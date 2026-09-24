extends Proef
## The UI shell's own contracts: the F4 text budget, the 12 px floor, the
## bundled font subset, the answer-strip contract of world.md §5.5 (four
## numbers, one tap), and the whole shell measured on the five viewports the
## ticket names.

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

# ------------------------------------------------------- slepen of tikken

## Firefox measures a finger's `movementX` from where the MOUSE last was: once
## the mouse moved in a session, the first tremble of a tap arrives as a
## `relative` of hundreds of units, Godot started a drag on it and the tap on a
## source was lost (found on the voerkar, 2026-09-23).  A source now starts a
## drag on the REAL distance from where it was pressed: that tremble stays a
## tap, and a finger that really moves still drags.
func test_een_trillende_tik_op_een_bron_blijft_een_tik() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var vp := SubViewport.new()
	vp.size = Vector2i(1000, 648)
	vp.gui_embed_subwindows = true
	boom.root.add_child(vp)
	var laag := Control.new()
	laag.size = Vector2(1000, 648)
	vp.add_child(laag)
	Ui.registreer_lagen(laag, laag, laag, laag, laag)
	World.meet(Rect2(Vector2.ZERO, laag.size))
	var tikken := [0]
	Ui.bron({"x": 40.0, "z": 40.0}, {"id": "proefbron", "kamer": World.kamer_nu(),
		"icoon": "🍪", "label": "koekjes", "aantal": 3, "sleep": "proef",
		"tik": func(_s = null) -> void: tikken[0] += 1})
	Hits.plaats()
	await boom.process_frame
	var bron := Ui.bron_van("proefbron")
	waar(bron != null, "de bron staat er")
	if bron != null:
		var p := bron.get_global_rect().get_center()
		_druk(vp, p, true)
		await boom.process_frame
		var mm := InputEventMouseMotion.new()
		mm.position = p + Vector2(1, 0)
		mm.global_position = mm.position
		mm.relative = Vector2(-553, -367)     # what Firefox reports for that tremble
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		vp.push_input(mm)
		await boom.process_frame
		waar(not vp.gui_is_dragging(), "een trillinkje is geen sleep")
		_druk(vp, p + Vector2(1, 0), false)
		await boom.process_frame
		gelijk(tikken[0], 1, "de tik kwam aan")
		# and a finger that really moves still drags
		_druk(vp, p, true)
		await boom.process_frame
		for i in range(1, 6):
			var m2 := InputEventMouseMotion.new()
			m2.position = p + Vector2(8.0 * i, 0)
			m2.global_position = m2.position
			m2.relative = Vector2(8, 0)
			m2.button_mask = MOUSE_BUTTON_MASK_LEFT
			vp.push_input(m2)
			await boom.process_frame
		waar(vp.gui_is_dragging(), "40 eenheden verder is het wel een sleep")
		_druk(vp, p + Vector2(40, 0), false)
		await boom.process_frame
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	vp.queue_free()

func _druk(vp: SubViewport, p: Vector2, in_: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = in_
	mb.position = p
	mb.global_position = p
	vp.push_input(mb)

# ------------------------------------------------- knop of mededeling

## What you can press looks pressable, what only speaks does not (owner,
## 2026-09-23: "heel veel textboxen die allemaal klikbaar lijken dan is het niet
## meer duidelijk welke nou interactie hebben en welke niet").  A bubble without
## its own `tik` is flat, lets a tap through and takes no focus; a bubble with a
## `tik` and every hotel button stand on a key edge that goes down when pressed.
func test_knop_en_mededeling_zien_er_anders_uit() -> void:
	_op(Vector2(1000, 648))
	Ui.wolk({"id": "zeg", "kamer": World.kamer_nu(), "x": 20.0, "z": 20.0,
		"icoon": "🛒", "tekst": "Breng 4 koekjes naar elke gast"})
	Ui.wolk({"id": "doe", "kamer": World.kamer_nu(), "x": 40.0, "z": 20.0,
		"icoon": "🐶", "tekst": "Boef komt eraan", "tik": func(_s) -> void: pass})
	var zeg := Hits.spot("zeg").knoop as UiWolk
	gelijk(zeg.actie, false, "een mededeling doet niets")
	gelijk(zeg.mouse_filter, Control.MOUSE_FILTER_IGNORE, "een tik gaat er dwars doorheen")
	gelijk(zeg.focus_mode, Control.FOCUS_NONE, "en ze krijgt geen focus")
	var plat := zeg.get_theme_stylebox("normal") as StyleBoxFlat
	gelijk(plat.border_width_bottom, 0, "plat: geen rand")
	gelijk(plat.shadow_size, 0, "en geen schaduw")
	gelijk(zeg.get_theme_stylebox("pressed"), plat, "ingedrukt ziet ze er net zo uit")
	var doe := Hits.spot("doe").knoop as UiWolk
	gelijk(doe.actie, true, "een wolk met een tik doet iets")
	gelijk(doe.mouse_filter, Control.MOUSE_FILTER_STOP, "en vangt de tik")
	var sleutel := doe.get_theme_stylebox("normal") as StyleBoxFlat
	waar(sleutel.border_width_bottom >= UiThema.KNOP_LIP, "ze staat op een drukrand")
	waar((doe.get_theme_stylebox("pressed") as StyleBoxFlat).border_width_bottom
		< sleutel.border_width_bottom, "die ingedrukt zakt")
	var hotknop := Ui.thema.get_stylebox("normal", "Hotknop") as StyleBoxFlat
	waar(hotknop.border_width_bottom >= UiThema.KNOP_LIP, "een hotelknop staat op dezelfde rand")
	waar(hotknop.shadow_size > 0, "met een schaduwtje")
	waar((Ui.thema.get_stylebox("pressed", "Hotknop") as StyleBoxFlat).border_width_bottom
		< hotknop.border_width_bottom, "en zakt als je drukt")
	var antwoord := Ui.thema.get_stylebox("normal", "Keuzeknop") as StyleBoxFlat
	waar(antwoord.border_width_bottom >= UiThema.KNOP_LIP, "een antwoordknop ook")
	_af()

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

# -------------------------------------------------- world.md §5.5 antwoordstrook

## Press one button of the strip glued under card `id`.
func _kies(id: String, knop: String) -> bool:
	var s := Hits.spot(id + "_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		return false
	var k := s.knoop.get_node_or_null("Rij/K" + knop) as BaseButton
	if k == null:
		return false
	k.emit_signal("pressed")
	return true

func _strook_getallen(id: String) -> Array[int]:
	var uit: Array[int] = []
	var s := Hits.spot(id + "_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		return uit
	for k in s.knoop.get_node("Rij").get_children():
		var laatste := str((k as Button).text).split(" ")[-1]
		if laatste.is_valid_int():
			uit.append(laatste.to_int())
	return uit

## The answer contract (owner, 2026-09-14): a card with `goed` carries a strip of
## four numbers, pictogram and number in one button, exactly one right; a tap
## puts the number in the box and hands it over at once — no ✓, no keypad.
func test_antwoordstrook_vier_getallen_een_tik() -> void:
	_op(Vector2(1000, 648))
	var gekregen := [null]
	var keer := [0]
	var kaart := Ui.somkaart({"x": 20.0, "z": 20.0}, "3 + 2 =", {
		"id": "ak", "door": "test", "kamer": World.kamer_nu(), "goed": 5, "max": 2,
		"liever": [3, 2], "icoon": "🥄", "regel": "Hoeveel scheppen samen?",
		"on_ok": func(n, _k) -> void:
			gekregen[0] = n
			keer[0] += 1})
	Hits.plaats()
	waar(Hits.spot("ak_pad") == null, "er is geen toetsenbord meer")
	var strook := Hits.spot("ak_keuzes")
	waar(strook != null, "de strook hangt aan de kaart")
	if strook == null:
		_af()
		return
	var getallen := _strook_getallen("ak")
	gelijk(getallen.size(), 4, "vier getallen: %s" % str(getallen))
	waar(getallen.has(5), "het goede antwoord staat ertussen")
	waar(getallen.has(3) and getallen.has(2), "de twee getallen uit de som ook (liever)")
	var gesorteerd := getallen.duplicate()
	gesorteerd.sort()
	gelijk(getallen, gesorteerd, "op volgorde, als een getallenlijn")
	for k in strook.knoop.get_node("Rij").get_children():
		waar(str((k as Button).text).begins_with("🥄 "), "pictogram én getal: %s" % (k as Button).text)
	var kaartknoop := Hits.spot("ak").knoop as UiSomkaart
	waar(kaartknoop.vak_label.visible, "het antwoordvak blijft: daar komt het getikte getal")
	waar(_kies("ak", "n3"), "3 is een knop")
	gelijk(gekregen[0], 3, "één tik geeft het getal meteen door")
	gelijk(keer[0], 1, "en precies één keer")
	gelijk(kaart.getal(), 3, "en het staat in het vak")
	# 3 was fout, dus de strook staat even op slot (S5).  Direct daarna nog
	# eens tikken doet niets; pas na die pauze gaat de volgende tik door.
	waar(_kies("ak", "n5"), "5 is een knop, maar de strook staat nog op slot")
	gelijk(keer[0], 1, "en on_ok hoort die tik niet")
	await _wacht(Ui.MIS_PAUZE + 0.3)
	waar(_kies("ak", "n5"), "na de mispauze is de strook weer vrij")
	gelijk(gekregen[0], 5, "en komt het goede getal door")
	gelijk(keer[0], 2, "precies één keer extra")
	kaart.klaar()
	gelijk(kaart.getal(), null, "een afgevinkte kaart heeft geen getal meer")
	waar(Hits.spot("ak_keuzes") == null, "klaar() haalt de strook weg")
	kaart.weg()
	_af()

## Wait out real seconds on the main loop.  The miss pause is a wall-clock
## timer, not a think tick, so this is what a UI test needs to sit through it.
func _wacht(seconden: float) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var eind := Time.get_ticks_msec() + int(seconden * 1000.0)
	while Time.get_ticks_msec() < eind:
		await boom.process_frame

## The id of a button on the strip of card `id` whose number is NOT `goed`.
func _verkeerd_getal(id: String, goed: int) -> String:
	for n in _strook_getallen(id):
		if n != goed:
			return "n%d" % n
	return ""

## The guest these miss-tests hang their card on.
const MIS_GAST := "ui_sip"

## A card with `goed` and a strip, hanging where nothing else is.
func _mis_kaart(id: String, goed: int, dier: String, keer: Array):
	var o := {
		"id": id, "door": "test", "kamer": World.kamer_nu(), "goed": goed, "max": 2,
		"icoon": "🥄", "regel": "Hoeveel scheppen samen?", "dier": dier}
	o["on_ok"] = func(n, _k) -> void: keer.append(n)
	var kaart := Ui.somkaart({"x": 20.0, "z": 20.0}, "3 + 2 =", o)
	Hits.plaats()
	return kaart

# --------------------------------------------------------------- S5: de misser

## A wrong answer does something a child can see: the animal of the turn
## goes `sip` for `Ui.SIP_TIKKEN` think ticks and comes out of it by itself
## (PLAN.md S5).  Nothing was taken away to get there.
func test_een_misser_maakt_het_dier_even_sip() -> void:
	_op(Vector2(1000, 648))
	World.zet(MIS_GAST, World.kamer_nu(), 20.0, 20.0, {"kind": "hond"})
	var keer: Array = []
	var kaart = _mis_kaart("ms1", 5, MIS_GAST, keer)
	waar(World.dier(MIS_GAST).pose != "sip", "voordat er iets misging was hij niet sip")
	var f := _verkeerd_getal("ms1", 5)
	waar(not f.is_empty() and _kies("ms1", f), "een verkeerd getal getikt")
	gelijk(World.dier(MIS_GAST).pose, "sip", "het dier van de beurt is sip")
	waar(Hits.spot("mis_ms1") != null, "met 🔄 Nog een keer naast zich")
	gelijk(World.dier(MIS_GAST).tikken, Ui.SIP_TIKKEN,
		"en wel %d tikken, dus ~2 s bij World.TIK" % Ui.SIP_TIKKEN)
	waar(float(Ui.SIP_TIKKEN) * World.TIK > Ui.MIS_PAUZE,
		"de sip duurt langer dan het slot op de strook (eigenaar 2026-09-24)")
	gelijk(keer.size(), 1, "en het spel hoort het foute antwoord gewoon")
	for _i in Ui.SIP_TIKKEN + 2:
		World._tik()
	waar(World.dier(MIS_GAST).pose != "sip", "en na die tikken is hij het vanzelf kwijt")
	kaart.weg()
	World.weg(MIS_GAST)
	_af()

## The strip locks for `Ui.MIS_PAUZE` seconds: a second tap during that
## window does nothing at all — no second answer, no sound, no number in the
## box.  Afterwards it opens by itself.
func test_de_strook_gaat_even_op_slot() -> void:
	_op(Vector2(1000, 648))
	var keer: Array = []
	var kaart = _mis_kaart("sl1", 5, "", keer)
	var f := _verkeerd_getal("sl1", 5)
	waar(_kies("sl1", f), "de eerste verkeerde tik komt door")
	gelijk(keer.size(), 1, "on_ok één keer aangeroepen")
	var strook := Hits.spot("sl1_keuzes").knoop as UiKeuzes
	waar(strook.op_slot, "de strook staat op slot")
	for b in strook.get_node("Rij").get_children():
		waar((b as Button).disabled, "elke knop is uit")
		waar(float((b as Button).modulate.a) < 1.0, "en lichter van kleur")
	waar(_kies("sl1", "n5"), "er wordt wél op geklikt")
	gelijk(keer.size(), 1, "maar on_ok blijft bij één")
	gelijk(kaart.getal(), int(f), "het foute getal staat nog in het vak")
	await _wacht(Ui.MIS_PAUZE + 0.3)
	waar(not strook.op_slot, "na de pauze is de strook weer open")
	for b in strook.get_node("Rij").get_children():
		waar(not (b as Button).disabled, "en elke knop weer aan")
	gelijk(kaart.getal(), null, "en het antwoordvak is leeg")
	waar(_kies("sl1", "n5"), "nu gaat de tik door")
	gelijk(keer.size(), 2, "en on_ok hoort het tweede antwoord")
	gelijk(keer[-1], 5, "het goede getal")
	kaart.weg()
	_af()

## The pause is not a new question: the same four numbers stand in the same
## order, and the box is empty so the child starts clean.
func test_dezelfde_keuzes_komen_terug() -> void:
	_op(Vector2(1000, 648))
	var keer: Array = []
	var kaart = _mis_kaart("kk1", 5, "", keer)
	var voor := _strook_getallen("kk1")
	gelijk(voor.size(), 4, "vier getallen")
	waar(_kies("kk1", _verkeerd_getal("kk1", 5)), "verkeerd getikt")
	await _wacht(Ui.MIS_PAUZE + 0.3)
	gelijk(_strook_getallen("kk1"), voor, "dezelfde vier getallen, dezelfde volgorde")
	gelijk(kaart.getal(), null, "en het antwoordvak is leeg")
	kaart.weg()
	_af()

## R6 (HOTEL.md §1): a miss costs nothing.  No star away, no coin away, the
## game is not locked, and the child may go on playing.
func test_een_misser_kost_niets() -> void:
	_op(Vector2(1000, 648))
	var sterren_voor := int(State.s.get("sterren", 0))
	var munten_voor := int(State.s.get("munten", 0))
	var keer: Array = []
	var kaart = _mis_kaart("kn1", 5, "", keer)
	for _poging in 3:
		waar(_kies("kn1", _verkeerd_getal("kn1", 5)), "nog een keer verkeerd")
		await _wacht(Ui.MIS_PAUZE + 0.2)
	gelijk(int(State.s.get("sterren", 0)), sterren_voor, "geen enkele ster weg")
	gelijk(int(State.s.get("munten", 0)), munten_voor, "geen enkele munt weg")
	gelijk(keer.size(), 3, "het spel hoort elke misser en doet zijn eigen tred")
	waar(not kaart.pauze, "en na de derde pauze is de strook weer vrij")
	kaart.weg()
	_af()

## A card with no animal still pauses, and the miss is still seen (owner,
## 2026-09-24: a wrong answer gets no help, only its disappointment): the
## `🔄 Nog een keer` bubble hangs at the card's own thing — where the card
## points — for as long as the strip is locked.
func test_zonder_dier_hangt_het_wolkje_bij_de_kaart() -> void:
	_op(Vector2(1000, 648))
	var keer: Array = []
	var kaart = _mis_kaart("nd1", 5, "", keer)
	gelijk(kaart.dier, "", "er is geen dier van de beurt")
	waar(_kies("nd1", _verkeerd_getal("nd1", 5)), "verkeerd getikt")
	var wolk := Hits.spot("mis_nd1")
	waar(wolk != null, "het wolkje staat er toch")
	if wolk != null:
		var plek := Hits.spot("nd1")
		gelijk(Vector2(wolk.x, wolk.z), Vector2(plek.x, plek.z), "op het punt van de kaart")
		waar(wolk.y > plek.y, "en er net boven")
		gelijk(wolk.door, "test", "van het spel van de kaart")
		waar(str((wolk.knoop as Control).tooltip_text).contains(UiTekst.MIS_ZIN), "🔄 Nog een keer")
	var strook := Hits.spot("nd1_keuzes").knoop as UiKeuzes
	waar(strook.op_slot, "en de strook staat op slot")
	await _wacht(Ui.MIS_PAUZE + 0.3)
	waar(not strook.op_slot, "die gaat gewoon weer open")
	waar(Hits.spot("mis_nd1") == null, "en het wolkje is weg")
	kaart.weg()
	_af()

## A miss without a card — a coin that slides back, a stroke that fell short —
## is only the animal: he sulks, the bubble hangs beside him in the name of
## the game that asked, and after the pause it goes by itself.
func test_een_misser_zonder_kaart_is_alleen_het_dier() -> void:
	_op(Vector2(1000, 648))
	World.zet(MIS_GAST, World.kamer_nu(), 20.0, 20.0, {"kind": "konijn"})
	Ui.misser(null, MIS_GAST, "test")
	var id := Ui.MIS_WOLK + Ui.MIS_DIER + MIS_GAST
	gelijk(World.dier(MIS_GAST).pose, "sip", "het dier is sip")
	var wolk := Hits.spot(id)
	waar(wolk != null, "met het wolkje naast zich")
	if wolk != null:
		gelijk(wolk.door, "test", "op naam van het spel")
	Ui.misser(null, "", "test")
	Ui.misser(null, "niemand_hier", "test")
	await _wacht(Ui.MIS_PAUZE + 0.3)
	waar(Hits.spot(id) == null, "na de pauze is het wolkje weg")
	World.weg(MIS_GAST)
	_af()

## Without a strip the box is the game's own — the coins on the counter, the
## number on a key — and the end of the pause leaves it standing.
func test_zonder_strook_blijft_het_vak_van_het_spel() -> void:
	_op(Vector2(1000, 648))
	World.zet(MIS_GAST, World.kamer_nu(), 20.0, 20.0, {"kind": "hond"})
	var kaart := Ui.somkaart({"x": 20.0, "z": 20.0}, "€5", {
		"id": "vk1", "door": "test", "kamer": World.kamer_nu(), "max": 2,
		"icoon": "🎁", "regel": "Leg de munten op de toonbank", "dier": MIS_GAST})
	Hits.plaats()
	kaart.zet("€3")
	Ui.misser(kaart, MIS_GAST)
	waar(kaart.pauze, "de misser loopt")
	await _wacht(Ui.MIS_PAUZE + 0.3)
	waar(not kaart.pauze, "en is voorbij")
	var knoop := Hits.spot("vk1").knoop as UiSomkaart
	gelijk(knoop.vak_label.text, "€3", "wat het spel in het vak schreef, staat er nog")
	kaart.weg()
	World.weg(MIS_GAST)
	_af()

## A game that rebuilds its card under the same id during a pause owns a new
## strip: the old pause's timer does not unlock it and does not take the new
## card's bubble away.
func test_een_nieuwe_kaart_houdt_haar_eigen_misser() -> void:
	_op(Vector2(1000, 648))
	World.zet(MIS_GAST, World.kamer_nu(), 20.0, 20.0, {"kind": "poes"})
	var keer: Array = []
	var oud = _mis_kaart("nk1", 5, MIS_GAST, keer)
	waar(_kies("nk1", _verkeerd_getal("nk1", 5)), "de eerste misser")
	await _wacht(0.6)
	var nieuw = _mis_kaart("nk1", 5, MIS_GAST, keer)
	waar(nieuw != oud, "de kaart is opnieuw gebouwd")
	waar(_kies("nk1", _verkeerd_getal("nk1", 5)), "de misser op de nieuwe kaart")
	await _wacht(Ui.MIS_PAUZE - 0.6 + 0.2)
	var strook := Hits.spot("nk1_keuzes").knoop as UiKeuzes
	waar(strook.op_slot, "de oude timer liep af, de nieuwe strook blijft op slot")
	waar(Hits.spot("mis_nk1") != null, "en het wolkje van de nieuwe misser staat er nog")
	await _wacht(0.8)
	waar(not strook.op_slot, "tot haar eigen pauze voorbij is")
	waar(Hits.spot("mis_nk1") == null, "en dan gaat het wolkje ook")
	nieuw.weg()
	World.weg(MIS_GAST)
	_af()

## Closing the card in the middle of the pause leaves nothing behind: the
## bubble goes with it, and the timer that is still running finds no card to
## unlock and erases nothing.
func test_sluiten_tijdens_de_pauze_lekt_niets() -> void:
	_op(Vector2(1000, 648))
	World.zet(MIS_GAST, World.kamer_nu(), 20.0, 20.0, {"kind": "kat"})
	var keer: Array = []
	var kaart = _mis_kaart("lk1", 5, MIS_GAST, keer)
	waar(_kies("lk1", _verkeerd_getal("lk1", 5)), "verkeerd getikt")
	waar(Hits.spot("mis_lk1") != null, "het wolkje staat er")
	waar(kaart.pauze, "en de kaart staat op slot")
	kaart.weg()
	waar(Hits.spot("mis_lk1") == null, "met de kaart weg gaat het wolkje mee")
	waar(not kaart.pauze, "en is de pauze voorbij")
	await _wacht(Ui.MIS_PAUZE + 0.4)
	waar(Hits.spot("mis_lk1") == null, "en de lopende timer maakt hem niet terug")
	gelijk(keer.size(), 1, "het spel heeft nog steeds maar één antwoord gehoord")
	World.weg(MIS_GAST)
	_af()

## The same card draws the same strip: after a slip the four choices come back
## unchanged, and a reload shows what the child saw.
func test_antwoordstrook_is_herhaalbaar_en_begrensd() -> void:
	_op(Vector2(1000, 648))
	var o := {"id": "hh", "door": "test", "kamer": World.kamer_nu(), "goed": 0, "max": 2,
		"icoon": "🥄", "regel": "Hoeveel blijft over?", "on_ok": func(_n, _k) -> void: pass}
	var a := Ui.somkaart({"x": 20.0, "z": 20.0}, "2 − 2 =", o)
	var eerste := _strook_getallen("hh")
	a.weg()
	var b := Ui.somkaart({"x": 20.0, "z": 20.0}, "2 − 2 =", o)
	gelijk(_strook_getallen("hh"), eerste, "dezelfde kaart, dezelfde strook")
	for n in eerste:
		waar(n >= 0 and n <= 99, "nooit onder nul of boven het cijferbudget: %d" % n)
	gelijk(eerste.size(), 4, "ook bij 0 zijn er vier")
	b.weg()
	# a strip a game hands over is capped at four
	var veel: Array = []
	for i in 6:
		veel.append({"id": "v%d" % i, "icoon": "🪨", "tekst": "%d keer" % i,
			"kies": func(_id, _k) -> void: pass})
	var c := Ui.somkaart({"x": 20.0, "z": 20.0}, "", {
		"id": "zes", "door": "test", "kamer": World.kamer_nu(), "icoon": "🪨",
		"regel": "Hoeveel keer?", "keuzes": veel})
	gelijk(Hits.spot("zes_keuzes").knoop.get_node("Rij").get_child_count(), 4,
		"hooguit vier knoppen op een strook")
	c.weg()
	_af()

## A card without `goed` or `keuzes` is a statement: no strip at all; a strip of
## words replaces the answer box.
func test_kaart_zonder_vraag_en_met_woorden() -> void:
	_op(Vector2(1000, 648))
	var zonder := Ui.somkaart({"x": 20.0, "z": 20.0}, "2 × 3 = 6", {
		"id": "kz", "door": "test", "kamer": World.kamer_nu(),
		"icoon": "🥄", "regel": "Elke dag 3 scheppen"})
	waar(Hits.spot("kz_keuzes") == null, "zonder vraag geen strook")
	var niets := func(_k) -> void: pass
	var met := Ui.somkaart({"x": 26.0, "z": 20.0}, "", {
		"id": "kw", "door": "test", "kamer": World.kamer_nu(),
		"icoon": "📦", "regel": "Is er genoeg eten?",
		"keuzes": [{"id": "a", "icoon": "⚖", "tekst": "precies", "kies": niets}]})
	waar(Hits.spot("kw_keuzes") != null, "de strook staat er wel")
	var kaartknoop := Hits.spot("kw").knoop as UiSomkaart
	waar(not kaartknoop.vak_label.visible, "het antwoordvak is weg bij woorden")
	zonder.weg()
	met.weg()
	_af()

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
		# four 48-unit buttons and their gaps fit in the width of every frame
		waar(4 * 48.0 + 3 * 4.0 + 10.0 <= kader.size.x,
			"vier antwoordknoppen passen in het kader bij %s" % str(maat))
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
