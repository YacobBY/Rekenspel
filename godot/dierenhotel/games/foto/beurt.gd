extends RefCounted
## foto — de getallen en de zinnen van één beurt in het fotohokje van de
## Winkelstraat (eigenaar, 2026-10-01: "een fotohokje ... waar je minimaal 2
## dieren moet kiezen die op de foto gaan en de prijs per dier daaronder en dan
## een hoe veel geld je moet inwerpen").  Puur en statisch: geen wereld, geen
## ctx, zodat de tests elke groep, elke dag en elk aantal dieren kunnen aflopen.
##
## HET REKENEN IS VAN HET HOKJE ZELF.  `core/sommen.gd` is bevroren; dit bestand
## LEEST alleen `Sommen.Prng`, de gezaaide mulberry32 die elk spel deelt, zodat
## een dag altijd dezelfde prijs geeft en herladen dezelfde vraag.
##
## Eén prijs per dier, zoals een echt fotohokje: wie er ook op gaat, elk dier
## kost hetzelfde.  Er gaan twee, drie of vier dieren op de foto (`aantal`, het
## hokje van vandaag); het eerste stapt vanzelf in, de anderen kiest het kind,
## en na elk dier dat erbij komt: wat kost de foto nu?
##   groep 3: €2 + €2 + €2 =      herhaald optellen, prijs €2 … €5, tot €20
##   groep 4: 3 × €7 =            alle tafels (eind groep 4, eigenaar 2026-11-15):
##                                €2 … €10, tot 4 × €10 = €40
##   groep 5: 4 × €14 =           de tafels van 6 … 9 en tweecijferige prijzen
##                                (€11, €14, €15, €18), tot 4 × €18 = €72
## Dan het geld erin: welke munten en briefjes zijn precies dat bedrag
## (`games/_winkel/beurt.gd`, dezelfde handjes geld als in de winkels).  Zo
## rekent het kind na elke keuze, en is rekenen meer dan de helft van de tikken
## (eigenaar, 2026-10-08: "rekenen moet minstens 50% van de interactie zijn").
## Eén schaalregel (HOTEL.md §3): de prijs is k·N + r — N het aantal gasten, r
## uit het zaad van de dag — teruggevouwen in het bereik van de groep.  Hele
## euro's, geen kommageld (IDEAS.md).

const ZAAD := 60317
const MIN_DIEREN := 2
const MAX_DIEREN := 4

## De prijzen van groep 4: alle tafels tot 10 (eind groep 4, 2026-11-15) — de
## tafels van 2, 3, 4, 5 en 10 eerst, dan 6, 7, 8 en 9.
const TAFELS_4 := [2, 3, 4, 5, 10, 6, 7, 8, 9]
## De prijzen van groep 5: nooit makkelijker dan groep 4 — de lastige tafels en
## tweecijferige prijzen (keer met splitsen, 4 × €14), elk antwoord in hooguit
## vier munten en briefjes te betalen (dus geen €12: 4 × €12 = €48 is er vijf).
const PRIJZEN_5 := [6, 7, 8, 9, 11, 14, 15, 18]

# ------------------------------------------------------------ de kindtekst

const ICOON := "📸"
const ICOON_GELD := "💶"
const ICOON_AF := "✨"
const ICOON_WEG := "😞"
const T_KNOP := "Foto"
const T_KIES := "Wie gaan er op de foto?"            ## 6 woorden, 23 tekens
const T_SOM := "Hoeveel kost de foto nu?"            ## 5 woorden, 24 tekens
const T_BETAAL := "Welk geld gooi je erin?"          ## 5 woorden, 23 tekens
const T_AF := "Klik! Wat een mooie foto!"            ## 5 woorden, 25 tekens
const T_WEG := "Dat klopt niet"                      ## 3 woorden
const T_LEEG := "nog te weinig gasten"
const T_BLIJ := "mooi!"

static func euro(n: int) -> String:
	return "€%d" % n

# ------------------------------------------------------------ de opzet

static func groep(band: int) -> int:
	return clampi(band, 3, 5)

## De prijs per dier van vandaag: k·N + r in het bereik van de groep.
static func prijs(n: int, band: int, dag: int) -> int:
	var b := groep(band)
	var gasten := maxi(1, n)
	var rnd := Sommen.Prng.new(ZAAD + dag * 7919 + gasten * 131 + b * 17)
	var r := int(rnd.volgende() * 5.0)
	match b:
		3:
			return 2 + (gasten + r) % 4                      # €2 … €5
		4:
			var r4 := int(rnd.volgende() * float(TAFELS_4.size()))
			return int(TAFELS_4[(gasten + r + r4) % TAFELS_4.size()])
	var r5 := int(rnd.volgende() * float(PRIJZEN_5.size()))
	return int(PRIJZEN_5[(2 * gasten + r + r5) % PRIJZEN_5.size()])

## Hoeveel dieren er vandaag op de foto gaan: twee, drie of vier, en nooit meer
## dan er mogen (`pool`, de dieren met een bed, hooguit vier).  Een functie van
## het hotel, de groep en de dag, zoals de prijs; de beurt bewaart het.
static func aantal(n: int, band: int, dag: int, pool: int) -> int:
	var hoog := mini(MAX_DIEREN, pool)
	if hoog <= MIN_DIEREN:
		return MIN_DIEREN
	var rnd := Sommen.Prng.new(ZAAD + 4241 + dag * 613 + maxi(1, n) * 29 + groep(band) * 5)
	var keuzes := hoog - MIN_DIEREN + 1
	return MIN_DIEREN + int(rnd.volgende() * float(keuzes)) % keuzes

## Wat er in moet: zoveel dieren keer de prijs per dier.
static func goed(aantal: int, prijs_: int) -> int:
	return aantal * prijs_

## De somregel onder de vraag: in groep 3 de prijzen onder elkaar opgeteld
## (wat het kind op het scherm onder elk dier ziet staan), vanaf groep 4 de
## keersom.
static func som(aantal: int, prijs_: int, band: int) -> String:
	if groep(band) == 3:
		var delen: Array[String] = []
		for i in aantal:
			delen.append(euro(prijs_))
		return " + ".join(delen) + " ="
	return "%d × %s =" % [aantal, euro(prijs_)]

## De vergissingen die een kind echt maakt, voor de antwoordstrook
## (`Afleiders.vier`): één dier te weinig of te veel, het aantal en de prijs
## opgeteld in plaats van keer, en de prijs van één dier.
static func liever(aantal: int, prijs_: int) -> Array:
	return [(aantal - 1) * prijs_, (aantal + 1) * prijs_, aantal + prijs_, prijs_]

## Het zaad van de antwoordstrook: dezelfde vier bedragen in dezelfde volgorde
## zolang het dezelfde vraag is.
static func zaad(n: int, band: int, dag: int, aantal: int) -> int:
	return ZAAD + dag * 31 + maxi(1, n) * 7 + groep(band) * 3 + aantal * 101
