extends Proef
## band — De dierenband in de muziekkamer (U2), headless.
##
## Driven the way a child drives it: an answer is a `pressed` on a button of
## the real strip under the card, "🔁 Nog een keer luisteren" a `pressed` on
## its hotspot.  The rhythm plays in real time (one `na()` per tick), so the
## turns are picked on days with a short rhythm (`_dag_voor`).  The pure turn
## logic in `beurt.gd` and the stave (`BandNotenbalk`) on its own clock are
## also tested directly.

const SPEL := "band"
const KAMER := "muziekkamer"
const KAART := "band_som"
const STROOK := "band_som_keuzes"
const BALK := "band_balk"
const NOG := "band_nog"
const LUISTER := "band_luister"
const BLIJ := "band_blij"
const LEEG := "band_leeg"
const RUST_TROMMEL := "rust_band_trommel"
const TROMMEL := "bd_trommel"
const Beurt := preload("res://games/band/beurt.gd")
const Spel := preload("res://games/band/spel.gd")

const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740),
	Vector2i(740, 360)]
const STAP := 1.0 / 30.0

var _laag: Control = null
var _bewaard: Dictionary = {}
var _rust_voor := false
var _gehoord: Array[String] = []
var _hoor_was: Array = []
var _hoor_log_was: Array[String] = []

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
	_hoor_uit()
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

## A day on which the turn for `n` guests in `band` is of `soort` and the
## rhythm lasts at most `max_s` seconds — the tests wait for it in real time.
func _dag_voor(n: int, band: int, soort: String, max_s: float, min_s := 0.0) -> int:
	for dag in range(1, 80):
		var o := Beurt.opzet(n, band, dag)
		if str(o["soort"]) == soort and Beurt.duur(o) <= max_s and Beurt.duur(o) >= min_s:
			return dag
	fout("geen dag met een kort ritme %s voor %d gasten in band %d" % [soort, n, band])
	return 1

func _knoop(id: String) -> Control:
	var s = Hits.spot(id)
	return null if s == null or not is_instance_valid(s.knoop) else s.knoop

func _balk() -> BandNotenbalk:
	return _knoop(BALK) as BandNotenbalk

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

## A hotspot button, pressed the way a finger presses it.
func _tik_knop(id: String) -> bool:
	var k := _knoop(id) as BaseButton
	if k == null:
		fout("de knop %s staat er niet" % id)
		return false
	k.pressed.emit()
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

func _foute_keuze(goed: int) -> String:
	for k in _strook():
		if k != "Kn%d" % goed:
			return k
	return ""

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

func _wacht(s: float) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	await boom.create_timer(maxf(0.0, s)).timeout

## Listen to the band from here on (it sleeps in the suite).  What `Snd`
## remembers (`gehoord()`, the last 32 starts) is put back afterwards: a
## rhythm fills it, and a later file that counts from its size would hear
## nothing new in a full buffer (`test_foto`, found in the full suite).
func _hoor_aan() -> void:
	_gehoord.clear()
	if _hoor_was.is_empty():
		_hoor_was = [Snd._wakker, Snd._uit]
		_hoor_log_was = Snd.gehoord()
	Snd._wakker = true
	Snd._uit = false
	if not Snd.gespeeld.is_connected(_hoor):
		Snd.gespeeld.connect(_hoor)

func _hoor(naam: String) -> void:
	_gehoord.append(naam)

func _hoor_uit() -> void:
	if Snd.gespeeld.is_connected(_hoor):
		Snd.gespeeld.disconnect(_hoor)
	if not _hoor_was.is_empty():
		Snd._wakker = bool(_hoor_was[0])
		Snd._uit = bool(_hoor_was[1])
		_hoor_was = []
		Snd._gehoord.clear()
		Snd._gehoord.append_array(_hoor_log_was)
		_hoor_log_was = []
		if not Snd._wakker or Snd._uit:
			Snd._zwijg()

func _plops(lijst: Array) -> Array[String]:
	var uit: Array[String] = []
	for naam in lijst:
		if str(naam).begins_with("plop"):
			uit.append(str(naam))
	return uit

## `n` ticks per bar as the turn writes them: [[1..k], …].
static func _maten(ks: Array) -> Array:
	var uit: Array = []
	for k in ks:
		var maat: Array = []
		for j in int(k):
			maat.append(j + 1)
		uit.append(maat)
	return uit

## Turn the stave's clock `sec` seconds on in frames of a thirtieth.
func _tik(b: BandNotenbalk, sec: float) -> void:
	for _i in int(round(sec / STAP)):
		b.tik(STAP)

# -------------------------------------------------------------- aanmelding

## The directory scan finds the band in the music room; its entry hangs on
## the resting drum, its four props are known to `Art` before it ever ran.
func test_aanmelding() -> void:
	var def: Dictionary = Games.definitie(SPEL)
	waar(not def.is_empty(), "band is aangemeld")
	if def.is_empty():
		return
	gelijk(def.get("naam", ""), "De dierenband", "naam")
	gelijk(String(def["kamer"]), KAMER, "de band speelt in de muziekkamer")
	gelijk(def.get("stub", true), false, "geen stub meer: speelbaar")
	var hs: Dictionary = def.get("hotspot", {})
	gelijk(hs.get("obj", ""), "muziekdoos", "de ingang is verankerd aan de muziekdoos")
	gelijk(hs.get("rust", ""), RUST_TROMMEL, "en hangt aan de rustende trommel")
	gelijk(hs.get("icoon", ""), Beurt.ICOON, "icoon")
	gelijk(hs.get("label", ""), Beurt.T_KNOP, "label")
	var doos := World.mik("muziekdoos", KAMER)
	waar(not doos.is_empty(), "de muziekdoos staat in de muziekkamer")
	gelijk(float(doos.get("x", 0)) + float(hs["dx"]), float(Spel.TROMMEL_X), "x van de trommel")
	gelijk(float(doos.get("z", 0)) + float(hs["dz"]), float(Spel.TROMMEL_Z), "z van de trommel")
	gelijk((def.get("rust", []) as Array).size(), 4, "vier rustspullen: trommel, xylofoon, piano, standaard")
	gelijk(String(def["taak"]["id"]), "band", "taak id")
	gelijk(String(def["taak"]["kamer"]), KAMER, "het briefje zegt: in de muziekkamer")
	waar(Ui.keur_taak("band", str(def["taak"]["tekst"])), "het briefje heeft ≤ 6 woorden")
	for naam in ArtDecorMuziek.NAMEN:
		waar(Art.heeft_model(naam), "Art kent " + naam)
	var unlock: Callable = def["unlock"]
	waar(not unlock.call(0, 3), "zonder gasten niet")
	waar(unlock.call(1, 3), "vanaf één gast wel")
	var kan: Callable = def["kan"]
	waar(not kan.call({"gasten": [{"bed": ""}]}), "zonder een gast met een bed is er niemand voor de trommel")
	waar(kan.call({"gasten": [{"bed": "bed1"}]}), "één gast met een bed: het kan")
	waar(Rooms.bestaat(KAMER), "de muziekkamer bestaat")
	waar(not Rooms.deur(KAMER, "speelzaal").is_empty(), "deur naar de speelzaal")
	waar(not Rooms.deur("speelzaal", KAMER).is_empty(), "deur vanuit de speelzaal")
	gelijk(Rooms.etage(KAMER), 3, "de muziekkamer is de bovenste verdieping")

func test_een_maat_per_gast() -> void:
	gelijk(Beurt.maten_voor(0), 2, "nooit minder dan twee maten")
	gelijk(Beurt.maten_voor(1), 2, "één gast: twee maten")
	gelijk(Beurt.maten_voor(4), 4, "vier gasten: vier maten")
	gelijk(Beurt.maten_voor(8), 6, "acht gasten: de balk is vol bij zes")

func test_de_getallen_per_band() -> void:
	var soorten := {}
	for n in range(1, 9):
		for band in [3, 4, 5]:
			for dag in range(1, 9):
				var o := Beurt.opzet(n, band, dag)
				var wie := "n=%d band=%d dag=%d" % [n, band, dag]
				var soort := String(o["soort"])
				soorten[soort] = true
				waar(Beurt.SOORTEN.has(soort), wie + " soort " + soort)
				var goed := int(o["goed"])
				var k := int(o["k"])
				var m := int(o["m"])
				var maten: Array = o["maten"]
				waar(int(o["min"]) <= goed and goed <= int(o["max"]), wie + " goed binnen min..max")
				waar(int(o["min"]) < int(o["max"]), wie + " min < max")
				gelijk(int(o["tikken"]), Beurt.tel_tikken(maten), wie + " tikken geteld")
				waar(int(o["toon_maten"]) >= 1 and int(o["toon_maten"]) <= maten.size(),
					wie + " de balk toont 1..alle maten")
				gelijk(Beurt.toon(o).size(), int(o["toon_maten"]), wie + " toon() geeft de getoonde maten")
				# the four numbers on the strip: the right one among them, all
				# inside the range, two digits at most
				var vier := Afleiders.vier(goed, 17, {"min": o["min"], "max": o["max"], "liever": o["liever"]})
				gelijk(vier.size(), 4, wie + " vier getallen")
				waar(vier.has(goed), wie + " het goede getal staat erbij")
				waar(vier.max() <= 99, wie + " hooguit twee cijfers")
				# the rhythm a child sits through: never longer than 20 s, and a
				# tick never quicker than TIK_MIN_S
				waar(Beurt.duur(o) <= 20.0, wie + " het ritme duurt hooguit 20 s (%.1f)" % Beurt.duur(o))
				waar(Beurt.tik_s(o) >= Beurt.TIK_MIN_S, wie + " een tik is te volgen")
				match soort:
					"tel":
						gelijk(band, 3, wie + " tellen is groep 3")
						waar(goed >= 2 and goed <= 10, wie + " 2..10 tikken")
						gelijk(goed, int(o["tikken"]), wie + " het antwoord is het aantal tikken")
						gelijk(maten.size(), 1, wie + " één ritme")
						gelijk(Beurt.tik_s(o), Beurt.TIK_S, wie + " groep 3 telt in het rustige tempo")
					"samen":
						gelijk(band, 3, wie + " samen is groep 3")
						waar(dag >= 3, wie + " pas vanaf dag 3")
						waar(goed >= 5 and goed <= 20, wie + " 5..20 tikken samen")
						gelijk(goed, int(o["tikken"]), wie + " het antwoord is het aantal tikken")
						gelijk(maten.size(), 2, wie + " twee ritmes")
						gelijk(str(Beurt.kleuren(o)), "[0, 1]", wie + " twee kleuren")
					"maten":
						gelijk(band, 4, wie + " sprongen zijn groep 4")
						waar(Beurt.SPRONGEN.has(k), wie + " k in {2, 5, 10}")
						gelijk(m, Beurt.maten_voor(n), wie + " één maat per gast")
						gelijk(goed, k * m, wie + " k × m")
						gelijk(goed, int(o["tikken"]), wie + " alle tikken")
					"tafel":
						gelijk(band, 5, wie + " tafels zijn groep 5")
						waar(Beurt.TAFELS.has(k), wie + " k uit de tafels")
						gelijk(m, Beurt.maten_voor(n), wie + " één maat per gast")
						gelijk(goed, k * m, wie + " k × m")
						waar(dag % 2 == 1, wie + " oneven dag")
					"omgekeerd":
						gelijk(band, 5, wie + " omgekeerd is groep 5")
						waar(dag % 2 == 0, wie + " even dag")
						gelijk(goed, m, wie + " het antwoord is het aantal maten")
						gelijk(int(o["doel"]), k * m, wie + " het doel is k × m")
						gelijk(int(o["toon_maten"]), 1, wie + " de balk toont één maat")
						waar((o["liever"] as Array).has(k), wie + " de tikken van één maat zijn een echte misser")
	for s in Beurt.SOORTEN:
		waar(soorten.has(s), "soort %s komt voor" % s)

## The same day, the same guests and band, the same turn number: the same
## rhythm (a reload asks the same question).  Another day — or the next turn of
## the same day — another rhythm.
func test_hetzelfde_zaad_hetzelfde_ritme() -> void:
	for band in [3, 4, 5]:
		gelijk(str(Beurt.opzet(3, band, 4)), str(Beurt.opzet(3, band, 4)), "band %d: hetzelfde zaad" % band)
		gelijk(str(Beurt.opzet(3, band, 4, 2)), str(Beurt.opzet(3, band, 4, 2)), "band %d: ook met een beurtnummer" % band)
		var ritmes := {}
		for nr in 6:
			var o := Beurt.opzet(3, band, 4, nr)
			ritmes["%d|%d|%s" % [int(o["k"]), int(o["goed"]), str(o["soort"])]] = true
		waar(ritmes.size() >= 2, "band %d: de volgende beurt van de dag is een ander ritme (%s)" % [band, str(ritmes.keys())])
	var anders := false
	for dag in range(1, 12):
		anders = anders or str(Beurt.opzet(3, 3, dag)) != str(Beurt.opzet(3, 3, 4))
	waar(anders, "een andere dag geeft een ander ritme")

## HOTEL.md §9: every card sentence ≤ 8 words AND ≤ 40 characters, pictogram
## first, and every glyph in the bundled fonts (🥁 👂 🔁 🎵 since F1).
func test_elke_zin_past() -> void:
	if Ui.thema == null or Ui.thema.default_font == null:
		Ui._bouw_thema(17)
	var pictos := [Beurt.ICOON, Beurt.ICOON_LUISTER, Beurt.ICOON_NOG, Beurt.ICOON_AF, Beurt.ICOON_AF2,
		Beurt.ICOON_LEEG, Beurt.ICOON_BLIJ]
	for zin in Beurt.zinnen():
		var vol := "%s %s" % [Beurt.ICOON, zin]
		waar(vol.split(" ", false).size() <= 8, "≤ 8 woorden: " + vol)
		waar(vol.length() <= 40, "≤ 40 tekens: " + vol)
		gelijk(Ui.mist_tekens(zin).size(), 0, "elk teken staat in de fontsubset: %s" % zin)
	for p in pictos:
		var mist: Array[String] = Ui.mist_tekens(p)
		waar(mist.is_empty(), "het pictogram %s staat in de fonts" % p)
	waar(Ui.mist_tekens(Rooms.get_kamer(KAMER).icoon).is_empty(), "het kamerpictogram staat in de fonts")
	waar(Beurt.ICOON_NOG != UiTekst.MIS_ICOON,
		"de luisterknop lijkt niet op de mokwolk %s Nog een keer" % UiTekst.MIS_ICOON)
	for n in [1, 4, 8]:
		for band in [3, 4, 5]:
			for dag in [2, 3, 5]:
				var o := Beurt.opzet(n, band, dag)
				var vraag := "%s %s" % [Beurt.ICOON, Beurt.vraag(o)]
				waar(Ui.keur_regel(SPEL, Beurt.vraag(o)), "de kaartregel past: " + vraag)
				waar(vraag.split(" ", false).size() <= 8 and vraag.length() <= 40, "de vraag past: " + vraag)
				gelijk(Ui.mist_tekens(str(o["som"])).size(), 0, "de som staat in de fontsubset: %s" % o["som"])
				gelijk(Ui.mist_tekens(Beurt.af2(o)).size(), 0, "de slotregel staat in de fontsubset: %s" % Beurt.af2(o))
	waar(Ui.keur_regel(SPEL, Beurt.T_AF), "de slotzin past")

func test_de_modellen_bakken() -> void:
	for naam in ArtDecorMuziek.NAMEN:
		var fn: Callable = ArtDecorMuziek.tabel()[naam]
		var v: Array = fn.call({})
		waar(v.size() >= 20, "%s heeft voxels (%d)" % [naam, v.size()])
		for b in v:
			if not (b.has("x") and b.has("y") and b.has("z") and b.has("k")):
				fout("%s: een voxel zonder x/y/z/k" % naam)
				break
		for g in [2, 3]:
			var p = Art.plaat(naam, g, {})
			waar(p != null and p.w > 0 and p.h > 0, "%s bakt op g=%d" % [naam, g])
	waar(ArtDecorMuziek.band_trommel().size() > ArtDecorMuziek.band_standaard().size(),
		"de trommel is groter dan de standaard")

# ------------------------------------------------------------ de notenbalk

## The stave alone, OUTSIDE the tree: never drawn, so it only moves when the
## test turns its clock.  Every tick lights one more note and that note glows;
## the glow fades on the clock, the light stays — the count a child reads with
## the sound off.  In reduced motion, and headless in the tree, a lit note is
## simply lit: no glow, nothing that moves.
func test_de_notenbalk_telt_zijn_lichtjes() -> void:
	var rust_voor := Ui.rust_modus()
	Ui.zet_rust_modus(false)
	var b := BandNotenbalk.new()
	b.size = Vector2(600, 220)
	b.zet(_maten([3, 3]))
	gelijk(b.aantal(), 6, "zes noten in twee maten")
	gelijk(b.aantal_aan(), 0, "nog niets geklonken: alles bleek")
	waar(not b.beweegt(), "een bleke balk staat stil")
	gelijk(b.mouse_filter, Control.MOUSE_FILTER_IGNORE, "een tik gaat erdoorheen")
	b.slag(1)
	gelijk(b.aantal_aan(), 1, "de eerste tik: één noot aan")
	waar(b.is_aan(0) and not b.is_aan(1), "de eerste, niet de tweede")
	gelijk(b.gloed(0), 1.0, "de noot die net klonk gloeit")
	waar(b.beweegt(), "en dat beweegt")
	_tik(b, BandNotenbalk.GLOED_S * 0.5)
	var half := b.gloed(0)
	waar(half > 0.2 and half < 0.8, "halverwege half zo fel (%.2f)" % half)
	b.slag(2)
	gelijk(b.aantal_aan(), 2, "de tweede tik: twee noten aan")
	gelijk(b.gloed(1), 1.0, "de tweede gloeit nu")
	_tik(b, 0.1)
	waar(b.gloed(0) < half, "de eerste dooft verder")
	waar(b.gloed(1) > b.gloed(0), "de laatste noot gloeit het felst")
	_tik(b, BandNotenbalk.GLOED_S + 0.1)
	gelijk(b.gloed(0) + b.gloed(1), 0.0, "uitgegloeid")
	gelijk(b.aantal_aan(), 2, "maar ze blijven aan")
	waar(not b.beweegt(), "en niets beweegt meer")
	b.slag(99)
	gelijk(b.aantal_aan(), 6, "nooit meer dan er staan")
	b.doof()
	gelijk(b.aantal_aan(), 0, "nog een keer: alles weer bleek")
	# the right answer: every note lit, and a glow sweeps over them
	b.feest()
	gelijk(b.aantal_aan(), 6, "feest: alles aan")
	waar(b.gloed(0) > 0.9 and b.gloed(5) == 0.0, "de gloed begint links")
	_tik(b, BandNotenbalk.FEEST_STAP * 5.0 + 0.05)
	waar(b.gloed(5) > 0.0, "en loopt naar rechts")
	_tik(b, BandNotenbalk.FEEST_S + BandNotenbalk.FEEST_STAP * 6.0)
	waar(not b.beweegt(), "en dooft")
	# reduced motion: lit at once, no glow
	Ui.zet_rust_modus(true)
	b.doof()
	b.slag(3)
	gelijk(b.aantal_aan(), 3, "rust: drie noten aan")
	gelijk(b.gloed(2), 0.0, "rust: geen gloed")
	waar(not b.beweegt(), "rust: niets beweegt")
	b.feest()
	gelijk(b.gloed(0), 0.0, "rust: ook het feest gloeit niet")
	# headless in the tree: the same, whatever the setting
	Ui.zet_rust_modus(false)
	var boom := Engine.get_main_loop() as SceneTree
	var laag := Control.new()
	boom.root.add_child(laag)
	laag.add_child(b)
	b.doof()
	b.slag(4)
	gelijk(b.aantal_aan(), 4, "in de boom: vier noten aan")
	gelijk(b.gloed(3), 0.0, "headless in de boom: meteen af")
	waar(not b.beweegt(), "headless in de boom: niets beweegt")
	# its size is the game's: it asks, and lets go of an old pin
	b.custom_minimum_size = Vector2(900, 900)
	b.meet = func() -> Vector2: return Vector2(320, 120)
	gelijk(b.inhoud_maat(), Vector2(320, 120), "de maat vraagt het spel")
	gelijk(b.custom_minimum_size, Vector2.ZERO, "en laat de oude speld los")
	laag.queue_free()
	Ui.zet_rust_modus(rust_voor)

## The layout, at every size the game may give it: every note inside its own
## bar's tile, every tile inside the stave, no two tiles on each other, the
## notes of a bar left to right and climbing like the pitch, and between two
## bars a gap a child sees — the groups ARE the multiplication.
func test_de_notenbalk_groepeert_de_maten() -> void:
	var gevallen := [
		[[7], Vector2(600, 300)],
		[[6, 5], Vector2(500, 200)],
		[[5, 5, 5, 5], Vector2(960, 260)],
		[[10, 10, 10, 10, 10, 10], Vector2(960, 300)],
		[[10, 10, 10, 10, 10, 10], Vector2(340, 330)],
		[[8, 8, 8, 8, 8, 8], Vector2(700, 140)],
		[[2, 2, 2, 2], Vector2(330, 120)],
		[[8], Vector2(300, 120)],
	]
	for geval in gevallen:
		var ks: Array = geval[0]
		var ruimte: Vector2 = geval[1]
		var wat := "%s in %s" % [str(ks), str(ruimte)]
		var maten := _maten(ks)
		var maat := BandNotenbalk.past(ruimte.x, ruimte.y, maten)
		waar(maat.x <= ruimte.x + 0.5 and maat.y <= ruimte.y + 0.5, "%s: past in de ruimte (%s)" % [wat, str(maat)])
		var b := BandNotenbalk.new()
		b.size = maat
		b.zet(maten)
		var heel := Rect2(Vector2.ZERO, b.size).grow(0.5)
		var stap := b.noot_rect(1).position.x - b.noot_rect(0).position.x if ks[0] > 1 else 0.0
		waar(b.noot_rect(0).size.x >= 4.0, "%s: een noot is te zien (%s)" % [wat, str(b.noot_rect(0))])
		var i := 0
		for m in maten.size():
			var tegel := b.maat_rect(m)
			waar(heel.encloses(tegel), "%s: maat %d in de balk" % [wat, m])
			for m2 in range(m + 1, maten.size()):
				waar(not tegel.grow(-0.5).intersects(b.maat_rect(m2).grow(-0.5)),
					"%s: maat %d en %d liggen niet op elkaar" % [wat, m, m2])
			for j in int(ks[m]):
				var r := b.noot_rect(i)
				gelijk(b.maat_van(i), m, "%s: noot %d hoort bij maat %d" % [wat, i, m])
				waar(tegel.grow(0.5).encloses(r), "%s: noot %d in zijn eigen maat" % [wat, i])
				if j > 0:
					var vorig := b.noot_rect(i - 1)
					waar(r.position.x > vorig.position.x, "%s: noot %d rechts van de vorige" % [wat, i])
					waar(r.position.y < vorig.position.y, "%s: noot %d hoger dan de vorige (de toon stijgt)" % [wat, i])
				i += 1
			# two bars side by side: the gap between them is far wider than
			# the step between two notes of a bar
			if m > 0 and stap > 0.0:
				var links := b.maat_rect(m - 1)
				if absf(links.position.y - tegel.position.y) < 0.5:
					var over := b.noot_rect(i - int(ks[m])).position.x - b.noot_rect(i - int(ks[m]) - 1).position.x
					waar(over >= 2.0 * stap, "%s: tussen maat %d en %d een echte opening (%.1f, noot %.1f)" % [wat, m - 1, m, over, stap])
		gelijk(i, b.aantal(), "%s: elke noot geteld" % wat)
		b.free()

# ------------------------------------------------------------ een hele beurt

## A whole turn in groep 3, the way a child plays it: the animal walks to the
## drum, the stave stands there pale, the drum plays — every tick a plop and
## one more lit note, in time — then the card.  One wrong number: the animal
## sulks, the same four numbers, nothing else changes.  🔁 plays the rhythm
## again.  The right number: `ja`, the band plays, everyone in the room
## cheers, one star, and the game closes itself.
func test_een_hele_beurt() -> void:
	alleen_spellen([SPEL])
	var dag := _dag_voor(2, 3, "tel", 2.8)
	_op()
	_wereld(2, 3, dag)
	var o := Beurt.opzet(2, 3, dag)
	var goed := int(o["goed"])
	var sterren := int(State.s["sterren"])
	var signaal := (State.s["signaal"] as Array).size()
	_hoor_aan()
	waar(Games.start(SPEL), "het spel start")
	var gast := str(_stand().get("gast", ""))
	var d = World.dier(gast)
	waar(d != null and d.kamer == KAMER, "het dier van de beurt is in de muziekkamer")
	if d != null:
		waar(Vector2(d.x, d.z).distance_to(Spel.PLEK) <= 3.0, "naast de trommel")
	gelijk(Games.speler(), gast, "het dier van de beurt staat op de spelbalk")
	gelijk(_stand().get("stap", ""), "luister", "eerst luisteren")
	waar(World.decor_plek(RUST_TROMMEL, KAMER).is_empty(), "de rustende trommel is weg")
	waar(not World.decor_plek(TROMMEL, KAMER).is_empty(), "de eigen trommel staat er")
	var balk := _balk()
	waar(balk != null, "de notenbalk staat groot in beeld")
	if balk == null:
		_af()
		return
	gelijk(balk.aantal(), int(o["tikken"]), "een noot per tik")
	gelijk(balk.aantal_aan(), 0, "nog geen noot aan")
	waar(_knoop(KAART) == null, "nog geen kaart: eerst luisteren")
	waar(_knoop(NOG) != null, "🔁 Nog een keer luisteren staat er")
	waar(_knoop(LUISTER) != null, "het wolkje zegt: luister en kijk goed")
	waar(_spel().speelt(), "de trommel speelt")
	# in time: after the hup and one and a half ticks one or two notes burn
	var bij := Beurt.VOOR_S + Beurt.tik_s(o) * 1.5
	await _wacht(bij)
	var nu := balk.aantal_aan()
	waar(nu >= 1 and nu <= 2, "de noten gaan één voor één aan (%d van %d)" % [nu, balk.aantal()])
	gelijk(_plops(_gehoord).size(), nu, "zoveel plops als lichtjes")
	await _wacht(Beurt.duur(o) - bij + 0.4)
	gelijk(balk.aantal_aan(), balk.aantal(), "na het ritme zijn alle noten aan")
	waar(_gehoord.has("hup"), "het ritme begint met hup (%s)" % str(_gehoord))
	var plops := _plops(_gehoord)
	gelijk(plops.size(), int(o["tikken"]), "een plop per tik (%s)" % str(_gehoord))
	if not plops.is_empty():
		gelijk(plops[0], "plop1", "de eerste tik is de laagste")
		gelijk(plops[plops.size() - 1], "plop%d" % int(o["tikken"]), "de laatste de hoogste")
	waar(Snd.gehoord().has("plop1"), "Snd.gehoord() kent de tikken")
	waar(not _spel().speelt(), "het ritme is uit")
	# a nod is a pose, and after a pose the world chooses what he does next —
	# found in play (2026-10-07): he wandered off the stage mid-rhythm
	d = World.dier(gast)
	waar(d != null and Vector2(d.x, d.z).distance_to(Spel.PLEK) <= 3.0,
		"het dier knikte op elke tik en staat nog bij de trommel (%s)" % (str(Vector2(d.x, d.z)) if d != null else "weg"))
	# the card
	gelijk(_stand().get("stap", ""), "som", "nu de vraag")
	gelijk(_kaart_tekst("Kolom/Regel"), "%s %s" % [Beurt.ICOON, Beurt.vraag(o)], "de vraag")
	var keuzes := _strook()
	gelijk(keuzes.size(), 4, "vier getallen")
	waar(keuzes.has("Kn%d" % goed), "het goede getal staat erbij (%s)" % str(keuzes))
	waar(_knoop(LUISTER) == null, "het luisterwolkje is weg")
	# one wrong number
	var voor := beeld(SPEL)
	_druk(_foute_keuze(goed))
	gelijk(int(_stand().get("missers", 0)), 1, "de misser is geteld")
	gelijk(_stand().get("stap", ""), "som", "dezelfde vraag blijft")
	waar(is_sip(gast), "het dier is teleurgesteld")
	waar(mis_wolk(KAART, gast), "met 🔄 Nog een keer")
	gelijk(_kaart_tekst("Kolom/Hulp"), "", "geen hulpregel")
	await _wacht(Ui.MIS_PAUZE + 0.25)
	niets_erbij(voor, beeld(SPEL), "band")
	gelijk(str(_strook()), str(keuzes), "dezelfde vier getallen in dezelfde volgorde")
	# 🔁: the rhythm again, from the first note
	_gehoord.clear()
	_tik_knop(NOG)
	waar(_spel().speelt(), "de trommel speelt opnieuw")
	gelijk(balk.aantal_aan(), 0, "alle noten weer bleek")
	waar(_knoop(KAART) != null, "de kaart blijft staan")
	await _wacht(Beurt.duur(o) + 0.4)
	gelijk(balk.aantal_aan(), balk.aantal(), "opnieuw alle noten aan")
	gelijk(_plops(_gehoord).size(), int(o["tikken"]), "opnieuw een plop per tik")
	gelijk(int(_stand().get("missers", 0)), 1, "luisteren is geen misser")
	# the right number
	_gehoord.clear()
	_druk("Kn%d" % goed)
	waar(_gehoord.has("ja"), "ja! (%s)" % str(_gehoord))
	gelijk(_stand().get("stap", ""), "af", "goed")
	gelijk(int(State.s["sterren"]), sterren + 1, "één ster voor het meedoen")
	var sig: Array = State.s["signaal"]
	gelijk(sig.size(), signaal + 1, "het signaal is één keer gevoed")
	if sig.size() > signaal:
		gelijk(int((sig[sig.size() - 1] as Dictionary)["g"]), 0, "niet in één keer goed")
	waar(_knoop(NOG) == null, "geen 🔁 meer")
	await _wacht(Spel.SOM_S + Spel.TOVER_S + 0.3)
	waar(_gehoord.has("hoera") and _gehoord.has("tover"), "de band speelt (%s)" % str(_gehoord))
	var laatst := Snd.gehoord()
	waar(laatst.has("ja") and laatst.has("hoera"), "Snd.gehoord(): ja en hoera (%s)" % str(laatst))
	gelijk(_kaart_tekst("Kolom/Regel"), "%s %s" % [Beurt.ICOON_AF, Beurt.T_AF], "de slotzin")
	gelijk(_kaart_tekst("Kolom/Regel2"), Beurt.af2(o), "met het aantal tikken")
	gelijk(_kaart_tekst("Kolom/Rij/Vak"), str(goed), "en het antwoord erin")
	waar(_knoop(BLIJ) != null, "het dier vindt het mooi")
	d = World.dier(gast)
	waar(d != null and str(d.staat) == "blij", "het dier van de beurt juicht")
	gelijk(balk.aantal_aan(), balk.aantal(), "de hele balk brandt")
	await _wacht(Spel.AF_S + 0.4)
	gelijk(Games.actief(), "", "het spel sluit zichzelf")
	waar(Games.actief().is_empty() and _knoop(BALK) == null, "de notenbalk is weg")
	waar(not World.decor_plek(RUST_TROMMEL, KAMER).is_empty(), "de trommel rust weer in de kamer")
	_af()

## Groep 4 and 5: the stave groups the bars (M tiles of k notes — or for the
## inverse question ONE tile), the card asks the band's own question with its
## sum line, the right answer is on the strip and earns the star.
func test_een_beurt_in_groep_4_en_5() -> void:
	alleen_spellen([SPEL])
	for geval in [[4, 4, "maten", 6.0], [8, 5, "omgekeerd", 3.5]]:
		var n: int = geval[0]
		var band: int = geval[1]
		var soort: String = geval[2]
		var dag := _dag_voor(n, band, soort, float(geval[3]))
		_op()
		_wereld(n, band, dag)
		var o := Beurt.opzet(n, band, dag)
		var sterren := int(State.s["sterren"])
		waar(Games.start(SPEL), "band %d: het spel start" % band)
		var balk := _balk()
		waar(balk != null, "band %d: de notenbalk staat er" % band)
		if balk == null:
			_af()
			continue
		var getoond := Beurt.toon(o)
		gelijk(balk.maten.size(), getoond.size(), "band %d: zoveel maten als de trommel speelt" % band)
		if soort == "omgekeerd":
			gelijk(balk.maten.size(), 1, "band %d: de balk toont één maat" % band)
			gelijk(balk.aantal(), int(o["k"]), "band %d: van k noten" % band)
		else:
			gelijk(balk.maten.size(), Beurt.maten_voor(n), "band %d: een maat per gast" % band)
			gelijk(balk.aantal(), int(o["goed"]), "band %d: M × k noten" % band)
			for m in balk.maten.size():
				gelijk((balk.maten[m] as Array).size(), int(o["k"]), "band %d: maat %d heeft k noten" % [band, m])
		await _wacht(Beurt.duur(o) + 0.4)
		gelijk(balk.aantal_aan(), balk.aantal(), "band %d: alle noten aan" % band)
		var gast := str(_stand().get("gast", ""))
		var d = World.dier(gast)
		waar(d != null and Vector2(d.x, d.z).distance_to(Spel.PLEK) <= 3.0,
			"band %d: het dier staat na het ritme nog bij de trommel" % band)
		gelijk(_stand().get("stap", ""), "som", "band %d: de vraag" % band)
		gelijk(_kaart_tekst("Kolom/Regel"), "%s %s" % [Beurt.ICOON, Beurt.vraag(o)], "band %d: de zin" % band)
		gelijk(_kaart_tekst("Kolom/Rij/Som"), str(o["som"]), "band %d: de som" % band)
		waar(_strook().has("Kn%d" % int(o["goed"])), "band %d: het goede getal staat erbij (%s)" % [band, str(_strook())])
		_druk("Kn%d" % int(o["goed"]))
		gelijk(_stand().get("stap", ""), "af", "band %d: goed" % band)
		gelijk(int(State.s["sterren"]), sterren + 1, "band %d: één ster" % band)
		_af()

## The animal of the turn nods onto the drum on every tick — and never once
## leaves the stage while the rhythm plays.  Found in play (2026-10-07): a nod
## is a pose, after a pose the world chooses what he does next, and he
## wandered off onto the xylophone mid-rhythm.  Watched every frame: the
## keeper would bring him back within a second and hide it.
func test_het_dier_blijft_bij_de_trommel() -> void:
	alleen_spellen([SPEL])
	var dag := _dag_voor(4, 4, "maten", 6.0)
	_op()
	_wereld(4, 4, dag)
	var o := Beurt.opzet(4, 4, dag)
	waar(Games.start(SPEL), "het spel start")
	var gast := str(_stand().get("gast", ""))
	var boom := Engine.get_main_loop() as SceneTree
	var t0 := Time.get_ticks_msec()
	var verst := 0.0
	var knikken := 0
	var vorige := ""
	while float(Time.get_ticks_msec() - t0) / 1000.0 < Beurt.duur(o) + 0.3:
		await boom.process_frame
		var d = World.dier(gast)
		if d == null:
			fout("het dier van de beurt is weg")
			break
		verst = maxf(verst, Vector2(d.x, d.z).distance_to(Spel.PLEK))
		var nu := str(d.pose)
		if nu == Spel.KNIK_POSE and vorige != Spel.KNIK_POSE:
			knikken += 1
		vorige = nu
	waar(verst <= 3.0, "hij bleef de hele tijd bij de trommel (verst %.1f voxels)" % verst)
	waar(knikken >= int(o["tikken"]) - 1, "hij knikte op de tikken (%d van %d)" % [knikken, int(o["tikken"])])
	_af()

## A long rhythm (four bars of ten) does not keep the card waiting: after
## `KAART_NA_S` the card asks while the drum plays on, and the notes keep
## lighting until the last one.
func test_een_lang_ritme_laat_de_kaart_niet_wachten() -> void:
	alleen_spellen([SPEL])
	var dag := _dag_voor(4, 4, "maten", 14.0, Beurt.KAART_NA_S + 1.5)
	_op()
	_wereld(4, 4, dag)
	var o := Beurt.opzet(4, 4, dag)
	waar(Beurt.duur(o) > Beurt.KAART_NA_S + 1.0, "een lang ritme (%.1f s)" % Beurt.duur(o))
	waar(Games.start(SPEL), "het spel start")
	# the card asks at the first tick after KAART_NA_S
	await _wacht(Beurt.KAART_NA_S + Beurt.tik_s(o) + 0.3)
	var balk := _balk()
	gelijk(_stand().get("stap", ""), "som", "na %.0f s vraagt de kaart al" % Beurt.KAART_NA_S)
	waar(_knoop(KAART) != null, "de kaart staat er")
	waar(_spel().speelt(), "terwijl de trommel nog speelt")
	waar(balk != null and balk.aantal_aan() < balk.aantal(), "en nog niet alle noten aan zijn")
	await _wacht(Beurt.duur(o) - Beurt.KAART_NA_S - Beurt.tik_s(o) + 0.1)
	waar(balk != null and balk.aantal_aan() == balk.aantal(), "tot de laatste noot")
	_druk("Kn%d" % int(o["goed"]))
	gelijk(_stand().get("stap", ""), "af", "goed")
	_af()

## A reload in the middle: the same rhythm, the same question, the same four
## numbers and the miss still counted; floats from the JSON are numbers again.
## A turn that was finished today gives the next one another rhythm; the next
## day starts afresh.
func test_herladen_hervat_de_beurt() -> void:
	alleen_spellen([SPEL])
	var dag := _dag_voor(4, 4, "maten", 6.0)
	_op()
	_wereld(4, 4, dag)
	var o := Beurt.opzet(4, 4, dag)
	waar(Games.start(SPEL), "het spel start")
	await _wacht(Beurt.duur(o) + 0.4)
	gelijk(_stand().get("stap", ""), "som", "de vraag staat er")
	var vraag := _kaart_tekst("Kolom/Regel")
	var som := _kaart_tekst("Kolom/Rij/Som")
	var keuzes := _strook()
	var ritme := str(Beurt.toon(_spel().opzet()))
	_druk(_foute_keuze(int(o["goed"])))
	await _wacht(Ui.MIS_PAUZE + 0.25)
	Games.stop()
	gelijk(_stand().get("stap", ""), "som", "de stand is bewaard")
	gelijk(int(_stand().get("missers", 0)), 1, "met de misser")
	# through the JSON of a reload: every number a float
	var st: Dictionary = State.spel_data(SPEL)["stand"]
	for k in ["dag", "N", "band", "nr", "missers", "pog", "ster"]:
		st[k] = float(st[k])
	waar(Games.start(SPEL), "opnieuw gestart")
	gelijk(typeof(_stand()["missers"]), TYPE_INT, "missers is weer een geheel getal")
	gelijk(int(_stand().get("missers", 0)), 1, "de misser telt nog")
	gelijk(str(Beurt.toon(_spel().opzet())), ritme, "hetzelfde ritme")
	gelijk(_kaart_tekst("Kolom/Regel"), vraag, "dezelfde vraag, meteen")
	gelijk(_kaart_tekst("Kolom/Rij/Som"), som, "dezelfde som")
	gelijk(str(_strook()), str(keuzes), "dezelfde vier getallen")
	waar(_spel().speelt(), "de trommel speelt het ritme nog een keer")
	_druk("Kn%d" % int(o["goed"]))
	gelijk(_stand().get("stap", ""), "af", "nu goed")
	Games.stop()
	waar(Games.start(SPEL), "nog een beurt op dezelfde dag")
	gelijk(int(_stand().get("nr", -1)), 1, "de tweede beurt van de dag")
	gelijk(_stand().get("stap", ""), "luister", "die begint met luisteren")
	gelijk(int(_stand().get("missers", -1)), 0, "zonder missers")
	gelijk(str(_spel().opzet().get("nr", -1)), "1", "met een eigen ritme")
	Games.stop()
	State.s["dag"] = dag + 1
	waar(Games.start(SPEL), "de volgende dag")
	gelijk(int(_stand().get("nr", -1)), 0, "de eerste beurt van die dag")
	gelijk(int(_stand().get("dag", -1)), dag + 1, "van die dag")
	_af()

## The props stand in the music room while nobody plays, the entry hangs ON
## the drum; a turn takes them away and puts its own there; afterwards the
## resting ones come back.  The stage under them is no walk or furniture spot.
func test_de_rustende_band() -> void:
	alleen_spellen([SPEL])
	_op()
	_wereld(3, 3)
	World.naar(KAMER)
	Games.hersteek()
	var def := Games.definitie(SPEL)
	for stuk in def["rust"]:
		var rust := World.decor_plek(str(stuk["id"]), KAMER)
		waar(not rust.is_empty(), "%s staat in de muziekkamer als er niet gespeeld wordt" % stuk["id"])
		gelijk(float(rust.get("x", -1)), float(stuk["x"]), "%s op zijn plek" % stuk["id"])
	var knop = Hits.spot("spel_band")
	waar(knop != null, "de knop 🥁 Dierenband staat er")
	if knop != null:
		gelijk(str(knop.obj), RUST_TROMMEL, "en hangt aan de trommel")
	waar(Games.start(SPEL), "het spel start")
	for stuk in def["rust"]:
		waar(World.decor_plek(str(stuk["id"]), KAMER).is_empty(), "%s gaat weg" % stuk["id"])
		var eigen := World.decor_plek(Spel.EIGEN + str(stuk["id"]).trim_prefix(Spel.RUST), KAMER)
		waar(not eigen.is_empty(), "het spel zet zijn eigen %s neer" % stuk["model"])
		gelijk(float(eigen.get("z", -1)), float(stuk["z"]), "op dezelfde plek")
	Games.stop()
	waar(World.decor_plek(TROMMEL, KAMER).is_empty(), "na het spel is de eigen trommel weg")
	waar(not World.decor_plek(RUST_TROMMEL, KAMER).is_empty(), "en staat de rustende trommel er weer")
	var r := Rooms.get_kamer(KAMER)
	for p in r.plekken:
		waar(not (p[0] >= 40 and p[0] <= 64 and p[1] >= 40 and p[1] <= 64),
			"geen loopplek op de trommel (%s)" % str(p))
	waar(not Rooms.vrij_vak(KAMER, Spel.TROMMEL_MIDDEN.x, Spel.TROMMEL_MIDDEN.y),
		"er kan geen meubel op de trommel")
	_af()

func test_zonder_gasten() -> void:
	alleen_spellen([SPEL])
	_op()
	State.nieuw_spel()
	State.s["gasten"] = []
	World.sync([])
	waar(not Games.speelbaar_nu(SPEL), "zonder gasten geen knop en geen briefje")
	waar(Games.start(SPEL), "het spel start toch (een oude knop)")
	waar(_knoop(LEEG) != null, "het wolkje zegt dat er nog geen gasten zijn")
	await _wacht(Spel.LEEG_S + 0.3)
	gelijk(Games.actief(), "", "en het spel sluit zichzelf")
	_af()

# ------------------------------------------------------- op vier schermen

## The real shell on the four screens, with the card up (a turn that comes
## back after a reload asks at once): every element of the game inside the
## frame at a real place, the stave clear of the card and its strip, and the
## animal at the drum not hidden behind it.
func test_op_vier_schermen() -> void:
	alleen_spellen([SPEL])
	var bewaard: Dictionary = State.s.duplicate(true)
	var scherm_terug = Ui.get("_scherm")
	var rust_voor := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	var boom := Engine.get_main_loop() as SceneTree
	# groep 5 with six bars, groep 4 with four, groep 3 with ONE short bar
	# (narrow and tall: it must stay in its band, not slide onto the drum)
	for geval in [[8, 5, 1], [4, 4, 2], [1, 3, 1]]:
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
			var n: int = geval[0]
			var dag: int = geval[2]
			var gasten := _wereld(n, geval[1], dag)
			Hotel.start()
			var wat := "%s, %d gasten" % [str(maat), n]
			# the turn that comes back: the card asks at once
			State.spel_data(SPEL)["stand"] = {"gast": str(gasten[0]["id"]), "dag": dag, "N": n,
				"band": State.band(), "nr": 0, "stap": "som", "pog": 0, "missers": 0, "ster": 0}
			waar(Games.start(SPEL), "%s: het spel start" % wat)
			for _f in 6:
				await boom.process_frame
			var kader: Control = shell.get_node("Scherm/Kolom/Middenrij/Kaderdoos/Kader")
			_keur(kader.size, wat)
			var dbg := Hits.debug()
			waar(dbg.has(BALK) and dbg.has(KAART), "%s: de notenbalk en de kaart staan er" % wat)
			if dbg.has(BALK):
				var b: Rect2 = dbg[BALK]["rect"]
				var dier := World.vlak_van_dier(str(gasten[0]["id"]))
				if dier.size.x > 0.0:
					waar(not b.has_point(dier.get_center()),
						"%s: het dier staat niet achter de notenbalk (%s, %s)" % [wat, str(b), str(dier)])
				var vel: Vector2 = World.mik_punt(Spel.TROMMEL_MIDDEN.x, Spel.TROMMEL_MIDDEN.y,
					float(ArtDecorMuziek.TROMMEL_TOP))
				waar(not b.has_point(vel), "%s: de trommel staat niet achter de notenbalk (%s, %s)" % [wat, str(b), str(vel)])
				for id in [KAART, STROOK, NOG]:
					if dbg.has(id):
						var andere: Rect2 = dbg[id]["rect"]
						var snij := b.intersection(andere)
						waar(snij.size.x <= 0.5 or snij.size.y <= 0.5,
							"%s: de notenbalk ligt niet over %s (%s, %s)" % [wat, id, str(b), str(andere)])
				var balk := _balk()
				if balk != null:
					waar(balk.noot_rect(0).size.x >= 6.0, "%s: de noten zijn te zien (%s)" % [wat, str(balk.noot_rect(0))])
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
		var spot = Hits.spot(id)
		if spot == null or spot.door != SPEL:
			continue
		eigen += 1
		var d: Dictionary = dbg[id]
		var r: Rect2 = d["rect"]
		waar(not bool(d["krap"]), "%s: %s vond een echte plek" % [wat, id])
		waar(r.position.x >= -0.01 and r.position.y >= -0.01
			and r.end.x <= kader.x + 0.01 and r.end.y <= kader.y + 0.01,
			"%s: %s staat binnen het kader (%s in %s)" % [wat, id, str(r), str(kader)])
		if spot.kind == "tag" or int(d["laag"]) == Hits.Laag.VAST:
			continue
		waar(r.size.x >= 44.0 and r.size.y >= 44.0, "%s: %s is een tikdoel" % [wat, id])
	waar(eigen >= 3, "%s: het spel staat op het scherm (%d)" % [wat, eigen])
