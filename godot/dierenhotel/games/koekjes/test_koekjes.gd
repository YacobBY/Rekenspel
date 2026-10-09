extends Proef
## Koekjes bakken — de bakkerij (2026-10-07), headless.
##
## The sums of `KoekjesBeurt` per group and per day, the text rules (HOTEL.md
## §9), the bakery as a room, the models, the registration, and whole turns
## driven the way a child drives them: an answer is a `pressed` on a button of
## the real strip under the card.  Only the pure turn logic in `beurt.gd` is
## called directly.

const SPEL := "koekjes"
const KAMER := "bakkerij"
const KAART := "kk_kaart"
const STROOK := "kk_kaart_keuzes"
const LEKKER := "kk_lekker"
const LEEG := "kk_leeg"
const OVEN := "kk_oven"
const BANK := "kk_bank"
const RUST_OVEN := "rust_kk_oven"
const RUST_BANK := "rust_kk_bank"
const BORD := "kk_bord"
const Beurt := preload("res://games/koekjes/beurt.gd")
const Spel := preload("res://games/koekjes/spel.gd")

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
## adaptive cap so the band really is the band the test asks for.  The save is
## never written: `start_gekozen()` is not called (see test_kraam), except in
## the reload test, which writes and reads the file on purpose.
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
	if band > 0:
		gelijk(State.band(), band, "de band is %d bij %d gasten" % [band, n])
	return uit

## The first day (from 1) on which `n` guests in group `band` get soort `soort`.
func _dag_voor(n: int, band: int, soort: String) -> int:
	for dag in range(1, 200):
		if str(Beurt.maak(n, band, dag)["soort"]) == soort:
			return dag
	fout("geen dag met %s voor %d gasten in groep %d" % [soort, n, band])
	return 1

func _knoop(id: String) -> Control:
	var s := Hits.spot(id)
	return null if s == null or not is_instance_valid(s.knoop) else s.knoop

func _druk(naam: String) -> bool:
	var strook := _knoop(STROOK)
	if strook == null:
		fout("er is geen antwoordstrook")
		return false
	var k := strook.get_node_or_null("Rij/" + naam)
	if k == null:
		fout("%s staat niet op de strook (%s)" % [naam, str(_strook())])
		return false
	(k as BaseButton).pressed.emit()
	return true

## One number on the real strip under the card.
func _kies(getal: int) -> bool:
	return _druk("Kn%d" % getal)

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

func _foute_knop(goed: int) -> String:
	for k in _strook():
		if k != "Kn%d" % goed:
			return k
	return ""

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

func _bank() -> Dictionary:
	return World.decor_plek(BANK, KAMER)

func _oven() -> Dictionary:
	return World.decor_plek(OVEN, KAMER)

func _bord() -> KoekjesBord:
	return _knoop(BORD) as KoekjesBord

func _wacht(s: float) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	await boom.create_timer(s).timeout

## Everything the band plays while `fn` runs and for `s` seconds after it: the
## band is woken for it (tests run with it asleep) and put back after.
func _hoor(s: float, fn: Callable) -> Array[String]:
	var gehoord: Array[String] = []
	var hoor := func(naam: String) -> void: gehoord.append(naam)
	var was := [Snd._wakker, Snd._uit]
	Snd._wakker = true
	Snd._uit = false
	for naam in Snd.WERELD_MS:
		Snd._laatst.erase(naam)
	Snd.gespeeld.connect(hoor)
	fn.call()
	if s > 0.0:
		await _wacht(s)
	Snd.gespeeld.disconnect(hoor)
	Snd._wakker = bool(was[0])
	Snd._uit = bool(was[1])
	if not Snd._wakker or Snd._uit:
		Snd._zwijg()
	return gehoord

## Rekent een som als "2 + 2 + 2 =", "3 × 5 =" of "14 : 3 =" uit.
func _reken(som: String) -> int:
	var kaal := som.trim_suffix(" =").strip_edges()
	if kaal.contains(" : "):
		var d := kaal.split(" : ")
		@warning_ignore("integer_division")
		return int(d[0]) / int(d[1])
	if kaal.contains(" × "):
		var p := 1
		for s in kaal.split(" × "):
			p *= int(s)
		return p
	var t := 0
	for s in kaal.split(" + "):
		t += int(s)
	return t

# ------------------------------------------------------------- het rekenen

## Every group, N 1..8 and days 1..14: the sum is right, the answer is above
## zero, three distinct wrong answers, the same day gives the same question,
## and what lies on the table IS the sum: before the answer its numbers, after
## it the answer.
func _elke(band: int, fn: Callable) -> void:
	for n in range(1, 9):
		for dag in range(1, 15):
			var b := Beurt.maak(n, band, dag)
			var wat := "groep %d, %d gasten, dag %d: %s %s" % [band, n, dag, b["soort"], b["som"]]
			gelijk(str(b), str(Beurt.maak(n, band, dag)), "%s: dezelfde dag, dezelfde vraag" % wat)
			gelijk(_reken(str(b["som"])), int(b["goed"]), wat)
			waar(int(b["goed"]) > 0, "%s: antwoord boven nul" % wat)
			var liever: Array = b["liever"]
			gelijk(liever.size(), 3, "%s: drie afleiders" % wat)
			for l in liever:
				waar(int(l) != int(b["goed"]) and int(l) > 0,
					"%s: afleider %s naast %d" % [wat, str(l), int(b["goed"])])
			waar(int(b["goed"]) <= 99, "%s: past in twee cijfers" % wat)
			var vier := Afleiders.vier(int(b["goed"]), 7, {"min": 1, "max": 99, "liever": liever})
			gelijk(vier.size(), 4, "%s: vier getallen op de strook" % wat)
			waar(vier.has(int(b["goed"])), "%s: het goede getal staat erbij" % wat)
			_keur_tafel(b, wat)
			fn.call(n, b)

## The table in every step of the turn: before the answer it shows the
## numbers of the sum, after it the answer — and it always fits on the table.
func _keur_tafel(b: Dictionary, wat: String) -> void:
	var soort := str(b["soort"])
	var voor := Beurt.bank(b, "som")
	var na := Beurt.bank(b, "af")
	match soort:
		"koekjes", "plaat", "tafel":
			gelijk(Beurt.op_tafel(voor), int(b["goed"]), "%s: zoveel bolletjes deeg op de plaat" % wat)
			gelijk(int(voor["rijen"]), int(b["rijen"]), "%s: een rij per gast" % wat)
			waar(not bool(voor["gaar"]) and bool(na["gaar"]), "%s: deeg, dan gebakken" % wat)
			waar(Beurt.bank(b, "bak").is_empty(), "%s: de plaat is in de oven" % wat)
			waar(bool(Beurt.oven(b, "bak").get("bakt", false)), "%s: de oven gloeit" % wat)
		"eieren":
			gelijk(str(voor["kommen"]), str([int(b["eieren"])]), "%s: N eieren in de kom" % wat)
			gelijk(int(voor["los"]), int(b["erbij"]), "%s: en r ernaast" % wat)
			gelijk(str(na["kommen"]), str([int(b["goed"])]), "%s: daarna alle eieren in de kom" % wat)
		"dubbel":
			gelijk(Beurt.op_tafel(voor), int(b["goed"]), "%s: twee kommen met e eieren" % wat)
			waar(bool(na["beslag"]), "%s: daarna beslag" % wat)
		"verdeel":
			gelijk(Beurt.op_tafel(voor), int(b["totaal"]), "%s: alle T koekjes op de plaat" % wat)
			gelijk(int(na["rijen"]), int(b["rijen"]), "%s: daarna een rij per dier" % wat)
			gelijk(int(na["kolommen"]), int(b["goed"]), "%s: van k koekjes" % wat)
			gelijk(int(Beurt.oven(b, "af").get("rest", 0)), int(b["rest"]),
				"%s: de rest op het bordje op de oven" % wat)
	for p in [voor, na]:
		if int(p.get("rijen", 0)) > 0:
			var w: int = int(p["kolommen"]) * ArtDecorBakkerij.STAP + 2
			var d: int = int(p["rijen"]) * ArtDecorBakkerij.STAP + 2
			waar(w <= ArtDecorBakkerij.BANK_W - 4 and d <= ArtDecorBakkerij.BANK_D - 4,
				"%s: de plaat (%d × %d) past op de tafel" % [wat, w, d])
		for k in p.get("kommen", []):
			waar(int(k) <= 12, "%s: hooguit twaalf eieren in een kom" % wat)

func test_groep3_telt_tot_twintig() -> void:
	var soorten := {}
	_elke(3, func(n: int, b: Dictionary) -> void:
		soorten[b["soort"]] = true
		waar(["koekjes", "eieren"].has(b["soort"]), "groep 3 soort " + str(b["soort"]))
		waar(int(b["goed"]) <= 20, "groep 3 blijft onder 20: " + str(b["som"]))
		waar(not str(b["som"]).contains("×") and not str(b["som"]).contains(":"),
			"groep 3 telt op: " + str(b["som"]))
		if b["soort"] == "koekjes":
			gelijk(int(b["rijen"]), n, "een rij per gast")
			gelijk(int(b["kolommen"]), 2, "twee per dier: tellen met sprongen van twee")
			waar(n >= 2 and n <= 5, "hooguit vijf tweeën op een rij")
		else:
			gelijk(int(b["eieren"]), n, "een ei per gast in de kom")
			waar(int(b["erbij"]) >= 1 and int(b["erbij"]) <= 3, "er komen er 1 tot 3 bij"))
	waar(soorten.has("koekjes") and soorten.has("eieren"), "beide soorten komen voor")

func test_groep4_tafels_2_5_10_en_verdubbelen() -> void:
	var soorten := {}
	_elke(4, func(n: int, b: Dictionary) -> void:
		soorten[b["soort"]] = true
		waar(["plaat", "dubbel"].has(b["soort"]), "groep 4 soort " + str(b["soort"]))
		if b["soort"] == "plaat":
			gelijk(int(b["rijen"]), n, "een rij per gast")
			waar(int(b["kolommen"]) in [2, 5, 10], "tafel van 2, 5 of 10")
		else:
			waar(int(b["eieren"]) <= 10 and int(b["goed"]) <= 20, "dubbel blijft onder 20")
			waar(int(b["eieren"]) > n, "het recept heeft meer eieren dan er gasten zijn"))
	waar(soorten.has("plaat") and soorten.has("dubbel"), "beide soorten komen voor")

func test_groep5_alle_tafels_en_delen_met_rest() -> void:
	var soorten := {}
	_elke(5, func(n: int, b: Dictionary) -> void:
		soorten[b["soort"]] = true
		waar(["tafel", "verdeel"].has(b["soort"]), "groep 5 soort " + str(b["soort"]))
		if b["soort"] == "tafel":
			gelijk(int(b["rijen"]), n, "een rij per gast")
			waar(int(b["kolommen"]) in [3, 4, 6, 7, 8, 9], "de tafels van groep 5")
		else:
			waar(n >= 2, "delen alleen met twee of meer dieren")
			gelijk(int(b["totaal"]), int(b["goed"]) * n + int(b["rest"]), "T = k·N + r")
			waar(int(b["rest"]) < n, "rest kleiner dan het aantal dieren")
			waar(int(b["goed"]) >= 2 and int(b["goed"]) <= 9, "2 tot 9 per dier")
			gelijk(str(b["regel2"]), Beurt.T_REST, "de rest is voor de kok"))
	waar(soorten.has("tafel") and soorten.has("verdeel"), "beide soorten komen voor")

func test_zelfde_dag_zelfde_vraag() -> void:
	for band in [3, 4, 5]:
		var a := Beurt.maak(4, band, 7)
		var b := Beurt.maak(4, band, 7)
		gelijk(str(a), str(b), "herladen geeft dezelfde beurt in groep %d" % band)
		var anders := false
		for dag in range(8, 15):
			anders = anders or str(Beurt.maak(4, band, dag)) != str(a)
		waar(anders, "groep %d: een andere dag geeft een andere vraag" % band)

## Every sentence the child reads fits the card rules (HOTEL.md §9) — with its
## pictogram in front, as the card shows it — and every character is in the
## font subset (`Ui.mist_tekens`).
func test_zinnen_volgen_de_tekstregels() -> void:
	if Ui.thema == null or Ui.thema.default_font == null:
		Ui._bouw_thema(17)
	for zin in Beurt.vragen():
		var regel := "%s %s" % [Beurt.ICOON, zin]
		waar(Ui.keur_regel(SPEL, regel), "past op de kaart: %s" % regel)
	var alles: Array = [Beurt.ICOON, Beurt.ICOON_AF, Beurt.ICOON_LEKKER, "🛏"]
	alles.append_array(Beurt.zinnen())
	for zin in alles:
		var s := str(zin)
		waar(s.split(" ", false).size() <= 8, "≤ 8 woorden: " + s)
		waar(s.length() <= 40, "≤ 40 tekens: " + s)
		gelijk(Ui.mist_tekens(s).size(), 0, "elk teken staat in de lettertypen: " + s)
	# the sum lines are no sentences, but they must fit and render as well
	for band in [3, 4, 5]:
		for n in range(1, 9):
			for dag in range(1, 15):
				var som := str(Beurt.maak(n, band, dag)["som"])
				waar(som.length() <= 24, "de som past op de kaart: " + som)
				gelijk(Ui.mist_tekens(som).size(), 0, "elk teken van de som staat erin: " + som)
	waar(Ui.keur_taak(SPEL, Beurt.TAAK), "taakkaartje ≤ 6 woorden")
	gelijk(Ui.mist_tekens(Rooms.get_kamer(KAMER).icoon).size(), 0, "het pictogram van de kamer")

# -------------------------------------------------------------- de kamer

## The bakery is a room on the first floor behind the kitchen; the oven and the
## table of the game stand in it whenever nobody plays — also before the first
## guest — and their floor holds no wander place and no bought furniture.
func test_de_bakkerij_is_een_kamer_op_de_eerste_verdieping() -> void:
	waar(Rooms.bestaat(KAMER), "de bakkerij bestaat")
	gelijk(Rooms.etage(KAMER), 1, "naast de keuken op de eerste verdieping")
	# additive: after every room that was there (the winkels were the last one
	# before 2026-10-07); the three sibling rooms of that day may follow it
	waar(Rooms.lijst().find(KAMER) > Rooms.lijst().find("winkels"),
		"achter de kamers die er al waren toegevoegd")
	waar(not Rooms.deur(KAMER, "keuken").is_empty(), "deur naar de keuken")
	waar(not Rooms.deur("keuken", KAMER).is_empty(), "en de keuken heeft hem ook")
	_pad_is(Rooms.pad("receptie", KAMER), ["receptie", "gang", "keuken", KAMER])
	var r := Rooms.get_kamer(KAMER)
	gelijk(r.mijd.size(), 2, "de vloer van de oven en van de tafel")
	for p in r.plekken:
		for m in r.mijd:
			waar(not (p[0] >= m["x0"] and p[0] <= m["x1"] and p[1] >= m["z0"] and p[1] <= m["z1"]),
				"loopplek %s staat niet op de oven of de tafel" % str(p))
	for plek in [Vector2(Spel.OVEN_X, Spel.OVEN_Z), Vector2(Spel.BANK_X, Spel.BANK_Z)]:
		waar(not Rooms.vrij_vak(KAMER, plek.x, plek.y), "geen gekocht meubel op %s" % str(plek))
	# the table's floor is the table: its rectangle in the room data covers it
	var bank: Dictionary = r.mijd[1]
	gelijk(int(bank["x1"]) - int(bank["x0"]), ArtDecorBakkerij.BANK_W, "de tafel is zo breed")
	gelijk(int(bank["z1"]) - int(bank["z0"]), ArtDecorBakkerij.BANK_D, "en zo diep")
	gelijk((int(bank["x0"]) + int(bank["x1"])) / 2, Spel.BANK_X, "om het midden van de tafel (x)")
	gelijk((int(bank["z0"]) + int(bank["z1"])) / 2, Spel.BANK_Z, "om het midden van de tafel (z)")
	# the baker's place: beside the table, on no table, and the walk from the
	# kitchen door to it passes over no table and no oven
	var gast := Vector2(Spel.GAST_X, Spel.GAST_Z)
	var deur := Vector2(float(r.deur_punten["keuken"]["ix"]), float(r.deur_punten["keuken"]["iz"]))
	for m in r.mijd:
		var vak := Rect2(float(m["x0"]), float(m["z0"]), float(m["x1"] - m["x0"]),
			float(m["z1"] - m["z0"]))
		waar(not vak.grow(13.0).has_point(gast), "de bakker staat naast %s" % str(m))
		waar(not Rooms._snijdt(vak, deur, gast), "van de deur naar de bakker langs %s" % str(m))

func _pad_is(gekregen: Array, verwacht: Array) -> void:
	gelijk(gekregen.size(), verwacht.size(), "padlengte")
	for i in mini(gekregen.size(), verwacht.size()):
		gelijk(gekregen[i], verwacht[i], "stap %d" % i)

## The models bake at every scale; what lies on them is really there.
func test_decormodellen_bakken() -> void:
	var t := ArtDecorBakkerij.tabel()
	for naam in ArtDecorBakkerij.NAMEN:
		waar(t.has(naam), "tabel kent " + naam)
		var v: Array = (t[naam] as Callable).call({})
		waar(v.size() > 0, naam + " heeft voxels")
	var plaat: Array = ArtDecorBakkerij.bakplaat({"rijen": 3, "kolommen": 5})
	var leeg: Array = ArtDecorBakkerij.bakplaat({"rijen": 3, "kolommen": 5, "aantal": 0})
	waar(plaat.size() > leeg.size(), "koekjes op de plaat zijn voxels")
	gelijk(plaat.size() - leeg.size(), 15 * 10, "vijftien gebakken koekjes van tien voxels")
	var deeg: Array = ArtDecorBakkerij.bakplaat({"rijen": 3, "kolommen": 5, "gaar": false})
	gelijk(deeg.size() - leeg.size(), 15 * 10, "vijftien bolletjes deeg van tien voxels")
	var vol: Array = ArtDecorBakkerij.eierschaal({"n": 8})
	var kom: Array = ArtDecorBakkerij.eierschaal({"n": 0})
	gelijk(vol.size() - kom.size(), 8 * 10, "acht eieren van tien voxels in de kom")
	# every egg has a place of its own inside the bowl's wall
	var gezien := {}
	for i in 12:
		var c := ArtDecorBakkerij._ei_vak(i)
		waar(not gezien.has(c), "ei %d heeft een eigen vak" % i)
		gezien[c] = true
		for hoek: Vector2i in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 1)]:
			var p: Vector2i = c + hoek
			waar(p.x * p.x + p.y * p.y <= 64, "ei %d ligt binnen de wand" % i)
	for params in [{}, Spel.RUST_TAFEL, {"rijen": 8, "kolommen": 10, "gaar": true},
			{"kommen": [8], "los": 3}, {"kommen": [10, 10]}, {"kommen": [10, 10], "beslag": true}]:
		for g in [2, 3, 4]:
			var p = Art.plaat(Spel.MODEL_BANK, g, params)
			waar(p != null and p.w > 0 and p.h > 0, "de tafel bakt op g=%d (%s)" % [g, str(params)])
		# nothing pokes out of the table top
		for q in ArtDecorBakkerij.werkbank(params):
			waar(absi(int(q["x"])) <= ArtDecorBakkerij.BANK_W / 2
				and absi(int(q["z"])) <= ArtDecorBakkerij.BANK_D / 2,
				"alles ligt op de tafel (%s)" % str(params))
	for params in [{}, {"bakt": true}, {"rest": 7}]:
		var p = Art.plaat(Spel.MODEL_OVEN, 3, params)
		waar(p != null and p.w > 0, "de oven bakt (%s)" % str(params))
	waar(ArtDecorBakkerij.bakoven({"bakt": true}).size() != ArtDecorBakkerij.bakoven({}).size(),
		"de oven ziet er anders uit als hij bakt")
	waar(ArtDecorBakkerij.bakoven({"rest": 3}).size() > ArtDecorBakkerij.bakoven({}).size(),
		"de rest ligt op een bordje op de oven")

## The big board: one cell per cookie or egg, every table of the game fits a
## board of at most 15 by 11 cells (ten cookies and the plate of the rest
## across, eight rows and the oven's arch down), and the oven and the plate of
## the rest make it larger, never smaller.
func test_het_grote_bord_meet_zich() -> void:
	for band in [3, 4, 5]:
		for n in range(1, 9):
			for dag in range(1, 15):
				var b := Beurt.maak(n, band, dag)
				for stap in ["som", "bak", "af"]:
					var p := Beurt.bord(b, stap)
					var c := KoekjesBord.cellen(p)
					var wat := "groep %d, %d gasten, dag %d, %s (%s)" % [band, n, dag, stap, b["soort"]]
					waar(c.x >= 2.0 and c.y >= 2.0, "%s: het bord heeft een maat (%s)" % [wat, str(c)])
					waar(c.x <= 15.0 and c.y <= 11.0, "%s: hooguit 15 bij 11 vakken (%s)" % [wat, str(c)])
					if int(p.get("rijen", 0)) > 0:
						waar(c.x >= float(p["kolommen"]) and c.y >= float(p["rijen"]),
							"%s: een vak per koekje" % wat)
					var m := KoekjesBord.maat_bij(20.0, p)
					gelijk(m, (c * 20.0).floor(), "%s: maat_bij" % wat)
	var plaat := {"rijen": 3, "kolommen": 4, "aantal": 12}
	waar(KoekjesBord.cellen(plaat.merged({"oven": true})).x > KoekjesBord.cellen(plaat).x,
		"de oven om de plaat maakt het bord breder")
	waar(KoekjesBord.cellen(plaat.merged({"rest": 2})).x > KoekjesBord.cellen(plaat).x,
		"het bordje van de kok ook")

# ------------------------------------------------------------ aanmelding

## The directory scan finds the game: not a stub, in the bakery, its entry
## anchored to the counter and hanging ON the resting oven; the oven and the
## table are its resting props and its models are registered at the scan.
func test_aanmelding() -> void:
	waar(Games.lijst().has(SPEL), "de mapscan vindt koekjes")
	var d := Games.definitie(SPEL)
	gelijk(str(d.get("naam", "")), "Koekjes bakken", "naam")
	gelijk(str(d.get("kamer", "")), KAMER, "in de bakkerij")
	gelijk(bool(d.get("stub", true)), false, "geen stub meer: speelbaar")
	var hs: Dictionary = d.get("hotspot", {})
	gelijk(str(hs.get("obj", "")), Spel.ANKER, "de ingang is verankerd aan het aanrecht")
	gelijk(str(hs.get("rust", "")), RUST_OVEN, "en hangt aan de rustende oven")
	gelijk(str(hs.get("icoon", "")), Beurt.ICOON, "icoon")
	gelijk(str(hs.get("label", "")), Beurt.KNOP, "label: pictogram én woord")
	var anker := World.mik(Spel.ANKER, KAMER)
	waar(not anker.is_empty(), "het aanrecht staat in de bakkerij")
	gelijk(float(anker.get("x", 0)) + float(hs["dx"]), float(Spel.OVEN_X), "x van de oven")
	gelijk(float(anker.get("z", 0)) + float(hs["dz"]), float(Spel.OVEN_Z), "z van de oven")
	var modellen: Dictionary = d.get("modellen", {})
	for m in [Spel.MODEL_OVEN, Spel.MODEL_BANK]:
		waar(modellen.has(m), "%s wordt aangemeld" % m)
		waar(Art.heeft_model(m), "en Art kent %s" % m)
		waar(not Art.is_wereldmodel(m), "%s is van het spel, geen wereldmodel" % m)
	var rust: Array = d.get("rust", [])
	gelijk(rust.size(), 2, "twee rustspullen: de oven en de tafel")
	var unlock: Callable = d["unlock"]
	waar(unlock.call(0, 3), "de oven en de tafel staan er ook zonder gasten")
	var kan: Callable = d["kan"]
	waar(not kan.call({"gasten": []}), "zonder gasten geen bakker")
	waar(not kan.call({"gasten": [{"bed": ""}]}), "een gast zonder bed bakt nog niet")
	waar(kan.call({"gasten": [{"bed": ""}, {"bed": "bed1"}]}), "een gast met een bed wel")
	var taak: Dictionary = d.get("taak", {})
	gelijk(str(taak.get("id", "")), SPEL, "taak id")
	gelijk(str(taak.get("kamer", "")), KAMER, "het briefje zegt: in de bakkerij")
	gelijk(int(taak.get("prio", 0)), HotelPrikbord.LAAG, "een gewoon spelkaartje, geen wens")
	waar(Ui.keur_taak(SPEL, str(taak.get("tekst", ""))), "het briefje heeft ≤ 6 woorden")
	waar(not d.has("wens"), "het spel vervult geen wens: het 🍪-bakje is van de voerkar")

## The resting oven and table stand while nobody plays — also with no guest
## at all; the entry hangs ON the oven only when there is a baker; a turn
## takes them away and puts its own there; after it they are back.
func test_de_rustende_oven_en_tafel() -> void:
	_op()
	_wereld(0, 0)
	Games.hersteek()
	waar(not World.decor_plek(RUST_OVEN, KAMER).is_empty(), "de oven staat er zonder gasten")
	waar(not World.decor_plek(RUST_BANK, KAMER).is_empty(), "de tafel ook")
	World.naar(KAMER)
	Games.hersteek()
	Hits.plaats()
	waar(Hits.spot("spel_koekjes") == null, "maar zonder bakker geen knop")
	gelijk(Hotel.spel_taken().filter(func(q): return str(q["spel"]) == SPEL).size(), 0,
		"en geen taakkaartje")
	_wereld(3, 3)
	World.naar(KAMER)
	Games.hersteek()
	Hits.plaats()
	var knop := Hits.spot("spel_koekjes")
	waar(knop != null, "met een gast met een bed hangt 🍪 Bakken er")
	if knop != null:
		gelijk(str(knop.obj), RUST_OVEN, "aan de rustende oven")
	gelijk(Hotel.spel_taken().filter(func(q): return str(q["spel"]) == SPEL).size(), 1,
		"en het briefje Bak koekjes kan op het prikbord")
	var rust := World.decor_plek(RUST_BANK, KAMER)
	gelijk(float(rust.get("x", 0)), float(Spel.BANK_X), "de tafel op haar plek")
	waar(Games.start(SPEL), "het spel start")
	waar(World.decor_plek(RUST_OVEN, KAMER).is_empty(), "de rustende oven gaat weg")
	waar(World.decor_plek(RUST_BANK, KAMER).is_empty(), "de rustende tafel gaat weg")
	waar(not _oven().is_empty() and not _bank().is_empty(), "de eigen oven en tafel staan er")
	Games.stop()
	waar(_oven().is_empty() and _bank().is_empty(), "na het spel zijn de eigen spullen weg")
	waar(not World.decor_plek(RUST_OVEN, KAMER).is_empty(), "en staat de rustende oven er weer")
	waar(not World.decor_plek(RUST_BANK, KAMER).is_empty(), "en de rustende tafel")
	_af()

# ------------------------------------------------------------ een hele beurt

## A whole turn per group through the real strip: the baker walks to the
## table, the card asks the sum that lies on the table, one miss first (the
## baker sulks, the same four numbers, nothing helps and nothing is taken),
## then the right answer: the tick, the sounds, one star, the answer in the
## world, the end card — and the game closes itself.
func test_een_beurt_per_band() -> void:
	alleen_spellen([SPEL])
	for geval in [[3, 3, "eieren"], [4, 4, "plaat"], [8, 5, "verdeel"]]:
		var n: int = geval[0]
		var band: int = geval[1]
		var soort: String = geval[2]
		var dag := _dag_voor(n, band, soort)
		_op()
		_wereld(n, band, dag)
		var wat := "groep %d (%s)" % [band, soort]
		var b := Beurt.maak(n, band, dag)
		var sterren := int(State.s["sterren"])
		waar(Games.start(SPEL), "%s: het spel start" % wat)
		gelijk(World.kamer_nu(), KAMER, "%s: de camera is in de bakkerij" % wat)
		gelijk(str(_stand().get("stap", "")), "som", "%s: eerst de som" % wat)
		var gast := str(_stand().get("gast", ""))
		var d = World.dier(gast)
		waar(d != null and d.kamer == KAMER, "%s: de bakker is in de bakkerij" % wat)
		if d != null:
			waar(absf(d.x - Spel.GAST_X) + absf(d.z - Spel.GAST_Z) <= 1.0, "%s: naast de tafel" % wat)
		gelijk(Games.speler(), gast, "%s: de bakker staat op de spelbalk" % wat)
		# the sum lies on the table, and large on the board beside the baker
		gelijk(str(_bank().get("params", {})), str(Beurt.bank(b, "som")), "%s: de tafel toont de som" % wat)
		var bord := _bord()
		waar(bord != null, "%s: de tafel staat groot in beeld" % wat)
		if bord != null:
			gelijk(str(bord.p), str(Beurt.bord(b, "som")), "%s: het bord toont wat op de tafel ligt" % wat)
			gelijk(Beurt.op_tafel(bord.p), Beurt.op_tafel(Beurt.bank(b, "som")), "%s: evenveel als op de tafel" % wat)
		gelijk(_kaart_tekst("Kolom/Regel"), "%s %s" % [Beurt.ICOON, str(b["regel"])], "%s: de vraag" % wat)
		gelijk(_kaart_tekst("Kolom/Rij/Som"), str(b["som"]), "%s: de som" % wat)
		var keuzes := _strook()
		gelijk(keuzes.size(), 4, "%s: vier getallen" % wat)
		waar(keuzes.has("Kn%d" % int(b["goed"])), "%s: het goede getal staat erbij (%s)" % [wat, str(keuzes)])
		# a miss: the baker sulks, nothing else changes, nothing helps
		var voor := beeld(SPEL)
		var mis := _foute_knop(int(b["goed"]))
		var gehoord := await _hoor(0.0, func() -> void: _druk(mis))
		waar(is_sip(gast), "%s: de bakker is teleurgesteld" % wat)
		waar(mis_wolk(KAART, gast), "%s: 🔄 Nog een keer" % wat)
		waar(gehoord.has("%s_sip" % Snd.soort_van(gast)) or gehoord.has("zacht"),
			"%s: een zacht, teleurgesteld geluidje (%s)" % [wat, str(gehoord)])
		gelijk(str(_stand().get("stap", "")), "som", "%s: dezelfde vraag" % wat)
		gelijk(int(_stand().get("missers", 0)), 1, "%s: de misser is geteld" % wat)
		gelijk(int(State.s["sterren"]), sterren, "%s: een misser kost niets en geeft niets" % wat)
		gelijk(_kaart_tekst("Kolom/Hulp"), "", "%s: geen hulpregel" % wat)
		await _wacht(Ui.MIS_PAUZE + 0.25)
		niets_erbij(voor, beeld(SPEL), wat)
		gelijk(str(_strook()), str(keuzes), "%s: dezelfde vier getallen" % wat)
		# the right answer: "dat klopt!", one star, and one entry in the
		# adaptive signal — not first time right, there was a miss
		var signaal := (State.s["signaal"] as Array).size()
		Snd._gehoord.clear()
		var goed_gehoord := await _hoor(0.0, func() -> void: _kies(int(b["goed"])))
		waar(Snd.gehoord().has("ja"), "%s: Snd.gehoord: dat klopt! (%s)" % [wat, str(Snd.gehoord())])
		waar(goed_gehoord.has("ja"), "%s: dat klopt! (%s)" % [wat, str(goed_gehoord)])
		gelijk(int(State.s["sterren"]), sterren + 1, "%s: één ster voor het meedoen" % wat)
		var sig: Array = State.s["signaal"]
		gelijk(sig.size(), mini(signaal + 1, State.SIGNAAL_MAX), "%s: één keer geteld (State.tel)" % wat)
		if not sig.is_empty():
			gelijk(int((sig[sig.size() - 1] as Dictionary)["g"]), 0, "%s: niet in één keer goed" % wat)
		var later := await _hoor(Spel.IN_S + Spel.BAK_S + 0.6, func() -> void: pass)
		later = goed_gehoord + later
		gelijk(str(_stand().get("stap", "")), "af", "%s: de beurt is af" % wat)
		waar(later.has("hoera"), "%s: hoera (%s)" % [wat, str(later)])
		waar(later.has("knabbel"), "%s: de bakker proeft er een (%s)" % [wat, str(later)])
		if soort == "eieren":
			waar(later.count("plop%d" % 1) >= 1, "%s: de eieren rollen hoorbaar in de kom (%s)" % [wat, str(later)])
		if soort == "plaat":
			waar(later.has("deur") and later.has("ding"), "%s: de ovendeur en het belletje (%s)" % [wat, str(later)])
		if soort == "verdeel":
			waar(later.has("tover"), "%s: eerlijk verdeeld (%s)" % [wat, str(later)])
			gelijk(int(_oven().get("params", {}).get("rest", 0)), int(b["rest"]), "%s: de rest op de oven" % wat)
		gelijk(str(_bank().get("params", {})), str(Beurt.bank(b, "af")), "%s: het antwoord ligt op tafel" % wat)
		var eind := _bord()
		waar(eind != null and str(eind.p) == str(Beurt.bord(b, "af")), "%s: en groot op het bord" % wat)
		gelijk(_kaart_tekst("Kolom/Regel"), "%s %s" % [Beurt.ICOON_AF, Beurt.af_regel(b)], "%s: de slotzin" % wat)
		gelijk(_kaart_tekst("Kolom/Rij/Som"), str(b["som"]), "%s: onder de som" % wat)
		gelijk(_kaart_tekst("Kolom/Rij/Vak"), str(int(b["goed"])), "%s: met het antwoord erin" % wat)
		waar(_knoop(STROOK) == null, "%s: geen strook meer" % wat)
		waar(_knoop(LEKKER) != null, "%s: de bakker vindt het lekker" % wat)
		gelijk(int(_stand().get("missers", -1)), 1, "%s: één misser" % wat)
		await _wacht(Spel.AF_S + 0.3)
		gelijk(Games.actief(), "", "%s: het spel is vanzelf dicht" % wat)
		gelijk(int(State.s["sterren"]), sterren + 1, "%s: nog steeds één ster" % wat)
		waar(not World.decor_plek(RUST_OVEN, KAMER).is_empty(), "%s: de rustende oven is terug" % wat)
		_af()

## The other three kinds of turn put their own answer on the table: golden
## cookies after the oven (groep 3 and 5), batter in both bowls (groep 4).
func test_elke_soort_legt_zijn_antwoord_neer() -> void:
	alleen_spellen([SPEL])
	for geval in [[3, 3, "koekjes"], [5, 4, "dubbel"], [7, 5, "tafel"]]:
		var n: int = geval[0]
		var band: int = geval[1]
		var soort: String = geval[2]
		var dag := _dag_voor(n, band, soort)
		_op()
		_wereld(n, band, dag)
		var wat := "groep %d (%s)" % [band, soort]
		var b := Beurt.maak(n, band, dag)
		waar(Games.start(SPEL), "%s: het spel start" % wat)
		gelijk(str(_bank().get("params", {})), str(Beurt.bank(b, "som")), "%s: de som op tafel" % wat)
		_kies(int(b["goed"]))
		var sig: Array = State.s["signaal"]
		waar(not sig.is_empty() and int((sig[sig.size() - 1] as Dictionary)["g"]) == 1,
			"%s: in één keer goed telt als goed (State.tel)" % wat)
		if Beurt.bakt(b):
			gelijk(str(_stand().get("stap", "")), "bak", "%s: de plaat gaat de oven in" % wat)
			await _wacht(Spel.IN_S + 0.2)
			waar(bool(_oven().get("params", {}).get("bakt", false)), "%s: de oven gloeit" % wat)
			waar((_bank().get("params", {}) as Dictionary).is_empty(), "%s: de plaat is van de tafel" % wat)
			var bord := _bord()
			waar(bord != null and bool(bord.p.get("oven", false)), "%s: het bord toont de plaat in de oven" % wat)
			await _wacht(Spel.BAK_S)
		else:
			await _wacht(0.2)
		gelijk(str(_stand().get("stap", "")), "af", "%s: af" % wat)
		gelijk(str(_bank().get("params", {})), str(Beurt.bank(b, "af")), "%s: het antwoord op tafel" % wat)
		waar(not bool(_oven().get("params", {}).get("bakt", false)), "%s: de oven is weer rustig" % wat)
		_af()

## A reload in the middle of the question: start, answer wrongly, the save is
## written and read back from the file, and the SAME question is back — the
## same baker, the same sum on the table, the same four numbers in the same
## order, the miss still counted.  A finished turn is not resumed; another day
## is another question.
func test_herladen_geeft_dezelfde_vraag() -> void:
	alleen_spellen([SPEL])
	_op()
	_wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	var gast := str(_stand().get("gast", ""))
	var b := Beurt.maak(4, 4, 2)
	var keuzes := _strook()
	var som := _kaart_tekst("Kolom/Rij/Som")
	_druk(_foute_knop(int(b["goed"])))
	gelijk(int(_stand().get("missers", 0)), 1, "een misser")
	State.start_gekozen()                   # writes user://dierenhotel.json
	waar(State.bewaar(), "de opslag is geschreven")
	Games.stop()
	State.s = State.standaard()
	waar(State.lees(), "en teruggelezen")
	World.sync(State.s["gasten"])
	waar(Games.start(SPEL), "het spel start opnieuw")
	gelijk(typeof(_stand()["missers"]), TYPE_INT, "JSON gaf komma-getallen; ze zijn weer geheel")
	gelijk(int(_stand().get("missers", 0)), 1, "de misser is er nog")
	gelijk(str(_stand().get("gast", "")), gast, "dezelfde bakker")
	gelijk(str(_stand().get("stap", "")), "som", "dezelfde vraag staat er")
	gelijk(_kaart_tekst("Kolom/Rij/Som"), som, "dezelfde som")
	gelijk(str(_strook()), str(keuzes), "met dezelfde vier getallen in dezelfde volgorde")
	gelijk(str(_bank().get("params", {})), str(Beurt.bank(b, "som")), "en hetzelfde op tafel")
	_kies(int(b["goed"]))
	Games.stop()
	waar(Games.start(SPEL), "na het goede antwoord")
	gelijk(int(_stand().get("missers", -1)), 0, "een nieuwe beurt")
	Games.stop()
	State.s["dag"] = 3
	waar(Games.start(SPEL), "de volgende dag")
	gelijk(_kaart_tekst("Kolom/Rij/Som"), str(Beurt.maak(4, 4, 3)["som"]), "de vraag van dag 3")
	# never leave a save file behind for the next test file
	Games.stop()
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("dierenhotel.json")
		dir.remove("dierenhotel.json.tmp")
	State.nieuw_spel()                      # `start_gekozen` off again
	_af()

## The animal picked on the game bar bakes when it may; another baker's
## unfinished turn is simply not finished.
func test_het_gekozen_dier_bakt() -> void:
	alleen_spellen([SPEL])
	_op()
	var gasten := _wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	var eerste := str(_stand().get("gast", ""))
	var lijst: Array = _spel().spelers()
	gelijk(lijst.size(), 4, "vier gasten met een bed mogen bakken")
	var ander := ""
	for g in gasten:
		if str(g["id"]) != eerste:
			ander = str(g["id"])
			break
	State.s["speler"] = ander
	Games.stop()
	waar(Games.start(SPEL), "opnieuw, met een ander dier")
	gelijk(str(_stand().get("gast", "")), ander, "het gekozen dier bakt")
	State.s.erase("speler")
	_af()

func test_zonder_gasten() -> void:
	alleen_spellen([SPEL])
	_op()
	_wereld(0, 0)
	waar(Games.start(SPEL), "het spel start")
	waar(_knoop(LEEG) != null, "het wolkje zegt dat er nog geen gasten zijn")
	await _wacht(Spel.LEEG_S + 0.3)
	gelijk(Games.actief(), "", "en het spel sluit zichzelf")
	_af()

# ------------------------------------------------------- op vier schermen

## The real shell on the four screens, the question and the end: every
## element of the game is inside the frame, finds a real place and is a real
## tap target, and the baker and the table are in sight.
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
		_keur(kader.size, "%s som" % str(maat))
		gelijk(_strook().size(), 4, "%s: vier getallen op de strook" % str(maat))
		var dbg := Hits.debug()
		var gast := str(_stand().get("gast", ""))
		var dier := World.vlak_van_dier(gast)
		var tafel := World.vlak_van(Spel.MODEL_BANK, float(Spel.BANK_X), float(Spel.BANK_Z), 0.0,
			_bank().get("params", {}))
		# where the card docks in the maths bar (not on the landscape phone,
		# where a third of the frame is lower than any card with a sum line)
		# it stands over neither the baker nor the table
		var dok: bool = maat.y >= 400
		if dok:
			gelijk(Ui.balk_kaart(), KAART, "%s: de som staat in de rekenbalk" % str(maat))
		for id in [KAART, STROOK]:
			if not dbg.has(id) or not dok:
				continue
			var r: Rect2 = dbg[id]["rect"]
			if dier.size.x > 0.0:
				waar(not r.has_point(dier.get_center()),
					"%s: %s staat niet over de bakker (%s, %s)" % [str(maat), id, str(r), str(dier)])
			if tafel.size.x > 0.0:
				waar(not r.intersects(tafel),
					"%s: %s staat niet over de tafel (%s, %s)" % [str(maat), id, str(r), str(tafel)])
		# the big board: large enough to count on, inside the frame, and over
		# neither the baker nor the card and its strip
		waar(dbg.has(BORD), "%s: het grote bord staat er" % str(maat))
		if dbg.has(BORD):
			var br: Rect2 = dbg[BORD]["rect"]
			var c := KoekjesBord.cellen(_bord().p)
			waar(br.size.x / c.x >= Spel.CEL_MIN - 0.5, "%s: een koekje op het bord is groot genoeg (%s)"
				% [str(maat), str(br)])
			if dier.size.x > 0.0:
				waar(not br.has_point(dier.get_center()),
					"%s: het bord staat niet over de bakker (%s, %s)" % [str(maat), str(br), str(dier)])
			for id in [KAART, STROOK]:
				if dbg.has(id):
					var andere: Rect2 = dbg[id]["rect"]
					var snij := br.intersection(andere)
					waar(snij.size.x <= 0.5 or snij.size.y <= 0.5,
						"%s: het bord ligt niet over %s (%s, %s)" % [str(maat), id, str(br), str(andere)])
		var b := Beurt.maak(4, 4, 2)
		_kies(int(b["goed"]))
		await _wacht(Spel.IN_S + Spel.BAK_S + 0.4)
		for _f in 3:
			await boom.process_frame
		_keur(kader.size, "%s af" % str(maat))
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
	waar(eigen >= 1, "%s: het spel staat op het scherm (%d)" % [wat, eigen])

# ------------------------------------------- golf 2: rekenen eerst (R1, R2)

var _teller := {"reken": 0, "spel": 0}

## Every tap the test performs, labelled the way R1 counts it: an answer on a
## maths strip is "reken", everything else "spel".
func _tel(soort: String) -> void:
	_teller[soort] = int(_teller.get(soort, 0)) + 1

## R1 (wave 2, owner: "rekenen moet minstens 50% van de interactie zijn"): in a
## whole turn — from the start, the entry tap not counted — the maths taps
## outnumber everything else by at least one, in every group and for a small
## and a large hotel.  A baker's turn needs one tap: the answer on the strip
## (a miss is a maths tap too).
func test_rekenaandeel() -> void:
	alleen_spellen([SPEL])
	for geval in [[1, 3, true], [3, 3, false], [4, 4, false], [6, 4, true], [7, 5, false],
			[8, 5, false]]:
		var n: int = geval[0]
		var band: int = geval[1]
		var mis: bool = geval[2]
		var wat := "groep %d, %d gasten" % [band, n]
		_teller = {"reken": 0, "spel": 0}
		_op()
		_wereld(n, band, 2)
		waar(Games.start(SPEL), "%s: het spel start" % wat)
		var b := Beurt.maak(n, band, 2)
		gelijk(str(_stand().get("stap", "")), "som", "%s: de vraag staat er" % wat)
		if mis:
			_tel("reken")
			_druk(_foute_knop(int(b["goed"])))
			gelijk(str(_stand().get("stap", "")), "som", "%s: een misser rondt niets af" % wat)
			await _wacht(Ui.MIS_PAUZE + 0.25)
		_tel("reken")
		_kies(int(b["goed"]))
		waar(str(_stand().get("stap", "")) != "som", "%s: het goede antwoord rondt af" % wat)
		var reken := int(_teller["reken"])
		var spel := int(_teller["spel"])
		waar(reken >= spel + 1, "%s: R1 reken %d >= spel %d + 1" % [wat, reken, spel])
		_af()

## R2 (wave 2): a question that was answered wrong comes back UNCHANGED after
## any exit — a new day, another band, another hotel size, the animal on the
## game bar — until it is answered right; only then is the next turn new.
func test_een_gemiste_vraag_komt_onveranderd_terug() -> void:
	alleen_spellen([SPEL])
	_op()
	var gasten := _wereld(5, 4, 2)
	waar(Games.start(SPEL), "het spel start")
	var b := Beurt.maak(5, 4, 2)
	var som := _kaart_tekst("Kolom/Rij/Som")
	var keuzes := _strook()
	var bakker := str(_stand().get("gast", ""))
	var ander := ""
	for i in 4:
		if str(gasten[i]["id"]) != bakker:
			ander = str(gasten[i]["id"])
			break
	_druk(_foute_knop(int(b["goed"])))
	gelijk(int(_stand().get("missers", 0)), 1, "een misser")
	await _wacht(Ui.MIS_PAUZE + 0.25)
	for stap in ["een nieuwe dag", "een andere band", "een gast minder", "het dier op de balk"]:
		Games.stop()
		match stap:
			"een nieuwe dag":
				State.s["dag"] = 3
				World.zet_dag(3)
			"een andere band":
				State.s["kunnen"] = 2
				gelijk(State.band(), 3, "nu groep 3")
			"een gast minder":
				(State.s["gasten"] as Array).pop_back()
				World.sync(State.s["gasten"])
			_:
				State.s["speler"] = ander
		waar(Games.start(SPEL), "%s: het spel start" % stap)
		gelijk(str(_stand().get("stap", "")), "som", "%s: de vraag staat nog open" % stap)
		gelijk(int(_stand().get("missers", 0)), 1, "%s: met zijn misser" % stap)
		gelijk(_kaart_tekst("Kolom/Rij/Som"), som, "%s: dezelfde som" % stap)
		gelijk(str(_strook()), str(keuzes), "%s: dezelfde vier getallen" % stap)
	gelijk(str(_stand().get("gast", "")), ander, "het gekozen dier bakt, aan dezelfde vraag")
	_kies(int(b["goed"]))
	waar(str(_stand().get("stap", "")) != "som", "nu goed")
	Games.stop()
	State.s.erase("speler")
	waar(Games.start(SPEL), "na het goede antwoord")
	gelijk(int(_stand().get("missers", -1)), 0, "een nieuwe beurt")
	gelijk(int(_stand().get("dag", -1)), 3, "van vandaag")
	_af()
