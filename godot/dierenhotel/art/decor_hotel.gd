class_name ArtDecorHotel
extends RefCounted
## Decor models for the reception and the corridor.  Same primitives, same palette and the same
## bake path as `ArtDecor`, which merges this table into its own (see
## `ArtDecor.tabel()` and `ArtDecor.alle_namen()`).  Every model is anchored at
## (0, 0, 0) on the floor, y upward, and is registered as a protected world model.
##
## Wall pieces (`klok`, `kapstok`, `poster_poot`, `poster_boom`) lie flat against
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

## The front door (owner, 2026-09-23: the guests "komen momenteel vanuit de
## gang binnen ipv ingang"): white like every door that leads outside, with a
## mint leaf — the hotel's own colour, its collar and its hat — and a big pane
## with the sky in it.  No other door in the hotel is closed, mint and glass, so
## it never reads as one more door to a room.
const KOZIJN := Color("#FBF7EE")      ## the white frame (scenes/vloer.gd KOZIJN_WIT)
const DEUR := Color("#86C9AE")        ## the leaf
const DEUR_D := Color("#6DB397")
const DEUR_L := Color("#A8DCC6")
const RUIT := Color("#D6EEF7")        ## the pane: the sky outside
const RUIT_L := Color("#F4FBFD")      ## a glint on the glass
const HAG := Color("#BFE0B0")         ## the hedge outside, low in the pane
const BOVENLICHT := Color("#FFF1C4")  ## the fanlight over the door: sunshine
const BUITEN := Color("#CFE9F7")      ## the sky through the open door
const STOEP := Color("#E8DAC4")       ## the pavement outside (the garden's STOEP)
const STOEP_D := Color("#DDCDB5")
const DREMPEL := Color("#C9A27E")     ## the threshold (scenes/vloer.gd DREMPEL)
const MAT := Color("#EF9FAE")         ## the welcome mat
const MAT_D := Color("#D98596")

## Every model name this file provides, in a fixed order.
const NAMEN: Array[String] = ["klok", "bloemen", "bankje", "bankjez", "koffer",
	"kapstok", "poster_poot", "poster_boom", "voordeur", "welkomsmat", "voordeuromlijst"]

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
static func poster_poot(_p := {}) -> Array:
	var v := _lijst(ArtDecor.KUSSEN)
	ArtVorm.verf(v, -2, 1, 2, 4, 1, 1, ROZE)     # the pad
	ArtVorm.verf(v, -3, -3, 5, 6, 1, 1, ROZE)    # four toes
	ArtVorm.verf(v, -1, -1, 6, 7, 1, 1, ROZE)
	ArtVorm.verf(v, 1, 1, 6, 7, 1, 1, ROZE)
	ArtVorm.verf(v, 3, 3, 5, 6, 1, 1, ROZE)
	return v

## A little tree with the sun over it — the corridor's second picture.
static func poster_boom(_p := {}) -> Array:
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

## The hotel's front door, for the back wall z = 0 (world.md §1.2, the
## receptie's `ingang`): 14 wide and 28 tall in a white frame three deep,
## round an opening of 12 x 26 — the size of every door in a wall
## (`Rooms.deur_hoog`).  Over the leaf a fanlight with a white sunburst.
##   closed (`params.open` 0): a mint leaf with a big pane — the sky, a hedge
##       low in it, a glint and a pink paw on the glass — a lower panel and a
##       brass knob;
##   open (1): the leaf has swung out of sight and the opening shows outside
##       itself: the sky with a sun and a cloud, the hedge, the pavement, and
##       the threshold at its foot.
static func voordeur(p := {}) -> Array:
	var v: Array = []
	var open := int(p.get("open", 0)) > 0
	# the frame: two posts and a lintel, three deep
	ArtVorm.bx(v, -7, 0, 0, 1, 26, 3, KOZIJN)
	ArtVorm.bx(v, 6, 0, 0, 1, 26, 3, KOZIJN)
	ArtVorm.bx(v, -7, 26, 0, 14, 2, 3, KOZIJN)
	# the fanlight (y 22..25) with a sunburst, and the transom under it
	ArtVorm.bx(v, -6, 22, 0, 12, 4, 1, BOVENLICHT)
	for s in [[-1, 22], [0, 22], [-1, 23], [0, 23], [-1, 24], [0, 24], [-1, 25], [0, 25],
			[-2, 23], [-3, 24], [-4, 25], [1, 23], [2, 24], [3, 25], [-6, 25], [5, 25]]:
		ArtVorm.verf(v, s[0], s[0], s[1], s[1], 0, 0, KOZIJN)
	ArtVorm.bx(v, -6, 21, 0, 12, 1, 2, KOZIJN)
	if open:
		# outside, in the plane of the wall, two behind the face of the frame
		ArtVorm.bx(v, -6, 0, 0, 12, 21, 1, BUITEN)
		ArtVorm.verf(v, 2, 3, 15, 16, 0, 0, ZON)
		ArtVorm.verf(v, -5, -2, 17, 17, 0, 0, ArtDecor.KUSSEN)
		ArtVorm.verf(v, -4, -3, 18, 18, 0, 0, ArtDecor.KUSSEN)
		for x in range(-6, 6):
			ArtVorm.verf(v, x, x, 3, 8 if x % 2 == 0 else 9, 0, 0,
				ArtDecor.BLAD_A if x % 3 == 0 else HAG)
			ArtVorm.verf(v, x, x, 0, 2, 0, 0, STOEP if (x & 2) == 0 else STOEP_D)
		ArtVorm.bx(v, -6, 0, 1, 12, 1, 2, DREMPEL)
		return v
	# the leaf, one behind the face of the frame
	ArtVorm.bx(v, -6, 0, 0, 12, 21, 2, DEUR)
	ArtVorm.verf(v, -6, 5, 20, 20, 1, 1, DEUR_L)
	ArtVorm.verf(v, -6, -6, 0, 20, 1, 1, DEUR_L)
	# the pane: the sky, a hedge low in it, a glint and a paw on the glass
	ArtVorm.verf(v, -4, 3, 8, 18, 1, 1, RUIT)
	ArtVorm.verf(v, -4, 3, 8, 9, 1, 1, HAG)
	ArtVorm.verf(v, -3, -3, 13, 16, 1, 1, RUIT_L)
	ArtVorm.verf(v, -2, -2, 15, 17, 1, 1, RUIT_L)
	ArtVorm.verf(v, 0, 1, 10, 11, 1, 1, ROZE)
	for teen in [[-1, 12], [0, 13], [1, 13], [2, 12]]:
		ArtVorm.verf(v, teen[0], teen[0], teen[1], teen[1], 1, 1, ROZE)
	# the lower panel and the knob
	ArtVorm.verf(v, -4, 3, 2, 5, 1, 1, DEUR_D)
	ArtVorm.verf(v, -4, 3, 5, 5, 1, 1, DEUR_L)
	ArtVorm.bx(v, 3, 10, 2, 2, 2, 1, ArtDecor.GOUD)
	return v

## The receptie's front door as it stands in the FRONT edge of the lobby, at the
## pink rug (owner, 2026-09-24: "alleen de uitlijn en laat hem open zodat je
## erdoorheen kan kijken en het tapijt zien ... En maak hem wat groter dan de
## andere deuren"): only its outline — two white posts, a lintel and the
## threshold on the floor — and open, so you look through it at the rug and the
## lobby as through every door into the next room.  26 wide and 38 tall inside
## (a door in a wall is 12 x 26; the owner asked twice for it bigger, 2026-09-24:
## "Mooi maak de deur nog iets groter").  Along x, one deep, for the edge z = d.
static func voordeuromlijst(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -14, 0, 0, 1, 38, 1, KOZIJN)
	ArtVorm.bx(v, 13, 0, 0, 1, 38, 1, KOZIJN)
	ArtVorm.bx(v, -14, 38, 0, 28, 2, 1, KOZIJN)
	ArtVorm.bx(v, -13, 0, 0, 26, 1, 1, DREMPEL)
	return v

# ---------------------------------------------------------------- op de vloer

## The welcome mat before the front door: pink with a darker border and a white
## heart, 12 x 7 and one voxel thin — the kitchen's coir mat has a paw, this one
## says welcome.  Along x, for the wall z = 0.
static func welkomsmat(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -6, 0, -3, 12, 1, 7, MAT)
	ArtVorm.verf(v, -6, 5, 0, 0, -3, -3, MAT_D)
	ArtVorm.verf(v, -6, 5, 0, 0, 3, 3, MAT_D)
	ArtVorm.verf(v, -6, -6, 0, 0, -3, 3, MAT_D)
	ArtVorm.verf(v, 5, 5, 0, 0, -3, 3, MAT_D)
	# the heart, its two bumps toward the door
	for c in [[-2, -2], [-1, -2], [1, -2], [2, -2], [-2, -1], [-1, -1], [0, -1], [1, -1],
			[2, -1], [-1, 0], [0, 0], [1, 0], [0, 1]]:
		ArtVorm.verf(v, c[0], c[0], 0, 0, c[1], c[1], ArtDecor.KUSSEN)
	return v

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
		"poster_poot": Callable(ArtDecorHotel, "poster_poot"),
		"poster_boom": Callable(ArtDecorHotel, "poster_boom"),
		"voordeur": Callable(ArtDecorHotel, "voordeur"),
		"welkomsmat": Callable(ArtDecorHotel, "welkomsmat"),
		"voordeuromlijst": Callable(ArtDecorHotel, "voordeuromlijst"),
	}
