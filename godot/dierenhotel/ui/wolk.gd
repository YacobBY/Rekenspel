class_name UiWolk
extends Button
## A speech bubble on an object or an animal (world.md §5.6).
## One row: pictogram · number · sentence — the pictogram always sits in the
## same bubble as its word or number (HOTEL.md §9), never scattered.
##
## It is a real `Button` and not a panel (I1 finding 1).  A prikbord task card,
## the check-in question and every hotel bubble reach the child through
## `Hits.hotspot_getikt`, and that signal is only wired for a `BaseButton`; as a
## `PanelContainer` the bubble swallowed the tap with its own `mouse_filter` and
## nothing happened — the board was decoration.  Being a Button also gives it
## focus, the keyboard and the pressed sound for free.
##
## A Button lays out no children, so the row lives in a Control anchored to the
## whole rectangle and that row's size becomes this node's `custom_minimum_size`.

const BREED := 290
const BREED_KLEIN := 274
const ZIN_BREED := 228
const ZIN_BREED_KLEIN := 216
const RAND_X := 10       ## the bubble's own padding
const RAND_Y := 6

var icoon_label: Label
var getal_label: Label
var zeg_label: Label
var balk: ProgressBar = null    ## only on a "komt eraan" bubble (`voortgang`)
var _doos: MarginContainer
var _smal := false

func bouw(o: Dictionary, mt: Dictionary, smal: bool) -> void:
	var soort := str(o.get("klas", ""))
	var kleur := UiThema.WOLK
	if soort.contains("goed"):
		kleur = UiThema.WOLK_GOED
	elif soort.contains("hulp"):
		kleur = UiThema.WOLK_HULP
	text = ""
	clip_text = false
	focus_mode = Control.FOCUS_ALL
	for staat in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(staat, _vel(kleur, staat))

	_doos = MarginContainer.new()
	_doos.name = "Doos"
	_doos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_doos.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_doos.add_theme_constant_override("margin_left", RAND_X)
	_doos.add_theme_constant_override("margin_right", RAND_X)
	_doos.add_theme_constant_override("margin_top", RAND_Y)
	_doos.add_theme_constant_override("margin_bottom", RAND_Y)
	add_child(_doos)

	var rij := HBoxContainer.new()
	rij.name = "Rij"
	rij.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rij.add_theme_constant_override("separation", 6)
	if o.get("voortgang", null) == null:
		_doos.add_child(rij)
	else:
		# the row, and under it a bar that fills while a guest walks in from a
		# room you cannot see (owner, 2026-09-14)
		var kolom := VBoxContainer.new()
		kolom.name = "Kolom"
		kolom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		kolom.add_theme_constant_override("separation", 4)
		_doos.add_child(kolom)
		kolom.add_child(rij)
		balk = ProgressBar.new()
		balk.name = "Balk"
		balk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		balk.min_value = 0.0
		balk.max_value = 1.0
		balk.step = 0.001
		balk.show_percentage = false
		balk.custom_minimum_size = Vector2(0, 10)
		balk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		balk.add_theme_stylebox_override("background", UiThema.vlak(UiThema.KURK, 5))
		balk.add_theme_stylebox_override("fill", UiThema.vlak(UiThema.MUNT_D, 5))
		kolom.add_child(balk)
		zet_voortgang(float(o["voortgang"]))

	icoon_label = _regel("Icoon", str(o.get("icoon", "")), mt["icoon_wolk"])
	rij.add_child(icoon_label)

	getal_label = _regel("Getal", "" if o.get("getal", null) == null else str(o.get("getal")),
		mt["getal"])
	rij.add_child(getal_label)

	zeg_label = _regel("Zeg", str(o.get("tekst", "")), mt["wereld"])
	zeg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	zeg_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	rij.add_child(zeg_label)
	_smal = smal
	tooltip_text = str(o.get("titel", ("%s %s %s" % [icoon_label.text, getal_label.text,
		zeg_label.text]).strip_edges()))

## How big the bubble has to be, asked by `Hits` every placement pass.
##
## Two Godot facts make this a method instead of a minimum size: a `Button`
## computes its minimum in C++ and never asks the script, and a `Label` has no
## font at all until it hangs in a themed tree — measured in `bouw()` the
## sentence is 8 units wide and the bubble collapses to an empty 48 x 48 button.
## Asked here, in the tree, both are true.
func inhoud_maat() -> Vector2:
	if _doos == null or zeg_label == null:
		return Vector2.ZERO
	var breed := ZIN_BREED_KLEIN if _smal else ZIN_BREED
	var f := zeg_label.get_theme_font("font")
	if f != null and not zeg_label.text.is_empty():
		var nodig := f.get_string_size(zeg_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			zeg_label.get_theme_font_size("font_size")).x
		# BOTH sides, always: an autowrapping Label reports its height for the
		# width it happens to have, and a bubble built between two layout passes
		# has none — the board cards came back 441 units tall after "Verder
		# spelen" until this line pinned the height too (architecture.md §4.4).
		# A `Label` with autowrap reports its height for the width it CURRENTLY
		# has, and a bubble built between two layout passes has width 1: one
		# character per line, 375 units for four words — the board cards came
		# back 441 units tall after "Verder spelen".  So the sentence is measured
		# at the width it will really get, that measurement becomes its minimum,
		# and `clip_text` takes the Label's own guess out of the sum (Godot
		# reports height 1 for a clipping autowrap label).  It never actually
		# clips: the minimum below is the height it needs.
		var zin_breed := minf(nodig, float(breed))
		zeg_label.clip_text = true
		zeg_label.custom_minimum_size = Vector2(zin_breed,
			UiThema.wrap_hoogte(zeg_label, zin_breed))
	# the row measures itself, never the size a previous pass handed the button
	custom_minimum_size = Vector2.ZERO
	var nodig_maat := _doos.get_combined_minimum_size()
	# and then it is PINNED: a bubble that `Hits` never got to place (its guest
	# was in another room when it was made) must still be its own content and a
	# real tap target, not a 0 x 0 stylebox blob with the sentence spilling out
	# of it (V1 finding 1).
	custom_minimum_size = Vector2(maxf(nodig_maat.x, UiThema.HOT),
		maxf(nodig_maat.y, UiThema.HOT))
	return nodig_maat

## Pin the size the moment the bubble is in a themed tree, so it is never drawn
## before `Hits` has measured it.
func _ready() -> void:
	inhoud_maat()
	if not Ui.rust_modus() and DisplayServer.get_name() != "headless" and is_inside_tree() and not Engine.is_editor_hint():
		pivot_offset = custom_minimum_size * 0.5
		scale = Vector2(0.9, 0.9)
		modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 1.0, 0.12)

## How far the guest is, 0..1.
func zet_voortgang(f: float) -> void:
	if balk != null:
		balk.value = clampf(f, 0.0, 1.0)

func _regel(naam: String, tekst: String, maat: int) -> Label:
	var l := Label.new()
	l.name = naam
	l.text = tekst
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", maxi(UiThema.VLOER, maat))
	l.add_theme_color_override("font_color", UiThema.INKT)
	l.visible = not tekst.is_empty()
	return l

## The bubble shape: a rounded panel with the little tail corner bottom-left.
func _vel(kleur: Color, staat: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = kleur.lightened(0.06) if staat == "hover" else kleur
	if staat == "pressed":
		sb.bg_color = kleur.darkened(0.06)
	sb.corner_radius_top_left = 20
	sb.corner_radius_top_right = 20
	sb.corner_radius_bottom_right = 20
	sb.corner_radius_bottom_left = 6
	sb.set_border_width_all(2)
	sb.border_color = UiThema.INKT if staat == "focus" else UiThema.WIT
	sb.shadow_color = UiThema.SCHADUW_KL
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	if staat == "pressed":
		sb.shadow_size = 1
		sb.shadow_offset = Vector2(0, 1)
	return sb

