extends Node
## World — camera, scale, the room in view and the animal runtime.  Autoload #4.
## Port of `demos/dierenhotel/world.js` (world.md §0, §1.9, §2).
##
## The world is drawn inside a SubViewport of `kader * dicht` canvas pixels and
## shown in a TextureRect of `kader` units, exactly reproducing HOTEL.md §1:
## voxels are rasterised at the whole number `g` and the canvas is then scaled
## down smoothly.  `schaal()` is the only source of scale numbers a game may
## read; never the device pixel ratio.
##
## W1 fills in: the eight rooms in view, guests, idle wandering, sleeping,
## bowls, the door graph walk (`reis`), the camera slide of world.md §1.9 and
## the redraw-on-change fingerprint.  The skeleton implements the scale/camera
## maths, the projection and a single walking animal.

signal kader_veranderd(rect: Rect2, schaal: Dictionary)
signal kamer_veranderd(kamer: String)
signal getekend()

const TIK := 1.0 / 15.0     ## world.js STAP: one think tick
const MAX_INHAAL := 3       ## at most 3 catch-up ticks per frame
const KADER_ONDER := 132    ## css-px reserved under the room (keypad band)
const WAND_ZICHT := 56      ## voxel-px of wall that must stay visible
const KADER_MIN := 200
const DICHT_KLEIN := 900    ## short side under this -> density lower bound 2

var _kamer_nu: String = ""
var _kader := Rect2()
var _schaal := {"g": 3, "dicht": 2.0, "k": 1.5, "q": 1.5,
		"pxPerVoxelX": 3.0, "pxPerVoxelY": 1.5, "pxPerHoogte": 3.0, "kamer": ""}
var _cam := Vector2.ZERO           ## camera origin in canvas px
var _viewport: SubViewport = null
var _kamerscene: Node2D = null
var _dieren: Dictionary = {}       ## id -> Dier
var _tijd := 0.0
var _tikken := 0
var _vuil := true

class Dier extends RefCounted:
	var id: String
	var kamer: String
	var x: float
	var z: float
	var face := 1
	var pose := "rust"
	var staat := "stil"
	var bob := 0.0
	var lift := 0.0
	var hoogte := 0.0
	var model := "proef_dier"
	var params: Dictionary = {}
	var _punten: Array = []
	var _opdracht: Object = null   ## Opdracht, resolved true/false

## The awaitable movement order.  `await World.stappen(...)` gives a bool:
## true = the last point was reached, false = another order took over.
class Opdracht extends RefCounted:
	signal af(gehaald: bool)
	var klaar := false
	func rond(gehaald: bool) -> void:
		if klaar:
			return
		klaar = true
		af.emit(gehaald)

# ------------------------------------------------------------------ opzet

func registreer_viewport(vp: SubViewport, scene: Node2D) -> void:
	_viewport = vp
	_kamerscene = scene

func _process(delta: float) -> void:
	_tijd += delta
	var tikken := 0
	while _tijd >= TIK and tikken < MAX_INHAAL:
		_tijd -= TIK
		tikken += 1
		_tikken += 1
		_tik()
	if _tijd > TIK * 6.0:
		_tijd = 0.0
	if _vuil and _kamerscene != null:
		_kamerscene.queue_redraw()
		_vuil = false
		getekend.emit()
	Hits.plaats()

func vuil() -> void:
	_vuil = true

# ------------------------------------------------------------ kader en maat

## Called by the world frame Control whenever its rectangle changes.
func meet(rect: Rect2) -> void:
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	var oud := _kader
	_kader = rect
	_bereken_schaal()
	if _viewport != null:
		var canvas := Vector2i(
			maxi(1, JsGetal.rond(rect.size.x * _schaal["dicht"])),
			maxi(1, JsGetal.rond(rect.size.y * _schaal["dicht"])))
		if _viewport.size != canvas:
			_viewport.size = canvas
	_cam = cam_doel(Rooms.get_kamer(_kamer_nu))
	_vuil = true
	if oud != _kader:
		kader_veranderd.emit(_kader, _schaal)

func kader_rect() -> Rect2:
	return _kader

func hermeet() -> void:
	meet(_kader)

## `World.schaal()` — {g, dicht, k, q, pxPerVoxelX, pxPerVoxelY, pxPerHoogte}.
func schaal() -> Dictionary:
	return _schaal.duplicate()

func px_per_hoogte() -> float:
	return _schaal["pxPerHoogte"]

## world.md §1.9 `schermDicht()`, with the tablet cap of art-sound-rules §18.3.
func scherm_dicht() -> float:
	var dpr := 1.0
	if DisplayServer.has_method("screen_get_scale"):
		dpr = maxf(1.0, DisplayServer.screen_get_scale())
	var kort := minf(_kader.size.x, _kader.size.y)
	if dpr > 2.0 and kort < DICHT_KLEIN:
		return 2.0
	return minf(3.0, dpr)

## world.md §1.9 `maatVan()`: q, then the whole-number g, then dicht.
func _bereken_schaal() -> void:
	var r := Rooms.get_kamer(_kamer_nu)
	var d := scherm_dicht()
	var box_w := 200.0
	var nodig_h := 150.0
	if r != null:
		var box := Rooms.kader(r)
		box_w = float(box[1] - box[0])
		nodig_h = float(box[3] - box[2]) - maxf(0.0, float(-box[2] - WAND_ZICHT))
	var q := minf((maxf(240.0, _kader.size.x) - 4.0) / box_w,
			maxf(120.0, _kader.size.y - 4.0) / nodig_h)
	q = maxf(q, 0.01)
	var ng := clampi(JsGetal.rond(q * d), 2, 4)
	if float(ng) / d < q * 0.9:
		ng = clampi(JsGetal.plafond(q * d), 2, 4)
	var dicht := maxf(d, float(ng) / q)
	var k := float(ng) / dicht
	_schaal = {"g": ng, "dicht": dicht, "k": k, "q": k,
			"pxPerVoxelX": 2.0 * k, "pxPerVoxelY": k, "pxPerHoogte": 2.0 * k,
			"kamer": _kamer_nu}

## world.md §1.9 `camDoel()` — the floor stays whole; bare wall is cut at the top.
func cam_doel(r: Rooms.Kamer) -> Vector2:
	if r == null or _viewport == null:
		return Vector2.ZERO
	var box := Rooms.kader(r)
	var g: int = _schaal["g"]
	var dicht: float = _schaal["dicht"]
	var w := float(_viewport.size.x)
	var h := float(_viewport.size.y)
	var cx := w / 2.0 - float(box[0] + box[1]) / 2.0 * g
	var over := h - float(box[3] - box[2]) * g
	var onder := minf(KADER_ONDER * dicht, maxf(0.0, over))
	var cy := (over - onder) / 2.0 - float(box[2]) * g if over >= 0.0 else h - 4.0 - float(box[3]) * g
	return Vector2(cx, cy)

func cam() -> Vector2:
	return _cam

# ------------------------------------------------------------- projectie

## Canvas px inside the world SubViewport (world.md §0).
func scherm(x: float, z: float, y: float = 0.0) -> Vector2:
	var g: float = float(_schaal["g"])
	return Vector2(
		_cam.x + (x - z) * Art.S * g,
		_cam.y + (x + z) * (Art.S / 2.0) * g - y * Art.HG * g)

## The same point in frame units (css px) — what a hotspot or card uses.
func mik_punt(x: float, z: float, y: float = 0.0) -> Vector2:
	return scherm(x, z, y) / _schaal["dicht"]

## The screen rectangle a model occupies, in frame units.  Hotspots need it to
## guarantee 0 % coverage; it comes straight from the baked plate.
func vlak_van(model: String, x: float, z: float, y: float, params: Dictionary = {}) -> Rect2:
	var p := Art.plaat(model, _schaal["g"], params)
	if p == null:
		return Rect2()
	var dicht: float = _schaal["dicht"]
	var mid := scherm(x, z, y)
	return Rect2(Vector2(mid.x + p.dx, mid.y + p.dy) / dicht, Vector2(p.w, p.h) / dicht)

# ------------------------------------------------------------------ kamers

func kamer_nu() -> String:
	return _kamer_nu

func naar(kamer_id: String) -> void:
	if not Rooms.bestaat(kamer_id) or kamer_id == _kamer_nu:
		return
	_kamer_nu = kamer_id
	_bereken_schaal()
	hermeet()
	kamer_veranderd.emit(kamer_id)
	# W1: the 300 ms ease-in-out camera slide of world.md §1.9.

# ------------------------------------------------------------------ dieren

# ------------------------------------------------------------- los decor
##
## `World.decor(kamer, o)` — a game's own loose decor (world.md §1.7).  Not
## saved; owned by the game that placed it; wiped when another game starts.
## Implemented here because the vertical slice and every wave-2 game need it;
## W1 adds `rot`, the depth bias for `hoog`, and the `ver` layer.

const LOS_MAX := 48                ## pieces of loose decor per room

var _decor: Dictionary = {}        ## kamer -> {id -> stuk}
var _decor_versie := 0

## Create or update one piece.  Returns a COPY, or {} on: unknown room, missing
## id, unknown model, a piece owned by another game, or a full room.
func decor(kamer_id: String, o: Dictionary) -> Dictionary:
	if not Rooms.bestaat(kamer_id):
		return {}
	var id: String = o.get("id", "")
	var model: String = o.get("model", "")
	if id.is_empty() or not Art.heeft_model(model):
		return {}
	if not _decor.has(kamer_id):
		_decor[kamer_id] = {}
	var kamer: Dictionary = _decor[kamer_id]
	var door: String = o.get("door", Games.actief())
	if kamer.has(id) and kamer[id]["door"] != door:
		return {}
	if not kamer.has(id) and kamer.size() >= LOS_MAX:
		return {}
	var stuk := {
		"id": id, "model": model, "kamer": kamer_id,
		"x": float(o.get("x", 0.0)), "z": float(o.get("z", 0.0)),
		"hoog": float(o.get("hoog", o.get("y", 0.0))),
		"rot": int(o.get("rot", 0)), "ver": bool(o.get("ver", false)),
		"params": o.get("params", {}), "door": door,
	}
	kamer[id] = stuk
	_decor_versie += 1
	_vuil = true
	return stuk.duplicate(true)

func decor_weg(kamer_id: String, id: String) -> bool:
	if not _decor.has(kamer_id) or not _decor[kamer_id].has(id):
		return false
	_decor[kamer_id].erase(id)
	_decor_versie += 1
	_vuil = true
	return true

func decor_lijst(kamer_id: String = "") -> Array:
	var uit: Array = []
	for k in _decor.keys():
		if kamer_id != "" and k != kamer_id:
			continue
		for stuk in _decor[k].values():
			uit.append(stuk.duplicate(true))
	return uit

## Where a piece stands, for a hotspot that hangs on it (`World.mik`).
func decor_plek(id: String, kamer_id: String = "") -> Dictionary:
	for k in _decor.keys():
		if kamer_id != "" and k != kamer_id:
			continue
		if _decor[k].has(id):
			return _decor[k][id].duplicate(true)
	return {}

func decor_wis_eigenaar(door: String) -> void:
	for k in _decor.keys():
		for id in _decor[k].keys():
			if _decor[k][id]["door"] == door:
				_decor[k].erase(id)
	_decor_versie += 1
	_vuil = true

## Bumped on every change; the room scene rebuilds its nodes when it moves.
func decor_versie() -> int:
	return _decor_versie

# ------------------------------------------------------------------ dieren

func zet(id: String, kamer: String, x: float, z: float) -> Dier:
	var d: Dier = _dieren.get(id)
	if d == null:
		d = Dier.new()
		d.id = id
		_dieren[id] = d
	_breek(d, false)
	d.kamer = kamer
	d.x = x
	d.z = z
	d.staat = "stil"
	_vuil = true
	return d

func dier(id: String) -> Dier:
	return _dieren.get(id)

func dieren(kamer: String = "") -> Array:
	var uit: Array = []
	for d in _dieren.values():
		if kamer == "" or d.kamer == kamer:
			uit.append(d)
	return uit

## `World.loopNaar(id, x, z, o)` — awaitable.  See `stappen`.
func loop_naar(id: String, x: float, z: float, o: Dictionary = {}) -> bool:
	return await stappen(id, [Vector2(x, z)], o)

## `World.stappen(id, punten, o)` — walk a list of points in the animal's own
## room.  Returns true when the last point was reached, false as soon as another
## order takes the animal over.  Never throws, never rejects.
##
## A game MUST re-check `actief` after every await (architecture.md §5.4).
func stappen(id: String, punten: Array, o: Dictionary = {}) -> bool:
	var d: Dier = _dieren.get(id)
	if d == null:
		return false
	if punten.is_empty():
		return true
	_breek(d, false)
	var op := Opdracht.new()
	d._opdracht = op
	d._punten = punten.duplicate()
	d.staat = "loop"
	d.pose = o.get("pose", "loopA")
	_vuil = true
	var gehaald: bool = await op.af
	return gehaald

## ---- the rest of the movement API (world.md §2.5) -------------------------
## Signatures are final (architecture.md §6.4); the bodies are W1's.

## Walk inside the current room, then take state `na`.
func ga(_id: String, _x: float, _z: float, _na: String = "") -> bool:
	push_warning("World.ga: W1")            # W1
	return false

## Walk through the doors to another room.  Returns the path it will take.
func reis(_id: String, _kamer: String, _o: Dictionary = {}) -> Array:
	push_warning("World.reis: W1")          # W1
	return []

## Go to bed: walk to the bed's standing place, then lie down on the mattress.
func slaap(_id: String, _kamer: String, _slot: String) -> bool:
	push_warning("World.slaap: W1")         # W1
	return false

## Walk to the eating place and eat.
func feed(_ids: Array) -> void:
	push_warning("World.feed: W1")          # W1

## Walk to a free place and be happy there.
func solo(_id: String, _act: String = "") -> bool:
	push_warning("World.solo: W1")          # W1
	return false

## 'sad' | 'happy' | 'idle' — sulk at the sulking place, bounce, or resume.
func mood(_id: String, _stemming: String) -> bool:
	push_warning("World.mood: W1")          # W1
	return false

## One pose for `duur` ticks (15 ticks = 1 s).  Minimal: sets the pose; W1 adds
## the duration, the return to the previous state and the reduced-motion path.
func pose(id: String, naam: String, _duur: int = 0) -> bool:
	var d: Dier = _dieren.get(id)
	if d == null:
		return false
	d.pose = naam                            # W1: duur, terugval, rustmodus
	_vuil = true
	return true

## Any new order supersedes the running one (world.md §2.5).
func _breek(d: Dier, gehaald: bool) -> void:
	if d._opdracht != null:
		var op: Opdracht = d._opdracht
		d._opdracht = null
		d._punten = []
		op.rond(gehaald)

func _tik() -> void:
	for d in _dieren.values():
		if d._punten.is_empty():
			continue
		var doel: Vector2 = d._punten[0]
		var r := Rooms.get_kamer(d.kamer)
		var loop := 1.0 if r == null else r.loop
		var stap := 1.3 * loop   # voxels per tick; W1: the real accel/brake model
		var naar_doel := Vector2(doel.x - d.x, doel.y - d.z)
		if naar_doel.length() <= stap:
			d.x = doel.x
			d.z = doel.y
			d._punten.pop_front()
			if d._punten.is_empty():
				d.staat = "stil"
				d.pose = "rust"
				_breek(d, true)
		else:
			var stapv := naar_doel.normalized() * stap
			d.x += stapv.x
			d.z += stapv.y
			d.face = 1 if (stapv.x - stapv.y) >= 0.0 else -1
			d.pose = "loopA" if (_tikken / 4) % 2 == 0 else "loopB"
		_vuil = true
