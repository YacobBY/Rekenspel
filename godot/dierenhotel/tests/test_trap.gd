extends Proef
## The stairs between the floors (owner, 2026-09-24: "Ik wil de winkels op een
## andere etage. Het is de bedoeling dat het hotel heel groot en hoog aanvoelt
## net als Habbo Hotel. Op de begane grond zijn enkel de buiten dingen als het
## zwembad en de tuin"; a lift until 2026-09-25: "Ik wil graag de lift
## vervangen voor een trap"; two flights since 2026-10-01: "ik wil dat je bij
## de trap tussen etages beweegt misschien een trap omhoog en een omlaag").
## The floors themselves are data and `test_rooms.gd` holds them; this is what
## the child meets, on the real shell: a flight up and a flight down in every
## room the stairs reach — only the ones that go somewhere — each with its own
## sign, one tap is one floor with the camera and the footsteps going that way,
## and a guest takes the flight that goes his way.

## The shells of the suite: tablet landscape and portrait, phone portrait and
## landscape.
const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740),
	Vector2i(740, 360)]

## Which flights each stair room has, and where each one leads: one floor up or
## down, to the stairs of that floor.  The guest rooms on the first floor
## (owner, 2026-10-01: "Maak de kamers de eerste verdieping"), the shops over
## them and the playroom on top.
const VLUCHTEN := {
	"speelzaal": {"af": "winkels"},
	"winkels": {"op": "speelzaal", "af": "gang"},
	"gang": {"op": "winkels", "af": "receptie"},
	"receptie": {"op": "gang", "af": "wasserij"},
	"wasserij": {"op": "receptie"},
}

var _genomen: Array = []

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
	var kader: Control = shell.get_node("Scherm/Kolom/Middenrij/Kaderdoos/Kader")
	return {"vp": vp, "shell": shell, "kader": kader}

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

## Until the camera has stopped sliding (a headless frame can be much shorter
## than a drawn one), at most a few hundred frames.
func _tot_stil() -> void:
	for _f in 400:
		if not World.reist():
			break
		await _boom().process_frame
	await _frames(3)

# ------------------------------------------------------------------ de vluchten

## Up where a floor above has stairs, down where a floor below has them —
## and only there: the top floor only goes down, the cellar only up, and a
## room the stairs do not reach has neither.  Each flight leads exactly one
## floor, to the stairs of that floor.
func test_een_trap_omhoog_en_een_trap_omlaag_waar_ze_ergens_heen_gaan() -> void:
	gelijk(Rooms.trap_kamers().size(), VLUCHTEN.size(), "de trap komt in vijf kamers")
	for kamer in Rooms.lijst():
		var verwacht: Dictionary = VLUCHTEN.get(kamer, {})
		var hoort: Array[String] = []
		for richting in ["op", "af"]:
			if verwacht.has(richting):
				hoort.append(richting)
		gelijk(Rooms.trap_richtingen(kamer), hoort, "%s: de juiste vluchten" % kamer)
		for richting in ["op", "af"]:
			var naar := Rooms.trap_naar(kamer, richting)
			gelijk(naar, str(verwacht.get(richting, "")), "%s %s: waar hij heen gaat" % [kamer, richting])
			if naar.is_empty():
				waar(Rooms.trap_punt(kamer, richting).is_empty(), "%s %s: geen trap, geen punt" % [kamer, richting])
				continue
			gelijk(Rooms.etage(naar) - Rooms.etage(kamer), 1 if richting == "op" else -1,
				"%s %s: precies één verdieping" % [kamer, richting])
			gelijk(Rooms.trap_richting(kamer, naar), richting, "%s -> %s gaat %s" % [kamer, naar, richting])
			# and back the other way, on the other flight
			gelijk(Rooms.trap_naar(naar, "af" if richting == "op" else "op"), kamer,
				"%s %s: de andere vlucht daar brengt je terug" % [kamer, richting])

## Each flight is its own opening in a wall of its room: inside the wall, clear
## of the other flight and of every door in that wall, and its point (where a
## guest stands before he climbs) is a different one from the other flight's.
func test_elke_vlucht_heeft_een_eigen_opening() -> void:
	for kamer in Rooms.trap_kamers():
		var r := Rooms.get_kamer(kamer)
		var gaten: Array = []
		for richting in Rooms.trap_richtingen(kamer):
			var gat: Dictionary = r.trap[richting]
			var a := float(gat["at"])
			var b := a + float(gat["breed"])
			var lang := float(r.w) if str(gat["wand"]) == "z" else float(r.d)
			waar(a >= 2.0 and b <= lang - 2.0, "%s %s: in de wand (%s..%s van %s)" % [kamer, richting, a, b, lang])
			gaten.append({"wand": str(gat["wand"]), "a": a, "b": b, "wat": "trap " + richting})
		for dr in r.deuren:
			gaten.append({"wand": str(dr["wand"]), "a": float(dr["at"]), "b": float(dr["at"]) + float(dr["breed"]),
				"wat": "deur " + str(dr["naar"])})
		for i in gaten.size():
			for j in range(i + 1, gaten.size()):
				var p: Dictionary = gaten[i]
				var q: Dictionary = gaten[j]
				if p["wand"] != q["wand"]:
					continue
				# a frame post on each side: at least two voxels of wall between
				waar(float(p["b"]) + 2.0 <= float(q["a"]) or float(q["b"]) + 2.0 <= float(p["a"]),
					"%s: %s en %s staan niet in elkaar" % [kamer, p["wat"], q["wat"]])
		if Rooms.trap_richtingen(kamer).size() == 2:
			var op := Rooms.trap_punt(kamer, "op")
			var af := Rooms.trap_punt(kamer, "af")
			waar(Vector2(op["ix"], op["iz"]) != Vector2(af["ix"], af["iz"]),
				"%s: omhoog en omlaag hebben elk hun eigen punt" % kamer)

## Every way between two floors takes the flight that goes that way: the door
## point of the step up is on the flight up, the step down on the flight down —
## from every stair room to every other, however many floors apart.
func test_de_route_neemt_de_vlucht_die_zijn_kant_op_gaat() -> void:
	for van in Rooms.trap_kamers():
		for naar in Rooms.trap_kamers():
			if van == naar:
				continue
			var richting := Rooms.trap_richting(van, naar)
			var dp := Rooms.deur(van, naar)
			var lp := Rooms.trap_punt(van, richting)
			waar(not lp.is_empty(), "%s -> %s: de vlucht %s is er" % [van, naar, richting])
			waar(Rooms.via_trap(van, naar), "%s -> %s gaat met de trap" % [van, naar])
			gelijk(Vector2(dp.get("ix", -1.0), dp.get("iz", -1.0)), Vector2(lp.get("ix", -2.0), lp.get("iz", -2.0)),
				"%s -> %s: via de trap %s" % [van, naar, richting])
			gelijk(str(dp.get("richting", "")), richting, "%s -> %s: het punt zegt welke vlucht" % [van, naar])

# ------------------------------------------------------------------ de knoppen

## A sign on every flight — `⬆ Omhoog` on the one up, `⬇ Omlaag` on the one
## down — and none for a flight that is not there, nor a door sign per floor.
## Each is a door sign (`hotdeur`) that hangs at its own opening and never on
## the other flight's; no button of the room overlaps another, and on a tablet
## both signs stand ON their doors (the door sign rule), on every screen.
func test_elke_vlucht_heeft_een_eigen_bordje() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	for maat in SCHERMEN:
		var h: Dictionary = await _hotel_op(maat)
		var kader: Control = h["kader"]
		var tablet: bool = mini(maat.x, maat.y) >= 400
		for kamer in Rooms.lijst():
			await _naar(kamer)
			var wat := "%s %s" % [str(maat), kamer]
			waar(Hits.spot("trap_" + kamer) == null, "%s: geen oude trapknop" % wat)
			for ander in Rooms.trap_kamers():
				waar(Hits.spot("deur_%s_%s" % [kamer, ander]) == null or not Rooms.via_trap(kamer, ander),
					"%s: geen deurknop per verdieping (%s)" % [wat, ander])
			var dbg := Hits.debug()
			for richting in ["op", "af"]:
				var id := Hotel.trap_knop_id(kamer, richting)
				var s := Hits.spot(id)
				var hoort := Rooms.trap_richtingen(kamer).has(richting)
				waar((s != null) == hoort, "%s: een bordje %s precies waar die vlucht is" % [wat, richting])
				if s == null:
					continue
				waar(s.klas.contains("hotdeur"), "%s: %s is een deurbordje" % [wat, id])
				waar(s.knoop != null and s.knoop.visible, "%s: %s staat in beeld" % [wat, id])
				var knop := s.knoop as Button
				var tekst := "⬆ Omhoog" if richting == "op" else "⬇ Omlaag"
				gelijk(knop.text if knop != null else "", tekst, "%s: pictogram én woord" % wat)
				gelijk(Ui.mist_tekens(tekst), [] as Array[String], "%s: elk teken bestaat in de letters" % wat)
				var vlak := World.vlak_van_trap(kamer, richting)
				waar(vlak.size.x > 0.0 and vlak.size.y > 0.0, "%s: de vlucht %s heeft een vlak" % [wat, richting])
				# where `Hits` put it, in frame units like the flight's rectangle
				var r: Rect2 = (dbg.get(id, {}) as Dictionary).get("rect", Rect2())
				var plek := str((dbg.get(id, {}) as Dictionary).get("deurplek", ""))
				waar(Hits.DEURPLEK.has(plek), "%s: %s staat op zijn opening of erboven (%s)" % [wat, id, plek])
				if tablet:
					gelijk(plek, "deur", "%s: op een tablet hangt %s midden op zijn opening" % [wat, id])
				# the middle of its own opening under the sign, never the other one's
				var hart := vlak.get_center().x
				waar(r.position.x <= hart and r.end.x >= hart,
					"%s: %s hangt bij zijn eigen vlucht (%s, vlucht %s)" % [wat, id, str(r), str(vlak)])
				var ander := World.vlak_van_trap(kamer, "af" if richting == "op" else "op")
				if ander.size.x > 0.0:
					waar(not r.intersects(ander), "%s: %s bedekt de andere vlucht niet (%s, %s)"
						% [wat, id, str(r), str(ander)])
				waar(r.position.x >= -0.5 and r.end.x <= kader.size.x + 0.5,
					"%s: %s staat binnen het kader" % [wat, id])
			# nothing in the room overlaps anything else
			var rechthoeken := {}
			for id in dbg.keys():
				var s := Hits.spot(id)
				if s != null and is_instance_valid(s.knoop) and s.knoop.visible:
					rechthoeken[id] = dbg[id]["rect"]
					waar(not bool(dbg[id]["krap"]), "%s: %s heeft ruimte" % [wat, id])
			var ids: Array = rechthoeken.keys()
			for i in ids.size():
				for j in range(i + 1, ids.size()):
					var p: Rect2 = rechthoeken[ids[i]]
					var q: Rect2 = rechthoeken[ids[j]]
					waar(not p.grow(-0.5).intersects(q.grow(-0.5)),
						"%s: %s en %s overlappen niet (%s, %s)" % [wat, ids[i], ids[j], str(p), str(q)])
		await _hotel_af(h)
	Ui.zet_rust_modus(rust)
	State.s = bewaard

## A tap on a flight's sign goes exactly one floor up or down, straight to the
## stairs there — no panel in between — with the camera sliding the new floor
## in from above (up) or from below (down) and footsteps climbing or going
## down.  Every flight of every room, one after the other, as a child takes
## them: up from the cellar to the top, and down again.
func test_omhoog_en_omlaag_is_precies_een_verdieping() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(false)
	var wakker: bool = Snd.get("_wakker")
	var uit: bool = Snd.get("_uit")
	Snd.set("_wakker", true)
	Snd.set("_uit", false)
	var h: Dictionary = await _hotel_op(SCHERMEN[0])
	_genomen.clear()
	var neem := func(van: String, naar: String, richting: String) -> void:
		_genomen.append([van, naar, richting])
	Hotel.trap_genomen.connect(neem)
	var gehoord: Array[String] = []
	var hoor := func(naam: String) -> void: gehoord.append(naam)
	Snd.gespeeld.connect(hoor)
	await _naar("wasserij")
	await _frames(40)
	# the climb: the cellar to the top floor, then all the way down again
	var ritten: Array = []
	for kamer in ["wasserij", "receptie", "gang", "winkels"]:
		ritten.append([kamer, "op"])
	for kamer in ["speelzaal", "winkels", "gang", "receptie"]:
		ritten.append([kamer, "af"])
	for rit in ritten:
		var van: String = rit[0]
		var richting: String = rit[1]
		var naar: String = VLUCHTEN[van][richting]
		var wat := "%s %s" % [van, richting]
		gelijk(World.kamer_nu(), van, "%s: hier staan we" % wat)
		await _tot_stil()             # the last slide is done
		var s := Hits.spot(Hotel.trap_knop_id(van, richting))
		waar(s != null and is_instance_valid(s.knoop), "%s: het bordje is er" % wat)
		if s == null or not is_instance_valid(s.knoop):
			break
		gehoord.clear()
		_genomen.clear()
		(s.knoop as BaseButton).emit_signal("pressed")
		var zij: Vector2 = World.get("_reis_zij")
		waar(World.reist(), "%s: de camera beweegt" % wat)
		if richting == "op":
			waar(zij.x == 0.0 and zij.y < 0.0, "%s: de verdieping erboven komt van boven (%s)" % [wat, str(zij)])
			waar(gehoord.has("trap_op") and not gehoord.has("trap_af"), "%s: voetstappen de trap op (%s)" % [wat, str(gehoord)])
		else:
			waar(zij.x == 0.0 and zij.y > 0.0, "%s: de verdieping eronder komt van onder (%s)" % [wat, str(zij)])
			waar(gehoord.has("trap_af") and not gehoord.has("trap_op"), "%s: voetstappen de trap af (%s)" % [wat, str(gehoord)])
		waar(not gehoord.has("deur"), "%s: geen deur (%s)" % [wat, str(gehoord)])
		gelijk(World.kamer_nu(), naar, "%s: precies één verdieping verder, bij de trap" % wat)
		gelijk(_genomen, [[van, naar, richting]], "%s: de shell hoort welke trap" % wat)
		await _frames(3)
		waar(not Ui.blad_open_nu(), "%s: geen paneel ertussen" % wat)
	await _tot_stil()
	waar(not World.reist(), "de rit is voorbij")
	Snd.gespeeld.disconnect(hoor)
	Hotel.trap_genomen.disconnect(neem)
	for p in Snd.get("_spelers"):
		(p as AudioStreamPlayer).stop()
		(p as AudioStreamPlayer).stream = null
	Snd._sfeer_stop()
	Snd.set("_wakker", wakker)
	Snd.set("_uit", uit)
	await _hotel_af(h)
	Ui.zet_rust_modus(rust)
	State.s = bewaard

## A flight that is not there goes nowhere: the top floor has no way up, the
## cellar no way down.
func test_geen_trap_omhoog_vanaf_de_bovenste_verdieping() -> void:
	waar(not Hotel.neem_trap("speelzaal", "op"), "de speelzaal is de bovenste verdieping")
	waar(not Hotel.neem_trap("wasserij", "af"), "onder de kelder is niets")
	waar(not Hotel.neem_trap("tuin", "op"), "in de tuin is geen trap")

# ------------------------------------------------------------------ de rit

## To another floor by the room bar or the map you take the stairs as well:
## the new floor slides in from ABOVE going up and from BELOW going down, with
## footsteps climbing up or going down; on the same floor it is the sideways
## slide and the door as always.
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

## On the think tick, step by step: a guest going UP walks to the flight up and
## steps off the flight DOWN of the floor he arrives on (he came up it); a guest
## going DOWN walks to the flight down and comes out of the flight up below.
## The last place he stood in the room he leaves, and the first in the room he
## enters, are those flights' points.
func test_omhoog_loopt_hij_de_trap_op_en_omlaag_de_trap_af() -> void:
	Rooms.herstel()
	var was: bool = Ui.rust_modus()
	Ui.set("_rust", false)
	# [from, to, the flight he leaves by, the flight he arrives by]
	for rit in [["receptie", "gang", "op", "af"], ["speelzaal", "receptie", "af", "op"],
			["winkels", "wasserij", "af", "op"], ["wasserij", "speelzaal", "op", "af"]]:
		var van: String = rit[0]
		var naar: String = rit[1]
		var wat := "%s -> %s" % [van, naar]
		var start := Vector2(Rooms.get_kamer(van).plekken[0][0], Rooms.get_kamer(van).plekken[0][1])
		var d := World.zet("t_vlucht", van, start.x, start.y, {"kind": "konijn"})
		var route := World.reis("t_vlucht", naar, {"na": "wacht"})
		gelijk(route, [van, naar], "%s: één keer de trap" % wat)
		var weg := Vector2.INF
		var aan := Vector2.INF
		var vorig := Vector2(d.x, d.z)
		var t := 0
		while d.kamer == van and t < 3000:
			vorig = Vector2(d.x, d.z)
			World._tik()
			t += 1
		weg = vorig
		if d.kamer == naar:
			aan = Vector2(d.x, d.z)
		var uit_lp := Rooms.trap_punt(van, str(rit[2]))
		var in_lp := Rooms.trap_punt(naar, str(rit[3]))
		gelijk(d.kamer, naar, "%s: hij is de trap genomen" % wat)
		var uit_p := Vector2(uit_lp["ix"], uit_lp["iz"])
		waar(weg.distance_to(uit_p) <= 3.0,
			"%s: hij liep naar de trap %s (%s, trap %s)" % [wat, rit[2], str(weg), str(uit_p)])
		var andere := Rooms.trap_punt(van, "af" if str(rit[2]) == "op" else "op")
		if not andere.is_empty():
			var andere_p := Vector2(andere["ix"], andere["iz"])
			waar(weg.distance_to(uit_p) < weg.distance_to(andere_p),
				"%s: naar de trap %s, niet naar de andere (%s)" % [wat, rit[2], str(andere_p)])
		var in_p := Vector2(in_lp["ix"], in_lp["iz"])
		waar(aan.distance_to(in_p) <= 3.0,
			"%s: hij komt uit de trap %s (%s, trap %s)" % [wat, rit[3], str(aan), str(in_p)])
		var daar := Rooms.trap_punt(naar, "af" if str(rit[3]) == "op" else "op")
		if not daar.is_empty():
			waar(aan.distance_to(in_p) < aan.distance_to(Vector2(daar["ix"], daar["iz"])),
				"%s: uit de trap %s, niet uit de andere" % [wat, rit[3]])
		World.weg("t_vlucht")
	Ui.set("_rust", was)
	World.naar("receptie")
