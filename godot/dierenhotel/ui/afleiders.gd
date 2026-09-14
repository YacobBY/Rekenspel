class_name Afleiders
extends RefCounted
## Four answers to choose from for a number question, exactly one of them right
## (owner, 2026-09-14: "altijd alles multiple choice met max 4 opties", one tap
## answers, there is no ✓ key any more).
##
## The wrong ones are the slips a child really makes, in this order:
##   1. what the game names in `liever` (the two numbers in the sum, the price
##      instead of the change, …) — the same "numbers you can see" rule as the
##      frozen `Sommen.Zwembad.keuze_getallen`;
##   2. neighbours of the answer (± 1, 2, 10, 3, 5, 4), in an order drawn from
##      the seed, so the right button is not always the second from the left;
##   3. counting on from the answer, as filler.
## Never below `min` (0), never above `max`, never a duplicate; the strip is
## sorted, so the child reads it like a number line.  Same seed, same strip:
## after a slip the card comes back with the very same four choices.

const AANTAL := 4
const BUREN: Array[int] = [1, -1, 2, -2, 10, -10, 3, -3, 5, -5, 4, -4]

static func vier(goed: int, zaad: int, o: Dictionary = {}) -> Array[int]:
	var laag: int = int(o.get("min", 0))
	var hoog: int = int(o.get("max", 99))
	var uit: Array[int] = [goed]
	var neem := func(v: int) -> void:
		if uit.size() < AANTAL and v >= laag and v <= hoog and not uit.has(v):
			uit.append(v)
	for v in o.get("liever", []):
		neem.call(int(v))
	var rnd := Sommen.Lcg31.new(zaad * 31 + goed * 7 + 1)
	var buren: Array[int] = BUREN.duplicate()
	for i in range(buren.size() - 1, 0, -1):
		var j: int = mini(i, int(rnd.volgende() * float(i + 1)))
		var t := buren[i]
		buren[i] = buren[j]
		buren[j] = t
	for b in buren:
		neem.call(goed + b)
	var v2 := goed + 1
	while uit.size() < AANTAL and v2 <= hoog:
		neem.call(v2)
		v2 += 1
	v2 = goed - 1
	while uit.size() < AANTAL and v2 >= laag:
		neem.call(v2)
		v2 -= 1
	uit.sort()
	return uit
