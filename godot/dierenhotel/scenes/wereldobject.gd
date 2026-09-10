class_name WereldObject
extends Node2D
## One thing in the room: a guest, a piece of decor, a game's own loose decor.
##
## The node sits on the object's FLOOR point, so the parent's y-sorting is
## exactly the painter's algorithm of world.md §0 (depth = x + z).  The sprite
## child carries the plate offset, the anchor and the lift (a jump, a swimmer,
## a sleeper on a mattress), so lifting never changes the depth.

var model := ""
var params: Dictionary = {}
var rot := 0             ## 0..3 quarter turns about y (world.md §1.7)
var vx := 0.0            ## floor voxel x
var vz := 0.0            ## floor voxel z
var vy := 0.0            ## height in voxels (jump +, swim -)
var anker := Vector2.ZERO ## the model voxel that must land on (vx, vz)
var face := 1
var diepte_bias := 0.0   ## +0.3 for decor with a height, +0.5 for a sleeper

var _plaat = null
var _sleutel := ""
var _bron: Callable          ## optional: fn(g) -> Art.Plaat, for a split plate
var _bron_sleutel: Callable  ## ... and its cache key

@onready var beeld: Sprite2D = $Beeld

## Build the node the world uses, sprite child and all, in one call.
static func maak(naam: String = "stuk") -> WereldObject:
	var o := WereldObject.new()
	o.name = naam
	var s := Sprite2D.new()
	s.name = "Beeld"
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	o.add_child(s)
	return o

func _ready() -> void:
	if get_node_or_null("Beeld") == null:
		var s := Sprite2D.new()
		s.name = "Beeld"
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(s)
		beeld = s

func zet_model(naam: String, p: Dictionary = {}, a := Vector2.ZERO, r: int = 0) -> void:
	model = naam
	params = p
	anker = a
	rot = r
	ververs()

## A plate that is not a plain model: the two halves of the feeding bowl come
## out of `Art.kom(niveau, g, voor)`, which needs a face-level split.
## `sleutel()` is the change key, `maak(g)` bakes.
func zet_bron(sleutel: Callable, maak: Callable, a := Vector2.ZERO) -> void:
	_bron_sleutel = sleutel
	_bron = maak
	anker = a
	ververs()

func plaats(x: float, z: float, y: float = 0.0) -> void:
	vx = x
	vz = z
	vy = y
	ververs()

## Re-read the plate when the model, its params or the voxel size changed, and
## put the sprite where it belongs.  Nothing else touches the texture: that is
## the redraw-on-change rule of art-sound-rules.md §11.7 for objects.
func ververs() -> void:
	if beeld == null:
		beeld = get_node_or_null("Beeld")
	if beeld == null or (model.is_empty() and not _bron.is_valid()):
		return
	var sch := World.schaal()
	var g: int = sch["g"]
	var sleutel := "%s|%d" % [_bron_sleutel.call(), g] if _bron.is_valid() \
		else "%s|%d|%d|%s" % [model, g, rot, JSON.stringify(params)]
	if sleutel != _sleutel:
		_sleutel = sleutel
		_plaat = _bron.call(g) if _bron.is_valid() else World.plaat(model, g, params, rot)
		beeld.texture = null if _plaat == null else _plaat.tex
	var plaat = _plaat
	if plaat == null:
		return
	beeld.flip_h = face < 0
	# The depth bias only changes where the node SORTS, never where it is seen:
	# the sprite is shifted back by exactly the same amount.
	var scheef := diepte_bias * (Art.S / 2.0) * g
	position = World.scherm(vx, vz, 0.0) + Vector2(0.0, scheef)
	var ankerpx := Vector2(
		(anker.x - anker.y) * Art.S * g,
		(anker.x + anker.y) * (Art.S / 2.0) * g)
	beeld.position = Vector2(plaat.dx, plaat.dy) - ankerpx \
		- Vector2(0.0, vy * Art.HG * g + scheef)
	if beeld.flip_h:
		beeld.position.x = -plaat.dx - plaat.w + ankerpx.x

## The object's screen rectangle in frame units — Hits needs it to keep a
## button completely off its object.
func vlak() -> Rect2:
	if beeld == null or beeld.texture == null:
		return Rect2()
	var dicht: float = World.schaal()["dicht"]
	return Rect2((position + beeld.position) / dicht, beeld.texture.get_size() / dicht)
