extends MiniGame
## meubels — HET MEUBELBOEK (games-a.md §5, architecture.md §12.2 row 3).
##
## De groeilus van het hotel: rekenen -> inrichten -> meer gasten.  Er is geen
## gast in dit spel; het speelt bij de balie van de receptie en daarna in de
## kamer die je zelf kiest.
##
## Drie bladzijden:
##   1  het OVERZICHT — het enige paneel dat HOTEL.md §9 toestaat: alleen
##      pictogrammen en prijzen, geen zinnen (`Ui.blad_open`);
##   2  AFREKENEN — helemaal in de wereld: de som op de kassa, je munten als
##      sleepbron op de buidel, het bedrag op de toonbank;
##   3  NEERZETTEN — uit de doos naar een ✨-vakje op de voxelvloer, in welke
##      kamer je maar wil.
##
## Alle getallen komen uit `Sommen.Meubels` en `Sommen.buidel/splits`
## (architecture.md §1.1 F1); dit bestand rekent zelf niets uit dat daar staat.
##
## Twee afwijkingen van de HTML, allebei omdat Godot iets anders biedt dan de
## DOM, en allebei bewust (zie het rapport bij dit ticket):
##  * `Ui.blad_open` is MODAAL — de HTML had een zijpaneel naast de wereld.  De
##    knopjes van §5.8 (🔄 draaien / 📦 oppakken) staan daarom op de wereldpagina
##    van dit spel: leg je het boek even neer (tik naast het blad), dan staan ze
##    naast je eigen meubels en brengt `📖 Boek` je terug.
##  * Slepen naar een DEUR bestaat niet meer.  Godots sleepcontract vergelijkt
##    één naam (`_can_drop_data`), dus een lading past bij één soort doel; de
##    deurknoppen van het hotel blijven gewoon staan en één tik loopt de doos
##    achter je aan (`volg`).

const MODELLEN := preload("res://games/meubels/modellen.gd")

# --------------------------------------------------------- alle kinderteksten
# games-a.md §5.9, letterlijk (architecture.md §1.1 F3).
const T_TITEL := "📖 Meubelboek"
const T_MEUBELS := "Meubels"
const T_VERSIERING := "Versiering met sterren"
const T_AFREKENEN := "Afrekenen"
const T_LIJST_LEEG := "Lijstje leeg"
const T_BOEK_DICHT := "Boek dicht"
const T_GENOEG := "is genoeg"
## De openingsvraag bij de kassa (PLAN.md §3.8 `N6`, open vraag V4): elke beurt
## begint met tellen, in de wereld, vóór het winkelblad.
const T_HOEVEEL := "Hoeveel euro heb je?"
const T_GEEN_MUNTEN := "Nog geen munten"
const T_OP_TAFEL := "je munten op de toonbank"
const T_BUIDEL := "je buidel: %d munten"
const T_SAMEN := "Hoeveel euro is dat samen?"
const T_TERUG_VRAAG := "Hoeveel krijg je terug?"
const T_LEG_MUNTEN := "Leg de 🪙 munten op de toonbank"
const T_TIK_GETAL := "tik een getal"
const T_KLAAR_TELLEN := "klaar met tellen"
const T_MUNT_TERUG := "een munt terugpakken"
const T_TERUG_BOEK := "terug naar het meubelboek"
const T_SPOOK_SAMEN := "zoveel is het samen"
const T_SPOOK_WISSEL := "zoveel krijg je terug"
const T_SPOOK_BIJ := "dit moet er nog bij"
const T_SPOOK_MOET := "zoveel moet het zijn"
const T_SPOOK_UIT := "zo ziet het uit"
const T_SPOOK_ZOVEEL := "zoveel is het"
const T_TERUG := "terug"
const T_BETAALD := "betaald"
const T_SLEEP := "sleep naar een plekje"
const T_HIER := "hier neerzetten"
const T_MEER := "meer plekjes"
const T_BEZET := "bezet"
const T_GASTEN := "gasten"
const T_SLAAPT := "iemand slaapt"
const T_DRAAIEN := "bed draaien"
## architecture.md §13 Q-X2-8/Q-X2-9: de wachtrij is op drie gemaximeerd en een
## vierde verzoek krijgt dit antwoord.
const T_EERST := "leg eerst iets neer"
const WACHT_MAX := 3

## De woorden naast de pictogrammen op de knoppen in de wereld.  HOTEL.md §9:
## "een pictogram staat altijd in hetzelfde wolkje als zijn woord of getal";
## de HTML kon met een aria-label toe, een Godot-knop draagt zijn woord echt.
## Elk woord komt uit de zin van §5.9 waar de knop bij hoort.
## Twee tekens uit de HTML zitten NIET in de gebundelde subset (gemeten met
## `Ui.mist_tekens`, zie `test_elk_pictogram_zit_in_het_lettertype`): U+FF0B
## (de brede plus) en U+21A9 (de terugpijl).  Op een echte export werden het
## tofu-blokjes.  Het meubelboek gebruikt daarom de gewone `+` en de chevron
## `«`, die het lettertype wel kent en die de spiegeling is van de `▸` van de
## schil.
const W_HIER := "Hier"
const W_MEER := "Meer"
const W_KLAAR := "Klaar"
const W_TERUG := "Terug"
const W_BOEK := "Boek"
const W_DRAAIEN := "Draaien"
const W_OPPAKKEN := "Oppakken"

const VAK_MAX := 4          ## hooguit vier ✨-vakjes tegelijk in beeld
const VAK_AF := 24          ## en die liggen minstens 24 voxels uit elkaar
const MUNTSOORT := [1, 2, 5, 10]

# ------------------------------------------------------------------- de stand
var _view := "boek"          ## kassa | boek | wereld | betaal | plaats
var _tab := "meubels"        ## meubels | versiering
var _lijst: Array[String] = []
var _spaar: Dictionary = {}  ## {icoon, nodig, heb} — de spaarchip boven het blad
var _bet: Dictionary = {}    ## de afrekening; leeg = er wordt niet betaald
var _kas: Dictionary = {}    ## de buidelvraag; leeg = er wordt niet geteld
var _thuis := "kamer1"       ## de kamer waar je inricht
var _vak_offset := 0
var _blad_stil := false      ## een blad dat IK dichtdoe mag geen view omzetten
var _verbonden := false
var _t0 := 0

# =============================================================== registratie

func definitie() -> Dictionary:
	return {
		"naam": "Het meubelboek",
		"kamer": "receptie",
		"hotspot": {"obj": "boek", "icoon": "📖", "label": "Boek", "hoog": 16},
		# Vanaf drie gasten: dan zijn er munten uit het uitchecken en is er ook
		# een reden om bij te bouwen (games-a.md §1.1).
		"unlock": func(n: int, _band: int) -> bool: return n >= 3,
		"stub": false,
		"taak": {"id": "meubels", "icoon": "📖", "tekst": "Koop iets moois",
			"kamer": "receptie", "prio": 5,
			"wanneer": func(s: Dictionary) -> bool: return int(s.get("munten", 0)) >= 5},
	}

# ============================================================== levenscyclus

func start(_c: SpelCtx) -> void:
	Art.registreer_model("meubels_toonbank", Callable(MODELLEN, "toonbank"))
	Art.registreer_model("meubels_buidel", Callable(MODELLEN, "buidel"))
	var q := _q()
	_view = "boek"
	_tab = "meubels"
	_lijst = []
	_spaar = {}
	_bet = {}
	_kas = {}
	_vak_offset = 0
	_thuis = ctx.wereld.actief()
	if _thuis.is_empty() or _thuis == "receptie":
		_thuis = "kamer1"        # inrichten doe je in een kamer
	if not _verbonden:
		World.kamer_veranderd.connect(_op_kamer)
		_verbonden = true
	print("[probe] mb=start band=", ctx.state.band(), " munten=", _munten(),
		" wacht=", _nog().size())
	# Al betaald maar nog niet neergezet (ook na "Verder spelen")?  Dan mag dat
	# eerst een plekje krijgen: daar is immers al voor gerekend.
	if not _nog().is_empty():
		_plaats()
	elif _munten() <= 0:
		q["wacht"] = null
		_geen_munten()
	else:
		# R1: binnen een seconde na de tik staat er een som, niet het winkelblad.
		q["wacht"] = null
		_kassa_vraag()

func stop() -> void:
	if _verbonden and World.kamer_veranderd.is_connected(_op_kamer):
		World.kamer_veranderd.disconnect(_op_kamer)
	_verbonden = false
	_blad_stil = true
	Ui.blad_dicht()
	# de kaart, de buidel, de munten en het decor van dit spel gaan mee
	_kaart_weg()
	_bet = {}
	_kas = {}
	ctx.hotspots.laat()
	ctx.hotspots.wis_alles()
	ctx.wereld.decor_wis_eigenaar(ctx.id)
	State.bewaar()
	print("[probe] mb=stop gekocht=", int(_q().get("gekocht", 0)),
		" wacht=", _nog().size())

# =================================================================== hulpjes

## Mijn laatje in de opslag.  Alles wat door de JSON is geweest komt terug als
## float, dus elk getal gaat door `int()` (architecture.md §9).
func _q() -> Dictionary:
	var q := ctx.data()
	if not q.has("mijn") or typeof(q["mijn"]) != TYPE_ARRAY:
		q["mijn"] = []
	if not q.has("versiering") or typeof(q["versiering"]) != TYPE_DICTIONARY:
		q["versiering"] = {}
	if not q.has("wacht"):
		q["wacht"] = null
	q["gekocht"] = int(q.get("gekocht", 0))
	return q

## Wat er betaald is maar nog niet staat.
func _nog() -> Array:
	var w = _q()["wacht"]
	if typeof(w) != TYPE_DICTIONARY:
		return []
	var n = (w as Dictionary).get("nog", [])
	return n if typeof(n) == TYPE_ARRAY else []

func _zet_nog(nog: Array) -> void:
	var q := _q()
	q["wacht"] = null if nog.is_empty() else {"nog": nog}

static func _artikel(type: String) -> Dictionary:
	for w in Sommen.Meubels.WINKEL:
		if str(w["type"]) == type:
			return w
	return {}

static func _versier(sleutel: String) -> Dictionary:
	for v in Sommen.Meubels.VERSIERING:
		if str(v["sleutel"]) == sleutel:
			return v
	return {}

func _munten() -> int:
	return int(ctx.state.s["munten"])

func _sterren() -> int:
	return int(ctx.state.s["sterren"])

func _band() -> int:
	return ctx.state.band()

func _max_lijst() -> int:
	return Sommen.Meubels.max_lijst(_band())

static func _eur(n: int) -> String:
	return "€%d" % n

static func _totaal_van(types: Array) -> int:
	var t := 0
	for q in types:
		var w := _artikel(str(q))
		if not w.is_empty():
			t += int(w["prijs"])
	return t

static func _iconen(types: Array) -> String:
	var s := ""
	for t in types:
		var w := _artikel(str(t))
		s += str(w["icoon"]) if not w.is_empty() else "?"
	return s

static func _naam_van(type: String) -> String:
	var w := _artikel(type)
	return str(w["naam"]) if not w.is_empty() else "meubel"

static func _kap(t: String) -> String:
	return t if t.is_empty() else t.substr(0, 1).to_upper() + t.substr(1)

## "Mandje kost €3" of "Plant en mandje kosten €4" (games-a.md §5.6).
static func _prijs_zin(types: Array, totaal: int) -> String:
	if types.size() == 1:
		return "%s kost %s" % [_kap(_naam_van(str(types[0]))), _eur(_totaal_van(types))]
	var namen := PackedStringArray()
	for t in types:
		namen.append(_naam_van(str(t)))
	return "%s kosten %s" % [_kap(" en ".join(namen)), _eur(totaal)]

## "Plant €1 en mandje €3".
static func _som_zin(types: Array) -> String:
	var delen := PackedStringArray()
	for t in types:
		delen.append("%s %s" % [_naam_van(str(t)), _eur(int(_artikel(str(t))["prijs"]))])
	return _kap(" en ".join(delen))

## Samen doortellen: "6 … 7 … 8" — nooit een lap tekst, nooit een kruis.
static func _door_tellen(van: int, stappen: int) -> String:
	var l := PackedStringArray()
	for i in range(1, mini(stappen, 12) + 1):
		l.append(str(van + i))
	return " … ".join(l)

## Een plek in de ruimte waar je NU staat: een wolkje in een andere kamer zou
## je nooit zien.
func _hier() -> Dictionary:
	var k: String = ctx.wereld.actief()
	if k.is_empty():
		k = "receptie"
	if k == "receptie":
		var b: Dictionary = World.mik("boek", "receptie")
		if not b.is_empty():
			return {"kamer": k, "x": float(b["x"]), "z": float(b["z"])}
	var r: Rooms.Kamer = ctx.wereld.kamer(k)
	if r == null:
		return {"kamer": k, "x": 30.0, "z": 30.0}
	return {"kamer": k, "x": float(JsGetal.rond(r.w * 0.5)),
		"z": float(JsGetal.rond(r.d * 0.22))}

func _wolk(plek: Dictionary, o: Dictionary) -> void:
	var kopie := o.duplicate()
	kopie["kamer"] = plek.get("kamer", ctx.wereld.actief())
	kopie["x"] = plek.get("x", 0.0)
	kopie["z"] = plek.get("z", 0.0)
	ctx.ui.wolk(kopie)

func _kaart_weg() -> void:
	for laatje in [_bet, _kas]:
		var k = (laatje as Dictionary).get("kaart")
		if k != null:
			k.weg()
		if (laatje as Dictionary).has("kaart"):
			# een leeg laatje blijft leeg: het is zelf de vlag
			(laatje as Dictionary)["kaart"] = null

## `Rooms.meubel_zet` geeft een SLOT terug met `id` (bed, bakje) en een stuk
## DECOR met de sleutel `meubel` (plant, mandje, ...).  Eén regel, zodat de rest
## van dit spel het verschil nooit hoeft te kennen.
static func _meubel_id(m: Dictionary) -> String:
	return str(m.get("id", m.get("meubel", "")))

## Alles van mij uit de wereld halen (wolkjes, kaartjes, bronnen, cijfers).
func _leeg_wereld() -> void:
	_kaart_weg()
	ctx.hotspots.wis_alles()

func _op_kamer(kamer_id: String) -> void:
	if not actief:
		return
	if kamer_id != "receptie":
		_thuis = kamer_id
	match _view:
		"plaats":
			_vak_offset = 0
			_plaats_teken()
		"wereld":
			_wereld_teken()

# ==================================================================================
# BLADZIJDE 0 — DE BUIDEL TELLEN (PLAN.md §3.8 `N6`, open vraag V4)
#
# R1 zegt: binnen één seconde na de tik op de spelknop staat er een somkaart
# mét antwoordstrook.  Het winkelblad was dat niet — het was een winkel.  Dus
# begint elke beurt nu bij de kassa: de munten uit je buidel liggen op de
# toonbank, elk met zijn waarde erop, en de vraag hangt op de kassa.  Pas na
# het goede antwoord gaat het boek open.
# ==================================================================================

func _kassa_vraag() -> void:
	_view = "kassa"
	_bet = {}
	# de echte munten uit de buidel: `Sommen.buidel` legt ze zo neer dat elk
	# bedrag eronder ook precies te betalen is (dezelfde munten als straks).
	_kas = {"munten": ctx.econ.buidel(_munten()), "pog": 0, "kaart": null}
	_blad_stil = true
	Ui.blad_dicht()                              # de wereld is het speelvlak
	_blad_stil = false
	if ctx.wereld.actief() != "receptie":
		Hotel.naar_kamer("receptie")
	_q()["view"] = "kassa"
	State.bewaar()
	_kassa_teken()

func _kassa_teken() -> void:
	if not actief or _view != "kassa" or _kas.is_empty():
		return
	var munten: Array = _kas["munten"]
	var goed := _som(munten)
	ctx.hotspots.wis_alles()
	_kas["kaart"] = null
	_decor_betaal()

	# de vraag op de kassa.  Eigen keuzes in plaats van `goed`, want een
	# geldknop draagt zijn eenheid: 🪙 €7, niet 💰 7 (HOTEL.md §9).
	var kaart := ctx.ui.somkaart(_kaart_obj(), "💰 =", {
		"id": "mb_kas", "kamer": "receptie", "max": _cijfers(goed), "icoon": "💰",
		"vlak": _kaart_vlak(), "regel": T_HOEVEEL,
		"keuzes": _munt_keuzes(goed), "keuze_titel": T_TIK_GETAL})
	_kas["kaart"] = kaart
	# Nooit een kruis: één misser zet de telladder eronder, drie missers leggen
	# de spookmunten erbij — dezelfde ladder als bij het afrekenen.
	if int(_kas["pog"]) >= 1:
		kaart.hulp(_tel_munten(munten))
	if int(_kas["pog"]) >= 3:
		_spook_zet(goed, T_SPOOK_ZOVEEL)

	# de munten zelf, op de toonbank, met hun waarde erop (R5: getallen staan
	# óp voorwerpen — het kind telt ze, het raadt niet).
	var bank := Rooms.plek("receptie", 0.55, 0.75)
	ctx.ui.wolk({"id": "mb_munten", "kamer": "receptie",
		"x": float(bank["x"]), "z": float(bank["z"]), "hoog": 10.0, "prio": 11,
		"icoon": "🪙", "getal": _munt_rij(munten), "tekst": "",
		"klas": "hotbron", "titel": T_OP_TAFEL})

	# en de buidel waar ze uit komen: het AANTAL munten staat erop, niet hun
	# waarde — dat is precies de vergissing die de strook ook aanbiedt.
	var buidel := Rooms.plek("receptie", 0.075, 0.875)
	ctx.hotspots.bron({"x": float(buidel["x"]), "z": float(buidel["z"])}, {
		"id": "mb_buidel", "kamer": "receptie", "hoog": 10.0, "prio": 10,
		"icoon": "💰", "label": "", "aantal": munten.size(), "hand": 0,
		"titel": T_BUIDEL % munten.size(), "sleep": "",
		"tik": func(_s) -> void:
			ctx.snd.munt()
			_kassa_teken()})
	ctx.wereld.vuil()
	_meld_kassa()

## Het cijferbudget van de strook: twee cijfers, en drie voor een kassa die door
## de honderd is (een lange speelbeurt spaart door).
static func _cijfers(bedrag: int) -> int:
	return 3 if bedrag > 99 else 2

## De vier knoppen van de buidelvraag: pictogram én bedrag op elke knop.  De
## klassieke vergissing staat er expres bij — het AANTAL munten in plaats van
## hun waarde (IDEAS.md: de valkuil is het doel, niet het ongeluk).
func _munt_keuzes(goed: int) -> Array:
	var munten: Array = _kas.get("munten", [])
	var liever: Array[int] = [munten.size()]
	if not munten.is_empty():
		liever.append(int(munten[0]))          # alleen de grootste munt geteld
	var dag := int(ctx.state.s.get("dag", 1))
	var zaad := (hash("mb_kas") % 100003) + dag * 17
	var uit: Array = []
	for g in Afleiders.vier(goed, zaad, {"min": 1,
			"max": int(pow(10, _cijfers(goed))) - 1, "liever": liever}):
		var n: int = g
		uit.append({"id": "n%d" % n, "icoon": "🪙", "tekst": _eur(n),
			"kort": _eur(n), "titel": _eur(n),
			"kies": func(_k, _kaart) -> void: _kas_ok(n)})
	return uit

## De munten zoals ze op de toonbank liggen: "€2 €2 €2 €2 €1".
static func _munt_rij(munten: Array) -> String:
	var l := PackedStringArray()
	for i in mini(munten.size(), 6):
		l.append(_eur(int(munten[i])))
	if munten.size() > 6:
		l.append("+%d" % (munten.size() - 6))
	return " ".join(l)

## Samen de buidel doortellen: de stand ná elke munt ("2 … 4 … 6 … 8 … 9").
static func _tel_munten(munten: Array) -> String:
	var l := PackedStringArray()
	var som := 0
	for i in mini(munten.size(), 12):
		som += int(munten[i])
		l.append(str(som))
	return " … ".join(l)

func _kas_ok(n: int) -> void:
	if not actief or _kas.is_empty():
		return
	var goed := _som(_kas["munten"])
	if n != goed:
		_kas["pog"] = int(_kas["pog"]) + 1
		ctx.snd.zacht()                        # nooit een kruis, nooit een straf
		_kassa_teken()
		return
	var kaart = _kas.get("kaart")
	if kaart != null:
		kaart.som("💰 = %s" % _eur(goed))
		kaart.klaar()                          # het vinkje, de strook gaat weg
	_spook_weg()
	ctx.snd.ja()
	var b: Dictionary = World.mik("kassa", "receptie")
	_wolk({"kamer": "receptie", "x": float(b.get("x", 60)), "z": float(b.get("z", 20))},
		{"id": "mb_af", "icoon": "✅", "getal": _eur(goed), "tekst": "",
		"klas": "goed", "hoog": 30.0, "prio": 12})
	_q()["view"] = "boek"
	State.bewaar()
	print("[probe] mb=kassa-goed bedrag=", goed, " pog=", int(_kas["pog"]))
	ctx.wereld.vuil()
	_na_kassa()

func _na_kassa() -> void:
	if not await na(0.8):
		return
	if _view == "kassa":
		_boek()

## Stap 0: met een lege buidel valt er niets te tellen — dan meteen het boek en
## een wolkje dat zegt waarom.  Een som met `goed = 0` zou vier afleiders rond
## nul opleveren, en dat is geen vraag maar een raadsel.
func _geen_munten() -> void:
	_q()["view"] = "boek"
	_boek()
	_wolk(_hier(), {"id": "mb_geen", "icoon": "💰", "tekst": T_GEEN_MUNTEN,
		"klas": "hulp", "hoog": 26.0, "prio": 11})
	ctx.wereld.vuil()
	_wolk_straks("mb_geen", 2.6)

func _meld_kassa() -> void:
	if not await na(0.1) or _view != "kassa" or _kas.is_empty():
		return
	print("[probe] mb=kassa munten=", _munten(),
		" stuks=", (_kas["munten"] as Array).size(), " pog=", int(_kas["pog"]))
	for id in ["mb_kas", "mb_munten", "mb_buidel", "mb_spook"]:
		var s := Hits.spot(id)
		if s != null and is_instance_valid(s.knoop) and s.knoop.visible:
			print("[probe] mb=hot ", id, "=", s.knoop.get_global_rect(),
				" dekking=", "%.2f" % Hits.dekking(id))
	_meld_keuzes(_kas.get("kaart"))

# ==================================================================================
# BLADZIJDE 1 — HET OVERZICHT (pictogram + prijs, geen zinnen)
# Het enige paneel dat HOTEL.md §9 nog toestaat.
# ==================================================================================

func _boek() -> void:
	_view = "boek"
	_bet = {}
	_leeg_wereld()
	_boek_teken()

func _boek_teken() -> void:
	if not actief or _view != "boek":
		return
	var q := _q()
	var inhoud: Array[Control] = []
	inhoud.append(_rij([
		_chip("💰 %d" % _munten(), UiThema.ZON),
		_chip("⭐ %d" % _sterren(), UiThema.LILA),
		_chip("🛏 %d" % ctx.state.max_gasten(), UiThema.MUNT)]))
	inhoud.append(_rij([
		_tabknop("meubels", "🪑 %s" % T_MEUBELS, T_MEUBELS),
		_tabknop("versiering", "⭐ Versiering", T_VERSIERING)]))
	if not _spaar.is_empty():
		inhoud.append(_rij([
			_chip("%s %s" % [_spaar["icoon"], _spaar["nodig"]], UiThema.ROZE),
			_chip("💰 %s" % _spaar["heb"], UiThema.ZON)]))
	if _tab == "versiering":
		_blad_versiering(q, inhoud)
	else:
		_blad_meubels(inhoud)
	_blad_open(inhoud)
	ctx.wereld.vuil()

## Hoe breed het blad straks wordt — dezelfde som als `UiBlad.bouw`.  Het
## meubelboek heeft dat getal nodig VOORDAT het zijn kaartjes bouwt: op een
## telefoon (blad 336 eenheden) passen er maar twee kaartjes van 104 naast
## elkaar, en dan is de bladzijde drie rijen hoog, rolt ze, en staan 🛒
## Afrekenen en ✖ Boek dicht onder de onderrand van het scherm.  Gemeten op
## 360 x 740: `Kdicht` op y 762.  Dus: smallere kaartjes (drie op een rij) en
## het lijstje BOVEN het rek, zodat afrekenen altijd in beeld staat.
func _blad_breed() -> float:
	var kader := Vector2.ZERO
	if Ui.bladlaag != null and is_instance_valid(Ui.bladlaag):
		kader = Ui.bladlaag.size
	if kader.x < 1.0:
		kader = Ui.scherm_maat()
	return minf(UiBlad.BREED, maxf(240.0, kader.x - 2 * UiBlad.RAND))

func _blad_smal() -> bool:
	return _blad_breed() < 400.0

func _blad_meubels(inhoud: Array[Control]) -> void:
	if _blad_smal():
		_lijst_rij(inhoud)
	var rooster := HFlowContainer.new()
	rooster.name = "Winkel"
	rooster.alignment = FlowContainer.ALIGNMENT_CENTER
	rooster.add_theme_constant_override("h_separation", 6)
	rooster.add_theme_constant_override("v_separation", 6)
	var maxi_lijst := _max_lijst()
	for w in Sommen.Meubels.WINKEL:
		var type := str(w["type"])
		var prijs := int(w["prijs"])
		var delen: Array[Control] = [
			_icoon_label(str(w["icoon"])),
			_chip(_eur(prijs), UiThema.PERZIK)]
		if not str(w.get("plus", "")).is_empty():
			delen.append(_chip(str(w["plus"]), UiThema.MUNT))
		if maxi_lijst > 1:
			var aantal := 0
			for t in _lijst:
				if t == type:
					aantal += 1
			delen.append(_knop("k_%s" % type, "%d×" % aantal if aantal > 0 else "+",
				"%s %d euro erbij" % [str(w["naam"]), prijs],
				func() -> void: _op_lijstje(type)))
		else:
			var kan := prijs <= _munten()
			delen.append(_knop("k_%s" % type, "🛒" if kan else "💛",
				"%s kopen, %d euro" % [str(w["naam"]), prijs],
				func() -> void: _koop([type])))
		rooster.add_child(_kaartje(delen))
	inhoud.append(rooster)
	if not _blad_smal():
		_lijst_rij(inhoud)

## Het lijstje met zijn twee knoppen: 🛒 Afrekenen en « Lijstje leeg.
func _lijst_rij(inhoud: Array[Control]) -> void:
	if _max_lijst() <= 1 or _lijst.is_empty():
		return
	var prijzen := PackedStringArray()
	for t in _lijst:
		prijzen.append(_eur(int(_artikel(t)["prijs"])))
	inhoud.append(_rij([
		_chip("%s %s" % [_iconen(_lijst), " + ".join(prijzen)], UiThema.KAART),
		_knop("afrekenen", "🛒", T_AFREKENEN, func() -> void: _koop(_lijst.duplicate())),
		_knop("leeg", "«", T_LIJST_LEEG, func() -> void:
			_lijst = []
			_boek_teken())]))

func _blad_versiering(q: Dictionary, inhoud: Array[Control]) -> void:
	var rooster := HFlowContainer.new()
	rooster.name = "Versiering"
	rooster.alignment = FlowContainer.ALIGNMENT_CENTER
	rooster.add_theme_constant_override("h_separation", 6)
	rooster.add_theme_constant_override("v_separation", 6)
	var sterren := _sterren()
	for v in Sommen.Meubels.VERSIERING:
		var sleutel := str(v["sleutel"])
		var nodig := int(v["ster"])
		var heb := int((q["versiering"] as Dictionary).get(sleutel, 0))
		var delen: Array[Control] = [
			_icoon_label(str(v["icoon"])),
			_chip("⭐ %d" % nodig, UiThema.LILA)]
		if heb > 0:
			delen.append(_chip("%d×" % heb, UiThema.MUNT))
		delen.append(_knop("v_%s" % sleutel, "🛒" if nodig <= sterren else "💛",
			"%s kopen voor %d sterren" % [str(v["naam"]), nodig],
			func() -> void: _koop_versiering(sleutel)))
		rooster.add_child(_kaartje(delen))
	inhoud.append(rooster)
	var bak := HFlowContainer.new()
	bak.name = "Bak"
	bak.alignment = FlowContainer.ALIGNMENT_CENTER
	bak.add_theme_constant_override("h_separation", 2)
	for v in Sommen.Meubels.VERSIERING:
		var n := int((q["versiering"] as Dictionary).get(str(v["sleutel"]), 0))
		if n <= 0:
			continue
		for _i in mini(n, 8):
			bak.add_child(_icoon_label(str(v["icoon"]), true))
		if n > 8:
			bak.add_child(_chip("+%d" % (n - 8), UiThema.KAART))
	if bak.get_child_count() > 0:
		inhoud.append(bak)

## Het blad zelf.  `sluitbaar` blijft aan: naast het blad tikken legt het boek
## even weg en zet het spel op zijn wereldpagina (§5.8 hoort daar).
func _blad_open(inhoud: Array[Control]) -> void:
	_blad_stil = true
	var blad := Ui.blad_open({
		"titel": T_TITEL, "inhoud": inhoud, "sluitbaar": true,
		# `dicht: false`: `ctx.sluit()` doet het blad zelf dicht via `stop()`.
		# Zou het blad eerst sluiten, dan zag de `gesloten`-luisteraar hieronder
		# nog even een wereldpagina die meteen daarna wordt opgeruimd.
		"knoppen": [{"id": "dicht", "tekst": "✖", "titel": T_BOEK_DICHT,
			"dicht": false, "aan": func() -> void: ctx.sluit()}],
	})
	_blad_stil = false
	if blad == null:
		return
	# `Ui.blad_open` doet het vorige blad met `queue_free()` dicht, dus dat hangt
	# nog één beeld in dezelfde laag en verdubbelt het waas.  Onzichtbaar maken
	# scheelt die flits; opruimen doet de motor zelf.
	for ouder in Ui.bladlaag.get_children():
		if ouder != blad and ouder is Control and ouder.is_queued_for_deletion():
			(ouder as Control).visible = false
	blad.gesloten.connect(func() -> void:
		if actief and not _blad_stil and _view == "boek":
			_wereld())
	_meld_blad(blad)

func _meld_blad(blad: UiBlad) -> void:
	if not await na(0.1) or not is_instance_valid(blad):
		return
	var rij := blad.get_node_or_null("Midden/Blad/Rol/Kolom/Knoppen")
	print("[probe] mb=blad tab=", _tab, " lijst=", _lijst.size(),
		" knoppen=", 0 if rij == null else rij.get_child_count())
	var kolom := blad.get_node_or_null("Midden/Blad/Rol/Kolom")
	if kolom != null:
		_meld_knop_in(kolom)

func _meld_knop_in(kind: Node) -> void:
	if kind is Button:
		print("[probe] mb=knop ", kind.name, "=", (kind as Control).get_global_rect())
		return
	for k in kind.get_children():
		_meld_knop_in(k)

# ----------------------------------------------------------- bouwstenen blad

func _rij(kinderen: Array) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.name = "Rij"
	f.alignment = FlowContainer.ALIGNMENT_CENTER
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	for k in kinderen:
		f.add_child(k)
	return f

func _chip(tekst: String, kleur: Color) -> Label:
	var l := Label.new()
	l.name = "Chip"
	l.text = tekst
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", _maat("klein"))
	l.add_theme_color_override("font_color", UiThema.INKT)
	l.add_theme_stylebox_override("normal",
		UiThema.vulling(UiThema.vlak(kleur, 999, 2, UiThema.WIT), 10, 4))
	return l

func _icoon_label(icoon: String, klein := false) -> Label:
	var l := Label.new()
	l.name = "Icoon"
	l.text = icoon
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size",
		_maat("icoon_keuze") if klein else _maat("icoon_bron"))
	return l

func _kaartje(delen: Array[Control]) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Kaartje"
	p.custom_minimum_size = Vector2(88 if _blad_smal() else 104, 0)
	p.add_theme_stylebox_override("panel",
		UiThema.vulling(UiThema.vlak(UiThema.BG2, 16, 2, UiThema.WIT), 6, 8))
	var kolom := VBoxContainer.new()
	kolom.name = "Kolom"
	kolom.add_theme_constant_override("separation", 4)
	p.add_child(kolom)
	for c in delen:
		c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		kolom.add_child(c)
	return p

func _knop(id: String, tekst: String, titel: String, aan: Callable) -> Button:
	var b := Button.new()
	b.name = "K" + id
	b.text = tekst
	b.tooltip_text = titel
	b.custom_minimum_size = Vector2(Ui.tap_maat(), Ui.tap_maat())
	b.clip_text = false
	b.add_theme_font_size_override("font_size", _maat("knop"))
	b.pressed.connect(func() -> void:
		Snd.tik()
		aan.call())
	return b

func _tabknop(welke: String, tekst: String, titel: String) -> Button:
	var b := _knop("tab_" + welke, tekst, titel, func() -> void:
		_tab = welke
		_boek_teken())
	if _tab == welke:
		b.theme_type_variation = "KnopGroot"
	return b

func _maat(sleutel: String) -> int:
	return maxi(UiThema.VLOER, int(Ui.maten.get(sleutel, 14)))

# -------------------------------------------------------------- het lijstje

func _op_lijstje(type: String) -> void:
	if _lijst.size() >= _max_lijst():
		ctx.snd.zacht()
		_wolk(_hier(), {"id": "mb_vol", "icoon": "🧺", "getal": 2,
			"tekst": T_GENOEG, "klas": "hulp"})
		ctx.wereld.vuil()
		return
	_lijst.append(type)
	_spaar = {}
	_boek_teken()

## Te weinig geld: één wolkje met de prijs en wat je hebt.  Het meubel blijft
## in het boek staan om voor te sparen; er gaat niets op slot.
func _tekort(totaal: int) -> void:
	_spaar = {"icoon": "💛", "nodig": _eur(totaal), "heb": _eur(_munten())}
	_boek_teken()
	ctx.snd.zacht()
	_wolk(_hier(), {"id": "mb_spaar", "icoon": "💛", "getal": _eur(totaal),
		"tekst": "je hebt %s" % _eur(_munten()), "klas": "hulp",
		"hoog": 26.0, "prio": 11})
	ctx.wereld.vuil()

func _koop_versiering(sleutel: String) -> void:
	var q := _q()
	var v := _versier(sleutel)
	if v.is_empty():
		return
	var nodig := int(v["ster"])
	var sterren := _sterren()
	if nodig > sterren:
		_spaar = {"icoon": "⭐", "nodig": nodig, "heb": sterren}
		_boek_teken()
		ctx.snd.zacht()
		_wolk(_hier(), {"id": "mb_spaar", "icoon": "⭐", "getal": nodig,
			"tekst": "je hebt %d" % sterren, "klas": "hulp", "hoog": 26.0, "prio": 11})
		ctx.wereld.vuil()
		return
	ctx.econ.sterren(-nodig, "versiering")     # `state.ster(-n, 'versiering')`
	var bak: Dictionary = q["versiering"]
	bak[sleutel] = int(bak.get(sleutel, 0)) + 1
	_spaar = {}
	State.bewaar()
	Hotel.render()
	_boek_teken()
	_wolk(_hier(), {"id": "mb_af", "icoon": str(v["icoon"]), "getal": "+1",
		"klas": "goed", "hoog": 26.0, "prio": 11})
	ctx.wereld.vuil()

# ==================================================================================
# DE WERELDPAGINA — je eigen meubels (games-a.md §5.8)
# ==================================================================================

func _wereld() -> void:
	_view = "wereld"
	_wereld_teken()

func _wereld_teken() -> void:
	if not actief or _view != "wereld":
		return
	ctx.hotspots.wis_alles()
	var b: Dictionary = World.mik("boek", "receptie")
	ctx.hotspots.maak({"id": "mb_boek", "kamer": "receptie",
		"x": float(b.get("x", 84)), "z": float(b.get("z", 20)), "y": 20.0,
		"icoon": "📖", "label": W_BOEK, "titel": T_TERUG_BOEK, "prio": 11,
		"aan": func(_s) -> void: _boek()})
	_mijn_meubel_knoppen()
	ctx.wereld.vuil()

## Hooguit drie eigen meubels per kamer krijgen knopjes (architecture.md §13
## Q-X2-9: het plafond blijft, een vierde verzoek zegt "leg eerst iets neer").
func _mijn_meubel_knoppen() -> void:
	for kamer_id in ctx.wereld.kamers():
		var n := 0
		for m in ctx.wereld.kamer_meubels(kamer_id):
			var mijn := _mijn(str(m.get("id", "")))
			if mijn.is_empty() or n >= 3:
				continue
			n += 1
			var id := str(m["id"])
			var type := str(mijn.get("type", "plant"))
			var x := float(m.get("x", 0.0))
			var z := float(m.get("z", 0.0))
			if type == "bed":
				ctx.hotspots.maak({"id": "mbdraai_%s" % id, "kamer": kamer_id,
					"x": x + 8.0, "z": z - 8.0, "y": 14.0,
					"icoon": "🔄", "label": W_DRAAIEN, "titel": T_DRAAIEN, "prio": 8,
					"aan": func(_s) -> void: _draai(id, kamer_id, x, z)})
			ctx.hotspots.maak({"id": "mbop_%s" % id, "kamer": kamer_id,
				"x": x - 8.0, "z": z + 8.0, "y": 14.0,
				"icoon": "📦", "label": W_OPPAKKEN,
				"titel": "%s oppakken" % _naam_van(type), "prio": 8,
				"aan": func(_s) -> void: _pak_op(id, type, kamer_id, x, z)})

func _mijn(id: String) -> Dictionary:
	for m in _q()["mijn"]:
		if typeof(m) == TYPE_DICTIONARY and str((m as Dictionary).get("id", "")) == id:
			return m
	return {}

func _mijn_weg(id: String) -> void:
	var q := _q()
	var uit: Array = []
	for m in q["mijn"]:
		if typeof(m) == TYPE_DICTIONARY and str((m as Dictionary).get("id", "")) != id:
			uit.append(m)
	q["mijn"] = uit

func _rot_van(id: String) -> int:
	for m in ctx.wereld.kamer_meubels():
		if str(m.get("id", "")) == id:
			return int(m.get("rot", 0))
	return 0

## Draaien = weghalen en op hetzelfde vakje een kwartslag anders terugzetten.
## Lukt dat niet, dan gaat het bed in de doos terug — nooit kwijt.
func _draai(id: String, kamer_id: String, x: float, z: float) -> void:
	if not ctx.state.gast_in_bed(kamer_id, id).is_empty():
		_slaapt(kamer_id, x, z)
		return
	var rot := (_rot_van(id) + 1) % 2
	if not ctx.wereld.verwijder_meubel(id):
		return
	_mijn_weg(id)
	var m: Dictionary = ctx.wereld.voeg_bed(kamer_id, {"x": x, "z": z, "rot": rot})
	if m.is_empty():
		m = ctx.wereld.voeg_bed(kamer_id, {"x": x, "z": z})
	if m.is_empty():
		m = ctx.wereld.voeg_bed(kamer_id, {})
	if m.is_empty():
		_zet_nog(_nog() + ["bed"])
		State.bewaar()
		_plaats()
		return
	(_q()["mijn"] as Array).append({"id": _meubel_id(m), "type": "bed"})
	ctx.snd.plop(1)
	State.bewaar()
	Hotel.render()
	_wereld_teken()
	_wolk({"kamer": kamer_id, "x": float(m["x"]), "z": float(m["z"])},
		{"id": "mb_neer", "icoon": "🔄", "getal": "✓", "klas": "goed",
		"hoog": 24.0, "prio": 12})
	ctx.wereld.vuil()
	_wolk_straks("mb_neer", 1.8)

## Oppakken is gratis: het meubel gaat terug in `wacht.nog` en je gaat direct
## naar de plaatsstap.
func _pak_op(id: String, type: String, kamer_id: String, x: float, z: float) -> void:
	if type == "bed" and not ctx.state.gast_in_bed(kamer_id, id).is_empty():
		_slaapt(kamer_id, x, z)
		return
	if _nog().size() >= WACHT_MAX:
		ctx.snd.zacht()
		_wolk({"kamer": kamer_id, "x": x, "z": z},
			{"id": "mb_vol", "icoon": "📦", "tekst": T_EERST, "klas": "hulp",
			"hoog": 26.0, "prio": 11})
		ctx.wereld.vuil()
		return
	if not ctx.wereld.verwijder_meubel(id):
		return
	_mijn_weg(id)
	_zet_nog(_nog() + [type])
	ctx.snd.terug()
	State.bewaar()
	Hotel.render()
	_thuis = kamer_id
	_plaats()

func _slaapt(kamer_id: String, x: float, z: float) -> void:
	ctx.snd.zacht()
	_wolk({"kamer": kamer_id, "x": x, "z": z},
		{"id": "mb_slaap", "icoon": "💤", "tekst": T_SLAAPT, "klas": "hulp",
		"hoog": 26.0, "prio": 11})
	ctx.wereld.vuil()

# ==================================================================================
# BLADZIJDE 2 — AFREKENEN, HELEMAAL ÍN DE WERELD (games-a.md §5.6)
# ==================================================================================

func _koop(types: Array) -> void:
	if types.is_empty():
		return
	var tot := _totaal_van(types)
	if tot > _munten():
		_tekort(tot)
		return
	var cap := Sommen.Meubels.buidel_cap(tot, _munten(), _band())
	_spaar = {}
	_view = "betaal"
	_t0 = Time.get_ticks_msec()
	var soorten: Array[String] = []
	for t in types:
		soorten.append(str(t))
	_bet = {
		"types": soorten, "totaal": tot,
		"stap": "som" if soorten.size() > 1 else "munten",
		"hand": ctx.econ.buidel(cap), "bank": [] as Array[int],
		"som_pog": 0, "tel_pog": 0, "wis_pog": 0,
		"spook": {}, "hulp": "", "rest": _munten() - cap,
		"kaart": null, "soort": 1,
	}
	_kies_soort(1)
	_blad_stil = true
	Ui.blad_dicht()                              # de wereld is nu het speelvlak
	_blad_stil = false
	Hotel.naar_kamer("receptie")
	ctx.snd.tik()
	_betaal_teken()

# ------------------------------------------------------------------- munten

func _heeft(v: int) -> int:
	var n := 0
	for c in _bet["hand"]:
		if int(c) == v:
			n += 1
	return n

func _som(munten: Array) -> int:
	var t := 0
	for c in munten:
		t += int(c)
	return t

## Welke muntsoort heb je in je hand?  Tikken op de buidel gaat naar de
## volgende soort die je nog hebt (`kiesSoort` loopt cyclisch door [1,2,5,10]).
func _kies_soort(vanaf: int) -> int:
	var i := MUNTSOORT.find(vanaf)
	if i < 0:
		i = 0
	for k in MUNTSOORT.size():
		var v: int = MUNTSOORT[(i + k) % MUNTSOORT.size()]
		if _heeft(v) > 0:
			_bet["soort"] = v
			return v
	_bet["soort"] = 0
	return 0

func _volgende_soort() -> void:
	if _bet.is_empty():
		return
	var i := MUNTSOORT.find(int(_bet["soort"]))
	_kies_soort(MUNTSOORT[(i + 1) % MUNTSOORT.size()])
	ctx.snd.tik()
	_betaal_teken()

# ----------------------------------------------------------------- het beeld

func _betaal_teken() -> void:
	if not actief or _bet.is_empty():
		return
	var stap := str(_bet["stap"])
	var types: Array = _bet["types"]
	var totaal := int(_bet["totaal"])
	ctx.hotspots.wis_alles()
	_bet["kaart"] = null
	_decor_betaal()

	if stap == "som":
		var prijzen := PackedStringArray()
		for t in types:
			prijzen.append(_eur(int(_artikel(str(t))["prijs"])))
		var p0 := int(_artikel(str(types[0]))["prijs"])
		var p1 := int(_artikel(str(types[types.size() - 1]))["prijs"])
		var kaart := ctx.ui.somkaart(_kaart_obj(), " + ".join(prijzen) + " =", {
			"id": "mb_som", "kamer": "receptie", "max": 2, "icoon": "🛒",
			"goed": totaal, "liever": [absi(p0 - p1), maxi(p0, p1), totaal + 1],
			"vlak": _kaart_vlak(),
			"regel": _som_zin(types), "regel2": T_SAMEN,
			"on_ok": func(n) -> void: _som_ok(n)})
		_bet["kaart"] = kaart
		if int(_bet["som_pog"]) >= 1:
			kaart.hulp(_door_tellen(int(_artikel(str(types[0]))["prijs"]),
				int(_artikel(str(types[1]))["prijs"])))
		if int(_bet["som_pog"]) >= 3:
			_spook_zet(totaal, T_SPOOK_SAMEN)
	elif stap == "wissel":
		var betaald := _som(_bet["bank"])
		var kaart := ctx.ui.somkaart(_kaart_obj(),
			"%s − %s =" % [_eur(betaald), _eur(totaal)], {
			"id": "mb_wissel", "kamer": "receptie", "max": 2,
			"goed": betaald - totaal, "liever": [totaal, betaald, betaald - totaal + 1],
			"hoog": 26.0, "icoon": "👛", "vlak": _kaart_vlak(),
			"regel": "Je gaf %s, het kost %s" % [_eur(betaald), _eur(totaal)],
			"regel2": T_TERUG_VRAAG,
			"on_ok": func(n) -> void: _wissel_ok(n)})
		_bet["kaart"] = kaart
		if int(_bet["wis_pog"]) >= 1:
			kaart.hulp(_door_tellen(totaal, betaald - totaal))
		if int(_bet["wis_pog"]) >= 3:
			_spook_zet(betaald - totaal, T_SPOOK_WISSEL)
	else:
		# De prijs als afgevinkt sommenkaartje.  De pictogram-som ("🪑 =")
		# staat er nooit zonder zin erboven (HOTEL.md §9).
		var kaart := ctx.ui.somkaart(_kaart_obj(), _iconen(types) + " =", {
			"id": "mb_bon", "kamer": "receptie", "pad": false, "hoog": 24.0,
			"vlak": _kaart_vlak(),
			"icoon": "🛒" if types.size() > 1 else str(_artikel(str(types[0]))["icoon"]),
			"regel": _prijs_zin(types, totaal), "regel2": T_LEG_MUNTEN})
		_bet["kaart"] = kaart
		kaart.zet(_eur(totaal))
		if not str(_bet["hulp"]).is_empty():
			kaart.hulp(str(_bet["hulp"]))
		var spook: Dictionary = _bet["spook"]
		if not spook.is_empty():
			_spook_zet(int(spook["bedrag"]), str(spook["label"]))

	# de toonbank: sleep de munten hierheen, het bedrag staat erop.  Tikken
	# legt de munt die je in je hand hebt neer — zo kun je ook zonder slepen.
	var geteld := _som(_bet["bank"])
	var bank := Rooms.plek("receptie", 0.55, 0.75)
	ctx.hotspots.maak({"id": "mb_bank", "kamer": "receptie",
		"x": float(bank["x"]), "z": float(bank["z"]), "y": 10.0,
		"icoon": "🧾", "label": _eur(geteld), "prio": 11,
		"kind": "drop", "drop": "mbbank", "klas": "hotbron",
		"titel": "de toonbank: %s" % _eur(geteld),
		"val": func(_lading, _data) -> void: _leg_neer(int(_bet.get("soort", 0))),
		"aan": func(_s) -> void: _leg_neer(int(_bet.get("soort", 0)))})

	# je geldbuidel: de munt die je in je hand hebt staat erop, met hoeveel je
	# er nog van hebt.  Tikken pakt de volgende muntsoort.
	var soort := int(_bet["soort"])
	if soort > 0:
		var buidel := Rooms.plek("receptie", 0.075, 0.875)
		ctx.hotspots.bron({"x": float(buidel["x"]), "z": float(buidel["z"])}, {
			"id": "mb_buidel", "kamer": "receptie", "hoog": 10.0, "prio": 10,
			# `UiBron` tekent alleen het pictogram, geen label: de waarde van de
			# munt gaat er dus IN, zodat het kind ziet wat het in zijn hand heeft
			# (HOTEL.md §9: een pictogram staat altijd bij zijn getal).
			"icoon": ("💶" if soort >= 10 else "🪙") + _eur(soort),
			"label": _eur(soort), "aantal": _heeft(soort), "hand": 0,
			"titel": "munt van %d euro (%d in je buidel)" % [soort, _heeft(soort)],
			"sleep": "" if stap == "som" else "mbbank",
			"tik": func(_s) -> void: _volgende_soort()})

	# klaar met tellen, en een munt terugpakken
	var ok_plek := Rooms.plek("receptie", 0.95, 0.25)
	var terug_plek := Rooms.plek("receptie", 0.375, 0.975)
	if stap != "som":
		ctx.hotspots.maak({"id": "mb_ok", "kamer": "receptie",
			"x": float(ok_plek["x"]), "z": float(ok_plek["z"]), "y": 8.0,
			"icoon": "✔", "label": W_KLAAR, "klas": "hotwolk goed", "prio": 10,
			"titel": T_KLAAR_TELLEN,
			"aan": func(_s) -> void: _klaar_met_tellen()})
	if not (_bet["bank"] as Array).is_empty():
		ctx.hotspots.maak({"id": "mb_terug", "kamer": "receptie",
			"x": float(terug_plek["x"]), "z": float(terug_plek["z"]), "y": 6.0,
			"icoon": "«", "label": W_TERUG, "klas": "hotwolk", "prio": 9,
			"titel": T_MUNT_TERUG,
			"aan": func(_s) -> void: _munt_terug()})
	else:
		# Niets neergelegd?  Dan is dit de weg terug naar het boek.
		ctx.hotspots.maak({"id": "mb_boek", "kamer": "receptie",
			"x": float(terug_plek["x"]), "z": float(terug_plek["z"]), "y": 6.0,
			"icoon": "📖", "label": W_BOEK, "klas": "hotgame", "prio": 9,
			"titel": T_TERUG_BOEK,
			"aan": func(_s) -> void: _boek()})
	ctx.wereld.vuil()
	_meld_betaal()

## Waar de rekenkaart hangt: op de kassa, zoals §5.6 vraagt.
##
## Alleen op een heel laag kader (telefoon in landschap, kader 558 x 289) niet.
## Daar staat het cijferpad in de onderste 106 eenheden en is er tussen de
## bovenrand en die band geen enkele band vrij die de kassa mist; een vaste
## kaart schuift alleen VERTICAAL (architecture.md §4.3), dus hij zou de kassa
## helemaal afdekken.  De kaart hangt dan een stuk naar links, vóór de balie —
## nog steeds in de wereld, en de kassa blijft heel.  De kassa gaat wél als
## `vlak` mee, zodat `Hits.dekking` een echt getal blijft meten en niet nul is
## omdat er niets te dekken viel.
const KAART_KADER_LAAG := 400.0

func _kaart_obj() -> Variant:
	if World.kader_rect().size.y >= KAART_KADER_LAAG:
		return "kassa"
	return Rooms.plek("receptie", 0.20, 0.72)

func _kaart_vlak() -> Rect2:
	if World.kader_rect().size.y >= KAART_KADER_LAAG:
		return Rect2()                      # `Ui.somkaart` meet de kassa zelf
	var k: Dictionary = World.mik("kassa", "receptie")
	if k.is_empty():
		return Rect2()
	return World.vlak_van("kassa", float(k.get("x", 60.0)), float(k.get("z", 20.0)),
		float(k.get("y", 14.0)))

## Hoeveel ✨-vakjes er tegelijk in beeld staan.  Vier, zoals §5.7 zegt — maar
## een laag kader heeft onder de kamer maar een paar banden, en daar staan ook
## de deur, de bedden, het bakje, de speelmand en de naamplaatjes van de gasten
## in.  Gemeten op het laagste kader dat de poort kent (telefoon in landschap,
## kader 558 x 289, vijf banden): daar passen naast de knoppen van het hotel
## precies TWEE knoppen van dit spel zonder dat er één `krap` staat.  Dus daar
## de doos plus één vakje, en geen `▸`.  Neerzetten blijft overal mogelijk: na
## elk meubel wordt de lijst opnieuw berekend, dus het volgende vakje ligt weer
## ergens anders.
func _vak_max() -> int:
	var h := World.kader_rect().size.y
	if h >= KAART_KADER_LAAG:
		return VAK_MAX
	return 2 if h >= 340.0 else 1

## En daar is dus ook geen band meer over voor `▸ Meer`.
func _meer_knop() -> bool:
	return World.kader_rect().size.y >= 340.0

## De toonbank en de buidel zijn echte voorwerpen, zodat het vangvlak van een
## sleepdoel de vereniging van knop en voorwerp is (architecture.md §10).
func _decor_betaal() -> void:
	var bank := Rooms.plek("receptie", 0.55, 0.75)
	var buidel := Rooms.plek("receptie", 0.075, 0.875)
	ctx.wereld.decor("receptie", {"id": "mb_toonbank", "model": "meubels_toonbank",
		"x": float(bank["x"]), "z": float(bank["z"]), "door": ctx.id})
	ctx.wereld.decor("receptie", {"id": "mb_geldbuidel", "model": "meubels_buidel",
		"x": float(buidel["x"]), "z": float(buidel["z"]), "door": ctx.id})

func _meld_betaal() -> void:
	if not await na(0.1) or not _bet.has("stap"):
		return
	print("[probe] mb=betaal stap=", _bet["stap"], " totaal=", _bet["totaal"],
		" bank=", _som(_bet["bank"]), " soort=", _bet["soort"])
	for id in ["mb_som", "mb_wissel", "mb_bon", "mb_bank", "mb_buidel", "mb_ok",
			"mb_terug", "mb_boek", "mb_spook"]:
		var s := Hits.spot(id)
		if s != null and is_instance_valid(s.knoop) and s.knoop.visible:
			print("[probe] mb=hot ", id, "=", s.knoop.get_global_rect(),
				" dekking=", "%.2f" % Hits.dekking(id))
	_meld_keuzes(_bet.get("kaart"))

## De knoppen van de antwoordstrook, zodat een browserproef een getal kan tikken.
func _meld_keuzes(kaart) -> void:
	if kaart == null or str(kaart.strook_id).is_empty():
		return
	var strook := Hits.spot(str(kaart.strook_id))
	if strook == null or not is_instance_valid(strook.knoop):
		return
	var rij := strook.knoop.get_node_or_null("Rij")
	if rij == null:
		return
	for k in rij.get_children():
		print("[probe] mb=keuze ", k.name, "=", (k as Control).get_global_rect())

# ----------------------------------------------------------- de spookmunten

func _spook_weg() -> void:
	ctx.hotspots.weg("mb_spook")

## `Econ.splits(bedrag)`, hooguit 4 munten, als één kaartje bij SPOOKPLEK.
func _spook_zet(bedrag: int, label: String) -> void:
	var m: Array = ctx.econ.splits(maxi(0, bedrag))
	var delen := PackedStringArray()
	for i in mini(m.size(), 4):
		delen.append(_eur(int(m[i])))
	var plek := Rooms.plek("receptie", 0.75, 0.625)
	var lbl := label if not label.is_empty() else T_SPOOK_UIT
	ctx.ui.wolk({"id": "mb_spook", "kamer": "receptie",
		"x": float(plek["x"]), "z": float(plek["z"]), "hoog": 6.0,
		"icoon": "🪙", "getal": " ".join(delen), "tekst": "",
		"klas": "hotspook hulp", "prio": 12, "titel": lbl,
		"tik": func(_s) -> void: Ui.spreek(lbl if not lbl.is_empty() else T_SPOOK_ZOVEEL)})

# ------------------------------------------------------------- de handelingen

func _leg_neer(v: int) -> void:
	if _bet.is_empty() or str(_bet["stap"]) == "som" or v <= 0:
		return
	var hand: Array = _bet["hand"]
	for i in hand.size():
		if int(hand[i]) == v:
			hand.remove_at(i)
			(_bet["bank"] as Array).append(v)
			_bet["hulp"] = ""
			if str(_bet["stap"]) == "wissel":
				_bet["stap"] = "munten"
				_bet["wis_pog"] = 0
				_bet["spook"] = {}
			if _heeft(v) == 0:
				_kies_soort(v)                # die soort is op: pak de volgende
			ctx.snd.munt()
			_betaal_teken()
			return
	# geen munt van deze soort meer: pak de volgende, zonder gemopper
	_kies_soort(v)
	_betaal_teken()

func _munt_terug() -> void:
	var bank: Array = _bet.get("bank", [])
	if _bet.is_empty() or bank.is_empty():
		return
	var hand: Array = _bet["hand"]
	hand.append(bank.pop_back())
	hand.sort()
	hand.reverse()
	_bet["hulp"] = ""
	_bet["spook"] = {}
	if str(_bet["stap"]) == "wissel":
		_bet["stap"] = "munten"
		_bet["wis_pog"] = 0
	ctx.snd.terug()
	_betaal_teken()

func _som_ok(n) -> void:
	if _bet.is_empty():
		return
	if n == null:
		_tip_getal()
		return
	if int(n) == int(_bet["totaal"]):
		var kaart = _bet["kaart"]
		if kaart != null:
			kaart.zet(_eur(int(n)))
			kaart.klaar()
		_bet["stap"] = "munten"
		ctx.snd.ja()
		_na_som()
		return
	_bet["som_pog"] = int(_bet["som_pog"]) + 1
	ctx.snd.zacht()
	_betaal_teken()

func _na_som() -> void:
	if not await na(0.45):
		return
	if not _bet.is_empty() and str(_bet["stap"]) == "munten":
		_betaal_teken()

func _tip_getal() -> void:
	var b: Dictionary = World.mik("kassa", "receptie")
	_wolk({"kamer": "receptie", "x": float(b.get("x", 60)), "z": float(b.get("z", 20))},
		{"id": "mb_tip", "icoon": "☝", "tekst": T_TIK_GETAL, "klas": "hulp", "hoog": 34.0})
	ctx.wereld.vuil()

func _klaar_met_tellen() -> void:
	if _bet.is_empty():
		return
	if str(_bet["stap"]) == "wissel":
		var kaart = _bet["kaart"]
		_wissel_ok(null if kaart == null else kaart.getal())
		return
	var t := _som(_bet["bank"])
	var p := int(_bet["totaal"])
	if t == p:
		_betaald(0)
		return
	if t < p:                                   # nog niet genoeg: samen doortellen
		_bet["tel_pog"] = int(_bet["tel_pog"]) + 1
		var mist := p - t
		_bet["hulp"] = "🪙 +%s\n%s" % [_eur(mist), _door_tellen(t, mist)]
		_bet["spook"] = {"bedrag": mist, "label": T_SPOOK_BIJ} \
			if int(_bet["tel_pog"]) >= 3 else {}
		ctx.snd.zacht()
		_betaal_teken()
		return
	if Sommen.Meubels.wisselgeld(_band()):      # groep 4/5: wisselgeld uitrekenen
		_bet["stap"] = "wissel"
		_bet["wis_pog"] = 0
		_bet["hulp"] = ""
		_bet["spook"] = {}
		_betaal_teken()
		return
	# groep 3 rekent nog geen wisselgeld: precies leggen, munt terugpakken mag
	_bet["tel_pog"] = int(_bet["tel_pog"]) + 1
	_bet["hulp"] = "« %s te veel" % _eur(t - p)
	_bet["spook"] = {"bedrag": p, "label": T_SPOOK_MOET} \
		if int(_bet["tel_pog"]) >= 3 else {}
	ctx.snd.zacht()
	_betaal_teken()

func _wissel_ok(n) -> void:
	if _bet.is_empty():
		return
	var goed := _som(_bet["bank"]) - int(_bet["totaal"])
	if n == null:
		_tip_getal()
		return
	if int(n) == goed:
		_betaald(goed)
		return
	_bet["wis_pog"] = int(_bet["wis_pog"]) + 1
	ctx.snd.zacht()
	_betaal_teken()

## Betaald!  De munten gaan uit de kassa, het meubel gaat in de doos en er is
## één ster voor het meedoen — nooit voor goed rekenen (F5).
func _betaald(wissel: int) -> void:
	var q := _q()
	var types: Array = _bet["types"]
	var totaal := int(_bet["totaal"])
	var missers := int(_bet["som_pog"]) + int(_bet["tel_pog"]) + int(_bet["wis_pog"])
	ctx.econ.geef_munt(-totaal)
	ctx.state.tel(missers == 0, Time.get_ticks_msec() - _t0)
	_zet_nog(types.duplicate())
	q["gekocht"] = int(q.get("gekocht", 0)) + types.size()
	_lijst = []
	_bet = {}
	ctx.snd.tover()
	# architecture.md §13 Q-X2-2: het kaartje heet `meubels`, dus dat is de naam
	# die hier meegaat; `taak_klaar` vinkt ook op de spel-id af.
	ctx.taak_klaar("meubels", {"sterren": 1})
	State.bewaar()
	Hotel.render()
	_leeg_wereld()
	var b: Dictionary = World.mik("kassa", "receptie")
	_wolk({"kamer": "receptie", "x": float(b.get("x", 60)), "z": float(b.get("z", 20))},
		{"id": "mb_af", "icoon": "💰" if wissel > 0 else "✅",
		"getal": _eur(wissel) if wissel > 0 else _eur(totaal),
		"tekst": T_TERUG if wissel > 0 else T_BETAALD,
		"klas": "goed", "hoog": 30.0, "prio": 12})
	print("[probe] mb=betaald totaal=", totaal, " wissel=", wissel,
		" missers=", missers, " sterren=", int(State.s["sterren"]),
		" munten=", _munten())
	ctx.wereld.vuil()
	_na_betaald()

func _na_betaald() -> void:
	if not await na(1.2):
		return
	ctx.ui.wolk_weg("mb_af")
	_plaats()

# ==================================================================================
# BLADZIJDE 3 — NEERZETTEN OP HET VOXELRASTER (games-a.md §5.7)
# ==================================================================================

func _plaats() -> void:
	_view = "plaats"
	_bet = {}
	_blad_stil = true
	Ui.blad_dicht()                     # geen blad: de kamer is het speelvlak
	_blad_stil = false
	if _nog().is_empty():
		_boek()
		return
	if ctx.wereld.actief() == "receptie":
		Hotel.naar_kamer(_thuis)
	_plaats_teken()

func _plaats_teken() -> void:
	if not actief or _view != "plaats":
		return
	var nog := _nog()
	if nog.is_empty():
		_boek()
		return
	var w := _artikel(str(nog[0]))
	if w.is_empty():
		w = Sommen.Meubels.WINKEL[0]
	var nu: String = ctx.wereld.actief()
	ctx.hotspots.wis_alles()

	# DE DOOS reist met je mee: zijn `volg()` zet hem in de ruimte waar je nu
	# staat, dus loop je door een deur, dan loopt hij achter je aan.
	var dp := _doos_plek(nu)
	ctx.hotspots.bron({"x": dp["x"], "z": dp["z"]}, {
		"id": "mb_doos", "kamer": nu, "hoog": 16.0, "prio": 11,
		"icoon": "📦%s" % str(w["icoon"]), "aantal": nog.size(),
		"titel": "%s neerzetten" % str(w["naam"]),
		"sleep": "mbdoos", "klas": "hotbron",
		"volg": func() -> Dictionary:
			var k := World.kamer_nu()
			var p := _doos_plek(k)
			return {"x": p["x"], "z": p["z"], "y": 16.0, "kamer": k},
		"tik": func(_s) -> void:
			var p := _doos_plek(World.kamer_nu())
			_wolk({"kamer": World.kamer_nu(), "x": p["x"], "z": p["z"]},
				{"id": "mb_tip", "icoon": "✨", "tekst": T_SLEEP,
				"klas": "hulp", "hoog": 30.0})
			ctx.wereld.vuil()})

	# de vrije vakjes van DEZE ruimte, hooguit vier tegelijk
	var alle := _vakjes(nu)
	if _vak_offset >= alle.size():
		_vak_offset = 0
	var vak_max := _vak_max()
	for i in mini(vak_max, alle.size()):
		var v: Dictionary = alle[(_vak_offset + i) % alle.size()]
		var vx := float(v["x"])
		var vz := float(v["z"])
		ctx.hotspots.maak({"id": "mbvak_%s_%s" % [nu, str(v["id"])], "kamer": nu,
			"x": vx, "z": vz, "y": 0.0,
			"icoon": "✨", "label": W_HIER, "titel": T_HIER, "prio": 9,
			"kind": "drop", "drop": "mbdoos", "klas": "hotgame",
			"data": {"kamer": nu, "x": vx, "z": vz},
			"val": func(_lading, data) -> void:
				_zet_neer(str(data["kamer"]), float(data["x"]), float(data["z"])),
			"aan": func(_s) -> void: _zet_neer(nu, vx, vz)})
	if alle.size() > vak_max and _meer_knop():
		var v: Dictionary = alle[(_vak_offset + vak_max) % alle.size()]
		var aantal := alle.size()
		ctx.hotspots.maak({"id": "mb_meer", "kamer": nu,
			"x": float(v["x"]), "z": float(v["z"]), "y": 0.0,
			"icoon": "▸", "label": W_MEER, "klas": "hotwolk", "prio": 8,
			"titel": T_MEER,
			"aan": func(_s) -> void:
				_vak_offset = (_vak_offset + vak_max) % aantal
				ctx.snd.tik()
				_plaats_teken()})
	ctx.wereld.vuil()
	_meld_plaats(nu, alle.size())

func _meld_plaats(kamer_id: String, vakken: int) -> void:
	if not await na(0.1) or _view != "plaats":
		return
	print("[probe] mb=plaats kamer=", kamer_id, " nog=", _nog().size(),
		" vakjes=", vakken)
	for id in Hits.lijst():
		if not id.begins_with("mb"):
			continue
		var s := Hits.spot(id)
		if s != null and is_instance_valid(s.knoop) and s.knoop.visible:
			print("[probe] mb=hot ", id, "=", s.knoop.get_global_rect(),
				" dekking=", "%.2f" % Hits.dekking(id))

## De doos staat vooraan in de ruimte, uit de weg van de deur.
func _doos_plek(kamer_id: String) -> Dictionary:
	var r: Rooms.Kamer = ctx.wereld.kamer(kamer_id)
	if r == null:
		return {"x": 30.0, "z": 60.0}
	return {"x": float(JsGetal.rond(r.w * 0.26)), "z": float(JsGetal.rond(r.d * 0.88))}

## De vrije vakjes, netjes uit elkaar en op volgorde van de deur af: wat het
## dichtst bij binnenkomen ligt zie je het eerst.
func _vakjes(kamer_id: String) -> Array:
	var r: Rooms.Kamer = ctx.wereld.kamer(kamer_id)
	if r == null:
		return []
	var dx := float(r.w) / 2.0
	var dz := float(r.d) / 2.0
	for naar in r.deur_punten:
		var punt: Dictionary = r.deur_punten[naar]
		dx = float(punt.get("ix", punt.get("x", dx)))
		dz = float(punt.get("iz", punt.get("z", dz)))
		break                                      # het eerste deurpunt telt
	var vrij: Array = r.vrij.duplicate()
	vrij.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return absf(a["x"] - dx) + absf(a["z"] - dz) \
			< absf(b["x"] - dx) + absf(b["z"] - dz))
	var uit: Array = []
	for cel in vrij:
		var ver := true
		for p in uit:
			if absf(float(p["x"]) - float(cel["x"])) \
					+ absf(float(p["z"]) - float(cel["z"])) < VAK_AF:
				ver = false
				break
		if ver:
			uit.append(cel)
	return uit

func _zet_neer(kamer_id: String, x: float, z: float) -> void:
	var q := _q()
	var nog := _nog()
	if nog.is_empty() or ctx.wereld.kamer(kamer_id) == null:
		return
	var type := str(nog[0])
	var w := _artikel(type)
	# Een bed erbij loopt via voegBed: dat verhoogt meteen de gastenlimiet.
	var m: Dictionary = ctx.wereld.voeg_bed(kamer_id, {"x": x, "z": z, "rot": 0}) \
		if type == "bed" else ctx.wereld.plaats_meubel(kamer_id, type, x, z, 0)
	if m.is_empty():
		_bezet(kamer_id, x, z)
		return
	(q["mijn"] as Array).append({"id": _meubel_id(m), "type": type})
	nog.remove_at(0)
	_zet_nog(nog)
	ctx.snd.plop(2)
	State.bewaar()
	Hotel.render()
	print("[probe] mb=neer type=", type, " kamer=", kamer_id,
		" bedden=", ctx.state.max_gasten(), " nog=", _nog().size())
	if _nog().is_empty():
		_boek()
	else:
		_plaats_teken()
	# feedback als pictogram + getal: een bed betekent een gast erbij
	if type == "bed":
		_wolk({"kamer": kamer_id, "x": float(m["x"]), "z": float(m["z"])},
			{"id": "mb_neer", "icoon": "🐾", "getal": ctx.state.max_gasten(),
			"tekst": T_GASTEN, "klas": "goed", "hoog": 26.0, "prio": 12})
	else:
		_wolk({"kamer": kamer_id, "x": float(m["x"]), "z": float(m["z"])},
			{"id": "mb_neer", "icoon": str(w["icoon"]), "getal": "✓",
			"klas": "goed", "hoog": 22.0, "prio": 12})
	ctx.wereld.vuil()
	_wolk_straks("mb_neer", 2.4)

func _bezet(kamer_id: String, x: float, z: float) -> void:
	ctx.snd.zacht()
	_wolk({"kamer": kamer_id, "x": x, "z": z},
		{"id": "mb_bezet", "icoon": "🚫", "tekst": T_BEZET, "klas": "hulp",
		"hoog": 26.0, "prio": 11})
	ctx.wereld.vuil()
	_wolk_straks("mb_bezet", 2.2)

func _wolk_straks(id: String, seconden: float) -> void:
	if not await na(seconden):
		return
	ctx.ui.wolk_weg(id)
	ctx.wereld.vuil()
