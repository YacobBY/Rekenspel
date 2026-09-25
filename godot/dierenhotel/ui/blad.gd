class_name UiBlad
extends Control
## A modal sheet (world.md §6.7, art-sound-rules.md §16.8).
##
## `Ui.blad_open({titel, beeld, hint, inhoud, knoppen, sluitbaar})`.  Only the start
## screen, the map, the till, the letter wall and the day cycle use it: HOTEL.md
## §9 forbids a calculation panel beside the world, so no sum ever appears here.
##
## Tapping the backdrop closes it, unless `sluitbaar` is false (the start screen
## must be answered before anything is saved, architecture.md §9).

signal gesloten()

const BREED := 560       ## the sheet never gets wider than this
const RAND := 12         ## air between the sheet and the screen edge
const VULLING := 14      ## the sheet's own padding
const HOOG_DEEL := 0.92  ## and never taller than this much of the screen
const KNOP_RIJ := "Knoppen"

var _paneel: PanelContainer
var _kolom: VBoxContainer
var _rol: ScrollContainer
var sluitbaar := true

func bouw(o: Dictionary, mt: Dictionary, kader: Vector2) -> void:
	# `set_anchors_preset` moves the ANCHORS and recomputes the offsets so the
	# rectangle stays what it was — on a Control built in code that is 0 x 0, and
	# the whole sheet then collapses onto its panel's minimum size.  Anchors AND
	# offsets, or nothing.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	sluitbaar = bool(o.get("sluitbaar", true))

	var waas := ColorRect.new()
	waas.name = "Waas"
	waas.color = UiThema.SCHERM_WAAS
	waas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	waas.mouse_filter = Control.MOUSE_FILTER_STOP
	waas.gui_input.connect(func(ev: InputEvent) -> void:
		if sluitbaar and ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			Ui.blad_dicht())
	add_child(waas)

	var midden := CenterContainer.new()
	midden.name = "Midden"
	midden.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	midden.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(midden)

	_paneel = PanelContainer.new()
	_paneel.name = "Blad"
	var sb := UiThema.vulling(UiThema.vlak(UiThema.KAART, 26, 3, UiThema.WIT), 14, 12)
	sb.shadow_color = UiThema.SCHADUW_DIEP
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 5)
	_paneel.add_theme_stylebox_override("panel", sb)
	var breed := minf(BREED, maxf(240.0, kader.x - 2 * RAND))
	_paneel.custom_minimum_size = Vector2(breed, 0)
	midden.add_child(_paneel)

	# `stil`: the same sheet built again with new content (the prikbord after a
	# card was ticked) does not pop in a second time.
	if not bool(o.get("stil", false)) and not Ui.rust_modus() \
			and DisplayServer.get_name() != "headless" and not Engine.is_editor_hint():
		waas.modulate.a = 0.0
		_paneel.pivot_offset = Vector2(breed * 0.5, 120.0)
		_paneel.scale = Vector2(0.92, 0.92)
		_paneel.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(waas, "modulate:a", 1.0, 0.16)
		tw.tween_property(_paneel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_paneel, "modulate:a", 1.0, 0.14)

	# A ScrollContainer has minimum height 0, so inside a CenterContainer the
	# panel would shrink to its padding and clip everything.  The sheet is
	# content-sized (measured below) and only scrolls when the content is taller
	# than 92 % of the screen.
	_rol = ScrollContainer.new()
	_rol.name = "Rol"
	_rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_paneel.add_child(_rol)

	_kolom = VBoxContainer.new()
	_kolom.name = "Kolom"
	_kolom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kolom.add_theme_constant_override("separation", 8)
	_rol.add_child(_kolom)

	var titel := str(o.get("titel", ""))
	if not titel.is_empty():
		var k := Label.new()
		k.name = "Titel"
		k.theme_type_variation = "Kop"
		k.text = titel
		k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		k.add_theme_font_size_override("font_size", mt["h1"])
		var beeld = o.get("beeld", null)
		if beeld is Texture2D:
			# a drawn pictogram before the title, where no emoji exists (the
			# stairs' panel, `UiTrapIcoon`), as big as an emoji of the title
			var rij := HBoxContainer.new()
			rij.name = "TitelRij"
			rij.add_theme_constant_override("separation", int(round(float(mt["h1"]) * 0.3)))
			var plaatje := TextureRect.new()
			plaatje.name = "Beeld"
			plaatje.texture = beeld
			plaatje.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			plaatje.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			plaatje.custom_minimum_size = Vector2.ONE * round(float(mt["h1"]) * 1.2)
			plaatje.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			plaatje.mouse_filter = Control.MOUSE_FILTER_IGNORE
			k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			# a wrapping Label in a row reports one word per line as its
			# height and the sheet grew by it (the Label trap, AGENTS.md §8):
			# a title with a picture is short, it stays on one line
			k.autowrap_mode = TextServer.AUTOWRAP_OFF
			rij.add_child(plaatje)
			rij.add_child(k)
			_kolom.add_child(rij)
		else:
			_kolom.add_child(k)
	var hint := str(o.get("hint", ""))
	if not hint.is_empty():
		var h := Label.new()
		h.name = "Hint"
		h.text = hint
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_theme_font_size_override("font_size", mt["klein"])
		h.add_theme_color_override("font_color", UiThema.INKT2)
		# Under 320 units of height the explanation goes rather than a tap
		# target shrinking below 48 px (art-sound-rules.md §16.4).
		h.visible = kader.y >= 320.0
		_kolom.add_child(h)
	for c in o.get("inhoud", []):
		_kolom.add_child(c)

	var knoppen: Array = o.get("knoppen", [])
	if not knoppen.is_empty():
		var rij := HFlowContainer.new()
		rij.name = KNOP_RIJ
		rij.alignment = FlowContainer.ALIGNMENT_CENTER
		rij.add_theme_constant_override("h_separation", 8)
		rij.add_theme_constant_override("v_separation", 6)
		_kolom.add_child(rij)
		for kn in knoppen:
			var b := Button.new()
			b.name = "K" + str(kn.get("id", kn.get("tekst", "")))
			b.text = str(kn.get("tekst", ""))
			b.tooltip_text = str(kn.get("titel", kn.get("tekst", "")))
			b.custom_minimum_size = Vector2(UiThema.TAP, UiThema.TAP)
			b.clip_text = false
			if bool(kn.get("groot", false)) or bool(kn.get("primair", false)):
				b.theme_type_variation = "KnopActief"
				b.add_theme_font_size_override("font_size", mt["knop_groot"])
			var aan: Callable = kn.get("aan", Callable())
			var dicht := bool(kn.get("dicht", true))
			b.pressed.connect(func() -> void:
				Snd.tik()
				if dicht:
					Ui.blad_dicht()
				if aan.is_valid():
					aan.call())
			rij.add_child(b)
	_meet(breed, kader)
	_hermeet(breed, kader)

## How tall the sheet really is.
##
## `Container.get_combined_minimum_size()` cannot answer this: a `Label` with
## autowrap reports its height for the width it CURRENTLY has, and before the
## first layout pass that width is 1 — the start screen's two sentences claimed
## 2970 units between them.  So the content is measured child by child at the
## width the sheet will really give it, and only that number reaches the panel.
## The ScrollContainer's own vertical minimum is 0 (it scrolls), so the column's
## nonsense minimum never propagates: the sheet is exactly its content, capped
## at 92 % of the screen, and scrolls beyond that.
func _meet(breed: float, kader: Vector2) -> void:
	var binnen := breed - 2 * VULLING
	_wrap(_kolom, binnen)
	var maxi_h := maxf(120.0, kader.y * HOOG_DEEL - 2 * VULLING - 2 * RAND)
	# Two units of slack: without them the content is exactly as tall as the box
	# and a scrollbar appears on a sheet that fits.  Vertical scrolling stays on
	# (turning it off would let the column's pre-layout minimum — thousands of
	# units, one character per line — reach the panel again).
	var nodig := _inhoud_hoogte(binnen)
	_rol.custom_minimum_size = Vector2(binnen, minf(nodig + 2.0, maxi_h))

## And how tall it turned out to be.  The estimate above is made before the
## first layout pass, and a `Button` reports a smaller minimum then than the one
## it really takes (the two start-screen buttons measured 48 and drew 59), so
## the sheet clipped its own button row off the bottom — on a 360 unit phone
## that made "Verder spelen ▸" untappable (I1 finding 1, seen in the probe).
## One frame later every child knows its real width, so the column's minimum is
## honest and the panel is corrected upwards, still capped at 92 % of the screen.
func _hermeet(breed: float, kader: Vector2) -> void:
	await get_tree().process_frame
	if not is_instance_valid(_rol) or not is_instance_valid(_kolom):
		return
	var maxi_h := maxf(120.0, kader.y * HOOG_DEEL - 2 * VULLING - 2 * RAND)
	var echt := _kolom.get_combined_minimum_size().y + 2.0
	_rol.custom_minimum_size.y = clampf(echt, _rol.custom_minimum_size.y, maxi_h)

func _inhoud_hoogte(binnen: float) -> float:
	var sep := float(_kolom.get_theme_constant("separation"))
	var totaal := 0.0
	var eerste := true
	for kind in _kolom.get_children():
		var c := kind as Control
		if c == null or not c.visible:
			continue
		if not eerste:
			totaal += sep
		eerste = false
		totaal += _hoogte_van(c, binnen)
	return totaal

func _hoogte_van(c: Control, binnen: float) -> float:
	if c is Label and (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
		return UiThema.wrap_hoogte(c as Label, binnen)
	if c is FlowContainer:
		return _flow_hoogte(c as FlowContainer, binnen)
	return c.get_combined_minimum_size().y

## A FlowContainer reports 0 before it is laid out, so its rows are packed here.
func _flow_hoogte(f: FlowContainer, binnen: float) -> float:
	var h_sep := float(f.get_theme_constant("h_separation"))
	var v_sep := float(f.get_theme_constant("v_separation"))
	var rij_breed := 0.0
	var rij_hoog := 0.0
	var totaal := 0.0
	var rijen := 0
	for kind in f.get_children():
		var c := kind as Control
		if c == null or not c.visible:
			continue
		var m := c.get_combined_minimum_size()
		var nodig: float = m.x if rij_breed <= 0.0 else rij_breed + h_sep + m.x
		if nodig > binnen and rij_breed > 0.0:
			totaal += rij_hoog + (v_sep if rijen > 0 else 0.0)
			rijen += 1
			rij_breed = m.x
			rij_hoog = m.y
		else:
			rij_breed = nodig
			rij_hoog = maxf(rij_hoog, m.y)
	totaal += rij_hoog + (v_sep if rijen > 0 else 0.0)
	return totaal

## Every autowrapping Label gets the width the sheet gives it AND the height it
## needs at that width, so it stops claiming one character per line.
func _wrap(k: Node, breed: float) -> void:
	if k is Label:
		var l := k as Label
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.visible \
				and l.custom_minimum_size.y <= 0.0:
			l.custom_minimum_size = Vector2(breed, UiThema.wrap_hoogte(l, breed))
	for kind in k.get_children():
		_wrap(kind, breed)

func inhoud() -> VBoxContainer:
	return _kolom

func sluit() -> void:
	gesloten.emit()
	if not Ui.rust_modus() and DisplayServer.get_name() != "headless" and is_inside_tree() and not Engine.is_editor_hint():
		var tw := create_tween().set_parallel()
		tw.tween_property(self, "modulate:a", 0.0, 0.12)
		tw.finished.connect(queue_free)
	else:
		queue_free()
