extends RefCounted
## The voxel models of `oogst` (games-c.md §2.4): the picking table with its ten
## punnet places.  The punnets are part of the table's OWN model, never loose
## decor of their own: loose decor sorts on its floor point, so a punnet on the
## back half of the table would be drawn before the table and vanish under its
## top.  One model, one plate, and the baker sorts the voxels itself.
##
## Registered with the game id in front (`oogst_tafel`, architecture.md §13
## Q-X1-11).  Anchor (0,0,0) on the floor under the middle of the table.

const HOUT := ArtDecor.HOUT
const HOUT_D := ArtDecor.HOUT_D
const HOUT_L := ArtDecor.HOUT_L
const BAKJE := Color("#9CCB8C")      ## a green punnet
const BAKJE_D := Color("#83B474")
const AARDBEI := Color("#E4574B")
const AARDBEI_L := Color("#F27E70")
const KROON := Color("#6FA05A")      ## the green crown on top of every berry

## The table: 26 along x, 37 along z, its top at y = TOP.
const TOP := 8
## Ten places on the top: two columns along x, five rows along z.  A punnet is
## 12 long (x) and 6 deep (z); `PLEK` is the middle of place i, relative to the
## table's anchor.  Place 0..4 are the left column from back to front, 5..9 the
## right one, so the child reads "five punnets, and five more".
const BAKJE_L := 12
const BAKJE_D_Z := 6
const KOLOM_X := [-6, 7]
const RIJ_Z := [-14, -7, 0, 7, 14]

## Name -> builder, for `Art.registreer_model` and `definitie().modellen`.
static func tabel() -> Dictionary:
	return {"oogst_tafel": tafel}

## Where punnet `i` stands on the table, relative to the table's anchor.
static func plek(i: int) -> Vector2i:
	return Vector2i(int(KOLOM_X[int(i / 5) % 2]), int(RIJ_Z[i % 5]))

## The table with its punnets.  `params.b` is one entry per place, 0..9: -1 (or
## missing) = no punnet there, 0..10 = a punnet with that many berries.  (No
## ghost berries any more: a miss gets no help, owner 2026-09-24.)
static func tafel(params: Dictionary = {}) -> Array:
	var v: Array = []
	# the top, one plank line darker, and four legs
	ArtVorm.bx(v, -13, TOP - 1, -18, 26, 1, 37, HOUT_L)
	ArtVorm.verf(v, -13, 12, TOP - 1, TOP - 1, -1, -1, HOUT)
	ArtVorm.verf(v, -13, 12, TOP - 1, TOP - 1, 8, 8, HOUT)
	ArtVorm.verf(v, -13, 12, TOP - 1, TOP - 1, -10, -10, HOUT)
	ArtVorm.bx(v, -13, TOP - 2, -18, 26, 1, 1, HOUT_D)          # the apron
	ArtVorm.bx(v, -13, TOP - 2, 18, 26, 1, 1, HOUT_D)
	for lx in [-13, 11]:
		for lz in [-18, 17]:
			ArtVorm.bx(v, lx, 0, lz, 2, TOP - 2, 1, HOUT_D)
	var b: Array = params.get("b", [])
	for i in 10:
		var n := int(b[i]) if i < b.size() else -1
		if n < 0:
			continue
		_bakje(v, plek(i), clampi(n, 0, 10))
	return v

## One green punnet at `p` on the top: a tray with a rim, and in it up to ten
## berries in two rows of five (the ten-frame): the back row first, left to
## right, then the front row.  Every berry is 2 × 2 × 2 with its own green
## crown, so two berries that touch still count as two.
static func _bakje(v: Array, p: Vector2i, n: int) -> void:
	var x0 := p.x - int(BAKJE_L / 2.0)
	var z0 := p.y - int(BAKJE_D_Z / 2.0)
	ArtVorm.bx(v, x0, TOP, z0, BAKJE_L, 1, BAKJE_D_Z, BAKJE_D)
	ArtVorm.bx(v, x0, TOP + 1, z0, BAKJE_L, 1, 1, BAKJE)
	ArtVorm.bx(v, x0, TOP + 1, z0 + BAKJE_D_Z - 1, BAKJE_L, 1, 1, BAKJE)
	ArtVorm.bx(v, x0, TOP + 1, z0 + 1, 1, 1, BAKJE_D_Z - 2, BAKJE)
	ArtVorm.bx(v, x0 + BAKJE_L - 1, TOP + 1, z0 + 1, 1, 1, BAKJE_D_Z - 2, BAKJE)
	for k in 10:
		var bx := x0 + 1 + (k % 5) * 2
		var bz := z0 + 1 + int(k / 5) * 2
		if k < n:
			ArtVorm.bx(v, bx, TOP + 1, bz, 2, 2, 2, AARDBEI)
			ArtVorm.verf(v, bx, bx, TOP + 2, TOP + 2, bz, bz, AARDBEI_L)
			v.append({"x": bx + 1, "y": TOP + 3, "z": bz, "k": KROON})
