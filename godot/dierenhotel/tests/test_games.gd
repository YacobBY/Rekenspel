extends Proef
## The minigame registry (architecture.md §6.1): a game is a DIRECTORY under
## `res://games/` with a `spel.tscn` in it, and the directory name is its id.
##
## That is what lets ten wave-2 workers run in parallel worktrees with zero
## merge conflicts: adding a game touches no shared file at all.  The scan must
## therefore keep working both in the editor tree and inside the exported PCK —
## the second half is proven by the browser probe, which prints `Games.lijst()`
## from the running wasm.

var _laag: Control = null

func _op() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = Vector2(1000, 648)
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	World.meet(Rect2(Vector2.ZERO, Vector2(1000, 648)))

func _af() -> void:
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	if _laag != null:
		_laag.queue_free()
		_laag = null

## The scan itself: every `res://games/*/spel.tscn` is found, without any shared
## registry file existing anywhere in the project.
func test_map_scan_vindt_elk_spel() -> void:
	var mappen := DirAccess.get_directories_at(Games.MAP)
	var verwacht: Array[String] = []
	for map in mappen:
		if not map.begins_with(".") and ResourceLoader.exists("%s/%s/spel.tscn" % [Games.MAP, map]):
			verwacht.append(map)
	verwacht.sort()
	waar(verwacht.size() >= 1, "er staat minstens één spel in res://games")
	gelijk(str(Games.lijst()), str(verwacht), "de scan vindt precies die mappen")
	waar(Games.lijst().has("_voorbeeld"), "het voorbeeldspel hoort erbij")
	# no shared registry file may have crept back in
	for pad in ["res://games/_lijst.json", "res://games/registry.gd", "res://games/lijst.gd"]:
		waar(not ResourceLoader.exists(pad) and not FileAccess.file_exists(pad),
			"geen gedeeld registerbestand (%s)" % pad)

## `definitie()` is read once, with the scene OUTSIDE the tree.
func test_definitie_wordt_gelezen() -> void:
	var def := Games.definitie("_voorbeeld")
	gelijk(def.get("naam", ""), "Voorbeeld", "definitie().naam")
	gelijk(def.get("kamer", ""), "gang", "definitie().kamer")
	gelijk(def.get("id", ""), "_voorbeeld", "de mapnaam IS het id")
	waar(def.has("hotspot"), "en er hangt een ingangsknop aan")
	gelijk(Games.definitie("bestaat-niet"), {}, "een onbekend spel geeft niets")

## `unlock(N, band)` decides whether a game may be played; absent means yes.
func test_ontgrendeling() -> void:
	waar(Games.ontgrendeld("_voorbeeld"), "het voorbeeld is altijd te spelen")
	waar(not Games.ontgrendeld("bestaat-niet"), "wat er niet is, is niet te spelen")

## An unknown game never leaves the child staring at a dead button: it toasts
## `💛 Probeer iets anders` and stays where it was (world.md §5.2 step 7).
func test_onbekend_spel_meldt_zich() -> void:
	_op()
	waar(not Games.start("bestaat-niet"), "start() van een onbekend spel is false")
	gelijk(Games.actief(), "", "en er draait niets")
	var t: Control = _laag.get_node_or_null("Toast")
	waar(t != null, "er staat een toast")
	if t != null:
		gelijk(t.get_node("Label").text if t.has_node("Label") else _eerste_label(t),
			UiTekst.SPEL_MIS, "en die zegt het woordelijk")
	_af()

func _eerste_label(k: Node) -> String:
	for kind in k.get_children():
		if kind is Label:
			return (kind as Label).text
		var diep := _eerste_label(kind)
		if not diep.is_empty():
			return diep
	return ""

## The entry button hangs ON its own object, covers 0 % of it, and disappears
## while its own game is running (world.md §5.1).
func test_ingangsknop_hangt_aan_zijn_voorwerp() -> void:
	_op()
	var def := Games.definitie("_voorbeeld")
	var kamer := str(def.get("kamer", ""))
	if not Rooms.bestaat(kamer):
		return                       # the placeholder room went with W1; nothing to hang on
	World.naar(kamer)
	World.meet(Rect2(Vector2.ZERO, Vector2(1000, 648)))
	# the sample game is a stub and hangs no button in the real hotel (owner,
	# 2026-09-14: "Doe het voorbeeld" on the board); for this test it is not
	def["stub"] = false
	Games.hersteek()
	Hits.plaats()
	var s := Hits.spot("spel__voorbeeld")
	waar(s != null, "de ingangsknop staat er")
	if s != null:
		gelijk(s.door, "registry", "de eigenaar is het register")
		# `op: aan` (owner, 2026-09-14): a big thing like the chest may carry
		# its button; a small one keeps it just above or below
		var d: Dictionary = Hits.debug()["spel__voorbeeld"]
		waar(Hits.dekking("spel__voorbeeld") <= 0.0 or str(d["op"]) == "aan",
			"de knop hangt aan zijn voorwerp (%s, %.1f %%)" % [d["op"], Hits.dekking("spel__voorbeeld")])
		var r: Rect2 = Hits.debug()["spel__voorbeeld"]["rect"]
		waar(r.size.x >= 48.0 and r.size.y >= 48.0, "en is een tikdoel")
	def["stub"] = true
	Games.hersteek()
	waar(Hits.spot("spel__voorbeeld") == null, "een stub hangt geen knop in het hotel")
	_af()

## One turn through the lifecycle: start stamps the owner and gives the game
## priority, stop wipes everything the game placed and hands the buttons back.
func test_levensloop_ruimt_alles_op() -> void:
	_op()
	var def := Games.definitie("_voorbeeld")
	if not Rooms.bestaat(str(def.get("kamer", ""))):
		_af()
		return
	# owner "keurmeester": anything but "hotel", whose own render() legitimately
	# rebuilds its buttons while the game starts
	Hits.maak({"id": "hotelknop", "kamer": World.kamer_nu(), "x": 8.0, "z": 8.0, "y": 10.0,
		"icoon": "🔔", "label": "Bel", "door": "keurmeester", "aan": func(_s) -> void: pass})
	waar(Games.start("_voorbeeld"), "het spel start")
	gelijk(Games.actief(), "_voorbeeld", "en is actief")
	gelijk(Hits.voorrang_van(), "_voorbeeld", "en heeft voorrang")
	var eigen := 0
	for id in Hits.lijst():
		if Hits.spot(id).door == "_voorbeeld":
			eigen += 1
	waar(eigen >= 1, "het spel plaatste eigen hotspots (%d)" % eigen)
	Games.stop()
	gelijk(Games.actief(), "", "na stop draait er niets meer")
	gelijk(Hits.voorrang_van(), "", "en niemand heeft voorrang")
	for id in Hits.lijst():
		waar(Hits.spot(id).door != "_voorbeeld", "geen hotspot van het spel bleef staan: %s" % id)
	waar(Hits.spot("hotelknop") != null, "de knop van een andere eigenaar bleef staan")
	gelijk(World.decor_lijst().filter(func(d): return d["door"] == "_voorbeeld").size(), 0,
		"en het losse decor van het spel is weg")
	_af()

## `ctx` stamps everything the game places, so "supersede = full stop" is free.
## The game bar (owner, 2026-09-18): while a game runs the room chips leave and
## `⬅ Terug` takes their row — the same place for every game, on every screen,
## the frame keeps its size, and a tap on it ends the game.
func test_de_spelbalk_neemt_de_rij_van_de_kamerbalk() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var bewaard := State.s.duplicate(true)
	var scherm_voor = Ui.get("_scherm")
	for maat in [Vector2i(1024, 768), Vector2i(360, 740), Vector2i(740, 360)]:
		var vp := SubViewport.new()
		vp.size = maat
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		boom.root.add_child(vp)
		var shell = load("res://scenes/main.tscn").instantiate()
		shell.set_meta("geen_start", true)
		vp.add_child(shell)
		State.nieuw_spel()
		State.start_gekozen()
		Hotel.start()
		for _f in 3:
			await boom.process_frame
		var kb: Control = shell.kamerbalk
		var kader: Control = shell.kader
		waar(kb.visible, "%s: zonder spel staat de kamerbalk er" % str(maat))
		var kader_voor := kader.get_global_rect()
		var rij_voor := kb.get_global_rect()
		waar(Games.start("_voorbeeld"), "%s: het voorbeeldspel start" % str(maat))
		for _f in 2:
			await boom.process_frame
		var balk: UiSpelbalk = shell.spelbalk
		waar(balk != null and balk.visible, "%s: de spelbalk staat er" % str(maat))
		waar(not kb.visible, "%s: en de kamerchips zijn weg" % str(maat))
		gelijk(kader.get_global_rect(), kader_voor, "%s: het kader is niet bewogen" % str(maat))
		var plek := balk.get_global_rect()
		gelijk(plek.position, rij_voor.position, "%s: de balk staat waar de kamerbalk stond" % str(maat))
		gelijk(balk.terug_knop.text, UiTekst.TERUG, "%s: met de terugknop, woordelijk" % str(maat))
		var knop := balk.terug_knop.get_global_rect()
		waar(knop.size.x >= 48.0 and knop.size.y >= 48.0, "%s: de terugknop is een vol tikdoel" % str(maat))
		waar(plek.encloses(knop), "%s: en staat binnen de balk" % str(maat))
		waar(balk.titel_label.text.contains("Voorbeeld"), "%s: de naam van het spel staat erbij" % str(maat))
		# a second game: the same place, to the pixel
		waar(Games.start("wekker"), "%s: een tweede spel start" % str(maat))
		for _f in 2:
			await boom.process_frame
		gelijk(Games.actief(), "wekker", "%s: en draait" % str(maat))
		gelijk(shell.spelbalk.terug_knop.get_global_rect().position, knop.position,
			"%s: de terugknop staat op dezelfde plek" % str(maat))
		# the tap: the game ends, the chips come back, the frame did not move
		shell.spelbalk.terug_knop.pressed.emit()
		for _f in 2:
			await boom.process_frame
		gelijk(Games.actief(), "", "%s: na Terug draait er niets meer" % str(maat))
		waar(not shell.spelbalk.visible, "%s: de spelbalk is weg" % str(maat))
		waar(kb.visible, "%s: de kamerchips zijn terug" % str(maat))
		gelijk(kader.get_global_rect(), kader_voor, "%s: en het kader staat nog steeds stil" % str(maat))
		Games.stop()
		Hits.wis_alles()
		vp.queue_free()
		await boom.process_frame
	Ui.registreer_lagen(null, null, null)
	Ui.vergeet_scherm()
	if scherm_voor != null:
		Ui.set("_scherm", scherm_voor)
	State.s = bewaard

func test_ctx_stempelt_de_eigenaar() -> void:
	_op()
	var ctx := SpelCtx.new("proefspel", {"naam": "Proef", "kamer": World.kamer_nu()})
	gelijk(ctx.id, "proefspel", "ctx.id")
	gelijk(ctx.naam, "Proef", "ctx.naam")
	ctx.hotspots.maak({"id": "ps1", "kamer": World.kamer_nu(), "x": 8.0, "z": 8.0,
		"y": 10.0, "icoon": "🐾", "label": "Kijk"})
	ctx.ui.wolk({"id": "ps2", "kamer": World.kamer_nu(), "x": 8.0, "z": 8.0,
		"hoog": 20.0, "icoon": "💤", "tekst": "slaapt"})
	ctx.ui.getal_tag({"x": 8.0, "z": 8.0}, 3, {"id": "ps3"})
	for id in ["ps1", "ps2", "ps3"]:
		var s := Hits.spot(id)
		waar(s != null and s.door == "proefspel", "%s draagt de stempel van het spel" % id)
	ctx.hotspots.wis_alles()
	for id in ["ps1", "ps2", "ps3"]:
		waar(Hits.spot(id) == null, "%s is weg na wis_alles()" % id)
	_af()

## Every game whose entry hangs on a resting prop (`hotspot.rust`) leaves that
## prop standing while no game runs, the entry hangs ON it, it goes the moment
## any game starts and comes back when it stops (owner, 2026-09-23: "Dan hangt
## elk spel aan iets wat je echt ziet").  The wekker's clock and the bedden
## blanket chest joined the stones, the stall and the pile of washing: before
## them "⏰ Wekker" hung on the paw poster and "🛏 Bedden" on the play basket,
## next to that basket's own "Speelmand".
func test_elk_spel_hangt_aan_zijn_eigen_rustspul() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	_op()
	State.nieuw_spel()
	for i in 5:
		(State.s["gasten"] as Array).append({"id": "rg%d" % i, "naam": "Rust%d" % i,
			"kind": "hond", "soort": "puppy", "scoops": 1, "kamer": "kamer1",
			"bed": "bed1" if i == 0 else "", "behoefte": "eten"})
	var met_rust: Array[String] = []
	for id in Games.lijst():
		var def := Games.definitie(id)
		var hs: Dictionary = def.get("hotspot", {})
		if str(hs.get("rust", "")).is_empty():
			continue
		met_rust.append(id)
	for moet in ["hinkel", "kraam", "was", "wekker"]:
		waar(met_rust.has(moet), "%s hangt aan een rustspul" % moet)
	# bedden has no entry any more: it is step 4 of the check-in (2026-09-24),
	# so the blanket chest it hung on in kamer 1 went with it
	waar(not met_rust.has("bedden"), "bedden heeft geen ingang en dus geen rustspul")
	Games.hersteek()
	for id in met_rust:
		var def := Games.definitie(id)
		var sid := str((def["hotspot"] as Dictionary)["rust"])
		var kamer := str(def.get("kamer", ""))
		if not Games.ontgrendeld(id):
			continue
		waar(not World.decor_plek(sid, kamer).is_empty(),
			"%s: %s staat in %s zolang er niet gespeeld wordt" % [id, sid, kamer])
		var eigen := false
		for stuk in (def.get("rust", []) as Array):
			if str((stuk as Dictionary).get("id", "")) == sid:
				eigen = true
		waar(eigen, "%s: het ding waar de ingang aan hangt is een van zijn eigen rustspullen" % id)
	# a game starts: every resting prop goes, the game's own things come
	waar(Games.start("wekker"), "de wekker start")
	for id in met_rust:
		var def := Games.definitie(id)
		for stuk in (def.get("rust", []) as Array):
			var sid := str((stuk as Dictionary).get("id", ""))
			waar(World.decor_plek(sid, str(def.get("kamer", ""))).is_empty(),
				"%s: %s is weg zolang er een spel loopt" % [id, sid])
	Games.stop()
	waar(not World.decor_plek("rust_wk_klok", "gang").is_empty(),
		"na het spel hangt de klok weer in de gang")
	State.s = bewaard
	Games.hersteek()
	_af()

## `kan` (world.md §5.1): a game with nothing to do right now has no entry and no
## task card — tapping it only said "vol ✓", "Alle bakjes vol!" or "Nog geen
## munten" (owner, 2026-09-23: "you can't execute them ... visual clutter").
func test_een_spel_zonder_iets_te_doen_heeft_geen_knop() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	_op()
	State.nieuw_spel()
	for i in 3:
		(State.s["gasten"] as Array).append({"id": "kn%d" % i, "naam": "Kn%d" % i,
			"kind": "hond", "soort": "puppy", "scoops": 1, "kamer": "kamer1",
			"bed": "bed%d" % (1 + i % 2), "behoefte": "eten"})
	# the voerkar: with every bowl full it has nothing to deliver
	for b in Hotel.alle_bakken():
		World.zet_bak(str(b["kamer"]), str(b["slot"]), 3)
	waar(not Games.speelbaar_nu("voerkar"), "voerkar: alle bakjes vol, niets te doen")
	World.zet_bak("kamer1", "bak", 0)
	waar(Games.speelbaar_nu("voerkar"), "voerkar: een leeg bakje, wel iets te doen")
	# the meubelboek: no coins and no stars, nothing to buy
	State.s["munten"] = 0
	State.s["sterren"] = 0
	waar(not Games.speelbaar_nu("meubels"), "meubels: zonder munten en sterren niets te kopen")
	State.s["munten"] = 2
	waar(Games.speelbaar_nu("meubels"), "meubels: met munten wel")
	# bedden (2026-09-24): step 4 of the check-in, so only something to do while
	# a check-in stands at its beds — and even then no entry and no card
	waar(not Games.speelbaar_nu("bedden"), "bedden: zonder check-in niets te doen")
	State.s["checkin"] = {"gastId": "kn9", "stap": 3, "kamer": ""}
	waar(not Games.speelbaar_nu("bedden"), "bedden: bij de kamervraag nog niet")
	State.s["checkin"] = {"gastId": "kn9", "stap": 4, "kamer": "kamer1"}
	waar(Games.speelbaar_nu("bedden"), "bedden: bij zijn bedden wel")
	var kaarten := []
	for q in Hotel.spel_taken():
		kaarten.append(str(q["spel"]))
	waar(not kaarten.has("bedden"), "maar nooit een taakkaartje: het begint aan de balie")
	State.s["checkin"] = null
	# and the task card goes with the entry
	State.s["munten"] = 0
	kaarten = []
	for q in Hotel.spel_taken():
		kaarten.append(str(q["spel"]))
	waar(not kaarten.has("meubels"), "geen taakkaartje voor een spel zonder iets te doen")
	State.s = bewaard
	_af()

# ------------------------------------------------------ het dier van de beurt

## `n` guests from the pool, the first `met_bed` of them with a bed of their
## own, all of them standing at the desk: Boef, Muis, Wolkje, …
func _gasten_van_de_pool(n: int, met_bed: int) -> Array:
	var pool := State.gasten_pool()
	var bedden := State.alle_bedden()
	var uit: Array = []
	for i in n:
		var g: Dictionary = pool[i].duplicate(true)
		if i < met_bed:
			var bed: Dictionary = bedden[i % bedden.size()]
			g["kamer"] = str(bed["kamer"])
			g["bed"] = str(bed["slot"])
		g["waar"] = "receptie"
		g["behoefte"] = "eten"
		g["nachten"] = 100
		uit.append(g)
	State.s["gasten"] = uit
	State.herbereken()
	for i in uit.size():
		World.zet(str(uit[i]["id"]), "receptie", 40.0 + i * 8.0, 60.0,
			{"naam": str(uit[i]["naam"]), "kind": str(uit[i]["kind"]), "nr": i})
	return uit

func _ids(gasten: Array) -> Array[String]:
	var uit: Array[String] = []
	for g in gasten:
		uit.append(str((g as Dictionary)["id"]))
	return uit

## "Een methode om te wisselen met welk dier je de spellen speelt" (owner,
## 2026-09-23), the registry half: the running game names its animal of the
## turn and who else may take it; the switch goes round in that stable order,
## is remembered for the session, and starts the game afresh with the next
## animal.  A game without an animal of the turn, or with one animal only,
## offers nothing to switch to.
func test_het_dier_van_de_beurt_gaat_rond() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	_op()
	var rust_voor := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	State.nieuw_spel()
	State.s["taken"] = []
	var gasten := _gasten_van_de_pool(4, 3)
	var ids := _ids(gasten)
	# the sample game has no animal of the turn
	waar(Games.start("_voorbeeld"), "het voorbeeld start")
	gelijk(Games.speler(), "", "het voorbeeld heeft geen dier van de beurt")
	gelijk(Games.spelers().size(), 0, "en niemand om mee te wisselen")
	waar(not Games.kan_wisselen(), "dus valt er niets te wisselen")
	waar(not Games.wissel_speler(), "en een wissel doet niets")
	gelijk(Games.actief(), "_voorbeeld", "het voorbeeld draait gewoon door")
	# the pool: everybody with a bed may swim, in check-in order
	waar(Games.start("zwembad"), "het zwembad start")
	gelijk(str(Games.spelers()), str(ids.slice(0, 3)), "wie mag zwemmen: de drie met een bed, op volgorde")
	gelijk(Games.speler(), ids[0], "het spel kiest zelf, zoals altijd: Boef")
	gelijk(Games.volgende_speler(), ids[1], "na Boef komt Muis")
	waar(Games.wissel_speler(), "de wissel lukt")
	gelijk(Games.actief(), "zwembad", "het zwembad draait nog")
	gelijk(Games.speler(), ids[1], "Muis zwemt nu")
	gelijk(str(State.s.get("speler", "")), ids[1], "en dat onthoudt het hotel")
	gelijk(str(State.spel_data("zwembad").get("gast", "")), ids[1], "een beurt voor Muis")
	gelijk(int(State.spel_data("zwembad").get("p", -1)), 0, "die vooraan begint")
	waar(Games.wissel_speler(), "nog een keer")
	gelijk(Games.speler(), ids[2], "Wolkje")
	waar(Games.wissel_speler(), "en nog een keer")
	gelijk(Games.speler(), ids[0], "en weer rond naar Boef — de gast zonder bed zwemt niet")
	Games.stop()
	gelijk(Games.speler(), "", "zonder spel speelt er niemand")
	# the pick stays for the session: the next start prefers that animal
	State.s["speler"] = ids[2]
	waar(Games.start("zwembad"), "het zwembad start opnieuw")
	gelijk(Games.speler(), ids[2], "met het dier dat het kind koos")
	Games.stop()
	# ... as long as it may take part; otherwise the game chooses itself.  Since
	# 2026-09-23 every turn brings its swimmer to the pool BEFORE the question
	# (`ctx.wacht_op`, owner: "Zorg dat de minigame pas begint wanneer het dier
	# er is"), so the three who swam above now stand at the water and the game's
	# own rule 2 ("who is here, nearest the start edge") would pick one of them.
	# Back to the desk with everybody, as at the top of this test: then its own
	# choice is rule 3, the first guest with a bed.
	for i in gasten.size():
		World.zet(ids[i], "receptie", 40.0 + i * 8.0, 60.0)
	State.s["speler"] = ids[3]
	(State.s["spel"] as Dictionary).erase("zwembad")
	waar(Games.start("zwembad"), "het zwembad start met een keuze zonder bed")
	gelijk(Games.speler(), ids[0], "wie niet mee mag doen, zwemt niet: het spel kiest zelf")
	Games.stop()
	# one animal that may swim: nothing to switch to, so no button either
	for g in gasten.slice(1):
		(g as Dictionary)["bed"] = ""
	State.s.erase("speler")
	(State.s["spel"] as Dictionary).erase("zwembad")
	waar(Games.start("zwembad"), "het zwembad start met één gast met een bed")
	gelijk(Games.speler(), ids[0], "Boef zwemt")
	waar(not Games.kan_wisselen(), "en er is niemand om mee te wisselen")
	waar(not Games.wissel_speler(), "dus doet een wissel niets")
	gelijk(str(State.s.get("speler", "")), "", "en er wordt niets onthouden")
	Games.stop()
	for d in World.dieren():
		World.weg(d.id)
	Ui.zet_rust_modus(rust_voor)
	State.s = bewaard
	Games.hersteek()
	_af()

## The game bar half, in the real shell, on the owner's screen (1536 x 760),
## the tablet, the phone and the low landscape phone (its rail): the animal
## stands beside the game's name as one full tap target inside the bar, the
## frame does not move by it, a tap hands the turn to the next animal, and a
## game without an animal of the turn shows no such button.
func test_de_spelbalk_wisselt_van_dier() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var bewaard: Dictionary = State.s.duplicate(true)
	var scherm_voor = Ui.get("_scherm")
	var rust_voor := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	for maat in [Vector2i(1536, 760), Vector2i(1024, 768), Vector2i(360, 740), Vector2i(740, 360)]:
		var vp := SubViewport.new()
		vp.size = maat
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		boom.root.add_child(vp)
		var shell = load("res://scenes/main.tscn").instantiate()
		shell.set_meta("geen_start", true)
		vp.add_child(shell)
		State.nieuw_spel()
		State.start_gekozen()
		State.s["taken"] = []
		var ids := _ids(_gasten_van_de_pool(3, 3))
		Hotel.start()
		for _f in 3:
			await boom.process_frame
		var kader: Control = shell.kader
		var kader_voor := kader.get_global_rect()
		waar(Games.start("_voorbeeld"), "%s: het voorbeeld start" % str(maat))
		for _f in 2:
			await boom.process_frame
		var balk: UiSpelbalk = shell.spelbalk
		waar(balk.speler_knop != null and not balk.speler_knop.visible,
			"%s: zonder dier van de beurt geen dierknop" % str(maat))
		waar(Games.start("zwembad"), "%s: het zwembad start" % str(maat))
		for _f in 2:
			await boom.process_frame
		balk = shell.spelbalk
		var knop: Button = balk.speler_knop
		waar(knop != null and knop.visible, "%s: het dier staat op de balk" % str(maat))
		if knop == null or not knop.visible:
			Games.stop()
			vp.queue_free()
			await boom.process_frame
			continue
		var rail := (balk.get_child(0) is VBoxContainer)
		gelijk(knop.text, UiTekst.speler_knop("🐶", "Boef", rail),
			"%s: pictogram, naam en 🔄, woordelijk" % str(maat))
		waar(Ui.mist_tekens(knop.text).is_empty(), "%s: zonder tofu" % str(maat))
		gelijk(kader.get_global_rect(), kader_voor, "%s: het kader is niet bewogen" % str(maat))
		var r := knop.get_global_rect()
		waar(r.size.x >= 48.0 and r.size.y >= 48.0, "%s: een vol tikdoel (%s)" % [str(maat), str(r.size)])
		waar(balk.get_global_rect().encloses(r), "%s: binnen de balk" % str(maat))
		waar(not r.intersects(balk.terug_knop.get_global_rect()), "%s: naast Terug, niet erop" % str(maat))
		waar(Rect2(Vector2.ZERO, Vector2(maat)).encloses(r), "%s: en op het scherm" % str(maat))
		# the tap: the next animal swims, in a fresh turn, and the frame stays put
		knop.pressed.emit()
		for _f in 3:
			await boom.process_frame
		gelijk(Games.actief(), "zwembad", "%s: het zwembad draait nog" % str(maat))
		gelijk(Games.speler(), ids[1], "%s: nu zwemt Muis" % str(maat))
		gelijk(str(State.spel_data("zwembad").get("gast", "")), ids[1], "%s: in een eigen beurt" % str(maat))
		knop = shell.spelbalk.speler_knop
		waar(knop.visible and knop.text.contains("Muis") and knop.text.contains("🐱"),
			"%s: en de balk zegt het: %s" % [str(maat), knop.text])
		gelijk(kader.get_global_rect(), kader_voor, "%s: het kader staat nog steeds stil" % str(maat))
		# ⬅ Terug still ends the game
		shell.spelbalk.terug_knop.pressed.emit()
		for _f in 2:
			await boom.process_frame
		gelijk(Games.actief(), "", "%s: na Terug draait er niets meer" % str(maat))
		Games.stop()
		Hits.wis_alles()
		for d in World.dieren():
			World.weg(d.id)
		vp.queue_free()
		await boom.process_frame
	Ui.zet_rust_modus(rust_voor)
	Ui.registreer_lagen(null, null, null)
	Ui.vergeet_scherm()
	if scherm_voor != null:
		Ui.set("_scherm", scherm_voor)
	State.s = bewaard

## `ctx.laat_gaan`: the animal whose unfinished turn a pick dropped makes room
## for the new one, and a switch never wakes anybody.  With real walking (no
## reduced motion), because "still on his way" only exists while walking.
func test_wie_zijn_beurt_niet_afmaakt_maakt_plaats() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	_op()
	var rust_voor := Ui.rust_modus()
	Ui.zet_rust_modus(false)
	State.nieuw_spel()
	var gasten := _gasten_van_de_pool(4, 4)
	var ctx := SpelCtx.new("proefspel", {"naam": "Proef", "kamer": "tuin"})
	# Boef was still on his way to the garden: he turns back to his own bed
	World.reis("boef", "tuin", {"x": 110.0, "z": 60.0, "na": "wacht"})
	waar(World.onderweg_naar("tuin").has("boef"), "Boef is op weg naar de tuin")
	ctx.laat_gaan("boef")
	waar(not World.onderweg_naar("tuin").has("boef"), "Boef komt niet meer naar de tuin")
	gelijk(str(World.dier("boef").reis_doel), str(gasten[0]["kamer"]), "hij gaat terug naar zijn kamer")
	gelijk(str(gasten[0]["waar"]), str(gasten[0]["kamer"]), "en daar hoort hij nu")
	# Muis sleeps: nobody is woken by a switch
	World.zet("muis", str(gasten[1]["kamer"]))
	World.slaap("muis", str(gasten[1]["kamer"]), str(gasten[1]["bed"]))
	waar(World.slaapt("muis"), "Muis slaapt")
	ctx.laat_gaan("muis")
	waar(World.slaapt("muis"), "en slaapt door")
	# Wolkje stands in the garden where the new one is heading: he walks off
	World.zet("wolkje", "tuin", 112.0, 60.0)
	ctx.laat_gaan("wolkje")
	var wolkje = World.dier("wolkje")
	waar(wolkje.staat == "loop" and not wolkje.punten.is_empty(), "Wolkje loopt weg")
	# Gerrit was sent somewhere else already (a stop sends him to bed): left alone
	World.reis("gerrit", "keuken", {"na": "wacht"})
	ctx.laat_gaan("gerrit")
	gelijk(str(World.dier("gerrit").reis_doel), "keuken", "Gerrit gaat gewoon waar hij heen ging")
	for d in World.dieren():
		World.weg(d.id)
	Ui.zet_rust_modus(rust_voor)
	State.s = bewaard
	_af()
