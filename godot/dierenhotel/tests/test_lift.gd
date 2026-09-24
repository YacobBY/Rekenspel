extends Proef
## The lift between the floors (owner, 2026-09-24: "Ik wil de winkels op een
## andere etage. Het is de bedoeling dat het hotel heel groot en hoog aanvoelt
## net als Habbo Hotel. Op de begane grond zijn enkel de buiten dingen als het
## zwembad en de tuin").  The floors themselves are data and `test_rooms.gd`
## holds them; this is what the child meets, on the real shell: one lift button
## in every room the lift stops in, the panel it opens, the ride on the camera
## and its chime, and a guest who takes the lift to his room.

const SCHERMEN := [Vector2i(1024, 768), Vector2i(360, 740)]

var _gevraagd: Array[String] = []

func _boom() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

func _frames(n: int) -> void:
	for _f in n:
		await _boom().process_frame

## The whole shell in a SubViewport, with a fresh hotel — as `test_hits.gd`
## builds it: the camera only moves when a viewport is registered.
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

func _naar(kamer: String) -> void:
	Hotel.naar_kamer(kamer)
	await _frames(3)

# ------------------------------------------------------------------ de knop

## One button on the lift in every room it stops in — never one per floor —
## and none where it does not stop.  It is a door sign (`hotdeur`), so it hangs
## by its opening like every door's sign, and it counts the wishes waiting on
## the other floors.
func test_elke_liftkamer_heeft_een_liftknop() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	for maat in SCHERMEN:
		var h: Dictionary = await _hotel_op(maat)
		for kamer in Rooms.lijst():
			await _naar(kamer)
			var s := Hits.spot("lift_" + kamer)
			var stopt := not Rooms.lift_punt(kamer).is_empty()
			waar((s != null) == stopt, "%s: een liftknop precies waar de lift stopt (%s)"
				% [str(maat), kamer])
			for ander in Rooms.lift_kamers():
				waar(Hits.spot("deur_%s_%s" % [kamer, ander]) == null or not Rooms.via_lift(kamer, ander),
					"%s: geen deurknop per verdieping in %s (%s)" % [str(maat), kamer, ander])
			if s == null:
				continue
			waar(s.klas.contains("hotdeur"), "%s: de liftknop is een deurbordje (%s)" % [str(maat), kamer])
			waar(s.knoop != null and s.knoop.visible, "%s: de liftknop staat in beeld (%s)" % [str(maat), kamer])
			var vlak := World.vlak_van_lift(kamer)
			waar(vlak.size.x > 0.0 and vlak.size.y > 0.0, "%s: de lift heeft een vlak (%s)" % [str(maat), kamer])
			var r: Rect2 = s.knoop.get_global_rect()
			# the sign stands on the opening or over the lintel: its middle
			# above the floor of the lift and within a sign's width of it
			waar(absf(r.get_center().x - vlak.get_center().x) <= r.size.x,
				"%s: de liftknop hangt bij de lift in %s (%s, lift %s)" % [str(maat), kamer, str(r), str(vlak)])
		await _hotel_af(h)
	Ui.zet_rust_modus(rust)
	State.s = bewaard

## A tap on the lift asks the shell for the tower, and the shell opens it under
## the lift's own title; a tap on a room there rides to it.
func test_de_liftknop_opent_de_toren() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	_gevraagd.clear()
	var h: Dictionary = await _hotel_op(SCHERMEN[0])
	var luister := func(k: String) -> void: _gevraagd.append(k)
	Hotel.lift_gevraagd.connect(luister)
	await _naar("receptie")
	var s := Hits.spot("lift_receptie")
	waar(s != null, "de lobby heeft een liftknop")
	if s != null:
		(s.knoop as BaseButton).emit_signal("pressed")
	await _frames(3)
	gelijk(_gevraagd, ["receptie"] as Array[String], "de tik vraagt om de lift vanuit de receptie")
	waar(Ui.blad_open_nu(), "het liftpaneel staat open")
	var kaart: UiPlattegrond = null
	if Ui.bladlaag != null:
		var gevonden := Ui.bladlaag.find_children("*", "UiPlattegrond", true, false)
		if not gevonden.is_empty():
			kaart = gevonden[0]
	waar(kaart != null, "in het paneel staat de toren")
	if kaart != null:
		var knop := kaart.knop_van("winkels")
		waar(knop != null, "met de winkels erin")
		if knop != null:
			knop.emit_signal("pressed")
		await _frames(3)
		gelijk(World.kamer_nu(), "winkels", "een tik op de winkels brengt je daarheen")
		waar(not Ui.blad_open_nu(), "en het paneel gaat dicht")
	Hotel.lift_gevraagd.disconnect(luister)
	await _hotel_af(h)
	Ui.zet_rust_modus(rust)
	State.s = bewaard

# ------------------------------------------------------------------ de rit

## To another floor the camera rides the lift: the new floor slides in from
## ABOVE going up and from BELOW going down, and the lift chimes; on the same
## floor it is the sideways slide and the door as always.
func test_een_andere_verdieping_is_een_liftrit() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(false)
	var wakker: bool = Snd.get("_wakker")
	var uit: bool = Snd.get("_uit")
	Snd.set("_wakker", true)
	Snd.set("_uit", false)
	var h: Dictionary = await _hotel_op(SCHERMEN[0])
	await _naar("receptie")
	await _frames(40)
	# what starts playing, straight from the signal: `gehoord()` keeps only the
	# last 32, so after a long suite its length says nothing
	var gehoord: Array[String] = []
	var hoor := func(naam: String) -> void: gehoord.append(naam)
	Snd.gespeeld.connect(hoor)
	# [from, to, up (+1) / down (-1) / same floor (0)]
	for rit in [["receptie", "winkels", 1], ["winkels", "wasserij", -1],
			["wasserij", "gang", 1], ["gang", "kamer1", 0], ["kamer1", "gang", 0],
			["gang", "receptie", -1], ["receptie", "tuin", 0]]:
		await _naar(str(rit[0]))
		await _frames(40)             # the last slide is done
		gehoord.clear()
		Hotel.naar_kamer(str(rit[1]))
		var zij: Vector2 = World.get("_reis_zij")
		var wat := "%s -> %s" % [rit[0], rit[1]]
		waar(World.reist(), "%s: de camera beweegt" % wat)
		match int(rit[2]):
			1:
				waar(zij.x == 0.0 and zij.y < 0.0, "%s: omhoog, de verdieping komt van boven (%s)" % [wat, str(zij)])
				waar(gehoord.has("lift"), "%s: de lift klinkt (%s)" % [wat, str(gehoord)])
			-1:
				waar(zij.x == 0.0 and zij.y > 0.0, "%s: omlaag, de verdieping komt van onder (%s)" % [wat, str(zij)])
				waar(gehoord.has("lift"), "%s: de lift klinkt (%s)" % [wat, str(gehoord)])
			_:
				waar(zij.y == 0.0 and zij.x != 0.0, "%s: op de verdieping schuift hij opzij (%s)" % [wat, str(zij)])
				waar(gehoord.has("deur") and not gehoord.has("lift"),
					"%s: een deur, geen lift (%s)" % [wat, str(gehoord)])
	await _frames(40)
	waar(not World.reist(), "de rit is voorbij")
	Snd.gespeeld.disconnect(hoor)
	for p in Snd.get("_spelers"):
		(p as AudioStreamPlayer).stop()
		(p as AudioStreamPlayer).stream = null
	Snd._sfeer_stop()
	Snd.set("_wakker", wakker)
	Snd.set("_uit", uit)
	await _hotel_af(h)
	Ui.zet_rust_modus(rust)
	State.s = bewaard

## `Snd.lift()` is a ding-dong: two struck tones, the second lower and later,
## short enough for its buffer, never clipping.
func test_het_liftgeluid() -> void:
	var b := Snd.monster("lift")
	waar(b.size() > 0, "de lift heeft een geluid")
	var piek := 0.0
	var eerste := -1
	var tweede := -1
	for i in b.size():
		piek = maxf(piek, absf(b[i]))
	for i in b.size():
		if eerste < 0 and absf(b[i]) > piek * 0.5:
			eerste = i
		if i > int(0.30 * Snd.SR) and tweede < 0 and absf(b[i]) > piek * 0.5:
			tweede = i
	waar(piek > 0.0 and piek < 1.0, "hoorbaar en zonder knip (%.3f)" % piek)
	waar(eerste >= 0 and eerste < int(0.05 * Snd.SR), "de eerste toon valt meteen in")
	waar(tweede >= int(0.34 * Snd.SR), "de tweede toon komt later (%d)" % tweede)

# ------------------------------------------------------------------ een gast

## A guest on his way from the lobby to a room upstairs walks into the lift and
## steps out of it on the guest floor — the lift is one step of his route.
func test_een_gast_neemt_de_lift() -> void:
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	World.zet("t_lift", "receptie", 72.0, 90.0, {"kind": "hond"})
	var route := World.reis("t_lift", "kamer2", {"x": 60.0, "z": 60.0, "na": "wacht"})
	gelijk(route, ["receptie", "gang", "kamer2"], "via de lift naar de gang, dan de kamer in")
	var d := World.dier("t_lift")
	gelijk(d.kamer, "kamer2", "hij is er")
	World.weg("t_lift")
	# and from the shops to the pool: down in the lift, out the back door
	World.zet("t_lift", "winkels", 60.0, 60.0, {"kind": "poes"})
	gelijk(World.reis("t_lift", "zwembad"), ["winkels", "receptie", "tuin", "zwembad"],
		"de winkels uit, de lift af, de tuin door")
	World.weg("t_lift")
	Ui.zet_rust_modus(rust)
