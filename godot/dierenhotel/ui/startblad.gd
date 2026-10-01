class_name UiStartblad
extends Node
## The start sheet with the hotels (owner 2026-10-01: "En ik wil save files
## maken"), and the questions around it.
##
## The sheet shows the three hotels of the tablet as tiles (`UiHotelkeuze`): a
## tap on a hotel continues it, a tap on an empty tile `➕ Nieuw hotel` starts
## a new one there.  When all three are taken, `➕ Nieuw hotel` asks which one
## may go and then once more — that hotel alone on the sheet, `🗑️ Weet je het
## zeker?` — before anything is overwritten: a hotel is never thrown away by a
## single tap.  Under the tiles, small, the two buttons for a parent:
## `💾 Bewaar` (a hotel as a file) and `📂 Open` (a file into a hotel).
##
## What happens to the WORLD when a hotel is picked is the shell's business
## (`scenes/main.gd`): this sheet only says which hotel, and whether it is new
## (`gekozen`).  Nothing is written before that answer, except by the parent's
## `📂 Open`, which writes only the file it was given into a free hotel (or the
## one the confirmation gave up).

## The child chose hotel `n`: continue it, or (`nieuw`) start a fresh one there.
signal gekozen(n: int, nieuw: bool)
## A sheet of this flow is on the glass and laid out (for the probe lines).
signal blad_klaar(waarom: String)

var bestand: UiHotelbestand = null
## The last thing a parent's file action said, shown under the title.
var _melding := ""

func _ready() -> void:
	name = "Startblad"
	bestand = UiHotelbestand.new()
	bestand.name = "Hotelbestand"
	add_child(bestand)
	bestand.gelezen.connect(laad_tekst)

## Is there a hotel at all?  Without one the shell starts the first right away.
static func een_hotel() -> bool:
	for h in State.hotels():
		if not bool(h["leeg"]):
			return true
	return false

# ------------------------------------------------------------- het startblad

## The start sheet: the hotels, the played-last one highlighted.
func toon(stil := false) -> void:
	var hotels := State.hotels()
	var vol := true
	for h in hotels:
		if bool(h["leeg"]):
			vol = false
	var tegels := UiHotelkeuze.new()
	tegels.bouw(hotels, Ui.maten, {"actief": State.hotel})
	tegels.gekozen.connect(_tegel_gekozen.bind(hotels))
	var knoppen: Array = []
	if vol:
		# all three taken: a new hotel first asks which one may go
		# (on a phone held upright a row of its own, never beside 💾 and 📂)
		knoppen.append({"id": "nieuw", "tekst": UiTekst.HOTEL_NIEUW, "dicht": false,
			"rij": not tegels.staand(),
			"aan": func() -> void:
				vraag_weg(func(n: int) -> void:
					Ui.blad_dicht()
					gekozen.emit(n, true))})
	knoppen.append({"id": "bewaar", "tekst": UiTekst.HOTEL_BEWAAR, "klein": true,
		"dicht": false, "aan": bewaar_knop})
	knoppen.append({"id": "open", "tekst": UiTekst.HOTEL_OPEN, "klein": true,
		"dicht": false, "aan": open_knop})
	var b := Ui.blad_open({
		"titel": UiTekst.START_TERUG, "hint": _melding, "inhoud": [tegels],
		"sluitbaar": false, "stil": stil, "knoppen": knoppen})
	_melding = ""
	# the browser opens a file picker only inside a user gesture: the button
	# arms it the moment the finger goes down (`UiHotelbestand`)
	var open_knop_node := _knop(b, "open")
	if open_knop_node != null:
		open_knop_node.button_down.connect(bestand.wapen)
	_meld("hotels")

func _tegel_gekozen(n: int, hotels: Array) -> void:
	var leeg := bool((hotels[n - 1] as Dictionary).get("leeg", true))
	Ui.blad_dicht()
	gekozen.emit(n, leeg)

# ------------------------------------------------------ welk hotel mag weg

## All three hotels are taken and a new one is wanted (a new game, or a file
## from `📂 Open`): first which one may go, then are you sure.  `doel(n)` runs
## only after `✅ Ja, weg ermee`; `⬅ Nee, terug` always goes back to the start
## sheet with every hotel as it was.
func vraag_weg(doel: Callable) -> void:
	var tegels := UiHotelkeuze.new()
	tegels.bouw(State.hotels(), Ui.maten, {"alleen_vol": true})
	tegels.gekozen.connect(func(n: int) -> void: vraag_zeker(n, doel))
	Ui.blad_open({
		"titel": UiTekst.HOTEL_WEG, "inhoud": [tegels], "sluitbaar": false, "stil": true,
		"knoppen": [{"id": "nee", "tekst": UiTekst.HOTEL_NEE, "aan": func() -> void: toon(true)}]})
	_meld("weg")

func vraag_zeker(n: int, doel: Callable) -> void:
	var tegels := UiHotelkeuze.new()
	tegels.bouw([State.samenvatting(n)], Ui.maten, {"toon": true})
	Ui.blad_open({
		"titel": UiTekst.HOTEL_ZEKER, "inhoud": [tegels], "sluitbaar": false, "stil": true,
		"knoppen": [
			{"id": "nee", "tekst": UiTekst.HOTEL_NEE, "groot": true, "aan": func() -> void: toon(true)},
			{"id": "ja", "tekst": UiTekst.HOTEL_JA, "dicht": false, "aan": func() -> void: doel.call(n)},
		]})
	_meld("zeker")

# ------------------------------------------------------------- 💾 Bewaar

## One hotel: straight to the file.  More: which one?
func bewaar_knop() -> void:
	var vol: Array[int] = []
	for h in State.hotels():
		if not bool(h["leeg"]):
			vol.append(int(h["hotel"]))
	if vol.size() == 1:
		bewaar_hotel(vol[0])
		toon(true)
		return
	var tegels := UiHotelkeuze.new()
	tegels.bouw(State.hotels(), Ui.maten, {"alleen_vol": true})
	tegels.gekozen.connect(func(n: int) -> void:
		bewaar_hotel(n)
		toon(true))
	Ui.blad_open({
		"titel": UiTekst.HOTEL_WELKE, "inhoud": [tegels], "sluitbaar": false, "stil": true,
		"knoppen": [{"id": "terug", "tekst": UiTekst.TERUG, "aan": func() -> void: toon(true)}]})
	_meld("welke")

## Hotel `n` as a file: `dierenhotel-hotel2-dag4.json`.  Returns where it went.
func bewaar_hotel(n: int) -> String:
	var tekst := State.exporteer(n)
	if tekst.is_empty():
		return ""
	var naam := "dierenhotel-hotel%d-dag%d.json" % [n, int(State.samenvatting(n).get("dag", 1))]
	var waar := bestand.bewaar(naam, tekst)
	print("[probe] hotel_bewaar=", n, " naam=", naam, " waar=", waar)
	_melding = UiTekst.HOTEL_BEWAARD if not waar.is_empty() else ""
	return waar

# --------------------------------------------------------------- 📂 Open

func open_knop() -> void:
	if not bestand.open():
		print("[probe] hotel_open=geen_kiezer")

## The text of a file a parent opened.  A hotel goes into the first free slot,
## or — all three taken — into the one the confirmation gave up.  Anything that
## is not a whole hotel is refused, and then NOTHING changed: not a file, not
## the hotel in use, not the world behind the sheet.
func laad_tekst(tekst: String) -> bool:
	var uit := State.ontleed(tekst)
	if uit.is_empty():
		print("[probe] hotel_open=kapot")
		_melding = UiTekst.HOTEL_KAPOT
		toon(true)
		return false
	var n := State.vrij_hotel()
	if n > 0:
		_zet(n, uit)
		return true
	vraag_weg(func(m: int) -> void: _zet(m, uit))
	return true

func _zet(n: int, uit: Dictionary) -> void:
	if State.zet_hotel(n, uit):
		State.kies_hotel(n)
		print("[probe] hotel_open=", n, " dag=", int(uit["dag"]))
		_melding = UiTekst.HOTEL_GELADEN
	else:
		_melding = UiTekst.HOTEL_KAPOT
	toon(true)

# ------------------------------------------------------------------ hulp

func _knop(b: UiBlad, id: String) -> Button:
	if b == null:
		return null
	return b.get_node_or_null("Midden/Blad/Rol/Kolom/%s/K%s" % [UiBlad.KNOP_RIJ, id]) as Button

## Two frames: the sheet is laid out, its buttons are where a finger finds them.
func _meld(waarom: String) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	blad_klaar.emit(waarom)
