extends Proef
## `State`: the save document of architecture.md §9 — every field round-trips,
## a corrupt file always ends at the start screen, the guest pool and its
## repairs behave, and the band/number factories agree with world.md §3.9.

func _voor() -> void:
	State.nieuw_spel()
	State.start_gekozen()

func _wis_bestand() -> void:
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("dierenhotel.json")
		dir.remove("dierenhotel.json.tmp")

# ------------------------------------------------------------------ opslag

## Every field of the table in architecture.md §9, with a non-default value.
func test_alle_velden_overleven_een_rondrit() -> void:
	_voor()
	var gast := State.mk_gast("boef", "Boef", "hond", "puppy", 2, "Wandeling", 30)
	gast["kamer"] = "kamer1"
	gast["bed"] = "bed1"
	gast["waar"] = "tuin"
	gast["nachten"] = 3
	gast["geslapen"] = 2
	gast["prijs"] = 5
	gast["betaald"] = 20
	gast["behoefte"] = "zwemmen"
	gast["gegeten"] = true
	gast["blij"] = false
	gast["accessoires"] = ["hoedje"]
	var s: Dictionary = State.s
	s["dag"] = 7
	s["ronde"] = "avond"
	s["munten"] = 12
	s["sterren"] = 9
	s["kunnen"] = 5
	s["signaal"] = [{"g": 1, "t": 1200}, {"g": 0, "t": 8000}]
	s["gasten"] = [gast]
	s["famIdx"] = 3
	s["meubels"] = [{"id": "m1", "kamer": "kamer1", "type": "bed", "x": 10, "z": 4,
		"rot": 1, "soort": "hout"}]
	s["meubelNr"] = 4
	s["taken"] = [{"id": "bel", "spel": "", "icoon": "🔔", "tekst": "Bel een gast",
		"kamer": "receptie", "actie": "bel", "prio": 0, "klaar": true}]
	s["brieven"] = [{"titel": "Bedankje van familie Bakker 💌", "tekst": "dank", "dag": 5}]
	s["scoops"] = 13
	s["levering"] = 2
	s["snoeppot"] = 6
	s["kar"] = {"vak": 2}
	s["spel"] = {"wekker": {"stap": 2, "missers": 1}}
	s["gezien"] = {"uitleg_bed": 1}
	s["kamerNu"] = "tuin"
	s["uitcheck"] = ["boef"]
	s["checkin"] = null
	s["rekening"] = {"gastId": "boef", "fam": "Bakker", "nachten": 3, "prijs": 5,
		"totaal": 15, "stap": 2, "pogingen": 1, "telPog": 0, "wisselPog": 0,
		"hand": [10, 5, 2, 2, 1], "bank": [10], "t0": 0, "tw": 0}
	s["geluid"] = false
	State.herbereken()
	var voor := _blob(State.s)
	waar(State.bewaar(), "bewaar()")

	State.s = State.standaard()
	waar(State.lees(), "lees()")
	# the repair adds nothing when the document was already complete
	gelijk(_blob(State.s), voor, "elk veld komt ongewijzigd terug")
	gelijk(typeof(State.s["dag"]), TYPE_INT, "dag is weer een geheel getal")
	gelijk(typeof(State.s["gasten"][0]["nachten"]), TYPE_INT, "gast.nachten int")
	gelijk(typeof(State.s["rekening"]["hand"][0]), TYPE_INT, "munt in de buidel int")
	gelijk(typeof(State.s["meubels"][0]["x"]), TYPE_INT, "meubel.x int")
	gelijk(typeof(State.s["taken"][0]["prio"]), TYPE_INT, "taak.prio int")
	gelijk(State.s["brieven"][0]["dag"], 5, "brief.dag")
	gelijk(State.s["taken"][0]["klaar"], true, "een afgevinkt taakje overleeft")
	gelijk(State.s["geluid"], false, "geluid uit")
	# the three free-form drawers keep their VALUES; their number types belong
	# to the game that wrote them (`int(ctx.data()[...])`)
	gelijk(int(State.s["spel"]["wekker"]["stap"]), 2, "de laatjes van de spellen")
	gelijk(int(State.s["kar"]["vak"]), 2, "de voerkar")
	waar(State.s["gezien"].has("uitleg_bed"), "wat al is uitgelegd")

## Everything except the three drawers a minigame owns itself.
func _blob(s: Dictionary) -> String:
	var kopie := s.duplicate(true)
	for k in ["spel", "gezien", "kar"]:
		kopie.erase(k)
	return JSON.stringify(kopie)

## A save written in the middle of a bill resumes with the counted coins
## (architecture.md §13, Q-X1-4).
func test_rekening_overleeft_een_herlaad() -> void:
	_voor()
	# the guest the bill belongs to must still be in the hotel: a bill for
	# somebody who already left is dropped by the repair
	State.s["gasten"] = [State.mk_gast("muis", "Muis", "poes", "poes", 1, "Spelen", 15)]
	State.s["rekening"] = {"gastId": "muis", "fam": "Jansen", "nachten": 2,
		"prijs": 5, "totaal": 10, "stap": 2, "pogingen": 1, "telPog": 2,
		"wisselPog": 0, "hand": [2, 1], "bank": [5, 2], "t0": 0, "tw": 0}
	waar(State.bewaar(), "bewaar met rekening")
	State.s = State.standaard()
	waar(State.lees(), "lees met rekening")
	gelijk(State.s["rekening"]["stap"], 2, "de rekening staat weer op stap 2")
	gelijk(State.s["rekening"]["bank"], [5, 2], "de getelde munten liggen er nog")
	gelijk(State.s["rekening"]["telPog"], 2, "de pogingen tellen door")

## Four kinds of broken file, four times the start screen and no crash.
func test_kapotte_opslag_geeft_het_startscherm() -> void:
	_voor()
	State.s["dag"] = 5
	State.bewaar()
	var gevallen := {
		"geen json": "{niet: json",
		"lege tekst": "",
		"verkeerde versie": '{"v": 99, "s": {"dag": 4}}',
		"geen s": '{"v": 1}',
		"s is geen object": '{"v": 1, "s": 7}',
		"gasten zijn geen lijst": '{"v": 1, "s": {"gasten": 3}}',
		"gast zonder id": '{"v": 1, "s": {"gasten": [{"naam": "Zoek"}]}}',
		# the reviewer's file: a valid envelope, a rekening that IS a
		# Dictionary, and two coin piles that are not lists
		"buidel is geen lijst": '{"v": 1, "s": {"rekening": {"gastId": "boef", "fam": "Bakker", "hand": "kapot", "bank": 3}}}',
		"munt is geen getal": '{"v": 1, "s": {"rekening": {"gastId": "boef", "fam": "Bakker", "hand": [5, "twee"], "bank": []}}}',
		"rekening zonder gast-id": '{"v": 1, "s": {"rekening": {"gastId": 7, "fam": "Bakker", "hand": [], "bank": []}}}',
		"dag is een woord": '{"v": 1, "s": {"dag": "morgen"}}',
		"onbekende ronde": '{"v": 1, "s": {"ronde": "middag"}}',
		"signaal met tekst": '{"v": 1, "s": {"signaal": [{"g": "ja", "t": 5}]}}',
		"speellaatje is geen object": '{"v": 1, "s": {"spel": {"wekker": 5}}}',
		"checkin zonder gast-id": '{"v": 1, "s": {"checkin": {"gastId": 7, "stap": 1}}}',
		"gast met een getal als naam": '{"v": 1, "s": {"gasten": [{"id": "boef", "naam": 7}]}}',
		"uitcheck met een getal": '{"v": 1, "s": {"uitcheck": [7]}}',
		"taak zonder id": '{"v": 1, "s": {"taken": [{"tekst": "Bel een gast"}]}}',
	}
	for wat in gevallen.keys():
		var f := FileAccess.open("user://dierenhotel.json", FileAccess.WRITE)
		f.store_string(gevallen[wat])
		f.close()
		State.s = State.standaard()
		State.s["dag"] = 42                     # a running game must stay whole
		waar(not State.lees(), "%s -> startscherm" % wat)
		gelijk(State.s["dag"], 42, "%s: niets half geladen" % wat)

## Nothing is written before the start screen has been answered.
func test_niets_bewaren_voor_het_startscherm() -> void:
	_wis_bestand()
	State.nieuw_spel()
	waar(not State.bewaar(), "bewaar() doet niets voor start_gekozen()")
	waar(not State.lees(), "en er staat dus niets op de tablet")

# ----------------------------------------------------------------- sterren

## §3.8 `N1`: a game pays one star a day.  Playing it again the same day still
## ticks its card, it just does not pay twice — and tomorrow it pays again.
func test_een_spel_geeft_een_ster_per_dag() -> void:
	_voor()
	var ctx := SpelCtx.new("zwemles", {"naam": "Zwemles", "kamer": "zwembad"})
	waar(not State.ster_gehad("zwemles"), "vandaag nog geen ster gehad")
	ctx.taak_klaar("zwemles")
	gelijk(int(State.s["sterren"]), 1, "meedoen levert één ster op")
	waar(State.ster_gehad("zwemles"), "en vandaag staat gestempeld")
	ctx.taak_klaar("zwemles")
	gelijk(int(State.s["sterren"]), 1, "nog een keer spelen mag, maar betaalt niet")
	# every game keeps its own stamp
	var ander := SpelCtx.new("hinkel", {"naam": "Hinkel", "kamer": "tuin"})
	ander.taak_klaar("hinkel")
	gelijk(int(State.s["sterren"]), 2, "een ánder spel geeft wél zijn ster")
	State.s["dag"] = int(State.s["dag"]) + 1
	waar(not State.ster_gehad("zwemles"), "morgen telt de stempel van gisteren niet")
	ctx.taak_klaar("zwemles")
	gelijk(int(State.s["sterren"]), 3, "en morgen komt er weer één")
	_wis_bestand()

## `sterren: 0` vinkt het taakkaartje af zonder ster — en laat de dag vrij, zodat
## een volgende beurt die er wél om vraagt hem gewoon krijgt.
func test_sterren_nul_slaat_de_ster_over() -> void:
	_voor()
	var ctx := SpelCtx.new("voerkar", {"naam": "Voerkar", "kamer": "keuken"})
	ctx.taak_klaar("voer", {"sterren": 0})
	gelijk(int(State.s["sterren"]), 0, "nul sterren gevraagd, nul gekregen")
	waar(not State.ster_gehad("voerkar"), "en de dag is niet gestempeld")
	ctx.taak_klaar("voer", {"sterren": 1})
	gelijk(int(State.s["sterren"]), 1, "de beurt daarna geeft er wel één")
	_wis_bestand()

## De stempel woont in het al bestaande laatje `gezien`: het document blijft
## versie 1, en een opslag van vóór deze wijziging heeft er eenvoudig geen.
func test_de_opslag_overleeft_de_sterdag() -> void:
	_voor()
	State.s["dag"] = 3
	State.zet_ster("zwemles")
	gelijk(State.s["gezien"]["ster_zwemles"], 3, "de dag staat in `gezien`")
	waar(State.bewaar(), "bewaar()")
	State.s = State.standaard()
	waar(State.lees(), "lees()")
	gelijk(int(State.s["dag"]), 3, "dag 3 komt terug")
	waar(State.ster_gehad("zwemles"), "en de stempel overleeft de herlaad")
	waar(not State.ster_gehad("hinkel"), "hij geldt alleen voor dat ene spel")
	# the document on disk did not change shape: still v1, still the same drawer
	var f := FileAccess.open("user://dierenhotel.json", FileAccess.READ)
	var doc = JSON.parse_string(f.get_as_text())
	f.close()
	gelijk(int(doc["v"]), State.VERSIE, "de opslag is nog steeds v1")
	waar((doc["s"]["gezien"] as Dictionary).has("ster_zwemles"),
		"en de stempel ligt in het laatje `gezien`")
	# a save written before this change simply has no stamp
	f = FileAccess.open("user://dierenhotel.json", FileAccess.WRITE)
	f.store_string('{"v": 1, "s": {"dag": 3, "gezien": {"uitleg_bed": 1}}}')
	f.close()
	waar(State.lees(), "een oude opslag zonder stempel leest gewoon")
	waar(not State.ster_gehad("zwemles"), "en heeft vandaag nog geen ster gehad")
	_wis_bestand()

# ------------------------------------------------------------------ gasten

func test_gastenpool_en_wachtlijst() -> void:
	_voor()
	var pool := State.gasten_pool()
	gelijk(pool.size(), 9, "negen gasten in de pool")
	gelijk(pool[0]["id"], "boef", "eerste gast")
	gelijk(pool[0]["naam"], "Boef", "naam")
	gelijk(pool[6]["naam"], "Stampertje", "zevende gast heet Stampertje")
	gelijk(pool[4]["scoops"], 3, "Pip eet 3 scheppen")
	gelijk((State.s["wachtlijst"] as Array).size(), 9, "de wachtlijst is gevuld")
	var g := State.pak_gast()
	gelijk(g["id"], "boef", "de bel pakt ze op volgorde")
	gelijk((State.s["wachtlijst"] as Array).size(), 8, "eentje van de lijst af")

func test_lege_wachtlijst_wordt_bijgevuld() -> void:
	_voor()
	State.s["dag"] = 4
	State.s["wachtlijst"] = []
	var g := State.pak_gast()
	gelijk(g["id"], "boef_d4", "bijvullen zet _d<dag> achter de id")
	# a still-colliding id gets _2 behind it
	State.s["gasten"] = [g]
	State.s["wachtlijst"] = []
	var g2 := State.pak_gast()
	gelijk(g2["id"], "boef_d4_2", "een botsende id krijgt _2")

func test_dag_verbruik_en_bedden() -> void:
	_voor()
	State.s["gasten"] = [
		State.mk_gast("a", "A", "hond", "puppy", 2, "Wandeling", 30),
		State.mk_gast("b", "B", "poes", "poes", 1, "Spelen", 15),
	]
	gelijk(State.dag_verbruik(), 3, "samen 3 scheppen per dag")
	# the guest cap is the bedrooms (owner, 2026-09-24): every bed there is,
	# plus the beds the check-in may still put down, up to MAX_BEDDEN a room
	var bedden := State.alle_bedden()
	var cap := 0
	for k in State.slaapkamers():
		cap += Rooms.slots(k, "bed").size() + State.nieuwe_bedden(k)
	gelijk(State.max_gasten(), cap, "max_gasten telt de bedden en de vloer voor nieuwe")
	waar(State.max_gasten() > bedden.size(), "meer dan de bedden die er staan")
	waar(bedden.size() >= 2, "het hotel heeft bedden (%d)" % bedden.size())
	for b in bedden:
		waar(not str(b["kamer"]).is_empty(), "elk bed weet in welke kamer het staat")
		waar(not str(b["slot"]).is_empty(), "en hoe het heet")
	# an occupied bed is not free any more
	var eerste: Dictionary = bedden[0]
	gelijk(State.bed_vrij(), eerste, "het eerste bed is vrij")
	State.s["gasten"][0]["kamer"] = str(eerste["kamer"])
	State.s["gasten"][0]["bed"] = str(eerste["slot"])
	gelijk(State.gast_in_bed(str(eerste["kamer"]), str(eerste["slot"]))["id"], "a",
		"en daarna ligt A erin")
	waar(State.bed_vrij() != eerste, "bed_vrij() wijst het volgende aan")

## The bedrooms and the room in them (owner, 2026-09-24: the check-in chooses a
## ROOM and its beds are made for the guest): a room has room for one more
## animal while it has a free bed, or floor where the check-in may still put a
## new one — at most `MAX_BEDDEN` a room, and only on free floor.
func test_plek_in_de_slaapkamers() -> void:
	_voor()
	Rooms.herstel()
	gelijk(str(State.slaapkamers()), str(["kamer1", "kamer2"]), "de twee slaapkamers")
	gelijk(State.slapers_in("kamer1").size(), 0, "nog niemand in kamer 1")
	gelijk(State.vrije_bedden("kamer1").size(), 2, "twee vrije bedden")
	var nieuw := State.nieuwe_bedden("kamer1")
	waar(nieuw >= 1 and nieuw <= State.MAX_BEDDEN - 2, "en vloer voor nieuwe (%d)" % nieuw)
	gelijk(State.plek_in("kamer1"), 2 + nieuw, "dieren die erin passen")
	waar(State.plek_voor_gast(), "er mag een gast komen")
	gelijk(str(State.kamers_met_plek()), str(["kamer1", "kamer2"]), "in allebei")
	# the next new bed stands on free floor, far from the beds there are
	var p := State.bed_plek("kamer1")
	waar(not p.is_empty(), "er is een plek voor een nieuw bed")
	waar(Rooms.vrij_vak("kamer1", float(p["x"]), float(p["z"])), "op vrije vloer (%s)" % str(p))
	gelijk(State.bed_plekken("kamer1", nieuw).size(), nieuw, "en ook voor allemaal")
	# a new bed stands on nothing: not on the bowl, the basket, a bed or a door
	var r = Rooms.get_kamer("kamer1")
	for q in State.bed_plekken("kamer1", nieuw):
		var bed := Rect2((q as Vector2) + Vector2(-17.0, -8.0), Vector2(34.0, 17.0))
		for stuk in r.decor:
			if not bool(stuk.get("ver", false)):
				waar(not bed.has_point(Vector2(float(stuk["x"]), float(stuk["z"]))),
					"een nieuw bed op %s staat niet op %s" % [str(q), str(stuk["n"])])
		for sid in r.slots:
			var sl: Dictionary = r.slots[sid]
			waar(not bed.grow(6.0).has_point(Vector2(float(sl["x"]), float(sl["z"]))),
				"een nieuw bed op %s staat niet op %s" % [str(q), sid])
		for naar in r.deur_punten:
			var dp: Dictionary = r.deur_punten[naar]
			waar(not bed.grow(6.0).has_point(Vector2(float(dp["ix"]), float(dp["iz"]))),
				"een nieuw bed op %s staat niet in de deur" % str(q))
	# two sleepers in kamer 1: no free bed, the floor still takes a new one
	var a := State.mk_gast("a", "A", "hond", "puppy", 1, "Wandeling", 30)
	var b := State.mk_gast("b", "B", "poes", "poes", 1, "Spelen", 15)
	a["kamer"] = "kamer1"
	a["bed"] = "bed1"
	b["kamer"] = "kamer1"
	b["bed"] = "bed2"
	State.s["gasten"] = [a, b]
	gelijk(State.slapers_in("kamer1").size(), 2, "twee slapers")
	gelijk(State.vrije_bedden("kamer1").size(), 0, "geen vrij bed")
	gelijk(State.bed_vrij("kamer1"), {}, "ook niet volgens bed_vrij")
	waar(not State.bed_vrij("kamer2").is_empty(), "in kamer 2 wel")
	gelijk(State.plek_in("kamer1"), nieuw, "alleen nog de nieuwe bedden")
	# kamer 1 filled with every bed the check-in may put down, all taken: kamer 1
	# is full, kamer 2 is not
	var gasten: Array = [a, b]
	while State.nieuwe_bedden("kamer1") > 0:
		var q := State.bed_plek("kamer1")
		var m := Rooms.meubel_zet("kamer1", "bed", float(q["x"]), float(q["z"]))
		waar(not m.is_empty(), "een nieuw bed op %s" % str(q))
		var g := State.mk_gast("g%d" % gasten.size(), "G", "hond", "puppy", 1, "Wandeling", 30)
		g["kamer"] = "kamer1"
		g["bed"] = str(m.get("id", ""))
		gasten.append(g)
	State.s["gasten"] = gasten
	gelijk(State.nieuwe_bedden("kamer1"), 0, "de check-in zet er geen meer bij")
	waar(Rooms.slots("kamer1", "bed").size() <= State.MAX_BEDDEN, "nooit meer dan zes")
	gelijk(State.plek_in("kamer1"), 0, "kamer 1 is vol")
	gelijk(str(State.kamers_met_plek()), str(["kamer2"]), "alleen kamer 2 heeft plek")
	waar(State.plek_voor_gast(), "dus er mag nog een gast komen")
	# a bed bought in the meubelboek (anywhere the grid takes it) is a free bed:
	# room for one more after all
	var extra := Rooms.meubel_zet("kamer1", "bed", 60.0, 60.0)
	if not extra.is_empty():
		gelijk(State.plek_in("kamer1"), 1, "een gekocht bed geeft plek")
	Rooms.herstel()

## The check-in fills the bed places in order (owner, 2026-09-24: "De eerste
## twee bedden zijn goed geplaatst, daarna gaat alles door elkaar"): the room
## chosen for each new guest gets his bed on its next free bed place — as the
## beds game does it, a free bed first, else `bed_plek` + `voeg_bed` — every
## guest lies in a bed of his own, and the guest cap is exactly the bed places.
func test_de_check_in_vult_de_bedplekken_op_volgorde() -> void:
	_voor()
	Rooms.herstel()
	var plekken := 0
	for k in State.slaapkamers():
		plekken += Rooms.bed_raster(k).size()
	gelijk(plekken, 8, "vier bedplekken in elk van de twee slaapkamers")
	gelijk(State.max_gasten(), plekken, "de gastenlimiet is het aantal bedplekken")
	var pool := State.gasten_pool()
	var gasten: Array = []
	var n := 0
	while State.plek_voor_gast() and n < 30:
		var kamers := State.kamers_met_plek()
		var k: String = kamers[n % kamers.size()]
		var slot := ""
		var vrij := State.vrije_bedden(k)
		if not vrij.is_empty():
			slot = str((vrij[0] as Dictionary)["id"])
		else:
			var p := State.bed_plek(k)
			gelijk(Vector2(float(p["x"]), float(p["z"])), Rooms.vrije_bedplekken(k)[0],
				"%s: het nieuwe bed komt op de eerstvolgende bedplek" % k)
			slot = str(World.voeg_bed(k, {"x": p["x"], "z": p["z"]}).get("id", ""))
		waar(not slot.is_empty(), "gast %d krijgt een bed in %s" % [n + 1, k])
		var g: Dictionary = (pool[n % pool.size()] as Dictionary).duplicate(true)
		g["id"] = "%s_%d" % [str(g["id"]), n]
		g["kamer"] = k
		g["bed"] = slot
		gasten.append(g)
		State.s["gasten"] = gasten
		n += 1
	gelijk(n, plekken, "precies zoveel gasten als bedplekken")
	waar(not State.plek_voor_gast(), "en dan is het hotel vol")
	gelijk(State.max_gasten(), plekken, "de limiet bleef wat hij was")
	var gezien := {}
	for g in gasten:
		var sleutel := "%s|%s" % [str(g["kamer"]), str(g["bed"])]
		waar(not gezien.has(sleutel), "%s ligt alleen in %s" % [str(g["id"]), sleutel])
		gezien[sleutel] = true
		waar(not Rooms.slot(str(g["kamer"]), str(g["bed"])).is_empty(), "het bed van %s bestaat" % g["id"])
	for b in Rooms.slots("", "bed"):
		waar(Rooms.bed_raster(str(b["kamer"])).has(Vector2(float(b["x"]), float(b["z"]))),
			"%s in %s staat op een bedplek" % [b["id"], b["kamer"]])
		gelijk(str(b["model"]), Rooms.bed_model(str(b["kamer"])), "%s ligt zoals de kamer" % b["id"])
	Rooms.herstel()

## Every guest a bed of his own, also after a save that says otherwise: the
## seed `tools/kiek.js --gasten 7` made until 2026-09-24 put guests 5, 6 and 7
## in bed1/bed2 again — two animals in one bed on the picture.
func test_herstel_geeft_elk_dier_een_eigen_bed() -> void:
	_voor()
	Rooms.herstel()
	var rond := [["kamer1", "bed1"], ["kamer1", "bed2"], ["kamer2", "bed1"], ["kamer2", "bed2"]]
	var gasten: Array = []
	for i in 7:
		var g := State.mk_gast("g%d" % i, "G%d" % i, "hond", "puppy", 1, "Wandeling", 30)
		g["kamer"] = rond[i % 4][0]
		g["bed"] = rond[i % 4][1]
		g["waar"] = g["kamer"]
		gasten.append(g)
	State.s["gasten"] = gasten
	var verhuisd := State.herstel_bedden()
	gelijk(str(verhuisd), str(["g4", "g5", "g6"]), "de drie dubbele dieren kregen een ander bed")
	for i in 4:
		gelijk(str(gasten[i]["bed"]), rond[i][1], "g%d houdt zijn bed" % i)
	gelijk(str(gasten[4]["kamer"]), "kamer1", "g4 blijft in zijn kamer")
	var s4 := Rooms.slot("kamer1", str(gasten[4]["bed"]))
	gelijk(Vector2(float(s4["x"]), float(s4["z"])), Rooms.bed_raster("kamer1")[2],
		"op de derde bedplek van kamer 1")
	_elk_een_eigen_bed("na de reparatie")
	# a bed that is gone: its guest gets the free bed of his room
	gasten[0]["bed"] = "m99_bed"
	gelijk(str(State.herstel_bedden()), str(["g0"]), "g0 had geen bed meer")
	_elk_een_eigen_bed("na een verdwenen bed")
	gelijk(str(gasten[0]["kamer"]), "kamer1", "g0 slaapt weer in kamer 1")
	# the hotel full up: the last free bed place, then the waiting list
	var extra: Array = []
	for i in 2:
		var g := State.mk_gast("x%d" % i, "X%d" % i, "poes", "poes", 1, "Spelen", 15)
		g["kamer"] = "kamer2"
		g["bed"] = "bed1"
		gasten.append(g)
		extra.append(g)
	State.herstel_bedden()
	_elk_een_eigen_bed("in een vol hotel")
	gelijk(str(extra[0]["kamer"]), "kamer2", "x0 krijgt de laatste bedplek")
	gelijk(Rooms.vrije_bedplekken("kamer2").size(), 0, "kamer 2 is vol")
	waar(not (State.s["gasten"] as Array).has(extra[1]), "x1 is niet meer in het hotel")
	gelijk(str(State.s["wachtlijst"][0]["id"]), "x1", "maar staat vooraan op de wachtlijst")
	gelijk(str(extra[1]["bed"]), "", "zonder bed")
	Rooms.herstel()

func _elk_een_eigen_bed(wanneer: String) -> void:
	var gezien := {}
	for g in State.s["gasten"]:
		var sleutel := "%s|%s" % [str(g["kamer"]), str(g["bed"])]
		waar(not gezien.has(sleutel), "%s: %s deelt %s" % [wanneer, str(g["id"]), sleutel])
		gezien[sleutel] = true
		var slot := Rooms.slot(str(g["kamer"]), str(g["bed"]))
		waar(not slot.is_empty() and str(slot["soort"]) == "bed",
			"%s: het bed van %s bestaat (%s)" % [wanneer, str(g["id"]), sleutel])

func test_reparaties_verliezen_nooit_een_gast() -> void:
	_voor()
	# 1. a checkin whose gastId does not match nieuweGast is dropped
	State.s["nieuweGast"] = State.mk_gast("muis", "Muis", "poes", "poes", 1, "Spelen", 15)
	State.s["checkin"] = {"gastId": "iemand-anders", "stap": 1}
	State.bewaar()
	State.s = State.standaard()
	waar(State.lees(), "lees()")
	gelijk(State.s["checkin"], null, "een losse check-in wordt weggegooid")
	# 2. and the pending guest then goes to the FRONT of the waiting list
	gelijk(State.s["nieuweGast"], null, "geen halve gast aan de balie")
	gelijk(State.s["wachtlijst"][0]["id"], "muis", "hij staat weer vooraan")

func test_gast_wordt_gerepareerd() -> void:
	_voor()
	State.s["gasten"] = [{"id": "kaal", "kamer": "kamer1"}]
	State.bewaar()
	State.s = State.standaard()
	waar(State.lees(), "lees()")
	var g: Dictionary = State.s["gasten"][0]
	gelijk(g["naam"], "kaal", "naam valt terug op de id")
	gelijk(g["name"], g["naam"], "naam en name spiegelen")
	gelijk(g["waar"], "kamer1", "waar valt terug op de kamer")
	gelijk(g["nachten"], 2, "nachten 2")
	gelijk(g["geslapen"], 0, "geslapen 0")
	gelijk(g["prijs"], 1, "prijs 1")
	gelijk(g["behoefte"], "eten", "met kamer -> eten")
	gelijk(g["accessoires"], [], "accessoires leeg")

## The wardrobe (2026-09-24): what a guest bought is his, worn or not, and it
## survives a save; a save from before the shops simply has an empty one, and
## what the guest wears counts as his own anyway (a souvenir from the stall).
func test_de_kast_van_een_gast() -> void:
	_voor()
	State.s["gasten"] = [{"id": "kast", "kamer": "kamer1", "accessoires": ["hoedje"]}]
	State.bewaar()
	State.s = State.standaard()
	waar(State.lees(), "lees() zonder kast")
	gelijk(State.kast_van("kast"), ["hoedje"], "wat hij draagt is van hem")
	State.in_kast("kast", "pet")
	State.in_kast("kast", "pet")
	State.in_kast("kast", "bestaat-niet")
	gelijk(State.kast_van("kast"), ["hoedje", "pet"], "een pet erbij, één keer, en niets onbekends")
	State.bewaar()
	State.s = State.standaard()
	waar(State.lees(), "lees() met kast")
	gelijk(State.kast_van("kast"), ["hoedje", "pet"], "de kast overleeft een herlaad")
	gelijk(State.kast_van("niemand"), [], "een onbekende gast heeft niets")
	# a wardrobe that is not a list makes the file unreadable, like accessoires
	State.s["gasten"] = [{"id": "kapot", "kast": "pet"}]
	State.bewaar()
	State.s = State.standaard()
	waar(not State.lees(), "een kast die geen lijst is: het bestand telt niet")

# ------------------------------------------------------------------ brieven

func test_brief_van_de_familie() -> void:
	_voor()
	var g: Dictionary = State.mk_gast("boef", "Boef", "hond", "puppy", 2, "Wandeling", 30)
	g["kamer"] = "kamer2"
	var b := State.nieuwe_brief(g)
	gelijk(b["titel"], "Bedankje van familie Van Dijk 💌", "titel van de eerste brief")
	gelijk(State.s["famIdx"], 1, "famIdx schuift op")
	waar(b["tekst"].begins_with("Lieve hotelhouder,\n\n"), "aanhef")
	waar(b["tekst"].contains("Boef rende elke dag door de tuin en at netjes het bakje leeg."),
		"zin 2 hoort bij famIdx 1")
	waar(b["tekst"].ends_with("Liefs, familie Van Dijk"), "ondertekening")
	gelijk(b["dag"], State.s["dag"], "de dag staat erbij")
	var b2 := State.nieuwe_brief(g)
	gelijk(b2["titel"], "Bedankje van familie De Groot 💌", "de volgende familie")
	waar(b2["tekst"].contains("Boef vond het bad het allerleukste"), "zin 3")

func test_bezit_en_lidwoord() -> void:
	gelijk(State.bezit("Boef"), "Boefs", "Boef -> Boefs")
	gelijk(State.bezit("Pip"), "Pips", "Pip -> Pips")
	gelijk(State.bezit("Muis"), "Muis'", "s -> alleen een apostrof")
	gelijk(State.bezit("Bo"), "Bo's", "lange klinker -> 's")
	gelijk(State.met_lidwoord({"soort": "konijn"}), "het konijn", "het konijn")
	gelijk(State.met_lidwoord({"soort": "poes"}), "de poes", "de poes")

# ------------------------------------------------------------- band en som

func test_band_volgt_gasten_en_kunnen() -> void:
	_voor()
	gelijk(State.band(), 3, "zonder gasten band 3")
	var gasten: Array = []
	for i in 7:
		gasten.append(State.mk_gast("g%d" % i, "G%d" % i, "hond", "puppy", 1, "Spelen", 15))
	State.s["gasten"] = gasten
	gelijk(Sommen.band_van_n(7), 5, "bandVanN(7) = 5")
	gelijk(State.band(), 4, "kunnen 3 begrenst hem op 4")
	State.s["kunnen"] = 5
	gelijk(State.band(), 5, "met kunnen 5 mag band 5")
	State.s["gasten"] = []
	gelijk(State.band(), 3, "N begrenst hem weer")

func test_signaal_houdt_tien_items() -> void:
	_voor()
	for i in 14:
		State.tel(false, 9000)
	waar((State.s["signaal"] as Array).size() <= State.SIGNAAL_MAX,
		"hooguit tien items in het signaal")
	gelijk(State.s["kunnen"], 3, "kunnen zakt niet onder 3")

## The two frozen worked examples the hotel leans on (world.md §3.9).
func test_frozen_deel_en_geld() -> void:
	var d := Sommen.deel(5, 4, 2)
	gelijk(d["k"], 10, "deel(5, 4, 2).k")
	gelijk(d["r"], 1, "deel(5, 4, 2).r")
	gelijk(d["T"], 51, "deel(5, 4, 2).T")
	var g := Sommen.geld(5, 4)
	gelijk(g["prijs"], 2, "band 5 dag 4: prijs 2")
	gelijk(g["nachten"], 4, "vier nachten")
	gelijk(g["totaal"], 8, "2 x 4 = 8")
	gelijk(g["betaald"], 10, "betaald met een biljet van 10")
	gelijk(g["wissel"], 2, "2 terug")
