extends Proef
## The skeleton's own contracts: the autoloads exist, the baker bakes, the
## registry finds a game without any shared file, the save round-trips and the
## band follows the guest count.
##
## The placeholder room `proefkamer` and the placeholder models `proef_dier` /
## `proef_blok` are gone (W1): the world now ships the eight real rooms and the
## baker the real models, so the two assertions that named them bake a cube of
## their own instead — the plate geometry of art-sound-rules.md §1.5 is what
## they were really about.

func test_autoloads_bestaan() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	for naam in ["Art", "Rooms", "Hits", "World", "Snd", "Ui", "State", "Econ", "Games", "Hotel"]:
		waar(boom.root.get_node_or_null(NodePath(naam)) != null, "autoload " + naam)

func test_baker_maakt_een_plaat() -> void:
	# a 4x4x4 cube of its own, so the plate geometry is asserted on a shape
	# whose box is known by hand instead of on a model somebody may re-draw
	if not Art.heeft_model("proef_kubus"):
		Art.registreer_wereldmodel("proef_kubus", func(params: Dictionary) -> Array:
			var n: int = params.get("n", 4)
			var v: Array = []
			for x in n:
				for y in n:
					for z in n:
						v.append({"x": x, "y": y, "z": z, "k": Color("#D0A87A")})
			return v)
	var p = Art.plaat("proef_kubus", 4, {"n": 4})
	waar(p != null, "plaat bestaat")
	if p == null:
		return
	# 4x4x4 voxels: the box is (4 + 4) * S = 16 voxel-px wide, + 2 px padding
	gelijk(p.w, (4 + 4) * 2 * 4 + 4, "plaatbreedte bij g=4")
	waar(p.h > 0, "plaathoogte")
	waar(p.tex.get_image().get_used_rect().size.x > 0, "er staat iets op")
	# a second call must hit the cache, not bake again
	var voor: int = Art.gebakken()
	Art.plaat("proef_kubus", 4, {"n": 4})
	gelijk(Art.gebakken(), voor, "tweede aanroep komt uit de cache")

func test_registry_vindt_voorbeeld() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var games = boom.root.get_node_or_null(NodePath("Games"))
	if games == null:
		fout("Games ontbreekt")
		return
	waar(games.lijst().has("_voorbeeld"), "map-scan vindt _voorbeeld")
	var def: Dictionary = games.definitie("_voorbeeld")
	gelijk(def.get("naam", ""), "Voorbeeld", "definitie().naam")
	waar(def.has("kamer"), "definitie() noemt een kamer")

func test_opslag_rondrit() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var st = boom.root.get_node_or_null(NodePath("State"))
	if st == null:
		fout("State ontbreekt")
		return
	st.nieuw_spel()
	st.start_gekozen()
	st.s["dag"] = 7
	st.s["sterren"] = 3
	waar(st.bewaar(), "bewaar()")
	st.s = st.standaard()
	gelijk(st.s["dag"], 1, "vers spel")
	waar(st.lees(), "lees()")
	gelijk(st.s["dag"], 7, "dag overleeft")
	gelijk(st.s["sterren"], 3, "sterren overleven")
	# a corrupt file is ignored completely
	var f := FileAccess.open("user://dierenhotel.json", FileAccess.WRITE)
	f.store_string("{niet: json")
	f.close()
	waar(not st.lees(), "kapotte opslag -> startscherm")

func test_band_en_signaal() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	var st = boom.root.get_node_or_null(NodePath("State"))
	st.nieuw_spel()
	gelijk(st.band(), 3, "zonder gasten band 3")
	for i in 6:
		st.tel(true, 1000)
	gelijk(st.s["kunnen"], 4, "kunnen stijgt na 6 goede items")
	gelijk(st.band(), 3, "N begrenst de band")
