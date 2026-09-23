class_name UiIntro
extends Control
## The intro of a fresh game (owner, 2026-09-23: "Maak ook een leuke intro voor
## de game" — and in the same breath: "laat niet het prikbord zien als start. De
## gebruiker moet gewoon op de bel drukken").
##
## Six short pages, told IN the receptie instead of on a sheet: the real world
## stays in view and plays along.  The first three guests of the waiting list
## walk in through the door, get their wish bubbles, are helped, walk out again
## — and the last page dims the hotel, lights up the bell and points at it:
## "🔔 Druk op de bel voor Boef!".  The child rings it; that closes the intro and
## the hotel's own bell brings Boef in for real.
##
## When: a fresh game only (no save at boot, or `Nieuw spel`), never after
## `Verder spelen` — `scenes/main.gd` decides, the save gets no field for it.
##
## The rules of HOTEL.md §9 hold on every page: one sentence with its pictogram
## in front on the same card (`UiTekst.INTRO_*`), ≤ 8 words and ≤ 40 characters,
## never a letter under 12 px, every button ≥ 48 × 48 with a picture beside its
## word.  A tap anywhere goes on (after `drempel_s`, so a double tap does not
## eat a page), `Verder ▸` does the same, `Overslaan ▸▸` is on every page.
##
## Reduced motion (`Ui.rust_modus()`): the same six pages, standing still — the
## guests are PUT where they would have walked to, nothing bounces, pulses,
## sparkles or fades, and they are gone at once instead of walking out.
##
## Nothing here awaits a timer: a page's little choreography is a plan of
## `{t, fn}` steps run from `_process`, so a page that is left early (or an
## intro that is freed with its shell, in a test) leaves no coroutine behind.

signal stap_veranderd(stap: int, aantal: int)
## `hoe`: "overslaan" | "bel" (the child rang the bell) | "tik" (tapped beside
## it on the last page) | "klaar" (`Verder`/Enter on the last page) | "weg" (the
## shell replaced it)
signal klaar(hoe: String)

const EIGENAAR := "intro"        ## owner stamp of the intro's bubbles
const DIER := "intro_"           ## id prefix of the intro's own animals
const GROEP := "intro"           ## the running intro is in this group
const KAMER := "receptie"
## The door the guests come in through, and leave by — see `_ingang()`.
const INGANG_NAAR := "gang"
const DREMPEL := 0.35            ## s a fresh page ignores taps
const BREED := 640               ## the card never gets wider than this ...
const BREED_RIJ := 820           ## ... or this, as one row on a low screen
const RAND := 12                 ## air between the card and the screen edge
const LAAG := 450.0              ## a landscape screen under this is "compact"
const NA_ELKAAR := 0.45          ## s between two guests stepping in
const PLOP_NA := 0.28            ## s between two wish bubbles
## Where the three guests stand: spread over the middle of the floor, left to
## right on the screen, so each one keeps its own bubble above it and none of
## them stands on the check-in spot (65, 44) the real first guest walks to.
const PLEKKEN := [Vector2(26, 64), Vector2(58, 72), Vector2(92, 56)]
## One wish each: the three the hotel grants itself (Hotel.HOTEL_WENS).
const WENSEN := ["kamer", "eten", "spelen"]
const WENS_HOOG := [58, 71, 58]  ## the hotel's own alternation of bubble heights

var drempel_s := DREMPEL         ## tests set 0

var _stap := -1
var _zinnen: Array[String] = []
var _gasten: Array = []          ## {id, naam, kind} of the waiting list, up to three
var _plan: Array = []            ## [{t, fn}] of the page on screen, in order
var _stap_t := 0.0               ## s since the page appeared
var _tijd := 0.0                 ## s since the intro began (pulse and bounce)
var _dicht := false
var _opgeruimd := false          ## the world is clean of the intro (once, see _ruim_op)
var _weg: Dictionary = {}        ## animal id -> true: walking out of the door
var _waas := 0.0                 ## 0..1: how far the last page's dimming is in
var _gat_mid := Vector2.ZERO     ## the spotlight on the bell, in my coordinates
var _gat_r := 0.0
var _pijl_richting := Vector2.DOWN   ## from the bell towards the arrow's tail

var _kaart: PanelContainer
var _kaart_sb: StyleBoxFlat
var _doos: BoxContainer
var _boven: VBoxContainer
var _stippen: Stippen
var _zin: Label
var _rij: HBoxContainer
var _tussen: Control
var _overslaan: Button
var _verder: Button

## The progress dots over the sentence: decoration, never a tap target.
class Stippen extends Control:
	var aantal := 6
	var nu := 0

	func _draw() -> void:
		var stap := 18.0
		var x0 := size.x * 0.5 - (aantal - 1) * stap * 0.5
		for i in aantal:
			var p := Vector2(x0 + i * stap, size.y * 0.5)
			if i == nu:
				draw_circle(p, 6.0, UiThema.PERZIK_D)
			else:
				draw_circle(p, 5.0, UiThema.PERZIK if i < nu else UiThema.KURK)

# ------------------------------------------------------------------ opbouw

## Called by the shell right after `Hotel.start()` of a fresh game.
func begin() -> void:
	name = "Intro"
	add_to_group(GROEP)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Ui.thema
	# The board opens by itself on a morning round; the intro is the start of the
	# game now and the child's first job is the bell, not a list of chores.
	Hotel.bord_dicht()
	if World.kamer_nu() != KAMER:
		Hotel.naar_kamer(KAMER)
	# A clear stage: the hotel's own buttons (doors, bell, board) step aside for
	# the story exactly as they do for a running game — nothing can be tapped
	# through the intro anyway, and with them gone each wish bubble gets the
	# place right over its own animal instead of wherever a band was still free
	# (at 360 × 740 "🛏 bed" hung under the card).  The name plates stay: they
	# are the fixed layer.  The last page gives the stage back, bell and all.
	Hits.voorrang(EIGENAAR)
	_gasten = _eerste_gasten()
	var eerste := str(_gasten[0]["naam"]) if not _gasten.is_empty() else ""
	_zinnen = [UiTekst.INTRO_WELKOM, UiTekst.INTRO_BAAS, UiTekst.INTRO_GASTEN,
		UiTekst.INTRO_WENS, UiTekst.INTRO_SOMMEN, UiTekst.intro_bel(eerste)]
	_bouw()
	resized.connect(_leg_uit)
	Ui.thema_veranderd.connect(_op_thema)
	if _mag_tweenen():
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	_toon(0)

func _bouw() -> void:
	_kaart = PanelContainer.new()
	_kaart.name = "Kaart"
	_kaart_sb = UiThema.vulling(UiThema.vlak(UiThema.KAART, 26, 3, UiThema.WIT), 18, 14)
	_kaart_sb.shadow_color = UiThema.SCHADUW_DIEP
	_kaart_sb.shadow_size = 12
	_kaart_sb.shadow_offset = Vector2(0, 5)
	_kaart.add_theme_stylebox_override("panel", _kaart_sb)
	# the card is part of the "tap anywhere": only its two buttons stop a tap
	_kaart.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_kaart)

	_doos = BoxContainer.new()
	_doos.name = "Doos"
	_doos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_doos.add_theme_constant_override("separation", 10)
	_kaart.add_child(_doos)

	_boven = VBoxContainer.new()
	_boven.name = "Boven"
	_boven.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boven.add_theme_constant_override("separation", 6)
	_boven.alignment = BoxContainer.ALIGNMENT_CENTER
	_doos.add_child(_boven)

	_stippen = Stippen.new()
	_stippen.name = "Stippen"
	_stippen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stippen.aantal = _zinnen.size()
	_stippen.custom_minimum_size = Vector2(_zinnen.size() * 18.0, 14.0)
	_boven.add_child(_stippen)

	_zin = Label.new()
	_zin.name = "Zin"
	_zin.theme_type_variation = "Kop"
	_zin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zin.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The Label trap (architecture.md §4.4): an autowrapping Label reports the
	# height of whatever width it last had — at boot on a phone that was one
	# letter per line and a card of 1139 units.  `clip_text` takes that guess
	# out of the sum; `_leg_uit` gives it the height it really needs, so
	# nothing is ever clipped.
	_zin.clip_text = true
	_zin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boven.add_child(_zin)

	_rij = HBoxContainer.new()
	_rij.name = "Rij"
	_rij.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rij.add_theme_constant_override("separation", 10)
	_rij.alignment = BoxContainer.ALIGNMENT_CENTER
	_doos.add_child(_rij)

	_overslaan = Button.new()
	_overslaan.name = "Koverslaan"
	_overslaan.text = UiTekst.INTRO_OVERSLAAN
	_overslaan.tooltip_text = UiTekst.INTRO_OVERSLAAN_TITEL
	_overslaan.focus_mode = Control.FOCUS_NONE
	# the theme's plain button is card-white on a card-white card: invisible
	# here, so the quiet button gets a peach face and a cork rim of its own
	_overslaan.add_theme_stylebox_override("normal",
		UiThema.vulling(UiThema.vlak(UiThema.BG2, 16, 2, UiThema.KURK), 12, 8))
	_overslaan.add_theme_stylebox_override("hover",
		UiThema.vulling(UiThema.vlak(UiThema.BG2.lerp(UiThema.ZON, 0.35), 16, 2, UiThema.KURK), 12, 8))
	_overslaan.add_theme_stylebox_override("pressed",
		UiThema.vulling(UiThema.vlak(UiThema.PERZIK, 16, 2, UiThema.KURK), 12, 10, 12, 6))
	_overslaan.add_theme_stylebox_override("hover_pressed",
		UiThema.vulling(UiThema.vlak(UiThema.PERZIK, 16, 2, UiThema.KURK), 12, 10, 12, 6))
	_overslaan.pressed.connect(_op_overslaan)
	_rij.add_child(_overslaan)

	_tussen = Control.new()
	_tussen.name = "Tussen"
	_tussen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tussen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rij.add_child(_tussen)

	_verder = Button.new()
	_verder.name = "Kverder"
	_verder.text = UiTekst.INTRO_VERDER
	_verder.tooltip_text = UiTekst.INTRO_VERDER_TITEL
	_verder.theme_type_variation = "KnopActief"
	_verder.focus_mode = Control.FOCUS_NONE
	_verder.pressed.connect(_op_verder)
	_rij.add_child(_verder)

func _op_thema() -> void:
	if _dicht:
		return
	theme = Ui.thema
	_leg_uit()

# ------------------------------------------------------------------ de maat

## The sentence is the one thing on the glass, so it is big — picture-book
## big on a tablet, still two lines at most on a phone.
static func zin_maat(scherm: Vector2) -> int:
	var kort := minf(scherm.x, scherm.y)
	if kort >= 600.0:
		return 30
	if kort >= 420.0:
		return 26
	return 22

## A phone on its side: one row (sentence | buttons) instead of two, or the
## card would take half of a 289 unit frame.
func compact() -> bool:
	return size.x > size.y and size.y < LAAG

## 48 × 48 at the least (`UiThema.HOT`), a little taller where there is room.
func _knop_maat() -> Vector2:
	var tap := maxi(UiThema.HOT, Ui.tap_maat())
	return Vector2(tap, tap if compact() else maxi(tap, 52))

## Lay the card out for this screen and this page.  Every autowrapping Label is
## given its width AND the height that width really takes (the Label trap of
## architecture.md §4.4), so the card is exactly its content.
func _leg_uit() -> void:
	if _kaart == null or _dicht:
		return
	var scherm := size
	if scherm.x < 1.0 or scherm.y < 1.0:
		return
	var mt: Dictionary = Ui.maten
	var klein := compact()
	var laatste := is_laatste()
	_zin.add_theme_font_size_override("font_size", zin_maat(scherm))
	_verder.add_theme_font_size_override("font_size",
		maxi(UiThema.VLOER, int(mt.get("knop" if klein else "knop_groot", 19))))
	_overslaan.add_theme_font_size_override("font_size", maxi(UiThema.VLOER, int(mt.get("basis", 17))))
	var knop := _knop_maat()
	_verder.custom_minimum_size = Vector2(maxf(knop.x, 96.0), knop.y)
	_overslaan.custom_minimum_size = knop
	# the last page has no `Verder`: the bell is the button there
	_verder.visible = not laatste
	_stippen.visible = not klein
	_stippen.nu = _stap
	_stippen.queue_redraw()
	_doos.vertical = not klein
	_tussen.visible = not klein and not laatste
	_rij.alignment = BoxContainer.ALIGNMENT_CENTER if (klein or laatste) else BoxContainer.ALIGNMENT_BEGIN
	_boven.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# one row on a low screen is also a thin row: 8 units of paper above and
	# under the 48 unit buttons, so the card stays on the chrome
	_kaart_sb.content_margin_top = 8.0 if klein else 14.0
	_kaart_sb.content_margin_bottom = 8.0 if klein else 14.0
	var vul := Vector2(_kaart_sb.get_margin(SIDE_LEFT) + _kaart_sb.get_margin(SIDE_RIGHT),
		_kaart_sb.get_margin(SIDE_TOP) + _kaart_sb.get_margin(SIDE_BOTTOM))
	var breed := minf(float(BREED_RIJ if klein else BREED), scherm.x - 2.0 * RAND)
	var binnen := breed - vul.x
	var zin_breed := binnen
	if klein:
		zin_breed = maxf(120.0, binnen - _rij_breed() - 10.0)
	if _stap >= 0 and _stap < _zinnen.size():
		_zin.text = _mooi_gebroken(_zinnen[_stap], zin_breed)
	_zin.custom_minimum_size = Vector2(zin_breed, UiThema.wrap_hoogte(_zin, zin_breed))
	_rij.custom_minimum_size = Vector2(0.0 if klein else binnen, 0.0)
	var maat := _kaart.get_combined_minimum_size()
	maat.x = breed
	_kaart.size = maat
	# Tall screens: at the bottom, over the room bar and the front of the floor.
	# A phone on its side has a frame of 289 units, and at the bottom the card
	# took the band the wish bubbles need; there it lies over the chrome at the
	# top instead, which has nothing to tap while the intro runs anyway.
	var x := (scherm.x - breed) * 0.5
	var onder := Vector2(x, scherm.y - maat.y - float(RAND))
	var boven := Vector2(x, 2.0 if klein else float(RAND))
	var plek := boven if klein else onder
	# on the last page the card never covers what it points at
	if laatste and _gat_r > 0.0:
		var gat := Rect2(_gat_mid - Vector2.ONE * _gat_r, Vector2.ONE * _gat_r * 2.0)
		if Rect2(plek, maat).intersects(gat):
			plek = onder if klein else boven
	_kaart.position = plek
	queue_redraw()

## A sentence that needs two lines gets two lines of about the same length —
## never one word left alone on the second ("… help je de / dieren!") and never
## the pictogram alone on the first.  One line when it fits; the Label's own
## wrap is the fallback if no split fits at all.
func _mooi_gebroken(tekst: String, breed: float) -> String:
	var f := _zin.get_theme_font("font")
	var maat := _zin.get_theme_font_size("font_size")
	if f == null or breed <= 1.0:
		return tekst
	var meet := func(s: String) -> float:
		return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, maat).x
	if float(meet.call(tekst)) <= breed:
		return tekst
	var woorden := tekst.split(" ", false)
	var beste := tekst
	var beste_w := INF
	for i in range(2, woorden.size()):
		var een := " ".join(woorden.slice(0, i))
		var twee := " ".join(woorden.slice(i))
		var w := maxf(float(meet.call(een)), float(meet.call(twee)))
		if w <= breed and w < beste_w:
			beste_w = w
			beste = een + "\n" + twee
	return beste

func _rij_breed() -> float:
	var b := 0.0
	var n := 0
	for k in [_overslaan, _verder]:
		if (k as Control).visible:
			b += (k as Control).get_combined_minimum_size().x
			n += 1
	return b + maxf(0.0, n - 1) * 10.0

# ------------------------------------------------------------------ de pagina's

func stap() -> int:
	return _stap

func aantal() -> int:
	return _zinnen.size()

## The sentence of the page on screen, as it is written (the Label may carry
## it over two balanced lines).
func zin() -> String:
	return _zinnen[_stap] if _stap >= 0 and _stap < _zinnen.size() else ""

func zinnen() -> Array[String]:
	return _zinnen.duplicate()

func is_laatste() -> bool:
	return _stap >= _zinnen.size() - 1

func is_dicht() -> bool:
	return _dicht

## The intro's own animals that are in the world right now.
func dieren() -> Array[String]:
	var uit: Array[String] = []
	for g in _gasten:
		var id := DIER + str(g["id"])
		if World.dier(id) != null:
			uit.append(id)
	return uit

## Where a guest of the intro is headed, by index, in floor voxels.
func plek_van(i: int) -> Vector2:
	return PLEKKEN[i % PLEKKEN.size()]

## True while something on screen moves because of the intro: a tween, the
## pulse on the bell, a guest walking in or out.  Always false with reduced
## motion — that is the whole promise of `Ui.rust_modus()`.
func beweegt() -> bool:
	if _rust() or _dicht:
		return false
	if is_laatste() and _gat_r > 0.0:
		return true
	for id in dieren():
		var d = World.dier(id)
		# "komt": coming in through the front door (`World.kom_binnen`)
		if d != null and str(d.staat) in ["loop", "komt"]:
			return true
	return false

## Where the spotlight is, in the shell's coordinates (= my own, I cover it).
func gat() -> Rect2:
	if _gat_r <= 0.0:
		return Rect2()
	return Rect2(_gat_mid - Vector2.ONE * _gat_r, Vector2.ONE * _gat_r * 2.0)

func kaart_rect() -> Rect2:
	return _kaart.get_global_rect() if _kaart != null else Rect2()

func knop_verder() -> Button:
	return _verder

func knop_overslaan() -> Button:
	return _overslaan

func zin_label() -> Label:
	return _zin

func _toon(i: int) -> void:
	# a page that was left early finishes what it was doing first (the guests
	# still on their way in step in now), so no page misses its world
	_voer_plan_uit(INF)
	_stap = clampi(i, 0, _zinnen.size() - 1)
	_stap_t = 0.0
	_plan.clear()
	_zin.text = _zinnen[_stap]
	match _stap:
		0:
			Snd.tover()
			_fonkel(_ingang(), 18.0, 6)
			var bel := _plek_van_ding("bel")
			_fonkel(bel, 16.0, 6)
		1:
			Snd.ster()
			for x in [44.0, 66.0, 88.0]:
				_fonkel(Vector2(x, 22.0), 17.0, 4)
		2:
			Snd.deur()
			for n in _gasten.size():
				var k := n
				_plan_in(n * NA_ELKAAR, func() -> void: _kom_binnen(k))
		3:
			_zorg_voor_dieren()
			for n in _gasten.size():
				var k := n
				_plan_in(n * PLOP_NA, func() -> void: _wens(k, false))
		4:
			_zorg_voor_dieren()
			Snd.hoera()
			for n in _gasten.size():
				_wens(n, true)
				var id := DIER + str(_gasten[n]["id"])
				if not _rust():
					World.mood(id, "blij")
				var d = World.dier(id)
				if d != null:
					_fonkel(Vector2(d.x, d.z), 26.0, 5)
		_:
			Snd.dag()
			Hits.wis_eigenaar(EIGENAAR)
			_geef_podium_terug()          # the bell is back on the glass
			for id in dieren():
				_ga_weg(id)
			_volg_bel()
			if _mag_tweenen():
				_waas = 0.0
				create_tween().tween_method(_zet_waas, 0.0, 1.0, 0.3)
			else:
				_waas = 1.0
	# with reduced motion the whole page is there at once, as a still picture
	if _rust():
		_voer_plan_uit(INF)
	_leg_uit()
	if _mag_tweenen():
		_zin.pivot_offset = _zin.custom_minimum_size * 0.5
		_zin.scale = Vector2(0.92, 0.92)
		_zin.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(_zin, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_zin, "modulate:a", 1.0, 0.14)
	stap_veranderd.emit(_stap, _zinnen.size())

func _zet_waas(w: float) -> void:
	_waas = w
	queue_redraw()

## The next page, or the end after the last one.
func verder() -> void:
	if _dicht or _te_vroeg():
		return
	if is_laatste():
		sluit("klaar")
		return
	_toon(_stap + 1)

func overslaan() -> void:
	if _dicht or _te_vroeg():
		return
	sluit("overslaan")

## A tap on the glass, in my coordinates.  On the last page a tap in the light
## is a tap on the bell; a tap beside it ends the intro without ringing.
func tik_op(punt: Vector2) -> void:
	if _dicht or _te_vroeg():
		return
	if is_laatste():
		if _gat_r > 0.0 and punt.distance_to(_gat_mid) <= _gat_r:
			druk_bel()
		else:
			sluit("tik")
		return
	verder()

## The child rings: the intro goes, and the bell's own button is pressed — the
## same sound, the same `[probe] tik`, the same `Hotel.bel()` as a real tap.
func druk_bel() -> void:
	if _dicht:
		return
	var knop := _bel_knop()
	sluit("bel")
	if knop != null:
		knop.pressed.emit()

## Every button of the game says `tik` when it is pressed (world.md §6.6).
func _op_verder() -> void:
	if not _dicht and not _te_vroeg():
		Snd.tik()
	verder()

func _op_overslaan() -> void:
	if not _dicht and not _te_vroeg():
		Snd.tik()
	overslaan()

func _te_vroeg() -> bool:
	return _stap_t < drempel_s

func _gui_input(ev: InputEvent) -> void:
	var m := ev as InputEventMouseButton
	if m != null and m.pressed and m.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		tik_op(m.position)

func _unhandled_key_input(ev: InputEvent) -> void:
	if _dicht:
		return
	if ev.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		overslaan()
	elif ev.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		verder()

# ------------------------------------------------------------------ het einde

## Close, whatever the reason: everything the intro put in the world goes with
## it, and it stops catching taps at once (the fade is only for the eye).
func sluit(hoe: String) -> void:
	if _dicht:
		return
	_dicht = true
	_plan.clear()
	remove_from_group(GROEP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	propagate_call("set", ["mouse_filter", Control.MOUSE_FILTER_IGNORE])
	for k in [_overslaan, _verder]:
		(k as Button).disabled = true
	_ruim_op()
	klaar.emit(hoe)
	if _mag_tweenen() and is_inside_tree():
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.2)
		tw.finished.connect(queue_free)
	else:
		queue_free()

## Once only: an intro that is freed a frame after it closed must not tidy up
## what a NEW intro has put in the world in the meantime (same owner, same ids).
func _ruim_op() -> void:
	if _opgeruimd:
		return
	_opgeruimd = true
	Hits.wis_eigenaar(EIGENAAR)
	_geef_podium_terug()
	for g in _gasten:
		World.weg(DIER + str(g["id"]))
	_weg.clear()

## The hotel's buttons back — only if the priority is still ours: a game that
## took it in the meantime keeps it.
func _geef_podium_terug() -> void:
	if Hits.voorrang_van() == EIGENAAR:
		Hits.voorrang("")

## A shell that is torn down with the intro still up (a test, a reload) leaves
## no animal and no bubble behind in the autoloads.
func _exit_tree() -> void:
	if Ui.thema_veranderd.is_connected(_op_thema):
		Ui.thema_veranderd.disconnect(_op_thema)
	_ruim_op()

# ------------------------------------------------------------------ de wereld

## Where the guests come in and where they go out again: the point just inside
## the receptie by its door (world.md §1.2).  ONE place on purpose — the lead,
## 2026-09-23: the receptie is getting a real front entrance on branch
## `binnenkomst`; point this at it and the intro's guests use it both ways.
func _ingang() -> Vector2:
	# the receptie's own front door (`Rooms.ingang`, the binnenkomst of
	# 2026-09-23): the guests of the story come in and go out where every real
	# guest does; the corridor door only when a room has no front door
	var voor := Rooms.ingang(KAMER)
	if not voor.is_empty():
		return Vector2(float(voor.get("ix", 8.0)), float(voor.get("iz", 30.0)))
	var dp := Rooms.deur(KAMER, INGANG_NAAR)
	if dp.is_empty():
		return Vector2(8, 30)
	return Vector2(float(dp.get("ix", 8.0)), float(dp.get("iz", 30.0)))

## The first guests of the waiting list — the ones the bell will bring, in that
## order, so the animal the last page names is the one that really comes.
func _eerste_gasten() -> Array:
	var uit: Array = []
	for g in State.s.get("wachtlijst", []):
		if typeof(g) != TYPE_DICTIONARY:
			continue
		uit.append({"id": str(g.get("id", "")), "naam": str(g.get("naam", "")),
			"kind": str(g.get("kind", "hond"))})
		if uit.size() >= PLEKKEN.size():
			break
	return uit

func _kom_binnen(i: int) -> void:
	if i >= _gasten.size():
		return
	var g: Dictionary = _gasten[i]
	var id := DIER + str(g["id"])
	if World.dier(id) != null:
		return
	var p := plek_van(i)
	var o := {"naam": str(g["naam"]), "kind": str(g["kind"]), "nr": i}
	if _rust():
		# reduced motion: put, never walk — and hold still
		World.zet(id, KAMER, p.x, p.y, o)
		World.pose(id, "rust", 100000)
		return
	var ing := _ingang()
	World.zet(id, KAMER, ing.x, ing.y, o)
	# each kind comes in its own way, through the front door, exactly as a
	# guest the bell brings (`World.kom_binnen`)
	if not World.kom_binnen(id, p.x, p.y, KAMER):
		World.ga(id, p.x, p.y, "wacht")
	Snd.hup()

## A page that was skipped past quickly still has all its guests.
func _zorg_voor_dieren() -> void:
	_voer_plan_uit(INF)
	for i in _gasten.size():
		_kom_binnen(i)

## The wish bubble of guest `i`: pictogram and word in one bubble, like the
## hotel's own (`Hotel._wens_wolken`).  `goed`: the wish came true — mint, ✓.
##
## The bubble takes the place of the name plate: a plate is the fixed layer of
## the band grid and is placed first, right over the head, so with it the
## bubble went BELOW its animal — at 1536 × 760 "🛏 bed" hung nearer to Muis
## than to Boef.  The names were on the page before; this page is the wishes.
func _wens(i: int, goed: bool) -> void:
	if i >= _gasten.size():
		return
	var id := DIER + str(_gasten[i]["id"])
	if World.dier(id) == null:
		return
	_zonder_naam(id)
	var soort: String = WENSEN[i % WENSEN.size()]
	var bh: Dictionary = State.BEHOEFTE.get(soort, {})
	var woord := Hotel.wens_woord(soort)
	var hoog: int = WENS_HOOG[i % WENS_HOOG.size()]
	Ui.wolk({"id": "%swens_%d" % [DIER, i], "door": EIGENAAR, "kamer": KAMER, "hoog": hoog,
		"icoon": str(bh.get("icoon", "✨")), "tekst": ("%s ✓" % woord) if goed else woord,
		"klas": "hotwens goed" if goed else "hotwens", "prio": 6,
		"volg": _volg_dier(id, hoog), "tik": func(_s) -> void: pass})
	if not goed:
		Snd.plop(i)

func _volg_dier(id: String, hoog: float) -> Callable:
	return func() -> Dictionary:
		var d = World.dier(id)
		if d == null:
			return {}
		return {"x": d.x, "z": d.z, "y": hoog, "kamer": d.kamer,
			"vlak": World.vlak_van_dier(id), "d": d.x + d.z + 0.6}

## Off through the door again: they wait outside until the bell calls them.
## They go without their name plates: a plate is a cell in the band grid, and
## three of them walking to the door pushed the door's own sign into the light
## on the bell (seen at 360 × 740).
func _ga_weg(id: String) -> void:
	if _rust():
		World.weg(id)
		return
	if World.dier(id) == null:
		return
	_zonder_naam(id)
	var ing := _ingang()
	_weg[id] = true
	World.ga(id, ing.x, ing.y, "")

## Take the name plate off one of the intro's own animals.  The room draws a
## plate for every animal with a name (`scenes/kamer.gd`), so the name itself
## goes; the animal keeps walking or standing as it was.
func _zonder_naam(id: String) -> void:
	var d = World.dier(id)
	if d == null or str(d.naam).is_empty():
		return
	d.naam = ""
	Ui.naamplaat_weg(id)
	World.vuil()

## Guests that reached the door are gone; a little puff where they left.
func _ruim_vertrokken() -> void:
	if _weg.is_empty():
		return
	var ing := _ingang()
	for id in _weg.keys():
		var d = World.dier(id)
		if d == null:
			_weg.erase(id)
			continue
		if Vector2(d.x, d.z).distance_to(ing) <= 1.5 and str(d.staat) != "loop":
			World.weg(id)
			_weg.erase(id)
			_fonkel(ing, 10.0, 4)

func _plek_van_ding(naam: String) -> Vector2:
	var p := Hotel.decor_plek(KAMER, naam)
	if p.is_empty():
		return Vector2(36, 20)
	return Vector2(float(p.get("x", 36.0)), float(p.get("z", 20.0)))

## Sparkles — `World.spetter` does nothing with reduced motion.
func _fonkel(p: Vector2, hoog: float, n: int) -> void:
	World.spetter(KAMER, p.x, p.y, n, ArtEffect.STER_KL[0], true, hoog)

func _plan_in(t: float, fn: Callable) -> void:
	_plan.append({"t": t, "fn": fn})

func _voer_plan_uit(tot: float) -> void:
	while not _plan.is_empty() and float(_plan[0]["t"]) <= tot:
		var stuk: Dictionary = _plan.pop_front()
		(stuk["fn"] as Callable).call()

func _process(delta: float) -> void:
	if _dicht:
		return
	_tijd += delta
	_stap_t += delta
	_voer_plan_uit(_stap_t)
	_ruim_vertrokken()
	if is_laatste():
		_volg_bel()

func _rust() -> bool:
	return Ui.rust_modus()

## Tweens only where somebody can see them move: not with reduced motion, not
## headless (the suite measures rectangles, and a card half-way through its
## pop-in has another one).
func _mag_tweenen() -> bool:
	return not _rust() and DisplayServer.get_name() != "headless"

# ------------------------------------------------------------------ de bel

func _bel_knop() -> BaseButton:
	var s = Hits.spot("bel")
	if s == null or not is_instance_valid(s.knoop) or not (s.knoop as Control).visible:
		return null
	return s.knoop as BaseButton

## The bell and its button under one light, followed every frame: the buttons
## of the room are placed again whenever something moves.
func _volg_bel() -> void:
	var knop := _bel_knop()
	if knop == null:
		if _gat_r > 0.0:
			_gat_r = 0.0
			_leg_uit()
		return
	var r := knop.get_global_rect()
	var dbg: Dictionary = Hits.debug().get("bel", {})
	var vlak: Rect2 = dbg.get("vlak", Rect2())
	if vlak.size.x > 0.0 and vlak.size.y > 0.0 and Ui.knoplaag != null:
		r = r.merge(Rect2(vlak.position + Ui.knoplaag.get_global_rect().position, vlak.size))
	r.position -= get_global_rect().position
	var mid := r.get_center()
	var straal := maxf(r.size.x, r.size.y) * 0.5 + 10.0
	var nieuw := not mid.is_equal_approx(_gat_mid) or not is_equal_approx(straal, _gat_r)
	var had := _gat_r > 0.0
	_gat_mid = mid
	_gat_r = straal
	if not had:
		_leg_uit()
	_kies_pijl()
	if nieuw or not _rust():
		queue_redraw()

## From which side the arrow comes: the first side where it fits on the screen
## and stays off the card.  Below the bell is the floor in front of the desk.
func _kies_pijl() -> void:
	var kaart := _kaart.get_rect() if _kaart != null else Rect2()
	var scherm := Rect2(Vector2.ZERO, size).grow(-4.0)
	for richting in [Vector2.DOWN, Vector2(-0.707, 0.707), Vector2(0.707, 0.707),
			Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
		var v: Vector2 = richting
		var punt := _gat_mid + v * (_gat_r + 10.0)
		var staart := punt + v * 72.0
		var vak := Rect2(punt, Vector2.ZERO).expand(staart).grow(18.0)
		if scherm.encloses(vak) and not vak.intersects(kaart):
			_pijl_richting = v
			return
	_pijl_richting = Vector2.DOWN

# ------------------------------------------------------------------ tekenen

func _draw() -> void:
	if _dicht or not is_laatste() or _gat_r <= 0.0 or _waas <= 0.0:
		return
	var puls := 0.0 if _rust() else sin(_tijd * 4.0)
	_teken_waas(_gat_mid, _gat_r + 6.0, Color(0.29, 0.231, 0.2, 0.46 * _waas))
	var ring := _gat_r + 2.0 + 3.0 * puls
	draw_arc(_gat_mid, ring + 4.0, 0.0, TAU, 64, Color(1, 1, 1, 0.85 * _waas), 3.0, true)
	draw_arc(_gat_mid, ring, 0.0, TAU, 64, Color(UiThema.ZON, _waas), 6.0, true)
	var hup := 0.0 if _rust() else 7.0 * (0.5 + 0.5 * sin(_tijd * 6.0))
	var v := _pijl_richting
	var punt := _gat_mid + v * (_gat_r + 10.0 + hup)
	var pijl := _pijl_punten(punt, (-v).angle())
	var schaduw := PackedVector2Array()
	for p in pijl:
		schaduw.append(p + Vector2(0, 3))
	draw_colored_polygon(schaduw, Color(UiThema.SCHADUW_DIEP, UiThema.SCHADUW_DIEP.a * _waas))
	draw_colored_polygon(pijl, Color(UiThema.PERZIK_D, _waas))
	var rand := pijl.duplicate()
	rand.append(pijl[0])
	draw_polyline(rand, Color(1, 1, 1, _waas), 3.0, true)

## A chunky arrow with its tip at `punt`, pointing along `hoek`.
static func _pijl_punten(punt: Vector2, hoek: float) -> PackedVector2Array:
	var vorm := [Vector2(0, 0), Vector2(-28, -19), Vector2(-28, -8), Vector2(-70, -8),
		Vector2(-70, 8), Vector2(-28, 8), Vector2(-28, 19)]
	var uit := PackedVector2Array()
	for p in vorm:
		uit.append(punt + (p as Vector2).rotated(hoek))
	return uit

## The dimmed hotel with one round hole of light.  Two simple polygons — the
## left and the right half of the screen, each with half the circle bitten out —
## because a polygon with a hole is not something `draw_colored_polygon` does.
## The outer box grows past the screen when the light is near an edge, so the
## straight seam never runs backwards.
func _teken_waas(mid: Vector2, r: float, kleur: Color) -> void:
	var l := minf(0.0, mid.x - r - 2.0)
	var t := minf(0.0, mid.y - r - 2.0)
	var re := maxf(size.x, mid.x + r + 2.0)
	var o := maxf(size.y, mid.y + r + 2.0)
	var n := 28
	var links := PackedVector2Array([Vector2(l, t), Vector2(mid.x, t)])
	var rechts := PackedVector2Array([Vector2(re, t), Vector2(mid.x, t)])
	for i in n + 1:
		var f := float(i) / float(n)
		links.append(mid + Vector2.from_angle(-PI * 0.5 - PI * f) * r)
		rechts.append(mid + Vector2.from_angle(-PI * 0.5 + PI * f) * r)
	links.append_array([Vector2(mid.x, o), Vector2(l, o)])
	rechts.append_array([Vector2(mid.x, o), Vector2(re, o)])
	draw_colored_polygon(links, kleur)
	draw_colored_polygon(rechts, kleur)
