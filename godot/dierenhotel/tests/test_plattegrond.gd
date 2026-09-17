extends Proef
## The map sheet (`ui/plattegrond.gd`), opened exactly as `scenes/main.gd`
## opens it, on three frames.
##
## What shipped broken and what these assertions hold on to: the cells were
## stretched into 530 unit columns and every word was drawn half a sheet to the
## right of its own cell, because a `Button` never sorts an anchored child.  So
## nothing here trusts the node tree: every assertion is on `get_global_rect()`
## — of the eight buttons, and of the two labels inside each of them.

const FRAMES := [Vector2(1000, 648), Vector2(326, 402), Vector2(534, 289)]
const RIJ_MIDDEN := ["receptie", "gang", "keuken", "tuin"]
const HOOG_MAX := UiPlattegrond.RIJEN * UiPlattegrond.CEL_MAX \
	+ (UiPlattegrond.RIJEN - 1) * UiPlattegrond.GAT

var _laag: Control = null
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
		gelijk(UiPlattegrond.KAART.size(), 8, "de tabel heeft acht kamers")
		for id in UiPlattegrond.KAART:
			var knop: Button = kaart.get_node_or_null("P" + id)
			waar(knop != null, "%s heeft een cel bij %s" % [id, str(kader)])
			if knop != null:
				gelijk(knop.text, "", "de knop tekent zelf geen tekst (%s)" % id)
				gelijk(knop.tooltip_text, UiTekst.ga_naar(Rooms.get_kamer(id).naam),
					"de cel zegt waar hij heen gaat (%s)" % id)
		_af()

## Every cell is a tap target and stands on the sheet — and on the short frame,
## where the sheet scrolls, at least within the sheet's width, with the whole
## plan no taller than three cells of the maximum size.
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
		var pr := paneel.get_global_rect().grow(0.5)
		var rolt := kaart.size.y > rol.size.y + 0.5
		var ic: Label = kaart.get_node("Pzwembad/Icoon")
		var nm: Label = kaart.get_node("Pzwembad/Naam")
		print("[maat] plattegrond %s: cel %s gat %.0f plan %s rolt=%s zwembad icoon %s naam %s"
			% [str(kader), str(kaart.celmaat()), kaart.gat(), str(kaart.size), str(rolt),
				str(ic.size), str(nm.size)])
		waar(kaart.size.y <= float(HOOG_MAX),
			"de hele plattegrond blijft onder %d eenheden hoog bij %s (%s)"
				% [HOOG_MAX, str(kader), str(kaart.size)])
		waar(kaart.size.x <= pr.size.x,
			"en niet breder dan het vel bij %s (%.1f > %.1f)"
				% [str(kader), kaart.size.x, pr.size.x])
		for id in UiPlattegrond.KAART:
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

## The plan is a plan: the four rooms of the middle row share one line, and the
## two bedrooms sit above and below the corridor they open onto.
func test_de_plattegrond_is_een_plattegrond() -> void:
	var uit: Array = await _open(Vector2(1000, 648))
	var kaart: UiPlattegrond = uit[1]
	var gang := (kaart.get_node("Pgang") as Control).get_global_rect()
	for id in RIJ_MIDDEN:
		var r := (kaart.get_node("P" + id) as Control).get_global_rect()
		waar(absf(r.position.y - gang.position.y) <= 0.5,
			"%s staat op de rij van de gang (%.1f vs %.1f)" % [id, r.position.y, gang.position.y])
	var links := (kaart.get_node("Preceptie") as Control).get_global_rect()
	waar(links.end.x <= gang.position.x, "de receptie ligt links van de gang")
	var keuken := (kaart.get_node("Pkeuken") as Control).get_global_rect()
	waar(keuken.position.x >= gang.end.x, "de keuken ligt rechts van de gang")
	var k1 := (kaart.get_node("Pkamer1") as Control).get_global_rect()
	var k2 := (kaart.get_node("Pkamer2") as Control).get_global_rect()
	waar(k1.end.y <= gang.position.y, "kamer 1 ligt boven de gang")
	waar(k2.position.y >= gang.end.y, "kamer 2 ligt onder de gang")
	waar(absf(k1.position.x - gang.position.x) <= 0.5 \
		and absf(k2.position.x - gang.position.x) <= 0.5,
		"en beide in de kolom van de gang")
	# every door of the hotel between two neighbouring cells, once per pair
	gelijk(kaart.deurparen(), 7, "zeven deuren tussen buren")
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
