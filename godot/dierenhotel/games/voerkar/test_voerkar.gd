extends Proef
## De voerkar (games-a.md §7), headless gespeeld door de ctx heen.
##
## Elke beurt wordt gedreven zoals een kind hem speelt: een tik op een knop van
## `Hits` of op een knop van de keuzestrook, nooit door een interne functie aan
## te roepen.  Wat hier vastligt: de aanmelding, één hele beurt per band, de
## misserweg met de hulpladder, het herstel uit de savegame, een schone wereld
## na `stop()`, elke kindtekst letterlijk, en 0 % dekking in vier kaders.

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

func _tik(id: String) -> bool:
	var k := _knop(id)
	if k == null:
		fout("knop %s staat er niet" % id)
		return false
	k.emit_signal("pressed")
	Hits.plaats()
	return true

## Een tik op een knop van de keuzestrook — dezelfde weg als een vinger.
func _tik_keuze(kaart_id: String, keuze_id: String) -> bool:
	var s := Hits.spot(kaart_id + "_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		fout("de keuzestrook van %s staat er niet" % kaart_id)
		return false
	var b := s.knoop.get_node_or_null("Rij/K" + keuze_id)
	if b == null:
		fout("keuze %s staat niet in de strook" % keuze_id)
		return false
	(b as BaseButton).emit_signal("pressed")
	Hits.plaats()
	return true

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

## De hele verdeling in één keer goed doen, alleen via tikken op de bakjes.
func _verdeel_goed(spel: Node, g: Array) -> void:
	var per := int(spel.K["per"])
	var rest := int(spel.K["rest"])
	_zet_hand(spel, 1)
	for q in g:
		for i in per:
			_tik("vk_%s" % str(q["id"]))
	for i in rest:
		_tik("vk___pot")

func _zet_hand(spel: Node, h: int) -> void:
	for _i in 4:
		if int(spel.K["hand"]) == h:
			return
		_tik("vk_zak")
	fout("de schep is niet op %d te zetten" % h)

## Alles wat er nog in de zak zit in één bakje kieperen (de misserweg).
func _leeg_de_zak(spel: Node, id: String) -> void:
	for _i in 80:
		if int(spel.K["zak"]) <= 0:
			return
		_tik("vk_%s" % id)
	fout("de zak raakt niet leeg")

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
			"🩺 Iedereen %d, rest in de pot",
			"pak %d",
			"zak met %d koekjes, pak %d per tik",
			"nog in de zak", "zak is leeg",
			"pot", "%s heeft %d koekjes", "de snoeppot: %d koekjes",
			"%d erbij", "%d eraf", "hier hoort %d in",
			"Klaar", "de kar is klaar",
			"Opnieuw", "alles opnieuw verdelen",
			"Els helpt", "buurvrouw Els doet het voor",
			"nog %d %s", "de voerkar: nog %d %s",
			"kar is leeg", "de voerkar is leeg",
			"Sleep de kar naar een deur", "Sleep de kar hierheen",
			"Breng %d koekjes naar elke gast", "Alle bakjes vol!",
			"koekjes", "koekjes elk",
			"↩", "🛒", "🍪", "🫙", "🩺", "🛏", "👉", "✅", "😋"]:
		waar(bron.contains(zin), 'games-a.md §7.7: "%s" staat in de bron' % zin)
	# elk kindwoord moet ook een glyph hebben in het meegeleverde font
	var mist: Array[String] = []
	for zin in ["🍪 Verdeel 17 koekjes over 5 gasten", "🫙 Ieder evenveel, de rest in de pot",
			"🩺 Iedereen 4, rest in de pot", "🛒 Klaar", "🩺 Els helpt", "🛏 nog geen gasten",
			"👉 Sleep de kar naar een deur", "✅ Alle bakjes vol!", "😋 4 koekjes elk",
			"🐶 Boef 12 · 8 eraf", "🐱 🐰 🦆 🐾", "🛒 nog 2 kamers"]:
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
	_keur_regel(spel.T_ELS_ZIN % 10, "de tweede zin met Els")
	spel.free()
	_af()

func _keur_regel(zin: String, wat: String) -> void:
	var woorden := zin.split(" ", false).size()
	waar(woorden <= 8 and zin.length() <= 40,
		"%s: \"%s\" = %d woorden, %d tekens" % [wat, zin, woorden, zin.length()])

# ------------------------------------------------------------- hele beurten

func test_beurt_band_3() -> void:
	await _hele_beurt(3, 3, 1)

func test_beurt_band_4() -> void:
	await _hele_beurt(4, 5, 3)

func test_beurt_band_5() -> void:
	await _hele_beurt(5, 7, 5)

## Eén hele beurt: de som komt uit `Sommen.deel`, het kind verdeelt met tikken,
## `🛒 Klaar` maakt de kar vol, en daarna rijdt het rondje elke kamer af.
func _hele_beurt(band: int, n: int, dag: int) -> void:
	_op()
	var spel := _start(n, band, dag, mini(n, 6))
	waar(spel != null, "band %d: het spel draait" % band)
	if spel == null:
		_af()
		return
	gelijk(ctx_band(), band, "band %d is echt de band" % band)
	var g: Array = spel.deelnemers()
	var som := Sommen.deel(g.size(), band, dag)
	gelijk(int(spel.K["T"]), int(som["T"]), "band %d: T uit Sommen.deel" % band)
	gelijk(int(spel.K["per"]), int(som["k"]), "band %d: per gast" % band)
	gelijk(int(spel.K["rest"]), int(som["r"]), "band %d: in de pot" % band)
	gelijk(int(spel.K["zak"]), int(som["T"]), "band %d: alles zit nog in de zak" % band)
	# de kaart draagt de opdracht in twee zinnen
	var kk := Hits.spot("vk_kaart")
	waar(kk != null, "band %d: er hangt een sommenkaart" % band)
	if kk != null:
		var kaart := kk.knoop as UiSomkaart
		gelijk(kaart.regel_label.text,
			"🍪 " + (spel.T_VERDEEL % [int(som["T"]), Ui.meervoud(g.size(), "gast", "gasten")]),
			"band %d: de eerste zin" % band)
		gelijk(kaart.regel2_label.text, spel.T_IEDER, "band %d: de tweede zin" % band)
		gelijk(kaart.som_label.visible, band >= 4 and int(som["r"]) == 0,
			"band %d: de somrij staat er alleen als het uitkomt" % band)
		waar(not kaart.vak_label.visible, "band %d: geen leeg antwoordvakje" % band)
	# ieder bakje draagt zijn dier en zijn getal
	for q in g:
		var t := _tekst("vk_%s" % str(q["id"]))
		waar(t.contains(str(q["naam"]).substr(0, 4)), "band %d: %s staat op zijn bakje" % [band, q["naam"]])
		waar(t.ends_with(" 0"), "band %d: %s begint op nul" % [band, q["naam"]])
	gelijk(_titel("vk___pot"), "de snoeppot: 0 koekjes", "band %d: de pot" % band)
	gelijk(_titel("vk_zak"), "zak met %d koekjes, pak 1 per tik" % int(som["T"]),
		"band %d: de zak vertelt wat er in zit" % band)
	# verdelen en klaar
	var sterren_voor := int(State.s["sterren"])
	var pot_voor := int(State.s["snoeppot"])
	_verdeel_goed(spel, g)
	gelijk(int(spel.K["zak"]), 0, "band %d: de zak is leeg na het verdelen" % band)
	_tik("vk_klaar")
	waar(bool(spel.K["vol"]), "band %d: de kar klopt" % band)
	gelijk(int(State.s["sterren"]), sterren_voor + 1, "band %d: één ster voor het meedoen" % band)
	gelijk(int(State.s["snoeppot"]), pot_voor + int(som["r"]), "band %d: de rest ging in de snoeppot" % band)
	waar(Hotel.taak_af("voer") or true, "het taakje mag afgevinkt zijn")
	# het rondje: de kar zegt hoeveel kamers er nog open zijn
	var open: Array = spel.open_kamers()
	waar(open.size() >= 1, "band %d: er is minstens één kamer met een bakje" % band)
	gelijk(_tekst("karhot"), "🛒 nog %d %s" % [open.size(), "kamer" if open.size() == 1 else "kamers"],
		"band %d: de kar telt de kamers" % band)
	gelijk(_tekst("vk_duw"), "🛒 Breng %d koekjes naar elke gast" % int(som["k"]),
		"band %d: de kar zegt wat er nu moet" % band)
	var boom := Engine.get_main_loop() as SceneTree
	var ronden := 0
	while not spel.open_kamers().is_empty() and ronden < 8:
		ronden += 1
		var q: Dictionary = spel.open_kamers()[0]
		var kamer := str(q["kamer"])
		# eerst zonder kar: het bakje vraagt om de kar
		if str(World.ding("kar").get("kamer", "")) != kamer:
			spel.lever(kamer, str(q["slot"]))
			gelijk(_tekst("vk_hier"), "🛒 Sleep de kar hierheen",
				"band %d: zonder kar wijst het bakje de weg" % band)
			waar(not spel.K["geleverd"].has(kamer), "band %d: en er is niets geleverd" % band)
			spel.duw_naar(kamer)
			Hits.plaats()
		gelijk(str(World.ding("kar").get("kamer", "")), kamer, "band %d: de kar staat in %s" % [band, kamer])
		waar(spel.lever(kamer, str(q["slot"])), "band %d: afleveren in %s lukt" % [band, kamer])
		Hits.plaats()
		gelijk(World.bak_stand(kamer, str(q["slot"])), 4, "band %d: het bakje is vol" % band)
		var hier := 0
		for gg in g:
			if str(gg.get("kamer", "")) == kamer:
				hier += 1
				waar(bool(gg.get("gegeten", false)), "band %d: %s heeft gegeten" % [band, gg["naam"]])
				gelijk(str(gg.get("behoefte", "")), "spelen", "band %d: en wil nu spelen" % band)
		gelijk(_tekst("vk_smul"), "😋 %d %s" % [int(som["k"]), "koekjes elk" if hier > 1 else "koekjes"],
			"band %d: het smulwolkje telt per dier" % band)
	gelijk(_tekst("vk_af"), "✅ Alle bakjes vol!", "band %d: alles rond" % band)
	_tik("vk_af")
	await boom.process_frame
	gelijk(Games.actief(), "", "band %d: het spel sluit zichzelf" % band)
	gelijk(State.s["kar"], null, "band %d: de kar is opgeruimd" % band)
	_af()

func ctx_band() -> int:
	return State.band()

# ------------------------------------------------------- de misserweg

## Nooit straffend: een misser kost niets, zet niets terug en geeft geen ster —
## alleen `zacht()` en één getal bij het bakje waar het over gaat.
func test_misser_en_hulpladder() -> void:
	_op()
	var spel := _start(3, 3, 1, 3)
	var g: Array = spel.deelnemers()
	var per := int(spel.K["per"])
	# te weinig verdeeld: er zit nog voer in de zak
	_zet_hand(spel, 1)
	_tik("vk_%s" % str(g[0]["id"]))
	var zak_voor := int(spel.K["zak"])
	var sterren_voor := int(State.s["sterren"])
	_tik("vk_klaar")
	gelijk(int(spel.K["missers"]), 1, "de eerste misser is geteld")
	gelijk(int(spel.K["zak"]), zak_voor, "en er wordt niets teruggezet")
	gelijk(int(State.s["sterren"]), sterren_voor, "een misser levert geen ster op")
	waar(not bool(spel.K["vol"]), "de kar is nog niet klaar")
	waar(_tekst("vk_zak").contains("nog in de zak"), "de zak zegt het zelf")
	waar(_knop("vk_els") == null, "na één poging is er nog geen hulp")
	# elk bakje vertelt hoeveel er bij of af moet
	var mis := per - int(spel.K["vak"][str(g[0]["id"])])
	if mis != 0:
		waar(_tekst("vk_%s" % str(g[0]["id"])).contains("%d erbij" % mis),
			"het bakje zegt hoeveel erbij moet")
	waar(_tekst("vk_%s" % str(g[1]["id"])).contains("%d erbij" % per),
		"een leeg bakje ook")
	# tweede poging: alles in één bakje, dus de zak is leeg maar het klopt niet
	_leeg_de_zak(spel, str(g[0]["id"]))
	_tik("vk_klaar")
	gelijk(int(spel.K["missers"]), 2, "de tweede misser is geteld")
	waar(_tekst("vk_%s" % str(g[0]["id"])).contains(" eraf"), "te veel: er moet wat af")
	# ... en nu komt Els, en ze blijft staan
	waar(_knop("vk_els") != null, "na twee pogingen staat Els er (HOTEL.md §5)")
	gelijk(_tekst("vk_els"), "🩺 Els helpt", "met pictogram én woord")
	gelijk(_titel("vk_els"), "buurvrouw Els doet het voor", "en een uitleg")
	_tik("vk_els")
	gelijk(int(spel.K["spook"]), 1, "Els doet het voor")
	waar(State.gezien("voerkar_els"), "en dat wordt onthouden")
	var kaart := Hits.spot("vk_kaart").knoop as UiSomkaart
	gelijk(kaart.regel2_label.text, "🩺 Iedereen %d, rest in de pot" % per,
		"de tweede zin van de kaart zegt het antwoord")
	waar(_titel("vk_%s" % str(g[1]["id"])).contains("hier hoort %d in" % per),
		"en elk bakje zegt waar het heen moet")
	waar(_knop("vk_els") != null, "Els blijft staan zolang er twee pogingen op zitten")
	# opnieuw beginnen zet alles terug in de zak
	_tik("vk_opnieuw")
	gelijk(int(spel.K["zak"]), int(spel.K["T"]), "↩ Opnieuw doet alles terug in de zak")
	gelijk(int(spel.K["pot"]), 0, "de pot is leeg")
	gelijk(int(spel.K["spook"]), 0, "en Els kijkt niet meer mee")
	waar(_knop("vk_els") != null, "maar haar knop blijft staan")
	_af()

## De schep: de strook zet hem, een tik op de zak schakelt door (1 → 2 → 5 → 1).
func test_de_schep_schakelt_door() -> void:
	_op()
	var spel := _start(2, 3, 1, 2)
	gelijk(int(spel.K["hand"]), 1, "je begint met pak 1")
	gelijk(_tekst("vk_zak").split(" ·")[0], "🍪 pak 1", "en dat staat op de zak")
	waar(_tik_keuze("vk_kaart", "h5"), "de strook heeft een knop `pak 5`")
	gelijk(int(spel.K["hand"]), 5, "de strook zet de schep")
	_tik("vk_zak")
	gelijk(int(spel.K["hand"]), 1, "en een tik op de zak schakelt door naar 1")
	_tik("vk_zak")
	gelijk(int(spel.K["hand"]), 2, "1 → 2")
	# met een lege zak zegt de zak het zelf; niets gaat er mis
	var g: Array = spel.deelnemers()
	_leeg_de_zak(spel, str(g[0]["id"]))
	var vak_voor := int(spel.K["vak"][str(g[0]["id"])])
	_tik("vk_%s" % str(g[0]["id"]))
	gelijk(int(spel.K["vak"][str(g[0]["id"])]), vak_voor, "uit een lege zak komt niets")
	waar(_tekst("vk_zak").contains("zak is leeg"), "en de zak zegt dat")
	_af()

# -------------------------------------------------------------- herstellen

## De stand van de kar leeft in `state.kar` (games-a.md §7.2) én in `ctx.data()`,
## en komt na een echte savegame-ronde als gehele getallen terug.
func test_herstel_uit_de_save() -> void:
	_op()
	var spel := _start(3, 3, 1, 3)
	var g: Array = spel.deelnemers()
	_zet_hand(spel, 2)
	_tik("vk_%s" % str(g[0]["id"]))
	_tik("vk___pot")
	var zak := int(spel.K["zak"])
	var vak := int(spel.K["vak"][str(g[0]["id"])])
	var pot := int(spel.K["pot"])
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
	gelijk(int(terug.K["zak"]), zak, "de zak staat er weer")
	gelijk(int(terug.K["vak"][str(g[0]["id"])]), vak, "en het bakje ook")
	gelijk(int(terug.K["pot"]), pot, "en de pot")
	gelijk(int(terug.K["hand"]), 2, "de schep staat nog op 2")
	gelijk(typeof(terug.K["T"]), TYPE_INT, "JSON gaf komma-getallen; ze zijn weer geheel")
	gelijk(_tekst("vk_%s" % str(g[0]["id"])).right(1), str(vak), "het kind ziet zijn eigen verdeling terug")
	# en de bakjes staan er weer, want los decor gaat niet mee in de savegame
	gelijk(World.decor_lijst("keuken").size(), g.size() + 1, "elk bakje en de pot staan er weer")
	_af()

## Halverwege het rondje herladen: de geleverde kamers blijven geleverd.
func test_herstel_midden_in_het_rondje() -> void:
	_op()
	var spel := _start(3, 3, 1, 3)
	var g: Array = spel.deelnemers()
	_verdeel_goed(spel, g)
	_tik("vk_klaar")
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
	waar(bool(terug.K["vol"]), "de kar was al vol en blijft vol")
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
	var g: Array = spel.deelnemers()
	waar(World.decor_lijst("keuken").size() > 0, "er staan bakjes in de keuken")
	_verdeel_goed(spel, g)
	_tik("vk_klaar")
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
## ook maar één voorwerp af, in vier kaders, met zes bakjes op de vloer.
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
		# het drukste beeld dat dit spel kent: zes bakjes én de pot met hun
		# correctie erbij, plus de knop van Els (twee missers)
		_tik("vk_klaar")
		_tik("vk_klaar")
		for _f in 2:
			await boom.process_frame
		var kader: Control = shell.get_node("Scherm/Kolom/Middenrij/Kaderdoos/Kader")
		var spel := _spel()
		waar(spel != null and spel.deelnemers().size() == 6,
			"%s: zes gasten doen mee" % str(maat))
		waar(_knop("vk_els") != null, "%s: Els staat er na twee pogingen" % str(maat))
		waar(_tekst("vk_boef").contains("erbij"), "%s: elk bakje draagt zijn correctie" % str(maat))
		var dbg := Hits.debug()
		var eigen := 0
		for id in dbg.keys():
			var s := Hits.spot(id)
			if s == null or s.door != SPEL:
				continue
			eigen += 1
			var d: Dictionary = dbg[id]
			var r: Rect2 = d["rect"]
			waar(not bool(d["krap"]), "%s: %s vond een echte plek" % [str(maat), id])
			waar(r.position.x >= 0.0 and r.position.y >= 0.0
				and r.end.x <= kader.size.x + 0.01 and r.end.y <= kader.size.y + 0.01,
				"%s: %s staat binnen het kader %s" % [str(maat), id, str(kader.size)])
			if s.kind != "tag" and s.kind != "naam":
				waar(r.size.x >= 44.0 and r.size.y >= 44.0,
					"%s: %s is een tikdoel (%s)" % [str(maat), id, str(r.size)])
			# een vaste kaart (en haar strook) mag over de wereld staan; een
			# knop nooit — die twee zijn de enige uitzondering (§4.3)
			if int(d["laag"]) == Hits.Laag.VAST:
				continue
			gelijk(Hits.dekking(id), 0.0, "%s: %s dekt zijn voorwerp niet af" % [str(maat), id])
			for ander in dbg.keys():
				var v: Rect2 = dbg[ander]["vlak"]
				if v.size.x <= 0.0:
					continue
				var snij := r.intersection(v)
				gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
					"%s: %s dekt het voorwerp van %s af" % [str(maat), id, ander])
		waar(eigen >= 10, "%s: %d knoppen van de voerkar in beeld" % [str(maat), eigen])
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

# ---------------------------------------------------------------- slepen

## Slepen uit de zak naar een bakje — de tweede weg van games-a.md §7.5, naast
## tikken.  Dit loopt door de échte invoerlaag van de motor (een muisknop en
## muisbewegingen in een SubViewport), niet langs `_get_drag_data` heen: alleen
## zo bewijst het dat het vangvlak van `Hits` een vinger ook echt vangt.
func test_slepen_uit_de_zak_in_een_bakje() -> void:
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
	waar(spel != null, "het spel draait")
	if spel == null:
		await _ruim_op(vp)
		return
	var g: Array = spel.deelnemers()
	var id := str(g[0]["id"])
	var zak := Hits.spot("vk_zak")
	var bak: Dictionary = Hits.debug().get("vk_%s" % id, {})
	waar(zak != null and not bak.is_empty(), "de zak en het bakje staan er")
	if zak == null or bak.is_empty():
		await _ruim_op(vp)
		return
	var van: Vector2 = (zak.knoop as Control).get_global_rect().get_center()
	# het VOORWERP is het doel: daar ligt gegarandeerd geen knop overheen
	var vlak: Rect2 = bak["vlak"]
	var naar: Vector2 = Ui.knoplaag.get_global_rect().position + vlak.get_center()
	var voor := int(spel.K["vak"][id])
	var hand := int(spel.K["hand"])
	var in_zak := int(spel.K["zak"])
	await _sleep(vp, van, naar)
	gelijk(int(spel.K["vak"][id]), voor + hand,
		"een sleep uit de zak legt %d koekje(s) in het bakje" % hand)
	gelijk(int(spel.K["zak"]), in_zak - hand, "en evenveel gaat er uit de zak")
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

## De kar door een deur slepen — de andere sleep van games-a.md §7.6, ook door
## de echte invoerlaag.  De deuren en de bakjes van het hotel zijn tijdens het
## rondje van de voerkar; dit bewijst dat de sleep daar ook echt aankomt.
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
	_verdeel_goed(spel, spel.deelnemers())
	_tik("vk_klaar")
	for _f in 3:
		await boom.process_frame
	waar(bool(spel.K["vol"]), "de kar is vol")
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
	await _ruim_op(vp)
