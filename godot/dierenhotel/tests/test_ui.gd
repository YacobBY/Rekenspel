extends Proef
## The UI shell's own contracts: the F4 text budget, the 12 px floor, the
## bundled font subset, the answer-box contract of world.md §5.5, the keypad
## shape rules of architecture.md §4.4/§4.5, and the whole shell measured on the
## five viewports the ticket names.

## The ticket's five screens (CSS px), portrait and landscape.
const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(1280, 800),
	Vector2i(360, 740), Vector2i(740, 360)]
## and the world frames they produce, printed by test_shell_op_vijf_schermen.
const KADERS_UNITS := [Vector2(990, 637), Vector2(734, 788), Vector2(1170, 669),
	Vector2(326, 558), Vector2(558, 289)]

var _laag: Control = null

func _op(kader: Vector2) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = kader
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	World.meet(Rect2(Vector2.ZERO, kader))

func _af() -> void:
	Ui.blad_dicht()
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	if _laag != null:
		_laag.queue_free()
		_laag = null

# --------------------------------------------------------------- F4: de zin

## HOTEL.md §9 / architecture.md §1.1 F4: one plain Dutch sentence, at most
## 8 words AND at most 40 characters.  A violation still draws and warns.
func test_regel_budget() -> void:
	waar(Ui.keur_regel("t", "Hoeveel scheppen eten ze samen op?"), "34 tekens, 6 woorden")
	waar(Ui.keur_regel("t", "Muis wil om half 3 op"), "de wekkerzin uit §6.5")
	waar(not Ui.keur_regel("t", ""), "een lege regel is een fout")
	waar(not Ui.keur_regel("t", "een twee drie vier vijf zes zeven acht negen"),
		"negen woorden is er een te veel")
	waar(not Ui.keur_regel("t", "Hoeveel scheppen eten alle gasten hier samen?!!"),
		"46 tekens is er zes te veel")

## A task card on the notice board keeps its own short line: at most 6 words.
func test_taakkaart_budget() -> void:
	waar(Ui.keur_taak("t", "Zet de bedden op rij"), "vijf woorden mag")
	waar(Ui.keur_taak("t", "Bel een gast"), "drie woorden mag")
	waar(not Ui.keur_taak("t", "Zet alle bedden van het hotel op rij"),
		"acht woorden is er twee te veel")

## The one-line guarantee of F4, re-measured against the bundled Nunito
## (architecture.md §7.5 asks W3 for exactly this number).
func test_kaartzin_past_op_een_regel() -> void:
	var f: Font = Ui.thema.default_font
	waar(f != null, "er is een gebundeld font")
	if f == null:
		return
	var zin := "Hoeveel scheppen eten ze samen op?"        # 34 tekens
	gelijk(zin.length(), 34, "de meetzin is 34 tekens")
	var maat: int = Ui.maten["klein"]
	var breed := f.get_string_size(zin, HORIZONTAL_ALIGNMENT_LEFT, -1, maat).x
	print("[maat] kaartzin 34 tekens = %.1f eenheden bij %d px (kaartmaximum %d)"
		% [breed, maat, UiSomkaart.BREED - 20])
	waar(breed <= float(UiSomkaart.BREED - 20),
		"34 tekens passen op één regel binnen de kaart (%.1f px)" % breed)
	var lang := "Hoeveel scheppen eten alle gasten op?"    # 37 tekens
	var breed2 := f.get_string_size(lang, HORIZONTAL_ALIGNMENT_LEFT, -1, maat).x
	waar(breed2 <= float(UiSomkaart.BREED - 20), "ook 37 tekens passen nog")
	# On the phone card the same sentence wraps instead of being cut.
	waar(f.get_string_size(zin, HORIZONTAL_ALIGNMENT_LEFT, -1, maat).x
		> float(UiSomkaart.BREED_KLEIN - 20), "op de telefoon breekt de zin af")

# ------------------------------------------------------- de letters en glyphs

## Every child-facing letter is at least 12 px, whatever a game asks for.
func test_letters_nooit_onder_twaalf() -> void:
	_op(Vector2(360, 740))
	var niets := func(_k) -> void: pass
	var kaart := Ui.somkaart({"x": 20.0, "z": 20.0}, "3 + 2 =", {
		"id": "vk", "door": "test", "kamer": World.kamer_nu(), "open": true,
		"icoon": "🥄", "regel": "Hoeveel scheppen samen?", "regel2": "📦 In huis: 8 scheppen."})
	Ui.wolk({"id": "vw", "door": "test", "kamer": World.kamer_nu(), "x": 20.0, "z": 20.0,
		"icoon": "🍪", "getal": 3, "tekst": "eten"})
	Ui.getal_tag({"x": 20.0, "z": 20.0}, 7, {"id": "vt", "door": "test"})
	Ui.bron({"x": 20.0, "z": 20.0}, {"id": "vb", "door": "test", "icoon": "🥄",
		"aantal": 4, "hand": 1, "sleep": "bak"})
	Hits.maak({"id": "vs", "kamer": World.kamer_nu(), "x": 20.0, "z": 20.0, "y": 8.0,
		"kind": "keuzes", "door": "test", "keuzes": [
			{"id": "a", "icoon": "⬇", "tekst": "te weinig", "kort": "weinig", "kies": niets}]})
	Hits.plaats()
	var te_klein: Array[String] = []
	for id in Hits.lijst():
		var s := Hits.spot(id)
		if s != null and is_instance_valid(s.knoop):
			_meet_letters(s.knoop, te_klein)
	gelijk(te_klein.size(), 0, "alles boven de 12 px: %s" % str(te_klein))
	waar(kaart != null, "de kaart bestaat")
	_af()

func _meet_letters(k: Node, te_klein: Array[String]) -> void:
	if k is Label or k is Button:
		var maat: int = (k as Control).get_theme_font_size("font_size")
		var tekst: String = k.get("text")
		if maat < UiThema.VLOER and not tekst.is_empty():
			te_klein.append("%s(%s)=%d" % [k.name, tekst, maat])
	for kind in k.get_children():
		_meet_letters(kind, te_klein)

## Every child-facing string of the shell must have a glyph in the bundled
## subset (architecture.md §7.5); a missing one renders as tofu on the web.
func test_alle_schermteksten_hebben_een_glyph() -> void:
	var mist: Array[String] = []
	for zin in _schermteksten():
		for c in Ui.mist_tekens(zin):
			if not mist.has(c):
				mist.append("%s in \"%s\"" % [c, zin])
	gelijk(mist.size(), 0, "geen tofu: %s" % str(mist))

func _schermteksten() -> Array[String]:
	var uit: Array[String] = []
	var scr: GDScript = load("res://ui/teksten.gd")
	for naam in scr.get_script_constant_map().keys():
		var w = scr.get_script_constant_map()[naam]
		if w is String:
			uit.append(w)
	uit.append(UiTekst.start_stand(3, 2, 12, 5))
	uit.append(UiTekst.start_v5_regel(2))
	uit.append(UiTekst.kassa_munten(4))
	uit.append(UiTekst.kassa_sterren(4))
	uit.append(UiTekst.kassa_snoep(4))
	for t in UiKeypad.TOETSEN:
		uit.append(t)
	for id in Rooms.lijst():
		var r := Rooms.get_kamer(id)
		if r != null:
			uit.append(r.icoon)
			uit.append(r.naam)
			uit.append(UiTekst.ga_naar(r.naam))
	for n in 21:
		uit.append(Ui.woord(n))
	uit.append(Ui.meervoud(1, "nacht", "nachten"))
	uit.append("✓")
	return uit

# -------------------------------------------------- world.md §5.5 antwoordvak

## The answer box contract: at most `max` digits, ⌫ wipes one, ✓ hands over the
## number (or `null` when nothing was typed), and `klaar()` ticks the card.
func test_antwoordvak_en_toetsen() -> void:
	_op(Vector2(1000, 648))
	var gekregen := [null]
	var keer := [0]
	var kaart := Ui.somkaart({"x": 20.0, "z": 20.0}, "3 + 2 =", {
		"id": "ak", "door": "test", "kamer": World.kamer_nu(), "open": true, "max": 2,
		"icoon": "🥄", "regel": "Hoeveel scheppen samen?",
		"on_ok": func(n, _k) -> void:
			gekregen[0] = n
			keer[0] += 1})
	Hits.plaats()
	var pad := Hits.spot("ak_pad")
	waar(pad != null, "het toetsenbord staat er")
	if pad == null:
		_af()
		return
	var toets := func(t: String) -> void:
		(pad.knoop as UiKeypad).toets_getikt.emit(t)
	toets.call("4")
	gelijk(kaart.getal(), 4, "één cijfer")
	toets.call("2")
	gelijk(kaart.getal(), 42, "twee cijfers")
	toets.call("7")
	gelijk(kaart.getal(), 42, "een derde cijfer past niet in max 2")
	toets.call(UiKeypad.WIS)
	gelijk(kaart.getal(), 4, "⌫ wist er één")
	toets.call(UiKeypad.OK)
	gelijk(gekregen[0], 4, "✓ geeft het getal door")
	gelijk(keer[0], 1, "en precies één keer")
	toets.call(UiKeypad.WIS)
	toets.call(UiKeypad.OK)
	waar(gekregen[0] == null, "leeg vak geeft null")
	kaart.klaar()
	gelijk(kaart.getal(), null, "een afgevinkte kaart heeft geen getal meer")
	waar(Hits.spot("ak_pad") == null, "klaar() haalt het toetsenbord weg")
	kaart.weg()
	_af()

## There is exactly one keypad: a second card taking it over wins (world.md §5.5).
func test_maar_een_toetsenbord_tegelijk() -> void:
	_op(Vector2(1000, 648))
	var a := Ui.somkaart({"x": 20.0, "z": 20.0}, "1 + 1 =", {
		"id": "ka", "door": "test", "kamer": World.kamer_nu(), "open": true,
		"icoon": "🥄", "regel": "Hoeveel samen?"})
	var b := Ui.somkaart({"x": 26.0, "z": 20.0}, "2 + 2 =", {
		"id": "kb", "door": "test", "kamer": World.kamer_nu(), "open": true,
		"icoon": "🥄", "regel": "En hoeveel nu?"})
	waar(Hits.spot("ka_pad") == null, "de eerste kaart gaf het pad af")
	waar(Hits.spot("kb_pad") != null, "de tweede kaart heeft het")
	gelijk(a.pad_id, "", "en weet dat zelf ook")
	gelijk(b.pad_id, "kb_pad", "de tweede houdt het vast")
	a.weg()
	b.weg()
	_af()

## `o.pad: false` means no keypad at all; `o.keuzes` replaces box and keypad.
func test_kaart_zonder_pad_en_met_keuzes() -> void:
	_op(Vector2(1000, 648))
	var zonder := Ui.somkaart({"x": 20.0, "z": 20.0}, "2 × 3 = 6", {
		"id": "kz", "door": "test", "kamer": World.kamer_nu(), "pad": false,
		"icoon": "🥄", "regel": "Elke dag 3 scheppen"})
	zonder.open()
	waar(Hits.spot("kz_pad") == null, "pad:false laat geen toetsenbord toe")
	var niets := func(_k) -> void: pass
	var met := Ui.somkaart({"x": 26.0, "z": 20.0}, "", {
		"id": "kw", "door": "test", "kamer": World.kamer_nu(), "open": true,
		"icoon": "📦", "regel": "Is er genoeg eten?",
		"keuzes": [{"id": "a", "icoon": "⚖", "tekst": "precies", "kies": niets}]})
	waar(Hits.spot("kw_pad") == null, "keuzes vervangen vak én toetsenbord")
	waar(Hits.spot("kw_keuzes") != null, "de strook staat er wel")
	var kaartknoop := Hits.spot("kw").knoop as UiSomkaart
	waar(not kaartknoop.vak_label.visible, "het antwoordvak is weg bij keuzes")
	zonder.weg()
	met.weg()
	_af()

# ------------------------------------------------------- het toetsenbord zelf

## architecture.md §4.4/§4.5: two rows of six, one row of twelve from 660 units,
## and the worked-out low-frame ladder 620 / 572.  The FRAME decides the shape;
## the SCREEN decides the key size (art-sound-rules.md §16.5), so the size is
## passed in here and checked on its own in the next test.
func test_toetsenbord_vorm_per_kader() -> void:
	var v := UiKeypad.vorm(Vector2(1000, 648), 48)
	gelijk(v["kolommen"], 12, "een breed kader krijgt één rij van twaalf")
	gelijk(v["toets"], 48, "met toetsen van 48")
	v = UiKeypad.vorm(Vector2(600, 900), 48)
	gelijk(v["kolommen"], 6, "een smal hoog kader krijgt twee rijen van zes")
	gelijk(v["toets"], 48, "ook met toetsen van 48")
	v = UiKeypad.vorm(Vector2(300, 700), 44)
	gelijk(v["toets"], 44, "op een klein scherm mogen de toetsen 44 zijn")
	gelijk(v["kolommen"], 6, "en het blijven twee rijen")
	v = UiKeypad.vorm(Vector2(640, 400), 48)
	gelijk(v["kolommen"], 12, "een laag kader van 640 krijgt één rij")
	gelijk(v["toets"], 48, "met toetsen van 48")
	v = UiKeypad.vorm(Vector2(600, 400), 48)
	gelijk(v["kolommen"], 12, "tussen 572 en 620 nog steeds één rij")
	gelijk(v["toets"], 44, "maar dan met toetsen van 44")
	v = UiKeypad.vorm(Vector2(560, 400), 48)
	gelijk(v["kolommen"], 6, "onder 572 breekt de strook naar twee rijen")
	# the band must fit the strip it lives in
	for kader in KADERS_UNITS:
		var w := UiKeypad.vorm(kader, 48)
		waar(float(w["breed"]) <= kader.x, "de band past in de breedte van %s" % str(kader))
		waar(float(w["hoog"]) <= 132.0, "de band past in KADER_ONDER bij %s" % str(kader))
		waar(int(w["toets"]) >= 44, "de toetsen blijven een tikdoel bij %s" % str(kader))

## The lead decision of W3-F1 finding 6: 44 px keys only BELOW a 360 px screen,
## 48 at exactly 360 (art-sound-rules.md §16.5 beats the looser reading of
## HOTEL.md §9).  Measured on the window, never on the world frame — a fingertip
## does not shrink because the chrome took some room.
func test_toetsmaat_hangt_aan_het_scherm() -> void:
	_op(Vector2(326, 402))                       # the frame a 360 px phone gives
	Ui.zet_scherm(Vector2(360, 740))
	gelijk(Ui.tap_maat(), 48, "bij precies 360 px scherm blijven de toetsen 48")
	gelijk(UiKeypad.vorm(Vector2(326, 402))["toets"], 48, "en het toetsenbord ook")
	waar(6 * 48 + 5 * UiKeypad.GAT + 2 * UiKeypad.RAND <= 326,
		"zes toetsen van 48 passen in het kader van zo'n telefoon")
	Ui.zet_scherm(Vector2(320, 640))
	gelijk(Ui.tap_maat(), 44, "onder 360 px scherm mag 44")
	Ui.zet_scherm(Vector2(1024, 768))
	gelijk(Ui.tap_maat(), 48, "en op een tablet is het weer 48")
	_af()

## Every key is a real tap target once it is built.
func test_toetsen_zijn_tikdoelen() -> void:
	for paar in [[Vector2(1000, 648), Vector2(1024, 768), 48],
			[Vector2(322, 562), Vector2(360, 740), 48],
			[Vector2(290, 500), Vector2(320, 640), 44]]:
		var kader: Vector2 = paar[0]
		_op(kader)
		Ui.zet_scherm(paar[1])
		var pad := UiKeypad.new()
		_laag.add_child(pad)
		pad.bouw(kader, Ui.maten)
		var raster: GridContainer = pad.get_node("Toetsen")
		gelijk(raster.get_child_count(), 12, "twaalf toetsen bij %s" % str(kader))
		var eis: int = paar[2]
		for k in raster.get_children():
			var maat: Vector2 = (k as Control).custom_minimum_size
			waar(maat.x >= eis and maat.y >= eis,
				"toets %s is %s (>= %d) bij scherm %s" % [k.name, str(maat), eis, str(paar[1])])
		gelijk(raster.get_child(5).get("text"), UiKeypad.WIS, "⌫ staat op plek 6")
		gelijk(raster.get_child(11).get("text"), UiKeypad.OK, "✓ staat op plek 12")
		pad.queue_free()
		_af()
	Ui.zet_scherm(Vector2(1024, 768))

# ------------------------------------------------------------- de keuzestrook

## Pictogram AND word, always; the short word only when the long strip does not
## fit — decided before the first draw (architecture.md §4.4).
func test_keuzestrook_kiest_korte_woorden() -> void:
	var keuzes := [
		{"id": "min", "icoon": "⬇", "tekst": "te weinig", "kort": "weinig"},
		{"id": "gelijk", "icoon": "⚖", "tekst": "precies", "kort": "precies"},
		{"id": "meer", "icoon": "⬆", "tekst": "blijft over", "kort": "over"},
	]
	_op(Vector2(1000, 648))
	var breed := UiKeuzes.new()
	_laag.add_child(breed)
	breed.bouw(keuzes, 1000.0, Ui.maten, "is er genoeg eten?")
	waar(not breed.kort_gekozen, "op een breed kader blijven de lange woorden staan")
	gelijk(breed.get_node("Rij").get_child(0).get("text"), "⬇ te weinig", "pictogram én woord")
	var smal := UiKeuzes.new()
	_laag.add_child(smal)
	smal.bouw(keuzes, 200.0, Ui.maten, "is er genoeg eten?")
	waar(smal.kort_gekozen, "op een smal kader komen de korte woorden")
	gelijk(smal.get_node("Rij").get_child(0).get("text"), "⬇ weinig", "ook kort: pictogram én woord")
	for rij in [breed.get_node("Rij"), smal.get_node("Rij")]:
		for k in rij.get_children():
			waar(not str(k.get("text")).strip_edges().is_empty(), "nooit een kale knop")
	breed.queue_free()
	smal.queue_free()
	_af()

# ------------------------------------------------------------ toast en bladen

func test_toast_is_geen_knop() -> void:
	_op(Vector2(1000, 648))
	Ui.toast("Smakelijk eten! 😋", "happy")
	var t: Control = _laag.get_node_or_null("Toast")
	waar(t != null, "de toast staat er")
	if t != null:
		gelijk(t.mouse_filter, Control.MOUSE_FILTER_IGNORE, "een toast is nooit een knop")
		waar(t.size.x <= 1000.0 * 0.92 + 0.5, "de toast blijft binnen 92 %")
		# and it is a LINE, not a column: an autowrapping Label reports width 1,
		# so a toast sized from its minimum came out 33 units wide with one
		# letter per line — unreadable, and it stood over the whole world (I1).
		waar(t.size.x >= 100.0, "de toast is een regel, geen kolom (%s)" % str(t.size))
		waar(t.size.y <= 3.0 * Ui.maten["klein"] + 24.0,
			"de toast blijft laag (%s)" % str(t.size))
	_af()

## The sheet carries its title, its hint and a real `Sluiten` tap target — and
## all three have to be SOMEWHERE.  A node that exists but measures 560 x 24 at
## (0, 0) is what shipped the invisible start screen, so every assertion here is
## on `get_global_rect()`, not on the node tree.
func test_blad_heeft_een_sluitknop() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	for kader in [Vector2(1000, 648), Vector2(326, 402), Vector2(534, 289)]:
		_op(kader)
		var blad := Ui.blad_open({"titel": UiTekst.KAART_TITEL, "hint": UiTekst.KAART_HINT,
			"knoppen": [{"id": "sluit", "tekst": UiTekst.SLUITEN}]})
		waar(blad != null, "het blad opent bij %s" % str(kader))
		if blad == null:
			_af()
			continue
		for _f in 3:
			await boom.process_frame
		var scherm := Rect2(Vector2.ZERO, kader)
		gelijk(blad.size, kader, "het blad vult het scherm %s" % str(kader))
		var paneel: Control = blad.get_node("Midden/Blad")
		var pr := paneel.get_global_rect()
		waar(pr.size.x >= 240.0 and pr.size.y >= 80.0,
			"het vel heeft een echte maat bij %s (%s)" % [str(kader), str(pr)])
		waar(scherm.encloses(pr), "en staat in beeld bij %s (%s)" % [str(kader), str(pr)])
		var titel: Label = blad.get_node("Midden/Blad/Rol/Kolom/Titel")
		gelijk(titel.text, UiTekst.KAART_TITEL, "de kop staat er woordelijk")
		waar(pr.encloses(titel.get_global_rect()), "de kop staat op het vel")
		var knop: Button = blad.get_node("Midden/Blad/Rol/Kolom/Knoppen/Ksluit")
		gelijk(knop.text, UiTekst.SLUITEN, "Sluiten staat er woordelijk")
		var kr := knop.get_global_rect()
		waar(kr.size.x >= 48.0 and kr.size.y >= 48.0,
			"Sluiten is een tikdoel bij %s (%s)" % [str(kader), str(kr)])
		waar(scherm.encloses(kr), "en is te bereiken bij %s (%s)" % [str(kader), str(kr)])
		Ui.blad_dicht()
		waar(not Ui.blad_open_nu(), "en het gaat weer dicht")
		_af()

# ------------------------------------------------------------------ de shell

## The whole shell at the five screens of the ticket: the frame gets every unit
## the chrome leaves, never falls under KADER_MIN, the keypad fits, and the tap
## and text rules hold everywhere.  The frames printed here are the ones
## `test_hits.gd::KADERS` walks every room's decor through.
func test_shell_op_vijf_schermen() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var bewaard: Dictionary = State.s.duplicate(true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	waar(scene != null, "de hoofdscene laadt")
	if scene == null:
		return
	for maat in SCHERMEN:
		var vp := SubViewport.new()
		vp.size = maat
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		boom.root.add_child(vp)
		var shell := scene.instantiate()
		shell.set_meta("geen_start", true)
		vp.add_child(shell)
		for _f in 4:
			await boom.process_frame
		var kader: Control = shell.get_node("Scherm/Kolom/Middenrij/Kaderdoos/Kader")
		var chroom: Control = shell.get_node("Scherm/Kolom/Chroom")
		var kb: Control = shell.get_node_or_null("Scherm/Kolom/Kamerbalk")
		if kb == null:
			kb = shell.get_node_or_null("Scherm/Kolom/Middenrij/Rail/Kamerbalk")
		print("[maat] scherm %s -> kader %s chroom %s balk %s"
			% [str(maat), str(kader.size), str(chroom.size), str(kb.size) if kb else "-"])
		waar(kader.size.x > 0.0 and kader.size.y >= 200.0,
			"het kader haalt KADER_MIN bij %s (%s)" % [str(maat), str(kader.size)])
		waar(kader.size.x <= float(maat.x) and kader.size.y <= float(maat.y),
			"het kader past in het scherm %s" % str(maat))
		# the keypad band of this frame fits inside it
		var vorm := UiKeypad.vorm(kader.size)
		waar(float(vorm["breed"]) <= kader.size.x,
			"het toetsenbord past in het kader bij %s" % str(maat))
		waar(float(vorm["hoog"]) <= kader.size.y,
			"het toetsenbord past in de hoogte bij %s" % str(maat))
		# The theme must really reach the shell: a Control inherits it from a
		# Control or Window ANCESTOR only, and the shell's root is a plain Node.
		# Without this check the whole chrome silently falls back to Godot's
		# default theme — every emoji as a tofu box — and no assertion on
		# `Ui.thema` notices.
		var proef := Label.new()
		proef.text = "📅"
		chroom.add_child(proef)
		gelijk(proef.get_theme_font("font"), Ui.thema.default_font,
			"%s: de chroom leest het gebundelde font" % str(maat))
		waar(proef.get_theme_font("font") != null
			and proef.get_theme_font("font").has_char(0x1F4C5),
			"%s: en dat font heeft de emoji" % str(maat))
		proef.queue_free()
		# every tap target in the chrome and the room bar
		var te_klein: Array[String] = []
		var letters: Array[String] = []
		_meet_tikdoelen(shell, te_klein, letters)
		gelijk(te_klein.size(), 0, "%s: alle tikdoelen >= 48: %s" % [str(maat), str(te_klein)])
		gelijk(letters.size(), 0, "%s: alle letters >= 12 px: %s" % [str(maat), str(letters)])
		Hits.wis_alles()
		vp.queue_free()
		await boom.process_frame
	State.s = bewaard
	Ui.registreer_lagen(null, null, null)

## Walk the shell: a Button is a tap target, a Label is reading text.
func _meet_tikdoelen(k: Node, te_klein: Array[String], letters: Array[String]) -> void:
	if k is Button and (k as Control).visible and not str(k.get("text")).is_empty():
		var b := k as Control
		var maat := b.size
		if maat.x > 0.0 and (maat.x < 44.0 or maat.y < 44.0):
			te_klein.append("%s=%s" % [k.name, str(maat)])
	if (k is Label or k is Button) and (k as Control).visible:
		var m: int = (k as Control).get_theme_font_size("font_size")
		if m < UiThema.VLOER and not str(k.get("text")).is_empty():
			letters.append("%s=%d" % [k.name, m])
	for kind in k.get_children():
		_meet_tikdoelen(kind, te_klein, letters)


## V1 finding 4: a toast is a message over the WORLD, never over a tap target.
## The toast layer covers the whole screen, so a toast at its bottom edge lay on
## the room bar — "Precies! 🎉" covered the Zwembad chip for 2.6 s.  The world
## frame is exactly the band between the chrome and the bar.
func test_toast_blijft_in_het_kader() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var scherm := Control.new()            # the whole screen: chrome, frame, room bar
	scherm.size = Vector2(1000, 700)
	boom.root.add_child(scherm)
	var kader := Control.new()             # the world frame, 60 units of chrome above
	kader.position = Vector2(10, 60)
	kader.size = Vector2(980, 560)
	scherm.add_child(kader)
	Ui.registreer_lagen(kader, kader, scherm, scherm, kader)
	World.meet(Rect2(Vector2.ZERO, kader.size))
	Ui.toast("Precies! 🎉", "happy")
	var t: Control = scherm.get_node_or_null("Toast")
	waar(t != null, "de toast staat er")
	if t != null:
		var r := Rect2(t.position, t.size)
		var band := Rect2(kader.position, kader.size)
		waar(band.encloses(r), "de toast blijft in het kader (%s in %s)" % [str(r), str(band)])
		waar(r.position.y >= band.position.y and r.end.y <= band.end.y,
			"dus niet op de chroom of de kamerbalk (%s)" % str(r))
		waar(r.size.x > r.size.y and r.size.y <= 3.0 * Ui.maten["klein"] + 24.0,
			"en het is nog steeds een regel, geen kolom (%s)" % str(r))
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	kader.queue_free()
	scherm.queue_free()
	await boom.process_frame

## V1 finding 3 / world.md §7.10: every counted noun uses `meervoud`, so the
## child never reads "1 sterren".  The plural forms are unchanged, so every
## example in world.md §7.2 and §7.9 still matches word for word.
func test_enkelvoud_en_meervoud_in_de_schermteksten() -> void:
	gelijk(UiTekst.kassa_munten(1), "💰 1 munt", "1 munt")
	gelijk(UiTekst.kassa_munten(0), "💰 0 munten", "0 munten")
	gelijk(UiTekst.kassa_munten(12), "💰 12 munten", "12 munten")
	gelijk(UiTekst.kassa_sterren(1), "⭐ 1 ster", "1 ster")
	gelijk(UiTekst.kassa_sterren(5), "⭐ 5 sterren", "5 sterren")
	gelijk(UiTekst.start_stand(1, 1, 1, 1),
		"Je was bij 1 dag — met 1 gast, 1 munt en 1 ster.", "alles enkelvoud")
	gelijk(UiTekst.start_stand(3, 2, 12, 5),
		"Je was bij 3 dagen — met 2 gasten, 12 munten en 5 sterren.", "alles meervoud")

## V1 finding 2: a saved mute must survive a reload.  The mute used to be
## decided on the FIRST INPUT, and the first input is the tap on "Verder spelen
## ▸" — which happens before `State.s` is swapped for the saved game, so a
## `geluid=false` save came back with the sound on for the whole session.
func test_bewaard_geluid_uit_komt_terug() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var bewaard: Dictionary = State.s.duplicate(true)
	State.nieuw_spel()
	State.start_gekozen()
	State.s["dag"] = 3
	State.s["geluid"] = false
	waar(State.bewaar(), "er staat een stille opslag klaar")
	Snd.stem_af(true)                         # this session starts with sound

	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 768)
	boom.root.add_child(vp)
	var shell := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	vp.add_child(shell)
	for _f in 5:
		await boom.process_frame
	# behind the sheet a FRESH game runs, and a fresh game has sound
	waar(not Snd.dempt(), "achter het startblad speelt het verse spel geluid")
	var verder: Button = shell.get_node_or_null("Bladlaag/Blad/Midden/Blad/Rol/Kolom/Knoppen/Kverder")
	waar(verder != null, "de knop 'Verder spelen' staat er")
	if verder != null:
		verder.emit_signal("pressed")
		await boom.process_frame
		gelijk(int(State.s["dag"]), 3, "de opgeslagen dag is terug")
		waar(Snd.dempt(), "en het geluid staat weer uit, zoals het kind het liet")
	Hits.wis_alles()
	vp.queue_free()
	await boom.process_frame
	Snd.stem_af(true)
	State.nieuw_spel()
	State.s = bewaard
	Ui.registreer_lagen(null, null, null)
	Ui.registreer_wortels([])

## world.md §6.2: with a save on disk the shell asks before it touches anything.
## Nothing is written before the child answered (architecture.md §9), and the
## two buttons carry their wording verbatim.
func test_startscherm_vraagt_voor_het_bewaart() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var bewaard: Dictionary = State.s.duplicate(true)
	# a save to come back to
	State.nieuw_spel()
	State.start_gekozen()
	State.s["dag"] = 4
	State.s["munten"] = 12
	State.s["sterren"] = 5
	waar(State.bewaar(), "er staat een opslag klaar")

	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 768)
	boom.root.add_child(vp)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var shell := scene.instantiate()
	vp.add_child(shell)
	for _f in 5:
		await boom.process_frame
	var blad: UiBlad = shell.get_node_or_null("Bladlaag/Blad")
	waar(blad != null, "het startscherm staat er")
	if blad != null:
		waar(not blad.sluitbaar, "en het is niet weg te tikken")
		# and it is VISIBLE: a 560 x 24 strip at (0, 0) is what made the start
		# screen unanswerable, and with it every bewaar() a no-op.
		var scherm := Rect2(Vector2.ZERO, Vector2(1024, 768))
		gelijk(blad.size, Vector2(1024, 768), "het blad vult het scherm")
		var pr: Rect2 = (blad.get_node("Midden/Blad") as Control).get_global_rect()
		waar(pr.size.x >= 240.0 and pr.size.y >= 120.0,
			"het vel heeft een echte maat (%s)" % str(pr))
		waar(scherm.encloses(pr), "en staat in beeld (%s)" % str(pr))
		gelijk((blad.get_node("Midden/Blad/Rol/Kolom/Titel") as Label).text,
			UiTekst.START_TERUG, "de kop staat er woordelijk")
		var regel: Label = blad.get_node("Midden/Blad/Rol/Kolom").get_child(1)
		gelijk(regel.text, UiTekst.start_stand(4, 0, 12, 5), "de stand staat er woordelijk")
		var verder: Button = blad.get_node("Midden/Blad/Rol/Kolom/Knoppen/Kverder")
		var nieuw: Button = blad.get_node("Midden/Blad/Rol/Kolom/Knoppen/Knieuw")
		gelijk(verder.text, UiTekst.START_VERDER, "Verder spelen ▸")
		gelijk(nieuw.text, UiTekst.START_NIEUW, "Nieuw spel")
		for knop in [verder, nieuw]:
			var kr := (knop as Control).get_global_rect()
			waar(kr.size.x >= 48.0 and kr.size.y >= 48.0,
				"%s is een tikdoel (%s)" % [knop.text, str(kr)])
			waar(Rect2(Vector2.ZERO, Vector2(1024, 768)).encloses(kr),
				"%s is te bereiken (%s)" % [knop.text, str(kr)])
		# behind the sheet a living world is already running (world.md §6.2)
		gelijk(int(State.s["dag"]), 1, "achter het blad draait een vers hotel")
		verder.emit_signal("pressed")
		await boom.process_frame
		gelijk(int(State.s["dag"]), 4, "Verder spelen zet de opgeslagen dag terug")
		gelijk(int(State.s["sterren"]), 5, "en de sterren")
	Hits.wis_alles()
	vp.queue_free()
	await boom.process_frame
	State.s = bewaard
	Ui.registreer_lagen(null, null, null)
	Ui.registreer_wortels([])
