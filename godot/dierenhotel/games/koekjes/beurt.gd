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
##   groep 3  `koekjes`: N rijen van 2 → "2 + 2 + 2 =" (2 tot 5 gasten, tot 10)
##            `eieren`:  N eieren in de kom en r ernaast (r 1..3) → "3 + 2 ="
##   groep 4  `plaat`:   N rijen × k (2, 5, 10) → "3 × 5 ="
##            `dubbel`:  twee kommen met e eieren (e = N+1 .. N+3, ≤ 10) → "4 + 4 ="
##   groep 5  `tafel`:   N rijen × k (3, 4, 6, 7, 8, 9) → "6 × 7 =" (alle tafels)
##            `verdeel`: T = k·N + r koekjes eerlijk over N dieren → "14 : 3 =",
##                       de rest is voor de kok (delen met rest, IDEAS.md)
##
## Wat er op de tafel ligt (`bank`) is de som zelf: de plaat met N × k bolletjes
## deeg, de kom met N eieren en r ernaast, de twee kommen, de T koekjes in
## rijen van tien.  Na het goede antwoord ligt de uitkomst er: gebakken
## koekjes, alle eieren in de kom, beslag, of N rijen van k en de rest op een
## bordje op de oven.

const ZAAD := 90317

## Het pictogram vóór elke zin op de kaart (de kaart zet het ervoor) en op elk
## getal van de strook.  🥚 🥣 🥐 staan sinds 2026-10-08 in de lettertypen
## (`test_ui`); het spel houdt 🍪 op elke kaart, ook die met de eieren, en 🥐
## is het pictogram van de bakkerij.
const ICOON := "🍪"
const ICOON_AF := "✨"
const ICOON_LEKKER := "😋"

const T_PLAAT := "Hoeveel koekjes op de plaat?"        ## 5 woorden, 28 tekens
const T_KOM := "Hoeveel eieren in de kom?"             ## 5 woorden, 25 tekens
const T_DUBBEL := "Dubbel recept: hoeveel eieren?"     ## 4 woorden, 30 tekens
const T_VERDEEL := "Hoeveel koekjes per dier?"         ## 4 woorden, 25 tekens
const T_REST := "▸ De rest is voor de kok"             ## 7 stukjes, 24 tekens
const T_GAAR := "Klaar! Ze zijn gaar"                  ## 4 woorden, 19 tekens
const T_IN_DE_KOM := "Alle eieren in de kom!"          ## 5 woorden, 22 tekens
const T_DEEG := "Het deeg is klaar"                    ## 4 woorden, 17 tekens
const T_EERLIJK := "Eerlijk verdeeld!"                 ## 2 woorden, 17 tekens
const T_LEKKER := "lekker!"
const T_LEEG := "nog geen gasten"
const KNOP := "Bakken"
const TAAK := "Bak koekjes"

## Alle zinnen die een kind te zien krijgt, voor de tekstregels van de test.
static func zinnen() -> Array[String]:
	return [T_PLAAT, T_KOM, T_DUBBEL, T_VERDEEL, T_REST, T_GAAR, T_IN_DE_KOM, T_DEEG,
		T_EERLIJK, T_LEKKER, T_LEEG, KNOP, TAAK]

## De vragen die als `regel` op een kaart staan (met het pictogram ervoor).
static func vragen() -> Array[String]:
	return [T_PLAAT, T_KOM, T_DUBBEL, T_VERDEEL, T_GAAR, T_IN_DE_KOM, T_DEEG, T_EERLIJK]

## De beurt van vandaag voor `n_gasten` gasten in groep `band` (3, 4, 5).
## Sleutels: soort, regel, [regel2], som, goed, liever, rijen, kolommen,
## eieren, erbij, totaal, rest.
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
	# één gast: één rij is geen optelsom; meer dan vijf rijen is een te lange
	# rij tweeën voor groep 3 — dan altijd de eieren
	if n >= 2 and n <= 5 and rnd.volgende() < 0.5:
		var stukken: PackedStringArray = []
		for i in n:
			stukken.append("2")
		var goed := 2 * n
		return _beurt("koekjes", T_PLAAT, " + ".join(stukken) + " =", goed,
			_liever(goed, [goed + 2, goed - 2, n]),
			{"rijen": n, "kolommen": 2})
	var r := 1 + _tot(rnd, 3)
	var goed := n + r
	return _beurt("eieren", T_KOM, "%d + %d =" % [n, r], goed,
		_liever(goed, [goed + 1, goed - 1, goed + 2]), {"eieren": n, "erbij": r})

static func _groep4(n: int, rnd: Sommen.Prng) -> Dictionary:
	if rnd.volgende() < 0.5:
		var k: int = _kies(rnd, [2, 5, 10])
		var goed := k * n
		return _beurt("plaat", T_PLAAT, "%d × %d =" % [n, k], goed,
			_liever(goed, [goed + k, goed - k, n + k]),
			{"rijen": n, "kolommen": k})
	var e := mini(n + 1 + _tot(rnd, 3), 10)
	var goed := 2 * e
	return _beurt("dubbel", T_DUBBEL, "%d + %d =" % [e, e], goed,
		_liever(goed, [goed + 1, goed - 1, e]), {"eieren": e})

static func _groep5(n: int, rnd: Sommen.Prng) -> Dictionary:
	if n >= 2 and rnd.volgende() < 0.5:
		var k := 2 + _tot(rnd, 8)          # 2..9 per dier
		var r := _tot(rnd, n)              # 0..n-1 voor de kok
		var t := k * n + r
		var b := _beurt("verdeel", T_VERDEEL, "%d : %d =" % [t, n], k,
			_liever(k, [k + 1, k - 1, (r if r > 0 else k + 2)]),
			{"rijen": n, "kolommen": k, "totaal": t, "rest": r})
		b["regel2"] = T_REST
		return b
	var k: int = _kies(rnd, [3, 4, 6, 7, 8, 9])
	var goed := k * n
	return _beurt("tafel", T_PLAAT, "%d × %d =" % [n, k], goed,
		_liever(goed, [goed + k, goed - k, n + k]),
		{"rijen": n, "kolommen": k})

static func _beurt(soort: String, regel: String, som: String, goed: int,
		liever: Array, extra: Dictionary) -> Dictionary:
	var b := {"soort": soort, "regel": regel, "som": som, "goed": goed,
		"liever": liever, "rijen": 0, "kolommen": 0, "eieren": 0, "erbij": 0,
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

# ------------------------------------------------------------ in de wereld

## Bakken de koekjes in de oven na het goede antwoord?  (Bij de eieren en bij
## het delen niet: daar ligt de uitkomst meteen op tafel.)
static func bakt(b: Dictionary) -> bool:
	return str(b.get("soort", "")) in ["koekjes", "plaat", "tafel"]

## Wat er op de bakkerstafel ligt (`ArtDecorBakkerij.werkbank`) in stap `stap`
## van de beurt: "som" (de vraag), "bak" (de plaat is in de oven) of "af".
static func bank(b: Dictionary, stap: String) -> Dictionary:
	var soort := str(b.get("soort", ""))
	var af := stap == "af"
	match soort:
		"eieren":
			var n := int(b.get("eieren", 0))
			var r := int(b.get("erbij", 0))
			if af:
				return {"kommen": [n + r]}
			return {"kommen": [n], "los": r}
		"dubbel":
			var e := int(b.get("eieren", 0))
			return {"kommen": [e, e], "beslag": af}
		"verdeel":
			if af:
				return {"rijen": int(b["rijen"]), "kolommen": int(b["kolommen"]),
					"aantal": int(b["rijen"]) * int(b["kolommen"]), "gaar": true}
			var t := int(b.get("totaal", 0))
			@warning_ignore("integer_division")
			return {"rijen": (t + 9) / 10, "kolommen": mini(t, 10), "aantal": t, "gaar": true}
		_:
			if stap == "bak":
				return {}
			return {"rijen": int(b.get("rijen", 0)), "kolommen": int(b.get("kolommen", 0)),
				"aantal": int(b.get("rijen", 0)) * int(b.get("kolommen", 0)), "gaar": af}

## De oven in stap `stap`: hij gloeit met de plaat erin, en na het delen staat
## de rest op een bordje op de oven.
static func oven(b: Dictionary, stap: String) -> Dictionary:
	var p := {}
	if stap == "bak" and bakt(b):
		p["bakt"] = true
	if stap == "af" and str(b.get("soort", "")) == "verdeel" and int(b.get("rest", 0)) > 0:
		p["rest"] = int(b["rest"])
	return p

## Hoeveel dingen er op de tafel liggen om te tellen: koekjes op de plaat,
## eieren in de kommen en ernaast (voor de tests: het getal staat in de wereld).
static func op_tafel(p: Dictionary) -> int:
	var n := 0
	if int(p.get("rijen", 0)) > 0:
		n += int(p.get("aantal", int(p["rijen"]) * int(p.get("kolommen", 0))))
	if not bool(p.get("beslag", false)):
		for k in p.get("kommen", []):
			n += int(k)
	n += int(p.get("los", 0))
	return n

## Wat het grote bord laat zien (`KoekjesBord`): wat er op de tafel ligt, en
## terwijl de plaat in de oven staat de plaat met het deeg in de ovenmond; na
## het delen ook het bordje met de rest voor de kok.
static func bord(b: Dictionary, stap: String) -> Dictionary:
	if stap == "bak":
		var p := bank(b, "som")
		p["oven"] = true
		return p
	var q := bank(b, stap)
	var o := oven(b, stap)
	if o.has("rest"):
		q["rest"] = int(o["rest"])
	return q

## De zin van de kaart als de beurt af is.
static func af_regel(b: Dictionary) -> String:
	match str(b.get("soort", "")):
		"eieren":
			return T_IN_DE_KOM
		"dubbel":
			return T_DEEG
		"verdeel":
			return T_EERLIJK
		_:
			return T_GAAR
