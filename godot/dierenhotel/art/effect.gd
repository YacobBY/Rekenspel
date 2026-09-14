class_name ArtEffect
extends RefCounted
## Everything that is drawn on top of the plates: the crumbs and sparkles, the
## sleep mark, the two shadows and the water band over a swimmer
## (art-sound-rules.md §11.2, §11.3, §11.4, §11.5).
##
## None of it is a texture: they are a handful of rectangles, one ellipse and
## one composited band, so the world draws them straight.  The numbers live here
## because they belong to the art spec, not to the room that happens to use them.
##
## With `Ui.rust_modus()` on there are no particles at all and every guest holds
## one still pose; the sleep mark stays, because it is a still image already
## (§19, Q-X4-8).

# ------------------------------------------------------------------ deeltjes

const KRUIMEL_KL := Color("#BC8149")            ## KOM.brok
const STER_KL := [Color("#FFE9A8"), Color("#FFF7EC")]
const PLONS_KL := [Color("#E6F5FF"), Color("#FFFFFF"), Color("#CFE9FF")]
const KRUIMEL_N := 3
const STER_N := 2
const ZEEP_KL := Color("#EAF6FF")                 ## a soap bubble over the tub

## `pluis(st, n, x, y, kleur, omhoog)` — n particles with a spawn jitter of
## x +- 7, y +- 3.5 and vx = (rand - 0.5) * 3.2.  Sparkles fly up and hang
## (gravity 0.08, life 9); crumbs fall (gravity 0.5, life 7).
static func pluis(n: int, x: float, y: float, kl: Color, omhoog: bool,
		rnd: RandomNumberGenerator = null) -> Array:
	var uit: Array = []
	for i in n:
		var r := func() -> float: return rnd.randf() if rnd != null else randf()
		uit.append({
			"x": x + (r.call() * 14.0 - 7.0),
			"y": y + (r.call() * 7.0 - 3.5),
			"vx": (r.call() - 0.5) * 3.2,
			"vy": -(1.4 + r.call() * 2.0) if omhoog else -(0.6 + r.call() * 1.2),
			"g": 0.08 if omhoog else 0.5,
			"t": 9 if omhoog else 7,
			"c": kl,
			"s": 2.0 if omhoog else 1.5,
		})
	return uit

## One tick of the particles; dead ones are removed in place.
static func pluis_stap(lijst: Array) -> void:
	for i in range(lijst.size() - 1, -1, -1):
		var q: Dictionary = lijst[i]
		q["x"] += q["vx"]
		q["y"] += q["vy"]
		q["vy"] += q["g"]
		q["t"] -= 1
		if q["t"] <= 0:
			lijst.remove_at(i)

## An axis-aligned square of max(2, round(s * g)) px; the alpha fades with the
## life left — t/6 in the world, t/5 on a card.
static func pluis_maat(q: Dictionary, g: int) -> int:
	return maxi(2, JsGetal.rond(float(q["s"]) * g))

static func pluis_alfa(q: Dictionary, kaart := false) -> float:
	return minf(1.0, float(q["t"]) / (5.0 if kaart else 6.0))

# ----------------------------------------------------------------- het 💤

## Three block "Z" glyphs above a sleeper's head, small to large.  Drawn, not
## typed: this is the one emoji of the game that is not an emoji.  A mirrored
## guest gets mirrored placement.  Still image — they go the moment he gets up.
const ZZZ_KL := Color("#7E6255")
const ZZZ_ALFA := 0.8
const Z_KOP := 8                                ## voxels along the screen axis
const ZZZ := [[0.0, 17.5, 0.85], [2.0, 20.5, 1.15], [4.0, 24.0, 1.5]]

## The rectangles of the sleep mark, relative to the guest's floor point on
## screen (add `(bob + lift) * g` to y yourself, as world.js does).
static func zzz_rechthoeken(g: int, face := 1) -> Array[Rect2i]:
	var uit: Array[Rect2i] = []
	var kop := -1 if face < 0 else 1
	for q in ZZZ:
		var m := maxi(1, JsGetal.rond(float(q[2]) * g))
		var px := JsGetal.rond(kop * (Z_KOP + float(q[0])) * ArtVorm.S * g) - (m * 4 if kop < 0 else 0)
		var py := JsGetal.rond(-float(q[1]) * ArtVorm.HG * g)
		uit.append(Rect2i(px, py, m * 4, m))                    # dakje
		uit.append(Rect2i(px + m * 2, py + m, m, m))            # schuin
		uit.append(Rect2i(px + m, py + m * 2, m, m))            # schuin
		uit.append(Rect2i(px, py + m * 3, m * 4, m))            # vloertje
	return uit

# ---------------------------------------------------------------- schaduwen

## The world shadow: an ellipse on the guest's floor point.  A sitting or sad
## guest sits lower, so its shadow is smaller; a sleeping guest gets NO shadow.
const SCHADUW_KL := Color("#6E5A4A")
const SCHADUW_ALFA := 0.15
const SCHADUW_R := 8.0
const SCHADUW_R_ZIT := 7.0

static func grondschaduw(g: int, staat := "") -> Vector2:
	var r := SCHADUW_R_ZIT if (staat == "zit" or staat == "sip") else SCHADUW_R
	return Vector2(r * g, r * 0.5 * g)

## The card shadow: two stacked ground rhombi, the inner one inset by 2 voxels,
## each filled rgba(74,59,51,.07) — the overlap makes the middle darker.
const KAART_SCHADUW := [3, 1, 19, 14]
const KAART_SCHADUW_KL := Color(74.0 / 255.0, 59.0 / 255.0, 51.0 / 255.0, 0.07)

static func kaart_schaduw(g: int) -> Array[PackedVector2Array]:
	var uit: Array[PackedVector2Array] = []
	for i in 2:
		var m := i * 2
		var x0 := float(KAART_SCHADUW[0] + m)
		var z0 := float(KAART_SCHADUW[1] + m)
		var x1 := float(KAART_SCHADUW[2] - m)
		var z1 := float(KAART_SCHADUW[3] - m)
		uit.append(PackedVector2Array([
			Vector2((x0 - z0) * ArtVorm.S * g, (x0 + z0) * (ArtVorm.S / 2.0) * g),
			Vector2((x1 - z0) * ArtVorm.S * g, (x1 + z0) * (ArtVorm.S / 2.0) * g),
			Vector2((x1 - z1) * ArtVorm.S * g, (x1 + z1) * (ArtVorm.S / 2.0) * g),
			Vector2((x0 - z1) * ArtVorm.S * g, (x0 + z1) * (ArtVorm.S / 2.0) * g)]))
	return uit

# --------------------------------------------------------- water over een zwemmer

## The pool water is baked into the floor and therefore lies UNDER the guest, so
## a swimmer would look like he was wading.  After the guest is drawn a
## translucent band of water is composited onto HIS OWN pixels (source-atop), cut
## by an ellipse — the surface seen from above, so the line stands higher at the
## back than at the front.  The band does not bob: the water stays put and the
## animal bobs in it.
const ZWEM_DIEP := 7                      ## voxels a swimmer sinks (POOT_HOOG)
const WATER_KL := Color("#9CD1E4")        ## BADWATER[0]
const WATER_ALFA := 0.75

## The water line inside the plate: `top` is the guest's floor point in plate
## pixels.  Returns a new Image; the caller keeps it in a texture per (plate,
## top), which is a handful of variants per pose.
static func water_over(bron: Image, top_in: float, g: int) -> Image:
	var w := bron.get_width()
	var h := bron.get_height()
	var uit := bron.duplicate()
	if w < 2 or h < 2:
		return uit
	var top := top_in
	if top >= float(h):
		return uit
	if top < 0.0:
		top = 0.0
	var cx := w / 2.0
	var rx := w / 2.0
	var ry := maxf(2.0, minf(rx * 0.42, 5.0 * g))
	var y0 := maxi(0, int(floor(top - ry)))
	for y in range(y0, h):
		var binnen := float(y) >= top
		for x in w:
			if not binnen:
				var dx := (float(x) + 0.5 - cx) / rx
				var dy := (float(y) + 0.5 - top) / ry
				if dx * dx + dy * dy > 1.0:
					continue
			var p: Color = uit.get_pixel(x, y)
			if p.a <= 0.0:
				continue
			uit.set_pixel(x, y, p.blend(Color(WATER_KL.r, WATER_KL.g, WATER_KL.b,
				WATER_ALFA * p.a)))
	return uit
