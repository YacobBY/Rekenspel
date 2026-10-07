extends Proef
## band — De dierenband in de muziekkamer (U2), headless.
##
## Only the pure turn logic in `beurt.gd`, the models and the registration are
## tested here; the turn itself (card, strip, sounds) is NOT driven yet — see
## `.fanout/scratch/uitbreiding/U2-muziekkamer.md`, NEXT STEPS.

const Beurt := preload("res://games/band/beurt.gd")

func test_aanmelding() -> void:
	var def: Dictionary = Games.definitie("band")
	waar(not def.is_empty(), "band is aangemeld")
	if def.is_empty():
		return
	gelijk(String(def["kamer"]), "muziekkamer", "de band speelt in de muziekkamer")
	gelijk(String(def["taak"]["id"]), "band", "taak id")
	waar(bool(def.get("stub", false)), "band is nog een stub (U2 stand)")
	for naam in ArtDecorMuziek.NAMEN:
		waar(Art.heeft_model(naam), "Art kent " + naam)
	waar(Rooms.bestaat("muziekkamer"), "de muziekkamer bestaat")
	waar(not Rooms.deur("muziekkamer", "speelzaal").is_empty(), "deur naar de speelzaal")
	waar(not Rooms.deur("speelzaal", "muziekkamer").is_empty(), "deur vanuit de speelzaal")
	gelijk(Rooms.etage("muziekkamer"), 3, "de muziekkamer is de bovenste verdieping")

func test_een_maat_per_gast() -> void:
	gelijk(Beurt.maten_voor(0), 2, "nooit minder dan twee maten")
	gelijk(Beurt.maten_voor(1), 2, "één gast: twee maten")
	gelijk(Beurt.maten_voor(4), 4, "vier gasten: vier maten")
	gelijk(Beurt.maten_voor(8), 6, "acht gasten: de balk is vol bij zes")

func test_de_getallen_per_band() -> void:
	var soorten := {}
	for n in range(1, 9):
		for band in [3, 4, 5]:
			for dag in range(1, 9):
				var o := Beurt.opzet(n, band, dag)
				var wie := "n=%d band=%d dag=%d" % [n, band, dag]
				var soort := String(o["soort"])
				soorten[soort] = true
				waar(Beurt.SOORTEN.has(soort), wie + " soort " + soort)
				var goed := int(o["goed"])
				var k := int(o["k"])
				var m := int(o["m"])
				var maten: Array = o["maten"]
				waar(int(o["min"]) <= goed and goed <= int(o["max"]), wie + " goed binnen min..max")
				waar(int(o["min"]) < int(o["max"]), wie + " min < max")
				gelijk(int(o["tikken"]), Beurt.tel_tikken(maten), wie + " tikken geteld")
				waar(int(o["toon_maten"]) >= 1 and int(o["toon_maten"]) <= maten.size(),
					wie + " de balk toont 1..alle maten")
				match soort:
					"tel":
						gelijk(band, 3, wie + " tellen is groep 3")
						waar(goed >= 2 and goed <= 10, wie + " 2..10 tikken")
						gelijk(goed, int(o["tikken"]), wie + " het antwoord is het aantal tikken")
						gelijk(maten.size(), 1, wie + " één ritme")
					"samen":
						gelijk(band, 3, wie + " samen is groep 3")
						waar(dag >= 3, wie + " pas vanaf dag 3")
						waar(goed >= 5 and goed <= 20, wie + " 5..20 tikken samen")
						gelijk(goed, int(o["tikken"]), wie + " het antwoord is het aantal tikken")
						gelijk(maten.size(), 2, wie + " twee ritmes")
					"maten":
						gelijk(band, 4, wie + " sprongen zijn groep 4")
						waar(Beurt.SPRONGEN.has(k), wie + " k in {2, 5, 10}")
						gelijk(m, Beurt.maten_voor(n), wie + " één maat per gast")
						gelijk(goed, k * m, wie + " k × m")
						gelijk(goed, int(o["tikken"]), wie + " alle tikken")
					"tafel":
						gelijk(band, 5, wie + " tafels zijn groep 5")
						waar(Beurt.TAFELS.has(k), wie + " k uit de tafels")
						gelijk(m, Beurt.maten_voor(n), wie + " één maat per gast")
						gelijk(goed, k * m, wie + " k × m")
						waar(dag % 2 == 1, wie + " oneven dag")
					"omgekeerd":
						gelijk(band, 5, wie + " omgekeerd is groep 5")
						waar(dag % 2 == 0, wie + " even dag")
						gelijk(goed, m, wie + " het antwoord is het aantal maten")
						gelijk(int(o["doel"]), k * m, wie + " het doel is k × m")
						gelijk(int(o["toon_maten"]), 1, wie + " de balk toont één maat")
	for s in Beurt.SOORTEN:
		waar(soorten.has(s), "soort %s komt voor" % s)

func test_hetzelfde_zaad_hetzelfde_ritme() -> void:
	for band in [3, 4, 5]:
		gelijk(str(Beurt.opzet(3, band, 4)), str(Beurt.opzet(3, band, 4)), "band %d: hetzelfde zaad" % band)
	var anders := false
	for dag in range(1, 12):
		anders = anders or str(Beurt.opzet(3, 3, dag)) != str(Beurt.opzet(3, 3, 4))
	waar(anders, "een andere dag geeft een ander ritme")

## HOTEL.md §9: every card sentence ≤ 8 words AND ≤ 40 characters, pictogram
## first, and every glyph in the bundled fonts.
func test_elke_zin_past() -> void:
	var pictos := [Beurt.ICOON, Beurt.ICOON_LUISTER, Beurt.ICOON_NOG, Beurt.ICOON_AF, Beurt.ICOON_AF2]
	for zin in Beurt.zinnen():
		var vol := "%s %s" % [Beurt.ICOON, zin]
		waar(vol.split(" ", false).size() <= 8, "≤ 8 woorden: " + vol)
		waar(vol.length() <= 40, "≤ 40 tekens: " + vol)
	for p in pictos:
		var mist: Array[String] = Ui.mist_tekens(p)
		waar(mist.is_empty(), "het pictogram %s staat in de fonts" % p)
	waar(Ui.mist_tekens(Rooms.get_kamer("muziekkamer").icoon).is_empty(),
		"het kamerpictogram staat in de fonts")
	for n in [1, 4, 8]:
		for band in [3, 4, 5]:
			var o := Beurt.opzet(n, band, 2)
			var vraag := "%s %s" % [Beurt.ICOON, Beurt.vraag(o)]
			waar(vraag.split(" ", false).size() <= 8 and vraag.length() <= 40, "de vraag past: " + vraag)

func test_de_modellen_bakken() -> void:
	for naam in ArtDecorMuziek.NAMEN:
		var fn: Callable = ArtDecorMuziek.tabel()[naam]
		var v: Array = fn.call({})
		waar(v.size() >= 20, "%s heeft voxels (%d)" % [naam, v.size()])
		for b in v:
			if not (b.has("x") and b.has("y") and b.has("z") and b.has("k")):
				fout("%s: een voxel zonder x/y/z/k" % naam)
				break
	waar(ArtDecorMuziek.band_trommel().size() > ArtDecorMuziek.band_standaard().size(),
		"de trommel is groter dan de standaard")
