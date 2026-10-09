extends Proef
## post — De post sorteren in de postkamer (U4, 2026-10-07), headless.
##
## Driven the way a child drives it: an answer is a `pressed` on a button of
## the real strip under the card.  Only the pure turn logic in `beurt.gd` and
## the models in `art/decor_post.gd` are called directly.

const SPEL := "post"
const KAMER := "postkamer"
const KAART := "po_som"
const STROOK := "po_som_keuzes"
const KAST := "po_kast"
const KAR := "po_kar"
const BALIE := "po_balie"
const ADRES := "po_adres"
const RUST_KAST := "rust_po_kast"
const RUST_KAR := "rust_po_kar"
const RUST_BALIE := "rust_po_balie"
const Beurt := preload("res://games/post/beurt.gd")
const Spel := preload("res://games/post/spel.gd")
const Modellen := preload("res://art/decor_post.gd")

## The four ticket screens (tablet both ways, phone both ways) and the owner's
## own screen.
const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(360, 740),
	Vector2i(740, 360), Vector2i(1536, 760)]

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

## `n` guests from the pool, the first `met_bed` (all, by default) in a real
## bed; `kunnen` lifts the adaptive cap so the band really is the band the test
## asks for.  The post task is on the board, so its tick can be seen.
func _wereld(n: int, band: int, dag := 2, met_bed := -1) -> Array:
	State.nieuw_spel()
	State.s["taken"] = [{"id": "post", "spel": "post", "icoon": Beurt.ICOON,
		"tekst": Beurt.T_TAAK, "kamer": KAMER, "actie": "game:post", "prio": 6, "klaar": false}]
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

## Every guest asleep in his own bed upstairs, whatever an earlier test did
## with him (`World.sync` keeps a guest where he stands).  Reduced motion: at
## once.
func _boven(gasten: Array) -> void:
	for g in gasten:
		if not str(g.get("bed", "")).is_empty():
			World.slaap(str(g["id"]), str(g["kamer"]), str(g["bed"]))

func _knoop(id: String) -> Control:
	var s := Hits.spot(id)
	return null if s == null or not is_instance_valid(s.knoop) else s.knoop

## One hole on the real strip under the card.
func _kies(j: int) -> bool:
	var strook := _knoop(STROOK)
	if strook == null:
		fout("er is geen keuzestrook")
		return false
	var k := strook.get_node_or_null("Rij/Kvak%d" % j)
	if k == null:
		fout("vakje %d staat niet op de strook (%s)" % [j, str(_strook())])
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

## The words on the strip's buttons, in order.
func _strook_teksten() -> Array[String]:
	var uit: Array[String] = []
	var strook := _knoop(STROOK)
	var rij := strook.get_node_or_null("Rij") if strook != null else null
	if rij == null:
		return uit
	for k in rij.get_children():
		uit.append((k as Button).text)
	return uit

func _kaart_tekst(deel: String) -> String:
	var k := _knoop(KAART)
	if k == null:
		return ""
	var l := k.get_node_or_null(deel) as Label
	return "" if l == null else l.text

func _tag_tekst(id: String) -> String:
	var k := _knoop(id) as Label
	return "" if k == null else k.text

func _stand() -> Dictionary:
	var d = State.spel_data(SPEL).get("stand", {})
	return d if typeof(d) == TYPE_DICTIONARY else {}

func _spel() -> Node:
	return Games._knoop if Games.actief() == SPEL else null

func _opzet() -> Dictionary:
	var s := _spel()
	return {} if s == null else s.opzet()

func _brief() -> Dictionary:
	var o := _opzet()
	var i := int(_stand().get("i", 0))
	var b: Array = o.get("brieven", [])
	return b[i] if i < b.size() else {}

func _wacht(s: float) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	await boom.create_timer(s).timeout

## The strip is locked for `Ui.MIS_PAUZE` after a miss (S5): tap again only
## after it, the way a child with a real finger does.
func _wacht_mispauze() -> void:
	await _wacht(Ui.MIS_PAUZE + 0.25)

## Two drawn frames: every placement pass of the start has run.
func _rust_af() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	for _f in 2:
		await boom.process_frame

## The next letter comes SOM_S after a right one.
func _wacht_brief() -> void:
	await _wacht(Spel.SOM_S + 0.25)

func _fout_vak(goed: int) -> int:
	return (goed + 1) % Beurt.VAKJES

## Sort every letter that is left, right first time.
func _sorteer_alles() -> void:
	var n := 0
	while str(_stand().get("stap", "")) == "sorteer" and n < 10:
		var br := _brief()
		if br.is_empty():
			break
		_kies(int(br["vak"]))
		n += 1
		await _wacht_brief()

# ------------------------------------------------------------- het rekenen

func test_een_brief_per_gast_tussen_twee_en_zes() -> void:
	gelijk(Beurt.aantal(0), 2, "zonder gasten toch twee brieven")
	gelijk(Beurt.aantal(1), 2, "één gast: twee brieven")
	gelijk(Beurt.aantal(4), 4, "vier gasten: vier brieven")
	gelijk(Beurt.aantal(8), 6, "een vol hotel: hooguit zes brieven")

func test_groep_3_vakjes_van_vijf_tot_twintig() -> void:
	var vk := Beurt.vakjes(3, 3, 1)
	gelijk(vk.size(), 4, "vier vakjes")
	gelijk(vk[0], {"van": 1, "tot": 5}, "1 - 5")
	gelijk(vk[1], {"van": 6, "tot": 10}, "6 - 10")
	gelijk(vk[2], {"van": 11, "tot": 15}, "11 - 15")
	gelijk(vk[3], {"van": 16, "tot": 20}, "16 - 20")
	gelijk(Beurt.plaat(vk[2]), "11 - 15", "het plaatje toont beide getallen")
	gelijk(Beurt.kort(vk[2]), "11-15", "kort: zonder spaties, nog steeds beide getallen")
	gelijk(Beurt.vak_van(13, vk), 2, "13 hoort in 11 - 15")
	gelijk(Beurt.vak_van(5, vk), 0, "5 hoort in 1 - 5")
	gelijk(Beurt.vak_van(16, vk), 3, "16 hoort in 16 - 20")
	gelijk(Beurt.vak_van(21, vk), -1, "21 past nergens")

func test_groep_4_en_5_vier_tientallen_tot_honderd() -> void:
	for band in [4, 5]:
		for dag in range(1, 15):
			for n in range(2, 7):
				var vk := Beurt.vakjes(band, n, dag)
				gelijk(vk.size(), 4, "vier vakjes")
				for j in 4:
					gelijk(int(vk[j]["tot"]) - int(vk[j]["van"]), 9, "een vakje is een tiental")
					gelijk(int(vk[j]["van"]) % 10, 0, "een vakje begint op een tiental")
					if j > 0:
						gelijk(int(vk[j]["van"]), int(vk[j - 1]["tot"]) + 1, "de vakjes sluiten aan")
				waar(int(vk[0]["van"]) >= 0 and int(vk[3]["tot"]) <= 99, "alles onder de honderd")
	gelijk(Beurt.vak_van(34, [{"van": 30, "tot": 39}, {"van": 40, "tot": 49}]), 0, "34 hoort in 30 - 39")

## Every band, every day, every hotel size and four rounds: every letter has
## its hole, groep 5 writes a product of the tables, and one pile never holds
## the same letter twice.
func test_elke_brief_past_in_een_vakje() -> void:
	for band in [3, 4, 5]:
		for dag in range(1, 15):
			for n_gasten in range(0, 9):
				for ronde in range(0, 4):
					var b := Beurt.maak(band, n_gasten, dag, ronde)
					var vk: Array = b["vakjes"]
					var brieven: Array = b["brieven"]
					gelijk(brieven.size(), Beurt.aantal(n_gasten), "één brief per gast")
					var teksten := {}
					for br in brieven:
						waar(not teksten.has(str(br["tekst"])),
							"groep %d dag %d ronde %d: brief %s maar één keer" % [band, dag, ronde, str(br["tekst"])])
						teksten[str(br["tekst"])] = true
						var j := int(br["vak"])
						waar(j >= 0 and j < 4, "brief %d heeft een vakje (groep %d, dag %d)" % [int(br["getal"]), band, dag])
						if j >= 0:
							waar(int(br["getal"]) >= int(vk[j]["van"]) and int(br["getal"]) <= int(vk[j]["tot"]),
								"brief %d ligt in zijn vakje %s" % [int(br["getal"]), Beurt.plaat(vk[j])])
						if band >= 5:
							waar(" × " in str(br["tekst"]), "groep 5: een keersom op de brief (%s)" % str(br["tekst"]))
							var delen := str(br["tekst"]).split(" × ")
							gelijk(int(delen[0]) * int(delen[1]), int(br["getal"]), "de keersom klopt")
							waar(int(delen[0]) >= 2 and int(delen[0]) <= 10 and int(delen[1]) >= 2 and int(delen[1]) <= 10,
								"uit de tafels van 2 tot 10")
						else:
							gelijk(str(br["tekst"]), str(br["getal"]), "groep 3/4: het getal zelf op de brief")
						if band == 3:
							waar(int(br["getal"]) >= 1 and int(br["getal"]) <= 20, "groep 3 tot 20")

func test_de_voorbeelden_uit_het_ontwerp() -> void:
	# groep 5: 7 × 8 = 56 lands in 50 - 59 whenever the window holds it
	var vk := [{"van": 50, "tot": 59}, {"van": 60, "tot": 69}, {"van": 70, "tot": 79}, {"van": 80, "tot": 89}]
	gelijk(Beurt.vak_van(7 * 8, vk), 0, "7 × 8 → 50 - 59")
	gelijk(Beurt.vak_van(9 * 9, vk), 3, "9 × 9 → 80 - 89")
	var paren: Array = Beurt._tafels_in(0, 39)
	waar(paren.has(Vector2i(3, 4)), "3 × 4 zit in het venster 0..39")
	waar(not paren.has(Vector2i(7, 8)), "7 × 8 niet")
	gelijk(Beurt.adres({"tekst": "34"}), "📮 34", "het adres op de bovenste brief")
	gelijk(Beurt.adres({"tekst": "7 × 8"}), "📮 7 × 8", "ook als keersom")
	gelijk(str(Beurt.vol([{"vak": 2}, {"vak": 0}, {"vak": 2}], 3)), str([1, 0, 2, 0]),
		"de vakjes vullen zich met wat er gesorteerd is")
	gelijk(str(Beurt.vol([{"vak": 2}, {"vak": 0}, {"vak": 2}], 1)), str([0, 0, 1, 0]),
		"alleen de brieven die al gesorteerd zijn")

## A second turn on the same day brings a fresh pile for the same holes.
func test_een_tweede_ronde_is_een_nieuwe_stapel() -> void:
	for band in [3, 4, 5]:
		var a := Beurt.maak(band, 4, 3, 0)
		var b := Beurt.maak(band, 4, 3, 1)
		gelijk(str(a["vakjes"]), str(b["vakjes"]), "groep %d: dezelfde kast" % band)
		waar(str(a["brieven"]) != str(b["brieven"]), "groep %d: andere brieven" % band)
		gelijk(str(a["brieven"]), str(Beurt.maak(band, 4, 3, 0)["brieven"]), "groep %d: vast per ronde" % band)

# ---------------------------------------------------------- tekst en tekens

## Every sentence a child reads fits the budget (HOTEL.md §9: ≤ 8 words AND
## ≤ 40 characters with the pictogram in front) and every glyph is in the
## bundled subset (📮 since F1; the first draft used 💌 while it was missing).
func test_elke_zin_past() -> void:
	if Ui.thema == null or Ui.thema.default_font == null:
		Ui._bouw_thema(17)
	for paar in [[Beurt.ICOON, Beurt.T_VRAAG], [Beurt.ICOON_AF, Beurt.T_AF]]:
		var zin := "%s %s" % [paar[0], paar[1]]
		waar(Ui.keur_regel("post", paar[1]), "binnen het budget: %s" % paar[1])
		waar(zin.length() <= 40, "met het pictogram ≤ 40 tekens: %s (%d)" % [zin, zin.length()])
		waar(zin.split(" ", false).size() <= 8, "met het pictogram ≤ 8 woorden: %s" % zin)
		gelijk(Ui.mist_tekens(zin).size(), 0, "alle tekens bestaan: %s" % zin)
	waar(Ui.keur_taak("post", Beurt.T_TAAK), "het briefje op het prikbord heeft ≤ 6 woorden")
	for zin in [Beurt.T_TAAK, Beurt.T_KNOP, Beurt.T_KEUZE_TITEL, Beurt.T_TITEL,
			Beurt.adres({"tekst": "7 × 8"}), Rooms.get_kamer(KAMER).icoon + " " + Rooms.get_kamer(KAMER).naam]:
		gelijk(Ui.mist_tekens(zin).size(), 0, "alle tekens bestaan: %s" % zin)
	for band in [3, 4, 5]:
		for vk in Beurt.vakjes(band, 4, 2):
			gelijk(Ui.mist_tekens(Beurt.ICOON + " " + Beurt.plaat(vk)).size(), 0, "het vakje: %s" % Beurt.plaat(vk))
	# the glyph trap the first draft walked into: 📮 was not in the subset, so
	# the post used 💌 until F1 added it.  Only the glyph in USE is pinned here
	# (integration I1b), so a later switch stays a one-line change in beurt.gd.
	gelijk(Ui.mist_tekens(Beurt.ICOON).size(), 0, "het pictogram %s bestaat" % Beurt.ICOON)

# --------------------------------------------------------------- aanmelding

func test_definitie_en_scene() -> void:
	var scene: PackedScene = load("res://games/post/spel.tscn")
	waar(scene != null, "de scene laadt")
	var spel = scene.instantiate()
	waar(spel is MiniGame, "het spel is een MiniGame")
	var d: Dictionary = spel.definitie()
	gelijk(d["kamer"], "postkamer", "het spel staat in de postkamer")
	waar(not bool(d.get("stub", true)), "geen stub meer: de beurt is rond")
	gelijk(d["taak"]["id"], "post", "de taakkaart heet post")
	gelijk(d["hotspot"]["icoon"], "📮", "de knop draagt de brievenbus")
	waar((d["unlock"] as Callable).call(1, 3), "open vanaf de eerste gast")
	waar(not (d["unlock"] as Callable).call(0, 3), "zonder gasten nog niet")
	spel.free()

## The directory scan finds the game; its entry hangs on the resting cart, its
## models are known before it ever ran, and its board card is a normal chore.
func test_aanmelding() -> void:
	waar(Games.lijst().has(SPEL), "de mapscan vindt post")
	var def := Games.definitie(SPEL)
	gelijk(def.get("naam", ""), "De post sorteren", "naam")
	gelijk(def.get("kamer", ""), KAMER, "kamer")
	gelijk(def.get("stub", true), false, "geen stub")
	var hs: Dictionary = def.get("hotspot", {})
	gelijk(hs.get("rust", ""), RUST_KAR, "de ingang hangt aan de rustende postkar")
	gelijk(hs.get("obj", ""), RUST_KAR, "en heeft geen ander voorwerp nodig")
	gelijk(hs.get("label", ""), "Post", "label")
	var modellen: Dictionary = def.get("modellen", {})
	for m in ["post_kast", "post_kar", "post_balie"]:
		waar(modellen.has(m), "%s wordt bij de scan aangemeld" % m)
		waar(Art.heeft_model(m), "en Art kent %s" % m)
	var rust: Array = def.get("rust", [])
	var ids: Array[String] = []
	for stuk in rust:
		ids.append(str((stuk as Dictionary).get("id", "")))
	gelijk(str(ids), str([RUST_KAST, RUST_BALIE, RUST_KAR]), "drie rustspullen: kast, balie, kar")
	var taak: Dictionary = def.get("taak", {})
	gelijk(taak.get("id", ""), "post", "taak id")
	gelijk(taak.get("kamer", ""), KAMER, "het briefje zegt: in de postkamer")
	waar(int(taak.get("prio", 0)) >= 5, "een gewoon klusje (prio ≥ 5)")

## Integration I1a (2026-10-07): the post room hangs on the KAS, not on the
## lobby — a fifth opening in the lobby found no place for its sign on a phone
## and pushed the bell and the board around (tests/test_hits.gd,
## tests/test_knoppen_staan_stil.gd).  Still the ground floor.
func test_de_kamer_bestaat_en_hangt_aan_de_kas() -> void:
	waar(Rooms.bestaat("postkamer"), "de postkamer bestaat")
	gelijk(Rooms.etage("postkamer"), 0, "op de begane grond")
	waar(not Rooms.deur("kas", "postkamer").is_empty(), "de kas heeft een deur erheen")
	waar(not Rooms.deur("postkamer", "kas").is_empty(), "en de postkamer terug")
	gelijk(Rooms.pad("receptie", "postkamer"), ["receptie", "tuin", "kas", "postkamer"],
		"vanuit de receptie door de tuin en de kas")
	waar(Rooms.get_kamer("postkamer").trap.is_empty(), "geen trap: die blijft in de trapkamers")
	gelijk(Rooms.get_kamer("postkamer").icoon, "📮", "de kamer draagt de brievenbus, net als het spel")

func test_de_modellen_bakken() -> void:
	for naam in ["post_kast", "post_kar", "post_balie"]:
		for g in [2, 3, 4]:
			for params in [{}, {"vol": [1, 2, 0, 6], "brieven": 6}, {"vol": [9, -1], "brieven": 99}]:
				var p = Art.plaat(naam, g, params)
				waar(p != null and p.w > 0 and p.h > 0, "%s bakt op g=%d met %s" % [naam, g, str(params)])
	var v: Array = Modellen.pakketweegschaal()
	waar(v.size() > 50, "de weegschaal heeft voxels (%d)" % v.size())
	var leeg: Array = Modellen.postkar({"brieven": 0})
	var vol: Array = Modellen.postkar({"brieven": 5})
	waar(vol.size() > leeg.size(), "meer brieven, een hogere stapel op de kar")
	var kast0: Array = Modellen.vakkenkast({"vol": [0, 0, 0, 0]})
	var kast1: Array = Modellen.vakkenkast({"vol": [0, 0, 1, 0]})
	waar(kast1.size() > kast0.size(), "een gesorteerde brief ligt echt in de kast")
	# the anchors: the shelf stands against the back wall, centred on its length
	var minx := 999
	var maxx := -999
	var minz := 999
	for vox in kast0:
		minx = mini(minx, int(vox["x"]))
		maxx = maxi(maxx, int(vox["x"]))
		minz = mini(minz, int(vox["z"]))
	waar(absi(minx + maxx) <= 2, "de kast is gecentreerd op zijn lengte (%d..%d)" % [minx, maxx])
	gelijk(minz, 0, "en staat met zijn rug tegen de muur")
	# every hole lies inside the room, in a row along the back wall
	var r := Rooms.get_kamer(KAMER)
	for j in 4:
		var p := Spel.vak_plek(j)
		waar(p.x > 4.0 and p.x < float(r.w) - 4.0, "vakje %d staat in de kamer (x %.1f)" % [j, p.x])
		if j > 0:
			waar(p.x > Spel.vak_plek(j - 1).x, "vakje %d staat rechts van vakje %d" % [j, j - 1])

# ------------------------------------------------------------ een hele beurt

## Groep 4, the whole turn by finger: the card and the first letter at once,
## while the postbode is still on his way from his room upstairs (W5e: the
## first play waited 14–24 s for him); he arrives in his own time and joins;
## the shelf with its four plates, the address on the cart, one miss, every
## letter into its hole, the star, the board card ticked, his cheer, and the
## game closes itself.
func test_een_beurt_in_groep_4() -> void:
	_op()
	var gasten := _wereld(4, 4)
	var sterren := int(State.s["sterren"])
	var signaal := (State.s["signaal"] as Array).size()
	# real walking for the start: everybody sleeps upstairs in kamer 1 and 2
	_boven(gasten)
	Ui.zet_rust_modus(false)
	var t0 := Time.get_ticks_msec()
	waar(Games.start(SPEL), "het spel start")
	var o := Beurt.maak(4, 4, 2, 0)
	gelijk(str(_opzet().get("brieven", [])), str(o["brieven"]), "de stapel van vandaag")
	gelijk(_stand().get("stap", ""), "sorteer", "er wordt gesorteerd")
	gelijk(Games.speler(), str(_stand().get("gast", "")), "de spelbalk weet wie de postbode is")
	waar(not str(_stand().get("gast", "")).is_empty(), "er is een postbode")
	var gast := str(_stand().get("gast", ""))
	var d = World.dier(gast)
	# the question is there in the same frame as the tap; he is not
	waar(_knoop(KAART) != null and _knoop(STROOK) != null, "de vraag en de strook staan er meteen")
	waar(Time.get_ticks_msec() - t0 < 1000, "binnen een seconde (%d ms)" % (Time.get_ticks_msec() - t0))
	gelijk(_kaart_tekst("Kolom/Rij/Som"), str(o["brieven"][0]["tekst"]), "met de eerste brief")
	waar(d != null and d.kamer != KAMER and str(d.reis_doel) == KAMER,
		"terwijl de postbode nog onderweg is (%s → %s)" % [str(d.kamer) if d != null else "-",
			str(d.reis_doel) if d != null else "-"])
	# the game does not wait for him: no "komt eraan" with 👀 Volg, the camera
	# stays with the card in the postkamer
	waar(not Games.verwacht_dier(gast), "het spel wacht niet op hem")
	Hotel.volg(gast)
	gelijk(Hotel.volgt(), "", "Volg loopt niet met hem mee")
	gelijk(World.kamer_nu(), KAMER, "de camera blijft in de postkamer")
	# he joins in his own time (reduced motion from here: the next look of
	# the turn puts him at the cart)
	Ui.zet_rust_modus(true)
	await _wacht(Spel.KOM_TIK * 2.0 + 0.1)
	waar(d != null and d.kamer == KAMER, "de postbode is in de postkamer")
	if d != null:
		waar(absf(d.x - Spel.GAST_X) + absf(d.z - Spel.GAST_Z) <= 3.0, "bij de kar (%.0f, %.0f)" % [d.x, d.z])
	gelijk(int(_stand().get("i", -1)), 0, "en de eerste brief ligt er nog")
	# the shelf, the counter and the cart stand there; the resting ones went
	for id in [KAST, KAR, BALIE]:
		waar(not World.decor_plek(id, KAMER).is_empty(), "%s staat in de postkamer" % id)
	for id in [RUST_KAST, RUST_KAR, RUST_BALIE]:
		waar(World.decor_plek(id, KAMER).is_empty(), "%s is weg zolang er gespeeld wordt" % id)
	gelijk(int(World.decor_plek(KAR, KAMER)["params"]["brieven"]), 4, "vier brieven op de kar")
	# the four plates over the holes, left to right, and the same words on the strip
	var platen: Array[String] = []
	for j in 4:
		platen.append(_tag_tekst("po_vak%d" % j))
		gelijk(platen[j], Beurt.plaat(o["vakjes"][j]), "het bordje van vakje %d" % j)
	gelijk(str(_strook()), str(["Kvak0", "Kvak1", "Kvak2", "Kvak3"]), "vier knoppen: de vier vakjes, op volgorde")
	var teksten := _strook_teksten()
	for j in 4:
		waar(teksten[j].contains(platen[j]) or teksten[j].contains(Beurt.kort(o["vakjes"][j])),
			"knop %d zegt wat zijn bordje zegt (%s / %s)" % [j, teksten[j], platen[j]])
		waar(teksten[j].begins_with(Beurt.ICOON), "pictogram en woord (%s)" % teksten[j])
	# the card: the question, the letter's number on the sum line, no answer box
	var br: Dictionary = o["brieven"][0]
	gelijk(_kaart_tekst("Kolom/Regel"), Beurt.ICOON + " " + Beurt.T_VRAAG, "de vraag op de kaart")
	gelijk(_kaart_tekst("Kolom/Rij/Som"), str(br["tekst"]), "het adres op de somregel")
	gelijk(_tag_tekst(ADRES), Beurt.adres(br), "en op de bovenste brief op de kar")
	waar(Ui.is_som(KAART), "de vraag telt als som: de kamerbalk wacht")
	# a miss: the same letter, the postbode disappointed, nothing lost, no help
	# (the picture is taken once the placement passes settled: whether the
	# plates fit is the frame's business, not the miss's)
	await _rust_af()
	var voor := beeld(SPEL)
	_kies(_fout_vak(int(br["vak"])))
	gelijk(int(_stand().get("i", -1)), 0, "een misser: dezelfde brief")
	gelijk(int(_stand().get("missers", 0)), 1, "de misser is geteld")
	waar(is_sip(gast), "de postbode is teleurgesteld")
	waar(mis_wolk(KAART), "met 🔄 Nog een keer")
	var strook := _knoop(STROOK) as UiKeuzes
	waar(strook != null and strook.op_slot, "de strook staat even op slot (S5)")
	gelijk(int(State.s["sterren"]), sterren, "een misser kost niets")
	await _wacht_mispauze()
	niets_erbij(voor, beeld(SPEL), "na de misser")
	gelijk(_kaart_tekst("Kolom/Hulp"), "", "geen hulpregel")
	gelijk(str(_strook()), str(["Kvak0", "Kvak1", "Kvak2", "Kvak3"]), "dezelfde vier vakjes")
	# right: the letter goes into its hole, the pile gets lower
	var hoor := Snd.luister(func() -> void: _kies(int(br["vak"])))
	waar(hoor.has("brief") and hoor.has("ja"), "de brief gaat door de brievenbus (%s)" % str(hoor))
	gelijk(int(_stand().get("i", -1)), 1, "de volgende brief")
	var vol: Array = World.decor_plek(KAST, KAMER)["params"]["vol"]
	gelijk(int(vol[int(br["vak"])]), 1, "de brief ligt in zijn vakje")
	gelijk(int(World.decor_plek(KAR, KAMER)["params"]["brieven"]), 3, "nog drie op de kar")
	waar(_knoop(ADRES) == null, "terwijl de brief vliegt, geen adres op de kar")
	await _wacht_brief()
	var br2: Dictionary = o["brieven"][1]
	gelijk(_kaart_tekst("Kolom/Rij/Som"), str(br2["tekst"]), "de tweede brief op de kaart")
	gelijk(_tag_tekst(ADRES), Beurt.adres(br2), "en op de kar")
	# up to the last letter; the hotel rebuilds its board while the game runs,
	# so the post card is put on it right before the last one goes
	for k in 2:
		_kies(int(_brief()["vak"]))
		await _wacht_brief()
	gelijk(int(_stand().get("i", -1)), 3, "de laatste brief")
	State.s["taken"] = [{"id": "post", "spel": "post", "icoon": Beurt.ICOON,
		"tekst": Beurt.T_TAAK, "kamer": KAMER, "actie": "game:post", "prio": 6, "klaar": false}]
	_kies(int(_brief()["vak"]))
	gelijk(_stand().get("stap", ""), "af", "alle post is gesorteerd")
	gelijk(int(State.s["sterren"]), sterren + 1, "één ster voor het meedoen")
	gelijk((State.s["signaal"] as Array).size(), signaal + 1, "het adaptieve signaal kreeg één beurt")
	gelijk(int((State.s["signaal"] as Array).back()["g"]), 0, "met een misser: niet in één keer goed")
	waar(bool((State.s["taken"] as Array)[0].get("klaar", false)), "het briefje op het prikbord is af")
	gelijk(_kaart_tekst("Kolom/Regel"), Beurt.ICOON_AF + " " + Beurt.T_AF, "de slotzin")
	gelijk(int(World.decor_plek(KAR, KAMER)["params"]["brieven"]), 0, "de kar is leeg")
	var totaal := 0
	for n in World.decor_plek(KAST, KAMER)["params"]["vol"]:
		totaal += int(n)
	gelijk(totaal, 4, "alle vier de brieven liggen in de kast")
	waar(_knoop(ADRES) == null, "geen adres meer")
	waar(gasten.size() == 4, "vier gasten")
	waar(d != null and str(d.staat) == "blij", "de postbode juicht mee (%s)" % (str(d.staat) if d != null else "-"))
	await _wacht(Spel.AF_S + 0.3)
	gelijk(Games.actief(), "", "het spel sluit zichzelf")
	waar(not World.decor_plek(RUST_KAR, KAMER).is_empty(), "en de rustende kar staat er weer")
	_af()

## Groep 3: numbers to twenty into holes of five; first time right counts as
## right for the adaptive signal.
func test_een_beurt_in_groep_3() -> void:
	_op()
	_wereld(1, 3)
	waar(Games.start(SPEL), "het spel start")
	var o := Beurt.maak(3, 1, 2, 0)
	gelijk(str(_opzet().get("vakjes", [])), str(o["vakjes"]), "1 - 5 · 6 - 10 · 11 - 15 · 16 - 20")
	gelijk(_tag_tekst("po_vak0"), "1 - 5", "het eerste bordje")
	gelijk(_tag_tekst("po_vak3"), "16 - 20", "het laatste bordje")
	gelijk((o["brieven"] as Array).size(), 2, "één gast: twee brieven")
	await _sorteer_alles()
	gelijk(_stand().get("stap", ""), "af", "gesorteerd")
	gelijk(int((State.s["signaal"] as Array).back()["g"]), 1, "in één keer goed")
	_af()

## Groep 5: a product of the tables on every letter, the holes are tens.
func test_een_beurt_in_groep_5() -> void:
	_op()
	_wereld(8, 5)
	waar(Games.start(SPEL), "het spel start")
	var br := _brief()
	waar(str(br.get("tekst", "")).contains(" × "), "een keersom op de brief (%s)" % str(br.get("tekst", "")))
	gelijk(_kaart_tekst("Kolom/Rij/Som"), str(br["tekst"]), "op de somregel")
	gelijk(_tag_tekst(ADRES), Beurt.adres(br), "en op de kar")
	gelijk((_opzet()["brieven"] as Array).size(), 6, "zes brieven bij een vol hotel")
	await _sorteer_alles()
	gelijk(_stand().get("stap", ""), "af", "gesorteerd")
	_af()

## The owner, 2026-09-24: "Nee geef geen hulp na fouten."  Three wrong holes
## in a row: every time the postbode sulks with `🔄 Nog een keer`, and after
## the pause the shelf, the cart, the plates, the card and the strip are
## exactly what they were.  The same letter stays, and the right hole still
## takes it.
func test_geen_hulp_na_een_fout() -> void:
	_op()
	_wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	var gast := str(_stand().get("gast", ""))
	var br := _brief()
	var regel := _kaart_tekst("Kolom/Regel")
	var keuzes := _strook()
	await _rust_af()
	var voor := beeld(SPEL)
	waar(voor.has(KAART) and voor.has(STROOK) and voor.has("decor " + KAST) and voor.has("po_vak0"),
		"het beeld kent de kaart, de strook, de kast en de bordjes (%s)" % str(voor.keys()))
	for i in 3:
		var wat := "misser %d" % (i + 1)
		_kies((int(br["vak"]) + 1 + i) % 4)
		waar(is_sip(gast), "%s: de postbode is teleurgesteld" % wat)
		waar(mis_wolk(KAART), "%s: met 🔄 Nog een keer" % wat)
		await _wacht_mispauze()
		niets_erbij(voor, beeld(SPEL), wat)
		gelijk(int(_stand().get("i", -1)), 0, "%s: dezelfde brief" % wat)
		gelijk(_kaart_tekst("Kolom/Regel"), regel, "%s: dezelfde zin" % wat)
		gelijk(str(_strook()), str(keuzes), "%s: dezelfde vier vakjes" % wat)
	gelijk(int(_stand().get("missers", 0)), 3, "drie missers geteld, voor het adaptieve signaal")
	_kies(int(br["vak"]))
	gelijk(int(_stand().get("i", -1)), 1, "het goede vakje neemt de brief gewoon aan")
	_af()

## Nobody has a bed yet: the post is still there and the child sorts it alone —
## no animal walks, a miss shows its bubble at the card, and the turn ends the
## same way.
func test_zonder_postbode() -> void:
	_op()
	_wereld(2, -1, 2, 0)
	waar(Games.start(SPEL), "het spel start")
	gelijk(str(_stand().get("gast", "x")), "", "geen postbode")
	gelijk(Games.speler(), "", "en niemand op de spelbalk")
	waar(_knoop(KAART) != null, "de vraag staat er meteen")
	var br := _brief()
	_kies(_fout_vak(int(br["vak"])))
	waar(mis_wolk(KAART), "de misser wordt gezien: 🔄 Nog een keer bij de kaart")
	await _wacht_mispauze()
	await _sorteer_alles()
	gelijk(_stand().get("stap", ""), "af", "gesorteerd, ook alleen")
	_af()

## The postbode never comes (W5e): the child sorts the whole pile while he is
## still on his way from upstairs — nothing waits for him, a miss shows its
## bubble at the card and does not stop him two rooms away, a reload brings
## the same letter back at once — and the turn ends exactly as it does with
## him: the star, the adaptive signal, and the game closes itself.  He is not
## made to cheer in a room nobody looks at.
func test_de_postbode_komt_nooit_aan() -> void:
	_op()
	_boven(_wereld(4, 4))
	var sterren := int(State.s["sterren"])
	var signaal := (State.s["signaal"] as Array).size()
	Ui.zet_rust_modus(false)
	waar(Games.start(SPEL), "het spel start")
	var o := Beurt.maak(4, 4, 2, 0)
	var gast := str(_stand().get("gast", ""))
	var d = World.dier(gast)
	waar(d != null and d.kamer != KAMER and str(d.reis_doel) == KAMER, "de postbode komt van boven")
	waar(_knoop(KAART) != null, "de vraag staat er meteen")
	var br := _brief()
	_kies(_fout_vak(int(br["vak"])))
	waar(mis_wolk(KAART), "een misser: 🔄 Nog een keer bij de kaart")
	waar(not is_sip(gast), "het dier verderop wordt niet stilgezet")
	waar(d != null and str(d.reis_doel) == KAMER, "hij loopt gewoon door")
	await _wacht_mispauze()
	_kies(int(br["vak"]))
	await _wacht_brief()
	gelijk(int(_stand().get("i", -1)), 1, "de eerste brief ligt in zijn vakje")
	# a reload while he walks: the same letter at once, the same postbode, who
	# keeps walking (he is not sent off again from where he is)
	Games.stop()
	waar(Games.start(SPEL), "opnieuw gestart")
	gelijk(int(_stand().get("i", -1)), 1, "verder bij de tweede brief")
	gelijk(_kaart_tekst("Kolom/Rij/Som"), str(o["brieven"][1]["tekst"]), "die meteen op de kaart staat")
	gelijk(str(_stand().get("gast", "")), gast, "dezelfde postbode")
	waar(d != null and d.kamer != KAMER and str(d.reis_doel) == KAMER, "die nog steeds onderweg is")
	await _sorteer_alles()
	gelijk(_stand().get("stap", ""), "af", "alle post is gesorteerd, zonder hem")
	waar(d != null and d.kamer != KAMER, "terwijl hij nog onderweg is (%s)" % (str(d.kamer) if d != null else "-"))
	gelijk(int(State.s["sterren"]), sterren + 1, "één ster voor het meedoen")
	gelijk((State.s["signaal"] as Array).size(), signaal + 1, "het adaptieve signaal kreeg één beurt")
	gelijk(int((State.s["signaal"] as Array).back()["g"]), 0, "met een misser: niet in één keer goed")
	waar(d != null and str(d.staat) != "blij", "geen gejuich in een kamer waar niemand kijkt")
	await _wacht(Spel.AF_S + 0.3)
	gelijk(Games.actief(), "", "het spel sluit zichzelf")
	_af()

## The postbode leaves the hotel on his way (W5e): the post stays and the
## child sorts on alone — nobody on the game bar, a miss shows its bubble at
## the card, and the turn ends.
func test_de_postbode_vertrekt_onderweg() -> void:
	_op()
	_boven(_wereld(4, 4))
	Ui.zet_rust_modus(false)
	waar(Games.start(SPEL), "het spel start")
	var gast := str(_stand().get("gast", ""))
	waar(not gast.is_empty(), "er is een postbode")
	# he checks out: gone from the guest book and from the world
	State.s["gasten"] = (State.s["gasten"] as Array).filter(
		func(g) -> bool: return str(g.get("id", "")) != gast)
	World.weg(gast)
	await _wacht(Spel.KOM_TIK * 2.0 + 0.1)
	gelijk(str(_stand().get("gast", "x")), "", "zonder postbode verder")
	gelijk(Games.speler(), "", "niemand op de spelbalk")
	gelijk(int(_stand().get("i", -1)), 0, "dezelfde brief")
	waar(_knoop(KAART) != null, "de vraag blijft staan")
	_kies(_fout_vak(int(_brief()["vak"])))
	waar(mis_wolk(KAART), "de misser wordt gezien bij de kaart")
	await _wacht_mispauze()
	await _sorteer_alles()
	gelijk(_stand().get("stap", ""), "af", "gesorteerd, ook alleen")
	_af()
	# the world back in step with the guest book for whatever runs next
	World.sync(State.s["gasten"])

## The nearest guest with a bed carries the post (W5e): one in the postkamer
## itself first, then the kas next door, before anyone upstairs — so his walk
## is short.  Equally near ones take turns with the day, as before.
func test_de_dichtstbijzijnde_gast_brengt_de_post() -> void:
	_op()
	var gasten := _wereld(4, 4)
	_boven(gasten)
	var ids: Array[String] = []
	for g in gasten:
		ids.append(str(g["id"]))
	waar(Spel.deuren_tot_kar(ids[0]) >= 4.0, "van boven is het ver (%.0f deuren)" % Spel.deuren_tot_kar(ids[0]))
	World.reis(ids[2], "kas")
	gelijk(Spel.deuren_tot_kar(ids[2]), 1.0, "uit de kas is het één deur")
	waar(Games.start(SPEL), "het spel start")
	gelijk(str(_stand().get("gast", "")), ids[2], "de gast in de kas brengt de post")
	Games.stop()
	# a new hotel state: one in the kas, one in the postkamer itself
	_boven(_wereld(4, 4))
	World.reis(ids[1], "kas")
	World.reis(ids[3], KAMER)
	gelijk(Spel.deuren_tot_kar(ids[3]), 0.0, "in de postkamer: geen deur")
	waar(Games.start(SPEL), "het spel start opnieuw")
	gelijk(str(_stand().get("gast", "")), ids[3], "de gast die er al is brengt de post")
	_af()

## A reload in the middle of a turn picks up where the child was: the second
## letter is still the second letter, the first still lies in its hole.
func test_herladen_hervat_de_beurt() -> void:
	_op()
	_wereld(4, 4)
	waar(Games.start(SPEL), "het spel start")
	var o := Beurt.maak(4, 4, 2, 0)
	var br: Dictionary = o["brieven"][0]
	_kies(int(br["vak"]))
	await _wacht_brief()
	Games.stop()
	gelijk(int(_stand().get("i", -1)), 1, "de stand is bewaard")
	waar(Hits.spot(KAART) == null and World.decor_plek(KAST, KAMER).is_empty(),
		"na stop staat er niets meer van de beurt")
	waar(Games.start(SPEL), "opnieuw gestart")
	gelijk(int(_stand().get("i", -1)), 1, "verder bij de tweede brief")
	gelijk(_kaart_tekst("Kolom/Rij/Som"), str(o["brieven"][1]["tekst"]), "met dezelfde brief op de kaart")
	gelijk(int(World.decor_plek(KAST, KAMER)["params"]["vol"][int(br["vak"])]), 1,
		"de eerste brief ligt nog in zijn vakje")
	gelijk(int(World.decor_plek(KAR, KAMER)["params"]["brieven"]), 3, "en de kar heeft er nog drie")
	# the JSON way back: floats in the save are read as numbers
	var st: Dictionary = State.spel_data(SPEL)["stand"]
	st["i"] = 1.0
	st["missers"] = 0.0
	st["ronde"] = 0.0
	Games.stop()
	waar(Games.start(SPEL), "na een JSON-ronde")
	gelijk(typeof(_stand()["i"]), TYPE_INT, "i is weer een geheel getal")
	gelijk(_kaart_tekst("Kolom/Rij/Som"), str(o["brieven"][1]["tekst"]), "nog steeds de tweede brief")
	# another day is another pile
	Games.stop()
	State.s["dag"] = 3
	waar(Games.start(SPEL), "de volgende dag")
	gelijk(int(_stand().get("i", -1)), 0, "begint bij de eerste brief van een nieuwe stapel")
	gelijk(str(_opzet()["brieven"]), str(Beurt.maak(4, 4, 3, 0)["brieven"]), "de post van dag 3")
	_af()

## A finished pile is followed by a fresh one on the same day — and the star
## is paid once a day (`ctx.taak_klaar`, §3.8 N1).
func test_na_de_stapel_een_nieuwe_stapel() -> void:
	_op()
	_wereld(4, 4)
	var sterren := int(State.s["sterren"])
	waar(Games.start(SPEL), "het spel start")
	await _sorteer_alles()
	gelijk(_stand().get("stap", ""), "af", "de eerste stapel is gesorteerd")
	Games.stop()
	waar(Games.start(SPEL), "nog een keer")
	gelijk(int(_stand().get("ronde", -1)), 1, "de tweede ronde")
	gelijk(str(_opzet()["brieven"]), str(Beurt.maak(4, 4, 2, 1)["brieven"]), "met een nieuwe stapel")
	await _sorteer_alles()
	gelijk(int(State.s["sterren"]), sterren + 1, "maar één ster per dag")
	_af()

## "Een methode om te wisselen met welk dier je de spellen speelt" (owner,
## 2026-09-23, world.md §5.8): every guest with a bed may carry the post, the
## animal on the game bar hands the cart to the next one in a fresh turn —
## nothing is taken away — and the next start keeps the animal the child chose.
func test_het_kind_kiest_de_postbode() -> void:
	_op()
	var gasten := _wereld(4, 4)
	var ids: Array[String] = []
	for g in gasten:
		ids.append(str(g["id"]))
	waar(Games.start(SPEL), "het spel start")
	gelijk(str(Games.spelers()), str(ids), "wie de post mag sorteren: iedereen met een bed, op volgorde")
	var br := _brief()
	_kies(int(br["vak"]))
	await _wacht_brief()
	var sterren := int(State.s["sterren"])
	var volgende := Games.volgende_speler()
	waar(not volgende.is_empty() and volgende != Games.speler(), "er is een ander dier")
	waar(Games.wissel_speler(), "het dier op de balk geeft de kar door")
	gelijk(Games.actief(), SPEL, "het sorteren gaat door")
	gelijk(Games.speler(), volgende, "met het volgende dier")
	gelijk(str(_stand().get("gast", "")), volgende, "die de kar overneemt")
	# wave 2, R2: the pile and its progress stay — the switch used to start the
	# same pile again at letter 0
	gelijk(int(_stand().get("i", -1)), 1, "en verder gaat bij de tweede brief")
	gelijk(int(State.s["sterren"]), sterren, "er ging geen ster af")
	Games.stop()
	waar(Games.start(SPEL), "het spel start opnieuw")
	gelijk(Games.speler(), volgende, "met het gekozen dier")
	_af()

# ------------------------------------------------------------- het rustspul

## The shelf, the counter and the cart stand in the postkamer while nobody
## plays; the entry hangs ON the cart; a turn takes them away and puts its own
## there; after the turn they are back.  The floor under them is kept free.
func test_de_rustende_postkamer() -> void:
	_op()
	_wereld(3, -1)
	Games.hersteek()
	for stuk in Spel.rust():
		var id := str(stuk["id"])
		var p := World.decor_plek(id, KAMER)
		waar(not p.is_empty(), "%s staat in de postkamer als er niet gespeeld wordt" % id)
		if not p.is_empty():
			gelijk(float(p.get("x", 0)), float(stuk["x"]), "%s op zijn plek" % id)
	gelijk(int(World.decor_plek(RUST_KAR, KAMER)["params"]["brieven"]), Spel.RUST_BRIEVEN,
		"op de kar wacht de post van vandaag")
	waar(Games.start(SPEL), "het spel start")
	for id in [RUST_KAST, RUST_KAR, RUST_BALIE]:
		waar(World.decor_plek(id, KAMER).is_empty(), "%s gaat weg" % id)
	for id in [KAST, KAR, BALIE]:
		waar(not World.decor_plek(id, KAMER).is_empty(), "het eigen %s staat er" % id)
	Games.stop()
	for id in [KAST, KAR, BALIE]:
		waar(World.decor_plek(id, KAMER).is_empty(), "na het spel is %s weg" % id)
	for id in [RUST_KAST, RUST_KAR, RUST_BALIE]:
		waar(not World.decor_plek(id, KAMER).is_empty(), "en staat %s er weer" % id)
	# locked (no guests): no props, no entry — nothing that cannot be played
	State.s["gasten"] = []
	State.herbereken()
	Games.hersteek()
	waar(World.decor_plek(RUST_KAR, KAMER).is_empty(), "zonder gasten geen post")
	# the floor under the props is kept free: no wander place, no bought plant
	var r := Rooms.get_kamer(KAMER)
	for p in r.plekken:
		waar(not (p[0] >= 30 and p[0] <= 52 and p[1] >= 37 and p[1] <= 51),
			"geen loopplek op de postkar (%s)" % str(p))
		waar(not (p[0] >= 8 and p[0] <= 74 and p[1] <= 12), "geen loopplek in de vakkenkast (%s)" % str(p))
		waar(not (p[0] <= 15 and p[1] >= 19 and p[1] <= 49), "geen loopplek in de balie (%s)" % str(p))
	for xz in [Vector2(Spel.KAR_X, Spel.KAR_Z), Vector2(41, 6), Vector2(6, 34)]:
		waar(not Rooms.vrij_vak(KAMER, xz.x, xz.y), "er kan geen meubel op %s" % str(xz))
	_af()

## The entry button in the real hotel: it hangs on the resting cart, covers
## nothing else and is a full tap target; a tap starts the game.
func test_de_ingang_hangt_aan_de_kar() -> void:
	_op()
	_wereld(3, -1)
	World.naar(KAMER)
	World.meet(Rect2(Vector2.ZERO, Vector2(1000, 648)))
	Games.hersteek()
	Hits.plaats()
	var s := Hits.spot("spel_post")
	waar(s != null, "de ingang staat er")
	if s != null:
		var dbg: Dictionary = Hits.debug()["spel_post"]
		var r: Rect2 = dbg["rect"]
		waar(r.size.x >= 48.0 and r.size.y >= 48.0, "en is een tikdoel (%s)" % str(r.size))
		waar(not bool(dbg["krap"]), "met een echte plek")
		waar(Hits.dekking("spel_post") <= 0.0 or str(dbg["op"]) == "aan",
			"hij hangt aan de kar (%s, %.1f %%)" % [dbg["op"], Hits.dekking("spel_post")])
		(s.knoop as BaseButton).pressed.emit()
		gelijk(Games.actief(), SPEL, "een tik start het sorteren")
	_af()

# ------------------------------------------------------- op vier schermen

## The real shell on the four ticket screens: every element of the game is
## inside the frame and found a real place, the four plates stand over their
## own holes in the shelf's order without touching each other, the card with
## its strip docks in the maths bar where a frame is tall enough, and a miss
## shows no help.
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
		_keur(kader.size, "%s vraag" % str(maat))
		# the big plates stand over their holes on a tablet and a desktop; on a
		# phone, both ways round, the small ones do (W5e: the portrait phone
		# showed no plates at all, only the strip had the numbers)
		var vorm: String = Spel.VORM_GROOT if maat.x >= 700 and maat.y >= 700 else Spel.VORM_KLEIN
		_platen_op_volgorde("%s" % str(maat), vorm)
		if maat.y >= 400:
			gelijk(Ui.balk_kaart(), KAART, "%s: de vraag staat in de rekenbalk" % str(maat))
		# every hole button: the long words, or on a narrow frame the pictogram
		# over the numbers — always pictogram AND numbers
		var vakken: Array = _opzet().get("vakjes", [])
		var teksten := _strook_teksten()
		gelijk(teksten.size(), 4, "%s: vier vakjes op de strook" % str(maat))
		for j in mini(teksten.size(), vakken.size()):
			var t := teksten[j]
			waar(t == Beurt.knop(vakken[j]) or t == Beurt.knop_kort(vakken[j]),
				"%s: knop %d is het vakje met pictogram en getallen (%s)" % [str(maat), j, t.replace("\n", "|")])
		var br := _brief()
		_kies(_fout_vak(int(br["vak"])))
		for _f in 3:
			await boom.process_frame
		_keur(kader.size, "%s misser" % str(maat))
		_platen_op_volgorde("%s misser" % str(maat), vorm)
		gelijk(_kaart_tekst("Kolom/Hulp"), "", "%s: geen hulpregel op de kaart" % str(maat))
		await _wacht_mispauze()
		_kies(int(br["vak"]))
		await _wacht_brief()
		for _f in 3:
			await boom.process_frame
		_keur(kader.size, "%s tweede brief" % str(maat))
		_platen_op_volgorde("%s tweede brief" % str(maat), vorm)
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

## Every spot of the game: inside the frame, never `krap`, a tap target, and
## no button on an object (a card and a number may lie over the world).
func _keur(kader: Vector2, wat: String) -> void:
	var dbg := Hits.debug()
	var vakken: Array[Rect2] = []
	for id in dbg.keys():
		var v: Rect2 = dbg[id]["vlak"]
		if v.size.x > 0.0 and v.size.y > 0.0:
			vakken.append(v)
	var eigen := 0
	for id in dbg.keys():
		var spot := Hits.spot(id)
		if spot == null or spot.door != SPEL:
			continue
		eigen += 1
		var d: Dictionary = dbg[id]
		var r: Rect2 = d["rect"]
		# `Ui`'s own miss bubble on the landscape phone may touch the strip for
		# the length of the pause (the same exception as the oogst test)
		var s5_laag := str(id).begins_with(Ui.MIS_WOLK) and kader.y < 300.0
		waar(not bool(d["krap"]) or s5_laag, "%s: %s vond een echte plek" % [wat, id])
		waar(r.position.x >= -0.01 and r.position.y >= -0.01
			and r.end.x <= kader.x + 0.01 and r.end.y <= kader.y + 0.01,
			"%s: %s staat binnen het kader (%s)" % [wat, id, str(r)])
		if spot.kind == "tag" or int(d["laag"]) == Hits.Laag.VAST:
			continue
		waar(Hits.dekking(id) <= 0.0 or str(d["op"]) == "aan",
			"%s: %s dekt zijn voorwerp niet (%s, %.1f %%)" % [wat, id, str(d["op"]), Hits.dekking(id)])
		waar(r.size.x >= 44.0 and r.size.y >= 44.0, "%s: %s is een tikdoel" % [wat, id])
		for v in vakken:
			if v == d["vlak"]:
				continue
			var snij := r.intersection(v)
			waar(maxf(0.0, snij.size.x) * maxf(0.0, snij.size.y) <= 0.15 * v.get_area() + 0.5,
				"%s: %s dekt geen ander voorwerp af" % [wat, id])
	# the card, its strip and the address on the cart at least; the plates come
	# on top of that where the frame has room for them
	waar(eigen >= 3, "%s: het spel staat op het scherm (%d)" % [wat, eigen])

## The four plates of set `vorm` (the big ones on a tablet, the small ones on a
## phone; never both sets, never a part of one): each right over its own hole
## (its middle on the hole's projected middle, its foot on the hole's board),
## left to right in the shelf's order, never on top of each other, never on
## the card or its strip, never moved off its hole by the band grid — and
## readable: the hole's own words, at no less than the hotel's smallest text.
func _platen_op_volgorde(wat: String, vorm: String) -> void:
	var dbg := Hits.debug()
	var groot := 0
	var klein := 0
	for j in 4:
		groot += 1 if dbg.has(Spel.VAK_TAG % j) else 0
		klein += 1 if dbg.has(Spel.VAK_KLEIN % j) else 0
	waar(groot == 0 or klein == 0, "%s: nooit beide soorten bordjes (%d groot, %d klein)" % [wat, groot, klein])
	var spel := _spel()
	if spel != null:
		gelijk(spel.plaat_vorm(), vorm, "%s: welke bordjes passen" % wat)
	var sjabloon: String = Spel.VAK_KLEIN if vorm == Spel.VORM_KLEIN else Spel.VAK_TAG
	var er := klein if vorm == Spel.VORM_KLEIN else groot
	gelijk(er, 4, "%s: de vier bordjes (%s) staan boven de vakjes" % [wat, vorm])
	if er == 0:
		return
	var vakken: Array = _opzet().get("vakjes", [])
	var vorige := Rect2()
	for j in 4:
		var id := sjabloon % j
		if dbg.has(id):
			var r0: Rect2 = dbg[id]["rect"]
			for ander in [KAART, STROOK]:
				if dbg.has(ander):
					var snij0 := r0.intersection(dbg[ander]["rect"])
					waar(snij0.size.x <= 0.0 or snij0.size.y <= 0.0,
						"%s: bordje %d ligt niet op %s" % [wat, j, ander])
			var t := _knoop(id) as Label
			waar(t != null and t.visible, "%s: bordje %d is te zien" % [wat, j])
			if t != null and j < vakken.size():
				var woorden: String = Beurt.kort(vakken[j]) if vorm == Spel.VORM_KLEIN else Beurt.plaat(vakken[j])
				gelijk(t.text, woorden, "%s: bordje %d zegt wat zijn knop zegt" % [wat, j])
				waar(t.get_theme_font_size("font_size") >= UiThema.VLOER,
					"%s: bordje %d is leesbaar (%d px)" % [wat, j, t.get_theme_font_size("font_size")])
		waar(dbg.has(id), "%s: bordje %d staat er" % [wat, j])
		if not dbg.has(id):
			continue
		var r: Rect2 = dbg[id]["rect"]
		var p := Spel.vak_plek(j)
		var mik := World.mik_punt(p.x, p.y, 0.0)
		waar(absf(r.get_center().x - mik.x) <= 2.0,
			"%s: bordje %d hangt recht boven zijn vakje (%.0f vs %.0f)" % [wat, j, r.get_center().x, mik.x])
		if spel != null:
			var gat: Rect2 = spel.vak_vlak(j)
			waar(r.end.y <= gat.position.y + gat.size.y * 0.1 + 1.0 and r.end.y >= gat.position.y - 1.0,
				"%s: bordje %d staat op het bord van zijn vakje (%.0f, gat %.0f)" % [wat, j, r.end.y, gat.position.y])
		if j > 0:
			waar(r.get_center().x > vorige.get_center().x, "%s: bordje %d staat rechts van %d" % [wat, j, j - 1])
			var snij := r.intersection(vorige)
			waar(snij.size.x <= 0.0 or snij.size.y <= 0.0, "%s: bordje %d raakt bordje %d niet" % [wat, j, j - 1])
		vorige = r

# ------------------------------------------- golf 2: rekenen eerst (R1, R2)

var _teller := {"reken": 0, "spel": 0}

## Every tap the test performs, labelled the way R1 counts it: an answer on a
## maths strip is "reken", everything else "spel".
func _tel(soort: String) -> void:
	_teller[soort] = int(_teller.get(soort, 0)) + 1

## R1 (wave 2, owner: "rekenen moet minstens 50% van de interactie zijn"): in a
## whole turn — from the start, the entry tap not counted — the maths taps
## outnumber everything else by at least one, in every group and for a small
## and a large hotel.  Every tap of the post is a hole on the choice strip of
## a maths card (`reken: true`), one per letter (a miss is a maths tap too).
func test_rekenaandeel() -> void:
	for geval in [[1, 3, true], [3, 3, false], [4, 4, false], [6, 4, true], [7, 5, false],
			[8, 5, false]]:
		var n: int = geval[0]
		var band: int = geval[1]
		var mis: bool = geval[2]
		var wat := "groep %d, %d gasten" % [band, n]
		_teller = {"reken": 0, "spel": 0}
		_op()
		_wereld(n, band, 2)
		waar(Games.start(SPEL), "%s: het spel start" % wat)
		if mis:
			var br := _brief()
			_tel("reken")
			_kies(_fout_vak(int(br["vak"])))
			gelijk(int(_stand().get("i", -1)), 0, "%s: een misser schuift niets op" % wat)
			await _wacht_mispauze()
		var brieven := 0
		while str(_stand().get("stap", "")) == "sorteer" and brieven < 10:
			var br := _brief()
			if br.is_empty():
				break
			_tel("reken")
			_kies(int(br["vak"]))
			brieven += 1
			await _wacht_brief()
		gelijk(str(_stand().get("stap", "")), "af", "%s: de stapel is gesorteerd" % wat)
		var reken := int(_teller["reken"])
		var spel := int(_teller["spel"])
		waar(reken >= spel + 1, "%s: R1 reken %d >= spel %d + 1" % [wat, reken, spel])
		_af()

## R2 (wave 2): a letter that was put in a wrong hole stays on top of the pile
## UNCHANGED after any exit — a new day, another band, another hotel size, the
## animal on the game bar — with the letters already sorted still sorted; only
## after the pile is done is the next one new.
func test_een_gemiste_brief_komt_onveranderd_terug() -> void:
	_op()
	var gasten := _wereld(5, 4, 2)
	waar(Games.start(SPEL), "het spel start")
	var o := _opzet().duplicate(true)
	var eerste := _brief()
	_kies(int(eerste["vak"]))
	await _wacht_brief()
	var br := _brief()
	var som := _kaart_tekst("Kolom/Rij/Som")
	var keuzes := _strook_teksten()
	var bode := str(_stand().get("gast", ""))
	var ander := ""
	for i in 4:
		if str(gasten[i]["id"]) != bode:
			ander = str(gasten[i]["id"])
			break
	_kies(_fout_vak(int(br["vak"])))
	gelijk(int(_stand().get("pog", 0)), 1, "een misser op de tweede brief")
	await _wacht_mispauze()
	for stap in ["een nieuwe dag", "een andere band", "een gast minder", "het dier op de balk"]:
		Games.stop()
		match stap:
			"een nieuwe dag":
				State.s["dag"] = 3
				World.zet_dag(3)
			"een andere band":
				State.s["kunnen"] = 2
				gelijk(State.band(), 3, "nu groep 3")
			"een gast minder":
				(State.s["gasten"] as Array).pop_back()
				World.sync(State.s["gasten"])
			_:
				State.s["speler"] = ander
		waar(Games.start(SPEL), "%s: het spel start" % stap)
		gelijk(int(_stand().get("i", -1)), 1, "%s: de tweede brief ligt nog bovenop" % stap)
		gelijk(int(_stand().get("pog", 0)), 1, "%s: met zijn misser" % stap)
		gelijk(str(_opzet().get("brieven", [])), str(o["brieven"]), "%s: dezelfde stapel" % stap)
		gelijk(_kaart_tekst("Kolom/Rij/Som"), som, "%s: dezelfde brief" % stap)
		gelijk(str(_strook_teksten()), str(keuzes), "%s: dezelfde vier vakjes" % stap)
	gelijk(str(_stand().get("gast", "")), ander, "het gekozen dier sorteert verder")
	await _sorteer_alles()
	gelijk(str(_stand().get("stap", "")), "af", "de stapel is af")
	Games.stop()
	State.s.erase("speler")
	waar(Games.start(SPEL), "na de stapel")
	gelijk(int(_stand().get("i", -1)), 0, "een nieuwe stapel")
	gelijk(int(_stand().get("dag", -1)), 3, "van vandaag")
	_af()
