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
## True while this card is the one docked in the maths bar (`B4`).  In that
## stand it brings no panel of its own — the bar's paper is already behind it —
## no ruled lines, and it reads its sizes from `UiThema.balk_maten` instead of
## the little chrome table.
var in_balk := false
var _balk := {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	if not Ui.rust_modus() and DisplayServer.get_name() != "headless" and is_inside_tree() and not Engine.is_editor_hint():
		pivot_offset = custom_minimum_size * 0.5
		scale = Vector2(0.92, 0.92)
		modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 1.0, 0.12)

## `o` is the somkaart option dictionary; `smal` is true below a 360 unit frame.
func bouw(o: Dictionary, mt: Dictionary, smal: bool) -> void:
	in_balk = bool(o.get("in_balk", false))
	_balk = UiThema.balk_maten(World.kader_rect().size) if in_balk else {}
	# On a narrow frame the card takes the frame width minus its margins, never
	# less than BREED_KLEIN: a 28-character F4 sentence must stay on one line
	# (I2, kraam at 360×740).  In the bar the width is the bar's own: minus a
	# 24 unit gutter, or the left block in shape `laag`.
	var breed := BREED
	if in_balk:
		var b := Ui.balk_rect()
		breed = b.size.x - 24.0
		if str(_balk.get("vorm", "hoog")) == "laag":
			breed = b.size.x * UiThema.BALK_LAAG_LINKS
		# The card fills the bar it sits in: the sentence gets the whole width
		# and never wraps to a second line inside the strip (B4).
		custom_minimum_size = Vector2(breed, 0)
	elif smal:
		breed = clampi(int(World.kader_rect().size.x) - 24, BREED_KLEIN, BREED)
	if in_balk:
		# The bar paints the paper; the card adds nothing but its text.
		var kaal := StyleBoxFlat.new()
		kaal.bg_color = Color(0, 0, 0, 0)
		add_theme_stylebox_override("panel", kaal)
	else:
		add_theme_stylebox_override("panel", _papier())
	var kolom := VBoxContainer.new()
	kolom.name = "Kolom"
	kolom.add_theme_constant_override("separation", 0 if in_balk else (2 if smal else 4))
	add_child(kolom)

	var zin_grootte := int(mt["klein"])
	var som_grootte := int(mt["somlijn"])
	var vak_grootte := int(mt["somvak"])
	if in_balk:
		zin_grootte = int(_balk["zin"])
		som_grootte = int(_balk["som"])
		vak_grootte = int(_balk["som"])

	regel_label = Label.new()
	regel_label.name = "Regel"
	regel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	regel_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	regel_label.custom_minimum_size = Vector2(0, 0)
	regel_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regel_label.add_theme_font_size_override("font_size", zin_grootte)
	regel_label.add_theme_color_override("font_color", UiThema.INKT)
	icoon = str(o.get("icoon", ""))
	regel_label.text = _zin(icoon, str(o.get("regel", "")))
	kolom.add_child(regel_label)

	# A second SHORT sentence is allowed when another number belongs to it (a
	# stock, for instance).  Three sentences never exist (HOTEL.md §9).  In the
	# bar the second line rides along with the first: the bar is sized (B4) to
	# hold zin + regel2 + som + the answer strip, so `regel2` stays visible.
	regel2_label = Label.new()
	regel2_label.name = "Regel2"
	regel2_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	regel2_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	regel2_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regel2_label.add_theme_font_size_override("font_size", zin_grootte)
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
	# In the bar the somlijn never shrinks: that shrink bought room for a keypad
	# that no longer exists (B4).
	som_label.add_theme_font_size_override("font_size", som_grootte if in_balk
		else (mt["somlijn"] if not smal else maxi(UiThema.VLOER, int(mt["somlijn"]) - 4)))
	som_label.add_theme_color_override("font_color", UiThema.INKT)
	rij.add_child(som_label)

	vak_label = Label.new()
	vak_label.name = "Vak"
	vak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vak_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if in_balk:
		vak_label.custom_minimum_size = Vector2(40, int(_balk["som"]) + 4)
	else:
		vak_label.custom_minimum_size = Vector2(32, 32) if smal else Vector2(40, 34)
	vak_label.add_theme_font_size_override("font_size", vak_grootte if in_balk
		else (mt["somvak"] if not smal else maxi(UiThema.VLOER, int(mt["somvak"]) - 4)))
	vak_label.add_theme_color_override("font_color", UiThema.INKT)
	# the box shows the number the child tapped; a strip of WORDS needs no box
	vak_label.visible = bool(o.get("vak", (o.get("keuzes", []) as Array).is_empty()))
	_verf_vak()
	rij.add_child(vak_label)

	# No empty ruled line left behind: a card without a sum shows no sum row
	# (B4 — was band 3, the was end-card, the zwembad start card).
	som_label.visible = not som_label.text.is_empty()
	_ververs_rij()

	hulp_label = Label.new()
	hulp_label.name = "Hulp"
	hulp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hulp_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	hulp_label.add_theme_font_size_override("font_size", zin_grootte)
	hulp_label.add_theme_color_override("font_color", UiThema.INKT2)
	hulp_label.visible = false
	kolom.add_child(hulp_label)

	if in_balk:
		# The bar is one tight stack: no extra line spacing anywhere on it, so
		# the sentence, the sum and the buttons all fit in the bar's height.
		for l in [regel_label, regel2_label, som_label, hulp_label]:
			l.add_theme_constant_override("line_spacing", 0)
	max_cijfers = int(o.get("max", 2))
	# The sentence decides the width: it wraps at the card maximum instead of
	# being cut, and nothing forces the card wider than the sentence needs.
	regel_label.custom_minimum_size = Vector2(_zin_breedte(regel_label, int(breed)), 0)
	if regel2_label.visible:
		regel2_label.custom_minimum_size = Vector2(_zin_breedte(regel2_label, int(breed)), 0)

## The sum row is only there when there is something in it: a sum or an answer
## box.  `Ui.Kaart.som()` keeps this true when it fills the line later (B4).
func zet_som(tekst: String) -> void:
	if som_label != null:
		som_label.text = tekst
		som_label.visible = not tekst.is_empty()
	_ververs_rij()

func _ververs_rij() -> void:
	var r := get_node_or_null("Kolom/Rij")
	if r != null:
		r.visible = (som_label != null and som_label.visible) \
			or (vak_label != null and vak_label.visible)

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
	sb.shadow_color = UiThema.SCHADUW_KL
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
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
	if goed and vak_label != null and not Ui.rust_modus() and DisplayServer.get_name() != "headless" and is_inside_tree():
		vak_label.pivot_offset = vak_label.size * 0.5
		vak_label.scale = Vector2(1.15, 1.15)
		var tw := vak_label.create_tween()
		tw.tween_property(vak_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func zet_af() -> void:
	_af = true
	add_theme_stylebox_override("panel", _papier())

# ------------------------------------------------------------------ slepen

## The card catches the finger (MOUSE_FILTER_STOP) and Godot stops a drop at the
## first such Control, so a card lying over a bowl swallowed the biscuit (Z1).
## It hands the drop on to the catch area underneath it, like every hotspot
## Control does.
func _can_drop_data(at: Vector2, lading: Variant) -> bool:
	return Hits.vang_onder(get_global_position() + at, lading) != null

## In the TARGET's own coordinates, never the card's `at`.
func _drop_data(at: Vector2, lading: Variant) -> void:
	var punt := get_global_position() + at
	var v := Hits.vang_onder(punt, lading)
	if v != null:
		v._drop_data(punt - v.get_global_position(), lading)

## The ruled paper, drawn over the panel (CanvasItem calls `_draw` after the
## container painted its stylebox).
func _draw() -> void:
	if in_balk:
		return   # the bar is the paper; the card draws no ruled lines (B4)
	var y := float(LIJN)
	while y < size.y - 2.0:
		draw_line(Vector2(4, y), Vector2(size.x - 4, y), UiThema.PAPIER_LIJN, 1.0)
		y += LIJN
