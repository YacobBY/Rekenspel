extends Proef
## Room ambience (review plan 2026-09-14, pillar 1): a looping buffer per kind
## of room, far under the master gain, silent for a quiet room, and never one
## of the frozen 18.

func test_elke_sfeer_is_een_zachte_naadloze_lus() -> void:
	var gezien := {}
	for kamer in Snd.SFEER.keys():
		var naam := Snd.sfeer_naam(str(kamer))
		waar(not naam.is_empty(), "%s heeft een sfeer" % kamer)
		if gezien.has(naam):
			continue
		gezien[naam] = true
		var buf := Snd.sfeer_monster(naam)
		gelijk(buf.size(), int(Snd.SFEER_DUUR * Snd.SR), "%s: een lus van %.0f s" % [naam, Snd.SFEER_DUUR])
		var top := 0.0
		var energie := 0.0
		for v in buf:
			top = maxf(top, absf(v))
			energie += v * v
		waar(top > 0.001, "%s klinkt (piek %.4f)" % [naam, top])
		waar(top <= Snd.MEESTER * Snd.SFEER_TOP + 0.001,
			"%s blijft onder een derde van de meester (piek %.4f)" % [naam, top])
		waar(energie > 0.0, "%s heeft energie" % naam)
		var stream := Snd.sfeer_stream(naam)
		gelijk(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s loopt rond" % naam)
		gelijk(stream.loop_end, buf.size(), "%s loopt tot het eind" % naam)
		gelijk(stream.mix_rate, Snd.SR, "%s op de eigen samplefrequentie" % naam)
	waar(gezien.size() >= 3, "minstens drie verschillende sferen (%d)" % gezien.size())

func test_stille_kamers_en_de_bevroren_achttien() -> void:
	gelijk(Snd.sfeer_naam("gang"), "", "de gang is stil")
	gelijk(Snd.sfeer_naam("kamer1"), "", "een slaapkamer ook")
	gelijk(Snd.sfeer_naam("receptie"), "tiktak", "de receptie tikt")
	gelijk(Snd.sfeer_naam("tuin"), "wind", "de tuin waait")
	gelijk(Snd.sfeer_naam("zwembad"), "water", "het bad klotst")
	gelijk(Snd.sfeer_naam("speelzaal"), "speeldoos", "de speelzaal speelt")
	gelijk(Snd.sfeer_naam("kas"), "warm", "de kas zoemt warm, als de keuken")
	gelijk(Snd.namen().size(), 18, "de achttien geluiden zijn de achttien gebleven")
	for naam in ["wind", "tiktak", "water", "warm"]:
		waar(not Snd.namen().has(naam), "%s is geen van de achttien" % naam)

## Off is off: muted or asleep, nothing plays; a quiet room stops it.
func test_sfeer_volgt_geluid_aan_uit_en_de_kamer() -> void:
	var wakker := Snd.ontgrendeld()
	var uit := Snd.dempt()
	Snd.stem_af(true)
	Snd.ontgrendel()
	Snd.sfeer("tuin")
	gelijk(Snd.sfeer_speelt(), "wind", "wakker en aan: de tuin waait")
	Snd.sfeer("receptie")
	gelijk(Snd.sfeer_speelt(), "tiktak", "een andere kamer, een andere sfeer")
	Snd.sfeer("gang")
	gelijk(Snd.sfeer_speelt(), "", "een stille kamer zet hem uit")
	Snd.sfeer("zwembad")
	gelijk(Snd.sfeer_speelt(), "water", "het bad klotst")
	Snd.stem_af(false)
	gelijk(Snd.sfeer_speelt(), "", "gedempt is stil")
	Snd.stem_af(not uit)
	Snd._wakker = wakker
	Snd._sfeer_stop()
