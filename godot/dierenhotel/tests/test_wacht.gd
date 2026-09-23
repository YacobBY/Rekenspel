extends Proef
## `ctx.wacht_op(gast, plek)` (spel/ctx.gd) — the game begins when its animal
## is there (owner, 2026-09-23: "Zorg dat de minigame pas begint wanneer het
## dier er is").  Driven on the reference game `_voorbeeld` (the corridor),
## whose own start never waits: every wait here is the test's own, on that
## game's ctx, with the world ticked by hand as in tests/test_komt.gd.

var _laag: Control = null
var _rust_voor := false
var _bewaard: Dictionary = {}
var _uit: Dictionary = {}          ## how a wait that runs in the background ended

# ------------------------------------------------------------------ opzet

func _op() -> void:
	_bewaard = State.s.duplicate(true)
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = Vector2(1000, 648)
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	_rust_voor = Ui.rust_modus()
	Ui.zet_rust_modus(false)
	World.meet(Rect2(Vector2.ZERO, _laag.size))
	World.pauzeer(true)                 # the test ticks the world itself
	World.zet("w_boef", "kamer1", 60.0, 60.0, {"kind": "hond", "naam": "Boef"})
	waar(Games.start("_voorbeeld"), "het voorbeeldspel start")
	gelijk(World.kamer_nu(), "gang", "de camera staat in de gang")

func _af() -> void:
	Games.stop()
	World.pauzeer(false)
	World.weg("w_boef")
	World.weg("w_pluis")
	Hotel.stop_volgen()
	Hotel.komt_eraan()
	Hits.wis_alles()
	World.decor_wis_alles()
	Ui.zet_rust_modus(_rust_voor)
	Ui.registreer_lagen(null, null, null)
	if _laag != null:
		_laag.queue_free()
		_laag = null
	State.s = _bewaard
	await _frames(2)

func _ctx() -> SpelCtx:
	return Games._ctx.get("_voorbeeld")

## A free place in the corridor: its first wander place.
func _plek(i := 0) -> Vector2:
	var p: Array = Rooms.get_kamer("gang").plekken[i]
	return Vector2(float(p[0]), float(p[1]))

func _frames(n := 2) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	for _i in n:
		await boom.process_frame

## Let a wait run in the background; `_uit` says how it ended.
func _wacht_los(gast: String, plek: Vector2, o: Dictionary = {}) -> void:
	_uit = {"klaar": false, "er": false}
	var er: bool = await _ctx().wacht_op(gast, plek, o)
	_uit = {"klaar": true, "er": er}

## Real time (frames keep running) until the background wait has ended.
func _klaar_binnen(ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while not bool(_uit.get("klaar", false)) and Time.get_ticks_msec() - t0 < ms:
		await _frames(1)
	return bool(_uit.get("klaar", false))

## Tick until `id` stands still in `kamer`: arrived, not walking any more.
func _tik_tot_hij_staat(id: String, kamer: String) -> bool:
	var d = World.dier(id)
	var t := 0
	while d != null and t < 4000 and not (d.kamer == kamer and str(d.reis_doel).is_empty()
			and (d.route as Array).is_empty() and (d.punten as Array).is_empty()):
		World._tik()
		t += 1
	return d != null and d.kamer == kamer and (d.punten as Array).is_empty()

# ------------------------------------------------------------------ tests

## He is there already: true at once, in the very same call — not one frame in
## between — and he takes his place for the turn ("wacht": no wandering off
## from under the card).
func test_staat_hij_er_al_dan_meteen() -> void:
	_op()
	World.zet("w_boef", "gang", _plek().x, _plek().y, {"kind": "hond", "naam": "Boef"})
	var f := Engine.get_process_frames()
	var er: bool = await _ctx().wacht_op("w_boef", _plek())
	waar(er, "hij staat er: waar")
	gelijk(Engine.get_process_frames(), f, "in dezelfde frame, zonder één beeld te wachten")
	waar(not Games.verwacht_dier("w_boef"), "er werd op niemand gewacht")
	gelijk(World.dier("w_boef").staat, "wacht", "en hij wacht op zijn plek")
	await _af()

## From another room he is sent through the doors, the game waits for him —
## the hotel keeps his "komt eraan" bubble in view during the game — and the
## wait ends the moment he stands at his place.
func test_van_elders_loopt_hij_eerst_naar_zijn_plek() -> void:
	_op()
	_wacht_los("w_boef", _plek())
	waar(not bool(_uit["klaar"]), "hij is er nog niet: het wachten loopt")
	waar(Games.verwacht_dier("w_boef"), "het spel wacht op hem")
	gelijk(str(World.dier("w_boef").reis_doel), "gang", "hij is op weg naar de gang")
	Hotel.komt_eraan()
	Hits.plaats()
	var w := Hits.spot("komt_w_boef")
	waar(w != null and is_instance_valid(w.knoop) and w.knoop.visible,
		"zijn wolkje 'komt eraan' staat in beeld, ook nu er een spel loopt")
	waar(_tik_tot_hij_staat("w_boef", "gang"), "hij loopt de gang in, naar zijn plek")
	waar(await _klaar_binnen(1500), "hij staat er: het wachten is voorbij")
	waar(bool(_uit["er"]), "met waar")
	waar(not Games.verwacht_dier("w_boef"), "en er wordt niet meer op hem gewacht")
	var d = World.dier("w_boef")
	waar(Vector2(d.x, d.z).distance_to(_plek()) <= 3.0, "op zijn plek")
	gelijk(d.staat, "wacht", "waar hij blijft staan")
	Hotel.komt_eraan()
	waar(Hits.spot("komt_w_boef") == null, "zijn wolkje is weg")
	await _af()

## The game stops while it waits: the wait says false and nobody is awaited.
func test_een_stop_breekt_het_wachten_af() -> void:
	_op()
	_wacht_los("w_boef", _plek())
	waar(Games.verwacht_dier("w_boef"), "het spel wacht op hem")
	Games.stop()
	waar(not Games.verwacht_dier("w_boef"), "na de stop wacht er niemand meer")
	waar(await _klaar_binnen(1000), "het wachten houdt op")
	waar(not bool(_uit["er"]), "met onwaar: het spel is gestopt")
	await _af()

## Reduced motion resolves every walk at once (world.md §2.5): from another room
## he is at his place in the same call, and the wait is over before it began.
func test_in_rust_is_hij_er_meteen() -> void:
	_op()
	Ui.zet_rust_modus(true)
	var f := Engine.get_process_frames()
	var er: bool = await _ctx().wacht_op("w_boef", _plek())
	waar(er, "in rust: waar")
	gelijk(Engine.get_process_frames(), f, "in dezelfde frame")
	var d = World.dier("w_boef")
	gelijk(d.kamer, "gang", "hij is door de deur")
	waar(Vector2(d.x, d.z).distance_to(_plek()) <= 3.0, "en staat op zijn plek")
	gelijk(d.staat, "wacht", "waar hij wacht")
	waar(not Games.verwacht_dier("w_boef"), "er is op niemand gewacht")
	await _af()

## A fresh start of the same game — exactly what the animal switch on the game
## bar is (`Games.wissel_speler`) — ends the wait of the start before it; the
## new start waits for its own animal.
func test_een_nieuwe_start_breekt_het_wachten_af() -> void:
	_op()
	World.zet("w_pluis", "kamer2", 60.0, 60.0, {"kind": "konijn", "naam": "Pluis"})
	_wacht_los("w_boef", _plek())
	waar(Games.verwacht_dier("w_boef"), "het spel wacht op Boef")
	waar(Games.start("_voorbeeld"), "hetzelfde spel start opnieuw")
	waar(not Games.verwacht_dier("w_boef"), "op Boef wacht niemand meer")
	waar(await _klaar_binnen(1000), "het oude wachten houdt op")
	waar(not bool(_uit["er"]), "met onwaar")
	_wacht_los("w_pluis", _plek(1))
	waar(Games.verwacht_dier("w_pluis"), "de nieuwe start wacht op Pluis")
	waar(not Games.verwacht_dier("w_boef"), "en niet op Boef")
	waar(_tik_tot_hij_staat("w_pluis", "gang"), "Pluis loopt naar zijn plek")
	waar(await _klaar_binnen(1500), "en is er")
	waar(bool(_uit["er"]), "met waar")
	await _af()

## A walk that another order takes over (a wander, a game) is sent again, so a
## game never waits for an animal that is going nowhere.
func test_een_overgenomen_wandeling_wordt_opnieuw_gestuurd() -> void:
	_op()
	World.zet("w_boef", "gang", _plek(3).x, _plek(3).y, {"kind": "hond", "naam": "Boef"})
	_wacht_los("w_boef", _plek())
	var d = World.dier("w_boef")
	waar(not (d.punten as Array).is_empty(), "hij loopt naar zijn plek")
	World.ga("w_boef", _plek(2).x, _plek(2).y, "stil")
	waar(_tik_tot_hij_staat("w_boef", "gang"), "iets anders stuurde hem elders heen")
	waar(Vector2(d.x, d.z).distance_to(_plek(2)) <= 1.0, "daar staat hij nu")
	var t0 := Time.get_ticks_msec()
	while (d.punten as Array).is_empty() and Time.get_ticks_msec() - t0 < 2500:
		await _frames(1)
	waar(not (d.punten as Array).is_empty(), "na een tel wordt hij opnieuw gestuurd")
	waar(_tik_tot_hij_staat("w_boef", "gang"), "hij loopt alsnog")
	waar(await _klaar_binnen(1500), "en het wachten is voorbij")
	waar(bool(_uit["er"]), "met waar")
	await _af()
