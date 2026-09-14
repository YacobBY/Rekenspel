extends Proef
## Tobbe-tijd (games-a.md §6) — headless suite, written by the lead after the
## worker was stopped before its tests: registration, the recipe per band from
## `Sommen.Tobbe`, one whole turn, a miss that never punishes, the reload from
## `ctx.data()`, a clean `stop()`, the §6.6 strings, and coverage on four
## frames.

const ID := "tobbe"
const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740),
	Vector2i(740, 360)]

var _laag: Control = null

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
	World.naar("tuin")
	World.meet(Rect2(Vector2.ZERO, kader))

func _af() -> void:
	if Games.actief() != "":
		Games.stop()
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	if _laag != null:
		_laag.queue_free()
		_laag = null

## `n` guests in real beds, on day `dag`, with `kunnen` bands unlocked.
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
	return uit

func _spel():
	return Games._knoop

# ------------------------------------------------------------ 1. aanmelding

func test_aanmelding_en_definitie() -> void:
	waar(Games.lijst().has(ID), "tobbe staat in het register")
	var d := Games.definitie(ID)
	gelijk(str(d["naam"]), "Tobbe-tijd", "naam")
	gelijk(str(d["kamer"]), "tuin", "kamer")
	gelijk(str(d["wens"]), "bad", "de wens 🛁 hoort bij dit spel")
	gelijk(str(d["hotspot"]["obj"]), "tobbe", "de knop hangt op de tobbe")
	gelijk(str(d["hotspot"]["icoon"]), "🛁", "met het badje als pictogram")
	waar(bool(d["unlock"].call(1, 3)), "vanaf één gast")
	waar(not bool(d["unlock"].call(0, 3)), "zonder gasten niet")

# ------------------------------------------------------- 2. recept per band

## The stand comes straight from the frozen `Sommen.Tobbe.recept`, for every
## band and for two guest counts.
func test_recept_komt_uit_de_bevroren_kern() -> void:
	for kunnen in [2, 3, 4]:
		for n in [1, 3]:
			_op()
			_gasten(n, 2, kunnen)
			waar(Games.start(ID), "het spel start (%d gasten, kunnen %d)" % [n, kunnen])
			var spel = _spel()
			if spel == null:
				_af()
				continue
			var s: Dictionary = spel.stand()
			var r := Sommen.Tobbe.recept(n, State.band(), 2)
			gelijk(int(s["T"]), int(r["T"]), "T uit het recept")
			gelijk(int(s["M"]), int(r["M"]), "M uit het recept")
			gelijk(int(s["per"]), int(r["per"]), "per uit het recept")
			gelijk(int(s["rest"]), int(r["rest"]), "rest uit het recept")
			gelijk(str(s["soort"]), str(r["soort"]), "soort uit het recept")
			gelijk(int(s["per"]) * int(s["M"]) + int(s["rest"]), int(s["T"]),
				"per × M + rest = T")
			waar(int(s["M"]) >= 2, "minstens twee tobbes")
			_af()

# ----------------------------------------------------------- 3. een beurt

## Everything on the rack goes into the tubs, the rest into the can: the check
## passes, the guests may bathe, and the turn is saved as done in progress.
func test_eerlijk_verdelen_slaagt() -> void:
	_op()
	_gasten(3, 1, 3)
	waar(Games.start(ID), "het spel start")
	var spel = _spel()
	if spel == null:
		_af()
		return
	var s: Dictionary = spel._s
	if str(s["soort"]) != "eerlijk":
		# the recipe of this day is a question card, not the filling step
		_af()
		return
	gelijk(str(s["stap"]), "vullen", "eerst vullen")
	for i in int(s["M"]):
		s["tob"][i] = int(s["per"])
	s["rek"] = 0
	s["kan"] = int(s["rest"])
	spel._check()
	gelijk(str(spel._s["stap"]), "baden", "na een goede verdeling mag iedereen in bad")
	gelijk(int(spel._s["missers"]), 0, "zonder misser")
	var d := State.spel_data(ID)
	gelijk(str(d["stand"]["stap"]), "baden", "en dat staat in de savegame")
	_af()

## A miss costs nothing: the turn goes on, the star count does not move.
func test_misser_helpt_en_straft_nooit() -> void:
	_op()
	_gasten(2, 1, 3)
	waar(Games.start(ID), "het spel start")
	var spel = _spel()
	if spel == null:
		_af()
		return
	var s: Dictionary = spel._s
	if str(s["soort"]) != "eerlijk":
		_af()
		return
	var sterren := int(State.s["sterren"])
	spel._check()                                  # nothing moved yet: the rack is full
	gelijk(int(spel._s["missers"]), 1, "één misser geteld")
	gelijk(str(spel._s["stap"]), "vullen", "de beurt loopt door")
	gelijk(int(State.s["sterren"]), sterren, "geen ster erbij of eraf")
	waar(not spel._s["zeg"].is_empty(), "het spel zegt wat er nog moet")
	_af()

# --------------------------------------------------------- 4. herlaad, stop

func test_beurt_overleeft_een_herlaad() -> void:
	_op()
	_gasten(3, 4, 3)
	waar(Games.start(ID), "het spel start")
	var spel = _spel()
	if spel == null:
		_af()
		return
	var voor: Dictionary = spel.stand()
	if str(voor["soort"]) == "eerlijk":
		spel._s["tob"][0] = 1
		spel._s["rek"] = int(spel._s["rek"]) - 1
		spel._bewaar()
	Games.stop()
	waar(Games.start(ID), "opnieuw starten")
	var na: Dictionary = _spel().stand()
	gelijk(int(na["T"]), int(voor["T"]), "dezelfde T")
	gelijk(int(na["M"]), int(voor["M"]), "dezelfde M")
	if str(voor["soort"]) == "eerlijk":
		gelijk(int(na["tob"][0]), 1, "het schepje in tobbe 1 is er nog")
	_af()

func test_stop_laat_de_wereld_schoon_achter() -> void:
	_op()
	_gasten(2, 1, 3)
	waar(Games.start(ID), "het spel start")
	Games.stop()
	gelijk(Games.actief(), "", "geen spel actief")
	var los := 0
	for d in World.decor_lijst("tuin"):
		if str((d as Dictionary).get("eigenaar", "")) == ID:
			los += 1
	gelijk(los, 0, "geen los decor van tobbe meer in de tuin")
	for id in Hits.debug().keys():
		waar(not str(id).begins_with("tb_"), "geen knop van tobbe meer: %s" % str(id))
	_af()

# --------------------------------------------------------------- 5. teksten

## Every §6.6 literal is in the source, verbatim.
func test_alle_teksten_staan_er_woordelijk() -> void:
	var f := FileAccess.open("res://games/tobbe/spel.gd", FileAccess.READ)
	waar(f != null, "de bron is leesbaar")
	if f == null:
		return
	var bron := f.get_as_text()
	for zin in ["nog geen gasten", "geen plek", "Verdeel het eerlijk", "Zo is het goed!",
			"zo is het goed", "klaar met badderen", "buurvrouw Els doet het voor",
			"opnieuw beginnen", "morgen dubbel", "Hoeveel samen?", "in twee helften",
			"Hoeveel in elke helft?", "rek is leeg", "blijft over", "is oneven",
			"eerst sop erin", "te vol", "nog op het rek", "even hoog", "hoort hierin",
			"erbij", "ieder evenveel", "zoveel hoort erin", "zoveel blijft over",
			"wil in bad", "zit vol", "lekker warm", "mag in de tobbe",
			"mogen in de tobbe", "blinkend schoon"]:
		waar(bron.contains(zin), "letterlijk in de bron: %s" % zin)

# --------------------------------------------------------------- 6. dekking

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
	Hotel.naar_kamer("tuin")
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
	Ui.registreer_lagen(null, null, null)
	Ui.vergeet_scherm()
	(h["vp"] as SubViewport).queue_free()
	for _f in 2:
		await boom.process_frame

## No button of the game covers an object, and no two elements overlap, on
## four frames — the §12.2 definition of done.
func test_dekking_in_vier_kaders() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	for maat in SCHERMEN:
		var h: Dictionary = await _schil_op(maat)
		var kader: Vector2 = h["kader"]
		gelijk(Games.actief(), ID, "het spel draait bij %s" % str(maat))
		var dbg := Hits.debug()
		var eigen := 0
		var ids: Array = dbg.keys()
		for id in ids:
			if str(id).begins_with("tb_"):
				eigen += 1
			var a: Dictionary = dbg[id]
			var r: Rect2 = a["rect"]
			waar(r.position.x >= -0.01 and r.position.y >= -0.01
				and r.end.x <= kader.x + 0.01 and r.end.y <= kader.y + 0.01,
				"%s: %s binnen het kader (%s)" % [str(maat), id, str(r)])
			if int(a["laag"]) != Hits.Laag.VAST:
				var spot := Hits.spot(str(id))
				var wolk := spot != null and (spot.kind == "wolk" or spot.kind == "tag")
				# a speech cloud or number tag may sit on a tenth of its own thing
				# (Hits.TAG_IN); a button never
				waar(str(a.get("op", "")) == "aan"
					or Hits.dekking(str(id)) <= (Hits.TAG_IN * 100.0 + 0.01 if wolk else 0.0),   # dekking is a percentage
					"%s: %s dekt zijn voorwerp niet (%.2f)" % [str(maat), id, Hits.dekking(str(id))])
		waar(eigen >= 3, "%s: het spel staat op het scherm (%d knoppen)" % [str(maat), eigen])
		await _schil_af(h)
	State.s = bewaard
