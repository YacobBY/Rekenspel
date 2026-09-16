class_name ZwembadModellen
extends RefCounted
## The two voxel models of the pool game (games-b.md §1.9), and nothing else.
##
## Both are blue/pink on purpose: the stone rim of the pool is almost white, so
## a marker in that family would disappear into it.
##
## The names are namespaced with the game id (`zwembad_streep`, `zwembad_vlag`)
## because `Art.registreer_model` demands `<spel>_<naam>` and refuses a bare
## world name (architecture.md §13, Q-X1-11).  games-b.md §1.9 writes them as
## `zb_streep` / `zb_vlag`, which are the HTML's global names; the shapes and
## the colours below are that spec verbatim.

const STREEP_GROOT := "#4C7FA6"
const STREEP_KLEIN := "#8FB4CC"
const STREEP_KNOP := "#FFFDF3"
const VLAG_VOET := "#EDEFF6"
const VLAG_MAST := "#B98F62"
const VLAG_DOEK := "#F5A8BE"

## A metre marker on the rim.  `groot` = a whole label step (a taller post),
## `bleek` = the ghost marker of the third help step: the same shape, washed
## out, so it reads as "this is where you are going", not as a real marker.
## `gehaald` = the swimmer has passed this metre: the white knob becomes the
## flag pink, so the number line shows how far he is and how much is left.
## `licht` = the first rung of the help ladder lights this marker ("tel de
## strepen tot de vlag"): post and stripe glow towards the knob white and the
## knob itself stays as it is.
static func streep(params: Dictionary) -> Array:
	var groot := bool(params.get("groot", false))
	var bleek := bool(params.get("bleek", false))
	var gehaald := bool(params.get("gehaald", false))
	var licht := bool(params.get("licht", false))
	var kl := Color(STREEP_GROOT if groot else STREEP_KLEIN)
	var knop := Color(STREEP_KNOP)
	if bleek:
		kl = kl.lerp(Color(STREEP_KNOP), 0.55)
		knop = knop.lerp(Color(STREEP_KLEIN), 0.25)
	elif gehaald:
		knop = Color(VLAG_DOEK)
	if licht and not bleek:
		kl = kl.lerp(Color(STREEP_KNOP), 0.45)
	var h: int = 7 if groot else 4
	var v: Array = []
	ArtVorm.bx(v, -1, 0, -2, 2, 1, 4, kl)          # the stripe over the rim
	ArtVorm.bx(v, -1, 1, -1, 2, h, 2, kl)          # the post
	ArtVorm.bx(v, -2, h + 1, -2, 4, 1, 4, knop)    # the white knob on top
	return v

## The flag at L metres: a flat foot, a mast and a triangular pennant.
static func vlag(_params: Dictionary) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -3, 0, -3, 7, 1, 7, Color(VLAG_VOET))
	ArtVorm.bx(v, -1, 1, -1, 2, 21, 2, Color(VLAG_MAST))
	for i in 7:
		ArtVorm.bx(v, 1, 21 - i, -1, 7 - i, 1, 2, Color(VLAG_DOEK))
	return v
