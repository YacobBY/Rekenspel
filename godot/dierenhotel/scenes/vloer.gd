extends Node2D
## The floor plate: floor tiles in 4x4 blocks plus both back walls, their
## skirting, rail, top cap, door openings and the shadow strip where a wall
## meets the floor — world.md §1.4.
##
## DECISION.  The HTML bakes all of that into one canvas image and blits it.
## Here it is one `ArrayMesh` with per-vertex colours, built in **voxel-px**
## and drawn in a single call: the node itself carries the camera (`position`)
## and the voxel size (`scale`), so panning the camera or changing `g` costs
## nothing — the mesh is only rebuilt when the room or its furniture changes.
## That is the same trick the baked plate buys, without a second rasteriser.

## The per-tile floor colour comes from `ArtVloer` (W4) through
## `Rooms.vloer_kleur()` — one authority for the speckle.  The wall palette
## below belongs to this renderer, which is the only thing that draws a wall.
const W_L := Color("#DFC6A8")      ## the z wall faces +z and catches less light
const W_L2 := Color("#E9D4BA")
const W_R := Color("#EDD8BC")
const W_R2 := Color("#F5E5CE")
const W_TOP := Color("#FCF0DE")
const W_PLINT := Color("#C08F6B")
const GAT := Color("#7A6250")      ## the dark hole of a door
const GAT_L := Color("#9C8168")    ## and the lintel strip over it
const HOUT := Color("#D0A87A")
const HOUT_D := Color("#B98F62")
const WAND_SCHADUW := Color(110.0 / 255.0, 90.0 / 255.0, 74.0 / 255.0, 0.10)
const VIGNET := Color(120.0 / 255.0, 96.0 / 255.0, 70.0 / 255.0, 0.18)
const WAND_DIK := 3      ## voxels of wall top cap
const SCHADUW_BREED := 4 ## voxels of shadow where a wall meets the floor
const ERF_RAND := 120    ## voxel-px of lawn beyond the garden frame

var _mesh: ArrayMesh = null
var _kamer := ""
var _vignet: ImageTexture = null

func _draw() -> void:
	var r := Rooms.get_kamer(World.kamer_nu())
	if r == null:
		return
	if _mesh == null or _kamer != r.id:
		_bouw(r)
	draw_mesh(_mesh, null)
	_teken_vignet(r)

## Rebuild after a furniture change (the door frames and the mats move along).
func herbouw() -> void:
	_mesh = null
	queue_redraw()

func _proj(x: float, z: float, y: float = 0.0) -> Vector2:
	return Vector2((x - z) * Art.S, (x + z) * (Art.S / 2.0) - y * Art.HG)

func _vlak(v: PackedVector2Array, k: PackedColorArray, i: PackedInt32Array,
		p: Array, kl: Color) -> void:
	var n := v.size()
	for punt in p:
		v.append(punt)
		k.append(kl)
	i.append_array([n, n + 1, n + 2, n, n + 2, n + 3])

func _bouw(r: Rooms.Kamer) -> void:
	_kamer = r.id
	var v := PackedVector2Array()
	var k := PackedColorArray()
	var i := PackedInt32Array()
	_vloer(r, v, k, i)
	if r.wand > 0:
		_wanden(r, v, k, i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = k
	arrays[Mesh.ARRAY_INDEX] = i
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

## The floor in 4x4 blocks, the colour taken at the block origin.
##
## The garden has no walls and its frame is a literal rectangle, so its lawn
## must run on past the room: it is filled with one base colour and then tiled
## with diamond cells out to 8 voxels beyond the frame (world.md §1.4).  Every
## other room stops at its own edge.
func _vloer(r: Rooms.Kamer, v: PackedVector2Array, k: PackedColorArray,
		i: PackedInt32Array) -> void:
	if not r.erf:
		var x := 0
		while x < r.w:
			var z := 0
			while z < r.d:
				var x1 := mini(x + 4, r.w)
				var z1 := mini(z + 4, r.d)
				_vlak(v, k, i, [_proj(x, z), _proj(x1, z), _proj(x1, z1), _proj(x, z1)],
					Rooms.vloer_kleur(r, x, z))
				z += 4
			x += 4
		return
	# the lawn runs on well past the frame, so it fills the viewport at every
	# scale; underneath it one flat quad, so no gap can ever show through
	var kader := Rooms.kader(r)
	var box := PackedInt32Array([kader[0] - ERF_RAND, kader[1] + ERF_RAND,
		kader[2] - ERF_RAND, kader[3] + ERF_RAND])
	_vlak(v, k, i, [Vector2(box[0], box[2]), Vector2(box[1], box[2]),
		Vector2(box[1], box[3]), Vector2(box[0], box[3])], ArtVloer.GRAS[1])
	var u0 := int(floor(float(box[0]) / Art.S)) - 8
	var u1 := int(ceil(float(box[1]) / Art.S)) + 8
	var w0 := int(floor(float(box[2]) / (Art.S / 2.0))) - 8
	var w1 := int(ceil(float(box[3]) / (Art.S / 2.0))) + 8
	var gx := int(floor((u0 + w0) / 8.0)) * 4
	var gx1 := int(ceil((u1 + w1) / 8.0)) * 4
	var gz := int(floor((w0 - u1) / 8.0)) * 4
	var gz1 := int(ceil((w1 - u0) / 8.0)) * 4
	var x := gx
	while x < gx1:
		var z := gz
		while z < gz1:
			var p0 := _proj(x, z)
			var p1 := _proj(x + 4, z)
			var p2 := _proj(x + 4, z + 4)
			var p3 := _proj(x, z + 4)
			var links: float = minf(p0.x, p3.x)
			var rechts: float = maxf(p1.x, p2.x)
			var boven: float = minf(p0.y, minf(p1.y, p3.y))
			var onder: float = maxf(p2.y, maxf(p1.y, p3.y))
			if rechts >= box[0] and links <= box[1] and onder >= box[2] and boven <= box[3]:
				_vlak(v, k, i, [p0, p1, p2, p3], Rooms.vloer_kleur(r, x, z))
			z += 4
		x += 4

func _wanden(r: Rooms.Kamer, v: PackedVector2Array, k: PackedColorArray,
		i: PackedInt32Array) -> void:
	var h := float(r.wand)
	# wall on z = 0, running along x
	_vlak(v, k, i, [_proj(0, 0, 0), _proj(r.w, 0, 0), _proj(r.w, 0, h), _proj(0, 0, h)], W_L)
	_vlak(v, k, i, [_proj(0, 0, 9), _proj(r.w, 0, 9), _proj(r.w, 0, 10.4), _proj(0, 0, 10.4)],
		W_L2)
	_vlak(v, k, i, [_proj(0, 0, 0), _proj(r.w, 0, 0), _proj(r.w, 0, 3), _proj(0, 0, 3)], W_PLINT)
	_vlak(v, k, i, [_proj(0, 0, h), _proj(r.w, 0, h), _proj(r.w, -WAND_DIK, h),
		_proj(0, -WAND_DIK, h)], W_TOP)
	# wall on x = 0, running along z
	_vlak(v, k, i, [_proj(0, 0, 0), _proj(0, r.d, 0), _proj(0, r.d, h), _proj(0, 0, h)], W_R)
	_vlak(v, k, i, [_proj(0, 0, 9), _proj(0, r.d, 9), _proj(0, r.d, 10.4), _proj(0, 0, 10.4)],
		W_R2)
	_vlak(v, k, i, [_proj(0, 0, 0), _proj(0, r.d, 0), _proj(0, r.d, 3), _proj(0, 0, 3)], W_PLINT)
	_vlak(v, k, i, [_proj(0, 0, h), _proj(0, r.d, h), _proj(-WAND_DIK, r.d, h),
		_proj(-WAND_DIK, 0, h)], W_TOP)
	# the shadow strip where each wall meets the floor
	_vlak(v, k, i, [_proj(0, 0), _proj(r.w, 0), _proj(r.w, SCHADUW_BREED),
		_proj(0, SCHADUW_BREED)], WAND_SCHADUW)
	_vlak(v, k, i, [_proj(0, 0), _proj(0, r.d), _proj(SCHADUW_BREED, r.d),
		_proj(SCHADUW_BREED, 0)], WAND_SCHADUW)
	_deuren(r, v, k, i)

## Door openings are cut to `min(wand − 6, 26)`: a dark hole, a lighter lintel
## strip over the top, and a wooden frame.  A garden gate cuts no hole.
func _deuren(r: Rooms.Kamer, v: PackedVector2Array, k: PackedColorArray,
		i: PackedInt32Array) -> void:
	var hoog := float(mini(r.wand - 6, 26))
	for dr in r.deuren:
		if dr.get("poort", false):
			continue
		var a: float = dr["at"]
		var b: float = a + dr["breed"]
		if dr["wand"] == "z":
			_vlak(v, k, i, [_proj(a, 0, 0), _proj(b, 0, 0), _proj(b, 0, hoog),
				_proj(a, 0, hoog)], GAT)
			_vlak(v, k, i, [_proj(a, 0, hoog - 1.2), _proj(b, 0, hoog - 1.2),
				_proj(b, 0, hoog), _proj(a, 0, hoog)], GAT_L)
			_vlak(v, k, i, [_proj(a - 1, 0, 0), _proj(a, 0, 0), _proj(a, 0, hoog + 1.4),
				_proj(a - 1, 0, hoog + 1.4)], HOUT_D)
			_vlak(v, k, i, [_proj(b, 0, 0), _proj(b + 1, 0, 0), _proj(b + 1, 0, hoog + 1.4),
				_proj(b, 0, hoog + 1.4)], HOUT_D)
			_vlak(v, k, i, [_proj(a - 1, 0, hoog), _proj(b + 1, 0, hoog),
				_proj(b + 1, 0, hoog + 1.4), _proj(a - 1, 0, hoog + 1.4)], HOUT)
		else:
			_vlak(v, k, i, [_proj(0, a, 0), _proj(0, b, 0), _proj(0, b, hoog),
				_proj(0, a, hoog)], GAT)
			_vlak(v, k, i, [_proj(0, a, hoog - 1.2), _proj(0, b, hoog - 1.2),
				_proj(0, b, hoog), _proj(0, a, hoog)], GAT_L)
			_vlak(v, k, i, [_proj(0, a - 1, 0), _proj(0, a, 0), _proj(0, a, hoog + 1.4),
				_proj(0, a - 1, hoog + 1.4)], HOUT_D)
			_vlak(v, k, i, [_proj(0, b, 0), _proj(0, b + 1, 0), _proj(0, b + 1, hoog + 1.4),
				_proj(0, b, hoog + 1.4)], HOUT_D)
			_vlak(v, k, i, [_proj(0, a - 1, hoog), _proj(0, b + 1, hoog),
				_proj(0, b + 1, hoog + 1.4), _proj(0, a - 1, hoog + 1.4)], HOUT)

## A soft radial vignette over the WHOLE view, as one stretched texture — the
## HTML paints it over the entire floor plate, which is the frame.  Anchoring
## it to the room box instead would draw a visible rectangle around the room.
func _teken_vignet(_r: Rooms.Kamer) -> void:
	if _vignet == null:
		_vignet = _maak_vignet()
	var zicht := get_viewport_rect()
	var inv := get_global_transform().affine_inverse()
	var s: float = maxf(0.001, scale.x)
	draw_texture_rect(_vignet, Rect2(inv * zicht.position, zicht.size / s), false)

func _maak_vignet() -> ImageTexture:
	var n := 48
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var mid := (n - 1) / 2.0
	for y in n:
		for x in n:
			var d := Vector2(x - mid, y - mid).length() / mid
			var a: float = clampf((d - 0.35) / 0.65, 0.0, 1.0) * VIGNET.a
			img.set_pixel(x, y, Color(VIGNET.r, VIGNET.g, VIGNET.b, a))
	return ImageTexture.create_from_image(img)
