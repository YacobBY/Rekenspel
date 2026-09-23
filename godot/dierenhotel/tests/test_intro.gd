extends Proef
## The intro of a fresh game (`ui/intro.gd`, world.md §6.2; owner 2026-09-23:
## "Maak ook een leuke intro voor de game").
##
## What is proven here, each on the real shell (`scenes/main.tscn`) with its
## real `_begin()`: the intro comes on a fresh game (no save, or `Nieuw spel`)
## and never after `Verder spelen`; `Overslaan ▸▸` ends it at once and leaves
## nothing in the world; the pages are the six sentences of `UiTekst` in order;
## the last one lights the bell in the receptie and a tap on it rings the real
## bell; every sentence and button keeps HOTEL.md §9 on the four screens of the
## owner's brief; and with reduced motion the same pages stand still.

## The four screens of the brief: desktop, iPad, phone upright, phone on its side.
const SCHERMEN := [Vector2i(1536, 760), Vector2i(1024, 768), Vector2i(360, 740),
	Vector2i(740, 360)]

var _vp: SubViewport = null
var _shell: Node = null
var _bewaard: Dictionary = {}
var _gekozen := false
var _bestand := ""            ## the save on disk before the test, verbatim
var _had_bestand := false
var _scherm_terug = null
var _rust_terug := false
var _thema_terug := Vector2i(18, 0)
var _wakker_terug := false

func _boom() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

func _frames(n: int) -> void:
	for _f in n:
		await _boom().process_frame

# ------------------------------------------------------------------ opzet

## Everything a shell changes in the autoloads, remembered once per test.
func _onthoud() -> void:
	_bewaard = State.s.duplicate(true)
	_gekozen = State.gestart()
	_had_bestand = FileAccess.file_exists(State.PAD)
	_bestand = FileAccess.get_file_as_string(State.PAD) if _had_bestand else ""
	_scherm_terug = Ui.get("_scherm")
	_rust_terug = Ui.rust_modus()
	_thema_terug = Vector2i(Ui.basis_maat(), 1 if bool(Ui.get("_ruim")) else 0)
	# a pushed tap is a first touch: the shell wakes the audio (`main.gd _input`)
	_wakker_terug = Snd.ontgrendeld()

## Boot the shell at `maat`.  `opslag`: a save of day 3 on disk first (the
## start sheet), otherwise NO save at all (a fresh game).
func _start(maat: Vector2i, opslag := false) -> void:
	var d := DirAccess.open("user://")
	if d != null and FileAccess.file_exists(State.PAD):
		d.remove(State.PAD.get_file())
	if opslag:
		State.nieuw_spel()
		State.start_gekozen()
		State.s["dag"] = 3
		State.s["munten"] = 7
		State.bewaar()
	_vp = SubViewport.new()
	_vp.size = maat
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_boom().root.add_child(_vp)
	_shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	_vp.add_child(_shell)
	await _frames(5)
	var intro := _intro()
	if intro != null:
		intro.drempel_s = 0.0

## The shell goes, and with it everything; the autoloads get back what they had.
func _weg() -> void:
	Hits.wis_alles()
	if _vp != null:
		_vp.queue_free()
		_vp = null
		_shell = null
		await _frames(2)
	Ui.registreer_lagen(null, null, null)
	Ui.registreer_wortels([])

func _af() -> void:
	await _weg()
	if Hits.voorrang_van() == UiIntro.EIGENAAR:
		Hits.voorrang("")
	Ui.zet_rust_modus(_rust_terug)
	# the audio sleeps again as it did, and nothing is left playing: a stream
	# that still plays at exit is a leaked AudioStreamPlaybackWAV (test_sfeer does
	# the same)
	Snd.set("_wakker", _wakker_terug)
	for p in Snd.get("_spelers"):
		(p as AudioStreamPlayer).stop()
		(p as AudioStreamPlayer).stream = null
	Snd._sfeer_stop()
	Ui.set("_scherm", _scherm_terug)
	if Ui.basis_maat() != _thema_terug.x or bool(Ui.get("_ruim")) != (_thema_terug.y == 1):
		Ui._bouw_thema(_thema_terug.x, _thema_terug.y == 1)
	State.s = _bewaard
	State.set("_start_keuze", _gekozen)
	var d := DirAccess.open("user://")
	if d != null and FileAccess.file_exists(State.PAD):
		d.remove(State.PAD.get_file())
	if _had_bestand:
		var f := FileAccess.open(State.PAD, FileAccess.WRITE)
		if f != null:
			f.store_string(_bestand)
			f.close()

func _intro() -> UiIntro:
	if _shell == null or not is_instance_valid(_shell):
		return null
	var i = _shell.get("intro")
	if i == null or not is_instance_valid(i):
		return null
	return i as UiIntro

func _intro_dieren() -> Array[String]:
	var uit: Array[String] = []
	for d in World.dieren():
		if str(d.id).begins_with(UiIntro.DIER):
			uit.append(str(d.id))
	return uit

func _intro_spots() -> Array[String]:
	var uit: Array[String] = []
	for id in Hits.lijst():
		var s = Hits.spot(id)
		if s != null and str(s.door) == UiIntro.EIGENAAR:
			uit.append(id)
	return uit

func _bel_knop() -> Control:
	var s = Hits.spot("bel")
	if s == null or not is_instance_valid(s.knoop) or not (s.knoop as Control).visible:
		return null
	return s.knoop as Control

## Page on with the real button, and give the page a frame to lay itself out.
func _verder(intro: UiIntro) -> void:
	intro.knop_verder().pressed.emit()
	await _frames(2)

func _naar_laatste(intro: UiIntro) -> void:
	while intro != null and not intro.is_dicht() and not intro.is_laatste():
		await _verder(intro)
	# the hotel's own buttons come back on the last page and are placed on the
	# next pass; the light follows the bell there
	await _frames(3)

## A finger on the glass, through the viewport's own input — so the overlay
## really is what catches it.
func _tik(p: Vector2) -> void:
	var neer := InputEventMouseButton.new()
	neer.button_index = MOUSE_BUTTON_LEFT
	neer.pressed = true
	neer.position = p
	neer.global_position = p
	_vp.push_input(neer)
	var op := InputEventMouseButton.new()
	op.button_index = MOUSE_BUTTON_LEFT
	op.pressed = false
	op.position = p
	op.global_position = p
	_vp.push_input(op)
	await _frames(2)

## The sentences the intro must show, in order, for a fresh waiting list.
func _zinnen_verwacht() -> Array[String]:
	var eerste := str((State.s["wachtlijst"] as Array)[0]["naam"])
	return [UiTekst.INTRO_WELKOM, UiTekst.INTRO_BAAS, UiTekst.INTRO_GASTEN,
		UiTekst.INTRO_WENS, UiTekst.INTRO_SOMMEN, UiTekst.intro_bel(eerste)]

# ------------------------------------------------------------------ wanneer

## No save at all: the fresh game starts under the intro — page 1, in the
## receptie, over everything, and the notice board does not open.
func test_een_vers_spel_begint_met_de_intro() -> void:
	_onthoud()
	await _start(Vector2i(1024, 768))
	var intro := _intro()
	waar(intro != null, "een vers spel krijgt de intro")
	if intro != null:
		waar(_shell.call("intro_loopt"), "de schil weet dat de intro loopt")
		gelijk(intro.stap(), 0, "hij begint bij de eerste pagina")
		gelijk(intro.aantal(), 6, "zes pagina's")
		gelijk(intro.zin(), UiTekst.INTRO_WELKOM, "de eerste zin, woordelijk")
		gelijk(intro.zin_label().text.replace("\n", " "), UiTekst.INTRO_WELKOM,
			"en zo staat hij op het kaartje")
		gelijk(intro.get_index(), _shell.get_child_count() - 1,
			"de intro ligt over alles heen: het laatste kind van de schil")
		gelijk(intro.size, Vector2(1024, 768), "en bedekt het hele scherm")
		gelijk(World.kamer_nu(), "receptie", "in de receptie")
		waar(not Hotel.bord_is_open(), "het prikbord gaat niet open bij de start")
		waar(Ui.huidig_blad() == null, "er ligt geen blad onder de intro")
		gelijk(intro.knop_verder().text, UiTekst.INTRO_VERDER, "Verder ▸ woordelijk")
		gelijk(intro.knop_overslaan().text, UiTekst.INTRO_OVERSLAAN, "Overslaan ▸▸ woordelijk")
		gelijk(Hits.voorrang_van(), UiIntro.EIGENAAR,
			"de knoppen van het hotel wijken voor het verhaal")
		# a tap anywhere on the glass turns the page — through the real input
		await _tik(Vector2(100, 200))
		gelijk(intro.stap(), 1, "een tik ergens op het scherm is de volgende pagina")
		gelijk(intro.zin(), UiTekst.INTRO_BAAS, "de tweede zin")
	await _af()

## A child who comes back is never held up: `Verder spelen` has no intro — and
## as long as the start sheet asks, there is none either.
func test_verder_spelen_houdt_niemand_op() -> void:
	_onthoud()
	await _start(Vector2i(1024, 768), true)
	waar(_intro() == null, "onder het startblad loopt geen intro")
	var blad: UiBlad = _shell.get_node_or_null("Bladlaag/Blad")
	waar(blad != null, "het startblad staat er")
	var verder: Button = _shell.get_node_or_null("Bladlaag/Blad/Midden/Blad/Rol/Kolom/Knoppen/Kverder")
	waar(verder != null, "met Verder spelen")
	if verder != null:
		verder.pressed.emit()
		await _frames(3)
		gelijk(int(State.s["dag"]), 3, "de bewaarde dag is terug")
		waar(_intro() == null, "Verder spelen toont geen intro")
		waar(_shell.get_node_or_null("Intro") == null, "ook niet als knoop in de schil")
		gelijk(_boom().get_nodes_in_group(UiIntro.GROEP).size(), 0, "en nergens anders")
		waar(Hits.voorrang_van() != UiIntro.EIGENAAR, "de knoppen van het hotel staan er")
	await _af()

## `Nieuw spel` IS a fresh game: the intro comes after it.
func test_nieuw_spel_krijgt_de_intro() -> void:
	_onthoud()
	await _start(Vector2i(1024, 768), true)
	var nieuw: Button = _shell.get_node_or_null("Bladlaag/Blad/Midden/Blad/Rol/Kolom/Knoppen/Knieuw")
	waar(nieuw != null, "het startblad heeft Nieuw spel")
	if nieuw != null:
		nieuw.pressed.emit()
		await _frames(3)
		var intro := _intro()
		waar(intro != null, "Nieuw spel begint met de intro")
		if intro != null:
			gelijk(intro.stap(), 0, "bij de eerste pagina")
			gelijk(int(State.s["dag"]), 1, "in een vers hotel")
			waar(not Hotel.bord_is_open(), "zonder prikbord")
	await _af()

# ------------------------------------------------------------------ overslaan

## `Overslaan ▸▸` ends it at once, on any page, and the hotel is playable: no
## animal, no bubble and no priority of the intro stays behind.
func test_overslaan_sluit_meteen_en_ruimt_op() -> void:
	_onthoud()
	await _start(Vector2i(1024, 768))
	var intro := _intro()
	waar(intro != null, "de intro staat er")
	if intro != null:
		# into the middle of it: guests in the room, bubbles over them
		await _verder(intro)
		await _verder(intro)
		await _verder(intro)
		await _boom().create_timer(0.7).timeout
		waar(_intro_dieren().size() == 3, "drie gasten van de intro staan in de receptie")
		waar(_intro_spots().size() == 3, "met elk een wenswolkje")
		var hoe := [""]
		intro.klaar.connect(func(h: String) -> void: hoe[0] = h)
		intro.knop_overslaan().pressed.emit()
		gelijk(hoe[0], "overslaan", "Overslaan sluit, met die reden")
		waar(intro.is_dicht(), "de intro is dicht")
		waar(not _shell.call("intro_loopt"), "de schil weet het ook")
		gelijk(intro.mouse_filter, Control.MOUSE_FILTER_IGNORE, "en vangt geen tik meer")
		gelijk(_intro_dieren().size(), 0, "geen dier van de intro blijft achter")
		gelijk(_intro_spots().size(), 0, "geen wolkje van de intro blijft achter")
		gelijk(Hits.voorrang_van(), "", "de knoppen van het hotel zijn terug")
		await _frames(3)
		waar(not is_instance_valid(intro), "de intro is weg uit de boom")
		var bel := _bel_knop()
		waar(bel != null, "de bel staat klaar")
		if bel != null:
			(bel as BaseButton).pressed.emit()
			await _frames(2)
			waar(State.s["nieuweGast"] != null, "en de bel brengt een gast")
			if State.s["nieuweGast"] != null:
				gelijk(str(State.s["nieuweGast"]["naam"]), "Boef", "Boef, de eerste van de lijst")
	await _af()

## A double tap is one page, not two: a fresh page ignores taps for a moment.
func test_een_dubbele_tik_slaat_geen_pagina_over() -> void:
	_onthoud()
	await _start(Vector2i(1024, 768))
	var intro := _intro()
	if intro != null:
		intro.drempel_s = UiIntro.DREMPEL
		await _boom().create_timer(UiIntro.DREMPEL + 0.1).timeout
		intro.tik_op(Vector2(80, 80))
		intro.tik_op(Vector2(80, 80))
		gelijk(intro.stap(), 1, "twee tikken vlak na elkaar: één pagina verder")
		intro.knop_overslaan().pressed.emit()
		waar(not intro.is_dicht(), "ook Overslaan wacht even op een verse pagina")
		await _boom().create_timer(UiIntro.DREMPEL + 0.1).timeout
		intro.tik_op(Vector2(80, 80))
		gelijk(intro.stap(), 2, "daarna gaat een tik weer verder")
	else:
		fout("geen intro")
	await _af()

# ------------------------------------------------------------------ het verhaal

## The six pages in order, what the world does on them, and the end: the last
## page lights the bell in the receptie, a tap in the light rings the REAL bell
## and the intro is gone; the guest it named is the one who comes.
func test_de_intro_eindigt_bij_de_bel() -> void:
	_onthoud()
	await _start(Vector2i(1536, 760))
	var intro := _intro()
	waar(intro != null, "de intro staat er")
	if intro == null:
		await _af()
		return
	var zinnen := _zinnen_verwacht()
	gelijk(intro.zinnen(), zinnen, "de zes zinnen, woordelijk en op volgorde")
	gelijk(zinnen[5], "🔔 Druk op de bel voor Boef!", "de laatste noemt de gast die de bel brengt")
	for i in 3:
		gelijk(intro.zin(), zinnen[i], "pagina %d" % (i + 1))
		await _verder(intro)
	# page 4: the three guests of the waiting list, each with its wish
	gelijk(intro.zin(), zinnen[3], "pagina 4")
	await _boom().create_timer(0.7).timeout
	var namen: Array[String] = []
	for g in (State.s["wachtlijst"] as Array).slice(0, 3):
		namen.append(UiIntro.DIER + str(g["id"]))
	gelijk(_intro_dieren(), namen, "Boef, Muis en Wolkje, de eerste drie van de lijst")
	for i in 3:
		var s = Hits.spot("%swens_%d" % [UiIntro.DIER, i])
		waar(s != null, "wolkje %d staat er" % i)
		if s != null:
			var w := s.knoop as UiWolk
			waar(w != null and not w.icoon_label.text.is_empty() and not w.zeg_label.text.is_empty(),
				"wolkje %d: pictogram en woord in één wolkje" % i)
	await _verder(intro)
	gelijk(intro.zin(), zinnen[4], "pagina 5")
	for i in 3:
		var s = Hits.spot("%swens_%d" % [UiIntro.DIER, i])
		waar(s != null and str(s.klas).contains("goed")
			and (s.knoop as UiWolk).zeg_label.text.ends_with("✓"),
			"wens %d is vervuld: munt-groen met ✓" % i)
	await _naar_laatste(intro)
	gelijk(intro.zin(), zinnen[5], "pagina 6")
	waar(intro.is_laatste(), "de laatste pagina")
	gelijk(World.kamer_nu(), "receptie", "in de receptie")
	waar(not intro.knop_verder().visible, "zonder Verder: de bel is hier de knop")
	waar(intro.knop_overslaan().is_visible_in_tree(), "Overslaan staat er nog")
	gelijk(Hits.voorrang_van(), "", "het hotel heeft zijn knoppen terug")
	var bel := _bel_knop()
	waar(bel != null, "de bel staat op het scherm")
	var gat := intro.gat()
	waar(gat.size.x > 0.0, "de laatste pagina zet de bel in het licht")
	if bel != null:
		var br := bel.get_global_rect()
		waar(gat.has_point(br.get_center()), "het licht staat op de bel (%s in %s)" % [str(br), str(gat)])
		waar(not intro.kaart_rect().intersects(gat), "het kaartje dekt de bel niet af")
		gelijk(_intro_spots().size(), 0, "de wolkjes van de intro zijn weg")
		var hoe := [""]
		intro.klaar.connect(func(h: String) -> void: hoe[0] = h)
		await _tik(gat.get_center())
		gelijk(hoe[0], "bel", "een tik in het licht is een tik op de bel")
		# Never call into the intro after it closed: it frees itself, and without
		# a debugger GDScript does not check for a freed instance — a method call
		# on it is a use-after-free (this line crashed the runner with signal 11
		# while it still read `intro.is_dicht()`).
		waar(not is_instance_valid(intro), "en dan is de intro weg")
		waar(not _shell.call("intro_loopt"), "de schil weet het")
		waar(State.s["nieuweGast"] != null, "de echte bel ging: er staat een gast aan de balie")
		if State.s["nieuweGast"] != null:
			gelijk(str(State.s["nieuweGast"]["naam"]), "Boef", "de gast die de zin noemde")
		waar(State.s["checkin"] != null, "en het inchecken begint")
		gelijk(_intro_dieren().size(), 0, "de dieren van de intro zijn weg")
	await _af()

## A tap beside the light on the last page ends the intro without ringing:
## then the child rings itself, the bell is right there.
func test_een_tik_naast_de_bel_sluit_zonder_te_bellen() -> void:
	_onthoud()
	await _start(Vector2i(1024, 768))
	var intro := _intro()
	if intro == null:
		fout("geen intro")
		await _af()
		return
	await _naar_laatste(intro)
	var gat := intro.gat()
	var ver := Vector2(8, 8) if gat.get_center().distance_to(Vector2(8, 8)) > gat.size.x else Vector2(1016, 700)
	var hoe := [""]
	intro.klaar.connect(func(h: String) -> void: hoe[0] = h)
	await _tik(ver)
	gelijk(hoe[0], "tik", "een tik naast het licht sluit")
	waar(State.s["nieuweGast"] == null, "zonder te bellen")
	await _frames(2)
	waar(_bel_knop() != null, "de bel wacht op het kind")
	await _af()

# ------------------------------------------------------------------ de regels

## HOTEL.md §9 on every sentence the intro can show — also the last one with
## every name the pool has: one sentence, pictogram in front on the same card,
## at most 8 words (the pictogram counts, as in `Ui.keur_regel`) and 40
## characters, and every glyph in the bundled font subset.
func test_de_zinnen_houden_zich_aan_hotel_9() -> void:
	var zinnen: Array[String] = [UiTekst.INTRO_WELKOM, UiTekst.INTRO_BAAS,
		UiTekst.INTRO_GASTEN, UiTekst.INTRO_WENS, UiTekst.INTRO_SOMMEN, UiTekst.INTRO_BEL_LEEG]
	for g in State.gasten_pool():
		zinnen.append(UiTekst.intro_bel(str(g["naam"])))
	gelijk(UiTekst.intro_bel(""), UiTekst.INTRO_BEL_LEEG, "zonder naam: de zin zonder naam")
	for zin in zinnen:
		waar(Ui.keur_regel("intro", zin), "%s: hooguit 8 woorden en 40 tekens" % zin)
		waar(zin.length() <= 40, "%s: %d tekens" % [zin, zin.length()])
		var eerste := zin.split(" ", false)[0]
		waar(eerste.unicode_at(0) >= 0x2000, "%s: het pictogram staat vooraan" % zin)
		gelijk(Ui.mist_tekens(zin).size(), 0, "%s: elk teken staat in de fontsubset %s" % [zin, str(Ui.mist_tekens(zin))])
		gelijk(zin.count("."), 1 if zin.ends_with(".") else 0, "%s: één zin" % zin)
	for knop in [UiTekst.INTRO_VERDER, UiTekst.INTRO_OVERSLAAN]:
		gelijk(Ui.mist_tekens(knop).size(), 0, "%s: elk teken staat in de fontsubset" % knop)
		waar(knop.contains("▸"), "%s: een plaatje naast het woord" % knop)

## The four screens of the brief, every page: the card and its buttons on the
## screen, every button 48 × 48 or more, the sentence on at most two lines and
## no letter under 12 px; on the last page the light is on the bell, the card
## keeps off it and the arrow stays on the screen.
func test_de_intro_past_op_vier_schermen() -> void:
	_onthoud()
	for maat in SCHERMEN:
		await _start(maat)
		var intro := _intro()
		waar(intro != null, "%s: de intro staat er" % str(maat))
		if intro == null:
			await _weg()
			continue
		var scherm := Rect2(Vector2.ZERO, Vector2(maat))
		for pagina in intro.aantal():
			var wat := "%s pagina %d" % [str(maat), pagina + 1]
			var kaart := intro.kaart_rect()
			waar(scherm.encloses(kaart), "%s: het kaartje staat in beeld (%s)" % [wat, str(kaart)])
			for knop in [intro.knop_verder(), intro.knop_overslaan()]:
				var b := knop as Button
				if not b.is_visible_in_tree():
					continue
				var r := b.get_global_rect()
				waar(r.size.x >= 48.0 and r.size.y >= 48.0, "%s: %s is een tikdoel (%s)" % [wat, b.text, str(r)])
				waar(scherm.encloses(r), "%s: %s is te bereiken (%s)" % [wat, b.text, str(r)])
			var zin := intro.zin_label()
			waar(zin.get_line_count() <= 2, "%s: hooguit twee regels (%d)" % [wat, zin.get_line_count()])
			for regel in zin.text.split("\n"):
				waar(regel.length() <= 40, "%s: hooguit 40 tekens per regel" % wat)
			waar(zin.get_theme_font_size("font_size") >= 20, "%s: de zin is groot" % wat)
			var klein: Array[String] = []
			_letters(intro, klein)
			gelijk(klein.size(), 0, "%s: geen letter onder de 12 px %s" % [wat, str(klein)])
			if intro.is_laatste():
				await _frames(3)
				var gat := intro.gat()
				var bel := _bel_knop()
				waar(bel != null and gat.has_point(bel.get_global_rect().get_center()),
					"%s: het licht staat op de bel" % wat)
				waar(not intro.kaart_rect().intersects(gat), "%s: het kaartje dekt de bel niet" % wat)
				var v: Vector2 = intro.get("_pijl_richting")
				var punt := gat.get_center() + v * (gat.size.x * 0.5 + 10.0)
				var staart := punt + v * 70.0
				waar(scherm.encloses(Rect2(punt, Vector2.ZERO).expand(staart)),
					"%s: de pijl staat in beeld" % wat)
			else:
				await _verder(intro)
		await _weg()
	await _af()

func _letters(k: Node, uit: Array[String]) -> void:
	if (k is Label or k is Button) and (k as Control).is_visible_in_tree():
		var m: int = (k as Control).get_theme_font_size("font_size")
		if m < UiThema.VLOER and not str(k.get("text")).is_empty():
			uit.append("%s=%d" % [k.name, m])
	for kind in k.get_children():
		_letters(kind, uit)

# ------------------------------------------------------------------ rust

## Reduced motion: the same six pages as still pictures.  The guests are PUT
## where they would have walked to and hold still, nothing sparkles, the bell's
## light does not pulse, and on the last page they are gone at once.
func test_rustmodus_zelfde_paginas_zonder_beweging() -> void:
	_onthoud()
	Ui.zet_rust_modus(true)
	# counted BEFORE the boot, so the first page's sparkles are counted too
	var deeltjes := World.deeltjes().size()
	await _start(Vector2i(1024, 768))
	var intro := _intro()
	waar(intro != null, "ook met rustmodus is er een intro")
	if intro == null:
		await _af()
		return
	gelijk(intro.zinnen(), _zinnen_verwacht(), "dezelfde zes pagina's")
	await _verder(intro)
	await _verder(intro)
	# page 3: everybody is there at once, on the spot, not walking
	var ids := _intro_dieren()
	gelijk(ids.size(), 3, "de drie gasten staan er meteen")
	for i in ids.size():
		var d = World.dier(ids[i])
		var p := intro.plek_van(i)
		waar(d != null and is_equal_approx(float(d.x), p.x) and is_equal_approx(float(d.z), p.y),
			"%s staat op zijn plek, niet onderweg" % ids[i])
		waar(d != null and str(d.staat) != "loop", "%s loopt niet" % ids[i])
	waar(not intro.beweegt(), "niets beweegt")
	await _verder(intro)
	gelijk(_intro_spots().size(), 3, "de wolkjes staan er meteen, alle drie")
	await _boom().create_timer(0.3).timeout
	for id in ids:
		var d = World.dier(id)
		var p := intro.plek_van(ids.find(id))
		waar(d != null and is_equal_approx(float(d.x), p.x) and is_equal_approx(float(d.z), p.y),
			"%s is blijven staan" % id)
	await _verder(intro)
	await _naar_laatste(intro)
	gelijk(_intro_dieren().size(), 0, "op de laatste pagina zijn ze meteen weg, niemand loopt naar de deur")
	waar(intro.gat().size.x > 0.0, "de bel staat in het licht")
	waar(not intro.beweegt(), "en het licht staat stil")
	# particles of earlier tests may still be dying out; not ONE may be added
	waar(World.deeltjes().size() <= deeltjes, "geen enkel nieuw sterretje (%d, eerst %d)"
		% [World.deeltjes().size(), deeltjes])
	await _af()

## And without reduced motion it really moves — the counterpart that makes the
## test above mean something.
func test_zonder_rustmodus_beweegt_het_wel() -> void:
	_onthoud()
	Ui.zet_rust_modus(false)
	await _start(Vector2i(1024, 768))
	var intro := _intro()
	if intro == null:
		fout("geen intro")
		await _af()
		return
	await _frames(2)
	waar(World.deeltjes().size() > 0, "de eerste pagina fonkelt")
	await _verder(intro)
	await _verder(intro)
	await _frames(2)
	var loopt := false
	for id in _intro_dieren():
		var d = World.dier(id)
		# "komt": each kind's own arrival through the front door
		if d != null and str(d.staat) in ["loop", "komt"]:
			loopt = true
	waar(loopt, "de eerste gast loopt naar binnen")
	waar(intro.beweegt(), "en dat telt als beweging")
	await _naar_laatste(intro)
	waar(intro.beweegt(), "het licht op de bel klopt")
	await _af()

## A second intro over a running one (the shell starts one again) takes the
## stage whole: the old one tidies up at once and, freed a frame later, does not
## take the new one's priority or animals with it — they share owner and ids.
func test_een_nieuwe_intro_houdt_zijn_podium() -> void:
	_onthoud()
	await _start(Vector2i(1024, 768))
	var oud := _intro()
	if oud == null:
		fout("geen intro")
		await _af()
		return
	await _verder(oud)
	await _verder(oud)
	await _verder(oud)
	_shell.call("_intro_start")
	var nieuw := _intro()
	waar(nieuw != null and nieuw != oud, "er staat een nieuwe intro")
	if nieuw != null:
		nieuw.drempel_s = 0.0
		await _frames(3)
		waar(not is_instance_valid(oud), "de oude is weg")
		gelijk(nieuw.stap(), 0, "de nieuwe begint bij de eerste pagina")
		gelijk(Hits.voorrang_van(), UiIntro.EIGENAAR, "en houdt het podium")
		await _verder(nieuw)
		await _verder(nieuw)
		await _verder(nieuw)
		gelijk(_intro_dieren().size(), 3, "met zijn eigen drie gasten")
	await _af()

## A shell torn down with the intro in the middle (a reload, a test) leaves no
## animal, bubble or priority behind in the autoloads for whoever comes next.
func test_de_intro_ruimt_op_als_de_schil_weggaat() -> void:
	_onthoud()
	await _start(Vector2i(1024, 768))
	var intro := _intro()
	if intro != null:
		await _verder(intro)
		await _verder(intro)
		await _verder(intro)
		await _boom().create_timer(0.7).timeout
		waar(_intro_dieren().size() > 0 and _intro_spots().size() > 0, "midden in het verhaal")
	_vp.queue_free()
	_vp = null
	_shell = null
	await _frames(2)
	gelijk(_intro_dieren().size(), 0, "geen dier van de intro in de wereld")
	gelijk(_intro_spots().size(), 0, "geen wolkje van de intro in de knoppenlaag")
	waar(Hits.voorrang_van() != UiIntro.EIGENAAR, "de intro heeft geen voorrang meer")
	await _af()
