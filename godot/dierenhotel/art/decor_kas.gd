extends RefCounted
class_name ArtDecorKas

## De Kas 🪴 (PLAN.md R3): de glazen kas achter het hotel, met moesbakken, een
## aardbeienbak, een potkast, zonnebloemen en een pompoenveldje.  Eigen namen en
## een eigen tabel, aangemeld bij `ArtDecor._extra()`; de basis-NAMEN van
## ArtDecor blijven ongemoeid (test_art telt ze).  Zelfde bouwstenen, palet en
## bakweg als de rest van het hotel (art-sound-rules.md §8).
##
## Wandstukken (`hangplant`, `kasluifel`) zijn gebouwd tegen de wand z = 0 (z van
## 0 naar voren) en hebben een `…z`-tweeling, over de diagonaal gespiegeld, voor
## de wand x = 0 — net als het slaapkamerraam en de luifel.

const HOUT := ArtDecor.HOUT
const HOUT_D := ArtDecor.HOUT_D
const HOUT_L := ArtDecor.HOUT_L
const BLAD := ArtDecor.BLAD
const BLAD_A := ArtDecor.BLAD_A
const BLAD_B := ArtDecor.BLAD_B
const POT := ArtDecor.POT
const METAAL := ArtDecor.METAAL
const METAAL_L := ArtDecor.METAAL_L
const PAPIER := ArtDecor.PAPIER
const GOUD := ArtDecor.GOUD

## De paar kleuren die de kas erbij brengt, in dezelfde pastelfamilie.
const AARDE := Color("#8C6A4E")       ## potgrond
const AARDE_D := Color("#77583F")     ## ... een voor in de grond
const BLAD_D := Color("#86B86F")      ## een donker blad, zodat een plant diepte heeft
const STENGEL := Color("#7FA85F")
const AARDBEI := Color("#E4574B")
const AARDBEI_L := Color("#F27E70")
const BLOEM := Color("#FFFDF3")
const POT_D := Color("#C47A57")
const ZONNE := Color("#FFD45C")
const ZONNE_D := Color("#F2B33D")
const ZONNE_HART := Color("#8A5A36")
const POMPOEN := Color("#F29A4A")
const POMPOEN_D := Color("#DE8338")
const STEEL := Color("#7A5A3A")
const GIETER := Color("#7DB3A0")
const GIETER_D := Color("#679B89")
const GLAS := Color("#D6EFEE")
const WIEL := Color("#6E6A72")
const ZAAD := [Color("#F5A8BE"), Color("#FFE49B"), Color("#A9D3F0"), Color("#B8E0A0")]

const NAMEN: Array[String] = ["moesbak", "moesbakz", "moesinhoud", "aardbeienbak",
	"aardbeienbakz", "potkast", "potkastz", "zaadkist", "kruiwagen", "gieter", "hangplant",
	"hangplantz", "zonnebloem", "pompoenen", "kasluifel", "kasluifelz", "kaspot"]

# ------------------------------------------------------------- de moesbakken

## Een moesbak: een verhoogde bak van planken, 30 lang langs x en 12 diep, vol
## potgrond met twee voren, en daarin wat er vandaag groeit — `params.groei`
## 0 kale aarde, 1 kiempjes, 2 blaadjes, 3 rijtjes sla (R3; de dagdressing van
## R6 laat het met het seizoen meelopen).
static func moesbak(p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -15, 0, -6, 30, 5, 12, HOUT_D)
	ArtVorm.verf(v, -15, 14, 0, 0, -6, 5, AARDE_D)             # de voet in de schaduw
	ArtVorm.bx(v, -15, 5, -6, 30, 1, 1, HOUT_L)                 # de rand
	ArtVorm.bx(v, -15, 5, 5, 30, 1, 1, HOUT_L)
	ArtVorm.bx(v, -15, 5, -5, 1, 1, 10, HOUT_L)
	ArtVorm.bx(v, 14, 5, -5, 1, 1, 10, HOUT_L)
	ArtVorm.bx(v, -14, 5, -5, 28, 1, 10, AARDE)                 # de grond
	ArtVorm.verf(v, -14, 13, 5, 5, -3, -3, AARDE_D)             # twee voren
	ArtVorm.verf(v, -14, 13, 5, 5, 2, 2, AARDE_D)
	_inhoud(v, clampi(int(p.get("groei", 3)), 0, 3), 6)
	return v

## Alleen wat er in een moesbak groeit, zonder de bak (voor de dagdressing van
## R6: los decor op een bak die er al staat, `hoog` 0).
static func moesinhoud(p := {}) -> Array:
	var v: Array = []
	_inhoud(v, clampi(int(p.get("groei", 3)), 0, 3), 6)
	return v

## Twee rijtjes van vijf op de voren: kiempjes, blaadjes of kroppen sla.
static func _inhoud(v: Array, groei: int, y: int) -> void:
	if groei <= 0:
		return
	for z in [-3, 2]:
		for x in [-12, -6, 0, 6, 12]:
			match groei:
				1:
					ArtVorm.bx(v, x, y, z, 1, 1, 1, STENGEL)
					ArtVorm.bx(v, x - 1, y + 1, z, 1, 1, 1, BLAD_B)
					ArtVorm.bx(v, x + 1, y + 1, z, 1, 1, 1, BLAD_B)
				2:
					ArtVorm.ell(v, x, y + 1, z, 1.6, 1.4, 1.6, BLAD_A, {"e": 2.2, "ymin": y})
				_:
					ArtVorm.ell(v, x, y + 1.6, z, 2.3, 2.0, 2.3, BLAD_D, {"e": 2.2, "ymin": y})
					ArtVorm.ell(v, x, y + 2.4, z, 1.3, 1.2, 1.3, BLAD_B, {"e": 2.2, "ymin": y + 1})

# ------------------------------------------------------------ de aardbeienbak

## De aardbeienbak: een lange houten plantenbak langs x (34 × 10), met vijf
## aardbeiplanten erin.  De rode aardbeien hangen over de voorrand (+z) en
## liggen tussen de blaadjes, zodat je vanaf elke kant ziet wat hier groeit;
## hier plukt het spel `oogst` zijn aardbeien.
static func aardbeienbak(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -17, 0, -5, 34, 6, 10, HOUT)
	ArtVorm.verf(v, -17, 16, 0, 0, -5, 4, HOUT_D)
	ArtVorm.verf(v, -17, 16, 5, 5, -5, 4, HOUT_L)
	ArtVorm.bx(v, -16, 6, -4, 32, 1, 8, AARDE)
	var planten := [-13, -7, -1, 5, 11]
	for i in planten.size():
		var x: int = planten[i]
		ArtVorm.ell(v, x, 8.0, 0.0, 3.1, 2.3, 3.1, BLAD_D, {"e": 2.2, "ymin": 7})
		ArtVorm.ell(v, x, 9.2, -0.5, 1.9, 1.5, 1.9, BLAD_A, {"e": 2.2, "ymin": 8})
		# een wit bloemetje met een geel hart bovenop elke tweede plant
		if i % 2 == 0:
			ArtVorm.bx(v, x, 11, 0, 1, 1, 1, BLOEM)
		# twee aardbeien hangen over de voorrand, eentje ligt in het blad
		for ax in [x - 2, x + 1]:
			ArtVorm.bx(v, ax, 3, 5, 2, 2, 1, AARDBEI)
			ArtVorm.bx(v, ax, 5, 5, 2, 1, 1, STENGEL)
		ArtVorm.bx(v, x + 1, 8, 2, 2, 2, 2, AARDBEI)
		ArtVorm.verf(v, x + 1, x + 1, 9, 9, 3, 3, AARDBEI_L)
	return v

# ---------------------------------------------------------------- de potkast

## Een open kast van planken (18 breed, 6 diep, 24 hoog) met drie planken vol
## terracotta potjes met zaailingen: de kweekhoek van de kas.  Staat met zijn
## rug tegen de wand z = 0.
static func potkast(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -9, 0, -3, 18, 24, 1, HOUT_D)                 # de rug
	ArtVorm.bx(v, -9, 0, -2, 1, 24, 5, HOUT)                    # de zijkanten
	ArtVorm.bx(v, 8, 0, -2, 1, 24, 5, HOUT)
	for y in [0, 8, 16]:
		ArtVorm.bx(v, -8, y, -2, 16, 1, 5, HOUT_L)              # de planken
	ArtVorm.bx(v, -9, 24, -3, 18, 1, 6, HOUT_L)                 # het blad bovenop
	var kl := [BLAD_A, ZONNE, BLAD_B]
	for rij in 3:
		var y := 1 + rij * 8
		for x in [-6, -1, 4]:
			ArtVorm.bx(v, x, y, -1, 3, 3, 3, POT)
			ArtVorm.verf(v, x, x + 2, y + 2, y + 2, -1, 1, POT_D)
			ArtVorm.bx(v, x + 1, y + 3, 0, 1, 1, 1, STENGEL)
			ArtVorm.bx(v, x, y + 4, 0, 1, 1, 1, kl[rij])
			ArtVorm.bx(v, x + 2, y + 4, 0, 1, 1, 1, kl[(rij + 1) % 3])
	return v

## De zaadkist: een houten kist met het deksel open tegen de achterkant, vol
## gekleurde zakjes zaad (R3: het toekomstige ingangsvoorwerp van het zaaien).
static func zaadkist(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -6, 0, -4, 12, 7, 8, HOUT_D)
	ArtVorm.bx(v, -6, 7, -4, 12, 1, 8, HOUT_L)
	ArtVorm.bx(v, -5, 7, -3, 10, 1, 6, AARDE_D)                 # het donkere binnenste
	for i in 5:                                                 # het deksel, schuin open
		ArtVorm.bx(v, -6, 8 + i, -5 - int(i / 2.0), 12, 1, 1, HOUT)
	for i in 4:
		ArtVorm.bx(v, -4 + i * 2, 8, -1 + (i % 2), 2, 3, 1, ZAAD[i])
		ArtVorm.verf(v, -4 + i * 2, -3 + i * 2, 10, 10, -1 + (i % 2), -1 + (i % 2), BLOEM)
	return v

# ------------------------------------------------------------ het gereedschap

## Een kruiwagen vol potgrond: groene bak, één wiel voorop (+x), twee houten
## handvatten achter.
static func kruiwagen(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -4, 2, -3, 8, 2, 7, GIETER_D)                 # de bodem
	ArtVorm.bx(v, -6, 4, -4, 12, 4, 9, GIETER)                  # de bak
	ArtVorm.bx(v, -5, 5, -3, 10, 3, 7, AARDE)
	ArtVorm.ell(v, -0.5, 8.0, 0.5, 4.5, 2.0, 3.2, AARDE, {"e": 2.2, "ymin": 8})
	for z in [-4, 4]:
		ArtVorm.bx(v, -13, 5, z, 8, 1, 1, HOUT)                 # de handvatten
		ArtVorm.bx(v, -4, 0, z, 1, 3, 1, HOUT_D)                # de pootjes
	for x in range(5, 10):                                      # het wiel
		for y in range(0, 5):
			var dx := float(x) - 7.0
			var dy := float(y) - 2.0
			if dx * dx + dy * dy <= 5.5:
				ArtVorm.bx(v, x, y, 0, 1, 1, 2, WIEL)
	ArtVorm.bx(v, 6, 2, 0, 2, 1, 2, METAAL_L)
	return v

## Een groene gieter met een lange tuit en een broes.
static func gieter(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -2, 0, -2, 5, 6, 5, GIETER)
	ArtVorm.bx(v, -2, 6, -2, 5, 1, 5, GIETER_D)
	for i in 4:
		ArtVorm.bx(v, 3 + i, 2 + i, 0, 1, 1, 1, GIETER_D)       # de tuit
	ArtVorm.bx(v, 7, 5, -1, 1, 3, 3, GIETER)                    # de broes
	ArtVorm.bx(v, -3, 3, 0, 1, 4, 1, GIETER_D)                  # het handvat
	ArtVorm.bx(v, -2, 8, 0, 4, 1, 1, GIETER_D)
	return v

# ------------------------------------------------------------- aan de wand

## Een hangplant aan een houten arm tegen de wand z = 0: een terracotta pot met
## een bol blad erin en ranken die naar beneden hangen.  Hang hem met
## `{"ver": true, "y": <hoogte>}`; de ranken lopen 7 voxels onder de pot door.
static func hangplant(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -1, 13, 0, 3, 1, 6, HOUT_D)                   # de arm uit de wand
	ArtVorm.bx(v, 0, 11, 5, 1, 2, 1, METAAL)                    # het kettinkje
	ArtVorm.bx(v, -2, 7, 3, 5, 4, 5, POT)                       # de pot
	ArtVorm.verf(v, -2, 2, 10, 10, 3, 7, POT_D)
	ArtVorm.ell(v, 0.0, 11.0, 5.0, 2.8, 1.6, 2.8, BLAD_A, {"e": 2.2, "ymin": 10})
	for r in [[-2, 7], [1, 7], [2, 5], [-1, 4]]:                # de ranken
		for y in range(r[1] - 6, r[1]):
			ArtVorm.bx(v, r[0], y + 1, 7 if r[0] % 2 == 0 else 6, 1, 1, 1,
				BLAD_D if y % 2 == 0 else BLAD_B)
	return v

## Een glazen luifel boven een deur in een wand z = 0: witte stijlen en glas,
## schuin aflopend van de wand af, op twee houten schoren (de kasdeur in de
## gevel van de tuin).  16 breed, 7 diep.
static func kasluifel(_p := {}) -> Array:
	var v: Array = []
	for zz in 7:
		var yy := 6 - int(floor(zz * 0.6))
		for xx in range(-8, 8):
			var rand := xx == -8 or xx == 7 or xx == -1 or zz == 6
			v.append({"x": xx, "y": yy, "z": zz, "k": PAPIER if rand else GLAS})
	for xx in [-8, 7]:
		ArtVorm.bx(v, xx, 0, 0, 1, 5, 1, HOUT_D)
		ArtVorm.bx(v, xx, 4, 1, 1, 1, 2, HOUT_D)
	return v

# ---------------------------------------------------------------- de planten

## Drie zonnebloemen in een grote pot, 21, 27 en 33 voxels hoog, met hun koppen
## naar de kijker: het hoogste in de kas, dus in de achterhoek.
static func zonnebloem(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -4, 0, -4, 8, 5, 8, POT)
	ArtVorm.verf(v, -4, 3, 4, 4, -4, 3, POT_D)
	ArtVorm.bx(v, -3, 5, -3, 6, 1, 6, AARDE)
	for b in [[-2, 21, -1], [1, 33, 0], [2, 27, 2]]:
		var sx: int = b[0]
		var top: int = b[1]
		var sz: int = b[2]
		ArtVorm.bx(v, sx, 6, sz, 1, top - 6, 1, STENGEL)
		for ly in [top - 14, top - 8]:                          # twee bladeren per steel
			ArtVorm.ell(v, sx + (2 if ly % 2 == 0 else -2), ly, sz, 1.8, 0.9, 1.4, BLAD_D,
				{"e": 2.2})
		_zonnekop(v, sx + 1, top, sz + 1)
	return v

## A sunflower head that faces the viewer: a disc in the plane x + z = const,
## i.e. along (1, 0, −1) and up.  One step along that line is two screen units
## wide and one voxel up is two tall, so the disc is half as deep in `t` as it
## is in `dy` and reads round on screen: brown heart, yellow petals.
static func _zonnekop(v: Array, cx: int, cy: int, cz: int) -> void:
	for t in range(-3, 4):
		for dy in range(-5, 6):
			var d := sqrt(pow(float(t) / 2.4, 2.0) + pow(float(dy) / 4.6, 2.0))
			if d > 1.0:
				continue
			var kl := ZONNE_HART if d < 0.5 else (ZONNE if (t + dy) % 2 == 0 else ZONNE_D)
			v.append({"x": cx + t, "y": cy + dy, "z": cz - t, "k": kl})

## Een pompoenveldje: drie pompoenen (groot, middel, klein) met ribbels en een
## steeltje, tussen platte bladeren op de grond.  20 × 18.
static func pompoenen(_p := {}) -> Array:
	var v: Array = []
	for b in [[-8, -4], [6, -6], [-3, 7], [8, 6], [-9, 5]]:     # het blad op de grond
		ArtVorm.ell(v, b[0], 0.6, b[1], 3.2, 0.9, 2.6, BLAD_D, {"e": 2.2, "ymin": 0})
	for p in [[-4, 0, 4.3, 3.4], [5, -3, 3.3, 2.7], [3, 6, 2.5, 2.1]]:
		var px: float = p[0]
		var pz: float = p[1]
		var r: float = p[2]
		var h: float = p[3]
		var voor := v.size()
		ArtVorm.ell(v, px, h, pz, r, h, r, POMPOEN, {"e": 2.2, "ymin": 0})
		# ribbels: elke tweede kolom een tint donkerder, alleen op deze pompoen
		for i in range(voor, v.size()):
			var q: Dictionary = v[i]
			if (int(q["x"]) + int(q["z"])) % 3 == 0:
				q["k"] = POMPOEN_D
		ArtVorm.bx(v, int(px), int(h * 2.0), int(pz), 1, 2, 1, STEEL)
	return v

## Een klein terracotta potje met een plantje: naast de kasdeur in de tuin.
static func kaspot(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -2, 0, -2, 5, 4, 5, POT)
	ArtVorm.verf(v, -2, 2, 3, 3, -2, 2, POT_D)
	ArtVorm.ell(v, 0.0, 6.0, 0.0, 2.8, 2.4, 2.8, BLAD_A, {"e": 2.2, "ymin": 4})
	ArtVorm.ell(v, 0.5, 7.4, -0.5, 1.4, 1.2, 1.4, BLAD_B, {"e": 2.2, "ymin": 6})
	return v

# --------------------------------------------------------------------- register

## `naam -> Callable(params) -> Array` of voxels {x, y, z, k}.
static func tabel() -> Dictionary:
	return {
		"moesbak": Callable(ArtDecorKas, "moesbak"),
		"moesbakz": func(p := {}): return ArtVorm.draai(moesbak(p)),
		"moesinhoud": Callable(ArtDecorKas, "moesinhoud"),
		"aardbeienbak": Callable(ArtDecorKas, "aardbeienbak"),
		"aardbeienbakz": func(_p := {}): return ArtVorm.draai(aardbeienbak()),
		"potkast": Callable(ArtDecorKas, "potkast"),
		"potkastz": func(_p := {}): return ArtVorm.draai(potkast()),
		"zaadkist": Callable(ArtDecorKas, "zaadkist"),
		"kruiwagen": Callable(ArtDecorKas, "kruiwagen"),
		"gieter": Callable(ArtDecorKas, "gieter"),
		"hangplant": Callable(ArtDecorKas, "hangplant"),
		"hangplantz": func(_p := {}): return ArtVorm.draai(hangplant()),
		"zonnebloem": Callable(ArtDecorKas, "zonnebloem"),
		"pompoenen": Callable(ArtDecorKas, "pompoenen"),
		"kasluifel": Callable(ArtDecorKas, "kasluifel"),
		"kasluifelz": func(_p := {}): return ArtVorm.draai(kasluifel()),
		"kaspot": Callable(ArtDecorKas, "kaspot"),
	}
