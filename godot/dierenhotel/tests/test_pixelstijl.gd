extends Proef
## The pixel style (docs/ART-STIJL.md): the rules every plate follows, the floor
## and walls drawn one pixel per voxel-px, and golden plates that pin the look.
##
## The goldens in `tests/gouden_pixel/` are the game's OWN output, baked at
## g = 1 (one pixel per voxel-px, the pure pixel art; every other g is an exact
## blow-up of it, which `test_elke_schaal_is_een_vergroting` checks).  They are
## there to catch a look that changes by ACCIDENT.  When a model is changed on
## purpose, write them again and look at the pictures before committing:
##
##     DH_GOUD_SCHRIJF=1 DH_TEST_FILTER=test_pixelstijl tools/test.sh
##
## (docs/ART-STIJL.md §6 has the whole round.)

const GOUD := "res://tests/gouden_pixel"
const POSES := ["rust", "lig", "loopA", "loopB", "zit", "sip", "blijA"]

## The pixel style is the backup look since 2026-10-01 (the game draws in the
## voxel style again, `Art.STANDAARD`): every test here switches to it first,
## and `Proef.herstel_spellen` switches back after the test.
func _pixel() -> void:
	Art.zet_stijl("pixel")

func _schrijven() -> bool:
	return OS.get_environment("DH_GOUD_SCHRIJF") == "1"

## Compare (or, with DH_GOUD_SCHRIJF=1, write) one golden plate.  Exact: the
## pixel style has no anti-aliasing, so there is nothing to tolerate.
func _goud(naam: String, plaat) -> void:
	if plaat == null:
		fout("%s: bakt niet" % naam)
		return
	var img: Image = plaat.tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var pad := "%s/%s.png" % [GOUD, naam]
	if _schrijven():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOUD))
		img.save_png(ProjectSettings.globalize_path(pad))
		return
	if not FileAccess.file_exists(pad):
		fout("%s: geen gouden plaat (schrijf ze met DH_GOUD_SCHRIJF=1)" % naam)
		return
	var goud := Image.new()
	if goud.load_png_from_buffer(FileAccess.get_file_as_bytes(pad)) != OK:
		fout("%s: gouden plaat onleesbaar" % naam)
		return
	goud.convert(Image.FORMAT_RGBA8)
	if goud.get_size() != img.get_size():
		fout("%s: maat %s, gouden %s" % [naam, img.get_size(), goud.get_size()])
		return
	var a := goud.get_data()
	var b := img.get_data()
	var anders := 0
	for i in range(0, a.size(), 4):
		if a[i] != b[i] or a[i + 1] != b[i + 1] or a[i + 2] != b[i + 2] or a[i + 3] != b[i + 3]:
			anders += 1
	if anders > 0:
		fout("%s: %d pixels anders dan de gouden plaat" % [naam, anders])

func _wereldmodellen() -> Array[String]:
	var namen := ArtDecor.alle_namen()
	for n in ArtDecor.POL_AANTAL:
		namen.append("pol%d" % n)
	return namen

# ------------------------------------------------------------------ goudplaten

func test_gouden_gasten() -> void:
	_pixel()
	for kind in ArtGasten.SOORTEN:
		for pose in POSES:
			_goud("gast_%s_%s" % [kind, pose], Art.dier(kind, pose, 1))
	_goud("gast_hond_rust_tooi", Art.dier("hond", "rust", 1, "hoedje,sjaaltje,bal"))

func test_gouden_kom() -> void:
	_pixel()
	for n in 5:
		_goud("kom_n%d_achter" % n, Art.kom(n, 1, false))
		_goud("kom_n%d_voor" % n, Art.kom(n, 1, true))

func test_gouden_wereldmodellen() -> void:
	_pixel()
	for naam in _wereldmodellen():
		_goud("decor_%s" % naam, Art.plaat(naam, 1))

# ------------------------------------------------------------------ de regels

## No anti-aliasing anywhere: a pixel is there or it is not.
func test_geen_halve_pixels() -> void:
	_pixel()
	for plaat in [Art.dier("konijn", "rust", 3), Art.plaat("bed", 2), Art.plaat("plant", 4),
			Art.kom(2, 3, false), Art.kom(2, 3, true)]:
		var d: PackedByteArray = plaat.tex.get_image().get_data()
		var half := 0
		for i in range(3, d.size(), 4):
			if d[i] != 0 and d[i] != 255:
				half += 1
		gelijk(half, 0, "halfdoorzichtige pixels")

## Every g is the g = 1 plate blown up without smoothing, in the same place.
func test_elke_schaal_is_een_vergroting() -> void:
	_pixel()
	for naam in ["bed", "balie", "plant", "kassa"]:
		var een = Art.plaat(naam, 1)
		var bron: Image = een.tex.get_image()
		for g in [2, 3, 4]:
			var p = Art.plaat(naam, g)
			gelijk(p.w, een.w * g, "%s g%d breedte" % [naam, g])
			gelijk(p.h, een.h * g, "%s g%d hoogte" % [naam, g])
			gelijk(p.dx, een.dx * g, "%s g%d dx" % [naam, g])
			gelijk(p.dy, een.dy * g, "%s g%d dy" % [naam, g])
			var groot: Image = bron.duplicate()
			groot.resize(een.w * g, een.h * g, Image.INTERPOLATE_NEAREST)
			waar(groot.get_data() == p.tex.get_image().get_data(), "%s g%d is een vergroting" % [naam, g])

## The outline is the colour inside it, darker — never black, never grey ink —
## and it runs round the whole silhouette.
func test_de_rand_is_de_eigen_kleur_donkerder() -> void:
	_pixel()
	var img: Image = Art.plaat("bed", 1).tex.get_image()
	var w := img.get_width()
	var h := img.get_height()
	var rand := 0
	var zwart := 0
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var buiten := x == 0 or y == 0 or x == w - 1 or y == h - 1 \
				or img.get_pixel(x - 1, y).a == 0.0 or img.get_pixel(x + 1, y).a == 0.0 \
				or img.get_pixel(x, y - 1).a == 0.0 or img.get_pixel(x, y + 1).a == 0.0
			if not buiten:
				continue
			rand += 1
			if c.get_luminance() < 0.12:
				zwart += 1
	waar(rand > 50, "het bed heeft een rand (%d pixels)" % rand)
	gelijk(zwart, 0, "randpixels die zwart zijn")

## The anchor convention of `bak` holds; only the padding is one voxel-px now.
func test_plaatmaat_hond() -> void:
	_pixel()
	var p := Art.dier("hond", "rust", 4)
	# 64 x 60 voxel-px at (-16, -29), plus one voxel-px of outline all round
	gelijk(p.w, 66 * 4, "hond rust g4 breedte")
	gelijk(p.h, 62 * 4, "hond rust g4 hoogte")
	gelijk(p.dx, -17 * 4, "hond rust g4 dx")
	gelijk(p.dy, -30 * 4, "hond rust g4 dy")

## Every world model bakes in the pixel style at every scale the world uses.
func test_elk_wereldmodel_bakt() -> void:
	_pixel()
	for naam in _wereldmodellen():
		for g in [2, 3, 4]:
			var p = Art.plaat(naam, g)
			waar(p != null and p.w > 0 and p.h > 0, "%s bakt op g=%d" % [naam, g])

## The voxel style is the game's look again, `?stijl=pixel` gives the pixel
## art, and switching throws the cache away.
func test_stijl_wisselen() -> void:
	Art.zet_stijl(Art.standaard())
	gelijk(Art.standaard(), "voxel", "het spel tekent weer in de voxelstijl (eigenaar, 2026-10-01)")
	_pixel()
	gelijk(Art.stijl, "pixel", "de pixelstijl is er nog, als backup")
	var pixel: Image = Art.plaat("mand", 2).tex.get_image()
	Art.zet_stijl("voxel")
	var voxel: Image = Art.plaat("mand", 2).tex.get_image()
	waar(pixel.get_data() != voxel.get_data(), "de voxelstijl ziet er anders uit")
	Art.zet_stijl("pixel")
	waar(Art.plaat("mand", 2).tex.get_image().get_data() == pixel.get_data(),
		"terug in de pixelstijl is het dezelfde plaat")

## A sprite lands on the world's pixel grid.
func test_op_raster() -> void:
	_pixel()
	gelijk(Art.op_raster(Vector2(13.4, 7.9), Vector2(1, 1), 3), Vector2(13, 7), "op veelvouden van g")
	Art.zet_stijl("voxel")
	gelijk(Art.op_raster(Vector2(13.4, 7.9), Vector2(1, 1), 3), Vector2(13.4, 7.9), "voxel schuift niet")
	Art.zet_stijl("pixel")

# ------------------------------------------------------------ vloer en muren

## Every room's floor, walls, doors, stairs and facade rasterise one pixel per
## voxel-px, opaque, with the dark ring round a walled room.
func test_elke_kamer_rasteriseert() -> void:
	_pixel()
	var script := load("res://scenes/vloer.gd")
	for kid in Rooms.lijst():
		var r := Rooms.get_kamer(kid)
		var v = script.new()
		var t0 := Time.get_ticks_msec()
		v._bouw(r)
		var ms := Time.get_ticks_msec() - t0
		var beeld: ImageTexture = v._beeld
		waar(beeld != null, "%s heeft een vloerbeeld" % kid)
		if beeld == null:
			v.free()
			continue
		var img := beeld.get_image()
		# the floor's middle is covered and opaque
		var mid: Vector2 = v._proj(r.w / 2.0, r.d / 2.0) - v._beeld_bij
		var c := img.get_pixelv(Vector2i(mid.floor()))
		waar(c.a > 0.99, "%s: het midden van de vloer is dicht" % kid)
		if not r.erf and r.wand > 0:
			var hoek: Vector2 = v._proj(r.w, r.d) - v._beeld_bij + Vector2(0, 0.5)
			var rand := img.get_pixelv(Vector2i(hoek.floor()))
			waar(rand.a > 0.99 and rand.get_luminance() < 0.6,
				"%s: de voorhoek van de vloer heeft de donkere rand (%s)" % [kid, rand])
		waar(ms < 1500, "%s rasteriseert in %d ms" % [kid, ms])
		v.free()
