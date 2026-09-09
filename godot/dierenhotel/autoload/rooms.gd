extends Node
## Rooms — the eight rooms, their decor, slots, doors and furniture.
## Autoload #2.  Port of `demos/dierenhotel/rooms.js` (world.md §1).
##
## W1 fills this file: the eight rooms of world.md §1.1 with their exact
## w x d, wand, vloer and loop, the door graph of §1.2 (and `pad()` as a BFS),
## the fixed decor tables of §1.3 incl. the deterministic garden fence/tufts
## (Sommen.Prng, bit-identical), the floor colour rules of §1.4, `bouw_af()`
## (§1.5: box, deurPunten, vrij, plekkenLijst, standing places), `plek/hoogte`
## (§1.6) and the furniture API of §1.8.
##
## The skeleton ships ONE placeholder room so the vertical slice can run; it is
## deliberately not one of the eight (no real world content in the skeleton).

signal kamers_veranderd()      ## a room's derived data changed (furniture)

const MARGE := 12              ## free-cell grid margin (world.md §1.5)
const RASTER := 12             ## free-cell grid step

var _kamers: Dictionary = {}   ## id -> Kamer
var _volgorde: Array[String] = []
var _proef = preload("res://scenes/proef_modellen.gd").new()   ## W1 deletes this

class Kamer extends RefCounted:
	var id: String
	var naam: String
	var icoon: String
	var w: int
	var d: int
	var wand: int
	var vloer: String
	var loop: float = 1.0
	var decor: Array = []          ## {n, x, z, y, ver, params}
	var slots: Dictionary = {}     ## slotId -> {soort, model, x, z, sx, sz}
	var deuren: Array = []         ## {naar, wand, at, breed}
	var box: PackedInt32Array      ## [x0, x1, y0, y1] in voxel-px
	var plekken: Array = []        ## wander places [[x, z], ...]

func _ready() -> void:
	_proef.registreer()            # W1: the world's own models instead
	_bouw_proefkamer()

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

## world.md §1.1 — the room box in voxel-px, used by the camera.
func kader(r: Kamer) -> PackedInt32Array:
	return PackedInt32Array([
		-r.d * Art.S - 10, r.w * Art.S + 10,
		-r.wand * Art.HG - 12, JsGetal.rond((r.w + r.d) * (Art.S / 2.0)) + 10])

## world.md §1.2 — breadth-first over the door graph, start room included.
func pad(_van: String, _naar: String) -> Array[String]:
	push_warning("Rooms.pad: W1")   # W1
	return []

## world.md §1.4 — the colour of one 1x1 floor cell.
func vloer_kleur(_r: Kamer, _x: int, _z: int) -> Color:
	return Color("#E4CBA6")         # W1

# ------------------------------------------------------------------ meubels

func meubel_zet(_kamer_id: String, _type: String, _x: int, _z: int, _rot: int, _id: String) -> Dictionary:
	push_warning("Rooms.meubelZet: W2")   # W2
	return {}

func meubel_weg(_id: String) -> bool:
	return false                    # W2

func meubels(_kamer_id: String = "") -> Array:
	return []                       # W2

func herstel() -> void:
	pass                            # W2

# ------------------------------------------------------------- proefkamer

func _bouw_proefkamer() -> void:
	var r := Kamer.new()
	r.id = "proefkamer"
	r.naam = "Proefkamer"
	r.icoon = "🧪"
	r.w = 48
	r.d = 36
	r.wand = 24
	r.vloer = "hout"
	r.loop = 1.5
	r.decor = [
		{"n": "proef_blok", "x": 8, "z": 8, "params": {"n": 6, "kleur": Color("#A6CE8E")}},
		{"n": "proef_blok", "x": 40, "z": 8, "params": {"n": 4, "kleur": Color("#F5B0C2")}},
		{"n": "proef_blok", "x": 40, "z": 30, "params": {"n": 5, "kleur": Color("#C9CCDC")}},
	]
	r.box = kader(r)
	r.plekken = [[12, 12], [36, 12], [36, 28], [12, 28], [24, 20]]
	_kamers[r.id] = r
	_volgorde = ["proefkamer"]
