extends Proef
## sterren — Sterren tellen op het dakterras (U3), headless.  The pure turn
## logic of `beurt.gd` for every band, every number of guests and many turns;
## the game's definition; the room on top of the tower; the deck's models.
## Driving a turn on the real shell is the next step (see the stand file
## .fanout/scratch/uitbreiding/U3-dakterras.md).

const Beurt := preload("res://games/sterren/beurt.gd")
const Spel := preload("res://games/sterren/spel.gd")
const Dak := preload("res://art/decor_dak.gd")

func _zin_ok(zin: String) -> bool:
	var woorden := zin.strip_edges().split(" ", false)
	return woorden.size() <= 8 and zin.length() <= 40

func test_patronen_kloppen() -> void:
	for k in range(1, 7):
		var p := Beurt.patroon("dobbel", k)
		gelijk(int(p["k"]), k, "dobbelsteen %d heeft %d ogen" % [k, k])
		var uniek := {}
		for c in p["cellen"]:
			uniek[c] = true
			waar((c as Vector2i).x >= 0 and (c as Vector2i).x < 3, "dobbel %d: in het 3×3 rooster" % k)
		gelijk(uniek.size(), k, "dobbel %d: elke oog op een eigen plek" % k)
	for k in range(0, 11):
		var p := Beurt.patroon("tien", k)
		gelijk(int(p["k"]), k, "tienveld %d" % k)
		gelijk(int(p["breed"]), 5, "een tienveld is vijf breed")
		for c in p["cellen"]:
			waar((c as Vector2i).y < 2, "tienveld %d: twee rijen" % k)
	var rij := Beurt.patroon("rij", 15, 5)
	gelijk(int(rij["k"]), 15, "3 rijen van 5 = 15 cellen")
	gelijk(int(rij["breed"]), 5, "de rij is 5 breed")
	var honderd := Beurt.patroon("honderd", 100)
	gelijk(int(honderd["waarde"]), 100, "een blok van honderd telt honderd")
	gelijk(Beurt.aantal([honderd, Beurt.patroon("tien", 10), Beurt.patroon("dobbel", 4)]), 114, "100 + 10 + 4")
	gelijk(Beurt.vorm_voor(6), "dobbel", "tot zes een dobbelsteen")
	gelijk(Beurt.vorm_voor(7), "tien", "vanaf zeven een tienveld")

## Every band, 1..8 guests, twelve turns, three seeds: the answer is what the
## patterns show, the sentence follows HOTEL.md §9, the near distractors are
## sound and the numbers stay in the band's range (IDEAS.md).
func test_elke_groep_elke_beurt_is_een_kloppende_som() -> void:
	var gezien := {}
	for band in [3, 4, 5]:
		for n in range(1, 9):
			for nr in 12:
				for zaad in [Beurt.ZAAD, Beurt.ZAAD + 1, Beurt.ZAAD + 2]:
					var b := Beurt.maak(band, n, nr, zaad)
					var wat := "groep %d, N %d, beurt %d, zaad %d (%s)" % [band, n, nr, zaad, b["soort"]]
					gezien[b["soort"]] = true
					var som := Beurt.aantal(b["patronen"])
					if b["soort"] == "tot_tien":
						gelijk(int(b["goed"]), 10 - som, wat + ": erbij tot tien")
					else:
						gelijk(int(b["goed"]), som, wat + ": het antwoord is wat er hangt")
					waar(int(b["goed"]) >= 1, wat + ": minstens één")
					var grens := 20 if band == 3 else (100 if band == 4 else 399)
					waar(int(b["goed"]) <= grens, wat + ": binnen de groep (%d ≤ %d)" % [int(b["goed"]), grens])
					waar(_zin_ok(str(b["regel"])), wat + ": de zin is kort (%s)" % b["regel"])
					waar(str(b["regel"]).begins_with("⭐"), wat + ": pictogram eerst")
					waar(not Ui.mist_tekens(str(b["regel"])), wat + ": elk teken is in de letters")
					waar(b["patronen"].size() >= 1, wat + ": er hangt iets")
					if band == 3:
						waar(b["patronen"].size() <= 2, wat + ": hooguit twee sterrenbeelden")
					for l in b["liever"]:
						waar(int(l) > 0 and int(l) != int(b["goed"]), wat + ": afleider %d deugt" % int(l))
					waar(b["liever"].size() >= 1 and b["liever"].size() <= 3, wat + ": één tot drie afleiders")
					waar(Beurt.keur(b, int(b["goed"])), wat + ": het goede antwoord keurt")
					waar(not Beurt.keur(b, int(b["goed"]) + 1), wat + ": één te veel keurt niet")
	for s in ["patroon", "samen", "tot_tien", "rijen", "dubbel", "tientallen", "honderden", "rijen_van"]:
		waar(gezien.has(s), "soort %s komt voor" % s)

func test_dezelfde_dag_dezelfde_vraag() -> void:
	var a := Beurt.maak(4, 3, 5, Beurt.ZAAD + 9)
	var b := Beurt.maak(4, 3, 5, Beurt.ZAAD + 9)
	gelijk(a, b, "dezelfde argumenten geven dezelfde beurt")
	gelijk(Beurt.soort(3, 1, 1), "patroon", "met één gast geen 'samen'")
	gelijk(Beurt.soort(3, 2, 1), "samen", "met twee gasten wel")
	gelijk(Beurt.soort(5, 4, 2), "rijen_van", "groep 5, derde beurt: rijen van")

func test_de_definitie_is_een_stub_op_het_dakterras() -> void:
	var spel: MiniGame = Spel.new()
	var d := spel.definitie()
	spel.free()
	gelijk(str(d["kamer"]), "dakterras", "het spel staat op het dakterras")
	waar(bool(d.get("stub", false)), "U3: nog een stub tot de beurt loopt")
	gelijk(str(d["hotspot"]["obj"]), "telescoop", "de knop hangt op de telescoop")
	waar(_zin_ok(str(d["taak"]["tekst"])), "de taakkaart is kort")
	waar(_zin_ok(str(d["hotspot"]["label"])), "het knoplabel is kort")
	waar((d["unlock"] as Callable).call(1, 3), "vanaf de eerste gast")

func test_het_dakterras_is_de_top_van_de_toren() -> void:
	var r := Rooms.get_kamer("dakterras")
	waar(r != null, "het dakterras bestaat")
	if r == null:
		return
	gelijk(r.etage, 4, "verdieping 4, boven de speelzaal")
	waar(r.erf, "buiten, onder de hemel")
	gelijk(Rooms.etages()[0], 4, "de bovenste verdieping van de toren")
	gelijk(Rooms.trap_richtingen("dakterras"), ["af"] as Array[String], "alleen een trap omlaag")
	gelijk(Rooms.trap_naar("dakterras", "af"), "speelzaal", "omlaag naar de speelzaal")
	gelijk(Rooms.trap_naar("speelzaal", "op"), "dakterras", "de speelzaal heeft weer een trap omhoog")
	gelijk(Rooms.trap_richtingen("speelzaal"), ["op", "af"] as Array[String], "beide vluchten in de speelzaal")
	waar(r.zones.has("sterren"), "de zone voor de telescoop en zijn stuk hemel")
	waar(Rooms.pad("receptie", "dakterras").size() >= 2, "je komt er vanaf de receptie")
	# additive: after every room that was there (the winkels were the last one
	# before 2026-10-07); the sibling rooms of that day stand around it
	waar(Rooms.lijst().find("dakterras") > Rooms.lijst().find("winkels"),
		"achter de kamers die er al waren (additief)")

## Every model of the deck bakes to voxels; the table and the names agree; the
## planned placement only names models the table has.
func test_de_modellen_van_het_dak_bakken() -> void:
	var t: Dictionary = Dak.tabel()
	gelijk(t.keys().size(), Dak.NAMEN.size(), "evenveel modellen als namen")
	for naam in Dak.NAMEN:
		waar(t.has(naam), "tabel kent %s" % naam)
		var v: Array = (t[naam] as Callable).call({})
		waar(v.size() > 10, "%s heeft voxels (%d)" % [naam, v.size()])
		for vox in v.slice(0, 5):
			var d: Dictionary = vox
			waar(d.has("x") and d.has("y") and d.has("z") and d.has("k"), "%s: voxel {x,y,z,k}" % naam)
	for stuk in Dak.PLAATSING:
		waar(Dak.NAMEN.has(str(stuk["n"])), "plaatsing kent %s" % str(stuk["n"]))
		var r := Rooms.get_kamer("dakterras")
		waar(float(stuk["x"]) >= 0.0 and float(stuk["x"]) <= float(r.w), "%s staat binnen de breedte" % str(stuk["n"]))
		waar(float(stuk["z"]) >= 0.0 and float(stuk["z"]) <= float(r.d), "%s staat binnen de diepte" % str(stuk["n"]))
