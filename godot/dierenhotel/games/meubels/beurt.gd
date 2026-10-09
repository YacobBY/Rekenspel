extends RefCounted
## meubels — de rekenvragen van één aankoop (golf 2, de Rekenwacht: R1 en R2).
##
## Puur en statisch: geen wereld, geen opslag, geen kaarten.  `Sommen.Meubels`
## (de bevroren kern) levert de catalogus en de bandregels; wat hier staat zijn
## de vragen die er sinds de regel van de eigenaar bij horen ("het moet niet
## mogelijk zijn om rekenen over te slaan en rekenen moet minstens 50% van de
## interactie zijn"):
##
##   * ELKE aankoop vraagt rekenen, ook één ding en ook groep 3 — vroeger had
##     alleen een lijstje van twee dingen een som;
##   * `genoeg`: "Heb je genoeg?" — de vergelijking die het kaartje in het boek
##     vroeger zelf deed (🛒 of 💛).  IDEAS.md: "enough/not enough" is groep 3-geld;
##   * `munten`: het bedrag op de toonbank leggen is een gekeurde handeling: elke
##     munt telt als rekenen, en bij de prijs (of erover) keurt het spel de stapel;
##   * `wissel`: groep 4/5 rekent ALTIJD het wisselgeld uit — ook bij precies
##     betalen ("€4 − €4 = €0": nul is een uitkomst, geen raadsel);
##   * `over`: "Hoeveel houd je over?" — wat je had min wat het kost.
##
## Met sterren (de versiering) is er geen toonbank: `genoeg` en `over` met ⭐.

const SOM := "som"
const GENOEG := "genoeg"
const MUNTEN := "munten"
const WISSEL := "wissel"
const OVER := "over"

## De stappen van één aankoop, in volgorde.  `valuta` is "munt" of "ster".
static func stappen(band: int, aantal: int, valuta: String) -> Array[String]:
	var uit: Array[String] = []
	if valuta == "munt" and aantal > 1:
		uit.append(SOM)                      # groep 4/5: twee dingen samen
	uit.append(GENOEG)
	if valuta == "munt":
		uit.append(MUNTEN)
		if Sommen.Meubels.wisselgeld(band):
			uit.append(WISSEL)
	uit.append(OVER)
	return uit

## De stap na `stap`; "" = klaar, er is betaald.
static func volgende(stap: String, band: int, aantal: int, valuta: String) -> String:
	var rij := stappen(band, aantal, valuta)
	var i := rij.find(stap)
	if i < 0 or i + 1 >= rij.size():
		return ""
	return rij[i + 1]

## De eerste stap van een aankoop.
static func eerste(band: int, aantal: int, valuta: String) -> String:
	return stappen(band, aantal, valuta)[0]

## "Heb je genoeg?" — het goede antwoord.
static func genoeg(heb: int, prijs: int) -> bool:
	return heb >= prijs

## "Hoeveel houd je over?" — wat je had min wat het kost.
static func over(heb: int, prijs: int) -> int:
	return heb - prijs

## De vergissingen die de strook van `over` expres aanbiedt: de prijs zelf, wat
## je had, en net ernaast (IDEAS.md: de valkuil is het doel, niet het ongeluk).
static func over_liever(heb: int, prijs: int) -> Array[int]:
	var goed := over(heb, prijs)
	var uit: Array[int] = [prijs, heb, goed + 1]
	if goed >= 1:
		uit.append(goed - 1)
	return uit

## Wisselgeld: wat je gaf min wat het kost (0 bij precies betalen).
static func wissel(gegeven: int, prijs: int) -> int:
	return gegeven - prijs

static func wissel_liever(gegeven: int, prijs: int) -> Array[int]:
	return [prijs, gegeven, wissel(gegeven, prijs) + 1]

## De keuring van de stapel op de toonbank na elke munt:
##   "nog"     — minder dan de prijs: gewoon verder leggen;
##   "precies" — precies de prijs;
##   "wissel"  — meer dan de prijs, en de band rekent wisselgeld uit (groep 4/5);
##   "te_veel" — meer dan de prijs in groep 3: een misser, de stapel gaat terug.
static func leg(gelegd: int, prijs: int, band: int) -> String:
	if gelegd < prijs:
		return "nog"
	if gelegd == prijs:
		return "precies"
	return "wissel" if Sommen.Meubels.wisselgeld(band) else "te_veel"

## De muntsoorten die nog in je hand zitten, klein naar groot (hooguit vier:
## €1, €2, €5, €10 — de knoppen van de muntstrook).
static func muntsoorten(hand: Array) -> Array[int]:
	var uit: Array[int] = []
	for c in hand:
		var v := int(c)
		if v > 0 and not uit.has(v):
			uit.append(v)
	uit.sort()
	return uit

## Het cijferbudget van een strook: drie cijfers vanaf honderd.
static func cijfers(bedrag: int) -> int:
	return 3 if absi(bedrag) > 99 else 2
