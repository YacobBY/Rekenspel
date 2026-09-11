class_name WasIndeling
extends RefCounted
## The layout of the bar chart, computed instead of measured.
##
## The HTML version (`games/was.js`, games-b.md §4.6) read `Hits.debug()` and
## the DOM eight times over 2.65 seconds, because the button layer only placed
## in the NEXT paint, `ui.js` freed its card in two rounds of 90 ms, and the
## digit strip under the frame changed the frame size again up to 400 ms later.
## None of that exists here: a Godot Control answers
## `get_combined_minimum_size()` synchronously and `World`'s projection is a
## closed form, so the two rules below are SOLVED in one pass, before the first
## draw, and re-solved only when the frame really changes.
##
## The two rules (games-b.md §4.6), unchanged:
##
##   C1  the plate of a crate must never end up UNDER its crate.  The band grid
##       hangs a `boven` button in the lowest band whose bottom edge still
##       clears the object by `GAT`; the topmost band starts at `RAND`, so the
##       top of the stack has to leave `RAND + plate height + GAT` units of
##       room.  Otherwise the plate flips below the crate — where the question
##       card is — and it is no longer visible which pile the socks are.
##   C2  the card must not cover a block of the bar chart.
##
## Both hang on one knob: the height of the bench under the crate.  A higher
## bench lifts the blocks clear of the card (good for C2) but eats the room
## above them (bad for C1).  When three-voxel blocks cannot satisfy both, the
## blocks become two voxels: the bar gets shorter and it fits again.  If even
## that fails — which no measured frame produces — C1 wins: a plate that hides
## behind the card makes the question unanswerable, a block that misses a
## sliver at the bottom does not.
##
## Everything here is pure and static, so `test_was.gd` can check the geometry
## against `World.vlak_van()` (the real baked plate) instead of trusting it.

## The screen offsets of a crate model, in units of `k` (= `World.schaal().k`),
## measured from the projection of its own voxel (0, 0, 0):
##   screen_x = (vx - vz) * 2k        screen_y = (vx + vz) * k - vy * 2k
## The blocks span vx in [-4, 5], vz in [-3, 4]; so the topmost corner of the
## stack sits at (vx, vz) = (-4, -3) -> -7k, and the lowest at (5, 4) -> +9k.
const HOEK_TOP := -7.0
const HOEK_VOET := 9.0
const HOEK_LINKS := -16.0     ## (-4 - 4) * 2
const HOEK_RECHTS := 16.0     ## ( 5 + 3) * 2
## The rim of the crate is wider than the blocks (vx in [-6, 7], vz in [-5, 6])
## and its top face sits `voet + 5` voxels up, so on a SHORT stack the plate's
## topmost pixel is the rim's back corner and not the blocks at all:
##   rim    : -11 - 2*voet - 10        blocks : -7 - 2*voet - 4 - 2*stap*n
## The rim wins whenever `stap * n <= 5`.  Measured against `World.vlak_van()`
## in `test_was.gd::test_de_meetkunde_klopt_met_de_gebakken_plaat`.
const RAND_TOP := -11.0
const RAND_HOOG := 5

## The plate word: 2 = the whole word (`sokken`), 1 = the singular (`sok`),
## 0 = the pictogram on its own.
const TIER_WOORD := 2
const TIER_EV := 1
const TIER_ICOON := 0

## Two plates that touch exactly read as one long strip, so they want at least
## this much air between them.
const LUCHT := 2.0

## The screen y of the TOP of a stack of `n` blocks, in frame units.
## `vloer` is `World.mik_punt(x, z, 0).y` of the crate, `k` is `schaal().k`.
static func blok_top(vloer: float, k: float, voet: int, stap: int, n: int) -> float:
	return vloer + HOEK_TOP * k - float(voet + 2 + stap * n) * 2.0 * k

## The screen y of the top of the whole PLATE — that is what the button layer
## sees and what C1 is about.  For a short stack the crate's own rim is higher
## than the blocks in it.
static func plaat_top(vloer: float, k: float, voet: int, stap: int, n: int) -> float:
	return vloer + minf(HOEK_TOP - float(2 * voet + 4 + 2 * stap * n),
		RAND_TOP - float(2 * voet + 2 * RAND_HOOG)) * k

## The screen y of the BOTTOM of the lowest block (the crate floor is under it,
## and the card may cover that).
static func blok_bodem(vloer: float, k: float, voet: int) -> float:
	return vloer + HOEK_VOET * k - float(voet + 2) * 2.0 * k

## The screen rectangle of the blocks of one crate — what the card must stay
## off (C2).  `oorsprong` is `World.mik_punt(x, z, 0)`.
static func blok_vlak(oorsprong: Vector2, k: float, voet: int, stap: int, n: int) -> Rect2:
	if n <= 0:
		return Rect2()
	var top := blok_top(oorsprong.y, k, voet, stap, n)
	var bodem := blok_bodem(oorsprong.y, k, voet)
	return Rect2(Vector2(oorsprong.x + HOEK_LINKS * k, top),
		Vector2((HOEK_RECHTS - HOEK_LINKS) * k, bodem - top))

## The rectangle a crate's PLATE hangs on: the crate box from the top of the
## plate down to the bottom of the blocks — the bar the child counts, without
## the bench under it.
##
## This is handed to `Hits` as the hotspot's own `vlak`, and that is what keeps
## the plate above the crate.  The band grid weighs the band above against the
## band below and takes the one whose free cell is NEAREST the object's centre
## (architecture.md §4.3, I1 finding 2); with the whole crate — bench, legs and
## all — as the object, that centre sits low and "below" wins, which is exactly
## what C1 forbids.  The bar is what the plate belongs to, so the bar is what it
## is measured against.
static func krat_vlak(oorsprong: Vector2, k: float, voet: int, stap: int, n: int) -> Rect2:
	var top := plaat_top(oorsprong.y, k, voet, stap, n)
	var bodem := blok_bodem(oorsprong.y, k, voet)
	return Rect2(Vector2(oorsprong.x + RAND_TOP * 2.0 * k, top),
		Vector2(-RAND_TOP * 4.0 * k, maxf(1.0, bodem - top)))

## The rectangle the plate is ANCHORED on, which is the bar grown upwards by
## exactly the sliver the `rand` anchor is allowed to cover.
##
## C1 says the plate is above its crate, full stop.  `op: "boven"` does not give
## that: the band grid weighs the band above against the band below and takes
## the nearer free cell, and because a band is 52 units the quantisation alone
## can make "below" nearer — measured, on three of the four ticket frames.  The
## `rand` anchor (number tags, name plates) is the one that only ever goes UP:
## it hangs the element's bottom edge just over the object's top edge, centres
## it exactly on the aim point (so it never drifts over the neighbour's crate)
## and steps up in whole bands when that place is taken.
##
## `rand` does allow the element to cover `Hits.TAG_IN` of its object.  Growing
## the anchor upwards by
##     d = (GAT + TAG_IN * h) / (1 - TAG_IN)
## turns that allowance into exactly `GAT` units of AIR above the real bar, so
## the plate touches no block at all: the bar is a strict subset of the anchor.
static func anker_vlak(oorsprong: Vector2, k: float, voet: int, stap: int, n: int) -> Rect2:
	var bar := krat_vlak(oorsprong, k, voet, stap, n)
	var d := (float(Hits.GAT) + Hits.TAG_IN * bar.size.y) / (1.0 - Hits.TAG_IN)
	return Rect2(Vector2(bar.position.x, bar.position.y - d),
		Vector2(bar.size.x, bar.size.y + d))

## C1 as a bench height: the highest bench for which the plate still fits above
## the finished stack.  May come out negative; the caller clamps.
##
##   plaat_top(voet) >= RAND + plaat_h + GAT + pad
##   <=>  max(11 + 2*stap*hoogste, 11 + 2*RAND_HOOG) + 2*voet <= A
## with A the room above the crate floor, in units of k.
static func voet_max(vloer: float, k: float, pad: float, plaat_h: float,
		stap: int, hoogste: int) -> int:
	if k <= 0.0:
		return WasSoorten.VOET
	var a := (vloer - pad - float(Hits.RAND) - plaat_h - float(Hits.GAT)) / k
	var nodig: float = maxf(-HOEK_TOP + 4.0 + 2.0 * float(stap * hoogste),
		-RAND_TOP + 2.0 * float(RAND_HOOG))
	return int(floor((a - nodig) / 2.0))

## C2 as a bench height: the lowest bench that keeps every block above the top
## edge of the card.  `kaart_top` is INF while there is no card.
static func voet_min(vloer: float, k: float, pad: float, kaart_top: float) -> int:
	if k <= 0.0 or not is_finite(kaart_top):
		return WasSoorten.VOET_MIN
	return int(ceil((vloer + HOEK_VOET * k + pad - kaart_top) / (2.0 * k))) - 2

## The whole solve.  `o` carries what only the game can know:
##   vloer, k, pad, hoogste, plaat_h, kaart_top, breedtes: Array[float],
##   mikken: Array[float] (the aim x of every crate), kolommen: int
## Returns {voet, stap, tier}.
static func los(o: Dictionary) -> Dictionary:
	var vloer: float = o.get("vloer", 0.0)
	var k: float = maxf(0.001, float(o.get("k", 1.0)))
	var pad: float = o.get("pad", 0.0)
	var hoogste: int = maxi(0, int(o.get("hoogste", 0)))
	var plaat_h: float = maxf(float(Hits.RIJ) - 4.0, float(o.get("plaat_h", 48.0)))
	var kaart_top: float = o.get("kaart_top", INF)
	var stap := WasSoorten.STAP
	var v_max := voet_max(vloer, k, pad, plaat_h, stap, hoogste)
	var v_min := voet_min(vloer, k, pad, kaart_top)
	# Two voxels per block instead of three: the bar gets shorter, so the plate
	# fits above it AND every block stays clear of the card.
	if v_min > v_max and hoogste > 0:
		stap = WasSoorten.STAP_MIN
		v_max = voet_max(vloer, k, pad, plaat_h, stap, hoogste)
	var voet := clampi(v_max, WasSoorten.VOET_MIN, WasSoorten.VOET_MAX)
	if v_min > voet and v_min <= v_max:
		voet = clampi(v_min, WasSoorten.VOET_MIN, WasSoorten.VOET_MAX)
	return {"voet": voet, "stap": stap, "tier": tier_van(o)}

## Which word fits on the plates.  Two neighbours that would overlap (less than
## `LUCHT` units of air) drop a size; when even the pictogram alone does not
## fit, the plates are allowed to dodge — then not overlapping matters more
## than standing right above the own crate, and the band grid does the dodging
## by itself (there is no evasion round to write here).
##
## `breedtes[t]` is the plate width per tier, measured on the real Controls.
static func tier_van(o: Dictionary) -> int:
	var mikken: Array = o.get("mikken", [])
	var breedtes: Array = o.get("breedtes", [])
	var kolommen: int = maxi(1, int(o.get("kolommen", 99)))
	if breedtes.size() < 3:
		return TIER_WOORD
	for tier in [TIER_WOORD, TIER_EV, TIER_ICOON]:
		var w: float = maxf(float(Hits.RIJ) - 4.0, float(breedtes[tier]))
		if _past(mikken, w, kolommen):
			return tier
	return TIER_ICOON

static func _past(mikken: Array, breed: float, kolommen: int) -> bool:
	# every plate takes whole grid columns; m of them have to fit side by side
	var kols: int = maxi(1, ceili(breed / float(Hits.KOL)))
	if kols * maxi(1, mikken.size()) > kolommen:
		return false
	var rij: Array[float] = []
	for x in mikken:
		rij.append(float(x))
	rij.sort()
	for i in range(1, rij.size()):
		if breed - (rij[i] - rij[i - 1]) > -LUCHT:
			return false
	return true
