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
var _warm := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

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
