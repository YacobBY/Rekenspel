extends Proef
## HET SLEUTELBORD — de speeltest (games-a.md §4, architecture.md §12.2).
##
## Alles wordt door de ctx heen gespeeld: een sleutel wordt op een haakje
## gehangen door op de knop te tikken of hem erop te slepen, precies zoals een
## kind dat doet.  Geen enkele test roept een interne functie van het spel aan;
## de stand wordt uit `State.spel_data("sleutels")` gelezen, want dat IS
## `ctx.data()`.

const ID := "sleutels"
const BRON := "res://games/sleutels/spel.gd"

## De vier kaders van de opdracht, en de vier schermen waar ze bij horen.
const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740),
	Vector2i(740, 360)]
## De opstelling die elk van die vier schermen hoort te kiezen, gemeten op de
## echte schil.  Drift hierin is een echte verandering, geen detail.
const MODUS := {"(1024, 768)": "gewoon", "(768, 1024)": "stapel",
	"(360, 740)": "stapel", "(740, 360)": "naast"}

var _laag: Control = null
var _bewaard: Dictionary = {}

# ------------------------------------------------------------------ gereedschap

func _op(kader := Vector2(990, 637)) -> void:
	_bewaard = State.s.duplicate(true)
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = kader
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	World.meet(Rect2(Vector2.ZERO, kader))
	World.naar("receptie")


func _af() -> void:
	if Games.actief() != "":
		Games.stop()
	Ui.naamplaten_leeg()
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	if _laag != null:
		_laag.queue_free()
		_laag = null
	if not _bewaard.is_empty():
		State.s = _bewaard
		_bewaard = {}


## `n` gasten uit de pool; de eerste vier krijgen een echt bed van het hotel.
## `kunnen` bepaalt samen met `n` de band (`max(3, min(bandVanN(n), kunnen+1))`).
func _wereld(n: int, kunnen: int, dag := 1) -> Array:
	State.nieuw_spel()
	State.start_gekozen()
	State.s["dag"] = dag
	State.s["kunnen"] = kunnen
	State.s["taken"] = []
	var pool := State.gasten_pool()
	var bedden := State.alle_bedden()
	var uit: Array = []
	for i in n:
		var g: Dictionary = pool[i % pool.size()]
		g["id"] = "%s_%d" % [str(g["id"]), i] if i >= pool.size() else str(g["id"])
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
	State.s["band"] = State.band()
	Hotel.herstel_wereld()
	World.naar("receptie")
	return uit


func _bord() -> Dictionary:
	var d := State.spel_data(ID)
	var b = d.get("bord", null)
	return b if typeof(b) == TYPE_DICTIONARY else {}


## Het spel dat NU draait.  `Games` maakt zijn knoop vrij met `queue_free()`, dus
## de knoop van een vorige test hangt er nog tot het einde van het beeld; alleen
## de draaiende heeft `actief`.
func _spel() -> Node:
	for k in Games.get_children():
		if k.has_method("debug") and bool(k.get("actief")):
			return k
	return null


## De sleutel op haakje `i` hangen — slepen of tikken, allebei de weg van een kind.
func _hang(i: int, slepen := true) -> void:
	var s := Hits.spot("sl_h%d" % i)
	if s == null:
		fout("haakje %d staat er niet" % i)
		return
	if slepen and s.vangvlak != null:
		var lading := {"sleep": "haak", "bron": "sl_key"}
		waar(s.vangvlak._can_drop_data(Vector2.ZERO, lading),
			"haakje %d neemt een sleutel aan" % i)
		s.vangvlak._drop_data(Vector2.ZERO, lading)
		return
	var knop := s.knoop as BaseButton
	if knop == null:
		fout("haakje %d is geen knop" % i)
		return
	knop.emit_signal("pressed")


## Een haakje dat NIET van deze sleutel is, om de misser mee te maken.  Een
## ander LEEG haakje gaat voor: dan staat er een `?` in het getallenlijntje,
## precies het voorbeeld van games-a.md §4.6 (`10 … ? … 20`).
func _fout_haakje(p: Dictionary, behalve: Array[int]) -> int:
	var nu := int(p.get("nu", 0))
	var s: Dictionary = (p["sleutels"] as Array)[nu]
	var b: Dictionary = (p["borden"] as Array)[int(s["bord"])]
	var haken: Array = b["haken"]
	for leeg in [true, false]:
		for i in haken.size():
			if i == int(s["haak"]) or behalve.has(i):
				continue
			if bool((haken[i] as Dictionary).get("blanco", false)) == leeg:
				return i
	return -1

# ------------------------------------------------------------- 1. aanmelding

## De mapnaam IS het id; de definitie staat woordelijk in games-a.md §1.1 en
## architecture.md §12.2.
func test_aanmelding_en_definitie() -> void:
	waar(Games.lijst().has(ID), "de mapscan vindt sleutels")
	var def := Games.definitie(ID)
	gelijk(str(def.get("naam", "")), "Het sleutelbord", "naam")
	gelijk(str(def.get("kamer", "")), "receptie", "kamer")
	var hs: Dictionary = def.get("hotspot", {})
	gelijk(str(hs.get("obj", "")), "sleutelbordz", "de knop hangt aan het sleutelbord")
	gelijk(str(hs.get("icoon", "")), "🔑", "pictogram")
	gelijk(str(hs.get("label", "")), "Sleutels", "en het woord erbij (HOTEL.md §9)")
	gelijk(int(hs.get("hoog", 0)), 13, "hoogte 13")
	gelijk(int(hs.get("dz", 0)), 6, "dz 6")
	var taak: Dictionary = def.get("taak", {})
	gelijk(str(taak.get("id", "")), "sleutels", "taak-id")
	gelijk(str(taak.get("icoon", "")), "🔑", "taakpictogram")
	gelijk(str(taak.get("tekst", "")), "Hang de sleutels op", "taaktekst, woordelijk")
	gelijk(int(taak.get("prio", 0)), 5, "prio 5, een gewoon klusje")
	waar(Ui.keur_taak("sleutels", str(taak.get("tekst", ""))), "≤ 6 woorden")


## `unlock`: N >= 2, en het prikbordkaartje verschijnt bij dezelfde grens.
func test_ontgrendeling_bij_twee_gasten() -> void:
	_op()
	_wereld(1, 3)
	waar(not Games.ontgrendeld(ID), "met één gast is er niets op te hangen")
	_wereld(2, 3)
	waar(Games.ontgrendeld(ID), "vanaf twee gasten mag het")
	var def := Games.definitie(ID)
	var wanneer = (def.get("taak", {}) as Dictionary).get("wanneer", null)
	waar(wanneer is Callable and bool((wanneer as Callable).call(State.s)),
		"en dan staat het kaartje op het bord")
	_af()

# ---------------------------------------------------------- 2. kinderteksten

## games-a.md §4.6: elke kindertekst woordelijk, met het echte U+2026 en de
## spatie eromheen.  Zowel in de bron als op het scherm.
func test_alle_teksten_staan_er_woordelijk() -> void:
	var f := FileAccess.open(BRON, FileAccess.READ)
	waar(f != null, "de bron is te lezen")
	if f == null:
		return
	var bron := f.get_as_text()
	f.close()
	for zin in ["Het sleutelbord", "Sleutels", "Hang de sleutels op", "nog geen gasten",
			"Welk nummer hoort in het gat?", "Welk kamernummer hoort in het gat?",
			"De rij is nu af", "hang mij op", "kijk bij de buren", "leeg haakje",
			"hier hoort ", "de sleutel van ", "nummer %d", "kamer %d",
			"buurvrouw Els doet het voor", "naar mijn kamer", "alle sleutels hangen",
			"om en om", "+ %d", " … ", " · ", " en ", "slaapt hier: ", "💡 "]:
		waar(bron.contains(zin), 'de tekst "%s" staat woordelijk in de bron' % zin)
	waar(bron.contains("…"), "het echte beletselteken U+2026, geen drie punten")


## F4: de verplichte zin van de sommenkaart, ≤ 8 woorden en ≤ 40 tekens.
func test_de_zinnen_passen_in_het_budget() -> void:
	for zin in ["Welk nummer hoort in het gat?", "Welk kamernummer hoort in het gat?",
			"De rij is nu af"]:
		waar(Ui.keur_regel("proef", zin), '"%s" past in het budget' % zin)


## `rijTekst` en het buurlijntje, precies zoals ze op de kaart komen te staan.
func test_rijtekst_en_burenlijn() -> void:
	_op()
	_wereld(5, 3, 3)
	waar(Games.start(ID), "het spel start")
	var p := _bord()
	gelijk(str(p.get("variant", "")), "sprong5", "N 5, band 4, dag 3 -> sprong5")
	var spel := _spel()
	waar(spel != null, "het spel hangt in de boom")
	if spel != null:
		gelijk(str(spel.debug()["rij_tekst"]), "5, __, 15, __, 25",
			"de rij zoals je hem in je schrift schrijft")
	# een misser zet het getallenlijntje in het antwoordvakje
	var i := _fout_haakje(p, [])
	_hang(i)
	if spel != null:
		var lijn := str(spel.debug()["buren_tekst"])
		waar(lijn.contains(" … "), "het buurlijntje staat er: %s" % lijn)
		waar(lijn.split(" … ").size() == 3, "met de twee buren en het gat: %s" % lijn)
		waar(lijn.contains("?"), "en het gat staat er als ?: %s" % lijn)
	_af()

# ------------------------------------------------------------- 3. de beurt

## Eén hele beurt op band 3, 4 en 5: de opdracht klopt, elke sleutel hangt op
## precies één haakje, en er komt precies één ster bij — voor het meedoen.
func test_een_hele_beurt_op_elke_band() -> void:
	for geval in [{"n": 2, "kunnen": 3, "band": 3}, {"n": 5, "kunnen": 3, "band": 4},
			{"n": 7, "kunnen": 4, "band": 5}]:
		_op()
		_wereld(int(geval["n"]), int(geval["kunnen"]))
		gelijk(State.band(), int(geval["band"]), "band bij N %d" % int(geval["n"]))
		waar(Games.start(ID), "het spel start op band %d" % int(geval["band"]))
		var p := _bord()
		waar(not p.is_empty(), "er is een opdracht")
		gelijk(str(Sommen.Sleutels.controleer(p)["fout"]), "[]",
			"de opdracht rekent na op band %d" % int(geval["band"]))
		gelijk(int(p.get("band", 0)), int(geval["band"]), "de opdracht draagt de band")
		var sleutels: Array = p["sleutels"]
		waar(sleutels.size() >= 1, "er is minstens één sleutel")
		var sterren := int(State.s["sterren"])
		for beurt in sleutels.size():
			var s: Dictionary = sleutels[int(p["nu"])]
			waar(Hits.spot("sl_key") != null, "de sleutel ligt bij zijn poot")
			_hang(int(s["haak"]), beurt % 2 == 0)
			waar(bool(s["op"]), "sleutel %d hangt" % int(s["nummer"]))
			var g := State.gast_van(str(s["gast"]))
			gelijk(str(g.get("waar", "")), str(g.get("kamer", "")),
				"%s ging naar zijn eigen kamer" % str(s["naam"]))
		gelijk(int(p["nu"]), sleutels.size(), "alle sleutels zijn geweest")
		waar(bool(p["klaar"]), "de ronde staat als klaar in ctx.data()")
		gelijk(int(State.s["sterren"]), sterren + 1, "precies één ster, voor het meedoen")
		gelijk(int(p["missers"]), 0, "zonder missers gespeeld")
		gelijk(World.kamer_nu(), "gang", "de finale hangt in de gang")
		# de deurplaatjes: één per kamer met opgehangen sleutels
		var platen := 0
		for id in Hits.lijst():
			if id.begins_with("sl_deur_"):
				platen += 1
		waar(platen >= 1, "er hangt een 💡-plaatje boven een deur")
		Games.stop()
		_af()


## De taak wordt afgevinkt op de naam én op de spel-id (world.md §5.3).
func test_taak_wordt_afgevinkt() -> void:
	alleen_spellen(["sleutels"])      # three chips fit; with ten games the chip rotates by day
	_op()
	# elk bed bezet, anders neemt het prio-0 kaartje "nog een bed vrij" de plek
	# van het klusje op het bord in (er passen er maar drie)
	_wereld(State.alle_bedden().size(), 3)
	Hotel.bouw_taken(true)
	var staat := false
	for q in State.s["taken"]:
		if str((q as Dictionary).get("id", "")) == "sleutels":
			staat = true
	waar(staat, "het kaartje staat op het prikbord")
	waar(Games.start(ID), "het spel start")
	var p := _bord()
	for beurt in (p["sleutels"] as Array).size():
		var s: Dictionary = (p["sleutels"] as Array)[int(p["nu"])]
		_hang(int(s["haak"]))
	var af := false
	for q in State.s["taken"]:
		if str((q as Dictionary).get("id", "")) == "sleutels" \
				and bool((q as Dictionary).get("klaar", false)):
			af = true
	waar(af, "het kaartje op het prikbord staat afgevinkt")
	_af()

# --------------------------------------------------- 4. missen zonder straf

## Een misser kost niets: geen ster, geen munt, geen beurt.  De twee buren
## lichten op, het getallenlijntje komt in het antwoordvakje, en pas na twee
## missers staat buurvrouw Els er — daarna legt ze de spookcijfers neer.
func test_misser_helpt_en_straft_nooit() -> void:
	_op()
	_wereld(5, 3)
	waar(Games.start(ID), "het spel start")
	var p := _bord()
	var spel := _spel()
	var sterren := int(State.s["sterren"])
	var munten := int(State.s["munten"])
	var eerste := _fout_haakje(p, [])
	_hang(eerste)
	gelijk(int(p["missers"]), 1, "de misser is geteld")
	gelijk(int(State.s["sterren"]), sterren, "een misser kost geen ster (F5)")
	gelijk(int(State.s["munten"]), munten, "en geen munt")
	gelijk(int(p["nu"]), 0, "en de beurt blijft van dezelfde gast")
	waar(Hits.spot("sl_els") == null, "na één misser staat Els er nog niet")
	if spel != null:
		var d: Dictionary = spel.debug()
		gelijk((d["buren"] as Array).size(), 2, "twee buren lichten op")
		var lijn := str(d["buren_tekst"])
		gelijk(lijn.split(" … ").size(), 3,
			"de buren en het gat staan op volgorde met ' … ' ertussen: %s" % lijn)
		# een `?` komt er alleen als het haakje waarop gemikt werd zelf leeg is
		var haken: Array = ((p["borden"] as Array)[0] as Dictionary)["haken"]
		if bool((haken[eerste] as Dictionary).get("blanco", false)):
			waar(lijn.contains("?"), "een leeg haakje staat als ? in het lijntje: %s" % lijn)
	# het wolkje van de gast wijst naar de buren
	var wolk := Hits.spot("sl_tag")
	waar(wolk != null and is_instance_valid(wolk.knoop)
		and (wolk.knoop as Control).tooltip_text.contains("kijk bij de buren"),
		"de gast zegt: kijk bij de buren")
	# tweede misser: Els komt erbij, en ze blijft daarna staan
	var tweede := _fout_haakje(p, [eerste])
	if tweede >= 0:
		_hang(tweede)
	else:
		_hang(eerste)
	gelijk(int(p["missers"]), 2, "twee missers")
	var els := Hits.spot("sl_els")
	waar(els != null, "na twee missers staat Els er")
	if els != null and is_instance_valid(els.knoop):
		gelijk((els.knoop as Control).tooltip_text, "buurvrouw Els doet het voor",
			"met haar eigen tekst")
		(els.knoop as BaseButton).emit_signal("pressed")
	waar(State.gezien("sleutels_els"), "de uitleg is gezien")
	if spel != null:
		var d2: Dictionary = spel.debug()
		waar(bool(d2["spook"]), "Els legt de spookcijfers neer")
		var tip := str(d2["tip"])
		waar(tip == "om en om" or tip.begins_with("+ "),
			'de hulpregel is "om en om" of "+ <stap>", nu: %s' % tip)
	# het goede haakje draagt nu het goede getal als spookcijfer
	var s: Dictionary = (p["sleutels"] as Array)[int(p["nu"])]
	var haak := Hits.spot("sl_h%d" % int(s["haak"]))
	waar(haak != null and is_instance_valid(haak.knoop)
		and (haak.knoop as Button).text.contains(str(int(s["nummer"]))),
		"het goede getal staat als spookcijfer op het lege haakje")
	waar(haak != null and (haak.knoop as Control).tooltip_text
		== "hier hoort %d" % int(s["nummer"]), "en de titel zegt waar het hoort")
	# en daarna telt de ster gewoon: meedoen is genoeg
	for beurt in (p["sleutels"] as Array).size():
		var q: Dictionary = (p["sleutels"] as Array)[int(p["nu"])]
		_hang(int(q["haak"]))
	gelijk(int(State.s["sterren"]), sterren + 1, "de ster komt er ondanks de missers")
	_af()


## Een sleutel op een bezet haakje is ook een misser, nooit een straf.
func test_bezet_haakje_is_een_misser() -> void:
	_op()
	_wereld(5, 3)
	Games.start(ID)
	var p := _bord()
	if (p["sleutels"] as Array).size() < 2:
		_af()
		return
	var eerste: Dictionary = (p["sleutels"] as Array)[0]
	_hang(int(eerste["haak"]))
	var missers := int(p["missers"])
	_hang(int(eerste["haak"]))          # het haakje is nu bezet
	gelijk(int(p["missers"]), missers + 1, "op een bezet haakje is een misser")
	gelijk(int(p["nu"]), 1, "en de beurt blijft staan waar hij stond")
	_af()

# ------------------------------------------------------- 5. herstel en stop

## De beurt overleeft een herlaad: de stand staat in `ctx.data()` en die gaat
## door de savegame heen (dus ook door JSON, waar een int een float wordt).
func test_beurt_overleeft_een_herlaad() -> void:
	_op()
	_wereld(5, 3)
	Games.start(ID)
	var p := _bord()
	var sig := str(p["sig"])
	var eerste: Dictionary = (p["sleutels"] as Array)[0]
	_hang(int(eerste["haak"]))
	var nu := int(_bord()["nu"])
	waar(nu >= 1, "er hangt een sleutel")
	Games.stop()
	# de herlaad: de savegame gaat door JSON en komt terug
	var doc = JSON.parse_string(JSON.stringify(State.s))
	waar(typeof(doc) == TYPE_DICTIONARY, "de savegame overleeft JSON")
	if typeof(doc) == TYPE_DICTIONARY:
		State.s = doc
	Hotel.herstel_wereld()
	World.naar("receptie")
	Games.start(ID)
	var q := _bord()
	gelijk(str(q["sig"]), sig, "dezelfde opdracht")
	gelijk(int(q["nu"]), nu, "en de beurt hervat precies waar hij was")
	var eerste2: Dictionary = (q["sleutels"] as Array)[0]
	waar(bool(eerste2["op"]), "de opgehangen sleutel hangt er nog")
	_af()


## Een verse dag geeft een verse opdracht (de handtekening klopt niet meer).
func test_nieuwe_dag_geeft_nieuwe_opdracht() -> void:
	_op()
	_wereld(5, 3, 3)
	Games.start(ID)
	var sig := str(_bord()["sig"])
	var rij := str((_spel() as Node).debug()["rij_tekst"])
	Games.stop()
	State.s["dag"] = 4
	Games.start(ID)
	waar(str(_bord()["sig"]) != sig, "een nieuwe dag geeft een nieuwe handtekening")
	waar(str((_spel() as Node).debug()["rij_tekst"]) != rij, "en een andere rij")
	_af()


## `stop()` laat de wereld schoon achter: geen knop, geen decor, en wie nog met
## zijn sleutellabel aan de balie stond ligt weer in zijn eigen bed.
func test_stop_laat_de_wereld_schoon_achter() -> void:
	_op()
	_wereld(5, 3)
	# eigenaar "keurmeester": alles behalve "hotel", want `Hotel.render()` bouwt
	# zijn eigen knoppen tijdens het starten terecht opnieuw op
	Hits.maak({"id": "hotelknop", "kamer": "receptie", "x": 8.0, "z": 8.0, "y": 10.0,
		"icoon": "🔔", "label": "Bel", "door": "keurmeester",
		"aan": func(_s) -> void: pass})
	Games.start(ID)
	var eigen := 0
	for id in Hits.lijst():
		if Hits.spot(id).door == ID:
			eigen += 1
	waar(eigen >= 3, "het spel plaatste zijn eigen knoppen (%d)" % eigen)
	Games.stop()
	for id in Hits.lijst():
		waar(Hits.spot(id).door != ID, "geen knop van het spel bleef staan: %s" % id)
	waar(Hits.spot("hotelknop") != null, "de knop van het hotel bleef wel staan")
	gelijk(World.decor_lijst().filter(func(d): return str(d.get("door", "")) == ID).size(), 0,
		"en geen los decor")
	for g in State.s["gasten"]:
		var gast: Dictionary = g
		if not str(gast.get("bed", "")).is_empty():
			gelijk(str(gast.get("waar", "")), str(gast.get("kamer", "")),
				"%s ligt weer in zijn eigen kamer" % str(gast.get("naam", "")))
	_af()


## Geen enkele gast heeft een bed: één wolkje, geen dood scherm.
func test_zonder_bedden_zegt_het_spel_het_zelf() -> void:
	_op()
	_wereld(2, 3)
	for g in State.s["gasten"]:
		(g as Dictionary)["bed"] = ""
		(g as Dictionary)["kamer"] = ""
	Games.start(ID)
	var wolk := Hits.spot("sl_leeg")
	waar(wolk != null, "er hangt een wolkje aan het sleutelbord")
	if wolk != null and is_instance_valid(wolk.knoop):
		var tekst := (wolk.knoop as Control).tooltip_text
		waar(tekst.contains("nog geen gasten") and tekst.contains("🛏"),
			'het wolkje zegt "🛏 nog geen gasten", nu: %s' % tekst)
	waar(_bord().is_empty(), "en er is geen opdracht gemaakt")
	_af()

# ------------------------------------------------- 6. de vier opstellingen

## `opbouw()` koos in de HTML uit vier opstellingen ná een DOM-meting; hier
## kiest hij ze vóór de eerste tekenbeurt, uit de kadermaat en de gemeten
## Controlmaat van de kaart.  Elke opstelling is bereikbaar, en op een kader dat
## te smal is voor vijf tikdoelen naast elkaar gaat de rij op twee regels verder
## in plaats van dat er één plaatje uit de rij wordt getild.
func test_de_vier_opstellingen() -> void:
	var gezien := {}
	for kader in [Vector2(990, 637), Vector2(734, 788), Vector2(326, 558),
			Vector2(558, 322), Vector2(236, 236)]:
		_op(kader)
		_wereld(5, 3)
		Games.start(ID)
		var spel := _spel()
		waar(spel != null, "het spel draait bij kader %s" % str(kader))
		if spel != null:
			var lay: Dictionary = spel.debug()["opbouw"]
			var modus := str(lay.get("modus", ""))
			waar(["gewoon", "stapel", "naast", "krap"].has(modus),
				"kader %s koos een opstelling: %s" % [str(kader), modus])
			gezien[modus] = 1
			var per_regel := int(lay.get("per_regel", 0))
			var regels := int(lay.get("regels", 0))
			waar(per_regel >= 1 and regels >= 1,
				"kader %s deelt de rij in (%d per regel, %d regels)"
					% [str(kader), per_regel, regels])
			if kader.x < 250.0:
				waar(regels >= 2, "op een heel smal kader gaat de rij op twee regels")
			else:
				gelijk(regels, 1, "kader %s houdt de rij op één regel" % str(kader))
		Games.stop()
		_af()
	for modus in ["stapel", "naast", "krap"]:
		waar(gezien.has(modus), "de opstelling %s is een keer gekozen" % modus)


## De rij zelf: elk plaatje is een tikdoel, ze staan waterpas en op volgorde,
## niet op elkaar, en geen enkel plaatje is aan een meubelstuk blijven plakken.
func _keur_rij(kader: Vector2, regels: int, per_regel: int) -> void:
	var dbg := Hits.debug()
	var vorige := -INF
	var vorige_y := -INF
	var n := 0
	for i in 8:
		var id := "sl_h%d" % i
		if not dbg.has(id):
			continue
		var d: Dictionary = dbg[id]
		var r: Rect2 = d["rect"]
		waar(r.size.x >= 44.0 and r.size.y >= 44.0,
			"%s: %s is een tikdoel (%s)" % [str(kader), id, str(r.size)])
		waar(r.position.x >= 0.0 and r.position.y >= 0.0
			and r.end.x <= kader.x + 0.01 and r.end.y <= kader.y + 0.01,
			"%s: %s staat in het kader" % [str(kader), id])
		waar(not bool(d["krap"]), "%s: %s vond een echte plek" % [str(kader), id])
		var vlak: Rect2 = d["vlak"]
		gelijk(maxf(0.0, vlak.size.x * vlak.size.y), 0.0,
			"%s: %s plakt niet aan een meubelstuk" % [str(kader), id])
		if per_regel > 0 and n % per_regel == 0:
			vorige = -INF          # nieuwe regel: weer van links af
		else:
			gelijk(r.position.y, vorige_y, "%s: %s staat waterpas" % [str(kader), id])
		waar(r.position.x > vorige, "%s: %s staat rechts van zijn buurman" % [str(kader), id])
		vorige = r.position.x
		vorige_y = r.position.y
		n += 1
	waar(n >= 4, "%s: de hele rij staat er (%d plaatjes)" % [str(kader), n])
	waar(regels >= 1, "%s: de rij heeft regels" % str(kader))

# ----------------------------------------------- 7. dekking in vier kaders

## De echte receptie in de echte schil, op de vier schermen van de opdracht:
## geen enkele knop van dit spel staat op een voorwerp — niet op zijn eigen en
## niet op dat van een ander (architecture.md §4.3, §12.2).
func test_dekking_is_nul_op_vier_schermen() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	# De schil vertelt `Ui` de CSS-maat van het HELE scherm, en daar hangt de
	# 44/48 px tikregel aan.  Een test die een schil bouwt laat die maat staan,
	# en `res://games/...` draait vóór `res://tests/...` — dus zonder dit
	# teruggeven meet `tests/test_hits.gd` zijn cijferpad op ons laatste scherm.
	var scherm_terug = Ui.get("_scherm")
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
		_wereld(5, 3)
		Hotel.start()
		for _f in 4:
			await boom.process_frame
		waar(Games.start(ID), "%s: het spel start" % str(maat))
		for _f in 4:
			await boom.process_frame
		var kader: Control = shell.get_node("Scherm/Kolom/Middenrij/Kaderdoos/Kader")
		var dbg := Hits.debug()
		var vakken: Array[Rect2] = []
		for id in dbg.keys():
			var v: Rect2 = dbg[id]["vlak"]
			if v.size.x > 0.0 and v.size.y > 0.0:
				vakken.append(v)
		var eigen := 0
		for id in dbg.keys():
			var spot := Hits.spot(id)
			if spot == null or spot.door != ID:
				continue
			eigen += 1
			var d: Dictionary = dbg[id]
			var r: Rect2 = d["rect"]
			gelijk(Hits.dekking(id), 0.0, "%s: %s dekt zijn voorwerp niet" % [str(maat), id])
			waar(not bool(d["krap"]), "%s: %s vond een echte plek" % [str(maat), id])
			waar(r.position.x >= -0.01 and r.position.y >= -0.01
				and r.end.x <= kader.size.x + 0.01 and r.end.y <= kader.size.y + 0.01,
				"%s: %s staat binnen het kader" % [str(maat), id])
			if spot.kind == "tag" or int(d["laag"]) == Hits.Laag.VAST:
				continue          # een kaart en een cijfer mogen over de wereld
			waar(r.size.x >= 44.0 and r.size.y >= 44.0,
				"%s: %s is een tikdoel" % [str(maat), id])
			for v in vakken:
				var snij := r.intersection(v)
				gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
					"%s: %s staat op een voorwerp" % [str(maat), id])
		waar(eigen >= 5, "%s: het spel staat echt op het scherm (%d knoppen)"
			% [str(maat), eigen])
		# de rij zelf, op de echte camera: waterpas, op volgorde, los van alles
		var spel := _spel()
		var modus := ""
		if spel != null:
			var lay: Dictionary = spel.debug()["opbouw"]
			modus = str(lay.get("modus", ""))
			_keur_rij(kader.size, int(lay.get("regels", 1)), int(lay.get("per_regel", 0)))
			gelijk(modus, str(MODUS.get(str(maat), modus)),
				"%s kiest de verwachte opstelling" % str(maat))
		print("[probe] sleutels dekking scherm=", maat, " knoppen=", eigen,
			" kader=", kader.size, " opbouw=", modus)
		Games.stop()
		Ui.naamplaten_leeg()
		Hits.wis_alles()
		vp.queue_free()
		await boom.process_frame
		Ui.registreer_lagen(null, null, null)
	State.s = bewaard
	Ui.set("_scherm", scherm_terug)
