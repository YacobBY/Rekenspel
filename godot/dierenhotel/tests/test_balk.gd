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

# =========================================================== de dock (B2)
#
# The tests above measured the bar on paper.  These test the one thing that
# makes it real: the bar takes room from the world ONLY while a card stands
# in it, and gives every unit back the moment the card lets go.
#
# The owner's rule of 2026-09-19 is the spine of all of them — "de balk mag
# alleen ruimte kosten als er echt een kaart in staat".  Everything the bar
# is not told by a card it does not take, and nothing that happened before a
# card opened may be undone by one.

var _laag: Control = null
var _papier: UiRekenbalk = null

func _op(kader: Vector2) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = kader
	boom.root.add_child(_laag)
	_papier = UiRekenbalk.new()
	_papier.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_laag.add_child(_papier)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag, _papier)
	World.meet(Rect2(Vector2.ZERO, kader))

func _af() -> void:
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	if _papier != null:
		_papier.queue_free()
		_papier = null
	if _laag != null:
		_laag.queue_free()
		_laag = null

## A real som card with a strip of four answers under it.  The wrapper is
## handed back so a test can do what a game does — `kaart.hulp(...)` — and
## not reach into the node behind it.
func _kaart(id: String, prio: int = 14) -> Ui.Kaart:
	return Ui.somkaart({"x": 20.0, "z": 20.0}, "3 + 2 =", {
		"id": id, "regel": "Hondje telt 3 + 2", "goed": 5, "prio": prio,
		"door": "test"})

## The overlap of two rectangles in pixels; 0 means they do not touch.
func _px(a: Rect2, b: Rect2) -> float:
	var s := a.intersection(b)
	return maxf(0.0, s.size.x) * maxf(0.0, s.size.y)

## Nothing is open: the bar costs nothing, claims no rectangle, and the world
## is fitted into the whole frame exactly as it was before the bar existed.
func test_zonder_kaart_kost_de_balk_niets() -> void:
	for kader in KADERS:
		_op(kader)
		var wat := "leeg %s" % str(kader)
		gelijk(Ui.balk_kost(), 0.0, "%s: de kost is nul" % wat)
		waar(not Ui.balk_aan(), "%s: de balk staat uit" % wat)
		gelijk(Ui.balk_rect(), Rect2(), "%s: geen papier" % wat)
		gelijk(World.balk_hoog(), 0.0, "%s: de wereld geeft niets" % wat)
		gelijk(Ui.balk_kaart(), "", "%s: geen eigenaar" % wat)
		waar(World.schaal()["k"] > 0.0, "%s: er wordt wél getekend" % wat)
		_af()

## A card with a strip docks, the paper closes on the bottom edge of the
## frame, both parts stand inside it, and the world scales DOWN to make room.
func test_de_kaart_neemt_de_balk_en_de_wereld_wijk() -> void:
	for kader in KADERS:
		_op(kader)
		var zonder := float(World.schaal()["k"])
		_kaart("k1")
		Hits.plaats()
		var wat := "kaart %s" % str(kader)
		var kost := Ui.balk_kost()
		var dak := Ui.balk_dak()
		waar(kost <= dak + 0.001, "%s: kost %.1f blijft onder dak %.1f" % [wat, kost, dak])
		if kost <= 0.0:
			# The frame is too short for this card; it floats, as it always did.
			gelijk(World.balk_hoog(), 0.0, "%s: de wereld merkt van niets" % wat)
			_af()
			continue
		gelijk(World.balk_hoog(), kost, "%s: de wereld geeft precies af" % wat)
		waar(float(World.schaal()["k"]) <= zonder + 0.0001,
			"%s: de wereld wordt niet groter" % wat)
		var b := Ui.balk_rect()
		gelijk(b.position.x, 0.0, "%s: papier begint links" % wat)
		gelijk(b.size.x, kader.x, "%s: papier is zo breed als het kader" % wat)
		gelijk(b.end.y, kader.y, "%s: papier sluit op de onderkant" % wat)
		var dbg := Hits.debug()
		waar(dbg.has("k1") and dbg.has("k1_keuzes"), "%s: beide staan geplaatst" % wat)
		var rc: Rect2 = dbg["k1"]["rect"]
		var rs: Rect2 = dbg["k1_keuzes"]["rect"]
		waar(b.encloses(rc), "%s: de kaart staat op het papier" % wat)
		waar(b.encloses(rs), "%s: de strook staat op het papier" % wat)
		waar(rc.size.x > 0.0 and rs.size.x > 0.0, "%s: beide zijn echt" % wat)
		if Ui.balk_vorm() == "hoog":
			waar(rc.end.y <= rs.position.y + 0.01,
				"%s: de kaart staat BOVEN de strook" % wat)
		_af()

## The line the reverted attempt of 2026-09-19 got wrong: a card that closes
## must give EVERY unit back, and the world must land on the exact scale it
## had before the card ever opened.
func test_de_balk_geeft_zijn_ruimte_weer_vrij() -> void:
	for kader in KADERS:
		_op(kader)
		var zonder := float(World.schaal()["k"])
		_kaart("k1")
		Hits.plaats()
		var kost := Ui.balk_kost()
		Hits.weg("k1")
		var wat := "sluiten %s" % str(kader)
		gelijk(Ui.balk_kost(), 0.0, "%s: de kost gaat naar nul" % wat)
		waar(not Ui.balk_aan(), "%s: de balk staat uit" % wat)
		gelijk(Ui.balk_kaart(), "", "%s: de eigenaar is weg" % wat)
		gelijk(float(World.schaal()["k"]), zonder,
			"%.1f: de wereld staat op de maat van vóór de kaart" % kost)
		_af()

## The paper is walled off before anything chooses a place, so no ordinary
## hotspot may end up standing on it.
func test_geen_enige_knop_staat_op_het_papier() -> void:
	for kader in KADERS:
		_op(kader)
		_kaart("k1")
		var vlak := Rect2(kader * 0.5 - Vector2(47, 37), Vector2(94, 74))
		Hits.maak({"id": "w1", "kamer": World.kamer_nu(), "x": 24.0, "z": 20.0,
			"y": 12.0, "label": "Loop", "vlak": vlak, "door": "test"})
		Hits.plaats()
		var wat := "muur %s" % str(kader)
		var b := Ui.balk_rect()
		var r: Rect2 = Hits.debug()["w1"]["rect"]
		gelijk(_px(r, b), 0.0, "%s: %s staat niet op het papier" % [wat, str(r)])
		waar(not Hits.debug()["w1"]["krap"], "%s: de knop vond een plek" % wat)
		_af()

## A help line makes the card taller and the bar grows with it — never past
## a third of the frame, never below its own rung, and never smaller than it
## was without the line.  Where the frame is too short to hold the taller
## card the bar lets go instead of clipping: the card floats, whole.
func test_de_hulplijn_groeit_de_balk_mee() -> void:
	for kader in KADERS:
		_op(kader)
		var kaart := _kaart("k1")
		var zonder := Ui.balk_kost()
		# The card's OWN height before the help line, so "grew" is measured
		# against the card and not against the bar's total cost (B4: the wide
		# docked card fits a help line on one short line, so it is shorter
		# than the bar it sits in — comparing the two was a category error).
		var kaart_zonder: float = Ui.kaart_mat(Hits.spot("k1").knoop).y
		var wat := "hulp %s" % str(kader)
		gelijk(Ui.balk_kandidaat(), "k1", "%s: de kaart is de kandidaat" % wat)
		kaart.hulp("Kijk: 3 en 2 samen zijn 5, tel de boterhammen na")
		var met := Ui.balk_bepaal()
		waar(met <= Ui.balk_dak() + 0.001, "%s: nog steeds onder het dak" % wat)
		waar(met >= zonder or met == 0.0,
			"%s: %.1f wordt niet kleiner door een extra regel" % [wat, zonder])
		if met > 0.0:
			waar(met >= Ui.balk_hoog() - 0.001, "%s: nooit onder de rung" % wat)
			waar(Ui.balk_kaart() == "k1", "%s: de balk houdt zijn kaart" % wat)
			Hits.plaats()
			var r: Rect2 = Hits.debug()["k1"]["rect"]
			waar(Ui.balk_rect().encloses(r), "%s: %s staat op het papier" % [wat, str(r)])
			waar(r.size.y >= kaart_zonder, "%s: de kaart is echt gegroeid (%s)" % [wat, str(r.size.y)])
		else:
			waar(Ui.balk_kaart() == "", "%s: de balk laat netjes los" % wat)
		_af()

## The card never grows into a tower.  A `Label` under `AUTOWRAP_WORD_SMART`
## reports its minimum at the width it last had, so a help line that arrives
## before the card's first frame used to answer 631 units for one short
## sentence and `Hits` pinned that into `custom_minimum_size` for good.  The
## height of a card with a help line is now measured by the theme at the
## width the card is drawn at, so it stays a card on every frame the shell
## hands out — with the bar under it or without.
func test_de_hulplijn_wordt_geen_toren() -> void:
	for kader in KADERS:
		_op(kader)
		var kaart := _kaart("k1")
		kaart.hulp("Tel de ballen: 3 en nog 2")
		Hits.plaats()
		var wat := "toren %s" % str(kader)
		var r: Rect2 = Hits.debug()["k1"]["rect"]
		waar(r.size.y <= 260.0, "%s: %s is een kaart, geen strook" % [wat, str(r)])
		waar(r.position.y >= 0.0 and r.end.y <= kader.y + 0.01,
			"%s: %s staat heel in het kader" % [wat, str(r)])
		waar(not Hits.debug()["k1"]["krap"], "%s: en ze vond een echte plek" % wat)
		_af()

## Two cards open: the bar belongs to the one with the highest `prio`, and it
## moves the moment a more urgent one arrives.  `balk_kandidaat()` is the
## choice itself and holds on every frame; `balk_kaart()` is who actually
## stands on the paper, which on a frame too short to dock nobody does.
func test_de_balk_volgt_de_hoogste_prio() -> void:
	for kader in KADERS:
		_op(kader)
		var wat := "prio %s" % str(kader)
		_kaart("rustig", 10)
		gelijk(Ui.balk_kandidaat(), "rustig", "%s: de enige is de kandidaat" % wat)
		_kaart("dringend", 20)
		gelijk(Ui.balk_kandidaat(), "dringend", "%s: de drukste wint" % wat)
		if Ui.balk_aan():
			gelijk(Ui.balk_kaart(), "dringend", "%s: en staat op het papier" % wat)
		Hits.weg("dringend")
		gelijk(Ui.balk_kandidaat(), "rustig", "%s: de overgeblevene erft" % wat)
		if Ui.balk_aan():
			gelijk(Ui.balk_kaart(), "rustig", "%s: en erft het papier" % wat)
		Hits.weg("rustig")
		gelijk(Ui.balk_kandidaat(), "", "%s: met niets is er geen kandidaat" % wat)
		gelijk(Ui.balk_kaart(), "", "%s: en geen eigenaar" % wat)
		_af()

## The honest limit, written down so nobody has to rediscover it: on the two
## short frames the paper cannot hold a card WITH a help line, so the card
## floats over the world exactly as it did before the bar was built.  It must
## still be placed, in the frame, and not `krap`.
func test_kort_kader_laat_de_kaart_drijven() -> void:
	for kader in [Vector2(558, 289), Vector2(676, 320), Vector2(296, 314)]:
		_op(kader)
		var kaart := _kaart("k1")
		kaart.hulp("Tel de ballen: 3 en nog 2")
		Hits.plaats()
		var wat := "drijven %s" % str(kader)
		waar(Ui.balk_kost() <= Ui.balk_dak() + 0.001, "%s: onder het dak" % wat)
		var dbg := Hits.debug()
		waar(dbg.has("k1"), "%s: de kaart staat" % wat)
		var r: Rect2 = dbg["k1"]["rect"]
		waar(r.position.x >= 0.0 and r.position.y >= 0.0
			and r.end.x <= kader.x + 0.01 and r.end.y <= kader.y + 0.01,
			"%s: %s binnen het kader" % [wat, str(r)])
		waar(not dbg["k1"]["krap"], "%s: niet krap" % wat)
		_af()

## `World.zet_balk` is the door for everything that is not a card: it
## rescales, it emits, and it does nothing at all when nothing changed.
func test_zet_balk_om_gerescaleerd_te_worden() -> void:
	_op(Vector2(1000, 648))
	var zonder := float(World.schaal()["k"])
	var keren := [0]
	var op := func(_k, _s) -> void: keren[0] += 1
	World.kader_veranderd.connect(op)
	World.zet_balk(120.0)
	gelijk(World.balk_hoog(), 120.0, "de hoogte staat er")
	waar(float(World.schaal()["k"]) <= zonder, "de wereld wordt niet groter")
	gelijk(keren[0], 1, "het kader is één keer gemeld")
	World.zet_balk(120.0)
	gelijk(keren[0], 1, "dezelfde hoogte meldt niets opnieuw")
	World.zet_balk(0.0)
	gelijk(World.balk_hoog(), 0.0, "terug naar niets")
	gelijk(float(World.schaal()["k"]), zonder, "en terug naar de oude maat")
	gelijk(keren[0], 2, "het teruggeven wordt wél gemeld")
	World.kader_veranderd.disconnect(op)
	_af()

## The bar is only worth building if the world really moves out of the way.
## On a frame that is bound by its WIDTH the height budget is not the tight
## one and nothing needs to shrink — that is fine, and honest — but across
## the ten frames the strip has to bite somewhere, or the whole task is a
## no-op dressed up as a feature.
func test_de_balk_druwt_de_wereld_werkelijk_kleiner() -> void:
	var ergens := 0
	for kader in KADERS:
		_op(kader)
		var zonder := float(World.schaal()["k"])
		World.zet_balk(minf(120.0, floorf(kader.y * 0.34)))
		var met := float(World.schaal()["k"])
		waar(met <= zonder + 0.0001,
			"%s: de wereld wordt nooit groter door een balk" % str(kader))
		if met < zonder - 0.0001:
			ergens += 1
		_af()
	waar(ergens >= 3, "op minstens drie van de tien kaders geeft de wereld echt mee (%d)" % ergens)

## Nothing changes, so nothing computes.  The bar used to be measured in
## `Ui._process`, which meant a minimum-size query on the docked card in
## every single frame a sum was open — and because `kaart_mat()` also flips
## the help rule and clears `custom_minimum_size`, every one of those frames
## re-laid the card out.  The bar is event-driven now: only `somkaart`, the
## card's `on_weg` and the `Kaart` setters that can change its shape call
## `_balk_herstel()`, so a screen that stands still must tick zero times.
##
## What this deliberately does NOT claim: `Hits._maat_van` still asks
## `Ui.kaart_mat()` for EVERY card that has a help line showing — not only
## the one docked in the bar — and it does that while `Hits.plaats()` runs,
## which is every frame.  That is the placement layer's own need (a card
## measured at the wrong width becomes a strip of frame height) and it stays
## exactly as it was; it is why this counts the bar's own recomputes and not
## the calls to `kaart_mat`.
##
## Each event brings a second, deferred pass at the end of its own frame, so
## a game that tidies the card right after receiving it (voerkar hides the
## som line and the answer box) is still caught.  That pass belongs to the
## event, not to the clock: a frame that saw no event measures nothing,
## which is exactly what the ten idle frames below assert.
func test_stilstand_verandert_niets_aan_de_balk() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_op(Vector2(990, 637))
	var kaart := _kaart("stilstaand")
	await boom.process_frame
	waar(Ui.balk_aan(), "de kaart dokt en de balk staat")
	var rust := Ui._balk_tellingen
	var kost := Ui.balk_kost()
	for _i in 10:
		await boom.process_frame
	gelijk(Ui._balk_tellingen, rust,
		"tien frames zonder iets te doen: de balk heeft geen enkele keer gerekend")
	gelijk(Ui.balk_kost(), kost, "en zijn kost is niet geschoven")
	# and every event that CAN change it is still heard
	kaart.hulp("Tel de ballen: 3 en nog 2")
	waar(Ui._balk_tellingen > rust, "de hulplijn wordt gehoord")
	await boom.process_frame   # the deferred second pass
	await boom.process_frame
	var na_hulp := Ui._balk_tellingen
	kaart.regel2("Elk blokje is 2 stuks")
	waar(Ui._balk_tellingen > na_hulp, "de tweede regel wordt gehoord")
	await boom.process_frame
	await boom.process_frame
	var na_regel2 := Ui._balk_tellingen
	for _i in 10:
		await boom.process_frame
	gelijk(Ui._balk_tellingen, na_regel2,
		"en daarna is het weer stil, ook met de hulplijn op het scherm")
	kaart.weg()
	await boom.process_frame
	waar(not Ui.balk_aan(), "met de kaart weg geeft de balk zijn ruimte terug")
	_af()

# ------------------------------------------------------------ het papier

## The check-in card of the receptie (`Hotel.paint_checkin`, step 2): two
## sentences that both open with a pictogram, a sum, and a strip of WORDS —
## the card the owner saw the ruled lines run through on 2026-09-22.
func _inchecken(id: String) -> Ui.Kaart:
	var niets := func(_k) -> void: pass
	return Ui.somkaart({"x": 20.0, "z": 20.0}, "4 × 2", {
		"id": id, "door": "test", "icoon": "🥄", "prio": 14,
		"regel": "Elke dag 2 scheppen, 4 dagen lang",
		"regel2": "📦 In huis: 20 scheppen. Genoeg?",
		"keuzes": [
			{"id": "meer", "icoon": "⬇", "tekst": "te weinig", "kort": "weinig", "kies": niets},
			{"id": "precies", "icoon": "⚖", "tekst": "precies", "kort": "precies", "kies": niets},
			{"id": "minder", "icoon": "⬆", "tekst": "blijft over", "kort": "over", "kies": niets}]})

## A card's labels only stand where they stand after `Kolom` and `Rij` did
## their deferred sort.
func _laat_zetten() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	for _i in 3:
		await boom.process_frame

## The ruled lines of the paper that carries `k`, in the CARD's coordinates:
## its own paper while it floats, the bar's while it is docked.  In `_op` the
## card and the bar share one parent and the bar stands at its origin, so the
## bar's y minus the card's y is the card's y.
func _lijnen_onder(k: UiSomkaart) -> PackedFloat32Array:
	var uit := PackedFloat32Array()
	if not k.in_balk:
		for y in k.lijn_ys():
			if y < k.size.y - 2.0:   # what `UiSomkaart._draw` draws
				uit.append(y)
		return uit
	waar(k.get_parent() == _papier.get_parent() and _papier.position == Vector2.ZERO,
		"de kaart en het papier delen één ouder")
	for y in _papier.lijnen():
		uit.append(y - k.position.y)
	return uit

## The rows a label draws, top to bottom, in the label's own coordinates.
func _rijvakken(lbl: Label) -> Array[Rect2]:
	var vakken: Array[Rect2] = []
	for i in lbl.text.length():
		var vak := lbl.get_character_bounds(i)
		if vak.size.y > 0.0 and (vakken.is_empty() or vak.position.y > vakken[-1].position.y + 0.5):
			vakken.append(vak)
	return vakken

## Every row of text on `k` stands ON exactly one of `lijnen` and none of them
## runs through its letters.  The rows come from the label's own layout and
## the positions from the global rects; the text is broken as ONE paragraph at
## the label's width (`TextParagraph`), not cut into rows the way `lijn_ys`
## does, and centred in its row the way the web build draws it (see the test
## after this one for the measured numbers).  Returns how many rows it checked.
func _staat_op_de_lijnen(k: UiSomkaart, lijnen: PackedFloat32Array, wat: String) -> int:
	var rijen := 0
	for l in [k.regel_label, k.regel2_label, k.som_label, k.hulp_label]:
		var lbl: Label = l
		if not lbl.is_visible_in_tree() or lbl.text.is_empty():
			continue
		var alinea := TextParagraph.new()
		alinea.add_string(lbl.text, lbl.get_theme_font("font"), lbl.get_theme_font_size("font_size"))
		alinea.width = lbl.size.x - lbl.get_theme_stylebox("normal").get_minimum_size().x
		alinea.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND \
			| TextServer.BREAK_ADAPTIVE
		var boven := lbl.get_global_rect().position.y - k.get_global_rect().position.y
		var vakken := _rijvakken(lbl)
		gelijk(vakken.size(), alinea.get_line_count(),
			"%s: '%s' breekt in de alinea net zo als in het label" % [wat, lbl.text])
		for r in mini(vakken.size(), alinea.get_line_count()):
			rijen += 1
			var stijg := alinea.get_line_ascent(r)
			var hoog := stijg + alinea.get_line_descent(r)
			var inkt := boven + vakken[r].position.y + (vakken[r].size.y - hoog) * 0.5
			var voet := inkt + stijg
			var op := 0
			var door := PackedFloat32Array()
			for y in lijnen:
				if y >= voet - 0.25 and y <= voet + 2.0:
					op += 1
				elif y > inkt + 1.0 and y < voet - 0.25:
					door.append(y)
			gelijk(op, 1, "%s: '%s' rij %d staat op één lijn (voet %.1f, lijnen %s)"
				% [wat, lbl.text, r + 1, voet, str(lijnen)])
			waar(door.is_empty(), "%s: geen lijn door '%s' (letters %.1f–%.1f, door %s)"
				% [wat, lbl.text, inkt, voet, str(door)])
	return rijen

## Where the web build really puts the foot of the letters, read off its own
## pixels on 2026-09-22 (`tools/speel.js` at 1280×640@2 with the card floating
## and at 1024×768@2 with it in the bar, two pixels per unit): the foot of
## "Elke", "In huis" and "4" below the top of the row that holds it.  A row
## is as tall as the whole font chain and the text is centred in it, so "row
## top + ascent" lands 2 to 4 units too high — the first try of this fix did
## exactly that, and its line cut through the foot of every letter while a
## test built on the same formula stayed green.  These numbers are the truth
## that formula has to meet.
func test_de_voet_staat_waar_de_webbouw_hem_tekent() -> void:
	for geval in [["los", 14, 17.0, 21, 25.5], ["balk", 22, 26.5, 34, 41.0]]:
		_op(Vector2(990, 637))
		var kaart := _inchecken("ci")
		if geval[0] == "los":
			kaart.hulp("🥄🥄 + 🥄🥄 + 🥄🥄 + 🥄🥄")   # too tall for the bar: it floats
		Hits.plaats()
		await _laat_zetten()
		var k: UiSomkaart = Hits.spot("ci").knoop
		var wat := "voet %s" % geval[0]
		gelijk(k.in_balk, geval[0] == "balk", "%s: de kaart staat waar de meting stond" % wat)
		gelijk(k.regel_label.get_theme_font_size("font_size"), geval[1], "%s: de zinmaat van de meting" % wat)
		gelijk(k.som_label.get_theme_font_size("font_size"), geval[3], "%s: de sommaat van de meting" % wat)
		var ys := k.lijn_ys()
		for paar in [[k.regel_label, geval[2]], [k.regel2_label, geval[2]], [k.som_label, geval[4]]]:
			var lbl: Label = paar[0]
			var rij: float = k._in_kaart(lbl).y + _rijvakken(lbl)[0].position.y
			var gevonden := false
			for y in ys:
				if absf(y - UiSomkaart.ONDER - rij - float(paar[1])) <= 0.26:
					gevonden = true
			waar(gevonden, "%s: '%s' — voet %.1f onder de rijtop gemeten, lijnen %s (rijtop %.1f)"
				% [wat, lbl.text, float(paar[1]), str(ys), rij])
		_af()

## The owner's screenshot of 2026-09-22: on the check-in card the ruled lines
## ran through the letters, floating and docked alike, because both papers
## ruled a fixed 22 unit pitch that knew nothing of the rows of text on them.
## Now every row of text stands on a line
## of its own and no line crosses one — on all ten frames, docked or floating,
## with and without a worked example, and for a card with an answer box too.
func test_de_letters_staan_op_de_lijnen() -> void:
	var gedokt := 0
	var los := 0
	for kader in KADERS:
		for soort in ["inchecken", "inchecken+hulp", "vak"]:
			_op(kader)
			var kaart := _kaart("ci") if soort == "vak" else _inchecken("ci")
			if soort == "inchecken+hulp":
				kaart.hulp("🥄🥄 + 🥄🥄 + 🥄🥄 + 🥄🥄")
			Hits.plaats()
			await _laat_zetten()
			var k: UiSomkaart = Hits.spot("ci").knoop
			if k.in_balk:
				gedokt += 1
			else:
				los += 1
			var wat := "%s %s %s" % [str(kader), soort, "balk" if k.in_balk else "los"]
			var rijen := _staat_op_de_lijnen(k, _lijnen_onder(k), wat)
			waar(rijen >= (2 if soort == "vak" else 3), "%s: %d tekstrijen gemeten" % [wat, rijen])
			_af()
	# Both papers really were measured, not just one of them.
	waar(gedokt > 0 and los > 0, "gedokt %d keer, zwevend %d keer" % [gedokt, los])

## The bar rules the whole strip, not only the rows of the card: the ruling
## goes on at the card's sentence pitch down to the bottom of the paper,
## behind the answer buttons, every line lies on the paper, and no two lines
## lie on top of each other.
func test_de_balk_lijnt_het_hele_papier() -> void:
	var gedokt := 0
	for kader in KADERS:
		_op(kader)
		_inchecken("ci")
		Hits.plaats()
		await _laat_zetten()
		var k: UiSomkaart = Hits.spot("ci").knoop
		if not k.in_balk:
			_af()
			continue
		gedokt += 1
		var wat := "papier %s" % str(kader)
		var b := Ui.balk_rect()
		var lijnen := _papier.lijnen()
		waar(lijnen.size() >= 4, "%s: %d lijnen" % [wat, lijnen.size()])
		for i in lijnen.size():
			waar(lijnen[i] > b.position.y and lijnen[i] < b.end.y,
				"%s: lijn %.1f ligt op het papier %s" % [wat, lijnen[i], str(b)])
			if i > 0:
				waar(lijnen[i] - lijnen[i - 1] >= 8.0,
					"%s: %.1f en %.1f liggen niet op elkaar" % [wat, lijnen[i - 1], lijnen[i]])
		waar(b.end.y - lijnen[lijnen.size() - 1] <= k.lijn_afstand() + UiRekenbalk.VOET,
			"%s: de lijnen lopen door tot onderaan (laatste %.1f, bodem %.1f)"
			% [wat, lijnen[lijnen.size() - 1], b.end.y])
		_af()
	waar(gedokt > 0, "de inchecksom dokt op %d van de %d kaders" % [gedokt, KADERS.size()])
