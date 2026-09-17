class_name ArtVloer
extends RefCounted
## The colour of one floor tile (art-sound-rules.md §2.3).
##
## OWNERSHIP.  There is exactly one floor renderer: `scenes/vloer.gd` builds the
## floor and both back walls as an `ArrayMesh` with per-vertex colours (W1).
## This file is only the colour table it reads, so the speckle of a garden or a
## pool comes out of one authority and is identical voxel for voxel to the HTML.
## `Art.vloer_plaat()` — a second, baked floor — existed briefly and was deleted
## again: a 3-megapixel plate per room next to a mesh that does the same thing
## is not a fallback, it is a fork.
##
## `kleur()` takes a room record and reads it with `Object.get()` semantics, so
## a `Rooms.Kamer` goes straight in — no conversion, no copy:
##
##   Rooms.vloer_kleur(r, x, z)  ->  ArtVloer.kleur(r, x, z)
##
## The fields it reads: `vloer` (hout | tegel | zacht | loper | gras), `d`,
## `matten` and `bad` ({x0, x1, z0, z1}).  `matten` is a Dictionary
## ({x0, x1, z0, z1, kl: [Color, Color]}) — ONE mat per room, as `Rooms.Kamer`
## declares it — but an Array of those Dictionaries is accepted as well, because
## the HTML has a list and a later room may want two.  An empty one is no mat.

const PLANK := [Color("#E4CBA6"), Color("#DCC29B")]
const PLANK_D := Color("#D2B58C")
const TEGEL := [Color("#EDE6DA"), Color("#D9E6E2")]
const ZACHT := [Color("#E6D3B8"), Color("#DFC9AC")]
const LOPER := [Color("#E9DCC6"), Color("#E2D3BA")]
const LOPER_M := [Color("#D68FA0"), Color("#CE8496")]
const GRAS := [Color("#AFD595"), Color("#AAD190"), Color("#B4D89A"), Color("#ACD392")]
const WEI := [Color("#9DC486"), Color("#98C081")]
const BADWATER := [Color("#9CD1E4"), Color("#A9D8E6"), Color("#93CBE0"), Color("#A2D4E5")]
const BADKANT := [Color("#5AA3C2"), Color("#66ABC8")]
const BADRAND := [Color("#FFFDF3"), Color("#FCF8EA")]
const HEK_X := 10          ## inside the fence the meadow becomes garden grass
const HEK_Z := 10
const DEK := 16            ## the tiled deck round an outdoor pool, in voxels

## Read one field from a `Rooms.Kamer` or from a plain Dictionary.
static func _veld(r, naam: String, terug):
	if r == null:
		return terug
	if r is Dictionary:
		return r.get(naam, terug)
	var v = r.get(naam)
	return terug if v == null else v

## One mat, a list of mats or nothing at all -> a list of mats.
static func _matten(v) -> Array:
	if v is Array:
		return v
	if v is Dictionary and not (v as Dictionary).is_empty():
		return [v]
	return []

## The colour of the floor tile at (x, z).  A mat wins over everything, then the
## garden, then the pool, then the room's own floor pattern.  `hash2` is the
## stable per-tile hash of rooms.js — reproduce it exactly or the speckle moves.
static func kleur(r, x: int, z: int) -> Color:
	var k := Sommen.hash2(x, z)
	for mat in _matten(_veld(r, "matten", {})):
		if x >= int(mat["x0"]) and x < int(mat["x1"]) \
				and z >= int(mat["z0"]) and z < int(mat["z1"]):
			return mat["kl"][k & 1]
	var soort := str(_veld(r, "vloer", "hout"))
	# the fence line is per room: the garden keeps HEK_X/HEK_Z, the pool stands
	# further off its fence (owner, 2026-09-17: "Doe het hek verder van beide
	# kanten van het zwembad")
	var hek_x := int(_veld(r, "hek_x", HEK_X))
	var hek_z := int(_veld(r, "hek_z", HEK_Z))
	# the water first: a pool on a lawn (the outdoor pool) keeps its water, its
	# rim and a tiled deck of DEK voxels round it
	var bad = _veld(r, "bad", {})
	if bad is Dictionary and not (bad as Dictionary).is_empty():
		var x0 := int(bad["x0"])
		var x1 := int(bad["x1"])
		var z0 := int(bad["z0"])
		var z1 := int(bad["z1"])
		if x >= x0 and x < x1 and z >= z0 and z < z1:
			if x < x0 + 4 or x >= x1 - 4 or z < z0 + 4 or z >= z1 - 4:
				return BADKANT[k & 1]
			return BADWATER[k & 3]
		if x >= x0 - 4 and x < x1 + 4 and z >= z0 - 4 and z < z1 + 4:
			return BADRAND[((x >> 2) + (z >> 2)) & 1]
		if soort == "gras" and x >= x0 - DEK and x < x1 + DEK and z >= z0 - DEK and z < z1 + DEK \
				and x >= hek_x and z >= hek_z:
			return TEGEL[((x >> 2) + (z >> 2)) & 1]
	if soort == "gras":
		if x < hek_x or z < hek_z:
			return WEI[k & 1]
		return GRAS[k & 3]
	if soort == "tegel":
		return TEGEL[((x >> 2) + (z >> 2)) & 1]
	if soort == "loper":
		if z >= 8 and z < int(_veld(r, "d", 0)) - 6:
			return LOPER_M[(x >> 2) & 1]
		return LOPER[k & 1]
	if soort == "zacht":
		return ZACHT[(z >> 2) & 1]
	return PLANK_D if ((z >> 2) & 3) == 0 else PLANK[(z >> 2) & 1]
