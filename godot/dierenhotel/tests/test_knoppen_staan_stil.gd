extends Proef
## The hotel's buttons stand still (owner, 2026-09-24: "Wanneer boef binnenkomt
## wisselen de gang en prikbord icoontjes supervaak. Ik zie dat icoon indeling
## en consistentie nog steeds niet gefixt is").
##
## `Hits.plaats()` lays every button out again each frame.  A guest who walks
## through the room is not a reason for any of them to move: a door sign, the
## stairs, the board, the bell and a game's entry hang on things that do not
## move, so their places are the same in every frame the guest walks — on the
## real shell, at the screens the owner uses.

const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740)]
## the buttons of the lobby that hang on things standing still
const VAST := ["trap_receptie", "deur_receptie_tuin", "prikbord", "spel_meubels", "spel_sleutels"]

func _boom() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

func _frames(n: int) -> void:
	for _f in n:
		await _boom().process_frame

## The whole shell in a SubViewport, with a fresh hotel in the receptie.
func _hotel_op(maat: Vector2i) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = maat
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_boom().root.add_child(vp)
	var shell := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	shell.set_meta("geen_start", true)     # never touch the save from a test
	vp.add_child(shell)
	await _frames(4)
	State.nieuw_spel()
	Hotel.start()
	await _frames(4)
	return {"vp": vp, "shell": shell}

func _hotel_af(h: Dictionary) -> void:
	Ui.blad_dicht()
	Ui.naamplaten_leeg()
	Hits.wis_alles()
	(h["vp"] as SubViewport).queue_free()
	await _boom().process_frame
	Ui.registreer_lagen(null, null, null)
	State.nieuw_spel()

## Every visible hotspot's rectangle, right now.
func _rechthoeken() -> Dictionary:
	var uit := {}
	for id in Hits.debug().keys():
		var s := Hits.spot(id)
		if s != null and is_instance_valid(s.knoop) and s.knoop.visible:
			uit[id] = s.knoop.get_global_rect()
	return uit

## A guest rings in and walks from the front door to the desk: the buttons on
## still things keep one place the whole way.
func test_een_gast_die_binnenloopt_verschuift_geen_knop() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(false)
	for maat in SCHERMEN:
		var h: Dictionary = await _hotel_op(maat)
		Hotel.bord_dicht()
		await _frames(10)
		Hotel.bel()
		var gast := str((State.s["nieuweGast"] as Dictionary).get("id", "")) \
			if State.s["nieuweGast"] != null else ""
		waar(not gast.is_empty(), "%s: er komt een gast binnen" % str(maat))
		var sprongen := {}
		var vorig := _rechthoeken()
		var liep := 0
		var d := World.dier(gast)
		var plek := Vector2(d.x, d.z) if d != null else Vector2.ZERO
		for f in 240:
			# a headless frame takes no real time: the think tick is driven by
			# hand, one per frame, so the guest really crosses the lobby
			World._tik()
			await _frames(1)
			var nu := _rechthoeken()
			if d != null and Vector2(d.x, d.z).distance_to(plek) > 0.01:
				liep += 1
				plek = Vector2(d.x, d.z)
			for id in VAST:
				if nu.has(id) and vorig.has(id) and not (nu[id] as Rect2).is_equal_approx(vorig[id]):
					sprongen[id] = int(sprongen.get(id, 0)) + 1
					if int(sprongen[id]) <= 3:
						print("[sprong] %s f%d %s: %s -> %s" % [str(maat), f, id, str(vorig[id]), str(nu[id])])
			vorig = nu
		waar(liep > 20, "%s: de gast liep echt (%d frames)" % [str(maat), liep])
		for id in VAST:
			gelijk(int(sprongen.get(id, 0)), 0,
				"%s: %s staat stil terwijl de gast binnenloopt" % [str(maat), id])
		await _hotel_af(h)
	Ui.zet_rust_modus(rust)
	State.s = bewaard

## Guests walking about the lobby with no sum on screen — past the stairs, past
## the board, round the desk and back — move no sign and no button: they
## walk UNDER them.
func test_gasten_die_voorbijlopen_verschuiven_geen_knop() -> void:
	var sprongen: Dictionary = await _loop_rond([
		# Boef from the rug past the stairs to the bench and back to the rug
		["t_stil1", "hond", "Boef", Vector2(72, 96), [Vector2(10, 32), Vector2(30, 70), Vector2(80, 100)]],
		# Mispel from the bench round the desk past the garden door and back
		["t_stil2", "poes", "Mispel", Vector2(30, 60), [Vector2(104, 40), Vector2(90, 100), Vector2(20, 64)]],
	])
	for sleutel in sprongen:
		gelijk(int(sprongen[sleutel]), 0, "%s staat stil terwijl er gasten langslopen" % sleutel)

## A guest who STOPS on a button's place and waits there: the button steps
## aside once, stays aside while he waits — blinking, wagging and turning as he
## does — and goes back once when he walks on.  Never more than those two.
func test_een_gast_die_blijft_staan_duwt_een_knop_een_keer() -> void:
	# Boef walks to the stairs and waits in front of them, then walks back to the rug
	var sprongen: Dictionary = await _loop_rond([
		["t_stil1", "hond", "Boef", Vector2(72, 96), [Vector2(8, 30)]],
	], 100, [Vector2(72, 96)])
	for sleutel in sprongen:
		waar(int(sprongen[sleutel]) <= 2,
			"%s gaat hooguit één keer opzij en één keer terug (%d)" % [sleutel, int(sprongen[sleutel])])

## Let guests walk their legs for 200 think ticks (a leg starts when the last
## one is done; `terug` after `wacht` ticks), and count, per screen and
## button, how often a button of the lobby moved.  Name plates walk along with
## their guests and are not counted.
func _loop_rond(gasten: Array, wacht := 0, terug: Array = []) -> Dictionary:
	var bewaard: Dictionary = State.s.duplicate(true)
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(false)
	var uit := {}
	for maat in SCHERMEN:
		var h: Dictionary = await _hotel_op(maat)
		Hotel.bord_dicht()
		await _frames(6)
		var benen := {}
		for g in gasten:
			World.zet(str(g[0]), "receptie", (g[3] as Vector2).x, (g[3] as Vector2).y,
				{"kind": str(g[1]), "naam": str(g[2]), "nr": benen.size()})
			benen[str(g[0])] = (g[4] as Array).duplicate()
		await _frames(3)
		var vorig := _rechthoeken()
		for f in 200:
			for id in benen:
				var d := World.dier(id)
				var rest: Array = benen[id]
				if d != null and d.punten.is_empty() and d.staat != "loop" and not rest.is_empty():
					var p: Vector2 = rest.pop_front()
					World.ga(id, p.x, p.y, "wacht")
			if f == wacht and not terug.is_empty():
				for i in mini(terug.size(), gasten.size()):
					benen[str(gasten[i][0])] = [terug[i]]
			World._tik()
			await _frames(1)
			var nu := _rechthoeken()
			for id in nu.keys():
				if not vorig.has(id) or str(id).begins_with(Ui.PLAAT):
					continue
				if not (nu[id] as Rect2).is_equal_approx(vorig[id]):
					var sleutel := "%s %s" % [str(maat), id]
					uit[sleutel] = int(uit.get(sleutel, 0)) + 1
					if int(uit[sleutel]) <= 3:
						print("[sprong] %s f%d: %s -> %s" % [sleutel, f, str(vorig[id]), str(nu[id])])
			vorig = nu
		for g in gasten:
			World.weg(str(g[0]))
		await _hotel_af(h)
	Ui.zet_rust_modus(rust)
	State.s = bewaard
	return uit
