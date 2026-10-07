extends RefCounted
class_name ArtDecorBakkerij

## De bakkerij 🍪 (eigenaar, 2026-10-07: "Verzin nog vier kamers met
## activiteiten"; ontwerp .fanout/scratch/uitbreiding/U1-bakkerij.md).  Eigen
## namen en een eigen tabel, zelfde bouwstenen en bakweg als de rest van het
## hotel (art-sound-rules.md §8).
##
## Aangemeld bij `ArtDecor._extra()` zoals `ArtDecorWinkels` (integratie I1a,
## 2026-10-07): `Art` kent de vijf namen als wereldmodellen, met hun
## pixel-goudplaten.  Geen kamer zet ze als vast decor: de oven en de werkbank
## zijn de spullen van het spel `koekjes`.  Het spel meldt ze zelf nog eens aan
## (`definitie().modellen`, als `koekjes_oven` en `koekjes_bank`), zet ze als
## RUSTSPUL in de bakkerij zolang er niet gespeeld wordt (`Games._zet_rust`) en
## tijdens een beurt als zijn eigen decor — zo staat er altijd precies één oven
## en één bakkerstafel (integratie I1b: de vaste `bakoven` van I1a is weg).
##
##   bakoven     stenen oven met een mond naar voren (+z) en een schoorsteen
##               links achter; `bakt` laat de mond gloeien met een bakplaat erin,
##               `rest` zet een bordje met zoveel koekjes op het blad (de rest
##               van het delen: "voor de kok")
##   bakplaat    een bakplaat met koekjes in RIJEN × KOLOMMEN (params rijen,
##               kolommen, aantal: minder koekjes dan vakjes laat de laatste leeg;
##               gaar: gebakken koekjes, anders bolletjes deeg) — de tafelsom als
##               een ding dat je kunt tellen
##   eierschaal  een kom met `n` eieren netjes in rijen van vier (param n, tot
##               12); `beslag` vult de kom met beslag in plaats van eieren
##   werkbank    de grote bakkerstafel (BANK_W × BANK_D) met wat er op ligt:
##               een bakplaat (rijen, kolommen, aantal, gaar), kommen met eieren
##               (`kommen`: [n, n], `beslag`), losse eieren ernaast (`los`) en,
##               als hij rust, een deegroller en een hoopje meel (`rol`)
##   koekbord    een bordje met `n` gebakken koekjes (de rest voor de kok)

const STEEN := Color("#D2AE94")
const STEEN_D := Color("#B58E73")
const STEEN_L := Color("#E2C4AC")
const MOND := Color("#2E2328")
const GLOED := Color("#FFB24A")
const GLOED_D := Color("#E0702A")
const VUUR := Color("#FFE08A")
const PLAAT := Color("#9EA4BA")       ## the tray: darker than the dough on it
const PLAAT_L := ArtDecor.METAAL      ## its raised rim catches the light
const KOEK := Color("#D9A066")
const KOEK_D := Color("#B9803F")
const CHOCO := Color("#5A3A28")
const DEEG := Color("#F7EAD0")
const DEEG_D := Color("#E6CFA4")
const DEEG_L := Color("#FFF8EA")
const KOM := Color("#A9CDEE")
const KOM_L := Color("#CFE3F6")
const KOM_D := Color("#86B2DB")
const EI := Color("#FFF4E0")
const EI_D := Color("#F1DFC2")
const BESLAG := Color("#F7D774")
const BESLAG_L := Color("#FBE6A0")
const BLAD := ArtDecor.HOUT_L
const BLAD_D := ArtDecor.HOUT_D
const POOT := ArtDecor.HOUT
const MEEL := ArtDecor.PAPIER
const BORD := ArtDecor.KUSSEN
const BORD_L := ArtDecor.PAPIER

const NAMEN: Array[String] = ["bakoven", "bakplaat", "eierschaal", "werkbank", "koekbord"]

## De hoogte van het blad van de oven: daar hangt het knopje van `koekjes`.
const OVEN_TOP := 24
## De bakkerstafel: zo breed (x) en zo diep (z), en op deze hoogte ligt wat er
## op het blad staat.  Groot genoeg voor de grootste plaat van het spel: acht
## rijen van tien koekjes (STAP × 10 + 2 bij STAP × 8 + 2).
const BANK_W := 46
const BANK_D := 38
const BANK_HOOG := 10
## Eén koekje per vak van STAP × STAP voxels: drie breed en één voxel lucht.
const STAP := 4
## Eieren in een kom: rijen van vier, om de drie voxels.
const EI_STAP := 3
const EI_RIJ := 4
## Een kom is zo breed (en zo diep), wand meegeteld.
const KOM_MAAT := 19

# ------------------------------------------------------------------ de oven

static func bakoven(p := {}) -> Array:
	var bakt := bool(p.get("bakt", false))
	var rest: int = clampi(int(p.get("rest", 0)), 0, 9)
	var v: Array = []
	ArtVorm.bx(v, -12, 0, -8, 24, 22, 16, STEEN)        # het lijf
	# stenen: een paar lichte en donkere blokjes op de voorkant en de zijkant
	for s in [[-10, 15], [-4, 18], [4, 16], [8, 19], [-8, 2], [6, 3]]:
		ArtVorm.verf(v, s[0], s[0] + 2, s[1], s[1] + 1, 7, 7, STEEN_L)
	for s in [[-2, 9], [9, 6], [-11, 7]]:
		ArtVorm.verf(v, s[0], s[0] + 2, s[1], s[1] + 1, 7, 7, STEEN_D)
	ArtVorm.verf(v, 11, 11, 4, 6, -6, -3, STEEN_L)
	ArtVorm.verf(v, 11, 11, 13, 15, 0, 3, STEEN_D)
	ArtVorm.bx(v, -13, 22, -9, 26, 2, 18, STEEN_D)      # het blad
	ArtVorm.bx(v, -8, 4, 7, 16, 9, 2, MOND)             # de mond, naar voren
	ArtVorm.bx(v, -9, 13, 7, 18, 1, 2, STEEN_D)         # de boog erboven
	if bakt:
		# het vuur brandt fel en de plaat schuift erin: haar rand steekt uit
		ArtVorm.bx(v, -6, 5, 8, 12, 4, 1, GLOED_D)
		ArtVorm.bx(v, -5, 6, 8, 10, 3, 1, GLOED)
		ArtVorm.bx(v, -3, 7, 8, 6, 2, 1, VUUR)
		ArtVorm.bx(v, -7, 9, 7, 14, 1, 3, PLAAT_L)
		for i in 4:
			v.append({"x": -5 + i * 3, "y": 10, "z": 8, "k": DEEG})
	else:
		ArtVorm.bx(v, -6, 5, 8, 12, 2, 1, GLOED_D)      # de gloed onderin
		ArtVorm.bx(v, -4, 5, 8, 8, 1, 1, GLOED)
	ArtVorm.bx(v, -10, 1, 7, 20, 2, 2, STEEN_D)         # de drempel
	ArtVorm.bx(v, -11, 24, -8, 6, 10, 6, STEEN_D)       # de schoorsteen, links achter
	ArtVorm.verf(v, -11, -6, 33, 33, -8, -3, MOND)
	if rest > 0:
		_zet(v, koekbord({"n": rest}), 5, OVEN_TOP, 1)
	return v

# ------------------------------------------------------------- de bakplaat

## Een plaat van `kolommen` × `rijen` vakken op de vloer van het model (y = 0);
## de koekjes liggen erop.  Rij 0 ligt achteraan (kleinste z), kolom 0 links.
static func bakplaat(p := {}) -> Array:
	var rijen: int = maxi(1, int(p.get("rijen", 2)))
	var kolommen: int = maxi(1, int(p.get("kolommen", 3)))
	var aantal: int = clampi(int(p.get("aantal", rijen * kolommen)), 0, rijen * kolommen)
	var gaar := bool(p.get("gaar", true))
	var w := kolommen * STAP + 2
	var d := rijen * STAP + 2
	var x0 := -(w >> 1)
	var z0 := -(d >> 1)
	var v: Array = []
	ArtVorm.bx(v, x0, 0, z0, w, 1, d, PLAAT)
	# de opstaande rand van de plaat
	ArtVorm.bx(v, x0, 1, z0, w, 1, 1, PLAAT_L)
	ArtVorm.bx(v, x0, 1, z0 + d - 1, w, 1, 1, PLAAT_L)
	ArtVorm.bx(v, x0, 1, z0 + 1, 1, 1, d - 2, PLAAT_L)
	ArtVorm.bx(v, x0 + w - 1, 1, z0 + 1, 1, 1, d - 2, PLAAT_L)
	for i in aantal:
		@warning_ignore("integer_division")
		var r := i / kolommen
		var k := i % kolommen
		_koekje(v, x0 + 2 + k * STAP, 1, z0 + 2 + r * STAP, gaar)
	return v

## Eén koekje met zijn midden op (cx, y, cz): drie bij drie, de hoeken een
## tint donkerder zodat het rond leest, en een bolletje in het midden.  Deeg is
## bleek met een licht bolletje; gebakken is het goudbruin met een stukje
## chocola erop.
static func _koekje(v: Array, cx: int, y: int, cz: int, gaar: bool) -> void:
	var kl := KOEK if gaar else DEEG
	var rand := KOEK_D if gaar else DEEG_D
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var hoek: bool = dx != 0 and dz != 0
			v.append({"x": cx + dx, "y": y, "z": cz + dz, "k": rand if hoek else kl})
	v.append({"x": cx, "y": y + 1, "z": cz, "k": CHOCO if gaar else DEEG_L})

# ------------------------------------------------------------- de eierkom

## Een kom met `n` eieren in rijen van vier (of vol beslag).  Om (0, 0): de
## kom is KOM_MAAT breed en diep, de wand 3 hoog; de eieren liggen binnen de
## wand op een raster, zodat je ze een voor een kunt tellen.
static func eierschaal(p := {}) -> Array:
	var n: int = clampi(int(p.get("n", 4)), 0, 12)
	var beslag := bool(p.get("beslag", false))
	var v: Array = []
	# een ronde kom: de bodem, en een wand van drie hoog
	for x in range(-9, 10):
		for z in range(-9, 10):
			var r2 := x * x + z * z
			if r2 <= 64:
				v.append({"x": x, "y": 0, "z": z, "k": KOM_D})
			elif r2 <= 92:
				for y in range(0, 4):
					v.append({"x": x, "y": y, "z": z, "k": KOM_L if y == 3 else KOM})
	if beslag:
		for x in range(-8, 9):
			for z in range(-8, 9):
				var r2b := x * x + z * z
				if r2b <= 64:
					v.append({"x": x, "y": 1, "z": z, "k": BESLAG})
					v.append({"x": x, "y": 2, "z": z,
						"k": BESLAG_L if posmod(x + 2 * z, 5) == 0 else BESLAG})
		return v
	for i in n:
		var c := _ei_vak(i)
		_ei(v, c.x, 1, c.y)
	return v

## Het vak van ei `i` in de kom: rijen van vier, om de drie voxels, het geheel
## rond het midden.
static func _ei_vak(i: int) -> Vector2i:
	@warning_ignore("integer_division")
	var rij := i / EI_RIJ
	var k := i % EI_RIJ
	return Vector2i(-5 + k * EI_STAP, -4 + rij * EI_STAP)

## Eén ei: twee bij twee voxels en drie hoog, de bovenste laag een puntje.
static func _ei(v: Array, x: int, y: int, z: int) -> void:
	ArtVorm.bx(v, x, y, z, 2, 2, 2, EI)
	v.append({"x": x, "y": y + 2, "z": z, "k": EI_D})
	v.append({"x": x + 1, "y": y + 2, "z": z + 1, "k": EI})

# ------------------------------------------------------------- de werkbank

## De grote bakkerstafel met wat erop ligt.  Alles ligt om het midden van het
## blad: eerst de plaat, dan de kommen naast elkaar, de losse eieren rechts
## daarvan.  Alleen wat het spel vraagt staat erop, zodat het getal op de tafel
## het getal van de som is.
static func werkbank(p := {}) -> Array:
	var v: Array = []
	var x0 := -(BANK_W >> 1)
	var z0 := -(BANK_D >> 1)
	var h := BANK_HOOG
	# vier poten en een plank onderin, dan het blad met een donkere rand
	for px in [x0 + 1, x0 + BANK_W - 3]:
		for pz in [z0 + 1, z0 + BANK_D - 3]:
			ArtVorm.bx(v, px, 0, pz, 2, h - 2, 2, POOT)
	ArtVorm.bx(v, x0 + 2, 2, z0 + 2, BANK_W - 4, 1, BANK_D - 4, BLAD_D)
	ArtVorm.bx(v, x0, h - 2, z0, BANK_W, 2, BANK_D, BLAD)
	ArtVorm.verf(v, x0, x0 + BANK_W - 1, h - 2, h - 2, z0, z0 + BANK_D - 1, BLAD_D)
	if bool(p.get("rol", false)):
		_rol(v, x0 + 6, h, z0 + 5)
	var rijen := int(p.get("rijen", 0))
	var kolommen := int(p.get("kolommen", 0))
	if rijen > 0 and kolommen > 0:
		_zet(v, bakplaat({"rijen": rijen, "kolommen": kolommen,
			"aantal": int(p.get("aantal", rijen * kolommen)),
			"gaar": bool(p.get("gaar", false))}), 0, h, 0)
	var kommen: Array = p.get("kommen", [])
	var los: int = clampi(int(p.get("los", 0)), 0, 6)
	if not kommen.is_empty() or los > 0:
		var breed := kommen.size() * KOM_MAAT + maxi(0, kommen.size() - 1) * 3
		var los_breed := (los * EI_STAP + 2) if los > 0 else 0
		var links := -((breed + los_breed) >> 1)
		for i in kommen.size():
			var cx := links + (KOM_MAAT >> 1) + i * (KOM_MAAT + 3)
			_zet(v, eierschaal({"n": int(kommen[i]), "beslag": bool(p.get("beslag", false))}),
				cx, h, 0)
		for j in los:
			_ei(v, links + breed + 2 + j * EI_STAP, h, -1)
	return v

## Een deegroller met twee handvatten en een hoopje meel ervoor.
static func _rol(v: Array, x: int, y: int, z: int) -> void:
	ArtVorm.bx(v, x, y, z, 10, 2, 2, ArtDecor.HOUT_L)
	ArtVorm.bx(v, x - 2, y, z, 2, 1, 1, ArtDecor.HOUT_D)
	ArtVorm.bx(v, x + 10, y, z, 2, 1, 1, ArtDecor.HOUT_D)
	for d in [[0, 4], [1, 4], [2, 4], [1, 5], [0, 5], [2, 5], [1, 6], [-1, 5], [3, 5]]:
		v.append({"x": x + 2 + d[0], "y": y, "z": z + d[1], "k": MEEL})
	v.append({"x": x + 3, "y": y + 1, "z": z + 5, "k": MEEL})

# ------------------------------------------------------------- het koekbord

## Een rond bordje met `n` gebakken koekjes (tot negen) in een vakje van drie
## bij drie.  Om (0, 0), 13 breed.
static func koekbord(p := {}) -> Array:
	var n: int = clampi(int(p.get("n", 3)), 0, 9)
	var v: Array = []
	for x in range(-6, 7):
		for z in range(-6, 7):
			if x * x + z * z <= 40:
				v.append({"x": x, "y": 0, "z": z, "k": BORD if x * x + z * z > 24 else BORD_L})
	for i in n:
		@warning_ignore("integer_division")
		var r := i / 3
		var k := i % 3
		_koekje(v, -4 + k * 4, 1, -4 + r * 4, true)
	return v

# ------------------------------------------------------------------ helpers

## Zet de voxels van een ander model verschoven in `v`.
static func _zet(v: Array, deel: Array, dx: int, dy: int, dz: int) -> void:
	for q in deel:
		var n: Dictionary = (q as Dictionary).duplicate()
		n["x"] = int(n["x"]) + dx
		n["y"] = int(n["y"]) + dy
		n["z"] = int(n["z"]) + dz
		v.append(n)

static func tabel() -> Dictionary:
	return {
		"bakoven": Callable(ArtDecorBakkerij, "bakoven"),
		"bakplaat": Callable(ArtDecorBakkerij, "bakplaat"),
		"eierschaal": Callable(ArtDecorBakkerij, "eierschaal"),
		"werkbank": Callable(ArtDecorBakkerij, "werkbank"),
		"koekbord": Callable(ArtDecorBakkerij, "koekbord"),
	}
