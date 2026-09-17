class_name ArtDecor
extends RefCounted
## The 33 built-in decor models of `demos/dierenhotel/rooms.js`
## (art-sound-rules.md §8), built from the same primitives, the same light and
## the same bake path as the guests.  Every model is anchored at (0,0,0) on the
## floor, y upward.
##
## `Art` registers all of them as PROTECTED world models (architecture.md §13,
## Q-X1-11); a minigame that wants its own clock calls it `wekker_klok`.

const HOUT := Color("#D0A87A")
const HOUT_D := Color("#B98F62")
const HOUT_L := Color("#E2C094")
const STAM := Color("#B08A6A")
const BLAD := Color("#A6CE8E")
const BLAD_A := Color("#A9D08F")
const BLAD_B := Color("#B2D797")
const DAK := Color("#E79C7C")
const MUUR := Color("#F6E2C8")
const DEURKL := Color("#8B6F5C")
const WATER := Color("#A9D8E6")
const KUSSEN := Color("#FFF7EC")
const DEKEN := Color("#A9D3F0")
const DEKEN_D := Color("#84B4D8")
const STOF := Color("#F5B0C2")
const METAAL := Color("#C9CCDC")
const METAAL_L := Color("#EDEFF6")
const GOUD := Color("#F2C14E")
const GOUD_D := Color("#D9A72F")
const POT := Color("#D98E6A")
const PAPIER := Color("#FFFDF3")

## Every fixed name, in the order rooms.js declares them.
const NAMEN := ["boom", "hok", "hekx", "hekz", "tobbe", "bal", "kist", "mat", "poort",
	"balie", "baliez", "bel", "kassa", "boek", "prikbord", "sleutelbord", "bed", "bedz",
	"mand", "kast", "kastz", "zak", "kar", "lamp", "lampaan", "plant",
	"prikbordz", "sleutelbordz", "startblok"]
## The garden's grass tufts, laid out by a seeded PRNG.
const POL_AANTAL := 5

## The themed decor files (kitchen, laundry, bedrooms, reception and corridor)
## each bring their own table; `tabel()` merges them and `alle_namen()` lists
## every name, base set first.
static func _extra() -> Array:
	return [ArtDecorKeuken, ArtDecorWasserij, ArtDecorSlaapkamer, ArtDecorHotel]

static func alle_namen() -> Array[String]:
	var uit: Array[String] = []
	uit.append_array(NAMEN)
	for k in _extra():
		for n in k.NAMEN:
			if not uit.has(n):
				uit.append(n)
	return uit

static func boom(_p := {}) -> Array:
	var v: Array = []
	var kl := [BLAD_A, BLAD_B, BLAD, BLAD_B, BLAD_A]
	var bol := [[0, 29, 0, 8.5], [-8, 25, 5, 7.0], [7, 26, -6, 6.5], [1, 35, 2, 6.5], [-4, 32, -6, 5.5]]
	ArtVorm.bx(v, -3, 0, -3, 7, 2, 7, STAM)
	ArtVorm.bx(v, -2, 1, -2, 4, 21, 4, STAM)
	for i in bol.size():
		var b: Array = bol[i]
		ArtVorm.ell(v, b[0], b[1], b[2], b[3], b[3] * 0.92, b[3], kl[i], {"e": 2.2})
	return v

static func hok(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -11, 0, -10, 22, 17, 20, MUUR)
	for j in 9:
		ArtVorm.bx(v, -12 + j, 17 + j, -11, 24 - 2 * j, 1, 22, DAK)
	ArtVorm.verf(v, 10, 10, 0, 11, -4, 4, DEURKL)
	ArtVorm.verf(v, 10, 10, 12, 12, -5, 5, HOUT_D)
	ArtVorm.bx(v, -11, 0, -10, 22, 1, 20, HOUT_D)
	return v

static func mat(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -8, 0, -8, 17, 1, 17, HOUT)
	ArtVorm.verf(v, -8, 8, 0, 0, -8, -8, HOUT_D)
	ArtVorm.verf(v, -8, 8, 0, 0, 8, 8, HOUT_D)
	ArtVorm.verf(v, -8, -8, 0, 0, -8, 8, HOUT_D)
	ArtVorm.verf(v, 8, 8, 0, 0, -8, 8, HOUT_D)
	return v

## A swimming start block with a little stair (owner, 2026-09-17:
## "startblokken ... met een trappetje zodat het dier langzaam omhoog kan
## springen").  It faces the water (+x): three metal steps climb to a blue
## block with a white top at y = 7, the guest's standing height on it.
static func startblok(_p := {}) -> Array:
	var v: Array = []
	# a big startblok with a little stair on the west side, facing the water
	# (+x).  Bigger than the old one at the owner's word (2026-09-17: "Maak
	# het startblok groter en doe 1 ipv 3"): wider in z and taller, the block
	# front edge stops just short of the water so the dive clears it.
	ArtVorm.bx(v, -8, 0, -2, 2, 3, 4, METAAL)
	ArtVorm.bx(v, -6, 0, -2, 2, 6, 4, METAAL)
	ArtVorm.bx(v, -4, 0, -2, 2, 8, 4, METAAL)
	ArtVorm.bx(v, -2, 0, -3, 5, 8, 6, DEKEN_D)
	ArtVorm.bx(v, -2, 8, -3, 5, 1, 6, KUSSEN)
	ArtVorm.verf(v, 3, 3, 1, 8, -1, 1, DEKEN)
	return v

static func hekx(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -1, 0, -1, 3, 13, 3, HOUT_D)
	ArtVorm.bx(v, -2, 13, -2, 5, 1, 5, HOUT)
	ArtVorm.bx(v, 1, 9, -1, 11, 2, 3, HOUT)
	ArtVorm.bx(v, 1, 4, -1, 11, 2, 3, HOUT)
	return v

static func hekz(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -1, 0, -1, 3, 13, 3, HOUT_D)
	ArtVorm.bx(v, -2, 13, -2, 5, 1, 5, HOUT)
	ArtVorm.bx(v, -1, 9, 1, 3, 2, 11, HOUT)
	ArtVorm.bx(v, -1, 4, 1, 3, 2, 11, HOUT)
	return v

static func tobbe(_p := {}) -> Array:
	var v: Array = []
	for x in range(-5, 6):
		for z in range(-5, 6):
			var q := x * x + z * z
			if q > 27:
				continue
			if q > 15:
				ArtVorm.bx(v, x, 0, z, 1, 6, 1, HOUT)
				ArtVorm.verf(v, x, x, 5, 5, z, z, HOUT_D)
			else:
				ArtVorm.bx(v, x, 0, z, 1, 4, 1, WATER)
	return v

static func bal(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.ell(v, 0, 3.4, 0, 3.4, 3.4, 3.4, Color("#F5A8BE"), {"e": 2.0})
	ArtVorm.verf(v, -1, 1, 0, 7, -4, 4, Color("#FFF0C6"))
	return v

static func kist(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -4, 0, -4, 9, 8, 9, HOUT)
	ArtVorm.verf(v, -4, 4, 3, 4, -4, 4, HOUT_D)
	ArtVorm.bx(v, -5, 8, -5, 11, 1, 11, HOUT_L)
	return v

## Grass tufts: deterministic PRNG seed 4711 + n * 977, `n % 4 == 1` adds a
## pink or yellow flower.  Reproduce the PRNG exactly or the garden changes.
static func pol(n: int) -> Array:
	var v: Array = []
	var r := Sommen.Prng.new(4711 + n * 977)
	for i in 5 + (n % 3):
		var h := 2 + JsGetal.rond(r.volgende() * 4.0)
		var c := Color("#93C57E") if r.volgende() < 0.5 else Color("#A8D48F")
		ArtVorm.punt(v, JsGetal.rond(r.volgende() * 7.0 - 3.0), 0,
			JsGetal.rond(r.volgende() * 7.0 - 3.0), 2, h, 2, c)
	if n % 4 == 1:
		ArtVorm.punt(v, 1, 0, 1, 2, 6, 2, Color("#F7C0D2") if r.volgende() < 0.5 else Color("#FFE49B"))
	return v

# ------------------------------------------------------------------ hotelmeubels

## The counter runs along x; its wide front looks toward +z, straight at the child.
static func balie(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -17, 0, -5, 35, 12, 11, HOUT)
	ArtVorm.bx(v, -19, 12, -7, 39, 2, 15, HOUT_L)
	ArtVorm.verf(v, -17, 17, 4, 5, 5, 5, HOUT_D)
	ArtVorm.verf(v, -17, 17, 9, 9, 5, 5, HOUT_L)
	ArtVorm.verf(v, -17, 17, 0, 0, -5, 5, HOUT_D)
	return v

static func bel(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -3, 0, -3, 7, 1, 7, DEURKL)
	ArtVorm.ell(v, 0, 3.6, 0, 3.0, 3.2, 3.0, GOUD, {"e": 2.4, "ymin": 1})
	ArtVorm.bx(v, -1, 6, -1, 3, 2, 3, GOUD_D)
	return v

static func kassa(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -5, 0, -6, 11, 7, 13, METAAL)
	ArtVorm.bx(v, -5, 7, -6, 11, 2, 8, METAAL_L)
	ArtVorm.verf(v, -5, 5, 3, 4, 6, 6, Color("#A0A6C0"))
	ArtVorm.bx(v, -3, 9, -1, 7, 5, 2, METAAL_L)
	ArtVorm.verf(v, -3, 3, 11, 12, 0, 0, Color("#8FA9C4"))
	return v

static func boek(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -5, 0, -4, 11, 2, 9, PAPIER)
	ArtVorm.bx(v, -5, 0, -4, 11, 1, 9, Color("#E08FA6"))
	ArtVorm.verf(v, 0, 0, 0, 2, -4, 4, Color("#C9788F"))
	return v

## Hangs on the wall z = 0.
static func prikbord(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -11, 4, 0, 23, 19, 2, HOUT_D)
	ArtVorm.bx(v, -10, 5, 1, 21, 17, 2, Color("#E8CFA6"))
	ArtVorm.bx(v, -8, 8, 3, 6, 6, 1, PAPIER)
	ArtVorm.bx(v, 0, 9, 3, 6, 7, 1, Color("#FFF0C6"))
	ArtVorm.bx(v, -3, 16, 3, 5, 4, 1, Color("#FFC7D9"))
	return v

## Hangs on the wall z = 0, five hooks.
static func sleutelbord(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -10, 6, 0, 21, 13, 2, HOUT)
	ArtVorm.verf(v, -10, 10, 6, 6, 1, 1, HOUT_D)
	for i in 5:
		ArtVorm.bx(v, -8 + i * 4, 14, 2, 1, 1, 1, GOUD_D)
		ArtVorm.bx(v, -8 + i * 4, 10, 2, 2, 4, 1, GOUD)
	return v

## Lies along x; the pillow is at the high-x end, where a sleeper's head goes.
static func bed(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -16, 0, -8, 33, 4, 17, HOUT_D)
	ArtVorm.bx(v, -15, 4, -7, 31, 3, 15, KUSSEN)
	ArtVorm.bx(v, -17, 0, -8, 3, 13, 17, HOUT)
	ArtVorm.bx(v, 14, 0, -8, 3, 9, 17, HOUT)
	ArtVorm.bx(v, 4, 7, -7, 9, 2, 15, KUSSEN)
	ArtVorm.bx(v, -13, 7, -7, 16, 2, 15, DEKEN)
	ArtVorm.verf(v, 2, 2, 7, 8, -7, 7, DEKEN_D)
	ArtVorm.verf(v, -16, 13, 3, 3, -8, 8, HOUT_L)
	return v

static func mand(_p := {}) -> Array:
	var v: Array = []
	for x in range(-7, 8):
		for z in range(-7, 8):
			var q := x * x + z * z
			if q > 46:
				continue
			if q > 26:
				ArtVorm.bx(v, x, 0, z, 1, 7, 1, HOUT)
				ArtVorm.verf(v, x, x, 6, 6, z, z, HOUT_L)
			else:
				ArtVorm.bx(v, x, 0, z, 1, 3, 1, STOF)
	return v

## The food cupboard against the wall z = 0 — the tallest furniture, 29 voxels.
static func kast(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -12, 0, -2, 25, 27, 10, HOUT)
	ArtVorm.verf(v, -12, 12, 0, 26, 7, 7, HOUT_L)
	ArtVorm.verf(v, -1, 0, 0, 26, 7, 7, HOUT_D)
	ArtVorm.verf(v, -12, 12, 13, 13, 7, 7, HOUT_D)
	ArtVorm.bx(v, -4, 12, 8, 1, 2, 1, GOUD)
	ArtVorm.bx(v, 3, 12, 8, 1, 2, 1, GOUD)
	ArtVorm.bx(v, -13, 27, -3, 27, 2, 12, HOUT_D)
	return v

static func zak(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.ell(v, 0, 7, 0, 6.5, 7.0, 6.5, Color("#E8CFA6"), {"e": 2.6, "ymin": 0})
	ArtVorm.verf(v, -7, 7, 3, 7, 5, 7, Color("#D9B98A"))
	ArtVorm.bx(v, -2, 13, -2, 5, 3, 5, Color("#C99B63"))
	ArtVorm.verf(v, -3, 3, 5, 8, -7, -5, Color("#C99B63"))
	return v

## The feeding cart: three compartments, a sweet jar and four wheels.
static func kar(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -13, 4, -9, 27, 3, 19, HOUT)
	ArtVorm.bx(v, -13, 7, -9, 27, 1, 19, HOUT_L)
	for i in 3:
		ArtVorm.bx(v, -12 + i * 8, 8, -8, 7, 5, 8, HOUT_D)
		ArtVorm.bx(v, -11 + i * 8, 9, -7, 5, 4, 6, MUUR)
	ArtVorm.ell(v, 6, 11, 4, 4.4, 4.0, 4.4, Color("#DFF1FB"), {"e": 2.6, "ymin": 8})
	ArtVorm.bx(v, 3, 15, 1, 7, 1, 7, Color("#C5E4F7"))
	ArtVorm.bx(v, -11, 0, -8, 4, 5, 4, Color("#6E5A4A"))
	ArtVorm.bx(v, -11, 0, 5, 4, 5, 4, Color("#6E5A4A"))
	ArtVorm.bx(v, 8, 0, -8, 4, 5, 4, Color("#6E5A4A"))
	ArtVorm.bx(v, 8, 0, 5, 4, 5, 4, Color("#6E5A4A"))
	ArtVorm.bx(v, -15, 7, -9, 2, 14, 19, HOUT_D)
	ArtVorm.bx(v, -16, 20, -9, 4, 2, 19, HOUT)
	return v

static func lamp(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -3, 0, -3, 7, 1, 7, METAAL)
	ArtVorm.bx(v, -1, 1, -1, 3, 8, 3, METAAL)
	ArtVorm.ell(v, 0, 11, 0, 4.6, 3.2, 4.6, Color("#CFD6E0"), {"e": 2.6, "ymin": 9})
	return v

static func lampaan(_p := {}) -> Array:
	var v := lamp()
	ArtVorm.verf(v, -6, 6, 8, 16, -6, 6, Color("#FFE9A8"))
	return v

static func plant(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -4, 0, -4, 9, 6, 9, POT)
	ArtVorm.bx(v, -5, 6, -5, 11, 2, 11, Color("#E8A97F"))
	ArtVorm.ell(v, 0, 13, 0, 5.5, 5.5, 5.5, BLAD, {"e": 2.2})
	ArtVorm.ell(v, 3, 17, -2, 4.0, 4.0, 4.0, BLAD_B, {"e": 2.2})
	ArtVorm.ell(v, -3, 16, 3, 3.6, 3.6, 3.6, BLAD_A, {"e": 2.2})
	return v

## The garden gate in the fence.
static func poort(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -1, 0, -9, 3, 15, 3, HOUT_D)
	ArtVorm.bx(v, -1, 0, 7, 3, 15, 3, HOUT_D)
	ArtVorm.bx(v, -1, 13, -9, 3, 2, 19, HOUT)
	ArtVorm.bx(v, -1, 4, -7, 3, 2, 15, HOUT)
	return v

# --------------------------------------------------------------------- register

## `naam -> Callable(params) -> Array`, the four `*z` variants mirrored over the
## diagonal by `ArtVorm.draai` — the same furniture, a quarter turn round.
static func tabel() -> Dictionary:
	var uit := _basis()
	for k in _extra():
		var t: Dictionary = k.tabel()
		for n in t:
			if uit.has(n):
				push_error("ArtDecor: model '%s' is al een basismodel" % n)
				continue
			uit[n] = t[n]
	return uit

static func _basis() -> Dictionary:
	return {
		"boom": Callable(ArtDecor, "boom"),
		"hok": Callable(ArtDecor, "hok"),
		"hekx": Callable(ArtDecor, "hekx"),
		"hekz": Callable(ArtDecor, "hekz"),
		"tobbe": Callable(ArtDecor, "tobbe"),
		"bal": Callable(ArtDecor, "bal"),
		"kist": Callable(ArtDecor, "kist"),
		"mat": Callable(ArtDecor, "mat"),
		"startblok": Callable(ArtDecor, "startblok"),
		"poort": Callable(ArtDecor, "poort"),
		"balie": Callable(ArtDecor, "balie"),
		"baliez": func(_p := {}): return ArtVorm.draai(balie()),
		"bel": Callable(ArtDecor, "bel"),
		"kassa": Callable(ArtDecor, "kassa"),
		"boek": Callable(ArtDecor, "boek"),
		"prikbord": Callable(ArtDecor, "prikbord"),
		"prikbordz": func(_p := {}): return ArtVorm.draai(prikbord()),
		"sleutelbord": Callable(ArtDecor, "sleutelbord"),
		"sleutelbordz": func(_p := {}): return ArtVorm.draai(sleutelbord()),
		"bed": Callable(ArtDecor, "bed"),
		"bedz": func(_p := {}): return ArtVorm.draai(bed()),
		"mand": Callable(ArtDecor, "mand"),
		"kast": Callable(ArtDecor, "kast"),
		"kastz": func(_p := {}): return ArtVorm.draai(kast()),
		"zak": Callable(ArtDecor, "zak"),
		"kar": Callable(ArtDecor, "kar"),
		"lamp": Callable(ArtDecor, "lamp"),
		"lampaan": Callable(ArtDecor, "lampaan"),
		"plant": Callable(ArtDecor, "plant"),
	}
