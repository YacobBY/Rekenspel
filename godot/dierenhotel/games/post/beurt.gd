extends RefCounted
## De post sorteren — de getallen van één beurt (U4, 2026-10-07).  Puur en
## statisch: geen wereld, geen ctx, zodat de tests elke groep en elke dag
## kunnen aflopen zonder dat er een beurt loopt.  `core/sommen.gd` blijft
## bevroren; dit bestand leest niets daaruit.
##
## De vakkenkast is een GETALLENLIJN in vier stukken (de vakjes); de vraag is
## altijd dezelfde: "💌 In welk vakje hoort deze brief?"  Wat op de brief staat
## en hoe groot de vakjes zijn, bepaalt de groep:
##
##   groep 3  getallen tot 20, vakjes van vijf: 1-5 · 6-10 · 11-15 · 16-20;
##            op de brief staat een los getal 1..20.
##   groep 4  getallen tot 100, vakjes van TIEN, een venster van vier
##            tientallen (a0-a9 … d0-d9, a uit 0..6); op de brief een getal
##            uit dat venster — tientallen en eenheden ("tussen 30 en 40").
##   groep 5  hetzelfde venster, maar op de brief staat een KEERSOM uit de
##            tafels (k × m, 2..10) waarvan het product in het venster valt.
##
## Eén schaalregel (HOTEL.md §3): N = het aantal gasten geeft het aantal
## brieven (één per gast, 2..6) en verschuift het venster van de dag.

const VAKJES := 4
const MIN_BRIEVEN := 2
const MAX_BRIEVEN := 6

## One letter per guest, never fewer than two or more than six.
static func aantal(n_gasten: int) -> int:
	return clampi(n_gasten, MIN_BRIEVEN, MAX_BRIEVEN)

## The first ten of the groep 4/5 window: shifts with the day and the guests.
static func venster(n: int, dag: int) -> int:
	return posmod(n + dag, 7)

## The four pigeonholes, left to right: [{van, tot}, …].
static func vakjes(band: int, n: int, dag: int) -> Array:
	var uit: Array = []
	if band <= 3:
		for j in VAKJES:
			uit.append({"van": 1 + 5 * j, "tot": 5 + 5 * j})
	else:
		var a := venster(n, dag)
		for j in VAKJES:
			uit.append({"van": 10 * (a + j), "tot": 10 * (a + j) + 9})
	return uit

## Which hole a number belongs in (index into `vakjes`), −1 when none.
static func vak_van(getal: int, vakken: Array) -> int:
	for j in vakken.size():
		var v: Dictionary = vakken[j]
		if getal >= int(v["van"]) and getal <= int(v["tot"]):
			return j
	return -1

## The plate on a hole: both numbers, so the hole shows its own range.
static func plaat(vak: Dictionary) -> String:
	return "%d - %d" % [int(vak["van"]), int(vak["tot"])]

## Letter `i` of the day: {getal, tekst, vak}.  `tekst` is what the letter
## shows — the number itself, or in groep 5 the keersom that makes it.
static func brief(band: int, n: int, dag: int, i: int) -> Dictionary:
	var vakken := vakjes(band, n, dag)
	if band <= 3:
		var g := 1 + posmod(i * 7 + dag * 3 + n, 20)
		return {"getal": g, "tekst": str(g), "vak": vak_van(g, vakken)}
	var a := venster(n, dag)
	var laag := 10 * a
	var hoog := laag + 39
	if band >= 5:
		var paren := _tafels_in(laag, hoog)
		if not paren.is_empty():
			var p: Vector2i = paren[posmod(i * 5 + dag * 3 + n, paren.size())]
			var g5 := p.x * p.y
			return {"getal": g5, "tekst": "%d × %d" % [p.x, p.y], "vak": vak_van(g5, vakken)}
	var g4 := laag + posmod(i * 13 + dag * 7 + n * 3, 40)
	return {"getal": g4, "tekst": str(g4), "vak": vak_van(g4, vakken)}

## Every k × m of the tables (2..10 × 2..10) whose product lies in [laag, hoog].
static func _tafels_in(laag: int, hoog: int) -> Array:
	var uit: Array = []
	for k in range(2, 11):
		for m in range(2, 11):
			if k * m >= laag and k * m <= hoog:
				uit.append(Vector2i(k, m))
	return uit

## The whole day: the holes and the pile, in the order the child gets them.
static func maak(band: int, n_gasten: int, dag: int) -> Dictionary:
	var n := aantal(n_gasten)
	var brieven: Array = []
	for i in n:
		brieven.append(brief(band, n, dag, i))
	return {"vakjes": vakjes(band, n, dag), "brieven": brieven}
