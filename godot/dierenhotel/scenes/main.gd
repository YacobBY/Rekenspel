extends Node
## The shell.  Boots the autoloads into a running world, keeps one unit equal to
## one CSS pixel at every window size and device pixel ratio (architecture.md
## §4.1), and lays out the chrome around the world frame (§4.5).
##
## Three rules decide every layout here, and they are the ones from world.md
## §6.5 / art-sound-rules.md §16.9 — expressed in units on the shell, not as
## media queries on a document:
##   * the world frame gets every unit the chrome does not use, and never falls
##     below KADER_MIN = 200: the chrome gives way, never the world;
##   * a tap target is at least 48 units, 44 only below a 360 unit frame;
##   * a child-facing letter is never below 12 px.

const KADER_MIN := 200         ## units; the world never gets less than this
const APP_MAX := 1180          ## units; the reading width cap on a big tablet
const BREED_ZIJ := 900         ## landscape from here on is the wide shell
const LAAG_LANDSCHAP := 450    ## landscape under this is the compact shell
const VOET_UIT := 520          ## the footer disappears below this width
const TELEFOON := 520          ## portrait under this width is the phone shell

@onready var wereld_vp: SubViewport = $Wereld
@onready var kamer_scene: Node2D = $Wereld/Kamer
@onready var scherm: MarginContainer = $Scherm
@onready var kolom: VBoxContainer = $Scherm/Kolom
@onready var chroom: UiHud = $Scherm/Kolom/Chroom
@onready var middenrij: HBoxContainer = $Scherm/Kolom/Middenrij
@onready var kader: Control = $Scherm/Kolom/Middenrij/Kaderdoos/Kader
@onready var beeld: TextureRect = $Scherm/Kolom/Middenrij/Kaderdoos/Kader/Beeld
@onready var vanglaag: Control = $Scherm/Kolom/Middenrij/Kaderdoos/Kader/Vanglaag
## The paper of the maths bar (PLAN.md §3.1), between the catch areas and the
## buttons: it paints over the world and catches nothing.
@onready var balklaag: UiRekenbalk = $Scherm/Kolom/Middenrij/Kaderdoos/Kader/Balklaag
@onready var knoplaag: Control = $Scherm/Kolom/Middenrij/Kaderdoos/Kader/Knoplaag
@onready var naamlaag: Control = $Scherm/Kolom/Middenrij/Kaderdoos/Kader/Naamlaag
@onready var rail: VBoxContainer = $Scherm/Kolom/Middenrij/Rail
@onready var kamerbalk: UiKamerbalk = $Scherm/Kolom/Kamerbalk
var spelbalk: UiSpelbalk = null   ## takes the room bar's place while a game runs
var _spel_titel: Dictionary = {}  ## {icoon, titel} of the running game, or empty
@onready var voet: Label = $Scherm/Kolom/Voet
@onready var toastlaag: Control = $Toastlaag
@onready var bladlaag: Control = $Bladlaag

var _bezig := false
var _gemeld := false
var _tikken := 0
var _geluid_klaar := false
var _bak_repaint := false         ## a bowl repaint is already queued (V5)
var _compact := false
var _telefoon := false
## The intro of a fresh game while it is on the glass, or null (ui/intro.gd).
var intro: UiIntro = null

func _ready() -> void:
	Ui.registreer_lagen(knoplaag, naamlaag, toastlaag, bladlaag, vanglaag, balklaag)
	Ui.registreer_wortels([scherm, toastlaag, bladlaag])
	World.registreer_viewport(wereld_vp, kamer_scene)
	beeld.texture = wereld_vp.get_texture()
	get_window().size_changed.connect(_op_venster)
	kader.resized.connect(_op_kader)
	scherm.resized.connect(_pas_shell)
	Ui.thema_veranderd.connect(_op_thema)
	Hits.hotspot_getikt.connect(func(id: String) -> void:
		_tikken += 1
		print("[probe] tik=", _tikken, " id=", id))
	Ui.kaart_geopend.connect(_meld_kaart)
	# The game bar (owner, 2026-09-18): the registry says a game started or
	# stopped, the shell swaps the room bar for `⬅ Terug` and back.
	spelbalk = UiSpelbalk.new()
	spelbalk.visible = false
	kolom.add_child(spelbalk)
	kolom.move_child(spelbalk, kamerbalk.get_index() + 1)
	Games.spel_gestart.connect(_spel_aan)
	Games.spel_gestopt.connect(_spel_uit)
	# ... and the animal of the turn beside it (owner, 2026-09-23)
	Games.speler_veranderd.connect(_op_speler)

	# The save owns the sound: every time `State.s` is replaced (a fresh game, a
	# restored save) the mixer is told what the child chose last (V1 finding 2).
	State.veranderd.connect(_volg_geluid)
	_bouw_chroom()
	Hotel.hud_veranderd.connect(_ververs_chroom)
	Hotel.dag_veranderd.connect(func(_d: int) -> void: _meld_stand("dag"))
	Hotel.bord_veranderd.connect(_ververs_chroom)
	Hotel.trap_gevraagd.connect(_trap)
	Rooms.kamers_veranderd.connect(_nieuwe_kamers)
	World.kamer_veranderd.connect(func(_k: String) -> void: kamerbalk.ververs())
	# V5 (PLAN.md): a bowl level can change right in the middle of the world
	# tick, while the eat loop is still walking over the animals.  A repaint
	# there would rebuild the hotel's buttons underneath that loop, so it goes
	# deferred — and only for the room the child is actually looking at.
	World.bak_veranderd.connect(_bak_gewijzigd)

	_op_venster()
	_pas_shell()
	# `geen_start` is set by the headless layout test, which drops this shell
	# into a SubViewport to measure the five frames and must not touch the save.
	if not has_meta("geen_start"):
		_begin()
		_meld_later()

## Someone's bowl changed level.  The button that says "Vol" is built by
## `Hotel.hotspots()`, which `render()` calls, so a change has to reach it —
## but never on the tick that caused it (see the connect above).
func _bak_gewijzigd(kamer: String, _slot: String) -> void:
	if kamer != World.kamer_nu():
		return
	if _bak_repaint:
		return          # four animals chewing one bowl is one repaint, not four
	_bak_repaint = true
	_schildert_bak.call_deferred()

## The deferred half of `_bak_gewijzigd`.  The flag is cleared here and not by
## a timer, so everything the world changed while this was queued is drawn by
## this one render.
func _schildert_bak() -> void:
	_bak_repaint = false
	Hotel.render()

# ---------------------------------------------------------------- opstarten

## world.md §6.2: read the save, always start a living world behind the sheet,
## and only then ask.  Nothing is written before the child answered
## (architecture.md §9), so looking at the start screen cannot destroy a save.
##
## A FRESH game — no save at all, or `Nieuw spel` — begins with the intro
## (ui/intro.gd); `Verder spelen` never does: a child who comes back is not held
## up by a story it has already seen.  The flow decides this, the save carries
## no field for it.
func _begin() -> void:
	_opslag_uit_url()
	var had_save := State.lees()
	var bewaard: Dictionary = State.s.duplicate(true) if had_save else {}
	State.nieuw_spel()
	Hotel.start()
	_ververs_chroom()
	if not had_save:
		State.start_gekozen()
		_volg_geluid()
		_meld_stand("vers")
		_intro_start()
		return
	var verder := func() -> void:
		State.s = bewaard
		State.start_gekozen()
		_volg_geluid()
		Hotel.start()
		_ververs_chroom()
		_meld_stand("verder")
		_meld_knoppen()
	var nieuw := func() -> void:
		State.nieuw_spel()
		State.start_gekozen()
		_volg_geluid()
		Hotel.start()
		_ververs_chroom()
		_meld_stand("nieuw")
		_intro_start()
		_meld_knoppen()
	print("[probe] opslag= dag=", int(bewaard.get("dag", 1)),
		" sterren=", int(bewaard.get("sterren", 0)),
		" munten=", int(bewaard.get("munten", 0)),
		" geluid=", bool(bewaard.get("geluid", true)))
	var regel := Label.new()
	regel.text = UiTekst.start_stand(int(bewaard.get("dag", 1)),
		(bewaard.get("gasten", []) as Array).size(),
		int(bewaard.get("munten", 0)), int(bewaard.get("sterren", 0)))
	regel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Ui.blad_open({
		"titel": UiTekst.START_TERUG, "inhoud": [regel], "sluitbaar": false,
		"knoppen": [
			{"id": "verder", "tekst": UiTekst.START_VERDER, "groot": true, "aan": verder},
			{"id": "nieuw", "tekst": UiTekst.START_NIEUW, "aan": nieuw},
		]})

# ------------------------------------------------------------------- intro

## Lay the intro over the whole shell — over the chrome, the room bar, the
## sheets and the toasts: it is the last child of the shell on purpose.
func _intro_start() -> void:
	if intro_loopt():
		intro.sluit("weg")          # tidies up NOW, before the new one takes the stage
	intro = UiIntro.new()
	add_child(intro)
	intro.stap_veranderd.connect(_intro_stap)
	intro.klaar.connect(_intro_klaar)
	intro.begin()

func intro_loopt() -> bool:
	return intro != null and is_instance_valid(intro) and not intro.is_dicht()

## One `[probe]` line when the welcome card is up, and where it is: a probe
## taps it away (any tap does) or waits for "[probe] intro=klaar".
func _intro_stap(stap: int, aantal: int) -> void:
	print("[probe] intro stap=%d/%d" % [stap + 1, aantal])
	await _na_plaatsing()
	if intro_loopt():
		print("[probe] introkaart=", intro.kaart_rect())

func _intro_klaar(hoe: String) -> void:
	print("[probe] intro=klaar hoe=", hoe)
	intro = null
	# the hotel's own buttons are back on the glass (the intro had them step
	# aside), and a probe steers on the newest lines
	_meld_knoppen()

# ------------------------------------------------------------------ chroom

## Build (or rebuild at a new text size) the chrome and the room bar.
func _bouw_chroom() -> void:
	chroom.bouw(Ui.maten)
	chroom.munt_badge.pressed.connect(_kassa)
	chroom.brief_badge.pressed.connect(_brievenmuur)
	chroom.geluid_knop.pressed.connect(_geluid)
	chroom.prikbord_knop.pressed.connect(Hotel.bord_open)
	chroom.avond_knop.pressed.connect(Hotel.avondronde)
	kamerbalk.bouw(Ui.maten)
	if not kamerbalk.kamer_gekozen.is_connected(_naar_kamer):
		kamerbalk.kamer_gekozen.connect(_naar_kamer)
		kamerbalk.kaart_gevraagd.connect(_plattegrond)
		kamerbalk.verstopt_veranderd.connect(_meld_verstopt)
	_ververs_chroom()

func _naar_kamer(id: String) -> void:
	Hotel.naar_kamer(id)

## A sum came up or went (owner, 2026-09-24): the room chips and the door
## signs stepped aside or came back.  One line, so a browser probe knows why
## the `chip` lines are missing and which card it is answering.
func _meld_verstopt(aan: bool) -> void:
	print("[probe] kamerbalk verstopt=", aan, " som=", Ui.som_kaart_in_beeld())

# ---------------------------------------------------------------- spelbalk

## A game started: the room chips are not part of the sum and took the whole
## row, so the row becomes the game bar — `⬅ Terug` first, always in the same
## place, the game's name beside it.
func _spel_aan(id: String) -> void:
	var def := Games.definitie(id)
	var hs: Dictionary = def.get("hotspot", {})
	_spel_titel = {"icoon": str(hs.get("icoon", "")), "titel": str(def.get("naam", id))}
	_bouw_spelbalk()
	_pas_shell()

func _spel_uit(_id: String) -> void:
	_spel_titel = {}
	_pas_shell()

func _bouw_spelbalk() -> void:
	if spelbalk == null or _spel_titel.is_empty():
		return
	spelbalk.bouw(str(_spel_titel["icoon"]), str(_spel_titel["titel"]), Ui.maten, Ui.tap_maat(),
		Games.stop, _compact, Games.wissel_speler)
	_zet_speler_knop()

func spel_balk_aan() -> bool:
	return spelbalk != null and not _spel_titel.is_empty()

## The animal of the turn on the game bar (owner, 2026-09-23): shown only when
## the running game has one AND somebody else could take its turn — with a
## single animal the button could do nothing, so it is not there.
func _zet_speler_knop() -> void:
	if spelbalk == null:
		return
	var gast: Dictionary = State.gast_van(Games.speler()) if Games.kan_wisselen() else {}
	spelbalk.zet_speler(str(Hotel.DIER_ICOON.get(str(gast.get("kind", "")), "🐾")),
		str(gast.get("naam", "")))

## The running game moved on to another animal (the next key, the next
## sleeper) or started with one: redraw the button, and lay the shell out again
## because the bar may have grown or shrunk by it.
func _op_speler(_gast: String) -> void:
	if not is_inside_tree() or not spel_balk_aan():
		return
	_zet_speler_knop()
	_pas_shell()

## A room was added or renamed: rebuild the chips and re-lay the shell, because
## the bar's own width decides how many columns it gets.
func _nieuwe_kamers() -> void:
	kamerbalk.vul()
	_pas_shell()

func _ververs_chroom() -> void:
	chroom.ververs()
	kamerbalk.ververs()

func _op_thema() -> void:
	# The breakpoint moved: the chrome is cheap to rebuild and there is exactly
	# one place that knows the new sizes.
	_bouw_chroom()
	_bouw_spelbalk()
	_pas_shell()

func _geluid() -> void:
	Snd.ontgrendel()
	Snd.schakel()          # persists `geluid` in the save itself
	_ververs_chroom()
	_meld_stand("geluid")

func _kassa() -> void:
	var regels: Array[Control] = []
	for zin in [UiTekst.kassa_munten(int(State.s["munten"])),
			UiTekst.kassa_sterren(int(State.s["sterren"])),
			UiTekst.kassa_snoep(int(State.s["snoeppot"])),
			UiTekst.KASSA_UITLEG_1, UiTekst.KASSA_UITLEG_2]:
		var l := Label.new()
		l.text = zin
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		regels.append(l)
	Ui.blad_open({"titel": UiTekst.KASSA_TITEL, "inhoud": regels,
		"knoppen": [{"id": "sluit", "tekst": UiTekst.SLUITEN}]})

func _brievenmuur() -> void:
	var regels: Array[Control] = []
	for brief in State.s["brieven"]:
		var l := Label.new()
		l.text = "%s\n%s" % [str(brief.get("titel", "")), str(brief.get("tekst", ""))]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		regels.append(l)
	for zin in [UiTekst.BRIEVEN_UITLEG_1, UiTekst.BRIEVEN_UITLEG_2]:
		var l := Label.new()
		l.text = zin
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", UiThema.INKT2)
		regels.append(l)
	Ui.blad_open({"titel": UiTekst.BRIEVEN_TITEL, "inhoud": regels,
		"knoppen": [{"id": "sluit", "tekst": UiTekst.SLUITEN}]})

func _plattegrond() -> void:
	_toren(UiTekst.KAART_TITEL, UiTekst.KAART_HINT)

## The stairs' panel (owner, 2026-09-24: the hotel is a tower; stairs instead of
## a lift since 2026-09-25): the same tower as the map, under the stairs' own
## title and pictogram — a floor is a row, and a tap on a
## room rides there (`World.naar` slides the new floor in from above or below).
func _trap(_kamer: String) -> void:
	print("[probe] trap open kamer=", _kamer)
	_toren(UiTekst.TRAP_BLAD, UiTekst.TRAP_HINT, UiTrapIcoon.beeld())

func _toren(titel: String, hint: String, beeld: Texture2D = null) -> void:
	var kaart := UiPlattegrond.new()
	kaart.bouw(Ui.maten)
	kaart.kamer_gekozen.connect(func(id: String) -> void:
		Ui.blad_dicht()
		Hotel.naar_kamer(id))
	Ui.blad_open({"titel": titel, "hint": hint, "beeld": beeld,
		"inhoud": [kaart], "knoppen": [{"id": "sluit", "tekst": UiTekst.SLUITEN}]})

# --------------------------------------------------------------- de maten

## One unit = one CSS pixel, at any device pixel ratio (architecture.md §4.1).
func _op_venster() -> void:
	var win := get_window()
	var dpr := maxf(1.0, DisplayServer.screen_get_scale())
	var css := Vector2i(
		maxi(320, JsGetal.rond(win.size.x / dpr)),
		maxi(240, JsGetal.rond(win.size.y / dpr)))
	if win.content_scale_size != css:
		win.content_scale_size = css
	call_deferred("_pas_shell")

func _op_kader() -> void:
	if kader == null:
		return
	World.meet(Rect2(Vector2.ZERO, kader.size))

## The whole breakpoint ladder, in units, on the shell.  Idempotent: it only
## writes a value that actually changed, so it cannot feed itself (which is
## exactly the loop `world.js` needed a 180 ms lock and a signature for).
func _pas_shell() -> void:
	if _bezig or scherm == null:
		return
	_bezig = true
	# The shell measures ITSELF, not the window: `Scherm` is anchored to the
	# whole viewport, so its rectangle is the CSS size in units — and a headless
	# test can drop the shell into a SubViewport of any size and get the real
	# layout out of it.
	var breed := scherm.size.x
	var hoog := scherm.size.y
	if breed < 1.0 or hoog < 1.0:
		var win := get_window()
		breed = float(win.content_scale_size.x)
		hoog = float(win.content_scale_size.y)
	var landschap := breed > hoog
	var compact := landschap and hoog < LAAG_LANDSCHAP
	# A phone in portrait: the chrome and the room bar together took 304 of 740
	# units and left the world 54 % (architecture.md §4.5, I1 finding 4).
	var telefoon := not landschap and breed < TELEFOON
	_compact = compact
	_telefoon = telefoon
	# The tap rule is measured on the screen, not on the world frame (§16.5).
	Ui.zet_scherm(Vector2(breed, hoog))

	# Safe areas (world.md §6.5): the minimum is 6/12/10/12, 4/8/4/8 compact.
	var min_l := 8 if compact else 12
	var min_t := 4 if compact else 6
	var min_b := 4 if compact else 10
	var veilig := _veilige_randen()
	var links := maxi(min_l, int(veilig.position.x))
	var rechts := maxi(min_l, int(veilig.size.x))
	var boven := maxi(min_t, int(veilig.position.y))
	var onder := maxi(min_b, int(veilig.size.y))
	# On a wide tablet the reading width is capped and centred, so the child
	# does not have to sweep an arm across 1280 units.
	if landschap and breed >= BREED_ZIJ and breed - links - rechts > APP_MAX:
		var extra := int((breed - links - rechts - APP_MAX) * 0.5)
		links += extra
		rechts += extra
	_marge(links, boven, rechts, onder)

	# The chrome gives way, never the world (architecture.md §4.5).  Four rungs,
	# each of which costs the child less than a smaller room does: the footer is
	# decoration, the logo is decoration, and the room bar beside the frame keeps
	# every chip reachable while costing width instead of height.
	var rail_aan := compact
	voet.visible = breed >= VOET_UIT and not compact
	chroom.zet_vorm(compact, telefoon)
	_zet_balk(rail_aan, breed - links - rechts,
		hoog - boven - onder - chroom.get_combined_minimum_size().y - 8.0, telefoon)
	if _kader_hoog(hoog, boven, onder, rail_aan) < KADER_MIN and voet.visible:
		voet.visible = false
	if _kader_hoog(hoog, boven, onder, rail_aan) < KADER_MIN and not compact:
		chroom.zet_vorm(true, telefoon)
	if _kader_hoog(hoog, boven, onder, rail_aan) < KADER_MIN and not rail_aan:
		rail_aan = true
		_zet_balk(true, breed - links - rechts,
			hoog - boven - onder - chroom.get_combined_minimum_size().y - 8.0, telefoon)
	_bezig = false
	_op_kader()

## What the world frame is left with, given the chrome as it stands now.
func _kader_hoog(hoog: float, boven: int, onder: int, rail_aan: bool) -> float:
	var vrij := hoog - boven - onder - chroom.get_combined_minimum_size().y
	if not rail_aan:
		vrij -= (spelbalk if spel_balk_aan() else kamerbalk).get_combined_minimum_size().y
	if voet.visible:
		vrij -= voet.get_combined_minimum_size().y
	return vrij - 8.0        # the column separations between the three rows

## The room bar sits under the frame, as a three-column rail beside it, or — on
## a phone in portrait — as one scrolling row under it (architecture.md §4.5).
func _zet_balk(rail_aan: bool, breed: float, hoogte: float = 0.0, strook: bool = false) -> void:
	var doel: Node = rail if rail_aan else kolom
	if kamerbalk.get_parent() != doel:
		kamerbalk.reparent(doel, false)
		if not rail_aan:
			kolom.move_child(kamerbalk, voet.get_index())
	rail.visible = rail_aan
	kamerbalk.pas_aan(kamerbalk.rail_breedte() if rail_aan else breed, rail_aan, hoogte,
		strook and not rail_aan)
	# The game bar goes wherever the room bar goes and takes its exact
	# footprint, so the frame keeps its size when a game starts or ends.
	if spelbalk != null:
		var spel := spel_balk_aan()
		if spelbalk.get_parent() != doel:
			spelbalk.reparent(doel, false)
		if not rail_aan:
			kolom.move_child(spelbalk, voet.get_index())
		if spel and (spelbalk.get_child_count() == 0 or (spelbalk.get_child(0) is VBoxContainer) != rail_aan):
			_bouw_spelbalk()
		var voetafdruk := kamerbalk.get_combined_minimum_size()
		spelbalk.neem_maat(Vector2(voetafdruk.x, 0.0) if rail_aan else Vector2(0.0, voetafdruk.y),
			voetafdruk.x if rail_aan else breed)
		spelbalk.visible = spel
		kamerbalk.visible = not spel

func _marge(l: int, t: int, r: int, b: int) -> void:
	for paar in [["margin_left", l], ["margin_top", t], ["margin_right", r], ["margin_bottom", b]]:
		if scherm.get_theme_constant(paar[0]) != paar[1]:
			scherm.add_theme_constant_override(paar[0], paar[1])

## The four insets a notch or a home bar takes, in units.  `Rect2` carries them
## as position = (left, top) and size = (right, bottom); on the web export the
## `viewport-fit=cover` meta of §7.2 is what makes them non-zero.
func _veilige_randen() -> Rect2:
	var scherm_rect := DisplayServer.screen_get_usable_rect()
	var veilig := DisplayServer.get_display_safe_area()
	if veilig.size.x <= 0 or veilig.size.y <= 0:
		return Rect2()
	var f := 1.0 / maxf(1.0, DisplayServer.screen_get_scale())
	return Rect2(
		maxf(0.0, (veilig.position.x - scherm_rect.position.x) * f),
		maxf(0.0, (veilig.position.y - scherm_rect.position.y) * f),
		maxf(0.0, (scherm_rect.end.x - veilig.end.x) * f),
		maxf(0.0, (scherm_rect.end.y - veilig.end.y) * f))

# ------------------------------------------------------------------ invoer

## No sound before the first real input — that satisfies the browser autoplay
## policy without the one-sample-buffer trick (architecture.md §8).
func _input(event: InputEvent) -> void:
	if _geluid_klaar:
		return
	var raak := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	raak = raak or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if raak:
		_geluid_klaar = true
		Snd.ontgrendel()
		# what the child chose is in the save, not in this event
		_volg_geluid()

## The mixer follows the save, never the other way round.  `Snd.schakel()` is
## the child's toggle and writes the save; this only reads it, so it is safe to
## call after every swap of `State.s` (V1 finding 2).
func _volg_geluid() -> void:
	Snd.stem_af(bool(State.s.get("geluid", true)))

# ------------------------------------------------------------------- probe

## What the child would see of the save right now, and whether the start screen
## is really on the glass.  `bewaard` is the one that mattered: while the sheet
## rendered as a 560 x 24 strip nobody could answer it, so `start_gekozen()`
## never ran and every `bewaar()` was a no-op (W3-F1 finding 3).
func _meld_stand(waarom: String) -> void:
	print("[probe] stand=", waarom, " dag=", int(State.s["dag"]),
		" sterren=", int(State.s["sterren"]), " munten=", int(State.s["munten"]),
		" geluid=", bool(State.s["geluid"]), " bewaard=", State.gestart())
	var blad := bladlaag.get_node_or_null("Blad")
	if blad == null:
		print("[probe] blad=geen")
		return
	var paneel: Control = blad.get_node_or_null("Midden/Blad")
	print("[probe] blad=", paneel.get_global_rect() if paneel != null else Rect2())
	var rij: Control = blad.get_node_or_null("Midden/Blad/Rol/Kolom/Knoppen")
	if rij != null:
		for k in rij.get_children():
			print("[probe] bladknop ", k.name, "=", (k as Control).get_global_rect())

## A sum card opened.  The rectangle is only real after the next placement
## pass, so the line waits one frame — the browser probe reads it as the proof
## that a tap produced a card and not only a press (I1 finding 1).
func _meld_kaart(id: String) -> void:
	await _na_plaatsing()
	var s := Hits.spot(id)
	if s == null or not is_instance_valid(s.knoop):
		return
	var kn := (s.knoop as Control)
	print("[probe] kaart ", id, "=", kn.get_global_rect(),
		" balk=", Ui.balk_rect(), " baas=", Ui.balk_kaart(),
		" op=", str(Hits.debug().get(id, {}).get("op", "?")))
	# ... and its answer strip, bare as `<id>_keuzes=`, the way `tools/speel.js`
	# looks for a strip (`ci_som_keuzes#2/4`): the check-in's strip was never
	# reported, so a played run could not answer the desk's questions
	var st := Hits.spot(id + "_keuzes")
	if st != null and is_instance_valid(st.knoop) and (st.knoop as Control).visible:
		print("[probe] ", id, "_keuzes=", (st.knoop as Control).get_global_rect())

## One machine-readable line per fact, for the browser probe and the tests.
func _meld_later() -> void:
	await get_tree().create_timer(1.0).timeout
	if _gemeld or not is_inside_tree():
		return
	_gemeld = true
	var win := get_window()
	var sch := World.schaal()
	print("[probe] versie=", Engine.get_version_info()["string"])
	print("[probe] venster=", win.size, " css=", win.content_scale_size,
		" dpr=", DisplayServer.screen_get_scale())
	print("[probe] kader=", kader.size, " viewport=", wereld_vp.size,
		" g=", sch["g"], " dicht=", "%.3f" % sch["dicht"], " k=", "%.3f" % sch["k"])
	# Which font the CHROME really reads — not which font `Ui` thinks it built.
	var chroom_font := chroom.dag_badge.get_theme_font("font")
	print("[probe] font=", chroom_font.resource_path if chroom_font != null else "geen",
		" emoji=", chroom_font != null and chroom_font.has_char(0x1F4C5))
	print("[probe] shell=", "compact" if _compact else ("telefoon" if _telefoon else "gewoon"),
		" basis=", Ui.basis_maat(), " tap=", Ui.tap_maat(), " voet=", voet.visible)
	print("[probe] balk=", kamerbalk.size, " kolommen=", kamerbalk.kolommen(),
		" chroom=", chroom.size, " midden=", middenrij.size)
	print("[probe] kamers=", Rooms.lijst().size(), " kamer=", World.kamer_nu())
	print("[probe] spellen=", Games.lijst())
	print("[probe] platen=", Art.gebakken())
	var dbg := Hits.debug()
	var krap := 0
	var dek := 0.0
	var met_vlak := 0
	for id in dbg.keys():
		if bool(dbg[id]["krap"]):
			krap += 1
		dek = maxf(dek, float(dbg[id]["dekking"]))
		var v: Rect2 = dbg[id]["vlak"]
		if v.size.x > 0.0 and v.size.y > 0.0:
			met_vlak += 1
	# `vlakken` says how many of those buttons actually KNOW their object, so a
	# `dekking_max` of 0.00 is evidence and not an empty set (W3-F1 finding 5).
	print("[probe] hits=", dbg.size(), " krap=", krap, " vlakken=", met_vlak,
		" dekking_max=", "%.2f" % dek)
	_meld_stand("boot")
	print("[probe] tik=", _tikken)
	for k in [chroom.munt_badge, chroom.brief_badge, chroom.geluid_knop,
			chroom.prikbord_knop, chroom.avond_knop]:
		print("[probe] chroomknop ", k.name, "=", k.get_global_rect())
	await _meld_knoppen()
	# a fresh game is under the intro: say so, and where its buttons are
	if intro_loopt():
		print("[probe] intro=stap %d/%d" % [intro.stap() + 1, intro.aantal()])
		print("[probe] introkaart=", intro.kaart_rect())
	else:
		print("[probe] intro=geen")
	print("[probe] klaar")

## Wait until the hotspots that were just created have really been placed.
## `World._process` runs `Hits.plaats()` once per frame, and a tap is handled
## AFTER that pass in the same frame on the web export — so one frame of waiting
## reports the previous layout and the freshly built buttons are missing.
func _na_plaatsing() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

## Where every hotspot really is, right now.  Printed at boot AND again after
## the start screen was answered: "Verder spelen" restores a saved day, the
## hotel lays its buttons out for THAT day, and a probe that kept tapping the
## boot rectangles would tap empty glass (I1 finding 1).
func _meld_knoppen() -> void:
	await _na_plaatsing()
	for id in Hits.debug().keys():
		var s := Hits.spot(id)
		if s != null and is_instance_valid(s.knoop) and s.knoop.visible:
			print("[probe] knop ", id, "=", s.knoop.get_global_rect())
	# the game bar, when a game runs: one fixed place for `⬅ Terug`
	if spel_balk_aan() and spelbalk.visible and spelbalk.terug_knop != null:
		print("[probe] spelbalk=", spelbalk.get_global_rect(), " terug=", spelbalk.terug_knop.get_global_rect())
		if spelbalk.speler_knop != null and spelbalk.speler_knop.visible:
			print("[probe] spelbalk speler=", Games.speler(), " knop=",
				spelbalk.speler_knop.get_global_rect())
	# the room bar, so a probe can tap a room or the map ("kaart") by name —
	# not while a sum has made the chips step aside: they cannot be tapped then
	if kamerbalk != null and not kamerbalk.verstopt():
		for id in kamerbalk.chips():
			var b: Control = kamerbalk.chips()[id]
			if is_instance_valid(b) and b.visible:
				print("[probe] chip ", id if id != "" else "kaart", "=", b.get_global_rect())

## A shell that leaves the tree stops answering the theme signal: tests build
## several shells in one process and a freed one must not answer (I2).
func _exit_tree() -> void:
	if Ui.thema_veranderd.is_connected(_op_thema):
		Ui.thema_veranderd.disconnect(_op_thema)

## Probe hook (architecture.md §14.4, I2): `index.html?opslag=<base64 JSON>`
## writes that save to `user://` BEFORE it is read, so a browser proof can start
## on any day and band without playing the days first.  Without the flag nothing
## is written; a corrupt payload is caught by `State.lees()` like any other file.
func _opslag_uit_url() -> void:
	if not OS.has_feature("web"):
		return
	var zoek = JavaScriptBridge.eval("location.search", true)
	if zoek == null:
		return
	var s := str(zoek)
	var i := s.find("opslag=")
	if i < 0:
		return
	# base64url (no + or /, so no percent-decoding trouble); plain base64 works too
	var b64 := s.substr(i + 7).split("&")[0].replace("-", "+").replace("_", "/")
	var json := Marshalls.base64_to_utf8(b64)
	if json.is_empty():
		print("[probe] opslag_uit_url=onleesbaar")
		return
	var f := FileAccess.open(State.PAD, FileAccess.WRITE)
	if f != null:
		f.store_string(json)
		f.close()
		print("[probe] opslag_uit_url=%d" % json.length())
