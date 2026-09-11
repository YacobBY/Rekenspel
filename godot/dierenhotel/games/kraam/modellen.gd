extends RefCounted
## The six voxel models of the souvenir stall (games-b.md §5.4), ported one to
## one from `demos/dierenhotel/games/kraam.js` §1.
##
## They are the game's OWN models and are registered with the game id in front
## of their name (`Art.registreer_model("kraam_bank", …)`, architecture.md §13
## Q-X1-11), so `bal` — a real garden ball — and `kraam_bal` — a pink one on a
## market table — can live side by side.
##
## Anchor (0,0,0) is on the floor, in the middle under the piece; `y` is up.
## Everything stays inside 21 voxels in x and 11 in z, so a piece whose anchor
## sits in the middle of the 22 × 32 stall zone falls entirely inside it.

const HOUT := Color("#D0A87A")
const HOUT_D := Color("#B98F62")
const HOUT_L := Color("#E2C094")
const DOEK_A := Color("#F5A8BE")     ## the striped awning
const DOEK_B := Color("#FFFDF6")
const MINT := Color("#6BC5A4")
const ORANJE := Color("#F6A957")
const ROZE := Color("#F5A8BE")
const WIT := Color("#FFFDF6")
const LEER := Color("#B4744A")
const LEER_D := Color("#8E5B3A")

## Name -> builder, for `Art.registreer_model`.  The keys are already qualified.
static func tabel() -> Dictionary:
	return {
		"kraam_kraam": kraam,
		"kraam_bank": bank,
		"kraam_hoedje": hoedje,
		"kraam_sjaaltje": sjaaltje,
		"kraam_bal": bal,
		"kraam_tas": tas,
	}

## The stall: a back panel with two posts and a striped awning.  It stands
## along the BACK edge of the zone (small x + z), so behind the counter: that
## way it covers neither the counter nor the guest.
static func kraam(_params: Dictionary = {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -10, 0, 0, 21, 24, 2, HOUT)          # back panel
	ArtVorm.verf(v, -10, 10, 10, 11, 0, 1, HOUT_D)     # one plank line
	ArtVorm.bx(v, -10, 0, -2, 2, 27, 2, HOUT_D)        # left post
	ArtVorm.bx(v, 9, 0, -2, 2, 27, 2, HOUT_D)          # right post
	for i in 6:                                        # awning, sloping forward
		ArtVorm.bx(v, -10, 27 - int(floor(i / 2.0)), 1 - i, 21, 2, 1,
			DOEK_A if i % 2 == 1 else DOEK_B)
	return v

## The counter: a SQUARE market table.  Square, because the goods have to stand
## side by side ON SCREEN, and in isometry that is the line x + z = constant —
## which runs right across a square top (games-b.md §5.4).
static func bank(_params: Dictionary = {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -10, 0, -7, 21, 11, 15, HOUT)        # the block
	ArtVorm.verf(v, -10, 10, 4, 5, -7, 7, HOUT_D)      # a groove
	ArtVorm.bx(v, -11, 11, -8, 23, 2, 17, HOUT_L)      # the top
	return v

## The goods are deliberately CHUNKY: on the garden scale one voxel is only
## 2 css px, so a six-voxel hat disappears next to its 23 px price tag.
static func hoedje(_params: Dictionary = {}) -> Array:
	var v: Array = []
	ArtVorm.ell(v, 0, 1, 0, 4.6, 1.8, 4.6, MINT, {"ymin": 0})   # wide brim
	ArtVorm.ell(v, 0, 6, 0, 3, 4.6, 3, MINT, {"ymin": 2})       # tall crown
	ArtVorm.verf(v, -4, 4, 2, 2, -4, 4, WIT)                    # ribbon
	return v

static func sjaaltje(_params: Dictionary = {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -4, 0, -3, 9, 4, 7, ORANJE)          # folded pile
	ArtVorm.bx(v, -3, 4, -2, 7, 4, 5, ORANJE)
	ArtVorm.bx(v, -2, 8, -1, 5, 2, 3, ORANJE)
	ArtVorm.verf(v, -4, -4, 0, 9, -3, 3, WIT)          # fringe on the side
	return v

static func bal(_params: Dictionary = {}) -> Array:
	var v: Array = []
	ArtVorm.ell(v, 0, 4.4, 0, 4.4, 4.4, 4.4, ROZE, {"e": 2.0})
	ArtVorm.verf(v, -1, 1, 0, 9, -5, 5, WIT)           # white equator
	return v

static func tas(_params: Dictionary = {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -4, 0, -3, 9, 8, 6, LEER)
	ArtVorm.bx(v, -4, 8, -3, 9, 2, 6, LEER_D)          # the flap
	ArtVorm.bx(v, -1, 10, -1, 3, 3, 1, LEER_D)         # the handle
	return v
