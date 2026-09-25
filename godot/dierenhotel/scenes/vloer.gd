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
# The floors over the ground floor (owner, 2026-09-24: "Het is de bedoeling dat
# het hotel heel groot en hoog aanvoelt"): from the lawn the hotel is a tower —
# over the lobby's back door the facade rises one band per floor, each with a
# row of windows, and the roof only starts above the top one.
const GEVEL_ETAGE := 30.0                 ## voxels per floor over the ground floor
const GEVEL_RAAM_STAP := 24.0             ## a window every this many voxels
const GEVEL_RAAM_BREED := 10.0
const GEVEL_RAAM_ONDER := 9.0             ## ... from this far over the floor band
const GEVEL_RAAM_HOOG := 14.0
const GEVEL_RUIT := Color("#CFE4EE")      ## sky in the panes
const GEVEL_RUIT_D := Color("#B7D2E0")

## The glass walls of the kas (`Kamer.glas`, PLAN.md R3): a brick knee wall with
## a darker course on top, panes that show the garden's green low down and the
## light higher up, white glazing bars every GLAS_VAK voxels, one transom and a
## white cap.  The same two planes as a plaster wall, so the doors, the view
## through them and the shadow strips work unchanged.
const GLAS_Z := Color("#CFE7E3")          ## the z wall's panes face +z: a touch darker
const GLAS_X := Color("#DCEFEB")
const GLAS_GROEN := Color("#BCDDB7")      ## low in the panes: the garden seen through them
const GLAS_STIJL := Color("#FBF7EE")      ## the white glazing bars
const GLAS_STIJL_D := Color("#E6DDCC")
const BORST := Color("#C98B6B")           ## the brick knee wall
const BORST_D := Color("#B67858")
const GLAS_VAK := 12.0                    ## voxels between two glazing bars
const GLAS_VOET := 6.0                    ## the knee wall is this high
const GLAS_GROEN_TOT := 14.0              ## the green fades out this far above it
const GLAS_KOP := 22.0                    ## the transom
# The stairs (`Kamer.trap`, owner 2026-09-24: the hotel is a tower; a lift
# until 2026-09-25: "Ik wil graag de lift vervangen voor een trap").  A door
# frame in the wall, and through it the stairwell with a wooden flight seen from
# the side — the saw-tooth of the steps, light treads, a banister on posts, like
# the pictogram on its button (`UiTrapIcoon`).  Where there is a floor above,
# the flight climbs from the foot of the doorway towards the back corner of the
# room, getting lighter towards upstairs; on the top floor it goes down from a
# landing into the dark instead.  Everything is clipped to the opening.
const TRAP_TREE := Color("#EDC38F")       ## the top of a step
const TRAP_ZIJ := Color("#C98B5B")        ## the side of the flight, the saw-tooth
const TRAP_STOOTBORD := Color("#A87044")  ## the front of a step
const TRAP_LEUNING := Color("#6E4426")    ## the banister and its posts
const TRAP_MUUR := Color("#E8D8C2")       ## the stairwell's own wall, behind the flight
const TRAP_MUUR_AF := Color("#E3CDB0")    ## ... a shade darker over a flight going down
const TRAP_LICHT := Color("#FFF3DC")      ## upstairs: the light the flight climbs into
const TRAP_DIEP := Color("#4E3E33")       ## downstairs: the dark it goes into
## The flight up: this far behind the wall's face, this deep, a step this long
## and this high, this many of them.
const TRAP_OP_VOOR := 4.0
const TRAP_OP_BREED := 9.0
const TRAP_OP_STAP := 2.6
const TRAP_OP_HOOG := 3.4
const TRAP_OP_TREDEN := 7
## The flight down, from a landing: set further back, so it shows over the sill.
const TRAP_AF_VOOR := 11.0
const TRAP_AF_BREED := 9.0
const TRAP_AF_STAP := 2.6
const TRAP_AF_HOOG := 3.0
const TRAP_AF_TREDEN := 8
const TRAP_PAAL := 8.0                    ## the banister stands this high over a step
const TRAP_DIEPTE := -80.0                ## how far down the dark of a flight going down runs

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
	if r.glas:
		_wanden_glas(r, v, k, i)
		return
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
	_trap(r, v, k, i)

## The kas: both back walls in glass (see GLAS_*), then the shadow strips and the
## doors exactly as a plaster room has them.
func _wanden_glas(r: Rooms.Kamer, v: PackedVector2Array, k: PackedColorArray,
		i: PackedInt32Array) -> void:
	var h := float(r.wand)
	_glaswand(v, k, i, float(r.w), h, true)
	_glaswand(v, k, i, float(r.d), h, false)
	_vlak(v, k, i, [_proj(0, 0), _proj(r.w, 0), _proj(r.w, SCHADUW_BREED),
		_proj(0, SCHADUW_BREED)], WAND_SCHADUW)
	_vlak(v, k, i, [_proj(0, 0), _proj(0, r.d), _proj(SCHADUW_BREED, r.d),
		_proj(SCHADUW_BREED, 0)], WAND_SCHADUW)
	_deuren(r, v, k, i)

## One glass wall, `lang` voxels long: along x on z = 0 (`langs_z`) or along z
## on x = 0.  Later quads are drawn over earlier ones, so the bars lie on the
## panes and the doors, drawn after, lie on everything.
func _glaswand(v: PackedVector2Array, k: PackedColorArray, i: PackedInt32Array,
		lang: float, h: float, langs_z: bool) -> void:
	var p := func(a: float, y: float) -> Vector2:
		return _proj(a, 0, y) if langs_z else _proj(0, a, y)
	var ruit := GLAS_Z if langs_z else GLAS_X
	var stijl := GLAS_STIJL_D if langs_z else GLAS_STIJL
	var voet := GLAS_VOET
	# the brick knee wall and its darker top course
	_vlak(v, k, i, [p.call(0.0, 0.0), p.call(lang, 0.0), p.call(lang, voet), p.call(0.0, voet)],
		BORST if langs_z else BORST.lightened(0.06))
	_vlak(v, k, i, [p.call(0.0, voet - 1.0), p.call(lang, voet - 1.0), p.call(lang, voet),
		p.call(0.0, voet)], BORST_D)
	# the panes: the garden's green low down, fading into the light glass
	var groen := voet + GLAS_GROEN_TOT
	_vlak_kl(v, k, i, [p.call(0.0, voet), p.call(lang, voet), p.call(lang, groen),
		p.call(0.0, groen)], [GLAS_GROEN, GLAS_GROEN, ruit, ruit])
	_vlak(v, k, i, [p.call(0.0, groen), p.call(lang, groen), p.call(lang, h), p.call(0.0, h)], ruit)
	# the glazing bars, the transom and the top rail
	var a := 0.0
	while a <= lang + 0.01:
		var a0 := clampf(a - 0.5, 0.0, lang)
		var a1 := clampf(a + 0.5, 0.0, lang)
		_vlak(v, k, i, [p.call(a0, voet), p.call(a1, voet), p.call(a1, h), p.call(a0, h)], stijl)
		a += GLAS_VAK
	_vlak(v, k, i, [p.call(0.0, GLAS_KOP), p.call(lang, GLAS_KOP), p.call(lang, GLAS_KOP + 0.8),
		p.call(0.0, GLAS_KOP + 0.8)], stijl)
	_vlak(v, k, i, [p.call(0.0, h - 1.2), p.call(lang, h - 1.2), p.call(lang, h),
		p.call(0.0, h)], stijl)
	# the cap, as deep as a plaster wall is thick
	if langs_z:
		_vlak(v, k, i, [_proj(0, 0, h), _proj(lang, 0, h), _proj(lang, -WAND_DIK, h),
			_proj(0, -WAND_DIK, h)], GLAS_STIJL)
	else:
		_vlak(v, k, i, [_proj(0, 0, h), _proj(0, lang, h), _proj(-WAND_DIK, lang, h),
			_proj(-WAND_DIK, 0, h)], GLAS_STIJL)

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
		# A door that leads outside is painted white, and so is a door into a
		# glass house (the kas, R3): a greenhouse has white frames.
		var glas := doel != null and doel.glas
		var buiten := doel != null and (doel.erf or glas)
		var langs_z := wand == "z"
		_doorkijk(dr, doel, hoog, r.erf, v, k, i)
		# The jamb.  The wall is WAND_DIK thick and the viewer looks along
		# (−1, −1, −1): of the two sides of the opening only the one facing the
		# viewer shows — the left one in the z wall, the right one in the x wall.
		var in_gevel := not r.gevel.is_empty() and str(r.gevel.get("wand", "")) == wand
		var negge := GEVEL_NEGGE if in_gevel else (W_R if langs_z else W_L).darkened(0.12)
		if r.glas:
			negge = GLAS_STIJL_D
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
			# the kas's glass door slides away: no leaf folded against the wall
			if in_gevel and not glas:
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

## The stairs in their wall (`Kamer.trap`): the stairwell seen through a door
## frame (see TRAP_*).  The opening is as tall as a door (`Rooms.deur_hoog`), so
## the door sign rule and `World.vlak_van_trap` measure the same box.
func _trap(r: Rooms.Kamer, v: PackedVector2Array, k: PackedColorArray,
		i: PackedInt32Array) -> void:
	if r.trap.is_empty():
		return
	var dr: Dictionary = r.trap
	var langs_z := str(dr.get("wand", "z")) == "z"
	var hoog := float(Rooms.deur_hoog(r, dr))
	var a := float(dr["at"])
	var b := a + float(dr["breed"])
	# a point in the wall: `t` along it, `diep` behind it, `y` up
	var pw := func(t: float, diep: float, y: float) -> Vector2:
		return _proj(t, -diep, y) if langs_z else _proj(-diep, t, y)
	var vak := _scherm_vlakken([pw.call(a, 0.0, 0.0), pw.call(b, 0.0, 0.0),
		pw.call(b, 0.0, hoog), pw.call(a, 0.0, hoog)])
	var boven := false
	for ander in Rooms.trap_kamers():
		boven = boven or Rooms.etage(ander) > r.etage
	if boven:
		_trap_op(pw, vak, a, b, v, k, i)
	else:
		_trap_af(pw, vak, a, b, v, k, i)
	# the threshold inside the wall, the lintel's shadow, the jamb that faces
	# the viewer and the wooden frame, as every door in a wall has them
	_scherm_vlak(v, k, i, [pw.call(a, 0.0, 0.0), pw.call(b, 0.0, 0.0),
		pw.call(b, WAND_DIK, 0.0), pw.call(a, WAND_DIK, 0.0)], vak, DREMPEL)
	var band := minf(LATEI_BAND, hoog)
	var schaduw := Color(BINNEN_SCHADUW, LATEI_SCHADUW)
	var weg := Color(BINNEN_SCHADUW, 0.0)
	_vlak_kl(v, k, i, [pw.call(a, 0.0, hoog), pw.call(b, 0.0, hoog), pw.call(b, 0.0, hoog - band),
		pw.call(a, 0.0, hoog - band)], [schaduw, schaduw, weg, weg])
	var negge := (W_R if langs_z else W_L).darkened(0.12)
	_vlak(v, k, i, [pw.call(a, 0.0, 0.0), pw.call(a, WAND_DIK, 0.0), pw.call(a, WAND_DIK, hoog),
		pw.call(a, 0.0, hoog)], negge)
	_vlak(v, k, i, [pw.call(a - 1.0, 0.0, 0.0), pw.call(a, 0.0, 0.0), pw.call(a, 0.0, hoog + 1.4),
		pw.call(a - 1.0, 0.0, hoog + 1.4)], HOUT_D)
	_vlak(v, k, i, [pw.call(b, 0.0, 0.0), pw.call(b + 1.0, 0.0, 0.0), pw.call(b + 1.0, 0.0, hoog + 1.4),
		pw.call(b, 0.0, hoog + 1.4)], HOUT_D)
	_vlak(v, k, i, [pw.call(a - 1.0, 0.0, hoog), pw.call(b + 1.0, 0.0, hoog),
		pw.call(b + 1.0, 0.0, hoog + 1.4), pw.call(a - 1.0, 0.0, hoog + 1.4)], HOUT)

## The flight up, clipped to `vak`: it starts at the foot of the doorway's far
## side and climbs along the wall towards the back corner (`t` down), set a
## little behind the wall, so the child sees it from the side — per step the
## front of the step, its tread and the column under it — and a banister on a
## post per step.  The viewer stands on the side of the lower steps, so the
## highest step is drawn first and every lower one over it.  The wall behind
## the flight is the stairwell's own, and each step is a little nearer the
## light upstairs.
func _trap_op(pw: Callable, vak: Array, a: float, b: float, v: PackedVector2Array,
		k: PackedColorArray, i: PackedInt32Array) -> void:
	_scherm_vlak(v, k, i, [pw.call(a - 60.0, 0.0, -40.0), pw.call(b + 60.0, 0.0, -40.0),
		pw.call(b + 60.0, 0.0, 80.0), pw.call(a - 60.0, 0.0, 80.0)], vak, TRAP_MUUR)
	var u0 := TRAP_OP_VOOR
	var u1 := u0 + TRAP_OP_BREED
	# a point behind the wall shows `diep` further along it: this puts the foot
	# of the flight just inside the far jamb
	var voet := b + 1.5 - u0
	var n := TRAP_OP_TREDEN
	for j in range(n - 1, -1, -1):
		var tl := voet - TRAP_OP_STAP * float(j + 1)
		var tr := voet - TRAP_OP_STAP * float(j)
		var y0 := TRAP_OP_HOOG * float(j)
		var y1 := y0 + TRAP_OP_HOOG
		var licht := 0.4 * float(j) / float(n)
		_scherm_vlak(v, k, i, [pw.call(tr, u0, y0), pw.call(tr, u1, y0), pw.call(tr, u1, y1),
			pw.call(tr, u0, y1)], vak, TRAP_STOOTBORD.lerp(TRAP_LICHT, licht))
		_scherm_vlak(v, k, i, [pw.call(tl, u0, y1), pw.call(tr, u0, y1), pw.call(tr, u1, y1),
			pw.call(tl, u1, y1)], vak, TRAP_TREE.lerp(TRAP_LICHT, licht))
		_scherm_vlak(v, k, i, [pw.call(tl, u0, 0.0), pw.call(tr, u0, 0.0), pw.call(tr, u0, y1),
			pw.call(tl, u0, y1)], vak, TRAP_ZIJ.lerp(TRAP_LICHT, licht * 0.5))
	_trap_leuning(pw, vak, voet, -TRAP_OP_STAP, TRAP_OP_HOOG, n, u0, v, k, i)

## The flight down, clipped to `vak`: the stairwell's floor is a landing on the
## near side of the doorway, and from it the flight goes down along the wall,
## away from the back corner, into the dark — each step darker, its tread and
## the side under it, with the banister going down with it.  The flight is set
## further back than the one going up, so its first steps show over the sill.
## The viewer stands on the side of the lower steps: drawn from the top down.
func _trap_af(pw: Callable, vak: Array, a: float, b: float, v: PackedVector2Array,
		k: PackedColorArray, i: PackedInt32Array) -> void:
	_scherm_vlak(v, k, i, [pw.call(a - 60.0, 0.0, -40.0), pw.call(b + 60.0, 0.0, -40.0),
		pw.call(b + 60.0, 0.0, 80.0), pw.call(a - 60.0, 0.0, 80.0)], vak, TRAP_MUUR_AF)
	var u0 := TRAP_AF_VOOR
	var u1 := u0 + TRAP_AF_BREED
	var kop := a + 2.0 - u0
	# the dark the flight goes down into, and the wall behind it
	_scherm_vlak(v, k, i, [pw.call(kop, u0, TRAP_DIEPTE), pw.call(b + 60.0, u0, TRAP_DIEPTE),
		pw.call(b + 60.0, u1, TRAP_DIEPTE), pw.call(kop, u1, TRAP_DIEPTE)], vak, TRAP_DIEP)
	_scherm_vlak(v, k, i, [pw.call(kop, u1, TRAP_DIEPTE), pw.call(b + 60.0, u1, TRAP_DIEPTE),
		pw.call(b + 60.0, u1, 0.0), pw.call(kop, u1, 0.0)], vak, TRAP_MUUR_AF.lerp(TRAP_DIEP, 0.6))
	var n := TRAP_AF_TREDEN
	for j in n:
		var tl := kop + TRAP_AF_STAP * float(j)
		var tr := tl + TRAP_AF_STAP
		var y := -TRAP_AF_HOOG * float(j + 1)
		var donker := minf(1.0, 0.15 + 0.85 * float(j + 1) / float(n))
		_scherm_vlak(v, k, i, [pw.call(tl, u0, y), pw.call(tr, u0, y), pw.call(tr, u1, y),
			pw.call(tl, u1, y)], vak, TRAP_TREE.lerp(TRAP_DIEP, donker))
		_scherm_vlak(v, k, i, [pw.call(tl, u0, TRAP_DIEPTE), pw.call(tr, u0, TRAP_DIEPTE),
			pw.call(tr, u0, y), pw.call(tl, u0, y)], vak, TRAP_ZIJ.lerp(TRAP_DIEP, donker))
	_trap_leuning(pw, vak, kop, TRAP_AF_STAP, -TRAP_AF_HOOG, n, u0, v, k, i)
	# the landing: the stairwell's floor from the wall to its back, beside the flight
	_scherm_vlak(v, k, i, [pw.call(a - 60.0, WAND_DIK, 0.0), pw.call(kop, WAND_DIK, 0.0),
		pw.call(kop, u1, 0.0), pw.call(a - 60.0, u1, 0.0)], vak, TRAP_TREE)

## The banister of a flight that starts at `voet` and moves `stap` along the wall
## and `hoog` up per step (both may be negative): a post on the middle of every
## tread and the rail over their tops, on the near edge of the flight.
func _trap_leuning(pw: Callable, vak: Array, voet: float, stap: float, hoog: float, n: int,
		u0: float, v: PackedVector2Array, k: PackedColorArray, i: PackedInt32Array) -> void:
	var u := u0 + 0.9
	for j in n:
		var t := voet + stap * (float(j) + 0.5)
		var y := hoog * float(j + 1)
		_scherm_vlak(v, k, i, [pw.call(t - 0.35, u, y), pw.call(t + 0.35, u, y),
			pw.call(t + 0.35, u, y + TRAP_PAAL), pw.call(t - 0.35, u, y + TRAP_PAAL)], vak, TRAP_LEUNING)
	# going down the rail starts a little before the first post, over the landing
	var aan := -3.0 * signf(stap) if hoog < 0.0 else 0.0
	var t0 := voet + stap * 0.5 + aan
	var y0 := hoog + TRAP_PAAL + (aan / stap) * hoog
	var t1 := voet + stap * (float(n) - 0.5)
	var y1 := hoog * float(n) + TRAP_PAAL
	_scherm_vlak(v, k, i, [pw.call(t0, u, y0 - 0.6), pw.call(t1, u, y1 - 0.6), pw.call(t1, u, y1 + 0.6),
		pw.call(t0, u, y0 + 0.6)], vak, TRAP_LEUNING)

## The half-planes n · p <= c that hold a convex polygon of SCREEN points, for
## `_knip` — the opening of the stairs as it is drawn.
static func _scherm_vlakken(p: Array) -> Array:
	var midden := Vector2.ZERO
	for q in p:
		midden += q
	midden /= float(p.size())
	var uit: Array = []
	for j in p.size():
		var s: Vector2 = p[j]
		var e: Vector2 = p[(j + 1) % p.size()]
		var n := Vector2(e.y - s.y, s.x - e.x)
		if n.dot(midden - s) > 0.0:
			n = -n
		uit.append(Vector3(n.x, n.y, n.dot(s)))
	return uit

## A convex polygon of SCREEN points, clipped to `vlakken`, in one colour.
func _scherm_vlak(v: PackedVector2Array, k: PackedColorArray, i: PackedInt32Array,
		p: Array, vlakken: Array, kl: Color) -> void:
	_scherm_vlak_kl(v, k, i, p, vlakken, [kl, kl, kl, kl])

## ... and with a colour per corner of a quad, interpolated over what is left.
func _scherm_vlak_kl(v: PackedVector2Array, k: PackedColorArray, i: PackedInt32Array,
		p: Array, vlakken: Array, kl: Array) -> void:
	var stuk := _knip(p, vlakken)
	if stuk.size() < 3:
		return
	var n := v.size()
	for q in stuk:
		v.append(q)
		k.append(_kleur_in(p, kl, q))
	for j in range(1, stuk.size() - 1):
		i.append_array([n, n + j, n + j + 1])

## The colour at `q` inside the quad `p` whose corners carry `kl`: the quads here
## are parallelograms, so `q` = p0 + s·(p1 − p0) + t·(p3 − p0) is solved exactly.
static func _kleur_in(p: Array, kl: Array, q: Vector2) -> Color:
	var o: Vector2 = p[0]
	var ex: Vector2 = p[1] - o
	var ey: Vector2 = p[3] - o
	var det := ex.x * ey.y - ex.y * ey.x
	if absf(det) < 0.000001:
		return kl[0]
	var d := q - o
	var s := clampf((d.x * ey.y - d.y * ey.x) / det, 0.0, 1.0)
	var t := clampf((ex.x * d.y - ex.y * d.x) / det, 0.0, 1.0)
	var onder := (kl[0] as Color).lerp(kl[1], s)
	var boven := (kl[3] as Color).lerp(kl[2], s)
	return onder.lerp(boven, t)

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
			# a glass house is as light inside as the lawn it stands on
			var diep := BUITEN_IN_DIEP if van_buiten and not doel.glas else BINNEN_DIEP
			kl = kl.lerp(BINNEN_SCHADUW, diep)
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
	var h0 := float(g.get("hoog", 30))
	var z0 := -2.0 * WAND_DIK
	var z1 := GEVEL_EIND
	# the ground floor, then `etages` floors over it; the roof sits on the top
	var h := h0 + GEVEL_ETAGE * float(int(g.get("etages", 0)))
	_vlak(v, k, i, [_proj(0, z0, 0), _proj(0, z1, 0), _proj(0, z1, h), _proj(0, z0, h)], GEVEL)
	_vlak(v, k, i, [_proj(0, z0, 0), _proj(0, z1, 0), _proj(0, z1, 3), _proj(0, z0, 3)],
		GEVEL_PLINT)
	var band := h0
	while band <= h + 0.1:
		_vlak(v, k, i, [_proj(0, z0, band - 3), _proj(0, z1, band - 3), _proj(0, z1, band),
			_proj(0, z0, band)], GEVEL_BAND)
		if band + GEVEL_RAAM_ONDER + GEVEL_RAAM_HOOG < h:
			_gevelramen(band, z0, z1, v, k, i)
		band += GEVEL_ETAGE
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

## One row of windows along the facade on x = 0, over the floor band at `band`:
## a white frame, sky in the panes, a cross of glazing bars and a sill.
func _gevelramen(band: float, z0: float, z1: float, v: PackedVector2Array,
		k: PackedColorArray, i: PackedInt32Array) -> void:
	var y0 := band + GEVEL_RAAM_ONDER
	var y1 := y0 + GEVEL_RAAM_HOOG
	var z := z0 + 8.0
	while z + GEVEL_RAAM_BREED < z1:
		var a := z
		var b := z + GEVEL_RAAM_BREED
		_vlak(v, k, i, [_proj(0.1, a - 1, y0 - 1), _proj(0.1, b + 1, y0 - 1),
			_proj(0.1, b + 1, y1 + 1), _proj(0.1, a - 1, y1 + 1)], KOZIJN_WIT)
		_vlak_kl(v, k, i, [_proj(0.2, a, y0), _proj(0.2, b, y0), _proj(0.2, b, y1),
			_proj(0.2, a, y1)], [GEVEL_RUIT_D, GEVEL_RUIT_D, GEVEL_RUIT, GEVEL_RUIT])
		var zm := (a + b) * 0.5
		var ym := (y0 + y1) * 0.5
		_vlak(v, k, i, [_proj(0.3, zm - 0.5, y0), _proj(0.3, zm + 0.5, y0),
			_proj(0.3, zm + 0.5, y1), _proj(0.3, zm - 0.5, y1)], KOZIJN_WIT)
		_vlak(v, k, i, [_proj(0.3, a, ym - 0.5), _proj(0.3, b, ym - 0.5),
			_proj(0.3, b, ym + 0.5), _proj(0.3, a, ym + 0.5)], KOZIJN_WIT)
		_vlak(v, k, i, [_proj(0.1, a - 1.5, y0 - 1.6), _proj(0.1, b + 1.5, y0 - 1.6),
			_proj(1.2, b + 1.5, y0 - 1.0), _proj(1.2, a - 1.5, y0 - 1.0)], KOZIJN_WIT_D)
		z += GEVEL_RAAM_STAP

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
