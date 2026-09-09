class_name Sommen
extends RefCounted
## The frozen number core.  Byte-identical to `demos/dierenhotel/state.js`,
## `econ.js` and `games/sleutels.js`; every function is pure and integer-only.
##
## Binding rule (A1 §2): the numbers a child sees may never change between the
## HTML game and this port.  Same inputs -> same outputs, bit for bit.
## Every worked example in games-a.md §2 and world.md §3.9 is asserted in
## `res://tests/test_sommen.gd`.
##
## W5 completes this file: the day-planner solver (`planbord`, `maakPlan`,
## `planOplossingen`, `planFouten`) and the per-game generators that games-b.md
## marks as frozen.  Nothing here may be "improved".

# ---------------------------------------------------------------- generators

## `dagRnd(zaad)` (state.js): an LCG with 24-bit output.
## The step multiply overflows 53 bits, so it MUST run through float64 —
## see JsGetal.  dag_rnd(1).volgende() == 0.15803265571594238 in the browser.
class DagRnd extends RefCounted:
	var _a: int = 0

	func _init(zaad: int) -> void:
		# zaad * 2654435761 stays under 2^53 for every seed the game uses
		# (dag*7919 + n*131 + verzwak), so this multiply is exact.
		_a = JsGetal.to_uint32(float(zaad) * 2654435761.0 + 12345.0)

	func stand() -> int:
		return _a

	func volgende() -> float:
		_a = JsGetal.to_uint32(float(_a) * 1103515245.0 + 12345.0)
		return float(_a >> 8) / 16777216.0

## `zaadje(n)` (games/sleutels.js): a second LCG, 32-bit output.
## Here the product stays inside 53 bits, so plain integer arithmetic is exact.
class Zaadje extends RefCounted:
	var _s: int = 1

	func _init(n: int) -> void:
		_s = JsGetal.u32(n)
		if _s == 0:
			_s = 1

	func stand() -> int:
		return _s

	func volgende() -> float:
		_s = JsGetal.u32(_s * 1664525 + 1013904223)
		return float(_s) / 4294967296.0

## `prng(seed)` (rooms.js / world.js): the mulberry32 used for the garden tufts
## and for each animal's idle behaviour.  All three steps are `Math.imul`.
class Prng extends RefCounted:
	var _a: int = 0

	func _init(seed: int) -> void:
		_a = JsGetal.u32(seed)

	func volgende() -> float:
		_a = JsGetal.i32(_a + 0x6D2B79F5)
		var t := JsGetal.imul(_a ^ (JsGetal.u32(_a) >> 15), 1 | _a)
		t = JsGetal.i32(t + JsGetal.imul(t ^ (JsGetal.u32(t) >> 7), 61 | t)) ^ t
		return float(JsGetal.u32(t ^ (JsGetal.u32(t) >> 14))) / 4294967296.0

## `hash2(x, z)` (rooms.js) — the floor-tile hash.
static func hash2(x: int, z: int) -> int:
	return JsGetal.u32(JsGetal.imul((x * 73856093) ^ (z * 19349663), 2654435761)) >> 24

## `hash(s)` (world.js) — FNV-1a over a string, used to seed an animal.
static func hash_tekst(s: String) -> int:
	var h := 2166136261
	for i in s.length():
		h = JsGetal.i32(h ^ s.unicode_at(i))
		h = JsGetal.imul(h, 16777619)
	return JsGetal.u32(h)

# ------------------------------------------------------------------ de band

## `bandVanN(N)` — the guest count sets the ceiling of the band.
static func band_van_n(n: int) -> int:
	if n <= 3:
		return 3
	if n <= 6:
		return 4
	return 5

# ------------------------------------------------------- de vijf somfabrieken

const DEEL_PLAN := [
	{"per": 4, "rest": 0}, {"per": 4, "rest": 1}, {"per": 3, "rest": 2},
	{"per": 4, "rest": 0}, {"per": 3, "rest": 1}, {"per": 4, "rest": 2},
]

## `koekjesSom(day, n)` — fair sharing with a remainder.  Frozen.
static func koekjes_som(dag: int, n: int) -> Dictionary:
	var p: Dictionary = DEEL_PLAN[posmod(dag - 1, 6)]
	var per: int = p["per"]
	var rest: int = p["rest"]
	if rest >= n:
		rest = n - 1
	while n * per + rest > 20 and per > 2:
		per -= 1
	return {"per": per, "rest": rest, "total": n * per + rest}

## `vergelijk(v)` — meer / minder / precies (the check-in).  Frozen.
static func vergelijk(dagen: int, nieuw: int, voorraad: int) -> String:
	var tot := dagen * nieuw
	if tot > voorraad:
		return "meer"
	if tot < voorraad:
		return "minder"
	return "precies"

const KSET := {3: [1, 2, 3, 4], 4: [2, 3, 4, 5, 10], 5: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]}
const KPLAFOND := {3: 20, 4: 100, 5: 100}

## `sommen.deel(N, band, dag)` -> {T, k, r, band}, with T = k*N + r.  Frozen.
static func deel(n_gasten: int, band: int, dag: int) -> Dictionary:
	var n: int = maxi(1, n_gasten)
	var ks := koekjes_som(dag, n)
	var k: int = ks["per"]
	var r: int = ks["rest"]
	if r >= k:
		r = k - 1
	while k > 1 and k * n + r > 20:
		k -= 1
		if r > k - 1:
			r = k - 1
	if band <= 3:
		return {"T": k * n + r, "k": k, "r": r, "band": 3}
	var set: Array = KSET.get(band, KSET[4])
	var plaf: int = KPLAFOND.get(band, 100)
	var kand: Array[int] = []
	for kk in set:
		if kk >= k and kk * n + mini(r, kk - 1) <= plaf:
			kand.append(kk)
	if kand.is_empty():
		kand = [k]
	var kk2: int = kand[posmod(dag + n, kand.size())]
	var r2: int = mini(r, kk2 - 1)
	return {"T": kk2 * n + r2, "k": kk2, "r": r2, "band": band}

const TAFEL_SET := {3: [1, 2, 5, 10], 4: [1, 2, 3, 4, 5, 10], 5: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]}
const TAFEL_MAX := {3: 20, 4: 100, 5: 100}

## `sommen.tafel(band)` — the times table for "bedden op rij".  Frozen.
static func tafel(band: int, dag: int, n_gasten: int) -> Dictionary:
	var b := 3 if band <= 3 else (5 if band >= 5 else 4)
	var n: int = n_gasten if n_gasten > 0 else 2
	var set: Array = TAFEL_SET[b]
	var plaf: int = TAFEL_MAX[b]
	var a: int = set[posmod(dag + n, set.size())]
	var max_b: int = maxi(1, mini(10, int(floor(float(plaf) / float(a)))))
	var bb: int = 1 + posmod(dag * 3 + n, max_b)
	return {"a": a, "b": bb, "uit": a * bb, "band": b, "tafels": set, "plafond": plaf}

## `sommen.geld(band, nachten, prijs)` — the bill.  Frozen.
## `nachten`/`prijs` of 0 mean "let the generator choose".
static func geld(band: int, dag: int, nachten: int = 0, prijs: int = 0) -> Dictionary:
	var kans: Array = [1, 2] if band <= 3 else ([1, 2, 5] if band == 4 else [2, 5])
	var p: int = prijs if prijs > 0 else kans[posmod(dag, kans.size())]
	var n: int = nachten if nachten > 0 else (2 if band <= 3 else (3 if band == 4 else 4))
	while n * p > 20 and n > 1:
		n -= 1
	var totaal := n * p
	var betaald := totaal
	if band == 4 and posmod(dag, 2) == 0 and totaal + 2 <= 20:
		betaald = totaal + 2
	if band >= 5:
		while totaal >= 20 and n > 1:
			n -= 1
			totaal = n * p
		betaald = 10 if totaal < 10 else 20
	return {"nachten": n, "prijs": p, "totaal": totaal, "betaald": betaald, "wissel": betaald - totaal}

## `sommen.klok(band)` — the wake-up time.  Frozen.
static func klok(band: int, dag: int) -> Dictionary:
	var u := 7 + posmod(dag * 3, 8)
	if band <= 3:
		return {"u": u, "m": 0, "stap": 60, "tekst": "%d uur" % u}
	if band == 4:
		var m: int = [0, 15, 30, 45][posmod(dag + u, 4)]
		return {"u": u, "m": m, "stap": 15, "tekst": "%d:%02d" % [u, m]}
	var m5 := posmod(dag * 7 + u * 5, 60)
	return {"u": u, "m": m5, "stap": 5, "duur": 20 + posmod(dag, 4) * 10,
			"tekst": "%d:%02d" % [u, m5]}

# --------------------------------------------------------------- muntenwerk

const DENOMS := [10, 5, 2, 1]

## `Econ.buidel(total)` — a purse in which every amount up to `total` can be
## paid exactly.  Returns the coin values, descending.  Frozen.
static func buidel(total: int) -> Array[int]:
	var rest := total
	var som := 0
	var uit: Array[int] = []
	var ronden := 0
	while rest > 0 and ronden < 60:
		ronden += 1
		var d := 1
		for k in DENOMS:
			if k <= rest and k <= som + 1:
				d = k
				break
		uit.append(d)
		som += d
		rest -= d
	uit.sort()
	uit.reverse()
	return uit

## `Econ.splits(n)` — plain greedy change.  Frozen.
static func splits(n: int) -> Array[int]:
	var rest := n
	var uit: Array[int] = []
	for d in DENOMS:
		while rest >= d:
			uit.append(d)
			rest -= d
	return uit
