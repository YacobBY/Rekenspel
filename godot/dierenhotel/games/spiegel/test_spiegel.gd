extends Proef
## spiegel — Spiegelmaskers in de speelzaal (PLAN.md §3.7.2, M3 + M4), headless.
##
## Driven the way a child drives it: an answer is a `pressed` on a button of
## the real strip — a number for the sum, a colour for every dot.  Only the
## pure turn logic in `beurt.gd` is called directly.

const SPEL := "spiegel"
const KAMER := "speelzaal"
const KAART := "sp_som"
const STROOK := "sp_som_keuzes"
const MOOI := "sp_mooi"
const LEEG := "sp_leeg"
const EZEL := "sp_ezel"
const RUST := "rust_sp_ezel"
const Beurt := preload("res://games/spiegel/beurt.gd")
const Modellen := preload("res://games/spiegel/modellen.gd")
const Spel := preload("res://games/spiegel/spel.gd")

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

## `n` guests from the pool, the first ones in a real bed; `kunnen` lifts the
## adaptive cap so the band really is the band the test asks for.
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

## One number on the real strip under the sum card.
func _kies(getal: int) -> bool:
	return _druk("Kn%d" % getal)

## One colour on the real strip under a dot card.
func _kleur(kleur: String) -> bool:
	return _druk("K" + kleur)

func _druk(naam: String) -> bool:
	var strook := _knoop(STROOK)
	if strook == null:
		fout("er is geen antwoordstrook")
		return false
	var k := strook.get_node_or_null("Rij/" + naam)
	if k == null:
		fout("%s staat niet op de strook" % naam)
		return false
	(k as BaseButton).pressed.emit()
	return true

## The names of the buttons on the strip, in order.
func _strook() -> Array[String]:
	var uit: Array[String] = []
	var strook := _knoop(STROOK)
	var rij := strook.get_node_or_null("Rij") if strook != null else null
	if rij == null:
		return uit
	for k in rij.get_children():
		uit.append(str(k.name))
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

func _ezel() -> Dictionary:
	return World.decor_plek(EZEL, KAMER)

func _wacht(s: float) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	await boom.create_timer(s).timeout

func _wacht_mispauze() -> void:
	await _wacht(Ui.MIS_PAUZE + 0.25)

func _wacht_kaart() -> void:
	await _wacht(Spel.SOM_S + 0.25)

func _wacht_plak() -> void:
	await _wacht(Spel.PLAK_S + 0.1)

## A colour that is not the right one for the dot that is asked now.
func _foute_kleur(goed: String) -> String:
	for m in Beurt.MERKEN:
		if str(m["id"]) != goed:
			return str(m["id"])
	return ""

# -------------------------------------------------------------- aanmelding

## The directory scan finds the game, and its registration says where it lives
## and what it hangs on: the resting easel in the playroom.
func test_aanmelding() -> void:
	waar(Games.lijst().has(SPEL), "de mapscan vindt spiegel")
	var def := Games.definitie(SPEL)
	gelijk(def.get("naam", ""), "Spiegelmaskers", "naam")
	gelijk(def.get("kamer", ""), KAMER, "het spel woont in de speelzaal")
	gelijk(def.get("stub", true), false, "geen stub")
	var hs: Dictionary = def.get("hotspot", {})
	gelijk(hs.get("obj", ""), "muziekdoos", "de ingang is verankerd aan de muziekdoos")
	gelijk(hs.get("rust", ""), RUST, "en hangt aan de rustende ezel")
	gelijk(hs.get("icoon", ""), "🎭", "icoon")
	gelijk(hs.get("label", ""), "Maskers", "label")
	var doos := World.mik("muziekdoos", KAMER)
	waar(not doos.is_empty(), "de muziekdoos staat in de speelzaal")
	gelijk(float(doos.get("x", 0)) + float(hs["dx"]), float(Spel.EZEL_X), "x van de ezel")
	gelijk(float(doos.get("z", 0)) + float(hs["dz"]), float(Spel.EZEL_Z), "z van de ezel")
	waar((def.get("modellen", {}) as Dictionary).has("spiegel_ezel"), "het ezelmodel wordt aangemeld")
	waar(Art.heeft_model("spiegel_ezel"), "en Art kent het")
	var rust: Array = def.get("rust", [])
	gelijk(rust.size(), 1, "één rustspul: de ezel")
	var taak: Dictionary = def.get("taak", {})
	gelijk(taak.get("id", ""), "masker", "taak id")
	gelijk(taak.get("kamer", ""), KAMER, "het briefje zegt: in de speelzaal")
	waar(Ui.keur_taak("masker", str(taak.get("tekst", ""))), "het briefje heeft ≤ 6 woorden")
	var unlock: Callable = def["unlock"]
	waar(not unlock.call(0, 3), "zonder gasten niet")
	waar(unlock.call(1, 3), "vanaf één gast wel")

## The easel bakes at every scale, empty and with every band's mask, marks
## and frame; dots and marks are really in the model.
func test_het_masker_bakt() -> void:
	var sets: Array = [{}]
	for band in [3, 4, 5]:
		var o := Beurt.opzet(3, band, 2)
		var d: Dictionary = o["doel"][0]
		sets.append({"r": o["R"], "k": o["K"], "as": o["as"], "stip": o["stip"],
			"merk": d["merk"], "bron": d["bron"]})
	for g in [2, 3, 4]:
		for params in sets:
			var p = Art.plaat("spiegel_ezel", g, params)
			waar(p != null and p.w > 0 and p.h > 0, "spiegel_ezel bakt op g=%d" % g)
	var leeg := Modellen.ezel({"r": 4, "k": 6, "as": "v"}).size()
	var een := Modellen.ezel({"r": 4, "k": 6, "as": "v", "stip": [[0, 0]]}).size()
	var merk := Modellen.ezel({"r": 4, "k": 6, "as": "v", "merk": [[0, 3], [0, 4], [0, 5]]}).size()
	waar(een > leeg, "een stip is echt een sticker op het bord")
	waar(merk > leeg, "de merkjes staan echt op het bord")
	# every cell of a board has its own middle, on the board's face
	for as_ in ["v", "vh"]:
		var gezien := {}
		for rij in 4:
			for kol in 6:
				var p := Modellen.cel_midden(rij, kol, 4, 6, as_)
				waar(not gezien.has(p), "cel %d,%d heeft een eigen plek (%s)" % [rij, kol, as_])
				gezien[p] = true
		# column 0 is on the LEFT of the screen: the largest z
		waar(Modellen.cel_midden(0, 0, 4, 6, as_).z > Modellen.cel_midden(0, 5, 4, 6, as_).z,
			"kolom 0 staat links (%s)" % as_)

# ------------------------------------------------------------- het rekenen

## Every band, many days and hotel sizes: the sum is the one of the band, its
## answer is what the mask needs, every dot to place is the mirror of the dot
## that shines, and its three marks are three free cells on the side that is
## filled — the right one among them, and the slips beside it.
func test_de_getallen_per_band() -> void:
	for band in [3, 4, 5]:
		for dag in range(1, 15):
			for n in [1, 2, 4, 6, 8]:
				var o := Beurt.opzet(n, band, dag)
				var wat := "band %d, dag %d, %d gasten" % [band, dag, n]
				var doel: Array = o["doel"]
				var stip: Array = o["stip"]
				var r := int(o["R"])
				var k := int(o["K"])
				waar(doel.size() >= 2 and doel.size() <= 6, "%s: 2 … 6 stippen plakken (%d)" % [wat, doel.size()])
				gelijk(int(o["basis"]), stip.size(), "%s: de basis is wat er al zit" % wat)
				match band:
					3:
						waar(str(o["som"]).contains("−"), "%s: groep 3 trekt af" % wat)
						gelijk(int(o["goed"]), doel.size(), "%s: zoveel moeten er nog rechts" % wat)
						var links := 0
						for c in stip:
							if int(c[1]) < k / 2:
								links += 1
						gelijk(stip.size() + doel.size(), 2 * links, "%s: rechts komen er evenveel als links" % wat)
					4:
						gelijk(str(o["som"]), "%d + %d =" % [doel.size(), doel.size()], "%s: verdubbelen" % wat)
						gelijk(int(o["goed"]), 2 * doel.size(), "%s: het hele masker" % wat)
					5:
						waar(str(o["som"]).ends_with("× 4 ="), "%s: de tafel van 4" % wat)
						gelijk(int(o["goed"]), stip.size() + doel.size(), "%s: het hele masker" % wat)
						gelijk(int(o["goed"]) % 4, 0, "%s: vier gelijke kwarten" % wat)
				waar(int(o["goed"]) <= 20, "%s: binnen het getallengebied (%d)" % [wat, int(o["goed"])])
				waar(not (o["liever"] as Array).has(int(o["goed"])) or band == 3,
					"%s: de afleiders zijn fout" % wat)
				var vol := {}
				for c in stip:
					vol["%d,%d" % [int(c[0]), int(c[1])]] = true
				for i in doel.size():
					var d: Dictionary = doel[i]
					var cel: Array = d["cel"]
					var bron: Array = d["bron"]
					var spiegel: Array = Beurt.spiegel_h(bron, r) if band == 5 else Beurt.spiegel_v(bron, k)
					gelijk(str(cel), str(spiegel), "%s: stip %d is het spiegelbeeld" % [wat, i])
					waar(vol.has("%d,%d" % [int(bron[0]), int(bron[1])]), "%s: zijn tweeling zit er al" % wat)
					var merk: Array = d["merk"]
					gelijk(merk.size(), 3, "%s: drie merkjes" % wat)
					gelijk(str(merk[int(d["goed"])]), str(cel), "%s: het goede merkje is het spiegelbeeld" % wat)
					var sleutels := {}
					for m in merk:
						waar(m != null, "%s: elk merkje heeft een vak" % wat)
						if m == null:
							continue
						var s := "%d,%d" % [int(m[0]), int(m[1])]
						waar(not vol.has(s), "%s: merkje %s staat op een leeg vak" % [wat, s])
						sleutels[s] = true
						if band == 5:
							waar(int(m[0]) >= r / 2, "%s: onderaan, waar gevuld wordt" % wat)
						else:
							waar(int(m[1]) >= k / 2, "%s: rechts, waar gevuld wordt" % wat)
					gelijk(sleutels.size(), 3, "%s: drie verschillende vakken" % wat)
					vol["%d,%d" % [int(cel[0]), int(cel[1])]] = true
					if i > 0:
						waar(int(d["goed"]) != int((doel[i - 1] as Dictionary)["goed"]),
							"%s: stip %d heeft een andere goede kleur dan de vorige" % [wat, i])

## The same day, the same guests and band: the same mask (a reload asks the
## same question); another day: another mask.
func test_hetzelfde_zaad_hetzelfde_masker() -> void:
	for band in [3, 4, 5]:
		gelijk(str(Beurt.opzet(3, band, 4)), str(Beurt.opzet(3, band, 4)), "band %d: hetzelfde zaad" % band)
		var anders := false
		for dag in range(5, 12):
			anders = anders or str(Beurt.opzet(3, band, dag)) != str(Beurt.opzet(3, band, 4))
		waar(anders, "band %d: een andere dag geeft een ander masker" % band)

## Every sentence the child reads fits the card rules (HOTEL.md §9) and every
## character is in the font subset.
func test_elke_zin_past() -> void:
	if Ui.thema == null or Ui.thema.default_font == null:
		Ui._bouw_thema(17)
	for zin in ["%s %s" % [Beurt.ICOON, Beurt.T_NOG], "%s %s" % [Beurt.ICOON, Beurt.T_SAMEN],
			"%s %s" % [Beurt.ICOON_PLAK, Beurt.T_PLAK], "%s %s" % [Beurt.ICOON_AF, Beurt.T_AF]]:
		waar(Ui.keur_regel("spiegel", zin), "past: %s" % zin)
	var alles: Array = [Beurt.ICOON, Beurt.ICOON_PLAK, Beurt.ICOON_AF, Beurt.ICOON_MOOI, Beurt.T_NOG,
		Beurt.T_SAMEN, Beurt.T_PLAK, Beurt.T_AF, Beurt.T_AF2, Beurt.T_AF2_VIER, Beurt.T_LEEG,
		Beurt.T_MOOI, Beurt.T_KNOP, Beurt.T_TITEL]
	for m in Beurt.MERKEN:
		alles.append(str(m["icoon"]))
		alles.append(str(m["tekst"]))
	for band in [3, 4, 5]:
		alles.append(str(Beurt.opzet(3, band, 2)["som"]))
	for zin in alles:
		gelijk(Ui.mist_tekens(str(zin)).size(), 0, "elk teken staat in de fontsubset: %s" % zin)

# ------------------------------------------------------------ een hele beurt

## A whole turn per band through the real strips: the sum (one miss first:
## the animal sulks, the same four numbers, no help), then every dot (one
## wrong colour first: a sulk, the dot stays, nothing lost), then the finished
## mask with one star.
func test_een_beurt_per_band() -> void:
	for geval in [[2, 3], [4, 4], [8, 5]]:
		var n: int = geval[0]
		var band: int = geval[1]
		_op()
		_wereld(n, band)
		waar(Games.start(SPEL), "band %d: het spel start" % band)
		var o := Beurt.opzet(n, band, 2)
		gelijk(_stand().get("stap", ""), "som", "band %d: de som staat er meteen (R1)" % band)
		waar(not _ezel().is_empty(), "band %d: de ezel staat in de speelzaal" % band)
		waar(World.decor_plek(RUST, KAMER).is_empty(), "band %d: de rustende ezel is weg" % band)
		gelijk(_kaart_tekst("Kolom/Regel"), "🎭 " + Beurt.vraag(o), "band %d: de vraag" % band)
		gelijk(_kaart_tekst("Kolom/Rij/Som"), str(o["som"]), "band %d: de som" % band)
		await _wacht(1.2)
		var gast := str(_stand().get("gast", ""))
		var d = World.dier(gast)
		waar(d != null and d.kamer == KAMER, "band %d: de gast van de beurt is in de speelzaal" % band)
		if d != null:
			waar(absf(d.x - Spel.GAST_X) + absf(d.z - Spel.GAST_Z) <= 1.0, "band %d: naast de ezel" % band)
		var keuzes := _strook()
		waar(keuzes.has("Kn%d" % int(o["goed"])), "band %d: het goede getal staat erbij (%s)" % [band, str(keuzes)])
		var sterren := int(State.s["sterren"])
		for kn in keuzes:
			if kn != "Kn%d" % int(o["goed"]):
				_druk(kn)
				break
		gelijk(_stand().get("stap", ""), "som", "band %d: een misser, dezelfde vraag" % band)
		waar(is_sip(gast), "band %d: het dier is teleurgesteld" % band)
		gelijk(_kaart_tekst("Kolom/Hulp"), "", "band %d: geen hulpregel" % band)
		await _wacht_mispauze()
		gelijk(str(_strook()), str(keuzes), "band %d: dezelfde vier getallen" % band)
		_kies(int(o["goed"]))
		await _wacht_kaart()
		gelijk(_stand().get("stap", ""), "plak", "band %d: nu de stippen" % band)
		gelijk(_kaart_tekst("Kolom/Regel"), "🪞 " + Beurt.T_PLAK, "band %d: de spiegelvraag" % band)
		gelijk(str(_strook()), '["Kblauw", "Kgroen", "Kgeel"]', "band %d: drie kleuren" % band)
		gelijk(_kaart_tekst("Kolom/Rij/Som"), "", "band %d: geen hangende som bij het plakken" % band)
		var spel := _spel()
		var doel: Array = o["doel"]
		for i in doel.size():
			var p: Dictionary = _ezel()["params"]
			gelijk(str(p.get("merk", [])), str((doel[i] as Dictionary)["merk"]), "band %d, stip %d: de merkjes staan op het bord" % [band, i])
			gelijk(str(p.get("bron", [])), str((doel[i] as Dictionary)["bron"]), "band %d, stip %d: zijn tweeling glanst" % [band, i])
			var bord := _knoop("sp_bord") as SpiegelBord
			waar(bord != null, "band %d, stip %d: het masker staat groot in beeld" % [band, i])
			if bord != null:
				gelijk(str(bord.merk), str((doel[i] as Dictionary)["merk"]), "band %d: groot dezelfde merkjes" % band)
				gelijk(str(bord.bron), str((doel[i] as Dictionary)["bron"]), "band %d: groot dezelfde glanzende stip" % band)
				gelijk(bord.stip.size(), int(o["basis"]) + i, "band %d: groot dezelfde stippen" % band)
			var goed: String = spel.goede_kleur()
			if i == 0:
				_kleur(_foute_kleur(goed))
				gelijk(int(_stand().get("i", -1)), 0, "band %d: een foute kleur plakt niets" % band)
				waar(is_sip(gast), "band %d: en het dier is teleurgesteld" % band)
				waar(mis_wolk(KAART, gast), "band %d: alleen 🔄 Nog een keer" % band)
				await _wacht_mispauze()
			_kleur(goed)
			if i < doel.size() - 1:
				gelijk(int(_stand().get("i", -1)), i + 1, "band %d: stip %d zit" % [band, i])
				gelijk(((_ezel()["params"] as Dictionary)["stip"] as Array).size(), int(o["basis"]) + i + 1,
					"band %d: en zit op het masker" % band)
				await _wacht_plak()
		gelijk(_stand().get("stap", ""), "af", "band %d: het masker is af" % band)
		gelijk(int(State.s["sterren"]), sterren + 1, "band %d: één ster voor het meedoen" % band)
		gelijk(_kaart_tekst("Kolom/Regel"), "✨ " + Beurt.T_AF, "band %d: de slotzin" % band)
		gelijk(_kaart_tekst("Kolom/Rij/Som"), str(o["som"]), "band %d: onder de som van het begin" % band)
		gelijk(_kaart_tekst("Kolom/Rij/Vak"), str(int(o["goed"])), "band %d: met het antwoord erin" % band)
		var eind: Dictionary = _ezel()["params"]
		gelijk((eind["stip"] as Array).size(), int(o["basis"]) + doel.size(), "band %d: alle stippen zitten" % band)
		waar(not eind.has("merk"), "band %d: geen merkjes meer" % band)
		waar(_knoop(MOOI) != null, "band %d: de gast vindt het mooi" % band)
		gelijk(int(_stand().get("missers", 0)), 2, "band %d: twee missers geteld" % band)
		_af()

## A reload in the middle: the dots that stuck stay stuck and the same dot is
## asked; floats from the JSON are numbers again; another day is a new mask.
func test_herladen_hervat_de_beurt() -> void:
	_op()
	_wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	var o := Beurt.opzet(4, 4, 2)
	_kies(int(o["goed"]))
	await _wacht_kaart()
	_kleur(_spel().goede_kleur())
	await _wacht_plak()
	Games.stop()
	gelijk(_stand().get("stap", ""), "plak", "de stand is bewaard")
	waar(Games.start(SPEL), "opnieuw gestart")
	gelijk(_stand().get("stap", ""), "plak", "verder met plakken")
	gelijk(int(_stand().get("i", 0)), 1, "de eerste stip zit er nog")
	gelijk(((_ezel()["params"] as Dictionary)["stip"] as Array).size(), int(o["basis"]) + 1, "ook op het bord")
	var st: Dictionary = State.spel_data(SPEL)["stand"]
	st["i"] = 1.0
	st["missers"] = 0.0
	Games.stop()
	waar(Games.start(SPEL), "na een JSON-ronde")
	gelijk(typeof(_stand()["i"]), TYPE_INT, "i is weer een geheel getal")
	Games.stop()
	State.s["dag"] = 3
	waar(Games.start(SPEL), "de volgende dag")
	gelijk(_stand().get("stap", ""), "som", "een nieuw masker begint met de som")
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

## The resting easel stands while nobody plays; the entry hangs ON it; a turn
## takes it away and puts its own easel there; the floor under it stays free.
func test_de_rustende_ezel() -> void:
	_op()
	_wereld(3, 3)
	Games.hersteek()
	var rust := World.decor_plek(RUST, KAMER)
	waar(not rust.is_empty(), "de ezel staat in de speelzaal als er niet gespeeld wordt")
	gelijk(float(rust.get("x", 0)), float(Spel.EZEL_X), "op de plek van de ezel")
	waar(Games.start(SPEL), "het spel start")
	waar(World.decor_plek(RUST, KAMER).is_empty(), "het rustspul gaat weg")
	waar(not _ezel().is_empty(), "de eigen ezel staat er")
	Games.stop()
	waar(_ezel().is_empty(), "na het spel is de eigen ezel weg")
	waar(not World.decor_plek(RUST, KAMER).is_empty(), "en staat de rustende ezel er weer")
	var r := Rooms.get_kamer(KAMER)
	for p in r.plekken:
		waar(not (p[0] >= 10 and p[0] <= 32 and p[1] >= 46 and p[1] <= 86),
			"geen loopplek op de ezel (%s)" % str(p))
	waar(not Rooms.vrij_vak(KAMER, float(Spel.EZEL_X), float(Spel.EZEL_Z)),
		"er kan geen meubel op de ezel")
	_af()

# ------------------------------------------------------- op vier schermen

## The real shell on the four screens, every step of a turn: every element of
## the game is inside the frame, finds a real place, and the card and its
## strip stand on the screen.
func test_op_vier_schermen() -> void:
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
		_keur(kader.size, "%s som" % str(maat))
		# both cards dock in the maths bar (not on the landscape phone, where a
		# third of the frame is lower than any card with a sum line)
		var dok: bool = maat.y >= 400
		if dok:
			gelijk(Ui.balk_kaart(), KAART, "%s: de som staat in de rekenbalk" % str(maat))
		_kies(int(o["goed"]))
		await _wacht_kaart()
		for _f in 3:
			await boom.process_frame
		_keur(kader.size, "%s plak" % str(maat))
		if dok:
			gelijk(Ui.balk_kaart(), KAART, "%s: de spiegelvraag staat in de rekenbalk" % str(maat))
		gelijk(_strook().size(), 3, "%s: drie kleuren op de strook" % str(maat))
		# the big mask stands clear of the card and its strip, and is big
		var dbg := Hits.debug()
		waar(dbg.has("sp_bord"), "%s: het grote masker staat er" % str(maat))
		if dbg.has("sp_bord"):
			var b: Rect2 = dbg["sp_bord"]["rect"]
			waar(b.size.x >= 150.0, "%s: het masker is groot genoeg (%s)" % [str(maat), str(b)])
			# the guest of the turn stays in sight beside it: his sulk is the
			# only answer to a miss
			var gast := str(_stand().get("gast", ""))
			var dier := World.vlak_van_dier(gast)
			if dier.size.x > 0.0:
				var mid := dier.get_center()
				waar(not b.has_point(mid), "%s: de gast staat niet achter het masker (%s, %s)" % [str(maat), str(b), str(dier)])
			for id in [KAART, STROOK]:
				if dbg.has(id):
					var andere: Rect2 = dbg[id]["rect"]
					var snij := b.intersection(andere)
					waar(snij.size.x <= 0.5 or snij.size.y <= 0.5,
						"%s: het masker ligt niet over %s (%s, %s)" % [str(maat), id, str(b), str(andere)])
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

## Every spot of the game: inside the frame, never `krap` (the miss bubble on
## the landscape phone aside, as in every game), and a real tap target.
func _keur(kader: Vector2, wat: String) -> void:
	var dbg := Hits.debug()
	var eigen := 0
	for id in dbg.keys():
		var spot := Hits.spot(id)
		if spot == null or spot.door != SPEL:
			continue
		eigen += 1
		var d: Dictionary = dbg[id]
		var r: Rect2 = d["rect"]
		var s5_laag := str(id).begins_with(Ui.MIS_WOLK) and kader.y < 300.0
		waar(not bool(d["krap"]) or s5_laag, "%s: %s vond een echte plek" % [wat, id])
		waar(r.position.x >= -0.01 and r.position.y >= -0.01
			and r.end.x <= kader.x + 0.01 and r.end.y <= kader.y + 0.01,
			"%s: %s staat binnen het kader (%s)" % [wat, id, str(r)])
		if spot.kind == "tag" or int(d["laag"]) == Hits.Laag.VAST:
			continue
		waar(r.size.x >= 44.0 and r.size.y >= 44.0, "%s: %s is een tikdoel" % [wat, id])
	waar(eigen >= 2, "%s: het spel staat op het scherm (%d)" % [wat, eigen])
