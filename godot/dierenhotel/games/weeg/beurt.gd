extends RefCounted
## weeg — the numbers and the sentences of one turn (games-c.md §3.3, §3.9).
## Pure and static: no world, no ctx, so the tests can walk every band and
## every day without a turn running.
##
## THE MATHS IS THE GAME'S OWN.  `core/sommen.gd` is frozen (PLAN.md R8); this
## file only READS `Sommen.Prng`, the seeded mulberry32 every game shares.
##
## A turn is measuring with a balance (meten, kg — groep 4 in the curriculum
## table of IDEAS.md, natural units and comparing in groep 3), in two steps:
##   1. read a balanced scale: the thing weighs what the weights weigh together;
##   2. weigh a second thing yourself: its weight is on the card, the child
##      makes that number with the weights (splitsen) and the beam is level.
## (Until wave 2 the second thing was balanced by trying — "nog te licht",
## "te zwaar", "eraf" — and then read; those taps carried no number.)
## Weights per band: 1, 2, 5 kg (tot 10) · 2, 5, 10, 20 kg (tot 50, eind
## groep 4, owner 2026-11-15) · 1, 5, 10, 20 kg (tot 60, the giant pumpkin of
## groep 5).  The second weight grows with the hotel.
## From band 4 on the balanced scale is read across the ten: its small weights
## together weigh more than ten kilo (`20 + 5 + 5 + 2 =` → 32, not 22), and
## without a 1 kg weight an odd weight has to be built with the 5.

const ZAAD := 51329

## The weights each band has, in the stock on the floor and on the answer strip
## (at most four buttons on a strip, HOTEL.md §9), lightest first.  Groep 5
## weighs with 1, 5, 10 and 20 kg — the steps of the euro notes it knows.
const REK := {3: [1, 2, 5], 4: [2, 5, 10, 20], 5: [1, 5, 10, 20]}
## What is weighed, per band: the first thing lies balanced at the start, the
## other one is weighed by the child (they alternate by day).
const DINGEN := {3: ["pompoen", "meloen"], 4: ["pompoen", "zak"], 5: ["pompoen", "zak"]}
## [pictogram, "de …" in a sentence, "De …" at the start of one]
const NAAM := {"pompoen": ["🎃", "de pompoen", "De pompoen"],
	"meloen": ["🍉", "de meloen", "De meloen"],
	"zak": ["🥔", "de zak", "De zak"]}
## At most this many weights stacked on the right pan.  The weight to find
## always takes at most PAN_MAX − 1 of them (`_tweede`), so one wrong weight on
## the pan never blocks the way to level.  The scale at the start holds up to
## PAN_MAX weights (band 4 and 5: the ones that cross the ten).
const PAN_MAX := 5

## Child text, verbatim (games-c.md §3.9).
const ICOON := "⚖️"
## "is", not "weegt": "🎃 Hoeveel kilo weegt de pompoen?" is one line too wide
## for the maths bar of a 360-wide phone, and the first card of the turn would
## float over the room while every other card of the turn docks.
const T_HOEVEEL := "Hoeveel kilo is %s?"                ## 5 woorden, ≤ 27 tekens
## The second step (wave 2): the thing's weight is the question, the weights
## the child lays are the answer.  The pictogram of the thing goes first.
const T_MAAK := "Leg %d kilo op de weegschaal"           ## 6 woorden, ≤ 28 tekens
const T_AF := "%s weegt %d kilo!"                        ## 5 woorden, ≤ 25 tekens
const T_KG := "%d kg"
const T_KG_TITEL := "leg een gewicht op de weegschaal"
const ICOON_LEG := "⬇"
const T_LEEG := "nog geen gasten"
const ICOON_AF := "✅"

## The turn of today.
static func opzet(n: int, band: int, dag: int) -> Dictionary:
	var b := clampi(band, 3, 5)
	var gasten := maxi(1, n)
	var rnd := Sommen.Prng.new(ZAAD + dag * 7919 + gasten * 131 + b * 17)
	var rek: Array = REK[b]
	var set1: Array = []
	var g1 := 0
	if b >= 4:
		set1 = _kruisend(rnd, [3, 21, 21][b - 3], [10, 49, 60][b - 3], rek)
		g1 = som(set1)
	else:
		g1 = _eerste(rnd, b, rek)
		set1 = splits(g1, rek)
	var g2 := _tweede(rnd, b, gasten, g1)
	var dingen: Array = DINGEN[b]
	var eerste: String = dingen[(dag + gasten) % 2]
	var tweede: String = dingen[(dag + gasten + 1) % 2]
	return {"band": b, "rek": rek.duplicate(), "set1": set1, "gewicht1": g1,
		"ding1": eerste, "maat1": _maat(eerste, b), "gewicht2": g2, "ding2": tweede,
		"maat2": _maat(tweede, b)}

## The weight on the scale at the start: one that takes two to four weights.
## (Band 4 and 5 lay a crossing set instead, `_kruisend`.)
static func _eerste(rnd: Sommen.Prng, b: int, rek: Array) -> int:
	var lo: int = [3, 11, 21][b - 3]
	var hi: int = [10, 20, 60][b - 3]
	var start := lo + int(rnd.volgende() * float(hi - lo + 1))
	for i in hi - lo + 1:
		var g := lo + (start - lo + i) % (hi - lo + 1)
		var n := splits(g, rek).size()
		if n >= 2 and n <= 4:
			return g
	return lo

## A set of three to five weights from `rek` that weighs lo … hi, with at
## least one weight of ten or more and small weights (under ten) that together
## weigh 11 … 19 kilo, not a whole ten: the sum line crosses the ten
## (`20 + 5 + 5 + 2 =` is 32).  Heaviest first; one of all such sets, drawn.
static func _kruisend(rnd: Sommen.Prng, lo: int, hi: int, rek: Array) -> Array:
	var soorten: Array = rek.duplicate()
	soorten.sort()
	soorten.reverse()
	var sets: Array = []
	var stel := func(zelf: Callable, i: int, nu: Array) -> void:
		if i == soorten.size():
			if nu.size() < 3 or nu.size() > PAN_MAX:
				return
			var t := som(nu)
			var klein := 0
			var groot := 0
			for v in nu:
				if int(v) < 10:
					klein += int(v)
				else:
					groot += 1
			if t >= lo and t <= hi and groot >= 1 and klein > 10 and klein % 10 != 0:
				sets.append(nu.duplicate())
			return
		var kg := int(soorten[i])
		var neem: Array = nu.duplicate()
		while neem.size() <= PAN_MAX:
			zelf.call(zelf, i + 1, neem)
			neem.append(kg)
	stel.call(stel, 0, [])
	if sets.is_empty():
		return splits(lo, rek)
	return sets[mini(sets.size() - 1, int(rnd.volgende() * float(sets.size())))]

## The weight the child finds herself: it grows with the hotel, never the same
## as the first one, and always reachable within PAN_MAX − 1 weights.  Band 5
## is never lighter than band 4 for the same hotel.
static func _tweede(rnd: Sommen.Prng, b: int, n: int, g1: int) -> int:
	var lo: int = [3, 21, 21][b - 3]
	var hi: int = [9, 49, 59][b - 3]
	var g := 0
	match b:
		3:
			g = 3 + n + int(rnd.volgende() * 4.0)
		4:
			g = 20 + n * 3 + int(rnd.volgende() * 8.0)
		_:
			g = 24 + n * 4 + int(rnd.volgende() * 8.0)
	g = clampi(g, lo, hi)
	var rek: Array = REK[b]
	# the nearest weight upwards (then downwards) that is not the first one and
	# takes at most PAN_MAX − 1 weights
	for stap in hi - lo + 1:
		for kandidaat in [g + stap, g - stap]:
			if kandidaat >= lo and kandidaat <= hi and kandidaat != g1 \
					and som(splits(kandidaat, rek)) == kandidaat \
					and splits(kandidaat, rek).size() <= PAN_MAX - 1:
				return kandidaat
	return g

static func _maat(ding: String, b: int) -> int:
	if ding == "pompoen":
		return b - 3
	return 1

## The fewest weights that make `g`, heaviest first (the stall's change rule).
## Greedy; when that leaves a rest (band 4 has no 1 kg: 33 is 20 + 5 + 2 + 2 + 2
## + 2, not 20 + 10 + 2 + ?), the fewest weights by counting up.  Empty when `g`
## cannot be made at all.
static func splits(g: int, rek: Array) -> Array:
	var uit: Array = []
	var rest := g
	var soorten: Array = rek.duplicate()
	soorten.sort()
	soorten.reverse()
	for kg in soorten:
		while rest >= int(kg):
			uit.append(int(kg))
			rest -= int(kg)
	if rest == 0:
		return uit
	# fewest weights for every total 0 … g, heavier kinds tried first
	var beste: Array = [[]]
	for t in range(1, g + 1):
		var keus: Variant = null
		for kg in soorten:
			var k := int(kg)
			if k <= t and beste[t - k] != null:
				var kan: Array = (beste[t - k] as Array) + [k]
				if keus == null or kan.size() < (keus as Array).size():
					keus = kan
		beste.append(keus)
	if beste[g] == null:
		return []
	var los: Array = (beste[g] as Array).duplicate()
	los.sort()
	los.reverse()
	return los

static func som(lijst: Array) -> int:
	var t := 0
	for v in lijst:
		t += int(v)
	return t

## Which way the beam leans: < 0 the thing (left) is down, > 0 the weights
## (right) are down, 0 level.  Two steps each way: far off, or nearly there.
static func kant(ding: int, gewichten: int) -> int:
	var verschil := ding - gewichten
	if verschil == 0:
		return 0
	var ver := absi(verschil) > maxi(2, int(ding / 4.0))
	if verschil > 0:
		return -2 if ver else -1
	return 2 if ver else 1

## The sum line of a pan: `10 + 5 + 2 =`, heaviest first as they lie.
static func som_regel(lijst: Array) -> String:
	var l := PackedStringArray()
	for v in lijst:
		l.append(str(int(v)))
	return " + ".join(l) + " ="

## The four answers: the right one, one weight forgotten, the number of weights
## (counting the weights instead of adding them), and one weight too many.
## Across the ten (band 4 and 5) the first slip is the forgotten carry:
## `20 + 5 + 5 + 2` is not 22.
static func liever(lijst: Array) -> Array:
	var t := som(lijst)
	var kleinste := 99
	var klein := 0
	var groot := false
	for v in lijst:
		kleinste = mini(kleinste, int(v))
		if int(v) < 10:
			klein += int(v)
		else:
			groot = true
	if groot and klein > 10:
		return [t - 10, t - kleinste, t + kleinste]
	return [t - kleinste, lijst.size(), t + kleinste]

## A sentence with the thing in it.
static func vraag(ding: String) -> String:
	return T_HOEVEEL % str(NAAM.get(ding, ["", "het", "Het"])[1])

## The building question: "Leg 13 kilo op de weegschaal".
static func maak(kilo: int) -> String:
	return T_MAAK % kilo

static func af(ding: String, kilo: int) -> String:
	return T_AF % [str(NAAM.get(ding, ["", "het", "Het"])[2]), kilo]

static func icoon(ding: String) -> String:
	return str(NAAM.get(ding, [ICOON])[0])
