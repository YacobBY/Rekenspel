extends Proef
## G2 — de wekkerdienst, headless (games-b.md §2, architecture.md §12.2).
##
## De beurt wordt door de STROOK gedreven, niet door de binnenkant van het spel
## aan te roepen: elke tik gaat via de knop die het kind ook ziet
## (`wk_som_keuzes` → `Rij/K<id>`), zodat de test dezelfde weg loopt.

const ID := "wekker"

## De kaders die de vier ticketviewports opleveren (1024×768, 768×1024,
## 360×740, 740×360), gemeten door `tests/test_ui.gd` en daar afgedrukt.
const KADERS := [Vector2(990, 637), Vector2(734, 788), Vector2(326, 558),
	Vector2(558, 289)]

var _laag: Control = null

# ------------------------------------------------------------------ harnas

func _op(kader := Vector2(1000, 648)) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = kader
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	State.nieuw_spel()
	State.start_gekozen()
	Econ.rekening_stop()
	State.s["taken"] = []
	Hotel.bord_dicht()
	World.naar("gang")
	World.meet(Rect2(Vector2.ZERO, kader))

func _af() -> void:
	if Games.actief() != "":
		Games.stop()
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	if _laag != null:
		_laag.queue_free()
		_laag = null

## `n` gasten uit de pool, met een echt bed zolang er bedden zijn, en slapend.
func _gasten(n: int, dag := 1, kunnen := 3) -> Array:
	var pool := State.gasten_pool()
	var bedden := State.alle_bedden()
	var uit: Array = []
	for i in n:
		var g: Dictionary = pool[i % pool.size()]
		if i < bedden.size():
			g["kamer"] = str(bedden[i]["kamer"])
			g["bed"] = str(bedden[i]["slot"])
			g["waar"] = str(g["kamer"])
		else:
			g["kamer"] = ""
			g["bed"] = ""
			g["waar"] = "receptie"
		g["nachten"] = 100
		uit.append(g)
	State.s["gasten"] = uit
	State.s["dag"] = dag
	State.s["kunnen"] = kunnen
	State.herbereken()
	World.zet_dag(dag)
	World.sync(uit)
	# `World.sync` verplaatst een dier dat er al staat NIET, en `World.slaap`
	# laat een dier uit een andere kamer eerst lopen — in een test die geen
	# frames draait komt het dan nooit aan.  Eerst neerzetten, dan slapen.
	for g in uit:
		if not str(g["bed"]).is_empty():
			World.zet(str(g["id"]), str(g["kamer"]))
			World.slaap(str(g["id"]), str(g["kamer"]), str(g["bed"]))
	return uit

func _spel() -> MiniGame:
	var k = Games._knoop
	return k as MiniGame

func _knop(id: String) -> Button:
	var s := Hits.spot("wk_som_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		return null
	return s.knoop.get_node_or_null("Rij/K" + id) as Button

func _tik(id: String) -> bool:
	var b := _knop(id)
	if b == null:
		return false
	b.pressed.emit()
	return true

func _kaart_tekst(veld: String) -> String:
	var s := Hits.spot("wk_som")
	if s == null or not is_instance_valid(s.knoop):
		return ""
	var l := s.knoop.get_node_or_null(veld) as Label
	return "" if l == null else l.text

# ------------------------------------------------------------- 1. aanmelding

## Het spel wordt door de mapscan gevonden; de mapnaam IS het id, en geen
## enkel gedeeld bestand is aangeraakt (architecture.md §6.1).
func test_aanmelding_via_de_mapscan() -> void:
	waar(Games.lijst().has(ID), "de scan vindt res://games/wekker")
	var def := Games.definitie(ID)
	gelijk(def.get("id", ""), ID, "de mapnaam is het id")
	gelijk(def.get("naam", ""), "Wekkerdienst", "naam")
	gelijk(def.get("kamer", ""), "gang", "kamer")
	gelijk(def.get("stub", true), false, "geen stub: het spel doet echt iets")
	waar(not def.has("wens"), "de wekker lost geen wens in")
	var hs: Dictionary = def.get("hotspot", {})
	gelijk(hs.get("obj", ""), "kist", "het icoontje hangt aan de kist")
	gelijk(hs.get("dx", 0), -66, "en schuift met dx naar de klok")
	gelijk(hs.get("dz", 0), -13, "en met dz")
	gelijk(hs.get("hoog", 0), 26, "hoogte van het icoontje")
	gelijk(hs.get("icoon", ""), "⏰", "icoon")
	gelijk(hs.get("label", ""), "Wekker", "label")
	var taak: Dictionary = def.get("taak", {})
	gelijk(taak.get("id", ""), "wekker", "taak-id")
	gelijk(taak.get("icoon", ""), "⏰", "taakicoon")
	gelijk(taak.get("prio", 0), 3, "taak prio 3")
	gelijk(taak.get("tekst", ""), "Wekker zetten", "prikbordtekst")
	waar(Ui.keur_taak("wekker", str(taak.get("tekst", ""))), "≤ 6 woorden op het kaartje")

## `unlock: N >= 1`, en de prikbordvoorwaarde: er zijn gasten én (ronde is
## avond of er slaapt er één).
func test_unlock_en_prikbordvoorwaarde() -> void:
	_op()
	waar(not Games.ontgrendeld(ID), "zonder gasten is er niets te wekken")
	var wanneer: Callable = Games.definitie(ID)["taak"]["wanneer"]
	waar(not wanneer.call(State.s), "en er staat geen kaartje op het bord")
	_gasten(2)
	waar(Games.ontgrendeld(ID), "met één gast mag het spel")
	State.s["ronde"] = "vrij"
	waar(wanneer.call(State.s), "een slaper zet het kaartje op het bord")
	for g in State.s["gasten"]:
		World.zet(str(g["id"]), "gang", 20.0, 20.0)
	waar(not wanneer.call(State.s), "wakker en overdag: geen kaartje")
	State.s["ronde"] = "avond"
	waar(wanneer.call(State.s), "in de avondronde altijd wel")
	_af()

# ---------------------------------------------------- 2. de bevroren getallen

## De nagerekende tabel van games-b.md §2.3, regel voor regel.  Het spel rekent
## zelf niets uit: het roept `Sommen.Wekker.*` aan (architecture.md §2.2).
func test_getallen_van_de_generator() -> void:
	var w := Sommen.Wekker
	var rijen := [
		# N, band, dag, idx, startwoord, doelwoord, vorm
		[2, 3, 1, 0, "7 uur", "10 uur", "zet"],
		[3, 3, 2, 0, "10 uur", "1 uur", "zet"],
		[5, 4, 1, 0, "half 7", "10 uur", "zet"],
		[5, 4, 2, 1, "kwart voor 11", "half 3", "zet"],
		[8, 5, 1, 0, "7 uur", "10 uur", "duur"],
		[8, 5, 2, 0, "5 voor 10", "half 2", "zet"],
		[9, 5, 3, 0, "5 uur", "8 uur", "duur"],
	]
	for r in rijen:
		var b: Dictionary = w.beurt(int(r[1]), int(r[0]), int(r[2]), int(r[3]))
		var wat := "N=%d band=%d dag=%d idx=%d" % [r[0], r[1], r[2], r[3]]
		gelijk(w.tijd_woord(int(b["u"]), int(b["m"])), r[4], "%s: start" % wat)
		gelijk(w.tijd_woord(int(b["doelU"]), int(b["doelM"])), r[5], "%s: doel" % wat)
		gelijk(b["stap"], r[6], "%s: vorm" % wat)
	# de twee tijdsduurrijen met hun keuzes, in die volgorde
	gelijk(str(w.beurt(5, 8, 1, 0)["keuzes"]), str([11, 9, 4, 10]), "keuzes dag 1")
	gelijk(str(w.beurt(5, 9, 3, 0)["keuzes"]), str([2, 8, 9, 7]), "keuzes dag 3")

## Tijd in woorden, de Nederlandse afspraken van games-b.md §2.4.
func test_tijd_in_woorden() -> void:
	var w := Sommen.Wekker
	var paren := [[7, 0, "7 uur"], [7, 15, "kwart over 7"], [7, 30, "half 8"],
		[7, 45, "kwart voor 8"], [7, 5, "5 over 7"], [7, 20, "10 voor half 8"],
		[7, 35, "5 over half 8"], [7, 50, "10 voor 8"], [12, 30, "half 1"],
		[11, 55, "5 voor 12"]]
	for p in paren:
		gelijk(w.tijd_woord(int(p[0]), int(p[1])), p[2],
			"%d:%02d" % [int(p[0]), int(p[1])])
	gelijk(w.uur_ico(7, 40), "🕗", "het klokje van het dichtstbijzijnde uur")
	gelijk(w.uur_ico(7, 20), "🕖", "en naar beneden")

# ------------------------------------------------------- 3. één beurt per band

func _speel_beurt(band_n: int, dag: int, kunnen: int, verwacht_band: int) -> void:
	_op()
	_gasten(band_n, dag, kunnen)
	gelijk(State.band(), verwacht_band, "band bij N=%d" % band_n)
	waar(Games.start(ID), "het spel start")
	gelijk(Games.actief(), ID, "en is actief")
	gelijk(World.kamer_nu(), "gang", "de camera staat in de gang")
	var spel := _spel()
	waar(spel != null, "de spelknoop bestaat")
	if spel == null:
		_af()
		return
	var s: Dictionary = spel.stand()
	gelijk(int(s["band"]), verwacht_band, "de beurt draait op deze band")
	# de tijdsduurvraag eerst, als die er is
	if str(s["stap"]) == "duur":
		waar(_knop("u%d" % int(s["doelU"])) != null, "de goede uurknop staat er")
		gelijk(_kaart_tekst("Kolom/Regel2"), "Hoe laat is hij wakker?",
			"de tijdsduurvraag staat op de kaart")
		waar(_tik("u%d" % int(s["doelU"])), "het goede uur wordt getikt")
		gelijk(str(s["stap"]), "zet", "daarna mag de klok gezet worden")
	# de klok staat op de startstand en draagt die als cijfer
	var start_woord: String = Sommen.Wekker.tijd_woord(int(s["u"]), int(s["m"]))
	gelijk(_kaart_tekst("Kolom/Rij/Som"), "nu: " + start_woord, "de sombalk")
	waar(not World.decor_plek("klok", "gang").is_empty(), "de klok hangt in de gang")
	# draaien tot de wijzers op het doel staan: alleen met de knoppen die
	# deze band heeft, en altijd VOORUIT
	var stappen := {"uur": 60, "kwartier": 15, "vijf": 5}
	var rondjes := 0
	while not spel.goed() and rondjes < 200:
		rondjes += 1
		var gedaan := false
		for knop in ["uur", "kwartier", "vijf"]:
			if _knop(knop) == null:
				continue
			var nu: int = Sommen.Wekker.in_min(int(s["u"]), int(s["m"]))
			var doel: int = Sommen.Wekker.in_min(int(s["doelU"]), int(s["doelM"]))
			var over: int = posmod(doel - nu, 720)
			if over >= int(stappen[knop]):
				waar(_tik(knop), "tik %s" % knop)
				gedaan = true
				break
		if not gedaan:
			break
	waar(spel.goed(), "de wijzers staan op de wektijd (band %d)" % verwacht_band)
	gelijk(_kaart_tekst("Kolom/Rij/Som"),
		"nu: " + Sommen.Wekker.tijd_woord(int(s["doelU"]), int(s["doelM"])),
		"de sombalk loopt mee")
	var sterren_voor: int = int(State.s["sterren"])
	waar(_tik("klaar"), "✅ Klaar")
	gelijk(str(spel.stand()["stap"]), "wakker", "de gast wordt wakker")
	gelijk(int(State.s["sterren"]), sterren_voor + 1, "er valt precies één ster")
	gelijk(_kaart_tekst("Kolom/Regel"),
		"⏰ %s is wakker" % str(State.s["gasten"][0]["naam"]), "de feestkaart")
	waar(Hits.spot("wk_gast") == null, "het wekkerkaartje bij de gast is weg")
	waar(Hits.spot("wk_zon") != null, "en er hangt een ☀-wolkje")
	_af()

func test_beurt_band_3() -> void:
	_speel_beurt(2, 1, 3, 3)

func test_beurt_band_4() -> void:
	_speel_beurt(5, 2, 3, 4)

func test_beurt_band_5() -> void:
	_speel_beurt(8, 2, 5, 5)

## De hele ronde: drie gasten, en daarna sluit het spel zichzelf.
func test_hele_ronde_sluit_zichzelf() -> void:
	_op()
	_gasten(3, 1, 3)
	waar(Games.start(ID), "het spel start")
	var spel := _spel()
	if spel == null:
		_af()
		return
	var gewekt := 0
	for beurt in 3:
		var s: Dictionary = spel.stand()
		if s.is_empty():
			break
		while not spel.goed():
			if not _tik("uur") and not _tik("kwartier"):
				break
		waar(_tik("klaar"), "beurt %d: ✅ Klaar" % (beurt + 1))
		gewekt += 1
		if beurt < 2:
			waar(spel.volgende(), "de volgende slaper komt aan de beurt")
			gelijk(World.kamer_nu(), "gang", "de camera staat weer bij de klok")
	gelijk(gewekt, 3, "drie gasten gewekt")
	waar(spel.volgende(), "de ronde is af")
	gelijk(int(spel.stand()["af"]), 1, "en dat staat in de stand")
	waar(Hits.spot("wk_af") != null, "er hangt een wolkje op de klok")
	gelijk(int(State.s["sterren"]), 1, "hooguit één ster per ronde (games-b.md §2.9)")
	_af()

# ------------------------------------------------------- 4. de hulpladder

## Fout is nooit straffend: geen rood, geen buzzer, de wijzers blijven staan en
## de spookwijzers komen al bij de TWEEDE misser (HOTEL.md §5, F5).
func test_misser_en_hulpladder() -> void:
	_op()
	_gasten(2, 1, 3)
	waar(Games.start(ID), "het spel start")
	var spel := _spel()
	if spel == null:
		_af()
		return
	var s: Dictionary = spel.stand()
	var u_voor := int(s["u"])
	var m_voor := int(s["m"])
	waar(not spel.goed(), "de klok staat nog niet goed")
	waar(_tik("klaar"), "eerste misser")
	gelijk(int(s["missers"]), 1, "één misser geteld")
	gelijk(str(s["stap"]), "mis", "de kaart staat op mis")
	gelijk(int(s["u"]), u_voor, "de wijzers blijven staan (uur)")
	gelijk(int(s["m"]), m_voor, "de wijzers blijven staan (minuut)")
	gelijk(_kaart_tekst("Kolom/Hulp"), "💛 draai nog wat verder", "hulp, trede 1")
	gelijk(_kaart_tekst("Kolom/Rij/Som"), "", "de sombalk is leeg na een misser")
	gelijk(_kaart_tekst("Kolom/Regel"),
		"⏰ De klok staat op %s" % Sommen.Wekker.tijd_woord(u_voor, m_voor),
		"de kaart zegt wat de klok NU zegt")
	waar(not spel.klok_params().has("spookU"), "nog geen spookwijzers")
	waar(_tik("klaar"), "tweede misser")
	gelijk(int(s["missers"]), 2, "twee missers geteld")
	gelijk(_kaart_tekst("Kolom/Hulp"), "👻 de spookwijzers wijzen mee", "hulp, trede 2")
	gelijk(int(spel.klok_params().get("spookU", 0)), int(s["doelU"]),
		"de spookuurwijzer wijst de wektijd")
	gelijk(int(spel.klok_params().get("spookM", -1)), int(s["doelM"]),
		"en de spookminuutwijzer ook")
	gelijk(int(State.s["sterren"]), 0, "een misser kost geen ster")
	# verder draaien zet de gewone zin terug, de spookwijzers blijven
	waar(_tik("uur"), "verder draaien")
	gelijk(str(s["stap"]), "zet", "de gewone zin is terug")
	waar(spel.klok_params().has("spookU"), "de spookwijzers blijven wijzen")
	_af()

## De tijdsduurvraag van band 5: fout geeft de telladder, goed bouwt de kaart
## met de andere knoppen opnieuw op.
func test_tijdsduurvraag() -> void:
	_op()
	_gasten(8, 1, 5)
	waar(Games.start(ID), "het spel start")
	var spel := _spel()
	if spel == null:
		_af()
		return
	var s: Dictionary = spel.stand()
	gelijk(str(s["stap"]), "duur", "dag 1, gast 1, band 5: een tijdsduurvraag")
	gelijk(_kaart_tekst("Kolom/Regel"),
		"⏰ %s slaapt nog %d uur" % [str(State.s["gasten"][0]["naam"]), int(s["duur"])],
		"de zin van de tijdsduurvraag")
	gelijk(_kaart_tekst("Kolom/Regel2"), "Hoe laat is hij wakker?", "en de vraag")
	gelijk(Hits.spot("wk_som_keuzes").knoop.tooltip_text,
		"hoe laat wordt hij wakker?", "de strooktitel")
	gelijk((s["keuzes"] as Array).size(), 4, "vier uurknoppen")
	var fout_u := 0
	for q in s["keuzes"]:
		if int(q) != int(s["doelU"]):
			fout_u = int(q)
			break
	waar(_tik("u%d" % fout_u), "een verkeerd uur")
	gelijk(int(s["missers"]), 1, "één misser")
	gelijk(str(s["stap"]), "duur", "de vraag blijft staan")
	var ladder: String = "💛 " + " … ".join(PackedStringArray(
		range(0, int(s["duur"]) + 1).map(func(i: int) -> String:
			return str(Sommen.Wekker.u12(int(s["u"]) + i)))))
	gelijk(_kaart_tekst("Kolom/Hulp"), ladder, "de telladder telt uur voor uur mee")
	waar(_tik("u%d" % int(s["doelU"])), "het goede uur")
	gelijk(str(s["stap"]), "zet", "nu mag de klok gezet worden")
	waar(_knop("uur") != null and _knop("vijf") != null and _knop("klaar") != null,
		"en de draaiknoppen van band 5 staan er")
	_af()

## Het wekkerkaartje hangt bij het dier in ZIJN kamer.  Staat de camera in de
## gang, dan is er geen `wk_gast` — en dus ook geen Control die in de hoek van
## het kader blijft staan: `Hits.plaats()` zet `visible` alleen voor hotspots
## uit de kamer die in beeld is (zie de contractnotitie in `spel.gd`).
func test_wekkerkaartje_alleen_in_de_kamer_van_de_gast() -> void:
	_op()
	_gasten(2, 1, 3)
	waar(Games.start(ID), "het spel start")
	gelijk(World.kamer_nu(), "gang", "de camera staat in de gang")
	Hits.plaats()
	waar(Hits.spot("wk_gast") == null,
		"de slaper ligt in zijn eigen kamer: geen wolkje in de gang")
	# geen enkele Control van dit spel staat zichtbaar buiten zijn eigen kamer
	for id in Hits.lijst():
		var s := Hits.spot(id)
		if s == null or s.door != ID or not is_instance_valid(s.knoop):
			continue
		waar(s.kamer == World.kamer_nu() or not s.knoop.visible,
			"%s hoort bij kamer %s maar staat zichtbaar in %s"
				% [id, s.kamer, World.kamer_nu()])
	# mee naar de slaapkamer: daar hoort het kaartje wel te staan
	var g: Dictionary = State.s["gasten"][0]
	World.naar(str(g["kamer"]))
	Hits.plaats()
	var w := Hits.spot("wk_gast")
	waar(w != null, "in de kamer van de gast hangt het wekkerkaartje wel")
	if w != null:
		gelijk(w.kamer, str(g["kamer"]), "en het hangt in die kamer")
		var st: Dictionary = _spel().stand()
		var wil: String = Sommen.Wekker.tijd_woord(int(st["doelU"]), int(st["doelM"]))
		waar(w.knoop.tooltip_text.contains(wil),
			"met de wektijd erin: '%s'" % w.knoop.tooltip_text)
		waar(w.knoop.tooltip_text.contains("💤"), "en het slaapicoontje")
	# terug naar de gang: het kaartje gaat weer weg
	World.naar("gang")
	Hits.plaats()
	waar(Hits.spot("wk_gast") == null, "terug in de gang is het wolkje weer weg")
	_af()
# ------------------------------------------------------------ 5. herstellen

## Een belofte overleeft geen herlaad: de stand komt altijd uit ctx.data().
func test_herstel_uit_ctx_data() -> void:
	_op()
	_gasten(5, 2, 3)
	waar(Games.start(ID), "het spel start")
	var spel := _spel()
	if spel == null:
		_af()
		return
	waar(_tik("uur"), "één keer draaien")
	waar(_tik("klaar"), "en er een keer naast zitten")
	var voor: Dictionary = (spel.stand() as Dictionary).duplicate(true)
	Games.stop()
	# de opslag als een echt herlaad: schrijven, wissen, terugleze
	waar(State.bewaar(), "de stand is bewaard")
	State.s = {}
	waar(State.lees(), "en weer gelezen")
	World.sync(State.s["gasten"])
	for g in State.s["gasten"]:
		if not str(g["bed"]).is_empty():
			World.slaap(str(g["id"]), str(g["kamer"]), str(g["bed"]))
	waar(Games.start(ID), "het spel start opnieuw")
	var na_herlaad: Dictionary = _spel().stand()
	for sleutel in ["dag", "N", "band", "idx", "doelU", "doelM", "u", "m", "missers"]:
		gelijk(int(na_herlaad[sleutel]), int(voor[sleutel]),
			"%s overleeft het herlaad" % sleutel)
	gelijk(str(na_herlaad["gast"]), str(voor["gast"]), "dezelfde gast")
	gelijk(str(na_herlaad["stap"]), "mis", "en dezelfde stap")
	_af()

## Een andere dag hoort een nieuwe beurt te geven, geen oude stand.
func test_andere_dag_geeft_een_nieuwe_beurt() -> void:
	_op()
	_gasten(5, 2, 3)
	waar(Games.start(ID), "het spel start")
	var voor: Dictionary = (_spel().stand() as Dictionary).duplicate(true)
	Games.stop()
	State.s["dag"] = 3
	World.zet_dag(3)
	waar(Games.start(ID), "het spel start op een nieuwe dag")
	var nu: Dictionary = _spel().stand()
	gelijk(int(nu["dag"]), 3, "de nieuwe dag")
	gelijk(int(nu["missers"]), 0, "en een schone beurt")
	waar(int(nu["doelU"]) != int(voor["doelU"]) or int(nu["doelM"]) != int(voor["doelM"]),
		"met een andere wektijd")
	_af()

## Geen gasten: een wolkje op de kist, daarna sluit het spel zichzelf.
func test_zonder_gasten_een_wolkje() -> void:
	_op()
	State.s["gasten"] = []
	World.sync([])
	# `unlock` houdt het spel normaal tegen; wie het toch start krijgt dit
	waar(Games.start(ID), "het spel start")
	var s := Hits.spot("wk_leeg")
	waar(s != null, "er hangt een wolkje")
	if s != null:
		waar(s.knoop.tooltip_text.contains("nog geen gasten")
			and s.knoop.tooltip_text.contains("🛏"),
			"en dat zegt het letterlijk: '%s'" % s.knoop.tooltip_text)
	waar(Hits.spot("wk_som") == null, "er is geen kaart")
	_af()

# --------------------------------------------------------- 6. stoppen opruimen

func test_stop_laat_de_wereld_schoon_achter() -> void:
	_op()
	_gasten(2, 1, 3)
	Hits.maak({"id": "hotelknop", "kamer": "gang", "x": 8.0, "z": 8.0, "y": 10.0,
		"icoon": "🔔", "label": "Bel", "door": "keurmeester",
		"aan": func(_s) -> void: pass})
	waar(Games.start(ID), "het spel start")
	waar(not World.decor_plek("klok", "gang").is_empty(), "de klok staat er")
	var eigen := 0
	for id in Hits.lijst():
		if Hits.spot(id).door == ID:
			eigen += 1
	waar(eigen >= 4, "het spel plaatste eigen knoppen (%d)" % eigen)
	Games.stop()
	gelijk(Games.actief(), "", "er draait niets meer")
	gelijk(Hits.voorrang_van(), "", "en niemand heeft voorrang")
	for id in Hits.lijst():
		waar(Hits.spot(id).door != ID, "geen hotspot van het spel bleef staan: %s" % id)
	waar(Hits.spot("wk_som") == null, "de kaart is weg")
	waar(Hits.spot("wk_plaat") == null, "het tagje op de wijzerplaat is weg")
	waar(World.decor_plek("klok", "gang").is_empty(), "en de klok is weg")
	gelijk(World.decor_lijst().filter(func(d): return d["door"] == ID).size(), 0,
		"al het eigen decor is weg")
	waar(Hits.spot("hotelknop") != null, "de knop van een ander bleef staan")
	_af()

# ---------------------------------------------------------- 7. de kindtekst

## Elke zin letterlijk uit games-b.md §2.10, plus het budget van F4 (≤ 8
## woorden én ≤ 40 tekens) voor élke naam-en-tijdcombinatie die kan vallen.
func test_kindtekst_letterlijk_en_binnen_het_budget() -> void:
	_op()
	_gasten(8, 1, 5)
	waar(Games.start(ID), "het spel start")
	var spel := _spel()
	if spel == null:
		_af()
		return
	var s: Dictionary = spel.stand()
	# de langste naam uit de pool, zodat de zin op zijn zwaarst wordt gemeten
	var lang := ""
	for g in State.gasten_pool():
		if str(g["naam"]).length() > lang.length():
			lang = str(g["naam"])
	s["gast"] = str(State.s["gasten"][0]["id"])
	State.s["gasten"][0]["naam"] = lang
	var zinnen: Array[String] = []
	for u in range(1, 13):
		for m in range(0, 60):
			s["u"] = u
			s["m"] = m
			s["doelU"] = u
			s["doelM"] = m
			for stap in ["zet", "mis"]:
				s["stap"] = stap
				for dutje in [true, false]:
					s["slaapt"] = dutje
					var zin: Array = spel.zin_zet()
					zinnen.append(str(zin[0]))
					zinnen.append(str(zin[1]))
			s["stap"] = "duur"
			for uur in range(1, 6):
				s["duur"] = uur
				var zd: Array = spel.zin_duur()
				zinnen.append(str(zd[0]))
				zinnen.append(str(zd[1]))
			zinnen.append("%s is wakker" % lang)
			zinnen.append("nu: " + Sommen.Wekker.tijd_woord(u, m))
	var te_lang: Array[String] = []
	for zin in zinnen:
		if zin.is_empty():
			continue
		if zin.split(" ", false).size() > 8 or zin.length() > 40:
			if not te_lang.has(zin):
				te_lang.append(zin)
	gelijk(te_lang.size(), 0, "elke zin binnen 8 woorden en 40 tekens: %s" % str(te_lang))
	# de vaste zinnen, letterlijk
	var scr: GDScript = load("res://games/wekker/spel.gd")
	var k: Dictionary = scr.get_script_constant_map()
	gelijk(k["T_NAAM"], "Wekkerdienst", "naam")
	gelijk(k["T_LABEL"], "Wekker", "label")
	gelijk(k["T_TAAK"], "Wekker zetten", "prikbord")
	gelijk(k["T_LEEG"], "nog geen gasten", "geen gasten")
	gelijk(k["T_ZET"], "Zet de klok", "zetten")
	gelijk(k["T_ZET_MORGEN"], "Zet de klok voor morgen", "zetten voor morgen")
	gelijk(k["T_DUUR2"], "Hoe laat is hij wakker?", "tijdsduurvraag")
	gelijk(k["T_STROOK"], "draai de klok", "strooktitel")
	gelijk(k["T_STROOK_DUUR"], "hoe laat wordt hij wakker?", "strooktitel duur")
	gelijk(k["T_HULP1"], "💛 draai nog wat verder", "hulp 1")
	gelijk(k["T_HULP2"], "👻 de spookwijzers wijzen mee", "hulp 2")
	gelijk(k["T_SLAAPT_NOG"], "slaapt nog", "bij de gast, slapend")
	gelijk(k["T_NOG_NIET"], "nog niet", "bij de gast, wakker")
	gelijk(k["T_GOEDEMORGEN"], "goedemorgen", "het ☀-wolkje")
	gelijk(k["T_AF"], "allemaal gewekt", "de ronde af")
	gelijk(k["T_PLAAT"], "de wijzerplaat", "het lege tagje")
	gelijk(k["T_UUR"], "uur erbij", "knop uur")
	gelijk(k["T_UUR_K"], "uur", "knop uur, kort")
	gelijk(k["T_KWARTIER"], "kwartier erbij", "knop kwartier")
	gelijk(k["T_KWARTIER_K"], "kwartier", "knop kwartier, kort")
	gelijk(k["T_VIJF"], "5 minuten erbij", "knop vijf")
	gelijk(k["T_VIJF_K"], "5 min", "knop vijf, kort")
	gelijk(k["T_KLAAR"], "Klaar", "knop klaar")
	# geen tofu: elk teken zit in de meegeleverde subset
	var mist: Array[String] = []
	for naam in k.keys():
		var v = k[naam]
		if typeof(v) != TYPE_STRING:
			continue
		for c in Ui.mist_tekens(str(v)):
			if not mist.has(c):
				mist.append("%s in \"%s\"" % [c, str(v)])
	for u in range(1, 13):
		for c in Ui.mist_tekens(Sommen.Wekker.uur_ico(u, 0)):
			if not mist.has(c):
				mist.append(c)
	for c in Ui.mist_tekens("🕐 🕒 🕧 ✅ ☀ 💤 🛏"):
		if not mist.has(c):
			mist.append(c)
	gelijk(mist.size(), 0, "geen tofu: %s" % str(mist))
	_af()

## Pictogram ÉN woord op elke keuzeknop, nooit een kaal pictogram (F4).
func test_elke_keuzeknop_draagt_een_woord() -> void:
	_op()
	_gasten(8, 2, 5)
	waar(Games.start(ID), "het spel start")
	for id in ["uur", "kwartier", "vijf", "klaar"]:
		var b := _knop(id)
		waar(b != null, "knop %s staat er" % id)
		if b != null:
			var stukken := b.text.split(" ", false)
			waar(stukken.size() >= 2, "knop %s draagt pictogram én woord: '%s'"
				% [id, b.text])
	_af()

# ----------------------------------------------- 8. de knoppen dekken niets
##
## Deze twee draaien op de ECHTE schil in een SubViewport: de camera centreert
## een kamer alleen als er een viewport bekend is, en knoppen die tegen een
## camera op de oorsprong zijn gelegd bewijzen niets over de kamer die het kind
## ziet (dezelfde aanpak als `tests/test_hits.gd` voor de receptie).

## De vier ticketviewports.
const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740),
	Vector2i(740, 360)]

func _schil_op(maat: Vector2i) -> Dictionary:
	var boom := Engine.get_main_loop() as SceneTree
	var vp := SubViewport.new()
	vp.size = maat
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	boom.root.add_child(vp)
	var shell = load("res://scenes/main.tscn").instantiate()
	shell.set_meta("geen_start", true)
	vp.add_child(shell)
	for _f in 4:
		await boom.process_frame
	State.nieuw_spel()
	State.start_gekozen()
	Hotel.start()
	for _f in 4:
		await boom.process_frame
	_gasten(3, 1, 3)
	Hotel.naar_kamer("gang")
	for _f in 3:
		await boom.process_frame
	Games.start(ID)
	for _f in 6:
		await boom.process_frame
	var kader: Control = shell.get_node("Scherm/Kolom/Middenrij/Kaderdoos/Kader")
	return {"vp": vp, "kader": kader.size}

func _schil_af(h: Dictionary) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	if Games.actief() != "":
		Games.stop()
	Ui.naamplaten_leeg()
	Hits.wis_alles()
	(h["vp"] as SubViewport).queue_free()
	await boom.process_frame
	Ui.registreer_lagen(null, null, null)
	# De schil meldt de schermmaat aan `Ui`; die blijft anders staan voor elke
	# test die hierna draait (het cijferpad kiest zijn toetsmaat erop).  `Ui`
	# kent geen "vergeet het scherm" — zie het verslag onder "Contract gaps".
	Ui.set("_scherm", Vector2.ZERO)
	World.meet(Rect2(Vector2.ZERO, Vector2(1000, 648)))

## `Hits.dekking` is 0 % voor elke knop op een voorwerp, in vier schermmaten, en
## geen enkel element staat `krap` (architecture.md §4.3, §12.2).
func test_dekking_in_vier_kaders() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	for maat in SCHERMEN:
		var h: Dictionary = await _schil_op(maat)
		var kader: Vector2 = h["kader"]
		gelijk(Games.actief(), ID, "het spel draait bij %s" % str(maat))
		var dbg := Hits.debug()
		waar(dbg.has("wk_som"), "%s: de kaart staat er" % str(maat))
		var ids: Array = dbg.keys()
		for id in ids:
			var a: Dictionary = dbg[id]
			var r: Rect2 = a["rect"]
			waar(r.position.x >= -0.01 and r.position.y >= -0.01
				and r.end.x <= kader.x + 0.01 and r.end.y <= kader.y + 0.01,
				"%s: %s binnen het kader (%s)" % [str(maat), id, str(r)])
			waar(not a["krap"], "%s: %s vond een echte plek (%s)" % [str(maat), id, str(r)])
			if int(a["laag"]) != Hits.Laag.VAST:
				gelijk(Hits.dekking(str(id)), 0.0,
					"%s: %s dekt zijn voorwerp niet" % [str(maat), id])
				for ander in ids:
					var v: Rect2 = dbg[ander]["vlak"]
					if v.size.x <= 0.0:
						continue
					var snij := r.intersection(v)
					gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
						"%s: %s staat op het voorwerp van %s" % [str(maat), id, ander])
			# geen twee elementen over elkaar
			for ander in ids:
				if str(ander) == str(id):
					continue
				var s2 := r.intersection(dbg[ander]["rect"] as Rect2)
				gelijk(maxf(0.0, s2.size.x) * maxf(0.0, s2.size.y), 0.0,
					"%s: %s en %s overlappen" % [str(maat), id, ander])
		# elke tikbare eigen knop is minstens 48 x 48
		for id in ids:
			var s := Hits.spot(str(id))
			if s == null or s.door != ID or s.kind == "tag":
				continue
			var r: Rect2 = dbg[id]["rect"]
			waar(r.size.x >= 48.0 and r.size.y >= 48.0,
				"%s: %s is een tikdoel (%s)" % [str(maat), id, str(r.size)])
		await _schil_af(h)
	State.s = bewaard

## De klok is echt te zien, de kaart hangt eronder en de wijzerplaat blijft vrij
## (games-b.md §2.6, bindend).
func test_de_klok_is_te_zien_en_de_plaat_blijft_vrij() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	for maat in SCHERMEN:
		var h: Dictionary = await _schil_op(maat)
		var kader: Vector2 = h["kader"]
		var klok: Rect2 = World.vlak_van("wekker_klok", 48.0, 1.0, 0.0,
			World.decor_plek("klok", "gang").get("params", {}))
		var zicht := klok.intersection(Rect2(Vector2.ZERO, kader))
		waar(zicht.size.x > 0.0 and zicht.size.y > 0.0,
			"%s: de klok staat in beeld" % str(maat))
		waar(zicht.size.x * zicht.size.y >= 0.6 * klok.size.x * klok.size.y,
			"%s: en voor het grootste deel (%.0f %%)"
				% [str(maat), 100.0 * zicht.size.x * zicht.size.y / maxf(1.0, klok.size.x * klok.size.y)])
		var dbg := Hits.debug()
		waar(dbg.has("wk_plaat"), "%s: het tagje ligt op de plaat" % str(maat))
		if dbg.has("wk_plaat"):
			var plaat: Rect2 = dbg["wk_plaat"]["rect"]
			waar(plaat.size.x >= 20.0 and plaat.size.y >= 20.0,
				"%s: en is minstens 20 x 20 (%s)" % [str(maat), str(plaat.size)])
			waar(klok.intersection(plaat).size.y > 0.0,
				"%s: en ligt op de klok" % str(maat))
			for id in dbg.keys():
				if str(id) == "wk_plaat":
					continue
				var snij: Rect2 = (dbg[id]["rect"] as Rect2).intersection(plaat)
				gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
					"%s: %s staat niet op de wijzerplaat" % [str(maat), id])
		# de kaart hangt ONDER de klok, niet erover
		if dbg.has("wk_som"):
			var kaart: Rect2 = dbg["wk_som"]["rect"]
			waar(kaart.position.y >= klok.end.y - 0.01,
				"%s: de kaart hangt onder de klok (%s vs %s)"
					% [str(maat), str(kaart), str(klok)])
		await _schil_af(h)
	State.s = bewaard

# -------------------------------------------------------------- 9. het model

## Het eigen voxelmodel heet `wekker_klok` (§13 Q-X1-11), draait echt met zijn
## parameters mee en bakt per stand precies één plaatje.
func test_klokmodel() -> void:
	_op()
	_gasten(2, 1, 3)
	waar(Games.start(ID), "het spel start")
	waar(Art.heeft_model("wekker_klok"), "het model heet wekker_klok")
	waar(not Art.is_wereldmodel("wekker_klok"), "en is geen wereldmodel")
	var v3 := Art.model("wekker_klok", {"uur": 3, "min": 0})
	var v9 := Art.model("wekker_klok", {"uur": 9, "min": 0})
	waar(v3.size() > 500, "de klok heeft een wijzerplaat (%d voxels)" % v3.size())
	waar(str(v3) != str(v9), "3 uur ziet er anders uit dan 9 uur")
	var spook := Art.model("wekker_klok", {"uur": 3, "min": 0, "spookU": 9, "spookM": 30})
	waar(spook.size() > v3.size(), "de spookwijzers zetten er voxels bij")
	var kleuren := {}
	for q in spook:
		kleuren[str(q["k"])] = 1
	waar(kleuren.has(str(Color("#9A8578"))), "de bleke spookuurwijzer staat erop")
	waar(kleuren.has(str(Color("#D9A0B0"))), "en de bleke spookminuutwijzer")
	# het decorstuk staat op de plek van games-b.md §2.5
	var stuk := World.decor_plek("klok", "gang")
	gelijk(int(stuk.get("x", 0)), 48, "KX")
	gelijk(int(stuk.get("z", 0)), 1, "KZ")
	gelijk(stuk.get("ver", false), true, "wanddecor")
	gelijk(str(stuk.get("model", "")), "wekker_klok", "model")
	# en het cijfer ÓP de klok draagt de stand
	var tag := Hits.spot("wk_tijd")
	waar(tag != null, "de klok draagt zijn tijd als cijfer")
	if tag != null:
		var spel := _spel()
		var s: Dictionary = spel.stand()
		var w: String = Sommen.Wekker.tijd_woord(int(s["u"]), int(s["m"]))
		gelijk((tag.knoop as Label).text, w, "en dat is de stand van de klok")
		gelijk(tag.knoop.tooltip_text, "de klok staat op %s" % w, "met zijn titel")
	_af()
