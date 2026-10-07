extends RefCounted
class_name ArtDecorPost

## De postkamer 💌 (U4, 2026-10-07; owner: "Verzin nog vier kamers met
## activiteiten").  Een klein kamertje achter de lobby: de VAKKENKAST met vier
## genummerde vakjes langs de achterwand (de getallenlijn van het spel), de
## POSTKAR met de brieven van de dag, de PAKKETWEEGSCHAAL en de ZEGELBALIE
## langs de linkerwand.  Zelfde bouwstenen en palet als de rest van het hotel
## (art-sound-rules.md §8); een voxel is {x, y, z, k}, y omhoog.
##
## Aangemeld bij `ArtDecor._extra()` (integratie I1a, 2026-10-07): de vier
## namen zijn wereldmodellen, en `vakkenkast`, `zegelbalie` en
## `pakketweegschaal` staan als vast decor in de postkamer (`rooms.gd`).  Het
## spel registreert daarnaast nog zijn eigen `post_vakkenkast`/`post_postkar`
## (`Art.registreer_model`) voor de beurt.
##
## Elk model staat, zoals elk decormodel van het hotel, MIDDEN op zijn eigen
## punt (x en z rond 0, y vanaf de vloer): een kast op (40, 8) staat met zijn
## midden daar (`_midden`).

const HOUT := Color("#B8864E")
const HOUT_D := Color("#8E6436")
const HOUT_L := Color("#D9AC74")
const PAPIER := Color("#F7F1E3")
const ROOD := Color("#D9534F")
const METAAL := Color("#9AA3AD")
const METAAL_L := Color("#C9D1D9")
const ZWART := Color("#3B3B3B")

const NAMEN: Array[String] = ["vakkenkast", "postkar", "pakketweegschaal", "zegelbalie"]

## Shift a model built from its corner (x, z from 0) so its footprint is centred
## on its own point, like every decor model (`ArtDecor`: "anchored at (0,0,0)
## on the floor"); `Rooms.voet` and the bake read the voxels as they are.
static func _midden(v: Array) -> Array:
	if v.is_empty():
		return v
	var x0 := 1 << 30
	var x1 := -(1 << 30)
	var z0 := 1 << 30
	var z1 := -(1 << 30)
	for p in v:
		x0 = mini(x0, int(p["x"]))
		x1 = maxi(x1, int(p["x"]))
		z0 = mini(z0, int(p["z"]))
		z1 = maxi(z1, int(p["z"]))
	var dx := x0 + ((x1 - x0 + 1) >> 1)
	var dz := z0 + ((z1 - z0 + 1) >> 1)
	for p in v:
		p["x"] = int(p["x"]) - dx
		p["z"] = int(p["z"]) - dz
	return v

## The sorting shelf: 4 holes of 14 voxels, a back wall, a plank between them,
## an empty plate strip above every hole (the number itself is the game's
## `getal_tag`/card, so the model never has to draw digits).
## params: {platen: [String] (unused by the voxels, kept for the probe), vol: [int] letters per hole}
static func vakkenkast(params := {}) -> Array:
	var v: Array = []
	var vol: Array = params.get("vol", [])
	var breed := 4 * 14 + 5 * 2        # 66
	var hoog := 26
	var diep := 10
	# back wall
	for x in breed:
		for y in hoog:
			v.append({"x": x, "y": y, "z": 0, "k": HOUT_D})
	# bottom, top and the three dividers + two sides
	for x in breed:
		for z in diep:
			v.append({"x": x, "y": 0, "z": z, "k": HOUT})
			v.append({"x": x, "y": hoog - 1, "z": z, "k": HOUT_L})
	for j in 5:
		var sx := j * 16
		for y in hoog:
			for z in diep:
				v.append({"x": sx, "y": y, "z": z, "k": HOUT})
				v.append({"x": sx + 1, "y": y, "z": z, "k": HOUT})
	# the plate strip above each hole, and the letters already sorted into it
	for j in 4:
		var x0 := j * 16 + 2
		for x in range(x0, x0 + 14):
			v.append({"x": x, "y": hoog - 3, "z": diep, "k": PAPIER})
			v.append({"x": x, "y": hoog - 4, "z": diep, "k": PAPIER})
		var n := int(vol[j]) if j < vol.size() else 0
		for b in mini(n, 6):
			for x in range(x0 + 2, x0 + 12):
				for y in range(1, 9):
					v.append({"x": x, "y": y, "z": 2 + b, "k": PAPIER})
	return _midden(v)

## The mail cart: a wooden box on four wheels with a stack of white letters.
## params: {brieven: int} — the pile's height follows what is still to sort.
static func postkar(params := {}) -> Array:
	var v: Array = []
	var n := int(params.get("brieven", 0))
	var breed := 20
	var diep := 14
	# wheels
	for wx in [2, breed - 3]:
		for wz in [1, diep - 2]:
			for y in 3:
				v.append({"x": wx, "y": y, "z": wz, "k": ZWART})
	# the box
	for x in breed:
		for z in diep:
			v.append({"x": x, "y": 3, "z": z, "k": HOUT_D})
			for y in range(4, 10):
				if x == 0 or x == breed - 1 or z == 0 or z == diep - 1:
					v.append({"x": x, "y": y, "z": z, "k": HOUT})
	# handle
	for y in range(10, 16):
		v.append({"x": breed - 1, "y": y, "z": 2, "k": METAAL})
		v.append({"x": breed - 1, "y": y, "z": diep - 3, "k": METAAL})
	for z in range(2, diep - 2):
		v.append({"x": breed - 1, "y": 15, "z": z, "k": METAAL_L})
	# the letters: one slab per letter, with a red stamp dot
	for b in mini(n, 6):
		for x in range(3, breed - 3):
			for z in range(2, diep - 2):
				v.append({"x": x, "y": 4 + b, "z": z, "k": PAPIER})
		v.append({"x": breed - 5, "y": 4 + b, "z": 3, "k": ROOD})
	return _midden(v)

## The parcel scale: a grey platform on a column with a round dial.
static func pakketweegschaal(_params := {}) -> Array:
	var v: Array = []
	for x in 12:
		for z in 12:
			v.append({"x": x, "y": 0, "z": z, "k": METAAL})
			v.append({"x": x, "y": 6, "z": z, "k": METAAL_L})
	for y in range(1, 6):
		for x in range(4, 8):
			for z in range(4, 8):
				v.append({"x": x, "y": y, "z": z, "k": METAAL})
	for y in range(7, 16):
		for x in range(5, 7):
			v.append({"x": x, "y": y, "z": 0, "k": METAAL})
	for x in range(2, 10):
		for y in range(12, 20):
			if (x - 6) * (x - 6) + (y - 16) * (y - 16) <= 16:
				v.append({"x": x, "y": y, "z": 0, "k": PAPIER})
	return _midden(v)

## The stamp counter: a short wooden counter with a sheet of stamps on it.
static func zegelbalie(_params := {}) -> Array:
	var v: Array = []
	for x in 14:
		for z in 28:
			for y in 12:
				if y == 11 or x == 0 or x == 13 or z == 0 or z == 27:
					v.append({"x": x, "y": y, "z": z, "k": HOUT if y < 11 else HOUT_L})
	for x in range(3, 11):
		for z in range(6, 22):
			v.append({"x": x, "y": 12, "z": z, "k": PAPIER})
			if (x + z) % 4 == 0:
				v.append({"x": x, "y": 13, "z": z, "k": ROOD})
	return _midden(v)

static func tabel() -> Dictionary:
	return {
		"vakkenkast": Callable(ArtDecorPost, "vakkenkast"),
		"postkar": Callable(ArtDecorPost, "postkar"),
		"pakketweegschaal": Callable(ArtDecorPost, "pakketweegschaal"),
		"zegelbalie": Callable(ArtDecorPost, "zegelbalie"),
	}
