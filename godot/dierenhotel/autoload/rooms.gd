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
	var hek_x := HEK_X              ## the fence line along x (inside ⇔ x > hek_x)
	var hek_z := HEK_Z              ## the fence line along z (inside ⇔ z > hek_z)
	var matten = {}                 ## {x0, x1, z0, z1, kl: [Color, Color]} of een lijst daarvan (R2)
	var bad: Dictionary = {}        ## {x0, x1, z0, z1} — water is a floor rule
	## Outdoors: a building wall on one side, {wand, hoog, stoep} — the garden
	## has the hotel's back wall on x = 0, with the kitchen door in it.
	var gevel: Dictionary = {}
	## Outdoors: what lies beyond the fence and can be seen from here, drawn
	## as floor — the pool behind the garden's back fence.  [{soort, x0, x1, z0, z1}]
	var uitzicht: Array = []
	## The floor point a door INTO this room shows through its opening
	## (`scenes/vloer.gd`); the middle of the room when it is not set.
	var kijk := Vector2(-1.0, -1.0)
	var balie: Dictionary = {}      ## the desk footprint; nobody walks over it
	var vrij_z0 := 0                ## no wander place in front of this z
	## Glass walls (the kas, R3): a brick knee wall with panes and white glazing
	## bars over it instead of plaster (`scenes/vloer.gd`); a door INTO such a
	## room gets a white frame, like a door that leads outside.
	var glas := false
	## Floor rectangles {x0, x1, z0, z1} kept free of wander places and of bought
	## furniture: where a game's own table or scale stands (its resting props,
	## world.md §5.1), so a guest does not stroll into it and the furniture book
	## cannot put a plant on it.  Empty in every room but the kas.
	var mijd: Array = []
	var dek: Dictionary = {}        ## {start: Vector2, over: Vector2}
	var zones: Dictionary = {}      ## reserved rectangles for the games
	var decor: Array = []           ## {n, x, z, y, ver, params, sleutel, meubel, ingang}
	var slots: Dictionary = {}      ## slotId -> {id, soort, model, x, z, sx, sz, draai}
	var deuren: Array = []          ## {naar, wand, at, breed, poort}
	## The hotel's front door, {wand, at, breed} like a door (the receptie only,
	## owner 2026-09-23: guests "komen momenteel vanuit de gang binnen ipv
	## ingang").  It is NOT a door of the graph: no path (`pad`), no door button,
	## no chip and no cell on the map lead through it.  A guest who arrives at the
	## hotel steps in from outside here (`World.kom_binnen`).  Derived into
	## `ingang_punt` by `bouw_af`.
	var ingang: Dictionary = {}
	var ingang_punt: Dictionary = {}  ## {x, z, ix, iz, dx, dz, wand}, or {}
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

## The front door of a room (only the receptie has one): the point in the wall
## `(x, z)`, the step inside `(ix, iz)` where a guest who came in stands clear
## of the doorway, and `(dx, dz)` on the threshold, where he appears.
## `{}` for a room without one.  Not a door: `pad()` never goes through it.
func ingang(kamer_id: String) -> Dictionary:
	var r := get_kamer(kamer_id)
	if r == null:
		return {}
	return r.ingang_punt.duplicate()

## How tall a door's opening is, in voxels — ONE rule for the wall drawing
## (`scenes/vloer.gd`) and the door's screen box (`World.vlak_van_deur`).
## A door in a wall is cut to `min(wand − 6, 26)` (world.md §1.4); a door in
## the garden's facade the same, with the facade's height as the wall; a
## gate in a fence is as tall as the gate model that stands in it.
const POORT_HOOG := 18

func deur_hoog(r: Kamer, dr: Dictionary) -> int:
	if r == null:
		return 6
	if bool(dr.get("poort", false)):
		return POORT_HOOG
	# a door that says how tall it is (the receptie's front door, 32)
	if dr.has("hoog"):
		return int(dr["hoog"])
	var wand := r.wand
	if not r.gevel.is_empty() and str(r.gevel.get("wand", "")) == str(dr.get("wand", "")):
		wand = int(r.gevel.get("hoog", 0))
	return maxi(6, mini(wand - 6, 26))

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
	# the front door is derived like a door, but kept apart from `deur_punten`:
	# every door button, path and "komt eraan" bubble walks that table
	r.ingang_punt = {}
	if not r.ingang.is_empty():
		var im: float = float(r.ingang["at"]) + float(r.ingang["breed"]) / 2.0
		if str(r.ingang["wand"]) == "z":
			r.ingang_punt = {"x": im, "z": 0.0, "ix": im, "iz": 8.0, "dx": im, "dz": 3.0,
				"wand": "z"}
		elif str(r.ingang["wand"]) == "voor":
			# the FRONT edge z = d, the side the camera looks in through: he
			# appears on the threshold and his first step is onto the rug
			r.ingang_punt = {"x": im, "z": float(r.d), "ix": im, "iz": float(r.d) - 12.0,
				"dx": im, "dz": float(r.d) - 2.0, "wand": "voor"}
		else:
			r.ingang_punt = {"x": 0.0, "z": im, "ix": 8.0, "iz": im, "dx": 3.0, "dz": im,
				"wand": "x"}
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
	if _in_mijd(r, x, z, 3.0):
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
	# the front door's step inside is kept free like a door's
	if not r.ingang_punt.is_empty() \
			and absf(float(r.ingang_punt["ix"]) - x) + absf(float(r.ingang_punt["iz"]) - z) < 14.0:
		return false
	return true

## The wander places: walk the free cells in order and keep one only when it is
## at least 22 voxels (Manhattan) from every cell kept so far.
## The way round the water (owner, 2026-09-14: "ze lopen door het bad heen").
## A walk from one dry point to another that would cut through the pool goes
## via the corners of the pool's margin instead: the shortest chain of at most
## two corners whose legs all stay dry.  From INSIDE the water (leaving after a
## swim) the straight line is kept: that is the shortest way out.
## Returns the intermediate points only; empty when the line is dry already.
const WATER_RAND := 5.0

func om_het_water(kamer_id: String, van: Vector2, naar: Vector2) -> Array:
	var r := get_kamer(kamer_id)
	if r == null or r.bad.is_empty():
		return []
	var water := Rect2(float(r.bad["x0"]), float(r.bad["z0"]),
		float(r.bad["x1"]) - float(r.bad["x0"]), float(r.bad["z1"]) - float(r.bad["z0"]))
	if water.has_point(van) or water.has_point(naar) or not _snijdt(water, van, naar):
		return []
	var m := WATER_RAND
	var hoeken: Array[Vector2] = [
		Vector2(water.position.x - m, water.position.y - m),
		Vector2(water.end.x + m, water.position.y - m),
		Vector2(water.end.x + m, water.end.y + m),
		Vector2(water.position.x - m, water.end.y + m),
	]
	var beste: Array = []
	var beste_lengte := INF
	for h in hoeken:
		if not _snijdt(water, van, h) and not _snijdt(water, h, naar):
			var l := van.distance_to(h) + h.distance_to(naar)
			if l < beste_lengte:
				beste_lengte = l
				beste = [h]
	if not beste.is_empty():
		return beste
	for i in hoeken.size():
		for j in hoeken.size():
			if i == j:
				continue
			var a := hoeken[i]
			var b := hoeken[j]
			if _snijdt(water, van, a) or _snijdt(water, a, b) or _snijdt(water, b, naar):
				continue
			var l := van.distance_to(a) + a.distance_to(b) + b.distance_to(naar)
			if l < beste_lengte:
				beste_lengte = l
				beste = [a, b]
	return beste

## What stands on the floor of a room, for the walking grid (`World.looppad`,
## `wereld/looppad.gd`; owner, 2026-09-24: "Dieren lopen ook vaak door objecten
## heen").  Read from the room as it is NOW, so bought furniture is in it the
## moment it is bought:
##   * every piece of fixed or bought decor that stands on the floor — not what
##     hangs on a wall (`ver`), not the grass tufts (`pol`);
##   * every slot: a bed as its model, a bowl as the bowl (`kom`, on its own
##     anchor, also a bought `bakje` without a model), the tub;
##   * the water, as a floor rectangle — the pool is walked round, and a guest
##     who climbs out takes the shortest way out (`om_het_water` did the same);
##   * the desk and the strip behind it, back to the wall: the owner's walkable
##     lobby is the floor in front of the counter (Q-X1-13).
## `{model, params, x, z, y, rot, ax, az}` for a model, `{x0, x1, z0, z1}` for a
## rectangle.  `World` adds the two movable things and a game's loose decor.
func hindernissen(kamer_id: String) -> Array:
	var uit: Array = []
	var r := get_kamer(kamer_id)
	if r == null:
		return uit
	for stuk in r.decor:
		if bool(stuk.get("ver", false)) or bool(stuk.get("pol", false)):
			continue
		uit.append({"model": str(stuk["n"]), "params": stuk.get("params", {}),
			"x": float(stuk["x"]), "z": float(stuk["z"]), "y": float(stuk.get("y", 0.0)),
			"rot": int(stuk.get("rot", 0)), "ax": 0.0, "az": 0.0})
	for sid in r.slots:
		var slot: Dictionary = r.slots[sid]
		if str(slot.get("soort", "")) == "bak":
			uit.append({"model": "kom", "params": {}, "x": float(slot["x"]),
				"z": float(slot["z"]), "y": 0.0, "rot": 0,
				"ax": Art.KOM_ANKER.x, "az": Art.KOM_ANKER.y})
		elif not str(slot.get("model", "")).is_empty():
			uit.append({"model": str(slot["model"]), "params": {}, "x": float(slot["x"]),
				"z": float(slot["z"]), "y": 0.0, "rot": 0, "ax": 0.0, "az": 0.0})
	if not r.bad.is_empty():
		uit.append({"x0": float(r.bad["x0"]), "x1": float(r.bad["x1"]),
			"z0": float(r.bad["z0"]), "z1": float(r.bad["z1"])})
	if not r.balie.is_empty():
		uit.append({"x0": float(r.balie["x0"]), "x1": float(r.balie["x1"]),
			"z0": 0.0, "z1": float(r.balie["z1"])})
	return uit

## Does the open segment a–b pass through the rectangle?  Liang–Barsky.
static func _snijdt(r: Rect2, a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	var p := [-d.x, d.x, -d.y, d.y]
	var q := [a.x - r.position.x, r.end.x - a.x, a.y - r.position.y, r.end.y - a.y]
	for i in 4:
		if is_zero_approx(p[i]):
			if q[i] < 0.0:
				return false
		else:
			var t: float = q[i] / p[i]
			if p[i] < 0.0:
				t0 = maxf(t0, t)
			else:
				t1 = minf(t1, t)
	return t0 < t1 - 0.0001

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
	if _in_mijd(r, x, z, 4.0):
		return true
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
	if not r.ingang_punt.is_empty() \
			and absf(float(r.ingang_punt["ix"]) - x) + absf(float(r.ingang_punt["iz"]) - z) < 12.0:
		return true
	return false

## Does (x, z) lie within `rand` voxels of one of the room's `mijd` rectangles
## (the floor a game's table or scale stands on)?  No room but the kas has one.
func _in_mijd(r: Kamer, x: float, z: float, rand: float) -> bool:
	for m in r.mijd:
		if x >= float(m["x0"]) - rand and x <= float(m["x1"]) + rand \
				and z >= float(m["z0"]) - rand and z <= float(m["z1"]) + rand:
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
		# a door into the receptie shows its planks AND the edge of its pink
		# rug, so it is not the playroom's wooden floor (owner, 2026-09-23)
		"kijk": Vector2(72, 84),
		"balie": {"x0": 28, "x1": 102, "z0": 13, "z1": 27},
		"vrij_z0": 36,
		"deuren": [{"naar": "gang", "wand": "x", "at": 24, "breed": 12},
			# R2: de speelzaal komt bij de plant in de verre hoek; de plant had
			# die hoek al grotendeels leeggemaakt (zie tmp/log voor de meting).
			{"naar": "speelzaal", "wand": "x", "at": 108, "breed": 12}],
		# The hotel's front door (owner, 2026-09-23: the guests "komen momenteel
		# vanuit de gang binnen ipv ingang").  It stands where the pink rug lies,
		# in the FRONT edge of the lobby — the side the camera looks in through,
		# which has no wall on screen — and it is only its outline, open, a size
		# bigger than a door in a wall (owner, 2026-09-24: "zet de lobby deur
		# waar het tapijt is maar alleen de uitlijn en laat hem open zodat je
		# erdoorheen kan kijken en het tapijt zien ... En maak hem wat groter dan
		# de andere deuren"; and once more: "Mooi maak de deur nog iets groter").
		# 26 wide and 38 tall where every door in a wall is 12 x 26.  A guest
		# who arrives steps in over the rug and walks straight
		# up to the counter; no door button, path or chip goes through it
		# (`Kamer.ingang`, world.md §1.2).  `open`: no leaf, nothing to shut.
		"ingang": {"wand": "voor", "at": 59, "breed": 26, "hoog": 38, "open": true},
		"decor": [
			# the outline of the front door, on the front edge in the middle of
			# the rug (`matten` x 45..99)
			{"n": "voordeuromlijst", "x": 72, "z": 119},
			{"n": "balie", "x": 48, "z": 20}, {"n": "balie", "x": 83, "z": 20},
			{"n": "bel", "x": 36, "z": 20, "y": 14, "d": 12.5},   # sorts after the desk piece at (48, 20)
			{"n": "kassa", "x": 60, "z": 20, "y": 14},
			# flowers on the desk: like the bell they need a depth bias, or the
			# desk piece at (83, 20) they stand on draws over them (103 > 92.3);
			# 11.5 puts them in front of that piece and behind the book (104.3)
			{"n": "bloemen", "x": 72, "z": 20, "y": 14, "d": 11.5},
			{"n": "boek", "x": 84, "z": 20, "y": 14},
			{"n": "lamp", "x": 99, "z": 20, "y": 14, "sleutel": "balielamp"},
			# The notice board hangs on the back wall again, left of the desk.
			# For a day it hung over the bench to give its task cards room
			# round it; the cards are a sheet now (owner, 2026-09-23: "wekker
			# zetten is ... helemaal niet relevant aan waar de tekst geplaatst
			# is"), and over the bench it pushed the key board's "Sleutels" off
			# its board and onto the bench.
			{"n": "prikbord", "x": 12, "z": 1, "ver": true},
			{"n": "klok", "x": 70, "z": 1, "y": 36, "ver": true},
			{"n": "poster_poot", "x": 112, "z": 1, "y": 32, "ver": true},
			{"n": "sleutelbordz", "x": 1, "z": 84, "ver": true},
			# the waiting corner along the left wall, between the door (z 24..36)
			# and the key board (z 84): the bench runs z 48..67, the case z 70..73
			{"n": "bankjez", "x": 6, "z": 58}, {"n": "koffer", "x": 6, "z": 72},
			{"n": "plant", "x": 16, "z": 96}, {"n": "plant", "x": 104, "z": 96}]})
	_kamer({"id": "gang", "naam": "Gang", "icoon": "🚪", "w": 120, "d": 36,
		"wand": 56, "vloer": "loper", "loop": 1.0,
		"deuren": [
			{"naar": "receptie", "wand": "x", "at": 10, "breed": 12},
			{"naar": "kamer1", "wand": "z", "at": 24, "breed": 12},
			{"naar": "kamer2", "wand": "z", "at": 60, "breed": 12},
			{"naar": "keuken", "wand": "z", "at": 96, "breed": 12}],
		# the corridor is only 36 deep, so everything new hangs on the back wall
		# (z = 1): a piece there is 23 voxels from the walking cells at z = 24
		# and drops none of them.  The pictures hang at y = 30.
		# The two plants stand along the FRONT edge (owner, 2026-09-23: every
		# door should show where it goes): against the back wall a plant hides
		# the wall from 21 voxels left of it to 5 right of it, and the doors
		# are only 24 apart, so at (44, 8) and (82, 8) they covered 37 % of the
		# kamer 1 door and 29 % of the kamer 2 door.  Here they cover nothing,
		# and at x = 36 and 108 they sit exactly between the walking cells of
		# the front row, so the corridor keeps its four wander places.
		"decor": [{"n": "kapstok", "x": 12, "z": 1, "ver": true},
			{"n": "poster_poot", "x": 48, "z": 1, "y": 30, "ver": true},
			{"n": "poster_boom", "x": 84, "z": 1, "y": 30, "ver": true},
			{"n": "plant", "x": 36, "z": 30}, {"n": "plant", "x": 108, "z": 30},
			{"n": "kist", "x": 114, "z": 14}]})
	# OWNER DECISION (2026-09-17): "kamer 2 lijkt exact op kamer 1, die mag wel
	# iets anders".  The two bedrooms were one loop; they are two rooms now.
	#
	# Kamer 1, the lilac room: the two beds lie along x on the left half (their
	# places are fixed facts — tests/test_rooms.gd `test_stavakken_van_de_slots`),
	# a window on the back wall between the door and the corner, a bedside table
	# with a picture over it against the left wall, blocks in the near corner.
	_kamer({"id": "kamer1", "naam": "Kamer 1", "icoon": "🛏️",
		"w": 114, "d": 114, "wand": 58, "vloer": "zacht", "loop": 1.5,
		"matten": {"x0": 51, "x1": 93, "z0": 45, "z1": 87,
			"kl": [Color("#DFCBEA"), Color("#D6BFE4")]},
		"deuren": [{"naar": "gang", "wand": "z", "at": 72, "breed": 12}],
		"decor": [
			{"n": "raam", "x": 40, "z": 1, "y": 25, "ver": true},
			{"n": "schilderijz", "x": 1, "z": 51, "y": 29, "ver": true},
			{"n": "nachtkastje", "x": 8, "z": 51},
			{"n": "blokken", "x": 14, "z": 100},
			# (107, 8), not (102, 12): there it hid the corner of the door
			{"n": "plant", "x": 107, "z": 8},
			{"n": "mand", "x": 93, "z": 99}],
		"slots": [
			{"id": "bed1", "soort": "bed", "model": "bed", "x": 30, "z": 27},
			{"id": "bed2", "soort": "bed", "model": "bed", "x": 30, "z": 75},
			{"id": "bak", "soort": "bak", "model": "kom", "x": 84, "z": 33}]})
	# Kamer 2, the mint room: everything the child recognises sits somewhere
	# else.  Both beds are `bedz` — turned a quarter, side by side along the back
	# wall, leaving its right half for the door — the bowl stands in the far
	# corner instead of beside the beds, the rug is a runner in front of them,
	# the window hangs on the LEFT wall and the back wall carries a book shelf
	# right of the door.  Slot ids stay bed1, bed2, bak.
	_kamer({"id": "kamer2", "naam": "Kamer 2", "icoon": "🛏️",
		"w": 114, "d": 114, "wand": 58, "vloer": "zacht", "loop": 1.5,
		"matten": {"x0": 24, "x1": 96, "z0": 58, "z1": 76,
			"kl": [Color("#CBE3D6"), Color("#BFDBCB")]},
		"deuren": [{"naar": "gang", "wand": "z", "at": 72, "breed": 12}],
		"decor": [
			{"n": "raamz", "x": 1, "z": 72, "y": 25, "ver": true},
			{"n": "schilderij", "x": 64, "z": 1, "y": 31, "ver": true},
			{"n": "boekenplank", "x": 100, "z": 1, "y": 30, "ver": true},
			{"n": "staande_lamp", "x": 12, "z": 52},
			{"n": "speelgoedkist", "x": 104, "z": 44},
			{"n": "mand", "x": 14, "z": 96},
			{"n": "plant", "x": 48, "z": 102}],
		"slots": [
			{"id": "bed1", "soort": "bed", "model": "bedz", "x": 18, "z": 30},
			{"id": "bed2", "soort": "bed", "model": "bedz", "x": 52, "z": 30},
			{"id": "bak", "soort": "bak", "model": "kom", "x": 96, "z": 84}]})
	_kamer({"id": "keuken", "naam": "Keuken", "icoon": "🍪", "w": 120, "d": 114,
		"wand": 56, "vloer": "tegel", "loop": 1.5,
		# an apricot runner in front of the sink: the laundry and the pool deck
		# have the same tiles, so a door into the kitchen shows the runner too
		# (`kijk`, owner 2026-09-23)
		"matten": {"x0": 48, "x1": 76, "z0": 14, "z1": 26,
			"kl": [Color("#EBC3A8"), Color("#E3B598")]},
		"kijk": Vector2(62, 22),
		# OWNER, 2026-09-23: "keuken naar tuin hebben geen mooie overgang die
		# sprekend is".  The garden door was a `poort` in a room WITH walls, so
		# no hole was cut and the kitchen had no door to the garden at all —
		# only a button beside the fridge.  It is a real back door now, in the
		# corner at the end of the kitchen run, and through it you see the lawn.
		# The fridge moved up next to the stove to make room: in front of the
		# old opening (x 90..102) its body hid a third of the door.
		"deuren": [
			{"naar": "gang", "wand": "x", "at": 75, "breed": 12},
			{"naar": "tuin", "wand": "z", "at": 104, "breed": 12},
			{"naar": "wasserij", "wand": "x", "at": 30, "breed": 12}],
		# OWNER, 2026-09-17: "de keuken heeft een bed en kast en plant ipv
		# kookgerei".  The kitchen now reads as a kitchen: one run along the back
		# wall (voerkast, aanrecht with a sink, fornuis, koelkast) with a
		# pannenrek and a pottenplank on the wall above it, and a little table
		# with biscuits in the near corner instead of the plant.  Nothing stands
		# in front of the garden door (x 104..116) but its doormat, and the
		# middle of the floor stays open for the guests and the voerkar's bowls.
		# `keukenkar` is the kitchen's own trolley model (art/decor_keuken.gd);
		# it keeps the thing key "kar", so the game and the save do not notice.
		"decor": [{"n": "kast", "x": 33, "z": 6}, {"n": "zak", "x": 12, "z": 22},
			{"n": "aanrecht", "x": 60, "z": 6}, {"n": "fornuis", "x": 80, "z": 6},
			{"n": "koelkast", "x": 94, "z": 8},
			{"n": "pottenplank", "x": 55, "z": 2, "y": 18, "ver": true},
			{"n": "pannenrek", "x": 79, "z": 2, "y": 20, "ver": true},
			{"n": "deurmat", "x": 110, "z": 5},
			{"n": "keukentafel", "x": 104, "z": 98},
			{"n": "keukenkar", "x": 48, "z": 66, "sleutel": "kar"}]})
	# OWNER, 2026-09-23: "Het zwembad vanuit de tuin gezien is niet duidelijk
	# dat lijkt gewoon op een huis" — and no exit of the garden said where it
	# went: the kitchen gate stood behind the tree, the pool opening behind the
	# doghouse.  The garden is the lawn BEHIND the hotel now:
	#   * the left side is the hotel's back wall (`gevel`), with the kitchen's
	#     back door in it — an awning over it, a doormat before it, a window
	#     beside it and a paved strip along the wall;
	#   * behind the back fence lies the pool itself (`uitzicht`): deck, rim,
	#     water, a ladder and a parasol, seen through a white pool gate with a
	#     lifebuoy on it;
	#   * the doghouse stands in the back corner against the hotel, where it
	#     also closes the gap between the wall and the fence, and the hopscotch
	#     path starts in front of it; the tree moved to the front left.  Neither
	#     stands in front of an exit any more.  (For a while the doghouse stood
	#     in the far right corner — but the souvenir stall, which stays standing
	#     now, would hide it there.)
	_kamer({"id": "tuin", "naam": "Tuin", "icoon": "🌳", "w": 130, "d": 130,
		"wand": 0, "vloer": "gras", "loop": 1.0, "erf": true,
		"hek_x": 0,
		"vast_kader": [-170, 190, -70, 220],
		"gevel": {"wand": "x", "hoog": 34, "stoep": 8},
		"uitzicht": [{"soort": "bad", "x0": 24, "x1": 124, "z0": -36, "z1": -4}],
		"zones": {"hinkel": {"x0": 24, "x1": 100, "z0": 34, "z1": 50},
			"kraam": {"x0": 104, "x1": 126, "z0": 36, "z1": 68}},
		# R3: the glass door of the kas sits in the hotel's back wall where the
		# kitchen window hung — the only stretch of the facade in view that is
		# not the kitchen door, its open leaf or the doghouse (z ≤ 85 is in
		# the frame).  A glass canopy over it and a potted plant beside it say
		# "greenhouse" before its sign does; through it you see the kas's
		# terracotta path (`kijk`).
		"deuren": [
			{"naar": "keuken", "wand": "x", "at": 34, "breed": 12},
			{"naar": "zwembad", "wand": "z", "at": 38, "breed": 12, "poort": true},
			{"naar": "kas", "wand": "x", "at": 62, "breed": 12}],
		"decor": [{"n": "boom", "x": 22, "z": 126}, {"n": "hok", "x": 22, "z": 22},
			{"n": "tobbe", "x": 32, "z": 94}, {"n": "bal", "x": 120, "z": 76},
			{"n": "kist", "x": 12, "z": 84},
			{"n": "kasluifelz", "x": 1, "z": 68, "y": 27, "ver": true},
			{"n": "kaspot", "x": 4, "z": 58},
			{"n": "luifelz", "x": 1, "z": 40, "y": 27, "ver": true},
			{"n": "deurmatz", "x": 5, "z": 40},
			{"n": "zwembadpoort", "x": 44, "z": 10},
			{"n": "zwembadtrap", "x": 31, "z": -3},
			{"n": "parasol", "x": 66, "z": 0}],
		"slots": [{"id": "tobbe", "soort": "vrij", "model": "tobbe", "x": 32, "z": 94}]})
	# Outdoors (owner, 2026-09-14: "het zwembad wil ik graag ook buiten"): lawn
	# and a fence like the garden's, the water with a tiled deck round it, and
	# a gate in the side fence towards the garden.
	# The metre markers and the finish flag lie INSIDE the fence, on the deck in
	# front of the water (owner, 2026-09-16: "de duikplek van het zwembad zit
	# door een hek heen").  The old instapvlonder (`mat`) is gone: the entry is
	# the startblok now (owner, 2026-09-17: "haal de oude houten plank weg").
	# The fence stands further from the water than the garden's (owner,
	# 2026-09-17: "Doe het hek verder van beide kanten van het zwembad"), and
	# it runs along the BACK long side of the pool, not along the short side
	# by the startblok (owner, 2026-09-23: "zet het hek aan de bovenste
	# zijkant van het zwembad niet aan de korte kant bij de startblokken");
	# `_bouw_zwembad` builds it.  One big startblok with a little stair sits at
	# the west end of the lane ("startblokken ... met een trappetje zodat het
	# dier langzaam omhoog kan springen"; "Maak het startblok groter en doe 1
	# ipv 3").
	_kamer({"id": "zwembad", "naam": "Zwembad", "icoon": "🏊", "w": 144, "d": 88,
		"wand": 0, "vloer": "gras", "loop": 1.5, "erf": true,
		"hek_x": 4, "hek_z": 4,
		"vast_kader": [-190, 300, -60, 250],
		"bad": {"x0": 18, "x1": 134, "z0": 12, "z1": 44},
		# `over` stands beside the finish flag (x 134, z 50), not in its foot:
		# a guest who climbed out at (132, 56) stood inside the flag
		"dek": {"start": Vector2(12, 56), "over": Vector2(116, 56)},
		"deuren": [{"naar": "tuin", "wand": "x", "at": 60, "breed": 12, "poort": true}],
		# The way back to the garden looks like a garden (owner, 2026-09-23): a
		# rose arch in the line of the side fence, and beyond it the garden's
		# tree and its flowers.
		"decor": [{"n": "plant", "x": 136, "z": 80},
			{"n": "rozenboog", "x": 4, "z": 66},
			{"n": "startblok", "x": 14, "z": 28},
			{"n": "boom", "x": -22, "z": 46},
			{"n": "bloemstruik", "x": -8, "z": 40}, {"n": "bloemstruik", "x": -9, "z": 79}]})
	# The laundry was "heel kaal" — a cupboard and a tub (owner, 2026-09-17).
	# It is furnished with `art/decor_wasserij.gd` now, and every piece stands
	# where the `was` game does NOT draw (games-b.md §4.4): its crates fill the
	# diagonal x + z = 66, the pile lies at (60, 54), the question card at
	# (88, 84) and the legend at (12, 27).  So: the back wall left of the door
	# (two washing machines with the soap shelf over them), the narrow strip of
	# back wall right of the door (the ironing board, low enough to stay under
	# the kitchen door's button), the left wall in front of the crates (the
	# drying rack) and the front-right corner (the tub with its basket).
	# The tub stays at (80, 74): the game's entry button hangs on it.
	# An aqua bath mat lies under the laundry pile (owner, 2026-09-23): the
	# laundry and the kitchen both have tiles, and the kitchen's door into the
	# laundry should show a different room, not more kitchen (`kijk`).
	_kamer({"id": "wasserij", "naam": "Wasserij", "icoon": "🧺", "w": 100, "d": 90,
		"wand": 52, "vloer": "tegel", "loop": 1.25,
		"matten": {"x0": 40, "x1": 80, "z0": 36, "z1": 68,
			"kl": [Color("#C9E7EC"), Color("#BCDFE6")]},
		"kijk": Vector2(60, 52),
		"deuren": [{"naar": "keuken", "wand": "z", "at": 62, "breed": 12}],
		"decor": [
			{"n": "wasmachine", "x": 14, "z": 7}, {"n": "wasmachine", "x": 30, "z": 7},
			{"n": "zeepplank", "x": 22, "z": 1, "ver": true},
			{"n": "strijkplank", "x": 86, "z": 8},
			{"n": "droogrekz", "x": 6, "z": 80},
			{"n": "tobbe", "x": 80, "z": 74}, {"n": "wasmand", "x": 94, "z": 66}]})
	# R2: de speelzaal.  Een houten zaal met een lichtblauwe speelmatted in het
	# midden, het klimrek en de ballenbak bij de achterwand, de toren en de
	# kussenhoek in de voorhoeken, de muziekdoos (toekomstige ingang van
	# `spiegel`) bij de verre muur en de wimpel hoog boven de dansvloer.  De
	# deur ligt aan de receptiezijde bij de plant in de verre hoek.
	_kamer({"id": "speelzaal", "naam": "Speelzaal", "icoon": "🧸",
		"w": 114, "d": 100, "wand": 56, "vloer": "hout", "loop": 1.5,
		"matten": {"x0": 20, "x1": 94, "z0": 18, "z1": 82,
			"kl": [Color("#BFE3F2"), Color("#AEDAEC")]},
		"zones": {"dans": {"x0": 40, "x1": 74, "z0": 56, "z1": 80}},
		"deuren": [{"naar": "receptie", "wand": "z", "at": 57, "breed": 12}],
		"decor": [
			{"n": "klimrek", "x": 16, "z": 14},
			{"n": "ballenbak", "x": 96, "z": 14},
			{"n": "blokkentoren", "x": 12, "z": 86},
			{"n": "kussenhoek", "x": 100, "z": 86},
			{"n": "muziekdoos", "x": 57, "z": 90},
			{"n": "wimpel", "x": 30, "z": 50}]})
	# R3: de Kas 🪴, the glass house behind the hotel (PLAN.md §3.5; the garden
	# was rebuilt on 2026-09-23, so its door is in the facade, not in a side
	# fence).  Glass walls on a brick knee wall, a tiled floor with a terracotta
	# path from the garden door to the front, the vegetable beds along the back
	# wall (zone `rijen`), the strawberry planter along the left wall and the
	# pumpkins in the front corner.  Two games live here, and their tables stand
	# where `mijd` keeps the floor free: the picking table of `oogst` in front of
	# the strawberries, the scale of `weeg` on the right (world.md §5.1, their
	# resting props).
	_kamer({"id": "kas", "naam": "Kas", "icoon": "🪴", "w": 128, "d": 112,
		"wand": 40, "vloer": "tegel", "loop": 1.25, "glas": true,
		"matten": [{"x0": 50, "x1": 66, "z0": 0, "z1": 112,
			"kl": [Color("#DDA88C"), Color("#D39B7E")]}],
		"kijk": Vector2(58, 48),
		"zones": {"rijen": {"x0": 12, "x1": 102, "z0": 3, "z1": 17}},
		# the picking table in front of the strawberries (`oogst`), the balance
		# and its row of weights (`weeg`)
		"mijd": [{"x0": 16, "x1": 44, "z0": 19, "z1": 57},
			{"x0": 68, "x1": 112, "z0": 32, "z1": 76},
			{"x0": 74, "x1": 122, "z0": 54, "z1": 102}],
		"deuren": [{"naar": "tuin", "wand": "z", "at": 52, "breed": 12}],
		"decor": [
			{"n": "zonnebloem", "x": 6, "z": 6},
			{"n": "moesbak", "x": 28, "z": 10, "params": {"groei": 3}},
			{"n": "moesbak", "x": 86, "z": 10, "params": {"groei": 2}},
			{"n": "potkast", "x": 118, "z": 5},
			{"n": "hangplant", "x": 28, "z": 1, "y": 22, "ver": true},
			{"n": "hangplantz", "x": 1, "z": 76, "y": 22, "ver": true},
			{"n": "aardbeienbakz", "x": 7, "z": 38},
			{"n": "gieter", "x": 14, "z": 66},
			{"n": "zaadkist", "x": 118, "z": 20},
			{"n": "pompoenen", "x": 114, "z": 100},
			{"n": "kruiwagen", "x": 22, "z": 104}]})
	_bouw_tuin(_kamers["tuin"])
	_bouw_zwembad(_kamers["zwembad"])
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
	r.hek_x = int(o.get("hek_x", HEK_X))
	r.hek_z = int(o.get("hek_z", HEK_Z))
	r.matten = o.get("matten", {})
	r.bad = o.get("bad", {})
	r.gevel = o.get("gevel", {})
	r.uitzicht = o.get("uitzicht", [])
	r.kijk = o.get("kijk", Vector2(-1.0, -1.0))
	r.balie = o.get("balie", {})
	r.vrij_z0 = int(o.get("vrij_z0", 0))
	r.glas = bool(o.get("glas", false))
	r.mijd = o.get("mijd", [])
	r.dek = o.get("dek", {})
	r.zones = o.get("zones", {})
	r.deuren = o.get("deuren", [])
	r.ingang = o.get("ingang", {})
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

## The pool's fence runs along the BACK long side of the water, from one
## post past the corner by the startblok to the far end of the room (owner,
## 2026-09-23: "zet het hek aan de bovenste zijkant van het zwembad niet aan
## de korte kant bij de startblokken").  Nothing stands by the startblok: the
## short side has no fence, only the rose arch of the gate to the garden in
## its line (door at z 60..72), so the walk from the gate to the stair stays
## open, and the corner over the block stays free for the block's own 🏊
## button — on a phone a post in that corner stood under it.  Until
## 2026-09-23 it was the other way round: a side fence along the startblok
## and, behind the water, only the posts beyond its two ends (2026-09-17:
## "Haal het hek gedeelte dat op het zwembad zit weg").  The line is the
## room's own `hek_z`, further off the water than the garden's.
func _bouw_zwembad(r: Kamer) -> void:
	var x := int(r.bad["x0"]) + 14
	while x + 12 <= r.w:
		r.decor.append({"n": "hekx", "x": x, "z": r.hek_z, "hek": true})
		x += 14
	var rnd := Sommen.Prng.new(TUFT_ZAAD + 7)
	for i in 12:
		var px := 16 + JsGetal.rond(rnd.volgende() * (r.w - 24))
		var pz := 58 + JsGetal.rond(rnd.volgende() * (r.d - 62))
		if absf(px - 116) + absf(pz - 56) < 18 or absf(px - 12) + absf(pz - 56) < 18 \
				or absf(px - 26) + absf(pz - 58) < 18 \
				or absf(px - 136) + absf(pz - 80) < 14:
			continue
		r.decor.append({"n": "pol%d" % (i % 5), "x": px, "z": pz, "pol": true})

## world.md §1.3 — the fence and the 30 grass tufts, deterministic, once.
##
## The left side is the hotel's back wall (owner, 2026-09-23), so where the
## garden has a `gevel` on x = 0 there is no side fence, and the back fence
## starts one post earlier, at the wall's corner.  The tufts keep clear of
## every piece of fixed decor that stands on the lawn — the big props, the
## doormat, the pool things behind the fence — read from the decor list, so a
## prop that moves takes its clear patch with it.
func _bouw_tuin(r: Kamer) -> void:
	var gevel_x := str(r.gevel.get("wand", "")) == "x"
	if not gevel_x:
		var z := HEK_Z
		while z <= 130:
			if z < 34 or z > 46:
				r.decor.append({"n": "hekz", "x": HEK_X, "z": z, "hek": true})
			z += 14
	var x := HEK_X if gevel_x else 24
	while x <= 130:
		if x < 38 or x > 50:
			r.decor.append({"n": "hekx", "x": x, "z": HEK_Z, "hek": true})
		x += 14
	var groot: Array = []
	for stuk in r.decor:
		if not stuk.get("ver", false) and not stuk.get("hek", false):
			groot.append([float(stuk["x"]), float(stuk["z"])])
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
