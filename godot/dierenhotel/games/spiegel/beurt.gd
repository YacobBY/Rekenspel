extends RefCounted
## spiegel — the numbers and the sentences of one turn of Spiegelmaskers
## (PLAN.md §3.7.2, M3).  Pure and static: no world, no ctx, so the tests can
## walk every band and every day without a turn running.
##
## THE MATHS IS THE GAME'S OWN.  `core/sommen.gd` is frozen; this file only
## READS `Sommen.Prng`, the seeded mulberry32 every game shares, so a day
## always gives the same mask and a reload the same question.
##
## A mask is a board of R rows × K columns with a fold line down the middle —
## and in groep 5 a second one across it.  One side is already stuck full of
## pink dots; the other side has to become its mirror image:
##   band 3 (groep 3): left L dots, right already R0 of their mirrors
##                     "how many more on the right?"          L − R0 =   (minus)
##   band 4 (groep 4): left L dots, right empty
##                     "how many dots will the mask have?"    L + L =    (doubling)
##   band 5 (groep 5): the top left quarter Q dots, the top right its mirror,
##                     the bottom half empty — two fold lines
##                     "how many dots will the mask have?"    Q × 4 =    (the table of 4)
## After the sum every missing dot is placed one by one, and each placement is
## a mirror question of its own: of three coloured marks on the empty side,
## which one is the mirror image of the dot that shines?  The wrong marks are
## the classic slips: the dot SHIFTED instead of mirrored, and the mirror one
## row off.  More guests, more dots (T grows with N, the one scale rule).

const ZAAD := 51329

## Child text, verbatim.  The pictogram is the card's `icoon`.
const ICOON := "🎭"
const ICOON_PLAK := "🪞"
const ICOON_AF := "✨"
const T_NOG := "Hoeveel stippen nog rechts?"              ## 4 woorden, 27 tekens
## Short enough for one line of the maths bar on a 360 wide phone (≈ 28
## characters, like oogst's questions): "Hoeveel stippen krijgt het masker?"
## and "Waar komt de stip in de spiegel?" were not, and the card floated.
const T_SAMEN := "Hoeveel stippen samen?"                 ## 3 woorden, 22 tekens
const T_PLAK := "Waar komt de spiegelstip?"               ## 4 woorden, 25 tekens
const T_AF := "Het masker is af!"                         ## 4 woorden, 17 tekens
const T_AF2 := "%d stippen, links en rechts gelijk"       ## 6 woorden
const T_AF2_VIER := "%d stippen, in alle vier gelijk"     ## 6 woorden
const T_LEEG := "nog geen gasten"
const T_MOOI := "mooi!"
const ICOON_MOOI := "😍"
const T_KNOP := "Maskers"
const T_TITEL := "Maak een masker"

## The three marks on the board and their buttons on the strip: a heart and
## the colour's own word (HOTEL.md §9: pictogram AND word).
const MERKEN := [
	{"id": "blauw", "icoon": "💙", "tekst": "blauw"},
	{"id": "groen", "icoon": "💚", "tekst": "groen"},
	{"id": "geel", "icoon": "💛", "tekst": "geel"},
]

## The mask of today.
##   `band`, `R` rows, `K` columns, `as`: "v" (one fold line down the middle)
##   or "vh" (and one across), `stip`: the dots already on it, `doel`: the
##   dots to place, in the order they are asked, each `{cel, bron, merk}` —
##   the cell it goes to, its twin that shines while it is asked, and the
##   three marked cells in the order blauw, groen, geel —, `goed`: the answer
##   of the sum, `som`: the sum line, `basis`: the dots on the board before
##   the first one is placed, `liever`: the wrong answers the strip prefers.
static func opzet(n: int, band: int, dag: int) -> Dictionary:
	var b := clampi(band, 3, 5)
	var gasten := maxi(1, n)
	var rnd := Sommen.Prng.new(ZAAD + dag * 7919 + gasten * 131 + b * 17)
	var r := 4
	var k := 4 if b == 3 else 6
	var h := k / 2
	var as_ := "vh" if b == 5 else "v"
	var o := {"band": b, "R": r, "K": k, "as": as_}
	var stip: Array = []
	var doel: Array = []
	match b:
		3:
			# left: L of the 8 cells; right: R0 of their mirrors already there
			var l := clampi(3 + gasten / 3 + int(rnd.volgende() * 2.0), 3, 5)
			var links := _kies(rnd, _cellen(0, r, 0, h), l)
			var r0 := clampi(1 + int(rnd.volgende() * 2.0), 1, l - 2)
			for i in links.size():
				stip.append(links[i])
			for i in links.size():
				var m := spiegel_v(links[i], k)
				if i < r0:
					stip.append(m)
				else:
					doel.append({"cel": m, "bron": links[i]})
			o["goed"] = l - r0
			o["som"] = "%d − %d =" % [l, r0]
			o["liever"] = [l, l + r0, r0]
			o["basis"] = l + r0
		4:
			var l := clampi(3 + gasten / 3 + int(rnd.volgende() * 2.0), 3, 6)
			var links := _kies(rnd, _cellen(0, r, 0, h), l)
			for c in links:
				stip.append(c)
				doel.append({"cel": spiegel_v(c, k), "bron": c})
			o["goed"] = 2 * l
			o["som"] = "%d + %d =" % [l, l]
			o["liever"] = [l, 2 * l + 1, 2 * l - 2]
			o["basis"] = l
		_:
			var q := clampi(2 + gasten / 4 + int(rnd.volgende() * 2.0), 2, 3)
			var kwart := _kies(rnd, _cellen(0, r / 2, 0, h), q)
			var boven: Array = []
			for c in kwart:
				boven.append(c)
			for c in kwart:
				boven.append(spiegel_v(c, k))
			for c in boven:
				stip.append(c)
			# the bottom half, the left dots first: the second fold
			for c in boven:
				doel.append({"cel": spiegel_h(c, r), "bron": c})
			o["goed"] = 4 * q
			o["som"] = "%d × 4 =" % q
			o["liever"] = [3 * q, q + 4, 2 * q]
			o["basis"] = 2 * q
	# every mark in its own place: the right one, the slips, then any free cell
	var bezet := {}
	for c in stip:
		bezet[_sleutel(c)] = true
	for d in doel:
		bezet[_sleutel(d["cel"])] = true
	var vorige := -1
	for i in doel.size():
		var d: Dictionary = doel[i]
		var foute := _slips(d, o, stip, doel, i)
		var drie: Array = [d["cel"]]
		for f in foute:
			if drie.size() < 3 and not _bevat(drie, f):
				drie.append(f)
		# the colour of the right one changes from dot to dot — never the same
		# colour twice in a row, or a child just taps that colour again
		var volgorde := [0, 1, 2]
		_schud(rnd, volgorde)
		if int(volgorde[0]) == vorige:
			var j := 1 + int(rnd.volgende() * 2.0)
			var t = volgorde[0]
			volgorde[0] = volgorde[j]
			volgorde[j] = t
		vorige = int(volgorde[0])
		var merk: Array = [null, null, null]
		for j in 3:
			merk[volgorde[j]] = drie[j]
		d["merk"] = merk
		d["goed"] = int(volgorde[0])
	o["stip"] = stip
	o["doel"] = doel
	return o

## The mirror of a cell over the fold line down the middle.
static func spiegel_v(c: Array, k: int) -> Array:
	return [int(c[0]), k - 1 - int(c[1])]

## The mirror of a cell over the fold line across the middle.
static func spiegel_h(c: Array, r: int) -> Array:
	return [r - 1 - int(c[0]), int(c[1])]

## Two wrong marks for dot `i`, both empty when it is asked and on the side
## that is being filled: the dot SHIFTED across the fold instead of mirrored,
## the mirror one row (or column) off, and then any other free cell there.
static func _slips(d: Dictionary, o: Dictionary, stip: Array, doel: Array, i: int) -> Array:
	var r := int(o["R"])
	var k := int(o["K"])
	var h := k / 2
	var cel: Array = d["cel"]
	var bron: Array = d["bron"]
	var kandidaten: Array = []
	var zijde: Array = []
	if str(o["as"]) == "vh":
		kandidaten.append([int(bron[0]) + r / 2, int(bron[1])] if int(bron[0]) < r / 2 else [int(bron[0]) - r / 2, int(bron[1])])
		kandidaten.append([int(cel[0]), int(cel[1]) + 1])
		kandidaten.append([int(cel[0]), int(cel[1]) - 1])
		zijde = _cellen(r / 2, r, 0, k)
	else:
		kandidaten.append([int(bron[0]), int(bron[1]) + h])
		kandidaten.append([int(cel[0]) + 1, int(cel[1])])
		kandidaten.append([int(cel[0]) - 1, int(cel[1])])
		zijde = _cellen(0, r, h, k)
	for c in zijde:
		kandidaten.append(c)
	# empty right now: not a dot on the board, not a dot placed before this one
	var vol := {}
	for c in stip:
		vol[_sleutel(c)] = true
	for j in i:
		vol[_sleutel((doel[j] as Dictionary)["cel"])] = true
	var uit: Array = []
	for c in kandidaten:
		if int(c[0]) < 0 or int(c[0]) >= r or int(c[1]) < 0 or int(c[1]) >= k:
			continue
		if not _bevat(zijde, c) or vol.has(_sleutel(c)) or _zelfde(c, cel) or _bevat(uit, c):
			continue
		uit.append(c)
	return uit

## Every cell [row, column] in rows r0..r1 − 1 and columns k0..k1 − 1.
static func _cellen(r0: int, r1: int, k0: int, k1: int) -> Array:
	var uit: Array = []
	for rij in range(r0, r1):
		for kol in range(k0, k1):
			uit.append([rij, kol])
	return uit

## `n` different cells out of `uit`, in reading order (top to bottom, left to
## right), so the dots are asked the way a child reads the board.
static func _kies(rnd, uit: Array, n: int) -> Array:
	var pot := uit.duplicate()
	_schud(rnd, pot)
	var keuze := pot.slice(0, mini(n, pot.size()))
	keuze.sort_custom(func(a, b) -> bool:
		return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1])))
	return keuze

static func _schud(rnd, a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := int(rnd.volgende() * float(i + 1))
		var t = a[i]
		a[i] = a[j]
		a[j] = t

static func _sleutel(c: Array) -> String:
	return "%d,%d" % [int(c[0]), int(c[1])]

static func _zelfde(a: Array, b: Array) -> bool:
	return int(a[0]) == int(b[0]) and int(a[1]) == int(b[1])

static func _bevat(lijst: Array, c: Array) -> bool:
	for x in lijst:
		if _zelfde(x, c):
			return true
	return false

## The first line of the sum card for this band.
static func vraag(o: Dictionary) -> String:
	return T_NOG if int(o["band"]) == 3 else T_SAMEN

## The last line when the mask is done.
static func af2(o: Dictionary, totaal: int) -> String:
	return (T_AF2_VIER if str(o["as"]) == "vh" else T_AF2) % totaal
