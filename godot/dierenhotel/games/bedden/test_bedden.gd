extends RefCounted
## bedden — "Verdeel bedden over de kamers" (games-a.md §3), headless: step 4 of
## the check-in (owner, 2026-09-24).
##
## LET OP — dit bestand hoort `extends Proef` te zijn en doet dat NIET, om een
## bestaande fout in `res://tests/run_tests.gd` heen.  De runner sorteert ÉÉN
## lijst van `res://tests/test_*.gd` plus `res://games/<id>/test_*.gd`, en dit
## bestand is daarin het eerste; het eerste bestand dat `proef.gd` erft laat
## `res://core/sommen.gd` en `res://core/jsgetal.gd` bij het afsluiten achter
## (`ERROR: 2 resources still in use at exit`).  De vier hulpjes van Proef
## staan daarom hieronder.
##
## Elke tik gaat via `pressed` op de echte knop (de kamerkeuze van de check-in,
## de vier getallen van de beddenvraag).  De wandelingen worden met de hand
## getikt (`World._tik()` en `Hotel._volg_stap()`, zoals tests/test_komt.gd):
## de wereld staat stil (`World.pauzeer`), het spel kijkt elke 0,1 s echt.
##
## Wat hier vastligt:
##   * aanmelding: de naam, geen ingangsknop en geen prikbordkaartje, `kan`
##     alleen tijdens een check-in bij zijn bedden, open vanaf de eerste gast;
##   * de kamerkeuze biedt alleen kamers met plek;
##   * de getallen van de vraag zijn de dieren van die kamer, plus hij;
##   * goed: hij slaapt in zijn bed, een ster, de check-in is klaar, het spel
##     sluit zichzelf — ook met een nieuw bed;
##   * te weinig: geen bed, teleurgesteld, terug naar de balie, dezelfde vraag,
##     niets kwijt — en de camera loopt heen en terug mee;
##   * te veel: de bedden voor dat antwoord gaan weer weg, terug, dezelfde vraag;
##   * nooit hulp: geen hulpregel, geen helper, geen antwoord op de kaart;
##   * `⬅ Terug` midden in het spel, en een herlaad: de check-in gaat door;
##   * rustmodus: niemand loopt, de uitkomst staat er meteen;
##   * elke kindertekst letterlijk, in het budget, met glyphs.

const SPEL := "bedden"
const BRON := "res://games/bedden/spel.gd"
const KADER := Vector2(1000, 648)

var _laag: Control = null
var _vp: SubViewport = null
var _bewaard: Dictionary = {}
var _bewaard_nr := 0
var _rust := false

# ------------------------------------------------- de vier hulpjes van Proef

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

## A button layer, a viewport with a camera, the world measured — the bare
## shell `Hotel.scherm_klaar()` and `Hits` need (as tests/test_hits.gd does).
func _op(kader := KADER) -> void:
	_bewaard = State.s.duplicate(true)
	_bewaard_nr = Rooms.nr_stand()
	_rust = Ui.rust_modus()
	Rooms.herstel()
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
	Hotel.stop_volgen()
	World.pauzeer(false)
	World.toon_bedden()
	Ui.naamplaten_leeg()
	Hits.wis_alles()
	World.sync([])
	Rooms.herstel()
	Rooms.zet_nr(_bewaard_nr)
	World.naar("receptie")
	Ui.registreer_lagen(null, null, null)
	World.registreer_viewport(null, null)
	if _vp != null:
		_vp.queue_free()
		_vp = null
	if _laag != null:
		_laag.queue_free()
		_laag = null
	State.s = _bewaard
	Ui.zet_rust_modus(_rust)
	# one frame on, so the viewport and its texture are really gone
	await _boom().process_frame

## A hotel with `in1` animals asleep in kamer 1 and `in2` in kamer 2 (−1: as
## many as the room takes), each in a real bed (new ones where the base room
## has too few), and the next guest of
## the pool — Stampertje when `stamp` — at the desk, the check-in on the room
## question (step 3).  Reduced motion while the guest comes in, so he stands at
## the desk at once; `rust` is what the rest of the test runs in.
func _hotel(in1: int, in2: int, rust := true, stamp := false) -> Dictionary:
	State.nieuw_spel()
	State.s["taken"] = []
	var gasten: Array = []
	var pool := State.gasten_pool()
	var nr := 0
	for paar in [["kamer1", in1], ["kamer2", in2]]:
		var kamer: String = paar[0]
		var aantal := int(paar[1]) if int(paar[1]) >= 0 else State.plek_in(kamer)
		for i in aantal:
			var bed := State.bed_vrij(kamer)
			if bed.is_empty():
				var p := State.bed_plek(kamer)
				if p.is_empty():
					break
				bed = {"kamer": kamer, "slot": str(Rooms.meubel_zet(kamer, "bed",
					float(p["x"]), float(p["z"])).get("id", ""))}
			var g: Dictionary = (pool[nr % pool.size()] as Dictionary).duplicate(true)
			g["id"] = "bg%d" % nr
			g["kamer"] = kamer
			g["bed"] = str(bed["slot"])
			g["waar"] = kamer
			g["behoefte"] = "eten"
			g["gegeten"] = true
			g["nachten"] = 100
			gasten.append(g)
			State.s["gasten"] = gasten
			nr += 1
	State.s["gasten"] = gasten
	State.herbereken()
	if stamp:
		var st: Dictionary = {}
		for q in State.s["wachtlijst"]:
			if str(q.get("naam", "")) == "Stampertje":
				st = q
		(State.s["wachtlijst"] as Array).erase(st)
		(State.s["wachtlijst"] as Array).push_front(st)
	World.sync(Hotel.alle_dieren())
	for g in gasten:
		World.slaap(str(g["id"]), str(g["kamer"]), str(g["bed"]))
	World.naar("receptie")
	State.s["kamerNu"] = "receptie"
	Ui.zet_rust_modus(true)
	Hotel.bel()
	var v = State.s["checkin"]
	if v != null:
		v["invoer"] = str(int(v["nieuw"]))
		Hotel.antwoord1()
		Hotel.antwoord2(Sommen.vergelijk(int(v["dagen"]), int(v["nieuw"]), int(v["voorraad"])))
	Ui.zet_rust_modus(rust)
	Hits.plaats()
	return {} if v == null else v

func _gid() -> String:
	var v = State.s["checkin"]
	return "" if v == null else str(v["gastId"])

func _d() -> Dictionary:
	return State.spel_data(SPEL)

## The buttons of a strip, by name ("Kkamer1", "Kn3").
func _knoppen(strook_id: String) -> Array[String]:
	var uit: Array[String] = []
	var s := Hits.spot(strook_id)
	if s == null or not is_instance_valid(s.knoop):
		return uit
	var rij := s.knoop.get_node_or_null("Rij")
	if rij == null:
		return uit
	for k in rij.get_children():
		if not k.is_queued_for_deletion():
			uit.append(str(k.name))
	return uit

func _druk(strook_id: String, knop: String) -> bool:
	var s := Hits.spot(strook_id)
	if s == null or not is_instance_valid(s.knoop):
		return false
	var kn := s.knoop.get_node_or_null("Rij/" + knop)
	if kn == null or not (kn is BaseButton):
		return false
	(kn as BaseButton).emit_signal("pressed")
	return true

func _kaart(id: String) -> UiSomkaart:
	var s := Hits.spot(id)
	return null if s == null or not is_instance_valid(s.knoop) else s.knoop as UiSomkaart

func _wolk_tekst(id: String) -> String:
	var s := Hits.spot(id)
	if s == null or not is_instance_valid(s.knoop):
		return ""
	var w := s.knoop as UiWolk
	if w == null:
		return ""
	return ("%s %s" % [w.icoon_label.text if w.icoon_label != null else "",
		w.zeg_label.text if w.zeg_label != null else ""]).strip_edges()

## Wait (real time, the world standing still) until `klaar` is true.
func _wacht(klaar: Callable, sec: float) -> bool:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(sec * 1000.0):
		if bool(klaar.call()):
			return true
		await _boom().process_frame
	return bool(klaar.call())

## Drive the world by hand until `klaar` is true: ticks and the walk along, one
## real frame every few ticks so the game's own looks (every 0,1 s) keep up.
## `kamers` collects every room the camera stood in, and every tick checks that
## the camera is where the guest is while it walks along with him.
func _loop(klaar: Callable, kamers: Array, max_tikken := 4000) -> bool:
	var gid := _gid() if not _gid().is_empty() else str(_d().get("gast", ""))
	for i in max_tikken:
		if bool(klaar.call()):
			return true
		World._tik()
		Hotel._volg_stap()
		if kamers.is_empty() or kamers.back() != World.kamer_nu():
			kamers.append(World.kamer_nu())
		var d = World.dier(gid)
		if Hotel.volgt() == gid and d != null and d.kamer != World.kamer_nu():
			fout("de camera loopt met hem mee: %s tegen %s" % [World.kamer_nu(), d.kamer])
			return false
		if i % 6 == 5:
			await _boom().process_frame
	return bool(klaar.call())

## He stands still in `kamer`, done walking.
func _staat_in(kamer: String) -> Callable:
	var gid := _gid()
	return func() -> bool:
		var d = World.dier(gid)
		return d != null and d.kamer == kamer and str(d.reis_doel).is_empty() \
			and (d.route as Array).is_empty() and (d.punten as Array).is_empty()

## The room question answered: the beds game runs with its question up.
func _kies_kamer(kamer: String) -> bool:
	if not _druk("ci_som_keuzes", "K" + kamer):
		return false
	if Games.actief() != SPEL:
		return false
	return await _wacht(func() -> bool: return Hits.spot("bd_som_keuzes") != null, 3.0)

# ------------------------------------------------------- aanmelding, toegang

func test_aanmelding_zonder_ingang_en_zonder_kaartje() -> void:
	var def := Games.definitie(SPEL)
	gelijk(def.get("id", ""), SPEL, "de mapnaam IS het spel-id")
	gelijk(def.get("naam", ""), "Verdeel bedden over de kamers", "definitie().naam, letterlijk")
	gelijk(def.get("kamer", ""), "receptie", "het spel speelt aan de balie")
	var hs: Dictionary = def.get("hotspot", {})
	gelijk(hs.get("icoon", ""), "🛏", "het pictogram van de spelbalk")
	gelijk(str(hs.get("obj", "")), "", "geen ding om een ingangsknop aan te hangen")
	waar(not def.has("taak"), "geen eigen prikbordkaartje")
	waar(not def.has("rust"), "geen rustspul (de dekenkist hoorde bij de oude ingang)")
	var slot: Callable = def.get("unlock", Callable())
	waar(slot.is_valid() and slot.call(0, 3), "open vanaf de allereerste gast (N = 0)")
	var kan: Callable = def.get("kan", Callable())
	waar(kan.is_valid(), "er is een `kan`")
	waar(not kan.call({"checkin": null}), "zonder check-in niets te doen")
	waar(not kan.call({"checkin": {"stap": 3, "kamer": ""}}), "bij de kamerkeuze nog niet")
	waar(kan.call({"checkin": {"stap": 4, "kamer": "kamer1"}}), "bij zijn bedden wel")
	for q in Hotel.spel_taken():
		waar(str(q.get("spel", "")) != SPEL, "geen taakkaartje van bedden op het prikbord")

## Nowhere in the hotel hangs an entry: the game begins at the desk, from the
## room question.
func test_geen_ingangsknop_in_de_kamers() -> void:
	_op()
	_hotel(1, 0)
	for kamer in ["kamer1", "kamer2", "receptie"]:
		Hotel.naar_kamer(kamer)
		Games.hersteek()
		waar(Hits.spot("spel_" + SPEL) == null, "geen ingangsknop in %s" % kamer)
	await _af()

# ------------------------------------------------------------- de kamerkeuze

## Step 3 is a room, and only the rooms where one more animal fits: a free bed
## or floor for a new one.  A room full of sleepers and beds is not offered.
func test_kamerkeuze_biedt_alleen_kamers_met_plek() -> void:
	_op()
	var v := _hotel(1, 0)
	waar(not v.is_empty(), "er checkt iemand in")
	gelijk(int(v.get("stap", 0)), 3, "de check-in staat bij de kamer")
	var k := _kaart("ci_som")
	waar(k != null, "de vraag hangt aan de balie")
	if k != null:
		gelijk(k.regel_label.text, "🛏 Welke kamer voor %s?" % Hotel.gast_bij_id(_gid())["naam"],
			"de vraag, met het pictogram vooraan")
	gelijk(str(_knoppen("ci_som_keuzes")), str(["Kkamer1", "Kkamer2"]), "twee kamers met plek")
	await _af()
	# kamer 2 vol: elk bed dat erin past, en in elk een slaper
	_op()
	_hotel(1, -1)
	gelijk(State.plek_in("kamer2"), 0, "kamer 2 heeft geen plek meer")
	gelijk(str(_knoppen("ci_som_keuzes")), str(["Kkamer1"]), "alleen kamer 1 wordt aangeboden")
	await _af()

## The room buttons carry pictogram and word (HOTEL.md §9).
func test_kamerknoppen_hebben_pictogram_en_woord() -> void:
	_op()
	_hotel(0, 0)
	var s := Hits.spot("ci_som_keuzes")
	waar(s != null, "de kamerstrook staat er")
	if s != null:
		var kn := s.knoop.get_node_or_null("Rij/Kkamer1") as Button
		waar(kn != null, "de knop van kamer 1")
		if kn != null:
			gelijk(kn.text, "🛏 Kamer 1", "pictogram en woord")
	await _af()

# ----------------------------------------------------------- de getallen

## The numbers are the animals: the ones whose bed is in the chosen room, plus
## the new guest.  Kamer 2 with three sleepers asks "3 + 1 =".
func test_de_vraag_telt_de_dieren_van_die_kamer() -> void:
	_op()
	_hotel(1, 3)
	waar(await _kies_kamer("kamer2"), "kamer 2 gekozen, het spel vraagt")
	gelijk(Games.actief(), SPEL, "het beddenspel loopt")
	gelijk(int(State.s["checkin"]["stap"]), 4, "de check-in staat bij zijn bedden")
	gelijk(str(State.s["checkin"]["kamer"]), "kamer2", "in kamer 2")
	var k := _kaart("bd_som")
	waar(k != null, "de beddenvraag hangt aan de balie")
	if k != null:
		gelijk(k.regel_label.text, "🛏 In kamer 2 slapen al 3 dieren", "wie er al slapen")
		gelijk(k.regel2_label.text, "%s komt erbij. Hoeveel bedden?" % Hotel.gast_bij_id(_gid())["naam"],
			"en wie erbij komt")
		gelijk(k.som_label.text, "3 + 1 =", "de som")
	var knoppen := _knoppen("bd_som_keuzes")
	gelijk(knoppen.size(), 4, "vier getallen")
	waar(knoppen.has("Kn4"), "het goede antwoord staat erbij: %s" % str(knoppen))
	waar(knoppen.has("Kn3"), "en de kamer zonder hem: %s" % str(knoppen))
	gelijk(Hits.spot("bd_som").kamer, "receptie", "aan de balie")
	await _af()
	# and kamer 1 with nobody in it yet
	_op()
	_hotel(0, 2)
	waar(await _kies_kamer("kamer1"), "kamer 1 gekozen")
	var k1 := _kaart("bd_som")
	if k1 != null:
		gelijk(k1.regel_label.text, "🛏 In kamer 1 slaapt nog niemand", "nog niemand")
		gelijk(k1.som_label.text, "0 + 1 =", "0 + 1")
	waar(_knoppen("bd_som_keuzes").has("Kn1"), "met 1 bed als antwoord")
	await _af()

func test_een_slaper_is_enkelvoud() -> void:
	var spel: GDScript = load(BRON)
	gelijk(spel.regel_slapers("kamer1", 0), "In kamer 1 slaapt nog niemand", "0")
	gelijk(spel.regel_slapers("kamer1", 1), "In kamer 1 slaapt al 1 dier", "1")
	gelijk(spel.regel_slapers("kamer2", 5), "In kamer 2 slapen al 5 dieren", "5")
	gelijk(spel.regel_erbij("Boef"), "Boef komt erbij. Hoeveel bedden?", "erbij")

# --------------------------------------------------------------------- goed

## Right: he walks to his free bed (the camera along), lies in it, the
## check-in ends with its star, and the game closes itself.
func test_goed_hij_slaapt_en_de_check_in_is_klaar() -> void:
	_op()
	_hotel(1, 0, false)
	World.pauzeer(true)
	var gid := _gid()
	var sterren := int(State.s["sterren"])
	var gasten := (State.s["gasten"] as Array).size()
	waar(await _kies_kamer("kamer1"), "kamer 1 gekozen")
	waar(_druk("bd_som_keuzes", "Kn2"), "2 bedden: 1 slaper + hij")
	gelijk(State.s["checkin"], null, "de check-in is klaar")
	gelijk(int(State.s["sterren"]), sterren + 1, "één ster voor het meedoen")
	gelijk((State.s["gasten"] as Array).size(), gasten + 1, "hij logeert in het hotel")
	var g := State.gast_van(gid)
	gelijk(str(g.get("kamer", "")), "kamer1", "in kamer 1")
	gelijk(str(g.get("bed", "")), "bed2", "in het vrije bed")
	gelijk(Hotel.volgt(), gid, "de camera loopt met hem mee")
	var kamers: Array = []
	waar(await _loop(func() -> bool: return World.slaapt(gid), kamers), "hij slaapt")
	gelijk(kamers, ["receptie", "gang", "kamer1"], "door elke deur mee")
	gelijk(World.kamer_nu(), "kamer1", "de camera staat bij zijn bed")
	var dutje := "💤 %s doet een dutje" % str(g.get("naam", ""))
	waar(await _wacht(func() -> bool: return Hits.spot("bd_slaap") != null, 2.0), dutje)
	gelijk(_wolk_tekst("bd_slaap"), dutje, "de woorden")
	waar(await _wacht(func() -> bool: return Games.actief().is_empty(), 6.0),
		"het spel sluit zichzelf")
	gelijk(World.kamer_nu(), "kamer1", "en de camera blijft bij hem")
	waar(World.slaapt(gid), "hij slaapt nog")
	await _af()

## Every bed full: the right answer puts a NEW bed down where the floor has
## room, and he sleeps in it.
func test_goed_met_een_nieuw_bed() -> void:
	_op()
	_hotel(2, 0)
	var gid := _gid()
	var voor := Rooms.slots("kamer1", "bed").size()
	waar(await _kies_kamer("kamer1"), "kamer 1 gekozen")
	waar(_druk("bd_som_keuzes", "Kn3"), "3 bedden")
	gelijk(Rooms.slots("kamer1", "bed").size(), voor + 1, "er staat een bed bij")
	var g := State.gast_van(gid)
	waar(str(g.get("bed", "")).begins_with("m"), "hij slaapt in het nieuwe bed (%s)" % g.get("bed", ""))
	waar(World.slaapt(gid), "in rust meteen")
	gelijk(World.kamer_nu(), "kamer1", "en de camera staat bij hem")
	await _af()

# ----------------------------------------------------------------- te weinig

## Too few: no bed for him.  He walks to the room (the camera along), finds
## none, is sad, walks back (the camera along) and the same question comes back
## with the same four numbers.  Nothing is lost, no help appears.
func test_te_weinig_geen_bed_teleurgesteld_terug_en_opnieuw() -> void:
	_op()
	_hotel(1, 0, false)
	World.pauzeer(true)
	var gid := _gid()
	var sterren := int(State.s["sterren"])
	var gasten := (State.s["gasten"] as Array).size()
	waar(await _kies_kamer("kamer1"), "kamer 1 gekozen")
	var eerst := _knoppen("bd_som_keuzes")
	waar(_druk("bd_som_keuzes", "Kn1"), "1 bed: te weinig")
	waar(Hits.spot("bd_som") == null, "de vraag gaat weg terwijl hij loopt")
	waar(World.bed_verborgen("kamer1", "bed2"), "het vrije bed staat er niet")
	gelijk(Hotel.volgt(), gid, "de camera loopt met hem mee")
	var heen: Array = []
	waar(await _loop(_staat_in("kamer1"), heen), "hij is in kamer 1")
	gelijk(heen, ["receptie", "gang", "kamer1"], "heen: door elke deur mee")
	gelijk(World.kamer_nu(), "kamer1", "de camera blijft bij hem in de kamer")
	waar(await _wacht(func() -> bool: return Hits.spot("bd_nee") != null, 2.0), "hij zegt het")
	gelijk(_wolk_tekst("bd_nee"), "🛏 geen bed", "geen bed")
	gelijk(World.dier(gid).staat, "sip", "en hij is teleurgesteld")
	gelijk(State.gast_van(gid), {}, "hij heeft geen bed gekregen")
	waar(State.s["checkin"] != null and str(State.s["checkin"]["gastId"]) == gid,
		"de check-in loopt nog")
	# back to the desk
	waar(await _wacht(func() -> bool: return str(World.dier(gid).reis_doel) == "receptie", 5.0),
		"hij loopt terug naar de balie")
	gelijk(Hotel.volgt(), gid, "de camera loopt weer mee")
	var terug: Array = []
	waar(await _loop(_staat_in("receptie"), terug), "hij is terug in de receptie")
	gelijk(terug, ["kamer1", "gang", "receptie"], "terug: door elke deur mee")
	waar(not World.bed_verborgen("kamer1", "bed2"), "het vrije bed is terug zodra de kamer uit beeld is")
	waar(await _wacht(func() -> bool: return Hits.spot("bd_som_keuzes") != null, 3.0),
		"dezelfde vraag komt terug")
	gelijk(str(_knoppen("bd_som_keuzes")), str(eerst), "met dezelfde vier getallen")
	var p := Hotel.balieplek()
	var d = World.dier(gid)
	waar(Vector2(d.x, d.z).distance_to(Vector2(float(p["x"]), float(p["z"]))) <= 6.0,
		"hij staat weer aan de balie")
	# nothing lost, nothing given, no help
	gelijk(int(State.s["sterren"]), sterren, "geen ster erbij, geen ster eraf")
	gelijk((State.s["gasten"] as Array).size(), gasten, "niemand weg")
	gelijk(int(_d().get("missers", 0)), 1, "één misser")
	var k := _kaart("bd_som")
	waar(k != null and k.hulp_label.text.is_empty(), "geen hulpregel op de kaart")
	waar(k != null and k.vak_label.text.is_empty(), "en geen antwoord erop")
	for id in Hits.lijst():
		waar(not id.contains("wolkje") and not id.contains("hulp") and not id.contains("spook"),
			"geen helper of hulpknop: %s" % id)
	await _af()

# -------------------------------------------------------------------- te veel

## Too many: the room gets the beds he asked for (the free one and new ones),
## he sees the empty ones, is sad, the beds made for this answer go again, and
## he walks back to the same question.
func test_te_veel_bedden_gaan_weer_weg_en_opnieuw() -> void:
	_op()
	_hotel(1, 0, false)
	World.pauzeer(true)
	var gid := _gid()
	var bedden := Rooms.slots("kamer1", "bed").size()
	waar(await _kies_kamer("kamer1"), "kamer 1 gekozen")
	waar(_druk("bd_som_keuzes", "Kn4"), "4 bedden: te veel")
	var nep := World.decor_lijst("kamer1").filter(func(s): return s["door"] == SPEL)
	gelijk(nep.size(), 2, "twee bedden erbij, voor dit antwoord (1 slaper + 3 vrij)")
	waar(not World.bed_verborgen("kamer1", "bed2"), "het vrije bed staat er ook")
	gelijk(Rooms.slots("kamer1", "bed").size(), bedden, "niets in de save: de echte bedden blijven twee")
	var heen: Array = []
	waar(await _loop(_staat_in("kamer1"), heen), "hij is in kamer 1")
	gelijk(heen, ["receptie", "gang", "kamer1"], "de camera loopt mee")
	waar(await _wacht(func() -> bool: return Hits.spot("bd_nee") != null, 2.0), "hij zegt het")
	gelijk(_wolk_tekst("bd_nee"), "🛏 te veel bedden", "te veel bedden")
	gelijk(World.dier(gid).staat, "sip", "teleurgesteld")
	waar(await _wacht(func() -> bool:
			return World.decor_lijst("kamer1").filter(func(s): return s["door"] == SPEL).is_empty(), 3.0),
		"de bedden voor dit antwoord gaan weer weg")
	waar(World.bed_verborgen("kamer1", "bed2"), "ook het vrije bed staat er niet meer")
	var terug: Array = []
	waar(await _wacht(func() -> bool: return str(World.dier(gid).reis_doel) == "receptie", 5.0),
		"hij loopt terug")
	waar(await _loop(_staat_in("receptie"), terug), "terug aan de balie")
	gelijk(terug, ["kamer1", "gang", "receptie"], "de camera loopt terug mee")
	waar(await _wacht(func() -> bool: return Hits.spot("bd_som_keuzes") != null, 3.0),
		"dezelfde vraag")
	gelijk(State.gast_van(gid), {}, "hij heeft nog geen bed")
	waar(State.s["checkin"] != null, "de check-in loopt nog")
	# and now right
	waar(_druk("bd_som_keuzes", "Kn2"), "2 bedden")
	gelijk(State.s["checkin"], null, "nu is de check-in klaar")
	await _af()

## Owner, 2026-09-24: "De eerste twee bedden zijn goed geplaatst, daarna gaat
## alles door elkaar."  The beds a "too many" answer shows stand exactly where
## real new beds would stand — on kamer 2's next bed places, turned along z like
## bed1 and bed2 there — and a right answer puts his new bed on the next one.
func test_de_bedden_van_een_antwoord_staan_op_de_bedplekken() -> void:
	_op()
	_hotel(0, 2, false)
	World.pauzeer(true)
	var raster := Rooms.bed_raster("kamer2")
	waar(await _kies_kamer("kamer2"), "kamer 2 gekozen")
	waar(_druk("bd_som_keuzes", "Kn4"), "4 bedden: te veel")
	var nep := World.decor_lijst("kamer2").filter(func(s): return s["door"] == SPEL)
	gelijk(nep.size(), 2, "twee bedden erbij, voor dit antwoord")
	var plekken: Array = []
	for s in nep:
		gelijk(str(s["model"]), "bedz", "ze liggen zoals bed1 en bed2 van kamer 2")
		plekken.append(Vector2(float(s["x"]), float(s["z"])))
	plekken.sort()
	var verwacht: Array = [raster[2], raster[3]]
	verwacht.sort()
	gelijk(str(plekken), str(verwacht), "op de derde en vierde bedplek")
	gelijk(Rooms.slots("kamer2", "bed").size(), 2, "en niets in de save")
	await _af()
	# the right answer: his new bed on the third place, turned along z
	_op()
	_hotel(0, 2, true)
	var gid := _gid()
	waar(await _kies_kamer("kamer2"), "kamer 2 gekozen")
	waar(_druk("bd_som_keuzes", "Kn3"), "3 bedden: goed")
	gelijk(State.s["checkin"], null, "de check-in is klaar")
	var g := State.gast_van(gid)
	var bed := Rooms.slot("kamer2", str(g.get("bed", "")))
	waar(not bed.is_empty(), "hij heeft een nieuw bed")
	gelijk(Vector2(float(bed.get("x", 0.0)), float(bed.get("z", 0.0))), raster[2],
		"op de derde bedplek van kamer 2")
	gelijk(str(bed.get("model", "")), "bedz", "zoals de andere bedden daar")
	await _af()

# --------------------------------------------------------------- rustmodus

## Reduced motion: nobody walks.  Wrong: the sad bubble at the desk and the
## question again; right: in his bed at once.
func test_rustmodus_meteen() -> void:
	_op()
	_hotel(1, 0, true)
	var gid := _gid()
	waar(await _kies_kamer("kamer1"), "kamer 1 gekozen")
	waar(_druk("bd_som_keuzes", "Kn1"), "te weinig")
	gelijk(World.dier(gid).kamer, "receptie", "hij loopt nergens heen")
	gelijk(World.kamer_nu(), "receptie", "en de camera ook niet")
	gelijk(_wolk_tekst("bd_nee"), "🛏 geen bed", "de uitkomst meteen, aan de balie")
	gelijk(World.dier(gid).staat, "sip", "teleurgesteld")
	gelijk(Hotel.volgt(), "", "niemand om te volgen")
	waar(await _wacht(func() -> bool: return Hits.spot("bd_som_keuzes") != null, 4.0),
		"de vraag komt terug")
	waar(Hits.spot("bd_nee") == null, "het wolkje is weg")
	waar(_druk("bd_som_keuzes", "Kn2"), "goed")
	waar(World.slaapt(gid), "hij ligt meteen in zijn bed")
	gelijk(World.kamer_nu(), "kamer1", "en de camera is bij hem")
	gelijk(State.s["checkin"], null, "de check-in is klaar")
	await _af()

# ------------------------------------------------------------ terug en herlaad

## `⬅ Terug` while he walks to the room: the check-in is not over.  He walks
## back to the desk, the room question hangs there again, nothing is lost.
func test_terug_midden_in_het_spel() -> void:
	_op()
	_hotel(1, 0, false)
	World.pauzeer(true)
	var gid := _gid()
	var gasten := (State.s["gasten"] as Array).size()
	waar(await _kies_kamer("kamer1"), "kamer 1 gekozen")
	waar(_druk("bd_som_keuzes", "Kn3"), "te veel")
	for i in 30:
		World._tik()
		Hotel._volg_stap()
	Games.stop()                          # ⬅ Terug
	gelijk(Games.actief(), "", "het spel is weg")
	gelijk(Hotel.volgt(), "", "het volgen ook")
	var v = State.s["checkin"]
	waar(v != null and str(v["gastId"]) == gid, "de check-in loopt nog")
	gelijk(int(v["stap"]) if v != null else 0, 3, "terug bij de kamer")
	waar(State.s["nieuweGast"] != null, "hij staat nog op de lijst van de balie")
	gelijk((State.s["gasten"] as Array).size(), gasten, "niemand weg")
	gelijk(World.decor_lijst("kamer1").filter(func(s): return s["door"] == SPEL).size(), 0,
		"de bedden van dat antwoord zijn weg")
	waar(Hits.spot("ci_som_keuzes") != null, "de kamervraag hangt weer aan de balie")
	var d = World.dier(gid)
	waar(d.kamer == "receptie" or str(d.reis_doel) == "receptie", "hij gaat terug naar de balie")
	# he walks back to his place at the desk — and stays in the receptie: no
	# door of the walk he broke off comes back
	var kamers: Array = []
	var p := Hotel.balieplek()
	var plek := Vector2(float(p["x"]), float(p["z"]))
	waar(await _loop(func() -> bool:
			var dd = World.dier(gid)
			return dd != null and dd.kamer == "receptie" and (dd.punten as Array).is_empty() \
				and (dd.route as Array).is_empty() and Vector2(dd.x, dd.z).distance_to(plek) <= 3.0,
			kamers), "hij staat weer aan de balie")
	gelijk(World.dier(gid).kamer, "receptie", "in de receptie, niet ergens in de gang")
	# the child chooses again and the beds question is back
	Hits.plaats()
	waar(await _kies_kamer("kamer1"), "opnieuw kamer 1")
	waar(Hits.spot("bd_som") != null, "en de beddenvraag is terug")
	await _af()

## A reload in the middle: timers and walks are gone, the save is not.  The
## check-in comes back at the room question; choosing the room brings the beds
## question back.
func test_herlaad_midden_in_de_check_in() -> void:
	_op()
	_hotel(1, 0)
	var gid := _gid()
	waar(await _kies_kamer("kamer1"), "kamer 1 gekozen")
	gelijk(int(State.s["checkin"]["stap"]), 4, "bij zijn bedden")
	var doc := JSON.stringify({"v": State.VERSIE, "s": State.s})
	Games.stop()
	Hits.wis_alles()
	State.s = State.standaard()
	var terug = JSON.parse_string(doc)
	State.s = (terug as Dictionary)["s"]
	State.s["checkin"]["stap"] = 4          # as it was saved
	Hotel.herstel_wereld()
	Hotel.paint_checkin()                  # what `Hotel.start()` does
	var v = State.s["checkin"]
	waar(v != null and str(v["gastId"]) == gid, "de check-in is er nog, van hem")
	gelijk(int(v["stap"]) if v != null else 0, 3, "terug bij de kamer")
	Hits.plaats()
	waar(Hits.spot("ci_som_keuzes") != null, "de kamervraag hangt aan de balie")
	waar(await _kies_kamer("kamer1"), "kamer 1 opnieuw")
	var k := _kaart("bd_som")
	waar(k != null and k.som_label.text == "1 + 1 =", "de beddenvraag is terug")
	await _af()

# ----------------------------------------------------------------- teksten

## Every sentence on the longest guest name stays within 8 words and 40
## characters (HOTEL.md §9), and every glyph is in the bundled subset.
func test_teksten_in_het_budget_op_stampertje() -> void:
	_op()
	_hotel(2, 0, true, true)
	gelijk(str(Hotel.gast_bij_id(_gid()).get("naam", "")), "Stampertje", "de langste naam")
	var ci := _kaart("ci_som")
	waar(ci != null and Ui.keur_regel("ci", ci.regel_label.text), "de kamervraag: %s"
		% (ci.regel_label.text if ci != null else ""))
	waar(await _kies_kamer("kamer1"), "kamer 1 gekozen")
	var k := _kaart("bd_som")
	waar(k != null, "de beddenvraag")
	if k != null:
		gelijk(k.regel2_label.text, "Stampertje komt erbij. Hoeveel bedden?", "letterlijk")
		for zin in [k.regel_label.text, k.regel2_label.text]:
			waar(Ui.keur_regel("bd", zin), "'%s' past (%d tekens)" % [zin, zin.length()])
	for zin in ["In kamer 2 slapen al 5 dieren", "In kamer 1 slaapt nog niemand",
			"In kamer 1 slaapt al 1 dier", "Welke kamer voor Stampertje?",
			"Stampertje komt erbij. Hoeveel bedden?", "Stampertje doet een dutje"]:
		waar(Ui.keur_regel("bd", zin), "'%s' past in het budget" % zin)
	for zin in ["🛏 geen bed", "🛏 te veel bedden", "💤 Stampertje doet een dutje", "🛏 Kamer 1",
			"Verdeel bedden over de kamers", "🔄 Nog een keer"]:
		gelijk(str(Ui.mist_tekens(zin)), "[]", "elke glyph van '%s' is er" % zin)
	await _af()

## The source carries every child-facing string of games-a.md §3 verbatim.
func test_bron_draagt_de_letterlijke_teksten() -> void:
	var f := FileAccess.open(BRON, FileAccess.READ)
	waar(f != null, "de bron is te lezen")
	if f == null:
		return
	var bron := f.get_as_text()
	f.close()
	for zin in ['"Verdeel bedden over de kamers"', '"%s slaapt nog niemand"',
			'"%s slaapt al 1 dier"', '"%s slapen al %d dieren"',
			'"%s komt erbij. Hoeveel bedden?"', '"geen bed"', '"te veel bedden"',
			'"%s doet een dutje"', '"hoeveel bedden?"']:
		waar(bron.contains(zin), "de bron draagt %s" % zin)
	for oud in ["Bedden op rij", "Zet de bedden op rij", "Wolkje", "tel mee", "Hoeveel bedden heb je nodig?",
			"welterusten"]:
		waar(not bron.contains('"%s"' % oud), "de oude tekst %s is weg" % oud)
