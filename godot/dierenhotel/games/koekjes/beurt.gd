extends RefCounted
class_name KoekjesBeurt
## Koekjes bakken — de getallen en de zinnen van één beurt (de bakkerij,
## 2026-10-07; ontwerp: .fanout/scratch/uitbreiding/U1-bakkerij.md).
## Puur en statisch: geen wereld, geen ctx, zodat de tests elke groep en elke
## dag kunnen aflopen zonder dat er een beurt loopt.
##
## `core/sommen.gd` is bevroren; dit bestand LEEST alleen `Sommen.Prng`, zodat
## een dag altijd dezelfde vraag geeft en herladen dezelfde beurt.
##
## Eén schaalregel (HOTEL.md §3): elk aantal is k·N + r met N = het aantal
## gasten.  De koekjes liggen op een bakplaat in RIJEN × KOLOMMEN: de rijen zijn
## de gasten, de kolommen zijn wat elk dier krijgt — zo is de tafelsom een ding
## dat je kunt tellen.
##
##   groep 3  `koekjes`: N rijen × 1 of 2 → "2 + 2 + 2 =" (tot 16)
##            `eieren`:  N + r eieren in de kom (r 0..3) → "3 + 2 ="
##   groep 4  `plaat`:   N rijen × k (2, 5, 10) → "3 × 5 ="
##            `dubbel`:  het recept twee keer: e + e (e = N + r ≤ 10)
##   groep 5  `platen`:  2 platen × N × k (k 3..9, k·N ≤ 45) → "2 × 3 × 4 ="
##            `verdeel`: T = k·N + r koekjes eerlijk over N dieren → "14 : 3 =",
##                       de rest is voor de kok (delen met rest, IDEAS.md)

const ZAAD := 90317

const REGEL_PLAAT := "🍪 Hoeveel koekjes op de plaat?"      # 5 woorden, 31 tekens
const REGEL_PLATEN := "🍪 Hoeveel koekjes op 2 platen?"     # 6 woorden, 31 tekens
const REGEL_KOM := "🍪 Hoeveel eieren in de kom?"           # 5 woorden, 28 tekens
const REGEL_DUBBEL := "🍪 Dubbel recept: hoeveel eieren?"   # 4 woorden, 32 tekens
const REGEL_VERDEEL := "🍪 Hoeveel koekjes per dier?"       # 4 woorden, 28 tekens
const REGEL_REST := "▸ De rest is voor de kok"              # 6 woorden, 24 tekens
const KLAAR := "🍪 Klaar! Ze zijn gaar"                     # 4 woorden, 22 tekens
const KNOP := "Bakken"
const TAAK := "Bak koekjes"

## Alle zinnen die een kind te zien krijgt, voor de tekstregels van de test.
static func zinnen() -> Array[String]:
	return [REGEL_PLAAT, REGEL_PLATEN, REGEL_KOM, REGEL_DUBBEL, REGEL_VERDEEL,
		REGEL_REST, KLAAR]

## De beurt van vandaag voor `n_gasten` gasten in groep `band` (3, 4, 5).
## Sleutels: soort, regel, [regel2], som, goed, liever, rijen, kolommen,
## platen, eieren, totaal, rest.
static func maak(n_gasten: int, band: int, dag: int) -> Dictionary:
	var n := clampi(n_gasten, 1, 8)
	var rnd := Sommen.Prng.new(ZAAD + dag * 31 + n_gasten * 7 + band)
	match clampi(band, 3, 5):
		3:
			return _groep3(n, rnd)
		4:
			return _groep4(n, rnd)
		_:
			return _groep5(n, rnd)

static func _groep3(n: int, rnd: Sommen.Prng) -> Dictionary:
	if rnd.volgende() < 0.5:
		var per: int = _kies(rnd, [1, 2])
		var stukken: PackedStringArray = []
		for i in n:
			stukken.append(str(per))
		var goed := per * n
		return _beurt("koekjes", REGEL_PLAAT, " + ".join(stukken) + " =", goed,
			_liever(goed, [goed + 1, goed - 1, n + per]),
			{"rijen": n, "kolommen": per, "platen": 1})
	var r := _tot(rnd, 4)
	var goed := n + r
	return _beurt("eieren", REGEL_KOM, "%d + %d =" % [n, r], goed,
		_liever(goed, [goed + 1, goed - 1, goed + 2]), {"eieren": goed})

static func _groep4(n: int, rnd: Sommen.Prng) -> Dictionary:
	if rnd.volgende() < 0.5:
		var k: int = _kies(rnd, [2, 5, 10])
		var goed := k * n
		return _beurt("plaat", REGEL_PLAAT, "%d × %d =" % [n, k], goed,
			_liever(goed, [goed + k, goed - k, n + k]),
			{"rijen": n, "kolommen": k, "platen": 1})
	var e := mini(n + _tot(rnd, 3), 10)
	var goed := 2 * e
	return _beurt("dubbel", REGEL_DUBBEL, "%d + %d =" % [e, e], goed,
		_liever(goed, [goed + 1, goed - 1, e + 2]), {"eieren": e})

static func _groep5(n: int, rnd: Sommen.Prng) -> Dictionary:
	if n >= 2 and rnd.volgende() < 0.5:
		var k := 2 + _tot(rnd, 8)          # 2..9 per dier
		var r := _tot(rnd, n)              # 0..n-1 voor de kok
		var t := k * n + r
		var b := _beurt("verdeel", REGEL_VERDEEL, "%d : %d =" % [t, n], k,
			_liever(k, [k + 1, k - 1, (r if r > 0 else k + 2)]),
			{"totaal": t, "rest": r})
		b["regel2"] = REGEL_REST
		return b
	var ks: Array = []
	for k in [3, 4, 6, 7, 8, 9]:
		if k * n <= 45:
			ks.append(k)
	var k: int = _kies(rnd, ks)
	var goed := 2 * k * n
	return _beurt("platen", REGEL_PLATEN, "2 × %d × %d =" % [n, k], goed,
		_liever(goed, [k * n, goed + k, goed - n]),
		{"rijen": n, "kolommen": k, "platen": 2})

static func _beurt(soort: String, regel: String, som: String, goed: int,
		liever: Array, extra: Dictionary) -> Dictionary:
	var b := {"soort": soort, "regel": regel, "som": som, "goed": goed,
		"liever": liever, "rijen": 0, "kolommen": 0, "platen": 0, "eieren": 0,
		"totaal": goed, "rest": 0}
	for k in extra:
		b[k] = extra[k]
	return b

## Afleiders: anders dan het goede antwoord, groter dan nul, geen dubbele.
static func _liever(goed: int, kandidaten: Array) -> Array:
	var uit: Array = []
	for k in kandidaten:
		var n := int(k)
		if n > 0 and n != goed and not uit.has(n):
			uit.append(n)
	var extra := goed + 2
	while uit.size() < 3:
		if extra != goed and not uit.has(extra):
			uit.append(extra)
		extra += 1
	return uit

static func _tot(rnd: Sommen.Prng, n: int) -> int:
	return mini(int(floor(rnd.volgende() * n)), n - 1)

static func _kies(rnd: Sommen.Prng, lijst: Array) -> Variant:
	return lijst[_tot(rnd, lijst.size())]
