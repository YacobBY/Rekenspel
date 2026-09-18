class_name UiHotKnop
extends Button
## A hotspot button: pictogram, word, and optionally a waiting badge.
##
## Never a lone pictogram (HOTEL.md §9), never under 48 × 48 units (44 only
## below a 360 unit frame, world.md §6.5), and its label never below 12 px —
## the floor lives here, not in a stylesheet a game could escape.

var badge_label: Label = null
var _icoon := ""
var _label := ""

func _ready() -> void:
	pressed.connect(_op_getikt)

func _op_getikt() -> void:
	if not Ui.rust_modus() and DisplayServer.get_name() != "headless" and is_inside_tree():
		pivot_offset = size * 0.5
		scale = Vector2(0.92, 0.92)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func bouw(o: Dictionary, mt: Dictionary, tap: int) -> void:
	theme_type_variation = "Hotknop"
	_icoon = str(o.get("icoon", ""))
	_label = str(o.get("label", ""))
	text = ("%s %s" % [_icoon, _label]).strip_edges()
	tooltip_text = str(o.get("titel", _label))
	custom_minimum_size = Vector2(tap, tap)
	clip_text = false
	add_theme_font_size_override("font_size", mt["klein"])
	focus_mode = Control.FOCUS_ALL
	zet_badge(o.get("badge", null))

## `badge` is the waiting-guest counter; `null` or 0 hides it.
func zet_badge(n: Variant) -> void:
	var tekst := "" if n == null else str(n)
	if tekst == "0":
		tekst = ""
	if tekst.is_empty():
		if badge_label != null:
			badge_label.visible = false
		return
	if badge_label == null:
		badge_label = Label.new()
		badge_label.name = "Badge"
		badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_label.add_theme_font_size_override("font_size", UiThema.VLOER)
		badge_label.add_theme_color_override("font_color", UiThema.INKT)
		badge_label.add_theme_stylebox_override("normal",
			UiThema.vulling(UiThema.vlak(UiThema.ZON, 999, 2, UiThema.WIT), 4, 0))
		badge_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge_label.position = Vector2(-6, -6)
		add_child(badge_label)
	badge_label.text = tekst
	badge_label.visible = true

func zet_label(icoon: String, label: String) -> void:
	_icoon = icoon
	_label = label
	text = ("%s %s" % [icoon, label]).strip_edges()

# ------------------------------------------------------------------ slepen

## A hotspot button stands OVER its own catch area, and Godot stops a drop at
## the first MOUSE_FILTER_STOP Control it meets — so a drop that landed on the
## button, exactly where a child aims, was refused in silence (Z1).  The button
## hands it on to the catch area under the finger itself: `Hits.vang_onder`
## picks the smallest one and lights it up while the finger hovers.
func _can_drop_data(at: Vector2, lading: Variant) -> bool:
	return Hits.vang_onder(get_global_position() + at, lading) != null

## In the TARGET's own coordinates, never the source's `at`.
func _drop_data(at: Vector2, lading: Variant) -> void:
	var punt := get_global_position() + at
	var v := Hits.vang_onder(punt, lading)
	if v != null:
		v._drop_data(punt - v.get_global_position(), lading)
