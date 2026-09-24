extends Proef
## G3 — het hinkelpad, headless (architecture.md §12.2, §2.4).
##
## The turn is driven the way a child drives it: through `ctx`, the registry and
## the CHOICE STRIP — `Hits.spot("hk_som_keuzes")` holds a real `UiKeuzes` and
## the test presses its buttons.  Nothing in here calls a play method of the
## game directly; the `proef_*` hooks only READ the turn and the measurements
## that are invisible from outside.

## The world frames the four ticket viewports produce (1024x768, 768x1024,
## 360x740, 740x360), as `tests/test_ui.gd::test_shell_op_vijf_schermen` prints
## them and `tests/test_hits.gd` pastes them.
const KADERS := [Vector2(990, 637), Vector2(734, 788), Vector2(326, 558),
	Vector2(558, 289)]
const KADER := Vector2(990, 637)

## The three verified rows of games-b.md §3.4: N, band, day -> s, doel, k, n.
const BANDEN := [
	{"n": 2, "dag": 1, "kunnen": 3, "band": 3, "s": 1, "doel": 3, "k": 1, "hops": 2},
	{"n": 5, "dag": 1, "kunnen": 3, "band": 4, "s": 10, "doel": 20, "k": 2, "hops": 5},
	{"n": 8, "dag": 1, "kunnen": 4, "band": 5, "s": 15, "doel": 35, "k": 2, "hops": 10},
]

var _laag: Control = null
var _bewaard: Dictionary = {}
var _rust_was := false

# ------------------------------------------------------------------ opzet

func _op(kader: Vector2 = KADER) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_bewaard = State.s.duplicate(true)
	_rust_was = Ui.rust_modus()
	# Reduced motion: `World.stappen` then walks every point at once and its
	# promise resolves in the same frame (games-b.md §0.11), so a whole turn is
	# deterministic instead of six seconds of jumping.
	Ui.zet_rust_modus(true)
	_laag = Control.new()
	_laag.size = kader
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	World.meet(Rect2(Vector2.ZERO, kader))
	World.naar("tuin")
	World.meet(Rect2(Vector2.ZERO, kader))

func _af() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	if Games.actief() != "":
		Games.stop()
	# `stop()` cancels the game's timers by making them fire at once; two frames
	# let them do that, so no coroutine of the game stays suspended on a timer
	# that never comes — a suspended coroutine keeps its whole script alive and
	# the engine reports it as a leaked instance at exit.
	for _f in 2:
		await boom.process_frame
	Hits.wis_alles()
	World.decor_wis_alles()
	Ui.registreer_lagen(null, null, null)
	if _laag != null:
		_laag.queue_free()
		_laag = null
	Ui.zet_rust_modus(_rust_was)
	State.s = _bewaard

## `n` guests, each with a bed, all of them already in the garden.
func _gasten(n: int, dag: int, kunnen: int) -> void:
	State.nieuw_spel()
	State.s["dag"] = dag
	State.s["kunnen"] = kunnen
	var pool := State.gasten_pool()
	var bedden := State.alle_bedden()
	var lijst: Array = []
	for i in n:
		var g: Dictionary = pool[i % pool.size()].duplicate(true)
		g["id"] = "hk%d" % i
		g["naam"] = str(g["naam"])
		g["kamer"] = str(bedden[i % bedden.size()]["kamer"])
		g["bed"] = str(bedden[i % bedden.size()]["slot"])
		g["waar"] = "tuin"
		lijst.append(g)
	State.s["gasten"] = lijst
	World.sync(lijst)
	for i in n:
		World.zet("hk%d" % i, "tuin", 20.0 + float(i) * 6.0, 100.0)

## Start the turn twice: the first start makes the stand, and once the guest
## stands on his own stone the second start resumes exactly that stand — which
## is the reload path as well, so the strip is on screen without waiting out the
## half-second poll of `_wacht_lus`.
func _speel(n: int, dag: int, kunnen: int) -> Node:
	_gasten(n, dag, kunnen)
	waar(Games.start("hinkel"), "het spel start")
	var node: Node = Games._knoop
	if node == null:
		fout("het spel heeft geen knoop")
		return null
	var st: Dictionary = node.proef_stand()
	var m: Dictionary = node.proef_pad_maat()
	World.zet(str(st["gast"]), "tuin", node.proef_dier_x(float(st["s"])),
		float(m["zDier"]))
	Games.stop()
	for _f in 2:
		await (Engine.get_main_loop() as SceneTree).process_frame
	waar(Games.start("hinkel"), "en start opnieuw met de gast op zijn steen")
	node = Games._knoop
	Hits.plaats()
	return node

## Press one button of the choice strip, exactly as a finger does.
func _tik_keuze(id: String) -> bool:
	var s := Hits.spot("hk_som_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		return false
	var rij: Node = s.knoop.get_node_or_null("Rij")
	if rij == null:
		return false
	for k in rij.get_children():
		if k.name == "K" + id:
			(k as BaseButton).emit_signal("pressed")
			return true
	return false

func _keuze_woorden() -> Array[String]:
	var uit: Array[String] = []
	var s := Hits.spot("hk_som_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		return uit
	var rij: Node = s.knoop.get_node_or_null("Rij")
	if rij == null:
		return uit
	for k in rij.get_children():
		uit.append((k as Button).text)
	return uit

func _kaart_knoop() -> UiSomkaart:
	var s := Hits.spot("hk_som")
	if s == null or not is_instance_valid(s.knoop):
		return null
	return s.knoop as UiSomkaart

func _regels() -> Array[String]:
	var k := _kaart_knoop()
	if k == null:
		return [] as Array[String]
	var uit: Array[String] = [k.regel_label.text]
	if k.regel2_label != null and k.regel2_label.visible:
		uit.append(k.regel2_label.text)
	return uit

# ================================================================ aanmelding

## The registry finds the game by directory scan; every field of games-b.md §3.2
## is what the hotel reads.
func test_aanmelding_en_ontgrendeling() -> void:
	waar(Games.lijst().has("hinkel"), "de mapscan vindt hinkel")
	var def := Games.definitie("hinkel")
	gelijk(def.get("id", ""), "hinkel", "de mapnaam is het id")
	gelijk(def.get("naam", ""), "Hinkelpad", "naam")
	gelijk(def.get("kamer", ""), "tuin", "kamer")
	gelijk(def.get("wens", ""), "spelen", "het lost de wens 🧶 spelen in")
	gelijk(def.get("stub", true), false, "geen stub")
	var hs: Dictionary = def.get("hotspot", {})
	gelijk(hs.get("obj", ""), "hok", "de knop hangt aan het hok")
	gelijk(hs.get("icoon", ""), "🪨", "met het steentje")
	gelijk(hs.get("label", ""), "Hinkelen", "en het woord Hinkelen")
	gelijk(hs.get("hoog", 0), 6, "hoogte 6")
	# dx/dz slide the button from the hok onto the first stone (27, 41); the
	# hok itself moved to the far corner of the garden (owner, 2026-09-23),
	# so the shift is measured from wherever it stands
	var hok := World.mik("hok", "tuin")
	gelijk(float(hok.get("x", 0)) + float(hs.get("dx", 0)), 27.0, "dx schuift naar de eerste steen")
	gelijk(float(hok.get("z", 0)) + float(hs.get("dz", 0)), 41.0, "dz naar de stenenrij")
	var slot: Callable = def["unlock"]
	waar(not slot.call(0, 3), "zonder gast is er niets te hinkelen")
	waar(slot.call(1, 3), "vanaf één gast wel")

## `taak.prio` is a READ value: 2 while a guest waits to play, 5 otherwise
## (games-b.md §3.2).  `Hotel.spel_taken()` is what reads it.
func test_taakkaartje_en_zijn_voorrang() -> void:
	_op()
	_gasten(2, 1, 3)
	var taak: Dictionary = Games.definitie("hinkel")["taak"]
	gelijk(taak.get("icoon", ""), "🪨", "het pictogram van het kaartje")
	gelijk(taak.get("kamer", ""), "tuin", "het wijst naar de tuin")
	var chip := _spel_taak()
	gelijk(chip.get("tekst", ""), "Hinkel op de stenen", "zonder wens: het klusje")
	gelijk(chip.get("prio", 0), 5, "en dan is het een gewoon klusje")
	waar(Ui.keur_taak("hinkel", str(chip.get("tekst", ""))), "hooguit zes woorden")
	State.s["gasten"][1]["behoefte"] = "spelen"
	State.s["gasten"][1]["blij"] = false
	chip = _spel_taak()
	gelijk(chip.get("tekst", ""), "%s wil hinkelen" % State.s["gasten"][1]["naam"],
		"met een wens leent het kaartje de naam van de gast")
	gelijk(chip.get("prio", 0), 2, "en schuift het naar voren")
	waar(Ui.keur_taak("hinkel", str(chip.get("tekst", ""))), "ook dan hooguit zes woorden")
	State.s["gasten"] = []
	gelijk(_spel_taak(), {}, "zonder gast met een bed hangt er geen kaartje")
	await _af()

func _spel_taak() -> Dictionary:
	for q in Hotel.spel_taken():
		if str(q["spel"]) == "hinkel":
			return q
	return {}

## No guest with a bed: one word on the hok, verbatim, and then it closes.
func test_zonder_gasten_zegt_het_dat() -> void:
	_op()
	State.nieuw_spel()
	State.s["gasten"] = []
	World.sync([])
	waar(Games.start("hinkel"), "het spel start ook zonder gasten")
	Hits.plaats()
	var s := Hits.spot("hk_leeg")
	waar(s != null, "er hangt een wolkje op het hok")
	if s != null:
		var w := s.knoop as UiWolk
		gelijk(w.icoon_label.text, "🛏", "met het bedje")
		gelijk(w.zeg_label.text, "nog geen gasten", "en dat zegt het woordelijk")
	await _af()

# ============================================================ de hele beurt

## One full turn per band, driven through the choice strip: pick the hop size,
## pick the number of hops, land on the staircase, get the star.
func test_beurt_op_band_3_4_en_5() -> void:
	for rij in BANDEN:
		_op()
		var node := await _speel(int(rij["n"]), int(rij["dag"]), int(rij["kunnen"]))
		if node == null:
			await _af()
			continue
		var wat := "band %d" % int(rij["band"])
		var st: Dictionary = node.proef_stand()
		gelijk(int(st["band"]), int(rij["band"]), "%s: de band van de beurt" % wat)
		gelijk(int(st["s"]), int(rij["s"]), "%s: het startgetal" % wat)
		gelijk(int(st["doel"]), int(rij["doel"]), "%s: het doelgetal" % wat)
		waar(node.proef_op_start_steen(), "%s: de gast staat op zijn steen" % wat)
		gelijk(str(st["fase"]), "sprong", "%s: eerst de sprongmaat" % wat)

		# the sum bar says where he stands and where he must be
		var kaart := _kaart_knoop()
		waar(kaart != null, "%s: de sommenkaart staat er" % wat)
		if kaart != null:
			gelijk(kaart.som_label.text, "van %d naar %d" % [int(rij["s"]), int(rij["doel"])],
				"%s: de sombalk" % wat)
		# the strip offers only sizes that fit the distance exactly
		var maten: Array = node.proef_maten()
		waar(maten.size() >= 1 and maten.size() <= 3,
			"%s: hooguit drie sprongmaten (%s)" % [wat, str(maten)])
		for k in maten:
			gelijk((int(rij["doel"]) - int(rij["s"])) % int(k), 0,
				"%s: maat %d past precies" % [wat, int(k)])
		for woord in _keuze_woorden():
			waar(woord.contains("🪨") and woord.contains("sprong"),
				"%s: elke knop draagt pictogram én woord (%s)" % [wat, woord])

		# pick the size of the verified row, then the right number of hops
		waar(_tik_keuze("k%d" % int(rij["k"])), "%s: de sprongmaat is aan te tikken" % wat)
		Hits.plaats()
		st = node.proef_stand()
		gelijk(str(st["fase"]), "aantal", "%s: nu de vraag hoeveel sprongen" % wat)
		gelijk(int(st["sprong"]), int(rij["k"]), "%s: de gekozen maat staat vast" % wat)
		var keuzes := _keuze_woorden()
		gelijk(keuzes.size(), 4, "%s: vier aantallen om uit te kiezen" % wat)
		waar(keuzes.has("🪨 %d keer" % int(rij["hops"])),
			"%s: het goede aantal staat erbij (%s)" % [wat, str(keuzes)])
		var sterren_voor := int(State.s["sterren"])
		waar(_tik_keuze("n%d" % int(rij["hops"])), "%s: het aantal is aan te tikken" % wat)
		Hits.plaats()

		st = node.proef_stand()
		gelijk(str(st["fase"]), "af", "%s: de beurt is af" % wat)
		gelijk(int(st["s"]), int(rij["doel"]), "%s: hij staat op de trap" % wat)
		gelijk(int(State.s["sterren"]), sterren_voor + 1, "%s: één ster erbij" % wat)
		gelijk(_regels(), ["✅ Precies op de trap!"], "%s: de eindzin, woordelijk" % wat)
		var eind := _kaart_knoop()
		if eind != null:
			gelijk(eind.som_label.text, "", "%s: geen lege mededeling op het eind" % wat)
			gelijk(eind.vak_label.text, "✓", "%s: de kaart draagt een vinkje" % wat)
		waar(Hits.spot("hk_som_keuzes") == null, "%s: de strook is weg" % wat)
		waar(Hits.spot("hk_goed") != null, "%s: het wolkje bij het dier" % wat)
		if Hits.spot("hk_goed") != null:
			var blij := Hits.spot("hk_goed").knoop as UiWolk
			gelijk(blij.icoon_label.text, "⭐", "%s: de ster bij het dier" % wat)
			gelijk(blij.zeg_label.text, "op de trap", "%s: woordelijk" % wat)
		await _af()

## The 🧶 wish is redeemed by the turn, and only then.
func test_de_wens_spelen_wordt_ingelost() -> void:
	_op()
	_gasten(2, 1, 3)
	State.s["gasten"][0]["behoefte"] = "spelen"
	State.s["gasten"][0]["blij"] = false
	State.s["gasten"][1]["behoefte"] = "eten"
	var node := await _speel_verder()
	if node == null:
		await _af()
		return
	gelijk(str(node.proef_stand()["gast"]), "hk0", "wie wil spelen, speelt")
	_maak_af(node)
	gelijk(State.s["gasten"][0].get("blij", false), true, "de wens is ingelost")
	await _af()

## Restart on the guests that are already in `State.s`, without rebuilding them.
func _speel_verder() -> Node:
	waar(Games.start("hinkel"), "het spel start")
	var node: Node = Games._knoop
	if node == null:
		return null
	var st: Dictionary = node.proef_stand()
	var m: Dictionary = node.proef_pad_maat()
	World.zet(str(st["gast"]), "tuin", node.proef_dier_x(float(st["s"])), float(m["zDier"]))
	Games.stop()
	# two frames for the stopped game's node to go — with the world standing
	# still: a guest the stop let go starts to wander otherwise, and then the
	# test depended on how many ticks fit in two frames (red on a slow run)
	World.pauzeer(true)
	for _f in 2:
		await (Engine.get_main_loop() as SceneTree).process_frame
	World.pauzeer(false)
	waar(Games.start("hinkel"), "en gaat verder met de gast op zijn steen")
	node = Games._knoop
	Hits.plaats()
	return node

## Play the turn out with the right answers, whatever the numbers are.
func _maak_af(node: Node) -> void:
	for _ronde in 8:
		var st: Dictionary = node.proef_stand()
		if str(st["fase"]) == "af":
			return
		if str(st["fase"]) == "sprong":
			var maten: Array = node.proef_maten()
			if maten.is_empty():
				return
			if not _tik_keuze("k%d" % int(maten[0])):
				return
			Hits.plaats()
			st = node.proef_stand()
		@warning_ignore("integer_division")
		var hops: int = absi(int(st["doel"]) - int(st["s"])) / maxi(1, int(st["sprong"]))
		if not _tik_keuze("n%d" % hops):
			return
		Hits.plaats()

# ======================================================= geen hulp na een fout

## Wait out the pause `Ui.misser` puts on the strip after a miss (S5), the way
## a child with a real finger does.
func _wacht_mispauze() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var eind := Time.get_ticks_msec() + int(Ui.MIS_PAUZE * 1000.0) + 250
	while Time.get_ticks_msec() < eind:
		await boom.process_frame

## A count on the strip that is NOT the right number of hops.
func _fout_aantal(node: Node) -> int:
	var st: Dictionary = node.proef_stand()
	@warning_ignore("integer_division")
	var goed: int = absi(int(st["doel"]) - int(st["s"])) / maxi(1, int(st["sprong"]))
	for w in _keuze_woorden():
		var n := int(w.trim_prefix("🪨 ").trim_suffix(" keer"))
		if n > 0 and n != goed:
			return n
	return -1

## The owner, 2026-09-24: "Nee geef geen hulp na fouten.  Kinderen moeten zelf
## leren rekenen.  Fout antwoord kiezen moet niet beloond worden met hulp maar
## juist een teleurgesteld dier."  A wrong number of hops, one, two and three
## times: the animal still hops what was chosen (never punishing) and then he
## is disappointed — `sip`, `🔄 Nog een keer`, the strip locked for a moment.
## Nothing helps: no bubble that says he is short or too far, no card that says
## which way to go, no counting line on the next card.  The card asks the same
## question as always from where he landed, and the right hops still finish.
func test_geen_hulp_na_een_fout() -> void:
	_op()
	var node := await _speel(5, 1, 3)          # band 4: van 10 naar 20 met 2, 5 sprongen
	if node == null:
		await _af()
		return
	var gast := str(node.proef_stand()["gast"])
	var naam := str(State.gast_van(gast).get("naam", ""))
	for i in 3:
		var wat := "misser %d" % (i + 1)
		var maten: Array = node.proef_maten()
		waar(not maten.is_empty() and _tik_keuze("k%d" % int(maten[0])), "%s: een sprongmaat" % wat)
		Hits.plaats()
		var kaart := _kaart_knoop()
		waar(kaart != null and not kaart.hulp_label.visible, "%s: bij de vraag geen telhulp" % wat)
		var n := _fout_aantal(node)
		waar(n > 0, "%s: er staat een fout aantal op de strook" % wat)
		waar(_tik_keuze("n%d" % n), "%s: %d keer, fout" % [wat, n])
		Hits.plaats()
		var st: Dictionary = node.proef_stand()
		gelijk(int(st["missers"]), i + 1, "%s: geteld" % wat)
		gelijk(str(st["fase"]), "sprong", "%s: de kaart vraagt van daaruit verder" % wat)
		waar(int(st["s"]) != int(st["doel"]), "%s: hij staat niet op de trap" % wat)
		waar(is_sip(gast), "%s: het dier is teleurgesteld" % wat)
		waar(mis_wolk("hk_som"), "%s: met 🔄 Nog een keer" % wat)
		var strook := Hits.spot("hk_som_keuzes")
		waar(strook != null and (strook.knoop as UiKeuzes).op_slot,
			"%s: de strook staat even op slot" % wat)
		waar(Hits.spot("hk_zeg") == null, "%s: geen wolkje met te ver of nog verder" % wat)
		var regels := _regels()
		waar(regels.size() == 2 and regels[0].ends_with(
			"%s staat op %d, trap bij %d" % [naam, int(st["s"]), int(st["doel"])])
			and regels[1] == "Kies je sprong",
			"%s: dezelfde vraag als altijd, vanaf zijn steen (%s)" % [wat, str(regels)])
		kaart = _kaart_knoop()
		waar(kaart != null and not kaart.hulp_label.visible, "%s: geen hulpregel" % wat)
		for regel in _regels():
			waar(not regel.contains("✗") and not regel.contains("❌") and not regel.contains("fout"),
				"%s: nooit een kruis op de kaart (%s)" % [wat, regel])
		gelijk(int(State.s["sterren"]), 0, "%s: een misser kost geen ster" % wat)
		var voor := beeld("hinkel")
		await _wacht_mispauze()
		waar(not (Hits.spot("hk_som_keuzes").knoop as UiKeuzes).op_slot, "%s: de strook is weer open" % wat)
		var na := beeld("hinkel")
		for id in na.keys():
			waar(voor.has(id), "%s: na de pauze verschijnt %s niet (%s)" % [wat, id, str(na[id])])
	# and the star is still there for taking part
	_maak_af(node)
	gelijk(str(node.proef_stand()["fase"]), "af", "de goede sprongen maken het af")
	gelijk(int(State.s["sterren"]), 1, "de ster hangt aan het meedoen")
	await _af()

## Never off the line: an answer that would hop past the end is clamped and the
## turn simply goes on (games-b.md §3.8).
func test_nooit_van_de_lijn_af() -> void:
	_op()
	var node := await _speel(2, 1, 3)          # band 3: van 1 naar 3 met 1, 2 sprongen
	if node == null:
		await _af()
		return
	waar(_tik_keuze("k1"), "sprongmaat 1")
	Hits.plaats()
	var st: Dictionary = node.proef_stand()
	gelijk(int(st["E"]), 10, "de lijn loopt tot 10")
	# the strip never offers more than the line holds, so the clamp is proven on
	# the state itself: nine hops from 1 with size 1 ends at 10, not at 12
	waar(_tik_keuze("n%d" % 4), "vier sprongen")
	Hits.plaats()
	st = node.proef_stand()
	gelijk(int(st["s"]), 5, "van 1 naar 5")
	waar(int(st["s"]) <= int(st["E"]), "en nooit voorbij het einde van de lijn")
	await _af()

# ============================================================ herstel en stop

## The turn survives a reload: it is rebuilt from `ctx.data()` — through JSON,
## because that is the shape the save really has (architecture.md §9).
func test_herstel_uit_ctx_data() -> void:
	_op()
	var node := await _speel(5, 1, 3)
	if node == null:
		await _af()
		return
	waar(_tik_keuze("k2"), "de sprongmaat is gekozen")
	Hits.plaats()
	var voor: Dictionary = node.proef_stand()
	Games.stop()

	# a reload: everything the engine held is gone, only the save is left
	var door_json = JSON.parse_string(JSON.stringify(State.s))
	waar(door_json is Dictionary, "de stand overleeft JSON")
	State.s = door_json
	World.sync(State.s["gasten"])
	World.zet(str(voor["gast"]), "tuin", node.proef_dier_x(float(voor["s"])),
		float(node.proef_pad_maat()["zDier"]))
	waar(Games.start("hinkel"), "het spel start opnieuw")
	var na_node: Node = Games._knoop
	var na_stand: Dictionary = na_node.proef_stand()
	gelijk(int(na_stand["s"]), int(voor["s"]), "hetzelfde startgetal")
	gelijk(int(na_stand["doel"]), int(voor["doel"]), "hetzelfde doel")
	gelijk(int(na_stand["sprong"]), int(voor["sprong"]), "dezelfde sprongmaat")
	gelijk(str(na_stand["fase"]), "aantal", "en dezelfde vraag")
	Games.stop()

	# a hop survives no reload: fase `hop` comes back as `sprong`
	State.spel_data("hinkel")["stand"]["fase"] = "hop"
	waar(Games.start("hinkel"), "en nog eens, midden in een sprong")
	gelijk(str((Games._knoop as Node).proef_stand()["fase"]), "sprong",
		"een sprong overleeft geen herlaad")
	await _af()

## A turn of another day, another guest count or another band is never resumed.
func test_een_oude_stand_wordt_niet_hervat() -> void:
	_op()
	var node := await _speel(5, 1, 3)
	if node == null:
		await _af()
		return
	var voor: Dictionary = node.proef_stand()
	Games.stop()
	State.s["dag"] = int(State.s["dag"]) + 1
	waar(Games.start("hinkel"), "morgen start het opnieuw")
	var na_stand: Dictionary = (Games._knoop as Node).proef_stand()
	gelijk(int(na_stand["dag"]), int(voor["dag"]) + 1, "met de nieuwe dag")
	waar(int(na_stand["s"]) != int(voor["s"]) or int(na_stand["doel"]) != int(voor["doel"]),
		"en met een verse som")
	await _af()

## `stop()` leaves the world clean: no hotspot, no loose decor, no guest left
## standing where the game put him.
func test_stop_laat_de_wereld_schoon_achter() -> void:
	_op()
	var node := await _speel(5, 1, 3)
	if node == null:
		await _af()
		return
	var stenen := 0
	for stuk in World.decor_lijst("tuin"):
		if str(stuk["door"]) == "hinkel":
			stenen += 1
	gelijk(stenen, 22, "21 stenen en één trapje staan er")
	var eigen := 0
	for id in Hits.lijst():
		if Hits.spot(id).door == "hinkel":
			eigen += 1
	waar(eigen >= 2, "en het spel plaatste eigen knoppen (%d)" % eigen)

	Games.stop()
	for id in Hits.lijst():
		waar(Hits.spot(id).door != "hinkel", "geen hotspot van het spel bleef staan: %s" % id)
	gelijk(World.decor_lijst().filter(func(d): return str(d["door"]) == "hinkel").size(), 0,
		"en geen enkel eigen decorstuk")
	waar(Hits.spot("hk_som") == null, "de kaart is weg")
	waar(Hits.spot("hk_gast") == null, "en de cijferchip ook")
	await _af()

## The guests that were sent off the strip get their own way back.
func test_gasten_naast_de_strook_en_terug() -> void:
	_op()
	_gasten(5, 1, 3)
	# put two guests right on top of the number line
	World.zet("hk1", "tuin", 60.0, 42.0)
	World.zet("hk2", "tuin", 40.0, 44.0)
	var node := await _speel_verder()
	if node == null:
		await _af()
		return
	var z: Dictionary = Rooms.get_kamer("tuin").zones["hinkel"]
	for id in ["hk1", "hk2"]:
		var d = World.dier(id)
		waar(d != null, "%s staat er nog" % id)
		if d != null:
			waar(d.z >= float(z["z1"]) + 10.0 or not d.punten.is_empty(),
				"%s is van de stenen af gestuurd (z=%.0f)" % [id, d.z])
	Games.stop()
	for id in ["hk1", "hk2"]:
		var d = World.dier(id)
		if d != null:
			gelijk(d.pose, "rust", "%s krijgt zijn eigen gang terug" % id)
	await _af()

# ======================================================= het dier van de beurt

## "Een methode om te wisselen met welk dier je de spellen speelt" (owner,
## 2026-09-23): every guest with a bed may hop, in check-in order; the game
## still picks its own hopper; the animal on the game bar hands the path to the
## next one in a fresh turn — the one who stood on the stones is sent off them
## like every other guest — and the next start hops with the animal the child
## picked.
func test_het_kind_kiest_wie_er_hinkelt() -> void:
	_op()
	var node := await _speel(5, 1, 3)          # band 4: van 10 naar 20
	if node == null:
		await _af()
		return
	gelijk(str(Games.spelers()), str(["hk0", "hk1", "hk2", "hk3", "hk4"]),
		"wie mag hinkelen: iedereen met een bed, op volgorde")
	var eerste := str(node.proef_stand()["gast"])
	gelijk(Games.speler(), eerste, "het spel kiest zelf, zoals altijd")
	waar(_tik_keuze("k2"), "de sprongmaat 2")
	Hits.plaats()
	waar(_tik_keuze("n4"), "vier sprongen, nog niet bij de trap")
	Hits.plaats()
	gelijk(int(node.proef_stand()["s"]), 18, "hij staat halverwege het pad")
	var sterren := int(State.s["sterren"])
	var volgende := Games.volgende_speler()
	waar(not volgende.is_empty() and volgende != eerste, "er is een volgend dier")
	waar(Games.wissel_speler(), "het dier op de balk geeft de beurt door")
	gelijk(Games.actief(), "hinkel", "het hinkelpad draait nog")
	node = Games._knoop
	var st: Dictionary = node.proef_stand()
	gelijk(str(st["gast"]), volgende, "nu hinkelt het volgende dier")
	gelijk(Games.speler(), volgende, "en de balk weet het")
	gelijk(int(st["s"]), 10, "vanaf de start van het pad")
	gelijk(str(st["fase"]), "sprong", "met de eerste vraag")
	gelijk(int(st["missers"]), 0, "zonder missers")
	gelijk(int(State.s["sterren"]), sterren, "er ging geen ster af")
	# who stood on the stones is sent off them, like every guest who is not playing
	var z: Dictionary = Rooms.get_kamer("tuin").zones["hinkel"]
	var d = World.dier(eerste)
	waar(d != null and (d.z >= float(z["z1"]) + 10.0 or not d.punten.is_empty()),
		"%s staat niet meer op de stenen" % eerste)
	# the next start hops with the animal the child picked
	Games.stop()
	for _f in 2:
		await (Engine.get_main_loop() as SceneTree).process_frame
	waar(Games.start("hinkel"), "het hinkelpad start opnieuw")
	gelijk(str((Games._knoop as Node).proef_stand()["gast"]), volgende, "met het gekozen dier")
	await _af()

# ====================================================== wachten op het dier

## Eigenaar, 2026-09-23: "Zorg dat de minigame pas begint wanneer het dier er
## is" — dat overrulet PLAN N11 ("de som staat er meteen, het dier komt
## eraan").  De hinkelaar ligt in zijn kamer: zolang hij door het hotel loopt
## staat er niets van het spel — geen kaart, geen strook, geen getal boven zijn
## kop — maar wel het hotelwolkje "komt eraan" met `👀 Volg` aan de tuindeur.
## Op zijn steen komt de kaart met de eerste vraag.
func test_de_kaart_wacht_op_de_hinkelaar() -> void:
	_op()
	Ui.zet_rust_modus(false)
	_gasten(2, 1, 3)
	var g: Dictionary = State.s["gasten"][0]
	g["behoefte"] = "spelen"                # hk0 wil spelen: hij hinkelt
	g["blij"] = false
	var id := str(g["id"])
	World.zet(id, str(g["kamer"]), 60.0, 60.0)
	World.pauzeer(true)                     # de test tikt de wereld zelf
	waar(Games.start("hinkel"), "het spel start")
	var node: Node = Games._knoop
	gelijk(Games.speler(), id, "wie wil spelen, hinkelt")
	waar(Hits.spot("hk_som") == null, "nog geen kaart")
	waar(Hits.spot("hk_som_keuzes") == null, "en geen strook")
	waar(Hits.spot("hk_gast") == null, "en geen getal boven zijn kop")
	waar(Games.verwacht_dier(id), "het spel wacht op hem")
	var stenen := 0
	for stuk in World.decor_lijst("tuin"):
		if str(stuk["door"]) == "hinkel":
			stenen += 1
	waar(stenen > 0, "de stenen en het trapje liggen er al (%d)" % stenen)
	Hotel.komt_eraan()
	Hits.plaats()
	var w := Hits.spot("komt_" + id)
	waar(w != null and is_instance_valid(w.knoop) and w.knoop.visible,
		"zijn wolkje 'komt eraan' hangt aan de tuindeur, ook nu het spel loopt")
	var d = World.dier(id)
	var t := 0
	while d.kamer != "tuin" and t < 4000:
		World._tik()
		t += 1
	gelijk(d.kamer, "tuin", "hij stapt de tuin in")
	var boom := Engine.get_main_loop() as SceneTree
	await boom.create_timer(0.35).timeout
	waar(Hits.spot("hk_som") == null, "zolang hij naar zijn steen loopt, is er geen kaart")
	while not (d.punten as Array).is_empty() and t < 4000:
		World._tik()
		t += 1
	var t0 := Time.get_ticks_msec()
	while Hits.spot("hk_som_keuzes") == null and Time.get_ticks_msec() - t0 < 1500:
		await boom.process_frame
	waar(Hits.spot("hk_som_keuzes") != null, "op zijn steen: de kaart met de strook")
	waar(node.proef_op_start_steen(), "hij staat op zijn steen")
	waar(not Games.verwacht_dier(id), "het spel wacht niet meer")
	var regels := _regels()
	waar(not regels.is_empty() and regels[0].contains("staat op"),
		"de eerste vraag: waar hij staat (%s)" % str(regels))
	World.pauzeer(false)
	await _af()

# ============================================================== de kindtekst

## F3: every child-facing string of games-b.md §3.9 stands verbatim in the file.
## The card "<naam> komt eraan / Tel straks mee" is gone since the owner's wish of
## 2026-09-23 ("Zorg dat de minigame pas begint wanneer het dier er is"): while
## the hopper walks in the game draws nothing and the hotel's own "komt eraan"
## bubble says who is coming (`test_de_kaart_wacht_op_de_hinkelaar`).
func test_kindtekst_staat_woordelijk_in_het_bestand() -> void:
	var f := FileAccess.open("res://games/hinkel/spel.gd", FileAccess.READ)
	waar(f != null, "het spelbestand is te lezen")
	if f == null:
		return
	var bron := f.get_as_text()
	f.close()
	for zin in ["Hinkelen", "%s wil hinkelen", "Hinkel op de stenen",
			"nog geen gasten", "van %d naar %d",
			"%s staat op %d, trap bij %d", "Kies je sprong",
			"%s springt %d", " terug", " per keer", "Hoeveel sprongen?",
			"%s hinkelt", "Tel maar mee", "Precies op de trap!",
			"sprong %d", "terug %d", "%d keer", "kies je sprong",
			"hoeveel sprongen?", "op de trap",
			"🪨", "🛏", "✅", "⭐", "🐶", "🐱", "🐰", "🦆", "🐾"]:
		waar(bron.contains(zin), "de tekst staat er woordelijk: %s" % zin)
	# what came after a miss is gone (owner, 2026-09-24): no hint of the way
	for weg in ["Nog even verder", "Oei, te ver!", "Kies je sprong terug",
			"\"te ver\"", "\"nog verder\"", "tel_pad"]:
		waar(not bron.contains(weg), "geen hulp na een misser meer: %s" % weg)

## F4: every sentence of every phase is one Dutch sentence of <= 8 words and
## <= 40 characters, on the longest name the hotel can produce.
func test_elke_zin_past_binnen_f4() -> void:
	_op()
	_gasten(8, 1, 4)
	State.s["gasten"][0]["naam"] = "Stampertje"        # the longest guest name
	var node := await _speel_verder()
	if node == null:
		await _af()
		return
	var gezien := 0
	for fase in ["sprong", "aantal", "hop"]:
		for melding in ["", "kort", "ver"]:
			var st: Dictionary = node.proef_stand()
			var zin: Array = node.proef_zinnen()["zin"]
			for regel in zin:
				waar(Ui.keur_regel("hk_som", str(regel)),
					"'%s' past binnen 8 woorden en 40 tekens (%d)"
						% [str(regel), str(regel).length()])
				gezien += 1
			# walk the phases by playing, not by writing into the state
			if str(st["fase"]) == "sprong":
				var maten: Array = node.proef_maten()
				if not maten.is_empty():
					_tik_keuze("k%d" % int(maten[0]))
					Hits.plaats()
			elif str(st["fase"]) == "aantal":
				_tik_keuze("n1")
				Hits.plaats()
	waar(gezien >= 6, "er zijn zinnen gekeurd (%d)" % gezien)
	await _af()

# ========================================================== de knoppenlaag

## The screens of the definition of done.
const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740),
	Vector2i(740, 360)]

## The whole shell in a SubViewport, so the camera really centres the garden:
## hotspots placed against a camera at the origin prove nothing about the room
## the child sees (tests/test_hits.gd says the same).
func _shell_op(maat: Vector2i) -> Dictionary:
	var boom := Engine.get_main_loop() as SceneTree
	_bewaard = State.s.duplicate(true)
	_rust_was = Ui.rust_modus()
	Ui.zet_rust_modus(true)
	var vp := SubViewport.new()
	vp.size = maat
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	boom.root.add_child(vp)
	var shell := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	shell.set_meta("geen_start", true)     # never write the save from a test
	vp.add_child(shell)
	for _f in 4:
		await boom.process_frame
	Hotel.start()
	for _f in 4:
		await boom.process_frame
	var kader: Control = shell.get_node("Scherm/Kolom/Middenrij/Kaderdoos/Kader")
	return {"vp": vp, "kader": kader.size}

func _shell_af(h: Dictionary) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	if Games.actief() != "":
		Games.stop()
	Ui.naamplaten_leeg()
	Hits.wis_alles()
	World.decor_wis_alles()
	(h["vp"] as SubViewport).queue_free()
	await boom.process_frame
	Ui.registreer_lagen(null, null, null)
	# The shell reported the window size to `Ui`; forget it again, or the next
	# suite measures its tap targets against a screen that is no longer there.
	# The next `World.meet()` recomputes them from the frame, as it always did.
	Ui._scherm = Vector2.ZERO
	Ui.zet_rust_modus(_rust_was)
	State.s = _bewaard

## The definition of done: `Hits.dekking` is 0 % for every button on an object,
## in four frame sizes, not one placement is `krap`, everything stands inside
## the frame, and the card and its strip never cover the guest.
func test_geen_knop_dekt_zijn_voorwerp_in_vier_kaders() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	for maat in SCHERMEN:
		var h: Dictionary = await _shell_op(maat)
		var kader: Vector2 = h["kader"]
		var node := await _speel(3, 1, 3)
		if node == null:
			await _shell_af(h)
			continue
		Hotel.render()
		for _f in 3:
			await boom.process_frame
		Hits.plaats()
		var dbg := Hits.debug()
		waar(dbg.size() >= 3, "%s: er staat wat op het glas (%d)" % [str(maat), dbg.size()])
		for id in dbg.keys():
			var d: Dictionary = dbg[id]
			var mijn := str(id).begins_with("hk_") or str(id) == "spel_hinkel"
			if mijn:
				waar(not bool(d["krap"]), "%s: %s vond een echte plek" % [str(maat), id])
			var r: Rect2 = d["rect"]
			waar(r.position.x >= -0.01 and r.position.y >= -0.01
				and r.end.x <= kader.x + 0.01 and r.end.y <= kader.y + 0.01,
				"%s: %s staat in het kader %s (%s)" % [str(maat), id, str(kader), str(r)])
			if int(d["laag"]) != Hits.Laag.VAST:
				# every BUTTON covers 0 % of every object in view
				gelijk(Hits.dekking(id), 0.0,
					"%s: %s dekt zijn voorwerp niet" % [str(maat), id])
			elif id == "hk_gast":
				# a number tag may cover a tenth of its own object, no more
				waar(Hits.dekking(id) <= Hits.TAG_IN * 100.0 + 0.01,
					"%s: het getal dekt hoogstens %d %% van de gast (%.2f)"
						% [str(maat), int(Hits.TAG_IN * 100.0), Hits.dekking(id)])
		# the card and its strip belong together and stay off the animal
		waar(Hits.spot("hk_som") != null, "%s: de kaart staat er" % str(maat))
		waar(Hits.spot("hk_som_keuzes") != null, "%s: de strook staat er" % str(maat))
		var gast := World.vlak_van_dier(str(node.proef_stand()["gast"]))
		var pad := _padvlak(node)
		for id in ["hk_som", "hk_som_keuzes"]:
			if not dbg.has(id):
				continue
			var r: Rect2 = dbg[id]["rect"]
			var snij := r.intersection(gast)
			gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
				"%s: %s laat de gast heel" % [str(maat), id])
			for steen in pad:
				var sn2 := r.intersection(steen as Rect2)
				gelijk(maxf(0.0, sn2.size.x) * maxf(0.0, sn2.size.y), 0.0,
					"%s: %s laat de getallenlijn heel" % [str(maat), id])
		await _shell_af(h)

## The screen rectangle of every stone of the number line, right now — from the
## same record the game hands to the world, plate and all.
func _padvlak(node: Node) -> Array[Rect2]:
	var uit: Array[Rect2] = []
	var m: Dictionary = node.proef_pad_maat()
	var band := int(node.proef_stand()["band"])
	for i in int(m["stenen"]):
		var st: Dictionary = node.proef_steen_plek(i, band)
		uit.append(World.vlak_van("hinkel_steen", float(st["x"]), float(st["z"]),
			0.0, st["params"]))
	return uit

## The stones and the staircase are LOOSE DECOR and cost not one button, so the
## garden stays well under the sixteen the button layer holds.
func test_de_stenen_kosten_geen_enkele_knop() -> void:
	_op()
	var node := await _speel(5, 1, 3)
	if node == null:
		await _af()
		return
	Hits.plaats()
	var knoppen := Hits.debug().size()
	waar(knoppen <= Hits.MAX_PER_KAMER,
		"hoogstens %d knoppen in de tuin (%d)" % [Hits.MAX_PER_KAMER, knoppen])
	var eigen: Array[String] = []
	for id in Hits.lijst():
		if Hits.spot(id).door == "hinkel":
			eigen.append(id)
	eigen.sort()
	gelijk(str(eigen), '["hk_gast", "hk_som", "hk_som_keuzes"]',
		"drie eigen knoppen: het getal van de gast, de kaart en de strook")
	await _af()

# ============================================================== de maatvoering

## games-b.md §3.3: three depth rows that keep the same `x - z`, a target that
## always lands ON a stone, and a number plate on the right stones.
func test_de_maatvoering_van_het_pad() -> void:
	_op()
	var node := await _speel(5, 1, 3)
	if node == null:
		await _af()
		return
	var m: Dictionary = node.proef_pad_maat()
	gelijk(m["eerste"], 27.0, "de eerste steen ligt 3 voxels binnen de zone")
	gelijk(m["laatste"], 97.0, "en de laatste 3 voxels ervoor")
	gelijk(m["zSteen"], 41.0, "de stenen liggen op z 41")
	gelijk(m["zDier"], 44.0, "de looplijn op 44")
	gelijk(m["zTrap"], 45.0, "het trapje op 45")
	gelijk(m["zTop"], 47.0, "en de bovenste trede op 47")
	gelijk(m["stenen"], 21, "band 4 heeft 21 stenen")
	gelijk(m["steek"], 3.5, "met een steek van 3,5 voxel")
	# every row keeps the same (x - z), so everything stands in one screen column
	var st: Dictionary = node.proef_stand()
	var x_steen: float = 27.0 + 70.0 * float(st["doel"]) / 100.0
	gelijk(node.proef_dier_x(float(st["doel"])) - 44.0, x_steen - 41.0,
		"de looplijn houdt dezelfde x − z als de steen")
	# the target always stands ON a stone, and never on the last one
	gelijk(int(st["doel"]) % int(st["stap"]), 0, "het doel ligt op een steen")
	waar(int(st["doel"]) < int(st["E"]), "en nooit op de laatste steen")
	# band 4/5 writes out every TWENTIETH stone and keeps every plate low (a plate
	# on every ten was 18 voxel-px wide on a pitch of 7 and smudged; lifting every
	# other one only made two rows of numbers of it).  Band 3 numbers them all.
	gelijk(node.proef_steen_getal(4, 4), 20, "steen 4 van band 4 draagt 20")
	gelijk(node.proef_steen_getal(2, 4), -1, "steen 2 (10) draagt geen bordje meer")
	gelijk(node.proef_steen_getal(3, 4), -1, "steen 3 draagt niets")
	gelijk(node.proef_rij_van_steen(4, 4), 0, "elk bordje hangt laag")
	gelijk(node.proef_rij_van_steen(8, 4), 0, "ook het volgende")
	# ... while the big, darker tick stones keep counting in tens
	gelijk(bool(node.proef_steen_plek(2, 4)["params"]["groot"]), true,
		"steen 2 blijft een dikke tellersteen")
	gelijk(bool(node.proef_steen_plek(3, 4)["params"]["groot"]), false,
		"steen 3 is een gewone steen")
	gelijk(node.proef_steen_getal(7, 3), 7, "in band 3 draagt elke steen zijn getal")
	gelijk(node.proef_rij_van_steen(10, 3), 1, "alleen 10 gaat een rij hoger")
	gelijk(node.proef_rij_van_steen(9, 3), 0, "de rest blijft laag")
	# The plate of the last stone is the widest of its line and the strip stops
	# three voxels behind that stone.  It gives way to its NEIGHBOUR, not to the
	# strip: "10" (9 voxels wide on a pitch of 7) steps two voxels out of the
	# strip, "100" (13 wide on a pitch of 14) has room to come one voxel back in.
	gelijk(int(node.proef_steen_plek(10, 3)["params"]["dx"]), 2,
		"het bordje 10 wijkt twee voxels naar rechts")
	gelijk(int(node.proef_steen_plek(9, 3)["params"]["dx"]), 0,
		"en 9 blijft precies boven zijn eigen steen staan")
	gelijk(int(node.proef_steen_plek(20, 4)["params"]["dx"]), -1,
		"in band 4 schuift 100 één voxel naar binnen")
	gelijk(int(node.proef_steen_plek(16, 4)["params"]["dx"]), 0, "en 80 staat stil")
	await _af()

## The two models are the game's own, namespaced with the game id, and they bake.
func test_eigen_modellen_bakken() -> void:
	_op()
	var node := await _speel(5, 1, 3)
	if node == null:
		await _af()
		return
	waar(Art.heeft_model("hinkel_steen"), "hinkel_steen is aangemeld")
	waar(Art.heeft_model("hinkel_trap"), "hinkel_trap ook")
	waar(not Art.is_wereldmodel("hinkel_steen"), "en het is geen wereldmodel")
	var steen := Art.plaat("hinkel_steen", 3, {"getal": 10, "rij": 1, "dx": 0, "groot": true})
	waar(steen != null and steen.w > 0 and steen.h > 0,
		"de steen bakt tot een echte plaat")
	var trap := Art.plaat("hinkel_trap", 3, {"getal": 20, "dx": 0})
	waar(trap != null and trap.w > 0 and trap.h > 0, "het trapje ook")
	# the number plate is ONE slab: 7 rows x (w + 2) columns at one depth
	var voxels := Art.model("hinkel_steen", {"getal": 7, "rij": 0, "dx": 0, "groot": false})
	var op_plaat := 0
	for p in voxels:
		if int(p["z"]) == -3:
			op_plaat += 1
	gelijk(op_plaat, 7 * 5, "het bordje van één teken is 7 x 5 voxels dik één plaat")
	await _af()

# =========================================================== de getallenlijn

## One number plate, exactly as Art bakes it.  The sign is the single slab at
## z = -3 of `hinkel_steen` (`test_eigen_modellen_bakken` counts its 7 x 5
## voxels), so baking those voxels on their own gives the picture that hangs
## behind the stone — outline and all, because that outline is part of what the
## child sees touch or not touch.
func _bakplaat(st: Dictionary) -> Dictionary:
	var deel: Array = []
	for q in Art.model("hinkel_steen", st["params"]):
		if int(q["z"]) != -3:
			continue
		deel.append(q)
	if deel.is_empty():
		return {}
	var plaat = Art.bak(deel, int(World.schaal()["g"]))
	if plaat == null:
		return {}
	var img: Image = plaat.tex.get_image()
	var op := Vector2i((World.scherm_doel(float(st["x"]), float(st["z"]), 0.0)
		+ Vector2(plaat.dx, plaat.dy)).round())
	var inkt := img.get_used_rect()
	return {"img": img, "op": op, "ink": Rect2i(op + inkt.position, inkt.size)}

## The plate of stone `i` on the screen spot the world gives that stone, or `{}`
## when the stone wears none.  `ink` is the rectangle of the plate's own pixels —
## the baked image carries two transparent pixels of padding on every side, and
## transparent padding is nothing the child can see.
func _bordplaat(node: Node, i: int, band: int) -> Dictionary:
	var st: Dictionary = node.proef_steen_plek(i, band)
	if int(st["params"]["getal"]) < 0:
		return {}
	var heel := _bakplaat(st)
	if heel.is_empty():
		return {}
	return {"n": int(st["params"]["getal"]), "rij": int(st["params"]["rij"]),
		"heel": heel, "ink": heel["ink"]}

## How many pixels do two baked plates really share?
func _gedeelde_pixels(a: Dictionary, b: Dictionary) -> int:
	var ia: Image = a["img"]
	var ib: Image = b["img"]
	var pa: Vector2i = a["op"]
	var pb: Vector2i = b["op"]
	var x0 := maxi(pa.x, pb.x)
	var x1 := mini(pa.x + ia.get_width(), pb.x + ib.get_width())
	var y0 := maxi(pa.y, pb.y)
	var y1 := mini(pa.y + ia.get_height(), pb.y + ib.get_height())
	var n := 0
	for y in range(y0, y1):
		for x in range(x0, x1):
			if ia.get_pixel(x - pa.x, y - pa.y).a > 0.0 \
					and ib.get_pixel(x - pb.x, y - pb.y).a > 0.0:
				n += 1
	return n

## The line has to READ, in every band and on all four frames (the voxel size g
## is 2, 3 or 4 there).  Band 3 writes out every stone — a plate of one character
## is 5 voxels wide on a pitch of 7 — and band 4/5 every twentieth: 0 20 40 60 80
## 100, four stones = 14 voxels = 28*g px apart against a plate of 18*g px
## (26*g px for "100").
##
## Three demands, all measured on the plates Art really bakes and on the screen
## spot the world gives their stone:
##
##  * the line writes out exactly that series of numbers;
##  * in band 4/5 every plate hangs at the SAME height.  The tens used to go up
##    and down in turn, which is what kept a plate of 18*g px standing on a pitch
##    of 7*g px: two rows of numbers, and the child had to work out which number
##    belonged to which stone;
##  * NO TWO PLATES TOUCH — their pixel rectangles keep daylight between them and
##    the two baked pictures do not share one opaque pixel.  The outline counts
##    as part of a plate, so this is the strictest reading there is.  What made
##    two numbers run together was always the LAST plate of the line, the widest
##    one ("10", "100"), being pulled back inside the strip and into its
##    neighbour; it now steps out of the strip instead (`_bord_dx`).
func test_geen_twee_getalbordjes_overlappen() -> void:
	for kader in KADERS:
		_op(kader)
		var node := await _speel(5, 1, 3)
		if node == null:
			await _af()
			continue
		for band in [3, 4, 5]:
			var m: Dictionary = node.proef_pad_maat_van(band)
			var borden: Array[Dictionary] = []
			var getallen: Array = []
			for i in int(m["stenen"]):
				var bp := _bordplaat(node, i, band)
				if bp.is_empty():
					continue
				borden.append(bp)
				getallen.append(int(bp["n"]))
			var wacht: Array = range(11) if band == 3 else [0, 20, 40, 60, 80, 100]
			gelijk(str(getallen), str(wacht),
				"%s band %d: de lijn schrijft %s" % [str(kader), band, str(wacht)])
			if band != 3:
				var rijen := {}
				for bp in borden:
					rijen[int(bp["rij"])] = true
				gelijk(str(rijen.keys()), "[0]",
					"%s band %d: elk bordje hangt op dezelfde hoogte" % [str(kader), band])
			for a in borden.size():
				for b in range(a + 1, borden.size()):
					var na := int(borden[a]["n"])
					var nb := int(borden[b]["n"])
					var ra: Rect2i = borden[a]["ink"]
					var rb: Rect2i = borden[b]["ink"]
					# they miss each other as soon as ONE axis has daylight
					var gat := maxi(
						maxi(ra.position.x, rb.position.x) - mini(ra.end.x, rb.end.x),
						maxi(ra.position.y, rb.position.y) - mini(ra.end.y, rb.end.y))
					waar(gat >= 1, "%s band %d: %d en %d raken elkaar niet (%d px)"
						% [str(kader), band, na, nb, gat])
					gelijk(_gedeelde_pixels(borden[a]["heel"], borden[b]["heel"]), 0,
						"%s band %d: %d en %d delen geen enkele pixel"
							% [str(kader), band, na, nb])
		await _af()

## The lowest voxel of the ink colour — where the digits of a plate begin.
func _laagste_inkt(voxels: Array, kl: Color) -> int:
	var y := 1 << 20
	for q in voxels:
		if Color(q["k"]) == kl:
			y = mini(y, int(q["y"]))
	return y

## The target has to be FINDABLE.  The guest ends his turn ON the little
## staircase, so the number board and its pink flag sit on a mast that comes out
## above him — above the tallest guest of the hotel (a rabbit, ears and all), on
## all four frames.
func test_het_trapje_is_zichtbaar() -> void:
	# 1. the model: a mast out of the treads, the board a row (8 voxels) above the
	#    highest plate the path itself carries, the flag over everything
	_op()
	var node := await _speel(5, 1, 3)
	if node == null:
		await _af()
		return
	var kt: Dictionary = node.get_script().get_script_constant_map()
	var trap_vox: Array = Art.model("hinkel_trap", {"getal": 20, "dx": 0})
	var pad_vox: Array = Art.model("hinkel_steen",
		{"getal": 10, "rij": 1, "dx": 0, "groot": true})
	gelijk(_laagste_inkt(trap_vox, kt["INKT"]), _laagste_inkt(pad_vox, kt["INKT"]) + 8,
		"het doelgetal hangt een rij (8 voxels) boven een padbordje")
	var top := -1
	for q in trap_vox:
		top = maxi(top, int(q["y"]))
	gelijk(top, int(kt["TRAP_BORD"]) + 6, "de vlag is het hoogste van het trapje")
	var roze := true
	for q in trap_vox:
		if int(q["y"]) == top and Color(q["k"]) != Color(kt["VLAG"]):
			roze = false
	waar(roze, "en de hele bovenste rij is roze")
	var mast := 0
	for q in trap_vox:
		if int(q["x"]) == 0 and int(q["z"]) == 0 \
				and int(q["y"]) >= 9 and int(q["y"]) < int(kt["TRAP_BORD"]) - 1:
			mast += 1
	gelijk(mast, int(kt["TRAP_BORD"]) - 10,
		"de mast draagt het bord vanaf de bovenste trede")
	await _af()
	# 2. on screen: the flag stands above the guest on the staircase, whatever the
	#    frame and whatever animal it is
	for kader in KADERS:
		_op(kader)
		var n2 := await _speel(5, 1, 3)
		if n2 == null:
			await _af()
			continue
		var st: Dictionary = n2.proef_stand()
		var m: Dictionary = n2.proef_pad_maat()
		var t: Dictionary = n2.proef_trap_plek()
		var trap := World.vlak_van("hinkel_trap", float(t["x"]), float(t["z"]), 0.0,
			t["params"])
		waar(trap.size.y > 0.0, "%s: het trapje bakt" % str(kader))
		# where `_gelukt` sets the guest down: on the top tread, in front of the mast
		var id := str(st["gast"])
		var dx: float = n2.proef_x_op_rij(float(int(st["doel"])), float(m["zTop"])) + 1.0
		World.zet(id, "tuin", dx, float(m["zTop"]))
		var dier := World.vlak_van_dier(id)
		waar(dier.size.y > 0.0 and trap.position.y + 2.0 <= dier.position.y,
			"%s: de vlag steekt boven de gast uit (%.1f tegen %.1f)"
				% [str(kader), trap.position.y, dier.position.y])
		# ... and above every guest the hotel has, rabbit ears included
		var sch := World.schaal()
		var g := int(sch["g"])
		var trap_top: float = World.scherm_doel(float(t["x"]), float(t["z"]), 0.0).y \
			+ float(Art.plaat("hinkel_trap", g, t["params"]).dy)
		var voet := World.scherm_doel(dx, float(m["zTop"]), 0.0).y
		var anker := (Art.DIER_ANKER.x + Art.DIER_ANKER.y) * (Art.S / 2.0) * float(g)
		for soort in ArtGasten.SOORTEN:
			var pl = Art.dier(soort, "blij", g)
			var kop := voet + float(pl.dy) - anker
			waar(trap_top + float(g) <= kop,
				"%s: ook boven een %s (%.1f tegen %.1f)"
					% [str(kader), soort, trap_top, kop])
		await _af()
	# 3. and at the end of a real turn, when he dances on the staircase, nothing
	#    of the game lands on the board: the number of the target is the board's
	#    own, so the guest's counting chip makes way for it
	for kader in KADERS:
		_op(kader)
		var n3 := await _speel(5, 1, 3)
		if n3 == null:
			await _af()
			continue
		_maak_af(n3)
		Hits.plaats()
		gelijk(str(n3.proef_stand()["fase"]), "af", "%s: de beurt is af" % str(kader))
		waar(Hits.spot("hk_gast") == null,
			"%s: de cijferchip maakt plaats voor het doelbord" % str(kader))
		var t3: Dictionary = n3.proef_trap_plek()
		var bord := World.vlak_van("hinkel_trap", float(t3["x"]), float(t3["z"]), 0.0,
			t3["params"])
		var dbg := Hits.debug()
		for id in dbg.keys():
			if not str(id).begins_with("hk_"):
				continue
			var r: Rect2 = dbg[id]["rect"]
			var sn := r.intersection(bord)
			gelijk(maxf(0.0, sn.size.x) * maxf(0.0, sn.size.y), 0.0,
				"%s: %s laat het doelbord heel" % [str(kader), id])
		await _af()
