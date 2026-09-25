extends Proef
## The stairs between the floors (owner, 2026-09-24: "Ik wil de winkels op een
## andere etage. Het is de bedoeling dat het hotel heel groot en hoog aanvoelt
## net als Habbo Hotel. Op de begane grond zijn enkel de buiten dingen als het
## zwembad en de tuin"; a lift until 2026-09-25: "Ik wil graag de lift
## vervangen voor een trap").  The floors themselves are data and
## `test_rooms.gd` holds them; this is what the child meets, on the real shell:
## one stairs button in every room the stairs reach, with a drawn pictogram,
## the panel it opens, the camera going up or down with footsteps, and a guest
## who takes the stairs to his room.

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

## One button on the stairs in every room they reach — never one per floor —
## and none where they do not.  It is a door sign (`hotdeur`), so it hangs by
## its opening like every door's sign, and it counts the wishes waiting on the
## other floors.  Its pictogram is drawn (there is no stairs emoji), and it
## says `Trap` — never the lift's 🛗.
func test_elke_trapkamer_heeft_een_trapknop() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	for maat in SCHERMEN:
		var h: Dictionary = await _hotel_op(maat)
		for kamer in Rooms.lijst():
			await _naar(kamer)
			var s := Hits.spot("trap_" + kamer)
			var stopt := not Rooms.trap_punt(kamer).is_empty()
			waar((s != null) == stopt, "%s: een trapknop precies waar de trap komt (%s)"
				% [str(maat), kamer])
			for ander in Rooms.trap_kamers():
				waar(Hits.spot("deur_%s_%s" % [kamer, ander]) == null or not Rooms.via_trap(kamer, ander),
					"%s: geen deurknop per verdieping in %s (%s)" % [str(maat), kamer, ander])
			if s == null:
				continue
			waar(s.klas.contains("hotdeur"), "%s: de trapknop is een deurbordje (%s)" % [str(maat), kamer])
			waar(s.knoop != null and s.knoop.visible, "%s: de trapknop staat in beeld (%s)" % [str(maat), kamer])
			var knop := s.knoop as Button
			gelijk(knop.text if knop != null else "", "Trap", "%s: het woord (%s)" % [str(maat), kamer])
			waar(knop != null and knop.icon == UiTrapIcoon.beeld(),
				"%s: met het getekende trapje ervoor (%s)" % [str(maat), kamer])
			waar(knop != null and knop.get_combined_minimum_size().x
				> knop.get_theme_font("font").get_string_size("Trap", HORIZONTAL_ALIGNMENT_LEFT, -1,
					knop.get_theme_font_size("font_size")).x + 12.0,
				"%s: het trapje neemt echt plaats in naast het woord (%s)" % [str(maat), kamer])
			var vlak := World.vlak_van_trap(kamer)
			waar(vlak.size.x > 0.0 and vlak.size.y > 0.0, "%s: de trap heeft een vlak (%s)" % [str(maat), kamer])
			var r: Rect2 = s.knoop.get_global_rect()
			# the sign stands on the opening or over the lintel: its middle
			# above the foot of the stairs and within a sign's width of it
			waar(absf(r.get_center().x - vlak.get_center().x) <= r.size.x,
				"%s: de trapknop hangt bij de trap in %s (%s, trap %s)" % [str(maat), kamer, str(r), str(vlak)])
		await _hotel_af(h)
	Ui.zet_rust_modus(rust)
	State.s = bewaard

## A tap on the stairs asks the shell for the tower, and the shell opens it
## under the stairs' own title, with the drawn pictogram before it; a tap on a
## room there goes to it.
func test_de_trapknop_opent_de_toren() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	_gevraagd.clear()
	var h: Dictionary = await _hotel_op(SCHERMEN[0])
	var luister := func(k: String) -> void: _gevraagd.append(k)
	Hotel.trap_gevraagd.connect(luister)
	await _naar("receptie")
	var s := Hits.spot("trap_receptie")
	waar(s != null, "de lobby heeft een trapknop")
	if s != null:
		(s.knoop as BaseButton).emit_signal("pressed")
	await _frames(3)
	gelijk(_gevraagd, ["receptie"] as Array[String], "de tik vraagt om de trap vanuit de receptie")
	waar(Ui.blad_open_nu(), "het trappaneel staat open")
	var blad := Ui.huidig_blad()
	var titel: Label = blad.find_child("Titel", true, false) if blad != null else null
	gelijk(titel.text if titel != null else "", "De trap", "onder de titel van de trap")
	var beeld: TextureRect = blad.find_child("Beeld", true, false) if blad != null else null
	waar(beeld != null and beeld.texture == UiTrapIcoon.beeld(), "met het trapje ervoor")
	if beeld != null and titel != null:
		waar(beeld.get_global_rect().end.x <= titel.get_global_rect().position.x + 0.5,
			"links van de titel (%s, %s)" % [str(beeld.get_global_rect()), str(titel.get_global_rect())])
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
	# the same tower as the map, so the same size: the picture before the title
	# adds no height (a wrapping title in a row once made the sheet a strip
	# taller, empty under `Sluiten`)
	h["shell"]._plattegrond()
	await _frames(3)
	var kaart_hoog := _blad_hoogte()
	h["shell"]._trap("receptie")
	await _frames(3)
	var trap_hoog := _blad_hoogte()
	waar(kaart_hoog > 0.0 and absf(trap_hoog - kaart_hoog) <= 4.0,
		"het trappaneel is zo hoog als de plattegrond (%.0f, %.0f)" % [trap_hoog, kaart_hoog])
	Ui.blad_dicht()
	Hotel.trap_gevraagd.disconnect(luister)
	await _hotel_af(h)
	Ui.zet_rust_modus(rust)
	State.s = bewaard

## The height of the sheet on screen, 0 without one.
func _blad_hoogte() -> float:
	var b := Ui.huidig_blad()
	var paneel: Control = b.get_node_or_null("Midden/Blad") if b != null else null
	return paneel.size.y if paneel != null else 0.0

# ------------------------------------------------------------------ de rit

## To another floor you take the stairs: the new floor slides in from ABOVE
## going up and from BELOW going down, with footsteps climbing up or going
## down; on the same floor it is the sideways slide and the door as always.
func test_een_andere_verdieping_is_de_trap() -> void:
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
				waar(gehoord.has("trap_op") and not gehoord.has("trap_af"),
					"%s: voetstappen de trap op (%s)" % [wat, str(gehoord)])
			-1:
				waar(zij.x == 0.0 and zij.y > 0.0, "%s: omlaag, de verdieping komt van onder (%s)" % [wat, str(zij)])
				waar(gehoord.has("trap_af") and not gehoord.has("trap_op"),
					"%s: voetstappen de trap af (%s)" % [wat, str(gehoord)])
			_:
				waar(zij.y == 0.0 and zij.x != 0.0, "%s: op de verdieping schuift hij opzij (%s)" % [wat, str(zij)])
				waar(gehoord.has("deur") and not gehoord.has("trap_op") and not gehoord.has("trap_af"),
					"%s: een deur, geen trap (%s)" % [wat, str(gehoord)])
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

## `Snd.trap(op)` is four footfalls on wooden treads, `Snd.TRAP_STAP` apart,
## with a moment of quiet after each; going up every step sounds higher than
## the one before, going down lower.  It fits its buffer, never clips, and has
## no noise in it, so it sounds the same every time.
func test_het_trapgeluid() -> void:
	waar(Snd.has_method("trap"), "Snd.trap() bestaat")
	for naam in ["trap_op", "trap_af"]:
		waar(not Snd.namen().has(naam), "%s staat niet in de tabel van de HTML" % naam)
		var b := Snd.monster(naam)
		gelijk(b.size(), int(float(Snd.LENGTE[naam]) * Snd.SR) + 64, "%s: zo lang als LENGTE zegt" % naam)
		waar(Snd.monster(naam) == b, "%s: twee keer precies hetzelfde" % naam)
		waar(not Snd.is_ruis(naam), "%s: zonder ruis" % naam)
		var piek := _hard(b, 0.0, float(Snd.LENGTE[naam]))
		waar(piek > 0.05 and piek < 1.0, "%s: hoorbaar en zonder knip (%.3f)" % [naam, piek])
		var tonen: Array[float] = []
		for stap in 4:
			var t := Snd.TRAP_STAP * float(stap)
			waar(_hard(b, t, t + 0.06) > piek * 0.3, "%s: stap %d klinkt" % [naam, stap + 1])
			waar(_hard(b, t + 0.10, t + Snd.TRAP_STAP - 0.005) < piek * 0.05,
				"%s: na stap %d is het even stil" % [naam, stap + 1])
			tonen.append(_toon(b, t + 0.03, t + 0.075))
		for stap in 3:
			if naam == "trap_op":
				waar(tonen[stap + 1] > tonen[stap] * 1.05,
					"%s: stap %d klinkt hoger dan stap %d (%s)" % [naam, stap + 2, stap + 1, str(tonen)])
			else:
				waar(tonen[stap + 1] < tonen[stap] / 1.05,
					"%s: stap %d klinkt lager dan stap %d (%s)" % [naam, stap + 2, stap + 1, str(tonen)])

## The loudest sample between two moments, in seconds.
func _hard(b: PackedFloat32Array, van: float, tot: float) -> float:
	var uit := 0.0
	for i in range(int(van * Snd.SR), mini(b.size(), int(tot * Snd.SR))):
		uit = maxf(uit, absf(b[i]))
	return uit

## The pitch between two moments, in Hz, from the zero crossings.
func _toon(b: PackedFloat32Array, van: float, tot: float) -> float:
	var eerste := -1
	var laatste := -1
	var n := 0
	for i in range(int(van * Snd.SR) + 1, mini(b.size(), int(tot * Snd.SR))):
		if (b[i - 1] < 0.0) != (b[i] < 0.0):
			if eerste < 0:
				eerste = i
			laatste = i
			n += 1
	if n < 2:
		return 0.0
	return float(n - 1) * 0.5 * float(Snd.SR) / float(laatste - eerste)

# ------------------------------------------------------------------ een gast

## A guest on his way from the lobby to a room upstairs walks up the stairs and
## steps off them on the guest floor — the stairs are one step of his route.
func test_een_gast_neemt_de_trap() -> void:
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	World.zet("t_trap", "receptie", 72.0, 90.0, {"kind": "hond"})
	var route := World.reis("t_trap", "kamer2", {"x": 60.0, "z": 60.0, "na": "wacht"})
	gelijk(route, ["receptie", "gang", "kamer2"], "de trap op naar de gang, dan de kamer in")
	var d := World.dier("t_trap")
	gelijk(d.kamer, "kamer2", "hij is er")
	World.weg("t_trap")
	# and from the shops to the pool: down the stairs, out the back door
	World.zet("t_trap", "winkels", 60.0, 60.0, {"kind": "poes"})
	gelijk(World.reis("t_trap", "zwembad"), ["winkels", "receptie", "tuin", "zwembad"],
		"de winkels uit, de trap af, de tuin door")
	World.weg("t_trap")
	Ui.zet_rust_modus(rust)
