extends MiniGame
## DE VOERKAR — games-a.md §7, de referentie-implementatie van HOTEL.md §9.
##
## V2 — de keukenvloer wordt leeg (PLAN.md, sloper).  De vul-fase is weg:
## geen bakjes op de vloer, geen zak, geen pak-knoppen, geen Klaar/Opnieuw.
## De kar vertrekt vol — de eigenaarsbeslissing van 2026-09-20 is
## "doorduwen": `start()` zet `op_kar = T` en schiet door naar stap "duwen",
## zodat de hele lus (keuken → gang → kamer → bakje vullen → terug) speelbaar
## blijft en er geen dood scherm ontstaat.  V3 vervangt deze tussentijdse
## route door de echte som-poort (`_som_kaart`/`_op_som`), waar
## `op_kar = per * n` uit het antwoord van het kind valt.
##
## Bindend en ongewijzigd: de getallen (`Sommen.Voerkar.*`), nooit straffen
## (alleen `zacht()`), één ster voor het meedoen, en de kar die thuis komt.
## De hulpladder is weg (eigenaar 2026-09-24: "Nee geef geen hulp na fouten.
## Kinderen moeten zelf leren rekenen"): buurvrouw Els komt niet meer, ook niet
## met missers uit een oude opslag, en de kaart zegt nooit haar doelgetal.
##
## TIKKEN (eigenaar, 2026-09-23: "Zorg dat je op de kar kan klikken en daarna
## op een deur en zo de kar mee kan nemen").  Slepen was de enige weg, en alleen
## het labeltje NAAST de kar was sleepbaar — wie de getekende kar zelf pakte,
## greep in het niets.  Nu is tikken de weg, hangt de knop óp de kar en blijft
## slepen erbij (`_kar_invoer`):
##   * tik op de kar → je hebt hem vast: de knop wordt `🛒 Je duwt de kar`
##     (ingedrukt, met ☝) en de deuren op weg naar een hongerige kamer krijgen
##     een 👉 op hun bordje;
##   * tik op een deur → kar én camera gaan erdoor, en je houdt de kar vast;
##     een deur zonder vastgepakte kar neemt hem ook mee (geen dode tik, geen
##     "nee" om te lezen);
##   * tik op de vastgepakte kar → je zet hem neer (de 👉's gaan weg);
##   * het bakje is alleen een knop waar vullen nu kan: de kar staat in die
##     kamer en daar wacht nog iemand op zijn koekjes (vast of niet vast).
## Eén wolkje tegelijk, altijd `vk_zeg` bij de kar: de volgende stap in één
## zin.  Wat iets doet is een knop, wat alleen vertelt is een wolkje.  Heb je
## de kar vast, dan zegt de kar het zelf: `🛒 Je duwt de kar` en daaronder
## `👉 Tik op een deur`, in één bubbeltje met het koekjespilletje (eigenaar,
## 2026-09-24: "Verwerk deze twee teksten in een bubbeltje").
##
## DE SOM BIJ HET BAKJE (eigenaar, 2026-09-24: "De koekjes kar naar de kamer
## duwen heeft nu geen rekenwerk meer op het einde").  Een tik op het bakje (of
## de kar erop slepen) vult het niet meer meteen: er komt een somkaart
## (`vk_som`) met de vraag hoeveel koekjes erin gaan = de meespelende gasten van
## die kamer × `K.per`, als keersom (`2 × 4 =`) waar de band die tafel kent, als
## herhaalde optelling (`4 + 4 =`) in groep 3, en bij één gast alleen het getal.
## Goed → het bakje gaat vol zoals altijd (`lever`).  Fout → alleen `misser`
## (geen hulp, eigenaar 2026-09-24): het dier van de beurt loopt teleurgesteld
## naar het lege bakje, het bakje blijft leeg en dezelfde vraag blijft staan.
## De open vraag staat in `K.vraag`, zodat een herlaad hem terugzet.
##
## ETEN BIJ HET BAKJE (eigenaar, 2026-09-24: "Bij het vullen van het eten lopen
## de dieren niet naar de voerbakjes toe.  De eet animatie gebeurt op het bed").
## Na het goede antwoord staat elke gast van die kamer op, loopt naar een eigen
## vrij plekje bij het bakje (`eet_plekken`: vrije vloer, niet op elkaar,
## niet onder de kar) en eet daar (`World.eet_bij`).  Daarna zijn ze wakker.
## Met de snuit IN het bakje (eigenaar, 2026-09-24: "wanneer de hond van het
## voerbakje eet dan eet hij er net naast/achter in plaats van dat zijn mond
## erboven gaan"): zie `ETEN_SNUIT`.

##
## REKENEN EERST (wave 2, eigenaar 2026-10-08: "het moet niet mogelijk zijn om
## rekenen over te slaan en rekenen moet minstens 50% van de interactie zijn").
## Een beurt was per kamer één som tegen twee à drie tikken spel (de kar pakken,
## één of twee deuren, het bakje).  Nu:
##   * de beurt begint met de som van de kar in de keuken (`_lading_kaart`):
##     "🍪 Hoeveel koekjes gaan op de kar?", elke gast krijgt `per`, als
##     keersom of herhaalde optelling zoals bij het bakje (`bak_som`).  Het
##     goede antwoord IS de lading (`op_kar`); de rest van de bakkerij gaat aan
##     het eind zoals altijd in de snoeppot (`pot_rest`);
##   * daarna rijdt de kar zelf, kamer voor kamer, naar de volgende kamer met
##     honger (`_rijd_verder`) — geen deur en geen kar om aan te tikken — en
##     daar gaat de som van het bakje vanzelf open (`vraag_bak`);
##   * een fout antwoord is alleen een misser en de vraag blijft dezelfde, ook
##     na weggaan, herladen of een nieuwe dag (`K.mis`, `vraag_goed`/`vraag_som`
##     liggen vast in de stand).
## Zo is een beurt 1 + (kamers) rekenantwoorden en geen enkele speltik.

# --------------------------------------------------------------- vaste maten

const KAMER := "keuken"
## Hoogstens zes gasten doen mee (games-a.md §7.3).
const SPELERS_MAX := 6
const SMUL_MS := 2.6                          ## nagenieten, games-a.md §7.6
const LEEG_MS := 1.8                          ## "nog geen gasten"

const SOORT_ICO := {"puppy": "🐶", "poes": "🐱", "konijn": "🐰", "gans": "🦆", "vos": "🦊", "varken": "🐷"}
const KIND_ICO := {"hond": "🐶", "poes": "🐱", "konijn": "🐰", "gans": "🦆", "vos": "🦊", "varken": "🐷"}
const DIER_ONBEKEND := "🐾"

# ------------------------------------------------ kindteksten (F3, §7.7)

const T_GEEN_GASTEN := "nog geen gasten"
const T_VERDEEL := "Verdeel %d koekjes over %s"
const T_IEDER := "🫙 Ieder evenveel, de rest in de pot"
const T_PAK := "pak %d"
const T_ZAK_TITEL := "zak met %d koekjes, pak %d per tik"
const T_NOG_IN_ZAK := "nog in de zak"
const T_ZAK_LEEG := "zak is leeg"
const T_POT := "pot"
const T_POT_TITEL := "de snoeppot: %d koekjes"
const T_GAST_TITEL := "%s heeft %d koekjes"
const T_ERBIJ := "%d erbij"
const T_ERAF := "%d eraf"
const T_HIER_HOORT := "hier hoort %d in"
const T_KLAAR := "Klaar"
const T_KLAAR_TITEL := "de kar is klaar"
const T_OPNIEUW := "Opnieuw"
const T_OPNIEUW_TITEL := "alles opnieuw verdelen"
const T_KAMER := "kamer"
const T_KAMERS := "kamers"
const T_KAR_TITEL := "de voerkar: nog %d %s"
## De kar is een knop die zegt wat hij doet, en dan wat hij is (tikken, 2026-09-23).
const T_PAK_KAR := "Pak de kar"
const T_DUW_KAR := "Je duwt de kar"
## Het ene wolkje bij de kar: de eerste zin is de opdracht met het getal erin
## (het oude duw-wolkje, zo komt er geen tweede bij), daarna de volgende tik.
const T_BRENG := "Breng %d koekjes naar elke gast"
const T_TIK_KAR := "Tik op de kar"
const T_TIK_DEUR := "Tik op een deur"
const T_TIK_BAK := "Tik op het bakje"
const T_ALLE_VOL := "Alle bakjes vol!"
const T_KOEKJES := "koekjes"
const T_KOEKJES_ELK := "koekjes elk"
const T_KEUZE_TITEL := "hoeveel pak je per tik"
## De som bij het bakje (2026-09-24): de vraag, en wat elke gast krijgt.  De
## tweede zin draagt het getal per gast met `Ui.meervoud` ("1 koekje").
const T_HOEVEEL := "Hoeveel koekjes gaan in het bakje?"
const T_ELK := "Elke gast krijgt %s"
const T_SOM_TITEL := "de som van het bakje"
## de som van de kar (wave 2)
const T_LADING := "Hoeveel koekjes gaan op de kar?"
const T_LADING_TITEL := "de som van de kar"
const KAART_KAR := "vk_lading"
const KAR_TAG := "vk_karn"
## zo lang staat de kar in elke kamer waar hij doorheen rijdt (rustmodus korter)
const REIS_S := 0.9
const REIS_RUST_S := 0.2
## na het smullen rijdt de kar pas als de eters van die kamer niet meer lopen
## (hoogstens zo lang): het kind ziet ze bij het bakje eten
const ETEN_WACHT_S := 6.0
const T_SOM_KIES := "hoeveel koekjes gaan erin"

const ICO_KOEK := "🍪"
const ICO_POT := "🫙"
const ICO_KAR := "🛒"
const ICO_BED := "🛏"
const ICO_WIJS := "👉"
const ICO_VOL := "✅"
const ICO_SMUL := "😋"
## `↩` (U+21A9) zit niet in de meegeleverde emoji-subset; zonder terugval ziet
## een kind een leeg blokje.  De letterlijke tekst blijft hierboven staan, dus
## zodra het teken in het font zit komt hij vanzelf terug.
const ICO_OPNIEUW := "🔄"
const ICO_OPNIEUW_TERUG := "🔄"

## De sleepnaam die de deuren en de bakjes van het hotel al dragen (hotel.gd:
## `drop: "deur"` / `drop: "bak"`).  De kar draagt er één; de bakjes van de
## kamer waar de kar staat krijgen hem er tijdelijk bij, zodat slepen op een
## bakje net zo werkt als slepen op een deur.
const SLEEP_KAR := "deur"

## Zo ver (eenheden) moet een vinger of muis van het indrukpunt af zijn eer een
## druk op de kar een sleep wordt; daaronder is het een tik (zie `_kar_invoer`).
const SLEEP_AF := 10.0

## Het ene wolkje van de kar.  Elke zin die bij de kar hoort gebruikt dit id,
## dus er kan er nooit een tweede naast komen te hangen.
const ZEG := "vk_zeg"
## De meta op een geleend deurbordje: staat er nu een 👉 op?
const WIJS_META := "vk_wijs"
## De somkaart bij het bakje; haar strook heet `vk_som_keuzes`.
const KAART_BAK := "vk_som"

## Waar de gasten met hun snuit IN het bakje eten.  Het bakje is getekend voor
## een dier dat er schuin achter staat (art-sound-rules.md §7): in het raster van
## de modellen ligt het midden van het bakje op x = 29,5 (`ArtGasten.KOM_CX`) en
## reikt de neus van elk dier in `hap` tot x 28..31 (hond 31, poes en konijn 29,
## gans 28) — vanaf het anker op x 13 is dat 16,5 voxels.  Een dier dat 16,5
## voor het midden staat en ernaar kijkt, hapt dus midden in het bakje: van −x
## (gezicht 1, naar rechts) of van −z (gezicht −1, gespiegeld naar links).  Twee
## naast elkaar aan één kant staan 3 voxels uit het midden (een lijf is 6 breed)
## en houden hun neus binnen de rand (straal ±5,5).  De achterste helft van het
## bakje sorteert 20 voxels terug (`scenes/kamer.gd` KOM_ACHTER), dus al deze
## eters staan ervoor en hun kop zakt tussen achter- en voorwand.
## De sets in volgorde van voorkeur, per aantal eters; wie geen snuitplek krijgt
## (een volle kamer, een plek die niet vrij is) eet ernaast (`ETEN_PLEK`).
const ETEN_VOOR := 16.5
const ETEN_ZIJ := 3.0
const ETEN_SNUIT := [
	[Vector2(-ETEN_VOOR, -ETEN_ZIJ), Vector2(-ETEN_VOOR, ETEN_ZIJ),
		Vector2(-ETEN_ZIJ, -ETEN_VOOR), Vector2(ETEN_ZIJ, -ETEN_VOOR)],
	[Vector2(-ETEN_VOOR, -ETEN_ZIJ), Vector2(-ETEN_VOOR, ETEN_ZIJ), Vector2(0, -ETEN_VOOR)],
	[Vector2(-ETEN_VOOR, 0), Vector2(-ETEN_ZIJ, -ETEN_VOOR), Vector2(ETEN_ZIJ, -ETEN_VOOR)],
	[Vector2(-ETEN_VOOR, 0), Vector2(0, -ETEN_VOOR)],
	[Vector2(-ETEN_VOOR, -ETEN_ZIJ), Vector2(-ETEN_VOOR, ETEN_ZIJ)],
	[Vector2(-ETEN_ZIJ, -ETEN_VOOR), Vector2(ETEN_ZIJ, -ETEN_VOOR)],
	[Vector2(-ETEN_VOOR, 0)],
	[Vector2(0, -ETEN_VOOR)],
]
## Twee eters met hun snuit in het bakje staan minstens zo ver uit elkaar: zij
## aan zij aan één kant (6), of elk aan een eigen kant.
const ETEN_SNUIT_AF := 5.9
## Waar de gasten bij het bakje gaan eten als er geen snuitplek meer is:
## plekjes rond het bakje, in voxels vanaf het bakje, de mooiste eerst — schuin erachter en ernaast, zodat het
## bakje in beeld blijft (een dier ervóór dekt het af).  Elk plekje ligt 15..17
## voxels van het bakje: `Rooms.vrij_vak` houdt 15 (manhattan) rond een slot
## vrij, en zo staat het dier er toch vlak naast.  Daarna een ring op
## `ETEN_RING` (nog steeds naast het bakje, schuin erachter eerst), en pas voor
## een echt volle kamer een ring op 1,6 keer de eerste afstand.
const ETEN_PLEK := [Vector2(-13, -7), Vector2(7, -13), Vector2(12, -12), Vector2(-12, 12),
	Vector2(-7, -13), Vector2(13, 7), Vector2(-15, 0), Vector2(0, -15),
	Vector2(15, 0), Vector2(0, 15), Vector2(-13, 7), Vector2(13, -7),
	Vector2(7, 13), Vector2(-7, 13)]
const ETEN_RING := 18.5
const ETEN_RING2 := 1.6
## Zo ver (voxels) staan twee etende gasten minstens uit elkaar.
const ETEN_AF := 11.0
## De voet van de kar (ArtDecorKeuken.keukenkar, net als ArtDecor.kar: x −16..+14,
## z −9..+10) plus een rand: daar gaat niemand staan eten.
const KAR_VOET := Rect2(-16.0, -9.0, 30.0, 19.0)
const KAR_RAND := 6.0

# --------------------------------------------------------------- toestand

var K: Dictionary = {}            ## state.kar; de vorm van V2 (PLAN.md §7):
## {T, per, rest, op_kar, pot, stap, geleverd, missers, t0, dag, vraag}
## `stap` is "som" (de poort die V3 bouwt) of "duwen" (het rondje); `vraag` is
## de kamer waar de som van het bakje open staat, of "".
var _kaart = null                 ## Ui.Kaart
var _som_kaart = null             ## Ui.Kaart van de som bij het bakje
var _sluit_bezig := false
## Heeft het kind de kar vast?  Niet in de save: na een herlaad of een nieuwe
## start staat de kar thuis in de keuken, en daar is hij neergezet.
var _mee := false
## Had het kind de kar deze beurt al eens vast?  Dan is de opdracht gelezen en
## zegt een neergezette kar kort `👉 Tik op de kar`.
var _ooit_mee := false
## Het smulwolkje hangt 2,6 s bij de dieren van deze kamer; zolang wacht het
## wolkje van de kar (één wolkje tegelijk).  `_smul_nr` hoort bij de laatste
## levering, zodat een oud wachtje een nieuw smulwolkje niet weghaalt.
var _smul_kamer := ""
var _smul_nr := 0
## Waar de kar werd ingedrukt (lokaal op de knop), of INF als er niets vast zit.
var _druk_op := Vector2.INF
## De kar rijdt zelf (wave 2): één rit tegelijk, en een nummer per rit zodat
## een oude rit na een stop niets meer doet.
var _rijdt := false
var _reis_nr := 0

# ------------------------------------------------------------- aanmelding

func definitie() -> Dictionary:
	return {
		"naam": "De voerkar",
		"kamer": KAMER,
		"hotspot": {"obj": "kar", "icoon": ICO_KAR, "label": "Voerkar", "hoog": 16},
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		# `kan` (world.md §5.1): alleen als er een leeg bakje is in een kamer
		# waar iemand slaapt — met alles gevuld zei het spel "✅ Alle bakjes
		# vol!" en ging het weer dicht (eigenaar, 2026-09-23: "you can't
		# execute them").  Dezelfde vraag als het hotelkaartje "Vul de voerkar".
		"kan": func(_s: Dictionary) -> bool: return not Hotel.lege_bakken().is_empty(),
		# geen eigen taakkaartje: het hotel heeft er al één ("🍪 Vul de voerkar",
		# prikbord.gd), en dat vinkt `taak_klaar("voer")` af.
	}

# ------------------------------------------------------------------ start

func start(_c: SpelCtx) -> void:
	var g := deelnemers()
	if g.is_empty():
		_geen_gasten()
		return
	_lees_kar(g)
	# Wave 2: stap "som" is de som van de kar (`_lading_kaart`) — tot 2026-10-08
	# schoof de beurt hier door naar "duwen" en vertrok de kar vol zonder dat er
	# iets gevraagd was (eigenaarsbeslissing 2026-09-20 "doorduwen", vervallen).
	# Stond de som van een bakje nog open (herlaad, of het spel werd even
	# weggezet)?  Dan staan de kar en de camera weer bij dat bakje en komt
	# dezelfde vraag terug; is die kamer intussen gevoerd, dan vervalt hij.
	var vraag := str(K.get("vraag", ""))
	if not vraag.is_empty():
		if _is_open(vraag):
			_zet_kar_in(vraag)
		else:
			K["vraag"] = ""
			_bewaar_kar()
	_rondje()
	if str(K.get("stap", "")) == "duwen" and str(K.get("vraag", "")).is_empty():
		_rijd_verder()

## Geen enkele gast met een bed: één wolkje bij de kar en dan dicht.
func _geen_gasten() -> void:
	var kar: Dictionary = ctx.wereld.ding("kar")
	ctx.ui.wolk({"id": "vk_leeg", "kamer": KAMER,
		"x": float(kar.get("x", 60.0)), "z": float(kar.get("z", 57.0)),
		"hoog": 24.0, "icoon": ICO_BED, "tekst": T_GEEN_GASTEN, "prio": 11})
	ctx.wereld.vuil()
	if not await na(LEEG_MS):
		return
	ctx.ui.wolk_weg("vk_leeg")
	ctx.sluit()

## De kar rijdt het hotel door, maar hij hoort in de keuken: zonder deze regel
## blijft hij staan waar de beurt ophield en verdwijnt de 🛒-knop uit de keuken
## (games-a.md §7.6).  De camera blijft waar hij is; alleen de kar gaat naar huis.
func stop() -> void:
	_kaart = null
	_som_kaart = null
	_rijdt = false
	_reis_nr += 1
	_mee = false
	_ooit_mee = false
	_smul_kamer = ""
	if ctx != null:
		ctx.hotspots.laat()
		_bewaar_kar()
		ctx.wereld.ding_thuis_zet("kar")
		ctx.wereld.vuil()

## Heeft het kind de kar nu vast?  (Voor de tests en de browserproef.)
func mee() -> bool:
	return _mee

# ------------------------------------------------------- gasten en toestand

## De gasten die meedoen: iedereen met een bed in een kamer die een bakje
## heeft — wat geen bakje kan krijgen, wordt nooit gevoerd (PLAN.md V2) —
## hoogstens SPELERS_MAX.
func deelnemers() -> Array:
	var uit: Array = []
	for g in ctx.state.s["gasten"]:
		if str(g.get("bed", "")).is_empty():
			continue
		var kamer := str(g.get("kamer", ""))
		if kamer.is_empty() or ctx.wereld.slots(kamer, "bak").is_empty():
			continue
		uit.append(g)
		if uit.size() >= SPELERS_MAX:
			break
	return uit

func _lees_kar(g: Array) -> void:
	var bewaard = ctx.state.s.get("kar", null)
	if typeof(bewaard) != TYPE_DICTIONARY:
		bewaard = ctx.data().get("kar", null)
		# `Hotel.morgen()` zet `state.kar` op null en leegt de bakjes, maar de
		# kopie in het laatje bleef staan: de volgende ochtend zei het spel
		# "Alle bakjes vol!" terwijl elk bakje leeg was.  Een kar van een andere
		# dag telt niet meer.
		# ... behalve als er een vraag open stond met een misser: die komt
		# onveranderd terug, ook op een nieuwe dag (wave-2 regel R2)
		if typeof(bewaard) == TYPE_DICTIONARY \
				and int(bewaard.get("dag", -1)) != int(ctx.state.s["dag"]) \
				and int(bewaard.get("mis", 0)) <= 0:
			bewaard = null
	if typeof(bewaard) == TYPE_DICTIONARY and int(bewaard.get("T", 0)) > 0:
		K = _herstel(bewaard)
	else:
		var som := Sommen.deel(g.size(), ctx.state.band(), int(ctx.state.s["dag"]))
		K = {
			"T": int(som["T"]), "per": int(som["k"]), "rest": int(som["r"]),
			"op_kar": 0, "pot": 0, "stap": "som",
			"geleverd": {}, "missers": 0,
			"t0": Time.get_ticks_msec(), "dag": int(ctx.state.s["dag"]),
			"vraag": "",
		}
	_bewaar_kar()

## JSON kent geen gehele getallen: alles komt als komma-getal terug (state.gd
## laat `kar` bewust met rust).  Een stand van V2 of later draagt `stap` en
## `op_kar` zelf; een oude vul-stand wordt omgeteld: `vol: true` is het
## rondje, zonder `vol` was de beurt nog bij de som, en wat op de kar lag
## (`vak`) of nog in de zak zat gaat als lading van de kar mee (`op_kar`).
## Eén keer terugrekenen, dan telt de rest weer.
func _herstel(d: Dictionary) -> Dictionary:
	var stap := str(d.get("stap", ""))
	if stap != "som" and stap != "duwen":
		stap = "duwen" if bool(d.get("vol", false)) else "som"
	var op_kar := int(d.get("op_kar", -1))
	if op_kar < 0:
		var op := 0
		var vak = d.get("vak", {})
		if typeof(vak) == TYPE_DICTIONARY:
			for id in vak:
				op += int(vak[id])
		op_kar = op if stap == "duwen" else op + int(d.get("zak", 0))
	var uit := {
		"T": int(d.get("T", 0)), "per": maxi(1, int(d.get("per", 1))),
		"rest": int(d.get("rest", 0)),
		"op_kar": op_kar,
		"pot": int(d.get("pot", 0)),
		"stap": stap,
		"geleverd": {}, "missers": int(d.get("missers", 0)),
		"t0": int(d.get("t0", Time.get_ticks_msec())),
		# de kamer waar de som van het bakje open stond (2026-09-24); een oude
		# stand kent hem niet
		"vraag": str(d.get("vraag", "")) if d.get("vraag", null) is String else "",
		# wave 2: de open vraag ligt vast (getal en som), met haar missers
		"mis": int(d.get("mis", 0)),
		"pot_rest": int(d.get("pot_rest", 0)),
	}
	for sleutel in ["lading_goed", "vraag_goed"]:
		if d.has(sleutel):
			uit[sleutel] = int(d[sleutel])
	for sleutel in ["lading_som", "vraag_som"]:
		if d.has(sleutel):
			uit[sleutel] = str(d[sleutel])
	var geleverd = d.get("geleverd", {})
	if typeof(geleverd) == TYPE_DICTIONARY:
		for kamer in geleverd:
			uit["geleverd"][str(kamer)] = int(geleverd[kamer])
	# de tellerklok begint na een herlaad opnieuw bij nul
	if int(uit["t0"]) > Time.get_ticks_msec():
		uit["t0"] = Time.get_ticks_msec()
	return uit

## De stand hoort in `state.kar` (games-a.md §7.2); `ctx.data()` krijgt hetzelfde
## woordenboek, zodat het herstel via het spellaatje precies zo werkt.
func _bewaar_kar() -> void:
	if ctx == null or K.is_empty():
		return
	ctx.state.s["kar"] = K
	ctx.data()["kar"] = K
	State.bewaar()

# ------------------------------------------------------------- de opdracht

## Eén machineleesbare regel per stap, plus de plek van elke knop van dit spel:
## daarmee tikt de browserproef de beurt af zonder te gokken waar iets staat
## (architecture.md §14.4; de schil drukt zijn eigen knoppen maar twee keer af).
## Alleen in de browser, zodat de headless suite er niet mee volloopt.
func _meld_probe(fase: String) -> void:
	if not OS.has_feature("web") or K.is_empty():
		return
	if not await na(0.0):        # één beeld: de knoppen zijn dan geplaatst
		return
	if not await na(0.0) or K.is_empty():
		return
	if fase == "rondje":
		# waar de kar heen moet: de eerstvolgende deur op het pad, of het bakje
		# in deze kamer.  Dat weet het spel toch al; de proef hoeft niet te raden.
		var open := open_kamers()
		var nu := World.kamer_nu()
		var doel := str(open[0]["kamer"]) if not open.is_empty() else ""
		var deur := ""
		if not doel.is_empty() and doel != nu:
			var pad: Array = ctx.wereld.pad(nu, doel)
			if pad.size() > 1:
				deur = "deur_%s_%s" % [nu, str(pad[1])]
		print("[probe] vk volgende=", deur, " doel=", doel, " hier=", nu,
			" open=", open.size(), " mee=", _mee, " wijs=", wijs_deuren())
	print("[probe] vk ", fase, " T=", int(K["T"]), " per=", int(K["per"]),
		" rest=", int(K["rest"]), " op_kar=", int(K["op_kar"]),
		" pot=", int(K["pot"]), " stap=", str(K["stap"]),
		" missers=", int(K["missers"]),
		" geleverd=", (K["geleverd"] as Dictionary).size(),
		" band=", ctx.state.band(), " gasten=", deelnemers().size())
	for id in Hits.lijst():
		var s := Hits.spot(id)
		if s == null or not is_instance_valid(s.knoop) or not s.knoop.visible:
			continue
		if s.door == ctx.id:
			print("[probe] vk knop ", id, "=", (s.knoop as Control).get_global_rect(),
				" tekst=", str(s.knoop.text if "text" in s.knoop else "").replace("\n", " / "),
				" aantal=", (s.knoop as UiBron).aantal if s.knoop is UiBron else -1)
		elif fase == "rondje" and (id.begins_with("bak_") or id.begins_with("deur_")):
			# De knoppen van het hotel die tijdens het rondje van de kar zijn.
			# Het sleepdoel is het VOORWERP (de deuropening, het bakje), niet de
			# knop: daar ligt gegarandeerd geen andere knop overheen, dus daar
			# komt een sleep altijd aan.
			var vlak: Rect2 = Hits.debug().get(id, {}).get("vlak", Rect2())
			if vlak.size.x <= 0.0 or Ui.knoplaag == null:
				continue
			var laag := Ui.knoplaag.get_global_rect().position
			print("[probe] vk doel ", id, "=", Rect2(laag + vlak.position, vlak.size),
				" knop=", (s.knoop as Control).get_global_rect(),
				" drop=", s.drop, " val=", s.val.is_valid(),
				" geleend=", s.geleend_door)

## Eén kaartje: de opdracht in twee gewone zinnen.  In V2 hangt het nog
## alleen maar voor V3 aan de voerkast — het spel zelf speelt zich af in het
## rondje — maar de tekst en de somregel blijven zoals games-a.md §7.7 ze
## voorschrijft.
func _zinnen(n: int) -> Array:
	return [T_VERDEEL % [int(K["T"]), Ui.meervoud(n, "gast", "gasten")], T_IEDER]

func som_regel(n: int) -> String:
	return Sommen.Voerkar.som_regel(ctx.state.band(), int(K["T"]), n, int(K["rest"]))

func _kaart_neer(g: Array) -> void:
	var zin := _zinnen(g.size())
	var som := som_regel(g.size())
	# De kaart hángt op de voerkast (games-a.md §7.1), dus ze mag hem afdekken.
	# Daarom een kaal punt naast de kast in plaats van het voorwerp zelf: met de
	# kast als voorwerp houdt het bandenraster de kaart eraf, en in een liggend
	# kader (558 x 289) duwt die 92 eenheden hoge plaat de kaart tot onderin.
	var opts := {
		"id": "vk_kaart", "kamer": KAMER, "hoog": 30.0, "icoon": ICO_KOEK,
		"regel": zin[0], "regel2": zin[1], "pad": false, "prio": 14,
		"titel": "%s. %s" % [zin[0], zin[1]],
	}
	if not g.is_empty():
		# S5, open punt 2026-09-20: het dier van de beurt wordt doorgegeven,
		# zodat een misser sip wordt en niet alleen de strook pauzeert.  Voor
		# de voerkar is dit de plek; V3 laat de kaart hier weer in het spel
		# komen.
		opts["dier"] = str(g[0]["id"])
	_kaart = ctx.ui.somkaart(_kaart_punt(), som, opts)
	# `somkaart` tekent de somrij altijd en zet zonder strook een leeg
	# antwoordvakje neer; band 3 heeft geen somregel en er valt niets te typen.
	var kk := _kaart_knoop()
	if kk != null:
		if kk.som_label != null:
			kk.som_label.visible = not som.is_empty()
		if kk.vak_label != null:
			kk.vak_label.visible = false

## Het mikpunt van de kaart: vlak naast de voerkast, ver genoeg (meer dan
## `Hits.VLAK_NABIJ` = 2 voxels) om niet aan de kast te blijven plakken.
func _kaart_punt() -> Dictionary:
	var kast := World.mik("kast", KAMER)
	return {"x": float(kast.get("x", 33)) + 3.0, "z": float(kast.get("z", 6)) + 3.0}

func _kaart_knoop() -> UiSomkaart:
	var s := Hits.spot("vk_kaart")
	if s == null or not is_instance_valid(s.knoop):
		return null
	return s.knoop as UiSomkaart

func _dier_ico(g: Dictionary) -> String:
	if g.is_empty():
		return DIER_ONBEKEND
	if SOORT_ICO.has(str(g.get("soort", ""))):
		return SOORT_ICO[str(g.get("soort", ""))]
	if KIND_ICO.has(str(g.get("kind", ""))):
		return KIND_ICO[str(g.get("kind", ""))]
	return DIER_ONBEKEND

# -------------------------------------------------------------- het rondje

## Kamers met een meespelende gast én een bakje.
func kamers_met_gast() -> Array:
	var uit: Array = []
	var gezien := {}
	for g in deelnemers():
		var kamer := str(g.get("kamer", ""))
		if kamer.is_empty() or gezien.has(kamer):
			continue
		gezien[kamer] = 1
		for slot in ctx.wereld.slots(kamer, "bak"):
			uit.append({"kamer": kamer, "slot": str(slot.get("id", ""))})
			break
	return uit

func open_kamers() -> Array:
	var uit: Array = []
	for q in kamers_met_gast():
		if not (K["geleverd"] as Dictionary).has(str(q["kamer"])):
			uit.append(q)
	return uit

func _rondje() -> void:
	if not actief or K.is_empty():
		return
	if str(K.get("stap", "")) == "som":
		# de som van de kar: die kaart blijft staan zolang ze open is, zodat
		# een misser zijn pauze houdt en de strook haar volgorde
		_wis(true)
		_lading_kaart()
		ctx.wereld.vuil()
		_meld_probe("lading")
		return
	# de somkaart bij het bakje blijft staan zolang haar vraag hier open is: een
	# nieuw beeld van het hotel bouwt haar niet opnieuw op, dus een misser houdt
	# zijn pauze en de strook haar volgorde
	var vraag := _vraag_hier()
	_wis(vraag)
	var open := open_kamers()
	if open.is_empty():
		# Alles rond: niets meer om aan te tikken — geen kar-knop, geen geleende
		# deur of bakje — alleen het slotwolkje, en na 2,6 s gaat het spel dicht.
		# Een wolkje doet niets als je erop tikt (Ui.wolk = informatie).
		_mee = false
		ctx.ui.wolk({"id": ZEG, "kamer": World.kamer_nu(),
			"x": _kar_x(), "z": _kar_z(), "hoog": 22.0, "icoon": ICO_VOL,
			"tekst": T_ALLE_VOL, "klas": "goed", "prio": 12,
			"volg": _volg_kar(22.0)})
		_zeg_maat()
		_sluit_straks()
		ctx.wereld.vuil()
		_meld_probe("rondje")
		return
	_kar_getal(open.size())
	_zeg()
	if vraag:
		_bak_kaart()
	ctx.wereld.vuil()
	_meld_probe("rondje")

## Alles van dit spel weg, zoals `wis_alles()` — maar met `houd_kaart` blijven
## de somkaart van het bakje, haar strook en het wolkje van een misser staan.
## De geleende knoppen gaan in beide gevallen terug; `_leen_doelen` leent wat
## nu nodig is opnieuw.
func _wis(houd_kaart: bool) -> void:
	if not houd_kaart or (Hits.spot(KAART_BAK) == null and Hits.spot(KAART_KAR) == null):
		ctx.hotspots.wis_alles()
		_som_kaart = null
		_kaart = null
		return
	ctx.hotspots.laat()
	var houd := [KAART_BAK, KAART_BAK + "_keuzes", Ui.MIS_WOLK + KAART_BAK,
		KAART_KAR, KAART_KAR + "_keuzes", Ui.MIS_WOLK + KAART_KAR]
	for id in Hits.lijst().duplicate():
		var s := Hits.spot(id)
		if s != null and s.door == ctx.id and not houd.has(id):
			Hits.weg(id)

## Het wolkje bij de kar.  Sinds wave 2 is er niets meer om aan te tikken: de
## kar rijdt zelf en de somkaarten ZIJN de volgende stap, dus een opdracht
## ("Tik op de kar", "Tik op een deur", "Tik op het bakje") hoort er niet meer
## bij.  Alleen het slotwolkje (`T_ALLE_VOL`) en het smulwolkje blijven.  De
## oude zinnen staan nog als constante in dit bestand (games-a.md §7.7).
func _zeg() -> void:
	if not actief or K.is_empty():
		return
	ctx.ui.wolk_weg(ZEG)

## Op een liggend telefoonkader (740 x 360: 5 banden van 52, negen kolommen
## van 56) is een wolk van 55 hoog twee banden breed en ligt er geen vrij blok
## van vijf kolommen bij de kar: de deuren van de keuken en de kar zelf kruisen
## elke band die raakt.  Met het icoon op `icoon` in plaats van `icoon_wolk`
## wordt de bubbel ±51 hoog — één band — en past hij bovenin, waar alleen de
## wasserijdeur een kolom raakt.  Zonder deze maat staat het wolkje daar
## `krap` en dekt het het kozijn van de tuin (0 %-regel, architectuur §4.3).
func _zeg_maat(id := ZEG) -> void:
	var w := Hits.spot(id)
	if w != null and w.knoop is UiWolk:
		(w.knoop as UiWolk).icoon_label.add_theme_font_size_override(
			"font_size", int(Ui.maten.get("icoon", 23)))

## Smullen de dieren in de kamer die in beeld is?
func _smul_hier() -> bool:
	return not _smul_kamer.is_empty() and _smul_kamer == World.kamer_nu() \
		and Hits.spot("vk_smul") != null

## Het wolkje bij het bakje houdt het bakje vrij zoals het GETEKEND wordt.  De
## kamer tekent een bak met zijn anker `Art.KOM_ANKER` (scenes/kamer.gd), maar
## `Hits` meet de bakknop van het hotel zonder dat anker: zijn vlak ligt een
## flink stuk rechtsonder het bakje (op 1536 x 760 zo'n 88 x 70 eenheden).  Met
## dat vlak zou het wolkje het echte bakje afdekken; dit vlak klopt wel.  Elke
## plaatsing opnieuw, want de camera schuift na een deur nog even.
func _volg_bak(x: float, z: float, hoog: float) -> Callable:
	var kamer := World.kamer_nu()
	return func() -> Dictionary:
		return {"x": x, "z": z, "y": hoog, "kamer": kamer,
			"vlak": World.vlak_van("kom", x, z, 0.0, {}, Art.KOM_ANKER)}

## Het bak-slot van de open kamer waar de kar nu staat, of {}.
func _bak_hier() -> Dictionary:
	var nu := World.kamer_nu()
	for q in open_kamers():
		if str(q["kamer"]) == nu:
			return ctx.wereld.slot(nu, str(q["slot"]))
	return {}

## Staat de kar in beeld in een kamer die nog koekjes krijgt?
func _kar_bij_honger() -> bool:
	var nu := World.kamer_nu()
	if str(ctx.wereld.ding("kar").get("kamer", "")) != nu:
		return false
	for q in open_kamers():
		if str(q["kamer"]) == nu:
			return true
	return false

## De deuren van deze kamer die op weg zijn naar een kamer waar nog iemand op
## zijn koekjes wacht: de eerste stap van het kortste pad naar elke open kamer,
## als kamer-id's.  Leeg als die kamer hier is — dan is het bakje het doel.
func wijs_deuren() -> Array:
	var uit: Array = []
	if K.is_empty() or _kar_bij_honger():
		return uit
	var nu := World.kamer_nu()
	for q in open_kamers():
		var pad: Array = ctx.wereld.pad(nu, str(q["kamer"]))
		if pad.size() > 1 and not uit.has(str(pad[1])):
			uit.append(str(pad[1]))
	return uit

func _kar_x() -> float:
	return float(ctx.wereld.ding("kar").get("x", 48.0))

func _kar_z() -> float:
	return float(ctx.wereld.ding("kar").get("z", 66.0))

func _volg_kar(hoog: float = 16.0) -> Callable:
	return func() -> Dictionary:
		var q := World.ding("kar")
		if q.is_empty():
			return {}
		return {"x": float(q["x"]), "z": float(q["z"]), "y": hoog,
			"kamer": str(q["kamer"]),
			"vlak": World.vlak_van(str(q["model"]), float(q["x"]), float(q["z"]), 0.0)}

## Het getal óp de kar: zoveel koekjes liggen er nog op (een kaal cijfer,
## world.md §5.6).  Sinds wave 2 is de kar geen knop meer: hij rijdt zelf.
func _kar_getal(open_n: int) -> void:
	var kar: Dictionary = ctx.wereld.ding("kar")
	if kar.is_empty():
		return
	var woord := T_KAMER if open_n == 1 else T_KAMERS
	ctx.ui.getal_tag({"x": float(kar["x"]), "z": float(kar["z"])}, int(K["op_kar"]), {
		"id": KAR_TAG, "kamer": str(kar["kamer"]), "y": 16.0,
		"titel": T_KAR_TITEL % [open_n, woord], "volg": _volg_kar(16.0)})

## De som van de kar, in de keuken bij de kar: hoeveel koekjes gaan erop?
## Elke meespelende gast krijgt `per`; de som is die van het bakje (`bak_som`)
## voor alle gasten samen.  Getal en som liggen vast in de stand zodra ze
## gevraagd zijn, zodat een herlaad of een andere dag dezelfde vraag terugzet.
func _lading_kaart() -> void:
	if Hits.spot(KAART_KAR) != null and _kaart != null:
		return
	var n := deelnemers().size()
	var per := int(K["per"])
	if not K.has("lading_goed"):
		K["lading_goed"] = per * n
		K["lading_som"] = bak_som(n)
		_bewaar_kar()
	var goed := int(K["lading_goed"])
	var kar: Dictionary = ctx.wereld.ding("kar")
	var plek := {"x": float(kar.get("x", 48.0)), "z": float(kar.get("z", 66.0))}
	_kaart = ctx.ui.somkaart(plek, str(K["lading_som"]), {
		"id": KAART_KAR, "kamer": str(kar.get("kamer", KAMER)), "hoog": 22.0,
		"icoon": ICO_KOEK, "regel": T_LADING,
		"regel2": T_ELK % Ui.meervoud(per, "koekje", "koekjes"),
		"titel": T_LADING_TITEL, "keuze_titel": T_SOM_KIES,
		"goed": goed, "liever": [goed + per, maxi(1, goed - per), goed + 1], "min": 1,
		"max": 3 if goed > 99 else 2, "prio": 14, "dier": "",
		"on_ok": _op_lading,
	})
	_meld_probe("lading")

## Het antwoord op de som van de kar.  Goed: dat is de lading, en de kar rijdt
## naar de eerste kamer met honger.  Fout: alleen de misser (de strook deed
## `Ui.misser` al), dezelfde vraag blijft staan.
func _op_lading(n, kaart) -> void:
	if not actief or K.is_empty() or n == null or str(K.get("stap", "")) != "som":
		return
	if int(n) != int(K.get("lading_goed", -1)):
		K["missers"] = int(K["missers"]) + 1
		K["mis"] = int(K.get("mis", 0)) + 1
		ctx.snd.zacht()
		_bewaar_kar()
		ctx.ui.misser(kaart, "")
		_meld_probe("mis")
		return
	K["mis"] = 0
	K["op_kar"] = int(n)
	K["pot_rest"] = int(K["rest"])
	K["stap"] = "duwen"
	_bewaar_kar()
	ctx.snd.ja()
	ctx.hotspots.weg(KAART_KAR)
	ctx.hotspots.weg(KAART_KAR + "_keuzes")
	_kaart = null
	_rondje()
	_rijd_verder()

## De kar rijdt zelf (wave 2): kamer voor kamer langs het kortste pad naar de
## dichtstbijzijnde kamer waar nog iemand op zijn koekjes wacht, de camera
## mee, en daar gaat de som van het bakje vanzelf open.  Eén rit tegelijk.
func _rijd_verder() -> void:
	if _rijdt or K.is_empty():
		return
	_rijdt = true
	_reis_nr += 1
	var mijn := _reis_nr
	var stappen := 0
	while actief and not K.is_empty() and str(K.get("stap", "")) == "duwen" and stappen < 12:
		var open := open_kamers()
		if open.is_empty():
			break
		var nu := str(ctx.wereld.ding("kar").get("kamer", KAMER))
		if _is_open(nu):
			if World.kamer_nu() != nu:
				_zet_kar_in(nu)
			vraag_bak(nu)
			break
		var pad: Array = []
		for q in open:
			var p: Array = ctx.wereld.pad(nu, str(q["kamer"]))
			if p.size() > 1 and (pad.is_empty() or p.size() < pad.size()):
				pad = p
		var naar := str(pad[1]) if pad.size() > 1 else str(open[0]["kamer"])
		ctx.snd.kar()
		_zet_kar_in(naar)
		_rondje()
		stappen += 1
		if not await na(REIS_RUST_S if ctx.wereld.rust() else REIS_S):
			break
		if mijn != _reis_nr:
			break
	if mijn == _reis_nr:
		_rijdt = false

## De kar door een deur duwen: hij verhuist naar die kamer, de camera gaat mee,
## en wie duwt heeft de kar vast — ook in de volgende kamer.
func duw_naar(kamer_id: String) -> void:
	if kamer_id.is_empty() or not Rooms.bestaat(kamer_id) or K.is_empty():
		return
	# wie de kar zelf duwt neemt de rit over: een lopende rit stopt
	_reis_nr += 1
	_rijdt = false
	_mee = true
	_ooit_mee = true
	# wie met de kar een kamer uit gaat laat de som van dat bakje staan; komt de
	# kar daar weer, dan komt dezelfde vraag terug — en een vraag met een
	# misser blijft liggen tot hij goed beantwoord is (wave-2 regel R2)
	if not str(K.get("vraag", "")).is_empty() and str(K["vraag"]) != kamer_id \
			and int(K.get("mis", 0)) <= 0:
		K["vraag"] = ""
		K.erase("vraag_goed")
		K.erase("vraag_som")
		_bewaar_kar()
	ctx.snd.kar()
	_zet_kar_in(kamer_id)
	_rondje()

## De kar en de camera in die kamer, naast het bakje; het hotel tekent zijn
## knoppen daar opnieuw (dan kan `_leen_doelen` ze lenen).
func _zet_kar_in(kamer_id: String) -> void:
	var plek := _kar_plek(kamer_id)
	ctx.wereld.ding_zet("kar", {"kamer": kamer_id, "x": plek.x, "z": plek.y})
	ctx.wereld.naar(kamer_id)
	ctx.state.s["kamerNu"] = kamer_id
	Hotel.render()

## Waar de kar in die kamer komt te staan: naast het bakje, anders midden in de
## kamer.  (De HTML liet hem op de keukenplek staan, ook als die in een muur van
## de nieuwe kamer viel.)
func _kar_plek(kamer_id: String) -> Vector2:
	var r := Rooms.get_kamer(kamer_id)
	if r == null:
		return Vector2(12.0, 12.0)
	var doel := Vector2(r.w * 0.5, r.d * 0.5)
	for slot in ctx.wereld.slots(kamer_id, "bak"):
		var sx := float(slot.get("sx", slot.get("x", doel.x)))
		var sz := float(slot.get("sz", slot.get("z", doel.y)))
		var mid := Vector2(float(slot.get("x", sx)), float(slot.get("z", sz)))
		# De kar staat schuin voor het bakje — maar niet waar de gasten zo met
		# hun snuit in het bakje gaan eten (`ETEN_SNUIT`, 2026-09-24): op de
		# oude plek stond hij op de plekjes aan de −x-kant, en daar aten ze dan
		# naast het bakje.  De eerste plek die dat vrij laat en zelf vrije vloer
		# is; anders de oude.
		var kandidaten: Array = [Vector2(sx - 14.0, sz + 10.0), Vector2(sx - 18.0, sz + 20.0),
			Vector2(sx - 14.0, sz + 28.0), Vector2(sx - 30.0, sz + 10.0)]
		for k in kandidaten:
			var p := _binnen(r, k)
			if Rooms.vrij_vak(kamer_id, p.x, p.y) and _kar_laat_eten(p, mid):
				return p
		return _binnen(r, kandidaten[0])
	return _binnen(r, doel)

func _binnen(r: Rooms.Kamer, p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 8.0, r.w - 8.0), clampf(p.y, 8.0, r.d - 8.0))

## Laat een kar op `p` elke snuitplek rond het bakje op `mid` vrij?
func _kar_laat_eten(p: Vector2, mid: Vector2) -> bool:
	var voet := KAR_VOET.grow(KAR_RAND)
	voet.position += p
	for set in ETEN_SNUIT:
		for off in set:
			if voet.has_point(mid + (off as Vector2)):
				return false
	return true

# --------------------------------------------------- de som bij het bakje

## De meespelende gasten die in deze kamer hun bed hebben, in vaste volgorde.
func _gasten_in(kamer_id: String) -> Array:
	var uit: Array = []
	for g in deelnemers():
		if str(g.get("kamer", "")) == kamer_id:
			uit.append(g)
	return uit

## Het bak-slot van deze kamer, of "".
func _bak_slot(kamer_id: String) -> String:
	for slot in ctx.wereld.slots(kamer_id, "bak"):
		return str(slot.get("id", ""))
	return ""

## Wacht er in deze kamer nog iemand op zijn koekjes?
func _is_open(kamer_id: String) -> bool:
	for q in open_kamers():
		if str(q["kamer"]) == kamer_id:
			return true
	return false

## Staat de som van het bakje open in de kamer die in beeld is, met de kar erbij?
func _vraag_hier() -> bool:
	if K.is_empty():
		return false
	var kamer := str(K.get("vraag", ""))
	return not kamer.is_empty() and kamer == World.kamer_nu() and _kar_bij_honger()

## Het goede antwoord: zoveel gasten in deze kamer, `per` koekjes elk.
func bak_goed(kamer_id: String) -> int:
	return int(K["per"]) * _gasten_in(kamer_id).size()

## De somregel van het bakje voor `n` gasten.  Een keersom alleen waar de band
## die tafel kent (`Sommen.TAFEL_SET`, de tafel van het getal per gast: `2 × 4`
## is twee keer vier); groep 3 kent de keersom nog niet en krijgt de herhaalde
## optelling (`4 + 4 =`); één gast is alleen het getal (`4 =`).
func bak_som(n: int) -> String:
	var per := int(K["per"])
	if n <= 1:
		return "%d =" % per
	var band := clampi(ctx.state.band(), 3, 5)
	var tafels: Array = Sommen.TAFEL_SET.get(band, [])
	if band >= 4 and tafels.has(per) and n <= 10:
		return "%d × %d =" % [n, per]
	var delen := PackedStringArray()
	for _i in n:
		delen.append(str(per))
	return " + ".join(delen) + " ="

## Het dier van de beurt voor de kaart (S5): de eerste gast van deze kamer die
## er ook echt is, zodat een misser in beeld sip wordt.
func _bak_dier(kamer_id: String) -> String:
	var hier := _gasten_in(kamer_id)
	for g in hier:
		var d = World.dier(str(g["id"]))
		if d != null and str(d.kamer) == kamer_id:
			return str(g["id"])
	return "" if hier.is_empty() else str(hier[0]["id"])

## Tik op het bakje (of de kar erop gesleept): de som van dit bakje gaat open.
## Alleen waar vullen nu kan — de kar staat in die kamer en daar wacht nog
## iemand — anders gebeurt er niets (daar is het bakje ook geen knop).
func vraag_bak(kamer_id: String, _slot_id: String = "") -> bool:
	if not actief or K.is_empty() or kamer_id.is_empty():
		return false
	var kar: Dictionary = ctx.wereld.ding("kar")
	if kar.is_empty() or str(kar.get("kamer", "")) != kamer_id or not _is_open(kamer_id):
		return false
	if str(K.get("vraag", "")) == kamer_id and Hits.spot(KAART_BAK) != null:
		return true
	if str(K.get("vraag", "")) != kamer_id or not K.has("vraag_goed"):
		# een nieuwe vraag: getal en som liggen vanaf nu vast, zodat dezelfde
		# vraag terugkomt, ook als er intussen een gast bij kwam of de band
		# veranderde (wave-2 regel R2)
		K["vraag_goed"] = bak_goed(kamer_id)
		K["vraag_som"] = bak_som(_gasten_in(kamer_id).size())
	K["vraag"] = kamer_id
	_bewaar_kar()
	ctx.snd.tik()
	_rondje()
	return true

## De somkaart bij het bakje: 🍪 "Hoeveel koekjes gaan in het bakje?", "Elke
## gast krijgt 4 koekjes", de somregel en een strook van vier getallen.  Staat
## ze er al, dan blijft ze staan zoals ze is.
func _bak_kaart() -> void:
	var kamer := str(K.get("vraag", ""))
	var slot := _bak_slot(kamer)
	var hier := _gasten_in(kamer)
	if slot.is_empty() or hier.is_empty():
		return
	if Hits.spot(KAART_BAK) != null and _som_kaart != null:
		return
	var bak: Dictionary = ctx.wereld.slot(kamer, slot)
	var per := int(K["per"])
	var goed := int(K.get("vraag_goed", bak_goed(kamer)))
	_som_kaart = ctx.ui.somkaart(
		{"x": float(bak.get("x", 0.0)), "z": float(bak.get("z", 0.0))},
		str(K.get("vraag_som", bak_som(hier.size()))), {
		"id": KAART_BAK, "kamer": kamer, "hoog": 20.0, "icoon": ICO_KOEK,
		"regel": T_HOEVEEL, "regel2": T_ELK % Ui.meervoud(per, "koekje", "koekjes"),
		"titel": T_SOM_TITEL, "keuze_titel": T_SOM_KIES,
		"goed": goed, "liever": [goed + per, goed - per, goed + 1], "min": 1,
		"max": 3 if goed > 99 else 2, "prio": 14,
		"dier": _bak_dier(kamer), "on_ok": _op_bak_som,
	})
	_meld_probe("som")

## Het antwoord op de som van het bakje.  Goed → het bakje gaat vol (`lever`).
## Fout → alleen de misser (eigenaar 2026-09-24: geen hulp na een fout): de
## strook heeft `Ui.misser` al gedaan — `sip`, `🔄 Nog een keer`, even op slot —,
## hier telt de misser voor het adaptieve signaal, klinkt het zachte geluid en
## loopt het dier van de beurt teleurgesteld naar zijn lege bakje.  Het bakje
## blijft leeg en dezelfde vraag blijft staan.
func _op_bak_som(n, kaart) -> void:
	if not actief or K.is_empty() or n == null:
		return
	var kamer := str(K.get("vraag", ""))
	if kamer.is_empty():
		return
	if int(n) != int(K.get("vraag_goed", bak_goed(kamer))):
		K["missers"] = int(K["missers"]) + 1
		K["mis"] = int(K.get("mis", 0)) + 1
		ctx.snd.zacht()
		_bewaar_kar()
		var dier := _bak_dier(kamer)
		ctx.ui.misser(kaart, dier)          # de strook deed hem al: dan niets
		_sip_bij_bak(kamer, dier)
		_meld_probe("mis")
		return
	ctx.snd.ja()
	lever(kamer, _bak_slot(kamer))

## Het dier van de beurt staat op en loopt naar zijn eigen plekje bij het lege
## bakje, en is daar sip (liever dan sip in zijn bed te staan).
func _sip_bij_bak(kamer_id: String, dier: String) -> void:
	var d = World.dier(dier)
	if d == null or str(d.kamer) != kamer_id:
		return
	var hier := _gasten_in(kamer_id)
	var plekken := eet_plekken(kamer_id, _bak_slot(kamer_id), hier.size())
	var i := 0
	for j in hier.size():
		if str(hier[j]["id"]) == dier:
			i = j
	if i >= plekken.size():
		return
	var p: Vector2 = plekken[i]
	ctx.wereld.ga(dier, p.x, p.y, "sip")

# ------------------------------------------------- eten bij het bakje

## De plekjes waar `n` gasten bij het bakje eten: vrije vloer
## (`Rooms.vrij_vak`) en niet onder de kar.  Eerst de snuitplekken
## (`ETEN_SNUIT`: de neus in het bakje, zij aan zij `ETEN_SNUIT_AF` uit
## elkaar), dan voor wie overblijft de ring naast het bakje (minstens `ETEN_AF`
## uit elkaar en niet tussen een eter en het bakje), een tweede ring; is een
## kamer echt vol, dan de staplek van het bakje zelf, een stapje uit elkaar —
## nooit te weinig plekjes.
func eet_plekken(kamer_id: String, slot_id: String, n: int) -> Array:
	var uit: Array = []
	var bak: Dictionary = ctx.wereld.slot(kamer_id, slot_id)
	if bak.is_empty() or n <= 0:
		return uit
	var mid := Vector2(float(bak.get("x", 0.0)), float(bak.get("z", 0.0)))
	# eerst de snuitplekken: de grootste set die helemaal vrij is en niet meer
	# eters vraagt dan er zijn
	for set in ETEN_SNUIT:
		if (set as Array).size() > n:
			continue
		var vrij := true
		for off in set:
			var p: Vector2 = mid + (off as Vector2)
			if not Rooms.vrij_vak(kamer_id, p.x, p.y) or _onder_kar(kamer_id, p):
				vrij = false
				break
		if vrij:
			for off in set:
				uit.append(mid + (off as Vector2))
			break
	var snuit := uit.size()
	for off in _eet_kandidaten():
		if uit.size() >= n:
			return uit
		var p: Vector2 = mid + (off as Vector2)
		if not Rooms.vrij_vak(kamer_id, p.x, p.y) or _onder_kar(kamer_id, p):
			continue
		var ver := true
		for q in uit:
			if (q as Vector2).distance_to(p) < ETEN_AF:
				ver = false
				break
		# en niet in de weg van wie met zijn snuit in het bakje staat: niet
		# tussen hem en het bakje
		if ver and snuit > 0 and p.distance_to(mid) < ETEN_VOOR + 1.0:
			ver = false
		if ver:
			uit.append(p)
	var staan := Vector2(float(bak.get("sx", mid.x - 13.0)), float(bak.get("sz", mid.y)))
	while uit.size() < n:
		uit.append(staan + Vector2(0.0, 5.0 * float(uit.size() % 3)))
	return uit

## De plekjes rond een bakje in volgorde van voorkeur, als afstand tot het
## bakje: de vaste lijst vlak ernaast, dan de ring op `ETEN_RING` (om de 30°,
## wat achter het bakje ligt eerst), dan de vaste lijst op 1,6 keer.
func _eet_kandidaten() -> Array:
	var uit: Array = ETEN_PLEK.duplicate()
	var ring: Array = []
	for i in 12:
		ring.append(Vector2.from_angle(deg_to_rad(15.0 + 30.0 * i)) * ETEN_RING)
	ring.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x + a.y < b.x + b.y)
	uit.append_array(ring)
	for off in ETEN_PLEK:
		uit.append((off as Vector2) * ETEN_RING2)
	return uit

## Staat (x, z) op of vlak naast de kar?
func _onder_kar(kamer_id: String, p: Vector2) -> bool:
	var kar: Dictionary = ctx.wereld.ding("kar")
	if kar.is_empty() or str(kar.get("kamer", "")) != kamer_id:
		return false
	var voet := KAR_VOET.grow(KAR_RAND)
	voet.position += Vector2(float(kar.get("x", 0.0)), float(kar.get("z", 0.0)))
	return voet.has_point(p)

## Iedereen van deze kamer uit bed, naar zijn plekje naast het bakje, en eten
## (`World.eet_bij`: met het gezicht naar het bakje; in rustmodus meteen).
func _eet_bij_bak(kamer_id: String, slot_id: String, hier: Array) -> void:
	var bak: Dictionary = ctx.wereld.slot(kamer_id, slot_id)
	var mid := Vector2(float(bak.get("x", 0.0)), float(bak.get("z", 0.0)))
	var plekken := eet_plekken(kamer_id, slot_id, hier.size())
	for i in mini(hier.size(), plekken.size()):
		var p: Vector2 = plekken[i]
		ctx.wereld.eet_bij(str(hier[i]["id"]), kamer_id, p.x, p.y, mid)

## Het bakje vullen — het goede antwoord op de som van het bakje: wat de
## gasten in die kamer moeten hebben gaat erin, en elke gast van die kamer
## staat op, loopt naar een plekje naast het bakje en eet daar (niet meer in
## zijn bed, eigenaar 2026-09-24).  De kar draagt de hele lading (`op_kar`);
## bij de laatste levering gaat wat hij over heeft in de snoeppot — dat is de
## `rest` van de deling — en daar sluit de lus: één ster voor het meedoen en
## de band wordt gevoed zoals altijd.
##
## Staat de kar er niet, dan gebeurt er niets: daar is het bakje ook geen knop
## (`_leen_doelen`), dus een kind kan hier alleen met een oude sleep komen.
func lever(kamer_id: String, slot_id: String) -> bool:
	if K.is_empty() or kamer_id.is_empty():
		return false
	var kar: Dictionary = ctx.wereld.ding("kar")
	if kar.is_empty() or str(kar.get("kamer", "")) != kamer_id:
		return false
	var hier: Array = []
	for g in deelnemers():
		if str(g.get("kamer", "")) == kamer_id:
			hier.append(g)
	if hier.is_empty() or (K["geleverd"] as Dictionary).has(kamer_id):
		return false
	# de som van dit bakje is beantwoord: de kaart gaat met het volgende beeld weg
	K["vraag"] = ""
	K["mis"] = 0
	K.erase("vraag_goed")
	K.erase("vraag_som")
	var samen := mini(int(K["per"]) * hier.size(), int(K["op_kar"]))
	K["op_kar"] = int(K["op_kar"]) - samen
	for g in hier:
		g["gegeten"] = true
		g["behoefte"] = "spelen"
		g["blij"] = false
	K["geleverd"][kamer_id] = samen
	ctx.wereld.set_bak(kamer_id, slot_id, 4)
	_eet_bij_bak(kamer_id, slot_id, hier)
	ctx.snd.plop(3)
	_bewaar_kar()
	# het smulwolkje komt zo; tot het weg is wacht het wolkje van de kar
	_smul_kamer = kamer_id
	_smul_nr += 1
	var nr := _smul_nr
	Hotel.render()
	_rondje()
	# every bowl in the hotel is full: the loop closes here — the rest of the
	# trolley goes into the candy jar, the turn is counted, sparkles and a cheer
	if open_kamers().is_empty():
		# wat de kar over heeft en de rest van de bakkerij (`pot_rest`, sinds
		# wave 2 niet meer op de kar: de lading is het antwoord van het kind)
		ctx.state.s["snoeppot"] = int(ctx.state.s["snoeppot"]) + int(K["op_kar"]) \
			+ int(K.get("pot_rest", 0))
		ctx.state.tel(int(K["missers"]) == 0, Time.get_ticks_msec() - int(K["t0"]))
		ctx.taak_klaar("voer", {"sterren": 1})
		var sl2: Dictionary = ctx.wereld.slot(kamer_id, slot_id)
		ctx.wereld.spetter(kamer_id, float(sl2.get("x", 0.0)), float(sl2.get("z", 0.0)),
			ArtEffect.STER_N * 3, ArtEffect.STER_KL[0], true, 6.0)
		ctx.snd.hoera()
	# ná _rondje(), want dat begint met wis_alles() en zou dit wolkje meteen
	# weer weghalen (games-a.md §7.6)
	ctx.ui.wolk({"id": "vk_smul", "kamer": kamer_id, "hoog": 54.0,
		"icoon": ICO_SMUL, "getal": int(K["per"]),
		"tekst": T_KOEKJES_ELK if hier.size() > 1 else T_KOEKJES,
		"klas": "goed", "prio": 10, "volg": _volg_dier(str(hier[0]["id"]), 54.0)})
	# dezelfde maat als het wolkje van de kar: één band hoog, anders vindt het
	# op 740 x 360 in een volle slaapkamer geen plek (`krap`).  Prio 10, onder de
	# kar (11): de knop die iets doet kiest zijn plek eerst, het wolkje dat
	# alleen vertelt schuift op.
	_zeg_maat("vk_smul")
	if not open_kamers().is_empty():
		ctx.ui.wolk_weg(ZEG)
	_smul_weg(nr)
	ctx.wereld.vuil()
	return true

func _volg_dier(id: String, hoog: float) -> Callable:
	return func() -> Dictionary:
		var d = World.dier(id)
		if d == null:
			return {}
		return {"x": d.x, "z": d.z, "y": hoog, "kamer": d.kamer,
			"vlak": World.vlak_van_dier(id)}

## Na 2,6 s is het smullen gezien: het wolkje gaat weg en het wolkje van de kar
## komt terug met de volgende stap.  Alleen het wachtje van de laatste levering
## ruimt op.
func _smul_weg(nr: int) -> void:
	if not await na(SMUL_MS):
		return
	if nr != _smul_nr:
		return
	var kamer := _smul_kamer
	_smul_kamer = ""
	ctx.ui.wolk_weg("vk_smul")
	if not K.is_empty() and not open_kamers().is_empty():
		_zeg()
		_rijd_na_eten(kamer, nr)  # en de kar rijdt zelf naar de volgende kamer
	ctx.wereld.vuil()

## De kar rijdt door zodra de eters van `kamer` bij het bakje staan (niemand
## loopt meer), hoogstens na `ETEN_WACHT_S`: anders ging de camera weg terwijl
## ze nog naar hun bakje liepen.
func _rijd_na_eten(kamer: String, nr: int) -> void:
	var t := 0.0
	while actief and not K.is_empty() and t < ETEN_WACHT_S:
		var loopt := false
		for g in _gasten_in(kamer):
			var d = World.dier(str(g["id"]))
			if d != null and str(d.staat) == "loop":
				loopt = true
		if not loopt:
			break
		if not await na(0.25):
			return
		t += 0.25
	if nr != _smul_nr or not actief or K.is_empty() or open_kamers().is_empty():
		return
	_rijd_verder()

func _sluit_straks() -> void:
	if _sluit_bezig:
		return
	_sluit_bezig = true
	var door := await na(SMUL_MS)
	_sluit_bezig = false
	if not door or K.is_empty() or str(K.get("stap", "")) != "duwen":
		return
	_klaar_met_rondje()

## Het rondje is uit: de stand gaat weg en de kar rijdt terug naar de keuken —
## zonder de camera mee te nemen, want het kind kijkt nog naar de kamer waar het
## laatste bakje net vol ging.
func _klaar_met_rondje(_s = null) -> void:
	if ctx == null:
		return
	ctx.state.s["kar"] = null
	ctx.data().erase("kar")
	K = {}
	State.bewaar()
	ctx.ui.wolk_weg(ZEG)
	ctx.wereld.ding_thuis_zet("kar")
	ctx.sluit()
