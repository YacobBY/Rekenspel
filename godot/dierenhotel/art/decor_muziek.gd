extends RefCounted
class_name ArtDecorMuziek

## De Muziekkamer 🎵 (eigenaar, 2026-10-07: "Verzin nog vier kamers met
## activiteiten").  De instrumenten van De dierenband (`games/band`): een grote
## rode trommel met twee stokjes, een xylofoon met acht regenboogtoetsen, een
## staande piano tegen de achterwand en een muziekstandaard.  Zelfde bouwstenen,
## palet en bakweg als de rest van het hotel (art-sound-rules.md §8).
##
## De namen dragen het voorvoegsel `band_`: het SPEL zet ze neer als
## rustrekwisieten (`definitie().rust`, zoals spiegel's ezel).  Sinds de
## integratie (I1a, 2026-10-07) staat `ArtDecorMuziek` ook in
## `art/decor.gd::_extra()`, dus `Art` kent ze bij het opstarten als
## beschermde wereldmodellen; `Games._meld_modellen` slaat een naam over die
## er al is, dus `definitie().modellen` doet dan niets meer.
##
## Wandstukken (`band_piano`) staan tegen de wand z = 0, met z naar voren.

const HOUT := ArtDecor.HOUT
const HOUT_D := ArtDecor.HOUT_D
const HOUT_L := ArtDecor.HOUT_L
const METAAL := ArtDecor.METAAL
const GOUD := ArtDecor.GOUD
const GOUD_D := ArtDecor.GOUD_D

const TROM := Color("#E2574C")        ## de rode ton
const TROM_D := Color("#C44439")
const VEL := Color("#FFF4DC")         ## het trommelvel
const STOK := Color("#D9B98A")
const STOK_KOP := Color("#FBF1E2")
const PIANO := Color("#3B3340")       ## de staande piano
const PIANO_L := Color("#524858")
const TOETS_WIT := Color("#FFF9EE")
const TOETS_ZWART := Color("#2A2430")
const BLAD := Color("#2F2A33")        ## het blad van de standaard
const PAPIER := ArtDecor.PAPIER
## De acht regenboogtoetsen van de xylofoon, van lang (links) naar kort.
const REGENBOOG: Array[Color] = [Color("#E2574C"), Color("#F28C38"), Color("#F5D37A"),
	Color("#8CCB7A"), Color("#5FB8A6"), Color("#5A9BD5"), Color("#8A7BC8"), Color("#D98AB8")]

const NAMEN: Array[String] = ["band_trommel", "band_xylofoon", "band_piano", "band_standaard"]

## De bovenkant van het trommelvel: daar slaat het stokje, daar vonkt het.
const TROMMEL_TOP := 14

## Een grote staande trommel: een rode ton op drie pootjes, een room vel met een
## gouden rand, en twee stokjes die op het vel liggen.
static func band_trommel(_p := {}) -> Array:
	var v: Array = []
	# pootjes
	ArtVorm.bx(v, 1, 0, 1, 2, 2, 2, HOUT_D)
	ArtVorm.bx(v, 13, 0, 1, 2, 2, 2, HOUT_D)
	ArtVorm.bx(v, 7, 0, 13, 2, 2, 2, HOUT_D)
	# de ton, een afgeronde cilinder van 16 × 16, 12 hoog
	for y in range(2, TROMMEL_TOP):
		for x in 16:
			for z in 16:
				var dx := x + 0.5 - 8.0
				var dz := z + 0.5 - 8.0
				var r2 := dx * dx + dz * dz
				if r2 > 64.0:
					continue
				var rand := r2 > 42.0
				var kl := TROM_D if rand else TROM
				if y == 2 or y == TROMMEL_TOP - 1:
					kl = GOUD if rand else kl     # de gouden banden
				if y == 7 and rand and (x + z) % 3 == 0:
					kl = GOUD_D                   # de spanhaken
				v.append({"x": x, "y": y, "z": z, "k": kl})
	# het vel
	for x in 16:
		for z in 16:
			var dx := x + 0.5 - 8.0
			var dz := z + 0.5 - 8.0
			var r2 := dx * dx + dz * dz
			if r2 > 64.0:
				continue
			v.append({"x": x, "y": TROMMEL_TOP, "z": z, "k": GOUD if r2 > 46.0 else VEL})
	# twee stokjes, gekruist op het vel
	for i in 7:
		v.append({"x": 3 + i, "y": TROMMEL_TOP + 1, "z": 4 + i, "k": STOK})
		v.append({"x": 11 - i, "y": TROMMEL_TOP + 1, "z": 5 + i, "k": STOK})
	v.append({"x": 10, "y": TROMMEL_TOP + 2, "z": 11, "k": STOK_KOP})
	v.append({"x": 4, "y": TROMMEL_TOP + 2, "z": 12, "k": STOK_KOP})
	return v

## Een xylofoon op een houten voet: acht regenboogtoetsen, van lang naar kort,
## met twee hamertjes ernaast.
static func band_xylofoon(_p := {}) -> Array:
	var v: Array = []
	# de wig-vormige voet
	ArtVorm.bx(v, 0, 0, 0, 20, 2, 10, HOUT_D)
	ArtVorm.bx(v, 0, 2, 1, 20, 2, 8, HOUT)
	# acht toetsen dwars op de voet, elk 2 breed, aflopend in lengte
	for i in REGENBOOG.size():
		var lengte := 10 - i            # 10 … 3
		var z0 := int((10 - lengte) / 2.0)
		ArtVorm.bx(v, 1 + i * 2, 4, z0, 2, 1, lengte, REGENBOOG[i])
		v.append({"x": 1 + i * 2, "y": 4, "z": z0, "k": METAAL})   # het spijkertje
	# twee hamertjes
	ArtVorm.bx(v, 20, 0, 2, 1, 1, 5, STOK)
	v.append({"x": 20, "y": 1, "z": 2, "k": TROM})
	ArtVorm.bx(v, 21, 0, 4, 1, 1, 5, STOK)
	v.append({"x": 21, "y": 1, "z": 4, "k": TROM})
	return v

## Een staande piano tegen de wand z = 0: een donkere kast, het klavier naar
## voren met zwarte en witte toetsen, een bladmuziekstandaard en een krukje.
static func band_piano(_p := {}) -> Array:
	var v: Array = []
	# de kast, 30 breed, 34 hoog, 10 diep
	ArtVorm.bx(v, 0, 0, 0, 30, 34, 10, PIANO)
	ArtVorm.bx(v, 1, 20, 10, 28, 1, 1, PIANO_L)      # de lijst boven het klavier
	ArtVorm.bx(v, 0, 32, 0, 30, 2, 11, PIANO_L)      # het deksel
	# het klavier: een plank naar voren met 14 witte toetsen en 10 zwarte
	ArtVorm.bx(v, 1, 18, 10, 28, 2, 6, PIANO)
	ArtVorm.bx(v, 2, 20, 10, 26, 1, 6, TOETS_WIT)
	for i in 13:
		v.append({"x": 3 + i * 2 + 1, "y": 20, "z": 15, "k": PIANO_L})   # de naden
		if i % 7 != 2 and i % 7 != 6:
			ArtVorm.bx(v, 3 + i * 2 + 1, 21, 10, 1, 1, 3, TOETS_ZWART)
	# de bladmuziek op de standaard
	ArtVorm.bx(v, 10, 24, 9, 10, 7, 1, PAPIER)
	for i in 3:
		ArtVorm.bx(v, 12, 26 + i * 2, 9, 6, 1, 1, PIANO_L)
	# de pedalen en het krukje
	ArtVorm.bx(v, 11, 0, 10, 3, 1, 3, GOUD)
	ArtVorm.bx(v, 16, 0, 10, 3, 1, 3, GOUD)
	ArtVorm.bx(v, 11, 0, 16, 8, 1, 8, HOUT_D)
	ArtVorm.bx(v, 12, 1, 17, 6, 7, 6, HOUT)
	ArtVorm.bx(v, 11, 8, 16, 8, 2, 8, TROM)
	return v

## Een muziekstandaard: een driepoot, een paal en een schuin blad met een vel
## bladmuziek erop.
static func band_standaard(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, 3, 0, 0, 1, 1, 4, METAAL)
	ArtVorm.bx(v, 0, 0, 3, 7, 1, 1, METAAL)
	ArtVorm.bx(v, 3, 0, 4, 1, 1, 3, METAAL)
	ArtVorm.bx(v, 3, 1, 3, 1, 18, 1, METAAL)
	# het blad helt naar voren: elke rij een stapje naar z
	for i in 9:
		ArtVorm.bx(v, -2, 19 + i, 6 - int(i / 2.0), 11, 1, 1, BLAD)
		if i >= 1 and i <= 7:
			ArtVorm.bx(v, -1, 19 + i, 7 - int(i / 2.0), 9, 1, 1, PAPIER)
	for i in 3:
		ArtVorm.bx(v, 0, 21 + i * 2, 7 - int((2 + i * 2) / 2.0), 7, 1, 1, BLAD)
	return v

static func tabel() -> Dictionary:
	return {
		"band_trommel": Callable(ArtDecorMuziek, "band_trommel"),
		"band_xylofoon": Callable(ArtDecorMuziek, "band_xylofoon"),
		"band_piano": Callable(ArtDecorMuziek, "band_piano"),
		"band_standaard": Callable(ArtDecorMuziek, "band_standaard"),
	}
