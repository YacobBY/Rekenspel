extends Node
## Art — the voxel baker.  Autoload #1 (nothing depends on it at _ready time).
##
## DECISION (architecture.md §3): the voxel models of art-sound-rules.md are
## re-drawn procedurally in GDScript and baked into an `ImageTexture` per
## (model, params, g); the world then only blits those textures.  No sprite
## sheets: several models take geometry-changing parameters (klok, steen, trap,
## was_krat) and plates are not integer rescales of one another.
##
## The rasteriser is CPU-side (`Image.fill_rect` per scanline span) instead of a
## SubViewport read-back, so a bake is deterministic, needs no GPU round trip on
## the single-threaded web build, and can run in `--headless` — which is what
## makes the golden-image test against /tmp/dh-art/*.png possible in CI.
##
## W4 fills in: the four guests with their 15 poses, the accessories, the 33
## decor models, the bowl, particles and the shadow.  The plate API below does
## not change.

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
var _span_cache: Dictionary = {}    ## "vlak|g" -> Array of [y, x0, breedte]
var _bakken := 0                    ## how many plates were baked this session

signal model_geregistreerd(naam: String)

func _ready() -> void:
	_registreer_ingebouwd()

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
	model_geregistreerd.emit(naam)
	return true

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

func _registreer_ingebouwd() -> void:
	pass   # W4: the 33 decor models of art-sound-rules.md §8 and the four guests.
	       # The vertical slice registers its placeholders from scenes/kamer.gd.

# --------------------------------------------------------------- het bakken

## The plate for one model at voxel size `g`.  Cached (LRU).
func plaat(naam: String, g: int, params: Dictionary = {}) -> Plaat:
	var sleutel := "%s|%d|%s" % [naam, g, JSON.stringify(params)]
	if _plaat_cache.has(sleutel):
		_plaat_orde.erase(sleutel)
		_plaat_orde.append(sleutel)
		return _plaat_cache[sleutel]
	var p := bak(model(naam, params), g)
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

func wis_platen() -> void:
	_plaat_cache.clear()
	_plaat_orde.clear()

## Bake a voxel list into a plate.  This is the whole renderer.
func bak(voxels: Array, g: int) -> Plaat:
	if voxels.is_empty() or g <= 0:
		return null
	_bakken += 1
	# 1. occupancy set for hidden-face culling
	var bezet := {}
	for v in voxels:
		bezet[_sleutel(v["x"], v["y"], v["z"])] = true
	# 2. emit the visible faces, in painter order (d = x + y + z ascending)
	var vlakken: Array = []
	var min_px := 1 << 30
	var max_px := -(1 << 30)
	var min_py := 1 << 30
	var max_py := -(1 << 30)
	for v in voxels:
		var x: int = v["x"]
		var y: int = v["y"]
		var z: int = v["z"]
		var kl: Color = v["k"]
		var px := (x - z) * S
		var py := (x + z) - (y + 1) * HG
		min_px = mini(min_px, px - S)
		max_px = maxi(max_px, px + S)
		min_py = mini(min_py, py)
		max_py = maxi(max_py, py + 2 * HG)
		var d := x + y + z
		if not bezet.has(_sleutel(x, y + 1, z)):
			vlakken.append([d, Vlak.TOP, px, py, _tint(kl, F_TOP * AO[_buren_top(bezet, x, y, z)])])
		if not bezet.has(_sleutel(x + 1, y, z)):
			vlakken.append([d, Vlak.RECHTS, px, py, _tint(kl, F_RECHTS * AO[_buren_rechts(bezet, x, y, z)])])
		if not bezet.has(_sleutel(x, y, z + 1)):
			vlakken.append([d, Vlak.LINKS, px, py, _tint(kl, F_LINKS * AO[_buren_links(bezet, x, y, z)])])
	vlakken.sort_custom(func(a, b): return a[0] < b[0])
	# 3. plate geometry (art-sound-rules.md §1.5)
	var dx := min_px * g - PAD
	var dy := min_py * g - PAD
	var w := (max_px - min_px) * g + 2 * PAD
	var h := (max_py - min_py) * g + 2 * PAD
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var sil := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var wit := Color(1, 1, 1, 1)
	for f in vlakken:
		var ox: int = f[2] * g - dx
		var oy: int = f[3] * g - dy
		_teken_vlak(img, f[1], g, ox, oy, f[4])
		_teken_vlak(sil, f[1], g, ox, oy, wit)
	# 4. omlijn: a dilated silhouette behind the shape
	var dik := maxi(1, JsGetal.rond(float(g) / 2.6))
	var achter := _dilateer(sil, dik, OMLIJN_KLEUR)
	achter.blend_rect(img, Rect2i(0, 0, w, h), Vector2i.ZERO)
	# 5. rondAf: shave one pixel off every staircase corner (only at g >= 2)
	if g >= 2:
		_rond_af(achter)
	return Plaat.new(ImageTexture.create_from_image(achter), dx, dy)

func _sleutel(x: int, y: int, z: int) -> int:
	return ((x + 512) << 22) | ((y + 512) << 11) | (z + 512)

func _buren_top(b: Dictionary, x: int, y: int, z: int) -> int:
	var n := 0
	if b.has(_sleutel(x - 1, y + 1, z)): n += 1
	if b.has(_sleutel(x + 1, y + 1, z)): n += 1
	if b.has(_sleutel(x, y + 1, z - 1)): n += 1
	if b.has(_sleutel(x, y + 1, z + 1)): n += 1
	return n

func _buren_rechts(b: Dictionary, x: int, y: int, z: int) -> int:
	var n := 0
	if b.has(_sleutel(x + 1, y - 1, z)): n += 1
	if b.has(_sleutel(x + 1, y + 1, z)): n += 1
	if b.has(_sleutel(x + 1, y, z - 1)): n += 1
	if b.has(_sleutel(x + 1, y, z + 1)): n += 1
	return n

func _buren_links(b: Dictionary, x: int, y: int, z: int) -> int:
	var n := 0
	if b.has(_sleutel(x, y - 1, z + 1)): n += 1
	if b.has(_sleutel(x, y + 1, z + 1)): n += 1
	if b.has(_sleutel(x - 1, y, z + 1)): n += 1
	if b.has(_sleutel(x + 1, y, z + 1)): n += 1
	return n

## `shade(hex, m)` — mix toward WARM above 1, toward KOEL below.
func _tint(kl: Color, m: float) -> Color:
	var doel := WARM if m >= 1.0 else KOEL
	var t := minf(1.0, (m - 1.0) * 1.25) if m >= 1.0 else minf(1.0, (1.0 - m) * 1.55)
	var c := Vector3(kl.r * 255.0, kl.g * 255.0, kl.b * 255.0)
	var uit := c + (doel - c) * t
	return Color(
		clampf(JsGetal.rond(uit.x), 0, 255) / 255.0,
		clampf(JsGetal.rond(uit.y), 0, 255) / 255.0,
		clampf(JsGetal.rond(uit.z), 0, 255) / 255.0, 1.0)

func _teken_vlak(img: Image, vlak: int, g: int, ox: int, oy: int, kl: Color) -> void:
	for sp in _spans(vlak, g):
		var x: int = ox + int(sp[1])
		var y: int = oy + int(sp[0])
		var b: int = int(sp[2])
		if y < 0 or y >= img.get_height():
			continue
		if x < 0:
			b += x
			x = 0
		if x + b > img.get_width():
			b = img.get_width() - x
		if b > 0:
			img.fill_rect(Rect2i(x, y, b, 1), kl)

## Scanline spans of one face shape at scale g, relative to the voxel origin.
## Computed once per (shape, g).  The x-range of a row is taken over the whole
## row (y .. y+1) and rounded outward, which is what the JS 1-px stroke does.
func _spans(vlak: int, g: int) -> Array:
	var sleutel := "%d|%d" % [vlak, g]
	if _span_cache.has(sleutel):
		return _span_cache[sleutel]
	var b := S * g
	var d := HG * g
	var punten: Array[Vector2]
	match vlak:
		Vlak.TOP:
			punten = [Vector2(0, 0), Vector2(b, g), Vector2(0, b), Vector2(-b, g)]
		Vlak.RECHTS:
			punten = [Vector2(b, g), Vector2(0, b), Vector2(0, b + d), Vector2(b, g + d)]
		_:
			punten = [Vector2(-b, g), Vector2(0, b), Vector2(0, b + d), Vector2(-b, g + d)]
	var lijst := _polygoon_spans(punten)
	_span_cache[sleutel] = lijst
	return lijst

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

## Manhattan dilation of the alpha mask by `w`, tinted with `kl`.
func _dilateer(sil: Image, w: int, kl: Color) -> Image:
	var breed := sil.get_width()
	var hoog := sil.get_height()
	var bron := sil.get_data()
	var masker := PackedByteArray()
	masker.resize(breed * hoog)
	for i in breed * hoog:
		masker[i] = 1 if bron[i * 4 + 3] > 0 else 0
	for _ronde in w:
		var vorig := masker.duplicate()
		for y in hoog:
			for x in breed:
				var i := y * breed + x
				if vorig[i] == 1:
					continue
				if (x > 0 and vorig[i - 1] == 1) or (x + 1 < breed and vorig[i + 1] == 1) \
						or (y > 0 and vorig[i - breed] == 1) or (y + 1 < hoog and vorig[i + breed] == 1):
					masker[i] = 1
	var uit := Image.create_empty(breed, hoog, false, Image.FORMAT_RGBA8)
	var data := uit.get_data()
	var cr := int(kl.r * 255.0)
	var cg := int(kl.g * 255.0)
	var cb := int(kl.b * 255.0)
	var ca := int(kl.a * 255.0)
	for i in breed * hoog:
		if masker[i] == 1:
			data[i * 4] = cr
			data[i * 4 + 1] = cg
			data[i * 4 + 2] = cb
			data[i * 4 + 3] = ca
	return Image.create_from_data(breed, hoog, false, Image.FORMAT_RGBA8, data)

## `rondAf`: an opaque pixel with two or more empty orthogonal neighbours
## drops to alpha 112 — one pixel off every staircase corner.
func _rond_af(img: Image) -> void:
	var breed := img.get_width()
	var hoog := img.get_height()
	var data := img.get_data()
	var uit := data.duplicate()
	for y in hoog:
		for x in breed:
			var i := (y * breed + x) * 4
			if data[i + 3] < 200:
				continue
			var leeg := 0
			if x == 0 or data[i - 4 + 3] < 40: leeg += 1
			if x + 1 >= breed or data[i + 4 + 3] < 40: leeg += 1
			if y == 0 or data[i - breed * 4 + 3] < 40: leeg += 1
			if y + 1 >= hoog or data[i + breed * 4 + 3] < 40: leeg += 1
			if leeg >= 2:
				uit[i + 3] = 112
	var nieuw := Image.create_from_data(breed, hoog, false, Image.FORMAT_RGBA8, uit)
	img.copy_from(nieuw)
