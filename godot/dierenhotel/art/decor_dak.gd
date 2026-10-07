extends RefCounted
class_name ArtDecorDak

## Dakterras-decor (U3, 2026-10-07): telescoop, reling, ligstoel en lampjes.
## Eigen namen en een eigen tabel, zoals ArtDecorSpeelzaal; de basis-NAMEN
## van ArtDecor blijven ongemoeid.  Aangemeld bij `ArtDecor._extra()`
## (integratie I1a, 2026-10-07); `Rooms.get_kamer("dakterras").decor` is een
## kopie van `PLAATSING`.  `games/sterren/test_sterren.gd` bakt elk model los.
##
## Voxels zijn `{x, y, z, k}` zoals `games/_voorbeeld/spel.gd::_blok`; de
## helper `_bx` legt een balk neer.  Nacht: koele kleuren, de lampjes warm.

const HOUT := Color("#C89A5E")
const HOUT_D := Color("#A6783F")
const METAAL := Color("#5C6470")
const METAAL_L := Color("#8A93A0")
const KOPER := Color("#D9A441")
const DOEK := Color("#5FA8E0")
const DOEK_L := Color("#EAF4FB")
const DRAAD := Color("#2E3340")
const LAMP := [Color("#FFD166"), Color("#FF7B9C"), Color("#7BE0AD"), Color("#9AD0FF")]

const NAMEN: Array[String] = ["telescoop", "reling", "ligstoel", "lampjes"]

## Where the pieces go on the deck (`Rooms` decor entries) — the dakterras
## room takes a copy of this list as its decor.  The telescope stands in
## zone `sterren` (x 70..104, z 70..96) at the front-right edge; the chairs
## face the sky on the left; the lights hang on the stairhouse wall (z 0).
const PLAATSING: Array = [
	{"n": "telescoop", "x": 90, "z": 86},
	{"n": "ligstoel", "x": 30, "z": 72},
	{"n": "ligstoel", "x": 52, "z": 72},
	{"n": "lampjes", "x": 20, "z": 1, "y": 44, "ver": true},
	{"n": "reling", "x": 86, "z": 2},
]

static func _bx(v: Array, x0: int, y0: int, z0: int, w: int, h: int, d: int, k: Color) -> void:
	for x in range(x0, x0 + w):
		for y in range(y0, y0 + h):
			for z in range(z0, z0 + d):
				v.append({"x": x, "y": y, "z": z, "k": k})

## Telescoop: a tripod of three dark legs, a brass collar and a tube that
## points up and away over the railing (one voxel higher per two forward).
static func telescoop(_p := {}) -> Array:
	var v: Array = []
	for been in [[0, 0], [8, 0], [4, 7]]:
		for i in 12:
			var t := float(i) / 11.0
			var x := int(round(lerpf(float(been[0]), 4.0, t)))
			var z := int(round(lerpf(float(been[1]), 3.0, t)))
			_bx(v, x, i, z, 1, 1, 1, METAAL)
	_bx(v, 3, 12, 2, 3, 2, 3, KOPER)
	for i in 10:
		var y := 13 + i / 2
		_bx(v, 3, y, 4 + i, 3, 3, 1, METAAL_L if i % 4 < 2 else METAAL)
	_bx(v, 2, 17, 13, 5, 4, 1, KOPER)
	return v

## Reling: posts every six voxels along x with two rails, `lang` voxels.
static func reling(p := {}) -> Array:
	var lang: int = int(p.get("lang", 24))
	var v: Array = []
	for x in range(0, lang, 6):
		_bx(v, x, 0, 0, 1, 10, 1, METAAL)
	_bx(v, 0, 5, 0, lang, 1, 1, METAAL_L)
	_bx(v, 0, 9, 0, lang, 1, 1, HOUT)
	return v

## Ligstoel: a wooden frame low at the front, high at the back, with blue and
## white striped canvas.
static func ligstoel(_p := {}) -> Array:
	var v: Array = []
	for z in [0, 15]:
		_bx(v, 0, 0, z, 1, 3, 1, HOUT_D)
		_bx(v, 9, 0, z, 1, 3, 1, HOUT_D)
	_bx(v, 0, 2, 0, 1, 1, 16, HOUT)
	_bx(v, 9, 2, 0, 1, 1, 16, HOUT)
	for z in range(1, 10):
		_bx(v, 1, 3, z, 8, 1, 1, DOEK if z % 2 == 0 else DOEK_L)
	for i in 7:
		var z := 10 + i
		var y := 3 + i
		_bx(v, 1, y, z, 8, 1, 1, DOEK if i % 2 == 0 else DOEK_L)
	_bx(v, 0, 3, 15, 1, 8, 1, HOUT_D)
	_bx(v, 9, 3, 15, 1, 8, 1, HOUT_D)
	return v

## Lampjes: a sagging wire along x with a coloured bulb every four voxels.
static func lampjes(p := {}) -> Array:
	var lang: int = int(p.get("lang", 40))
	var v: Array = []
	for x in lang:
		var t := float(x) / float(maxi(1, lang - 1))
		var zak := int(round(4.0 * sin(PI * t)))
		_bx(v, x, 6 - zak, 0, 1, 1, 1, DRAAD)
		if x % 4 == 2:
			_bx(v, x, 4 - zak, 0, 1, 2, 1, LAMP[(x / 4) % LAMP.size()])
	return v

static func tabel() -> Dictionary:
	return {
		"telescoop": Callable(ArtDecorDak, "telescoop"),
		"reling": Callable(ArtDecorDak, "reling"),
		"ligstoel": Callable(ArtDecorDak, "ligstoel"),
		"lampjes": Callable(ArtDecorDak, "lampjes"),
	}
