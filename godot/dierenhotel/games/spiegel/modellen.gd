extends RefCounted
## The voxel model of `spiegel`: an easel with a mask on it (PLAN.md §3.7.2,
## M3).  The board faces +x, so it stands along the left half of the playroom
## and the child looks straight at it; its columns run along z, column 0 on the
## LEFT of the screen (the largest z).  Everything on the board — the dots, the
## three coloured marks, the frame round the dot that is asked — is part of
## this one model, never loose decor of its own: loose decor sorts on its floor
## point and would vanish behind the board.
##
## Registered with the game id in front (`spiegel_ezel`, architecture.md §13).
## Anchor (0,0,0) on the floor under the middle of the board's front.

const HOUT := ArtDecor.HOUT
const HOUT_D := ArtDecor.HOUT_D
const BORD := Color("#FFF6EA")          ## the mask's white face
const RAND := Color("#B57EDC")          ## its purple edge and ears
const RAND_D := Color("#9A63C4")
const SPIEGEL := Color("#C9D6E3")       ## the fold line: a strip of mirror
const SPIEGEL_L := Color("#EEF4FA")
const STIP := Color("#F06BA8")          ## a pink sticker
const STIP_L := Color("#FF9CCB")
const GLANS := Color("#4B2E63")         ## the dark frame round the dot that is asked (never a mark colour)
## The marks, in the order of `SpiegelBeurt.MERKEN`: blauw, groen, geel.
const MERK := [Color("#3D8BEA"), Color("#4DB86A"), Color("#F2C230")]

const CEL := 5            ## a cell is 5 × 5 voxels
const POOT := 8           ## the board starts this high over the floor
const DIK := 2            ## the board is this thick (x −1 .. 0)

## Name -> builder, for `Art.registreer_model` and `definitie().modellen`.
static func tabel() -> Dictionary:
	return {"spiegel_ezel": ezel}

## The width of the board along z and its height, frame and fold lines in.
static func maat(r: int, k: int, as_: String) -> Vector2i:
	var breed := 2 + k * CEL + 1
	var hoog := 2 + r * CEL + (1 if as_ == "vh" else 0)
	return Vector2i(breed, hoog)

## The middle of cell [rij, kol] on the board's face: `Vector3(x, y, z)`
## relative to the anchor — where a dot lands, where the sparkles go.
static func cel_midden(rij: int, kol: int, r: int, k: int, as_: String) -> Vector3:
	var z_hi := _z_hoog(kol, k)
	var y_hi := _y_hoog(rij, r, as_)
	return Vector3(1.0, float(y_hi) - 2.0, float(z_hi) - 2.0)

## The board's top edge (y) — the card aims a little over it.
static func top(r: int, as_: String) -> int:
	return POOT + maat(r, 4, as_).y

## `params`: `r` rows, `k` columns, `as` "v" | "vh", `stip` the pink dots
## `[[rij, kol], …]`, `merk` the three marks `[[rij, kol] or null, …]` in the
## order blauw, groen, geel, `bron` the dot that shines `[rij, kol]` or `[]`.
## Without params: the empty mask of the resting easel, 4 × 6, one fold line.
static func ezel(params: Dictionary = {}) -> Array:
	var v: Array = []
	var r := int(params.get("r", 4))
	var k := int(params.get("k", 6))
	var as_ := str(params.get("as", "v"))
	var m := maat(r, k, as_)
	var z0 := -m.x / 2                       # the right edge on screen (smallest z)
	var z1 := z0 + m.x - 1
	var y0 := POOT
	var y1 := POOT + m.y - 1
	# the easel: two legs under the ends, a back leg and a ledge under the board
	for pz in [z0 + 2, z1 - 3]:
		ArtVorm.bx(v, -DIK, 0, pz, 2, y0 + 4, 2, HOUT_D)
	for i in 10:
		ArtVorm.bx(v, -DIK - 2 - i, y0 + 10 - 2 * i, -1, 1, 2, 2, HOUT_D)
	ArtVorm.bx(v, -DIK, y0 - 1, z0, DIK + 2, 1, m.x, HOUT)
	# the mask: the white face, a purple edge, and two ears on top
	ArtVorm.bx(v, -DIK, y0, z0, DIK, m.y, m.x, BORD)
	ArtVorm.bx(v, 0, y0, z0, 1, 1, m.x, RAND)
	ArtVorm.bx(v, 0, y1, z0, 1, 1, m.x, RAND)
	ArtVorm.bx(v, 0, y0, z0, 1, m.y, 1, RAND)
	ArtVorm.bx(v, 0, y0, z1, 1, m.y, 1, RAND)
	for kant in [z0, z1 - 5]:
		for rij in 3:
			ArtVorm.bx(v, -DIK, y1 + 1 + rij, kant + rij, DIK + 1, 1, 6 - 2 * rij, RAND if rij < 2 else RAND_D)
	# the fold line down the middle, and in groep 5 the one across
	var zv := _z_hoog(k / 2 - 1, k) - CEL
	ArtVorm.bx(v, 0, y0 + 1, zv, 1, m.y - 2, 1, SPIEGEL)
	if as_ == "vh":
		var yh := _y_hoog(r / 2 - 1, r, as_) - CEL
		ArtVorm.bx(v, 0, yh, z0 + 1, 1, 1, m.x - 2, SPIEGEL)
		v.append({"x": 1, "y": yh, "z": zv, "k": SPIEGEL_L})
	else:
		for y in range(y0 + 2, y1 - 1, 4):
			v.append({"x": 1, "y": y, "z": zv, "k": SPIEGEL_L})
	# the marks: a hollow square in the middle of a cell, standing out
	var merk: Array = params.get("merk", [])
	for i in mini(merk.size(), MERK.size()):
		var c = merk[i]
		if c == null or (c as Array).size() < 2:
			continue
		var p := cel_midden(int(c[0]), int(c[1]), r, k, as_)
		for dy in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dy == 0 and dz == 0:
					continue
				v.append({"x": 1, "y": int(p.y) + dy, "z": int(p.z) + dz, "k": MERK[i]})
	# the frame round the dot that is asked
	var bron: Array = params.get("bron", [])
	if bron.size() >= 2:
		var p := cel_midden(int(bron[0]), int(bron[1]), r, k, as_)
		for d in range(-2, 3):
			for rand in [-2, 2]:
				v.append({"x": 1, "y": int(p.y) + rand, "z": int(p.z) + d, "k": GLANS})
				v.append({"x": 1, "y": int(p.y) + d, "z": int(p.z) + rand, "k": GLANS})
	# the dots: a pink sticker of 3 × 3 with a light top edge
	for c in params.get("stip", []):
		var p := cel_midden(int(c[0]), int(c[1]), r, k, as_)
		ArtVorm.bx(v, 1, int(p.y) - 1, int(p.z) - 1, 1, 3, 3, STIP)
		ArtVorm.bx(v, 1, int(p.y) + 1, int(p.z) - 1, 1, 1, 2, STIP_L)
	return v

## The top voxel row of the cells in row `rij` (rows count from the top).
static func _y_hoog(rij: int, r: int, as_: String) -> int:
	var m := maat(r, 4, as_)
	var y1 := POOT + m.y - 1
	var hi := y1 - 1 - rij * CEL
	if as_ == "vh" and rij >= r / 2:
		hi -= 1
	return hi

## The highest z of the cells in column `kol` (column 0 is on the left of the
## screen, the largest z); the fold line takes one voxel between the halves.
static func _z_hoog(kol: int, k: int) -> int:
	var breed := 2 + k * CEL + 1
	var z1 := -breed / 2 + breed - 1
	var hi := z1 - 1 - kol * CEL
	if kol >= k / 2:
		hi -= 1
	return hi
