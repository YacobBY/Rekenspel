extends Proef
## G4 — de Wasmandtoren, headless.
##
## The turn is driven the way a finger drives it: every tap is a `pressed` on a
## real hotspot Control, every answer goes through the keypad band or the choice
## strip.  Nothing calls the game's own logic directly — the only hooks used are
## the read-only ones (`stand()`, `indeling()`, `juist()`).
##
## The heavy test is `test_kratplaatjes_zijn_zichtbaar_in_elk_kader`: the whole
## shell in a SubViewport, four viewports x three bands, with the bar chart
## finished and the question card up, and 0 misses on C1 and C2 of games-b.md
## §4.6 — the rules the HTML could only reach with an eight-step measuring
## ladder over 2.65 seconds.

const ID := "was"
const SpelWas := preload("res://games/was/spel.gd")
const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024),
	Vector2i(360, 740), Vector2i(740, 360)]
const BANDEN := [3, 4, 5]
## N and `kunnen` that really produce band 3, 4 and 5
## (`band = max(3, min(band_van_n(N), kunnen + 1))`).
const BAND_OPZET := {3: [3, 3], 4: [5, 3], 5: [8, 4]}

## Every child-facing literal of games-b.md §4.10 that the game spells out.
const KINDTEKST := [
	"Was sorteren", "nog te sorteren", "pak %d",
	"sokken", "sjaals", "doeken", "knuffels",
	"sok", "sjaal", "doek", "knuffel",
	"Elk blokje is 2 stuks",
	"Welke stapel is het hoogst?", "kies een stapel",
	"Hoeveel meer %s dan %s?", "Hoeveel stuks samen?", "Hoeveel %s zijn het?",
	"Hoeveel blokjes worden dat?",
	"Alles gesorteerd!", "klaar",
	"blokje", "blokjes", "krat met %s: %d %s",
	"berg met %d stuks was, kijk er goed naar",
	"berg met was, kijk er goed naar",
]
## What the pile and the hand say, per kind — the game composes these from the
## table in `WasSoorten`, so the table is what is checked (§4.10).
const HAND_EEN := ["een sok", "een sjaal", "een doek", "een knuffel"]
const HAND_TWEE := ["twee sokken", "twee sjaals", "twee doeken", "twee knuffels"]
const GREEP := ["pak 1", "pak 2"]

var _laag: Control = null
var _bewaard: Dictionary = {}
## `Ui` keeps the CSS size of the screen the shell last reported, and the tap
## rule is measured on it.  A test that builds a shell has to put it back, or
## the next suite measures its keypad against this test's phone.
var _scherm_voor := Vector2.ZERO

# ------------------------------------------------------------------ harnas
##
## `run_tests.gd` runs `res://games/<id>/test_*.gd` BEFORE `res://tests/`, so
## every harness here puts `State.s` back exactly as it found it.

## The light harness: one Control as every layer, no shell.  Enough for the
## logic, the strings and the save; not for the camera.
func _licht_op(kader := Vector2(1000, 648)) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_bewaard = State.s.duplicate(true)
	_laag = Control.new()
	_laag.size = kader
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	World.meet(Rect2(Vector2.ZERO, kader))

func _licht_af() -> void:
	if Games.actief() != "":
		Games.stop()
	Hits.wis_alles()
	World.decor_wis_alles()
	Ui.registreer_lagen(null, null, null)
	if _laag != null:
		_laag.queue_free()
		_laag = null
	if not _bewaard.is_empty():
		State.s = _bewaard
		_bewaard = {}

## N guests in real beds, the day, and a `kunnen` that gives exactly this band.
##
## `start_gekozen()` is deliberately NOT called: `State.bewaar()` is a no-op
## until the child answered the start sheet, so this whole suite never writes
## `user://dierenhotel.json`.  Everything asserted here lives in `State.s` and
## in `ctx.data()`, which are in memory — and a test that rewrote the save would
## hand the next suite its own day (measured: `test_ui.gd` read day 5 instead of
## the day it had just written).
func _wereld(band: int, dag := 1, gasten := -1, kunnen := -1) -> void:
	State.nieuw_spel()
	var opzet: Array = BAND_OPZET[band]
	if kunnen >= 0:
		opzet = [opzet[0], kunnen]
	var aantal := gasten if gasten > 0 else int(opzet[0])
	var pool := State.gasten_pool()
	var bedden := State.alle_bedden()
	var uit: Array = []
	for i in aantal:
		var g: Dictionary = pool[i % pool.size()]
		g["id"] = "%s%d" % [str(g["id"]), i]
		if i < bedden.size():
			g["kamer"] = str(bedden[i]["kamer"])
			g["bed"] = str(bedden[i]["slot"])
		g["waar"] = str(g.get("kamer", "receptie"))
		g["nachten"] = 100
		uit.append(g)
	State.s["gasten"] = uit
	State.s["kunnen"] = int(opzet[1])
	State.s["dag"] = dag
	State.s["taken"] = []
	gelijk(State.band(), band, "de opzet geeft band %d" % band)
	gelijk(State.n_gasten(), aantal, "en %d gasten" % aantal)

func _spel() -> Node:
	return Games._knoop if "_knoop" in Games else null

func _stand() -> Dictionary:
	var s := _spel()
	return {} if s == null or not s.has_method("stand") else s.stand()

# ---------------------------------------------------------------- tikken

func _tik(id: String) -> bool:
	var s := Hits.spot(id)
	if s == null or not is_instance_valid(s.knoop) or not (s.knoop is BaseButton):
		return false
	(s.knoop as BaseButton).emit_signal("pressed")
	return true

## Since wave 2 the pile sorts itself (`_sorteer_vanzelf`, a piece every
## SORTEER_S); the tests that only need the chart do not wait for it and take
## the same step at once (`sorteer_een`).  Group 5's opening question is
## answered on the way, because a child answers it before the pile sorts (N8).
func _sorteer_alles() -> int:
	var veilig := 0
	while veilig < 240:
		veilig += 1
		var st := _stand()
		if st.is_empty():
			break
		var stap := str(st.get("stap", ""))
		if stap == "vraag0":
			if not _antwoord_goed():
				break
			continue
		if stap != "sorteren":
			break
		var s := _spel()
		if s == null or not s.has_method("sorteer_een") or not s.sorteer_een():
			break
	return veilig

## Frames run (real time) until the turn stands on `stap`, or `max_s` passed.
func _wacht_tot_stap(stap: String, max_s := 8.0) -> bool:
	var boom := Engine.get_main_loop() as SceneTree
	var eind := Time.get_ticks_msec() + int(max_s * 1000.0)
	while Time.get_ticks_msec() < eind:
		if str(_stand().get("stap", "")) == stap:
			return true
		await boom.process_frame
	return str(_stand().get("stap", "")) == stap

## Tap the number `n` on the strip of four under the card (no keypad, no ✓).
func _toets(n: int) -> bool:
	return _kies("n%d" % n)

## Tap a number on the strip that is NOT the right one.
func _toets_fout() -> bool:
	var s := Hits.spot("ws_vraag_keuzes")
	var spel := _spel()
	if s == null or not is_instance_valid(s.knoop) or spel == null:
		return false
	for k in s.knoop.get_node("Rij").get_children():
		if k.name != "Kn%d" % int(spel.juist()):
			(k as BaseButton).emit_signal("pressed")
			return true
	return false

## Wait out the miss pause S5 puts on the answer strip (`Ui.MIS_PAUZE`, plus
## a little room).  A wrong answer holds the buttons shut for 1,2 s so a child
## cannot mash to a win — the four numbers, and since 2026-09-24 the strip of
## kinds of band 3 too; a test that wants three misses in a row therefore has
## to sit through the pause between them, the way a child with a real finger
## does.
func _wacht_mispauze() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var eind := Time.get_ticks_msec() + int(Ui.MIS_PAUZE * 1000.0) + 250
	while Time.get_ticks_msec() < eind:
		await boom.process_frame

## Press one button of the choice strip under the card.
func _kies(knop_id: String) -> bool:
	var s := Hits.spot("ws_vraag_keuzes")
	if s == null or not is_instance_valid(s.knoop):
		return false
	var rij := s.knoop.get_node_or_null("Rij")
	if rij == null:
		return false
	var k := rij.get_node_or_null("K" + knop_id) as BaseButton
	if k == null:
		return false
	k.emit_signal("pressed")
	return true

func ind_c2(spel) -> bool:
	return spel != null and bool(spel.indeling().get("c2", true))

func _kaart_tekst(naam: String) -> String:
	var s := Hits.spot("ws_vraag")
	if s == null or not is_instance_valid(s.knoop):
		return ""
	var k := s.knoop as UiSomkaart
	if k == null:
		return ""
	match naam:
		"regel":
			return k.regel_label.text if k.regel_label != null else ""
		"regel2":
			return k.regel2_label.text if k.regel2_label != null else ""
		"som":
			return k.som_label.text if k.som_label != null else ""
		"hulp":
			return k.hulp_label.text if k.hulp_label != null else ""
		"vak":
			return k.vak_label.text if k.vak_label != null else ""
	return ""

## Answer the question that is open, correctly, in the way its band allows.
func _antwoord_goed() -> bool:
	var s := _spel()
	if s == null:
		return false
	var juist: int = s.juist()
	var st := _stand()
	var stap := str(st.get("stap", ""))
	# The opening question is a number; only the crate question of group 3 is
	# a choice of kinds.
	if stap == "vraag0":
		return _toets(juist)
	if int(st.get("band", 3)) == 3:
		return _kies(str(WasSoorten.soort(juist)["id"]))
	return _toets(juist)

## The opening question stands between the child and the pile: get past it.
func _door_de_opening() -> bool:
	if str(_stand().get("stap", "")) != "vraag0":
		return true
	return _antwoord_goed()

# ------------------------------------------------------------- aanmelding

## The registration of games-b.md §4.2, field by field.
func test_aanmelding_en_taak() -> void:
	waar(Games.lijst().has(ID), "de mapscan vindt res://games/was")
	var def := Games.definitie(ID)
	gelijk(def.get("naam", ""), "Wasmandtoren", "naam")
	gelijk(def.get("kamer", ""), "wasserij", "kamer")
	gelijk(def.get("stub", true), false, "geen stub")
	waar(not def.has("wens"), "was lost geen wens in")
	var hs: Dictionary = def.get("hotspot", {})
	gelijk(hs.get("obj", ""), "tobbe", "hotspot hangt aan de tobbe")
	gelijk(hs.get("icoon", ""), "🧺", "hotspot icoon")
	gelijk(hs.get("label", ""), "Was sorteren", "hotspot label")
	gelijk(int(hs.get("hoog", 0)), 14, "hotspot hoogte")
	gelijk(int(hs.get("dx", 0)), -20, "dx")
	gelijk(int(hs.get("dz", 0)), -20, "dz")
	var taak: Dictionary = def.get("taak", {})
	gelijk(taak.get("icoon", ""), "🧺", "taak icoon")
	gelijk(taak.get("tekst", ""), "Was sorteren", "taak tekst")
	gelijk(int(taak.get("prio", 0)), 8, "taak prio 8")
	waar(Ui.keur_taak("was", str(taak.get("tekst", ""))), "taakkaartje <= 6 woorden")
	var slot = def.get("unlock", null)
	waar(slot is Callable, "er is een unlock")
	waar(not slot.call(0, 3), "met nul gasten nog niet")
	waar(slot.call(1, 3), "met een gast wel")
	waar(slot.call(9, 5), "en met negen ook")
	# the hotspot really lands on the pile, not on the tub
	var tobbe := World.mik("tobbe", "wasserij")
	gelijk(int(tobbe.get("x", 0)) + int(hs["dx"]), 60, "startknop op x 60")
	gelijk(int(tobbe.get("z", 0)) + int(hs["dz"]), 54, "startknop op z 54")

## The generators are frozen and live in `Sommen`; the game may not have its
## own copy (architecture.md §1.1 F1, §2.2).
func test_de_getallen_komen_uit_sommen() -> void:
	_licht_op()
	for band in BANDEN:
		for dag in [1, 2, 3]:
			_wereld(band, dag)
			waar(Games.start(ID), "was start bij band %d dag %d" % [band, dag])
			var st := _stand()
			var q := Sommen.Was.recept(int(BAND_OPZET[band][0]), band, dag)
			for sleutel in ["band", "N", "dag", "k", "r", "T", "per", "m"]:
				gelijk(int(st.get(sleutel, -1)), int(q[sleutel]),
					"band %d dag %d: %s" % [band, dag, sleutel])
			gelijk(str(st.get("doel", [])), str(q["blok"]), "de stapels")
			gelijk(str(st.get("rij", [])), str(q["rij"]), "de rij op de berg")
			# the piles are always different, so "which is the highest" has one
			# answer (games-b.md §4.3)
			var gezien := {}
			for v in st["doel"]:
				waar(not gezien.has(int(v)), "elke stapel is anders (band %d)" % band)
				gezien[int(v)] = true
			Games.stop()
	_licht_af()

# --------------------------------------------------------------- de beurt

## One whole turn per band, tap by tap.  Band 3 has one question, 4 and 5 have
## two; the star falls once, for taking part.
func test_beurt_per_band() -> void:
	_licht_op()
	for band in BANDEN:
		_wereld(band)
		var sterren_voor := int(State.s["sterren"])
		waar(Games.start(ID), "start band %d" % band)
		var st := _stand()
		var per := int(st["per"])
		gelijk(per, 2 if band == 5 else 1, "per tik bij band %d" % band)
		var bron := Ui.bron_van("ws_berg")
		waar(bron != null, "de berg hangt er bij de start (band %d)" % band)
		if band == 5:
			# group 5 opens with a sum about the pile: it says how many pieces,
			# and it is not yours to touch yet
			if bron != null:
				gelijk(bron.text, "🧹 %d" % int(st["T"]),
					"tijdens de opening doet het cijfer op de berg het alleen")
				gelijk(int(bron.aantal), 0, "en is nog niet sleepbaar")
			gelijk(str(st["stap"]), "vraag0", "groep 5 begint met de opening")
			waar(_tik("ws_berg"), "de berg staat er")
			waar(int(_stand()["hand"]) < 0, "maar er komt niets in de hand")
			waar(_antwoord_goed(), "opening beantwoord")
			await _spoel(1.0)
			gelijk(str(_stand()["stap"]), "sorteren", "en dan pas mag er gesorteerd worden")
			gelijk(Ui.bron_van("ws_berg").text, "🧹 %d nog te sorteren" % int(st["T"]),
				"tijdens het sorteren heeft de berg zijn woorden terug")
		else:
			# groups 3 and 4 sort at once, and the pile never says how much
			gelijk(str(st["stap"]), "sorteren", "band %d begint met sorteren" % band)
			waar(Hits.spot("ws_vraag") == null, "zonder vraagkaart (band %d)" % band)
			if bron != null:
				gelijk(bron.text, "🧹 nog te sorteren",
					"de berg noemt geen aantal (band %d)" % band)
		# wave 2: the pile sorts itself — a tap on it puts nothing in a hand,
		# and the chart grows while the child watches, without one tap
		_tik("ws_berg")
		gelijk(int(_stand()["hand"]), -1, "een tik op de berg pakt niets (band %d)" % band)
		waar(Hits.spot("ws_hand") == null, "er is geen handwolkje (band %d)" % band)
		if Ui.bron_van("ws_berg") != null:
			gelijk(int(Ui.bron_van("ws_berg").aantal), 0, "de berg is niet sleepbaar (band %d)" % band)
		waar(await _wacht_tot_stap("vraag1"), "de berg sorteert zichzelf (band %d)" % band)
		st = _stand()
		gelijk(str(st["stap"]), "vraag1", "de berg is leeg, de vraag komt (band %d)" % band)
		gelijk(int(st["i"]), (st["rij"] as Array).size(), "alles gesorteerd")
		var som := 0
		for v in st["vak"]:
			som += int(v)
		gelijk(som * per, int(st["T"]), "elk stuk zit in een krat")
		gelijk(str(st["vak"]), str(st["doel"]), "en in de goede krat")
		# question 1
		waar(Hits.spot("ws_vraag") != null, "de vraagkaart staat er (band %d)" % band)
		waar(_antwoord_goed(), "vraag 1 beantwoord (band %d)" % band)
		st = _stand()
		if band == 3:
			gelijk(str(st["stap"]), "af", "band 3 heeft geen tweede vraag")
		else:
			gelijk(str(st["stap"]), "vraag2", "band %d krijgt een tweede vraag" % band)
			await _spoel(1.0)
			waar(_antwoord_goed(), "vraag 2 beantwoord (band %d)" % band)
			st = _stand()
			gelijk(str(st["stap"]), "af", "en dan is het af (band %d)" % band)
		gelijk(int(st["ster"]), 1, "de ster is gevallen (band %d)" % band)
		gelijk(int(State.s["sterren"]), sterren_voor + 1, "precies een ster erbij")
		# the end card, without a button (wave 2): it closes by itself
		await _spoel(1.0)
		gelijk(_kaart_tekst("regel"), "✅ Alles gesorteerd!", "de eindkaart (band %d)" % band)
		waar(Hits.spot("ws_vraag_keuzes") == null, "zonder knop eronder")
		gelijk(_kaart_tekst("vak"), "✓", "met een vinkje in het vakje, geen leeg vakje (band %d)" % band)
		await _spoel(SpelWas.AF_S)
		gelijk(Games.actief(), "", "het spel sluit zichzelf (band %d)" % band)
	_licht_af()

## N8: group 5 opens with a question about the pile, before a single piece
## moves — the pile says how many pieces, the card asks how many blocks.  Four
## buttons under the card, and the pile may be looked at but not emptied
## (`aantal: 0` is what makes a source undraggable).  Groups 3 and 4 sort at
## once (owner, 2026-09-24: "Haal die hints weg"): their opening question could
## only be answered by reading the number on the pile.
func test_alleen_groep_5_begint_met_een_vraag() -> void:
	_licht_op()
	for band in BANDEN:
		_wereld(band)
		waar(Games.start(ID), "start band %d" % band)
		var st := _stand()
		var berg := Ui.bron_van("ws_berg")
		waar(berg != null, "de berg is te zien (band %d)" % band)
		if band != 5:
			gelijk(str(st["stap"]), "sorteren", "band %d sorteert meteen" % band)
			waar(Hits.spot("ws_vraag") == null, "geen vraag over de berg (band %d)" % band)
			if berg != null:
				gelijk(int(berg.aantal), 0, "de berg sorteert zichzelf: niet sleepbaar (band %d)" % band)
			Games.stop()
			continue
		gelijk(str(st["stap"]), "vraag0", "band 5 begint met de opening")
		var goed := int(int(st["T"]) / 2)
		gelijk(int(_spel().juist()), goed, "band 5 vraagt om %d blokjes" % goed)
		gelijk(_kaart_tekst("regel"), "📊 Hoeveel blokjes worden dat?", "de vraag zelf")
		var strook := Hits.spot("ws_vraag_keuzes")
		waar(strook != null, "er hangt een keuzestrook onder de kaart")
		if strook != null:
			gelijk(strook.knoop.get_node("Rij").get_child_count(), 4, "vier keuzes")
			waar(strook.knoop.get_node_or_null("Rij/Kn%d" % goed) != null,
				"en het goede getal staat ertussen")
		if berg != null:
			gelijk(int(berg.aantal), 0, "maar de berg is niet sleepbaar")
		waar(_tik("ws_berg"), "de berg staat er")
		waar(int(_stand()["hand"]) < 0, "en er komt niets in de hand")
		Games.stop()
	_licht_af()

## The owner, 2026-09-24: "Haal die hints weg".  Halfway there used to be
## `Hoeveel liggen er nog?`, answered by the number on the pile.  Now the
## sorting runs through to the chart in every band, and in groups 3 and 4 the
## pile never says how many pieces lie on it, not in its tooltip either: in
## group 4 that count is the answer to `Hoeveel stuks samen?` at the end.
func test_geen_tussensom_en_geen_aantal_op_de_berg() -> void:
	_licht_op()
	for band in BANDEN:
		_wereld(band)
		waar(Games.start(ID), "start band %d" % band)
		waar(_door_de_opening(), "de opening, als die er is (band %d)" % band)
		# the pile sorts itself (wave 2): watch it, frame by frame
		var stappen: Array[String] = []
		var boom := Engine.get_main_loop() as SceneTree
		var eind := Time.get_ticks_msec() + 9000
		var gezien := -1
		while Time.get_ticks_msec() < eind:
			var st := _stand()
			if st.is_empty():
				break
			if stappen.is_empty() or stappen[stappen.size() - 1] != str(st["stap"]):
				stappen.append(str(st["stap"]))
			if str(st["stap"]) != "sorteren" and str(st["stap"]) != "vraag0":
				break
			var berg := Ui.bron_van("ws_berg")
			if band != 5 and berg != null and int(st["i"]) != gezien:
				gezien = int(st["i"])
				gelijk(berg.text, "🧹 nog te sorteren",
					"band %d, stuk %d: geen aantal op de berg" % [band, gezien])
				gelijk(berg.tooltip_text, "berg met was, kijk er goed naar",
					"band %d, stuk %d: en ook niet in de titel" % [band, gezien])
			await boom.process_frame
		waar(not stappen.has("vraagT"), "band %d: geen tussensom" % band)
		gelijk(str(_stand()["stap"]), "vraag1",
			"band %d: de berg is leeg en de vraag over het diagram komt" % band)
		Games.stop()
	_licht_af()

## A save from before 2026-09-24 can stand on a question that is gone: the
## opening of groups 3 and 4, or the one halfway.  It picks up the sorting.
func test_een_oude_opslag_sorteert_verder() -> void:
	_licht_op()
	_wereld(4)
	waar(Games.start(ID), "band 4 start")
	for _q in 2:
		_spel().sorteer_een()
	Games.stop()
	for oud in ["vraag0", "vraagT"]:
		var bewaard: Dictionary = State.spel_data(ID).get("stand", {})
		waar(not bewaard.is_empty(), "%s: er is een opgeslagen beurt" % oud)
		bewaard["stap"] = oud
		bewaard["tussen"] = 1
		Games.start(ID)
		gelijk(str(_stand()["stap"]), "sorteren", "%s: hij sorteert verder" % oud)
		gelijk(int(_stand()["i"]), 2, "%s: waar hij was" % oud)
		waar(Hits.spot("ws_vraag") == null, "%s: zonder vraagkaart" % oud)
		Games.stop()
	_licht_af()

## The wording of every question, per band, verbatim (games-b.md §4.8, §4.10).
func test_de_vragen_letterlijk() -> void:
	_licht_op()
	for band in BANDEN:
		_wereld(band)
		Games.start(ID)
		_sorteer_alles()
		var st := _stand()
		var vak: Array = st["vak"]
		var h := 0
		var l := 0
		for i in vak.size():
			if int(vak[i]) > int(vak[h]):
				h = i
			if int(vak[i]) < int(vak[l]):
				l = i
		var hn := str(WasSoorten.soort(h)["naam"])
		var ln := str(WasSoorten.soort(l)["naam"])
		var per := int(st["per"])
		if band == 3:
			gelijk(_kaart_tekst("regel"), "📊 Welke stapel is het hoogst?", "band 3 vraag")
			gelijk(Hits.spot("ws_vraag_keuzes").knoop.tooltip_text, "kies een stapel",
				"strooktitel")
			waar(Hits.spot("ws_vraag_keuzes").knoop.get_node_or_null("Rij/Kn%d" % (int(vak[h]) * per)) == null,
				"band 3 kiest een stapel, geen getal")
		elif band == 4:
			gelijk(_kaart_tekst("regel"), "📊 Hoeveel meer %s dan %s?" % [hn, ln], "band 4 vraag 1")
			gelijk(_kaart_tekst("som"), "%d − %d =" % [int(vak[h]) * per, int(vak[l]) * per],
				"de sombalk met het echte minteken")
			waar(Hits.spot("ws_vraag_pad") == null, "band 4 heeft geen cijferpad meer")
			var strook := Hits.spot("ws_vraag_keuzes")
			waar(strook != null and strook.knoop.get_node("Rij").get_child_count() == 4,
				"band 4 kiest uit vier getallen")
			waar(strook != null and strook.knoop.get_node_or_null("Rij/Kn%d" % _spel().juist()) != null,
				"en het goede staat ertussen")
			_antwoord_goed()
			await _spoel(1.0)
			gelijk(_kaart_tekst("regel"), "📊 Hoeveel stuks samen?", "band 4 vraag 2")
			var delen: Array[String] = []
			for v in vak:
				delen.append(str(int(v) * per))
			gelijk(_kaart_tekst("som"), "%s =" % " + ".join(delen), "de optelbalk")
		else:
			gelijk(_kaart_tekst("regel"), "📊 Hoeveel %s zijn het?" % hn, "band 5 vraag 1")
			gelijk(_kaart_tekst("regel2"), "📦 Elk blokje is 2 stuks", "de legenda op de kaart")
			gelijk(_kaart_tekst("som"), "", "band 5 heeft geen sombalk")
			_antwoord_goed()
			await _spoel(1.0)
			gelijk(_kaart_tekst("regel"), "📊 Hoeveel meer %s dan %s?" % [hn, ln], "band 5 vraag 2")
		Games.stop()
	_licht_af()

## The legend bubble stands there the whole of the sorting in group 5, and never
## when the turn is over (games-b.md §4.9).
func test_legenda_bij_band_5() -> void:
	_licht_op()
	_wereld(5)
	Games.start(ID)
	waar(_door_de_opening(), "eerst de opening, dan het sorteren")
	await _spoel(1.0)
	var w := Hits.spot("ws_legenda")
	waar(w != null, "het legendawolkje staat er tijdens het sorteren")
	if w != null:
		gelijk((w.knoop as UiWolk).zeg_label.text, "Elk blokje is 2 stuks", "de legenda")
		gelijk((w.knoop as UiWolk).icoon_label.text, "📦", "met het pictogram")
	_sorteer_alles()
	waar(Hits.spot("ws_legenda") == null,
		"bij de vraag staat de legenda op de kaart, dus niet ook nog als wolkje")
	Games.stop()
	_licht_af()
	# band 3 and 4 sort one piece at a time: no legend at all
	_licht_op()
	_wereld(4)
	Games.start(ID)
	waar(Hits.spot("ws_legenda") == null, "band 4 heeft geen legenda nodig")
	_licht_af()

# ------------------------------------------------- fout, geen hulp, ster

## The owner, 2026-09-24: "Nee geef geen hulp na fouten.  Kinderen moeten zelf
## leren rekenen.  Fout antwoord kiezen moet niet beloond worden met hulp maar
## juist een teleurgesteld dier."  In every band, one, two and three wrong
## answers on the chart: the strip pauses with `🔄 Nog een keer` at the card
## (this game has no animal of the turn), and after the pause the card, the
## crates and the chart are exactly what they were — no counting line, no
## "kijk naar de hoogste stapel", no ghost numbers on the crates.  Never
## punishing either, and the right answer still works.
func test_geen_hulp_na_een_fout() -> void:
	_licht_op()
	for band in BANDEN:
		_wereld(band)
		Games.start(ID)
		var sterren_voor := int(State.s["sterren"])
		_sorteer_alles()
		var st := _stand()
		var vak: Array = st["vak"]
		var l := 0
		for i in vak.size():
			if int(vak[i]) < int(vak[l]):
				l = i
		var fout_antwoord := func() -> void:
			if band == 3:
				_kies(str(WasSoorten.soort(l)["id"]))     # the lowest pile, never right
			else:
				_toets_fout()
		var voor := beeld(ID)
		waar(voor.has("ws_vraag") and voor.has("ws_vraag_keuzes"),
			"band %d: het beeld kent de kaart en de strook" % band)
		var regel := _kaart_tekst("regel")
		for keer in 3:
			var wat := "band %d, misser %d" % [band, keer + 1]
			fout_antwoord.call()
			st = _stand()
			gelijk(int(st["missers"]), keer + 1, "%s: geteld" % wat)
			gelijk(str(st["stap"]), "vraag1", "%s: de vraag blijft staan" % wat)
			waar(mis_wolk("ws_vraag"), "%s: 🔄 Nog een keer bij de kaart" % wat)
			var strook := Hits.spot("ws_vraag_keuzes")
			waar(strook != null and (strook.knoop as UiKeuzes).op_slot,
				"%s: de strook staat even op slot" % wat)
			gelijk(_kaart_tekst("hulp"), "", "%s: geen hulpregel" % wat)
			for i in int(st["m"]):
				waar(Hits.spot("ws_sp%d" % i) == null, "%s: geen spookcijfer op krat %d" % [wat, i])
			waar(Hits.spot("ws_sp_berg") == null, "%s: en niet op de berg" % wat)
			await _wacht_mispauze()
			niets_erbij(voor, beeld(ID), wat)
			gelijk(_kaart_tekst("regel"), regel, "%s: dezelfde vraag" % wat)
		# never punishing: no star was taken away, nothing was reset
		gelijk(int(State.s["sterren"]), sterren_voor, "geen ster erbij en geen ster eraf")
		gelijk(str(_stand()["vak"]), str(vak), "het diagram staat er nog precies zo")
		waar(_antwoord_goed(), "band %d: het goede antwoord komt er alsnog door" % band)
		Games.stop()
	_licht_af()

## The opening question about the pile (group 5), wrong three times: the same
## pause, and no ghost number on the pile either.
func test_geen_hulp_bij_de_openingsvraag() -> void:
	_licht_op()
	_wereld(5)
	Games.start(ID)
	gelijk(str(_stand().get("stap", "")), "vraag0", "de beurt opent met de vraag over de berg")
	var voor := beeld(ID)
	for keer in 3:
		var wat := "opening, misser %d" % (keer + 1)
		waar(_toets_fout(), "%s: een fout getal" % wat)
		waar(mis_wolk("ws_vraag"), "%s: 🔄 Nog een keer bij de kaart" % wat)
		gelijk(_kaart_tekst("hulp"), "", "%s: geen telregel" % wat)
		waar(Hits.spot("ws_sp_berg") == null, "%s: geen spookcijfer op de berg" % wat)
		await _wacht_mispauze()
		niets_erbij(voor, beeld(ID), wat)
	waar(_antwoord_goed(), "het goede antwoord opent de berg")
	gelijk(str(_stand().get("stap", "")), "sorteren", "en dan wordt er gesorteerd")
	_licht_af()

## Wave 2: the pile sorts itself, and a finger is no step of it.  A tap on a
## crate or on the pile moves nothing, makes no sound and shows no miss; then,
## without a single tap, every piece lands in its own crate, one by one, with
## a plop, and the chart is exactly the recipe.  (Before wave 2 this test drove
## a wrong crate by hand: that cannot happen any more.)
func test_mis_sorteren_is_niet_straffend() -> void:
	_licht_op()
	_wereld(4)
	Games.start(ID)
	waar(_door_de_opening(), "eerst de opening, dan de berg")
	var voor := _stand()
	var berg_voor := int(voor["i"])
	var hoor := Snd.luister(func() -> void:
		_tik("ws_k0")
		_tik("ws_berg"))
	# only the click every button makes (`Hits`); the game itself says nothing
	for naam in hoor:
		gelijk(naam, "tik", "een tik op een krat of de berg: geen eigen geluid (%s)" % str(hoor))
	var na1 := _stand()
	gelijk(int(na1["i"]), berg_voor, "er gaat niets van de berg af")
	gelijk(int(na1["hand"]), -1, "en er komt niets in de hand")
	gelijk(str(na1["vak"]), str(voor["vak"]), "geen blokje erbij")
	waar(Hits.spot(Ui.MIS_WOLK + "was_krat0") == null, "en geen 🔄 bij de krat")
	gelijk(int(State.s["sterren"]), 0, "en geen ster eraf")
	# one step of the pile by itself: a plop, one piece off, into ITS crate
	var soort := int(voor["rij"][berg_voor])
	var hoor2 := Snd.luister(func() -> void: _spel().sorteer_een())
	waar(hoor2.has("plof"), "de was valt met een plof in de krat (%s)" % str(hoor2))
	var na3 := _stand()
	gelijk(int(na3["i"]), berg_voor + 1, "nu gaat er een stuk van de berg af")
	gelijk(int(na3["vak"][soort]), int(voor["vak"][soort]) + 1, "en komt er een blokje bij")
	waar(await _wacht_tot_stap("vraag1"), "de rest sorteert zichzelf")
	gelijk(str(_stand()["vak"]), str(_stand()["doel"]), "elk stuk in de goede krat")
	_licht_af()

## Wave 2: nothing is dragged from the pile any more — it carries no load, and
## a drop on a crate puts nothing in it.
func test_slepen_van_de_berg_naar_de_krat() -> void:
	_licht_op()
	_wereld(3)
	Games.start(ID)
	waar(_door_de_opening(), "eerst de opening")
	Hits.plaats()
	var bron := Ui.bron_van("ws_berg")
	waar(bron != null, "de berg staat er")
	if bron != null:
		gelijk(int(bron.aantal), 0, "de berg geeft niets mee")
	var vp := _laag.get_viewport()
	_laag.force_drag({"sleep": "proef"}, null)
	var sleep = bron._get_drag_data(Vector2.ZERO) if bron != null else null
	vp.gui_cancel_drag()
	waar(sleep == null, "een sleep van de berg begint niet")
	var st := _stand()
	var soort := int(st["rij"][int(st["i"])])
	var doel := Hits.spot("ws_k%d" % soort)
	if doel != null and doel.vangvlak != null:
		doel.vangvlak._drop_data(Vector2.ZERO, {"sleep": "krat"})
	var na := _stand()
	gelijk(int(na["i"]), int(st["i"]), "een losse drop sorteert niets")
	gelijk(str(na["vak"]), str(st["vak"]), "geen blokje erbij")
	gelijk(int(na["hand"]), -1, "de hand is leeg")
	_licht_af()

## The star hangs on taking part, never on being right (F5): three misses and
## then the answer still gives exactly one star.
func test_ster_is_voor_meedoen() -> void:
	_licht_op()
	_wereld(3)
	Games.start(ID)
	var voor := int(State.s["sterren"])
	_sorteer_alles()
	var st := _stand()
	var l := 0
	for i in (st["vak"] as Array).size():
		if int(st["vak"][i]) < int(st["vak"][l]):
			l = i
	for _p in 3:
		_kies(str(WasSoorten.soort(l)["id"]))
		await _wacht_mispauze()
	gelijk(int(State.s["sterren"]), voor, "missen levert geen ster op, maar kost er ook geen")
	_antwoord_goed()
	gelijk(int(State.s["sterren"]), voor + 1, "meedoen levert er precies een op")
	gelijk(str(_stand()["ster"]), "1", "en maar een keer")
	_antwoord_goed()
	gelijk(int(State.s["sterren"]), voor + 1, "nog een tik geeft geen tweede ster")
	_licht_af()

# ---------------------------------------------------------------- herstel

## The turn survives a reload: `stop()` writes the state to `ctx.data()` and a
## fresh `start()` picks it up — the misses too, but no help comes with them.
func test_herstel_uit_ctx_data() -> void:
	_licht_op()
	_wereld(4)
	Games.start(ID)
	waar(_door_de_opening(), "eerst de opening")
	gelijk(str(_stand()["stap"]), "sorteren", "en dan de berg")
	# three pieces sorted (the pile's own steps) and stop halfway
	for _q in 3:
		_spel().sorteer_een()
	var halverwege := _stand()
	gelijk(int(halverwege["i"]), 3, "drie stukken gesorteerd")
	Games.stop()
	var bewaard: Dictionary = State.spel_data(ID).get("stand", {})
	gelijk(int(bewaard.get("i", -1)), 3, "de stand staat in ctx.data()")
	Games.start(ID)
	var terug := _stand()
	gelijk(int(terug["i"]), 3, "en komt terug na een herstart")
	gelijk(str(terug["rij"]), str(halverwege["rij"]), "dezelfde rij")
	gelijk(str(terug["vak"]), str(halverwege["vak"]), "dezelfde vakken")
	# now to the question, three misses, and reload again
	_sorteer_alles()
	var st2 := _stand()
	var l := 0
	for i in (st2["vak"] as Array).size():
		if int(st2["vak"][i]) < int(st2["vak"][l]):
			l = i
	for _p in 3:
		_toets_fout()
		await _wacht_mispauze()
	gelijk(int(_stand()["missers"]), 3, "drie missers verdiend")
	Games.stop()
	Games.start(ID)
	var na := _stand()
	gelijk(str(na["stap"]), "vraag1", "de vraag staat er meteen weer")
	gelijk(int(na["missers"]), 3, "en de missers zijn niet weggegooid")
	waar(Hits.spot("ws_sp0") == null, "maar er komen geen spookcijfers terug (2026-09-24)")
	gelijk(_kaart_tekst("hulp"), "", "en geen hulpregel")
	# wave 2 (R2): a question that was missed is still open on another day —
	# it comes back unchanged, chart and all
	var regel := _kaart_tekst("regel")
	Games.stop()
	State.s["dag"] = int(State.s["dag"]) + 1
	Games.start(ID)
	var nog := _stand()
	gelijk(str(nog["stap"]), "vraag1", "een nieuwe dag: de open vraag blijft")
	gelijk(str(nog["vak"]), str(na["vak"]), "met hetzelfde diagram")
	gelijk(_kaart_tekst("regel"), regel, "en dezelfde zin")
	# ... until it is answered; a turn without an open miss is NOT reused on
	# another day
	waar(_antwoord_goed(), "het goede antwoord")
	Games.stop()
	State.s["dag"] = int(State.s["dag"]) + 1
	Games.start(ID)
	var vers := _stand()
	gelijk(int(vers["i"]), 0, "een nieuwe dag geeft een nieuwe beurt")
	gelijk(int(vers["missers"]), 0, "zonder oude missers")
	_licht_af()

## `stop()` leaves the world clean: no hotspot, no loose decor, no borrowed
## button (games-b.md §4.11).
func test_stop_laat_de_wereld_schoon() -> void:
	_licht_op()
	_wereld(5)
	Games.start(ID)
	_tik("ws_berg")
	waar(not World.decor_lijst("wasserij").is_empty(), "er staat eigen decor")
	waar(Hits.spot("ws_berg") != null, "en er hangen knoppen")
	Games.stop()
	# the resting pile (`Games.RUST`) comes back; the game's own decor does not
	gelijk(World.decor_lijst("wasserij").filter(func(d): return d["door"] == ID).size(), 0,
		"al het eigen decor is weg")
	for id in ["ws_berg", "ws_hand", "ws_vraag", "ws_vraag_pad", "ws_vraag_keuzes",
			"ws_legenda", "ws_k0", "ws_k1", "ws_k2", "ws_k3", "ws_sp0"]:
		waar(Hits.spot(id) == null, "hotspot %s is opgeruimd" % id)
	gelijk(Games.actief(), "", "er draait niets meer")
	_licht_af()

## The turn does not only have to survive `ctx.data()` — it has to survive the
## real save, where JSON hands every number back as a float.  This writes the
## state through `JSON.stringify`, reads it back, and plays on.
##
## With `WAS_OPSLAG=<map>` set it also writes that exact document to disk: that
## is the starting position the browser proof seeds into IndexedDB, so the
## fixture can never drift from what `State.lees()` accepts.
func test_opslag_overleeft_json() -> void:
	_licht_op()
	for band in BANDEN:
		_wereld(band)
		Games.start(ID)
		for _q in 2:
			_spel().sorteer_een()          # band 5 stands on its opening: no step
		var voor := _stand()
		Games.stop()
		var tekst := JSON.stringify({"v": State.VERSIE, "s": State.s})
		var doc = JSON.parse_string(tekst)
		waar(typeof(doc) == TYPE_DICTIONARY, "band %d: de opslag is geldige JSON" % band)
		State.s = (doc as Dictionary)["s"]
		Games.start(ID)
		var na := _stand()
		gelijk(int(na["i"]), int(voor["i"]), "band %d: de beurt komt uit JSON terug" % band)
		gelijk(str(na["vak"]), str(voor["vak"]), "band %d: dezelfde vakken" % band)
		gelijk(str(na["rij"]), str(voor["rij"]), "band %d: dezelfde rij" % band)
		gelijk(int(na["per"]), int(voor["per"]), "band %d: dezelfde maat" % band)
		Games.stop()
		if OS.has_environment("WAS_OPSLAG"):
			var pad := "%s/opslag-band%d.json" % [OS.get_environment("WAS_OPSLAG"), band]
			var f := FileAccess.open(pad, FileAccess.WRITE)
			if f != null:
				f.store_string(JSON.stringify({"v": State.VERSIE, "s": State.s}))
				f.close()
				print("[was] opslag geschreven: ", pad)
	_licht_af()

# ------------------------------------------------------------ de kindtekst

## F3: every literal of games-b.md §4.10 stands in this game's own source.
func test_kindtekst_staat_letterlijk_in_de_bron() -> void:
	var bron := ""
	for pad in ["res://games/was/spel.gd", "res://games/was/soorten.gd"]:
		var f := FileAccess.open(pad, FileAccess.READ)
		waar(f != null, "bestand %s bestaat" % pad)
		if f != null:
			bron += f.get_as_text()
			f.close()
	for zin in KINDTEKST:
		waar(bron.contains(zin), 'de zin "%s" staat letterlijk in de bron' % zin)
	# the composed ones, straight off the frozen table of kinds
	for i in WasSoorten.LIJST.size():
		gelijk("een %s" % str(WasSoorten.soort(i)["ev"]), HAND_EEN[i],
			"in je hand, per 1, soort %d" % i)
		gelijk("twee %s" % str(WasSoorten.soort(i)["naam"]), HAND_TWEE[i],
			"in je hand, per 2, soort %d" % i)
	for per in [1, 2]:
		gelijk("pak %d" % per, GREEP[per - 1], "de handgreep bij per %d" % per)
	# the real minus sign, not a hyphen (games-b.md leeswijzer)
	waar(bron.contains("%d − %d ="), "de sombalk gebruikt het echte minteken U+2212")
	# the help ladder is gone (owner, 2026-09-24)
	for weg in ["tel de blokjes", "kijk naar de hoogste stapel", "tel_mee", "_spook"]:
		waar(not bron.contains(weg), 'de hulp "%s" staat niet meer in de bron' % weg)
	# and so are the two questions the number on the pile answered by itself
	for weg in ["Hoeveel stuks liggen er?", "Hoeveel liggen er nog?"]:
		waar(not bron.contains('"%s"' % weg), 'de vraag "%s" is weg' % weg)
	# and the font really carries every character of them
	for zin in KINDTEKST + HAND_EEN + HAND_TWEE + GREEP \
			+ ["🧦", "🧣", "🧺", "🧸", "🧹", "📊", "📦", "✅", "👍"]:
		gelijk(str(Ui.mist_tekens(str(zin))), "[]",
			'elk teken van "%s" zit in het lettertype' % str(zin))

## F4: every sentence the card can carry fits the budget (<= 8 words, <= 40
## characters), for every combination of kinds the generator can produce.
func test_elke_kaartzin_past_in_f4() -> void:
	var zinnen: Array[String] = ["Welke stapel is het hoogst?", "Hoeveel stuks samen?",
		"Alles gesorteerd!", "📦 Elk blokje is 2 stuks", "Hoeveel blokjes worden dat?"]
	for a in WasSoorten.LIJST:
		zinnen.append("Hoeveel %s zijn het?" % str(a["naam"]))
		for b in WasSoorten.LIJST:
			if a != b:
				zinnen.append("Hoeveel meer %s dan %s?" % [str(a["naam"]), str(b["naam"])])
	for zin in zinnen:
		waar(Ui.keur_regel("was", zin), 'de zin "%s" past in F4 (%d tekens)' % [zin, zin.length()])
		waar(zin.length() <= 40, '"%s" is %d tekens' % [zin, zin.length()])
	# the longest one the spec names
	waar(zinnen.has("Hoeveel meer knuffels dan doeken?"), "de langste zin komt voor")
	gelijk("Hoeveel meer knuffels dan doeken?".length(), 33, "en is 33 tekens")

# ------------------------------------------------------------- de modellen

## The two models are the game's own, namespaced with the game id, and never
## overwrite a world model (architecture.md §13 Q-X1-11).
func test_eigen_modellen() -> void:
	_licht_op()
	_wereld(5)
	Games.start(ID)
	waar(Art.heeft_model("was_krat"), "was_krat is geregistreerd")
	waar(Art.heeft_model("was_berg"), "was_berg is geregistreerd")
	waar(not Art.is_wereldmodel("was_krat"), "en is geen wereldmodel")
	# the stack stays under the wall of the wasserij (52 voxels)
	var vox := Art.model("was_krat", {"soort": 0, "n": 99, "voet": 18, "stap": 3})
	var hoog := 0
	for p in vox:
		hoog = maxi(hoog, int(p["y"]))
	waar(hoog < 52, "een kapot getal gaat niet door de wand (%d)" % hoog)
	# every block is 2 voxels of colour plus 1 of dark seam, so they are countable
	var een := Art.model("was_krat", {"soort": 0, "n": 1, "voet": 0, "stap": 3})
	var twee := Art.model("was_krat", {"soort": 0, "n": 2, "voet": 0, "stap": 3})
	gelijk(twee.size() - een.size(), een.size() - Art.model("was_krat",
		{"soort": 0, "n": 0, "voet": 0, "stap": 3}).size(), "elk blokje kost even veel voxels")
	# an empty pile draws nothing at all
	gelijk(Art.model("was_berg", {"n": 0}).size(), 0, "een lege berg heeft geen plaatje")
	waar(Art.model("was_berg", {"n": 4}).size() > 0, "een volle berg wel")
	gelijk(str(Art.model("was_berg", {"n": 6})), str(Art.model("was_berg", {"n": 6})),
		"dezelfde params geven dezelfde plukjes")
	_licht_af()

## The crates stand on one line of equal depth (games-b.md §4.4) — the table of
## the spec, crate by crate.
func test_kratten_staan_op_een_grondlijn() -> void:
	var tabel := {
		2: [[18, 48], [40, 26]],
		3: [[7, 59], [29, 37], [51, 15]],
		4: [[5, 61], [21, 45], [37, 29], [53, 13]],
	}
	var scene: PackedScene = load("res://games/was/spel.tscn")
	var knoop = scene.instantiate()
	for m in tabel:
		for i in int(m):
			var q: Vector2 = knoop._krat_plek(int(m), i)
			gelijk(int(q.x), int(tabel[m][i][0]), "krat %d van %d: x" % [i, m])
			gelijk(int(q.y), int(tabel[m][i][1]), "krat %d van %d: z" % [i, m])
			gelijk(int(q.x + q.y), 66, "en op de grondlijn x + z = 66")
	knoop.free()

# --------------------------------------------------- de indeling, gemeten

## The geometry `WasIndeling` computes has to be the geometry the baked plate
## really has — otherwise C1 and C2 are solved against a fantasy.  This checks
## the closed form against `World.vlak_van()`, the real plate.
func test_de_meetkunde_klopt_met_de_gebakken_plaat() -> void:
	_licht_op(Vector2(1000, 648))
	World.naar("wasserij")
	World.meet(Rect2(Vector2.ZERO, Vector2(1000, 648)))
	var sch := World.schaal()
	var k := float(sch["k"])
	var pad := float(Art.PAD) / float(sch["dicht"])
	for voet in [0, 6, 13, 18]:
		for stap in [2, 3]:
			for n in [2, 5, 8]:
				var vlak := World.vlak_van("was_krat", 29.0, 37.0, 0.0,
					{"soort": 0, "n": n, "voet": voet, "stap": stap})
				waar(vlak.size.y > 0.0, "de plaat bestaat (voet %d)" % voet)
				var vloer := World.mik_punt(29.0, 37.0, 0.0).y
				var voorspeld := WasIndeling.plaat_top(vloer, k, voet, stap, n) - pad
				waar(absf(voorspeld - vlak.position.y) <= 1.01,
					"plaat_top voorspelt de plaatbovenkant (voet %d stap %d n %d: %.2f tegen %.2f)"
						% [voet, stap, n, voorspeld, vlak.position.y])
				var blok := WasIndeling.blok_vlak(World.mik_punt(29.0, 37.0, 0.0),
					k, voet, stap, n)
				waar(vlak.grow(1.5).encloses(blok),
					"de blokjes liggen binnen de plaat (voet %d stap %d n %d)" % [voet, stap, n])
	_licht_af()

# ----------------------------------------------------- de echte wasserij

## The whole shell in a SubViewport, so the camera really centres the wasserij.
func _shell_op(maat: Vector2i, band: int) -> Dictionary:
	var boom := Engine.get_main_loop() as SceneTree
	_bewaard = State.s.duplicate(true)
	_scherm_voor = Ui._scherm if "_scherm" in Ui else Vector2.ZERO
	var vp := SubViewport.new()
	vp.size = maat
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	boom.root.add_child(vp)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var shell = scene.instantiate()
	shell.set_meta("geen_start", true)
	vp.add_child(shell)
	for _f in 4:
		await boom.process_frame
	_wereld(band)
	Hotel.start()
	for _f in 4:
		await boom.process_frame
	World.naar("wasserij")
	for _f in 2:
		await boom.process_frame
	return {"vp": vp, "shell": shell}

func _shell_af(h: Dictionary) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	if Games.actief() != "":
		Games.stop()
	Ui.naamplaten_leeg()
	Hits.wis_alles()
	World.decor_wis_alles()
	(h["vp"] as SubViewport).queue_free()
	await boom.process_frame
	Ui.registreer_lagen(null, null, null)
	if "_scherm" in Ui:
		Ui._scherm = _scherm_voor
	if not _bewaard.is_empty():
		State.s = _bewaard
		_bewaard = {}

func _spoel(seconden := 0.6) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var eind := Time.get_ticks_msec() + int(seconden * 1000.0)
	while Time.get_ticks_msec() < eind:
		await boom.process_frame

## THE gate of this ticket.  In four frame sizes and three bands, with the bar
## chart finished and the question card on screen:
##
##   * every crate carries a plate, and it stands ABOVE its crate (C1);
##   * that plate covers 0 % of any object, and overlaps nothing else;
##   * the card covers no block of the bar chart (C2);
##   * nothing is `krap` (no element fell back onto its aim point).
##
## 0 misses, counted and reported.
func test_kratplaatjes_zijn_zichtbaar_in_elk_kader() -> void:
	var missers := 0
	var gemeten := 0
	var krap_kaders := 0
	for maat in SCHERMEN:
		for band in BANDEN:
			var h: Dictionary = await _shell_op(maat, band)
			waar(Games.start(ID), "%s band %d: was start" % [str(maat), band])
			_sorteer_alles()
			await _spoel(0.4)
			var st := _stand()
			var ind: Dictionary = _spel().indeling()
			var wat := "%s band %d" % [str(maat), band]
			gelijk(str(st.get("stap", "")), "vraag1", "%s: de vraag staat er" % wat)
			# band 5 cannot be answered without knowing a block is two, so the
			# legend is on the card or a bubble on every frame that can hold it
			if band == 5:
				waar(bool(ind.get("legenda_zichtbaar", false)) or not bool(ind.get("c2", true)),
					"%s: de legenda staat op de kaart of als wolkje" % wat)
			if not bool(ind_c2(_spel())):
				# C1 won: then the bench must really be at its C1 maximum, so
				# nothing more could have been done for C2 (games-b.md §4.6)
				krap_kaders += 1
				var sch := World.schaal()
				var q1: Vector2 = _spel()._krat_plek(int(st["m"]), 0)
				var hoogste := 0
				for v in st["doel"]:
					hoogste = maxi(hoogste, int(v))
				var vmax := WasIndeling.voet_max(World.mik_punt(q1.x, q1.y, 0.0).y,
					float(sch["k"]), float(Art.PAD) / float(sch["dicht"]),
					_spel()._plaat_maat(int(st["m"])).y,
					int(_spel().indeling()["stap"]), hoogste)
				gelijk(int(_spel().indeling()["voet"]),
					clampi(vmax, WasSoorten.VOET_MIN, WasSoorten.VOET_MAX),
					"%s: C1 gaat voor, dus het bankje staat op zijn C1-maximum" % wat)
			var dbg := Hits.debug()
			var kader := World.kader_rect().size
			var m := int(st.get("m", 0))
			var kaart: Rect2 = dbg["ws_vraag"]["rect"] if dbg.has("ws_vraag") else Rect2()
			if OS.has_environment("WAS_DIAG"):
				var q0: Vector2 = _spel()._krat_plek(m, 0)
				print("[was] %s band %d kader=%s k=%.2f vloer=%.1f voet=%d stap=%d tier=%d c2=%s legenda=%s/%s kort=%s kaart=%s"
					% [str(maat), band, str(kader), float(World.schaal()["k"]),
						World.mik_punt(q0.x, q0.y, 0.0).y, int(ind["voet"]),
						int(ind["stap"]), int(ind["tier"]), str(ind.get("c2", true)),
						str(ind.get("legenda_op_kaart", false)), str(ind.get("legenda_wolk", false)),
						str(ind.get("berg_kort", false)), str(kaart)])
				for id2 in dbg.keys():
					print("[was]    %s op=%s rect=%s vlak=%s krap=%s laag=%d prio=%d"
						% [str(id2), str(dbg[id2]["op"]), str(dbg[id2]["rect"]),
							str(dbg[id2]["vlak"]), str(dbg[id2]["krap"]),
							int(dbg[id2]["laag"]), int(dbg[id2]["prio"])])
			for i in m:
				gemeten += 1
				var id := "ws_k%d" % i
				if not dbg.has(id):
					missers += 1
					fout("%s: krat %d heeft geen plaatje" % [wat, i])
					continue
				var d: Dictionary = dbg[id]
				var r: Rect2 = d["rect"]
				var vlak: Rect2 = d["vlak"]
				# C1 — the plate is above its crate, never under it, and it
				# touches no block of the bar
				var q0: Vector2 = _spel()._krat_plek(m, i)
				var bar := WasIndeling.krat_vlak(World.mik_punt(q0.x, q0.y, 0.0),
					float(World.schaal()["k"]), int(ind["voet"]), int(ind["stap"]),
					int(st["vak"][i]))
				if r.end.y > bar.position.y + 0.01:
					missers += 1
					fout("%s: plaatje van krat %d staat niet boven zijn staaf (%s tegen %s)"
						% [wat, i, str(r), str(bar)])
				var op_staaf := r.intersection(bar)
				if op_staaf.size.x > 0.001 and op_staaf.size.y > 0.001:
					missers += 1
					fout("%s: plaatje van krat %d dekt %.0f x %.0f van zijn staaf"
						% [wat, i, op_staaf.size.x, op_staaf.size.y])
				if bool(d["krap"]):
					missers += 1
					fout("%s: plaatje van krat %d viel terug op zijn mikpunt" % [wat, i])
				if not Rect2(Vector2.ZERO, kader).grow(0.5).encloses(r):
					missers += 1
					fout("%s: plaatje van krat %d valt buiten het kader %s"
						% [wat, i, str(r)])
				if r.size.x < 44.0 or r.size.y < 44.0:
					missers += 1
					fout("%s: plaatje van krat %d is te klein (%s)" % [wat, i, str(r)])
				# nothing else stands on it
				for ander in dbg.keys():
					if str(ander) == id:
						continue
					var rb: Rect2 = dbg[ander]["rect"]
					var snij := r.intersection(rb)
					if snij.size.x > 0.001 and snij.size.y > 0.001:
						missers += 1
						fout("%s: plaatje van krat %d en %s overlappen" % [wat, i, str(ander)])
				# C2 — the card covers no block of the bar chart.  The spec puts
				# C1 first when a frame cannot do both; the game says which case
				# it is in, and that claim is checked below.
				if bool(ind.get("c2", true)) and kaart.size.x > 0.0 and vlak.size.y > 0.0:
					var blok := WasIndeling.blok_vlak(World.mik_punt(q0.x, q0.y, 0.0),
						float(World.schaal()["k"]), int(ind["voet"]), int(ind["stap"]),
						int(st["vak"][i]))
					var s2 := kaart.intersection(blok)
					if s2.size.x > 1.0 and s2.size.y > 1.0:
						missers += 1
						fout("%s: de kaart dekt %.0f x %.0f van de blokjes van krat %d"
							% [wat, s2.size.x, s2.size.y, i])
			await _shell_af(h)
	gelijk(missers, 0, "%d plaatjes gekeurd in %d kaders x %d banden, %d missers"
		% [gemeten, SCHERMEN.size(), BANDEN.size(), missers])
	waar(gemeten >= SCHERMEN.size() * BANDEN.size() * 2, "er is echt gemeten (%d)" % gemeten)
	# and C2 really holds on the frames that can afford it
	waar(krap_kaders <= 2,
		"C1 hoefde maar in %d van de %d gevallen voor te gaan"
			% [krap_kaders, SCHERMEN.size() * BANDEN.size()])

## The definition of done: `Hits.dekking` is 0 % for every button on an object,
## in the four frame sizes of the ticket — during the sorting AND during the
## question, because the pile, the crates and the card are on screen at
## different moments.
func test_dekking_is_nul_in_vier_kaders() -> void:
	for maat in SCHERMEN:
		var h: Dictionary = await _shell_op(maat, 5)
		Games.start(ID)
		for fase in ["sorteren", "vraag"]:
			if fase == "vraag":
				_sorteer_alles()
				await _spoel(0.4)
			else:
				# the opening question comes first; this phase is the sorting
				waar(_door_de_opening(), "%s sorteren: de opening is beantwoord" % str(maat))
				await _spoel(1.0)
			var dbg := Hits.debug()
			var kader := World.kader_rect().size
			var knoppen := 0
			for id in dbg.keys():
				var spot := Hits.spot(str(id))
				if spot == null or spot.door != ID:
					continue          # the hotel's own buttons are test_hits.gd's job
				var d: Dictionary = dbg[id]
				var r: Rect2 = d["rect"]
				waar(not bool(d["krap"]),
					"%s %s: %s vond een echte plek" % [str(maat), fase, str(id)])
				waar(Rect2(Vector2.ZERO, kader).grow(0.5).encloses(r),
					"%s %s: %s blijft in het kader (%s in %s)"
						% [str(maat), fase, str(id), str(r), str(kader)])
				knoppen += 1
				if str(d["op"]) in ["rand", "midden", "aan"]:
					continue          # a fixed card and a `rand` plate may stand
									  # over the world (architecture.md §4.3);
									  # test_kratplaatjes... checks the real bar
				gelijk(float(d["dekking"]), 0.0,
					"%s %s: %s dekt %.1f %% van zijn voorwerp"
						% [str(maat), fase, str(id), float(d["dekking"])])
				waar(r.size.x >= 44.0 and r.size.y >= 44.0,
					"%s %s: %s is een echt tikdoel (%s)" % [str(maat), fase, str(id), str(r)])
				# and it stands on no object in view at all, not just its own
				for ander in dbg.keys():
					var v: Rect2 = dbg[ander]["vlak"]
					if v.size.x <= 0.0:
						continue
					var snij := r.intersection(v)
					gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
						"%s %s: %s staat op het voorwerp van %s"
							% [str(maat), fase, str(id), str(ander)])
			waar(knoppen >= 4, "%s %s: er stonden %d eigen hotspots" % [str(maat), fase, knoppen])
		await _shell_af(h)

# ------------------------------------------------ rekenen eerst (wave 2, R1/R2)

## R1: inside one turn (the entry tap not counted) the maths taps outnumber
## the rest by at least one, for groep 3, 4 and 5 with a small and a large
## hotel.  Every tap this test makes is labelled: the strip under the card is
## maths (the piles of group 3 too, `reken: true`).  The pile sorts itself and
## the end card closes itself, so there is nothing else to tap.  (Before wave 2
## a turn was 9 … 20 sorting moves of one or two taps, then "👍 klaar": about
## 8 % maths.)
var _teller := {"reken": 0, "spel": 0}

func _tel(soort: String) -> void:
	_teller[soort] = int(_teller[soort]) + 1

func _fout_antwoord(band: int) -> bool:
	if band == 3 and str(_stand().get("stap", "")) != "vraag0":
		var vak: Array = _stand()["vak"]
		var l := 0
		for i in vak.size():
			if int(vak[i]) < int(vak[l]):
				l = i
		return _kies(str(WasSoorten.soort(l)["id"]))
	return _toets_fout()

func test_rekenaandeel() -> void:
	for geval in [[3, 1, 3], [3, 8, 2], [4, 4, 3], [4, 8, 3], [5, 7, 4], [5, 8, 4]]:
		var band: int = geval[0]
		var n: int = geval[1]
		_teller = {"reken": 0, "spel": 0}
		_licht_op()
		_wereld(band, 1, n, int(geval[2]))
		var va_b := _va_begin()
		waar(Games.start(ID), "band %d, N %d: het spel start" % [band, n])
		if str(_stand().get("stap", "")) == "vraag0":
			waar(_fout_antwoord(band), "band %d: een misser op de opening" % band)
			_tel("reken")
			await _wacht_mispauze()
			waar(_antwoord_goed(), "band %d: de opening goed" % band)
			_tel("reken")
		# nobody taps while the pile sorts itself
		waar(await _wacht_tot_stap("vraag1", 10.0), "band %d, N %d: gesorteerd zonder tik" % [band, n])
		waar(_fout_antwoord(band), "band %d: een misser op vraag 1" % band)
		_tel("reken")
		await _wacht_mispauze()
		waar(_antwoord_goed(), "band %d: vraag 1 goed" % band)
		_tel("reken")
		if band != 3:
			await _spoel(1.0)
			waar(_antwoord_goed(), "band %d: vraag 2 goed" % band)
			_tel("reken")
		gelijk(str(_stand().get("stap", "")), "af", "band %d, N %d: af" % [band, n])
		await _spoel(0.75 + SpelWas.AF_S + 0.3)
		gelijk(Games.actief(), "", "band %d, N %d: het spel sluit zichzelf" % [band, n])
		var reken := int(_teller["reken"])
		var spel_tik := int(_teller["spel"])
		waar(reken >= spel_tik + 1, "band %d, N %d: rekenen %d ≥ spel %d + 1" % [band, n, reken, spel_tik])
		_va_eind("was band %d, N %d" % [band, n], _teller, va_b)
		_licht_af()

## R2: a question about the chart that was missed comes back unchanged after an
## exit — also when the band changes in between (the strip of piles of group 3
## would otherwise replace the number question of group 4).  Before wave 2
## another band threw the turn away and started a new pile.
func test_een_gemiste_vraag_blijft_bij_een_andere_band() -> void:
	_licht_op()
	_wereld(4)
	Games.start(ID)
	_sorteer_alles()
	gelijk(str(_stand()["stap"]), "vraag1", "de vraag over het diagram")
	var regel := _kaart_tekst("regel")
	var vak := str(_stand()["vak"])
	waar(_toets_fout(), "een misser")
	Games.stop()
	State.s["kunnen"] = 2                    # the band drops to groep 3
	gelijk(State.band(), 3, "nu groep 3")
	Games.start(ID)
	gelijk(str(_stand()["stap"]), "vraag1", "de open vraag blijft")
	gelijk(int(_stand()["band"]), 4, "de vraag van groep 4")
	gelijk(str(_stand()["vak"]), vak, "over hetzelfde diagram")
	gelijk(_kaart_tekst("regel"), regel, "dezelfde zin")
	await _wacht_mispauze()
	waar(_antwoord_goed(), "en pas het goede antwoord gaat verder")
	gelijk(str(_stand()["stap"]), "vraag2", "naar de tweede vraag")
	_licht_af()

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
