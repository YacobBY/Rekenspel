extends Proef
## The browser's back button (`ui/web.gd`, W2 2026-10-09; owner: "Het moet in
## browser werken ook op Android niet IOS specifiek").
##
## On Android the back button or back gesture, and in a desktop browser ⬅ or
## Alt+←, must act like the game's own `⬅ Terug` and never leave the app.  The
## browser half (a history entry of our own, `popstate`) needs a browser and is
## played by `tools/speel.js` (`terug` steps); the DECISION is GDScript and is
## proven here, headless, on the real shell (`scenes/main.tscn`) with its real
## `_begin()`: the welcome card goes as a tap makes it go; a sheet that a tap
## beside closes is closed; a sheet that must be answered stays — unless it has
## `⬅ Nee, terug`, which is pressed; a running game ends as with `⬅ Terug`;
## with nothing open nothing happens.  And outside the browser the shell has no
## UiWeb at all, so the desktop and the suite run exactly as before.

const MAAT := Vector2i(1024, 768)

var _vp: SubViewport = null
var _shell: Node = null
var _web: UiWeb = null
var _bewaard: Dictionary = {}
var _gekozen := false
var _bestand := ""            ## the save on disk before the test, verbatim
var _had_bestand := false
var _hotel_terug := 1
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
# The same boot and tidy-up as tests/test_intro.gd: the real shell, its real
# `_begin()`, and every autoload handed back as it was.

func _onthoud() -> void:
	UiIntro.duur_standaard = 600.0      # the welcome never goes by itself meanwhile
	_bewaard = State.s.duplicate(true)
	_gekozen = State.gestart()
	_had_bestand = FileAccess.file_exists(State.PAD)
	_bestand = FileAccess.get_file_as_string(State.PAD) if _had_bestand else ""
	_hotel_terug = State.hotel
	_scherm_terug = Ui.get("_scherm")
	_rust_terug = Ui.rust_modus()
	_thema_terug = Vector2i(Ui.basis_maat(), 1 if bool(Ui.get("_ruim")) else 0)
	_wakker_terug = Snd.ontgrendeld()

## Boot the shell.  `opslag`: a save of day 3 on disk first (the start sheet),
## otherwise no save at all (a fresh game under the welcome card).  The
## UiWeb the browser would get is hung on the shell by hand: headless there
## is no browser, so the shell itself makes none (see the first test).
func _start(opslag := false, maat := MAAT) -> void:
	var d := DirAccess.open("user://")
	if d != null and FileAccess.file_exists(State.PAD):
		d.remove(State.PAD.get_file())
	_wis_hotels()
	State.hotel = 1
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
	_web = UiWeb.new()
	_web.shell = _shell
	_shell.add_child(_web)

## A fresh game, the welcome tapped away: the hotel is the child's.
func _speelklaar(maat := MAAT) -> void:
	await _start(false, maat)
	var intro = _shell.get("intro")
	if intro != null and is_instance_valid(intro):
		(intro as UiIntro).sluit("tik")
	await _frames(3)

func _weg() -> void:
	Games.stop()
	Ui.blad_dicht()
	Hits.wis_alles()
	if _vp != null:
		_vp.queue_free()
		_vp = null
		_shell = null
		_web = null
		await _frames(2)
	Ui.registreer_lagen(null, null, null)
	Ui.registreer_wortels([])

func _af() -> void:
	await _weg()
	if Hits.voorrang_van() == UiIntro.EIGENAAR:
		Hits.voorrang("")
	UiIntro.duur_standaard = UiIntro.DUUR
	Ui.zet_rust_modus(_rust_terug)
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
	_wis_hotels()
	State.hotel = _hotel_terug
	var d := DirAccess.open("user://")
	if d != null and FileAccess.file_exists(State.PAD):
		d.remove(State.PAD.get_file())
	if _had_bestand:
		var f := FileAccess.open(State.PAD, FileAccess.WRITE)
		if f != null:
			f.store_string(_bestand)
			f.close()

func _wis_hotels() -> void:
	var d := DirAccess.open("user://")
	if d == null:
		return
	for n in range(2, State.HOTELS + 1):
		d.remove(State.pad_van(n).get_file())
	d.remove(State.PAD_KEUZE.get_file())

func _intro() -> UiIntro:
	if _shell == null or not is_instance_valid(_shell):
		return null
	var i = _shell.get("intro")
	if i == null or not is_instance_valid(i) or (i as UiIntro).is_dicht():
		return null
	return i as UiIntro

# ---------------------------------------------------------------- de tabel

## The whole decision, row by row: the topmost thing on the glass goes first,
## a sheet that must be answered is never closed by back, and with nothing
## open back does nothing (it never leaves the app).
func test_beslis_volgt_de_tabel() -> void:
	gelijk(UiWeb.beslis({}), "niets", "niets open: niets")
	gelijk(UiWeb.beslis({"spel": ""}), "niets", "geen spel: niets")
	gelijk(UiWeb.beslis({"spel": "wekker"}), "spel_terug", "een spel loopt: zoals ⬅ Terug")
	gelijk(UiWeb.beslis({"blad": true, "blad_sluitbaar": true}), "blad_dicht",
		"een blad dat een tik ernaast sluit: dicht")
	gelijk(UiWeb.beslis({"blad": true, "blad_sluitbaar": true, "blad_knop": "Kterug"}), "blad_dicht",
		"sluitbaar gaat voor zijn eigen knop (zoals de tik ernaast)")
	gelijk(UiWeb.beslis({"blad": true, "blad_knop": "Knee"}), "blad_knop",
		"een blad dat beantwoord moet worden maar ⬅ Nee, terug heeft: die knop")
	gelijk(UiWeb.beslis({"blad": true}), "niets", "het startblad moet beantwoord worden")
	gelijk(UiWeb.beslis({"blad": true, "spel": "meubels"}), "niets",
		"een blad dat niet dicht mag, ook niet tijdens een spel")
	gelijk(UiWeb.beslis({"blad": true, "blad_sluitbaar": true, "spel": "meubels"}), "blad_dicht",
		"eerst het blad, dan pas het spel")
	gelijk(UiWeb.beslis({"intro": true, "blad": true, "blad_sluitbaar": true, "spel": "x"}),
		"intro_weg", "het welkom ligt over alles heen en gaat als eerste")

## The insets come from the page as "left,top,right,bottom" in CSS px.
func test_randen_uit_de_pagina() -> void:
	gelijk(UiWeb.lees_randen("0,24,0,16"), Rect2(0, 24, 0, 16), "links, boven, rechts, onder")
	gelijk(UiWeb.lees_randen("44, 0, 44, 21"), Rect2(44, 0, 44, 21), "spaties mogen")
	gelijk(UiWeb.lees_randen(""), Rect2(), "niets: nul")
	gelijk(UiWeb.lees_randen("a,b"), Rect2(), "onleesbaar: nul")
	gelijk(UiWeb.lees_randen("-3,5"), Rect2(0, 5, 0, 0), "nooit negatief, wat ontbreekt is nul")
	gelijk(UiWeb.randen_tekst(Rect2(1, 2, 3, 4)), "1,2,3,4", "en terug als tekst")

## The page glue keeps the names `tools/speel.js`, the shell and the notes rely on.
func test_de_lijm_kent_de_afspraken() -> void:
	for stuk in ["window.dhWeb", "popstate", "pushState", "replaceState", "navigator.storage",
			"wakeLock", "safe-area-inset-bottom", "zetTerug", "stand:"]:
		waar(UiWeb.JS_LIJM.contains(stuk), "de lijm bevat %s" % stuk)
	waar(not UiWeb.JS_LIJM.contains("userAgent"), "en snuffelt niet aan de user agent")

# ------------------------------------------------------- buiten de browser

## Headless (and on a desktop build) the shell makes no UiWeb, and one hung on
## it by hand stays asleep: the margins are what they were.
func test_buiten_de_browser_doet_hij_niets() -> void:
	_onthoud()
	await _start(true)
	waar(_shell.get("web") == null, "de schil maakt buiten de browser geen UiWeb")
	var voor: Rect2 = _shell.call("_veilige_randen")
	_shell.set("web", _web)
	waar(not _web.actief, "zonder browser is de lijm er niet")
	gelijk(_web.randen(), Rect2(), "en kent hij geen randen")
	gelijk(_shell.call("_veilige_randen"), voor, "de schil houdt zijn eigen randen")
	_shell.set("web", null)
	await _af()

# ---------------------------------------------------------------- terug

## The welcome card of a fresh game goes at back, as it goes at a tap.
func test_terug_sluit_het_welkom() -> void:
	_onthoud()
	await _start()
	var intro := _intro()
	waar(intro != null, "een vers spel begint met het welkom")
	if intro != null:
		var hoe := [""]
		intro.klaar.connect(func(h: String) -> void: hoe[0] = h)
		gelijk(_web.terug(), "intro_weg", "terug neemt het welkom weg")
		await _frames(2)
		gelijk(hoe[0], "tik", "zoals een tik")
		waar(_intro() == null, "het welkom is weg")
		gelijk(Games.actief(), "", "en er is niets anders gebeurd")
	await _af()

## The start sheet must be answered before anything is saved (architecture.md
## §9): back leaves it where it is and chooses nothing.
func test_terug_laat_het_startblad_staan() -> void:
	_onthoud()
	await _start(true)
	var blad := Ui.huidig_blad()
	waar(blad != null and not blad.sluitbaar, "het startblad staat er en moet beantwoord worden")
	gelijk(_web.terug(), "niets", "terug doet niets")
	await _frames(2)
	waar(Ui.huidig_blad() == blad, "het startblad staat er nog")
	waar(not State.gestart(), "er is niets gekozen, dus niets bewaard")
	await _af()

## "Which hotel may go?" must be answered too, but it has `⬅ Nee, terug`:
## back presses exactly that — back to the hotels, nothing thrown away.
func test_terug_drukt_nee_terug() -> void:
	_onthoud()
	await _start(true)
	var startblad: UiStartblad = _shell.get("startblad")
	waar(startblad != null, "er is een startblad")
	if startblad != null:
		var weg := [false]
		startblad.vraag_weg(func(_n: int) -> void: weg[0] = true)
		await _frames(2)
		var vraag := Ui.huidig_blad()
		waar(vraag != null and not vraag.sluitbaar, "de vraag staat er en moet beantwoord worden")
		waar(UiWeb.blad_terug_knop(vraag) != null, "met ⬅ Nee, terug")
		gelijk(_web.terug(), "blad_knop", "terug drukt die knop")
		await _frames(2)
		waar(not weg[0], "er gaat geen hotel weg")
		var nu := Ui.huidig_blad()
		waar(nu != null and nu != vraag, "het startblad is terug")
		if nu != null:
			waar(nu.find_child("Khotel1", true, false) != null, "met de hotels erop")
	await _af()

## A sheet that a tap beside closes (the till) is closed by back; the hotel
## stays as it was.
func test_terug_sluit_een_blad() -> void:
	_onthoud()
	await _speelklaar()
	var kamer := World.kamer_nu()
	_shell.call("_kassa")
	await _frames(2)
	waar(Ui.huidig_blad() != null and Ui.huidig_blad().sluitbaar, "de kassa staat open")
	gelijk(_web.terug(), "blad_dicht", "terug sluit hem")
	await _frames(2)
	waar(Ui.huidig_blad() == null, "het blad is dicht")
	gelijk(World.kamer_nu(), kamer, "in dezelfde kamer")
	gelijk(_web.terug(), "niets", "nog een keer terug: er is niets meer open")
	await _af()

## A running game ends as with the game bar's `⬅ Terug`; the room bar comes
## back.  With a sheet over the game the sheet goes first.
func test_terug_verlaat_het_spel() -> void:
	_onthoud()
	await _speelklaar()
	waar(Games.start("_voorbeeld"), "het voorbeeldspel start")
	await _frames(3)
	var balk: UiSpelbalk = _shell.get("spelbalk")
	waar(balk != null and balk.visible, "de spelbalk met ⬅ Terug staat er")
	waar(_web.wakker_nodig(), "tijdens een spel blijft het scherm aan")
	_shell.call("_kassa")
	await _frames(2)
	gelijk(_web.terug(), "blad_dicht", "eerst gaat het blad dicht")
	await _frames(2)
	gelijk(Games.actief(), "_voorbeeld", "en het spel loopt nog")
	gelijk(_web.terug(), "spel_terug", "dan verlaat terug het spel")
	await _frames(3)
	gelijk(Games.actief(), "", "er loopt geen spel meer")
	waar(not _shell.get("spelbalk").visible, "de spelbalk is weg")
	waar((_shell.get("kamerbalk") as Control).visible, "de kamerbalk is terug")
	waar(not _web.wakker_nodig(), "het scherm mag weer uit")
	gelijk(_web.terug(), "niets", "en nog een keer terug doet niets")
	gelijk(_web.aantal_terug, 3, "drie keer terug geteld")
	await _af()

# ---------------------------------------------------------------- draaien

## A phone turned on its side and back (W2, found in the Android emulation):
## the shell lays itself out for the screen it has NOW.  The browser turns in
## two steps: the window is upright before the content scale follows, so for
## one pass the units are 915 x 2033 (aspect `expand`) and the shell lays out
## for that wide screen — whose chrome is 891 units wide.  Then the units
## become 412 x 915, but that chrome's minimum width held `Scherm` at 891, the
## shell measured 891 and kept the wide layout: the right half of the game was
## cut off.  `_op_venster` calls `_pas_shell` on a real window; here the test
## does, as the SubViewport has no window.
func test_draaien_laat_geen_brede_indeling_achter() -> void:
	_onthoud()
	await _speelklaar(Vector2i(915, 412))
	var scherm: Control = _shell.get("scherm")
	waar(bool(_shell.get("_compact")), "liggend op een telefoon: de compacte schil")
	for ronde in 2:
		_vp.size = Vector2i(915, 2033)      # the half-turned step
		await _frames(1)
		_shell.call("_pas_shell")
		await _frames(2)
		_vp.size = Vector2i(412, 915)
		await _frames(1)
		_shell.call("_pas_shell")
		await _frames(3)
		waar(scherm.size.x <= 412.5, "ronde %d staand: de schil is niet breder dan het scherm (%.0f)" % [ronde, scherm.size.x])
		waar(bool(_shell.get("_telefoon")), "ronde %d staand: de telefoonschil" % ronde)
		waar(not bool(_shell.get("_compact")), "ronde %d staand: niet meer compact" % ronde)
		_vp.size = Vector2i(915, 412)
		await _frames(1)
		_shell.call("_pas_shell")
		await _frames(3)
		waar(scherm.size.x <= 915.5 and scherm.size.y <= 412.5, "ronde %d liggend: past weer" % ronde)
		waar(bool(_shell.get("_compact")), "ronde %d liggend: weer compact" % ronde)
	await _af()
