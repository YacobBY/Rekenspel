class_name UiSpelbalk
extends PanelContainer
## The game bar: while a minigame runs it takes the ROOM BAR's place in the
## shell — under the frame, or beside it as the rail — with the `⬅ Terug`
## button first and the game's name beside it (owner, 2026-09-18).
##
## That is why it lives in the chrome and not in the world frame: the frame is
## the sum's, a fixed strip inside it fought every card for the same corner on a
## phone, and the room chips are exactly the icons that mean nothing while the
## child is counting.  One place for "back" on every screen, always the same,
## is what lets a six-year-old leave a game without reading anything.
##
## It takes the room bar's minimum size on purpose, so the world frame keeps
## its exact size when a game starts or ends: nothing in the room moves.
##
## A game with an animal of the turn gets ONE more button here: that animal,
## `🐶 Boef 🔄` — tap it and the next animal takes the turn (owner, 2026-09-23:
## "een methode om te wisselen met welk dier je de spellen speelt").  It is only
## there when there IS another animal to switch to: a button that cannot do
## anything is no button.

var terug_knop: Button = null
var titel_label: Label = null
var speler_knop: Button = null     ## the animal of the turn; hidden when there is none
var _doos: BoxContainer = null
var _rail := false

func _init() -> void:
	name = "Spelbalk"
	mouse_filter = Control.MOUSE_FILTER_STOP

## Build (or rebuild after a breakpoint change).  `terug` runs when the child
## taps the button; `rail` stacks the two under each other beside the frame.
## `wissel` runs when the child taps the animal (`zet_speler` shows it).
func bouw(icoon: String, titel: String, mt: Dictionary, tap: int, terug: Callable,
		rail := false, wissel := Callable()) -> void:
	for k in get_children():
		remove_child(k)
		k.queue_free()
	_rail = rail
	# As flat as the room bar: the chips have no panel around them either, and
	# the bar must not be one unit taller than the row it replaces.
	add_theme_stylebox_override("panel",
		UiThema.vulling(UiThema.vlak(Color(0, 0, 0, 0), 0, 0), 0, 0))
	_doos = VBoxContainer.new() if rail else HBoxContainer.new()
	_doos.name = "Doos"
	_doos.add_theme_constant_override("separation", 6 if rail else 10)
	_doos.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_doos)

	terug_knop = Button.new()
	terug_knop.name = "Terug"
	terug_knop.theme_type_variation = "Hotknop"
	terug_knop.text = UiTekst.TERUG
	terug_knop.tooltip_text = UiTekst.TERUG_TITEL
	terug_knop.clip_text = false
	terug_knop.custom_minimum_size = Vector2(tap, tap)
	terug_knop.focus_mode = Control.FOCUS_ALL
	terug_knop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	terug_knop.add_theme_font_size_override("font_size", mt["knop"])
	if terug.is_valid():
		terug_knop.pressed.connect(func() -> void:
			Snd.tik()
			terug.call())
	_doos.add_child(terug_knop)

	titel_label = Label.new()
	titel_label.name = "Titel"
	titel_label.text = ("%s %s" % [icoon, titel]).strip_edges()
	titel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titel_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titel_label.add_theme_font_size_override("font_size", mt["klein"])
	titel_label.add_theme_color_override("font_color", UiThema.INKT)
	if rail:
		titel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		titel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titel_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_doos.add_child(titel_label)

	# The animal of the turn: the same kind of button as `⬅ Terug`, after the
	# name.  The switch runs deferred, because it rebuilds this very bar.
	speler_knop = Button.new()
	speler_knop.name = "Speler"
	speler_knop.theme_type_variation = "Hotknop"
	speler_knop.tooltip_text = UiTekst.SPELER_TITEL
	speler_knop.clip_text = false
	speler_knop.custom_minimum_size = Vector2(tap, tap)
	speler_knop.focus_mode = Control.FOCUS_ALL
	speler_knop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speler_knop.add_theme_font_size_override("font_size", mt["knop"])
	speler_knop.visible = false
	if wissel.is_valid():
		speler_knop.pressed.connect(func() -> void:
			Snd.tik()
			wissel.call_deferred())
	_doos.add_child(speler_knop)

## The animal of the turn on the bar: its pictogram, its name and the 🔄 that
## says "another one".  An empty name hides the button.  In the rail beside the
## frame the name goes under the pictures, so the button keeps the rail's width.
func zet_speler(icoon: String, naam: String) -> void:
	if speler_knop == null:
		return
	speler_knop.visible = not naam.is_empty()
	speler_knop.text = "" if naam.is_empty() else UiTekst.speler_knop(icoon, naam, _rail)

## The room bar's footprint, so the frame does not move: its height under the
## frame, its width as the rail.  The name goes when the row is too narrow for
## both — the button is the point.
func neem_maat(maat: Vector2, breed_beschikbaar: float) -> void:
	custom_minimum_size = maat
	if titel_label != null:
		titel_label.visible = true
		if breed_beschikbaar > 0.0 and get_combined_minimum_size().x > breed_beschikbaar:
			titel_label.visible = false
