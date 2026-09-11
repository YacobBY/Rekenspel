class_name UiSomkaart
extends PanelContainer
## The sum card: one line of squared paper hanging ON the object
## (HOTEL.md §9, world.md §5.5, art-sound-rules.md §16.6).
##
## Structure — the node names are part of the contract, `Ui.Kaart` addresses
## them:  Kolom/Regel · Kolom/Rij/Som · Kolom/Rij/Vak · Kolom/Hulp.
##
## The mandatory sentence is a `Label` with word wrapping and no ellipsis: on a
## narrow phone the sentence takes a second line rather than shrinking, because
## "het dier blijft zichtbaar" beats "de zin op één regel" (art §17.1).

signal ok_getikt()

const BREED := 290       ## the card's own maximum, in units
const BREED_KLEIN := 170 ## below a 360 unit frame (art §16.6)
const LIJN := 22         ## the ruled paper pitch

var regel_label: Label
var regel2_label: Label
var som_label: Label
var vak_label: Label
var hulp_label: Label
var max_cijfers := 2
var icoon := ""
var _goed := false
var _af := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

## `o` is the somkaart option dictionary; `smal` is true below a 360 unit frame.
func bouw(o: Dictionary, mt: Dictionary, smal: bool) -> void:
	# On a narrow frame the card takes the frame width minus its margins, never
	# less than BREED_KLEIN: a 28-character F4 sentence must stay on one line
	# (I2, kraam at 360×740).
	var breed := BREED
	if smal:
		breed = clampi(int(World.kader_rect().size.x) - 24, BREED_KLEIN, BREED)
	add_theme_stylebox_override("panel", _papier())
	var kolom := VBoxContainer.new()
	kolom.name = "Kolom"
	kolom.add_theme_constant_override("separation", 2 if smal else 4)
	add_child(kolom)

	regel_label = Label.new()
	regel_label.name = "Regel"
	regel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	regel_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	regel_label.custom_minimum_size = Vector2(0, 0)
	regel_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regel_label.add_theme_font_size_override("font_size", mt["klein"])
	regel_label.add_theme_color_override("font_color", UiThema.INKT)
	icoon = str(o.get("icoon", ""))
	regel_label.text = _zin(icoon, str(o.get("regel", "")))
	kolom.add_child(regel_label)

	# A second SHORT sentence is allowed when another number belongs to it (a
	# stock, for instance).  Three sentences never exist (HOTEL.md §9).
	regel2_label = Label.new()
	regel2_label.name = "Regel2"
	regel2_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	regel2_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	regel2_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regel2_label.add_theme_font_size_override("font_size", mt["klein"])
	regel2_label.add_theme_color_override("font_color", UiThema.INKT)
	regel2_label.text = str(o.get("regel2", ""))
	regel2_label.visible = not regel2_label.text.is_empty()
	kolom.add_child(regel2_label)

	var rij := HBoxContainer.new()
	rij.name = "Rij"
	rij.add_theme_constant_override("separation", 6)
	kolom.add_child(rij)

	som_label = Label.new()
	som_label.name = "Som"
	som_label.text = str(o.get("som", ""))
	som_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	som_label.add_theme_font_size_override("font_size", mt["somlijn"] if not smal else maxi(UiThema.VLOER, mt["somlijn"] - 4))
	som_label.add_theme_color_override("font_color", UiThema.INKT)
	rij.add_child(som_label)

	vak_label = Label.new()
	vak_label.name = "Vak"
	vak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vak_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vak_label.custom_minimum_size = Vector2(32, 32) if smal else Vector2(40, 34)
	vak_label.add_theme_font_size_override("font_size", mt["somvak"] if not smal else maxi(UiThema.VLOER, mt["somvak"] - 4))
	vak_label.add_theme_color_override("font_color", UiThema.INKT)
	vak_label.visible = bool(o.get("keuzes", []).is_empty())
	_verf_vak()
	rij.add_child(vak_label)

	hulp_label = Label.new()
	hulp_label.name = "Hulp"
	hulp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hulp_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	hulp_label.add_theme_font_size_override("font_size", mt["klein"])
	hulp_label.add_theme_color_override("font_color", UiThema.INKT2)
	hulp_label.visible = false
	kolom.add_child(hulp_label)

	max_cijfers = int(o.get("max", 2))
	# The sentence decides the width: it wraps at the card maximum instead of
	# being cut, and nothing forces the card wider than the sentence needs.
	regel_label.custom_minimum_size = Vector2(_zin_breedte(regel_label, breed), 0)
	if regel2_label.visible:
		regel2_label.custom_minimum_size = Vector2(_zin_breedte(regel2_label, breed), 0)

## How wide the sentence line may become before it wraps.  The measurement is
## synchronous (`Font.get_string_size`), so the card knows its shape before its
## first draw — there is no "measure after one paint and then shove".
func _zin_breedte(l: Label, breed: int) -> int:
	var f := l.get_theme_font("font")
	var maat: int = l.get_theme_font_size("font_size")
	if f == null:
		return breed - 20
	var nodig := f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, maat).x
	return int(clampf(nodig, 60.0, float(breed - 20)))

static func _zin(pictogram: String, regel: String) -> String:
	return ("%s %s" % [pictogram, regel]).strip_edges()

## Replace the sentence, keeping the pictogram first on that same line (F4).
func zet_regel(regel: String) -> void:
	if regel_label != null:
		regel_label.text = _zin(icoon, regel)

func zet_regel2(regel: String) -> void:
	if regel2_label != null:
		regel2_label.text = regel
		regel2_label.visible = not regel.is_empty()

func _papier() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiThema.KAART_AF if _af else UiThema.PAPIER
	sb.border_color = UiThema.PAPIER_RAND
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_right = 14
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 7
	sb.content_margin_bottom = 9
	return sb

func _verf_vak() -> void:
	if vak_label == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiThema.VAK_GOED if _goed else UiThema.VAK
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = UiThema.MUNT_D if _goed else UiThema.VAK_ONDER
	sb.border_width_bottom = 4
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	vak_label.add_theme_stylebox_override("normal", sb)

func zet_goed(goed: bool) -> void:
	_goed = goed
	_verf_vak()

func zet_af() -> void:
	_af = true
	add_theme_stylebox_override("panel", _papier())

## The ruled paper, drawn over the panel (CanvasItem calls `_draw` after the
## container painted its stylebox).
func _draw() -> void:
	var y := float(LIJN)
	while y < size.y - 2.0:
		draw_line(Vector2(4, y), Vector2(size.x - 4, y), UiThema.PAPIER_LIJN, 1.0)
		y += LIJN
