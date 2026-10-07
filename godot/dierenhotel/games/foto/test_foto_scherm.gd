extends Proef
## FotoScherm alone — what the camera of the photo booth sees (owner,
## 2026-10-06: "kan het echt in het hokje geanimeerd worden van een camera
## hokje PoV met alle dieren die erin zitten").
##
## The screen is held in the hand, OUTSIDE the tree: then it is never drawn and
## only moves when the test turns its clock (`tik`), so every frame of a walk
## in, a shuffle, the countdown, the click and the walk out can be checked.
## What it draws cannot be seen headless; what it would draw can, through its
## public face only: `vak_rect` (place i, left to right, as it is NOW),
## `prijs_rect`, `beeld_rect`, `binnen()`, how a place is drawn (`stand_van`:
## pose, which way the nose points, which row), the order the places are drawn
## in (`teken_volgorde`), whether the clock changes anything (`beweegt`), and
## the state the game reads (`dieren`, `vakken`, `foto`, `flits`, `ontwikkel`,
## `tel_getal`).

const BREED := 300.0
const STAP := 1.0 / 30.0

var _rust_voor := false
var _schermen: Array = []

func _scherm(rust := false, breed := BREED) -> FotoScherm:
	if _schermen.is_empty():
		_rust_voor = Ui.rust_modus()
	Ui.zet_rust_modus(rust)
	var s := FotoScherm.new()
	s.size = FotoScherm.maat_bij(breed)
	_schermen.append(s)
	return s

func _af() -> void:
	for s in _schermen:
		var sch: FotoScherm = s
		if is_instance_valid(sch):
			if sch.get_parent() != null:
				sch.get_parent().remove_child(sch)
			sch.free()
	_schermen.clear()
	Ui.zet_rust_modus(_rust_voor)

## Turn the clock `sec` seconds on in frames of a thirtieth.
func _tik(s: FotoScherm, sec: float) -> void:
	var n := int(round(sec / STAP))
	for _i in n:
		s.tik(STAP)

## Everybody in, standing still (the walks in take one KOM_NA after the other).
func _allen_binnen(s: FotoScherm) -> void:
	_tik(s, FotoScherm.KOM_S + FotoScherm.KOM_NA * float(s.dieren.size()) + 0.1)

## Where the paws of a row are, on this screen.
func _voet(s: FotoScherm, rij_y: float) -> float:
	var b := s.beeld_rect()
	return b.position.y + rij_y * b.size.y

## The breath of the idle animation, at most, in px.
func _adem(s: FotoScherm) -> float:
	return 1.5 * s.beeld_rect().size.y / 150.0 + 0.05

## `n` made-up guests (unknown ids are dogs).
func _ids(n: int) -> Array:
	var ids: Array = []
	for k in n:
		ids.append("d%d" % k)
	return ids

## Where the middle of the cabin is across: right of it a nose points left.
func _midden(s: FotoScherm) -> float:
	var b := s.beeld_rect()
	return b.position.x + (FotoScherm.GORDIJN + FotoScherm.MIDDEN * (1.0 - FotoScherm.GORDIJN)) * b.size.x

# ---------------------------------------------------------------- the size

## Landscape at every width the game asks for (180 … 600): the picture, the row
## of price tags under it, the edge round both — inside the Control, the same
## for any number of animals, and no tap is caught.
func test_maat_en_vorm() -> void:
	var een := FotoScherm.maat_bij(100.0)
	for breed in [180.0, 240.0, 300.0, 450.0, 600.0]:
		var m := FotoScherm.maat_bij(breed)
		gelijk(m.x, breed, "%d breed" % breed)
		waar(absf(m.y / m.x - een.y / een.x) < 0.0001, "%d: dezelfde verhouding (%s)" % [breed, str(m)])
		gelijk(FotoScherm.maat_bij(breed, 4), m, "%d: vier dieren, dezelfde maat" % breed)
		var s := _scherm(true, breed)
		var b := s.beeld_rect()
		var vorm := b.size.x / b.size.y
		waar(vorm >= 1.3 and vorm <= 1.75, "%d: het beeld is liggend (%.2f)" % [breed, vorm])
		waar(Rect2(Vector2.ZERO, s.size).encloses(b), "%d: het beeld in het scherm" % breed)
		for i in s.vakken:
			var p := s.prijs_rect(i)
			waar(p.position.y >= b.end.y, "%d: prijskaartje %d onder het beeld" % [breed, i])
			waar(p.end.y <= s.size.y + 0.01, "%d: prijskaartje %d in het scherm" % [breed, i])
		waar(FotoScherm.vak_breed(breed, 2) > FotoScherm.vak_breed(breed, 4), "%d: vak_breed per aantal" % breed)
	var s := _scherm(true)
	gelijk(s.mouse_filter, Control.MOUSE_FILTER_IGNORE, "een tik gaat erdoorheen")
	s.custom_minimum_size = Vector2(500, 500)
	s.meet = func() -> Vector2: return FotoScherm.maat_bij(240.0)
	gelijk(s.inhoud_maat(), FotoScherm.maat_bij(240.0), "de maat vraagt het spel")
	gelijk(s.custom_minimum_size, Vector2.ZERO, "en laat de oude speld los")
	_af()

## Lower than `maat_bij` asks — on a phone on its side the band over the
## animals is 115 high, the smallest screen at its own shape 136: the screen
## keeps its width, the picture gets wider for its height and the price tags
## keep the size they have on the smallest screen (they stay readable); with
## four animals everybody still stands in the picture.  Far lower everything
## shrinks, in the middle, and still stays inside.
func test_lager_dan_gevraagd() -> void:
	var s := _scherm(true, 180.0)
	s.dieren = _ids(4)
	var vol_beeld := s.beeld_rect()
	var vol_kaart := s.prijs_rect(0)
	s.size = Vector2(180.0, 115.0)
	var b := s.beeld_rect()
	waar(absf(b.size.x - vol_beeld.size.x) < 0.01, "zo breed als het kleinste scherm (%.1f)" % b.size.x)
	var vorm := b.size.y / b.size.x
	waar(vorm < FotoScherm.BEELD - 0.05 and vorm >= FotoScherm.BEELD_MIN - 0.001,
		"het beeld is breder voor zijn hoogte (%.3f)" % vorm)
	waar(Rect2(Vector2.ZERO, s.size).encloses(b), "het beeld in het scherm (%s)" % str(b))
	for i in s.vakken:
		var p := s.prijs_rect(i)
		waar(p.size.is_equal_approx(vol_kaart.size), "kaartje %d houdt zijn maat (%s, %s)" % [i, str(p.size), str(vol_kaart.size)])
		waar(p.position.y >= b.end.y and p.end.y <= s.size.y + 0.01, "kaartje %d onder het beeld, in het scherm" % i)
		var r := s.vak_rect(i)
		waar(r.end.y <= b.end.y + 0.5 and r.position.y >= b.position.y - 0.5, "dier %d in het beeld (%s)" % [i, str(r)])
	# far lower: all of it at the lowest picture, smaller, in the middle
	s.size = Vector2(300.0, 150.0)
	b = s.beeld_rect()
	waar(Rect2(Vector2.ZERO, s.size).encloses(b), "te laag: het beeld past nog (%s)" % str(b))
	waar(absf(b.size.y / b.size.x - FotoScherm.BEELD_MIN) < 0.001, "te laag: het laagste beeld (%.3f)" % (b.size.y / b.size.x))
	waar(absf(b.get_center().x - 150.0) < 0.5, "te laag: in het midden")
	for i in s.vakken:
		waar(s.prijs_rect(i).end.y <= 150.01, "te laag: kaartje %d ook" % i)
	_af()

## A guest of the hotel: the id is enough, its kind and clothes come from the
## hotel.  `zet(prijs)` changes the price and nothing else.
func test_een_gast_van_het_hotel_en_de_prijs() -> void:
	var g: Dictionary = State.gasten_pool()[0]
	var s := _scherm(true)
	s.dieren = [str(g["id"])]
	waar(s.vak_rect(0).size.x > 4.0, "een gast van het hotel staat erin")
	s.zet(5)
	gelijk(s.prijs, 5, "zet(prijs)")
	gelijk(s.dieren, [str(g["id"])], "zet(prijs) laat de dieren staan")
	gelijk(FotoScherm.maat_bij(100.0, 3), FotoScherm.maat_bij(100.0), "maat_bij(breed, n): dezelfde maat voor elk aantal")
	_af()

# ----------------------------------------------------------- the places

## Per number of animals: at least two places; the animals stand left to
## right in the cabin right of the curtain, a price tag under each place and
## no tag on another; three: the middle one at the back on the bench (smaller,
## higher); four: the middle two at the back.  An empty booth shows two dashed
## places, one animal one.
func test_plekken_per_aantal() -> void:
	var s := _scherm(true)
	var b := s.beeld_rect()
	var gordijn := b.position.x + b.size.x * FotoScherm.GORDIJN
	for n in range(0, 5):
		var ids := _ids(n)
		s.dieren = ids
		var wat := "%d dieren" % n
		gelijk(s.vakken, maxi(2, n), "%s: vakken" % wat)
		gelijk(s.dieren.size(), n, "%s: dieren" % wat)
		gelijk(s.binnen(), ids, "%s: in reduced motion staat iedereen er meteen" % wat)
		var vorige := -INF
		for i in s.vakken:
			var r := s.vak_rect(i)
			waar(r.size.x > 4.0 and r.size.y > 4.0, "%s: plek %d heeft een maat" % [wat, i])
			var mid := r.get_center().x
			waar(mid > gordijn and mid < b.end.x, "%s: plek %d staat in het hokje, naast het gordijn" % [wat, i])
			waar(mid > vorige + 4.0, "%s: plek %d staat rechts van %d" % [wat, i, i - 1])
			vorige = mid
			waar(r.end.y <= b.end.y + 0.5 and r.position.y >= b.position.y, "%s: plek %d in het beeld (%s)" % [wat, i, str(r)])
			var p := s.prijs_rect(i)
			waar(absf(p.get_center().x - mid) < 1.0, "%s: het kaartje van %d staat eronder (%.1f, %.1f)" % [wat, i, p.get_center().x, mid])
			waar(p.size.x <= b.size.x / float(s.vakken), "%s: kaartje %d past in zijn deel" % [wat, i])
			if i > 0:
				waar(s.prijs_rect(i - 1).end.x < p.position.x, "%s: kaartjes %d en %d raken elkaar niet" % [wat, i - 1, i])
		gelijk(s.vak_rect(s.vakken), Rect2(), "%s: geen plek na de laatste" % wat)
		gelijk(s.vak_rect(-1), Rect2(), "%s: geen plek -1" % wat)
		gelijk(s.prijs_rect(s.vakken), Rect2(), "%s: geen kaartje na het laatste" % wat)
		var voor := _voet(s, FotoScherm.VOOR_Y)
		var achter := _voet(s, FotoScherm.ACHTER_Y)
		match n:
			0:
				gelijk(s.vak_rect(0).size, s.vak_rect(1).size, "leeg: twee gelijke vraagtekenplekken")
				waar(absf(s.vak_rect(0).end.y - voor) < 0.5, "leeg: op de vloer")
			1:
				waar(absf(s.vak_rect(0).end.y - voor) < 1.0, "één: het dier staat vooraan")
				waar(absf(s.vak_rect(1).end.y - voor) < 0.5, "één: rechts nog een vraagteken")
			2:
				for i in 2:
					waar(absf(s.vak_rect(i).end.y - voor) < 1.0, "twee: %d vooraan" % i)
			3:
				waar(absf(s.vak_rect(1).end.y - achter) < 1.0, "drie: de middelste achter op de bank")
				waar(s.vak_rect(1).size.y < s.vak_rect(0).size.y * 0.9, "drie: achter is kleiner")
				waar(absf(s.vak_rect(0).end.y - voor) < 1.0 and absf(s.vak_rect(2).end.y - voor) < 1.0, "drie: de andere vooraan")
			4:
				for i in [1, 2]:
					waar(absf(s.vak_rect(i).end.y - achter) < 1.0, "vier: %d achter op de bank" % i)
				for i in [0, 3]:
					waar(absf(s.vak_rect(i).end.y - voor) < 1.0, "vier: %d vooraan" % i)
				waar(s.vak_rect(0).size.y < FotoScherm.maat_bij(BREED).y, "vier: past")
	# four make the camera step back: the same dog is smaller than with two
	s.dieren = ["d0", "d1"]
	var twee := s.vak_rect(0).size.y
	s.dieren = ["d0", "d1", "d2", "d3"]
	waar(s.vak_rect(0).size.y < twee * 0.95, "met vier zijn ze kleiner (%.1f < %.1f)" % [s.vak_rect(0).size.y, twee])
	_af()

## Every nose toward the middle of the cabin: right of it the plate is mirrored
## and looks left, left of it it looks right — standing, cheering and on the
## photo; the outermost two look at each other.  Walking in from the curtain
## they look right, into the booth; walking out they look left, at the curtain.
func test_kijkrichting() -> void:
	var s := _scherm(true)
	var midden := _midden(s)
	for n in range(1, 5):
		s.dieren = _ids(n)
		for i in n:
			var x := s.vak_rect(i).get_center().x
			gelijk(bool(s.stand_van(i)["links"]), x > midden + 0.5,
				"%d dieren: plek %d kijkt naar het midden (%.1f, midden %.1f)" % [n, i, x, midden])
		gelijk(s.stand_van(n), {}, "%d dieren: geen dier op plek %d" % [n, n])
		if n >= 2:
			waar(not bool(s.stand_van(0)["links"]) and bool(s.stand_van(n - 1)["links"]),
				"%d dieren: de buitenste twee kijken naar elkaar" % n)
	s.tel(1)
	for i in 4:
		gelijk(bool(s.stand_van(i)["links"]), s.vak_rect(i).get_center().x > midden + 0.5, "juichend: plek %d" % i)
	s.klik()
	for i in 4:
		gelijk(bool(s.stand_van(i)["links"]), s.vak_rect(i).get_center().x > midden + 0.5, "op de foto: plek %d" % i)
	# walking: in from the curtain looking right, out to the curtain looking left
	var t := _scherm(false)
	t.dieren = ["a", "b"]
	t.tik(STAP)
	for i in 2:
		waar(not bool(t.stand_van(i)["links"]), "binnenkomend: %d kijkt het hokje in" % i)
	_allen_binnen(t)
	t.vertrek()
	t.tik(STAP)
	for i in 2:
		waar(bool(t.stand_van(i)["links"]), "naar buiten: %d kijkt naar het gordijn" % i)
	_af()

## The back row is drawn first, so whoever stands in front stands before the
## ones on the bench: with three the middle one first, with four the middle
## two; then the front row, left to right (the newer one, further left, first).
func test_achterste_rij_eerst() -> void:
	var s := _scherm(true)
	var verwacht := {1: [0], 2: [0, 1], 3: [1, 0, 2], 4: [1, 2, 0, 3]}
	var achter_rij := {1: [], 2: [], 3: [1], 4: [1, 2]}
	for n in range(1, 5):
		s.dieren = _ids(n)
		var achter: Array = []
		for i in n:
			if bool(s.stand_van(i)["achter"]):
				achter.append(i)
				waar(s.vak_rect(i).end.y < _voet(s, FotoScherm.VOOR_Y) - 5.0, "%d dieren: %d staat echt achteraan" % [n, i])
		gelijk(achter, achter_rij[n], "%d dieren: wie achter op de bank staat" % n)
		var volgorde := s.teken_volgorde()
		gelijk(volgorde, verwacht[n], "%d dieren: de achterste rij eerst getekend" % n)
		gelijk(volgorde.slice(0, achter.size()), achter, "%d dieren: eerst de bank" % n)
	_af()

# ----------------------------------------------------------- walking in

## A guest steps out from behind the curtain: first wholly left of the
## picture, then on its way with a hop, then on its place — and only then is it
## `binnen`.
func test_binnenkomen() -> void:
	var s := _scherm(false)
	var b := s.beeld_rect()
	s.dieren = ["a"]
	gelijk(s.dieren, ["a"], "de lijst is er meteen")
	gelijk(s.binnen(), [], "maar binnen is nog niemand")
	var r0 := s.vak_rect(0)
	waar(r0.end.x <= b.position.x + 0.5, "eerst helemaal links van het beeld, achter het gordijn (%s)" % str(r0))
	var rust_y := _voet(s, FotoScherm.VOOR_Y)
	_tik(s, FotoScherm.KOM_S * 0.5)
	var r1 := s.vak_rect(0)
	waar(r1.position.x > r0.position.x + 20.0, "halverwege is het onderweg naar rechts (%s)" % str(r1))
	waar(r1.end.y < rust_y - 5.0, "met een sprongetje (%.1f boven de vloer)" % (rust_y - r1.end.y))
	gelijk(s.binnen(), [], "halverwege nog niet binnen")
	_tik(s, FotoScherm.KOM_S * 0.5 + 0.05)
	gelijk(s.binnen(), ["a"], "na KOM_S is het binnen")
	var r2 := s.vak_rect(0)
	waar(absf(r2.get_center().x - s.prijs_rect(0).get_center().x) < 1.0, "op zijn plek, boven zijn prijs")
	waar(absf(r2.end.y - rust_y) <= _adem(s), "op de vloer (%.2f)" % (r2.end.y - rust_y))
	# several at once: one after the other, the first chosen first
	var t := _scherm(false)
	t.dieren = ["a", "b", "c"]
	_tik(t, FotoScherm.KOM_S + 0.02)
	gelijk(t.binnen(), ["a"], "drie tegelijk: eerst a")
	_tik(t, FotoScherm.KOM_NA)
	gelijk(t.binnen(), ["a", "b"], "dan b")
	_tik(t, FotoScherm.KOM_NA)
	gelijk(t.binnen(), ["a", "b", "c"], "dan c: binnen == dieren")
	gelijk(t.binnen(), t.dieren, "iedereen staat stil")
	_af()

## One still waiting behind the curtain when a third is chosen walks in along
## the row of his NEW place — up on the bench — and never slants up to it
## from the floor of his old one.
func test_wachtende_loopt_over_zijn_nieuwe_rij() -> void:
	var s := _scherm(false)
	s.dieren = ["a", "b"]                 # b waits KOM_NA behind the curtain
	_tik(s, FotoScherm.KOM_NA * 0.3)
	s.dieren = ["a", "b", "c"]            # three: b's place is the middle one
	waar(bool(s.stand_van(1)["achter"]), "b's nieuwe plek is achter op de bank")
	var bank := _voet(s, FotoScherm.ACHTER_Y)
	var b := s.beeld_rect()
	var laagst := -INF
	var gezien := 0
	for _k in int((FotoScherm.KOM_NA + FotoScherm.KOM_S + 0.1) / STAP):
		s.tik(STAP)
		var r := s.vak_rect(1)
		if r.end.x > b.position.x + 0.5:
			gezien += 1
			laagst = maxf(laagst, r.end.y)
	waar(gezien > 3, "b komt in beeld (%d)" % gezien)
	waar(laagst <= bank + 0.5, "b loopt over de bank naar binnen, niet schuin van de vloer (%.1f, bank %.1f)" % [laagst, bank])
	_allen_binnen(s)
	gelijk(s.binnen(), ["a", "b", "c"], "en dan zijn ze alle drie binnen")
	waar(absf(s.vak_rect(1).end.y - bank) <= _adem(s), "b staat op de bank")
	_af()

## "Schuif op!": the newest takes the place nearest the curtain, the ones in
## already shuffle one place to the right; an id that leaves the list is gone
## at once, and the others close up without walking in again.
func test_schuif_op() -> void:
	var s := _scherm(false)
	s.dieren = ["a"]
	_allen_binnen(s)
	var a_eerst := s.vak_rect(0).get_center().x
	s.dieren = ["a", "b"]
	waar(absf(s.vak_rect(1).get_center().x - a_eerst) < 1.0, "a staat nog waar het stond (%.1f)" % s.vak_rect(1).get_center().x)
	waar(s.vak_rect(0).end.x <= s.beeld_rect().position.x + 0.5, "b staat nog achter het gordijn")
	gelijk(s.binnen(), ["a"], "a is binnen, b nog niet")
	_tik(s, FotoScherm.SCHUIF_S + 0.02)
	var a_nu := s.vak_rect(1).get_center().x
	waar(a_nu > a_eerst + 20.0, "a is een plek opgeschoven (%.1f -> %.1f)" % [a_eerst, a_nu])
	waar(absf(a_nu - s.prijs_rect(1).get_center().x) < 1.0, "a staat boven het rechter kaartje")
	_tik(s, FotoScherm.KOM_S)
	gelijk(s.binnen(), ["a", "b"], "b is binnen")
	waar(absf(s.vak_rect(0).get_center().x - s.prijs_rect(0).get_center().x) < 1.0, "b links, het dichtst bij het gordijn")
	s.dieren = ["a", "b", "c"]
	_allen_binnen(s)
	gelijk(s.binnen(), ["a", "b", "c"], "drie binnen")
	# b goes: gone at once, nobody walks in again, the other two close up
	s.dieren = ["a", "c"]
	gelijk(s.vakken, 2, "nog twee plekken")
	gelijk(s.binnen(), ["a", "c"], "a en c staan er nog, zonder opnieuw binnen te komen")
	_tik(s, FotoScherm.SCHUIF_S + 0.02)
	for i in 2:
		waar(absf(s.vak_rect(i).get_center().x - s.prijs_rect(i).get_center().x) < 1.0, "%d staat weer boven zijn kaartje" % i)
	# a list changed in place is caught up with
	s.dieren.append("d")
	gelijk(s.vakken, 3, "in de lijst geschreven: drie plekken")
	gelijk(s.binnen(), ["a", "c"], "d komt nog binnen")
	_allen_binnen(s)
	gelijk(s.binnen(), ["a", "c", "d"], "en is er dan")
	_af()

# ------------------------------------------------------------- waiting

## Standing still they breathe — up and down a little, never sideways, never
## through the floor — and every one at its own pace.
func test_wachten_ademt_binnen_de_perken() -> void:
	var s := _scherm(false)
	s.dieren = ["a", "b", "c"]
	_allen_binnen(s)
	var adem := _adem(s)
	var x0: Array = []
	var lo: Array = []
	var hi: Array = []
	for i in 3:
		x0.append(s.vak_rect(i).position.x)
		lo.append(INF)
		hi.append(-INF)
	for _k in 240:
		s.tik(STAP)
		for i in 3:
			var r := s.vak_rect(i)
			waar(absf(r.position.x - float(x0[i])) < 0.01, "plek %d schuift niet opzij" % i)
			lo[i] = minf(float(lo[i]), r.end.y)
			hi[i] = maxf(float(hi[i]), r.end.y)
	for i in 3:
		var rij_y := FotoScherm.ACHTER_Y if i == 1 else FotoScherm.VOOR_Y
		var voet := _voet(s, rij_y)
		waar(float(hi[i]) - float(lo[i]) > 1.0, "plek %d ademt (%.2f)" % [i, float(hi[i]) - float(lo[i])])
		waar(float(lo[i]) >= voet - adem and float(hi[i]) <= voet + adem,
			"plek %d blijft binnen ±%.2f (%.2f … %.2f om %.2f)" % [i, adem, float(lo[i]), float(hi[i]), voet])
	gelijk(s.binnen(), ["a", "b", "c"], "wachten verandert niets aan wie er is")
	_af()

## While they wait they blink and wag (the frames of the world's own guests),
## from a handful of plates that are baked once: turning the clock bakes
## nothing new.  At the "1" they cheer; on the photo they keep one smile.
func test_knipperen_kwispelen_en_weinig_platen() -> void:
	var s := _scherm(false)
	s.dieren = ["a", "b", "c", "d"]
	_allen_binnen(s)
	var gezien := {}
	var platen := {}
	var zonder: Array = []
	var draai := func(sec: float) -> void:
		for _k in int(sec / STAP):
			s.tik(STAP)
			for i in s.vakken:
				var st := s.stand_van(i)
				var pose := str(st["pose"])
				gezien[pose] = true
				if not bool(st["plaat"]):
					zonder.append(pose)
				platen["%d|%s" % [i, pose]] = true
	draai.call(13.0)
	for pose in ["rust", "knipper", "kwispelA", "kwispelB"]:
		waar(gezien.has(pose), "wachtend: %s (%s)" % [pose, str(gezien.keys())])
	var gebakken: int = Art.gebakken()
	draai.call(13.0)
	gelijk(Art.gebakken(), gebakken, "nog een rondje wachten bakt niets meer")
	s.tel(1)
	draai.call(1.0)
	waar(gezien.has("blijA") and gezien.has("blijB"), "bij 1 juichen ze (%s)" % str(gezien.keys()))
	s.klik()
	gezien.clear()
	draai.call(1.2)
	gelijk(gezien.keys(), ["blijA"], "op de foto één glimlach")
	waar(platen.size() <= 4 * 8, "hooguit acht platen per dier (%d)" % platen.size())
	gebakken = Art.gebakken()
	draai.call(3.0)
	gelijk(Art.gebakken(), gebakken, "de foto bakt niets meer")
	gelijk(zonder, [], "elke pose heeft een plaat")
	_af()

## The clock only asks for a redraw while something changes: an empty booth
## and a finished photo stand still; the animals in the live booth, a digit of
## the countdown, the flash, the developing and the walk out move.  Never in
## reduced motion.
func test_alleen_tekenen_als_er_iets_beweegt() -> void:
	var s := _scherm(false)
	waar(not s.beweegt(), "een leeg hokje staat stil")
	s.tel(3)
	waar(s.beweegt(), "een cijfer van het aftellen")
	s.tel(0)
	waar(not s.beweegt(), "zonder cijfer weer stil")
	s.dieren = ["a", "b"]
	waar(s.beweegt(), "ze lopen naar binnen")
	_allen_binnen(s)
	waar(s.beweegt(), "binnen ademen, knipperen en kwispelen ze")
	s.klik()
	waar(s.beweegt(), "de flits en het ontwikkelen")
	_tik(s, FotoScherm.ONTWIKKEL_S + 0.05)
	waar(not s.beweegt(), "een klare foto staat stil")
	s.vertrek()
	waar(s.beweegt(), "ze lopen naar buiten")
	_tik(s, FotoScherm.WEG_S + 0.05)
	waar(not s.beweegt(), "weer leeg: stil")
	var r := _scherm(true)
	r.dieren = ["a", "b"]
	r.tel(2)
	waar(not r.beweegt(), "rustig: niets beweegt")
	_af()

# ---------------------------------------------------------- the countdown

## 3, 2, 1: the digit; at 1 everybody cheers — hops up, never below the floor;
## 0 hides the digit and calls the cheering off.  In reduced motion they cheer
## standing still.
func test_aftellen_en_juichen() -> void:
	var s := _scherm(false)
	s.dieren = ["a", "b"]
	_allen_binnen(s)
	gelijk(s.tel_getal, 0, "eerst geen cijfer")
	var voet := _voet(s, FotoScherm.VOOR_Y)
	s.tel(3)
	gelijk(s.tel_getal, 3, "drie")
	_tik(s, 0.5)
	var hoogst := INF
	var laagst := -INF
	for _k in 30:
		s.tik(STAP)
		hoogst = minf(hoogst, s.vak_rect(0).end.y)
		laagst = maxf(laagst, s.vak_rect(0).end.y)
	waar(voet - hoogst < 2.5, "bij drie nog niet springen (%.2f)" % (voet - hoogst))
	s.tel(2)
	gelijk(s.tel_getal, 2, "twee")
	s.tel(1)
	gelijk(s.tel_getal, 1, "één")
	hoogst = INF
	laagst = -INF
	for _k in 30:
		s.tik(STAP)
		for i in 2:
			hoogst = minf(hoogst, s.vak_rect(i).end.y)
			laagst = maxf(laagst, s.vak_rect(i).end.y)
	waar(voet - hoogst > 4.0, "bij één springen ze (%.2f)" % (voet - hoogst))
	waar(laagst <= voet + 0.5, "nooit door de vloer (%.2f)" % (laagst - voet))
	# called off: the digit goes and so does the cheering
	s.tel(0)
	gelijk(s.tel_getal, 0, "nul: geen cijfer")
	hoogst = INF
	var juicht := false
	for _k in 30:
		s.tik(STAP)
		for i in 2:
			hoogst = minf(hoogst, s.vak_rect(i).end.y)
			juicht = juicht or str(s.stand_van(i)["pose"]).begins_with("blij")
	waar(not juicht, "afgeblazen: niemand juicht meer")
	waar(voet - hoogst < 2.5, "afgeblazen: geen sprongetjes meer (%.2f)" % (voet - hoogst))
	# reduced motion: the digit, no hop
	var r := _scherm(true)
	r.dieren = ["a", "b"]
	var stil := r.vak_rect(0)
	r.tel(1)
	gelijk(r.tel_getal, 1, "rustig: het cijfer staat er")
	_tik(r, 0.4)
	gelijk(r.vak_rect(0), stil, "rustig: geen sprongetje")
	_af()

# ------------------------------------------------------------- the click

## The digit's badge sits in the top-right quarter of the picture and hides
## no animal, for one to four of them, every kind on every place, on the
## smallest screen and on a phone on its side: at "3" and "2" not one opaque
## pixel of a plate is under it, nor a "?" place; at "1", as they jump for
## joy, no head (the half of the plate the nose points to).
func test_aftellen_in_de_hoek() -> void:
	var kinderen := ["boef", "muis", "wolkje", "gerrit"]   # hond, poes, konijn, gans
	var gasten_voor: Array = (State.s["gasten"] as Array).duplicate()
	for g in State.gasten_pool():
		if kinderen.has(str(g["id"])):
			(State.s["gasten"] as Array).append(g)
	for maat in [FotoScherm.maat_bij(180.0), Vector2(180.0, FotoScherm.maat_bij(180.0).y * 0.8)]:
		for n in range(1, 5):
			for draai in 4:
				for cijfer in [2, 1]:
					var s := _scherm(false)
					s.size = maat
					var ids: Array = []
					for k in n:
						ids.append(kinderen[(k + draai) % 4])
					s.dieren = ids
					_allen_binnen(s)
					s.tel(cijfer)
					var b := s.beeld_rect()
					var kw := Rect2(b.get_center().x, b.position.y, b.size.x * 0.5, b.size.y * 0.5)
					var r := s.badge_rect()
					waar(r.size.x > 0.0 and kw.encloses(r), "n=%d: in de hoek rechtsboven %s" % [n, r])
					var krap := INF
					for _k in 20:
						s.tik(STAP)
						for i in range(n, s.vakken):
							waar(not r.intersects(s.vak_rect(i)), "n=%d: het ?-vak %d vrij" % [n, i])
						for i in n:
							krap = minf(krap, _vrij_van(s, i, r, cijfer == 1))
					waar(krap > 0.0, "n=%d %s bij %d: geen dier achter het cijfer (%.2f px)" % [n, ids, cijfer, krap])
					_af()
	State.s["gasten"] = gasten_voor

## How far the opaque pixels of the animal on place `i` (only its head half:
## `kop`) stay out of the round badge in `r`; negative: that far under it.
func _vrij_van(s: FotoScherm, i: int, r: Rect2, kop: bool) -> float:
	var p = s._plaat(s._rij[s._rij.size() - 1 - i], "rust")
	var v := s.vak_rect(i)
	var img: Image = p.tex.get_image()
	var links := bool(s.stand_van(i)["links"])
	var c := r.get_center()
	var uit := INF
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a < 0.5:
				continue
			var u := (float(x) + 0.5) / float(img.get_width())
			if links:
				u = 1.0 - u
			if kop and (u > 0.5 if links else u < 0.5):
				continue
			var q := v.position + Vector2(u * v.size.x, (float(y) + 0.5) / float(img.get_height()) * v.size.y)
			uit = minf(uit, q.distance_to(c) - r.size.x * 0.5)
	return uit

## The click: `foto` at once, the countdown gone, the flash 1 → 0 and the
## polaroid 0 → 1 on the clock; everybody frozen on its place, happy — the
## photo does not breathe.
func test_klik_flits_en_ontwikkelen() -> void:
	var s := _scherm(false)
	s.dieren = ["a", "b", "c"]
	_tik(s, 0.3)          # the last one is still on its way in
	var plek_x: Array = []
	for i in 3:
		plek_x.append(s.prijs_rect(i).get_center().x)
	s.tel(1)
	s.klik()
	waar(s.foto, "foto meteen")
	gelijk(s.tel_getal, 0, "het cijfer is weg")
	gelijk(s.flits, 1.0, "de flits")
	gelijk(s.ontwikkel, 0.0, "de polaroid is nog wit")
	gelijk(s.binnen(), ["a", "b", "c"], "wie er nog aan kwam, staat er op de foto")
	var vast: Array = []
	for i in 3:
		vast.append(s.vak_rect(i))
		waar(absf(s.vak_rect(i).get_center().x - float(plek_x[i])) < 1.0, "%d staat op zijn plek" % i)
	_tik(s, 0.3)
	waar(s.flits > 0.0 and s.flits < 1.0, "de flits dooft (%.2f)" % s.flits)
	waar(s.ontwikkel > 0.0 and s.ontwikkel < 1.0, "de foto komt op (%.2f)" % s.ontwikkel)
	var eerder := s.ontwikkel
	_tik(s, 0.2)
	waar(s.ontwikkel > eerder, "steeds meer kleur")
	_tik(s, FotoScherm.ONTWIKKEL_S)
	gelijk(s.ontwikkel, 1.0, "ontwikkeld")
	gelijk(s.flits, 0.0, "de flits is uit")
	waar(s.foto, "het blijft een foto")
	_tik(s, 3.0)
	for i in 3:
		gelijk(s.vak_rect(i), vast[i], "op de foto staat %d stil" % i)
	_af()

## The price tags belong to the booth, not to the photo: one under every place
## while the camera is live, none on the polaroid and none while everybody
## walks out — back once the booth is empty and live again.
func test_geen_prijskaartjes_op_de_foto() -> void:
	var s := _scherm(true)
	s.zet(3)
	s.dieren = ["a", "b", "c"]
	for i in s.vakken:
		waar(s.prijs_rect(i).size.x > 4.0, "live: kaartje %d" % i)
	s.klik()
	for i in s.vakken:
		gelijk(s.prijs_rect(i), Rect2(), "op de foto geen kaartje %d" % i)
	var t := _scherm(false)
	t.zet(3)
	t.dieren = ["a", "b"]
	_allen_binnen(t)
	t.vertrek()
	for i in t.vakken:
		gelijk(t.prijs_rect(i), Rect2(), "naar buiten: geen kaartje %d" % i)
	_tik(t, FotoScherm.WEG_S + 0.05)
	for i in t.vakken:
		waar(t.prijs_rect(i).size.x > 4.0, "weer leeg en live: kaartje %d terug" % i)
	_af()

# ----------------------------------------------------------- walking out

## Everybody out through the curtain, to the left; while they go nobody is
## `binnen`; after WEG_S the booth is empty and live again — also after a
## photo (they slide out of it), also with a countdown on screen.  The
## shutter while they walk out ends the walk out: the photo keeps them all.
func test_vertrek() -> void:
	var s := _scherm(false)
	s.dieren = ["a", "b"]
	_allen_binnen(s)
	s.tel(2)
	var voor: Array = [s.vak_rect(0).position.x, s.vak_rect(1).position.x]
	s.vertrek()
	gelijk(s.tel_getal, 0, "het aftellen stopt")
	gelijk(s.dieren.size(), 2, "onderweg staan ze nog op de lijst")
	gelijk(s.binnen(), [], "maar binnen is niemand meer")
	_tik(s, FotoScherm.WEG_S * 0.5)
	for i in 2:
		waar(s.vak_rect(i).position.x < float(voor[i]) - 5.0, "%d loopt naar links, naar het gordijn" % i)
	_tik(s, FotoScherm.WEG_S * 0.5 + 0.05)
	gelijk(s.dieren, [], "eruit: de lijst is leeg")
	gelijk(s.vakken, 2, "weer twee lege plekken")
	waar(not s.foto, "geen foto")
	gelijk(s.binnen(), [], "niemand binnen")
	# after a photo: they slide out of it, then it is live and empty again
	s.dieren = ["a", "b"]
	_allen_binnen(s)
	s.klik()
	_tik(s, FotoScherm.ONTWIKKEL_S + 0.05)
	var op_foto: Array = [s.vak_rect(0).position.x, s.vak_rect(1).position.x]
	s.vertrek()
	_tik(s, FotoScherm.WEG_S * 0.5)
	for i in 2:
		waar(s.vak_rect(i).position.x < float(op_foto[i]) - 5.0,
			"na de foto: %d schuift naar het gordijn (%.1f -> %.1f)" % [i, float(op_foto[i]), s.vak_rect(i).position.x])
	_tik(s, FotoScherm.WEG_S * 0.5 + 0.05)
	gelijk(s.dieren, [], "na de foto: leeg")
	waar(not s.foto, "na de foto: weer live")
	# the shutter while they walk out: the walk out is over, the photo keeps them
	s.dieren = ["a", "b"]
	_allen_binnen(s)
	var plek: Array = [s.vak_rect(0).get_center().x, s.vak_rect(1).get_center().x]
	s.vertrek()
	_tik(s, FotoScherm.WEG_S * 0.3)
	s.klik()
	_tik(s, FotoScherm.WEG_S + FotoScherm.ONTWIKKEL_S)
	gelijk(s.dieren, ["a", "b"], "geklikt onderweg: de foto wordt niet gewist")
	waar(s.foto, "en blijft een foto")
	gelijk(s.binnen(), ["a", "b"], "met iedereen erop")
	for i in 2:
		waar(absf(s.vak_rect(i).get_center().x - float(plek[i])) < 1.0, "geklikt onderweg: %d op zijn plek" % i)
	# a new list on the way out ends the walk out
	s.vertrek()
	_tik(s, FotoScherm.WEG_S + 0.05)
	s.dieren = ["a", "b"]
	_allen_binnen(s)
	s.vertrek()
	_tik(s, FotoScherm.WEG_S * 0.3)
	s.dieren = ["a", "b"]
	_tik(s, FotoScherm.WEG_S)
	gelijk(s.dieren, ["a", "b"], "teruggeroepen: ze blijven")
	_tik(s, FotoScherm.SCHUIF_S)
	gelijk(s.binnen(), ["a", "b"], "en staan weer op hun plek")
	_af()

# ------------------------------------------------------- reduced motion

## Reduced motion, and headless in the tree (the suite): every change is final
## the moment it is made — in, the click, out — and nothing moves on the clock.
func test_rust_modus_en_headless() -> void:
	var s := _scherm(true)
	s.dieren = ["a", "b", "c"]
	gelijk(s.binnen(), ["a", "b", "c"], "meteen binnen")
	var r: Array = []
	for i in 3:
		r.append(s.vak_rect(i))
	_tik(s, 2.7)
	for i in 3:
		gelijk(s.vak_rect(i), r[i], "%d ademt niet" % i)
	s.klik()
	waar(s.foto, "foto")
	gelijk(s.ontwikkel, 1.0, "meteen ontwikkeld")
	gelijk(s.flits, 0.0, "geen flits")
	s.vertrek()
	gelijk(s.dieren, [], "meteen weg")
	waar(not s.foto, "weer live")
	gelijk(s.vakken, 2, "twee lege plekken")
	# headless in the tree: the same, also with reduced motion off
	Ui.zet_rust_modus(false)
	var h := _scherm(false)
	h.dieren = ["a"]                     # before it is in the tree: on its way ...
	gelijk(h.binnen(), [], "buiten de boom loopt het nog")
	(Engine.get_main_loop() as SceneTree).root.add_child(h)
	gelijk(h.binnen(), ["a"], "... in de boom staat het er meteen")
	h.dieren = ["a", "b"]
	gelijk(h.binnen(), ["a", "b"], "headless in de boom: meteen binnen")
	waar(not h.beweegt(), "headless in de boom: niets om opnieuw te tekenen")
	h.klik()
	gelijk(h.ontwikkel, 1.0, "headless: meteen ontwikkeld")
	gelijk(h.flits, 0.0, "headless: geen flits")
	h.vertrek()
	gelijk(h.dieren, [], "headless: meteen weg")
	_af()
