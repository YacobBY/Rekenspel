class_name UiWolk
extends PanelContainer
## A speech bubble on an object or an animal (world.md §5.6).
## One row: pictogram · number · sentence — the pictogram always sits in the
## same bubble as its word or number (HOTEL.md §9), never scattered.

const BREED := 290
const BREED_KLEIN := 274
const ZIN_BREED := 228
const ZIN_BREED_KLEIN := 216

var icoon_label: Label
var getal_label: Label
var zeg_label: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func bouw(o: Dictionary, mt: Dictionary, smal: bool) -> void:
	var soort := str(o.get("klas", ""))
	var kleur := UiThema.WOLK
	if soort.contains("goed"):
		kleur = UiThema.WOLK_GOED
	elif soort.contains("hulp"):
		kleur = UiThema.WOLK_HULP
	var sb := StyleBoxFlat.new()
	sb.bg_color = kleur
	sb.corner_radius_top_left = 20
	sb.corner_radius_top_right = 20
	sb.corner_radius_bottom_right = 20
	sb.corner_radius_bottom_left = 6
	sb.set_border_width_all(2)
	sb.border_color = UiThema.WIT
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	add_theme_stylebox_override("panel", sb)

	var rij := HBoxContainer.new()
	rij.name = "Rij"
	rij.add_theme_constant_override("separation", 6)
	add_child(rij)

	icoon_label = Label.new()
	icoon_label.name = "Icoon"
	icoon_label.text = str(o.get("icoon", ""))
	icoon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icoon_label.add_theme_font_size_override("font_size", mt["icoon_wolk"])
	icoon_label.visible = not icoon_label.text.is_empty()
	rij.add_child(icoon_label)

	getal_label = Label.new()
	getal_label.name = "Getal"
	getal_label.text = "" if o.get("getal", null) == null else str(o.get("getal"))
	getal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	getal_label.add_theme_font_size_override("font_size", mt["getal"])
	getal_label.add_theme_color_override("font_color", UiThema.INKT)
	getal_label.visible = not getal_label.text.is_empty()
	rij.add_child(getal_label)

	zeg_label = Label.new()
	zeg_label.name = "Zeg"
	zeg_label.text = str(o.get("tekst", ""))
	zeg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	zeg_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	zeg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zeg_label.add_theme_font_size_override("font_size", mt["klein"])
	zeg_label.add_theme_color_override("font_color", UiThema.INKT)
	zeg_label.visible = not zeg_label.text.is_empty()
	var breed := ZIN_BREED_KLEIN if smal else ZIN_BREED
	var f := zeg_label.get_theme_font("font")
	if f != null and not zeg_label.text.is_empty():
		var nodig := f.get_string_size(zeg_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			zeg_label.get_theme_font_size("font_size")).x
		zeg_label.custom_minimum_size = Vector2(minf(nodig, float(breed)), 0)
	rij.add_child(zeg_label)
	tooltip_text = str(o.get("titel", ("%s %s %s" % [icoon_label.text, getal_label.text, zeg_label.text]).strip_edges()))
