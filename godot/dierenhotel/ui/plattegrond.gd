class_name UiPlattegrond
extends Control
## The map sheet (world.md §6.3/§7.3): the hotel as a TOWER, seen from the side.
##
## Owner, 2026-09-24: the hotel has to feel big and tall, like Habbo Hotel, so
## the map is a cross-section of the building — one row per floor
## (`Kamer.etage`), the top floor at the top and the cellar at the bottom.  In
## every row the room the stairs reach comes first; the floor's other rooms
## follow in the order their doors join them, so a door between two cells side
## by side is drawn in the gap between them (a gate dashed).  Down the left runs
## the stairwell: a line through one small round floor button per row
## (`Rooms.etage_teken`), lit on the floor the child is on, and that floor's
## whole row wears a faint sunny band.  Every cell wears its own floor colour
## and the room you are in is the sunny one, so the plan reads as a building
## and not as a menu.  The same sheet is the stairs' panel
## (`scenes/main.gd::_toren`).
##
## The table is COMPUTED from `Rooms` (`kaart()`), never written down: a room
## added later gets a cell on its own floor without anyone touching this file.
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

const GAT := 8            ## air between two cells — the doors are drawn in it
const GAT_KRAP := 4       ## ... and this little on a phone
const CEL_WENS := 64      ## the width a cell would like: a 48 tap target plus air
const CEL_MIN := 56       ## ... and the least it takes, when a phone has no more
const CEL_MAX := 120
const CEL_HOOG := 0.6     ## a floor of a tower is wide and low
const CEL_HOOG_MIN := 56
const LUCHT := 4.0        ## between a cell's edge and its text
const LUCHT_KRAP := 2.0   ## ... in a cell under CEL_WENS, where "Zwembad" needs it all
const SCHACHT := 36       ## the stairwell column on the left, its air included
const SCHACHT_KRAP := 24  ## ... on a phone
const SCHACHT_DIK := 4.0  ## the shaft line
const KNOP_R_MAX := 14.0  ## radius of a floor button in the shaft
const ICOON_MIN := 16     ## the picture never shrinks past this — the cell grows
const DEUR_DIK := 6.0     ## the doorway stroke in the gap
const DEUR_DEEL := 0.4    ## ... spanning this much of the shared edge
const BADGE_MIN := 18.0
const BAND_ALFA := 0.35   ## the sunny band behind the floor the child is on

var _maten: Dictionary = {}
var _cellen: Dictionary = {}   ## kamer id -> {knop, icoon, naam, badge, plek}
var _deuren: Array = []        ## [{a: Vector2i, b: Vector2i, poort: bool, sleutel}], each pair once
var _etages: Array[int] = []   ## the floors top-down: row r is `_etages[r - 1]`
var _kolommen := 1
var _cel := Vector2(CEL_MAX, CEL_MAX * CEL_HOOG)
var _gat := float(GAT)
var _schacht := float(SCHACHT)
var _lucht := LUCHT
var _bezig := false

# ------------------------------------------------------------------ de toren

## `kamer id -> Vector2i(kolom, rij)`, one-based: row 1 is the top floor
## (`Rooms.etages()`), column 1 the room the stairs reach on that floor.
## Computed from `Rooms` every time, so every room of `lijst()` has a cell.
static func kaart() -> Dictionary:
	var uit: Dictionary = {}
	var rij := 0
	for e in Rooms.etages():
		rij += 1
		var kol := 0
		for id in rij_van(int(e)):
			kol += 1
			uit[id] = Vector2i(kol, rij)
	return uit

## As many columns as the widest floor has rooms.
static func kolommen() -> int:
	var n := 1
	for e in Rooms.etages():
		n = maxi(n, Rooms.op_etage(int(e)).size())
	return n

## One row per floor.
static func rijen() -> int:
	return maxi(1, Rooms.etages().size())

## The rooms of floor `e` from left to right.  The stairs' room first; every next
## cell is then a room with a door to the cell before it when there is one, so
## rooms joined by a door stand side by side wherever one row allows it (the
## door is drawn in their gap); otherwise the nearest room left on the floor —
## breadth-first over the floor's own doors from the stairs — and a room without
## a door on its floor last, in `lijst()` order.
static func rij_van(e: int) -> Array[String]:
	var alle := Rooms.op_etage(e)
	var rij: Array[String] = []
	if alle.is_empty():
		return rij
	var begin := Rooms.trap_kamer(e)
	if begin.is_empty():
		begin = alle[0]
	var dichtbij: Array[String] = [begin]
	var i := 0
	while i < dichtbij.size():
		for n in _deur_buren(dichtbij[i], alle):
			if not dichtbij.has(n):
				dichtbij.append(n)
		i += 1
	for id in alle:
		if not dichtbij.has(id):
			dichtbij.append(id)
	rij.append(begin)
	while rij.size() < dichtbij.size():
		var volgende := ""
		for n in _deur_buren(rij[rij.size() - 1], alle):
			if not rij.has(n):
				volgende = n
				break
		if volgende.is_empty():
			for id in dichtbij:
				if not rij.has(id):
					volgende = id
					break
		rij.append(volgende)
	return rij

## The rooms of `alle` (one floor) this room has a door to, in door order.
static func _deur_buren(id: String, alle: Array[String]) -> Array[String]:
	var uit: Array[String] = []
	var r := Rooms.get_kamer(id)
	if r == null:
		return uit
	for dr in r.deuren:
		var naar := str(dr.get("naar", ""))
		if alle.has(naar) and not uit.has(naar):
			uit.append(naar)
	return uit

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
	_etages = Rooms.etages()
	_kolommen = kolommen()
	var plaatsen := kaart()
	for id in Rooms.lijst():
		if plaatsen.has(id):
			_maak_cel(id, plaatsen[id])
	_zoek_deuren()
	_leg_uit()

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
## tower cannot show (two rooms of one floor that are not side by side, like
## the gang's doors to kamer 2 and the kitchen) is left out rather than drawn
## across the map; the stairs are no door and are the stairwell instead.
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
			_deuren.append({"a": a, "b": b, "poort": bool(dr.get("poort", false)),
				"sleutel": sleutel})

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
	return float(SCHACHT) + GAT * 0.5 + float(_kolommen * CEL_MAX + (_kolommen - 1) * GAT)

## The whole plan: cell size from the width, then every button and every label
## placed by hand.  Re-entrant-safe — writing `custom_minimum_size` makes the
## sheet sort again, which comes straight back here as NOTIFICATION_RESIZED.
func _leg_uit() -> void:
	if _bezig or _cellen.is_empty():
		return
	_bezig = true
	var breedte := _beschikbaar()
	# On a narrow sheet this gives way in turn: first the gaps, then the stairwell
	# shaft, and only then the cells — never under 56 (a 48 tap target plus
	# air).  The 326 unit phone frame ends at a 24 shaft, 4 gaps and four cells
	# of 59, which is 274: the whole sheet.
	var gat := float(GAT)
	var schacht := float(SCHACHT)
	var cel_w := _cel_breed(breedte, schacht, gat)
	if cel_w < CEL_WENS:
		gat = float(GAT_KRAP)
		cel_w = _cel_breed(breedte, schacht, gat)
	if cel_w < CEL_WENS:
		schacht = float(SCHACHT_KRAP)
		cel_w = _cel_breed(breedte, schacht, gat)
	cel_w = clampf(cel_w, float(CEL_MIN), float(CEL_MAX))
	# ... and in a cell that narrow the text keeps 2 units from the edge instead
	# of 4, so "Zwembad" and "Speelzaal" (54 and 53 at 12 px) stay one word.
	_lucht = LUCHT if cel_w >= CEL_WENS else LUCHT_KRAP
	# The word is measured BEFORE the height is fixed: a cell that cannot show
	# its picture and its word without them overlapping is a taller cell, not a
	# smaller picture.  On a phone "Zwembad" drops to the 12 px floor rather
	# than breaking in two (HOTEL.md §9: pictogram AND word, always readable).
	var nodig := 0.0
	for id in _cellen:
		nodig = maxf(nodig, _meet_tekst(_cellen[id], cel_w - 2.0 * _lucht))
	_cel = Vector2(cel_w, maxf(maxf(float(CEL_HOOG_MIN), round(cel_w * CEL_HOOG)),
		ceilf(nodig + 2.0 * _lucht)))
	_gat = gat
	_schacht = schacht
	var rij_n := float(maxi(1, _etages.size()))
	var maat := Vector2(_breedte(),
		2.0 * _boven() + rij_n * _cel.y + (rij_n - 1.0) * gat)
	if custom_minimum_size != maat:
		custom_minimum_size = maat
	if not (get_parent() is Container) and size != maat:
		size = maat
	for id in _cellen:
		_zet_cel(_cellen[id])
	queue_redraw()
	_bezig = false

## The cell width that fills `breedte` with this shaft and these gaps.
func _cel_breed(breedte: float, schacht: float, gat: float) -> float:
	var k := float(_kolommen)
	return floor((breedte - schacht - gat * 0.5 - (k - 1.0) * gat) / k)

## Where column 1 begins: after the shaft and half a gap.
func _links() -> float:
	return _schacht + _gat * 0.5

## Half a gap above the top floor and below the cellar, so the sunny band of
## either has room to stick out of its row as far as it does on the others.
func _boven() -> float:
	return _gat * 0.5

## The width of the whole tower: shaft, columns and the gaps between them.
func _breedte() -> float:
	var k := float(_kolommen)
	return _links() + k * _cel.x + (k - 1.0) * _gat

## The top-left corner of a cell.
func _hoek(plek: Vector2i) -> Vector2:
	return Vector2(_links() + (plek.x - 1) * (_cel.x + _gat),
		_boven() + (plek.y - 1) * (_cel.y + _gat))

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
	knop.position = _hoek(plek)
	knop.size = _cel
	var breed := _cel.x - 2.0 * _lucht
	var binnen := _cel.y - 2.0 * _lucht
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
	var y := maxf(_lucht, (_cel.y - (ic_h + 2.0 + naam_h)) * 0.5)
	icoon.position = Vector2(_lucht, y)
	icoon.size = Vector2(breed, ic_h)
	naam.position = Vector2(_lucht,
		clampf(y + ic_h + 2.0, _lucht, _cel.y - _lucht - naam_h))
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

# ------------------------------------------------------------------ tekenen

## Under the cells, back to front: the sunny band of the floor the child is on,
## the stairwell with its floor buttons, and the doors in the gaps.
func _draw() -> void:
	if _cellen.is_empty():
		return
	_teken_band()
	_teken_schacht()
	_teken_deuren()

## The row of the floor the child is on, a faint sunny band from the shaft to
## the last column that sticks out half a gap above and below its cells.
func _teken_band() -> void:
	var rij := band_rij()
	if rij <= 0:
		return
	var y := _hoek(Vector2i(1, rij)).y - _gat * 0.5
	var band := Rect2(0.0, y, _breedte(), _cel.y + _gat)
	draw_style_box(UiThema.vlak(Color(UiThema.ZON, BAND_ALFA), 10), band)

## The stairwell: one line from the top floor down to the cellar, and on it a
## small round button per floor with the floor's sign (`Rooms.etage_teken`) —
## like the floor signs on a tall building's landings.  The button of the floor
## the child is on is lit.  They are drawn, not tapped: the whole row of a floor
## is where a finger goes.
func _teken_schacht() -> void:
	if _etages.is_empty():
		return
	var x := _schacht * 0.5
	var boven := _hoek(Vector2i(1, 1)).y
	var onder := _hoek(Vector2i(1, _etages.size())).y + _cel.y
	draw_line(Vector2(x, boven), Vector2(x, onder), UiThema.KNOP_RAND, SCHACHT_DIK, true)
	var nu := band_rij()
	var f := get_theme_font("font", "Label")
	var maat := maxi(UiThema.VLOER, int(_maten.get("klein", UiThema.VLOER)))
	for i in _etages.size():
		var vak := etage_knop(_etages[i])
		var c := vak.get_center()
		var r := vak.size.x * 0.5
		var hier := i + 1 == nu
		draw_circle(c, r, UiThema.ZON if hier else UiThema.WIT, true, -1.0, true)
		draw_circle(c, r, UiThema.PERZIK_D if hier else UiThema.KNOP_RAND, false, 2.0, true)
		if f != null:
			var basis := c.y + (f.get_ascent(maat) - f.get_descent(maat)) * 0.5
			draw_string(f, Vector2(c.x - r, basis), Rooms.etage_teken(_etages[i]),
				HORIZONTAL_ALIGNMENT_CENTER, 2.0 * r, maat, UiThema.INKT)

## The doors, in the gaps between the cells: a short thick stroke on the shared
## edge, dashed and lighter when it is a gate (`poort`) to the outside.
func _teken_deuren() -> void:
	for d in _deuren:
		var a: Vector2i = d["a"]
		var b: Vector2i = d["b"]
		var poort: bool = d["poort"]
		var kl: Color = ArtDecor.DEURKL.lerp(UiThema.WIT, 0.5 if poort else 0.08)
		var p1 := Vector2.ZERO
		var p2 := Vector2.ZERO
		if a.y == b.y:
			var hoek := _hoek(Vector2i(mini(a.x, b.x), a.y))
			var x := hoek.x + _cel.x + _gat * 0.5
			var mid := hoek.y + _cel.y * 0.5
			var half := _cel.y * DEUR_DEEL * 0.5
			p1 = Vector2(x, mid - half)
			p2 = Vector2(x, mid + half)
		else:
			var hoek := _hoek(Vector2i(a.x, mini(a.y, b.y)))
			var y := hoek.y + _cel.y + _gat * 0.5
			var mid := hoek.x + _cel.x * 0.5
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

## The width of the shaft column on the left.
func schacht() -> float:
	return _schacht

func knop_van(id: String) -> Button:
	return _cellen[id]["knop"] if _cellen.has(id) else null

## Where a room sits on this map, `Vector2i(kolom, rij)` as in `kaart()`;
## `Vector2i.ZERO` for a room without a cell.
func plek_van(id: String) -> Vector2i:
	return _cellen[id]["plek"] if _cellen.has(id) else Vector2i.ZERO

## The floor button of floor `e` in the stairwell, as the square around its circle
## in this control's own units; an empty rectangle for a floor not on the map.
func etage_knop(e: int) -> Rect2:
	var i := _etages.find(e)
	if i < 0:
		return Rect2()
	var r := minf(KNOP_R_MAX, minf(_schacht * 0.5 - 1.0, _cel.y * 0.5 - 2.0))
	var c := Vector2(_schacht * 0.5, _hoek(Vector2i(1, i + 1)).y + _cel.y * 0.5)
	return Rect2(c - Vector2(r, r), Vector2(2.0 * r, 2.0 * r))

## The row that wears the sunny band — the floor of the room in view — or 0
## when the camera is in no room of the map.
func band_rij() -> int:
	var nu := World.kamer_nu()
	if not Rooms.bestaat(nu):
		return 0
	return _etages.find(Rooms.etage(nu)) + 1

func deurparen() -> int:
	return _deuren.size()

## The doors the map draws, each as "a|b" (the two room ids, sorted), sorted.
func deursleutels() -> Array[String]:
	var uit: Array[String] = []
	for d in _deuren:
		uit.append(str(d["sleutel"]))
	uit.sort()
	return uit
