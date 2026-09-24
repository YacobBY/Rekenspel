class_name UiKamerbalk
extends ScrollContainer
## The room bar (world.md §6.3): one chip per room, then the map chip.
##
## Built ONCE and only updated afterwards — in the HTML a rebuild scrolled the
## row back to the left on every event and the child tapped the wrong room.
##
## It has three shapes (architecture.md §4.5):
##   * a wrapping grid, the default: every chip visible, as many columns as fit;
##   * a three-column rail beside the frame in the compact landscape shell, which
##     scrolls up and down once the hotel has more rooms than it can show (R1);
##   * ONE SCROLLING ROW on a phone in portrait (I1 finding 4) — nine wrapped
##     chips cost 152 units of a 740 unit screen there, which pushed the world
##     frame down to 54 %.  The row keeps the whole chip (picture AND word,
##     HOTEL.md §9), the current room is always scrolled into view, and the map
##     chip opens the sheet that lists every room, so nothing becomes
##     unreachable by scrolling.
##
## The scrolling is why this is a `ScrollContainer` with the grid inside it: with
## both scroll modes disabled it measures and lays out exactly like the plain
## grid it used to be.

signal kamer_gekozen(kamer: String)
signal kaart_gevraagd()
## The chips stepped aside for a sum, or came back (`verstop`).
signal verstopt_veranderd(aan: bool)

const GAT := 4
const RAIL_KOLOMMEN := 3
const RAIL_BREED := UiThema.HOT   ## art-sound-rules.md §16.4: repeat(3, 48px)
const VULLING := 6            ## the chip's own padding, both sides
## ... and the tighter padding a row of chips takes before it wraps (R3): with
## the kas the hotel has eleven chips, one row needs 1029 units, and a 1000
## unit tablet (1024 × 768) would put the last chip on a second row — which
## takes a whole band of height from the world frame (990 × 637 → 990 × 585).
const VULLING_KRAP := 4

var _chips: Dictionary = {}   ## kamer id -> Button ("" = the map chip)
var _rail := false
var _strook := false
var _rolt := false            ## the rail ran out of height and scrolls (R1)
var _maten: Dictionary = {}
var _raster: GridContainer = null
var _verstopt := false        ## a sum is being answered: the chips step aside
var _muis := Control.MOUSE_FILTER_STOP   ## the bar's own filter, while shown
var _vervaag: Tween = null

## How long the chips take to fade out and back in (not in reduced motion).
const VERVAAG_S := 0.15

func bouw(mt: Dictionary) -> void:
	name = "Kamerbalk"
	_maten = mt
	if _raster == null or not is_instance_valid(_raster):
		_raster = GridContainer.new()
		_raster.name = "Raster"
		add_child(_raster)
	_raster.add_theme_constant_override("h_separation", GAT)
	_raster.add_theme_constant_override("v_separation", GAT)
	_raster.columns = 1
	follow_focus = true
	_zet_rollen(false)
	vul()

## The bar scrolls in the phone row, and in the rail when the hotel has grown
## more rooms than the rail can show (`_meet_rail`); everywhere else it is a
## plain grid that reports its full size, so the shell can give it exactly that.
func _zet_rollen(strook: bool, rol_v := false) -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if strook \
		else ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if rol_v \
		else ScrollContainer.SCROLL_MODE_DISABLED

## (Re)create the chips.  Called once at boot and again when `Rooms` changes.
func vul() -> void:
	for k in _raster.get_children():
		_raster.remove_child(k)
		k.queue_free()
	_chips.clear()
	for id in Rooms.lijst():
		var r := Rooms.get_kamer(id)
		if r == null:
			continue
		_chips[id] = _chip(id, r.icoon, r.naam, UiTekst.ga_naar(r.naam))
	_chips[""] = _chip("", "🗺️", "Plattegrond", UiTekst.KAART_TITEL)
	pas_aan(size.x, _rail, 0.0, _strook)

## `kamer id -> Button` ("" = the map chip), for the probe.
func chips() -> Dictionary:
	return _chips

func _chip(id: String, icoon: String, naam: String, titel: String) -> Button:
	var b := Button.new()
	b.name = "C" + (id if id != "" else "kaart")
	b.theme_type_variation = "Kamerchip"
	b.tooltip_text = titel
	b.focus_mode = Control.FOCUS_ALL
	b.toggle_mode = true
	_raster.add_child(b)
	# A Button is not a Container, so the content is anchored to its rectangle
	# and the chip's minimum size is taken from that content once, here.
	var rij := BoxContainer.new()
	rij.name = "Rij"
	rij.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rij.add_theme_constant_override("separation", 3)
	rij.set_anchors_preset(Control.PRESET_FULL_RECT)
	rij.offset_left = VULLING
	rij.offset_right = -VULLING
	rij.offset_top = 2
	rij.offset_bottom = -2
	rij.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(rij)
	rij.add_child(_tekst("Icoon", icoon, _maten["icoon"]))
	# the rail shrinks the picture, never the word (see pas_aan)
	var nm := _tekst("Naam", naam, maxi(UiThema.VLOER, _maten["klein"]))
	nm.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	rij.add_child(nm)
	var bdg := _tekst("Wacht", "", UiThema.VLOER)
	bdg.add_theme_stylebox_override("normal",
		UiThema.vulling(UiThema.vlak(UiThema.PERZIK, 999, 2, UiThema.WIT), 4, 0))
	bdg.visible = false
	rij.add_child(bdg)
	b.pressed.connect(func() -> void:
		if _verstopt:
			return            # a chip that stepped aside does nothing
		Snd.tik()
		if id == "":
			kaart_gevraagd.emit()
		else:
			kamer_gekozen.emit(id))
	_zet_chip(b, _verstopt)
	return b

func _tekst(naam: String, tekst: String, maat: int) -> Label:
	var l := Label.new()
	l.name = naam
	l.text = tekst
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", maxi(UiThema.VLOER, maat))
	l.add_theme_color_override("font_color", UiThema.INKT)
	return l

## The waiting-guest counter per room; `Hotel` owns the number (W2).
func ververs() -> void:
	for id in _chips.keys():
		var b: Button = _chips[id]
		var bdg: Label = b.get_node_or_null("Rij/Wacht")
		if bdg != null:
			var n := 0
			if id != "" and Hotel.has_method("wacht_in"):
				n = int(Hotel.call("wacht_in", id))
			var nieuw_tekst := str(n)
			if bdg.text != nieuw_tekst and n > 0 and not Ui.rust_modus() and DisplayServer.get_name() != "headless" and bdg.is_inside_tree():
				bdg.pivot_offset = bdg.size * 0.5
				bdg.scale = Vector2(1.2, 1.2)
				var tw := bdg.create_tween()
				tw.tween_property(bdg, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			bdg.text = nieuw_tekst
			bdg.visible = n > 0
		b.set_pressed_no_signal(id != "" and id == World.kamer_nu())
	_toon_huidige()

## In a scrolling bar the room you are in must be on screen — and only then is
## anything scrolled, so the bar never jumps back under the child's finger.
## The row scrolls sideways, the overflowing rail up and down.
func _toon_huidige() -> void:
	if (not _strook and not _rolt) or size.x <= 0.0:
		return
	var b: Button = _chips.get(World.kamer_nu())
	if b == null or not is_instance_valid(b):
		return
	if _strook:
		var links := b.position.x - scroll_horizontal
		if links < 0.0 or links + b.size.x > size.x:
			ensure_control_visible(b)
	else:
		var boven := b.position.y - scroll_vertical
		if boven < 0.0 or boven + b.size.y > size.y:
			ensure_control_visible(b)

# ------------------------------------------------------------ een som in beeld

## Owner, 2026-09-24: "Kan je tijdens een rekensom de hotkeys voor mappen
## verbergen".  While a sum is being answered (`Ui.som_in_beeld()`, the one
## rule, shared with the door signs in `Hits`) every chip — the map chip too —
## fades out and can be neither tapped nor focused: disabled,
## `MOUSE_FILTER_IGNORE`, `FOCUS_NONE`, and the bar itself lets the finger
## through.  The chips keep their place and their size, so the shell measures
## the same bar and the world frame does not move by a unit.  When the sum is
## answered or closed they come back exactly as they were.
##
## The bar asks once per drawn frame instead of listening to every card event:
## the answer also changes when the camera changes room (a card in another room
## does not count), and one question over the few open cards costs nothing.
func _process(_delta: float) -> void:
	verstop(Ui.som_in_beeld())

func verstopt() -> bool:
	return _verstopt

func verstop(aan: bool) -> void:
	if aan == _verstopt:
		return
	_verstopt = aan
	for b in _chips.values():
		_zet_chip(b, aan)
	if aan:
		_muis = mouse_filter
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		mouse_filter = _muis
	_vervaag_naar(0.0 if aan else 1.0)
	verstopt_veranderd.emit(aan)

func _zet_chip(b: Button, aan: bool) -> void:
	if b == null or not is_instance_valid(b):
		return
	if aan and b.has_focus():
		b.release_focus()
	b.disabled = aan
	b.focus_mode = Control.FOCUS_NONE if aan else Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE if aan else Control.MOUSE_FILTER_STOP

## A short fade, so the row does not blink; at once in reduced motion and
## headless, where a test reads the state on the next line.
func _vervaag_naar(alfa: float) -> void:
	if _vervaag != null and _vervaag.is_valid():
		_vervaag.kill()
	_vervaag = null
	if Ui.rust_modus() or DisplayServer.get_name() == "headless" or not is_inside_tree():
		modulate.a = alfa
		return
	_vervaag = create_tween()
	_vervaag.tween_property(self, "modulate:a", alfa, VERVAAG_S)

## Lay the chips out for the space they got.  `rail` is the compact landscape
## shell: three fixed columns of 48 units beside the frame (§16.4), the word
## wrapping whole under the picture.  `hoogte` is what the rail may use: it
## keeps its width and shrinks its PICTURE (and, at the last step, its word to
## the 12 px floor) until the chips fit — the word is never cut, and a bar that
## still does not fit scrolls rather than eat the world frame.
## `strook` is the phone row: every chip at its natural width, one line, scrolled.
func pas_aan(breedte: float, rail: bool, hoogte: float = 0.0, strook: bool = false) -> void:
	_rail = rail
	_strook = strook and not rail
	if not rail:
		_rail_rolt(false, 0.0)
	_zet_rollen(_strook, _rolt)
	for b in _chips.values():
		var rij: BoxContainer = b.get_node_or_null("Rij")
		if rij != null:
			rij.vertical = rail
		var ic: Label = b.get_node_or_null("Rij/Icoon")
		if ic != null and not rail:
			ic.add_theme_font_size_override("font_size", _maten["icoon"])
		var nm: Label = b.get_node_or_null("Rij/Naam")
		if nm != null:
			if not rail:
				nm.add_theme_font_size_override("font_size",
					maxi(UiThema.VLOER, int(_maten["klein"])))
			# In the rail the word wraps under the picture instead of the chip
			# growing sideways; outside it the word must NOT wrap, or its
			# minimum width collapses to one letter and the bar turns into a
			# column of very tall chips.
			nm.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY if rail else TextServer.AUTOWRAP_OFF
			nm.custom_minimum_size = Vector2.ZERO
			nm.max_lines_visible = -1
	if rail:
		_zet_vulling(VULLING)
		_meet_rail(hoogte)
		_raster.columns = RAIL_KOLOMMEN
		return
	var breedtes := _chip_breedtes(VULLING)
	# One row that overflows by a few units takes the tighter padding before it
	# wraps (VULLING_KRAP, R3).  Only then: every row that fits today keeps its
	# chips exactly as they were, and a bar that needs two rows anyway keeps
	# them too.
	if not _strook and not breedtes.is_empty() \
			and _rij_breedte(breedtes, breedtes.size()) > breedte:
		var krap := _chip_breedtes(VULLING_KRAP)
		if _rij_breedte(krap, krap.size()) <= breedte:
			breedtes = krap
		else:
			breedtes = _chip_breedtes(VULLING)
	if _strook:
		# one row, as wide as it needs to be: the ScrollContainer takes the
		# overflow instead of the world frame taking three rows of chips
		_raster.columns = maxi(1, _chips.size())
		_toon_huidige()
		return
	# A GridContainer sizes each column to its OWN widest chip, so the honest
	# question is "how many columns still fit", not "how many chips of the
	# widest size fit".  With nine chips that is nine cheap sums, and it is the
	# difference between one row and two on a 1000 unit tablet.
	_raster.columns = 1
	for k in range(breedtes.size(), 0, -1):
		if _rij_breedte(breedtes, k) <= breedte:
			_raster.columns = k
			break

## How many columns the bar ended up with — one machine-readable number for the
## browser probe and the layout test.
func kolommen() -> int:
	return _raster.columns if _raster != null else 0

func rijen() -> int:
	return int(ceil(_chips.size() / float(maxi(1, kolommen()))))

## Give every chip `vulling` units of padding on both sides and its minimum
## size for that padding; returns the widths in chip order.  The content is
## anchored to the chip with offsets (a Button lays out no children), so the
## offsets follow the padding or the word would be cut.
func _chip_breedtes(vulling: int) -> Array[float]:
	_zet_vulling(vulling)
	var uit: Array[float] = []
	for b in _chips.values():
		var rij: BoxContainer = b.get_node_or_null("Rij")
		if rij == null:
			continue
		var nodig := rij.get_combined_minimum_size()
		b.custom_minimum_size = Vector2(maxf(UiThema.HOT, nodig.x + 2 * vulling),
			maxf(UiThema.HOT, nodig.y + 4.0))
		uit.append(b.custom_minimum_size.x)
	return uit

func _zet_vulling(vulling: int) -> void:
	for b in _chips.values():
		var rij: BoxContainer = b.get_node_or_null("Rij")
		if rij != null:
			rij.offset_left = vulling
			rij.offset_right = -vulling

func _rij_breedte(breedtes: Array[float], kolommen_n: int) -> float:
	var som := float((kolommen_n - 1) * GAT)
	for k in kolommen_n:
		var breedst := 0.0
		var i := k
		while i < breedtes.size():
			breedst = maxf(breedst, breedtes[i])
			i += kolommen_n
		som += breedst
	return som

## The rail is exactly three columns of 48 units (art-sound-rules.md §16.4), so
## it costs the world 152 units of width and not a unit more.  The word stays —
## it wraps under the picture, whole, across as many lines as it needs.  What
## gives way when nine chips do not fit the height is the PICTURE, and only at
## the last step the word, down to the 12 px floor and never below it.
##
## A `Label` with autowrap reports one line as its minimum, so the wrapped
## height is measured with `UiThema.wrap_hoogte` and written into the label's
## own minimum; a colour-emoji line is much taller than its font size (35 units
## at size 20), which is why the picture is the first thing to shrink.
##
## And when even the smallest step does not fit, the bar scrolls (R1).  The
## hotel counts its own rooms, so this has to survive the room after the next:
## at 740 x 360 the rail has 295 units, and eleven chips need 328 of them with
## the picture at 14 and the word on the floor — a word of two lines is 48 units
## and there is nothing left to take away without breaking HOTEL.md §9.  Growing
## past the height it was given would push the world frame out of the shell, so
## the rail keeps that height and scrolls instead, exactly as the phone row does.
func _meet_rail(hoogte: float) -> void:
	var rijen_n := int(ceil(_chips.size() / float(RAIL_KOLOMMEN)))
	var trappen := [
		[int(_maten["icoon_keuze"]), int(_maten["klein"])],
		[18, maxi(UiThema.VLOER, int(_maten["klein"]) - 1)],
		[16, UiThema.VLOER],
		[14, UiThema.VLOER],
	]
	for trap in trappen:
		var hoogst := _zet_rail(int(trap[0]), int(trap[1]))
		if hoogte <= 0.0 or rijen_n * (hoogst + GAT) - GAT <= hoogte:
			_rail_rolt(false, hoogte)
			return
	_rail_rolt(true, hoogte)

## Scrolling rail on or off.  A `ScrollContainer` reports no minimum at all on
## the axis it scrolls, so the height it may use has to become its minimum —
## otherwise the bar collapses to nothing in the shell's rail column.
func _rail_rolt(aan: bool, hoogte: float) -> void:
	_rolt = aan and hoogte > 0.0
	_zet_rollen(false, _rolt)
	custom_minimum_size = Vector2(0.0, hoogte if _rolt else 0.0)
	if _rolt:
		_toon_huidige()

## One rail step: give every chip this picture and word size, and return the
## height the tallest chip then needs.
func _zet_rail(icoon_maat: int, naam_maat: int) -> float:
	var tekst_breed := RAIL_BREED - 2 * VULLING
	var hoogst := float(UiThema.HOT)
	for b in _chips.values():
		var rij: BoxContainer = b.get_node_or_null("Rij")
		var ic: Label = b.get_node_or_null("Rij/Icoon")
		var nm: Label = b.get_node_or_null("Rij/Naam")
		if rij == null or nm == null:
			continue
		if ic != null:
			ic.add_theme_font_size_override("font_size", icoon_maat)
		nm.add_theme_font_size_override("font_size", maxi(UiThema.VLOER, naam_maat))
		nm.custom_minimum_size = Vector2(tekst_breed, UiThema.wrap_hoogte(nm, tekst_breed))
		hoogst = maxf(hoogst, rij.get_combined_minimum_size().y + 4.0)
	for b in _chips.values():
		b.custom_minimum_size = Vector2(RAIL_BREED, hoogst)
	return hoogst

func rail_breedte() -> float:
	return RAIL_KOLOMMEN * RAIL_BREED + (RAIL_KOLOMMEN - 1) * GAT
