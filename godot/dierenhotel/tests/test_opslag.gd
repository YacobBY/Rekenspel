extends Proef
## The hotels: three save slots on one tablet, the start sheet that shows them,
## and a hotel as a file for a parent (owner 2026-10-01: "En ik wil save files
## maken").
##
## Proven here: hotel 1 IS the old single save (same file, an old save comes
## back unchanged); a hotel round-trips in its own file and leaves the others
## alone; the choice survives a restart; the start sheet shows every hotel's
## numbers and continues the one tapped; a new hotel takes a free slot and,
## when all three are taken, never overwrites one without "which one?" AND
## "are you sure?"; `💾 Bewaar` → `📂 Open` gives the same hotel back, bytes in;
## a file that is not a hotel is refused and changes nothing at all; and the
## start sheet with its tiles and its two buttons fits on four screens.

## The four screens of the brief: iPad both ways, a phone both ways.
const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740),
	Vector2i(740, 360)]
const BLAD := "Bladlaag/Blad/Midden/Blad/Rol/Kolom/"

var _vp: SubViewport = null
var _shell: Node = null
var _bewaard: Dictionary = {}
var _gekozen := false
var _hotel_terug := 1
var _bestanden: Dictionary = {}     ## path -> text of every hotel file before the test
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

## Every hotel file, the choice and the autoloads a shell touches, once.
func _onthoud() -> void:
	UiIntro.duur_standaard = 600.0
	_bewaard = State.s.duplicate(true)
	_gekozen = State.gestart()
	_hotel_terug = State.hotel
	_bestanden.clear()
	for pad in _alle_paden():
		if FileAccess.file_exists(pad):
			_bestanden[pad] = FileAccess.get_file_as_string(pad)
	_scherm_terug = Ui.get("_scherm")
	_rust_terug = Ui.rust_modus()
	_thema_terug = Vector2i(Ui.basis_maat(), 1 if bool(Ui.get("_ruim")) else 0)
	_wakker_terug = Snd.ontgrendeld()
	_wis()

func _alle_paden() -> Array[String]:
	var uit: Array[String] = [State.PAD_KEUZE]
	for n in range(1, State.HOTELS + 1):
		uit.append(State.pad_van(n))
	return uit

## No hotel, no choice, no file a parent kept.
func _wis() -> void:
	var d := DirAccess.open("user://")
	if d != null:
		for pad in _alle_paden():
			d.remove(pad.get_file())
	var b := DirAccess.open(UiHotelbestand.MAP)
	if b != null:
		for naam in b.get_files():
			b.remove(naam)
	State.hotel = 1

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
	_wis()
	for pad in _bestanden.keys():
		var f := FileAccess.open(pad, FileAccess.WRITE)
		if f != null:
			f.store_string(_bestanden[pad])
			f.close()
	State.s = _bewaard
	State.set("_start_keuze", _gekozen)
	State.hotel = _hotel_terug

## A hotel of `dag` days with `sterren` stars and `gasten` guests in slot `n`,
## written as the game writes it.  The hotel in use stays what it was.
func _hotel(n: int, dag: int, sterren: int, gasten: int, munten := 0) -> void:
	var voor := State.hotel
	State.nieuw_spel()
	State.s["dag"] = dag
	State.s["sterren"] = sterren
	State.s["munten"] = munten
	var pool := State.gasten_pool()
	for i in gasten:
		var g: Dictionary = pool[i]
		g["kamer"] = "kamer1"
		g["waar"] = "kamer1"
		g["behoefte"] = "eten"
		(State.s["gasten"] as Array).append(g)
	State.hotel = n
	State.start_gekozen()
	State.hotel = voor
	State.nieuw_spel()

func _tekst(n: int) -> String:
	var pad := State.pad_van(n)
	return FileAccess.get_file_as_string(pad) if FileAccess.file_exists(pad) else ""

func _alle_teksten() -> Array[String]:
	var uit: Array[String] = []
	for pad in _alle_paden():
		uit.append(FileAccess.get_file_as_string(pad) if FileAccess.file_exists(pad) else "")
	return uit

## Boot the real shell at `maat`, with whatever hotels are on disk.
func _start(maat: Vector2i) -> void:
	_vp = SubViewport.new()
	_vp.size = maat
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_boom().root.add_child(_vp)
	_shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	_vp.add_child(_shell)
	await _frames(5)

func _weg() -> void:
	Hits.wis_alles()
	Ui.blad_dicht()
	if _vp != null:
		_vp.queue_free()
		_vp = null
		_shell = null
		await _frames(2)
	Ui.registreer_lagen(null, null, null)
	Ui.registreer_wortels([])

func _blad() -> UiBlad:
	return _shell.get_node_or_null("Bladlaag/Blad") as UiBlad

func _titel() -> String:
	var l := _shell.get_node_or_null(BLAD + "Titel") as Label
	return l.text if l != null else ""

func _hint() -> String:
	var l := _shell.get_node_or_null(BLAD + "Hint") as Label
	return l.text if l != null else ""

func _knop(pad: String) -> Button:
	return _shell.get_node_or_null(BLAD + pad) as Button

## Press a button of the sheet as a finger would (the signal, as the other
## shell tests do), then let the next sheet lay itself out.
func _druk(pad: String) -> bool:
	var k := _knop(pad)
	if k == null:
		fout("geen knop %s op het blad (titel %s)" % [pad, _titel()])
		return false
	k.pressed.emit()
	await _frames(3)
	return true

func _intro_loopt() -> bool:
	return _shell != null and bool(_shell.call("intro_loopt"))

# ------------------------------------------------------- de hotels in State

## Hotel 1 is the old single save: the same file, and a save written before
## the hotels existed comes back unchanged, with no choice remembered.
func test_hotel_1_is_de_oude_opslag() -> void:
	_onthoud()
	gelijk(State.pad_van(1), "user://dierenhotel.json", "hotel 1 is het oude bestand")
	gelijk(State.PAD, State.pad_van(1), "en State.PAD blijft dat")
	waar(State.pad_van(2) != State.pad_van(1) and State.pad_van(3) != State.pad_van(2),
		"hotel 2 en 3 hebben elk een eigen bestand")
	# an old save, written as the game wrote it before 2026-10-01
	var oud := State.standaard()
	oud["dag"] = 5
	oud["sterren"] = 8
	oud["munten"] = 11
	var tekst := JSON.stringify({"v": 1, "s": oud})
	var f := FileAccess.open(State.PAD, FileAccess.WRITE)
	f.store_string(tekst)
	f.close()
	gelijk(State.lees_keuze(), 1, "zonder onthouden keuze is het hotel 1")
	State.hotel = State.lees_keuze()
	State.s = State.standaard()
	waar(State.lees(), "de oude opslag wordt gelezen")
	gelijk(int(State.s["dag"]), 5, "dag 5")
	gelijk(int(State.s["sterren"]), 8, "8 sterren")
	gelijk(int(State.s["munten"]), 11, "11 munten")
	var h := State.samenvatting(1)
	waar(not bool(h["leeg"]), "hotel 1 staat op het startblad")
	gelijk(int(h["dag"]), 5, "met zijn dag")
	gelijk(State.vrij_hotel(), 2, "hotel 2 is het eerste vrije")
	gelijk(_tekst(1), tekst, "lezen veranderde het bestand niet")
	await _af()

## Hotel 2 in its own file, read back whole; hotel 1 is not touched by it.
func test_een_hotel_rondrit_raakt_hotel_1_niet() -> void:
	_onthoud()
	_hotel(1, 3, 2, 1)
	var een := _tekst(1)
	waar(not een.is_empty(), "hotel 1 staat er")
	State.kies_hotel(2)
	State.nieuw_spel()
	State.start_gekozen()
	State.s["dag"] = 6
	State.s["sterren"] = 4
	waar(State.bewaar(), "hotel 2 bewaard")
	waar(FileAccess.file_exists(State.pad_van(2)), "in zijn eigen bestand")
	gelijk(_tekst(1), een, "hotel 1 is byte voor byte hetzelfde")
	State.s = State.standaard()
	waar(State.lees(), "hotel 2 komt terug")
	gelijk(int(State.s["dag"]), 6, "met dag 6")
	gelijk(int(State.s["sterren"]), 4, "en 4 sterren")
	State.kies_hotel(1)
	waar(State.lees(), "hotel 1 komt terug")
	gelijk(int(State.s["dag"]), 3, "met zijn eigen dag")
	gelijk(_tekst(1), een, "en ook lezen liet het heel")
	await _af()

## Which hotel was played last survives a restart; nonsense means hotel 1.
func test_de_keuze_overleeft_een_herstart() -> void:
	_onthoud()
	State.kies_hotel(3)
	State.hotel = 1                          # a restart forgets the variable ...
	gelijk(State.lees_keuze(), 3, "... the file remembers hotel 3")
	State.kies_hotel(9)
	gelijk(State.hotel, State.HOTELS, "er zijn er maar drie")
	for kapot in ["{niet json", '{"hotel": "twee"}', "[2]", '{"hotel": {}}', ""]:
		var f := FileAccess.open(State.PAD_KEUZE, FileAccess.WRITE)
		f.store_string(kapot)
		f.close()
		gelijk(State.lees_keuze(), 1, "%s -> hotel 1" % kapot)
	await _af()

## What the start sheet is told of each hotel; a broken file is no hotel.
func test_de_samenvatting_van_elk_hotel() -> void:
	_onthoud()
	_hotel(1, 4, 5, 2, 12)
	_hotel(3, 9, 1, 0)
	var f := FileAccess.open(State.pad_van(2), FileAccess.WRITE)
	f.store_string('{"v": 1, "s": {"dag": "morgen"}}')
	f.close()
	var h := State.hotels()
	gelijk(h.size(), 3, "drie hotels")
	gelijk([int(h[0]["dag"]), int(h[0]["sterren"]), int(h[0]["gasten"]), int(h[0]["munten"])],
		[4, 5, 2, 12], "hotel 1: dag, sterren, gasten, munten")
	waar(bool(h[1]["leeg"]), "hotel 2: een kapot bestand is geen hotel")
	gelijk([int(h[2]["dag"]), int(h[2]["sterren"]), int(h[2]["gasten"])], [9, 1, 0], "hotel 3")
	gelijk(State.vrij_hotel(), 2, "het kapotte telt als vrij")
	_hotel(2, 1, 0, 0)
	gelijk(State.vrij_hotel(), 0, "alle drie bezet")
	await _af()

# ------------------------------------------------------------ het startblad

## The start sheet shows every hotel with its own numbers, the one played last
## standing out, an empty one as `➕ Nieuw hotel`, the parent's two below.
## Looking at it writes nothing.
func test_het_startblad_toont_de_hotels() -> void:
	_onthoud()
	_hotel(1, 4, 5, 2)
	_hotel(3, 9, 1, 0)
	State.kies_hotel(3)
	var voor := _alle_teksten()
	await _start(Vector2i(1024, 768))
	gelijk(_titel(), UiTekst.START_TERUG, "het startblad staat er")
	waar(not _intro_loopt(), "geen welkom onder het startblad")
	var t1 := _knop("Hotels/Khotel1")
	var t2 := _knop("Hotels/Khotel2")
	var t3 := _knop("Hotels/Khotel3")
	waar(t1 != null and t2 != null and t3 != null, "drie tegels")
	if t1 != null and t2 != null and t3 != null:
		gelijk((t1.get_node("Icoon") as Label).text, UiTekst.HOTEL_ICOON[0], "hotel 1 zijn dier")
		gelijk((t3.get_node("Icoon") as Label).text, UiTekst.HOTEL_ICOON[2], "hotel 3 zijn dier")
		gelijk((t1.get_node("Naam") as Label).text, "Hotel 1", "zijn naam")
		gelijk((t1.get_node("Cijfers") as Label).text, UiTekst.hotel_cijfers(4, 5, 2),
			"hotel 1: dag 4, 5 sterren, 2 gasten")
		gelijk((t3.get_node("Cijfers") as Label).text, UiTekst.hotel_cijfers(9, 1, 0),
			"hotel 3: dag 9, 1 ster, geen gasten")
		gelijk("%s %s" % [(t2.get_node("Icoon") as Label).text, (t2.get_node("Naam") as Label).text],
			UiTekst.HOTEL_NIEUW, "hotel 2 is leeg: ➕ Nieuw hotel")
		waar(t2.get_node_or_null("Cijfers") == null, "een leeg hotel heeft geen cijfers")
		var sb3 := t3.get_theme_stylebox("normal") as StyleBoxFlat
		var sb1 := t1.get_theme_stylebox("normal") as StyleBoxFlat
		gelijk(sb3.bg_color, UiThema.ZON, "het laatst gespeelde hotel springt eruit")
		waar(sb1.bg_color != sb3.bg_color, "de andere niet")
	waar(_knop("Knoppen/Knieuw") == null, "met een vrij hotel geen aparte Nieuw-knop")
	waar(_knop("Knoppen/Kbewaar") != null and _knop("Knoppen/Kopen") != null,
		"💾 Bewaar en 📂 Open voor de ouder")
	gelijk(_alle_teksten(), voor, "kijken schrijft niets")
	await _af()

## A tap on a hotel continues THAT hotel — no welcome, nothing else touched.
func test_een_tik_op_een_hotel_speelt_het_verder() -> void:
	_onthoud()
	_hotel(1, 4, 5, 2)
	_hotel(3, 9, 1, 0)
	var een := _tekst(1)
	await _start(Vector2i(1024, 768))
	if await _druk("Hotels/Khotel3"):
		gelijk(State.hotel, 3, "hotel 3 is in gebruik")
		gelijk(int(State.s["dag"]), 9, "met zijn dag")
		gelijk(State.lees_keuze(), 3, "en dat wordt onthouden")
		waar(State.gestart(), "vanaf nu wordt er bewaard")
		waar(not _intro_loopt(), "verder spelen heeft geen welkom")
		waar(_blad() == null, "het startblad is weg")
		gelijk(_tekst(1), een, "hotel 1 is niet aangeraakt")
	await _af()

## `➕ Nieuw hotel` on an empty tile: a fresh hotel THERE, with the welcome;
## the saved hotels are exactly as they were.
func test_een_nieuw_hotel_neemt_een_vrij_hotel() -> void:
	_onthoud()
	_hotel(1, 4, 5, 2)
	_hotel(3, 9, 1, 0)
	var een := _tekst(1)
	var drie := _tekst(3)
	await _start(Vector2i(1024, 768))
	if await _druk("Hotels/Khotel2"):
		gelijk(State.hotel, 2, "het nieuwe hotel is hotel 2")
		gelijk(int(State.s["dag"]), 1, "een vers hotel")
		waar(_intro_loopt(), "met het welkom")
		gelijk(int(State.samenvatting(2).get("dag", 0)), 1, "en het staat al op de tablet")
		gelijk(_tekst(1), een, "hotel 1 is heel")
		gelijk(_tekst(3), drie, "hotel 3 is heel")
	await _af()

## All three taken: `➕ Nieuw hotel` first asks which may go, then shows that
## one alone and asks again.  `⬅ Nee, terug` at the last step changes nothing;
## only `✅ Ja, weg ermee` replaces it.
func test_vol_vraagt_welk_hotel_en_dan_zeker() -> void:
	_onthoud()
	_hotel(1, 4, 5, 2)
	_hotel(2, 7, 3, 1)
	_hotel(3, 9, 1, 0)
	State.kies_hotel(1)
	var voor := _alle_teksten()
	await _start(Vector2i(1024, 768))
	waar(_knop("Knoppen/Knieuw") != null, "alle drie bezet: de knop ➕ Nieuw hotel")
	if not await _druk("Knoppen/Knieuw"):
		await _af()
		return
	gelijk(_titel(), UiTekst.HOTEL_WEG, "eerst: welk hotel mag weg?")
	waar(_knop("Hotels/Khotel1") != null and _knop("Hotels/Khotel3") != null, "met alle drie")
	gelijk(_alle_teksten(), voor, "nog niets weg")
	await _druk("Hotels/Khotel2")
	gelijk(_titel(), UiTekst.HOTEL_ZEKER, "dan: weet je het zeker?")
	waar(_knop("Hotels/Khotel2") != null and _knop("Hotels/Khotel1") == null,
		"met alleen dat hotel erop")
	if _knop("Hotels/Khotel2") != null:
		gelijk((_knop("Hotels/Khotel2").get_node("Cijfers") as Label).text,
			UiTekst.hotel_cijfers(7, 3, 1), "zodat je ziet welk hotel het is")
		gelijk(_knop("Hotels/Khotel2").mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"om te bekijken, niet om op te tikken")
	gelijk(_alle_teksten(), voor, "nog steeds niets weg")
	await _druk("Knoppen/Knee")
	gelijk(_titel(), UiTekst.START_TERUG, "Nee: terug naar het startblad")
	gelijk(_alle_teksten(), voor, "en alles is er nog")
	gelijk(State.hotel, 1, "het hotel in gebruik is niet veranderd")
	# and now for real
	await _druk("Knoppen/Knieuw")
	await _druk("Hotels/Khotel2")
	await _druk("Knoppen/Kja")
	gelijk(State.hotel, 2, "het nieuwe hotel staat op de plek van hotel 2")
	gelijk(int(State.s["dag"]), 1, "een vers hotel")
	gelijk(int(State.samenvatting(2).get("dag", 0)), 1, "hotel 2 is nu het nieuwe")
	waar(_intro_loopt(), "met het welkom")
	gelijk(_tekst(1), voor[1], "hotel 1 is heel")
	gelijk(_tekst(3), voor[3], "hotel 3 is heel")
	await _af()

# ---------------------------------------------------------- bestand: 💾 📂

## `💾 Bewaar` writes the hotel as a file; that file, bytes in through the
## same door as `📂 Open`, is the same hotel — down to its guests, its bill
## and its furniture — in the first free slot.
func test_bewaar_en_open_geven_hetzelfde_hotel() -> void:
	_onthoud()
	State.nieuw_spel()
	var gast := State.mk_gast("boef", "Boef", "hond", "puppy", 2, "Wandeling", 30)
	gast["kamer"] = "kamer1"
	gast["bed"] = "bed1"
	gast["accessoires"] = ["hoedje"]
	State.s["dag"] = 7
	State.s["sterren"] = 9
	State.s["munten"] = 12
	State.s["gasten"] = [gast]
	State.s["meubels"] = [{"id": "m1", "kamer": "kamer1", "type": "bed", "x": 10, "z": 4,
		"rot": 1, "soort": "hout"}]
	State.s["rekening"] = {"gastId": "boef", "fam": "Bakker", "nachten": 3, "prijs": 5,
		"totaal": 15, "stap": 2, "pogingen": 1, "telPog": 0, "wisselPog": 0,
		"hand": [10, 5], "bank": [10], "t0": 0, "tw": 0}
	State.s["spel"] = {"wekker": {"stap": 2}}
	State.s["geluid"] = false
	State.start_gekozen()
	State.nieuw_spel()
	await _start(Vector2i(1024, 768))
	var blad: UiStartblad = _shell.get("startblad")
	waar(blad != null, "de schil heeft een startblad")
	if blad == null:
		await _af()
		return
	# one hotel: 💾 Bewaar asks nothing and writes it
	if await _druk("Knoppen/Kbewaar"):
		gelijk(_hint(), UiTekst.HOTEL_BEWAARD, "het blad zegt dat het bewaard is")
		gelijk(_titel(), UiTekst.START_TERUG, "en blijft het startblad")
	var map := DirAccess.open(UiHotelbestand.MAP)
	var namen := map.get_files() if map != null else PackedStringArray()
	gelijk(namen.size(), 1, "één bestand bewaard")
	if namen.size() != 1:
		await _af()
		return
	gelijk(namen[0], "dierenhotel-hotel1-dag7.json", "met een naam die een ouder terugvindt")
	var bytes := FileAccess.get_file_as_bytes(UiHotelbestand.MAP.path_join(namen[0]))
	waar(bytes.size() > 100, "het bestand heeft inhoud (%d bytes)" % bytes.size())
	# ... and back in, through the door of 📂 Open
	waar(blad.laad_tekst(bytes.get_string_from_utf8()), "📂 Open neemt het aan")
	await _frames(3)
	gelijk(_hint(), UiTekst.HOTEL_GELADEN, "het blad zegt dat het er is")
	gelijk(State.hotel, 2, "in het eerste vrije hotel, dat nu het gekozen is")
	gelijk(JSON.stringify(State.lees_hotel(2)), JSON.stringify(State.lees_hotel(1)),
		"hetzelfde hotel, veld voor veld")
	var twee := State.lees_hotel(2)
	gelijk(int(twee["dag"]), 7, "dag 7")
	gelijk(str(twee["gasten"][0]["naam"]), "Boef", "met Boef")
	gelijk(twee["rekening"]["hand"], [10, 5], "en zijn halve rekening")
	gelijk(bool(twee["geluid"]), false, "en het geluid uit")
	# the tile is on the sheet, and continuing it plays the opened hotel
	waar(_knop("Hotels/Khotel2") != null and _knop("Hotels/Khotel2").get_node_or_null("Cijfers") != null,
		"hotel 2 staat met cijfers op het startblad")
	if await _druk("Hotels/Khotel2"):
		gelijk(int(State.s["dag"]), 7, "verder spelen in het geopende hotel")
		gelijk(int(State.s["munten"]), 12, "met zijn munten")
	await _af()

## A file that is not a whole hotel is refused with a friendly line, and then
## nothing changed: no hotel file, not the choice, not the world behind.
func test_een_kapot_bestand_verandert_niets() -> void:
	_onthoud()
	_hotel(1, 4, 5, 2)
	await _start(Vector2i(1024, 768))
	var blad: UiStartblad = _shell.get("startblad")
	if blad == null:
		fout("geen startblad")
		await _af()
		return
	var voor := _alle_teksten()
	var wereld := JSON.stringify(State.s)
	var gevallen := {
		"leeg bestand": "",
		"geen json": "{niet: json",
		"een plaatje": "\u0089PNG\r\n\u001a\n",
		"verkeerde versie": '{"v": 2, "s": {"dag": 4}}',
		"versie als woord": '{"v": "1", "s": {"dag": 4}}',
		"versie is een object": '{"v": {}, "s": {"dag": 4}}',
		"geen s": '{"v": 1}',
		"alleen s": '{"dag": 4, "sterren": 2}',
		"lijst": "[1, 2, 3]",
		"dag is een woord": '{"v": 1, "s": {"dag": "morgen"}}',
		"buidel is geen lijst": '{"v": 1, "s": {"rekening": {"gastId": "boef", "fam": "Bakker", "hand": "kapot", "bank": 3}}}',
		"gast zonder id": '{"v": 1, "s": {"gasten": [{"naam": "Zoek"}]}}',
		"te groot": '{"v": 1, "s": {"brieven": [], "x": "%s"}}' % "a".repeat(State.BESTAND_MAX),
	}
	for wat in gevallen.keys():
		waar(not blad.laad_tekst(gevallen[wat]), "%s wordt geweigerd" % wat)
		await _frames(3)
		gelijk(_hint(), UiTekst.HOTEL_KAPOT, "%s: het blad zegt het vriendelijk" % wat)
		gelijk(_titel(), UiTekst.START_TERUG, "%s: het startblad blijft" % wat)
		gelijk(_alle_teksten(), voor, "%s: geen bestand veranderd" % wat)
		gelijk(State.hotel, 1, "%s: het hotel in gebruik niet" % wat)
		gelijk(JSON.stringify(State.s), wereld, "%s: de wereld erachter niet" % wat)
	waar(_knop("Hotels/Khotel2") != null and _knop("Hotels/Khotel2").get_node_or_null("Cijfers") == null,
		"hotel 2 is nog steeds leeg")
	await _af()

## `📂 Open` with all three taken: the same two questions as a new hotel, and
## the file lands only after `✅ Ja, weg ermee`.
func test_open_met_drie_hotels_vraagt_eerst() -> void:
	_onthoud()
	_hotel(1, 4, 5, 2)
	_hotel(2, 7, 3, 1)
	_hotel(3, 9, 1, 0)
	var nieuw := State.standaard()
	nieuw["dag"] = 21
	nieuw["sterren"] = 30
	var bestand := JSON.stringify({"v": 1, "s": nieuw})
	await _start(Vector2i(1024, 768))
	var blad: UiStartblad = _shell.get("startblad")
	if blad == null:
		fout("geen startblad")
		await _af()
		return
	var voor := _alle_teksten()
	waar(blad.laad_tekst(bestand), "een goed bestand")
	await _frames(3)
	gelijk(_titel(), UiTekst.HOTEL_WEG, "alle drie bezet: welk hotel mag weg?")
	gelijk(_alle_teksten(), voor, "nog niets overschreven")
	await _druk("Hotels/Khotel3")
	gelijk(_titel(), UiTekst.HOTEL_ZEKER, "weet je het zeker?")
	gelijk(_alle_teksten(), voor, "nog steeds niets")
	await _druk("Knoppen/Kja")
	gelijk(int(State.samenvatting(3).get("dag", 0)), 21, "hotel 3 is nu het geopende")
	gelijk(_tekst(1), voor[1], "hotel 1 is heel")
	gelijk(_tekst(2), voor[2], "hotel 2 is heel")
	gelijk(State.hotel, 3, "en het is het gekozen hotel")
	gelijk(_titel(), UiTekst.START_TERUG, "terug op het startblad")
	gelijk(_hint(), UiTekst.HOTEL_GELADEN, "dat zegt dat het er is")
	await _af()

## With more than one hotel `💾 Bewaar` asks which; an empty one cannot be
## picked, `⬅ Terug` writes nothing.
func test_bewaar_vraagt_welk_hotel() -> void:
	_onthoud()
	_hotel(1, 4, 5, 2)
	_hotel(3, 9, 1, 0)
	await _start(Vector2i(1024, 768))
	await _druk("Knoppen/Kbewaar")
	gelijk(_titel(), UiTekst.HOTEL_WELKE, "welk hotel bewaar je?")
	var leeg := _knop("Hotels/Khotel2")
	waar(leeg != null and leeg.disabled, "een leeg hotel kun je niet bewaren")
	await _druk("Knoppen/Kterug")
	gelijk(_titel(), UiTekst.START_TERUG, "terug")
	var map := DirAccess.open(UiHotelbestand.MAP)
	gelijk(map.get_files().size() if map != null else 0, 0, "niets bewaard")
	await _druk("Knoppen/Kbewaar")
	await _druk("Hotels/Khotel3")
	map = DirAccess.open(UiHotelbestand.MAP)
	var namen := map.get_files() if map != null else PackedStringArray()
	gelijk(Array(namen), ["dierenhotel-hotel3-dag9.json"], "hotel 3 is bewaard")
	gelijk(_titel(), UiTekst.START_TERUG, "en het startblad is terug")
	await _af()

# -------------------------------------------------------------- vier schermen

## The start sheet — three full hotels, so the `➕ Nieuw hotel` button too —
## and the confirmation fit on the four screens: everything on the glass and
## inside the sheet without scrolling, every tap target at least 48, nothing
## on top of something else, no letter under 12 px.
func test_het_startblad_past_op_vier_schermen() -> void:
	_onthoud()
	for vol in [true, false]:
		_wis()
		_hotel(1, 104, 345, 8)
		_hotel(3, 9, 1, 0)
		if vol:
			_hotel(2, 27, 52, 4)
		for maat in SCHERMEN:
			await _start(maat)
			var wat := "%s %s" % [str(maat), "vol" if vol else "één vrij"]
			_meet_blad(maat, wat, ["Hotels/Khotel1", "Hotels/Khotel2", "Hotels/Khotel3",
				"Knoppen/Kbewaar", "Knoppen/Kopen"] + (["Knoppen/Knieuw"] as Array if vol else []))
			if vol:
				await _druk("Knoppen/Knieuw")
				await _druk("Hotels/Khotel1")
				gelijk(_titel(), UiTekst.HOTEL_ZEKER, "%s: de vraag staat er" % wat)
				_meet_blad(maat, wat + " zeker", ["Hotels/Khotel1", "Knoppen/Knee", "Knoppen/Kja"])
			await _weg()
	await _af()

func _meet_blad(maat: Vector2i, wat: String, knoppen: Array) -> void:
	var scherm := Rect2(Vector2.ZERO, Vector2(maat))
	var rol := _shell.get_node_or_null("Bladlaag/Blad/Midden/Blad/Rol") as Control
	waar(rol != null, "%s: een blad" % wat)
	if rol == null:
		return
	var zicht := rol.get_global_rect()
	waar(scherm.encloses(zicht), "%s: het blad staat in beeld (%s)" % [wat, str(zicht)])
	var vakken: Array[Rect2] = []
	for pad in knoppen:
		var k := _knop(pad)
		waar(k != null, "%s: %s staat er" % [wat, pad])
		if k == null:
			continue
		var r := k.get_global_rect()
		waar(r.size.x >= 48.0 and r.size.y >= 48.0, "%s: %s is een tikdoel (%s)" % [wat, pad, str(r)])
		waar(zicht.grow(0.5).encloses(r), "%s: %s zonder scrollen te zien (%s in %s)"
			% [wat, pad, str(r), str(zicht)])
		for ander in vakken:
			waar(not ander.grow(-0.5).intersects(r.grow(-0.5)),
				"%s: %s ligt nergens op (%s, %s)" % [wat, pad, str(r), str(ander)])
		vakken.append(r)
	var te_klein: Array[String] = []
	_letters(_blad(), te_klein)
	gelijk(te_klein.size(), 0, "%s: geen letter onder 12 px %s" % [wat, str(te_klein)])
	# and the words of a tile stay inside it
	for n in range(1, State.HOTELS + 1):
		var t := _knop("Hotels/Khotel%d" % n)
		if t == null:
			continue
		for naam in ["Icoon", "Naam", "Cijfers"]:
			var l := t.get_node_or_null(naam) as Label
			if l != null:
				waar(t.get_global_rect().grow(0.5).encloses(l.get_global_rect()),
					"%s: %s van hotel %d past in de tegel (%s in %s)" % [wat, naam, n,
						str(l.get_global_rect()), str(t.get_global_rect())])

func _letters(k: Node, te_klein: Array[String]) -> void:
	if k == null:
		return
	if k is Label or k is Button:
		var maat: int = (k as Control).get_theme_font_size("font_size")
		if maat < UiThema.VLOER and not str(k.get("text")).is_empty():
			te_klein.append("%s=%d" % [k.name, maat])
	for kind in k.get_children():
		_letters(kind, te_klein)

# ------------------------------------------------------------------ teksten

## HOTEL.md §9 for every new word on the glass: at most 8 words and 40
## characters, a pictogram on every button, every glyph in the bundled fonts.
func test_teksten_houden_zich_aan_hotel_9() -> void:
	if Ui.thema == null or Ui.thema.default_font == null:
		Ui._bouw_thema(17)
	var knoppen := [UiTekst.HOTEL_NIEUW, UiTekst.HOTEL_JA, UiTekst.HOTEL_NEE,
		UiTekst.HOTEL_BEWAAR, UiTekst.HOTEL_OPEN, UiTekst.TERUG]
	var zinnen := [UiTekst.START_TERUG, UiTekst.HOTEL_WEG, UiTekst.HOTEL_ZEKER,
		UiTekst.HOTEL_WELKE, UiTekst.HOTEL_BEWAARD, UiTekst.HOTEL_GELADEN, UiTekst.HOTEL_KAPOT,
		UiTekst.hotel_naam(3), UiTekst.hotel_cijfers(104, 345, 8)] + knoppen
	for i in UiTekst.HOTEL_ICOON.size():
		zinnen.append(UiTekst.HOTEL_ICOON[i])
	for zin in zinnen:
		var z: String = zin
		waar(z.split(" ", false).size() <= 8, "%s: hooguit 8 woorden" % z)
		waar(z.length() <= 40, "%s: hooguit 40 tekens (%d)" % [z, z.length()])
		gelijk(Ui.mist_tekens(z).size(), 0, "%s: elk teken in de fonts %s" % [z, str(Ui.mist_tekens(z))])
	for knop in knoppen:
		var k: String = knop
		var delen := k.split(" ", false)
		waar(delen.size() >= 2 and delen[0].unicode_at(0) >= 0x2000,
			"%s: pictogram én woord" % k)
	gelijk(UiTekst.HOTEL_ICOON.size(), State.HOTELS, "een dier per hotel")
	var dieren := {}
	for d in UiTekst.HOTEL_ICOON:
		dieren[d] = true
	gelijk(dieren.size(), State.HOTELS, "drie verschillende dieren")
