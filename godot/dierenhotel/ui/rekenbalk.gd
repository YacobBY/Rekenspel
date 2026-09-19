class_name UiRekenbalk
extends Control
## The maths bar: the paper strip under the world (PLAN.md §3.1).
##
## One Control over the WHOLE world frame, between the catch areas and the
## buttons, that draws nothing but the strip along the bottom edge.  It carries
## no hotspot and catches no finger (`MOUSE_FILTER_IGNORE`), which is the point:
## `MAX_PER_KAMER` is 16 and the kitchen already sits against that ceiling.
##
## The strip is NOT what makes the bar exist.  `Ui.balk_rect()` is derived from
## `World.kader_rect()` alone, so the bar is just as real in the thirteen test
## files that never build this node — this layer only paints it (§3.1, "het gat
## dat de kritiek vond").
##
## Two slots stay empty in this task, so that the tasks after it have somewhere
## to dock: `zet_kaart(rect)` (`B3`: the sum card and its answer strip) and the
## hidden `Nu` chip (`B6`: `Hotel.volgende_stap()`).  `B5` adds the pointer to
## the object, the ring around it and the ruled lines.

const RONDING := 18      ## the two top corners of the strip
const RAND := 2          ## the line along the top edge

var _kaart := Rect2()    ## where the card docks (B3); empty = no card
var _nu: Button = null   ## the Nu chip (B6); invisible until it has something to say
var _vlak: StyleBoxFlat = null

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_nu = Button.new()
	_nu.name = "Nu"
	_nu.visible = false
	_nu.focus_mode = Control.FOCUS_NONE
	_nu.theme_type_variation = &"Kamerchip"
	add_child(_nu)
	# The height comes from the frame, so a frame change is a redraw — the node
	# keeps no size of its own to compare against.
	World.kader_veranderd.connect(_op_kader)
	resized.connect(queue_redraw)
	queue_redraw()

func _op_kader(_rect: Rect2, _schaal: Dictionary) -> void:
	queue_redraw()

## The strip in this layer's own coordinates: the bottom `Ui.balk_hoog()` units
## of the frame.  Empty while there is no frame yet (the shell before its first
## `World.meet`), and never taller than the frame itself.
func balk_rect() -> Rect2:
	var maat := size
	if maat.x < 1.0 or maat.y < 1.0:
		maat = World.kader_rect().size
	var h := minf(Ui.balk_hoog(), maat.y)
	if h <= 0.0 or maat.x < 1.0:
		return Rect2()
	return Rect2(Vector2(0.0, maat.y - h), Vector2(maat.x, h))

## `B3` hands in where the sum card landed; `B5` draws the pointer from there to
## the object.  An empty rectangle means there is no card in the bar.
func zet_kaart(rect: Rect2) -> void:
	if rect.is_equal_approx(_kaart):
		return
	_kaart = rect
	queue_redraw()

func kaart_rect() -> Rect2:
	return _kaart

## The chip `B6` fills.  It exists from now on so that task only has to give it
## words, not a place.
func nu_knop() -> Button:
	return _nu

func _draw() -> void:
	var r := balk_rect()
	if r.size.x < 1.0 or r.size.y < 1.0:
		return
	if _vlak == null:
		_vlak = StyleBoxFlat.new()
		_vlak.bg_color = UiThema.PAPIER
		_vlak.corner_radius_top_left = RONDING
		_vlak.corner_radius_top_right = RONDING
		_vlak.border_width_top = RAND
		_vlak.border_color = UiThema.PAPIER_RAND
	# One rounded rectangle, drawn by the engine: the strip runs off the bottom
	# of the frame, so only the two top corners are rounded.
	draw_style_box(_vlak, r)
