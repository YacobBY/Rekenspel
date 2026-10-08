extends Proef
## De rekenwacht (`autoload/reken.gd`).  Owner, 2026-10-09: "Zorg wel dat
## rekenen altijd een prioriteit wordt en dat kinderen niet lang kunnen spelen
## zonder te rekenen. Minigames mogen een klein extra spel element hebben maar
## het moet niet mogelijk zijn om rekenen over te slaan en rekenen moet
## minstens 50% van de interactie zijn."
##
## What is proven here: which taps count as maths and which as play; the budget
## and what a right answer pays back; that over a long played run maths is at
## least half (the bound the rule really gives); the play clock with a fake
## clock; that a refused tap does nothing; what stays allowed; the big button's
## four ways to maths; that nothing resets the counters (a reload, another
## hotel, a fresh `Reken`); that a running maths game never refuses; that free
## play in a game (the paskamer, a `vrij: true` button) waits for the maths;
## and every new string.

const NEP := preload("res://spel/minigame.tscn")
## The shells of the suite: tablet landscape and portrait, phone portrait and
## landscape.
const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740),
	Vector2i(740, 360)]

var _h: Dictionary = {}
var _bewaard: Dictionary = {}
var _gekozen := false
var _rust := false
var _nep_ids: Array[String] = []

func _boom() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

func _frames(n: int) -> void:
	for _f in n:
		await _boom().process_frame

## The real shell in a SubViewport and a fresh hotel in the receptie, motion
## reduced (walks resolve at once).
func _op(maat: Vector2i = SCHERMEN[0]) -> void:
	_bewaard = State.s.duplicate(true)
	_gekozen = State.gestart()
	_rust = Ui.rust_modus()
	Ui.zet_rust_modus(true)
	var vp := SubViewport.new()
	vp.size = maat
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_boom().root.add_child(vp)
	var shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	shell.set_meta("geen_start", true)
	vp.add_child(shell)
	await _frames(4)
	Rooms.herstel()
	State.nieuw_spel()
	Hotel.start()
	await _frames(4)
	_h = {"vp": vp, "shell": shell}

func _af() -> void:
	if not Games.actief().is_empty():
		Games.stop()
	Reken.voor_test()
	Econ.rekening_stop()
	Ui.blad_dicht()
	Ui.naamplaten_leeg()
	Hits.wis_alles()
	World.decor_wis_eigenaar(Reken.EIGENAAR)
	if _h.has("vp"):
		(_h["vp"] as SubViewport).queue_free()
		await _frames(2)
	Ui.registreer_lagen(null, null, null)
	Ui.registreer_wortels([])
	Ui.vergeet_scherm()
	Ui.zet_rust_modus(_rust)
	for id in _nep_ids:
		Games._defs.erase(id)
		Games._scenes.erase(id)
	_nep_ids.clear()
	if not _bewaard.is_empty():
		State.s = _bewaard
		State.set("_start_keuze", _gekozen)
	World.naar("receptie")
	_h = {}

## A stand-in maths game in room `kamer`, its entry on the fixed thing `obj`.
func _nep(id: String, kamer: String, obj: String, extra := {}) -> void:
	var def := {"id": id, "naam": "Proef " + id, "kamer": kamer,
		"hotspot": {"obj": obj, "icoon": "🧪", "label": "Proef", "hoog": 14}}
	def.merge(extra, true)
	Games.registreer(def, NEP)
	_nep_ids.append(id)

## A fixed thing of the room, to hang a stand-in's entry on.
func _ding(kamer: String) -> String:
	var r = Rooms.get_kamer(kamer)
	return str(r.decor[0]["n"]) if r != null and not (r.decor as Array).is_empty() else ""

## Tap a hotspot the way a finger does.
func _druk(id: String) -> bool:
	var s = Hits.spot(id)
	if s == null or not is_instance_valid(s.knoop) or not (s.knoop is BaseButton):
		return false
	(s.knoop as BaseButton).emit_signal("pressed")
	return true

## Press button `knop` of the strip glued under card `id`.
func _kies(id: String, knop: String) -> bool:
	var s = Hits.spot(id + "_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		return false
	var k := (s.knoop as Control).get_node_or_null("Rij/K" + knop) as BaseButton
	if k == null:
		return false
	k.emit_signal("pressed")
	return true

## Every free tap of one budget, as counted taps: the gate shuts.
func _op_maken() -> void:
	for _i in Reken.BUDGET_MAX:
		Reken.tik("spel", "proef")

func _geweigerd() -> int:
	return int(Reken.totaal()["geweigerd"])

# ------------------------------------------------------------ wat telt als wat

## A tap on an answer box of a maths card is maths — the right one and the
## wrong ones; a `keuzes` card counts as maths with `reken: true` or a sum line;
## a hotspot made with `reken: true` (and a drop on it) is maths; every hotel
## button and every other game button is play.  A right number answer pays the
## maths back by itself (`Ui`).
func test_strook_hotspot_en_hotelknop_worden_juist_geteld() -> void:
	await _op()
	var t0 := Reken.totaal()
	# a hotel button: the door sign of the receptie
	waar(_druk("deur_receptie_tuin"), "de deurknop is er")
	await _frames(2)
	gelijk(int(Reken.totaal()["spel"]), int(t0["spel"]) + 1, "een deurknop is spel")
	gelijk(Reken.budget(), Reken.BUDGET_MAX - 1, "en kost één van het budget")
	Hotel.naar_kamer("receptie")
	await _frames(2)
	# a button of a game: play, unless it says `reken: true`
	var getikt := [0, 0]
	Hits.maak({"id": "proef_spel", "door": "proef", "kamer": World.kamer_nu(),
		"x": 40.0, "z": 60.0, "y": 10.0, "icoon": "🧺", "label": "Mand",
		"aan": func(_s) -> void: getikt[0] += 1})
	Hits.maak({"id": "proef_reken", "door": "proef", "kamer": World.kamer_nu(),
		"x": 70.0, "z": 60.0, "y": 10.0, "icoon": "🧺", "label": "Krat", "reken": true,
		"kind": "drop", "drop": "was", "val": func(_l, _d) -> void: getikt[1] += 1,
		"aan": func(_s) -> void: getikt[0] += 1})
	await _frames(2)
	var t1 := Reken.totaal()
	waar(_druk("proef_spel"), "de spelknop is er")
	gelijk(int(Reken.totaal()["spel"]), int(t1["spel"]) + 1, "een gewone spelknop is spel")
	waar(_druk("proef_reken"), "de rekenknop is er")
	gelijk(int(Reken.totaal()["reken"]), int(t1["reken"]) + 1, "reken: true is rekenen")
	gelijk(getikt[0], 2, "beide knoppen deden hun werk")
	var vv = Hits.spot("proef_reken").vangvlak
	waar(vv != null, "het krat is een sleepdoel")
	if vv != null:
		vv._drop_data(Vector2.ZERO, {"sleep": "was"})
	gelijk(int(Reken.totaal()["reken"]), int(t1["reken"]) + 2, "een drop op reken: true is rekenen")
	gelijk(getikt[1], 1, "en komt bij het spel aan")
	# a number card: every box is maths; the right one pays back.  First the
	# budget down a little and the maths so far paid back, so what this card
	# pays shows
	for i in 6:
		Reken.tik("spel", "proef")
	Reken.goed("proef")
	var t2 := Reken.totaal()
	var b_voor := Reken.budget()
	waar(b_voor < Reken.BUDGET_MAX - 2, "er is ruimte om terug te betalen (%d)" % b_voor)
	Ui.somkaart({"x": 50.0, "z": 80.0}, "2 + 3 =", {"id": "proef_fout", "door": "proef",
		"goed": 5, "liever": [4, 6], "regel": "Hoeveel is het samen?"})
	Ui.somkaart({"x": 80.0, "z": 80.0}, "2 + 2 =", {"id": "proef_goed", "door": "proef",
		"goed": 4, "liever": [3, 5], "regel": "Hoeveel is het samen?"})
	await _frames(2)
	var fout_knop := ""
	for k in (Hits.spot("proef_fout_keuzes").knoop as Control).get_node("Rij").get_children():
		if str(k.name) != "Kn5":
			fout_knop = str(k.name).substr(1)
			break
	waar(_kies("proef_fout", fout_knop), "een fout antwoord is te tikken")
	gelijk(int(Reken.totaal()["reken"]), int(t2["reken"]) + 1, "een fout antwoord is ook rekenen")
	gelijk(int(Reken.totaal()["goed"]), int(t2["goed"]), "maar betaalt niets terug")
	waar(_kies("proef_goed", "n4"), "het goede antwoord is te tikken")
	gelijk(int(Reken.totaal()["reken"]), int(t2["reken"]) + 2, "het goede antwoord is rekenen")
	gelijk(int(Reken.totaal()["goed"]), int(t2["goed"]) + 1, "en Ui meldt het goed")
	gelijk(Reken.budget(), mini(Reken.BUDGET_MAX, b_voor + 2), "twee rekentikken betaalden er twee terug")
	# word cards: maths with a sum line or `reken: true`, play without
	var t3 := Reken.totaal()
	var woorden := [{"id": "a", "icoon": "⬇", "tekst": "te weinig", "kies": func(_k) -> void: pass},
		{"id": "b", "icoon": "⚖", "tekst": "precies", "kies": func(_k) -> void: pass}]
	Ui.somkaart({"x": 30.0, "z": 30.0}, "3 × 7", {"id": "proef_somregel", "door": "proef",
		"regel": "Is er genoeg voer?", "keuzes": woorden})
	Ui.somkaart({"x": 90.0, "z": 30.0}, "", {"id": "proef_vlag", "door": "proef",
		"regel": "Welke klok klopt?", "reken": true, "keuzes": woorden})
	Ui.somkaart({"x": 60.0, "z": 100.0}, "", {"id": "proef_woord", "door": "proef",
		"regel": "Welke kamer kies je?", "keuzes": woorden})
	await _frames(2)
	waar(_kies("proef_somregel", "a"), "de kaart met een somregel")
	waar(_kies("proef_vlag", "a"), "de kaart met reken: true")
	gelijk(int(Reken.totaal()["reken"]), int(t3["reken"]) + 2, "beide zijn rekenen")
	waar(_kies("proef_woord", "a"), "de kaart met alleen woorden")
	gelijk(int(Reken.totaal()["spel"]), int(t3["spel"]) + 1, "die is spel")
	await _af()

# ------------------------------------------------------------- het budget

## Twelve free taps, then the gate shuts; maths alone pays nothing until it is
## right; a right answer pays back exactly the maths since the last one, never
## above BUDGET_MAX, and a second call for the same tap pays nothing.
func test_het_budget_en_wat_een_goed_antwoord_terugbetaalt() -> void:
	var momenten: Array[bool] = []
	var luister := func(aan: bool) -> void: momenten.append(aan)
	Reken.rekenmoment.connect(luister)
	gelijk(Reken.budget(), Reken.BUDGET_MAX, "een vers budget is vol")
	waar(Reken.vrij(), "en vrij")
	for i in Reken.BUDGET_MAX - 1:
		Reken.tik("spel", "proef")
	gelijk(Reken.budget(), 1, "elf vrije tikken later is er één over")
	waar(Reken.vrij(), "nog vrij")
	Reken.tik("spel", "proef")
	gelijk(Reken.budget(), 0, "de twaalfde maakt het op")
	waar(not Reken.vrij(), "het rekenmoment begint")
	gelijk(momenten, [true] as Array[bool], "rekenmoment(true) één keer")
	waar(not Reken.mag("deur_receptie_tuin"), "een vrije tik mag niet meer")
	for i in 3:
		Reken.tik("reken", "proef")
	gelijk(Reken.budget(), 0, "rekenen zonder goed antwoord betaalt nog niets")
	waar(not Reken.vrij(), "het moment loopt door")
	Reken.goed("proef")
	gelijk(Reken.budget(), 3, "drie rekentikken (fouten tellen mee) betalen er drie terug")
	waar(Reken.vrij(), "het moment is voorbij")
	gelijk(momenten, [true, false] as Array[bool], "rekenmoment(false) één keer")
	Reken.goed("proef")
	gelijk(Reken.budget(), 3, "een tweede goed voor dezelfde tik betaalt niets")
	gelijk(int(Reken.totaal()["goed"]), 1, "en telt niet dubbel")
	for i in 30:
		Reken.tik("reken", "proef")
	Reken.goed("proef")
	gelijk(Reken.budget(), Reken.BUDGET_MAX, "nooit meer dan BUDGET_MAX")
	Reken.rekenmoment.disconnect(luister)

## A thousand interactions of a child that takes every free tap it can get,
## and one that plays at random (fixed seeds).  Whenever free play is allowed,
## spel <= reken + BUDGET_MAX — the rule of the contract — so the share of
## maths is at least (n − BUDGET_MAX) / 2n of n interactions and tends to one
## half.  It can not be one half from the first tap on: the first BUDGET_MAX
## taps are free by design.  In the steady state of the greedy child exactly
## every other interaction is a sum.
func test_over_een_lange_reeks_is_rekenen_minstens_de_helft() -> void:
	for beleid in ["gretig", "willekeurig"]:
		Reken.voor_test()
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261009 if beleid == "gretig" else 4711
		var n := 0
		var vrij_gezien := 0
		var mis := 0
		while n < 1000:
			var wil_spel: bool = beleid == "gretig" or rng.randf() < 0.7
			if wil_spel and Reken.mag("proef_vrij"):
				Reken.tik("spel", "proef_vrij")
			else:
				Reken.tik("reken", "proef")
				if beleid == "gretig" or rng.randf() < 0.75:
					Reken.goed("proef")
			n += 1
			if Reken.vrij():
				vrij_gezien += 1
				var t := Reken.totaal()
				var r := int(t["reken"])
				var s := int(t["spel"])
				if s > r + Reken.BUDGET_MAX:
					mis += 1
				var ondergrens := 0.5 - float(Reken.BUDGET_MAX) / (2.0 * float(n))
				if Reken.aandeel(Reken.GESCHIEDENIS) < ondergrens - 0.0001:
					mis += 1
		gelijk(mis, 0, "%s: spel <= reken + BUDGET_MAX bij elke vrije stap" % beleid)
		waar(vrij_gezien > 300, "%s: er was vaak vrij spel (%d)" % [beleid, vrij_gezien])
		var t_eind := Reken.totaal()
		gelijk(int(t_eind["reken"]) + int(t_eind["spel"]), 1000, "%s: duizend tikken geteld" % beleid)
		waar(Reken.aandeel(Reken.GESCHIEDENIS) >= 0.5 - float(Reken.BUDGET_MAX) / 2000.0,
			"%s: over de hele reeks is rekenen de helft op het startbudget na (%.3f)"
				% [beleid, Reken.aandeel(Reken.GESCHIEDENIS)])
		if beleid == "gretig":
			gelijk(Reken.aandeel(40), 0.5, "gretig: in de vaste gang is het precies om en om")
	Reken.voor_test()

# --------------------------------------------------------------- de klok

## Only ACTIVE play counts: a tap in the last ACTIEF_S seconds of the clock,
## the app on screen.  At TIJD_MAX a moment starts with budget left; the next
## right answer ends it and starts the clock again.
func test_de_speelklok_met_een_nepklok() -> void:
	var nu := [500000]
	Reken.klok = func() -> int: return int(nu[0])
	Reken.tik("spel", "proef")
	gelijk(Reken.verstrijk(100.0), 100.0, "honderd actieve seconden tellen")
	nu[0] += int(Reken.ACTIEF_S * 1000.0) + 1000
	gelijk(Reken.verstrijk(100.0), 100.0, "zonder tik in de laatste twintig seconden telt niets")
	Reken.wakker()
	gelijk(Reken.verstrijk(79.0), 179.0, "weer actief: het telt verder")
	waar(Reken.vrij(), "net onder TIJD_MAX is het nog vrij")
	Reken.verstrijk(2.0)
	waar(not Reken.vrij(), "bij TIJD_MAX begint het rekenmoment")
	gelijk(Reken.budget(), Reken.BUDGET_MAX - 1, "met budget over")
	# a hidden tab: the frames add nothing
	World.pauzeer(true)
	Reken.voor_test()
	Reken.klok = func() -> int: return int(nu[0])
	Reken.wakker()
	Reken._process(1.0)
	gelijk(Reken.tijd(), 0.0, "een verborgen tabblad telt niet")
	World.pauzeer(false)
	Reken._process(0.4)
	waar(Reken.tijd() > 0.39, "zichtbaar telt het weer (%.2f)" % Reken.tijd())
	Reken._process(30.0)
	waar(Reken.tijd() < 1.0, "één beeld telt nooit meer dan STAP_MAX (%.2f)" % Reken.tijd())
	# the answer
	Reken.verstrijk(Reken.TIJD_MAX)
	waar(not Reken.vrij(), "weer TIJD_MAX")
	Reken.tik("reken", "proef")
	Reken.goed("proef")
	waar(Reken.vrij(), "een goed antwoord maakt het vrij")
	gelijk(Reken.tijd(), 0.0, "en zet de klok op nul")
	Reken.voor_test()

# ------------------------------------------------------- het rekenmoment

## During a moment a free tap does nothing: the door sign does not open its
## door, no `hotspot_getikt`, nothing counted — the button shakes, a
## see-through bubble says "Eerst even rekenen!" at the big ➕ button, the
## room bar and the door signs dim.  A room chip, the floor plan and the
## chrome's 💰 are refused the same way.
func test_een_geweigerde_tik_doet_niets() -> void:
	await _op()
	_op_maken()
	await _frames(3)
	var knop = Hits.spot(Reken.KNOP)
	waar(knop != null and is_instance_valid(knop.knoop) and (knop.knoop as Control).visible,
		"de grote rekenknop staat er")
	var getikt: Array[String] = []
	var luister := func(id: String) -> void: getikt.append(id)
	Hits.hotspot_getikt.connect(luister)
	var kamer := World.kamer_nu()
	var deur = Hits.spot("deur_receptie_tuin")
	waar(deur != null, "de deur naar de tuin heeft een bordje")
	gelijk(snappedf((deur.knoop as Control).modulate.a, 0.01), Reken.DIM, "het deurbordje is gedimd")
	waar(_druk("deur_receptie_tuin"), "tik op de deur")
	await _frames(2)
	gelijk(World.kamer_nu(), kamer, "de kamer blijft dezelfde")
	gelijk(getikt.size(), 0, "geen hotspot_getikt")
	gelijk(Reken.budget(), 0, "niets geteld")
	gelijk(_geweigerd(), 1, "één weigering")
	gelijk(int(deur.knoop.get_meta("reken_geschud", 0)), 1, "de knop schudt nee")
	var wolk = Hits.spot(Reken.WOLK)
	waar(wolk != null, "de wolk zegt waarom")
	if wolk != null:
		var tekst := Proef._wat_er_staat(wolk.knoop as Control)
		waar(tekst.contains(UiTekst.REKEN_EERST), "met 'Eerst even rekenen!' (%s)" % tekst)
		waar(not (wolk.knoop as UiWolk).actie, "een wolk die alleen praat: doorkijk, geen knop")
		waar(Hits.debug().has(Reken.WOLK), "en hij staat in het kader")
	# the room bar dims and refuses
	var balk: UiKamerbalk = _h["shell"].kamerbalk
	waar(balk.gedimd(), "de kamerbalk is gedimd")
	gelijk(snappedf(balk.modulate.a, 0.01), Reken.DIM, "zichtbaar gedimd")
	(balk.chips()["tuin"] as Button).pressed.emit()
	await _frames(2)
	gelijk(World.kamer_nu(), kamer, "een kamerchip brengt je nergens heen")
	gelijk(_geweigerd(), 2, "ook geweigerd")
	# the chrome
	var chroom: UiHud = _h["shell"].chroom
	chroom.munt_badge.pressed.emit()
	await _frames(2)
	waar(not Ui.blad_open_nu(), "de kassa gaat niet open")
	gelijk(_geweigerd(), 3, "ook geweigerd")
	# the floor plan: it was open when the gate shut; a room there is refused
	# and the map closes on the big button
	Ui.blad_dicht()
	_h["shell"]._plattegrond()
	await _frames(2)
	var kaart: UiPlattegrond = null
	for k in Ui.huidig_blad().inhoud().get_children():
		if k is UiPlattegrond:
			kaart = k
	waar(kaart != null, "de plattegrond staat open")
	if kaart != null:
		kaart.kamer_gekozen.emit("tuin")
		await _frames(2)
		gelijk(World.kamer_nu(), kamer, "een kamer op de kaart brengt je nergens heen")
		waar(not Ui.blad_open_nu(), "de kaart gaat dicht, op de rekenknop")
	gelijk(_geweigerd(), 4, "ook geweigerd")
	gelijk(Reken.budget(), 0, "en van dat alles is niets geteld")
	Hits.hotspot_getikt.disconnect(luister)
	await _af()

## What stays allowed during a moment, and is not counted then: the big
## button, sound on/off, closing a sheet, a maths card on the board, the entry
## of a maths game, the bell.  Not allowed: the board's play card.
func test_wat_altijd_mag() -> void:
	alleen_spellen([])
	await _op()
	_nep("proef_som", "receptie", _ding("receptie"))
	Games.hersteek()
	await _frames(2)
	_op_maken()
	await _frames(3)
	var t0 := Reken.totaal()
	# sound
	var aan := bool(State.s.get("geluid", true))
	(_h["shell"].chroom as UiHud).geluid_knop.pressed.emit()
	gelijk(bool(State.s.get("geluid", true)), not aan, "het geluid gaat om")
	(_h["shell"].chroom as UiHud).geluid_knop.pressed.emit()
	# a sheet closes
	Hotel.bord_open()
	await _frames(2)
	waar(Ui.blad_open_nu(), "het prikbord staat open")
	var sluit := Ui.huidig_blad().find_child("Ksluit", true, false) as BaseButton
	waar(sluit != null, "met Sluiten")
	if sluit != null:
		sluit.emit_signal("pressed")
	await _frames(2)
	waar(not Ui.blad_open_nu(), "Sluiten sluit")
	# the board: a play card is refused, a maths card goes
	Hotel.bord_open()
	await _frames(2)
	var bord: UiPrikbordBlad = null
	for k in Ui.huidig_blad().inhoud().get_children():
		if k is UiPrikbordBlad:
			bord = k
	waar(bord != null, "het prikbord")
	if bord != null:
		bord.taak_gekozen.emit({"id": "spelen", "actie": "kamer", "kamer": "kamer1"})
		await _frames(2)
		gelijk(World.kamer_nu(), "receptie", "de speelkaart brengt je nergens heen")
		waar(not Ui.blad_open_nu(), "het bord gaat dicht, op de rekenknop")
		gelijk(_geweigerd(), 1, "geweigerd")
	Hotel.bord_open()
	await _frames(2)
	bord = null
	for k in Ui.huidig_blad().inhoud().get_children():
		if k is UiPrikbordBlad:
			bord = k
	if bord != null:
		bord.taak_gekozen.emit({"id": "proef_som", "spel": "proef_som", "actie": "game:proef_som",
			"kamer": "receptie"})
		await _frames(2)
		gelijk(Games.actief(), "proef_som", "de rekenkaart start zijn spel")
	Games.stop()
	await _frames(3)
	# the entry of a maths game
	waar(Hits.spot("spel_proef_som") != null, "het spel heeft een ingang")
	waar(_druk("spel_proef_som"), "tik op de ingang")
	gelijk(Games.actief(), "proef_som", "de ingang van een rekenspel mag")
	Games.stop()
	await _frames(3)
	# the bell: a guest comes to check in
	waar(Hits.spot("bel") != null, "de bel staat er")
	waar(_druk("bel"), "tik op de bel")
	waar(State.s.get("checkin") != null, "de bel mag: een gast checkt in")
	gelijk(Reken.budget(), 0, "niets van dat alles kostte budget")
	gelijk(int(Reken.totaal()["spel"]), int(t0["spel"]), "en niets werd als spel geteld")
	await _af()

## The big button: ONE, pulsing, pictogram AND word, at the foot of the frame
## on every screen, a whole tap target inside the frame — and gone again on a
## right answer.  It comes back after the shell wiped every button (another
## hotel), and it steps aside while a sum is on screen.
func test_de_rekenknop_op_vier_schermen() -> void:
	for maat in SCHERMEN:
		await _op(maat)
		_op_maken()
		await _frames(3)
		var s = Hits.spot(Reken.KNOP)
		waar(s != null and is_instance_valid(s.knoop), "%s: de knop is er" % str(maat))
		if s == null:
			await _af()
			continue
		var knop := s.knoop as UiHotKnop
		waar(knop != null and knop.visible, "%s: zichtbaar" % str(maat))
		waar(knop.text.contains(UiTekst.REKEN_ICOON) and knop.text.contains(UiTekst.REKEN_KNOP),
			"%s: pictogram én woord (%s)" % [str(maat), knop.text])
		waar(knop.pulseert(), "%s: hij pulseert" % str(maat))
		var d: Dictionary = Hits.debug().get(Reken.KNOP, {})
		var r: Rect2 = d.get("rect", Rect2())
		var kader := World.kader_rect()
		waar(r.size.x >= 48.0 and r.size.y >= 48.0, "%s: een heel tikdoel (%s)" % [str(maat), str(r.size)])
		waar(Rect2(Vector2.ZERO, kader.size).encloses(r), "%s: binnen het kader (%s in %s)"
			% [str(maat), str(r), str(kader.size)])
		waar(r.end.y > kader.size.y * 0.6, "%s: onderin, bij de vinger (%s)" % [str(maat), str(r)])
		waar(not bool(d.get("krap", true)), "%s: niet krap" % str(maat))
		var anderen := 0
		for id in Hits.debug().keys():
			if str(id) != Reken.KNOP and (Hits.debug()[id]["rect"] as Rect2).intersects(r):
				anderen += 1
		gelijk(anderen, 0, "%s: er ligt niets op de knop" % str(maat))
		# gone with a wipe, back the next frames (a hotel switch does this)
		Hits.wis_alles()
		await _frames(3)
		waar(Hits.spot(Reken.KNOP) != null, "%s: na wis_alles komt hij terug" % str(maat))
		await _af()

# ---------------------------------------------------- de rekenknop werkt altijd

## The four ways the big button finds maths, in their order: the top maths
## card of the board, a guest at the desk, a maths game in this room, and the
## quick sum — biscuits on the floor, counted.  The quick sum always works,
## and answering it right ends the moment.
func test_de_rekenknop_vindt_altijd_rekenwerk() -> void:
	alleen_spellen([])
	await _op()
	_nep("proef_bord", "keuken", _ding("keuken"))
	_nep("proef_hier", "receptie", _ding("receptie"))
	_op_maken()
	await _frames(3)
	# 1. the board
	State.s["taken"] = [{"id": "spelen", "spel": "", "actie": "kamer", "kamer": "kamer1",
			"klaar": false},
		{"id": "proef_bord", "spel": "proef_bord", "actie": "game:proef_bord",
			"kamer": "keuken", "klaar": false}]
	waar(_druk(Reken.KNOP), "tik op de rekenknop")
	await _frames(2)
	gelijk(Games.actief(), "proef_bord", "1: de bovenste rekenkaart van het bord (niet de speelkaart)")
	gelijk(World.kamer_nu(), "keuken", "1: in zijn eigen kamer")
	Games.stop()
	Hotel.naar_kamer("tuin")
	await _frames(3)
	# 2. a guest at the desk (the check-in waits in the receptie)
	Hotel.bel()
	Hotel.naar_kamer("tuin")
	await _frames(3)
	waar(State.s.get("checkin") != null, "2: er staat een gast aan de balie")
	waar(Hits.spot(Reken.KNOP) != null, "2: buiten de receptie staat de knop er")
	State.s["taken"] = []
	gelijk(Reken.doe_rekenen(), "checkin", "2: de check-in")
	await _frames(2)
	gelijk(World.kamer_nu(), "receptie", "2: naar de balie")
	waar(Hits.spot("ci_som") != null, "2: met de vraag")
	waar(Hits.spot(Reken.KNOP) == null, "2: en de knop stapt opzij voor de som")
	State.s["checkin"] = null
	State.s["nieuweGast"] = null
	Hotel.paint_checkin()
	World.sync(Hotel.alle_dieren())
	Hotel.render()
	await _frames(3)
	# 3. a maths game in this room
	State.s["taken"] = []
	gelijk(Reken.doe_rekenen(), "spel", "3: het rekenspel van deze kamer")
	gelijk(Games.actief(), "proef_hier", "3: draait")
	Games.stop()
	await _frames(3)
	# 4. the quick sum: nothing else in this room (the board is rebuilt on
	# every render, so it is emptied right before the tap)
	Games._defs.erase("proef_hier")
	Games._scenes.erase("proef_hier")
	Hotel.naar_kamer("tuin")
	await _frames(3)
	waar(not Reken.vrij(), "4: het moment loopt nog")
	State.s["taken"] = []
	waar(_druk(Reken.KNOP), "4: tik op de rekenknop")
	await _frames(3)
	var snel := Reken.snelle_som()
	waar(not snel.is_empty(), "4: de snelle som staat er")
	var n := int(snel.get("n", 0))
	var koekjes := 0
	for stuk in World.decor_lijst("tuin"):
		if str(stuk.get("door", "")) == Reken.EIGENAAR:
			koekjes += 1
	gelijk(koekjes, n, "4: zoveel koekjes liggen er als het antwoord zegt")
	waar(n >= 3 and n <= 7, "4: groep 3 telt drie tot zeven (%d)" % n)
	waar(Ui.som_in_beeld(), "4: het is een som in beeld")
	waar(Hits.spot(Reken.KNOP) == null, "4: de knop stapt opzij")
	var kaart = Hits.spot(Reken.KAART)
	waar(kaart != null and Hits.debug().has(Reken.KAART), "4: de kaart staat in het kader")
	# the card keeps clear of the biscuits
	if kaart != null:
		var kr: Rect2 = Hits.debug()[Reken.KAART]["rect"]
		for stuk in World.decor_lijst("tuin"):
			if str(stuk.get("door", "")) == Reken.EIGENAAR:
				var v := World.vlak_van(Reken.KOEK, float(stuk["x"]), float(stuk["z"]), 0.0)
				waar(not kr.intersects(v), "4: de kaart ligt niet op koekje %s" % str(stuk["id"]))
	waar(_kies(Reken.KAART, "n%d" % n), "4: het goede getal staat op de strook")
	await _frames(2)
	waar(Reken.vrij(), "4: goed geteld maakt het vrij")
	gelijk(Reken.budget(), 1, "4: één rekentik, één vrije tik terug")
	await _boom().create_timer(Reken.KLAAR_S + 0.3).timeout
	await _frames(2)
	koekjes = 0
	for stuk in World.decor_lijst("tuin"):
		if str(stuk.get("door", "")) == Reken.EIGENAAR:
			koekjes += 1
	gelijk(koekjes, 0, "4: daarna zijn de koekjes weg")
	waar(Hits.spot(Reken.KAART) == null, "4: en de kaart ook")
	await _af()

## The quick sum works in every room of the hotel: there are always at least
## two free places, the right answer is the number of biscuits, and the band
## sets how many.
func test_de_snelle_som_past_in_elke_kamer() -> void:
	alleen_spellen([])
	await _op()
	for band in [3, 4, 5]:
		State.s["band"] = band
		for kamer in Rooms.lijst():
			Hotel.naar_kamer(kamer)
			Reken._snelle_som()
			var snel := Reken.snelle_som()
			var n := int(snel.get("n", 0))
			waar(n >= 2, "%s, groep %d: de snelle som staat er (%d)" % [kamer, band, n])
			waar(not (snel.get("ids", []) as Array).is_empty(), "%s, groep %d: met koekjes" % [kamer, band])
			var k = Ui.kaart_van(Reken.KAART)
			waar(k != null and k.getal_vraag, "%s, groep %d: een getalkaart" % [kamer, band])
			Reken._snel_weg()
	State.s["band"] = 3
	await _af()

# ---------------------------------------------------------------- opslag

## Rule 6: the counters live outside the hotels.  Reading the hotel back,
## switching to another hotel or starting a new one, and a fresh `Reken` that
## reads the file (a reload) — none of them gives the budget back or ends a
## moment.  A broken file reads as a fresh one, never as more.
func test_niets_zet_de_teller_terug() -> void:
	var bestanden := {}
	var paden: Array[String] = [State.PAD_KEUZE]
	for h in range(1, State.HOTELS + 1):
		paden.append(State.pad_van(h))
	for pad in paden:
		if FileAccess.file_exists(pad):
			bestanden[pad] = FileAccess.get_file_as_string(pad)
	var bewaard := State.s.duplicate(true)
	var gekozen := State.gestart()
	var hotel := State.hotel
	_op_maken()
	Reken.tik("reken", "proef")
	waar(not Reken.vrij(), "het moment loopt")
	waar(FileAccess.file_exists(Reken.PAD), "in een eigen bestand")
	# hotel 1, read back
	State.kies_hotel(1)
	State.nieuw_spel()
	State.start_gekozen()
	waar(State.lees(), "het hotel is terug te lezen")
	gelijk(Reken.budget(), 0, "State.lees laat het budget")
	waar(not Reken.vrij(), "en het moment")
	# another hotel, and a new one there
	State.kies_hotel(2)
	State.nieuw_spel()
	State.start_gekozen()
	gelijk(Reken.budget(), 0, "een ander (nieuw) hotel laat het budget")
	waar(not Reken.vrij(), "en het moment")
	# a reload: a fresh Reken reads the file
	var vers = (load("res://autoload/reken.gd") as GDScript).new()
	vers.lees_opnieuw()
	gelijk(vers.budget(), 0, "een herladen Reken leest het budget")
	waar(not vers.vrij(), "en het moment")
	gelijk(int(vers.totaal()["spel"]), Reken.BUDGET_MAX, "en de tellingen")
	gelijk(vers.aandeel(), Reken.aandeel(), "en de geschiedenis")
	vers.free()
	# a broken file
	var f := FileAccess.open(Reken.PAD, FileAccess.WRITE)
	f.store_string("{kapot")
	f.close()
	var kapot = (load("res://autoload/reken.gd") as GDScript).new()
	kapot.lees_opnieuw()
	gelijk(kapot.budget(), Reken.BUDGET_MAX, "een kapot bestand leest als een vers")
	kapot.free()
	# a file that promises too much is clamped
	f = FileAccess.open(Reken.PAD, FileAccess.WRITE)
	f.store_string(JSON.stringify({"v": Reken.VERSIE, "budget": 500, "tijd": -40, "moment": "ja"}))
	f.close()
	var veel = (load("res://autoload/reken.gd") as GDScript).new()
	veel.lees_opnieuw()
	gelijk(veel.budget(), Reken.BUDGET_MAX, "nooit meer dan BUDGET_MAX uit een bestand")
	gelijk(veel.tijd(), 0.0, "geen negatieve klok")
	veel.free()
	# back as it was
	var dir := DirAccess.open("user://")
	for pad in paden:
		dir.remove(pad.get_file())
	for pad in bestanden.keys():
		var w := FileAccess.open(str(pad), FileAccess.WRITE)
		w.store_string(str(bestanden[pad]))
		w.close()
	State.hotel = hotel
	State.s = bewaard
	State.set("_start_keuze", gekozen)
	Reken.voor_test()

# ------------------------------------------------------------ in een spel

## Inside a running maths game every tap counts and none is refused: the budget
## goes negative and the moment waits until the game is over — then free play
## waits for the maths that pays it back.  A game's own free action
## (`vrij: true`) is refused once the budget is out, game or no game.  The
## turn's own counters (`beurt`) begin at the game's start.
func test_in_een_rekenspel_wordt_niets_geweigerd() -> void:
	alleen_spellen([])
	await _op()
	_nep("proef_spel", "receptie", _ding("receptie"))
	Reken.tik("spel", "proef")
	waar(Games.start("proef_spel"), "het rekenspel start")
	gelijk(Reken.beurt(), {"reken": 0, "spel": 0, "goed": 0}, "de beurt begint bij nul")
	var gedaan := [0]
	Hits.maak({"id": "proef_knop", "door": "proef_spel", "kamer": World.kamer_nu(),
		"x": 50.0, "z": 70.0, "y": 10.0, "icoon": "🧺", "label": "Mand",
		"aan": func(_s) -> void: gedaan[0] += 1})
	Hits.maak({"id": "proef_sticker", "door": "proef_spel", "kamer": World.kamer_nu(),
		"x": 80.0, "z": 70.0, "y": 10.0, "icoon": "⭐", "label": "Sticker", "vrij": true,
		"aan": func(_s) -> void: gedaan[0] += 100})
	await _frames(2)
	waar(_druk("proef_sticker"), "een vrije actie mag zolang er budget is")
	gelijk(gedaan[0], 100, "en doet haar werk")
	for i in 15:
		_druk("proef_knop")
	gelijk(gedaan[0], 115, "vijftien tikken in het spel deden alle vijftien hun werk")
	gelijk(Reken.budget(), Reken.BUDGET_MAX - 17, "het budget mag onder nul")
	waar(Reken.vrij(), "in het spel begint geen rekenmoment")
	gelijk(_geweigerd(), 0, "niets geweigerd")
	gelijk(Reken.beurt()["spel"], 16, "de beurt telt de tikken van het spel")
	waar(_druk("proef_sticker"), "de vrije actie, nu zonder budget")
	gelijk(gedaan[0], 115, "doet niets")
	gelijk(_geweigerd(), 1, "geweigerd")
	# the answer strip of the game always counts, never waits
	Ui.somkaart({"x": 60.0, "z": 90.0}, "1 + 1 =", {"id": "proef_som", "door": "proef_spel",
		"goed": 2, "liever": [1, 3], "regel": "Hoeveel is het samen?"})
	await _frames(2)
	waar(_kies("proef_som", "n2"), "het antwoord")
	gelijk(Reken.beurt()["reken"], 1, "rekenen in de beurt")
	gelijk(Reken.beurt()["goed"], 1, "goed in de beurt")
	gelijk(snappedf(Reken.aandeel_beurt(), 0.001), snappedf(1.0 / 17.0, 0.001), "het aandeel van de beurt")
	Games.stop()
	await _frames(3)
	waar(not Reken.vrij(), "na het spel begint het moment: het budget staat onder nul")
	Reken.tik("reken", "proef")
	Reken.goed("proef")
	waar(not Reken.vrij(), "één som betaalt het gat niet")
	gelijk(Reken.beurt()["spel"], 16, "de beurt van het gestopte spel blijft staan")
	await _af()

## The paskamer is free play (`vrij: true` in its `definitie()`): with the
## gate shut its entry is refused, and a paskamer that runs out of budget
## closes on the big button.
func test_de_paskamer_wacht_op_het_rekenen() -> void:
	gelijk(bool(Games.definitie("paskamer").get("vrij", false)), true, "de paskamer is vrij spel")
	await _op()
	var gast: Dictionary = State.gasten_pool()[0]
	var bed: Dictionary = State.alle_bedden()[0]
	gast["kamer"] = str(bed["kamer"])
	gast["bed"] = str(bed["slot"])
	gast["waar"] = gast["kamer"]
	gast["accessoires"] = ["hoedje"]
	State.s["gasten"] = [gast]
	Hotel.herstel_wereld()
	Hotel.naar_kamer("winkels")
	await _frames(3)
	waar(Hits.spot("spel_paskamer") != null, "de paskamer heeft een ingang")
	_op_maken()
	await _frames(2)
	waar(not Reken.mag("spel_paskamer"), "met het hek dicht mag de paskamer niet")
	waar(_druk("spel_paskamer"), "tik op de ingang")
	gelijk(Games.actief(), "", "de paskamer gaat niet open")
	gelijk(_geweigerd(), 1, "geweigerd")
	# with budget it opens, and the last free tap closes it
	Reken.voor_test()
	for i in Reken.BUDGET_MAX - 2:
		Reken.tik("spel", "proef")
	await _frames(2)
	waar(_druk("spel_paskamer"), "tik op de ingang, met budget")
	gelijk(Games.actief(), "paskamer", "de paskamer gaat open")
	gelijk(Reken.budget(), 1, "dat kostte een vrije tik")
	Reken.tik("spel", "paskamer")
	await _frames(3)
	gelijk(Games.actief(), "", "op is op: de paskamer gaat dicht")
	waar(not Reken.vrij(), "en het rekenmoment staat")
	await _frames(2)
	waar(Hits.spot(Reken.KNOP) != null, "met de grote knop")
	await _af()

# -------------------------------------------------------- vrij spelen en ctx

## "🐾 Vrij spelen" is the name of the round after the check-in (`ronde ==
## "vrij"`), a Label in the chrome — no button, no way around the gate: in that
## round a free tap is counted and refused exactly as in the morning.
func test_vrij_spelen_is_geen_uitweg() -> void:
	await _op()
	State.s["ronde"] = "vrij"
	Hotel.hud()
	await _frames(2)
	var chroom: UiHud = _h["shell"].chroom
	gelijk(chroom.ronde_label.text, UiTekst.RONDE_VRIJ, "de ronde heet Vrij spelen")
	var ronde: Control = chroom.ronde_label
	waar(not (ronde is BaseButton), "en is geen knop")
	_op_maken()
	await _frames(2)
	waar(_druk("deur_receptie_tuin"), "tik op de deur")
	await _frames(2)
	gelijk(World.kamer_nu(), "receptie", "ook in de vrije ronde geweigerd")
	await _af()

## `ctx.reken_goed()` without a running game only pays the maths back.
func test_ctx_reken_goed_zonder_spel() -> void:
	var ctx := SpelCtx.new("proefspel", {"naam": "Proef", "kamer": "receptie"})
	for i in 5:
		Reken.tik("spel", "proef")
	Reken.tik("reken", "proef")
	Reken.tik("reken", "proef")
	ctx.reken_goed()
	gelijk(Reken.budget(), Reken.BUDGET_MAX - 3, "twee rekentikken terug")
	gelijk(Reken.beurt(), {"reken": 0, "spel": 0, "goed": 0}, "zonder spel geen beurt")
	ctx.reken_goed()
	gelijk(Reken.budget(), Reken.BUDGET_MAX - 3, "een tweede keer betaalt niets")

# ---------------------------------------------------------- teksten en probe

## Every new sentence: pictogram first, at most 8 words and 40 characters, a
## glyph for every character; the button has a pictogram AND a word.
func test_de_nieuwe_teksten_volgen_de_regels() -> void:
	if Ui.thema == null or Ui.thema.default_font == null:
		Ui._bouw_thema(17)
	var zinnen := ["%s %s" % [UiTekst.REKEN_ICOON, UiTekst.REKEN_EERST],
		"%s %s" % [UiTekst.REKEN_TEL_ICOON, UiTekst.REKEN_TEL],
		"%s %s" % [UiTekst.REKEN_ICOON, UiTekst.REKEN_SAMEN],
		UiTekst.REKEN_GOED, UiTekst.REKEN_TITEL,
		"%s %s" % [UiTekst.REKEN_ICOON, UiTekst.REKEN_KNOP]]
	for zin in zinnen:
		waar(Ui.keur_regel("reken", zin), "%s: hooguit 8 woorden en 40 tekens" % zin)
		gelijk(str(Ui.mist_tekens(zin)), "[]", "%s: elk teken heeft een glyph" % zin)
	for zin in [UiTekst.REKEN_EERST, UiTekst.REKEN_TEL, UiTekst.REKEN_SAMEN]:
		waar(Ui.keur_regel("reken", zin), "%s: de regel zelf past" % zin)
	waar(UiTekst.REKEN_KNOP.length() >= 3 and not UiTekst.REKEN_ICOON.is_empty(),
		"de knop: pictogram én woord")
	gelijk(str(Ui.mist_tekens("🧮")), "[\"🧮\"]", "het telraam staat niet in de subset (daarom ➕)")

## The probe line of the play tools, in the shape of the other `[probe]` lines.
func test_de_probe_regel() -> void:
	var re := RegEx.new()
	re.compile("^\\[probe\\] reken vrij=[01] budget=-?\\d+ tijd=\\d+ aandeel=\\d\\.\\d\\d beurt=\\d+/\\d+ moment=[01]$")
	waar(re.search(Reken.probe_regel()) != null, "vers: %s" % Reken.probe_regel())
	_op_maken()
	waar(re.search(Reken.probe_regel()) != null, "dicht: %s" % Reken.probe_regel())
	waar(Reken.probe_regel().contains("vrij=0") and Reken.probe_regel().contains("moment=1")
		and Reken.probe_regel().contains("budget=0") and Reken.probe_regel().contains("aandeel=0.00"),
		"de waarden kloppen: %s" % Reken.probe_regel())
