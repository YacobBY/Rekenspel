extends Proef
## The structural placement rule of architecture.md §4.3, as a regression test.
##
## Two invariants, in every frame size and every shape the reviewer could think
## of: no placed element overlaps another, and no button (layer SPEL/HOTEL/WENS)
## overlaps ANY object box in view. A fixed card and a number tag are the only
## things allowed over the world, and they choose first.

const MATEN := [Vector2(1000, 648), Vector2(768, 1024), Vector2(360, 740),
	Vector2(296, 314), Vector2(676, 320)]

var _laag: Control = null

func _op(kader: Vector2) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = kader
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, null)
	World.meet(Rect2(Vector2.ZERO, kader))

func _af() -> void:
	Hits.wis_alles()
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
