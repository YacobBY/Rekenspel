extends Proef
## `Hotel`: the day cycle, the wishes, check-in, feeding and playing, the
## evening round and the prikbord (world.md §3).  Everything is asserted on
## `State` and on the hotel's own signals — never on pixels, so the suite runs
## headless and does not wait for W1's rooms or W3's shell.

const NEP := preload("res://spel/minigame.tscn")

var _nep_ids: Array[String] = []

func _voor() -> void:
	alleen_spellen([])               # the real games are wave 2; these tests use stand-ins
	Rooms.herstel()                  # the base beds: a test that filled the rooms leaves none
	State.nieuw_spel()
	State.start_gekozen()
	Econ.rekening_stop()
	State.s["taken"] = []
	Hotel.bord_dicht()

## A game definition without a scene of its own: the registry accepts one, and
## that is all the hotel needs to know whether a wish may be handed out and
## which chip belongs on the board.
func _meld(id: String, def: Dictionary) -> void:
	def["id"] = id
	Games.registreer(def, NEP)
	_nep_ids.append(id)

## `Games` has no deregister — a registry is written once at boot.  A test may
## not leave its stand-ins behind for the next test, so it clears them here.
func _na() -> void:
	for id in _nep_ids:
		if "_defs" in Games:
			Games._defs.erase(id)
		if "_scenes" in Games:
			Games._scenes.erase(id)
	_nep_ids.clear()

## `n` guests from the pool, in pool order, each in a REAL bed of the hotel
## (`Rooms.slots("", "bed")`), so `bed_vrij()` and `gast_in_bed()` see what the
## game sees.
func _gasten(n: int) -> Array:
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
		uit.append(g)
	State.s["gasten"] = uit
	return uit

## A FULL hotel: every bedroom holds as many beds as the check-in puts down
## (`State.MAX_BEDDEN`) and a guest sleeps in every one, so no room can take
## another animal and the prio-0 card `Nog plek voor een gast` does not take a
## place on a board that a test is measuring for other reasons.  Since
## 2026-09-24 a free bed is not the guest cap any more: the free floor is.
## Undo with `Rooms.herstel()`.
func _hotel_vol() -> Array:
	for k in State.slaapkamers():
		while Rooms.slots(k, "bed").size() < State.MAX_BEDDEN:
			var p := State.bed_plek(k)
			if p.is_empty() or Rooms.meubel_zet(k, "bed", float(p["x"]), float(p["z"])).is_empty():
				break
	var pool := State.gasten_pool()
	var bedden := State.alle_bedden()
	var uit: Array = []
	for i in bedden.size():
		var g: Dictionary = (pool[i % pool.size()] as Dictionary).duplicate(true)
		if i >= pool.size():
			g["id"] = "%s_%d" % [str(g["id"]), i]
		g["kamer"] = str(bedden[i]["kamer"])
		g["bed"] = str(bedden[i]["slot"])
		g["waar"] = g["kamer"]
		g["nachten"] = 100
		uit.append(g)
	State.s["gasten"] = uit
	return uit

## Fill every bowl, so the `🍪 Vul de voerkar` card does not take a place on
## the board in a test that is about something else.
func _bakken_vol() -> void:
	for b in Hotel.alle_bakken():
		World.zet_bak(str(b["kamer"]), str(b["slot"]), 4)

func _bakken_leeg() -> void:
	for b in Hotel.alle_bakken():
		World.zet_bak(str(b["kamer"]), str(b["slot"]), 0)

# --------------------------------------------------------------- de teksten

func test_ronde_en_wenswoorden_verbatim() -> void:
	_voor()
	State.s["ronde"] = "ochtend"
	gelijk(Hotel.ronde_naam(), "☀️ Ochtendronde", "ochtendronde")
	State.s["ronde"] = "avond"
	gelijk(Hotel.ronde_naam(), "🌙 Avondronde", "avondronde")
	State.s["ronde"] = "vrij"
	gelijk(Hotel.ronde_naam(), "🐾 Vrij spelen", "vrij spelen")
	# a pictogram never appears without its word (HOTEL.md §9)
	gelijk(Hotel.wens_woord("eten"), "eten", "🍪 eten")
	gelijk(Hotel.wens_woord("kamer"), "bed", "🛏 bed")
	gelijk(Hotel.wens_woord("bad"), "bad", "🛁 bad")
	gelijk(Hotel.wens_woord("spelen"), "spelen", "🧶 spelen")
	gelijk(Hotel.wens_woord("zwemmen"), "zwemmen", "🏊 zwemmen")
	gelijk(Hotel.wens_woord("souvenir"), "souvenir", "🎁 souvenir")
	for b in ["eten", "kamer", "bad", "spelen", "zwemmen", "souvenir"]:
		waar(State.BEHOEFTE.has(b), "BEHOEFTE kent %s" % b)
	gelijk(State.BEHOEFTE["bad"]["tekst"], "wil in de tobbe", "de lange tekst")

## F3: every child-facing string of world.md §7.8 must be in the tree, verbatim
## and in the file that owns it.  A scripted diff over the specs found the four
## letter strings missing tree-wide; this test is the gate that keeps them.
func test_strings_van_wereld_7_8_staan_er_verbatim() -> void:
	var bron := _lees("res://autoload/hotel.gd") + _lees("res://hotel/rekening.gd")
	for zin in [
			# de brief
			"💌 Er is post!", "Hang de brief op de muur 📌", "💌 Aan de muur!",
			"💌 De brievenmuur",
			"Hier komen de bedankjes van de families die hun dier bij jou lieten slapen.",
			"Laat een gast zijn nachten uitslapen en reken netjes af — dan komt er post.",
			"Sluiten",
			# de avond en de rekening
			"Morgen ▸", "gaat naar huis", "sliep", "per nacht",
			"gaf €%d, het kost €%d", "klaar", "klaar met tellen",
			"de toonbank", "munt van %d euro", "de buidel is leeg",
			"op de toonbank ligt €%d", "tik een getal", "zo ziet het uit",
			"zoveel is het samen", "dit moet er nog bij",
			"zoveel krijgt de familie terug", "terug", "betaald"]:
		waar(bron.contains(zin), 'world.md §7.8: "%s" staat in de bron' % zin)
	gelijk(Hotel.POST["titel"], "💌 Er is post!", "de kop van het postblad")
	gelijk(Hotel.POST["knop"], "Hang de brief op de muur 📌", "de knop eronder")
	gelijk(Hotel.POST["toast"], "💌 Aan de muur!", "de toast na het ophangen")
	var muur := Hotel.brievenmuur()
	gelijk(muur["titel"], "💌 De brievenmuur", "de kop van de brievenmuur")
	gelijk(muur["sluiten"], "Sluiten", "de sluitknop")
	waar(not str(muur["hint"]).is_empty(), "zonder brieven legt hij uit hoe je er een krijgt")

func _lees(pad: String) -> String:
	var f := FileAccess.open(pad, FileAccess.READ)
	if f == null:
		fout("kan %s niet lezen" % pad)
		return ""
	var tekst := f.get_as_text()
	f.close()
	return tekst

## The letter goes out on the signal, with the words of §7.8 next to it.
func test_brief_gaat_op_de_muur() -> void:
	_voor()
	var gekregen := []
	Hotel.brief_gereed.connect(func(b): gekregen.append(b), CONNECT_ONE_SHOT)
	var brief := State.nieuwe_brief(State.mk_gast("boef", "Boef", "hond", "puppy",
		2, "Wandeling", 30))
	Hotel.brief_op_muur(brief)
	gelijk(gekregen.size(), 1, "brief_gereed komt één keer")
	gelijk(gekregen[0]["titel"], "Bedankje van familie Van Dijk 💌", "met de brief erbij")
	Hotel.brief_opgehangen()          # the toast; no crash without a screen
	State.s["brieven"] = [brief]
	var muur := Hotel.brievenmuur()
	gelijk((muur["brieven"] as Array).size(), 1, "de muur toont de brief")
	gelijk(muur["hint"], "", "en dan hoeft de uitleg niet meer")

func test_hud_schrijft_vijf_getallen() -> void:
	_voor()
	State.s["dag"] = 4
	State.s["munten"] = 7
	State.s["sterren"] = 11
	State.s["brieven"] = [{"titel": "a", "tekst": "b", "dag": 1}]
	State.s["ronde"] = "avond"
	var gemeld := [0]
	Hotel.hud_veranderd.connect(func(): gemeld[0] += 1)
	Hotel.hud()
	gelijk(gemeld[0], 1, "hud_veranderd komt één keer")
	var h := Hotel.hud_gegevens()
	gelijk(h["dag"], 4, "#dayNum")
	gelijk(h["munten"], 7, "#muntNum")
	gelijk(h["sterren"], 11, "#sterNum")
	gelijk(h["brieven"], 1, "#letterNum")
	gelijk(h["ronde"], "🌙 Avondronde", "#rondeNaam")

# ----------------------------------------------------------------- morgen()

## Eight days with three guests: the food bookkeeping, the messages and the
## checkout list of world.md §3.1, step by step.
func test_morgen_acht_dagen_drie_gasten() -> void:
	_voor()
	var gasten := _gasten(3)          # Boef 2 + Muis 1 + Wolkje 1 = 4 scheppen
	gasten[0]["nachten"] = 3
	gasten[1]["nachten"] = 4
	gasten[2]["nachten"] = 5
	gelijk(State.dag_verbruik(), 4, "vier scheppen per dag")
	gelijk(State.s["scoops"], 20, "twintig in huis")
	gelijk(State.s["levering"], 4, "over vier dagen levering")
	var dagen := []
	Hotel.dag_veranderd.connect(func(d): dagen.append(d))

	var verwacht := [
		# dag, scoops, levering, uitcheck, berichten
		[2, 16, 3, 0, []],
		[3, 12, 2, 0, []],
		[4, 24, 4, 1, ["voer: 24 🥄", "Boef gaat naar huis"]],
		[5, 20, 3, 2, ["Boef gaat naar huis"]],
		[6, 16, 2, 3, ["Boef gaat naar huis"]],
		[7, 24, 4, 3, ["voer: 24 🥄", "Boef gaat naar huis"]],
		[8, 20, 3, 3, ["Boef gaat naar huis"]],
	]
	for rij in verwacht:
		Hotel.morgen()
		gelijk(State.s["dag"], rij[0], "dag")
		gelijk(State.s["scoops"], rij[1], "dag %d: scoops" % rij[0])
		gelijk(State.s["levering"], rij[2], "dag %d: levering" % rij[0])
		gelijk((State.s["uitcheck"] as Array).size(), rij[3],
			"dag %d: uitcheck" % rij[0])
		var teksten := []
		for b in Hotel.dag_bericht():
			teksten.append(b["tekst"])
		gelijk(teksten, rij[4], "dag %d: dagbericht" % rij[0])
		gelijk(State.s["ronde"], "ochtend", "elke morgen begint als ochtendronde")
		gelijk(int(gasten[0]["geslapen"]), rij[0] - 1, "geslapen telt mee")
		for g in gasten:
			gelijk(g["gegeten"], false, "iedereen is nog niet gevoerd")
			gelijk(g["blij"], false, "en nog niet blij")
			gelijk(g["behoefte"], "eten", "met een bed wil je 's ochtends eten")
	gelijk(dagen, [2, 3, 4, 5, 6, 7, 8], "dag_veranderd bij elke morgen")

## Els brings ten scoops when there is not enough left for one day.
func test_morgen_els_brengt_bij() -> void:
	_voor()
	var gasten := _gasten(3)
	for g in gasten:
		g["scoops"] = 6                       # 18 per dag
	State.s["scoops"] = 20
	State.s["levering"] = 4
	Hotel.morgen()
	gelijk(State.s["scoops"], 12, "20 - 18 = 2, en Els bracht er 10 bij")
	var teksten := []
	for b in Hotel.dag_bericht():
		teksten.append(b["tekst"])
	gelijk(teksten, ["Els bracht 10 🥄"], "het berichtje van Els")

func test_morgen_zonder_bed_wil_een_kamer() -> void:
	_voor()
	var g: Dictionary = State.gasten_pool()[0]
	State.s["gasten"] = [g]
	Hotel.morgen()
	gelijk(g["behoefte"], "kamer", "zonder bed wil hij een bed")
	gelijk(int(g["geslapen"]), 0, "en heeft hij niet geslapen")

# -------------------------------------------------------------- de wensen

## world.md §3.2, worked example: three guests with a bed, both games there.
func test_nieuwe_wensen_dag_3_5_7() -> void:
	_voor()
	_meld("zwembad", {"naam": "Zwembad", "kamer": "zwembad", "wens": "zwemmen"})
	_meld("kraam", {"naam": "Souvenirkraam", "kamer": "tuin", "wens": ["souvenir"]})
	var gasten := _gasten(3)
	waar(Hotel.wens_mogelijk("zwemmen"), "zwemmen kan")
	waar(Hotel.wens_mogelijk("souvenir"), "souvenir kan")

	State.s["dag"] = 3
	gelijk(Hotel.nieuwe_wensen(false), {gasten[1]["id"]: "zwemmen"},
		"dag 3: gast 2 gaat zwemmen")
	State.s["dag"] = 5
	gelijk(Hotel.nieuwe_wensen(false), {gasten[2]["id"]: "zwemmen"},
		"dag 5: gast 3 gaat zwemmen")
	State.s["dag"] = 7
	gelijk(Hotel.nieuwe_wensen(false), {gasten[0]["id"]: "souvenir"},
		"dag 7: gast 1 wil een souvenir")
	State.s["dag"] = 4
	gelijk(Hotel.nieuwe_wensen(false), {}, "even dagen horen bij de tobbe")
	State.s["dag"] = 3
	gelijk(Hotel.nieuwe_wensen(true), {gasten[2]["id"]: "zwemmen"},
		"met een badbeurt slaat gast 1 over")
	_na()

## No game for it, no bubble for it: a child never sees a wish it cannot fulfil.
func test_geen_spel_geen_wens() -> void:
	_voor()
	_gasten(3)
	waar(not Hotel.wens_mogelijk("zwemmen"), "zonder zwembad geen 🏊")
	waar(not Hotel.wens_mogelijk("souvenir"), "zonder kraam geen 🎁")
	waar(not Hotel.bad_mogelijk(), "zonder tobbe geen 🛁")
	State.s["dag"] = 3
	gelijk(Hotel.nieuwe_wensen(false), {}, "en dus geen nieuwe wensen")
	# the hotel resolves these three itself, so they are always possible
	for t in ["kamer", "eten", "spelen"]:
		waar(Hotel.wens_mogelijk(t), "%s kan altijd" % t)
	# a placeholder does not count
	_meld("zwembad", {"naam": "Zwembad", "kamer": "zwembad", "wens": "zwemmen",
		"stub": true})
	waar(not Hotel.wens_mogelijk("zwemmen"), "een plaatshouder deelt geen wens uit")
	_na()

## A locked game hands out no wish either.
func test_op_slot_geen_wens() -> void:
	_voor()
	_gasten(1)
	_meld("zwembad", {"naam": "Zwembad", "kamer": "zwembad", "wens": "zwemmen",
		"unlock": func(n, _band): return n >= 3})
	waar(not Hotel.wens_mogelijk("zwemmen"), "op slot: geen 🏊")
	_gasten(3)
	waar(Hotel.wens_mogelijk("zwemmen"), "met drie gasten wel")
	_na()

func test_wens_af() -> void:
	_voor()
	var gasten := _gasten(2)
	gasten[0]["behoefte"] = "eten"
	gasten[1]["behoefte"] = "zwemmen"
	waar(Hotel.wens_af(str(gasten[0]["id"]), "eten"), "eten inlossen")
	gelijk(gasten[0]["gegeten"], true, "gegeten staat aan")
	waar(Hotel.wens_af(str(gasten[1]["id"]), "zwemmen"), "zwemmen inlossen")
	gelijk(gasten[1]["blij"], true, "blij staat aan")
	# no star: the game hands that out itself with ctx.taak_klaar
	gelijk(State.s["sterren"], 0, "wens_af geeft geen ster")
	# architecture.md §13 Q-X1-8: asking for 'kamer' is a programming error
	waar(not Hotel.wens_af(str(gasten[0]["id"]), "kamer"), "'kamer' -> false")
	waar(not Hotel.wens_af("bestaat-niet", "eten"), "onbekende gast -> false")

func test_behoefte_klaar() -> void:
	_voor()
	var g: Dictionary = State.gasten_pool()[0]
	g["behoefte"] = "kamer"
	waar(not Hotel.behoefte_klaar(g), "zonder bed niet klaar")
	g["bed"] = "bed1"
	waar(Hotel.behoefte_klaar(g), "met bed wel")
	g["behoefte"] = "eten"
	waar(not Hotel.behoefte_klaar(g), "nog niet gegeten")
	g["gegeten"] = true
	waar(Hotel.behoefte_klaar(g), "gegeten")
	g["behoefte"] = "spelen"
	waar(not Hotel.behoefte_klaar(g), "nog niet blij")
	g["blij"] = true
	waar(Hotel.behoefte_klaar(g), "blij")

# ------------------------------------------------------------- de check-in

func test_check_in_twee_vragen_dan_een_kamer() -> void:
	_voor()
	State.s["scoops"] = 20
	State.s["levering"] = 4
	var er_al := _gasten(1)                    # Boef eet 2 scheppen
	er_al[0]["behoefte"] = "eten"
	var nieuw: Dictionary = State.gasten_pool()[1]        # Muis eet 1 schep
	State.s["nieuweGast"] = nieuw
	Hotel.init_checkin(nieuw)
	var v: Dictionary = State.s["checkin"]
	gelijk(v["gastId"], "muis", "de gast aan de balie")
	gelijk(v["samen"], 2, "de gasten eten samen 2 scheppen")
	gelijk(v["extra"], 1, "Muis eet er 1 bij")
	gelijk(v["nieuw"], 3, "samen 3")
	gelijk(v["dagen"], 4, "vier dagen tot de levering")
	gelijk(v["voorraad"], 20, "twintig in huis")
	gelijk(v["stap"], 1, "vraag 1")
	gelijk(v["kamer"], "", "nog geen kamer")

	# vraag 1: fout mag, en kost niets — en er komt ook geen hulp bij
	# (eigenaar, 2026-09-24; zie de test hieronder)
	v["invoer"] = "5"
	Hotel.antwoord1()
	gelijk(v["stap"], 1, "fout: nog steeds vraag 1")
	gelijk(v["fouten1"], 1, "één misser")
	v["invoer"] = ""
	Hotel.antwoord1()
	gelijk(v["fouten1"], 1, "leeg invoeren is geen misser")
	v["invoer"] = "3"
	Hotel.antwoord1()
	gelijk(v["stap"], 2, "goed: vraag 2")

	# vraag 2: 4 dagen x 3 scheppen = 12, en er ligt 20 -> er blijft over
	gelijk(Sommen.vergelijk(4, 3, 20), "minder", "het bevroren vergelijk")
	Hotel.antwoord2("meer")
	gelijk(v["stap"], 2, "fout: nog steeds vraag 2")
	gelijk(v["fouten2"], 1, "één misser")
	Hotel.antwoord2("minder")
	gelijk(v["stap"], 3, "goed: nu een kamer, geen bed (eigenaar, 2026-09-24)")

	# de kamer.  Dit bestand meldt de echte spellen af, dus zonder beddenspel
	# krijgt hij meteen het vrije bed van die kamer: de check-in loopt nooit vast
	waar(State.kamers_met_plek().has("kamer2"), "kamer 2 heeft plek")
	waar(not Hotel.kies_kamer("zolder"), "een kamer die er niet is gaat niet")
	gelijk(v["stap"], 3, "en de vraag blijft")
	var sterren_voor := int(State.s["sterren"])
	State.s["ronde"] = "ochtend"
	waar(Hotel.kies_kamer("kamer2"), "kamer 2 gekozen")
	gelijk(State.s["checkin"], null, "de check-in is klaar")
	gelijk(State.s["nieuweGast"], null, "niemand meer aan de balie")
	gelijk((State.s["gasten"] as Array).size(), 2, "de gast slaapt nu in het hotel")
	gelijk(nieuw["kamer"], "kamer2", "zijn kamer")
	gelijk(nieuw["bed"], "bed1", "het vrije bed van die kamer")
	gelijk(nieuw["behoefte"], "eten", "en hij wil daarna eten")
	gelijk(int(State.s["sterren"]), sterren_voor + 1, "één ster voor het meedoen")
	gelijk(State.s["ronde"], "vrij", "ochtend wordt vrij spelen")

## "Nee geef geen hulp na fouten. Kinderen moeten zelf leren rekenen. Fout
## antwoord kiezen moet niet beloond worden met hulp maar juist een
## teleurgesteld dier" (owner, 2026-09-24).  A slip on either question writes
## nothing on the card — no spoon rows, no product — and toasts no answer: the
## guest at the desk goes `sip`, the strip is shut for a moment (`Ui.misser`)
## and the SAME question with the same choices stays up.
func test_een_misser_bij_het_inchecken_geeft_geen_hulp() -> void:
	_voor()
	var boom := Engine.get_main_loop() as SceneTree
	var laag := Control.new()
	laag.size = Vector2(1000, 648)
	boom.root.add_child(laag)
	Ui.registreer_lagen(laag, laag, laag, laag, laag)
	World.meet(Rect2(Vector2.ZERO, laag.size))
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	World.naar("receptie")
	Hotel.bel()
	var v = State.s["checkin"]
	waar(v != null, "er checkt iemand in")
	if v != null:
		var gid := str(v["gastId"])
		Hits.plaats()
		var knoppen := _strook("ci_som_keuzes")
		var mis := ""
		for k in knoppen:
			if k != "Kn%d" % int(v["nieuw"]):
				mis = k
		var kaart = Hits.spot("ci_som").knoop
		waar(_druk("ci_som_keuzes", mis), "een fout getal: %s" % mis)
		gelijk(int(v["stap"]), 1, "dezelfde vraag")
		gelijk(int(v["fouten1"]), 1, "één misser")
		waar(Hits.spot("ci_som").knoop == kaart, "dezelfde kaart blijft hangen")
		gelijk((kaart as UiSomkaart).hulp_label.text, "", "zonder lepeltjes-hulp")
		gelijk(str(_strook("ci_som_keuzes")), str(knoppen), "met dezelfde vier keuzes")
		waar(Ui.kaart_van("ci_som").pauze, "de strook is even op slot")
		gelijk(World.dier(gid).pose, "sip", "de gast is teleurgesteld")
		waar(Hits.spot("mis_ci_som") != null, "met zijn wolkje")
		waar(not _toast_tekst().contains("Tel ze samen"), "geen hulp-toast: %s" % _toast_tekst())
		# vraag 2
		Ui.kaart_van("ci_som").pauze = false
		v["invoer"] = str(int(v["nieuw"]))
		Hotel.antwoord1()
		Hits.plaats()
		var goed := Sommen.vergelijk(int(v["dagen"]), int(v["nieuw"]), int(v["voorraad"]))
		var fout2 := "meer" if goed != "meer" else "minder"
		var kaart2 = Hits.spot("ci_som").knoop
		waar(_druk("ci_som_keuzes", "K" + fout2), "een fout antwoord op vraag 2")
		gelijk(int(v["stap"]), 2, "dezelfde vraag")
		gelijk(int(v["fouten2"]), 1, "één misser")
		waar(Hits.spot("ci_som").knoop == kaart2, "dezelfde kaart")
		gelijk((kaart2 as UiSomkaart).som_label.text, "%d × %d" % [int(v["dagen"]), int(v["nieuw"])],
			"de som zonder het antwoord erachter")
		gelijk((kaart2 as UiSomkaart).hulp_label.text, "", "en zonder hulpregel")
		waar(Ui.kaart_van("ci_som").pauze, "de strook is even op slot")
		gelijk(World.dier(gid).pose, "sip", "de gast is weer teleurgesteld")
		waar(not _toast_tekst().contains("="), "geen toast met het antwoord: %s" % _toast_tekst())
		World.weg(gid)
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	laag.queue_free()
	Ui.zet_rust_modus(rust)
	await boom.process_frame

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

func _toast_tekst() -> String:
	var t = Ui._toast
	if t == null or not is_instance_valid(t):
		return ""
	for k in (t as Node).get_children():
		if k is Label:
			return (k as Label).text
	return ""

func test_bed_van_iemand_anders() -> void:
	_voor()
	var gasten := _gasten(1)
	gasten[0]["kamer"] = "kamer1"
	gasten[0]["bed"] = "bed1"
	var nieuw: Dictionary = State.gasten_pool()[1]
	State.s["nieuweGast"] = nieuw
	Hotel.init_checkin(nieuw)
	State.s["checkin"]["stap"] = 3
	waar(not Hotel.wijs_bed("kamer1", "bed1"), "een bezet bed gaat niet")
	waar(State.s["checkin"] != null, "de check-in loopt gewoon door")
	waar(Hotel.wijs_bed("kamer1", "bed2"), "een vrij bed wel")

## Every BED taken is not a full hotel any more: the check-in puts a new bed
## down, so the bell still brings a guest while some bedroom has floor for one
## (owner, 2026-09-24).  Every ROOM full: a friendly bubble at the bell, and no
## half check-in (world.md §3.3, first branch).
func test_bel_met_volle_kamers_maakt_geen_check_in() -> void:
	_voor()
	var bedden := State.alle_bedden()
	waar(bedden.size() >= 2, "het hotel heeft bedden (%d)" % bedden.size())
	_gasten(bedden.size())
	gelijk(State.bed_vrij(), {}, "geen bed meer vrij")
	waar(State.plek_voor_gast(), "maar de kamers hebben nog vloer voor een nieuw bed")
	Hotel.bel()
	waar(State.s["checkin"] != null, "dus de bel haalt toch een gast")
	State.s["checkin"] = null
	State.s["nieuweGast"] = null
	_hotel_vol()
	waar(not State.plek_voor_gast(), "elke kamer vol: geen plek meer")
	gelijk(State.kamers_met_plek().size(), 0, "geen kamer met plek")
	var wacht_voor := (State.s["wachtlijst"] as Array).size()
	Hotel.bel()
	gelijk(State.s["checkin"], null, "geen check-in zonder plek")
	gelijk(State.s["nieuweGast"], null, "en geen gast aan de balie")
	gelijk((State.s["wachtlijst"] as Array).size(), wacht_voor,
		"de wachtlijst blijft heel")
	gelijk(Hotel.BEL_VOL, "alle kamers vol", "wat de bel dan zegt")
	Rooms.herstel()

## The bell's card on the board follows the same rule: "Bel een gast" for the
## first guest, "Nog plek voor een gast" while a bedroom can take one more —
## also with every bed taken — and nothing at all when every room is full.
func test_belkaartje_volgt_de_plek_in_de_kamers() -> void:
	_voor()
	_bakken_vol()
	Hotel.bouw_taken(true)
	gelijk(_taak("bel").get("tekst", ""), "Bel een gast", "de eerste gast")
	_gasten(State.alle_bedden().size())
	State.s["taken"] = []
	Hotel.bouw_taken(true)
	gelijk(_taak("bel").get("tekst", ""), "Nog plek voor een gast",
		"elk bed bezet, maar er is vloer voor een nieuw")
	waar(Ui.keur_taak("bel", "Nog plek voor een gast"), "hooguit zes woorden")
	_hotel_vol()
	State.s["taken"] = []
	Hotel.bouw_taken(true)
	gelijk(_taak("bel"), {}, "een vol hotel: geen belkaartje")
	Rooms.herstel()

## With a free bed the bell really does fetch the next guest.
func test_bel_haalt_de_volgende_gast() -> void:
	_voor()
	waar(State.plek_voor_gast(), "er is plek voor een gast")
	Hotel.bel()
	var v = State.s["checkin"]
	waar(v != null, "er staat een check-in klaar")
	if v == null:
		return
	gelijk(v["gastId"], "boef", "de eerste van de wachtlijst")
	gelijk(v["stap"], 1, "bij vraag 1")
	gelijk(v["samen"], 0, "nog geen gasten, dus 0 scheppen")
	gelijk(v["extra"], 2, "Boef eet er 2 bij")
	waar(State.s["nieuweGast"] != null, "en hij staat aan de balie")
	gelijk((State.s["wachtlijst"] as Array).size(), 8, "eentje van de lijst af")
	# a second ring does not start a second check-in
	Hotel.bel()
	gelijk(State.s["checkin"]["gastId"], "boef", "er staat al iemand")
	gelijk((State.s["wachtlijst"] as Array).size(), 8, "en er komt niemand bij")

# --------------------------------------------------------- eten en spelen

func test_spelen_met_de_mand() -> void:
	_voor()
	var gasten := _gasten(2)
	for g in gasten:
		g["behoefte"] = "spelen"
	Hotel.bouw_taken(true)
	Hotel.tik_mand("kamer1")
	gelijk(gasten[0]["blij"], true, "de eerste speelt")
	gelijk(gasten[1]["blij"], true, "de tweede ook")
	gelijk(int(State.s["sterren"]), 1, "één ster voor het spelen")
	var kaart := _taak("spelen")
	if not kaart.is_empty():
		gelijk(kaart["klaar"], true, "het taakje staat afgevinkt")
	# nobody waiting any more
	var sterren := int(State.s["sterren"])
	Hotel.tik_mand("kamer1")
	gelijk(int(State.s["sterren"]), sterren, "niemand wacht: geen tweede ster")

func _taak(id: String) -> Dictionary:
	for q in State.s["taken"]:
		if str(q["id"]) == id:
			return q
	return {}

# -------------------------------------------------------------- prikbord

## The hotel's own cards come first and always in the same order.
func test_hotel_taken_op_volgorde() -> void:
	_voor()
	_bakken_vol()
	# a full hotel plus one guest without a bed: no `bel` card competes, and
	# the three that are left are the ones this test is about
	var gasten := _hotel_vol()
	var zonder := State.mk_gast("zonder", "Zonder", "hond", "puppy", 1, "Wandeling", 30)
	zonder["nachten"] = 100
	gasten.append(zonder)
	State.s["gasten"] = gasten
	gasten[0]["behoefte"] = "spelen"
	State.s["uitcheck"] = [str(gasten[0]["id"])]
	var taken := Hotel.bouw_taken(true)
	var ids := []
	for q in taken:
		ids.append(q["id"])
	gelijk(ids, ["bed", "uit", "spelen"], "eerst het bed, dan afrekenen, dan spelen")
	gelijk(_taak("bed").get("tekst", ""),
		"%s wil een bed" % gasten[gasten.size() - 1]["naam"], "de bedregel")
	gelijk(_taak("uit").get("tekst", ""), "Reken af: %s" % gasten[0]["naam"], "de afrekenregel")
	gelijk(_taak("spelen").get("tekst", ""), "%s wil spelen" % gasten[0]["naam"], "de speelregel")
	gelijk(Hotel.open_taken(), 3, "drie open taakjes")
	Rooms.herstel()

## An empty bowl in a room where guests sleep puts `Vul de voerkar` on the
## board, in front of every game chip (world.md §3.7).
func test_leeg_bakje_vraagt_om_de_voerkar() -> void:
	_voor()
	_gasten(1)
	_bakken_leeg()
	var taken := Hotel.bouw_taken(true)
	var ids := []
	for q in taken:
		ids.append(str(q["id"]))
	waar(ids.has("voer"), "het voerkaartje hangt er")
	gelijk(_taak("voer").get("tekst", ""), "Vul de voerkar", "de voerregel")
	gelijk(_taak("voer").get("kamer", ""), "keuken", "en het wijst naar de keuken")
	_bakken_vol()
	State.s["taken"] = []
	Hotel.bouw_taken(true)
	gelijk(_taak("voer"), {}, "een vol bakje haalt het kaartje weg")

func test_taak_af_op_id_en_op_spel_id() -> void:
	_voor()
	_bakken_vol()
	_meld("bedden", {"naam": "Bedden op rij", "kamer": "kamer1",
		"taak": {"id": "bedden", "icoon": "🛏", "tekst": "Zet de bedden op rij"}})
	Hotel.bouw_taken(true)
	var open_voor := Hotel.open_taken()
	waar(Hotel.taak_af("bedden"), "afvinken op taak-id")
	gelijk(_taak("bedden").get("klaar", false), true, "het vinkje staat")
	gelijk(Hotel.open_taken(), open_voor - 1, "er staat er eentje minder open")
	waar(not Hotel.taak_af("bestaat-niet"), "een onbekende id raakt niets")
	# and once more on the GAME id, which is what ctx.taak_klaar sends
	State.s["taken"] = []
	Hotel.bouw_taken(true)
	waar(Hotel.taak_af("bedden"), "afvinken op spel-id")
	gelijk(_taak("bedden").get("klaar", false), true, "ook dan staat het vinkje")
	_na()

## The fair rotation: `n` ordinary chips shift one place per day, so every one
## of them reaches the board within `n` days (architecture.md §13, Q-X3-14).
func test_prikbord_rotatie_over_zes_dagen() -> void:
	_voor()
	_bakken_vol()
	_hotel_vol()
	_meld("bedden", {"naam": "Bedden op rij", "kamer": "kamer1",
		"taak": {"id": "bedden", "icoon": "🛏", "tekst": "Zet de bedden op rij", "prio": 5}})
	_meld("hinkel", {"naam": "Hinkelpad", "kamer": "tuin",
		"taak": {"id": "hinkel", "icoon": "🪨", "tekst": "Hinkelen", "prio": 5}})
	_meld("sleutels", {"naam": "Het sleutelbord", "kamer": "receptie",
		"taak": {"id": "sleutels", "icoon": "🔑", "tekst": "Hang de sleutels op", "prio": 5}})
	_meld("was", {"naam": "Wasmandtoren", "kamer": "wasserij",
		"taak": {"id": "was", "icoon": "🧺", "tekst": "Was de handdoeken", "prio": 8}})

	var basis := []
	for q in Hotel.spel_taken():
		basis.append(str(q["id"]))
	waar(basis.size() >= 4, "er staan meer klusjes dan plekken (%d)" % basis.size())
	var n := basis.size()
	var gezien := {}
	for dag in range(1, 7):
		State.s["dag"] = dag
		State.s["taken"] = []
		var taken := Hotel.bouw_taken(true)
		var ids := []
		for q in taken:
			ids.append(str(q["id"]))
		var start := (dag - 1) % n
		var verwacht := (basis.slice(start) + basis.slice(0, start)).slice(0, 3)
		gelijk(ids, verwacht, "dag %d schuift één plaats door" % dag)
		gelijk(ids.size(), 3, "dag %d: hooguit drie kaartjes" % dag)
		for id in ids:
			gezien[id] = 1
	for id in basis:
		waar(gezien.has(id), "%s kwam binnen zes dagen aan de beurt" % id)
	Rooms.herstel()
	_na()

## A wish chip (prio 0..4) keeps its own place, in front of the ordinary ones.
func test_wenskaartjes_houden_hun_volgorde() -> void:
	_voor()
	_bakken_vol()
	_hotel_vol()
	State.s["gasten"][0]["behoefte"] = "bad"
	_meld("tobbe", {"naam": "Tobbe-tijd", "kamer": "tuin", "wens": "bad"})
	_meld("zwembad", {"naam": "Zwembad", "kamer": "zwembad", "wens": "zwemmen",
		"taak": {"id": "zwemles", "icoon": "🏊", "tekst": "Zwemles", "prio": 1}})
	_meld("was", {"naam": "Wasmandtoren", "kamer": "wasserij",
		"taak": {"id": "was", "icoon": "🧺", "tekst": "Was de handdoeken", "prio": 8}})
	for dag in range(1, 5):
		State.s["dag"] = dag
		State.s["taken"] = []
		var taken := Hotel.bouw_taken(true)
		var ids := []
		for q in taken:
			ids.append(str(q["id"]))
		gelijk(ids[0], "bad", "dag %d: de wens van het dier staat vooraan" % dag)
		gelijk(ids[1], "zwemles", "dag %d: daarna de zwemles" % dag)
		waar(ids.size() == 3, "dag %d: en er past nog één klusje bij" % dag)
	gelijk(_taak("bad").get("tekst", ""), "%s wil in bad" % State.s["gasten"][0]["naam"],
		"de tobbe leent de naam van de gast")
	Rooms.herstel()
	_na()

## A ticked card keeps its ✅ for the rest of the day, also when it is no
## longer needed; tomorrow the board starts empty.
func test_afgevinkt_kaartje_blijft_staan() -> void:
	_voor()
	_bakken_vol()
	var gasten := _gasten(1)
	gasten[0]["behoefte"] = "spelen"
	Hotel.bouw_taken(true)
	waar(not _taak("spelen").is_empty(), "het speelkaartje hangt er")
	Hotel.taak_af("spelen")
	gasten[0]["blij"] = true                  # het is niet meer nodig
	Hotel.bouw_taken(true)
	var q := _taak("spelen")
	waar(not q.is_empty(), "het kaartje verdwijnt niet ongemerkt")
	gelijk(q.get("klaar", false), true, "het staat er met een vinkje")
	Hotel.morgen()
	gelijk(_taak("spelen"), {}, "morgen begint het bord weer leeg")

func test_bord_open_en_dicht() -> void:
	_voor()
	var gemeld := [0]
	Hotel.bord_veranderd.connect(func(): gemeld[0] += 1)
	waar(not Hotel.bord_is_open(), "het bord begint dicht")
	Hotel.prikbord()
	waar(Hotel.bord_is_open(), "het prikbord staat open")
	waar(Hotel.bord_dicht(), "en gaat dicht")
	waar(not Hotel.bord_dicht(), "twee keer dicht doen doet niets")
	Hotel.prikbord_tik()
	waar(Hotel.bord_is_open(), "de knop opent hem")
	Hotel.prikbord_tik()
	waar(not Hotel.bord_is_open(), "en sluit hem weer")
	waar(gemeld[0] >= 4, "bord_veranderd meldt elke keer (%d)" % gemeld[0])

# ------------------------------------------------------------ de avondronde

func test_avondronde_en_afrekenen() -> void:
	_voor()
	var gasten := _gasten(1)
	var g: Dictionary = gasten[0]
	g["nachten"] = 2
	g["prijs"] = 5
	g["betaald"] = 10
	g["geslapen"] = 2
	State.s["uitcheck"] = [str(g["id"])]
	waar(Hotel.avond_klaar(), "er valt iets af te rekenen")
	Hotel.avondronde()
	gelijk(State.s["ronde"], "avond", "de avondronde loopt")

	Hotel.reken_af(str(g["id"]))
	waar(Econ.rekening_bezig(), "de rekening staat op de balie")
	var r := Econ.rekening_stand()
	gelijk(r["totaal"], 10, "2 x €5 = €10")
	gelijk(r["fam"], "Van Dijk", "de eerste familie")
	await Econ.som_ok(10)
	for i in 4:
		Econ.leg_neer()
	await Econ.klaar_met_tellen()

	gelijk(int(State.s["munten"]), 10, "tien munten in de kassa")
	gelijk(int(State.s["sterren"]), 1, "één ster voor de rekening")
	gelijk((State.s["brieven"] as Array).size(), 1, "en één brief")
	gelijk(State.s["brieven"][0]["titel"], "Bedankje van familie Van Dijk 💌",
		"de brief komt van dezelfde familie")
	gelijk((State.s["gasten"] as Array).size(), 0, "de gast is naar huis")
	gelijk((State.s["uitcheck"] as Array).size(), 0, "en van het uitchecklijstje af")
	waar(not Hotel.avond_klaar(), "er valt niets meer af te rekenen")

func test_avond_zonder_uitcheck() -> void:
	_voor()
	_gasten(1)
	waar(not Hotel.avond_klaar(), "niemand gaat naar huis")
	Hotel.avondronde()
	gelijk(State.s["ronde"], "avond", "de avondronde mag altijd")
	# architecture.md §13 Q-X1-9: with nobody to check out the lamp offers
	# the next day instead, so the two evening entrances agree
	var dag := int(State.s["dag"])
	Hotel.morgen()
	gelijk(int(State.s["dag"]), dag + 1, "🌙 Morgen ▸ brengt de volgende dag")

# ------------------------------------------------------------------ opslag

## world.md §1.8 / §4.2: a bought bed is still there after a reload — and it
## raises the guest cap, so losing it would silently shrink the hotel.
func test_gekocht_meubel_overleeft_een_herlaad() -> void:
	_voor()
	var bedden_voor := State.alle_bedden().size()
	var stuk := Rooms.meubel_zet("kamer1", "bed", 66.0, 60.0, 0)
	waar(not stuk.is_empty(), "het bed staat er")
	gelijk(State.alle_bedden().size(), bedden_voor + 1, "een bed erbij")
	# Rooms.kamers_veranderd wrote it into the save by itself
	gelijk((State.s["meubels"] as Array).size(), 1, "het staat in de opslag")
	waar(int(State.s["meubelNr"]) >= 1, "en de meubelteller schoof op")
	waar(State.bewaar(), "bewaar")

	State.s = State.standaard()
	waar(State.lees(), "lees")
	Hotel.herstel_inrichting()
	gelijk(State.alle_bedden().size(), bedden_voor + 1, "het bed is terug")
	gelijk((State.s["meubels"] as Array).size(), 1, "en staat nog in de opslag")
	gelijk(State.s["meubels"][0]["type"], "bed", "als bed")
	gelijk(State.s["meubels"][0]["kamer"], "kamer1", "in kamer 1")
	# a fresh game starts from the base layout again
	State.nieuw_spel()
	State.start_gekozen()
	Hotel.herstel_inrichting()
	gelijk(State.alle_bedden().size(), bedden_voor, "nieuw spel: het basishotel")

## The whole day survives a reload: round, board, wishes, messages.
func test_dag_overleeft_een_herlaad() -> void:
	_voor()
	var gasten := _gasten(2)
	gasten[0]["behoefte"] = "spelen"
	Hotel.bouw_taken(true)
	Hotel.taak_af("spelen")
	waar(State.bewaar(), "bewaar")
	var taken_voor := JSON.stringify(State.s["taken"])
	State.s = State.standaard()
	waar(State.lees(), "lees")
	gelijk(JSON.stringify(State.s["taken"]), taken_voor, "het bord komt terug")
	gelijk((State.s["gasten"] as Array).size(), 2, "de gasten ook")
	gelijk(State.s["gasten"][0]["behoefte"], "spelen", "met hun wens")
