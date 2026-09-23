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
## `matten`, `bad` ({x0, x1, z0, z1}), the fence line `hek_x`/`hek_z`, and on a
## lawn `gevel` (its paved `stoep`) and `uitzicht` (a pool beyond the fence).  `matten` is a Dictionary
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
## The paved strip along the hotel's back wall in the garden (owner,
## 2026-09-23): warm stone slabs, so the wall stands on something.
const STOEP := [Color("#E8DAC4"), Color("#DDCDB5")]
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
		# the stone strip along a building wall on the lawn — the hotel's back
		# wall in the garden — inside the fence
		var gevel = _veld(r, "gevel", {})
		if gevel is Dictionary and not (gevel as Dictionary).is_empty():
			var stoep := int(gevel.get("stoep", 0))
			var langs_x := str(gevel.get("wand", "")) == "x"
			var af := x if langs_x else z
			var binnen := z >= hek_z if langs_x else x >= hek_x
			if af >= 0 and af < stoep and binnen:
				return STOEP[((x >> 2) + (z >> 2)) & 1]
		# what lies beyond the fence and can be seen from here: the pool behind
		# the garden (owner, 2026-09-23: "Het zwembad vanuit de tuin gezien is
		# niet duidelijk dat lijkt gewoon op een huis")
		for zicht in _veld(r, "uitzicht", []):
			if zicht is Dictionary and str(zicht.get("soort", "")) == "bad":
				var kl = _bad_buiten(zicht, x, z, k, hek_x, hek_z)
				if kl != null:
					return kl
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

## A pool seen beyond the fence (`Kamer.uitzicht`): the same water, dark edge
## and white rim as the pool room's own `bad`, and a tiled deck of DEK voxels
## round it that stops at the fence — inside the fence the lawn is the room's
## own.  `null` when (x, z) is not part of it.
static func _bad_buiten(b: Dictionary, x: int, z: int, k: int, hek_x: int, hek_z: int):
	var x0 := int(b["x0"])
	var x1 := int(b["x1"])
	var z0 := int(b["z0"])
	var z1 := int(b["z1"])
	if x >= x0 and x < x1 and z >= z0 and z < z1:
		if x < x0 + 4 or x >= x1 - 4 or z < z0 + 4 or z >= z1 - 4:
			return BADKANT[k & 1]
		return BADWATER[k & 3]
	if x >= x0 - 4 and x < x1 + 4 and z >= z0 - 4 and z < z1 + 4:
		return BADRAND[((x >> 2) + (z >> 2)) & 1]
	var dek := int(b.get("dek", DEK))
	if x >= x0 - dek and x < x1 + dek and z >= z0 - dek and z < z1 + dek \
			and (x < hek_x or z < hek_z):
		return TEGEL[((x >> 2) + (z >> 2)) & 1]
	return null
