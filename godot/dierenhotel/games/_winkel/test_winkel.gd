extends Proef
## De winkels van de Winkelstraat (games-d.md §4), headless: de drie kraampjes
## (hoeden, sjaals, schoenen), de luxe winkel en de paskamer.
##
## Driven the way a child drives it: a choice is a `pressed` on a button of the
## real strip under the card.  Only the pure turn logic in `beurt.gd` is called
## directly.

const KAMER := "winkels"
const KAART := "wk_kaart"
const STROOK := "wk_kaart_keuzes"
const WEG := "wk_weg"
const PK := "pk_kaart_keuzes"
const WINKELS := ["hoeden", "sjaals", "schoenen", "luxe"]
const Beurt := preload("res://games/_winkel/beurt.gd")

const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740),
	Vector2i(740, 360)]

var _laag: Control = null
var _bewaard: Dictionary = {}
var _rust_voor := false

# ------------------------------------------------------------------ harnas

func _op(kader := Vector2(1000, 648)) -> void:
	_bewaard = State.s.duplicate(true)
	_rust_voor = Ui.rust_modus()
	Ui.zet_rust_modus(true)                 # a walk is a teleport: no waiting
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = kader
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	World.meet(Rect2(Vector2.ZERO, kader))

func _af() -> void:
	Games.stop()
	Ui.naamplaten_leeg()
	Hits.wis_alles()
	Ui.zet_rust_modus(_rust_voor)
	if "_scherm" in Ui:
		Ui.vergeet_scherm()
	if _laag != null:
		_laag.queue_free()
		_laag = null
	Ui.registreer_lagen(null, null, null)
	if not _bewaard.is_empty():
		State.s = _bewaard
		_bewaard = {}
	Games.hersteek()

## `n` guests from the pool, the first four in a real bed; `kunnen` 5 lifts the
## adaptive cap, so the band is what the test asks for.
func _wereld(n: int, band: int, dag := 2) -> Array:
	State.nieuw_spel()
	State.s["taken"] = []
	State.s["kunnen"] = 5
	State.s["dag"] = dag
	var pool := State.gasten_pool()
	var bedden := State.alle_bedden()
	var uit: Array = []
	for i in n:
		var g: Dictionary = pool[i]
		if i < bedden.size():
			g["kamer"] = str(bedden[i]["kamer"])
			g["bed"] = str(bedden[i]["slot"])
		else:
			g["kamer"] = ""
			g["bed"] = ""
		g["waar"] = str(g["kamer"]) if not str(g["kamer"]).is_empty() else "receptie"
		g["nachten"] = 100
		g["behoefte"] = "eten"
		g["blij"] = false
		uit.append(g)
	State.s["gasten"] = uit
	World.sync(uit)
	World.zet_dag(dag)
	gelijk(State.band(), band, "de band is %d bij %d gasten" % [band, n])
	return uit

func _knoop(id: String) -> Control:
	var s := Hits.spot(id)
	return null if s == null or not is_instance_valid(s.knoop) else s.knoop

## One button of the real strip, by its keuze id (`K<id>`).
func _kies(keuze: String, strook_id := STROOK) -> bool:
	var strook := _knoop(strook_id)
	if strook == null:
		fout("er is geen antwoordstrook (voor %s)" % keuze)
		return false
	var k := strook.get_node_or_null("Rij/K" + keuze)
	if k == null:
		fout("%s staat niet op de strook (%s)" % [keuze, str(_keuzes(strook_id))])
		return false
	(k as BaseButton).pressed.emit()
	return true

## The keuze ids on the strip, in order.
func _keuzes(strook_id := STROOK) -> Array[String]:
	var uit: Array[String] = []
	var strook := _knoop(strook_id)
	if strook == null:
		return uit
	var rij := strook.get_node_or_null("Rij")
	if rij == null:
		return uit
	for k in rij.get_children():
		var naam := str(k.name)
		if naam.begins_with("K"):
			uit.append(naam.substr(1))
	return uit

func _kaart_tekst(deel: String) -> String:
	var k := _knoop(KAART)
	if k == null:
		return ""
	var l := k.get_node_or_null(deel) as Label
	return "" if l == null else l.text

func _stand(spel: String) -> Dictionary:
	var d = State.spel_data(spel).get("stand", {})
	return d if typeof(d) == TYPE_DICTIONARY else {}

## A shop's own layout (`WinkelSpel.winkel()`), read from a throwaway instance.
func _winkel(id: String) -> Dictionary:
	var knoop = Games._scenes[id].instantiate()
	var uit: Dictionary = knoop.winkel()
	knoop.free()
	return uit

func _wacht(s: float) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	await boom.create_timer(s).timeout

func _wacht_kaart() -> void:
	await _wacht(WinkelSpel.SOM_S + 0.25)

## Every right answer of this turn, one step at a time, through the strip.
func _speel_goed(spel: String) -> void:
	for _i in 6:
		var st := _stand(spel)
		var stap := str(st.get("stap", ""))
		if stap == "af" or stap.is_empty():
			return
		var o := Beurt.opzet(spel, State.n_gasten(), State.band(), int(State.s["dag"]))
		var kind := str(State.gast_van(str(st["gast"])).get("kind", "hond"))
		var s := Beurt.sommen(o, str(st["waar"]), kind)
		var goed := Beurt.goed(stap, s)
		_kies(("g%d" if stap == "betaal" else "n%d") % goed)
		await _wacht_kaart()

## A keuze on the strip that is NOT the answer of this step.
func _fout_keuze(spel: String) -> String:
	var st := _stand(spel)
	var stap := str(st.get("stap", ""))
	var o := Beurt.opzet(spel, State.n_gasten(), State.band(), int(State.s["dag"]))
	var kind := str(State.gast_van(str(st["gast"])).get("kind", "hond"))
	var goed := Beurt.goed(stap, Beurt.sommen(o, str(st["waar"]), kind))
	var juist := ("g%d" if stap == "betaal" else "n%d") % goed
	for k in _keuzes():
		if k != juist:
			return k
	return ""

# -------------------------------------------------------------- aanmelding

## The scan finds the five games of the arcade; each hangs on its own stall, the
## luxury shop's front or the mirror, all in the arcade.
func test_aanmelding() -> void:
	var dingen := {"hoeden": "hoedenkraam", "sjaals": "sjaalkraam", "schoenen": "schoenenkraam",
		"luxe": "luxepuiz", "paskamer": "spiegelz"}
	var r := Rooms.get_kamer(KAMER)
	waar(r != null, "de winkelstraat bestaat")
	for id in dingen:
		waar(Games.lijst().has(id), "de mapscan vindt %s" % id)
		var def := Games.definitie(id)
		gelijk(def.get("kamer", ""), KAMER, "%s woont in de winkelstraat" % id)
		gelijk(def.get("stub", true), false, "%s is geen stub" % id)
		var hs: Dictionary = def.get("hotspot", {})
		gelijk(hs.get("obj", ""), dingen[id], "%s hangt aan zijn eigen ding" % id)
		waar(not World.mik(str(dingen[id]), KAMER).is_empty(), "%s staat in de winkelstraat" % dingen[id])
		waar(not str(hs.get("icoon", "")).is_empty() and not str(hs.get("label", "")).is_empty(),
			"%s heeft een pictogram en een woord" % id)
		var unlock: Callable = def["unlock"]
		waar(not unlock.call(0, 3), "%s: zonder gasten niet" % id)
		waar(unlock.call(1, 3), "%s: vanaf één gast wel" % id)
	# the arcade is off the lobby, and every shop's goods are real models
	gelijk(Rooms.pad("receptie", KAMER).size(), 2, "de winkels liggen naast de receptie")
	for naam in ArtGasten.KLEDING:
		waar(Art.heeft_model("waar_" + str(naam)), "er is een uitstalmodel van %s" % naam)
		var p = Art.plaat("waar_" + str(naam), 3)
		waar(p != null and p.w > 0, "waar_%s bakt" % naam)
	for model in ["hoedenkraam", "sjaalkraam", "schoenenkraam", "luxepuiz", "vitrinez",
			"spiegelz", "lantaarn", "winkelbord", "cadeaudoos"]:
		var p = Art.plaat(model, 3)
		waar(p != null and p.w > 0 and p.h > 0, "%s bakt" % model)
	# kan: a shop has something to do as soon as somebody sleeps here; the
	# fitting room only when somebody owns something to put on
	var kan: Callable = Games.definitie("hoeden")["kan"]
	waar(not kan.call({"gasten": []}), "geen gasten: geen knop")
	waar(kan.call({"gasten": [{"id": "a", "bed": "bed1"}]}), "een gast met een bed: wel")
	var kan_pk: Callable = Games.definitie("paskamer")["kan"]
	waar(not kan_pk.call({"gasten": [{"id": "a", "bed": "bed1"}]}), "paskamer: niets gekocht, geen knop")
	waar(kan_pk.call({"gasten": [{"id": "a", "bed": "bed1", "kast": ["pet"]}]}),
		"paskamer: iets in de kast, wel")

# ------------------------------------------------------------- het rekenen

## Every shop, band, hotel size and day: prices in the band's range, two things
## on a counter never the same price (shoes in groep 3 excepted), the same day
## the same shop, and every sum inside the groep's numbers.
func test_de_prijzen_en_de_sommen() -> void:
	for winkel in WINKELS:
		for band in [3, 4, 5]:
			for n in range(1, 11):
				for dag in range(1, 8):
					var o := Beurt.opzet(winkel, n, band, dag)
					gelijk(str(Beurt.opzet(winkel, n, band, dag)), str(o), "dezelfde dag, dezelfde winkel")
					var bereik: Array = Beurt._bereik(winkel, band)
					var prijzen := {}
					for w in o["waren"]:
						var p := int(w["prijs"])
						waar(p >= int(bereik[0]) and p <= int(bereik[1]),
							"%s groep %d: %s kost %d, binnen %s" % [winkel, band, w["naam"], p, str(bereik)])
						if not (winkel == "schoenen" and band == 3):
							waar(not prijzen.has(p), "%s groep %d: twee dingen kosten nooit hetzelfde (%s)"
								% [winkel, band, str(o["waren"])])
						prijzen[p] = true
						for kind in ArtGasten.SOORTEN:
							var s := Beurt.sommen(o, str(w["naam"]), kind)
							var t := int(s["totaal"])
							var grens := 20 if band == 3 else 100
							waar(t >= 1 and t <= grens, "%s groep %d: het totaal %d blijft binnen %d"
								% [winkel, band, t, grens])
							if winkel == "schoenen":
								gelijk(t, p * ArtGasten.poten_van(kind), "schoenen: per poot")
							if winkel == "luxe":
								var basis := int(p / 2) if band == 5 else p
								gelijk(t, basis + int(o["doosje"]), "luxe: met het doosje")
							if Beurt.stappen(winkel, band).has("betaal"):
								waar(t <= (13 if band == 3 else 20),
									"%s groep %d: betalen tot €13 / €20 (%d)" % [winkel, band, t])
							if Beurt.stappen(winkel, band).has("terug"):
								waar(int(s["terug"]) >= 1 and int(s["terug"]) < int(s["briefje"]),
									"%s: er is altijd wisselgeld (%d van %d)" % [winkel, int(s["terug"]),
										int(s["briefje"])])
								waar(int(s["briefje"]) in [20, 50, 100], "een echt briefje")
	# the steps per groep: groep 3 never gives change, groep 5 always does, the
	# luxury shop computes most
	for winkel in WINKELS:
		waar(not Beurt.stappen(winkel, 3).has("terug"), "%s groep 3: geen wisselgeld" % winkel)
		waar(Beurt.stappen(winkel, 5).has("terug"), "%s groep 5: wisselgeld" % winkel)
		gelijk(Beurt.stappen(winkel, 4)[0], "kies", "%s: eerst kiezen" % winkel)
	gelijk(Beurt.stappen("luxe", 5).size(), 4, "de luxe winkel: kies, half, samen, terug")
	waar(Beurt.stappen("schoenen", 4).has("som"), "schoenen: eerst uitrekenen wat vier kosten")

## Paying: four real handfuls of money, exactly one of them the price, never
## more than four pieces, only the coins and notes of the groep.
func test_betalen_met_echt_geld() -> void:
	# what a shop really asks to pay: groep 3 up to €13 (the luxury shop with
	# its box), groep 4 up to €20 (four shoes of €5); groep 5 gets change
	for band in [3, 4]:
		for totaal in range(1, 14 if band == 3 else 21):
			var keuzes := Beurt.betaal_keuzes(totaal, band, 17)
			gelijk(keuzes.size(), 4, "groep %d, €%d: vier keuzes" % [band, totaal])
			var goed := 0
			var sommen := {}
			for st in keuzes:
				var som := Beurt.tel(st)
				if som == totaal:
					goed += 1
				waar(not sommen.has(som), "groep %d, €%d: vier verschillende bedragen" % [band, totaal])
				sommen[som] = true
				waar((st as Array).size() <= 4, "hooguit vier stuks geld (%s)" % str(st))
				for m in st:
					waar((Beurt.GELD[band] as Array).has(int(m)), "alleen geld van groep %d (%d)" % [band, m])
			gelijk(goed, 1, "groep %d, €%d: precies één keer het goede bedrag" % [band, totaal])
			gelijk(str(Beurt.betaal_keuzes(totaal, band, 17)), str(keuzes), "herladen: dezelfde vier")
	gelijk(Beurt.stapel(7, 3), [5, 2], "€7 = €5 + €2")
	gelijk(Beurt.stapel(19, 4), [10, 5, 2, 2], "€19 = €10 + €5 + €2 + €2")
	gelijk(Beurt.stapel_tekst([5, 2]), "€5 + €2", "zo staat het op de knop")

## Every sentence fits the budget with the longest guest name, and every glyph
## is in the bundled fonts.
func test_elke_zin_past() -> void:
	if Ui.thema == null or Ui.thema.default_font == null:
		Ui._bouw_thema(17)
	var naam := "Stampertje"
	var zinnen: Array[String] = [Beurt.T_KIES % naam, Beurt.T_SOM_DOOS, Beurt.T_HALF,
		Beurt.T_BETAAL % "€19", Beurt.T_TERUG % [naam, "€100"], Beurt.T_WEG, Beurt.T_LEEG]
	for kl in ArtGasten.KLEDING:
		var w: Dictionary = ArtGasten.KLEDING[kl]
		zinnen.append(Beurt.T_AF % [naam, str(w["lid"]), str(w["naam"])])
		if bool(w.get("veel", false)):
			zinnen.append(Beurt.T_SOM_SCHOEN % [4, str(w["naam"])])
		gelijk(Ui.mist_tekens(str(w["icoon"])).size(), 0, "het pictogram van %s bestaat" % kl)
	for zin in zinnen:
		waar(Ui.keur_regel("winkel", zin), "binnen het budget: %s" % zin)
		gelijk(Ui.mist_tekens(zin).size(), 0, "alle tekens bestaan: %s" % zin)
	for teken in ["🎩", "🧣", "👟", "💎", "🪞", "🛍️", Beurt.ICOON_WEG, Beurt.ICOON_GELD,
			Beurt.ICOON_AF, Beurt.ICOON_DOOS]:
		gelijk(Ui.mist_tekens(teken).size(), 0, "het pictogram %s staat in de fontsubset" % teken)

# ---------------------------------------------------------------- de beurt

## A whole turn in every shop and every groep, through the real buttons: choose,
## compute, pay — and the animal wears it, keeps it in its wardrobe, and the
## save knows it (it used to be lost at a reload).
func test_een_beurt_in_elke_winkel() -> void:
	for winkel in WINKELS:
		for band in [3, 4, 5]:
			_op()
			var n: int = [1, 4, 7][band - 3]
			_wereld(n, band)
			var sterren := int(State.s["sterren"])
			waar(Games.start(winkel), "%s start" % winkel)
			await _wacht(0.3)
			var st := _stand(winkel)
			gelijk(str(st.get("stap", "")), "kies", "%s groep %d: eerst kiezen" % [winkel, band])
			var gast := str(st.get("gast", ""))
			var d = World.dier(gast)
			waar(d != null and d.kamer == KAMER, "%s: de klant is in de winkelstraat" % winkel)
			gelijk(_kaart_tekst("Kolom/Regel").contains(Beurt.T_KIES % str(State.gast_van(gast)["naam"])),
				true, "%s: de kies-zin" % winkel)
			var keuzes := _keuzes()
			waar(keuzes.size() == 3, "%s: drie dingen om te kiezen (%s)" % [winkel, str(keuzes)])
			# the goods stand on the counter, each with its price
			var o := Beurt.opzet(winkel, n, band, int(State.s["dag"]))
			for i in keuzes.size():
				waar(not World.decor_plek("wk_w%d" % i, KAMER).is_empty(), "%s: ding %d staat op de toonbank" % [winkel, i])
				waar(Hits.spot("wk_p%d" % i) != null, "%s: met een prijskaartje" % winkel)
			waar(keuzes.size() == mini(3, (o["waren"] as Array).size()), "%s: drie dingen per dag" % winkel)
			var naam := str(keuzes[0]).trim_prefix("w_")
			_kies(keuzes[0])
			await _wacht(0.1)
			gelijk(str(_stand(winkel).get("waar", "")), naam, "%s: %s gekozen" % [winkel, naam])
			await _speel_goed(winkel)
			gelijk(str(_stand(winkel).get("stap", "")), "af", "%s groep %d: klaar" % [winkel, band])
			waar(World.accessoires(gast).has(naam), "%s: het dier draagt %s" % [winkel, naam])
			waar(State.kast_van(gast).has(naam), "%s: en het is van hem" % winkel)
			waar((State.gast_van(gast)["accessoires"] as Array).has(naam),
				"%s: de opslag weet wat hij draagt" % winkel)
			gelijk(int(State.s["sterren"]), sterren + 1, "%s: één ster voor het meedoen" % winkel)
			gelijk(int(_stand(winkel).get("missers", -1)), 0, "%s: geen missers" % winkel)
			_af()

## THE OWNER'S RULE (2026-09-24): the wrong money sends the animal out of the
## shop, disappointed, slowly — and the child has to tap the shop again.  Then
## the SAME question comes back, with the same four choices.
func test_verkeerd_geld_stuurt_het_dier_de_winkel_uit() -> void:
	_op()
	_wereld(4, 4)
	var sterren := int(State.s["sterren"])
	waar(Games.start("hoeden"), "de hoedenkraam start")
	await _wacht(0.3)
	var keuzes := _keuzes()
	_kies(keuzes[0])
	await _wacht(0.2)
	gelijk(str(_stand("hoeden").get("stap", "")), "betaal", "groep 4: nu betalen")
	var voor := _keuzes()
	gelijk(voor.size(), 4, "vier handjes geld")
	var gast := str(_stand("hoeden")["gast"])
	var fout_k := _fout_keuze("hoeden")
	waar(not fout_k.is_empty(), "er staat een verkeerd bedrag op de strook")
	# listen: the animal says it with its own sad little sound, once
	var was_wakker: bool = Snd._wakker
	Snd._wakker = true
	var gehoord_voor := Snd.gehoord().size()
	_kies(fout_k)
	var nu_gehoord := Snd.gehoord().slice(gehoord_voor)
	Snd._wakker = was_wakker
	var eigen := "%s_sip" % Snd.soort_van(gast)
	waar(nu_gehoord.has(eigen), "het dier zegt het met zijn eigen sip geluidje (%s)" % str(nu_gehoord))
	waar(not nu_gehoord.has("zacht") or nu_gehoord.has("stil:zacht"),
		"geen tweede, zacht geluid ernaast (%s)" % str(nu_gehoord))
	# at once: nothing left to tap, the animal sulks with its bubble
	waar(_knoop(KAART) == null and _knoop(STROOK) == null, "de kaart en de strook zijn meteen weg")
	gelijk(int(_stand("hoeden").get("weg", 0)), 1, "het dier moet de winkel uit")
	gelijk(str(_stand("hoeden").get("stap", "")), "betaal", "de vraag blijft staan")
	gelijk(int(_stand("hoeden").get("missers", 0)), 1, "de misser is geteld")
	waar(is_sip(gast), "het dier is teleurgesteld")
	waar(_knoop(WEG) != null, "met 😞 Dat klopt niet")
	gelijk(Games.actief(), "hoeden", "het spel loopt nog: hij moet nog weglopen")
	# no help: nothing but the bubble is new
	for id in Hits.lijst():
		var s = Hits.spot(id)
		if s != null and s.door == "hoeden":
			waar(str(id) == WEG or str(id).begins_with("wk_p"),
				"na de misser staat er niets anders (%s)" % id)
	# he walks out (a teleport in reduced motion), and then the game closes
	await _wacht(WinkelSpel.SIP_S + WinkelSpel.WEG_WACHT + 0.8)
	gelijk(Games.actief(), "", "buiten: het spel is dicht")
	var d = World.dier(gast)
	var buiten: Vector2 = _winkel("hoeden")["buiten"]
	waar(d != null and Vector2(d.x, d.z).distance_to(buiten) <= 3.0, "het dier staat buiten de kraam")
	gelijk(int(State.s["sterren"]), sterren, "een misser kost niets")
	# the shop's button is back on its stall: in again
	Games.hersteek()
	waar(Hits.spot("spel_hoeden") != null, "de knop van de hoedenkraam is er weer")
	waar(Games.start("hoeden"), "terug de winkel in")
	await _wacht(0.3)
	gelijk(int(_stand("hoeden").get("weg", 1)), 0, "hij is weer binnen")
	gelijk(str(_stand("hoeden").get("stap", "")), "betaal", "dezelfde vraag")
	gelijk(str(_keuzes()), str(voor), "met dezelfde vier keuzes in dezelfde volgorde")
	d = World.dier(gast)
	var klant: Vector2 = _winkel("hoeden")["klant"]
	waar(d != null and Vector2(d.x, d.z).distance_to(klant) <= 3.0, "en hij staat weer aan de toonbank")
	await _speel_goed("hoeden")
	gelijk(str(_stand("hoeden").get("stap", "")), "af", "nu goed betaald")
	gelijk(int(State.s["sterren"]), sterren + 1, "de ster komt voor het meedoen")
	_af()

## A wrong SUM sends him out too (the schoenen: four shoes), not only money.
func test_een_verkeerde_som_ook() -> void:
	_op()
	_wereld(4, 4)
	waar(Games.start("schoenen"), "de schoenenkraam start")
	await _wacht(0.3)
	_kies(_keuzes()[0])
	await _wacht(0.2)
	gelijk(str(_stand("schoenen").get("stap", "")), "som", "eerst uitrekenen wat vier schoentjes kosten")
	waar(_kaart_tekst("Kolom/Rij/Som").contains("×"), "een keersom (%s)" % _kaart_tekst("Kolom/Rij/Som"))
	_kies(_fout_keuze("schoenen"))
	gelijk(int(_stand("schoenen").get("weg", 0)), 1, "ook een verkeerde som: de winkel uit")
	await _wacht(WinkelSpel.SIP_S + WinkelSpel.WEG_WACHT + 0.8)
	gelijk(Games.actief(), "", "en het spel is dicht")
	_af()

## A reload in the middle of a turn resumes it: the same thing, the same step.
func test_herladen_hervat_de_beurt() -> void:
	_op()
	_wereld(7, 5)
	waar(Games.start("luxe"), "de luxe winkel start")
	await _wacht(0.3)
	_kies(_keuzes()[1])
	await _wacht(0.2)
	var st := _stand("luxe")
	gelijk(str(st.get("stap", "")), "half", "groep 5: eerst de halve prijs")
	Games.stop()
	var tekst := JSON.stringify(State.s)
	State.s = JSON.parse_string(tekst)
	waar(Games.start("luxe"), "opnieuw gestart")
	await _wacht(0.3)
	gelijk(str(_stand("luxe").get("waar", "")), str(st["waar"]), "hetzelfde ding")
	gelijk(str(_stand("luxe").get("stap", "")), "half", "dezelfde stap")
	waar(_kaart_tekst("Kolom/Rij/Som").contains("/ 2"), "de halve-prijssom staat er weer")
	_af()

## The fitting room: a tap on a slot puts on the next thing of that slot the
## animal owns, and after the last one nothing — and the save keeps it.
func test_de_paskamer() -> void:
	_op()
	var gasten := _wereld(4, 4)
	var id := str(gasten[0]["id"])
	State.in_kast(id, "pet")
	State.in_kast(id, "strohoed")
	State.in_kast(id, "gympjes")
	State.s["speler"] = id
	waar(Games.start("paskamer"), "de paskamer start")
	await _wacht(0.3)
	gelijk(str(_keuzes(PK)), str(["s_hoofd", "s_poten"]), "twee knoppen: hoofd en poten")
	_kies("s_hoofd", PK)
	await _wacht(0.05)
	gelijk(str(World.accessoires(id)), str(["pet"]), "de pet op")
	_kies("s_hoofd", PK)
	await _wacht(0.05)
	gelijk(str(World.accessoires(id)), str(["strohoed"]), "dan de strohoed (de pet gaat af)")
	_kies("s_poten", PK)
	await _wacht(0.05)
	gelijk(str(World.accessoires(id)), str(["strohoed", "gympjes"]), "en de gympjes erbij")
	_kies("s_hoofd", PK)
	await _wacht(0.05)
	gelijk(str(World.accessoires(id)), str(["gympjes"]), "na de laatste hoed: niets op het hoofd")
	gelijk(str(State.gast_van(id)["accessoires"]), str(["gympjes"]), "de opslag weet het")
	State.s.erase("speler")
	_af()

# ------------------------------------------------------------- het scherm

## The card and its strip, the price tags and the entry buttons find a real
## place on the four ticket screens, in the real shell.
func test_de_knoppen_op_vier_schermen() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var scherm_terug = Ui.get("_scherm")
	var rust_voor := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	var boom := Engine.get_main_loop() as SceneTree
	for maat in SCHERMEN:
		var vp := SubViewport.new()
		vp.size = maat
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		boom.root.add_child(vp)
		var shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		shell.set_meta("geen_start", true)
		vp.add_child(shell)
		for _f in 4:
			await boom.process_frame
		_wereld(4, 4)
		Hotel.start()
		World.naar(KAMER)
		State.s["kamerNu"] = KAMER
		Hotel.render()
		for _f in 4:
			await boom.process_frame
		# every shop has its button on its own thing in the arcade
		for id in ["hoeden", "sjaals", "schoenen", "luxe"]:
			waar(Hits.spot("spel_" + id) != null, "%s: de knop van %s staat er" % [str(maat), id])
		for winkel in ["hoeden", "luxe"]:
			waar(Games.start(winkel), "%s: %s start" % [str(maat), winkel])
			for _f in 4:
				await boom.process_frame
			waar(_knoop(KAART) != null and _knoop(STROOK) != null, "%s: kaart en strook" % str(maat))
			var kader: Control = shell.get_node("Scherm/Kolom/Middenrij/Kaderdoos/Kader")
			_keur(kader.size, "%s %s kies" % [str(maat), winkel], winkel)
			_kies(_keuzes()[0])
			await _wacht_kaart()
			for _f in 3:
				await boom.process_frame
			_keur(kader.size, "%s %s rekenen" % [str(maat), winkel], winkel)
			Games.stop()
		Ui.naamplaten_leeg()
		Hits.wis_alles()
		vp.queue_free()
		await boom.process_frame
		Ui.registreer_lagen(null, null, null)
	State.s = bewaard
	Ui.set("_scherm", scherm_terug)
	Ui.zet_rust_modus(rust_voor)
	Games.hersteek()

## Every element of the game found a real place inside the frame, and no button
## covers a thing it does not belong to.
func _keur(kader: Vector2, wat: String, spel: String) -> void:
	var dbg := Hits.debug()
	var eigen := 0
	for id in dbg.keys():
		var spot := Hits.spot(id)
		if spot == null or spot.door != spel:
			continue
		eigen += 1
		var d: Dictionary = dbg[id]
		var r: Rect2 = d["rect"]
		waar(not bool(d["krap"]), "%s: %s vond een echte plek" % [wat, id])
		waar(r.position.x >= -0.01 and r.position.y >= -0.01
			and r.end.x <= kader.x + 0.01 and r.end.y <= kader.y + 0.01,
			"%s: %s staat binnen het kader (%s)" % [wat, id, str(r)])
		if spot.kind == "tag" or int(d["laag"]) == Hits.Laag.VAST:
			continue
		waar(r.size.x >= 44.0 and r.size.y >= 44.0, "%s: %s is een tikdoel" % [wat, id])
	waar(eigen >= 2, "%s: het spel staat op het scherm (%d)" % [wat, eigen])
