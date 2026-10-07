extends RefCounted
class_name ArtDecorBakkerij

## De bakkerij 🍪 (eigenaar, 2026-10-07: "Verzin nog vier kamers met
## activiteiten"; ontwerp .fanout/scratch/uitbreiding/U1-bakkerij.md).  Eigen
## namen en een eigen tabel, zelfde bouwstenen en bakweg als de rest van het
## hotel (art-sound-rules.md §8).  Aangemeld bij `ArtDecor._extra()` zoals
## `ArtDecorWinkels` (integratie I1a, 2026-10-07): de bakkerij staat op haar
## eigen `bakoven`.  Het spel `koekjes` registreert zijn plaat en kom nog zelf
## via `Art.registreer_model("koekjes_plaat", …)`.
##
##   bakoven     stenen oven met een gloeiende mond naar voren (+z) en een schoorsteen
##   bakplaat    een bakplaat met koekjes in RIJEN × KOLOMMEN (params rijen, kolommen,
##               aantal: minder koekjes dan vakjes laat de laatste leeg) — de tafelsom
##               als een ding dat je kunt tellen
##   eierschaal  een kom met `n` eieren (param n, tot 12)

const STEEN := Color("#D2AE94")
const STEEN_D := Color("#B58E73")
const MOND := Color("#2E2328")
const GLOED := Color("#FFB24A")
const GLOED_D := Color("#E0702A")
const PLAAT := ArtDecor.METAAL
const PLAAT_L := ArtDecor.METAAL_L
const KOEK := Color("#D9A066")
const KOEK_D := Color("#B9803F")
const CHOCO := Color("#5A3A28")
const KOM := Color("#A9CDEE")
const KOM_L := Color("#CFE3F6")
const EI := Color("#FFF4E0")

const NAMEN: Array[String] = ["bakoven", "bakplaat", "eierschaal"]

## De hoogte van het blad van de oven: daar hangt het knopje van `koekjes`.
const OVEN_TOP := 24

static func bakoven(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -12, 0, -8, 24, 22, 16, STEEN)        # het lijf
	ArtVorm.bx(v, -13, 22, -9, 26, 2, 18, STEEN_D)      # het blad
	ArtVorm.bx(v, -8, 4, 7, 16, 9, 2, MOND)             # de mond, naar voren
	ArtVorm.bx(v, -6, 5, 8, 12, 3, 1, GLOED_D)          # de gloed onderin
	ArtVorm.bx(v, -4, 6, 8, 8, 2, 1, GLOED)
	ArtVorm.bx(v, -10, 1, 7, 20, 2, 2, STEEN_D)         # de drempel
	ArtVorm.bx(v, -3, 24, -6, 6, 10, 6, STEEN_D)        # de schoorsteen
	return v

static func bakplaat(p := {}) -> Array:
	var rijen: int = maxi(1, int(p.get("rijen", 2)))
	var kolommen: int = maxi(1, int(p.get("kolommen", 3)))
	var aantal: int = int(p.get("aantal", rijen * kolommen))
	var w := kolommen * 4 + 2
	var d := rijen * 4 + 2
	var x0 := -(w >> 1)
	var z0 := -(d >> 1)
	var v: Array = []
	ArtVorm.bx(v, x0, 0, z0, w, 1, d, PLAAT)
	ArtVorm.verf(v, x0, x0 + w - 1, 0, 0, z0, z0, PLAAT_L)   # de rand vangt licht
	var i := 0
	for r in rijen:
		for k in kolommen:
			if i >= aantal:
				return v
			var cx := float(x0 + 1 + k * 4 + 2)
			var cz := float(z0 + 1 + r * 4 + 2)
			ArtVorm.ell(v, cx - 0.5, 1.4, cz - 0.5, 1.7, 0.9, 1.7, KOEK, {"e": 2.2, "ymin": 1})
			v.append({"x": int(cx) - 1, "y": 2, "z": int(cz) - 1, "k": CHOCO})
			v.append({"x": int(cx), "y": 2, "z": int(cz) - 2, "k": KOEK_D})
			i += 1
	return v

static func eierschaal(p := {}) -> Array:
	var n: int = clampi(int(p.get("n", 4)), 0, 12)
	var v: Array = []
	ArtVorm.ell(v, 0.0, 1.0, 0.0, 6.0, 3.0, 6.0, KOM, {"e": 2.2, "ymin": 0, "ymax": 3})
	ArtVorm.verf(v, -6, 6, 3, 3, -6, 6, KOM_L)
	for i in n:
		var hoek := float(i) * TAU / float(maxi(n, 1))
		var rad := 0.0 if (i == 0 and n <= 1) else (2.2 if i < 6 else 3.8)
		var cx := cos(hoek) * rad
		var cz := sin(hoek) * rad
		ArtVorm.ell(v, cx, 3.6, cz, 1.1, 1.5, 1.1, EI, {"e": 2.2})
	return v

static func tabel() -> Dictionary:
	return {
		"bakoven": Callable(ArtDecorBakkerij, "bakoven"),
		"bakplaat": Callable(ArtDecorBakkerij, "bakplaat"),
		"eierschaal": Callable(ArtDecorBakkerij, "eierschaal"),
	}
