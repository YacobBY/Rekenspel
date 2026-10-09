extends Proef
## De voerkar (games-a.md §7), headless gespeeld door de ctx heen.
##
## V2 — de keukenvloer is leeg.  De vul-fase met de bakjes, de zak en de
## pak-knoppen is gesloopt; de kar vertrekt vol (eigenaarsbeslissing
## "doorduwen") en het spel speelt zich af in het rondje.  Elke beurt wordt
## gedreven zoals een kind hem speelt: een tik op een knop van `Hits`, nooit
## door een interne functie aan te roepen.  Wat hier vastligt: de
## aanmelding, één hele beurt per band, de lege keukenvloer, het herstel uit
## de savegame (nieuwe én oude vorm), een schone wereld na `stop()`, elke
## kindtekst letterlijk, en 0 % dekking in vier kaders.
##
## Tikken (eigenaar, 2026-09-23): tik op de kar = vast, tik op een deur = kar
## en camera erdoor (de kar blijft vast), tik op het bakje = afleveren, tik op
## de vaste kar = neerzetten, een deur zonder vaste kar neemt hem mee, en er
## hangt nooit meer dan één wolkje bij de kar.

const SPEL := "voerkar"
## de diepte van de achterste helft van het bakje (eten met de neus erin)
const KAMER_SCENE := preload("res://scenes/kamer.gd")
const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024),
	Vector2i(360, 740), Vector2i(740, 360)]

var _laag: Control = null
var _bewaard: Dictionary = {}
var _kar_voor: Dictionary = {}
var _scherm_voor = null
var _tap_voor = null

# ------------------------------------------------------------------ opzet

func _op(kader := Vector2(1000, 648)) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_onthoud()
	_laag = Control.new()
	_laag.size = kader
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	World.meet(Rect2(Vector2.ZERO, kader))

## Alles wat dit spel BUITEN zijn eigen laatje verandert, zodat de suite niet
## van de volgorde van haar bestanden afhangt: de savegame, de plek van de kar
## (het spel duwt hem door het hotel) en de schermmaat die de echte schil bij
## `Ui` achterlaat.
func _onthoud() -> void:
	_bewaard = State.s.duplicate(true)
	_kar_voor = World.ding("kar")
	_scherm_voor = Ui.get("_scherm")
	_tap_voor = Ui.get("_tap")

func _herstel_wereld() -> void:
	if not _kar_voor.is_empty():
		World.zet_ding("kar", _kar_voor)
	for b in Hotel.alle_bakken():
		World.zet_bak(str(b["kamer"]), str(b["slot"]), 0)
	if _scherm_voor != null:
		Ui.set("_scherm", _scherm_voor)
	if _tap_voor != null:
		Ui.set("_tap", _tap_voor)

func _af() -> void:
	Games.stop()
	Hits.wis_alles()
	World.decor_wis_alles()
	Ui.registreer_lagen(null, null, null)
	if _laag != null:
		_laag.queue_free()
		_laag = null
	_herstel_wereld()
	if not _bewaard.is_empty():
		State.s = _bewaard
		_bewaard = {}
	Rooms.herstel()

## `n` gasten uit de pool; de eerste `bedden` ervan krijgen een echt bed van het
## hotel, de rest staat in de receptie.  Dat is precies wat `deelnemers()` ziet.
func _gasten(n: int, bedden_nodig := 0) -> Array:
	State.nieuw_spel()
	State.start_gekozen()
	if bedden_nodig > State.alle_bedden().size():
		_extra_bedden(bedden_nodig)
	var pool := State.gasten_pool()
	var bedden := State.alle_bedden()
	var uit: Array = []
	for i in n:
		var g: Dictionary = pool[i]
		if i < bedden.size():
			g["kamer"] = str(bedden[i]["kamer"])
			g["bed"] = str(bedden[i]["slot"])
		else:
			g["kamer"] = ""
			g["bed"] = ""
		g["waar"] = str(g["kamer"]) if not str(g["kamer"]).is_empty() else "receptie"
		g["nachten"] = 100
		uit.append(g)
	State.s["gasten"] = uit
	State.s["kamerNu"] = "keuken"
	World.sync(uit)
	World.naar("keuken")
	return uit

func _extra_bedden(nodig: int) -> void:
	var plekken := [[78.0, 27.0], [78.0, 75.0], [54.0, 27.0], [54.0, 75.0]]
	for kamer in ["kamer1", "kamer2"]:
		for p in plekken:
			if State.alle_bedden().size() >= nodig:
				return
			Rooms.meubel_zet(kamer, "bed", p[0], p[1])

## Het draaiende spel.  `Games.stop()` doet `queue_free()`, en zonder een beeld
## ertussen hangt die knoop nog steeds onder `Games`: pak dus de laatste die
## niet op de vrijlijst staat, anders leest een test de vorige beurt uit.
func _spel() -> Node:
	var uit: Node = null
	for k in Games.get_children():
		if k.is_queued_for_deletion():
			continue
		if k.has_method("definitie") and k.has_method("deelnemers"):
			uit = k
	return uit

func _start(n: int, band: int, dag := 1, bedden_nodig := 0) -> Node:
	_gasten(n, bedden_nodig)
	State.s["dag"] = dag
	State.s["kunnen"] = maxi(3, band - 1)
	State.herbereken()
	Games.start(SPEL)
	Hits.plaats()
	return _spel()

# ------------------------------------------------------------- hulpjes

func _knop(id: String) -> BaseButton:
	var s := Hits.spot(id)
	if s == null or not is_instance_valid(s.knoop):
		return null
	return s.knoop as BaseButton

## Een tik zoals een kind hem geeft: alleen op een knop die er echt staat.  Een
## knop die `Hits` van het glas heeft gehaald (een hotelknop die het spel niet
## leende, een knop in een andere kamer) kan een vinger niet raken.
func _tik(id: String) -> bool:
	var k := _knop(id)
	if k == null or not _zichtbaar(id):
		fout("knop %s staat er niet (wel: %s)" % [id, str(_knoppen())])
		return false
	k.emit_signal("pressed")
	Hits.plaats()
	return true

## Staat deze knop nu op het glas?
func _zichtbaar(id: String) -> bool:
	var s := Hits.spot(id)
	return s != null and is_instance_valid(s.knoop) and s.zichtbaar \
		and s.knoop.is_visible_in_tree()

## Alles wat nu op het glas staat, voor een foutmelding die iets zegt.
func _knoppen() -> Array[String]:
	var uit: Array[String] = []
	for id in Hits.lijst():
		if _zichtbaar(id):
			uit.append(id)
	return uit

## De wolkjes van de voerkar die nu in beeld hangen (informatie, geen knoppen).
func _wolkjes() -> Array[String]:
	var uit: Array[String] = []
	for id in Hits.lijst():
		var s := Hits.spot(id)
		if s != null and s.door == SPEL and s.knoop is UiWolk and _zichtbaar(id):
			uit.append(id)
	return uit

## De knoppen van de voerkar zelf die nu in beeld staan (geen wolkjes).
func _eigen_knoppen() -> Array[String]:
	var uit: Array[String] = []
	for id in Hits.lijst():
		var s := Hits.spot(id)
		if s != null and s.door == SPEL and not (s.knoop is UiWolk) and _zichtbaar(id):
			uit.append(id)
	return uit

## De geleende hotelknoppen die nu in beeld staan (deuren, het bakje).
func _geleend() -> Array[String]:
	var uit: Array[String] = []
	for id in Hits.lijst():
		var s := Hits.spot(id)
		if s != null and s.geleend_door == SPEL and _zichtbaar(id):
			uit.append(id)
	return uit

## Wacht tot het spel zichzelf gesloten heeft (het slotwolkje sluit na 2,6 s).
func _wacht_dicht(max_s := 4.0) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var t := 0.0
	while t < max_s and Games.actief() == SPEL:
		await boom.create_timer(0.05).timeout
		t += 0.05

## Wacht echte tijd, in stapjes, zodat de timers van het spel lopen.
func _wacht(s: float) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	await boom.create_timer(s).timeout
	Hits.plaats()

## Het bakje van een open kamer, als hotspot-id.
func _bak_id(q: Dictionary) -> String:
	return "bak_%s_%s" % [str(q["kamer"]), str(q["slot"])]

## De somkaart bij het bakje (2026-09-24), of null.
func _som_kaart() -> UiSomkaart:
	var s := Hits.spot("vk_som")
	if s == null or not is_instance_valid(s.knoop):
		return null
	return s.knoop as UiSomkaart

## Wat er op de somkaart van het bakje staat: regel | regel2 | som.
func _som_tekst() -> String:
	var k := _som_kaart()
	if k == null:
		return ""
	return "%s | %s | %s" % [k.regel_label.text if k.regel_label != null else "",
		k.regel2_label.text if k.regel2_label != null else "",
		k.som_label.text if k.som_label != null else ""]

## De getallen op de strook onder die kaart, zoals een kind ze ziet.
func _getallen() -> Array[int]:
	var uit: Array[int] = []
	var s := Hits.spot("vk_som_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		return uit
	var rij = s.knoop.get_node_or_null("Rij")
	if rij == null:
		return uit
	for k in rij.get_children():
		var naam := str(k.name)
		if naam.begins_with("Kn"):
			uit.append(int(naam.substr(2)))
	return uit

## Eén tik op het getal `n` van die strook (er is geen toetsenbord).
func _kies(n: int) -> bool:
	var s := Hits.spot("vk_som_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		fout("de strook van het bakje staat er niet (wel: %s)" % str(_knoppen()))
		return false
	var k := s.knoop.get_node_or_null("Rij/Kn%d" % n) as BaseButton
	if k == null:
		fout("%d staat niet op de strook (%s)" % [n, str(_getallen())])
		return false
	k.emit_signal("pressed")
	Hits.plaats()
	return true

## Het goede antwoord op de som van het bakje in deze kamer.
func _beantwoord(spel: Node, kamer: String) -> bool:
	return _kies(int(spel.bak_goed(kamer)))

## Een getal van de strook dat NIET het goede antwoord is.
func _fout_getal(spel: Node, kamer: String) -> int:
	var goed := int(spel.bak_goed(kamer))
	for n in _getallen():
		if n != goed:
			return n
	return goed + 1

## De som die bij `n` gasten met `per` koekjes elk op de kaart hoort
## (games-a.md §7.6): een keersom waar de band die tafel kent, anders de
## herhaalde optelling, en bij één gast alleen het getal.
func _verwachte_som(band: int, n: int, per: int) -> String:
	if n <= 1:
		return "%d =" % per
	if band >= 4 and (Sommen.TAFEL_SET[band] as Array).has(per):
		return "%d × %d =" % [n, per]
	var delen := PackedStringArray()
	for _i in n:
		delen.append(str(per))
	return " + ".join(delen) + " ="

## Is deze kamer nog open (daar wacht iemand op zijn koekjes)?
func _open(spel: Node, kamer: String) -> Dictionary:
	for q in spel.open_kamers():
		if str(q["kamer"]) == kamer:
			return q
	return {}

## Draagt het bordje van deze deur een 👉?
func _wijst(deur_id: String) -> bool:
	return _tekst(deur_id).begins_with("👉")

func _tekst(id: String) -> String:
	var k := _knop(id)
	if k == null:
		return ""
	if k is UiWolk:
		var w := k as UiWolk
		var los := PackedStringArray()
		for deel in [w.icoon_label.text, w.getal_label.text, w.zeg_label.text]:
			if not str(deel).is_empty():
				los.append(str(deel))
		return " ".join(los)
	return str(k.text)

func _titel(id: String) -> String:
	var k := _knop(id)
	return "" if k == null else str(k.tooltip_text)

# ------------------------------------------------------------ aanmelding

## Het spel meldt zich met de rij van architecture.md §12.2 en heeft geen eigen
## prikbordkaartje: het hotel heeft er al één (`voer`).
func test_aanmelding_en_ontgrendeling() -> void:
	_op()
	var def := Games.definitie(SPEL)
	gelijk(def.get("naam", ""), "De voerkar", "naam")
	gelijk(def.get("kamer", ""), "keuken", "kamer")
	gelijk(def.get("id", ""), SPEL, "de mapnaam is het id")
	var hs: Dictionary = def.get("hotspot", {})
	gelijk(hs.get("obj", ""), "kar", "hangt aan de kar")
	gelijk(hs.get("icoon", ""), "🛒", "pictogram")
	gelijk(hs.get("label", ""), "Voerkar", "en een woord ernaast (HOTEL.md §9)")
	waar(not def.has("taak"), "geen eigen taakkaartje: het hotel heeft `voer` al")
	var slot = def.get("unlock", null)
	waar(slot is Callable, "er is een unlock")
	waar(not slot.call(0, 3), "zonder gasten geen voerkar")
	waar(slot.call(1, 3), "vanaf één gast wel")
	_gasten(2)
	waar(Games.ontgrendeld(SPEL), "met twee gasten ontgrendeld")
	# het prikbord van het hotel stuurt naar dit spel
	World.zet_bak("kamer1", "bak", 0)
	State.s["taken"] = []
	Hotel.bouw_taken(true)
	var kaart := {}
	for q in State.s["taken"]:
		if str(q.get("id", "")) == "voer":
			kaart = q
	gelijk(kaart.get("tekst", ""), "Vul de voerkar", "het kaartje van het hotel")
	gelijk(kaart.get("actie", ""), "game:voerkar", "en het start dit spel")
	_af()

## Zonder gast met een bed: één wolkje en dan sluit het spel zichzelf.
func test_zonder_gasten_een_wolkje_en_dicht() -> void:
	_op()
	State.nieuw_spel()
	State.start_gekozen()
	State.s["gasten"] = []
	World.sync([])
	World.naar("keuken")
	Games.start(SPEL)
	Hits.plaats()
	gelijk(_tekst("vk_leeg"), "🛏 nog geen gasten", "het wolkje zegt het in woorden")
	var boom := Engine.get_main_loop() as SceneTree
	var t := 0.0
	while t < 2.4 and Games.actief() == SPEL:
		await boom.process_frame
		t += 0.05
		await boom.create_timer(0.05).timeout
	gelijk(Games.actief(), "", "en daarna is het spel dicht")
	_af()

# ---------------------------------------------------------- de kindteksten

## F3: elke zin van games-a.md §7.7 staat letterlijk in de bron.
func test_kindteksten_staan_er_verbatim() -> void:
	var f := FileAccess.open("res://games/voerkar/spel.gd", FileAccess.READ)
	waar(f != null, "spel.gd is te lezen")
	if f == null:
		return
	var bron := f.get_as_text()
	f.close()
	for zin in [
			"nog geen gasten",
			"Verdeel %d koekjes over %s",
			"🫙 Ieder evenveel, de rest in de pot",
			"pak %d",
			"zak met %d koekjes, pak %d per tik",
			"nog in de zak", "zak is leeg",
			"pot", "%s heeft %d koekjes", "de snoeppot: %d koekjes",
			"%d erbij", "%d eraf", "hier hoort %d in",
			"Klaar", "de kar is klaar",
			"Opnieuw", "alles opnieuw verdelen",
			"de voerkar: nog %d %s",
			"Pak de kar", "Je duwt de kar",
			"Breng %d koekjes naar elke gast", "Tik op de kar", "Tik op een deur", "Tik op het bakje",
			"Alle bakjes vol!",
			"koekjes", "koekjes elk",
			"Hoeveel koekjes gaan in het bakje?", "Elke gast krijgt %s",
			"de som van het bakje",
			"🔄", "🛒", "🍪", "🫙", "🛏", "👉", "✅", "😋"]:
		waar(bron.contains(zin), 'games-a.md §7.7: "%s" staat in de bron' % zin)
	# buurvrouw Els is weg (eigenaar 2026-09-24: geen hulp na een fout)
	for weg in ["\"Els helpt\"", "buurvrouw Els doet het voor", "Iedereen %d, rest in de pot",
			"\"🩺\"", "vk_els"]:
		waar(not bron.contains(weg), "geen Els meer in de bron: %s" % weg)
	# tikken, niet slepen (eigenaar, 2026-09-23): geen enkele zin vraagt nog
	# om te slepen, en de oude knop- en wolkteksten van de kar zijn weg
	for weg in ["Sleep de kar", "\"kar is leeg\"", "\"nog %d %s\""]:
		waar(not bron.contains(weg), 'de oude tekst %s is weg' % weg)
	# elk kindwoord moet ook een glyph hebben in het meegeleverde font
	var mist: Array[String] = []
	for zin in ["🍪 Verdeel 17 koekjes over 5 gasten", "🫙 Ieder evenveel, de rest in de pot",
			"🛒 Klaar", "🛏 nog geen gasten",
			"🛒 Pak de kar", "🛒 Je duwt de kar ☝", "🍪 Breng 4 koekjes naar elke gast",
			"👉 Tik op de kar", "👉 Tik op een deur", "👉 Tik op het bakje", "👉 🚪 Gang",
			"✅ Alle bakjes vol!", "😋 4 koekjes elk",
			"🍪 Hoeveel koekjes gaan in het bakje?", "Elke gast krijgt 1 koekje",
			"2 × 4 =", "4 + 4 + 4 =", "🔄 Nog een keer",
			"🐶 Boef 12 · 8 eraf", "🐱 🐰 🦆 🐾", "🛒 de voerkar: nog 2 kamers"]:
		for c in Ui.mist_tekens(zin):
			if not mist.has(c):
				mist.append(c)
	gelijk(str(mist), "[]", "elk teken van een kindzin zit in het font")

## De zinnen op de kaart houden zich aan F4 (≤ 8 woorden, ≤ 40 tekens), voor elk
## aantal gasten en elke band, en de somregel volgt games-a.md §7.2.
func test_de_kaart_past_binnen_f4() -> void:
	_op()
	var spel = load("res://games/voerkar/spel.gd").new()
	for band in [3, 4, 5]:
		for n in range(1, 7):
			for dag in range(1, 7):
				var som := Sommen.deel(n, band, dag)
				var zin1: String = spel.T_VERDEEL % [int(som["T"]),
					Ui.meervoud(n, "gast", "gasten")]
				_keur_regel(zin1, "band %d, %d gasten, dag %d" % [band, n, dag])
				var regel := Sommen.Voerkar.som_regel(band, int(som["T"]), n, int(som["r"]))
				if band <= 3:
					gelijk(regel, "", "band 3 kent het deelteken nog niet")
				elif int(som["r"]) == 0:
					gelijk(regel, "%d : %d" % [int(som["T"]), n], "band %d deelt uit" % band)
				else:
					gelijk(regel, "", "delen mét rest hoort pas in groep 5")
	_keur_regel(spel.T_IEDER, "de tweede zin")
	spel.free()
	_af()

func _keur_regel(zin: String, wat: String) -> void:
	var woorden := zin.split(" ", false).size()
	waar(woorden <= 8 and zin.length() <= 40,
		"%s: \"%s\" = %d woorden, %d tekens" % [wat, zin, woorden, zin.length()])

## De zinnen van het rondje (tikken, 2026-09-23) houden zich aan dezelfde regel,
## met het grootste getal dat `Sommen.deel` per gast ooit geeft.
func test_de_zinnen_bij_de_kar_passen_binnen_f4() -> void:
	_op()
	var spel = load("res://games/voerkar/spel.gd").new()
	var per_max := 0
	for band in [3, 4, 5]:
		for n in range(1, 7):
			for dag in range(1, 8):
				per_max = maxi(per_max, int(Sommen.deel(n, band, dag)["k"]))
	for zin in [spel.T_PAK_KAR, spel.T_DUW_KAR, spel.T_BRENG % per_max,
			spel.T_TIK_KAR, spel.T_TIK_DEUR, spel.T_TIK_BAK, spel.T_ALLE_VOL,
			spel.T_KAR_TITEL % [6, spel.T_KAMERS],
			# de som bij het bakje (2026-09-24)
			spel.T_HOEVEEL, spel.T_LADING, spel.T_ELK % Ui.meervoud(per_max, "koekje", "koekjes"),
			spel.T_ELK % Ui.meervoud(1, "koekje", "koekjes")]:
		_keur_regel(zin, "de kar")
		gelijk(str(Ui.mist_tekens(zin)), "[]", "elk teken van \"%s\" zit in het font" % zin)
	spel.free()
	_af()

# ------------------------------------------------------------- hele beurten

func test_beurt_band_3() -> void:
	await _hele_beurt(3, 3, 1)

func test_beurt_band_4() -> void:
	await _hele_beurt(4, 5, 3)

func test_beurt_band_5() -> void:
	await _hele_beurt(5, 7, 5)

## Eén hele beurt, gespeeld zoals een kind hem speelt (wave 2, eigenaar
## 2026-10-08: "rekenen moet minstens 50% van de interactie zijn"): eerst de
## som van de kar in de keuken (in band 4 eerst één keer mis), daarna rijdt de
## kar zelf naar elke kamer met honger en vraagt het bakje daar zijn som — geen
## tik op de kar, een deur of het bakje.  Bij de laatste levering gaat de rest
## in de snoeppot en sluit de lus.  Bij elke stap hangt er hoogstens één wolkje.
func _hele_beurt(band: int, n: int, dag: int) -> void:
	_op()
	Ui.zet_rust_modus(true)
	var spel := _start(n, band, dag, mini(n, 6))
	waar(spel != null, "band %d: het spel draait" % band)
	if spel == null:
		Ui.zet_rust_modus(false)
		_af()
		return
	gelijk(State.band(), band, "band %d is echt de band" % band)
	var g: Array = spel.deelnemers()
	var som := Sommen.deel(g.size(), band, dag)
	gelijk(int(spel.K["T"]), int(som["T"]), "band %d: T uit Sommen.deel" % band)
	gelijk(int(spel.K["per"]), int(som["k"]), "band %d: per gast" % band)
	gelijk(int(spel.K["rest"]), int(som["r"]), "band %d: in de pot" % band)
	gelijk(str(spel.K["stap"]), "som", "band %d: de beurt begint met de som van de kar" % band)
	gelijk(int(spel.K["op_kar"]), 0, "band %d: de kar is nog leeg" % band)
	# de keukenvloer is leeg: geen bakjes, geen zak, geen pak-knoppen
	gelijk(World.decor_lijst("keuken").size(), 0, "band %d: geen los decor in de keuken" % band)
	for id in ["vk_zak", "vk_klaar", "vk_opnieuw", "vk___pot", "karhot"]:
		waar(Hits.spot(id) == null, "band %d: %s is er niet" % [band, id])
	var lading := int(som["k"]) * g.size()
	gelijk(_lading_tekst(), "🍪 Hoeveel koekjes gaan op de kar? | Elke gast krijgt %s | %s" % [
		Ui.meervoud(int(som["k"]), "koekje", "koekjes"),
		_verwachte_som(band, g.size(), int(som["k"]))], "band %d: de som van de kar" % band)
	waar(_getallen_op(LADING).has(lading) and _getallen_op(LADING).size() == 4,
		"band %d: vier getallen, het goede erbij (%s)" % [band, str(_getallen_op(LADING))])
	gelijk(str(_geleend()), "[]", "band %d: geen deur en geen bakje is van de kar" % band)
	var sterren_voor := int(State.s["sterren"])
	var pot_voor := int(State.s["snoeppot"])
	if band == 4:
		var getallen := _getallen_op(LADING)
		waar(_kies_op(LADING, _fout_op(LADING, lading)), "band 4: een fout getal")
		gelijk(int(spel.K["missers"]), 1, "band 4: de misser telt")
		gelijk(str(spel.K["stap"]), "som", "band 4: de kar blijft staan")
		await _wacht(float(Ui.MIS_PAUZE) + 0.2)
		gelijk(str(_getallen_op(LADING)), str(getallen), "band 4: dezelfde vier getallen")
	waar(_kies_op(LADING, lading), "band %d: het goede getal" % band)
	gelijk(str(spel.K["stap"]), "duwen", "band %d: nu rijdt de kar" % band)
	gelijk(int(spel.K["op_kar"]), lading, "band %d: de lading is het antwoord" % band)
	var ronden := 0
	var mis_gedaan := false
	while not spel.open_kamers().is_empty() and ronden < 8:
		ronden += 1
		# de kar rijdt zelf; het bakje vraagt zijn som zonder tik
		waar(await _wacht_tot(func() -> bool: return _som_kaart() != null, 8.0),
			"band %d: de kar kwam vanzelf bij een bakje (ronde %d)" % [band, ronden])
		if _som_kaart() == null:
			break
		var kamer := World.kamer_nu()
		gelijk(str(World.ding("kar").get("kamer", "")), kamer, "band %d: de kar staat waar het kind kijkt" % band)
		var q := _open(spel, kamer)
		waar(not q.is_empty(), "band %d: %s heeft honger" % [band, kamer])
		gelijk(str(_geleend()), "[]", "band %d: in %s is niets van de kar geleend" % [band, kamer])
		var kar_voor := int(spel.K["op_kar"])
		var hier := 0
		for gg in g:
			if str(gg.get("kamer", "")) == kamer:
				hier += 1
		var goed := int(som["k"]) * hier
		gelijk(_som_tekst(), "🍪 Hoeveel koekjes gaan in het bakje? | Elke gast krijgt %s | %s" % [
			Ui.meervoud(int(som["k"]), "koekje", "koekjes"),
			_verwachte_som(band, hier, int(som["k"]))], "band %d: de kaart bij het bakje" % band)
		gelijk(int(spel.bak_goed(kamer)), goed, "band %d: %d gasten × %d" % [band, hier, int(som["k"])])
		waar(_getallen().has(goed) and _getallen().size() == 4,
			"band %d: vier getallen, het goede erbij (%s)" % [band, str(_getallen())])
		if not q.is_empty():
			gelijk(World.bak_stand(kamer, str(q["slot"])), 0, "band %d: het bakje is nog leeg" % band)
		gelijk(str(_wolkjes()), "[]", "band %d: de kaart is de volgende stap, geen wolkje erbij" % band)
		if band == 4 and not mis_gedaan:
			mis_gedaan = true
			var getallen := _getallen()
			_kies(_fout_getal(spel, kamer))
			gelijk(int(spel.K["missers"]), 2, "band %d: de misser telt (alleen voor de band)" % band)
			waar(_som_kaart() != null, "band %d: en de vraag blijft staan" % band)
			await _wacht(float(Ui.MIS_PAUZE) + 0.2)
			gelijk(str(_getallen()), str(getallen), "band %d: met dezelfde vier getallen" % band)
		_beantwoord(spel, kamer)
		waar(spel.K["geleverd"].has(kamer), "band %d: afleveren in %s lukt" % [band, kamer])
		waar(_som_kaart() == null, "band %d: de som van het bakje is weg" % band)
		if not q.is_empty():
			gelijk(World.bak_stand(kamer, str(q["slot"])), 4, "band %d: het bakje is vol" % band)
		gelijk(int(spel.K["op_kar"]), kar_voor - goed, "band %d: de kar draagt %d minder" % [band, goed])
		for gg in g:
			if str(gg.get("kamer", "")) == kamer:
				waar(bool(gg.get("gegeten", false)), "band %d: %s heeft gegeten" % [band, gg["naam"]])
		gelijk(_tekst("vk_smul"), "😋 %d %s" % [int(som["k"]), "koekjes elk" if hier > 1 else "koekjes"],
			"band %d: het smulwolkje telt per dier" % band)
	waar(spel.open_kamers().is_empty(), "band %d: elke kamer is bediend (%d ronden)" % [band, ronden])
	gelijk(int(spel.K["op_kar"]), 0, "band %d: de kar is leeg" % band)
	gelijk(int(State.s["sterren"]), sterren_voor + 1, "band %d: één ster voor het meedoen" % band)
	gelijk(int(State.s["snoeppot"]), pot_voor + int(som["r"]), "band %d: de rest ging in de snoeppot" % band)
	gelijk(_tekst("vk_zeg"), "✅ Alle bakjes vol!", "band %d: alles rond" % band)
	gelijk(str(_eigen_knoppen()), "[]", "band %d: aan het eind is er geen knop van de kar meer" % band)
	gelijk(str(_geleend()), "[]", "band %d: en geen geleende deur of bakje" % band)
	await _wacht_dicht()
	gelijk(Games.actief(), "", "band %d: het spel sluit zichzelf" % band)
	gelijk(State.s["kar"], null, "band %d: de kar is opgeruimd" % band)
	Ui.zet_rust_modus(false)
	_af()

# ---------------------------------------------------------------- tikken

## Sinds wave 2 is de kar geen knop meer (eigenaar 2026-10-08: rekenen eerst):
## de beurt begint met de som van de kar, en geen enkele deur van de keuken is
## van het spel.  (Tot dan: tik op de kar = vast, eigenaar 2026-09-23.)
func test_een_tik_op_de_kar_pakt_hem() -> void:
	_op()
	var spel := _start(2, 3, 1, 2)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	waar(Hits.spot("karhot") == null, "de kar is geen knop")
	waar(Hits.spot(LADING) != null, "de som van de kar hangt er")
	gelijk(str(spel.K["stap"]), "som", "en de kar wacht op het antwoord")
	gelijk(str(_geleend()), "[]", "geen deur is van de kar")
	var s := Hits.spot("deur_keuken_gang")
	waar(s == null or s.geleend_door != SPEL, "ook de gangdeur niet")
	gelijk(str(_wolkjes()), "[]", "geen wolkje: de kaart is de opdracht")
	_af()

## Na de som van de kar rijdt de kar zelf (wave 2): door de gang naar de eerste
## kamer met honger, de camera mee, en daar vraagt het bakje vanzelf zijn som.
## Na het smullen rijdt hij zelf door naar de volgende kamer.
func test_een_tik_op_een_deur_neemt_kar_en_camera_mee() -> void:
	_op()
	Ui.zet_rust_modus(true)
	# drie gasten: twee in kamer1, één in kamer2
	var spel := _start(3, 3, 1, 3)
	waar(spel != null, "het spel draait")
	if spel == null:
		Ui.zet_rust_modus(false)
		_af()
		return
	waar(_laad(spel), "de som van de kar")
	waar(await _wacht_tot(func() -> bool: return _som_kaart() != null, 6.0), "de kar kwam vanzelf aan")
	var eerste := World.kamer_nu()
	waar(eerste == "kamer1" or eerste == "kamer2", "in een kamer met honger (%s)" % eerste)
	gelijk(str(World.ding("kar").get("kamer", "")), eerste, "met de kar")
	waar(not spel.K["geleverd"].has(eerste), "het bakje is nog niet gevuld")
	_beantwoord(spel, eerste)
	waar(spel.K["geleverd"].has(eerste), "het bakje is gevuld")
	gelijk(str(_wolkjes()), '["vk_smul"]', "tijdens het smullen hangt alleen het smulwolkje")
	waar(await _wacht_tot(func() -> bool: return _som_kaart() != null, float(spel.SMUL_MS) + 6.0),
		"na het smullen rijdt de kar zelf door")
	var tweede := World.kamer_nu()
	waar(tweede != eerste and (tweede == "kamer1" or tweede == "kamer2"),
		"naar de andere kamer (%s)" % tweede)
	gelijk(str(_geleend()), "[]", "zonder één geleende deur")
	Ui.zet_rust_modus(false)
	_af()

## Geen deur en geen bakje is ooit van de kar (wave 2): ook tijdens de rit en
## bij het bakje staat er geen geleende hotelknop, en een tik op de gangdeur
## is er niet eens (het hotel haalt zijn deuren weg zolang het spel loopt).
func test_een_tik_op_de_vaste_kar_zet_hem_neer() -> void:
	_op()
	Ui.zet_rust_modus(true)
	var spel := _start(2, 3, 1, 2)
	waar(spel != null, "het spel draait")
	if spel == null:
		Ui.zet_rust_modus(false)
		_af()
		return
	waar(_laad(spel), "de som van de kar")
	gelijk(str(_geleend()), "[]", "onderweg niets geleend")
	waar(await _wacht_tot(func() -> bool: return _som_kaart() != null, 6.0), "de kar kwam vanzelf aan")
	gelijk(str(_geleend()), "[]", "bij het bakje niets geleend")
	var q := _open(spel, World.kamer_nu())
	waar(not q.is_empty() and not _zichtbaar(_bak_id(q)), "het bakje is geen knop: de som hangt er al")
	Ui.zet_rust_modus(false)
	_af()

## R2 (wave 2): de som van de kar is niet over te slaan.  Een fout getal is
## alleen een misser — de kar blijft leeg in de keuken, dezelfde kaart met
## dezelfde vier getallen — en pas het goede getal laat hem rijden.
func test_een_deur_zonder_vaste_kar_neemt_hem_mee() -> void:
	_op()
	var spel := _start(2, 3, 1, 2)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	var goed := int(spel.K["lading_goed"])
	var voor := _lading_tekst()
	var getallen := _getallen_op(LADING)
	waar(_kies_op(LADING, _fout_op(LADING, goed)), "een fout getal")
	gelijk(int(spel.K["missers"]), 1, "een misser")
	gelijk(int(spel.K["mis"]), 1, "op de open vraag")
	gelijk(str(spel.K["stap"]), "som", "de kar rijdt niet")
	gelijk(int(spel.K["op_kar"]), 0, "en is nog leeg")
	gelijk(str(World.ding("kar").get("kamer", "")), "keuken", "hij staat nog in de keuken")
	gelijk(_tekst("mis_" + LADING), "🔄 Nog een keer", "alleen: nog een keer")
	await _wacht(float(Ui.MIS_PAUZE) + 0.2)
	gelijk(_lading_tekst(), voor, "dezelfde vraag")
	gelijk(str(_getallen_op(LADING)), str(getallen), "met dezelfde vier getallen")
	waar(_kies_op(LADING, goed), "het goede getal")
	gelijk(str(spel.K["stap"]), "duwen", "nu rijdt de kar")
	gelijk(int(spel.K["mis"]), 0, "en de open vraag is beantwoord")
	_af()

## Na `stop()` zijn de deurbordjes van het hotel: geen 👉 en niets geleend.
func test_na_stop_wijst_geen_deur_meer() -> void:
	_op()
	var spel := _start(2, 3, 1, 2)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	waar(_laad(spel), "de som van de kar")
	Games.stop()
	World.naar("keuken")
	Hotel.render()
	Hits.plaats()
	gelijk(_tekst("deur_keuken_gang"), "🚪 Gang", "het bordje is gewoon")
	var s := Hits.spot("deur_keuken_gang")
	waar(s != null and s.geleend_door == "", "en de deur is van het hotel")
	_af()

# --------------------------------------------------------- de kar komt thuis

## De ingang van dit spel hangt op de kar zelf (`Games._plek_van`), dus een kar
## die na het rondje in kamer2 blijft staan maakt de voerkar onbereikbaar tot de
## pagina herlaadt.  Na de ronde staat hij weer op zijn eigen plek in de keuken,
## zónder dat de camera meegaat.
func test_kar_staat_na_de_ronde_weer_in_de_keuken() -> void:
	_op()
	var spel := _start(3, 3, 1, 3)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	var thuis := World.ding_thuis("kar")
	gelijk(str(thuis.get("kamer", "")), "keuken", "de kar hoort in de keuken")
	waar(_laad(spel), "de som van de kar")
	var ronden := 0
	while not spel.open_kamers().is_empty() and ronden < 8:
		ronden += 1
		var q: Dictionary = spel.open_kamers()[0]
		spel.duw_naar(str(q["kamer"]))
		Hits.plaats()
		waar(spel.lever(str(q["kamer"]), str(q["slot"])),
			"afleveren in %s lukt" % str(q["kamer"]))
		Hits.plaats()
	waar(ronden >= 1, "de kar heeft de keuken verlaten")
	var laatste := World.kamer_nu()
	waar(laatste != "keuken", "en het kind kijkt naar de kamer van het laatste bakje")
	gelijk(_tekst("vk_zeg"), "✅ Alle bakjes vol!", "alles rond")
	await _wacht_dicht()
	gelijk(Games.actief(), "", "het spel sluit zichzelf")
	gelijk(World.kamer_nu(), laatste, "de camera blijft waar het kind keek")
	var kar := World.ding("kar")
	gelijk(str(kar.get("kamer", "")), "keuken", "maar de kar staat weer in de keuken")
	gelijk(float(kar.get("x", 0.0)), float(thuis.get("x", 0.0)), "op zijn eigen plek")
	gelijk(float(kar.get("z", 0.0)), float(thuis.get("z", 0.0)), "in beide richtingen")
	gelijk(str(kar.get("model", "")), str(thuis.get("model", "")), "met zijn eigen model")
	World.naar("keuken")
	Games.hersteek()
	Hits.plaats()
	var knop := _knop("spel_voerkar")
	waar(knop != null and knop.visible, "de 🛒-knop hangt weer zichtbaar in de keuken")
	World.zet_ding("kar", {"kamer": "kamer2", "x": 20.0, "z": 30.0})
	Games.hersteek()
	Hits.plaats()
	var terug := _knop("spel_voerkar")
	waar(terug != null and terug.visible, "ook met de kar in kamer2 blijft het spel bereikbaar")
	var s := Hits.spot("spel_voerkar")
	waar(s != null and is_equal_approx(s.x, float(thuis.get("x", 0.0))),
		"en dan hangt hij op de thuisplek van de kar")
	_af()

# ------------------------------------------------ geen Els, en de ronde

## Nooit straffend: een levering die niet kan, kost niets, zet niets terug en
## geeft geen ster.  En geen hulp na een fout (eigenaar 2026-09-24): buurvrouw
## Els bestaat niet meer — ook niet met twee, drie of vier missers uit een oude
## opslag — en er hangt geen wolkje met haar doelgetal.
func test_geen_els_en_de_ronde_straft_niet() -> void:
	_op()
	var spel := _start(3, 3, 1, 3)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	var sterren_voor := int(State.s["sterren"])
	var q: Dictionary = spel.open_kamers()[0]
	waar(not spel.lever(str(q["kamer"]), str(q["slot"])),
		"zonder de kar in de kamer gaat er niets af")
	gelijk(int(spel.K["missers"]), 0, "en er is geen misser geteld")
	gelijk(int(State.s["sterren"]), sterren_voor, "er is geen ster bij of af")
	waar(not spel.K["geleverd"].has(str(q["kamer"])), "en er is niets geleverd")
	waar(not _zichtbaar(_bak_id(q)), "een bakje zonder kar erbij is geen knop")
	for missers in [2, 3, 4]:
		spel.K["missers"] = missers
		spel._rondje()
		Hits.plaats()
		waar(_knop("vk_els") == null, "%d missers: geen Els" % missers)
		gelijk(str(_wolkjes()), '[]', "%d missers: geen wolkje met een doelgetal" % missers)
		waar(Hits.spot(LADING) != null, "%d missers: de som van de kar staat er gewoon" % missers)
	waar(not spel.K.has("spook"), "de kar kent geen spookgetal meer")
	var g: Array = spel.deelnemers()
	gelijk(spel._zinnen(g.size())[1], spel.T_IEDER, "de oude kaart houdt haar gewone tweede zin")
	_af()

## S5, open punt 2026-09-20: de voerkar geeft het dier van de beurt door met
## zijn opdrachtkaart (`o["dier"]`), zodat een misser sip kan worden zodra V3
## de kaart weer in het spel brengt.
func test_het_dier_van_de_beurt_wordt_doorgegeven() -> void:
	_op()
	var spel := _start(2, 3, 1, 2)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	var g: Array = spel.deelnemers()
	waar(not g.is_empty(), "er doen gasten mee")
	waar(_laad(spel), "de som van de kar")
	spel._kaart_neer(g)
	Hits.plaats()
	waar(spel._kaart != null, "de opdrachtkaart hangt er")
	if spel._kaart != null:
		gelijk(str(spel._kaart.dier), str(g[0]["id"]),
			"de kaart noemt het dier van de beurt (o[\"dier\"])")
	# en de som bij het bakje (2026-09-24) noemt een gast van díe kamer
	spel.duw_naar("kamer1")
	Hits.plaats()
	waar(spel.vraag_bak("kamer1"), "het bakje van kamer1 vraagt zijn som")
	Hits.plaats()
	waar(spel._som_kaart != null, "de somkaart bij het bakje hangt er")
	if spel._som_kaart != null:
		var van_hier: Array = []
		for gg in g:
			if str(gg["kamer"]) == "kamer1":
				van_hier.append(str(gg["id"]))
		waar(van_hier.has(str(spel._som_kaart.dier)),
			"de kaart bij het bakje noemt een gast van kamer1 (%s)" % str(spel._som_kaart.dier))
	_af()

# ------------------------------------------------------- de som bij het bakje

## Het bakje vraagt zijn eigen som (eigenaar 2026-09-24: "De koekjes kar naar de
## kamer duwen heeft nu geen rekenwerk meer op het einde").  Per band en per
## aantal gasten in de kamer: groep 3 telt op (`4 + 4 =`), groep 4 en 5 krijgen
## de keersom (`2 × 4 =`), één gast is alleen het getal (`4 =`).  Het goede
## antwoord staat op de strook van vier.
func test_het_bakje_vraagt_de_som_per_band() -> void:
	_op()
	# genoeg gasten voor de band (zoals de hele beurten): drie, vijf, zeven
	for band in [3, 4, 5]:
		var n_gasten: int = {3: 3, 4: 5, 5: 7}[band]
		var spel := _start(n_gasten, band, 2, mini(n_gasten, 6))
		waar(spel != null, "band %d: het spel draait" % band)
		if spel == null:
			break
		gelijk(State.band(), band, "band %d is echt de band" % band)
		waar(_laad(spel), "band %d: de som van de kar" % band)
		var per := int(spel.K["per"])
		gelijk(spel.bak_som(1), "%d =" % per, "band %d: één gast is alleen het getal" % band)
		for kamer in ["kamer1", "kamer2"]:
			var n: int = spel._gasten_in(kamer).size()
			spel.duw_naar(kamer)
			Hits.plaats()
			waar(spel.vraag_bak(kamer), "band %d, %s: het bakje vraagt zijn som" % [band, kamer])
			Hits.plaats()
			gelijk(int(spel.bak_goed(kamer)), per * n, "band %d, %s: %d × %d" % [band, kamer, n, per])
			var k := _som_kaart()
			waar(k != null, "band %d, %s: de kaart hangt er" % [band, kamer])
			if k != null:
				gelijk(k.som_label.text, _verwachte_som(band, n, per), "band %d, %s: de somregel" % [band, kamer])
				waar(k.som_label.visible, "band %d, %s: en die staat in beeld" % [band, kamer])
				gelijk(k.regel_label.text, "🍪 Hoeveel koekjes gaan in het bakje?", "de vraag, met het koekje ervoor")
				gelijk(k.icoon, "🍪", "met het koekje ervoor")
			waar(_getallen().has(per * n), "band %d, %s: het goede getal staat op de strook (%s)" % [
				band, kamer, str(_getallen())])
			waar(_getallen().size() <= 4, "hoogstens vier getallen")
			if band == 3:
				waar(not _som_tekst().contains("×"), "band 3 kent de keersom nog niet")
			_beantwoord(spel, kamer)
			waar(spel.K["geleverd"].has(kamer), "band %d, %s: gevuld" % [band, kamer])
		Games.stop()
		for b in Hotel.alle_bakken():
			World.zet_bak(str(b["kamer"]), str(b["slot"]), 0)
	_af()

## Mis is alleen een misser (eigenaar 2026-09-24: "Nee geef geen hulp na
## fouten"): het bakje blijft leeg, de kar houdt zijn koekjes, er is geen ster
## bij of af, de kaart houdt precies dezelfde vraag en dezelfde vier getallen,
## er verschijnt geen hulpregel — alleen `🔄 Nog een keer` en een sip dier van
## die kamer.  Daarna werkt het goede antwoord gewoon, en de beurt telt als
## "niet in één keer goed".
func test_een_fout_antwoord_is_alleen_een_misser() -> void:
	_op()
	Ui.zet_rust_modus(true)
	var spel := _start(3, 4, 1, 3)
	waar(spel != null, "het spel draait")
	if spel == null:
		Ui.zet_rust_modus(false)
		_af()
		return
	_in_bed(spel)
	waar(_laad(spel), "de som van de kar")
	spel.duw_naar("kamer1")
	Hits.plaats()
	var q := _open(spel, "kamer1")
	waar(spel.vraag_bak("kamer1"), "het bakje vraagt zijn som")
	Hits.plaats()
	var voor := _som_tekst()
	var getallen := _getallen()
	var kar_voor := int(spel.K["op_kar"])
	var sterren_voor := int(State.s["sterren"])
	var dier := str(spel._som_kaart.dier)
	_kies(_fout_getal(spel, "kamer1"))
	gelijk(int(spel.K["missers"]), 1, "de misser telt, alleen voor het adaptieve signaal")
	gelijk(World.bak_stand("kamer1", str(q["slot"])), 0, "het bakje blijft leeg")
	waar(not spel.K["geleverd"].has("kamer1"), "er is niets geleverd")
	gelijk(int(spel.K["op_kar"]), kar_voor, "de kar houdt zijn koekjes")
	gelijk(int(State.s["sterren"]), sterren_voor, "geen ster bij of af")
	gelijk(_som_tekst(), voor, "dezelfde vraag blijft staan")
	var k := _som_kaart()
	waar(k != null and (k.hulp_label == null or not k.hulp_label.visible or k.hulp_label.text.is_empty()),
		"geen hulpregel op de kaart")
	gelijk(_tekst("mis_vk_som"), "🔄 Nog een keer", "alleen: nog een keer")
	var d = World.dier(dier)
	waar(d != null and str(d.staat) == "sip", "het dier van de beurt is sip (%s)" % str(d.staat if d != null else ""))
	if d != null:
		gelijk(str(d.kamer), "kamer1", "in zijn eigen kamer")
		waar(Vector2(d.x, d.z).distance_to(_bak_punt("kamer1")) < 20.0,
			"bij zijn lege bakje, niet in bed")
	for id in _knoppen():
		waar(not id.contains("els") and not id.contains("hulp"), "geen helper in beeld (%s)" % id)
	# de strook staat even op slot; daarna dezelfde vier getallen
	await _wacht(float(Ui.MIS_PAUZE) + 0.2)
	gelijk(str(_getallen()), str(getallen), "dezelfde vier getallen, in dezelfde volgorde")
	waar(not _zichtbaar("mis_vk_som"), "het wolkje van de misser is weer weg")
	_beantwoord(spel, "kamer1")
	waar(spel.K["geleverd"].has("kamer1"), "het goede antwoord vult het bakje gewoon")
	gelijk(World.bak_stand("kamer1", str(q["slot"])), 4, "tot de rand")
	Ui.zet_rust_modus(false)
	_af()

## Alle meespelende gasten in hun eigen bed, zoals het hotel ze 's ochtends
## neerlegt (`Hotel.herstel_wereld`).  In rustmodus, zodat niemand eerst door
## het hotel hoeft te lopen: `World.sync` laat een dier van een vorige test staan
## waar het stond.
func _in_bed(spel: Node) -> void:
	var was := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	for g in spel.deelnemers():
		World.slaap(str(g["id"]), str(g["kamer"]), str(g["bed"]))
	Ui.zet_rust_modus(was)

## Het midden van een bakje, als vloerpunt.
func _bak_punt(kamer: String) -> Vector2:
	var s := Rooms.slot(kamer, "bak")
	return Vector2(float(s.get("x", 0.0)), float(s.get("z", 0.0)))

## R2 (wave 2): een som van een bakje met een misser komt onveranderd terug na
## ⬅ Terug (het spel gaat dicht en weer open): de kar en de camera staan weer
## bij dat bakje, met dezelfde kaart en dezelfde vier getallen.
func test_weglopen_en_terugkomen_geeft_dezelfde_vraag() -> void:
	_op()
	var spel := _start(3, 4, 1, 3)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	waar(_laad(spel), "de som van de kar")
	spel.duw_naar("kamer1")
	Hits.plaats()
	waar(spel.vraag_bak("kamer1"), "het bakje van kamer1 vraagt zijn som")
	Hits.plaats()
	var voor := _som_tekst()
	var getallen := _getallen()
	_kies(_fout_getal(spel, "kamer1"))
	gelijk(int(spel.K["mis"]), 1, "een misser op de open vraag")
	gelijk(str(spel.K["vraag"]), "kamer1", "de open vraag staat in de stand van de kar")
	Games.stop()
	World.naar("keuken")
	Games.start(SPEL)
	Hits.plaats()
	var terug := _spel()
	waar(terug != null, "het spel draait weer")
	if terug == null:
		_af()
		return
	gelijk(World.kamer_nu(), "kamer1", "de camera staat weer bij het bakje")
	gelijk(str(terug.K["vraag"]), "kamer1", "de vraag staat nog open")
	gelijk(_som_tekst(), voor, "dezelfde vraag")
	gelijk(str(_getallen()), str(getallen), "met dezelfde vier getallen")
	_af()

# ---------------------------------------------------- eten bij het bakje

## "Bij het vullen van het eten lopen de dieren niet naar de voerbakjes toe. De
## eet animatie gebeurt op het bed" (eigenaar 2026-09-24).  De gasten liggen in
## bed; na het goede antwoord staat elke gast van die kamer naast het bakje en
## eet daar: op de vloer, bij het bakje, niet op zijn bed, niet op een ander,
## niet onder de kar, en met zijn gezicht naar het bakje.  In rustmodus meteen.
func test_de_gasten_eten_bij_het_bakje() -> void:
	_op()
	Ui.zet_rust_modus(true)
	# zes gasten: vier in kamer1 (twee gekochte bedden erbij), twee in kamer2
	var spel := _start(6, 4, 1, 6)
	waar(spel != null, "het spel draait")
	if spel == null:
		Ui.zet_rust_modus(false)
		_af()
		return
	_in_bed(spel)
	waar(_laad(spel), "de som van de kar")
	for g in spel.deelnemers():
		waar(World.slaapt(str(g["id"])), "%s ligt in bed" % g["naam"])
	for kamer in ["kamer1", "kamer2"]:
		var hier: Array = spel._gasten_in(kamer)
		waar(not hier.is_empty(), "%s heeft gasten" % kamer)
		spel.duw_naar(kamer)
		Hits.plaats()
		waar(spel.vraag_bak(kamer), "%s: het bakje vraagt zijn som" % kamer)
		Hits.plaats()
		for g in hier:
			waar(World.slaapt(str(g["id"])), "%s ligt nog in bed tijdens de som" % g["naam"])
		_beantwoord(spel, kamer)
		waar(spel.K["geleverd"].has(kamer), "%s is gevoerd" % kamer)
		var bak := _bak_punt(kamer)
		var kar := World.ding("kar")
		var plekken: Array = []
		var snuit := 0
		for g in hier:
			var d = World.dier(str(g["id"]))
			var bed := Rooms.slot(kamer, str(g["bed"]))
			var p := Vector2(d.x, d.z)
			gelijk(str(d.kamer), kamer, "%s eet in zijn eigen kamer" % g["naam"])
			gelijk(str(d.staat), "eet", "%s eet" % g["naam"])
			waar(str(d.pose).begins_with("hap"), "%s hapt (%s)" % [g["naam"], d.pose])
			waar(not World.slaapt(str(g["id"])), "%s is uit bed" % g["naam"])
			gelijk(float(d.hoogte), 0.0, "%s staat op de vloer, niet op de matras" % g["naam"])
			# 25: sinds de vaste bedplekken (2026-09-24) staat bed 3 van kamer 1
			# vlak onder het bakje, en in een volle kamer eet de derde gast dan
			# één ring verder (±24) — nog steeds naast het bakje, niet bij zijn bed
			waar(p.distance_to(bak) < 25.0, "%s staat bij het bakje (%.1f)" % [g["naam"], p.distance_to(bak)])
			waar(p.distance_to(Vector2(float(bed["x"]), float(bed["z"]))) > 10.0,
				"%s staat niet op zijn bed" % g["naam"])
			waar(Rooms.vrij_vak(kamer, p.x, p.y), "%s staat op vrije vloer" % g["naam"])
			var voet: Rect2 = spel.KAR_VOET
			voet.position += Vector2(float(kar["x"]), float(kar["z"]))
			waar(not voet.has_point(p), "%s staat niet onder de kar" % g["naam"])
			var kijk := 1 if ((bak.x - bak.y) - (p.x - p.y)) >= 0.0 else -1
			gelijk(int(d.face), kijk, "%s kijkt naar het bakje" % g["naam"])
			gelijk(str(d.slaap_doel), "", "%s klimt straks niet terug in bed" % g["naam"])
			for ander in plekken:
				waar((ander as Vector2).distance_to(p) >= float(spel.ETEN_SNUIT_AF),
					"%s staat niet op een ander" % g["naam"])
			plekken.append(p)
			# de neus in het bakje (eigenaar, 2026-09-24: "wanneer de hond van
			# het voerbakje eet dan eet hij er net naast/achter"): een eter kijkt
			# naar +x (gezicht 1) of gespiegeld naar +z, en zijn neus reikt
			# `ETEN_VOOR` voor zijn anker; en hij sorteert vóór de achterste helft
			# van het bakje, zodat zijn kop niet achter de rand verdwijnt
			var neus := p + (Vector2(spel.ETEN_VOOR, 0.0) if int(d.face) == 1 \
				else Vector2(0.0, spel.ETEN_VOOR))
			if neus.distance_to(bak) <= 4.5:
				snuit += 1
				waar((p.x + p.y) - (bak.x + bak.y) > float(KAMER_SCENE.KOM_ACHTER),
					"%s staat voor de achterkant van het bakje" % g["naam"])
		# twee eters aan een bakje: beide met de neus erin; drie of vier: de
		# eerste drie (vier waar de vloer het toelaat), de rest wacht ernaast
		waar(snuit >= mini(hier.size(), 3),
			"%s: %d van de %d eters hebben hun neus in het bakje" % [kamer, snuit, hier.size()])
		# het smulwolkje hangt aan de eerste gast en loopt met hem mee
		waar(_zichtbaar("vk_smul"), "het smulwolkje hangt er")
	Ui.zet_rust_modus(false)
	_af()

## Zonder rustmodus lopen ze echt: vlak na het goede antwoord zijn ze op weg (uit
## bed, op de vloer), even later eten ze naast het bakje met hun gezicht ernaar,
## en als het bakje leeg is zijn ze wakker en blijven ze uit bed.  Wie niet in
## zijn kamer was (hier: in de gang) komt door de deur naar zijn bakje.
func test_de_gasten_lopen_naar_het_bakje() -> void:
	_op()
	var spel := _start(3, 3, 1, 3)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	var hier: Array = spel._gasten_in("kamer1")
	gelijk(hier.size(), 2, "kamer1 heeft twee gasten")
	if hier.size() < 2:
		_af()
		return
	_in_bed(spel)
	waar(_laad(spel), "de som van de kar")
	waar(World.slaapt(str(hier[0]["id"])), "%s ligt in bed" % hier[0]["naam"])
	# de tweede staat in de gang
	World.zet(str(hier[1]["id"]), "gang", 60.0, 30.0)
	spel.duw_naar("kamer1")
	Hits.plaats()
	var q := _open(spel, "kamer1")
	waar(spel.vraag_bak("kamer1"), "het bakje vraagt zijn som")
	Hits.plaats()
	_beantwoord(spel, "kamer1")
	var bak := _bak_punt("kamer1")
	for g in hier:
		var d = World.dier(str(g["id"]))
		gelijk(str(d.staat), "loop", "%s staat op en loopt" % g["naam"])
		gelijk(float(d.hoogte), 0.0, "%s is van de matras af" % g["naam"])
	var boom := Engine.get_main_loop() as SceneTree
	var t := 0.0
	while t < 9.0:
		var klaar := true
		for g in hier:
			if str(World.dier(str(g["id"])).staat) != "eet":
				klaar = false
		if klaar:
			break
		await boom.create_timer(0.1).timeout
		t += 0.1
	for g in hier:
		var d = World.dier(str(g["id"]))
		gelijk(str(d.staat), "eet", "%s eet (na %.1f s)" % [g["naam"], t])
		gelijk(str(d.kamer), "kamer1", "%s eet in zijn eigen kamer" % g["naam"])
		var p := Vector2(d.x, d.z)
		waar(p.distance_to(bak) < 20.0, "%s eet bij het bakje" % g["naam"])
		var neus := p + (Vector2(spel.ETEN_VOOR, 0.0) if int(d.face) == 1 \
			else Vector2(0.0, spel.ETEN_VOOR))
		waar(neus.distance_to(bak) <= 4.5, "%s eet met zijn neus in het bakje (%.1f)"
			% [g["naam"], neus.distance_to(bak)])
		gelijk(int(d.face), 1 if ((bak.x - bak.y) - (p.x - p.y)) >= 0.0 else -1,
			"%s kijkt naar het bakje" % g["naam"])
		waar(not d.per_stap.is_valid(), "%s: het omdraaien hangt niet meer aan zijn volgende wandeling" % g["naam"])
	# het bakje is op: ze zijn blij en wakker, en niemand klimt terug in bed
	World.zet_bak("kamer1", str(q["slot"]), 0)
	await _wacht(0.4)
	for g in hier:
		var d = World.dier(str(g["id"]))
		waar(str(d.staat) != "eet", "%s is klaar met eten (%s)" % [g["naam"], d.staat])
		waar(not World.slaapt(str(g["id"])), "%s ligt niet weer in bed" % g["naam"])
		gelijk(str(d.slaap_doel), "", "en gaat er ook niet naartoe")
	_af()

# -------------------------------------------------------------- herstellen

## De stand van de kar leeft in `state.kar` (games-a.md §7.2) én in `ctx.data()`,
## en komt na een echte savegame-ronde als gehele getallen terug.
func test_herstel_uit_de_save() -> void:
	_op()
	var spel := _start(3, 3, 1, 3)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	waar(_laad(spel), "de som van de kar")
	var q: Dictionary = spel.open_kamers()[0]
	spel.duw_naar(str(q["kamer"]))
	spel.lever(str(q["kamer"]), str(q["slot"]))
	var op_kar := int(spel.K["op_kar"])
	var geleverd: Array = (spel.K["geleverd"] as Dictionary).keys()
	waar(State.bewaar(), "de savegame is geschreven")
	waar(typeof(State.s["kar"]) == TYPE_DICTIONARY, "state.kar draagt de stand")
	waar(typeof(State.spel_data(SPEL).get("kar", null)) == TYPE_DICTIONARY,
		"en ctx.data() draagt hem ook")
	Games.stop()
	waar(State.lees(), "de savegame is teruggelezen")
	World.sync(State.s["gasten"])
	World.naar("keuken")
	Games.start(SPEL)
	Hits.plaats()
	var terug := _spel()
	waar(terug != null, "het spel draait weer")
	gelijk(int(terug.K["op_kar"]), op_kar, "de lading van de kar staat er weer")
	gelijk(str((terug.K["geleverd"] as Dictionary).keys()), str(geleverd),
		"en de geleverde kamers blijven geleverd")
	gelijk(str(terug.K["stap"]), "duwen", "het rondje gaat door")
	gelijk(typeof(terug.K["T"]), TYPE_INT, "JSON gaf komma-getallen; ze zijn weer geheel")
	waar(Hits.spot("vk_karn") != null, "het getal op de kar staat er weer")
	_af()

## Een oude save (V1-vorm) telt `_herstel` om naar de vorm van V2: `vol: true`
## is het rondje, zonder `vol` was de beurt bij de som, en wat op de kar lag
## of nog in de zak zat wordt de lading van de kar.
func test_herstel_oude_vulstand() -> void:
	var spel = load("res://games/voerkar/spel.gd").new()
	var oud = {
		"T": 17, "per": 5, "rest": 2, "zak": 5,
		"vak": {"g1": 8, "g2": 2}, "pot": 2, "hand": 1,
		"missers": 1, "vol": false, "geleverd": {}, "spook": 0,
		"feedback": false, "zakZeg": "", "t0": 12345,
	}
	var n = spel._herstel(oud)
	gelijk(str(n["stap"]), "som", "zonder vol: de beurt stond bij de som")
	gelijk(int(n["op_kar"]), 15, "kar + zak samen zijn de lading")
	gelijk(int(n["pot"]), 2, "de pot blijft")
	gelijk(int(n["T"]), 17, "en het totaal")
	var vol = oud.duplicate(true)
	vol["vol"] = true
	vol["zak"] = 0
	var g2 = spel._herstel(vol)
	gelijk(str(g2["stap"]), "duwen", "vol: true is het rondje")
	gelijk(int(g2["op_kar"]), 10, "wat op de kar lag is de lading")
	gelijk(str((g2["geleverd"] as Dictionary).keys()), "[]", "er is nog niets geleverd")
	spel.free()
	_af()

## Een beurt die nog bij de som stond vertrekt niet meer vol (wave 2, tot dan
## de eigenaarsbeslissing "doorduwen"): ze vraagt de som van de kar.
func test_oude_som_beurt_wordt_doorgeduwd() -> void:
	_op()
	_gasten(3, 3)
	State.s["dag"] = 1
	State.herbereken()
	State.s["kar"] = {
		"T": 17, "per": 5, "rest": 2, "op_kar": 15, "pot": 2,
		"stap": "som", "geleverd": {}, "missers": 1, "spook": 0,
		"t0": Time.get_ticks_msec(),
	}
	Games.start(SPEL)
	Hits.plaats()
	var spel := _spel()
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	gelijk(str(spel.K["stap"]), "som", "de som-stap blijft de som")
	waar(Hits.spot(LADING) != null, "en de som van de kar hangt er")
	gelijk(int(spel.K["lading_goed"]), 5 * spel.deelnemers().size(), "vijf koekjes per gast")
	_af()

## Halverwege het rondje herladen: de geleverde kamers blijven geleverd.
func test_herstel_midden_in_het_rondje() -> void:
	_op()
	var spel := _start(3, 3, 1, 3)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	waar(_laad(spel), "de som van de kar")
	var q: Dictionary = spel.open_kamers()[0]
	spel.duw_naar(str(q["kamer"]))
	spel.lever(str(q["kamer"]), str(q["slot"]))
	Hits.plaats()
	var geleverd := (spel.K["geleverd"] as Dictionary).keys()
	waar(State.bewaar(), "opgeslagen")
	Games.stop()
	waar(State.lees(), "teruggelezen")
	World.sync(State.s["gasten"])
	World.naar("keuken")
	Games.start(SPEL)
	Hits.plaats()
	var terug := _spel()
	gelijk(str(terug.K["stap"]), "duwen", "het rondje was al bezig en gaat door")
	gelijk(str((terug.K["geleverd"] as Dictionary).keys()), str(geleverd),
		"en de geleverde kamers blijven geleverd")
	waar(Hits.spot("vk_karn") != null, "het rondje loopt door")
	_af()

## Herladen midden in de som van een bakje (2026-09-24): de open vraag staat in
## `state.kar` (`vraag`).  Na het herladen staan de kar en de camera weer bij dat
## bakje, dezelfde kaart met dezelfde vier getallen hangt er, de misser van
## vóór het herladen telt nog mee, en het goede antwoord vult het bakje.
func test_herstel_midden_in_de_som_van_het_bakje() -> void:
	_op()
	var spel := _start(3, 4, 1, 3)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	waar(_laad(spel), "de som van de kar")
	spel.duw_naar("kamer1")
	Hits.plaats()
	var q := _open(spel, "kamer1")
	waar(spel.vraag_bak("kamer1"), "het bakje vraagt zijn som")
	Hits.plaats()
	var voor := _som_tekst()
	var getallen := _getallen()
	_kies(_fout_getal(spel, "kamer1"))
	gelijk(int(spel.K["missers"]), 1, "één misser vóór het herladen")
	waar(State.bewaar(), "opgeslagen")
	gelijk(str(State.s["kar"]["vraag"]), "kamer1", "de open vraag staat in de savegame")
	Games.stop()
	waar(State.lees(), "teruggelezen")
	World.sync(State.s["gasten"])
	World.naar("keuken")
	Games.start(SPEL)
	Hits.plaats()
	var terug := _spel()
	waar(terug != null, "het spel draait weer")
	if terug == null:
		_af()
		return
	gelijk(World.kamer_nu(), "kamer1", "de camera staat weer bij het bakje")
	gelijk(str(World.ding("kar").get("kamer", "")), "kamer1", "en de kar ook")
	gelijk(str(terug.K["vraag"]), "kamer1", "de vraag staat nog open")
	gelijk(int(terug.K["missers"]), 1, "de misser telt nog mee")
	gelijk(_som_tekst(), voor, "dezelfde vraag")
	gelijk(str(_getallen()), str(getallen), "met dezelfde vier getallen")
	gelijk(World.bak_stand("kamer1", str(q["slot"])), 0, "het bakje is nog leeg")
	_beantwoord(terug, "kamer1")
	waar(terug.K["geleverd"].has("kamer1"), "het goede antwoord vult het bakje")
	gelijk(str(terug.K["vraag"]), "", "en de vraag is beantwoord")
	_af()

## Een open vraag in een kamer die intussen gevoerd is (een oude of rare stand)
## vervalt bij het herstarten; de kar rijdt dan zelf naar de kamer die nog
## honger heeft (wave 2), nooit naar de gevoerde.
func test_een_vervallen_vraag_blijft_niet_hangen() -> void:
	_op()
	_gasten(3, 3)
	State.s["dag"] = 1
	State.herbereken()
	State.s["kar"] = {
		"T": 6, "per": 2, "rest": 0, "op_kar": 2, "pot": 0,
		"stap": "duwen", "geleverd": {"kamer1": 4}, "missers": 0,
		"t0": Time.get_ticks_msec(), "vraag": "kamer1",
	}
	Games.start(SPEL)
	Hits.plaats()
	var spel := _spel()
	waar(spel != null, "het spel draait")
	if spel != null:
		waar(str(spel.K["vraag"]) != "kamer1", "de vraag van een gevoerde kamer vervalt")
		waar(World.kamer_nu() != "kamer1", "de camera gaat niet naar de gevoerde kamer")
	_af()

# ----------------------------------------------------------------- stoppen

## `stop()` laat de wereld schoon achter: geen knoppen, geen los decor, en geen
## knop van het hotel is van de voerkar (sinds wave 2 leent hij er geen één).
func test_stop_laat_de_wereld_schoon() -> void:
	_op()
	var spel := _start(3, 3, 1, 3)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	gelijk(World.decor_lijst("keuken").size(), 0, "de keukenvloer is al leeg als het spel begint")
	waar(_laad(spel), "de som van de kar")
	var q: Dictionary = spel.open_kamers()[0]
	spel.duw_naar(str(q["kamer"]))
	Hits.plaats()
	gelijk(str(_geleend()), "[]", "geen knop van het hotel is van de voerkar")
	Games.stop()
	Hits.plaats()
	gelijk(Games.actief(), "", "er draait niets meer")
	for id in Hits.lijst():
		var s := Hits.spot(id)
		waar(s.door != SPEL, "geen knop van de voerkar meer over (%s)" % id)
		waar(s.geleend_door != SPEL, "en niets meer geleend (%s)" % id)
	gelijk(World.decor_lijst("keuken").size(), 0, "en geen los decor meer")
	waar(Rooms.slots("keuken", "bak").is_empty(), "de keuken houdt geen bakjes over")
	_af()

# --------------------------------------------------------- knoppen en dekking

## De harde regel van architecture.md §4.3/§12.2: geen knop van dit spel dekt
## ook maar één voorwerp af, in vier kaders.  Drie beelden (wave 2): de keuken
## met de som van de kar, de kamer met de som van het bakje (de kar rijdt er
## zelf heen), en die kamer na het voeren.
func test_dekking_nul_in_vier_kaders() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_onthoud()
	var rust := Ui.rust_modus()
	for maat in SCHERMEN:
		var vp := SubViewport.new()
		vp.size = maat
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		boom.root.add_child(vp)
		var shell = load("res://scenes/main.tscn").instantiate()
		shell.set_meta("geen_start", true)
		vp.add_child(shell)
		for _f in 4:
			await boom.process_frame
		Ui.zet_rust_modus(true)
		_gasten(6, 6)
		State.s["dag"] = 2
		State.herbereken()
		Hotel.start()
		World.naar("keuken")
		for _f in 3:
			await boom.process_frame
		Games.start(SPEL)
		for _f in 4:
			await boom.process_frame
		var spel := _spel()
		waar(spel != null and spel.deelnemers().size() == 6,
			"%s: zes gasten doen mee" % str(maat))
		spel.K["missers"] = 2
		spel._rondje()
		for _f in 2:
			await boom.process_frame
		waar(Hits.spot(LADING) != null, "%s: de som van de kar" % str(maat))
		waar(_knop("vk_els") == null, "%s: geen Els, ook niet na twee missers" % str(maat))
		var kader: Control = shell.get_node("Scherm/Kolom/Middenrij/Kaderdoos/Kader")
		_keur_dekking(kader, "%s keuken" % str(maat))
		waar(_laad(spel), "%s: het goede getal" % str(maat))
		waar(await _wacht_tot(func() -> bool: return _som_kaart() != null, 6.0),
			"%s: de kar rijdt zelf naar een bakje" % str(maat))
		for _f in 3:
			await boom.process_frame
		var kamer := World.kamer_nu()
		_keur_dekking(kader, "%s %s, som" % [str(maat), kamer])
		_beantwoord(spel, kamer)
		for _f in 3:
			await boom.process_frame
		_keur_dekking(kader, "%s %s, gevoerd" % [str(maat), kamer])
		Games.stop()
		Hits.wis_alles()
		World.decor_wis_alles()
		Ui.naamplaten_leeg()
		vp.queue_free()
		await boom.process_frame
		Ui.registreer_lagen(null, null, null)
	Ui.zet_rust_modus(rust)
	_herstel_wereld()
	State.s = _bewaard
	_bewaard = {}
	Rooms.herstel()

## Elke knop en elk wolkje van de voerkar in dit beeld: een echte plek, binnen
## het kader, groot genoeg voor een vinger, en over geen enkel voorwerp heen.
## Het getal op de kar en een wolkje mogen een tiende van hun eigen ding raken.
func _keur_dekking(kader: Control, wat: String) -> void:
	var dbg := Hits.debug()
	var eigen := 0
	for id in dbg.keys():
		var s := Hits.spot(id)
		if s == null or s.door != SPEL:
			continue
		eigen += 1
		var d: Dictionary = dbg[id]
		var r: Rect2 = d["rect"]
		waar(not bool(d["krap"]), "%s: %s vond een echte plek" % [wat, id])
		waar(r.position.x >= 0.0 and r.position.y >= 0.0
			and r.end.x <= kader.size.x + 0.01 and r.end.y <= kader.size.y + 0.01,
			"%s: %s staat binnen het kader %s" % [wat, id, str(kader.size)])
		if s.kind != "tag" and s.kind != "naam" and s.kind != "kaart":
			waar(r.size.x >= 44.0 and r.size.y >= 44.0,
				"%s: %s is een tikdoel (%s)" % [wat, id, str(r.size)])
		if int(d["laag"]) == Hits.Laag.VAST:
			continue
		var aan := str(d.get("op", "")) == "aan"
		var tag := s.kind == "tag" or s.kind == "wolk"
		waar(aan or Hits.dekking(id) <= (Hits.TAG_IN * 100.0 + 0.01 if tag else 0.0),
			"%s: %s dekt zijn voorwerp niet af (%.2f)" % [wat, id, Hits.dekking(id)])
		if tag:
			continue
		for ander in dbg.keys():
			var v: Rect2 = dbg[ander]["vlak"]
			if v.size.x <= 0.0 or (aan and v.is_equal_approx(d["vlak"])):
				continue
			var snij := r.intersection(v)
			gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
				"%s: %s dekt het voorwerp van %s af" % [wat, id, ander])
	waar(eigen >= 1, "%s: %d dingen van de voerkar in beeld" % [wat, eigen])

# ---------------------------------------------------------------- slepen

## Door de echte invoerlaag (wave 2): de kar is geen sleepbron meer en geen
## deur is van het spel; een tik op het goede getal van de som van de kar laat
## hem zelf naar de eerste kamer met honger rijden, de camera mee.
func test_slepen_de_kar_door_de_deur() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_onthoud()
	var rust := Ui.rust_modus()
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 768)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_embed_subwindows = true
	boom.root.add_child(vp)
	var shell = load("res://scenes/main.tscn").instantiate()
	shell.set_meta("geen_start", true)
	vp.add_child(shell)
	for _f in 4:
		await boom.process_frame
	Ui.zet_rust_modus(true)
	_gasten(2, 2)
	Hotel.start()
	World.naar("keuken")
	for _f in 3:
		await boom.process_frame
	Games.start(SPEL)
	for _f in 4:
		await boom.process_frame
	var spel := _spel()
	if spel == null:
		fout("het spel draait niet")
		Ui.zet_rust_modus(rust)
		await _ruim_op(vp)
		return
	waar(Hits.spot("karhot") == null, "de kar is geen knop en geen sleepbron")
	var knop := _keuze_knop(LADING, int(spel.K["lading_goed"]))
	waar(knop != null, "het goede getal staat op de strook")
	if knop == null:
		Ui.zet_rust_modus(rust)
		await _ruim_op(vp)
		return
	await _tik_op(vp, knop.get_global_rect().get_center())
	gelijk(str(spel.K["stap"]), "duwen", "de vinger op het goede getal laat de kar rijden")
	waar(await _wacht_tot(func() -> bool: return _som_kaart() != null, 6.0), "en hij komt vanzelf bij een bakje")
	gelijk(str(World.ding("kar").get("kamer", "")), World.kamer_nu(),
		"de kar staat waar het kind kijkt")
	Ui.zet_rust_modus(rust)
	await _ruim_op(vp)

## Een tik door de echte invoerlaag op een FOUT getal van de som van de kar:
## een misser, de kar blijft in de keuken — de som is niet over te slaan.
func test_een_trillende_tik_op_de_kar_blijft_een_tik() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_onthoud()
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 768)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_embed_subwindows = true
	boom.root.add_child(vp)
	var shell = load("res://scenes/main.tscn").instantiate()
	shell.set_meta("geen_start", true)
	vp.add_child(shell)
	for _f in 4:
		await boom.process_frame
	_gasten(2, 2)
	Hotel.start()
	World.naar("keuken")
	for _f in 3:
		await boom.process_frame
	Games.start(SPEL)
	for _f in 4:
		await boom.process_frame
	var spel := _spel()
	if spel == null:
		fout("het spel draait niet")
		await _ruim_op(vp)
		return
	var goed := int(spel.K["lading_goed"])
	var knop := _keuze_knop(LADING, _fout_op(LADING, goed))
	waar(knop != null, "een fout getal staat op de strook")
	if knop != null:
		await _tik_op(vp, knop.get_global_rect().get_center())
	gelijk(int(spel.K["missers"]), 1, "de tik was een misser")
	gelijk(str(spel.K["stap"]), "som", "de kar rijdt niet")
	gelijk(str(World.ding("kar").get("kamer", "")), "keuken", "de kar ging nergens heen")
	await _ruim_op(vp)

## De kar rijdt zelf naar het bakje en het bakje vraagt zijn som zonder tik
## (wave 2; tot dan tikte het kind de deuropeningen en het getekende bakje,
## eigenaar 2026-09-25).  Het bakje is daar geen knop: de som hangt er al.
func test_een_tik_op_het_bakje_zelf_vraagt_de_som() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_onthoud()
	var rust := Ui.rust_modus()
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 768)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_embed_subwindows = true
	boom.root.add_child(vp)
	var shell = load("res://scenes/main.tscn").instantiate()
	shell.set_meta("geen_start", true)
	vp.add_child(shell)
	for _f in 4:
		await boom.process_frame
	Ui.zet_rust_modus(true)
	_gasten(2, 2)
	Hotel.start()
	World.naar("keuken")
	for _f in 3:
		await boom.process_frame
	Games.start(SPEL)
	for _f in 4:
		await boom.process_frame
	var spel := _spel()
	if spel == null:
		fout("het spel draait niet")
		Ui.zet_rust_modus(rust)
		await _ruim_op(vp)
		return
	waar(_laad(spel), "de som van de kar")
	waar(await _wacht_tot(func() -> bool: return _som_kaart() != null, 6.0), "het bakje vraagt zijn som")
	var kamer := World.kamer_nu()
	var q := _open(spel, kamer)
	waar(not q.is_empty() and not _zichtbaar(_bak_id(q)), "het bakje zelf is geen knop")
	waar(not spel.K["geleverd"].has(kamer), "en is nog niet gevuld")
	Ui.zet_rust_modus(rust)
	await _ruim_op(vp)

## Een punt op het voorwerp van deze knop (zijn `vlak`) waar geen enkele knop,
## kaart of wolkje op het glas staat — daar raakt een vinger alleen het
## voorwerp.  `Vector2.INF` als het voorwerp helemaal onder knoppen ligt.
func _naast_de_knop(id: String) -> Vector2:
	var vlak: Rect2 = Hits.debug().get(id, {}).get("vlak", Rect2())
	if vlak.size.x <= 0.0 or Ui.knoplaag == null:
		return Vector2.INF
	vlak.position += Ui.knoplaag.get_global_rect().position
	var bezet: Array[Rect2] = []
	for ander in Hits.lijst():
		var s := Hits.spot(ander)
		if s != null and is_instance_valid(s.knoop) and s.knoop.is_visible_in_tree():
			bezet.append((s.knoop as Control).get_global_rect().grow(2.0))
	for iy in range(1, 8):
		for ix in range(1, 8):
			var p := vlak.position + vlak.size * Vector2(float(ix) / 8.0, float(iy) / 8.0)
			var vrij := true
			for r in bezet:
				if r.has_point(p):
					vrij = false
					break
			if vrij:
				return p
	return Vector2.INF

## Eén tik door de echte invoerlaag: indrukken en op dezelfde plek loslaten.
func _tik_op(vp: SubViewport, p: Vector2) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_beweeg(vp, p, p, false)
	await boom.process_frame
	for neer in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = neer
		mb.position = p
		mb.global_position = p
		vp.push_input(mb)
		await boom.process_frame
	for _f in 3:
		await boom.process_frame

## Eén sleep door de echte invoerlaag: indrukken, in stapjes bewegen, loslaten.
func _sleep(vp: SubViewport, van: Vector2, naar: Vector2) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var vorig := van
	_beweeg(vp, van, van, false)
	await boom.process_frame
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = van
	mb.global_position = van
	vp.push_input(mb)
	await boom.process_frame
	for i in range(1, 11):
		var p := van + (naar - van) * (float(i) / 10.0)
		_beweeg(vp, p, vorig, true)
		vorig = p
		await boom.process_frame
	var los := InputEventMouseButton.new()
	los.button_index = MOUSE_BUTTON_LEFT
	los.pressed = false
	los.position = naar
	los.global_position = naar
	vp.push_input(los)
	for _f in 3:
		await boom.process_frame

func _beweeg(vp: SubViewport, p: Vector2, vorig: Vector2, knop: bool) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = p
	mm.global_position = p
	mm.relative = p - vorig
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT if knop else 0
	vp.push_input(mm)

func _ruim_op(vp: SubViewport) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	Games.stop()
	Hits.wis_alles()
	World.decor_wis_alles()
	Ui.naamplaten_leeg()
	vp.queue_free()
	await boom.process_frame
	Ui.registreer_lagen(null, null, null)
	_herstel_wereld()
	State.s = _bewaard
	_bewaard = {}
	Rooms.herstel()

## De kar van gisteren telt niet meer (2026-09-23).  `Hotel.morgen()` zet
## `state.kar` op null en leegt de bakjes, maar de kopie in het laatje bleef
## staan, en dan zei het spel de volgende ochtend "✅ Alle bakjes vol!" terwijl
## elk bakje leeg was.  Een nieuwe kar draagt zijn dag.
func test_de_kar_van_gisteren_telt_niet_meer() -> void:
	_op()
	var spel := _start(3, 3, 1, 3)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	gelijk(int(spel.K.get("dag", -1)), 1, "de kar weet van welke dag hij is")
	# gisteren: alles geleverd, en het spel werd in het slotwolkje gestopt
	var geleverd := {}
	for q in spel.open_kamers():
		geleverd[str(q["kamer"])] = true
	spel.K["geleverd"] = geleverd
	spel.K["stap"] = "duwen"
	Games.stop()
	waar(typeof(State.spel_data(SPEL).get("kar", null)) == TYPE_DICTIONARY,
		"de volle kar staat nog in het laatje")
	# de nieuwe dag: het hotel ruimt `state.kar` op, het laatje niet
	State.s["dag"] = 2
	State.s["kar"] = null
	Games.start(SPEL)
	Hits.plaats()
	var vandaag := _spel()
	waar(vandaag != null, "het spel draait vandaag")
	if vandaag != null:
		gelijk(int(vandaag.K.get("dag", -1)), 2, "een nieuwe kar voor vandaag")
		gelijk((vandaag.K["geleverd"] as Dictionary).size(), 0, "met nog niets geleverd")
		waar(not vandaag.open_kamers().is_empty(), "en er zijn kamers om naar toe te duwen")
	_af()

# ------------------------------------------- rekenen eerst (wave 2, 2026-10-08)

const LADING := "vk_lading"

## De som van de kar: regel | regel2 | som.
func _lading_tekst() -> String:
	var s := Hits.spot(LADING)
	if s == null or not is_instance_valid(s.knoop):
		return ""
	var k := s.knoop as UiSomkaart
	return "%s | %s | %s" % [k.regel_label.text if k.regel_label != null else "",
		k.regel2_label.text if k.regel2_label != null else "",
		k.som_label.text if k.som_label != null else ""]

## De getallen op de strook onder een kaart.
func _getallen_op(kaart: String) -> Array[int]:
	var uit: Array[int] = []
	var s := Hits.spot(kaart + "_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		return uit
	var rij = s.knoop.get_node_or_null("Rij")
	if rij == null:
		return uit
	for k in rij.get_children():
		var naam := str(k.name)
		if naam.begins_with("Kn"):
			uit.append(int(naam.substr(2)))
	return uit

func _keuze_knop(kaart: String, n: int) -> Control:
	var s := Hits.spot(kaart + "_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		return null
	return s.knoop.get_node_or_null("Rij/Kn%d" % n) as Control

## Eén tik op het getal `n` van de strook onder `kaart`.
func _kies_op(kaart: String, n: int) -> bool:
	var k := _keuze_knop(kaart, n) as BaseButton
	if k == null:
		fout("%d staat niet op de strook van %s (%s)" % [n, kaart, str(_getallen_op(kaart))])
		return false
	k.emit_signal("pressed")
	Hits.plaats()
	return true

func _fout_op(kaart: String, goed: int) -> int:
	for n in _getallen_op(kaart):
		if n != goed:
			return n
	return goed + 1

## De som van de kar goed beantwoorden: daarna rijdt de kar zelf.
func _laad(spel: Node) -> bool:
	if str(spel.K.get("stap", "")) != "som":
		return true
	var ok := _kies_op(LADING, int(spel.K["lading_goed"]))
	return ok and str(spel.K["stap"]) == "duwen"

## Echte tijd laten lopen (de kar rijdt in stapjes) tot `test` waar is.
func _wacht_tot(test: Callable, max_s: float) -> bool:
	var boom := Engine.get_main_loop() as SceneTree
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(max_s * 1000.0):
		if bool(test.call()):
			return true
		await boom.process_frame
		Hits.plaats()
	return bool(test.call())

## Wave-2 regel R1 (eigenaar, 2026-10-08: "rekenen moet minstens 50% van de
## interactie zijn"): elke tik van een hele beurt, naar soort, zonder de tik
## die het spel opende.  De som van de kar (één fout, één goed) en de som van
## elk bakje zijn rekenen; de kar rijdt zelf en het bakje vraagt zelf, dus er
## is geen speltik.
var _teller := {"reken": 0, "spel": 0}

func _tel(soort: String) -> void:
	_teller[soort] = int(_teller.get(soort, 0)) + 1

func _rekenaandeel(band: int, n: int, dag: int) -> void:
	_op()
	_teller = {"reken": 0, "spel": 0}
	Ui.zet_rust_modus(true)
	_gasten(n, mini(n, 6))
	State.s["dag"] = dag
	State.s["kunnen"] = band - 1
	State.herbereken()
	var va_b := _va_begin()
	Games.start(SPEL)
	Hits.plaats()
	var spel := _spel()
	waar(spel != null, "band %d, %d gasten: het spel draait" % [band, n])
	if spel == null:
		Ui.zet_rust_modus(false)
		_af()
		return
	gelijk(State.band(), band, "%d gasten: band %d" % [n, band])
	var goed := int(spel.K["lading_goed"])
	_tel("reken")
	waar(_kies_op(LADING, _fout_op(LADING, goed)), "een fout getal op de kar")
	await _wacht(float(Ui.MIS_PAUZE) + 0.2)
	_tel("reken")
	waar(_laad(spel), "het goede getal op de kar")
	var ronden := 0
	while not spel.open_kamers().is_empty() and ronden < 8:
		ronden += 1
		waar(await _wacht_tot(func() -> bool: return _som_kaart() != null, 8.0),
			"band %d: de kar kwam vanzelf bij een bakje" % band)
		if _som_kaart() == null:
			break
		_tel("reken")
		_beantwoord(spel, World.kamer_nu())
	waar(spel.open_kamers().is_empty(), "band %d, %d gasten: alles gevoerd" % [band, n])
	var r := int(_teller["reken"])
	var s := int(_teller["spel"])
	waar(r >= s + 1, "band %d, %d gasten: rekenen %d >= spel %d + 1" % [band, n, r, s])
	_va_eind("voerkar band %d, %d gasten" % [band, n], _teller, va_b)
	Ui.zet_rust_modus(false)
	_af()

func test_rekenaandeel_band_3() -> void:
	await _rekenaandeel(3, 1, 1)
	await _rekenaandeel(3, 6, 2)

func test_rekenaandeel_band_4() -> void:
	await _rekenaandeel(4, 4, 1)
	await _rekenaandeel(4, 8, 3)

func test_rekenaandeel_band_5() -> void:
	await _rekenaandeel(5, 7, 1)
	await _rekenaandeel(5, 8, 2)

## R2 (wave 2): een gemiste som van de kar komt ook op een nieuwe dag
## onveranderd terug (tot dan: "de kar van gisteren telt niet meer", dus een
## nieuwe, misschien makkelijker som).
func test_een_gemiste_vraag_blijft_ook_morgen() -> void:
	_op()
	var spel := _start(3, 3, 1, 3)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	var goed := int(spel.K["lading_goed"])
	var voor := _lading_tekst()
	var getallen := _getallen_op(LADING)
	waar(_kies_op(LADING, _fout_op(LADING, goed)), "een fout getal")
	Games.stop()
	State.s["dag"] = 2
	State.s["kar"] = null
	Games.start(SPEL)
	Hits.plaats()
	var morgen := _spel()
	waar(morgen != null, "het spel draait de volgende dag")
	if morgen != null:
		gelijk(str(morgen.K["stap"]), "som", "dezelfde vraag staat open")
		gelijk(int(morgen.K["lading_goed"]), goed, "met hetzelfde antwoord")
		gelijk(_lading_tekst(), voor, "dezelfde kaart")
		gelijk(str(_getallen_op(LADING)), str(getallen), "met dezelfde vier getallen")
	_af()

# ------------------------------------------- VA: de echte Rekenwacht (R1)

## VA (2026-10-09): next to the in-test counter, the REAL classifier.  Every
## turn starts from a fresh Rekenwacht with half a budget (so a right answer
## has room to pay back); after the turn `Reken.beurt()` must hold R1 by
## itself, agree with the counter tap for tap, and show that a right answer
## paid back (`Reken.goed` fired and the budget rose over the turn).
const VA_BUDGET := 6

func _va_begin() -> int:
	Reken.voor_test()
	for _i in Reken.BUDGET_MAX - VA_BUDGET:
		Reken.tik("spel", "test:va")
	return Reken.budget()

func _va_eind(wat: String, teller: Dictionary, budget_voor: int) -> void:
	var b := Reken.beurt()
	var r := int(b["reken"])
	var s := int(b["spel"])
	print("[VA] %s: reken=%d spel=%d goed=%d budget=%d->%d" % [wat, r, s, int(b["goed"]),
		budget_voor, Reken.budget()])
	waar(r >= s + 1, "%s: Reken.beurt() reken %d >= spel %d + 1" % [wat, r, s])
	gelijk(r, int(teller["reken"]), "%s: Reken.beurt().reken = de teller" % wat)
	gelijk(s, int(teller["spel"]), "%s: Reken.beurt().spel = de teller" % wat)
	waar(int(b["goed"]) >= 1, "%s: Reken.goed() vuurde" % wat)
	waar(Reken.budget() > budget_voor, "%s: het budget steeg (%d -> %d)" % [wat, budget_voor,
		Reken.budget()])
