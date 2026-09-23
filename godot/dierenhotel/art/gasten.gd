class_name ArtGasten
extends RefCounted
## The four guests, their fifteen poses, the three accessories and the feeding
## bowl — a one-to-one port of `demos/dierenhotel/art.js` (art-sound-rules.md
## §4, §5, §6, §7).  Pure: same arguments, same voxel list, always.
##
## Grid: x = length (0 = tail, ~29 = nose), y = height (0 = ground), z = depth
## 0..15 with the heart at 7.5.  The feeding bowl sits at x 26..33.

const INK := Color("#4A3B33")
const WIT := Color("#FFF7EC")
const OOG := Color("#5B4840")   ## soft dark brown, never black
const NEUS := Color("#7E6255")  ## nose / mouth line, one step softer still
const BAND := Color("#6BC5A4")  ## the dog's collar

const SOORTEN := ["hond", "poes", "konijn", "gans"]

const PAL := {
	"hond": {"b": Color("#EEC194"), "d": Color("#D3996A"), "e": Color("#B4744A"), "l": Color("#FCE8D3")},
	"poes": {"b": Color("#C9CCDC"), "d": Color("#A0A6C0"), "e": Color("#F4C8D5"), "l": Color("#EDEFF6")},
	"konijn": {"b": Color("#F5E7EC"), "d": Color("#DCC6D3"), "e": Color("#F5B0C2"), "l": Color("#FFFBF6")},
	"gans": {"b": Color("#FDF8EA"), "d": Color("#E0D8C2"), "e": Color("#F6A957"), "l": Color("#FFFCF4")},
}
const KOM := {
	"schaal": Color("#DFC6D6"), "rand": Color("#F8E7F1"),
	"brok": Color("#BC8149"), "brok2": Color("#97663A"),
}

## Accessories, in the fixed order that makes a list into one cache key.
const ACC_NAMEN := ["hoedje", "sjaaltje", "bal"]
const HOED := BAND
const HOED_LINT := WIT
const SJAAL := Color("#F6A957")      ## PAL.gans.e
const SJAAL_FR := WIT
const BAL_KL := Color("#F4C8D5")     ## PAL.poes.e
const BAL_BAND := WIT

## The fifteen poses (art-sound-rules.md §5).  All frame poses: real geometry,
## never a transform.
const POSE := {
	"rust":   {"hx": 0, "hy": 0, "oor": "rust", "staart": "mid", "mond": 0, "oog": 0, "stap": 0, "zit": 0, "lig": 0},
	"tril":   {"hx": 0, "hy": 0, "oor": "perk", "staart": "r", "mond": 0, "oog": 0, "stap": 0, "zit": 0, "lig": 0},
	"hap1":   {"hx": 1, "hy": -4, "oor": "vooruit", "staart": "l", "mond": 1, "oog": -1, "stap": 0, "zit": 0, "lig": 0},
	"hap2":   {"hx": 2, "hy": -7, "oor": "vooruit", "staart": "r", "mond": 1, "oog": -1, "stap": 0, "zit": 0, "lig": 0},
	"blijA":  {"hx": 0, "hy": 0, "oor": "perk", "staart": "l", "mond": 1, "oog": 1, "stap": 0, "zit": 0, "lig": 0},
	"blijB":  {"hx": 0, "hy": 2, "oor": "perk", "staart": "r", "mond": 1, "oog": 1, "stap": 0, "zit": 0, "lig": 0},
	"sip":    {"hx": 0, "hy": -1, "oor": "hang", "staart": "laag", "mond": 2, "oog": 2, "stap": 0, "zit": 0, "lig": 0},
	"zwaai":  {"hx": 0, "hy": 0, "oor": "rust", "staart": "l", "mond": 0, "oog": 0, "stap": 0, "zit": 0, "lig": 0},
	"kijk":   {"hx": -1, "hy": 1, "oor": "perk", "staart": "l", "mond": 0, "oog": 0, "stap": 0, "zit": 0, "lig": 0},
	"loopA":  {"hx": 1, "hy": 0, "oor": "rust", "staart": "l", "mond": 0, "oog": 0, "stap": 1, "zit": 0, "lig": 0},
	"loopB":  {"hx": 1, "hy": 0, "oor": "rust", "staart": "r", "mond": 0, "oog": 0, "stap": 2, "zit": 0, "lig": 0},
	"zit":    {"hx": 0, "hy": 1, "oor": "rust", "staart": "laag", "mond": 0, "oog": 0, "stap": 0, "zit": 1, "lig": 0},
	"zitsip": {"hx": 0, "hy": 0, "oor": "hang", "staart": "laag", "mond": 2, "oog": 2, "stap": 0, "zit": 1, "lig": 0},
	"lig":    {"hx": 0, "hy": -1, "oor": "hang", "staart": "laag", "mond": 0, "oog": 3, "stap": 0, "zit": 0, "lig": 1},
	"snuif":  {"hx": 1, "hy": -6, "oor": "vooruit", "staart": "mid", "mond": 0, "oog": -1, "stap": 0, "zit": 0, "lig": 0},
}
## Only these nine decide the canvas size of a card sprite.
const POSE_NAMEN := ["rust", "tril", "hap1", "hap2", "blijA", "blijB", "sip", "snuif", "loopA"]

## The frames of the arrival through the front door (owner, 2026-09-23: "een
## leuke animatie wanneer ze binnenkomen dat per dier anders is";
## art-sound-rules.md §5.2).  The cat slinks in low and stretches at the desk,
## the goose waddles in flapping its wings.  They are NOT in `POSE`: the
## fifteen there are the HTML's, each held against its golden plate, and these
## have no HTML original.  Same keys, plus two that only they use:
##   `buk`     the front sinks this many voxels at the nose while the rear
##             stays up (`bukken`, the mirror of `zitten`) — a stretch;
##   `vleugel` the goose's wings: 1 half raised, 2 raised high over the back.
const POSE_EXTRA := {
	"sluipA":   {"hx": 1, "hy": -2, "oor": "vooruit", "staart": "laag", "mond": 0, "oog": -1, "stap": 1, "zit": 0, "lig": 0, "buk": 2},
	"sluipB":   {"hx": 1, "hy": -2, "oor": "vooruit", "staart": "laag", "mond": 0, "oog": -1, "stap": 2, "zit": 0, "lig": 0, "buk": 2},
	"strek":    {"hx": 2, "hy": -2, "oor": "rust", "staart": "l", "mond": 1, "oog": 1, "stap": 0, "zit": 0, "lig": 0, "buk": 6},
	"fladder":  {"hx": 0, "hy": 1, "oor": "perk", "staart": "r", "mond": 1, "oog": 0, "stap": 0, "zit": 0, "lig": 0, "vleugel": 2},
	"fladderA": {"hx": 1, "hy": 0, "oor": "rust", "staart": "l", "mond": 0, "oog": 0, "stap": 1, "zit": 0, "lig": 0, "vleugel": 2},
	"fladderB": {"hx": 1, "hy": 0, "oor": "rust", "staart": "r", "mond": 0, "oog": 0, "stap": 2, "zit": 0, "lig": 0, "vleugel": 1},
}

## One pose by name: the HTML's fifteen first, then the arrival's; an unknown
## name is `rust`, as it always was.
static func pose_van(naam: String) -> Dictionary:
	return POSE.get(naam, POSE_EXTRA.get(naam, POSE["rust"]))

const POOT := 7                     ## the bottom layers that `liggen` squashes
const KOM_CX := 29.5
const KOM_CZ := 7.5
const KOM_R := 3.9
const KOM_H := 4
const KOM_VOOR := 38

# ------------------------------------------------------------------- gezicht

## Eyes: a block on both sides of the head, mirrored in z, with a white
## highlight on the top layer.
static func ogen(v: Array, p: Dictionary, x: int, y: int, z1: int, z2: int, o: Dictionary) -> void:
	var h: int = o.get("h", 2)
	var w: int = o.get("w", 2)
	var dik: int = o.get("dik", 2)
	var yy := y
	var kl := OOG
	var oog: int = p["oog"]
	if oog == 1:            # happy: squint
		yy = y + h - 1
		h = 1
	elif oog == 2:          # sad: half closed
		h = maxi(1, h - 1)
	elif oog == -1:         # looking at the bowl
		yy = y - 1
	elif oog == 3:          # asleep: a soft lash stroke, one voxel wider
		yy = y
		h = 1
		w = w + 1
		kl = NEUS
	ArtVorm.verf(v, x, x + dik - 1, yy, yy + h - 1, z1, z1 + w - 1, kl)
	ArtVorm.verf(v, x, x + dik - 1, yy, yy + h - 1, z2 - w + 1, z2, kl)
	if h > 1 and o.get("glans", true):
		ArtVorm.verf(v, x, x + dik - 1, yy + h - 1, yy + h - 1, z1, z1, WIT)
		ArtVorm.verf(v, x, x + dik - 1, yy + h - 1, yy + h - 1, z2, z2, WIT)

## Mouth: 1 = open (happy / biting), 2 = soft down-turned corners (sad).
## Never crying, never angry; the face must stay visible.
static func mond(v: Array, p: Dictionary, x: int, y: int, z1: int, z2: int, zacht: Color) -> void:
	var m: int = p["mond"]
	if m == 1:
		ArtVorm.verf(v, x, x + 1, y, y, z1 + 1, z2 - 1, NEUS)
	elif m == 2:
		ArtVorm.verf(v, x, x + 1, y, y, z1, z1, zacht)
		ArtVorm.verf(v, x, x + 1, y, y, z2, z2, zacht)

## Which leg steps forward: a diagonal gait (left-rear + right-front together).
static func duwen(stap: int) -> Array:
	var s := 1 if stap == 1 else (-1 if stap == 2 else 0)
	return [s, -s, -s, s]

# --------------------------------------------------------------- de vier dieren

static func hond(p: Dictionary) -> Array:
	var C: Dictionary = PAL["hond"]
	var v: Array = []
	var hx: int = p["hx"]
	var hy: int = p["hy"]
	var tz := -2 if p["staart"] == "l" else (2 if p["staart"] == "r" else 0)
	var poot := [[5, 3], [5, 9], [13, 3], [13, 9]]
	var duw := duwen(p["stap"])
	for i in 4:
		var px: int = poot[i][0] + int(duw[i]) * 2
		var py := 1 if int(duw[i]) > 0 else 0
		var ph := 7 - py
		ArtVorm.bx(v, px, py, poot[i][1], 4, ph, 4, C["d"])
		ArtVorm.bx(v, px, py, poot[i][1], 5, 2, 4, C["l"])
		ArtVorm.verf(v, px, px + 4, py + 1, py + 1, poot[i][1] + 2, poot[i][1] + 2, C["d"])
	ArtVorm.ell(v, 10.5, 9.5, 7.5, 7.0, 4.4, 5.8, C["b"], {"e": 3.4, "ymin": 5})
	ArtVorm.verf(v, 14, 18, 5, 9, 3, 12, C["l"])
	if p["staart"] == "laag":
		ArtVorm.bx(v, 2, 7, 6, 3, 3, 3, C["d"])
		ArtVorm.bx(v, 0, 5, 6, 3, 3, 3, C["d"])
		ArtVorm.bx(v, 0, 4, 6, 2, 2, 3, C["l"])
	else:
		ArtVorm.bx(v, 3, 9, 6 + tz, 3, 3, 3, C["d"])
		ArtVorm.bx(v, 2, 12, 6 + tz, 3, 3, 3, C["d"])
		ArtVorm.bx(v, 1, 15, 6 + tz, 2, 3, 3, C["l"])
	ArtVorm.hals(v, 16, 12, 20 + hx, 15 + hy, 7.5, 2.8, 3.6, C["b"])
	ArtVorm.verf(v, 15, 16, 9, 12, 3, 12, BAND)
	ArtVorm.ell(v, 22 + hx, 17 + hy, 7.5, 4.4, 5.0, 5.6, C["b"], {"e": 3.2})
	ArtVorm.ell(v, 27 + hx, 15 + hy, 7.5, 2.4, 2.4, 3.4, C["l"], {"e": 2.8})
	ArtVorm.verf(v, 28 + hx, 29 + hx, 16 + hy, 17 + hy, 7, 8, NEUS)
	var oy := 17
	var ox := 21
	if p["oor"] == "perk":
		oy = 21
	elif p["oor"] == "hang":
		oy = 14
	elif p["oor"] == "vooruit":
		ox = 23
		oy = 18
	ArtVorm.ell(v, ox + hx, oy + hy, 0.6, 1.9, 3.4, 1.8, C["e"], {"e": 3.0})
	ArtVorm.ell(v, ox + hx, oy + hy, 14.4, 1.9, 3.4, 1.8, C["e"], {"e": 3.0})
	mond(v, p, 28 + hx, 14 + hy, 6, 9, C["d"])
	ogen(v, p, 25 + hx, 18 + hy, 4, 11, {"h": 2, "w": 2, "dik": 2})
	return v

static func poes(p: Dictionary) -> Array:
	var C: Dictionary = PAL["poes"]
	var v: Array = []
	var hx: int = p["hx"]
	var hy: int = p["hy"]
	var tz := -2 if p["staart"] == "l" else (2 if p["staart"] == "r" else 0)
	var poot := [[6, 4], [6, 9], [13, 4], [13, 9]]
	var duw := duwen(p["stap"])
	for i in 4:
		var px: int = poot[i][0] + int(duw[i]) * 2
		var py := 1 if int(duw[i]) > 0 else 0
		var ph := 8 - py
		ArtVorm.bx(v, px, py, poot[i][1], 3, ph, 3, C["d"])
		ArtVorm.bx(v, px, py, poot[i][1], 4, 3, 3, C["l"])
		ArtVorm.verf(v, px, px + 3, py + 2, py + 2, poot[i][1] + 1, poot[i][1] + 1, C["d"])
	ArtVorm.ell(v, 10.5, 10.5, 7.5, 6.4, 4.2, 5.0, C["b"], {"e": 3.2, "ymin": 6})
	ArtVorm.verf(v, 14, 17, 6, 10, 4, 11, C["l"])
	if p["staart"] == "laag":
		ArtVorm.bx(v, 4, 8, 7, 3, 3, 3, C["b"])
		ArtVorm.bx(v, 2, 6, 7, 3, 3, 3, C["b"])
		ArtVorm.bx(v, 1, 5, 7, 2, 2, 3, C["l"])
	else:
		ArtVorm.bx(v, 4, 10, 6 + tz, 3, 4, 3, C["b"])
		ArtVorm.bx(v, 3, 13, 6 + tz, 3, 4, 3, C["b"])
		ArtVorm.bx(v, 3, 16, 6 + tz, 2, 3, 3, C["l"])
		ArtVorm.verf(v, 3, 6, 11, 11, 6 + tz, 8 + tz, C["d"])
		ArtVorm.verf(v, 3, 6, 14, 14, 6 + tz, 8 + tz, C["d"])
	ArtVorm.hals(v, 15, 12, 19 + hx, 15 + hy, 7.5, 2.4, 3.0, C["b"])
	ArtVorm.ell(v, 21 + hx, 16.5 + hy, 7.5, 3.8, 4.0, 4.8, C["b"], {"e": 3.2})
	ArtVorm.ell(v, 25.5 + hx, 14.5 + hy, 7.5, 1.8, 1.8, 3.2, C["l"], {"e": 2.8})
	ArtVorm.verf(v, 26 + hx, 27 + hx, 15 + hy, 15 + hy, 7, 8, C["e"])
	if p["oor"] == "hang":
		ArtVorm.bx(v, 17 + hx, 18 + hy, 2, 3, 2, 3, C["b"])
		ArtVorm.bx(v, 17 + hx, 18 + hy, 11, 3, 2, 3, C["b"])
		ArtVorm.verf(v, 18 + hx, 19 + hx, 18 + hy, 19 + hy, 2, 2, C["e"])
		ArtVorm.verf(v, 18 + hx, 19 + hx, 18 + hy, 19 + hy, 13, 13, C["e"])
	else:
		var eo := 1 if p["oor"] == "perk" else 0
		var ex := 20 if p["oor"] == "vooruit" else 18
		ArtVorm.punt(v, ex + hx, 18 + eo + hy, 4, 3, 5, 3, C["b"])
		ArtVorm.punt(v, ex + hx, 18 + eo + hy, 9, 3, 5, 3, C["b"])
		ArtVorm.verf(v, ex + 1 + hx, ex + 1 + hx, 18 + eo + hy, 21 + eo + hy, 4, 5, C["e"])
		ArtVorm.verf(v, ex + 1 + hx, ex + 1 + hx, 18 + eo + hy, 21 + eo + hy, 9, 10, C["e"])
	mond(v, p, 26 + hx, 13 + hy, 6, 9, C["d"])
	ogen(v, p, 24 + hx, 17 + hy, 4, 11, {"h": 2, "w": 2, "dik": 2})
	return v

static func konijn(p: Dictionary) -> Array:
	var C: Dictionary = PAL["konijn"]
	var v: Array = []
	var hx: int = p["hx"]
	var hy: int = p["hy"]
	var tz := -1 if p["staart"] == "l" else (1 if p["staart"] == "r" else 0)
	var hs := 2 if p["stap"] == 1 else (-1 if p["stap"] == 2 else 0)
	var vy := 2 if p["stap"] == 1 else 0
	ArtVorm.bx(v, 5 + hs, 0, 3, 7, 3, 4, C["l"])
	ArtVorm.bx(v, 5 + hs, 0, 9, 7, 3, 4, C["l"])
	ArtVorm.verf(v, 5 + hs, 11 + hs, 2, 2, 5, 5, C["d"])
	ArtVorm.verf(v, 5 + hs, 11 + hs, 2, 2, 11, 11, C["d"])
	ArtVorm.ell(v, 9 + hs, 5, 4.8, 3.5, 3.7, 2.3, C["b"], {"e": 3.0, "ymin": 2})
	ArtVorm.ell(v, 9 + hs, 5, 10.2, 3.5, 3.7, 2.3, C["b"], {"e": 3.0, "ymin": 2})
	ArtVorm.bx(v, 14, vy, 4, 3, 7 - vy, 3, C["b"])
	ArtVorm.bx(v, 14, vy, 9, 3, 7 - vy, 3, C["b"])
	ArtVorm.bx(v, 14, vy, 4, 4, 2, 3, C["l"])
	ArtVorm.bx(v, 14, vy, 9, 4, 2, 3, C["l"])
	ArtVorm.ell(v, 11, 10, 7.5, 6.2, 5.0, 5.2, C["b"], {"e": 3.2, "ymin": 5})
	ArtVorm.verf(v, 14, 18, 5, 10, 4, 11, C["l"])
	ArtVorm.ell(v, 3.2, 9.5 if p["staart"] == "laag" else 12.0, 7.5 + tz, 2.3, 2.3, 2.3, C["l"], {"e": 3.0})
	ArtVorm.hals(v, 15, 13, 19 + hx, 16 + hy, 7.5, 2.6, 3.2, C["b"])
	ArtVorm.ell(v, 21 + hx, 17 + hy, 7.5, 4.2, 4.4, 5.2, C["b"], {"e": 3.2})
	ArtVorm.ell(v, 25.5 + hx, 15 + hy, 7.5, 1.8, 1.8, 3.0, C["l"], {"e": 2.8})
	ArtVorm.verf(v, 26 + hx, 27 + hx, 15 + hy, 15 + hy, 7, 8, C["e"])
	ArtVorm.verf(v, 26 + hx, 27 + hx, 13 + hy, 13 + hy, 7, 8, WIT)
	if p["lig"]:
		ArtVorm.ell(v, 15 + hx, 16, 2.4, 4.8, 1.6, 1.6, C["d"], {"e": 3.0})
		ArtVorm.ell(v, 15 + hx, 16, 12.6, 4.8, 1.6, 1.6, C["d"], {"e": 3.0})
		ArtVorm.verf(v, 12 + hx, 18 + hx, 17, 17, 2, 3, C["e"])
		ArtVorm.verf(v, 12 + hx, 18 + hx, 17, 17, 12, 13, C["e"])
	elif p["oor"] == "hang":
		ArtVorm.ell(v, 18 + hx, 13 + hy, 1.6, 1.8, 4.6, 1.6, C["d"], {"e": 3.0})
		ArtVorm.ell(v, 18 + hx, 13 + hy, 13.4, 1.8, 4.6, 1.6, C["d"], {"e": 3.0})
		ArtVorm.verf(v, 19 + hx, 20 + hx, 9 + hy, 17 + hy, 0, 1, C["e"])
		ArtVorm.verf(v, 19 + hx, 20 + hx, 9 + hy, 17 + hy, 14, 15, C["e"])
	else:
		var ox := 22 if p["oor"] == "vooruit" else 19
		var oh := 5.0 if p["oor"] == "perk" else 4.4
		ArtVorm.ell(v, ox + hx, 19 + oh + hy, 4.4, 1.8, oh, 1.6, C["d"], {"e": 3.0})
		ArtVorm.ell(v, ox + hx, 19 + oh + hy, 10.6, 1.8, oh, 1.6, C["d"], {"e": 3.0})
		ArtVorm.verf(v, ox + 1 + hx, ox + 1 + hx, 18 + hy, 28 + hy, 4, 5, C["e"])
		ArtVorm.verf(v, ox + 1 + hx, ox + 1 + hx, 18 + hy, 28 + hy, 10, 11, C["e"])
	mond(v, p, 26 + hx, 13 + hy, 6, 9, C["d"])
	ogen(v, p, 24 + hx, 18 + hy, 4, 11, {"h": 2, "w": 2, "dik": 2})
	return v

static func gans(p: Dictionary) -> Array:
	var C: Dictionary = PAL["gans"]
	var v: Array = []
	var hx := JsGetal.rond(float(p["hx"]) * 2.5)
	var hy: int = JsGetal.rond(float(p["hy"]) * 2.2) if int(p["hy"]) < 0 else int(p["hy"])
	var tz := -1 if p["staart"] == "l" else (1 if p["staart"] == "r" else 0)
	var gs := 2 if p["stap"] == 1 else (-2 if p["stap"] == 2 else 0)
	ArtVorm.bx(v, 8 + gs, 0, 3, 5, 1, 3, C["e"])
	ArtVorm.bx(v, 8 - gs, 0, 10, 5, 1, 3, C["e"])
	ArtVorm.bx(v, 9 + gs, 1, 4, 2, 7, 2, C["e"])
	ArtVorm.bx(v, 9 - gs, 1, 10, 2, 7, 2, C["e"])
	ArtVorm.ell(v, 10, 10.5, 7.5, 6.2, 4.6, 5.2, C["b"], {"e": 3.0, "ymin": 5})
	var vleugel := int(p.get("vleugel", 0))
	if vleugel > 0:
		# flapping (the arrival, POSE_EXTRA): the wings rise over the back and
		# spread a voxel wider, their dark feather tips on top
		var hy_v := 14.0 if vleugel == 1 else 18.5
		var uit := 1.2 if vleugel == 1 else 0.0
		var ry := 3.2 if vleugel == 1 else 3.8
		ArtVorm.ell(v, 9.5, hy_v, uit, 4.6, ry, 1.4, C["b"], {"e": 3.0})
		ArtVorm.ell(v, 9.5, hy_v, 15.0 - uit, 4.6, ry, 1.4, C["b"], {"e": 3.0})
		var top := JsGetal.rond(hy_v + ry - 1.0)
		ArtVorm.verf(v, 5, 14, top, top + 2, -2, 2, C["d"])
		ArtVorm.verf(v, 5, 14, top, top + 2, 13, 17, C["d"])
	else:
		var wy := 11.5 if p["oor"] == "perk" else (9.5 if p["oor"] == "hang" else 10.5)
		ArtVorm.ell(v, 10, wy, 2.0, 4.6, 3.0, 1.5, C["b"], {"e": 3.0})
		ArtVorm.ell(v, 10, wy, 13.0, 4.6, 3.0, 1.5, C["b"], {"e": 3.0})
		ArtVorm.verf(v, 8, 13, wy - 1, wy - 1, 1, 2, C["d"])
		ArtVorm.verf(v, 8, 13, wy - 1, wy - 1, 13, 14, C["d"])
	ArtVorm.punt(v, 3, 9 if p["staart"] == "laag" else 11, 6 + tz, 3, 3, 4, C["b"])
	var ky := 21 + hy
	ArtVorm.hals(v, 14, 13, 19 + hx, ky + 1, 7.5, 1.9, 2.2, C["b"])
	ArtVorm.ell(v, 19 + hx, ky + 3, 7.5, 2.8, 2.8, 3.0, C["b"], {"e": 2.8})
	ArtVorm.bx(v, 21 + hx, ky + 2, 6, 3, 2, 4, C["e"])
	ArtVorm.verf(v, 23 + hx, 23 + hx, ky + 3, ky + 3, 7, 7, C["d"])
	if p["mond"] == 1:
		ArtVorm.bx(v, 21 + hx, ky + 1, 6, 3, 1, 4, C["e"])
	elif p["mond"] == 2:
		ArtVorm.verf(v, 23 + hx, 23 + hx, ky + 2, ky + 2, 6, 9, C["d"])
	ogen(v, p, 20 + hx, ky + 4, 5, 10, {"h": 1, "w": 1, "dik": 2})
	return v

static func soort(kind: String, p: Dictionary) -> Array:
	match kind:
		"poes": return poes(p)
		"konijn": return konijn(p)
		"gans": return gans(p)
		_: return hond(p)

# ------------------------------------------------------------- zitten / liggen

## Sitting: the rear sinks, the head stays up.  No second model per species.
static func zitten(v: Array) -> Array:
	var x0 := 1 << 30
	var x1 := -(1 << 30)
	for p in v:
		x0 = mini(x0, p["x"])
		x1 = maxi(x1, p["x"])
	var sp := maxi(1, x1 - x0)
	for p in v:
		var t := float(p["x"] - x0) / float(sp)
		var zak := JsGetal.rond((1.0 - t) * (1.0 - t) * 5.0)
		p["y"] = maxi(0, p["y"] - zak)
	return v

## Lying: the bottom POOT layers are squashed to 30 %, everything above shifts
## down with them.  Light is baked AFTER this step, so no shadow falls wrong.
static func liggen(v: Array) -> Array:
	var plat := JsGetal.rond(POOT * 0.3)
	for p in v:
		var y: int = p["y"]
		p["y"] = JsGetal.rond(y * 0.3) if y <= POOT else y - POOT + plat
	return v

## Stretching (the arrival's `buk`, POSE_EXTRA): the mirror of `zitten` — the
## FRONT sinks, up to `buk` voxels at the nose, and the rear stays where it is,
## so the front paws flatten on the floor and the back slopes up to the tail.
static func bukken(v: Array, buk: float) -> Array:
	var x0 := 1 << 30
	var x1 := -(1 << 30)
	for p in v:
		x0 = mini(x0, p["x"])
		x1 = maxi(x1, p["x"])
	var sp := maxi(1, x1 - x0)
	for p in v:
		var t := float(p["x"] - x0) / float(sp)
		var zak := JsGetal.rond(t * t * buk)
		p["y"] = maxi(0, p["y"] - zak)
	return v

# ----------------------------------------------------------------- accessoires

## Where the head `[mid-x, top-y, rx, rz]` and the neck `[x0, y0, x1, y1,
## radius, depth, place on the neck axis, extra thickness]` of this species sit
## in this pose — exactly the numbers of the model functions above, the goose's
## hx/hy rewrite included, so the outfit moves with biting and sniffing.
static func ankers(kind: String, p: Dictionary) -> Dictionary:
	var hx: int = p["hx"]
	var hy: int = p["hy"]
	if kind == "poes":
		return {"kop": [22 + hx, 20.5 + hy, 3.8, 4.8],
			"hals": [15, 12, 19 + hx, 15 + hy, 2.4, 3.0, 0.55, 1.0]}
	if kind == "konijn":
		return {"kop": [21 + hx, 21.4 + hy, 4.2, 5.2],
			"hals": [15, 13, 19 + hx, 16 + hy, 2.6, 3.2, 0.55, 1.0]}
	if kind == "gans":
		hx = JsGetal.rond(float(p["hx"]) * 2.5)
		hy = JsGetal.rond(float(p["hy"]) * 2.2) if int(p["hy"]) < 0 else int(p["hy"])
		var ky := 21 + hy
		return {"kop": [19 + hx, ky + 5.8, 2.8, 3.0],
			"hals": [14, 13, 19 + hx, ky + 1, 1.9, 2.2, 0.60, 0.9]}
	return {"kop": [22 + hx, 22 + hy, 4.4, 5.6],
		"hals": [16, 12, 20 + hx, 15 + hy, 2.8, 3.6, 0.45, 1.1]}

## A flat brim sunk one layer into the head plus a rounded crown, three layers
## high: a cap, not a box.  Rabbit ears are higher than the crown and stick out.
static func hoedje(v: Array, k: Array) -> void:
	var cx: float = k[0]
	var y := JsGetal.vloer(k[1])
	var rx: float = k[2]
	var rz: float = k[3]
	ArtVorm.ell(v, cx, y - 0.2, 7.5, rx + 0.7, 0.9, rz + 0.7, HOED, {"e": 3.0})
	var n0 := v.size()
	ArtVorm.ell(v, cx, y, 7.5, rx - 0.8, 3.2, rz - 0.8, HOED, {"e": 3.0, "ymin": y})
	for i in range(n0, v.size()):
		if v[i]["y"] == y + 1:
			v[i]["k"] = HOED_LINT

## A disc across the neck axis — a ring, not a thicker neck.  `dak` holds the
## highest y of the animal per x-column; the collar never rises above it.
static func ring(v: Array, x0: float, y0: float, x1: float, y1: float, cz: float,
		r: float, rz: float, c: Color, tm: float, halfdik: float, dak: Dictionary) -> void:
	var dx := x1 - x0
	var dy := y1 - y0
	var l := sqrt(dx * dx + dy * dy)
	if l == 0.0:
		l = 1.0
	var ta := tm - halfdik / l
	var tb := tm + halfdik / l
	for x in range(JsGetal.vloer(minf(x0, x1) - r), JsGetal.plafond(maxf(x0, x1) + r) + 1):
		if not dak.is_empty() and not dak.has(x):
			continue
		for y in range(JsGetal.vloer(minf(y0, y1) - r), JsGetal.plafond(maxf(y0, y1) + r) + 1):
			if not dak.is_empty() and y > int(dak[x]):
				continue
			var t := ((x - x0) * dx + (y - y0) * dy) / (l * l)
			if t < ta or t > tb:
				continue
			var qx := x0 + dx * t
			var qy := y0 + dy * t
			var d2 := (x - qx) * (x - qx) + (y - qy) * (y - qy)
			if d2 > r * r:
				continue
			var zr := rz * (0.55 + 0.45 * sqrt(1.0 - d2 / (r * r)))
			for z in range(JsGetal.plafond(cz - zr), JsGetal.vloer(cz + zr) + 1):
				v.append({"x": x, "y": y, "z": z, "k": c})

## The same disc, but repainting EXISTING voxels only, so the scarf always runs
## over the outermost face of chin, neck and chest.  `plafond` keeps the paint
## under the neckline: ears laid along the back stay their own colour.
static func ring_verf(v: Array, x0: float, y0: float, x1: float, y1: float, cz: float,
		r: float, rz: float, c: Color, tm: float, halfdik: float, plafond: float) -> void:
	var dx := x1 - x0
	var dy := y1 - y0
	var l := sqrt(dx * dx + dy * dy)
	if l == 0.0:
		l = 1.0
	var ta := tm - halfdik / l
	var tb := tm + halfdik / l
	for p in v:
		if p["y"] > plafond:
			continue
		var t: float = ((p["x"] - x0) * dx + (p["y"] - y0) * dy) / (l * l)
		if t < ta or t > tb:
			continue
		var qx: float = x0 + dx * t
		var qy: float = y0 + dy * t
		var d2: float = (p["x"] - qx) * (p["x"] - qx) + (p["y"] - qy) * (p["y"] - qy)
		if d2 > r * r:
			continue
		var zr := rz * (0.55 + 0.45 * sqrt(1.0 - d2 / (r * r)))
		if absf(p["z"] - cz) <= zr:
			p["k"] = c

## Where does the model stop in a column, on the viewer's side?  The viewer
## sees the +x, +y and +z faces, so the highest z is the skin facing him.
## Returns [z, lowest y, highest y] of the columns x0..x1, or [] for nothing.
static func huid(v: Array, x0: int, x1: int, y0: int, y1: int) -> Array:
	var z := -(1 << 30)
	var ya := 1 << 30
	var yb := -(1 << 30)
	for p in v:
		if p["x"] < x0 or p["x"] > x1 or p["y"] < y0 or p["y"] > y1:
			continue
		z = maxi(z, p["z"])
		ya = mini(ya, p["y"])
		yb = maxi(yb, p["y"])
	return [] if z == -(1 << 30) else [z, ya, yb]

## The same skin in one pass: per column the highest z.  Key = x * 4096 + y.
static func huid_kaart(v: Array) -> Dictionary:
	var m := {}
	for p in v:
		var k: int = int(p["x"]) * 4096 + int(p["y"])
		if not m.has(k) or p["z"] > m[k]:
			m[k] = p["z"]
	return m

## The lowest point ON SCREEN of the voxels v[van..tot) — the same formula the
## bake uses, so it shows whether something hangs out under the animal.
static func py_max(v: Array, van: int, tot: int) -> float:
	var m := -1e9
	for i in range(van, tot):
		var p: Dictionary = v[i]
		var q: float = (p["x"] + p["z"]) * (ArtVorm.S / 2.0) - (p["y"] + 1) * ArtVorm.HG
		if q > m:
			m = q
	return m

## Per x-column the highest y of the model: the roof the collar stays under.
static func dak_van(v: Array) -> Dictionary:
	var m := {}
	for p in v:
		var x: int = p["x"]
		if not m.has(x) or p["y"] > m[x]:
			m[x] = p["y"]
	return m

## A thick collar around the neck plus a slip hanging over the chest toward the
## viewer, with a white fringe at the bottom.
static func sjaaltje(v: Array, h: Array) -> void:
	var tm: float = h[6]
	var dik: float = h[7]
	var r: float = float(h[4]) + dik
	var rz: float = float(h[5]) + dik
	var x0: float = h[0]
	var y0: float = h[1]
	var x1: float = h[2]
	var y1: float = h[3]
	var dak := dak_van(v)
	var sy := JsGetal.rond(y0)
	var plafond := float(JsGetal.rond(maxf(y0, y1)))
	for x in dak.keys():
		if dak[x] > plafond:
			dak[x] = plafond
	ring_verf(v, x0, y0, x1, y1, 7.5, r + 1.8, rz + 1.8, SJAAL, tm, 1.8, plafond)
	ring(v, x0, y0, x1, y1, 7.5, r + 1.2, rz + 1.2, SJAAL, tm, 2.2, dak)
	# First measure every place, then put them down: otherwise layer 2 measures
	# the slip of layer 1.
	var kaart := huid_kaart(v)
	var lagen: Array = []
	var basis := JsGetal.rond(x0)
	for y in 7:
		var yy := sy - y
		var xm := basis + 2
		while xm > basis - 3:
			if kaart.has(xm * 4096 + yy):
				break
			xm -= 1
		for i in 4:
			var k := (xm - i) * 4096 + yy
			if kaart.has(k):
				lagen.append([xm - i, yy, int(kaart[k]) + 1, SJAAL_FR if y == 6 else SJAAL])
	for l in lagen:
		ArtVorm.bx(v, l[0], l[1], l[2], 1, 1, 2, l[3])

## A ball with a white equator against the chest, fixed to the SKIN of the
## already-posed model, so it stays a round ball even lying in bed.
static func bal(v: Array, h: Array) -> void:
	var sx := JsGetal.rond(h[0])
	var k := huid(v, sx - 2, sx, -(1 << 30), 1 << 30)
	if k.is_empty():
		return
	var r := 2.7
	var cy := JsGetal.rond(k[1] + (k[2] - k[1]) * 0.45)
	var n0 := v.size()
	var onder := py_max(v, 0, n0)
	ArtVorm.ell(v, sx + 1.5, cy, k[0] + 1.4, r, r, r, BAL_KL, {"e": 2.2})
	# The ball may not sink below the animal: lying down it would stick out
	# exactly in the strip where a bed passes.
	var zak := JsGetal.plafond((py_max(v, n0, v.size()) - onder + 1) / float(ArtVorm.HG))
	if zak > 0:
		for i in range(n0, v.size()):
			v[i]["y"] = int(v[i]["y"]) + zak
		cy += zak
	for i in range(n0, v.size()):
		if v[i]["y"] == cy:
			v[i]["k"] = BAL_BAND

## The fixed order turns a list into one cache key; unknown names drop out.
static func acc_sleutel(lijst) -> String:
	if lijst == null:
		return ""
	var lst: Array = []
	if typeof(lijst) == TYPE_STRING:
		if (lijst as String).is_empty():
			return ""
		lst = Array((lijst as String).split(","))
	elif typeof(lijst) == TYPE_ARRAY or typeof(lijst) == TYPE_PACKED_STRING_ARRAY:
		lst = Array(lijst)
	else:
		return ""
	var uit: Array[String] = []
	for naam in ACC_NAMEN:
		if lst.has(naam):
			uit.append(naam)
	return ",".join(uit)

## The finished voxel list of one guest: species, pose and outfit.
static func bouw(kind: String, pose: String, sleutel: String) -> Array:
	var p: Dictionary = pose_van(pose)
	var v := soort(kind, p)
	var buk := float(p.get("buk", 0))
	var acc := sleutel.split(",") if not sleutel.is_empty() else PackedStringArray()
	if acc.is_empty():
		if p["lig"]:
			return liggen(v)
		if p["zit"]:
			return zitten(v)
		return bukken(v, buk) if buk > 0.0 else v
	var a := ankers(kind, p)
	if acc.has("sjaaltje"):
		sjaaltje(v, a["hals"])
	if acc.has("hoedje"):
		hoedje(v, a["kop"])
	# Hat and scarf sit on the animal and sink with the pose; the ball goes on
	# AFTER, against the skin of the already-squashed model.
	if p["lig"]:
		v = liggen(v)
	elif p["zit"]:
		v = zitten(v)
	elif buk > 0.0:
		v = bukken(v, buk)
	if acc.has("bal"):
		bal(v, a["hals"])
	return v

# ------------------------------------------------------------------- voerbakje

## The round dish around (KOM_CX, KOM_CZ).  `groot` is the world size; the card
## size is the small one.  Voxels of the FRONT wall carry `voor = 1`: they are
## drawn after the animal, so it can bite into the bowl.
static func kom_vox(niv: int, groot: bool) -> Array:
	var v: Array = []
	var cel: Array = []
	var R := 6.3 if groot else KOM_R
	var HH := 6 if groot else KOM_H
	var BOD := 3 if groot else 2
	var grens := (KOM_CX + KOM_CZ + R * 0.72) if groot else float(KOM_VOOR)
	var x0 := JsGetal.vloer(KOM_CX - R)
	var x1 := JsGetal.plafond(KOM_CX + R)
	var z0 := JsGetal.vloer(KOM_CZ - R)
	var z1 := JsGetal.plafond(KOM_CZ + R)
	var tel := 0
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			var q := pow(absf((x - KOM_CX) / R), 2.5) + pow(absf((z - KOM_CZ) / R), 2.5)
			if q > 1.0:
				continue
			var mid := q < (0.36 if groot else 0.30)
			var voor := 1 if (not mid and (x + z) >= grens) else 0
			if mid:
				ArtVorm.bx(v, x, 0, z, 1, BOD, 1, KOM["schaal"])
				cel.append([x, z, q, tel])
				tel += 1
			else:
				ArtVorm.bx(v, x, 0, z, 1, HH, 1, KOM["schaal"])
				ArtVorm.verf(v, x, x, HH - 1, HH - 1, z, z, KOM["rand"])
				if voor == 1:
					for i in range(v.size() - HH, v.size()):
						v[i]["voor"] = 1
	# kibble: fill from the centre outward (a stable sort, as in the browser)
	cel.sort_custom(func(a, b): return a[2] < b[2] if a[2] != b[2] else a[3] < b[3])
	var trap := [0, 10, 21, 34, 50] if groot else [0, 3, 6, 10, 15]
	var n: int = trap[niv] if niv >= 0 and niv < trap.size() else 0
	var j := 0
	while j < n and j < cel.size() * 2:
		var c: Array = cel[j % cel.size()]
		var laag := BOD + (0 if j < cel.size() else 1)
		v.append({"x": c[0], "y": laag, "z": c[1],
			"k": KOM["brok2"] if j % 3 == 2 else KOM["brok"]})
		j += 1
	return v

## `Art.niveau(aantal, per)` — how full the bowl looks, 0..4.
static func niveau(aantal: int, per: int) -> int:
	if aantal == 0:
		return 0
	var f := float(aantal) / float(per) if per > 0 else 1.0
	return maxi(1, mini(4, JsGetal.plafond(f * 4.0)))
