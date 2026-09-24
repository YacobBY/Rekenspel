extends Proef
## The welcome of a fresh game (`ui/intro.gd`, world.md §6.2; owner 2026-09-24:
## "Ik wil ook geen intro waar je 5x door moet klikken. Maakt het veel korter
## en zonder tutorial dat lukt de kinderen zelf wel").
##
## What is proven here, each on the real shell (`scenes/main.tscn`) with its
## real `_begin()`: one welcome card comes on a fresh game (no save, or `Nieuw
## spel`) and never after `Verder spelen`; it has no buttons and no pages; it
## goes by itself, or at a tap; after it the hotel is the child's with the bell
## pulsing; its sentence keeps HOTEL.md §9 on the four screens of the brief;
## and with reduced motion it stands still.

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
	# a card the test looks at never goes by itself in the meantime
	UiIntro.duur_standaard = 600.0
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
	UiIntro.duur_standaard = UiIntro.DUUR
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

func _bel_knop() -> Control:
	var s = Hits.spot("bel")
	if s == null or not is_instance_valid(s.knoop) or not (s.knoop as Control).visible:
		return null
	return s.knoop as Control

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

## Wait (real time, as the card counts) until it is gone or `s` has passed.
func _wacht_tot_weg(s: float) -> void:
	var eind := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < eind and _intro() != null:
		await _frames(1)
	await _frames(2)

func _knoppen_in(k: Node, uit: Array[Node]) -> void:
	for c in k.get_children():
		if c is BaseButton:
			uit.append(c)
		_knoppen_in(c, uit)

# ------------------------------------------------------------------ wanneer

## No save at all: the fresh game starts with ONE welcome card — no pages, no
## buttons, over everything, in the receptie, and the board stays shut.
func test_een_vers_spel_begint_met_het_welkom() -> void:
	_onthoud()
	await _start(Vector2i(1024, 768))
	var intro := _intro()
	waar(intro != null, "een vers spel krijgt het welkom")
	if intro != null:
		waar(_shell.call("intro_loopt"), "de schil weet dat het loopt")
		gelijk(intro.aantal(), 1, "één kaartje, geen pagina's")
		gelijk(intro.zin(), UiTekst.INTRO_WELKOM, "de zin, woordelijk")
		gelijk(intro.zin_label().text.replace("\n", " "), UiTekst.INTRO_WELKOM,
			"en zo staat hij op het kaartje")
		var knoppen: Array[Node] = []
		_knoppen_in(intro, knoppen)
		gelijk(knoppen.size(), 0, "geen knop om door te klikken")
		gelijk(intro.get_index(), _shell.get_child_count() - 1,
			"het ligt over alles heen: het laatste kind van de schil")
		gelijk(World.kamer_nu(), "receptie", "in de receptie")
		waar(not Hotel.bord_is_open(), "het prikbord gaat niet open bij de start")
		waar(Ui.huidig_blad() == null, "er ligt geen blad onder")
		gelijk(Hits.voorrang_van(), UiIntro.EIGENAAR,
			"de knoppen van het hotel staan zolang niet op het kaartje")
	await _af()

## It goes by itself: no tap needed, and after it the hotel is the child's —
## the bell pulses, nothing of the intro stays behind.
func test_het_welkom_gaat_vanzelf_weg() -> void:
	_onthoud()
	UiIntro.duur_standaard = 0.4
	await _start(Vector2i(1024, 768))
	var hoe := [""]
	var intro := _intro()
	if intro != null:
		intro.klaar.connect(func(h: String) -> void: hoe[0] = h)
	await _wacht_tot_weg(5.0)
	waar(_intro() == null, "het kaartje is weg zonder dat er getikt is")
	if intro != null:
		gelijk(hoe[0], "vanzelf", "vanzelf, niet door een tik")
	gelijk(_boom().get_nodes_in_group(UiIntro.GROEP).size(), 0, "nergens meer een intro")
	waar(Hits.voorrang_van() != UiIntro.EIGENAAR, "de knoppen van het hotel zijn terug")
	Hits.plaats()
	var bel := _bel_knop()
	waar(bel != null, "de bel staat in beeld")
	if bel != null and bel.has_method("pulseert"):
		waar(bool(bel.call("pulseert")), "en klopt: dat is de enige wenk")
	waar(not Hotel.bord_is_open(), "het prikbord blijft dicht")
	await _af()

## A tap ends it at once — but not the tap that started the game.
func test_een_tik_sluit_het_welkom() -> void:
	_onthoud()
	await _start(Vector2i(1024, 768))
	var intro := _intro()
	waar(intro != null, "het welkom staat er")
	if intro != null:
		intro.drempel_s = 600.0
		await _tik(Vector2(500, 300))
		waar(not intro.is_dicht(), "een tik meteen na de start telt niet")
		intro.drempel_s = 0.0
		var hoe := [""]
		intro.klaar.connect(func(h: String) -> void: hoe[0] = h)
		await _tik(Vector2(500, 300))
		# the card frees itself the moment it closes (headless: no fade), so
		# ask whether it is still there before asking it anything
		waar(not is_instance_valid(intro) or intro.is_dicht(), "een tik ergens op het scherm sluit het")
		gelijk(hoe[0], "tik", "door de tik")
		await _frames(2)
		waar(_intro() == null, "en de schil laat het los")
	await _af()

## A child who comes back is never held up: `Verder spelen` has no welcome.
func test_verder_spelen_houdt_niemand_op() -> void:
	_onthoud()
	await _start(Vector2i(1024, 768), true)
	waar(_intro() == null, "onder het startblad loopt geen welkom")
	var verder: Button = _shell.get_node_or_null("Bladlaag/Blad/Midden/Blad/Rol/Kolom/Knoppen/Kverder")
	waar(verder != null, "het startblad heeft Verder spelen")
	if verder != null:
		verder.pressed.emit()
		await _frames(3)
		gelijk(int(State.s["dag"]), 3, "de bewaarde dag is terug")
		waar(_intro() == null, "Verder spelen toont geen welkom")
		gelijk(_boom().get_nodes_in_group(UiIntro.GROEP).size(), 0, "en nergens anders")
	await _af()

## `Nieuw spel` IS a fresh game: the welcome comes after it.
func test_nieuw_spel_krijgt_het_welkom() -> void:
	_onthoud()
	await _start(Vector2i(1024, 768), true)
	var nieuw: Button = _shell.get_node_or_null("Bladlaag/Blad/Midden/Blad/Rol/Kolom/Knoppen/Knieuw")
	waar(nieuw != null, "het startblad heeft Nieuw spel")
	if nieuw != null:
		nieuw.pressed.emit()
		await _frames(3)
		var intro := _intro()
		waar(intro != null, "Nieuw spel begint met het welkom")
		if intro != null:
			gelijk(int(State.s["dag"]), 1, "in een vers hotel")
			waar(not Hotel.bord_is_open(), "zonder prikbord")
	await _af()

# ------------------------------------------------------------------ de zin

## HOTEL.md §9: one sentence, pictogram first, at most 8 words and 40
## characters, every glyph in the bundled subset.
func test_de_zin_houdt_zich_aan_hotel_9() -> void:
	var zin := UiTekst.INTRO_WELKOM
	waar(Ui.keur_regel("intro", zin), "%s: hooguit 8 woorden en 40 tekens" % zin)
	waar(zin.length() <= 40, "%s: %d tekens" % [zin, zin.length()])
	waar(zin.split(" ", false)[0].unicode_at(0) >= 0x2000, "het pictogram staat vooraan")
	gelijk(Ui.mist_tekens(zin).size(), 0, "elk teken staat in de fontsubset %s" % str(Ui.mist_tekens(zin)))
	# the tutorial of 2026-09-23 is gone
	var k: Dictionary = (load("res://ui/teksten.gd") as GDScript).get_script_constant_map()
	for weg in ["INTRO_BAAS", "INTRO_GASTEN", "INTRO_WENS", "INTRO_SOMMEN", "INTRO_VERDER",
			"INTRO_OVERSLAAN", "INTRO_BEL_LEEG"]:
		waar(not k.has(weg), "%s bestaat niet meer" % weg)

## The four screens of the brief: the card on the screen, the sentence big and
## on at most two lines, no letter under 12 px.
func test_het_welkom_past_op_vier_schermen() -> void:
	_onthoud()
	for maat in SCHERMEN:
		await _start(maat)
		var intro := _intro()
		waar(intro != null, "%s: het welkom staat er" % str(maat))
		if intro != null:
			var scherm := Rect2(Vector2.ZERO, Vector2(maat))
			var kaart := intro.kaart_rect()
			waar(kaart.size.x > 0.0 and scherm.encloses(kaart),
				"%s: het kaartje staat in beeld (%s)" % [str(maat), str(kaart)])
			var zin := intro.zin_label()
			waar(zin.get_line_count() <= 2, "%s: hooguit twee regels (%d)" % [str(maat), zin.get_line_count()])
			waar(zin.get_theme_font_size("font_size") >= 20, "%s: de zin is groot" % str(maat))
		await _weg()
	await _af()

## Reduced motion: the same card, standing still (no pop-in), and it still goes.
func test_rustmodus_staat_stil() -> void:
	_onthoud()
	Ui.zet_rust_modus(true)
	UiIntro.duur_standaard = 0.4
	await _start(Vector2i(1024, 768))
	var intro := _intro()
	waar(intro != null, "het welkom staat er, ook in rustmodus")
	if intro != null:
		var kaart := intro.get_node("Kaart") as Control
		gelijk(kaart.scale, Vector2.ONE, "geen opspringend kaartje")
		gelijk(kaart.modulate.a, 1.0, "geen invloeien")
	await _wacht_tot_weg(5.0)
	waar(_intro() == null, "en het gaat ook in rustmodus vanzelf weg")
	await _af()

## A shell that goes while the card is up leaves no intro behind.
func test_het_welkom_ruimt_op_als_de_schil_weggaat() -> void:
	_onthoud()
	await _start(Vector2i(1024, 768))
	waar(_intro() != null, "het welkom staat er")
	_vp.queue_free()
	_vp = null
	_shell = null
	await _frames(2)
	gelijk(_boom().get_nodes_in_group(UiIntro.GROEP).size(), 0, "geen intro meer in de boom")
	waar(Hits.voorrang_van() != UiIntro.EIGENAAR, "en geen voorrang meer")
	await _af()
