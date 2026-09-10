class_name ArtVorm
extends RefCounted
## The build primitives of `demos/dierenhotel/art.js` (art-sound-rules.md §4.1),
## ported one to one.  Every model — a guest, a bowl, a chest, a game's own
## clock — is made of these five shapes and nothing else, so one light model
## and one bake path serve the whole world.
##
## A voxel is `{x: int, y: int, z: int, k: Color}` plus an optional
## `voor: 1` flag (the front wall of the feeding bowl, drawn after the guest).
## Coordinates are voxels: x = length, y = height above the floor, z = depth.

## Isometry: one voxel is 2S wide and S tall on top, HG deep (art.js).
const S := 2
const HG := 2

## A box of w x h x d voxels with its low corner at (x, y, z).
static func bx(v: Array, x, y, z, w: int, h: int, d: int, c: Color) -> void:
	var ix := JsGetal.rond(float(x))
	var iy := JsGetal.rond(float(y))
	var iz := JsGetal.rond(float(z))
	for i in w:
		for j in h:
			for k in d:
				v.append({"x": ix + i, "y": iy + j, "z": iz + k, "k": c})

## Superellipsoid — round bodies and heads without hard steps.
## `o.e` = roundness (2 = egg, 3.4 = rounded cube), `o.lim` = 1.02,
## `o.ymin` = flat bottom.
static func ell(v: Array, cx: float, cy: float, cz: float,
		rx: float, ry: float, rz: float, c: Color, o: Dictionary = {}) -> void:
	var e: float = o.get("e", 2.2)
	var lim: float = o.get("lim", 1.02)
	var ymin: int = JsGetal.plafond(o.get("ymin", -1e9))
	var x0 := JsGetal.plafond(cx - rx)
	var x1 := JsGetal.vloer(cx + rx)
	var y0 := maxi(JsGetal.plafond(cy - ry), ymin)
	var y1 := JsGetal.vloer(cy + ry)
	var z0 := JsGetal.plafond(cz - rz)
	var z1 := JsGetal.vloer(cz + rz)
	for x in range(x0, x1 + 1):
		var ax := pow(absf((x - cx) / rx), e)
		if ax > lim:
			continue
		for y in range(y0, y1 + 1):
			var ay := pow(absf((y - cy) / ry), e)
			if ax + ay > lim:
				continue
			for z in range(z0, z1 + 1):
				var az := pow(absf((z - cz) / rz), e)
				if ax + ay + az <= lim:
					v.append({"x": x, "y": y, "z": z, "k": c})

## A capsule along the 2-D line (x0,y0)-(x1,y1) at depth `cz`; the z-radius
## tapers with the distance to the axis, so neck and head grow together.
static func hals(v: Array, x0: float, y0: float, x1: float, y1: float,
		cz: float, r: float, rz: float, c: Color) -> void:
	var dx := x1 - x0
	var dy := y1 - y0
	var l2 := dx * dx + dy * dy
	for x in range(JsGetal.vloer(minf(x0, x1) - r), JsGetal.plafond(maxf(x0, x1) + r) + 1):
		for y in range(JsGetal.vloer(minf(y0, y1) - r), JsGetal.plafond(maxf(y0, y1) + r) + 1):
			var t := ((x - x0) * dx + (y - y0) * dy) / l2 if l2 != 0.0 else 0.0
			t = clampf(t, 0.0, 1.0)
			var qx := x0 + dx * t
			var qy := y0 + dy * t
			var d2 := (x - qx) * (x - qx) + (y - qy) * (y - qy)
			if d2 > r * r:
				continue
			var zr := rz * (0.55 + 0.45 * sqrt(1.0 - d2 / (r * r)))
			for z in range(JsGetal.plafond(cz - zr), JsGetal.vloer(cz + zr) + 1):
				v.append({"x": x, "y": y, "z": z, "k": c})

## A tapering spike (ear, tail): each layer is narrower than the one below.
static func punt(v: Array, x, y, z, w: int, h: int, d: int, c: Color) -> void:
	for j in h:
		var ww := maxi(1, w - JsGetal.vloer(float(j * w) / float(h)))
		bx(v, x, float(y) + j, z, ww, 1, d, c)

## Repaint EXISTING voxels only — eyes, nose, socks, collar, bib.  Never adds
## a voxel, so a detail always lands on the outermost face.
## The bounds are floats on purpose: `art.js` compares integer voxel
## coordinates against whatever the caller passed, so a half-voxel bound
## (the goose's feather line at y = 10.5) matches nothing at all.  Rounding
## them to int here would repaint a stripe the original never had.
static func verf(v: Array, x0: float, x1: float, y0: float, y1: float,
		z0: float, z1: float, c: Color) -> void:
	for p in v:
		if p["x"] >= x0 and p["x"] <= x1 and p["y"] >= y0 and p["y"] <= y1 \
				and p["z"] >= z0 and p["z"] <= z1:
			p["k"] = c

## Mirror a model over the diagonal by swapping x and z (`baliez`, `bedz`, ...).
static func draai(v: Array) -> Array:
	var uit: Array = []
	uit.resize(v.size())
	for i in v.size():
		var p: Dictionary = v[i]
		var q := {"x": p["z"], "y": p["y"], "z": p["x"], "k": p["k"]}
		if p.has("voor"):
			q["voor"] = p["voor"]
		uit[i] = q
	return uit
