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
## kost hetzelfde.  Het kind kiest twee, drie of vier dieren, en dan:
##   groep 3: €2 + €2 + €2 =      herhaald optellen, prijs €2 … €5, tot €20
##   groep 4: 3 × €2 =            de tafels van groep 4: €2, €3, €4, €5, €10
##   groep 5: 4 × €7 =            de tafels tot 9: €3 … €9
## Eén schaalregel (HOTEL.md §3): de prijs is k·N + r — N het aantal gasten, r
## uit het zaad van de dag — teruggevouwen in het bereik van de groep.  Hele
## euro's, geen kommageld (IDEAS.md).

const ZAAD := 60317
const MIN_DIEREN := 2
const MAX_DIEREN := 4

## De prijzen van groep 4: de tafels die daar geleerd worden (IDEAS.md).
const TAFELS_4 := [2, 3, 4, 5, 10]

# ------------------------------------------------------------ de kindtekst

const ICOON := "📸"
const ICOON_GELD := "💶"
const ICOON_AF := "✨"
const ICOON_WEG := "😞"
const T_KNOP := "Foto"
const T_KIES := "Wie gaan er op de foto?"            ## 6 woorden, 23 tekens
const T_KLAAR := "Klaar"
const T_SOM := "Hoeveel geld gooi je erin?"          ## 5 woorden, 26 tekens
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
			return int(TAFELS_4[(gasten + r) % TAFELS_4.size()])
	return 3 + (2 * gasten + r) % 7                          # €3 … €9

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
