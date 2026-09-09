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
