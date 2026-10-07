extends Proef
## post — De post sorteren (U4, 2026-10-07), headless.  v1 proves the pure
## maths of `beurt.gd` for every groep and every day, the child-facing strings
## against HOTEL.md §9, the definition, and that the room's own models bake.
## The turn itself (card, strip, `taak_klaar`) is NEXT STEP 3 in
## .fanout/scratch/uitbreiding/U4-postkamer.md.

const Beurt := preload("res://games/post/beurt.gd")
const Spel := preload("res://games/post/spel.gd")
const Modellen := preload("res://art/decor_post.gd")

func test_een_brief_per_gast_tussen_twee_en_zes() -> void:
	gelijk(Beurt.aantal(0), 2, "zonder gasten toch twee brieven")
	gelijk(Beurt.aantal(1), 2, "één gast: twee brieven")
	gelijk(Beurt.aantal(4), 4, "vier gasten: vier brieven")
	gelijk(Beurt.aantal(8), 6, "een vol hotel: hooguit zes brieven")

func test_groep_3_vakjes_van_vijf_tot_twintig() -> void:
	var vk := Beurt.vakjes(3, 3, 1)
	gelijk(vk.size(), 4, "vier vakjes")
	gelijk(vk[0], {"van": 1, "tot": 5}, "1 - 5")
	gelijk(vk[1], {"van": 6, "tot": 10}, "6 - 10")
	gelijk(vk[2], {"van": 11, "tot": 15}, "11 - 15")
	gelijk(vk[3], {"van": 16, "tot": 20}, "16 - 20")
	gelijk(Beurt.plaat(vk[2]), "11 - 15", "het plaatje toont beide getallen")
	gelijk(Beurt.vak_van(13, vk), 2, "13 hoort in 11 - 15")
	gelijk(Beurt.vak_van(5, vk), 0, "5 hoort in 1 - 5")
	gelijk(Beurt.vak_van(16, vk), 3, "16 hoort in 16 - 20")
	gelijk(Beurt.vak_van(21, vk), -1, "21 past nergens")

func test_groep_4_en_5_vier_tientallen_tot_honderd() -> void:
	for band in [4, 5]:
		for dag in range(1, 15):
			for n in range(2, 7):
				var vk := Beurt.vakjes(band, n, dag)
				gelijk(vk.size(), 4, "vier vakjes")
				for j in 4:
					gelijk(int(vk[j]["tot"]) - int(vk[j]["van"]), 9, "een vakje is een tiental")
					gelijk(int(vk[j]["van"]) % 10, 0, "een vakje begint op een tiental")
					if j > 0:
						gelijk(int(vk[j]["van"]), int(vk[j - 1]["tot"]) + 1, "de vakjes sluiten aan")
				waar(int(vk[0]["van"]) >= 0 and int(vk[3]["tot"]) <= 99, "alles onder de honderd")
	gelijk(Beurt.vak_van(34, [{"van": 30, "tot": 39}, {"van": 40, "tot": 49}]), 0, "34 hoort in 30 - 39")

func test_elke_brief_past_in_een_vakje() -> void:
	for band in [3, 4, 5]:
		for dag in range(1, 15):
			for n_gasten in range(0, 9):
				var b := Beurt.maak(band, n_gasten, dag)
				var vk: Array = b["vakjes"]
				var brieven: Array = b["brieven"]
				gelijk(brieven.size(), Beurt.aantal(n_gasten), "één brief per gast")
				for br in brieven:
					var j := int(br["vak"])
					waar(j >= 0 and j < 4, "brief %d heeft een vakje (groep %d, dag %d)" % [int(br["getal"]), band, dag])
					if j >= 0:
						waar(int(br["getal"]) >= int(vk[j]["van"]) and int(br["getal"]) <= int(vk[j]["tot"]),
							"brief %d ligt in zijn vakje %s" % [int(br["getal"]), Beurt.plaat(vk[j])])
					if band >= 5:
						waar(" × " in str(br["tekst"]), "groep 5: een keersom op de brief (%s)" % str(br["tekst"]))
						var delen := str(br["tekst"]).split(" × ")
						gelijk(int(delen[0]) * int(delen[1]), int(br["getal"]), "de keersom klopt")
						waar(int(delen[0]) >= 2 and int(delen[0]) <= 10 and int(delen[1]) >= 2 and int(delen[1]) <= 10,
							"uit de tafels van 2 tot 10")
					else:
						gelijk(str(br["tekst"]), str(br["getal"]), "groep 3/4: het getal zelf op de brief")
					if band == 3:
						waar(int(br["getal"]) >= 1 and int(br["getal"]) <= 20, "groep 3 tot 20")

func test_de_voorbeelden_uit_het_ontwerp() -> void:
	# groep 5: 7 × 8 = 56 lands in 50 - 59 whenever the window holds it
	var vk := [{"van": 50, "tot": 59}, {"van": 60, "tot": 69}, {"van": 70, "tot": 79}, {"van": 80, "tot": 89}]
	gelijk(Beurt.vak_van(7 * 8, vk), 0, "7 × 8 → 50 - 59")
	gelijk(Beurt.vak_van(9 * 9, vk), 3, "9 × 9 → 80 - 89")
	var paren: Array = Beurt._tafels_in(0, 39)
	waar(paren.has(Vector2i(3, 4)), "3 × 4 zit in het venster 0..39")
	waar(not paren.has(Vector2i(7, 8)), "7 × 8 niet")

func test_elke_zin_is_kort_en_begint_met_een_pictogram() -> void:
	for zin in [Spel.REGEL, Spel.TOAST_GOED, Spel.TOAST_KLAAR]:
		waar(zin.length() <= 40, "%s: ≤ 40 tekens (%d)" % [zin, zin.length()])
		waar(zin.split(" ").size() <= 8, "%s: ≤ 8 woorden" % zin)
		waar(zin.begins_with("💌"), "%s: pictogram eerst" % zin)
	waar(Spel.KEUZE_TITEL.length() <= 40, "de strooktitel is kort")

func test_definitie_en_scene() -> void:
	var scene: PackedScene = load("res://games/post/spel.tscn")
	waar(scene != null, "de scene laadt")
	var spel = scene.instantiate()
	waar(spel is MiniGame, "het spel is een MiniGame")
	var d: Dictionary = spel.definitie()
	gelijk(d["kamer"], "postkamer", "het spel staat in de postkamer")
	waar(bool(d.get("stub", false)), "nog een stub tot de beurt rond is")
	gelijk(d["taak"]["id"], "post", "de taakkaart heet post")
	gelijk(d["hotspot"]["icoon"], "💌", "de knop draagt een brief")
	waar((d["unlock"] as Callable).call(1, 3), "open vanaf de eerste gast")
	spel.free()

## Integration I1a (2026-10-07): the post room hangs on the KAS, not on the
## lobby — a fifth opening in the lobby found no place for its sign on a phone
## and pushed the bell and the board around (tests/test_hits.gd,
## tests/test_knoppen_staan_stil.gd).  Still the ground floor.
func test_de_kamer_bestaat_en_hangt_aan_de_kas() -> void:
	waar(Rooms.bestaat("postkamer"), "de postkamer bestaat")
	gelijk(Rooms.etage("postkamer"), 0, "op de begane grond")
	waar(not Rooms.deur("kas", "postkamer").is_empty(), "de kas heeft een deur erheen")
	waar(not Rooms.deur("postkamer", "kas").is_empty(), "en de postkamer terug")
	gelijk(Rooms.pad("receptie", "postkamer"), ["receptie", "tuin", "kas", "postkamer"],
		"vanuit de receptie door de tuin en de kas")
	waar(Rooms.get_kamer("postkamer").trap.is_empty(), "geen trap: die blijft in de trapkamers")

func test_de_modellen_bakken() -> void:
	var fns := {"vakkenkast": Modellen.vakkenkast, "postkar": Modellen.postkar,
		"pakketweegschaal": Modellen.pakketweegschaal, "zegelbalie": Modellen.zegelbalie}
	for naam in fns:
		var v: Array = (fns[naam] as Callable).call({"vol": [1, 2, 0, 3], "brieven": 4})
		waar(v.size() > 50, "%s heeft voxels (%d)" % [naam, v.size()])
		for vox in v:
			waar(vox.has("x") and vox.has("y") and vox.has("z") and vox.has("k"), "%s: een voxel is {x, y, z, k}" % naam)
			break
	var leeg: Array = Modellen.postkar({"brieven": 0})
	var vol: Array = Modellen.postkar({"brieven": 5})
	waar(vol.size() > leeg.size(), "meer brieven, een hogere stapel op de kar")
