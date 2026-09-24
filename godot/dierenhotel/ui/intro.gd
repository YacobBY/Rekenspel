class_name UiIntro
extends Control
## The start of a fresh game: one welcome card over the receptie, and it goes
## by itself (owner, 2026-09-24: "Ik wil ook geen intro waar je 5x door moet
## klikken. Maakt het veel korter en zonder tutorial dat lukt de kinderen zelf
## wel").
##
## It replaces the six-page story of 2026-09-23 (guests walking in, wishes, a
## spotlight on the bell, `Verder ▸` / `Overslaan ▸▸`): no pages, no buttons,
## nothing explained.  After `DUUR` seconds — or at the first tap or key — the
## card is gone and the hotel is the child's.  The bell already pulses in the
## morning round (`Hotel.hotspots`), and that is the only hint the game gives.
##
## When: a fresh game only (no save at boot, or `Nieuw spel`), never after
## `Verder spelen` — `scenes/main.gd` decides, the save gets no field for it.
## Reduced motion (`Ui.rust_modus()`): the same card, standing still, gone
## after the same time.  Nothing here awaits a timer: `_process` counts.

## Kept for the shell's probe line: one step of one.
signal stap_veranderd(stap: int, aantal: int)
## `hoe`: "vanzelf" (its time ran out) | "tik" (a tap or a key) | "weg" (the
## shell replaced it)
signal klaar(hoe: String)

const GROEP := "intro"           ## the running intro is in this group
const EIGENAAR := "intro"        ## who has `Hits.voorrang` while the card is up
const KAMER := "receptie"
const DUUR := 2.5                ## s the welcome stays on the glass
const DREMPEL := 0.35            ## s a fresh card ignores taps (the tap that started the game)
const BREED := 640               ## the card never gets wider than this
const RAND := 12                 ## air between the card and the screen edge

## What a NEW card's `duur_s` starts at.  The suite raises it while it looks
## at a card (booting a shell can take longer than `DUUR` of real time) and
## lowers it to see the card go by itself.
static var duur_standaard := DUUR
var duur_s := duur_standaard
var drempel_s := DREMPEL         ## tests set 0

var _t := 0.0                    ## s since the card appeared
var _dicht := false
var _kaart: PanelContainer
var _zin: Label

func begin() -> void:
	name = "Intro"
	add_to_group(GROEP)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# a tap anywhere ends it, so nothing under it can be hit by accident
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Ui.thema
	# the board opens by itself on a morning round; the child starts in the
	# receptie with the pulsing bell, not with a list of chores
	Hotel.bord_dicht()
	if World.kamer_nu() != KAMER:
		Hotel.naar_kamer(KAMER)
	# The hotel's buttons live on a layer drawn over the shell, so they would
	# stand ON the card; for these few seconds they step aside, exactly as for
	# a running game, and come back — bell pulsing — when the card goes.
	Hits.voorrang(EIGENAAR)
	_bouw()
	resized.connect(_leg_uit)
	if not Ui.thema_veranderd.is_connected(_op_thema):
		Ui.thema_veranderd.connect(_op_thema)
	_leg_uit()
	Snd.tover()
	var bel := Hotel.decor_plek(KAMER, "bel")
	if not bel.is_empty():
		# sparkles — `World.spetter` does nothing with reduced motion
		World.spetter(KAMER, float(bel.get("x", 36.0)), float(bel.get("z", 20.0)), 6,
			ArtEffect.STER_KL[0], true, 16.0)
	if _mag_tweenen():
		_kaart.pivot_offset = _kaart.size * 0.5
		_kaart.scale = Vector2(0.9, 0.9)
		_kaart.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(_kaart, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_kaart, "modulate:a", 1.0, 0.16)
	stap_veranderd.emit(0, 1)

func _bouw() -> void:
	_kaart = PanelContainer.new()
	_kaart.name = "Kaart"
	var sb := UiThema.vulling(UiThema.vlak(UiThema.KAART, 26, 3, UiThema.WIT), 22, 16)
	sb.shadow_color = UiThema.SCHADUW_DIEP
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 5)
	_kaart.add_theme_stylebox_override("panel", sb)
	_kaart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_kaart)
	_zin = Label.new()
	_zin.name = "Zin"
	_zin.theme_type_variation = "Kop"
	_zin.text = UiTekst.INTRO_WELKOM
	_zin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zin.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# the Label trap (architecture.md §4.4): `_leg_uit` gives it the height its
	# width really takes, so this only takes the Label's own guess out
	_zin.clip_text = true
	_zin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kaart.add_child(_zin)

func _op_thema() -> void:
	if _dicht:
		return
	theme = Ui.thema
	_leg_uit()

## The sentence is the one thing on the glass: picture-book big on a tablet,
## still two lines at most on a phone.
static func zin_maat(scherm: Vector2) -> int:
	var kort := minf(scherm.x, scherm.y)
	if kort >= 600.0:
		return 32
	if kort >= 420.0:
		return 28
	return 24

## The card in the middle of the screen, a little above centre, exactly as big
## as its sentence.
func _leg_uit() -> void:
	if _kaart == null or _dicht:
		return
	var scherm := size
	if scherm.x < 1.0 or scherm.y < 1.0:
		return
	_zin.add_theme_font_size_override("font_size", zin_maat(scherm))
	var sb := _kaart.get_theme_stylebox("panel")
	var vul := Vector2(sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT),
		sb.get_margin(SIDE_TOP) + sb.get_margin(SIDE_BOTTOM))
	var f := _zin.get_theme_font("font")
	var nodig := f.get_string_size(_zin.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		_zin.get_theme_font_size("font_size")).x + 2.0 if f != null else 300.0
	var breed := minf(minf(float(BREED), scherm.x - 2.0 * RAND), nodig + vul.x)
	var zin_breed := breed - vul.x
	_zin.custom_minimum_size = Vector2(zin_breed, UiThema.wrap_hoogte(_zin, zin_breed))
	var maat := _kaart.get_combined_minimum_size()
	maat.x = breed
	_kaart.size = maat
	_kaart.position = Vector2((scherm.x - breed) * 0.5,
		clampf(scherm.y * 0.4 - maat.y * 0.5, float(RAND), scherm.y - maat.y - float(RAND)))
	_kaart.pivot_offset = maat * 0.5

# ------------------------------------------------------------------ vragen

func stap() -> int:
	return 0

func aantal() -> int:
	return 1

func zin() -> String:
	return UiTekst.INTRO_WELKOM

func is_dicht() -> bool:
	return _dicht

func kaart_rect() -> Rect2:
	return _kaart.get_global_rect() if _kaart != null else Rect2()

func zin_label() -> Label:
	return _zin

# ------------------------------------------------------------------ het einde

func _process(delta: float) -> void:
	if _dicht:
		return
	# a stuttering frame (the web export compiling its first shaders) counts
	# for at most a tenth of a second: the child really sees the card for
	# about `DUUR`, not one long hitch
	_t += minf(delta, 0.1)
	if _t >= duur_s:
		sluit("vanzelf")

func _gui_input(ev: InputEvent) -> void:
	var m := ev as InputEventMouseButton
	if m != null and m.pressed and m.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if not _dicht and _t >= drempel_s:
			sluit("tik")

func _unhandled_key_input(ev: InputEvent) -> void:
	if _dicht:
		return
	if ev.is_action_pressed("ui_cancel") or ev.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		sluit("tik")

## Close, whatever the reason: it stops catching taps at once (the fade is
## only for the eye).
func sluit(hoe: String) -> void:
	if _dicht:
		return
	_dicht = true
	remove_from_group(GROEP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_geef_podium_terug()
	klaar.emit(hoe)
	if _mag_tweenen() and is_inside_tree():
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.2)
		tw.finished.connect(queue_free)
	else:
		queue_free()

func _exit_tree() -> void:
	if Ui.thema_veranderd.is_connected(_op_thema):
		Ui.thema_veranderd.disconnect(_op_thema)
	_geef_podium_terug()

## The hotel's buttons back — only if the priority is still ours: a game that
## took it in the meantime keeps it.
func _geef_podium_terug() -> void:
	if Hits.voorrang_van() == EIGENAAR:
		Hits.voorrang("")

## Tweens only where somebody can see them move: not with reduced motion, not
## headless (the suite measures rectangles).
func _mag_tweenen() -> bool:
	return not Ui.rust_modus() and DisplayServer.get_name() != "headless"
