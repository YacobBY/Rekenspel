extends Proef
## De winkels van de Winkelstraat (games-d.md §4), headless: de vier kraampjes
## (hoeden, sjaals, schoenen en de souvenirkraam `kraam`), de luxe winkel en de
## paskamer.  De souvenirkraam heeft daarnaast zijn eigen `games/kraam/test_kraam.gd`.
##
## Driven the way a child drives it: a choice is a `pressed` on a button of the
## real strip under the card.  Only the pure turn logic in `beurt.gd` is called
## directly.

const KAMER := "winkels"
const KAART := "wk_kaart"
const STROOK := "wk_kaart_keuzes"
const WEG := "wk_weg"
const PK := "pk_kaart_keuzes"
const WINKELS := ["hoeden", "sjaals", "schoenen", "luxe", "kraam"]
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

## The shop of the turn in the save: its own day, hotel size and band (an open
## question with a miss keeps them, R2), not necessarily today's.
func _opzet_van(spel: String, st: Dictionary) -> Dictionary:
	return Beurt.opzet(spel, int(st.get("N", State.n_gasten())), int(st.get("band", State.band())),
		int(st.get("dag", State.s["dag"])))

## Every right answer of this turn, one step at a time, through the strip.
func _speel_goed(spel: String) -> void:
	for _i in 6:
		var st := _stand(spel)
		var stap := str(st.get("stap", ""))
		if stap == "af" or stap.is_empty():
			return
		var o := _opzet_van(spel, st)
		var kind := str(State.gast_van(str(st["gast"])).get("kind", "hond"))
		var s := Beurt.sommen(o, str(st["waar"]), kind)
		var goed := Beurt.goed(stap, s)
		_kies(("g%d" if stap == "betaal" else "n%d") % goed)
		await _wacht_kaart()

## A keuze on the strip that is NOT the answer of this step.
func _fout_keuze(spel: String) -> String:
	var st := _stand(spel)
	var stap := str(st.get("stap", ""))
	var o := _opzet_van(spel, st)
	var kind := str(State.gast_van(str(st["gast"])).get("kind", "hond"))
	var goed := Beurt.goed(stap, Beurt.sommen(o, str(st["waar"]), kind))
	var juist := ("g%d" if stap == "betaal" else "n%d") % goed
	for k in _keuzes():
		if k != juist:
			return k
	return ""

# -------------------------------------------------------------- aanmelding

## The scan finds the six games of the arcade; each hangs on its own stall, the
## luxury shop's front or the mirror, all in the arcade.
func test_aanmelding() -> void:
	var dingen := {"hoeden": "hoedenkraam", "sjaals": "sjaalkraam", "schoenen": "schoenenkraam",
		"luxe": "luxepuiz", "paskamer": "spiegelz", "kraam": "souvenirkraam"}
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
	# the arcade is a floor of its own, one flight of stairs from the lobby (owner,
	# 2026-09-24: "Ik wil de winkels op een andere etage"), and every shop's
	# goods are real models
	gelijk(Rooms.pad("receptie", KAMER).size(), 2, "de winkels zijn één keer de trap van de receptie")
	waar(Rooms.via_trap("receptie", KAMER), "met de trap")
	waar(Rooms.etage(KAMER) != Rooms.etage("receptie"), "op een andere verdieping")
	for naam in ArtGasten.KLEDING:
		waar(Art.heeft_model("waar_" + str(naam)), "er is een uitstalmodel van %s" % naam)
		var p = Art.plaat("waar_" + str(naam), 3)
		waar(p != null and p.w > 0, "waar_%s bakt" % naam)
	for model in ["hoedenkraam", "sjaalkraam", "schoenenkraam", "luxepuiz", "vitrinez",
			"spiegelz", "lantaarn", "winkelbord", "cadeaudoos", "souvenirkraam"]:
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
							if Beurt.stappen(winkel, band).has("over"):
								gelijk(int(s["beurs"]), 10 if band == 3 else 20,
									"%s groep %d: €10 / €20 in de beurs" % [winkel, band])
								gelijk(int(s["over"]), int(s["beurs"]) - t, "%s: wat er over is" % winkel)
								waar(int(s["over"]) >= 1 and int(s["over"]) <= (8 if band == 3 else 14),
									"%s groep %d: er blijft iets over, binnen 10 / 20 (%d)" % [winkel, band,
										int(s["over"])])
							if Beurt.stappen(winkel, band).has("half"):
								gelijk(p % 2, 0, "%s groep 5: een even prijs, de helft is hele euro's (%d)"
									% [winkel, p])
								gelijk(int(s["half"]), int(p / 2), "%s: de halve prijs" % winkel)
	# the steps per groep: groep 3 never gives change, groep 5 always does, the
	# luxury shop computes most
	for winkel in WINKELS:
		waar(not Beurt.stappen(winkel, 3).has("terug"), "%s groep 3: geen wisselgeld" % winkel)
		waar(Beurt.stappen(winkel, 5).has("terug"), "%s groep 5: wisselgeld" % winkel)
		gelijk(Beurt.stappen(winkel, 4)[0], "kies", "%s: eerst kiezen" % winkel)
		# R1 (owner, 2026-10-08): after the one choice, at least two sums in
		# every groep — maths is never less than half of the taps
		for band in [3, 4, 5]:
			var sommen := 0
			for stap in Beurt.stappen(winkel, band):
				if Beurt.REKENSTAPPEN.has(stap):
					sommen += 1
			waar(sommen >= 2, "%s groep %d: minstens twee sommen na het kiezen (%s)"
				% [winkel, band, str(Beurt.stappen(winkel, band))])
	gelijk(Beurt.stappen("hoeden", 3), ["kies", "betaal", "over"], "een kraam in groep 3: betalen, dan over")
	gelijk(Beurt.stappen("sjaals", 5), ["kies", "half", "terug"], "een kraam in groep 5: halve prijs, dan terug")
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
	gelijk(Beurt.stapel_knop_kort([5, 2]), "💶\n5+2", "op een telefoon: het pictogram boven het geld")

## Every sentence fits the budget with the longest guest name, and every glyph
## is in the bundled fonts.
func test_elke_zin_past() -> void:
	if Ui.thema == null or Ui.thema.default_font == null:
		Ui._bouw_thema(17)
	var naam := "Stampertje"
	var zinnen: Array[String] = [Beurt.T_KIES % naam, Beurt.T_SOM_DOOS, Beurt.T_HALF,
		Beurt.T_BETAAL % "€19", Beurt.T_TERUG % [naam, "€100"], Beurt.T_OVER % [naam, "€20"],
		Beurt.T_WEG, Beurt.T_LEEG]
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
	var hoor := Snd.luister(func() -> void: _kies("s_hoofd", PK))
	waar(hoor.has("kleed_aan"), "iets aan: zwiep-pling (%s)" % str(hoor))
	await _wacht(0.05)
	gelijk(str(World.accessoires(id)), str(["pet"]), "de pet op")
	_kies("s_hoofd", PK)
	await _wacht(0.05)
	gelijk(str(World.accessoires(id)), str(["strohoed"]), "dan de strohoed (de pet gaat af)")
	_kies("s_poten", PK)
	await _wacht(0.05)
	gelijk(str(World.accessoires(id)), str(["strohoed", "gympjes"]), "en de gympjes erbij")
	hoor = Snd.luister(func() -> void: _kies("s_hoofd", PK))
	waar(hoor.has("kleed_uit"), "iets uit: alleen de zwiep (%s)" % str(hoor))
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
		for id in ["hoeden", "sjaals", "schoenen", "luxe", "kraam"]:
			waar(Hits.spot("spel_" + id) != null, "%s: de knop van %s staat er" % [str(maat), id])
		for winkel in ["hoeden", "luxe", "kraam"]:
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

# ------------------------------------------------------- de waren van 2026-10-07

## Every new piece has a slot, stands in a shop's list and in the key order,
## has an icon the fonts know, and builds and bakes on every kind (the fox and
## the pig of 2026-10-07 too) without an engine error; the old pieces keep
## their places, so yesterday's prices hold.
func test_de_nieuwe_waren() -> void:
	if Ui.thema == null or Ui.thema.default_font == null:
		Ui._bouw_thema(17)
	var nieuw := ["feestmuts", "bloem", "bandana", "belletjes", "zwemvliezen", "pantoffels",
		"regenlaarsjes", "tiara", "sterrenbril", "pompoen", "goudbal"]
	var te_koop := {}
	for winkel in Beurt.WAREN:
		for naam in Beurt.WAREN[winkel]:
			te_koop[str(naam)] = winkel
	for naam in nieuw:
		var w: Dictionary = ArtGasten.KLEDING.get(naam, {})
		waar(not w.is_empty(), "%s staat in de garderobe" % naam)
		waar(ArtGasten.SLOTEN.has(ArtGasten.slot_van(naam)), "%s heeft een slot" % naam)
		waar(te_koop.has(naam), "%s is ergens te koop" % naam)
		waar(ArtGasten.ACC_NAMEN.has(naam), "%s zit in de sleutelvolgorde" % naam)
		gelijk(Ui.mist_tekens(str(w.get("icoon", ""))).size(), 0, "het pictogram van %s bestaat" % naam)
		for kind in ArtGasten.SOORTEN:
			var kaal := ArtGasten.bouw(kind, "rust", "")
			var aan := ArtGasten.bouw(kind, "rust", naam)
			waar(aan.size() >= kaal.size(), "%s op de %s bouwt" % [naam, kind])
			var p = Art.dier(kind, "rust", 3, naam)
			waar(p != null, "%s op de %s bakt" % [naam, kind])
	gelijk(Beurt.WAREN["hoeden"].slice(0, 3), ["strik", "pet", "strohoed"], "de hoeden van gisteren")
	gelijk(Beurt.WAREN["luxe"].slice(0, 4), ["zonnebril", "slofjes", "parels", "kroon"], "de luxe van gisteren")
	var gezien := {}
	for dag in range(1, 11):
		var o := Beurt.opzet("hoeden", 2, 3, dag)
		for w in o["waren"]:
			gezien[str(w["naam"])] = true
	gelijk(gezien.size(), 5, "de opzet draagt alle vijf hoeden")

## The strip says a piece by the LAST word of its name (`_kies_keuzes`), so no
## two pieces of one stall may share that word: "⚽ Bal" stood beside "🎾 Bal"
## on one day in seven (I1c) until the gold ball became the "goudbal" (its
## wardrobe id stayed `goudbal`).
func test_elk_strookwoord_is_uniek_per_kraam() -> void:
	for winkel in Beurt.WAREN:
		var woorden := {}
		for naam in Beurt.WAREN[winkel]:
			var kl: Dictionary = ArtGasten.KLEDING.get(str(naam), {})
			var woord: String = str(kl.get("naam", naam)).split(" ")[-1]
			waar(not woorden.has(woord), "%s: %s en %s heten allebei %s"
				% [winkel, str(woorden.get(woord, "")), naam, woord])
			woorden[woord] = naam
	gelijk(str(ArtGasten.KLEDING["goudbal"]["naam"]), "goudbal", "de gouden bal heet goudbal")
	gelijk(str(ArtGasten.KLEDING["bal"]["naam"]), "bal", "de bal van de HTML blijft de bal")

## The HTML's pink ball disappears against the pink pig: on Knor it is blue,
## on every other kind it keeps its pink (the hond's golden plates pin that).
func test_de_bal_van_het_varken_is_blauw() -> void:
	for kind in ArtGasten.SOORTEN:
		var kl: Color = ArtGasten.BAL_KL_VARKEN if kind == "varken" else ArtGasten.BAL_KL
		var n := 0
		for vox in ArtGasten.bouw(kind, "rust", "bal"):
			if vox["k"] == kl:
				n += 1
		waar(n > 0, "de bal op de %s heeft zijn kleur (%d voxels)" % [kind, n])

# ------------------------------------------------ elke strook op elk scherm

## Every strip a stall can put under its card — the choice, the money, the
## numbers — for every shop × groep 3–5 × 1–14 guests × day 1–7 × thing × 4 or
## 2 paws, on the four ticket screens: each one fits inside the frame.  Every
## strip is summed from its buttons (each measured once), the sum is checked
## against the real `UiKeuzes` (`Ui.maak_knop("keuzes")`, which takes the short
## words when the long ones do not fit), and the widest three per screen are
## placed for real through `Ui.somkaart` and `Hits`.  Red before 2026-10-07: on the 360-wide phone a money strip of
## €14..€19 ("💶 10+5+2+1" four times) stuck out of the frame by up to 46 units.
func test_elke_strook_past_op_elk_scherm() -> void:
	if Ui.thema == null or Ui.thema.default_font == null:
		Ui._bouw_thema(17)
	for f in [Ui.thema.default_font, Ui.thema.get_font("font", "Button"), ThemeDB.fallback_font]:
		var acht := (f as Font).get_string_size("8", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		for c in "0123456789":
			gelijk((f as Font).get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, acht,
				"de cijfers zijn even breed (%s)" % c)
	var stroken := _alle_stroken()
	waar(stroken.size() > 40, "genoeg verschillende stroken (%d)" % stroken.size())
	var geld := 0
	var kaal: Array[String] = []
	for sleutel in stroken:
		if str(stroken[sleutel]["stap"]) == "betaal":
			geld += 1
			# pictogram AND word on every money button, the long and the short
			# strip alike (HOTEL.md §9; red on 2026-10-08: "5+2+1" on a phone)
			for k in stroken[sleutel]["keuzes"]:
				for woord in [str(k.get("tekst", "")), str(k.get("kort", k.get("tekst", "")))]:
					var knop := ("%s %s" % [str(k.get("icoon", "")), woord]).strip_edges()
					if not knop.contains(Beurt.ICOON_GELD):
						kaal.append(knop)
	waar(geld >= 10, "de geldstroken zitten erbij (%d)" % geld)
	gelijk(kaal.size(), 0, "elke geldknop draagt 💶 (%s)" % str(kaal.slice(0, 4)))
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
		var kader: Control = shell.get_node("Scherm/Kolom/Middenrij/Kaderdoos/Kader")
		var breed := kader.size.x
		# every strip, from the width of its buttons in the themed frame (each
		# button measured once); where the long words would not fit, the real
		# strip too, built the way `Hits` gets it (`Ui.maak_knop`, out of the
		# tree, where `UiKeuzes` picks its words) and then put in the frame
		var meet := World.kader_rect().size.x
		var proef = Ui.maak_knop("keuzes", {"keuzes": [{"id": "x", "icoon": "", "tekst": "1"}]})
		var rand: float = (proef as Control).get_theme_stylebox("panel").get_minimum_size().x
		var tussen := float((proef.get_node("Rij") as HBoxContainer).get_theme_constant("separation"))
		proef.free()
		var knopen := {}
		var maten: Array = []
		var te_breed: Array[String] = []
		var echt := 0
		for sleutel in stroken:
			var keuzes: Array = stroken[sleutel]["keuzes"]
			var m := _strook_maat(keuzes, knopen, kader, rand, tussen)
			var w := m.y if m.x + 8.0 > meet else m.x
			var past := m.y + 2.0 * Hits.KRAP <= breed + 0.01
			if past and m.x + 2.0 * Hits.KRAP > breed + 0.01:
				# the long words do not fit: the strip must have taken the short
				# ones where `Hits` gets it from, out of the tree
				var st = Ui.maak_knop("keuzes", {"keuzes": keuzes})
				var kort: bool = st.kort_gekozen
				st.free()
				echt += 1
				past = kort
				w = maxf(w, m.y if kort else m.x)
			maten.append([w, sleutel, m.y if m.x + 8.0 > meet else m.x])
			if not past:
				te_breed.append("%s %s: %d breed (%s)" % [str(stroken[sleutel]["winkel"]),
					str(stroken[sleutel]["stap"]), int(w), str(sleutel).left(60)])
		gelijk(te_breed.size(), 0, "%s: elke strook past in %d (%s)" % [str(maat), int(breed),
			str(te_breed.slice(0, 4))])
		# the sum of the buttons IS the strip: checked against the real
		# `UiKeuzes` rebuilt in the frame (`Ui._herzie_maten` does that) on the
		# widest ten and every 40th
		maten.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
		for i in maten.size():
			if i >= 10 and i % 40 != 0:
				continue
			var keuzes: Array = stroken[maten[i][1]]["keuzes"]
			var st = Ui.maak_knop("keuzes", {"keuzes": keuzes})
			kader.add_child(st)
			st.bouw(keuzes, meet, Ui.maten)
			var w_in: float = (st as Control).get_combined_minimum_size().x
			kader.remove_child(st)
			st.free()
			waar(absf(w_in - float(maten[i][2])) < 0.51,
				"%s: de som van de knoppen is de strook (%d / %d, %s)" % [str(maat),
					int(maten[i][2]), int(w_in), str(maten[i][1]).left(50)])
		# the widest three, placed for real under their card
		maten.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
		for i in mini(3, maten.size()):
			var r: Dictionary = stroken[maten[i][1]]
			var w := _winkel(str(r["winkel"]))
			var k = Ui.somkaart({"x": float(w["x"]), "z": float(w["z"]), "kamer": KAMER},
				str(r["som"]), {"id": KAART, "kamer": KAMER, "hoog": float(w["top"]) + 22.0,
				"icoon": "💶", "regel": str(r["regel"]), "max": 3, "keuzes": r["keuzes"]})
			for _f in 4:
				await boom.process_frame
			var d: Dictionary = Hits.debug().get(STROOK, {})
			waar(not d.is_empty(), "%s: de strook staat er (%s)" % [str(maat), str(r["stap"])])
			if not d.is_empty():
				var rr: Rect2 = d["rect"]
				waar(not bool(d["krap"]), "%s: %s vond een echte plek" % [str(maat), str(r["stap"])])
				waar(rr.position.x >= -0.01 and rr.position.y >= -0.01
					and rr.end.x <= kader.size.x + 0.01 and rr.end.y <= kader.size.y + 0.01,
					"%s: de breedste strook (%s %s) staat binnen het kader (%s)" % [str(maat),
						str(r["winkel"]), str(r["stap"]), str(rr)])
			if k != null:
				k.weg()
			for _f in 2:
				await boom.process_frame
		Ui.naamplaten_leeg()
		Hits.wis_alles()
		vp.queue_free()
		await boom.process_frame
		Ui.registreer_lagen(null, null, null)
	State.s = bewaard
	Ui.set("_scherm", scherm_terug)
	Ui.zet_rust_modus(rust_voor)
	Games.hersteek()

## The floating strip `UiKeuzes` builds from `keuzes`, in the themed frame:
## x with the long words, y with the short ones.  `knopen` caches every
## button's width; `rand` and `tussen` are the strip's own panel margins and
## button spacing.
func _strook_maat(keuzes: Array, knopen: Dictionary, kader: Control, rand: float,
		tussen: float) -> Vector2:
	var vast := rand + tussen * float(maxi(0, keuzes.size() - 1))
	var uit := Vector2(vast, vast)
	for k in keuzes:
		var icoon := str(k.get("icoon", ""))
		uit.x += _knop_maat(knopen, kader, ("%s %s" % [icoon, str(k.get("tekst", ""))]).strip_edges())
		uit.y += _knop_maat(knopen, kader, ("%s %s" % [icoon,
			str(k.get("kort", k.get("tekst", "")))]).strip_edges())
	return uit

## The width of one answer button as `UiKeuzes._vul` makes it, in the themed
## frame.
func _knop_maat(knopen: Dictionary, kader: Control, tekst: String) -> float:
	if knopen.has(tekst):
		return float(knopen[tekst])
	var b := Button.new()
	b.theme_type_variation = "Keuzeknop"
	b.text = tekst
	b.custom_minimum_size = Vector2(UiThema.HOT, UiThema.HOT)
	b.add_theme_font_size_override("font_size", int(Ui.maten["wereld"]))
	b.clip_text = false
	kader.add_child(b)
	var w := b.get_combined_minimum_size().x
	kader.remove_child(b)
	b.free()
	knopen[tekst] = w
	return w

## Every strip a turn can show, by its words (the order of the buttons does not
## change the width, and neither do the digits, so two strips with the same
## buttons up to their digits count once):
##   {sleutel: {winkel, stap, keuzes, regel, som}}
## The keuzes come from the stall's own functions (`_kies_keuzes`,
## `_geld_keuzes`, `_getal_keuzes`) on a throwaway instance, so this test reads
## exactly what the game puts on the strip.  The choice strip twice per day:
## the goods the counter shows with an empty wardrobe, and the three with the
## longest words (what an animal that owns the rest is offered).
func _alle_stroken() -> Dictionary:
	var uit := {}
	for winkel in WINKELS:
		var knoop = Games._scenes[winkel].instantiate()
		for band in [3, 4, 5]:
			for n in range(1, 15):
				for dag in range(1, 8):
					var o := Beurt.opzet(winkel, n, band, dag)
					knoop.O = o
					_neem_strook(uit, winkel, "kies", knoop._kies_keuzes(), Beurt.T_KIES % "Stampertje", "")
					var lang: Array = (o["waren"] as Array).duplicate()
					lang.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
						return _woord_lengte(a) > _woord_lengte(b))
					var o2 := o.duplicate()
					o2["waren"] = lang.slice(0, 3)
					knoop.O = o2
					_neem_strook(uit, winkel, "kies", knoop._kies_keuzes(), Beurt.T_KIES % "Stampertje", "")
					knoop.O = o
					for w in o["waren"]:
						var naam := str(w["naam"])
						for kind in ["hond", "gans"]:
							var s := Beurt.sommen(o, naam, kind)
							for stap in Beurt.stappen(winkel, band):
								var keuzes: Array = []
								match str(stap):
									"betaal":
										keuzes = knoop._geld_keuzes(s)
									"som", "half", "terug", "over":
										keuzes = knoop._getal_keuzes(str(stap), s)
									_:
										continue
								var zin: Array = Beurt.kaart(str(stap), o, naam, s, "Stampertje")
								_neem_strook(uit, winkel, str(stap), keuzes, str(zin[0]), str(zin[1]))
		knoop.free()
	return uit

static func _neem_strook(uit: Dictionary, winkel: String, stap: String, keuzes: Array,
		regel: String, som: String) -> void:
	var woorden: Array[String] = []
	var kaal: Array = []
	for k in keuzes:
		woorden.append("%s %s|%s" % [str(k.get("icoon", "")), str(k.get("tekst", "")),
			str(k.get("kort", ""))])
		# without its `kies`: the instance it calls back is freed after the count
		var d: Dictionary = (k as Dictionary).duplicate()
		d.erase("kies")
		kaal.append(d)
	woorden.sort()
	# digits are tabular in every font of the game (checked in the test), so
	# two strips that differ only in their digits are as wide as each other
	var sleutel := " / ".join(woorden)
	for c in "123456789":
		sleutel = sleutel.replace(c, "0")
	if not uit.has(sleutel):
		uit[sleutel] = {"winkel": winkel, "stap": stap, "keuzes": kaal, "regel": regel,
			"som": som}

static func _woord_lengte(w: Dictionary) -> int:
	var kl: Dictionary = ArtGasten.KLEDING.get(str(w["naam"]), {})
	return str(kl.get("naam", w["naam"])).split(" ")[-1].length() + str(int(w["prijs"])).length()

# ------------------------------------------------- een paar is één ding

## Only the shoe stall counts paws (a shoe each, `poten_van`).  Everywhere else
## a pair — the souvenir stall's flippers and slippers (2026-10-07), the luxury
## shop's golden slippers — is ONE thing at ONE price: `veel` is the plural on
## the card, never a price rule.  So outside the shoe stall a dog (4 paws) and
## a goose (2) pay exactly the same, and no card asks "how much do 4 cost".
func test_een_paar_is_een_ding_buiten_de_schoenenkraam() -> void:
	waar(Beurt.WAREN["kraam"].has("zwemvliezen") and Beurt.WAREN["kraam"].has("pantoffels"),
		"zwemvliezen en pantoffels liggen bij de souvenirkraam")
	for naam in ["zwemvliezen", "pantoffels"]:
		waar(bool(ArtGasten.KLEDING[naam].get("veel", false)), "%s is een paar" % naam)
	var paren := 0
	for winkel in WINKELS:
		for band in [3, 4, 5]:
			for n in [1, 4, 8]:
				for dag in [1, 2, 5]:
					var o := Beurt.opzet(winkel, n, band, dag)
					for w in o["waren"]:
						var naam := str(w["naam"])
						var hond := Beurt.sommen(o, naam, "hond")
						var gans := Beurt.sommen(o, naam, "gans")
						if winkel == "schoenen":
							gelijk(int(hond["som"]), int(hond["prijs"]) * 4,
								"schoenen %s: vier pootjes, vier keer de prijs" % naam)
							gelijk(int(gans["som"]), int(gans["prijs"]) * 2,
								"schoenen %s: de gans twee keer" % naam)
							continue
						gelijk(int(hond["totaal"]), int(gans["totaal"]),
							"%s %s groep %d: elk dier betaalt hetzelfde" % [winkel, naam, band])
						if winkel == "kraam":
							# one price for the whole thing; in groep 5 the stall
							# sells it at half price (R1, 2026-10-09)
							gelijk(int(hond["totaal"]), int(w["prijs"]) / (2 if band == 5 else 1),
								"kraam %s: één prijs voor het hele ding" % naam)
						if bool(ArtGasten.KLEDING[naam].get("veel", false)):
							paren += 1
							for stap in Beurt.stappen(winkel, band):
								var zin: Array = Beurt.kaart(str(stap), o, naam, hond, "Pluis")
								waar(not str(zin[1]).contains("×"),
									"%s %s: geen keer-som op de kaart (%s)" % [winkel, naam, str(zin[1])])
	waar(paren > 0, "er zijn paren buiten de schoenenkraam (%d)" % paren)

# ------------------------------------------- de toonbank van een dichte kraam

## The band `_wereld` gets for `n` guests (`kunnen` 5 lifts the adaptive cap).
func _band_bij(n: int) -> int:
	return maxi(3, mini(Sommen.band_van_n(n), 6))

## What a counter holds now: [[model, x, z, hoog], ...] for the ids `fmt % i`.
func _toonbank(fmt: String, wie: String) -> Array:
	var uit: Array = []
	for i in 6:
		var p := World.decor_plek(fmt % i, KAMER)
		if p.is_empty():
			continue
		waar(str(p.get("door", "")) == wie, "%s staat er van %s (%s)" % [fmt % i, wie, str(p.get("door", ""))])
		uit.append([str(p["model"]), float(p["x"]), float(p["z"]), float(p["hoog"])])
	return uit

## W5a (2026-10-08): a CLOSED stall shows on its counter exactly the goods it
## sells when it opens — one choice (`Beurt.te_koop`) over the same day and N —
## not the first three of its list (the eleven goods of 2026-10-07 only came
## round once the stall was open).  For day 1..7 × N 1..8 × every stall: the
## counter at rest, put down by the registry itself (`Games.hersteek`), holds
## the goods the opened stall (`Games.start`) puts on it, on the same spots;
## every good of every stall comes round on some closed counter; and every
## good shown has its `waar_<naam>` model, which bakes without an engine error.
func test_de_dichte_toonbank_toont_de_waren_van_vandaag() -> void:
	_op()
	var gezien := {}
	for winkel in WINKELS:
		gezien[winkel] = {}
	var anders := 0
	for dag in range(1, 8):
		for n in range(1, 9):
			_wereld(n, _band_bij(n), dag)
			Games.hersteek()
			for winkel in WINKELS:
				var rust := _toonbank("rust_" + winkel + "_%d", "rust:" + winkel)
				var w := _winkel(winkel)
				gelijk(rust.size(), int(w.get("toon", 3)),
					"%s dag %d N %d: de dichte toonbank is vol" % [winkel, dag, n])
				if not Games.start(winkel):
					fout("%s dag %d N %d: de kraam gaat niet open" % [winkel, dag, n])
					continue
				var open := _toonbank("wk_w%d", winkel)
				gelijk(rust, open, "%s dag %d N %d: dicht staat er wat open te koop is" % [winkel, dag, n])
				Games.stop()
				var eerste: Array = Beurt.WAREN[winkel].slice(0, 3)
				var namen: Array = []
				for stuk in rust:
					var naam := str(stuk[0]).trim_prefix("waar_")
					namen.append(naam)
					gezien[winkel][naam] = true
				if namen != eerste:
					anders += 1
				gelijk(_toonbank("rust_" + winkel + "_%d", "rust:" + winkel).size(), rust.size(),
					"%s dag %d N %d: dicht weer, de waren staan er weer" % [winkel, dag, n])
	for winkel in WINKELS:
		gelijk((gezien[winkel] as Dictionary).size(), (Beurt.WAREN[winkel] as Array).size(),
			"elk ding van %s komt op de dichte toonbank (%s)" % [winkel, str(gezien[winkel].keys())])
		for naam in gezien[winkel]:
			var model := "waar_" + str(naam)
			waar(Art.heeft_model(model), "%s bestaat" % model)
			waar(Art.plaat(model, 2) != null and Art.plaat(model, 4) != null, "%s bakt" % model)
	waar(anders > 0, "niet elke dag de eerste drie (%d keer anders)" % anders)
	_af()

## The counters follow the hotel without a game: a new morning (`Hotel.morgen`)
## and a guest more (the render after a check-in) put the goods of the new day
## and the new N on the closed counters — the hook is `Hotel.bord_veranderd`
## after every render, which `Games` already listened to.  A counter that did
## not change is not put down again (every `World.decor` redraws the room).
func test_de_toonbank_volgt_de_dag_en_de_gasten() -> void:
	_op()
	_wereld(4, 4, 2)
	Games.hersteek()
	var verwacht := func(winkel: String) -> Array:
		var o := Beurt.opzet(winkel, State.n_gasten(), State.band(), int(State.s["dag"]))
		var uit: Array = []
		for w in Beurt.te_koop(o, [], int(_winkel(winkel).get("toon", 3))):
			uit.append("waar_" + str(w["naam"]))
		return uit
	var modellen := func(winkel: String) -> Array:
		var uit: Array = []
		for stuk in _toonbank("rust_" + winkel + "_%d", "rust:" + winkel):
			uit.append(stuk[0])
		return uit
	var gisteren := {}
	for winkel in WINKELS:
		gelijk(modellen.call(winkel), verwacht.call(winkel), "%s dag 2: de waren van vandaag" % winkel)
		gisteren[winkel] = modellen.call(winkel)
	# nothing changed: hersteek puts nothing down again
	var versie := World.decor_versie()
	Games.hersteek()
	gelijk(World.decor_versie(), versie, "niets veranderd: niets opnieuw neergezet")
	Hotel.morgen()
	gelijk(int(State.s["dag"]), 3, "het is dag 3")
	var nieuw := 0
	for winkel in WINKELS:
		gelijk(modellen.call(winkel), verwacht.call(winkel), "%s na de morgen: de waren van dag 3" % winkel)
		if modellen.call(winkel) != gisteren[winkel]:
			nieuw += 1
	waar(nieuw > 0, "de morgen zet andere waren op de toonbank (%d kramen)" % nieuw)
	# one guest more, as after a check-in: the hotel renders, the counters follow
	var gasten: Array = State.s["gasten"]
	var g: Dictionary = State.gasten_pool()[gasten.size()]
	g["kamer"] = ""
	g["bed"] = ""
	g["waar"] = "receptie"
	gasten.append(g)
	World.sync(gasten)
	var vijf := {}
	for winkel in WINKELS:
		vijf[winkel] = modellen.call(winkel)
	Hotel.render()
	nieuw = 0
	for winkel in WINKELS:
		gelijk(modellen.call(winkel), verwacht.call(winkel), "%s met %d gasten: de waren van N %d" % [winkel, State.n_gasten(), State.n_gasten()])
		if modellen.call(winkel) != vijf[winkel]:
			nieuw += 1
	waar(nieuw > 0, "een gast erbij zet andere waren op de toonbank (%d kramen)" % nieuw)
	_af()

# ------------------------------------------- R2: een misser blijft staan
# The owner (2026-10-08): "het moet niet mogelijk zijn om rekenen over te
# slaan".  An open question that had a miss comes back UNCHANGED after every
# exit — also when the child switches the animal on the game bar, when a new
# day begins, when a guest arrives (N) or the band moves.  Before 2026-10-09
# each of these threw the turn away and offered a fresh choice: a cheaper thing,
# an easier question (red log: tmp/log/r2-rood-winkel.log).

## Into the shop, choose, answer the first sum WRONG and wait until the animal
## is out and the game closed by itself.  {gast, waar, stap, keuzes} of that
## question.
func _misser(spel: String) -> Dictionary:
	waar(Games.start(spel), "%s start" % spel)
	await _wacht(0.3)
	_kies(_keuzes()[0])
	await _wacht_kaart()
	var st := _stand(spel)
	var uit := {"gast": str(st.get("gast", "")), "waar": str(st.get("waar", "")),
		"stap": str(st.get("stap", "")), "keuzes": str(_keuzes())}
	waar(not str(uit["stap"]) in ["kies", "af", ""], "%s: een rekenvraag staat open (%s)" % [spel, uit["stap"]])
	_kies(_fout_keuze(spel))
	await _wacht(WinkelSpel.SIP_S + WinkelSpel.WEG_WACHT + 0.8)
	gelijk(Games.actief(), "", "%s: na de misser is het spel dicht" % spel)
	gelijk(int(_stand(spel).get("missers", 0)), 1, "%s: de misser is bewaard" % spel)
	return uit

## Back into the shop: the same animal, the same thing, the same step and the
## same four choices in the same order.
func _zelfde_vraag(spel: String, voor: Dictionary, wat: String) -> void:
	Games.hersteek()
	waar(Games.start(spel), "%s: terug de winkel in (%s)" % [spel, wat])
	await _wacht(0.3)
	var st := _stand(spel)
	gelijk(str(st.get("gast", "")), voor["gast"], "%s: hetzelfde dier (%s)" % [spel, wat])
	gelijk(str(st.get("waar", "")), voor["waar"], "%s: hetzelfde ding (%s)" % [spel, wat])
	gelijk(str(st.get("stap", "")), voor["stap"], "%s: dezelfde vraag (%s)" % [spel, wat])
	gelijk(str(_keuzes()), voor["keuzes"], "%s: dezelfde vier keuzes (%s)" % [spel, wat])
	gelijk(int(st.get("missers", 0)), 1, "%s: de misser telt nog (%s)" % [spel, wat])

## An animal with a bed that is not `gast`.
func _ander_dier(gast: String) -> String:
	for g in State.s["gasten"]:
		if str(g.get("id", "")) != gast and not str(g.get("bed", "")).is_empty():
			return str(g["id"])
	return ""

func test_r2_misser_blijft_na_wissel_van_dier() -> void:
	for spel in ["hoeden", "schoenen"]:
		_op()
		_wereld(4, 4)
		var voor: Dictionary = await _misser(spel)
		# picked on the game bar before going back in ...
		var ander := _ander_dier(str(voor["gast"]))
		waar(not ander.is_empty(), "er is een ander dier")
		State.s["speler"] = ander
		await _zelfde_vraag(spel, voor, "ander dier gekozen")
		# ... and the chip tapped while the question is open
		Games.wissel_speler()
		await _wacht(0.3)
		gelijk(str(_stand(spel).get("gast", "")), voor["gast"], "%s: wisselen laat de vraag staan" % spel)
		gelijk(str(_stand(spel).get("stap", "")), voor["stap"], "%s: dezelfde stap na het wisselen" % spel)
		gelijk(str(_keuzes()), voor["keuzes"], "%s: dezelfde keuzes na het wisselen" % spel)
		await _speel_goed(spel)
		gelijk(str(_stand(spel).get("stap", "")), "af", "%s: goed beantwoord, dan klaar" % spel)
		State.s.erase("speler")
		_af()

func test_r2_misser_blijft_na_een_nieuwe_dag() -> void:
	_op()
	_wereld(4, 4)
	var voor: Dictionary = await _misser("sjaals")
	Hotel.morgen()
	gelijk(int(State.s["dag"]), 3, "het is de volgende dag")
	await _zelfde_vraag("sjaals", voor, "nieuwe dag")
	await _speel_goed("sjaals")
	gelijk(str(_stand("sjaals").get("stap", "")), "af", "goed beantwoord, dan klaar")
	_af()

func test_r2_misser_blijft_na_een_gast_erbij() -> void:
	_op()
	_wereld(4, 4)
	var voor: Dictionary = await _misser("kraam")
	var gasten: Array = State.s["gasten"]
	var g: Dictionary = State.gasten_pool()[gasten.size()]
	g["kamer"] = ""
	g["bed"] = ""
	g["waar"] = "receptie"
	gasten.append(g)
	World.sync(gasten)
	gelijk(State.n_gasten(), 5, "een gast erbij")
	gelijk(State.band(), 4, "de band blijft")
	await _zelfde_vraag("kraam", voor, "N 5")
	await _speel_goed("kraam")
	gelijk(str(_stand("kraam").get("stap", "")), "af", "goed beantwoord, dan klaar")
	_af()

func test_r2_misser_blijft_na_een_andere_band() -> void:
	_op()
	_wereld(7, 5)
	var voor: Dictionary = await _misser("luxe")
	State.s["kunnen"] = 2
	gelijk(State.band(), 3, "de band zakt naar groep 3")
	await _zelfde_vraag("luxe", voor, "band 3")
	await _speel_goed("luxe")
	gelijk(str(_stand("luxe").get("stap", "")), "af", "goed beantwoord, dan klaar")
	_af()

# ------------------------------------------------- R1: het rekenaandeel

## Counted by the rule of 2026-10-08 (R1): an answer on a maths strip is
## "reken", choosing the thing is "spel"; the tap that opened the shop is not
## counted.
var _teller := {"reken": 0, "spel": 0}

func _tel(soort: String) -> void:
	_teller[soort] = int(_teller[soort]) + 1

## The owner (2026-10-08): "rekenen moet minstens 50% van de interactie zijn".
## A whole turn in every shop, groep 3, 4 and 5, a small and a large hotel,
## through the real strips: reken >= spel + 1, so with the tap that opened the
## shop maths is still at least half.
func test_rekenaandeel() -> void:
	for winkel in WINKELS:
		for geval in [[3, 1], [3, 3], [4, 4], [4, 6], [5, 7], [5, 8]]:
			var band: int = geval[0]
			var n: int = geval[1]
			var wat := "%s groep %d, %d gasten" % [winkel, band, n]
			_op()
			_wereld(n, band)
			_teller = {"reken": 0, "spel": 0}
			waar(Games.start(winkel), "%s: start" % wat)
			await _wacht(0.3)
			_kies(_keuzes()[0])
			_tel("spel")
			await _wacht_kaart()
			for _i in 6:
				var st := _stand(winkel)
				var stap := str(st.get("stap", ""))
				if stap == "af" or stap.is_empty():
					break
				waar(Beurt.REKENSTAPPEN.has(stap), "%s: na het kiezen alleen sommen (%s)" % [wat, stap])
				var o := _opzet_van(winkel, st)
				var kind := str(State.gast_van(str(st["gast"])).get("kind", "hond"))
				var goed := Beurt.goed(stap, Beurt.sommen(o, str(st["waar"]), kind))
				_kies(("g%d" if stap == "betaal" else "n%d") % goed)
				_tel("reken")
				await _wacht_kaart()
			gelijk(str(_stand(winkel).get("stap", "")), "af", "%s: de beurt is af" % wat)
			waar(int(_teller["reken"]) >= int(_teller["spel"]) + 1,
				"%s: rekenen %d >= spel %d + 1" % [wat, int(_teller["reken"]), int(_teller["spel"])])
			_af()
