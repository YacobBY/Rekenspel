extends RefCounted
class_name ArtDecorDak

## Het dakterras (U3, 2026-10-07; eigenaar: "Verzin nog vier kamers met
## activiteiten"): de modellen van het spel Sterren tellen (`games/sterren`).
##
## Aangemeld bij `ArtDecor._extra()` (integratie I1a, 2026-10-07): `Art` kent
## `telescoop` en `ligstoel` als wereldmodellen, met hun pixel-goudplaten, maar
## geen kamer zet ze als vast decor.  Het spel meldt de telescoop zelf nog eens
## aan via `definitie().modellen` als `sterren_telescoop`
## (`games/sterren/spel.gd`), zoals de kas zijn tafel en de speelzaal zijn
## ezel; die staat als RUSTSPUL op het dak (`definitie().rust`), dus de knop van
## het spel hangt aan de telescoop.  De reling, het trappenhuis en de lampjes
## zijn geen modellen: die tekent de vloer (`scenes/vloer.gd`, `Kamer.nacht`;
## integratie I1b: `reling`, `lampjes` en `PLAATSING` zijn weg).
##
## Voxels zijn `{x, y, z, k}` (`ArtVorm`), het anker midden onder de voet.

const HOUT := Color("#C89A5E")
const HOUT_D := Color("#A6783F")
const METAAL := Color("#5C6470")
const METAAL_L := Color("#8A93A0")
const KOPER := Color("#E3B04B")
const BUIS := Color("#4F86D9")        ## the tube: a friendly blue, like a child's telescope
const BUIS_L := Color("#EEF4FB")      ## the dew cap at the open end
const OOG := Color("#2E3340")         ## the eyepiece and the lens
const STER := Color("#FFD23F")        ## the little star on the tube
const DOEK := Color("#5FA8E0")
const DOEK_L := Color("#EAF4FB")

const NAMEN: Array[String] = ["telescoop", "ligstoel"]

## Where the tube points: up, and back over the deck to the left — on screen
## almost straight up and a little to the left, at the sky over the railing.
const RICHTING := Vector3(-0.85, 0.5, -0.2)
const KOP := Vector3(0.5, 15.0, 0.5)  ## the top of the tripod, where the tube is held

## A rod of voxels from `a` to `b` (voxel corners), `r` thick round its axis,
## flat at both ends; `kl(t)` colours a voxel by where it lies along it (0..1).
static func _staaf(v: Array, a: Vector3, b: Vector3, r: float, kl: Callable) -> void:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z)) - Vector3.ONE * (r + 1.0)
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z)) + Vector3.ONE * (r + 1.0)
	for x in range(int(floor(lo.x)), int(ceil(hi.x)) + 1):
		for y in range(maxi(0, int(floor(lo.y))), int(ceil(hi.y)) + 1):
			for z in range(int(floor(lo.z)), int(ceil(hi.z)) + 1):
				var q := Vector3(x + 0.5, y + 0.5, z + 0.5)
				var t := (q - a).dot(ab) / l2
				if t < 0.0 or t > 1.0:
					continue
				if (q - (a + ab * t)).length() <= r:
					v.append({"x": x, "y": y, "z": z, "k": kl.call(t)})

## De telescoop: a tripod of three dark legs, a brass head, and on it a blue
## tube with brass rings, a white dew cap at the open end (up, at the sky) and a
## dark eyepiece at the low end, where an animal looks in; a little gold star
## on the tube says what it is for.  About 9 voxels wide on the floor and taller
## than a guest, so the entry button that hangs on it has something to hang on.
static func telescoop(_p := {}) -> Array:
	var v: Array = []
	var poot := func(_t: float) -> Color: return METAAL
	for voet in [Vector3(-5.5, 0.0, -3.5), Vector3(5.5, 0.0, -4.5), Vector3(0.5, 0.0, 6.5)]:
		_staaf(v, voet, KOP, 0.75, poot)
	ArtVorm.bx(v, -1, 13, -1, 4, 3, 4, KOPER)
	var r := RICHTING.normalized()
	var mid := KOP + Vector3(0.0, 3.0, 0.0)
	var a := mid - r * 8.0
	var b := mid + r * 15.0
	var buis := func(t: float) -> Color:
		if t < 0.06:
			return OOG
		if t > 0.86:
			return BUIS_L
		if (t > 0.3 and t < 0.38) or (t > 0.8 and t < 0.86):
			return KOPER
		return BUIS
	_staaf(v, a, b, 2.4, buis)
	# the eyepiece: a short dark stub on the low end, angled up towards the eye
	_staaf(v, a + Vector3(0.0, 1.5, 0.0), a + Vector3(0.6, 4.5, 0.3), 0.9,
		func(_t: float) -> Color: return OOG)
	# the finder: a thin tube on top, parallel to the big one
	var boven := Vector3(0.0, 2.6, 0.0)
	_staaf(v, mid + boven - r * 2.0, mid + boven + r * 6.0, 0.8,
		func(t: float) -> Color: return KOPER if t < 0.15 or t > 0.85 else METAAL_L)
	# a little gold star on the side of the tube that faces the room
	var s := mid + r * 3.0 + Vector3(0.0, 0.0, 2.6)
	for d in [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
			Vector3i(0, -1, 0)]:
		v.append({"x": int(round(s.x)) + d.x, "y": int(round(s.y)) + d.y,
			"z": int(round(s.z)) + d.z, "k": STER})
	return v

## Ligstoel: a wooden frame low at the front, high at the back, with blue and
## white striped canvas — a chair to lie in and look at the stars.
static func ligstoel(_p := {}) -> Array:
	var v: Array = []
	for z in [0, 15]:
		ArtVorm.bx(v, 0, 0, z, 1, 3, 1, HOUT_D)
		ArtVorm.bx(v, 9, 0, z, 1, 3, 1, HOUT_D)
	ArtVorm.bx(v, 0, 2, 0, 1, 1, 16, HOUT)
	ArtVorm.bx(v, 9, 2, 0, 1, 1, 16, HOUT)
	for z in range(1, 10):
		ArtVorm.bx(v, 1, 3, z, 8, 1, 1, DOEK if z % 2 == 0 else DOEK_L)
	for i in 7:
		ArtVorm.bx(v, 1, 3 + i, 10 + i, 8, 1, 1, DOEK if i % 2 == 0 else DOEK_L)
	ArtVorm.bx(v, 0, 3, 15, 1, 8, 1, HOUT_D)
	ArtVorm.bx(v, 9, 3, 15, 1, 8, 1, HOUT_D)
	return v

static func tabel() -> Dictionary:
	return {
		"telescoop": Callable(ArtDecorDak, "telescoop"),
		"ligstoel": Callable(ArtDecorDak, "ligstoel"),
	}
