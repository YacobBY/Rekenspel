extends Proef
## G2 — de wekkerdienst, headless (games-b.md §2, architecture.md §12.2).
##
## De beurt wordt door de STROOK gedreven, niet door de binnenkant van het spel
## aan te roepen: elke tik gaat via de knop die het kind ook ziet
## (`wk_som_keuzes` → `Rij/K<id>`), zodat de test dezelfde weg loopt.

const ID := "wekker"

## De kaders die de vier ticketviewports opleveren (1024×768, 768×1024,
## 360×740, 740×360), gemeten door `tests/test_ui.gd` en daar afgedrukt.
const KADERS := [Vector2(990, 637), Vector2(734, 788), Vector2(326, 558),
	Vector2(558, 289)]

var _laag: Control = null

# ------------------------------------------------------------------ harnas

func _op(kader := Vector2(1000, 648)) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = kader
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	State.nieuw_spel()
	State.start_gekozen()
	Econ.rekening_stop()
	State.s["taken"] = []
	Hotel.bord_dicht()
	World.naar("gang")
	World.meet(Rect2(Vector2.ZERO, kader))

func _af() -> void:
	if Games.actief() != "":
		Games.stop()
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	if _laag != null:
		_laag.queue_free()
		_laag = null

## `n` gasten uit de pool, met een echt bed zolang er bedden zijn, en slapend.
func _gasten(n: int, dag := 1, kunnen := 3) -> Array:
	var pool := State.gasten_pool()
	var bedden := State.alle_bedden()
	var uit: Array = []
	for i in n:
		var g: Dictionary = pool[i % pool.size()]
		if i < bedden.size():
			g["kamer"] = str(bedden[i]["kamer"])
			g["bed"] = str(bedden[i]["slot"])
			g["waar"] = str(g["kamer"])
		else:
			g["kamer"] = ""
			g["bed"] = ""
			g["waar"] = "receptie"
		g["nachten"] = 100
		uit.append(g)
	State.s["gasten"] = uit
	State.s["dag"] = dag
	State.s["kunnen"] = kunnen
	State.herbereken()
	World.zet_dag(dag)
	World.sync(uit)
	# `World.sync` verplaatst een dier dat er al staat NIET, en `World.slaap`
	# laat een dier uit een andere kamer eerst lopen — in een test die geen
	# frames draait komt het dan nooit aan.  Eerst neerzetten, dan slapen.
	for g in uit:
		if not str(g["bed"]).is_empty():
			World.zet(str(g["id"]), str(g["kamer"]))
			World.slaap(str(g["id"]), str(g["kamer"]), str(g["bed"]))
	return uit

func _spel() -> MiniGame:
	var k = Games._knoop
	return k as MiniGame

func _knop(id: String) -> Button:
	var s := Hits.spot("wk_som_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		return null
	return s.knoop.get_node_or_null("Rij/K" + id) as Button

func _tik(id: String) -> bool:
	var b := _knop(id)
	if b == null:
		return false
	b.pressed.emit()
	return true

func _kaart_tekst(veld: String) -> String:
	var s := Hits.spot("wk_som")
	if s == null or not is_instance_valid(s.knoop):
		return ""
	var l := s.knoop.get_node_or_null(veld) as Label
	return "" if l == null else l.text

## Na een misser staat de strook even op slot (S5): wacht die pauze af, zoals
## een kind met een echte vinger dat ook doet.
func _wacht_mispauze() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var eind := Time.get_ticks_msec() + int(Ui.MIS_PAUZE * 1000.0) + 250
	while Time.get_ticks_msec() < eind:
		await boom.process_frame

## Staat de strook op slot?
func _op_slot() -> bool:
	var s := Hits.spot("wk_som_keuzes")
	return s != null and is_instance_valid(s.knoop) and (s.knoop as UiKeuzes).op_slot

## De grote klok van voren, of `null`.
func _groot() -> WekkerKlok:
	var s := Hits.spot("wk_groot")
	if s == null or not is_instance_valid(s.knoop):
		return null
	return s.knoop as WekkerKlok

## Nergens staat in woorden hoe laat de klok is (eigenaar 2026-09-24: "geen
## hint geven hoe laat het is"): geen sombalk, geen tijdplaatje op de klok, en
## de grote klok zegt het alleen met zijn wijzers — die staan wel op de stand.
func _geen_tijdhint(s: Dictionary, wat: String) -> void:
	var som := _kaart_tekst("Kolom/Rij/Som")
	gelijk(som, "", "%s: geen klokstand in woorden op de kaart" % wat)
	var k := Hits.spot("wk_som")
	if k != null and is_instance_valid(k.knoop):
		var l := k.knoop.get_node_or_null("Kolom/Rij/Som") as Label
		waar(l == null or not l.visible, "%s: de sombalk staat er niet" % wat)
	waar(Hits.spot("wk_tijd") == null, "%s: geen tijdplaatje boven de klok" % wat)
	var g := _groot()
	waar(g != null, "%s: de grote klok staat er" % wat)
	if g != null:
		gelijk([g.uur, g.minuut], [int(s["u"]), int(s["m"])],
			"%s: de grote klok wijst de stand aan" % wat)
		gelijk(g.tooltip_text, "", "%s: en verklapt hem niet in een titel" % wat)
	# geen enkele tekst in beeld noemt de stand — behalve als die toevallig de
	# wektijd is, want die staat terecht in de wens van de gast
	var woord: String = Sommen.Wekker.tijd_woord(int(s["u"]), int(s["m"]))
	var wil: String = Sommen.Wekker.tijd_woord(int(s["doelU"]), int(s["doelM"]))
	if woord == wil or str(s.get("stap", "")) == "duur":
		return
	for id in Hits.lijst():
		var q := Hits.spot(id)
		if q == null or not is_instance_valid(q.knoop) or q.kamer != World.kamer_nu():
			continue
		var teksten: Array[String] = [q.knoop.tooltip_text]
		if "text" in q.knoop:
			teksten.append(str(q.knoop.get("text")))
		for l in q.knoop.find_children("*", "Label", true, false):
			if (l as Label).is_visible_in_tree() or not q.knoop.is_inside_tree():
				teksten.append((l as Label).text)
		for t in teksten:
			waar(not (" %s " % t).contains(" %s " % woord) and not t.ends_with(woord),
				"%s: %s zegt de stand '%s' in woorden: '%s'" % [wat, id, woord, t])

# ------------------------------------------------------------- 1. aanmelding

## Het spel wordt door de mapscan gevonden; de mapnaam IS het id, en geen
## enkel gedeeld bestand is aangeraakt (architecture.md §6.1).
func test_aanmelding_via_de_mapscan() -> void:
	waar(Games.lijst().has(ID), "de scan vindt res://games/wekker")
	var def := Games.definitie(ID)
	gelijk(def.get("id", ""), ID, "de mapnaam is het id")
	gelijk(def.get("naam", ""), "Wekkerdienst", "naam")
	gelijk(def.get("kamer", ""), "gang", "kamer")
	gelijk(def.get("stub", true), false, "geen stub: het spel doet echt iets")
	waar(not def.has("wens"), "de wekker lost geen wens in")
	var hs: Dictionary = def.get("hotspot", {})
	gelijk(hs.get("obj", ""), "kist", "het icoontje hangt aan de kist")
	gelijk(hs.get("dx", 0), -66, "en schuift met dx naar de klok")
	gelijk(hs.get("dz", 0), -13, "en met dz")
	gelijk(hs.get("hoog", 0), 26, "hoogte van het icoontje")
	gelijk(hs.get("icoon", ""), "⏰", "icoon")
	gelijk(hs.get("label", ""), "Wekker", "label")
	var taak: Dictionary = def.get("taak", {})
	gelijk(taak.get("id", ""), "wekker", "taak-id")
	gelijk(taak.get("icoon", ""), "⏰", "taakicoon")
	gelijk(taak.get("prio", 0), 3, "taak prio 3")
	gelijk(taak.get("tekst", ""), "Wekker zetten", "prikbordtekst")
	waar(Ui.keur_taak("wekker", str(taak.get("tekst", ""))), "≤ 6 woorden op het kaartje")

## `unlock: N >= 1`, en de prikbordvoorwaarde: er zijn gasten én (ronde is
## avond of er slaapt er één).
func test_unlock_en_prikbordvoorwaarde() -> void:
	_op()
	waar(not Games.ontgrendeld(ID), "zonder gasten is er niets te wekken")
	var wanneer: Callable = Games.definitie(ID)["taak"]["wanneer"]
	waar(not wanneer.call(State.s), "en er staat geen kaartje op het bord")
	_gasten(2)
	waar(Games.ontgrendeld(ID), "met één gast mag het spel")
	State.s["ronde"] = "vrij"
	waar(wanneer.call(State.s), "een slaper zet het kaartje op het bord")
	for g in State.s["gasten"]:
		World.zet(str(g["id"]), "gang", 20.0, 20.0)
	waar(not wanneer.call(State.s), "wakker en overdag: geen kaartje")
	State.s["ronde"] = "avond"
	waar(wanneer.call(State.s), "in de avondronde altijd wel")
	_af()

# ---------------------------------------------------- 2. de bevroren getallen

## De nagerekende tabel van games-b.md §2.3, regel voor regel.  Het spel rekent
## zelf niets uit: het roept `Sommen.Wekker.*` aan (architecture.md §2.2).
func test_getallen_van_de_generator() -> void:
	var w := Sommen.Wekker
	var rijen := [
		# N, band, dag, idx, startwoord, doelwoord, vorm
		[2, 3, 1, 0, "7 uur", "10 uur", "zet"],
		[3, 3, 2, 0, "10 uur", "1 uur", "zet"],
		[5, 4, 1, 0, "half 7", "10 uur", "zet"],
		[5, 4, 2, 1, "kwart voor 11", "half 3", "zet"],
		[8, 5, 1, 0, "7 uur", "10 uur", "duur"],
		[8, 5, 2, 0, "5 voor 10", "half 2", "zet"],
		[9, 5, 3, 0, "5 uur", "8 uur", "duur"],
	]
	for r in rijen:
		var b: Dictionary = w.beurt(int(r[1]), int(r[0]), int(r[2]), int(r[3]))
		var wat := "N=%d band=%d dag=%d idx=%d" % [r[0], r[1], r[2], r[3]]
		gelijk(w.tijd_woord(int(b["u"]), int(b["m"])), r[4], "%s: start" % wat)
		gelijk(w.tijd_woord(int(b["doelU"]), int(b["doelM"])), r[5], "%s: doel" % wat)
		gelijk(b["stap"], r[6], "%s: vorm" % wat)
	# de twee tijdsduurrijen met hun keuzes, in die volgorde
	gelijk(str(w.beurt(5, 8, 1, 0)["keuzes"]), str([11, 9, 4, 10]), "keuzes dag 1")
	gelijk(str(w.beurt(5, 9, 3, 0)["keuzes"]), str([2, 8, 9, 7]), "keuzes dag 3")

## Tijd in woorden, de Nederlandse afspraken van games-b.md §2.4.
func test_tijd_in_woorden() -> void:
	var w := Sommen.Wekker
	var paren := [[7, 0, "7 uur"], [7, 15, "kwart over 7"], [7, 30, "half 8"],
		[7, 45, "kwart voor 8"], [7, 5, "5 over 7"], [7, 20, "10 voor half 8"],
		[7, 35, "5 over half 8"], [7, 50, "10 voor 8"], [12, 30, "half 1"],
		[11, 55, "5 voor 12"]]
	for p in paren:
		gelijk(w.tijd_woord(int(p[0]), int(p[1])), p[2],
			"%d:%02d" % [int(p[0]), int(p[1])])
	gelijk(w.uur_ico(7, 40), "🕗", "het klokje van het dichtstbijzijnde uur")
	gelijk(w.uur_ico(7, 20), "🕖", "en naar beneden")

# ------------------------------------------------------- 3. één beurt per band

func _speel_beurt(band_n: int, dag: int, kunnen: int, verwacht_band: int) -> void:
	_op()
	_gasten(band_n, dag, kunnen)
	gelijk(State.band(), verwacht_band, "band bij N=%d" % band_n)
	waar(Games.start(ID), "het spel start")
	gelijk(Games.actief(), ID, "en is actief")
	gelijk(World.kamer_nu(), "gang", "de camera staat in de gang")
	var spel := _spel()
	waar(spel != null, "de spelknoop bestaat")
	if spel == null:
		_af()
		return
	var s: Dictionary = spel.stand()
	gelijk(int(s["band"]), verwacht_band, "de beurt draait op deze band")
	# de tijdsduurvraag eerst, als die er is
	if str(s["stap"]) == "duur":
		waar(_knop("u%d" % int(s["doelU"])) != null, "de goede uurknop staat er")
		gelijk(_kaart_tekst("Kolom/Regel2"), "Hoe laat is hij wakker?",
			"de tijdsduurvraag staat op de kaart")
		waar(_tik("u%d" % int(s["doelU"])), "het goede uur wordt getikt")
		gelijk(str(s["stap"]), "zet", "daarna mag de klok gezet worden")
	# de klok staat op de startstand en niets zegt die in woorden
	_geen_tijdhint(s, "start band %d" % verwacht_band)
	waar(not World.decor_plek("klok", "gang").is_empty(), "de klok hangt in de gang")
	# draaien tot de wijzers op het doel staan: alleen met de knoppen die
	# deze band heeft, hier alleen vooruit
	var stappen := {"uur": 60, "kwartier": 15, "vijf": 5}
	var rondjes := 0
	while not spel.goed() and rondjes < 200:
		rondjes += 1
		var gedaan := false
		for knop in ["uur", "kwartier", "vijf"]:
			if _knop(knop) == null:
				continue
			var nu: int = Sommen.Wekker.in_min(int(s["u"]), int(s["m"]))
			var doel: int = Sommen.Wekker.in_min(int(s["doelU"]), int(s["doelM"]))
			var over: int = posmod(doel - nu, 720)
			if over >= int(stappen[knop]):
				waar(_tik(knop), "tik %s" % knop)
				gedaan = true
				break
		if not gedaan:
			break
	waar(spel.goed(), "de wijzers staan op de wektijd (band %d)" % verwacht_band)
	var g := _groot()
	waar(g != null and g.uur == int(s["doelU"]) and g.minuut == int(s["doelM"]),
		"de grote klok draait mee tot de wektijd")
	gelijk(_kaart_tekst("Kolom/Rij/Som"), "", "en de kaart zegt de stand niet")
	var sterren_voor: int = int(State.s["sterren"])
	waar(_tik("klaar"), "✅ Klaar")
	gelijk(str(spel.stand()["stap"]), "wakker", "de gast wordt wakker")
	gelijk(int(State.s["sterren"]), sterren_voor + 1, "er valt precies één ster")
	gelijk(_kaart_tekst("Kolom/Regel"),
		"⏰ %s is wakker" % str(State.s["gasten"][0]["naam"]), "de feestkaart")
	waar(Hits.spot("wk_gast") == null, "het wekkerkaartje bij de gast is weg")
	waar(Hits.spot("wk_zon") != null, "en er hangt een ☀-wolkje")
	gelijk(World.kamer_nu(), str(State.s["gasten"][0]["kamer"]),
		"de camera springt naar de kamer van de gast")
	# Alles wat in de gang hangt is dan van de ruit af: `Hits.plaats()` verbergt
	# elke hotspot die het deze ronde niet plaatst (V1-F1).  Zonder dat bleef de
	# kaart of het cijfertagje in de hoek van het kader staan, zonder indeling.
	Hits.plaats()
	for id in Hits.lijst():
		var q := Hits.spot(id)
		if q == null or q.door != ID or not is_instance_valid(q.knoop):
			continue
		waar(q.kamer == World.kamer_nu() or not q.knoop.visible,
			"%s hoort bij %s maar staat zichtbaar in %s (band %d)"
				% [id, q.kamer, World.kamer_nu(), verwacht_band])
	_af()

func test_beurt_band_3() -> void:
	_speel_beurt(2, 1, 3, 3)

func test_beurt_band_4() -> void:
	_speel_beurt(5, 2, 3, 4)

func test_beurt_band_5() -> void:
	_speel_beurt(8, 2, 5, 5)

## De hele ronde: drie gasten, en daarna sluit het spel zichzelf.
func test_hele_ronde_sluit_zichzelf() -> void:
	_op()
	_gasten(3, 1, 3)
	waar(Games.start(ID), "het spel start")
	var spel := _spel()
	if spel == null:
		_af()
		return
	var gewekt := 0
	for beurt in 3:
		var s: Dictionary = spel.stand()
		if s.is_empty():
			break
		while not spel.goed():
			if not _tik("uur") and not _tik("kwartier"):
				break
		waar(_tik("klaar"), "beurt %d: ✅ Klaar" % (beurt + 1))
		gewekt += 1
		if beurt < 2:
			waar(spel.volgende(), "de volgende slaper komt aan de beurt")
			gelijk(World.kamer_nu(), "gang", "de camera staat weer bij de klok")
	gelijk(gewekt, 3, "drie gasten gewekt")
	waar(spel.volgende(), "de ronde is af")
	gelijk(int(spel.stand()["af"]), 1, "en dat staat in de stand")
	waar(Hits.spot("wk_af") != null, "er hangt een wolkje op de klok")
	gelijk(int(State.s["sterren"]), 1, "hooguit één ster per ronde (games-b.md §2.9)")
	_af()

# ------------------------------------------------- 4. geen hulp na een fout

## Eén stap aan de wijzers draaien, maar nooit tot óp de wektijd: dan blijft de
## volgende ✅ een misser.  Een uur verder kan toevallig het doel zijn, vandaar
## de lus (hooguit één rondje van twaalf uur).
func _draai_naast(spel: MiniGame, wat: String) -> void:
	for i in 13:
		waar(_tik("uur"), wat)
		if not spel.goed():
			return
	fout("%s: de klok kwam niet naast de wektijd" % wat)

## Een verkeerde ✅: wat een kind ziet is een misser en niets meer.  De strook
## staat even op slot met `🔄 Nog een keer` aan de klok (de slaper ligt in zijn
## eigen kamer), en na de pauze staat alles er precies zo bij als vlak ervoor.
func _verkeerd_klaar(wat: String) -> void:
	var voor := beeld(ID)
	var hulp := _kaart_tekst("Kolom/Hulp")
	waar(_tik("klaar"), wat)
	waar(_op_slot(), "%s: de strook staat even op slot" % wat)
	waar(mis_wolk("wk_som"), "%s: met 🔄 Nog een keer bij de klok" % wat)
	gelijk(_kaart_tekst("Kolom/Hulp"), hulp, "%s: de hulpregel blijft wat hij was" % wat)
	await _wacht_mispauze()
	niets_erbij(voor, beeld(ID), wat)

## De eigenaar, 2026-09-24: "Nee geef geen hulp na fouten.  Kinderen moeten
## zelf leren rekenen."  Eén, twee en drie echte pogingen naast de wektijd: de
## gast slaapt door, de wijzers blijven staan, de kaart herhaalt de wens met de
## klokstand in de balk — en de vaste regel "💛 draai tot de klok klopt" blijft
## staan.  Geen "draai nog wat verder", geen telladder, geen spookwijzers.  De
## goede stand wekt hem daarna gewoon.
func test_geen_hulp_na_een_fout() -> void:
	_op()
	_gasten(2, 1, 3)
	waar(Games.start(ID), "het spel start")
	var spel := _spel()
	if spel == null:
		_af()
		return
	var s: Dictionary = spel.stand()
	waar(not spel.goed(), "de klok staat nog niet goed")
	var regel_voor := _kaart_tekst("Kolom/Regel")
	gelijk(_kaart_tekst("Kolom/Hulp"), "💛 draai tot de klok klopt",
		"de vaste regel staat er vanaf de eerste tik (K3)")
	for keer in 3:
		var wat := "misser %d" % (keer + 1)
		_draai_naast(spel, "%s: eerst aan de wijzers draaien" % wat)
		var u_voor := int(s["u"])
		var m_voor := int(s["m"])
		await _verkeerd_klaar(wat)
		gelijk(int(s["missers"]), keer + 1, "%s: geteld" % wat)
		gelijk(str(s["stap"]), "mis", "%s: de kaart staat op mis" % wat)
		gelijk(int(s["u"]), u_voor, "%s: de wijzers blijven staan (uur)" % wat)
		gelijk(int(s["m"]), m_voor, "%s: de wijzers blijven staan (minuut)" % wat)
		gelijk(_kaart_tekst("Kolom/Hulp"), "💛 draai tot de klok klopt",
			"%s: geen hulpladder, de vaste regel" % wat)
		gelijk(_kaart_tekst("Kolom/Regel"), regel_voor, "%s: dezelfde wens" % wat)
		_geen_tijdhint(s, wat)
		waar(not spel.klok_params().has("spookU") and not spel.klok_params().has("spookM"),
			"%s: geen spookwijzers" % wat)
		waar(bool(World.slaapt(str(s["gast"]))), "%s: de gast slaapt door" % wat)
	gelijk(int(State.s["sterren"]), 0, "een misser kost geen ster")
	# de goede stand wekt hem gewoon
	while not spel.goed():
		if not _tik("uur") and not _tik("kwartier"):
			break
	waar(_tik("klaar"), "✅ op de goede stand")
	gelijk(str(spel.stand()["stap"]), "wakker", "en de gast wordt wakker")
	_af()

## N2 — twee keer ✅ tikken zonder aan de wijzers te draaien is geen tweede
## poging: het telt geen misser (R3, het adaptieve signaal).  Het blijft wel
## een verkeerd antwoord om te zien — de strook even op slot met
## `🔄 Nog een keer` — en ook hier komt er geen hulp bij: de kaart zegt niet
## "draai eerst aan de wijzers" (eigenaar 2026-09-24).
func test_klaar_zonder_draaien_telt_geen_misser() -> void:
	_op()
	_gasten(2, 1, 3)
	waar(Games.start(ID), "het spel start")
	var spel := _spel()
	if spel == null:
		_af()
		return
	var s: Dictionary = spel.stand()
	var u_voor := int(s["u"])
	var m_voor := int(s["m"])
	waar(not spel.goed(), "de klok staat nog niet goed")
	for keer in 2:
		await _verkeerd_klaar("✅ zonder te draaien (%d)" % (keer + 1))
		gelijk(int(s["missers"]), 0, "tik %d telt geen misser" % (keer + 1))
		gelijk(str(s["stap"]), "zet", "de zetkaart blijft staan")
		gelijk(_kaart_tekst("Kolom/Hulp"), "💛 draai tot de klok klopt",
			"de vaste regel, geen extra zin")
		waar(not spel.klok_params().has("spookU"), "geen spookuurwijzer")
		waar(not spel.klok_params().has("spookM"), "geen spookminuutwijzer")
	gelijk(int(s["u"]), u_voor, "de wijzers staan nog waar ze stonden (uur)")
	gelijk(int(s["m"]), m_voor, "de wijzers staan nog waar ze stonden (minuut)")
	_geen_tijdhint(s, "na twee keer ✅ zonder draaien")
	gelijk(int(State.s["sterren"]), 0, "er valt geen ster")
	# draaien is wél een poging: dán telt ✅ weer als misser
	_draai_naast(spel, "aan de wijzers draaien")
	await _verkeerd_klaar("✅ na een echte draai")
	gelijk(int(s["missers"]), 1, "nu telt de misser wel")
	gelijk(_kaart_tekst("Kolom/Hulp"), "💛 draai tot de klok klopt", "en de regel blijft")
	_af()

## Nooit spookwijzers: ook na vier echte pogingen, met tikken ertussen, wijst
## er niets bleeks de wektijd aan (eigenaar 2026-09-24).  De klok draagt alleen
## zijn eigen wijzers, en het model kent geen spookwijzers meer.
func test_nooit_spookwijzers() -> void:
	_op()
	_gasten(2, 1, 3)
	waar(Games.start(ID), "het spel start")
	var spel := _spel()
	if spel == null:
		_af()
		return
	var s: Dictionary = spel.stand()
	for keer in 4:
		_draai_naast(spel, "draai %d" % (keer + 1))
		await _verkeerd_klaar("poging %d" % (keer + 1))
		gelijk(spel.klok_params().keys(), ["uur", "min"],
			"poging %d: de klok kent alleen zijn eigen wijzers" % (keer + 1))
	gelijk(int(s["missers"]), 4, "vier missers")
	var met := Art.model("wekker_klok", {"uur": 3, "min": 0, "spookU": 9, "spookM": 30})
	var zonder := Art.model("wekker_klok", {"uur": 3, "min": 0})
	gelijk(met.size(), zonder.size(), "een oude spookparameter tekent niets meer")
	gelijk(int(State.s["sterren"]), 0, "en het kostte geen ster")
	_af()

## "Doe ook een 'uur eraf' optie" (eigenaar 2026-09-24): de wijzers een uur
## terug, vóór 1 uur komt 12 uur, de minuten blijven staan.  Het is een draai
## als elke andere: de teller loopt op (R3), een misser-kaart gaat terug naar
## de gewone zin, en de grote klok wijst mee.  En wie over de wektijd heen
## draaide, komt er met één tik terug.
func test_uur_eraf_draait_een_uur_terug() -> void:
	_op()
	_gasten(5, 2, 3)
	waar(Games.start(ID), "het spel start")
	var spel := _spel()
	if spel == null:
		_af()
		return
	var s: Dictionary = spel.stand()
	gelijk(int(s["band"]), 4, "band 4: met kwartieren")
	for keer in 13:
		var u_voor := int(s["u"])
		var m_voor := int(s["m"])
		var d_voor := int(s["draaien"])
		waar(_tik("uur_af"), "uur eraf (%d)" % keer)
		gelijk(int(s["u"]), Sommen.Wekker.u12(u_voor - 1), "een uur terug vanaf %d" % u_voor)
		gelijk(int(s["m"]), m_voor, "de minuten blijven staan")
		gelijk(int(s["draaien"]), d_voor + 1, "het telt als draai")
		var g := _groot()
		waar(g != null and g.uur == int(s["u"]) and g.minuut == int(s["m"]),
			"de grote klok wijst mee")
	# over de wektijd heen en weer terug
	var rondjes := 0
	while not spel.goed() and rondjes < 60:
		rondjes += 1
		var over: int = posmod(Sommen.Wekker.in_min(int(s["doelU"]), int(s["doelM"]))
			- Sommen.Wekker.in_min(int(s["u"]), int(s["m"])), 720)
		if over >= 60:
			_tik("uur")
		else:
			_tik("kwartier")
	waar(spel.goed(), "de klok staat op de wektijd")
	waar(_tik("uur"), "een uur te ver")
	waar(not spel.goed(), "nu staat hij er voorbij")
	waar(_tik("uur_af"), "en met uur eraf")
	waar(spel.goed(), "weer precies goed")
	# na een misser brengt uur eraf de gewone zin terug, zoals elke draai
	_tik("uur_af")
	waar(_tik("klaar"), "✅ op een verkeerde stand")
	gelijk(str(s["stap"]), "mis", "een misser")
	await _wacht_mispauze()
	waar(_tik("uur"), "terugdraaien")
	gelijk(str(s["stap"]), "zet", "de gewone zin is terug")
	waar(_tik("klaar"), "✅")
	gelijk(str(spel.stand()["stap"]), "wakker", "de gast wordt wakker")
	_af()

## De tijdsduurvraag van band 5: een verkeerd uur is een misser zonder
## telladder; goed bouwt de kaart met de andere knoppen opnieuw op.
func test_tijdsduurvraag() -> void:
	_op()
	_gasten(8, 1, 5)
	waar(Games.start(ID), "het spel start")
	var spel := _spel()
	if spel == null:
		_af()
		return
	var s: Dictionary = spel.stand()
	gelijk(str(s["stap"]), "duur", "dag 1, gast 1, band 5: een tijdsduurvraag")
	gelijk(_kaart_tekst("Kolom/Regel"),
		"⏰ %s slaapt nog %d uur" % [str(State.s["gasten"][0]["naam"]), int(s["duur"])],
		"de zin van de tijdsduurvraag")
	gelijk(_kaart_tekst("Kolom/Regel2"), "Hoe laat is hij wakker?", "en de vraag")
	gelijk(Hits.spot("wk_som_keuzes").knoop.tooltip_text,
		"hoe laat wordt hij wakker?", "de strooktitel")
	gelijk((s["keuzes"] as Array).size(), 4, "vier uurknoppen")
	var fout_u := 0
	for q in s["keuzes"]:
		if int(q) != int(s["doelU"]):
			fout_u = int(q)
			break
	var hulp := _kaart_tekst("Kolom/Hulp")
	for keer in 3:
		var voor := beeld(ID)
		waar(_tik("u%d" % fout_u), "een verkeerd uur (%d)" % (keer + 1))
		gelijk(int(s["missers"]), keer + 1, "misser %d" % (keer + 1))
		gelijk(str(s["stap"]), "duur", "de vraag blijft staan")
		waar(_op_slot() and mis_wolk("wk_som"), "de strook even op slot, 🔄 Nog een keer")
		gelijk(_kaart_tekst("Kolom/Hulp"), hulp, "geen telladder")
		await _wacht_mispauze()
		niets_erbij(voor, beeld(ID), "verkeerd uur %d" % (keer + 1))
	waar(not spel.klok_params().has("spookU"), "de tijdsduurvraag opent geen spookwijzers")
	waar(_tik("u%d" % int(s["doelU"])), "het goede uur")
	gelijk(str(s["stap"]), "zet", "nu mag de klok gezet worden")
	waar(not spel.klok_params().has("spookU"), "en op de zetkaart staan ze er ook niet")
	waar(_knop("uur") != null and _knop("vijf") != null and _knop("klaar") != null,
		"en de draaiknoppen van band 5 staan er")
	_af()

## K3 — de kaart groeit niet tussen de standen: zetten, drie missers, de
## tijdsduurvraag en daarna.  De kaarthoogte blijft gelijk tot op 2 px, zodat
## de strook eronder en de klok erboven hun plek houden (en sinds 2026-09-24
## verandert de hulpregel na een misser ook niet meer).  Gemeten met `Ui.kaart_mat`, de eerlijke maat op de breedte
## waarop de kaart écht tekent.
## De eerlijke kaarthoogte: `Ui.kaart_mat` meet de hulpregel op de breedte
## waarop de kaart écht tekent (Zie K1: `get_combined_minimum_size` liegt
## over de hulpregel).
func _kaart_hoogte() -> float:
	var s := Hits.spot("wk_som")
	if s == null or not is_instance_valid(s.knoop):
		return -1.0
	return Ui.kaart_mat(s.knoop as UiSomkaart).y

func test_kaarthoogte_blijft_gelijk_over_de_stappen() -> void:
	# band 3: zet → mis 1 → mis 2 → mis 3
	_op()
	_gasten(2, 1, 3)
	waar(Games.start(ID), "het spel start")
	var spel := _spel()
	if spel == null:
		_af()
		return
	var s: Dictionary = spel.stand()
	var h_zet := _kaart_hoogte()
	waar(h_zet > 0.0, "de kaart hangt")
	_draai_naast(spel, "draai 1")
	waar(_tik("klaar"), "misser 1")
	var h_mis1 := _kaart_hoogte()
	await _wacht_mispauze()
	_draai_naast(spel, "draai 2")
	waar(_tik("klaar"), "misser 2")
	var h_mis2 := _kaart_hoogte()
	await _wacht_mispauze()
	_draai_naast(spel, "draai 3")
	waar(_tik("klaar"), "misser 3")
	var h_mis3 := _kaart_hoogte()
	_af()
	# band 5: duur → duur-mis → zet
	_op()
	_gasten(8, 1, 5)
	waar(Games.start(ID), "het spel start (band 5)")
	spel = _spel()
	if spel == null:
		_af()
		return
	s = spel.stand()
	var h_duur := _kaart_hoogte()
	var fout_u := 0
	for q in s["keuzes"]:
		if int(q) != int(s["doelU"]):
			fout_u = int(q)
			break
	waar(_tik("u%d" % fout_u), "verkeerd uur bij de tijdsduurvraag")
	var h_duur_mis := _kaart_hoogte()
	await _wacht_mispauze()
	waar(_tik("u%d" % int(s["doelU"])), "goed uur bij de tijdsduurvraag")
	var h_zet5 := _kaart_hoogte()
	_af()
	for paar in [["mis 1", h_mis1], ["mis 2", h_mis2], ["mis 3", h_mis3]]:
		waar(absf(float(paar[1]) - h_zet) <= 2.0,
			"hoogte %s (%.1f) vs zet (%.1f) blijft binnen 2 px" % [paar[0], float(paar[1]), h_zet])
	waar(absf(h_duur_mis - h_duur) <= 2.0,
		"hoogte duur-mis (%.1f) vs duur (%.1f) blijft binnen 2 px" % [h_duur_mis, h_duur])
	waar(absf(h_zet5 - h_duur) <= 2.0,
		"hoogte zet na duur (%.1f) vs duur (%.1f) blijft binnen 2 px" % [h_zet5, h_duur])

## Het wekkerkaartje hangt bij het dier in ZIJN kamer.  Staat de camera in de
## gang, dan is er geen `wk_gast` — en dus ook geen Control die in de hoek van
## het kader blijft staan: `Hits.plaats()` zet `visible` alleen voor hotspots
## uit de kamer die in beeld is (zie de contractnotitie in `spel.gd`).
func test_wekkerkaartje_alleen_in_de_kamer_van_de_gast() -> void:
	_op()
	_gasten(2, 1, 3)
	waar(Games.start(ID), "het spel start")
	gelijk(World.kamer_nu(), "gang", "de camera staat in de gang")
	Hits.plaats()
	waar(Hits.spot("wk_gast") == null,
		"de slaper ligt in zijn eigen kamer: geen wolkje in de gang")
	# geen enkele Control van dit spel staat zichtbaar buiten zijn eigen kamer
	for id in Hits.lijst():
		var s := Hits.spot(id)
		if s == null or s.door != ID or not is_instance_valid(s.knoop):
			continue
		waar(s.kamer == World.kamer_nu() or not s.knoop.visible,
			"%s hoort bij kamer %s maar staat zichtbaar in %s"
				% [id, s.kamer, World.kamer_nu()])
	# mee naar de slaapkamer: daar hoort het kaartje wel te staan
	var g: Dictionary = State.s["gasten"][0]
	World.naar(str(g["kamer"]))
	Hits.plaats()
	var w := Hits.spot("wk_gast")
	waar(w != null, "in de kamer van de gast hangt het wekkerkaartje wel")
	if w != null:
		gelijk(w.kamer, str(g["kamer"]), "en het hangt in die kamer")
		var st: Dictionary = _spel().stand()
		var wil: String = Sommen.Wekker.tijd_woord(int(st["doelU"]), int(st["doelM"]))
		waar(w.knoop.tooltip_text.contains(wil),
			"met de wektijd erin: '%s'" % w.knoop.tooltip_text)
		waar(w.knoop.tooltip_text.contains("💤"), "en het slaapicoontje")
	# terug naar de gang: het kaartje gaat weer weg
	World.naar("gang")
	Hits.plaats()
	waar(Hits.spot("wk_gast") == null, "terug in de gang is het wolkje weer weg")
	_af()
## De slag bij het goede uur wordt NOOIT afgeremd (games-b.md §2.9).
##
## Het kind draait altijd vlak vóór ✅ Klaar nog aan de wijzers, en elke draai
## slaat de klok — `Snd.klok()` remt zichzelf 120 ms af, dus langs die weg zou
## juist de feestslag wegvallen.  De test rekent dat na: de laatste draai zet de
## rem, en de slag die daarna komt klinkt toch.
func test_de_wekslag_wordt_nooit_afgeremd() -> void:
	_op()
	_gasten(2, 1, 3)
	Snd.ontgrendel()
	waar(Games.start(ID), "het spel start")
	var spel := _spel()
	if spel == null:
		_af()
		return
	var s: Dictionary = spel.stand()
	var rondjes := 0
	while not spel.goed() and rondjes < 200:
		rondjes += 1
		if not _tik("uur") and not _tik("kwartier") and not _tik("vijf"):
			break
	waar(spel.goed(), "de klok staat goed")
	# de laatste draai heeft `Snd.klok()` net geslagen: de rem staat erop
	waar(Snd.ontgrendeld() and not Snd.dempt(), "de geluidsband is open")
	waar(_tik("klaar"), "✅ Klaar")
	gelijk(str(s["stap"]), "wakker", "de gast wordt wakker")
	# De slag klinkt via `Snd.klok(true)`: een van de stemmen van `Snd` speelt de
	# klok-stream, ook al sloeg de klok net (de 120 ms rem geldt niet voor `force`).
	waar(_klok_klinkt(), "de wekslag klinkt ondanks de 120 ms rem")
	Games.stop()
	# en de rem zelf werkt nog: twee gewone slagen binnen 120 ms geven er één
	for p in Snd._spelers:
		p.stop()
	Snd._laatst.erase("klok")     # de hele test duurt korter dan 120 ms
	Snd.klok()
	Snd.klok()
	gelijk(_klok_stemmen(), 1, "zonder force remt de klok af")
	Snd.klok(true)
	gelijk(_klok_stemmen(), 2, "met force slaat hij toch")
	# De geluidsband blijft anders open voor elke test die hierna draait;
	# `Snd` kent geen tegenhanger van `ontgrendel()`.
	Snd.set("_wakker", false)
	_af()
# ------------------------------------------------------------ 5. herstellen

## Een belofte overleeft geen herlaad: de stand komt altijd uit ctx.data().
func test_herstel_uit_ctx_data() -> void:
	_op()
	_gasten(5, 2, 3)
	waar(Games.start(ID), "het spel start")
	var spel := _spel()
	if spel == null:
		_af()
		return
	waar(_tik("uur"), "één keer draaien")
	waar(_tik("klaar"), "en er een keer naast zitten")
	var voor: Dictionary = (spel.stand() as Dictionary).duplicate(true)
	Games.stop()
	# de opslag als een echt herlaad: schrijven, wissen, terugleze
	waar(State.bewaar(), "de stand is bewaard")
	State.s = {}
	waar(State.lees(), "en weer gelezen")
	World.sync(State.s["gasten"])
	for g in State.s["gasten"]:
		if not str(g["bed"]).is_empty():
			World.slaap(str(g["id"]), str(g["kamer"]), str(g["bed"]))
	waar(Games.start(ID), "het spel start opnieuw")
	var na_herlaad: Dictionary = _spel().stand()
	for sleutel in ["dag", "N", "band", "idx", "doelU", "doelM", "u", "m", "missers",
			"draaien", "gekeurd"]:
		gelijk(int(na_herlaad[sleutel]), int(voor[sleutel]),
			"%s overleeft het herlaad" % sleutel)
	gelijk(str(na_herlaad["gast"]), str(voor["gast"]), "dezelfde gast")
	gelijk(str(na_herlaad["stap"]), "mis", "en dezelfde stap")
	# JSON maakt van elk getal een float; de tellers van N2 worden bij het lezen
	# teruggezet, anders vergelijkt `klaar_tik` straks 1.0 met 1.
	for sleutel in ["draaien", "gekeurd"]:
		gelijk(typeof(na_herlaad[sleutel]), TYPE_INT,
			"%s komt als heel getal terug" % sleutel)
	_af()

## "Een methode om te wisselen met welk dier je de spellen speelt" (eigenaar,
## 2026-09-23): iedereen die gewekt kan worden mag als eerste, in check-in
## volgorde; zonder keuze begint de ronde zoals altijd.  Het dier op de
## spelbalk begint een verse ronde bij het volgende dier — de wijzers van de
## vorige zijn gewoon niet afgemaakt en niemand wordt wakker gemaakt — en een
## ronde waarin het gekozen dier al gewekt is, gaat gewoon verder.
func test_het_kind_kiest_wie_er_gewekt_wordt() -> void:
	_op()
	var gasten := _gasten(4, 1, 3)
	var ids: Array[String] = []
	for g in gasten:
		ids.append(str(g["id"]))
	waar(Games.start(ID), "het spel start")
	var spel := _spel()
	if spel == null:
		_af()
		return
	gelijk(str(Games.spelers()), str(ids), "wie gewekt kan worden: iedereen die slaapt, op volgorde")
	gelijk(Games.speler(), ids[0], "zonder keuze begint de ronde bij de eerste slaper")
	gelijk(str(spel.stand()["rij"]), str(ids.slice(0, 3)), "een rijtje van drie")
	waar(_tik("uur"), "de wijzers een uur verder")
	var sterren := int(State.s["sterren"])
	waar(Games.wissel_speler(), "het dier op de balk geeft de beurt door")
	gelijk(Games.actief(), ID, "de wekkerdienst draait nog")
	spel = _spel()
	var s: Dictionary = spel.stand()
	gelijk(Games.speler(), ids[1], "nu wordt het volgende dier gewekt")
	gelijk(str(s["gast"]), ids[1], "in een verse ronde")
	gelijk(int(s["idx"]), 0, "die vooraan begint")
	gelijk(str(s["rij"]), str([ids[1], ids[2], ids[3]]), "met het gekozen dier voorop")
	gelijk(int(s["draaien"]), 0, "en ongedraaide wijzers")
	gelijk(int(State.s["sterren"]), sterren, "er ging geen ster af")
	waar(World.slaapt(ids[0]), "wie eerst aan de beurt was, slaapt gewoon door")
	# het gekozen dier wordt gewekt, dan komt de volgende van zijn rijtje
	var stappen := {"uur": 60, "kwartier": 15, "vijf": 5}
	for _rondje in 200:
		if spel.goed():
			break
		var nu: int = Sommen.Wekker.in_min(int(s["u"]), int(s["m"]))
		var over: int = posmod(Sommen.Wekker.in_min(int(s["doelU"]), int(s["doelM"])) - nu, 720)
		var gedaan := false
		for knop in ["uur", "kwartier", "vijf"]:
			if _knop(knop) != null and over >= int(stappen[knop]):
				gedaan = _tik(knop)
				break
		if not gedaan:
			break
	waar(spel.goed(), "de wijzers staan op zijn wektijd")
	waar(_tik("klaar"), "✅ Klaar")
	waar(spel.volgende(), "de volgende slaper komt aan de beurt")
	gelijk(Games.speler(), ids[2], "en de balk toont hem")
	# een stop en een start: het gekozen dier is al gewekt, de ronde gaat verder
	Games.stop()
	waar(Games.start(ID), "het spel start opnieuw")
	gelijk(Games.speler(), ids[2], "met wie nu aan de beurt is")
	gelijk(int(_spel().stand()["idx"]), 1, "halverwege dezelfde ronde")
	State.s.erase("speler")
	_af()

## Een andere dag hoort een nieuwe beurt te geven, geen oude stand.
func test_andere_dag_geeft_een_nieuwe_beurt() -> void:
	_op()
	_gasten(5, 2, 3)
	waar(Games.start(ID), "het spel start")
	var voor: Dictionary = (_spel().stand() as Dictionary).duplicate(true)
	Games.stop()
	State.s["dag"] = 3
	World.zet_dag(3)
	waar(Games.start(ID), "het spel start op een nieuwe dag")
	var nu: Dictionary = _spel().stand()
	gelijk(int(nu["dag"]), 3, "de nieuwe dag")
	gelijk(int(nu["missers"]), 0, "en een schone beurt")
	waar(int(nu["doelU"]) != int(voor["doelU"]) or int(nu["doelM"]) != int(voor["doelM"]),
		"met een andere wektijd")
	_af()

## Geen gasten: een wolkje op de kist, daarna sluit het spel zichzelf.
func test_zonder_gasten_een_wolkje() -> void:
	_op()
	State.s["gasten"] = []
	World.sync([])
	# `unlock` houdt het spel normaal tegen; wie het toch start krijgt dit
	waar(Games.start(ID), "het spel start")
	var s := Hits.spot("wk_leeg")
	waar(s != null, "er hangt een wolkje")
	if s != null:
		waar(s.knoop.tooltip_text.contains("nog geen gasten")
			and s.knoop.tooltip_text.contains("🛏"),
			"en dat zegt het letterlijk: '%s'" % s.knoop.tooltip_text)
	waar(Hits.spot("wk_som") == null, "er is geen kaart")
	_af()

# --------------------------------------------------------- 6. stoppen opruimen

func test_stop_laat_de_wereld_schoon_achter() -> void:
	_op()
	_gasten(2, 1, 3)
	Hits.maak({"id": "hotelknop", "kamer": "gang", "x": 8.0, "z": 8.0, "y": 10.0,
		"icoon": "🔔", "label": "Bel", "door": "keurmeester",
		"aan": func(_s) -> void: pass})
	waar(Games.start(ID), "het spel start")
	waar(not World.decor_plek("klok", "gang").is_empty(), "de klok staat er")
	var groot := _groot()
	waar(groot != null, "en hij staat groot van voren")
	var eigen := 0
	for id in Hits.lijst():
		if Hits.spot(id).door == ID:
			eigen += 1
	waar(eigen >= 3, "het spel plaatste eigen elementen: kaart, strook, grote klok (%d)" % eigen)
	Games.stop()
	gelijk(Games.actief(), "", "er draait niets meer")
	gelijk(Hits.voorrang_van(), "", "en niemand heeft voorrang")
	for id in Hits.lijst():
		waar(Hits.spot(id).door != ID, "geen hotspot van het spel bleef staan: %s" % id)
	waar(Hits.spot("wk_som") == null, "de kaart is weg")
	waar(Hits.spot("wk_groot") == null, "de grote klok van voren is weg")
	waar(World.decor_plek("klok", "gang").is_empty(), "en de klok is weg")
	gelijk(World.decor_lijst().filter(func(d): return d["door"] == ID).size(), 0,
		"al het eigen decor is weg")
	waar(Hits.spot("hotelknop") != null, "de knop van een ander bleef staan")
	waar(groot == null or not is_instance_valid(groot) or groot.is_queued_for_deletion(),
		"de grote klok wordt opgeruimd")
	_af()

# ---------------------------------------------------------- 7. de kindtekst

## Elke zin letterlijk uit games-b.md §2.10, plus het budget van F4 (≤ 8
## woorden én ≤ 40 tekens) voor élke naam-en-tijdcombinatie die kan vallen.
func test_kindtekst_letterlijk_en_binnen_het_budget() -> void:
	_op()
	_gasten(8, 1, 5)
	waar(Games.start(ID), "het spel start")
	var spel := _spel()
	if spel == null:
		_af()
		return
	var s: Dictionary = spel.stand()
	# de langste naam uit de pool, zodat de zin op zijn zwaarst wordt gemeten
	var lang := ""
	for g in State.gasten_pool():
		if str(g["naam"]).length() > lang.length():
			lang = str(g["naam"])
	s["gast"] = str(State.s["gasten"][0]["id"])
	State.s["gasten"][0]["naam"] = lang
	var zinnen: Array[String] = []
	for u in range(1, 13):
		for m in range(0, 60):
			s["u"] = u
			s["m"] = m
			s["doelU"] = u
			s["doelM"] = m
			for stap in ["zet", "mis"]:
				s["stap"] = stap
				for dutje in [true, false]:
					s["slaapt"] = dutje
					var zin: Array = spel.zin_zet()
					zinnen.append(str(zin[0]))
					zinnen.append(str(zin[1]))
			s["stap"] = "duur"
			for uur in range(1, 6):
				s["duur"] = uur
				var zd: Array = spel.zin_duur()
				zinnen.append(str(zd[0]))
				zinnen.append(str(zd[1]))
			zinnen.append("%s is wakker" % lang)
	var te_lang: Array[String] = []
	for zin in zinnen:
		if zin.is_empty():
			continue
		if zin.split(" ", false).size() > 8 or zin.length() > 40:
			if not te_lang.has(zin):
				te_lang.append(zin)
	gelijk(te_lang.size(), 0, "elke zin binnen 8 woorden en 40 tekens: %s" % str(te_lang))
	# de vaste zinnen, letterlijk
	var scr: GDScript = load("res://games/wekker/spel.gd")
	var k: Dictionary = scr.get_script_constant_map()
	# de vaste hulpregel staat niet op een kaartregel, maar houdt hetzelfde
	# budget; de hulpladder van na een misser bestaat niet meer (2026-09-24)
	var hulp := str(k["T_HULP_BEGIN"])
	waar(hulp.split(" ", false).size() <= 8 and hulp.length() <= 40,
		'de hulpregel "%s" past in 8 woorden en 40 tekens' % hulp)
	for weg in ["T_HULP0", "T_HULP1", "T_HULP_LAD", "T_HULP2", "KL_SPOOK_U", "KL_SPOOK_M",
			"T_PLAAT"]:
		waar(not k.has(weg), "%s bestaat niet meer" % weg)
	gelijk(spel.som_balk(), "", "de sombalk zegt de klokstand niet meer (2026-09-24)")
	gelijk(k["T_NAAM"], "Wekkerdienst", "naam")
	gelijk(k["T_LABEL"], "Wekker", "label")
	gelijk(k["T_TAAK"], "Wekker zetten", "prikbord")
	gelijk(k["T_LEEG"], "nog geen gasten", "geen gasten")
	gelijk(k["T_ZET"], "Zet de klok", "zetten")
	gelijk(k["T_ZET_MORGEN"], "Zet de klok voor morgen", "zetten voor morgen")
	gelijk(k["T_DUUR2"], "Hoe laat is hij wakker?", "tijdsduurvraag")
	gelijk(k["T_STROOK"], "draai de klok", "strooktitel")
	gelijk(k["T_STROOK_DUUR"], "hoe laat wordt hij wakker?", "strooktitel duur")
	gelijk(k["T_HULP_BEGIN"], "💛 draai tot de klok klopt", "de vaste hulpregel")
	gelijk(k["T_SLAAPT_NOG"], "slaapt nog", "bij de gast, slapend")
	gelijk(k["T_NOG_NIET"], "nog niet", "bij de gast, wakker")
	gelijk(k["T_GOEDEMORGEN"], "goedemorgen", "het ☀-wolkje")
	gelijk(k["T_AF"], "allemaal gewekt", "de ronde af")
	gelijk(k["T_UUR"], "uur erbij", "knop uur")
	gelijk(k["T_UUR_K"], "uur", "knop uur, kort")
	gelijk(k["T_UUR_AF"], "uur eraf", "knop uur eraf")
	gelijk(k["T_UUR_AF_K"], "eraf", "knop uur eraf, kort")
	gelijk(k["ICO_UUR_AF"], "⏪", "knop uur eraf, pictogram")
	gelijk(k["T_KWARTIER"], "kwartier erbij", "knop kwartier")
	gelijk(k["T_KWARTIER_K"], "kwartier", "knop kwartier, kort")
	gelijk(k["T_VIJF"], "5 minuten erbij", "knop vijf")
	gelijk(k["T_VIJF_K"], "5 min", "knop vijf, kort")
	gelijk(k["T_KLAAR"], "Klaar", "knop klaar")
	# geen tofu: elk teken zit in de meegeleverde subset
	var mist: Array[String] = []
	for naam in k.keys():
		var v = k[naam]
		if typeof(v) != TYPE_STRING:
			continue
		for c in Ui.mist_tekens(str(v)):
			if not mist.has(c):
				mist.append("%s in \"%s\"" % [c, str(v)])
	for u in range(1, 13):
		for c in Ui.mist_tekens(Sommen.Wekker.uur_ico(u, 0)):
			if not mist.has(c):
				mist.append(c)
	for c in Ui.mist_tekens("🕐 ⏪ 🕒 🕧 ✅ ☀ 💤 🛏"):
		if not mist.has(c):
			mist.append(c)
	gelijk(mist.size(), 0, "geen tofu: %s" % str(mist))
	_af()

## Pictogram ÉN woord op elke keuzeknop, nooit een kaal pictogram (F4).
func test_elke_keuzeknop_draagt_een_woord() -> void:
	# band, gasten, dag, kunnen → de knoppen van die band; hooguit vier (§9)
	for rij in [[3, 2, 1, 3, ["uur", "uur_af", "klaar"]],
			[4, 5, 2, 3, ["uur", "uur_af", "kwartier", "klaar"]],
			[5, 8, 2, 5, ["uur", "uur_af", "vijf", "klaar"]]]:
		_op()
		_gasten(int(rij[1]), int(rij[2]), int(rij[3]))
		waar(Games.start(ID), "het spel start (band %d)" % int(rij[0]))
		gelijk(int(_spel().stand()["band"]), int(rij[0]), "band %d" % int(rij[0]))
		var st := Hits.spot("wk_som_keuzes")
		var rij_knoop: Node = st.knoop.get_node_or_null("Rij") if st != null else null
		gelijk(rij_knoop.get_child_count() if rij_knoop != null else -1,
			(rij[4] as Array).size(), "band %d: %d knoppen" % [int(rij[0]), (rij[4] as Array).size()])
		for id in rij[4]:
			var b := _knop(str(id))
			waar(b != null, "band %d: knop %s staat er" % [int(rij[0]), id])
			if b != null:
				var stukken := b.text.split(" ", false)
				waar(stukken.size() >= 2, "knop %s draagt pictogram én woord: '%s'"
					% [id, b.text])
		_af()

# ----------------------------------------------- 8. de knoppen dekken niets
##
## Deze twee draaien op de ECHTE schil in een SubViewport: de camera centreert
## een kamer alleen als er een viewport bekend is, en knoppen die tegen een
## camera op de oorsprong zijn gelegd bewijzen niets over de kamer die het kind
## ziet (dezelfde aanpak als `tests/test_hits.gd` voor de receptie).

## De vier ticketviewports.
const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740),
	Vector2i(740, 360)]

func _schil_op(maat: Vector2i) -> Dictionary:
	var boom := Engine.get_main_loop() as SceneTree
	var vp := SubViewport.new()
	vp.size = maat
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	boom.root.add_child(vp)
	var shell = load("res://scenes/main.tscn").instantiate()
	shell.set_meta("geen_start", true)
	vp.add_child(shell)
	for _f in 4:
		await boom.process_frame
	State.nieuw_spel()
	State.start_gekozen()
	Hotel.start()
	for _f in 4:
		await boom.process_frame
	_gasten(3, 1, 3)
	Hotel.naar_kamer("gang")
	for _f in 3:
		await boom.process_frame
	Games.start(ID)
	for _f in 6:
		await boom.process_frame
	var kader: Control = shell.get_node("Scherm/Kolom/Middenrij/Kaderdoos/Kader")
	return {"vp": vp, "kader": kader.size}

func _schil_af(h: Dictionary) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	if Games.actief() != "":
		Games.stop()
	Ui.naamplaten_leeg()
	Hits.wis_alles()
	(h["vp"] as SubViewport).queue_free()
	await boom.process_frame
	Ui.registreer_lagen(null, null, null)
	# De schil meldt de schermmaat aan `Ui`; die blijft anders staan voor elke
	# test die hierna draait (het cijferpad kiest zijn toetsmaat erop).  `Ui`
	# kent geen "vergeet het scherm" — zie het verslag onder "Contract gaps".
	Ui.vergeet_scherm()
	World.meet(Rect2(Vector2.ZERO, Vector2(1000, 648)))

## `Hits.dekking` is 0 % voor elke knop op een voorwerp, in vier schermmaten, en
## geen enkel element staat `krap` (architecture.md §4.3, §12.2).
func test_dekking_in_vier_kaders() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	for maat in SCHERMEN:
		var h: Dictionary = await _schil_op(maat)
		var kader: Vector2 = h["kader"]
		gelijk(Games.actief(), ID, "het spel draait bij %s" % str(maat))
		var dbg := Hits.debug()
		waar(dbg.has("wk_som"), "%s: de kaart staat er" % str(maat))
		var ids: Array = dbg.keys()
		for id in ids:
			var a: Dictionary = dbg[id]
			var r: Rect2 = a["rect"]
			waar(r.position.x >= -0.01 and r.position.y >= -0.01
				and r.end.x <= kader.x + 0.01 and r.end.y <= kader.y + 0.01,
				"%s: %s binnen het kader (%s)" % [str(maat), id, str(r)])
			waar(not a["krap"], "%s: %s vond een echte plek (%s)" % [str(maat), id, str(r)])
			if int(a["laag"]) != Hits.Laag.VAST:
				var aan := str(a.get("op", "")) == "aan"     # a hotel button ON its own thing
				waar(aan or Hits.dekking(str(id)) <= 0.0,
					"%s: %s dekt zijn voorwerp niet" % [str(maat), id])
				for ander in ids:
					var v: Rect2 = dbg[ander]["vlak"]
					if v.size.x <= 0.0 or (aan and v.is_equal_approx(a["vlak"])):
						continue
					var snij := r.intersection(v)
					gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
						"%s: %s staat op het voorwerp van %s" % [str(maat), id, ander])
			# geen twee elementen over elkaar
			for ander in ids:
				if str(ander) == str(id):
					continue
				var s2 := r.intersection(dbg[ander]["rect"] as Rect2)
				gelijk(maxf(0.0, s2.size.x) * maxf(0.0, s2.size.y), 0.0,
					"%s: %s en %s overlappen" % [str(maat), id, ander])
		# elke tikbare eigen knop is minstens 48 x 48
		for id in ids:
			var s := Hits.spot(str(id))
			if s == null or s.door != ID or s.kind == "tag":
				continue
			var r: Rect2 = dbg[id]["rect"]
			waar(r.size.x >= 48.0 and r.size.y >= 48.0,
				"%s: %s is een tikdoel (%s)" % [str(maat), id, str(r.size)])
		await _schil_af(h)
	State.s = bewaard

## De klok is echt te zien, hij komt groot naar voren, de kaart hangt eronder
## en er ligt niets op de wijzerplaat (games-b.md §2.6, bindend; eigenaar
## 2026-09-24: "de klok naar voren laten komen zodat de speler de klok
## duidelijk van voren kan zien").
func test_de_klok_komt_naar_voren_en_blijft_vrij() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	for maat in SCHERMEN:
		var h: Dictionary = await _schil_op(maat)
		var kader: Vector2 = h["kader"]
		var klok: Rect2 = World.vlak_van("wekker_klok", 48.0, 1.0, 0.0,
			World.decor_plek("klok", "gang").get("params", {}))
		var zicht := klok.intersection(Rect2(Vector2.ZERO, kader))
		waar(zicht.size.x > 0.0 and zicht.size.y > 0.0,
			"%s: de klok staat in beeld" % str(maat))
		waar(zicht.size.x * zicht.size.y >= 0.6 * klok.size.x * klok.size.y,
			"%s: en voor het grootste deel (%.0f %%)"
				% [str(maat), 100.0 * zicht.size.x * zicht.size.y / maxf(1.0, klok.size.x * klok.size.y)])
		var dbg := Hits.debug()
		waar(dbg.has("wk_groot"), "%s: de grote klok staat er" % str(maat))
		var plaat := klok
		if dbg.has("wk_groot"):
			plaat = dbg["wk_groot"]["rect"]
			waar(not bool(dbg["wk_groot"]["krap"]), "%s: op een echte plek" % str(maat))
			# groot: minstens anderhalf keer de wandklok, en nooit onder de 96
			waar(plaat.size.x >= maxf(96.0, 1.5 * klok.size.x),
				"%s: en groot (%s tegen de wandklok %s)" % [str(maat), str(plaat.size), str(klok.size)])
			waar(Rect2(Vector2.ZERO, kader).encloses(plaat),
				"%s: helemaal in beeld (%s)" % [str(maat), str(plaat)])
			# van voren: hij staat vóór de wandklok, dus hij dekt die grotendeels
			var snij_w := plaat.intersection(klok)
			waar(snij_w.size.x * snij_w.size.y >= 0.5 * zicht.size.x * zicht.size.y,
				"%s: recht voor de wandklok (%s vs %s)" % [str(maat), str(plaat), str(klok)])
			for id in dbg.keys():
				if str(id) == "wk_groot":
					continue
				var snij: Rect2 = (dbg[id]["rect"] as Rect2).intersection(plaat)
				gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
					"%s: %s staat niet op de grote klok" % [str(maat), id])
			var g := _groot()
			waar(g != null and g.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"%s: een tik gaat door de klok heen: het is geen knop" % str(maat))
		# de kaart hangt ONDER de klok, niet erover
		if dbg.has("wk_som"):
			var kaart: Rect2 = dbg["wk_som"]["rect"]
			waar(kaart.position.y >= plaat.end.y - 0.01,
				"%s: de kaart hangt onder de klok (%s vs %s)"
					% [str(maat), str(kaart), str(plaat)])
		await _schil_af(h)
	State.s = bewaard

# -------------------------------------------------------------- 9. het model

## Het eigen voxelmodel heet `wekker_klok` (§13 Q-X1-11), draait echt met zijn
## parameters mee en bakt per stand precies één plaatje.
func test_klokmodel() -> void:
	_op()
	_gasten(2, 1, 3)
	waar(Games.start(ID), "het spel start")
	waar(Art.heeft_model("wekker_klok"), "het model heet wekker_klok")
	waar(not Art.is_wereldmodel("wekker_klok"), "en is geen wereldmodel")
	var v3 := Art.model("wekker_klok", {"uur": 3, "min": 0})
	var v9 := Art.model("wekker_klok", {"uur": 9, "min": 0})
	waar(v3.size() > 500, "de klok heeft een wijzerplaat (%d voxels)" % v3.size())
	waar(str(v3) != str(v9), "3 uur ziet er anders uit dan 9 uur")
	# geen spookwijzers meer (eigenaar 2026-09-24): een oude parameter tekent niets
	var spook := Art.model("wekker_klok", {"uur": 3, "min": 0, "spookU": 9, "spookM": 30})
	gelijk(str(spook), str(v3), "spookU/spookM veranderen de klok niet")
	# het decorstuk staat op de plek van games-b.md §2.5
	var stuk := World.decor_plek("klok", "gang")
	gelijk(int(stuk.get("x", 0)), 48, "KX")
	gelijk(int(stuk.get("z", 0)), 1, "KZ")
	gelijk(stuk.get("ver", false), true, "wanddecor")
	gelijk(str(stuk.get("model", "")), "wekker_klok", "model")
	# er hangt GEEN cijfer meer op de klok dat de stand verklapt (2026-09-24)
	waar(Hits.spot("wk_tijd") == null, "geen tijdplaatje op de klok")
	_geen_tijdhint(_spel().stand(), "het model")
	_af()


func _klok_stemmen() -> int:
	var n := 0
	var klok = Snd._cache.get("klok")
	for p in Snd._spelers:
		if p.playing and p.stream == klok:
			n += 1
	return n

func _klok_klinkt() -> bool:
	return _klok_stemmen() > 0
