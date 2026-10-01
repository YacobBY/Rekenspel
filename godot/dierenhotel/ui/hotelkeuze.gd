class_name UiHotelkeuze
extends Control
## The hotels on the start sheet (owner 2026-10-01: "En ik wil save files
## maken"): one tile per save slot, told apart without reading.
##
## A tile carries the hotel's own animal on its own colour, its name `Hotel 2`,
## and the day, the stars and the guests as numbers with a pictogram
## (`📅 3  ⭐ 5  🐾 2`).  An empty slot is a tile `➕ Nieuw hotel`.  The hotel
## played last stands out (sun yellow, a thicker edge): that is where the child
## was.  Tapping a tile is the whole answer — `gekozen(n)`.
##
## The same tiles serve the questions round the start sheet: "which hotel may
## go?" (`alleen_vol`: an empty tile cannot be picked there) and "are you
## sure?" (`toon`: the one hotel, only to look at).
##
## Laid out by hand, like the notice board (`ui/prikbordblad.gd`): a `Button`
## is not a `Container`, and the sheet measures its content before the first
## layout pass, so every tile and label gets its `position` and `size` here and
## the whole grid reports itself as this control's minimum size.  Three tiles
## stand side by side where the sheet is wide enough; on a phone held upright
## they lie under each other, the animal left of the words.

signal gekozen(n: int)

const GAT := 8.0            ## between two tiles
const VULLING_X := 10.0     ## inside a tile
const VULLING_Y := 8.0
const LIP := 5.0            ## the key edge at the bottom of a tile (UiThema.KNOP_LIP)
const REGEL_GAT := 2.0      ## between the lines of a tile
const STAAND_MIN := 150.0   ## a standing tile needs this; narrower -> lying tiles
## Below this screen height (a phone held sideways) the animal stands beside
## the name instead of over it, so the sheet fits without scrolling.
const LAAG_SCHERM := 450.0
const ICOON_GROOT := 1.9    ## the animal, in base font sizes, over the name ...
const ICOON_LAAG := 1.35    ## ... and beside it on a low screen
## A pastel per hotel, so the three tiles read as three hotels, not as a list.
const KLEUR := [Color("#DCEEFB"), Color("#FFE4EC"), Color("#DDF4EA")]

var _maten: Dictionary = {}
var _tegels: Array = []     ## [{n, leeg, knop, icoon, naam, cijfers}]
var _bezig := false

## `hotels`: `State.hotels()`.  `o`: `actief` (the hotel to highlight),
## `alleen_vol` (empty tiles cannot be picked), `toon` (nothing can be picked).
func bouw(hotels: Array, mt: Dictionary, o: Dictionary = {}) -> void:
	name = "Hotels"
	_maten = mt
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	for k in get_children():
		remove_child(k)
		k.queue_free()
	_tegels.clear()
	var actief := int(o.get("actief", 0))
	for h in hotels:
		_maak_tegel(h as Dictionary, int(h.get("hotel", 0)) == actief,
			bool(o.get("alleen_vol", false)), bool(o.get("toon", false)))
	_leg_uit()

## The tile of hotel `n`, or null.
func tegel(n: int) -> Button:
	for t in _tegels:
		if int(t["n"]) == n:
			return t["knop"]
	return null

func staand() -> bool:
	return _beschikbaar() >= 3.0 * STAAND_MIN + 2.0 * GAT

func _maak_tegel(h: Dictionary, actief: bool, alleen_vol: bool, toon: bool) -> void:
	var n := int(h.get("hotel", 1))
	var leeg := bool(h.get("leeg", true))
	var b := Button.new()
	b.name = "Khotel%d" % n
	b.text = ""                      # the labels below are the whole tile
	b.clip_text = false
	b.focus_mode = Control.FOCUS_ALL
	var nieuw := UiTekst.HOTEL_NIEUW.split(" ", true, 1)
	if leeg:
		b.tooltip_text = UiTekst.HOTEL_NIEUW
	else:
		b.tooltip_text = "%s: %s" % [UiTekst.hotel_naam(n), UiTekst.start_stand(int(h["dag"]),
			int(h["gasten"]), int(h.get("munten", 0)), int(h["sterren"]))]
	var kl: Color = KLEUR[(n - 1) % KLEUR.size()]
	var sb := UiThema.knop_vlak(UiThema.ZON if actief else (UiThema.KAART if leeg else kl), 16)
	if actief:
		sb.border_color = UiThema.PERZIK_D
		sb.set_border_width_all(3)
		sb.border_width_bottom = int(LIP) + 1
	var staten := UiThema.knop_staten(sb)
	for st in staten.keys():
		b.add_theme_stylebox_override(st, staten[st])
	if toon:
		# only to look at: the confirmation shows the hotel that would go
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.focus_mode = Control.FOCUS_NONE
	elif leeg and alleen_vol:
		b.disabled = true
		b.modulate.a = 0.45
	add_child(b)
	var ic := _label("Icoon", nieuw[0] if leeg else str(UiTekst.HOTEL_ICOON[(n - 1) % UiTekst.HOTEL_ICOON.size()]),
		_icoon_maat(ICOON_GROOT), UiThema.INKT)
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(ic)
	var nm := _label("Naam", nieuw[1] if leeg else UiTekst.hotel_naam(n),
		int(_maten.get("knop", 19)), UiThema.INKT)
	var vet := UiThema.laad_font(true)
	if vet != null:
		nm.add_theme_font_override("font", vet)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(nm)
	var cf: Label = null
	if not leeg:
		cf = _label("Cijfers", UiTekst.hotel_cijfers(int(h["dag"]), int(h["sterren"]),
			int(h["gasten"])), int(_maten.get("basis", 18)), UiThema.INKT)
		cf.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_child(cf)
	if not toon:
		b.pressed.connect(func() -> void:
			Snd.tik()
			gekozen.emit(n))
	_tegels.append({"n": n, "leeg": leeg, "knop": b, "icoon": ic, "naam": nm, "cijfers": cf})

func _icoon_maat(factor: float) -> int:
	return int(round(float(_maten.get("basis", 18)) * factor))

func _label(naam: String, tekst: String, maat: int, kleur: Color) -> Label:
	var l := Label.new()
	l.name = naam
	l.text = tekst
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", maxi(UiThema.VLOER, maat))
	l.add_theme_color_override("font_color", kleur)
	return l

# ------------------------------------------------------------------ meten

func _ready() -> void:
	_leg_uit()

func _notification(wat: int) -> void:
	if wat == NOTIFICATION_RESIZED:
		_leg_uit()

## The width the sheet gives the tiles, with the sheet's own rule before the
## first layout pass (the same answer `ui/prikbordblad.gd` gives).
func _beschikbaar() -> float:
	var ouder := get_parent() as Control
	if ouder != null and ouder.size.x > 1.0:
		return ouder.size.x
	var kader := Vector2.ZERO
	if Ui.bladlaag != null and is_instance_valid(Ui.bladlaag):
		kader = Ui.bladlaag.size
	if kader.x > 1.0:
		return minf(float(UiBlad.BREED), maxf(240.0, kader.x - 2.0 * UiBlad.RAND)) \
			- 2.0 * UiBlad.VULLING
	return float(UiBlad.BREED) - 2.0 * UiBlad.VULLING

## The height of the whole screen the sheet is on.
func _scherm_hoog() -> float:
	if Ui.bladlaag != null and is_instance_valid(Ui.bladlaag) and Ui.bladlaag.size.y > 1.0:
		return Ui.bladlaag.size.y
	return float(get_viewport_rect().size.y)

## Only measures once the labels have a font (in a themed tree); before that
## the size stays what it was.
func _leg_uit() -> void:
	if _bezig or not is_inside_tree() or _tegels.is_empty():
		return
	_bezig = true
	var breedte := _beschikbaar()
	var y := 0.0
	var laag := _scherm_hoog() < LAAG_SCHERM
	for t in _tegels:
		(t["icoon"] as Label).add_theme_font_size_override("font_size",
			_icoon_maat(ICOON_LAAG if laag else ICOON_GROOT))
	if staand():
		# side by side, as wide as the sheet allows but never wider than three
		# standing tiles need; all of a row equally tall
		var kolommen := _tegels.size()
		var w := minf(STAAND_MIN * 1.25,
			(breedte - float(kolommen - 1) * GAT) / float(kolommen))
		var x0 := (breedte - (w * float(kolommen) + GAT * float(kolommen - 1))) * 0.5
		var h := 0.0
		for t in _tegels:
			h = maxf(h, _staand_hoog(t, w, laag))
		for i in _tegels.size():
			_leg_staand(_tegels[i], Vector2(x0 + float(i) * (w + GAT), 0.0), w, h, laag)
		y = h
	else:
		var h := 0.0
		for t in _tegels:
			h = maxf(h, _liggend_hoog(t, breedte))
		for i in _tegels.size():
			_leg_liggend(_tegels[i], Vector2(0.0, y), breedte, h)
			y += h + GAT
		y -= GAT
	custom_minimum_size = Vector2(0.0, ceilf(y))
	_bezig = false

## From the font, never from the Label: its minimum is the size `_pin` gave it.
func _icoon_hoog(t: Dictionary) -> float:
	var ic: Label = t["icoon"]
	return UiThema.wrap_hoogte(ic, 400.0)

func _tekst_hoog(t: Dictionary, breed: float) -> Dictionary:
	var nm: Label = t["naam"]
	var cf: Label = t["cijfers"]
	var nm_h := UiThema.wrap_hoogte(nm, breed)
	var cf_h := 0.0 if cf == null else UiThema.wrap_hoogte(cf, breed)
	return {"naam": nm_h, "cijfers": cf_h,
		"samen": nm_h + (0.0 if cf == null else REGEL_GAT + cf_h)}

## The animal over the name — or, on a low screen, beside it on one line.
func _staand_hoog(t: Dictionary, w: float, laag: bool) -> float:
	var binnen := w - 2.0 * VULLING_X
	if laag:
		var naast := _naast(t, binnen)
		var cf_h := 0.0 if t["cijfers"] == null else \
			REGEL_GAT + UiThema.wrap_hoogte(t["cijfers"], binnen)
		return maxf(float(UiThema.TAP), 2.0 * VULLING_Y + LIP + float(naast["h"]) + cf_h)
	var th := _tekst_hoog(t, binnen)
	return maxf(float(UiThema.TAP),
		2.0 * VULLING_Y + LIP + _icoon_hoog(t) + REGEL_GAT + float(th["samen"]))

## The animal and the name side by side, centred as one group.
func _naast(t: Dictionary, binnen: float) -> Dictionary:
	var ic: Label = t["icoon"]
	var nm: Label = t["naam"]
	var ic_w := float(ic.get_theme_font_size("font_size")) * 1.3
	var f := nm.get_theme_font("font")
	var nm_w := binnen - ic_w - 4.0
	if f != null:
		nm_w = minf(nm_w, f.get_string_size(nm.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			nm.get_theme_font_size("font_size")).x + 2.0)
	var nm_h := UiThema.wrap_hoogte(nm, nm_w)
	return {"ic_w": ic_w, "nm_w": nm_w, "nm_h": nm_h,
		"h": maxf(_icoon_hoog(t), nm_h)}

func _leg_staand(t: Dictionary, plek: Vector2, w: float, h: float, laag: bool) -> void:
	var b: Button = t["knop"]
	b.position = plek
	b.size = Vector2(w, h)
	b.custom_minimum_size = b.size
	var binnen := w - 2.0 * VULLING_X
	var nm: Label = t["naam"]
	if laag:
		var naast := _naast(t, binnen)
		var cf_h := 0.0 if t["cijfers"] == null else UiThema.wrap_hoogte(t["cijfers"], binnen)
		var inhoud := float(naast["h"]) + (0.0 if t["cijfers"] == null else REGEL_GAT + cf_h)
		var y0 := VULLING_Y + maxf(0.0, (h - LIP - 2.0 * VULLING_Y - inhoud) * 0.5)
		var x0 := VULLING_X + maxf(0.0, (binnen - float(naast["ic_w"]) - 4.0 - float(naast["nm_w"])) * 0.5)
		_pin(t["icoon"], Vector2(x0, y0), Vector2(float(naast["ic_w"]), float(naast["h"])))
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_pin(nm, Vector2(x0 + float(naast["ic_w"]) + 4.0, y0 + (float(naast["h"]) - float(naast["nm_h"])) * 0.5),
			Vector2(float(naast["nm_w"]), float(naast["nm_h"])))
		if t["cijfers"] != null:
			_pin(t["cijfers"], Vector2(VULLING_X, y0 + float(naast["h"]) + REGEL_GAT), Vector2(binnen, cf_h))
		return
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var th := _tekst_hoog(t, binnen)
	var ic_h := _icoon_hoog(t)
	var inhoud := ic_h + REGEL_GAT + float(th["samen"])
	var y := VULLING_Y + maxf(0.0, (h - LIP - 2.0 * VULLING_Y - inhoud) * 0.5)
	_pin(t["icoon"], Vector2(VULLING_X, y), Vector2(binnen, ic_h))
	y += ic_h + REGEL_GAT
	_pin(nm, Vector2(VULLING_X, y), Vector2(binnen, float(th["naam"])))
	if t["cijfers"] != null:
		y += float(th["naam"]) + REGEL_GAT
		_pin(t["cijfers"], Vector2(VULLING_X, y), Vector2(binnen, float(th["cijfers"])))

func _icoon_breed(t: Dictionary) -> float:
	var ic: Label = t["icoon"]
	return maxf(40.0, float(ic.get_theme_font_size("font_size")) * 1.4)

func _liggend_hoog(t: Dictionary, w: float) -> float:
	var tekst_w := w - 2.0 * VULLING_X - _icoon_breed(t) - VULLING_X
	var th := _tekst_hoog(t, tekst_w)
	return maxf(float(UiThema.TAP) + LIP,
		2.0 * VULLING_Y + LIP + maxf(_icoon_hoog(t), float(th["samen"])))

func _leg_liggend(t: Dictionary, plek: Vector2, w: float, h: float) -> void:
	var b: Button = t["knop"]
	b.position = plek
	b.size = Vector2(w, h)
	b.custom_minimum_size = b.size
	var ic_w := _icoon_breed(t)
	var tekst_x := VULLING_X + ic_w + VULLING_X
	var tekst_w := w - tekst_x - VULLING_X
	var th := _tekst_hoog(t, tekst_w)
	var midden := (h - LIP) * 0.5
	_pin(t["icoon"], Vector2(VULLING_X, midden - _icoon_hoog(t) * 0.5),
		Vector2(ic_w, _icoon_hoog(t)))
	var y := midden - float(th["samen"]) * 0.5
	var nm: Label = t["naam"]
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_pin(nm, Vector2(tekst_x, y), Vector2(tekst_w, float(th["naam"])))
	if t["cijfers"] != null:
		var cf: Label = t["cijfers"]
		cf.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_pin(cf, Vector2(tekst_x, y + float(th["naam"]) + REGEL_GAT),
			Vector2(tekst_w, float(th["cijfers"])))

## The measured size is pinned BEFORE the size is set, and `clip_text` takes
## the Label's own guess out of it (the trick of `ui/prikbordblad.gd`): an
## autowrapping Label answers the height it would need at the width it had a
## moment ago, and a Control never gets smaller than its minimum.
func _pin(l: Label, plek: Vector2, maat: Vector2) -> void:
	l.clip_text = true
	l.custom_minimum_size = maat
	l.position = plek
	l.size = maat
