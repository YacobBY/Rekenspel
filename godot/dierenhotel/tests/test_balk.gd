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
## `hoog` is the value AFTER `clampi(H, 72, int(y * 0.34))`.  That ceiling only
## bites on 296x314: rung E asks for 132 and a 314 unit frame allows 106.
## `knop_breed` is the rung's formula rounded DOWN (150 = the cap of rung A,
## 69 = (326 − 48) / 4, 62 = (558 · 0.48 − 18) / 4, 76 = (676 · 0.48 − 18) / 4).
const TABEL := [
	[Vector2(990, 637), "A", "hoog", 160, 22, 34, 24, 21, 64, 150],
	[Vector2(734, 788), "B", "hoog", 152, 21, 32, 23, 20, 60, 140],
	[Vector2(1170, 669), "A", "hoog", 160, 22, 34, 24, 21, 64, 150],
	[Vector2(326, 558), "C", "hoog", 160, 20, 30, 22, 19, 60, 69],
	[Vector2(558, 289), "D", "laag", 96, 18, 26, 20, 18, 60, 62],
	[Vector2(1000, 648), "A", "hoog", 160, 22, 34, 24, 21, 64, 150],
	[Vector2(768, 1024), "B", "hoog", 152, 21, 32, 23, 20, 60, 140],
	[Vector2(360, 740), "C", "hoog", 160, 20, 30, 22, 19, 60, 78],
	[Vector2(296, 314), "E", "hoog", 106, 17, 24, 19, 17, 52, 63],
	[Vector2(676, 320), "D", "laag", 96, 18, 26, 20, 18, 60, 76],
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

## §3.1: the world is fitted ABOVE the bar, so the bar may never take more than
## a third of the frame — and on every frame the shell hands out it still gets
## its 72 units.
func test_de_balk_blijft_onder_een_derde() -> void:
	for kader in KADERS:
		var m := UiThema.balk_maten(kader)
		var plafond := int(kader.y * 0.34)
		waar(int(m["hoog"]) <= plafond,
			"%s: de balk is %d, het plafond %d" % [str(kader), int(m["hoog"]), plafond])
		waar(int(m["hoog"]) >= 72,
			"%s: de balk haalt zijn 72 (%d)" % [str(kader), int(m["hoog"])])
	# and the ceiling really does the cutting somewhere: 296x314 asks 132
	gelijk(UiThema.balk_maten(Vector2(296, 314))["hoog"], 106,
		"het plafond knipt rung E af op het kortste kader")
	gelijk(UiThema.balk_maten(Vector2(296, 400))["hoog"], 132,
		"met 400 units hoogte krijgt rung E zijn volle 132")

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
				if int(m["hoog"]) > int(y * 0.34) or int(m["hoog"]) < 72:
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
