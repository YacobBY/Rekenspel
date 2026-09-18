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
		waar(extra or not rolt,
			"de negen chips van vandaag passen zonder te rollen (%.0f units)" % nodig)
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
