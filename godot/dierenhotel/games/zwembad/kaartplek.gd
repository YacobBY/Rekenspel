class_name ZwembadKaartplek
extends RefCounted
## Where the sum card hangs — games-b.md §1.10 (binding, G1-F2), ported.
##
## The pool lies diagonally across the whole frame, so one fixed place for the
## card covers the swimmer sooner or later.  The card therefore looks for its
## place around the box the guest occupies RIGHT NOW.
##
## What is ported is the RULE (four candidate places in order of preference,
## 8 css px of air to the swimmer and to the flag's number, 6 to the frame
## edge, 2 as the hard edge); what is NOT ported is how the HTML found it —
## `getBoundingClientRect` after a paint, the `plek-rem`, the "fresh button has
## no transform" fix and `kaartLegStraks()` at 140/420/900/1800 ms.  None of
## those has a cause here: `Control.get_combined_minimum_size()` is exact
## before the first draw, and the answer below is recomputed inside the
## hotspot's own `volg` callable, so it is part of the one deterministic
## placement pass of architecture.md §4.3 instead of a round of measuring and
## shoving after it.
##
## Everything in this file is pure: two rectangles and a frame in, one point
## out.  `test_zwembad.gd` walks it in four frame sizes without a viewport.

const MARGE := 8.0    ## air the card keeps from the swimmer and from the flag
const RAND := 6.0     ## the same air to the frame edge
const KRAP := 2.0     ## the hard frame edge: nothing goes past it
const EPS := 0.01     ## slack against floating point
const GAT := 5.0      ## the vertical gap between the card and its choice strip

## How far two rectangles stand apart, along the axis that separates them.
## Negative = they overlap.  An empty rectangle is infinitely far away.
static func lucht(a: Rect2, b: Rect2) -> float:
	if b.size.x <= 0.0 or b.size.y <= 0.0 or a.size.x <= 0.0 or a.size.y <= 0.0:
		return INF
	var dx := maxf(b.position.x - a.end.x, a.position.x - b.end.x)
	var dy := maxf(b.position.y - a.end.y, a.position.y - b.end.y)
	return maxf(dx, dy)

static func binnen(blok: Rect2, kader: Vector2) -> bool:
	return blok.position.x >= KRAP - EPS and blok.position.y >= KRAP - EPS \
		and blok.end.x <= kader.x - KRAP + EPS and blok.end.y <= kader.y - KRAP + EPS

## `kaart` = the measured card size, `strook` = the measured choice strip size
## (zero when the card has none), `vrij` = the box the guest occupies including
## his number and his name plate, `vlagvak` = the box of the flag and its
## number.  Returns {punt: the card's TOP LEFT corner, midden, kant, krap,
## krap_vlag, half_w}.
##
## Two tiers, and the order between them is a design decision: on a landscape
## phone (a frame of 558 x 289) there are geometries in which no place keeps
## its full air to BOTH boxes, and then the swimmer wins.  HOTEL.md §9 —
## "het dier blijft zichtbaar" — is the rule that may not bend; the number on
## the flag is a label the child can also read off the rim.
static func kies(kader: Vector2, kaart: Vector2, strook: Vector2,
		vrij: Rect2, vlagvak: Rect2) -> Dictionary:
	var nodig := kaart.y + (GAT + strook.y if strook.y > 0.0 else 0.0)
	var half_w := maxf(kaart.x, strook.x) / 2.0 + 2.0
	var mid_x := clampf(kader.x / 2.0, half_w, maxf(half_w, kader.x - half_w))
	var links_x := clampf(half_w + RAND, half_w, maxf(half_w, kader.x - half_w))
	var rechts_x := clampf(kader.x - half_w - RAND, half_w, maxf(half_w, kader.x - half_w))
	var mid_y := clampf((kader.y - nodig) / 2.0, RAND, maxf(RAND, kader.y - nodig - RAND))
	var onder_y := maxf(vrij.end.y + MARGE, kader.y - RAND - nodig)
	# the four places of games-b.md §1.10 in their order of preference, and
	# after them the same two rows pushed against the left and the right edge —
	# still one deterministic list, still no measuring after a paint
	var kandidaten: Array[Dictionary] = [
		{"kant": "onder", "x": mid_x, "y": onder_y},
		{"kant": "boven", "x": mid_x, "y": RAND},
		{"kant": "links", "x": vrij.position.x - MARGE - half_w, "y": mid_y},
		{"kant": "rechts", "x": vrij.end.x + MARGE + half_w, "y": mid_y},
		{"kant": "onderlinks", "x": links_x, "y": onder_y},
		{"kant": "onderrechts", "x": rechts_x, "y": onder_y},
		{"kant": "bovenlinks", "x": links_x, "y": RAND},
		{"kant": "bovenrechts", "x": rechts_x, "y": RAND},
	]
	var beste := {}
	var beste_lucht := -INF
	var alleen_gast := {}
	var alleen_gast_lucht := -INF
	for k in kandidaten:
		var blok := _blok(k, half_w, nodig)
		if not binnen(blok, kader):
			continue
		var bij_gast := lucht(blok, vrij)
		var bij_vlag := lucht(blok, vlagvak)
		if minf(bij_gast, bij_vlag) >= MARGE - EPS:
			return _uit(k, kaart, half_w, false, false)
		if bij_gast >= MARGE - EPS and bij_vlag > alleen_gast_lucht:
			alleen_gast_lucht = bij_vlag
			alleen_gast = k
		if minf(bij_gast, bij_vlag) > beste_lucht:
			beste_lucht = minf(bij_gast, bij_vlag)
			beste = k
	# tier 2: the swimmer keeps his air, the flag's number gives way
	if not alleen_gast.is_empty():
		return _uit(alleen_gast, kaart, half_w, false, true)
	# nothing fits: the place inside the frame with the most air, and otherwise
	# as low as the frame allows (§1.10)
	if not beste.is_empty():
		return _uit(beste, kaart, half_w, true, true)
	var laag := {"kant": "krap", "x": mid_x,
		"y": clampf(kader.y - RAND - nodig, KRAP, maxf(KRAP, kader.y - KRAP - nodig))}
	return _uit(laag, kaart, half_w, true, true)

static func _blok(k: Dictionary, half_w: float, nodig: float) -> Rect2:
	return Rect2(Vector2(float(k["x"]) - half_w, float(k["y"])),
		Vector2(half_w * 2.0, nodig))

## The block a card plus its strip occupies, given the answer of `kies`.
static func blok_van(uit: Dictionary, kaart: Vector2, strook: Vector2) -> Rect2:
	var punt: Vector2 = uit["punt"]
	var half: float = uit["half_w"]
	return Rect2(Vector2(punt.x + kaart.x * 0.5 - half, punt.y),
		Vector2(half * 2.0, kaart.y + (GAT + strook.y if strook.y > 0.0 else 0.0)))

static func _uit(k: Dictionary, kaart: Vector2, half_w: float, krap: bool,
		krap_vlag: bool) -> Dictionary:
	return {
		"punt": Vector2(float(k["x"]) - kaart.x / 2.0, float(k["y"])),
		"midden": Vector2(float(k["x"]), float(k["y"]) + kaart.y / 2.0),
		"kant": str(k["kant"]), "krap": krap, "krap_vlag": krap_vlag,
		"half_w": half_w,
	}

# ------------------------------------------------------- frame px -> voxels

## The band grid places a `midden` hotspot on `World.mik_punt(x, z, y)`, so the
## answer above has to come back as a voxel triple.  The projection is affine,
## so three probes of `mik_punt` invert it exactly — no camera internals, no
## assumption about `dicht` (architecture.md §4.2).  `z` is fixed at 0: the aim
## point of a card is a screen point, not a place in the room.
static func punt_naar_voxel(wereld: Node, doel: Vector2) -> Vector3:
	var o: Vector2 = wereld.mik_punt(0.0, 0.0, 0.0)
	var ex: Vector2 = wereld.mik_punt(1.0, 0.0, 0.0) - o
	var ey: Vector2 = wereld.mik_punt(0.0, 0.0, 1.0) - o
	if absf(ex.x) < 0.00001 or absf(ey.y) < 0.00001:
		return Vector3.ZERO
	var x := (doel.x - o.x) / ex.x
	var y := (o.y + x * ex.y - doel.y) / -ey.y
	return Vector3(x, 0.0, y)
