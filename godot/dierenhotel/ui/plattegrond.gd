class_name UiPlattegrond
extends Control
## The map sheet (world.md §6.3/§7.3): a little 4 × 3 floor plan of the hotel.
##
## The grid positions are the hotel's floor plan, not a list — the child learns
## where the kitchen is relative to the garden, which is why the empty cells
## stay empty instead of the rooms closing ranks.  Every cell wears its own
## floor colour, the room you are in is the sunny one, and the doors are drawn
## in the gaps between the cells, so the plan reads as a map and not as a menu.
##
## WHY THIS LAYS ITSELF OUT.  This used to be a `GridContainer` of `Button`s
## with an anchored `VBoxContainer` inside every button.  A `Button` is not a
## `Container`: it never sorts that child, so the column kept the size the
## anchors gave it at the moment it was added and the words ended up half a
## sheet to the right of their own cell, while the grid stretched its columns to
## 530 units inside the sheet's `ScrollContainer`.  There is no container here
## at all now and no child carries an anchor: `_leg_uit()` gives every button
## and every label its `position` and its `size` in units, measured first
## (`get_minimum_size`, `UiThema.wrap_hoogte`), and the control reports the
## whole plan as its own minimum size so the sheet can measure it.

signal kamer_gekozen(kamer: String)

## `kamer id -> [kolom, rij]`, one-based, exactly the KAART table of §6.3.
const KAART := {
	"receptie": [1, 2], "gang": [2, 2], "kamer1": [2, 1], "kamer2": [2, 3],
	"keuken": [3, 2], "tuin": [4, 2], "wasserij": [3, 3], "zwembad": [4, 3],
	"speelzaal": [1, 1],
}
const KOLOMMEN := 4
const RIJEN := 3
const GAT := 8            ## air between two cells — the doors are drawn in it
const GAT_KRAP := 4       ## ... and this little on a phone, so 4 × 64 still fits
const CEL_MIN := 64       ## a tap target of 48 plus air, never less
const CEL_MAX := 120
const CEL_HOOG := 0.8     ## a cell is wider than it is tall, like a room
const CEL_HOOG_MIN := 56
const LUCHT := 4.0        ## between a cell's edge and its text
const ICOON_MIN := 16     ## the picture never shrinks past this — the cell grows
const DEUR_DIK := 6.0     ## the doorway stroke in the gap
const DEUR_DEEL := 0.4    ## ... spanning this much of the shared edge
const BADGE_MIN := 18.0

var _maten: Dictionary = {}
var _cellen: Dictionary = {}   ## kamer id -> {knop, icoon, naam, badge, plek}
var _deuren: Array = []        ## [{a: Vector2i, b: Vector2i, poort: bool}], each pair once
var _cel := Vector2(CEL_MAX, CEL_MAX * CEL_HOOG)
var _gat := float(GAT)
var _bezig := false

# ------------------------------------------------------------------ bouwen

func bouw(mt: Dictionary) -> void:
	name = "Plattegrond"
	_maten = mt
	# The plan is one block, centred on the sheet, as wide as its own cells.
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# The gaps are not a tap target; the buttons are tested on their own.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	for k in get_children():
		remove_child(k)
		k.queue_free()
	_cellen.clear()
	_deuren.clear()
	var plaatsen := _plaatsen()
	for id in plaatsen:
		_maak_cel(id, plaatsen[id])
	_zoek_deuren()
	_leg_uit()

## Which cell every room gets.  Rooms without a place in the table (any room a
## later run adds) take the first empty cells instead of vanishing.
func _plaatsen() -> Dictionary:
	var uit: Dictionary = {}
	var bezet: Dictionary = {}
	var rest: Array[String] = []
	for id in Rooms.lijst():
		if KAART.has(id):
			var p: Array = KAART[id]
			var plek := Vector2i(int(p[0]), int(p[1]))
			uit[id] = plek
			bezet["%d|%d" % [plek.x, plek.y]] = true
		else:
			rest.append(id)
	for rij in range(1, RIJEN + 1):
		for kol in range(1, KOLOMMEN + 1):
			if rest.is_empty():
				return uit
			if not bezet.has("%d|%d" % [kol, rij]):
				uit[rest.pop_front()] = Vector2i(kol, rij)
	return uit

func _maak_cel(id: String, plek: Vector2i) -> void:
	var r := Rooms.get_kamer(id)
	if r == null:
		return
	var b := Button.new()
	b.name = "P" + id
	b.text = ""                      # the two labels below are the whole cell
	b.tooltip_text = UiTekst.ga_naar(r.naam)
	b.focus_mode = Control.FOCUS_ALL
	_kleed(b, id, r)
	add_child(b)
	var icoon := _label("Icoon", r.icoon, maxi(UiThema.VLOER, int(_maten.get("icoon", 20))))
	b.add_child(icoon)
	var naam := _label("Naam", r.naam,
		maxi(UiThema.VLOER, int(_maten.get("klein", UiThema.VLOER))))
	naam.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(naam)
	var badge: Label = null
	if _wacht(id) > 0:
		badge = _label("Wacht", str(_wacht(id)), UiThema.VLOER)
		badge.add_theme_stylebox_override("normal",
			UiThema.vulling(UiThema.vlak(UiThema.PERZIK, 999, 2, UiThema.WIT), 5, 1))
		b.add_child(badge)
	b.pressed.connect(func() -> void:
		Snd.tik()
		kamer_gekozen.emit(id))
	_cellen[id] = {"knop": b, "icoon": icoon, "naam": naam, "badge": badge, "plek": plek}

func _label(naam: String, tekst: String, maat: int) -> Label:
	var l := Label.new()
	l.name = naam
	l.text = tekst
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", maxi(UiThema.VLOER, maat))
	l.add_theme_color_override("font_color", UiThema.INKT)
	return l

## A cell wears its own floor (art-sound-rules.md §2.3), lightened towards the
## paper so the ink on it stays readable; the room the child is in is the sunny
## one, exactly like the pressed chip in the room bar.
func _kleed(b: Button, id: String, r) -> void:
	var kl := _vloerkleur(r).lerp(UiThema.WIT, 0.35)
	var nu := id == World.kamer_nu()
	if nu:
		kl = kl.lerp(UiThema.ZON, 0.45)
	var rand := 3 if nu else 2
	var randkl := UiThema.PERZIK_D if nu else UiThema.KURK
	b.add_theme_stylebox_override("normal", UiThema.vlak(kl, 10, rand, randkl))
	b.add_theme_stylebox_override("hover", UiThema.vlak(kl.darkened(0.06), 10, rand, randkl))
	var in_druk := UiThema.vlak(kl.darkened(0.12), 10, maxi(rand, 3), UiThema.PERZIK_D)
	b.add_theme_stylebox_override("pressed", in_druk)
	b.add_theme_stylebox_override("hover_pressed", in_druk)
	b.add_theme_stylebox_override("focus",
		UiThema.vlak(Color(0, 0, 0, 0), 10, 3, UiThema.PERZIK_D))

## The first colour of the room's floor pattern — the pool is its water, not the
## lawn it stands on, or it would be the garden twice.
static func _vloerkleur(r) -> Color:
	if r == null:
		return ArtVloer.PLANK[0]
	var bad: Dictionary = r.bad
	if not bad.is_empty():
		return ArtVloer.BADWATER[0]
	var soort := str(r.vloer)
	if soort == "loper":
		return ArtVloer.LOPER_M[0]
	if soort == "zacht":
		return ArtVloer.ZACHT[0]
	if soort == "tegel":
		return ArtVloer.TEGEL[0]
	if soort == "gras":
		return ArtVloer.GRAS[0]
	return ArtVloer.PLANK[0]

## The waiting-guest counter per room; `Hotel` owns the number (W2).
func _wacht(id: String) -> int:
	if not Hotel.has_method("wacht_in"):
		return 0
	return int(Hotel.call("wacht_in", id))

## Every door between two cells that share an edge, once per pair.  A door the
## table cannot show (two rooms that are not neighbours on the plan) is left out
## rather than drawn across the map.
func _zoek_deuren() -> void:
	var gezien: Dictionary = {}
	for id in _cellen:
		var r := Rooms.get_kamer(id)
		if r == null:
			continue
		for dr in r.deuren:
			var naar := str(dr.get("naar", ""))
			if not _cellen.has(naar):
				continue
			var a: Vector2i = _cellen[id]["plek"]
			var b: Vector2i = _cellen[naar]["plek"]
			var af := (a - b).abs()
			if af.x + af.y != 1:
				continue
			var sleutel := "%s|%s" % [id, naar] if id < naar else "%s|%s" % [naar, id]
			if gezien.has(sleutel):
				continue
			gezien[sleutel] = true
			_deuren.append({"a": a, "b": b, "poort": bool(dr.get("poort", false))})

# ------------------------------------------------------------------ meten

func _ready() -> void:
	_leg_uit()

func _notification(wat: int) -> void:
	if wat == NOTIFICATION_RESIZED:
		_leg_uit()

## The width the sheet really gives the plan.  Before the first layout pass the
## parent has no size yet, so the sheet's own rule (`UiBlad`) answers instead —
## that way the height this control reports to `UiBlad._meet()` is already the
## height it will have, and the sheet does not end up with a hole in it.
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
	return float(KOLOMMEN * CEL_MAX + (KOLOMMEN - 1) * GAT)

## The whole plan: cell size from the width, then every button and every label
## placed by hand.  Re-entrant-safe — writing `custom_minimum_size` makes the
## sheet sort again, which comes straight back here as NOTIFICATION_RESIZED.
func _leg_uit() -> void:
	if _bezig or _cellen.is_empty():
		return
	_bezig = true
	var breedte := _beschikbaar()
	var cel_w := clampf(floor((breedte - (KOLOMMEN - 1) * GAT) / KOLOMMEN),
		float(CEL_MIN), float(CEL_MAX))
	# The cell never goes under 64 (a 48 tap target plus air); on the narrowest
	# phone it is the GAP that gives way, so four cells still fit the sheet.
	var gat := float(GAT)
	if KOLOMMEN * cel_w + (KOLOMMEN - 1) * gat > breedte:
		gat = clampf(floor((breedte - KOLOMMEN * cel_w) / (KOLOMMEN - 1)),
			float(GAT_KRAP), float(GAT))
	# The word is measured BEFORE the height is fixed: a cell that cannot show
	# its picture and its word without them overlapping is a taller cell, not a
	# smaller picture.  On a phone "Zwembad" drops to the 12 px floor rather
	# than breaking in two (HOTEL.md §9: pictogram AND word, always readable).
	var nodig := 0.0
	for id in _cellen:
		nodig = maxf(nodig, _meet_tekst(_cellen[id], cel_w - 2.0 * LUCHT))
	_cel = Vector2(cel_w, maxf(maxf(float(CEL_HOOG_MIN), round(cel_w * CEL_HOOG)),
		ceilf(nodig + 2.0 * LUCHT)))
	_gat = gat
	var maat := Vector2(KOLOMMEN * _cel.x + (KOLOMMEN - 1) * gat,
		RIJEN * _cel.y + (RIJEN - 1) * gat)
	if custom_minimum_size != maat:
		custom_minimum_size = maat
	if not (get_parent() is Container) and size != maat:
		size = maat
	for id in _cellen:
		_zet_cel(_cellen[id])
	queue_redraw()
	_bezig = false

## How much height this cell's picture and word need at this width, and what
## font size the word gets: the biggest that still keeps the name on one line,
## never under the 12 px floor.  `naam_h` is remembered for `_zet_cel`.
func _meet_tekst(c: Dictionary, breed: float) -> float:
	var naam: Label = c["naam"]
	var maat := maxi(UiThema.VLOER, int(_maten.get("klein", UiThema.VLOER)))
	var f := naam.get_theme_font("font")
	if f != null:
		while maat > UiThema.VLOER \
				and f.get_string_size(naam.text, HORIZONTAL_ALIGNMENT_CENTER, -1, maat).x > breed:
			maat -= 1
	naam.add_theme_font_size_override("font_size", maat)
	var naam_h := UiThema.wrap_hoogte(naam, breed)
	c["naam_h"] = naam_h
	# and the smallest picture this map is willing to show under it
	var icoon: Label = c["icoon"]
	icoon.add_theme_font_size_override("font_size", ICOON_MIN)
	return naam_h + 2.0 + icoon.get_minimum_size().y

## One cell: the picture centred at the top, the word centred under it, the
## waiting badge in the corner — all of it inside the button's rectangle, which
## is what `tests/test_plattegrond.gd` measures.
func _zet_cel(c: Dictionary) -> void:
	var plek: Vector2i = c["plek"]
	var knop: Button = c["knop"]
	knop.position = Vector2((plek.x - 1) * (_cel.x + _gat), (plek.y - 1) * (_cel.y + _gat))
	knop.size = _cel
	var breed := _cel.x - 2.0 * LUCHT
	var binnen := _cel.y - 2.0 * LUCHT
	var naam: Label = c["naam"]
	naam.size = Vector2(breed, naam.size.y)
	var naam_h := minf(float(c.get("naam_h", 0.0)), binnen)
	# The picture is capped at 45 % of the cell and then shrinks until the word
	# fits under it — a colour-emoji line is much taller than its font size.
	var icoon: Label = c["icoon"]
	var maat := maxi(ICOON_MIN,
		int(minf(float(_maten.get("icoon", 20)), floor(_cel.y * 0.45))))
	var ic_h := 0.0
	while true:
		icoon.add_theme_font_size_override("font_size", maat)
		ic_h = icoon.get_minimum_size().y
		if ic_h + 2.0 + naam_h <= binnen or maat <= ICOON_MIN:
			break
		maat -= 1
	ic_h = minf(ic_h, maxf(0.0, binnen - naam_h - 2.0))
	var y := maxf(LUCHT, (_cel.y - (ic_h + 2.0 + naam_h)) * 0.5)
	icoon.position = Vector2(LUCHT, y)
	icoon.size = Vector2(breed, ic_h)
	naam.position = Vector2(LUCHT,
		clampf(y + ic_h + 2.0, LUCHT, _cel.y - LUCHT - naam_h))
	# The word's minimum is its OWN measurement, written down: `UiBlad._wrap()`
	# hands every autowrapping label without one the full width of the sheet,
	# and a Control is never smaller than its minimum — that is how the names
	# ended up 532 units wide, half a sheet to the right of their cells.
	naam.custom_minimum_size = Vector2(breed, naam_h)
	naam.size = Vector2(breed, naam_h)
	var badge: Label = c["badge"]
	if badge != null:
		var m := badge.get_combined_minimum_size()
		badge.size = Vector2(clampf(m.x, BADGE_MIN, _cel.x - 6.0),
			clampf(m.y, BADGE_MIN, _cel.y - 6.0))
		badge.position = Vector2(_cel.x - badge.size.x - 3.0, 3.0)

# ------------------------------------------------------------------ deuren

## The doors, in the gaps between the cells: a short thick stroke on the shared
## edge, dashed and lighter when it is a gate (`poort`) to the outside.
func _draw() -> void:
	for d in _deuren:
		var a: Vector2i = d["a"]
		var b: Vector2i = d["b"]
		var poort: bool = d["poort"]
		var kl: Color = ArtDecor.DEURKL.lerp(UiThema.WIT, 0.5 if poort else 0.08)
		var p1 := Vector2.ZERO
		var p2 := Vector2.ZERO
		if a.y == b.y:
			var x := (mini(a.x, b.x) - 1) * (_cel.x + _gat) + _cel.x + _gat * 0.5
			var mid := (a.y - 1) * (_cel.y + _gat) + _cel.y * 0.5
			var half := _cel.y * DEUR_DEEL * 0.5
			p1 = Vector2(x, mid - half)
			p2 = Vector2(x, mid + half)
		else:
			var y := (mini(a.y, b.y) - 1) * (_cel.y + _gat) + _cel.y + _gat * 0.5
			var mid := (a.x - 1) * (_cel.x + _gat) + _cel.x * 0.5
			var half := _cel.x * DEUR_DEEL * 0.5
			p1 = Vector2(mid - half, y)
			p2 = Vector2(mid + half, y)
		if poort:
			_streepjes(p1, p2, kl)
		else:
			draw_line(p1, p2, kl, DEUR_DIK, true)

func _streepjes(p1: Vector2, p2: Vector2, kl: Color) -> void:
	var stap := (p2 - p1) / 5.0
	for i in [0, 2, 4]:
		draw_line(p1 + stap * float(i), p1 + stap * float(i + 1), kl, DEUR_DIK, true)

# ------------------------------------------------------------------ meetlat

## What the plan came out at — one machine-readable number for the tests.
func celmaat() -> Vector2:
	return _cel

func gat() -> float:
	return _gat

func knop_van(id: String) -> Button:
	return _cellen[id]["knop"] if _cellen.has(id) else null

func deurparen() -> int:
	return _deuren.size()
