class_name ArtDecorWasserij
extends RefCounted
## Decor models for the laundry.  Same primitives, same palette and the same
## bake path as `ArtDecor`, which merges this table into its own (see
## `ArtDecor.tabel()` and `ArtDecor.alle_namen()`).  Every model is anchored at
## (0, 0, 0) on the floor, y upward, and is registered as a protected world model.
##
## The owner, 2026-09-17: the wasserij was "heel kaal" — a cupboard and a tub.
## These five models furnish it: two front loaders with a soap shelf over them
## along the back wall, an ironing board on the narrow strip right of the door,
## a drying rack against the left wall and a laundry basket next to the tub.
## Everything stays out of the strip the `was` game draws in (games-b.md §4.4:
## the crates on the diagonal x + z = 66, the pile at (60, 54), the card at
## (88, 84)).  `droogrekz` and `strijkplankz` are the same pieces a quarter
## turn round, for whichever of the two walls they end up against.
##
## The visible faces are +y (top), +x (screen right-down) and +z (screen
## left-down), so a piece against the back wall z = 0 shows its +z face to the
## child: that is where the porthole, the drawer and the knobs go.

## Three new soft colours in the house style — the washing on the rack, the
## laundry in the basket and the soap boxes on the shelf.
const MINT := Color("#C9E4D2")
const LILA := Color("#D9CBEA")
const ZACHTGEEL := Color("#FCEBB6")
## The porthole's ring: the soft blue-grey of the till's screen, dark enough to
## read as a ring against the white body.
const RING := Color("#A0A6C0")

## Every model name this file provides, in a fixed order.
const NAMEN: Array[String] = ["wasmachine", "droogrek", "droogrekz", "wasmand",
	"strijkplank", "strijkplankz", "zeepplank"]

# ------------------------------------------------------------------ de modellen

## A front loader, 12 x 12 and 16 tall, against the back wall z = 0.  The round
## door sits on the +z face: a metal ring with a blue window in it, a control
## strip with two knobs on top and the detergent drawer just under it.
static func wasmachine(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -6, 0, -6, 12, 16, 12, ArtDecor.KUSSEN)
	# a grey plinth, so the machine does not melt into the floor tiles
	ArtVorm.verf(v, -6, 5, 0, 0, -6, 5, ArtDecor.METAAL)
	# the control strip over the whole top
	ArtVorm.verf(v, -6, 5, 14, 15, -6, 5, ArtDecor.METAAL_L)
	# The porthole is PAINTED on the front face, not built proud of it: a ring
	# of voxels standing out of the body turns into a staircase of little tops
	# and sides in this projection and reads as a smudge, a painted circle
	# reads as a door.  Only the handle really sticks out.
	for x in range(-5, 5):
		for y in range(2, 11):
			var q := (float(x) + 0.5) * (float(x) + 0.5) + float((y - 6) * (y - 6))
			if q <= 8.0:
				ArtVorm.verf(v, x, x, y, y, 5, 5, ArtDecor.DEKEN)
			elif q <= 17.0:
				ArtVorm.verf(v, x, x, y, y, 5, 5, RING)
	ArtVorm.verf(v, -3, -2, 7, 8, 5, 5, ArtDecor.METAAL_L)   # a glint on the glass
	ArtVorm.bx(v, 4, 5, 6, 1, 3, 1, ArtDecor.METAAL)         # the door handle
	# the detergent drawer just under the control strip
	ArtVorm.verf(v, -5, 4, 12, 13, 5, 5, ArtDecor.METAAL_L)
	ArtVorm.verf(v, -5, 4, 12, 12, 5, 5, ArtDecor.METAAL)
	ArtVorm.bx(v, -2, 13, 6, 4, 1, 1, ArtDecor.METAAL)
	# two knobs on the strip
	ArtVorm.bx(v, -4, 14, 6, 2, 2, 1, ArtDecor.DEKEN_D)
	ArtVorm.bx(v, 1, 14, 6, 2, 2, 1, ArtDecor.STOF)
	return v

## A drying rack, 16 x 8 and 15 tall: two wooden uprights on splayed feet,
## three rails along x and four pieces of washing hanging over them.
## The A-frame of the first try (legs leaning from z = +-4 to 0) stepped
## through the voxel grid as a staircase of brown blocks and read as a fence;
## a straight rack with a foot reads as a rack at one glance.
static func droogrek(_p := {}) -> Array:
	var v: Array = []
	for x0 in [-8, 6]:
		ArtVorm.bx(v, x0, 0, 0, 2, 15, 2, ArtDecor.HOUT)       # the upright
		ArtVorm.bx(v, x0, 0, -3, 2, 2, 8, ArtDecor.HOUT_D)     # the splayed foot
	for y in [4, 9, 14]:
		ArtVorm.bx(v, -8, y, 1, 16, 1, 2, ArtDecor.HOUT_L)     # the three rails
	# The washing hangs over a rail, in front of it, down to the next one.
	# Three voxels thick, with the fold on the rail and the hem at the bottom
	# in a deeper shade: four voxels read as a crate, three as cloth.
	ArtVorm.bx(v, -6, 6, 0, 5, 9, 3, ArtDecor.STOF)
	ArtVorm.verf(v, -6, -2, 14, 14, 0, 2, Color("#F7C6D4"))
	ArtVorm.verf(v, -6, -2, 6, 6, 0, 2, Color("#E79AB0"))
	ArtVorm.bx(v, 0, 7, 0, 5, 8, 3, LILA)
	ArtVorm.verf(v, 0, 4, 14, 14, 0, 2, Color("#E7DCF3"))
	ArtVorm.verf(v, 0, 4, 7, 7, 0, 2, Color("#C3B2D8"))
	ArtVorm.bx(v, -5, 0, 0, 5, 5, 3, MINT)
	ArtVorm.verf(v, -5, -1, 4, 4, 0, 2, Color("#DFF0E5"))
	ArtVorm.bx(v, 1, 1, 0, 3, 4, 3, ArtDecor.DEKEN)
	ArtVorm.verf(v, 1, 3, 1, 1, 0, 2, ArtDecor.DEKEN_D)
	return v

## The laundry basket, 11 x 9 and 8 tall: oval wickerwork with a heap of
## washing over the rim.  The base `mand` is round, bigger and holds a flat
## cushion of cloth; this one is the laundry's own basket.
static func wasmand(_p := {}) -> Array:
	var v: Array = []
	for x in range(-5, 6):
		for z in range(-4, 5):
			var q := float(x * x) / 25.0 + float(z * z) / 16.0
			if q > 1.05:
				continue
			if q > 0.45:
				ArtVorm.bx(v, x, 0, z, 1, 7, 1, ArtDecor.HOUT)
				ArtVorm.verf(v, x, x, 3, 3, z, z, ArtDecor.HOUT_D)
				ArtVorm.verf(v, x, x, 6, 6, z, z, ArtDecor.HOUT_L)
			else:
				ArtVorm.bx(v, x, 0, z, 1, 4, 1, ArtDecor.HOUT_D)
	ArtVorm.ell(v, 0, 5, 0, 4.2, 3.2, 3.4, LILA, {"e": 2.8, "ymin": 4})
	ArtVorm.ell(v, -1, 6, 1, 2.8, 2.6, 2.4, ArtDecor.DEKEN, {"e": 2.8, "ymin": 5})
	ArtVorm.ell(v, 2, 7, -1, 2.2, 2.0, 2.0, ZACHTGEEL, {"e": 2.8, "ymin": 6})
	return v

## The ironing board, 16 x 6 and 11 tall: a soft board on thin metal legs, a
## pointed nose at the low-x end and the iron parked on it.
static func strijkplank(_p := {}) -> Array:
	var v: Array = []
	for x0 in [-6, 5]:
		ArtVorm.bx(v, x0, 0, -2, 1, 7, 1, ArtDecor.METAAL)
		ArtVorm.bx(v, x0, 0, 1, 1, 7, 1, ArtDecor.METAAL)
	ArtVorm.bx(v, -6, 3, -1, 12, 1, 2, ArtDecor.METAAL_L)   # the cross brace
	# the board tapers to a nose at the low-x end; its rim keeps the cover's
	# pastel edge all the way round the taper
	for i in 16:
		var zr := 3 if i >= 5 else (2 if i >= 2 else 1)
		ArtVorm.bx(v, -8 + i, 7, -zr, 1, 1, 2 * zr, ArtDecor.KUSSEN)
		ArtVorm.verf(v, -8 + i, -8 + i, 7, 7, zr - 1, zr - 1, ArtDecor.STOF)
	# the iron, nose towards the pointed end of the board
	ArtVorm.bx(v, 2, 8, -2, 5, 1, 4, ArtDecor.METAAL)
	ArtVorm.bx(v, 3, 9, -2, 4, 2, 4, ArtDecor.METAAL_L)
	ArtVorm.bx(v, 4, 11, -1, 2, 1, 2, ArtDecor.DEKEN_D)
	return v

## A shelf on the wall z = 0 with three soap boxes on it (`ver`), hung above
## the two washing machines.  The height sits in the model, as in `prikbord`.
static func zeepplank(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -9, 21, 0, 1, 3, 2, ArtDecor.HOUT_D)      # the two brackets
	ArtVorm.bx(v, 7, 21, 0, 1, 3, 2, ArtDecor.HOUT_D)
	ArtVorm.bx(v, -10, 24, 0, 20, 1, 4, ArtDecor.HOUT)      # the shelf
	ArtVorm.verf(v, -10, 9, 24, 24, 3, 3, ArtDecor.HOUT_L)
	ArtVorm.bx(v, -8, 25, 0, 5, 4, 3, ZACHTGEEL)            # a box of powder
	ArtVorm.verf(v, -8, -4, 28, 28, 0, 2, ArtDecor.DEKEN_D)
	ArtVorm.bx(v, -1, 25, 0, 3, 5, 3, MINT)                 # a bottle
	ArtVorm.bx(v, 0, 30, 1, 1, 2, 1, ArtDecor.GOUD)
	ArtVorm.bx(v, 4, 25, 0, 4, 3, 3, LILA)                  # and a small box
	ArtVorm.verf(v, 4, 7, 27, 27, 0, 2, ArtDecor.STOF)
	return v

# --------------------------------------------------------------------- register

## `naam -> Callable(params) -> Array` of voxels {x, y, z, k}.  `droogrekz` and
## `strijkplankz` are mirrored over the diagonal, for the left wall x = 0.
static func tabel() -> Dictionary:
	return {
		"wasmachine": Callable(ArtDecorWasserij, "wasmachine"),
		"droogrek": Callable(ArtDecorWasserij, "droogrek"),
		"droogrekz": func(_p := {}): return ArtVorm.draai(droogrek()),
		"wasmand": Callable(ArtDecorWasserij, "wasmand"),
		"strijkplank": Callable(ArtDecorWasserij, "strijkplank"),
		"strijkplankz": func(_p := {}): return ArtVorm.draai(strijkplank()),
		"zeepplank": Callable(ArtDecorWasserij, "zeepplank"),
	}
