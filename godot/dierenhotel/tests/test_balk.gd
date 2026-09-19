extends Proef
## The measurements of the maths bar (PLAN.md §3.1), taken before a single node
## of it exists: `UiThema.balk_vorm` and `UiThema.balk_maten` are pure functions
## of the world frame, so this file needs no layer, no viewport and no save.
##
## `TABEL` is copied from the plan by hand, not from the implementation — a
## later task that retunes a rung has to change the plan and this table
## together.  Under it stand the four rules the bar may never break, whatever
## the frame: the 12 px letter floor (HOTEL.md §9), the 48 unit tap target
## (art-sound-rules.md §16.5), four answer buttons that fit side by side, and a
## bar that never eats more than a third of the frame.

## The ten frames the suite really draws: `tests/test_ui.gd::KADERS_UNITS` (the
## five ticket screens, measured through the real chrome by
## `test_shell_op_vijf_schermen`) and `tests/test_hits.gd::MATEN` (the five the
## placement suite walks every room's decor through).
const KADERS := [Vector2(990, 637), Vector2(734, 788), Vector2(1170, 669),
	Vector2(326, 558), Vector2(558, 289),
	Vector2(1000, 648), Vector2(768, 1024), Vector2(360, 740),
	Vector2(296, 314), Vector2(676, 320)]

## PLAN.md §3.1 by hand, one row per frame:
## [kader, rung, vorm, hoog, zin, som, knop, nu, knop_hoog, knop_breed].
##
## `hoog` is the value AFTER `clampi(H, 72, int(y * 0.48))`.  `B4` raised the
## rungs so the bar can hold its own stack — sentence over sum over buttons —
## at the real line height of the theme's font (about 1.9x the size).  The old
## third-of-the-frame cap could not hold that stack on a short frame, so the
## cap moved to 0.48: it still bites on 296x314, where rung E asks for 150 and
## a 314 unit frame allows exactly 150.  `knop_breed` is the rung's formula
## rounded DOWN (150 = the cap of rung A, 69 = (326 − 48) / 4, 62 =
## (558 · 0.48 − 18) / 4, 76 = (676 · 0.48 − 18) / 4).
const TABEL := [
	[Vector2(990, 637), "A", "hoog", 188, 22, 34, 24, 21, 64, 150],
	[Vector2(734, 788), "B", "hoog", 178, 21, 32, 23, 20, 60, 140],
	[Vector2(1170, 669), "A", "hoog", 188, 22, 34, 24, 21, 64, 150],
	[Vector2(326, 558), "C", "hoog", 172, 20, 30, 22, 19, 60, 69],
	[Vector2(558, 289), "D", "laag", 104, 18, 26, 20, 18, 60, 62],
	[Vector2(1000, 648), "A", "hoog", 188, 22, 34, 24, 21, 64, 150],
	[Vector2(768, 1024), "B", "hoog", 178, 21, 32, 23, 20, 60, 140],
	[Vector2(360, 740), "C", "hoog", 172, 20, 30, 22, 19, 60, 78],
	[Vector2(296, 314), "E", "hoog", 150, 17, 24, 19, 17, 52, 63],
	[Vector2(676, 320), "D", "laag", 104, 18, 26, 20, 18, 60, 76],
]

## The eight keys of §3.1 and nothing else, so a caller may read them blind.
const SLEUTELS := ["vorm", "hoog", "zin", "som", "knop", "nu", "knop_hoog",
	"knop_breed"]
const LETTERS := ["zin", "som", "knop", "nu"]
const GAT := 8.0       ## between two answer buttons
const RAND := 12.0     ## the margin left at the edge of the frame

## The room the row of four buttons has: the whole frame in a `hoog` bar, the
## right-hand block in a `laag` one (the sentence and the sum take the left
## `UiThema.BALK_LAAG_LINKS` of the width there).
func _ruimte(kader: Vector2, vorm: String) -> float:
	if vorm == "laag":
		return kader.x * (1.0 - UiThema.BALK_LAAG_LINKS) - RAND
	return kader.x - RAND

func _rij(m: Dictionary) -> float:
	return 4.0 * float(m["knop_breed"]) + 3.0 * GAT

# ------------------------------------------------------------------ de tabel

## Every rung of §3.1, on all ten frames, key by key.
func test_de_tabel_van_3_1() -> void:
	for rij in TABEL:
		var kader: Vector2 = rij[0]
		var wie := "%s (rung %s)" % [str(kader), str(rij[1])]
		var m := UiThema.balk_maten(kader)
		gelijk(UiThema.balk_vorm(kader), rij[2], "%s: vorm" % wie)
		gelijk(m["vorm"], rij[2], "%s: dezelfde vorm in de maten" % wie)
		gelijk(m["hoog"], rij[3], "%s: de hoogte van de balk" % wie)
		gelijk(m["zin"], rij[4], "%s: de zin" % wie)
		gelijk(m["som"], rij[5], "%s: de som" % wie)
		gelijk(m["knop"], rij[6], "%s: het woord op de knop" % wie)
		gelijk(m["nu"], rij[7], "%s: de Nu-chip" % wie)
		gelijk(m["knop_hoog"], rij[8], "%s: de knophoogte" % wie)
		gelijk(m["knop_breed"], rij[9], "%s: de knopbreedte" % wie)

## Exactly the eight keys of the plan, and every size a whole number: they go
## straight into `set_font_size` and `custom_minimum_size`, and half a unit
## there is a blurred letter on a 2x screen.
func test_acht_sleutels_en_hele_getallen() -> void:
	for kader in KADERS:
		var m := UiThema.balk_maten(kader)
		gelijk(m.size(), SLEUTELS.size(), "%s: acht sleutels" % str(kader))
		for s in SLEUTELS:
			waar(m.has(s), "%s: sleutel %s staat er" % [str(kader), s])
		for s in SLEUTELS:
			if s == "vorm":
				continue
			gelijk(typeof(m[s]), TYPE_INT, "%s: %s is een heel getal" % [str(kader), s])
	gelijk(typeof(UiThema.balk_maten(KADERS[0])["vorm"]), TYPE_STRING,
		"de vorm is een woord")

## The four lines of the table, tested where they cross.  `>=` on all three, so
## a frame that lands exactly on 900, 520, 470 or 440 takes the larger rung.
func test_de_grenzen_tussen_de_rungs() -> void:
	gelijk(UiThema.balk_maten(Vector2(600, 440))["som"], 32, "y = 440 is nog hoog (B)")
	gelijk(UiThema.balk_maten(Vector2(600, 439))["som"], 26, "y = 439 valt naar D")
	gelijk(UiThema.balk_maten(Vector2(900, 600))["som"], 34, "x = 900 is rung A")
	gelijk(UiThema.balk_maten(Vector2(899, 600))["som"], 32, "x = 899 is rung B")
	gelijk(UiThema.balk_maten(Vector2(520, 600))["som"], 32, "x = 520 is rung B")
	gelijk(UiThema.balk_maten(Vector2(519, 600))["som"], 30, "x = 519 is rung C")
	gelijk(UiThema.balk_maten(Vector2(470, 400))["som"], 26, "x = 470, kort: rung D")
	gelijk(UiThema.balk_maten(Vector2(469, 400))["som"], 24, "x = 469, kort: rung E")
	# `laag` exists in exactly one corner of the table: short AND wide enough
	gelijk(UiThema.balk_vorm(Vector2(470, 439)), "laag", "kort en breed genoeg")
	gelijk(UiThema.balk_vorm(Vector2(469, 439)), "hoog", "kort maar te smal")
	gelijk(UiThema.balk_vorm(Vector2(470, 440)), "hoog", "hoog genoeg blijft hoog")
	gelijk(UiThema.balk_vorm(Vector2(1170, 669)), "hoog", "een tablet is hoog")

# ------------------------------------------------------------------ de regels

## HOTEL.md §9: no child-facing letter under 12 px.  The bar asks far more than
## that — it carries the sum — so the real assertion is that the sum is the
## biggest letter of the four and the Nu-chip never shouts over the sentence.
func test_elke_letter_haalt_de_vloer() -> void:
	for kader in KADERS:
		var m := UiThema.balk_maten(kader)
		for s in LETTERS:
			waar(int(m[s]) >= UiThema.VLOER,
				"%s: %s is %d, de vloer is %d" % [str(kader), s, int(m[s]), UiThema.VLOER])
		waar(int(m["som"]) > int(m["knop"]),
			"%s: de som (%d) staat groter dan het knopwoord (%d)"
				% [str(kader), int(m["som"]), int(m["knop"])])
		waar(int(m["zin"]) >= int(m["nu"]),
			"%s: de zin (%d) is niet kleiner dan de Nu-chip (%d)"
				% [str(kader), int(m["zin"]), int(m["nu"])])

## art-sound-rules.md §16.5: a tap target is 48 units.  `HOT_KRAP` (44) is the
## allowance for a screen under 360 px wide; the bar never needs it, because
## even the smallest rung keeps 52 x 48.
func test_elke_knop_is_een_tikdoel() -> void:
	for kader in KADERS:
		var m := UiThema.balk_maten(kader)
		waar(int(m["knop_hoog"]) >= UiThema.HOT,
			"%s: knophoogte %d >= %d" % [str(kader), int(m["knop_hoog"]), UiThema.HOT])
		waar(int(m["knop_breed"]) >= UiThema.HOT,
			"%s: knopbreedte %d >= %d" % [str(kader), int(m["knop_breed"]), UiThema.HOT])

## Four answer buttons and their three gaps fit: in the frame minus a 12 unit
## margin when the bar is `hoog`, in the right-hand block when it is `laag`.
func test_vier_knoppen_passen_naast_elkaar() -> void:
	for kader in KADERS:
		var m := UiThema.balk_maten(kader)
		var rij := _rij(m)
		var ruimte := _ruimte(kader, str(m["vorm"]))
		waar(rij <= ruimte, "%s (%s): vier knoppen zijn %d breed, er is %d"
			% [str(kader), str(m["vorm"]), int(rij), int(ruimte)])

## §3.1 as retuned by `B4`: the bar is sized to hold its own stack — sentence
## over sum over buttons — at the real line height of the theme's font, so the
## cap moved from a third to just under half the frame.  The world keeps what
## is left, and on every frame the shell hands out the bar still gets its 72.
func test_de_balk_blijft_onder_de_helft() -> void:
	for kader in KADERS:
		var m := UiThema.balk_maten(kader)
		var plafond := int(kader.y * 0.48)
		waar(int(m["hoog"]) <= plafond,
			"%s: de balk is %d, het plafond %d" % [str(kader), int(m["hoog"]), plafond])
		waar(int(m["hoog"]) >= 72,
			"%s: de balk haalt zijn 72 (%d)" % [str(kader), int(m["hoog"])])
	# and the ceiling really does the cutting somewhere: rung E asks 150
	gelijk(UiThema.balk_maten(Vector2(296, 300))["hoog"], 144,
		"het plafond knipt rung E af op het kortste kader")
	gelijk(UiThema.balk_maten(Vector2(296, 400))["hoog"], 150,
		"met 400 units hoogte krijgt rung E zijn volle 150")

## Not only the ten: a sweep over every frame from 240x240 to 1400x1200 keeps
## the same four rules.  Pure arithmetic, so it costs milliseconds.
func test_de_regels_houden_op_elk_kader() -> void:
	var stuk: Array[String] = []
	var gezien := 0
	var x := 240.0
	while x <= 1400.0:
		var y := 240.0
		while y <= 1200.0:
			var kader := Vector2(x, y)
			var m := UiThema.balk_maten(kader)
			gezien += 1
			if stuk.size() < 5:
				for s in LETTERS:
					if int(m[s]) < UiThema.VLOER:
						stuk.append("%s: %s = %d" % [str(kader), s, int(m[s])])
				if int(m["knop_hoog"]) < UiThema.HOT or int(m["knop_breed"]) < UiThema.HOT:
					stuk.append("%s: knop %dx%d" % [str(kader), int(m["knop_breed"]),
						int(m["knop_hoog"])])
				if _rij(m) > _ruimte(kader, str(m["vorm"])):
					stuk.append("%s: de knoprij loopt over" % str(kader))
				if int(m["hoog"]) > int(y * 0.48) or int(m["hoog"]) < 72:
					stuk.append("%s: balkhoogte %d" % [str(kader), int(m["hoog"])])
				if m.size() != SLEUTELS.size():
					stuk.append("%s: %d sleutels" % [str(kader), m.size()])
			y += 20.0
		x += 20.0
	waar(gezien >= 2400, "de veeg liep echt (%d kaders)" % gezien)
	gelijk(stuk.size(), 0, "geen kader breekt een regel: %s" % str(stuk))

## A frame that does not exist yet (the shell before `World.meet`) must not
## crash and must not claim height: the ceiling takes it to zero.
func test_een_leeg_kader_krijgt_geen_balk() -> void:
	var m := UiThema.balk_maten(Vector2.ZERO)
	gelijk(m["hoog"], 0, "nul hoogte, dus geen balk")
	gelijk(m["vorm"], "hoog", "en de vorm is er wel")
	waar(int(m["knop_breed"]) >= UiThema.HOT, "de knopmaat blijft een tikdoel")

# ------------------------------------------------------ de balk in de wereld

## The second half of `B2`: the same ten frames, but now with a world behind
## them.  `Ui.balk_rect()` is a pure function of `World.kader_rect()` — no
## Balklaag node needed, which is exactly why the eighteen five-layer test
## shells did not have to change (PLAN.md §3.1) — and the world is fitted ABOVE
## the strip, so the bar covers nothing.
##
## The harness is the bare version of `tests/test_hits.gd::_hotel_op`: a hotspot
## layer, a SubViewport and a Node2D, without the whole shell.

var _vp: SubViewport = null
var _laag: Control = null

func _boom() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

func _op(kader: Vector2) -> void:
	_laag = Control.new()
	_laag.size = kader
	_boom().root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	_vp = SubViewport.new()
	_vp.size = Vector2i(kader)
	_boom().root.add_child(_vp)
	var scene := Node2D.new()
	_vp.add_child(scene)
	World.registreer_viewport(_vp, scene)
	World.meet(Rect2(Vector2.ZERO, kader))

func _af() -> void:
	Hits.wis_alles()
	World.naar("receptie")
	Ui.registreer_lagen(null, null, null)
	World.registreer_viewport(null, null)
	if _vp != null:
		_vp.queue_free()
		_vp = null
	if _laag != null:
		_laag.queue_free()
		_laag = null
	# one frame further, so the viewport and its texture are really gone: else
	# the engine reports "resources still in use at exit", and that is an ERROR
	# line the suite (rightly) does not allow
	await _boom().process_frame

## (a) The strip itself: the height of the table of §3.1, the full width of the
## frame, against the bottom edge.
func test_de_balk_ligt_tegen_de_onderrand() -> void:
	for rij in TABEL:
		var kader: Vector2 = rij[0]
		var wie := str(kader)
		_op(kader)
		waar(Ui.balk_aan(), "%s: er is een kader, dus er is een balk" % wie)
		gelijk(Ui.balk_hoog(), float(rij[3]), "%s: de hoogte uit de tabel" % wie)
		var r := Ui.balk_rect()
		gelijk(r.size.y, float(rij[3]), "%s: en de strook is zo hoog" % wie)
		gelijk(r.position.x, 0.0, "%s: vanaf de linkerrand" % wie)
		gelijk(r.size.x, kader.x, "%s: over de volle breedte" % wie)
		gelijk(r.end.y, kader.y, "%s: en tegen de onderrand" % wie)
		gelijk(r.position.y, kader.y - float(rij[3]), "%s: de bovenrand ligt eronder" % wie)
		await _af()

## The shell before its first `World.meet`: no frame, so no bar — and above all
## no crash and no height claimed on a world that is not measured yet.
func test_zonder_kader_is_er_geen_balk() -> void:
	var bewaard := World.kader_rect()
	World._kader = Rect2()
	waar(not Ui.balk_aan(), "geen kader, geen balk")
	gelijk(Ui.balk_hoog(), 0.0, "en dus geen hoogte")
	gelijk(str(Ui.balk_rect()), str(Rect2()), "en geen strook")
	World._kader = bewaard

## The corners of the floor that the room's OWN frame box shows.  The garden is
## 130 x 130 voxels while its `vast_kader` shows [-170, 190] x [-70, 220] of it:
## three of its four corners have been outside the picture since long before the
## bar existed (on `main` the far one lands 88 units under the bottom edge at
## 990x637).  What the camera promises to show is the box, and that one is
## checked in full, in every room.
func _hoeken_in_beeld(r: Rooms.Kamer, box: PackedInt32Array) -> Array:
	var uit: Array = []
	for h: Vector2 in [Vector2(0, 0), Vector2(r.w, 0), Vector2(0, r.d), Vector2(r.w, r.d)]:
		var px: float = (h.x - h.y) * float(Art.S)
		var py: float = (h.x + h.y) * float(Art.S) / 2.0
		if px >= float(box[0]) and px <= float(box[1]) \
				and py >= float(box[2]) and py <= float(box[3]):
			uit.append(h)
	return uit

## (b) Every room of `Rooms.lijst()` on every frame: the bottom edge of the room
## and every floor corner in the picture end ABOVE the paper.
func test_elke_kamer_staat_boven_de_balk() -> void:
	for kader: Vector2 in KADERS:
		_op(kader)
		var top: float = kader.y - Ui.balk_hoog()
		for id in Rooms.lijst():
			World.naar(id)
			var r := Rooms.get_kamer(id)
			var box := Rooms.kader(r)
			var sch := World.schaal()
			var onder := (World.cam_doel(r).y + float(box[3]) * float(sch["g"])) \
				/ float(sch["dicht"])
			var wie := "%s op %s" % [id, str(kader)]
			waar(onder <= top + 0.01,
				"%s: de onderrand van de kamer (%.1f) ligt boven de balk (%.1f)"
					% [wie, onder, top])
			var hoeken := _hoeken_in_beeld(r, box)
			waar(hoeken.size() >= 1, "%s: er is een vloerhoek om te meten" % wie)
			if r.vast_kader.is_empty():
				gelijk(hoeken.size(), 4, "%s: alle vier de hoeken horen bij het beeld" % wie)
			for h: Vector2 in hoeken:
				var p := World.mik_punt(h.x, h.y, 0.0)
				waar(p.y <= top + 0.01, "%s: vloerhoek %s staat op %.1f, de balk begint op %.1f"
					% [wie, str(h), p.y, top])
		await _af()

## (c) The price of the strip: the voxel step may get smaller, never illegal.
func test_de_voxelstap_blijft_twee_tot_vier() -> void:
	for kader: Vector2 in KADERS:
		_op(kader)
		for id in Rooms.lijst():
			World.naar(id)
			var sch := World.schaal()
			var g: int = sch["g"]
			waar(g >= 2 and g <= 4, "%s op %s: g = %d" % [id, str(kader), g])
			waar(float(sch["k"]) > 0.0 and float(sch["dicht"]) >= 1.0,
				"%s op %s: k en dicht blijven echte getallen" % [id, str(kader)])
		await _af()

## The height in units a hotspot has to sit at to aim at `doel_y` on the screen.
func _hoogte_voor(x: float, z: float, doel_y: float) -> float:
	var p0 := World.mik_punt(x, z, 0.0)
	var per := p0.y - World.mik_punt(x, z, 1.0).y     # units per voxel of height
	if absf(per) < 0.001:
		return 0.0
	return (p0.y - doel_y) / per

## (d) A hotspot that aims at the middle of the bar lands above it — whatever
## anchor it uses.  `Hits.plaats()` hands the strip out before anything else, so
## the paper blocks every cell it covers and there is nothing left to land on.
func test_een_hotspot_midden_in_de_balk_landt_erboven() -> void:
	for kader: Vector2 in KADERS:
		_op(kader)
		World.naar("receptie")
		var balk := Ui.balk_rect()
		var midden := balk.position.y + balk.size.y * 0.5
		var y := _hoogte_voor(24.0, 20.0, midden)
		for op: String in ["boven", "midden"]:
			Hits.maak({"id": "diep", "kamer": World.kamer_nu(), "x": 24.0, "z": 20.0,
				"y": y, "op": op, "label": "Diep", "door": "test"})
			Hits.plaats()
			var wie := "%s op %s" % [op, str(kader)]
			var mik := Hits.debug()["diep"]["mik"] as Vector2
			waar(absf(mik.y - midden) <= 1.0,
				"%s: het mikpunt (%.1f) ligt midden in de balk (%.1f)" % [wie, mik.y, midden])
			var rect := Hits.debug()["diep"]["rect"] as Rect2
			var snij := rect.intersection(balk)
			gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
				"%s: de knop raakt de balk niet" % wie)
			waar(rect.end.y <= balk.position.y + 0.01,
				"%s: en staat er helemaal boven (%.1f <= %.1f)"
					% [wie, rect.end.y, balk.position.y])
			waar(not bool(Hits.debug()["diep"]["krap"]),
				"%s: het was een echte plek, geen noodplek" % wie)
			Hits.weg("diep")
		await _af()

## The layer only paints; it never claims a hotspot and never catches a finger.
## The two slots for the tasks after this one are there and empty.
func test_de_balklaag_tekent_wat_ui_zegt() -> void:
	for kader: Vector2 in [Vector2(990, 637), Vector2(360, 740), Vector2(676, 320)]:
		_op(kader)
		var laag := UiRekenbalk.new()
		_laag.add_child(laag)
		await _boom().process_frame
		var wie := str(kader)
		gelijk(laag.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"%s: de balk vangt geen vinger" % wie)
		var r := laag.balk_rect()
		gelijk(r.size.y, Ui.balk_hoog(), "%s: de laag tekent de hoogte van Ui" % wie)
		gelijk(r.size.x, kader.x, "%s: over de volle breedte" % wie)
		gelijk(r.end.y, kader.y, "%s: tegen de onderrand" % wie)
		gelijk(Hits.lijst().size(), 0, "%s: en hij kost geen enkele hotspot" % wie)
		var nu := laag.nu_knop()
		waar(nu != null and not nu.visible, "%s: de Nu-chip bestaat en zwijgt nog (B6)" % wie)
		gelijk(str(laag.kaart_rect()), str(Rect2()), "%s: er dokt nog geen kaart (B3)" % wie)
		laag.zet_kaart(Rect2(10, 20, 30, 40))
		gelijk(str(laag.kaart_rect()), str(Rect2(10, 20, 30, 40)),
			"%s: het slot onthoudt de kaart" % wie)
		laag.queue_free()
		await _af()


## Everything the room really has, as aim points: slots, loose things and fixed
## decor, in the order `Hits._zoek_voorwerp` would find them.
func _dingen_van(id: String) -> Array[Dictionary]:
	var uit: Array[Dictionary] = []
	var r := Rooms.get_kamer(id)
	if r == null:
		return uit
	var bron: Array = []
	bron.append_array(r.slots.values())
	bron.append_array(r.decor)
	bron.append_array(World.dingen(id))
	for stuk in bron:
		if typeof(stuk) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = stuk
		if not d.has("x") or not d.has("z"):
			continue
		uit.append(d)
		if uit.size() >= VOL:
			break
	return uit

## How many buttons a full room really shows at once.  `Hits.MAX_PER_KAMER` is
## 16, but that is the CULL ceiling, not a layout: eight hotspots is what the
## reception carries at its busiest (bell, notice board, two task cards, door,
## name plate, a bubble and a game button), and eight is what this test loads.
## Sixteen at once does not fit over a 96 unit bar on a landscape phone — see
## the report of `B2`; that frame is what `N8` and `B3` are for.
const VOL := 8

## (d), the version that means something: a FULL room, on the two frames where
## the bar costs most, with a button on every thing the room has and every
## anchor of `_op_van` in the mix.  Not one placed rectangle may touch the
## paper — a lone hotspot in an empty reception proves nothing (the review of
## `B2`: the wash game put a "pak 1" chip in the middle of the strip).
##
## The sum card and the strip glued under it are the exception the bar EXISTS
## for (`B3` docks them there); they are not in this test, and they are the only
## two placements in `Hits` that may reach onto the paper.
func test_een_volle_kamer_laat_de_balk_leeg() -> void:
	const ANKERS := ["auto", "boven", "onder", "midden", "rand"]
	var gemeten := 0
	for kader: Vector2 in [Vector2(558, 289), Vector2(360, 740), Vector2(990, 637)]:
		_op(kader)
		for id in ["receptie", "keuken"]:
			World.naar(id)
			var balk := Ui.balk_rect()
			var dingen := _dingen_van(id)
			waar(dingen.size() >= 4, "%s op %s: de kamer heeft spullen (%d)"
				% [id, str(kader), dingen.size()])
			for i in dingen.size():
				var d: Dictionary = dingen[i]
				var anker: String = ANKERS[i % ANKERS.size()]
				Hits.maak({
					"id": "vol%d" % i, "kamer": id,
					"x": float(d.get("x", 0.0)), "z": float(d.get("z", 0.0)),
					"y": 6.0 if anker != "midden" else 0.0,
					"op": anker, "kind": "tag" if anker == "rand" else "btn",
					"getal": i if anker == "rand" else null,
					"icoon": "🔔", "label": "Knop %d" % i, "door": "test"})
			Hits.plaats()
			var dbg := Hits.debug()
			for spot_id in dbg.keys():
				var r: Rect2 = dbg[spot_id]["rect"]
				var snij := r.intersection(balk)
				gemeten += 1
				gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
					"%s op %s: %s (%s, anker %s) staat op de balk %s"
						% [id, str(kader), str(spot_id), str(r), str(dbg[spot_id]["op"]),
							str(balk)])
			Hits.wis_alles()
		await _af()
	waar(gemeten >= 40, "er stonden echt knoppen in de kamers (%d)" % gemeten)

