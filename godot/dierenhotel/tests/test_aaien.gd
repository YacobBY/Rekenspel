extends Proef
## The petting supply (PLAN.md §3.4, task `D1`) — the data half of it.  The
## button, the hearts and the nap live in `hotel/aaien.gd` and arrive with `D2`;
## what this file pins down is the ladder underneath them: three per guest, only
## spent by petting, only refilled by maths, never touched by the clock.
##
## Those are three different owners, so they are tested apart.  `mk_gast`,
## `GAST_INT` and `_repareer_gast` own the FIELD (it is there, it is an int, an
## old save gets one for free).  The four `aai_*` functions own the LADDER (it
## ends at zero and at three, and it refuses nothing).  `State.tel()` owns the
## refill, including the rule that is the easiest of all to lose in a later
## refactor: a WRONG answer fills up just as well (R6 — joining in is what
## counts, not being right).

func _voor() -> void:
	State.nieuw_spel()
	State.start_gekozen()

func _wis_bestand() -> void:
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("dierenhotel.json")
		dir.remove("dierenhotel.json.tmp")

## `n` guests checked in, straight from the pool the bell uses.
func _gasten(n: int) -> void:
	var uit: Array = []
	var pool := State.gasten_pool()
	for i in n:
		var g: Dictionary = pool[i]
		g["kamer"] = "kamer1"
		g["bed"] = "bed%d" % (i + 1)
		g["waar"] = "kamer1"
		uit.append(g)
	State.s["gasten"] = uit

# ------------------------------------------------------------------ het veld

func test_een_verse_gast_komt_met_drie_aaien() -> void:
	_voor()
	gelijk(State.AAI_MAX, 3, "drie aaien, niet meer")
	var g := State.mk_gast("boef", "Boef", "hond", "puppy", 2, "Wandeling", 30)
	gelijk(g["aai"], State.AAI_MAX, "mk_gast geeft de volle voorraad mee")
	gelijk(typeof(g["aai"]), TYPE_INT, "en wel als geheel getal")
	waar(State.GAST_INT.has("aai"), "`aai` staat in GAST_INT: _normaliseer en "
		+ "_gast_vorm_klopt bewaken het type gratis")
	# niet alleen de eerste: iedereen die de bel binnenhaalt begint vol
	for q in State.gasten_pool():
		gelijk(int(q["aai"]), State.AAI_MAX, "%s begint vol" % q["id"])
	for q in State.s["wachtlijst"]:
		gelijk(int(q["aai"]), State.AAI_MAX, "%s staat vol op de wachtlijst" % q["id"])

## The save is still v1: the field rides along on the guest record, so a stand
## halfway down the ladder comes back as the same INT it went in as.
func test_de_stand_overleeft_een_herlaad() -> void:
	_voor()
	_gasten(2)
	State.s["gasten"][0]["aai"] = 1
	State.s["gasten"][1]["aai"] = 0
	waar(State.bewaar(), "bewaar()")
	State.s = State.standaard()
	waar(State.lees(), "lees()")
	gelijk(int(State.s["gasten"][0]["aai"]), 1, "één aai over")
	gelijk(typeof(State.s["gasten"][0]["aai"]), TYPE_INT, "int, geen JSON-komma-getal")
	gelijk(int(State.s["gasten"][1]["aai"]), 0, "en nul blijft nul — geen cadeau")
	gelijk(typeof(State.s["gasten"][1]["aai"]), TYPE_INT, "ook nul is een int")
	_wis_bestand()

## A save from before this task has no `aai` at all.  It is not broken — the
## guest gets three pets as a present and nobody ends at the start screen
## (world.md §4.3: a guest is never lost).
func test_een_oude_opslag_krijgt_drie_aaien_cadeau() -> void:
	_voor()
	var oud := State.mk_gast("boef", "Boef", "hond", "puppy", 2, "Wandeling", 30)
	oud.erase("aai")
	oud["kamer"] = "kamer1"
	oud["bed"] = "bed1"
	oud["waar"] = "kamer1"
	State.s["gasten"] = [oud]
	waar(State.bewaar(), "bewaar() zonder het veld")
	State.s = State.standaard()
	waar(State.lees(), "zo'n bestand is niet kapot")
	gelijk(int(State.s["gasten"][0]["aai"]), State.AAI_MAX, "drie aaien cadeau")
	gelijk(typeof(State.s["gasten"][0]["aai"]), TYPE_INT, "en als int")
	_wis_bestand()

## A hand-edited number is put back on the ladder instead of costing the child
## its hotel — and nothing outside the ladder is ever read, reloaded or not.
func test_een_getal_buiten_de_ladder_wordt_teruggezet() -> void:
	_voor()
	_gasten(2)
	State.s["gasten"][0]["aai"] = 99
	State.s["gasten"][1]["aai"] = -4
	waar(State.bewaar(), "bewaar()")
	State.s = State.standaard()
	waar(State.lees(), "het bestand blijft bruikbaar")
	gelijk(int(State.s["gasten"][0]["aai"]), State.AAI_MAX, "99 wordt 3")
	gelijk(int(State.s["gasten"][1]["aai"]), 0, "−4 wordt 0")
	State.s["gasten"][0]["aai"] = 9
	gelijk(State.aai_van(str(State.s["gasten"][0]["id"])), State.AAI_MAX,
		"aai_van klemt ook zonder herlaad")
	_wis_bestand()

# ----------------------------------------------------------------- de ladder

func test_aai_uit_telt_af_en_blijft_op_nul() -> void:
	_voor()
	_gasten(1)
	var id := str(State.s["gasten"][0]["id"])
	gelijk(State.aai_van(id), 3, "drie om mee te beginnen")
	gelijk(State.aai_uit(id), 2, "de eerste aai laat er twee over")
	gelijk(State.aai_uit(id), 1, "de tweede één")
	gelijk(State.aai_uit(id), 0, "de derde nul — nu is het dutje")
	gelijk(State.aai_uit(id), 0, "een vierde tik weigert niets en zakt niet door nul heen")
	gelijk(State.aai_van(id), 0, "de stand blijft nul")
	gelijk(typeof(State.s["gasten"][0]["aai"]), TYPE_INT, "int in de opslag")

## Only a guest who is really in the hotel can be petted; everybody else is −1,
## and nothing crashes on the way (the button asks before it draws).
func test_een_onbekende_gast_geeft_min_een() -> void:
	_voor()
	_gasten(2)
	gelijk(State.aai_van("staat-hier-niet"), -1, "aai_van kent hem niet")
	gelijk(State.aai_uit("staat-hier-niet"), -1, "aai_uit ook niet")
	gelijk(State.aai_van(""), -1, "en een lege naam evenmin")
	var wacht: Dictionary = (State.s["wachtlijst"] as Array).back()
	waar(State.gast_van(str(wacht["id"])).is_empty(), "die staat echt niet in het hotel")
	gelijk(State.aai_van(str(wacht["id"])), -1, "de wachtlijst telt niet mee")

func test_aai_vol_zet_iedereen_vol() -> void:
	_voor()
	_gasten(4)
	State.s["gasten"][0]["aai"] = 0
	State.s["gasten"][1]["aai"] = 1
	State.s["gasten"][2]["aai"] = 3
	waar(State.aai_vol(), "er was iets bij te vullen")
	for g in State.s["gasten"]:
		gelijk(int(g["aai"]), State.AAI_MAX, "%s is vol" % g["id"])
	waar(not State.aai_vol(), "een tweede keer verandert niets meer")
	State.s["gasten"][0]["aai"] = 1
	waar(State.aai_bij(5), "meer dan één tegelijk mag")
	gelijk(int(State.s["gasten"][0]["aai"]), State.AAI_MAX, "maar nooit boven drie")

# ------------------------------------------------------------------ de vulling

## Every sum the child answers anywhere in the hotel hands every animal a pet
## back — a wrong one just as well.  The signal is what makes the hearts rise,
## so it only goes off when somebody really gained something.
func test_elke_som_vult_bij_ook_een_foute() -> void:
	_voor()
	_gasten(3)
	for g in State.s["gasten"]:
		g["aai"] = 0
	var gevuld: Array = [0]
	var oor := func() -> void: gevuld[0] += 1
	State.aai_gevuld.connect(oor)

	State.tel(true, 1000)
	for g in State.s["gasten"]:
		gelijk(int(g["aai"]), 1, "%s krijgt er één bij van een goed antwoord" % g["id"])
	gelijk(gevuld[0], 1, "en het signaal ging één keer")

	State.tel(false, 9000)
	for g in State.s["gasten"]:
		gelijk(int(g["aai"]), 2, "%s krijgt er één bij van een FOUT antwoord" % g["id"])
	gelijk(gevuld[0], 2, "meedoen telt, niet correct zijn")

	State.tel(true, 1000)
	gelijk(int(State.s["gasten"][0]["aai"]), State.AAI_MAX, "de derde som maakt hem vol")
	gelijk(gevuld[0], 3, "drie sommen, drie keer bijgevuld")

	State.tel(true, 1000)
	State.tel(false, 4000)
	for g in State.s["gasten"]:
		gelijk(int(g["aai"]), State.AAI_MAX, "nooit boven drie")
	gelijk(gevuld[0], 3, "een volle voorraad meldt niets meer")
	State.aai_gevuld.disconnect(oor)

## `tests/test_state.gd::test_signaal_houdt_tien_items` counts fourteen answers
## in an empty hotel: an empty guest list has to be a quiet `false`, not an
## error, or that file goes red for a reason that has nothing to do with it.
func test_tellen_zonder_gasten_doet_niets() -> void:
	_voor()
	gelijk((State.s["gasten"] as Array).size(), 0, "een leeg hotel")
	var gevuld: Array = [0]
	var oor := func() -> void: gevuld[0] += 1
	State.aai_gevuld.connect(oor)
	waar(not State.aai_bij(1), "aai_bij verdraagt een lege lijst")
	waar(not State.aai_vol(), "aai_vol ook")
	for i in 14:
		State.tel(false, 9000)
	gelijk(gevuld[0], 0, "en er gaat geen signaal af")
	gelijk(int(State.s["kunnen"]), 3, "kunnen zakt niet onder 3 (tel() doet zijn eigen werk nog)")
	State.aai_gevuld.disconnect(oor)

## None of the four writes the file.  `tel()` runs on every single answer, and a
## tablet that saves fifteen times a beurt is a tablet that stutters; the save
## follows from the caller that did the real work (a finished task, a new day).
func test_aaien_schrijft_de_opslag_niet() -> void:
	_voor()
	_gasten(2)
	_wis_bestand()
	var id := str(State.s["gasten"][0]["id"])
	State.aai_van(id)
	State.aai_uit(id)
	State.aai_bij(1)
	State.aai_vol()
	State.tel(true, 1000)
	waar(not FileAccess.file_exists(State.PAD), "geen van vieren bewaart, tel() ook niet")
