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

func bouw(o: Dictionary, mt: Dictionary, tap: int) -> void:
	theme_type_variation = "Hotknop"
	text = str(o.get("icoon", ""))
	tooltip_text = str(o.get("titel", o.get("label", "")))
	custom_minimum_size = Vector2(tap, tap)
	clip_text = false
	add_theme_font_size_override("font_size", mt["icoon_bron"])
	sleep_naam = str(o.get("sleep", o.get("drop", "")))
	sleep_data = o.get("data", {})
	var rij := HBoxContainer.new()
	rij.name = "Tellers"
	rij.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rij.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	rij.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(rij)
	_telling = _pil(UiThema.KAART, mt["klein"])
	rij.add_child(_telling)
	_hand_label = _pil(UiThema.MUNT, UiThema.VLOER)
	rij.add_child(_hand_label)
	zet(int(o.get("aantal", 0)), int(o.get("hand", 0)))

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
		_hand_label.text = "☝ %d" % hand
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
