class_name JsGetal
extends RefCounted
## JavaScript integer semantics, reproduced exactly.
##
## The frozen number core of the HTML game (state.js, sleutels.js, rooms.js,
## world.js) leans on three JavaScript behaviours that GDScript does NOT share:
##
##  1. `x >>> 0` / `x | 0` — ToUint32 / ToInt32 on a **float64**, i.e. truncate
##     toward zero and take it modulo 2^32.  A product that does not fit in 53
##     bits is rounded *before* the truncation, so the low bits are lost.  See
##     `dagRnd` below: the naive 64-bit integer port gives 678745307 where the
##     browser gives 678745088.  Byte identity therefore needs the float path.
##  2. `Math.imul(a, b)` — a true 32-bit signed multiply of the low 32 bits.
##  3. `Math.round(x)` — halves go toward +infinity (`-0.5` -> `0`), where
##     GDScript's `round()` sends halves away from zero (`-0.5` -> `-1`).
##
## Every port of a frozen function must go through these helpers.

const U32 := 4294967296  ## 2^32

## `x >>> 0` where x is an integer expression that stays inside 53 bits.
static func u32(v: int) -> int:
	return v & 0xFFFFFFFF

## `x | 0` — the signed 32-bit view of the same bits.
static func i32(v: int) -> int:
	var u := v & 0xFFFFFFFF
	return u - U32 if u >= 2147483648 else u

## `Math.imul(a, b)`.  The 64-bit product may wrap; only the low 32 bits matter.
static func imul(a: int, b: int) -> int:
	return i32(i32(a) * i32(b))

## `x >>> 0` where x is a float64 that may exceed 2^53 (ToUint32 in the spec).
static func to_uint32(x: float) -> int:
	if not is_finite(x):
		return 0
	var t := floorf(absf(x))
	t = fmod(t, float(U32))
	var n := int(t)
	if x < 0.0:
		n = (-n) & 0xFFFFFFFF
	return n & 0xFFFFFFFF

## `Math.round(x)` — halves toward +infinity.
static func rond(x: float) -> int:
	return int(floorf(x + 0.5))

## `Math.floor` / `Math.ceil` on a float, returned as an int.
static func vloer(x: float) -> int:
	return int(floorf(x))

static func plafond(x: float) -> int:
	return int(ceilf(x))
