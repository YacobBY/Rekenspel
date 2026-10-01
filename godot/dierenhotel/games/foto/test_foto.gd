extends Proef
## foto — het fotohokje van de Winkelstraat (eigenaar, 2026-10-01), headless.
##
## Driven the way a child drives it: a choice is a `pressed` on a button of the
## real strip under the card — an animal, "Klaar", an amount.  Only the pure
## turn logic in `beurt.gd` is called directly.

const SPEL := "foto"
const KAMER := "winkels"
const KAART := "ft_kaart"
const STROOK := "ft_kaart_keuzes"
const SCHERM := "ft_scherm"
const WEG := "ft_weg"
const LEEG := "ft_leeg"
const HOKJE := "fotohokje"
const Beurt := preload("res://games/foto/beurt.gd")
const Spel := preload("res://games/foto/spel.gd")

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
func _wereld(n: int, band: int, dag := 2, met_bed := -1) -> Array:
	State.nieuw_spel()
	State.s["taken"] = []
	State.s["kunnen"] = 5
	State.s["dag"] = dag
	var pool := State.gasten_pool()
	var bedden := State.alle_bedden()
	var uit: Array = []
	var bed_n := n if met_bed < 0 else met_bed
	for i in n:
		var g: Dictionary = pool[i]
		if i < bedden.size() and i < bed_n:
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
		fout("er is geen keuzestrook")
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

## The animals on the strip, in order (their buttons are `Kd_<id>`).
func _dieren_op_de_strook() -> Array[String]:
	var uit: Array[String] = []
	for k in _strook():
		if k.begins_with("Kd_"):
			uit.append(k.trim_prefix("Kd_"))
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

func _scherm() -> FotoScherm:
	return _knoop(SCHERM) as FotoScherm

func _wacht(s: float) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	await boom.create_timer(s).timeout

## Choose `aantal` animals and "Klaar", then wait for the money question.
func _kies_er(aantal: int) -> Array[String]:
	var gekozen: Array[String] = []
	for i in aantal:
		var vrij := _dieren_op_de_strook()
		if vrij.is_empty():
			fout("geen dier meer op de strook")
			return gekozen
		gekozen.append(vrij[0])
		_druk("Kd_" + vrij[0])
	if _strook().has("Kklaar"):
		_druk("Kklaar")
	await _wacht(Spel.SOM_S + 0.3)
	return gekozen

func _foute_keuze(goed: int) -> String:
	for k in _strook():
		if k != "Kn%d" % goed:
			return k
	return ""

# -------------------------------------------------------------- aanmelding

## The directory scan finds the booth as a game of the arcade: its button hangs
## on the booth at the end of the row of stalls, and it opens from two guests.
func test_aanmelding() -> void:
	waar(Games.lijst().has(SPEL), "de mapscan vindt foto")
	var def := Games.definitie(SPEL)
	gelijk(def.get("naam", ""), "Fotohokje", "naam")
	gelijk(def.get("kamer", ""), KAMER, "het hokje staat in de winkelstraat")
	gelijk(def.get("stub", true), false, "geen stub")
	var hs: Dictionary = def.get("hotspot", {})
	gelijk(hs.get("obj", ""), HOKJE, "de knop hangt aan het fotohokje")
	gelijk(hs.get("icoon", ""), "📸", "icoon")
	gelijk(hs.get("label", ""), "Foto", "label: pictogram én woord")
	var hokje := World.mik(HOKJE, KAMER)
	waar(not hokje.is_empty(), "het fotohokje staat in de winkelstraat")
	var unlock: Callable = def["unlock"]
	waar(not unlock.call(1, 3), "met één gast nog niet: er moeten er minstens twee op")
	waar(unlock.call(2, 3), "vanaf twee gasten wel")
	var kan: Callable = def["kan"]
	waar(not kan.call({"gasten": [{"bed": "b1"}, {"bed": ""}]}), "twee dieren met een bed nodig")
	waar(kan.call({"gasten": [{"bed": "b1"}, {"bed": "b2"}]}), "twee met een bed: het kan")

# ------------------------------------------------------------- het rekenen

## Every band, many days and hotel sizes: one price per animal in the band's
## range (groep 4: its own tables), and for two, three and four animals the sum
## of the band, its answer, and four wrong amounts the strip prefers.
func test_de_prijs_en_de_som() -> void:
	for band in [3, 4, 5]:
		var gezien := {}
		for dag in range(1, 20):
			for n in [2, 3, 4, 6, 8]:
				var p := Beurt.prijs(n, band, dag)
				var wat := "band %d, dag %d, %d gasten" % [band, dag, n]
				gezien[p] = true
				gelijk(p, Beurt.prijs(n, band, dag), "%s: dezelfde dag, dezelfde prijs" % wat)
				match band:
					3: waar(p >= 2 and p <= 5, "%s: €2 … €5 (%d)" % [wat, p])
					4: waar(Beurt.TAFELS_4.has(p), "%s: een tafel van groep 4 (%d)" % [wat, p])
					5: waar(p >= 3 and p <= 9, "%s: €3 … €9 (%d)" % [wat, p])
				for aantal in range(Beurt.MIN_DIEREN, Beurt.MAX_DIEREN + 1):
					var goed := Beurt.goed(aantal, p)
					gelijk(goed, aantal * p, "%s: %d dieren keer de prijs" % [wat, aantal])
					waar(goed <= (20 if band == 3 else 40), "%s: binnen het getallengebied (%d)" % [wat, goed])
					var som := Beurt.som(aantal, p, band)
					if band == 3:
						gelijk(som.count("+"), aantal - 1, "%s: groep 3 telt de prijzen op (%s)" % [wat, som])
						waar(not som.contains("×"), "%s: groep 3 heeft geen keersom" % wat)
					else:
						gelijk(som, "%d × €%d =" % [aantal, p], "%s: de keersom" % wat)
					var vier := Afleiders.vier(goed, Beurt.zaad(n, band, dag, aantal),
						{"min": 1, "max": 99, "liever": Beurt.liever(aantal, p)})
					gelijk(vier.size(), 4, "%s: vier bedragen" % wat)
					waar(vier.has(goed), "%s: het goede bedrag staat erbij" % wat)
		waar(gezien.size() >= 3, "band %d: de prijs verschilt van dag tot dag (%s)" % [band, str(gezien.keys())])

## Every sentence the child reads fits the card rules (HOTEL.md §9) and every
## character is in the font subset.
func test_elke_zin_past() -> void:
	if Ui.thema == null or Ui.thema.default_font == null:
		Ui._bouw_thema(17)
	for zin in ["%s %s" % [Beurt.ICOON, Beurt.T_KIES], "%s %s" % [Beurt.ICOON_GELD, Beurt.T_SOM],
			"%s %s" % [Beurt.ICOON_AF, Beurt.T_AF]]:
		waar(Ui.keur_regel(SPEL, zin), "past: %s" % zin)
	var alles: Array = [Beurt.ICOON, Beurt.ICOON_GELD, Beurt.ICOON_AF, Beurt.ICOON_WEG, Beurt.T_KNOP,
		Beurt.T_KIES, Beurt.T_KLAAR, Beurt.T_SOM, Beurt.T_AF, Beurt.T_WEG, Beurt.T_LEEG, Beurt.T_BLIJ,
		"😍", "€0123456789?"]
	for kind in Hotel.DIER_ICOON:
		alles.append(str(Hotel.DIER_ICOON[kind]))
	for band in [3, 4, 5]:
		alles.append(Beurt.som(4, Beurt.prijs(4, band, 2), band))
	for zin in alles:
		gelijk(Ui.mist_tekens(str(zin)).size(), 0, "elk teken staat in de fontsubset: %s" % zin)

# ------------------------------------------------------------ een hele beurt

## A whole turn per band through the real strips: choose animals (at least
## two: "Klaar" only comes with the second), they walk to the booth, the money
## question, the right amount — the photo and one star.
func test_een_beurt_per_band() -> void:
	for geval in [[2, 3, 2], [4, 4, 3], [8, 5, 4]]:
		var n: int = geval[0]
		var band: int = geval[1]
		var aantal: int = geval[2]
		_op()
		_wereld(n, band)
		var sterren := int(State.s["sterren"])
		waar(Games.start(SPEL), "band %d: het spel start" % band)
		var prijs := Beurt.prijs(n, band, 2)
		gelijk(str(_stand().get("stap", "")), "kies", "band %d: eerst kiezen wie er op de foto gaat" % band)
		gelijk(_kaart_tekst("Kolom/Regel"), "📸 " + Beurt.T_KIES, "band %d: de vraag" % band)
		gelijk(_dieren_op_de_strook().size(), mini(n, Beurt.MAX_DIEREN), "band %d: de dieren op de strook" % band)
		waar(not _strook().has("Kklaar"), "band %d: nog geen Klaar: er moeten er minstens twee op" % band)
		# the screen: two empty frames, each with the price per animal under it
		var sch := _scherm()
		waar(sch != null, "band %d: het scherm van het hokje staat groot in beeld" % band)
		if sch != null:
			gelijk(sch.vakken, 2, "band %d: twee lege vakjes" % band)
			gelijk(sch.dieren.size(), 0, "band %d: nog niemand" % band)
			gelijk(sch.prijs, prijs, "band %d: de prijs per dier staat eronder" % band)
		var eerste := _dieren_op_de_strook()[0]
		_druk("Kd_" + eerste)
		waar(not _dieren_op_de_strook().has(eerste), "band %d: wie gekozen is, gaat van de strook" % band)
		waar(not _strook().has("Kklaar"), "band %d: met één dier nog geen Klaar" % band)
		var d = World.dier(eerste)
		waar(d != null and d.kamer == KAMER, "band %d: het dier loopt naar het hokje" % band)
		var gekozen: Array[String] = [eerste]
		for i in aantal - 1:
			var vrij := _dieren_op_de_strook()
			if vrij.is_empty():
				break
			gekozen.append(vrij[0])
			_druk("Kd_" + vrij[0])
		if aantal < mini(n, Beurt.MAX_DIEREN):
			waar(_strook().has("Kklaar"), "band %d: vanaf twee dieren mag het: Klaar" % band)
			_druk("Kklaar")
		sch = _scherm()
		if sch != null:
			gelijk(sch.dieren.size(), aantal, "band %d: %d dieren op het scherm" % [band, aantal])
			gelijk(sch.vakken, aantal, "band %d: een vakje per dier" % band)
		gelijk(str(_stand().get("dieren", [])), str(gekozen), "band %d: de keuze is bewaard" % band)
		await _wacht(Spel.SOM_S + 0.3)
		gelijk(str(_stand().get("stap", "")), "som", "band %d: nu het geld" % band)
		for i in gekozen.size():
			var dier = World.dier(gekozen[i])
			var plek: Vector2 = Spel.PLEKKEN[i]
			waar(dier != null and dier.kamer == KAMER and Vector2(dier.x, dier.z).distance_to(plek) <= 3.0,
				"band %d: %s staat bij het hokje" % [band, gekozen[i]])
		gelijk(_kaart_tekst("Kolom/Regel"), "💶 " + Beurt.T_SOM, "band %d: hoeveel geld erin moet" % band)
		gelijk(_kaart_tekst("Kolom/Rij/Som"), Beurt.som(aantal, prijs, band), "band %d: de som" % band)
		var goed := aantal * prijs
		gelijk(_strook().size(), 4, "band %d: vier bedragen" % band)
		waar(_strook().has("Kn%d" % goed), "band %d: het goede bedrag staat erbij (%s)" % [band, str(_strook())])
		# the flash comes KLIK_S later, so listen to the band itself until then
		var gehoord: Array[String] = []
		var hoor := func(naam: String) -> void: gehoord.append(naam)
		var was := [Snd._wakker, Snd._uit]
		Snd._wakker = true
		Snd._uit = false
		Snd.gespeeld.connect(hoor)
		_druk("Kn%d" % goed)
		gelijk(str(_stand().get("stap", "")), "af", "band %d: betaald" % band)
		gelijk(int(State.s["sterren"]), sterren + 1, "band %d: één ster voor het meedoen" % band)
		await _wacht(Spel.KLIK_S + 0.2)
		Snd.gespeeld.disconnect(hoor)
		Snd._wakker = bool(was[0])
		Snd._uit = bool(was[1])
		waar(gehoord.has("klik"), "band %d: de sluiter klikt (%s)" % [band, str(gehoord)])
		sch = _scherm()
		waar(sch != null and sch.foto, "band %d: het scherm is nu de foto" % band)
		gelijk(_kaart_tekst("Kolom/Regel"), "✨ " + Beurt.T_AF, "band %d: de slotzin" % band)
		gelijk(_kaart_tekst("Kolom/Rij/Vak"), Beurt.euro(goed), "band %d: met het bedrag erin" % band)
		gelijk(int(_stand().get("missers", -1)), 0, "band %d: geen missers" % band)
		_af()

## Four animals: the strip is empty then, so the money question comes at once —
## no "Klaar" needed; and "Klaar" never works with one animal.
func test_vier_dieren_en_nooit_een() -> void:
	_op()
	_wereld(6, 0)
	waar(Games.start(SPEL), "het spel start")
	var spel := _spel()
	var eerste := _dieren_op_de_strook()[0]
	_druk("Kd_" + eerste)
	spel.klaar()
	gelijk(str(_stand().get("stap", "")), "kies", "met één dier geen foto")
	for i in 3:
		_druk("Kd_" + _dieren_op_de_strook()[0])
	gelijk(str(_stand().get("stap", "")), "som", "vier dieren: meteen naar het geld")
	gelijk((_stand().get("dieren", []) as Array).size(), Beurt.MAX_DIEREN, "vier op de foto")
	_af()

## A wrong amount sends them out of the booth, as in every shop of the street:
## the card goes, they sulk and walk away, the game closes, nothing is taken.
## A tap on the booth brings the same animals and the same four amounts back.
func test_verkeerd_geld_stuurt_ze_weg() -> void:
	_op()
	_wereld(4, 4)
	var sterren := int(State.s["sterren"])
	waar(Games.start(SPEL), "het hokje start")
	var gekozen := await _kies_er(3)
	gelijk(str(_stand().get("stap", "")), "som", "nu het geld")
	var voor := _strook()
	var goed := 3 * Beurt.prijs(4, 4, 2)
	var fout_k := _foute_keuze(goed)
	waar(not fout_k.is_empty(), "er staat een verkeerd bedrag op de strook")
	var was_wakker: bool = Snd._wakker
	Snd._wakker = true
	var gehoord_voor := Snd.gehoord().size()
	_druk(fout_k)
	var nu_gehoord := Snd.gehoord().slice(gehoord_voor)
	Snd._wakker = was_wakker
	var eigen := "%s_sip" % Snd.soort_van(gekozen[0])
	waar(nu_gehoord.has(eigen), "het eerste dier zegt het met zijn eigen sip geluidje (%s)" % str(nu_gehoord))
	waar(_knoop(KAART) == null and _knoop(STROOK) == null, "de kaart en de strook zijn meteen weg")
	gelijk(int(_stand().get("weg", 0)), 1, "ze moeten het hokje uit")
	gelijk(str(_stand().get("stap", "")), "som", "de vraag blijft staan")
	gelijk(int(_stand().get("missers", 0)), 1, "de misser is geteld")
	for id in gekozen:
		waar(is_sip(id), "%s is teleurgesteld" % id)
	waar(_knoop(WEG) != null, "met 😞 Dat klopt niet")
	gelijk(Games.actief(), SPEL, "het spel loopt nog: ze moeten nog weglopen")
	for id in Hits.lijst():
		var s = Hits.spot(id)
		if s != null and s.door == SPEL:
			waar(str(id) == WEG or str(id) == SCHERM, "na de misser staat er niets anders (%s)" % id)
	await _wacht(Spel.SIP_S + Spel.WEG_WACHT + 0.8)
	gelijk(Games.actief(), "", "weg: het spel is dicht")
	for i in gekozen.size():
		var d = World.dier(gekozen[i])
		var buiten: Vector2 = Spel.BUITEN[i]
		waar(d != null and Vector2(d.x, d.z).distance_to(buiten) <= 3.0, "%s staat weg van het hokje" % gekozen[i])
	gelijk(int(State.s["sterren"]), sterren, "een misser kost niets")
	Games.hersteek()
	waar(Hits.spot("spel_foto") != null, "de knop van het fotohokje is er weer")
	waar(Games.start(SPEL), "terug naar het hokje")
	await _wacht(Spel.SOM_S + 0.3)
	gelijk(int(_stand().get("weg", 1)), 0, "ze zijn er weer")
	gelijk(str(_stand().get("dieren", [])), str(gekozen), "dezelfde dieren")
	gelijk(str(_stand().get("stap", "")), "som", "dezelfde vraag")
	gelijk(str(_strook()), str(voor), "met dezelfde vier bedragen in dezelfde volgorde")
	for i in gekozen.size():
		var d = World.dier(gekozen[i])
		waar(d != null and Vector2(d.x, d.z).distance_to(Spel.PLEKKEN[i]) <= 3.0, "%s staat weer bij het hokje" % gekozen[i])
	_druk("Kn%d" % goed)
	gelijk(str(_stand().get("stap", "")), "af", "nu goed betaald")
	gelijk(int(State.s["sterren"]), sterren + 1, "de ster komt voor het meedoen")
	_af()

## A reload in the middle of choosing keeps who was chosen; floats from the JSON
## are numbers again; the next day is a new photo.
func test_herladen_hervat_de_beurt() -> void:
	_op()
	_wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	var eerste := _dieren_op_de_strook()[0]
	_druk("Kd_" + eerste)
	Games.stop()
	gelijk(str(_stand().get("dieren", [])), str([eerste]), "de keuze is bewaard")
	waar(Games.start(SPEL), "opnieuw gestart")
	gelijk(str(_stand().get("stap", "")), "kies", "verder met kiezen")
	waar(not _dieren_op_de_strook().has(eerste), "wie al gekozen was, staat niet meer op de strook")
	var sch := _scherm()
	waar(sch != null and sch.dieren.size() == 1, "en staat al op het scherm")
	var st: Dictionary = State.spel_data(SPEL)["stand"]
	st["missers"] = 0.0
	st["N"] = 4.0
	Games.stop()
	waar(Games.start(SPEL), "na een JSON-ronde")
	gelijk(typeof(_stand()["missers"]), TYPE_INT, "missers is weer een geheel getal")
	gelijk(str(_stand().get("dieren", [])), str([eerste]), "de keuze is er nog")
	Games.stop()
	State.s["dag"] = 3
	waar(Games.start(SPEL), "de volgende dag")
	gelijk((_stand().get("dieren", []) as Array).size(), 0, "een nieuwe foto begint leeg")
	_af()

## One animal with a bed: the booth says there are too few guests and closes.
func test_te_weinig_gasten() -> void:
	_op()
	_wereld(2, 0, 2, 1)
	waar(Games.start(SPEL), "het spel start")
	waar(_knoop(LEEG) != null, "het wolkje zegt dat er te weinig gasten zijn")
	await _wacht(Spel.LEEG_S + 0.3)
	gelijk(Games.actief(), "", "en het spel sluit zichzelf")
	_af()

# ------------------------------------------------------------- het hokje

## The booth is the fifth in the row along the back wall: as deep as the
## stalls, on none of them, inside the arcade.  The places of its animals and
## their way out lie on no stall, counter or pot, and no walk to them — from
## the stairs, out, and back — goes through one; no stroll between two wander
## places goes through the booth.
func test_het_hokje_staat_in_de_rij() -> void:
	var r := Rooms.get_kamer(KAMER)
	var voeten := {}
	for stuk in r.decor:
		voeten[str(stuk["n"])] = _voet_van(stuk)
	waar(voeten.has(HOKJE), "het fotohokje staat in de winkelstraat")
	var hokje: Rect2 = voeten.get(HOKJE, Rect2())
	waar(hokje.position.x >= 0.0 and hokje.position.y >= 0.0 and hokje.end.x <= r.w
		and hokje.end.y <= r.d, "binnen de kamer (%s)" % str(hokje))
	for stuk in r.decor:
		if str(stuk["n"]) == HOKJE:
			gelijk(float(stuk["z"]), 12.0, "in dezelfde rij als de kraampjes")
			continue
		waar(not voeten[str(stuk["n"])].grow(-0.5).intersects(hokje),
			"%s staat niet op het hokje" % stuk["n"])
	var deur := Vector2(float(r.deur_punten["receptie"]["ix"]), float(r.deur_punten["receptie"]["iz"]))
	var lopen: Array = []
	for i in Spel.PLEKKEN.size():
		var plek: Vector2 = Spel.PLEKKEN[i]
		var buiten: Vector2 = Spel.BUITEN[i]
		lopen.append([deur, plek, "naar plek %d" % i])
		lopen.append([plek, buiten, "plek %d het hokje uit" % i])
		lopen.append([buiten, deur, "plek %d terug naar de trap" % i])
		for naam in voeten:
			waar(not voeten[naam].grow(2.0).has_point(plek), "plek %d staat niet in %s" % [i, naam])
			waar(not voeten[naam].has_point(buiten), "buiten %d staat niet in %s" % [i, naam])
		waar(plek.y > hokje.end.y, "plek %d staat vóór het hokje" % i)
		waar(Rooms._in_mijd(r, plek.x, plek.y, 0.0), "plek %d is geen loop- of meubelplek" % i)
	for l in lopen:
		for naam in voeten:
			waar(not Rooms._snijdt(voeten[naam], l[0], l[1]), "%s (%s -> %s) gaat niet door %s"
				% [l[2], str(l[0]), str(l[1]), naam])
	var dwaal: Array = []
	for p in r.plekken:
		dwaal.append(Vector2(p[0], p[1]))
	for a in dwaal + [deur]:
		for b in dwaal:
			waar(not Rooms._snijdt(hokje, a, b), "de wandeling %s -> %s gaat niet door het hokje" % [str(a), str(b)])

func _voet_van(stuk: Dictionary) -> Rect2:
	var vox: Array = Art.model(str(stuk["n"]))
	if vox.is_empty():
		return Rect2()
	var x0 := INF
	var x1 := -INF
	var z0 := INF
	var z1 := -INF
	for v in vox:
		x0 = minf(x0, float(v["x"]))
		x1 = maxf(x1, float(v["x"]))
		z0 = minf(z0, float(v["z"]))
		z1 = maxf(z1, float(v["z"]))
	return Rect2(float(stuk["x"]) + x0, float(stuk["z"]) + z0, x1 - x0 + 1.0, z1 - z0 + 1.0)

# ------------------------------------------------------- op vier schermen

## The real shell on the four screens, choosing and paying: every element of
## the game is inside the frame and finds a real place, the big screen stands
## clear of the card and its strip, and the animals at the booth are not
## hidden behind it.
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
		_keur(kader.size, "%s kiezen" % str(maat))
		var gekozen := await _kies_er(3)
		for _f in 4:
			await boom.process_frame
		_keur(kader.size, "%s betalen" % str(maat))
		gelijk(_strook().size(), 4, "%s: vier bedragen op de strook" % str(maat))
		var dbg := Hits.debug()
		waar(dbg.has(SCHERM), "%s: het scherm van het hokje staat er" % str(maat))
		if dbg.has(SCHERM):
			var b: Rect2 = dbg[SCHERM]["rect"]
			for id in gekozen:
				var dier := World.vlak_van_dier(id)
				if dier.size.x > 0.0:
					waar(not b.has_point(dier.get_center()),
						"%s: %s staat niet achter het scherm (%s, %s)" % [str(maat), id, str(b), str(dier)])
			for id in [KAART, STROOK]:
				if dbg.has(id):
					var andere: Rect2 = dbg[id]["rect"]
					var snij := b.intersection(andere)
					waar(snij.size.x <= 0.5 or snij.size.y <= 0.5,
						"%s: het scherm ligt niet over %s (%s, %s)" % [str(maat), id, str(b), str(andere)])
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
