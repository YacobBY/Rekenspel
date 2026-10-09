extends RefCounted
## De winkels — de getallen en de zinnen van één beurt (games-d.md §4).
## Puur en statisch: geen wereld, geen ctx, zodat de tests elke winkel, elke
## groep en elke dag kunnen aflopen zonder dat er een beurt loopt.
##
## HET REKENEN IS VAN DE WINKELS ZELF.  `core/sommen.gd` is bevroren; dit
## bestand LEEST alleen `Sommen.Prng`, de gezaaide mulberry32 die elk spel deelt,
## zodat een dag altijd dezelfde prijzen geeft en herladen dezelfde vraag.
##
## Eén schaalregel (HOTEL.md §3): elke prijs is k·N + r — k per ding, r uit het
## zaad van de dag — teruggevouwen in het bereik van de groep: een nieuwe gast
## zet de prijzen van de winkel dus op een nieuwe plek, en de groep bepaalt hoe
## groot ze mogen zijn.  Hele euro's overal: geen kommageld (IDEAS.md), en echte
## munten en briefjes (€1, €2, €5, €10, €20, €50, €100).
##
##   kraampjes (hoeden, sjaals, en de souvenirkraam `kraam`)  één ding kiezen,
##       dan groep 3: precies betalen tot €9, en wat er over is van de €10 in
##       de beurs · groep 4: precies betalen tot €19, en wat er over is van de
##       €20 · groep 5: halve prijs (de prijzen zijn even), dan betalen met €50,
##       hoeveel terug?  Twee sommen per ding (eigenaar, 2026-10-08: "rekenen
##       moet minstens 50% van de interactie zijn": kiezen is één tik, rekenen
##       twee).
##   schoenen   per schoentje, één per poot (4, de gans 2), dan
##       "hoeveel kosten 4 gympjes?" (groep 3 verdubbelen tot 8, groep 4 de
##       tafels tot 20, groep 5 tot 36), dan precies betalen (3, 4) of terug (5)
##   luxe winkel  duur, en er komt een cadeaudoosje bij:
##       groep 3: samen (tot 13), precies betalen ·
##       groep 4: samen (tot 69), betalen met €100, terug ·
##       groep 5: halve prijs, samen met het doosje, terug van €50 of €100
## Een verkeerd antwoord kost geen hulp en geen ster, maar het dier moet de
## winkel uit (eigenaar, 2026-09-24; `WinkelSpel._weggestuurd`).

const ZAAD := 72421
const WINKEL_NR := {"hoeden": 1, "sjaals": 2, "schoenen": 3, "luxe": 4, "kraam": 5}

## Wat elke winkel verkoopt, van goedkoop naar duur (k = 1, 2, 3, 4).
const WAREN := {
	# the goods of 2026-10-07 stand LAST in every list (owner: "nog extra
	# accessoires om te kopen bij de kraampjes"): the old three keep their k,
	# so yesterday's prices stay what they were
	"hoeden": ["strik", "pet", "strohoed", "feestmuts", "bloem"],
	"sjaals": ["das", "sjaaltje", "streepsjaal", "bandana", "belletjes"],
	# groep 4 has only four shoe prices (€2..5), so the shoe stall holds four
	# things at most; flippers and slippers are souvenirs (one price a pair)
	"schoenen": ["sokjes", "gympjes", "laarsjes", "regenlaarsjes"],
	"luxe": ["zonnebril", "slofjes", "parels", "kroon", "tiara", "sterrenbril"],
	# the souvenirs of the old garden stall (games-b.md §5, moved into the
	# arcade on 2026-09-24): the same three pieces, so what an animal bought
	# there is still the thing on the counter here
	"kraam": ["sjaaltje", "hoedje", "bal", "pompoen", "goudbal", "zwemvliezen", "pantoffels"],
}

## Munten en briefjes per groep, groot naar klein.
const GELD := {3: [10, 5, 2, 1], 4: [20, 10, 5, 2, 1], 5: [50, 20, 10, 5, 2, 1]}

## What an animal has in its purse at a stall in groep 3 and 4 (the step
## `over`): the price always fits in it — €10 for prices up to €9 (groep 3:
## splitting 10), €20 up to €19 (groep 4: within 20).
const BEURS := {3: 10, 4: 20}

# ------------------------------------------------------------ de kindtekst

const T_KIES := "Wat kiest %s?"                          ## 3 woorden
const T_SOM_SCHOEN := "Hoeveel kosten %d %s?"            ## 4 woorden
const T_SOM_DOOS := "Hoeveel samen met het doosje?"      ## 5 woorden, 29 tekens
const T_HALF := "Halve prijs! Hoeveel is dat?"           ## 5 woorden, 28 tekens
const T_BETAAL := "Met welk geld betaal je %s?"          ## 6 woorden
const T_TERUG := "%s betaalt %s. Hoeveel terug?"          ## 5 woorden
const T_OVER := "%s had %s. Hoeveel over?"                ## 5 woorden, 33 tekens
const T_AF := "%s draagt nu %s %s!"                      ## 5-6 woorden
const T_WEG := "Dat klopt niet"                          ## 3 woorden
const T_LEEG := "nog geen gasten"
const T_BLIJ := "mooi!"
const ICOON_WEG := "😞"
const ICOON_AF := "✅"
const ICOON_GELD := "💶"
const ICOON_DOOS := "🎁"

## The first letter up: "Pet" on a button.
static func hoofd(w: String) -> String:
	return w if w.is_empty() else w.substr(0, 1).to_upper() + w.substr(1)

static func euro(n: int) -> String:
	return "€%d" % n

# ------------------------------------------------------------ de opzet

## Which band's numbers: 3, 4 or 5.
static func groep(band: int) -> int:
	return clampi(band, 3, 5)

## The shop of today: its goods with their prices, the gift box (luxe), and the
## seed of its answer strips.  A pure function of shop, N, band and day.
##   {winkel, band, N, dag, waren: [{naam, prijs}], doosje, zaad}
static func opzet(winkel: String, n: int, band: int, dag: int) -> Dictionary:
	var b := groep(band)
	var gasten := maxi(1, n)
	var nr: int = WINKEL_NR.get(winkel, 1)
	var rnd := Sommen.Prng.new(ZAAD + dag * 7919 + gasten * 131 + b * 17 + nr * 1009)
	var namen: Array = WAREN.get(winkel, WAREN["hoeden"])
	var waren: Array = []
	var gezien := {}
	for i in namen.size():
		var k := i + 1
		var r := int(rnd.volgende() * 4.0)
		var p := prijs(winkel, b, k, gasten, r)
		# two things on one counter never cost the same, except shoes in groep 3
		# (€1 or €2 a shoe is all there is); a price that steps by 5 or by 2
		# keeps doing so, also round the top of the range
		var bereik := _bereik(winkel, b)
		var stap := 1
		if winkel == "luxe" and b == 4:
			stap = 5
		elif b == 5 and winkel != "schoenen":
			stap = 2
		var rondjes := 0
		while gezien.has(p) and not (winkel == "schoenen" and b == 3) and rondjes < 40:
			p -= stap
			if p < int(bereik[0]):
				p = int(bereik[1]) - (int(bereik[1]) - int(bereik[0])) % stap
			rondjes += 1
		gezien[p] = true
		waren.append({"naam": str(namen[i]), "prijs": p})
	var doosje := 0
	if winkel == "luxe":
		match b:
			3: doosje = 1 + int(rnd.volgende() * 3.0)          # €1..3
			4: doosje = 2 + int(rnd.volgende() * 8.0)          # €2..9
			_: doosje = 3 + int(rnd.volgende() * 7.0)          # €3..9
	return {"winkel": winkel, "band": b, "N": gasten, "dag": dag, "waren": waren,
		"doosje": doosje, "zaad": int(rnd.volgende() * 100000.0)}

## [lo, hi] of a price in this shop and band.
static func _bereik(winkel: String, b: int) -> Array:
	match winkel:
		"schoenen":
			return [1, 2] if b == 3 else ([2, 5] if b == 4 else [3, 9])
		"luxe":
			return [5, 10] if b == 3 else ([20, 60] if b == 4 else [40, 98])
	return [2, 9] if b == 3 else ([6, 19] if b == 4 else [12, 39])

## One price: k·N + r (k = how dear the thing is, r = the day's seed), folded
## into the band's range, so it grows with the hotel and never leaves the range.
static func prijs(winkel: String, b: int, k: int, n: int, r: int) -> int:
	var bereik := _bereik(winkel, b)
	var lo: int = bereik[0]
	var hi: int = bereik[1]
	match winkel:
		"luxe":
			if b == 4:
				return lo + 5 * ((k * n + r) % (int((hi - lo) / 5) + 1))    # 20, 25 … 60
			if b == 5:
				return lo + 2 * ((k * 3 * n + r * 5) % (int((hi - lo) / 2) + 1))  # even, 40 … 98
			return lo + (k * n + r) % (hi - lo + 1)
		"schoenen":
			return lo + (k * n + r) % (hi - lo + 1)
	if b == 5:
		# even, 12 … 38: a stall in groep 5 sells at half price (`stappen`),
		# and half of it is whole euros
		return lo + 2 * ((k * n + r) % (int((hi - lo) / 2) + 1))
	return mini(hi, lo + (k * n + r) % (hi - lo + 1))

# ------------------------------------------------------------ de toonbank

## What stands on the counter today — THE one choice, used by the open stall
## (`WinkelSpel._te_koop`) and by the counter at rest (`WinkelSpel.rust_van`),
## so the child sees on a closed stall what it sells when opened (W5a,
## 2026-10-08).  `o` is today's `opzet`; `eigen` what the animal of the turn
## already owns (the counter at rest has no animal: []); `toon` how many things
## at most.  Everything the shop has, except what the animal owns — unless it
## owns it all, then everything again — at most `toon`; with more than one
## over (the extra goods of 2026-10-07) the list turns by the day and the
## hotel's size, so every thing comes round on the counter.  Returns the
## `waren` entries ({naam, prijs}) in counter order.
static func te_koop(o: Dictionary, eigen: Array, toon: int) -> Array:
	var uit: Array = []
	for w in o.get("waren", []):
		if not eigen.has(str(w["naam"])):
			uit.append(w)
	if uit.is_empty():
		uit = (o.get("waren", []) as Array).duplicate()
	var draai := (int(o.get("dag", 1)) + int(o.get("N", 1))) % maxi(1, uit.size())
	if uit.size() > toon + 1:
		uit = uit.slice(draai) + uit.slice(0, draai)
		uit = uit.slice(0, toon)
	elif uit.size() > toon:
		uit.remove_at(draai)
		uit = uit.slice(0, toon)
	return uit

# ------------------------------------------------------------ de stappen

## The steps of a turn, in order: the choice, then at least two sums in every
## shop and every groep (owner, 2026-10-08: maths at least half of the taps —
## the choice is one tap).  A stall: groep 3/4 pay exactly, then what is left
## in the purse (`over`); groep 5 half price, then the change from €50.
static func stappen(winkel: String, band: int) -> Array:
	var b := groep(band)
	match winkel:
		"schoenen":
			return ["kies", "som", "betaal" if b <= 4 else "terug"]
		"luxe":
			if b == 3:
				return ["kies", "som", "betaal"]
			if b == 4:
				return ["kies", "som", "terug"]
			return ["kies", "half", "som", "terug"]
	return ["kies", "betaal", "over"] if b <= 4 else ["kies", "half", "terug"]

## The steps that are a sum (an answer strip of numbers or of money).
const REKENSTAPPEN := ["som", "half", "betaal", "terug", "over"]

static func volgende(winkel: String, band: int, stap: String) -> String:
	var lijst := stappen(winkel, band)
	var i := lijst.find(stap)
	return "af" if i < 0 or i + 1 >= lijst.size() else str(lijst[i + 1])

static func waar_van(o: Dictionary, naam: String) -> Dictionary:
	for w in o.get("waren", []):
		if str(w["naam"]) == naam:
			return w
	return {}

static func poten(kind: String) -> int:
	return ArtGasten.poten_van(kind)

## The price of the thing chosen, as the child first meets it.
static func prijs_van(o: Dictionary, naam: String) -> int:
	return int(waar_van(o, naam).get("prijs", 0))

## Everything a turn asks, from the shop, the thing and the animal's kind.
##   {prijs, poten, half, som, totaal, briefje, terug, beurs, over}
##   totaal = what has to be paid; briefje = the note the animal pays with in
##   a "terug" step; terug = the change; beurs = the purse at a stall in
##   groep 3/4 and over = what is left in it after paying ("over" step).
static func sommen(o: Dictionary, naam: String, kind: String) -> Dictionary:
	var winkel := str(o["winkel"])
	var b := int(o["band"])
	var p := prijs_van(o, naam)
	var uit := {"prijs": p, "poten": poten(kind), "half": 0, "som": p, "totaal": p,
		"briefje": 0, "terug": 0, "beurs": 0, "over": 0}
	if winkel == "schoenen":
		uit["som"] = p * int(uit["poten"])
		uit["totaal"] = uit["som"]
	elif winkel == "luxe":
		var basis := p
		if b >= 5:
			uit["half"] = int(p / 2)
			basis = int(uit["half"])
		uit["som"] = basis + int(o["doosje"])
		uit["totaal"] = uit["som"]
	elif b >= 5:
		# a stall in groep 5: half price (its prices are even, `prijs`)
		uit["half"] = int(p / 2)
		uit["totaal"] = uit["half"]
	else:
		# a stall in groep 3/4: the purse, and what is left of it
		uit["beurs"] = int(BEURS.get(b, 20))
		uit["over"] = int(uit["beurs"]) - p
	# the smallest note that is MORE than the bill, so there is always change
	# (groep 5 pays with €50 or €100, never with a note that just fits)
	var t := int(uit["totaal"])
	for briefje in ([20, 50, 100] if b <= 4 else [50, 100]):
		if briefje > t:
			uit["briefje"] = briefje
			break
	uit["terug"] = int(uit["briefje"]) - t
	return uit

## The right answer of a number step.
static func goed(stap: String, s: Dictionary) -> int:
	match stap:
		"som":
			return int(s["som"])
		"half":
			return int(s["half"])
		"terug":
			return int(s["terug"])
		"betaal":
			return int(s["totaal"])
		"over":
			return int(s.get("over", 0))
	return 0

## The slips a child really makes, for the answer strip (`Afleiders.vier`).
static func liever(stap: String, s: Dictionary, o: Dictionary) -> Array:
	var p := int(s["prijs"])
	match stap:
		"som":
			if str(o["winkel"]) == "schoenen":
				# adding instead of multiplying, one shoe, one paw too many
				return [p + int(s["poten"]), p, p * (int(s["poten"]) + 1)]
			var basis := int(s["half"]) if int(s["half"]) > 0 else p
			return [basis, basis + int(o["doosje"]) + 10, basis + int(o["doosje"]) - 10]
		"half":
			return [p, int(s["half"]) + 10, int(s["half"]) - 10]
		"terug":
			# the price itself, and ten off
			return [int(s["totaal"]), int(s["terug"]) + 10, int(s["terug"]) - 10]
		"over":
			# the price itself, and one off when counting on to the purse
			return [int(s["totaal"]), int(s["over"]) + 1, int(s["over"]) - 1]
	return []

# ------------------------------------------------------------ het betalen

## The fewest coins and notes that make `bedrag` (greedy works for euros).
static func stapel(bedrag: int, band: int) -> Array:
	var uit: Array = []
	var rest := bedrag
	for m in GELD.get(groep(band), GELD[4]):
		while rest >= int(m):
			uit.append(int(m))
			rest -= int(m)
	return uit

static func tel(stapel_: Array) -> int:
	var som := 0
	for m in stapel_:
		som += int(m)
	return som

## "€5 + €2" — and "5+2" where the strip is narrow.
static func stapel_tekst(stapel_: Array) -> String:
	var delen: Array[String] = []
	for m in stapel_:
		delen.append(euro(int(m)))
	return " + ".join(delen)

static func stapel_kort(stapel_: Array) -> String:
	var delen: Array[String] = []
	for m in stapel_:
		delen.append(str(int(m)))
	return "+".join(delen)

## The money button's short word on a phone: the 💶 over the coins
## ("💶" / "10+5+2+1"), so the button is no wider than its numbers and still
## carries its pictogram (HOTEL.md §9: pictogram AND word).
static func stapel_knop_kort(stapel_: Array) -> String:
	return "%s\n%s" % [ICOON_GELD, stapel_kort(stapel_)]

## Four ways to pay, exactly one of them the right amount: the fewest coins and
## notes for the price, and for a euro less, a euro more and two more (or three
## more when there is no euro less) — every one a real handful of money, never
## more than four pieces.  Their order comes from the seed, so the right one is
## not always in the same place, and a reload draws the same four.
static func betaal_keuzes(totaal: int, band: int, zaad: int) -> Array:
	var sommen_: Array[int] = [totaal]
	for d in [-1, 1, 2, 3, -2]:
		var t := totaal + int(d)
		if sommen_.size() >= 4:
			break
		if t >= 1 and not sommen_.has(t) and stapel(t, band).size() <= 4:
			sommen_.append(t)
	var uit: Array = []
	for t in sommen_:
		uit.append(stapel(t, band))
	var rnd := Sommen.Prng.new(zaad * 7 + totaal * 13 + 3)
	for i in range(uit.size() - 1, 0, -1):
		var j := mini(i, int(rnd.volgende() * float(i + 1)))
		var tmp = uit[i]
		uit[i] = uit[j]
		uit[j] = tmp
	return uit

# ------------------------------------------------------------ de zinnen

## The card of one step: [regel, som].
static func kaart(stap: String, o: Dictionary, naam: String, s: Dictionary, gast: String) -> Array:
	var w: Dictionary = ArtGasten.KLEDING.get(naam, {})
	match stap:
		"kies":
			return [T_KIES % gast, ""]
		"som":
			if str(o["winkel"]) == "schoenen":
				return [T_SOM_SCHOEN % [int(s["poten"]), str(w.get("naam", naam))],
					"%d × %s =" % [int(s["poten"]), euro(int(s["prijs"]))]]
			var basis := int(s["half"]) if int(s["half"]) > 0 else int(s["prijs"])
			return [T_SOM_DOOS, "%s + %s =" % [euro(basis), euro(int(o["doosje"]))]]
		"half":
			return [T_HALF, "%s / 2 =" % euro(int(s["prijs"]))]
		"betaal":
			return [T_BETAAL % euro(int(s["totaal"])), euro(int(s["totaal"]))]
		"terug":
			return [T_TERUG % [gast, euro(int(s["briefje"]))],
				"%s − %s =" % [euro(int(s["briefje"])), euro(int(s["totaal"]))]]
		"over":
			return [T_OVER % [gast, euro(int(s["beurs"]))],
				"%s − %s =" % [euro(int(s["beurs"])), euro(int(s["totaal"]))]]
	return [T_AF % [gast, str(w.get("lid", "de")), str(w.get("naam", naam))], ""]
