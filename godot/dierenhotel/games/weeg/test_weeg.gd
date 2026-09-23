extends Proef
## weeg — groenten wegen in de kas (games-c.md §3), headless.
##
## Driven the way a child drives it: an answer is a `pressed` on a button of
## the real strip, a weight is a `pressed` on its button on the card's strip,
## "eraf" is a `pressed` on the button at the balance.  Only the pure turn
## logic in `beurt.gd` and the balance's own model are called directly.

const SPEL := "weeg"
const KAMER := "kas"
const KAART := "wg_som"
const STROOK := "wg_som_keuzes"
const ERAF := "wg_eraf"
const ZEG := "wg_zeg"
const HULP := "wg_hulp"
const SPOOK := "wg_spook"
const AF := "wg_af"
const LEEG := "wg_leeg"
const SCHAAL := "wg_schaal"
const RUST := "rust_wg_schaal"
const Beurt := preload("res://games/weeg/beurt.gd")
const Modellen := preload("res://games/weeg/modellen.gd")
const Spel := preload("res://games/weeg/spel.gd")

const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740),
	Vector2i(740, 360)]

var _laag: Control = null
var _bewaard: Dictionary = {}
var _rust_voor := false

# ------------------------------------------------------------------ harnas

func _op(kader := Vector2(1000, 648)) -> void:
	_bewaard = State.s.duplicate(true)
	_rust_voor = Ui.rust_modus()
	Ui.zet_rust_modus(true)
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = kader
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	World.meet(Rect2(Vector2.ZERO, kader))

func _af() -> void:
	Games.stop()
	Ui.naamplaten_leeg()
	Hits.wis_alles()
	Ui.zet_rust_modus(_rust_voor)
	if "_scherm" in Ui:
		Ui.vergeet_scherm()
	if _laag != null:
		_laag.queue_free()
		_laag = null
	Ui.registreer_lagen(null, null, null)
	if not _bewaard.is_empty():
		State.s = _bewaard
		_bewaard = {}
	Games.hersteek()

func _wereld(n: int, band: int, dag := 2) -> Array:
	State.nieuw_spel()
	State.s["taken"] = []
	State.s["kunnen"] = 5
	State.s["dag"] = dag
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
		g["behoefte"] = "eten"
		g["blij"] = false
		uit.append(g)
	State.s["gasten"] = uit
	World.sync(uit)
	World.zet_dag(dag)
	gelijk(State.band(), band, "de band is %d bij %d gasten" % [band, n])
	return uit

func _knoop(id: String) -> Control:
	var s := Hits.spot(id)
	return null if s == null or not is_instance_valid(s.knoop) else s.knoop

func _tik(id: String) -> bool:
	var k := _knoop(id)
	if k == null or not (k is BaseButton):
		fout("hotspot %s is geen knop om te tikken" % id)
		return false
	(k as BaseButton).pressed.emit()
	return true

## A button of the real strip, by its choice id (`n37`, `kg5`).
func _strookknop(keuze: String) -> bool:
	var strook := _knoop(STROOK)
	if strook == null:
		fout("er is geen strook")
		return false
	var k := strook.get_node_or_null("Rij/K" + keuze)
	if k == null:
		fout("keuze %s staat niet op de strook" % keuze)
		return false
	(k as BaseButton).pressed.emit()
	return true

func _kies(getal: int) -> bool:
	return _strookknop("n%d" % getal)

func _leg(kg: int) -> bool:
	return _strookknop("kg%d" % kg)

func _strook() -> Array[String]:
	var uit: Array[String] = []
	var strook := _knoop(STROOK)
	if strook == null:
		return uit
	var rij := strook.get_node_or_null("Rij")
	if rij == null:
		return uit
	for k in rij.get_children():
		uit.append(str(k.name).substr(1))
	return uit

func _getallen() -> Array[int]:
	var uit: Array[int] = []
	for k in _strook():
		if k.begins_with("n"):
			uit.append(int(k.substr(1)))
	return uit

func _fout_getal(goed: int) -> int:
	for k in _getallen():
		if k != goed:
			return k
	return goed + 1

func _kaart_tekst(deel: String) -> String:
	var k := _knoop(KAART)
	if k == null:
		return ""
	var l := k.get_node_or_null(deel) as Label
	return "" if l == null else l.text

func _wolk_tekst(id: String) -> String:
	var k := _knoop(id)
	if k == null:
		return ""
	var uit := ""
	for l in k.find_children("*", "Label", true, false):
		uit += (l as Label).text + " "
	return uit.strip_edges()

func _stand() -> Dictionary:
	var d = State.spel_data(SPEL).get("stand", {})
	return d if typeof(d) == TYPE_DICTIONARY else {}

func _schaal() -> Dictionary:
	return World.decor_plek(SCHAAL, KAMER)

func _spel() -> Node:
	return Games._knoop if Games.actief() == SPEL else null

func _wacht(s: float) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	await boom.create_timer(s).timeout

func _wacht_mispauze() -> void:
	await _wacht(Ui.MIS_PAUZE + 0.25)

func _wacht_kaart() -> void:
	await _wacht(Spel.SOM_S + 0.25)

func _wacht_recht() -> void:
	await _wacht(Spel.RECHT_S + 0.3)

# -------------------------------------------------------------- aanmelding

func test_aanmelding() -> void:
	waar(Games.lijst().has(SPEL), "de mapscan vindt weeg")
	var def := Games.definitie(SPEL)
	gelijk(def.get("naam", ""), "Groenten wegen", "naam")
	gelijk(def.get("kamer", ""), KAMER, "kamer")
	gelijk(def.get("stub", true), false, "geen stub")
	var hs: Dictionary = def.get("hotspot", {})
	gelijk(hs.get("obj", ""), "pompoenen", "de ingang is verankerd aan het pompoenveldje")
	gelijk(hs.get("rust", ""), RUST, "en hangt aan de rustende weegschaal")
	gelijk(hs.get("icoon", ""), "⚖️", "icoon")
	gelijk(hs.get("label", ""), "Wegen", "label")
	var veld := World.mik("pompoenen", KAMER)
	waar(not veld.is_empty(), "het pompoenveldje staat in de kas")
	gelijk(float(veld.get("x", 0)) + float(hs["dx"]), float(Spel.SCHAAL_X), "x van de weegschaal")
	gelijk(float(veld.get("z", 0)) + float(hs["dz"]), float(Spel.SCHAAL_Z), "z van de weegschaal")
	var modellen: Dictionary = def.get("modellen", {})
	for m in ["weeg_schaal", "weeg_gewicht"]:
		waar(modellen.has(m) and Art.heeft_model(m), "%s wordt bij de scan aangemeld" % m)
	var rust: Array = def.get("rust", [])
	gelijk(str((rust[0] as Dictionary).get("id", "")), RUST, "het eerste rustspul is de weegschaal")
	gelijk(rust.size(), 1 + (Beurt.REK[4] as Array).size(), "plus een rij gewichten")
	var taak: Dictionary = def.get("taak", {})
	gelijk(taak.get("id", ""), "weeg", "taak id")
	gelijk(taak.get("kamer", ""), KAMER, "in de kas")
	waar(Ui.keur_taak("weeg", str(taak.get("tekst", ""))), "het briefje heeft ≤ 6 woorden")
	var unlock: Callable = def["unlock"]
	waar(not unlock.call(0, 3) and unlock.call(1, 3), "vanaf één gast")

## The balance bakes in every tilt, with every thing and a full stack; the
## pans follow the tilt; the stock weights bake.
func test_de_weegschaal_bakt_en_helt() -> void:
	for g in [2, 3, 4]:
		for kant in [-2, -1, 0, 1, 2]:
			for ding in ["", "pompoen", "meloen", "zak"]:
				var params := {"kant": kant, "l": ding, "lm": 2, "r": [20, 10, 5, 2, 1]}
				var p = Art.plaat("weeg_schaal", g, params)
				waar(p != null and p.w > 0 and p.h > 0, "weeg_schaal bakt (g=%d, kant %d, %s)" % [g, kant, ding])
		for kg in [1, 2, 5, 10, 20]:
			var q = Art.plaat("weeg_gewicht", g, {"kg": kg})
			waar(q != null and q.w > 0, "gewicht van %d kg bakt op g=%d" % [kg, g])
	gelijk(Modellen.pan_hoog(true, 0), Modellen.pan_hoog(false, 0), "recht: de pannen even hoog")
	waar(Modellen.pan_hoog(true, -2) < Modellen.pan_hoog(false, -2), "links zwaarder: links omlaag")
	waar(Modellen.pan_hoog(true, 2) > Modellen.pan_hoog(false, 2), "rechts zwaarder: rechts omlaag")
	waar(Modellen.pan_hoog(true, -2) < Modellen.pan_hoog(true, -1), "ver uit balans helt verder")
	# the lamp on the pivot is green only when level, and never red
	var recht: Array = Modellen.schaal({"kant": 0})
	var scheef: Array = Modellen.schaal({"kant": 1})
	var groen := func(v: Array) -> bool:
		for q in v:
			if (q["k"] as Color) == Modellen.RECHT:
				return true
		return false
	waar(groen.call(recht), "recht: het lampje is groen")
	waar(not groen.call(scheef), "scheef: niet groen")
	# the weights on the right pan are stacked, in the order they went on
	gelijk(Modellen.stapel_hoog([5, 1]), 4 + 2, "een stapel is zo hoog als zijn gewichten")

# ------------------------------------------------------------- het rekenen

## Every band, many days and hotel sizes (games-c.md §3.3).
func test_de_gewichten_per_band() -> void:
	for band in [3, 4, 5]:
		var gasten: Array = [[1, 2, 3], [4, 5, 6], [7, 8, 9, 10]][band - 3]
		var rek: Array = Beurt.REK[band]
		waar(rek.size() <= 4, "band %d: hooguit vier soorten, vier knoppen op een strook" % band)
		for n in gasten:
			for dag in range(1, 15):
				var o := Beurt.opzet(n, band, dag)
				var set1: Array = o["set1"]
				waar(set1.size() >= 2 and set1.size() <= 4, "band %d: 2 tot 4 gewichten op de weegschaal" % band)
				gelijk(Beurt.som(set1), int(o["gewicht1"]), "de gewichten wegen samen wat het ding weegt")
				for kg in set1:
					waar(rek.has(int(kg)), "alleen gewichten van deze band (%d)" % int(kg))
				var lo: int = [3, 11, 21][band - 3]
				var hi: int = [10, 20, 60][band - 3]
				waar(int(o["gewicht1"]) >= lo and int(o["gewicht1"]) <= hi,
					"band %d: het eerste ding weegt %d … %d (%d)" % [band, lo, hi, int(o["gewicht1"])])
				var g2 := int(o["gewicht2"])
				waar(g2 != int(o["gewicht1"]), "het tweede ding weegt iets anders")
				var lo2: int = [3, 8, 21][band - 3]
				var hi2: int = [9, 19, 59][band - 3]
				waar(g2 >= lo2 and g2 <= hi2, "band %d: het tweede %d … %d (%d)" % [band, lo2, hi2, g2])
				waar(Beurt.splits(g2, rek).size() <= Beurt.PAN_MAX - 1,
					"met hooguit %d gewichten recht te krijgen" % (Beurt.PAN_MAX - 1))
				gelijk(str(Beurt.opzet(n, band, dag)), str(o), "dezelfde dag, dezelfde beurt")
				waar(Beurt.DINGEN[band].has(str(o["ding1"])) and Beurt.DINGEN[band].has(str(o["ding2"])),
					"dingen van deze band")
				waar(str(o["ding1"]) != str(o["ding2"]), "twee verschillende dingen")

## Which way the beam leans, and how far.
func test_de_balans() -> void:
	gelijk(Beurt.kant(7, 7), 0, "even zwaar: recht")
	gelijk(Beurt.kant(7, 0), -2, "niets erop: het ding zakt ver")
	gelijk(Beurt.kant(7, 6), -1, "bijna: een beetje")
	gelijk(Beurt.kant(7, 8), 1, "net te zwaar: een beetje de andere kant")
	gelijk(Beurt.kant(7, 20), 2, "veel te zwaar: ver de andere kant")
	gelijk(Beurt.kant(40, 25), -2, "15 kilo te weinig bij 40 is ver (meer dan een kwart)")
	gelijk(Beurt.kant(40, 30), -1, "10 kilo te weinig bij 40 is nog een beetje (een kwart)")
	gelijk(Beurt.kant(4, 1), -2, "bij iets lichts telt minstens 2 kilo als ver")
	gelijk(Beurt.splits(17, [1, 2, 5, 10]), [10, 5, 2], "zo min mogelijk gewichten, zwaarste eerst")
	gelijk(Beurt.splits(26, [1, 5, 10, 20]), [20, 5, 1], "groep 5 zonder 2 kilo")
	gelijk(Beurt.som_regel([10, 5, 2]), "10 + 5 + 2 =", "de somregel")
	gelijk(Beurt.hulp([10, 5, 2]), "10 ▸ 15 ▸ 17", "doortellen")
	var liever := Beurt.liever([10, 5, 2])
	waar(liever.has(15), "een gewicht vergeten")
	waar(liever.has(3), "de gewichten geteld in plaats van opgeteld")

func test_elke_zin_past() -> void:
	if Ui.thema == null or Ui.thema.default_font == null:
		Ui._bouw_thema(17)
	var zinnen := [Beurt.T_RECHT, Beurt.T_VOL]
	for ding in ["pompoen", "meloen", "zak"]:
		zinnen.append(Beurt.vraag(ding))
		zinnen.append(Beurt.af(ding, 59))
		gelijk(Ui.mist_tekens(Beurt.icoon(ding)).size(), 0, "het pictogram van %s bestaat" % ding)
	for zin in zinnen:
		waar(Ui.keur_regel("weeg", zin), "binnen het budget: %s" % zin)
		waar(("🎃 " + zin).length() <= 40, "met het pictogram ≤ 40 tekens: %s" % zin)
		gelijk(Ui.mist_tekens(zin).size(), 0, "alle tekens bestaan: %s" % zin)
	for teken in [Beurt.ICOON, Beurt.ICOON_LICHT, Beurt.ICOON_ZWAAR, Beurt.ICOON_ERAF,
			Beurt.ICOON_HULP, Beurt.ICOON_AF, Beurt.ICOON_LEG]:
		gelijk(Ui.mist_tekens(teken).size(), 0, "het pictogram %s staat in de fontsubset" % teken)
	gelijk(Beurt.vraag("pompoen"), "Hoeveel kilo is de pompoen?", "de leesvraag")
	gelijk(Beurt.af("zak", 9), "De zak weegt 9 kilo!", "de slotzin")

# ------------------------------------------------------------ een hele beurt

## Groep 4, by finger: read the balance (with a miss), weigh the second thing
## yourself — too light, too heavy, a weight off again — and read your own
## measurement.
func test_een_beurt_in_groep_4() -> void:
	_op()
	_wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	var o := Beurt.opzet(4, 4, 2)
	gelijk(_stand().get("stap", ""), "lees1", "de leesvraag staat er meteen (R1)")
	gelijk(_kaart_tekst("Kolom/Regel"), Beurt.icoon(str(o["ding1"])) + " " + Beurt.vraag(str(o["ding1"])),
		"de zin noemt het ding")
	gelijk(_kaart_tekst("Kolom/Rij/Som"), Beurt.som_regel(o["set1"]), "de gewichten in de somregel")
	var s := _schaal()
	waar(not s.is_empty(), "de weegschaal staat er")
	gelijk(int(s["params"]["kant"]), 0, "recht")
	gelijk(str(s["params"]["r"]), str(o["set1"]), "met de gewichten op de rechter schaal")
	gelijk(str(s["params"]["l"]), str(o["ding1"]), "en het ding op de linker")
	waar(World.decor_plek(RUST, KAMER).is_empty(), "het rustspul is weg zolang er gespeeld wordt")
	for kg in o["rek"]:
		waar(not World.decor_plek("wg_kg%d" % int(kg), KAMER).is_empty(), "het gewicht van %d kg staat klaar" % int(kg))
	# a miss costs nothing and brings the same four choices back
	var keuzes := _getallen()
	gelijk(keuzes.size(), 4, "vier antwoorden")
	var sterren := int(State.s["sterren"])
	_kies(_fout_getal(int(o["gewicht1"])))
	gelijk(int(_stand().get("missers", 0)), 1, "de misser is geteld")
	waar(_knoop(HULP) != null, "de hulp hangt bij de weegschaal")
	waar(_wolk_tekst(HULP).begins_with(Beurt.ICOON_HULP) and _wolk_tekst(HULP).contains(Beurt.hulp(o["set1"])),
		"en telt de gewichten op (%s)" % _wolk_tekst(HULP))
	gelijk(int(State.s["sterren"]), sterren, "een misser kost niets")
	await _wacht_mispauze()
	gelijk(str(_getallen()), str(keuzes), "dezelfde vier keuzes in dezelfde volgorde")
	_kies(int(o["gewicht1"]))
	await _wacht_kaart()
	gelijk(_stand().get("stap", ""), "leg", "nu zelf wegen")
	gelijk(_kaart_tekst("Kolom/Regel"), Beurt.ICOON + " " + Beurt.T_RECHT, "maak hem weer recht")
	var g2 := int(o["gewicht2"])
	s = _schaal()
	gelijk(str(s["params"]["l"]), str(o["ding2"]), "het tweede ding ligt erop")
	gelijk(int(s["params"]["kant"]), -2, "en de weegschaal zakt naar zijn kant")
	gelijk(str(_strook()), str((o["rek"] as Array).map(func(v): return "kg%d" % int(v))),
		"één knop per gewicht op de strook, lichtste eerst")
	waar(_knoop(ERAF) == null, "zonder gewichten is er niets om eraf te halen")
	# too light: the weights side goes up
	var oplossing := Beurt.splits(g2, o["rek"])
	_leg(int(oplossing[0]))
	if Beurt.som([oplossing[0]]) < g2:
		waar(int(_schaal()["params"]["kant"]) < 0, "te licht: het ding hangt nog lager")
		waar(_wolk_tekst(ZEG).contains(Beurt.T_LICHT), "het wolkje zegt: nog te licht")
	waar(_knoop(ERAF) != null, "nu kan er een gewicht af")
	# too heavy on purpose, then off again: never a penalty
	var zwaarste := int((o["rek"] as Array).max())
	_leg(zwaarste)
	_leg(zwaarste)
	waar(int(_schaal()["params"]["kant"]) > 0, "te zwaar: de gewichten zakken")
	waar(_wolk_tekst(ZEG).contains(Beurt.T_ZWAAR), "het wolkje zegt: te zwaar")
	_tik(ERAF)
	_tik(ERAF)
	gelijk(str(_stand()["pan"]), str([oplossing[0]]), "eraf haalt het laatste gewicht eraf")
	gelijk(int(_stand().get("missers", 0)), 1, "te zwaar is geen misser")
	for i in range(1, oplossing.size()):
		_leg(int(oplossing[i]))
	gelijk(int(_schaal()["params"]["kant"]), 0, "recht!")
	waar(_wolk_tekst(ZEG).contains(Beurt.T_PRECIES), "precies")
	await _wacht_recht()
	gelijk(_stand().get("stap", ""), "lees2", "nu aflezen")
	gelijk(_kaart_tekst("Kolom/Regel"), Beurt.icoon(str(o["ding2"])) + " " + Beurt.vraag(str(o["ding2"])),
		"hoeveel weegt het tweede ding")
	gelijk(_kaart_tekst("Kolom/Rij/Som"), Beurt.som_regel(oplossing), "de eigen gewichten in de somregel")
	waar(_getallen().has(g2), "het goede antwoord staat op de strook")
	_kies(g2)
	gelijk(_stand().get("stap", ""), "af", "klaar")
	gelijk(int(State.s["sterren"]), sterren + 1, "één ster voor het meedoen")
	gelijk(_kaart_tekst("Kolom/Regel"), Beurt.ICOON_AF + " " + Beurt.af(str(o["ding2"]), g2), "de slotzin")
	gelijk(_kaart_tekst("Kolom/Rij/Vak"), str(g2), "het gewicht in het vakje")
	waar(_knoop(AF) != null, "de gast is blij met zijn meting")
	await _wacht(Spel.AF_S + 0.4)
	gelijk(Games.actief(), "", "en het spel sluit zichzelf")
	_af()

## Groep 5 weighs the giant pumpkin with 20 kg weights; groep 3 with 1, 2 and 5.
func test_groep_3_en_5() -> void:
	for rij in [[2, 3], [8, 5]]:
		_op()
		_wereld(int(rij[0]), int(rij[1]))
		waar(Games.start(SPEL), "het spel start (band %d)" % int(rij[1]))
		var o := Beurt.opzet(int(rij[0]), int(rij[1]), 2)
		_kies(int(o["gewicht1"]))
		await _wacht_kaart()
		gelijk(_strook().size(), (Beurt.REK[int(rij[1])] as Array).size(), "de gewichten van deze band")
		for kg in Beurt.splits(int(o["gewicht2"]), o["rek"]):
			_leg(int(kg))
		await _wacht_recht()
		_kies(int(o["gewicht2"]))
		gelijk(_stand().get("stap", ""), "af", "band %d is af" % int(rij[1]))
		if int(rij[1]) == 5 and str(o["ding2"]) == "pompoen":
			gelijk(int(_schaal()["params"]["lm"]), 2, "groep 5: de reuzenpompoen")
		_af()

## At most PAN_MAX weights on the pan: a sixth is refused kindly.
func test_de_schaal_is_vol() -> void:
	_op()
	_wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	var o := Beurt.opzet(4, 4, 2)
	_kies(int(o["gewicht1"]))
	await _wacht_kaart()
	for i in Beurt.PAN_MAX + 1:
		_leg(1)
	gelijk((_stand()["pan"] as Array).size(), Beurt.PAN_MAX, "niet meer dan %d gewichten" % Beurt.PAN_MAX)
	waar(_wolk_tekst(ZEG).contains(Beurt.T_VOL), "het wolkje zegt: neem een zwaarder gewicht")
	gelijk(int(_stand().get("missers", 0)), 0, "en dat is geen misser")
	_af()

## The help ladder: count on after a miss, the answer pale on the balance at the
## third, and while weighing, after many weights, the recipe.
func test_de_hulpladder() -> void:
	_op()
	_wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	var o := Beurt.opzet(4, 4, 2)
	var mis := _fout_getal(int(o["gewicht1"]))
	for i in 3:
		_kies(mis)
		waar(_knoop(HULP) != null, "misser %d: hulp bij de weegschaal" % (i + 1))
		if i < 2:
			waar(_knoop(SPOOK) == null, "misser %d: nog geen spookgetal" % (i + 1))
		await _wacht_mispauze()
	waar(_knoop(SPOOK) != null, "de derde misser: het antwoord bleek op de weegschaal")
	gelijk((_knoop(SPOOK) as Label).text if _knoop(SPOOK) is Label else "", str(int(o["gewicht1"])),
		"zoveel weegt het")
	_kies(int(o["gewicht1"]))
	await _wacht_kaart()
	waar(_knoop(HULP) == null and _knoop(SPOOK) == null, "goed: de hulp is weg")
	for i in Spel.SPOOK_LEG / 2:
		_leg(1)
		_tik(ERAF)
	var recept := " + ".join(PackedStringArray(Beurt.splits(int(o["gewicht2"]), o["rek"]).map(
		func(v): return str(v))))
	waar(_wolk_tekst(HULP).contains(recept), "na veel gewichten het recept (%s)" % _wolk_tekst(HULP))
	_af()

## "Een methode om te wisselen met welk dier je de spellen speelt" (owner,
## 2026-09-23, world.md §5.8): every guest with a bed may weigh, in check-in
## order; the animal on the game bar hands the scale to the next one in a
## fresh turn — nothing is taken away — and the next start weighs with the
## animal the child chose.
## Eigenaar, 2026-09-23: "Zorg dat de minigame pas begint wanneer het dier er
## is."  De weger komt uit zijn kamer: de weegschaal met de pompoen staat er
## al, maar de eerste leesvraag komt pas als hij ernaast staat.  Tot dan hangt
## het hotelwolkje "komt eraan" met `👀 Volg` aan de kasdeur.
func test_de_leesvraag_wacht_op_de_weger() -> void:
	_op()
	Ui.zet_rust_modus(false)
	var gasten := _wereld(1, 3)
	var id := str(gasten[0]["id"])
	World.zet(id, str(gasten[0]["kamer"]), 60.0, 60.0)   # in zijn eigen kamer
	World.pauzeer(true)                     # de test tikt de wereld zelf
	waar(Games.start(SPEL), "het spel start")
	gelijk(Games.speler(), id, "hij weegt")
	waar(Hits.spot(KAART) == null, "nog geen vraag")
	waar(not World.decor_plek(SCHAAL, KAMER).is_empty(), "de weegschaal staat er al")
	waar(Games.verwacht_dier(id), "het spel wacht op hem")
	waar(_komt_eraan_in_beeld(id), "zijn wolkje 'komt eraan' hangt aan de kasdeur")
	waar(_tik_tot_hij_binnen_is(id, KAMER), "hij stapt de kas in")
	await _wacht(0.35)
	waar(Hits.spot(KAART) == null, "zolang hij naar de weegschaal loopt, is er geen vraag")
	waar(_tik_tot_hij_staat(id, KAMER), "hij loopt naar de weegschaal")
	waar(await _staat_er_binnen(STROOK, 1500), "naast de weegschaal: de leesvraag met de strook")
	waar(not Games.verwacht_dier(id), "het spel wacht niet meer")
	World.pauzeer(false)
	_af()

## Tick until `id` stands still in `kamer`: arrived, not walking any more.
func _tik_tot_hij_staat(id: String, kamer: String) -> bool:
	var d = World.dier(id)
	var t := 0
	while d != null and t < 5000 and not (d.kamer == kamer and str(d.reis_doel).is_empty()
			and (d.route as Array).is_empty() and (d.punten as Array).is_empty()):
		World._tik()
		t += 1
	return d != null and d.kamer == kamer and (d.punten as Array).is_empty()

## Tick until `id` has stepped into `kamer` (and may still walk on in it).
func _tik_tot_hij_binnen_is(id: String, kamer: String) -> bool:
	var d = World.dier(id)
	var t := 0
	while d != null and d.kamer != kamer and t < 5000:
		World._tik()
		t += 1
	return d != null and d.kamer == kamer

## Real time, frames running, until hotspot `id` exists.
func _staat_er_binnen(id: String, ms: int) -> bool:
	var boom := Engine.get_main_loop() as SceneTree
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		if Hits.spot(id) != null:
			return true
		await boom.process_frame
	return Hits.spot(id) != null

## The hotel's "komt eraan" bubble of `id` hangs in the room in view, and stands
## on the glass while the game runs.
func _komt_eraan_in_beeld(id: String) -> bool:
	Hotel.komt_eraan()
	Hits.plaats()
	var w := Hits.spot("komt_" + id)
	return w != null and is_instance_valid(w.knoop) and w.knoop.visible

func test_het_kind_kiest_wie_er_weegt() -> void:
	_op()
	var gasten := _wereld(4, 4)
	var ids: Array[String] = []
	for g in gasten:
		ids.append(str(g["id"]))
	waar(Games.start(SPEL), "het spel start")
	gelijk(str(Games.spelers()), str(ids), "wie mag wegen: iedereen met een bed, op volgorde")
	gelijk(Games.speler(), str(_stand().get("gast", "")), "de balk weet wie er weegt")
	var o := Beurt.opzet(4, 4, 2)
	_kies(int(o["gewicht1"]))
	await _wacht_kaart()
	gelijk(_stand().get("stap", ""), "leg", "de leesvraag is af")
	var sterren := int(State.s["sterren"])
	var volgende := Games.volgende_speler()
	waar(not volgende.is_empty() and volgende != Games.speler(), "er is een ander dier")
	waar(Games.wissel_speler(), "het dier op de balk geeft de beurt door")
	gelijk(Games.actief(), SPEL, "het wegen gaat door")
	gelijk(Games.speler(), volgende, "met het volgende dier")
	gelijk(str(_stand().get("gast", "")), volgende, "in een eigen beurt")
	gelijk(_stand().get("stap", ""), "lees1", "die weer bij het aflezen begint")
	gelijk(int(State.s["sterren"]), sterren, "er ging geen ster af")
	Games.stop()
	waar(Games.start(SPEL), "het spel start opnieuw")
	gelijk(Games.speler(), volgende, "met het gekozen dier")
	_af()

## A reload in the middle of weighing keeps the pan.
func test_herladen_hervat_de_weging() -> void:
	_op()
	_wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	var o := Beurt.opzet(4, 4, 2)
	_kies(int(o["gewicht1"]))
	await _wacht_kaart()
	_leg(1)
	Games.stop()
	gelijk(_stand().get("stap", ""), "leg", "de stand is bewaard")
	waar(Games.start(SPEL), "opnieuw gestart")
	gelijk(str(_stand()["pan"]), str([1]), "het gewicht ligt er nog")
	gelijk(str(_schaal()["params"]["r"]), str([1]), "ook op de weegschaal")
	gelijk(_kaart_tekst("Kolom/Regel"), Beurt.ICOON + " " + Beurt.T_RECHT, "verder met wegen")
	var st: Dictionary = State.spel_data(SPEL)["stand"]
	st["pan"] = [1.0, 2.0]
	st["missers"] = 0.0
	Games.stop()
	waar(Games.start(SPEL), "na een JSON-ronde")
	gelijk(typeof((_stand()["pan"] as Array)[0]), TYPE_INT, "de gewichten zijn weer gehele getallen")
	_af()

func test_zonder_gasten() -> void:
	_op()
	State.nieuw_spel()
	State.s["gasten"] = []
	World.sync([])
	waar(Games.start(SPEL), "het spel start")
	waar(_knoop(LEEG) != null, "het wolkje zegt dat er nog geen gasten zijn")
	await _wacht(Spel.LEEG_S + 0.3)
	gelijk(Games.actief(), "", "en het spel sluit zichzelf")
	_af()

## The resting balance and its row of weights stand while nobody plays; the
## floor under them is kept free of wander places and furniture.
func test_de_rustende_weegschaal() -> void:
	_op()
	_wereld(3, 3)
	Games.hersteek()
	waar(not World.decor_plek(RUST, KAMER).is_empty(), "de weegschaal staat in de kas")
	for kg in Beurt.REK[4]:
		waar(not World.decor_plek("rust_wg_kg%d" % int(kg), KAMER).is_empty(),
			"met het gewicht van %d kg ernaast" % int(kg))
	waar(Games.start(SPEL), "het spel start")
	waar(World.decor_plek(RUST, KAMER).is_empty(), "het rustspul gaat weg")
	Games.stop()
	waar(not World.decor_plek(RUST, KAMER).is_empty(), "en komt terug")
	var r := Rooms.get_kamer(KAMER)
	for p in r.plekken:
		waar(not (p[0] >= 68 and p[0] <= 112 and p[1] >= 32 and p[1] <= 76),
			"geen loopplek op de weegschaal (%s)" % str(p))
	waar(not Rooms.vrij_vak(KAMER, float(Spel.SCHAAL_X), float(Spel.SCHAAL_Z)),
		"er kan geen meubel op de weegschaal")
	for i in 4:
		var p := Spel.voorraad_plek(i, 4)
		waar(p.x + 4 <= r.w and p.y + 4 <= r.d, "gewicht %d staat in de kas" % i)
	_af()

# ------------------------------------------------------- op vier schermen

func test_de_knoppen_op_vier_schermen() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var scherm_terug = Ui.get("_scherm")
	var rust_voor := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	var boom := Engine.get_main_loop() as SceneTree
	for maat in SCHERMEN:
		var vp := SubViewport.new()
		vp.size = maat
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		boom.root.add_child(vp)
		var shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		shell.set_meta("geen_start", true)
		vp.add_child(shell)
		for _f in 4:
			await boom.process_frame
		_wereld(4, 4)
		Hotel.start()
		for _f in 4:
			await boom.process_frame
		waar(Games.start(SPEL), "%s: het spel start" % str(maat))
		for _f in 4:
			await boom.process_frame
		var kader: Control = shell.get_node("Scherm/Kolom/Middenrij/Kaderdoos/Kader")
		var o := Beurt.opzet(4, 4, 2)
		_keur(kader.size, "%s lezen" % str(maat))
		# The first card docks in the maths bar like the other cards of the
		# turn ("weegt" made its line too wide on the 360 phone).  Not on the
		# landscape phone: a third of its 289 high frame is lower than any card
		# with a sum line, so every card floats there (the oogst card too).
		if maat.y >= 400:
			gelijk(Ui.balk_kaart(), KAART, "%s: de leesvraag staat in de rekenbalk" % str(maat))
		_kies(_fout_getal(int(o["gewicht1"])))
		for _f in 3:
			await boom.process_frame
		_keur(kader.size, "%s misser" % str(maat))
		if minf(kader.size.x, kader.size.y) >= 400.0:
			_bij_zijn_ding(HULP, "%s: het hulpwolkje" % str(maat))
		else:
			waar(_knoop(HULP) == null, "%s: op de telefoon geen hulpwolkje" % str(maat))
			waar(_kaart_tekst("Kolom/Hulp").contains("▸"), "%s: maar de hulpregel op de kaart" % str(maat))
		await _wacht_mispauze()
		_kies(int(o["gewicht1"]))
		await _wacht_kaart()
		var oplossing := Beurt.splits(int(o["gewicht2"]), o["rek"])
		_leg(int(oplossing[0]))
		for _f in 3:
			await boom.process_frame
		_keur(kader.size, "%s wegen" % str(maat))
		_bij_zijn_ding(ERAF, "%s: eraf" % str(maat))
		if minf(kader.size.x, kader.size.y) >= 400.0:
			_bij_zijn_ding(ZEG, "%s: het wolkje van de balans" % str(maat))
		else:
			waar(_knoop(ZEG) == null, "%s: op de telefoon geen wolkje naast de balans" % str(maat))
			waar(_kaart_tekst("Kolom/Hulp").contains(Beurt.T_LICHT),
				"%s: maar op de kaart: nog te licht (%s)" % [str(maat), _kaart_tekst("Kolom/Hulp")])
		Games.stop()
		Ui.naamplaten_leeg()
		Hits.wis_alles()
		vp.queue_free()
		await boom.process_frame
		Ui.registreer_lagen(null, null, null)
	State.s = bewaard
	Ui.set("_scherm", scherm_terug)
	Ui.zet_rust_modus(rust_voor)
	Games.hersteek()

func _keur(kader: Vector2, wat: String) -> void:
	var dbg := Hits.debug()
	var vakken: Array[Rect2] = []
	for id in dbg.keys():
		var v: Rect2 = dbg[id]["vlak"]
		if v.size.x > 0.0 and v.size.y > 0.0:
			vakken.append(v)
	var eigen := 0
	for id in dbg.keys():
		var spot := Hits.spot(id)
		if spot == null or spot.door != SPEL:
			continue
		eigen += 1
		var d: Dictionary = dbg[id]
		var r: Rect2 = d["rect"]
		# `Ui`'s own miss bubble (S5) on the landscape phone: see test_oogst
		var s5_laag := str(id).begins_with(Ui.MIS_WOLK) and kader.y < 300.0
		waar(not bool(d["krap"]) or s5_laag, "%s: %s vond een echte plek" % [wat, id])
		waar(r.position.x >= -0.01 and r.position.y >= -0.01
			and r.end.x <= kader.x + 0.01 and r.end.y <= kader.y + 0.01,
			"%s: %s staat binnen het kader (%s)" % [wat, id, str(r)])
		if spot.kind == "tag" or int(d["laag"]) == Hits.Laag.VAST:
			continue
		waar(Hits.dekking(id) <= 0.0 or str(d["op"]) == "aan",
			"%s: %s dekt zijn voorwerp niet (%s, %.1f %%)" % [wat, id, str(d["op"]), Hits.dekking(id)])
		waar(r.size.x >= 44.0 and r.size.y >= 44.0, "%s: %s is een tikdoel" % [wat, id])
		for v in vakken:
			if v == d["vlak"]:
				continue
			var snij := r.intersection(v)
			waar(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y) <= 0.15 * v.get_area() + 0.5,
				"%s: %s dekt geen ander voorwerp af" % [wat, id])
	waar(eigen >= 2, "%s: het spel staat op het scherm (%d)" % [wat, eigen])

func _bij_zijn_ding(id: String, wat: String) -> void:
	var dbg := Hits.debug()
	waar(dbg.has(id), "%s staat er" % wat)
	if not dbg.has(id):
		return
	var r: Rect2 = dbg[id]["rect"]
	var vlak: Rect2 = dbg[id]["vlak"]
	waar(vlak.size.x > 0.0, "%s kent zijn ding" % wat)
	var gat_x := maxf(0.0, maxf(vlak.position.x - r.end.x, r.position.x - vlak.end.x))
	var gat_y := maxf(0.0, maxf(vlak.position.y - r.end.y, r.position.y - vlak.end.y))
	var kader := World.kader_rect().size
	var mag := Hits.GAT + 1.0 if minf(kader.x, kader.y) >= 400.0 else float(Hits.RIJ) + Hits.GAT
	waar(gat_x <= mag and gat_y <= mag, "%s hangt bij zijn ding (gat %.0f, %.0f)" % [wat, gat_x, gat_y])
