extends Proef
## Walking round things (owner, 2026-09-24: "Dieren lopen ook vaak door objecten
## heen als ze naar andere maps toe lopen en ik ze volg"): every leg a guest
## walks in a room goes round what stands there — `World.looppad`,
## `wereld/looppad.gd`, world.md §2.5.
##
## What a guest must not walk through is worked out HERE, on its own, from the
## voxels of every piece that stands in the room (`_voetafdrukken`): the rule is
## the one world.md §1.5 writes down (a column with a voxel between
## `WereldLooppad.VLOER` and `KOP` over the floor), not the grid the walking
## uses, so a mistake in the grid cannot hide itself.

const T := "t_loop"

func _af() -> void:
	for id in [T, "t_loop2"]:
		World.weg(id)
	World.decor_wis_eigenaar("proef")
	World.ding_thuis_zet("kar")
	Rooms.herstel()

# ----------------------------------------------------------------- de meetlat

## The footprints of everything that stands on the floor of a room right now:
## [{naam, kol: {Vector2i: true}, o: Vector2}] per piece (a column k covers the
## voxel square round o + k), and [{naam, rect}] for the water and the desk.
func _voetafdrukken(kamer: String) -> Array:
	var r := Rooms.get_kamer(kamer)
	var stukken: Array = []
	for stuk in r.decor:
		if bool(stuk.get("ver", false)) or bool(stuk.get("pol", false)):
			continue
		stukken.append([str(stuk["n"]), stuk.get("params", {}), float(stuk["x"]),
			float(stuk["z"]), float(stuk.get("y", 0.0)), int(stuk.get("rot", 0)), Vector2.ZERO])
	for sid in r.slots:
		var s: Dictionary = r.slots[sid]
		if str(s["soort"]) == "bak":
			stukken.append(["kom", {}, float(s["x"]), float(s["z"]), 0.0, 0, Art.KOM_ANKER])
		elif not str(s.get("model", "")).is_empty():
			stukken.append([str(s["model"]), {}, float(s["x"]), float(s["z"]), 0.0, 0, Vector2.ZERO])
	for ding in World.dingen(kamer):
		stukken.append([str(ding["model"]), {}, float(ding["x"]), float(ding["z"]),
			float(ding["hoog"]), 0, Vector2.ZERO])
	for los in World.decor_lijst(kamer):
		if not bool(los["ver"]):
			stukken.append([str(los["model"]), los["params"], float(los["x"]), float(los["z"]),
				float(los["hoog"]), int(los["rot"]), Vector2.ZERO])
	var uit: Array = []
	for s in stukken:
		var kol := {}
		for v in Art.model(s[0], s[1]):
			var h := int(v["y"]) + int(roundf(s[4]))
			if h < WereldLooppad.VLOER or h > WereldLooppad.KOP:
				continue
			var x := int(v["x"])
			var z := int(v["z"])
			for _i in posmod(int(s[5]), 4):
				var t := x
				x = z
				z = -t
			kol[Vector2i(x, z)] = true
		if not kol.is_empty():
			var anker: Vector2 = s[6]
			uit.append({"naam": s[0], "kol": kol, "o": Vector2(s[2], s[3]) - anker})
	if not r.bad.is_empty():
		uit.append({"naam": "water", "rect": Rect2(float(r.bad["x0"]), float(r.bad["z0"]),
			float(r.bad["x1"]) - float(r.bad["x0"]), float(r.bad["z1"]) - float(r.bad["z0"]))})
	if not r.balie.is_empty():
		uit.append({"naam": "balie", "rect": Rect2(float(r.balie["x0"]), 0.0,
			float(r.balie["x1"]) - float(r.balie["x0"]), float(r.balie["z1"]))})
	return uit

## The piece a floor point stands in, or "".
func _in(afdrukken: Array, p: Vector2) -> String:
	for a in afdrukken:
		if (a as Dictionary).has("rect"):
			var rect: Rect2 = a["rect"]
			if rect.has_point(p):
				return str(a["naam"])
			continue
		var rel: Vector2 = p - (a["o"] as Vector2)
		if (a["kol"] as Dictionary).has(Vector2i(roundi(rel.x), roundi(rel.y))):
			return str(a["naam"])
	return ""

## The first point of the line through `punten`, sampled every half voxel, that
## stands in a piece: "naam @ (x, z)", or "".
func _raakt(afdrukken: Array, punten: Array) -> String:
	for i in range(1, punten.size()):
		var a: Vector2 = punten[i - 1]
		var b: Vector2 = punten[i]
		var n := maxi(1, ceili(a.distance_to(b) * 2.0))
		for s in n + 1:
			var p := a.lerp(b, float(s) / n)
			var naam := _in(afdrukken, p)
			if naam != "":
				return "%s @ (%.1f, %.1f)" % [naam, p.x, p.y]
	return ""

static func _lengte(punten: Array) -> float:
	var som := 0.0
	for i in range(1, punten.size()):
		som += (punten[i - 1] as Vector2).distance_to(punten[i])
	return som

## The walk from a to b as the guest walks it: a, then `World.looppad`.
func _weg(kamer: String, a: Vector2, b: Vector2) -> Array:
	var uit: Array = [a]
	uit.append_array(World.looppad(kamer, a, b))
	return uit

## Every point a guest walks from or to in a room: its doors (the step inside,
## where he appears and where he leaves), the front door, every bed's standing
## place and the eating spot at every bowl.
func _plekken(kamer: String) -> Dictionary:
	var r := Rooms.get_kamer(kamer)
	var uit := {}
	for naar in r.deur_punten:
		var dp: Dictionary = r.deur_punten[naar]
		uit["deur " + str(naar)] = Vector2(dp["ix"], dp["iz"])
	var ing := Rooms.ingang(kamer)
	if not ing.is_empty():
		uit["voordeur"] = Vector2(ing["ix"], ing["iz"])
	for sid in r.slots:
		var s: Dictionary = r.slots[sid]
		if str(s["soort"]) == "bed" or str(s["soort"]) == "bak":
			uit[str(sid)] = Vector2(s["sx"], s["sz"])
	# and a few wander places a guest can stand on (`_vrije_plek` skips the rest)
	var rooster: WereldLooppad = World.looppad_rooster(kamer)
	var n := 0
	for p in r.plekken:
		var v := Vector2(p[0], p[1])
		if n < 4 and rooster.vrij(v):
			uit["plek %d,%d" % [int(v.x), int(v.y)]] = v
			n += 1
	return uit

## One walk checked the way the owner looks at it: it ends on its target, never
## goes into anything, and is not an absurd detour — at most 1.6 times the
## straight line (plus a step round a corner) where that line itself is free.
func _keur(kamer: String, afdrukken: Array, wat: String, a: Vector2, b: Vector2) -> Dictionary:
	var weg := _weg(kamer, a, b)
	gelijk(weg[weg.size() - 1], b, "%s: %s eindigt op zijn doel" % [kamer, wat])
	var raakt := _raakt(afdrukken, weg)
	waar(raakt == "", "%s: %s loopt nergens doorheen (%s, %s)" % [kamer, wat, raakt, str(weg)])
	var recht := a.distance_to(b)
	var lang := _lengte(weg)
	if _raakt(afdrukken, [a, b]) == "":
		waar(lang <= recht * 1.6 + 12.0, "%s: %s is geen omweg (%.0f tegen %.0f recht)"
			% [kamer, wat, lang, recht])
	else:
		waar(lang <= recht * 3.0 + 60.0, "%s: %s gaat er redelijk omheen (%.0f tegen %.0f)"
			% [kamer, wat, lang, recht])
	return {"weg": weg, "lang": lang, "recht": recht}

# ------------------------------------------------------------------- de paden

## For every room: door to door, door to every bed and bowl and back, and bed to
## bowl — the walk ends on its target, never enters a footprint and is no
## detour where the straight line is free.  Walks that hit something straight
## really do go round it now.
func test_elk_pad_blijft_uit_elke_voetafdruk() -> void:
	Rooms.herstel()
	var omwegen := 0
	var paren := 0
	for kamer in Rooms.lijst():
		var afdrukken := _voetafdrukken(kamer)
		var plekken := _plekken(kamer)
		for naam_a in plekken:
			var a: Vector2 = plekken[naam_a]
			waar(_in(afdrukken, a) == "", "%s: %s staat vrij (%s)" % [kamer, naam_a, _in(afdrukken, a)])
			for naam_b in plekken:
				if naam_a == naam_b:
					continue
				var b: Vector2 = plekken[naam_b]
				var uit := _keur(kamer, afdrukken, "%s -> %s" % [naam_a, naam_b], a, b)
				paren += 1
				if _raakt(afdrukken, [a, b]) != "":
					omwegen += 1
					waar((uit["weg"] as Array).size() > 2,
						"%s: %s -> %s gaat om iets heen" % [kamer, naam_a, naam_b])
				# natural diagonals, not a staircase of grid steps
				waar((uit["weg"] as Array).size() <= 8, "%s: %s -> %s heeft weinig hoeken (%d)"
					% [kamer, naam_a, naam_b, (uit["weg"] as Array).size()])
	waar(paren > 300, "genoeg paren gekeurd (%d)" % paren)
	waar(omwegen > 0, "de rechte lijn liep vroeger ergens doorheen (%d keer)" % omwegen)
	_af()

## The owner's own picture: from the kamer 1 door to the far bed.  Straight it
## cut through the corner of bed 2; now it goes round it and ends on the spot.
func test_van_de_deur_naar_bed2_om_het_bed_heen() -> void:
	Rooms.herstel()
	var afdrukken := _voetafdrukken("kamer1")
	var dp := Rooms.deur("kamer1", "gang")
	var bed := Rooms.slot("kamer1", "bed2")
	var a := Vector2(dp["ix"], dp["iz"])
	var b := Vector2(bed["sx"], bed["sz"])
	waar(_raakt(afdrukken, [a, b]).begins_with("bed"), "recht door ging door het bed (%s)"
		% _raakt(afdrukken, [a, b]))
	var uit := _keur("kamer1", afdrukken, "deur -> bed2", a, b)
	waar((uit["weg"] as Array).size() >= 3, "met een hoek erin")
	_af()

## A bed bought a minute ago and the food trolley pushed into a bedroom stand
## in the very next walk: the grid follows the room, not a list of its own.
func test_gekocht_bed_en_de_kar_staan_in_de_weg() -> void:
	Rooms.herstel()
	var oud: WereldLooppad = World.looppad_rooster("kamer1")
	gelijk(World.looppad_rooster("kamer1"), oud, "zolang er niets verandert, hetzelfde rooster")
	var bed := Rooms.meubel_zet("kamer1", "bed", 60.0, 72.0)
	waar(not bed.is_empty(), "het bed is gekocht")
	# across the bed, wherever the furniture rules put it — along its long
	# side: since the fixed bed places (2026-09-24) bed 3 of kamer 1 stands
	# between the bowl and bed 4, so across its short side runs into the bowl
	var mid := Vector2(float(bed.get("x", 60.0)), float(bed.get("z", 72.0)))
	var a := Vector2(mid.x - 32.0, mid.y)
	var b := Vector2(minf(mid.x + 30.0, float(Rooms.get_kamer("kamer1").w) - 8.0), mid.y)
	waar(World.looppad_rooster("kamer1") != oud, "een nieuw rooster na het nieuwe bed")
	var afdrukken := _voetafdrukken("kamer1")
	waar(_raakt(afdrukken, [a, b]).begins_with("bed"), "het bed staat op de lijn (%s)" % _raakt(afdrukken, [a, b]))
	var uit := _keur("kamer1", afdrukken, "om het gekochte bed", a, b)
	waar((uit["weg"] as Array).size() >= 3, "hij loopt om het bed heen")
	Rooms.meubel_weg(str(bed.get("id", "")))
	gelijk(World.looppad("kamer1", a, b), [b], "bed weg: weer recht door")
	a = Vector2(60.0, 40.0)
	b = Vector2(60.0, 104.0)
	gelijk(World.looppad("kamer1", a, b), [b], "over de vrije vloer recht door")
	# the trolley, pushed into kamer 1 by a game
	World.zet_ding("kar", {"kamer": "kamer1", "x": 60.0, "z": 72.0})
	afdrukken = _voetafdrukken("kamer1")
	waar(_raakt(afdrukken, [a, b]).begins_with("keukenkar") or _raakt(afdrukken, [a, b]).begins_with("kar"),
		"de kar staat op de lijn (%s)" % _raakt(afdrukken, [a, b]))
	var om := _keur("kamer1", afdrukken, "om de kar", a, b)
	waar((om["weg"] as Array).size() >= 3, "hij loopt om de kar heen")
	World.ding_thuis_zet("kar")
	gelijk(World.looppad("kamer1", a, b), [b], "kar thuis: weer recht door")
	# and in the kitchen the trolley stands where it belongs: from the corridor
	# door to the corner under the window, where the garden door was until the
	# kitchen moved upstairs (2026-09-24, the tower)
	var k_af := _voetafdrukken("keuken")
	var gang := Rooms.deur("keuken", "gang")
	_keur("keuken", k_af, "gang -> de hoek bij het raam langs de kar",
		Vector2(gang["ix"], gang["iz"]), Vector2(110.0, 8.0))
	_af()

## A game's loose decor is in the grid while it stands, and gone with it.
func test_los_decor_van_een_spel_staat_in_de_weg() -> void:
	var a := Vector2(30.0, 60.0)
	var b := Vector2(100.0, 60.0)
	gelijk(World.looppad("speelzaal", a, b), [b], "over de speelmat recht door")
	World.decor("speelzaal", {"id": "pr_kist", "model": "kist", "x": 65.0, "z": 60.0, "door": "proef"})
	var afdrukken := _voetafdrukken("speelzaal")
	waar(_raakt(afdrukken, [a, b]).begins_with("kist"), "de kist staat op de lijn")
	var uit := _keur("speelzaal", afdrukken, "om de kist", a, b)
	waar((uit["weg"] as Array).size() >= 3, "hij loopt om de kist heen")
	World.decor_wis_eigenaar("proef")
	gelijk(World.looppad("speelzaal", a, b), [b], "kist weg: weer recht door")
	_af()

## Flat things lie under a guest's paws (a doormat, the hopscotch stones), and
## what hangs over his back (the garland over the dance floor) is no wall.
func test_platte_en_hoge_dingen_houden_niemand_tegen() -> void:
	gelijk(WereldLooppad.kolommen("deurmat").size(), 0, "een deurmat ligt plat")
	gelijk(WereldLooppad.kolommen("hinkel_steen", {"groot": true}).size(), 0, "een hinkelsteen ook")
	gelijk(WereldLooppad.kolommen("wimpel").size(), 0, "de slinger hangt boven de rug")
	waar(WereldLooppad.kolommen("bed").size() > 400, "een bed staat in de weg")
	# a quarter turn turns the footprint: `bed` lies along x, turned along z
	var recht := WereldLooppad.kolommen("bed")
	var gedraaid := WereldLooppad.kolommen("bed", {}, 1)
	var rx := 0
	var gx := 0
	for i in range(0, recht.size(), 2):
		rx = maxi(rx, absi(recht[i]))
	for i in range(0, gedraaid.size(), 2):
		gx = maxi(gx, absi(gedraaid[i]))
	waar(rx > gx, "gedraaid is het bed smal langs x (%d tegen %d)" % [gx, rx])

# ------------------------------------------------------------------ echt lopen

## A real journey on the think tick: from a bed in kamer 2 through the corridor,
## down in the lift, through the lobby — round the desk — into the garden, and
## in every room he passes he never stands in anything, also between two ticks.
## He arrives where he was sent.
func test_reis_door_vier_kamers_loopt_nergens_doorheen() -> void:
	Rooms.herstel()
	var was: bool = Ui.rust_modus()
	Ui.set("_rust", false)
	World.naar("kamer2")
	var bed := Rooms.slot("kamer2", "bed1")
	var d := World.zet(T, "kamer2", float(bed["sx"]), float(bed["sz"]), {"kind": "hond"})
	var doel := Vector2(112.0, 96.0)
	var route := World.reis(T, "tuin", {"x": doel.x, "z": doel.y, "na": "wacht"})
	gelijk(route, ["kamer2", "gang", "receptie", "tuin"], "twee deuren en de lift")
	var afdrukken := {}
	for k in route:
		afdrukken[k] = _voetafdrukken(k)
	var vorig := Vector2(d.x, d.z)
	var kamer := d.kamer
	var gezien := {}
	var botsing := ""
	var t := 0
	while (d.kamer != "tuin" or not d.punten.is_empty() or not d.route.is_empty()) and t < 3000:
		World._tik()
		t += 1
		var nu := Vector2(d.x, d.z)
		gezien[d.kamer] = true
		if d.kamer == kamer and botsing == "":
			botsing = _raakt(afdrukken[kamer], [vorig, nu])
			if botsing != "":
				botsing = "%s: %s" % [kamer, botsing]
		vorig = nu
		kamer = d.kamer
	waar(botsing == "", "hij liep nergens doorheen (%s)" % botsing)
	gelijk(d.kamer, "tuin", "hij is in de tuin")
	gelijk(Vector2(d.x, d.z), doel, "op de plek waar hij heen moest")
	waar(gezien.has("gang") and gezien.has("receptie"), "hij liep door de gang en de lobby")
	Ui.set("_rust", was)
	World.naar("receptie")
	_af()

## Idle wandering only picks places a guest can stand on and walk to: in kamer 1
## four wander places lie at the ends of the beds.
func test_dwalen_kiest_alleen_haalbare_plekken() -> void:
	Rooms.herstel()
	var r := Rooms.get_kamer("kamer1")
	# Since the fixed bed places (2026-09-24) no wander place lies against a
	# bed any more; a game's chest on the first one makes sure there is one
	# to skip.
	var p0: Array = r.plekken[0]
	World.decor("kamer1", {"id": "pr_dwaal", "model": "kist", "x": float(p0[0]),
		"z": float(p0[1]), "door": "proef"})
	var afdrukken := _voetafdrukken("kamer1")
	var in_iets := 0
	for p in r.plekken:
		if _in(afdrukken, Vector2(p[0], p[1])) != "" \
				or not World.looppad_rooster("kamer1").vrij(Vector2(p[0], p[1])):
			in_iets += 1
	waar(in_iets > 0, "er liggen dwaalplekken tegen of in iets (%d)" % in_iets)
	var d := World.zet(T, "kamer1", 70.0, 60.0, {"kind": "poes"})
	var rooster: WereldLooppad = World.looppad_rooster("kamer1")
	for i in 150:
		var p: Vector2 = World._vrije_plek(d)
		if not rooster.vrij(p) or _in(afdrukken, p) != "":
			fout("dwaalplek (%.0f, %.0f) is niet vrij" % [p.x, p.y])
			break
		# and the walk there goes round everything
		var raakt := _raakt(afdrukken, _weg("kamer1", Vector2(d.x, d.z), p))
		if raakt != "":
			fout("de wandeling naar (%.0f, %.0f) raakt %s" % [p.x, p.y, raakt])
			break
		World.zet(T, "kamer1", p.x, p.y)
	# one who stands deep INSIDE something (a game's customer at the stall's
	# counter, found by the kraam test; here: in the middle of the trolley)
	# still finds a free place to wander off to
	var kar := World.ding("kar")
	var in_kar := Vector2(float(kar["x"]), float(kar["z"]))
	World.zet(T, str(kar["kamer"]), in_kar.x, in_kar.y)
	waar(not World.looppad_rooster(str(kar["kamer"])).vrij(in_kar), "hij staat midden in de kar")
	var weg: Vector2 = World._vrije_plek(World.dier(T))
	waar(weg.distance_to(in_kar) > 8.0 and World.looppad_rooster(str(kar["kamer"])).vrij(weg),
		"en dwaalt weg naar een vrije plek (%s)" % str(weg))
	World.decor_wis_eigenaar("proef")
	_af()

## Swimming, jumping and a walk that counts its own points keep their exact
## points; a plain walk through something gets its way round it.
func test_zwemmen_springen_en_tellen_houden_hun_punten() -> void:
	Rooms.herstel()
	var was: bool = Ui.rust_modus()
	Ui.set("_rust", false)
	World.naar("kamer1")
	var dp := Rooms.deur("kamer1", "gang")
	var bed := Rooms.slot("kamer1", "bed2")
	var a := Vector2(dp["ix"], dp["iz"])
	var b := Vector2(bed["sx"], bed["sz"])
	var d := World.zet(T, "kamer1", a.x, a.y, {"kind": "konijn"})
	World.stappen(T, [b], {"pose": "spring"})
	gelijk(d.punten, [b], "springen: precies het ene punt")
	World.zet(T, "kamer1", a.x, a.y)
	World.stappen(T, [b], {"pose": "zwem"})
	gelijk(d.punten, [b], "zwemmen: precies het ene punt")
	World.zet(T, "kamer1", a.x, a.y)
	World.stappen(T, [b], {"per_stap": func(_i: int, _p): pass})
	gelijk(d.punten, [b], "een tellende wandeling: precies het ene punt")
	World.zet(T, "kamer1", a.x, a.y)
	World.stappen(T, [b])
	waar(d.punten.size() >= 2, "een gewone wandeling gaat om het bed heen (%s)" % str(d.punten))
	gelijk(d.punten[d.punten.size() - 1], b, "en eindigt op het punt")
	World.zet(T, "kamer1", a.x, a.y)
	World.ga(T, b.x, b.y, "wacht")
	waar(d.punten.size() >= 2, "ga() ook (%s)" % str(d.punten))
	Ui.set("_rust", was)
	World.naar("receptie")
	_af()

## A guest who stands IN something (woken on his mattress, put down in a
## doorway) walks out of it, and a goal inside something (the bed's own point)
## is still reached: DICHT costs, it never walls anything off.
func test_in_en_uit_een_voetafdruk() -> void:
	Rooms.herstel()
	var bed := Rooms.slot("kamer1", "bed1")
	var midden := Vector2(bed["x"], bed["z"])
	var dp := Rooms.deur("kamer1", "gang")
	var deur := Vector2(dp["ix"], dp["iz"])
	var uit := _weg("kamer1", midden, deur)
	gelijk(uit[uit.size() - 1], deur, "van het matras naar de deur")
	var erin := _weg("kamer1", deur, midden)
	gelijk(erin[erin.size() - 1], midden, "en van de deur het bed in")
	# the water: out the shortest way, then round it
	var zw := _weg("zwembad", Vector2(60.0, 28.0), Vector2(12.0, 56.0))
	gelijk(zw[zw.size() - 1], Vector2(12.0, 56.0), "uit het water naar de start")
	var afdrukken := _voetafdrukken("zwembad")
	var kant := Vector2(132.0, 56.0)
	var start := Vector2(12.0, 56.0)
	_keur("zwembad", afdrukken, "langs het water", kant, start)
	_af()

## No room, no grid: the old walk, straight.
func test_zonder_kamer_de_rechte_lijn() -> void:
	gelijk(World.looppad("nergens", Vector2(1, 1), Vector2(9, 9)), [Vector2(9, 9)], "recht")
	waar(World.looppad_rooster("nergens") == null, "geen rooster")

## The travel bar of "komt eraan" counts the way round things: it only climbs
## and it is full at the door.
func test_de_voortgang_telt_de_omweg() -> void:
	Rooms.herstel()
	var was: bool = Ui.rust_modus()
	Ui.set("_rust", false)
	World.naar("receptie")
	var bed := Rooms.slot("kamer1", "bed2")
	var d := World.zet(T, "kamer1", float(bed["sx"]), float(bed["sz"]), {"kind": "gans"})
	World.reis(T, "receptie", {"x": 60.0, "z": 60.0})
	var vorige := -1.0
	var stijgt := true
	var t := 0
	while d.kamer == "kamer1" and t < 1000:
		World._tik()
		t += 1
		var f := World.reis_voortgang(T)
		if f + 0.0001 < vorige:
			stijgt = false
		vorige = f
	waar(stijgt, "de voortgang loopt alleen op")
	waar(vorige >= 0.45, "en is een half vol als hij de kamer uit is (%.2f)" % vorige)
	Ui.set("_rust", was)
	World.naar("receptie")
	_af()

## A walk is cheap: the grid is built once per change of the room and a way
## over it costs a few milliseconds, on a slow machine too.
func test_een_pad_is_goedkoop() -> void:
	Rooms.herstel()
	var paren: Array = []
	for kamer in ["receptie", "tuin", "kamer2", "keuken"]:
		var p := _plekken(kamer)
		var lijst: Array = p.values()
		for i in lijst.size():
			for j in lijst.size():
				if i != j:
					paren.append([kamer, lijst[i], lijst[j]])
	for kamer in ["receptie", "tuin", "kamer2", "keuken"]:
		World.looppad_rooster(kamer)
	var t0 := Time.get_ticks_usec()
	for p in paren:
		World.looppad(p[0], p[1], p[2])
	var per := (Time.get_ticks_usec() - t0) / 1000.0 / maxf(1.0, float(paren.size()))
	print("[looppad] %d paden, %.2f ms per pad" % [paren.size(), per])
	waar(per < 25.0, "een pad kost %.2f ms" % per)
	_af()
