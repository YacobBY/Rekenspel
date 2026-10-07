extends Proef
## Koekjes bakken — de sommen van `KoekjesBeurt` per groep en per dag, de
## tekstregels (HOTEL.md §9), de bakkerij als kamer, de decormodellen en de
## registratie als stub.  Geen beurt in de wereld nog: het spel is een stub
## (.fanout/scratch/uitbreiding/U1-bakkerij.md).

const Beurt := preload("res://games/koekjes/beurt.gd")

## Rekent een som als "2 + 2 + 2 =", "3 × 5 =", "2 × 3 × 4 =" of "14 : 3 =" uit.
func _reken(som: String) -> int:
	var kaal := som.trim_suffix(" =").strip_edges()
	if kaal.contains(" : "):
		var d := kaal.split(" : ")
		@warning_ignore("integer_division")
		return int(d[0]) / int(d[1])
	if kaal.contains(" × "):
		var p := 1
		for s in kaal.split(" × "):
			p *= int(s)
		return p
	var t := 0
	for s in kaal.split(" + "):
		t += int(s)
	return t

func _elke(band: int, fn: Callable) -> void:
	for n in range(1, 9):
		for dag in range(1, 13):
			var b := Beurt.maak(n, band, dag)
			gelijk(_reken(str(b["som"])), int(b["goed"]), "%s: %s" % [b["soort"], b["som"]])
			waar(int(b["goed"]) > 0, "antwoord boven nul")
			var liever: Array = b["liever"]
			gelijk(liever.size(), 3, "drie afleiders")
			for l in liever:
				waar(int(l) != int(b["goed"]) and int(l) > 0,
					"afleider %s naast %d" % [str(l), int(b["goed"])])
			fn.call(n, b)

func test_groep3_telt_tot_twintig() -> void:
	var soorten := {}
	_elke(3, func(n: int, b: Dictionary) -> void:
		soorten[b["soort"]] = true
		waar(["koekjes", "eieren"].has(b["soort"]), "groep 3 soort " + str(b["soort"]))
		waar(int(b["goed"]) <= 20, "groep 3 blijft onder 20: " + str(b["som"]))
		if b["soort"] == "koekjes":
			gelijk(int(b["rijen"]), n, "een rij per gast")
			waar(int(b["kolommen"]) in [1, 2], "1 of 2 per dier")
			waar(not str(b["som"]).contains("×"), "groep 3 telt op, geen keer"))
	waar(soorten.has("koekjes") and soorten.has("eieren"), "beide soorten komen voor")

func test_groep4_tafels_2_5_10_en_verdubbelen() -> void:
	_elke(4, func(n: int, b: Dictionary) -> void:
		waar(["plaat", "dubbel"].has(b["soort"]), "groep 4 soort " + str(b["soort"]))
		if b["soort"] == "plaat":
			gelijk(int(b["rijen"]), n, "een rij per gast")
			waar(int(b["kolommen"]) in [2, 5, 10], "tafel van 2, 5 of 10")
		else:
			waar(int(b["eieren"]) <= 10 and int(b["goed"]) <= 20, "dubbel blijft onder 20"))

func test_groep5_platen_en_delen_met_rest() -> void:
	var soorten := {}
	_elke(5, func(n: int, b: Dictionary) -> void:
		soorten[b["soort"]] = true
		waar(["platen", "verdeel"].has(b["soort"]), "groep 5 soort " + str(b["soort"]))
		if b["soort"] == "platen":
			gelijk(int(b["platen"]), 2, "twee platen")
			waar(int(b["kolommen"]) <= 10 and int(b["rijen"]) * int(b["kolommen"]) <= 45,
				"binnen de tafels")
		else:
			waar(n >= 2, "delen alleen met twee of meer dieren")
			gelijk(int(b["totaal"]), int(b["goed"]) * n + int(b["rest"]), "T = k·N + r")
			waar(int(b["rest"]) < n, "rest kleiner dan het aantal dieren")
			gelijk(str(b["regel2"]), Beurt.REGEL_REST, "de rest is voor de kok"))
	waar(soorten.has("platen") and soorten.has("verdeel"), "beide soorten komen voor")

func test_zelfde_dag_zelfde_vraag() -> void:
	for band in [3, 4, 5]:
		var a := Beurt.maak(4, band, 7)
		var b := Beurt.maak(4, band, 7)
		gelijk(str(a), str(b), "herladen geeft dezelfde beurt in groep %d" % band)
	var anders := str(Beurt.maak(4, 4, 7)) != str(Beurt.maak(4, 4, 8)) \
		or str(Beurt.maak(4, 4, 7)) != str(Beurt.maak(4, 4, 9))
	waar(anders, "een andere dag geeft een andere vraag")

func test_zinnen_volgen_de_tekstregels() -> void:
	for zin in Beurt.zinnen():
		var woorden := zin.split(" ", false)
		waar(woorden.size() <= 8, "≤ 8 woorden: " + zin)
		waar(zin.length() <= 40, "≤ 40 tekens: " + zin)
		gelijk(Ui.mist_tekens(zin).size(), 0, "elk teken staat in de lettertypen: " + zin)
	waar(Beurt.TAAK.split(" ", false).size() <= 6, "taakkaartje ≤ 6 woorden")

func test_de_bakkerij_is_een_kamer_op_de_eerste_verdieping() -> void:
	waar(Rooms.bestaat("bakkerij"), "de bakkerij bestaat")
	gelijk(Rooms.etage("bakkerij"), 1, "naast de keuken op de eerste verdieping")
	# additive: after every room that was there (the winkels were the last one
	# before 2026-10-07); the three sibling rooms of that day may follow it
	waar(Rooms.lijst().find("bakkerij") > Rooms.lijst().find("winkels"),
		"achter de kamers die er al waren toegevoegd")
	waar(not Rooms.deur("bakkerij", "keuken").is_empty(), "deur naar de keuken")
	waar(not Rooms.deur("keuken", "bakkerij").is_empty(), "en de keuken heeft hem ook")
	_pad_is(Rooms.pad("receptie", "bakkerij"), ["receptie", "gang", "keuken", "bakkerij"])
	gelijk(World.ding("oven").get("kamer", ""), "bakkerij", "de oven staat in de bakkerij")

func _pad_is(gekregen: Array, verwacht: Array) -> void:
	gelijk(gekregen.size(), verwacht.size(), "padlengte")
	for i in mini(gekregen.size(), verwacht.size()):
		gelijk(gekregen[i], verwacht[i], "stap %d" % i)

func test_decormodellen_bakken() -> void:
	var t := ArtDecorBakkerij.tabel()
	for naam in ArtDecorBakkerij.NAMEN:
		waar(t.has(naam), "tabel kent " + naam)
		var v: Array = (t[naam] as Callable).call({})
		waar(v.size() > 0, naam + " heeft voxels")
	var plaat: Array = ArtDecorBakkerij.bakplaat({"rijen": 3, "kolommen": 5})
	var leeg: Array = ArtDecorBakkerij.bakplaat({"rijen": 3, "kolommen": 5, "aantal": 0})
	waar(plaat.size() > leeg.size(), "koekjes op de plaat zijn voxels")
	var vol: Array = ArtDecorBakkerij.eierschaal({"n": 8})
	var kom: Array = ArtDecorBakkerij.eierschaal({"n": 0})
	waar(vol.size() > kom.size(), "eieren in de kom zijn voxels")

func test_spel_is_een_stub_in_de_bakkerij() -> void:
	var d := Games.definitie("koekjes")
	waar(not d.is_empty(), "koekjes is geregistreerd")
	gelijk(str(d.get("kamer", "")), "bakkerij", "in de bakkerij")
	waar(bool(d.get("stub", false)), "nog een stub: niet op het bord, niet in de kamer")
	gelijk(str(d.get("hotspot", {}).get("obj", "")), "oven", "de knop hangt aan de oven")
