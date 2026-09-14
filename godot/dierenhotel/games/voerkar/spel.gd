extends MiniGame
## DE VOERKAR — games-a.md §7, de referentie-implementatie van HOTEL.md §9.
##
## Twee fasen.  **Vullen** in de keuken: op de voerkast hangt één sommenkaartje
## met de opdracht in twee gewone zinnen, uit de zak komen koekjes die je over
## de bakjes op de vloer verdeelt, met de rest in de snoeppot.  **Het rondje**:
## zodra de kar klopt sleep je hem door het hotel en vul je de bakjes in de
## kamers.
##
## Wat deze poort anders doet dan de HTML (architecture.md §1.2, §4.3):
##  * de plaatser (`pakker`, STAP_X/PAD_X/PAD_Y, vier ontwijkrondes, het
##    terugrekenen van schermpixels naar voxels) is weg.  Elk kaartje hangt aan
##    zijn eigen voorwerp en het bandenraster van `Hits` zet het in de band
##    ernaast — 0 % dekking per constructie in plaats van per iteratie;
##  * de bakjes zijn eigen los decor (`voerkar_bakje`, hetzelfde voxelmodel als
##    de voerbak van de wereld) in plaats van tijdelijke meubels: los decor gaat
##    niet mee in de savegame en wordt door `Games.stop()` opgeruimd, dus de
##    keuken kan nooit met zeven bakjes achterblijven;
##  * de kar-toestand blijft in `state.kar` (games-a.md §7.2, §8.6) en staat
##    daarnaast in `ctx.data()["kar"]`, zodat beide herstelwegen hetzelfde
##    woordenboek teruggeven.
##
## Bindend en ongewijzigd: de getallen (`Sommen.deel`, `Sommen.Voerkar.*`), elke
## kindtekst, de hulpladder (Els vanaf twee missers, en ze blijft staan), nooit
## straffen (alleen `zacht()`), één ster voor het meedoen.

# --------------------------------------------------------------- vaste maten

const KAMER := "keuken"
const MODEL_BAKJE := "voerkar_bakje"
const HAND: Array = Sommen.Voerkar.HAND      ## [1, 2, 5]
## Zes bakjes, dus hoogstens zes gasten doen mee (games-a.md §7.3).  De HTML
## zette ook maar zes bakjes neer maar keurde daarna élke gast, waardoor een
## hotel met zeven gasten nooit "klaar" kon zijn; hier telt wie een bakje heeft.
const SPELERS_MAX := 6
## De bakjes staan op breuken van de kamer, in twee kolommen (x−z ≈ −60 en +72).
const VAKBREUK := [[0.05, 0.5789], [0.65, 0.0526], [0.25, 0.7895],
	[0.85, 0.2632], [0.4, 0.9474], [0.95, 0.3684]]
const POTBREUK := [0.6, 0.6316]
## Het komvoxelmodel ligt rond (29.5, 7.5); zo verschoven valt zijn midden op
## het punt waar het decorstuk staat (architecture.md §3.3).
const BAK_DX := 30
const BAK_DZ := 8
const SMUL_MS := 2.6                          ## nagenieten, games-a.md §7.6
const LEEG_MS := 1.8                          ## "nog geen gasten"
const MINI_VLAK := 140000.0                   ## kader waarop de strook vervalt

const SOORT_ICO := {"puppy": "🐶", "poes": "🐱", "konijn": "🐰", "gans": "🦆"}
const KIND_ICO := {"hond": "🐶", "poes": "🐱", "konijn": "🐰", "gans": "🦆"}
const DIER_ONBEKEND := "🐾"

# ------------------------------------------------ kindteksten (F3, §7.7)

const T_GEEN_GASTEN := "nog geen gasten"
const T_VERDEEL := "Verdeel %d koekjes over %s"
const T_IEDER := "🫙 Ieder evenveel, de rest in de pot"
const T_ELS_ZIN := "🩺 Iedereen %d, rest in de pot"
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
const T_ELS := "Els helpt"
const T_ELS_TITEL := "buurvrouw Els doet het voor"
const T_KAR_NOG := "nog %d %s"
const T_KAMER := "kamer"
const T_KAMERS := "kamers"
const T_KAR_TITEL := "de voerkar: nog %d %s"
const T_KAR_LEEG := "kar is leeg"
const T_KAR_LEEG_TITEL := "de voerkar is leeg"
const T_SLEEP_DEUR := "Sleep de kar naar een deur"
const T_SLEEP_HIER := "Sleep de kar hierheen"
const T_BRENG := "Breng %d koekjes naar elke gast"
const T_ALLE_VOL := "Alle bakjes vol!"
const T_KOEKJES := "koekjes"
const T_KOEKJES_ELK := "koekjes elk"
const T_KEUZE_TITEL := "hoeveel pak je per tik"

const ICO_KOEK := "🍪"
const ICO_POT := "🫙"
const ICO_ELS := "🩺"
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

# --------------------------------------------------------------- toestand

var K: Dictionary = {}            ## state.kar; zie games-a.md §7.2
var _kaart = null                 ## Ui.Kaart
var _af_kader: Callable = Callable()
var _mini := false
var _krap := false
var _kort := 0
var _sluit_bezig := false
var _laatste_vorm := ""           ## mini|krap|kort, om alleen bij verandering te hertekenen

# ------------------------------------------------------------- aanmelding

func definitie() -> Dictionary:
	return {
		"naam": "De voerkar",
		"kamer": KAMER,
		"hotspot": {"obj": "kar", "icoon": ICO_KAR, "label": "Voerkar", "hoog": 16},
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		# geen eigen taakkaartje: het hotel heeft er al één ("🍪 Vul de voerkar",
		# prikbord.gd), en dat vinkt `taak_klaar("voer")` af.
	}

# ------------------------------------------------------------------ start

func start(_c: SpelCtx) -> void:
	Art.registreer_model(MODEL_BAKJE, _bakje_model)
	_af_kader = ctx.ui.op_kader(_op_kader)
	var g := deelnemers()
	if g.is_empty():
		_geen_gasten()
		return
	_lees_kar(g)
	if bool(K.get("vol", false)):
		_rondje()
	else:
		_teken()

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

func stop() -> void:
	if _af_kader.is_valid():
		_af_kader.call()
		_af_kader = Callable()
	_bakjes_weg()
	_kaart = null
	if ctx != null:
		ctx.hotspots.laat()
		_bewaar_kar()
		ctx.wereld.vuil()

## Zolang het rondje loopt zijn de bakjes en de deuren van het hotel even van de
## voerkar.  `Hotel.render()` bouwt die knoppen opnieuw op (bij elke levering,
## bij elke kamerwissel), dus het lenen wordt elk beeld opnieuw bevestigd.
func _process(_dt: float) -> void:
	if not actief or K.is_empty() or not bool(K.get("vol", false)):
		return
	_leen_doelen()

# ------------------------------------------------------- gasten en toestand

## De gasten die meedoen: iedereen met een bed, hoogstens zoveel als er bakjes
## zijn (games-a.md §7.3: zes plekken op de keukenvloer).
func deelnemers() -> Array:
	var uit: Array = []
	for g in ctx.state.s["gasten"]:
		if str(g.get("bed", "")).is_empty():
			continue
		uit.append(g)
		if uit.size() >= SPELERS_MAX:
			break
	return uit

func _lees_kar(g: Array) -> void:
	var bewaard = ctx.state.s.get("kar", null)
	if typeof(bewaard) != TYPE_DICTIONARY:
		bewaard = ctx.data().get("kar", null)
	if typeof(bewaard) == TYPE_DICTIONARY and int(bewaard.get("T", 0)) > 0:
		K = _herstel(bewaard)
	else:
		var som := Sommen.deel(g.size(), ctx.state.band(), int(ctx.state.s["dag"]))
		K = {
			"T": int(som["T"]), "per": int(som["k"]), "rest": int(som["r"]),
			"zak": int(som["T"]), "vak": {}, "pot": 0, "hand": HAND[0],
			"missers": 0, "vol": false, "geleverd": {}, "spook": 0,
			"feedback": false, "zakZeg": "", "t0": Time.get_ticks_msec(),
		}
	for q in g:
		if not (K["vak"] as Dictionary).has(str(q["id"])):
			K["vak"][str(q["id"])] = 0
	_bewaar_kar()

## JSON kent geen gehele getallen: alles komt als komma-getal terug (state.gd
## laat `kar` bewust met rust).  Eén keer terugrekenen, dan telt de rest weer.
func _herstel(d: Dictionary) -> Dictionary:
	var uit := {
		"T": int(d.get("T", 0)), "per": maxi(1, int(d.get("per", 1))),
		"rest": int(d.get("rest", 0)), "zak": int(d.get("zak", 0)),
		"pot": int(d.get("pot", 0)), "hand": int(d.get("hand", HAND[0])),
		"missers": int(d.get("missers", 0)), "spook": int(d.get("spook", 0)),
		"vol": bool(d.get("vol", false)), "feedback": bool(d.get("feedback", false)),
		"zakZeg": str(d.get("zakZeg", "")), "vak": {}, "geleverd": {},
		"t0": int(d.get("t0", Time.get_ticks_msec())),
	}
	if not HAND.has(uit["hand"]):
		uit["hand"] = HAND[0]
	var vak = d.get("vak", {})
	if typeof(vak) == TYPE_DICTIONARY:
		for id in vak:
			uit["vak"][str(id)] = int(vak[id])
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

# ------------------------------------------------------------- de bakjes

## Het eigen voxelmodel: de voerbak van de wereld, verschoven zodat zijn midden
## op het decorpunt valt.  `niveau` 0..4 bepaalt hoeveel brokjes erin liggen.
func _bakje_model(params: Dictionary) -> Array:
	var niv := clampi(int(params.get("niveau", 0)), 0, 4)
	var uit: Array = []
	for v in ArtGasten.kom_vox(niv, true):
		var q: Dictionary = (v as Dictionary).duplicate()
		q["x"] = int(q["x"]) - BAK_DX
		q["z"] = int(q["z"]) - BAK_DZ
		uit.append(q)
	return uit

func bak_plek(i: int) -> Dictionary:
	if i < 0:
		return Rooms.plek(KAMER, POTBREUK[0], POTBREUK[1])
	var b: Array = VAKBREUK[i % VAKBREUK.size()]
	return Rooms.plek(KAMER, b[0], b[1])

func _bak_id(i: int) -> String:
	return "vk_bak_pot" if i < 0 else "vk_bak_%d" % i

## Zet (of ververst) één bakje als los decor, op het niveau dat erin ligt.
func _bakje_zet(i: int, aantal: int) -> Dictionary:
	var p := bak_plek(i)
	# het waterpeil van een bakje: `niveau(n) = n ? max(1, min(4, ceil(n/per*4))) : 0`
	var doel := int(K["rest"]) if i < 0 else int(K["per"])
	var niv: int = ctx.wereld.voer_niveau(aantal, maxi(1, doel))
	ctx.wereld.decor(KAMER, {"id": _bak_id(i), "model": MODEL_BAKJE,
		"x": float(p["x"]), "z": float(p["z"]), "hoog": 0.0,
		"params": {"niveau": niv}})
	return p

func _bakjes_weg() -> void:
	for i in range(-1, VAKBREUK.size()):
		ctx.wereld.decor_weg(KAMER, _bak_id(i))
	ctx.wereld.vuil()

# ------------------------------------------------------------- het tekenen

func _op_kader(_rect: Rect2, _schaal: Dictionary) -> void:
	if not actief or K.is_empty() or bool(K.get("vol", false)):
		return
	var voor := _laatste_vorm
	_meet_kader(deelnemers().size())
	if _laatste_vorm != voor:
		_teken()

## `mini` = het kader waarop de keuzestrook niet meer past; dan schakelt een tik
## op de zak de schep door en staat er `pak 2` op de zak zelf (games-a.md §7.2).
## `krap` kort de namen in zodra er veel bakjes staan.
##
## De HTML koos `mini` op oppervlak (140 000 px²), want zijn kader werd door de
## CSS-verhoudingen op een telefoon 326 x 312.  Hier is datzelfde kader 326 x 558
## en telt niet het oppervlak maar het BANDENRASTER: de strook is vier kolommen
## van de vijf breed, en met zes bakjes erbij past dat niet meer.  Vandaar de
## twee extra grenzen: smaller dan 360 of lager dan 400 eenheden.
func _meet_kader(n: int) -> void:
	var kader := World.kader_rect().size
	_mini = kader.x < 360.0 or kader.y < 400.0 or kader.x * kader.y < MINI_VLAK
	_krap = _mini or kader.y < 240.0 or n >= 5
	_kort = 4 if (_mini and n >= 4) else 0
	_laatste_vorm = "%d|%d|%d" % [1 if _mini else 0, 1 if _krap else 0, _kort]

func _teken() -> void:
	if not actief or K.is_empty() or bool(K.get("vol", false)):
		return
	ctx.hotspots.wis_alles()
	var g := deelnemers()
	_meet_kader(g.size())
	_kaart_neer(g)
	_knoppen_neer()
	_zak_neer()
	_bakjes_neer(g)
	ctx.wereld.vuil()
	_meld_probe("vullen")

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
			" open=", open.size())
	print("[probe] vk ", fase, " T=", int(K["T"]), " per=", int(K["per"]),
		" rest=", int(K["rest"]), " zak=", int(K["zak"]), " pot=", int(K["pot"]),
		" hand=", int(K["hand"]), " missers=", int(K["missers"]),
		" vol=", bool(K["vol"]), " geleverd=", (K["geleverd"] as Dictionary).size(),
		" band=", ctx.state.band(), " gasten=", deelnemers().size())
	for id in Hits.lijst():
		var s := Hits.spot(id)
		if s == null or not is_instance_valid(s.knoop) or not s.knoop.visible:
			continue
		if s.door == ctx.id:
			print("[probe] vk knop ", id, "=", (s.knoop as Control).get_global_rect(),
				" tekst=", str(s.knoop.text if "text" in s.knoop else "").replace("\n", " / "),
				" aantal=", (s.knoop as UiBron).aantal if s.knoop is UiBron else -1)
			# waar een sleep uit de zak moet landen: op het BAKJE, niet op het
			# kaartje — over het kaartje ligt de knop zelf
			var eigen: Rect2 = Hits.debug().get(id, {}).get("vlak", Rect2())
			if s.drop != "" and eigen.size.x > 0.0 and Ui.knoplaag != null:
				print("[probe] vk doel ", id, "=",
					Rect2(Ui.knoplaag.get_global_rect().position + eigen.position, eigen.size))
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

## Eén kaartje: pictogram, woord, getal en — na een misser — het staartje
## "· 8 erbij", met als Els meekijkt haar doelgetal erachter.
##
## Krap of met Els erbij zet het staartje zich ONDER de naam in plaats van
## erachter (games-a.md §7.3).  Gemeten: "🐶 Boef 12 · 8 eraf" is 134 eenheden
## breed op één regel en 85 op twee, terwijl de knop maar van 48 naar 52 hoog
## gaat — precies één band.  Zo passen er twee kaartjes naast elkaar waar er
## anders één stond.
func _chip(woord: String, getal, staart: String, doel) -> String:
	var twee := (_krap or doel != null) and not woord.is_empty() and not staart.is_empty()
	var kop := woord
	if getal != null:
		kop += " " + str(getal)
	if staart.is_empty():
		return kop
	var staartje := "· " + staart
	if doel != null:
		staartje += " " + (("▸ %d" % int(doel)) if Ui.heeft_teken(0x25B8) else ("(%d)" % int(doel)))
	return kop + ("\n" if twee else " ") + staartje

## Hoe hoog een kaartje wordt: één regel is 48 (het tikdoel), twee regels 52.
func _chip_hoog(tekst: String) -> float:
	return 52.0 if tekst.contains("\n") else 48.0

func _naam_kort(naam: String) -> String:
	return naam.substr(0, _kort) if _kort > 0 and naam.length() > _kort else naam

func _dier_ico(g: Dictionary) -> String:
	if g.is_empty():
		return DIER_ONBEKEND
	if SOORT_ICO.has(str(g.get("soort", ""))):
		return SOORT_ICO[str(g.get("soort", ""))]
	if KIND_ICO.has(str(g.get("kind", ""))):
		return KIND_ICO[str(g.get("kind", ""))]
	return DIER_ONBEKEND

func _opnieuw_ico() -> String:
	return ICO_OPNIEUW if Ui.heeft_teken(0x21A9) else ICO_OPNIEUW_TERUG

# ---------------------------------------------------------- de opdrachtkaart

func _zinnen(n: int) -> Array:
	return [T_VERDEEL % [int(K["T"]), Ui.meervoud(n, "gast", "gasten")],
		(T_ELS_ZIN % int(K["per"])) if int(K["spook"]) > 0 else T_IEDER]

func som_regel(n: int) -> String:
	return Sommen.Voerkar.som_regel(ctx.state.band(), int(K["T"]), n, int(K["rest"]))

func _kaart_neer(g: Array) -> void:
	var zin := _zinnen(g.size())
	var som := som_regel(g.size())
	var keuzes: Array = []
	if not _mini:
		for h in HAND:
			keuzes.append({"id": "h%d" % int(h), "icoon": ICO_KOEK,
				"tekst": T_PAK % int(h), "kort": T_PAK % int(h), "kies": _kies_hand})
	# De kaart hángt op de voerkast (games-a.md §7.1), dus ze mag hem afdekken.
	# Daarom een kaal punt naast de kast in plaats van het voorwerp zelf: met de
	# kast als voorwerp houdt het bandenraster de kaart eraf, en in een liggend
	# kader (558 x 289) duwt die 92 eenheden hoge plaat de kaart tot onderin,
	# dwars door de twee kolommen bakjes heen.  Zo staat ze bovenaan en houdt
	# elk bakje zijn eigen rij.
	_kaart = ctx.ui.somkaart(_kaart_punt(), som, {
		"id": "vk_kaart", "kamer": KAMER, "hoog": 30.0, "icoon": ICO_KOEK,
		"regel": zin[0], "regel2": zin[1], "pad": false, "prio": 14,
		"titel": "%s. %s" % [zin[0], zin[1]],
		"keuze_titel": T_KEUZE_TITEL, "keuzes": keuzes,
	})
	# `somkaart` tekent de somrij altijd en zet zonder strook een leeg
	# antwoordvakje neer; band 3 heeft geen somregel en er valt niets te typen.
	var kk := _kaart_knoop()
	if kk != null:
		if kk.som_label != null:
			kk.som_label.visible = not som.is_empty()
		if kk.vak_label != null:
			kk.vak_label.visible = false
	_kleur_hand()

## Hoe hoog een kaartje boven zijn voorwerp hangt.
##
## Op een krap kader zijn de kaartjes `vast` (games-a.md §7.4): ze staan op hun
## mikpunt en wijken alleen omhoog of omlaag, in stappen van één band (52).  Twee
## kaartjes waarvan de mikpunten een halve band schelen kunnen elkaar dan nooit
## ontlopen — ze schuiven allebei mee.  Daarom krijgt elk kaartje de hoogte die
## zijn bovenkant precies op het bandenraster zet: dan tegelen ze, in plaats van
## elkaar half te overlappen.  Dit is een SNAP, geen zoektocht: één formule, geen
## ontwijkrondes, geen kostfunctie.
##
## De hoogte kan alleen omhoog (hooguit één band, ±27 voxels), dus een kaartje
## blijft altijd boven zijn eigen bakje hangen.
func _snap_hoogte(x: float, z: float, basis: float, knop_hoog := 48.0) -> float:
	if not _mini:
		return basis
	var y0 := World.mik_punt(x, z, 0.0).y
	var per := y0 - World.mik_punt(x, z, 1.0).y     ## schermeenheden per voxel hoogte
	if per <= 0.01:
		return basis
	var top := (y0 - basis * per) - knop_hoog * 0.5
	var n := floorf((top - float(Hits.RAND)) / float(Hits.RIJ))
	var doel := float(Hits.RAND) + n * float(Hits.RIJ)
	return basis + (top - doel) / per

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

## De knop die aan staat krijgt de peach-kleur van het hotel — nooit een ✅,
## dat teken betekent in dit spel "klaar" (games-a.md §7.2).
func _kleur_hand() -> void:
	if _kaart == null or String(_kaart.strook_id).is_empty():
		return
	var s := Hits.spot(_kaart.strook_id)
	if s == null or not is_instance_valid(s.knoop):
		return
	var knop := s.knoop.get_node_or_null("Rij/Kh%d" % int(K["hand"]))
	if knop is Button:
		(knop as Button).add_theme_stylebox_override("normal",
			UiThema.vulling(UiThema.vlak(UiThema.PERZIK, 14, 2, UiThema.PERZIK_D), 8, 6))

func _kies_hand(id: String) -> void:
	for h in HAND:
		if id == "h%d" % int(h):
			zet_hand(int(h))
			return

func zet_hand(h: int) -> void:
	K["hand"] = h
	_bewaar_kar()
	_teken()

func volgende_hand() -> int:
	return Sommen.Voerkar.volgende_hand(int(K["hand"]))

# ---------------------------------------------------------------- de zak

func _zak_neer() -> void:
	var zak := int(K["zak"])
	var hand := int(K["hand"])
	var zeg := str(K["zakZeg"])
	var titel := T_ZAK_TITEL % [zak, hand]
	if not zeg.is_empty():
		titel += " (%s)" % zeg
	ctx.hotspots.bron("zak", {
		"id": "vk_zak", "kamer": KAMER, "icoon": ICO_KOEK, "hoog": 16.0,
		"aantal": zak, "hand": 0, "prio": 10, "titel": titel,
		"klas": "hotbron hotwolk" + ("" if zak > 0 else " leeg") + ("" if zeg.is_empty() else " hulp"),
		"sleep": "vak", "data": {}, "tik": _tik_zak,
	})
	# `Ui.bron` kent `vast` niet, en de zak hoort er wel toe (games-a.md §7.4):
	# hij wijkt nooit, de rest schuift om hem heen.  Zie "Contract gaps".
	var s := Hits.spot("vk_zak")
	if s != null:
		s.vast = false
	var b := Ui.bron_van("vk_zak")
	if b != null:
		b.text = "%s %s" % [ICO_KOEK, _chip(T_PAK % hand, null, zeg, null)]
		b.add_theme_font_size_override("font_size", int(Ui.maten.get("klein", 13)))
	if not zeg.is_empty():
		_verf("vk_zak", UiThema.WOLK_HULP)

## Een tik op de zak schakelt de schep door (1 → 2 → 5).  Op een klein kader is
## dat de enige weg, want dan is er geen keuzestrook (games-a.md §7.2).
func _tik_zak(_s = null) -> void:
	zet_hand(volgende_hand())

# --------------------------------------------------------------- de bakjes

func _bakjes_neer(g: Array) -> void:
	for i in g.size():
		_bakje_hotspot(i, g[i])
	_bakje_hotspot(-1, {})

func _bakje_hotspot(i: int, gast: Dictionary) -> void:
	var pot := i < 0
	var gast_id := "__pot" if pot else str(gast["id"])
	var aantal := int(K["pot"]) if pot else int((K["vak"] as Dictionary).get(gast_id, 0))
	var doel := int(K["rest"]) if pot else int(K["per"])
	var p := _bakje_zet(i, aantal)
	var mis := doel - aantal
	var staart := ""
	if bool(K["feedback"]) and mis != 0:
		staart = (T_ERBIJ % mis) if mis > 0 else (T_ERAF % (-mis))
	# Els zegt haar doelgetal waar het kind toch al kijkt; in een laag kader of
	# met ingekorte namen zegt alleen de kaart het (games-a.md §7.5).
	var mik = doel if (int(K["spook"]) > 0 and not staart.is_empty()
		and World.kader_rect().size.y >= 240.0 and _kort == 0) else null
	var ico := ICO_POT if pot else _dier_ico(gast)
	var woord := T_POT if pot else _naam_kort(str(gast.get("naam", "")))
	var titel := (T_POT_TITEL % aantal) if pot else (T_GAST_TITEL % [str(gast.get("naam", "")), aantal])
	if not staart.is_empty():
		titel += ", " + staart
	if mik != null:
		titel += ", " + (T_HIER_HOORT % int(mik))
	var regel := _chip(woord, aantal, staart, mik)
	ctx.hotspots.maak({
		"id": "vk_%s" % gast_id, "kamer": KAMER,
		"x": float(p["x"]), "z": float(p["z"]),
		"y": _snap_hoogte(float(p["x"]), float(p["z"]), 10.0, _chip_hoog(regel)),
		"icoon": ico, "label": regel,
		"titel": titel, "kind": "drop", "drop": "vak",
		"data": {"id": gast_id}, "val": _val_vak,
		"klas": "hotbron hotwolk" + ("" if staart.is_empty() else " hulp"),
		"prio": 9 if pot else 10, "vast": _mini,
		"aan": _tik_bakje.bind(gast_id),
	})
	if not staart.is_empty():
		_verf("vk_%s" % gast_id, UiThema.WOLK_HULP)

func _tik_bakje(_s, gast_id: String) -> void:
	verplaats(gast_id, int(K["hand"]))

func _val_vak(_lading: Dictionary, data: Dictionary) -> void:
	verplaats(str(data.get("id", "")), int(K["hand"]))

# --------------------------------------------------------------- de knoppen

## De drie knoppen staan rond de kar.  Ze krijgen elk een eigen punt: een vaste
## knop wijkt alleen omhoog of omlaag, dus drie knoppen op één punt vechten om
## dezelfde kolom.  ±14 voxels langs de diagonaal is op het scherm ruim een
## halve knop opzij, en blijft ver van elk bakje vandaan.
func _knoppen_neer() -> void:
	var kar: Dictionary = ctx.wereld.ding("kar")
	var x := float(kar.get("x", 48.0))
	var z := float(kar.get("z", 66.0))
	var ox := clampf(x - 14.0, 6.0, 114.0)
	var oz := clampf(z + 14.0, 6.0, 108.0)
	var ex := clampf(x + 14.0, 6.0, 114.0)
	var ez := clampf(z - 14.0, 6.0, 108.0)
	ctx.hotspots.maak({"id": "vk_klaar", "kamer": KAMER, "x": x, "z": z,
		"y": 16.0,
		"icoon": ICO_KAR, "label": T_KLAAR, "titel": T_KLAAR_TITEL,
		"klas": "hotwolk goed", "prio": 11, "aan": _tik_klaar})
	_verf("vk_klaar", UiThema.WOLK_GOED)
	ctx.hotspots.maak({"id": "vk_opnieuw", "kamer": KAMER,
		"x": ox, "z": oz, "y": 16.0,
		"icoon": _opnieuw_ico(), "label": T_OPNIEUW, "titel": T_OPNIEUW_TITEL,
		"klas": "hotwolk", "prio": 7, "aan": _tik_opnieuw})
	# De hulp komt na twee pogingen en blijft daarna staan: een kind mag Els zo
	# vaak vragen als het wil (games-a.md §8.3).
	if int(K["missers"]) >= 2:
		ctx.hotspots.maak({"id": "vk_els", "kamer": KAMER,
			"x": ex, "z": ez, "y": 16.0,
			"icoon": ICO_ELS, "label": T_ELS, "titel": T_ELS_TITEL,
			"klas": "hotwolk hulp", "prio": 8, "aan": _tik_els})
		_verf("vk_els", UiThema.WOLK_HULP)

func _verf(id: String, kleur: Color) -> void:
	var s := Hits.spot(id)
	if s == null or not is_instance_valid(s.knoop):
		return
	s.knoop.add_theme_stylebox_override("normal",
		UiThema.vulling(UiThema.vlak(kleur, 16, 2, UiThema.WIT), 8, 6))

func _tik_klaar(_s = null) -> void:
	check()

func _tik_opnieuw(_s = null) -> void:
	opnieuw()

func _tik_els(_s = null) -> void:
	hulp()

# ------------------------------------------------------------- het vullen

## Slepen uit de zak naar een bakje, of tikken op een bakje: `min(hand, zak)`
## koekjes verhuizen.  Een lege zak is geen fout — de zak zegt het zelf.
func verplaats(id: String, aantal: int) -> void:
	if id.is_empty() or K.is_empty() or bool(K["vol"]):
		return
	var k := mini(aantal, int(K["zak"]))
	if k <= 0:
		K["zakZeg"] = T_ZAK_LEEG
		ctx.snd.zacht()
		_bewaar_kar()
		_teken()
		return
	K["zak"] = int(K["zak"]) - k
	if id == "__pot":
		K["pot"] = int(K["pot"]) + k
	else:
		K["vak"][id] = int((K["vak"] as Dictionary).get(id, 0)) + k
	K["feedback"] = false
	K["zakZeg"] = ""
	_bewaar_kar()
	_teken()
	ctx.snd.plop(int(K["hand"]))
	_kruimels(id)

## Crumbs fall into the bowl a scoop landed in (review plan pillar 4).
func _kruimels(id: String) -> void:
	var p := bak_plek(_bak_index(id))
	ctx.wereld.spetter(KAMER, float(p.get("x", 0.0)), float(p.get("z", 0.0)),
		ArtEffect.KRUIMEL_N, ArtEffect.KRUIMEL_KL, false, 6.0)

## Sparkles over every bowl: the sharing is right (pillar 4).
func _fonkel_bakjes() -> void:
	var n := deelnemers().size()
	for i in n:
		var p := bak_plek(i)
		ctx.wereld.spetter(KAMER, float(p.get("x", 0.0)), float(p.get("z", 0.0)),
			ArtEffect.STER_N * 2, ArtEffect.STER_KL[i % 2], true, 8.0)

## The bowl of a guest, in the order of `deelnemers()`; -1 for the pot.
func _bak_index(id: String) -> int:
	if id == "__pot":
		return -1
	var g := deelnemers()
	for i in g.size():
		if str(g[i]["id"]) == id:
			return i
	return -1

func opnieuw() -> void:
	if K.is_empty() or bool(K["vol"]):
		return
	for id in (K["vak"] as Dictionary).keys():
		K["vak"][id] = 0
	K["pot"] = 0
	K["zak"] = int(K["T"])
	K["feedback"] = false
	K["spook"] = 0
	K["zakZeg"] = ""
	_bewaar_kar()
	_teken()
	ctx.snd.terug()

## De vriendelijke controle: nooit een kruis, nooit terugzetten — een misser is
## `zacht()` plus één getal bij het bakje waar het over gaat (HOTEL.md §9).
func check() -> bool:
	if K.is_empty() or bool(K["vol"]):
		return false
	var g := deelnemers()
	if int(K["zak"]) > 0:
		K["missers"] = int(K["missers"]) + 1
		K["feedback"] = true
		K["zakZeg"] = T_NOG_IN_ZAK
		_bewaar_kar()
		_teken()
		ctx.snd.zacht()
		return false
	var goed := int(K["pot"]) == int(K["rest"])
	for q in g:
		if int((K["vak"] as Dictionary).get(str(q["id"]), 0)) != int(K["per"]):
			goed = false
	if not goed:
		K["missers"] = int(K["missers"]) + 1
		K["feedback"] = true
		_bewaar_kar()
		_teken()
		ctx.snd.zacht()
		return false
	K["vol"] = true
	K["feedback"] = false
	K["spook"] = 0
	K["zakZeg"] = ""
	ctx.state.s["snoeppot"] = int(ctx.state.s["snoeppot"]) + int(K["pot"])
	ctx.state.tel(int(K["missers"]) == 0, Time.get_ticks_msec() - int(K["t0"]))
	ctx.taak_klaar("voer", {"sterren": 1})
	ctx.snd.tover()
	_fonkel_bakjes()
	_bakjes_weg()
	_bewaar_kar()
	_rondje()
	return true

## Els doet het voor: haar doelgetal komt op de kaart én in elk bakje, zonder
## één extra knop (games-a.md §7.5 — vroeger viel de helft weg door het
## plafond van 16 knoppen per kamer).
func hulp() -> void:
	if K.is_empty() or bool(K["vol"]):
		return
	K["spook"] = 1
	_bewaar_kar()
	_teken()
	ctx.state.zet_gezien("voerkar_els")
	ctx.snd.brief()

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

func _op_kar() -> int:
	var n := 0
	for id in (K["vak"] as Dictionary).keys():
		n += int(K["vak"][id])
	return n

func _rondje() -> void:
	if not actief or K.is_empty():
		return
	ctx.hotspots.wis_alles()
	var open := open_kamers()
	_kar_hotspot(open.size())
	_leen_doelen()
	if open.is_empty():
		ctx.ui.wolk({"id": "vk_af", "kamer": World.kamer_nu(),
			"x": _kar_x(), "z": _kar_z(), "hoog": 22.0, "icoon": ICO_VOL,
			"tekst": T_ALLE_VOL, "klas": "goed", "prio": 12,
			"volg": _volg_kar(22.0), "tik": _klaar_met_rondje})
		_sluit_straks()
	elif (K["geleverd"] as Dictionary).is_empty():
		ctx.ui.wolk({"id": "vk_duw", "kamer": World.kamer_nu(),
			"x": _kar_x(), "z": _kar_z(), "hoog": 30.0, "icoon": ICO_KAR,
			"tekst": T_BRENG % int(K["per"]), "prio": 10, "volg": _volg_kar(30.0)})
	ctx.wereld.vuil()
	_meld_probe("rondje")

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

## De kar is zelf een knop: sleep hem naar een deur (of op een bakje) en tik
## hem aan om te horen hoe dat moet.
func _kar_hotspot(open_n: int) -> void:
	var kar: Dictionary = ctx.wereld.ding("kar")
	if kar.is_empty():
		return
	var woord := T_KAMER if open_n == 1 else T_KAMERS
	var tekst := (T_KAR_NOG % [open_n, woord]) if open_n > 0 else T_KAR_LEEG
	var titel := (T_KAR_TITEL % [open_n, woord]) if open_n > 0 else T_KAR_LEEG_TITEL
	ctx.hotspots.bron("kar", {
		"id": "karhot", "kamer": str(kar["kamer"]),
		"x": float(kar["x"]), "z": float(kar["z"]), "hoog": 16.0,
		"icoon": ICO_KAR, "aantal": _op_kar(), "hand": 0, "prio": 11,
		"klas": "hotbron hotwolk", "titel": titel, "sleep": SLEEP_KAR,
		"tik": _tik_kar, "volg": _volg_kar(16.0),
	})
	var b := Ui.bron_van("karhot")
	if b != null:
		b.text = "%s %s" % [ICO_KAR, tekst]
		b.add_theme_font_size_override("font_size", int(Ui.maten.get("klein", 13)))

func _tik_kar(_s = null) -> void:
	if OS.has_feature("web"):
		print("[probe] vk tik_kar")
	hoe_dan()

func hoe_dan() -> void:
	ctx.ui.wolk({"id": "vk_hoe", "kamer": World.kamer_nu(),
		"x": _kar_x(), "z": _kar_z(), "hoog": 44.0, "icoon": ICO_WIJS,
		"tekst": T_SLEEP_DEUR, "prio": 11, "volg": _volg_kar(44.0)})
	ctx.wereld.vuil()

## De deuren en de bakjes van het hotel doen tijdens het rondje het werk van de
## voerkar: tikken op een bakje levert af, slepen van de kar duwt hem door een
## deur of levert af.  `Hits.leen` ruilt alleen `aan`; de sleep-afhandelaar
## zetten we er zelf op (zie "Contract gaps" in het rapport).
func _leen_doelen() -> void:
	for q in kamers_met_gast():
		var id := "bak_%s_%s" % [str(q["kamer"]), str(q["slot"])]
		var s := Hits.spot(id)
		if s == null:
			continue
		if s.geleend_door != ctx.id:
			ctx.hotspots.pak(id, _tik_bak)
		s.val = _val_lever
		if s.vangvlak != null and is_instance_valid(s.vangvlak):
			s.vangvlak.drop = SLEEP_KAR
			s.vangvlak.val = _val_lever
	var r := Rooms.get_kamer(World.kamer_nu())
	if r == null:
		return
	for dr in r.deuren:
		var s := Hits.spot("deur_%s_%s" % [World.kamer_nu(), str(dr.get("naar", ""))])
		if s == null:
			continue
		s.val = _val_duw
		if s.vangvlak != null and is_instance_valid(s.vangvlak):
			s.vangvlak.val = _val_duw

func _tik_bak(s = null) -> void:
	if s == null:
		return
	lever(str(s.data.get("kamer", "")), str(s.data.get("slot", "")))

func _val_lever(_lading: Dictionary, data: Dictionary) -> void:
	lever(str(data.get("kamer", "")), str(data.get("slot", "")))

func _val_duw(_lading: Dictionary, data: Dictionary) -> void:
	if OS.has_feature("web"):
		print("[probe] vk val_duw=", data)
	duw_naar(str(data.get("naar", "")))

## De kar door een deur duwen: hij verhuist naar die kamer en de camera gaat mee.
func duw_naar(kamer_id: String) -> void:
	if kamer_id.is_empty() or not Rooms.bestaat(kamer_id) or K.is_empty():
		return
	ctx.ui.wolk_weg("vk_hoe")
	var plek := _kar_plek(kamer_id)
	ctx.wereld.ding_zet("kar", {"kamer": kamer_id, "x": plek.x, "z": plek.y})
	ctx.wereld.naar(kamer_id)
	ctx.state.s["kamerNu"] = kamer_id
	ctx.snd.kar()
	Hotel.render()
	_rondje()

## Waar de kar in die kamer komt te staan: naast het bakje, anders midden in de
## kamer.  (De HTML liet hem op de keukenplek staan, ook als die in een muur van
## de nieuwe kamer viel.)
func _kar_plek(kamer_id: String) -> Vector2:
	var r := Rooms.get_kamer(kamer_id)
	if r == null:
		return Vector2(12.0, 12.0)
	var doel := Vector2(r.w * 0.5, r.d * 0.5)
	for slot in ctx.wereld.slots(kamer_id, "bak"):
		doel = Vector2(float(slot.get("sx", slot.get("x", doel.x))) - 14.0,
			float(slot.get("sz", slot.get("z", doel.y))) + 10.0)
		break
	return Vector2(clampf(doel.x, 8.0, r.w - 8.0), clampf(doel.y, 8.0, r.d - 8.0))

## Het bakje vullen: alle koekjes van de gasten in die kamer gaan erin en de
## dieren smullen waar ze staan.
func lever(kamer_id: String, slot_id: String) -> bool:
	if K.is_empty() or kamer_id.is_empty():
		return false
	var kar: Dictionary = ctx.wereld.ding("kar")
	if kar.is_empty() or str(kar.get("kamer", "")) != kamer_id:
		var sl: Dictionary = ctx.wereld.slot(kamer_id, slot_id)
		ctx.ui.wolk({"id": "vk_hier", "kamer": kamer_id,
			"x": float(sl.get("sx", sl.get("x", _kar_x()))),
			"z": float(sl.get("sz", sl.get("z", _kar_z()))),
			"hoog": 26.0, "icoon": ICO_KAR, "tekst": T_SLEEP_HIER,
			"klas": "hulp", "prio": 11})
		ctx.wereld.vuil()
		return false
	var hier: Array = []
	for g in deelnemers():
		if str(g.get("kamer", "")) == kamer_id:
			hier.append(g)
	if hier.is_empty() or (K["geleverd"] as Dictionary).has(kamer_id):
		return false
	var samen := 0
	var ids: Array = []
	for g in hier:
		var id := str(g["id"])
		samen += int((K["vak"] as Dictionary).get(id, 0))
		K["vak"][id] = 0
		g["gegeten"] = true
		g["behoefte"] = "spelen"
		g["blij"] = false
		ids.append(id)
	K["geleverd"][kamer_id] = samen
	ctx.ui.wolk_weg("vk_hier")
	ctx.ui.wolk_weg("vk_hoe")
	ctx.wereld.set_bak(kamer_id, slot_id, 4)
	ctx.wereld.feest(ids)
	ctx.snd.plop(3)
	_bewaar_kar()
	Hotel.render()
	_rondje()
	# every bowl in the hotel is full: sparkles on this one and a cheer
	if open_kamers().is_empty():
		var sl: Dictionary = ctx.wereld.slot(kamer_id, slot_id)
		ctx.wereld.spetter(kamer_id, float(sl.get("x", 0.0)), float(sl.get("z", 0.0)),
			ArtEffect.STER_N * 3, ArtEffect.STER_KL[0], true, 6.0)
		ctx.snd.hoera()
	# ná _rondje(), want dat begint met wis_alles() en zou dit wolkje meteen
	# weer weghalen (games-a.md §7.6)
	ctx.ui.wolk({"id": "vk_smul", "kamer": kamer_id, "hoog": 54.0,
		"icoon": ICO_SMUL, "getal": int(K["per"]),
		"tekst": T_KOEKJES_ELK if hier.size() > 1 else T_KOEKJES,
		"klas": "goed", "prio": 12, "volg": _volg_dier(str(hier[0]["id"]), 54.0)})
	_smul_weg()
	ctx.wereld.vuil()
	return true

func _volg_dier(id: String, hoog: float) -> Callable:
	return func() -> Dictionary:
		var d = World.dier(id)
		if d == null:
			return {}
		return {"x": d.x, "z": d.z, "y": hoog, "kamer": d.kamer,
			"vlak": World.vlak_van_dier(id)}

func _smul_weg() -> void:
	if not await na(SMUL_MS):
		return
	ctx.ui.wolk_weg("vk_smul")
	ctx.wereld.vuil()

func _sluit_straks() -> void:
	if _sluit_bezig:
		return
	_sluit_bezig = true
	var door := await na(SMUL_MS)
	_sluit_bezig = false
	if not door or K.is_empty() or not bool(K.get("vol", false)):
		return
	_klaar_met_rondje()

func _klaar_met_rondje(_s = null) -> void:
	if ctx == null:
		return
	ctx.state.s["kar"] = null
	ctx.data().erase("kar")
	K = {}
	State.bewaar()
	ctx.ui.wolk_weg("vk_af")
	ctx.sluit()
