extends Proef
## Every worked example that games-a.md and games-b.md print for a generator,
## one assertion per row of the spec, in the spec's own order.
##
## These are the READABLE half of the proof: they say which number is wrong.
## `test_sommen_kruis.gd` holds the machine half — the whole sweep, hashed
## against the output of the original JavaScript.

# ============================================================ G1 — zwembad

## games-b.md §1.3, including the "Nagerekend" note: the window of band 5 is
## 31…80, not 31…76 (Q-X3-1 answered 80 in A1 §13).
func test_zwembad_baan() -> void:
	var b := Sommen.Zwembad.baan(5, 4, 1)
	gelijk(b["r"], 6, "baan(5,4,1).r = (5+1) mod 8")
	gelijk(b["L"], 46, "baan(5,4,1).L")
	gelijk(b["M"], 30, "baan(5,4,1).M")
	gelijk(b["stap"], 10, "baan(5,4,1).stap")
	# the windows of the three bands over every reachable turn
	var venster := {3: [999, 0], 4: [999, 0], 5: [999, 0]}
	var ronde: Array[int] = []
	for band in range(3, 6):
		for n in range(1, 13):
			for dag in range(1, 9):
				var q := Sommen.Zwembad.baan(n, band, dag)
				var v: Array = venster[band]
				v[0] = mini(v[0], int(q["L"]))
				v[1] = maxi(v[1], int(q["L"]))
				waar(int(q["L"]) <= 2 * int(q["M"]),
					"baan(%d,%d,%d): L <= 2M, dus hoogstens twee etappes" % [n, band, dag])
				if band == 5 and int(q["L"]) in [40, 50, 60, 70] and not ronde.has(int(q["L"])):
					ronde.append(int(q["L"]))
	gelijk(str(venster[3]), "[8, 20]", "band 3: L-venster 8…20")
	gelijk(str(venster[4]), "[21, 50]", "band 4: L-venster 21…50")
	gelijk(str(venster[5]), "[31, 80]", "band 5: L-venster 31…80 (niet 76)")
	gelijk(str(ronde), "[]", "band 5: 40, 50, 60 en 70 komen niet voor (+3-schuif)")

## games-b.md §1.4.  The spec prints the buttons but not the `leg` column;
## running the original in node settles it: the p = 0 rows are the FIRST choice
## of a turn (leg 0) and the p = M rows the second (leg 1).  Recorded here so
## nobody has to re-derive it.
func test_zwembad_keuzes_de_kaart_van_de_eigenaar() -> void:
	for rij in [[43, 30, 0, 4, 0, 30, "43,13,20,30"], [43, 30, 30, 4, 1, 13, "43,30,13,3"],
			[14, 10, 0, 3, 0, 10, "14,10,4,20"], [14, 10, 10, 3, 1, 4, "14,4,10,3"],
			[76, 40, 0, 5, 0, 40, "76,36,40,30"], [76, 40, 40, 5, 1, 36, "76,40,36,26"]]:
		var q := Sommen.Zwembad.keuze_getallen(rij[0], rij[1], rij[2], rij[3], rij[4])
		var d: Array[String] = []
		for v in q["lijst"]:
			d.append(str(v))
		gelijk(q["juist"], rij[5], "juist bij L=%d M=%d p=%d" % [rij[0], rij[1], rij[2]])
		gelijk(",".join(PackedStringArray(d)), rij[6], "knoppen bij L=%d M=%d p=%d leg=%d" % rij.slice(0, 4))
		gelijk(q["lijst"].size(), 4, "altijd vier knoppen")
		gelijk(q["lijst"].count(q["juist"]), 1, "precies één juiste knop")

## games-b.md §1.5: never punishing.  Too short = swim that far, too much = only
## M, too far = a soft bump against the wall.
func test_zwembad_slag() -> void:
	var goed := Sommen.Zwembad.slag(43, 30, 0, 30)
	gelijk(goed["soort"], "goed", "43 m, max 30, tik 30")
	gelijk(goed["meters"], 30, "hij zwemt 30")
	var kort := Sommen.Zwembad.slag(43, 30, 0, 20)
	gelijk(kort["soort"], "kort", "tik 20 van de 30")
	gelijk(kort["meters"], 20, "hij zwemt 20 en de rest komt op een nieuwe kaart")
	var veel := Sommen.Zwembad.slag(43, 30, 0, 40)
	gelijk(veel["soort"], "veel", "tik 40 terwijl er maar 30 mag")
	gelijk(veel["meters"], 30, "hij zwemt hooguit M")
	var ver := Sommen.Zwembad.slag(43, 30, 0, 50)
	gelijk(ver["soort"], "ver", "tik 50 terwijl het bad 43 lang is")
	gelijk(ver["meters"], 43, "hij zwemt tot de wand en botst zacht")

# ============================================================= G2 — wekker

## games-b.md §2.4 — Nederlandse klokafspraken, alle tien de verified gevallen.
func test_wekker_tijd_in_woorden() -> void:
	for rij in [[7, 0, "7 uur"], [7, 15, "kwart over 7"], [7, 30, "half 8"],
			[7, 45, "kwart voor 8"], [7, 5, "5 over 7"], [7, 20, "10 voor half 8"],
			[7, 35, "5 over half 8"], [7, 50, "10 voor 8"], [12, 30, "half 1"],
			[11, 55, "5 voor 12"]]:
		gelijk(Sommen.Wekker.tijd_woord(rij[0], rij[1]), rij[2],
			"tijdWoord(%d, %d)" % [rij[0], rij[1]])
	gelijk(Sommen.Wekker.u12(0), 12, "u12(0) = 12, nooit 0 uur")
	gelijk(Sommen.Wekker.u12(13), 1, "u12(13) = 1")

## games-b.md §2.3, the whole "Nagerekend (verified)" table: the frozen clock,
## the start position, the target and the shape of the question.
func test_wekker_beurten() -> void:
	for rij in [[2, 3, 1, 0, "10:00", "7 uur", "10 uur", "zet", ""],
			[3, 3, 2, 0, "13:00", "10 uur", "1 uur", "zet", ""],
			[5, 4, 1, 0, "10:45", "half 7", "10 uur", "zet", ""],
			[5, 4, 2, 1, "13:45", "kwart voor 11", "half 3", "zet", ""],
			[8, 5, 1, 0, "10:57", "7 uur", "10 uur", "duur", "11,9,4,10"],
			[8, 5, 2, 0, "13:19", "5 voor 10", "half 2", "zet", ""],
			[9, 5, 3, 0, "8:01", "5 uur", "8 uur", "duur", "2,8,9,7"]]:
		var n: int = rij[0]
		var band: int = rij[1]
		var dag: int = rij[2]
		var idx: int = rij[3]
		var wat := "N=%d band=%d dag=%d idx=%d" % [n, band, dag, idx]
		var k := Sommen.klok(band, dag)
		gelijk("%d:%02d" % [k["u"], k["m"]], rij[4], "%s: sommen.klok" % wat)
		var q := Sommen.Wekker.beurt(band, n, dag, idx)
		gelijk(Sommen.Wekker.tijd_woord(q["u"], q["m"]), rij[5], "%s: de klok start op" % wat)
		gelijk(Sommen.Wekker.tijd_woord(q["doelU"], q["doelM"]), rij[6], "%s: het doel" % wat)
		gelijk(q["stap"], rij[7], "%s: vorm van de vraag" % wat)
		var d: Array[String] = []
		for v in q["keuzes"]:
			d.append(str(v))
		gelijk(",".join(PackedStringArray(d)), rij[8], "%s: de uurknoppen" % wat)

# ============================================================= G3 — hinkel

## games-b.md §3.4, the whole "Nagerekend (verified)" table.
func test_hinkel_beurten() -> void:
	for rij in [[2, 3, 1, 1, 3, 1, 2, "1,2"], [3, 3, 3, 3, 7, 1, 4, "1,2"],
			[5, 4, 1, 10, 20, 2, 5, "2,5,10"], [6, 4, 2, 20, 70, 10, 5, "5,10"],
			[8, 5, 1, 15, 35, 2, 10, "2,4,5,10"], [9, 5, 2, 55, 95, 4, 10, "4,5,8,10"],
			[10, 5, 4, 25, 95, 7, 10, "7,10"]]:
		var wat := "N=%d band=%d dag=%d" % [rij[0], rij[1], rij[2]]
		var q := Sommen.Hinkel.beurt(rij[0], rij[1], rij[2])
		gelijk(q["s"], rij[3], "%s: start" % wat)
		gelijk(q["doel"], rij[4], "%s: doel" % wat)
		gelijk(q["sprong"], rij[5], "%s: maat" % wat)
		gelijk(q["n"], rij[6], "%s: sprongen" % wat)
		var d: Array[String] = []
		for v in Sommen.Hinkel.maten_voor(int(q["afstand"]), int(q["band"])):
			d.append(str(v))
		gelijk(",".join(PackedStringArray(d)), rij[7], "%s: maten die passen" % wat)
		waar(int(q["doel"]) < int(q["E"]),
			"%s: het doel ligt nooit op de laatste steen" % wat)
	# de strook: 2/4/5/10 wordt 2 / 5 / 10 (eerste, middelste, laatste)
	gelijk(str(Sommen.Hinkel.maten(20, 5)), "[2, 5, 10]", "maten(): hoogstens drie knoppen")

## games-b.md §3.4: precies één goede, geen dubbele, nooit nul of negatief.
func test_hinkel_keuze_getallen() -> void:
	for rij in [[4, 0, "[2, 3, 4, 5]"], [4, 1, "[3, 4, 5, 6]"], [4, 2, "[4, 5, 6, 7]"],
			[4, 3, "[2, 4, 6, 7]"], [4, 4, "[2, 3, 4, 7]"], [1, 0, "[1, 2, 3, 4]"]]:
		gelijk(str(Sommen.Hinkel.keuze_getallen(rij[0], rij[1])), rij[2],
			"keuzeGetallen(n=%d, zaad=%d)" % [rij[0], rij[1]])

# ================================================================ G4 — was

## games-b.md §4.3, the whole "Nagerekend (verified)" table.
func test_was_getallen() -> void:
	for rij in [[2, 3, 1, 2, 1, 5, 1, 2, "[3, 2]"], [3, 3, 2, 2, 0, 6, 1, 3, "[1, 2, 3]"],
			[3, 3, 3, 2, 1, 7, 1, 3, "[2, 1, 4]"], [5, 4, 1, 4, 0, 20, 1, 3, "[8, 5, 7]"],
			[6, 4, 2, 3, 1, 19, 1, 3, "[8, 6, 5]"], [8, 5, 1, 3, 2, 26, 2, 4, "[4, 5, 1, 3]"],
			[9, 5, 2, 3, 1, 28, 2, 4, "[3, 4, 2, 5]"], [10, 5, 3, 3, 0, 30, 2, 4, "[6, 3, 2, 4]"],
			[1, 5, 1, 10, 8, 18, 2, 3, "[3, 4, 2]"]]:
		var wat := "N=%d band=%d dag=%d" % [rij[0], rij[1], rij[2]]
		var q := Sommen.Was.recept(rij[0], rij[1], rij[2])
		gelijk(q["k"], rij[3], "%s: k" % wat)
		gelijk(q["r"], rij[4], "%s: r" % wat)
		gelijk(q["T"], rij[5], "%s: T" % wat)
		gelijk(q["per"], rij[6], "%s: per tik" % wat)
		gelijk(q["m"], rij[7], "%s: soorten" % wat)
		gelijk(str(q["blok"]), rij[8], "%s: de stapels" % wat)

## A1 §13 Q-X3-12: the `k = 0` emergency branch is unreachable for every (N, band)
## the game can reach, and the highest possible pile is 8 blocks.
func test_was_noodgeval_is_onbereikbaar() -> void:
	var hoogste := 0
	for n in range(1, 13):
		for band in range(3, 6):
			for dag in range(1, 13):
				var q := Sommen.Was.recept(n, band, dag)
				waar(int(q["k"]) > 0, "was(%d,%d,%d): k = 0 mag niet voorkomen" % [n, band, dag])
				for v in q["blok"]:
					hoogste = maxi(hoogste, int(v))
	gelijk(hoogste, 8, "de hoogst mogelijke stapel is 8 blokjes")

# ============================================================== G5 — kraam

## games-b.md §5.3, the worked example and the table of ranges.
func test_kraam_opzet() -> void:
	var o := Sommen.Kraam.opzet(9, 5, 2)
	var s := Sommen.Kraam.schuif_van(9, 5, 2)
	gelijk(s["v"], 3, "v = (9+2) mod 4")
	gelijk(s["schuif"], 3, "groep 5 schuift omhoog")
	gelijk(s["rot"], 1, "rot = (9 + 4) mod 3")
	gelijk(str(o["keus"]), '["bal", "hoedje"]', "i0 = 11 mod 3 = 2 -> bal + hoedje")
	gelijk(o["kosten"], 13, "€7 + €6")
	gelijk(o["betaald"], 20, "13 > 9, dus een briefje van 20")
	gelijk(o["wissel"], 7, "wisselgeld")
	gelijk(o["doel"], 7, "het kind legt het wisselgeld neer")
	gelijk(o["vraag"]["som"], "€20 − €13 =", "de som op de kaart (echt minteken U+2212)")
	var grens := {3: [99, 0, 99, 0, 99, 0], 4: [99, 0, 99, 0, 99, 0], 5: [99, 0, 99, 0, 99, 0]}
	for band in range(3, 6):
		for n in range(1, 13):
			for dag in range(1, 13):
				var q := Sommen.Kraam.opzet(n, band, dag)
				var g: Array = grens[band]
				for w in q["waren"]:
					if str(w["id"]) == "tas":
						continue
					g[0] = mini(g[0], int(w["prijs"]))
					g[1] = maxi(g[1], int(w["prijs"]))
				g[2] = mini(g[2], int(q["kosten"]))
				g[3] = maxi(g[3], int(q["kosten"]))
				g[4] = mini(g[4], int(q["wissel"]))
				g[5] = maxi(g[5], int(q["wissel"]))
	gelijk(str(grens[3]), "[2, 5, 2, 5, 0, 0]", "groep 3: prijzen 2…5, kosten 2…5, geen wisselgeld")
	gelijk(str(grens[4]), "[3, 6, 7, 11, 0, 0]", "groep 4: prijzen 3…6, kosten 7…11, geen wisselgeld")
	gelijk(str(grens[5]), "[3, 8, 7, 15, 1, 10]", "groep 5: prijzen 3…8, kosten 7…15, wissel 1…10")
	var tas := {}
	for w in Sommen.Kraam.opzet(9, 5, 2)["waren"]:
		if str(w["id"]) == "tas":
			tas = w
	gelijk(tas.get("prijs", 0), 12, "de tas is vast €12")
	gelijk(tas.get("acc", "-"), "", "de tas is niet te dragen en blijft dus decor (Q-X3-11)")

# =========================================================== A — groep A

## games-a.md §4.2, the three worked examples "nagerekend met de exacte LCG".
func test_sleutels_opdracht() -> void:
	var gasten: Array[Dictionary] = [
		{"id": "g1", "naam": "Boef", "soort": "puppy"},
		{"id": "g2", "naam": "Muis", "soort": "poes"},
		{"id": "g3", "naam": "Wolkje", "soort": "konijn"},
	]
	var a := Sommen.Sleutels.maak_opdracht(5, 4, 3, gasten)
	gelijk(a["H"], 5, "N 5, band 4, dag 3: vijf haakjes")
	gelijk(a["variant"], "sprong5", "variant")
	gelijk(a["borden"].size(), 1, "één bord")
	gelijk(str(a["borden"][0]["blanco"]), "[1, 3]", "lege haakjes op index 1 en 3")
	gelijk(_nummers(a), "10,20", "de sleutels")
	gelijk(_haken(a["borden"][0]), "5,10,15,20,25", "de rij")
	var b := Sommen.Sleutels.maak_opdracht(2, 3, 1, gasten)
	gelijk(b["H"], 4, "N 2, band 3, dag 1: vier haakjes")
	gelijk(b["variant"], "telrij", "variant")
	gelijk(_haken(b["borden"][0]), "1,2,3,4", "de rij")
	gelijk(str(b["borden"][0]["blanco"]), "[1]", "leeg op index 1")
	gelijk(_nummers(b), "2", "de sleutel")
	var c := Sommen.Sleutels.maak_opdracht(7, 5, 4, gasten)
	gelijk(c["H"], 4, "N 7, band 5, dag 4: vier haakjes")
	gelijk(c["variant"], "kamers", "variant")
	gelijk(c["borden"].size(), 3, "drie borden")
	gelijk(_haken(c["borden"][0]) + " " + str(c["borden"][0]["label"]),
		"111,112,113,114 verdieping 1", "bord 1")
	gelijk(_haken(c["borden"][1]) + " " + str(c["borden"][1]["label"]),
		"211,212,213,214 verdieping 2", "bord 2")
	gelijk(_haken(c["borden"][2]) + " " + str(c["borden"][2]["label"]),
		"115,116,117,118 verdieping 1", "bord 3")
	gelijk(_nummers(c), "113,212,116", "de drie sleutels")
	for p in [a, b, c]:
		gelijk(str(Sommen.Sleutels.controleer(p)["fout"]), "[]", "controleer() klaagt niet")

func _nummers(p: Dictionary) -> String:
	var d: Array[String] = []
	for s in p["sleutels"]:
		d.append(str(s["nummer"]))
	return ",".join(PackedStringArray(d))

func _haken(bord: Dictionary) -> String:
	var d: Array[String] = []
	for h in bord["haken"]:
		d.append(str(h["w"]))
	return ",".join(PackedStringArray(d))

## games-a.md §6.2 and .fanout/scratch/games-a-worked-examples.txt.
func test_tobbe_recept() -> void:
	for rij in [[3, 3, 1, "eerlijk", 6, 2, 3, 0], [5, 4, 3, "half", 10, 2, 5, 0],
			[6, 4, 2, "half", 12, 2, 6, 0], [7, 5, 5, "eerlijk", 14, 3, 4, 2],
			[7, 5, 4, "half", 21, 2, 10, 1], [9, 5, 6, "eerlijk", 18, 3, 6, 0]]:
		var wat := "N=%d band=%d dag=%d" % [rij[0], rij[1], rij[2]]
		var q := Sommen.Tobbe.recept(rij[0], rij[1], rij[2])
		gelijk(q["soort"], rij[3], "%s: soort" % wat)
		gelijk(q["T"], rij[4], "%s: T" % wat)
		gelijk(q["M"], rij[5], "%s: tobbes" % wat)
		gelijk(q["per"], rij[6], "%s: per tobbe" % wat)
		gelijk(q["rest"], rij[7], "%s: rest" % wat)
		waar(int(q["T"]) <= int(Sommen.Tobbe.PLAFOND[int(q["band"])]),
			"%s: nooit boven het plafond van de band" % wat)

## games-a.md §3.3, the worked example (band 4, dag 3, N 5, cap 6, maxStroken 4).
func test_bedden_opdracht() -> void:
	var q := Sommen.Bedden.opdracht(4, 3, 5, 6, 4)
	gelijk(q["perRij"], 3, "tafel geeft a = 3")
	gelijk(q["rijen"], 2, "min(5, 3, floor(6/3) = 2, 3, maxStroken-1 = 3)")
	gelijk(q["doel"], 6, "2 x 3")
	# de kamer is de baas: een te brede rij zakt naar een tafel die de band kent
	var krap := Sommen.Bedden.opdracht(3, 1, 3, 4, 4)
	waar(int(krap["perRij"]) <= 4, "perRij past in de kamer")
	waar([1, 2, 5, 10].has(int(krap["perRij"])), "perRij blijft in de tafels van groep 3")

## games-a.md §7.2 (voerkar) en §5.3 (meubels): de kleine bandregels.
func test_voerkar_en_meubels() -> void:
	gelijk(Sommen.Voerkar.som_regel(3, 12, 3, 0), "", "groep 3 kent het deelteken nog niet")
	gelijk(Sommen.Voerkar.som_regel(4, 30, 6, 0), "30 : 6", "groep 4 mag een deler van 6 zien")
	gelijk(Sommen.Voerkar.som_regel(4, 26, 6, 2), "", "delen mét rest hoort pas in groep 5")
	gelijk(Sommen.Voerkar.volgende_hand(2), 5, "de zak schakelt 1 - 2 - 5 door")
	gelijk(Sommen.Meubels.max_lijst(3), 1, "groep 3: één ding per keer")
	gelijk(Sommen.Meubels.max_lijst(4), 2, "groep 4: twee dingen samen")
	gelijk(Sommen.Meubels.buidel_max(3), 10, "groep 3 rekent t/m 10")
	gelijk(Sommen.Meubels.buidel_max(5), 20, "groep 4 en 5 t/m 20")
	waar(not Sommen.Meubels.wisselgeld(3), "groep 3 betaalt precies")
	waar(Sommen.Meubels.wisselgeld(4), "vanaf groep 4 is er wisselgeld")
	gelijk(Sommen.Meubels.buidel_cap(7, 13, 4), 13, "cap = max(totaal, min(munten, 20))")
	gelijk(Sommen.Meubels.buidel_cap(7, 30, 4), 20, "de rest blijft in de kassa")
	gelijk(Sommen.Meubels.buidel_cap(24, 30, 4), 24, "een duur lijstje past altijd in de buidel")
	gelijk(Sommen.Meubels.prijs_van("bed"), 5, "een bed kost €5 (HOTEL.md §4)")
	# elk bedrag t/m de buidel is precies te leggen — dat is de hele truc
	for totaal in range(1, 21):
		var munten := Sommen.buidel(totaal)
		var som := 0
		for v in munten:
			som += v
		gelijk(som, totaal, "buidel(%d) telt op tot %d" % [totaal, totaal])
