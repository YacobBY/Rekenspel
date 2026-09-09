extends Node2D
## The room in view, inside the world SubViewport.
##
## Layers, in drawing order (world.md §0 painter's algorithm):
##   Vloer      one baked plate: floor tiles + both back walls   (W1/W4)
##   Ver        wall decor, always behind everything             (`ver: 1`)
##   Objecten   y_sort_enabled -> depth = x + z, for free
##   Voor       overlays: the water band over a swimmer, particles
##
## W1 replaces the placeholder floor below with the baked plate of world.md
## §1.4 and fills Objecten from Rooms + World.

const VOORBEELD_GAST := "gast1"

@onready var vloer: Node2D = $Vloer
@onready var objecten: Node2D = $Objecten

var _gast: WereldObject = null
var _decor: Array[WereldObject] = []
var _los: Dictionary = {}          ## id -> WereldObject, a game's loose decor
var _los_versie := -1

func _ready() -> void:
	World.registreer_viewport(get_parent() as SubViewport, self)
	World.kader_veranderd.connect(_op_kader)
	World.getekend.connect(_ververs)

func bouw(kamer_id: String) -> void:
	for k in objecten.get_children():
		k.queue_free()
	_decor.clear()
	_gast = null
	var r := Rooms.get_kamer(kamer_id)
	if r == null:
		return
	for stuk in r.decor:
		var o := WereldObject.new()
		var s := Sprite2D.new()
		s.name = "Beeld"
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		o.add_child(s)
		objecten.add_child(o)
		o.zet_model(stuk["n"], stuk.get("params", {}))
		o.plaats(stuk["x"], stuk["z"], stuk.get("y", 0))
		_decor.append(o)
	var d := World.dier(VOORBEELD_GAST)
	if d != null:
		var g := WereldObject.new()
		var gs := Sprite2D.new()
		gs.name = "Beeld"
		gs.centered = false
		gs.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		g.add_child(gs)
		objecten.add_child(g)
		g.zet_model(d.model, d.params, Vector2(8, 5))
		g.plaats(d.x, d.z, 0.0)
		_gast = g
	queue_redraw()

func gast_vlak() -> Rect2:
	return Rect2() if _gast == null else _gast.vlak()

func _op_kader(_rect: Rect2, _schaal: Dictionary) -> void:
	for o in _decor:
		o.ververs()
	if _gast != null:
		_gast.ververs()
	queue_redraw()

## Loose decor of the running game (World.decor) becomes nodes like anything
## else; the version counter is the redraw-on-change rule for them.
func _ververs_los() -> void:
	if World.decor_versie() == _los_versie:
		for o in _los.values():
			o.ververs()
		return
	_los_versie = World.decor_versie()
	var gezien := {}
	for stuk in World.decor_lijst(World.kamer_nu()):
		var id: String = stuk["id"]
		gezien[id] = true
		var o: WereldObject = _los.get(id)
		if o == null:
			o = WereldObject.new()
			var s := Sprite2D.new()
			s.name = "Beeld"
			s.centered = false
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			o.add_child(s)
			objecten.add_child(o)
			_los[id] = o
		o.zet_model(stuk["model"], stuk["params"])
		o.diepte_bias = 0.3 if stuk["hoog"] > 0.0 else 0.0
		o.plaats(stuk["x"], stuk["z"], stuk["hoog"])
	for id in _los.keys():
		if not gezien.has(id):
			_los[id].queue_free()
			_los.erase(id)

func _ververs() -> void:
	var d := World.dier(VOORBEELD_GAST)
	if _gast != null and d != null:
		_gast.face = d.face
		_gast.plaats(d.x, d.z, d.hoogte)
	for o in _decor:
		o.ververs()
	_ververs_los()
	vloer.queue_redraw()

func _draw() -> void:
	pass
