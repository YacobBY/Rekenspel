extends RefCounted
## De post sorteren — de getallen en de zinnen van één beurt (U4, 2026-10-07).
## Puur en statisch: geen wereld, geen ctx, zodat de tests elke groep en elke
## dag kunnen aflopen zonder dat er een beurt loopt.  `core/sommen.gd` blijft
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
## brieven (één per gast, 2..6) en verschuift het venster van de dag.  Een
## tweede beurt op dezelfde dag (`ronde`) krijgt een nieuwe stapel bij dezelfde
## vakjes.  Binnen één stapel staat elke brief er één keer.

# ------------------------------------------------------------------ zinnen

## Child-facing strings (HOTEL.md §9: ≤ 8 words AND ≤ 40 characters with the
## pictogram in front).  📮 ✉ 📬 are NOT in the bundled font subset
## (`fonts/tekens.txt`, `Ui.mist_tekens`); 💌 is — the hotel's own post
## pictogram ("💌 Er is post!", the letter wall).
const ICOON := "💌"
const ICOON_AF := "✅"
const T_KNOP := "Post"                              ## the entry on the cart
const T_TAAK := "Sorteer de post"                   ## the board card, ≤ 6 words
const T_VRAAG := "In welk vakje hoort deze brief?"  ## 💌 + 31 = 33 tekens, 7 woorden
const T_KEUZE_TITEL := "kies een vakje"
const T_AF := "Alle post is gesorteerd!"            ## ✅ + 24 = 26 tekens, 5 woorden
const T_TITEL := "de postkar"

# ------------------------------------------------------------------ getallen

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

## The plate on a hole: both numbers, so the hole shows its own range.  A
## hyphen, as on a street sign ("huisnummers 1 - 15"); the sums of this game
## never show a minus, and the hotel writes its minus as "−" (U+2212).
static func plaat(vak: Dictionary) -> String:
	return "%d - %d" % [int(vak["van"]), int(vak["tot"])]

## The same plate without the spaces.
static func kort(vak: Dictionary) -> String:
	return "%d-%d" % [int(vak["van"]), int(vak["tot"])]

## A hole's button on the strip: the post's pictogram and the words of its
## plate (HOTEL.md §9: pictogram AND word), "💌 30 - 39".
static func knop(vak: Dictionary) -> String:
	return "%s %s" % [ICOON, plaat(vak)]

## The same button when the strip has to take its short words (a phone): the
## pictogram over the numbers, so four of them fit the phone's maths bar
## (69 units a button there; "💌 30-39" on one line needs about 100).
static func knop_kort(vak: Dictionary) -> String:
	return "%s\n%s" % [ICOON, kort(vak)]

## What the letter on top of the pile shows in the world: "💌 34", "💌 7 × 8".
static func adres(brief_: Dictionary) -> String:
	return "%s %s" % [ICOON, str(brief_.get("tekst", ""))]

## Letter `i` of the day: {getal, tekst, vak}.  `tekst` is what the letter
## shows — the number itself, or in groep 5 the keersom that makes it.
static func brief(band: int, n: int, dag: int, i: int, ronde: int = 0) -> Dictionary:
	var vakken := vakjes(band, n, dag)
	if band <= 3:
		var g := 1 + posmod(i * 7 + dag * 3 + n + ronde * 11, 20)
		return {"getal": g, "tekst": str(g), "vak": vak_van(g, vakken)}
	var a := venster(n, dag)
	var laag := 10 * a
	var hoog := laag + 39
	if band >= 5:
		var paren := _tafels_in(laag, hoog)
		if not paren.is_empty():
			var p: Vector2i = paren[posmod(i * 5 + dag * 3 + n + ronde * 7, paren.size())]
			var g5 := p.x * p.y
			return {"getal": g5, "tekst": "%d × %d" % [p.x, p.y], "vak": vak_van(g5, vakken)}
	var g4 := laag + posmod(i * 13 + dag * 7 + n * 3 + ronde * 17, 40)
	return {"getal": g4, "tekst": str(g4), "vak": vak_van(g4, vakken)}

## Every k × m of the tables (2..10 × 2..10) whose product lies in [laag, hoog].
static func _tafels_in(laag: int, hoog: int) -> Array:
	var uit: Array = []
	for k in range(2, 11):
		for m in range(2, 11):
			if k * m >= laag and k * m <= hoog:
				uit.append(Vector2i(k, m))
	return uit

## The whole turn: the holes and the pile, in the order the child gets them.
## Every letter of one pile is a different letter (a text that came up already
## is skipped), so the child never sorts the same letter twice in a row.
static func maak(band: int, n_gasten: int, dag: int, ronde: int = 0) -> Dictionary:
	var n := aantal(n_gasten)
	var brieven: Array = []
	var gehad := {}
	var i := 0
	while brieven.size() < n and i < 200:
		var br := brief(band, n, dag, i, ronde)
		i += 1
		if gehad.has(str(br["tekst"])):
			continue
		gehad[str(br["tekst"])] = true
		brieven.append(br)
	return {"vakjes": vakjes(band, n, dag), "brieven": brieven}

## How many letters lie in each hole once the first `klaar` letters are sorted.
static func vol(brieven: Array, klaar: int) -> Array:
	var uit: Array = []
	for j in VAKJES:
		uit.append(0)
	for k in mini(klaar, brieven.size()):
		var j := int((brieven[k] as Dictionary).get("vak", -1))
		if j >= 0 and j < VAKJES:
			uit[j] = int(uit[j]) + 1
	return uit
