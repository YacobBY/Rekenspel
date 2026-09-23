extends RefCounted
## The voxel models of `weeg` (games-c.md §3.4): the big market balance with two
## pans, the weights, and the three things that are weighed.
##
## What lies on the pans is part of the balance's OWN model (`params.l`, `.r`),
## for the same reason the punnets are part of the picking table: loose decor
## sorts on its floor point, so a weight on the back of a pan would be drawn
## under the pan.  One model, one plate.
##
## The beam runs along the screen's horizontal, the line x + z = const: the
## left pan (the thing being weighed) stands at (−ARM, +ARM) and the right pan
## (the weights) at (+ARM, −ARM), so the tilt reads on every screen.  The
## weights on the right pan are STACKED, in the order they were put down: side
## by side five of them would not fit on a pan, and a tower of coloured blocks
## reads at a glance.  Anchor (0,0,0) on the floor under the pivot.

const HOUT := ArtDecor.HOUT
const HOUT_D := ArtDecor.HOUT_D
const HOUT_L := ArtDecor.HOUT_L
const METAAL := ArtDecor.METAAL
const METAAL_L := ArtDecor.METAAL_L
const GOUD := ArtDecor.GOUD
const GOUD_D := ArtDecor.GOUD_D
const PAN := Color("#E9EDF3")        ## a pan: light tin
const PAN_D := Color("#C4CAD6")
const RECHT := Color("#8CC08A")      ## the pivot's lamp when the beam is level
const SCHEEF := Color("#C9CCDC")     ## ... and when it is not: plain grey, never red

## Weights by size and colour (games-c.md §3.4): [width, height] in voxels.
const GEWICHT_KL := {1: Color("#F2C14E"), 2: Color("#8CC08A"), 5: Color("#6FA3CC"),
	10: Color("#F19FB5"), 20: Color("#B58FD1")}
const GEWICHT_MAAT := {1: [3, 2], 2: [4, 3], 5: [5, 4], 10: [6, 5], 20: [7, 6]}

const POMPOEN := Color("#F29A4A")
const POMPOEN_D := Color("#DE8338")
const STEEL := Color("#7A5A3A")
const MELOEN := Color("#79B56A")
const MELOEN_D := Color("#4E8C4A")
const JUTE := Color("#C8A675")
const JUTE_D := Color("#AE8C5C")
const AARDAPPEL := Color("#D9B27A")

const ARM := 14            ## the pans stand this far along x and z from the pivot
const PAN_R := 8.0         ## pan radius (in x and z)
const PAN_Y := 16          ## pan height when the beam is level
const HELLING := 3         ## voxels a pan moves up or down per step of `kant`

## Name -> builder.
static func tabel() -> Dictionary:
	return {"weeg_schaal": schaal, "weeg_gewicht": gewicht}

## How high the top of a pan stands for this tilt.  `kant` < 0: the left side
## (the thing) is down; > 0: the right side (the weights) is down; 0: level.
static func pan_hoog(links: bool, kant: int) -> int:
	var k := clampi(kant, -2, 2)
	return PAN_Y + (k if links else -k) * HELLING

static func plek_links() -> Vector2i:
	return Vector2i(-ARM, ARM)

static func plek_rechts() -> Vector2i:
	return Vector2i(ARM, -ARM)

## How tall a stack of these weights is, in voxels.
static func stapel_hoog(lijst: Array) -> int:
	var h := 0
	for kg in lijst:
		h += int((GEWICHT_MAAT.get(int(kg), [3, 2]) as Array)[1])
	return h

## The balance.  `params.kant` −2..2, `params.l` what lies on the left pan
## ("pompoen" | "meloen" | "zak" | ""), `params.lm` its size 0..2, `params.r`
## the weights on the right pan, bottom first.
static func schaal(params: Dictionary = {}) -> Array:
	var v: Array = []
	var kant := clampi(int(params.get("kant", 0)), -2, 2)
	# the stand: a wooden plinth, a thick tin column and the pivot's lamp
	ArtVorm.bx(v, -6, 0, -6, 12, 3, 12, HOUT)
	ArtVorm.verf(v, -6, 5, 2, 2, -6, 5, HOUT_L)
	ArtVorm.verf(v, -6, 5, 0, 0, -6, 5, HOUT_D)
	ArtVorm.bx(v, -1, 3, -1, 3, PAN_Y - 6, 3, METAAL)
	var lamp := RECHT if kant == 0 else SCHEEF
	ArtVorm.bx(v, -2, PAN_Y - 4, -2, 5, 3, 5, lamp)
	ArtVorm.verf(v, -2, 2, PAN_Y - 2, PAN_Y - 2, -2, 2, lamp.lightened(0.2))
	# the beam, two voxels thick, from the left pan's post to the right one's
	var yl := float(pan_hoog(true, kant)) - 4.0
	var yr := float(pan_hoog(false, kant)) - 4.0
	for t in range(-ARM, ARM + 1):
		var f := float(t + ARM) / float(2 * ARM)
		var y := int(round(lerpf(yl, yr, f)))
		for dz in [0, 1]:
			v.append({"x": t, "y": y, "z": -t + dz, "k": METAAL_L})
			v.append({"x": t, "y": y - 1, "z": -t + dz, "k": METAAL})
	# two posts and two pans
	for links in [true, false]:
		var m := plek_links() if links else plek_rechts()
		var top := pan_hoog(links, kant)
		ArtVorm.bx(v, m.x, top - 4, m.y, 2, 3, 2, METAAL)
		_pan(v, m, top)
	# what lies on them
	var ding := str(params.get("l", ""))
	if not ding.is_empty():
		_ding(v, ding, clampi(int(params.get("lm", 1)), 0, 2), plek_links(), pan_hoog(true, kant))
	var y0 := pan_hoog(false, kant)
	var mr := plek_rechts()
	for kg in params.get("r", []):
		_gewicht(v, int(kg), mr.x, y0, mr.y)
		y0 += int((GEWICHT_MAAT.get(int(kg), [3, 2]) as Array)[1])
	return v

## A flat tin pan with a raised rim, its top at `top`.
static func _pan(v: Array, m: Vector2i, top: int) -> void:
	var r := int(ceil(PAN_R))
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var d := sqrt(float(dx * dx + dz * dz))
			if d > PAN_R:
				continue
			v.append({"x": m.x + dx, "y": top - 1, "z": m.y + dz,
				"k": PAN_D if d > PAN_R - 1.2 else PAN})
			if d > PAN_R - 1.0:
				v.append({"x": m.x + dx, "y": top, "z": m.y + dz, "k": PAN})

## One weight standing on its own: a block in its colour with a lighter top, a
## darker foot and a brass knob — the stock on the floor beside the balance.
static func gewicht(params: Dictionary = {}) -> Array:
	var v: Array = []
	var kg := int(params.get("kg", 1))
	_gewicht(v, kg, 0, 0, 0)
	var maat: Array = GEWICHT_MAAT.get(kg, [3, 2])
	v.append({"x": 0, "y": int(maat[1]), "z": 0, "k": GOUD_D})
	return v

## A weight block centred on (x, z), its foot at y.
static func _gewicht(v: Array, kg: int, x: int, y: int, z: int) -> void:
	var maat: Array = GEWICHT_MAAT.get(kg, [3, 2])
	var b: int = maat[0]
	var h: int = maat[1]
	var kl: Color = GEWICHT_KL.get(kg, GOUD)
	var x0 := x - int(b / 2.0)
	var z0 := z - int(b / 2.0)
	ArtVorm.bx(v, x0, y, z0, b, h, b, kl)
	ArtVorm.verf(v, x0, x0 + b - 1, y + h - 1, y + h - 1, z0, z0 + b - 1, kl.lightened(0.25))
	ArtVorm.verf(v, x0, x0 + b - 1, y, y, z0, z0 + b - 1, kl.darkened(0.18))

## What is being weighed, standing on the left pan: a ribbed pumpkin (three
## sizes; the big one is the giant pumpkin of groep 5), a striped watermelon,
## or a jute sack with potatoes peeking out of its top.
static func _ding(v: Array, soort: String, maat: int, m: Vector2i, y0: int) -> void:
	var cx := float(m.x)
	var cz := float(m.y)
	match soort:
		"pompoen":
			var r: float = [4.6, 5.8, 7.2][maat]
			var h: float = [3.8, 4.8, 6.0][maat]
			var voor := v.size()
			ArtVorm.ell(v, cx, y0 + h, cz, r, h, r, POMPOEN, {"e": 2.2, "ymin": y0})
			for i in range(voor, v.size()):
				if (int(v[i]["x"]) + int(v[i]["z"])) % 3 == 0:
					v[i]["k"] = POMPOEN_D
			ArtVorm.bx(v, m.x, y0 + int(h * 2.0), m.y, 1, 3, 1, STEEL)
		"meloen":
			var voor := v.size()
			ArtVorm.ell(v, cx, y0 + 4.2, cz, 6.0, 4.2, 4.8, MELOEN, {"e": 2.2, "ymin": y0})
			for i in range(voor, v.size()):
				if (int(v[i]["x"]) - int(v[i]["z"])) % 4 == 0:
					v[i]["k"] = MELOEN_D
		"zak":
			ArtVorm.ell(v, cx, y0 + 5.0, cz, 5.2, 5.0, 4.6, JUTE, {"e": 3.0, "ymin": y0})
			ArtVorm.bx(v, m.x - 1, y0 + 9, m.y - 1, 3, 3, 3, JUTE_D)
			ArtVorm.ell(v, cx, y0 + 12.6, cz, 3.0, 1.6, 3.0, JUTE, {"e": 2.2, "ymin": y0 + 12})
			for a in [[-1, 0], [1, 1], [0, -1], [2, -1]]:
				v.append({"x": m.x + int(a[0]), "y": y0 + 14, "z": m.y + int(a[1]), "k": AARDAPPEL})
