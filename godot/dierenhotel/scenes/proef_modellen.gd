extends RefCounted
## Placeholder voxel models for the vertical slice, so the skeleton can prove
## the baker, the plate cache, the anchor maths and the y-sorting WITHOUT
## porting any real world content.
##
## W1 deletes this file together with the placeholder room `proefkamer`
## (Rooms._bouw_proefkamer) and rewrites the two assertions in
## tests/test_skelet.gd that name them.  Nothing else refers to them.

func registreer() -> void:
	Art.registreer_wereldmodel("proef_dier", dier)
	Art.registreer_wereldmodel("proef_blok", blok)

## A four-legged block animal, anchored at (8, 5) — the middle of its paws.
func dier(params: Dictionary) -> Array:
	var kl: Color = params.get("kleur", Color("#EEC194"))
	var donker: Color = params.get("donker", Color("#D3996A"))
	var oog := Color("#5B4840")
	var v: Array = []
	for x in range(0, 14):
		for y in range(4, 9):
			for z in range(2, 8):
				v.append({"x": x, "y": y, "z": z, "k": kl})
	for p in [[1, 2], [1, 6], [11, 2], [11, 6]]:
		for y in range(0, 4):
			for dz in 2:
				v.append({"x": p[0], "y": y, "z": p[1] + dz, "k": donker})
	for x in range(13, 18):
		for y in range(7, 12):
			for z in range(3, 7):
				v.append({"x": x, "y": y, "z": z, "k": kl})
	v.append({"x": 17, "y": 10, "z": 3, "k": oog})
	v.append({"x": 17, "y": 10, "z": 6, "k": oog})
	return v

## An n x n x n cube; `n` and `kleur` are parameters, so it also proves that a
## parameterised model gets its own plate.
func blok(params: Dictionary) -> Array:
	var kl: Color = params.get("kleur", Color("#D0A87A"))
	var n: int = params.get("n", 4)
	var v: Array = []
	for x in n:
		for y in n:
			for z in n:
				v.append({"x": x, "y": y, "z": z, "k": kl})
	return v
