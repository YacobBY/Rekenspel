extends Proef
## kraam — de souvenirkraam, headless.  Since 2026-09-24 one of the shops of
## the Winkelstraat (owner: "De kraam in de tuin voelt nu dubbelop die kan
## verwerkt worden in de winkels"; games-d.md §4): the turn is the shared
## `WinkelSpel`, whose own suite (`games/_winkel/test_winkel.gd`) plays every
## shop, this one included, on every band and on four screens.  What is
## particular to this stall is tested here: it left the garden, it stands in
## the arcade without being in anybody's way, it keeps the 🎁 wish and its
## board card, and an old save — a coin turn of the garden stall, a garden
## card, a souvenir already bought — loads and plays on.
##
## Driven the way a child drives it: a choice is a `pressed` on a button of the
## real strip under the card.

const SPEL := "kraam"
const KAMER := "winkels"
const KAART := "wk_kaart"
const STROOK := "wk_kaart_keuzes"
const WEG := "wk_weg"
const STAL := "souvenirkraam"
const Beurt := preload("res://games/_winkel/beurt.gd")

## Every field a shop turn keeps (games-d.md §4.6).
const VELDEN := ["gast", "dag", "N", "band", "stap", "waar", "plek", "pog", "missers",
	"weg", "ster", "keer", "wens"]

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

## `n` guests from the pool, the first four in a real bed, none of them with a
## wish yet (`eten`); `kunnen` 5 lifts the adaptive cap, so the band is what
## the test asks for.  `start_gekozen()` is NOT called, so `State.bewaar()` is a
## no-op — except in the save test, which writes and reads the file on purpose.
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
	gelijk(State.band(), band, "de band is %d bij %d gasten" % [band, n])
	return uit

func _knoop(id: String) -> Control:
	var s := Hits.spot(id)
	return null if s == null or not is_instance_valid(s.knoop) else s.knoop

## One button of the real strip, by its keuze id (`K<id>`).
func _kies(keuze: String) -> bool:
	var strook := _knoop(STROOK)
	if strook == null:
		fout("er is geen antwoordstrook (voor %s)" % keuze)
		return false
	var k := strook.get_node_or_null("Rij/K" + keuze)
	if k == null:
		fout("%s staat niet op de strook (%s)" % [keuze, str(_keuzes())])
		return false
	(k as BaseButton).pressed.emit()
	return true

func _keuzes() -> Array[String]:
	var uit: Array[String] = []
	var strook := _knoop(STROOK)
	if strook == null:
		return uit
	var rij := strook.get_node_or_null("Rij")
	if rij == null:
		return uit
	for k in rij.get_children():
		var naam := str(k.name)
		if naam.begins_with("K"):
			uit.append(naam.substr(1))
	return uit

func _stand() -> Dictionary:
	var d = State.spel_data(SPEL).get("stand", {})
	return d if typeof(d) == TYPE_DICTIONARY else {}

func _kaart_tekst(deel: String) -> String:
	var k := _knoop(KAART)
	if k == null:
		return ""
	var l := k.get_node_or_null(deel) as Label
	return "" if l == null else l.text

func _wacht(s: float) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	await boom.create_timer(s).timeout

## This shop's own layout (`WinkelSpel.winkel()`), read from a throwaway instance.
func _winkel() -> Dictionary:
	var knoop = Games._scenes[SPEL].instantiate()
	var uit: Dictionary = knoop.winkel()
	knoop.free()
	return uit

## The right keuze id of the step the turn is in.
func _goed_keuze() -> String:
	var st := _stand()
	var stap := str(st.get("stap", ""))
	var o := Beurt.opzet(SPEL, State.n_gasten(), State.band(), int(State.s["dag"]))
	var kind := str(State.gast_van(str(st["gast"])).get("kind", "hond"))
	var goed := Beurt.goed(stap, Beurt.sommen(o, str(st["waar"]), kind))
	return ("g%d" if stap == "betaal" else "n%d") % goed

func _fout_keuze() -> String:
	var juist := _goed_keuze()
	for k in _keuzes():
		if k != juist:
			return k
	return ""

## Every right answer of this turn, one step at a time, through the strip.
func _speel_goed() -> void:
	for _i in 6:
		var stap := str(_stand().get("stap", ""))
		if stap == "af" or stap.is_empty():
			return
		_kies(_goed_keuze())
		await _wacht(WinkelSpel.SOM_S + 0.25)

func _kaart_van_het_bord(id: String) -> Dictionary:
	for q in State.s["taken"]:
		if str(q.get("id", "")) == id:
			return q
	return {}

## The floor a piece of the arcade's decor takes, in room voxels, from its own
## model and its place in the room's decor list.
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

## The souvenir stall's floor.
func _voet() -> Rect2:
	for s in Rooms.get_kamer(KAMER).decor:
		if str(s["n"]) == STAL:
			return _voet_van(s)
	return Rect2()

## Every shop's layout, from throwaway instances: {id: winkel()}.
func _winkels() -> Dictionary:
	var uit := {}
	for id in ["hoeden", "sjaals", "schoenen", SPEL, "luxe"]:
		var knoop = Games._scenes[id].instantiate()
		uit[id] = knoop.winkel()
		knoop.free()
	return uit

# -------------------------------------------------------------- aanmelding

## The directory scan finds the stall as a shop of the arcade: its button hangs
## on its own stall there, with the 🎁 of the garden and a word, and it kept
## the souvenir wish and the board card.
func test_aanmelding() -> void:
	waar(Games.lijst().has(SPEL), "de mapscan vindt kraam")
	var def := Games.definitie(SPEL)
	gelijk(def.get("naam", ""), "Souvenirkraam", "naam")
	gelijk(def.get("kamer", ""), KAMER, "de kraam staat in de winkelstraat")
	gelijk(def.get("wens", ""), "souvenir", "wens 🎁")
	gelijk(def.get("stub", true), false, "geen stub")
	var hs: Dictionary = def.get("hotspot", {})
	gelijk(hs.get("obj", ""), STAL, "het knopje hangt aan de souvenirkraam")
	gelijk(hs.get("icoon", ""), "🎁", "icoon")
	gelijk(hs.get("label", ""), "Souvenirs", "een woord bij het pictogram")
	waar(str(hs.get("rust", "")).is_empty(), "geen los rustspul meer: de kraam is vast decor")
	waar(not World.mik(STAL, KAMER).is_empty(), "de souvenirkraam staat in de winkelstraat")
	var taak: Dictionary = def.get("taak", {})
	gelijk(taak.get("id", ""), "souvenir", "taak id")
	gelijk(taak.get("prio", 0), 1, "taak prio 1")
	gelijk(taak.get("icoon", ""), "🎁", "taak icoon")
	# the same three souvenirs as in the garden, each a real wardrobe piece
	gelijk(Beurt.WAREN[SPEL], ["sjaaltje", "hoedje", "bal"], "sjaaltje, hoedje en bal")
	for naam in Beurt.WAREN[SPEL]:
		waar(ArtGasten.KLEDING.has(naam), "%s is een kledingstuk" % naam)
		waar(Art.heeft_model("waar_" + str(naam)), "%s heeft een uitstalmodel" % naam)
	var plaat = Art.plaat(STAL, 3)
	waar(plaat != null and plaat.w > 0 and plaat.h > 0, "%s bakt" % STAL)
	gelijk(Ui.mist_tekens("🎁 Souvenirs").size(), 0, "de knop heeft alleen bestaande tekens")

## `unlock(N, band)` = N >= 1, and the board card only appears when a guest
## with a bed really wants a souvenir.
func test_ontgrendeling_en_taakkaart() -> void:
	_op()
	var def := Games.definitie(SPEL)
	var unlock: Callable = def["unlock"]
	waar(not unlock.call(0, 3), "zonder gasten geen kraam")
	waar(unlock.call(1, 3), "vanaf één gast wel")
	var wanneer: Callable = def["taak"]["wanneer"]
	var tekst: Callable = def["taak"]["tekst"]
	var gasten := _wereld(1, 3)
	waar(not wanneer.call(State.s), "zonder 🎁-gast geen kaartje")
	gelijk(tekst.call(State.s), "Souvenir", "en anders het korte woord")
	gasten[0]["behoefte"] = "souvenir"
	waar(wanneer.call(State.s), "met een 🎁-gast staat het kaartje op het bord")
	gelijk(tekst.call(State.s), "Boef wil een souvenir", "de tekst noemt de gast")
	waar(Ui.keur_taak("souvenir", str(tekst.call(State.s))), "de kaarttekst past")
	waar(Ui.keur_taak("souvenir", "Stampertje wil een souvenir"), "ook met de langste naam")
	# the card leads to the arcade now, not to the garden
	var kaart := {}
	for q in Hotel.spel_taken():
		if str(q["id"]) == "souvenir":
			kaart = q
	gelijk(str(kaart.get("kamer", "")), KAMER, "het kaartje wijst naar de winkels")
	gelijk(str(kaart.get("actie", "")), "game:kraam", "en start de souvenirkraam")
	# the hotel may only hand out a 🎁 wish because this game exists
	waar(Hotel.wens_mogelijk("souvenir"), "de wens 🎁 kan uitgedeeld worden")
	# the wish waits at the counter, in the arcade
	var p := Hotel.plek_van_behoefte(gasten[0])
	var klant: Vector2 = _winkel()["klant"]
	gelijk(str(p.get("kamer", "")), KAMER, "wie een souvenir wil wacht in de winkels")
	gelijk(Vector2(float(p["x"]), float(p["z"])), klant, "aan de toonbank van de souvenirkraam")
	gelijk(Hotel.wacht_in(KAMER), 1, "de deur naar de winkels telt hem mee")
	gelijk(Hotel.wacht_in("tuin"), 0, "de tuin niet meer")
	_af()

# ----------------------------------------------------------- weg uit de tuin

## The garden has no stall, no zone, no button and no loose props of it any
## more; the hopscotch keeps its zone, and grass grows where the stall stood.
func test_de_tuin_heeft_geen_kraam_meer() -> void:
	_op()
	_wereld(4, 4)
	Games.hersteek()
	var tuin := Rooms.get_kamer("tuin")
	waar(not tuin.zones.has("kraam"), "de tuin heeft geen kraamzone meer")
	waar(tuin.zones.has("hinkel"), "het hinkelpad houdt zijn zone")
	for stuk in tuin.decor:
		waar(not str(stuk["n"]).contains("kraam"), "geen kraam in het tuindecor (%s)" % stuk["n"])
	for d in World.decor_lijst("tuin"):
		waar(str(d.get("door", "")) != SPEL, "geen los spul van de kraam in de tuin")
		waar(not str(d.get("model", "")).begins_with("kraam_"), "geen kraammodel (%s)" % d.get("model", ""))
	waar(not Art.heeft_model("kraam_bank"), "de oude toonbank bestaat niet meer")
	for id in Games.lijst():
		if id == SPEL:
			continue
		waar(str(Games.definitie(id).get("kamer", "")) != "tuin"
			or str((Games.definitie(id).get("hotspot", {}) as Dictionary).get("icoon", "")) != "🎁",
			"geen 🎁-knop in de tuin (%s)" % id)
	# in the garden: the hopscotch button, no stall button
	World.naar("tuin")
	State.s["kamerNu"] = "tuin"
	Hotel.render()
	waar(Hits.spot("spel_kraam") == null, "in de tuin hangt geen kraamknop")
	waar(Hits.spot("spel_hinkel") != null, "de hinkelknop wel")
	# the old stall zone (x 104..126, z 36..68) is lawn again: the seeded grass
	# tufts grow there now (they kept 4 voxels off every zone)
	var pollen := 0
	for stuk in tuin.decor:
		if bool(stuk.get("pol", false)) and float(stuk["x"]) >= 100.0 and float(stuk["x"]) <= 130.0 \
				and float(stuk["z"]) >= 32.0 and float(stuk["z"]) <= 72.0:
			pollen += 1
	waar(pollen >= 1, "waar de kraam stond groeit weer gras (%d pollen)" % pollen)
	_af()

# ------------------------------------------------------ in de winkelstraat

## The stall is the fourth of the row along the back wall: inside the room, in
## line with the other three and on none of them, with its customer on the
## street in front of its counter.  The arcade's door moved to the left wall
## for it (games-d.md §3), so the door is clear of every stall.
func test_de_kraam_staat_in_de_rij() -> void:
	var r := Rooms.get_kamer(KAMER)
	var voet := _voet()
	waar(voet.size.x > 20.0 and voet.size.y > 10.0, "de kraam heeft een echte voet (%s)" % str(voet))
	waar(voet.position.x >= 0.0 and voet.position.y >= 0.0 and voet.end.x <= r.w
		and voet.end.y <= r.d, "de kraam staat in de kamer (%s)" % str(voet))
	for stuk in r.decor:
		if str(stuk["n"]) == STAL:
			continue
		var ander := _voet_van(stuk)
		waar(not ander.grow(-0.5).intersects(voet), "%s staat niet op de souvenirkraam (%s / %s)"
			% [stuk["n"], str(ander), str(voet)])
		if str(stuk["n"]).ends_with("kraam"):
			gelijk(float(stuk["z"]), 12.0, "%s staat in dezelfde rij" % stuk["n"])
	for naar in r.deur_punten:
		var dp: Dictionary = r.deur_punten[naar]
		gelijk(str(dp["wand"]), "x", "de deur naar %s zit in de linkerwand" % naar)
		for stuk in r.decor:
			waar(not _voet_van(stuk).grow(4.0).has_point(Vector2(float(dp["ix"]), float(dp["iz"]))),
				"%s staat niet voor de deur naar %s" % [stuk["n"], naar])
	var w := _winkel()
	var klant: Vector2 = w["klant"]
	waar(klant.x > voet.position.x and klant.x < voet.end.x and klant.y > voet.end.y,
		"de klant staat vóór de toonbank (%s)" % str(klant))
	var zone: Dictionary = r.zones.get("kraam", {})
	waar(not zone.is_empty() and klant.x >= float(zone["x0"]) and klant.x <= float(zone["x1"])
		and klant.y >= float(zone["z0"]) and klant.y <= float(zone["z1"]),
		"in de zone kraam van de winkelstraat")

## "Walking paths stay free": every walk a shop makes in the arcade, as the
## straight line `World.stappen` walks — from the door to the counter or the
## mirror, from the counter out when sent away, and from there back to the
## door — crosses no stall, no counter, no mirror and no pot.  And no stroll
## between two places a guest may wander to, or from a customer's place to
## one, crosses the souvenir stall.
func test_geen_loop_gaat_door_een_kraam() -> void:
	var r := Rooms.get_kamer(KAMER)
	var voeten := {}
	for stuk in r.decor:
		voeten[str(stuk["n"])] = _voet_van(stuk)
	var deur := Vector2(float(r.deur_punten["receptie"]["ix"]), float(r.deur_punten["receptie"]["iz"]))
	var lopen: Array = []
	var plekken: Array = []
	var winkels := _winkels()
	for id in winkels:
		var w: Dictionary = winkels[id]
		lopen.append([deur, w["klant"], "%s: naar de toonbank" % id])
		lopen.append([w["klant"], w["buiten"], "%s: de winkel uit" % id])
		lopen.append([w["buiten"], deur, "%s: terug naar de deur" % id])
		plekken.append(w["klant"])
		plekken.append(w["buiten"])
	var paskamer: Vector2 = load("res://games/paskamer/spel.gd").PLEK
	lopen.append([deur, paskamer, "paskamer: naar de spiegel"])
	lopen.append([paskamer, deur, "paskamer: terug naar de deur"])
	plekken.append(paskamer)
	for l in lopen:
		for naam in voeten:
			waar(not Rooms._snijdt(voeten[naam], l[0], l[1]), "%s (%s -> %s) gaat niet door %s"
				% [l[2], str(l[0]), str(l[1]), naam])
	for p in plekken:
		for naam in voeten:
			waar(not voeten[naam].has_point(p), "%s staat niet in %s" % [str(p), naam])
	var dwaal: Array = []
	for p in r.plekken:
		dwaal.append(Vector2(p[0], p[1]))
	var stal: Rect2 = voeten[STAL]
	for a in dwaal + plekken + [deur]:
		for b in dwaal:
			waar(not Rooms._snijdt(stal, a, b), "de wandeling %s -> %s gaat niet door de souvenirkraam"
				% [str(a), str(b)])
	for a in dwaal:
		for b in dwaal:
			for naam in voeten:
				waar(not Rooms._snijdt(voeten[naam], a, b), "de wandeling %s -> %s gaat niet door %s"
					% [str(a), str(b), naam])

## A guest with the 🎁 wish shops first; the whole turn in every band, through
## the real strip: choose a souvenir, pay, wear it — and the wish is fulfilled,
## the board card ticked, one star.
func test_een_souvenir_kopen_vervult_de_wens() -> void:
	for band in [3, 4, 5]:
		_op()
		var n: int = [1, 4, 7][band - 3]
		var gasten := _wereld(n, band)
		var wie: Dictionary = gasten[n - 1] if n <= 4 else gasten[2]
		wie["behoefte"] = "souvenir"
		var chip := func() -> bool:
			return Hotel.spel_taken().any(func(q): return str(q["id"]) == "souvenir")
		waar(chip.call(), "groep %d: het 🎁-kaartje is een taak" % band)
		Hotel.bouw_taken(true)
		# the board holds three cards; with guests still without a bed the
		# hotel's own cards may come first
		var op_bord := not _kaart_van_het_bord("souvenir").is_empty()
		if band < 5:
			waar(op_bord, "groep %d: het 🎁-kaartje hangt op het bord" % band)
		var sterren := int(State.s["sterren"])
		waar(Games.start(SPEL), "groep %d: de souvenirkraam start" % band)
		await _wacht(0.3)
		var st := _stand()
		gelijk(str(st.get("gast", "")), str(wie["id"]), "groep %d: wie een souvenir wil, koopt" % band)
		gelijk(int(st.get("wens", 0)), 1, "voor zijn wens")
		var d = World.dier(str(wie["id"]))
		waar(d != null and d.kamer == KAMER, "hij staat in de winkelstraat")
		var klant: Vector2 = _winkel()["klant"]
		waar(d != null and Vector2(d.x, d.z).distance_to(klant) <= 3.0, "aan de toonbank")
		var keuzes := _keuzes()
		gelijk(str(keuzes), str(["w_sjaaltje", "w_hoedje", "w_bal"]), "de drie souvenirs")
		_kies("w_bal")
		await _wacht(0.1)
		gelijk(str(_stand().get("waar", "")), "bal", "de bal gekozen")
		await _speel_goed()
		gelijk(str(_stand().get("stap", "")), "af", "groep %d: klaar" % band)
		var id := str(wie["id"])
		waar(World.accessoires(id).has("bal"), "hij draagt de bal")
		waar(State.kast_van(id).has("bal"), "en die is van hem")
		waar(bool(State.gast_van(id).get("blij", false)), "zijn wens is vervuld")
		waar(not chip.call(), "er is geen 🎁-taak meer")
		if op_bord:
			waar(bool(_kaart_van_het_bord("souvenir").get("klaar", false)), "het kaartje is afgevinkt")
		gelijk(int(State.s["sterren"]), sterren + 1, "één ster voor het meedoen")
		_af()

## THE SHOP RULE (owner, 2026-09-24) holds here too: the wrong money sends the
## animal out of the shop, slowly, the game closes, the wish waits — and a tap
## on the stall brings the SAME question back.
func test_verkeerd_geld_stuurt_het_dier_de_kraam_uit() -> void:
	_op()
	var gasten := _wereld(4, 4)
	gasten[0]["behoefte"] = "souvenir"
	var gast := str(gasten[0]["id"])
	var sterren := int(State.s["sterren"])
	waar(Games.start(SPEL), "de souvenirkraam start")
	await _wacht(0.3)
	_kies("w_hoedje")
	await _wacht(0.2)
	gelijk(str(_stand().get("stap", "")), "betaal", "groep 4: nu betalen")
	var voor := _keuzes()
	gelijk(voor.size(), 4, "vier handjes geld")
	_kies(_fout_keuze())
	waar(_knoop(KAART) == null and _knoop(STROOK) == null, "de kaart en de strook zijn meteen weg")
	gelijk(int(_stand().get("weg", 0)), 1, "het dier moet de kraam uit")
	gelijk(str(_stand().get("stap", "")), "betaal", "de vraag blijft staan")
	waar(_knoop(WEG) != null, "met 😞 Dat klopt niet")
	await _wacht(WinkelSpel.SIP_S + WinkelSpel.WEG_WACHT + 0.8)
	gelijk(Games.actief(), "", "buiten: het spel is dicht")
	var d = World.dier(gast)
	var buiten: Vector2 = _winkel()["buiten"]
	waar(d != null and Vector2(d.x, d.z).distance_to(buiten) <= 3.0, "het dier staat buiten de kraam")
	gelijk(int(State.s["sterren"]), sterren, "een misser kost niets")
	waar(not bool(State.gast_van(gast).get("blij", false)), "de wens wacht nog")
	Games.hersteek()
	World.naar(KAMER)
	State.s["kamerNu"] = KAMER
	Hotel.render()
	waar(Hits.spot("spel_kraam") != null, "de knop van de souvenirkraam is er weer")
	waar(Games.start(SPEL), "terug de kraam in")
	await _wacht(0.3)
	gelijk(int(_stand().get("weg", 1)), 0, "hij is weer binnen")
	gelijk(str(_stand().get("stap", "")), "betaal", "dezelfde vraag")
	gelijk(str(_keuzes()), str(voor), "met dezelfde vier keuzes in dezelfde volgorde")
	await _speel_goed()
	gelijk(str(_stand().get("stap", "")), "af", "nu goed betaald")
	waar(World.accessoires(gast).has("hoedje"), "hij draagt het hoedje")
	waar(bool(State.gast_van(gast).get("blij", false)), "en nu is de wens vervuld")
	gelijk(int(State.s["sterren"]), sterren + 1, "de ster komt voor het meedoen")
	_af()

## The customer really walks in — from his room, through the lobby and the
## arcade's door in the left wall — along the street to the fourth stall at
## the far end, and never over a stall on the way.
func test_de_klant_loopt_langs_de_straat() -> void:
	_op()
	Ui.zet_rust_modus(false)
	var gasten := _wereld(1, 3)
	var id := str(gasten[0]["id"])
	gasten[0]["behoefte"] = "souvenir"
	World.zet(id, str(gasten[0]["kamer"]), 60.0, 60.0)
	World.pauzeer(true)                     # the test ticks the world itself
	waar(Games.start(SPEL), "het spel start")
	waar(Hits.spot(KAART) == null, "nog geen kaart: de klant is er nog niet")
	var voeten: Array = []
	for stuk in Rooms.get_kamer(KAMER).decor:
		voeten.append(_voet_van(stuk).grow(-0.5))
	var d = World.dier(id)
	var t := 0
	var in_winkel := 0
	var over := 0
	while t < 6000:
		World._tik()
		t += 1
		if d.kamer == KAMER:
			in_winkel += 1
			for v in voeten:
				if (v as Rect2).has_point(Vector2(d.x, d.z)):
					over += 1
			if (d.punten as Array).is_empty() and (d.route as Array).is_empty():
				break
	gelijk(d.kamer, KAMER, "hij stapt de winkelstraat in")
	waar(in_winkel > 5, "en loopt er een eind (%d tikken)" % in_winkel)
	gelijk(over, 0, "nooit over een kraam, de vitrine of de plant")
	var klant: Vector2 = _winkel()["klant"]
	waar(Vector2(d.x, d.z).distance_to(klant) <= 3.0, "hij staat aan de toonbank (%s)" % str(Vector2(d.x, d.z)))
	var boom := Engine.get_main_loop() as SceneTree
	var t0 := Time.get_ticks_msec()
	while Hits.spot(KAART) == null and Time.get_ticks_msec() - t0 < 1500:
		await boom.process_frame
	waar(Hits.spot(KAART) != null, "aan de toonbank: nu de kaart")
	World.pauzeer(false)
	_af()

# ----------------------------------------------------------------- de opslag

## A turn of the garden stall in the drawer becomes a fresh choice for the same
## animal; a turn that was done stays done; the wish survives.
func test_een_oude_kraambeurt_wordt_een_nieuwe_keuze() -> void:
	var leg := {"gast": "boef", "dag": 2.0, "N": 4.0, "band": 4.0, "stap": "leg",
		"gelegd": [2.0, 1.0], "hand": 2.0, "som_pog": 1.0, "leg_pog": 0.0, "missers": 1.0,
		"wens": 1.0, "ster": 0.0, "acc": 0.0,
		"zeg": {"icoon": "🪙", "getal": "€2", "tekst": "in je hand"}}
	var st := WinkelSpel._normaliseer(leg)
	gelijk(str(st.keys().filter(func(k): return not VELDEN.has(k))), "[]",
		"alleen de velden van een winkelbeurt blijven over")
	gelijk(st["stap"], "kies", "een muntbeurt wordt een nieuwe keuze")
	gelijk(st["gast"], "boef", "voor hetzelfde dier")
	gelijk(st["wens"], 1, "met zijn wens")
	gelijk(st["missers"], 0, "zonder de missers van de oude kraam")
	gelijk(typeof(st["dag"]), TYPE_INT, "getallen zijn weer gehele getallen")
	var som := leg.duplicate(true)
	som["stap"] = "som"
	gelijk(WinkelSpel._normaliseer(som)["stap"], "kies", "ook de som van groep 4 en 5")
	var af := leg.duplicate(true)
	af["stap"] = "af"
	af["ster"] = 1.0
	gelijk(WinkelSpel._normaliseer(af)["stap"], "af", "een afgemaakte beurt blijft af")
	# a shop turn that was sent out keeps its question and its miss
	var weg := {"gast": "boef", "dag": 2, "N": 4, "band": 4, "stap": "betaal", "waar": "bal",
		"plek": 2, "pog": 1, "missers": 1, "weg": 1, "ster": 0, "keer": 1, "wens": 1}
	var w2 := WinkelSpel._normaliseer(weg)
	gelijk(w2["stap"], "betaal", "een winkelbeurt blijft waar hij was")
	gelijk(w2["missers"], 1, "met zijn misser")

## The whole way through the save FILE: a save written while the stall was in
## the garden — a coin turn in its drawer, the 🎁 card pointing at the garden,
## the camera in the garden, a hoedje bought there — is read by `State.lees()`,
## the board sends the card to the arcade, the game starts there with the same
## animal, the hoedje is his and stays off the counter, and he buys the rest.
func test_een_oude_opslag_speelt_verder() -> void:
	_op()
	var gasten := _wereld(4, 4)
	var boef: Dictionary = gasten[0]
	var id := str(boef["id"])
	boef["behoefte"] = "souvenir"
	boef["accessoires"] = ["hoedje"]
	State.s["spel"]["kraam"] = {"stand": {"gast": id, "dag": 2, "N": 4, "band": 4,
		"stap": "leg", "gelegd": [2, 1], "hand": 2, "som_pog": 0, "leg_pog": 1,
		"missers": 1, "wens": 1, "ster": 0, "acc": 0, "zeg": null}}
	State.s["taken"] = [{"id": "souvenir", "spel": "kraam", "icoon": "🎁",
		"tekst": "Boef wil een souvenir", "kamer": "tuin", "actie": "game:kraam",
		"prio": 1, "klaar": false}]
	State.s["kamerNu"] = "tuin"
	State.start_gekozen()                   # writes user://dierenhotel.json
	State.s = State.standaard()
	waar(State.lees(), "de oude opslag leest zonder fout")
	gasten = State.s["gasten"]
	World.sync(gasten)
	gelijk(State.kast_van(id), ["hoedje"], "het hoedje uit de tuin is van hem")
	# the board: the card goes to the arcade now
	Hotel.bouw_taken(true)
	var kaart := _kaart_van_het_bord("souvenir")
	gelijk(str(kaart.get("kamer", "")), KAMER, "het 🎁-kaartje wijst naar de winkels")
	gelijk(str(kaart.get("actie", "")), "game:kraam", "en start de souvenirkraam")
	# the card is tapped: the camera goes to the arcade and the stall opens
	Hotel.doe_taak(kaart)
	await _wacht(0.3)
	gelijk(Games.actief(), SPEL, "de souvenirkraam draait")
	gelijk(World.kamer_nu(), KAMER, "in de winkelstraat")
	var st := _stand()
	gelijk(str(st.keys().filter(func(k): return not VELDEN.has(k))), "[]",
		"de munten van de oude kraam zijn uit de beurt")
	gelijk(str(st.get("gast", "")), id, "hetzelfde dier koopt")
	gelijk(str(st.get("stap", "")), "kies", "hij kiest opnieuw")
	gelijk(int(st.get("wens", 0)), 1, "voor zijn wens")
	gelijk(str(_keuzes()), str(["w_sjaaltje", "w_bal"]), "het hoedje heeft hij al: sjaaltje of bal")
	_kies("w_sjaaltje")
	await _wacht(0.1)
	await _speel_goed()
	gelijk(str(_stand().get("stap", "")), "af", "gekocht")
	gelijk(State.kast_van(id), ["hoedje", "sjaaltje"], "hoedje en sjaaltje zijn van hem")
	waar(World.accessoires(id).has("hoedje") and World.accessoires(id).has("sjaaltje"),
		"hij draagt ze allebei (hoofd en hals)")
	waar(bool(State.gast_van(id).get("blij", false)), "de wens is vervuld")
	# never leave a save file behind for the next test file
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("dierenhotel.json")
		dir.remove("dierenhotel.json.tmp")
	State.nieuw_spel()                      # `start_gekozen` off again
	_af()

## A new day starts a fresh turn; a turn that is done is not resumed.
func test_nieuwe_dag_nieuwe_beurt() -> void:
	_op()
	_wereld(4, 4)
	waar(Games.start(SPEL), "start")
	await _wacht(0.3)
	_kies(_keuzes()[0])
	await _wacht(0.2)
	gelijk(str(_stand().get("stap", "")), "betaal", "midden in de beurt")
	Games.stop()
	State.s["dag"] = int(State.s["dag"]) + 1
	waar(Games.start(SPEL), "de volgende dag")
	await _wacht(0.3)
	gelijk(str(_stand().get("stap", "")), "kies", "een nieuwe dag begint bij het kiezen")
	gelijk(int(_stand().get("dag", 0)), int(State.s["dag"]), "met de dag van vandaag")
	_af()
