extends RefCounted
## The two voxel models the meubelboek adds to the receptie while you pay
## (architecture.md §6.1: a game's own models live in its own directory and are
## registered as `<spel>_<naam>`, §13 Q-X1-11).
##
## They are here for a reason a screenshot makes obvious: `mb_bank` and
## `mb_buidel` were hotspots hanging over bare floor, and a drop target is the
## UNION of a button and its object (architecture.md §10).  Without an object
## the counter was a 48 x 48 square to aim a coin at; with one it is the whole
## counter.  Both are low and small, so the band grid keeps its room.
##
## Static, so the registry never holds a Callable bound to a node that the next
## `Games.stop()` frees.

const HOUT := ArtDecor.HOUT
const HOUT_D := ArtDecor.HOUT_D
const HOUT_L := ArtDecor.HOUT_L
const LEER := Color("#C08A5E")
const LEER_D := Color("#A0714B")
const KOORD := Color("#8B6F5C")
const GOUD := ArtDecor.GOUD

## The counter you lay the coins on: one low block with a lighter top.
static func toonbank(_p: Dictionary = {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -11, 0, -6, 23, 5, 13, HOUT)
	ArtVorm.bx(v, -12, 5, -7, 25, 2, 15, HOUT_L)
	ArtVorm.verf(v, -11, 11, 2, 2, -6, 6, HOUT_D)
	return v

## Your purse: a small leather pouch with a cord and one coin on top, so the
## drag source stands on something instead of on the floorboards.
static func buidel(_p: Dictionary = {}) -> Array:
	var v: Array = []
	ArtVorm.ell(v, 0, 4.2, 0, 5.0, 4.4, 4.2, LEER, {"e": 2.4, "ymin": 0})
	ArtVorm.verf(v, -5, 5, 0, 1, -5, 5, LEER_D)
	ArtVorm.bx(v, -2, 8, -1, 5, 2, 3, KOORD)
	ArtVorm.ell(v, 3, 10.5, 1, 2.2, 0.9, 2.2, GOUD, {"e": 2.6})
	return v
