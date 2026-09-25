extends RefCounted
class_name ArtDecorSpeelzaal

## Speelzaal-decor: klimrek, ballenbak, blokkentoren, kussenhoek, muziekdoos
## en wimpel.  Eigen namen en een eigen tabel, aangemeld bij ArtDecor._extra();
## de basis-NAMEN van ArtDecor blijven ongemoeid (test_art telt ze).
## Stijl volgt decor_wasserij.gd: bx/ell, kleuren uit ArtDecor.

const KUSSEN := ArtDecor.KUSSEN
const METAAL := ArtDecor.METAAL
const HOUT := ArtDecor.HOUT
const HOUT_D := ArtDecor.HOUT_D
const DOOS := Color("#E8C48A")
const DOOS_D := Color("#C89A5E")
const TOUCH := Color("#F2A65A")
const TOUCH_D := Color("#D98A3E")

const NAMEN: Array[String] = ["klimrek", "ballenbak", "blokkentoren", "kussenhoek",
	"muziekdoos", "wimpel"]

## Klimrek: een torentje op vier palen met een vloertje erop, een leuning
## rond de achterkant, een ladder met metalen sporten TUSSEN twee palen aan de
## rechterkant en een glijbaan die schuin naar voren omlaag loopt (eigenaar,
## 2026-09-25: "De speelzaal lijkt momenteel kapot" — de sporten staken dwars
## door de palen en de glijplank lag plat op de vloer).
const TOREN := 8            ## halve breedte van het torentje
const VLONDER := 14         ## hoogte van het vloertje
const PAAL := 26            ## hoogte van de palen
const GLIJ := 20            ## zo ver loopt de glijbaan naar voren
const GLIJ_BREED := 8
static func klimrek(_p := {}) -> Array:
	var v: Array = []
	var t := TOREN
	for px in [-t, t - 2]:
		for pz in [-t, t - 2]:
			ArtVorm.bx(v, px, 0, pz, 2, PAAL, 2, HOUT_D)                 # paal
	ArtVorm.bx(v, -t, VLONDER, -t, 2 * t, 2, 2 * t, HOUT)                 # vloertje
	# de leuning langs de twee achterkanten, op de palen
	ArtVorm.bx(v, -t, PAAL - 2, -t, 2 * t, 2, 2, HOUT)
	ArtVorm.bx(v, -t, PAAL - 2, -t, 2, 2, 2 * t, HOUT)
	for i in 3:
		ArtVorm.bx(v, -t + 4 + 4 * i, VLONDER + 2, -t, 1, PAAL - VLONDER - 4, 1, HOUT_D)
		ArtVorm.bx(v, -t, VLONDER + 2, -t + 4 + 4 * i, 1, PAAL - VLONDER - 4, 1, HOUT_D)
	# de ladder aan de rechterkant: dunne sporten van paal tot paal
	for ry in range(3, VLONDER, 4):
		ArtVorm.bx(v, t - 1, ry, -t + 2, 1, 1, 2 * t - 4, METAAL)
	# de glijbaan: van de voorrand van het vloertje schuin omlaag naar voren,
	# een goot tussen twee hoge randen — de randen dekken de trapjes van de
	# voxels af, zodat hij als één gladde baan leest — en een uitloop
	var x0 := -GLIJ_BREED / 2 - 1
	for k in GLIJ:
		var y := VLONDER - int(round(float(k) * float(VLONDER - 1) / float(GLIJ - 1)))
		ArtVorm.bx(v, x0, y - 1, t + k, GLIJ_BREED, 2, 1, TOUCH)
		ArtVorm.bx(v, x0 - 1, y - 1, t + k, 1, 5, 1, TOUCH_D)
		ArtVorm.bx(v, x0 + GLIJ_BREED, y - 1, t + k, 1, 5, 1, TOUCH_D)
	ArtVorm.bx(v, x0 - 1, 0, t + GLIJ, GLIJ_BREED + 2, 2, 4, TOUCH_D)
	ArtVorm.bx(v, x0, 1, t + GLIJ, GLIJ_BREED, 1, 4, TOUCH)
	return v

## Ballenbak: ondiepe bak vol ballen in vier kleuren.
static func ballenbak(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -16, 0, -12, 32, 5, 24, DOOS_D)                   # bodem
	ArtVorm.bx(v, -16, 4, -13, 32, 5, 2, DOOS)                       # randen
	ArtVorm.bx(v, -16, 4, 11, 32, 5, 2, DOOS)
	ArtVorm.bx(v, -17, 4, -11, 2, 5, 22, DOOS)
	ArtVorm.bx(v, 15, 4, -11, 2, 5, 22, DOOS)
	var bollen := [Color("#E4572E"), Color("#35A7FF"), Color("#FFC93C"), Color("#7BC950")]
	var pos := [[-9, -5], [0, -8], [9, -3], [-5, 4], [5, 6], [11, 7], [-11, 8], [2, 0]]
	for i in range(pos.size()):
		ArtVorm.ell(v, float(pos[i][0]), 8.0, float(pos[i][1]), 3.4, 3.2, 3.4, bollen[i % 4], {"e": 2.6, "ymin": 5})
	return v

## Blokkentoren: opgetapelde bouwblokken in drie kleuren.
static func blokkentoren(_p := {}) -> Array:
	var v: Array = []
	var kl := [Color("#C94F4F"), Color("#4A7FBF"), Color("#E8B84B")]
	var maten := [[10, 10], [9, 9], [8, 8], [6, 6], [5, 5]]
	var y := 0
	for i in range(maten.size()):
		var s: int = maten[i][0]
		var d: int = maten[i][1]
		ArtVorm.bx(v, -s / 2, y, -d / 2, s, 6, d, kl[i % 3])
		y += 6
	return v

## Kussenhoek: drie kussens opgestapeld, één ernaast.
static func kussenhoek(_p := {}) -> Array:
	var v: Array = []
	var kussens := [KUSSEN, Color("#F2C14E"), Color("#79B8A0")]
	var maten := [[14, 14], [12, 12], [10, 10]]
	var y := 0
	for i in range(3):
		var m: int = maten[i][0]
		ArtVorm.bx(v, -m / 2, y, -m / 2, m, 4, m, kussens[i])
		y += 4
	ArtVorm.bx(v, 8, 0, 6, 9, 3, 9, kussens[2])                     # ernaast
	return v

## Muziekdoos: een doos met een draaiend poppetje erboven.
static func muziekdoos(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -8, 0, -8, 16, 9, 16, DOOS)                       # doos
	ArtVorm.bx(v, -9, 8, -9, 18, 2, 18, DOOS_D)                     # deksel-rand
	ArtVorm.bx(v, -1, 10, -1, 2, 5, 2, METAAL)                       # as
	ArtVorm.bx(v, -2, 15, -2, 4, 5, 4, Color("#E48AB4"))            # poppetje-lijf
	ArtVorm.ell(v, 0, 22, 0, 2.4, 2.4, 2.4, Color("#FFE0C2"), {"e": 2.4})  # kop
	return v

## Wimpel: een slinger vlaggetjes aan de muur (eigenaar, 2026-09-25: "De
## speelzaal lijkt momenteel kapot" — hij hing als een los latje midden in de
## zaal, dwars door het klimrek).  Een touw dat in het midden doorhangt, met
## driehoekige vlaggetjes eronder, in vijf kleuren.  Hij hangt hoog: niets
## ervan komt lager dan een gast (`WereldLooppad.KOP`), dus hij houdt niemand
## tegen, ook niet zonder `ver`.
const SLINGER := 38         ## lengte langs de muur
const SLINGER_HOOG := 44    ## hoogte van het touw aan de uiteinden
const DOORHANG := 4         ## zoveel zakt het in het midden
static func wimpel(_p := {}) -> Array:
	var v: Array = []
	var half := SLINGER / 2
	var hang := func(x: float) -> int:
		var t := x / float(half)
		return SLINGER_HOOG - int(round(float(DOORHANG) * (1.0 - t * t)))
	for x in range(-half, half):
		ArtVorm.bx(v, x, hang.call(float(x)), 0, 1, 1, 1, HOUT_D)             # touw
	var kl := [Color("#E4572E"), Color("#35A7FF"), Color("#FFC93C"), Color("#7BC950"), Color("#B57EDC")]
	var n := 6
	for i in n:
		var mx := -half + 3 + i * (SLINGER - 6) / (n - 1)
		var top: int = hang.call(float(mx)) - 1
		# a pennant: a triangle pointing down, 5 wide at the rope
		for rij in 5:
			var breed := 5 - 2 * (rij / 2)
			ArtVorm.bx(v, mx - breed / 2, top - rij, 0, breed, 1, 1, kl[i % kl.size()])
	return v

static func tabel() -> Dictionary:
	return {
		"klimrek": Callable(ArtDecorSpeelzaal, "klimrek"),
		"ballenbak": Callable(ArtDecorSpeelzaal, "ballenbak"),
		"blokkentoren": Callable(ArtDecorSpeelzaal, "blokkentoren"),
		"kussenhoek": Callable(ArtDecorSpeelzaal, "kussenhoek"),
		"muziekdoos": Callable(ArtDecorSpeelzaal, "muziekdoos"),
		"wimpel": Callable(ArtDecorSpeelzaal, "wimpel"),
	}
