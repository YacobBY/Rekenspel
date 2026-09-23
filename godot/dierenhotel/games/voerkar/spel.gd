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
## Bindend en ongewijzigd: de getallen (`Sommen.Voerkar.*`), elke kindtekst,
## de hulpladder (Els vanaf twee missers, en ze blijft staan), nooit straffen
## (alleen `zacht()`), één ster voor het meedoen, en de kar die thuis komt.

# --------------------------------------------------------------- vaste maten

const KAMER := "keuken"
## Hoogstens zes gasten doen mee (games-a.md §7.3).
const SPELERS_MAX := 6
const SMUL_MS := 2.6                          ## nagenieten, games-a.md §7.6
const LEEG_MS := 1.8                          ## "nog geen gasten"

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

var K: Dictionary = {}            ## state.kar; de vorm van V2 (PLAN.md §7):
## {T, per, rest, op_kar, pot, stap, geleverd, missers, spook, t0}
## `stap` is "som" (de poort die V3 bouwt) of "duwen" (het rondje).
var _kaart = null                 ## Ui.Kaart
var _sluit_bezig := false

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
	if str(K.get("stap", "som")) == "som":
		# Beslissing eigenaar 2026-09-20: "doorduwen".  De vul-fase is
		# gesloopt en V3 bouwt de echte som-poort nog niet: de kar vertrekt
		# vol, zodat de lus speelbaar blijft en er geen dood scherm staat.
		K["op_kar"] = int(K["T"])
		K["stap"] = "duwen"
		_bewaar_kar()
	_rondje()

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
	if ctx != null:
		ctx.hotspots.laat()
		_bewaar_kar()
		ctx.wereld.ding_thuis_zet("kar")
		ctx.wereld.vuil()

## Zolang het rondje loopt zijn de bakjes en de deuren van het hotel even van
## de voerkar.  `Hotel.render()` bouwt die knoppen opnieuw op (bij elke
## levering, bij elke kamerwissel), dus het lenen wordt elk beeld opnieuw
## bevestigd.
func _process(_dt: float) -> void:
	if not actief or K.is_empty() or str(K.get("stap", "")) != "duwen":
		return
	_leen_doelen()

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
		if typeof(bewaard) == TYPE_DICTIONARY \
				and int(bewaard.get("dag", -1)) != int(ctx.state.s["dag"]):
			bewaard = null
	if typeof(bewaard) == TYPE_DICTIONARY and int(bewaard.get("T", 0)) > 0:
		K = _herstel(bewaard)
	else:
		var som := Sommen.deel(g.size(), ctx.state.band(), int(ctx.state.s["dag"]))
		K = {
			"T": int(som["T"]), "per": int(som["k"]), "rest": int(som["r"]),
			"op_kar": 0, "pot": 0, "stap": "som",
			"geleverd": {}, "missers": 0, "spook": 0,
			"t0": Time.get_ticks_msec(), "dag": int(ctx.state.s["dag"]),
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
		"spook": int(d.get("spook", 0)),
		"t0": int(d.get("t0", Time.get_ticks_msec())),
	}
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
			" open=", open.size())
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
	return [T_VERDEEL % [int(K["T"]), Ui.meervoud(n, "gast", "gasten")],
		(T_ELS_ZIN % int(K["per"])) if int(K["spook"]) > 0 else T_IEDER]

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

func _verf(id: String, kleur: Color) -> void:
	var s := Hits.spot(id)
	if s == null or not is_instance_valid(s.knoop):
		return
	s.knoop.add_theme_stylebox_override("normal",
		UiThema.vulling(UiThema.vlak(kleur, 16, 2, UiThema.WIT), 8, 6))

func _tik_els(_s = null) -> void:
	hulp()

## Els doet het voor: haar doelgetal komt op de kaart te staan (games-a.md
## §7.5).  De knop overleeft de sloop van de vul-fase en hangt nu bij het
## rondje mee (PLAN.md V2: "Els blijft"); haar spookgetal ziet het kind weer
## zodra V3 de kaart de poort laat zijn.
func hulp() -> void:
	if K.is_empty() or str(K.get("stap", "")) != "duwen":
		return
	K["spook"] = 1
	_bewaar_kar()
	ctx.state.zet_gezien("voerkar_els")
	ctx.snd.brief()
	_rondje()

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
		# Op een liggend telefoonkader (740 x 360: 5 banden van 52, negen
		# kolommen van 56) is de wolk van 55 hoog twee banden breed en ligt
		# er geen vrij blok van vijf kolommen bij de kar: de deuren van de
		# keuken en de kar zelf kruisen elke band die raakt.  Met het icoon
		# op `icoon` in plaats van `icoon_wolk` wordt de bubbel ±51 hoog —
		# één band — en past hij bovenin, waar alleen de wasserijdeur een
		# kolom raakt.  Zonder deze maat is de duwknop daar altijd `krap`
		# en dekt hij het kozijn van de tuin (0 %-regel, architectuur §4.3).
		var duw := Hits.spot("vk_duw")
		if duw != null and duw.knoop is UiWolk:
			(duw.knoop as UiWolk).icoon_label.add_theme_font_size_override(
				"font_size", int(Ui.maten.get("icoon", 23)))
	if int(K["missers"]) >= 2:
		# Els blijft: haar knop is uit `_knoppen_neer` verhuisd naar de
		# tekenlaag van het rondje en hangt nu naast de kar mee (PLAN.md V2).
		ctx.hotspots.maak({"id": "vk_els", "kamer": World.kamer_nu(),
			"x": _kar_x(), "z": _kar_z(), "y": 44.0,
			"icoon": ICO_ELS, "label": T_ELS, "titel": T_ELS_TITEL,
			"klas": "hotwolk hulp", "prio": 8, "aan": _tik_els,
			"volg": _volg_kar(44.0)})
		_verf("vk_els", UiThema.WOLK_HULP)
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
		"icoon": ICO_KAR, "aantal": int(K["op_kar"]), "hand": 0, "prio": 11,
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
		var id := "deur_%s_%s" % [World.kamer_nu(), str(dr.get("naar", ""))]
		var s := Hits.spot(id)
		if s == null:
			continue
		# Borrowed as well: only a borrowed hotel button stays on screen while a
		# game runs, and a tap on the door now pushes the trolley through it —
		# the same thing the drag does, for a finger that cannot drag yet.
		if s.geleend_door != ctx.id:
			ctx.hotspots.pak(id, _tik_deur)
		s.val = _val_duw
		if s.vangvlak != null and is_instance_valid(s.vangvlak):
			s.vangvlak.val = _val_duw

func _tik_bak(s = null) -> void:
	if s == null:
		return
	lever(str(s.data.get("kamer", "")), str(s.data.get("slot", "")))

func _tik_deur(s = null) -> void:
	if s == null:
		return
	duw_naar(str(s.data.get("naar", "")))

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

## Het bakje vullen: wat de gasten in die kamer moeten hebben gaat erin en de
## dieren smullen waar ze staan.  De kar draagt de hele lading (`op_kar`);
## bij de laatste levering gaat wat hij over heeft in de snoeppot — dat is de
## `rest` van de deling — en daar sluit de lus: één ster voor het meedoen en
## de band wordt gevoed zoals altijd.
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
	var samen := mini(int(K["per"]) * hier.size(), int(K["op_kar"]))
	K["op_kar"] = int(K["op_kar"]) - samen
	var ids: Array = []
	for g in hier:
		var id := str(g["id"])
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
	# every bowl in the hotel is full: the loop closes here — the rest of the
	# trolley goes into the candy jar, the turn is counted, sparkles and a cheer
	if open_kamers().is_empty():
		ctx.state.s["snoeppot"] = int(ctx.state.s["snoeppot"]) + int(K["op_kar"])
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
	ctx.ui.wolk_weg("vk_af")
	ctx.wereld.ding_thuis_zet("kar")
	ctx.sluit()
