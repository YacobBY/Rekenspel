class_name WasSoorten
extends RefCounted
## The four kinds of washing, and the two voxel models of the laundry
## (games-b.md §4.1, §4.5).
##
## One word per kind, everywhere the same — on the card, on the choice button
## and on the plate above the crate: "doeken", never "handdoeken".  A 91 unit
## plate does not fit between crates that stand 63 units apart, and two names
## for the same pile does not read as the same pile to a six year old.  The
## longest sentence stays `Hoeveel meer knuffels dan doeken?` (33 characters).
##
## The order is also the order of difficulty: group 3 sorts the first two or
## three, group 4 three, group 5 all four.

## `naam` is the plural, `ev` the singular (the short plate on a tight frame).
const LIJST := [
	{"id": "sok", "ico": "🧦", "naam": "sokken", "ev": "sok",
		"kl": "#E86A9A", "kl2": "#C9527E"},
	{"id": "sjaal", "ico": "🧣", "naam": "sjaals", "ev": "sjaal",
		"kl": "#5FA8D3", "kl2": "#3E85AE"},
	{"id": "doek", "ico": "🧺", "naam": "doeken", "ev": "doek",
		"kl": "#F2C14E", "kl2": "#D09F2E"},
	{"id": "knuf", "ico": "🧸", "naam": "knuffels", "ev": "knuffel",
		"kl": "#8DBF6B", "kl2": "#6C9E4C"},
]

## The crates are made of the same wood as the furniture in `rooms.gd`.
const HOUT := "#D0A87A"
const HOUT_D := "#B98F62"
const HOUT_L := "#E2C094"

## The bench under a crate, in voxels.  Why a bench at all: the question card
## hangs IN FRONT of the crates, so on a low frame it slides up against them.
## With the blocks standing well above the floor the card covers at most the
## bench and the whole bar chart stays countable (games-b.md §4.5).
const VOET := 18
const VOET_MIN := 0
const VOET_MAX := 18
## Every block is `stap - 1` voxels of colour plus one voxel of dark seam, so a
## child can really count the blocks on screen.
const STAP := 3
const STAP_MIN := 2
## The wall of the wasserij is 52 voxels; a stack never goes through it.
const WAND := 50

static func soort(i: int) -> Dictionary:
	return LIJST[i] if i >= 0 and i < LIJST.size() else LIJST[0]

static func kleur(naam: String) -> Color:
	return Color(naam)

# ---------------------------------------------------------------- de modellen

## `was_krat` (params `soort`, `n`, `voet`, `stap`) — a crate on a low bench
## with `n` blocks stacked in it, in the colour of its kind.
static func krat(params: Dictionary) -> Array:
	var v: Array = []
	var so := soort(int(params.get("soort", 0)))
	var y0: int = clampi(JsGetal.rond(float(params.get("voet", VOET))), VOET_MIN, VOET_MAX)
	var stap: int = clampi(JsGetal.rond(float(params.get("stap", STAP))), STAP_MIN, STAP)
	var n: int = clampi(JsGetal.rond(float(params.get("n", 0))), 0,
		int(floor(float(WAND - y0 - 2) / float(stap))))
	var hout := kleur(HOUT)
	var hout_d := kleur(HOUT_D)
	var hout_l := kleur(HOUT_L)
	if y0 >= 6:
		ArtVorm.bx(v, -6, y0 - 4, -5, 13, 4, 11, hout_d)     # the bench top
		ArtVorm.bx(v, -5, 0, -4, 3, y0 - 4, 3, hout_d)       # leg back-left
		ArtVorm.bx(v, 3, 0, -4, 3, y0 - 4, 3, hout_d)        # leg back-right
		ArtVorm.bx(v, -5, 0, 2, 3, y0 - 4, 3, hout)          # leg front-left
		ArtVorm.bx(v, 3, 0, 2, 3, y0 - 4, 3, hout)           # leg front-right
	elif y0 > 0:
		ArtVorm.bx(v, -6, 0, -5, 13, y0, 11, hout_d)         # too low for legs
	ArtVorm.bx(v, -6, y0, -5, 13, 2, 11, hout)               # the crate floor
	ArtVorm.bx(v, -6, y0 + 2, -5, 13, 3, 1, hout_d)          # rim back  (z-)
	ArtVorm.bx(v, -6, y0 + 2, 5, 13, 3, 1, hout_l)           # rim front (z+)
	ArtVorm.bx(v, -6, y0 + 2, -4, 1, 3, 9, hout_d)           # rim left  (x-)
	ArtVorm.bx(v, 6, y0 + 2, -4, 1, 3, 9, hout_l)            # rim right (x+)
	var kl := kleur(str(so["kl"]))
	var kl2 := kleur(str(so["kl2"]))
	for i in n:
		ArtVorm.bx(v, -4, y0 + 2 + i * stap, -3, 9, stap - 1, 7, kl)
		ArtVorm.bx(v, -4, y0 + 1 + stap + i * stap, -3, 9, 1, 7, kl2)
	return v

## The eight tufts of the pile, drawn once with `prng(90210)` at load time, so
## the same params always give the same list (the bake caches on params).
static var _pluk: Array = []

static func pluk() -> Array:
	if _pluk.is_empty():
		var r := Sommen.Prng.new(90210)
		for _i in 8:
			_pluk.append([JsGetal.rond(r.volgende() * 16.0 - 8.0),
				JsGetal.rond(r.volgende() * 3.0),
				JsGetal.rond(r.volgende() * 16.0 - 8.0),
				r.volgende()])
	return _pluk

## `was_berg` (param `n`) — the pile of washing.  The less there is left, the
## fewer tufts; at zero an empty list, so there is no picture at all.
static func berg(params: Dictionary) -> Array:
	var v: Array = []
	var n: int = maxi(0, JsGetal.rond(float(params.get("n", 0))))
	if n == 0:
		return v
	var lijst := pluk()
	var m: int = clampi(JsGetal.plafond(float(n) / 2.0), 1, lijst.size())
	for i in m:
		var q: Array = lijst[i]
		var so := soort(i % LIJST.size())
		ArtVorm.ell(v, float(q[0]), 2.0 + float(q[1]), float(q[2]), 4.2, 2.8, 4.2,
			kleur(str(so["kl"] if float(q[3]) < 0.5 else so["kl2"])),
			{"e": 2.4, "ymin": 0})
	return v
