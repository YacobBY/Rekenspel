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
const WOLK_INFO := Color("#FFF6E3")   ## a bubble that only speaks: warm paper, not a key
const WOLK_GOED := Color("#E4F7EC")
const WOLK_HULP := Color("#FFF8E7")
const SCHERM_WAAS := Color(0.29, 0.231, 0.2, 0.333)   ## #4a3b3355
const SCHADUW_KL := Color(0.29, 0.231, 0.2, 0.12)
const SCHADUW_DIEP := Color(0.29, 0.231, 0.2, 0.20)

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
## `ruim`: the frame has room for the world's bigger words (`ruim_van`).
static func maten(basis: int, ruim := false) -> Dictionary:
	var m := func(rem: float) -> int:
		return maxi(VLOER, int(round(rem * basis)))
	return {
		"basis": maxi(VLOER, basis),
		"klein": clampi(int(round(0.75 * basis)), VLOER, 14),   ## the floor clamp
		## The words IN the world — button labels, bubbles, the answer strip,
		## the sentence of a floating card — at the base size instead of
		## `klein` wherever the frame has room.  The owner, 2026-09-23: "de
		## tekst is er klein".  §12.2 caps child-facing text at 14 px because
		## the prototype's world was a small canvas; on a tablet or a desktop
		## the world fills a big frame and its labels stayed 14 in it.  On a
		## phone-sized frame they stay `klein`: the games' layouts there are cut
		## to those sizes, and at 18 the hopscotch card covered its own guest
		## and the key card its own board.  The chrome keeps its sizes.
		"wereld": clampi(basis, VLOER, 18) if ruim
			else clampi(int(round(0.75 * basis)), VLOER, 14),
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

## Room for the world's bigger words: a frame whose SHORT side is at least
## `RUIM` units — a tablet either way up, a desktop window.  Every phone the
## suite draws stays under it (short sides 289 to 360).
const RUIM := 600.0
static func ruim_van(kader: Vector2) -> bool:
	return minf(kader.x, kader.y) >= RUIM

## A tap target is 48; 44 is allowed **only below a 360 px screen**, never at
## exactly 360 (art-sound-rules.md §16.5: `@media (max-width:359px)` drops to 44
## and `@media (min-width:360px)` puts it back at 48).  The argument is therefore
## the SHORT SIDE OF THE WINDOW, not the width of the world frame: a fingertip
## does not shrink because the chrome took some room.
static func tap_van(scherm_kort: float) -> int:
	return HOT_KRAP if scherm_kort < 360.0 else HOT

# ------------------------------------------------------------- de rekenbalk

## The maths bar of PLAN.md §3.1: the strip under the world that always carries
## the sentence, the sum and the four answer buttons.  This is the measuring
## tape only — the node (`ui/rekenbalk.gd`), the anchor `"balk"` and the
## hysteresis on a resize are later tasks; nothing here keeps state.
##
## The argument is the WORLD FRAME in units (`World.kader_rect().size`), never
## the screen: the chrome and the room bar have taken their share long before
## the frame exists, and the bar is measured inside what is left.
##
## `hoog` stacks the sentence over the sum over one row of four buttons.  `laag`
## is for a frame that is short in the tall direction: sentence and sum on the
## left in `BALK_LAAG_LINKS` of the width, the button row in the rest.  A frame
## that is short AND narrow (296x314) has no room for two blocks beside each
## other, so it stays `hoog` and pays with its height instead.
const BALK_LAAG_LINKS := 0.48

static func balk_vorm(kader: Vector2) -> String:
	return "laag" if kader.y < 440.0 and kader.x >= 470.0 else "hoog"

## The table of PLAN.md §3.1: five rungs by frame size, then one clamp on the
## height.  Keys: `vorm`, `hoog` (the bar itself), `zin`, `som`, `knop` and `nu`
## (text sizes, every one of them over the 12 px floor of HOTEL.md §9),
## `knop_hoog` and `knop_breed` (one answer button, never under `HOT`).
##
## These are deliberately far over the 14 px the global `klein` clamp allows
## (`maten()` above): that clamp feeds twenty-eight little chrome labels, while
## the bar is the one place where the child actually reads the sum.
##
## The button width is cut so four buttons and their three 8 unit gaps fit in
## the frame minus a 12 unit margin (`hoog`), or in the right-hand block
## (`laag`, where the left block is `BALK_LAAG_LINKS` of the width — that is why
## `laag` starts at 470 units: any narrower and the two blocks would overlap).
## Both hold on every frame the shell hands out.  Under 228 units of width the
## 48 unit tap floor wins over the fit, and `World.KADER_MIN` never lets a frame
## get that small; under 212 units of height the ceiling wins over the 72 of the
## clamp, for the same reason.
static func balk_maten(kader: Vector2) -> Dictionary:
	var x := kader.x
	var m := {}
	if kader.y >= 440.0:
		if x >= 900.0:                     ## A — tablet and desktop
			m = {"hoog": 160, "zin": 22, "som": 34, "knop": 24, "nu": 21,
				"knop_hoog": 64, "knop_breed": clampf((x - 54.0) / 4.0, 56.0, 150.0)}
		elif x >= 520.0:                   ## B — tablet upright
			m = {"hoog": 152, "zin": 21, "som": 32, "knop": 23, "nu": 20,
				"knop_hoog": 60, "knop_breed": clampf((x - 54.0) / 4.0, 56.0, 140.0)}
		else:                              ## C — phone upright
			m = {"hoog": 160, "zin": 20, "som": 30, "knop": 22, "nu": 19,
				"knop_hoog": 60, "knop_breed": clampf((x - 48.0) / 4.0, 48.0, 120.0)}
	elif x >= 470.0:                       ## D — phone on its side, the only `laag`
		m = {"hoog": 96, "zin": 18, "som": 26, "knop": 20, "nu": 18,
			"knop_hoog": 60,
			"knop_breed": clampf((x * BALK_LAAG_LINKS - 18.0) / 4.0, 48.0, 96.0)}
	else:                                  ## E — short and narrow
		m = {"hoog": 132, "zin": 17, "som": 24, "knop": 19, "nu": 17,
			"knop_hoog": 52, "knop_breed": clampf((x - 42.0) / 4.0, 48.0, 96.0)}
	m["vorm"] = balk_vorm(kader)
	# the world keeps two thirds: the bar never grows past a third of the frame
	m["hoog"] = clampi(int(m["hoog"]), 72, int(kader.y * 0.34))
	# down, never up — the fit of the four buttons has to survive the rounding
	m["knop_breed"] = floori(float(m["knop_breed"]))
	return m

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

static func vlak(kleur: Color, ronding: int, rand := 0, rand_kleur := WIT, schaduw := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = kleur
	sb.set_corner_radius_all(ronding)
	if rand > 0:
		sb.set_border_width_all(rand)
		sb.border_color = rand_kleur
	if schaduw:
		sb.shadow_color = SCHADUW_KL
		sb.shadow_size = 4
		sb.shadow_offset = Vector2(0, 2)
	return sb

## What you can press looks pressable, what only speaks does not (owner,
## 2026-09-23: "heel veel textboxen die allemaal klikbaar lijken dan is het
## niet meer duidelijk welke nou interactie hebben en welke niet").  Every
## button in the world stands on a warm border with a thicker key edge at the
## bottom and a small shadow, and pressing it pushes the edge in; a bubble that
## only says something is flat, see-through and does not react (`UiWolk`).
const KNOP_RAND := Color("#E2BE8E")   ## the border and the key edge of a button
const KNOP_LIP := 5                    ## the key edge, in units

static func knop_vlak(kleur: Color, ronding: int, lip := KNOP_LIP) -> StyleBoxFlat:
	var sb := vlak(kleur, ronding, 2, KNOP_RAND)
	sb.border_width_bottom = lip
	sb.shadow_color = SCHADUW_KL
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	return sb

## The states of a button in the world, from its normal box: a warmer face
## under the finger, and pressed the key edge goes down and the face with it.
static func knop_staten(sb: StyleBoxFlat) -> Dictionary:
	var over := sb.duplicate() as StyleBoxFlat
	over.bg_color = over.bg_color.lerp(ZON, 0.35)
	var druk := sb.duplicate() as StyleBoxFlat
	druk.bg_color = druk.bg_color.lerp(PERZIK, 0.55)
	druk.border_width_bottom = 2
	druk.shadow_size = 1
	druk.shadow_offset = Vector2(0, 1)
	if sb.content_margin_top >= 0.0:
		druk.content_margin_top = sb.content_margin_top + 2
	if sb.content_margin_bottom >= 0.0:
		druk.content_margin_bottom = maxf(0.0, sb.content_margin_bottom - 2)
	return {"normal": sb, "hover": over, "pressed": druk, "hover_pressed": druk,
		"disabled": sb,
		"focus": vlak(Color(0, 0, 0, 0), int(sb.corner_radius_top_left), 2, PERZIK_D)}

## What only SAYS something — a hint, a status — is a speech bubble and not a
## key (owner, 2026-09-24: "Hints als 'tik op een deur' of 'je duwt de kar'
## lijken erg op bubbeltjes waar interactie voor is ... zodat text bubbels
## zonder interactie minder prominent zijn en niet zo klikbaar lijken").  Next to
## a button (warm border, thick key edge, shadow, bold words, round pill) it is
## lighter and see-through, has a thin soft outline instead of a border, small
## corners instead of the pill, no shadow and no key edge, and its words are
## regular weight and `INFO_KLEINER` smaller.  A bubble also points a comic tail
## at what it talks about (`UiWolk._draw`).  Dark ink on warm paper keeps it
## easy to read.
const INFO_VUL_ALFA := 0.8
const INFO_LIJN := Color(0.29, 0.231, 0.2, 0.35)    ## the outline: ink at 35 %
const INFO_LIJN_DIK := 1.5
const INFO_RONDING := 10
const INFO_KLEINER := 2                             ## px under a button's words, never under VLOER

## The box of a status label that is still a (quiet) button: the held trolley
## says "Je duwt de kar" and a tap puts it down again (games/voerkar).
static func info_vlak(kleur := WOLK_INFO) -> StyleBoxFlat:
	var sb := vlak(Color(kleur, INFO_VUL_ALFA), INFO_RONDING, 1, INFO_LIJN)
	return vulling(sb, 8, 6)

## The size of a bubble's words, from the size a button's words have there.
static func info_maat(knop_maat: int) -> int:
	return maxi(VLOER, knop_maat - INFO_KLEINER)

static func vulling(sb: StyleBoxFlat, links: int, boven: int, rechts := -1, onder := -1) -> StyleBoxFlat:
	sb.content_margin_left = links
	sb.content_margin_top = boven
	sb.content_margin_right = links if rechts < 0 else rechts
	sb.content_margin_bottom = boven if onder < 0 else onder
	return sb

## The whole theme.  Rebuilt when the breakpoint moves, never per frame.
static func bouw(basis: int, ruim := false) -> Theme:
	var t := Theme.new()
	var gewoon := laad_font(false)
	var vet := laad_font(true)
	var mt := maten(basis, ruim)
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
	t.set_stylebox("hover_pressed", "Button", knop_in)
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
	_variant(t, "KnopActief", "Button", vulling(vlak(ZON, 18, 2, PERZIK_D), 16, 12), mt["knop_groot"], vet)
	_variant(t, "Hotknop", "Button", vulling(knop_vlak(WIT, 16), 8, 6), mt["wereld"], vet)
	_knop_staten_in(t, "Hotknop")
	_variant(t, "Padtoets", "Button", vulling(vlak(WIT, 12, 2, KURK), 4, 2), mt["toets"], vet)
	_variant(t, "Keuzeknop", "Button", vulling(knop_vlak(WIT, 14), 8, 6), mt["wereld"], vet)
	_knop_staten_in(t, "Keuzeknop")

	var chip_sb := vulling(vlak(KAART, 14, 2, WIT), 6, 4)
	_variant(t, "Kamerchip", "Button", chip_sb, mt["klein"], vet)
	var chip_in := chip_sb.duplicate() as StyleBoxFlat
	chip_in.bg_color = ZON.lerp(WIT, 0.25)
	chip_in.border_color = PERZIK_D
	chip_in.set_border_width_all(2)
	t.set_stylebox("pressed", "Kamerchip", chip_in)
	t.set_stylebox("hover_pressed", "Kamerchip", chip_in)

	_variant(t, "Badge", "Button", vulling(vlak(KAART, 999, 2, WIT), 9, 4), mt["badge"], vet)
	_variant(t, "Kaartknop", "Button", vulling(vlak(KURK, 14, 2, WIT), 10, 8), mt["wereld"], vet)

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
	# ---- tooltips (desktop only): ink on a card, not Godot's dark-on-dark
	t.set_stylebox("panel", "TooltipPanel", vulling(vlak(KAART, 12, 2, KURK), 10, 6))
	t.set_color("font_color", "TooltipLabel", INKT)
	t.set_font_size("font_size", "TooltipLabel", mt["klein"])
	return t

## A world button's own states instead of the tints `_variant` makes: the key
## edge goes down when it is pressed.
static func _knop_staten_in(t: Theme, naam: String) -> void:
	var staten := knop_staten(t.get_stylebox("normal", naam) as StyleBoxFlat)
	for toestand in staten:
		t.set_stylebox(toestand, naam, staten[toestand])

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
	t.set_stylebox("hover_pressed", naam, in_druk)
	t.set_stylebox("focus", naam, vlak(Color(0, 0, 0, 0), 14, 2, PERZIK_D))
	t.set_font_size("font_size", naam, maat)
	t.set_color("font_color", naam, INKT)
	t.set_color("font_hover_color", naam, INKT)
	t.set_color("font_pressed_color", naam, INKT)
	t.set_color("font_focus_color", naam, INKT)
	if vet != null:
		t.set_font("font", naam, vet)
