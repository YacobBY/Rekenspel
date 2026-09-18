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
	# the beds are the hard guest cap (world.md §5.3, HOTEL.md §2)
	var bedden := State.alle_bedden()
	gelijk(State.max_gasten(), bedden.size(), "max_gasten telt de bedden")
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
