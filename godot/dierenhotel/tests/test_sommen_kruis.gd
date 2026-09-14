extends Proef
## The Node-verified tables of games-a.md, games-b.md and world.md, as one
## regression net over the whole frozen core.
##
## HOW THIS WAS MADE, and why it may be trusted (A1 §1.1 F1).  A harness in
## `.fanout/scratch/w5/` lifts the generator functions VERBATIM out of
## `demos/dierenhotel/**.js` (by line range, no retyping), runs them in node and
## writes every case to `ref.json`.  The same sweep runs here in GDScript and
## was diffed against that file: **23042 cases, 0 differences**, including the
## exact double bit patterns of all four PRNGs.  The numbers in `VERWACHT` below
## are the fingerprints of the JAVASCRIPT rows, computed with the same FNV-1a
## that `Sommen.hash_tekst` is — so this test compares the port against the
## original, not against itself.  Reproduce with:
##
##     python3 .fanout/scratch/w5/bouw_harnas.py && node .fanout/scratch/w5/dump.js > ref.json
##     python3 .fanout/scratch/w5/vergelijk.py
##
## A failure here says "some generator changed".  `test_sommen.gd` and
## `test_sommen_spellen.gd` hold the readable worked examples that say WHICH.
## `eerste`/`laatste` are the first and last row of the sweep, so a failure
## still shows a concrete case.

const VERWACHT := {
	"band_van_n": {"n": 12, "h": 3422196137,
		"eerste": "1=3",
		"laatste": "12=5"},
	"bedden_opdracht": {"n": 6912, "h": 3317951772,
		"eerste": "3,1,1,1,3=1x1=1",
		"laatste": "5,12,12,8,4=5x1=5"},
	"bedden_wand": {"n": 15, "h": 2552589677,
		"eerste": "3,0=0/0",
		"laatste": "5,4=3/2"},
	"buidel": {"n": 41, "h": 1768854321,
		"eerste": "0=[]",
		"laatste": "40=[10,10,10,5,2,2,1]"},
	"dag_rnd": {"n": 6, "h": 1526551805,
		"eerste": "1=[000000006a3ac43f,00000080ce4ae93f,00000000ca13cb3f,0000008046bee23f,000000800a7feb3f]",
		"laatste": "4294967295=[000000008886ba3f,00000000062ede3f,000000c080d1df3f,000000002ff7ea3f,000000002444c63f]"},
	"deel": {"n": 432, "h": 501595674,
		"eerste": "1,3,1=4/4/0/3",
		"laatste": "12,5,12=12/1/0/5"},
	"geld": {"n": 72, "h": 2652444319,
		"eerste": "3,1=2/2/4/4/0",
		"laatste": "5,12,3,5=3/5/15/20/5"},
	"hash2": {"n": 324, "h": 2490518646,
		"eerste": "-20,-20=141",
		"laatste": "58,57=63"},
	"hash_tekst": {"n": 8, "h": 3404865863,
		"eerste": "=2166136261",
		"laatste": "ABCDEFGHIJKLMNOPQRSTUVWXYZ=2324225410"},
	"hinkel_beurt": {"n": 432, "h": 765383834,
		"eerste": "1,3,1=1>3/1/2/2/10/1",
		"laatste": "12,5,12=5>85/8/10/80/100/5"},
	"hinkel_keuzes": {"n": 156, "h": 1567326636,
		"eerste": "1,0=[1,2,3,4]",
		"laatste": "12,12=[12,13,14,15]"},
	"hinkel_maten": {"n": 300, "h": 1329031794,
		"eerste": "3,1=[1]/[1]",
		"laatste": "5,100=[10]/[10]"},
	"hinkel_telpad": {"n": 974, "h": 3318463448,
		"eerste": "0>0/1=.",
		"laatste": "100>100/10=."},
	"klok": {"n": 36, "h": 53109114,
		"eerste": "3,1=10/0/60/10 uur/-",
		"laatste": "5,12=11/19/5/11:19/20"},
	"koekjes_som": {"n": 144, "h": 2647395251,
		"eerste": "1,1=4/0/4",
		"laatste": "12,12=2/2/26"},
	"kraam_klachten": {"n": 1, "h": 890022063,
		"eerste": "0",
		"laatste": "0"},
	"kraam_opzet": {"n": 432, "h": 2045058365,
		"eerste": "1,3,1=[4,3,5]/[bal]/5/5/0/5/-/[1,2]/0",
		"laatste": "12,5,12=[4,3,5,12]/[hoedje,sjaaltje]/7/10/3/3/€10 − €7 =|3/[1,2,5]/0"},
	"kraam_splitsmet": {"n": 21, "h": 1122844873,
		"eerste": "0=[]/[]",
		"laatste": "20=[5,5,5,5]/[2,2,2,2,2,2,2,2,2,2]"},
	"kraam_telvanaf": {"n": 273, "h": 975297217,
		"eerste": "0,0=0.",
		"laatste": "20,12=20 … 21 … 22 … 23 … 24 … 25 … 26 … 27 … 28 … 29 … 30 … 31 … 32."},
	"meubels_bandregels": {"n": 4, "h": 3245094029,
		"eerste": "3=1/10",
		"laatste": "6=2/20"},
	"meubels_cap": {"n": 858, "h": 2733083362,
		"eerste": "0,0,3=0",
		"laatste": "25,30,5=25"},
	"meubels_versiering": {"n": 5, "h": 2467596124,
		"eerste": "0=vlag/🎉/vlaggetjes/1",
		"laatste": "4=ster/⭐/sterrensticker/1"},
	"meubels_winkel": {"n": 6, "h": 1711053053,
		"eerste": "0=plant/🪴/plant/1/",
		"laatste": "5=badkuip/🛁/badkuip/8/"},
	"mulberry32": {"n": 6, "h": 3249028942,
		"eerste": "0=[000080182d0dd13f,00000000379c353f,000000842d94cc3f,00000082c0b6c23f,000000f5b2e8dd3f]",
		"laatste": "2166136261=[00008086508fe33f,000040e9e695df3f,000020d5cfc4e83f,00008049e562da3f,0000e0ce14fee93f]"},
	"planbord": {"n": 48, "h": 1929462835,
		"eerste": "1,1=0/7/6/{\"b0_boef\":0} // b0_boef:Wandeling:30:2:- // ",
		"laatste": "8,6=0/120/0/{\"vast_Voer\":6,\"b0_boef\":0,\"b1_muis\":1,\"b2_wolkje\":2,\"b3_gerrit\":3,\"b4_pip\":4,\"b5_vlok\":7} // b0_boef:Wandeling:15:1:-;b1_muis:Spelen:15:1:-;b2_wolkje:Bad:15:1:-;b3_gerrit:Plonzen:15:1:-;b4_pip:Wandeling:30:2:-;b5_vlok:Spelen:15:1:-;vast_Voer:Voer:15:1:v6 // vast:📦:Om 15:30 wordt het nieuwe voer gebracht. Dat blokje staat vast.|na(b2_wolkje>b0_boef):🛁:Eerst de wandeling, dán het bad: Wolkjes bad moet ná de wandeling van Boef — anders is Wolkje meteen weer vies!|na(b4_pip>b1_muis):⏱️:En nog iets: Pips wandeling kan pas ná het spelen van Muis."},
	"planbord_fouten": {"n": 15, "h": 2679747444,
		"eerste": "blok b0_boef cells 2",
		"laatste": "1/1=1"},
	"planbord_maakplan": {"n": 288, "h": 2571036721,
		"eerste": "1,1,0=b0_boef:Wandeling:30:2:- //  // 7 // {\"b0_boef\":0}",
		"laatste": "8,6,5=b0_boef:Wandeling:30:2:-;b1_muis:Spelen:15:1:-;b2_wolkje:Bad:15:1:-;b3_gerrit:Plonzen:15:1:-;b4_pip:Wandeling:30:2:-;b5_vlok:Spelen:15:1:- //  // 400 // {\"b0_boef\":0,\"b1_muis\":2,\"b2_wolkje\":3,\"b3_gerrit\":4,\"b4_pip\":5,\"b5_vlok\":7}"},
	"sleutels_opdracht": {"n": 2592, "h": 863140870,
		"eerste": "1,3,1,1,0=4/telrij/1+1x4:[1]/[2@0:1]/ok",
		"laatste": "12,5,12,3,1=4/kamers/111+1x4(verdieping 1):[2];211+1x4(verdieping 2):[1];115+1x4(verdieping 1):[2]/[113@0:2,212@1:1,117@2:2]/ok"},
	"splits": {"n": 41, "h": 73820814,
		"eerste": "0=[]",
		"laatste": "40=[10,10,10,10]"},
	"tafel": {"n": 432, "h": 4085421438,
		"eerste": "3,1,1=5x1=5/3/20",
		"laatste": "5,12,12=5x9=45/5/100"},
	"tobbe_herschaal": {"n": 111, "h": 4182921333,
		"eerste": "0,1=0/0",
		"laatste": "36,3=12/0"},
	"tobbe_recept": {"n": 432, "h": 1389320143,
		"eerste": "1,3,1=eerlijk/1/2/2/2/2/1/0",
		"laatste": "12,5,12=eerlijk/10/2/20/20/3/6/2"},
	"vaste_afspraken": {"n": 4, "h": 672379050,
		"eerste": "0=Dierenarts/dokter Els/4/1/Dokter Els komt om 15:00 langs voor de controle. Dat blokje staat vast.",
		"laatste": "3=Dierenarts/dokter Els/3/2/Dokter Els komt om 14:45 en blijft een half uur. Dat blokje staat vast."},
	"vergelijk": {"n": 324, "h": 1718958887,
		"eerste": "1,1,0=meer",
		"laatste": "6,6,24=meer"},
	"voerkar_hand": {"n": 3, "h": 1481824858,
		"eerste": "1=2",
		"laatste": "5=1"},
	"voerkar_somregel": {"n": 1056, "h": 728254933,
		"eerste": "3,0,1,0=",
		"laatste": "5,40,8,3="},
	"was_kiest": {"n": 432, "h": 759215291,
		"eerste": "1,3,1=2/1/3",
		"laatste": "12,5,12=2/0/24"},
	"was_recept": {"n": 432, "h": 641608456,
		"eerste": "1,3,1=2/1/3/1/2/[1,2]/[1,0,1]",
		"laatste": "12,5,12=2/0/24/2/4/[2,5,4,1]/[2,3,0,1,1,2,1,0,2,2,1,1]"},
	"was_soorten": {"n": 90, "h": 781495129,
		"eerste": "3,1=2",
		"laatste": "5,30=4"},
	"was_verdeel": {"n": 120, "h": 3278627724,
		"eerste": "1,1=[1]",
		"laatste": "30,4=[6,7,8,9]"},
	"wekker_afstand": {"n": 432, "h": 4083014735,
		"eerste": "3,1,1=2/0/0/120",
		"laatste": "5,12,12=3/0/0/180"},
	"wekker_beurt": {"n": 1296, "h": 2890706338,
		"eerste": "3,1,1,0=10:0/8:0/zet/0/[]",
		"laatste": "5,12,12,2=1:30/10:30/zet/0/[]"},
	"wekker_doeltijd": {"n": 108, "h": 1680031613,
		"eerste": "3,1,0=10:0",
		"laatste": "5,12,2=1:30"},
	"wekker_duurkeuzes": {"n": 480, "h": 3642271421,
		"eerste": "1,1,1=[3,1,12,2]",
		"laatste": "12,5,8=[5,6,4,7]"},
	"wekker_minuten": {"n": 144, "h": 1465553883,
		"eerste": "1:0=60/{\"u\":1,\"m\":30}",
		"laatste": "12:55=55/{\"u\":1,\"m\":25}"},
	"wekker_tijdwoord": {"n": 720, "h": 2453045053,
		"eerste": "1:0=1 uur",
		"laatste": "12:59=1 voor 1"},
	"zaadje": {"n": 6, "h": 2280994025,
		"eerste": "1=[000000b62c44ce3f,0000c07621a2d73f,0000c02fc022e03f,0000a058678ee63f,000000c0dae0a93f]",
		"laatste": "0=[000000b62c44ce3f,0000c07621a2d73f,0000c02fc022e03f,0000a058678ee63f,000000c0dae0a93f]"},
	# 2026-09-14: lanes under the window walk with the day (owner: "altijd 8
	# meter"); the fingerprint is of the Godot rule, no longer of the JavaScript
	"zwembad_baan": {"n": 432, "h": 3648792083,
		"eerste": "1,3,1=16/10/5/2/20",
		"laatste": "12,5,12=80/40/10/3/100"},
	"zwembad_keuzes": {"n": 160, "h": 969817161,
		"eerste": "43,30,0,4,0=[43,13,20,30]/30/3/43",
		"laatste": "8,10,8,3,3=[8,10,0,1]/0/2/0"},
	"zwembad_prng": {"n": 4, "h": 2129034377,
		"eerste": "1=[3fe3a0a99f71e03f,62fd2c00b17ec63f,1bbf27408ddfc33f,a9712580d4b8c23f,ab712460d538d23f]",
		"laatste": "2147483647=[e2393e00f11cdf3f,b5c036805a60eb3f,48992900a4ccb43f,d26834006934aa3f,efc92a60f764e53f]"},
	"zwembad_slag": {"n": 1370, "h": 2459403040,
		"eerste": "43,30,0,0=kort/0/30/43",
		"laatste": "80,40,80,82=ver/0/0/0"},
}

# ------------------------------------------------------------------ de toets

func _keur(naam: String, rijen: Array) -> void:
	var w: Dictionary = VERWACHT[naam]
	gelijk(rijen.size(), w["n"], "%s: aantal rijen" % naam)
	if rijen.is_empty():
		return
	gelijk(rijen[0], w["eerste"], "%s: eerste rij" % naam)
	gelijk(rijen[rijen.size() - 1], w["laatste"], "%s: laatste rij" % naam)
	gelijk(Sommen.hash_tekst("\n".join(PackedStringArray(rijen))), w["h"],
		"%s: vingerafdruk van de hele tabel" % naam)

func _lijst(a) -> String:
	var d: Array = []
	for v in a:
		d.append(str(v))
	return ",".join(PackedStringArray(d))

func _bits(v: float) -> String:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, v)
	return b.hex_encode()

# --------------------------------------------------------- de bevroren kern

func test_kruis_koekjes_deel_tafel() -> void:
	var r: Array[String] = []
	for d in range(1, 13):
		for n in range(1, 13):
			var ks := Sommen.koekjes_som(d, n)
			r.append("%d,%d=%d/%d/%d" % [d, n, ks["per"], ks["rest"], ks["total"]])
	_keur("koekjes_som", r)
	r = []
	for n in range(1, 13):
		for b in range(3, 6):
			for d in range(1, 13):
				var q := Sommen.deel(n, b, d)
				r.append("%d,%d,%d=%d/%d/%d/%d" % [n, b, d, q["T"], q["k"], q["r"], q["band"]])
	_keur("deel", r)
	r = []
	for b in range(3, 6):
		for d in range(1, 13):
			for n in range(1, 13):
				var t := Sommen.tafel(b, d, n)
				r.append("%d,%d,%d=%dx%d=%d/%d/%d" % [b, d, n, t["a"], t["b"], t["uit"],
					t["band"], t["plafond"]])
	_keur("tafel", r)

func test_kruis_geld_klok_vergelijk_band() -> void:
	var r: Array[String] = []
	for b in range(3, 6):
		for d in range(1, 13):
			var g := Sommen.geld(b, d)
			r.append("%d,%d=%d/%d/%d/%d/%d" % [b, d, g["nachten"], g["prijs"], g["totaal"],
				g["betaald"], g["wissel"]])
			var g2 := Sommen.geld(b, d, 3, 5)
			r.append("%d,%d,3,5=%d/%d/%d/%d/%d" % [b, d, g2["nachten"], g2["prijs"],
				g2["totaal"], g2["betaald"], g2["wissel"]])
	_keur("geld", r)
	r = []
	for b in range(3, 6):
		for d in range(1, 13):
			var c := Sommen.klok(b, d)
			r.append("%d,%d=%d/%d/%d/%s/%s" % [b, d, c["u"], c["m"], c["stap"], c["tekst"],
				str(c["duur"]) if c.has("duur") else "-"])
	_keur("klok", r)
	r = []
	for d in range(1, 7):
		for n in range(1, 7):
			for i in range(0, 25, 3):
				r.append("%d,%d,%d=%s" % [d, n, i, Sommen.vergelijk(d, n, i)])
	_keur("vergelijk", r)
	r = []
	for n in range(1, 13):
		r.append("%d=%d" % [n, Sommen.band_van_n(n)])
	_keur("band_van_n", r)

func test_kruis_munten_en_hashes() -> void:
	var r: Array[String] = []
	for i in range(0, 41):
		r.append("%d=[%s]" % [i, _lijst(Sommen.buidel(i))])
	_keur("buidel", r)
	r = []
	for i in range(0, 41):
		r.append("%d=[%s]" % [i, _lijst(Sommen.splits(i))])
	_keur("splits", r)
	r = []
	for i in range(-20, 61, 3):
		for j in range(-20, 61, 7):
			r.append("%d,%d=%d" % [i, j, Sommen.hash2(i, j)])
	_keur("hash2", r)
	r = []
	for s in ["", "a", "boef", "muis", "Wolkje", "gerrit-1", "kamer1/bed2",
			"ABCDEFGHIJKLMNOPQRSTUVWXYZ"]:
		r.append("%s=%d" % [s, Sommen.hash_tekst(s)])
	_keur("hash_tekst", r)

## The four generators, compared on the exact bits of the doubles they return.
## `dag_rnd` is the one that proves the float64 path of A1 §2.1.
func test_kruis_generatoren_bit_voor_bit() -> void:
	var r: Array[String] = []
	for z in [1, 2, 12345, 7919, 99991, 4294967295]:
		var f := Sommen.DagRnd.new(z)
		var l: Array[String] = []
		for i in 5:
			l.append(_bits(f.volgende()))
		r.append("%d=[%s]" % [z, _lijst(l)])
	_keur("dag_rnd", r)
	r = []
	for z in [1, 2, 8051, 1046529, 4294967295, 0]:
		var f := Sommen.Zaadje.new(z)
		var l: Array[String] = []
		for i in 5:
			l.append(_bits(f.volgende()))
		r.append("%d=[%s]" % [z, _lijst(l)])
	_keur("zaadje", r)
	r = []
	for z in [0, 1, 3075, 5297, 4294967295, 2166136261]:
		var f := Sommen.Prng.new(z)
		var l: Array[String] = []
		for i in 5:
			l.append(_bits(f.volgende()))
		r.append("%d=[%s]" % [z, _lijst(l)])
	_keur("mulberry32", r)
	r = []
	for z in [1, 977, 45942, 2147483647]:
		var f := Sommen.Lcg31.new(z)
		var l: Array[String] = []
		for i in 5:
			l.append(_bits(f.volgende()))
		r.append("%d=[%s]" % [z, _lijst(l)])
	_keur("zwembad_prng", r)

# ------------------------------------------------------ de spelgeneratoren

func test_kruis_zwembad() -> void:
	var r: Array[String] = []
	for n in range(1, 13):
		for b in range(3, 6):
			for d in range(1, 13):
				var ba := Sommen.Zwembad.baan(n, b, d)
				r.append("%d,%d,%d=%d/%d/%d/%d/%d" % [n, b, d, ba["L"], ba["M"], ba["stap"],
					ba["r"], ba["plafond"]])
	_keur("zwembad_baan", r)
	r = []
	for lm in [[43, 30], [14, 10], [76, 40], [46, 30], [20, 10], [80, 40], [31, 30], [8, 10]]:
		var p := 0
		while p <= lm[0]:
			for leg in range(0, 4):
				var band: int = 3 if lm[1] == 10 else (5 if lm[0] > 50 else 4)
				var q := Sommen.Zwembad.keuze_getallen(lm[0], lm[1], p, band, leg)
				r.append("%d,%d,%d,%d,%d=[%s]/%d/%d/%d" % [lm[0], lm[1], p, band, leg,
					_lijst(q["lijst"]), q["juist"], q["plek"], q["rest"]])
			p += maxi(1, lm[0] / 4)
	_keur("zwembad_keuzes", r)
	r = []
	for lm in [[43, 30], [14, 10], [76, 40], [46, 30], [80, 40]]:
		var p := 0
		while p <= lm[0]:
			for n in range(0, lm[0] + 3):
				var q := Sommen.Zwembad.slag(lm[0], lm[1], p, n)
				r.append("%d,%d,%d,%d=%s/%d/%d/%d" % [lm[0], lm[1], p, n, q["soort"],
					q["meters"], q["juist"], q["rest"]])
			p += maxi(1, lm[0] / 4)
	_keur("zwembad_slag", r)

func test_kruis_wekker() -> void:
	var r: Array[String] = []
	for i in range(1, 13):
		for j in range(0, 60):
			r.append("%d:%d=%s" % [i, j, Sommen.Wekker.tijd_woord(i, j)])
	_keur("wekker_tijdwoord", r)
	r = []
	for b in range(3, 6):
		for d in range(1, 13):
			for i in range(0, 3):
				var t := Sommen.Wekker.doel_tijd(b, d, i)
				r.append("%d,%d,%d=%d:%d" % [b, d, i, t["u"], t["m"]])
	_keur("wekker_doeltijd", r)
	r = []
	for b in range(3, 6):
		for n in range(1, 13):
			for d in range(1, 13):
				var a := Sommen.Wekker.afstand(b, n, d)
				r.append("%d,%d,%d=%d/%d/%d/%d" % [b, n, d, a["uur"], a["kwart"], a["vijf"],
					a["min"]])
	_keur("wekker_afstand", r)
	r = []
	for i in range(1, 13):
		for j in range(1, 6):
			for d in range(1, 9):
				r.append("%d,%d,%d=[%s]" % [i, j, d, _lijst(Sommen.Wekker.duur_keuzes(i, j, d))])
	_keur("wekker_duurkeuzes", r)
	r = []
	for i in range(1, 13):
		for j in range(0, 60, 5):
			var m := Sommen.Wekker.in_min(i, j)
			var v := Sommen.Wekker.van_min(m + 30)
			r.append('%d:%d=%d/{"u":%d,"m":%d}' % [i, j, m, v["u"], v["m"]])
	_keur("wekker_minuten", r)
	r = []
	for b in range(3, 6):
		for n in range(1, 13):
			for d in range(1, 13):
				for i in range(0, 3):
					var q := Sommen.Wekker.beurt(b, n, d, i)
					r.append("%d,%d,%d,%d=%d:%d/%d:%d/%s/%d/[%s]" % [b, n, d, i, q["doelU"],
						q["doelM"], q["u"], q["m"], q["stap"], q["duur"], _lijst(q["keuzes"])])
	_keur("wekker_beurt", r)

func test_kruis_hinkel() -> void:
	var r: Array[String] = []
	for n in range(1, 13):
		for b in range(3, 6):
			for d in range(1, 13):
				var be := Sommen.Hinkel.beurt(n, b, d)
				r.append("%d,%d,%d=%d>%d/%d/%d/%d/%d/%d" % [n, b, d, be["s"], be["doel"],
					be["sprong"], be["n"], be["afstand"], be["E"], be["stap"]])
	_keur("hinkel_beurt", r)
	r = []
	for b in range(3, 6):
		for i in range(1, 101):
			r.append("%d,%d=[%s]/[%s]" % [b, i, _lijst(Sommen.Hinkel.maten_voor(i, b)),
				_lijst(Sommen.Hinkel.maten(i, b))])
	_keur("hinkel_maten", r)
	r = []
	for n in range(1, 13):
		for i in range(0, 13):
			r.append("%d,%d=[%s]" % [n, i, _lijst(Sommen.Hinkel.keuze_getallen(n, i))])
	_keur("hinkel_keuzes", r)
	r = []
	for i in range(0, 101, 5):
		for j in range(0, 101, 10):
			for k in range(1, 11):
				if absi(j - i) % k == 0:
					r.append("%d>%d/%d=%s" % [i, j, k, Sommen.Hinkel.tel_pad(i, j, k)])
	_keur("hinkel_telpad", r)

func test_kruis_was() -> void:
	var r: Array[String] = []
	for n in range(1, 13):
		for b in range(3, 6):
			for d in range(1, 13):
				var t := Sommen.Was.kies_t(n, b, d)
				r.append("%d,%d,%d=%d/%d/%d" % [n, b, d, t["k"], t["r"], t["T"]])
	_keur("was_kiest", r)
	r = []
	for i in range(1, 31):
		for j in range(1, 5):
			r.append("%d,%d=[%s]" % [i, j, _lijst(Sommen.Was.verdeel(i, j))])
	_keur("was_verdeel", r)
	r = []
	for b in range(3, 6):
		for i in range(1, 31):
			r.append("%d,%d=%d" % [b, i, Sommen.Was.soorten_voor(b, i)])
	_keur("was_soorten", r)
	r = []
	for n in range(1, 13):
		for b in range(3, 6):
			for d in range(1, 13):
				var rc := Sommen.Was.recept(n, b, d)
				r.append("%d,%d,%d=%d/%d/%d/%d/%d/[%s]/[%s]" % [n, b, d, rc["k"], rc["r"],
					rc["T"], rc["per"], rc["m"], _lijst(rc["blok"]), _lijst(rc["rij"])])
	_keur("was_recept", r)

## The sweep games-b.md §5.3 calls out by name: band 3–5 × N 1…12 × dag 1…12 =
## 432 stalls, and `keuring()` may not have a single complaint about any of them.
func test_kruis_kraam_432_zonder_klacht() -> void:
	var r: Array[String] = []
	var klachten := 0
	for n in range(1, 13):
		for b in range(3, 6):
			for d in range(1, 13):
				var o := Sommen.Kraam.opzet(n, b, d)
				var f := Sommen.Kraam.keuring(o)
				klachten += f.size()
				if not f.is_empty():
					fout("kraam N=%d band=%d dag=%d: %s" % [n, b, d, ", ".join(f)])
				var prijzen: Array = []
				for w in o["waren"]:
					prijzen.append(w["prijs"])
				var vraag: Dictionary = o["vraag"]
				r.append("%d,%d,%d=[%s]/[%s]/%d/%d/%d/%d/%s/[%s]/%d" % [n, b, d,
					_lijst(prijzen), _lijst(o["keus"]), o["kosten"], o["betaald"],
					o["wissel"], o["doel"],
					("%s|%d" % [vraag["som"], vraag["goed"]]) if not vraag.is_empty() else "-",
					_lijst(o["munten"]), f.size()])
	gelijk(r.size(), 432, "kraam: 3 banden x 12 N x 12 dagen")
	gelijk(klachten, 0, "kraam: klachten over de hele veeg")
	_keur("kraam_opzet", r)
	_keur("kraam_klachten", [str(klachten)])
	r = []
	for i in range(0, 21):
		r.append("%d=[%s]/[%s]" % [i, _lijst(Sommen.Kraam.splits_met(i, [5, 2, 1])),
			_lijst(Sommen.Kraam.splits_met(i, [1, 2]))])
	_keur("kraam_splitsmet", r)
	r = []
	for i in range(0, 21):
		for j in range(0, 13):
			r.append("%d,%d=%s" % [i, j, Sommen.Kraam.tel_vanaf(i, j)])
	_keur("kraam_telvanaf", r)

func test_kruis_tobbe_sleutels_bedden() -> void:
	var r: Array[String] = []
	for n in range(1, 13):
		for b in range(3, 6):
			for d in range(1, 13):
				var tb := Sommen.Tobbe.recept(n, b, d)
				r.append("%d,%d,%d=%s/%d/%d/%d/%d/%d/%d/%d" % [n, b, d, tb["soort"], tb["n0"],
					tb["perDier"], tb["basis"], tb["T"], tb["M"], tb["per"], tb["rest"]])
	_keur("tobbe_recept", r)
	var gasten: Array[Dictionary] = [
		{"id": "g1", "naam": "Boef", "soort": "puppy"},
		{"id": "g2", "naam": "Muis", "soort": "poes"},
		{"id": "g3", "naam": "Wolkje", "soort": "konijn"},
	]
	r = []
	for n in range(1, 13):
		for b in range(3, 6):
			for d in range(1, 13):
				for g in range(1, 4):
					for ro in range(0, 2):
						var op := Sommen.Sleutels.maak_opdracht(n, b, d, gasten.slice(0, g), ro)
						var ctrl := Sommen.Sleutels.controleer(op)
						var borden: Array[String] = []
						for bo in op["borden"]:
							borden.append("%d+%dx%d%s:[%s]" % [bo["van"], bo["stap"], bo["n"],
								("(%s)" % bo["label"]) if str(bo["label"]) != "" else "",
								_lijst(bo["blanco"])])
						var sl: Array[String] = []
						for s in op["sleutels"]:
							sl.append("%d@%d:%d" % [s["nummer"], s["bord"], s["haak"]])
						r.append("%d,%d,%d,%d,%d=%d/%s/%s/[%s]/%s" % [n, b, d, g, ro, op["H"],
							op["variant"], ";".join(PackedStringArray(borden)),
							_lijst(sl), "ok" if ctrl["ok"] else "|".join(ctrl["fout"])])
	_keur("sleutels_opdracht", r)
	r = []
	for b in range(3, 6):
		for d in range(1, 13):
			for n in range(1, 13):
				for cap in range(1, 9):
					for st in range(3, 5):
						var od := Sommen.Bedden.opdracht(b, d, n, cap, st)
						r.append("%d,%d,%d,%d,%d=%dx%d=%d" % [b, d, n, cap, st,
							od["perRij"], od["rijen"], od["doel"]])
	_keur("bedden_opdracht", r)
	r = []
	for b in range(3, 6):
		for i in range(0, 5):
			var w := Sommen.Bedden.wand(b, i)
			r.append("%d,%d=%d/%d" % [b, i, w, Sommen.Bedden.volgende_wand(w, i) if w != 0 else 0])
	_keur("bedden_wand", r)
	r = []
	for i in range(0, 37):
		for j in range(1, 4):
			var h := Sommen.Tobbe.herschaal(i, j)
			r.append("%d,%d=%d/%d" % [i, j, h["per"], h["rest"]])
	_keur("tobbe_herschaal", r)
	r = []
	for b in range(3, 7):
		r.append("%d=%d/%d" % [b, Sommen.Meubels.max_lijst(b), Sommen.Meubels.buidel_max(b)])
	_keur("meubels_bandregels", r)
	r = []
	for i in range(0, 26):
		for j in range(0, 31, 3):
			for b in range(3, 6):
				r.append("%d,%d,%d=%d" % [i, j, b, Sommen.Meubels.buidel_cap(i, j, b)])
	_keur("meubels_cap", r)
	r = []
	for ix in Sommen.Meubels.WINKEL.size():
		var w: Dictionary = Sommen.Meubels.WINKEL[ix]
		r.append("%d=%s/%s/%s/%d/%s" % [ix, w["type"], w["icoon"], w["naam"], w["prijs"], w["plus"]])
	_keur("meubels_winkel", r)
	r = []
	for ix in Sommen.Meubels.VERSIERING.size():
		var w: Dictionary = Sommen.Meubels.VERSIERING[ix]
		r.append("%d=%s/%s/%s/%d" % [ix, w["sleutel"], w["icoon"], w["naam"], w["ster"]])
	_keur("meubels_versiering", r)
	r = []
	for b in range(3, 6):
		for i in range(0, 41, 4):
			for n in range(1, 9):
				for j in range(0, 4):
					r.append("%d,%d,%d,%d=%s" % [b, i, n, j, Sommen.Voerkar.som_regel(b, i, n, j)])
	_keur("voerkar_somregel", r)
	r = []
	for h in Sommen.Voerkar.HAND:
		r.append("%d=%d" % [h, Sommen.Voerkar.volgende_hand(h)])
	_keur("voerkar_hand", r)

# ----------------------------------------------------------- de planbord-solver

func _dieren() -> Array[Dictionary]:
	return [
		{"id": "boef", "name": "Boef", "act": "Wandeling", "mins": 30},
		{"id": "muis", "name": "Muis", "act": "Spelen", "mins": 15},
		{"id": "wolkje", "name": "Wolkje", "act": "Bad", "mins": 15},
		{"id": "gerrit", "name": "Gerrit", "act": "Plonzen", "mins": 15},
		{"id": "pip", "name": "Pip", "act": "Wandeling", "mins": 30},
		{"id": "vlok", "name": "Vlok", "act": "Spelen", "mins": 15},
	]

func _plan_regel(p: Dictionary) -> String:
	var bl: Array[String] = []
	for b in p["blokken"]:
		bl.append("%s:%s:%d:%d:%s" % [b["id"], b["act"], b["mins"], b["cells"],
			("v%d" % b["at"]) if bool(b["vast"]) else "-"])
	var rg: Array[String] = []
	for q in p["regels"]:
		rg.append("%s%s:%s:%s" % [q["soort"],
			("(%s>%s)" % [q["a"], q["b"]]) if q.has("a") else "",
			str(q.get("emoji", "")), str(q.get("tekst", ""))])
	return ";".join(PackedStringArray(bl)) + " // " + "|".join(PackedStringArray(rg))

func _stand_json(stand: Dictionary, gevonden: bool) -> String:
	if not gevonden:
		return "null"
	var d: Array[String] = []
	for k in stand:
		d.append('"%s":%d' % [k, int(stand[k])])
	return "{" + ",".join(PackedStringArray(d)) + "}"

func test_kruis_planbord() -> void:
	var r: Array[String] = []
	for d in range(1, 9):
		for n in range(1, 7):
			for vz in range(0, 6):
				var pl := Sommen.maak_plan(d, _dieren().slice(0, n), vz)
				var opl := Sommen.plan_oplossingen(pl, 400)
				r.append("%d,%d,%d=%s // %d // %s" % [d, n, vz, _plan_regel(pl), opl["aantal"],
					_stand_json(opl["eerste"], int(opl["aantal"]) > 0)])
	_keur("planbord_maakplan", r)
	r = []
	for d in range(1, 9):
		for n in range(1, 7):
			var pb := Sommen.planbord(d, _dieren().slice(0, n))
			r.append("%d,%d=%d/%d/%d/%s // %s" % [d, n, pb["verzwakt"], pb["oplossingen"],
				pb["vrijeVakjes"], _stand_json(pb.get("oplossing", {}), pb.has("oplossing")),
				_plan_regel(pb)])
	_keur("planbord", r)
	r = []
	for i in Sommen.VASTE_AFSPRAKEN.size():
		var a: Dictionary = Sommen.VASTE_AFSPRAKEN[i]
		r.append("%d=%s/%s/%d/%d/%s" % [i, a["act"], a["name"], a["at"], a["cells"], a["tekst"]])
	_keur("vaste_afspraken", r)
	r = []
	var pl_f := Sommen.maak_plan(6, _dieren().slice(0, 4), 0)
	for b3 in pl_f["blokken"]:
		r.append("blok %s cells %d" % [b3["id"], b3["cells"]])
	for q in pl_f["regels"]:
		r.append("regel %s %s %s" % [q["soort"], str(q.get("a", "")), str(q.get("b", ""))])
	var nas: Array = []
	for q in pl_f["regels"]:
		if q["soort"] == "na":
			nas.append(q)
	for st in [[0, 0], [0, 2], [3, 0], [2, 1], [1, 1]]:
		if not nas.is_empty():
			var stand := {}
			stand[nas[0]["a"]] = st[0]
			stand[nas[0]["b"]] = st[1]
			r.append("%d/%d=%d" % [st[0], st[1], Sommen.plan_fouten(pl_f, stand).size()])
	_keur("planbord_fouten", r)
