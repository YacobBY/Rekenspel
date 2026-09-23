class_name ArtDecorBuiten
extends RefCounted
## The decor of the passages between the rooms outdoors (owner, 2026-09-23:
## "Het zwembad vanuit de tuin gezien is niet duidelijk dat lijkt gewoon op een
## huis" — "Ook andere ruimtes als keuken naar tuin hebben geen mooie overgang
## die sprekend is").  Every exit should say where it goes before a button
## does: the pool behind the garden fence is seen through a white pool gate
## with a lifebuoy on it, next to a ladder and a parasol; the way back from the
## pool is a rose arch with the garden's tree behind it; the kitchen's back
## door in the hotel's wall has an awning over it, a doormat before it and a
## kitchen window with a flower box beside it.
##
## Same primitives, palette and bake path as `ArtDecor`, which merges this
## table into its own; the base models stay frozen (their golden images).
## Wall pieces are built against the z = 0 wall (z from 0 outward) and have a
## `*z` twin mirrored over the diagonal for the x = 0 wall, exactly like the
## bedroom window.

const HOUT := ArtDecor.HOUT
const HOUT_D := ArtDecor.HOUT_D
const HOUT_L := ArtDecor.HOUT_L
const KUSSEN := ArtDecor.KUSSEN
const PAPIER := ArtDecor.PAPIER
const METAAL := ArtDecor.METAAL
const METAAL_L := ArtDecor.METAAL_L
const DEKEN := ArtDecor.DEKEN
const DEKEN_D := ArtDecor.DEKEN_D
const STOF := ArtDecor.STOF
const POT := ArtDecor.POT
const BLAD := ArtDecor.BLAD
const BLAD_A := ArtDecor.BLAD_A
const BLAD_B := ArtDecor.BLAD_B
const DAK := ArtDecor.DAK

## The few colours this file adds, in the same pastel family.
const BOEI := Color("#EF8A7A")        ## the lifebuoy and the parasol: coral ...
const BLAUW := Color("#6FA3CC")       ## ... the pool gate's blue
const GEEL := Color("#FFE49B")        ## a yellow flower (the bedrooms' ZONNE)
const LILA := Color("#D9C6EC")        ## a lilac flower
const ROOS := Color("#F19FB5")        ## a rose
const KOKOS := Color("#CDA676")       ## the coir of a doormat
const KOKOS_D := Color("#AE8757")
const LAMPLICHT := Color("#FFEFC6")   ## a kitchen window: warm light inside
const LAMPLICHT_L := Color("#FFF8E3")

## Every model name this file provides, in a fixed order.
const NAMEN: Array[String] = ["zwembadpoort", "rozenboog", "gevelraam", "gevelraamz",
	"luifel", "luifelz", "deurmat", "deurmatz", "parasol", "zwembadtrap", "bloemstruik"]

# ---------------------------------------------------------------- de poorten

## The pool gate in a fence along x (the garden's back fence): two white posts
## with blue caps and a blue bar, a blue sign with two white waves on top, and
## a coral-and-white lifebuoy hanging on the left post.  The opening is the
## 12 voxels between the posts; 19 wide, 24 tall.
static func zwembadpoort(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -8, 0, -1, 2, 18, 2, PAPIER)
	ArtVorm.bx(v, 7, 0, -1, 2, 18, 2, PAPIER)
	ArtVorm.bx(v, -9, 18, -2, 4, 1, 4, BLAUW)
	ArtVorm.bx(v, 6, 18, -2, 4, 1, 4, BLAUW)
	ArtVorm.bx(v, -6, 15, -1, 13, 2, 2, BLAUW)
	# the sign: two white waves on blue, facing the garden (+z) — a wave two
	# voxels up and two down, not one: at one it reads as a chessboard
	ArtVorm.bx(v, -5, 17, 0, 11, 7, 1, DEKEN_D)
	var golf := [0, 1, 1, 0, 0, 1, 1, 0, 0]
	for rij in [18, 21]:
		for x in range(-4, 5):
			var y: int = rij + int(golf[x + 4])
			ArtVorm.verf(v, x, x, y, y, 0, 0, PAPIER)
	# the lifebuoy on the front of the left post
	var cx := -7.0
	var cy := 9.0
	for x in range(-11, -2):
		for y in range(5, 14):
			var dx := float(x) - cx + 0.5
			var dy := float(y) - cy + 0.5
			var d := sqrt(dx * dx + dy * dy)
			if d < 1.9 or d > 3.9:
				continue
			var kl := BOEI if dx * dy >= 0.0 else KUSSEN
			ArtVorm.bx(v, x, y, 1, 1, 1, 2, kl)
	return v

## The rose arch in a fence along z (the pool's side fence, back to the
## garden): two wooden posts overgrown with leaves, a leafy arch over the
## opening and roses in pink, white and yellow on the side that faces the
## pool.  The opening is the 12 voxels between the posts; 19 wide, 26 tall.
static func rozenboog(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -1, 0, -8, 2, 17, 2, HOUT_D)
	ArtVorm.bx(v, -1, 0, 7, 2, 17, 2, HOUT_D)
	var kl := [BLAD_A, BLAD_B, BLAD, BLAD_B, BLAD_A, BLAD, BLAD_B, BLAD_A, BLAD]
	for t in 9:
		var hoek := PI * float(t) / 8.0
		ArtVorm.ell(v, 0.0, 16.0 + 7.0 * sin(hoek), -7.0 * cos(hoek), 2.4, 2.4, 2.4,
			kl[t], {"e": 2.2})
	for z in [-7.0, 7.5]:
		for y in [4.0, 9.0, 13.0]:
			ArtVorm.ell(v, 0.0, y, z, 1.9, 2.2, 1.9, BLAD_B if y == 9.0 else BLAD_A,
				{"e": 2.2})
	# the roses: small blossoms on the outer (+x) face
	var rozen := [[3, 16, -7, ROOS], [2, 20, -5, KUSSEN], [2, 23, -2, ROOS],
		[2, 23, 2, GEEL], [2, 21, 5, ROOS], [3, 17, 7, KUSSEN], [2, 11, -7, ROOS],
		[2, 6, 7, GEEL], [2, 12, 8, ROOS], [2, 5, -8, KUSSEN]]
	for r in rozen:
		ArtVorm.verf(v, r[0] - 1, r[0] + 1, r[1] - 1, r[1], r[2], r[2] + 1, r[3])
	return v

# ------------------------------------------------------------- aan de gevel

## A kitchen window in the hotel's back wall, seen from the garden: a white
## frame with a cross, warm light behind the glass, white half curtains, a sill
## and a terracotta flower box with flowers in front of it.  Built against the
## z = 0 wall; 17 wide, 19 tall.  Hang `gevelraamz` on the x = 0 wall with
## `{"ver": true, "y": 9}`.
static func gevelraam(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -7, 4, 0, 15, 15, 2, KUSSEN)
	ArtVorm.verf(v, -6, 6, 5, 17, 1, 1, LAMPLICHT)
	ArtVorm.verf(v, -6, -4, 13, 17, 1, 1, LAMPLICHT_L)
	ArtVorm.verf(v, -6, 6, 5, 8, 1, 1, PAPIER)            # the half curtains
	ArtVorm.verf(v, 0, 0, 5, 17, 1, 1, KUSSEN)            # the cross
	ArtVorm.verf(v, -6, 6, 11, 11, 1, 1, KUSSEN)
	ArtVorm.bx(v, -8, 3, 0, 17, 1, 3, HOUT_L)             # the sill
	ArtVorm.bx(v, -7, 0, 0, 15, 3, 3, POT)                # the flower box
	ArtVorm.verf(v, -7, 7, 2, 2, 2, 2, DAK)
	var bloem := [[-5, ROOS], [-2, GEEL], [1, KUSSEN], [4, ROOS], [6, LILA]]
	for b in bloem:
		ArtVorm.bx(v, b[0], 3, 3, 1, 2, 1, BLAD)
		ArtVorm.bx(v, b[0] - 1, 5, 3, 2, 1, 1, BLAD_B)
		ArtVorm.bx(v, b[0], 6, 3, 1, 1, 1, b[1])
	return v

## A striped awning over a door in the hotel's back wall: coral and white
## stripes sloping away from the wall and a scalloped edge.  Built against the
## z = 0 wall; 16 wide, 6 deep.  Hang `luifelz` over the door on the x = 0
## wall with `{"ver": true, "y": <door height + 1>}`.
static func luifel(_p := {}) -> Array:
	var v: Array = []
	for zz in 6:
		var yy := 6 - int(floor(zz * 0.7))
		for xx in range(-8, 8):
			var kl := BOEI if ((xx + 8) >> 1) & 1 == 0 else KUSSEN
			v.append({"x": xx, "y": yy, "z": zz, "k": kl})
			if zz == 0:
				v.append({"x": xx, "y": yy + 1, "z": zz, "k": kl})
	for xx in range(-8, 8):
		var kl := BOEI if ((xx + 8) >> 1) & 1 == 0 else KUSSEN
		var diep := 2 if ((xx + 8) % 4) < 2 else 1
		for j in diep:
			v.append({"x": xx, "y": 2 - j, "z": 5, "k": kl})
	for xx in [-8, 7]:
		ArtVorm.bx(v, xx, 1, 0, 1, 5, 1, HOUT_D)
	return v

# ------------------------------------------------------------- op de grond

## A coir doormat with a paw print, 12 x 7, one voxel thin, before a door.
static func deurmat(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -6, 0, -3, 12, 1, 7, KOKOS)
	ArtVorm.verf(v, -6, 5, 0, 0, -3, -3, KOKOS_D)
	ArtVorm.verf(v, -6, 5, 0, 0, 3, 3, KOKOS_D)
	ArtVorm.verf(v, -6, -6, 0, 0, -3, 3, KOKOS_D)
	ArtVorm.verf(v, 5, 5, 0, 0, -3, 3, KOKOS_D)
	# the paw: a pad and three toes
	ArtVorm.verf(v, -1, 1, 0, 0, 0, 1, KOKOS_D)
	for teen in [[-2, -1], [0, -2], [2, -1]]:
		ArtVorm.verf(v, teen[0], teen[0], 0, 0, teen[1], teen[1], KOKOS_D)
	return v

## A parasol on the pool deck: a white pole on a metal foot and a coral and
## white canopy, 17 across and 21 tall.
static func parasol(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -2, 0, -2, 4, 1, 4, METAAL)
	ArtVorm.bx(v, -1, 1, -1, 2, 17, 2, PAPIER)
	for x in range(-8, 9):
		for z in range(-8, 9):
			var fx := float(x) + 0.5
			var fz := float(z) + 0.5
			var d := sqrt(fx * fx + fz * fz)
			if d > 8.4:
				continue
			var y := 17 + int(round((8.4 - d) * 0.42))
			var vak := int(floor((atan2(fz, fx) + PI) / (PI / 4.0))) % 2
			v.append({"x": x, "y": y, "z": z, "k": BOEI if vak == 0 else KUSSEN})
	ArtVorm.bx(v, -1, 21, -1, 2, 1, 2, KUSSEN)
	return v

## The handrails of a pool ladder, standing on the rim with the water behind
## it (−z): two bent metal tubes, 7 wide and 9 tall.
static func zwembadtrap(_p := {}) -> Array:
	var v: Array = []
	for x in [-3, 3]:
		ArtVorm.bx(v, x, 0, 1, 1, 8, 1, METAAL_L)
		ArtVorm.bx(v, x, 8, -3, 1, 1, 5, METAAL_L)
		ArtVorm.bx(v, x, 4, -3, 1, 4, 1, METAAL)
	return v

## A flowering bush: a green mound with pink, yellow, white and lilac flowers
## on top, 9 across and 7 tall.
static func bloemstruik(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.ell(v, 0, 2.6, 0, 4.2, 3.0, 4.2, BLAD_A, {"e": 2.2, "ymin": 0})
	ArtVorm.ell(v, 1, 3.4, -1, 2.6, 2.4, 2.6, BLAD_B, {"e": 2.2, "ymin": 0})
	var bloem := [[-2, 1, ROOS], [1, -2, GEEL], [2, 2, KUSSEN], [-1, -1, LILA],
		[0, 3, ROOS], [3, -1, ROOS], [-3, -2, GEEL]]
	for b in bloem:
		var hoogste := -1
		for p in v:
			if p["x"] == b[0] and p["z"] == b[1]:
				hoogste = maxi(hoogste, int(p["y"]))
		if hoogste >= 0:
			v.append({"x": b[0], "y": hoogste + 1, "z": b[1], "k": b[2]})
	return v

# --------------------------------------------------------------------- register

## `naam -> Callable(params) -> Array` of voxels {x, y, z, k}.
static func tabel() -> Dictionary:
	return {
		"zwembadpoort": Callable(ArtDecorBuiten, "zwembadpoort"),
		"rozenboog": Callable(ArtDecorBuiten, "rozenboog"),
		"gevelraam": Callable(ArtDecorBuiten, "gevelraam"),
		"gevelraamz": func(_p := {}): return ArtVorm.draai(gevelraam()),
		"luifel": Callable(ArtDecorBuiten, "luifel"),
		"luifelz": func(_p := {}): return ArtVorm.draai(luifel()),
		"deurmat": Callable(ArtDecorBuiten, "deurmat"),
		"deurmatz": func(_p := {}): return ArtVorm.draai(deurmat()),
		"parasol": Callable(ArtDecorBuiten, "parasol"),
		"zwembadtrap": Callable(ArtDecorBuiten, "zwembadtrap"),
		"bloemstruik": Callable(ArtDecorBuiten, "bloemstruik"),
	}
