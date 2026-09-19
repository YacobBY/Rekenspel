class_name UiRekenbalk
extends Control
## De rekenbalk: het papier onder de wereld (PLAN.md §3.1).
##
## One `Control` over the WHOLE world frame, sitting between the catch areas
## and the buttons, that paints nothing but a strip along the bottom edge.  It
## carries no hotspot and catches no finger (`MOUSE_FILTER_IGNORE`), and that
## is the whole reason it is built this way: `Hits.MAX_PER_KAMER` is 16 and the
## kitchen already sits against that ceiling, so the bar may not become one
## more hotspot.  §3.1: "de balk kost nul hotspots".
##
## This node is NOT what makes the bar exist.  `Ui.balk_rect()` is a pure
## function of `World.kader_rect()` and of the card that is docked, so the bar
## is just as real in the test files that never build this node — the geometry
## lives in `Ui`, this layer only paints it.
##
## The owner's rule of 2026-09-19, which is what this whole task turns on:
## **the bar may only cost the world space while a card really stands in it.**
## With no card docked, `Ui.balk_kost()` is 0, the world is fitted into the
## whole frame, and this node paints nothing at all.
##
## Two slots are left empty here so the tasks after this one have a home:
## `zet_kaart()` (`B5`: the pointer from the bar to the object it is about,
## and the ring around that object) and the `Nu` chip (`B6`:
## `Hotel.volgende_stap()`).

const RONDING := 18      ## the two top corners of the strip
const RAND := 2          ## the line along the top edge
const LIJN := 22         ## the ruled pitch; the same as UiSomkaart.LIJN

var _kaart := Rect2()    ## where the card docks; `B5` draws the pointer from here
var _nu: Button = null   ## the `Nu` chip of `B6`; hidden until it has words
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
	# The strip is a function of the frame, so a frame change is a redraw; the
	# node keeps no size of its own to compare against.
	World.kader_veranderd.connect(_op_kader)
	resized.connect(queue_redraw)
	queue_redraw()

func _op_kader(_rect: Rect2, _schaal: Dictionary) -> void:
	queue_redraw()

## The strip in this layer's own coordinates.  `Ui` owns the geometry; this
## node only ever asks.  Empty while there is no frame or no docked card.
func balk_rect() -> Rect2:
	return Ui.balk_rect()

## `B3`/`B5` hand in where the sum card landed; `B5` draws the pointer from
## there to the object.  An empty rectangle means no card is in the bar.
func zet_kaart(rect: Rect2) -> void:
	if rect.is_equal_approx(_kaart):
		return
	_kaart = rect
	queue_redraw()

func kaart_rect() -> Rect2:
	return _kaart

## The chip `B6` fills with words.  It exists from now on so that task only
## has to give it a label, not a place.
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
	# One rounded rectangle drawn by the engine: the strip runs off the bottom
	# of the frame, so only its two top corners are rounded.
	draw_style_box(_vlak, r)
	# Squared paper, the same 22 unit pitch and the same pale blue as the card
	# standing on it, so the two read as one sheet torn from the same pad.
	var y := r.end.y - float(LIJN)
	while y > r.position.y + float(LIJN) * 0.5:
		draw_line(Vector2(r.position.x + 12.0, y), Vector2(r.end.x - 12.0, y),
			UiThema.PAPIER_LIJN, 1.0)
		y -= float(LIJN)
