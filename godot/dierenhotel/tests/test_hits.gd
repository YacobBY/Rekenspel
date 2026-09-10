extends Proef
## The structural placement rule of architecture.md §4.3, as a regression test.
##
## Two invariants, in every frame size and every shape the reviewer could think
## of: no placed element overlaps another, and no button (layer SPEL/HOTEL/WENS)
## overlaps ANY object box in view. A fixed card, a number tag and the keypad
## band are the only things allowed over the world, and they choose first.

const MATEN := [Vector2(1000, 648), Vector2(768, 1024), Vector2(360, 740),
	Vector2(296, 314), Vector2(676, 320)]

## The world frames the five ticket viewports produce (1024x768, 768x1024,
## 1280x800, 360x740, 740x360), measured on the real shell by
## `test_ui.gd::test_shell_op_vijf_schermen` and pasted here so this suite does
## not have to build a window.  That test prints them, so a drift shows up.
const KADERS := [Vector2(990, 637), Vector2(734, 788), Vector2(1170, 669),
	Vector2(326, 402), Vector2(558, 289)]

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

# ------------------------------------------------------------ het toetsenbord

## The keypad band docks to the bottom of the world frame (architecture.md
## §4.4), reserves its cells, and the card lifts itself off it instead of the
## pad sliding over the floor.  Every key stays a real tap target.
func test_toetsenbord_staat_onderaan_en_neemt_zijn_plek() -> void:
	for kader in MATEN + KADERS:
		_op(kader)
		var kaart := Ui.somkaart({"x": 24.0, "z": 20.0}, "3 + 2 =", {
			"id": "pk", "door": "test", "kamer": World.kamer_nu(), "open": true,
			"icoon": "🥄", "regel": "Hoeveel scheppen samen?", "max": 2})
		Hits.plaats()
		var dbg := Hits.debug()
		waar(dbg.has("pk_pad"), "het toetsenbord staat er bij kader %s" % str(kader))
		if dbg.has("pk_pad"):
			var pad: Rect2 = dbg["pk_pad"]["rect"]
			gelijk(dbg["pk_pad"]["op"], "voet", "het pad hangt aan de voet, %s" % str(kader))
			waar(pad.end.y <= kader.y - Hits.KRAP + 0.01 and pad.end.y >= kader.y - Hits.RIJ,
				"het pad staat onderaan het kader %s (%s)" % [str(kader), str(pad)])
			waar(pad.position.x >= 0.0 and pad.end.x <= kader.x + 0.01,
				"het pad past in de breedte van %s (%s)" % [str(kader), str(pad)])
			var kr: Rect2 = dbg["pk"]["rect"]
			var snij := kr.intersection(pad)
			gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
				"de kaart tilt zichzelf van het pad, kader %s" % str(kader))
		_keur(kader, "pad %s" % str(kader))
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
