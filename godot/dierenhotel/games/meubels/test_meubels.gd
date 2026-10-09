extends Proef
## Het meubelboek, headless (games-a.md §5, architecture.md §12.2).
##
## Elke beurt wordt door de CTX gespeeld, nooit door een interne functie aan te
## roepen: een knop wordt ingedrukt zoals een vinger dat doet
## (`Hits.spot(id).knoop.pressed.emit()`), een getal wordt op de antwoordstrook
## getikt en een keuze op de strook.  Dat is de enige manier waarop een test
## kan bewijzen dat het kind erbij kan.

const Spel := preload("res://games/meubels/spel.gd")

## De vier kaders van de definition of done (het gemeenschappelijke contract).
const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740),
	Vector2i(740, 360)]

var _laag: Control = null
var _bewaard: Dictionary = {}

# =================================================================== steigers

func _op(kader := Vector2(1000, 648), gasten := 3, munten := 12, kunnen := 5) -> void:
	_bewaard = State.s.duplicate(true)
	State.nieuw_spel()
	State.s["munten"] = munten
	State.s["sterren"] = 6
	State.s["kunnen"] = kunnen
	State.s["gasten"] = _gasten(gasten)
	State.herbereken()
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = kader
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	Ui.zet_scherm(kader)
	World.meet(Rect2(Vector2.ZERO, kader))
	World.naar("receptie")

## `Ui.zet_scherm()` neemt geen nulmaat aan, dus de schermmaat die deze test
## (of de schil in `_hotel_op`) zette blijft anders staan en beslist de tikmaat
## van de VOLGENDE test: `tests/test_hits.gd` rekent op 44 px onder een 360 px
## scherm.  Zie "Contract gaps" bij dit ticket.
func _scherm_los() -> void:
	Ui.vergeet_scherm()

func _af() -> void:
	if Games.actief() != "":
		Games.stop()
	Ui.blad_dicht()
	Hits.wis_alles()
	Ui.naamplaten_leeg()
	Ui.registreer_lagen(null, null, null)
	World.decor_wis_alles()
	Rooms.herstel()
	if _laag != null:
		_laag.queue_free()
		_laag = null
	_scherm_los()
	State.s = _bewaard

## Gasten die het hotel aankan: genoeg om de band te zetten, tevreden zodat er
## geen wenswolkjes bij komen.
func _gasten(n: int) -> Array:
	var uit: Array = []
	for i in n:
		var g := State.pak_gast()
		if g.is_empty():
			break
		g["kamer"] = "kamer1" if i % 2 == 0 else "kamer2"
		g["waar"] = g["kamer"]
		g["bed"] = ""
		g["behoefte"] = "eten"
		g["gegeten"] = true
		g["blij"] = true
		g["nachten"] = 2
		g["prijs"] = 2
		g["dagIn"] = 1
		g["geslapen"] = 0
		g["betaald"] = 0
		uit.append(g)
	return uit

## Het levende spelknooppunt.  Nooit op naam: `Games.stop()` doet `queue_free()`
## en een meteen daarna toegevoegd knooppunt met dezelfde naam wordt hernoemd.
func _spel() -> Node:
	for k in Games.get_children():
		if k is MiniGame and not k.is_queued_for_deletion():
			return k
	return null

func _wacht(seconden: float) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	await boom.create_timer(seconden).timeout

func _tel_frames(n := 2) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	for _f in n:
		await boom.process_frame

# --------------------------------------------------------------- vingers

## Eén vinger op een hotspot.
func _tik(id: String) -> bool:
	var s := Hits.spot(id)
	if s == null or not is_instance_valid(s.knoop) or not (s.knoop is BaseButton):
		fout("hotspot %s staat er niet" % id)
		return false
	(s.knoop as BaseButton).pressed.emit()
	return true

func _er_is(id: String) -> bool:
	var s := Hits.spot(id)
	return s != null and is_instance_valid(s.knoop)

## Elke beurt begint bij de kassa (PLAN.md §3.8 `N6`): eerst je buidel tellen,
## dan pas gaat het boek open.  Elke test die het boek nodig heeft loopt hier
## langs — precies zoals een kind dat doet, met één tik op de goede knop.
func _kassa_door() -> void:
	if int(State.s["munten"]) <= 0:
		return                      # zonder munten is er geen vraag (stap 0)
	if not _typ("mb_kas", int(State.s["munten"])):
		return
	for _p in 40:
		if Ui.blad_open_nu():
			break
		await _wacht(0.05)
	await _tel_frames()

## Eén vinger op een knop in het meubelboek-blad.
func _blad_tik(naam: String) -> bool:
	var knop := _blad_knop(naam)
	if knop == null:
		fout("bladknop %s staat er niet" % naam)
		return false
	knop.pressed.emit()
	return true

## Om dezelfde reden wordt het blad niet op naam gezocht: bij een herbouw hangt
## het oude blad nog één beeld in dezelfde laag.
func _blad_knop(naam: String) -> Button:
	if Ui.bladlaag == null:
		return null
	var kinderen := Ui.bladlaag.get_children()
	kinderen.reverse()
	for blad in kinderen:
		if blad is Control and not blad.is_queued_for_deletion():
			var t := _zoek_knop(blad, naam)
			if t != null:
				return t
	return null

func _zoek_knop(k: Node, naam: String) -> Button:
	if k is Button and k.name == naam:
		return k as Button
	for kind in k.get_children():
		var t := _zoek_knop(kind, naam)
		if t != null:
			return t
	return null

## Een getal tikken op de antwoordstrook onder een kaart (vier knoppen, geen ✓).
func _typ(kaart_id: String, getal: int) -> bool:
	var strook := Hits.spot(kaart_id + "_keuzes")
	if strook == null or not is_instance_valid(strook.knoop):
		fout("de antwoordstrook van %s staat er niet" % kaart_id)
		return false
	var k := strook.knoop.get_node_or_null("Rij/Kn%d" % getal) as Button
	if k == null:
		fout("knop %d staat niet op de strook van %s" % [getal, kaart_id])
		return false
	k.pressed.emit()
	return true

## Een fout getal tikken: de eerste knop van de strook die niet `goed` is.
func _typ_fout(kaart_id: String, goed: int) -> bool:
	var strook := Hits.spot(kaart_id + "_keuzes")
	if strook == null or not is_instance_valid(strook.knoop):
		fout("de antwoordstrook van %s staat er niet" % kaart_id)
		return false
	for k in strook.knoop.get_node("Rij").get_children():
		if k.name != "Kn%d" % goed:
			(k as Button).pressed.emit()
			return true
	fout("de strook van %s heeft alleen het goede getal" % kaart_id)
	return false

func _kaart_tekst(kaart_id: String, veld: String) -> String:
	var s := Hits.spot(kaart_id)
	if s == null or not is_instance_valid(s.knoop):
		return ""
	var k := s.knoop as UiSomkaart
	match veld:
		"regel": return k.regel_label.text
		"regel2": return k.regel2_label.text
		"som": return k.som_label.text
		"vak": return k.vak_label.text
		"hulp": return k.hulp_label.text
	return ""

func _titel(id: String) -> String:
	var s := Hits.spot(id)
	if s == null or not is_instance_valid(s.knoop):
		return ""
	return s.knoop.tooltip_text

## Wacht de pauze af die `Ui.misser` na een misser op de strook legt (S5).
func _wacht_mispauze() -> void:
	await _wacht(Ui.MIS_PAUZE + 0.25)

## Staat de strook van `kaart_id` even op slot?
func _op_slot(kaart_id: String) -> bool:
	var s := Hits.spot(kaart_id + "_keuzes")
	return s != null and is_instance_valid(s.knoop) and (s.knoop as UiKeuzes).op_slot

## Wat een misser in dit spel laat zien (eigenaar 2026-09-24): `🔄 Nog een keer`
## bij de kassa — er is geen dier van de beurt — en geen hulpregel, geen
## spookmunten.
func _alleen_teleurstelling(kaart_id: String, wat: String) -> void:
	waar(mis_wolk(kaart_id), "%s: 🔄 Nog een keer" % wat)
	gelijk(_kaart_tekst(kaart_id, "hulp"), "", "%s: geen hulpregel" % wat)
	waar(not _er_is("mb_spook"), "%s: geen spookmunten" % wat)

# --------------------------------------------------- de Rekenwacht (golf 2)

## R1-teller: elke tik die deze test doet, gelabeld zoals R1 het zegt.
var _r1 := {"reken": 0, "spel": 0}

func _tel(soort: String) -> void:
	_r1[soort] = int(_r1[soort]) + 1

## Eén tik op een knop van een eigen strook (de kassa, genoeg, de munten).
func _kies(kaart_id: String, keuze: String) -> bool:
	var strook := Hits.spot(kaart_id + "_keuzes")
	if strook == null or not is_instance_valid(strook.knoop):
		fout("de strook van %s staat er niet" % kaart_id)
		return false
	var k := strook.knoop.get_node_or_null("Rij/K" + keuze) as Button
	if k == null:
		fout("knop %s staat niet op de strook van %s" % [keuze, kaart_id])
		return false
	k.pressed.emit()
	return true

## De munten die de muntstrook onder de bon aanbiedt, klein naar groot.
func _munten_op_strook() -> Array[int]:
	var uit: Array[int] = []
	for k in _strook_knoppen("mb_bon"):
		var naam := str((k as Node).name)
		if naam.begins_with("Km"):
			uit.append(naam.substr(2).to_int())
	uit.sort()
	return uit

## Een munt op de toonbank leggen: één tik op de muntstrook.
func _leg(waarde: int) -> bool:
	return _kies("mb_bon", "m%d" % waarde)

## Wacht tot een hotspot er staat (de stappen volgen elkaar op na 0,45 s).
func _wacht_op(id: String, max_s := 3.0) -> bool:
	var t := 0.0
	while t < max_s:
		if _er_is(id):
			return true
		await _wacht(0.05)
		t += 0.05
	return _er_is(id)

func _wacht_boek() -> void:
	for _p in 60:
		if Ui.blad_open_nu():
			break
		await _wacht(0.05)
	await _tel_frames()

## Na het betalen: wacht tot het eerste ✨-vakje er ligt.
func _wacht_vak() -> String:
	for _p in 60:
		if not _eerste_vak().is_empty():
			break
		await _wacht(0.05)
	return _eerste_vak()

## Het rekenwerk van één aankoop bij de kassa, zoals een kind het doet, met de
## R1-teller: [som] → genoeg → munten → [wisselgeld] → over.
func _reken_door(heb: int, totaal: int, band: int, aantal: int, wat: String,
		ster := false) -> void:
	if aantal > 1:
		waar(await _wacht_op("mb_som_keuzes"), "%s: de som staat er" % wat)
		waar(_typ("mb_som", totaal), "%s: som = %d" % [wat, totaal])
		_tel("reken")
	waar(await _wacht_op("mb_genoeg_keuzes"), "%s: genoeg? staat er" % wat)
	waar(_kies("mb_genoeg", "ja"), "%s: genoeg" % wat)
	_tel("reken")
	if not ster:
		waar(await _wacht_op("mb_bon_keuzes"), "%s: de muntstrook staat er" % wat)
		var voor := int(_r1["reken"])
		var gelegd := _leg_precies(totaal)
		gelijk(gelegd, totaal, "%s: precies %d op de toonbank" % [wat, totaal])
		waar(int(_r1["reken"]) > voor, "%s: de munten tellen als rekenen" % wat)
		if Sommen.Meubels.wisselgeld(band):
			waar(await _wacht_op("mb_wissel_keuzes"), "%s: het wisselgeld staat er" % wat)
			waar(_typ("mb_wissel", gelegd - totaal), "%s: wisselgeld %d" % [wat, gelegd - totaal])
			_tel("reken")
	waar(await _wacht_op("mb_over_keuzes"), "%s: houd je over? staat er" % wat)
	waar(_typ("mb_over", heb - totaal), "%s: over = %d" % [wat, heb - totaal])
	_tel("reken")

## Eén hele beurt: start (de ingangstik telt niet mee) → kassavraag → [tab] →
## kiezen → [afrekenen] → rekenen → neerzetten → het spel gaat vanzelf dicht.
## Daarna: R1, en de munten zijn betaald.
func _r1_beurt(types: Array, tab: String, wat: String) -> void:
	_r1 = {"reken": 0, "spel": 0}
	var band := State.band()
	var heb := int(State.s["munten"])
	var totaal := 0
	for t in types:
		totaal += int(Spel._artikel(str(t))["prijs"])
	var va_b := _va_begin()
	waar(Games.start("meubels"), "%s: het spel start" % wat)
	await _tel_frames()
	waar(_typ("mb_kas", heb), "%s: de kassavraag" % wat)
	_tel("reken")
	await _wacht_boek()
	if tab != "meubels":
		waar(_blad_tik("Ktab_" + tab), "%s: naar de tab %s" % [wat, tab])
		_tel("spel")
		await _tel_frames()
	for t in types:
		waar(_blad_tik("Kk_" + str(t)), "%s: %s kiezen" % [wat, t])
		_tel("spel")
		await _tel_frames()
	if band >= 4 and types.size() == 1:
		waar(_blad_tik("Kafrekenen"), "%s: afrekenen" % wat)
		_tel("spel")
		await _tel_frames()
	await _reken_door(heb, totaal, band, types.size(), wat)
	gelijk(int(State.s["munten"]), heb - totaal, "%s: de prijs is betaald" % wat)
	for i in types.size():
		var vak: String = await _wacht_vak()
		waar(not vak.is_empty(), "%s: een vakje voor stuk %d" % [wat, i + 1])
		if vak.is_empty():
			break
		waar(_tik(vak), "%s: neerzetten" % wat)
		_tel("spel")
		await _tel_frames(2)
	await _wacht(2.3)
	gelijk(Games.actief(), "", "%s: het spel ging vanzelf dicht" % wat)
	waar(int(_r1["reken"]) >= int(_r1["spel"]) + 1,
		"%s: R1 reken %d >= spel %d + 1" % [wat, _r1["reken"], _r1["spel"]])
	print("[r1] ", wat, " reken=", _r1["reken"], " spel=", _r1["spel"])
	_va_eind("meubels " + wat, _r1, va_b)

## Een sticker met sterren: kassavraag (als er munten zijn) → ⭐-tab → kiezen →
## genoeg → over.
func _r1_sticker(sleutel: String, wat: String) -> void:
	_r1 = {"reken": 0, "spel": 0}
	var munten := int(State.s["munten"])
	var sterren := int(State.s["sterren"])
	var nodig := int(Spel._versier(sleutel)["ster"])
	var va_b := _va_begin()
	waar(Games.start("meubels"), "%s: het spel start" % wat)
	await _tel_frames()
	if munten > 0:
		waar(_typ("mb_kas", munten), "%s: de kassavraag" % wat)
		_tel("reken")
		await _wacht_boek()
		waar(_blad_tik("Ktab_versiering"), "%s: naar de sterren" % wat)
		_tel("spel")
		await _tel_frames()
	waar(_blad_tik("Kv_" + sleutel), "%s: %s kiezen" % [wat, sleutel])
	_tel("spel")
	await _tel_frames()
	await _reken_door(sterren, nodig, State.band(), 1, wat, true)
	gelijk(int(State.s["sterren"]), sterren - nodig, "%s: de sterren zijn betaald" % wat)
	await _wacht(1.9)
	gelijk(Games.actief(), "", "%s: het spel ging vanzelf dicht" % wat)
	waar(int(_r1["reken"]) >= int(_r1["spel"]) + 1,
		"%s: R1 reken %d >= spel %d + 1" % [wat, _r1["reken"], _r1["spel"]])
	print("[r1] ", wat, " reken=", _r1["reken"], " spel=", _r1["spel"])
	_va_eind("meubels " + wat, _r1, va_b)

# ==================================================================================
# 1. registratie en ontgrendeling
# ==================================================================================

func test_registratie_en_taak() -> void:
	var def := Games.definitie("meubels")
	gelijk(def.get("id", ""), "meubels", "de mapnaam is het id")
	gelijk(def.get("naam", ""), "Het meubelboek", "definitie().naam")
	gelijk(def.get("kamer", ""), "receptie", "definitie().kamer")
	var hs: Dictionary = def.get("hotspot", {})
	gelijk(hs.get("obj", ""), "boek", "de ingang hangt aan het boek")
	gelijk(hs.get("icoon", ""), "📖", "met het pictogram van §1.1")
	gelijk(hs.get("label", ""), "Boek", "en het label van §1.1")
	gelijk(hs.get("hoog", 0), 16, "hoog 16")
	var taak: Dictionary = def.get("taak", {})
	gelijk(taak.get("id", ""), "meubels", "het prikbordkaartje heet meubels")
	gelijk(taak.get("icoon", ""), "📖", "kaartje-pictogram")
	gelijk(taak.get("tekst", ""), "Koop iets moois", "kaartje-tekst, letterlijk")
	gelijk(taak.get("prio", 0), 5, "prio 5")
	waar(Ui.keur_taak("meubels", str(taak.get("tekst", ""))), "≤ 6 woorden (HOTEL.md §9)")
	# `wanneer`: het kaartje verschijnt vanaf 5 munten
	var wanneer: Callable = taak["wanneer"]
	waar(not bool(wanneer.call({"munten": 4})), "bij 4 munten geen kaartje")
	waar(bool(wanneer.call({"munten": 5})), "bij 5 munten wel")

## Het kaartje staat echt op het prikbord, en de 📖-ingang echt in de receptie
## (architecture.md §12.2, "registreert via de mapscan en verschijnt op het
## prikbord/de hotspot volgens zijn rij").
func test_kaartje_en_ingang_staan_er_echt() -> void:
	await _op(Vector2(1000, 648), 3, 9)
	Hotel.bouw_taken(true)
	var gevonden := {}
	for q in Hotel.spel_taken():
		gevonden[str(q.get("id", ""))] = q
	waar(gevonden.has("meubels"), "het spel levert een prikbordkaartje")
	if gevonden.has("meubels"):
		var q: Dictionary = gevonden["meubels"]
		gelijk(q.get("tekst", ""), "Koop iets moois", "met zijn eigen regel")
		gelijk(q.get("icoon", ""), "📖", "en zijn eigen pictogram")
		gelijk(q.get("kamer", ""), "receptie", "en zijn eigen kamer")
		gelijk(q.get("actie", ""), "game:meubels", "een tik start het spel")
	# bij minder dan 5 munten hoort het kaartje er niet te staan
	State.s["munten"] = 4
	var arm := false
	for q in Hotel.spel_taken():
		if str(q.get("id", "")) == "meubels":
			arm = true
	waar(not arm, "met 4 munten valt het kaartje weg")
	State.s["munten"] = 9
	# de ingangsknop hangt op het boek in de receptie en dekt het niet
	World.naar("receptie")
	Games.hersteek()
	Hits.plaats()
	var ingang := Hits.spot("spel_meubels")
	waar(ingang != null, "de 📖-ingang staat in de receptie")
	if ingang != null:
		gelijk(ingang.door, "registry", "en is van het register")
		gelijk(Hits.dekking("spel_meubels"), 0.0, "hij dekt het boek niet af")
		var r: Rect2 = Hits.debug()["spel_meubels"]["rect"]
		waar(r.size.x >= 48.0 and r.size.y >= 48.0, "en is een tikdoel")
	_af()

func test_ontgrendelt_vanaf_drie_gasten() -> void:
	var bewaard := State.s.duplicate(true)
	State.nieuw_spel()
	for n in 5:
		State.s["gasten"] = _gasten(n)
		gelijk(Games.ontgrendeld("meubels"), n >= 3,
			"N = %d ontgrendelt %s" % [n, "wel" if n >= 3 else "niet"])
	State.s = bewaard

# ==================================================================================
# 2. een hele beurt per band
# ==================================================================================

## Groep 3: één ding per keer, precies betalen, geen wisselgeld — en sinds de
## Rekenwacht ook bij één ding: genoeg? → munten → hoeveel houd je over?
func test_beurt_band_3() -> void:
	await _op(Vector2(1000, 648), 3, 9)
	gelijk(State.band(), 3, "de band is 3")
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	gelijk(Sommen.Meubels.max_lijst(3), 1, "groep 3 koopt één ding per keer")
	waar(_blad_knop("Kk_mandje") != null, "het mandje staat in het boek")
	gelijk(_blad_knop("Kk_mandje").text, "🛒", "met een 🛒")
	gelijk(_blad_knop("Kk_badkuip").text, "🛒",
		"de badkuip ook: of je genoeg hebt is de vraag bij de kassa")
	waar(_blad_tik("Kk_mandje"), "tik op 🛒 bij het mandje")
	await _tel_frames()
	# eerst de vergelijking: genoeg?
	gelijk(_kaart_tekst("mb_genoeg", "regel"), "🧺 Mandje kost €3", "de prijszin")
	gelijk(_kaart_tekst("mb_genoeg", "regel2"), "Je hebt €9. Is dat genoeg?", "de vraag")
	gelijk(_strook_knoppen("mb_genoeg").size(), 2, "twee knoppen: genoeg en te weinig")
	waar(_kies("mb_genoeg", "ja"), "genoeg")
	waar(await _wacht_op("mb_bon_keuzes"), "de bon met de muntstrook")
	# de bon hangt op de kassa, met de prijs in het vakje
	gelijk(_kaart_tekst("mb_bon", "regel"), "🧺 Mandje kost €3", "de prijszin")
	gelijk(_kaart_tekst("mb_bon", "regel2"), Spel.T_LEG_MUNTEN, "en de tweede regel")
	gelijk(_kaart_tekst("mb_bon", "vak"), "€3", "het vakje draagt het bedrag")
	gelijk(_kaart_tekst("mb_bon", "som"), "🧺 = €3",
		"en de somregel ook: met een muntstrook is er geen vakje te zien")
	waar(_er_is("mb_bank"), "de toonbank staat er")
	waar(_er_is("mb_boek"), "en de weg terug naar het boek")
	waar(not _er_is("mb_ok"), "geen ✔ Klaar meer: de stapel wordt zelf gekeurd")
	# buidel(9) = [2,2,2,2,1]: de strook biedt €1 en €2
	gelijk(str(_munten_op_strook()), "[1, 2]", "de muntsoorten in je hand")
	waar(_leg(1), "leg de munt van 1 neer")
	gelijk(_titel("mb_bank"), "de toonbank: €1", "de toonbank telt mee")
	waar(_er_is("mb_terug"), "en nu kan er een munt terug")
	waar(not _er_is("mb_boek"), "en niet meer terug naar het boek")
	var sterren_voor := int(State.s["sterren"])
	waar(_leg(2), "leg de munt van 2 neer: precies €3")
	gelijk(int(State.s["munten"]), 9, "nog niets betaald: eerst de laatste vraag")
	waar(await _wacht_op("mb_over_keuzes"), "hoeveel houd je over?")
	gelijk(_kaart_tekst("mb_over", "som"), "€9 − €3 =", "de som, met een echte −")
	gelijk(_kaart_tekst("mb_over", "regel"), "💰 Je hebt €9, het kost €3", "de zin")
	gelijk(_kaart_tekst("mb_over", "regel2"), Spel.T_OVER_VRAAG, "en de vraag")
	waar(_typ("mb_over", 6), "tik 6")
	gelijk(int(State.s["munten"]), 6, "de munten gaan uit de kassa")
	gelijk(int(State.s["sterren"]), sterren_voor + 1, "één ster voor het meedoen")
	gelijk(str(_spel().call("_nog")), '["mandje"]', "het mandje wacht op een plekje")
	_keur_taak_afgevinkt()
	await _wacht(1.4)
	await _tel_frames()
	# bladzijde 3: neerzetten
	var vak := _eerste_vak()
	waar(not vak.is_empty(), "er ligt een ✨-vakje klaar")
	waar(_er_is("mb_doos"), "en de doos staat erbij")
	var voor := ctx_meubels().size()
	waar(_tik(vak), "zet het mandje neer")
	gelijk(ctx_meubels().size(), voor + 1, "er staat een meubel bij")
	gelijk(str(_spel().call("_nog")), "[]", "en de doos is leeg")
	await _wacht(2.3)
	gelijk(Games.actief(), "", "het spel ging vanzelf dicht: geen ✖ nodig")
	_af()

## Groep 4: twee dingen samen (het tweede rekent meteen af), en wisselgeld.
func test_beurt_band_4() -> void:
	await _op(Vector2(1000, 648), 5, 12)
	gelijk(State.band(), 4, "de band is 4")
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	gelijk(Sommen.Meubels.max_lijst(4), 2, "groep 4 legt twee dingen op het lijstje")
	gelijk(_blad_knop("Kk_plant").text, "+", "de knop is nu +")
	waar(_blad_tik("Kk_plant"), "plant erbij")
	await _tel_frames()
	gelijk(_blad_knop("Kk_plant").text, "1×", "en staat er als 1×")
	waar(_blad_knop("Kafrekenen") != null, "met één ding staat er een afrekenknop")
	gelijk(_blad_knop("Kafrekenen").tooltip_text, Spel.T_AFREKENEN, "aria Afrekenen")
	gelijk(_blad_knop("Kleeg").tooltip_text, Spel.T_LIJST_LEEG, "aria Lijstje leeg")
	waar(_blad_tik("Kk_mandje"), "mandje erbij: het lijstje is vol")
	await _tel_frames()
	waar(not Ui.blad_open_nu(), "een vol lijstje rekent meteen af")
	# stap som
	gelijk(_kaart_tekst("mb_som", "som"), "€1 + €3 =", "de som staat op de kassa")
	gelijk(_kaart_tekst("mb_som", "regel"), "🛒 Plant €1 en mandje €3", "de somzin")
	gelijk(_kaart_tekst("mb_som", "regel2"), Spel.T_SAMEN, "en de vraag")
	waar(_typ("mb_som", 4), "tik 4 op de strook")
	waar(await _wacht_op("mb_genoeg_keuzes"), "genoeg?")
	gelijk(_kaart_tekst("mb_genoeg", "regel"), "🛒 Plant en mandje kosten €4", "de prijszin")
	waar(_kies("mb_genoeg", "ja"), "genoeg")
	waar(await _wacht_op("mb_bon_keuzes"), "de bon")
	# stap munten: buidel(12) = [5,2,2,2,1]; €5 is te veel -> wisselgeld
	gelijk(_kaart_tekst("mb_bon", "regel"), "🛒 Plant en mandje kosten €4", "de prijszin")
	gelijk(str(_munten_op_strook()), "[1, 2, 5]", "de muntsoorten in je hand")
	waar(_leg(5), "leg €5 neer")
	waar(await _wacht_op("mb_wissel_keuzes"), "de wisselvraag")
	gelijk(_kaart_tekst("mb_wissel", "som"), "€5 − €4 =", "de wisselsom, met een echte −")
	gelijk(_kaart_tekst("mb_wissel", "regel"), "👛 Je gaf €5, het kost €4", "de wisselzin")
	gelijk(_kaart_tekst("mb_wissel", "regel2"), Spel.T_TERUG_VRAAG, "en de vraag")
	var sterren_voor := int(State.s["sterren"])
	waar(_typ("mb_wissel", 1), "tik het wisselgeld")
	waar(await _wacht_op("mb_over_keuzes"), "hoeveel houd je over?")
	gelijk(_kaart_tekst("mb_over", "som"), "€12 − €4 =", "de oversom")
	waar(_typ("mb_over", 8), "tik 8")
	gelijk(int(State.s["munten"]), 8, "de prijs gaat uit de kassa, niet het gelegde bedrag")
	gelijk(int(State.s["sterren"]), sterren_voor + 1, "één ster")
	gelijk(str(_spel().call("_nog")), '["plant", "mandje"]', "twee dingen wachten")
	await _wacht(1.4)
	await _tel_frames()
	# twee keer neerzetten
	for beurt in 2:
		var vak := _eerste_vak()
		waar(not vak.is_empty(), "er is een vakje (beurt %d)" % beurt)
		if vak.is_empty():
			break
		waar(_tik(vak), "zet neer (beurt %d)" % beurt)
		await _tel_frames()
	gelijk(str(_spel().call("_nog")), "[]", "de doos is leeg")
	_af()

## Groep 5: dezelfde regels als groep 4, met de grotere buidel.  Precies
## betalen geeft in groep 4/5 ook de wisselvraag: €9 − €9 = €0.
func test_beurt_band_5() -> void:
	await _op(Vector2(1000, 648), 7, 20)
	gelijk(State.band(), 5, "de band is 5")
	gelijk(Sommen.Meubels.buidel_max(5), 20, "de buidel gaat tot 20")
	waar(Sommen.Meubels.wisselgeld(5), "en er is wisselgeld")
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	waar(_blad_tik("Kk_bed"), "bed erbij")
	await _tel_frames()
	waar(_blad_tik("Kk_speelmand"), "speelmand erbij: afrekenen")
	await _tel_frames()
	gelijk(_kaart_tekst("mb_som", "som"), "€5 + €4 =", "de som")
	waar(_typ("mb_som", 9), "tik 9")
	waar(await _wacht_op("mb_genoeg_keuzes"), "genoeg?")
	waar(_kies("mb_genoeg", "ja"), "genoeg")
	waar(await _wacht_op("mb_bon_keuzes"), "de bon")
	# buidel(20) = precies te leggen
	var gelegd := _leg_precies(9)
	gelijk(gelegd, 9, "er ligt precies €9 op de toonbank")
	waar(await _wacht_op("mb_wissel_keuzes"), "ook bij precies betalen: de wisselvraag")
	gelijk(_kaart_tekst("mb_wissel", "som"), "€9 − €9 =", "nul is een uitkomst")
	waar(_strook_knop("mb_wissel", 0) != null, "en 0 staat op de strook")
	waar(_typ("mb_wissel", 0), "tik 0")
	waar(await _wacht_op("mb_over_keuzes"), "hoeveel houd je over?")
	var bedden_voor := State.alle_bedden().size()
	var cap_voor := State.max_gasten()
	waar(_typ("mb_over", 11), "tik 11")
	gelijk(int(State.s["munten"]), 11, "20 − 9 = 11 in de kassa")
	await _wacht(1.4)
	await _tel_frames()
	for beurt in 2:
		var vak := _eerste_vak()
		if vak.is_empty():
			fout("geen vakje in beurt %d" % beurt)
			break
		waar(_tik(vak), "zet neer (beurt %d)" % beurt)
		await _tel_frames()
	gelijk(State.alle_bedden().size(), bedden_voor + 1, "het gekochte bed staat in de kamer")
	# Sinds 2026-09-24 (bedden: een kamer kiezen bij het inchecken) is de vrije
	# vloer de gastenlimiet: tot zes bedden per kamer zet de check-in ze zelf neer,
	# dus een gekocht bed verhoogt de limiet pas boven die zes.
	waar(State.max_gasten() >= cap_voor, "de gastenlimiet zakt er nooit door")
	_af()

## Leg net zolang munten neer tot het bedrag klopt: telkens de grootste munt van
## de strook die nog past.  Precies wat een kind doet, alleen sneller.  Alles wat
## deze lus weet, leest ze van de knoppen zelf (de toonbank en de muntstrook);
## elke gelegde munt telt voor R1 als rekenen (een gekeurde handeling).
func _leg_precies(doel: int) -> int:
	var geteld := maxi(0, _op_de_bank())
	for _poging in 30:
		if geteld >= doel:
			return geteld
		var beste := 0
		for v in _munten_op_strook():
			if v <= doel - geteld:
				beste = maxi(beste, v)
		if beste <= 0 or not _leg(beste):
			return geteld
		_tel("reken")
		geteld += beste
	return geteld

func _op_de_bank() -> int:
	var t := _titel("mb_bank")
	if not t.begins_with("de toonbank: €"):
		return -1
	return t.substr("de toonbank: €".length()).split(" ")[0].to_int()







## Het prikbordkaartje van vandaag draagt een vinkje.
func _keur_taak_afgevinkt() -> void:
	var gevonden := false
	for q in State.s["taken"]:
		if str(q.get("id", "")) == "meubels" or str(q.get("spel", "")) == "meubels":
			gevonden = true
			waar(bool(q.get("klaar", false)), "het prikbordkaartje is afgevinkt")
	if not gevonden:
		Hotel.bouw_taken(true)
		for q in State.s["taken"]:
			if str(q.get("id", "")) == "meubels":
				waar(bool(q.get("klaar", false)),
					"het prikbordkaartje blijft afgevinkt na een herbouw")

func _eerste_vak() -> String:
	for id in Hits.lijst():
		if id.begins_with("mbvak_"):
			return id
	return ""

func ctx_meubels() -> Array:
	return World.kamer_meubels()

## De knoppen van een antwoordstrook, zoals een vinger ze ziet.
func _strook_knoppen(kaart_id: String) -> Array:
	var strook := Hits.spot(kaart_id + "_keuzes")
	if strook == null or not is_instance_valid(strook.knoop):
		return []
	var rij := strook.knoop.get_node_or_null("Rij")
	return [] if rij == null else rij.get_children()

func _strook_knop(kaart_id: String, getal: int) -> Button:
	var strook := Hits.spot(kaart_id + "_keuzes")
	if strook == null or not is_instance_valid(strook.knoop):
		return null
	return strook.knoop.get_node_or_null("Rij/Kn%d" % getal) as Button

## Wat er in een wolkje staat: pictogram, getal en zin, elk apart.
func _wolk_deel(id: String, veld: String) -> String:
	var s := Hits.spot(id)
	if s == null or not is_instance_valid(s.knoop) or not (s.knoop is UiWolk):
		return ""
	var w := s.knoop as UiWolk
	match veld:
		"icoon": return w.icoon_label.text
		"getal": return w.getal_label.text
		"tekst": return w.zeg_label.text
	return ""

# ==================================================================================
# 2b. de buidelvraag bij de kassa (PLAN.md §3.8 `N6`, open vraag V4)
# ==================================================================================

## R1: binnen een seconde na de tik staat er een som mét strook — in de wereld,
## bij de kassa, en niet het winkelblad.
func test_het_spel_begint_met_een_muntvraag() -> void:
	await _op(Vector2(1000, 648), 3, 9)
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	waar(not Ui.blad_open_nu(), "het boek staat nog dicht")
	waar(_er_is("mb_kas"), "er hangt een somkaart bij de kassa")
	gelijk(_kaart_tekst("mb_kas", "regel"), "💰 Hoeveel euro heb je?",
		"de vraag, met het pictogram vooraan op dezelfde regel")
	waar(Ui.keur_regel("mb_kas", Spel.T_HOEVEEL), "≤ 8 woorden én ≤ 40 tekens")
	gelijk(_kaart_tekst("mb_kas", "som"), "💰 =", "de somregel")
	gelijk(_kaart_tekst("mb_kas", "hulp"), "", "en nog geen hulpregel")
	# de munten liggen echt op de toonbank: buidel(9) = [2, 2, 2, 2, 1]
	waar(_er_is("mb_munten"), "de munten liggen op de toonbank")
	gelijk(_wolk_deel("mb_munten", "getal"), "€2 €2 €2 €2 €1",
		"elke munt draagt zijn eigen waarde")
	gelijk(_wolk_deel("mb_munten", "icoon"), "🪙", "met het muntpictogram ernaast")
	gelijk(_titel("mb_munten"), Spel.T_OP_TAFEL, "en de titel van §5.9")
	waar(_er_is("mb_buidel"), "de buidel staat erbij")
	gelijk(_titel("mb_buidel"), "je buidel: 5 munten",
		"die het AANTAL munten draagt, niet hun waarde")
	# vier knoppen, elk met pictogram én bedrag (HOTEL.md §9)
	var knoppen := _strook_knoppen("mb_kas")
	gelijk(knoppen.size(), 4, "vier knoppen op de strook")
	for k in knoppen:
		waar((k as Button).text.begins_with("🪙 €"),
			'knop "%s" draagt pictogram én bedrag' % (k as Button).text)
	waar(_strook_knop("mb_kas", 9) != null, "en het goede antwoord staat erbij")
	gelijk(str(State.spel_data("meubels").get("view", "")), "kassa",
		"de stand staat in het laatje")
	_af()

## Stap 0: met een lege buidel valt er niets te tellen — dan meteen het boek,
## en wel op de sterrenbladzijde: daar is het enige dat je kunt halen, en elke
## sticker vraagt zelf rekenen (Rekenwacht).
func test_nul_munten_slaat_de_vraag_over() -> void:
	await _op(Vector2(1000, 648), 3, 0)
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	waar(not _er_is("mb_kas"), "er komt geen som met goed = 0")
	waar(not _er_is("mb_munten"), "en geen lege toonbank")
	waar(Ui.blad_open_nu(), "het boek gaat meteen open")
	waar(_blad_knop("Kv_vlag") != null, "op de sterrenbladzijde")
	waar(_er_is("mb_geen"), "met een wolkje dat zegt waarom")
	gelijk(_wolk_deel("mb_geen", "icoon"), "💰", "het pictogram van het wolkje")
	gelijk(_wolk_deel("mb_geen", "tekst"), Spel.T_GEEN_MUNTEN, "Nog geen munten")
	gelijk(str(State.spel_data("meubels").get("view", "")), "boek",
		"en de stand staat op het boek")
	_af()

## De eigenaar, 2026-09-24: "Nee geef geen hulp na fouten.  Kinderen moeten
## zelf leren rekenen."  Drie foute sommen bij het afrekenen, drie foute
## antwoorden op "Heb je genoeg?" en drie foute antwoorden op "Hoeveel houd je
## over?": elke keer `🔄 Nog een keer` bij de kassa en verder niets — geen
## doortellen, geen "+€3", geen spookmunten.  Nooit straffen: niets afgepakt,
## en de goede antwoorden leveren nog gewoon een ster op.
func test_geen_hulp_en_nooit_straffen() -> void:
	await _op(Vector2(1000, 648), 5, 12)
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	waar(_blad_tik("Kk_plant"), "plant erbij")
	await _tel_frames()
	waar(_blad_tik("Kk_mandje"), "mandje erbij: afrekenen")
	await _tel_frames()
	var munten_voor := int(State.s["munten"])
	var sterren_voor := int(State.s["sterren"])
	gelijk(_kaart_tekst("mb_som", "hulp"), "", "eerst geen hulpregel")
	var voor := beeld("meubels")
	waar(voor.has("mb_boek"), "vóór een misser mag je nog terug naar het boek")
	voor.erase("mb_boek")       # R2: na een misser is die weg terug er niet meer
	for keer in 3:
		var wat := "som, misser %d" % (keer + 1)
		waar(_typ_fout("mb_som", 4), "%s: een fout antwoord" % wat)
		await _tel_frames()
		waar(_op_slot("mb_som"), "%s: de strook staat even op slot" % wat)
		_alleen_teleurstelling("mb_som", wat)
		await _wacht_mispauze()
		niets_erbij(voor, beeld("meubels"), wat)
	gelijk(int(State.s["munten"]), munten_voor, "er is geen munt afgepakt")
	gelijk(int(State.s["sterren"]), sterren_voor, "en geen ster afgepakt")
	waar(_er_is("mb_som"), "de kaart staat er nog")
	waar(_typ("mb_som", 4), "het goede antwoord")
	waar(await _wacht_op("mb_genoeg_keuzes"), "genoeg?")
	var gen := beeld("meubels")
	for keer in 3:
		var wat := "genoeg, misser %d" % (keer + 1)
		waar(_kies("mb_genoeg", "nee"), "%s: te weinig gezegd" % wat)
		await _tel_frames()
		waar(_op_slot("mb_genoeg"), "%s: de strook staat even op slot" % wat)
		_alleen_teleurstelling("mb_genoeg", wat)
		await _wacht_mispauze()
		niets_erbij(gen, beeld("meubels"), wat)
	waar(not Ui.blad_open_nu(), "een fout 'te weinig' brengt je niet terug naar het boek")
	waar(_kies("mb_genoeg", "ja"), "het goede antwoord")
	waar(await _wacht_op("mb_bon_keuzes"), "de bon")
	var gelegd := _leg_precies(4)
	gelijk(gelegd, 4, "leg €4 neer")
	waar(await _wacht_op("mb_wissel_keuzes"), "de wisselvraag")
	waar(_typ("mb_wissel", 0), "precies betaald: 0 terug")
	waar(await _wacht_op("mb_over_keuzes"), "hoeveel houd je over?")
	var over := beeld("meubels")
	for keer in 3:
		var wat := "over, misser %d" % (keer + 1)
		waar(_typ_fout("mb_over", 8), "%s: een fout antwoord" % wat)
		await _tel_frames()
		waar(_op_slot("mb_over"), "%s: de strook staat even op slot" % wat)
		_alleen_teleurstelling("mb_over", wat)
		gelijk(int(State.s["munten"]), munten_voor, "%s: er is nog niets betaald" % wat)
		await _wacht_mispauze()
		niets_erbij(over, beeld("meubels"), wat)
	waar(_typ("mb_over", 8), "het goede antwoord")
	gelijk(int(State.s["munten"]), 8, "nu pas betaald")
	gelijk(int(State.s["sterren"]), sterren_voor + 1,
		"de ster komt er ook na negen missers (F5)")
	_af()

## Een fout wisselgeld (groep 4 en 5): dezelfde pauze, en geen telladder.
func test_geen_hulp_bij_het_wisselgeld() -> void:
	await _op(Vector2(1000, 648), 5, 12)
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	waar(_blad_tik("Kk_plant"), "plant erbij")
	await _tel_frames()
	waar(_blad_tik("Kk_mandje"), "mandje erbij: afrekenen")
	await _tel_frames()
	waar(_typ("mb_som", 4), "de som")
	waar(await _wacht_op("mb_genoeg_keuzes"), "genoeg?")
	waar(_kies("mb_genoeg", "ja"), "genoeg")
	waar(await _wacht_op("mb_bon_keuzes"), "de bon")
	# buidel(12) = [5,2,2,2,1]: leg €5 neer, dan de wisselvraag (geen ✔ Klaar)
	waar(_leg(5), "leg €5 neer")
	waar(await _wacht_op("mb_wissel_keuzes"), "de wisselvraag staat er")
	var voor := beeld("meubels")
	for keer in 3:
		var wat := "wisselgeld, misser %d" % (keer + 1)
		waar(_typ_fout("mb_wissel", 1), "%s: een fout getal" % wat)
		await _tel_frames()
		waar(_op_slot("mb_wissel"), "%s: de strook staat even op slot" % wat)
		_alleen_teleurstelling("mb_wissel", wat)
		await _wacht_mispauze()
		niets_erbij(voor, beeld("meubels"), wat)
	waar(_typ("mb_wissel", 1), "het goede wisselgeld")
	waar(await _wacht_op("mb_over_keuzes"), "hoeveel houd je over?")
	waar(_typ("mb_over", 8), "het goede antwoord")
	gelijk(int(State.s["munten"]), 8, "de prijs gaat uit de kassa")
	_af()

## Groep 3 rekent geen wisselgeld uit: te veel op de toonbank is een misser
## zonder hulp — de stapel gaat terug in je hand, dezelfde bon blijft staan.
## En « pakt een munt terug (vrij spel), zolang er iets ligt.
func test_groep_drie_pakt_een_munt_terug() -> void:
	await _op(Vector2(1000, 648), 3, 9)
	waar(not Sommen.Meubels.wisselgeld(3), "groep 3 kent nog geen wisselgeld")
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	waar(_blad_tik("Kk_mandje"), "koop het mandje van €3")
	await _tel_frames()
	waar(_kies("mb_genoeg", "ja"), "genoeg")
	waar(await _wacht_op("mb_bon_keuzes"), "de bon")
	# buidel(9) = [2,2,2,2,1]: leg €1 neer en pak hem terug met «
	waar(_leg(1), "leg €1 neer")
	waar(_er_is("mb_terug"), "de knop om een munt terug te pakken")
	gelijk(_titel("mb_terug"), Spel.T_MUNT_TERUG, "met de titel van §5.9")
	waar(_tik("mb_terug"), "pak de munt terug")
	gelijk(_titel("mb_bank"), "de toonbank: €0", "de toonbank is weer leeg")
	# nu te veel: €2 + €2 = €4 voor een mandje van €3
	waar(_leg(2), "leg €2 neer")
	waar(_leg(2), "en nog €2: te veel")
	await _tel_frames()
	waar(not _er_is("mb_wissel"), "er komt géén wisselkaart in groep 3")
	_alleen_teleurstelling("mb_bon", "te veel")
	gelijk(int(State.s["munten"]), 9, "er is niets betaald")
	await _wacht_mispauze()
	gelijk(_titel("mb_bank"), "de toonbank: €0", "de stapel ging terug in je hand")
	gelijk(_kaart_tekst("mb_bon", "vak"), "€3", "dezelfde bon, dezelfde prijs")
	gelijk(str(_munten_op_strook()), "[1, 2]", "en dezelfde munten")
	waar(_leg(2) and _leg(1), "€2 + €1: precies")
	waar(await _wacht_op("mb_over_keuzes"), "hoeveel houd je over?")
	waar(_typ("mb_over", 6), "9 − 3 = 6")
	gelijk(int(State.s["munten"]), 6, "drie munten betaald")
	_af()

## Rekenwacht: het boek zegt niet meer vooraf of je genoeg hebt (vroeger 💛).
## Wie de badkuip van €8 met €3 wil, krijgt de vraag "Heb je genoeg?" — en het
## goede antwoord "💛 Te weinig" geeft het spaarwolkje.  Er gaat niets op slot.
func test_te_weinig_geld_zet_niets_op_slot() -> void:
	await _op(Vector2(1000, 648), 3, 3)
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	gelijk(_blad_knop("Kk_badkuip").text, "🛒", "de badkuip heeft gewoon een 🛒")
	gelijk(_blad_knop("Kk_badkuip").tooltip_text, "badkuip kopen, 8 euro",
		"en staat gewoon in het boek")
	waar(_blad_tik("Kk_badkuip"), "tik hem aan")
	await _tel_frames()
	waar(_er_is("mb_genoeg"), "de vraag: heb je genoeg?")
	gelijk(_kaart_tekst("mb_genoeg", "regel2"), "Je hebt €3. Is dat genoeg?", "de vraag")
	waar(_kies("mb_genoeg", "nee"), "te weinig: goed gezegd")
	await _tel_frames()
	waar(_er_is("mb_spaar"), "er komt een spaarwolkje")
	gelijk(_titel("mb_spaar"), "💛 €8 je hebt €3", "met de prijs en wat je hebt")
	gelijk(int(State.s["munten"]), 3, "er is niets afgeschreven")
	waar(Ui.blad_open_nu(), "het boek staat weer open")
	waar(_blad_knop("Kk_badkuip") != null, "en de badkuip staat er nog")
	waar(_blad_knop("Kk_plant") != null and _blad_knop("Kk_plant").text == "🛒",
		"wat je wel kunt betalen blijft gewoon te koop")
	gelijk(State.spel_data("meubels").get("open", null), null, "er staat geen open vraag")
	_af()

## Versiering kost sterren, en die gaan pas af na "Heb je genoeg?" en "Hoeveel
## houd je over?" (Rekenwacht: geen sticker zonder rekenen).
func test_versiering_kost_sterren() -> void:
	await _op(Vector2(1000, 648), 3, 5)
	State.s["sterren"] = 2
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	waar(_blad_tik("Ktab_versiering"), "naar de sterrenpagina")
	await _tel_frames()
	gelijk(_blad_knop("Kv_vlag").tooltip_text, "vlaggetjes kopen voor 1 sterren",
		"aria van §5.9")
	gelijk(_blad_knop("Kv_slinger").text, "🛒", "de slinger van 3 sterren: de vraag beslist")
	waar(_blad_tik("Kv_slinger"), "tik hem aan")
	await _tel_frames()
	gelijk(_kaart_tekst("mb_genoeg", "regel"), "🎈 Dit kost 3 ⭐", "de prijs in sterren")
	gelijk(_kaart_tekst("mb_genoeg", "regel2"), "Je hebt 2⭐. Is dat genoeg?", "de vraag")
	waar(_kies("mb_genoeg", "nee"), "te weinig: goed gezegd")
	await _tel_frames()
	gelijk(int(State.s["sterren"]), 2, "er gaat geen ster af")
	gelijk(_titel("mb_spaar"), "⭐ 3 je hebt 2", "wel een spaarwolkje")
	waar(_blad_tik("Kv_vlag"), "koop de vlaggetjes")
	await _tel_frames()
	waar(_kies("mb_genoeg", "ja"), "genoeg")
	gelijk(int(State.s["sterren"]), 2, "nog geen ster af: eerst de laatste vraag")
	waar(await _wacht_op("mb_over_keuzes"), "hoeveel houd je over?")
	gelijk(_kaart_tekst("mb_over", "som"), "⭐ 2 − 1 =", "de oversom in sterren")
	waar(_typ("mb_over", 1), "2 − 1 = 1")
	gelijk(int(State.s["sterren"]), 1, "één ster betaald")
	var q: Dictionary = State.spel_data("meubels")
	gelijk(int((q["versiering"] as Dictionary).get("vlag", 0)), 1, "en je hebt er een")
	await _wacht(1.9)
	gelijk(Games.actief(), "", "daarna gaat het spel vanzelf dicht")
	_af()

func test_herstel_uit_ctx_data() -> void:
	await _op(Vector2(1000, 648), 5, 12)
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	waar(_blad_tik("Kk_plant"), "plant erbij")
	await _tel_frames()
	waar(_blad_tik("Kk_mandje"), "mandje erbij: afrekenen")
	await _tel_frames()
	waar(_typ("mb_som", 4), "de som")
	waar(await _wacht_op("mb_genoeg_keuzes"), "genoeg?")
	waar(_kies("mb_genoeg", "ja"), "genoeg")
	waar(await _wacht_op("mb_bon_keuzes"), "de bon")
	var gelegd := _leg_precies(4)
	gelijk(gelegd, 4, "leg €4 neer")
	waar(await _wacht_op("mb_wissel_keuzes"), "wisselgeld")
	waar(_typ("mb_wissel", 0), "0 terug")
	waar(await _wacht_op("mb_over_keuzes"), "over")
	waar(_typ("mb_over", 8), "8 over")
	await _wacht(1.4)
	await _tel_frames()
	var voor: Dictionary = State.spel_data("meubels").duplicate(true)
	gelijk(str(voor["wacht"]), '{ "nog": ["plant", "mandje"] }',
		"twee dingen staan in het laatje")
	# een herlaad: het spel stopt, de wereld gaat leeg, het spel start opnieuw
	Games.stop()
	await _tel_frames()
	waar(Games.start("meubels"), "opnieuw gestart")
	await _tel_frames()
	gelijk(str(State.spel_data("meubels")["wacht"]), str(voor["wacht"]),
		"de wachtrij overleeft de herlaad")
	waar(_er_is("mb_doos"), "en het spel staat meteen op de plaatsstap")
	waar(not _eerste_vak().is_empty(), "met een vakje om in te zetten")
	waar(not Ui.blad_open_nu(), "het boek staat niet open: eerst neerzetten")
	waar(_tik(_eerste_vak()), "zet de plant neer")
	await _tel_frames()
	gelijk(str(_spel().call("_nog")), '["mandje"]', "er blijft er één over")
	_af()

func test_stop_laat_de_wereld_schoon() -> void:
	await _op(Vector2(1000, 648), 5, 12)
	Hits.maak({"id": "vreemde_knop", "kamer": "receptie", "x": 8.0, "z": 8.0, "y": 10.0,
		"icoon": "🔔", "label": "Bel", "door": "keurmeester", "aan": func(_s) -> void: pass})
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	waar(_blad_tik("Kk_plant"), "plant erbij")
	await _tel_frames()
	waar(_blad_tik("Kafrekenen"), "afrekenen")
	await _tel_frames()
	var eigen := 0
	for id in Hits.lijst():
		if Hits.spot(id).door == "meubels":
			eigen += 1
	waar(eigen >= 3, "het spel plaatste eigen hotspots (%d)" % eigen)
	waar(World.decor_lijst("receptie").any(func(d): return str(d["door"]) == "meubels"),
		"en eigen decor")
	waar(Ui.blad_open_nu() == false, "tijdens het betalen staat er geen blad")
	Games.stop()
	await _tel_frames()
	for id in Hits.lijst():
		waar(Hits.spot(id).door != "meubels", "geen hotspot bleef staan: %s" % id)
	gelijk(World.decor_lijst().filter(func(d): return str(d["door"]) == "meubels").size(), 0,
		"en geen los decor")
	waar(not Ui.blad_open_nu(), "het blad is dicht")
	gelijk(Hits.voorrang_van(), "", "niemand heeft voorrang")
	waar(Hits.spot("vreemde_knop") != null, "de knop van een ander bleef staan")
	waar(not World.kamer_veranderd.is_connected(Callable(_spel(), "_op_kamer")) if _spel() != null else true,
		"en de kamerluisteraar is losgekoppeld")
	_af()

## R3: er is geen route langs de som heen, en een misser kost niets en helpt
## niet (eigenaar 2026-09-24): drie foute antwoorden op de kassavraag, elke
## keer `🔄 Nog een keer` en de strook even op slot — geen telladder langs de
## munten, geen spookmunten — en daarna precies dezelfde kaart.
func test_het_boek_komt_pas_na_het_goede_antwoord() -> void:
	await _op(Vector2(1000, 648), 3, 9)
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	var munten_voor := int(State.s["munten"])
	var sterren_voor := int(State.s["sterren"])
	var voor := beeld("meubels")
	waar(voor.has("mb_kas") and voor.has("mb_kas_keuzes"), "het beeld kent de kassavraag")
	for keer in 3:
		var wat := "kassa, misser %d" % (keer + 1)
		waar(_typ_fout("mb_kas", 9), "%s: een fout antwoord" % wat)
		await _tel_frames()
		waar(not Ui.blad_open_nu(), "%s: het boek blijft dicht" % wat)
		waar(_op_slot("mb_kas"), "%s: de strook staat even op slot" % wat)
		_alleen_teleurstelling("mb_kas", wat)
		await _wacht_mispauze()
		niets_erbij(voor, beeld("meubels"), wat)
	gelijk(int(State.s["munten"]), munten_voor, "er is geen munt afgepakt")
	gelijk(int(State.s["sterren"]), sterren_voor, "en geen ster afgepakt")
	waar(not Ui.blad_open_nu(), "en het boek is nog altijd dicht")
	# het goede antwoord: een vinkje, en pas dán het boek
	waar(_typ("mb_kas", 9), "het goede antwoord")
	await _tel_frames()
	gelijk(_kaart_tekst("mb_kas", "som"), "💰 = €9", "de som staat af op de kaart")
	waar(_er_is("mb_af"), "en er staat een vinkje bij de kassa")
	gelijk(_wolk_deel("mb_af", "icoon"), "✅", "een groen vinkje")
	gelijk(_wolk_deel("mb_af", "getal"), "€9", "met het bedrag erbij")
	waar(not _er_is("mb_kas_keuzes"), "de strook is weg")
	for _p in 40:
		if Ui.blad_open_nu():
			break
		await _wacht(0.05)
	waar(Ui.blad_open_nu(), "het boek gaat open")
	waar(not _er_is("mb_kas"), "de kaart is opgeruimd")
	waar(_blad_knop("Kk_mandje") != null, "en nu pas staat het winkelblad er")
	_af()

## "Verder spelen" komt midden in de vraag terug.
func test_de_kassavraag_overleeft_een_herlaad() -> void:
	await _op(Vector2(1000, 648), 5, 12)
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	waar(_er_is("mb_kas"), "de vraag staat er")
	waar(_typ_fout("mb_kas", 12), "één misser, zodat er iets te herstellen valt")
	await _tel_frames()
	gelijk(str(State.spel_data("meubels").get("view", "")), "kassa",
		"het laatje weet waar het kind is")
	Games.stop()
	await _tel_frames()
	waar(not _er_is("mb_kas"), "stop ruimt de kaart op")
	waar(not _er_is("mb_buidel"), "en de buidel")
	waar(not _er_is("mb_munten"), "en de munten")
	gelijk(World.decor_lijst("receptie").filter(
		func(d): return str(d["door"]) == "meubels").size(), 0, "en het decor")
	waar(Games.start("meubels"), "opnieuw gestart")
	await _tel_frames()
	waar(_er_is("mb_kas"), "de kassavraag staat er weer")
	gelijk(_kaart_tekst("mb_kas", "regel"), "💰 Hoeveel euro heb je?", "met dezelfde vraag")
	waar(not Ui.blad_open_nu(), "en het boek nog steeds dicht")
	gelijk(str(State.spel_data("meubels").get("view", "")), "kassa", "de stand staat er nog")
	waar(_typ("mb_kas", 12), "het goede antwoord")
	for _p in 40:
		if Ui.blad_open_nu():
			break
		await _wacht(0.05)
	waar(Ui.blad_open_nu(), "en dan pas gaat het boek open")
	_af()

# ==================================================================================
# 3. geen hulp na een fout, en nooit straffen
# ==================================================================================




# ==================================================================================
# 4. te weinig geld, en versiering
# ==================================================================================



# ==================================================================================
# 5. herstellen uit ctx.data(), en opruimen
# ==================================================================================



func test_blad_dicht_geeft_de_wereldpagina() -> void:
	await _op(Vector2(1000, 648), 5, 12)
	# één eigen meubel neerzetten via het spel zelf
	var m: Dictionary = World.plaats_meubel("kamer1", "plant", 30.0, 100.0, 0)
	waar(not m.is_empty(), "er staat een plant in kamer1")
	var mid := str(m.get("id", m.get("meubel", "")))
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	(State.spel_data("meubels")["mijn"] as Array).append({"id": mid, "type": "plant"})
	waar(Ui.blad_open_nu(), "het boek staat open")
	Ui.blad_dicht()                       # zoals een tik naast het blad
	await _tel_frames()
	waar(_er_is("mb_boek"), "de wereldpagina heeft de weg terug naar het boek")
	gelijk(_titel("mb_boek"), Spel.T_TERUG_BOEK, "met de titel van §5.9")
	World.naar("kamer1")
	await _tel_frames()
	waar(_er_is("mbop_%s" % mid), "en je eigen plant heeft een 📦-knop")
	gelijk(_titel("mbop_%s" % mid), "plant oppakken", "met de titel van §5.9")
	waar(_tik("mbop_%s" % mid), "pak de plant op")
	await _tel_frames()
	gelijk(str(_spel().call("_nog")), '["plant"]', "de plant zit in de doos")
	gelijk(World.kamer_meubels("kamer1").filter(
		func(q): return str(q["id"]) == mid).size(), 0, "en staat niet meer in de kamer")
	_af()

## Eigenaar, 2026-09-24: "De eerste twee bedden zijn goed geplaatst, daarna gaat
## alles door elkaar."  Een bed uit de doos heeft een ✨-vakje op elke vrije
## bedplek van de slaapkamer en nergens anders; het landt precies daar, zoals
## bed1 en bed2 liggen; het krijgt geen 🔄 (elk bed van een slaapkamer ligt al
## zoals de kamer); en de vakjes van een plant blijven van de vrije bedplekken af.
func test_een_gekocht_bed_gaat_op_een_bedplek() -> void:
	await _op(Vector2(1000, 648), 5, 12)
	State.spel_data("meubels")["wacht"] = {"nog": ["bed", "plant"]}
	waar(Games.start("meubels"), "het spel start op de plaatsstap")
	await _tel_frames(3)
	gelijk(World.kamer_nu(), "kamer1", "de doos gaat naar kamer 1")
	var vrij := Rooms.vrije_bedplekken("kamer1")
	gelijk(vrij.size(), 2, "kamer 1 heeft twee vrije bedplekken")
	var vakken := _vakken()
	gelijk(vakken.size(), vrij.size(), "één ✨-vakje per vrije bedplek")
	for id in vakken:
		var s := Hits.spot(id)
		waar(vrij.has(Vector2(s.x, s.z)), "%s ligt op een bedplek (%s, %s)" % [id, s.x, s.z])
	waar(_tik(_eerste_vak()), "zet het bed neer")
	await _tel_frames()
	var nieuw: Array = Rooms.slots("kamer1", "bed").filter(
		func(b): return str(b["id"]).begins_with("m"))
	gelijk(nieuw.size(), 1, "er staat één gekocht bed")
	if nieuw.size() == 1:
		gelijk(Vector2(float(nieuw[0]["x"]), float(nieuw[0]["z"])), vrij[0],
			"op de eerste vrije bedplek")
		gelijk(str(nieuw[0]["model"]), Rooms.bed_model("kamer1"), "zoals bed1 en bed2")
	# nu de plant: geen vakje op de bedplek die nog vrij is
	gelijk(str(_spel().call("_nog")), '["plant"]', "de plant is aan de beurt")
	var bedplek := Rooms.bed_vlak(Rooms.bed_model("kamer1"), vrij[1].x, vrij[1].y)
	var planten := _vakken()
	waar(not planten.is_empty(), "de plant heeft vakjes")
	for id in planten:
		var s := Hits.spot(id)
		waar(not bedplek.grow(Rooms.MEUBEL_BED_RAND).has_point(Vector2(s.x, s.z)),
			"%s ligt niet op de vrije bedplek" % id)
		waar(Rooms.vrij_vak("kamer1", s.x, s.z), "%s is echt vrij" % id)
	# de wereldpagina: een 📦 bij het gekochte bed, geen 🔄
	Games.stop()
	await _tel_frames()
	State.spel_data("meubels")["wacht"] = {"nog": []}
	waar(Games.start("meubels"), "opnieuw gestart")
	await _tel_frames()
	await _kassa_door()
	if nieuw.size() == 1:
		var mid := str(nieuw[0]["id"])
		(State.spel_data("meubels")["mijn"] as Array).append({"id": mid, "type": "bed"})
		Ui.blad_dicht()
		await _tel_frames()
		World.naar("kamer1")
		await _tel_frames()
		waar(_er_is("mbop_%s" % mid), "het gekochte bed heeft een 📦-knop")
		waar(not _er_is("mbdraai_%s" % mid), "maar geen 🔄: het ligt al zoals de kamer")
	_af()

## Elke bedplek heeft een bed: een bed kopen kan dan niet, want het zou in de
## doos blijven zonder vakje.  Hetzelfde wolkje als de bel bij een vol hotel,
## en er gaat geen munt af.
func test_geen_bed_te_koop_als_alle_bedplekken_vol_zijn() -> void:
	await _op(Vector2(1000, 648), 3, 12)
	for k in Rooms.lijst():
		while not Rooms.meubel_zet(k, "bed").is_empty():
			pass
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	await _tel_frames()
	var munten := int(State.s["munten"])
	waar(_blad_tik("Kk_bed"), "tik op het bed")
	await _tel_frames()
	waar(_er_is("mb_bedvol"), "het wolkje zegt dat alle kamers vol zijn")
	gelijk(int(State.s["munten"]), munten, "er gaat geen munt af")
	gelijk(str(_spel().call("_nog")), "[]", "en er zit niets in de doos")
	_af()

func _vakken() -> Array[String]:
	var uit: Array[String] = []
	for id in Hits.lijst():
		if id.begins_with("mbvak_"):
			uit.append(id)
	return uit

# ==================================================================================
# 6. elke kinderzin letterlijk, en het tekstbudget van F4
# ==================================================================================

func test_teksten_staan_er_letterlijk() -> void:
	var bron := FileAccess.get_file_as_string("res://games/meubels/spel.gd")
	waar(not bron.is_empty(), "spel.gd is te lezen")
	# games-a.md §5.9, in volgorde van verschijnen (✔ "klaar met tellen" en de
	# buideltitel bestaan sinds de Rekenwacht niet meer: de munten liggen als
	# strook onder de bon en de stapel wordt zelf gekeurd)
	for zin in ["📖 Meubelboek", "Meubels", "Versiering met sterren", "Afrekenen",
			"Lijstje leeg", "Boek dicht", "is genoeg", "je hebt ",
			"Hoeveel euro heb je?", "Nog geen munten", "je munten op de toonbank",
			"je buidel: ", " munten",
			"Hoeveel euro is dat samen?", "Je gaf ", "Hoeveel krijg je terug?",
			"kost ", "kosten ", "Leg de 🪙 munten op de toonbank", "tik een getal",
			"de toonbank: ", "munt van ",
			"een munt terugpakken", "terug naar het meubelboek",
			"terug", "betaald", " neerzetten", "sleep naar een plekje",
			"hier neerzetten", "meer plekjes", "bezet", "gasten", "iemand slaapt",
			"bed draaien", " oppakken", " euro erbij", " kopen, ",
			" kopen voor ", " sterren",
			# de Rekenwacht
			"Je hebt %s. Is dat genoeg?", "Je hebt %s, het kost %s",
			"Hoeveel houd je over?", "Dit kost %d ⭐", "Genoeg", "Te weinig"]:
		waar(bron.contains(zin), 'de zin "%s" staat letterlijk in spel.gd' % zin)
	# de echte minus U+2212 (F3)
	waar(bron.contains("−"), "de wisselsom gebruikt het echte minteken U+2212")
	# en de hulpladder is weg (eigenaar 2026-09-24)
	for weg in ["zoveel is het samen", "zoveel krijg je terug", "dit moet er nog bij",
			"zoveel moet het zijn", "zo ziet het uit", "te veel", "hotspook"]:
		waar(not bron.contains('"%s"' % weg) and not bron.contains(weg + '"'),
			'geen hulp na een misser meer: "%s"' % weg)
	# geen enkele kinderzin heeft een teken dat het lettertype niet kent
	for zin in [Spel.T_TITEL, Spel.T_SAMEN, Spel.T_TERUG_VRAAG, Spel.T_LEG_MUNTEN,
			Spel.T_TIK_GETAL, Spel.T_SLEEP, Spel.T_HIER, Spel.T_MEER, Spel.T_BEZET,
			Spel.T_SLAAPT, Spel.T_DRAAIEN, Spel.T_EERST,
			Spel.T_HOEVEEL, Spel.T_GEEN_MUNTEN, Spel.T_OP_TAFEL, Spel.T_BUIDEL,
			Spel.T_GENOEG_VRAAG, Spel.T_OVER_ZIN, Spel.T_OVER_VRAAG, Spel.T_STER_PRIJS,
			Spel.W_GENOEG, Spel.W_TE_WEINIG, Spel.T_MUNT_LEG]:
		gelijk(str(Ui.mist_tekens(zin)), "[]", 'elk teken van "%s" zit in de subset' % zin)

## Elk teken dat dit spel op een knop, een kaart of een wolkje kan zetten moet
## in de gebundelde subset zitten (architecture.md §7.5).  Gemeten op een echte
## export: U+FF0B (de brede plus) en U+21A9 (de terugpijl) werden tofu-blokjes.
func test_elk_pictogram_zit_in_het_lettertype() -> void:
	var tekens := PackedStringArray()
	# elke kinderzin en elk woord naast een pictogram
	for zin in [Spel.T_TITEL, Spel.T_MEUBELS, Spel.T_VERSIERING, Spel.T_AFREKENEN,
			Spel.T_LIJST_LEEG, Spel.T_BOEK_DICHT, Spel.T_GENOEG, Spel.T_SAMEN,
			Spel.T_TERUG_VRAAG, Spel.T_LEG_MUNTEN, Spel.T_TIK_GETAL,
			Spel.T_MUNT_TERUG, Spel.T_TERUG_BOEK,
			Spel.T_TERUG, Spel.T_BETAALD, Spel.T_SLEEP, Spel.T_HIER, Spel.T_MEER,
			Spel.T_BEZET, Spel.T_GASTEN, Spel.T_SLAAPT, Spel.T_DRAAIEN,
			Spel.T_EERST, Spel.W_HIER, Spel.W_MEER, Spel.W_TERUG,
			Spel.W_BOEK, Spel.W_DRAAIEN, Spel.W_OPPAKKEN,
			Spel.T_HOEVEEL, Spel.T_GEEN_MUNTEN, Spel.T_OP_TAFEL, Spel.T_BUIDEL,
			Spel.T_GENOEG_VRAAG, Spel.T_OVER_ZIN, Spel.T_OVER_VRAAG, Spel.T_STER_PRIJS,
			Spel.W_GENOEG, Spel.W_TE_WEINIG, Spel.T_MUNT_LEG]:
		tekens.append(zin)
	# elk pictogram dat het spel zelf op een knop of in een wolkje zet
	for icoon in ["📖", "🪑", "⭐", "💰", "🛏", "🛒", "💛", "+", "«", "✖",
			"▸", "✨", "📦", "🔄", "☝", "🧾", "🪙", "💶", "👛", "🐾", "✅", "«",
			"🚫", "💤", "🧺", "✓", "×", "€", "−", "…", "🎉", "🌸", "🩷", "🎈"]:
		tekens.append(icoon)
	for w in Sommen.Meubels.WINKEL:
		tekens.append(str(w["icoon"]))
		tekens.append(str(w["naam"]))
		tekens.append(str(w.get("plus", "")))
	for v in Sommen.Meubels.VERSIERING:
		tekens.append(str(v["icoon"]))
		tekens.append(str(v["naam"]))
	var gemist := 0
	for zin in tekens:
		var mist := Ui.mist_tekens(zin)
		if not mist.is_empty():
			gemist += 1
			fout('"%s" mist %s in de subset' % [zin, str(mist)])
	gelijk(gemist, 0, "%d van de %d teksten mist een teken" % [gemist, tekens.size()])
	# en geen enkel pictogram uit de bron staat nog in de FULLWIDTH-vorm
	var bron := FileAccess.get_file_as_string("res://games/meubels/spel.gd")
	for verboden in [0xFF0B, 0x21A9]:
		waar(not bron.contains(char(verboden)),
			"U+%04X staat niet meer in de bron: het lettertype kent hem niet" % verboden)

## F4: elke zin op elke kaart, voor elke combinatie die het spel kan maken —
## ook de vragen van de Rekenwacht (genoeg?, houd je over?, met munten en met
## sterren), tot een buidel van honderd.
func test_elke_kaartzin_past_in_het_budget() -> void:
	var namen: Array[String] = []
	for w in Sommen.Meubels.WINKEL:
		namen.append(str(w["type"]))
	for w in Spel.VERSIERING_KAMER:
		namen.append(str(w["type"]))
	var gekeurd := 0
	for a in namen:
		_keur_zin(Spel._prijs_zin([a], Spel._totaal_van([a])), "prijszin %s" % a)
		gekeurd += 1
		for b in namen:
			var paar: Array = [a, b]
			var tot: int = Spel._totaal_van(paar)
			_keur_zin(Spel._som_zin(paar), "somzin %s+%s" % [a, b])
			_keur_zin(Spel._prijs_zin(paar, tot), "prijszin %s+%s" % [a, b])
			gekeurd += 2
	# de wisselzin, met het grootste bedrag dat de buidel kan maken
	for betaald in range(1, 21):
		for prijs in [1, 2, 3, 4, 5, 8]:
			_keur_zin("Je gaf €%d, het kost €%d" % [betaald, prijs], "wisselzin")
			gekeurd += 1
	# genoeg? en houd je over?, met munten en met sterren
	for heb in [0, 9, 20, 99, 100, 250]:
		for prijs in [1, 8, 16]:
			_keur_zin(Spel.T_GENOEG_VRAAG % ("€%d" % heb), "genoegzin")
			_keur_zin(Spel.T_GENOEG_VRAAG % ("%d⭐" % heb), "genoegzin ster")
			_keur_zin("💰 " + Spel.T_OVER_ZIN % ["€%d" % heb, "€%d" % prijs], "overzin")
			_keur_zin("⭐ " + Spel.T_OVER_ZIN % ["%d⭐" % heb, "%d⭐" % prijs], "overzin ster")
			gekeurd += 4
	for v in Sommen.Meubels.VERSIERING:
		_keur_zin("%s %s" % [str(v["icoon"]), Spel.T_STER_PRIJS % int(v["ster"])], "sterprijs")
		gekeurd += 1
	for zin in [Spel.T_SAMEN, Spel.T_TERUG_VRAAG, Spel.T_LEG_MUNTEN, Spel.T_OVER_VRAAG]:
		_keur_zin(zin, "vaste regel")
		gekeurd += 1
	waar(gekeurd > 100, "er zijn %d zinnen gekeurd" % gekeurd)



func _keur_zin(zin: String, wat: String) -> void:
	var woorden := zin.split(" ", false).size()
	waar(woorden <= 8 and zin.length() <= 40,
		"%s: \"%s\" = %d woorden, %d tekens (max 8 / 40)" % [wat, zin, woorden, zin.length()])

## Er is geen hulpladder meer (eigenaar 2026-09-24): geen doortel-hulp, geen
## telladder langs de munten, geen spookmunten.
func test_er_is_geen_hulpladder_meer() -> void:
	var namen: Array[String] = []
	for m in (Spel as Script).get_script_method_list():
		namen.append(str(m["name"]))
	waar(namen.has("_kas_ok"), "de methodelijst is te lezen")
	for weg in ["_door_tellen", "_tel_munten", "_spook_zet", "_spook_weg"]:
		waar(not namen.has(weg), "%s bestaat niet meer" % weg)
	var k: Dictionary = (Spel as Script).get_script_constant_map()
	for weg in ["T_SPOOK_SAMEN", "T_SPOOK_WISSEL", "T_SPOOK_BIJ", "T_SPOOK_MOET",
			"T_SPOOK_UIT", "T_SPOOK_ZOVEEL"]:
		waar(not k.has(weg), "%s bestaat niet meer" % weg)

## De catalogus komt uit `Sommen.Meubels`, niet uit dit spel (F1).
func test_de_catalogus_komt_uit_de_rekenkern() -> void:
	gelijk(Sommen.Meubels.WINKEL.size(), 6, "zes meubels")
	gelijk(Sommen.Meubels.VERSIERING.size(), 5, "vijf versieringen")
	var prijzen := {"plant": 1, "bakje": 2, "mandje": 3, "speelmand": 4,
		"bed": 5, "badkuip": 8}
	for type in prijzen:
		gelijk(Sommen.Meubels.prijs_van(type), prijzen[type], "prijs van %s" % type)
	# de bandregels
	gelijk(Sommen.Meubels.max_lijst(3), 1, "groep 3: één ding")
	gelijk(Sommen.Meubels.max_lijst(4), 2, "groep 4: twee dingen")
	gelijk(Sommen.Meubels.max_lijst(5), 2, "groep 5: twee dingen")
	gelijk(Sommen.Meubels.buidel_max(3), 10, "buidelplafond groep 3")
	gelijk(Sommen.Meubels.buidel_max(4), 20, "buidelplafond groep 4")
	gelijk(Sommen.Meubels.buidel_cap(3, 25, 4), 20, "cap = max(totaal, min(munten, max))")
	gelijk(Sommen.Meubels.buidel_cap(8, 5, 3), 8, "en nooit minder dan de prijs")

# ==================================================================================
# 7. de knoppen dekken hun voorwerp niet, in vier kaders
# ==================================================================================

## De hele schil in een SubViewport, zoals tests/test_hits.gd het doet: de
## camera centreert een kamer alleen als er een viewport geregistreerd is, dus
## hotspots tegen een camera in de oorsprong bewijzen niets.
func _hotel_op(maat: Vector2i) -> Dictionary:
	var boom := Engine.get_main_loop() as SceneTree
	var vp := SubViewport.new()
	vp.size = maat
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	boom.root.add_child(vp)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var shell := scene.instantiate()
	shell.set_meta("geen_start", true)
	vp.add_child(shell)
	for _f in 4:
		await boom.process_frame
	# GEEN `State.start_gekozen()`: dat schrijft `user://dierenhotel.json`, en
	# deze suite hoeft de opslag op schijf niet aan te raken.  `State.bewaar()`
	# is dan een no-op en tests die WEL over dat bestand gaan
	# (tests/test_ui.gd) houden hun eigen bestand.
	State.nieuw_spel()
	State.s["munten"] = 12
	State.s["sterren"] = 6
	State.s["kunnen"] = 5
	State.s["gasten"] = _gasten(5)
	State.herbereken()
	Hotel.start()
	for _f in 4:
		await boom.process_frame
	var kader: Control = shell.get_node("Scherm/Kolom/Middenrij/Kaderdoos/Kader")
	return {"vp": vp, "shell": shell, "kader": kader.size}

func _hotel_af(h: Dictionary) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	if Games.actief() != "":
		Games.stop()
	Ui.blad_dicht()
	Ui.naamplaten_leeg()
	Hits.wis_alles()
	World.decor_wis_alles()
	Rooms.herstel()
	(h["vp"] as SubViewport).queue_free()
	await boom.process_frame
	Ui.registreer_lagen(null, null, null)
	_scherm_los()

## Het boek is het enige paneel dat HOTEL.md §9 toestaat, en een knop erin moet
## te halen zijn zonder te rollen.  Gemeten op 360 x 740 stond `✖ Boek dicht`
## op y 762 — 22 eenheden onder de onderrand — zodra er iets op het lijstje
## lag; §5.5 zegt dat die knop er altijd is.  (Sinds de Rekenwacht rekent een
## vol lijstje meteen af, dus het langste blad heeft één ding op het lijstje.)
func test_boek_past_op_elk_scherm() -> void:
	var bewaard := State.s.duplicate(true)
	var boom := Engine.get_main_loop() as SceneTree
	for maat in SCHERMEN:
		var h: Dictionary = await _hotel_op(maat)
		waar(Games.start("meubels"), "%s: het spel start" % str(maat))
		for _f in 3:
			await boom.process_frame
		await _kassa_door()
		# één ding op het lijstje: dan staat de lijstrij erbij en is het blad op
		# zijn langst
		_blad_tik("Kk_plant")
		for _f in 3:
			await boom.process_frame
		var scherm := Vector2(maat)
		_keur_blad_past(maat, scherm, ["Kk_plant", "Kk_badkuip", "Kafrekenen", "Kleeg", "Kdicht"])
		# de tab 🩷 Decoratie (U7): alle negen stukken, met hetzelfde lijstje
		# erop, staan op hetzelfde scherm net zo goed in beeld
		waar(_blad_tik("Ktab_decoratie"), "%s: naar de decoratiepagina" % str(maat))
		for _f in 3:
			await boom.process_frame
		var namen: Array = ["Kafrekenen", "Kleeg", "Kdicht"]
		for w in Spel.VERSIERING_KAMER:
			namen.append("Kk_%s" % str(w["type"]))
		gelijk(Spel.VERSIERING_KAMER.size(), 9, "negen decoratiestukken in het boek")
		_keur_blad_past(maat, scherm, namen)
		waar(_blad_knop("Kk_plant") == null, "%s: geen meubel op de decoratiepagina" % str(maat))
		await _hotel_af(h)
	State.s = bewaard

func test_knoppen_dekken_hun_voorwerp_niet() -> void:
	var bewaard := State.s.duplicate(true)
	var boom := Engine.get_main_loop() as SceneTree
	for maat in SCHERMEN:
		var h: Dictionary = await _hotel_op(maat)
		var kader: Vector2 = h["kader"]
		waar(Games.start("meubels"), "%s: het spel start" % str(maat))
		for _f in 3:
			await boom.process_frame
		# eerst de kassastap: de kaart, de munten en de buidel staan er samen
		_keur_dekking("%s kassastap" % str(maat), kader)
		await _kassa_door()
		# door naar de wereld: twee dingen = meteen afrekenen, de som
		_blad_tik("Kk_plant")
		for _f in 2:
			await boom.process_frame
		_blad_tik("Kk_mandje")
		for _f in 3:
			await boom.process_frame
		_keur_dekking("%s betaalstap" % str(maat), kader)
		# genoeg?, en dan de bon met de muntstrook: de drukste stap
		_typ("mb_som", 4)
		waar(await _wacht_op("mb_genoeg_keuzes"), "%s: genoeg?" % str(maat))
		for _f in 2:
			await boom.process_frame
		_keur_dekking("%s genoegstap" % str(maat), kader)
		_kies("mb_genoeg", "ja")
		waar(await _wacht_op("mb_bon_keuzes"), "%s: de bon" % str(maat))
		_leg(1)
		for _f in 3:
			await boom.process_frame
		waar(_er_is("mb_terug"), "%s: « staat er" % str(maat))
		_keur_dekking("%s muntstap" % str(maat), kader)
		# en de plaatsstap, met de doos en de vakjes.  Die wordt hier via het
		# laatje bereikt in plaats van door een hele afrekening te spelen: dat
		# is precies de herstelweg van §5.7 ("al betaald, nog niet neergezet")
		# en het scheelt vier keer twee seconden wachten in de suite.
		Games.stop()
		State.spel_data("meubels")["wacht"] = {"nog": ["plant", "bed"]}
		waar(Games.start("meubels"), "%s: opnieuw gestart op de plaatsstap" % str(maat))
		for _f in 3:
			await boom.process_frame
		waar(_er_is("mb_doos"), "%s: de doos staat er" % str(maat))
		_keur_dekking("%s plaatsstap" % str(maat), kader)
		await _hotel_af(h)
	State.s = bewaard

## Elke knop van het open blad in beeld (vanaf 400 eenheden hoogte; daaronder
## rolt het vel en moet het vel zelf in beeld staan), elke knop een tikdoel, en
## `namen` staan er allemaal.
func _keur_blad_past(maat: Vector2i, scherm: Vector2, namen: Array) -> void:
	# Onder de 400 eenheden hoogte past een catalogus van zes kaartjes
	# nergens meer: dan rolt het blad, en dat is precies waar `UiBlad` zijn
	# ScrollContainer voor heeft.  Daarboven moet alles gewoon in beeld staan.
	var moet_passen := scherm.y >= 400.0
	var gekeurd := 0
	for knop in _blad_knoppen():
		gekeurd += 1
		var r := knop.get_global_rect()
		if moet_passen:
			waar(r.position.y >= -0.01 and r.end.y <= scherm.y + 0.01
				and r.position.x >= -0.01 and r.end.x <= scherm.x + 0.01,
				"%s: bladknop %s staat in beeld (%s van %s)"
					% [str(maat), knop.name, str(r), str(scherm)])
		waar(r.size.x >= 44.0 and r.size.y >= 44.0,
			"%s: bladknop %s is een tikdoel (%s)" % [str(maat), knop.name, str(r.size)])
	if not moet_passen:
		# dan moet het vel zelf wel in beeld staan en te rollen zijn
		var vel := _blad_vel()
		waar(vel != null, "%s: het vel staat er" % str(maat))
		if vel != null:
			waar(Rect2(Vector2.ZERO, scherm).encloses(vel.get_global_rect()),
				"%s: het vel staat in beeld (%s)" % [str(maat), str(vel.get_global_rect())])
		waar(_blad_rol() != null, "%s: en het blad rolt" % str(maat))
	for naam in namen:
		waar(_blad_knop(naam) != null, "%s: %s staat in het boek" % [str(maat), naam])
	waar(gekeurd >= 9, "%s: %d knoppen in het boek gekeurd" % [str(maat), gekeurd])

func _blad_vel() -> Control:
	return _blad_deel("Midden/Blad")

func _blad_rol() -> ScrollContainer:
	return _blad_deel("Midden/Blad/Rol") as ScrollContainer

func _blad_deel(pad: String) -> Control:
	if Ui.bladlaag == null:
		return null
	var kinderen := Ui.bladlaag.get_children()
	kinderen.reverse()
	for blad in kinderen:
		if blad is Control and not blad.is_queued_for_deletion():
			return blad.get_node_or_null(pad) as Control
	return null

## Elke knop in het open blad.
func _blad_knoppen() -> Array[Button]:
	var uit: Array[Button] = []
	if Ui.bladlaag == null:
		return uit
	var kinderen := Ui.bladlaag.get_children()
	kinderen.reverse()
	for blad in kinderen:
		if blad is Control and not blad.is_queued_for_deletion():
			_verzamel_knoppen(blad, uit)
			return uit
	return uit

func _verzamel_knoppen(k: Node, uit: Array[Button]) -> void:
	if k is Button:
		uit.append(k as Button)
	for kind in k.get_children():
		_verzamel_knoppen(kind, uit)


## Elke knop van dit spel staat op 0 % van zijn voorwerp, binnen het kader, en
## is een echt tikdoel.
func _keur_dekking(wat: String, kader: Vector2) -> void:
	var dbg := Hits.debug()
	var gekeurd := 0
	var tap := float(Ui.tap_maat())
	for id in dbg.keys():
		var s := Hits.spot(id)
		if s == null or s.door != "meubels":
			continue
		gekeurd += 1
		var d: Dictionary = dbg[id]
		var r: Rect2 = d["rect"]
		gelijk(Hits.dekking(id), 0.0, "%s: %s dekt zijn voorwerp niet (knop %s, voorwerp %s)"
			% [wat, id, str(r), str(d["vlak"])])
		waar(not bool(d["krap"]), "%s: %s vond een echte plek" % [wat, id])
		waar(r.position.x >= -0.01 and r.position.y >= -0.01
			and r.end.x <= kader.x + 0.01 and r.end.y <= kader.y + 0.01,
			"%s: %s blijft in het kader %s (%s)" % [wat, id, str(kader), str(r)])
		if int(d["laag"]) != Hits.Laag.VAST and s.kind != "wolk" and s.kind != "tag":
			waar(r.size.x >= tap - 0.01 and r.size.y >= tap - 0.01,
				"%s: %s is een tikdoel van %d px (%s)" % [wat, id, tap, str(r.size)])
		# en geen enkele knop van dit spel staat op een andere geplaatste knop
		for ander in dbg.keys():
			if ander == id:
				continue
			var snij: Rect2 = r.intersection(dbg[ander]["rect"])
			gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
				"%s: %s en %s overlappen" % [wat, id, ander])
	# Twee op het laagste kader (doos + één vakje, zie `_vak_max`), drie of meer
	# overal daarboven.
	waar(gekeurd >= (2 if kader.y < 340.0 else 3),
		"%s: er zijn %d knoppen van het spel gekeurd" % [wat, gekeurd])

# ==================================================================================
# 8. koopbare kamerdecoratie (eigenaar 2026-10-07, U7)
# ==================================================================================

## Elk decoratiestuk heeft een pictogram dat rendert, een prijs binnen het bereik
## van de bevroren winkel (1..8), een plek in `Rooms.DECORATIE` met een plekssoort
## (vloer of wand) en een beschermd wereldmodel (`ArtDecor._extra()`) dat zonder
## enginefout bakt.  De zes meubels uit de kern staan onaangeroerd vooraan.
func test_kamerdecoratie_catalogus() -> void:
	gelijk(Sommen.Meubels.WINKEL.size(), 6, "de kern verkoopt nog steeds zes meubels")
	gelijk(World.meubeltypen().size(), 6, "en de wereld kent nog steeds zes meubeltypen")
	var extra: Array = Spel.VERSIERING_KAMER
	gelijk(extra.size(), 9, "negen decoratiestukken")
	var gezien := {}
	var soorten := {}
	for w in extra:
		var type := str(w["type"])
		waar(not gezien.has(type), "%s komt één keer voor" % type)
		gezien[type] = true
		gelijk(Sommen.Meubels.prijs_van(type), 0, "%s botst niet met de kern" % type)
		var prijs := int(w["prijs"])
		waar(prijs >= 1 and prijs <= 8, "%s kost 1..8 euro (%d)" % [type, prijs])
		var icoon := str(w["icoon"])
		waar(Ui.mist_tekens(icoon).is_empty(), "%s: pictogram %s rendert (mist %s)"
			% [type, icoon, str(Ui.mist_tekens(icoon))])
		waar(Rooms.DECORATIE.has(type) and not Rooms.MEUBEL.has(type),
			"%s staat in Rooms.DECORATIE, niet tussen de zes meubels" % type)
		waar(Rooms.koopbaar(type), "Rooms.meubel_zet neemt %s aan" % type)
		if Rooms.DECORATIE.has(type):
			gelijk(str(Rooms.DECORATIE[type]["soort"]), "decor", "%s is decor" % type)
			var model := str(Rooms.DECORATIE[type]["model"])
			waar(ArtDecorVersiering.NAMEN.has(model), "%s heeft een model in decor_versiering.gd" % type)
			waar(Art.is_wereldmodel(model), "%s is een beschermd wereldmodel" % model)
			var plek := Rooms.plek_soort(type)
			waar(plek in ["vloer", "wand"], "%s: plekssoort %s" % [type, plek])
			soorten[plek] = true
		var naam := str(w["naam"])
		waar(naam.split(" ").size() <= 2, "%s: naam van hooguit twee woorden" % type)
		gelijk(int(Spel._artikel(type).get("prijs", -1)), prijs, "_artikel kent %s" % type)
	waar(soorten.has("vloer") and soorten.has("wand"), "er is iets voor de vloer en voor de muur")
	# de enige nieuwe zin is de titel van de tab; hij volgt HOTEL.md §9
	for zin in [Spel.T_DECORATIE, "🩷 Decoratie"]:
		gelijk(str(Ui.mist_tekens(zin)), "[]", 'elk teken van "%s" rendert' % zin)
		waar(zin.split(" ").size() <= 8 and zin.length() <= 40,
			'"%s": hooguit 8 woorden en 40 tekens' % zin)
	gelijk(Rooms.plek_soort("schilderij"), "wand", "het schilderij hangt aan de muur")
	gelijk(Rooms.plek_soort("plant"), "vloer", "de plant van de kern staat op de vloer")
	waar(ArtDecor.alle_namen().has("versier_aquarium"), "ArtDecor kent de decoratie")
	for naam in ArtDecorVersiering.NAMEN:
		waar(Art.heeft_model(naam), "%s is aangemeld" % naam)
		waar(not Art.model(naam).is_empty(), "%s heeft voxels" % naam)
		waar(Art.plaat(naam, 2) != null, "%s bakt" % naam)
		waar(World.plaat(naam, 2, {}, 1) != null, "%s bakt een kwartslag gedraaid" % naam)

## Koop → save → herlaad: een vloerstuk en een wandstuk staan terug in dezelfde
## kamer op dezelfde plek, en de oude meubels eromheen ook (geen nieuw
## save-veld: een decoratiestuk is een meubel-regel).
func test_kamerdecoratie_overleeft_een_herlaad() -> void:
	await _op(Vector2(1000, 648), 3, 12)
	var plant := Rooms.meubel_zet("kamer1", "plant")
	waar(not plant.is_empty(), "een oude plant staat in kamer 1")
	var bankje := Rooms.meubel_zet("kamer1", "bankje", 30.0, 30.0)
	waar(not bankje.is_empty(), "het bankje staat in kamer 1")
	var schilderij := Rooms.meubel_zet("kamer2", "schilderij")
	waar(not schilderij.is_empty(), "het schilderij hangt in kamer 2")
	var lamp := Rooms.meubel_zet("speelzaal", "lamp")
	waar(not lamp.is_empty(), "de lamp staat in de speelzaal")
	Hotel.bewaar_inrichting()
	var tekst := JSON.stringify(State.s)
	Rooms.herstel()
	gelijk(Rooms.meubels("kamer1").size(), 0, "na herstel is kamer 1 leeg")
	State.s = JSON.parse_string(tekst)
	Hotel.herstel_inrichting()
	for oud in [bankje, schilderij, lamp]:
		var terug: Array = Rooms.meubels(str(oud["kamer"])).filter(
			func(m): return str(m["id"]) == str(oud["id"]))
		gelijk(terug.size(), 1, "%s is terug in %s" % [oud["type"], oud["kamer"]])
		if terug.size() == 1:
			gelijk(Vector2(float(terug[0]["x"]), float(terug[0]["z"])),
				Vector2(float(oud["x"]), float(oud["z"])), "%s op dezelfde plek" % oud["type"])
			gelijk(str(terug[0]["type"]), str(oud["type"]), "en hetzelfde stuk")
	gelijk(Rooms.meubels("kamer1").filter(func(m): return str(m["type"]) == "plant").size(), 1,
		"de oude plant is er ook nog")
	var hangt: Array = Rooms.get_kamer("kamer2").decor.filter(
		func(d): return str(d.get("meubel", "")) == str(schilderij["id"]))
	gelijk(hangt.size(), 1, "het schilderij is decor van kamer 2")
	if hangt.size() == 1:
		waar(bool(hangt[0].get("ver", false)), "het hangt in de laag achter alles (ver)")
		gelijk(float(hangt[0].get("y", 0.0)), float(Rooms.WAND_Y), "op wandhoogte")
	waar(Rooms.gebruikte_modellen().has("versier_bankje"), "de kamer vraagt het bankmodel")
	waar(Rooms.gebruikte_modellen().has("versier_schilderij"), "en het schilderijmodel")
	_af()

## In het boek staan de decoratiestukken op hun eigen tab, met dezelfde knop en
## dezelfde zin als een meubel; alle negen staan in beeld op 1000×648.
func test_kamerdecoratie_staat_achterin_het_boek() -> void:
	await _op(Vector2(1000, 648), 3, 12)
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	# het meubelblad is wat het was: zes kaartjes, geen decoratie
	waar(_blad_knop("Kk_plant") != null, "de plant staat op het meubelblad")
	waar(_blad_knop("Kk_bankje") == null, "het bankje staat NIET op het meubelblad")
	waar(_blad_knop("Ktab_decoratie") != null, "er is een derde tab 🩷 Decoratie")
	waar(_blad_tik("Ktab_decoratie"), "naar de decoratiepagina")
	await _tel_frames()
	var bankje := _blad_knop("Kk_bankje")
	waar(bankje != null, "het bankje heeft een knop op de decoratiepagina")
	if bankje != null:
		waar(bankje.tooltip_text.begins_with("bankje"), "met de bestaande zin (%s)" % bankje.tooltip_text)
	waar(_blad_knop("Kk_plant") == null, "de plant staat niet op de decoratiepagina")
	for w in Spel.VERSIERING_KAMER:
		var k := _blad_knop("Kk_%s" % str(w["type"]))
		waar(k != null, "%s heeft een knop" % str(w["type"]))
		if k != null:
			var r := k.get_global_rect()
			waar(r.end.x <= 1000.0 + 0.01 and r.end.y <= 648.0 + 0.01,
				"%s staat in beeld op 1000×648 (%s)" % [str(w["type"]), str(r)])
	_af()

## Door het spel, in kamer 1, kamer 2, de gang en de speelzaal: de ✨-vakjes van
## een lamp zijn vrije vloervakken, die van een schilderij wandplekken op de
## hoogte waar het komt te hangen; één tik zet elk op zijn soort plek.  In de
## gang (geen vrije muur) toont de doos geen vakje maar `🚫 bezet`, en het
## schilderij blijft in de doos — niets wordt ergens anders neergezet.
func test_kamerdecoratie_vakjes_per_soort() -> void:
	for kamer in ["kamer1", "kamer2", "gang", "speelzaal"]:
		await _op(Vector2(1000, 648), 3, 12)
		State.spel_data("meubels")["wacht"] = {"nog": ["lamp", "schilderij"]}
		waar(Games.start("meubels"), "%s: het spel start op de plaatsstap" % kamer)
		await _tel_frames(3)
		World.naar(kamer)
		await _tel_frames(3)
		gelijk(World.kamer_nu(), kamer, "de doos is mee naar %s" % kamer)
		# de lamp: vloervakken
		var vakken := _vakken()
		waar(not vakken.is_empty(), "%s: de lamp heeft vakjes" % kamer)
		for id in vakken:
			var s := Hits.spot(id)
			waar(Rooms.vrij_vak(kamer, s.x, s.z) and s.y == 0.0,
				"%s: %s is een vrij vloervak (%s, %s)" % [kamer, id, s.x, s.z])
		if not vakken.is_empty():
			waar(_tik(_eerste_vak()), "%s: de lamp neerzetten" % kamer)
		await _tel_frames(2)
		var lampen: Array = Rooms.meubels(kamer).filter(func(m): return str(m["type"]) == "lamp")
		gelijk(lampen.size(), 1, "%s: de lamp staat" % kamer)
		gelijk(str(_spel().call("_nog")), '["schilderij"]', "%s: het schilderij is aan de beurt" % kamer)
		# het schilderij: wandplekken, of niets als de muur vol is
		vakken = _vakken()
		if Rooms.vrije_wandplekken(kamer).is_empty():
			gelijk(vakken.size(), 0, "%s: geen vakje voor een schilderij" % kamer)
			waar(_er_is("mb_bezet"), "%s: de doos zegt 🚫 bezet" % kamer)
			gelijk(_wolk_deel("mb_bezet", "tekst"), Spel.T_BEZET, "%s: met het bestaande woord" % kamer)
		else:
			waar(not vakken.is_empty(), "%s: het schilderij heeft vakjes" % kamer)
			var muur := Rooms.vrije_wandplekken(kamer)
			for id in vakken:
				var s := Hits.spot(id)
				var op := false
				for p in muur:
					if float(p["x"]) == s.x and float(p["z"]) == s.z:
						op = true
				waar(op, "%s: %s ligt op een wandplek (%s, %s)" % [kamer, id, s.x, s.z])
				gelijk(s.y, float(Rooms.WAND_Y) + Rooms.WAND_HOOG / 2.0, "%s: %s op schilderijhoogte" % [kamer, id])
			if not vakken.is_empty():
				waar(_tik(_eerste_vak()), "%s: het schilderij ophangen" % kamer)
			await _tel_frames(2)
			var hangt: Array = Rooms.get_kamer(kamer).decor.filter(
				func(d): return str(d.get("type", "")) == "schilderij" and d.has("meubel"))
			gelijk(hangt.size(), 1, "%s: het schilderij hangt" % kamer)
			if hangt.size() == 1:
				waar(bool(hangt[0].get("ver", false)), "%s: aan de muur" % kamer)
			gelijk(str(_spel().call("_nog")), "[]", "%s: de doos is leeg" % kamer)
		_af()

## Een kamer kiezen = erheen lopen (games-a.md §5.7).  Zolang een spel loopt
## haalt `Hits` de hotelknoppen weg, dus de plaatsstap leent de deurbordjes van
## de kamer waar je bent: één tik op `Gang` en dan op `Kamer 2`, en de doos met
## de lamp staat in kamer 2 met de vakjes van kamer 2.  Na het neerzetten gaan
## de bordjes terug naar het hotel.
func test_kamerdecoratie_de_doos_loopt_mee_door_de_deur() -> void:
	await _op(Vector2(1000, 648), 3, 12)
	State.spel_data("meubels")["wacht"] = {"nog": ["lamp"]}
	waar(Games.start("meubels"), "het spel start op de plaatsstap")
	await _tel_frames(3)
	gelijk(World.kamer_nu(), "kamer1", "de doos begint in kamer 1")
	var deur = Hits.spot("deur_kamer1_gang")
	waar(deur != null and str(deur.geleend_door) == "meubels", "het deurbordje naar de gang is geleend")
	waar(_tik("deur_kamer1_gang"), "tik op het deurbordje")
	await _wacht(0.6)
	await _tel_frames(3)
	gelijk(World.kamer_nu(), "gang", "de camera en de doos zijn in de gang")
	var verder = Hits.spot("deur_gang_kamer2")
	waar(verder != null and str(verder.geleend_door) == "meubels", "ook in de gang zijn de bordjes geleend")
	waar(_tik("deur_gang_kamer2"), "tik op het bordje naar kamer 2")
	await _wacht(0.6)
	await _tel_frames(3)
	gelijk(World.kamer_nu(), "kamer2", "nu in kamer 2")
	var vakken := _vakken()
	waar(not vakken.is_empty(), "kamer 2 heeft vakjes voor de lamp")
	for id in vakken:
		waar(id.begins_with("mbvak_kamer2_"), "%s hoort bij kamer 2" % id)
	if not vakken.is_empty():
		waar(_tik(_eerste_vak()), "de lamp neerzetten")
	await _tel_frames(3)
	gelijk(Rooms.meubels("kamer2").filter(func(m): return str(m["type"]) == "lamp").size(), 1,
		"de lamp staat in kamer 2")
	gelijk(Rooms.meubels("kamer1").filter(func(m): return str(m["type"]) == "lamp").size(), 0,
		"en niet in kamer 1")
	await _tel_frames(2)
	var terug = Hits.spot("deur_kamer2_gang")
	waar(terug == null or str(terug.geleend_door).is_empty(), "na het neerzetten is het bordje weer van het hotel")
	_af()


# ==================================================================================
# 9. de Rekenwacht (golf 2): R1 — rekenen is minstens de helft van een beurt
# ==================================================================================

## Groep 3, een kleine en een grote N: één meubel, decoratie (via de tab), een
## derde ding, en een sticker met sterren — vier beurten na elkaar, elk van de
## start tot het spel vanzelf dichtgaat, en elk met reken >= spel + 1.
func test_rekenaandeel_band_3() -> void:
	for n in [3, 8]:
		await _op(Vector2(1000, 648), n, 20, 5 if n == 3 else 2)
		gelijk(State.band(), 3, "N=%d: band 3" % n)
		await _r1_beurt(["mandje"], "meubels", "groep 3 N=%d, 1 ding" % n)
		await _r1_beurt(["lamp"], "decoratie", "groep 3 N=%d, decoratie" % n)
		if n == 3:
			await _r1_beurt(["plant"], "meubels", "groep 3 N=%d, 3e ding" % n)
			await _r1_sticker("vlag", "groep 3 N=%d, sticker" % n)
		_af()

## Groep 4: twee dingen (het tweede rekent meteen af), één ding (met 🛒
## Afrekenen), decoratie één en twee (via de tab) — de zwaarste beurt voor R1
## is één decoratiestuk: tab, +, afrekenen, neerzetten = 4 speltikken tegen
## kassa, genoeg, munt, wisselgeld en over = 5 rekentikken.
func test_rekenaandeel_band_4() -> void:
	for n in [5, 8]:
		await _op(Vector2(1000, 648), n, 40, 5 if n == 5 else 3)
		gelijk(State.band(), 4, "N=%d: band 4" % n)
		await _r1_beurt(["plant", "mandje"], "meubels", "groep 4 N=%d, 2 dingen" % n)
		await _r1_beurt(["kussen"], "decoratie", "groep 4 N=%d, 1 decoratie" % n)
		if n == 5:
			await _r1_beurt(["speelmand"], "meubels", "groep 4 N=%d, 3e ding" % n)
			await _r1_beurt(["bloemen", "slinger"], "decoratie", "groep 4 N=%d, 2 decoratie" % n)
		_af()

## Groep 5: een bed (N klein: er is een bedplek vrij) en een badkuip samen,
## een speelkist, een schilderij aan de muur.
func test_rekenaandeel_band_5() -> void:
	for n in [7, 8]:
		await _op(Vector2(1000, 648), n, 60, 5)
		gelijk(State.band(), 5, "N=%d: band 5" % n)
		if n == 7:
			await _r1_beurt(["bed", "badkuip"], "meubels", "groep 5 N=%d, 2 dingen" % n)
			await _r1_beurt(["schilderij"], "decoratie", "groep 5 N=%d, schilderij" % n)
		await _r1_beurt(["kist"], "decoratie", "groep 5 N=%d, 1 decoratie" % n)
		await _r1_beurt(["bakje"], "meubels", "groep 5 N=%d, 1 meubel" % n)
		_af()

## Zonder munten: het boek opent op de sterren, en een sticker is één speltik
## tegen twee rekentikken.
func test_rekenaandeel_zonder_munten() -> void:
	await _op(Vector2(1000, 648), 3, 0)
	State.s["sterren"] = 4
	await _r1_sticker("bloem", "zonder munten, sticker")
	_af()

# ==================================================================================
# 10. de Rekenwacht: R2 — geen beloning zonder een goed antwoord, en een open
#     vraag met een misser komt onveranderd terug
# ==================================================================================

## R2-gat 1 (spel.gd:1023 vóór de fix): één ding kopen sloeg de som over — de
## bon stond meteen klaar met de prijs al ingevuld, in groep 3 elke keer.  Nu
## is de eerste kaart na het kiezen een rekenvraag, in elke band.
func test_r2_een_ding_kopen_vraagt_rekenen() -> void:
	for geval in [[3, 9, 3], [5, 12, 4], [7, 20, 5]]:
		await _op(Vector2(1000, 648), geval[0], geval[1])
		gelijk(State.band(), geval[2], "de band is %d" % geval[2])
		waar(Games.start("meubels"), "het spel start")
		await _tel_frames()
		await _kassa_door()
		if geval[2] >= 4:
			waar(_blad_tik("Kk_plant"), "groep %d: plant erbij" % geval[2])
			await _tel_frames()
			waar(_blad_tik("Kafrekenen"), "en afrekenen")
		else:
			waar(_blad_tik("Kk_plant"), "groep 3: koop de plant")
		await _tel_frames()
		waar(not _er_is("mb_bon"), "groep %d: geen bon zonder vraag" % geval[2])
		waar(_er_is("mb_genoeg_keuzes"), "groep %d: eerst een rekenvraag" % geval[2])
		var munten := int(State.s["munten"])
		waar(_kies("mb_genoeg", "ja"), "genoeg")
		waar(await _wacht_op("mb_bon_keuzes"), "de muntstrook")
		_leg_precies(1)
		var over_id := "mb_over_keuzes" if geval[2] == 3 else "mb_wissel_keuzes"
		waar(await _wacht_op(over_id), "groep %d: nog een vraag na het leggen" % geval[2])
		gelijk(int(State.s["munten"]), munten, "groep %d: nog niets betaald" % geval[2])
		gelijk(str(_spel().call("_nog")), "[]", "groep %d: nog niets in de doos" % geval[2])
		_af()

## R2-gat 2 (spel.gd:841-865 vóór de fix): de sterrenpagina verkocht stickers
## zonder één som.  Nu gaat er geen ster af en komt er geen sticker zonder twee
## goede antwoorden — ook niet met nul munten, waar het boek meteen opent.
func test_r2_versiering_alleen_na_rekenen() -> void:
	await _op(Vector2(1000, 648), 3, 0)
	State.s["sterren"] = 3
	waar(Games.start("meubels"), "het spel start zonder munten")
	await _tel_frames()
	waar(Ui.blad_open_nu(), "het boek staat open")
	waar(_blad_tik("Kv_vlag"), "tik de vlaggetjes aan")
	await _tel_frames()
	gelijk(int(State.s["sterren"]), 3, "er gaat nog geen ster af")
	gelijk(int((State.spel_data("meubels")["versiering"] as Dictionary).get("vlag", 0)), 0,
		"en er is nog geen sticker")
	waar(_er_is("mb_genoeg_keuzes"), "eerst: heb je genoeg?")
	waar(_kies("mb_genoeg", "nee"), "een fout antwoord")
	await _wacht_mispauze()
	gelijk(int(State.s["sterren"]), 3, "na een misser: nog altijd niets af")
	waar(_kies("mb_genoeg", "ja"), "het goede antwoord")
	waar(await _wacht_op("mb_over_keuzes"), "dan: hoeveel houd je over?")
	gelijk(int((State.spel_data("meubels")["versiering"] as Dictionary).get("vlag", 0)), 0,
		"nog altijd geen sticker")
	waar(_typ("mb_over", 2), "3 − 1 = 2")
	gelijk(int(State.s["sterren"]), 2, "nu pas één ster af")
	gelijk(int((State.spel_data("meubels")["versiering"] as Dictionary).get("vlag", 0)), 1,
		"en de sticker in het bakje")
	_af()

## R2-gat 3 (spel.gd:200-215 vóór de fix): stoppen gooide de afrekening weg;
## wie een misser had, kon via een uitgang een nieuwe (makkelijkere) vraag
## halen.  Nu komt de open vraag ONVERANDERD terug — ook na een nieuwe dag, met
## meer munten en een andere band.
func test_r2_open_vraag_komt_onveranderd_terug() -> void:
	await _op(Vector2(1000, 648), 5, 12)
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	waar(_blad_tik("Kk_plant"), "plant erbij")
	await _tel_frames()
	waar(_blad_tik("Kk_mandje"), "mandje erbij: afrekenen")
	await _tel_frames()
	var knoppen_voor := _strook_namen("mb_som")
	waar(_typ_fout("mb_som", 4), "een misser op de som")
	await _tel_frames()
	# een uitgang, een nieuwe dag, meer munten en een andere band
	Games.stop()
	await _tel_frames()
	State.s["dag"] = int(State.s.get("dag", 1)) + 1
	State.s["munten"] = 30
	State.s["gasten"] = _gasten(7)
	State.herbereken()
	waar(State.band() != 4 or true, "de band mag veranderen")
	waar(Games.start("meubels"), "opnieuw gestart")
	await _tel_frames()
	waar(not _er_is("mb_kas"), "geen nieuwe kassavraag eroverheen")
	waar(not Ui.blad_open_nu(), "en geen boek")
	gelijk(_kaart_tekst("mb_som", "som"), "€1 + €3 =", "dezelfde som")
	gelijk(_strook_namen("mb_som"), knoppen_voor, "met dezelfde vier knoppen")
	waar(not _er_is("mb_boek"), "na een misser geen weg terug naar het boek")
	waar(_typ("mb_som", 4), "het goede antwoord")
	waar(await _wacht_op("mb_genoeg_keuzes"), "genoeg?")
	gelijk(_kaart_tekst("mb_genoeg", "regel2"), "Je hebt €12. Is dat genoeg?",
		"de vraag rekent met wat je had: dezelfde vraag")
	waar(_kies("mb_genoeg", "ja"), "genoeg")
	waar(await _wacht_op("mb_bon_keuzes"), "de bon")
	gelijk(str(_munten_op_strook()), "[1, 2, 5]", "dezelfde buidel van €12")
	_af()

## En de kassavraag zelf: na een misser en een uitgang dezelfde munten op de
## toonbank en dezelfde vier knoppen, ook al kwamen er munten bij.
func test_r2_kassavraag_komt_onveranderd_terug() -> void:
	await _op(Vector2(1000, 648), 3, 9)
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	var knoppen_voor := _strook_namen("mb_kas")
	var munten_voor := _wolk_deel("mb_munten", "getal")
	waar(_typ_fout("mb_kas", 9), "een misser")
	await _tel_frames()
	Games.stop()
	await _tel_frames()
	State.s["munten"] = 14
	State.s["dag"] = int(State.s.get("dag", 1)) + 1
	waar(Games.start("meubels"), "opnieuw gestart")
	await _tel_frames()
	gelijk(_wolk_deel("mb_munten", "getal"), munten_voor, "dezelfde munten op de toonbank")
	gelijk(_strook_namen("mb_kas"), knoppen_voor, "dezelfde vier knoppen")
	waar(_typ("mb_kas", 9), "het goede antwoord is nog altijd 9")
	await _wacht_boek()
	waar(Ui.blad_open_nu(), "dan pas het boek")
	gelijk(State.spel_data("meubels").get("open", null), null, "de open vraag is gesloten")
	_af()

## R2-gat 4: na een misser terug naar het boek en iets goedkopers kiezen
## verving de open vraag.  Nu staat 📖 er na een misser niet meer.
func test_r2_na_een_misser_geen_goedkoper_ding() -> void:
	await _op(Vector2(1000, 648), 3, 9)
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	waar(_blad_tik("Kk_badkuip"), "koop de badkuip van €8")
	await _tel_frames()
	waar(_er_is("mb_boek"), "zonder misser mag je nog terug naar het boek")
	waar(_kies("mb_genoeg", "nee"), "een misser: 9 is wel genoeg voor 8")
	await _tel_frames()
	waar(not _er_is("mb_boek"), "na een misser niet meer")
	await _wacht_mispauze()
	waar(not _er_is("mb_boek"), "ook niet na de pauze")
	waar(_kies("mb_genoeg", "ja"), "het goede antwoord")
	waar(await _wacht_op("mb_bon_keuzes"), "de bon van de badkuip")
	gelijk(_kaart_tekst("mb_bon", "vak"), "€8", "dezelfde aankoop")
	waar(not _er_is("mb_boek"), "en ook hier geen weg terug")
	_af()

## R4: wat geen rekenen is maar wel mag (herschikken, een munt terugpakken,
## de buidel aantikken, ▸ meer plekjes) is gemarkeerd als `vrij`.  `Hits`
## bewaart die sleutel nog niet (de echte Rekenwacht komt op main), dus de
## keuring leest de bron.
func test_r4_vrije_acties_zijn_gemarkeerd() -> void:
	var bron := FileAccess.get_file_as_string("res://games/meubels/spel.gd")
	for id in ['"mbdraai_%s"', '"mbop_%s"', '"mb_terug"', '"mb_buidel"', '"mb_meer"']:
		var i := bron.find('"id": %s' % id)
		waar(i >= 0, "%s staat in de bron" % id)
		if i >= 0:
			var stuk := bron.substr(i, 700)
			var einde := stuk.find("})")
			waar(einde > 0 and stuk.substr(0, einde).contains('"vrij": true'),
				"%s is vrij spel" % id)
	for id in ['"mb_kas"', '"mb_genoeg"', '"mb_bon"']:
		var i := bron.find('"id": %s' % id)
		waar(i >= 0 and bron.substr(i, 400).contains('"reken": true'),
			"%s telt als rekenen" % id)
	# de eigen knoppen van het boek gaan door de poort van de Rekenwacht, en
	# bladeren (de tabs) is vrij spel
	waar(bron.contains('Reken.laat_door("spel", "meubels:" + id, b, vrij)'),
		"elke boekknop gaat door Reken.laat_door")
	waar(bron.contains('_knop("tab_" + welke, tekst, titel, wissel, true)'),
		"de tabs zijn vrij")

func _strook_namen(kaart_id: String) -> String:
	var uit := PackedStringArray()
	for k in _strook_knoppen(kaart_id):
		uit.append("%s:%s" % [str((k as Node).name), (k as Button).text])
	return ",".join(uit)

# ------------------------------------------- VA: de echte Rekenwacht (R1)

## VA (2026-10-09): next to the in-test counter, the REAL classifier.  Every
## turn starts from a fresh Rekenwacht with half a budget (so a right answer
## has room to pay back); after the turn `Reken.beurt()` must hold R1 by
## itself, agree with the counter tap for tap, and show that a right answer
## paid back (`Reken.goed` fired and the budget rose over the turn).
const VA_BUDGET := 6

func _va_begin() -> int:
	Reken.voor_test()
	for _i in Reken.BUDGET_MAX - VA_BUDGET:
		Reken.tik("spel", "test:va")
	return Reken.budget()

func _va_eind(wat: String, teller: Dictionary, budget_voor: int) -> void:
	var b := Reken.beurt()
	var r := int(b["reken"])
	var s := int(b["spel"])
	print("[VA] %s: reken=%d spel=%d goed=%d budget=%d->%d" % [wat, r, s, int(b["goed"]),
		budget_voor, Reken.budget()])
	waar(r >= s + 1, "%s: Reken.beurt() reken %d >= spel %d + 1" % [wat, r, s])
	gelijk(r, int(teller["reken"]), "%s: Reken.beurt().reken = de teller" % wat)
	gelijk(s, int(teller["spel"]), "%s: Reken.beurt().spel = de teller" % wat)
	waar(int(b["goed"]) >= 1, "%s: Reken.goed() vuurde" % wat)
	waar(Reken.budget() > budget_voor, "%s: het budget steeg (%d -> %d)" % [wat, budget_voor,
		Reken.budget()])
