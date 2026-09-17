class_name ArtDecorSlaapkamer
extends RefCounted
## Decor models for the two bedrooms.  Same primitives, same palette and the same
## bake path as `ArtDecor`, which merges this table into its own (see
## `ArtDecor.tabel()` and `ArtDecor.alle_namen()`).  Every model is anchored at
## (0, 0, 0) on the floor, y upward, and is registered as a protected world model.
##
## `raam`, `schilderij` and `boekenplank` hang on the BACK wall (z = 0): they are
## built lying against it (z from 0 outward towards the child) and placed with
## `"ver": true` plus the height they hang at, e.g.
## `{"n": "raam", "x": 40, "z": 1, "y": 26, "ver": true}`.  The `*z` twins are the
## same model mirrored over the diagonal (`ArtVorm.draai`) for the LEFT wall x = 0.

const HOUT := ArtDecor.HOUT
const HOUT_D := ArtDecor.HOUT_D
const HOUT_L := ArtDecor.HOUT_L
const KUSSEN := ArtDecor.KUSSEN
const DEKEN := ArtDecor.DEKEN
const STOF := ArtDecor.STOF
const GOUD := ArtDecor.GOUD
const METAAL := ArtDecor.METAAL
const PAPIER := ArtDecor.PAPIER

## A few extra soft colours, in the same pastel family as `ArtDecor`.
const MINT := Color("#BFE3D2")
const MINT_D := Color("#A6D3BE")
const LILA := Color("#D9C6EC")
const LILA_D := Color("#C4ACDD")
const ZONNE := Color("#FFE49B")
const ZONNE_D := Color("#F2D083")
const LUCHT := Color("#C4E2F6")     ## a lighter sky, high in the window
const KAP := Color("#FFDCA8")       ## lampshade
const KAP_L := Color("#FFF0C6")     ## ... and the warm rim under it
const ROOS := Color("#F19FB5")      ## the heart in the picture

## Every model name this file provides, in a fixed order.
const NAMEN: Array[String] = ["nachtkastje", "raam", "raamz", "schilderij",
	"schilderijz", "blokken", "speelgoedkist", "staande_lamp", "boekenplank"]

# ------------------------------------------------------------------ op de vloer

## Bedside table with its own little lamp — one model, so one decor entry and
## one depth sort.  Footprint 9 x 9, 18 tall.
static func nachtkastje(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -3, 0, -3, 7, 8, 7, HOUT)
	ArtVorm.bx(v, -4, 8, -4, 9, 1, 9, HOUT_L)
	ArtVorm.verf(v, -2, 2, 1, 3, 3, 3, HOUT_L)
	ArtVorm.verf(v, -2, 2, 4, 6, 3, 3, HOUT_L)
	ArtVorm.verf(v, -1, 1, 2, 2, 3, 3, GOUD)
	ArtVorm.verf(v, -1, 1, 5, 5, 3, 3, GOUD)
	ArtVorm.bx(v, -2, 9, -2, 5, 1, 5, METAAL)
	ArtVorm.bx(v, -1, 10, -1, 3, 3, 3, METAAL)
	ArtVorm.ell(v, 0, 15, 0, 3.4, 2.8, 3.4, KAP, {"e": 2.8, "ymin": 13})
	ArtVorm.verf(v, -4, 4, 13, 13, -4, 4, KAP_L)
	return v

## Three toy blocks, each one a little out of line.  Footprint 8 x 8, 12 tall.
static func blokken(_p := {}) -> Array:
	var v: Array = []
	var kl := [MINT, LILA, ZONNE]
	var rand := [MINT_D, LILA_D, ZONNE_D]
	var dx := [0, 1, -1]
	var dz := [0, -1, 1]
	for i in 3:
		var x0: int = dx[i] - 3
		var z0: int = dz[i] - 3
		var y0: int = i * 4
		ArtVorm.bx(v, x0, y0, z0, 6, 4, 6, kl[i])
		ArtVorm.verf(v, x0, x0 + 5, y0, y0, z0, z0 + 5, rand[i])
		ArtVorm.verf(v, x0 + 1, x0 + 1, y0 + 1, y0 + 1, z0 + 5, z0 + 5, PAPIER)
		ArtVorm.verf(v, x0 + 4, x0 + 4, y0 + 2, y0 + 2, z0 + 5, z0 + 5, PAPIER)
		ArtVorm.verf(v, x0 + 5, x0 + 5, y0 + 2, y0 + 2, z0 + 1, z0 + 1, PAPIER)
	return v

## Toy chest with the lid standing open, a ball and a block peeking out of it.
## Footprint 13 x 10, 16 tall.
static func speelgoedkist(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -6, 0, -4, 13, 8, 9, MINT)
	ArtVorm.verf(v, -6, 6, 0, 0, -4, 4, MINT_D)
	ArtVorm.verf(v, -6, 6, 3, 4, 4, 4, MINT_D)
	ArtVorm.verf(v, 6, 6, 3, 4, -4, 4, MINT_D)
	ArtVorm.verf(v, -5, 5, 7, 7, -3, 3, HOUT_D)      # the opening
	ArtVorm.bx(v, -6, 8, -4, 13, 2, 2, MINT_D)       # the hinge
	ArtVorm.bx(v, -6, 10, -5, 13, 6, 2, MINT)        # the lid, standing open
	ArtVorm.verf(v, -6, 6, 15, 15, -5, -4, MINT_D)
	ArtVorm.ell(v, -2, 10.4, 0, 2.6, 2.6, 2.6, STOF, {"e": 2.0, "ymin": 8})
	ArtVorm.verf(v, -3, -1, 10, 12, 2, 2, KUSSEN)
	ArtVorm.bx(v, 2, 8, -1, 5, 5, 5, LILA)
	ArtVorm.verf(v, 3, 5, 10, 11, 3, 3, PAPIER)
	return v

## Floor lamp with a pastel shade.  Footprint 9 x 9, 22 tall.
static func staande_lamp(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -3, 0, -3, 7, 1, 7, HOUT_D)
	ArtVorm.bx(v, -2, 1, -2, 5, 1, 5, HOUT)
	ArtVorm.bx(v, -1, 2, -1, 3, 12, 3, METAAL)
	ArtVorm.ell(v, 0, 17.5, 0, 4.2, 3.8, 4.2, KAP, {"e": 3.0, "ymin": 14})
	ArtVorm.verf(v, -5, 5, 14, 14, -5, 5, KAP_L)
	return v

# ------------------------------------------------------------------ aan de wand

## Window for the back wall z = 0: a HOUT_L frame of 23 x 18 with sky panes, a
## white cross bar, a sill and a curtain on both sides.  29 wide, 20 tall.
static func raam(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -11, 1, 0, 23, 18, 2, HOUT_L)
	ArtVorm.bx(v, -9, 3, 1, 19, 14, 2, DEKEN)
	ArtVorm.verf(v, -9, 9, 11, 16, 2, 2, LUCHT)
	ArtVorm.verf(v, -1, 1, 3, 16, 2, 2, KUSSEN)
	ArtVorm.verf(v, -9, 9, 9, 10, 2, 2, KUSSEN)
	ArtVorm.bx(v, -12, 0, 0, 25, 2, 4, HOUT)          # the sill
	ArtVorm.bx(v, -13, 3, 2, 3, 16, 2, STOF)          # curtains
	ArtVorm.bx(v, 11, 3, 2, 3, 16, 2, STOF)
	ArtVorm.bx(v, -14, 19, 2, 29, 2, 2, HOUT_D)       # the rail
	return v

## Framed picture for the back wall z = 0: a pastel heart on paper.  13 x 12.
static func schilderij(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -6, 0, 0, 13, 12, 2, HOUT)
	ArtVorm.bx(v, -5, 1, 1, 11, 10, 2, PAPIER)
	var hart := [[9, -4, -2], [9, 2, 4], [8, -5, -1], [8, 1, 5], [7, -5, 5],
		[6, -4, 4], [5, -3, 3], [4, -2, 2], [3, -1, 1]]
	for r in hart:
		ArtVorm.verf(v, r[1], r[2], r[0], r[0], 2, 2, ROOS)
	ArtVorm.verf(v, -6, 6, 11, 11, 0, 1, HOUT_L)
	return v

## Wall shelf for the back wall z = 0 with five pastel books.  23 wide, 13 tall.
static func boekenplank(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -11, 0, 0, 23, 2, 6, HOUT)
	ArtVorm.verf(v, -11, 11, 1, 1, 0, 5, HOUT_L)
	ArtVorm.verf(v, -11, 11, 0, 0, 0, 5, HOUT_D)
	var kl := [MINT, STOF, ZONNE, LILA, DEKEN]
	var hg := [10, 8, 11, 9, 10]
	var br := [3, 2, 3, 2, 4]
	var x := -9
	for i in 5:
		ArtVorm.bx(v, x, 2, 1, br[i], hg[i], 4, kl[i])
		ArtVorm.verf(v, x, x + br[i] - 1, hg[i], hg[i] + 1, 4, 4, PAPIER)
		x += br[i] + 1
	return v

# --------------------------------------------------------------------- register

## `naam -> Callable(params) -> Array` of voxels {x, y, z, k}.
static func tabel() -> Dictionary:
	return {
		"nachtkastje": Callable(ArtDecorSlaapkamer, "nachtkastje"),
		"raam": Callable(ArtDecorSlaapkamer, "raam"),
		"raamz": func(_p := {}): return ArtVorm.draai(raam()),
		"schilderij": Callable(ArtDecorSlaapkamer, "schilderij"),
		"schilderijz": func(_p := {}): return ArtVorm.draai(schilderij()),
		"blokken": Callable(ArtDecorSlaapkamer, "blokken"),
		"speelgoedkist": Callable(ArtDecorSlaapkamer, "speelgoedkist"),
		"staande_lamp": Callable(ArtDecorSlaapkamer, "staande_lamp"),
		"boekenplank": Callable(ArtDecorSlaapkamer, "boekenplank"),
	}
