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
			spel.T_KAR_TITEL % [6, spel.T_KAMERS]]:
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

## Eén hele beurt, gespeeld zoals een kind hem speelt: alleen tikken op wat er
## staat.  De som komt uit `Sommen.deel`, de kar vertrekt vol (beslissing
## "doorduwen"): tik op de kar, volg de deuren met een 👉, tik op het bakje waar
## de kar staat, en bij de laatste levering gaat de rest in de snoeppot en
## sluit de lus.  Bij elke stap hangt er hoogstens één wolkje in beeld.
func _hele_beurt(band: int, n: int, dag: int) -> void:
	_op()
	var spel := _start(n, band, dag, mini(n, 6))
	waar(spel != null, "band %d: het spel draait" % band)
	if spel == null:
		_af()
		return
	gelijk(State.band(), band, "band %d is echt de band" % band)
	var g: Array = spel.deelnemers()
	var som := Sommen.deel(g.size(), band, dag)
	gelijk(int(spel.K["T"]), int(som["T"]), "band %d: T uit Sommen.deel" % band)
	gelijk(int(spel.K["per"]), int(som["k"]), "band %d: per gast" % band)
	gelijk(int(spel.K["rest"]), int(som["r"]), "band %d: in de pot" % band)
	gelijk(str(spel.K["stap"]), "duwen", "band %d: de beurt wordt doorgeduwd tot het rondje" % band)
	gelijk(int(spel.K["op_kar"]), int(som["T"]), "band %d: de kar vertrekt vol" % band)
	# de keukenvloer is leeg: geen bakjes, geen zak, geen pak-knoppen
	gelijk(World.decor_lijst("keuken").size(), 0, "band %d: geen los decor in de keuken" % band)
	for id in ["vk_zak", "vk_klaar", "vk_opnieuw", "vk___pot"]:
		waar(Hits.spot(id) == null, "band %d: %s is weg met de vul-fase" % [band, id])
	var open: Array = spel.open_kamers()
	waar(open.size() >= 1, "band %d: er is minstens één kamer met een bakje" % band)
	# de keuken: de kar zegt wat een tik doet, het ene wolkje zegt de opdracht
	gelijk(_tekst("karhot"), "🛒 Pak de kar", "band %d: de kar is een knop die zegt wat hij doet" % band)
	gelijk(_titel("karhot"), "de voerkar: nog %d %s" % [open.size(), "kamer" if open.size() == 1 else "kamers"],
		"band %d: de uitleg telt de kamers" % band)
	gelijk(_tekst("vk_zeg"), "🍪 Breng %d koekjes naar elke gast" % int(som["k"]),
		"band %d: de opdracht met het getal erin" % band)
	gelijk(str(_wolkjes()), '["vk_zeg"]', "band %d: één wolkje bij de kar" % band)
	var sterren_voor := int(State.s["sterren"])
	var pot_voor := int(State.s["snoeppot"])
	_tik("karhot")
	waar(spel.mee(), "band %d: de kar is vast" % band)
	gelijk(_tekst("karhot"), "🛒 Je duwt de kar", "band %d: en de knop zegt het" % band)
	var ronden := 0
	while not spel.open_kamers().is_empty() and ronden < 16:
		ronden += 1
		var nu := World.kamer_nu()
		gelijk(str(World.ding("kar").get("kamer", "")), nu, "band %d: de kar staat waar het kind kijkt" % band)
		var q := _open(spel, nu)
		if q.is_empty():
			# onderweg: tik op een deur met een 👉.  Net gevoerd?  Dan hangt het
			# smulwolkje er nog en wacht dat van de kar; het kind tikt meteen door.
			if _zichtbaar("vk_smul"):
				waar(not _zichtbaar("vk_zeg"), "band %d: tijdens het smullen geen tweede wolkje" % band)
			else:
				gelijk(_tekst("vk_zeg"), "👉 Tik op een deur", "band %d: %s zegt de volgende stap" % [band, nu])
			var wijs: Array = spel.wijs_deuren()
			waar(not wijs.is_empty(), "band %d: in %s wijst een deur de weg" % [band, nu])
			if wijs.is_empty():
				break
			var deur := "deur_%s_%s" % [nu, str(wijs[0])]
			waar(_wijst(deur), "band %d: het bordje van %s draagt een 👉 (%s)" % [band, deur, _tekst(deur)])
			if not _tik(deur):
				break
			gelijk(World.kamer_nu(), str(wijs[0]), "band %d: de camera ging mee door de deur" % band)
			waar(spel.mee(), "band %d: en de kar is nog steeds vast" % band)
		else:
			# de kar staat bij hongerige gasten: tik op het bakje
			var kamer := nu
			gelijk(_tekst("vk_zeg"), "👉 Tik op het bakje", "band %d: %s zegt: het bakje" % [band, kamer])
			var bak := _bak_id(q)
			waar(_zichtbaar(bak), "band %d: het bakje van %s is nu een knop" % [band, kamer])
			for dr in spel.wijs_deuren():
				fout("band %d: in een hongerige kamer wijst geen deur (%s)" % [band, str(dr)])
			var kar_voor := int(spel.K["op_kar"])
			var hier := 0
			for gg in g:
				if str(gg.get("kamer", "")) == kamer:
					hier += 1
			if not _tik(bak):
				break
			waar(spel.K["geleverd"].has(kamer), "band %d: afleveren in %s lukt" % [band, kamer])
			gelijk(World.bak_stand(kamer, str(q["slot"])), 4, "band %d: het bakje is vol" % band)
			gelijk(int(spel.K["op_kar"]), kar_voor - int(som["k"]) * hier,
				"band %d: de kar draagt %d * %d minder" % [band, int(som["k"]), hier])
			for gg in g:
				if str(gg.get("kamer", "")) == kamer:
					waar(bool(gg.get("gegeten", false)), "band %d: %s heeft gegeten" % [band, gg["naam"]])
					gelijk(str(gg.get("behoefte", "")), "spelen", "band %d: en wil nu spelen" % band)
			gelijk(_tekst("vk_smul"), "😋 %d %s" % [int(som["k"]), "koekjes elk" if hier > 1 else "koekjes"],
				"band %d: het smulwolkje telt per dier" % band)
			waar(not _zichtbaar(bak), "band %d: het volle bakje is geen knop meer" % band)
			if not spel.open_kamers().is_empty():
				gelijk(str(_wolkjes()), '["vk_smul"]',
					"band %d: tijdens het smullen wacht het wolkje van de kar" % band)
		if not spel.open_kamers().is_empty():
			waar(_wolkjes().size() <= 1, "band %d: hoogstens één wolkje in %s (%s)" % [band,
				World.kamer_nu(), str(_wolkjes())])
	waar(spel.open_kamers().is_empty(), "band %d: elke kamer is bediend (%d stappen)" % [band, ronden])
	# de lus is rond: de rest van de kar gaat in de snoeppot, één ster voor het
	# meedoen
	gelijk(int(spel.K["op_kar"]), int(som["r"]), "band %d: de kar draagt de rest" % band)
	gelijk(int(State.s["sterren"]), sterren_voor + 1, "band %d: één ster voor het meedoen" % band)
	gelijk(int(State.s["snoeppot"]), pot_voor + int(som["r"]), "band %d: de rest ging in de snoeppot" % band)
	waar(Hotel.taak_af("voer") or true, "het taakje mag afgevinkt zijn")
	gelijk(_tekst("vk_zeg"), "✅ Alle bakjes vol!", "band %d: alles rond" % band)
	# niets meer om aan te tikken: geen kar-knop, geen geleende deur of bakje
	gelijk(str(_eigen_knoppen()), "[]", "band %d: aan het eind is er geen knop van de kar meer" % band)
	gelijk(str(_geleend()), "[]", "band %d: en geen geleende deur of bakje" % band)
	await _wacht_dicht()
	gelijk(Games.actief(), "", "band %d: het spel sluit zichzelf" % band)
	gelijk(State.s["kar"], null, "band %d: de kar is opgeruimd" % band)
	_af()

# ---------------------------------------------------------------- tikken

## Tik op de kar: je hebt hem vast (eigenaar, 2026-09-23).  De knop wordt
## `🛒 Je duwt de kar`, ingedrukt en met de ☝ van "in je hand"; de deur op weg
## naar de gasten krijgt een 👉 en de andere deuren niet; het ene wolkje zegt
## wat er nu moet.
func test_een_tik_op_de_kar_pakt_hem() -> void:
	_op()
	var spel := _start(2, 3, 1, 2)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	waar(not spel.mee(), "de kar staat eerst gewoon in de keuken")
	var b := Ui.bron_van("karhot")
	waar(b != null and b.toggle_mode and not b.button_pressed, "de kar is een schakelaar die uit staat")
	gelijk(_tekst("karhot"), "🛒 Pak de kar", "en zegt wat een tik doet")
	for deur in ["deur_keuken_gang", "deur_keuken_tuin", "deur_keuken_wasserij"]:
		waar(_zichtbaar(deur), "%s is een knop" % deur)
		waar(not _wijst(deur), "%s wijst nog niet" % deur)
	_tik("karhot")
	waar(spel.mee(), "na een tik heb je de kar vast")
	gelijk(_tekst("karhot"), "🛒 Je duwt de kar", "de knop zegt het")
	b = Ui.bron_van("karhot")
	waar(b != null and b.button_pressed, "en staat ingedrukt")
	if b != null:
		gelijk(b.hand, 1, "met de ☝ van 'in je hand'")
		gelijk(b.aantal, int(spel.K["op_kar"]), "het pilletje telt de koekjes op de kar")
	gelijk(spel.wijs_deuren(), ["gang"], "beide kamers liggen achter de gang")
	gelijk(_tekst("deur_keuken_gang"), "👉 🚪 Gang", "die deur wijst de weg")
	waar(not _wijst("deur_keuken_tuin"), "de tuin is geen weg naar de gasten")
	waar(not _wijst("deur_keuken_wasserij"), "de wasserij ook niet")
	gelijk(_tekst("vk_zeg"), "👉 Tik op een deur", "het wolkje zegt de volgende stap")
	gelijk(str(_wolkjes()), '["vk_zeg"]', "één wolkje")
	_af()

## Tik op een deur: kar én camera gaan erdoor en de kar blijft vast, ook in de
## volgende kamer.  In een kamer met hongerige gasten is het bakje de knop;
## een tik erop vult het, de dieren smullen (dan hangt alleen hún wolkje), en
## daarna zegt de kar weer de volgende stap.
func test_een_tik_op_een_deur_neemt_kar_en_camera_mee() -> void:
	_op()
	# drie gasten: twee in kamer1, één in kamer2
	var spel := _start(3, 3, 1, 3)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	_tik("karhot")
	_tik("deur_keuken_gang")
	gelijk(World.kamer_nu(), "gang", "de camera ging mee")
	gelijk(str(World.ding("kar").get("kamer", "")), "gang", "en de kar ook")
	waar(spel.mee(), "de kar is nog vast")
	gelijk(_tekst("karhot"), "🛒 Je duwt de kar", "en de knop zegt het nog")
	waar(_zichtbaar("karhot"), "de kar is ook in de gang een knop")
	for kamer in ["kamer1", "kamer2"]:
		waar(_wijst("deur_gang_%s" % kamer), "de deur naar %s wijst (%s)" % [kamer,
			_tekst("deur_gang_%s" % kamer)])
	waar(not _wijst("deur_gang_keuken"), "terug naar de keuken wijst niet")
	waar(not _wijst("deur_gang_receptie"), "de receptie ook niet")
	gelijk(_tekst("vk_zeg"), "👉 Tik op een deur", "het wolkje zegt het weer")
	_tik("deur_gang_kamer1")
	gelijk(World.kamer_nu(), "kamer1", "door naar kamer1")
	gelijk(str(World.ding("kar").get("kamer", "")), "kamer1", "met de kar")
	waar(spel.mee(), "nog steeds vast")
	var q := _open(spel, "kamer1")
	waar(not q.is_empty(), "in kamer1 wacht iemand op koekjes")
	if q.is_empty():
		_af()
		return
	waar(_zichtbaar(_bak_id(q)), "het bakje is nu een knop")
	gelijk(_tekst("vk_zeg"), "👉 Tik op het bakje", "en het wolkje zegt het")
	waar(not _wijst("deur_kamer1_gang"), "hier wijst geen deur: eerst het bakje")
	gelijk(str(_wolkjes()), '["vk_zeg"]', "één wolkje")
	_tik(_bak_id(q))
	waar(spel.K["geleverd"].has("kamer1"), "het bakje is gevuld")
	gelijk(World.bak_stand("kamer1", str(q["slot"])), 4, "tot de rand")
	gelijk(str(_wolkjes()), '["vk_smul"]', "tijdens het smullen hangt alleen het smulwolkje")
	waar(not _zichtbaar(_bak_id(q)), "het volle bakje is geen knop meer")
	waar(spel.mee(), "de kar is nog vast")
	waar(_wijst("deur_kamer1_gang"), "en de deur naar de gang wijst naar kamer2")
	await _wacht(float(spel.SMUL_MS) + 0.3)
	gelijk(str(_wolkjes()), '["vk_zeg"]', "na het smullen hangt het wolkje van de kar er weer")
	gelijk(_tekst("vk_zeg"), "👉 Tik op een deur", "met de volgende stap")
	_af()

## Tik op de kar die je vast hebt: je zet hem neer.  De knop zegt weer
## `🛒 Pak de kar`, de 👉's gaan van de deuren af en het wolkje zegt weer de
## opdracht.  Neergezet naast een hongerig bakje blijft dat bakje een knop: de
## kar staat er toch.
func test_een_tik_op_de_vaste_kar_zet_hem_neer() -> void:
	_op()
	var spel := _start(2, 3, 1, 2)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	_tik("karhot")
	waar(spel.mee(), "vast")
	_tik("karhot")
	waar(not spel.mee(), "weer neergezet")
	gelijk(_tekst("karhot"), "🛒 Pak de kar", "de knop zegt weer wat een tik doet")
	var b := Ui.bron_van("karhot")
	waar(b != null and not b.button_pressed, "en staat niet meer ingedrukt")
	if b != null:
		gelijk(b.hand, 0, "zonder ☝")
	for deur in ["deur_keuken_gang", "deur_keuken_tuin", "deur_keuken_wasserij"]:
		waar(not _wijst(deur), "%s wijst niet meer" % deur)
	gelijk(_tekst("vk_zeg"), "👉 Tik op de kar",
		"de opdracht is gelezen: het wolkje zegt kort wat nu")
	# naar kamer1 en daar neerzetten
	_tik("karhot")
	_tik("deur_keuken_gang")
	_tik("deur_gang_kamer1")
	_tik("karhot")
	waar(not spel.mee(), "in kamer1 neergezet")
	var q := _open(spel, "kamer1")
	waar(not q.is_empty() and _zichtbaar(_bak_id(q)), "het bakje naast de kar blijft een knop")
	gelijk(_tekst("vk_zeg"), "👉 Tik op het bakje", "en het wolkje zegt het")
	if not q.is_empty():
		_tik(_bak_id(q))
		waar(spel.K["geleverd"].has("kamer1"), "vullen gaat ook met de kar neergezet")
	_af()

## Een deur waar het kind op tikt zonder de kar vast te hebben neemt de kar
## gewoon mee: geen dode tik en geen "nee" om te lezen.  Daarna is de kar vast.
func test_een_deur_zonder_vaste_kar_neemt_hem_mee() -> void:
	_op()
	var spel := _start(2, 3, 1, 2)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	waar(not spel.mee(), "de kar is niet vast")
	_tik("deur_keuken_gang")
	gelijk(World.kamer_nu(), "gang", "de camera gaat door de deur")
	gelijk(str(World.ding("kar").get("kamer", "")), "gang", "en de kar gaat mee")
	waar(spel.mee(), "en is nu vast")
	gelijk(_tekst("karhot"), "🛒 Je duwt de kar", "de knop zegt het")
	waar(_wijst("deur_gang_kamer1"), "en de deuren wijzen de weg")
	_af()

## Na `stop()` zijn de deurbordjes weer van het hotel: geen 👉 meer, en een tik
## doet weer wat het hotel wil (geen kar meer duwen).
func test_na_stop_wijst_geen_deur_meer() -> void:
	_op()
	var spel := _start(2, 3, 1, 2)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	_tik("karhot")
	waar(_wijst("deur_keuken_gang"), "de gangdeur wijst")
	Games.stop()
	Hits.plaats()
	gelijk(_tekst("deur_keuken_gang"), "🚪 Gang", "het bordje is weer gewoon")
	var s := Hits.spot("deur_keuken_gang")
	waar(s != null and s.geleend_door == "", "en de deur is weer van het hotel")
	_af()

# --------------------------------------------------------- de kar komt thuis

## De ingang van dit spel hangt op de kar zelf (`Games._plek_van`), dus een kar
## die na het rondje in kamer2 blijft staan maakt de voerkar onbereikbaar tot de
## pagina herlaadt.  Na de ronde staat hij weer op zijn eigen plek in de keuken,
## zónder dat de camera meegaat — en zou hij toch elders stilstaan, dan valt de
## knop terug op zijn thuisplek.
func test_kar_staat_na_de_ronde_weer_in_de_keuken() -> void:
	_op()
	var spel := _start(3, 3, 1, 3)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	var thuis := World.ding_thuis("kar")
	gelijk(str(thuis.get("kamer", "")), "keuken", "de kar hoort in de keuken")
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
	# het slotwolkje is informatie, geen knop: het spel sluit zelf na 2,6 s
	gelijk(_tekst("vk_zeg"), "✅ Alle bakjes vol!", "alles rond")
	await _wacht_dicht()
	gelijk(Games.actief(), "", "het spel sluit zichzelf")
	gelijk(World.kamer_nu(), laatste, "de camera blijft waar het kind keek")
	var kar := World.ding("kar")
	gelijk(str(kar.get("kamer", "")), "keuken", "maar de kar staat weer in de keuken")
	gelijk(float(kar.get("x", 0.0)), float(thuis.get("x", 0.0)), "op zijn eigen plek")
	gelijk(float(kar.get("z", 0.0)), float(thuis.get("z", 0.0)), "in beide richtingen")
	gelijk(str(kar.get("model", "")), str(thuis.get("model", "")), "met zijn eigen model")
	# en daarmee hangt de ingang er morgen weer
	World.naar("keuken")
	Games.hersteek()
	Hits.plaats()
	var knop := _knop("spel_voerkar")
	waar(knop != null and knop.visible, "de 🛒-knop hangt weer zichtbaar in de keuken")
	# blijft de kar toch ergens anders staan, dan valt de knop terug op zijn thuisplek
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
## geeft geen ster.  En geen hulp na een fout (eigenaar 2026-09-24: "Nee geef
## geen hulp na fouten"): buurvrouw Els bestaat niet meer — ook niet met twee,
## drie of vier missers uit een oude opslag — en het wolkje van de kar zegt
## nooit haar doelgetal; de kaart houdt haar gewone tweede zin.
func test_geen_els_en_de_ronde_straft_niet() -> void:
	_op()
	var spel := _start(3, 3, 1, 3)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	var sterren_voor := int(State.s["sterren"])
	# afleveren waar de kar niet staat: niets gebeurt, er wordt niet gestraft
	var q: Dictionary = spel.open_kamers()[0]
	waar(not spel.lever(str(q["kamer"]), str(q["slot"])),
		"zonder de kar in de kamer gaat er niets af")
	gelijk(int(spel.K["missers"]), 0, "en er is geen misser geteld")
	gelijk(int(State.s["sterren"]), sterren_voor, "er is geen ster bij of af")
	waar(not spel.K["geleverd"].has(str(q["kamer"])), "en er is niets geleverd")
	# daar is het bakje ook geen knop: het wolkje van de kar zegt gewoon verder
	# wat er nu moet
	waar(not _zichtbaar(_bak_id(q)), "een bakje zonder kar erbij is geen knop")
	gelijk(_tekst("vk_zeg"), "🍪 Breng %d koekjes naar elke gast" % int(spel.K["per"]),
		"het wolkje blijft de opdracht zeggen")
	# missers uit een oude opslag brengen niemand die het voordoet
	for missers in [2, 3, 4]:
		spel.K["missers"] = missers
		spel._rondje()
		Hits.plaats()
		waar(_knop("vk_els") == null, "%d missers: geen Els" % missers)
		waar(not _tekst("vk_zeg").contains("🩺"), "%d missers: het wolkje zegt niets van Els" % missers)
		gelijk(str(_wolkjes()), '["vk_zeg"]', "%d missers: één wolkje, zoals altijd" % missers)
	waar(not spel.K.has("spook"), "de kar kent geen spookgetal meer")
	var g: Array = spel.deelnemers()
	gelijk(spel._zinnen(g.size())[1], spel.T_IEDER, "de kaart houdt haar gewone tweede zin")
	_tik("karhot")
	gelijk(_tekst("vk_zeg"), "👉 Tik op een deur", "de volgende tik zegt de volgende stap")
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
	spel._kaart_neer(g)
	Hits.plaats()
	waar(spel._kaart != null, "de opdrachtkaart hangt er")
	if spel._kaart != null:
		gelijk(str(spel._kaart.dier), str(g[0]["id"]),
			"de kaart noemt het dier van de beurt (o[\"dier\"])")
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
	waar(_knop("karhot") != null, "de kar is weer een knop")
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

## Een beurt die nog bij de som stond wordt door `start()` doorgeduwd
## (eigenaarsbeslissing "doorduwen"): de kar vertrekt vol.
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
	gelijk(str(spel.K["stap"]), "duwen", "de som-stap wordt doorgeduwd")
	gelijk(int(spel.K["op_kar"]), 17, "en de kar vertrekt vol")
	_af()

## Halverwege het rondje herladen: de geleverde kamers blijven geleverd.
func test_herstel_midden_in_het_rondje() -> void:
	_op()
	var spel := _start(3, 3, 1, 3)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
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
	waar(_knop("karhot") != null, "het rondje loopt door")
	_af()

# ----------------------------------------------------------------- stoppen

## `stop()` laat de wereld schoon achter: geen knoppen, geen los decor, en de
## geleende knoppen van het hotel doen weer hun eigen werk.
func test_stop_laat_de_wereld_schoon() -> void:
	_op()
	var spel := _start(3, 3, 1, 3)
	waar(spel != null, "het spel draait")
	if spel == null:
		_af()
		return
	gelijk(World.decor_lijst("keuken").size(), 0, "de keukenvloer is al leeg als het spel begint")
	var q: Dictionary = spel.open_kamers()[0]
	spel.duw_naar(str(q["kamer"]))
	Hits.plaats()
	var bak_id := "bak_%s_%s" % [str(q["kamer"]), str(q["slot"])]
	var geleend := Hits.spot(bak_id)
	waar(geleend != null and geleend.geleend_door == SPEL, "het bakje is even van de voerkar")
	Games.stop()
	Hits.plaats()
	gelijk(Games.actief(), "", "er draait niets meer")
	for id in Hits.lijst():
		var s := Hits.spot(id)
		waar(s.door != SPEL, "geen knop van de voerkar meer over (%s)" % id)
	gelijk(World.decor_lijst("keuken").size(), 0, "en geen los decor meer")
	var terug := Hits.spot(bak_id)
	waar(terug == null or terug.geleend_door == "", "het bakje is weer van het hotel")
	waar(Rooms.slots("keuken", "bak").is_empty(), "de keuken houdt geen bakjes over")
	_af()

# --------------------------------------------------------- knoppen en dekking

## De harde regel van architecture.md §4.3/§12.2: geen knop van dit spel dekt
## ook maar één voorwerp af, in vier kaders.  Drie beelden van de ronde: de
## keuken bij de start (de kar en het opdrachtwolkje), de keuken met de kar
## vast (de gangdeur draagt dan een 👉 en is breder), en kamer1 met de kar naast
## het hongerige bakje — het beeld waar de eigenaar drie witte vakjes zag.
## (Tot 2026-09-24 stond buurvrouw Els er nog bij; zij bestaat niet meer.)
func test_dekking_nul_in_vier_kaders() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_onthoud()
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
		# missers uit een oude opslag: ook dan geen Els (eigenaar 2026-09-24)
		spel.K["missers"] = 2
		spel._rondje()
		for _f in 2:
			await boom.process_frame
		waar(_knop("karhot") != null, "%s: de kar is een knop" % str(maat))
		waar(_knop("vk_els") == null, "%s: geen Els, ook niet na twee missers" % str(maat))
		var kader: Control = shell.get_node("Scherm/Kolom/Middenrij/Kaderdoos/Kader")
		_keur_dekking(kader, "%s keuken" % str(maat))
		# de kar vast: de gangdeur draagt een 👉
		_tik("karhot")
		for _f in 2:
			await boom.process_frame
		waar(_wijst("deur_keuken_gang"), "%s: de gangdeur wijst" % str(maat))
		_keur_dekking(kader, "%s keuken, kar vast" % str(maat))
		# en door naar kamer1, naast het bakje
		_tik("deur_keuken_gang")
		for _f in 2:
			await boom.process_frame
		_tik("deur_gang_kamer1")
		for _f in 3:
			await boom.process_frame
		gelijk(World.kamer_nu(), "kamer1", "%s: de kar staat in kamer1" % str(maat))
		var q := _open(spel, "kamer1")
		waar(not q.is_empty() and _zichtbaar(_bak_id(q)), "%s: het bakje is een knop" % str(maat))
		gelijk(_tekst("vk_zeg"), "👉 Tik op het bakje", "%s: het ene wolkje" % str(maat))
		_keur_dekking(kader, "%s kamer1" % str(maat))
		# gevoerd en neergezet (de tik ruimt het smulwolkje op), en weer vast
		_tik(_bak_id(q))
		_tik("karhot")
		for _f in 2:
			await boom.process_frame
		gelijk(_tekst("vk_zeg"), "👉 Tik op de kar", "%s: neergezet na het voeren" % str(maat))
		_keur_dekking(kader, "%s kamer1, gevoerd, neergezet" % str(maat))
		_tik("karhot")
		for _f in 2:
			await boom.process_frame
		gelijk(_tekst("vk_zeg"), "👉 Tik op een deur", "%s: weer vast" % str(maat))
		_keur_dekking(kader, "%s kamer1, gevoerd, vast" % str(maat))
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

## Elke knop en elk wolkje van de voerkar in dit beeld: een echte plek, binnen
## het kader, groot genoeg voor een vinger, en over geen enkel voorwerp heen.
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
		if s.kind != "tag" and s.kind != "naam":
			waar(r.size.x >= 44.0 and r.size.y >= 44.0,
				"%s: %s is een tikdoel (%s)" % [wat, id, str(r.size)])
		# een vaste kaart (en haar strook) mag over de wereld staan; een
		# knop nooit — die twee zijn de enige uitzondering (§4.3)
		if int(d["laag"]) == Hits.Laag.VAST:
			continue
		var aan := str(d.get("op", "")) == "aan"     # a hotel button ON its own thing
		waar(aan or Hits.dekking(id) <= 0.0, "%s: %s dekt zijn voorwerp niet af" % [wat, id])
		for ander in dbg.keys():
			var v: Rect2 = dbg[ander]["vlak"]
			if v.size.x <= 0.0 or (aan and v.is_equal_approx(d["vlak"])):
				continue
			var snij := r.intersection(v)
			gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
				"%s: %s dekt het voorwerp van %s af" % [wat, id, ander])
	# the cart and its one bubble (buurvrouw Els made it three until 2026-09-24)
	waar(eigen >= 2, "%s: %d knoppen van de voerkar in beeld" % [wat, eigen])

# ---------------------------------------------------------------- slepen

## De kar door een deur slepen — de sleep van games-a.md §7.6, door de echte
## invoerlaag.  De deuren en de bakjes van het hotel zijn tijdens het rondje
## van de voerkar; dit bewijst dat de sleep daar ook echt aankomt.
func test_slepen_de_kar_door_de_deur() -> void:
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
	gelijk(str(spel.K["stap"]), "duwen", "de kar is vol en rijdt")
	var kar := Hits.spot("karhot")
	waar(kar != null, "de kar is een knop")
	if kar == null:
		await _ruim_op(vp)
		return
	var open: Array = spel.open_kamers()
	waar(not open.is_empty(), "er is een kamer open")
	var doel := str(open[0]["kamer"])
	var pad: Array = World.pad("keuken", doel)
	var deur_id := "deur_keuken_%s" % str(pad[1])
	var deur: Dictionary = Hits.debug().get(deur_id, {})
	waar(not deur.is_empty(), "de deur naar %s staat er" % str(pad[1]))
	if deur.is_empty():
		await _ruim_op(vp)
		return
	var van: Vector2 = (kar.knoop as Control).get_global_rect().get_center()
	var vlak: Rect2 = deur["vlak"]
	var naar: Vector2 = Ui.knoplaag.get_global_rect().position + vlak.get_center()
	await _sleep(vp, van, naar)
	gelijk(str(World.ding("kar").get("kamer", "")), str(pad[1]),
		"de kar is naar %s geduwd" % str(pad[1]))
	gelijk(World.kamer_nu(), str(pad[1]), "en de camera ging mee")
	# wie de kar door een deur sleept, duwt hem: hij is daarna vast
	waar(spel.mee(), "na de sleep is de kar vast")
	gelijk(_tekst("karhot"), "🛒 Je duwt de kar", "en de knop zegt het")
	await _ruim_op(vp)

## Firefox meet `movementX` van een vinger vanaf de laatste plek van de muis: na
## één muisbeweging in de sessie krijgt het eerste trillinkje van een tik een
## `relative` van honderden eenheden (browserproef 2026-09-23: -553, -367 bij een
## vinger die 1 eenheid bewoog).  Godot telt die `relative` op en begon dan een
## sleep: de tik op de kar was weg.  De kar start zijn sleep nu zelf, gemeten aan
## de echte afstand tot het indrukpunt, dus deze tik blijft een tik.
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
	var kar := Hits.spot("karhot")
	if spel == null or kar == null:
		fout("het spel draait niet of de kar is geen knop")
		await _ruim_op(vp)
		return
	waar(not spel.mee(), "de kar staat nog")
	var p: Vector2 = (kar.knoop as Control).get_global_rect().get_center()
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = p
	mb.global_position = p
	vp.push_input(mb)
	await boom.process_frame
	# de vinger trilt één eenheid, maar Firefox meldt hem honderden eenheden ver
	var mm := InputEventMouseMotion.new()
	mm.position = p + Vector2(1, 0)
	mm.global_position = mm.position
	mm.relative = Vector2(-553, -367)
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(mm)
	await boom.process_frame
	waar(not Hits.sleept(), "een trillinkje is geen sleep")
	var los := InputEventMouseButton.new()
	los.button_index = MOUSE_BUTTON_LEFT
	los.pressed = false
	los.position = p + Vector2(1, 0)
	los.global_position = los.position
	vp.push_input(los)
	for _f in 3:
		await boom.process_frame
	waar(spel.mee(), "de tik pakte de kar")
	gelijk(_tekst("karhot"), "🛒 Je duwt de kar", "en de knop zegt het")
	gelijk(str(World.ding("kar").get("kamer", "")), "keuken", "de kar ging nergens heen")
	await _ruim_op(vp)

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
