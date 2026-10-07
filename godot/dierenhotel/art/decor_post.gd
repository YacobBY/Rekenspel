extends RefCounted
class_name ArtDecorPost

## De postkamer 💌 (U4, 2026-10-07; owner: "Verzin nog vier kamers met
## activiteiten").  Een klein kamertje achter de lobby: de VAKKENKAST met vier
## vakjes langs de achterwand (z = 0) — de getallenlijn van `games/post` —,
## de POSTKAR met de stapel brieven van de dag midden in de kamer, en langs de
## linkerwand (x = 0) de ZEGELBALIE met de PAKKETWEEGSCHAAL erop.  Zelfde
## bouwstenen en palet als de rest van het hotel (`ArtVorm`, `ArtDecor`); een
## voxel is {x, y, z, k}, y omhoog.
##
## Every anchor (0, 0, 0) lies on the floor: the shelf's under the middle of its
## BACK edge (it stands against the wall z = 0, its holes open toward +z), the
## counter's under the middle of its WALL edge (against x = 0, its front toward
## +x), the cart's under its middle.  The letters are part of the shelf's and
## the cart's own model, never loose decor of their own: loose decor sorts on
## its floor point, so a letter on the back half of the cart would be drawn
## before the cart and vanish under its rim (the oogst punnets, games-c.md §2.4).
##
## Registered by the game as `post_kast`, `post_kar` and `post_balie`
## (`definitie().modellen` = `spel_tabel()`, `Games._meld_modellen`), so the
## resting props stand in the room before the game ever ran.  Also hooked into
## `ArtDecor._extra()` (integration I1a, 2026-10-07): `NAMEN` and `tabel()` make
## the four pieces world models under their own names, with their pixel
## goldens; no room places them as fixed decor (integration I1b: the
## postkamer's shelf, counter and cart are the game's resting props only).

const HOUT := ArtDecor.HOUT
const HOUT_D := ArtDecor.HOUT_D
const HOUT_L := ArtDecor.HOUT_L
const PAPIER := ArtDecor.PAPIER
const METAAL := ArtDecor.METAAL
const METAAL_L := ArtDecor.METAAL_L
const WIEL := Color("#6E5A4A")
## The post's own colours: a soft letter-box red for the cart and the stamps,
## a cream envelope with a darker fold line, brown cardboard for the parcel.
const ROOD := Color("#E4574B")
const ROOD_L := Color("#F08A7E")
const ENVELOP := Color("#FFF4DC")
const VOUW := Color("#E8D5B0")
const KARTON := Color("#D9A766")
const KARTON_D := Color("#C08C4C")
const BLAUW := Color("#8FB8DE")
## The inside of the holes, alternating so four holes read as four.
const VAK_A := Color("#F3DFC1")
const VAK_B := Color("#EBD2AE")

## The shelf: four holes of VAK_BREED wide with dividers of WAND between them.
## A pitch of 20 voxels keeps the four number plates of `games/post` apart on
## a tablet: at 1024 × 768 with the maths bar docked one voxel is 1.63 units
## down the diagonal, so two neighbouring plates stand 33 units apart in
## height, more than the 26 a plate is tall (16 voxels did not: 26.1).
const VAKKEN := 4
const VAK_BREED := 18
const WAND := 2
const LENGTE := VAKKEN * VAK_BREED + (VAKKEN + 1) * WAND     ## 82
const DIEP := 10
const VOET := 4          ## the plinth; the floor of a hole is at y = VOET
const VAK_HOOG := 14     ## inside height of a hole
const BOVEN := VOET + 1 + VAK_HOOG                            ## 19: the top plank
const BORD := BOVEN + 2  ## 21: the name board over the holes, at the front
const HOOG := BORD + 5   ## 26: the top of the shelf
const MAX_BRIEVEN := 6   ## a hole shows at most this many letters (the pile is ≤ 6)
const BRIEF_DIK := 2     ## every letter is two voxels thick, so each one counts

## The world names (`ArtDecor._extra()` lists every name of `tabel()`).
const NAMEN: Array[String] = ["vakkenkast", "postkar", "pakketweegschaal", "zegelbalie"]

## Where the middle of hole `j` is, relative to the shelf's anchor (x along
## the shelf, z at its open front).  The game hangs a hole's number plate there.
static func vak_midden(j: int) -> Vector2:
	var x0 := -int(LENGTE / 2.0) + WAND + j * (VAK_BREED + WAND)
	return Vector2(float(x0) + VAK_BREED / 2.0, float(DIEP))

## The sorting shelf.  params: {vol: [int] — letters already in each hole}.
static func vakkenkast(params: Dictionary = {}) -> Array:
	var v: Array = []
	var vol: Array = params.get("vol", [])
	var x0 := -int(LENGTE / 2.0)
	# the back panel, the plinth and the top plank
	ArtVorm.bx(v, x0, 0, 0, LENGTE, BOVEN + 1, 1, HOUT_D)
	ArtVorm.bx(v, x0, 0, 1, LENGTE, VOET, DIEP - 1, HOUT_D)
	ArtVorm.verf(v, x0, x0 + LENGTE - 1, 1, 1, DIEP - 1, DIEP - 1, HOUT)
	ArtVorm.bx(v, x0 - 1, BOVEN, 0, LENGTE + 2, 2, DIEP + 1, HOUT_L)
	# the name board along the FRONT of the top, a label card over every hole:
	# the game's number plate stands right on it (`games/post`), and where a
	# frame is too small for the plates the cards are simply the shelf's labels
	ArtVorm.bx(v, x0, BORD, DIEP - 2, LENGTE, HOOG - BORD, 2, HOUT)
	ArtVorm.verf(v, x0, x0 + LENGTE - 1, HOOG - 1, HOOG - 1, DIEP - 2, DIEP - 1, HOUT_L)
	for j in VAKKEN:
		var vx := x0 + WAND + j * (VAK_BREED + WAND)
		ArtVorm.verf(v, vx + 3, vx + VAK_BREED - 4, BORD + 1, BORD + 3, DIEP - 1, DIEP - 1, PAPIER)
		# the inside of the hole, and its floor
		ArtVorm.bx(v, vx, VOET + 1, 1, VAK_BREED, VAK_HOOG, 1, VAK_A if j % 2 == 0 else VAK_B)
		ArtVorm.bx(v, vx, VOET, 1, VAK_BREED, 1, DIEP - 1, HOUT_L)
		# the letters already sorted into it, flat on top of each other
		var n := clampi(int(vol[j]) if j < vol.size() else 0, 0, MAX_BRIEVEN)
		for b in n:
			var y := VOET + 1 + b * BRIEF_DIK
			ArtVorm.bx(v, vx + 2, y, 2, VAK_BREED - 4, BRIEF_DIK, DIEP - 4, ENVELOP)
			ArtVorm.verf(v, vx + 2, vx + VAK_BREED - 3, y, y, 2, DIEP - 3, VOUW)
			ArtVorm.bx(v, vx + VAK_BREED - 5, y + 1, DIEP - 4, 2, 1, 1, ROOD if b % 2 == 0 else BLAUW)
	# the five uprights, in front of everything inside
	for j in VAKKEN + 1:
		var sx := x0 + j * (VAK_BREED + WAND)
		ArtVorm.bx(v, sx, VOET, 1, WAND, BOVEN - VOET, DIEP, HOUT)
		ArtVorm.verf(v, sx, sx + WAND - 1, VOET, BOVEN - 1, DIEP - 1, DIEP - 1, HOUT_L)
	return v

## The mail cart: a red box on four wheels with a push handle on its −x side
## (the postbode stands there, toward the door), and the pile of the day's
## letters in it.
## params: {brieven: int} — the pile follows what is still to be sorted.
static func postkar(params: Dictionary = {}) -> Array:
	var v: Array = []
	var n := clampi(int(params.get("brieven", 0)), 0, MAX_BRIEVEN)
	# wheels
	for wx in [-9, 6]:
		for wz in [-7, 5]:
			ArtVorm.bx(v, wx, 0, wz, 3, 3, 2, WIEL)
	# the box: a floor and four low walls
	ArtVorm.bx(v, -10, 3, -7, 20, 1, 14, HOUT_D)
	ArtVorm.bx(v, -10, 4, -7, 20, 7, 1, ROOD)
	ArtVorm.bx(v, -10, 4, 6, 20, 7, 1, ROOD)
	ArtVorm.bx(v, -10, 4, -6, 1, 7, 12, ROOD)
	ArtVorm.bx(v, 9, 4, -6, 1, 7, 12, ROOD)
	ArtVorm.verf(v, -10, 9, 10, 10, -7, 6, ROOD_L)
	# a white envelope painted on the front, so the cart says "post"
	ArtVorm.bx(v, -5, 6, 7, 9, 4, 1, ENVELOP)
	ArtVorm.verf(v, -1, 0, 7, 7, 7, 7, ROOD)
	# the handle on the −x side
	ArtVorm.bx(v, -11, 8, -5, 1, 8, 1, METAAL)
	ArtVorm.bx(v, -11, 8, 4, 1, 8, 1, METAAL)
	ArtVorm.bx(v, -12, 15, -5, 1, 1, 10, METAAL_L)
	# the pile: one envelope per letter, each with its own stamp
	for b in n:
		var y := 4 + b * BRIEF_DIK
		ArtVorm.bx(v, -8, y, -5, 16, BRIEF_DIK, 10, ENVELOP)
		ArtVorm.verf(v, -8, 7, y, y, -5, 4, VOUW)
		ArtVorm.bx(v, 4, y + 1, 3 if b % 2 == 0 else 2, 2, 1, 2, ROOD if b % 2 == 0 else BLAUW)
	return v

## The parcel scale: a grey platform with a round dial, a parcel on it.
## Built at (x, y, z) inside another model (the counter carries it).
static func _weegschaal(v: Array, x: int, y: int, z: int, met_pakket: bool) -> void:
	ArtVorm.bx(v, x, y, z, 9, 1, 9, METAAL)
	ArtVorm.bx(v, x, y + 1, z, 9, 1, 9, METAAL_L)
	# the dial on a short post at the wall side, facing +x
	ArtVorm.bx(v, x + 1, y + 2, z + 4, 1, 4, 1, METAAL)
	for dy in range(-3, 4):
		for dz in range(-3, 4):
			if dy * dy + dz * dz <= 10:
				v.append({"x": x + 1, "y": y + 9 + dy, "z": z + 4 + dz, "k": PAPIER})
	v.append({"x": x + 2, "y": y + 9, "z": z + 4, "k": ROOD})
	v.append({"x": x + 2, "y": y + 10, "z": z + 4, "k": ROOD})
	if met_pakket:
		ArtVorm.bx(v, x + 3, y + 2, z + 1, 6, 5, 7, KARTON)
		ArtVorm.verf(v, x + 3, x + 8, y + 6, y + 6, z + 4, z + 4, KARTON_D)
		ArtVorm.verf(v, x + 8, x + 8, y + 2, y + 6, z + 4, z + 4, KARTON_D)

## The parcel scale on its own (the counter carries one).
static func pakketweegschaal(_params: Dictionary = {}) -> Array:
	var v: Array = []
	_weegschaal(v, -4, 0, -4, true)
	return v

## The stamp counter along the wall x = 0, 28 long in z: a sheet of stamps on
## the back half of its top, the parcel scale on the front half.
static func zegelbalie(_params: Dictionary = {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, 0, 0, -14, 13, 11, 28, HOUT)
	ArtVorm.verf(v, 12, 12, 0, 1, -14, 13, HOUT_D)
	ArtVorm.verf(v, 12, 12, 5, 5, -14, 13, HOUT_L)
	ArtVorm.bx(v, 0, 11, -15, 15, 2, 30, HOUT_L)
	# the stamp sheet: rows of little red and blue stamps on white
	ArtVorm.bx(v, 3, 13, -12, 8, 1, 10, PAPIER)
	for sx in [4, 7]:
		for sz in [-11, -8, -5]:
			ArtVorm.bx(v, sx, 14, sz, 2, 1, 2, ROOD if (sx + sz) % 2 == 0 else BLAUW)
	_weegschaal(v, 3, 13, 2, true)
	return v

## World name -> builder, for `ArtDecor.tabel()` (the four `NAMEN`).
static func tabel() -> Dictionary:
	return {"vakkenkast": vakkenkast, "postkar": postkar,
		"pakketweegschaal": pakketweegschaal, "zegelbalie": zegelbalie}

## The game's names -> builder, for `definitie().modellen` and
## `Art.registreer_model` (`games/post/spel.gd`).
static func spel_tabel() -> Dictionary:
	return {"post_kast": vakkenkast, "post_kar": postkar, "post_balie": zegelbalie}
