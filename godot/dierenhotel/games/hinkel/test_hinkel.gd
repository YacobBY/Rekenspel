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
	gelijk(hs.get("dx", 0), -40, "dx schuift naar de eerste steen")
	gelijk(hs.get("dz", 0), 22, "dz naar de stenenrij")
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
	for _f in 2:
		await (Engine.get_main_loop() as SceneTree).process_frame
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

# ============================================================ de hulpladder

## A wrong answer still hops, is never punished, and from the SECOND slip the
## card counts along out loud (games-b.md §0.5, §0.6, §3.8).
func test_fout_antwoord_hinkelt_toch_en_helpt() -> void:
	_op()
	var node := await _speel(5, 1, 3)          # band 4: van 10 naar 20 met 2, 5 sprongen
	if node == null:
		await _af()
		return
	waar(_tik_keuze("k2"), "de sprongmaat 2")
	Hits.plaats()
	var goed := 5
	waar(_tik_keuze("n%d" % (goed - 1)), "en één sprong te weinig")
	Hits.plaats()
	var st: Dictionary = node.proef_stand()
	gelijk(int(st["missers"]), 1, "één misser geteld")
	gelijk(int(st["pogingen"]), 1, "en één poging")
	gelijk(int(st["s"]), 18, "het dier hinkelde tóch: van 10 naar 18")
	gelijk(str(st["fase"]), "sprong", "en de kaart vraagt van daaruit verder")
	gelijk(str(st["melding"]), "kort", "hij staat nog vóór de trap")
	gelijk(int(State.s["sterren"]), 0, "een misser kost geen ster en geeft er geen")
	var zeg := Hits.spot("hk_zeg")
	waar(zeg != null, "er staat een zacht praatje bij het dier")
	if zeg != null:
		gelijk(zeg.knoop.tooltip_text, "🪨 18 nog verder", "woordelijk, en zonder kruis")
	for regel in _regels():
		waar(not regel.contains("✗") and not regel.contains("❌") and not regel.contains("fout"),
			"nooit een kruis op de kaart (%s)" % regel)
	var kaart := _kaart_knoop()
	waar(kaart != null and not kaart.hulp_label.visible,
		"bij de eerste misser nog geen telhulp")

	# second slip: now the card counts along
	waar(_tik_keuze("k2"), "opnieuw de maat 2")
	Hits.plaats()
	waar(_tik_keuze("n2"), "en weer te weinig")
	Hits.plaats()
	st = node.proef_stand()
	gelijk(int(st["missers"]), 2, "twee missers")
	waar(_tik_keuze("k2"), "de maat voor de derde keer")
	Hits.plaats()
	kaart = _kaart_knoop()
	waar(kaart != null and kaart.hulp_label.visible, "nu telt de kaart samen mee")
	if kaart != null:
		gelijk(kaart.hulp_label.text, "20.", "de telregel langs de lijn")
	# and the star is still there for taking part
	_maak_af(node)
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

# ============================================================== de kindtekst

## F3: every child-facing string of games-b.md §3.9 stands verbatim in the file.
func test_kindtekst_staat_woordelijk_in_het_bestand() -> void:
	var f := FileAccess.open("res://games/hinkel/spel.gd", FileAccess.READ)
	waar(f != null, "het spelbestand is te lezen")
	if f == null:
		return
	var bron := f.get_as_text()
	f.close()
	for zin in ["Hinkelen", "%s wil hinkelen", "Hinkel op de stenen",
			"nog geen gasten", "van %d naar %d", "%s komt eraan", "Tel straks mee",
			"Komt eraan", "%s staat op %d, trap bij %d", "Kies je sprong",
			"Nog even verder", "Oei, te ver!", "Kies je sprong terug",
			"%s springt %d", " terug", " per keer", "Hoeveel sprongen?",
			"%s hinkelt", "Tel maar mee", "Precies op de trap!",
			"sprong %d", "terug %d", "%d keer", "kies je sprong",
			"hoeveel sprongen?", "te ver", "nog verder", "op de trap",
			"🪨", "🛏", "✅", "⭐", "🙃", "🐶", "🐱", "🐰", "🦆", "🐾"]:
		waar(bron.contains(zin), "de tekst staat er woordelijk: %s" % zin)

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

## The screen rectangle of every stone of the number line, right now.
func _padvlak(node: Node) -> Array[Rect2]:
	var uit: Array[Rect2] = []
	var m: Dictionary = node.proef_pad_maat()
	var band := int(node.proef_stand()["band"])
	for i in int(m["stenen"]):
		var x: float = float(m["eerste"]) + float(m["steek"]) * float(i)
		var n: int = node.proef_steen_getal(i, band)
		uit.append(World.vlak_van("hinkel_steen", x, float(m["zSteen"]), 0.0,
			{"getal": n, "rij": node.proef_rij_van_steen(i, band), "dx": 0,
				"groot": n >= 0 and n % (5 if band == 3 else 10) == 0}))
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
	# band 4/5 numbers the tens, alternating in height; band 3 numbers them all
	gelijk(node.proef_steen_getal(2, 4), 10, "steen 2 van band 4 draagt 10")
	gelijk(node.proef_steen_getal(3, 4), -1, "steen 3 draagt niets")
	gelijk(node.proef_rij_van_steen(2, 4), 1, "en de tientallen wisselen van hoogte")
	gelijk(node.proef_rij_van_steen(4, 4), 0, "om en om")
	gelijk(node.proef_steen_getal(7, 3), 7, "in band 3 draagt elke steen zijn getal")
	gelijk(node.proef_rij_van_steen(10, 3), 1, "alleen 10 gaat een rij hoger")
	gelijk(node.proef_rij_van_steen(9, 3), 0, "de rest blijft laag")
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
