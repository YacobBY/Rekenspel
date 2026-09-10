extends Node
## Art — the voxel baker.  Autoload #1 (nothing depends on it at _ready time).
##
## DECISION (architecture.md §3): the voxel models of art-sound-rules.md are
## re-drawn procedurally in GDScript and baked into an `ImageTexture` per
## (model, params, g); the world then only blits those textures.  No sprite
## sheets: several models take geometry-changing parameters (klok, steen, trap,
## was_krat) and plates are not integer rescales of one another.
##
## The rasteriser is CPU-side (one prepared face stamp per shape/scale/colour,
## blended with `Image.blend_rect`) instead of a SubViewport read-back, so a
## bake is deterministic, needs no GPU round trip on the single-threaded web
## build, and can run in `--headless` — which is what makes the golden-image
## test against tests/gouden/*.png possible in CI.
##
## What lives where:
##   art/vorm.gd    the five build primitives (bx, ell, hals, punt, verf)
##   art/gasten.gd  the four guests, 15 poses, 3 accessories, the feeding bowl
##   art/decor.gd   the 33 built-in decor models of rooms.js
##   art/vloer.gd   the colour of one floor tile (the floor itself is W1's mesh)
##   art/effect.gd  particles, the sleep mark, the shadows, the water band
## This file owns the register, the bake and the plate cache, and nothing else.

## Voxel geometry (art.js `Art.kit`): one voxel is 4g px wide and 4g px tall.
const S := 2
const HG := 2
const PAD := 2  ## canvas px of padding around a plate, NOT scaled by g

## Light and shading (art-sound-rules.md §3).
const F_TOP := 1.10
const F_RECHTS := 0.90
const F_LINKS := 0.72
const AO := [1.0, 0.972, 0.946, 0.928, 0.914]
const WARM := Vector3(255, 248, 236)
const KOEL := Vector3(116, 100, 116)

## Silhouette treatment (art-sound-rules.md §1.6).
const OMLIJN_KLEUR := Color(112.0 / 255.0, 90.0 / 255.0, 76.0 / 255.0, 0.26)
const PLAAT_MAX := 110  ## LRU size of the plate cache
const VLAK_MAX := 90    ## LRU size of the culled-face cache (art.js poseCache)
const STEMPEL_MAX := 800  ## soft cap on the (shape, scale, shade) stamp cache

## Anchors in voxels (art-sound-rules.md §1.5).
const DIER_ANKER := Vector2(13, 7.5)      ## centre of the four paws
const KOM_ANKER := Vector2(29.5, 7.5)     ## centre of the feeding bowl

enum Vlak {TOP, RECHTS, LINKS}

## A baked plate.  `tex` is drawn at (anker.x * g + dx, anker.y * g + dy).
class Plaat extends RefCounted:
	var tex: ImageTexture
	var dx: int
	var dy: int
	var w: int
	var h: int
	func _init(t: ImageTexture, x: int, y: int) -> void:
		tex = t
		dx = x
		dy = y
		w = t.get_width()
		h = t.get_height()

var _modellen: Dictionary = {}      ## naam -> Callable(params) -> Array voxels
var _beschermd: Dictionary = {}     ## world model names a game may not take
var _plaat_cache: Dictionary = {}   ## sleutel -> Plaat
var _plaat_orde: Array[String] = [] ## LRU, oldest first
var _vlak_cache: Dictionary = {}    ## sleutel -> the culled face list (scale free)
var _vlak_orde: Array[String] = []  ## LRU, oldest first
var _stempels: Dictionary = {}      ## rgb << 8 | g << 2 | vlak -> [Image, ox, oy]
var _span_cache: Dictionary = {}    ## "vlak|g" -> Array of [y, x0, breedte]
var _tint_cache: Dictionary = {}    ## rgb << 4 | (vlak * 5 + buren) -> tinted rgb
var _bakken := 0                    ## how many plates were baked this session

signal model_geregistreerd(naam: String)

func _ready() -> void:
	_registreer_ingebouwd()
	_bakmeting_misschien()

# ------------------------------------------------------------- bakmeting (web)
##
## architecture.md §3.5 budgets <= 25 ms per plate **in the browser**, and there
## is no way to time a wasm bake from the outside: the console only sees what
## the game prints.  So the web build answers a query flag.  Open the export as
## `index.html?bakmeting` and `Art` bakes the model set of the receptie and of
## the tuin at the scale the world actually chose, and prints one `[probe]` line
## per room.  Without the flag not a line and not a microsecond is spent, so the
## real game never pays for the measurement.
func _bakmeting_misschien() -> void:
	if not OS.has_feature("web"):
		return
	var zoek := str(JavaScriptBridge.eval("location.search", true))
	if not zoek.contains("bakmeting"):
		return
	_bakmeting.call_deferred()

func _bakmeting() -> void:
	# two frames: every autoload has had its _ready and the world has a scale
	await get_tree().process_frame
	await get_tree().process_frame
	var wortel := get_tree().root
	var kamers = wortel.get_node_or_null(^"Rooms")
	var wereld = wortel.get_node_or_null(^"World")
	var g := 4
	if wereld != null and wereld.has_method("schaal"):
		g = int(wereld.schaal()["g"])
	for kid in ["receptie", "tuin"]:
		var werk := _kamerwerk(kamers, kid)
		wis_platen()
		var voor := _bakken
		var t0 := Time.get_ticks_usec()
		var ergst := 0.0
		var ergste := ""
		for stuk in werk:
			var t1 := Time.get_ticks_usec()
			plaat(stuk[0], g, stuk[1])
			var d := (Time.get_ticks_usec() - t1) / 1000.0
			if d > ergst:
				ergst = d
				ergste = String(stuk[0])
		print("[probe] bakmeting kamer=", kid, " g=", g, " stukken=", werk.size(),
			" gebakken=", _bakken - voor,
			" ms=", "%.1f" % ((Time.get_ticks_usec() - t0) / 1000.0),
			" ergste=", ergste, " ", "%.1f" % ergst)
	wis_platen()
	print("[probe] bakmeting klaar")

## Everything a room has to bake when you walk into it: its decor (with the
## parameters it carries), the models of its slots, and the four guests — the
## upper bound, because the hotel is never fuller than its four beds.
func _kamerwerk(kamers, kid: String) -> Array:
	var uit: Array = []
	var gezien := {}
	var voeg := func(naam: String, params: Dictionary) -> void:
		var sl := naam + JSON.stringify(params)
		if naam.is_empty() or gezien.has(sl) or not _modellen.has(naam):
			return
		gezien[sl] = true
		uit.append([naam, params])
	if kamers != null and kamers.has_method("get_kamer"):
		var r = kamers.get_kamer(kid)
		if r != null:
			for stuk in r.decor:
				voeg.call(String(stuk.get("n", "")), stuk.get("params", {}))
			for sid in r.slots:
				voeg.call(String(r.slots[sid].get("model", "")), {})
	for kind in ArtGasten.SOORTEN:
		voeg.call("gast_" + kind, {"pose": "rust"})
	return uit


# ------------------------------------------------------------ modelregister
##
## Two doors into the register (architecture.md §13, Q-X1-11):
##  * `registreer_wereldmodel()` — the world's own models (W1/W4).  These names
##    are PROTECTED: a game can never take one over.
##  * `registreer_model()` — a game's own model.  The name must be qualified
##    with the game id (`wekker_klok`), so two games can both have a `klok`.

## World model (W1/W4).  Protected from that moment on.
func registreer_wereldmodel(naam: String, fn: Callable) -> bool:
	if naam.is_empty() or not fn.is_valid():
		return false
	_modellen[naam] = fn
	_beschermd[naam] = true
	_vergeet(naam)
	model_geregistreerd.emit(naam)
	return true

## A game's own model.  Rejects a bare name that collides with a world model.
func registreer_model(naam: String, fn: Callable) -> bool:
	if naam.is_empty() or not fn.is_valid():
		return false
	if _beschermd.has(naam):
		push_error("Art.registreer_model: '%s' is een wereldmodel; noem het '<spel>_%s'"
			% [naam, naam])
		return false
	var spel := Games.actief()
	if spel != "" and not naam.begins_with(spel + "_"):
		push_warning("Art.registreer_model: noem '%s' liever '%s_%s' (§13 Q-X1-11)"
			% [naam, spel, naam])
	_modellen[naam] = fn
	_vergeet(naam)
	model_geregistreerd.emit(naam)
	return true

## Re-registering a name (a game may, last one wins) has to throw away what was
## baked from the old function, or the world would keep drawing the old shape.
func _vergeet(naam: String) -> void:
	var voor := naam + "|"
	for sleutel in _plaat_orde.duplicate():
		if sleutel.begins_with(voor):
			_plaat_orde.erase(sleutel)
			_plaat_cache.erase(sleutel)
	for sleutel in _vlak_orde.duplicate():
		if sleutel.begins_with(voor):
			_vlak_orde.erase(sleutel)
			_vlak_cache.erase(sleutel)

func heeft_model(naam: String) -> bool:
	return _modellen.has(naam)

func is_wereldmodel(naam: String) -> bool:
	return _beschermd.has(naam)

## Returns the voxel list of a model: Array of {x, y, z, k: Color}.
func model(naam: String, params: Dictionary = {}) -> Array:
	if not _modellen.has(naam):
		return []
	var fn: Callable = _modellen[naam]
	return fn.call(params)

## Every name the world owns: 33 decor models (art-sound-rules.md §8), the four
## guests and the bowl (which have their own entry points below).
func _registreer_ingebouwd() -> void:
	var tabel := ArtDecor.tabel()
	for naam in tabel:
		registreer_wereldmodel(naam, tabel[naam])
	for n in ArtDecor.POL_AANTAL:
		registreer_wereldmodel("pol%d" % n, _pol_fn(n))
	# The four guests and the bowl also answer to the generic door, so a
	# WereldObject can carry one without knowing anything about poses:
	#   Art.plaat("gast_hond", g, {"pose": "loopA", "acc": "hoedje"})
	#   Art.plaat("kom", g, {"niveau": 2})
	# The split halves of the bowl (the front wall is drawn after the animal)
	# come from `Art.kom()`, which needs a face-level split.
	for kind in ArtGasten.SOORTEN:
		registreer_wereldmodel("gast_" + kind, _gast_fn(kind))
	registreer_wereldmodel("kom", func(params := {}):
		return ArtGasten.kom_vox(int(params.get("niveau", 0)), bool(params.get("groot", true))))

func _pol_fn(n: int) -> Callable:
	return func(_params := {}): return ArtDecor.pol(n)

func _gast_fn(kind: String) -> Callable:
	return func(params := {}):
		return ArtGasten.bouw(kind, params.get("pose", "rust"),
			ArtGasten.acc_sleutel(params.get("acc", null)))

# --------------------------------------------------------------- het bakken

## The plate for one model at voxel size `g`.  Cached (LRU).
func plaat(naam: String, g: int, params: Dictionary = {}) -> Plaat:
	var vsl := "%s|%s" % [naam, JSON.stringify(params)]
	var sleutel := "%s|%d" % [vsl, g]
	return plaat_van(sleutel, func():
		return _bak_model(vsl, g, func(): return model(naam, params)))

## The generic LRU door (`haalPlaat` in art.js): any caller that can name its
## own plate uniquely may bake through it.  `maak` returns a Plaat or null.
func plaat_van(sleutel: String, maak: Callable) -> Plaat:
	if _plaat_cache.has(sleutel):
		_plaat_orde.erase(sleutel)
		_plaat_orde.append(sleutel)
		return _plaat_cache[sleutel]
	var p = maak.call()
	if p == null:
		return null
	_plaat_cache[sleutel] = p
	_plaat_orde.append(sleutel)
	while _plaat_orde.size() > PLAAT_MAX:
		var oud: String = _plaat_orde.pop_front()
		_plaat_cache.erase(oud)
	return p

func gebakken() -> int:
	return _bakken

## Diagnostic (art.js `Art.stats()`): how big a model is before it is baked.
## {voxels: raw list length, vlakken: culled faces, lxhxd: Vector3i}
func census(voxels: Array) -> Dictionary:
	var b := [1 << 30, -(1 << 30), 1 << 30, -(1 << 30), 1 << 30, -(1 << 30)]
	for p in voxels:
		b[0] = mini(b[0], p["x"]); b[1] = maxi(b[1], p["x"])
		b[2] = mini(b[2], p["y"]); b[3] = maxi(b[3], p["y"])
		b[4] = mini(b[4], p["z"]); b[5] = maxi(b[5], p["z"])
	return {"voxels": voxels.size(), "vlakken": _vlakken(voxels)["n"],
		"lxhxd": Vector3i(b[1] - b[0] + 1, b[3] - b[2] + 1, b[5] - b[4] + 1)}

func platen_in_cache() -> int:
	return _plaat_orde.size()

func wis_platen() -> void:
	_plaat_cache.clear()
	_plaat_orde.clear()
	_vlak_cache.clear()
	_vlak_orde.clear()
	_stempels.clear()

## Bake through the scale-free face cache: the voxel list is only BUILT when
## the culled faces of that model are not in the cache yet, so a second scale
## costs the rasteriser and nothing else (art.js keeps `poseCache` the same way).
func _bak_model(vsl: String, g: int, maak: Callable, opties: Dictionary = {}) -> Plaat:
	opties["vlaksleutel"] = vsl
	var vox: Array = [] if _vlak_cache.has(vsl) else maak.call()
	return bak(vox, g, opties)

# ---------------------------------------------------------------- de gasten

## One guest: species, pose, voxel size, accessories (a list, a comma string or
## nothing).  Mirroring is `flip_h` at draw time — no mirrored textures.
func dier(kind: String, pose: String, g: int, acc = null) -> Plaat:
	var sleutel := ArtGasten.acc_sleutel(acc)
	var vsl := "d|%s|%s%s" % [kind, pose, "" if sleutel.is_empty() else "|" + sleutel]
	return plaat_van("%s|%d" % [vsl, g], func():
		return _bak_model(vsl, g, func(): return ArtGasten.bouw(kind, pose, sleutel)))

## The feeding bowl.  `voor` splits the plate: the front wall is drawn AFTER the
## guest (so it can bite into the bowl) and carries no contour of its own —
## the contour is computed over the whole bowl so both halves share one ring.
func kom(niv: int, g: int, voor: bool, groot := true) -> Plaat:
	var vsl := "k|%d|%d" % [niv, 1 if groot else 0]
	var k := "%s|%d|%d" % [vsl, g, 1 if voor else 0]
	return plaat_van(k, func():
		return _bak_model(vsl, g, func(): return ArtGasten.kom_vox(niv, groot),
			{"voor": 1 if voor else 0, "omlijn": not voor, "silhouet_alles": not voor}))

## `Art.niveau(aantal, per)` — how full the bowl looks, 0..4.
func niveau(aantal: int, per: int) -> int:
	return ArtGasten.niveau(aantal, per)

# ------------------------------------------------------------------ de bakoven

## Bake a voxel list into a plate.  This is the whole renderer.
##
## `opties` (all optional, the defaults are the plain case):
##   voor            -1 = every face (default) · 0 / 1 = only that group
##   omlijn          true (default) · false = no contour of its own
##   silhouet_alles  false (default) · true = box and contour over EVERY face,
##                   not only the selected group (the bowl's back wall)
##   vlaksleutel     cache name for the culled face list; the same list serves
##                   every scale, exactly as art.js keeps `poseCache`
func bak(voxels: Array, g: int, opties: Dictionary = {}) -> Plaat:
	if g <= 0:
		return null
	var sleutel: String = opties.get("vlaksleutel", "")
	var alles: Dictionary = {}
	if not sleutel.is_empty() and _vlak_cache.has(sleutel):
		_vlak_orde.erase(sleutel)
		_vlak_orde.append(sleutel)
		alles = _vlak_cache[sleutel]
	else:
		if voxels.is_empty():
			return null
		alles = _vlakken(voxels)
		if not sleutel.is_empty():
			_vlak_cache[sleutel] = alles
			_vlak_orde.append(sleutel)
			while _vlak_orde.size() > VLAK_MAX:
				_vlak_cache.erase(_vlak_orde.pop_front())
	if alles["n"] == 0:
		return null
	_bakken += 1
	var deel: int = opties.get("voor", -1)
	var lijst := alles if deel < 0 else _splits(alles, deel)
	var omlijnen: bool = opties.get("omlijn", true)
	var alles_sil: bool = opties.get("silhouet_alles", false)
	var bron := alles if alles_sil else lijst
	if bron["n"] == 0:
		bron = lijst
	# plate geometry (art-sound-rules.md §1.5): the box is taken over the FACES,
	# exactly as `extent()` does — a voxel whose three faces are all culled adds
	# nothing to the plate.
	var box := _doos(bron if bron["n"] > 0 else lijst)
	var w: int = maxi(1, (box[1] - box[0]) * g + 2 * PAD)
	var h: int = maxi(1, (box[3] - box[2]) * g + 2 * PAD)
	var dx: int = box[0] * g - PAD
	var dy: int = box[2] * g - PAD
	var ox: int = -box[0] * g + PAD
	var oy: int = -box[2] * g + PAD
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	_teken_lijst(img, lijst, g, ox, oy, false)
	if omlijnen:
		var dik := maxi(1, JsGetal.rond(float(g) / 2.6))
		var dil := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		# The contour is a Manhattan dilation of the silhouette; dilating each
		# face stamp once and stamping THAT is the same set (dilation
		# distributes over a union) and costs a fraction of dilating the whole
		# plate 2w^2 + 2w + 1 times.
		_teken_lijst(dil, bron, g, ox, oy, true, dik)
		img = _omlijn(img, dil)
		if g >= 2:
			_rond_af(img, true)
	elif g >= 2:
		_rond_af(img, false)
	return Plaat.new(ImageTexture.create_from_image(img), dx, dy)

## Voxels -> a culled face list in painter order.  The result is a bundle of
## parallel packed arrays, which is what keeps a bake inside its budget:
## a Dictionary of 11 000 voxels costs more in hashing than the whole raster.
##
##   px, py : voxel-px position of the face origin
##   ct, cr, cl : the shaded colour of the top / right / left face, -1 = culled
##   voor : the "drawn after the animal" flag of the feeding bowl
func _vlakken(voxels: Array) -> Dictionary:
	var leeg := {"n": 0, "px": PackedInt32Array(), "py": PackedInt32Array(),
		"ct": PackedInt32Array(), "cr": PackedInt32Array(), "cl": PackedInt32Array(),
		"voor": PackedByteArray()}
	var n := voxels.size()
	if n == 0:
		return leeg
	var x0 := 1 << 30; var x1 := -(1 << 30)
	var y0 := 1 << 30; var y1 := -(1 << 30)
	var z0 := 1 << 30; var z1 := -(1 << 30)
	# One pass over the dictionaries, into packed arrays: every later pass then
	# reads integers instead of hashing a key.  On an 11 000-voxel model that is
	# the difference between a comfortable bake and a stutter.
	var vx := PackedInt32Array(); vx.resize(n)
	var vy := PackedInt32Array(); vy.resize(n)
	var vz := PackedInt32Array(); vz.resize(n)
	var vk := PackedInt32Array(); vk.resize(n)
	var vv0 := PackedByteArray(); vv0.resize(n)
	var i0 := 0
	for v in voxels:
		var x: int = v["x"]; var y: int = v["y"]; var z: int = v["z"]
		if x < x0: x0 = x
		if x > x1: x1 = x
		if y < y0: y0 = y
		if y > y1: y1 = y
		if z < z0: z0 = z
		if z > z1: z1 = z
		var kl: Color = v["k"]
		vx[i0] = x; vy[i0] = y; vz[i0] = z
		# `int(c * 255 + 0.5)` is Math.round for a value in 0..1, without the
		# static call: this line runs once per voxel.
		vk[i0] = (int(kl.r * 255.0 + 0.5) << 16) | (int(kl.g * 255.0 + 0.5) << 8) \
			| int(kl.b * 255.0 + 0.5)
		if v.has("voor") and v["voor"]:
			vv0[i0] = 1
		i0 += 1
	var bd := z1 - z0 + 3
	var bh := y1 - y0 + 3
	var bw := x1 - x0 + 3
	var groot := bw * bh * bd
	if groot <= 0 or groot > 16000000:
		push_error("Art.bak: model te groot voor het raster (%d cellen)" % groot)
		return leeg
	var sy := bd
	var sx := bh * bd
	var bezet := PackedByteArray(); bezet.resize(groot)
	var kleur := PackedInt32Array(); kleur.resize(groot)
	var voorv := PackedByteArray(); voorv.resize(groot)
	var volg := PackedInt32Array(); volg.resize(n)
	var xyz := PackedInt32Array(); xyz.resize(n)
	var m := 0
	for j in n:
		var x := vx[j]; var y := vy[j]; var z := vz[j]
		var i := (x - x0 + 1) * sx + (y - y0 + 1) * sy + (z - z0 + 1)
		# a later voxel on the same spot overwrites the colour but not the place
		# in the paint order — exactly what a JS object keyed by position does
		kleur[i] = vk[j]
		voorv[i] = vv0[j]
		if bezet[i] == 0:
			bezet[i] = 1
			volg[m] = i
			xyz[m] = ((x + 512) << 20) | ((y + 512) << 10) | (z + 512)
			m += 1
	# emit the visible faces in insertion order, then counting-sort on
	# d = x + y + z (a stable bucket sort: Array.prototype.sort is stable too)
	var px := PackedInt32Array(); px.resize(m)
	var py := PackedInt32Array(); py.resize(m)
	var ct := PackedInt32Array(); ct.resize(m)
	var cr := PackedInt32Array(); cr.resize(m)
	var cl := PackedInt32Array(); cl.resize(m)
	var vv := PackedByteArray(); vv.resize(m)
	var fd := PackedInt32Array(); fd.resize(m)
	var dmin := x0 + y0 + z0
	var dspan := (x1 - x0) + (y1 - y0) + (z1 - z0) + 1
	var telling := PackedInt32Array(); telling.resize(dspan + 1)
	var nf := 0
	for j in m:
		var i := volg[j]
		var t := bezet[i + sy] == 0
		var r := bezet[i + sx] == 0
		var l := bezet[i + 1] == 0
		if not t and not r and not l:
			continue
		var p := xyz[j]
		var x := (p >> 20) - 512
		var y := ((p >> 10) & 1023) - 512
		var z := (p & 1023) - 512
		var rgb := kleur[i]
		px[nf] = (x - z) * S
		py[nf] = (x + z) - (y + 1) * HG
		ct[nf] = -1
		cr[nf] = -1
		cl[nf] = -1
		if t:
			var b := 0
			if bezet[i + sy - sx] != 0: b += 1
			if bezet[i + sy + sx] != 0: b += 1
			if bezet[i + sy - 1] != 0: b += 1
			if bezet[i + sy + 1] != 0: b += 1
			ct[nf] = _tint(rgb, Vlak.TOP, b)
		if r:
			var b := 0
			if bezet[i + sx - sy] != 0: b += 1
			if bezet[i + sx + sy] != 0: b += 1
			if bezet[i + sx - 1] != 0: b += 1
			if bezet[i + sx + 1] != 0: b += 1
			cr[nf] = _tint(rgb, Vlak.RECHTS, b)
		if l:
			var b := 0
			if bezet[i + 1 - sy] != 0: b += 1
			if bezet[i + 1 + sy] != 0: b += 1
			if bezet[i + 1 - sx] != 0: b += 1
			if bezet[i + 1 + sx] != 0: b += 1
			cl[nf] = _tint(rgb, Vlak.LINKS, b)
		vv[nf] = voorv[i]
		fd[nf] = x + y + z - dmin
		telling[fd[nf]] += 1
		nf += 1
	var start := PackedInt32Array(); start.resize(dspan + 1)
	var loop := 0
	for b in dspan + 1:
		start[b] = loop
		loop += telling[b]
	var uit := {"n": nf,
		"px": PackedInt32Array(), "py": PackedInt32Array(), "ct": PackedInt32Array(),
		"cr": PackedInt32Array(), "cl": PackedInt32Array(), "voor": PackedByteArray()}
	var opx: PackedInt32Array = uit["px"]; opx.resize(nf)
	var opy: PackedInt32Array = uit["py"]; opy.resize(nf)
	var oct: PackedInt32Array = uit["ct"]; oct.resize(nf)
	var ocr: PackedInt32Array = uit["cr"]; ocr.resize(nf)
	var ocl: PackedInt32Array = uit["cl"]; ocl.resize(nf)
	var ovv: PackedByteArray = uit["voor"]; ovv.resize(nf)
	for k in nf:
		var b := fd[k]
		var q := start[b]
		start[b] = q + 1
		opx[q] = px[k]; opy[q] = py[k]
		oct[q] = ct[k]; ocr[q] = cr[k]; ocl[q] = cl[k]
		ovv[q] = vv[k]
	uit["px"] = opx; uit["py"] = opy
	uit["ct"] = oct; uit["cr"] = ocr; uit["cl"] = ocl; uit["voor"] = ovv
	return uit

## Only the faces with that `voor` flag (the bowl's two halves).
func _splits(bron: Dictionary, deel: int) -> Dictionary:
	var n: int = bron["n"]
	var vv: PackedByteArray = bron["voor"]
	var px := PackedInt32Array(); var py := PackedInt32Array()
	var ct := PackedInt32Array(); var cr := PackedInt32Array(); var cl := PackedInt32Array()
	var uv := PackedByteArray()
	var bpx: PackedInt32Array = bron["px"]
	var bpy: PackedInt32Array = bron["py"]
	var bct: PackedInt32Array = bron["ct"]
	var bcr: PackedInt32Array = bron["cr"]
	var bcl: PackedInt32Array = bron["cl"]
	for i in n:
		if vv[i] != deel:
			continue
		px.append(bpx[i]); py.append(bpy[i])
		ct.append(bct[i]); cr.append(bcr[i]); cl.append(bcl[i]); uv.append(vv[i])
	return {"n": px.size(), "px": px, "py": py, "ct": ct, "cr": cr, "cl": cl, "voor": uv}

func _doos(lijst: Dictionary) -> Array:
	var b := [1 << 30, -(1 << 30), 1 << 30, -(1 << 30)]
	var px: PackedInt32Array = lijst["px"]
	var py: PackedInt32Array = lijst["py"]
	for i in lijst["n"]:
		if px[i] - S < b[0]: b[0] = px[i] - S
		if px[i] + S > b[1]: b[1] = px[i] + S
		if py[i] < b[2]: b[2] = py[i]
		if py[i] + S + HG > b[3]: b[3] = py[i] + S + HG
	return b

## Draw a face list.  `masker` = draw the silhouette, dilated by `dik`, in one
## flat colour — that is how the contour is made.
func _teken_lijst(img: Image, lijst: Dictionary, g: int, ox: int, oy: int,
		masker: bool, dik := 0) -> void:
	var breed := img.get_width()
	var hoog := img.get_height()
	var px: PackedInt32Array = lijst["px"]
	var py: PackedInt32Array = lijst["py"]
	var ct: PackedInt32Array = lijst["ct"]
	var cr: PackedInt32Array = lijst["cr"]
	var cl: PackedInt32Array = lijst["cl"]
	for i in lijst["n"]:
		var x := px[i] * g + ox
		var y := py[i] * g + oy
		if ct[i] >= 0:
			_stempel(img, Vlak.TOP, g, ct[i], x, y, breed, hoog, masker, dik)
		if cr[i] >= 0:
			_stempel(img, Vlak.RECHTS, g, cr[i], x, y, breed, hoog, masker, dik)
		if cl[i] >= 0:
			_stempel(img, Vlak.LINKS, g, cl[i], x, y, breed, hoog, masker, dik)

## One face, blended from a prepared stamp.  A stamp is made once per
## (shape, scale, colour); a model uses at most 3 x 5 shades per base colour, so
## the cache stays small and the whole bake is native blends.
func _stempel(img: Image, vlak: int, g: int, rgb: int, x: int, y: int,
		breed: int, hoog: int, masker: bool, dik: int) -> void:
	# the key carries g: the same colour is a different stamp at another scale
	var sl := ((rgb << 8) | (g << 2) | vlak) if not masker else -(g * 4 + vlak + 1)
	var st: Array = _stempels.get(sl, [])
	if st.is_empty():
		if _stempels.size() > STEMPEL_MAX:
			_stempels.clear()   # a soft cap; they are rebuilt in microseconds
		st = _maak_stempel(vlak, g, rgb, masker, dik)
		_stempels[sl] = st
	var bron: Image = st[0]
	var dx: int = x + int(st[1])
	var dy: int = y + int(st[2])
	if dx >= breed or dy >= hoog or dx + bron.get_width() <= 0 or dy + bron.get_height() <= 0:
		return
	img.blend_rect(bron, Rect2i(Vector2i.ZERO, bron.get_size()), Vector2i(dx, dy))

func _maak_stempel(vlak: int, g: int, rgb: int, masker: bool, dik: int) -> Array:
	var spans := _spans(vlak, g)
	var x0 := 1 << 30; var x1 := -(1 << 30)
	var y0 := 1 << 30; var y1 := -(1 << 30)
	for sp in spans:
		x0 = mini(x0, int(sp[1]))
		x1 = maxi(x1, int(sp[1]) + int(sp[2]))
		y0 = mini(y0, int(sp[0]))
		y1 = maxi(y1, int(sp[0]) + 1)
	var rand := dik if masker else 0
	var kl := Color(1, 1, 1, 1) if masker else Color(float(rgb >> 16 & 255) / 255.0,
		float(rgb >> 8 & 255) / 255.0, float(rgb & 255) / 255.0, 1.0)
	var w := maxi(1, x1 - x0) + 2 * rand
	var h := maxi(1, y1 - y0) + 2 * rand
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for sp in spans:
		img.fill_rect(Rect2i(int(sp[1]) - x0 + rand, int(sp[0]) - y0 + rand, int(sp[2]), 1), kl)
	if rand > 0:
		var kaal := img.duplicate()
		var rect := Rect2i(Vector2i.ZERO, img.get_size())
		for ddx in range(-rand, rand + 1):
			for ddy in range(-rand, rand + 1):
				if absi(ddx) + absi(ddy) > rand or (ddx == 0 and ddy == 0):
					continue
				img.blend_rect(kaal, rect, Vector2i(ddx, ddy))
	return [img, x0 - rand, y0 - rand]

## `shade(hex, m)` — mix toward WARM above 1, toward KOEL below.  Returns the
## packed rgb, so a face list stays a PackedInt32Array.
func _tint(rgb: int, vlak: int, buren: int) -> int:
	var sleutel := (rgb << 4) | (vlak * 5 + buren)
	if _tint_cache.has(sleutel):
		return _tint_cache[sleutel]
	var f := F_TOP if vlak == Vlak.TOP else (F_RECHTS if vlak == Vlak.RECHTS else F_LINKS)
	var m: float = f * AO[buren]
	var doel := WARM if m >= 1.0 else KOEL
	var t := minf(1.0, (m - 1.0) * 1.25) if m >= 1.0 else minf(1.0, (1.0 - m) * 1.55)
	var c := Vector3(float(rgb >> 16 & 255), float(rgb >> 8 & 255), float(rgb & 255))
	var uit := c + (doel - c) * t
	var kl := (int(clampf(JsGetal.rond(uit.x), 0, 255)) << 16) \
		| (int(clampf(JsGetal.rond(uit.y), 0, 255)) << 8) \
		| int(clampf(JsGetal.rond(uit.z), 0, 255))
	_tint_cache[sleutel] = kl
	return kl

## Scanline spans of one face shape at scale g, relative to the voxel origin.
## Computed once per (shape, g).  The x-range of a row is taken over the whole
## row (y .. y+1) and rounded outward, which is what the JS 1-px stroke does.
func _spans(vlak: int, g: int) -> Array:
	var sleutel := "%d|%d" % [vlak, g]
	if _span_cache.has(sleutel):
		return _span_cache[sleutel]
	var lijst := _polygoon_spans(_punten(vlak, g))
	_span_cache[sleutel] = lijst
	return lijst

## The three face polygons of art-sound-rules.md §1.2, at scale g.
func _punten(vlak: int, g: int) -> Array[Vector2]:
	var b := S * g
	var d := HG * g
	match vlak:
		Vlak.TOP:
			return [Vector2(0, 0), Vector2(b, g), Vector2(0, b), Vector2(-b, g)]
		Vlak.RECHTS:
			return [Vector2(b, g), Vector2(0, b), Vector2(0, b + d), Vector2(b, g + d)]
	return [Vector2(-b, g), Vector2(0, b), Vector2(0, b + d), Vector2(-b, g + d)]

func _polygoon_spans(p: Array[Vector2]) -> Array:
	var y0 := INF
	var y1 := -INF
	for v in p:
		y0 = minf(y0, v.y)
		y1 = maxf(y1, v.y)
	var uit: Array = []
	var ry0 := int(floor(y0))
	var ry1 := int(ceil(y1))
	for y in range(ry0, ry1):
		var l := INF
		var r := -INF
		for t in [maxf(float(y), y0), minf(float(y + 1), y1)]:
			var sn := _snij(p, t)
			if sn.x <= sn.y:
				l = minf(l, sn.x)
				r = maxf(r, sn.y)
		if l > r:
			continue
		var x0 := int(floor(l))
		var x1 := int(ceil(r))
		if x1 > x0:
			uit.append([y, x0, x1 - x0])
	return uit

## x-interval of a convex polygon at height t.
func _snij(p: Array[Vector2], t: float) -> Vector2:
	var l := INF
	var r := -INF
	var n := p.size()
	for i in n:
		var a := p[i]
		var b := p[(i + 1) % n]
		if is_equal_approx(a.y, b.y):
			if is_equal_approx(a.y, t):
				l = minf(l, minf(a.x, b.x))
				r = maxf(r, maxf(a.x, b.x))
			continue
		var lo := minf(a.y, b.y)
		var hi := maxf(a.y, b.y)
		if t < lo - 0.0001 or t > hi + 0.0001:
			continue
		var f := (t - a.y) / (b.y - a.y)
		var x := a.x + (b.x - a.x) * f
		l = minf(l, x)
		r = maxf(r, x)
	return Vector2(l, r)

## `omlijn` — the soft dark contour, tinted from the dilated silhouette `dil`
## and drawn BEHIND the shape (`destination-over` in art.js).
func _omlijn(img: Image, dil: Image) -> Image:
	var breed := img.get_width()
	var hoog := img.get_height()
	var rect := Rect2i(0, 0, breed, hoog)
	var inkt := Image.create_empty(breed, hoog, false, Image.FORMAT_RGBA8)
	inkt.fill(OMLIJN_KLEUR)
	var uit := Image.create_empty(breed, hoog, false, Image.FORMAT_RGBA8)
	uit.blit_rect_mask(inkt, dil, rect, Vector2i.ZERO)
	uit.blend_rect(img, rect, Vector2i.ZERO)
	return uit

## `rondAf`: an opaque pixel (alpha >= 200) with two or more empty orthogonal
## neighbours (alpha < 40) drops to alpha 112 — one pixel off every staircase
## corner.  Only at g >= 2.
##
## With a contour behind it this pass provably cannot fire: the contour is a
## dilation by at least one pixel, so every orthogonal neighbour of a shape
## pixel carries alpha 66 and is not "empty".  The browser runs the loop
## anyway; here it is skipped, because the outcome is the same image and the
## loop would be the most expensive thing in a bake.
func _rond_af(img: Image, omlijnd: bool) -> void:
	if omlijnd:
		return
	var breed := img.get_width()
	var hoog := img.get_height()
	if breed < 4 or hoog < 4:
		return
	var data := img.get_data()
	var uit := data.duplicate()
	var raak := false
	for y in range(1, hoog - 1):
		for x in range(1, breed - 1):
			var i := (y * breed + x) * 4
			if data[i + 3] < 200:
				continue
			var leeg := 0
			if data[i - 4 + 3] < 40: leeg += 1
			if data[i + 4 + 3] < 40: leeg += 1
			if data[i - breed * 4 + 3] < 40: leeg += 1
			if data[i + breed * 4 + 3] < 40: leeg += 1
			if leeg >= 2:
				uit[i + 3] = 112
				raak = true
	if raak:
		img.set_data(breed, hoog, false, Image.FORMAT_RGBA8, uit)

## The colour of one floor tile — one authority for the whole port.  The floor
## itself is drawn by `scenes/vloer.gd` as a mesh; this is the table it reads.
func vloer_kleur(r, x: int, z: int) -> Color:
	return ArtVloer.kleur(r, x, z)

# -------------------------------------------------------------------- effecten

## The same guest with a band of water over his lower half (art-sound-rules.md
## §11.5).  `top` is his floor point inside the plate; it depends only on the
## anchor, the scale, the lift and the bob, so the handful of variants a
## swimmer needs are cached like any other plate.
func water_plaat(kind: String, pose: String, g: int, top: int, acc = null) -> Plaat:
	var basis := dier(kind, pose, g, acc)
	if basis == null:
		return null
	var sleutel := "w|%s|%s|%d|%d|%s" % [kind, pose, g, top, ArtGasten.acc_sleutel(acc)]
	return plaat_van(sleutel, func():
		var img := ArtEffect.water_over(basis.tex.get_image(), float(top), g)
		return Plaat.new(ImageTexture.create_from_image(img), basis.dx, basis.dy))
