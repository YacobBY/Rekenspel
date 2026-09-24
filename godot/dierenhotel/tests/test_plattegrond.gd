extends Proef
## The map sheet (`ui/plattegrond.gd`), opened exactly as `scenes/main.gd`
## opens it, on three frames.
##
## What shipped broken and what these assertions hold on to: the cells were
## stretched into 530 unit columns and every word was drawn half a sheet to the
## right of its own cell, because a `Button` never sorts an anchored child.  So
## nothing here trusts the node tree: every assertion is on `get_global_rect()`
## — of the button of every room `Rooms` has, and of the two labels inside each
## of them.

const FRAMES := [Vector2(1000, 648), Vector2(326, 402), Vector2(534, 289)]

var _laag: Control = null

## The whole tower is no taller than one floor of the widest cell per row
## (`CEL_MAX` wide, `CEL_HOOG` of that tall) plus a gap per row.
func _hoog_max() -> float:
	return UiPlattegrond.rijen() * (UiPlattegrond.CEL_MAX * UiPlattegrond.CEL_HOOG
		+ UiPlattegrond.GAT)
var _gekozen: Array[String] = []

func _op(kader: Vector2) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = kader
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	World.meet(Rect2(Vector2.ZERO, kader))

func _af() -> void:
	Ui.blad_dicht()
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	if _laag != null:
		_laag.queue_free()
		_laag = null

## The sheet as `scenes/main.gd::_plattegrond` builds it, three frames later.
func _open(kader: Vector2) -> Array:
	_op(kader)
	var kaart := UiPlattegrond.new()
	kaart.bouw(Ui.maten)
	kaart.kamer_gekozen.connect(func(id: String) -> void:
		_gekozen.append(id))
	var blad := Ui.blad_open({"titel": UiTekst.KAART_TITEL, "hint": UiTekst.KAART_HINT,
		"inhoud": [kaart], "knoppen": [{"id": "sluit", "tekst": UiTekst.SLUITEN}]})
	var boom := Engine.get_main_loop() as SceneTree
	for _f in 3:
		await boom.process_frame
	return [blad, kaart]

# ------------------------------------------------------------------ de maat

func test_acht_kamers_op_hun_plek() -> void:
	for kader in FRAMES:
		var uit: Array = await _open(kader)
		var blad: UiBlad = uit[0]
		var kaart: UiPlattegrond = uit[1]
		waar(blad != null, "het blad opent bij %s" % str(kader))
		if blad == null:
			_af()
			continue
		var tafel := UiPlattegrond.kaart()
		gelijk(tafel.size(), Rooms.lijst().size(),
			"de tabel heeft een vak per kamer van het hotel")
		# every room of the hotel, not every row of the table: a room added
		# without its cell has to fail here (R1)
		for id in Rooms.lijst():
			waar(tafel.has(id), "%s staat in de tabel" % id)
			gelijk(kaart.plek_van(id), tafel.get(id, Vector2i.ZERO),
				"%s staat op de kaart waar de tabel zegt" % id)
			var knop: Button = kaart.get_node_or_null("P" + id)
			waar(knop != null, "%s heeft een cel bij %s" % [id, str(kader)])
			if knop != null:
				gelijk(knop.text, "", "de knop tekent zelf geen tekst (%s)" % id)
				gelijk(knop.tooltip_text, UiTekst.ga_naar(Rooms.get_kamer(id).naam),
					"de cel zegt waar hij heen gaat (%s)" % id)
		_af()

## Every cell is a tap target and stands on the sheet — and on the short frames,
## where the five floors make the sheet scroll, at least within the sheet's
## width, with the whole tower no taller than five floors of the maximum size.
## On the desktop frame the whole tower fits without scrolling.
func test_cellen_passen_op_het_blad() -> void:
	for kader in FRAMES:
		var uit: Array = await _open(kader)
		var blad: UiBlad = uit[0]
		var kaart: UiPlattegrond = uit[1]
		if blad == null:
			_af()
			continue
		var paneel: Control = blad.get_node("Midden/Blad")
		var rol: Control = blad.get_node("Midden/Blad/Rol")
		var kolom: Control = blad.get_node("Midden/Blad/Rol/Kolom")
		var pr := paneel.get_global_rect().grow(0.5)
		var rolt := kaart.size.y > rol.size.y + 0.5
		var ic: Label = kaart.get_node("Pzwembad/Icoon")
		var nm: Label = kaart.get_node("Pzwembad/Naam")
		print("[maat] plattegrond %s: cel %s gat %.0f schacht %.0f plan %s blad %s rol %s rolt=%s zwembad icoon %s naam %s"
			% [str(kader), str(kaart.celmaat()), kaart.gat(), kaart.schacht(), str(kaart.size),
				str(kolom.size), str(rol.size), str(rolt), str(ic.size), str(nm.size)])
		waar(kaart.size.y <= _hoog_max(),
			"de hele toren blijft onder %.0f eenheden hoog bij %s (%s)"
				% [_hoog_max(), str(kader), str(kaart.size)])
		waar(kaart.size.x <= pr.size.x,
			"en niet breder dan het vel bij %s (%.1f > %.1f)"
				% [str(kader), kaart.size.x, pr.size.x])
		if kader == FRAMES[0]:
			waar(kolom.size.y <= rol.size.y + 0.5,
				"op het grote scherm past het hele blad met de toren zonder rollen (%s in %s)"
					% [str(kolom.size), str(rol.size)])
		# the lift shaft stays a narrow column: every floor button left of the
		# first room column, inside the tower
		var eerste := INF
		for id in Rooms.lift_kamers():
			eerste = minf(eerste, kaart.knop_van(id).position.x)
		for e in Rooms.etages():
			var lk := kaart.lift_knop(e)
			waar(lk.size.x >= 20.0, "etage %s heeft een liftknop bij %s (%s)" % [e, str(kader), str(lk)])
			waar(lk.position.x >= 0.0 and lk.end.x <= eerste,
				"de liftknop van etage %s staat in de schacht bij %s (%s, kolom 1 op %.1f)"
					% [e, str(kader), str(lk), eerste])
		for id in Rooms.lijst():
			var knop: Button = kaart.get_node_or_null("P" + id)
			if knop == null:
				continue
			var kr := knop.get_global_rect()
			waar(kr.size.x >= 48.0 and kr.size.y >= 48.0,
				"%s is een tikdoel bij %s (%s)" % [id, str(kader), str(kr.size)])
			waar(kr.position.x >= pr.position.x and kr.end.x <= pr.end.x,
				"%s staat binnen het vel bij %s (%s in %s)" % [id, str(kader), str(kr), str(pr)])
			if not rolt:
				waar(pr.encloses(kr),
					"%s staat helemaal op het vel bij %s (%s in %s)"
						% [id, str(kader), str(kr), str(pr)])
			for naam in ["Icoon", "Naam"]:
				var l: Label = knop.get_node_or_null(naam)
				waar(l != null, "%s heeft een %s" % [id, naam])
				if l == null:
					continue
				waar(not l.text.strip_edges().is_empty(), "%s: %s is geen lege regel" % [id, naam])
				waar(kr.grow(0.5).encloses(l.get_global_rect()),
					"%s: %s staat in de cel bij %s (%s in %s)"
						% [id, naam, str(kader), str(l.get_global_rect()), str(kr)])
		_af()

## The map is a tower (owner, 2026-09-24): every floor is one row, a higher
## floor is higher on the sheet, the lift's rooms stand in the first room
## column one above the other, and every floor button sits in the shaft on the
## middle of its own row.
func test_de_plattegrond_is_een_toren() -> void:
	var uit: Array = await _open(Vector2(1000, 648))
	var kaart: UiPlattegrond = uit[1]
	var vorige := -INF
	var lift_x := NAN
	for e in Rooms.etages():
		var ids := Rooms.op_etage(e)
		waar(not ids.is_empty(), "etage %s heeft kamers" % e)
		if ids.is_empty():
			continue
		var y0 := (kaart.get_node("P" + ids[0]) as Control).get_global_rect().position.y
		for id in ids:
			var r := (kaart.get_node("P" + id) as Control).get_global_rect()
			waar(absf(r.position.y - y0) <= 0.5,
				"%s staat op de rij van etage %s (%.1f vs %.1f)" % [id, e, r.position.y, y0])
			gelijk(kaart.plek_van(id).y, Rooms.etages().find(e) + 1,
				"%s staat in de rij van zijn etage" % id)
		waar(y0 > vorige + 0.5, "etage %s staat onder de etage erboven (%.1f > %.1f)"
			% [e, y0, vorige])
		vorige = y0
		var lift := Rooms.lift_kamer(e)
		if not lift.is_empty():
			gelijk(kaart.plek_van(lift).x, 1, "de lift van etage %s staat vooraan (%s)" % [e, lift])
			var lx := kaart.knop_van(lift).position.x
			if is_nan(lift_x):
				lift_x = lx
			waar(absf(lx - lift_x) <= 0.5, "%s staat in de liftkolom (%.1f vs %.1f)"
				% [lift, lx, lift_x])
			var cel := kaart.knop_van(lift).get_rect()
			var knop := kaart.lift_knop(e)
			waar(absf(knop.get_center().y - cel.get_center().y) <= 0.5,
				"de liftknop van etage %s staat midden op zijn rij" % e)
			waar(knop.end.x <= cel.position.x, "en links van %s, in de schacht" % lift)
	# the building reads top-down: the guest rooms up high, the lobby on the
	# ground, the laundry in the cellar
	var gang := (kaart.get_node("Pgang") as Control).get_global_rect()
	var receptie := (kaart.get_node("Preceptie") as Control).get_global_rect()
	var wasserij := (kaart.get_node("Pwasserij") as Control).get_global_rect()
	waar(gang.end.y <= receptie.position.y, "de gang ligt boven de receptie")
	waar(wasserij.position.y >= receptie.end.y, "de wasserij ligt onder de receptie")
	gelijk(UiPlattegrond.rij_van(3), ["gang", "kamer1", "kamer2", "keuken"] as Array[String],
		"de bovenste etage: de gang bij de lift, dan de kamers erlangs")
	gelijk(UiPlattegrond.rij_van(0), ["receptie", "tuin", "zwembad", "kas"] as Array[String],
		"de begane grond: receptie, tuin, en door de tuin naar buiten")
	# every door between two cells side by side, once per pair: on the top floor
	# gang|kamer1 (kamer 2 and the kitchen also open onto the gang but cannot
	# stand beside it in one row), on the ground floor receptie|tuin and the
	# gate tuin|zwembad (the tuin's door to the kas is not a neighbour); the
	# floors of one room have none, and the lift is the shaft, not a door
	gelijk(kaart.deursleutels(), ["gang|kamer1", "receptie|tuin", "tuin|zwembad"] as Array[String],
		"de deuren die de toren tekent")
	gelijk(kaart.deurparen(), 3, "drie deuren tussen buren")
	# the floor in view wears the band
	gelijk(kaart.band_rij(), Rooms.etages().find(Rooms.etage(World.kamer_nu())) + 1
		if Rooms.bestaat(World.kamer_nu()) else 0, "de etage in beeld heeft de zonnige band")
	_af()

## The tap: `scenes/main.gd` closes the sheet and walks to the room, so the
## signal is the whole contract.
func test_tik_kiest_de_kamer() -> void:
	_gekozen.clear()
	var uit: Array = await _open(Vector2(1000, 648))
	var knop: Button = uit[1].get_node("Ptuin")
	knop.emit_signal("pressed")
	gelijk(_gekozen.size(), 1, "één tik, één keus")
	gelijk(_gekozen[0] if not _gekozen.is_empty() else "", "tuin",
		"een tik op de tuin kiest de tuin")
	_af()
