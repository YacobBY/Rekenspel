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
	gelijk(hs.get("obj", ""), "mat", "het icoontje hangt op de instapvlonder")
	gelijk(hs.get("icoon", ""), "🏊", "icoon")
	gelijk(hs.get("label", ""), "Zwemles", "label")
	gelijk(hs.get("hoog", 0), 12, "hoogte")
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
					ZwembadBeurt.eind_regel2_precies(naam, l),
					ZwembadBeurt.eind_regel_bots(naam), ZwembadBeurt.eind_regel2_bots(l),
					ZwembadBeurt.hulp_regel(1, m), ZwembadBeurt.hulp_regel(2, m),
					ZwembadBeurt.hulp_regel(3, m)]:
				waar(zin.split(" ", false).size() <= 8 and zin.length() <= 40,
					'"%s" past in het tekstbudget (%d woorden, %d tekens)'
						% [zin, zin.split(" ", false).size(), zin.length()])
	# every character is in the bundled font subset
	for zin in [ZwembadBeurt.GEEN_GAST, ZwembadBeurt.TOAST_PRECIES,
			ZwembadBeurt.TOAST_BOTS, ZwembadBeurt.ICOON, ZwembadBeurt.PRECIES_ICOON,
			ZwembadBeurt.BOTS_ICOON, ZwembadBeurt.som_verder(43, 30),
			ZwembadBeurt.som_af(43, 0, 43, false), ZwembadBeurt.hulp_regel(1, 30)]:
		gelijk(str(Ui.mist_tekens(zin)), "[]", 'geen ontbrekend teken in "%s"' % zin)

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

## Never punishing (§0.6, F5): a wrong answer costs no star, gives a soft sound
## and a help line, and the turn simply goes on with the rest.
func test_fout_antwoord_helpt_en_straft_nooit() -> void:
	_op()
	_gasten(4)
	var sterren_voor := int(State.s["sterren"])
	waar(Games.start(ID), "het spel start")
	waar(await _wacht(_kaart_staat), "de vraagkaart staat er")
	var l := int(_beurt()["L"])
	var m := int(_beurt()["M"])
	# too short: he swims that far and a new card asks for the rest
	var kort := _kort_antwoord()
	waar(kort > 0, "er staat een te korte knop op de strook (%d)" % kort)
	waar(_druk(kort), "de te korte knop is aan te tikken")
	waar(await _wacht(_kaart_staat), "er komt gewoon een nieuwe kaart")
	gelijk(int(_beurt()["p"]), kort, "hij zwom precies zo ver als gevraagd")
	gelijk(int(_beurt()["misser"]), 1, "één misser geteld")
	gelijk(int(State.s["sterren"]), sterren_voor, "en geen ster minder")
	var kaart := _kaart_knoop()
	waar(kaart != null and kaart.hulp_label.visible, "trede 1: er staat een hulpregel")
	if kaart != null:
		gelijk(kaart.hulp_label.text, ZwembadBeurt.hulp_regel(1, m), "trede 1 letterlijk")
		waar(not kaart.regel_label.text.contains("✗"), "geen kruis op de kaart")
	# a second slip: a more pointed line, still no punishment
	var kort2 := _kort_antwoord()
	if kort2 > 0:
		waar(_druk(kort2), "nog een te korte knop")
		waar(await _wacht(func() -> bool: return _kaart_staat() or not _klaar().is_empty()),
			"en het spel gaat verder")
	if _klaar().is_empty():
		gelijk(int(_beurt()["misser"]), 2, "twee missers")
		var k2 := _kaart_knoop()
		if k2 != null:
			gelijk(k2.hulp_label.text, ZwembadBeurt.hulp_regel(2, m), "trede 2 letterlijk")
	gelijk(int(State.s["sterren"]), sterren_voor, "nog steeds geen ster minder")
	waar(l > 0, "de baan is er nog")
	await _af()

## The third slip shows the answer as a pale marker in the water (§0.5).
func test_derde_misser_zet_een_spookstreep() -> void:
	_op()
	_gasten(4)
	waar(Games.start(ID), "het spel start")
	waar(await _wacht(_kaart_staat), "de vraagkaart staat er")
	for _i in 3:
		var kort := _kort_antwoord()
		if kort <= 0:
			break
		_druk(kort)
		await _wacht(func() -> bool: return _kaart_staat() or not _klaar().is_empty())
	if int(_beurt()["misser"]) >= 3 and _klaar().is_empty():
		waar(not World.decor_plek("zb_spook", ID).is_empty(),
			"er ligt een bleke streep in het water")
		waar(Hits.spot("zb_spooktag") != null, "met het antwoord erop")
		var kaart := _kaart_knoop()
		if kaart != null:
			gelijk(kaart.hulp_label.text, ZwembadBeurt.hulp_regel(3, int(_beurt()["M"])),
				"trede 3 letterlijk")
	else:
		waar(true, "de baan was te kort voor drie missers")
	await _af()

## Too far: a soft bump, a 💛 Au! and never a cross — and the star still comes,
## because it belongs to reaching the other side (§1.5, §1.7).
func test_te_ver_botst_zacht_en_geeft_toch_een_ster() -> void:
	_op()
	_gasten(4)
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
	waar(_druk(ver), "de te verre knop is aan te tikken")
	waar(await _wacht(func() -> bool: return not _klaar().is_empty(), 6000),
		"de beurt loopt af met een bots")
	gelijk(_klaar(), "bots", "hij botste zacht tegen de wand")
	gelijk(int(_beurt()["p"]), l, "en ligt aan de overkant")
	gelijk(int(_beurt()["laatste_rest"]), l - p_voor, "de laatste rest klopt")
	var kaart := _kaart_knoop()
	waar(kaart != null, "er staat een eindkaart")
	if kaart != null:
		gelijk(kaart.regel_label.text,
			"💛 " + ZwembadBeurt.eind_regel_bots(str(State.s["gasten"][0]["naam"])),
			"eindkaart na een bots")
		gelijk(kaart.regel2_label.text, ZwembadBeurt.eind_regel2_bots(l - p_voor),
			"en wat er nog lag")
	gelijk(int(State.s["sterren"]), sterren_voor + 1, "de ster hoort bij het meedoen")
	await _af()

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
	# start again: the saved turn is picked up where it was
	waar(Games.start(ID), "het spel start opnieuw")
	waar(await _wacht(_kaart_staat), "en de vraagkaart is terug")
	gelijk(int(_beurt()["p"]), p, "op dezelfde meter")
	gelijk(int(_beurt()["L"]), l, "met dezelfde baan")
	d = World.dier(str(gasten[0]["id"]))
	var doel := ZwembadBeurt.baan_x(Rooms.get_kamer(ID).bad, l, p)
	waar(absf(d.x - doel) <= 3.0,
		"en de zwemmer ligt weer op meter %d (x=%.1f, doel %.1f)" % [p, d.x, doel])
	gelijk(d.hoogte, -World.ZWEM_DIEP, "in het water, niet erop")
	var kaart := _kaart_knoop()
	if kaart != null:
		gelijk(kaart.som_label.text, ZwembadBeurt.som_verder(l, p), "en de som klopt nog")
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
	for id in [KAART, STROOK, VLAG_TAG, GAST_TAG, "zb_wolk", "zb_spooktag"]:
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
	for params in [{"groot": true}, {"groot": false}, {"groot": true, "bleek": true}]:
		var p = Art.plaat("zwembad_streep", 3, params)
		waar(p != null and p.w > 0 and p.h > 0,
			"de streep bakt met %s (%s)" % [str(params), str(p)])
	var v = Art.plaat("zwembad_vlag", 3, {})
	waar(v != null and v.w > 0 and v.h > 0, "de vlag bakt")
	# the marker never wears the almost white of the stone rim
	for vox in ZwembadModellen.streep({"groot": true}):
		var kl: Color = vox["k"]
		waar(kl != Color("#EDEFF6"), "de streep is blauw, niet steenkleurig")

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
