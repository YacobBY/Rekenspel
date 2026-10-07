extends RefCounted
## Sterren tellen — de getallen en de zinnen van één beurt (U3, dakterras).
## Puur en statisch: geen wereld, geen ctx, zodat de tests elke groep, elk
## aantal gasten en elke beurt kunnen aflopen zonder dat er een beurt loopt.
##
## HET REKENEN IS VAN HET SPEL ZELF; `core/sommen.gd` blijft bevroren.  De
## sterren hangen in PATRONEN (dobbelsteenogen, tienvelden, rijen, blokken van
## tien en honderd) zodat een kind ze in één oogopslag ziet in plaats van één
## voor één te tellen.  N = het aantal gasten schaalt het patroon (één
## sterrenbeeld per gast, meer rijen met meer gasten).
##
##   groep 3  `patroon`  één patroon 1..10 → hoeveel?
##            `samen`    twee sterrenbeelden (a, b ≤ 10, a+b ≤ 20) → samen?
##            `tot_tien` een tienveld met k → hoeveel erbij tot 10?
##   groep 4  `rijen`    r rijen van 2, 5 of 10 → r·s (de tafels van 2, 5, 10)
##            `dubbel`   een patroon k twee keer, gespiegeld → 2k
##   groep 5  `tientallen`  t blokken van 10 + e losse → 10t + e
##            `honderden`   h blokken van 100 + t van 10 → 100h + 10t
##            `rijen_van`   r rijen van s (2..9) → r·s
## Een fout antwoord: geen hulp, dezelfde vraag blijft (`Ui.misser`).

const ZAAD := 90317

## A pattern of `k` dots, as cells {x, y} in a small grid.  `breed` is the grid
## width the viewer lays it out in.
static func patroon(vorm: String, k: int, s := 5) -> Dictionary:
	var cellen: Array = []
	var breed := 3
	match vorm:
		"dobbel":
			breed = 3
			var ogen := {
				1: [[1, 1]],
				2: [[0, 0], [2, 2]],
				3: [[0, 0], [1, 1], [2, 2]],
				4: [[0, 0], [2, 0], [0, 2], [2, 2]],
				5: [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2]],
				6: [[0, 0], [2, 0], [0, 1], [2, 1], [0, 2], [2, 2]],
			}
			for c in ogen.get(clampi(k, 1, 6), []):
				cellen.append(Vector2i(c[0], c[1]))
		"tien":
			breed = 5
			for i in clampi(k, 0, 10):
				cellen.append(Vector2i(i % 5, i / 5))
		"rij":
			breed = maxi(1, s)
			for i in maxi(0, k):
				cellen.append(Vector2i(i % breed, i / breed))
		"honderd":
			breed = 10
			for i in 100:
				cellen.append(Vector2i(i % 10, i / 10))
		_:
			breed = 5
			for i in maxi(0, k):
				cellen.append(Vector2i(i % 5, i / 5))
	return {"vorm": vorm, "k": cellen.size(), "cellen": cellen, "breed": breed,
		"waarde": 100 if vorm == "honderd" else cellen.size()}

## The natural pattern for a count up to 10: dice to six, a ten-frame beyond.
static func vorm_voor(k: int) -> String:
	return "dobbel" if k <= 6 else "tien"

## How many stars the patterns hold together (a `honderd` block counts 100).
static func aantal(patronen: Array) -> int:
	var n := 0
	for p in patronen:
		n += int((p as Dictionary)["waarde"])
	return n

static func _rng(band: int, n: int, beurt_nr: int, zaad: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(zaad) * 1000003 + beurt_nr * 7919 + n * 131 + band
	return r

## Which kind of question this turn asks: a round robin per band, so a child
## meets every kind; with one guest groep 3 has no second constellation.
static func soort(band: int, n: int, beurt_nr: int) -> String:
	if band <= 3:
		var s: String = ["patroon", "samen", "tot_tien"][posmod(beurt_nr, 3)]
		return "patroon" if s == "samen" and n < 2 else s
	if band == 4:
		return ["rijen", "dubbel"][posmod(beurt_nr, 2)]
	return ["tientallen", "honderden", "rijen_van"][posmod(beurt_nr, 3)]

## One turn: `{band, soort, patronen, goed, regel, liever, tekst}`.  The same
## arguments give the same turn (a reload asks the same question).
static func maak(band: int, n: int, beurt_nr: int, zaad := ZAAD) -> Dictionary:
	var rng := _rng(band, n, beurt_nr, zaad)
	var s := soort(band, n, beurt_nr)
	var patronen: Array = []
	var goed := 0
	var regel := ""
	var liever: Array = []
	match s:
		"patroon":
			var k := rng.randi_range(1, 10)
			patronen.append(patroon(vorm_voor(k), k))
			goed = k
			regel = "⭐ Hoeveel sterren zie je?"
			liever = [k - 1, k + 1]
		"samen":
			var a := rng.randi_range(1, 10)
			var b := rng.randi_range(1, mini(10, 20 - a))
			patronen.append(patroon(vorm_voor(a), a))
			patronen.append(patroon(vorm_voor(b), b))
			goed = a + b
			regel = "⭐ Hoeveel sterren samen?"
			liever = [goed - 1, goed + 1]
		"tot_tien":
			var k := rng.randi_range(1, 9)
			patronen.append(patroon("tien", k))
			goed = 10 - k
			regel = "⭐ Hoeveel erbij tot 10?"
			liever = [goed - 1, goed + 1, k]
		"rijen":
			var per: int = [2, 5, 10][rng.randi_range(0, 2)]
			var r := rng.randi_range(1, mini(10, n + 2))
			patronen.append(patroon("rij", r * per, per))
			goed = r * per
			regel = "⭐ Hoeveel sterren in de rijen?"
			liever = [goed - per, goed + per]
		"dubbel":
			var k := rng.randi_range(2, 10)
			patronen.append(patroon(vorm_voor(k), k))
			patronen.append(patroon(vorm_voor(k), k))
			goed = 2 * k
			regel = "⭐ Dubbel zoveel: hoeveel sterren?"
			liever = [goed - 1, goed + 1, k]
		"tientallen":
			var t := rng.randi_range(1, mini(9, n + 2))
			var e := rng.randi_range(0, 9)
			for _i in t:
				patronen.append(patroon("tien", 10))
			if e > 0:
				patronen.append(patroon(vorm_voor(e), e))
			goed = 10 * t + e
			regel = "⭐ Hoeveel sterren bij elkaar?"
			liever = [goed - 10, goed + 10, goed - 1]
		"honderden":
			var h := rng.randi_range(1, mini(3, maxi(1, n)))
			var t := rng.randi_range(0, 9)
			for _i in h:
				patronen.append(patroon("honderd", 100))
			for _i in t:
				patronen.append(patroon("tien", 10))
			goed = 100 * h + 10 * t
			regel = "⭐ Hoeveel sterren bij elkaar?"
			liever = [goed - 100, goed + 100, goed - 10]
		"rijen_van":
			var r := rng.randi_range(2, mini(9, n + 3))
			var per := rng.randi_range(2, 9)
			patronen.append(patroon("rij", r * per, per))
			goed = r * per
			regel = "⭐ Hoeveel in %d rijen van %d?" % [r, per]
			liever = [goed - per, goed + per, goed - r]
	var schoon: Array = []
	for l in liever:
		if int(l) > 0 and int(l) != goed and not schoon.has(int(l)):
			schoon.append(int(l))
	return {"band": band, "soort": s, "patronen": patronen, "goed": goed,
		"regel": regel, "liever": schoon, "n": n, "beurt_nr": beurt_nr}

## True when `antwoord` is the answer of `beurt`.
static func keur(beurt: Dictionary, antwoord: int) -> bool:
	return int(beurt.get("goed", -1)) == antwoord
