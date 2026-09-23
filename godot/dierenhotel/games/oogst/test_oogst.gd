extends Proef
## oogst — aardbeien plukken in de kas (games-c.md §2), headless.
##
## Driven the way a child drives it: an answer is a `pressed` on a button of
## the real strip, a pick is a `pressed` on the real pick button that hangs on
## the planter.  Only the pure turn logic in `beurt.gd` is called directly.

const SPEL := "oogst"
const KAMER := "kas"
const KAART := "og_som"
const STROOK := "og_som_keuzes"
const PLUK := "og_pluk"
const HULP := "og_hulp"
const SPOOK := "og_spook"
const LEKKER := "og_lekker"
const LEEG := "og_leeg"
const TAFEL := "og_tafel"
const RUST := "rust_og_tafel"
const Beurt := preload("res://games/oogst/beurt.gd")
const Modellen := preload("res://games/oogst/modellen.gd")
const Spel := preload("res://games/oogst/spel.gd")

## The four ticket screens (tablet both ways, phone both ways).
const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740),
	Vector2i(740, 360)]

var _laag: Control = null
var _bewaard: Dictionary = {}
var _rust_voor := false

# ------------------------------------------------------------------ harnas

func _op(kader := Vector2(1000, 648)) -> void:
	_bewaard = State.s.duplicate(true)
	_rust_voor = Ui.rust_modus()
	Ui.zet_rust_modus(true)                 # a walk is a teleport: no waiting
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

## `n` guests from the pool, the first four in a real bed.  `kunnen` lifts
## the adaptive cap so the band really is the band the test asks for.  The
## save is never written: `start_gekozen()` is not called (see test_kraam).
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

## One number on the real strip under the card.
func _kies(getal: int) -> bool:
	var strook := _knoop(STROOK)
	if strook == null:
		fout("er is geen antwoordstrook")
		return false
	var k := strook.get_node_or_null("Rij/Kn%d" % getal)
	if k == null:
		fout("getal %d staat niet op de strook" % getal)
		return false
	(k as BaseButton).pressed.emit()
	return true

## The numbers on the strip, in order.
func _strook() -> Array[int]:
	var uit: Array[int] = []
	var strook := _knoop(STROOK)
	if strook == null:
		return uit
	var rij := strook.get_node_or_null("Rij")
	if rij == null:
		return uit
	for k in rij.get_children():
		var naam := str(k.name)
		if naam.begins_with("Kn"):
			uit.append(int(naam.substr(2)))
	return uit

func _kaart_tekst(deel: String) -> String:
	var k := _knoop(KAART)
	if k == null:
		return ""
	var l := k.get_node_or_null(deel) as Label
	return "" if l == null else l.text

func _stand() -> Dictionary:
	var d = State.spel_data(SPEL).get("stand", {})
	return d if typeof(d) == TYPE_DICTIONARY else {}

func _spel() -> Node:
	return Games._knoop if Games.actief() == SPEL else null

func _tafel() -> Dictionary:
	return World.decor_plek(TAFEL, KAMER)

func _wacht(s: float) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	await boom.create_timer(s).timeout

## The strip is locked for `Ui.MIS_PAUZE` after a miss (S5): tap again only
## after it, the way a child with a real finger does.
func _wacht_mispauze() -> void:
	await _wacht(Ui.MIS_PAUZE + 0.25)

## The next card comes SOM_S after a right answer.
func _wacht_kaart() -> void:
	await _wacht(Spel.SOM_S + 0.25)

## A number on the strip that is not the answer.
func _fout_getal(goed: int) -> int:
	for k in _strook():
		if k != goed:
			return k
	return goed + 1

func _berries(b: Array) -> int:
	var t := 0
	for n in b:
		t += maxi(0, int(n))
	return t

# -------------------------------------------------------------- aanmelding

## The directory scan finds the game, and its registration says where it lives
## and what it hangs on (games-c.md §2.2).
func test_aanmelding() -> void:
	waar(Games.lijst().has(SPEL), "de mapscan vindt oogst")
	var def := Games.definitie(SPEL)
	gelijk(def.get("naam", ""), "Aardbeien plukken", "naam")
	gelijk(def.get("kamer", ""), KAMER, "kamer")
	gelijk(def.get("stub", true), false, "geen stub")
	var hs: Dictionary = def.get("hotspot", {})
	gelijk(hs.get("obj", ""), "aardbeienbakz", "de ingang is verankerd aan de aardbeienbak")
	gelijk(hs.get("rust", ""), RUST, "en hangt aan de rustende pluktafel")
	gelijk(hs.get("icoon", ""), "🍓", "icoon")
	gelijk(hs.get("label", ""), "Plukken", "label")
	# the planter really stands where the entry is anchored, and the nudge lands
	# on the table
	var bak := World.mik("aardbeienbakz", KAMER)
	waar(not bak.is_empty(), "de aardbeienbak staat in de kas")
	gelijk(float(bak.get("x", 0)) + float(hs["dx"]), float(Spel.TAFEL_X), "x van de tafel")
	gelijk(float(bak.get("z", 0)) + float(hs["dz"]), float(Spel.TAFEL_Z), "z van de tafel")
	var modellen: Dictionary = def.get("modellen", {})
	waar(modellen.has("oogst_tafel"), "het tafelmodel wordt bij de scan aangemeld")
	waar(Art.heeft_model("oogst_tafel"), "en Art kent het")
	var rust: Array = def.get("rust", [])
	gelijk(rust.size(), 1, "één rustspul: de pluktafel")
	gelijk(str((rust[0] as Dictionary).get("id", "")), RUST, "met het id van de ingang")
	var taak: Dictionary = def.get("taak", {})
	gelijk(taak.get("id", ""), "oogst", "taak id")
	gelijk(taak.get("kamer", ""), KAMER, "het briefje zegt: in de kas")
	waar(int(taak.get("prio", 0)) >= 5, "een gewoon klusje (prio ≥ 5)")
	waar(Ui.keur_taak("oogst", str(taak.get("tekst", ""))), "het briefje heeft ≤ 6 woorden")
	var unlock: Callable = def["unlock"]
	waar(not unlock.call(0, 3), "zonder gasten niet")
	waar(unlock.call(1, 3), "vanaf één gast wel")

## The table model bakes at every scale, with and without punnets and ghosts.
func test_de_pluktafel_bakt() -> void:
	for g in [2, 3, 4]:
		for params in [{}, {"b": [10, 10, 4, 0, -1]}, {"b": Spel.RUST_BAKJES},
				{"b": [10, 10, 10, 10, 10, 10, 10, 10, 10, 10]}, {"b": [3], "spook": 0}]:
			var p = Art.plaat("oogst_tafel", g, params)
			waar(p != null and p.w > 0 and p.h > 0, "oogst_tafel bakt op g=%d met %s" % [g, str(params)])
	# the berries are really in the model: more berries, more voxels
	var leeg: Array = Modellen.tafel({"b": [0]})
	var vol: Array = Modellen.tafel({"b": [10]})
	waar(vol.size() > leeg.size(), "een vol bakje heeft meer voxels dan een leeg")
	var spook: Array = Modellen.tafel({"b": [4], "spook": 0})
	var zonder: Array = Modellen.tafel({"b": [4]})
	waar(spook.size() > zonder.size(), "het spookbakje toont bleke aardbeien in de lege gaatjes")
	# ten places, five per column, none on top of another
	var gezien := {}
	for i in 10:
		var p := Modellen.plek(i)
		waar(not gezien.has(p), "plek %d is een eigen plek" % i)
		gezien[p] = true
		waar(absi(p.x) + Modellen.BAKJE_L / 2 <= 13 and absi(p.y) + Modellen.BAKJE_D_Z / 2 <= 18,
			"plek %d ligt op het tafelblad" % i)

# ------------------------------------------------------------- het rekenen

## Every band, many days and hotel sizes: the table is place value on punnets
## of ten, the second question is the complement, and the numbers stay inside
## the band's range (games-c.md §2.3).
func test_de_getallen_per_band() -> void:
	for dag in range(1, 15):
		for n in [1, 2, 3]:
			var o := Beurt.opzet(n, 3, dag)
			waar(int(o["vol"]) in [0, 1], "groep 3: hooguit één vol bakje")
			waar(int(o["T"]) <= 19, "groep 3: tot 20 (%d)" % int(o["T"]))
			waar(int(o["los"]) >= (3 if int(o["vol"]) == 0 else 1), "een open bakje met genoeg")
			gelijk(int(o["doel"]), int(o["vol"]) + 1, "groep 3 vult het open bakje")
			gelijk(int(o["nodig"]), 10 - int(o["los"]), "splitsen tot 10")
		for n in [4, 5, 6]:
			var o := Beurt.opzet(n, 4, dag)
			gelijk(int(o["vol"]), clampi(n - 1, 2, 5), "groep 4: een vol bakje per gast behalve één")
			waar(int(o["T"]) >= 21 and int(o["T"]) <= 59, "groep 4: tot 100 (%d)" % int(o["T"]))
			gelijk(int(o["nodig"]), 10 - int(o["los"]), "aanvullen tot het tiental")
		for n in [7, 8, 9, 10]:
			var o := Beurt.opzet(n, 5, dag)
			waar(int(o["vol"]) >= 5 and int(o["vol"]) <= 8, "groep 5: vijf tot acht volle bakjes")
			gelijk(int(o["doel"]), 10, "groep 5: tot alle tien vol zijn")
			gelijk(int(o["nodig"]), 100 - int(o["T"]), "aanvullen tot 100")
			waar(int(o["nodig"]) >= 11 and int(o["nodig"]) <= 49, "en dat is 11 … 49")
	for band in [3, 4, 5]:
		for dag in range(1, 8):
			var o := Beurt.opzet(4, band, dag)
			gelijk(int(o["T"]), 10 * int(o["vol"]) + int(o["los"]), "T is tientallen en eenheden")
			gelijk(int(o["T"]) + int(o["nodig"]), 10 * int(o["doel"]), "na het plukken is alles vol")
			waar(int(o["los"]) >= 1 and int(o["los"]) <= 9, "het open bakje is nooit leeg of vol")
			gelijk(str(Beurt.opzet(4, band, dag)), str(o), "dezelfde dag, dezelfde tafel")

## The four answers carry the slips a child really makes: the digits turned
## round (14 becomes 41), and they never go past 100.
func test_de_vier_antwoorden() -> void:
	for band in [3, 4, 5]:
		for dag in range(1, 10):
			var n: int = [2, 5, 8][band - 3]
			var o := Beurt.opzet(n, band, dag)
			var tel := Afleiders.vier(int(o["T"]), dag, {"max": 100, "liever": Beurt.liever_tel(o)})
			gelijk(tel.size(), 4, "vier antwoorden op de telvraag")
			waar(tel.has(int(o["T"])), "het goede staat erbij")
			if int(o["vol"]) > 0 and int(o["los"]) != int(o["vol"]):
				waar(tel.has(10 * int(o["los"]) + int(o["vol"])), "en de omgedraaide cijfers (%s)" % str(tel))
			var bij := Afleiders.vier(int(o["nodig"]), dag, {"max": 100, "liever": Beurt.liever_bij(o)})
			waar(bij.has(int(o["nodig"])), "de aanvulvraag heeft het goede antwoord")
			for v in tel + bij:
				waar(v >= 0 and v <= 100, "nooit buiten 0 … 100 (%d)" % v)

## The punnets on the table follow the picking: one berry at a time into the
## open punnet, then (band 5) a whole punnet per tap; the table always holds
## what the sum line says.
func test_plukken_via_de_tien() -> void:
	for band in [3, 4, 5]:
		var o := Beurt.opzet([2, 4, 8][band - 3], band, 3)
		var geplukt := 0
		var tikken := 0
		while Beurt.pluk_stap(o, geplukt) > 0 and tikken < 100:
			var stap := Beurt.pluk_stap(o, geplukt)
			if geplukt < 10 - int(o["los"]):
				gelijk(stap, 1, "band %d: eerst één aardbei per tik" % band)
			else:
				gelijk(stap, 10, "band %d: daarna een heel bakje per tik" % band)
			geplukt += stap
			tikken += 1
			var b := Beurt.bakjes(o, geplukt)
			gelijk(_berries(b), int(o["T"]) + geplukt, "band %d: op tafel ligt T + geplukt" % band)
		gelijk(geplukt, int(o["nodig"]), "band %d: precies het antwoord geplukt" % band)
		var eind := Beurt.bakjes(o, geplukt)
		for i in int(o["doel"]):
			gelijk(int(eind[i]), 10, "band %d: bakje %d is vol" % [band, i])
		for i in range(int(o["doel"]), 10):
			gelijk(int(eind[i]), -1, "band %d: plek %d blijft leeg" % [band, i])
		if band == 5:
			gelijk(tikken, (10 - int(o["los"])) + int((int(o["nodig"]) - (10 - int(o["los"]))) / 10.0),
				"groep 5: de losse aardbeien en dan per tien")

## Every sentence a child reads fits the budget and has its glyphs.
func test_elke_zin_past() -> void:
	if Ui.thema == null or Ui.thema.default_font == null:
		Ui._bouw_thema(17)
	var zinnen := [Beurt.T_TEL, Beurt.T_TEL2, Beurt.T_BIJ, Beurt.T_HONDERD, Beurt.T_AF,
		Beurt.T_PLUK % 49, Beurt.T_AF2 % 100]
	for zin in zinnen:
		waar(Ui.keur_regel("oogst", zin), "binnen het budget: %s" % zin)
		waar((Beurt.ICOON + " " + zin).length() <= 40, "met het pictogram ≤ 40 tekens: %s" % zin)
		gelijk(Ui.mist_tekens(zin).size(), 0, "alle tekens bestaan: %s" % zin)
	for teken in [Beurt.ICOON, Beurt.ICOON_PLUK10, Beurt.ICOON_HULP, Beurt.ICOON_AF,
			Beurt.ICOON_LEKKER]:
		gelijk(Ui.mist_tekens(teken).size(), 0, "het pictogram %s staat in de fontsubset" % teken)
	# the help lines count along the real structure of the table
	var o := {"band": 4, "vol": 3, "los": 4, "T": 34, "doel": 4, "nodig": 6}
	gelijk(Beurt.hulp_tel(o), "10 … 20 … 30 en nog 4", "tellen per bakje")
	gelijk(Beurt.hulp_bij(o), "5 … 6 … 7 … 8 … 9 … 10", "doortellen tot 10")
	gelijk(Beurt.som_bij(o), "4 + __ = 10", "de aanvulsom met het gat")
	var o5 := {"band": 5, "vol": 6, "los": 3, "T": 63, "doel": 10, "nodig": 37}
	gelijk(Beurt.hulp_bij(o5), "63 ▸ 70 ▸ 80 ▸ 90 ▸ 100", "via de tientallen naar 100")
	gelijk(Beurt.som_bij(o5), "63 + __ = 100", "de aanvulsom tot honderd")
	gelijk(Beurt.spook_bij(o5), "7 + 30", "het spookgetal laat de twee stappen zien")

# ------------------------------------------------------------ een hele beurt

## Groep 4, the whole turn by finger: count, one miss, fill, pick, done.
func test_een_beurt_in_groep_4() -> void:
	_op()
	var gasten := _wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	var o := Beurt.opzet(4, 4, 2)
	gelijk(_stand().get("stap", ""), "tel", "de telvraag staat er meteen (R1)")
	gelijk(_kaart_tekst("Kolom/Regel"), "🍓 " + Beurt.T_TEL, "de zin op de kaart")
	var keuzes := _strook()
	gelijk(keuzes.size(), 4, "vier antwoorden")
	waar(keuzes.has(int(o["T"])), "het goede staat erbij (%s)" % str(keuzes))
	# the table stands with its punnets: vol full, one open
	var tafel := _tafel()
	waar(not tafel.is_empty(), "de pluktafel staat in de kas")
	gelijk(str(tafel["params"]["b"]), str(Beurt.bakjes(o, 0)), "met de bakjes van vandaag")
	waar(World.decor_plek(RUST, KAMER).is_empty(), "het rustspul is weg zolang er gespeeld wordt")
	# the guest of the turn came in and stands beside the table (the doors are
	# a teleport in reduced motion, the last leg in the room is a short walk)
	await _wacht(1.2)
	var gast := str(_stand().get("gast", ""))
	var d = World.dier(gast)
	waar(d != null and d.kamer == KAMER, "de gast van de beurt is in de kas")
	if d != null:
		waar(absf(d.x - Spel.GAST_X) + absf(d.z - Spel.GAST_Z) <= 1.0, "naast de tafel")
	# a miss: nothing lost, the same four choices, help on the table
	var sterren := int(State.s["sterren"])
	var fout_getal := -1
	for k in keuzes:
		if k != int(o["T"]):
			fout_getal = k
			break
	_kies(fout_getal)
	gelijk(_stand().get("stap", ""), "tel", "een misser: dezelfde vraag")
	gelijk(int(_stand().get("missers", 0)), 1, "de misser is geteld")
	waar(_knoop(HULP) != null, "de hulp hangt als wolkje bij de tafel")
	gelijk(int(State.s["sterren"]), sterren, "een misser kost niets")
	var strook := _knoop(STROOK) as UiKeuzes
	waar(strook != null and strook.op_slot, "de strook staat even op slot (S5)")
	await _wacht_mispauze()
	gelijk(str(_strook()), str(keuzes), "daarna dezelfde vier keuzes in dezelfde volgorde")
	# right: the second question
	_kies(int(o["T"]))
	await _wacht_kaart()
	gelijk(_stand().get("stap", ""), "bij", "tweede vraag: hoeveel passen er nog bij")
	gelijk(_kaart_tekst("Kolom/Regel"), "🍓 " + Beurt.T_BIJ, "de zin van de tweede vraag")
	gelijk(_kaart_tekst("Kolom/Rij/Som"), "%d + __ = 10" % int(o["los"]), "de aanvulsom")
	waar(_knoop(HULP) == null, "de hulp is weg bij een nieuwe vraag")
	waar(_strook().has(int(o["nodig"])), "het goede antwoord staat op de strook")
	_kies(int(o["nodig"]))
	await _wacht_kaart()
	gelijk(_stand().get("stap", ""), "pluk", "nu zelf plukken")
	waar(_knoop(PLUK) != null, "de plukknop hangt aan de aardbeienbak")
	gelijk(_kaart_tekst("Kolom/Regel"), "🍓 " + Beurt.T_PLUK % int(o["nodig"]), "pluk er nog …")
	for i in int(o["nodig"]):
		_tik(PLUK)
		if i < int(o["nodig"]) - 1:
			gelijk(_kaart_tekst("Kolom/Rij/Vak"), str(int(o["T"]) + i + 1), "het vakje telt mee")
	gelijk(_stand().get("stap", ""), "af", "alle bakjes vol")
	gelijk(int(State.s["sterren"]), sterren + 1, "één ster voor het meedoen")
	gelijk(_kaart_tekst("Kolom/Regel"), "✅ " + Beurt.T_AF, "de slotzin")
	gelijk(_kaart_tekst("Kolom/Regel2"), Beurt.T_AF2 % (10 * int(o["doel"])), "zoveel voor de gasten")
	gelijk(_kaart_tekst("Kolom/Rij/Vak"), str(10 * int(o["doel"])), "het totaal in het vakje")
	waar(_knoop(PLUK) == null, "er valt niets meer te plukken")
	waar(_knoop(LEKKER) != null, "de gast proeft")
	var eind: Array = _tafel()["params"]["b"]
	for i in int(o["doel"]):
		gelijk(int(eind[i]), 10, "bakje %d is vol" % i)
	waar(gasten.size() == 4, "vier gasten")
	_af()

## Groep 5 goes to a hundred, and "via the ten": first the loose berries, then
## a whole punnet per tap — the button says so.
func test_een_beurt_in_groep_5() -> void:
	_op()
	_wereld(8, 5)
	waar(Games.start(SPEL), "het spel start")
	var o := Beurt.opzet(8, 5, 2)
	_kies(int(o["T"]))
	await _wacht_kaart()
	gelijk(_kaart_tekst("Kolom/Regel"), "🍓 " + Beurt.T_HONDERD, "hoeveel nog tot 100")
	gelijk(_kaart_tekst("Kolom/Rij/Som"), "%d + __ = 100" % int(o["T"]), "de som tot honderd")
	_kies(int(o["nodig"]))
	await _wacht_kaart()
	gelijk(_stand().get("stap", ""), "pluk", "plukken")
	var tikken := 0
	var bakjes_tikken := 0
	while str(_stand().get("stap", "")) == "pluk" and tikken < 60:
		var knop := _knoop(PLUK) as Button
		waar(knop != null, "de plukknop is er")
		if knop == null:
			break
		var voor := int(_stand().get("geplukt", 0))
		if voor >= 10 - int(o["los"]):
			waar(knop.text.contains(Beurt.T_PLUK10_KNOP), "na het volle bakje: pluk een bakje (%s)" % knop.text)
			bakjes_tikken += 1
		else:
			waar(knop.text.contains(Beurt.T_PLUK_KNOP) and not knop.text.contains(Beurt.T_PLUK10_KNOP),
				"eerst één aardbei per tik (%s)" % knop.text)
		knop.pressed.emit()
		tikken += 1
	gelijk(_stand().get("stap", ""), "af", "tot honderd")
	gelijk(bakjes_tikken, 9 - int(o["vol"]), "de lege bakjes elk met één tik")
	gelijk(_kaart_tekst("Kolom/Rij/Vak"), "100", "honderd aardbeien")
	gelijk(_kaart_tekst("Kolom/Regel2"), Beurt.T_AF2 % 100, "honderd voor de gasten")
	_af()

## Groep 3: one open punnet (and sometimes one full one beside it); the only
## band that is told what a full punnet holds, and only when there is one.
func test_een_beurt_in_groep_3() -> void:
	for dag in [2, 3]:
		_op()
		_wereld(2, 3, dag)
		waar(Games.start(SPEL), "het spel start (dag %d)" % dag)
		var o := Beurt.opzet(2, 3, dag)
		var zin2 := _kaart_tekst("Kolom/Regel2")
		if int(o["vol"]) > 0:
			gelijk(zin2, Beurt.T_TEL2, "een vol bakje: de zin wat erin zit")
		else:
			gelijk(zin2, "", "alleen een open bakje: één zin")
		_kies(int(o["T"]))
		await _wacht_kaart()
		gelijk(_kaart_tekst("Kolom/Rij/Som"), "%d + __ = 10" % int(o["los"]), "splitsen tot 10")
		_kies(int(o["nodig"]))
		await _wacht_kaart()
		for i in int(o["nodig"]):
			_tik(PLUK)
		gelijk(_stand().get("stap", ""), "af", "het bakje is vol (dag %d)" % dag)
		_af()

## The help ladder (games-b.md §0.5): count along in a bubble on the table
## after a miss, and at the third miss the answer in pale numbers — the ghost
## tag on the table, and in the second question the ghost berries in the open
## punnet.  Never a cross, never a star less, the turn always goes on.
func test_de_hulpladder() -> void:
	_op()
	_wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	var o := Beurt.opzet(4, 4, 2)
	var mis := -1
	for k in _strook():
		if k != int(o["T"]):
			mis = k
			break
	for i in 3:
		_kies(mis)
		var hulp := _knoop(HULP)
		waar(hulp != null, "misser %d: het hulpwolkje staat er" % (i + 1))
		if hulp != null:
			waar((hulp as Button).text.contains(Beurt.hulp_tel(o)) or _wolk_tekst(hulp).contains(Beurt.hulp_tel(o)),
				"en telt per bakje mee")
		if i < 2:
			waar(_knoop(SPOOK) == null, "misser %d: nog geen spookgetal" % (i + 1))
		await _wacht_mispauze()
	waar(_knoop(SPOOK) != null, "de derde misser: het antwoord bleek op de tafel")
	gelijk((_knoop(SPOOK) as Label).text if _knoop(SPOOK) is Label else "", Beurt.spook_tel(o),
		"als tientallen en eenheden")
	_kies(int(o["T"]))
	await _wacht_kaart()
	waar(_knoop(SPOOK) == null, "goed: het spookgetal is weg")
	var mis2 := -1
	for k in _strook():
		if k != int(o["nodig"]):
			mis2 = k
			break
	for i in 3:
		_kies(mis2)
		await _wacht_mispauze()
	gelijk(int(_tafel()["params"]["spook"]), int(o["vol"]),
		"bij de aanvulvraag: bleke aardbeien in het open bakje")
	gelijk(int(_stand().get("missers", 0)), 6, "zes missers geteld, niets verloren")
	_kies(int(o["nodig"]))
	await _wacht_kaart()
	gelijk(int(_tafel()["params"]["spook"]), -1, "goed: de spookaardbeien zijn weg")
	gelijk(_stand().get("stap", ""), "pluk", "en de beurt gaat gewoon door")
	_af()

func _wolk_tekst(k: Control) -> String:
	var uit := ""
	for l in k.find_children("*", "Label", true, false):
		uit += (l as Label).text + " "
	return uit

## A reload in the middle of a turn picks up where the child was: the second
## question is still the second question, the picked berries are still there.
func test_herladen_hervat_de_beurt() -> void:
	_op()
	_wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	var o := Beurt.opzet(4, 4, 2)
	_kies(int(o["T"]))
	await _wacht_kaart()
	Games.stop()
	gelijk(_stand().get("stap", ""), "bij", "de stand is bewaard")
	waar(Games.start(SPEL), "opnieuw gestart")
	gelijk(_stand().get("stap", ""), "bij", "verder bij de tweede vraag")
	gelijk(_kaart_tekst("Kolom/Regel"), "🍓 " + Beurt.T_BIJ, "met dezelfde vraag")
	_kies(int(o["nodig"]))
	await _wacht_kaart()
	_tik(PLUK)
	Games.stop()
	waar(Games.start(SPEL), "en nog een keer")
	gelijk(int(_stand().get("geplukt", 0)), 1, "de geplukte aardbei ligt er nog")
	gelijk(str(_tafel()["params"]["b"]), str(Beurt.bakjes(o, 1)), "ook op de tafel")
	# the JSON way back: floats in the save are read as numbers
	var d := State.spel_data(SPEL)
	var st: Dictionary = d["stand"]
	st["geplukt"] = 1.0
	st["missers"] = 0.0
	Games.stop()
	waar(Games.start(SPEL), "na een JSON-ronde")
	gelijk(typeof(_stand()["geplukt"]), TYPE_INT, "geplukt is weer een geheel getal")
	# another day is another table
	Games.stop()
	State.s["dag"] = 3
	waar(Games.start(SPEL), "de volgende dag")
	gelijk(_stand().get("stap", ""), "tel", "begint opnieuw met tellen")
	_af()

## "Een methode om te wisselen met welk dier je de spellen speelt" (owner,
## 2026-09-23, world.md §5.8): every guest with a bed may pick, in check-in
## order; the animal on the game bar hands the table to the next one in a
## fresh turn — nothing is taken away — and the next start picks with the
## animal the child chose.
func test_het_kind_kiest_wie_er_plukt() -> void:
	_op()
	var gasten := _wereld(4, 4)
	var ids: Array[String] = []
	for g in gasten:
		ids.append(str(g["id"]))
	waar(Games.start(SPEL), "het spel start")
	gelijk(str(Games.spelers()), str(ids), "wie mag plukken: iedereen met een bed, op volgorde")
	gelijk(Games.speler(), str(_stand().get("gast", "")), "de balk weet wie er plukt")
	var o := Beurt.opzet(4, 4, 2)
	_kies(int(o["T"]))
	await _wacht_kaart()
	gelijk(_stand().get("stap", ""), "bij", "de telvraag is af")
	var sterren := int(State.s["sterren"])
	var volgende := Games.volgende_speler()
	waar(not volgende.is_empty() and volgende != Games.speler(), "er is een ander dier")
	waar(Games.wissel_speler(), "het dier op de balk geeft de beurt door")
	gelijk(Games.actief(), SPEL, "het plukken gaat door")
	gelijk(Games.speler(), volgende, "met het volgende dier")
	gelijk(str(_stand().get("gast", "")), volgende, "in een eigen beurt")
	gelijk(_stand().get("stap", ""), "tel", "die weer bij het tellen begint")
	gelijk(int(State.s["sterren"]), sterren, "er ging geen ster af")
	Games.stop()
	waar(Games.start(SPEL), "het spel start opnieuw")
	gelijk(Games.speler(), volgende, "met het gekozen dier")
	_af()

## Nobody in a bed yet: the game says so on the planter and closes itself.
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

## The resting table stands while nobody plays; the entry hangs ON it; a turn
## takes it away and puts its own table there; after the turn it is back.
func test_de_rustende_tafel() -> void:
	_op()
	_wereld(3, 3)
	Games.hersteek()
	var rust := World.decor_plek(RUST, KAMER)
	waar(not rust.is_empty(), "de pluktafel staat in de kas als er niet gespeeld wordt")
	gelijk(float(rust.get("x", 0)), float(Spel.TAFEL_X), "op de plek van de tafel")
	waar(Games.start(SPEL), "het spel start")
	waar(World.decor_plek(RUST, KAMER).is_empty(), "het rustspul gaat weg")
	waar(not _tafel().is_empty(), "de eigen tafel staat er")
	Games.stop()
	waar(_tafel().is_empty(), "na het spel is de eigen tafel weg")
	waar(not World.decor_plek(RUST, KAMER).is_empty(), "en staat de rustende tafel er weer")
	# the floor under it is kept free: no wander place, no bought plant
	var r := Rooms.get_kamer(KAMER)
	for p in r.plekken:
		waar(not (p[0] >= 16 and p[0] <= 44 and p[1] >= 19 and p[1] <= 57),
			"geen loopplek op de pluktafel (%s)" % str(p))
	waar(not Rooms.vrij_vak(KAMER, float(Spel.TAFEL_X), float(Spel.TAFEL_Z)),
		"er kan geen meubel op de pluktafel")
	_af()

# ------------------------------------------------------- op vier schermen

## The real shell on the four ticket screens, every step of a turn: every
## button of the game is a real tap target inside the frame, covers nothing,
## found a real place (never `krap`), and the pick button and the help bubble
## hang AT their thing (owner, 2026-09-23: labels floating where they don't
## belong).
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
		_keur(kader.size, "%s tel" % str(maat))
		# Both questions dock in the maths bar (not on the landscape phone: a
		# third of its 289 high frame is lower than any card with a sum line).
		var dok: bool = maat.y >= 400
		if dok:
			gelijk(Ui.balk_kaart(), KAART, "%s: de telvraag staat in de rekenbalk" % str(maat))
		_kies(_fout_getal(int(o["T"])))
		for _f in 3:
			await boom.process_frame
		_keur(kader.size, "%s misser" % str(maat))
		if minf(kader.size.x, kader.size.y) >= 400.0:
			_bij_zijn_ding(HULP, "%s: het hulpwolkje" % str(maat))
		else:
			waar(_knoop(HULP) == null, "%s: op de telefoon geen hulpwolkje" % str(maat))
			waar(_kaart_tekst("Kolom/Hulp").contains(" en nog "),
				"%s: maar de hulpregel op de kaart (%s)" % [str(maat), _kaart_tekst("Kolom/Hulp")])
		await _wacht_mispauze()
		_kies(int(o["T"]))
		await _wacht_kaart()
		if dok:
			gelijk(Ui.balk_kaart(), KAART, "%s: de bijvraag staat in de rekenbalk" % str(maat))
		_kies(int(o["nodig"]))
		await _wacht_kaart()
		for _f in 3:
			await boom.process_frame
		_keur(kader.size, "%s pluk" % str(maat))
		_bij_zijn_ding(PLUK, "%s: de plukknop" % str(maat))
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

## Groep 5 on the phone: the question to a hundred docks in the maths bar too
## ("Hoeveel nog tot 100 aardbeien?" was one line too wide for it, and the card
## floated over the room while the first one stood in the bar).
func test_groep_5_op_de_telefoon() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var scherm_terug = Ui.get("_scherm")
	var rust_voor := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	var boom := Engine.get_main_loop() as SceneTree
	var vp := SubViewport.new()
	vp.size = Vector2i(360, 740)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	boom.root.add_child(vp)
	var shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	shell.set_meta("geen_start", true)
	vp.add_child(shell)
	for _f in 4:
		await boom.process_frame
	_wereld(8, 5)
	Hotel.start()
	for _f in 4:
		await boom.process_frame
	waar(Games.start(SPEL), "het spel start")
	for _f in 4:
		await boom.process_frame
	var o := Beurt.opzet(8, 5, 2)
	gelijk(Ui.balk_kaart(), KAART, "de telvraag staat in de rekenbalk")
	_kies(int(o["T"]))
	await _wacht_kaart()
	gelijk(_kaart_tekst("Kolom/Regel"), "🍓 " + Beurt.T_HONDERD, "de vraag tot 100")
	gelijk(Ui.balk_kaart(), KAART, "en die staat ook in de rekenbalk")
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

## Every spot of the game: inside the frame, never `krap`, a tap target, and
## no button on an object (a card and a number may lie over the world).
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
		# The one exception: `Ui`'s own miss bubble (S5, "🔄 Nog een keer", 1.2 s)
		# on the landscape phone.  There the maths bar lets go (B3), and the
		# floating card with its help line, its strip and that bubble share the
		# five bands of a 289 unit frame; the bubble touches the end of the strip
		# for the length of the pause.  Every element of the game itself still
		# finds a real place there.
		var s5_laag := str(id).begins_with(Ui.MIS_WOLK) and kader.y < 300.0
		waar(not bool(d["krap"]) or s5_laag, "%s: %s vond een echte plek" % [wat, id])
		waar(r.position.x >= -0.01 and r.position.y >= -0.01
			and r.end.x <= kader.x + 0.01 and r.end.y <= kader.y + 0.01,
			"%s: %s staat binnen het kader (%s)" % [wat, id, str(r)])
		if spot.kind == "tag" or int(d["laag"]) == Hits.Laag.VAST:
			continue
		# a button that belongs to a BIG thing may stand on it (`op: aan`,
		# world.md §5.4 — the pick button on the planter); anything else
		# covers nothing of its own thing
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

## A button that belongs to a thing touches that thing (on a phone at most one
## band away, like test_hits holds every room to).
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
