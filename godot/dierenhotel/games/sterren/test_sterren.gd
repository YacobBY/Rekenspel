extends Proef
## sterren — Sterren tellen op het dakterras (U3), headless.
##
## The pure turn logic of `beurt.gd` for every band, every number of guests and
## many turns; the telescope's view (`SterrenKijker`) through its public
## getters; the room on top of the tower and its models; and whole turns driven
## the way a child drives them: an answer is a `pressed` on a button of the
## real strip under the card.

const SPEL := "sterren"
const KAMER := "dakterras"
const KAART := "st_som"
const STROOK := "st_som_keuzes"
const KIJKER := "st_kijker"
const LEEG := "st_leeg"
const TELESCOOP := "st_telescoop"
const RUST := "rust_st_telescoop"
const Beurt := preload("res://games/sterren/beurt.gd")
const Spel := preload("res://games/sterren/spel.gd")
const Dak := preload("res://art/decor_dak.gd")

const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740),
	Vector2i(740, 360)]
const SOORTEN := ["patroon", "samen", "tot_tien", "rijen", "dubbel", "tientallen",
	"honderden", "rijen_van"]

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

## `n` guests from the pool, each in a real bed; `kunnen` lifts the adaptive
## cap so the band really is the band the test asks for.
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

func _kijker() -> SterrenKijker:
	return _knoop(KIJKER) as SterrenKijker

## The turn the running game asks, as the game itself rebuilt it.
func _beurt() -> Dictionary:
	var spel := _spel()
	return spel.beurt() if spel != null else {}

func _wacht(s: float) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	await boom.create_timer(s).timeout

func _foute_keuze(goed: int) -> String:
	for k in _strook():
		if k != "Kn%d" % goed:
			return k
	return ""

func _zin_ok(zin: String) -> bool:
	var woorden := zin.strip_edges().split(" ", false)
	return woorden.size() <= 8 and zin.length() <= 40

# ------------------------------------------------------------- het rekenen

func test_patronen_kloppen() -> void:
	for k in range(1, 7):
		var p := Beurt.patroon("dobbel", k)
		gelijk(int(p["k"]), k, "dobbelsteen %d heeft %d ogen" % [k, k])
		var uniek := {}
		for c in p["cellen"]:
			uniek[c] = true
			waar((c as Vector2i).x >= 0 and (c as Vector2i).x < 3, "dobbel %d: in het 3×3 rooster" % k)
		gelijk(uniek.size(), k, "dobbel %d: elke oog op een eigen plek" % k)
		gelijk(int(p["hoog"]), 3, "dobbel %d: drie rijen hoog" % k)
	for k in range(0, 11):
		var p := Beurt.patroon("tien", k)
		gelijk(int(p["k"]), k, "tienveld %d" % k)
		gelijk(int(p["breed"]), 5, "een tienveld is vijf breed")
		gelijk((p["leeg"] as Array).size(), 10 - k, "tienveld %d: %d lege vakjes" % [k, 10 - k])
		var vakjes := {}
		for c in (p["cellen"] as Array) + (p["leeg"] as Array):
			waar((c as Vector2i).y < 2, "tienveld %d: twee rijen" % k)
			vakjes[c] = true
		gelijk(vakjes.size(), 10, "tienveld %d: samen precies tien vakjes" % k)
	var rij := Beurt.patroon("rij", 15, 5)
	gelijk(int(rij["k"]), 15, "3 rijen van 5 = 15 cellen")
	gelijk(int(rij["breed"]), 5, "de rij is 5 breed")
	gelijk(int(rij["hoog"]), 3, "drie rijen hoog")
	var honderd := Beurt.patroon("honderd", 100)
	gelijk(int(honderd["waarde"]), 100, "een blok van honderd telt honderd")
	gelijk(Beurt.aantal([honderd, Beurt.patroon("tien", 10), Beurt.patroon("dobbel", 4)]), 114, "100 + 10 + 4")
	gelijk(Beurt.vorm_voor(6), "dobbel", "tot zes een dobbelsteen")
	gelijk(Beurt.vorm_voor(7), "tien", "vanaf zeven een tienveld")
	gelijk(Beurt.cijfers(99), 2, "twee cijfers tot 99")
	gelijk(Beurt.cijfers(100), 3, "drie vanaf 100")

## Every band, 1..8 guests, twelve turns, three seeds: the answer is what the
## patterns show, the sentence follows HOTEL.md §9, the near distractors are
## sound and the numbers stay in the band's range (IDEAS.md).
func test_elke_groep_elke_beurt_is_een_kloppende_som() -> void:
	var gezien := {}
	for band in [3, 4, 5]:
		for n in range(1, 9):
			for nr in 12:
				for zaad in [Beurt.ZAAD, Beurt.ZAAD + 1, Beurt.ZAAD + 2]:
					var b := Beurt.maak(band, n, nr, zaad)
					var wat := "groep %d, N %d, beurt %d, zaad %d (%s)" % [band, n, nr, zaad, b["soort"]]
					gezien[b["soort"]] = true
					var som := Beurt.aantal(b["patronen"])
					if b["soort"] == "tot_tien":
						gelijk(int(b["goed"]), 10 - som, wat + ": erbij tot tien")
						var leeg := 0
						for p in b["patronen"]:
							leeg += ((p as Dictionary)["leeg"] as Array).size()
						gelijk(leeg, int(b["goed"]), wat + ": zoveel lege vakjes als er erbij moeten")
					else:
						gelijk(int(b["goed"]), som, wat + ": het antwoord is wat er hangt")
					waar(int(b["goed"]) >= 1, wat + ": minstens één")
					var grens := 20 if band == 3 else (100 if band == 4 else 399)
					waar(int(b["goed"]) <= grens, wat + ": binnen de groep (%d ≤ %d)" % [int(b["goed"]), grens])
					var zin := Beurt.zin(b)
					waar(_zin_ok(zin), wat + ": de zin is kort (%s)" % zin)
					waar(zin.begins_with(Beurt.ICOON + " "), wat + ": pictogram eerst")
					waar(not str(b["regel"]).contains(Beurt.ICOON), wat + ": de kaart zet het pictogram er zelf voor")
					gelijk(Ui.mist_tekens(zin).size(), 0, wat + ": elk teken is in de letters")
					waar(b["patronen"].size() >= 1, wat + ": er hangt iets")
					if band == 3:
						waar(b["patronen"].size() <= 2, wat + ": hooguit twee sterrenbeelden")
					for l in b["liever"]:
						waar(int(l) > 0 and int(l) != int(b["goed"]), wat + ": afleider %d deugt" % int(l))
					waar(b["liever"].size() >= 1 and b["liever"].size() <= 3, wat + ": één tot drie afleiders")
					waar(Beurt.keur(b, int(b["goed"])), wat + ": het goede antwoord keurt")
					waar(not Beurt.keur(b, int(b["goed"]) + 1), wat + ": één te veel keurt niet")
					# the strip of four the card will hold (`Ui._getal_keuzes`)
					var plafond := int(pow(10, Beurt.cijfers(int(b["goed"])))) - 1
					var vier := Afleiders.vier(int(b["goed"]), 17, {"min": 1, "max": plafond, "liever": b["liever"]})
					gelijk(vier.size(), 4, wat + ": vier getallen op de strook")
					waar(vier.has(int(b["goed"])), wat + ": het goede getal staat erbij")
					for v in vier:
						waar(v >= 1 and v <= plafond, wat + ": %d past in het vakje" % v)
	for s in SOORTEN:
		waar(gezien.has(s), "soort %s komt voor" % s)

func test_dezelfde_dag_dezelfde_vraag() -> void:
	var a := Beurt.maak(4, 3, 5, Beurt.ZAAD + 9)
	var b := Beurt.maak(4, 3, 5, Beurt.ZAAD + 9)
	gelijk(a, b, "dezelfde argumenten geven dezelfde beurt")
	gelijk(Beurt.soort(3, 1, 1), "patroon", "met één gast geen 'samen'")
	gelijk(Beurt.soort(3, 2, 1), "samen", "met twee gasten wel")
	gelijk(Beurt.soort(5, 4, 2), "rijen_van", "groep 5, derde beurt: rijen van")

# -------------------------------------------------------------- aanmelding

## The directory scan finds the game; it lives on the roof, its button hangs on
## the resting telescope, it brings its own model, and its task card is short.
func test_de_definitie_op_het_dakterras() -> void:
	waar(Games.lijst().has(SPEL), "de mapscan vindt sterren")
	var d := Games.definitie(SPEL)
	gelijk(str(d.get("kamer", "")), KAMER, "het spel staat op het dakterras")
	gelijk(d.get("stub", true), false, "geen stub meer: de beurt loopt van begin tot eind")
	var hs: Dictionary = d.get("hotspot", {})
	gelijk(str(hs.get("obj", "")), RUST, "de knop hangt aan de telescoop")
	gelijk(str(hs.get("rust", "")), RUST, "aan de rustende telescoop")
	gelijk(str(hs.get("icoon", "")), Beurt.ICOON, "pictogram")
	gelijk(str(hs.get("label", "")), Beurt.T_KNOP, "pictogram én woord")
	waar((d.get("modellen", {}) as Dictionary).has(Spel.MODEL), "het telescoopmodel wordt aangemeld")
	waar(Art.heeft_model(Spel.MODEL), "en Art kent het")
	var rust: Array = d.get("rust", [])
	gelijk(rust.size(), 1, "één rustspul: de telescoop")
	gelijk(str((rust[0] as Dictionary).get("id", "")), RUST, "met het id van de knop")
	var taak: Dictionary = d.get("taak", {})
	gelijk(str(taak.get("id", "")), "sterren", "taak id")
	gelijk(str(taak.get("kamer", "")), KAMER, "het briefje zegt: op het dakterras")
	waar(Ui.keur_taak("sterren", str(taak.get("tekst", ""))), "het briefje heeft ≤ 6 woorden")
	var unlock: Callable = d["unlock"]
	waar(not unlock.call(0, 3), "zonder gasten niet")
	waar(unlock.call(1, 3), "vanaf de eerste gast")

func test_het_dakterras_is_de_top_van_de_toren() -> void:
	var r := Rooms.get_kamer(KAMER)
	waar(r != null, "het dakterras bestaat")
	if r == null:
		return
	gelijk(r.etage, 4, "verdieping 4, boven de speelzaal")
	waar(r.erf, "buiten, onder de hemel")
	waar(r.nacht, "en het is er nacht: de vloer tekent de sterrenhemel")
	for id in Rooms.lijst():
		if id != KAMER:
			waar(not Rooms.get_kamer(id).nacht, "%s blijft overdag" % id)
	gelijk(Rooms.etages()[0], 4, "de bovenste verdieping van de toren")
	gelijk(Rooms.trap_richtingen(KAMER), ["af"] as Array[String], "alleen een trap omlaag")
	gelijk(Rooms.trap_naar(KAMER, "af"), "speelzaal", "omlaag naar de speelzaal")
	gelijk(Rooms.trap_naar("speelzaal", "op"), KAMER, "de speelzaal heeft weer een trap omhoog")
	gelijk(Rooms.trap_richtingen("speelzaal"), ["op", "af"] as Array[String], "beide vluchten in de speelzaal")
	waar(r.zones.has("sterren"), "de zone voor de telescoop")
	waar(Rooms.pad("receptie", KAMER).size() >= 2, "je komt er vanaf de receptie")
	# additive: after every room that was there (the winkels were the last one
	# before 2026-10-07); the sibling rooms of that day stand around it
	waar(Rooms.lijst().find(KAMER) > Rooms.lijst().find("winkels"),
		"achter de kamers die er al waren (additief)")
	# the telescope's corner: no wander place, no bought furniture, and the
	# place of the animal of the turn is in it
	waar(Rooms._in_mijd(r, Spel.TELESCOOP_X, Spel.TELESCOOP_Z, 0.0), "de telescoop staat in zijn eigen hoek")
	waar(Rooms._in_mijd(r, Spel.GAST_X, Spel.GAST_Z, 0.0), "de plek van het dier ook")
	for p in r.plekken:
		waar(not Rooms._in_mijd(r, float(p[0]), float(p[1]), 0.0), "geen loopplek bij de telescoop (%s)" % str(p))
	waar(not Rooms.vrij_vak(KAMER, Spel.TELESCOOP_X, Spel.TELESCOOP_Z), "er kan geen meubel op de telescoop")
	waar(r.plekken.size() >= 8, "genoeg loopplekken op het dek (%d)" % r.plekken.size())

## Every model of the deck bakes to voxels at every scale; the telescope is
## taller than a guest, so its button has something to hang on, and it stands
## inside its corner of the deck.
func test_de_modellen_van_het_dak_bakken() -> void:
	var t: Dictionary = Dak.tabel()
	gelijk(t.keys().size(), Dak.NAMEN.size(), "evenveel modellen als namen")
	for naam in Dak.NAMEN:
		waar(t.has(naam), "tabel kent %s" % naam)
		var v: Array = (t[naam] as Callable).call({})
		waar(v.size() > 10, "%s heeft voxels (%d)" % [naam, v.size()])
		for vox in v.slice(0, 5):
			var d: Dictionary = vox
			waar(d.has("x") and d.has("y") and d.has("z") and d.has("k"), "%s: voxel {x,y,z,k}" % naam)
	for g in [2, 3, 4]:
		var p = Art.plaat(Spel.MODEL, g)
		waar(p != null and p.w > 0 and p.h > 0, "de telescoop bakt op g=%d" % g)
	var hoog := 0
	var x0 := 999
	var x1 := -999
	var z0 := 999
	var z1 := -999
	for vox in Dak.telescoop():
		hoog = maxi(hoog, int(vox["y"]))
		if int(vox["y"]) == 0:
			x0 = mini(x0, int(vox["x"]))
			x1 = maxi(x1, int(vox["x"]))
			z0 = mini(z0, int(vox["z"]))
			z1 = maxi(z1, int(vox["z"]))
	waar(hoog >= 24, "de telescoop is hoger dan een gast (%d)" % hoog)
	var r := Rooms.get_kamer(KAMER)
	for hoek in [Vector2(x0, z0), Vector2(x1, z1)]:
		var p: Vector2 = hoek + Vector2(Spel.TELESCOOP_X, Spel.TELESCOOP_Z)
		waar(Rooms._in_mijd(r, p.x, p.y, 0.0), "de poten staan in de hoek van de telescoop (%s)" % str(p))

# ------------------------------------------------------------- de kijker

## The telescope's view shows exactly the stars of the turn — every soort, in
## its patterns, nothing else — each pattern in its own place inside the rim.
func test_de_kijker_toont_de_patronen() -> void:
	var gezien := {}
	for band in [3, 4, 5]:
		for n in [1, 2, 4, 8]:
			for nr in 6:
				var b := Beurt.maak(band, n, nr, Beurt.ZAAD + 3)
				var wat := "groep %d, N %d, beurt %d (%s)" % [band, n, nr, b["soort"]]
				gezien[b["soort"]] = true
				var kijker := SterrenKijker.new()
				var verhouding := SterrenKijker.verhouding(b["patronen"])
				waar(verhouding >= SterrenKijker.VERHOUDING_MIN and verhouding <= SterrenKijker.VERHOUDING_MAX,
					wat + ": een redelijke vorm (%.2f)" % verhouding)
				kijker.meet = func() -> Vector2: return Vector2(420.0, floorf(420.0 / verhouding))
				kijker.zet(b["patronen"])
				gelijk(kijker.size, Vector2(420.0, floorf(420.0 / verhouding)), wat + ": de maat van het spel")
				gelijk(kijker.aantal_patronen(), (b["patronen"] as Array).size(), wat + ": elk patroon")
				gelijk(kijker.waarde(), Beurt.aantal(b["patronen"]), wat + ": wat de sterren samen tellen")
				var cellen := 0
				var leeg := 0
				for p in b["patronen"]:
					cellen += ((p as Dictionary)["cellen"] as Array).size()
					leeg += ((p as Dictionary)["leeg"] as Array).size()
				gelijk(kijker.aantal_sterren(), cellen, wat + ": elke ster en niet meer")
				gelijk(kijker.aantal_leeg(), leeg, wat + ": de lege vakjes")
				if b["soort"] == "tot_tien":
					gelijk(kijker.aantal_leeg(), int(b["goed"]), wat + ": zoveel lege vakjes als er erbij moeten")
					gelijk(kijker.aantal_sterren() + kijker.aantal_leeg(), 10, wat + ": samen een tienveld")
				else:
					gelijk(kijker.waarde(), int(b["goed"]), wat + ": de sterren zijn het antwoord")
				var vormen := kijker.vormen()
				for j in vormen.size():
					gelijk(vormen[j], str((b["patronen"][j] as Dictionary)["vorm"]), wat + ": vorm %d" % j)
				var vakken := kijker.indeling()
				gelijk(vakken.size(), kijker.aantal_patronen(), wat + ": een plek per patroon")
				var binnen := Rect2(Vector2.ZERO, kijker.size).grow(-2.0)
				for i in vakken.size():
					waar(binnen.encloses(vakken[i]), wat + ": patroon %d binnen de rand (%s)" % [i, str(vakken[i])])
					waar(vakken[i].size.x >= 8.0, wat + ": patroon %d is te zien" % i)
					for j in range(i + 1, vakken.size()):
						waar(not vakken[i].intersects(vakken[j]), wat + ": patroon %d en %d liggen los" % [i, j])
				kijker.free()
	for s in SOORTEN:
		waar(gezien.has(s), "de kijker toonde %s" % s)

## The view is not a button, and it lights up after the right answer.
func test_de_kijker_is_geen_knop_en_glanst() -> void:
	var kijker := SterrenKijker.new()
	gelijk(kijker.mouse_filter, Control.MOUSE_FILTER_IGNORE, "een tik gaat erdoorheen")
	kijker.meet = func() -> Vector2: return Vector2(300.0, 180.0)
	gelijk(kijker.inhoud_maat(), Vector2(300.0, 180.0), "Hits vraagt de maat aan het spel")
	gelijk(kijker.glans, 0.0, "nog niet verlicht")
	kijker.juich()
	waar(kijker.glans > 0.0, "na het goede antwoord lichten de sterren op")
	kijker.free()

# ------------------------------------------------------------- de zinnen

## Every sentence the child reads fits the card rules (HOTEL.md §9) and every
## character is in the font subset.
func test_elke_zin_past() -> void:
	if Ui.thema == null or Ui.thema.default_font == null:
		Ui._bouw_thema(17)
	var zinnen: Array = [Beurt.T_PATROON, Beurt.T_SAMEN, Beurt.T_TOT_TIEN, Beurt.T_DUBBEL,
		Beurt.T_BIJ_ELKAAR, Beurt.T_RIJEN % [10, 10], Beurt.T_RIJEN % [9, 9]]
	for zin in zinnen:
		var heel := "%s %s" % [Beurt.ICOON, zin]
		waar(Ui.keur_regel(SPEL, zin), "past: %s" % zin)
		waar(_zin_ok(heel), "past met pictogram: %s" % heel)
	waar(Ui.keur_taak(SPEL, Beurt.T_TAAK), "het briefje: %s" % Beurt.T_TAAK)
	var alles: Array = zinnen + [Beurt.ICOON, Beurt.T_KNOP, Beurt.T_TAAK, Beurt.T_LEEG, "🛏",
		Rooms.get_kamer(KAMER).naam, Rooms.get_kamer(KAMER).icoon, "0123456789"]
	for zin in alles:
		gelijk(Ui.mist_tekens(str(zin)).size(), 0, "elk teken staat in de fontsubset: %s" % zin)

# ------------------------------------------------------------ een hele beurt

## A whole turn per band through the real strip: the animal stands beside the
## telescope, the view shows the turn's stars, the card asks; one wrong number
## first — the animal sulks, nothing else changes, the same four numbers come
## back — then the right one: the tick, one star, the stars light up, every
## animal on the roof looks up, the adaptive signal, and the game closes.
func test_een_beurt_per_band() -> void:
	for geval in [[2, 3], [4, 4], [8, 5]]:
		var n: int = geval[0]
		var band: int = geval[1]
		_op()
		_wereld(n, band)
		var sterren := int(State.s["sterren"])
		var signaal := (State.s["signaal"] as Array).size()
		waar(Games.start(SPEL), "band %d: het spel start" % band)
		gelijk(World.kamer_nu(), KAMER, "band %d: de camera staat op het dak" % band)
		waar(not World.decor_plek(TELESCOOP, KAMER).is_empty(), "band %d: de telescoop staat er" % band)
		waar(World.decor_plek(RUST, KAMER).is_empty(), "band %d: de rustende telescoop is weg" % band)
		gelijk(str(_stand().get("stap", "")), "som", "band %d: de vraag" % band)
		var b := _beurt()
		gelijk(b, Beurt.maak(band, n, 0, Beurt.ZAAD + 2), "band %d: de beurt komt uit het zaad" % band)
		var gast := str(_stand().get("gast", ""))
		var d = World.dier(gast)
		waar(d != null and d.kamer == KAMER, "band %d: het dier van de beurt is op het dak" % band)
		if d != null:
			waar(absf(d.x - Spel.GAST_X) + absf(d.z - Spel.GAST_Z) <= 3.0, "band %d: naast de telescoop" % band)
		gelijk(Games.speler(), gast, "band %d: de spelbalk toont het dier" % band)
		gelijk(_kaart_tekst("Kolom/Regel"), Beurt.zin(b), "band %d: de vraag op de kaart" % band)
		gelijk(_kaart_tekst("Kolom/Rij/Som"), "", "band %d: geen som: de sterren zijn de som" % band)
		var kijker := _kijker()
		waar(kijker != null, "band %d: de kijker toont de hemel groot" % band)
		if kijker != null:
			gelijk(kijker.waarde(), Beurt.aantal(b["patronen"]), "band %d: dezelfde sterren als de beurt" % band)
			gelijk(kijker.aantal_patronen(), (b["patronen"] as Array).size(), "band %d: dezelfde patronen" % band)
		var keuzes := _strook()
		var goed := int(b["goed"])
		gelijk(keuzes.size(), 4, "band %d: vier getallen (%s)" % [band, str(keuzes)])
		waar(keuzes.has("Kn%d" % goed), "band %d: het goede getal staat erbij (%s)" % [band, str(keuzes)])
		# one miss: the animal sulks, nothing else changes
		var voor := beeld(SPEL)
		_druk(_foute_keuze(goed))
		gelijk(str(_stand().get("stap", "")), "som", "band %d: een misser, dezelfde vraag" % band)
		gelijk(int(_stand().get("missers", 0)), 1, "band %d: de misser is geteld" % band)
		waar(is_sip(gast), "band %d: het dier is teleurgesteld" % band)
		waar(mis_wolk(KAART, gast), "band %d: 🔄 Nog een keer" % band)
		gelijk(_kaart_tekst("Kolom/Hulp"), "", "band %d: geen hulpregel" % band)
		gelijk(int(State.s["sterren"]), sterren, "band %d: een misser kost niets" % band)
		await _wacht(Ui.MIS_PAUZE + 0.25)
		niets_erbij(voor, beeld(SPEL), "band %d" % band)
		gelijk(str(_strook()), str(keuzes), "band %d: dezelfde vier getallen" % band)
		if kijker != null:
			gelijk(kijker.glans, 0.0, "band %d: de sterren lichten niet op na een misser" % band)
		# the right one
		var hoor := Snd.luister(func() -> void: _druk("Kn%d" % goed))
		waar(hoor.has("ja"), "band %d: het klopt, hoorbaar (%s)" % [band, str(hoor)])
		gelijk(str(_stand().get("stap", "")), "af", "band %d: goed geteld" % band)
		gelijk(int(State.s["sterren"]), sterren + 1, "band %d: één ster voor het meedoen" % band)
		gelijk(_kaart_tekst("Kolom/Rij/Vak"), str(goed), "band %d: het antwoord in het vakje" % band)
		var sig: Array = State.s["signaal"]
		gelijk(sig.size(), signaal + 1, "band %d: één keer geteld voor het niveau" % band)
		gelijk(int((sig.back() as Dictionary)["g"]), 0, "band %d: niet de eerste keer goed" % band)
		gelijk(int(State.spel_data(SPEL).get("beurt_nr", 0)), 1, "band %d: de volgende beurt is een andere" % band)
		if kijker != null:
			waar(kijker.glans > 0.0, "band %d: de sterren lichten op" % band)
		for dier in World.dieren(KAMER):
			gelijk(str(dier.pose), "kijk", "band %d: %s kijkt omhoog" % [band, dier.id])
		await _wacht(Spel.AF_S + 0.3)
		gelijk(Games.actief(), "", "band %d: het spel sluit zichzelf" % band)
		waar(not World.decor_plek(RUST, KAMER).is_empty(), "band %d: de telescoop rust weer op het dak" % band)
		_af()

## First time right: the adaptive signal says so.  The star is paid once a
## day; a second turn the same day still ticks and still counts.
func test_meteen_goed_en_een_tweede_beurt() -> void:
	_op()
	_wereld(4, 4)
	var sterren := int(State.s["sterren"])
	waar(Games.start(SPEL), "het spel start")
	var b := _beurt()
	var eerste := str(_stand().get("gast", ""))
	_druk("Kn%d" % int(b["goed"]))
	var sig: Array = State.s["signaal"]
	gelijk(int((sig.back() as Dictionary)["g"]), 1, "meteen goed")
	gelijk(int(State.s["sterren"]), sterren + 1, "één ster")
	await _wacht(Spel.AF_S + 0.3)
	gelijk(Games.actief(), "", "dicht")
	var d = World.dier(eerste)
	waar(d != null and d.kamer == KAMER, "het dier van de eerste beurt is nog op het dak")
	waar(Games.start(SPEL), "nog een keer")
	var tweede := str(_stand().get("gast", ""))
	waar(tweede != eerste, "nu kijkt een ander dier (%s, %s)" % [eerste, tweede])
	# the one of the first turn steps aside: the telescope is the new one's
	d = World.dier(eerste)
	if d != null and d.kamer == KAMER:
		waar(absf(d.x - Spel.GAST_X) + absf(d.z - Spel.GAST_Z) >= Spel.PLEK_VRIJ,
			"%s stapt opzij (%s, %s)" % [eerste, d.x, d.z])
	var nu = World.dier(tweede)
	waar(nu != null and absf(nu.x - Spel.GAST_X) + absf(nu.z - Spel.GAST_Z) <= 3.0,
		"%s staat bij de telescoop" % tweede)
	var b2 := _beurt()
	waar(str(b2["soort"]) != str(b["soort"]), "de tweede beurt vraagt iets anders (%s, %s)" % [b["soort"], b2["soort"]])
	_druk("Kn%d" % int(b2["goed"]))
	gelijk(int(State.s["sterren"]), sterren + 1, "geen tweede ster op één dag")
	gelijk(str(_stand().get("stap", "")), "af", "maar wel goed geteld")
	_af()

## A reload in the middle of a question shows the same sky and asks the same
## question with the same four numbers; floats from the JSON are numbers again;
## the next day is another sky.
func test_herladen_toont_dezelfde_hemel() -> void:
	_op()
	_wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	var b := _beurt()
	var keuzes := _strook()
	var sterren_in_beeld := _kijker().aantal_sterren() if _kijker() != null else -1
	_druk(_foute_keuze(int(b["goed"])))
	await _wacht(Ui.MIS_PAUZE + 0.25)
	Games.stop()
	gelijk(str(_stand().get("stap", "")), "som", "de vraag is bewaard")
	gelijk(int(_stand().get("missers", 0)), 1, "met zijn misser")
	# what a reload does: the save goes through JSON, every number a float
	var tekst := JSON.stringify(State.s)
	var terug = JSON.parse_string(tekst)
	waar(typeof(terug) == TYPE_DICTIONARY, "de opslag is JSON")
	State.s["spel"] = (terug as Dictionary).get("spel", State.s.get("spel", {}))
	gelijk(typeof(_stand().get("N", 0)), TYPE_FLOAT, "na JSON is N een kommagetal")
	waar(Games.start(SPEL), "opnieuw gestart")
	gelijk(typeof(_stand()["N"]), TYPE_INT, "N is weer een geheel getal")
	gelijk(_beurt(), b, "dezelfde beurt")
	gelijk(_kaart_tekst("Kolom/Regel"), Beurt.zin(b), "dezelfde vraag")
	gelijk(str(_strook()), str(keuzes), "dezelfde vier getallen in dezelfde volgorde")
	var kijker := _kijker()
	waar(kijker != null and kijker.aantal_sterren() == sterren_in_beeld, "dezelfde sterren in de kijker")
	gelijk(int(_stand().get("missers", 0)), 1, "de misser telt nog mee")
	# wave 2, R2: a missed question waits for its right answer, also across a
	# new day — so answer it first, then the next day is another sky
	_druk("Kn%d" % int(b["goed"]))
	gelijk(str(_stand().get("stap", "")), "af", "nu goed geteld")
	Games.stop()
	State.s["dag"] = 3
	waar(Games.start(SPEL), "de volgende dag")
	gelijk(int(_stand().get("missers", -1)), 0, "een nieuwe beurt")
	gelijk(int(_stand().get("zaad", 0)), Beurt.ZAAD + 3, "met de hemel van vandaag")
	_af()

## Nobody with a bed: the telescope says there are no guests yet and closes.
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

## The resting telescope stands on the deck while nobody plays and the entry
## hangs ON it; a turn takes it away and puts its own there; afterwards it rests
## again.
func test_de_rustende_telescoop() -> void:
	_op()
	_wereld(3, 3)
	World.naar(KAMER)
	Games.hersteek()
	var rust := World.decor_plek(RUST, KAMER)
	waar(not rust.is_empty(), "de telescoop staat op het dak als er niet gespeeld wordt")
	gelijk(float(rust.get("x", 0)), Spel.TELESCOOP_X, "op zijn plek")
	var knop := Hits.spot("spel_" + SPEL)
	waar(knop != null, "de knop hangt in het dakterras")
	if knop != null:
		gelijk(knop.obj, RUST, "aan de telescoop")
	waar(Games.start(SPEL), "het spel start")
	waar(World.decor_plek(RUST, KAMER).is_empty(), "het rustspul gaat weg")
	waar(not World.decor_plek(TELESCOOP, KAMER).is_empty(), "de eigen telescoop staat er")
	Games.stop()
	waar(World.decor_plek(TELESCOOP, KAMER).is_empty(), "na het spel is de eigen telescoop weg")
	waar(not World.decor_plek(RUST, KAMER).is_empty(), "en rust de telescoop er weer")
	_af()

# ------------------------------------------------------- op vier schermen

## The real shell on the four screens: every element of the game is inside the
## frame and finds a real place, the view stands clear of the card and its
## strip, and neither the animal of the turn nor the telescope hides behind it.
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
		for _f in 6:
			await boom.process_frame
		var kader: Control = shell.get_node("Scherm/Kolom/Middenrij/Kaderdoos/Kader")
		_keur(kader.size, str(maat))
		gelijk(_strook().size(), 4, "%s: vier getallen op de strook" % str(maat))
		var dbg := Hits.debug()
		waar(dbg.has(KIJKER), "%s: de kijker staat er" % str(maat))
		if dbg.has(KIJKER):
			var b: Rect2 = dbg[KIJKER]["rect"]
			waar(b.size.x >= Spel.KIJKER_MIN - 0.5, "%s: de kijker is groot (%s)" % [str(maat), str(b)])
			var gast := str(_stand().get("gast", ""))
			var dier := World.vlak_van_dier(gast)
			if dier.size.x > 0.0:
				waar(not b.has_point(dier.get_center()),
					"%s: het dier staat niet achter de kijker (%s, %s)" % [str(maat), str(b), str(dier)])
			var tele := World.vlak_van(Spel.MODEL, Spel.TELESCOOP_X, Spel.TELESCOOP_Z, 0.0)
			if tele.size.x > 0.0:
				waar(not b.has_point(tele.get_center()),
					"%s: de telescoop staat niet achter de kijker (%s, %s)" % [str(maat), str(b), str(tele)])
			for id in [KAART, STROOK]:
				if dbg.has(id):
					var andere: Rect2 = dbg[id]["rect"]
					var snij := b.intersection(andere)
					waar(snij.size.x <= 0.5 or snij.size.y <= 0.5,
						"%s: de kijker ligt niet over %s (%s, %s)" % [str(maat), id, str(b), str(andere)])
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

## Every spot of the game: inside the frame, never `krap`, and a real tap target.
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
		waar(not bool(d["krap"]), "%s: %s vond een echte plek" % [wat, id])
		waar(r.position.x >= -0.01 and r.position.y >= -0.01
			and r.end.x <= kader.x + 0.01 and r.end.y <= kader.y + 0.01,
			"%s: %s staat binnen het kader (%s)" % [wat, id, str(r)])
		if spot.kind == "tag" or int(d["laag"]) == Hits.Laag.VAST:
			continue
		waar(r.size.x >= 44.0 and r.size.y >= 44.0, "%s: %s is een tikdoel" % [wat, id])
	waar(eigen >= 2, "%s: het spel staat op het scherm (%d)" % [wat, eigen])

# ------------------------------------------- golf 2: rekenen eerst (R1, R2)

var _teller := {"reken": 0, "spel": 0}

## Every tap the test performs, labelled the way R1 counts it: an answer on a
## maths strip is "reken", everything else "spel".
func _tel(soort: String) -> void:
	_teller[soort] = int(_teller.get(soort, 0)) + 1

## R1 (wave 2, owner: "rekenen moet minstens 50% van de interactie zijn"): in a
## whole turn — from the start, the entry tap not counted — the maths taps
## outnumber everything else by at least one, in every group and for a small
## and a large hotel.  A turn at the telescope needs one tap: the answer on
## the strip (a miss is a maths tap too).
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
		var b := _beurt()
		gelijk(str(_stand().get("stap", "")), "som", "%s: de vraag staat er" % wat)
		if mis:
			_tel("reken")
			_druk(_foute_keuze(int(b["goed"])))
			gelijk(str(_stand().get("stap", "")), "som", "%s: een misser rondt niets af" % wat)
			await _wacht(Ui.MIS_PAUZE + 0.25)
		_tel("reken")
		_druk("Kn%d" % int(b["goed"]))
		gelijk(str(_stand().get("stap", "")), "af", "%s: het goede antwoord rondt af" % wat)
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
	var b := _beurt()
	var regel := _kaart_tekst("Kolom/Regel")
	var keuzes := _strook()
	var kijker := str(_stand().get("gast", ""))
	var ander := ""
	for i in 4:
		if str(gasten[i]["id"]) != kijker:
			ander = str(gasten[i]["id"])
			break
	_druk(_foute_keuze(int(b["goed"])))
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
		gelijk(_beurt(), b, "%s: dezelfde hemel" % stap)
		gelijk(_kaart_tekst("Kolom/Regel"), regel, "%s: dezelfde vraag" % stap)
		gelijk(str(_strook()), str(keuzes), "%s: dezelfde vier getallen" % stap)
	gelijk(str(_stand().get("gast", "")), ander, "het gekozen dier kijkt, naar dezelfde hemel")
	_druk("Kn%d" % int(b["goed"]))
	gelijk(str(_stand().get("stap", "")), "af", "nu goed")
	Games.stop()
	State.s.erase("speler")
	waar(Games.start(SPEL), "na het goede antwoord")
	gelijk(int(_stand().get("missers", -1)), 0, "een nieuwe beurt")
	gelijk(int(_stand().get("dag", -1)), 3, "van vandaag")
	_af()
