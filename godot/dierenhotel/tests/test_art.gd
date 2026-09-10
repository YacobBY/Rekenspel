extends Proef
## W4 — the voxel baker against the golden-image oracle (architecture.md §3.6).
##
## `tests/gouden/` holds 72 plates that were pulled losslessly out of the
## running HTML engine (73 rows in `meta.json`: `gast_hond_rust_g4` is both a
## pose and a species).  Every test below bakes the same model/pose/g in Godot
## and compares it pixel for pixel.
##
## Tolerance (architecture.md §3.6): the alpha silhouette must match within
## 1 px — with ZERO exceptions, measured — and the number of pixels whose
## channel difference is more than 16 must stay under
## `2 % of w*h + 5 * (w + h)`.  The difference between canvas2d and this integer
## filler is an EDGE phenomenon (canvas anti-aliases every polygon edge and
## strokes it 1 px wide, this filler rounds the span outward), so it scales with
## the perimeter of the plate, not with its area: measured 1.19 % of a 436 x 316
## counter and 14.36 % of a 44 x 44 ball, but a near-constant 2.7-3.8 pixels per
## unit of perimeter across all 64 plates.
##
## The report per plate lands in `user://art-rapport.txt`; the ticket asks for
## the per-plate difference, and a table of 63 lines does not belong in the
## suite's output.

const GOUDEN := "res://tests/gouden"
const TOL_KANAAL := 16      ## a channel difference above this counts
const TOL_VLAK := 0.02      ## share of the plate area
const TOL_OMTREK := 5.0     ## plus this many pixels per unit of perimeter
const TOL_SILHOUET := 0     ## pixels of silhouette that may be more than 1 px off

static var _rapport: Array[String] = []

# --------------------------------------------------------------------- helpers

func _gouden(naam: String) -> Image:
	var pad := "%s/%s.png" % [GOUDEN, naam]
	if not FileAccess.file_exists(pad):
		return null
	var ruw := FileAccess.get_file_as_bytes(pad)
	if ruw.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(ruw) != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img

func _meta() -> Dictionary:
	var pad := "%s/meta.json" % GOUDEN
	if not FileAccess.file_exists(pad):
		return {}
	var t := FileAccess.get_file_as_string(pad)
	var d = JSON.parse_string(t)
	return d if typeof(d) == TYPE_DICTIONARY else {}

## Compare a baked plate with its golden PNG.  Returns
## {px, anders, deel, silhouet, maat} — `silhouet` counts alpha pixels that are
## on in one image and off in the other AND have no matching neighbour.
func _vergelijk(naam: String, plaat) -> Dictionary:
	var goud := _gouden(naam)
	if goud == null or plaat == null:
		return {}
	var eigen: Image = plaat.tex.get_image()
	eigen.convert(Image.FORMAT_RGBA8)
	var w := goud.get_width()
	var h := goud.get_height()
	if eigen.get_width() != w or eigen.get_height() != h:
		return {"maat": false, "w": eigen.get_width(), "h": eigen.get_height(),
			"gw": w, "gh": h, "px": w * h, "anders": w * h, "deel": 100.0, "silhouet": w * h}
	var a := goud.get_data()
	var b := eigen.get_data()
	var anders := 0
	var sil := 0
	var n := w * h
	# 1. channel difference
	for i in n:
		var o := i * 4
		if absi(a[o] - b[o]) > TOL_KANAAL or absi(a[o + 1] - b[o + 1]) > TOL_KANAAL \
				or absi(a[o + 2] - b[o + 2]) > TOL_KANAAL or absi(a[o + 3] - b[o + 3]) > TOL_KANAAL:
			anders += 1
	# 2. silhouette: a pixel that is opaque here and empty there is only allowed
	#    when the other image has the same value one pixel away.
	for y in h:
		for x in w:
			var i := y * w + x
			var ga: bool = a[i * 4 + 3] >= 128
			var eb: bool = b[i * 4 + 3] >= 128
			if ga == eb:
				continue
			if _buurt(a if eb else b, w, h, x, y, eb if eb else ga):
				continue
			sil += 1
	return {"maat": true, "px": n, "anders": anders, "w": w, "h": h,
		"grens": int(TOL_VLAK * float(n) + TOL_OMTREK * float(w + h)),
		"deel": 100.0 * float(anders) / float(maxi(1, n)), "silhouet": sil}

## Does the 3x3 neighbourhood of (x, y) in `data` hold a pixel whose "opaque"
## flag equals `waarde`?
func _buurt(data: PackedByteArray, w: int, h: int, x: int, y: int, waarde: bool) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			if (data[(ny * w + nx) * 4 + 3] >= 128) == waarde:
				return true
	return false

## With DH_ART_DUMP=1 in the environment every baked plate is also written to
## `user://gebakken/`, so the difference with the golden PNG can be looked at
## instead of only counted.
func _dump(naam: String, plaat) -> void:
	if OS.get_environment("DH_ART_DUMP") != "1" or plaat == null:
		return
	DirAccess.make_dir_recursive_absolute("user://gebakken")
	plaat.tex.get_image().save_png("user://gebakken/%s.png" % naam)

func _keur(naam: String, plaat) -> void:
	_dump(naam, plaat)
	var r := _vergelijk(naam, plaat)
	if r.is_empty():
		fout("%s: geen gouden plaat of geen bak" % naam)
		return
	if not r["maat"]:
		fout("%s: plaatmaat %dx%d, gouden %dx%d" % [naam, r["w"], r["h"], r["gw"], r["gh"]])
		return
	_rapport.append("%-40s %7d px  %6d anders (%5.2f %%, grens %6d)  %4d silhouet"
		% [naam, r["px"], r["anders"], r["deel"], r["grens"], r["silhouet"]])
	if r["anders"] > r["grens"]:
		fout("%s: %d pixels wijken af, grens %d (%.2f %%)"
			% [naam, r["anders"], r["grens"], r["deel"]])
	if r["silhouet"] > TOL_SILHOUET:
		fout("%s: %d silhouetpixels meer dan 1 px mis" % [naam, r["silhouet"]])

func _schrijf_rapport() -> void:
	var f := FileAccess.open("user://art-rapport.txt", FileAccess.WRITE)
	if f == null:
		return
	f.store_line("W4 — gouden platen, verschil per plaat")
	f.store_line("kolommen: plaat, pixels, pixels met een kanaalverschil > %d, %%, silhouetmissers"
		% TOL_KANAAL)
	_rapport.sort()
	for r in _rapport:
		f.store_line(r)
	f.close()

# ----------------------------------------------------------------- de gasten

func test_gouden_gast_alle_houdingen() -> void:
	for pose in ArtGasten.POSE.keys():
		_keur("gast_hond_%s_g4" % pose, Art.dier("hond", pose, 4))
	_schrijf_rapport()

func test_gouden_gast_alle_soorten() -> void:
	for kind in ArtGasten.SOORTEN:
		_keur("gast_%s_rust_g4" % kind, Art.dier(kind, "rust", 4))
	_schrijf_rapport()

## W4-F1: the pose coverage was dog-only.  The other three species carry the
## post-transforms that are easiest to get wrong — `liggen()` squashes the legs
## (and lays a rabbit's ears flat along its back), `loopA`/`loopB` are the gait,
## which a rabbit hops and a goose waddles instead of walking.
##
## There is no pose `zwem`: art.js has fifteen and swimming is none of them.  A
## swimmer keeps his pose and gets a band of water composited over his lower
## half (art-sound-rules.md §11.5), which cannot come out of `Art.kit.dier` and
## is asserted in `test_water_alleen_op_de_zwemmer` instead.
func test_gouden_gast_lig_en_loop() -> void:
	for kind in ["poes", "konijn", "gans"]:
		for pose in ["lig", "loopA", "loopB"]:
			_keur("gast_%s_%s_g4" % [kind, pose], Art.dier(kind, pose, 4))
	_schrijf_rapport()

func test_gouden_gast_alle_schalen() -> void:
	for g in [2, 3, 5]:
		_keur("gast_hond_rust_g%d" % g, Art.dier("hond", "rust", g))
	_schrijf_rapport()

func test_gouden_gast_tooi() -> void:
	for acc in ["hoedje", "sjaaltje", "bal", "hoedje,sjaaltje,bal"]:
		_keur("gast_hond_rust_g4_%s" % acc.replace(",", "+"), Art.dier("hond", "rust", 4, acc))
	_schrijf_rapport()

func test_gouden_kom() -> void:
	for n in 5:
		_keur("kom_n%d_achter_g4" % n, Art.kom(n, 4, false))
		_keur("kom_n%d_voor_g4" % n, Art.kom(n, 4, true))
	_schrijf_rapport()

func test_gouden_decor() -> void:
	for naam in ["boom", "hok", "bed", "prikbord", "kar", "tobbe", "kist", "plant",
			"balie", "mand", "bal", "zak", "kast", "lamp"]:
		for g in [2, 4]:
			_keur("decor_%s_g%d" % [naam, g], Art.plaat(naam, g))
	_schrijf_rapport()

# ------------------------------------------------------- maten, anker, census

func test_plaatmaat_en_offset() -> void:
	var meta := _meta()
	if meta.is_empty():
		fout("meta.json ontbreekt")
		return
	var gezien := 0
	for p in meta.get("platen", []):
		var naam: String = p["naam"]
		var plaat = _plaat_voor(naam, p)
		if plaat == null:
			continue
		gezien += 1
		gelijk(plaat.w, int(p["w"]), "%s breedte" % naam)
		gelijk(plaat.h, int(p["h"]), "%s hoogte" % naam)
		gelijk(plaat.dx, int(p["dx"]), "%s dx" % naam)
		gelijk(plaat.dy, int(p["dy"]), "%s dy" % naam)
	waar(gezien >= 72, "minstens 72 platen gemeten, kreeg %d" % gezien)

func _plaat_voor(naam: String, p: Dictionary):
	match str(p.get("soort", "")):
		"gast":
			return Art.dier(str(p["kind"]), str(p["pose"]), int(p["g"]))
		"gast_tooi":
			return Art.dier("hond", "rust", int(p["g"]), str(p["acc"]))
		"kom":
			return Art.kom(int(p["niveau"]), int(p["g"]), str(p["deel"]) == "voor")
		"decor":
			return Art.plaat(str(p["model"]), int(p["g"]))
	return null

## The model census of art-sound-rules.md §4 / meta.json: voxels and culled
## faces per species in pose `rust`.
func test_modelcensus() -> void:
	var meta := _meta()
	var stats: Dictionary = meta.get("stats", {}).get("vlakken", {})
	if stats.is_empty():
		fout("meta.json zonder census")
		return
	for kind in ArtGasten.SOORTEN:
		var c := Art.census(ArtGasten.bouw(kind, "rust", ""))
		gelijk(c["voxels"], int(stats[kind]["voxels"]), "%s voxels" % kind)
		gelijk(c["vlakken"], int(stats[kind]["vlakken"]), "%s gecullde vlakken" % kind)
		var m: Array = stats[kind]["lxhxd"]
		gelijk(c["lxhxd"], Vector3i(int(m[0]), int(m[1]), int(m[2])), "%s l x h x d" % kind)

func test_anker_en_projectie() -> void:
	# X4 §5.1: gast_hond_rust is 64 x 60 voxel-px at (-16, -29); at g = 4 that is
	# 64*4 + 4 = 260 wide and the offset is -16*4 - 2 = -66.
	var p := Art.dier("hond", "rust", 4)
	gelijk(p.w, 260, "hond rust g4 breedte")
	gelijk(p.h, 244, "hond rust g4 hoogte")
	gelijk(p.dx, -66, "hond rust g4 dx")
	gelijk(p.dy, -118, "hond rust g4 dy")
	gelijk(Art.DIER_ANKER, Vector2(13, 7.5), "dierAnker")
	gelijk(Art.KOM_ANKER, Vector2(29.5, 7.5), "komAnker")

func test_niveau() -> void:
	gelijk(Art.niveau(0, 4), 0, "leeg bakje")
	gelijk(Art.niveau(1, 4), 1, "een schepje")
	gelijk(Art.niveau(4, 4), 4, "vol")
	gelijk(Art.niveau(9, 4), 4, "nooit boven 4")
	gelijk(Art.niveau(3, 0), 4, "per <= 0 telt als een volle portie")

# ---------------------------------------------------- register en plaatcache

func test_elk_wereldmodel_bakt_op_elke_schaal() -> void:
	var namen := ArtDecor.NAMEN.duplicate()
	for n in ArtDecor.POL_AANTAL:
		namen.append("pol%d" % n)
	gelijk(namen.size(), 33, "33 decorstukken (art-sound-rules.md §8)")
	for naam in namen:
		waar(Art.heeft_model(naam), "model %s bestaat" % naam)
		waar(Art.is_wereldmodel(naam), "model %s is beschermd" % naam)
		for g in [2, 3, 4]:
			var p = Art.plaat(naam, g)
			waar(p != null and p.w > 0 and p.h > 0, "%s bakt op g=%d" % [naam, g])

func test_lru_blijft_binnen_de_begroting() -> void:
	Art.wis_platen()
	for kind in ArtGasten.SOORTEN:
		for pose in ArtGasten.POSE.keys():
			for g in [2, 3, 4]:
				Art.dier(kind, pose, g)
	waar(Art.platen_in_cache() <= Art.PLAAT_MAX,
		"cache %d <= PLAAT_MAX %d" % [Art.platen_in_cache(), Art.PLAAT_MAX])
	# a plate that is still in the cache does not bake again
	var voor: int = Art.gebakken()
	Art.dier("gans", "snuif", 4)
	gelijk(Art.gebakken(), voor, "cachetreffer bakt niet opnieuw")

func test_spel_mag_geen_wereldmodel_kapen() -> void:
	# `registreer_model("bed", ...)` pushes an engine error on purpose, and the
	# runner counts an engine error as a failed test — so the refusal itself is
	# asserted through `is_wereldmodel`, not by provoking the error here.
	for naam in ["bed", "kar", "gast_hond", "kom", "pol0"]:
		waar(Art.is_wereldmodel(naam), "'%s' is een beschermd wereldmodel" % naam)
	waar(Art.registreer_model("proef4_bed", func(_p): return [
		{"x": 0, "y": 0, "z": 0, "k": Color.RED}]), "een eigen naam mag wel")
	waar(Art.heeft_model("proef4_bed"), "eigen model staat in het register")
	waar(not Art.is_wereldmodel("proef4_bed"), "eigen model is niet beschermd")

# ------------------------------------------------------------------- de vloer
#
# `scenes/vloer.gd` (W1) is the only floor renderer; this is the colour table it
# reads.  The tests below feed it BOTH shapes it has to accept: a plain
# Dictionary and a `Rooms.Kamer` record straight out of the room list.

func test_vloerkleur_volgt_de_regels() -> void:
	# hout (receptie): every 4th row dark, else PLANK[(z>>2)&1]
	var hout := {"w": 120, "d": 120, "vloer": "hout"}
	gelijk(ArtVloer.kleur(hout, 5, 2), ArtVloer.PLANK_D, "hout: rij 0 is donker")
	gelijk(ArtVloer.kleur(hout, 5, 4), ArtVloer.PLANK[1], "hout: rij 1")
	gelijk(ArtVloer.kleur(hout, 5, 8), ArtVloer.PLANK[0], "hout: rij 2")
	# tegel: a 4 x 4 checker
	var tegel := {"w": 40, "d": 40, "vloer": "tegel"}
	gelijk(ArtVloer.kleur(tegel, 0, 0), ArtVloer.TEGEL[0], "tegel 0,0")
	gelijk(ArtVloer.kleur(tegel, 4, 0), ArtVloer.TEGEL[1], "tegel 4,0")
	gelijk(ArtVloer.kleur(tegel, 4, 4), ArtVloer.TEGEL[0], "tegel 4,4")
	# loper (gang): a runner between z 8 and d - 6
	var loper := {"w": 120, "d": 36, "vloer": "loper"}
	gelijk(ArtVloer.kleur(loper, 0, 12), ArtVloer.LOPER_M[0], "loper: midden")
	gelijk(ArtVloer.kleur(loper, 4, 12), ArtVloer.LOPER_M[1], "loper: volgende baan")
	waar(ArtVloer.LOPER.has(ArtVloer.kleur(loper, 4, 2)), "loper: rand")
	# zacht (kamer 1 en 2)
	var zacht := {"w": 114, "d": 114, "vloer": "zacht"}
	gelijk(ArtVloer.kleur(zacht, 7, 0), ArtVloer.ZACHT[0], "zacht: rij 0")
	gelijk(ArtVloer.kleur(zacht, 7, 4), ArtVloer.ZACHT[1], "zacht: rij 1")
	# gras (tuin): meadow outside the fence, grass inside
	var tuin := {"w": 130, "d": 130, "vloer": "gras"}
	waar(ArtVloer.WEI.has(ArtVloer.kleur(tuin, 2, 40)), "wei buiten het hek")
	waar(ArtVloer.GRAS.has(ArtVloer.kleur(tuin, 40, 40)), "gras binnen het hek")
	# bad (zwembad): water, a darker edge and a nearly white stone rim
	var zwem := {"w": 144, "d": 88, "vloer": "tegel", "bad": {"x0": 18, "x1": 134, "z0": 12, "z1": 44}}
	waar(ArtVloer.BADWATER.has(ArtVloer.kleur(zwem, 70, 28)), "water in het midden")
	waar(ArtVloer.BADKANT.has(ArtVloer.kleur(zwem, 19, 28)), "donkere waterrand")
	waar(ArtVloer.BADRAND.has(ArtVloer.kleur(zwem, 16, 28)), "steenrand om het bad")
	waar(ArtVloer.TEGEL.has(ArtVloer.kleur(zwem, 70, 70)), "tegels buiten de rand")
	# a mat wins over everything.  `matten` is ONE Dictionary on a Rooms.Kamer;
	# a list of them is accepted too, because the HTML has a list.
	var kl := [Color("#E9BFC9"), Color("#E3B4C0")]
	var een := {"x0": 45, "z0": 78, "x1": 99, "z1": 114, "kl": kl}
	for vorm in [een, [een], {}, []]:
		var mat := {"w": 120, "d": 120, "vloer": "hout", "matten": vorm}
		var raak: bool = (vorm is Dictionary and not (vorm as Dictionary).is_empty()) \
			or (vorm is Array and not (vorm as Array).is_empty())
		if raak:
			waar(kl.has(ArtVloer.kleur(mat, 60, 90)), "de mat wint (%s)" % typeof(vorm))
		else:
			gelijk(ArtVloer.kleur(mat, 60, 90), ArtVloer.kleur(hout, 60, 90),
				"geen mat, gewoon hout (%s)" % typeof(vorm))
		gelijk(ArtVloer.kleur(mat, 60, 10), ArtVloer.kleur(hout, 60, 10), "buiten de mat hout")

## A `Rooms.Kamer` is an object, not a Dictionary: `kleur()` has to read it with
## `Object.get()` or it crashes on the first tile of the first room.
func test_vloerkleur_slikt_een_kamerrecord() -> void:
	var lijst: Array = Rooms.lijst()
	waar(lijst.size() > 0, "er zijn kamers")
	for id in lijst:
		var r = Rooms.get_kamer(id)
		if r == null:
			continue
		waar(not (r is Dictionary), "%s is een Kamer-record, geen Dictionary" % id)
		var punten := [[0, 0], [4, 4], [int(r.w) / 2, int(r.d) / 2], [int(r.w) - 1, int(r.d) - 1]]
		for p in punten:
			var kl := ArtVloer.kleur(r, int(p[0]), int(p[1]))
			waar(kl.a > 0.99, "%s (%d,%d) geeft een kleur" % [id, p[0], p[1]])
		# and Art's door gives exactly the same answer
		gelijk(Art.vloer_kleur(r, 12, 12), ArtVloer.kleur(r, 12, 12), "%s via Art" % id)

## The speckle is a hash, so the same tile always has the same colour.
func test_vloerkleur_is_stabiel() -> void:
	var tuin := {"w": 130, "d": 130, "vloer": "gras"}
	for i in 20:
		gelijk(ArtVloer.kleur(tuin, 40 + i, 40), ArtVloer.kleur(tuin, 40 + i, 40),
			"zelfde vakje, zelfde kleur")
	gelijk(Sommen.hash2(40, 40), Sommen.hash2(40, 40), "hash2 is stabiel")
	waar(not Art.has_method("vloer_plaat"),
		"er is maar een vloertekenaar: de mesh van scenes/vloer.gd")

# -------------------------------------------------------------------- effecten

func test_zzz_is_getekend_geen_emoji() -> void:
	var r := ArtEffect.zzz_rechthoeken(4, 1)
	gelijk(r.size(), 12, "drie z-jes van vier blokjes")
	# small to large, and all of them above the guest's floor point
	for rect in r:
		waar(rect.position.y < 0, "een z-je hangt boven de kop")
	var links := ArtEffect.zzz_rechthoeken(4, -1)
	gelijk(links.size(), 12, "gespiegeld even veel")
	waar(links[0].position.x < 0 and r[0].position.x > 0, "gespiegeld dier, gespiegelde z-jes")
	gelijk(ArtEffect.ZZZ_KL, Color("#7E6255"), "de zachte neuskleur, nooit hard")

func test_schaduwen() -> void:
	gelijk(ArtEffect.grondschaduw(4), Vector2(32, 16), "staande schaduw r=8")
	gelijk(ArtEffect.grondschaduw(4, "zit"), Vector2(28, 14), "zittend r=7")
	gelijk(ArtEffect.grondschaduw(4, "sip"), Vector2(28, 14), "sip r=7")
	gelijk(ArtEffect.SCHADUW_ALFA, 0.15, "wereldschaduw alfa")
	var k := ArtEffect.kaart_schaduw(4)
	gelijk(k.size(), 2, "twee ruiten over elkaar")
	# the inset shifts both x0 and z0 by 2, so the rhombus keeps its screen x and
	# drops on screen: that is exactly the overlap that darkens the middle.
	gelijk(k[1][0].x, k[0][0].x, "zelfde schermbreedte")
	waar(k[1][0].y > k[0][0].y, "de binnenste ruit ligt lager, dus binnen de buitenste")
	waar(k[1][1].x < k[0][1].x, "en is smaller")

func test_pluis() -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 7
	var kruimels := ArtEffect.pluis(ArtEffect.KRUIMEL_N, 10.0, 20.0, ArtEffect.KRUIMEL_KL, false, rnd)
	gelijk(kruimels.size(), 3, "drie kruimels")
	for q in kruimels:
		gelijk(q["t"], 7, "kruimel leeft 7 tikken")
		gelijk(q["g"], 0.5, "kruimel valt")
		waar(q["vy"] < 0.0, "kruimel springt eerst omhoog")
		waar(absf(q["x"] - 10.0) <= 7.0, "spreiding x +- 7")
	var sterren := ArtEffect.pluis(ArtEffect.STER_N, 0.0, 0.0, ArtEffect.STER_KL[0], true, rnd)
	gelijk(sterren.size(), 2, "twee sterretjes")
	gelijk(sterren[0]["t"], 9, "sterretje leeft 9 tikken")
	gelijk(sterren[0]["g"], 0.08, "sterretje hangt")
	# a particle dies after its life and the list empties itself
	for i in 12:
		ArtEffect.pluis_stap(kruimels)
	gelijk(kruimels.size(), 0, "kruimels ruimen zichzelf op")
	var q2 := ArtEffect.pluis(1, 0.0, 0.0, ArtEffect.KRUIMEL_KL, false, rnd)
	gelijk(ArtEffect.pluis_maat(q2[0], 4), 6, "kruimel is 6 px bij g=4")
	gelijk(ArtEffect.pluis_alfa(q2[0]), 1.0, "vers deeltje is dekkend")

## The water band lands ONLY on the guest's own pixels: never a puddle beside
## him on the pool rim (art-sound-rules.md §11.5).
func test_water_alleen_op_de_zwemmer() -> void:
	var basis = Art.dier("hond", "rust", 4)
	var kaal: Image = basis.tex.get_image()
	var top := float(kaal.get_height()) * 0.6
	# the cut with the water is an ellipse — the surface seen from above — so the
	# line stands `ry` higher at the back than at the front
	var ry := maxf(2.0, minf(float(kaal.get_width()) / 2.0 * 0.42, 5.0 * 4))
	var nat := ArtEffect.water_over(kaal, top, 4)
	gelijk(nat.get_size(), kaal.get_size(), "zelfde plaatmaat")
	var anders := 0
	var buiten := 0
	var boven := 0
	for y in kaal.get_height():
		for x in kaal.get_width():
			var a: Color = kaal.get_pixel(x, y)
			var b: Color = nat.get_pixel(x, y)
			if a == b:
				continue
			anders += 1
			if a.a <= 0.0:
				buiten += 1
			if float(y) < floor(top - ry):
				boven += 1
	waar(anders > 100, "er ligt echt water op het dier (%d pixels)" % anders)
	gelijk(buiten, 0, "geen plas naast het dier")
	gelijk(boven, 0, "niets boven de waterlijn en zijn ellips")
	var p = Art.water_plaat("hond", "rust", 4, int(float(kaal.get_height()) * 0.6))
	waar(p != null and p.dx == basis.dx and p.dy == basis.dy, "waterplaat houdt dezelfde offset")

## Re-registering a name throws away what was baked from the old function —
## a game may replace its own model (last one wins) and must not keep drawing
## the old shape.
func test_opnieuw_aanmelden_gooit_de_plaat_weg() -> void:
	Art.registreer_model("proef4_wissel", func(_p): return [
		{"x": 0, "y": 0, "z": 0, "k": Color.RED}])
	var een = Art.plaat("proef4_wissel", 4)
	waar(een != null, "eerste vorm bakt")
	var voor: int = Art.gebakken()
	Art.plaat("proef4_wissel", 4)
	gelijk(Art.gebakken(), voor, "tweede aanroep komt uit de cache")
	Art.registreer_model("proef4_wissel", func(_p): return [
		{"x": 0, "y": 0, "z": 0, "k": Color.RED},
		{"x": 1, "y": 0, "z": 0, "k": Color.BLUE},
		{"x": 2, "y": 0, "z": 0, "k": Color.GREEN}])
	var twee = Art.plaat("proef4_wissel", 4)
	waar(twee != null and twee.w > een.w, "de nieuwe vorm is echt opnieuw gebakken")

## `rondAf` shaves one pixel off every staircase corner.  With a contour behind
## it the pass provably cannot fire (every neighbour of a shape pixel carries
## the contour's alpha), so the bowl's front wall — the one plate that is drawn
## without a contour of its own — is where it has to show.
func test_rondaf_bijt_alleen_zonder_omlijning() -> void:
	var voor = Art.kom(4, 4, true)
	var achter = Art.kom(4, 4, false)
	var t := 0
	var img: Image = voor.tex.get_image()
	for y in img.get_height():
		for x in img.get_width():
			if int(round(img.get_pixel(x, y).a * 255.0)) == 112:
				t += 1
	waar(t > 0, "de voorwand heeft afgeronde hoeken (%d pixels op alfa 112)" % t)
	# and the back wall carries the contour, so it has the ink alpha 66
	var inkt := 0
	var b: Image = achter.tex.get_image()
	for y in b.get_height():
		for x in b.get_width():
			if int(round(b.get_pixel(x, y).a * 255.0)) == 66:
				inkt += 1
	waar(inkt > 0, "de achterwand draagt de contour (%d pixels op alfa 66)" % inkt)
