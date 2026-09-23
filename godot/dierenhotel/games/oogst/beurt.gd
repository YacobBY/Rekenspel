extends RefCounted
## oogst — the numbers and the sentences of one turn (games-c.md §2.3, §2.9).
## Pure and static: no world, no ctx, so the tests can walk every band and
## every day without a turn running.
##
## THE MATHS IS THE GAME'S OWN.  `core/sommen.gd` is frozen (PLAN.md R8); this
## file only READS `Sommen.Prng`, the seeded mulberry32 every game shares, so a
## day always gives the same table and a reload the same question.
##
## A turn is place value on a table of punnets of ten (the ten-frame and the
## hundred-field of the Dutch classroom):
##   band 3 (groep 3):  0 or 1 full punnet and one open one  -> tot 20;
##                      how many to fill the open punnet     -> splitsen tot 10
##   band 4 (groep 4):  2 … 5 full punnets and one open one  -> tot 100;
##                      how many to fill the open punnet     -> aanvullen tot het tiental
##   band 5 (groep 5):  5 … 8 full punnets and one open one  -> tot 100;
##                      how many until all ten punnets are full -> aanvullen tot 100
## The number of full punnets grows with the hotel: one punnet per guest but
## the guest of the turn, whose punnet is the open one (T = 10·(N − 1) + r).

const ZAAD := 60617

## Child text, verbatim (games-c.md §2.9).  The pictogram is the card's `icoon`.
const ICOON := "🍓"
const T_TEL := "Hoeveel aardbeien liggen er?"            ## 4 woorden, 28 tekens
const T_TEL2 := "Een vol bakje heeft 10 aardbeien"       ## 6 woorden, 32 tekens
const T_BIJ := "Hoeveel passen er nog bij?"              ## 5 woorden, 26 tekens
## Not "Hoeveel nog tot 100 aardbeien?": one line too wide for the maths bar
## of a 360-wide phone, and the card floated over the room (the 🍓 says what).
const T_HONDERD := "Hoeveel nog tot 100?"                ## 4 woorden, 20 tekens
const T_PLUK := "Pluk er nog %d"                         ## 4 woorden
const T_AF := "Alle bakjes zijn vol!"                    ## 4 woorden, 21 tekens
const T_AF2 := "%d aardbeien voor de gasten"             ## 5 woorden
const T_LEEG := "nog geen gasten"
const T_LEKKER := "lekker!"
const T_PLUK_KNOP := "Pluk"
const T_PLUK10_KNOP := "Pluk een bakje"
const T_PLUK_TITEL := "pluk een aardbei"
const T_PLUK10_TITEL := "pluk een heel bakje vol"
const T_SPOOK := "zoveel is het"
const ICOON_PLUK10 := "🧺"
const ICOON_HULP := "💛"
const ICOON_AF := "✅"
const ICOON_LEKKER := "😋"

## The table of today.  `vol` full punnets, one open punnet with `los` berries,
## `doel` punnets that are full at the end of the turn, and `nodig` berries to
## pick to get there.
static func opzet(n: int, band: int, dag: int) -> Dictionary:
	var b := clampi(band, 3, 5)
	var gasten := maxi(1, n)
	var rnd := Sommen.Prng.new(ZAAD + dag * 7919 + gasten * 131 + b * 17)
	var vol := 0
	var los := 0
	match b:
		3:
			# alternating: a lone open punnet (subitising in the ten-frame, tot
			# 10) and one full punnet beside it (the numbers 11 … 19)
			vol = 0 if gasten == 1 or (dag + gasten) % 2 == 0 else 1
			los = (3 if vol == 0 else 1) + int(rnd.volgende() * (7.0 if vol == 0 else 9.0))
		4:
			vol = clampi(gasten - 1, 2, 5)
			los = 1 + int(rnd.volgende() * 9.0)
		_:
			vol = clampi(gasten - 1, 5, 8)
			los = 1 + int(rnd.volgende() * 9.0)
	los = clampi(los, 1, 9)
	var t := 10 * vol + los
	var doel := 10 if b == 5 else vol + 1
	return {"band": b, "vol": vol, "los": los, "T": t, "doel": doel,
		"nodig": doel * 10 - t}

## The four answers of the first question: the right one, the digits turned
## round (the Dutch slip: "veertien" is four-ten, so 14 becomes 41), the digits
## added, and one punnet too many.
static func liever_tel(o: Dictionary) -> Array:
	var vol := int(o["vol"])
	var los := int(o["los"])
	var t := int(o["T"])
	var uit: Array = []
	if vol > 0 and los != vol:
		uit.append(10 * los + vol)
	uit.append(vol + los if vol > 0 else 10 - los)
	uit.append(t + 10)
	return uit

## ... and of the second: what is already in the punnet, a whole punnet, and
## (band 5) only the ones or only the tens.
static func liever_bij(o: Dictionary) -> Array:
	var los := int(o["los"])
	var nodig := int(o["nodig"])
	if int(o["band"]) >= 5:
		return [10 - los, 100 - 10 * int(o["vol"]), nodig + 10]
	return [los, 10, nodig + 1]

## The second question: to the full punnet, or to a hundred.
static func vraag_bij(o: Dictionary) -> Array:
	return [T_HONDERD] if int(o["band"]) >= 5 else [T_BIJ]

## ... and its sum line, the missing addend written out with the gap the key
## board uses (`__`, games-a.md §4): `7 + __ = 10`, `63 + __ = 100`.  Never
## a "?" between two expressions (HOTEL.md §9).
static func som_bij(o: Dictionary) -> String:
	if int(o["band"]) >= 5:
		return "%d + __ = 100" % int(o["T"])
	return "%d + __ = 10" % int(o["los"])

## The berries on the table right now: one entry per place, -1 = no punnet.
## The full punnets first, then the open one, then (band 5) the punnets that
## picking filled, and the empty punnets still to fill.
static func bakjes(o: Dictionary, geplukt: int) -> Array:
	var vol := int(o["vol"])
	var los := int(o["los"])
	var doel := int(o["doel"])
	var b: Array = []
	for i in 10:
		b.append(-1)
	for i in vol:
		b[i] = 10
	var in_open := mini(10 - los, maxi(0, geplukt))
	b[vol] = los + in_open
	var extra := maxi(0, geplukt - (10 - los))
	for i in range(vol + 1, doel):
		var n := mini(10, maxi(0, extra - (i - vol - 1) * 10))
		b[i] = n
	return b

## What one tap on the planter picks: one berry while the open punnet is not
## full, then (band 5, towards a hundred) a whole punnet at a time — the
## strategy "via the ten" made physical.
static func pluk_stap(o: Dictionary, geplukt: int) -> int:
	var rest := int(o["nodig"]) - geplukt
	if rest <= 0:
		return 0
	var tot_vol := (10 - int(o["los"])) - geplukt
	if tot_vol > 0:
		return 1
	return mini(10, rest)

## Counting on together (the help ladder, step 1 and 2).
static func hulp_tel(o: Dictionary) -> String:
	var vol := int(o["vol"])
	var los := int(o["los"])
	if vol == 0:
		if los > 5:
			return "5 en nog %d" % (los - 5)
		return " … ".join(_reeks(1, los, 1))
	var l := PackedStringArray()
	for i in vol:
		l.append(str(10 * (i + 1)))
	return " … ".join(l) + " en nog %d" % los

static func hulp_bij(o: Dictionary) -> String:
	var t := int(o["T"])
	if int(o["band"]) >= 5:
		var l := PackedStringArray([str(t)])
		var v := (int(t / 10.0) + 1) * 10
		while v <= 100:
			l.append(str(v))
			v += 10
		return " ▸ ".join(l)
	return " … ".join(_reeks(int(o["los"]) + 1, 10, 1))

## The third step: the answer shown in pale numbers on the table.
static func spook_tel(o: Dictionary) -> String:
	if int(o["vol"]) == 0:
		return "5 + %d" % (int(o["los"]) - 5) if int(o["los"]) > 5 else str(int(o["los"]))
	return "%d + %d" % [10 * int(o["vol"]), int(o["los"])]

static func spook_bij(o: Dictionary) -> String:
	var los := int(o["los"])
	if int(o["band"]) >= 5:
		return "%d + %d" % [10 - los, 100 - 10 * (int(o["vol"]) + 1)]
	return "+%d" % (10 - los)

static func _reeks(van: int, tot: int, stap: int) -> PackedStringArray:
	var uit := PackedStringArray()
	var v := van
	while v <= tot:
		uit.append(str(v))
		v += stap
	return uit
