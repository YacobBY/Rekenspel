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
## On top of every wait for the game's own clock: a slow runner (CI) may hand
## the game its frames late, and the test must not overtake it.
const MARGE := 0.5

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

## `aantal` animals on the photo: the booth is set to take that many
## (`zet_aantal`), the first walks in by itself, the test picks the others and
## answers every "what does it cost now?" on the way right — except the last
## one, which is left open (stap `som`, all of them inside).  The animals on
## the photo, in order.
func _kies_er(aantal: int) -> Array[String]:
	var spel := _spel()
	if spel != null:
		spel.zet_aantal(aantal)
	for _i in Beurt.MAX_DIEREN:
		if (_stand().get("dieren", []) as Array).size() >= aantal:
			break
		var vrij := _dieren_op_de_strook()
		if vrij.is_empty():
			fout("geen dier meer op de strook")
			break
		_druk("Kd_" + vrij[0])
		await _wacht(Spel.SOM_S + MARGE)
		var nu := (_stand().get("dieren", []) as Array).size()
		if nu < aantal:
			_druk("Kn%d" % (nu * _prijs_nu()))
			await _wacht(Spel.SOM_S + MARGE)
	var gekozen: Array[String] = []
	for id in _stand().get("dieren", []):
		gekozen.append(str(id))
	return gekozen

## The open cost of a full photo answered right, then the money: the right
## handful of coins and notes (`Kg<bedrag>`) — the photo is taken.
func _betaal_goed(goed: int) -> void:
	_druk("Kn%d" % goed)
	await _wacht(Spel.SOM_S + MARGE)
	gelijk(str(_stand().get("stap", "")), "betaal", "de foto is vol: nu het geld")
	_druk("Kg%d" % goed)

## A button on the strip that is NOT the right amount (an amount or a handful).
func _foute_keuze(goed: int) -> String:
	for k in _strook():
		if k != "Kn%d" % goed and k != "Kg%d" % goed:
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
					# the money: four real handfuls, exactly one of them right
					var geld := Spel.Geld.betaal_keuzes(goed, band, Beurt.zaad(n, band, dag, aantal) + 7)
					gelijk(geld.size(), 4, "%s: vier handjes geld" % wat)
					var raak := 0
					for st in geld:
						waar((st as Array).size() <= 4, "%s: hooguit vier stuks geld (%s)" % [wat, str(st)])
						if Spel.Geld.tel(st) == goed:
							raak += 1
					gelijk(raak, 1, "%s: precies één handje is het goede bedrag" % wat)
				# how many go on the photo: two to four, never more than may go
				for pool in range(2, 6):
					var k := Beurt.aantal(n, band, dag, pool)
					waar(k >= Beurt.MIN_DIEREN and k <= mini(Beurt.MAX_DIEREN, maxi(2, pool)),
						"%s: %d dieren op de foto bij %d die mogen" % [wat, k, pool])
		waar(gezien.size() >= 3, "band %d: de prijs verschilt van dag tot dag (%s)" % [band, str(gezien.keys())])

## Every sentence the child reads fits the card rules (HOTEL.md §9) and every
## character is in the font subset.
func test_elke_zin_past() -> void:
	if Ui.thema == null or Ui.thema.default_font == null:
		Ui._bouw_thema(17)
	for zin in ["%s %s" % [Beurt.ICOON, Beurt.T_KIES], "%s %s" % [Beurt.ICOON_GELD, Beurt.T_SOM],
			"%s %s" % [Beurt.ICOON_GELD, Beurt.T_BETAAL], "%s %s" % [Beurt.ICOON_AF, Beurt.T_AF]]:
		waar(Ui.keur_regel(SPEL, zin), "past: %s" % zin)
	var alles: Array = [Beurt.ICOON, Beurt.ICOON_GELD, Beurt.ICOON_AF, Beurt.ICOON_WEG, Beurt.T_KNOP,
		Beurt.T_KIES, Beurt.T_SOM, Beurt.T_BETAAL, Beurt.T_AF, Beurt.T_WEG, Beurt.T_LEEG, Beurt.T_BLIJ,
		"😍", "€0123456789?+"]
	for kind in Hotel.DIER_ICOON:
		alles.append(str(Hotel.DIER_ICOON[kind]))
	for band in [3, 4, 5]:
		alles.append(Beurt.som(4, Beurt.prijs(4, band, 2), band))
	for zin in alles:
		gelijk(Ui.mist_tekens(str(zin)).size(), 0, "elk teken staat in de fontsubset: %s" % zin)

# ------------------------------------------------------------ een hele beurt

## A whole turn per band through the real strips: the first animal goes by
## itself, the child chooses the others — and after every one "what does the
## photo cost now?" — they walk into the booth, and when it is full the money:
## the right handful of coins — the photo and one star.
func test_een_beurt_per_band() -> void:
	for geval in [[2, 3, 2], [4, 4, 3], [8, 5, 4]]:
		var n: int = geval[0]
		var band: int = geval[1]
		var aantal: int = geval[2]
		_op()
		_wereld(n, band)
		var sterren := int(State.s["sterren"])
		waar(Games.start(SPEL), "band %d: het spel start" % band)
		_spel().zet_aantal(aantal)
		gelijk(int(_stand().get("aantal", 0)), aantal, "band %d: %d dieren op deze foto" % [band, aantal])
		var prijs := Beurt.prijs(n, band, 2)
		gelijk(str(_stand().get("stap", "")), "kies", "band %d: eerst kiezen wie er op de foto gaat" % band)
		gelijk(_kaart_tekst("Kolom/Regel"), "📸 " + Beurt.T_KIES, "band %d: de vraag" % band)
		var eerste := str((_stand().get("dieren", []) as Array)[0])
		waar(not _dieren_op_de_strook().has(eerste), "band %d: het eerste dier gaat vanzelf" % band)
		gelijk(_dieren_op_de_strook().size(), mini(n, Beurt.MAX_DIEREN) - 1, "band %d: de anderen op de strook" % band)
		waar(not _strook().has("Kklaar"), "band %d: geen Klaar: het hokje is vol als het vol is" % band)
		# the screen: two frames, each with the price per animal under it
		var sch := _scherm()
		waar(sch != null, "band %d: het scherm van het hokje staat groot in beeld" % band)
		if sch != null:
			gelijk(sch.vakken, 2, "band %d: twee vakjes" % band)
			gelijk(sch.prijs, prijs, "band %d: de prijs per dier staat eronder" % band)
		var gekozen: Array[String] = [eerste]
		for i in aantal - 1:
			var vrij := _dieren_op_de_strook()
			if vrij.is_empty():
				fout("band %d: geen dier meer op de strook" % band)
				break
			gekozen.append(vrij[0])
			_druk("Kd_" + vrij[0])
			waar(not _dieren_op_de_strook().has(vrij[0]), "band %d: wie gekozen is, gaat van de strook" % band)
			var d = World.dier(vrij[0])
			waar(d != null and d.kamer == KAMER, "band %d: het dier loopt naar het hokje" % band)
			gelijk(str(_stand().get("dieren", [])), str(gekozen), "band %d: de keuze is bewaard" % band)
			gelijk(str(_stand().get("stap", "")), "som", "band %d: na elk dier een som" % band)
			await _wacht(Spel.SOM_S + MARGE)
			# everybody inside, then: what does the photo cost now?
			for j in gekozen.size():
				var dier = World.dier(gekozen[j])
				var plek: Vector2 = Spel.PLEKKEN[j]
				waar(dier != null and dier.kamer == KAMER and Vector2(dier.x, dier.z).distance_to(plek) <= 3.0,
					"band %d: %s staat bij het hokje" % [band, gekozen[j]])
				waar(World.verstopt(gekozen[j]), "band %d: %s zit in het hokje" % [band, gekozen[j]])
			sch = _scherm()
			if sch != null:
				gelijk(sch.dieren.size(), gekozen.size(), "band %d: %d dieren op het scherm" % [band, gekozen.size()])
				gelijk(sch.vakken, gekozen.size(), "band %d: een vakje per dier" % band)
			gelijk(_kaart_tekst("Kolom/Regel"), "💶 " + Beurt.T_SOM, "band %d: wat kost de foto nu" % band)
			gelijk(_kaart_tekst("Kolom/Rij/Som"), Beurt.som(gekozen.size(), prijs, band), "band %d: de som" % band)
			var nu := gekozen.size() * prijs
			gelijk(_strook().size(), 4, "band %d: vier bedragen" % band)
			waar(_strook().has("Kn%d" % nu), "band %d: het goede bedrag staat erbij (%s)" % [band, str(_strook())])
			_druk("Kn%d" % nu)
			await _wacht(Spel.SOM_S + MARGE)
			if gekozen.size() < aantal:
				gelijk(str(_stand().get("stap", "")), "kies", "band %d: er kan er nog één bij" % band)
		# full: the money, four handfuls of coins and notes
		var goed := aantal * prijs
		gelijk(str(_stand().get("stap", "")), "betaal", "band %d: het hokje is vol, nu het geld" % band)
		gelijk(_kaart_tekst("Kolom/Regel"), "💶 " + Beurt.T_BETAAL, "band %d: welk geld erin gaat" % band)
		gelijk(_kaart_tekst("Kolom/Rij/Som"), Beurt.euro(goed), "band %d: het bedrag" % band)
		gelijk(_strook().size(), 4, "band %d: vier handjes geld" % band)
		waar(_strook().has("Kg%d" % goed), "band %d: het goede geld staat erbij (%s)" % [band, str(_strook())])
		gelijk(int(State.s["sterren"]), sterren, "band %d: nog geen ster voor het betalen" % band)
		# the shutter comes after the countdown (3 × TEL_S), so listen to the
		# band itself until then
		var gehoord: Array[String] = []
		var hoor := func(naam: String) -> void: gehoord.append(naam)
		var was := [Snd._wakker, Snd._uit]
		Snd._wakker = true
		Snd._uit = false
		Snd.gespeeld.connect(hoor)
		_druk("Kg%d" % goed)
		gelijk(str(_stand().get("stap", "")), "af", "band %d: betaald" % band)
		gelijk(int(State.s["sterren"]), sterren + 1, "band %d: één ster voor het meedoen" % band)
		await _wacht(3.0 * Spel.TEL_S + MARGE)
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

## Never one animal, never more than the booth takes: the first goes by
## itself, a pick is always followed by its sum (a second pick before it is
## answered does nothing), and a full booth goes to the money.
func test_vier_dieren_en_nooit_een() -> void:
	_op()
	_wereld(6, 0)
	waar(Games.start(SPEL), "het spel start")
	var spel := _spel()
	spel.zet_aantal(4)
	gelijk((_stand().get("dieren", []) as Array).size(), 1, "het eerste dier gaat vanzelf")
	var vrij := _dieren_op_de_strook()
	gelijk(vrij.size(), 3, "drie anderen op de strook")
	_druk("Kd_" + vrij[0])
	gelijk(str(_stand().get("stap", "")), "som", "na het dier eerst de som")
	spel.kies_dier(vrij[1])
	gelijk((_stand().get("dieren", []) as Array).size(), 2, "zonder antwoord komt er niemand bij")
	await _wacht(Spel.SOM_S + MARGE)
	var prijs := _prijs_nu()
	for i in 2:
		_druk("Kn%d" % ((_stand()["dieren"] as Array).size() * prijs))
		await _wacht(Spel.SOM_S + MARGE)
		gelijk(str(_stand().get("stap", "")), "kies", "er kan er nog één bij")
		_druk("Kd_" + _dieren_op_de_strook()[0])
		await _wacht(Spel.SOM_S + MARGE)
	gelijk((_stand().get("dieren", []) as Array).size(), Beurt.MAX_DIEREN, "vier op de foto")
	_druk("Kn%d" % (Beurt.MAX_DIEREN * prijs))
	await _wacht(Spel.SOM_S + MARGE)
	gelijk(str(_stand().get("stap", "")), "betaal", "vier dieren: het hokje is vol, nu het geld")
	spel.kies_dier(vrij[2])
	gelijk((_stand().get("dieren", []) as Array).size(), Beurt.MAX_DIEREN, "er past er niet nog één in")
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
	for id in gekozen:
		waar(World.verstopt(id), "%s zit in het hokje" % id)
	var voor := _strook()
	var goed := 3 * Beurt.prijs(4, 4, 2)
	var fout_k := _foute_keuze(goed)
	waar(not fout_k.is_empty(), "er staat een verkeerd bedrag op de strook")
	# straight from the signal: `Snd.gehoord()` keeps only the last 32 sounds,
	# and in the whole suite it is full long before this
	var nu_gehoord: Array[String] = []
	var was := _luister_aan(nu_gehoord)
	_druk(fout_k)
	_luister_uit(was)
	# out of the booth first, before they sulk and walk away
	for i in gekozen.size():
		var d = World.dier(gekozen[i])
		waar(not World.verstopt(gekozen[i]), "%s komt eerst het hokje uit" % gekozen[i])
		waar(World.dieren(KAMER).has(d), "%s staat weer in de winkelstraat" % gekozen[i])
		waar(d != null and Vector2(d.x, d.z).distance_to(Spel.PLEKKEN[i]) <= 3.0,
			"%s staat nog voor het hokje" % gekozen[i])
	var sch := _scherm()
	waar(sch != null and sch.dieren.is_empty(), "het scherm laat ze gaan")
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
	await _wacht(Spel.SOM_S + MARGE)
	gelijk(int(_stand().get("weg", 1)), 0, "ze zijn er weer")
	gelijk(str(_stand().get("dieren", [])), str(gekozen), "dezelfde dieren")
	gelijk(str(_stand().get("stap", "")), "som", "dezelfde vraag")
	gelijk(str(_strook()), str(voor), "met dezelfde vier bedragen in dezelfde volgorde")
	for i in gekozen.size():
		var d = World.dier(gekozen[i])
		waar(d != null and Vector2(d.x, d.z).distance_to(Spel.PLEKKEN[i]) <= 3.0, "%s staat weer bij het hokje" % gekozen[i])
		waar(World.verstopt(gekozen[i]), "%s zit weer in het hokje" % gekozen[i])
	await _betaal_goed(goed)
	gelijk(str(_stand().get("stap", "")), "af", "nu goed betaald")
	gelijk(int(State.s["sterren"]), sterren + 1, "de ster komt voor het meedoen")
	_af()

## A reload in the middle of choosing keeps who is on the photo and how many go
## on it; floats from the JSON are numbers again; the next day is a new photo.
func test_herladen_hervat_de_beurt() -> void:
	_op()
	_wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	_spel().zet_aantal(3)
	var eerste := str((_stand().get("dieren", []) as Array)[0])
	Games.stop()
	gelijk(str(_stand().get("dieren", [])), str([eerste]), "het eerste dier is bewaard")
	waar(Games.start(SPEL), "opnieuw gestart")
	gelijk(str(_stand().get("stap", "")), "kies", "verder met kiezen")
	gelijk(int(_stand().get("aantal", 0)), 3, "en er gaan er nog steeds drie op")
	waar(not _dieren_op_de_strook().has(eerste), "wie al op de foto staat, staat niet meer op de strook")
	await _wacht(Spel.STAP_IN_S + MARGE)
	var sch := _scherm()
	waar(sch != null and sch.dieren.size() == 1, "en staat weer op het scherm, in het hokje")
	var st: Dictionary = State.spel_data(SPEL)["stand"]
	st["missers"] = 0.0
	st["N"] = 4.0
	st["aantal"] = 3.0
	st["prijs"] = float(Beurt.prijs(4, 4, 2))
	Games.stop()
	waar(Games.start(SPEL), "na een JSON-ronde")
	gelijk(typeof(_stand()["missers"]), TYPE_INT, "missers is weer een geheel getal")
	gelijk(typeof(_stand()["aantal"]), TYPE_INT, "aantal is weer een geheel getal")
	gelijk(str(_stand().get("dieren", [])), str([eerste]), "de keuze is er nog")
	Games.stop()
	State.s["dag"] = 3
	waar(Games.start(SPEL), "de volgende dag")
	gelijk((_stand().get("dieren", []) as Array).size(), 1, "een nieuwe foto begint met één dier")
	gelijk(int(_stand().get("dag", 0)), 3, "van vandaag")
	_af()

## One animal with a bed: the booth says there are too few guests and closes.
func test_te_weinig_gasten() -> void:
	_op()
	_wereld(2, 0, 2, 1)
	waar(Games.start(SPEL), "het spel start")
	waar(_knoop(LEEG) != null, "het wolkje zegt dat er te weinig gasten zijn")
	await _wacht(Spel.LEEG_S + MARGE)
	gelijk(Games.actief(), "", "en het spel sluit zichzelf")
	_af()

# ---------------------------------------------------------- in het hokje

## Listen to the band itself (the suite runs it asleep): every sound that
## starts lands in `uit`, until `_luister_uit`.  The throttles of the world
## sounds asked for here are cleared, so an earlier test cannot swallow them.
func _luister_aan(uit: Array[String]) -> Dictionary:
	var hoor := func(naam: String) -> void: uit.append(naam)
	var was := {"wakker": Snd._wakker, "uit": Snd._uit, "hoor": hoor}
	Snd._wakker = true
	Snd._uit = false
	for naam in ["zwiep", "klik"]:
		Snd._laatst.erase(naam)
	Snd.gespeeld.connect(hoor)
	return was

func _luister_uit(was: Dictionary) -> void:
	Snd.gespeeld.disconnect(was["hoor"])
	Snd._wakker = bool(was["wakker"])
	Snd._uit = bool(was["uit"])

## One `naam=waarde` field of a probe line ("" when it is empty or missing).
func _probe_veld(regel: String, naam: String) -> String:
	for deel in regel.split(" "):
		if deel.begins_with(naam + "="):
			return deel.trim_prefix(naam + "=")
	return ""

## Chosen, the animal walks to its place, looks at the booth and steps in
## through the curtain with a swish: gone from the street — the arcade no
## longer lists it, so nothing of it is drawn and no button steps aside for it
## — and on the booth's screen.  The probe line says who is inside.
func test_een_dier_stapt_het_hokje_in() -> void:
	_op()
	_wereld(4, 4)
	var gehoord: Array[String] = []
	var was := _luister_aan(gehoord)
	# the first animal of the photo goes by itself
	waar(Games.start(SPEL), "het spel start")
	var eerste := str((_stand().get("dieren", []) as Array)[0])
	var d = World.dier(eerste)
	waar(d != null and d.kamer == KAMER and Vector2(d.x, d.z).distance_to(Spel.PLEKKEN[0]) <= 3.0,
		"het dier staat bij het hokje")
	waar(not World.verstopt(eerste), "eerst staat het nog voor het hokje")
	var sch := _scherm()
	waar(sch != null and sch.dieren.is_empty(), "en staat het nog niet op het scherm")
	await _wacht(Spel.STAP_IN_S + MARGE)
	_luister_uit(was)
	waar(World.verstopt(eerste), "dan stapt het het hokje in")
	waar(not World.dieren(KAMER).has(World.dier(eerste)), "de winkelstraat laat het niet meer zien")
	waar(World.dier(eerste) != null and World.dier(eerste).kamer == KAMER, "maar het is er nog wel")
	waar(gehoord.has("zwiep"), "met een zwiep door het gordijn (%s)" % str(gehoord))
	sch = _scherm()
	waar(sch != null and str(sch.dieren) == str([eerste]), "het scherm laat het binnen zien")
	waar(sch != null and sch.binnen().has(eerste), "en het is helemaal binnen")
	gelijk(str(_stand().get("stap", "")), "kies", "er wordt nog gekozen")
	var spel := _spel()
	var regel: String = spel.probe_regel() if spel != null else ""
	waar(regel.begins_with("[probe] foto ") and regel.contains(" binnen=%s " % eerste)
		and regel.contains(" tel=0") and regel.contains(" foto=0"), "de probe-regel: %s" % regel)
	_af()

## The right amount: the screen counts down 3, 2, 1 with a tick for every
## digit and then the shutter clicks — in that order — and the photo is taken
## while they are still inside; the photo develops, and they come out of the
## booth, happy, with 😍.  Then the game closes by itself.
func test_aftellen_klik_en_weer_naar_buiten() -> void:
	_op()
	_wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	var gekozen := await _kies_er(2)
	gelijk(str(_stand().get("stap", "")), "som", "nu wat de foto kost")
	for id in gekozen:
		waar(World.verstopt(id), "%s zit in het hokje" % id)
	var goed := 2 * Beurt.prijs(4, 4, 2)
	var gehoord: Array[String] = []
	var was := _luister_aan(gehoord)
	await _betaal_goed(goed)
	var sch := _scherm()
	gelijk(sch.tel_getal if sch != null else -1, 3, "meteen een 3 op het scherm")
	var spel := _spel()
	var regel: String = spel.probe_regel() if spel != null else ""
	waar(regel.contains(" tel=3") and regel.contains(" foto=0"), "de probe-regel telt mee: %s" % regel)
	# the shutter at 3 × TEL_S, out of the booth ONTWIKKEL_S later: in between,
	# with MARGE on either side
	await _wacht(3.0 * Spel.TEL_S + MARGE)
	sch = _scherm()
	waar(sch != null and sch.foto, "de foto is genomen")
	gelijk(sch.tel_getal if sch != null else -1, 0, "na het aftellen staat er geen cijfer meer")
	var na_munt := gehoord.slice(maxi(0, gehoord.find("munt")))
	var tik_klik := na_munt.filter(func(naam: String) -> bool: return naam == "tik" or naam == "klik")
	waar(gehoord.has("munt"), "het geld valt erin (%s)" % str(gehoord))
	gelijk(str(tik_klik), str(["tik", "tik", "tik", "klik"]), "drie tikken, dan de sluiter (%s)" % str(gehoord))
	for id in gekozen:
		waar(World.verstopt(id), "%s zit nog in het hokje als de foto genomen wordt" % id)
	regel = spel.probe_regel() if spel != null else ""
	waar(regel.contains(" tel=0") and regel.contains(" foto=1"), "de probe-regel ziet de foto: %s" % regel)
	var binnen := _probe_veld(regel, "binnen").split(",")
	binnen.sort()
	var verwacht := PackedStringArray(gekozen)
	verwacht.sort()
	gelijk(binnen, verwacht, "de probe-regel zegt wie er binnen zit: %s" % regel)
	await _wacht(Spel.ONTWIKKEL_S + MARGE)
	_luister_uit(was)
	waar(gehoord.has("tover"), "de foto is klaar (%s)" % str(gehoord))
	for id in gekozen:
		var d = World.dier(id)
		waar(not World.verstopt(id), "%s komt weer naar buiten" % id)
		waar(World.dieren(KAMER).has(d), "%s staat weer in de winkelstraat" % id)
		waar(d != null and (str(d.staat) == "blij" or str(d.pose) in ["blijA", "blijB"]),
			"%s is blij (%s, %s)" % [id, str(d.staat) if d != null else "", str(d.pose) if d != null else ""])
	waar(_knoop("ft_blij") != null, "met 😍 mooi!")
	regel = spel.probe_regel() if spel != null and is_instance_valid(spel) else ""
	gelijk(_probe_veld(regel, "binnen"), "", "buiten zit er niemand meer binnen: %s" % regel)
	gelijk(Games.actief(), SPEL, "het spel loopt nog even")
	await _wacht(Spel.AF_S + MARGE)
	gelijk(Games.actief(), "", "en dan sluit het vanzelf")
	_af()

## Whatever stops the game, nobody stays inside the booth — and one who was
## just about to step in does not step in after it.
func test_stoppen_haalt_iedereen_uit_het_hokje() -> void:
	_op()
	_wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	var gekozen := await _kies_er(3)
	for id in gekozen:
		waar(World.verstopt(id), "%s zit in het hokje" % id)
	Games.stop()
	for id in gekozen:
		waar(not World.verstopt(id), "%s staat na het stoppen weer buiten" % id)
		waar(World.dieren(KAMER).has(World.dier(id)), "%s is weer te zien" % id)
	State.s["dag"] = 3                 # a new photo
	waar(Games.start(SPEL), "opnieuw")
	var eerste := _dieren_op_de_strook()[0]
	_druk("Kd_" + eerste)
	Games.stop()
	await _wacht(Spel.STAP_IN_S + MARGE)
	waar(not World.verstopt(eerste), "wie bijna instapte, stapt na het stoppen niet meer in")
	_af()

## While the money question waits the animals sit inside.  One the hotel
## shows again (a new day: `World.zet_dag`) steps back in where he stands,
## unseen — the photo is never taken with him outside — and one who sits
## inside is left alone, wherever he stands: nobody walks him anywhere.
func test_wie_binnen_zit_blijft_binnen() -> void:
	_op()
	_wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	var gekozen := await _kies_er(2)
	gelijk(str(_stand().get("stap", "")), "som", "nu het geld")
	for id in gekozen:
		waar(World.verstopt(id), "%s zit in het hokje" % id)
	# the first: shown by the hotel while he stands at his place
	World.zet_dag(int(State.s["dag"]))
	waar(not World.verstopt(gekozen[0]), "de nieuwe dag haalt iedereen tevoorschijn")
	# the second: hidden again, but put somewhere else in the arcade
	World.verstop(gekozen[1], true)
	var plek: Vector2 = Spel.PLEKKEN[1]
	var ergens := Vector2(plek.x - 20.0, plek.y + 30.0)
	World.zet(gekozen[1], KAMER, ergens.x, ergens.y)
	waar(World.verstopt(gekozen[1]), "verzet in dezelfde kamer: nog verstopt")
	await _wacht(2.0 * Spel.BLIJF_S + MARGE)
	gelijk(Games.actief(), SPEL, "het spel loopt nog")
	waar(World.verstopt(gekozen[0]), "%s stapt weer in, zonder dat iemand het ziet" % gekozen[0])
	var d = World.dier(gekozen[0])
	waar(d != null and Vector2(d.x, d.z).distance_to(Spel.PLEKKEN[0]) <= 3.0, "%s op zijn plek voor het hokje" % gekozen[0])
	var e = World.dier(gekozen[1])
	waar(World.verstopt(gekozen[1]), "%s blijft verstopt" % gekozen[1])
	waar(e != null and Vector2(e.x, e.z).distance_to(ergens) < 0.5,
		"en niemand stuurt hem ergens heen (%s)" % (str(Vector2(e.x, e.z)) if e != null else "-"))
	var sch := _scherm()
	waar(sch != null and sch.dieren.size() == 2, "het scherm heeft ze nog allebei")
	gelijk(_kaart_tekst("Kolom/Regel"), "💶 " + Beurt.T_SOM, "de vraag staat er nog")
	_af()

## A reload while the money is asked: everybody walks back, steps in again
## and is on the screen again — and only then the same question comes back.
func test_herladen_bij_het_geld_stapt_iedereen_weer_in() -> void:
	_op()
	_wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	var gekozen := await _kies_er(3)
	gelijk(str(_stand().get("stap", "")), "som", "bij het geld")
	var voor := _strook()
	Games.stop()
	waar(Games.start(SPEL), "opnieuw gestart")
	gelijk(str(_stand().get("stap", "")), "som", "nog steeds het geld")
	waar(_knoop(KAART) == null, "de vraag wacht tot ze weer binnen zitten")
	var sch := _scherm()
	waar(sch != null and sch.dieren.is_empty(), "het scherm begint leeg")
	await _wacht(Spel.SOM_S + MARGE)
	for i in gekozen.size():
		var d = World.dier(gekozen[i])
		waar(World.verstopt(gekozen[i]), "%s zit weer in het hokje" % gekozen[i])
		waar(d != null and Vector2(d.x, d.z).distance_to(Spel.PLEKKEN[i]) <= 3.0,
			"%s op zijn plek voor het hokje" % gekozen[i])
	sch = _scherm()
	var op_scherm: Array = sch.dieren.duplicate() if sch != null else []
	op_scherm.sort()
	var verwacht: Array = gekozen.duplicate()
	verwacht.sort()
	gelijk(str(op_scherm), str(verwacht), "ze staan allemaal weer op het scherm")
	gelijk(_kaart_tekst("Kolom/Regel"), "💶 " + Beurt.T_SOM, "de vraag staat er weer")
	gelijk(str(_strook()), str(voor), "met dezelfde vier bedragen")
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

## The real shell on the four screens, choosing, paying and paying wrong: every
## element of the game is inside the frame and finds a real place; the big
## screen lies inside the frame and above the maths bar, clear of the card and
## its strip and of the places of the animals at the booth — also on a phone on
## its side, where the band over them is lower than the smallest screen — with
## price tags as large as on the smallest screen at least.  Once the money
## question is up it keeps its size: a wrong amount lets the maths bar go and
## the room grows, and the screen does not grow along (and the animals that
## come out are never behind it).
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
		_keur_scherm("%s kiezen" % str(maat))
		var gekozen := await _kies_er(3)
		for _f in 4:
			await boom.process_frame
		_keur(kader.size, "%s wat kost het" % str(maat))
		gelijk(_strook().size(), 4, "%s: vier bedragen op de strook" % str(maat))
		_keur_scherm("%s wat kost het" % str(maat))
		# right: the money, four handfuls of coins and notes
		var goed := 3 * Beurt.prijs(4, 4, 2)
		_druk("Kn%d" % goed)
		await _wacht(Spel.SOM_S + MARGE)
		for _f in 4:
			await boom.process_frame
		gelijk(str(_stand().get("stap", "")), "betaal", "%s: nu het geld" % str(maat))
		_keur(kader.size, "%s betalen" % str(maat))
		gelijk(_strook().size(), 4, "%s: vier handjes geld op de strook" % str(maat))
		var b := _keur_scherm("%s betalen" % str(maat))
		# a wrong amount: the card goes, the maths bar lets go, they come out
		_druk(_foute_keuze(goed))
		for _f in 4:
			await boom.process_frame
		gelijk(Games.actief(), SPEL, "%s: ze moeten nog weglopen" % str(maat))
		var na := _keur_scherm("%s fout" % str(maat))
		waar(na.size.is_equal_approx(b.size),
			"%s: het scherm houdt zijn maat (%s -> %s)" % [str(maat), str(b.size), str(na.size)])
		for id in gekozen:
			var dier := World.vlak_van_dier(id)
			waar(dier.size.x > 0.0, "%s: %s staat weer in beeld" % [str(maat), id])
			var snij := na.intersection(dier)
			waar(snij.size.x <= 0.5 or snij.size.y <= 0.5,
				"%s: %s staat niet achter het scherm (%s, %s)" % [str(maat), id, str(na), str(dier)])
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

## The booth's screen on this frame: inside it and above the maths bar, clear
## of the card and its strip and of the four places at the booth (an animal is
## about 28 voxels long, 16 deep and 26 high), with price tags no smaller than
## on the smallest screen.  Its rectangle.
func _keur_scherm(wat: String) -> Rect2:
	var dbg := Hits.debug()
	waar(dbg.has(SCHERM), "%s: het scherm van het hokje staat er" % wat)
	if not dbg.has(SCHERM):
		return Rect2()
	var b: Rect2 = dbg[SCHERM]["rect"]
	var kader := World.kader_rect().size
	waar(b.position.x >= -0.01 and b.position.y >= -0.01 and b.end.x <= kader.x + 0.01
		and b.end.y <= kader.y + 0.01, "%s: het scherm in het kader (%s)" % [wat, str(b)])
	if Ui.balk_aan():
		waar(b.end.y <= Ui.balk_rect().position.y + 0.5,
			"%s: het scherm boven de rekenbalk (%s, %s)" % [wat, str(b), str(Ui.balk_rect())])
	for id in [KAART, STROOK]:
		if dbg.has(id):
			var andere: Rect2 = dbg[id]["rect"]
			var snij := b.intersection(andere)
			waar(snij.size.x <= 0.5 or snij.size.y <= 0.5,
				"%s: het scherm ligt niet over %s (%s, %s)" % [wat, id, str(b), str(andere)])
	var plekken := Rect2()
	var eerste := true
	for p in Spel.PLEKKEN:
		for hoek in [Vector3(-14, 0, -8), Vector3(14, 0, -8), Vector3(-14, 0, 8),
				Vector3(14, 0, 8), Vector3(-14, 26, 0), Vector3(14, 26, 0)]:
			var q: Vector2 = World.mik_punt(p.x + hoek.x, p.y + hoek.z, hoek.y)
			plekken = Rect2(q, Vector2.ZERO) if eerste else plekken.expand(q)
			eerste = false
	var over := b.intersection(plekken)
	waar(over.size.x <= 0.5 or over.size.y <= 0.5,
		"%s: het scherm ligt niet over de plekken van de dieren (%s, %s)" % [wat, str(b), str(plekken)])
	var sch := _scherm()
	var kaartje: Rect2 = sch.prijs_rect(0) if sch != null else Rect2()
	if kaartje.size.x > 0.0:
		waar(kaartje.size.y >= FotoScherm.LABEL * Spel.SCHERM_MIN - 0.01,
			"%s: de prijskaartjes blijven leesbaar (%.1f hoog)" % [wat, kaartje.size.y])
	return b

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

# ------------------------------------------- R2: een misser blijft staan
# The owner (2026-10-08): "het moet niet mogelijk zijn om rekenen over te
# slaan".  A money question that had a miss comes back UNCHANGED after every
# exit — also when a new day begins, a guest arrives (N) or the band moves.
# Before 2026-10-09 each of these threw the turn away: a new photo, a new price
# (red log: tmp/log/r2-rood-foto.log).  The booth has no animal of the turn on
# the game bar (`ctx.speelt("")`), so there is no switch to close here.

## The price per animal of the running turn, as the game has it.
func _prijs_nu() -> int:
	var spel := _spel()
	return int(spel.opzet().get("prijs", 0)) if spel != null else 0

## Choose until the first money question is on screen, the way the turn leads
## there (an animal at a time; "Klaar" from the second one on, where it exists).
func _naar_de_geldvraag() -> void:
	for _i in 6:
		if str(_stand().get("stap", "")) != "kies":
			break
		if _strook().has("Kklaar") and (_stand().get("dieren", []) as Array).size() >= 2:
			_druk("Kklaar")
			continue
		var vrij := _dieren_op_de_strook()
		if vrij.is_empty():
			break
		_druk("Kd_" + vrij[0])
	await _wacht(Spel.SOM_S + MARGE)

## Into the booth, to the money, one WRONG amount, and wait until they are out
## and the game closed.  {dieren, stap, keuzes, som} of that question.
func _foto_misser() -> Dictionary:
	waar(Games.start(SPEL), "het hokje start")
	await _naar_de_geldvraag()
	var st := _stand()
	var uit := {"dieren": str(st.get("dieren", [])), "stap": str(st.get("stap", "")),
		"keuzes": str(_strook()), "som": _kaart_tekst("Kolom/Rij/Som")}
	gelijk(str(uit["stap"]), "som", "een geldvraag staat open")
	var goed := (st.get("dieren", []) as Array).size() * _prijs_nu()
	_druk(_foute_keuze(goed))
	await _wacht(Spel.SIP_S + Spel.WEG_WACHT + 0.8)
	gelijk(Games.actief(), "", "na de misser is het hokje dicht")
	gelijk(int(_stand().get("missers", 0)), 1, "de misser is bewaard")
	return uit

## Back to the booth: the same animals, the same question, the same sum and the
## same four amounts in the same order.
func _zelfde_geldvraag(voor: Dictionary, wat: String) -> void:
	Games.hersteek()
	waar(Games.start(SPEL), "terug naar het hokje (%s)" % wat)
	await _wacht(Spel.SOM_S + MARGE)
	var st := _stand()
	gelijk(str(st.get("dieren", [])), voor["dieren"], "dezelfde dieren (%s)" % wat)
	gelijk(str(st.get("stap", "")), voor["stap"], "dezelfde vraag (%s)" % wat)
	gelijk(_kaart_tekst("Kolom/Rij/Som"), voor["som"], "dezelfde som (%s)" % wat)
	gelijk(str(_strook()), voor["keuzes"], "dezelfde vier bedragen (%s)" % wat)
	gelijk(int(st.get("missers", 0)), 1, "de misser telt nog (%s)" % wat)

func test_r2_misser_blijft_na_een_nieuwe_dag() -> void:
	_op()
	_wereld(4, 4)
	var voor: Dictionary = await _foto_misser()
	Hotel.morgen()
	gelijk(int(State.s["dag"]), 3, "het is de volgende dag")
	await _zelfde_geldvraag(voor, "nieuwe dag")
	_af()

func test_r2_misser_blijft_na_een_gast_erbij() -> void:
	_op()
	_wereld(4, 4)
	var voor: Dictionary = await _foto_misser()
	var gasten: Array = State.s["gasten"]
	var g: Dictionary = State.gasten_pool()[gasten.size()]
	g["kamer"] = ""
	g["bed"] = ""
	g["waar"] = "receptie"
	gasten.append(g)
	World.sync(gasten)
	gelijk(State.n_gasten(), 5, "een gast erbij")
	await _zelfde_geldvraag(voor, "N 5")
	_af()

func test_r2_misser_blijft_na_een_andere_band() -> void:
	_op()
	_wereld(4, 4)
	var voor: Dictionary = await _foto_misser()
	State.s["kunnen"] = 2
	gelijk(State.band(), 3, "de band zakt naar groep 3")
	await _zelfde_geldvraag(voor, "band 3")
	# answered right now: the photo goes on with the price it began with
	var goed := (_stand().get("dieren", []) as Array).size() * _prijs_nu()
	gelijk(_prijs_nu(), Beurt.prijs(4, 4, 2), "de prijs van de beurt zelf")
	_druk("Kn%d" % goed)
	await _wacht(Spel.SOM_S + MARGE)
	waar(str(_stand().get("stap", "")) in ["kies", "betaal"], "goed beantwoord: verder")
	_af()

# ------------------------------------------------- R1: het rekenaandeel

## Counted by the rule of 2026-10-08 (R1): an answer on a maths strip is
## "reken", choosing an animal is "spel"; the tap that opened the booth is not
## counted, the first animal goes by itself.
var _teller := {"reken": 0, "spel": 0}

func _tel(soort: String) -> void:
	_teller[soort] = int(_teller[soort]) + 1

## The owner (2026-10-08): "rekenen moet minstens 50% van de interactie zijn".
## A whole photo in groep 3, 4 and 5, a small and a large hotel, and every
## size the booth can take (two to four), through the real strips:
## reken >= spel + 1, so with the tap that opened the booth maths is still at
## least half.
func test_rekenaandeel() -> void:
	for geval in [[3, 2], [3, 3], [4, 4], [4, 6], [5, 7], [5, 8]]:
		var band: int = geval[0]
		var n: int = geval[1]
		for aantal in range(Beurt.MIN_DIEREN, mini(n, Beurt.MAX_DIEREN) + 1):
			var wat := "groep %d, %d gasten, %d op de foto" % [band, n, aantal]
			_op()
			_wereld(n, band)
			_teller = {"reken": 0, "spel": 0}
			waar(Games.start(SPEL), "%s: start" % wat)
			_spel().zet_aantal(aantal)
			for _i in 12:
				var st := _stand()
				var stap := str(st.get("stap", ""))
				var nu := (st.get("dieren", []) as Array).size()
				if stap == "kies":
					_druk("Kd_" + _dieren_op_de_strook()[0])
					_tel("spel")
				elif stap == "som":
					_druk("Kn%d" % (nu * _prijs_nu()))
					_tel("reken")
				elif stap == "betaal":
					_druk("Kg%d" % (nu * _prijs_nu()))
					_tel("reken")
				else:
					break
				await _wacht(Spel.SOM_S + MARGE)
			gelijk(str(_stand().get("stap", "")), "af", "%s: de foto is genomen" % wat)
			gelijk((_stand().get("dieren", []) as Array).size(), aantal, "%s: zoveel op de foto" % wat)
			waar(int(_teller["reken"]) >= int(_teller["spel"]) + 1,
				"%s: rekenen %d >= spel %d + 1" % [wat, int(_teller["reken"]), int(_teller["spel"])])
			_af()
