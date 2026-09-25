class_name UiVangvlak
extends Control
## The catch area of a hotspot that accepts a drop (world.md §5.4 step 8,
## architecture.md §10).
##
## A button stands ABOVE its object, never on it; a child dragging a biscuit
## aims at the bowl, not at the label over it.  So every hotspot with a `drop`
## gets a transparent rectangle = the union of button and object, in its own
## layer UNDER the buttons.  A real button therefore always wins a tap, and a
## drop lands wherever the child aimed.

var drop := ""              ## the name a dragged item must carry
var data: Dictionary = {}
var val: Callable           ## fn(lading: Dictionary) — the game's drop handler
## The hotspot's button, when a tap on the object presses it (`tik_vlak`, the
## hotel's bowls and doors; owner, 2026-09-25: "er staat 'Tik op het bakje'
## maar wanneer ik op het bakje tik gebeurt er niks. Ik moet op de speech
## bubbel eronder drukken").  `null`: only drops land here.
var knop: BaseButton = null
var _warm := false
var _druk_op := Vector2.INF

## A press that travels further than this before it is let go is no tap.
const TIK_AF := 12.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

## A tap on the object is a tap on its button: the same signal, so the same
## click, the same `[probe] tik` and the same handler — the hotel's own or the
## one a game borrowed it with.  Of the catch areas under the finger the
## smallest wins (`Hits.tik_onder`), as for a drop.
func _gui_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if knop == null or mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_druk_op = mb.position
		return
	var van := _druk_op
	_druk_op = Vector2.INF
	if van == Vector2.INF or mb.position.distance_to(van) > TIK_AF:
		return
	if get_viewport() != null and get_viewport().gui_is_dragging():
		return
	var doel := Hits.tik_onder(get_global_transform() * mb.position)
	if doel == null or doel.knop == null or not is_instance_valid(doel.knop) or doel.knop.disabled:
		return
	accept_event()
	doel.knop.emit_signal("pressed")

func _can_drop_data(_at: Vector2, lading: Variant) -> bool:
	if drop.is_empty() or typeof(lading) != TYPE_DICTIONARY:
		return false
	var goed: bool = str((lading as Dictionary).get("sleep", "")) == drop
	if goed != _warm:
		_warm = goed
		queue_redraw()
	return goed

func _drop_data(_at: Vector2, lading: Variant) -> void:
	_warm = false
	queue_redraw()
	if val.is_valid():
		Ui.roep(val, [lading, data])

## `drop-hot`: the target lights up while a drag hovers it.
func _draw() -> void:
	if _warm:
		draw_rect(Rect2(Vector2.ZERO, size), Color(UiThema.MUNT_D, 0.22), true)
		draw_rect(Rect2(Vector2.ZERO, size), UiThema.MUNT_D, false, 2.0)
