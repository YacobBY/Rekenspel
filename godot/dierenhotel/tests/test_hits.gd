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

## The strip of four numbers glues under its card (or above it when there is no
## room below), stays inside the frame and every button is a real tap target —
## on every frame size, the low landscape phone included.
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
			var kr: Rect2 = dbg["pk"]["rect"]
			print("[maat] strook bij %s staat %s" % [str(kader), dbg["pk_keuzes"]["op"]])
			waar(st.position.x >= 0.0 and st.end.x <= kader.x + 0.01
				and st.position.y >= 0.0 and st.end.y <= kader.y + 0.01,
				"de strook past in het kader %s (%s)" % [str(kader), str(st)])
			var afstand := minf(absf(st.position.y - kr.end.y), absf(kr.position.y - st.end.y))
			waar(afstand <= Hits.KLEEF + 0.01 or dbg["pk_keuzes"]["op"] != "kleef",
				"een gekleefde strook zit tegen de kaart aan, kader %s (%.1f)" % [str(kader), afstand])
			var knoop := Hits.spot("pk_keuzes").knoop
			gelijk(knoop.get_node("Rij").get_child_count(), 4, "vier knoppen, %s" % str(kader))
			for k in knoop.get_node("Rij").get_children():
				var m: Vector2 = (k as Control).custom_minimum_size
				waar(m.x >= 44.0 and m.y >= 44.0, "knop %s is een tikdoel bij %s" % [k.name, str(kader)])
		_keur(kader, "strook %s" % str(kader))
		kaart.weg()
		_af()

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

## The choice strip is glued under its card, never on it, at every frame size.
func test_keuzestrook_kleeft_onder_de_kaart() -> void:
	for kader in MATEN:
		_op(kader)
		var niets := func(_k) -> void: pass
		var kaart := Ui.somkaart({"x": 24.0, "z": 20.0}, "", {
			"id": "kk", "door": "test", "kamer": World.kamer_nu(),
			"icoon": "📦", "regel": "Is er genoeg eten?", "keuze_titel": "kies er een",
			"keuzes": [
				{"id": "min", "icoon": "⬇", "tekst": "te weinig", "kort": "weinig", "kies": niets},
				{"id": "gelijk", "icoon": "⚖", "tekst": "precies", "kies": niets},
				{"id": "meer", "icoon": "⬆", "tekst": "blijft over", "kort": "over", "kies": niets},
			]})
		Hits.plaats()
		var dbg := Hits.debug()
		waar(dbg.has("kk_keuzes"), "de strook staat er bij %s" % str(kader))
		if dbg.has("kk_keuzes"):
			gelijk(dbg["kk_keuzes"]["op"], "kleef", "de strook kleeft, %s" % str(kader))
		_keur(kader, "strook %s" % str(kader))
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
		var kaarten := 0
		for id in dbg.keys():
			var d: Dictionary = dbg[id]
			if str(d["op"]) != "midden":
				continue
			kaarten += 1
			var snij: Rect2 = (d["rect"] as Rect2).intersection(balie)
			gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
				"%s: kaart %s laat de balie vrij (%s tegen %s)"
					% [str(maat), id, str(d["rect"]), str(balie)])
		waar(kaarten >= 1, "%s: er stond %d kaart op het scherm" % [str(maat), kaarten])
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
