class_name UiThema
extends RefCounted
## The one owner of colour, font and tap size (architecture.md §1.3 point 5).
##
## In the HTML a game could escape the 12 px floor with its own inline
## `font-size`; here every child-facing Control is built by `Ui`, and `Ui` reads
## its numbers from this file.  Palette from art-sound-rules.md §2.4, text sizes
## from §12.2, tap sizes from §16.5, the three bundled OFL fonts from §7.5 of
## architecture.md.

# ------------------------------------------------------------------ palet
const BG := Color("#FFF4E8")
const BG2 := Color("#FFE9D6")
const KAART := Color("#FFFDF8")
const INKT := Color("#4A3B33")
const INKT2 := Color("#8A7566")
const PERZIK := Color("#FFB88C")
const PERZIK_D := Color("#F2915B")
const MUNT := Color("#A7DEC6")
const MUNT_D := Color("#5FBF9B")
const LILA := Color("#CBB8EA")
const LUCHT := Color("#A9D3F0")
const ROZE := Color("#FFC7D9")
const ZON := Color("#FFDD8C")
const GOUD := Color("#F2C14E")
const KURK := Color("#E8CFA6")
const WIT := Color("#FFFFFF")

## The squared-paper card (art-sound-rules.md §16.6).
const PAPIER := Color("#FCFAF0")
const PAPIER_RAND := Color("#EAE0C8")
const PAPIER_LIJN := Color("#C2D8EA")
const VAK := Color("#FFFFFF")
const VAK_ONDER := Color("#EAF1F8")
const VAK_GOED := Color("#D8F3E4")
const KAART_AF := Color("#EAFBF3")
const WOLK := Color("#FFFDF6")
const WOLK_GOED := Color("#E4F7EC")
const WOLK_HULP := Color("#FFF8E7")
const SCHERM_WAAS := Color(0.29, 0.231, 0.2, 0.333)   ## #4a3b3355

const RONDING := 22
const TAP := 52          ## `--tap`: the default minimum of a chrome button
const HOT := 48          ## a hotspot / keypad key; 44 only below a 360 unit frame
const HOT_KRAP := 44
const VLOER := 12        ## px; text never goes below this (HOTEL.md §9)

# ------------------------------------------------------------------ fonts
const NUNITO := "res://fonts/Nunito-Regular.ttf"
const NUNITO_VET := "res://fonts/Nunito-Bold.ttf"
const SYMBOLEN := "res://fonts/Symbolen.ttf"
const EMOJI := "res://fonts/Emoji.ttf"

## Nunito with the two subsets behind it, so one Label carries Dutch letters,
## `⌫ ✓ ▸` and colour emoji without any call site knowing about it.
static func laad_font(vet := false) -> FontFile:
	var f: FontFile = load(NUNITO_VET if vet else NUNITO)
	if f == null:
		return null
	var sym: FontFile = load(SYMBOLEN)
	var emo: FontFile = load(EMOJI)
	var terug: Array[Font] = []
	if sym != null:
		terug.append(sym)
	if emo != null:
		terug.append(emo)
	f.fallbacks = terug
	return f

# -------------------------------------------------------------- tekstmaten

## art-sound-rules.md §12.2, in px, against a base of 18 (17 below 520 units).
## Every value is floored at 12 px here, once, instead of in twenty call sites.
static func maten(basis: int) -> Dictionary:
	var m := func(rem: float) -> int:
		return maxi(VLOER, int(round(rem * basis)))
	return {
		"basis": maxi(VLOER, basis),
		"klein": clampi(int(round(0.75 * basis)), VLOER, 14),   ## the floor clamp
		"h1": m.call(1.32), "h2": m.call(1.2),
		"knop": m.call(1.05), "knop_groot": m.call(1.2),
		"logo": m.call(1.05), "ronde": m.call(0.82), "badge": m.call(0.9),
		"icoon": m.call(1.3), "icoon_wolk": m.call(1.4),
		"icoon_bron": m.call(1.5), "icoon_keuze": m.call(1.1),
		"getal": m.call(1.3),
		"somlijn": m.call(1.15), "somvak": m.call(1.25),
		"toets": m.call(1.15), "munt": m.call(1.1), "voet": m.call(0.8),
	}

## world.md §6.5 / art-sound-rules.md §16.9: the base font drops below 520 units.
static func basis_van(breedte: float) -> int:
	return 17 if breedte < 520.0 else 18

## A tap target is 48; 44 is allowed **only below a 360 px screen**, never at
## exactly 360 (art-sound-rules.md §16.5: `@media (max-width:359px)` drops to 44
## and `@media (min-width:360px)` puts it back at 48).  The argument is therefore
## the SHORT SIDE OF THE WINDOW, not the width of the world frame: a fingertip
## does not shrink because the chrome took some room.
static func tap_van(scherm_kort: float) -> int:
	return HOT_KRAP if scherm_kort < 360.0 else HOT

## The height an autowrapping Label really needs at this width.
##
## `Label.get_minimum_size()` reports ONE line for an autowrapping label — it
## cannot know the width a container will give it — so every place that has to
## size such a label vertically asks here instead.  The break flags are the ones
## `AUTOWRAP_WORD_SMART` uses, plus grapheme breaking for `AUTOWRAP_ARBITRARY`.
static func wrap_hoogte(l: Label, breed: float) -> float:
	var f := l.get_theme_font("font")
	var maat: int = l.get_theme_font_size("font_size")
	if f == null or breed <= 1.0:
		return float(maat) + 2.0
	var vlaggen := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND \
		| TextServer.BREAK_ADAPTIVE
	if l.autowrap_mode == TextServer.AUTOWRAP_ARBITRARY:
		vlaggen = TextServer.BREAK_MANDATORY | TextServer.BREAK_GRAPHEME_BOUND
	var vak := f.get_multiline_string_size(l.text, l.horizontal_alignment, breed, maat,
		-1, vlaggen).y
	# `get_multiline_string_size` stacks the LINES; a `Label` also puts its own
	# `line_spacing` under every one of them (4 units in this theme), and leaving
	# that out is what made every sheet 4 units per child too short — the start
	# screen clipped its own "Verder spelen ▸" off the bottom on a phone (I1).
	var regel_h := maxf(1.0, f.get_height(maat))
	var lijnen := maxf(1.0, round(vak / regel_h))
	return lijnen * (regel_h + float(l.get_theme_constant("line_spacing")))

# ------------------------------------------------------------- stijlblokken

static func vlak(kleur: Color, ronding: int, rand := 0, rand_kleur := WIT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = kleur
	sb.set_corner_radius_all(ronding)
	if rand > 0:
		sb.set_border_width_all(rand)
		sb.border_color = rand_kleur
	return sb

static func vulling(sb: StyleBoxFlat, links: int, boven: int, rechts := -1, onder := -1) -> StyleBoxFlat:
	sb.content_margin_left = links
	sb.content_margin_top = boven
	sb.content_margin_right = links if rechts < 0 else rechts
	sb.content_margin_bottom = boven if onder < 0 else onder
	return sb

## The whole theme.  Rebuilt when the breakpoint moves, never per frame.
static func bouw(basis: int) -> Theme:
	var t := Theme.new()
	var gewoon := laad_font(false)
	var vet := laad_font(true)
	var mt := maten(basis)
	if gewoon != null:
		t.default_font = gewoon
	t.default_font_size = mt["basis"]

	# ---- Label: the plain reading text
	t.set_color("font_color", "Label", INKT)
	t.set_font_size("font_size", "Label", mt["basis"])

	# ---- Button: `.btn`, radius 999-ish, sinks when pressed
	var knop_uit := vulling(vlak(KAART, 16, 2, WIT), 12, 8)
	var knop_over := vulling(vlak(BG2, 16, 2, WIT), 12, 8)
	var knop_in := vulling(vlak(PERZIK, 16, 2, WIT), 12, 10, 12, 6)
	t.set_stylebox("normal", "Button", knop_uit)
	t.set_stylebox("hover", "Button", knop_over)
	t.set_stylebox("pressed", "Button", knop_in)
	t.set_stylebox("focus", "Button", vlak(Color(0, 0, 0, 0), 16, 2, PERZIK_D))
	t.set_stylebox("disabled", "Button", vulling(vlak(BG2, 16, 2, WIT), 12, 8))
	t.set_color("font_color", "Button", INKT)
	t.set_color("font_hover_color", "Button", INKT)
	t.set_color("font_pressed_color", "Button", INKT)
	t.set_color("font_focus_color", "Button", INKT)
	t.set_color("font_disabled_color", "Button", INKT2)
	t.set_font_size("font_size", "Button", mt["knop"])
	if vet != null:
		t.set_font("font", "Button", vet)

	# ---- PanelContainer: the plain card
	t.set_stylebox("panel", "PanelContainer", vulling(vlak(KAART, RONDING, 2, WIT), 10, 8))

	_variant(t, "KnopGroot", "Button", vulling(vlak(PERZIK, 18, 2, WIT), 16, 12), mt["knop_groot"], vet)
	_variant(t, "Hotknop", "Button", vulling(vlak(KAART, 16, 2, WIT), 8, 6), mt["klein"], vet)
	_variant(t, "Padtoets", "Button", vulling(vlak(WIT, 12, 2, KURK), 4, 2), mt["toets"], vet)
	_variant(t, "Keuzeknop", "Button", vulling(vlak(KAART, 14, 2, WIT), 8, 6), mt["klein"], vet)
	_variant(t, "Kamerchip", "Button", vulling(vlak(KAART, 14, 2, WIT), 6, 4), mt["klein"], vet)
	_variant(t, "Badge", "Button", vulling(vlak(KAART, 999, 2, WIT), 9, 4), mt["badge"], vet)
	_variant(t, "Kaartknop", "Button", vulling(vlak(KURK, 14, 2, WIT), 10, 8), mt["klein"], vet)

	t.set_type_variation("Logo", "Label")
	t.set_font_size("font_size", "Logo", mt["logo"])
	if vet != null:
		t.set_font("font", "Logo", vet)
	t.set_type_variation("Ronde", "Label")
	t.set_font_size("font_size", "Ronde", mt["ronde"])
	t.set_type_variation("Klein", "Label")
	t.set_font_size("font_size", "Klein", mt["klein"])
	t.set_color("font_color", "Klein", INKT2)
	t.set_type_variation("Kop", "Label")
	t.set_font_size("font_size", "Kop", mt["h1"])
	if vet != null:
		t.set_font("font", "Kop", vet)
	t.set_type_variation("Voet", "Label")
	t.set_font_size("font_size", "Voet", mt["voet"])
	t.set_color("font_color", "Voet", INKT2)
	return t

static func _variant(t: Theme, naam: String, basis_type: String, sb: StyleBoxFlat,
		maat: int, vet: FontFile) -> void:
	t.set_type_variation(naam, basis_type)
	t.set_stylebox("normal", naam, sb)
	var over := sb.duplicate() as StyleBoxFlat
	over.bg_color = over.bg_color.lerp(ZON, 0.35)
	t.set_stylebox("hover", naam, over)
	var in_druk := sb.duplicate() as StyleBoxFlat
	in_druk.bg_color = in_druk.bg_color.lerp(PERZIK, 0.55)
	in_druk.content_margin_top = sb.content_margin_top + 2
	in_druk.content_margin_bottom = maxf(0.0, sb.content_margin_bottom - 2)
	t.set_stylebox("pressed", naam, in_druk)
	t.set_stylebox("focus", naam, vlak(Color(0, 0, 0, 0), 14, 2, PERZIK_D))
	t.set_font_size("font_size", naam, maat)
	t.set_color("font_color", naam, INKT)
	t.set_color("font_hover_color", naam, INKT)
	t.set_color("font_pressed_color", naam, INKT)
	t.set_color("font_focus_color", naam, INKT)
	if vet != null:
		t.set_font("font", naam, vet)
