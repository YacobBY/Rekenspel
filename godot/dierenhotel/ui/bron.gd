class_name UiBron
extends Button
## A drag source with a counter and an "in your hand" badge (world.md §5.6).
##
## `Ui.bron(obj, {icoon, aantal, hand, klas, prio, titel, tik, sleep})`;
## `zet(aantal, hand)` updates both counters, `weg()` removes it.  One tap
## delivers exactly once: Godot gives one `pressed` per tap, so the HTML's
## capture-phase click swallowing is gone (architecture.md §1.3 point 4).
##
## Dragging uses Godot's own Control drag-and-drop; the preview sits 40 units
## above the finger so a child can see the target (architecture.md §10).

const HEF := 40.0        ## the drag preview sits this far above the finger

var aantal := 0
var hand := 0
var sleep_naam := ""     ## what a drop target must accept
var sleep_data: Dictionary = {}
var _telling: Label = null
var _hand_label: Label = null
var _rij: HBoxContainer = null
var _tap := UiThema.HOT
var _naast := false      ## pills beside the sentence instead of under the pictogram

func bouw(o: Dictionary, mt: Dictionary, tap: int) -> void:
	theme_type_variation = "Hotknop"
	text = str(o.get("icoon", ""))
	tooltip_text = str(o.get("titel", o.get("label", "")))
	_tap = tap
	custom_minimum_size = Vector2(tap, tap)
	clip_text = false
	add_theme_font_size_override("font_size", mt["icoon_bron"])
	sleep_naam = str(o.get("sleep", o.get("drop", "")))
	sleep_data = o.get("data", {})
	# The pills live INSIDE the button.  They used to hang under it: a
	# `PRESET_BOTTOM_WIDE` row is a zero-height band pinned to the bottom edge,
	# and a Control smaller than its minimum grows towards `grow_vertical` —
	# which is END, downwards, by default.  So the 40 of the biscuit bag was
	# drawn under its own button, on the bowl `Hits` had put in the band below
	# (V6).  `inhoud_maat()` pins them back in and buys the room.
	var rij := HBoxContainer.new()
	rij.name = "Tellers"
	rij.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rij = rij
	_leg_rij(false)
	add_child(rij)
	_telling = _pil(UiThema.KAART, mt["klein"])
	_telling.name = "Telling"
	rij.add_child(_telling)
	_hand_label = _pil(UiThema.MUNT, UiThema.VLOER)
	_hand_label.name = "Hand"
	rij.add_child(_hand_label)
	zet(int(o.get("aantal", 0)), int(o.get("hand", 0)))

## Where the pills hang: in a strip under the pictogram, or at the end of the
## sentence.  The button's own text steps aside for them — it stays centred over
## the strip, and moves left of the pills.  `GROW_DIRECTION_BEGIN` is what keeps
## the row INSIDE: a row that is bigger than the zero-size band its anchors give
## it grows away from the edge it hangs on, not through it.
func _leg_rij(naast: bool) -> void:
	_naast = naast
	alignment = HORIZONTAL_ALIGNMENT_LEFT if naast else HORIZONTAL_ALIGNMENT_CENTER
	_rij.alignment = BoxContainer.ALIGNMENT_END if naast else BoxContainer.ALIGNMENT_CENTER
	_rij.grow_horizontal = Control.GROW_DIRECTION_BEGIN if naast else Control.GROW_DIRECTION_BOTH
	_rij.grow_vertical = Control.GROW_DIRECTION_BOTH if naast else Control.GROW_DIRECTION_BEGIN
	# the anchors alone, and then the offsets by hand: the `_and_offsets_` version
	# bakes the size the row happens to have at this instant into them, and
	# halfway through a placement pass that is last pass's size.
	_rij.set_anchors_preset(
		Control.PRESET_CENTER_RIGHT if naast else Control.PRESET_BOTTOM_WIDE, false)
	_rij.offset_left = 0.0
	_rij.offset_top = 0.0
	_rij.offset_right = 0.0
	_rij.offset_bottom = 0.0

## How big the source has to be, asked by `Hits` every placement pass
## (`hits.gd:_maat_van`).  A method and not a minimum size for the two reasons
## `ui/wolk.gd` writes out: a `Button` computes its minimum in C++ and never
## asks the script, and a `Label` has no font at all until it hangs in a themed
## tree — measured in `bouw()` the pills are 0 units tall.  Asked here, in the
## tree and after a game has changed the text, both are true.
##
## The pills get a strip of their own, and which side it comes off decides
## whether that strip is free.  `Hits` places in blocks of 52 x 56 units
## (`hits.gd` `RIJ`/`KOL`), so a button already pays for the whole block it
## stands in:
##
## * a bare **pictogram** (🧺, 🪙) is 48 wide and 59 tall — two bands high, one
##   column wide.  Under it there are 45 free units and beside it none, so the
##   strip goes under, over the full width.
## * a source that carries a whole **sentence** ("🍪 pak 1", "🧺 7 nog te
##   sorteren") is 36 units tall — one band, with 16 units to spare, too little
##   for a pill of 24 — and it is wide, so there are tens of free units at the
##   end of its column block.  There the strip stands beside the text.
##
## Get that the wrong way around and the busiest kitchen on a 558 x 289 frame
## loses a band and the "Opnieuw" button no longer finds a place
## (`games/voerkar/test_voerkar.gd::test_dekking_nul_in_vier_kaders`).
func inhoud_maat() -> Vector2:
	if _rij == null:
		return Vector2.ZERO
	# `get_minimum_size()` is the button's OWN minimum: its text and its stylebox,
	# and nothing we ever wrote.  `custom_minimum_size` is a different thing — what
	# a game demanded by hand (`games/kraam/spel.gd` gives every coin the same
	# width, `games/was/spel.gd` buys room for a pill of its own) AND what
	# `Hits.plaats()` handed back last pass.  So the strip is measured off the
	# button alone and that demand is laid over the answer afterwards: add it in
	# first and every pass would buy the strip again, twenty units wider each frame.
	var eis := custom_minimum_size
	var eigen := get_minimum_size()
	var pil := _rij.get_combined_minimum_size()
	var naast := eigen.x > eigen.y     # wider than tall = a sentence, not a glyph
	if naast != _naast:
		_leg_rij(naast)
	var nodig := Vector2(maxf(maxf(float(_tap), eigen.x), pil.x),
		maxf(maxf(float(_tap), eigen.y), pil.y))
	if naast:
		nodig.x = maxf(float(_tap), eigen.x) + pil.x
	else:
		nodig.y = maxf(float(_tap), eigen.y) + pil.y
	nodig = Vector2(maxf(nodig.x, eis.x), maxf(nodig.y, eis.y))
	custom_minimum_size = nodig
	return nodig

func _pil(kleur: Color, maat: int) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", maxi(UiThema.VLOER, maat))
	l.add_theme_color_override("font_color", UiThema.INKT)
	l.add_theme_stylebox_override("normal",
		UiThema.vulling(UiThema.vlak(kleur, 999, 2, UiThema.WIT), 5, 0))
	return l

func zet(n: int, in_hand: int = -1) -> void:
	aantal = n
	if in_hand >= 0:
		hand = in_hand
	if _telling != null:
		_telling.text = str(aantal)
		_telling.visible = aantal > 0
	if _hand_label != null:
		# one thing in hand is the pictogram alone (games-b §5.8); more is rare
		_hand_label.text = "☝" if hand <= 1 else "☝ %d" % hand
		_hand_label.visible = hand > 0

# ------------------------------------------------------------------ slepen

func _get_drag_data(_at: Vector2) -> Variant:
	if sleep_naam.is_empty() or aantal <= 0:
		return null
	var spook := Control.new()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", get_theme_font_size("font_size"))
	spook.add_child(l)
	l.position = Vector2(-l.get_combined_minimum_size().x * 0.5,
		-l.get_combined_minimum_size().y * 0.5 - HEF)
	set_drag_preview(spook)
	var lading := sleep_data.duplicate()
	lading["sleep"] = sleep_naam
	lading["bron"] = name
	return lading

## A source is a Button too, so a drop that lands on it dies there (Z1) — and a
## source often stands on the very thing it feeds.  Hand the drop on, same as
## `ui/hotknop.gd`.
func _can_drop_data(at: Vector2, lading: Variant) -> bool:
	return Hits.vang_onder(get_global_position() + at, lading) != null

## In the TARGET's own coordinates, never the source's `at`.
func _drop_data(at: Vector2, lading: Variant) -> void:
	var punt := get_global_position() + at
	var v := Hits.vang_onder(punt, lading)
	if v != null:
		v._drop_data(punt - v.get_global_position(), lading)
