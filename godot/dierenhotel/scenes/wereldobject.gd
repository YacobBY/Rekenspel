class_name WereldObject
extends Node2D
## One thing in the room: a guest, a piece of decor, a game's own loose decor.
##
## The node sits on the object's FLOOR point, so the parent's y-sorting is
## exactly the painter's algorithm of world.md §0 (depth = x + z).  The sprite
## child carries the plate offset and the lift (a jump, a swimmer, a sleeper in
## a bed), so lifting never changes the depth.

var model := ""
var params: Dictionary = {}
var vx := 0.0            ## floor voxel x
var vz := 0.0            ## floor voxel z
var vy := 0.0            ## height in voxels (jump +, swim -)
var anker := Vector2.ZERO ## the model voxel that must land on (vx, vz)
var face := 1
var diepte_bias := 0.0   ## +0.3 for decor with a height, +0.5 for a sleeper

var _plaat = null
var _g := 0

@onready var beeld: Sprite2D = $Beeld

func _ready() -> void:
	if get_node_or_null("Beeld") == null:
		var s := Sprite2D.new()
		s.name = "Beeld"
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(s)
		beeld = s

func zet_model(naam: String, p: Dictionary = {}, a := Vector2.ZERO) -> void:
	model = naam
	params = p
	anker = a
	_plaat = null
	ververs()

func plaats(x: float, z: float, y: float = 0.0) -> void:
	vx = x
	vz = z
	vy = y
	ververs()

## Re-read the plate for the current scale and put the sprite where it belongs.
func ververs() -> void:
	if beeld == null or model.is_empty():
		return
	var sch := World.schaal()
	var g: int = sch["g"]
	if _plaat == null or _g != g:
		_plaat = Art.plaat(model, g, params)   # redraw-on-change: only on a scale change
		_g = g
		if _plaat != null:
			beeld.texture = _plaat.tex
	var plaat = _plaat
	if plaat == null:
		return
	beeld.flip_h = face < 0
	position = World.scherm(vx, vz, 0.0) + Vector2(0.0, diepte_bias * sch["k"])
	var ankerpx := Vector2(
		(anker.x - anker.y) * Art.S * g,
		(anker.x + anker.y) * (Art.S / 2.0) * g)
	beeld.position = Vector2(plaat.dx, plaat.dy) - ankerpx - Vector2(0.0, vy * Art.HG * g)
	if beeld.flip_h:
		beeld.position.x = -plaat.dx - plaat.w + ankerpx.x

## The object's screen rectangle in frame units — Hits needs it to keep a
## button completely off its object.
func vlak() -> Rect2:
	if beeld == null or beeld.texture == null:
		return Rect2()
	var dicht: float = World.schaal()["dicht"]
	return Rect2((position + beeld.position) / dicht, beeld.texture.get_size() / dicht)
