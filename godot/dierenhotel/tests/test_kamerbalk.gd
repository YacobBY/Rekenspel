extends Proef
## The room bar (`ui/kamerbalk.gd`) carries the rooms the hotel HAS — eight
## today plus the map chip, eleven the day the speelzaal and the kas open.
##
## The bar names no number anywhere; this file is what keeps that honest.  It
## lays the bar out exactly as `scenes/main.gd::_zet_balk` does, on the four
## screens of the ticket, and then does it again with two rooms that do not
## exist yet — because that is the day a shape has to give way, and a room is
## added in a later batch by someone who will not be reading this file.
##
## The three shapes (architecture.md §4.5): the wrapping grid, the three-column
## rail beside the frame in the compact landscape shell, and one scrolling row
## on a phone in portrait.

## The four screens, in CSS px.
const SCHERMEN := [Vector2(1024, 768), Vector2(768, 1024), Vector2(360, 740),
	Vector2(740, 360)]
## The world frames they produce, measured on the real shell by
## `test_ui.gd::test_shell_op_vijf_schermen` (it prints them on every run) and
## pasted here so this file does not have to build a window.  They decide the
## font sizes, so they are not guessed.
const KADERS := [Vector2(990, 637), Vector2(734, 788), Vector2(326, 558),
	Vector2(558, 289)]
## What the compact shell has left for the rail at 740 x 360: 360 units minus
## the 4 + 4 safe area, minus the 49 unit chrome (measured in the same print)
## and the 8 units of column separation.
const RAIL_HOOGTE := 295.0
## The two rooms of §3.5, so the bar is measured at its future size today.
const EXTRA := [["speelzaal", "🧸", "Speelzaal"], ["kas", "🪴", "Kas"]]

var _laag: Control = null
var _balk: UiKamerbalk = null

# ------------------------------------------------------------------ opbouw

## The bar as the shell builds it for this screen.  `extra` adds the rooms of
## §3.5 as chips: `vul()` reads `Rooms`, and this test must not touch `Rooms`
## (a room is added in a later batch), so it borrows the bar's own chip maker.
func _op(scherm: Vector2, kader: Vector2, extra := false) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = scherm
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	Ui.zet_scherm(scherm)
	World.meet(Rect2(Vector2.ZERO, kader))
	_balk = UiKamerbalk.new()
	_laag.add_child(_balk)
	_balk.bouw(Ui.maten)
	if extra:
		for rij in EXTRA:
			_balk._chips[rij[0]] = _balk._chip(rij[0], rij[1], rij[2],
				UiTekst.ga_naar(rij[2]))
		# the map chip stays the last one in the row, as `vul()` leaves it
		var kaart: Button = _balk._chips[""]
		kaart.get_parent().move_child(kaart, -1)

func _af() -> void:
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	Ui.vergeet_scherm()
	if _laag != null:
		_laag.queue_free()
		_laag = null
	_balk = null

## Is this screen compact landscape / a portrait phone?  The ladder of
## `scenes/main.gd::_pas_shell`, and the width the bar is handed there.
func _rail(scherm: Vector2) -> bool:
	return scherm.x > scherm.y and scherm.y < 450.0

func _strook(scherm: Vector2) -> bool:
	return scherm.x <= scherm.y and scherm.x < 520.0

## The rail gets its own three columns; every other shape gets the screen minus
## the shell's 12 unit margins.  Measured: 1000, 744, 336 and 152 units.
func _breedte(scherm: Vector2) -> float:
	return _balk.rail_breedte() if _rail(scherm) else scherm.x - 24.0

## Lay the bar out and give it the rectangle the shell would give it: its own
## minimum height, and the width it was measured for.
func _leg_uit(scherm: Vector2, hoogte: float) -> void:
	var breedte := _breedte(scherm)
	_balk.pas_aan(breedte, _rail(scherm), hoogte, _strook(scherm))
	_balk.position = Vector2.ZERO
	_balk.size = Vector2(breedte, _balk.get_combined_minimum_size().y)
	var boom := Engine.get_main_loop() as SceneTree
	for _f in 2:
		await boom.process_frame

# ------------------------------------------------------------------- de rij

func test_de_balk_draagt_elke_kamer() -> void:
	_op(SCHERMEN[0], KADERS[0])
	await _leg_uit(SCHERMEN[0], 0.0)
	gelijk(_balk.chips().size(), Rooms.lijst().size() + 1,
		"een chip per kamer plus de plattegrond")
	for id in Rooms.lijst():
		var b: Button = _balk.chips().get(id)
		waar(b != null, "de balk kent " + id)
		if b == null:
			continue
		gelijk(b.name, "C" + id, "de chip heet C<kamer>")
		var r := Rooms.get_kamer(id)
		var ic: Label = b.get_node_or_null("Rij/Icoon")
		var nm: Label = b.get_node_or_null("Rij/Naam")
		waar(ic != null and ic.text == r.icoon, "%s draagt zijn plaatje" % id)
		waar(nm != null and nm.text == r.naam, "%s draagt zijn woord" % id)
	waar(_balk.chips().has(""), "en de plattegrondchip staat er ook")
	_af()

# ------------------------------------------------------------------ de maat

## Every chip stands inside the bar it was laid out in, on every screen — with
## and without the two rooms of §3.5.
func test_de_chips_passen_op_elk_scherm() -> void:
	for extra in [false, true]:
		for i in SCHERMEN.size():
			var scherm: Vector2 = SCHERMEN[i]
			_op(scherm, KADERS[i], extra)
			var hoogte := RAIL_HOOGTE if _rail(scherm) else 0.0
			await _leg_uit(scherm, hoogte)
			_keur(scherm, extra)
			_af()

func _keur(scherm: Vector2, extra: bool) -> void:
	var wat := "%s%s" % [str(scherm), " + 2 kamers" if extra else ""]
	var balk := _balk.get_global_rect()
	var tap := UiThema.tap_van(minf(scherm.x, scherm.y))
	# An axis the bar scrolls (the phone row sideways, a rail with more rooms
	# than it can show up and down) may overflow — but only by scrolling: a chip
	# that is bigger than the bar on that axis can never come fully into view.
	var rol_x := _balk.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
	var rol_y := _balk.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
	print("[maat] kamerbalk %s: chips %d kolommen %d rijen %d balk %s rolt %s/%s"
		% [wat, _balk.chips().size(), _balk.kolommen(), _balk.rijen(), str(_balk.size),
			str(rol_x), str(rol_y)])
	waar(_balk.kolommen() >= 1, "%s: minstens één kolom" % wat)
	waar(_balk.rijen() * _balk.kolommen() >= _balk.chips().size(),
		"%s: het raster heeft plaats voor elke chip" % wat)
	for id in _balk.chips():
		var b: Button = _balk.chips()[id]
		var r := b.get_global_rect()
		waar(r.size.x >= tap and r.size.y >= tap,
			"%s: chip %s is een tikdoel (%s)" % [wat, id, str(r.size)])
		if rol_x:
			waar(r.size.x <= balk.size.x + 0.5,
				"%s: chip %s rolt nooit in beeld, hij is te breed (%s)"
					% [wat, id, str(r.size)])
		else:
			waar(r.position.x >= balk.position.x - 0.5 and r.end.x <= balk.end.x + 0.5,
				"%s: chip %s staat in de balk (%s in %s)" % [wat, id, str(r), str(balk)])
		if rol_y:
			waar(r.size.y <= balk.size.y + 0.5,
				"%s: chip %s rolt nooit in beeld, hij is te hoog (%s)"
					% [wat, id, str(r.size)])
		else:
			waar(r.position.y >= balk.position.y - 0.5 and r.end.y <= balk.end.y + 0.5,
				"%s: chip %s staat in de balk (%s in %s)" % [wat, id, str(r), str(balk)])
		for naam in ["Icoon", "Naam"]:
			var l: Label = b.get_node_or_null("Rij/" + naam)
			waar(l != null and not l.text.strip_edges().is_empty(),
				"%s: chip %s heeft een %s" % [wat, id, naam])
			if l == null:
				continue
			waar(l.get_theme_font_size("font_size") >= UiThema.VLOER,
				"%s: %s van %s blijft leesbaar (%d)"
					% [wat, naam, id, l.get_theme_font_size("font_size")])
			waar(r.grow(0.5).encloses(l.get_global_rect()),
				"%s: %s van %s staat in de chip (%s in %s)"
					% [wat, naam, id, str(l.get_global_rect()), str(r)])

## R3: with the kas the hotel has eleven chips.  On the 1000 unit tablet row
## (1024 × 768) they need 1029 units at the normal padding, and a second row
## would take a whole band of height from the world frame (990 × 637 became
## 990 × 585 and the check-in card lost its guest, test_hits).  So the row first
## takes the tighter padding, and only a row that does not fit even then wraps.
## A row that fits keeps its padding exactly as it was.
func test_elf_chips_op_een_rij_op_de_tablet() -> void:
	_op(SCHERMEN[0], KADERS[0])
	await _leg_uit(SCHERMEN[0], 0.0)
	gelijk(_balk.chips().size(), Rooms.lijst().size() + 1, "elke kamer en de kaart")
	waar(_balk.chips().size() >= 11, "met de kas zijn het er elf")
	gelijk(_balk.rijen(), 1, "één rij op de tablet")
	var rij: Control = (_balk.chips()["kas"] as Button).get_node("Rij")
	gelijk(rij.offset_left, float(UiKamerbalk.VULLING_KRAP), "met de krappe vulling")
	_af()
	# a wide screen has room: the normal padding stays
	_op(Vector2(1280, 800), Vector2(1170, 669))
	await _leg_uit(Vector2(1280, 800), 0.0)
	gelijk(_balk.rijen(), 1, "één rij op 1280")
	rij = (_balk.chips()["kas"] as Button).get_node("Rij")
	gelijk(rij.offset_left, float(UiKamerbalk.VULLING), "met de gewone vulling")
	_af()
	# a tablet upright needs two rows anyway: those keep the normal padding too
	_op(SCHERMEN[1], KADERS[1])
	await _leg_uit(SCHERMEN[1], 0.0)
	waar(_balk.rijen() >= 2, "rechtop blijven het twee rijen")
	rij = (_balk.chips()["kas"] as Button).get_node("Rij")
	gelijk(rij.offset_left, float(UiKamerbalk.VULLING), "met de gewone vulling")
	_af()

## Twelve chips with the shopping arcade (2026-09-24): on the 1000 unit tablet
## the row takes a step smaller pictures (and words, never under the floor)
## before it wraps — a second row would take a band of height from the world
## frame.  Where there is room, the full sizes stay.
func test_twaalf_chips_op_een_rij_op_de_tablet() -> void:
	_op(SCHERMEN[0], KADERS[0])
	await _leg_uit(SCHERMEN[0], 0.0)
	gelijk(_balk.chips().size(), 12, "elf kamers en de kaart")
	gelijk(_balk.rijen(), 1, "één rij op de tablet")
	var ic: Label = (_balk.chips()["winkels"] as Button).get_node("Rij/Icoon")
	var nm: Label = (_balk.chips()["winkels"] as Button).get_node("Rij/Naam")
	waar(ic.get_theme_font_size("font_size") < int(Ui.maten["icoon"]), "een stap kleinere plaatjes")
	waar(nm.get_theme_font_size("font_size") >= UiThema.VLOER, "het woord nooit onder de vloer")
	for id in _balk.chips():
		var b: Button = _balk.chips()[id]
		var w: Label = b.get_node("Rij/Naam")
		waar(w.get_minimum_size().x <= b.custom_minimum_size.x, "%s: het woord past in de chip" % id)
	_af()
	# a wide screen keeps the full sizes
	_op(Vector2(1280, 800), Vector2(1170, 669))
	await _leg_uit(Vector2(1280, 800), 0.0)
	gelijk(_balk.rijen(), 1, "één rij op 1280")
	ic = (_balk.chips()["winkels"] as Button).get_node("Rij/Icoon")
	gelijk(ic.get_theme_font_size("font_size"), int(Ui.maten["icoon"]), "met de gewone plaatjes")
	_af()

# ------------------------------------------------------------------- de rail

## The rail costs the world width, never height: it must fit in the height the
## compact shell hands it, at nine chips and at eleven.  What gives way is the
## picture and, at the last step, the word — down to the 12 px floor, never
## below it, and never cut (`_meet_rail`).
func test_de_rail_blijft_binnen_zijn_hoogte() -> void:
	var scherm: Vector2 = SCHERMEN[3]
	for extra in [false, true]:
		_op(scherm, KADERS[3], extra)
		await _leg_uit(scherm, RAIL_HOOGTE)
		var nodig := _balk.get_combined_minimum_size().y
		print("[maat] rail %d chips: %.0f van %.0f units, %d rijen"
			% [_balk.chips().size(), nodig, RAIL_HOOGTE, _balk.rijen()])
		gelijk(_balk.kolommen(), UiKamerbalk.RAIL_KOLOMMEN, "de rail is drie kolommen")
		waar(nodig <= RAIL_HOOGTE,
			"%d chips passen in %.0f units (nodig: %.0f)"
				% [_balk.chips().size(), RAIL_HOOGTE, nodig])
		gelijk(_balk.rail_breedte(), 3 * UiThema.HOT + 2 * UiKamerbalk.GAT,
			"en hij kost de wereld 152 units breedte")
		for id in _balk.chips():
			var b: Button = _balk.chips()[id]
			gelijk(b.custom_minimum_size.x, float(UiKamerbalk.RAIL_BREED),
				"chip %s houdt de railbreedte" % id)
		var rolt := _balk.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
		# R2: with the playroom the hotel has ten chips today and the 295-unit
		# rail needs the scroll fallback `_meet_rail` was built for (the height
		# itself is checked above); the scroll path is verified below — the
		# last chip must come into view.
		# A rail that had to scroll must still bring its last chip into view, or
		# the room that was added would be the room nobody can reach.
		if rolt:
			var sleutels: Array = _balk.chips().keys()
			var laatste: Button = _balk.chips()[sleutels[sleutels.size() - 1]]
			_balk.ensure_control_visible(laatste)
			var boom := Engine.get_main_loop() as SceneTree
			await boom.process_frame
			waar(_balk.get_global_rect().grow(0.5).encloses(laatste.get_global_rect()),
				"de laatste chip rolt in beeld (%s in %s)"
					% [str(laatste.get_global_rect()), str(_balk.get_global_rect())])
		_af()

# ------------------------------------------------------- een som in beeld

## The whole shell in a SubViewport with a fresh hotel in the receptie — the
## same fixture as `test_hits.gd::_hotel_op`: the room bar, the frame and the
## door signs are only real in the real shell.
func _schil_op(maat: Vector2i) -> Dictionary:
	var boom := Engine.get_main_loop() as SceneTree
	var vp := SubViewport.new()
	vp.size = maat
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	boom.root.add_child(vp)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var shell := scene.instantiate()
	shell.set_meta("geen_start", true)     # never touch the save from a test
	vp.add_child(shell)
	await _beelden(4)
	State.nieuw_spel()
	Hotel.start()
	await _beelden(4)
	return {"vp": vp, "shell": shell}

func _schil_af(h: Dictionary) -> void:
	Games.stop()
	Ui.naamplaten_leeg()
	Hits.wis_alles()
	(h["vp"] as SubViewport).queue_free()
	await _beelden(1)
	Ui.registreer_lagen(null, null, null)
	Ui.vergeet_scherm()
	State.nieuw_spel()

func _beelden(n: int) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	for _f in n:
		await boom.process_frame

## A real tap, through the viewport's own input path: a disabled chip with
## `MOUSE_FILTER_IGNORE` must not be reachable by a finger at all, which an
## `emit_signal("pressed")` would never prove.
func _tik_op(vp: SubViewport, punt: Vector2) -> void:
	for druk in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = druk
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if druk else 0
		ev.position = punt
		ev.global_position = punt
		vp.push_input(ev, true)
		await _beelden(1)

## The hotel's door signs in a room: every hotspot with the `hotdeur` class.
func _deurbordjes(kamer: String) -> Array[String]:
	var uit: Array[String] = []
	for id in Hits.lijst():
		var s := Hits.spot(id)
		if s != null and s.kamer == kamer and s.klas.contains("hotdeur"):
			uit.append(id)
	return uit

func _op_het_glas(id: String) -> bool:
	var s := Hits.spot(id)
	return s != null and is_instance_valid(s.knoop) and s.zichtbaar \
		and s.knoop.is_visible_in_tree()

## Every chip is back: on the glass, tappable, focusable.
func _chips_terug(balk: UiKamerbalk, wat: String) -> void:
	waar(not balk.verstopt(), "%s: de kamerbalk is terug" % wat)
	gelijk(balk.modulate.a, 1.0, "%s: de chips zijn weer te zien" % wat)
	for id in balk.chips():
		var b: Button = balk.chips()[id]
		# PASS since 2026-09-24: the chip takes its tap AND lets the row be
		# swiped on a phone
		waar(not b.disabled and b.mouse_filter == Control.MOUSE_FILTER_PASS
			and b.focus_mode == Control.FOCUS_ALL,
			"%s: chip %s is weer te tikken" % [wat, id if id != "" else "kaart"])

## Owner, 2026-09-24: "Kan je tijdens een rekensom de hotkeys voor mappen
## verbergen".  The check-in in the receptie: while its two sums are up the
## room chips (the map chip too) and the door signs step aside — invisible,
## not tappable, not focusable — and the world frame does not move by a unit.
## The room question after them asks no sum: everything is back, and a tap on
## a chip goes to that room again.
func test_tijdens_een_som_wijken_de_kamerknoppen() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)                 # a walk is a teleport: no waiting
	var h: Dictionary = await _schil_op(Vector2i(1024, 768))
	var vp: SubViewport = h["vp"]
	var shell: Node = h["shell"]
	var balk: UiKamerbalk = shell.kamerbalk
	var kader: Control = shell.kader
	gelijk(World.kamer_nu(), "receptie", "we staan in de receptie")
	var kader_voor := kader.size
	var wereld_voor := World.kader_rect()
	var balk_voor := balk.get_global_rect()
	var deuren := _deurbordjes("receptie")
	waar(deuren.size() >= 2, "de receptie heeft deurbordjes (%s)" % str(deuren))
	waar(not Ui.som_in_beeld(), "nog geen som")
	_chips_terug(balk, "voor de bel")
	for d in deuren:
		waar(_op_het_glas(d), "voor de bel: %s staat er" % d)

	# vraag 1 van de check-in is een som
	Hotel.bel()
	await _beelden(4)
	var v = State.s["checkin"]
	waar(v != null, "er checkt iemand in")
	if v == null:
		await _schil_af(h)
		Ui.zet_rust_modus(rust)
		State.s = bewaard
		return
	waar(Ui.is_som("ci_som"), "vraag 1 is een som")
	gelijk(Ui.som_kaart_in_beeld(), "ci_som", "en het is de check-in die hem stelt")
	waar(balk.verstopt(), "de kamerbalk wijkt")
	gelijk(balk.modulate.a, 0.0, "de chips zijn niet te zien")
	gelijk(balk.mouse_filter, Control.MOUSE_FILTER_IGNORE, "de balk laat de vinger door")
	for id in balk.chips():
		var b: Button = balk.chips()[id]
		var naam: String = id if id != "" else "kaart"
		waar(b.disabled, "chip %s staat uit" % naam)
		gelijk(b.mouse_filter, Control.MOUSE_FILTER_IGNORE, "chip %s vangt geen vinger" % naam)
		gelijk(b.focus_mode, Control.FOCUS_NONE, "chip %s krijgt geen focus" % naam)
		waar(not b.has_focus(), "chip %s heeft geen focus" % naam)
	for d in deuren:
		waar(Hits.spot(d) != null, "%s bestaat nog (een spel mag hem lenen)" % d)
		waar(not _op_het_glas(d), "tijdens de som: %s is weg" % d)
	# nothing moved: the chips keep their place, the frame keeps its size
	gelijk(kader.size, kader_voor, "de wereld houdt haar kader")
	gelijk(World.kader_rect(), wereld_voor, "World meet hetzelfde kader")
	gelijk(balk.get_global_rect(), balk_voor, "de kamerbalk houdt zijn plek")
	# a real tap on the hidden gang chip goes nowhere
	var gang: Button = balk.chips()["gang"]
	await _tik_op(vp, gang.get_global_rect().get_center())
	gelijk(World.kamer_nu(), "receptie", "een tik op een verstopte chip doet niets")
	waar(Hits.spot("ci_som") != null, "en de som hangt er nog")
	# no game bar: the check-in is no game, answering its sum is the way on
	waar(not shell.spelbalk.visible, "geen spelbalk tijdens de check-in")

	# vraag 2 is ook een som
	v["invoer"] = str(int(v["nieuw"]))
	Hotel.antwoord1()
	await _beelden(3)
	gelijk(int(v["stap"]), 2, "vraag 2")
	waar(Ui.is_som("ci_som"), "vraag 2 is een som")
	waar(balk.verstopt(), "de kamerbalk blijft weg")
	for d in deuren:
		waar(not _op_het_glas(d), "vraag 2: %s is weg" % d)

	# de kamervraag is geen som: alles komt terug
	Hotel.antwoord2(Sommen.vergelijk(int(v["dagen"]), int(v["nieuw"]), int(v["voorraad"])))
	await _beelden(3)
	gelijk(int(v["stap"]), 3, "nu de kamer")
	waar(Hits.spot("ci_som") != null, "de kamervraag hangt er")
	waar(not Ui.is_som("ci_som"), "maar dat is geen som")
	waar(not Ui.som_in_beeld(), "er staat geen som meer")
	_chips_terug(balk, "na de som")
	for d in deuren:
		waar(_op_het_glas(d), "na de som: %s staat er weer" % d)
	gelijk(kader.size, kader_voor, "de wereld houdt haar kader, ook na de som")
	gelijk(balk.get_global_rect(), balk_voor, "de kamerbalk staat nog op zijn plek")
	# and a real tap on a chip works again
	gang = balk.chips()["gang"]
	await _tik_op(vp, gang.get_global_rect().get_center())
	gelijk(World.kamer_nu(), "gang", "een tik op de gang-chip gaat weer naar de gang")
	Hotel.naar_kamer("receptie")
	await _beelden(2)
	await _schil_af(h)
	Ui.zet_rust_modus(rust)
	State.s = bewaard

## The same on the other three shapes of the bar — two rows on the upright
## tablet, the scrolling row on the phone, the rail beside the frame in the
## compact landscape shell: the chips step aside, and neither the bar nor the
## world frame moves by a unit.
func test_de_som_verschuift_geen_enkele_balkvorm() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	for maat in [Vector2i(768, 1024), Vector2i(360, 740), Vector2i(740, 360)]:
		var h: Dictionary = await _schil_op(maat)
		var shell: Node = h["shell"]
		var balk: UiKamerbalk = shell.kamerbalk
		var kader: Control = shell.kader
		var kader_voor := kader.size
		var balk_voor := balk.get_global_rect()
		Hotel.bel()
		await _beelden(4)
		waar(State.s["checkin"] != null, "%s: er checkt iemand in" % str(maat))
		waar(Ui.som_in_beeld(), "%s: de som staat in beeld" % str(maat))
		waar(balk.verstopt(), "%s: de kamerbalk wijkt" % str(maat))
		gelijk(kader.size, kader_voor, "%s: de wereld houdt haar kader" % str(maat))
		gelijk(balk.get_global_rect(), balk_voor, "%s: de balk houdt zijn plek" % str(maat))
		for id in balk.chips():
			var b: Button = balk.chips()[id]
			waar(b.disabled and b.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and b.focus_mode == Control.FOCUS_NONE,
				"%s: chip %s is niet te tikken" % [str(maat), id if id != "" else "kaart"])
		for d in _deurbordjes("receptie"):
			waar(not _op_het_glas(d), "%s: %s is weg" % [str(maat), d])
		await _schil_af(h)
	Ui.zet_rust_modus(rust)
	State.s = bewaard

## The child is never stuck behind a sum.  In a game the sum's way out is the
## game bar's `⬅ Terug`, which never steps aside: the beds game of the
## check-in asks a sum at the desk, `⬅ Terug` is on the glass and tappable,
## and a tap on it brings the check-in back to its room question
## (`Hotel.checkin_terug`) — with the room chips back.
func test_terug_blijft_tijdens_de_som_van_een_spel() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var rust := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	var h: Dictionary = await _schil_op(Vector2i(1024, 768))
	var vp: SubViewport = h["vp"]
	var shell: Node = h["shell"]
	var balk: UiKamerbalk = shell.kamerbalk
	var kader_voor: Vector2 = (shell.kader as Control).size
	Hotel.bel()
	await _beelden(3)
	var v = State.s["checkin"]
	waar(v != null, "er checkt iemand in")
	waar(not Games.definitie("bedden").is_empty(), "het beddenspel is er")
	if v == null or Games.definitie("bedden").is_empty():
		await _schil_af(h)
		Ui.zet_rust_modus(rust)
		State.s = bewaard
		return
	v["stap"] = 3
	Hotel.paint_checkin()
	await _beelden(2)
	var kamer: String = str(State.kamers_met_plek()[0])
	waar(Hotel.kies_kamer(kamer), "een kamer gekozen: het beddenspel begint")
	var boom := Engine.get_main_loop() as SceneTree
	var t := 0.0
	while t < 3.0 and Hits.spot("bd_som") == null:
		await boom.create_timer(0.05).timeout
		t += 0.05
	await _beelden(3)
	gelijk(Games.actief(), "bedden", "het beddenspel loopt")
	waar(Ui.is_som("bd_som"), "de beddenvraag is een som")
	waar(Ui.som_in_beeld(), "er staat een som in beeld")
	var terug: Button = shell.spelbalk.terug_knop
	waar(shell.spelbalk.visible and terug != null and terug.is_visible_in_tree(),
		"⬅ Terug staat op het glas")
	if terug != null:
		waar(not terug.disabled and terug.mouse_filter == Control.MOUSE_FILTER_STOP,
			"en is te tikken")
		gelijk((shell.kader as Control).size, kader_voor, "de spelbalk houdt het kader")
		await _tik_op(vp, terug.get_global_rect().get_center())
		await _beelden(3)
	gelijk(Games.actief(), "", "⬅ Terug stopt het spel")
	v = State.s["checkin"]
	waar(v != null and int(v["stap"]) == 3, "de check-in staat weer bij de kamervraag")
	waar(Hits.spot("ci_som") != null and not Ui.som_in_beeld(),
		"de kamervraag hangt er, en die is geen som")
	_chips_terug(balk, "na ⬅ Terug")
	await _schil_af(h)
	Ui.zet_rust_modus(rust)
	State.s = bewaard

## Owner, 2026-09-24: "Op mobile kan ik de map shortcuts niet swipen onderaan
## het scherm."  Godot's ScrollContainer only scrolls under a finger when the
## touch reaches IT, so every chip passes it on (MOUSE_FILTER_PASS), the row has
## a small dead zone so a trembling tap stays a tap, and the chip under the
## finger that ends a swipe does not navigate.  (The swipe itself only happens
## where the device has a touch screen; it is played in the web export with
## `tools/speel.js --doe "veeg chip:receptie -250"`.)
func test_de_rij_laat_zich_vegen() -> void:
	var balk := UiKamerbalk.new()
	var boom := Engine.get_main_loop() as SceneTree
	boom.root.add_child(balk)
	balk.bouw(Ui.maten)
	waar(balk.scroll_deadzone >= 8, "een trillende tik is geen veeg (%d)" % balk.scroll_deadzone)
	for id in balk.chips():
		var b: Button = balk.chips()[id]
		gelijk(b.mouse_filter, Control.MOUSE_FILTER_PASS,
			"chip %s geeft de vinger door aan de rij" % (id if id != "" else "kaart"))
	var gekozen: Array[String] = []
	balk.kamer_gekozen.connect(func(k: String) -> void: gekozen.append(k))
	var chip: Button = balk.chips()["gang"]
	# a swipe that ends on the chip: no room
	balk.scroll_started.emit()
	chip.pressed.emit()
	gelijk(gekozen.size(), 0, "het einde van een veeg is geen tik")
	balk.scroll_ended.emit()
	await boom.process_frame
	waar(not balk.veegt(), "na de veeg is de rij weer gewoon")
	# and a plain tap still goes to the room
	chip.pressed.emit()
	gelijk(gekozen, ["gang"] as Array[String], "een gewone tik gaat naar de kamer")
	balk.queue_free()
	await boom.process_frame
