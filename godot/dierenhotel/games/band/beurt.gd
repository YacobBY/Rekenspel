extends RefCounted
## band — the numbers and the sentences of one turn of De dierenband (U2, the
## music room; owner 2026-10-07: "Verzin nog vier kamers met activiteiten").
## Pure and static: no world, no ctx, so the tests can walk every band and
## every day without a turn running.
##
## THE MATHS IS THE GAME'S OWN.  `core/sommen.gd` is frozen; this file only
## READS `Sommen.Prng`, the seeded mulberry32 every game shares, so a day
## always gives the same rhythm and a reload the same question.
##
## RHYTHM IS COUNTING MADE AUDIBLE.  The drum plays bars of ticks; every tick
## is a `plop` AND a lit note on the stave above the drum, so a muted tablet
## loses nothing.  One bar per guest (N = guests, clamped 2..6): more guests,
## more bars — the one scale rule.
##   band 3 (groep 3): one rhythm of T ticks (T ≤ 10)       "hoeveel tikken?"   T
##                     from day 3 half the time two short rhythms, two colours
##                                                          "hoeveel samen?"    A + B ≤ 20
##   band 4 (groep 4): a pattern of k ∈ {2, 5, 10} ticks repeated over M bars
##                                                          "tikken in M maten?" k × M
##   band 5 (groep 5): k ∈ {3, 4, 6, 7, 8} ticks × M bars   "tikken in M maten?" k × M
##                     on even days the inverse: ONE bar of k ticks is shown,
##                     "hoeveel maten voor D tikken?"       D ÷ k = M
## Distractors come from `ui/afleiders.gd` through `goed`, `min`, `max`.

const ZAAD := 60487

## Child text, verbatim.  The pictogram is the card's `icoon`.
## The bundled fonts have NO music glyph (`Ui.mist_tekens`, 2026-10-07: 🥁 🎵
## 🎶 🎼 🎹 ♪ ♫ 👂 🔁 all missing; 🔔 🔄 🎉 🐾 present), so the bell stands for
## the band until the font subset grows — OPEN QUESTION in the U2 stand file.
const ICOON := "🔔"
const ICOON_LUISTER := "🔔"
const ICOON_NOG := "🔄"
const ICOON_AF := "🎉"
const ICOON_AF2 := "🔔"
const T_TITEL := "Speel mee in de band"                 ## 5 woorden, 20 tekens (taakkaart)
const T_KNOP := "Dierenband"                            ## de knop op de trommel
const T_LUISTER := "Luister en kijk goed"               ## 4 woorden, 20 tekens
const T_TEL := "Hoeveel tikken hoorde je?"              ## 4 woorden, 25 tekens
const T_SAMEN := "Hoeveel tikken samen?"                ## 3 woorden, 21 tekens
const T_MATEN := "Hoeveel tikken in %d maten?"          ## 5 woorden, ≤ 27 tekens
const T_OMGEKEERD := "Hoeveel maten voor %d tikken?"    ## 5 woorden, ≤ 29 tekens
const T_NOG := "Nog een keer luisteren"                 ## 4 woorden, 22 tekens (knop)
const T_AF := "De band speelt!"                         ## 3 woorden, 15 tekens (toast)
const T_AF2 := "%d tikken, goed geteld"                 ## 4 woorden, ≤ 23 tekens

const MATEN_MIN := 2
const MATEN_MAX := 6
const SPRONGEN := [2, 5, 10]          ## groep 4: skip counting
const TAFELS := [3, 4, 6, 7, 8]       ## groep 5: the tables (7 × 8 is groep 5, IDEAS.md)
const SOORTEN := ["tel", "samen", "maten", "tafel", "omgekeerd"]

## Seconds between two ticks and the rest between two bars — the beats a child
## of six can still count along with.
const TIK_S := 0.42
const MAAT_RUST_S := 0.55

## One bar per guest, never fewer than two, never more than the stave holds.
static func maten_voor(n: int) -> int:
	return clampi(n, MATEN_MIN, MATEN_MAX)

## The turn for `n` guests in `band` on `dag`:
##   {soort, band, n, dag, maten: [[1..k], …], toon_maten, goed, min, max,
##    vraag, som, tikken, k, m [, doel]}
## `toon_maten` is how many bars the stave SHOWS while the drum plays; only the
## inverse question shows fewer than it has.
static func opzet(n: int, band: int, dag: int) -> Dictionary:
	var b := clampi(band, 3, 5)
	var gasten := maxi(n, 1)
	var rnd := Sommen.Prng.new(ZAAD + dag * 7919 + gasten * 131 + b * 17)
	var o := {"band": b, "n": gasten, "dag": dag, "k": 0, "m": 1}
	match b:
		3:
			if dag >= 3 and _tussen(rnd, 0, 1) == 1:
				var a := _tussen(rnd, 3, 10)
				var c := _tussen(rnd, 2, 10)
				o["soort"] = "samen"
				o["maten"] = [_ritme(a), _ritme(c)]
				o["k"] = a
				o["m"] = 2
				o["goed"] = a + c
				o["vraag"] = T_SAMEN
				o["som"] = "%d + %d =" % [a, c]
				o["min"] = 2
				o["max"] = 20
			else:
				var t := _tussen(rnd, 2, 10)
				o["soort"] = "tel"
				o["maten"] = [_ritme(t)]
				o["k"] = t
				o["goed"] = t
				o["vraag"] = T_TEL
				o["som"] = ""
				o["min"] = 1
				o["max"] = 10
		4:
			var k: int = SPRONGEN[_tussen(rnd, 0, SPRONGEN.size() - 1)]
			var m := maten_voor(gasten)
			o["soort"] = "maten"
			o["maten"] = herhaal(k, m)
			o["k"] = k
			o["m"] = m
			o["goed"] = k * m
			o["vraag"] = T_MATEN % m
			o["som"] = "%d × %d =" % [m, k]
			o["min"] = 1
			o["max"] = k * m + 10
		_:
			var k: int = TAFELS[_tussen(rnd, 0, TAFELS.size() - 1)]
			var m := maten_voor(gasten)
			o["k"] = k
			o["m"] = m
			o["maten"] = herhaal(k, m)
			if dag % 2 == 0:
				o["soort"] = "omgekeerd"
				o["doel"] = k * m
				o["goed"] = m
				o["vraag"] = T_OMGEKEERD % (k * m)
				o["som"] = "%d : %d =" % [k * m, k]
				o["min"] = 1
				o["max"] = 9
			else:
				o["soort"] = "tafel"
				o["goed"] = k * m
				o["vraag"] = T_MATEN % m
				o["som"] = "%d × %d =" % [m, k]
				o["min"] = 1
				o["max"] = k * m + 10
	o["toon_maten"] = 1 if o["soort"] == "omgekeerd" else (o["maten"] as Array).size()
	o["tikken"] = tel_tikken(o["maten"])
	return o

## `m` bars of `k` ticks each.
static func herhaal(k: int, m: int) -> Array:
	var uit: Array = []
	for _i in m:
		uit.append(_ritme(k))
	return uit

## Every tick of every bar, counted.
static func tel_tikken(maten: Array) -> int:
	var n := 0
	for maat in maten:
		n += (maat as Array).size()
	return n

## The sentence after the right answer: "%d tikken, goed geteld".
static func af2(o: Dictionary) -> String:
	return T_AF2 % int(o["tikken"])

## The question of a turn, pictogram first — the string the card gets as `regel`.
static func vraag(o: Dictionary) -> String:
	return String(o["vraag"])

## Every child-facing sentence a turn can show, for the text-rule test.
static func zinnen() -> Array[String]:
	return [T_TITEL, T_KNOP, T_LUISTER, T_TEL, T_SAMEN, T_MATEN % 6, T_OMGEKEERD % 48,
		T_NOG, T_AF, T_AF2 % 48]

# ------------------------------------------------------------------ hulp

static func _ritme(t: int) -> Array:
	var uit: Array = []
	for i in t:
		uit.append(i + 1)
	return uit

## A whole number in [a, b], from the shared PRNG.
static func _tussen(rnd, a: int, b: int) -> int:
	return a + int(floor(rnd.volgende() * float(b - a + 1)))
