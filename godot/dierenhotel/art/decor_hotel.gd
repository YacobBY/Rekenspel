class_name ArtDecorHotel
extends RefCounted
## Decor models for the reception and the corridor.  Same primitives, same palette and the same
## bake path as `ArtDecor`, which merges this table into its own (see
## `ArtDecor.tabel()` and `ArtDecor.alle_namen()`).  Every model is anchored at
## (0, 0, 0) on the floor, y upward, and is registered as a protected world model.
##
## Wall pieces (`klok`, `kapstok`, `schilderij`, `schilderij2`) lie flat against
## the back wall and every detail on them is PAINTED on the layer the child
## looks at, never added in front of it.  Mind which layer that is: a slab
## `bx(v, x, y, 0, w, h, 2)` fills z = 0 AND z = 1, so its front face is z = 1
## (a `verf(..., 2, 2, ...)` on it repaints nothing at all and the picture stays
## blank).  A room hangs a piece with `"ver": true` plus the height in `"y"`;
## the `*z` variants (`ArtVorm.draai`) belong on the left wall.

## A few soft colours in the house style, next to the palette of `ArtDecor`.
const ROZE := Color("#F7C8D8")     ## scarf, suitcase, paw print
const LILA := Color("#D9C7EC")     ## a flower
const MINT := Color("#BCE0CD")     ## leash, grass line
const ZON := Color("#FFE49B")      ## a flower, the sun in the second picture
const HEMEL := Color("#CFE6F5")    ## vase and canvas sky

## Every model name this file provides, in a fixed order.
const NAMEN: Array[String] = ["klok", "bloemen", "bankje", "bankjez", "koffer",
	"kapstok", "schilderij", "schilderij2"]

# ------------------------------------------------------------------ aan de wand

## The round wall clock above the desk: a gold disc z = 0..1, a white face on
## z = 2 with four ticks and two hands (ten past ten, the friendliest hour).
static func klok(_p := {}) -> Array:
	var v: Array = []
	for x in range(-5, 6):
		for y in range(-5, 6):
			var q := x * x + y * y
			if q > 30:
				continue
			# one flat disc, z = 0..2: a stepped white plate in front of a wider
			# gold one reads as a ragged blob, a white face inside the gold ring
			# on the same front layer reads as a clock
			ArtVorm.bx(v, x, 5 + y, 0, 1, 1, 2, ArtDecor.GOUD)
			ArtVorm.bx(v, x, 5 + y, 2, 1, 1, 1,
				ArtDecor.PAPIER if q <= 20 else ArtDecor.GOUD)
	ArtVorm.verf(v, -1, 1, 9, 9, 2, 2, ArtDecor.GOUD_D)      # 12
	ArtVorm.verf(v, -1, 1, 1, 1, 2, 2, ArtDecor.GOUD_D)      # 6
	ArtVorm.verf(v, -4, -4, 4, 6, 2, 2, ArtDecor.GOUD_D)     # 9
	ArtVorm.verf(v, 4, 4, 4, 6, 2, 2, ArtDecor.GOUD_D)       # 3
	ArtVorm.verf(v, 0, 0, 5, 8, 2, 2, ArtDecor.DEURKL)       # the long hand, up
	ArtVorm.verf(v, 0, 3, 5, 5, 2, 2, ArtDecor.DEURKL)       # the short hand, right
	return v

## The coat rack near the corridor's left end: a board with four hooks, a
## striped scarf on the second and a leash with its collar on the last.
static func kapstok(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -7, 16, 0, 15, 4, 2, ArtDecor.HOUT)
	ArtVorm.verf(v, -7, 7, 19, 19, 1, 1, ArtDecor.HOUT_L)
	ArtVorm.verf(v, -7, 7, 16, 16, 1, 1, ArtDecor.HOUT_D)
	for i in 4:
		var hx := -6 + i * 4
		ArtVorm.bx(v, hx, 13, 2, 1, 3, 1, ArtDecor.METAAL)
		ArtVorm.bx(v, hx, 13, 2, 2, 1, 1, ArtDecor.METAAL_L)
	# the scarf hangs from the second hook
	ArtVorm.bx(v, -3, 6, 2, 3, 8, 1, ROZE)
	ArtVorm.verf(v, -3, -1, 8, 8, 2, 2, ArtDecor.KUSSEN)
	ArtVorm.verf(v, -3, -1, 12, 12, 2, 2, ArtDecor.KUSSEN)
	ArtVorm.bx(v, -3, 4, 2, 1, 2, 1, ROZE)
	ArtVorm.bx(v, -1, 4, 2, 1, 2, 1, ROZE)
	# the leash and its collar hang from the last one
	ArtVorm.bx(v, 6, 11, 2, 1, 3, 1, MINT)
	ArtVorm.bx(v, 4, 6, 2, 5, 1, 1, MINT)
	ArtVorm.bx(v, 4, 10, 2, 5, 1, 1, MINT)
	ArtVorm.bx(v, 4, 7, 2, 1, 3, 1, MINT)
	ArtVorm.bx(v, 8, 7, 2, 1, 3, 1, MINT)
	ArtVorm.verf(v, 6, 6, 6, 6, 2, 2, ArtDecor.GOUD)
	return v

## The frame of both pictures: a solid slab against the wall whose front face
## (z = 2) is the canvas — the motif is painted on it, never added.
static func _lijst(lucht: Color) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -6, 0, 0, 12, 10, 2, ArtDecor.HOUT_D)
	ArtVorm.verf(v, -6, 5, 0, 9, 1, 1, ArtDecor.HOUT)
	ArtVorm.verf(v, -6, 5, 9, 9, 1, 1, ArtDecor.HOUT_L)
	ArtVorm.verf(v, -5, 4, 1, 8, 1, 1, lucht)
	return v

## A pastel paw print — the picture over the bench and in the corridor.
static func schilderij(_p := {}) -> Array:
	var v := _lijst(ArtDecor.KUSSEN)
	ArtVorm.verf(v, -2, 1, 2, 4, 1, 1, ROZE)     # the pad
	ArtVorm.verf(v, -3, -3, 5, 6, 1, 1, ROZE)    # four toes
	ArtVorm.verf(v, -1, -1, 6, 7, 1, 1, ROZE)
	ArtVorm.verf(v, 1, 1, 6, 7, 1, 1, ROZE)
	ArtVorm.verf(v, 3, 3, 5, 6, 1, 1, ROZE)
	return v

## A little tree with the sun over it — the corridor's second picture.
static func schilderij2(_p := {}) -> Array:
	var v := _lijst(HEMEL)
	ArtVorm.verf(v, -4, -2, 6, 8, 1, 1, ZON)     # the sun
	ArtVorm.verf(v, -5, -5, 7, 7, 1, 1, ZON)
	ArtVorm.verf(v, -1, -1, 7, 7, 1, 1, ZON)
	ArtVorm.verf(v, -3, -3, 5, 5, 1, 1, ZON)
	ArtVorm.verf(v, 2, 2, 1, 3, 1, 1, ArtDecor.STAM)   # the trunk
	ArtVorm.verf(v, 0, 4, 4, 6, 1, 1, ArtDecor.BLAD)   # the crown
	ArtVorm.verf(v, 1, 3, 3, 3, 1, 1, ArtDecor.BLAD_B)
	ArtVorm.verf(v, 1, 3, 7, 7, 1, 1, ArtDecor.BLAD_A)
	ArtVorm.verf(v, -5, 4, 1, 1, 1, 1, MINT)           # the grass line
	return v

# ---------------------------------------------------------------- op de vloer

## The waiting bench: it runs along x with its back at the low-z side, so
## `bankjez` (a quarter turn) puts that back against the left wall x = 0.
static func bankje(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -9, 0, -3, 2, 5, 6, ArtDecor.HOUT_D)
	ArtVorm.bx(v, 7, 0, -3, 2, 5, 6, ArtDecor.HOUT_D)
	ArtVorm.bx(v, -10, 5, -4, 20, 2, 8, ArtDecor.HOUT)
	ArtVorm.verf(v, -10, 9, 6, 6, -4, 3, ArtDecor.HOUT_L)
	ArtVorm.bx(v, -9, 7, -2, 8, 1, 5, ArtDecor.STOF)
	ArtVorm.bx(v, 1, 7, -2, 8, 1, 5, ArtDecor.KUSSEN)
	ArtVorm.bx(v, -10, 7, -4, 20, 5, 2, ArtDecor.HOUT)
	ArtVorm.verf(v, -10, 9, 11, 11, -4, -3, ArtDecor.HOUT_L)
	ArtVorm.verf(v, -10, 9, 8, 8, -3, -3, ArtDecor.HOUT_D)
	return v

## A small suitcase beside the bench: a soft pink case with a seam, two gold
## clasps and a handle on top.
static func koffer(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -4, 0, -2, 8, 6, 4, ROZE)
	ArtVorm.verf(v, -4, 3, 3, 3, -2, 1, ArtDecor.HOUT_D)
	ArtVorm.verf(v, -4, -4, 0, 5, -2, 1, ArtDecor.HOUT_D)
	ArtVorm.verf(v, 3, 3, 0, 5, -2, 1, ArtDecor.HOUT_D)
	ArtVorm.verf(v, -2, -2, 4, 4, 1, 1, ArtDecor.GOUD)
	ArtVorm.verf(v, 1, 1, 4, 4, 1, 1, ArtDecor.GOUD)
	ArtVorm.bx(v, -2, 6, -1, 1, 2, 2, ArtDecor.HOUT_D)
	ArtVorm.bx(v, 1, 6, -1, 1, 2, 2, ArtDecor.HOUT_D)
	ArtVorm.bx(v, -2, 8, -1, 4, 1, 2, ArtDecor.HOUT_D)
	return v

## Three flowers in a little vase, for the desk top.
static func bloemen(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.ell(v, 0, 2.4, 0, 2.4, 2.8, 2.4, HEMEL, {"e": 2.6, "ymin": 0})
	ArtVorm.bx(v, -1, 4, -1, 3, 2, 3, ArtDecor.METAAL_L)
	ArtVorm.bx(v, 0, 6, 0, 1, 3, 1, ArtDecor.BLAD)
	ArtVorm.bx(v, -1, 6, 1, 2, 2, 1, ArtDecor.BLAD)
	ArtVorm.bx(v, 1, 6, -1, 2, 2, 1, ArtDecor.BLAD)
	ArtVorm.ell(v, 0, 10, 0, 1.6, 1.6, 1.6, ROZE, {"e": 2.4})
	ArtVorm.ell(v, -2, 8.5, 1, 1.5, 1.5, 1.5, ZON, {"e": 2.4})
	ArtVorm.ell(v, 2, 8.5, -1, 1.5, 1.5, 1.5, LILA, {"e": 2.4})
	return v

# --------------------------------------------------------------------- register

## `naam -> Callable(params) -> Array` of voxels {x, y, z, k}.
static func tabel() -> Dictionary:
	return {
		"klok": Callable(ArtDecorHotel, "klok"),
		"bloemen": Callable(ArtDecorHotel, "bloemen"),
		"bankje": Callable(ArtDecorHotel, "bankje"),
		"bankjez": func(_p := {}): return ArtVorm.draai(bankje()),
		"koffer": Callable(ArtDecorHotel, "koffer"),
		"kapstok": Callable(ArtDecorHotel, "kapstok"),
		"schilderij": Callable(ArtDecorHotel, "schilderij"),
		"schilderij2": Callable(ArtDecorHotel, "schilderij2"),
	}
