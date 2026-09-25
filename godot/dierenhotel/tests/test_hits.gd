extends Proef
## The structural placement rule of architecture.md §4.3, as a regression test.
##
## Two invariants, in every frame size and every shape the reviewer could think
## of: no placed element overlaps another, and no button (layer SPEL/HOTEL/WENS)
## overlaps ANY object box in view. A fixed card and a number tag are the only
## things allowed over the world, and they choose first.

const MATEN := [Vector2(1000, 648), Vector2(768, 1024), Vector2(360, 740),
	Vector2(296, 314), Vector2(676, 320)]

## The world frames the five ticket viewports produce (1024x768, 768x1024,
## 1280x800, 360x740, 740x360), measured on the real shell by
## `test_ui.gd::test_shell_op_vijf_schermen` and pasted here so this suite does
## not have to build a window.  That test prints them, so a drift shows up.
const KADERS := [Vector2(990, 637), Vector2(734, 788), Vector2(1170, 669),
	Vector2(326, 558), Vector2(558, 289)]

var _laag: Control = null

func _op(kader: Vector2) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = kader
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, null, _laag, _laag)
	World.meet(Rect2(Vector2.ZERO, kader))

func _af() -> void:
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	if _laag != null:
		_laag.queue_free()
		_laag = null

## Every invariant at once, for whatever is on screen right now.
func _keur(kader: Vector2, wat: String) -> void:
	var dbg := Hits.debug()
	var ids: Array = dbg.keys()
	for i in ids.size():
		var a: Dictionary = dbg[ids[i]]
		var ra: Rect2 = a["rect"]
		waar(ra.position.x >= 0.0 and ra.position.y >= 0.0
			and ra.end.x <= kader.x + 0.01 and ra.end.y <= kader.y + 0.01,
			"%s: %s binnen het kader %s" % [wat, ids[i], str(kader)])
		waar(not a["krap"], "%s: %s vond een echte plek (krap = false)" % [wat, ids[i]])
		# no button stands on any object in view
		if int(a["laag"]) != Hits.Laag.VAST:
			for j in ids.size():
				var v: Rect2 = dbg[ids[j]]["vlak"]
				if v.size.x <= 0.0:
					continue
				if str(a.get("op", "")) == "aan" and v.is_equal_approx(a["vlak"]):
					continue          # `op: aan` hangs ON its own thing, by design
				# a door sign is ON its door, and a guest in the doorway or
				# walking through it does not move it (owner, 2026-09-24: the
				# signs jumped as Boef walked in)
				if str(a.get("deurplek", "")) != "" and str(ids[j]).begins_with(Ui.PLAAT):
					continue
				var snij := ra.intersection(v)
				gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
					"%s: %s dekt voorwerp van %s" % [wat, ids[i], ids[j]])
		# no two placed elements overlap
		for j in range(i + 1, ids.size()):
			var rb: Rect2 = dbg[ids[j]]["rect"]
			var s2 := ra.intersection(rb)
			gelijk(maxf(0.0, s2.size.x) * maxf(0.0, s2.size.y), 0.0,
				"%s: %s en %s overlappen" % [wat, ids[i], ids[j]])

func test_knop_dekt_zijn_voorwerp_nooit() -> void:
	for kader in MATEN:
		_op(kader)
		var vlak := Rect2(kader * 0.5 - Vector2(47, 37), Vector2(94, 74))
		Hits.maak({"id": "t1", "kamer": World.kamer_nu(), "x": 24.0, "z": 20.0, "y": 12.0,
			"label": "Loop", "vlak": vlak, "door": "test"})
		Hits.plaats()
		gelijk(Hits.dekking("t1"), 0.0, "dekking bij kader %s" % str(kader))
		var r: Rect2 = Hits.debug()["t1"]["rect"]
		waar(r.size.x >= 48.0 and r.size.y >= 48.0, "tikdoel >= 48 px bij %s" % str(kader))
		_keur(kader, "enkel %s" % str(kader))
		_af()

## The reviewer's case: a fixed `midden` card, and four `boven` buttons whose
## objects sit just under it, so the band they want IS the card's band.  Before
## the fix three of the four landed on the card (1728 px2 each) because `midden`
## returned early and never reserved a cell.
func test_vaste_kaart_reserveert_haar_plek() -> void:
	for kader in [Vector2(1000, 648), Vector2(360, 740), Vector2(768, 1024)]:
		_op(kader)
		Hits.maak({"id": "kaart", "kamer": World.kamer_nu(),
			"x": 24.0, "z": 20.0, "y": 0.0, "op": "midden", "vast": true, "prio": 14,
			"label": "Hoeveel scheppen samen?", "maat": Vector2(200, 78), "door": "test"})
		Hits.plaats()
		var kaart: Rect2 = Hits.debug()["kaart"]["rect"]
		for i in 4:
			var vlak := Rect2(Vector2(kaart.position.x + i * 40.0, kaart.end.y + 6.0),
				Vector2(48, 40))
			Hits.maak({"id": "k%d" % i, "kamer": World.kamer_nu(),
				"x": 24.0 + i * 0.1, "z": 20.0, "y": 12.0, "label": "Knop",
				"vlak": vlak, "door": "test"})
		Hits.plaats()
		kaart = Hits.debug()["kaart"]["rect"]
		for i in 4:
			var r: Rect2 = Hits.debug()["k%d" % i]["rect"]
			var snij := r.intersection(kaart)
			gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
				"knop %d staat niet op de kaart, kader %s" % [i, str(kader)])
		_keur(kader, "kaart %s" % str(kader))
		_af()

## An object against the top edge has no band above it: the button must go below.
func test_voorwerp_bovenaan_wijkt_naar_onder() -> void:
	for kader in [Vector2(1000, 648), Vector2(360, 740)]:
		_op(kader)
		Hits.maak({"id": "top", "kamer": World.kamer_nu(), "x": 24.0, "z": 20.0, "y": 12.0,
			"label": "Loop", "vlak": Rect2(Vector2(kader.x * 0.5 - 47, 0), Vector2(94, 74)),
			"door": "test"})
		Hits.plaats()
		var d: Dictionary = Hits.debug()["top"]
		gelijk(d["op"], "onder", "boven past niet, dus onder, kader %s" % str(kader))
		gelijk(Hits.dekking("top"), 0.0, "0 %% dekking, kader %s" % str(kader))
		_keur(kader, "bovenrand %s" % str(kader))
		_af()

func test_tien_knoppen_op_een_voorwerp() -> void:
	for kader in [Vector2(1000, 648), Vector2(360, 740)]:
		_op(kader)
		var vlak := Rect2(kader * 0.5 - Vector2(47, 37), Vector2(94, 74))
		for i in 10:
			Hits.maak({"id": "v%d" % i, "kamer": World.kamer_nu(), "x": 24.0 + i * 0.1,
				"z": 20.0, "y": 12.0, "label": "K%d" % i, "vlak": vlak, "door": "test"})
		Hits.plaats()
		_keur(kader, "tien %s" % str(kader))
		_af()

func test_twee_knoppen_delen_geen_plek() -> void:
	_op(Vector2(1000, 648))
	var vlak := Rect2(Vector2(453, 287), Vector2(94, 74))
	for i in 4:
		Hits.maak({"id": "t%d" % i, "kamer": World.kamer_nu(), "x": 24.0 + i, "z": 20.0,
			"y": 12.0, "label": "Knop", "vlak": vlak, "door": "test"})
	Hits.plaats()
	_keur(Vector2(1000, 648), "vier")
	_af()

# ---------------------------------------------------------- de antwoordstrook

## The strip of four numbers hangs on its card, stays inside the frame and every
## button is a real tap target — on every frame size, the low landscape phone
## included.  Since `B3` the strip no longer has to sit a fixed `Hits.KLEEF`
## from the card: on the maths bar the two stand where `Ui.balk_plek()` put
## them, and the distance there is the bar's own `BALK_GAT`.  What this test
## still guards is that the strip exists, fits, and is tappable.
func test_antwoordstrook_kleeft_aan_de_kaart() -> void:
	for kader in MATEN + KADERS:
		_op(kader)
		var kaart := Ui.somkaart({"x": 24.0, "z": 20.0}, "3 + 2 =", {
			"id": "pk", "door": "test", "kamer": World.kamer_nu(), "goed": 5,
			"icoon": "🥄", "regel": "Hoeveel scheppen samen?", "max": 2,
			"on_ok": func(_n, _k) -> void: pass})
		Hits.plaats()
		var dbg := Hits.debug()
		waar(not dbg.has("pk_pad"), "geen toetsenbord meer bij kader %s" % str(kader))
		waar(dbg.has("pk_keuzes"), "de strook staat er bij kader %s" % str(kader))
		if dbg.has("pk_keuzes"):
			var st: Rect2 = dbg["pk_keuzes"]["rect"]
			print("[maat] strook bij %s staat %s" % [str(kader), dbg["pk_keuzes"]["op"]])
			waar(st.position.x >= 0.0 and st.end.x <= kader.x + 0.01
				and st.position.y >= 0.0 and st.end.y <= kader.y + 0.01,
				"de strook past in het kader %s (%s)" % [str(kader), str(st)])
			var knoop := Hits.spot("pk_keuzes").knoop
			gelijk(knoop.get_node("Rij").get_child_count(), 4, "vier knoppen, %s" % str(kader))
			for k in knoop.get_node("Rij").get_children():
				var m: Vector2 = (k as Control).custom_minimum_size
				waar(m.x >= 44.0 and m.y >= 44.0, "knop %s is een tikdoel bij %s" % [k.name, str(kader)])
		_keur(kader, "strook %s" % str(kader))
		kaart.weg()
		_af()

## The card and its answers are ONE pair (owner, 2026-09-23: "de text van
## opdrachten staat soms ver van waar ik kan klikken voor antwoorden").  A wide
## thing right under the card — the desk under the check-in card — used to push
## the strip onto the foot of the frame while the card stayed up: the width of
## the room between the question and its buttons.  Now the strip hangs against
## its card on every frame, on a side where it covers no thing.
func test_kaart_en_antwoorden_staan_samen() -> void:
	for kader in MATEN + KADERS:
		_op(kader)
		var mik := World.mik_punt(24.0, 20.0, 22.0)
		var bureau := Rect2(Vector2(maxf(0.0, mik.x - 320.0), mik.y + 70.0),
			Vector2(640.0, 150.0))
		Hits.maak({"id": "bureau", "door": "test", "kamer": World.kamer_nu(),
			"x": 24.0, "z": 20.0, "y": 4.0, "icoon": "🛎️", "label": "Balie",
			"vlak": bureau, "op": "aan"})
		var kaart := Ui.somkaart({"x": 24.0, "z": 20.0}, "4 × 5", {
			"id": "pr", "door": "test", "kamer": World.kamer_nu(), "goed": 20,
			"balk": false, "icoon": "🥄", "regel": "Voer voor 4 dagen: elke dag 5 scheppen",
			"regel2": "📦 In de kast: 40 scheppen. Genoeg?"})
		Hits.plaats()
		var dbg := Hits.debug()
		var wat := "kader %s" % str(kader)
		waar(dbg.has("pr") and dbg.has("pr_keuzes"), "%s: kaart en strook staan er" % wat)
		if dbg.has("pr") and dbg.has("pr_keuzes"):
			var kr: Rect2 = dbg["pr"]["rect"]
			var sr: Rect2 = dbg["pr_keuzes"]["rect"]
			waar(_tegen(kr, sr), "%s: de strook %s hangt tegen de kaart %s" % [wat, str(sr), str(kr)])
			gelijk(str(dbg["pr_keuzes"]["op"]), "kleef", "%s: aan de kaart, niet op de voet" % wat)
			var hart := kr.get_center().y
			if not (hart > bureau.position.y and hart < bureau.end.y):
				waar(sr.intersection(bureau).get_area() <= 0.0,
					"%s: en de strook ligt niet op de balie" % wat)
		kaart.weg()
		_af()

## Two rectangles side by side: at most a few units apart on one axis and
## sharing a stretch of the other.
func _tegen(a: Rect2, b: Rect2) -> bool:
	var gat_x := maxf(b.position.x - a.end.x, a.position.x - b.end.x)
	var gat_y := maxf(b.position.y - a.end.y, a.position.y - b.end.y)
	var boven_elkaar := gat_y >= -0.5 and gat_y <= Hits.KLEEF + 1.0 \
		and minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x) > 8.0
	var naast_elkaar := gat_x >= -0.5 and gat_x <= Hits.KLEEF + 1.0 \
		and minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y) > 8.0
	return boven_elkaar or naast_elkaar

## HOTEL.md §9: the sum hangs ABOVE the bowl and the guest stays whole.  A fixed
## card is one of the two things allowed over the world, but never over the
## object it belongs to — it lifts itself in whole bands until it is clear.
func test_kaart_staat_nooit_op_haar_eigen_voorwerp() -> void:
	for kader in KADERS:
		_op(kader)
		# an object sitting exactly where the card would like to be
		var mik := World.mik_punt(24.0, 20.0, 6.0)
		var vlak := Rect2(mik - Vector2(60, 40), Vector2(120, 80))
		var kaart := Ui.somkaart({"x": 24.0, "z": 20.0}, "3 + 2 =", {
			"id": "ov", "door": "test", "kamer": World.kamer_nu(), "hoog": 6.0,
			"pad": false, "icoon": "🥄", "regel": "Hoeveel scheppen samen?",
			"vlak": vlak})
		Hits.plaats()
		gelijk(Hits.dekking("ov"), 0.0,
			"de kaart dekt haar eigen voorwerp niet, kader %s" % str(kader))
		var r: Rect2 = Hits.debug()["ov"]["rect"]
		waar(Rect2(Vector2.ZERO, kader).encloses(r),
			"en blijft in het kader %s (%s)" % [str(kader), str(r)])
		kaart.weg()
		_af()

## `B3` (PLAN.md): the sum and its answer strip dock IN the maths bar, and the
## strip is always on the far side of the card — below it in vorm `hoog`, to
## the right of it in vorm `laag`.  The old test asked `op == "kleef"`, which
## quietly accepted a strip ABOVE the card; that is exactly what the bar is for,
## so the anchor and the order are now required, not inferred.
##
## `Vector2(700, 430)` is not one of the ticket viewports.  It is here because
## it is the shortest frame in which the `laag` form still docks: the bar needs
## its card and its strip side by side AND `WERELD_BANDEN` bands left over, and
## none of the ten real frames lands in that window.  Without it the `laag`
## branch of this test would never run.
func test_strook_staat_onder_de_som_in_de_balk() -> void:
	var balk_kaders := 0
	var laag_kaders := 0
	for kader in MATEN + KADERS + [Vector2(700, 430)]:
		_op(kader)
		var kaart := Ui.somkaart({"x": 24.0, "z": 20.0}, "3 + 2 =", {
			"id": "kk", "door": "test", "kamer": World.kamer_nu(), "goed": 5,
			"icoon": "🥄", "regel": "Hoeveel scheppen samen?", "max": 2,
			"on_ok": func(_n, _k) -> void: pass})
		Hits.plaats()
		var dbg := Hits.debug()
		if not Ui.balk_aan():
			print("[balk] kader %s: balk uit (dak %.0f ruimte %.0f nodig %.0f)" % [
				str(kader), Ui.balk_dak(), Ui.balk_ruimte(), Ui.balk_nodig()])
			_keur(kader, "geen balk %s" % str(kader))
			kaart.weg()
			_af()
			continue
		balk_kaders += 1
		var vorm := Ui.balk_vorm()
		if vorm == "laag":
			laag_kaders += 1
		var balk := Ui.balk_rect()
		waar(balk.size.x > 0.0 and balk.size.y > 0.0,
			"%s: de balk heeft een rechthoek (%s)" % [str(kader), str(balk)])
		gelijk(dbg["kk"]["op"], "balk",
			"%s/%s: de som verankert op de balk" % [str(kader), vorm])
		gelijk(dbg["kk_keuzes"]["op"], "balk",
			"%s/%s: de strook volgt de som naar de balk" % [str(kader), vorm])
		var kr: Rect2 = dbg["kk"]["rect"]
		var sr: Rect2 = dbg["kk_keuzes"]["rect"]
		waar(balk.encloses(kr),
			"%s/%s: de kaart staat volledig IN de balk (%s in %s)"
				% [str(kader), vorm, str(kr), str(balk)])
		waar(balk.encloses(sr),
			"%s/%s: de strook staat volledig IN de balk (%s in %s)"
				% [str(kader), vorm, str(sr), str(balk)])
		if vorm == "laag":
			waar(kr.end.x <= sr.position.x + 0.01,
				"%s: laag — kaart links van de strook (%s | %s)"
					% [str(kader), str(kr), str(sr)])
		else:
			waar(kr.end.y <= sr.position.y + 0.01,
				"%s: hoog — kaart boven de strook (%s boven %s)"
					% [str(kader), str(kr), str(sr)])
		_keur(kader, "balk %s" % str(kader))
		kaart.weg()
		_af()
	waar(balk_kaders >= 1,
		"de balk staat in minstens één van de elf kaders (%d)" % balk_kaders)
	waar(laag_kaders >= 1,
		"het laag-formaat is ook echt getest (%d kader(s))" % laag_kaders)

## `B3` stap 3 (PLAN.md): a spot that anchors on the maths bar is exempt from
## `MAX_PER_KAMER`.  The bar limits itself already — one card and one strip,
## and `Ui.balk_bepaal()` lets go of both when they do not fit — so counting
## those two against the ceiling of sixteen took two places away from the room
## for nothing.  Filled to the ceiling and one over, the room now loses one of
## its OWN buttons and keeps both bar spots: the kitchen, which sits right
## against that ceiling, has its two places back.
func test_balkplekken_tellen_niet_tegen_de_plafond() -> void:
	var kader := Vector2(1000, 648)
	_op(kader)
	var totaal := Hits.MAX_PER_KAMER + 1
	for i in totaal:
		Hits.maak({"id": "v%d" % i, "kamer": World.kamer_nu(),
			"x": 6.0 + i * 1.5, "z": 20.0, "y": 12.0, "label": "K%d" % i,
			"vlak": Rect2(Vector2(30.0 + i * 56.0, 40.0), Vector2(40, 40)),
			"door": "test"})
	var kaart := Ui.somkaart({"x": 24.0, "z": 20.0}, "3 + 2 =", {
		"id": "pl", "door": "test", "kamer": World.kamer_nu(), "goed": 5,
		"icoon": "🥄", "regel": "Hoeveel scheppen samen?", "max": 2,
		"on_ok": func(_n, _k) -> void: pass})
	Hits.plaats()
	var dbg := Hits.debug()
	gelijk(Ui.balk_kaart(), "pl", "de kaart won de balk")
	waar(dbg.has("pl"), "de balkkaart staat er")
	waar(dbg.has("pl_keuzes"), "de balkstrook staat er")
	var over := 0
	for i in totaal:
		if dbg.has("v%d" % i):
			over += 1
	print("[plafond] %d gewone knoppen + 2 balkplekken -> %d gewoon over"
		% [totaal, over])
	gelijk(over, Hits.MAX_PER_KAMER,
		"de kamer verliest een eigen knop, geen balkplek")
	_keur(kader, "plafond")
	kaart.weg()
	_af()

# ------------------------------------------------------- elk voorwerp, elke kamer

## The ticket's own gate: walk EVERY piece of decor of EVERY room through the
## band grid, in every frame size, and prove that the button hung on it covers
## 0 % of it — and of every other object standing beside it.
##
## The pieces are handled in batches, because a room like the garden holds 35
## of them (grass tufts, fence posts, flowers) while the hotel never shows more
## than a handful of buttons at once; a 214 unit high frame has three bands, so
## thirty-five simultaneous buttons is not a layout, it is a stress test with a
## foregone conclusion.  Every piece is still visited, and every batch is held
## to both invariants.
func test_elk_voorwerp_in_elke_kamer_blijft_vrij() -> void:
	var gemeten := 0
	var stukken := 0
	for kamer_id in Rooms.lijst():
		var r := Rooms.get_kamer(kamer_id)
		if r == null:
			continue
		for kader in KADERS:
			var per := 8 if kader.y >= 400.0 else 4
			var i := 0
			while i < r.decor.size():
				_op(kader)
				World.naar(kamer_id)
				World.meet(Rect2(Vector2.ZERO, kader))
				var n := 0
				while n < per and i < r.decor.size():
					var stuk: Dictionary = r.decor[i]
					i += 1
					var x := float(stuk.get("x", 0))
					var z := float(stuk.get("z", 0))
					var y := float(stuk.get("y", 0))
					var vlak := World.vlak_van(str(stuk["n"]), x, z, y, stuk.get("params", {}))
					if vlak.size.x <= 0.0 or vlak.size.y <= 0.0:
						# no plate (that model belongs to another ticket): the aim point
						var mik := World.mik_punt(x, z, y)
						vlak = Rect2(mik - Vector2(32, 24), Vector2(64, 48))
					else:
						gemeten += 1
					if not Rect2(Vector2.ZERO, kader).intersects(vlak):
						continue          # off screen: the hotel places no button for it
					Hits.maak({"id": "d%d" % n, "kamer": kamer_id, "x": x, "z": z,
						"y": maxf(4.0, y), "icoon": "🐾", "label": "Kijk",
						"titel": "kijk", "vlak": vlak, "door": "test"})
					n += 1
					stukken += 1
				Hits.plaats()
				_keur(kader, "%s bij %s" % [kamer_id, str(kader)])
				for k in n:
					gelijk(Hits.dekking("d%d" % k), 0.0,
						"%s: knop %d dekt 0 %% bij %s" % [kamer_id, k, str(kader)])
				_af()
	waar(stukken > 0, "er is decor gekeurd (%d plaatsingen, %d met een echte plaat)"
		% [stukken, gemeten])

# ------------------------------------------------------ de echte receptie

## The screens the real shell is measured on for the two receptie tests below.
const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(1280, 800),
	Vector2i(360, 740)]

## The whole shell in a SubViewport, with a fresh hotel in the receptie.  The
## camera only centres a room when a viewport is registered, so a REAL receptie
## needs the real shell — placing hotspots against a camera at the origin proves
## nothing about the room the child sees.
func _hotel_op(maat: Vector2i) -> Dictionary:
	var boom := Engine.get_main_loop() as SceneTree
	var vp := SubViewport.new()
	vp.size = maat
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	boom.root.add_child(vp)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var shell := scene.instantiate()
	shell.set_meta("geen_start", true)     # never touch the save from a test
	vp.add_child(shell)
	for _f in 4:
		await boom.process_frame
	# NO `State.start_gekozen()`: that would switch autosaving on for the rest of
	# the suite, and a later fixture (a corrupt save, the start screen) would be
	# raced by a timer of this shell writing a fresh day over it.
	State.nieuw_spel()
	Hotel.start()
	for _f in 4:
		await boom.process_frame
	var kader: Control = shell.get_node("Scherm/Kolom/Middenrij/Kaderdoos/Kader")
	return {"vp": vp, "shell": shell, "kader": kader.size}

func _hotel_af(h: Dictionary) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	Ui.naamplaten_leeg()
	Hits.wis_alles()
	(h["vp"] as SubViewport).queue_free()
	await boom.process_frame
	Ui.registreer_lagen(null, null, null)
	State.nieuw_spel()          # and the save gate is shut again

## How far a placed rectangle stands from the object it belongs to.
func _gat_y(r: Rect2, vlak: Rect2) -> float:
	return maxf(0.0, maxf(vlak.position.y - r.end.y, r.position.y - vlak.end.y))

## I1 finding 2, with the room the owner asked for.  The desk stands along the
## back-right wall now, so the band ABOVE the bell is the notice board's plate
## and the band above the door is off the frame: a button that only asks for "a
## free cell in the band above" slides along the top edge and ends up a screen's
## width from the thing it belongs to (the 🔔 Bel button beside the door in
## `.fanout/scratch/godot-w1/shots/ipad-land-receptie.png`).
##
## The rule this asserts: a button's centre is at most one band (52) from its
## object vertically and at most one column (56) beyond its object's own width
## horizontally — unless both bands beside the object were full, and then the
## placement says so itself (`gestapeld`).
func test_receptie_knoppen_staan_bij_hun_voorwerp() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	for maat in SCHERMEN:
		var h: Dictionary = await _hotel_op(maat)
		var kader: Vector2 = h["kader"]
		var dbg := Hits.debug()
		var gemeten := 0
		var gestapeld := 0
		for id in dbg.keys():
			var d: Dictionary = dbg[id]
			var vlak: Rect2 = d["vlak"]
			if vlak.size.x <= 0.0 or vlak.size.y <= 0.0:
				continue
			if int(d["laag"]) == Hits.Laag.VAST:
				continue          # a card and a tag may stand over the world
			if bool(d.get("gestapeld", false)):
				gestapeld += 1
				continue          # both bands beside the object were full
			gemeten += 1
			var r: Rect2 = d["rect"]
			waar(_gat_y(r, vlak) <= Hits.RIJ + 0.01,
				"%s: %s staat %.0f eenheden van zijn voorwerp (max %d), knop %s voorwerp %s"
					% [str(maat), id, _gat_y(r, vlak), Hits.RIJ, str(r), str(vlak)])
			waar(absf(r.get_center().x - vlak.get_center().x) <= vlak.size.x + Hits.KOL + 0.01,
				"%s: %s staat %.0f eenheden naast zijn voorwerp (max %.0f)"
					% [str(maat), id, absf(r.get_center().x - vlak.get_center().x),
						vlak.size.x + Hits.KOL])
		waar(gemeten >= 2 and gemeten + gestapeld >= 3,
			"%s: %d knoppen tegen hun voorwerp gemeten, %d gestapeld (band vol)"
				% [str(maat), gemeten, gestapeld])
		# V1 finding 5: EVERY hotspot at boot knows the thing it belongs to, so
		# `dekking_max = 0.00` in the browser probe counts all five and not three
		# — the two task cards hang on the notice board they are pinned to.
		var zonder: Array[String] = []
		for id in dbg.keys():
			var v: Rect2 = dbg[id]["vlak"]
			if v.size.x <= 0.0 or v.size.y <= 0.0:
				zonder.append(id)
		gelijk(zonder.size(), 0,
			"%s: elke hotspot kent zijn voorwerp, zonder: %s" % [str(maat), str(zonder)])
		_keur(kader, "receptie %s" % str(maat))
		await _hotel_af(h)
	State.s = bewaard

## I1 finding 3: three guests at the desk.  A name plate is a hotspot of kind
## `naam` now, so it reserves its cells like a number tag and the Prikbord
## button can no longer end up under "Boef".
func test_naamplaten_nemen_hun_plek_in() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var boom := Engine.get_main_loop() as SceneTree
	var soorten := ["hond", "poes", "konijn"]
	var namen := ["Boef", "Mispel", "Pluis"]
	for maat in [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740)]:
		var h: Dictionary = await _hotel_op(maat)
		var kader: Vector2 = h["kader"]
		# three guests in front of the desk, where a family waits to check in
		for i in 3:
			World.zet("gast%d" % i, "receptie", 40.0 + i * 20.0, 48.0,
				{"kind": soorten[i], "naam": namen[i], "nr": i})
		World.vuil()
		for _f in 4:
			await boom.process_frame
		var dbg := Hits.debug()
		for i in 3:
			var id := Ui.PLAAT + "gast%d" % i
			waar(dbg.has(id), "%s: de naamplaat van %s staat er" % [str(maat), namen[i]])
			if not dbg.has(id):
				continue
			var r: Rect2 = dbg[id]["rect"]
			var dier := World.vlak_van_dier("gast%d" % i)
			var snij := r.intersection(dier)
			gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
				"%s: %s staat niet op zijn gast" % [str(maat), namen[i]])
			# against the head, or one whole band higher when that place was
			# taken — the grid steps in bands, and the plate keeps 2 units of air
			waar(_gat_y(r, dier) <= Hits.RIJ + Hits.GAT,
				"%s: %s hangt tegen zijn gast (%s tegen %s)"
					% [str(maat), namen[i], str(r), str(dier)])
			waar(absf(r.get_center().x - dier.get_center().x) <= dier.size.x + Hits.KOL + 0.01,
				"%s: %s hangt bij zijn gast" % [str(maat), namen[i]])
			var spot := Hits.spot(id)
			waar(spot != null and not (spot.knoop is BaseButton),
				"%s: %s is geen knop" % [str(maat), namen[i]])
			waar(spot != null and spot.knoop.get_parent() == Ui.naamlaag,
				"%s: %s hangt in de naamlaag" % [str(maat), namen[i]])
		# no plate on a button and no plate on a plate: `_keur`'s own rule
		_keur(kader, "naamplaten %s" % str(maat))
		for i in 3:
			World.weg("gast%d" % i)
		await _hotel_af(h)
	State.s = bewaard

## V1 finding 4: a fixed card may hang over the world — that is what makes it a
## card — but never over the COUNTER.  The bell, the till, the guest book and
## the desk lamp all stand on `Kamer.balie`, and the bill's own card was anchored
## on the desk since I1, so it covered the till while the child counted.
## `B3` (PLAN.md): the maths bar never touches the counter, the card that won
## the bar stands IN it, and the card that did not win stays by its own object.
## The old version only asked that no `midden` card overlap the desk; with the
## bar in play that says nothing about where the winning card actually went.
func test_kaart_laat_de_balie_vrij() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var boom := Engine.get_main_loop() as SceneTree
	for maat in [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740)]:
		var h: Dictionary = await _hotel_op(maat)
		Hotel.bel()                       # the check-in card, on the desk plek
		for _f in 3:
			await boom.process_frame
		var gast: Dictionary = State.s["nieuweGast"] if State.s["nieuweGast"] != null else {}
		if gast.is_empty() and not (State.s["gasten"] as Array).is_empty():
			gast = State.s["gasten"][0]
		Econ.rekening({"gast": gast, "fam": "Bakker", "nachten": 2, "prijs": 3,
			"totaal": 6, "betaald": 6})   # and the bill's card, anchored on the desk
		for _f in 3:
			await boom.process_frame
		var balie := World.vlak_van_balie("receptie")
		waar(balie.size.x > 0.0 and balie.size.y > 0.0,
			"%s: de balie heeft een vlak (%s)" % [str(maat), str(balie)])
		var dbg := Hits.debug()
		var balk := Ui.balk_rect()
		var winnaar := Ui.balk_kaart()
		print("[balie] %s: balk=%s winnaar=%s kaarten=%s" % [str(maat), str(balk),
			winnaar, str(dbg.keys())])
		# 1) the bar never reaches the counter
		if Ui.balk_aan():
			var snij: Rect2 = balk.intersection(balie)
			gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
				"%s: de balk raakt de balie nooit (%s tegen %s)"
					% [str(maat), str(balk), str(balie)])
			waar(winnaar != "", "%s: er is een kaart die de balk won" % str(maat))
			if winnaar != "" and dbg.has(winnaar):
				gelijk(str(dbg[winnaar]["op"]), "balk",
					"%s: %s verankert op de balk" % [str(maat), winnaar])
				waar(balk.encloses(dbg[winnaar]["rect"]),
					"%s: de winnende kaart staat volledig in de balk (%s in %s)"
						% [str(maat), str(dbg[winnaar]["rect"]), str(balk)])
		# 2) every other card stays by its own object, out of the bar
		var tweede := 0
		for id in ["ci_som", "rek_som"]:
			if not dbg.has(id) or id == winnaar:
				continue
			tweede += 1
			var d: Dictionary = dbg[id]
			var r: Rect2 = d["rect"]
			var mik: Vector2 = d["mik"]
			print("[balie] %s: %s op=%s rect=%s mik=%s" % [str(maat), id,
				str(d["op"]), str(r), str(mik)])
			if Ui.balk_aan():
				var s2: Rect2 = r.intersection(balk)
				gelijk(maxf(0.0, s2.size.x) * maxf(0.0, s2.size.y), 0.0,
					"%s: %s staat buiten de balk (%s)" % [str(maat), id, str(r)])
			var s3: Rect2 = r.intersection(balie)
			gelijk(maxf(0.0, s3.size.x) * maxf(0.0, s3.size.y), 0.0,
				"%s: %s laat de balie vrij (%s tegen %s)"
					% [str(maat), id, str(r), str(balie)])
			# "bij haar voorwerp": the card still covers the column of its own
			# aim point (a card wider than the room is clamped, so it may not
			# be centred on it).  Vertically it is pushed out of the bar, not
			# off the screen: the desk's own aim point lies inside the bar, so
			# the only honest bound is "above the paper", which is the check
			# above; the frame check in `_keur` keeps it on the glass.
			waar(r.position.x <= mik.x and mik.x <= r.end.x + 0.01,
				"%s: %s dekt de kolom van haar eigen voorwerp niet (%s, mik %s)"
					% [str(maat), id, str(r), str(mik)])
			if Ui.balk_aan():
				waar(r.end.y <= balk.position.y + 0.01,
					"%s: %s wijkt boven de balk uit, niet weg van haar voorwerp (%s, balk %s)"
						% [str(maat), id, str(r), str(balk)])
		waar(tweede >= 1, "%s: er stond een tweede kaart bij haar voorwerp (%d)"
			% [str(maat), tweede])
		Econ.rekening_stop()
		await _hotel_af(h)
	State.s = bewaard

## V1 finding 1: the checkout bubble "<naam> gaat naar huis" is made while its
## guest may still be in another room.  A hotspot that is not laid out this pass
## used to keep its Control on the glass at whatever size it had — for a bubble
## that was never placed, 0 x 0: a stylebox blob of ten pixels with the sentence
## spilling down the frame, one letter per line, for the three seconds the
## bubble lives (`/tmp/v1/shots/E1-rekening-stap1.png`, copied to
## `.fanout/scratch/godot-i1/`).  Two rules fix the class: `Hits` hides what it
## does not place, and a bubble is never smaller than its own content or 48 px.
func test_wolk_op_een_gast_in_een_andere_kamer() -> void:
	var kader := Vector2(1000, 648)
	_op(kader)
	World.naar("receptie")
	World.meet(Rect2(Vector2.ZERO, kader))
	World.zet("weggast", "kamer1", 40.0, 40.0, {"kind": "hond", "naam": "Boef"})
	var volg := func() -> Dictionary:
		var d = World.dier("weggast")
		if d == null:
			return {}
		return {"x": d.x, "z": d.z, "kamer": d.kamer, "vlak": World.vlak_van_dier("weggast")}
	Ui.wolk({"id": "af", "door": "test", "kamer": "receptie", "volg": volg,
		"hoog": 54, "icoon": "👪", "tekst": "Boef gaat naar huis", "klas": "goed"})
	Hits.plaats()
	var s := Hits.spot("af")
	waar(s != null and is_instance_valid(s.knoop), "de wolk bestaat")
	if s == null:
		_af()
		return
	# the guest is in kamer1: nothing of the bubble is on the glass
	waar(not s.knoop.visible, "een wolk op een gast in een andere kamer staat niet in beeld")
	waar(not Hits.debug().has("af"), "en heeft geen plek in dit doorloopje")
	var minimaal := s.knoop.get_combined_minimum_size()
	waar(minimaal.x >= 48.0 and minimaal.y >= 48.0,
		"en is nooit kleiner dan een tikdoel (%s)" % str(minimaal))
	# the guest walks in: now the bubble is a real, readable bubble
	World.zet("weggast", "receptie", 40.0, 40.0, {"kind": "hond", "naam": "Boef"})
	Hits.plaats()
	waar(s.knoop.visible, "zodra de gast er is, staat de wolk er wel")
	var r: Rect2 = Hits.debug()["af"]["rect"]
	waar(r.size.x >= 48.0 and r.size.y >= 48.0, "de wolk is minstens 48 x 48 (%s)" % str(r))
	waar(Rect2(Vector2.ZERO, kader).encloses(r), "en staat in het kader (%s)" % str(r))
	var w := s.knoop as UiWolk
	waar(w != null and w.zeg_label.get_line_count() == 1,
		"de zin staat op een regel (%d)" % (w.zeg_label.get_line_count() if w else -1))
	waar(w != null and w.zeg_label.size.x >= 60.0,
		"en de zin heeft echte breedte (%s)" % str(w.zeg_label.size if w else Vector2.ZERO))
	_keur(kader, "afscheidswolk")
	World.weg("weggast")
	_af()

# --------------------------------------------------------------------- lenen

## `ctx.hotspots.pak(id, fn)` borrows one of the hotel's own buttons; stopping
## the game hands it back untouched (world.md §5.3).
func test_geleende_knop_gaat_terug() -> void:
	_op(Vector2(1000, 648))
	var hotel_telde := [0]
	var spel_telde := [0]
	Hits.maak({"id": "bel", "kamer": World.kamer_nu(), "x": 10.0, "z": 10.0, "y": 12.0,
		"icoon": "🔔", "label": "Bel", "titel": "Bel voor de volgende gast",
		"door": "hotel", "aan": func(_s) -> void: hotel_telde[0] += 1})
	var knop := Hits.spot("bel").knoop as BaseButton
	knop.emit_signal("pressed")
	gelijk(hotel_telde[0], 1, "de bel doet zijn eigen werk")
	waar(Hits.leen("bel", "tobbe", func(_s) -> void: spel_telde[0] += 1), "het spel leent de bel")
	waar(not Hits.leen("bel", "was", func(_s) -> void: pass), "een tweede lener krijgt niets")
	knop.emit_signal("pressed")
	gelijk(spel_telde[0], 1, "de bel doet nu het werk van het spel")
	gelijk(hotel_telde[0], 1, "en niet meer dat van het hotel")
	Hits.wis_eigenaar("tobbe")          # exactly what Games.stop() does
	knop.emit_signal("pressed")
	gelijk(hotel_telde[0], 2, "na het spel is de bel weer van het hotel")
	gelijk(spel_telde[0], 1, "en het spel hoort niets meer")
	_af()

## A hotspot that declares `drop` gets a catch area over button AND object, in
## its own layer under the buttons (world.md §5.4 step 8).
func test_vangvlak_dekt_knop_en_voorwerp() -> void:
	_op(Vector2(1000, 648))
	var vlak := Rect2(Vector2(400, 300), Vector2(94, 74))
	Hits.maak({"id": "bak", "kamer": World.kamer_nu(), "x": 24.0, "z": 20.0, "y": 7.0,
		"icoon": "🍪", "label": "Vol", "kind": "drop", "drop": "bak",
		"data": {"kamer": "keuken"}, "vlak": vlak, "door": "test"})
	Hits.plaats()
	var s := Hits.spot("bak")
	waar(s.vangvlak != null, "er is een vangvlak")
	if s.vangvlak != null:
		var vang := Rect2(s.vangvlak.position, s.vangvlak.size)
		var knop: Rect2 = Hits.debug()["bak"]["rect"]
		waar(vang.encloses(knop), "het vangvlak dekt de knop")
		waar(vang.encloses(vlak), "het vangvlak dekt het voorwerp")
		gelijk(s.vangvlak.drop, "bak", "het vangvlak draagt dezelfde naam")
	_af()

# -------------------------------------------------- de sleep komt écht aan

## Z1: een drop die op een KNOP landt werd stil geweigerd.  Godot geeft een drop
## aan het Control onder de vinger en loopt dan de OUDERKETEN omhoog; de
## vanglaag is een broer van de knoppenlaag, geen ouder, en hij sterft op de
## knop (MOUSE_FILTER_STOP).  Een hotspot zónder voorwerpvlak (`sl_h*`,
## `bd_rij*`, `mbvak_*`) heeft daardoor geen onbedekt vangvlak: dáár ís de knop
## het vangvlak.  Deze drie proeven lopen de echte invoerlaag af.

var _vp: SubViewport = null
var _vanglaag: Control = null

## Dezelfde twee lagen als de schil: de vanglaag eerst, de knoppenlaag
## erbovenop (`scenes/main.tscn:78` en `:83`).  Als ze één Control zijn bewijst
## de proef niets — dan ligt het vangvlak bóven de knop.
func _op_sleep(kader := Vector2(1000, 648)) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(kader.x), int(kader.y))
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.gui_embed_subwindows = true
	boom.root.add_child(_vp)
	_vanglaag = Control.new()
	_vanglaag.name = "Vanglaag"
	_vanglaag.size = kader
	_vanglaag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp.add_child(_vanglaag)
	_laag = Control.new()
	_laag.name = "Knoplaag"
	_laag.size = kader
	_laag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, null, _laag, _vanglaag)
	World.meet(Rect2(Vector2.ZERO, kader))

func _af_sleep() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	_laag = null
	_vanglaag = null
	if _vp != null:
		_vp.queue_free()
		_vp = null
	await boom.process_frame

## Eén sleep door de echte invoerlaag: indrukken, in stapjes bewegen, loslaten.
## Woordelijk overgenomen uit `games/voerkar/test_voerkar.gd:719` — die bewijst
## al sinds de port dat dit headless werkt; hij mikt alleen op het VOORWERP, en
## dat is precies het geval dat toch al werkte.
func _sleep(vp: SubViewport, van: Vector2, naar: Vector2) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var vorig := van
	_beweeg(vp, van, van, false)
	await boom.process_frame
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = van
	mb.global_position = van
	vp.push_input(mb)
	await boom.process_frame
	for i in range(1, 11):
		var p := van + (naar - van) * (float(i) / 10.0)
		_beweeg(vp, p, vorig, true)
		vorig = p
		await boom.process_frame
	var los := InputEventMouseButton.new()
	los.button_index = MOUSE_BUTTON_LEFT
	los.pressed = false
	los.position = naar
	los.global_position = naar
	vp.push_input(los)
	for _f in 3:
		await boom.process_frame

func _beweeg(vp: SubViewport, p: Vector2, vorig: Vector2, knop: bool) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = p
	mm.global_position = p
	mm.relative = p - vorig
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT if knop else 0
	vp.push_input(mm)

## Een zak om uit te slepen en een bakje zonder voorwerpvlak om in te slepen.
## `tel` telt de afleveringen, `heen` bewaart wat er aankwam.
func _sleepveld(tel: Array, heen: Array, sleep := "koek") -> void:
	Hits.maak({"id": "zak", "kind": "bron", "kamer": World.kamer_nu(),
		"x": 18.0, "z": 18.0, "y": 14.0, "icoon": "🍪", "aantal": 3,
		"sleep": sleep, "prio": 6, "door": "test"})
	Hits.maak({"id": "bak", "kind": "drop", "kamer": World.kamer_nu(),
		"x": 96.0, "z": 96.0, "y": 14.0, "icoon": "🥣", "label": "Bakje",
		"drop": "koek", "data": {"slot": "a"}, "prio": 6, "door": "test",
		"val": func(lading: Dictionary, data: Dictionary) -> void:
			tel[0] += 1
			heen[0] = {"lading": lading, "data": data}})
	Hits.plaats()

func _knop_midden(id: String) -> Vector2:
	var s := Hits.spot(id)
	return (s.knoop as Control).get_global_rect().get_center()

## (a) Loslaten op het MIDDEN VAN DE KNOP van een drop-hotspot zonder
## `obj`/`vlak` levert precies één keer af.  Dit is de bug van Z1.
func test_sleep_op_het_midden_van_de_knop_komt_aan() -> void:
	_op_sleep()
	var tel := [0]
	var heen: Array = [{}]
	_sleepveld(tel, heen)
	gelijk(Hits.debug()["bak"]["vlak"].size, Vector2.ZERO,
		"het bakje heeft geen voorwerpvlak: de knop ÍS het vangvlak")
	var doel := _knop_midden("bak")
	waar(Hits.spot("bak").vangvlak.get_global_rect().has_point(doel),
		"het vangvlak ligt onder het midden van de knop")
	await _sleep(_vp, _knop_midden("zak"), doel)
	gelijk(tel[0], 1, "één sleep op de knop = één aflevering")
	gelijk(str((heen[0] as Dictionary).get("lading", {}).get("sleep", "")), "koek",
		"de lading komt heel aan")
	gelijk(str((heen[0] as Dictionary).get("data", {}).get("slot", "")), "a",
		"en de data van de hotspot ook")
	await _af_sleep()

## (b) Een lading met een andere sleepnaam vuurt niets — de knop geeft door,
## hij neemt niet zomaar alles aan.
func test_sleep_met_een_andere_naam_vuurt_niets() -> void:
	_op_sleep()
	var tel := [0]
	var heen: Array = [{}]
	_sleepveld(tel, heen, "was")
	waar(Hits.vang_onder(_knop_midden("bak"), {"sleep": "was"}) == null,
		"het bakje wil geen was")
	await _sleep(_vp, _knop_midden("zak"), _knop_midden("bak"))
	gelijk(tel[0], 0, "een vuile sok belandt niet in het koekjesbakje")
	waar(not Hits.spot("bak").vangvlak._warm, "en het bakje licht niet op")
	await _af_sleep()

## (c) Een vreemd Control bovenop het vangvlak schakelt óók door: een somkaart
## die over het doel heen ligt is geen muur.
func test_een_kaart_over_het_doel_schakelt_de_sleep_door() -> void:
	_op_sleep()
	var tel := [0]
	var heen: Array = [{}]
	_sleepveld(tel, heen)
	var doel := _knop_midden("bak")
	# De knoppenlaag houdt kaart en knop juist uit elkaar, dus leggen we haar er
	# met de hand bovenop — zo ligt ze gegarandeerd over het doel.
	var kaart := Ui.maak_knop("kaart", {"icoon": "🍪", "regel": "Hoeveel koekjes?",
		"som": "2 + 2 =", "max": 2})
	_laag.add_child(kaart)
	kaart.size = Vector2(180, 96)
	kaart.position = doel - kaart.size * 0.5
	waar(kaart.get_global_rect().has_point(doel), "de kaart ligt over het doel")
	await _sleep(_vp, _knop_midden("zak"), doel)
	gelijk(tel[0], 1, "de sleep gaat dwars door de kaart heen naar het bakje")
	await _af_sleep()

## De gloed van `drop-hot` hoort bij de vinger: aan zolang de sleep boven het
## doel hangt, uit zodra de sleep voorbij is — ook als het kind ergens anders
## loslaat, want dan vraagt niemand het vangvlak nog iets.
func test_de_gloed_gaat_uit_als_de_sleep_voorbij_is() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_op_sleep()
	var tel := [0]
	var heen: Array = [{}]
	_sleepveld(tel, heen)
	var vang := Hits.spot("bak").vangvlak
	var van := _knop_midden("zak")
	var doel := _knop_midden("bak")
	_beweeg(_vp, van, van, false)
	await boom.process_frame
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = van
	mb.global_position = van
	_vp.push_input(mb)
	await boom.process_frame
	_beweeg(_vp, doel, van, true)
	await boom.process_frame
	waar(Hits.sleept(), "er wordt gesleept")
	waar(vang._warm, "het doel licht op onder de vinger")
	Hits.plaats()
	waar(vang._warm, "en blijft oplichten terwijl de knoppenlaag doorloopt")
	# het kind laat in een lege hoek los
	var hoek := Vector2(996, 644)
	_beweeg(_vp, hoek, doel, true)
	await boom.process_frame
	var los := InputEventMouseButton.new()
	los.button_index = MOUSE_BUTTON_LEFT
	los.pressed = false
	los.position = hoek
	los.global_position = hoek
	_vp.push_input(los)
	for _f in 3:
		await boom.process_frame
	gelijk(tel[0], 0, "er is niets afgeleverd")
	waar(not Hits.sleept(), "de sleep is voorbij")
	Hits.plaats()
	waar(not vang._warm, "en de gloed is weg")
	await _af_sleep()

## Het gloeiende haakje: `vang_onder` koelt elk ander vangvlak af, anders blijft
## er een mint randje achter waar de vinger net was (`ui/vangvlak.gd` drop-hot).
func test_alleen_het_doel_onder_de_vinger_gloeit() -> void:
	_op(Vector2(1000, 648))
	for i in 2:
		Hits.maak({"id": "bak%d" % i, "kind": "drop", "kamer": World.kamer_nu(),
			"x": 20.0 + i * 60.0, "z": 20.0 + i * 60.0, "y": 14.0,
			"icoon": "🥣", "label": "Bak", "drop": "koek", "prio": 6, "door": "test"})
	Hits.plaats()
	var a := Hits.spot("bak0")
	var b := Hits.spot("bak1")
	Hits.vang_onder(a.vangvlak.get_global_rect().get_center(), {"sleep": "koek"})
	waar(a.vangvlak._warm and not b.vangvlak._warm, "de eerste bak gloeit")
	Hits.vang_onder(b.vangvlak.get_global_rect().get_center(), {"sleep": "koek"})
	waar(b.vangvlak._warm and not a.vangvlak._warm, "en daarna alleen de tweede")
	Hits.vang_onder(Vector2(-50, -50), {"sleep": "koek"})
	waar(not a.vangvlak._warm and not b.vangvlak._warm, "naast alles gloeit niets")
	_af()

## Het kleinste vangvlak wint: dat is het doel waar het kind op mikt.
func test_het_kleinste_vangvlak_wint() -> void:
	_op(Vector2(1000, 648))
	Hits.maak({"id": "groot", "kind": "drop", "kamer": World.kamer_nu(),
		"x": 40.0, "z": 40.0, "y": 14.0, "icoon": "🛏", "label": "Rij",
		"drop": "koek", "maat": Vector2(300, 120), "prio": 6, "door": "test"})
	Hits.maak({"id": "klein", "kind": "drop", "kamer": World.kamer_nu(),
		"x": 40.0, "z": 40.0, "y": 14.0, "icoon": "🥣", "label": "Bak",
		"drop": "koek", "prio": 6, "door": "test"})
	Hits.plaats()
	# de twee overlappen niet uit zichzelf; leg het kleine doel op het grote
	var g := Hits.spot("groot").vangvlak
	var k := Hits.spot("klein").vangvlak
	k.position = g.position + Vector2(10, 10)
	var punt := k.get_global_rect().get_center()
	waar(g.get_global_rect().has_point(punt), "beide vangvlakken liggen onder het punt")
	gelijk(Hits.vang_onder(punt, {"sleep": "koek"}), k, "het kleinste doel wint")
	_af()

## `Hits.zet_drop` — Spot, vangvlak en knop in één keer.  De voerkar zette
## `s.val` en `s.vangvlak.val` los van elkaar en vergat `data` elke keer.
func test_zet_drop_houdt_spot_en_vangvlak_gelijk() -> void:
	_op(Vector2(1000, 648))
	var tel := [0, 0]
	Hits.maak({"id": "bak", "kind": "drop", "kamer": World.kamer_nu(),
		"x": 40.0, "z": 40.0, "y": 14.0, "icoon": "🥣", "label": "Bak",
		"drop": "koek", "data": {"slot": "a"}, "door": "test",
		"val": func(_l, _d) -> void: tel[0] += 1})
	Hits.maak({"id": "deur", "kamer": World.kamer_nu(),
		"x": 100.0, "z": 100.0, "y": 14.0, "icoon": "🚪", "label": "Gang", "door": "test"})
	Hits.plaats()
	waar(not Hits.zet_drop("bestaat_niet", "koek", Callable()), "een onbekend id geeft false")
	var nieuw := func(_l: Dictionary, d: Dictionary) -> void: tel[1] += int(d.get("n", 0))
	waar(Hits.zet_drop("bak", "kar", nieuw), "het bakje gaat over op de kar")
	var s := Hits.spot("bak")
	gelijk(s.drop, "kar", "de Spot draagt de nieuwe naam")
	gelijk(s.vangvlak.drop, "kar", "het vangvlak ook")
	gelijk(str(s.vangvlak.data.get("slot", "")), "a", "een lege data laat de oude staan")
	s.vangvlak._drop_data(Vector2.ZERO, {"sleep": "kar"})
	gelijk(tel[0], 0, "de oude afhandelaar hoort niets meer")
	# een hotspot die nog geen drop had krijgt er een, op zijn eigen knoprechthoek
	waar(Hits.zet_drop("deur", "kar", nieuw, {"n": 7}), "de deur wordt een sleepdoel")
	var d := Hits.spot("deur")
	waar(d.vangvlak != null, "de deur heeft nu een vangvlak")
	gelijk(Rect2(d.vangvlak.position, d.vangvlak.size), Hits.debug()["deur"]["rect"],
		"en het ligt op de knop")
	d.vangvlak._drop_data(Vector2.ZERO, {"sleep": "kar"})
	gelijk(tel[1], 7, "de nieuwe data komt mee")
	# en weer weg
	waar(Hits.zet_drop("deur", "", Callable()), "een lege naam haalt het doel weg")
	waar(Hits.spot("deur").vangvlak == null, "het vangvlak is opgeruimd")
	_af()

# ------------------------------------------------------------- blijven staan

## Owner, 2026-09-14: opening the notice board reshuffled half the buttons.  An
## element that still fits where it was keeps that place when something new
## arrives elsewhere; only when its own place is taken does it move.
func test_knoppen_blijven_staan_als_er_iets_bijkomt() -> void:
	_op(Vector2(990, 637))
	Hits.maak({"id": "st_a", "door": "test", "kamer": World.kamer_nu(),
		"x": 30.0, "z": 30.0, "y": 10.0, "icoon": "🔔", "label": "Bel", "prio": 10})
	Hits.maak({"id": "st_b", "door": "test", "kamer": World.kamer_nu(),
		"x": 90.0, "z": 90.0, "y": 10.0, "icoon": "🚪", "label": "Gang", "prio": 5})
	Hits.plaats()
	var a1: Rect2 = Hits.debug()["st_a"]["rect"]
	var b1: Rect2 = Hits.debug()["st_b"]["rect"]
	Hits.plaats()
	gelijk(Hits.debug()["st_a"]["rect"], a1, "een tweede pas verandert niets")
	# something new, far away and with a higher priority
	Hits.maak({"id": "st_c", "door": "test", "kamer": World.kamer_nu(),
		"x": 100.0, "z": 20.0, "y": 10.0, "icoon": "📋", "label": "Prikbord", "prio": 12})
	Hits.plaats()
	gelijk(Hits.debug()["st_a"]["rect"], a1, "de bel blijft waar hij was")
	gelijk(Hits.debug()["st_b"]["rect"], b1, "de deurknop ook")
	_keur(Vector2(990, 637), "blijven staan")
	# something new exactly on the bell's place: now the bell may move, and moves
	Hits.maak({"id": "st_d", "door": "test", "kamer": World.kamer_nu(),
		"x": 30.0, "z": 30.0, "y": 10.0, "icoon": "⭐", "label": "Ster", "prio": 20})
	Hits.plaats()
	var d: Rect2 = Hits.debug()["st_d"]["rect"]
	var a2: Rect2 = Hits.debug()["st_a"]["rect"]
	var snij := a2.intersection(d)
	gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0, "de bel en de ster overlappen niet")
	_keur(Vector2(990, 637), "verdrongen")
	_af()

# ------------------------------------------------------------- de sleepbron

## Elke zichtbare pil ligt in zijn eigen knop, op geen enkele andere knop, en de
## strook waarin hij staat is bijgekocht — hij snoept niets van het tikvierkant
## van het pictogram af.
func _keur_bron(id: String, kader: Vector2, wat: String) -> void:
	var b := Hits.spot(id).knoop as UiBron
	var knop := b.get_global_rect()
	var rij := b.get_node("Tellers") as Control
	var gezien := 0
	for kind in rij.get_children():
		var pil := kind as Label
		if pil == null or not pil.visible:
			continue
		gezien += 1
		var r := pil.get_global_rect()
		waar(r.size.x > 0.0 and r.size.y > 0.0,
			"%s %s: de pil is echt getekend bij %s" % [wat, pil.name, str(kader)])
		waar(knop.encloses(r), "%s %s (%s) ligt in de knop %s bij kader %s"
			% [wat, pil.name, str(r), str(knop), str(kader)])
		for ander_id in Hits.debug().keys():
			if str(ander_id) == id:
				continue
			var ander := (Hits.spot(ander_id).knoop as Control).get_global_rect()
			var snee := r.intersection(ander)
			gelijk(maxf(0.0, snee.size.x) * maxf(0.0, snee.size.y), 0.0,
				"%s %s ligt op %s bij kader %s" % [wat, pil.name, ander_id, str(kader)])
	gelijk(gezien, 2, "%s: teller en handbadge staan er allebei bij %s" % [wat, str(kader)])
	# de strook is er bíj gekocht, in de richting waarin de knop ruimte over had
	var eigen := b.get_minimum_size()
	var strook := rij.get_combined_minimum_size()
	var tik := float(Ui.tap_maat())
	if eigen.x > eigen.y:
		waar(knop.size.x >= maxf(tik, eigen.x) + strook.x - 0.01,
			"%s: de pillen staan naast de zin bij %s (knop %s, zin %d, pil %d)"
				% [wat, str(kader), str(knop.size), int(eigen.x), int(strook.x)])
	else:
		waar(knop.size.y >= maxf(tik, eigen.y) + strook.y - 0.01,
			"%s: de pillen staan onder het pictogram bij %s (knop %s, teken %d, pil %d)"
				% [wat, str(kader), str(knop.size), int(eigen.y), int(strook.y)])

## `V6` — de teller van een sleepbron hoort IN zijn eigen knop.
##
## De pillenrij hing met `PRESET_BOTTOM_WIDE` aan de ONDERRAND van de knop, en
## een Control die kleiner is dan haar minimum groeit naar `grow_vertical` —
## standaard END, naar beneden.  De pillen stonden daardoor buiten de knop, in
## de band eronder: het getal van de voerkar landde op het bakje dat `Hits` daar
## had neergezet.  Nu groeien ze naar binnen en koopt `UiBron.inhoud_maat()` de
## strook waarin ze staan — onder een kaal pictogram (daar is de band toch al
## twee hoog), naast een hele zin (daar is de band vol en de kolom niet).
func test_de_teller_van_een_bron_blijft_in_zijn_knop() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	for kader in MATEN:
		_op(kader)
		Hits.maak({"id": "zak", "kind": "bron", "kamer": World.kamer_nu(),
			"x": 24.0, "z": 20.0, "y": 14.0, "icoon": "🍪", "aantal": 40,
			"hand": 2, "sleep": "vak", "prio": 10, "door": "test"})
		Hits.maak({"id": "bak", "kind": "drop", "kamer": World.kamer_nu(),
			"x": 96.0, "z": 96.0, "y": 14.0, "icoon": "🥣", "label": "Bakje",
			"drop": "vak", "prio": 6, "door": "test"})
		Hits.plaats()
		# een Container zet zijn kinderen pas neer in de layoutstap van het frame
		# ná de plaatsing; `World._process` draait `Hits.plaats()` er zelf bij
		await boom.process_frame
		_keur_bron("zak", kader, "pictogram")
		# en dezelfde bron met een hele zin op de knop, zoals de voerkar en de
		# was hem aankleden: dan verhuizen de pillen naar het eind van de regel
		var b := Hits.spot("zak").knoop as UiBron
		b.text = "🍪 pak 2"
		b.add_theme_font_size_override("font_size", int(Ui.maten["klein"]))
		Hits.plaats()
		await boom.process_frame
		_keur_bron("zak", kader, "zin")
		_af()

## De knop zelf blijft een tikdoel van minstens `tap`: de pillenrij komt eronder
## bij, ze snoept er niets van af.
func test_een_bron_blijft_een_vol_tikdoel() -> void:
	for kader in MATEN:
		_op(kader)
		Hits.maak({"id": "zak", "kind": "bron", "kamer": World.kamer_nu(),
			"x": 24.0, "z": 20.0, "y": 14.0, "icoon": "🍪", "aantal": 0,
			"sleep": "vak", "prio": 10, "door": "test"})
		Hits.plaats()
		var b := Hits.spot("zak").knoop as UiBron
		var r := b.get_global_rect()
		waar(r.size.x >= float(Ui.tap_maat()) and r.size.y >= float(Ui.tap_maat()),
			"een lege bron is nog een tikdoel bij %s (%s)" % [str(kader), str(r)])
		# leeg is leeg: bij 0 staat er geen pil, dus er wordt ook geen band gekocht
		var rij := b.get_node("Tellers") as Control
		for kind in rij.get_children():
			waar(not (kind as Control).visible, "bij 0 staat er geen pil")
		_keur(kader, "lege bron %s" % str(kader))
		_af()

## While a game has priority, every button of the HOTEL leaves the frame (doors,
## bell, board, the other games' entries): they are not part of the sum and they
## took half the screen (owner, 2026-09-18).  What the game borrowed stays, and
## so does the fixed layer — a name plate and a number tag are information.
func test_hotelknoppen_wijken_voor_een_spel() -> void:
	_op(Vector2(1000, 648))
	var nu := World.kamer_nu()
	Hits.maak({"id": "h_deur", "kamer": nu, "x": 10.0, "z": 10.0, "y": 9.0,
		"label": "Gang", "door": "hotel", "klas": "hotdeur"})
	Hits.maak({"id": "h_bel", "kamer": nu, "x": 30.0, "z": 10.0, "y": 9.0,
		"label": "Bel", "door": "hotel", "klas": "hotbel vrij"})
	Hits.maak({"id": "h_wens", "kind": "wolk", "kamer": nu, "x": 20.0, "z": 30.0, "y": 20.0,
		"label": "🍪 eten", "door": "hotel", "klas": "hotwolk hotwens"})
	Hits.maak({"id": "h_tag", "kind": "tag", "kamer": nu, "x": 12.0, "z": 30.0, "y": 8.0,
		"getal": 3, "op": "rand", "door": "hotel"})
	Hits.maak({"id": "spel_ander", "kamer": nu, "x": 40.0, "z": 30.0, "y": 12.0,
		"label": "Zwembad", "door": "registry", "klas": "hotgame"})
	Hits.maak({"id": "s_knop", "kamer": nu, "x": 24.0, "z": 20.0, "y": 12.0,
		"label": "Klaar", "door": "spel"})
	Hits.plaats()
	for id in ["h_deur", "h_bel", "h_wens", "h_tag", "spel_ander", "s_knop"]:
		waar(Hits.spot(id).knoop.visible, "zonder spel staat %s er gewoon" % id)
	# the game takes over and borrows the door
	Hits.voorrang("spel")
	waar(Hits.leen("h_deur", "spel", func(_s) -> void: pass), "de deur is te lenen")
	Hits.plaats()
	for id in ["h_bel", "h_wens", "spel_ander"]:
		waar(not Hits.spot(id).knoop.visible, "tijdens het spel is %s weg" % id)
		waar(not Hits.debug().has(id), "en %s telt niet mee in de plaatsing" % id)
	for id in ["h_deur", "h_tag", "s_knop"]:
		waar(Hits.spot(id).knoop.visible, "tijdens het spel blijft %s staan" % id)
	# the game ends: everything comes back
	Hits.geef_terug("spel")
	Hits.voorrang("")
	Hits.plaats()
	for id in ["h_deur", "h_bel", "h_wens", "h_tag", "spel_ander", "s_knop"]:
		waar(Hits.spot(id).knoop.visible, "na het spel staat %s er weer" % id)
	_af()

## Owner, 2026-09-23: "wekker zetten is bijvoorbeeld helemaal niet relevant aan
## waar de tekst geplaatst is. Dit gebeurt vaak over het hele spel".  In every
## room, on every screen: a door's sign hangs ON that door, and every other
## button that belongs to a thing (`op: aan`) touches that thing — none drifts
## off onto the furniture next to it.  Before, "Keuken" stood on the chest in
## the corridor, "Receptie" on the ball pit, "Sleutels" on the plant.
func test_elk_bordje_op_zijn_deur_en_elke_knop_aan_zijn_ding() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var boom := Engine.get_main_loop() as SceneTree
	for maat in SCHERMEN:
		var h: Dictionary = await _hotel_op(maat)
		var deuren := 0
		var op_deur := 0
		var geschoven := 0
		var telefoon: bool = mini(maat.x, maat.y) < 400
		for kamer in Rooms.lijst():
			Hotel.naar_kamer(kamer)
			for _f in 3:
				await boom.process_frame
			var dbg := Hits.debug()
			for id in dbg.keys():
				var s = Hits.spot(id)
				var d: Dictionary = dbg[id]
				var r: Rect2 = d["rect"]
				var vlak: Rect2 = d["vlak"]
				if s == null or vlak.size.x <= 0.0 or str(s.op) != "aan":
					continue
				var gat_x := maxf(0.0, maxf(vlak.position.x - r.end.x, r.position.x - vlak.end.x))
				var gat_y := maxf(0.0, maxf(vlak.position.y - r.end.y, r.position.y - vlak.end.y))
				if s.klas.contains("hotdeur"):
					continue          # the door signs: `_keur_deurbordjes` below
				# touching its thing; on a phone, where the bands fill up, at
				# most one band away from it
				var mag := Hits.GAT + 1.0 if not telefoon else float(Hits.RIJ) + Hits.GAT
				waar(gat_x <= mag and gat_y <= mag,
					"%s %s: %s staat bij zijn ding (gat %.0f, %.0f; knop %s, ding %s)"
						% [str(maat), kamer, id, gat_x, gat_y, str(r), str(vlak)])
			var tel := _keur_deurbordjes("%s %s" % [str(maat), kamer], h["kader"])
			deuren += int(tel["deur"]) + int(tel["latei"])
			op_deur += int(tel["deur"])
			geschoven += int(tel["geschoven"])
		print("  deurbordjes %s: %d deuren, %d midden op de deur, %d boven de latei, %d opzij geschoven"
			% [str(maat), deuren, op_deur, deuren - op_deur, geschoven])
		waar(deuren >= 15, "%s: alle deuren gemeten (%d)" % [str(maat), deuren])
		if not telefoon:
			gelijk(op_deur, deuren, "%s: elk bordje hangt midden op zijn deur" % str(maat))
		await _hotel_af(h)
	State.s = bewaard

## Owner, 2026-09-24, with a picture of the corridor during the voerkar: "Kamer 2
## staat onder de deur maar kamer 1 boven de deur. Dit is geen consistente
## plaats om de iconen te zetten."  Every door sign stands at ONE of two places,
## the same for every door in every room: centred on its door opening at the
## opening's half height, or — only when a thing with a button of its own stands
## in that opening, or a neighbouring door's sign already hangs there — centred
## just over its lintel.  Never on the foot of the door, never under it, never
## wherever the bands had room.  Returns how many stood where.
func _keur_deurbordjes(wat: String, kader: Vector2) -> Dictionary:
	var tel := {"deur": 0, "latei": 0, "geschoven": 0}
	var dbg := Hits.debug()
	for id in dbg.keys():
		var s = Hits.spot(id)
		if s == null or not str(s.klas).contains("hotdeur"):
			continue
		var d: Dictionary = dbg[id]
		var r: Rect2 = d["rect"]
		var deur: Rect2 = d["vlak"]
		var plek := str(d.get("deurplek", ""))
		waar(Hits.DEURPLEK.has(plek),
			"%s: het bordje %s staat op zijn deur of erboven, niet ergens (%s, deur %s)"
				% [wat, id, str(r), str(deur)])
		if not Hits.DEURPLEK.has(plek):
			continue
		tel[plek] = int(tel[plek]) + 1
		var hart := r.get_center()
		var cx := deur.get_center().x
		# exactly at one of the heights of the rule
		var plekken := Hits.deurbord_plekken(deur, r.size)
		var hoogte := false
		for i in plekken.size():
			if Hits.DEURPLEK[i] == plek and absf(plekken[i].position.y - r.position.y) <= 0.5:
				hoogte = true
		# over the lintel of a door that reaches the top of the frame: pushed
		# down to the frame's edge, on the upper half of its own door
		if plek == "latei" and r.position.y <= float(Hits.KRAP) + 0.5 \
				and r.position.y > plekken[1].position.y and r.end.y <= deur.get_center().y + 0.5:
			hoogte = true
		waar(hoogte, "%s: %s hangt op een hoogte van de regel (%s: %s, deur %s)"
			% [wat, id, plek, str(r), str(deur)])
		waar(r.position.y < deur.end.y,
			"%s: %s staat nooit onder zijn deur (%s, deur %s)" % [wat, id, str(r), str(deur)])
		# centred on the door; only the frame edge or a neighbouring sign may
		# have pushed it sideways, and never off the middle of its door
		var midden := absf(hart.x - cx) <= 0.5
		if not midden:
			tel["geschoven"] = int(tel["geschoven"]) + 1
		waar(midden or (r.position.x <= cx - Hits.DEUR_RAND + 0.5
				and r.end.x >= cx + Hits.DEUR_RAND - 0.5),
			"%s: %s staat recht op of boven het midden van zijn deur (%s, deur %s)"
				% [wat, id, str(r), str(deur)])
		waar(r.position.x >= 0.0 and r.end.x <= kader.x + 0.01,
			"%s: %s staat binnen het kader" % [wat, id])
		if plek == "deur" and midden:
			waar(deur.has_point(hart),
				"%s: het midden van %s ligt in de deuropening (%s, deur %s)"
					% [wat, id, str(hart), str(deur)])
	return tel

## The corridor during the voerkar, the trolley held: pushed through the
## kitchen door it stands in the middle of the corridor, right in front of the
## Kamer 1 door on a tablet — the owner's picture.  The door signs keep their
## places (on the door, or over the lintel where the trolley stands in the
## opening), and the trolley's button and its bubble give way to them: every
## invariant of `_keur` holds with all of them on screen.
func test_deurbordjes_in_de_gang_met_de_voerkar() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var kar_voor: Dictionary = World.ding("kar")
	var boom := Engine.get_main_loop() as SceneTree
	var ui_rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	for maat in SCHERMEN:
		var h: Dictionary = await _hotel_op(maat)
		# four guests in the beds of kamer1 and kamer2: two rooms to feed
		var pool := State.gasten_pool()
		var gasten: Array = []
		var bedden := State.alle_bedden()
		for i in mini(4, bedden.size()):
			var g: Dictionary = pool[i]
			g["kamer"] = str(bedden[i]["kamer"])
			g["bed"] = str(bedden[i]["slot"])
			g["waar"] = g["kamer"]
			g["nachten"] = 100
			gasten.append(g)
		State.s["gasten"] = gasten
		World.sync(Hotel.alle_dieren())
		Hotel.naar_kamer("keuken")
		for _f in 3:
			await boom.process_frame
		Games.start("voerkar")
		for _f in 3:
			await boom.process_frame
		gelijk(Games.actief(), "voerkar", "%s: de voerkar draait" % str(maat))
		# a tap on the corridor door takes the trolley along, held
		var deur := Hits.spot("deur_keuken_gang")
		waar(deur != null, "%s: de gangdeur staat er" % str(maat))
		if deur != null:
			(deur.knoop as BaseButton).emit_signal("pressed")
		for _f in 3:
			await boom.process_frame
		gelijk(World.kamer_nu(), "gang", "%s: de camera staat in de gang" % str(maat))
		gelijk(str(World.ding("kar").get("kamer", "")), "gang", "%s: de kar ook" % str(maat))
		var kar := Hits.spot("karhot")
		waar(kar != null and kar.knoop.visible, "%s: de kar is een knop" % str(maat))
		if kar != null:
			# held, the cart says the next step itself: one bubble (owner,
			# 2026-09-24: "Verwerk deze twee teksten in een bubbeltje")
			gelijk(str((kar.knoop as Button).text), "🛒 Je duwt de kar\n👉 Tik op een deur",
				"%s: en je hebt hem vast" % str(maat))
		var dbg := Hits.debug()
		waar(not dbg.has("vk_zeg"), "%s: geen los wolkje naast de kar" % str(maat))
		var tel := _keur_deurbordjes("%s gang, kar vast" % str(maat), h["kader"])
		# three: kamer 1, kamer 2 and the kitchen — the lift's sign steps aside
		# while the game runs, the trolley does not ride the lift (2026-09-24)
		gelijk(int(tel["deur"]) + int(tel["latei"]), 3, "%s: drie deurbordjes in de gang" % str(maat))
		if maat == Vector2i(1024, 768) and dbg.has("karhot") and dbg.has("deur_gang_kamer1"):
			# the owner's picture: the trolley stands in the Kamer 1 opening, so
			# that sign goes over the lintel — and so do ALL signs of the room,
			# at the same height ("geen consistente plaats", 2026-09-24)
			var kar_vlak: Rect2 = dbg["karhot"]["vlak"]
			var k1: Rect2 = dbg["deur_gang_kamer1"]["vlak"]
			waar(kar_vlak.intersects(k1), "de kar staat voor de deur van kamer 1")
			for id in ["deur_gang_kamer1", "deur_gang_kamer2", "deur_gang_keuken"]:
				if dbg.has(id):
					gelijk(str(dbg[id]["deurplek"]), "latei", "%s hangt boven de latei" % id)
		# one height per room: never on the door here and over the lintel there.
		# Not on the phone: its corridor's four doors are closer together than
		# two signs over their lintels are wide, so only a mix fits there.
		var hoogtes := {}
		for id in dbg.keys():
			if str(id).begins_with("deur_gang_") and dbg[id].has("deurplek"):
				var r: Rect2 = dbg[id]["rect"]
				var v: Rect2 = dbg[id]["vlak"]
				hoogtes["%s|%d" % [str(dbg[id]["deurplek"]), roundi((r.position.y - v.position.y) / 52.0)]] = true
		waar(maat.x < 600 or hoogtes.size() <= 1 or not hoogtes.keys().any(func(k): return str(k).begins_with("deur|")),
			"%s: de bordjes van de gang hangen niet deels op en deels boven hun deur (%s)"
				% [str(maat), str(hoogtes.keys())])
		_keur(Vector2(h["kader"]), "%s gang, kar vast" % str(maat))
		Games.stop()
		for _f in 2:
			await boom.process_frame
		await _hotel_af(h)
	Ui.zet_rust_modus(ui_rust)
	if not kar_voor.is_empty():
		World.zet_ding("kar", kar_voor)
	State.s = bewaard

## The other side of the same rule: whatever else wants the very place of a
## door sign gives way to it.  Before, a fixed card (the first layer) and the
## game's own buttons and bubbles (the second) chose first, and the sign dodged
## to the foot of its door, under it or over it — whatever was left.
func test_alles_wijkt_voor_het_deurbordje() -> void:
	var kader := Vector2(1000, 648)
	_op(kader)
	var nu := World.kamer_nu()
	var mik := World.mik_punt(80.0, 20.0, 9.0)
	var deur := Rect2(mik - Vector2(24, 64), Vector2(48, 128))
	Hits.maak({"id": "d_gang", "kamer": nu, "x": 80.0, "z": 20.0, "y": 9.0,
		"icoon": "🚪", "label": "Gang", "door": "hotel", "klas": "hotdeur", "op": "aan",
		"prio": 11, "vlak": deur})
	# a fixed card aimed at the middle of that same opening: a card may stand
	# over the world, so it used to take the door's place
	Hits.maak({"id": "s_kaart", "kamer": nu, "x": 80.0, "z": 20.0, "y": 9.0,
		"op": "midden", "vast": true, "prio": 14, "label": "Hoeveel koekjes?",
		"maat": Vector2(200, 78), "door": "spel", "geen_vlak": true})
	Hits.voorrang("spel")
	waar(Hits.leen("d_gang", "spel", func(_s) -> void: pass), "de deur is te lenen")
	Hits.plaats()
	var dbg := Hits.debug()
	gelijk(str(dbg["d_gang"]["deurplek"]), "deur", "het bordje blijft midden op zijn deur")
	var r: Rect2 = dbg["d_gang"]["rect"]
	waar(r.get_center().is_equal_approx(deur.get_center()),
		"precies op het midden van de opening (%s, deur %s)" % [str(r), str(deur)])
	var kaart: Rect2 = dbg["s_kaart"]["rect"]
	waar(not kaart.intersects(r), "de kaart wijkt (%s, bordje %s)" % [str(kaart), str(r)])
	_keur(kader, "kaart wijkt voor deur")
	Hits.weg("s_kaart")
	# The trolley pushed into the opening, with its own button and the game's
	# one bubble: the sign cannot stand on the door without hiding the trolley,
	# so it goes to its one fallback, straight over the lintel — and the
	# trolley's bubble, which wanted that band, gives way.
	var kar := Rect2(mik + Vector2(-60, -10), Vector2(120, 90))
	Hits.maak({"id": "s_kar", "kamer": nu, "x": 80.0, "z": 20.0, "y": 16.0,
		"icoon": "🛒", "label": "Je duwt de kar", "op": "aan", "prio": 11, "door": "spel",
		"vlak": kar})
	Hits.maak({"id": "s_zeg", "kind": "wolk", "kamer": nu, "x": 80.0, "z": 20.0, "y": 30.0,
		"icoon": "👉", "tekst": "Tik op een deur", "prio": 10, "door": "spel", "vlak": kar})
	Hits.plaats()
	dbg = Hits.debug()
	gelijk(str(dbg["d_gang"]["deurplek"]), "latei", "met de kar in de deur: boven de latei")
	r = dbg["d_gang"]["rect"]
	gelijk(r.end.y, deur.position.y - Hits.GAT, "vlak boven de latei")
	gelijk(r.get_center().x, deur.get_center().x, "recht boven de deur")
	_keur(kader, "kar in de deur")
	Hits.geef_terug("spel")
	Hits.voorrang("")
	_af()

## Owner, 2026-09-23: "Plaatjes als [de receptie met het open bord] zijn veel te
## druk in iconen. en wekker zetten is bijvoorbeeld helemaal niet relevant aan
## waar de tekst geplaatst is".  The board is a sheet now: its cards stand on
## the cork, each with its room under it, and NOTHING of the board hangs in the
## receptie.  A tap on a card closes the sheet and goes to that card's room.
func test_het_prikbord_is_een_blad() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var boom := Engine.get_main_loop() as SceneTree
	var h: Dictionary = await _hotel_op(Vector2i(1024, 768))
	State.s["taken"] = []
	Hotel.bord_dicht()
	for i in 2:
		(State.s["gasten"] as Array).append({"id": "pb%d" % i, "naam": "Pb%d" % i,
			"kind": "hond", "soort": "puppy", "scoops": 1, "kamer": "kamer1",
			"bed": "bed%d" % (i + 1), "behoefte": "spelen", "blij": false})
	Hotel.prikbord()
	for _f in 3:
		await boom.process_frame
	waar(Hotel.bord_is_open(), "het bord staat open")
	waar(Ui.blad_open_nu(), "als blad")
	var bord := Ui.huidig_blad().find_child("Prikbord", true, false)
	waar(bord is UiPrikbordBlad, "met het prikbord erop")
	var taken: Array = State.s["taken"]
	waar(not taken.is_empty(), "er staan taakjes klaar (%d)" % taken.size())
	var notes := 0
	var met_kamer := 0
	if bord != null:
		for k in bord.get_children():
			if k is Button:
				notes += 1
				var waar_l := k.get_node_or_null("Waar") as Label
				if waar_l != null and waar_l.text.begins_with("in ") or \
						(waar_l != null and waar_l.text.begins_with("bij ")):
					met_kamer += 1
	gelijk(notes, taken.size(), "elk taakje is een briefje op het bord")
	gelijk(met_kamer, taken.size(), "en elk briefje zegt in welke kamer het is")
	for id in Hits.lijst():
		var s = Hits.spot(id)
		waar(s == null or s.door != Hotel.BORD,
			"niets van het bord hangt in de kamer (%s)" % id)
	# a tap on a card: the sheet closes and we go to its room
	var eerste: Dictionary = taken[0]
	if bord != null:
		for k in bord.get_children():
			if k is Button:
				(k as Button).pressed.emit()
				break
	for _f in 3:
		await boom.process_frame
	waar(not Hotel.bord_is_open(), "het bord gaat dicht na een tik")
	waar(not Ui.blad_open_nu(), "en het blad ook")
	if not str(eerste.get("kamer", "")).is_empty() and not str(eerste.get("actie", "")).begins_with("game:"):
		gelijk(World.kamer_nu(), str(eerste["kamer"]), "en we staan in de kamer van het taakje")
	Games.stop()
	await _hotel_af(h)
	State.s = bewaard

## The guest who checks in stands AT the desk, and the question hangs by it:
## it used to wait by the bench in the far corner while its card hung at the
## other end of the desk (owner, 2026-09-23).
func test_de_gast_checkt_in_aan_de_balie() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var boom := Engine.get_main_loop() as SceneTree
	var h: Dictionary = await _hotel_op(Vector2i(1024, 768))
	var ui_rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)                 # a walk is a teleport: no waiting
	Hotel.bel()
	for _f in 4:
		await boom.process_frame
	var g = State.s["nieuweGast"]
	waar(g != null, "er staat een gast aan de balie")
	if g != null:
		var d = World.dier(str(g["id"]))
		var r = Rooms.get_kamer("receptie")
		waar(d != null, "de gast is er")
		if d != null:
			waar(d.x >= float(r.balie["x0"]) and d.x <= float(r.balie["x1"]),
				"hij staat vóór de balie, niet ernaast (x %.0f)" % d.x)
			waar(d.z > float(r.balie["z1"]) and d.z <= float(r.balie["z1"]) + 25.0,
				"vlak voor de balie (z %.0f)" % d.z)
			var dbg := Hits.debug()
			waar(dbg.has("ci_som"), "de vraag hangt er")
			if dbg.has("ci_som"):
				var kaart: Rect2 = dbg["ci_som"]["rect"]
				var dier := World.vlak_van_dier(str(g["id"]))
				var af := maxf(0.0, maxf(dier.position.y - kaart.end.y, kaart.position.y - dier.end.y))
				waar(af <= float(Hits.RIJ),
					"de vraag hangt bij de gast (%.0f eenheden, kaart %s, gast %s)"
						% [af, str(kaart), str(dier)])
	Ui.zet_rust_modus(ui_rust)
	await _hotel_af(h)
	State.s = bewaard

## Owner, 2026-09-23: "actions such as a blank bed are available after entering
## a guest but when you click on them you can't execute them ... this provides
## visual clutter".  Outside a game a hotel button stands only where a tap does
## something: the play basket while somebody here wants to play, a bowl with
## food while somebody here still has to eat, the bell while a bedroom can take
## one more guest and nobody stands at the desk.  A bed never has one: since
## 2026-09-24 the check-in chooses a ROOM at the desk (owner: "Je moet bij
## bellen van het dier een kamer voor het dier kiezen").
func test_een_knop_staat_er_alleen_als_hij_iets_doet() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var boom := Engine.get_main_loop() as SceneTree
	var h: Dictionary = await _hotel_op(Vector2i(1024, 768))
	# one guest in kamer 1, bed 1: it has eaten, it does not want to play
	State.s["gasten"] = [{"id": "kv0", "naam": "Kv", "kind": "hond", "soort": "puppy",
		"scoops": 1, "kamer": "kamer1", "bed": "bed1", "waar": "kamer1",
		"behoefte": "eten", "gegeten": true, "blij": false}]
	World.sync(Hotel.alle_dieren())
	Hotel.naar_kamer("kamer1")
	for _f in 3:
		await boom.process_frame
	waar(Hits.spot("bed_kamer1_bed2") == null, "een vrij bed zonder wachtende gast heeft geen knop")
	waar(Hits.spot("mand_kamer1") == null, "de speelmand zonder speler heeft geen knop")
	waar(Hits.spot("bak_kamer1_bak") == null, "een leeg bakje heeft geen knop")
	waar(Hits.spot("deur_kamer1_gang") != null, "de deur staat er wel")
	# somebody wants to play: the basket is something to tap
	(State.s["gasten"][0] as Dictionary)["behoefte"] = "spelen"
	Hotel.render()
	waar(Hits.spot("mand_kamer1") != null, "met een speler heeft de speelmand een knop")
	# food in the bowl and a guest that still has to eat: the bowl feeds
	(State.s["gasten"][0] as Dictionary)["gegeten"] = false
	World.zet_bak("kamer1", "bak", 2)
	Hotel.render()
	waar(Hits.spot("bak_kamer1_bak") != null, "een vol bakje met een hongerige gast heeft een knop")
	# the bell: a free bed and nobody at the desk
	Hotel.naar_kamer("receptie")
	for _f in 2:
		await boom.process_frame
	waar(Hits.spot("bel") != null, "met plek in een kamer staat de bel er")
	Hotel.bel()
	for _f in 2:
		await boom.process_frame
	waar(Hits.spot("bel") == null, "met een gast aan de balie niet meer")
	# the check-in reaches its room: the question hangs at the desk, and a free
	# bed is still nothing to tap
	var v = State.s["checkin"]
	waar(v != null, "de gast checkt in")
	if v != null:
		v["stap"] = 3
		Hotel.paint_checkin()
		for _f in 2:
			await boom.process_frame
		waar(Hits.spot("ci_som_keuzes") != null, "de kamervraag hangt aan de balie")
		Hotel.naar_kamer("kamer1")
		for _f in 2:
			await boom.process_frame
		waar(Hits.spot("bed_kamer1_bed2") == null, "ook bij de kamerkeuze heeft een vrij bed geen knop")
		waar(Hits.spot("bed_kamer1_bed1") == null, "een bezet bed nooit")
	await _hotel_af(h)
	State.s = bewaard
