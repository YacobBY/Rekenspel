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
const GAT := Color("#7A6250")      ## what a door shows when its room is unknown
const HOUT := Color("#D0A87A")
const HOUT_D := Color("#B98F62")
const WAND_SCHADUW := Color(110.0 / 255.0, 90.0 / 255.0, 74.0 / 255.0, 0.10)
const VIGNET := Color(120.0 / 255.0, 96.0 / 255.0, 70.0 / 255.0, 0.18)
const WAND_DIK := 3      ## voxels of wall top cap
const SCHADUW_BREED := 4 ## voxels of shadow where a wall meets the floor
const ERF_RAND := 120    ## voxel-px of lawn beyond the garden frame

## The view through a door (owner, 2026-09-23: "geen mooie overgang die
## sprekend is").  A door used to be one dark hole, the same for every room;
## now the opening shows the floor of the room behind it, so the corridor's
## pink runner, the kitchen's tiles or the garden's lawn tell the child where
## the door goes before any button does.  The wall is WAND_DIK thick, so the
## jamb that faces the viewer shows as a strip of wall and the first voxels
## behind it are the threshold; the lintel throws a soft shadow down into the
## opening.
const BINNEN_SCHADUW := Color("#6E5A4A") ## the room behind a door is a little darker
const BINNEN_DIEP := 0.16                 ## ... by this much
const BUITEN_IN_DIEP := 0.36              ## ... and a lot darker, seen from the sunny lawn
const LATEI_SCHADUW := 0.38               ## alpha under the lintel, fading down
const LATEI_BAND := 11.0                  ## voxels the lintel's shadow runs down
const DREMPEL := Color("#C9A27E")         ## the threshold inside the wall
const DAG := Color("#FFFBEF")             ## outside is brighter
const DAG_LICHT := 0.08
## A door that leads OUT is painted white, like a garden door.
const KOZIJN_WIT := Color("#FBF7EE")
const KOZIJN_WIT_D := Color("#E6DDCC")
## The back door in the hotel's facade stands wide open against the wall: a
## sage-green leaf with a panel, a four-pane window and a brass knob, so from
## the lawn the kitchen entrance reads as a DOOR at a glance.
const DEURBLAD := Color("#93C19C")
const DEURBLAD_D := Color("#7BA986")
const DEURBLAD_RUIT := Color("#DDF0F4")
const DEURKNOP := Color("#F2C14E")

## The hotel's back wall in the garden (`Kamer.gevel`, owner 2026-09-23): sunlit
## plaster on a stone plinth, a band in the eaves' shadow, and a tiled roof
## that runs back and up out of the picture — the building is the hotel, it
## does not end.
const GEVEL := Color("#F3E2C9")
const GEVEL_BAND := Color("#E6D0B1")
const GEVEL_PLINT := Color("#CDB195")
const GEVEL_NEGGE := Color("#D9C3A4")     ## the jamb of a door in the facade
const DAK := Color("#E79C7C")
const DAK_D := Color("#DA8C6D")
const DAK_GOOT := Color("#B7876C")
const GEVEL_EIND := 400.0                 ## the wall runs off the picture this far
const DAK_RIJEN := 44                     ## ... and the roof this many 4-voxel rows

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
	if not r.gevel.is_empty():
		_gevel(r, v, k, i)
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

## Door openings are cut to `Rooms.deur_hoog()` — `min(wand − 6, 26)` — and
## every one shows the room it leads to (`_doorkijk`), inside the thickness of
## the wall and under the lintel's shadow, in a wooden frame that is white when
## the door leads outside.  A garden gate cuts no hole: its gate is a model in
## the fence.  `alleen` limits the pass to one wall (the garden's facade draws
## its own door).
func _deuren(r: Rooms.Kamer, v: PackedVector2Array, k: PackedColorArray,
		i: PackedInt32Array, alleen := "") -> void:
	for dr in r.deuren:
		if dr.get("poort", false):
			continue
		var wand := str(dr["wand"])
		if alleen != "" and wand != alleen:
			continue
		var hoog := float(Rooms.deur_hoog(r, dr))
		var a: float = dr["at"]
		var b: float = a + dr["breed"]
		var doel := Rooms.get_kamer(str(dr["naar"]))
		var buiten := doel != null and doel.erf
		var langs_z := wand == "z"
		_doorkijk(dr, doel, hoog, r.erf, v, k, i)
		# The jamb.  The wall is WAND_DIK thick and the viewer looks along
		# (−1, −1, −1): of the two sides of the opening only the one facing the
		# viewer shows — the left one in the z wall, the right one in the x wall.
		var in_gevel := not r.gevel.is_empty() and str(r.gevel.get("wand", "")) == wand
		var negge := GEVEL_NEGGE if in_gevel else (W_R if langs_z else W_L).darkened(0.12)
		# the lintel's shadow, fading down into the opening (half of it outside)
		var s := LATEI_SCHADUW * (0.5 if buiten else 1.0)
		var boven := Color(BINNEN_SCHADUW, s)
		var onder := Color(BINNEN_SCHADUW, 0.0)
		var band := minf(LATEI_BAND, hoog)
		var post := KOZIJN_WIT_D if buiten else HOUT_D
		var latei := KOZIJN_WIT if buiten else HOUT
		if langs_z:
			_vlak(v, k, i, [_proj(a, 0, 0), _proj(a, -WAND_DIK, 0), _proj(a, -WAND_DIK, hoog),
				_proj(a, 0, hoog)], negge)
			_vlak_kl(v, k, i, [_proj(a, 0, hoog), _proj(b, 0, hoog), _proj(b, 0, hoog - band),
				_proj(a, 0, hoog - band)], [boven, boven, onder, onder])
			_vlak(v, k, i, [_proj(a - 1, 0, 0), _proj(a, 0, 0), _proj(a, 0, hoog + 1.4),
				_proj(a - 1, 0, hoog + 1.4)], post)
			_vlak(v, k, i, [_proj(b, 0, 0), _proj(b + 1, 0, 0), _proj(b + 1, 0, hoog + 1.4),
				_proj(b, 0, hoog + 1.4)], post)
			_vlak(v, k, i, [_proj(a - 1, 0, hoog), _proj(b + 1, 0, hoog),
				_proj(b + 1, 0, hoog + 1.4), _proj(a - 1, 0, hoog + 1.4)], latei)
		else:
			_vlak(v, k, i, [_proj(0, a, 0), _proj(-WAND_DIK, a, 0), _proj(-WAND_DIK, a, hoog),
				_proj(0, a, hoog)], negge)
			_vlak_kl(v, k, i, [_proj(0, a, hoog), _proj(0, b, hoog), _proj(0, b, hoog - band),
				_proj(0, a, hoog - band)], [boven, boven, onder, onder])
			_vlak(v, k, i, [_proj(0, a - 1, 0), _proj(0, a, 0), _proj(0, a, hoog + 1.4),
				_proj(0, a - 1, hoog + 1.4)], post)
			_vlak(v, k, i, [_proj(0, b, 0), _proj(0, b + 1, 0), _proj(0, b + 1, hoog + 1.4),
				_proj(0, b, hoog + 1.4)], post)
			_vlak(v, k, i, [_proj(0, a - 1, hoog), _proj(0, b + 1, hoog),
				_proj(0, b + 1, hoog + 1.4), _proj(0, a - 1, hoog + 1.4)], latei)
			if in_gevel:
				_deurblad(b + 1.0, b + 1.0 + (b - a) - 0.5, hoog, v, k, i)

## The open leaf of the back door, folded flat against the facade on x = 0
## beyond the opening (z from `z0` to `z1`): its face, the edge and top that
## show, a panel, a window with a cross and a knob.
func _deurblad(z0: float, z1: float, hoog: float, v: PackedVector2Array,
		k: PackedColorArray, i: PackedInt32Array) -> void:
	var dik := 1.2
	var y0 := 0.4
	_vlak(v, k, i, [_proj(dik, z0, y0), _proj(dik, z1, y0), _proj(dik, z1, hoog),
		_proj(dik, z0, hoog)], DEURBLAD)
	_vlak(v, k, i, [_proj(0, z1, y0), _proj(dik, z1, y0), _proj(dik, z1, hoog),
		_proj(0, z1, hoog)], DEURBLAD_D)
	_vlak(v, k, i, [_proj(0, z0, hoog), _proj(0, z1, hoog), _proj(dik, z1, hoog),
		_proj(dik, z0, hoog)], DEURBLAD.lightened(0.15))
	var p0 := z0 + 1.6
	var p1 := z1 - 1.6
	_vlak(v, k, i, [_proj(dik, p0, 2.5), _proj(dik, p1, 2.5), _proj(dik, p1, 11.0),
		_proj(dik, p0, 11.0)], DEURBLAD_D)
	var r0 := 14.0
	var r1 := hoog - 2.5
	_vlak(v, k, i, [_proj(dik, p0, r0), _proj(dik, p1, r0), _proj(dik, p1, r1),
		_proj(dik, p0, r1)], DEURBLAD_RUIT)
	var zm := (p0 + p1) * 0.5
	var ym := (r0 + r1) * 0.5
	_vlak(v, k, i, [_proj(dik, zm - 0.5, r0), _proj(dik, zm + 0.5, r0), _proj(dik, zm + 0.5, r1),
		_proj(dik, zm - 0.5, r1)], DEURBLAD)
	_vlak(v, k, i, [_proj(dik, p0, ym - 0.5), _proj(dik, p1, ym - 0.5), _proj(dik, p1, ym + 0.5),
		_proj(dik, p0, ym + 0.5)], DEURBLAD)
	_vlak(v, k, i, [_proj(dik, z1 - 2.4, 12.0), _proj(dik, z1 - 1.2, 12.0),
		_proj(dik, z1 - 1.2, 13.2), _proj(dik, z1 - 2.4, 13.2)], DEURKNOP)

## What a door lets you see: the floor of the room behind it, in that room's own
## 4x4 tiles (`Rooms.vloer_kleur`), clipped to exactly the floor the opening
## shows, plus the threshold inside the wall.  A little darker when the room is
## indoors, a little brighter when it is outside.
##
## Seen along (−1, −1, −1), a floor point (x, z) behind the z wall shows
## through the opening when its line of sight crosses the wall inside [a, b]
## (a ≤ x − z ≤ b) and below the lintel (−z ≤ hoog); the x wall is the same with
## x and z swapped.  The rooms do not really lie behind each other's walls, so
## the view is centred on the room's own `kijk` point (its middle by default):
## a glimpse of the heart of the room, never of the patch behind its door.
func _doorkijk(dr: Dictionary, doel: Rooms.Kamer, hoog: float, van_buiten: bool,
		v: PackedVector2Array, k: PackedColorArray, i: PackedInt32Array) -> void:
	var a: float = dr["at"]
	var b: float = a + float(dr["breed"])
	if doel == null:
		if str(dr["wand"]) == "z":
			_vlak(v, k, i, [_proj(a, 0, 0), _proj(b, 0, 0), _proj(b, 0, hoog), _proj(a, 0, hoog)], GAT)
		else:
			_vlak(v, k, i, [_proj(0, a, 0), _proj(0, b, 0), _proj(0, b, hoog), _proj(0, a, hoog)], GAT)
		return
	for tegel in doorkijk_tegels(dr, doel, hoog):
		var kl: Color = tegel["kl"]
		if doel.erf:
			kl = kl.lerp(DAG, DAG_LICHT)
		else:
			kl = kl.lerp(BINNEN_SCHADUW, BUITEN_IN_DIEP if van_buiten else BINNEN_DIEP)
		_veelhoek(v, k, i, tegel["p"], kl)
	var drempel: Array = [Vector2(a, -WAND_DIK), Vector2(b, -WAND_DIK), Vector2(b, 0),
		Vector2(a, 0)] if str(dr["wand"]) == "z" \
		else [Vector2(-WAND_DIK, a), Vector2(0, a), Vector2(0, b), Vector2(-WAND_DIK, b)]
	_veelhoek(v, k, i, _knip(drempel, doorkijk_zicht(dr, hoog)), DREMPEL)

## The half-planes n · (x, z) <= n.z that bound the floor a door opening shows.
static func doorkijk_zicht(dr: Dictionary, hoog: float) -> Array:
	var a: float = dr["at"]
	var b: float = a + float(dr["breed"])
	if str(dr["wand"]) == "z":
		return [Vector3(0, 1, 0), Vector3(0, -1, hoog), Vector3(-1, 1, -a), Vector3(1, -1, b)]
	return [Vector3(1, 0, 0), Vector3(-1, 0, hoog), Vector3(1, -1, -a), Vector3(-1, 1, b)]

## The floor tiles a door opening shows, before any light is put on them:
## `[{p: [floor points (x, z)], kl: the colour of that tile in the room behind}]`.
## Pure, so `tests/test_rooms.gd` walks every door of the hotel with it.
static func doorkijk_tegels(dr: Dictionary, doel: Rooms.Kamer, hoog: float) -> Array:
	var uit: Array = []
	var a: float = dr["at"]
	var b: float = a + float(dr["breed"])
	var langs_z := str(dr["wand"]) == "z"
	var zicht := doorkijk_zicht(dr, hoog)
	var kijk: Vector2 = doel.kijk if doel.kijk.x >= 0.0 else Vector2(doel.w * 0.5, doel.d * 0.5)
	var mid := Vector2((a + b - hoog) * 0.5, -hoog * 0.5) if langs_z \
		else Vector2(-hoog * 0.5, (a + b - hoog) * 0.5)
	var ox := int(round((kijk.x - mid.x) / 4.0)) * 4
	var oz := int(round((kijk.y - mid.y) / 4.0)) * 4
	var x0 := int(floor((a - hoog) / 4.0)) * 4 if langs_z else int(floor(-hoog / 4.0)) * 4
	var x1 := int(ceil(b)) if langs_z else 0
	var z0 := int(floor(-hoog / 4.0)) * 4 if langs_z else int(floor((a - hoog) / 4.0)) * 4
	var z1 := 0 if langs_z else int(ceil(b))
	var tx := x0
	while tx < x1:
		var tz := z0
		while tz < z1:
			var p := _knip([Vector2(tx, tz), Vector2(tx + 4, tz), Vector2(tx + 4, tz + 4),
				Vector2(tx, tz + 4)], zicht)
			if p.size() >= 3:
				uit.append({"p": p, "kl": Rooms.vloer_kleur(doel, tx + ox, tz + oz)})
			tz += 4
		tx += 4
	return uit

## The hotel's back wall on the lawn (`Kamer.gevel`, the garden, owner
## 2026-09-23): plaster on a plinth, a band in the shadow of the eaves, the
## kitchen door cut out of it, a strip of shadow on the paving at its foot, and
## a tiled roof that runs back and up out of the picture.  The wall starts just
## behind the garden's back corner and runs on past the front edge, so no end
## of the building is ever in view.  Only a wall on x = 0 exists (the garden).
func _gevel(r: Rooms.Kamer, v: PackedVector2Array, k: PackedColorArray,
		i: PackedInt32Array) -> void:
	var g: Dictionary = r.gevel
	if str(g.get("wand", "")) != "x":
		return
	var h := float(g.get("hoog", 30))
	var z0 := -2.0 * WAND_DIK
	var z1 := GEVEL_EIND
	_vlak(v, k, i, [_proj(0, z0, 0), _proj(0, z1, 0), _proj(0, z1, h), _proj(0, z0, h)], GEVEL)
	_vlak(v, k, i, [_proj(0, z0, 0), _proj(0, z1, 0), _proj(0, z1, 3), _proj(0, z0, 3)],
		GEVEL_PLINT)
	_vlak(v, k, i, [_proj(0, z0, h - 3), _proj(0, z1, h - 3), _proj(0, z1, h), _proj(0, z0, h)],
		GEVEL_BAND)
	_vlak(v, k, i, [_proj(0, z0), _proj(0, z1), _proj(SCHADUW_BREED, z1),
		_proj(SCHADUW_BREED, z0)], WAND_SCHADUW)
	# the roof: 4-voxel rows at 45 degrees, from eaves that stick out 3 voxels
	# over the wall, back and up until the picture ends
	var x := float(WAND_DIK)
	var y := h
	for rij in DAK_RIJEN:
		_vlak(v, k, i, [_proj(x, z0, y), _proj(x, z1, y), _proj(x - 4, z1, y + 4),
			_proj(x - 4, z0, y + 4)], DAK if rij % 2 == 0 else DAK_D)
		x -= 4.0
		y += 4.0
	# the fascia along the eaves
	_vlak(v, k, i, [_proj(WAND_DIK, z0, h - 1.5), _proj(WAND_DIK, z1, h - 1.5),
		_proj(WAND_DIK, z1, h), _proj(WAND_DIK, z0, h)], DAK_GOOT)
	_deuren(r, v, k, i, "x")

## A quad with a colour per corner (the lintel's fading shadow).
func _vlak_kl(v: PackedVector2Array, k: PackedColorArray, i: PackedInt32Array,
		p: Array, kl: Array) -> void:
	var n := v.size()
	for j in 4:
		v.append(p[j])
		k.append(kl[j])
	i.append_array([n, n + 1, n + 2, n, n + 2, n + 3])

## A convex polygon of FLOOR points (x, z), projected and fanned into triangles.
func _veelhoek(v: PackedVector2Array, k: PackedColorArray, i: PackedInt32Array,
		p: Array, kl: Color) -> void:
	if p.size() < 3:
		return
	var n := v.size()
	for q in p:
		v.append(_proj(q.x, q.y))
		k.append(kl)
	for j in range(1, p.size() - 1):
		i.append_array([n, n + j, n + j + 1])

## Sutherland–Hodgman: the part of a convex polygon (floor points) where
## n.x · x + n.y · z <= n.z for every half-plane n.
static func _knip(p: Array, vlakken: Array) -> Array:
	var uit: Array = p
	for h in vlakken:
		if uit.size() < 3:
			return []
		var nieuw: Array = []
		for j in uit.size():
			var s: Vector2 = uit[j]
			var e: Vector2 = uit[(j + 1) % uit.size()]
			var ds: float = h.x * s.x + h.y * s.y - h.z
			var de: float = h.x * e.x + h.y * e.y - h.z
			if ds <= 0.0:
				nieuw.append(s)
			if (ds < 0.0 and de > 0.0) or (ds > 0.0 and de < 0.0):
				nieuw.append(s.lerp(e, ds / (ds - de)))
		uit = nieuw
	return uit

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
