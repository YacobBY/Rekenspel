extends Proef
## G1 — het zwembad, headless (games-b.md §1, architecture.md §12.2).
##
## Everything is driven through the ctx the way a child drives it: the turn is
## answered by pressing the real buttons of the choice strip, never by calling
## the game's own methods.  Reduced motion is switched on for the run, so a
## walk resolves in the same frame (world.md §2.5) and a whole lane costs no
## wall-clock time — the delays that are left are the ones the child reads.

const ID := "zwembad"
const KAART := "zb_som"
const STROOK := "zb_som_keuzes"
const VLAG_TAG := "zb_vlagtag"
const GAST_TAG := "zb_gasttag"

## The world frames the four ticket viewports produce (1024x768, 768x1024,
## 360x740, 740x360), measured by `tests/test_ui.gd::test_shell_op_vijf_schermen`.
const KADERS := [Vector2(990, 637), Vector2(734, 788), Vector2(326, 558),
	Vector2(558, 289)]

var _laag: Control = null
var _rust_voor := false

# ------------------------------------------------------------------ opzet

func _op(kader := Vector2(990, 637)) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = kader
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	_rust_voor = Ui.rust_modus()
	Ui.zet_rust_modus(true)
	# deliberately WITHOUT `State.start_gekozen()`: every `State.bewaar()` is
	# then a no-op, so this suite can never write over the save file that
	# `tests/test_ui.gd` and `tests/test_hotel.gd` read back.  `ctx.data()`
	# lives in `State.s` and works exactly the same.
	State.nieuw_spel()
	State.s["taken"] = []
	Hotel.bord_dicht()
	if World.kamer_nu() != ID:
		World.naar(ID)
	World.meet(Rect2(Vector2.ZERO, kader))

## Leave nothing behind: no game, no hotspots, no decor, no guests, no layer —
## and three frames, so every queue_free() and every cancelled timer has really
## settled before the next test file starts.
func _af() -> void:
	Games.stop()
	await _frames(3)
	Hits.wis_alles()
	World.decor_wis_alles()
	for d in World.dieren():
		World.weg(d.id)
	Ui.zet_rust_modus(_rust_voor)
	Ui.registreer_lagen(null, null, null)
	if _laag != null:
		_laag.queue_free()
		_laag = null
	await _frames(2)
	State.nieuw_spel()

## `n` guests with a bed; the first one waits on the deck of the pool, the rest
## stay at the desk.  `kunnen` is what lets band 5 exist with seven guests.
func _gasten(n: int, kunnen := 3) -> Array:
	var pool := State.gasten_pool()
	var bedden := State.alle_bedden()
	var uit: Array = []
	for i in n:
		var g: Dictionary = pool[i % pool.size()].duplicate(true)
		g["id"] = "g%d" % i
		g["naam"] = str(pool[i % pool.size()]["naam"])
		g["name"] = g["naam"]
		var bed: Dictionary = bedden[i % bedden.size()]
		g["kamer"] = str(bed["kamer"])
		g["bed"] = str(bed["slot"])
		g["waar"] = str(bed["kamer"])
		g["behoefte"] = "eten"
		g["nachten"] = 100
		uit.append(g)
	State.s["gasten"] = uit
	State.s["kunnen"] = kunnen
	State.herbereken()
	var dek: Vector2 = Rooms.get_kamer(ID).dek["start"]
	for i in uit.size():
		if i == 0:
			World.zet(str(uit[i]["id"]), ID, dek.x, dek.y,
				{"naam": str(uit[i]["naam"]), "kind": str(uit[i]["kind"]), "nr": i})
		else:
			World.zet(str(uit[i]["id"]), "receptie", 40.0 + i * 8.0, 60.0,
				{"naam": str(uit[i]["naam"]), "kind": str(uit[i]["kind"]), "nr": i})
	return uit

# ----------------------------------------------------------------- helpers

func _frames(n := 2) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	for _i in n:
		await boom.process_frame

## Wait until `test` is true, or give up.  Frames keep running, so `World`
## ticks and `Hits.plaats()` runs exactly as in the real game.
func _wacht(test: Callable, max_ms := 4000) -> bool:
	var boom := Engine.get_main_loop() as SceneTree
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_ms:
		await boom.process_frame
		if bool(test.call()):
			return true
	return false

func _kaart_staat() -> bool:
	var s := Hits.spot(STROOK)
	return s != null and is_instance_valid(s.knoop)

func _beurt() -> Dictionary:
	return State.spel_data(ID)

func _klaar() -> String:
	return str(_beurt().get("klaar", ""))

func _kaart_knoop() -> UiSomkaart:
	var s := Hits.spot(KAART)
	if s == null or not is_instance_valid(s.knoop):
		return null
	return s.knoop as UiSomkaart

## Press one of the four real choice buttons, by its number.
func _druk(waarde: int) -> bool:
	var s := Hits.spot(STROOK)
	if s == null or not is_instance_valid(s.knoop):
		return false
	var rij := s.knoop.get_node_or_null("Rij")
	if rij == null:
		return false
	for knop in rij.get_children():
		if str(knop.name) == "Km%d" % waarde:
			(knop as BaseButton).pressed.emit()
			return true
	return false

## The numbers on the real strip, in the order the child sees them.
func _waarden() -> Array:
	var uit: Array = []
	var s := Hits.spot(STROOK)
	if s == null or not is_instance_valid(s.knoop):
		return uit
	var rij := s.knoop.get_node_or_null("Rij")
	if rij == null:
		return uit
	for knop in rij.get_children():
		uit.append(int(str(knop.name).substr(2)))
	return uit

func _juist_nu() -> int:
	var b := _beurt()
	return Sommen.Zwembad.juist_van(int(b["L"]), int(b["M"]), int(b["p"]))

# ------------------------------------------------------------- aanmelding

## The directory scan finds the game, and its record says what §1.2 says.
func test_aanmelding_en_ontgrendeling() -> void:
	var def := Games.definitie(ID)
	waar(not def.is_empty(), "het spel staat in het register")
	gelijk(def.get("naam", ""), "Zwembad", "naam")
	gelijk(def.get("kamer", ""), "zwembad", "kamer")
	gelijk(def.get("wens", ""), "zwemmen", "het lost de wens 🏊 in")
	gelijk(def.get("stub", true), false, "en het is geen plaatshouder")
	var hs: Dictionary = def.get("hotspot", {})
	gelijk(hs.get("obj", ""), "startblok", "het icoontje hangt op het startblok")
	gelijk(hs.get("icoon", ""), "🏊", "icoon")
	gelijk(hs.get("label", ""), "Zwemles", "label")
	gelijk(hs.get("hoog", 0), 13, "hoogte")
	var slot: Callable = def["unlock"]
	waar(not bool(slot.call(0, 3)), "zonder gast geen zwemles")
	waar(bool(slot.call(1, 3)), "vanaf één gast wel")
	var taak: Dictionary = def.get("taak", {})
	gelijk(taak.get("id", ""), "zwemles", "taak-id")
	gelijk(taak.get("prio", 0), 1, "taakprioriteit")
	gelijk(taak.get("icoon", ""), "🏊", "taakpictogram")

## The task card: it appears for a guest who still wants to swim, and it KEEPS
## his name after the tick (§1.2, `zwemGast(s, true)`).
func test_taakkaartje_houdt_zijn_naam() -> void:
	State.nieuw_spel()
	var g: Dictionary = State.gasten_pool()[6]      # Stampertje, the longest name
	g["kamer"] = "kamer1"
	g["bed"] = "bed1"
	g["behoefte"] = "zwemmen"
	g["blij"] = false
	State.s["gasten"] = [g]
	var taak: Dictionary = Games.definitie(ID)["taak"]
	var wanneer: Callable = taak["wanneer"]
	var tekst: Callable = taak["tekst"]
	waar(bool(wanneer.call(State.s)), "er is een gast die wil zwemmen")
	gelijk(tekst.call(State.s), "Zwemles voor Stampertje", "de kaart draagt zijn naam")
	waar(Ui.keur_taak("zwemles", str(tekst.call(State.s))), "≤ 6 woorden (HOTEL.md §9)")
	g["blij"] = true
	waar(not bool(wanneer.call(State.s)), "afgevinkt hoort het er niet meer bij")
	gelijk(tekst.call(State.s), "Zwemles voor Stampertje", "maar de naam blijft staan")
	g["behoefte"] = "eten"
	gelijk(tekst.call(State.s), "Zwemles", "zonder zwemgast de kale regel")

# ------------------------------------------------------ het rekenen per band

## The owner's own windows (§1.3): the band-5 lane runs to 80, not to 76, and
## the +3 shift keeps a round ten out of the remainder.
func test_de_baan_per_band() -> void:
	var vensters := {3: [8, 20], 4: [21, 50], 5: [31, 80]}
	for band in [3, 4, 5]:
		for n in range(1, 13):
			for dag in range(1, 9):
				var baan := Sommen.Zwembad.baan(n, band, dag)
				var l := int(baan["L"])
				var m := int(baan["M"])
				waar(l >= vensters[band][0] and l <= vensters[band][1],
					"band %d N=%d dag=%d: L=%d in het venster" % [band, n, dag, l])
				waar(l <= 2 * m, "band %d: L=%d kost hooguit twee etappes (M=%d)"
					% [band, l, m])
				gelijk(int(baan["stap"]), 5 if l <= 20 else 10, "meterstreep bij L=%d" % l)
				if band == 5:
					# the +3 shift: 40, 50, 60 and 70 never come out (§1.3)
					waar(not [40, 50, 60, 70].has(l),
						"band 5: geen rond tiental als baan (L=%d)" % l)
	# the header of the HTML file says band 5 stops at 76; from N = 11 the window
	# really reaches 80 (A1 §13 Q-X3-1), and that is what the port uses
	var langste := 0
	for n in range(1, 13):
		for dag in range(1, 9):
			langste = maxi(langste, int(Sommen.Zwembad.baan(n, 5, dag)["L"]))
	gelijk(langste, 80, "band 5 haalt 80, niet 76 (A1 §13 Q-X3-1)")
	for schuif in [[40, 43], [50, 53], [60, 63], [70, 73]]:
		var gevonden := false
		for n in range(1, 13):
			for dag in range(1, 9):
				if int(Sommen.Zwembad.baan(n, 5, dag)["L"]) == int(schuif[1]):
					gevonden = true
		waar(gevonden, "%d schuift naar %d" % [schuif[0], schuif[1]])

## The G1-F1 ordering: first the numbers the child SEES in the world, then a
## round ten off/on, and only as filler the neighbours.  The owner's card is
## 43 -> 43, 13, 20, 30.
func test_de_kaart_van_de_eigenaar() -> void:
	var k := Sommen.Zwembad.keuze_getallen(43, 30, 0, 4, 0)
	gelijk(str(k["lijst"]), str([43, 13, 20, 30]), "43 m, max 30: 43 / 13 / 20 / 30")
	gelijk(int(k["juist"]), 30, "en 30 is het goede antwoord")
	# L, M, p, band, leg, the four buttons — the second card of a turn has
	# `leg = 1`, and that seventh in the seed is what moves the right button
	for rij in [[43, 30, 30, 4, 1, [43, 30, 13, 3]], [14, 10, 0, 3, 0, [14, 10, 4, 20]],
			[14, 10, 10, 3, 1, [14, 4, 10, 3]], [76, 40, 0, 5, 0, [76, 36, 40, 30]],
			[76, 40, 40, 5, 1, [76, 40, 36, 26]]]:
		var uit := Sommen.Zwembad.keuze_getallen(int(rij[0]), int(rij[1]), int(rij[2]),
			int(rij[3]), int(rij[4]))
		gelijk(str(uit["lijst"]), str(rij[5]),
			"L=%d M=%d p=%d leg=%d" % [rij[0], rij[1], rij[2], rij[4]])
		gelijk(uit["lijst"].size(), 4, "altijd vier knoppen")
		gelijk(uit["lijst"].count(uit["juist"]), 1, "en precies één goede")

# ------------------------------------------------------- kindtekst, letterlijk

## Every literal of §1.11, and the F4 budget for every sentence a card can show
## at every band with the longest guest name in the hotel.
func test_de_zinnen_staan_er_woordelijk() -> void:
	gelijk(ZwembadBeurt.GEEN_GAST, "🏊 Er is nog geen gast", "toast zonder gast")
	gelijk(ZwembadBeurt.TOAST_PRECIES, "🏊 Precies aan de overkant! ⭐", "toast precies")
	gelijk(ZwembadBeurt.TOAST_BOTS, "🏊 Aan de overkant! ⭐", "toast bots")
	gelijk(ZwembadBeurt.EIND_PRECIES, "Precies aan de overkant!", "eindregel precies")
	gelijk(ZwembadBeurt.HULP_TITEL, "hoeveel meter zwemt hij?", "titel van de strook")
	gelijk(ZwembadBeurt.regel_start(43), "Het bad is 43 meter lang", "kaart 1, regel 1")
	gelijk(ZwembadBeurt.regel2_start(30), "Max 30 meter per keer", "kaart 1, regel 2")
	gelijk(ZwembadBeurt.som_start(43), "nog 43 m", "kaart 1, sombalk")
	gelijk(ZwembadBeurt.regel_verder("Muis", 30), "Muis is bij 30 meter", "kaart n, regel 1")
	gelijk(ZwembadBeurt.regel2_verder(), "Nog hoeveel meter?", "kaart n, regel 2")
	gelijk(ZwembadBeurt.regel_bots_terug("Muis", 12), "Muis botste terug naar 12 meter",
		"kaart n na een bots: waar hij nu ligt")
	gelijk(ZwembadBeurt.BOTS_KAART_ICOON, "🙃", "en haar pictogram")
	gelijk(ZwembadBeurt.som_verder(43, 30), "43 − 30 =", "kaart n, sombalk")
	gelijk(ZwembadBeurt.som_af(43, 30, 13, true), "43 − 30 = 13", "eindsombalk")
	gelijk(ZwembadBeurt.som_af(43, 0, 43, false), "43 m ✓", "eindsombalk zonder etappe")
	gelijk(ZwembadBeurt.eind_regel2_precies("Muis", 43), "Muis zwom 43 meter", "eind precies")
	gelijk(ZwembadBeurt.eind_regel_bots("Muis"), "Muis is aan de overkant", "eind bots")
	gelijk(ZwembadBeurt.eind_regel2_bots(13), "Het was nog 13 meter", "eind bots, regel 2")
	gelijk(ZwembadBeurt.keuze_woord(30), "30 m", "de knop draagt zijn eenheid")
	gelijk(ZwembadBeurt.taak_tekst("Muis"), "Zwemles voor Muis", "prikbord")
	# the real minus sign U+2212 and the tick, never a hyphen (F3)
	waar(ZwembadBeurt.som_verder(43, 30).contains(char(0x2212)), "echt minteken op de kaart")
	waar(not ZwembadBeurt.som_verder(43, 30).contains("-"), "en geen koppelteken")
	# F4: <= 8 words AND <= 40 characters, per sentence, at every band
	var naam := "Stampertje"
	for band in [3, 4, 5]:
		for n in range(1, 13):
			var baan := Sommen.Zwembad.baan(n, band, 1)
			var l := int(baan["L"])
			var m := int(baan["M"])
			for zin in [ZwembadBeurt.regel_start(l), ZwembadBeurt.regel2_start(m),
					ZwembadBeurt.regel_verder(naam, m), ZwembadBeurt.regel2_verder(),
					ZwembadBeurt.regel_bots_terug(naam, l - 1),
					ZwembadBeurt.eind_regel2_precies(naam, l),
					ZwembadBeurt.eind_regel_bots(naam), ZwembadBeurt.eind_regel2_bots(l)]:
				waar(zin.split(" ", false).size() <= 8 and zin.length() <= 40,
					'"%s" past in het tekstbudget (%d woorden, %d tekens)'
						% [zin, zin.split(" ", false).size(), zin.length()])
	# every character is in the bundled font subset
	for zin in [ZwembadBeurt.GEEN_GAST, ZwembadBeurt.TOAST_PRECIES,
			ZwembadBeurt.TOAST_BOTS, ZwembadBeurt.ICOON, ZwembadBeurt.PRECIES_ICOON,
			ZwembadBeurt.BOTS_ICOON, ZwembadBeurt.BOTS_KAART_ICOON,
			ZwembadBeurt.regel_bots_terug("Muis", 12), ZwembadBeurt.som_verder(43, 30),
			ZwembadBeurt.som_af(43, 0, 43, false)]:
		gelijk(str(Ui.mist_tekens(zin)), "[]", 'geen ontbrekend teken in "%s"' % zin)
	# the help ladder is gone (owner, 2026-09-24)
	waar(not ZwembadBeurt.new().has_method("hulp_regel") and not (ZwembadBeurt as Script)
		.get_script_method_list().any(func(mt): return str(mt["name"]) == "hulp_regel"),
		"ZwembadBeurt heeft geen hulp_regel meer")

# ------------------------------------------------------------ de bewaarde beurt

func test_normaliseren_en_geldigheid() -> void:
	var b := ZwembadBeurt.normaliseer({"L": 43, "p": 99, "band": 9,
		"laatste_p": 12.7}, 4)
	gelijk(int(b["band"]), 5, "de band wordt geklemd")
	gelijk(int(b["M"]), 30, "M komt uit maxVan(L, band)")
	gelijk(int(b["stap"]), 10, "meterstreep bij L > 20")
	gelijk(int(b["p"]), 43, "p wordt geklemd op 0..L")
	gelijk(int(b["laatste_p"]), 13, "laatstep is een geheel getal")
	gelijk(int(b["laatste_rest"]), 43, "laatsteRest is standaard L")
	var klein := ZwembadBeurt.normaliseer({"L": 14, "p": 0}, 3)
	gelijk(int(klein["stap"]), 5, "meterstreep bij L <= 20")
	waar(ZwembadBeurt.geldig(klein, true), "een echte beurt is geldig")
	waar(not ZwembadBeurt.geldig(klein, false), "zonder gast niet")
	waar(not ZwembadBeurt.geldig(ZwembadBeurt.normaliseer({"L": 0, "p": 0}, 3), true),
		"zonder baan niet")
	var af := ZwembadBeurt.normaliseer({"L": 14, "p": 14, "klaar": "precies"}, 3)
	waar(not ZwembadBeurt.geldig(af, true), "een afgelopen beurt wordt niet hervat")
	var wand := ZwembadBeurt.normaliseer({"L": 14, "p": 14}, 3)
	waar(not ZwembadBeurt.geldig(wand, true),
		"en een beurt die tegen de wand geparkeerd staat evenmin: die is niet te beantwoorden")

# ------------------------------------------------- de kaart en haar marges

## G1-F2: the card keeps 8 css px from the swimmer and from the flag, in every
## frame size and wherever the swimmer is on the lane.  Pure, so this walks the
## whole pool without a viewport.
func test_de_kaart_houdt_acht_px() -> void:
	var kaart := Vector2(212, 96)
	var strook := Vector2(238, 56)
	var vlag_krap := 0
	for kader in KADERS:
		for i in 11:
			var x: float = 20.0 + (kader.x - 100.0) * i / 10.0
			var vrij := Rect2(Vector2(x, kader.y * 0.32), Vector2(56, 74))
			var vlag := Rect2(Vector2(kader.x - 70.0, 24.0), Vector2(52, 60))
			var uit := ZwembadKaartplek.kies(kader, kaart, strook, vrij, vlag)
			var blok := ZwembadKaartplek.blok_van(uit, kaart, strook)
			waar(ZwembadKaartplek.binnen(blok, kader),
				"kader %s, x=%d: de kaart staat in beeld (%s)" % [str(kader), x, str(blok)])
			waar(not bool(uit["krap"]),
				"kader %s, x=%d: er was een echte plek (kant %s)"
					% [str(kader), x, str(uit["kant"])])
			# the swimmer's air is the rule that never bends
			waar(ZwembadKaartplek.lucht(blok, vrij) >= ZwembadKaartplek.MARGE
					- ZwembadKaartplek.EPS,
				"kader %s, x=%d: %.1f px lucht naar de zwemmer"
					% [str(kader), x, ZwembadKaartplek.lucht(blok, vrij)])
			if bool(uit["krap_vlag"]):
				vlag_krap += 1
				continue
			waar(ZwembadKaartplek.lucht(blok, vlag) >= ZwembadKaartplek.MARGE
					- ZwembadKaartplek.EPS,
				"kader %s, x=%d: %.1f px lucht naar de vlag"
					% [str(kader), x, ZwembadKaartplek.lucht(blok, vlag)])
	# and the flag only gives way where the frame really has no room: a
	# landscape phone, and nowhere else
	waar(vlag_krap <= 6, "de vlag wijkt hooguit in een enkel krap kader (%d)" % vlag_krap)

## The aim point the card hands the band grid maps back onto exactly the frame
## point it asked for — the projection is inverted, not approximated.
func test_kaderpunt_wordt_precies_een_mikpunt() -> void:
	_op()
	for doel in [Vector2(100, 90), Vector2(480, 320), Vector2(880, 560)]:
		var v: Vector3 = ZwembadKaartplek.punt_naar_voxel(World, doel)
		var terug: Vector2 = World.mik_punt(v.x, v.y, v.z)
		waar(terug.distance_to(doel) < 0.05,
			"%s komt terug als %s" % [str(doel), str(terug)])
	await _af()

# -------------------------------------------------------------- een hele beurt

## One full turn per band, driven through the ctx: every stroke is a press on a
## real choice button, and the turn ends with `Precies aan de overkant!`.
func test_een_hele_beurt_op_band_3() -> void:
	await _beurt_per_band(1, 3)

func test_een_hele_beurt_op_band_4() -> void:
	await _beurt_per_band(4, 4)

func test_een_hele_beurt_op_band_5() -> void:
	await _beurt_per_band(7, 5)

func _beurt_per_band(n_gasten: int, band: int) -> void:
	_op()
	var gasten := _gasten(n_gasten, 5 if band == 5 else 3)
	gelijk(State.band(), band, "band %d met %d gasten" % [band, n_gasten])
	var sterren_voor := int(State.s["sterren"])
	waar(Games.start(ID), "het spel start")
	waar(await _wacht(_kaart_staat), "band %d: de vraagkaart staat er" % band)
	var b := _beurt()
	gelijk(int(b["band"]), band, "de beurt draait op band %d" % band)
	var l := int(b["L"])
	var m := int(b["M"])
	gelijk(int(b["p"]), 0, "hij begint op meter 0")
	# card 1 says what the lane is and what the maximum per stroke is
	var kaart := _kaart_knoop()
	waar(kaart != null, "de kaart is een echte somkaart")
	if kaart != null:
		gelijk(kaart.regel_label.text, "🏊 " + ZwembadBeurt.regel_start(l), "kaart 1 regel 1")
		gelijk(kaart.regel2_label.text, ZwembadBeurt.regel2_start(m), "kaart 1 regel 2")
		gelijk(kaart.som_label.text, ZwembadBeurt.som_start(l), "kaart 1 sombalk")
	# the four buttons, and the right one among them
	var strook := Hits.spot(STROOK)
	var rij := strook.knoop.get_node_or_null("Rij")
	gelijk(rij.get_child_count(), 4, "vier keuzeknoppen")
	for knop in rij.get_children():
		waar(str((knop as Button).text).begins_with("🏊"),
			"pictogram én woord op %s" % str(knop.name))
	# swim it, stroke by stroke, always the right answer
	var slagen := 0
	while _klaar().is_empty() and slagen < 4:
		var juist := _juist_nu()
		var p_voor := int(_beurt()["p"])
		waar(_druk(juist), "knop %d m staat op de strook" % juist)
		waar(await _wacht(func() -> bool: return _kaart_staat() or not _klaar().is_empty()),
			"band %d: het spel gaat verder na %d m" % [band, juist])
		slagen += 1
		if _klaar().is_empty():
			var nu := _beurt()
			gelijk(int(nu["p"]), p_voor + juist, "hij ligt %d m verder" % juist)
			var k2 := _kaart_knoop()
			if k2 != null:
				gelijk(k2.regel_label.text,
					"🏊 " + ZwembadBeurt.regel_verder(str(gasten[0]["naam"]), int(nu["p"])),
					"kaart n regel 1")
				gelijk(k2.regel2_label.text, ZwembadBeurt.regel2_verder(), "kaart n regel 2")
				gelijk(k2.som_label.text, ZwembadBeurt.som_verder(l, int(nu["p"])),
					"kaart n sombalk")
	gelijk(_klaar(), "precies", "band %d eindigt precies aan de overkant" % band)
	gelijk(int(_beurt()["p"]), l, "en hij ligt op meter %d" % l)
	waar(slagen <= 2, "een baan kost hooguit twee etappes (%d)" % slagen)
	var eind := _kaart_knoop()
	waar(eind != null, "de eindkaart staat er")
	if eind != null:
		gelijk(eind.regel_label.text, "✅ " + ZwembadBeurt.EIND_PRECIES, "eindkaart regel 1")
		gelijk(eind.regel2_label.text,
			ZwembadBeurt.eind_regel2_precies(str(gasten[0]["naam"]), l), "eindkaart regel 2")
		gelijk(eind.som_label.text,
			ZwembadBeurt.som_af(l, int(_beurt()["laatste_p"]), int(_beurt()["laatste_rest"]), true),
			"eindsombalk")
	gelijk(int(State.s["sterren"]), sterren_voor + 1, "meedoen levert één ster op")
	waar(Hits.spot(STROOK) == null, "de keuzestrook is van tafel")
	await _af()

## The owner, 2026-09-24: "Nee geef geen hulp na fouten.  Kinderen moeten zelf
## leren rekenen.  Fout antwoord kiezen moet niet beloond worden met hulp maar
## juist een teleurgesteld dier."  A stroke that is too short, one, two and
## three times: he swims what the answer bought, and then he sulks in the water
## (`sip`) with `🔄 Nog een keer` beside him — no bubble with the metres that
## are left, no help line on the next card, no marker lighting up, no pale
## marker in the water.  Never punishing either: no star less, the turn goes
## on, and the right answers still reach the other side.
func test_geen_hulp_na_een_fout() -> void:
	_op()
	var gasten := _gasten(4)
	var gast := str(gasten[0]["id"])
	var sterren_voor := int(State.s["sterren"])
	waar(Games.start(ID), "het spel start")
	waar(await _wacht(_kaart_staat), "de vraagkaart staat er")
	var missers := 0
	for i in 3:
		var kort := _kort_antwoord()
		if kort <= 0 or not _klaar().is_empty():
			break
		var wat := "misser %d" % (i + 1)
		var p_voor := int(_beurt()["p"])
		waar(_druk(kort), "%s: de te korte knop %d is aan te tikken" % [wat, kort])
		waar(await _wacht(func() -> bool: return is_sip(gast)), "%s: hij wordt sip" % wat)
		missers += 1
		gelijk(int(_beurt()["p"]), p_voor + kort, "%s: hij zwom zo ver als gevraagd" % wat)
		gelijk(int(_beurt()["misser"]), missers, "%s: geteld" % wat)
		waar(mis_wolk("", gast), "%s: met 🔄 Nog een keer naast zich" % wat)
		var wolk := Hits.spot("zb_wolk")
		waar(wolk == null, "%s: geen wolkje met hoeveel of hooguit" % wat)
		waar(not _kaart_staat(), "%s: eerst het sippe dier, dan de kaart" % wat)
		waar(await _wacht(_kaart_staat), "%s: daarna gewoon een nieuwe kaart" % wat)
		var d = World.dier(gast)
		waar(d != null and str(d.staat) == "zwem", "%s: en hij drijft weer (%s)"
			% [wat, str(d.staat) if d != null else "?"])
		var kaart := _kaart_knoop()
		waar(kaart != null and not kaart.hulp_label.visible, "%s: geen hulpregel" % wat)
		if kaart != null:
			waar(not kaart.regel_label.text.contains("✗"), "%s: geen kruis" % wat)
		for stuk in World.decor_lijst(ID):
			var par: Dictionary = stuk.get("params", {})
			waar(not par.has("licht") and not par.has("bleek"),
				"%s: %s licht niet op en is niet bleek" % [wat, str(stuk.get("id", ""))])
		waar(World.decor_plek("zb_spook", ID).is_empty() and Hits.spot("zb_spooktag") == null,
			"%s: geen bleke streep met het antwoord" % wat)
	waar(missers >= 1, "er viel minstens één te korte slag (%d)" % missers)
	gelijk(int(State.s["sterren"]), sterren_voor, "en geen ster minder")
	# the right answers still get him to the other side
	var slagen := 0
	while _klaar().is_empty() and slagen < 6:
		waar(_druk(_juist_nu()), "het goede antwoord staat op de strook")
		await _wacht(func() -> bool: return _kaart_staat() or not _klaar().is_empty(), 8000)
		slagen += 1
	gelijk(_klaar(), "precies", "precies aan de overkant")
	await _af()

## PLAN N3 (open question V1) and the owner, 2026-09-23 ("Bij stoten moet de
## speler ook opnieuw rekenen met een andere afstand"): too far is a soft
## bump, a 💛 Au! and never a cross, and never the end of the turn.  He swims
## the rest, touches the wall, and the wall throws him back to a NEW metre —
## so the card that follows is a new sum from there, not the question he just
## missed.  Nothing is taken: no star, and the lane goes on from there.
## (Until 2026-09-23 this test asserted the opposite: back on `p_voor` with
## the same sum under the line "Te ver, hij tikt de rand".)
func test_een_te_ver_antwoord_eindigt_de_beurt_niet() -> void:
	_op()
	var gasten := _gasten(4)
	var sterren_voor := int(State.s["sterren"])
	waar(Games.start(ID), "het spel start")
	waar(await _wacht(_kaart_staat), "de vraagkaart staat er")
	var l := int(_beurt()["L"])
	var m := int(_beurt()["M"])
	# first the honest stroke, so that a button above the rest exists
	waar(_druk(_juist_nu()), "eerst netjes %d m" % m)
	waar(await _wacht(_kaart_staat), "de tweede kaart staat er")
	var ver := _ver_antwoord()
	waar(ver > 0, "er staat een te verre knop op de strook (%d)" % ver)
	var p_voor := int(_beurt()["p"])
	var rest_voor := l - p_voor
	var missers_voor := int(_beurt()["misser"])
	var leg := int(_beurt()["leg"]) + 1
	waar(_druk(ver), "de te verre knop is aan te tikken")
	waar(await _wacht(_kaart_staat, 8000), "er komt een nieuwe vraag na de bots")
	gelijk(_klaar(), "", "de beurt is NIET afgelopen")
	var p_na := int(_beurt()["p"])
	gelijk(p_na, ZwembadBeurt.bots_plek(l, m, p_voor, leg),
		"de wand gooide hem terug naar de meter die bots_plek zegt")
	waar(p_na != p_voor, "hij ligt NIET meer op meter %d" % p_voor)
	waar(p_na > 0 and p_na < l, "maar wel in de baan (%d m)" % p_na)
	waar(l - p_na != rest_voor, "dus het is een andere afstand (%d, was %d)"
		% [l - p_na, rest_voor])
	gelijk(int(_beurt()["misser"]), missers_voor + 1, "de misser telt voor het adaptieve signaal")
	gelijk(int(State.s["sterren"]), sterren_voor, "en er viel geen ster")
	var kaart := _kaart_knoop()
	waar(kaart != null, "er staat weer een somkaart")
	if kaart != null:
		gelijk(kaart.regel_label.text, ZwembadBeurt.BOTS_KAART_ICOON + " "
			+ ZwembadBeurt.regel_bots_terug(str(gasten[0]["naam"]), p_na),
			"die zegt waar de wand hem heen gooide")
		gelijk(kaart.regel2_label.text, ZwembadBeurt.regel2_verder(), "met de vraag")
		gelijk(kaart.som_label.text, ZwembadBeurt.som_verder(l, p_na), "en de nieuwe som")
		waar(not kaart.regel_label.text.contains("✗"), "geen kruis op de kaart")
	var rij := Hits.spot(STROOK).knoop.get_node_or_null("Rij")
	gelijk(rij.get_child_count(), 4, "met vier keuzeknoppen")
	gelijk(str(_waarden()), str(Sommen.Zwembad.keuze_getallen(l, m, p_na,
		int(_beurt()["band"]), int(_beurt()["leg"]))["lijst"]),
		"de keuzes komen uit de bevroren kern, vanaf zijn nieuwe meter")
	# the swimmer really floats on his new metre, not against the wall
	var d = World.dier(str(gasten[0]["id"]))
	var doel := ZwembadBeurt.baan_x(Rooms.get_kamer(ID).bad, l, p_na)
	waar(absf(d.x - doel) <= 3.0,
		"en hij drijft op meter %d (x=%.1f, doel %.1f)" % [p_na, d.x, doel])
	waar(Hits.spot(GAST_TAG) != null, "met zijn nummer op zijn rug")
	# and the new sum fits one stroke: its exact answer ends the lane
	waar(l - p_na <= m, "de nieuwe rest (%d) past in één slag (max %d)" % [l - p_na, m])
	waar(_druk(_juist_nu()), "het goede antwoord op de nieuwe som")
	waar(await _wacht(func() -> bool: return not _klaar().is_empty(), 8000), "de baan is af")
	gelijk(_klaar(), "precies", "precies aan de overkant")
	gelijk(int(State.s["sterren"]), sterren_voor + 1, "en nu pas valt de ster")
	await _af()

## De kaart die ná een bots terugkomt is een gewone kaart: ze past in het kader
## en staat niet `krap`.  Deze proef loopt in OPGEWEKTE beweging (rust uit),
## want alleen dan komt het einde van de terugzwemtocht uit de wereldtik zelf —
## en een kaart die in díe fase gebouwd wordt, wordt opgemeten vóórdat haar
## hulpregel een breedte heeft (een Label met autowrap meldt de hoogte die bij
## zijn HUIDIGE breedte hoort, en `Hits` zet die hoogte daarna vast in
## `custom_minimum_size`).  Zonder de tel tussen de bots en de vraag werd de
## kaart daardoor een strook van kaderhoogte.
func test_de_kaart_na_een_bots_past_in_het_kader() -> void:
	_op()
	_gasten(1)
	Ui.zet_rust_modus(false)
	waar(Games.start(ID), "het spel start")
	waar(await _wacht(_kaart_staat, 20000), "de vraagkaart staat er")
	waar(_druk(_juist_nu()), "eerst de eerlijke slag")
	waar(await _wacht(_kaart_staat, 20000), "de tweede kaart staat er")
	var ver := _ver_antwoord()
	waar(ver > 0, "er staat een te verre knop op de strook (%d)" % ver)
	waar(_druk(ver), "de te verre knop is aan te tikken")
	waar(await _wacht(_kaart_staat, 25000), "de vraag komt terug na de bots")
	await _frames(3)
	Ui.zet_rust_modus(true)
	var a: Dictionary = Hits.debug().get(KAART, {})
	waar(not a.is_empty(), "de kaart is geplaatst")
	if not a.is_empty():
		var r: Rect2 = a["rect"]
		waar(not bool(a["krap"]), "ze vond een echte plek (%s)" % str(r))
		waar(r.size.y <= 260.0, "ze is een kaart, geen strook (%s)" % str(r))
		waar(r.position.y >= 0.0 and r.end.y <= 637.0 + 0.01,
			"en ze staat heel in het kader (%s)" % str(r))
	var kaart := _kaart_knoop()
	if kaart != null:
		waar(not kaart.hulp_label.visible, "zonder hulpregel (eigenaar 2026-09-24)")
	await _af()

## En het sluitstuk van R3: de ster valt alleen bij `precies`.  Dezelfde beurt,
## eerst een bots (geen ster, geen vinkje) en daarna het goede antwoord.
func test_de_ster_valt_alleen_bij_precies() -> void:
	_op()
	_gasten(4)
	var sterren_voor := int(State.s["sterren"])
	waar(Games.start(ID), "het spel start")
	waar(await _wacht(_kaart_staat), "de vraagkaart staat er")
	waar(_druk(_juist_nu()), "eerst een eerlijke etappe")
	waar(await _wacht(_kaart_staat), "de tweede kaart staat er")
	var ver := _ver_antwoord()
	waar(ver > 0, "er staat een te verre knop op de strook (%d)" % ver)
	waar(_druk(ver), "en die wordt getikt")
	waar(await _wacht(_kaart_staat, 8000), "de vraag komt terug")
	gelijk(int(State.s["sterren"]), sterren_voor, "een bots levert geen ster op")
	gelijk(_klaar(), "", "en vinkt de beurt niet af")
	gelijk(Games.actief(), ID, "het spel draait gewoon door")
	# nu het goede antwoord: dan pas de ster
	waar(_druk(_juist_nu()), "nu het goede antwoord")
	waar(await _wacht(func() -> bool: return not _klaar().is_empty(), 8000),
		"de beurt loopt af")
	gelijk(_klaar(), "precies", "en wel precies aan de overkant")
	gelijk(int(State.s["sterren"]), sterren_voor + 1, "nu valt de ster")
	await _af()

## Eigenaar, 2026-09-23: "Bij het zwembad is er geen volg optie om boef aan te
## komen tenzij ik eerst op 'terug' druk.  Zorg dat de minigame pas begint
## wanneer het dier er is."  De zwemmer staat nog in de receptie: het spel
## wacht op hem — geen kaart, geen strook — en het hotelwolkje "komt eraan" met
## zijn balk en `👀 Volg` staat bij het hek, ook nu het spel loopt.  Zodra hij
## op het dek staat komt de eerste vraag; het trapje, de duik en het zwemmen
## zijn nog steeds wat het eerste antwoord koopt.  (Tot 2026-09-23 stond de
## vraag er meteen en was de zwemmer "nog niet eens in het zwembad", PLAN N3.)
func test_de_vraag_wacht_op_de_zwemmer() -> void:
	_op()
	Ui.zet_rust_modus(false)
	var gasten := _gasten(4)
	gasten[2]["behoefte"] = "zwemmen"      # de wensende gast staat in de receptie
	gasten[2]["blij"] = false
	var id := str(gasten[2]["id"])
	World.pauzeer(true)                    # de test tikt de wereld zelf
	waar(Games.start(ID), "het spel start")
	gelijk(str(_beurt()["gast"]), id, "de wensende gast zwemt")
	gelijk(Games.speler(), id, "en staat op de spelbalk")
	waar(Hits.spot(KAART) == null and not _kaart_staat(), "nog geen vraag: hij is er nog niet")
	waar(Games.verwacht_dier(id), "het spel wacht op hem")
	var d = World.dier(id)
	gelijk(str(d.reis_doel), ID, "hij loopt naar het zwembad")
	Hotel.komt_eraan()
	Hits.plaats()
	var w := Hits.spot("komt_" + id)
	waar(w != null and is_instance_valid(w.knoop) and w.knoop.visible,
		"zijn wolkje 'komt eraan' staat in beeld, ook nu het spel loopt")
	var t := 0
	while d.kamer != ID and t < 4000:
		World._tik()
		t += 1
	gelijk(d.kamer, ID, "hij stapt het zwembad in")
	await _wacht(func() -> bool: return false, 350)
	waar(not _kaart_staat(), "maar zolang hij naar het dek loopt, is er geen vraag")
	while not (d.punten as Array).is_empty() and t < 4000:
		World._tik()
		t += 1
	waar(await _wacht(_kaart_staat, 2000), "op het dek: nu komt de vraag")
	waar(not Games.verwacht_dier(id), "het spel wacht niet meer")
	var dek: Vector2 = Rooms.get_kamer(ID).dek["start"]
	waar(Vector2(d.x, d.z).distance_to(dek) <= 3.0,
		"hij staat op het dek aan het begin van de baan (%.0f, %.0f)" % [d.x, d.z])
	gelijk(int(_beurt()["p"]), 0, "nog op meter 0")
	var kaart := _kaart_knoop()
	waar(kaart != null, "het is een echte somkaart")
	if kaart != null:
		gelijk(kaart.regel_label.text,
			"🏊 " + ZwembadBeurt.regel_start(int(_beurt()["L"])), "met de baan erop")
	Hotel.komt_eraan()
	waar(Hits.spot("komt_" + id) == null, "en zijn wolkje is weg")
	World.pauzeer(false)
	await _af()

## Rustmodus lost elke wandeling meteen op (games-b.md §0.11): dan staat de
## zwemmer uit de receptie in dezelfde tik op het dek, en de vraag staat er
## zonder één frame te wachten.
func test_in_rust_staat_de_vraag_er_meteen() -> void:
	_op()
	var gasten := _gasten(4)
	gasten[2]["behoefte"] = "zwemmen"      # de wensende gast staat in de receptie
	gasten[2]["blij"] = false
	waar(Games.start(ID), "het spel start")
	waar(_kaart_staat(), "de keuzestrook staat er meteen, zonder één frame te wachten")
	gelijk(str(_beurt()["gast"]), str(gasten[2]["id"]), "de wensende gast zwemt")
	gelijk(int(_beurt()["p"]), 0, "en hij ligt nog op meter 0")
	var rij := Hits.spot(STROOK).knoop.get_node_or_null("Rij")
	waar(rij != null and rij.get_child_count() == 4, "de kaart draagt vier keuzes")
	var d = World.dier(str(gasten[2]["id"]))
	waar(d != null and d.kamer == ID, "de zwemmer is er al")
	waar(not Games.verwacht_dier(str(gasten[2]["id"])), "er valt niets te wachten")
	await _frames(2)
	waar(_kaart_staat(), "ook na de eerste plaatsing staat de vraag er")
	await _af()

## Het dier op de spelbalk wisselen terwijl het spel nog wacht: de vorige
## zwemmer keert om naar zijn bed (`ctx.laat_gaan`), het spel wacht op de
## nieuwe, en diens wolkje "komt eraan" hangt nu bij het hek.
func test_wisselen_terwijl_het_spel_wacht() -> void:
	_op()
	Ui.zet_rust_modus(false)
	var gasten := _gasten(4)
	var eerst := str(gasten[2]["id"])
	var dan := str(gasten[3]["id"])
	gasten[2]["behoefte"] = "zwemmen"
	gasten[2]["blij"] = false
	World.pauzeer(true)
	waar(Games.start(ID), "het spel start")
	gelijk(Games.speler(), eerst, "de wensende gast zwemt eerst")
	waar(Games.verwacht_dier(eerst), "en het spel wacht op hem")
	Hotel.komt_eraan()
	waar(Hits.spot("komt_" + eerst) != null, "zijn wolkje hangt bij het hek")
	gelijk(Games.volgende_speler(), dan, "de volgende op de balk")
	waar(Games.wissel_speler(), "het dier op de balk geeft de beurt door")
	gelijk(Games.speler(), dan, "nu zwemt de volgende")
	waar(not Games.verwacht_dier(eerst), "op de vorige wacht niemand meer")
	waar(Games.verwacht_dier(dan), "op de nieuwe wel")
	waar(Hits.spot(KAART) == null and not _kaart_staat(), "en er is nog steeds geen vraag")
	var vorige = World.dier(eerst)
	gelijk(str(vorige.reis_doel), str(gasten[2]["kamer"]),
		"de vorige keert om naar zijn eigen kamer")
	Hotel.komt_eraan()
	waar(Hits.spot("komt_" + eerst) == null, "zijn wolkje is weg")
	waar(Hits.spot("komt_" + dan) != null, "en het wolkje van de nieuwe hangt er")
	var d = World.dier(dan)
	var t := 0
	while (d.kamer != ID or not (d.punten as Array).is_empty()) and t < 4000:
		World._tik()
		t += 1
	waar(await _wacht(_kaart_staat, 2000), "de nieuwe staat op het dek: zijn vraag")
	var kaart := _kaart_knoop()
	waar(kaart != null and str(_beurt()["gast"]) == dan, "zijn eigen baan")
	World.pauzeer(false)
	await _af()

## De twee klimaxmomenten spatten: de wand en de overkant (pijler 4).  Met de
## rust aan slikt `World.spetter` elke druppel in, dus deze twee suites lopen
## in opgewekte beweging en meten de piek van `World.deeltjes()` per frame.
## Eén gast: band 3, baan 16 m — twee slagen, en over de laatste 6 m valt er
## precies één plonsdruppel (elke 5 m), zodat een piek van 6 druppels alleen
## van de klimax zelf kan komen.  De return zegt óf er tijdens het polled een
## sterkleurig deeltje rondhing: dat hoort alleen bij de precieze overkant.
## Sinds N3 eindigt een te verre slag de beurt niet meer: dan is de klimaks
## voorbij zodra de vraag terugkomt, en de precieze overkant sluit hem wél af.
func _klimax_spat(soort_ver: bool) -> bool:
	_op()
	_gasten(1)
	gelijk(State.band(), 3, "één gast baant weg op band 3")
	Ui.zet_rust_modus(false)
	waar(Games.start(ID), "het spel start")
	waar(await _wacht(_kaart_staat, 20000), "de vraagkaart staat er")
	waar(_druk(_juist_nu()), "eerst de eerlijke slag")
	waar(await _wacht(_kaart_staat, 20000), "de tweede kaart staat er")
	var laatste := _juist_nu()
	if soort_ver:
		laatste = _ver_antwoord()
		waar(laatste > 0, "er staat een te verre knop op de strook (%d)" % laatste)
	var voor := World.deeltjes().size()
	var piek := voor
	var sprankel := false
	var boom := Engine.get_main_loop() as SceneTree
	var t0 := Time.get_ticks_msec()
	waar(_druk(laatste), "de laatste knop is aan te tikken")
	var af := func() -> bool:
		return _kaart_staat() if soort_ver else not _klaar().is_empty()
	while Time.get_ticks_msec() - t0 < 25000 and not af.call():
		await boom.process_frame
		piek = maxi(piek, World.deeltjes().size())
		for q in World.deeltjes():
			if q.get("c") == ArtEffect.STER_KL[0]:
				sprankel = true
	piek = maxi(piek, World.deeltjes().size())
	Ui.zet_rust_modus(true)
	if soort_ver:
		gelijk(_klaar(), "", "een bots laat de beurt doorlopen")
		waar(_kaart_staat(), "en de vraag staat er weer")
	else:
		gelijk(_klaar(), "precies", "de beurt eindigt aan de overkant")
	waar(piek - voor >= 6,
		"'%s' spoot over (piek %d, voor %d)" % ["bots" if soort_ver else _klaar(), piek, voor])
	await _af()
	return sprankel

## Een te verre slag spoot tegen de wand — 💛 Au! én een spat water.
func test_spat_tege_de_wand() -> void:
	await _klimax_spat(true)

## Aankomst aan de overkant: ook daar spat het van het water af.
func test_spat_aan_de_overkant() -> void:
	await _klimax_spat(false)

## "Precies" is het exacte antwoord en krijgt glans boven het water: er
## sprikkelde sterkleur boven de zwemmer (de bots blijft zacht).
func test_precies_sprankelt() -> void:
	waar(await _klimax_spat(false), "er stegen sterren op boven de zwemmer")

## De bots blijft zacht: water wel, sterren nooit (§1.7).
func test_bots_sprankelt_niet() -> void:
	waar(not await _klimax_spat(true), "bij een bots geen sterrendeeltje")

## The 🏊 wish is resolved, and only by the guest who had it (§1.7 step 2).
func test_de_wens_wordt_ingelost() -> void:
	_op()
	var gasten := _gasten(4)
	gasten[2]["behoefte"] = "zwemmen"
	gasten[2]["blij"] = false
	waar(Games.start(ID), "het spel start")
	waar(await _wacht(_kaart_staat), "de vraagkaart staat er")
	gelijk(str(_beurt()["gast"]), str(gasten[2]["id"]), "de wensende gast zwemt")
	waar(bool(_beurt()["wens"]), "en het spel weet dat het een wens is")
	var rondjes := 0
	while _klaar().is_empty() and rondjes < 4:
		_druk(_juist_nu())
		await _wacht(func() -> bool: return _kaart_staat() or not _klaar().is_empty())
		rondjes += 1
	gelijk(_klaar(), "precies", "de baan is af")
	waar(bool(gasten[2].get("blij", false)), "de wens 🏊 is ingelost")
	waar(not bool(gasten[0].get("blij", false)), "en alleen bij hem")
	await _af()

# ------------------------------------------------------------------ herstel

## A promise never survives a reload; the turn does (§1.12).
func test_herstel_uit_ctx_data() -> void:
	_op()
	var gasten := _gasten(4)
	waar(Games.start(ID), "het spel start")
	waar(await _wacht(_kaart_staat), "de vraagkaart staat er")
	var l := int(_beurt()["L"])
	waar(_druk(_juist_nu()), "één etappe")
	waar(await _wacht(_kaart_staat), "de tweede kaart staat er")
	var p := int(_beurt()["p"])
	waar(p > 0, "hij ligt halverwege (%d m)" % p)
	Games.stop()
	await _frames(2)
	# stop() never leaves anybody afloat (§1.12)
	var d = World.dier(str(gasten[0]["id"]))
	waar(d.z > float(Rooms.get_kamer(ID).bad["z1"]), "niemand blijft in het water liggen")
	# start again: the saved turn is picked up where it was.  Sinds N3 komt de
	# vraag eerst: hij staat nog dróóg op het dek en gaat pas met het eerste
	# antwoord terug het water in, op zijn eigen meter (PLAN N3 stap 1).
	waar(Games.start(ID), "het spel start opnieuw")
	waar(await _wacht(_kaart_staat), "en de vraagkaart is terug")
	gelijk(int(_beurt()["p"]), p, "op dezelfde meter")
	gelijk(int(_beurt()["L"]), l, "met dezelfde baan")
	var kaart := _kaart_knoop()
	if kaart != null:
		gelijk(kaart.som_label.text, ZwembadBeurt.som_verder(l, p), "en de som klopt nog")
	d = World.dier(str(gasten[0]["id"]))
	waar(d.z > float(Rooms.get_kamer(ID).bad["z1"]), "hij wacht nog droog op het dek")
	gelijk(d.hoogte, 0.0, "op de vloer, niet in het water")
	# het antwoord legt hem terug op de bewaarde meter en zwemt vandaar verder
	waar(_druk(_juist_nu()), "het antwoord op de hervatte vraag")
	waar(await _wacht(func() -> bool: return not _klaar().is_empty() or _kaart_staat(), 8000),
		"en het spel gaat verder")
	gelijk(int(_beurt()["laatste_p"]), p,
		"hij zwom verder vanaf meter %d, niet vanaf nul" % p)
	gelijk(int(_beurt()["p"]), l, "en kwam aan de overkant")
	gelijk(_klaar(), "precies", "precies, want het was het goede antwoord")
	await _af()

## No guest at all: one sentence, and the game does not open.
func test_zonder_gast_gaat_het_spel_niet_open() -> void:
	_op()
	State.s["gasten"] = []
	State.herbereken()
	Games.registreer(Games.definitie(ID), load("res://games/zwembad/spel.tscn"))
	Games.start(ID)
	await _frames(3)
	gelijk(Games.actief(), "", "er draait geen spel")
	var toast := _laag.get_node_or_null("Toast")
	waar(toast != null, "er staat een toast")
	if toast != null:
		gelijk(_eerste_label(toast), ZwembadBeurt.GEEN_GAST, "en die zegt het woordelijk")
	await _af()

func _eerste_label(k: Node) -> String:
	for kind in k.get_children():
		if kind is Label:
			return (kind as Label).text
		var diep := _eerste_label(kind)
		if not diep.is_empty():
			return diep
	return ""

# ----------------------------------------------------------------- opruimen

## `stop()` leaves the world exactly as it found it (§1.12, §12.2).
func test_stop_laat_de_wereld_schoon_achter() -> void:
	_op()
	var gasten := _gasten(4)
	waar(Games.start(ID), "het spel start")
	waar(await _wacht(_kaart_staat), "de vraagkaart staat er")
	waar(not World.decor_lijst(ID).is_empty(), "er ligt eigen decor")
	Games.stop()
	await _frames(2)
	gelijk(Games.actief(), "", "er draait niets meer")
	for stuk in World.decor_lijst():
		waar(str(stuk.get("door", "")) != ID, "geen eigen decor bleef staan: %s" % stuk["id"])
	for id in Hits.lijst():
		waar(Hits.spot(id).door != ID, "geen eigen hotspot bleef staan: %s" % id)
	for id in [KAART, STROOK, VLAG_TAG, GAST_TAG, "zb_wolk",
			Ui.MIS_WOLK + Ui.MIS_DIER + str(gasten[0]["id"])]:
		waar(Hits.spot(id) == null, "%s is weg" % id)
	var d = World.dier(str(gasten[0]["id"]))
	waar(d.z > float(Rooms.get_kamer(ID).bad["z1"]), "de gast staat op het dek")
	gelijk(d.hoogte, 0.0, "en op de vloer, niet in het water")
	await _af()

# ------------------------------------------------------- knoppen op voorwerpen

## `Hits.dekking` is 0 % for every button on an object, in the four ticket
## frames, and nothing is placed `krap` (architecture.md §4.3, §12.2).
func test_geen_knop_staat_op_een_voorwerp() -> void:
	for kader in KADERS:
		_op(kader)
		_gasten(4)
		waar(Games.start(ID), "het spel start bij kader %s" % str(kader))
		waar(await _wacht(_kaart_staat), "de vraagkaart staat er bij %s" % str(kader))
		await _frames(2)
		var dbg := Hits.debug()
		var met_vlak := 0
		for id in dbg.keys():
			var a: Dictionary = dbg[id]
			var r: Rect2 = a["rect"]
			waar(not bool(a["krap"]), "%s: %s vond een echte plek" % [str(kader), id])
			waar(r.position.x >= 0.0 and r.position.y >= 0.0
					and r.end.x <= kader.x + 0.01 and r.end.y <= kader.y + 0.01,
				"%s: %s staat in het kader (%s)" % [str(kader), id, str(r)])
			var v: Rect2 = a["vlak"]
			if v.size.x > 0.0 and v.size.y > 0.0:
				met_vlak += 1
			if int(a["laag"]) == Hits.Laag.VAST:
				continue
			var aan := str(a.get("op", "")) == "aan"     # a hotel button ON its own thing
			waar(aan or Hits.dekking(id) <= 0.0,
				"%s: %s dekt zijn voorwerp niet" % [str(kader), id])
			for ander in dbg.keys():
				var vv: Rect2 = dbg[ander]["vlak"]
				if vv.size.x <= 0.0 or (aan and vv.is_equal_approx(a["vlak"])):
					continue
				var snij := r.intersection(vv)
				gelijk(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y), 0.0,
					"%s: %s staat op het voorwerp van %s" % [str(kader), id, ander])
		waar(met_vlak >= 1, "%s: minstens één knop kent zijn voorwerp" % str(kader))
		# and the card really keeps its 8 px from the swimmer and from the flag
		var s := Hits.spot(KAART)
		if s != null and is_instance_valid(s.knoop):
			var kr: Rect2 = dbg[KAART]["rect"]
			var gast := World.vlak_van_dier(str(State.s["gasten"][0]["id"]))
			waar(ZwembadKaartplek.lucht(kr, gast) >= ZwembadKaartplek.MARGE
					- ZwembadKaartplek.EPS,
				"%s: %.1f px tussen de kaart en de zwemmer"
					% [str(kader), ZwembadKaartplek.lucht(kr, gast)])
			var vt: Dictionary = Hits.debug().get(VLAG_TAG, {})
			if not vt.is_empty():
				var vr: Rect2 = vt["rect"]
				waar(ZwembadKaartplek.lucht(kr, vr) >= ZwembadKaartplek.MARGE
						- ZwembadKaartplek.EPS,
					"%s: %.1f px tussen de kaart en het vlagcijfer"
						% [str(kader), ZwembadKaartplek.lucht(kr, vr)])
		await _af()

# ------------------------------------------------------------ eigen modellen

## The two models are the game's own, namespaced, and they bake.
func test_eigen_modellen_bakken() -> void:
	Art.registreer_model("zwembad_streep", ZwembadModellen.streep)
	Art.registreer_model("zwembad_vlag", ZwembadModellen.vlag)
	waar(Art.heeft_model("zwembad_streep"), "de meterstreep is geregistreerd")
	waar(Art.heeft_model("zwembad_vlag"), "de vlag ook")
	waar(not Art.is_wereldmodel("zwembad_streep"), "en het is geen wereldmodel")
	for params in [{"groot": true}, {"groot": false}, {"groot": true, "gehaald": true}]:
		var p = Art.plaat("zwembad_streep", 3, params)
		waar(p != null and p.w > 0 and p.h > 0,
			"de streep bakt met %s (%s)" % [str(params), str(p)])
	# no pale ghost marker and no lit marker any more (owner, 2026-09-24)
	gelijk(str(ZwembadModellen.streep({"groot": true, "bleek": true, "licht": true})),
		str(ZwembadModellen.streep({"groot": true})), "bleek en licht tekenen niets anders")
	var v = Art.plaat("zwembad_vlag", 3, {})
	waar(v != null and v.w > 0 and v.h > 0, "de vlag bakt")
	# the marker never wears the almost white of the stone rim
	for vox in ZwembadModellen.streep({"groot": true}):
		var kl: Color = vox["k"]
		waar(kl != Color("#EDEFF6"), "de streep is blauw, niet steenkleurig")
	# a passed marker differs from a white one in the knob's colour only
	var ge: Array = ZwembadModellen.streep({"groot": true, "gehaald": true})
	var wit: Array = ZwembadModellen.streep({"groot": true})
	gelijk(ge.size(), wit.size(), "gehaald verandert geen enkele voxel")
	waar(ge != wit, "de gehaalde knop draagt de vlagkleur")

## The rim carries bare numbers on the big markers only, and never two labels
## closer than 34 px together (§1.9).
func test_de_meterstrepen_en_hun_cijfers() -> void:
	_op()
	_gasten(4)
	waar(Games.start(ID), "het spel start")
	await _frames(3)
	var b := _beurt()
	var l := int(b["L"])
	var stap := int(b["stap"])
	var bad: Dictionary = Rooms.get_kamer(ID).bad
	var m := 0
	while m < l:
		waar(not World.decor_plek("zb_streep_%d" % m, ID).is_empty(),
			"er staat een streep op %d m" % m)
		m += stap
	waar(World.decor_plek("zb_streep_%d" % l, ID).is_empty(),
		"maar geen streep óp de vlag")
	waar(not World.decor_plek("zb_vlag", ID).is_empty(), "de vlag staat op %d m" % l)
	waar(Hits.spot(VLAG_TAG) != null, "met '%d m' erop" % l)
	var k := float(World.schaal()["k"])
	var lstap := ZwembadBeurt.label_stap(l, stap, bad, k)
	var vorig := -9999.0
	for i in range(0, l, stap):
		var s := Hits.spot("zb_label_%d" % i)
		if s == null:
			continue
		waar(i % lstap == 0, "een cijfer staat alleen op een labelstap (%d)" % i)
		var x := ZwembadBeurt.baan_x(bad, l, i) * 2.0 * k
		waar(x - vorig >= 34.0 - 0.01,
			"twee cijfers staan minstens 34 px uit elkaar (%d, %.1f)" % [i, x - vorig])
		vorig = x
	await _af()

## Eigenaar (2026-09-16): "de duikplek van het zwembad zit door een hek heen".
## Meterstrepen en vlag liggen daarom állemaal binnen het hek, vóór het water —
## en de wandeling naar de start van de baan raakt het water niet en snijdt
## nooit door een hek.  Het zwembadhek staat op de eigen `hek_x`/`hek_z` van
## de kamer (2026-09-17: verder van het water af).  De oude instapvlonder is
## weg (2026-09-17: "haal de oude houten plank weg"); de instap is het
## startblok geworden.
func test_duikplek_ligt_binnen_het_hek() -> void:
	_op()
	var kamer = Rooms.get_kamer(ID)
	var bad: Dictionary = kamer.bad
	var mat_aanwezig := false
	for stuk in kamer.decor:
		if stuk["n"] == "mat":
			mat_aanwezig = true
	waar(not mat_aanwezig, "de oude houten instapvlonder is weg")
	var gasten := _gasten(4)
	waar(Games.start(ID), "het spel start")
	waar(await _wacht(_kaart_staat), "de vraagkaart staat er")
	var vlag := World.decor_plek("zb_vlag", ID)
	waar(not vlag.is_empty(), "de vlag staat op de finish")
	waar(float(vlag["z"]) > float(bad["z1"]), "de vlag staat vóór het water")
	waar(float(vlag["x"]) > int(kamer.hek_x) and float(vlag["z"]) > int(kamer.hek_z),
		"en de vlag staat binnen het hek")
	for stuk in World.decor_lijst(ID):
		var did := str(stuk.get("id", ""))
		if did.begins_with("zb_streep_"):
			waar(float(stuk["z"]) > float(bad["z1"]),
				"%s staat vóór het water in plaats van in het hek" % did)
			waar(float(stuk["x"]) > int(kamer.hek_x), "%s staat binnen het hek" % did)
	# de instap: de baan begint bij het westeinde, op het startblok; vanaf
	# het dek is de wandeling naar de trappenvoet een rechte streep die het
	# water niet raakt en binnen het hek blijft
	var voet := Vector2(ZwembadBeurt.trap_voet(bad), ZwembadBeurt.baan_z(bad))
	var dekplek: Vector2 = kamer.dek["start"]
	waar(voet.x > int(kamer.hek_x) and voet.y > int(kamer.hek_z),
		"de trappenvoet ligt binnen het hek")
	waar(Rooms.om_het_water(ID, dekplek, voet).is_empty(),
		"de wandeling naar de trappenvoet is een rechte streep")
	waar(World.dier(str(gasten[0]["id"])) != null, "de gast staat klaar op het dek")
	await _af()

## Eigenaar (2026-09-17): "startblokken ... met een trappetje zodat het dier
## langzaam omhoog kan springen" en "Maak het startblok groter en doe 1 ipv
## 3".  Eén groot blok staat op het terras tussen het verplaatste hek en het
## water, op de baan.  De trappenvoet ligt droog, het duikpunt in het water,
## en de duik start aan de voorkant van het blok zodat hij het blok niet raakt.
func test_startblokken_staan_klaar() -> void:
	_op()
	var kamer = Rooms.get_kamer(ID)
	var bad: Dictionary = kamer.bad
	var blokken := []
	for stuk in kamer.decor:
		if stuk["n"] == "startblok":
			blokken.append(stuk)
	gelijk(blokken.size(), 1, "één startblok langs de baan")
	var blok: Dictionary = blokken[0]
	waar(int(blok["x"]) > int(kamer.hek_x), "het blok staat binnen het zijhek")
	waar(int(blok["z"]) > int(bad["z0"]) and int(blok["z"]) < int(bad["z1"]),
		"en het blok ligt naast de baan")
	waar(absf(float(blok["x"]) - ZwembadBeurt.blok_x(bad)) < 0.5
			and absf(float(blok["z"]) - ZwembadBeurt.baan_z(bad)) < 0.5,
		"het blok staat op de baan")
	# de trappenvoet ligt droog en binnen het hek
	var voet := ZwembadBeurt.trap_voet(bad)
	waar(voet > float(kamer.hek_x), "de trappenvoet ligt binnen het hek")
	waar(Rooms.om_het_water(ID, kamer.dek["start"], Vector2(voet, ZwembadBeurt.baan_z(bad))).is_empty(),
		"de wandeling naar de trappenvoet raakt het water niet")
	# de laatste hop landt aan de voorkant van het blok, vóór het water, en de
	# duik komt in het water bij de 0-meter
	var hop := ZwembadBeurt.trap_hoppen(bad)
	var laatste: Array = hop[hop.size() - 1]
	waar(float(laatste[0]) < float(bad["x0"]),
		"de laatste hop landt nog op het blok, vóór het water")
	waar(float(laatste[1]) > 0.0, "en die hop staat omhoog op het blok")
	var duik := Vector2(ZwembadBeurt.duik_x(bad), ZwembadBeurt.baan_z(bad))
	waar(duik.x >= float(bad["x0"]), "het duikpunt ligt in het water")
	await _af()

## Elke meterstreep die hij gezwommen is kleurt zijn knop roze als de vlag; de
## strepen vóór hem blijven wit.  De getallenlijn laat dus zien hoe ver hij is
## en hoeveel er nog over is ("tel de strepen tot de vlag").
func test_gehaalde_strepen_kleuren_mee() -> void:
	_op()
	_gasten(1)
	gelijk(State.band(), 3, "één gast baant weg op band 3")
	Ui.zet_rust_modus(true)          # de zwemtocht kost geen muurkloktijd
	waar(Games.start(ID), "het spel start")
	waar(await _wacht(_kaart_staat, 20000), "de vraagkaart staat er")
	waar(_druk(_juist_nu()), "één eerlijke slag")
	waar(await _wacht(_kaart_staat, 20000), "de tweede kaart staat er")
	var p := int(_beurt()["p"])
	var Strepen := "zb_streep_".length()
	var alle := 0
	var gehaald := 0
	for stuk in World.decor_lijst(ID):
		var id := str(stuk.get("id", ""))
		if not id.begins_with("zb_streep_"):
			continue
		var m := int(id.substr(Strepen))
		var par: Dictionary = stuk.get("params", {})
		var ge := bool(par.get("gehaald", false))
		waar(ge == (m > 0 and m <= p),
			"streep op %d m is %s (hij ligt op %d m)"
			% [m, "gehaald" if ge else "nog wit", p])
		alle += 1
		if ge:
			gehaald += 1
	waar(alle > 0, "er staan meterstrepen in de bak")
	waar(gehaald >= 1, "minstens één streep is gehaald en roos")
	waar(alle - gehaald >= 1, "en minstens één vóór hem is nog wit")
	await _af()

## Na een te korte slag licht er niets op (eigenaar 2026-09-24: geen hulp na
## een fout): geen enkele streep vóór de vlag gloeit, en wat hij al zwom houdt
## gewoon zijn roze knop.
func test_na_een_misser_licht_niets_op() -> void:
	_op()
	_gasten(1)
	gelijk(State.band(), 3, "één gast baant weg op band 3")
	Ui.zet_rust_modus(true)          # de zwemtocht kost geen muurkloktijd
	waar(Games.start(ID), "het spel start")
	waar(await _wacht(_kaart_staat, 20000), "de vraagkaart staat er")
	waar(_druk(_kort_antwoord()), "één te korte slag")
	waar(await _wacht(_kaart_staat, 20000), "de tweede kaart staat er")
	gelijk(int(_beurt()["misser"]), 1, "het ís de eerste misser")
	var p := int(_beurt()["p"])
	var Strepen := "zb_streep_".length()
	var strepen := 0
	for stuk in World.decor_lijst(ID):
		var id := str(stuk.get("id", ""))
		if not id.begins_with("zb_streep_"):
			continue
		strepen += 1
		var m := int(id.substr(Strepen))
		var par: Dictionary = stuk.get("params", {})
		waar(not bool(par.get("licht", false)), "streep op %d m licht niet op" % m)
		var ge := bool(par.get("gehaald", false))
		waar(ge == (m > 0 and m <= p), "streep op %d m is %s (hij ligt op %d m)"
			% [m, "gehaald" if ge else "nog wit", p])
	waar(strepen >= 1, "er liggen strepen op de rand")
	await _af()

# ------------------------------------------------------ het dier van de beurt

## "Een methode om te wisselen met welk dier je de spellen speelt" (owner,
## 2026-09-23): every guest with a bed may swim, in check-in order; the game
## still picks its own swimmer; the animal on the game bar hands the lane to the
## next one in a fresh turn — the one who was swimming is out of the water and
## nothing was taken away — and the next start swims with the animal the child
## picked, as long as that one may swim.
func test_het_kind_kiest_wie_er_zwemt() -> void:
	_op()
	var gasten := _gasten(4)
	var ids: Array[String] = []
	for g in gasten:
		ids.append(str(g["id"]))
	waar(Games.start(ID), "het spel start")
	waar(await _wacht(_kaart_staat), "de vraagkaart staat er")
	gelijk(str(Games.spelers()), str(ids), "wie mag zwemmen: iedereen met een bed, op volgorde")
	gelijk(Games.speler(), ids[0], "het spel kiest zelf, zoals altijd: wie al bij het water staat")
	waar(_druk(_juist_nu()), "één etappe")
	waar(await _wacht(_kaart_staat), "de tweede kaart staat er")
	waar(int(_beurt()["p"]) > 0, "hij is halverwege (%d m)" % int(_beurt()["p"]))
	var sterren := int(State.s["sterren"])
	var munten := int(State.s["munten"])
	waar(Games.wissel_speler(), "het dier op de balk geeft de beurt door")
	waar(await _wacht(_kaart_staat), "en er staat meteen een vraag")
	gelijk(Games.actief(), ID, "het zwembad draait nog")
	gelijk(Games.speler(), ids[1], "nu zwemt de volgende")
	gelijk(str(_beurt()["gast"]), ids[1], "in een eigen beurt")
	gelijk(int(_beurt()["p"]), 0, "die vooraan begint")
	gelijk(int(_beurt()["misser"]), 0, "zonder missers")
	gelijk(_klaar(), "", "en nog niet af is")
	gelijk(int(State.s["sterren"]), sterren, "er ging geen ster af")
	gelijk(int(State.s["munten"]), munten, "en geen munt")
	var d = World.dier(ids[0])
	waar(d != null and d.z > float(Rooms.get_kamer(ID).bad["z1"]),
		"wie zwom, ligt niet meer in het water")
	# the lane is the new swimmer's: the next card names him
	waar(_druk(_juist_nu()), "een etappe voor de nieuwe zwemmer")
	waar(await _wacht(func() -> bool: return _kaart_staat() or not _klaar().is_empty(), 8000),
		"en het spel gaat verder")
	gelijk(int(_beurt()["laatste_p"]), 0, "hij zwom vanaf nul, niet vanaf de meter van de vorige")
	if _klaar().is_empty():
		var kaart := _kaart_knoop()
		waar(kaart != null and kaart.regel_label.text.contains(str(gasten[1]["naam"])),
			"de kaart noemt hem: %s" % (kaart.regel_label.text if kaart != null else "geen kaart"))
	# the next start swims with the animal the child picked ...
	Games.stop()
	await _frames(2)
	waar(Games.start(ID), "het spel start opnieuw")
	gelijk(Games.speler(), ids[1], "met het gekozen dier, op zijn eigen baan")
	Games.stop()
	await _frames(2)
	# ... not with one who may not swim: then the game picks, as always
	gasten[1]["bed"] = ""
	State.spel_data(ID).clear()
	waar(Games.start(ID), "en nog eens, nu de gekozen gast geen bed meer heeft")
	gelijk(Games.speler(), ids[0], "dan kiest het spel zelf")
	await _af()

# ------------------------------------------- de bots en de verre wand (2026-09-23)

## Owner, 2026-09-23: "Bij stoten moet de speler ook opnieuw rekenen met een
## andere afstand".  The metre the wall throws him back to, for every lane of
## every band, from every metre and every stroke: never the same distance
## again, never on or past the wall, never behind the start, one stroke from
## the wall, far enough that his nose is clear of it, ahead of where he began
## whenever there is room — and the same throw every time.
func test_de_botsplek_volgt_de_regel() -> void:
	var bad: Dictionary = Rooms.get_kamer(ID).bad
	var banen := {}
	for band in [3, 4, 5]:
		for n in range(1, 13):
			for dag in range(1, 9):
				var baan := Sommen.Zwembad.baan(n, band, dag)
				banen["%d|%d" % [int(baan["L"]), int(baan["M"])]] = baan
	var geteld := 0
	for sleutel in banen:
		var l := int(banen[sleutel]["L"])
		var m := int(banen[sleutel]["M"])
		var lo := ceili(l / 5.0)
		for p_voor in range(0, l):
			for leg in range(1, 5):
				var p := ZwembadBeurt.bots_plek(l, m, p_voor, leg)
				var wat := "L=%d M=%d p=%d leg=%d -> %d" % [l, m, p_voor, leg, p]
				gelijk(ZwembadBeurt.bots_plek(l, m, p_voor, leg), p, "steeds dezelfde worp: " + wat)
				waar(p >= 1 and p <= l - 1, "in de baan, niet op de wand of voor de start: " + wat)
				waar(p != p_voor, "een andere plek dan vóór de slag: " + wat)
				waar(l - p <= m, "de nieuwe rest past in één slag: " + wat)
				waar(ZwembadBeurt.baan_x(bad, l, p) + ZwembadBeurt.NEUS
						<= float(bad["x1"]) - 4.0, "zijn neus is los van de wand: " + wat)
				if l - p_voor - 1 >= lo:
					waar(p > p_voor, "hij houdt wat hij zwom: " + wat)
				else:
					gelijk(l - p, lo if lo != l - p_voor else lo + 1,
						"dicht bij de wand: de kleinste worp terug: " + wat)
				geteld += 1
	waar(geteld > 1000, "alle banen, alle meters (%d)" % geteld)
	# the worked example of games-b.md §1.7: 16 m, max 10, after the first 10 m
	gelijk(ZwembadBeurt.bots_plek(16, 10, 10, 2), 11, "16 m, na 10 m te ver: terug naar 11 m")

## A stroke that ends at the far wall stops with his NOSE against it: one point
## per metre, the last one where his paws are when the nose touches, never
## past it, never backwards — and a stroke that stops short of the wall keeps
## the plain number line (§1.6).
func test_een_slag_tot_de_wand_stopt_met_de_neus_ertegen() -> void:
	var bad: Dictionary = Rooms.get_kamer(ID).bad
	var wand := ZwembadBeurt.wand_x(bad)
	gelijk(wand, float(bad["x1"]) - ZwembadBeurt.NEUS, "de neus raakt de wand")
	for l in [8, 12, 16, 20, 31, 46, 53, 80]:
		for p0 in range(0, l):
			var x_nu := ZwembadBeurt.baan_x(bad, l, p0)
			var tot := ZwembadBeurt.slag_x(bad, l, p0, l - p0, x_nu)
			var alles: Array = (tot["snel"] as Array) + (tot["traag"] as Array)
			var wat := "L=%d p0=%d" % [l, p0]
			gelijk(alles.size(), l - p0, "één punt per meter: " + wat)
			var vorig := x_nu
			for x in alles:
				waar(float(x) >= vorig - 0.001, "nooit achteruit: " + wat)
				waar(float(x) <= maxf(wand, x_nu) + 0.001, "nooit voorbij de wand: " + wat)
				vorig = float(x)
			if x_nu < wand:
				waar(absf(float(alles[alles.size() - 1]) - wand) < 0.001,
					"de laatste meter is de neus tegen de wand: " + wat)
				waar(not (tot["traag"] as Array).is_empty(), "het laatste stuk gaat traag: " + wat)
			if p0 + 1 < l:
				var kort := ZwembadBeurt.slag_x(bad, l, p0, 1, x_nu)
				gelijk(str(kort["snel"]), str([ZwembadBeurt.baan_x(bad, l, p0 + 1)]),
					"een slag die de wand niet haalt blijft op de getallenlijn: " + wat)

## Owner, 2026-09-23: "Getallen boven 10 klikken wordt niet afgehandeld".  Every
## value the strip offers is tapped the way a finger taps it — a real press
## and release pushed into the real shell, at the four ticket screens, on the
## first card and on the card after the first stroke, in all three bands —
## and every tap reaches the game.  At the first screen it also swims what
## the frozen core says it swims: short and exact that far, too much only M,
## too far to the wall and back to `bots_plek`.
func test_elke_knop_op_de_strook_werkt() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var scherm_terug = Ui.get("_scherm")
	# a real press is the child's first touch: the shell unlocks the sound on
	# it (architecture.md §8), and that has to be undone for the next file
	var wakker_voor := Snd.ontgrendeld()
	var rust_voor := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	var boom := Engine.get_main_loop() as SceneTree
	var getikt := 0
	var boven_tien := 0
	for maat in [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740),
			Vector2i(740, 360)]:
		var vp := SubViewport.new()
		vp.size = maat
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		boom.root.add_child(vp)
		var shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		shell.set_meta("geen_start", true)
		vp.add_child(shell)
		for _f in 4:
			await boom.process_frame
		for rij in [[1, 3, 3], [4, 3, 4], [7, 5, 5]]:
			State.nieuw_spel()
			State.s["taken"] = []
			var gasten := _gasten(int(rij[0]), int(rij[1]))
			gelijk(State.band(), int(rij[2]), "%s: band %d" % [str(maat), rij[2]])
			var baan := Sommen.Zwembad.baan(State.n_gasten(), State.band(), int(State.s["dag"]))
			var l := int(baan["L"])
			var m := int(baan["M"])
			for p0 in ([0, m] if m < l else [0]):
				for k in 4:
					var wat := "%s band %d p=%d knop %d" % [str(maat), rij[2], p0, k]
					Games.stop()
					await boom.process_frame
					var d := State.spel_data(ID)
					d.clear()
					if p0 > 0:
						# the card after the first stroke: a saved turn half way (§1.12)
						d.merge({"gast": str(gasten[0]["id"]), "wens": false, "L": l,
							"M": m, "band": int(rij[2]), "p": p0, "leg": 1, "misser": 0,
							"laatste_p": 0, "laatste_rest": l, "klaar": ""}, true)
					waar(Games.start(ID), wat + ": het spel start")
					if not await _wacht(_kaart_staat):
						fout(wat + ": geen strook")
						continue
					for _f in 3:
						await boom.process_frame
					gelijk(int(_beurt()["p"]), p0, wat + ": hij ligt op meter %d" % p0)
					var rij_knoppen := Hits.spot(STROOK).knoop.get_node_or_null("Rij")
					var knop := rij_knoppen.get_child(k) as Button
					var n := int(str(knop.name).substr(2))
					if n > 10:
						boven_tien += 1
					var midden := knop.get_global_rect().get_center()
					var ingedrukt := [0]
					knop.pressed.connect(func() -> void: ingedrukt[0] += 1)
					var leg_voor := int(_beurt()["leg"])
					await _tik(vp, midden)
					gelijk(ingedrukt[0], 1, wat + ": de vinger op %d m drukt de knop in" % n)
					gelijk(int(_beurt()["leg"]), leg_voor + 1, wat + ": het spel telt de tik op %d" % n)
					getikt += 1
					if maat != Vector2i(1024, 768):
						continue
					# what the stroke did — straight from the frozen core
					var slag := Sommen.Zwembad.slag(l, m, p0, n)
					var verwacht: int = p0 + int(slag["meters"])
					if str(slag["soort"]) == "ver":
						verwacht = ZwembadBeurt.bots_plek(l, m, p0, leg_voor + 1)
					waar(await _wacht(func() -> bool: return _kaart_staat() or not _klaar().is_empty(),
						6000), wat + ": daarna een nieuwe vraag of de overkant")
					gelijk(int(_beurt()["p"]), verwacht,
						wat + ": %d m (%s) brengt hem op meter %d" % [n, slag["soort"], verwacht])
		Games.stop()
		Ui.naamplaten_leeg()
		Hits.wis_alles()
		vp.queue_free()
		await boom.process_frame
		Ui.registreer_lagen(null, null, null)
	waar(getikt >= 80, "alle knoppen op alle schermen (%d tikken)" % getikt)
	waar(boven_tien >= 40, "en daarvan veel boven de 10 (%d)" % boven_tien)
	State.s = bewaard
	Ui.set("_scherm", scherm_terug)
	Ui.zet_rust_modus(rust_voor)
	Snd.set("_wakker", wakker_voor)
	Snd.sfeer()
	for dier in World.dieren():
		World.weg(dier.id)

## A real finger: over the button, down, a frame, up — through the viewport's
## own GUI input, so whatever lies on top of the button gets the tap instead.
func _tik(vp: SubViewport, punt: Vector2) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var mm := InputEventMouseMotion.new()
	mm.position = punt
	mm.global_position = punt
	vp.push_input(mm)
	await boom.process_frame
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT
	mb.position = punt
	mb.global_position = punt
	vp.push_input(mb)
	await boom.process_frame
	var los := InputEventMouseButton.new()
	los.button_index = MOUSE_BUTTON_LEFT
	los.pressed = false
	los.position = punt
	los.global_position = punt
	vp.push_input(los)
	await boom.process_frame

## Reduced motion (games-b.md §0.11): the same bump, the same outcome, no
## animation — he is on his new metre at once, there is not one particle, the
## 💛 Au! still stands its full time, and then the new sum comes.
func test_de_bots_in_rustmodus() -> void:
	_op()
	var gasten := _gasten(4)
	var sterren := int(State.s["sterren"])
	waar(Ui.rust_modus(), "de rust staat aan")
	waar(Games.start(ID), "het spel start")
	waar(await _wacht(_kaart_staat), "de vraagkaart staat er")
	var l := int(_beurt()["L"])
	var m := int(_beurt()["M"])
	waar(_druk(_juist_nu()), "eerst netjes %d m" % m)
	waar(await _wacht(_kaart_staat), "de tweede kaart staat er")
	var p_voor := int(_beurt()["p"])
	var leg := int(_beurt()["leg"]) + 1
	var ver := _ver_antwoord()
	waar(ver > 0, "er staat een te verre knop (%d)" % ver)
	var t0 := Time.get_ticks_msec()
	waar(_druk(ver), "te ver getikt")
	await _frames(2)
	var p_na := ZwembadBeurt.bots_plek(l, m, p_voor, leg)
	gelijk(int(_beurt()["p"]), p_na, "de bewaarde beurt staat meteen op zijn nieuwe meter")
	var bad: Dictionary = Rooms.get_kamer(ID).bad
	var d = World.dier(str(gasten[0]["id"]))
	var wand := ZwembadBeurt.wand_x(bad)
	var doel := ZwembadBeurt.baan_x(bad, l, p_na)
	waar(absf(d.x - wand) < 0.01, "stilstaand beeld 1: hij ligt met zijn neus tegen de wand (x=%.1f)"
		% d.x)
	waar(Hits.spot("zb_wolk") != null, "met 💛 Au!")
	gelijk(World.deeltjes().size(), 0, "geen enkel deeltje in rustmodus")
	var gezien_deeltje := false
	var tussendoor := false
	while not _kaart_staat() and Time.get_ticks_msec() - t0 < 6000:
		await _frames(1)
		if not World.deeltjes().is_empty():
			gezien_deeltje = true
		if absf(d.x - wand) > 0.01 and absf(d.x - doel) > 0.01:
			tussendoor = true
	waar(_kaart_staat(), "de nieuwe vraag komt")
	waar(absf(d.x - doel) < 0.01, "stilstaand beeld 2: hij drijft op meter %d (x=%.1f, doel %.1f)"
		% [p_na, d.x, doel])
	waar(not tussendoor, "en er zat geen beweging tussen")
	waar(not gezien_deeltje, "en er spatte niets")
	waar(Time.get_ticks_msec() - t0 >= 1150, "💛 Au! hield zijn volle tijd (%d ms)"
		% (Time.get_ticks_msec() - t0))
	var kaart := _kaart_knoop()
	if kaart != null:
		gelijk(kaart.som_label.text, ZwembadBeurt.som_verder(l, p_na), "met de som vanaf daar")
	gelijk(int(State.s["sterren"]), sterren, "geen ster weg, geen ster erbij")
	gelijk(_klaar(), "", "en de beurt loopt door")
	await _af()

## The bump as the child sees it, in real motion: he brakes into the far wall
## and stops with his nose against it (never past it), 💛 Au! stands while he
## bonks and wobbles there, the wall pushes him back with the number on his
## back counting down to his new metre, and he ends afloat on that metre,
## facing the wall again.  From the touch on, the save already says where he
## will end up.
func test_de_bots_als_film() -> void:
	_op()
	var gasten := _gasten(1)
	Ui.zet_rust_modus(false)
	waar(Games.start(ID), "het spel start")
	waar(await _wacht(_kaart_staat, 20000), "de vraagkaart staat er")
	waar(_druk(_juist_nu()), "eerst de eerlijke slag")
	waar(await _wacht(_kaart_staat, 20000), "de tweede kaart staat er")
	var l := int(_beurt()["L"])
	var m := int(_beurt()["M"])
	var p_voor := int(_beurt()["p"])
	var leg := int(_beurt()["leg"]) + 1
	var p_na := ZwembadBeurt.bots_plek(l, m, p_voor, leg)
	var bad: Dictionary = Rooms.get_kamer(ID).bad
	var wand := ZwembadBeurt.wand_x(bad)
	var doel := ZwembadBeurt.baan_x(bad, l, p_na)
	var ver := _ver_antwoord()
	waar(ver > 0, "er staat een te verre knop (%d)" % ver)
	var id := str(gasten[0]["id"])
	var boom := Engine.get_main_loop() as SceneTree
	var t0 := Time.get_ticks_msec()
	waar(_druk(ver), "te ver getikt")
	var verste := -INF
	var raak_t := -1
	var wolk_weg_t := -1
	var x_bij_wolk: Array = []
	var p_bij_raak := -1
	var cijfers: Array = []
	while Time.get_ticks_msec() - t0 < 20000 and not _kaart_staat():
		await boom.process_frame
		var d = World.dier(id)
		verste = maxf(verste, d.x)
		var wolk := Hits.spot("zb_wolk") != null
		if raak_t < 0 and wolk:
			raak_t = Time.get_ticks_msec()
			p_bij_raak = int(_beurt()["p"])
		if raak_t >= 0 and wolk_weg_t < 0:
			if wolk:
				x_bij_wolk.append(d.x)
			else:
				wolk_weg_t = Time.get_ticks_msec()
		var tag := Hits.spot(GAST_TAG)
		if tag != null and is_instance_valid(tag.knoop):
			var tekst := str((tag.knoop as Label).text)
			if cijfers.is_empty() or cijfers[cijfers.size() - 1] != tekst:
				cijfers.append(tekst)
	Ui.zet_rust_modus(true)
	waar(_kaart_staat(), "de nieuwe vraag komt")
	waar(verste <= wand + 0.01, "hij zwom nooit voorbij de wand (verste x=%.2f, wand %.2f)"
		% [verste, wand])
	waar(verste >= wand - 0.01, "maar wel met zijn neus ertegen (%.2f)" % verste)
	waar(raak_t >= 0, "💛 Au! kwam bij de aanraking")
	gelijk(p_bij_raak, p_na, "vanaf de aanraking staat zijn nieuwe meter al in de opslag")
	waar(wolk_weg_t - raak_t >= 1100 and wolk_weg_t - raak_t <= 1700,
		"💛 Au! stond %d ms (spec: 1200)" % (wolk_weg_t - raak_t))
	var stil := true
	for x in x_bij_wolk:
		if absf(float(x) - wand) > 0.01:
			stil = false
	waar(stil, "zolang 💛 Au! er staat, ligt hij stil tegen de wand")
	waar(cijfers.has("%d m" % l), "het getal op zijn rug haalde %d m" % l)
	var terug := cijfers.slice(cijfers.find("%d m" % l))
	var verwacht: Array = []
	for metre in range(l, p_na - 1, -1):
		verwacht.append("%d m" % metre)
	gelijk(str(terug), str(verwacht), "en telde terug tot zijn nieuwe meter")
	var d = World.dier(id)
	waar(absf(d.x - doel) <= 0.5, "hij drijft op meter %d (x=%.1f, doel %.1f)" % [p_na, d.x, doel])
	gelijk(d.face, 1, "met zijn neus weer naar de wand")
	gelijk(str(d.staat), "zwem", "en drijvend")
	gelijk(_klaar(), "", "de beurt loopt door")
	await _af()

## Out of the water at the end of a lane: he hops out onto the deck and stands
## ON it, at his deck spot beside the finish flag — not sunk to the dive's
## depth in the tiles, and not inside the flag's foot.
func test_na_de_overkant_staat_hij_op_het_dek() -> void:
	_op()
	var gasten := _gasten(1)
	Ui.zet_rust_modus(false)
	waar(Games.start(ID), "het spel start")
	var t0 := Time.get_ticks_msec()
	while _klaar().is_empty() and Time.get_ticks_msec() - t0 < 40000:
		if _kaart_staat():
			_druk(_juist_nu())
		await _frames(1)
	gelijk(_klaar(), "precies", "de baan is gezwommen")
	var id := str(gasten[0]["id"])
	var dek: Vector2 = Rooms.get_kamer(ID).dek["over"]
	waar(await _wacht(func() -> bool:
		var d = World.dier(id)
		return d != null and d.staat == "pose" and Vector2(d.x, d.z).distance_to(dek) < 0.5, 8000),
		"hij staat blij op zijn dekplek")
	var d = World.dier(id)
	gelijk(d.hoogte, 0.0, "op het dek, niet op de diepte van de duik")
	var vlag := World.decor_plek("zb_vlag", ID)
	waar(absf(float(vlag["x"]) - d.x) >= 16.0, "en naast de vlag, niet in zijn voet (%.1f)"
		% absf(float(vlag["x"]) - d.x))
	Ui.zet_rust_modus(true)
	await _af()

## Owner, 2026-09-23: "zet het hek aan de bovenste zijkant van het zwembad niet
## aan de korte kant bij de startblokken".  The fence runs along the BACK long
## side of the water, the short side by the startblok is open, the gate's
## rose arch still stands in the line of the side fence, the walk from the
## gate to the stair stays in front of the fence, and no button of the room
## — the gate's, the swimming lesson's — stands on a fence post, on any of
## the four ticket frames.
func test_het_hek_staat_langs_de_lange_kant() -> void:
	var kamer = Rooms.get_kamer(ID)
	var bad: Dictionary = kamer.bad
	var palen: Array = []
	for stuk in kamer.decor:
		if bool(stuk.get("hek", false)):
			palen.append(stuk)
			gelijk(str(stuk["n"]), "hekx", "elk hekstuk loopt langs de lange kant")
			gelijk(int(stuk["z"]), int(kamer.hek_z), "achter het water, op de hekkenlijn")
			waar(int(stuk["z"]) < int(bad["z0"]), "achter de achterrand van het bad")
	waar(not palen.is_empty(), "er staat een hek")
	var eerste := INF
	var laatste := -INF
	for stuk in palen:
		eerste = minf(eerste, float(stuk["x"]))
		laatste = maxf(laatste, float(stuk["x"]) + 12.0)
	waar(eerste <= float(bad["x0"]) + 14.0 and laatste >= float(bad["x1"]),
		"het hek loopt de lange kant langs (%d..%d)" % [eerste, laatste])
	waar(eerste > ZwembadBeurt.blok_x(bad) + 2.0, "en begint pas voorbij het startblok")
	var boog := {}
	for stuk in kamer.decor:
		if stuk["n"] == "rozenboog":
			boog = stuk
	waar(not boog.is_empty() and int(boog["x"]) == int(kamer.hek_x),
		"de rozenboog staat nog in de opening naar de tuin")
	var deur: Dictionary = kamer.deur_punten["tuin"]
	var voet := Vector2(ZwembadBeurt.trap_voet(bad), ZwembadBeurt.baan_z(bad))
	for punt in [Vector2(deur["ix"], deur["iz"]), kamer.dek["start"], voet]:
		waar(punt.y > float(kamer.hek_z) + 10.0, "%s ligt vóór het hek" % str(punt))
	waar(Rooms.om_het_water(ID, kamer.dek["start"], voet).is_empty(),
		"de weg naar de trap blijft een rechte streep")
	# The buttons, on the real shell at the four ticket screens: with nobody
	# in the room, and with a guest waiting on the deck right under the
	# startblok.  In that second case a PHONE has no free side left for the
	# 🏊 button (the guest under the block, his wish over it, the rose arch to
	# the left), so `Hits` hangs it beside the block over the first posts of
	# the fence — the least it can hide.  That is written down in PLAN.md §7
	# (2026-09-23) and checked here as what it is: tablets keep the rule.
	var bewaard: Dictionary = State.s.duplicate(true)
	var scherm_terug = Ui.get("_scherm")
	var rust_voor := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	var boom := Engine.get_main_loop() as SceneTree
	for maat in [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740),
			Vector2i(740, 360)]:
		var vp := SubViewport.new()
		vp.size = maat
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		boom.root.add_child(vp)
		var shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		shell.set_meta("geen_start", true)
		vp.add_child(shell)
		for _f in 4:
			await boom.process_frame
		for wacht_er_een in [false, true]:
			State.nieuw_spel()
			State.s["taken"] = []
			for dier in World.dieren():
				World.weg(dier.id)
			_gasten(1)
			if not wacht_er_een:
				World.zet(str(State.s["gasten"][0]["id"]), "receptie", 40.0, 60.0)
			World.naar(ID)
			waar(await _wacht(func() -> bool: return not World.reist(), 3000),
				"%s: de camera staat stil" % str(maat))
			Hotel.render()
			for _f in 4:
				await boom.process_frame
			var telefoon: bool = maat.x < 520 or maat.y < 450
			var wat := "%s%s" % [str(maat), " met een gast op het dek" if wacht_er_een else ""]
			var dbg := Hits.debug()
			for sid in dbg.keys():
				var spot := Hits.spot(sid)
				if spot == null or spot.kind == "tag" or spot.kind == "naam":
					continue
				var r: Rect2 = dbg[sid]["rect"]
				var meeste := 0.0
				for stuk in palen:
					# the house rule of `Hits`: a button that hides less than
					# VREEMD_DEEL of a thing's box does not read as that thing's
					var v := World.vlak_van("hekx", float(stuk["x"]), float(stuk["z"]), 0.0, {})
					var snij := r.intersection(v)
					meeste = maxf(meeste, maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y)
						/ maxf(1.0, v.size.x * v.size.y))
				if wacht_er_een and telefoon and sid == "spel_zwembad":
					print("[probe] zwembad hek ", wat, " spel_zwembad bedekt een paal voor %.0f %%"
						% (meeste * 100.0))
					continue
				waar(meeste < Hits.VREEMD_DEEL, "%s: %s staat niet op het hek (%.0f %% van een paal)"
					% [wat, sid, meeste * 100.0])
			waar(dbg.has("spel_zwembad") and dbg.has("deur_zwembad_tuin"),
				"%s: de knoppen van de kamer staan er" % wat)
		Ui.naamplaten_leeg()
		Hits.wis_alles()
		vp.queue_free()
		await boom.process_frame
		Ui.registreer_lagen(null, null, null)
	State.s = bewaard
	Ui.set("_scherm", scherm_terug)
	Ui.zet_rust_modus(rust_voor)
	for dier in World.dieren():
		World.weg(dier.id)

# ------------------------------------------------------------------- hulpjes

## The biggest button that is still SHORT of the right answer.
func _kort_antwoord() -> int:
	var b := _beurt()
	var juist := _juist_nu()
	var uit := -1
	for v in Sommen.Zwembad.keuze_getallen(int(b["L"]), int(b["M"]), int(b["p"]),
			int(b["band"]), int(b["leg"]))["lijst"]:
		if int(v) < juist and int(v) > uit:
			uit = int(v)
	return uit

## The smallest button that is FURTHER than the whole remainder.
func _ver_antwoord() -> int:
	var b := _beurt()
	var rest: int = maxi(0, int(b["L"]) - int(b["p"]))
	var uit := -1
	for v in Sommen.Zwembad.keuze_getallen(int(b["L"]), int(b["M"]), int(b["p"]),
			int(b["band"]), int(b["leg"]))["lijst"]:
		if int(v) > rest and (uit < 0 or int(v) < uit):
			uit = int(v)
	return uit
