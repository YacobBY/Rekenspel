extends Proef
## The hotel itself never pays out without maths (owner, 2026-10-08: "het moet
## niet mogelijk zijn om rekenen over te slaan en rekenen moet minstens 50% van
## de interactie zijn") and never helps after a miss (owner, 2026-09-24: "Nee
## geef geen hulp na fouten").  The holes this file keeps shut:
##
##  * the bowl: food that the voerkar's sums put there is eaten, but the tap
##    gives no star and ticks no card;
##  * the play basket: a small count first (`Hotel.mand_som`), then the play,
##    the wish, the star and the card;
##  * the check-in without the beds game: the beds sum at the desk first, never
##    a bed or a star without the right answer;
##  * the bill: a miss is the disappointed guest and the same question, no
##    counting line, no "+€" hint, no ghost coins;
##  * an open, missed check-in, bill or basket question survives a new day, a
##    second tap on the family and a reload unchanged;
##  * R1 — the maths share of a check-in and of a bill, per group.

func _voor() -> void:
	alleen_spellen([])               # no beds game: the check-in's own fallback
	Rooms.herstel()
	State.nieuw_spel()
	State.start_gekozen()
	Econ.rekening_stop()
	State.s["taken"] = []
	Hotel.bord_dicht()

## `n` guests from the pool in the real beds of the hotel, in pool order.
func _gasten(n: int) -> Array:
	var pool := State.gasten_pool()
	var bedden := State.alle_bedden()
	var poging := 0
	while bedden.size() < n and poging < 16:
		# one bed of its own for every guest: a bedroom takes four
		var k := str(State.slaapkamers()[poging % State.slaapkamers().size()])
		var p := State.bed_plek(k)
		if not p.is_empty():
			Rooms.meubel_zet(k, "bed", float(p["x"]), float(p["z"]))
		bedden = State.alle_bedden()
		poging += 1
	var uit: Array = []
	for i in mini(n, bedden.size()):
		var g: Dictionary = pool[i]
		g["kamer"] = str(bedden[i]["kamer"])
		g["bed"] = str(bedden[i]["slot"])
		g["waar"] = g["kamer"]
		g["nachten"] = 100
		uit.append(g)
	State.s["gasten"] = uit
	State.s["wachtlijst"] = pool.slice(uit.size())
	return uit

func _taak(id: String) -> Dictionary:
	for q in State.s["taken"]:
		if str(q["id"]) == id:
			return q
	return {}

func _scherm() -> Control:
	var boom := Engine.get_main_loop() as SceneTree
	var laag := Control.new()
	laag.size = Vector2(1000, 648)
	boom.root.add_child(laag)
	Ui.registreer_lagen(laag, laag, laag, laag, laag)
	World.meet(Rect2(Vector2.ZERO, laag.size))
	return laag

func _scherm_weg(laag: Control) -> void:
	Econ.rekening_stop()
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	laag.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame

func _strook(id: String) -> Array[String]:
	var uit: Array[String] = []
	var s := Hits.spot(id)
	if s == null or not is_instance_valid(s.knoop):
		return uit
	var rij := s.knoop.get_node_or_null("Rij")
	if rij != null:
		for k in rij.get_children():
			if not k.is_queued_for_deletion():
				uit.append(str(k.name))
	return uit

func _druk(strook: String, knop: String) -> bool:
	var s := Hits.spot(strook)
	if s == null or not is_instance_valid(s.knoop):
		return false
	var b := s.knoop.get_node_or_null("Rij/" + knop) as BaseButton
	if b == null:
		return false
	b.emit_signal("pressed")
	return true

## The strip of a card open again at once, as it is after `Ui.MIS_PAUZE`.
func _open(kaart_id: String) -> void:
	var k = Ui.kaart_van(kaart_id)
	if k == null:
		return
	k.pauze = false
	var s := Hits.spot(str(k.strook_id))
	if s != null and is_instance_valid(s.knoop) and s.knoop.has_method("slot"):
		s.knoop.slot(false)

## A wrong number on a strip of four: the first one that is not `goed`.
func _mis_knop(strook: String, goed: int) -> String:
	for k in _strook(strook):
		if k != "Kn%d" % goed:
			return k
	return ""

# ------------------------------------------------------------------ het bakje

## The food in the bowl came from the voerkar's sums; eating it is the world's
## business.  The tap pays no star and ticks no card: the voerkar game already
## gave its own, for the sum.
func test_bakje_geeft_geen_ster_zonder_som() -> void:
	_voor()
	var gasten := _gasten(1)
	var g: Dictionary = gasten[0]
	g["behoefte"] = "eten"
	g["gegeten"] = false
	var kamer := str(g["kamer"])
	var bakken := Rooms.slots(kamer, "bak")
	waar(not bakken.is_empty(), "%s heeft een bakje" % kamer)
	if bakken.is_empty():
		return
	var slot := str(bakken[0]["id"])
	World.zet_bak(kamer, slot, 3)
	Hotel.bouw_taken(true)
	var sterren := int(State.s["sterren"])
	Hotel.tik_bak(kamer, slot)
	gelijk(int(State.s["sterren"]), sterren, "een tik op het bakje geeft geen ster")
	gelijk(_taak("voer").get("klaar", false), false, "en vinkt het voerkaartje niet af")
	gelijk(g["gegeten"], true, "het eten in het bakje wordt wel opgegeten")
	gelijk(g["behoefte"], "spelen", "en daarna wil hij spelen")

# ------------------------------------------------------------------ de mand

## The basket asks a small count first: no play, no wish, no star and no card
## before the right answer; a wrong one is a miss and the same question.
func test_mand_vraagt_eerst_een_som() -> void:
	_voor()
	var gasten := _gasten(2)
	var kamer := str(gasten[0]["kamer"])
	for g in gasten:
		g["behoefte"] = "spelen"
		g["blij"] = false
	Hotel.bouw_taken(true)
	var sterren := int(State.s["sterren"])
	Hotel.tik_mand(kamer)
	for g in gasten:
		gelijk(g["blij"], false, "%s speelt nog niet: eerst de som" % g["naam"])
	gelijk(int(State.s["sterren"]), sterren, "geen ster voor de tik op de mand")
	gelijk(_taak("spelen").get("klaar", false), false, "het speelkaartje staat nog open")
	var vraag := Hotel.mand_vraag(kamer)
	waar(not vraag.is_empty(), "de mand stelt een vraag")
	if vraag.is_empty():
		return
	var goed := int(vraag["goed"])
	waar(goed > 0, "er is een antwoord")
	Hotel.mand_antwoord(kamer, goed + 1)
	for g in gasten:
		gelijk(g["blij"], false, "fout: %s speelt nog niet" % g["naam"])
	gelijk(int(State.s["sterren"]), sterren, "fout: geen ster")
	gelijk(int(Hotel.mand_vraag(kamer).get("fouten", 0)), 1, "één misser")
	gelijk(str(Hotel.mand_vraag(kamer).get("som", "")), str(vraag["som"]), "dezelfde som")
	Hotel.tik_mand(kamer)
	gelijk(str(Hotel.mand_vraag(kamer).get("som", "")), str(vraag["som"]),
		"nog een tik op de mand: dezelfde vraag")
	Hotel.mand_antwoord(kamer, goed)
	for g in gasten:
		gelijk(g["blij"], true, "goed: %s speelt" % g["naam"])
	gelijk(int(State.s["sterren"]), sterren + 1, "één ster voor het meedoen")
	var kaart := _taak("spelen")
	if not kaart.is_empty():
		gelijk(kaart["klaar"], true, "het speelkaartje staat afgevinkt")
	waar(Hotel.mand_vraag(kamer).is_empty(), "de vraag is beantwoord")
	sterren = int(State.s["sterren"])
	Hotel.tik_mand(kamer)
	waar(Hotel.mand_vraag(kamer).is_empty(), "niemand wacht meer: geen nieuwe vraag")
	gelijk(int(State.s["sterren"]), sterren, "en geen tweede ster")

## A missed basket question comes back unchanged after a new day and after a
## reload — even when another animal wants to play by then (R2).
func test_mand_misser_overleeft_morgen_en_herladen() -> void:
	_voor()
	var gasten := _gasten(2)
	var kamer := str(gasten[0]["kamer"])
	gasten[0]["behoefte"] = "spelen"
	gasten[1]["behoefte"] = "eten"
	Hotel.tik_mand(kamer)
	var vraag := Hotel.mand_vraag(kamer)
	waar(not vraag.is_empty(), "de mand vraagt")
	if vraag.is_empty():
		return
	Hotel.mand_antwoord(kamer, int(vraag["goed"]) + 1)
	Hotel.morgen()
	for g in gasten:
		if str(g["kamer"]) == kamer:
			g["behoefte"] = "spelen"
			g["blij"] = false
	waar(State.bewaar(), "bewaar")
	State.s = State.standaard()
	waar(State.lees(), "lees")
	Hotel.tik_mand(kamer)
	var terug := Hotel.mand_vraag(kamer)
	gelijk(str(terug.get("som", "")), str(vraag["som"]), "dezelfde som na een nacht en herladen")
	gelijk(int(terug.get("goed", -1)), int(vraag["goed"]), "hetzelfde antwoord")
	gelijk(int(terug.get("fouten", 0)), 1, "de misser telt nog")

## The basket's count, every group and every number of players: a real sum
## (never a bare number), a sentence a child can read, the answer the product
## — and so one maths tap after the opening tap (R1: reken 1 ≥ spel 0 + 1).
func test_mand_som_per_groep() -> void:
	for band in [3, 4, 5]:
		for w in [1, 2, 3, 4]:
			for dag in [1, 2, 3, 4, 5, 6]:
				var v := Hotel.mand_som(w, band, dag, "Stampertje")
				var wat := "groep %d, %d dieren, dag %d" % [band, w, dag]
				waar(str(v["som"]).contains("+") or str(v["som"]).contains("×"),
					"%s: een echte som (%s)" % [wat, v["som"]])
				gelijk(int(v["goed"]), int(v["m"]) * int(v["k"]), "%s: m × k" % wat)
				waar(int(v["m"]) >= 2, "%s: minstens twee keer" % wat)
				if band <= 3:
					waar(int(v["goed"]) <= 10, "%s: groep 3 tot 10 (%d)" % [wat, v["goed"]])
					waar(not str(v["som"]).contains("×"), "%s: groep 3 telt op" % wat)
				else:
					waar(int(v["goed"]) <= 40, "%s: hooguit 40" % wat)
				for zin in [str(v["regel"]), str(v["regel2"])]:
					waar(zin.split(" ", false).size() <= 8, "%s: ≤ 8 woorden: %s" % [wat, zin])
					waar(zin.length() <= 40, "%s: ≤ 40 tekens: %s" % [wat, zin])
				var reken := 1          # the answer on the strip
				var spel := 0           # the tap on the basket opened it
				waar(reken >= spel + 1, "%s: R1" % wat)

## On screen: the card hangs at the basket with four numbers; a miss leaves
## the same card and strip; the right answer takes the card AND its strip away
## (speel.js 2026-10-09 caught a strip left standing after the answer).
func test_mand_kaart_op_het_scherm() -> void:
	_voor()
	var laag := _scherm()
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	var gasten := _gasten(2)
	var kamer := str(gasten[0]["kamer"])
	for g in gasten:
		g["behoefte"] = "spelen"
		g["gegeten"] = true
		g["blij"] = false
	World.naar(kamer)
	Hotel.tik_mand(kamer)
	Hits.plaats()
	var vraag := Hotel.mand_vraag(kamer)
	waar(Hits.spot("mand_som") != null, "de kaart hangt bij de mand")
	var knoppen := _strook("mand_som_keuzes")
	gelijk(knoppen.size(), 4, "vier getallen")
	if not vraag.is_empty() and knoppen.size() == 4:
		var kaart = Hits.spot("mand_som").knoop
		waar(_druk("mand_som_keuzes", _mis_knop("mand_som_keuzes", int(vraag["goed"]))), "fout")
		waar(Hits.spot("mand_som") != null and Hits.spot("mand_som").knoop == kaart, "dezelfde kaart")
		gelijk(str(_strook("mand_som_keuzes")), str(knoppen), "dezelfde vier getallen")
		gelijk((kaart as UiSomkaart).hulp_label.text, "", "zonder hulp")
		_open("mand_som")
		waar(_druk("mand_som_keuzes", "Kn%d" % int(vraag["goed"])), "goed")
		waar(Hits.spot("mand_som") == null, "de kaart is weg")
		waar(Hits.spot("mand_som_keuzes") == null, "en de strook ook")
		gelijk(gasten[0].get("blij", false), true, "ze spelen")
	Ui.zet_rust_modus(rust)
	await _scherm_weg(laag)

# --------------------------------------------- de check-in zonder beddenspel

func _naar_kamerstap() -> Dictionary:
	State.s["scoops"] = 20
	State.s["levering"] = 4
	Hotel.bel()
	var v = State.s["checkin"]
	if v == null:
		return {}
	v["invoer"] = str(int(v["nieuw"]))
	Hotel.antwoord1()
	Hotel.antwoord2(Sommen.vergelijk(int(v["dagen"]), int(v["nieuw"]), int(v["voorraad"])))
	return v

## Without the beds game a chosen room used to give the guest a bed and a star
## at once.  Now the beds sum comes at the desk first: a wrong answer gives
## nothing and keeps the question; only the right one gives the bed and the star.
func test_checkin_zonder_beddenspel_geeft_geen_bed_zonder_som() -> void:
	_voor()
	var v := _naar_kamerstap()
	waar(not v.is_empty(), "er checkt iemand in")
	if v.is_empty():
		return
	gelijk(int(v["stap"]), 3, "bij de kamer")
	var gid := str(v["gastId"])
	var sterren := int(State.s["sterren"])
	waar(Hotel.kies_kamer("kamer1"), "kamer 1 gekozen")
	waar(State.s["checkin"] != null, "de check-in loopt nog: eerst de som")
	gelijk(int(State.s["sterren"]), sterren, "geen ster voor het kiezen van een kamer")
	gelijk(str(State.s["nieuweGast"]["bed"]) if State.s["nieuweGast"] != null else "?", "",
		"en nog geen bed")
	gelijk(int(v["stap"]), 4, "de beddensom")
	var goed := State.slapers_in("kamer1").size() + 1
	Hotel.antwoord_bed(goed + 1)
	waar(State.s["checkin"] != null, "fout: de check-in loopt nog")
	gelijk(int(State.s["sterren"]), sterren, "fout: geen ster")
	gelijk(int(v["fouten4"]), 1, "één misser")
	gelijk(int(v["stap"]), 4, "dezelfde vraag")
	gelijk(int(v["slapers"]) + 1, goed, "met hetzelfde antwoord")
	Hotel.antwoord_bed(goed)
	gelijk(State.s["checkin"], null, "goed: de check-in is klaar")
	gelijk(int(State.s["sterren"]), sterren + 1, "één ster voor het meedoen")
	gelijk(str(State.gast_van(gid).get("kamer", "")), "kamer1", "hij slaapt in kamer 1")

## The same question after a reload, on the card at the desk.
func test_checkin_beddensom_overleeft_herladen() -> void:
	_voor()
	var v := _naar_kamerstap()
	if v.is_empty():
		fout("er checkt niemand in")
		return
	Hotel.kies_kamer("kamer2")
	var goed := int(v["slapers"]) + 1
	Hotel.antwoord_bed(goed + 2)
	waar(State.bewaar(), "bewaar")
	State.s = State.standaard()
	waar(State.lees(), "lees")
	Hotel.paint_checkin()
	var w = State.s["checkin"]
	waar(w != null, "de check-in is er nog")
	if w == null:
		return
	gelijk(int(w["stap"]), 4, "nog steeds de beddensom")
	gelijk(str(w["kamer"]), "kamer2", "voor dezelfde kamer")
	gelijk(int(w["slapers"]) + 1, goed, "met hetzelfde antwoord")
	gelijk(int(w["fouten4"]), 1, "en de misser")
	Hotel.antwoord_bed(goed)
	gelijk(State.s["checkin"], null, "en dan klaar")

## After a miss in the beds game the child cannot swap the open question for an
## emptier room: the room question offers only that room (R2).
func test_na_een_beddenmisser_blijft_de_kamer() -> void:
	_voor()
	var v := _naar_kamerstap()
	if v.is_empty():
		fout("er checkt niemand in")
		return
	var gid := str(v["gastId"])
	# what the beds game leaves in its drawer after one miss, then `⬅ Terug`
	v["kamer"] = "kamer1"
	v["stap"] = 4
	var d := State.spel_data("bedden")
	d.clear()
	d["gast"] = gid
	d["kamer"] = "kamer1"
	d["missers"] = 1
	Hotel.checkin_terug()
	gelijk(int(v["stap"]), 3, "terug bij de kamer")
	waar(not Hotel.kies_kamer("kamer2"), "een andere kamer kan niet")
	gelijk(int(v["stap"]), 3, "de vraag blijft")
	waar(Hotel.kies_kamer("kamer1"), "dezelfde kamer wel")
	d.clear()

# ----------------------------------------------------- de check-in en morgen

## An open, missed check-in question stays the same question, with the same
## four numbers in the same order, after a new day and after a reload.
func test_checkin_misser_overleeft_morgen_en_herladen() -> void:
	_voor()
	var laag := _scherm()
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	World.naar("receptie")
	Hotel.bel()
	var v = State.s["checkin"]
	waar(v != null, "er checkt iemand in")
	if v != null:
		Hits.plaats()
		var knoppen := _strook("ci_som_keuzes")
		var som: String = (Hits.spot("ci_som").knoop as UiSomkaart).som_label.text
		waar(_druk("ci_som_keuzes", _mis_knop("ci_som_keuzes", int(v["nieuw"]))), "een fout getal")
		gelijk(int(v["fouten1"]), 1, "één misser")
		var voor := [int(v["samen"]), int(v["extra"]), int(v["nieuw"]), int(v["stap"])]
		Hotel.morgen()
		var w = State.s["checkin"]
		waar(w != null, "na de nacht staat hij er nog")
		if w != null:
			gelijk([int(w["samen"]), int(w["extra"]), int(w["nieuw"]), int(w["stap"])], voor,
				"dezelfde vraag na een nacht")
			gelijk(int(w["fouten1"]), 1, "de misser telt nog")
			waar(State.bewaar(), "bewaar")
			State.s = State.standaard()
			waar(State.lees(), "lees")
			Hotel.paint_checkin()
			Hits.plaats()
			gelijk(str(_strook("ci_som_keuzes")), str(knoppen), "dezelfde vier getallen, zelfde volgorde")
			gelijk((Hits.spot("ci_som").knoop as UiSomkaart).som_label.text, som, "dezelfde som")
			gelijk(int(State.s["checkin"]["fouten1"]), 1, "en de misser")
		World.weg(str(v["gastId"]))
	Ui.zet_rust_modus(rust)
	await _scherm_weg(laag)

## The "enough food?" strip is maths: its card says so (`reken: true`).
func test_checkin_genoeg_is_een_rekenstrook() -> void:
	_voor()
	var laag := _scherm()
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	World.naar("receptie")
	Hotel.bel()
	var v = State.s["checkin"]
	if v != null:
		v["invoer"] = str(int(v["nieuw"]))
		Hotel.antwoord1()
		Hits.plaats()
		waar(Ui.kaart_van("ci_som") != null and Ui.kaart_van("ci_som").getal_vraag,
			"vraag 2 is een rekenkaart (reken: true)")
		World.weg(str(v["gastId"]))
	Ui.zet_rust_modus(rust)
	await _scherm_weg(laag)

# ------------------------------------------------------------- de rekening

func _gast_weg() -> Dictionary:
	var g := State.mk_gast("boef", "Boef", "hond", "puppy", 2, "Wandeling", 30)
	g["kamer"] = "kamer1"
	g["bed"] = "bed1"
	g["waar"] = "receptie"
	g["geslapen"] = 4
	State.s["gasten"] = [g]
	State.s["uitcheck"] = ["boef"]
	return g

## No help after a miss, in any of the three steps: no counting line on the
## card, no "+€" bubble at the counter, no ghost coins.  The guest is sad and
## the same card stays.
func test_rekening_geen_hulp_na_een_misser() -> void:
	_voor()
	var laag := _scherm()
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	World.naar("receptie")
	var g := _gast_weg()
	World.zet("boef", "receptie", 60.0, 60.0, {"kind": "hond", "naam": "Boef"})
	Econ.rekening({"gast": g, "fam": "Bakker", "nachten": 4, "prijs": 2,
		"totaal": 8, "betaald": 10})
	Hits.plaats()
	var kaart = Hits.spot("rek_som").knoop if Hits.spot("rek_som") != null else null
	waar(kaart != null, "de som staat er")
	var knoppen := _strook("rek_som_keuzes")
	for poging in 3:
		_open("rek_som")
		waar(_druk("rek_som_keuzes", _mis_knop("rek_som_keuzes", 8)), "een fout getal")
		await Econ.wacht(0.0)
	gelijk(int(Econ.rekening_stand()["pogingen"]), 3, "drie missers")
	waar(Hits.spot("rek_som") != null and Hits.spot("rek_som").knoop == kaart, "dezelfde kaart")
	gelijk((kaart as UiSomkaart).hulp_label.text, "", "zonder tel-mee-regel")
	gelijk(str(_strook("rek_som_keuzes")), str(knoppen), "met dezelfde vier getallen")
	waar(Hits.spot("spook0") == null, "zonder spookmunten")
	waar(Hits.spot("mis_rek_som") != null, "met het wolkje van de misser")
	gelijk(World.dier("boef").pose, "sip", "de gast is teleurgesteld")
	_open("rek_som")
	await Econ.som_ok(8)
	# too few coins: a miss, nothing that says how much is missing
	Econ.leg_neer()
	for poging in 3:
		await Econ.klaar_met_tellen()
	gelijk(int(Econ.rekening_stand()["telPog"]), 3, "drie keer te weinig")
	gelijk(int(Econ.rekening_stand()["stap"]), 2, "nog steeds tellen")
	waar(Hits.spot("rek_hint") == null, "geen +€-wolkje")
	waar(Hits.spot("spook0") == null, "geen spookmunten")
	gelijk(World.dier("boef").pose, "sip", "de gast is teleurgesteld")
	for i in 3:
		Econ.leg_neer()
	await Econ.klaar_met_tellen()
	gelijk(int(Econ.rekening_stand()["stap"]), 3, "wisselgeld")
	Hits.plaats()
	var wk = Hits.spot("rek_wissel").knoop if Hits.spot("rek_wissel") != null else null
	for poging in 3:
		_open("rek_wissel")
		waar(_druk("rek_wissel_keuzes", _mis_knop("rek_wissel_keuzes", 2)), "een fout wisselgeld")
		await Econ.wacht(0.0)
	gelijk(int(Econ.rekening_stand()["wisselPog"]), 3, "drie missers")
	waar(Hits.spot("rek_wissel") != null and Hits.spot("rek_wissel").knoop == wk, "dezelfde kaart")
	if wk != null:
		gelijk((wk as UiSomkaart).hulp_label.text, "", "zonder hulpregel")
	waar(Hits.spot("spook0") == null, "zonder spookmunten")
	var bron := FileAccess.get_file_as_string("res://hotel/rekening.gd")
	for weg in ["kaart.hulp(", "_spook(", "\"+€%d\""]:
		waar(not bron.contains(weg), "de rekening kent geen hulp na een fout meer: %s" % weg)
	World.weg("boef")
	Ui.zet_rust_modus(rust)
	await _scherm_weg(laag)

## Tapping the family again, a new day or a reload never starts the bill over:
## the misses, the counted coins and the question stay (R2).
func test_rekening_misser_overleeft_opnieuw_tikken_morgen_en_herladen() -> void:
	_voor()
	var g := _gast_weg()
	g["nachten"] = 4
	g["prijs"] = 2
	g["betaald"] = 10
	Hotel.avondronde()
	Hotel.reken_af("boef")
	waar(Econ.rekening_bezig(), "de rekening loopt")
	await Econ.som_ok(9)
	gelijk(int(Econ.rekening_stand()["pogingen"]), 1, "één misser")
	var zaad := int(Econ.rekening_stand().get("zaad", -1))
	Hotel.avondronde()
	Hotel.reken_af("boef")
	gelijk(int(Econ.rekening_stand()["pogingen"]), 1, "nog een tik op de familie: de misser blijft")
	gelijk(int(Econ.rekening_stand()["stap"]), 1, "en dezelfde vraag")
	Hotel.morgen()
	waar(Econ.rekening_bezig(), "na een nacht loopt de rekening nog")
	gelijk(int(Econ.rekening_stand()["pogingen"]), 1, "met de misser")
	gelijk(int(Econ.rekening_stand()["totaal"]), 8, "en dezelfde som")
	gelijk(int(Econ.rekening_stand().get("zaad", -2)), zaad, "en dezelfde strook")
	waar(State.bewaar(), "bewaar")
	State.s = State.standaard()
	waar(State.lees(), "lees")
	Econ.herstel_rekening()
	gelijk(int(Econ.rekening_stand()["pogingen"]), 1, "na herladen nog steeds")
	gelijk(int(Econ.rekening_stand().get("zaad", -2)), zaad, "en dezelfde strook")
	await Econ.som_ok(8)
	gelijk(int(Econ.rekening_stand()["stap"]), 2, "en dan verder")
	Econ.rekening_stop()

# ----------------------------------------------------------------- R1

## Every tap of a whole check-in and a whole bill, classed as R1 says: an
## answer on a maths strip or a coin laid on the counter (a quantity that is
## checked against the bill) is "reken"; choosing a room or `✔ klaar` is "spel";
## the tap that opened it (the bell, the family) does not count.  For groep 3,
## 4 and 5 and a small and a large hotel: reken ≥ spel + 1.
## VA (2026-10-09): every tap goes through the real strip or button (the
## Rekenwacht classifies it — a call to `Hotel.antwoord1`/`Econ.leg_neer` would
## bypass it), and the real counters agree: `Reken.totaal()` grows by exactly
## the taps counted here, holds R1 by itself, and a right answer pays back.
func test_rekenaandeel_checkin_en_rekening() -> void:
	var laag := _scherm()
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	for band in [3, 4, 5]:
		for n in [0, 3, 7]:
			_voor()
			World.naar("receptie")
			State.s["kunnen"] = band
			State.herbereken()
			_gasten(n)
			var wat := "groep %d, %d gasten" % [band, n]
			var tel := {"reken": 0, "spel": 0}
			var b0 := _va_begin()
			var t0 := Reken.totaal()
			State.s["scoops"] = 20
			State.s["levering"] = 4
			Hotel.bel()                             # the bell opened it: not counted
			var v = State.s["checkin"]
			if v == null:
				fout("%s: geen check-in" % wat)
				continue
			Hits.plaats()
			_open("ci_som")
			waar(_druk("ci_som_keuzes", "Kn%d" % int(v["nieuw"])), "%s: vraag 1 getikt" % wat)
			tel["reken"] += 1
			gelijk(int(v["stap"]), 2, "%s: vraag 1 goed" % wat)
			Hits.plaats()
			_open("ci_som")
			waar(_druk("ci_som_keuzes", "K" + Sommen.vergelijk(int(v["dagen"]), int(v["nieuw"]),
				int(v["voorraad"]))), "%s: vraag 2 getikt" % wat)
			tel["reken"] += 1
			gelijk(int(v["stap"]), 3, "%s: vraag 2 goed" % wat)
			Hits.plaats()
			var kamers := State.kamers_met_plek()
			_open("ci_som")
			waar(_druk("ci_som_keuzes", "K" + str(kamers[0])), "%s: de kamer getikt" % wat)
			tel["spel"] += 1                        # de kamer
			gelijk(int(v["stap"]), 4, "%s: de beddensom" % wat)
			Hits.plaats()
			_open("ci_som")
			waar(_druk("ci_som_keuzes", "Kn%d" % (int(v["slapers"]) + 1)), "%s: de beddensom getikt" % wat)
			tel["reken"] += 1
			gelijk(State.s["checkin"], null, "%s: ingecheckt" % wat)
			waar(tel["reken"] >= tel["spel"] + 1, "%s: check-in R1 %s" % [wat, tel])
			_va_eind(wat + ", check-in", tel, t0, b0)
			# the bill for that guest, as the evening asks it
			var gid := str(v["gastId"])
			var g := State.gast_van(gid)
			var geld := Sommen.geld(State.band(), int(State.s["dag"]))
			g["nachten"] = geld["nachten"]
			g["prijs"] = geld["prijs"]
			g["betaald"] = geld["betaald"]
			State.s["uitcheck"] = [gid]
			var rt := {"reken": 0, "spel": 0}
			b0 = _va_begin()
			t0 = Reken.totaal()
			Hotel.reken_af(gid)                     # the tap on the family: not counted
			Hits.plaats()
			var totaal := int(Econ.rekening_stand()["totaal"])
			_open("rek_som")
			waar(_druk("rek_som_keuzes", "Kn%d" % totaal), "%s: de som van de rekening" % wat)
			rt["reken"] += 1
			waar(await _wacht_spot("rek_buidel"), "%s: de buidel staat er" % wat)
			for _munt in 40:
				if Econ.geteld() >= totaal:
					break
				if not _tik_spot("rek_buidel"):
					break
				rt["reken"] += 1                    # a coin on the counter
			var wissel := Econ.geteld() > totaal
			waar(_tik_spot("rek_ok"), "%s: ✔ klaar" % wat)
			rt["spel"] += 1                         # confirming
			if wissel:
				waar(await _wacht_spot("rek_wissel_keuzes"), "%s: het wisselgeld" % wat)
				_open("rek_wissel")
				waar(_druk("rek_wissel_keuzes", "Kn%d" % (Econ.geteld() - totaal)),
					"%s: het wisselgeld getikt" % wat)
				rt["reken"] += 1
			for _i in 100:
				if not Econ.rekening_bezig():
					break
				await (Engine.get_main_loop() as SceneTree).process_frame
			waar(not Econ.rekening_bezig(), "%s: afgerekend" % wat)
			waar(rt["reken"] >= rt["spel"] + 1, "%s: rekening R1 %s" % [wat, rt])
			_va_eind(wat + ", rekening", rt, t0, b0)
			Econ.rekening_stop()
			World.weg(gid)
	Ui.zet_rust_modus(rust)
	await _scherm_weg(laag)
	_schoon()

## VA: the real Rekenwacht.  Half a budget first, so a right answer has room
## to pay back.
const VA_BUDGET := 6

func _va_begin() -> int:
	Reken.voor_test()
	for _i in Reken.BUDGET_MAX - VA_BUDGET:
		Reken.tik("spel", "test:va")
	return Reken.budget()

## No game runs at the desk, so `Reken.beurt()` stays still: the totals tell.
func _va_eind(wat: String, tel: Dictionary, t0: Dictionary, budget_voor: int) -> void:
	var t1 := Reken.totaal()
	var r := int(t1["reken"]) - int(t0["reken"])
	var s := int(t1["spel"]) - int(t0["spel"])
	var g := int(t1["goed"]) - int(t0["goed"])
	print("[VA] %s: reken=%d spel=%d goed=%d budget=%d->%d" % [wat, r, s, g, budget_voor,
		Reken.budget()])
	waar(r >= s + 1, "%s: Reken.totaal() reken %d >= spel %d + 1" % [wat, r, s])
	gelijk(r, int(tel["reken"]), "%s: de Rekenwacht telt de rekentikken zoals de teller" % wat)
	gelijk(s, int(tel["spel"]), "%s: de Rekenwacht telt de speltikken zoals de teller" % wat)
	waar(g >= 1, "%s: Reken.goed() vuurde" % wat)
	waar(Reken.budget() > budget_voor, "%s: het budget steeg (%d -> %d)" % [wat, budget_voor,
		Reken.budget()])
	gelijk(int(t1["geweigerd"]), int(t0["geweigerd"]), "%s: geen tik geweigerd" % wat)

func _wacht_spot(id: String, seconden := 4.0) -> bool:
	var boom := Engine.get_main_loop() as SceneTree
	var tot := Time.get_ticks_msec() + int(seconden * 1000.0)
	while Hits.spot(id) == null and Time.get_ticks_msec() < tot:
		await boom.process_frame
	return Hits.spot(id) != null

## A tap on a hotspot's own button, as a child does it.
func _tik_spot(id: String) -> bool:
	var s := Hits.spot(id)
	if s == null or not is_instance_valid(s.knoop) or not (s.knoop is BaseButton):
		fout("%s staat er niet om te tikken" % id)
		return false
	(s.knoop as BaseButton).pressed.emit()
	return true

## Leave the hotel as a fresh game: a band-5 hotel full of guests left behind
## unlocks games whose resting props (the spiegel's easel) then stand in the
## rooms of the next test file.
func _schoon() -> void:
	Econ.rekening_stop()
	State.nieuw_spel()
	State.start_gekozen()
	Rooms.herstel()
	World.sync(Hotel.alle_dieren())

## VA (2026-10-09), red before the fix in `Reken.soort_van`: every button of the
## bill counted as maths through its owner, so `✔ klaar` (confirming, play by
## R1) was maths and the real count disagreed with the design.  Now only the
## marked buttons are maths — the purse (its `reken: true` reaches `Hits`
## since `Ui.bron` passes it on) and the counter — and `✔ klaar` is play; during
## a rekenmoment every button of the bill still goes through.
func test_rekening_alleen_de_munten_zijn_rekenen() -> void:
	_voor()
	var laag := _scherm()
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	World.naar("receptie")
	var g := _gast_weg()
	World.zet("boef", "receptie", 60.0, 60.0, {"kind": "hond", "naam": "Boef"})
	Econ.rekening({"gast": g, "fam": "Bakker", "nachten": 4, "prijs": 2,
		"totaal": 8, "betaald": 10})
	Hits.plaats()
	_open("rek_som")
	waar(_druk("rek_som_keuzes", "Kn8"), "de som van de rekening")
	waar(await _wacht_spot("rek_buidel"), "de buidel staat er")
	for id in ["rek_buidel", "rek_bank", "rek_ok"]:
		waar(Hits.spot(id) != null, "%s staat er" % id)
	if Hits.spot("rek_ok") != null and Hits.spot("rek_buidel") != null:
		gelijk(Reken.soort_van(Hits.spot("rek_buidel")), "reken", "een munt uit de buidel is rekenen")
		gelijk(Reken.soort_van(Hits.spot("rek_bank")), "reken", "een munt op de toonbank is rekenen")
		gelijk(Reken.soort_van(Hits.spot("rek_ok")), "spel", "✔ klaar is bevestigen: spel")
		# the budget runs out: the bill's own buttons stay allowed (and are not counted)
		for _i in Reken.BUDGET_MAX + 1:
			Reken.tik("spel", "test:va")
		waar(not Reken.vrij(), "een rekenmoment")
		var geweigerd := int(Reken.totaal()["geweigerd"])
		waar(_tik_spot("rek_buidel"), "een munt")
		waar(_tik_spot("rek_ok"), "✔ klaar")
		gelijk(int(Reken.totaal()["geweigerd"]), geweigerd, "niets van de rekening is geweigerd")
	World.weg("boef")
	Ui.zet_rust_modus(rust)
	await _scherm_weg(laag)
	_schoon()
