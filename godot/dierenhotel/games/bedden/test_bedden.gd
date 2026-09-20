extends RefCounted
## bedden — "Bedden op rij" (games-a.md §3), headless.
##
## LET OP — dit bestand hoort `extends Proef` te zijn en doet dat NIET, om een
## bestaande fout in `res://tests/run_tests.gd` heen (die staat buiten de
## schrijfset van dit ticket; zie "Contract gaps" in het rapport).
##
## De runner sorteert ÉÉN lijst van `res://tests/test_*.gd` plus
## `res://games/<id>/test_*.gd`, en "res://games/..." sorteert altijd vóór
## "res://tests/...".  Het bestand dat als EERSTE geladen wordt en `proef.gd`
## erft, laat `res://core/sommen.gd` en `res://core/jsgetal.gd` bij het
## afsluiten achter: `ERROR: 2 resources still in use at exit`, waar
## `tools/test.sh` (terecht) op afgaat.  Nagemeten op de kale wave-1-boom, met
## een leeg testbestand van vier regels:
##
##   tests/test_aaa_lek.gd  extends Proef   (eerste)  -> 2 resources leaked
##   tests/test_b_lek.gd    extends Proef   (tweede)  -> schoon
##   tests/test_mmm_lek.gd  extends Proef   (midden)  -> schoon
##   tests/test_zzz_lek.gd  extends Proef   (laatste) -> schoon
##   tests/test_aaa_lek.gd  extends RefCounted        -> schoon
##
## Elk wave-2-spel loopt hier dus tegenaan.  Centrale oplossing: laat de runner
## de `tests/`-bestanden apart sorteren en de spelbestanden daarachter plakken
## in plaats van één gesorteerde lijst.  Zodra dat er is, mag dit bestand terug
## naar `extends Proef` en mogen de vier hulpjes hieronder weg.
##
## De ronde wordt door de ctx heen gespeeld: elke tik gaat via `pressed` op de
## echte hotspot, nooit via een interne functie.  Wat hier vastligt:
##
##   * aanmelding, ontgrendeling (N >= 1) en het prikbordkaartje;
##   * één hele beurt op band 3, 4 en 5, met de opdracht die
##     `Sommen.Bedden.opdracht` hoort te geven;
##   * de misserweg: zacht wolkje, niets weg, geen ster, Wolkje na twee missers;
##   * de beurt overleeft een echte herlaad (`State.bewaar()` -> `State.lees()`);
##   * `stop()` laat de kamer schoon achter en geeft de deur terug;
##   * elke kinderentekst van §3.7, letterlijk;
##   * 0 % dekking in vier kadermaten, met dezelfde invarianten als
##     `tests/test_hits.gd`.

const SPEL := "bedden"
const KAMER := "kamer1"
const BRON := "res://games/bedden/spel.gd"

## De vier kadermaten van de opdracht.
const MATEN := [Vector2(1024, 768), Vector2(768, 1024), Vector2(360, 740),
	Vector2(740, 360)]

## En het wereldkader dat de échte schil bij die vier schermen overhoudt
## (`tests/test_ui.gd::test_shell_op_vijf_schermen` drukt ze af; `test_hits.gd`
## plakt dezelfde rij).  Op een telefoon scheelt dat 34 x 182 eenheden, en
## precies daar wordt het krap.
const KADERS := [Vector2(990, 637), Vector2(734, 788), Vector2(326, 558),
	Vector2(558, 289)]

var _laag: Control = null
var _vp: SubViewport = null
var _bewaard: Dictionary = {}
var _bewaard_nr := 0

# ------------------------------------------------- de vier hulpjes van Proef
##
## Woordelijk `res://tests/proef.gd`; alleen hier omdat dit bestand die niet
## mag erven (zie de kop).  De runner leest `_fouten`, `_meldingen`, `_verwacht`
## en zet `_runner` met `get()`/`set()`, dus de vorm is wat telt, niet de klasse.

var _fouten := 0
var _meldingen: Array[String] = []
var _runner = null
var _verwacht := 0

func gelijk(gekregen, verwacht, wat := "") -> void:
	if typeof(gekregen) == TYPE_FLOAT or typeof(verwacht) == TYPE_FLOAT:
		if is_equal_approx(float(gekregen), float(verwacht)):
			return
	elif str(gekregen) == str(verwacht):
		return
	fout("%s: kreeg %s, verwacht %s" % [wat, str(gekregen), str(verwacht)])

func waar(v: bool, wat := "") -> void:
	if not v:
		fout("%s: niet waar" % wat)

func fout(melding: String) -> void:
	_fouten += 1
	_meldingen.append(melding)

# ------------------------------------------------------------------ opzet

func _boom() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

## De camera centreert een kamer alleen als er een viewport geregistreerd is
## (`World.cam_doel` geeft anders de oorsprong terug), en zonder camera staat
## elk wereldankerpunt op de linkerrand — dan bewijst een dekkingsmeting niets
## over de kamer die het kind ziet (dezelfde reden als
## `tests/test_hits.gd::_hotel_op`).  Deze opzet is de kale versie daarvan:
## een SubViewport en een Node2D, zonder de hele schil.
func _op(kader := Vector2(1000, 648)) -> void:
	_bewaard = State.s.duplicate(true)
	_bewaard_nr = Rooms.nr_stand()
	_laag = Control.new()
	_laag.size = kader
	_boom().root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	_vp = SubViewport.new()
	_vp.size = Vector2i(kader)
	_boom().root.add_child(_vp)
	var scene := Node2D.new()
	_vp.add_child(scene)
	World.registreer_viewport(_vp, scene)
	World.meet(Rect2(Vector2.ZERO, kader))

func _af() -> void:
	Games.stop()
	Hits.wis_alles()
	World.sync([])
	Rooms.herstel()
	Rooms.zet_nr(_bewaard_nr)
	Ui.registreer_lagen(null, null, null)
	World.registreer_viewport(null, null)
	if _vp != null:
		_vp.queue_free()
		_vp = null
	if _laag != null:
		_laag.queue_free()
		_laag = null
	State.s = _bewaard
	# één beeld verder, zodat de viewport en zijn textuur echt weg zijn: anders
	# meldt de motor bij het afsluiten "resources still in use at exit", en dat
	# is een ERROR-regel die `tools/test.sh` (terecht) niet toestaat
	await _boom().process_frame

## Een hotel met `n` gasten zonder bed in kamer 1, op dag `dag`, met `kunnen`
## als plafond van de band.  Band = max(3, min(bandVanN(N), kunnen + 1)).
func _hotel(n: int, kunnen: int, dag: int, kader := Vector2(1000, 648)) -> void:
	State.nieuw_spel()
	State.s["dag"] = dag
	State.s["kunnen"] = kunnen
	var pool := State.gasten_pool()
	var gasten: Array = []
	for i in n:
		var g: Dictionary = (pool[i % pool.size()] as Dictionary).duplicate(true)
		g["id"] = "g%d" % i
		g["waar"] = KAMER
		g["kamer"] = ""
		g["bed"] = ""
		gasten.append(g)
	State.s["gasten"] = gasten
	World.sync(gasten)
	World.naar(KAMER)
	World.meet(Rect2(Vector2.ZERO, kader))
	Hotel.render()

func _d() -> Dictionary:
	return State.spel_data(SPEL)

func _tik(id: String) -> bool:
	var s := Hits.spot(id)
	if s == null or not is_instance_valid(s.knoop) or not (s.knoop is BaseButton):
		return false
	(s.knoop as BaseButton).emit_signal("pressed")
	return true

func _titel(id: String) -> String:
	var s := Hits.spot(id)
	if s == null or not is_instance_valid(s.knoop):
		return ""
	return s.knoop.tooltip_text

func _tekst(id: String) -> String:
	var s := Hits.spot(id)
	if s == null or not is_instance_valid(s.knoop):
		return ""
	if s.knoop.has_method("inhoud_tekst"):
		return str(s.knoop.call("inhoud_tekst"))
	return _zoek_label(s.knoop)

func _zoek_label(k: Node) -> String:
	var uit := ""
	if k is Label:
		uit = (k as Label).text
	elif k is Button and not (k as Button).text.is_empty():
		uit = (k as Button).text
	for kind in k.get_children():
		var diep := _zoek_label(kind)
		if not diep.is_empty():
			uit = (uit + " " + diep).strip_edges()
	return uit

## Wacht tot `klaar` waar is, of tot `sec` seconden verstreken zijn.
func _wacht(klaar: Callable, sec: float) -> bool:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(sec * 1000.0):
		if bool(klaar.call()):
			return true
		await _boom().process_frame
	return bool(klaar.call())

## Drukt op één knop van de keuzestrook onder de vraagkaart.
func _kies_getal(n: int) -> bool:
	var s := Hits.spot("bd_som_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		return false
	var rij := s.knoop.get_node_or_null("Rij")
	if rij == null:
		return false
	var kn := rij.get_node_or_null("Kn%d" % n)
	if kn == null or not (kn is BaseButton):
		return false
	(kn as BaseButton).emit_signal("pressed")
	return true

## Drukt op een knop van de strook die níét het goede antwoord is.
func _kies_fout() -> bool:
	var s := Hits.spot("bd_som_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		return false
	var rij := s.knoop.get_node_or_null("Rij")
	if rij == null:
		return false
	var goed := "Kn%d" % int(_d()["doel"])
	for k in rij.get_children():
		if k.name != goed and k is BaseButton:
			(k as BaseButton).emit_signal("pressed")
			return true
	return false

## Wacht de mispauze af die `Ui.misser()` op de strook legt (S5), plus lucht.
func _wacht_mispauze() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var eind := Time.get_ticks_msec() + int(Ui.MIS_PAUZE * 1000.0) + 250
	while Time.get_ticks_msec() < eind:
		await boom.process_frame

## Beantwoordt de openingsvraag goed; daarna pas begint het leggen (N9).
func _beantwoord() -> bool:
	if str(_d().get("fase", "leg")) != "vraag":
		return true
	if not _kies_getal(int(_d()["doel"])):
		return false
	Hits.plaats()
	return str(_d().get("fase", "")) == "leggen"

## Legt de opdracht helemaal goed neer en tikt op het pootje.
func _speel_uit() -> void:
	_beantwoord()
	var d := _d()
	var rijen := int(d["rijen"])
	var per := int(d["perRij"])
	for r in rijen:
		for _i in per:
			_tik("bd_rij%d" % r)
	_tik("bd_klaar")

# ------------------------------------------------------- aanmelding, toegang

func test_aanmelding_en_ontgrendeling() -> void:
	var def := Games.definitie(SPEL)
	gelijk(def.get("id", ""), SPEL, "de mapnaam IS het spel-id")
	gelijk(def.get("naam", ""), "Bedden op rij", "definitie().naam")
	gelijk(def.get("kamer", ""), KAMER, "definitie().kamer")
	var hs: Dictionary = def.get("hotspot", {})
	gelijk(hs.get("obj", ""), "mand", "het icoontje hangt op de speelmand")
	gelijk(hs.get("icoon", ""), "🛏", "hotspot.icoon")
	gelijk(hs.get("label", ""), "Bedden", "hotspot.label")
	gelijk(hs.get("hoog", 0), 14, "hotspot.hoog")
	gelijk(hs.get("dx", 0), -4, "hotspot.dx")
	gelijk(hs.get("dz", 0), -4, "hotspot.dz")
	var slot: Callable = def.get("unlock", Callable())
	waar(slot.is_valid(), "er is een unlock")
	waar(not slot.call(0, 3), "zonder gasten is bedden dicht")
	waar(slot.call(1, 3), "vanaf één gast mag het")
	var taak: Dictionary = def.get("taak", {})
	gelijk(taak.get("id", ""), "bedden", "taak.id")
	gelijk(taak.get("icoon", ""), "🛏", "taak.icoon")
	gelijk(taak.get("tekst", ""), "Zet de bedden op rij", "taak.tekst, letterlijk")
	gelijk(taak.get("prio", 0), 5, "taak.prio")
	waar(Ui.keur_taak("bedden", str(taak.get("tekst", ""))),
		"het taakkaartje blijft onder de zes woorden")
	var wanneer: Callable = taak.get("wanneer", Callable())
	waar(not wanneer.call({"gasten": []}), "zonder gasten geen kaartje")
	waar(not wanneer.call({"gasten": [{}]}), "met één gast nog niet")
	waar(wanneer.call({"gasten": [{}, {}]}), "vanaf twee gasten wel")

## Het kaartje staat echt op het prikbord, met zijn eigen tekst.
func test_prikbordkaartje_staat_er() -> void:
	_op()
	_hotel(2, 3, 3)
	var gevonden := ""
	for q in Hotel.spel_taken():
		if str(q.get("spel", "")) == SPEL:
			gevonden = str(q.get("tekst", ""))
			gelijk(q.get("kamer", ""), KAMER, "het kaartje wijst naar kamer 1")
			gelijk(q.get("actie", ""), "game:bedden", "en start het spel")
	gelijk(gevonden, "Zet de bedden op rij", "het prikbordkaartje van bedden")
	await _af()

# -------------------------------------------------------- de opdracht per band

## De kamer is de baas: `Sommen.Bedden.opdracht` mag nooit meer bedden beloven
## dan er passen.  Deze drie zijn met de hand nagerekend uit `Sommen.tafel`.
func test_opdracht_per_band() -> void:
	for geval in [
			{"n": 2, "kunnen": 3, "dag": 3, "band": 3, "per": 2, "rijen": 2, "doel": 4},
			{"n": 4, "kunnen": 3, "dag": 3, "band": 4, "per": 2, "rijen": 3, "doel": 6},
			{"n": 7, "kunnen": 4, "dag": 5, "band": 5, "per": 3, "rijen": 2, "doel": 6}]:
		_op()
		_hotel(int(geval["n"]), int(geval["kunnen"]), int(geval["dag"]))
		gelijk(State.band(), int(geval["band"]), "de band bij N=%d" % int(geval["n"]))
		waar(Games.start(SPEL), "bedden start op band %d" % int(geval["band"]))
		Hits.plaats()
		waar(_beantwoord(), "de vraag is beantwoord op band %d" % int(geval["band"]))
		var d := _d()
		gelijk(int(d["cap"]), 6, "kamer 1 heeft plek voor zes bedden erbij")
		gelijk(int(d["perRij"]), int(geval["per"]), "perRij op band %d" % int(geval["band"]))
		gelijk(int(d["rijen"]), int(geval["rijen"]), "rijen op band %d" % int(geval["band"]))
		gelijk(int(d["doel"]), int(geval["doel"]), "doel op band %d" % int(geval["band"]))
		waar(int(d["perRij"]) <= int(d["cap"]),
			"een rij is nooit breder dan wat er past")
		waar(int(d["doel"]) <= int(d["cap"]),
			"de opdracht belooft nooit meer bedden dan er passen")
		# de schuifwand is er alleen in groep 5
		var wand := int(d["wand"])
		if int(geval["band"]) >= 5 and int(geval["rijen"]) >= 2:
			gelijk(wand, int(geval["rijen"]) - 1, "de schuifwand hoort bij groep 5")
			waar(Hits.spot("bd_wand") != null, "en staat er als knop")
		else:
			gelijk(wand, 0, "geen schuifwand onder groep 5")
			waar(Hits.spot("bd_wand") == null, "en dus ook geen knop")
		await _af()

# ------------------------------------------------------------ één hele beurt

func test_hele_beurt_op_drie_banden() -> void:
	for geval in [
			{"n": 2, "kunnen": 3, "dag": 3, "band": 3},
			{"n": 4, "kunnen": 3, "dag": 3, "band": 4},
			{"n": 7, "kunnen": 4, "dag": 5, "band": 5}]:
		_op()
		_hotel(int(geval["n"]), int(geval["kunnen"]), int(geval["dag"]))
		var bedden_voor := Rooms.slots(KAMER, "bed").size()
		var sterren_voor := int(State.s["sterren"])
		waar(Games.start(SPEL), "bedden start")
		Hits.plaats()
		var d := _d()
		var doel := int(d["doel"])
		_speel_uit()
		gelijk(bool(_d().get("klaar", false)), true,
			"de beurt is goed op band %d" % int(geval["band"]))
		var af := func() -> bool: return int(_d().get("nieuw", 0)) > 0
		waar(await _wacht(af, 8.0), "de dekengolf legt echte bedden neer")
		var nieuw := int(_d().get("nieuw", 0))
		gelijk(nieuw, doel, "alle %d bedden pasten er echt bij" % doel)
		gelijk(Rooms.slots(KAMER, "bed").size(), bedden_voor + nieuw,
			"de kamer heeft er %d bedden bij" % nieuw)
		gelijk(int(State.s["sterren"]), sterren_voor + 1,
			"precies één ster voor het meedoen")
		# de eindkaart telt de rijen uit
		gelijk(_tekst("bd_som").contains("%d × %d =" % [int(d["rijen"]), int(d["perRij"])]),
			true, "de eindkaart schrijft de som uit")
		await _af()

# --------------------------------------------------------- de misserweg

## Nooit straffen: geen kruis, geen teller in beeld, niets wordt weggehaald.
func test_misser_straft_nooit_en_helpt_zacht() -> void:
	_op()
	_hotel(4, 3, 3)
	var sterren_voor := int(State.s["sterren"])
	waar(Games.start(SPEL), "bedden start")
	Hits.plaats()
	waar(_beantwoord(), "de vraag is beantwoord, het leggen begint")
	var d := _d()
	var per := int(d["perRij"])
	# één rij half vol: dat is een scheve rij
	_tik("bd_rij0")
	var voor: Array = (_d()["rij"] as Array).duplicate()
	_tik("bd_klaar")
	gelijk(int(_d()["missers"]), 1, "een misser is geteld, meer niet")
	gelijk(str((_d()["rij"] as Array)), str(voor), "er is niets weggehaald")
	gelijk(int(State.s["sterren"]), sterren_voor, "en er is geen ster afgegaan")
	gelijk(bool(_d().get("klaar", false)), false, "de beurt is niet klaar")
	Hits.plaats()
	var fout := Hits.spot("bd_fout")
	waar(fout != null, "er staat één zacht wolkje")
	if fout != null:
		waar(_tekst("bd_fout").contains("+%d" % (per - 1)),
			"het wijst aan hoeveel er nog bij mogen: kreeg '%s'" % _tekst("bd_fout"))
		waar(not _tekst("bd_fout").contains("✗") and not _tekst("bd_fout").contains("!"),
			"nooit een kruis")
	waar(Hits.spot("bd_hulp") == null, "na één misser is er nog geen hulpknop")
	# tweede misser: de hulpknop komt, en Wolkje komt na 900 ms vanzelf
	_tik("bd_klaar")
	gelijk(int(_d()["missers"]), 2, "twee missers")
	Hits.plaats()
	waar(Hits.spot("bd_hulp") != null, "vanaf twee missers staat kamerhulp Wolkje er")
	gelijk(_titel("bd_hulp"), "kamerhulp Wolkje", "de titel van de hulpknop")
	var wolkje := func() -> bool: return Hits.spot("bd_wolkje") != null
	waar(await _wacht(wolkje, 4.0), "Wolkje komt na twee missers vanzelf")
	waar(bool(_d().get("spook", false)), "de spookbedjes staan aan")
	waar(Hits.spot("bd_spook") != null, "en het spookcijfer ligt naast de rij")
	gelijk(_titel("bd_spook"), "zoveel in een rij", "de titel van het spookcijfer")
	waar(State.gezien("bedden_wolkje"), "dat Wolkje geweest is, staat in de save")
	# tikken op Wolkje legt de rij écht neer
	var lege := -1
	var lijst: Array = (_d()["rij"] as Array).duplicate()
	for r in mini(4, int(d["rijen"]) + 1):
		var n := 0 if r >= lijst.size() else int(lijst[r])
		if n < per:
			lege = r
			break
	_tik("bd_wolkje")
	var lijst2: Array = _d()["rij"]
	gelijk(int(lijst2[lege]), int(lijst[lege]) + 1,
		"Wolkje legt één bedje bij, niet de hele rij")
	await _af()

## Kist leeg en rij vol zijn allebei een zacht "nee", geen fout.
func test_rij_vol_en_kist_leeg_zeggen_zacht_nee() -> void:
	_op()
	_hotel(4, 3, 3)
	waar(Games.start(SPEL), "bedden start")
	Hits.plaats()
	waar(_beantwoord(), "de vraag is beantwoord, het leggen begint")
	var per := int(_d()["perRij"])
	var doel := int(_d()["doel"])
	for _i in per:
		_tik("bd_rij0")
	_tik("bd_rij0")                       # deze rij is al vol
	Hits.plaats()
	var lijst: Array = _d()["rij"]
	gelijk(int(lijst[0]), per, "een volle rij groeit niet door")
	waar(Hits.spot("bd_op") != null, "er staat een zacht wolkje bij die rij")
	# de kist leeg maken en dan nog eens
	var gelegd := per
	var r := 1
	while gelegd < doel and r < 4:
		for _i in per:
			if gelegd >= doel:
				break
			_tik("bd_rij%d" % r)
			gelegd += 1
		r += 1
	gelijk(_d().get("laatste", -1) != null, true, "de laatst geraakte rij is bekend")
	_tik("bd_rij0")
	gelijk(int((_d()["rij"] as Array)[0]), per, "uit een lege kist komt niets")
	# terug: eentje terug in de kist, nooit meer
	var voor := 0
	for v in (_d()["rij"] as Array):
		voor += int(v)
	waar(_tik("bd_undo"), "de terugknop staat er")
	var na_ := 0
	for v in (_d()["rij"] as Array):
		na_ += int(v)
	gelijk(na_, voor - 1, "er gaat er precies één terug in de kist")
	await _af()

# -------------------------------------------------------------- herlaad

## Beloftes en timers overleven een herlaad niet, de stand wel.  De save is
## JSON, en JSON kent geen gehele getallen: de heenweg gaat daarom echt door
## `JSON.stringify`/`parse_string`, precies zoals `State.bewaar()`/`lees()`.
## (Het bestand in `user://` blijft met rust: `State.start_gekozen()` zou de
## hele suite daarna laten schrijven en de saves van andere tests overschrijven.)
func test_beurt_overleeft_een_herlaad() -> void:
	_op()
	_hotel(4, 3, 3)
	waar(Games.start(SPEL), "bedden start")
	Hits.plaats()
	waar(_beantwoord(), "de vraag is beantwoord, het leggen begint")
	var per := int(_d()["perRij"])
	for _i in per:
		_tik("bd_rij0")
	_tik("bd_rij1")
	var voor: Array = (_d()["rij"] as Array).duplicate()
	var sig := str(_d()["sig"])
	Games.stop()
	var doc := JSON.stringify({"v": State.VERSIE, "s": State.s})
	State.s = State.standaard()
	var terug = JSON.parse_string(doc)
	waar(typeof(terug) == TYPE_DICTIONARY, "de save is weer in te lezen")
	State.s = (terug as Dictionary)["s"]
	waar(typeof(State.spel_data(SPEL).get("rijen", null)) == TYPE_FLOAT,
		"JSON geeft de tellers als float terug (dat is de hele test)")
	World.sync(State.s["gasten"])
	World.naar(KAMER)
	World.meet(Rect2(Vector2.ZERO, Vector2(1000, 648)))
	Hotel.render()
	waar(Games.start(SPEL), "bedden hervat")
	Hits.plaats()
	gelijk(str(_d()["sig"]), sig, "dezelfde opdracht, dus dezelfde signatuur")
	gelijk(str(_d().get("fase", "")), "leggen", "en de fase overleeft het herlaad")
	gelijk(str((_d()["rij"] as Array)), str(voor), "de rijen staan er nog precies zo")
	gelijk(typeof(_d()["rijen"]), TYPE_INT, "en het laatje telt weer in hele getallen")
	gelijk(_titel("bd_rij0"), "rij 1: %d van %d" % [per, per],
		"en het strookje zegt het ook")
	await _af()

# ------------------------------------------------ de openingsvraag (N9)

## Het spel begint met een vraag: de kaart met vier knoppen, en van het
## leggen zelf is dan nog niets te zien.
func test_het_spel_begint_met_een_vraag() -> void:
	_op()
	_hotel(4, 3, 3)
	waar(Games.start(SPEL), "bedden start")
	Hits.plaats()
	gelijk(str(_d().get("fase", "")), "vraag", "de eerste fase is 'vraag'")
	var strook := Hits.spot("bd_som_keuzes")
	waar(strook != null, "er hangt een keuzestrook onder de kaart")
	if strook != null:
		var rij := strook.knoop.get_node_or_null("Rij")
		waar(rij != null, "de strook heeft een rij knoppen")
		if rij != null:
			gelijk(rij.get_child_count(), 4, "het zijn er vier")
	gelijk(Hits.spot("bd_rij0"), null, "er zijn nog geen strookjes")
	gelijk(Hits.spot("bd_kist"), null, "er is nog geen dekenkist")
	gelijk(Hits.spot("bd_undo"), null, "er is nog geen 🔄")
	gelijk(Hits.spot("bd_klaar"), null, "er is nog geen 🐾")
	var kaart := _tekst("bd_som")
	waar(kaart.contains("Hoeveel bedden heb je nodig?"),
		"de vraag staat op de kaart: kreeg '%s'" % kaart)
	waar(kaart.contains("%d × %d =" % [int(_d()["rijen"]), int(_d()["perRij"])]),
		"de som staat erbij: kreeg '%s'" % kaart)
	waar(_beantwoord(), "het goede antwoord zet de fase op 'leggen'")
	waar(Hits.spot("bd_rij0") != null, "nu verschijnen de strookjes")
	waar(Hits.spot("bd_klaar") != null, "en het pootje")
	await _af()

## Wolkje legt één bedje bij, niet een hele rij (N9).
func test_wolkje_legt_een_bedje() -> void:
	_op()
	_hotel(4, 3, 3)
	waar(Games.start(SPEL), "bedden start")
	Hits.plaats()
	waar(_beantwoord(), "de vraag is beantwoord")
	_tik("bd_klaar")                       # lege vloer: misser 1
	_tik("bd_klaar")                       # misser 2 -> Wolkje komt
	var wolkje := func() -> bool: return Hits.spot("bd_wolkje") != null
	waar(await _wacht(wolkje, 4.0), "Wolkje komt vanzelf")
	gelijk(_titel("bd_wolkje"), "nog een bedje erbij", "de titel van het wolkje")
	var per := int(_d()["perRij"])
	var lijst: Array = (_d()["rij"] as Array).duplicate()
	var lege := -1
	for r in mini(4, int(_d()["rijen"]) + 1):
		var n := 0 if r >= lijst.size() else int(lijst[r])
		if n < per:
			lege = r
			break
	waar(lege >= 0, "er is een rij die nog niet vol is")
	var voor := 0 if lege >= lijst.size() else int(lijst[lege])
	_tik("bd_wolkje")
	var lijst2: Array = (_d()["rij"] as Array).duplicate()
	gelijk(int(lijst2[lege]), voor + 1,
		"het zijn er precies één meer, niet perRij")
	await _af()

## Fout antwoord op de vraag kost niets: geen ster, geen misser-teller, de
## tel-ladder helpt en dezelfde vier knoppen blijven staan.
func test_twee_missers_en_hulp_geven_geen_ster() -> void:
	_op()
	_hotel(4, 3, 3)
	var sterren_voor := int(State.s["sterren"])
	waar(Games.start(SPEL), "bedden start")
	Hits.plaats()
	waar(_kies_fout(), "eerste fout antwoord")
	await _wacht_mispauze()
	waar(_kies_fout(), "tweede fout antwoord")
	gelijk(str(_d().get("fase", "")), "vraag", "de vraag blijft staan")
	gelijk(int(_d().get("missers", 0)), 0,
		"fouten op de vraag tellen niet als leg-missers")
	gelijk(int(State.s["sterren"]), sterren_voor, "er is geen ster bijgekomen")
	waar(_tekst("bd_som").contains("tel mee"),
		"de tel-ladder staat als hulp op de kaart: kreeg '%s'" % _tekst("bd_som"))
	await _af()

## De deur is geen klaar-knop meer (N9): een tik verlaat de kamer en telt
## geen misser; de beurt staat in `ctx.data()`.
func test_de_deur_verlaat_de_kamer() -> void:
	_op()
	_hotel(4, 3, 3)
	waar(Games.start(SPEL), "bedden start")
	Hits.plaats()
	waar(_beantwoord(), "de vraag is beantwoord")
	var deur := Hits.spot("deur_kamer1_gang")
	waar(deur != null, "de deur van kamer1 hangt er")
	if deur != null:
		waar(deur.geleend_door != SPEL, "de deur is niet door bedden geleend")
	waar(_tik("deur_kamer1_gang"), "de deur is aan te tikken")
	gelijk(int(_d().get("missers", 0)), 0, "de tik op de deur is geen misser")
	gelijk(str(_d().get("fase", "")), "leggen", "de beurt staat nog in het laatje")
	await _af()

# ---------------------------------------------------------------- opruimen

func test_stop_laat_de_kamer_schoon_achter() -> void:
	_op()
	_hotel(4, 3, 3)
	waar(Games.start(SPEL), "bedden start")
	Hits.plaats()
	waar(_beantwoord(), "de vraag is beantwoord, het leggen begint")
	# de kamer is rustig gemaakt: de knoppen die op de rijen vallen zijn weg
	waar(Hits.spot("mand_%s" % KAMER) == null, "de speelmandknop staat even uit")
	waar(Hits.spot("bed_%s_bed1" % KAMER) == null, "en een vrij bed ook")
	waar(Hits.spot("bd_rij0") != null, "de strookjes staan er")
	# N9: de deur wordt niet meer geleend — 🐾 is de enige klaar-controle
	var deur := Hits.spot("deur_%s_gang" % KAMER)
	waar(deur == null or deur.geleend_door != SPEL, "de deur is niet geleend")
	Games.stop()
	Hits.plaats()
	for id in Hits.lijst():
		waar(Hits.spot(id).door != SPEL, "geen hotspot van bedden bleef staan: %s" % id)
	for id in ["bd_rij0", "bd_rij1", "bd_kist", "bd_klaar", "bd_som", "bd_wolk",
			"bd_spook", "bd_undo", "bd_hulp", "bd_wand", "bd_goed"]:
		waar(Hits.spot(id) == null, "%s is weg" % id)
	gelijk(World.decor_lijst().filter(func(d): return d["door"] == SPEL).size(), 0,
		"en het losse decor van bedden is weg")
	var deur2 := Hits.spot("deur_%s_gang" % KAMER)
	waar(deur2 == null or deur2.geleend_door == "", "de deur is weer gewoon de deur")
	waar(Hits.spot("mand_%s" % KAMER) != null, "en de kamer is weer van het hotel")
	await _af()

## De kamer zit vol: één vriendelijk kaartje, geen opdracht, geen ster.
func test_volle_kamer_belooft_niets() -> void:
	_op()
	_hotel(2, 3, 3)
	# elk vrij vakje van beide slaapkamers volzetten
	for kamer in ["kamer1", "kamer2"]:
		for _i in 40:
			var r := Rooms.get_kamer(kamer)
			if r == null or r.vrij.is_empty():
				break
			var cel: Dictionary = r.vrij[0]
			if Rooms.meubel_zet(kamer, "bed", float(cel["x"]), float(cel["z"])).is_empty():
				break
	var sterren_voor := int(State.s["sterren"])
	waar(Games.start(SPEL), "bedden start ook in een volle kamer")
	Hits.plaats()
	gelijk(str(_d().get("fase", "")), "vol", "de fase is 'vol'")
	gelijk(int(_d().get("vol", 0)), 1, "en dat staat in het laatje")
	waar(_tekst("bd_vol").contains("vol ✓"), "het wolkje zegt 'vol ✓'")
	waar(Hits.spot("bd_som") == null, "geen sommenkaart")
	waar(Hits.spot("bd_rij0") == null, "geen strookjes")
	gelijk(int(State.s["sterren"]), sterren_voor, "en geen ster")
	await _af()

# ----------------------------------------------------------------- teksten

## F3: elke kindertekst van §3.7, letterlijk, en in beeld.
func test_alle_kinderteksten() -> void:
	_op()
	_hotel(4, 3, 3)
	waar(Games.start(SPEL), "bedden start")
	Hits.plaats()
	var d := _d()
	var per := int(d["perRij"])
	var rijen := int(d["rijen"])
	var doel := int(d["doel"])
	# N9: eerst staat de openingsvraag op de kaart, met vier knoppen
	gelijk(_tekst("bd_som").contains("Hoeveel bedden heb je nodig?"), true,
		"de vraagkaart: kreeg '%s'" % _tekst("bd_som"))
	waar(Hits.spot("bd_som_keuzes") != null, "onder de vraag staan vier knoppen")
	waar(_beantwoord(), "de vraag is goed beantwoord, het leggen begint")
	gelijk(_titel("bd_rij0"), "rij 1: 0 van %d" % per, "strookje, titel")
	gelijk(_titel("bd_kist"), "dekenkist met %d bedjes" % doel, "dekenkist, titel")
	gelijk(_titel("bd_klaar"), "%d gasten mogen erin" % doel, "klaar-knop, titel")
	gelijk(_tekst("bd_wolk"), "🛏 %d bedden maken" % doel, "wolkje boven de gast")
	var kaart := _tekst("bd_som")
	waar(kaart.contains("Leg %d rijen van %d bedden" % [rijen, per]),
		"sommenkaart, regel 1: kreeg '%s'" % kaart)
	waar(kaart.contains("Zo veel bedden staan er nu"), "sommenkaart, regel 2")
	waar(kaart.contains("? × %d =" % per), "sommenkaart, som zonder volle rij")
	_tik("bd_rij0")
	Hits.plaats()
	gelijk(_titel("bd_rij0"), "rij 1: 1 van %d" % per, "strookje telt mee")
	gelijk(_titel("bd_undo"), "eentje terug in de kist", "undo, titel")
	for _i in per - 1:
		_tik("bd_rij0")
	Hits.plaats()
	waar(_tekst("bd_som").contains("1 × %d =" % per), "de som telt de volle rijen")
	gelijk(_titel("bd_kist"), "dekenkist met %d bedjes" % (doel - per),
		"de dekenkist telt af")
	await _af()

## Op een telefoon houdt het wolkje boven de gast zijn pictogram én zijn getal,
## maar niet meer zijn woorden: "🛏 6 bedden maken" is 164 eenheden breed en die
## drie kolommen zijn naast een wandelende gast niet vrij.  Op een kort kader
## (compact landschap) blijft het helemaal weg, net als de kaart boven de rijen.
func test_wolkje_krimpt_op_een_telefoon() -> void:
	for geval in [
			{"kader": Vector2(990, 637), "wolk": "🛏 6 bedden maken"},
			{"kader": Vector2(326, 558), "wolk": "🛏 6"},
			{"kader": Vector2(558, 289), "wolk": ""}]:
		var kader: Vector2 = geval["kader"]
		_op(kader)
		_hotel(4, 3, 3, kader)
		waar(Games.start(SPEL), "bedden start bij %s" % str(kader))
		Hits.plaats()
		waar(_beantwoord(), "de vraag is beantwoord bij %s" % str(kader))
		gelijk(_tekst("bd_wolk"), str(geval["wolk"]),
			"het wolkje bij kader %s" % str(kader))
		if not str(geval["wolk"]).is_empty():
			gelijk(_titel("bd_wolk"), "6 bedden maken",
				"de woorden blijven in de titel bij %s" % str(kader))
		await _af()

## Enkelvoud en meervoud: nooit "van 1 bedden".
func test_enkelvoud_en_meervoud() -> void:
	var spel: GDScript = load(BRON)
	gelijk(spel.mv(1, "bed", "bedden"), "1 bed", "mv(1)")
	gelijk(spel.mv(3, "bed", "bedden"), "3 bedden", "mv(3)")
	gelijk(spel.mv(1, "bedje", "bedjes"), "1 bedje", "mv(1) voor de kist")
	gelijk(spel.mv(0, "rij", "rijen"), "0 rijen", "mv(0)")

## De bron draagt elke letterlijke tekst van §3.7 die niet in elke beurt
## voorkomt (de eindkaart, het eindwolkje, Wolkje, de schuifwand).
func test_bron_draagt_de_letterlijke_teksten() -> void:
	var f := FileAccess.open(BRON, FileAccess.READ)
	waar(f != null, "de bron is te lezen")
	if f == null:
		return
	var bron := f.get_as_text()
	f.close()
	for zin in ['"Bedden op rij"', '"Zet de bedden op rij"', '"Bedden"',
			'"Hoeveel bedden heb je nodig?"', '"nog een bedje erbij"',
			'"rij %d: %d van %d"', '"dekenkist met "', '"bedje", "bedjes"',
			'"eentje terug in de kist"', '"Leg %s van %s"',
			'"Zo veel bedden staan er nu"', '"bed maken"', '"bedden maken"',
			'"1 gast mag erin"', '"%d gasten mogen erin"', '"kamerhulp Wolkje"',
			'"zoveel in een rij"', '"in elke rij"', '"Nu staat er "',
			'"Nu staan er "', '"vol ✓"', '"%d × %d + %d × %d"']:
		waar(bron.contains(zin), "de bron draagt %s" % zin)

## Elk pictogram dat een kind ziet heeft een glyph in de meegeleverde subset.
func test_elk_pictogram_heeft_een_glyph() -> void:
	for zin in ["🛏", "🛌", "🧺", "🔄", "🐾", "🐑", "🚧", "⭐", "×", "−", "✓",
			"vol ✓", "Zo veel bedden staan er nu"]:
		var mist := Ui.mist_tekens(zin)
		gelijk(str(mist), "[]", "geen ontbrekende tekens in '%s'" % zin)

## F4: elke zin op de kaart blijft onder de acht woorden en veertig tekens.
func test_kaartzinnen_passen_in_het_budget() -> void:
	for zin in ["Leg 3 rijen van 10 bedden", "Zo veel bedden staan er nu",
			"Hoeveel bedden heb je nodig?",
			"Nu staan er 10 bedden", "Nu staat er 1 bed"]:
		waar(Ui.keur_regel("bd_som", zin), "'%s' past in het budget" % zin)

# ------------------------------------------------------ dekking in vier maten

## Dezelfde twee invarianten als `tests/test_hits.gd`: niets overlapt iets
## anders, en geen knop staat op een voorwerp in beeld.
func _keur(kader: Vector2, wat: String) -> void:
	var dbg := Hits.debug()
	var ids: Array = dbg.keys()
	for i in ids.size():
		var a: Dictionary = dbg[ids[i]]
		var ra: Rect2 = a["rect"]
		waar(ra.position.x >= 0.0 and ra.position.y >= 0.0
			and ra.end.x <= kader.x + 0.01 and ra.end.y <= kader.y + 0.01,
			"%s: %s binnen het kader" % [wat, ids[i]])
		waar(not a["krap"], "%s: %s vond een echte plek" % [wat, ids[i]])
		if int(a["laag"]) != Hits.Laag.VAST:
			for j in ids.size():
				var v: Rect2 = dbg[ids[j]]["vlak"]
				if v.size.x <= 0.0:
					continue
				if str(a.get("op", "")) == "aan" and v.is_equal_approx(a["vlak"]):
					continue          # a hotel button ON its own thing
				var snij := ra.intersection(v)
				gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
					"%s: %s dekt voorwerp van %s" % [wat, ids[i], ids[j]])
		for j in range(i + 1, ids.size()):
			var rb: Rect2 = dbg[ids[j]]["rect"]
			var s2 := ra.intersection(rb)
			gelijk(maxf(0.0, s2.size.x) * maxf(0.0, s2.size.y), 0.0,
				"%s: %s en %s overlappen" % [wat, ids[i], ids[j]])

func test_geen_knop_dekt_een_voorwerp_in_vier_maten() -> void:
	for kader in MATEN + KADERS:
		_op(kader)
		_hotel(4, 3, 3, kader)
		waar(Games.start(SPEL), "bedden start bij %s" % str(kader))
		Hits.plaats()
		_keur(kader, "%s in de vraagfase" % str(kader))
		waar(_beantwoord(), "de vraag is beantwoord bij %s" % str(kader))
		var eigen := 0
		for id in Hits.lijst():
			var s := Hits.spot(id)
			if s == null or s.door != SPEL:
				continue
			eigen += 1
			gelijk(Hits.dekking(id), 0.0,
				"%s: %s dekt 0 %% van zijn voorwerp" % [str(kader), id])
			var r: Rect2 = Hits.debug().get(id, {}).get("rect", Rect2())
			if s.kind != "tag" and s.kind != "naam":
				waar(r.size.x >= 48.0 and r.size.y >= 48.0,
					"%s: %s is een tikdoel van 48 px (%s)" % [str(kader), id, str(r)])
		waar(eigen >= 6, "%s: bedden plaatste %d eigen hotspots" % [str(kader), eigen])
		_keur(kader, str(kader))
		# en na een misser komen er wolkjes bij die ook een plek moeten vinden
		_tik("bd_rij0")
		_tik("bd_klaar")
		Hits.plaats()
		_keur(kader, "%s na een misser" % str(kader))
		await _af()

## "Nette rijen" is de hele opdracht: strookje 1 staat boven strookje 2, altijd,
## en ze staan even ver uit elkaar.  Gemeten in de browser op band 4 stond rij 0
## op y 621 en rij 1 op y 353 — vier banden lager dan de rest, omdat de
## sommenkaart (prio 14) de band van rij 0 innam en het raster rij 0 daarna naar
## beneden schoof.  De kaart wijkt nu voor de rijen (prio 13 tegen 14).
func test_de_rijen_staan_netjes_onder_elkaar() -> void:
	for geval in [
			{"n": 2, "kunnen": 3, "dag": 3},
			{"n": 4, "kunnen": 3, "dag": 3},
			{"n": 7, "kunnen": 4, "dag": 5}]:
		for kader in MATEN + KADERS:
			_op(kader)
			_hotel(int(geval["n"]), int(geval["kunnen"]), int(geval["dag"]), kader)
			waar(Games.start(SPEL), "bedden start bij %s" % str(kader))
			Hits.plaats()
			waar(_beantwoord(), "de vraag is beantwoord bij %s" % str(kader))
			var stroken := mini(4, int(_d()["rijen"]) + 1)
			var vorige := -1.0
			var stap := -1.0
			for r in stroken:
				var dbg: Dictionary = Hits.debug().get("bd_rij%d" % r, {})
				waar(not dbg.is_empty(), "%s: strookje %d staat er" % [str(kader), r])
				if dbg.is_empty():
					continue
				var y: float = (dbg["rect"] as Rect2).get_center().y
				if vorige >= 0.0:
					waar(y > vorige,
						"%s: rij %d staat onder rij %d (%.0f na %.0f)"
							% [str(kader), r, r - 1, y, vorige])
					var d := y - vorige
					if stap >= 0.0:
						waar(absf(d - stap) <= Hits.RIJ + 0.01,
							"%s: rij %d staat even ver (%.0f tegen %.0f)"
								% [str(kader), r, d, stap])
					stap = d
				vorige = y
			# en de kaart staat niet op een strookje
			var kr: Rect2 = Hits.debug().get("bd_som", {}).get("rect", Rect2())
			for r in stroken:
				var sr: Rect2 = Hits.debug().get("bd_rij%d" % r, {}).get("rect", Rect2())
				var snij := kr.intersection(sr)
				gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
					"%s: de kaart staat niet op rij %d" % [str(kader), r])
			await _af()

## Het kader bepaalt hoeveel strookjes er passen; nooit minder dan drie en
## nooit meer dan vier, dus `rijen` blijft tussen 1 en 3.
func test_max_stroken_volgt_het_kader() -> void:
	for kader in MATEN + KADERS:
		_op(kader)
		_hotel(4, 3, 3, kader)
		waar(Games.start(SPEL), "bedden start bij %s" % str(kader))
		Hits.plaats()
		waar(_beantwoord(), "de vraag is beantwoord bij %s" % str(kader))
		var d := _d()
		var stroken := mini(4, int(d["rijen"]) + 1)
		waar(int(d["rijen"]) >= 1 and int(d["rijen"]) <= 3,
			"%s: rijen blijft 1..3 (kreeg %d)" % [str(kader), int(d["rijen"])])
		for r in stroken:
			waar(Hits.spot("bd_rij%d" % r) != null,
				"%s: strookje %d staat er" % [str(kader), r])
		waar(Hits.spot("bd_rij%d" % stroken) == null,
			"%s: en er staat er niet één te veel" % str(kader))
		await _af()
