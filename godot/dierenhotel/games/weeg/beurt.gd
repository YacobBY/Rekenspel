extends RefCounted
## weeg — the numbers and the sentences of one turn (games-c.md §3.3, §3.9).
## Pure and static: no world, no ctx, so the tests can walk every band and
## every day without a turn running.
##
## THE MATHS IS THE GAME'S OWN.  `core/sommen.gd` is frozen (PLAN.md R8); this
## file only READS `Sommen.Prng`, the seeded mulberry32 every game shares.
##
## A turn is measuring with a balance (meten, kg — groep 4 in the curriculum
## table of IDEAS.md, natural units and comparing in groep 3), in three steps:
##   1. read a balanced scale: the thing weighs what the weights weigh together;
##   2. weigh a second thing yourself: put weights on until the beam is level —
##      the balance tilts towards the heavier side, so the child compares
##      before she adds;
##   3. read your own measurement: add up the weights you put on.
## Weights per band: 1, 2, 5 kg (tot 10) · + 10 kg (tot 20) · 1, 5, 10, 20 kg
## (tot 60, the giant pumpkin of groep 5).  The second weight grows with the
## hotel.

const ZAAD := 51329

## The weights each band has, in the stock on the floor and on the answer strip
## (at most four buttons on a strip, HOTEL.md §9), lightest first.  Groep 5
## weighs with 1, 5, 10 and 20 kg — the steps of the euro notes it knows.
const REK := {3: [1, 2, 5], 4: [1, 2, 5, 10], 5: [1, 5, 10, 20]}
## What is weighed, per band: the first thing lies balanced at the start, the
## other one is weighed by the child (they alternate by day).
const DINGEN := {3: ["pompoen", "meloen"], 4: ["pompoen", "zak"], 5: ["pompoen", "zak"]}
## [pictogram, "de …" in a sentence, "De …" at the start of one]
const NAAM := {"pompoen": ["🎃", "de pompoen", "De pompoen"],
	"meloen": ["🍉", "de meloen", "De meloen"],
	"zak": ["🥔", "de zak", "De zak"]}
## At most this many weights stacked on the right pan.  The weight to find
## always takes at most PAN_MAX − 1 of them (`_tweede`), so one wrong weight on
## the pan never blocks the way to level.
const PAN_MAX := 5

## Child text, verbatim (games-c.md §3.9).
const ICOON := "⚖️"
## "is", not "weegt": "🎃 Hoeveel kilo weegt de pompoen?" is one line too wide
## for the maths bar of a 360-wide phone, and the first card of the turn would
## float over the room while every other card of the turn docks.
const T_HOEVEEL := "Hoeveel kilo is %s?"                ## 5 woorden, ≤ 27 tekens
const T_RECHT := "Maak de weegschaal weer recht"         ## 5 woorden, 29 tekens
const T_AF := "%s weegt %d kilo!"                        ## 5 woorden, ≤ 25 tekens
const T_LICHT := "nog te licht"
const T_ZWAAR := "te zwaar"
const T_PRECIES := "precies!"
const T_VOL := "Neem een zwaarder gewicht"
const T_ERAF := "eraf"
const T_ERAF_TITEL := "haal het laatste gewicht eraf"
const T_KG := "%d kg"
const T_KG_TITEL := "leg een gewicht op de weegschaal"
const ICOON_LEG := "⬇"
const T_LEEG := "nog geen gasten"
const T_SPOOK := "zoveel is het"
const ICOON_LICHT := "⬆"
const ICOON_ZWAAR := "⬇"
const ICOON_ERAF := "⬆"
const ICOON_HULP := "💛"
const ICOON_AF := "✅"

## The turn of today.
static func opzet(n: int, band: int, dag: int) -> Dictionary:
	var b := clampi(band, 3, 5)
	var gasten := maxi(1, n)
	var rnd := Sommen.Prng.new(ZAAD + dag * 7919 + gasten * 131 + b * 17)
	var rek: Array = REK[b]
	var g1 := _eerste(rnd, b, rek)
	var g2 := _tweede(rnd, b, gasten, g1)
	var dingen: Array = DINGEN[b]
	var eerste: String = dingen[(dag + gasten) % 2]
	var tweede: String = dingen[(dag + gasten + 1) % 2]
	return {"band": b, "rek": rek.duplicate(), "set1": splits(g1, rek), "gewicht1": g1,
		"ding1": eerste, "maat1": _maat(eerste, b), "gewicht2": g2, "ding2": tweede,
		"maat2": _maat(tweede, b)}

## The weight on the scale at the start: one that takes two to four weights.
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

## The weight the child finds herself: it grows with the hotel, never the same
## as the first one, and always reachable within PAN_MAX weights.
static func _tweede(rnd: Sommen.Prng, b: int, n: int, g1: int) -> int:
	var lo: int = [3, 8, 21][b - 3]
	var hi: int = [9, 19, 59][b - 3]
	var g := 0
	match b:
		3:
			g = 3 + n + int(rnd.volgende() * 4.0)
		4:
			g = 8 + (n - 4) * 3 + int(rnd.volgende() * 6.0)
		_:
			g = 21 + (n - 7) * 8 + int(rnd.volgende() * 16.0)
	g = clampi(g, lo, hi)
	var rek: Array = REK[b]
	# the nearest weight upwards (then downwards) that is not the first one and
	# takes at most PAN_MAX − 1 weights
	for stap in hi - lo + 1:
		for kandidaat in [g + stap, g - stap]:
			if kandidaat >= lo and kandidaat <= hi and kandidaat != g1 \
					and splits(kandidaat, rek).size() <= PAN_MAX - 1:
				return kandidaat
	return g

static func _maat(ding: String, b: int) -> int:
	if ding == "pompoen":
		return b - 3
	return 1

## The fewest weights that make `g`, heaviest first (the stall's change rule).
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
	return uit

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
static func liever(lijst: Array) -> Array:
	var t := som(lijst)
	var kleinste := 99
	for v in lijst:
		kleinste = mini(kleinste, int(v))
	return [t - kleinste, lijst.size(), t + kleinste]

## Counting on together (the help ladder, step 1 and 2): `10 ▸ 15 ▸ 17`.
static func hulp(lijst: Array) -> String:
	var l := PackedStringArray()
	var t := 0
	for v in lijst:
		t += int(v)
		l.append(str(t))
	return " ▸ ".join(l)

## A sentence with the thing in it.
static func vraag(ding: String) -> String:
	return T_HOEVEEL % str(NAAM.get(ding, ["", "het", "Het"])[1])

static func af(ding: String, kilo: int) -> String:
	return T_AF % [str(NAAM.get(ding, ["", "het", "Het"])[2]), kilo]

static func icoon(ding: String) -> String:
	return str(NAAM.get(ding, [ICOON])[0])
