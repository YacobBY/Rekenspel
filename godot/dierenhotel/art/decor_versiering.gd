extends RefCounted
class_name ArtDecorVersiering

## Koopbare kamerdecoratie 🩷 (eigenaar, 2026-10-07: "En eventueel ook accessoires
## om in de kamers te zetten of de kamers te decoreren").  Negen kleine stukken
## die het meubelboek (`games/meubels`) op zijn tab 🩷 Decoratie verkoopt naast de
## zes meubels uit `Sommen.Meubels.WINKEL`: een kussen, bloemen, een
## ballonslinger, een bankje, een lamp, een schilderij, een klokkastje, een
## speelkist en een aquarium.  Zelfde bouwstenen en palet als de rest van het
## hotel (art-sound-rules.md §8, docs/ART-STIJL.md).
##
## Acht staan op de vloer, verankerd op (0, 0, 0), y omhoog.  Het SCHILDERIJ
## hangt aan de muur: het is gebouwd zoals de wandstukken van
## `ArtDecorSlaapkamer` — tegen de achterwand z = 0, z naar het kind toe — en
## `Rooms.meubel_zet` hangt het met `ver` op `Rooms.WAND_Y`; aan de linkerwand
## krijgt het `rot` 1 (een echte kwartslag, `World.plaat`).
##
## De namen dragen het voorvoegsel `versier_`, zodat ze nooit botsen met een
## ander wereldmodel; `ArtDecor._extra()` meldt dit bestand aan als beschermd
## wereldmodel, net als de andere themabestanden.

const HOUT := ArtDecor.HOUT
const HOUT_D := ArtDecor.HOUT_D
const HOUT_L := ArtDecor.HOUT_L
const METAAL := ArtDecor.METAAL
const GOUD := ArtDecor.GOUD
const POT := ArtDecor.POT
const PAPIER := ArtDecor.PAPIER
const BLAD := ArtDecor.BLAD
const ROZE := Color("#F2A7B8")
const ROZE_L := Color("#F9CBD6")
const LILA := Color("#B98BC4")
const LILA_L := Color("#D7BFE0")
const MINT := Color("#9FD8C4")
const BLAUW := Color("#A9CDEE")
const GEEL := Color("#FFE8A3")
const GLAS := Color("#CFE9EE")
const WATER := Color("#A9D8E6")
const VIS := Color("#F0975A")
const MAAN := Color("#FFE27A")
const NACHT := Color("#7E9CD6")
const GOUD_L := Color("#F7D77E")

const NAMEN: Array[String] = ["versier_kussen", "versier_bloemen", "versier_slinger",
	"versier_bankje", "versier_lamp", "versier_schilderij", "versier_kastje",
	"versier_kist", "versier_aquarium"]

## Een plat roze kussen met een lichte bovenkant.
static func kussen(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -5, 0, -5, 11, 3, 11, ROZE)
	ArtVorm.bx(v, -4, 3, -4, 9, 1, 9, ROZE_L)
	return v

## Een potje met drie roze bolletjes op groene steeltjes.
static func bloemen(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -3, 0, -3, 7, 5, 7, POT)
	ArtVorm.bx(v, -1, 5, -1, 3, 6, 3, BLAD)
	ArtVorm.ell(v, 0, 13, 0, 3.0, 3.0, 3.0, ROZE, {"e": 2.2})
	ArtVorm.ell(v, -3, 11, 2, 2.2, 2.2, 2.2, ROZE_L, {"e": 2.2})
	ArtVorm.ell(v, 3, 12, -2, 2.2, 2.2, 2.2, LILA_L, {"e": 2.2})
	return v

## Een staander met drie ballonnen (roze, mint, blauw).
static func slinger(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -3, 0, -3, 7, 1, 7, METAAL)
	ArtVorm.bx(v, 0, 1, 0, 1, 16, 1, METAAL)
	ArtVorm.ell(v, -4, 19, 0, 3.2, 3.8, 3.2, ROZE, {"e": 2.2})
	ArtVorm.ell(v, 4, 21, -1, 3.2, 3.8, 3.2, MINT, {"e": 2.2})
	ArtVorm.ell(v, 0, 24, 3, 3.2, 3.8, 3.2, BLAUW, {"e": 2.2})
	return v

## Een laag lila bankje: zitting, rugleuning, twee armen en een licht kussen.
static func bankje(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -8, 0, -4, 17, 5, 9, LILA)        # zitting
	ArtVorm.bx(v, -8, 5, -4, 17, 6, 2, LILA)        # rugleuning
	ArtVorm.bx(v, -8, 5, -4, 2, 3, 9, LILA)         # armen
	ArtVorm.bx(v, 7, 5, -4, 2, 3, 9, LILA)
	ArtVorm.bx(v, -6, 5, -2, 13, 1, 7, LILA_L)      # kussen
	return v

## Een staande lamp: voet, paal en een gele kap.
static func lamp(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -3, 0, -3, 7, 1, 7, METAAL)
	ArtVorm.bx(v, 0, 1, 0, 1, 18, 1, METAAL)
	ArtVorm.ell(v, 0, 22, 0, 5.0, 4.0, 5.0, GEEL, {"e": 2.6, "ymin": 19})
	return v

## Een schilderij voor de muur: een gouden lijst met een nachtlucht, een gele
## maan en twee sterretjes (het pictogram in het boek is 🌙).  Gebouwd tegen de
## achterwand z = 0, 15 breed en 13 hoog; `Rooms.meubel_zet` hangt het op.
static func schilderij(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -7, 0, 0, 15, 13, 2, GOUD)        # lijst
	ArtVorm.bx(v, -6, 1, 1, 13, 11, 2, NACHT)       # doek
	ArtVorm.verf(v, -7, 7, 12, 12, 0, 2, GOUD_L)    # licht op de bovenrand
	for p in v:                                      # de maan: een sikkel
		if int(p["z"]) != 2:
			continue
		var x := float(p["x"])
		var y := float(p["y"])
		var in_maan := (x + 1.5) * (x + 1.5) + (y - 6.5) * (y - 6.5) <= 12.5
		var in_hap := (x - 0.2) * (x - 0.2) + (y - 7.6) * (y - 7.6) <= 9.0
		if in_maan and not in_hap:
			p["k"] = MAAN
	ArtVorm.verf(v, 3, 3, 9, 9, 2, 2, PAPIER)       # twee sterretjes
	ArtVorm.verf(v, 4, 4, 4, 4, 2, 2, PAPIER)
	return v

## Een nachtkastje: houten blokje met een la en een gouden knopje.
static func kastje(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -5, 0, -4, 11, 11, 9, HOUT)
	ArtVorm.verf(v, -5, 5, 11, 11, -4, 4, HOUT_L)
	ArtVorm.verf(v, -5, 5, 5, 5, 4, 4, HOUT_D)
	ArtVorm.bx(v, 0, 7, 5, 1, 2, 1, GOUD)
	ArtVorm.ell(v, 0, 14, 0, 3.0, 3.0, 1.2, PAPIER, {"e": 2.4})   # het klokje erop
	ArtVorm.bx(v, 0, 14, 1, 1, 2, 1, GOUD)
	return v

## Een speelkist met een open deksel en een bal erin.
static func kist(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -6, 0, -4, 13, 8, 9, HOUT)
	ArtVorm.bx(v, -5, 7, -3, 11, 1, 7, HOUT_D)
	ArtVorm.bx(v, -6, 8, -5, 13, 10, 1, HOUT_L)    # deksel open naar achter
	ArtVorm.ell(v, 0, 10, 0, 2.6, 2.6, 2.6, ROZE, {"e": 2.4})
	return v

## Een aquarium op een kastje: glazen bak met water en een oranje visje.
static func aquarium(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -6, 0, -4, 13, 8, 9, HOUT)
	ArtVorm.bx(v, -6, 8, -4, 13, 9, 9, GLAS)
	ArtVorm.verf(v, -5, 5, 9, 15, -3, 3, WATER)
	ArtVorm.ell(v, 0, 12, 0, 2.6, 1.6, 1.2, VIS, {"e": 2.4})
	return v

static func tabel() -> Dictionary:
	return {
		"versier_kussen": Callable(ArtDecorVersiering, "kussen"),
		"versier_bloemen": Callable(ArtDecorVersiering, "bloemen"),
		"versier_slinger": Callable(ArtDecorVersiering, "slinger"),
		"versier_bankje": Callable(ArtDecorVersiering, "bankje"),
		"versier_lamp": Callable(ArtDecorVersiering, "lamp"),
		"versier_schilderij": Callable(ArtDecorVersiering, "schilderij"),
		"versier_kastje": Callable(ArtDecorVersiering, "kastje"),
		"versier_kist": Callable(ArtDecorVersiering, "kist"),
		"versier_aquarium": Callable(ArtDecorVersiering, "aquarium"),
	}
