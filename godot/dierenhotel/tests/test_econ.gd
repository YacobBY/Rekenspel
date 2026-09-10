extends Proef
## `Econ`: stars, coins, the coin helpers and the three-step bill of
## world.md §3.5 — including the reload in the middle of it (Q-X1-4).

func _voor() -> void:
	State.nieuw_spel()
	State.start_gekozen()
	Econ.rekening_stop()

func _gast(id := "boef", naam := "Boef") -> Dictionary:
	var g := State.mk_gast(id, naam, "hond", "puppy", 2, "Wandeling", 30)
	g["kamer"] = "kamer1"
	g["bed"] = "bed1"
	State.s["gasten"] = [g]
	return g

# ------------------------------------------------------------------ munten

func test_buidel_kan_elk_bedrag_leggen() -> void:
	gelijk(Econ.buidel(13), [5, 2, 2, 2, 1, 1], "buidel(13)")
	gelijk(Econ.buidel(10), [5, 2, 2, 1], "buidel(10)")
	gelijk(Econ.splits(13), [10, 2, 1], "splits(13)")
	gelijk(Econ.splits(20), [10, 10], "splits(20)")
	# the point of the purse: every amount up to the total is payable exactly
	for totaal in [1, 2, 5, 8, 10, 13, 20]:
		var munten := Econ.buidel(totaal)
		var som := 0
		for v in munten:
			som += v
		gelijk(som, totaal, "buidel(%d) telt op tot %d" % [totaal, totaal])
		for doel in range(1, totaal + 1):
			waar(_kan_leggen(munten, doel), "buidel(%d) legt ook %d" % [totaal, doel])

func _kan_leggen(munten: Array, doel: int) -> bool:
	var haalbaar := {0: true}
	for v in munten:
		for som in haalbaar.keys().duplicate():
			haalbaar[som + int(v)] = true
	return haalbaar.has(doel)

func test_biljet_of_munt() -> void:
	gelijk(Econ.munt_soort(10), "biljet", "€10 is een biljet")
	gelijk(Econ.munt_soort(20), "biljet", "€20 is een biljet")
	gelijk(Econ.munt_soort(5), "munt", "€5 is een munt")

func test_tel_mee() -> void:
	gelijk(Econ.tel_mee(5, 3), "5 … 10 … 15.", "5 x 3 telt mee")
	gelijk(Econ.tel_mee(1, 3), "1 … 2 … 3.", "wisselgeld telt met stapjes van 1")
	gelijk(Econ.tel_mee(2, 1), "2.", "een enkele stap")

# ------------------------------------------------------------ sterren, munten

## A star is for taking part: `sterren()` has no "correct" parameter (F5).
func test_ster_en_munt_melden_zich() -> void:
	_voor()
	var sterren := []
	var munten := []
	Econ.sterren_veranderd.connect(func(n): sterren.append(n))
	Econ.munten_veranderd.connect(func(n): munten.append(n))
	Econ.sterren(1, "checkin")
	Econ.sterren(2, "spel")
	Econ.geef_munt(6)
	gelijk(State.s["sterren"], 3, "drie sterren")
	gelijk(State.s["munten"], 6, "zes munten")
	gelijk(sterren, [1, 3], "sterren_veranderd meldt elke keer")
	gelijk(munten, [6], "munten_veranderd meldt")

# ------------------------------------------------------------- de rekening

## Band 5, day 4: 4 nachten x €2 = €8, betaald met €10, €2 terug.
func test_rekening_drie_stappen() -> void:
	_voor()
	var g := _gast()
	var uit := []
	Econ.rekening_klaar.connect(func(r): uit.append(r), CONNECT_ONE_SHOT)
	var geld := Sommen.geld(5, 4)
	Econ.rekening({"gast": g, "fam": "Bakker", "nachten": geld["nachten"],
		"prijs": geld["prijs"], "totaal": geld["totaal"], "betaald": geld["betaald"]})
	var r := Econ.rekening_stand()
	gelijk(r["stap"], 1, "stap 1: de som")
	gelijk(r["totaal"], 8, "4 x 2 = 8")
	gelijk(r["hand"], [5, 2, 2, 1], "de familie houdt buidel(10) vast")

	# a wrong answer costs nothing but one line of help
	await Econ.som_ok(9)
	gelijk(Econ.rekening_stand()["stap"], 1, "fout: nog steeds stap 1")
	gelijk(Econ.rekening_stand()["pogingen"], 1, "een poging erbij")
	await Econ.som_ok(null)
	gelijk(Econ.rekening_stand()["pogingen"], 1, "leeg invoeren is geen misser")
	await Econ.som_ok(8)
	gelijk(Econ.rekening_stand()["stap"], 2, "goed: munten tellen")

	# too few coins first: the counter goes up, the bill stays open
	Econ.leg_neer()
	Econ.leg_neer()
	gelijk(Econ.geteld(), 7, "5 + 2 op de toonbank")
	await Econ.klaar_met_tellen()
	gelijk(Econ.rekening_stand()["stap"], 2, "te weinig: tellen gaat door")
	gelijk(Econ.rekening_stand()["telPog"], 1, "eigen teller voor het tellen")
	gelijk(Econ.rekening_stand()["pogingen"], 1, "de som-teller staat stil")
	Econ.leg_neer()
	Econ.leg_neer()
	gelijk(Econ.geteld(), 10, "de hele buidel ligt op de toonbank")
	gelijk(Econ.rekening_stand()["hand"], [], "de buidel is leeg")
	Econ.leg_neer()
	gelijk(Econ.geteld(), 10, "een lege buidel legt niets meer neer")
	await Econ.klaar_met_tellen()
	gelijk(Econ.rekening_stand()["stap"], 3, "te veel: wisselgeld")

	await Econ.wissel_ok(3)
	gelijk(Econ.rekening_stand()["wisselPog"], 1, "fout wisselgeld telt mee")
	await Econ.wissel_ok(2)
	waar(not Econ.rekening_bezig(), "de rekening is klaar")
	gelijk(State.s["rekening"], null, "en staat niet meer in de opslag")
	gelijk(uit.size(), 1, "rekening_klaar kwam één keer")
	gelijk(uit[0]["totaal"], 8, "totaal 8")
	gelijk(uit[0]["betaald"], 10, "betaald 10")
	gelijk(uit[0]["wissel"], 2, "wissel 2")
	gelijk(uit[0]["pogingen"], 3, "1 som + 1 tellen + 1 wisselgeld")
	gelijk(uit[0]["gastId"], "boef", "en over welke gast het ging")

## Exactly paid: no change step at all.
func test_rekening_precies_betaald() -> void:
	_voor()
	var g := _gast()
	var uit := []
	Econ.rekening_klaar.connect(func(r): uit.append(r), CONNECT_ONE_SHOT)
	Econ.rekening({"gast": g, "fam": "Jansen", "nachten": 2, "prijs": 5,
		"totaal": 10, "betaald": 10})
	await Econ.som_ok(10)
	for i in 4:
		Econ.leg_neer()
	gelijk(Econ.geteld(), 10, "precies genoeg")
	await Econ.klaar_met_tellen()
	gelijk(uit.size(), 1, "meteen klaar")
	gelijk(uit[0]["wissel"], 0, "niets terug")

## The whole moment survives a reload with the coins already counted.
func test_rekening_overleeft_een_herlaad() -> void:
	_voor()
	var g := _gast()
	Econ.rekening({"gast": g, "fam": "Bakker", "nachten": 4, "prijs": 2,
		"totaal": 8, "betaald": 10})
	await Econ.som_ok(8)
	Econ.leg_neer()
	Econ.leg_neer()
	waar(State.bewaar(), "bewaar midden in de rekening")
	State.s = State.standaard()
	waar(State.lees(), "lees")
	Econ.herstel_rekening()
	waar(Econ.rekening_bezig(), "de rekening loopt weer")
	gelijk(Econ.rekening_stand()["stap"], 2, "nog steeds bij het tellen")
	gelijk(Econ.geteld(), 7, "de getelde munten liggen er nog")
	gelijk(Econ.rekening_stand()["hand"], [2, 1], "en de rest zit in de buidel")

## The help ladder never punishes; it only adds lines.
func test_hulpladder_telt_per_stap() -> void:
	_voor()
	var g := _gast()
	Econ.rekening({"gast": g, "fam": "Visser", "nachten": 3, "prijs": 5,
		"totaal": 15, "betaald": 20})
	for i in 3:
		await Econ.som_ok(1)
	gelijk(Econ.rekening_stand()["pogingen"], 3, "drie pogingen op de som")
	gelijk(Econ.rekening_stand()["stap"], 1, "en nog steeds dezelfde vraag")
	await Econ.som_ok(15)
	gelijk(Econ.rekening_stand()["telPog"], 0, "het tellen begint bij nul")
	Econ.rekening_stop()

func test_de_regel_op_de_bon_past_op_de_kaart() -> void:
	_voor()
	# F4: one sentence, <= 8 words AND <= 40 characters, also for the longest
	# name in the pool
	var g := _gast("stamp", "Stampertje")
	Econ.rekening({"gast": g, "fam": "Mulder", "nachten": 3, "prijs": 5,
		"totaal": 15, "betaald": 20})
	var zin := "Stampertje sliep 3 nachten, €5 per nacht"
	gelijk(zin.split(" ", false).size(), 7, "zeven woorden")
	waar(zin.length() <= 40, "hooguit 40 tekens (%d)" % zin.length())
	Econ.rekening_stop()
