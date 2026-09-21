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

const NAMEN: Array[String] = ["klimrek", "ballenbak", "blokkentoren", "kussenhoek",
	"muziekdoos", "wimpel"]

## Klimrek: twee stijgers met metalen sporten, plus een glijplank eraan.
static func klimrek(_p := {}) -> Array:
	var v: Array = []
	for sx in [-14, 14]:
		ArtVorm.bx(v, sx - 1, 0, -3, 3, 30, 3, HOUT_D)              # stijger
		for ry in range(4, 28, 5):
			ArtVorm.bx(v, sx - 1, ry, -4, 3, 2, 9, METAAL)          # sport
	ArtVorm.bx(v, -15, 29, -3, 31, 2, 3, HOUT)                      # bovenligger
	ArtVorm.bx(v, -11, 6, 5, 9, 2, 14, TOUCH)                        # glijplank
	ArtVorm.bx(v, -11, 4, 17, 9, 2, 2, TOUCH)                        # uitloop
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

## Wimpel: een touw met vierkante vlaggetjes (hangt hoog, rakt de vloer niet).
static func wimpel(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -24, 34, 0, 48, 1, 1, HOUT_D)                      # touw
	var kl := [Color("#E4572E"), Color("#35A7FF"), Color("#FFC93C"), Color("#7BC950"), Color("#B57EDC")]
	for i in range(5):
		var x := -20 + i * 10
		ArtVorm.bx(v, x - 3, 28, 0, 6, 6, 1, kl[i])                  # vlaggetje
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
