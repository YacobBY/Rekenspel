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
## Layout of this file (W5 completed it):
##   1. the four generators (`DagRnd`, `Zaadje`, `Prng`, `Lcg31`) and the hashes
##   2. the band and the five frozen sum factories (games-a.md §2)
##   3. the coins (`buidel`, `splits`, econ.js §2.9)
##   4. the day-planner solver (`maak_plan`, `plan_oplossingen`, `plan_fouten`,
##      `planbord`, `VASTE_AFSPRAKEN`) — frozen, not surfaced (A1 §13 Q-X1-6)
##   5. one inner class per wave-2 game with that game's own generators:
##      `Sommen.Zwembad`, `.Wekker`, `.Hinkel`, `.Was`, `.Kraam`, `.Sleutels`,
##      `.Tobbe`, `.Bedden`, `.Meubels`, `.Voerkar`.
##
## A game NEVER copies a generator into its own directory (A1 §2.2): it calls
## the function here, so there is exactly one place where the numbers live.
## Every function is `static` and pure — no autoload, no state, no `randf()`.
## Nothing here may be "improved".
##
## The dictionary keys of the per-game generators keep the JavaScript names
## (`L`, `M`, `T`, `k`, `r`, `per`…) so a reader can hold the spec next to the
## code; a JS `null` becomes `""` for a text field and `{}` for a record.

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

## `prng(z)` (games/zwembad.js, same LCG as rooms.js): 31-bit output.
## `s = (s * 1103515245 + 12345) & 0x7fffffff` — the product reaches 2.4·10^18,
## so this one ALSO has to run through float64 (JsGetal, A1 §2.1).
class Lcg31 extends RefCounted:
	var _s: int = 1

	func _init(zaad: int) -> void:
		_s = JsGetal.i32(zaad)
		if _s == 0:
			_s = 1

	func stand() -> int:
		return _s

	func volgende() -> float:
		# `& 0x7fffffff` clears bit 31, so ToInt32 and ToUint32 agree here.
		_s = JsGetal.to_uint32(float(_s) * 1103515245.0 + 12345.0) & 0x7FFFFFFF
		return float(_s) / 2147483647.0

## `hash2(x, z)` (rooms.js) — the floor-tile hash.
static func hash2(x: int, z: int) -> int:
	return JsGetal.u32(JsGetal.imul((x * 73856093) ^ (z * 19349663), 2654435761)) >> 24

## `hash(s)` (world.js) — FNV-1a over a string, used to seed an animal.
## JavaScript's `charCodeAt` walks UTF-16 code *units*, so a character outside
## the BMP counts as its two surrogates.  Every id the game hashes is ASCII, so
## this only matters for a future caller — but then it matters completely.
static func hash_tekst(s: String) -> int:
	var h := 2166136261
	for i in s.length():
		var c := s.unicode_at(i)
		if c > 0xFFFF:
			c -= 0x10000
			h = _fnv(h, 0xD800 + (c >> 10))
			h = _fnv(h, 0xDC00 + (c & 0x3FF))
		else:
			h = _fnv(h, c)
	return JsGetal.u32(h)

static func _fnv(h: int, code: int) -> int:
	return JsGetal.imul(JsGetal.i32(h ^ code), 16777619)

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

# ======================================================================
#  DE PLANBORD-SOLVER — frozen, and deliberately not surfaced in this run
#  (A1 §13, Q-X1-6).  games-a.md §2.7 + state.js:360-553.  The day planner
#  moves onto the prikbord later; when it does, it must compute exactly
#  what the tested demo computed, which is what this section guarantees.
# ======================================================================

## Eight quarters of an hour: the strip the planner fills.
const CELLEN := 8

## The four fixed appointments, in the order `maakPlan` picks from them.
const VASTE_AFSPRAKEN := [
	{"act": "Dierenarts", "name": "dokter Els", "at": 4, "cells": 1,
		"tekst": "Dokter Els komt om 15:00 langs voor de controle. Dat blokje staat vast."},
	{"act": "Bezoek", "name": "een familie", "at": 2, "cells": 1,
		"tekst": "Om 14:30 komt er een familie kijken naar de dieren. Dat blokje staat vast."},
	{"act": "Voer", "name": "de bezorger", "at": 6, "cells": 1,
		"tekst": "Om 15:30 wordt het nieuwe voer gebracht. Dat blokje staat vast."},
	{"act": "Dierenarts", "name": "dokter Els", "at": 3, "cells": 2,
		"tekst": "Dokter Els komt om 14:45 en blijft een half uur. Dat blokje staat vast."},
]

const ACT_EMOJI := {"Wandeling": "🦮", "Spelen": "🧶", "Bad": "🛁", "Plonzen": "💦",
		"Dierenarts": "🩺", "Bezoek": "👪", "Voer": "📦", "Klusje": "🧹"}
const ACT_LID := {"Wandeling": "de wandeling", "Spelen": "het spelen", "Bad": "het bad",
		"Plonzen": "het plonzen", "Klusje": "het klusje", "Dierenarts": "de dokter",
		"Bezoek": "het bezoek", "Voer": "de bezorging"}
## An activity that has to come AFTER something (you get dirty first, then bathe).
const NA_ACT := {"Bad": 1, "Plonzen": 1}
## An activity that has to come BEFORE such a block.
const VOOR_ACT := {"Wandeling": 1, "Spelen": 1}

## Dutch possessive -s: only an apostrophe after s/x/z, `'s` after a long vowel.
static func bezit(naam: String) -> String:
	var l := naam.substr(naam.length() - 1).to_lower() if naam.length() > 0 else ""
	if "sxz".find(l) >= 0:
		return naam + "'"
	if "aiouy".find(l) >= 0:
		return naam + "'s"
	return naam + "s"

static func act_lid(blok: Dictionary) -> String:
	var act := str(blok.get("act", ""))
	return ACT_LID.get(act, act.to_lower())

## The sentence under a `na` rule.
static func orde_tekst(na: Dictionary, voor: Dictionary) -> String:
	var act := str(na.get("act", "")).to_lower()
	if NA_ACT.has(na.get("act")) and VOOR_ACT.has(voor.get("act")):
		return "Eerst " + act_lid(voor) + ", dán " + act_lid(na) + ": " \
			+ bezit(str(na.get("name", ""))) + " " + act + " moet ná " + act_lid(voor) \
			+ " van " + str(voor.get("name", "")) + " — anders is " + str(na.get("name", "")) \
			+ " meteen weer vies!"
	return bezit(str(na.get("name", ""))) + " " + act + " kan pas ná " + act_lid(voor) \
		+ " van " + str(voor.get("name", "")) + "."

## How many cells does the block with this id take?  Unknown id -> 1, as in JS.
static func blok_cellen(plan: Dictionary, id: String) -> int:
	for b in plan.get("blokken", []):
		if b.get("id", "") == id:
			return int(b.get("cells", 1))
	return 1

## `planFouten(plan, stand)` — every `na` rule this arrangement breaks.
## `stand` maps a block id onto its start cell; a block that is not placed
## yet is simply absent and its rules are skipped.
static func plan_fouten(plan: Dictionary, stand: Dictionary) -> Array:
	var fout: Array = []
	for r in plan.get("regels", []):
		if r.get("soort", "") != "na":
			continue
		var a := str(r.get("a", ""))
		var b := str(r.get("b", ""))
		if not stand.has(a) or not stand.has(b):
			continue
		if int(stand[a]) < int(stand[b]) + blok_cellen(plan, b):
			fout.append(r)
	return fout

## `planOplossingen(plan, max)` — count the arrangements without a broken rule
## and remember the first one.  Backtracking over the free blocks; the fixed
## blocks put their bits in `bezet` up front.
static func plan_oplossingen(plan: Dictionary, maximaal: int = 500) -> Dictionary:
	if maximaal <= 0:
		maximaal = 500
	var vrij: Array = []
	var vast := 0
	var stand := {}
	for b in plan.get("blokken", []):
		if bool(b.get("vast", false)):
			stand[str(b.get("id", ""))] = int(b.get("at", 0))
			for j in int(b.get("cells", 1)):
				vast |= 1 << (int(b.get("at", 0)) + j)
		else:
			vrij.append(b)
	var tel := {"aantal": 0, "eerste": {}, "gevonden": false}
	_plan_lus(plan, vrij, 0, vast, stand, tel, maximaal)
	return {"aantal": int(tel["aantal"]), "eerste": tel["eerste"]}

static func _plan_lus(plan: Dictionary, vrij: Array, k: int, bezet: int,
		stand: Dictionary, tel: Dictionary, maximaal: int) -> void:
	if int(tel["aantal"]) >= maximaal:
		return
	if k >= vrij.size():
		if plan_fouten(plan, stand).is_empty():
			tel["aantal"] = int(tel["aantal"]) + 1
			if not bool(tel["gevonden"]):
				tel["eerste"] = stand.duplicate()
				tel["gevonden"] = true
		return
	var b: Dictionary = vrij[k]
	var id := str(b.get("id", ""))
	var cellen := int(b.get("cells", 1))
	for at in range(0, CELLEN - cellen + 1):
		var m := 0
		for t in cellen:
			m |= 1 << (at + t)
		if m & bezet:
			continue
		stand[id] = at
		_plan_lus(plan, vrij, k + 1, bezet | m, stand, tel, maximaal)
		stand.erase(id)
		if int(tel["aantal"]) >= maximaal:
			return

## `maakPlan(dag, dieren, verzwak)` — build one day's puzzle.
## `dieren` = [{id, naam|name, act, mins}]; `verzwak` 0…5 relaxes the puzzle
## one notch at a time (`planbord` walks it up until a solution exists).
## A free block has `at = -1`: GDScript has no `null` inside a typed record,
## and only a fixed block's `at` is ever read.
static func maak_plan(dag: int, dieren: Array, verzwak: int) -> Dictionary:
	var rnd := DagRnd.new(dag * 7919 + dieren.size() * 131 + verzwak)
	var blokken: Array = []
	for i in dieren.size():
		var a: Dictionary = dieren[i]
		var naam := str(a["name"]) if a.has("name") else str(a.get("naam", ""))
		blokken.append({"id": "b%d_%s" % [i, str(a.get("id", ""))],
			"animal": str(a.get("id", "")), "name": naam, "act": str(a.get("act", "")),
			"mins": int(a.get("mins", 15)), "cells": int(a.get("mins", 15)) / 15,
			"at": -1, "vast": false})
	var regels: Array = []
	var wil_vast := dag >= 2 and verzwak < 3
	var wil_orde := dag >= 3 and verzwak < 2
	var wil_vol := dag >= 4 and verzwak < 1

	# 1. the fixed appointment (verzwak 1 and 2 shift it along)
	var vast_cellen := 0
	var afspraak := {}
	if wil_vast:
		afspraak = VASTE_AFSPRAKEN[posmod(dag - 2 + verzwak, VASTE_AFSPRAKEN.size())]
		vast_cellen = int(afspraak["cells"])

	# 2. shrink the animal blocks until they fit in what is left
	var som := 0
	for b in blokken:
		som += int(b["cells"])
	var i2 := 0
	while i2 < blokken.size() and som > CELLEN - vast_cellen:
		if int(blokken[i2]["cells"]) > 1:
			som -= 1
			blokken[i2]["cells"] = 1
			blokken[i2]["mins"] = 15
		i2 += 1
	if som > CELLEN - vast_cellen:
		vast_cellen = 0
		afspraak = {}
	if not afspraak.is_empty():
		blokken.append({"id": "vast_" + str(afspraak["act"]), "animal": "",
			"name": str(afspraak["name"]), "act": str(afspraak["act"]),
			"mins": int(afspraak["cells"]) * 15, "cells": int(afspraak["cells"]),
			"at": int(afspraak["at"]), "vast": true})
		regels.append({"soort": "vast", "emoji": ACT_EMOJI.get(afspraak["act"], "📌"),
			"tekst": str(afspraak["tekst"]), "blok": "vast_" + str(afspraak["act"])})

	# 3. a chore on top, so the strip runs nearly full
	if wil_vol:
		var ruimte := CELLEN - vast_cellen - som
		var klus: int = mini(2, ruimte)
		if klus >= 1:
			blokken.append({"id": "klus_dag", "animal": "", "name": "Jij", "act": "Klusje",
				"mins": klus * 15, "cells": klus, "at": -1, "vast": false})
			som += klus
			regels.append({"soort": "vol", "emoji": "🧹",
				"tekst": "De kamers moeten vandaag ook schoon. Alles bij elkaar past nét — "
					+ "er blijft bijna geen vakje over."})

	# 4. the ordering rule: first get dirty, then into the tub
	if wil_orde:
		var na := -1
		var voor := -1
		for i in blokken.size():
			var b: Dictionary = blokken[i]
			if bool(b["vast"]):
				continue
			if na < 0 and NA_ACT.has(b["act"]):
				na = i
			elif voor < 0 and VOOR_ACT.has(b["act"]):
				voor = i
		if na < 0 or voor < 0:
			var los: Array[int] = []
			for i in blokken.size():
				if not bool(blokken[i]["vast"]):
					los.append(i)
			if los.size() >= 2:
				na = los[JsGetal.vloer(rnd.volgende() * los.size())]
				for q in los:
					if q != na:
						voor = q
						break
		if na >= 0 and voor >= 0 and na != voor:
			regels.append({"soort": "na", "a": str(blokken[na]["id"]), "b": str(blokken[voor]["id"]),
				"emoji": "🛁" if NA_ACT.has(blokken[na]["act"]) else "⏱️",
				"tekst": orde_tekst(blokken[na], blokken[voor])})
		# 5. from day 6 a second ordering rule.  It never reuses the two blocks
		#    of the first rule, so a cycle (a after b AND b after a) cannot arise.
		if dag >= 6 and verzwak < 1 and na >= 0 and voor >= 0:
			var rest: Array[int] = []
			for i in blokken.size():
				if not bool(blokken[i]["vast"]) and i != na and i != voor:
					rest.append(i)
			if rest.size() >= 2:
				var tweede: int = rest[JsGetal.vloer(rnd.volgende() * rest.size())]
				var eerst := -1
				for q in rest:
					if q != tweede:
						eerst = q
						break
				regels.append({"soort": "na", "a": str(blokken[tweede]["id"]),
					"b": str(blokken[eerst]["id"]), "emoji": "⏱️",
					"tekst": "En nog iets: " + orde_tekst(blokken[tweede], blokken[eerst])})

	return {"blokken": blokken, "regels": regels, "gekozen": "", "klaar": false,
		"markeer": [], "fout": {}, "pogingen": 0, "dag": dag}

## `planbord(dag, dieren)` — the puzzle of the day: relax it one notch at a
## time until it has at least one solution; if even that fails, fall back to
## "just fit the blocks" (`maakPlan(1, dieren, 9)`).
static func planbord(dag: int, dieren: Array) -> Dictionary:
	for verzwak in range(0, 6):
		var plan := maak_plan(dag, dieren, verzwak)
		var opl := plan_oplossingen(plan, 400)
		if int(opl["aantal"]) > 0:
			plan["oplossing"] = opl["eerste"]
			plan["oplossingen"] = int(opl["aantal"])
			plan["verzwakt"] = verzwak
			plan["vrijeVakjes"] = CELLEN - _cellen_som(plan)
			return plan
	var kaal := maak_plan(1, dieren, 9)
	kaal["oplossingen"] = int(plan_oplossingen(kaal, 400)["aantal"])
	kaal["verzwakt"] = 9
	kaal["vrijeVakjes"] = CELLEN - _cellen_som(kaal)
	return kaal

static func _cellen_som(plan: Dictionary) -> int:
	var s := 0
	for b in plan.get("blokken", []):
		s += int(b.get("cells", 0))
	return s

# ======================================================================
#  DE GENERATOREN VAN DE TIEN SPELLEN (wave 2)
#  One inner class per game.  A game calls these; it never re-implements
#  them (A1 §2.2).  Sources: games-a.md §3–§7 and games-b.md §1–§5, with
#  the JavaScript of `demos/dierenhotel/games/<id>.js` as the tie-breaker
#  for anything the prose leaves open.
# ======================================================================

## G1 — HET ZWEMBAD (games-b.md §1.3/§1.4, games/zwembad.js).
class Zwembad extends RefCounted:
	## k = the step per guest, lo/hi = the window of the band, M = metres per
	## stroke (band 5 decides that from L), plafond = the biggest button number.
	const BANDEN := {
		3: {"k": 5, "lo": 8, "hi": 20, "M": 10, "plafond": 20},
		4: {"k": 8, "lo": 21, "hi": 50, "M": 30, "plafond": 100},
		5: {"k": 7, "lo": 31, "hi": 80, "M": 0, "plafond": 100},
	}

	static func band_van(b: int) -> int:
		return 3 if b <= 3 else (5 if b >= 5 else 4)

	static func plafond_van(band: int) -> int:
		return int(BANDEN[band_van(band)]["plafond"])

	## The maximum per stroke: fixed per band, 40 m for the long lanes of band 5.
	static func max_van(l: int, band: int) -> int:
		var b := band_van(band)
		if b < 5:
			return int(BANDEN[b]["M"])
		return 40 if l >= 55 else 30

	## `baan(N, band, dag)` -> {L, M, band, N, dag, k, r, stap, plafond}.
	## Band 5 shifts a lane three metres whenever the remainder would be a round
	## ten (40 -> 43, 50 -> 53, …), and no lane ever needs more than two strokes.
	static func baan(n_gasten: int, band: int, dag: int) -> Dictionary:
		var b := band_van(band)
		var info: Dictionary = BANDEN[b]
		var n: int = maxi(1, n_gasten)
		var d: int = maxi(1, dag)
		var k := int(info["k"])
		var r: int = posmod(n + d, k)
		var lo := int(info["lo"])
		var hi := int(info["hi"])
		var l: int = clampi(k * n + r, lo, hi)
		# Owner, 2026-09-14: with one or two guests k·N + r fell under `lo` every
		# day and the clamp made every lane 8 m ("altijd 8 meter").  Under the
		# window the day walks the lane through it instead — a deliberate
		# deviation from the frozen JavaScript, documented in games-b.md §1.3.
		if k * n + r < lo:
			l = lo + posmod(k * n + 3 * d, hi - lo + 1)
		var m := max_van(l, b)
		if b >= 5 and l > m and (l - m) % 10 == 0:
			l = clampi(l + 3, int(info["lo"]), int(info["hi"]))
			m = max_van(l, b)
		if l > 2 * m:
			l = 2 * m
		return {"L": l, "M": m, "band": b, "N": n, "dag": d, "k": k, "r": r,
			"stap": 5 if l <= 20 else 10, "plafond": int(info["plafond"])}

	## "As far as you can": the whole remainder, or M when that is more.
	static func juist_van(l: int, m: int, p: int) -> int:
		var r: int = maxi(0, l - p)
		return r if r <= m else m

	## `keuzeGetallen(L, M, p, band, leg)` -> {lijst, juist, plek, rest}.
	## The order of the wishes is binding (G1-F1): first the numbers the child
	## can SEE in the world (the whole remainder, the lane, the maximum, what is
	## left after this stroke), then a round ten off/on, and only as filler the
	## neighbours juist ± 1…3.  `leg` = how many choices were made this turn, so
	## the right button does not sit in the same place every time.
	static func keuze_getallen(l: int, m: int, p: int, band: int, leg: int = 0) -> Dictionary:
		var r: int = maxi(0, l - p)
		var juist := juist_van(l, m, p)
		var plafond := plafond_van(band)
		var wens: Array[int] = [r, l, m, r - m, juist - 10, juist + 10,
			juist - 1, juist + 1, juist + 2, juist - 2, juist + 3, juist - 3]
		var goed: Array[int] = []
		for v in wens:
			if v < 1 or v > plafond or v == juist or goed.has(v):
				continue
			goed.append(v)
		var v2 := 1
		while goed.size() < 3 and v2 <= plafond:
			if v2 != juist and not goed.has(v2):
				goed.append(v2)
			v2 += 1
		var uit: Array[int] = goed.slice(0, 3)
		var rnd := Lcg31.new(l * 977 + m * 131 + p * 17 + leg * 7 + 1)
		var plek: int = mini(3, JsGetal.vloer(rnd.volgende() * 4.0))
		uit.insert(plek, juist)
		return {"lijst": uit, "juist": juist, "plek": plek, "rest": r}

	## What one tap on a choice button means (games-b.md §1.5).  NEVER punishing:
	## too short -> he swims that far and a new card asks for the rest; too much
	## -> he may only do M per stroke, so he swims M; too far -> he bumps softly
	## into the wall.  No red, no star less, no repeat of the turn.
	static func slag(l: int, m: int, p: int, n: int) -> Dictionary:
		var r: int = maxi(0, l - p)
		var juist := juist_van(l, m, p)
		var soort := "goed" if n == juist else ("kort" if n < juist else ("veel" if n <= r else "ver"))
		var meters := r if soort == "ver" else (juist if soort == "veel" else n)
		return {"soort": soort, "meters": meters, "juist": juist, "rest": r}


## G2 — DE WEKKERDIENST (games-b.md §2.3/§2.4, games/wekker.js).
## The hotel has no day or night: every clock is a 12-hour face (A1 §13 Q-X3-7).
class Wekker extends RefCounted:
	const UURICO := ["🕛", "🕐", "🕑", "🕒", "🕓", "🕔", "🕕", "🕖", "🕗", "🕘", "🕙", "🕚"]

	## Normalise an hour onto 1…12 (12 o'clock, never 0).
	static func u12(u: int) -> int:
		var v := u % 12
		return v + 12 if v <= 0 else v

	static func volg_u(u: int) -> int:
		return u12(u + 1)

	## Minutes since 12 o'clock, 0…719.
	static func in_min(u: int, m: int) -> int:
		return (u12(u) % 12) * 60 + posmod(m, 60)

	static func van_min(t: int) -> Dictionary:
		var v: int = posmod(t, 720)
		return {"u": u12(v / 60), "m": v % 60}

	## Dutch clock reading: half 8 = 7:30, 10 voor half 8 = 7:20.
	static func tijd_woord(u: int, m: int) -> String:
		var uu := u12(u)
		var mm: int = posmod(m, 60)
		if mm == 0:
			return "%d uur" % uu
		if mm == 15:
			return "kwart over %d" % uu
		if mm == 30:
			return "half %d" % volg_u(uu)
		if mm == 45:
			return "kwart voor %d" % volg_u(uu)
		if mm < 15:
			return "%d over %d" % [mm, uu]
		if mm < 30:
			return "%d voor half %d" % [30 - mm, volg_u(uu)]
		if mm < 45:
			return "%d over half %d" % [mm - 30, volg_u(uu)]
		return "%d voor %d" % [60 - mm, volg_u(uu)]

	## The clock face for this time, rounded to the nearest whole hour.
	static func uur_ico(u: int, m: int) -> String:
		var t := van_min(in_min(u, m) + 30)
		return UURICO[u12(int(t["u"])) % 12]

	static func band_klem(b: int) -> int:
		return 3 if b <= 3 else (5 if b >= 5 else 4)

	## Round a minute onto the nearest five (60 wraps to 0).
	static func klok5(m: int) -> int:
		var q := JsGetal.rond(float(m) / 5.0) * 5
		return 0 if q >= 60 else q

	## `doelTijd(band, dag, idx)` — the hour this guest wants, one hour later per
	## guest.  The frozen `klok()` gives the HOUR; its minutes cannot be used as
	## they are (band 4 always lands on 45, band 5 on a minute the clock cannot
	## be set to), so they are shifted here.  The generator itself is untouched.
	static func doel_tijd(band: int, dag: int, idx: int) -> Dictionary:
		var b := band_klem(band)
		var k := Sommen.klok(b, dag)
		var u := u12(int(k["u"]) + idx)
		var m := 0
		if b == 4:
			m = posmod(int(k["m"]) + (dag + idx) * 15, 60)
		elif b >= 5:
			m = posmod(klok5(int(k["m"])) + (dag + idx) * 5, 60)
		return {"u": u, "m": m}

	## `afstand(band, N, dag)` — how far the hands have to be turned.
	static func afstand(band: int, n_gasten: int, dag: int) -> Dictionary:
		var b := band_klem(band)
		var r := dag % 2
		var uur := 0
		var kwart := 0
		var vijf := 0
		if b <= 3:
			uur = maxi(1, mini(5, n_gasten + r))
		elif b == 4:
			uur = maxi(1, mini(3, JsGetal.plafond(float(n_gasten) / 2.0)))
			kwart = posmod(n_gasten + dag, 4)
		else:
			uur = maxi(1, mini(3, JsGetal.plafond(float(n_gasten) / 3.0)))
			kwart = posmod(n_gasten + dag, 4)
			vijf = posmod(n_gasten + dag, 3)
		return {"uur": uur, "kwart": kwart, "vijf": vijf,
			"min": uur * 60 + kwart * 15 + vijf * 5}

	## `duurKeuzes(startU, dh, dag)` — four hours to choose from at a duration
	## question.  Fixed, but a different order every day: no randomness in the
	## save file.
	static func duur_keuzes(nu_u: int, dh: int, dag: int) -> Array[int]:
		var goed := in_min(nu_u, 0) + dh * 60
		var lijst: Array[int] = [goed, goed + 60, goed - 60, in_min(nu_u, 0) - dh * 60]
		var uit: Array[int] = []
		var gezien := {}
		for t in lijst:
			var u := int(van_min(t)["u"])
			if gezien.has(u):
				continue
			gezien[u] = 1
			uit.append(u)
		var i := 0
		while uit.size() < 4 and i < 24:
			i += 1
			var u := int(van_min(goed + 120 + i * 60)["u"])
			if not gezien.has(u):
				gezien[u] = 1
				uit.append(u)
		var k: int = posmod(dag, 4)
		var gedraaid: Array[int] = uit.slice(k)
		gedraaid.append_array(uit.slice(0, k))
		return gedraaid

	## Is this a duration question?  Only band 5, and only on every other guest
	## of every other day (games-b.md §2.3).
	static func duur_vraag(band: int, dag: int, idx: int) -> bool:
		return band_klem(band) >= 5 and posmod(dag + idx, 2) == 1

	## The numbers of one wake-up turn -> {doelU, doelM, u, m, stap, duur, keuzes}.
	## `u`/`m` is where the hands START; `stap` is "duur" (first the duration
	## question) or "zet" (set the clock straight away).  A duration target
	## always sits on a whole hour and the clock starts `duur` whole hours
	## earlier, so the question has a clean answer.
	static func beurt(band: int, n_gasten: int, dag: int, idx: int) -> Dictionary:
		var b := band_klem(band)
		var doel := doel_tijd(b, dag, idx)
		var a := afstand(b, n_gasten, dag)
		var duur := duur_vraag(b, dag, idx)
		var dh := int(a["uur"])
		var start := {}
		var keuzes: Array[int] = []
		if duur:
			doel = {"u": int(doel["u"]), "m": 0}
			start = van_min(in_min(int(doel["u"]), 0) - dh * 60)
			keuzes = duur_keuzes(int(start["u"]), dh, dag)
		else:
			start = van_min(in_min(int(doel["u"]), int(doel["m"])) - int(a["min"]))
		return {"dag": dag, "N": n_gasten, "band": b, "idx": idx,
			"doelU": int(doel["u"]), "doelM": int(doel["m"]),
			"u": int(start["u"]), "m": int(start["m"]),
			"stap": "duur" if duur else "zet", "duur": dh if duur else 0,
			"keuzes": keuzes}


## G3 — HET HINKELPAD (games-b.md §3.4, games/hinkel.js).
class Hinkel extends RefCounted:
	## Never more than ten hops (HOTEL.md §3).
	const MAX_HOP := 10
	## E = the end of the line, stap = the spacing of the stones,
	## stenen = how many stones, sprongen = the hop sizes on the strip.
	const BAND := {
		3: {"E": 10, "stap": 1, "stenen": 11, "sprongen": [1, 2, 5]},
		4: {"E": 100, "stap": 5, "stenen": 21, "sprongen": [2, 5, 10]},
		5: {"E": 100, "stap": 5, "stenen": 21, "sprongen": [2, 3, 4, 5, 6, 7, 8, 9, 10]},
	}

	static func band_of(band: int) -> int:
		return 3 if band <= 3 else (5 if band >= 5 else 4)

	## Which hop sizes fit exactly on this distance (in 1…10 hops)?
	static func maten_voor(afst: int, band: int) -> Array[int]:
		var info: Dictionary = BAND[band_of(band)]
		var uit: Array[int] = []
		for k in info["sprongen"]:
			if afst % int(k) == 0 and afst / int(k) <= MAX_HOP and afst / int(k) >= 1:
				uit.append(int(k))
		return uit

	## The hop sizes on the strip: everything that fits, trimmed to three
	## (first, middle, last) so the strip stays readable.  2/4/5/10 -> 2/5/10.
	static func maten(afst: int, band: int) -> Array[int]:
		var uit := maten_voor(afst, band)
		var info: Dictionary = BAND[band_of(band)]
		if uit.is_empty():
			for k in info["sprongen"]:
				if afst % int(k) == 0:
					uit.append(int(k))
		if uit.is_empty():
			uit.append(1)
		if uit.size() > 3:
			uit = [uit[0], uit[uit.size() / 2], uit[uit.size() - 1]]
		return uit

	## `beurt(N, band, dag)` -> {band, E, stap, s, doel, sprong, n, afstand}.
	## Two demands on the distance: at least TWO hop sizes fit it exactly (or the
	## strip is not a real choice), and it is a multiple of the stone spacing (so
	## the little staircase always lands ON a stone).  The target is never on the
	## last stone — otherwise "too far" could not exist.
	static func beurt(n_gasten: int, band: int, dag: int) -> Dictionary:
		var b := band_of(band)
		var n0: int = maxi(1, n_gasten)
		var d: int = maxi(1, dag)
		var info: Dictionary = BAND[b]
		var e := int(info["E"])
		var stap := int(info["stap"])
		var lijst: Array = info["sprongen"]
		var ruimte := e - stap
		var k := int(lijst[posmod(d + n0, lijst.size())])
		var n: int = mini(maxi(2, n0), MAX_HOP)
		while k * n > ruimte and n > 2:
			n -= 1
		while k * n > ruimte:
			var kl := k
			for kk in lijst:
				if int(kk) < k and int(kk) * 2 <= ruimte:
					kl = int(kk)
					break
			if kl == k:
				break
			k = kl
		var afst := k * n
		var best := 0
		var orde: Array[int] = [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5]
		for stap_op in orde:
			if best != 0:
				break
			var nn := n + stap_op
			if nn < 2 or nn > MAX_HOP:
				continue
			if _past(k * nn, ruimte, stap, b):
				best = k * nn
				n = nn
		for j in lijst.size():
			if best != 0:
				break
			var kk := int(lijst[posmod(j + d, lijst.size())])
			for stap_op in orde:
				if best != 0:
					break
				var nn := n + stap_op
				if nn < 2 or nn > MAX_HOP:
					continue
				if _past(kk * nn, ruimte, stap, b):
					best = kk * nn
					k = kk
					n = nn
		afst = best if best != 0 else maxi(stap, mini(afst - (afst % stap), ruimte))
		var max_s: int = maxi(0, ruimte - afst)
		var s := 0
		if b == 4:
			s = 10 * posmod(d, max_s / 10 + 1)
		elif b == 5:
			# deliberately NOT on a ten, but still on a stone: 5, 15, 25, …
			s = 5 + 10 * posmod(d + n0, (max_s - 5) / 10 + 1) if max_s >= 5 else 0
		else:
			s = k * posmod(d, max_s / k + 1)
		return {"band": b, "E": e, "stap": stap, "s": s, "doel": s + afst,
			"sprong": k, "n": JsGetal.rond(float(afst) / float(k)), "afstand": afst}

	static func _past(a: int, ruimte: int, stap: int, band: int) -> bool:
		return a >= 2 and a <= ruimte and a % stap == 0 and maten_voor(a, band).size() >= 2

	## Four counts to choose from: exactly one right, no duplicates, never zero
	## or negative.  `zaad` = the seed of this question (s + dag + pogingen).
	static func keuze_getallen(n: int, zaad: int) -> Array[int]:
		var pool: Array[int] = [-2, -1, 1, 2, 3]
		var uit: Array[int] = [n]
		var z: int = absi(JsGetal.i32(zaad))
		for i in pool.size():
			if uit.size() >= 4:
				break
			var v: int = n + pool[posmod(i + z, pool.size())]
			if v >= 1 and not uit.has(v):
				uit.append(v)
		var v2 := n + 1
		while uit.size() < 4:
			if not uit.has(v2):
				uit.append(v2)
			v2 += 1
		uit.sort()
		return uit

	## Counting along the line out loud: "50 … 60 … 70." (the first help step).
	## At most four steps are spelled out, then "…" and the target.
	static func tel_pad(s: int, doel: int, k: int) -> String:
		var afst: int = absi(doel - s)
		var n: int = afst / maxi(1, k)
		var richting := 1 if doel >= s else -1
		var l: Array[String] = []
		for i in range(1, mini(n, 4) + 1):
			l.append(str(s + richting * k * i))
		if n > 4:
			l.append("…")
			l.append(str(doel))
		return " … ".join(l) + "."


## G4 — DE WASMANDTOREN (games-b.md §4.3, games/was.js).
class Was extends RefCounted:
	## plaf = the ceiling in pieces, soorten = how many kinds, per = pieces per
	## tap (group 5 picks up two at a time), kset = the k the sum may use.
	const BAND := {
		3: {"plaf": 12, "soorten": 3, "per": 1, "kset": [1, 2]},
		4: {"plaf": 20, "soorten": 3, "per": 1, "kset": [1, 2, 3, 4, 5]},
		5: {"plaf": 30, "soorten": 4, "per": 2, "kset": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]},
	}

	static func band_klem(band: int) -> int:
		return 4 if band == 4 else (5 if band == 5 else 3)

	## `kiesT(N, band, dag)` -> {k, r, T}.  Every (k, r) under this game's ceiling,
	## biggest totals first; in group 5 T must be even (the washing comes off the
	## pile two at a time).  On a tie the r closest to the frozen `deel()` wins,
	## and the three biggest totals take turns per day.
	## Emergency (even k = 1 runs over the ceiling): T drops to the ceiling itself
	## and `k = 0` says honestly that the form k·N + r no longer holds.
	static func kies_t(n_gasten: int, band: int, dag: int) -> Dictionary:
		var b := band_klem(band)
		var info: Dictionary = BAND[b]
		var plaf := int(info["plaf"])
		var per := int(info["per"])
		var basis := Sommen.deel(n_gasten, b, dag)
		var basis_r := int(basis["r"])
		var lijst: Array[Dictionary] = []
		for k in info["kset"]:
			var r := int(k) - 1
			while r >= 0:
				var t: int = int(k) * n_gasten + r
				if t > plaf or (per == 2 and t % 2 != 0):
					r -= 1
					continue
				var al := -1
				for j in lijst.size():
					if int(lijst[j]["T"]) == t:
						al = j
						break
				if al < 0:
					lijst.append({"k": int(k), "r": r, "T": t})
				elif absi(r - basis_r) < absi(int(lijst[al]["r"]) - basis_r):
					lijst[al] = {"k": int(k), "r": r, "T": t}
				r -= 1
		var goed: Array[Dictionary] = []
		for q in lijst:
			if int(q["T"]) >= 3 * per:
				goed.append(q)
		if goed.is_empty():
			goed = lijst
		if goed.is_empty():
			var t2 := plaf - (plaf % 2 if per == 2 else 0)
			return {"k": 0, "r": 0, "T": t2}
		goed = _aflopend_op_t(goed)
		var top: Array[Dictionary] = []
		for q in goed:
			if int(q["T"]) >= int(goed[0]["T"]) - 2 * per and top.size() < 3:
				top.append(q)
		return top[posmod(dag - 1, top.size())]

	## JavaScript's Array.sort is stable; GDScript's is not, so the original
	## index breaks the tie and the order stays byte-identical.
	static func _aflopend_op_t(rijen: Array[Dictionary]) -> Array[Dictionary]:
		var met_index: Array = []
		for i in rijen.size():
			met_index.append([int(rijen[i]["T"]), i, rijen[i]])
		met_index.sort_custom(func(a, b): return a[0] > b[0] if a[0] != b[0] else a[1] < b[1])
		var uit: Array[Dictionary] = []
		for r in met_index:
			uit.append(r[2])
		return uit

	## Spread T over m piles: base 1, 2, …, m, then the rest evenly and the last
	## bit on top of the highest piles.  So the piles are ALWAYS different and
	## "which pile is the highest" has exactly one answer.
	static func verdeel(t: int, m: int) -> Array[int]:
		var uit: Array[int] = []
		if m < 1:
			return uit
		var basis := m * (m + 1) / 2
		if t < basis:
			var q: int = maxi(1, t / m)
			for i in m:
				uit.append(q)
			uit[m - 1] += t - q * m
			return uit
		var q2 := (t - basis) / m
		var rest := (t - basis) - q2 * m
		for i in m:
			uit.append(1 + i + q2 + (1 if i >= m - rest else 0))
		return uit

	## How many kinds fit this many blocks?  m different piles need at least
	## 1+2+…+m blocks, so group 5 with one guest sorts three kinds, not four.
	static func soorten_voor(band: int, blokken: int) -> int:
		var m := int(BAND[band_klem(band)]["soorten"])
		while m > 2 and blokken < m * (m + 1) / 2:
			m -= 1
		return m

	## The complete recipe of one turn -> {band, N, dag, k, r, T, per, m, blok, rij}.
	## `blok` = the pile sizes per kind, `rij` = the order on the pile (one place
	## per tap).  Both are shuffled with the same mulberry32, descending
	## Fisher-Yates, so the tallest pile is not the same kind every day.
	static func recept(n_gasten: int, band: int, dag: int) -> Dictionary:
		var n: int = maxi(1, n_gasten)
		var b := band_klem(band)
		var d: int = maxi(1, dag)
		var info: Dictionary = BAND[b]
		var per := int(info["per"])
		var t := kies_t(n, b, d)
		var blokken := int(t["T"]) / per
		var m := soorten_voor(b, blokken)
		var stapel := verdeel(blokken, m)
		var r := Prng.new(1000 * b + 37 * n + d)
		var i := stapel.size() - 1
		while i > 0:
			var j := JsGetal.vloer(r.volgende() * float(i + 1))
			var q := stapel[i]
			stapel[i] = stapel[j]
			stapel[j] = q
			i -= 1
		var rij: Array[int] = []
		for s in m:
			for _q in stapel[s]:
				rij.append(s)
		i = rij.size() - 1
		while i > 0:
			var j := JsGetal.vloer(r.volgende() * float(i + 1))
			var q := rij[i]
			rij[i] = rij[j]
			rij[j] = q
			i -= 1
		return {"band": b, "N": n, "dag": d, "k": int(t["k"]), "r": int(t["r"]),
			"T": blokken * per, "per": per, "m": m, "blok": stapel, "rij": rij}


## G5 — DE SOUVENIRKRAAM (games-b.md §5.3, games/kraam.js).
class Kraam extends RefCounted:
	## `lid` = the Dutch article, `acc` = the accessory name `World.accessoire`
	## knows ("" = cannot be worn), `basis` = the price from the spec that the
	## band shift is added to.
	const WAREN := [
		{"id": "hoedje", "ico": "🎩", "naam": "hoedje", "lid": "het", "acc": "hoedje",
			"basis": 4, "model": "kr_hoedje"},
		{"id": "sjaaltje", "ico": "🧣", "naam": "sjaaltje", "lid": "het", "acc": "sjaaltje",
			"basis": 3, "model": "kr_sjaaltje"},
		{"id": "bal", "ico": "⚽", "naam": "bal", "lid": "de", "acc": "bal",
			"basis": 5, "model": "kr_bal"},
		{"id": "tas", "ico": "🎒", "naam": "tas", "lid": "de", "acc": "",
			"basis": 12, "model": "kr_tas"},
	]
	## Groups 3 and 4 pay with €1 and €2; group 5 gives change and needs €5 too.
	const MUNTEN := {3: [1, 2], 4: [1, 2], 5: [1, 2, 5]}
	## HOTEL.md §4: never more than €20 in one payment.
	const PLAFOND := 20
	## The ghost coins that show an amount: with €5, €2 and €1 every amount up to
	## €13 fits in four coins, and four is exactly what fits side by side (G5-F1).
	const SPOOK_MUNT := [5, 2, 1]
	const SPOOK_MAX := 4

	static func euro(n: int) -> String:
		return "€%d" % n

	## Plain greedy change in the coins that really lie in the drawer
	## (`Sommen.splits` also knows a €10 note, and that one is not there).
	static func splits_met(bedrag: int, munten: Array) -> Array[int]:
		var uit: Array[int] = []
		var r: int = maxi(0, bedrag)
		var m: Array[int] = []
		for v in munten:
			m.append(int(v))
		m.sort()
		m.reverse()
		for v in m:
			while r >= v:
				uit.append(v)
				r -= v
		return uit

	## Counting on together, and really ENDING on the sum: "5 … 6 … 7 … 8 … 9."
	## (`Ui.tel_mee` counts in steps of the price, "5 … 10.", and that is the
	## wrong answer for €5 + €4 — G5-F1.)
	static func tel_vanaf(start: int, erbij: int) -> String:
		var l: Array[String] = [str(start)]
		for i in range(1, erbij + 1):
			l.append(str(start + i))
		return " … ".join(l) + "."

	## The band shift: one number out of N and the day, exactly as tobbe picks
	## its kind.  Group 3 goes DOWN with it (preferably up to 10, HOTEL.md §3),
	## group 4 one step up, group 5 up to three.  `rot` rotates the prices over
	## the three things, so the hat is not always the most expensive.
	static func schuif_van(n_gasten: int, band: int, dag: int) -> Dictionary:
		var n: int = maxi(1, n_gasten)
		var d: int = maxi(1, dag)
		var v: int = posmod(n + d, 4 if band >= 5 else 2)
		return {"v": v, "schuif": -v if band <= 3 else v, "rot": posmod(n + 2 * d, 3)}

	## `opzet(N, band, dag)` — the stall of today: prices, what the guest buys,
	## what it costs, what is paid and what comes back.
	static func opzet(n_gasten: int, band: int, dag: int) -> Dictionary:
		var n: int = maxi(1, n_gasten)
		var d: int = maxi(1, dag)
		var b := 3 if band <= 3 else (5 if band >= 5 else 4)
		var s := schuif_van(n, b, d)
		var basis: Array[int] = [4, 3, 5]
		var waren: Array[Dictionary] = []
		for i in (4 if b >= 5 else 3):
			var w: Dictionary = WAREN[i]
			waren.append({"id": w["id"], "ico": w["ico"], "naam": w["naam"], "lid": w["lid"],
				"acc": w["acc"], "model": w["model"],
				"prijs": 12 if w["id"] == "tas" else basis[posmod(i + int(s["rot"]), 3)] + int(s["schuif"])})
		var draag: Array[Dictionary] = []
		for w in waren:
			if str(w["acc"]) != "":
				draag.append(w)
		var i0: int = posmod(n + d, draag.size())
		var keus: Array[Dictionary] = [draag[i0]]
		if b > 3:
			keus.append(draag[posmod(i0 + 1, draag.size())])
		var kosten := 0
		for w in keus:
			kosten += int(w["prijs"])
		# group 5 pays with a note and gets change; the other bands lay down the
		# amount themselves
		var betaald: int = (10 if kosten <= 9 else 20) if b >= 5 else kosten
		var wissel := betaald - kosten
		var keus_ids: Array[String] = []
		for w in keus:
			keus_ids.append(str(w["id"]))
		var vraag := {}
		if b == 4:
			vraag = {"som": euro(int(keus[0]["prijs"])) + " + " + euro(int(keus[1]["prijs"])) + " =",
				"goed": kosten}
		elif b >= 5:
			vraag = {"som": euro(betaald) + " − " + euro(kosten) + " =", "goed": wissel}
		return {"band": b, "N": n, "dag": d, "waren": waren, "keus": keus_ids,
			"kosten": kosten, "betaald": betaald, "wissel": wissel,
			"doel": wissel if b >= 5 else kosten, "vraag": vraag, "munten": MUNTEN[b]}

	## Checks the generator itself: whole euros, never above €20, no price twice,
	## no target of €0, never negative change, and in group 5 always ≥ €1 change.
	## Returns a list of complaints; EMPTY = good.  The suite sweeps this over
	## every band × N 1…12 × dag 1…12 (games-b.md §5.3).
	static func keuring(o: Dictionary) -> Array[String]:
		var fout: Array[String] = []
		var p: Array[int] = []
		for w in o["waren"]:
			p.append(int(w["prijs"]))
		if int(o["kosten"]) > PLAFOND:
			fout.append("kosten boven €20")
		if int(o["betaald"]) > PLAFOND:
			fout.append("betaling boven €20")
		for i in p.size():
			if p[i] < 1:
				fout.append("prijs geen hele euro: %d" % p[i])
			if p.find(p[i]) != i:
				fout.append("twee keer dezelfde prijs: %d" % p[i])
			if int(o["band"]) <= 3 and p[i] > 10:
				fout.append("groep 3 boven 10: %d" % p[i])
			if p[i] > PLAFOND:
				fout.append("prijs boven €20: %d" % p[i])
		if not int(o["doel"]) >= 1:
			fout.append("niets te leggen")
		if int(o["wissel"]) < 0:
			fout.append("negatief wisselgeld")
		if int(o["band"]) >= 5 and int(o["wissel"]) < 1:
			fout.append("groep 5 zonder wisselgeld")
		var keus: Array = o["keus"]
		if keus.is_empty():
			fout.append("geen aankoop")
		for i in keus.size():
			if keus.find(keus[i]) != i:
				fout.append("twee keer hetzelfde spulletje")
			var w := {}
			for q in o["waren"]:
				if str(q["id"]) == str(keus[i]):
					w = q
					break
			if w.is_empty() or str(w["acc"]) == "":
				fout.append("gekocht spul is niet te dragen: " + str(keus[i]))
		var vraag: Dictionary = o["vraag"]
		if not vraag.is_empty() and not int(vraag["goed"]) >= 0:
			fout.append("negatieve som")
		# the showing row must ALWAYS show exactly the amount
		for bedrag in [int(o["doel"]), int(vraag["goed"]) if not vraag.is_empty() else 0]:
			if bedrag == 0:
				continue
			var sp := splits_met(bedrag, SPOOK_MUNT)
			var som := 0
			for v in sp:
				som += v
			if som != bedrag:
				fout.append("spookmunten kloppen niet: %d" % bedrag)
			if sp.size() > SPOOK_MAX:
				fout.append("te veel spookmunten voor %d: %d" % [bedrag, sp.size()])
		if int(o["band"]) <= 3 and not vraag.is_empty():
			fout.append("groep 3 hoort geen som te krijgen")
		if int(o["band"]) >= 4 and vraag.is_empty():
			fout.append("groep %d hoort een som te krijgen" % int(o["band"]))
		var leg := splits_met(int(o["doel"]), o["munten"])
		var som2 := 0
		for v in leg:
			som2 += v
		if som2 != int(o["doel"]):
			fout.append("doel niet te leggen met deze munten")
		return fout


## A4 — HET SLEUTELBORD (games-a.md §4.2, games/sleutels.js).
## The only game of group A that uses chance, and it is fully seeded.
class Sleutels extends RefCounted:
	## The number range per group.
	const PLAFOND := {3: 20, 4: 100, 5: 1000}
	## Empty hooks per assignment.
	const MAXBLANCO := {3: 2, 4: 2, 5: 3}

	## More hooks do not fit: every plate is a 48 px tap target on a strip of
	## about 390 css-px.  Three-digit numbers (group 5) get a wider plate, so
	## there are four of them.
	static func aantal_haken(n_gasten: int, band: int) -> int:
		var h := 2 + JsGetal.plafond(float(maxi(1, n_gasten)) / 2.0)
		return clampi(h, 4, 4 if band >= 5 else 5)

	static func aantal_sleutels(n_gasten: int, band: int) -> int:
		return clampi(JsGetal.plafond(float(maxi(1, n_gasten)) / 3.0), 1,
			int(MAXBLANCO.get(band, 2)))

	## Two empty hooks need five hooks.
	static func per_bord(h: int) -> int:
		return 2 if h >= 5 else 1

	static func variant_van(band: int, dag: int) -> String:
		if band <= 3:
			return "telrij-tien" if dag % 2 == 0 else "telrij"
		if band == 4:
			return ["sprong5", "sprong10", "evenoneven"][posmod(dag, 3)]
		return "kamers" if dag % 2 == 0 else "sprong25"

	## The row of one board; `deel` 0 is the first stretch, 1 the next (or the
	## second floor / the even row).  An absent label is "" here, not null.
	static func rij_van(variant: String, dag: int, h: int, deel: int) -> Dictionary:
		var plaf := 20
		var van := 1
		var stap := 1
		var label := ""
		match variant:
			"telrij":
				van = 1 + deel * h
				stap = 1
				plaf = int(PLAFOND[3])
			"telrij-tien":
				van = (int(PLAFOND[3]) - h + 1) - deel * h
				stap = 1
				plaf = int(PLAFOND[3])
			"sprong5":
				van = 5 + deel * h * 5
				stap = 5
				plaf = int(PLAFOND[4])
			"sprong10":
				van = 10 + deel * h * 10
				stap = 10
				plaf = int(PLAFOND[4])
			"evenoneven":
				van = 2 if deel != 0 else 1
				stap = 2
				plaf = int(PLAFOND[4])
				label = "even" if deel != 0 else "oneven"
			"kamers":
				# floor 1 and 2 in turn; the third board is the next block of
				# rooms, so no room number is ever on the board twice
				var s := 11 if dag % 4 == 0 else 1
				var verd := 1 + (deel % 2)
				var blok := deel / 2
				van = 100 * verd + s + blok * h
				stap = 1
				plaf = int(PLAFOND[5])
				label = "verdieping %d" % verd
			_:
				van = 25 + deel * h * 25
				stap = 25
				plaf = int(PLAFOND[5])
		# never above the ceiling of the group and never below 1 (and do not push
		# up with the step: the odd row starts on 1 on purpose)
		van = maxi(1, mini(van, plaf - (h - 1) * stap))
		return {"van": van, "stap": stap, "n": h, "label": label}

	## Empty hooks: never on the edge and never next to each other, so there are
	## always two neighbours to read the step from.  May return FEWER than asked
	## (H = 5, 2 asked, candidate 2 chosen -> 1 blank); that is allowed and an
	## extra board is added (A1 §13 Q-X2-3).
	static func kies_blanco(n: int, hoeveel: int, rnd: Zaadje) -> Array[int]:
		var kand: Array[int] = []
		for i in range(1, n - 1):
			kand.append(i)
		var uit: Array[int] = []
		while uit.size() < hoeveel and not kand.is_empty():
			var k: int = kand[JsGetal.vloer(rnd.volgende() * kand.size())]
			uit.append(k)
			var over: Array[int] = []
			for q in kand:
				if absi(q - k) > 1:
					over.append(q)
			kand = over
		uit.sort()
		return uit

	static func handtekening(n_gasten: int, band: int, dag: int, ronde: int) -> String:
		return "%d|%d|%d|%d" % [n_gasten, band, dag, ronde]

	## `maakOpdracht(N, band, dag, gasten, ronde)` — the whole key board.
	## `gasten` = [{id, naam, soort}], one per key; at most three boards.
	static func maak_opdracht(n_gasten: int, band: int, dag: int, gasten: Array,
			ronde: int = 0) -> Dictionary:
		var b := clampi(band, 3, 5)
		var h := aantal_haken(n_gasten, b)
		var variant := variant_van(b, dag)
		var aantal: int = mini(aantal_sleutels(n_gasten, b), gasten.size())
		var rnd := Zaadje.new(dag * 7919 + n_gasten * 131 + b * 17 + ronde * 8191 + 1)
		var borden: Array[Dictionary] = []
		var sleutels: Array[Dictionary] = []
		var deel := 0
		var over := aantal
		while over > 0 and deel < 3:
			var hoeveel: int = mini(per_bord(h), over)
			var rij := rij_van(variant, dag, h, deel)
			var blanco := kies_blanco(h, hoeveel, rnd)
			var haken: Array[Dictionary] = []
			for i in h:
				haken.append({"w": int(rij["van"]) + i * int(rij["stap"]),
					"blanco": blanco.has(i), "sleutel": ""})
			borden.append({"van": int(rij["van"]), "stap": int(rij["stap"]), "n": h,
				"label": str(rij["label"]), "blanco": blanco, "haken": haken})
			for i2 in blanco:
				if sleutels.size() >= gasten.size():
					haken[i2]["blanco"] = false
					continue
				var g: Dictionary = gasten[sleutels.size()]
				sleutels.append({"gast": str(g.get("id", "")), "naam": str(g.get("naam", "")),
					"soort": str(g.get("soort", "")), "nummer": int(haken[i2]["w"]),
					"bord": deel, "haak": i2, "op": false, "mis": 0})
			over -= blanco.size()
			deel += 1
		return {"sig": handtekening(n_gasten, b, dag, ronde), "band": b, "N": n_gasten,
			"dag": dag, "ronde": ronde, "variant": variant, "H": h,
			"borden": borden, "sleutels": sleutels,
			"nu": 0, "missers": 0, "klaar": false, "t0": 0}

	## The check-back function, also the play test: one right answer per empty
	## hook, neatly inside the band.  `ok` = true when `fout` is empty.
	static func controleer(p: Dictionary) -> Dictionary:
		var fout: Array[String] = []
		var plaf := int(PLAFOND.get(int(p["band"]), 20))
		var alle := {}
		var borden: Array = p["borden"]
		for nr in borden.size():
			var b: Dictionary = borden[nr]
			var tel := {}
			var haken: Array = b["haken"]
			for i in haken.size():
				var w := int(haken[i]["w"])
				tel[w] = int(tel.get(w, 0)) + 1
				alle[w] = int(alle.get(w, 0)) + 1
				if w != int(b["van"]) + i * int(b["stap"]):
					fout.append("bord %d: haakje %d is geen rekenrij" % [nr, i])
				if w > plaf or w < 1:
					fout.append("bord %d: getal %d buiten 1..%d" % [nr, w, plaf])
			for w in tel:
				if int(tel[w]) != 1:
					fout.append("bord %d: getal %d hangt %dx" % [nr, int(w), int(tel[w])])
			if haken.size() != int(b["n"]):
				fout.append("bord %d: %d haakjes i.p.v. %d" % [nr, haken.size(), int(b["n"])])
			var zicht := 0
			var bl: Array[int] = []
			for i in haken.size():
				if bool(haken[i]["blanco"]):
					bl.append(i)
				else:
					zicht += 1
			if zicht < 2:
				fout.append("bord %d: maar %d plaatje(s), sprong niet te zien" % [nr, zicht])
			if bl.size() > 2:
				fout.append("bord %d: %d lege haakjes op één bord" % [nr, bl.size()])
			for i in bl:
				if i == 0 or i == int(b["n"]) - 1:
					fout.append("bord %d: leeg haakje op de rand (%d)" % [nr, i])
				if bl.has(i + 1):
					fout.append("bord %d: twee lege haakjes naast elkaar" % nr)
		for w in alle:
			if int(alle[w]) != 1:
				fout.append("getal %d komt op twee borden voor" % int(w))
		var blanco := 0
		for b in borden:
			for h in b["haken"]:
				if bool(h["blanco"]):
					blanco += 1
		var sleutels: Array = p["sleutels"]
		if blanco != sleutels.size():
			fout.append("%d sleutels voor %d lege haakjes" % [sleutels.size(), blanco])
		var nrs := {}
		for s in sleutels:
			var nummer := int(s["nummer"])
			if nrs.has(nummer):
				fout.append("twee sleutels met nummer %d" % nummer)
			nrs[nummer] = 1
			var past: Array[String] = []
			for nr in borden.size():
				var haken: Array = borden[nr]["haken"]
				for i in haken.size():
					if int(haken[i]["w"]) == nummer:
						past.append("%d:%d" % [nr, i])
			if past.size() != 1:
				fout.append("sleutel %d past op %d haakjes" % [nummer, past.size()])
			elif past[0] != "%d:%d" % [int(s["bord"]), int(s["haak"])]:
				fout.append("sleutel %d wijst verkeerd" % nummer)
			var h2 := {}
			if int(s["bord"]) < borden.size():
				var haken: Array = borden[int(s["bord"])]["haken"]
				if int(s["haak"]) < haken.size():
					h2 = haken[int(s["haak"])]
			if h2.is_empty() or not bool(h2["blanco"]):
				fout.append("sleutel %d hoort niet bij een leeg haakje" % nummer)
		var grootste := 0
		for b in borden:
			for h in b["haken"]:
				grootste = maxi(grootste, int(h["w"]))
		return {"ok": fout.is_empty(), "fout": fout, "borden": borden.size(),
			"haken": (int(borden[0]["haken"].size()) if not borden.is_empty() else 0),
			"blanco": blanco, "sleutels": sleutels.size(), "grootste": grootste,
			"variant": str(p["variant"]), "band": int(p["band"])}


## A6 — TOBBE-TIJD (games-a.md §6.2, games/tobbe.js).
class Tobbe extends RefCounted:
	const PLAFOND := {3: 10, 4: 20, 5: 36}
	## How many animals today's note may name at most, so T never runs over the
	## ceiling of the band.
	const CAP := {
		3: {"eerlijk": 5},
		4: {"eerlijk": 10, "dubbel": 5, "half": 10},
		5: {"eerlijk": 10, "dubbel": 9, "half": 11},
	}
	## How many scoops the child may take per tap.
	const HAND := [1, 2, 5]

	## Band 3 only splits fairly up to 10; doubling and halving arrive in group 4.
	static func soorten(band: int) -> Array[String]:
		var uit: Array[String] = ["eerlijk"]
		if band > 3:
			uit.append("dubbel")
			uit.append("half")
		return uit

	## `recept(N, band, dag)` -> {soort, band, n0, perDier, basis, T, M, per, rest}.
	## M = the number of tubs; `per` scoops in each, `rest` left in the bucket
	## (only group 5 ever has one).
	static func recept(n_gasten: int, band: int, dag: int) -> Dictionary:
		var n: int = maxi(1, n_gasten)
		var b := 3 if band <= 3 else (5 if band >= 5 else 4)
		var d: int = maxi(1, dag)
		var lijst := soorten(b)
		var soort: String = lijst[posmod(d + n, lijst.size())]
		# an extra dirty turn in group 5: 3 scoops per animal, so halving can
		# leave a remainder (9 = 4 and 4, 1 left)
		var per_dier := 3 if (soort == "half" and b >= 5) else 2
		var n0: int = maxi(1, mini(n, int(CAP[b][soort])))
		var m := 3 if (b >= 5 and soort != "half") else 2
		var basis := per_dier * n0
		var t := basis * 2 if soort == "dubbel" else basis
		while t > int(PLAFOND[b]) and n0 > 1:
			n0 -= 1
			basis = per_dier * n0
			t = basis * 2 if soort == "dubbel" else basis
		# never a tub that has to stay empty: rather one tub less
		while m > 2 and t / m < 1:
			m -= 1
		return {"soort": soort, "band": b, "n0": n0, "perDier": per_dier, "basis": basis,
			"T": t, "M": m, "per": t / m, "rest": t - (t / m) * m}

	## Fewer tubs fit on the yard than the recipe asked for: rescale the sum.
	static func herschaal(t: int, m: int) -> Dictionary:
		var per: int = t / maxi(1, m)
		return {"M": m, "per": per, "rest": t - per * m}


## A3 — BEDDEN OP RIJ (games-a.md §3.3, games/bedden.js).
class Bedden extends RefCounted:
	## So many rows fit on this floor / so many beds in one strip.
	const MAX_RIJEN := 3
	const MAX_PER_RIJ := 10

	## `opdracht(band, dag, N, cap, max_stroken)` -> {band, perRij, rijen, doel, cap}.
	## The ROOM is the boss: a row can never be wider than what still fits, so we
	## drop to the next table the band actually KNOWS (never a made-up number,
	## IDEAS.md) and only then squeeze the number of rows.
	## `cap` = how many beds still fit in the room, `max_stroken` = how many
	## strips the frame can show (the layout decides that, not the sum).
	static func opdracht(band: int, dag: int, n_gasten: int, cap: int,
			max_stroken: int) -> Dictionary:
		var s := Sommen.tafel(band, dag, n_gasten)
		var set: Array[int] = []
		for v in s["tafels"]:
			set.append(int(v))
		set.sort()
		if set.is_empty():
			set = [1, 2, 5, 10]
		var per_rij: int = maxi(1, mini(MAX_PER_RIJ, int(s["a"]) if int(s["a"]) != 0 else 2))
		var rijen: int = maxi(1, mini(MAX_RIJEN, int(s["b"]) if int(s["b"]) != 0 else 2))
		while per_rij > cap:
			var kleiner := 0
			for v in set:
				if v < per_rij and v <= cap:
					kleiner = v
			if kleiner == 0:
				per_rij = maxi(1, mini(per_rij, cap))
				break
			per_rij = kleiner
		var passend := cap / per_rij
		rijen = maxi(1, mini(mini(rijen, passend if passend != 0 else 1),
			mini(MAX_RIJEN, max_stroken - 1)))
		return {"band": int(s["band"]), "perRij": per_rij, "rijen": rijen,
			"doel": rijen * per_rij, "cap": cap}

	## The sliding wall (group 5 only): "3 rows of 7 = 2 x 7 + 1 x 7".  The 🚧
	## button splits the rows into `wand` and `rijen - wand`.
	static func wand(band: int, rijen: int) -> int:
		return rijen - 1 if (band >= 5 and rijen >= 2) else 0

	## One tap lowers the wall by one and wraps around.
	static func volgende_wand(huidig: int, rijen: int) -> int:
		return rijen - 1 if huidig - 1 < 1 else huidig - 1


## A5 — HET MEUBELBOEK (games-a.md §5.2/§5.3, games/meubels.js).
## The prices are HOTEL.md §4, whole euros; the star page is decoration and
## never arithmetic (there is always something to fetch).
class Meubels extends RefCounted:
	const WINKEL := [
		{"type": "plant", "icoon": "🪴", "naam": "plant", "prijs": 1, "plus": ""},
		{"type": "bakje", "icoon": "🍽", "naam": "voerbakje", "prijs": 2, "plus": ""},
		{"type": "mandje", "icoon": "🧺", "naam": "mandje", "prijs": 3, "plus": ""},
		{"type": "speelmand", "icoon": "🧶", "naam": "speelmand", "prijs": 4, "plus": ""},
		{"type": "bed", "icoon": "🛏", "naam": "bed", "prijs": 5, "plus": "+1 🐾"},
		{"type": "badkuip", "icoon": "🛁", "naam": "badkuip", "prijs": 8, "plus": ""},
	]
	const VERSIERING := [
		{"sleutel": "vlag", "icoon": "🎉", "naam": "vlaggetjes", "ster": 1},
		{"sleutel": "bloem", "icoon": "🌸", "naam": "bloemetje", "ster": 1},
		{"sleutel": "kussen", "icoon": "🩷", "naam": "kleurkussen", "ster": 2},
		{"sleutel": "slinger", "icoon": "🎈", "naam": "ballonslinger", "ster": 3},
		{"sleutel": "ster", "icoon": "⭐", "naam": "sterrensticker", "ster": 1},
	]
	const MUNTSOORT := [1, 2, 5, 10]

	## Two things together make the sum from group 4 on; group 3 buys one thing.
	static func max_lijst(band: int) -> int:
		return 2 if band >= 4 else 1

	## Money up to 20 (group 3 up to 10).
	static func buidel_max(band: int) -> int:
		return 20 if band >= 4 else 10

	## Group 3 pays exactly (too much = take a coin back); from group 4 there is
	## change: `betaald − prijs = ?`.
	static func wisselgeld(band: int) -> bool:
		return band >= 4

	## What goes into the purse: `max(totaal, min(munten, buidelMax()))`.
	## The rest stays in the till.  `Sommen.buidel(cap)` then guarantees that
	## every amount up to `cap` can be laid down exactly.
	static func buidel_cap(totaal: int, munten: int, band: int) -> int:
		return maxi(totaal, mini(munten, buidel_max(band)))

	static func prijs_van(type_naam: String) -> int:
		for w in WINKEL:
			if str(w["type"]) == type_naam:
				return int(w["prijs"])
		return 0


## A7 — DE VOERKAR (games-a.md §7.2, games/voerkar.js).
## The sum itself is the frozen `Sommen.deel(N, band, dag)`; what this class
## adds is the one line under it and the three "pak" buttons.
class Voerkar extends RefCounted:
	## How many biscuits come out of the bag per tap.
	const HAND := [1, 2, 5]

	static func volgende_hand(hand: int) -> int:
		var i := HAND.find(hand)
		return HAND[posmod(i + 1, HAND.size())]

	## The sum line under the two sentences.  Group 3 does not know the division
	## sign yet, and dividing WITH a remainder only starts in group 5 — so the
	## line stays empty unless it divides out.  The divisor follows from the
	## number of guests and may be 6, also in group 4: the OUTCOME comes from
	## `deel()` and stays inside the tables the band knows.
	static func som_regel(band: int, t: int, n_gasten: int, rest: int) -> String:
		if band >= 4 and rest == 0:
			return "%d : %d" % [t, n_gasten]
		return ""
