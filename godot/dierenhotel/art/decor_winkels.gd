extends RefCounted
class_name ArtDecorWinkels

## De Winkelstraat 🛍 (eigenaar, 2026-09-24: "Maak een level in een winkel level
## in het hotel met kraampjes en een luxe winkel ... Maak verschillende winkels
## met verschillende items zoals hoeden sjalen, schoenen etc.").  Een overdekte
## winkelgalerij naast de receptie: vier kraampjes met een gestreepte luifel
## langs de achterwand (hoeden, sjaals, schoenen en sinds 2026-09-24 de
## souvenirkraam die uit de tuin kwam), een luxe winkel met een
## gouden pui en een glazen vitrine langs de linkerwand, en een paskamer met een
## grote spiegel.  Eigen namen en een eigen tabel, aangemeld bij
## `ArtDecor._extra()`; zelfde bouwstenen, palet en bakweg als de rest van het
## hotel (art-sound-rules.md §8).
##
## Wandstukken (`luxepui`, `spiegel`, `winkelbord`) zijn gebouwd tegen de wand
## z = 0 (z van 0 naar voren) en hebben een `…z`-tweeling, over de diagonaal
## gespiegeld, voor de wand x = 0.
##
## DE KOOPWAAR.  Elk kledingstuk uit `ArtGasten.KLEDING` heeft hier ook een
## uitstalmodel, `waar_<naam>`: een hoed op een houten hoofdje, een opgevouwen
## sjaal, een paar schoentjes, een kroon op een kussen.  De winkelspellen zetten
## ze op hun toonbank, met het prijskaartje erboven (HOTEL.md §9: getallen op de
## dingen).  De hoeden zijn met dezelfde functies getekend als op het dier, dus
## wat je koopt is precies wat het dier straks draagt.

const HOUT := ArtDecor.HOUT
const HOUT_D := ArtDecor.HOUT_D
const HOUT_L := ArtDecor.HOUT_L
const METAAL := ArtDecor.METAAL
const METAAL_L := ArtDecor.METAAL_L
const GOUD := ArtDecor.GOUD
const GOUD_D := ArtDecor.GOUD_D
const PAPIER := ArtDecor.PAPIER
const BLAD_A := ArtDecor.BLAD_A
const BLAD_B := ArtDecor.BLAD_B
const POT := ArtDecor.POT

## Per kraampje een eigen streep in de luifel, zodat een kind ze uit elkaar
## houdt zonder te lezen: roze voor de hoeden, mint voor de sjaals, blauw voor
## de schoenen, geel voor de souvenirs (de kraam die uit de tuin hierheen
## verhuisde, eigenaar 2026-09-24).
const STREEP := {"hoeden": Color("#F2A7B8"), "sjaals": Color("#9FD8C4"),
	"schoenen": Color("#A9CDEE"), "souvenirs": Color("#F5D37A")}
const STREEP_D := {"hoeden": Color("#E38DA1"), "sjaals": Color("#83C6AE"),
	"schoenen": Color("#8DB8E0"), "souvenirs": Color("#E6BC55")}
const CADEAU := Color("#F2A7B8")       ## het cadeautje op het bord van de souvenirkraam
const LUIFEL_WIT := Color("#FFF7EC")
const PAARS := Color("#A77DB6")       ## het fluweel van de luxe winkel
const PAARS_D := Color("#8E66A0")
const ROOM := Color("#FBF1E2")        ## de pilaren van de pui
const GLAS := Color("#CFE9EE")
const GLAS_L := Color("#E6F5F7")
const SPIEGEL := Color("#DCEFF4")
const SPIEGEL_L := Color("#F2FAFC")
const GORDIJN := Color("#E9A6B4")
const GORDIJN_D := Color("#D98C9C")
const LANTAARN := Color("#6E6A72")
const LICHT := Color("#FFE8A3")
const TAS := [Color("#F2A7B8"), Color("#A9CDEE"), Color("#9FD8C4")]
const KUSSEN := Color("#B98BC4")

const NAMEN: Array[String] = ["hoedenkraam", "sjaalkraam", "schoenenkraam",
	"souvenirkraam", "luxepui", "luxepuiz", "vitrine", "vitrinez", "spiegel", "spiegelz",
	"lantaarn", "winkelbord", "winkelbordz", "tassen", "bloembak", "cadeaudoos",
	"waar_hoedje", "waar_sjaaltje", "waar_bal", "waar_pet", "waar_strohoed",
	"waar_strik", "waar_kroon", "waar_streepsjaal", "waar_das", "waar_parels",
	"waar_gympjes", "waar_laarsjes", "waar_sokjes", "waar_slofjes", "waar_zonnebril"]

## De hoogte van de toonbank van een kraampje en van de vitrine: daar zetten de
## spellen hun koopwaar op.
const KRAAM_TOP := 10
const VITRINE_TOP := 9

# ------------------------------------------------------------- de kraampjes

## Een marktkraampje, 26 breed (x) en 16 diep (z), dat met zijn rug tegen de
## achterwand staat: een houten toonbank met een gekleurde band aan de voorkant,
## vier palen, een schuine gestreepte luifel met een geschulpte rand, en achterin
## een rek met wat het kraampje verkoopt.  De streep en het rek volgen de soort.
##
## De souvenirkraam (`souvenirs`, de vierde in de rij, uit de tuin verhuisd)
## heeft daarnaast een bordje op de luifel: een wit bord in een gouden lijst met
## een roze cadeautje erop, het 🎁 van de knop — zo zie je zonder te lezen dat
## hier de souvenirs zijn.  Op de plank het hoedje, het sjaaltje en de bal.
static func kraam(soort: String) -> Array:
	var v: Array = []
	var kl: Color = STREEP.get(soort, STREEP["hoeden"])
	var kl_d: Color = STREEP_D.get(soort, STREEP_D["hoeden"])
	# de toonbank, met de band in de kraamkleur op de voorkant
	ArtVorm.bx(v, -12, 0, 1, 24, KRAAM_TOP - 1, 6, HOUT)
	ArtVorm.verf(v, -12, 11, 0, 0, 1, 6, HOUT_D)
	ArtVorm.verf(v, -12, 11, 4, 6, 6, 6, kl)
	ArtVorm.bx(v, -13, KRAAM_TOP - 1, 0, 26, 1, 8, HOUT_L)
	# de palen: twee achter tegen de wand, twee voor op de toonbank
	ArtVorm.bx(v, -13, 0, -8, 2, 27, 2, HOUT_D)
	ArtVorm.bx(v, 11, 0, -8, 2, 27, 2, HOUT_D)
	ArtVorm.bx(v, -13, KRAAM_TOP, 6, 1, 14, 1, HOUT_D)
	ArtVorm.bx(v, 12, KRAAM_TOP, 6, 1, 14, 1, HOUT_D)
	# de luifel: van achter (y 28) schuin naar voor (y 25), strepen van 4 breed
	for z in range(-8, 9):
		var y := 28 - int(floor(float(z + 8) / 5.5))
		for x in range(-14, 14):
			var streep := posmod(int(floor(float(x + 14) / 4.0)), 2) == 0
			v.append({"x": x, "y": y, "z": z, "k": kl if streep else LUIFEL_WIT})
	# de geschulpte rand aan de voorkant: om de vier een flapje naar beneden
	for x in range(-14, 14):
		var streep := posmod(int(floor(float(x + 14) / 4.0)), 2) == 0
		v.append({"x": x, "y": 24, "z": 8, "k": kl_d if streep else LUIFEL_WIT})
		if posmod(x + 14, 4) in [1, 2]:
			v.append({"x": x, "y": 23, "z": 8, "k": kl_d if streep else LUIFEL_WIT})
	# het rek achterin
	match soort:
		"sjaals":
			ArtVorm.bx(v, -11, 22, -6, 22, 1, 1, METAAL)
			var sjaals := [ArtGasten.SJAAL, ArtGasten.STREEP_KL, ArtGasten.DAS_KL, Color("#9FD8C4")]
			for i in 4:
				var sx := -9 + i * 5
				ArtVorm.bx(v, sx, 12, -6, 2, 10, 1, sjaals[i])
				ArtVorm.bx(v, sx, 12, -6, 2, 1, 1, LUIFEL_WIT)
				if i == 1:
					for y in range(12, 22, 3):
						ArtVorm.verf(v, sx, sx + 1, y, y, -6, -6, LUIFEL_WIT)
		"schoenen":
			for plank in [12, 18]:
				ArtVorm.bx(v, -11, plank, -7, 22, 1, 4, HOUT_D)
			var paren := [[-9, 13, ArtGasten.GYMP], [-2, 13, ArtGasten.LAARS],
				[5, 13, ArtGasten.SOK], [-6, 19, ArtGasten.GOUD], [2, 19, ArtGasten.GYMP]]
			for p in paren:
				ArtVorm.bx(v, p[0], p[1], -6, 3, 2, 1, p[2])
				ArtVorm.bx(v, p[0], p[1], -4, 3, 2, 1, p[2])
		"souvenirs":
			ArtVorm.bx(v, -11, 14, -7, 22, 1, 4, HOUT_D)
			# de drie souvenirs uit de tuin op de plank: hoedje, sjaaltje, bal
			_zet(v, _op_hoofdje("hoedje", false), -7, 15, -5)
			_zet(v, waar("sjaaltje"), 0, 15, -5)
			_zet(v, waar("bal"), 7, 15, -5)
			# het bordje boven op de luifel, tegen de achterste rand
			# (the awning's back row is y 28, so the sign starts on top of it)
			ArtVorm.bx(v, -7, 29, -8, 14, 10, 1, GOUD)
			ArtVorm.bx(v, -6, 30, -7, 12, 8, 1, PAPIER)
			ArtVorm.bx(v, -3, 31, -6, 6, 5, 1, CADEAU)
			ArtVorm.verf(v, -1, 0, 31, 35, -6, -6, GOUD)
			ArtVorm.verf(v, -3, 2, 33, 33, -6, -6, GOUD)
			ArtVorm.bx(v, -2, 36, -6, 2, 1, 1, GOUD)
			ArtVorm.bx(v, 0, 36, -6, 2, 1, 1, GOUD_D)
		_:
			ArtVorm.bx(v, -11, 14, -7, 22, 1, 4, HOUT_D)
			# drie hoedjes op de plank: een pet, een strohoed, een strik
			_zet(v, _op_hoofdje("pet", false), -7, 15, -5)
			_zet(v, _op_hoofdje("strohoed", false), 0, 15, -5)
			_zet(v, _op_hoofdje("strik", false), 7, 15, -5)
	return v

# ---------------------------------------------------------- de luxe winkel

## De pui van de luxe winkel tegen de wand z = 0: 44 lang, een paars sokkeltje,
## twee roomwitte pilaren met gouden kapitelen, twee etalages met een gouden
## lijst (links een kroon op een kussen, rechts een parelketting), een paars
## uithangbord met een gouden kroontje erop en een paarse luifel met gouden
## franje.  Alles blijft binnen 4 van de wand: het is een gevel, geen kast.
static func luxepui(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -22, 0, 0, 44, 4, 3, PAARS_D)
	for px in [-22, -3, 18]:
		ArtVorm.bx(v, px, 4, 0, 4, 24, 3, ROOM)
		ArtVorm.bx(v, px - 1, 27, 0, 6, 1, 4, GOUD)
		ArtVorm.bx(v, px - 1, 4, 0, 6, 1, 4, GOUD_D)
	# twee etalages
	for ex in [-18, 1]:
		ArtVorm.bx(v, ex, 5, 1, 15, 21, 1, GLAS)
		ArtVorm.verf(v, ex, ex + 14, 24, 25, 1, 1, GLAS_L)
		ArtVorm.bx(v, ex, 4, 1, 15, 1, 2, GOUD)
		ArtVorm.bx(v, ex, 26, 1, 15, 1, 2, GOUD)
	# wat erin ligt: op een kussentje vóór het glas, zodat je het ziet
	ArtVorm.bx(v, -14, 5, 2, 7, 2, 2, KUSSEN)
	_zet(v, _kroon_los(), -10, 7, 3)
	ArtVorm.bx(v, 5, 5, 2, 7, 2, 2, KUSSEN)
	for i in 6:
		var a := float(i) / 6.0 * TAU
		v.append({"x": 8 + int(round(cos(a) * 2.4)), "y": 9 + int(round(sin(a) * 2.4)), "z": 3,
			"k": ArtGasten.PAREL if i % 2 == 0 else GOUD})
	# het uithangbord met de kroon, en de luifel erboven
	ArtVorm.bx(v, -20, 28, 0, 40, 5, 3, PAARS)
	ArtVorm.verf(v, -20, 19, 28, 28, 0, 2, GOUD)
	ArtVorm.verf(v, -20, 19, 32, 32, 0, 2, GOUD)
	for i in 5:
		ArtVorm.bx(v, -3 + i, 29, 3, 1, 2 + (i % 2), 1, GOUD)
	for z in range(0, 6):
		var y := 36 - int(floor(float(z) / 2.0))
		ArtVorm.bx(v, -22, y, z, 44, 1, 1, PAARS if z % 2 == 0 else PAARS_D)
	for x in range(-22, 22, 2):
		v.append({"x": x, "y": 32, "z": 5, "k": GOUD})
	return v

## De glazen vitrine voor de luxe winkel, 24 lang (x) en 8 diep: een paarse voet,
## een gouden rand, een glazen bovenkant, en daar zet het spel de sieraden op.
static func vitrine(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -12, 0, -4, 24, VITRINE_TOP - 3, 8, PAARS)
	ArtVorm.verf(v, -12, 11, 0, 0, -4, 3, PAARS_D)
	ArtVorm.bx(v, -12, VITRINE_TOP - 3, -4, 24, 1, 8, GOUD)
	ArtVorm.bx(v, -12, VITRINE_TOP - 2, -4, 24, 2, 8, GLAS)
	ArtVorm.verf(v, -12, 11, VITRINE_TOP - 1, VITRINE_TOP - 1, -4, 3, GLAS_L)
	# gouden hoekjes
	for hx in [-12, 11]:
		for hz in [-4, 3]:
			ArtVorm.bx(v, hx, VITRINE_TOP - 2, hz, 1, 2, 1, GOUD_D)
	return v

# --------------------------------------------------------------- de paskamer

## De spiegel van de paskamer, tegen de wand z = 0: een ovale spiegel van 14
## breed en 26 hoog in een gouden lijst, op een voet, met een roze gordijntje
## ernaast.  Hier kiest een dier wat het aantrekt.
static func spiegel(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -8, 0, 0, 16, 2, 4, HOUT_D)
	for x in range(-8, 8):
		for y in range(2, 32):
			var dx := (float(x) + 0.5) / 8.0
			var dy := (float(y) - 17.0) / 15.0
			var d := dx * dx + dy * dy
			if d > 1.0:
				continue
			var kl := GOUD if d > 0.72 else (SPIEGEL_L if (x + y) % 9 == 0 or x - y == -20 else SPIEGEL)
			v.append({"x": x, "y": y, "z": 0, "k": kl})
			if d > 0.72:
				v.append({"x": x, "y": y, "z": 1, "k": GOUD_D})
	# het gordijn rechts ervan, in plooien
	for x in range(10, 17):
		var plooi := GORDIJN if x % 2 == 0 else GORDIJN_D
		ArtVorm.bx(v, x, 0, 0, 1, 30, 2, plooi)
	ArtVorm.bx(v, 9, 30, 0, 9, 1, 3, GOUD)
	return v

# ------------------------------------------------------------ de aankleding

## Een straatlantaarn op de galerij: een donkere paal, een vierkante lamp met
## een warm licht erin en een krulletje.
static func lantaarn(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -2, 0, -2, 4, 2, 4, LANTAARN)
	ArtVorm.bx(v, -1, 2, -1, 2, 30, 2, LANTAARN)
	ArtVorm.bx(v, -3, 32, -3, 6, 1, 6, LANTAARN)
	ArtVorm.bx(v, -2, 33, -2, 4, 5, 4, LICHT)
	ArtVorm.verf(v, -2, 1, 33, 37, -2, -2, LANTAARN)
	ArtVorm.verf(v, -2, -2, 33, 37, -2, 1, LANTAARN)
	ArtVorm.bx(v, -3, 38, -3, 6, 1, 6, LANTAARN)
	ArtVorm.bx(v, -1, 39, -1, 2, 2, 2, LANTAARN)
	return v

## Een bordje naast een deur, tegen de wand z = 0: een wit bord met een gouden
## rand en een roze boodschappentas erop — de deur van de receptie naar de
## winkelstraat laat zo zien waar hij heen gaat (eigenaar, 2026-09-23: "elke
## overgang laat zien waar hij heen gaat").
static func winkelbord(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -6, 0, 0, 12, 10, 1, GOUD)
	ArtVorm.bx(v, -5, 1, 1, 10, 8, 1, PAPIER)
	# de tas: een roze blok met twee hengsels
	ArtVorm.bx(v, -3, 2, 2, 6, 5, 1, TAS[0])
	ArtVorm.bx(v, -2, 7, 2, 1, 1, 1, STREEP_D["hoeden"])
	ArtVorm.bx(v, 1, 7, 2, 1, 1, 1, STREEP_D["hoeden"])
	ArtVorm.bx(v, -2, 8, 2, 4, 1, 1, STREEP_D["hoeden"])
	return v

## Een stapeltje boodschappentassen op de vloer: drie tassen in de kraamkleuren.
static func tassen(_p := {}) -> Array:
	var v: Array = []
	var plek := [[-4, 0], [2, -3], [1, 3]]
	for i in 3:
		var tx: int = plek[i][0]
		var tz: int = plek[i][1]
		ArtVorm.bx(v, tx, 0, tz, 5, 7, 3, TAS[i])
		ArtVorm.bx(v, tx + 1, 7, tz + 1, 1, 2, 1, PAPIER)
		ArtVorm.bx(v, tx + 3, 7, tz + 1, 1, 2, 1, PAPIER)
		ArtVorm.bx(v, tx + 1, 9, tz + 1, 3, 1, 1, PAPIER)
	return v

## Een lange bloembak met bloemetjes, voor de sfeer van een winkelstraat.
static func bloembak(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -9, 0, -3, 18, 5, 6, POT)
	ArtVorm.verf(v, -9, 8, 4, 4, -3, 2, Color("#E8A283"))
	for x in [-7, -3, 1, 5]:
		ArtVorm.ell(v, x, 6.5, 0.0, 2.2, 1.8, 2.2, BLAD_A, {"e": 2.2, "ymin": 5})
		ArtVorm.bx(v, x, 8, 0, 1, 1, 1, TAS[((x + 7) >> 2) % 3])
	return v

# --------------------------------------------------------------- de koopwaar

## Verschuif een stuk voxels.
static func _zet(v: Array, stuk: Array, dx: int, dy: int, dz: int) -> void:
	for q in stuk:
		v.append({"x": int(q["x"]) + dx, "y": int(q["y"]) + dy, "z": int(q["z"]) + dz, "k": q["k"]})

## Een hoed zoals het dier hem draagt, op een houten hoofdje (met de voet erbij
## of niet), het anker midden onder de voet.  Het hoofdje staat op z = 7.5
## zoals de kop van een dier, dus de functies van `ArtGasten` passen erop.
static func _op_hoofdje(naam: String, voet := true) -> Array:
	var v: Array = []
	var basis := 0
	if voet:
		ArtVorm.bx(v, -2, 0, 6, 4, 1, 4, HOUT_D)
		ArtVorm.bx(v, -1, 1, 7, 2, 2, 2, HOUT_D)
		basis = 3
	ArtVorm.ell(v, 0.0, float(basis) + 2.4, 7.5, 2.8, 2.4, 2.8, HOUT_L, {"e": 2.4, "ymin": basis})
	var k := [0.0, float(basis) + 4.6, 2.9, 2.9]
	var y0 := basis + 3
	match naam:
		"hoedje":
			ArtGasten.hoedje(v, k, 0, 0.0)
		"pet":
			ArtGasten.pet(v, k, y0)
		"strohoed":
			ArtGasten.strohoed(v, k, y0)
		"strik":
			ArtGasten.strik(v, k, y0 + 1)
		"kroon":
			ArtGasten.kroon(v, k, y0 + 1)
	for q in v:
		q["z"] = int(q["z"]) - 7
	return v

## Een kroontje los, op z = 0.
static func _kroon_los() -> Array:
	var v: Array = []
	ArtGasten.kroon(v, [0.0, 0.0, 2.9, 2.9], 0)
	for q in v:
		q["z"] = int(q["z"]) - 7
	return v

## Het uitstalmodel van één kledingstuk, het anker op de vloer (of de toonbank)
## onder het midden.  Klein: hooguit 8 breed, zoals op het dier.
static func waar(naam: String) -> Array:
	var v: Array = []
	match naam:
		"hoedje", "pet", "strohoed", "strik":
			return _op_hoofdje(naam)
		"kroon":
			ArtVorm.bx(v, -3, 0, -3, 7, 2, 7, KUSSEN)
			ArtVorm.bx(v, -3, 0, -3, 1, 1, 1, GOUD)
			_zet(v, _kroon_los(), 0, 2, 0)
		"sjaaltje", "streepsjaal":
			var kl := ArtGasten.SJAAL if naam == "sjaaltje" else ArtGasten.STREEP_KL
			ArtVorm.bx(v, -3, 0, -2, 7, 3, 5, kl)
			ArtVorm.bx(v, -3, 0, 3, 7, 1, 1, LUIFEL_WIT)
			if naam == "streepsjaal":
				ArtVorm.verf(v, -2, -2, 0, 2, -2, 3, LUIFEL_WIT)
				ArtVorm.verf(v, 1, 1, 0, 2, -2, 3, LUIFEL_WIT)
		"das":
			ArtVorm.bx(v, -1, 0, -4, 2, 1, 2, ArtGasten.DAS_KNOOP)
			ArtVorm.bx(v, -1, 0, -2, 2, 1, 6, ArtGasten.DAS_KL)
			ArtVorm.bx(v, -1, 0, 4, 2, 1, 1, ArtGasten.DAS_KNOOP)
		"parels":
			ArtVorm.bx(v, -4, 0, -4, 8, 1, 8, KUSSEN)
			for i in 10:
				var a := float(i) / 10.0 * TAU
				v.append({"x": int(round(cos(a) * 3.0)), "y": 1, "z": int(round(sin(a) * 3.0)),
					"k": ArtGasten.PAREL if i % 2 == 0 else GOUD})
		"gympjes", "laarsjes", "sokjes", "slofjes":
			var hoog := 4 if naam == "laarsjes" or naam == "sokjes" else 2
			for sz in [-3, 1]:
				ArtVorm.bx(v, -3, 0, sz, 6, 2, 2, HOUT_L)
				ArtVorm.bx(v, 1, 0, sz, 2, hoog, 2, HOUT_L)
				var n0 := v.size() - 2 * 6 * 2 - 2 * hoog * 2
				for i in range(n0, v.size()):
					var y := int(v[i]["y"])
					match naam:
						"gympjes":
							v[i]["k"] = PAPIER if y == 0 else ArtGasten.GYMP
						"laarsjes":
							v[i]["k"] = ArtGasten.LAARS_RAND if y == hoog - 1 else ArtGasten.LAARS
						"sokjes":
							v[i]["k"] = ArtGasten.SOK if y % 2 == 0 else PAPIER
						_:
							v[i]["k"] = ArtGasten.GOUD_D if y == 0 else ArtGasten.GOUD
		"zonnebril":
			ArtVorm.bx(v, -1, 0, -1, 2, 3, 2, HOUT_D)
			ArtVorm.bx(v, 0, 3, -4, 1, 3, 3, ArtGasten.MONTUUR)
			ArtVorm.bx(v, 0, 3, 1, 1, 3, 3, ArtGasten.MONTUUR)
			ArtVorm.verf(v, 0, 0, 3, 4, -3, -3, ArtGasten.GLAS)
			ArtVorm.verf(v, 0, 0, 3, 4, 2, 2, ArtGasten.GLAS)
			ArtVorm.bx(v, 0, 5, -1, 1, 1, 2, ArtGasten.MONTUUR)
		"bal":
			ArtVorm.ell(v, 0.0, 2.7, 0.0, 2.7, 2.7, 2.7, ArtGasten.BAL_KL, {"e": 2.2})
			for q in v:
				if int(q["y"]) == 3:
					q["k"] = ArtGasten.BAL_BAND
	return v

## Het cadeaudoosje van de luxe winkel: roze met een gouden lint en een strik.
static func cadeaudoos(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -3, 0, -3, 6, 5, 6, Color("#F2A7B8"))
	ArtVorm.verf(v, -1, 0, 0, 4, -3, 2, GOUD)
	ArtVorm.verf(v, -3, 2, 0, 4, -1, 0, GOUD)
	ArtVorm.bx(v, -2, 5, -1, 2, 1, 2, GOUD)
	ArtVorm.bx(v, 0, 5, -1, 2, 1, 2, GOUD_D)
	return v

# --------------------------------------------------------------------- register

## `naam -> Callable(params) -> Array` of voxels {x, y, z, k}.
static func tabel() -> Dictionary:
	var t := {
		"hoedenkraam": func(_p := {}): return kraam("hoeden"),
		"sjaalkraam": func(_p := {}): return kraam("sjaals"),
		"schoenenkraam": func(_p := {}): return kraam("schoenen"),
		"souvenirkraam": func(_p := {}): return kraam("souvenirs"),
		"luxepui": Callable(ArtDecorWinkels, "luxepui"),
		"luxepuiz": func(_p := {}): return ArtVorm.draai(luxepui()),
		"vitrine": Callable(ArtDecorWinkels, "vitrine"),
		"vitrinez": func(_p := {}): return ArtVorm.draai(vitrine()),
		"spiegel": Callable(ArtDecorWinkels, "spiegel"),
		"spiegelz": func(_p := {}): return ArtVorm.draai(spiegel()),
		"lantaarn": Callable(ArtDecorWinkels, "lantaarn"),
		"winkelbord": Callable(ArtDecorWinkels, "winkelbord"),
		"winkelbordz": func(_p := {}): return ArtVorm.draai(winkelbord()),
		"tassen": Callable(ArtDecorWinkels, "tassen"),
		"bloembak": Callable(ArtDecorWinkels, "bloembak"),
		"cadeaudoos": Callable(ArtDecorWinkels, "cadeaudoos"),
	}
	for naam in ArtGasten.KLEDING:
		t["waar_" + str(naam)] = _waar_fn(str(naam))
	return t

static func _waar_fn(naam: String) -> Callable:
	return func(_p := {}): return waar(naam)
