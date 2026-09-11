extends Node
## Rooms — the eight rooms, their decor, slots, doors and furniture.
## Autoload #2.  Port of `demos/dierenhotel/rooms.js` (world.md §1).
##
## Everything a room knows is data: size, wall height, floor kind, walking
## speed, fixed decor, slots (beds and bowls), doors, and the derived grid of
## free cells and wander places that `bouw_af()` recomputes after every
## furniture change.  The camera reads `kader()`; the floor plate reads
## `vloer_kleur()`; the animals read `plekken` and `deur_punten`.
##
## The garden is generated: its fence and its 30 grass tufts come out of the
## same seeded mulberry32 the HTML uses (`Sommen.Prng`, world.md §1.3), so the
## lawn is laid out identically on every device and in every session.

signal kamers_veranderd()      ## a room's derived data changed (furniture)

const MARGE := 12              ## free-cell grid margin (world.md §1.5)
const MARGE_ERF := 18          ## ... 18 in the garden
const RASTER := 12             ## free-cell grid step
const PLEK_AF := 22            ## wander places keep 22 voxels from each other
const HEK_X := 10
const HEK_Z := 10
const TUFT_ZAAD := 90210
const MATRAS := 7              ## the top of a mattress, in voxels

## The six pieces of furniture a child can buy (world.md §1.8).
const MEUBEL := {
	"bed": {"soort": "bed", "model": "bed", "naam": "bed"},
	"bakje": {"soort": "bak", "model": "", "naam": "voerbakje"},
	"mandje": {"soort": "decor", "model": "mand", "naam": "mandje"},
	"speelmand": {"soort": "decor", "model": "mand", "naam": "speelmand"},
	"plant": {"soort": "decor", "model": "plant", "naam": "plant"},
	"badkuip": {"soort": "decor", "model": "tobbe", "naam": "badkuip"},
}

var _kamers: Dictionary = {}   ## id -> Kamer
var _volgorde: Array[String] = []
var _basis: Dictionary = {}    ## id -> the base layout, for "Nieuw spel"
var _nr := 0                   ## furniture id counter (mirrored in the save)

class Kamer extends RefCounted:
	var id: String
	var naam: String
	var icoon: String
	var w: int
	var d: int
	var wand: int
	var vloer: String
	var loop: float = 1.0
	var erf := false                ## the garden: no walls, wider margin
	var matten: Dictionary = {}     ## {x0, x1, z0, z1, kl: [Color, Color]}
	var bad: Dictionary = {}        ## {x0, x1, z0, z1} — water is a floor rule
	var balie: Dictionary = {}      ## the desk footprint; nobody walks over it
	var vrij_z0 := 0                ## no wander place in front of this z
	var dek: Dictionary = {}        ## {start: Vector2, over: Vector2}
	var zones: Dictionary = {}      ## reserved rectangles for the games
	var decor: Array = []           ## {n, x, z, y, ver, params, sleutel, meubel}
	var slots: Dictionary = {}      ## slotId -> {id, soort, model, x, z, sx, sz, draai}
	var deuren: Array = []          ## {naar, wand, at, breed, poort}
	var vast_kader: PackedInt32Array = PackedInt32Array()
	var box: PackedInt32Array       ## [x0, x1, y0, y1] in voxel-px
	var deur_punten: Dictionary = {}  ## naar -> {x, z, ix, iz}
	var vrij: Array = []            ## free cells [{id, x, z, soort}]
	var plekken: Array = []         ## wander places [[x, z], ...]

func _ready() -> void:
	_bouw_kamers()

## Every model name the rooms ask `Art` for, so a test can prove that the world
## never places a piece of decor the baker does not know.
func gebruikte_modellen() -> Array[String]:
	var uit: Array[String] = []
	for kid in _volgorde:
		var r: Kamer = _kamers[kid]
		for stuk in r.decor:
			if not uit.has(stuk["n"]):
				uit.append(String(stuk["n"]))
		for sid in r.slots:
			var m: String = r.slots[sid].get("model", "")
			if m != "" and not uit.has(m):
				uit.append(m)
	return uit

# ------------------------------------------------------------------- lezen

func lijst() -> Array[String]:
	return _volgorde.duplicate()

func get_kamer(id: String) -> Kamer:
	return _kamers.get(id)

func bestaat(id: String) -> bool:
	return _kamers.has(id)

## world.md §1.6 — fractional placement, so a room resize moves everything.
func plek(kamer_id: String, fx: float, fz: float) -> Dictionary:
	var r := get_kamer(kamer_id)
	if r == null:
		return {}
	return {"kamer": kamer_id, "x": JsGetal.rond(r.w * fx), "z": JsGetal.rond(r.d * fz)}

func hoogte(kamer_id: String, f: float) -> int:
	var r := get_kamer(kamer_id)
	return 0 if r == null else JsGetal.rond(r.w * f)

## world.md §1.1 — the room box in voxel-px, used by the camera.  The garden
## has a literal frame: its lawn deliberately runs on beyond it.
func kader(r: Kamer) -> PackedInt32Array:
	if r == null:
		return PackedInt32Array([0, 1, 0, 1])
	if not r.vast_kader.is_empty():
		return r.vast_kader
	return PackedInt32Array([
		-r.d * Art.S - 10, r.w * Art.S + 10,
		-r.wand * Art.HG - 12, JsGetal.rond((r.w + r.d) * (Art.S / 2.0)) + 10])

## world.md §1.2 — the derived door point and the step INSIDE the room where an
## animal stands before it walks through.
func deur(kamer_id: String, naar: String) -> Dictionary:
	var r := get_kamer(kamer_id)
	if r == null:
		return {}
	return r.deur_punten.get(naar, {})

## world.md §1.2 — breadth-first over the door graph.  Returns the whole path
## INCLUDING the start room, `[van]` when they are the same, `[]` when a room
## does not exist.
func pad(van: String, naar: String) -> Array[String]:
	var leeg: Array[String] = []
	if not bestaat(van) or not bestaat(naar):
		return leeg
	if van == naar:
		var zelf: Array[String] = [van]
		return zelf
	var rij: Array[String] = [van]
	var vanwaar := {van: ""}
	while not rij.is_empty():
		var nu: String = rij.pop_front()
		var r := get_kamer(nu)
		for dr in r.deuren:
			var volgende: String = dr["naar"]
			if vanwaar.has(volgende) or not bestaat(volgende):
				continue
			vanwaar[volgende] = nu
			if volgende == naar:
				var uit: Array[String] = [naar]
				var stap := nu
				while stap != "":
					uit.push_front(stap)
					stap = vanwaar[stap]
				return uit
			rij.append(volgende)
	return leeg

# ---------------------------------------------------------------- de vloer

## world.md §1.4 — the colour of one 1x1 floor cell.  The rule and its palette
## live in `ArtVloer.kleur()` (W4), which reads a room with `Object.get()`
## semantics, so the room class goes straight in.  One authority: the floor
## mesh, this file and the baker can never drift apart.
func vloer_kleur(r: Kamer, x: int, z: int) -> Color:
	if r == null:
		return ArtVloer.PLANK[0]
	return ArtVloer.kleur(r, x, z)

# ------------------------------------------------------------ afgeleide data

## world.md §1.5 `bouwAf` — box, door points, free cells, wander places and the
## standing place of every slot.  Runs again after every furniture change.
func bouw_af(r: Kamer) -> void:
	r.box = kader(r)
	r.deur_punten = {}
	for dr in r.deuren:
		var mid: float = dr["at"] + dr["breed"] / 2.0
		if dr["wand"] == "z":
			r.deur_punten[dr["naar"]] = {"x": mid, "z": 0.0, "ix": mid, "iz": 8.0,
				"wand": "z", "poort": dr.get("poort", false)}
		else:
			r.deur_punten[dr["naar"]] = {"x": 0.0, "z": mid, "ix": 8.0, "iz": mid,
				"wand": "x", "poort": dr.get("poort", false)}
	for id in r.slots.keys():
		_af_slot(r.slots[id])
	_bouw_vrij(r)
	_bouw_plekken(r)

## The standing place beside a slot (world.md §1.5 `afSlot`).
func _af_slot(slot: Dictionary) -> void:
	var x: float = slot["x"]
	var z: float = slot["z"]
	match slot["soort"]:
		"bed":
			if slot.get("draai", false) or slot.get("model", "") == "bedz":
				slot["sx"] = x + 12
				slot["sz"] = z + 2
			else:
				slot["sx"] = x + 2
				slot["sz"] = z + 12
		"bak":
			slot["sx"] = x - 13
			slot["sz"] = z
		_:
			slot["sx"] = x
			slot["sz"] = z

func _bouw_vrij(r: Kamer) -> void:
	r.vrij = []
	var marge := MARGE_ERF if r.erf else MARGE
	var x := marge
	while x <= r.w - marge:
		var z := marge
		while z <= r.d - marge:
			if _cel_vrij(r, x, z):
				r.vrij.append({"id": "v%d_%d" % [x, z], "x": x, "z": z, "soort": "vrij"})
			z += RASTER
		x += RASTER

## A cell is dropped when it is too close to decor, a slot, a door — or when it
## would put an animal in the pool.
func _cel_vrij(r: Kamer, x: int, z: int) -> bool:
	if not r.bad.is_empty() and z < int(r.bad["z1"]) + 6:
		return false
	# the strip behind and beside the desk is not floor a guest may stand on:
	# what is left is convex, so no straight walk can cut a corner over the desk
	if r.vrij_z0 > 0 and z < r.vrij_z0:
		return false
	if not r.balie.is_empty() and x >= int(r.balie["x0"]) - 2 and x <= int(r.balie["x1"]) + 2 \
			and z >= int(r.balie["z0"]) - 2 and z <= int(r.balie["z1"]) + 2:
		return false
	for stuk in r.decor:
		if absf(stuk["x"] - x) + absf(stuk["z"] - z) < 18.0:
			return false
	for id in r.slots:
		var slot: Dictionary = r.slots[id]
		if absf(slot["x"] - x) + absf(slot["z"] - z) < 18.0:
			return false
	for naar in r.deur_punten:
		var dp: Dictionary = r.deur_punten[naar]
		if absf(dp["ix"] - x) + absf(dp["iz"] - z) < 14.0:
			return false
	return true

## The wander places: walk the free cells in order and keep one only when it is
## at least 22 voxels (Manhattan) from every cell kept so far.
func _bouw_plekken(r: Kamer) -> void:
	var uit: Array = []
	for cel in r.vrij:
		var ver := true
		for p in uit:
			if absf(p[0] - cel["x"]) + absf(p[1] - cel["z"]) < PLEK_AF:
				ver = false
				break
		if ver:
			uit.append([cel["x"], cel["z"]])
	if uit.is_empty():
		uit = [[r.w / 2.0, r.d / 2.0]]
	r.plekken = uit

# ------------------------------------------------------------------ meubels

## Is this cell free enough to put something down? (world.md §1.8 `bezet`)
func vrij_vak(kamer_id: String, x: float, z: float) -> bool:
	var r := get_kamer(kamer_id)
	if r == null:
		return false
	if x < 4 or z < 4 or x > r.w - 4 or z > r.d - 4:
		return false
	return not _bezet(r, x, z)

func _bezet(r: Kamer, x: float, z: float) -> bool:
	for id in r.slots:
		var slot: Dictionary = r.slots[id]
		if absf(slot["x"] - x) + absf(slot["z"] - z) < 15.0:
			return true
	for stuk in r.decor:
		if absf(stuk["x"] - x) + absf(stuk["z"] - z) < 15.0:
			return true
	for naar in r.deur_punten:
		var dp: Dictionary = r.deur_punten[naar]
		if absf(dp["ix"] - x) + absf(dp["iz"] - z) < 12.0:
			return true
	return false

## Snap to the nearest free grid cell.
func _naar_raster(r: Kamer, x: float, z: float) -> Dictionary:
	var beste := {}
	var beste_af := INF
	for cel in r.vrij:
		if _bezet(r, cel["x"], cel["z"]):
			continue
		var af: float = absf(cel["x"] - x) + absf(cel["z"] - z)
		if af < beste_af:
			beste_af = af
			beste = {"x": float(cel["x"]), "z": float(cel["z"])}
	return beste

## world.md §1.8 — put a piece of furniture down.  Returns the record, or {}
## when there is no free spot: never a half-placed item.
func meubel_zet(kamer_id: String, type: String, x: float = NAN, z: float = NAN,
		rot: int = 0, id: String = "") -> Dictionary:
	var r := get_kamer(kamer_id)
	if r == null or not MEUBEL.has(type):
		return {}
	_onthoud_basis()
	var soort: Dictionary = MEUBEL[type]
	if is_nan(x) or is_nan(z):
		x = r.w / 2.0
		z = r.d / 2.0
	if x < 4 or z < 4 or x > r.w - 4 or z > r.d - 4 or _bezet(r, x, z):
		var vak := _naar_raster(r, x, z)
		if vak.is_empty():
			return {}
		x = vak["x"]
		z = vak["z"]
	if _bezet(r, x, z):
		return {}
	if id.is_empty():
		_nr += 1
		id = "m%d_%s" % [_nr, type]
	else:
		_nr = maxi(_nr, _nr_uit_id(id))
	var uit: Dictionary
	if soort["soort"] == "decor":
		uit = {"id": id, "n": soort["model"], "x": x, "z": z, "meubel": id, "type": type,
			"kamer": kamer_id, "rot": rot}
		r.decor.append(uit)
	else:
		var draai := (rot % 2) == 1
		uit = {"id": id, "soort": soort["soort"], "type": type, "kamer": kamer_id,
			"model": "bedz" if (soort["soort"] == "bed" and draai) else soort["model"],
			"x": x, "z": z, "sx": x, "sz": z, "draai": draai, "meubel": id, "rot": rot}
		r.slots[id] = uit
	bouw_af(r)
	kamers_veranderd.emit()
	return uit.duplicate()

func meubel_weg(id: String) -> bool:
	for kid in _volgorde:
		var r: Kamer = _kamers[kid]
		for i in range(r.decor.size() - 1, -1, -1):
			if r.decor[i].get("meubel", "") == id:
				r.decor.remove_at(i)
				bouw_af(r)
				kamers_veranderd.emit()
				return true
		if r.slots.has(id):
			r.slots.erase(id)
			bouw_af(r)
			kamers_veranderd.emit()
			return true
	return false

## Every bought piece, as save records (world.md §4.2 `meubels`).
func meubels(kamer_id: String = "") -> Array:
	var uit: Array = []
	for kid in _volgorde:
		if kamer_id != "" and kid != kamer_id:
			continue
		var r: Kamer = _kamers[kid]
		for stuk in r.decor:
			if stuk.has("meubel"):
				uit.append({"id": stuk["meubel"], "kamer": kid, "type": stuk.get("type", ""),
					"x": stuk["x"], "z": stuk["z"], "rot": stuk.get("rot", 0),
					"soort": "decor"})
		for sid in r.slots:
			var slot: Dictionary = r.slots[sid]
			if slot.has("meubel"):
				uit.append({"id": slot["meubel"], "kamer": kid, "type": slot.get("type", ""),
					"x": slot["x"], "z": slot["z"], "rot": slot.get("rot", 0),
					"soort": slot["soort"]})
	return uit

## `Rooms.slots(kamer, soort)` — the slots of one room, or of every room when
## `kamer` is empty; `soort` empty means every kind.  Beds are the hard guest
## cap (HOTEL.md §2), so `slots("", "bed")` is what `State.alle_bedden()` counts.
## Every record carries its own `id` and `kamer`.
func slots(kamer_id: String = "", soort: String = "") -> Array:
	var uit: Array = []
	for kid in _volgorde:
		if kamer_id != "" and kid != kamer_id:
			continue
		var r: Kamer = _kamers[kid]
		for sid in r.slots:
			if soort != "" and r.slots[sid]["soort"] != soort:
				continue
			var kopie: Dictionary = r.slots[sid].duplicate()
			kopie["id"] = sid
			kopie["kamer"] = kid
			uit.append(kopie)
	return uit

## One slot by id, or {} — `ctx.wereld.slot(kamer, slotId)` of world.md §5.3.
func slot(kamer_id: String, slot_id: String) -> Dictionary:
	var r := get_kamer(kamer_id)
	if r == null or not r.slots.has(slot_id):
		return {}
	var kopie: Dictionary = r.slots[slot_id].duplicate()
	kopie["id"] = slot_id
	kopie["kamer"] = kamer_id
	return kopie

## Back to the base layout ("Nieuw spel").
func herstel() -> void:
	if _basis.is_empty():
		return
	for kid in _basis:
		var r: Kamer = _kamers[kid]
		r.decor = _basis[kid]["decor"].duplicate(true)
		r.slots = _basis[kid]["slots"].duplicate(true)
		bouw_af(r)
	_nr = 0
	kamers_veranderd.emit()

func nr_stand() -> int:
	return _nr

func zet_nr(n: int) -> void:
	_nr = maxi(_nr, n)

func _nr_uit_id(id: String) -> int:
	if not id.begins_with("m"):
		return 0
	return id.substr(1).split("_")[0].to_int()

func _onthoud_basis() -> void:
	if not _basis.is_empty():
		return
	for kid in _volgorde:
		var r: Kamer = _kamers[kid]
		_basis[kid] = {"decor": r.decor.duplicate(true), "slots": r.slots.duplicate(true)}

# -------------------------------------------------------------- de acht kamers

func _bouw_kamers() -> void:
	# OWNER DECISION (architecture.md §13, Q-X1-13), deviating from world.md §1.3:
	# the desk stands along the BACK-RIGHT wall (z = 0) and the door to the gang
	# is in the BACK-LEFT wall (x = 0).  In the HTML the door sat behind the desk
	# and a guest walked straight through it.  The desk is one straight run now
	# instead of an L, so the walkable floor is the convex strip z >= 36: every
	# straight walk between two places in this room stays in front of the desk.
	_kamer({"id": "receptie", "naam": "Receptie", "icoon": "🛎️", "w": 120, "d": 120,
		"wand": 54, "vloer": "hout", "loop": 1.5,
		"matten": {"x0": 45, "x1": 99, "z0": 78, "z1": 114,
			"kl": [Color("#E9BFC9"), Color("#E3B4C0")]},
		"balie": {"x0": 28, "x1": 102, "z0": 13, "z1": 27},
		"vrij_z0": 36,
		"deuren": [{"naar": "gang", "wand": "x", "at": 24, "breed": 12}],
		"decor": [
			{"n": "balie", "x": 48, "z": 20}, {"n": "balie", "x": 83, "z": 20},
			{"n": "bel", "x": 36, "z": 20, "y": 14},
			{"n": "kassa", "x": 60, "z": 20, "y": 14},
			{"n": "boek", "x": 84, "z": 20, "y": 14},
			{"n": "lamp", "x": 99, "z": 20, "y": 14, "sleutel": "balielamp"},
			{"n": "prikbord", "x": 12, "z": 1, "ver": true},
			{"n": "sleutelbordz", "x": 1, "z": 84, "ver": true},
			{"n": "plant", "x": 16, "z": 96}, {"n": "plant", "x": 104, "z": 96}]})
	_kamer({"id": "gang", "naam": "Gang", "icoon": "🚪", "w": 120, "d": 36,
		"wand": 56, "vloer": "loper", "loop": 1.0,
		"deuren": [
			{"naar": "receptie", "wand": "x", "at": 10, "breed": 12},
			{"naar": "kamer1", "wand": "z", "at": 24, "breed": 12},
			{"naar": "kamer2", "wand": "z", "at": 60, "breed": 12},
			{"naar": "keuken", "wand": "z", "at": 96, "breed": 12}],
		"decor": [{"n": "plant", "x": 44, "z": 8}, {"n": "plant", "x": 82, "z": 8},
			{"n": "kist", "x": 114, "z": 14}]})
	for nr in [1, 2]:
		var mat_kl := [Color("#DFCBEA"), Color("#D6BFE4")] if nr == 1 \
			else [Color("#CBE3D6"), Color("#BFDBCB")]
		var plant_x := 102 if nr == 1 else 12
		var plant_z := 12 if nr == 1 else 99
		_kamer({"id": "kamer%d" % nr, "naam": "Kamer %d" % nr, "icoon": "🛏️",
			"w": 114, "d": 114, "wand": 58, "vloer": "zacht", "loop": 1.5,
			"matten": {"x0": 51, "x1": 93, "z0": 45, "z1": 87, "kl": mat_kl},
			"deuren": [{"naar": "gang", "wand": "z", "at": 72, "breed": 12}],
			"decor": [{"n": "plant", "x": plant_x, "z": plant_z},
				{"n": "mand", "x": 93, "z": 99}],
			"slots": [
				{"id": "bed1", "soort": "bed", "model": "bed", "x": 30, "z": 27},
				{"id": "bed2", "soort": "bed", "model": "bed", "x": 30, "z": 75},
				{"id": "bak", "soort": "bak", "model": "kom", "x": 84, "z": 33}]})
	_kamer({"id": "keuken", "naam": "Keuken", "icoon": "🍪", "w": 120, "d": 114,
		"wand": 56, "vloer": "tegel", "loop": 1.5,
		"deuren": [
			{"naar": "gang", "wand": "x", "at": 75, "breed": 12},
			{"naar": "tuin", "wand": "z", "at": 90, "breed": 12, "poort": true},
			{"naar": "wasserij", "wand": "x", "at": 30, "breed": 12}],
		"decor": [{"n": "kast", "x": 33, "z": 6}, {"n": "zak", "x": 66, "z": 18},
			{"n": "kar", "x": 48, "z": 66, "sleutel": "kar"},
			{"n": "plant", "x": 108, "z": 93}]})
	_kamer({"id": "tuin", "naam": "Tuin", "icoon": "🌳", "w": 130, "d": 130,
		"wand": 0, "vloer": "gras", "loop": 1.0, "erf": true,
		"vast_kader": [-170, 190, -70, 220],
		"zones": {"hinkel": {"x0": 24, "x1": 100, "z0": 34, "z1": 50},
			"kraam": {"x0": 104, "x1": 126, "z0": 36, "z1": 68}},
		"deuren": [
			{"naar": "keuken", "wand": "x", "at": 34, "breed": 12, "poort": true},
			{"naar": "zwembad", "wand": "z", "at": 38, "breed": 12, "poort": true}],
		"decor": [{"n": "boom", "x": 16, "z": 68}, {"n": "hok", "x": 67, "z": 19},
			{"n": "tobbe", "x": 32, "z": 94}, {"n": "bal", "x": 120, "z": 76},
			{"n": "kist", "x": 95, "z": 23}, {"n": "poort", "x": 10, "z": 40, "ver": true}],
		"slots": [{"id": "tobbe", "soort": "vrij", "model": "tobbe", "x": 32, "z": 94}]})
	_kamer({"id": "zwembad", "naam": "Zwembad", "icoon": "🏊", "w": 144, "d": 88,
		"wand": 50, "vloer": "tegel", "loop": 1.5,
		"bad": {"x0": 18, "x1": 134, "z0": 12, "z1": 44},
		"dek": {"start": Vector2(12, 56), "over": Vector2(132, 56)},
		"deuren": [{"naar": "tuin", "wand": "x", "at": 60, "breed": 12}],
		"decor": [{"n": "mat", "x": 9, "z": 28}, {"n": "plant", "x": 136, "z": 80}]})
	_kamer({"id": "wasserij", "naam": "Wasserij", "icoon": "🧺", "w": 100, "d": 90,
		"wand": 52, "vloer": "tegel", "loop": 1.25,
		"deuren": [{"naar": "keuken", "wand": "z", "at": 62, "breed": 12}],
		"decor": [{"n": "kast", "x": 28, "z": 6}, {"n": "tobbe", "x": 80, "z": 74}]})
	_bouw_tuin(_kamers["tuin"])
	for id in _volgorde:
		bouw_af(_kamers[id])

func _kamer(o: Dictionary) -> void:
	var r := Kamer.new()
	r.id = o["id"]
	r.naam = o["naam"]
	r.icoon = o["icoon"]
	r.w = o["w"]
	r.d = o["d"]
	r.wand = o["wand"]
	r.vloer = o["vloer"]
	r.loop = o.get("loop", 1.0)
	r.erf = o.get("erf", false)
	r.matten = o.get("matten", {})
	r.bad = o.get("bad", {})
	r.balie = o.get("balie", {})
	r.vrij_z0 = int(o.get("vrij_z0", 0))
	r.dek = o.get("dek", {})
	r.zones = o.get("zones", {})
	r.deuren = o.get("deuren", [])
	r.decor = o.get("decor", []).duplicate(true)
	if o.has("vast_kader"):
		r.vast_kader = PackedInt32Array(o["vast_kader"])
	for slot in o.get("slots", []):
		var s: Dictionary = slot.duplicate()
		s["sx"] = s["x"]
		s["sz"] = s["z"]
		r.slots[s["id"]] = s
	_kamers[r.id] = r
	_volgorde.append(r.id)

## world.md §1.3 — the fence and the 30 grass tufts, deterministic, once.
func _bouw_tuin(r: Kamer) -> void:
	var z := HEK_Z
	while z <= 130:
		if z < 34 or z > 46:
			r.decor.append({"n": "hekz", "x": HEK_X, "z": z, "hek": true})
		z += 14
	var x := 24
	while x <= 130:
		if x < 38 or x > 50:
			r.decor.append({"n": "hekx", "x": x, "z": HEK_Z, "hek": true})
		x += 14
	var groot := [[16, 68], [67, 19], [32, 94], [120, 76], [95, 23]]
	var rnd := Sommen.Prng.new(TUFT_ZAAD)
	for i in 30:
		var u := JsGetal.rond(rnd.volgende() * 300.0 - 150.0)
		var w := 24 + JsGetal.rond(rnd.volgende() * 220.0)
		var px := (u + w) / 2.0
		var pz := (w - u) / 2.0
		if px <= 12 or pz <= 12:
			continue
		var goed := true
		for g in groot:
			if absf(g[0] - px) + absf(g[1] - pz) < 22.0:
				goed = false
				break
		if goed:
			for naam in r.zones:
				var zo: Dictionary = r.zones[naam]
				if px >= zo["x0"] - 4 and px <= zo["x1"] + 4 \
						and pz >= zo["z0"] - 4 and pz <= zo["z1"] + 4:
					goed = false
					break
		if goed:
			r.decor.append({"n": "pol%d" % (i % 5), "x": px, "z": pz, "pol": true})
