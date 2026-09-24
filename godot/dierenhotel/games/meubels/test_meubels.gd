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

## Groep 3: één ding per keer, precies betalen, geen wisselgeld.
func test_beurt_band_3() -> void:
	await _op(Vector2(1000, 648), 3, 9)
	gelijk(State.band(), 3, "de band is 3")
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	gelijk(Sommen.Meubels.max_lijst(3), 1, "groep 3 koopt één ding per keer")
	waar(_blad_knop("Kk_mandje") != null, "het mandje staat in het boek")
	gelijk(_blad_knop("Kk_mandje").text, "🛒", "en is te koop bij 9 munten")
	gelijk(_blad_knop("Kk_badkuip").text, "🛒", "de badkuip van €8 ook")
	waar(_blad_tik("Kk_mandje"), "tik op 🛒 bij het mandje")
	await _tel_frames()
	# de bon hangt op de kassa, met de prijs in het vakje
	gelijk(_kaart_tekst("mb_bon", "regel"), "🧺 Mandje kost €3", "de prijszin")
	gelijk(_kaart_tekst("mb_bon", "regel2"), Spel.T_LEG_MUNTEN, "en de tweede regel")
	gelijk(_kaart_tekst("mb_bon", "vak"), "€3", "het vakje draagt het bedrag")
	waar(_er_is("mb_bank") and _er_is("mb_buidel"), "toonbank en buidel staan er")
	waar(_er_is("mb_boek"), "en de weg terug naar het boek")
	# buidel(9) = [2,2,2,2,1]; leg 1 + 2 = 3 neer
	gelijk(_titel("mb_buidel"), "munt van 1 euro (1 in je buidel)", "de buideltitel")
	waar(_tik("mb_bank"), "leg de munt van 1 neer")
	gelijk(_titel("mb_bank"), "de toonbank: €1", "de toonbank telt mee")
	waar(_er_is("mb_terug"), "en nu kan er een munt terug")
	waar(_tik("mb_bank"), "leg de munt van 2 neer")
	gelijk(_titel("mb_bank"), "de toonbank: €3", "precies genoeg")
	var sterren_voor := int(State.s["sterren"])
	waar(_tik("mb_ok"), "klaar met tellen")
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
	_af()

## Groep 4: twee dingen samen, en wisselgeld.
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
	waar(_blad_tik("Kk_mandje"), "mandje erbij")
	await _tel_frames()
	waar(_blad_knop("Kafrekenen") != null, "de afrekenknop verschijnt")
	gelijk(_blad_knop("Kafrekenen").tooltip_text, Spel.T_AFREKENEN, "aria Afrekenen")
	gelijk(_blad_knop("Kleeg").tooltip_text, Spel.T_LIJST_LEEG, "aria Lijstje leeg")
	waar(_blad_tik("Kafrekenen"), "afrekenen")
	await _tel_frames()
	# stap som
	gelijk(_kaart_tekst("mb_som", "som"), "€1 + €3 =", "de som staat op de kassa")
	gelijk(_kaart_tekst("mb_som", "regel"), "🛒 Plant €1 en mandje €3", "de somzin")
	gelijk(_kaart_tekst("mb_som", "regel2"), Spel.T_SAMEN, "en de vraag")
	waar(_typ("mb_som", 4), "tik 4 op de strook")
	await _wacht(0.6)
	await _tel_frames()
	# stap munten: buidel(12) = [5,2,2,2,1]; €5 is te veel -> wisselgeld
	gelijk(_kaart_tekst("mb_bon", "regel"), "🛒 Plant en mandje kosten €4", "de prijszin")
	waar(_tik("mb_buidel"), "volgende muntsoort")
	waar(_tik("mb_buidel"), "en nog een")
	gelijk(_titel("mb_buidel"), "munt van 5 euro (1 in je buidel)", "nu heb je €5 in je hand")
	waar(_tik("mb_bank"), "leg €5 neer")
	waar(_tik("mb_ok"), "klaar met tellen")
	await _tel_frames()
	gelijk(_kaart_tekst("mb_wissel", "som"), "€5 − €4 =", "de wisselsom, met een echte −")
	gelijk(_kaart_tekst("mb_wissel", "regel"), "👛 Je gaf €5, het kost €4", "de wisselzin")
	gelijk(_kaart_tekst("mb_wissel", "regel2"), Spel.T_TERUG_VRAAG, "en de vraag")
	var sterren_voor := int(State.s["sterren"])
	waar(_typ("mb_wissel", 1), "tik het wisselgeld")
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

## Groep 5: dezelfde regels als groep 4, met de grotere buidel.
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
	waar(_blad_tik("Kk_speelmand"), "speelmand erbij")
	await _tel_frames()
	waar(_blad_tik("Kafrekenen"), "afrekenen")
	await _tel_frames()
	gelijk(_kaart_tekst("mb_som", "som"), "€5 + €4 =", "de som")
	waar(_typ("mb_som", 9), "tik 9")
	await _wacht(0.6)
	await _tel_frames()
	# buidel(20) = precies te leggen; tel tot 9 met wat er in je hand zit
	var gelegd := _leg_precies(9)
	gelijk(gelegd, 9, "er ligt precies €9 op de toonbank")
	var bedden_voor := State.alle_bedden().size()
	var cap_voor := State.max_gasten()
	waar(_tik("mb_ok"), "klaar met tellen")
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

## Leg net zolang munten neer tot het bedrag klopt; kies zo nodig een andere
## soort.  Precies wat een kind doet, alleen sneller.
## Alles wat deze lus weet, leest ze van de knoppen zelf: het bedrag staat op
## de toonbank ("de toonbank: \u20ac4") en de munt in je hand op de buidel
## ("munt van 2 euro (3 in je buidel)").  Geen enkele interne functie.
func _leg_precies(doel: int) -> int:
	var terug_gebruikt := 0
	for _poging in 60:
		var geteld := _op_de_bank()
		if geteld < 0 or geteld >= doel:
			return geteld
		var beste := _grootste_die_past(doel - geteld)
		if beste <= 0:
			# niets past meer: haal de toonbank leeg, precies waar « voor is
			if terug_gebruikt >= 1 or not _er_is("mb_terug"):
				return geteld
			terug_gebruikt += 1
			for _r in 20:
				if not _er_is("mb_terug") or _op_de_bank() <= 0:
					break
				_tik("mb_terug")
			continue
		for _rondje in 5:
			if _in_de_hand() == beste:
				break
			_tik("mb_buidel")
		if _in_de_hand() != beste:
			return geteld
		_tik("mb_bank")
	return -1

## Tik de buidel één rondje rond en onthoud de grootste soort die nog past.
## De buidel staat daarna weer op de soort waar hij begon.
func _grootste_die_past(ruimte: int) -> int:
	var eerste := _in_de_hand()
	if eerste <= 0:
		return 0
	var beste := eerste if eerste <= ruimte else 0
	for _r in 4:
		_tik("mb_buidel")
		var v := _in_de_hand()
		if v <= 0 or v == eerste:
			break
		if v <= ruimte:
			beste = maxi(beste, v)
	return beste

func _op_de_bank() -> int:
	var t := _titel("mb_bank")
	if not t.begins_with("de toonbank: \u20ac"):
		return -1
	return t.substr("de toonbank: \u20ac".length()).split(" ")[0].to_int()

func _in_de_hand() -> int:
	var t := _titel("mb_buidel")
	if not t.begins_with("munt van "):
		return 0
	# `to_int()` plukt ELK cijfer uit de string ("2 euro (3 in je buidel)" -> 23),
	# dus alleen het eerste woord telt.
	return t.substr("munt van ".length()).split(" ")[0].to_int()

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

## Stap 0: met een lege buidel valt er niets te tellen — dan meteen het boek.
func test_nul_munten_slaat_de_vraag_over() -> void:
	await _op(Vector2(1000, 648), 3, 0)
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	waar(not _er_is("mb_kas"), "er komt geen som met goed = 0")
	waar(not _er_is("mb_munten"), "en geen lege toonbank")
	waar(Ui.blad_open_nu(), "het boek gaat meteen open")
	waar(_er_is("mb_geen"), "met een wolkje dat zegt waarom")
	gelijk(_wolk_deel("mb_geen", "icoon"), "💰", "het pictogram van het wolkje")
	gelijk(_wolk_deel("mb_geen", "tekst"), Spel.T_GEEN_MUNTEN, "Nog geen munten")
	gelijk(str(State.spel_data("meubels").get("view", "")), "boek",
		"en de stand staat op het boek")
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

## De eigenaar, 2026-09-24: "Nee geef geen hulp na fouten.  Kinderen moeten
## zelf leren rekenen."  Eén, twee en drie foute sommen bij het afrekenen, en
## drie keer "klaar" met te weinig op de toonbank: elke keer `🔄 Nog een keer`
## bij de kassa en verder niets — geen doortellen, geen "+€3", geen
## spookmunten.  Nooit straffen: niets afgepakt, en het goede antwoord en het
## goede bedrag leveren nog gewoon een ster op.
func test_geen_hulp_en_nooit_straffen() -> void:
	await _op(Vector2(1000, 648), 5, 12)
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	waar(_blad_tik("Kk_plant"), "plant erbij")
	await _tel_frames()
	waar(_blad_tik("Kk_mandje"), "mandje erbij")
	await _tel_frames()
	waar(_blad_tik("Kafrekenen"), "afrekenen")
	await _tel_frames()
	var munten_voor := int(State.s["munten"])
	var sterren_voor := int(State.s["sterren"])
	gelijk(_kaart_tekst("mb_som", "hulp"), "", "eerst geen hulpregel")
	var voor := beeld("meubels")
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
	await _wacht(0.6)
	await _tel_frames()
	# te weinig neergelegd, drie keer "klaar"
	waar(_tik("mb_bank"), "leg één munt neer")
	await _tel_frames()
	var bon := beeld("meubels")
	for keer in 3:
		var wat := "te weinig, klaar %d" % (keer + 1)
		waar(_tik("mb_ok"), "%s: zeg dat je klaar bent" % wat)
		await _tel_frames()
		_alleen_teleurstelling("mb_bon", wat)
		gelijk(_kaart_tekst("mb_bon", "vak"), "€4", "%s: de bon houdt zijn prijs" % wat)
		await _wacht_mispauze()
		niets_erbij(bon, beeld("meubels"), wat)
	var sterren_nu := int(State.s["sterren"])
	var gelegd := _leg_precies(4)
	gelijk(gelegd, 4, "leg de rest neer")
	waar(_tik("mb_ok"), "klaar")
	gelijk(int(State.s["sterren"]), sterren_nu + 1,
		"de ster komt er ook na zes missers (F5)")
	_af()

## Een fout wisselgeld (groep 4 en 5): dezelfde pauze, en geen telladder.
func test_geen_hulp_bij_het_wisselgeld() -> void:
	await _op(Vector2(1000, 648), 5, 12)
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	waar(_blad_tik("Kk_plant"), "plant erbij")
	await _tel_frames()
	waar(_blad_tik("Kk_mandje"), "mandje erbij")
	await _tel_frames()
	waar(_blad_tik("Kafrekenen"), "afrekenen")
	await _tel_frames()
	waar(_typ("mb_som", 4), "de som")
	await _wacht(0.6)
	await _tel_frames()
	# buidel(12) = [5,2,2,2,1]: leg €5 neer, dan de wisselvraag
	waar(_tik("mb_buidel") and _tik("mb_buidel"), "naar de munt van 5")
	waar(_tik("mb_bank"), "leg €5 neer")
	waar(_tik("mb_ok"), "klaar met tellen")
	await _tel_frames()
	waar(_er_is("mb_wissel"), "de wisselvraag staat er")
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
	gelijk(int(State.s["munten"]), 8, "de prijs gaat uit de kassa")
	_af()

## Groep 3 rekent geen wisselgeld uit: te veel = een munt terugpakken.
func test_groep_drie_pakt_een_munt_terug() -> void:
	await _op(Vector2(1000, 648), 3, 9)
	waar(not Sommen.Meubels.wisselgeld(3), "groep 3 kent nog geen wisselgeld")
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	waar(_blad_tik("Kk_plant"), "koop de plant van €1")
	await _tel_frames()
	# buidel(9) = [2,2,2,2,1]; leg de 2 neer -> te veel
	waar(_tik("mb_buidel"), "kies de munt van 2")
	gelijk(_titel("mb_buidel"), "munt van 2 euro (4 in je buidel)", "vier tweetjes")
	waar(_tik("mb_bank"), "leg €2 neer")
	waar(_tik("mb_ok"), "klaar met tellen")
	await _tel_frames()
	waar(not _er_is("mb_wissel"), "er komt géén wisselkaart in groep 3")
	_alleen_teleurstelling("mb_bon", "te veel")
	await _wacht_mispauze()
	waar(_er_is("mb_terug"), "en de knop om een munt terug te pakken")
	gelijk(_titel("mb_terug"), Spel.T_MUNT_TERUG, "met de titel van §5.9")
	waar(_tik("mb_terug"), "pak de munt terug")
	gelijk(_titel("mb_bank"), "de toonbank: €0", "de toonbank is weer leeg")
	waar(_tik("mb_buidel"), "kies de munt van 1")
	gelijk(_titel("mb_buidel"), "munt van 1 euro (1 in je buidel)", "één eentje")
	waar(_tik("mb_bank"), "leg de munt van 1 neer")
	gelijk(_titel("mb_bank"), "de toonbank: €1", "precies")
	waar(_tik("mb_ok"), "klaar")
	gelijk(int(State.s["munten"]), 8, "één munt betaald")
	_af()

# ==================================================================================
# 4. te weinig geld, en versiering
# ==================================================================================

func test_te_weinig_geld_zet_niets_op_slot() -> void:
	await _op(Vector2(1000, 648), 3, 3)
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	gelijk(_blad_knop("Kk_badkuip").text, "💛", "de badkuip is te duur")
	gelijk(_blad_knop("Kk_badkuip").tooltip_text, "badkuip kopen, 8 euro",
		"maar staat gewoon in het boek")
	waar(_blad_tik("Kk_badkuip"), "tik hem toch aan")
	await _tel_frames()
	waar(_er_is("mb_spaar"), "er komt een spaarwolkje")
	gelijk(_titel("mb_spaar"), "💛 €8 je hebt €3", "met de prijs en wat je hebt")
	gelijk(int(State.s["munten"]), 3, "er is niets afgeschreven")
	waar(_blad_knop("Kk_badkuip") != null, "en de badkuip staat er nog")
	waar(_blad_knop("Kk_plant") != null and _blad_knop("Kk_plant").text == "🛒",
		"wat je wel kunt betalen blijft gewoon te koop")
	_af()

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
	gelijk(_blad_knop("Kv_slinger").text, "💛", "de slinger van 3 sterren kan niet")
	waar(_blad_tik("Kv_slinger"), "tik hem toch aan")
	await _tel_frames()
	gelijk(int(State.s["sterren"]), 2, "er gaat geen ster af")
	gelijk(_titel("mb_spaar"), "⭐ 3 je hebt 2", "wel een spaarwolkje")
	waar(_blad_tik("Kv_vlag"), "koop de vlaggetjes")
	await _tel_frames()
	gelijk(int(State.s["sterren"]), 1, "één ster betaald")
	var q: Dictionary = State.spel_data("meubels")
	gelijk(int((q["versiering"] as Dictionary).get("vlag", 0)), 1, "en je hebt er een")
	gelijk(_blad_knop("Kv_vlag").text, "🛒", "de tweede kan nog")
	_af()

# ==================================================================================
# 5. herstellen uit ctx.data(), en opruimen
# ==================================================================================

func test_herstel_uit_ctx_data() -> void:
	await _op(Vector2(1000, 648), 5, 12)
	waar(Games.start("meubels"), "het spel start")
	await _tel_frames()
	await _kassa_door()
	waar(_blad_tik("Kk_plant"), "plant erbij")
	await _tel_frames()
	waar(_blad_tik("Kk_mandje"), "mandje erbij")
	await _tel_frames()
	waar(_blad_tik("Kafrekenen"), "afrekenen")
	await _tel_frames()
	waar(_typ("mb_som", 4), "de som")
	await _wacht(0.6)
	var gelegd := _leg_precies(4)
	gelijk(gelegd, 4, "leg €4 neer")
	waar(_tik("mb_ok"), "klaar")
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

# ==================================================================================
# 6. elke kinderzin letterlijk, en het tekstbudget van F4
# ==================================================================================

func test_teksten_staan_er_letterlijk() -> void:
	var bron := FileAccess.get_file_as_string("res://games/meubels/spel.gd")
	waar(not bron.is_empty(), "spel.gd is te lezen")
	# games-a.md §5.9, in volgorde van verschijnen
	for zin in ["📖 Meubelboek", "Meubels", "Versiering met sterren", "Afrekenen",
			"Lijstje leeg", "Boek dicht", "is genoeg", "je hebt ",
			"Hoeveel euro heb je?", "Nog geen munten", "je munten op de toonbank",
			"je buidel: ", " munten",
			"Hoeveel euro is dat samen?", "Je gaf ", "Hoeveel krijg je terug?",
			"kost ", "kosten ", "Leg de 🪙 munten op de toonbank", "tik een getal",
			"de toonbank: ", "munt van ", " in je buidel)", "klaar met tellen",
			"een munt terugpakken", "terug naar het meubelboek",
			"terug", "betaald", " neerzetten", "sleep naar een plekje",
			"hier neerzetten", "meer plekjes", "bezet", "gasten", "iemand slaapt",
			"bed draaien", " oppakken", " euro erbij", " kopen, ",
			" kopen voor ", " sterren"]:
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
			Spel.T_HOEVEEL, Spel.T_GEEN_MUNTEN, Spel.T_OP_TAFEL, Spel.T_BUIDEL]:
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
			Spel.T_KLAAR_TELLEN, Spel.T_MUNT_TERUG, Spel.T_TERUG_BOEK,
			Spel.T_TERUG, Spel.T_BETAALD, Spel.T_SLEEP, Spel.T_HIER, Spel.T_MEER,
			Spel.T_BEZET, Spel.T_GASTEN, Spel.T_SLAAPT, Spel.T_DRAAIEN,
			Spel.T_EERST, Spel.W_HIER, Spel.W_MEER, Spel.W_KLAAR, Spel.W_TERUG,
			Spel.W_BOEK, Spel.W_DRAAIEN, Spel.W_OPPAKKEN,
			Spel.T_HOEVEEL, Spel.T_GEEN_MUNTEN, Spel.T_OP_TAFEL, Spel.T_BUIDEL]:
		tekens.append(zin)
	# elk pictogram dat het spel zelf op een knop of in een wolkje zet
	for icoon in ["📖", "🪑", "⭐", "💰", "🛏", "🛒", "💛", "+", "«", "✖", "✔",
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

## F4: elke zin op elke kaart, voor elke combinatie die het spel kan maken.
func test_elke_kaartzin_past_in_het_budget() -> void:
	var namen: Array[String] = []
	for w in Sommen.Meubels.WINKEL:
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
	for zin in [Spel.T_SAMEN, Spel.T_TERUG_VRAAG, Spel.T_LEG_MUNTEN]:
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
## op y 762 — 22 eenheden onder de onderrand — zodra er twee dingen op het
## lijstje lagen; §5.5 zegt dat die knop er altijd is.
func test_boek_past_op_elk_scherm() -> void:
	var bewaard := State.s.duplicate(true)
	var boom := Engine.get_main_loop() as SceneTree
	for maat in SCHERMEN:
		var h: Dictionary = await _hotel_op(maat)
		waar(Games.start("meubels"), "%s: het spel start" % str(maat))
		for _f in 3:
			await boom.process_frame
		await _kassa_door()
		# twee dingen op het lijstje: dan is de bladzijde op zijn langst
		_blad_tik("Kk_plant")
		for _f in 2:
			await boom.process_frame
		_blad_tik("Kk_mandje")
		for _f in 3:
			await boom.process_frame
		var scherm := Vector2(maat)
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
		for naam in ["Kk_plant", "Kk_badkuip", "Kafrekenen", "Kleeg", "Kdicht"]:
			waar(_blad_knop(naam) != null, "%s: %s staat in het boek" % [str(maat), naam])
		waar(gekeurd >= 9, "%s: %d knoppen in het boek gekeurd" % [str(maat), gekeurd])
		await _hotel_af(h)
	State.s = bewaard

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
		# door naar de wereld: de betaalstap heeft de meeste knoppen tegelijk
		_blad_tik("Kk_plant")
		for _f in 2:
			await boom.process_frame
		_blad_tik("Kk_mandje")
		for _f in 2:
			await boom.process_frame
		_blad_tik("Kafrekenen")
		for _f in 3:
			await boom.process_frame
		_keur_dekking("%s betaalstap" % str(maat), kader)
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

