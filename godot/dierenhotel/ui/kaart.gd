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
const ONDER := 0.5       ## a ruled line lies this far under its baseline

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
## The minimum size of this card AS IT WOULD BE in the bar, cached so the bar
## can measure the candidate in bar-mode even while the card is drawn floating
## (a help line that arrived after the bar let go).  `Vector2.ZERO` = unknown;
## every content change clears it so the next measure recomputes.
var _maat_balk := Vector2.ZERO
var _o := {}
var _mt := {}
var _smal := false
## The live content of the lines a game may set AFTER the card opened
## (`som()`, `hulp()`, `zet_regel()`, `zet_regel2()`).  `_bouw` rebuilds the
## children from these, never from the stale option dictionary, so a re-render
## for the bar or back to floating keeps every line the card is showing — a
## help line that a rebuild dropped used to make the released card answer its
## Control minimum (a tower) to `Hits` (B4).
var _hulp := ""
var _som := ""
var _regel := ""
var _regel2 := ""
## The answer the child tapped, shown in the box.  A bar re-render rebuilds
## the box, so this live field is what keeps the number (or the ✓) on it.
var _vak := ""

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The ruled lines follow the text, so a card that moves is a paper to redraw.
	item_rect_changed.connect(_lijnen_verschoven)

func _ready() -> void:
	if not Ui.rust_modus() and DisplayServer.get_name() != "headless" and is_inside_tree() and not Engine.is_editor_hint():
		pivot_offset = custom_minimum_size * 0.5
		scale = Vector2(0.92, 0.92)
		modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 1.0, 0.12)

## `o` is the somkaart option dictionary; `smal` is true below a 360 unit frame.
## `balk` renders the card for the maths bar (B4): no panel, no ruled lines,
## the bar's own big sizes and the bar's own width.
func bouw(o: Dictionary, mt: Dictionary, smal: bool) -> void:
	_o = o
	_mt = mt
	_smal = smal
	# Seed the live content from the option dictionary; the setters below keep
	# it current so a re-render never drops a line the card is showing.
	_regel = str(o.get("regel", ""))
	_regel2 = str(o.get("regel2", ""))
	_som = str(o.get("som", ""))
	_bouw(bool(o.get("in_balk", false)))

## Re-render the card in the bar (`aan`) or floating on its object.  Called by
## the bar when it takes or releases the card, so the look always matches the
## dock state: a docked card is big and bare, a floating card keeps its paper.
func zet_balk_stand(aan: bool) -> void:
	if aan == in_balk:
		return
	_bouw(aan)

func _bouw(balk: bool) -> void:
	in_balk = balk
	_balk = UiThema.balk_maten(World.kader_rect().size) if balk else {}
	# A rebuild drops the children the previous stand made.
	for kind in get_children():
		remove_child(kind)
		kind.queue_free()
	# On a narrow frame the card takes the frame width minus its margins, never
	# less than BREED_KLEIN: a 28-character F4 sentence must stay on one line
	# (I2, kraam at 360×740).  In the bar the width is the bar's own: the
	# whole frame minus a 24 unit gutter, or the left block in shape `laag`.
	var breed := BREED
	if balk:
		var w := World.kader_rect().size.x
		breed = w - 24.0
		if str(_balk.get("vorm", "hoog")) == "laag":
			breed = w * UiThema.BALK_LAAG_LINKS
		custom_minimum_size = Vector2(breed, 0)
	else:
		if _smal:
			breed = clampi(int(World.kader_rect().size.x) - 24, BREED_KLEIN, BREED)
		# A floating card carries no width of its own: the sentence line sets
		# it (HEAD behaviour).  Clearing the bar's pinned width here is what
		# stops a card that docked at the bar width from floating on at that
		# width after the bar lets go — `Hits` would pin it and place the
		# card outside the frame (B4).
		custom_minimum_size = Vector2.ZERO
	if balk:
		# The bar paints the paper; the card adds nothing but its text.
		var kaal := StyleBoxFlat.new()
		kaal.bg_color = Color(0, 0, 0, 0)
		add_theme_stylebox_override("panel", kaal)
	else:
		add_theme_stylebox_override("panel", _papier())
	var kolom := VBoxContainer.new()
	kolom.name = "Kolom"
	kolom.add_theme_constant_override("separation", 0 if balk else (2 if _smal else 4))
	# A container sorts its children deferred, after the card may already have
	# drawn: the lines are redrawn once the text really stands where it stands.
	kolom.sort_children.connect(_lijnen_verschoven)
	add_child(kolom)

	var zin_grootte := int(_mt["klein"])
	var som_grootte := int(_mt["somlijn"])
	var vak_grootte := int(_mt["somvak"])
	if balk:
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
	icoon = str(_o.get("icoon", ""))
	regel_label.text = _zin(icoon, _regel)
	kolom.add_child(regel_label)

	# A second SHORT sentence is allowed when another number belongs to it (a
	# stock, for instance).  Three sentences never exist (HOTEL.md §9).  In the
	# `laag` bar there is no room for a second line beside the sum, so it is
	# dropped there with one warning (B4).
	regel2_label = Label.new()
	regel2_label.name = "Regel2"
	regel2_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	regel2_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	regel2_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regel2_label.add_theme_font_size_override("font_size", zin_grootte)
	regel2_label.add_theme_color_override("font_color", UiThema.INKT)
	regel2_label.text = _regel2
	regel2_label.visible = not regel2_label.text.is_empty()
	if balk and str(_balk.get("vorm", "hoog")) == "laag" and not regel2_label.text.is_empty():
		regel2_label.visible = false
		push_warning('somkaart "%s": regel2 vervalt in de lage balk' % str(_o.get("id", "")))
	kolom.add_child(regel2_label)

	var rij := HBoxContainer.new()
	rij.name = "Rij"
	rij.add_theme_constant_override("separation", 6)
	rij.sort_children.connect(_lijnen_verschoven)
	kolom.add_child(rij)

	som_label = Label.new()
	som_label.name = "Som"
	som_label.text = _som
	som_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# In the bar the somlijn never shrinks: that shrink bought room for a
	# keypad that no longer exists (B4).
	som_label.add_theme_font_size_override("font_size", som_grootte if balk
		else (_mt["somlijn"] if not _smal else maxi(UiThema.VLOER, int(_mt["somlijn"]) - 4)))
	som_label.add_theme_color_override("font_color", UiThema.INKT)
	# No empty ruled line left behind: a card without a sum shows no sum line
	# (B4 — was band 3, the was end-card, the zwembad start card).
	som_label.visible = not som_label.text.is_empty()
	rij.add_child(som_label)

	vak_label = Label.new()
	vak_label.name = "Vak"
	vak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vak_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if balk:
		vak_label.custom_minimum_size = Vector2(40, int(_balk["som"]) + 4)
	else:
		vak_label.custom_minimum_size = Vector2(32, 32) if _smal else Vector2(40, 34)
	vak_label.add_theme_font_size_override("font_size", vak_grootte if balk
		else (_mt["somvak"] if not _smal else maxi(UiThema.VLOER, int(_mt["somvak"]) - 4)))
	vak_label.add_theme_color_override("font_color", UiThema.INKT)
	# the box shows the number the child tapped; a strip of WORDS needs no box
	vak_label.visible = bool(_o.get("vak", (_o.get("keuzes", []) as Array).is_empty()))
	vak_label.text = _vak
	_verf_vak()
	rij.add_child(vak_label)
	_ververs_rij()

	hulp_label = Label.new()
	hulp_label.name = "Hulp"
	hulp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hulp_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	hulp_label.add_theme_font_size_override("font_size", zin_grootte)
	hulp_label.add_theme_color_override("font_color", UiThema.INKT2)
	hulp_label.text = _hulp
	hulp_label.visible = not _hulp.is_empty()
	kolom.add_child(hulp_label)

	if balk:
		# The bar is one tight stack: no extra line spacing anywhere on it, so
		# the sentence, the sum and the buttons all fit in the bar's height.
		for l in [regel_label, regel2_label, som_label, hulp_label]:
			l.add_theme_constant_override("line_spacing", 0)
	max_cijfers = int(_o.get("max", 2))
	# The sentence decides the width: it wraps at the card maximum instead of
	# being cut, and nothing forces the card wider than the sentence needs.
	regel_label.custom_minimum_size = Vector2(_zin_breedte(regel_label, int(breed)), 0)
	if regel2_label.visible:
		regel2_label.custom_minimum_size = Vector2(_zin_breedte(regel2_label, int(breed)), 0)
	if balk:
		# The bar-mode minimum is what the bar measures; cache it now that the
		# children are built so a later floating render can still report it.
		_meet_balk()

## The card's content height measured by the THEME at `breed`, independent of
## what the labels' own minimums currently claim.  A wrapping `Label` reports
## its height at the width it was last LAID OUT at: a freshly built or
## just-shown label — or one left over a frame after the bar let go — has no
## honest width and answers one word per line (375 units for a card that
## draws 90).  Both the bar (`_meet_balk`) and the floating measure
## (`Ui.kaart_mat`) go through here so neither can dock or place a tower (B4).
## The `Kolom`'s own separation is added between the visible lines, so the
## number matches what the card really draws in either stand.
func inhoud_hoogte(breed: float) -> float:
	var kolom := get_node_or_null("Kolom")
	var sep := 4.0
	if kolom != null:
		sep = float(kolom.get_theme_constant("separation"))
	var lijnen: Array = []
	lijnen.append(UiThema.wrap_hoogte(regel_label, breed))
	if regel2_label.visible:
		lijnen.append(UiThema.wrap_hoogte(regel2_label, breed))
	var rij := get_node_or_null("Kolom/Rij")
	if rij != null and rij.visible:
		lijnen.append(float(rij.get_combined_minimum_size().y))
	if hulp_label.visible:
		lijnen.append(UiThema.wrap_hoogte(hulp_label, breed))
	var h := 0.0
	for i in lijnen.size():
		if i > 0:
			h += sep
		h += float(lijnen[i])
	return h

## The bar-mode minimum, measured by the THEME at the bar width — never by
## `get_combined_minimum_size()` (see `inhoud_hoogte`).
func _meet_balk() -> void:
	# The bar width comes from the CURRENT frame, never from the card's own
	# `custom_minimum_size`: that is pinned to whatever frame the card last
	# docked on, so after a resize the old bar width would ride along and the
	# card would be placed wider than the frame it now stands in (B4).
	var w := World.kader_rect().size.x - 24.0
	if str(_balk.get("vorm", "hoog")) == "laag":
		w = World.kader_rect().size.x * UiThema.BALK_LAAG_LINKS
	if w < 1.0:
		w = BREED
	_maat_balk = Vector2(w, inhoud_hoogte(w))

## The minimum size this card would have in the bar, whether or not it is drawn
## there right now.  The bar measures its candidate in bar-mode so the fit
## decision is stable across a float/bar re-render (B4).
func maat_balk() -> Vector2:
	if in_balk:
		# Even a laid-out card is measured by the theme: a help line that
		# just became visible has not been laid out at the bar width yet,
		# and the Control's own answer would be the one-word-per-line tower
		# again.
		_meet_balk()
		return _maat_balk
	if _maat_balk != Vector2.ZERO:
		return _maat_balk
	# Unknown: render bar-mode once, measure, and put the floating stand back
	# exactly as it was, including the size `Hits` pinned into it.
	var pin := custom_minimum_size
	_bouw(true)
	var m := _maat_balk
	_bouw(false)
	custom_minimum_size = pin
	return m

## The sum row is only there when there is something in it: a sum or an answer
## box.  `Ui.Kaart.som()` keeps this true when it fills the line later (B4).
func zet_som(tekst: String) -> void:
	if som_label != null:
		som_label.text = tekst
		som_label.visible = not tekst.is_empty()
	_som = tekst
	_ververs_rij()
	_maat_balk = Vector2.ZERO

func _ververs_rij() -> void:
	var r := get_node_or_null("Kolom/Rij")
	if r != null:
		r.visible = (som_label != null and som_label.visible) \
			or (vak_label != null and vak_label.visible)

## The help line is the one thing that changes the card's height after it
## opened, so it clears the bar-mode cache (B4).
func zet_hulp(tekst: String) -> void:
	_hulp = tekst
	if hulp_label != null:
		hulp_label.text = tekst
		hulp_label.visible = not tekst.is_empty()
	_maat_balk = Vector2.ZERO

## The number (or ✓) the child tapped, kept as a live field so a bar
## re-render of the card does not wipe the answer off the box (B4).
func zet_vak(tekst: String) -> void:
	_vak = tekst
	if vak_label != null:
		vak_label.text = tekst

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
	_regel = regel
	if regel_label != null:
		regel_label.text = _zin(icoon, regel)
	_maat_balk = Vector2.ZERO

func zet_regel2(regel: String) -> void:
	_regel2 = regel
	if regel2_label != null:
		regel2_label.text = regel
		regel2_label.visible = not regel.is_empty()
		if in_balk and str(_balk.get("vorm", "hoog")) == "laag":
			regel2_label.visible = false
	_maat_balk = Vector2.ZERO

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

# ------------------------------------------------------------ het papier

## The ruled lines of this card's paper, in the card's own coordinates, top to
## bottom: one under every line of text the card draws, `ONDER` below that
## line's baseline, so a letter stands ON its line and no line runs through
## one (PLAN.md §3.1).  The paper used to rule a fixed 22 unit pitch from its
## top edge while a text row is 24 units plus the column's 4, so the lines
## drifted through the text: 2 units into the foot of the first sentence,
## through the middle of the second (the owner's screenshot, 2026-09-22).
## Both papers ask here: the floating card for itself, the maths bar for the
## docked card.
##
## Where the baseline is, measured in the web build (2026-09-22): a `Label`
## row is as tall as the WHOLE font chain (`Symbolen` reaches deep: 15 + 9 at
## size 14), and the text it holds — Nunito plus an emoji, 15 + 5 — is
## CENTRED in that row.  So the baseline is not "row top + ascent" (off by 2
## to 4 units, the line cut through the foot of every letter) but the row top
## plus half the slack plus the ascent of what is really written there.  The
## rows come from the label's own layout (`get_character_bounds` walks the
## lines it draws), so a sentence that wraps gets a line per row.
##
## The height of a row is taken the way the label cuts it: the text is shaped
## once and every row is a SUBSTRING of it, which keeps only the fonts that
## really draw in that row.  Shaping the row anew (`TextLine`) also counts
## the fonts the fallback merely tried — on the web build that is `Symbolen`
## for the emoji, 24/14 instead of 23/8 at size 22 — and the line came out
## 2.5 units high again; on the desktop both ways agree, so only the web
## build shows it.
func lijn_ys() -> PackedFloat32Array:
	var ys := PackedFloat32Array()
	var ts := TextServerManager.get_primary_interface()
	for l in [regel_label, regel2_label, som_label, hulp_label]:
		var lbl: Label = l
		if lbl == null or lbl.text.is_empty() or not _zichtbaar(lbl):
			continue
		var f := lbl.get_theme_font("font")
		if f == null:
			continue
		var maat := lbl.get_theme_font_size("font_size")
		var boven := _in_kaart(lbl).y
		# Every row: its box, and where in the text it starts.
		var vakken: Array[Rect2] = []
		var begin: Array[int] = []
		for i in lbl.text.length():
			var vak := lbl.get_character_bounds(i)
			if vak.size.y <= 0.0:
				continue
			if vakken.is_empty() or not is_equal_approx(vak.position.y, vakken[-1].position.y):
				vakken.append(vak)
				begin.append(i)
		var vorm := ts.create_shaped_text()
		ts.shaped_text_add_string(vorm, lbl.text, f.get_rids(), maat, f.get_opentype_features())
		for r in vakken.size():
			var eind := begin[r + 1] if r + 1 < begin.size() else lbl.text.length()
			var rij := ts.shaped_text_substr(vorm, begin[r], eind - begin[r])
			var stijg := ts.shaped_text_get_ascent(rij)
			var speling := vakken[r].size.y - (stijg + ts.shaped_text_get_descent(rij))
			ts.free_rid(rij)
			ys.append(boven + vakken[r].position.y + speling * 0.5 + stijg + ONDER)
		ts.free_rid(vorm)
	ys.sort()
	return ys

## The pitch of one sentence line.  The bar rules its paper at this pitch
## above and below the docked card, so the lines it adds read as the next
## lines to write on.
func lijn_afstand() -> float:
	var sep := 0.0
	var kolom := get_node_or_null("Kolom")
	if kolom != null:
		sep = float(kolom.get_theme_constant("separation"))
	if regel_label == null:
		return 22.0
	var maat := regel_label.get_theme_font_size("font_size")
	var f := regel_label.get_theme_font("font")
	if f == null:
		return float(maat) + 2.0 + sep
	return f.get_height(maat) + float(regel_label.get_theme_constant("line_spacing")) + sep

## Shown on THIS card, whether or not the card itself is in a tree yet.
func _zichtbaar(c: CanvasItem) -> bool:
	var n: Node = c
	while n != null and n != self:
		if n is CanvasItem and not (n as CanvasItem).visible:
			return false
		n = n.get_parent()
	return n == self

## Where `c` stands in this card's own coordinates.  Only positions add up:
## nothing between the card and its labels scales, and the card's own
## appear-scale must not count — the paper is drawn in the card's space.
func _in_kaart(c: Control) -> Vector2:
	var p := Vector2.ZERO
	var n: Node = c
	while n != null and n != self:
		if n is Control:
			p += (n as Control).position
		n = n.get_parent()
	return p

## The text moved — laid out again, or the card itself moved — so the paper
## under it redraws: this card's own, or the bar's while the card is docked.
func _lijnen_verschoven() -> void:
	queue_redraw()
	if in_balk and Ui.balklaag != null and is_instance_valid(Ui.balklaag):
		Ui.balklaag.queue_redraw()

## The ruled paper, drawn over the panel (CanvasItem calls `_draw` after the
## container painted its stylebox).
func _draw() -> void:
	if in_balk:
		return   # the bar is the paper; it rules itself under this card (B4)
	for y in lijn_ys():
		if y < size.y - 2.0:
			draw_line(Vector2(4, y), Vector2(size.x - 4, y), UiThema.PAPIER_LIJN, 1.0)
