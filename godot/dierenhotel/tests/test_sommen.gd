extends Proef
## Every worked example of the frozen number core, straight from the specs.
## games-a.md §2, world.md §3.9, art-sound-rules.md §17.3.

func test_js_integer_semantiek() -> void:
	# The whole reason JsGetal exists: the dagRnd step multiply overflows 53
	# bits, so JavaScript rounds it before truncating.  A 64-bit integer port
	# gives 678745307 here; the browser gives 678745088.
	gelijk(JsGetal.to_uint32(float(2654448106) * 1103515245.0 + 12345.0), 678745088, "ToUint32 float pad")
	gelijk(JsGetal.u32(2654448106 * 1103515245 + 12345), 678745307, "integer pad (fout, ter vergelijking)")
	gelijk(JsGetal.imul(0xFFFFFFFF, 5), -5, "Math.imul(-1, 5)")
	gelijk(JsGetal.rond(-0.5), 0, "Math.round(-0.5) == 0")
	gelijk(JsGetal.rond(19.5), 20, "Math.round(19.5) == 20")
	# ToInt32 is the same bits as ToUint32, read signed — also past 2^53
	gelijk(JsGetal.to_int32(float(2654448106) * 1103515245.0 + 12345.0), 678745088,
		"ToInt32 op hetzelfde product")
	gelijk(JsGetal.to_int32(3000000000.0), -1294967296, "ToInt32(3e9)")
	gelijk(JsGetal.to_uint32(3000000000.0), 3000000000, "ToUint32(3e9)")
	gelijk(JsGetal.to_uint32(-1.5), 4294967295, "ToUint32(-1.5) kapt naar nul af")
	gelijk(JsGetal.i32(0x80000000), -2147483648, "de tekenbit van i32")

func test_dag_rnd() -> void:
	var r := Sommen.DagRnd.new(1)
	gelijk(r.stand(), 2654448106, "dagRnd(1) beginstand")
	gelijk(r.volgende(), 0.15803265571594238, "dagRnd(1) #1")
	gelijk(r.volgende(), 0.790381669998169, "dagRnd(1) #2")
	gelijk(r.volgende(), 0.21154141426086426, "dagRnd(1) #3")
	var r2 := Sommen.DagRnd.new(12345)
	gelijk(r2.stand(), 2703980706, "dagRnd(12345) beginstand")
	r2.volgende()
	gelijk(r2.stand(), 1301276672, "dagRnd(12345) stand na 1")

func test_zaadje() -> void:
	# seed = dag*7919 + N*131 + band*17 + ronde*8191 + 1, hier (1, 2, 3, 0)
	var z := Sommen.Zaadje.new(1 * 7919 + 2 * 131 + 3 * 17 + 0 * 8191 + 1)
	gelijk(z.volgende(), 0.4267871053889394, "zaadje #1")
	gelijk(z.volgende(), 0.04266549716703594, "zaadje #2")
	gelijk(z.volgende(), 0.02273993333801627, "zaadje #3")

func test_hash2() -> void:
	gelijk(Sommen.hash2(0, 0), 0, "hash2(0,0)")
	gelijk(Sommen.hash2(12, 8), 143, "hash2(12,8)")
	gelijk(Sommen.hash2(45, 78), 231, "hash2(45,78)")

func test_koekjes_som() -> void:
	var k := Sommen.koekjes_som(3, 5)
	gelijk(k["per"], 3, "koekjesSom(3,5).per")
	gelijk(k["rest"], 2, "koekjesSom(3,5).rest")
	gelijk(k["total"], 17, "koekjesSom(3,5).total")

func test_vergelijk() -> void:
	gelijk(Sommen.vergelijk(4, 3, 10), "meer", "12 > 10")
	gelijk(Sommen.vergelijk(2, 3, 10), "minder", "6 < 10")
	gelijk(Sommen.vergelijk(5, 2, 10), "precies", "10 == 10")

func test_deel() -> void:
	# games-a.md §2.3, the whole table
	for rij in [[3, 3, 1, 12, 4, 0], [2, 3, 2, 9, 4, 1], [5, 4, 3, 17, 3, 2],
			[6, 4, 6, 20, 3, 2], [7, 5, 5, 36, 5, 1]]:
		var d := Sommen.deel(rij[0], rij[1], rij[2])
		gelijk(d["T"], rij[3], "deel(%d,%d,%d).T" % [rij[0], rij[1], rij[2]])
		gelijk(d["k"], rij[4], "deel(%d,%d,%d).k" % [rij[0], rij[1], rij[2]])
		gelijk(d["r"], rij[5], "deel(%d,%d,%d).r" % [rij[0], rij[1], rij[2]])
	# world.md §3.9 worked example
	var w := Sommen.deel(5, 4, 2)
	gelijk("%d/%d/%d" % [w["k"], w["r"], w["T"]], "10/1/51", "deel(5,4,2)")

func test_tafel() -> void:
	var a := Sommen.tafel(4, 3, 5)
	gelijk("%d x %d = %d" % [a["a"], a["b"], a["uit"]], "3 x 5 = 15", "tafel(4,3,5)")
	var b := Sommen.tafel(3, 1, 3)
	gelijk("%d x %d = %d" % [b["a"], b["b"], b["uit"]], "1 x 7 = 7", "tafel(3,1,3)")
	var c := Sommen.tafel(5, 5, 7)
	gelijk("%d x %d = %d" % [c["a"], c["b"], c["uit"]], "3 x 3 = 9", "tafel(5,5,7)")
	# de laatste twee rijen van .fanout/scratch/games-a-worked-examples.txt
	var d := Sommen.tafel(3, 2, 2)
	gelijk("%d x %d = %d" % [d["a"], d["b"], d["uit"]], "1 x 9 = 9", "tafel(3,2,2)")
	var e := Sommen.tafel(4, 6, 6)
	gelijk("%d x %d = %d" % [e["a"], e["b"], e["uit"]], "1 x 5 = 5", "tafel(4,6,6)")

func test_geld() -> void:
	var g := Sommen.geld(5, 4)
	gelijk(g["prijs"], 2, "band 5 dag 4 prijs")
	gelijk(g["nachten"], 4, "band 5 dag 4 nachten")
	gelijk(g["totaal"], 8, "band 5 dag 4 totaal")
	gelijk(g["betaald"], 10, "band 5 dag 4 betaald")
	gelijk(g["wissel"], 2, "band 5 dag 4 wissel")

func test_klok() -> void:
	var k3 := Sommen.klok(3, 1)
	gelijk(k3["tekst"], "10 uur", "klok band 3 dag 1")
	var k4 := Sommen.klok(4, 1)
	gelijk("%d:%02d" % [k4["u"], k4["m"]], "10:45", "klok band 4 dag 1")
	var k5 := Sommen.klok(5, 1)
	gelijk("%d:%02d" % [k5["u"], k5["m"]], "10:57", "klok band 5 dag 1")

func test_band() -> void:
	gelijk(Sommen.band_van_n(3), 3, "N=3")
	gelijk(Sommen.band_van_n(6), 4, "N=6")
	gelijk(Sommen.band_van_n(7), 5, "N=7")

func test_munten() -> void:
	gelijk(str(Sommen.buidel(13)), "[5, 2, 2, 2, 1, 1]", "buidel(13)")
	gelijk(str(Sommen.splits(13)), "[10, 2, 1]", "splits(13)")

# --------------------------------------------------------- de planbord-solver

## games-a.md §2.7 + A1 §13 Q-X1-6: frozen, ported, deliberately not surfaced.
## Every number below was checked against `state.js` running in node.
func test_planbord_maakt_een_oplosbare_dag() -> void:
	gelijk(Sommen.CELLEN, 8, "de strook heeft acht vakjes")
	gelijk(Sommen.VASTE_AFSPRAKEN.size(), 4, "vier vaste afspraken")
	gelijk(Sommen.VASTE_AFSPRAKEN[0]["tekst"],
		"Dokter Els komt om 15:00 langs voor de controle. Dat blokje staat vast.",
		"de eerste vaste afspraak, letterlijk")
	gelijk(Sommen.VASTE_AFSPRAKEN[3]["cells"], 2, "de vierde afspraak duurt een half uur")
	for rij in [[1, 1, 0, 7, 6], [2, 2, 0, 25, 4], [3, 4, 0, 132, 2], [4, 3, 0, 48, 1],
			[6, 3, 0, 24, 1], [8, 6, 0, 120, 0]]:
		var wat := "planbord(dag %d, %d dieren)" % [rij[0], rij[1]]
		var p := Sommen.planbord(rij[0], _dieren().slice(0, rij[1]))
		gelijk(p["verzwakt"], rij[2], "%s: verzwakking" % wat)
		gelijk(p["oplossingen"], rij[3], "%s: aantal oplossingen" % wat)
		gelijk(p["vrijeVakjes"], rij[4], "%s: vrije vakjes" % wat)
		waar(Sommen.plan_fouten(p, p["oplossing"]).is_empty(),
			"%s: de gevonden oplossing breekt geen regel" % wat)

## The rules the solver has to honour, and the shape of a hard day.
func test_planbord_regels_en_fouten() -> void:
	var p := Sommen.maak_plan(6, _dieren().slice(0, 4), 0)
	var soorten: Array[String] = []
	for r in p["regels"]:
		soorten.append(str(r["soort"]))
	gelijk(str(soorten), '["vast", "vol", "na", "na"]',
		"dag 6 zonder verzwakking: een vaste afspraak, een klusje en twee ná-regels")
	gelijk(p["regels"][2]["a"], "b2_wolkje", "Wolkje moet in bad")
	gelijk(p["regels"][2]["b"], "b0_boef", "…ná de wandeling van Boef")
	gelijk(p["regels"][2]["tekst"],
		"Eerst de wandeling, dán het bad: Wolkjes bad moet ná de wandeling van Boef"
		+ " — anders is Wolkje meteen weer vies!",
		"de ordeningszin, letterlijk (met á en het echte kastlijntje)")
	# a `na` rule says: a starts only AFTER b has finished (b takes two cells)
	for rij in [[0, 0, 1], [0, 2, 1], [3, 0, 0], [2, 1, 1], [1, 1, 1]]:
		var stand := {"b2_wolkje": rij[0], "b0_boef": rij[1]}
		gelijk(Sommen.plan_fouten(p, stand).size(), rij[2],
			"planFouten met bad op %d en wandeling op %d" % [rij[0], rij[1]])
	# a block that has not been placed yet never counts as a mistake
	gelijk(Sommen.plan_fouten(p, {"b2_wolkje": 0}).size(), 0,
		"een blokje zonder plek telt niet mee")
	gelijk(Sommen.plan_oplossingen(p, 5)["aantal"], 5, "plan_oplossingen stopt bij het maximum")

func _dieren() -> Array[Dictionary]:
	return [
		{"id": "boef", "name": "Boef", "act": "Wandeling", "mins": 30},
		{"id": "muis", "name": "Muis", "act": "Spelen", "mins": 15},
		{"id": "wolkje", "name": "Wolkje", "act": "Bad", "mins": 15},
		{"id": "gerrit", "name": "Gerrit", "act": "Plonzen", "mins": 15},
		{"id": "pip", "name": "Pip", "act": "Wandeling", "mins": 30},
		{"id": "vlok", "name": "Vlok", "act": "Spelen", "mins": 15},
	]

# ------------------------------------------------------ de vierde generator

## The 31-bit LCG of zwembad/rooms: the same float64 trap as `dagRnd`, because
## `s * 1103515245` reaches 2.4e18 as well.  Bits checked against node.
func test_lcg31() -> void:
	var r := Sommen.Lcg31.new(1)
	gelijk(r.volgende(), 0.5138700783782965, "prng(1) #1")
	gelijk(r.volgende(), 0.17574131496983642, "prng(1) #2")
	gelijk(Sommen.Lcg31.new(0).stand(), 1, "zaad 0 wordt 1")
	# de eerste trek na het zaaien is degene die zwembad gebruikt
	gelijk(Sommen.Lcg31.new(43 * 977 + 30 * 131 + 0 * 17 + 0 * 7 + 1).volgende(),
		0.9550339542119922, "het zaad van de kaart 43/30")

## `hash` walks UTF-16 code units in JavaScript, so a character outside the BMP
## counts as two surrogates.  Values from world.js in node.
func test_hash_tekst_telt_utf16() -> void:
	gelijk(Sommen.hash_tekst(""), 2166136261, "de lege string is het FNV-zaad")
	gelijk(Sommen.hash_tekst("boef"), 3198978661, "hash('boef')")
	gelijk(Sommen.hash_tekst("kamer1/bed2"), 2268926008, "hash('kamer1/bed2')")
