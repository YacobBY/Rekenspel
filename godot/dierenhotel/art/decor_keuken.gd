class_name ArtDecorKeuken
extends RefCounted
## Decor models for the kitchen.  Same primitives, same palette and the same
## bake path as `ArtDecor`, which merges this table into its own (see
## `ArtDecor.tabel()` and `ArtDecor.alle_namen()`).  Every model is anchored at
## (0, 0, 0) on the floor, y upward, and is registered as a protected world model.
##
## Owner, 2026-09-17: "de keuken heeft een bed en kast en plant ipv kookgerei".
## What makes a kitchen read as a kitchen at first glance is the run along the
## back wall — counter with a sink, stove with pans, fridge — plus the things on
## the wall above it.  The trolley (`keukenkar`) is the kitchen's own copy of
## `ArtDecor.kar`: the base model is frozen by the golden-image oracle
## (`tests/test_art.gd` compares it pixel for pixel with the HTML original), so
## the kitchen gets a trolley that reads as a trolley without touching it.

## The models keep to the pastel palette of `ArtDecor`; these four soft tints
## are the only additions (a burner ring, copper pans, carrots, cart wheels).
const PIT := Color("#9AA1B4")        ## burner ring
const KOPER := Color("#E0A87E")      ## copper pan
const WORTEL := Color("#F2A35E")     ## carrots
const WIEL := Color("#6E5A4A")       ## cart wheel (the colour `ArtDecor.kar` uses)
## The sweet jar of the trolley, in the two blues the base model already has.
const SNOEP := Color("#DFF1FB")
const SNOEP_D := Color("#C5E4F7")

## Every model name this file provides, in a fixed order.
const NAMEN: Array[String] = ["fornuis", "aanrecht", "koelkast", "pannenrek",
	"pottenplank", "keukentafel", "keukenkar"]

# ----------------------------------------------------------------- het aanrecht

## Kitchen counter, 24 x 10 on the floor and 12 tall to the worktop (17 with the
## tap): two cabinet doors with a gold handle on the front (+z), a sink basin
## sunk one voxel into the top, the tap at the back edge, a cutting board and a
## mug.  The basin is a real hole: the top layer is laid in four strips around
## it and the layer below it is painted `WATER`.
static func aanrecht(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -12, 0, -5, 24, 10, 10, ArtDecor.HOUT_L)
	ArtVorm.verf(v, -12, 11, 0, 0, -5, 4, ArtDecor.HOUT_D)
	ArtVorm.verf(v, -11, -1, 1, 8, 4, 4, ArtDecor.HOUT)
	ArtVorm.verf(v, 1, 11, 1, 8, 4, 4, ArtDecor.HOUT)
	ArtVorm.bx(v, -2, 6, 5, 1, 2, 1, ArtDecor.GOUD)
	ArtVorm.bx(v, 2, 6, 5, 1, 2, 1, ArtDecor.GOUD)
	# the worktop: one closed layer, then a second one with the basin left open
	ArtVorm.bx(v, -13, 10, -6, 26, 1, 12, ArtDecor.KUSSEN)
	ArtVorm.bx(v, -13, 11, -6, 15, 1, 12, ArtDecor.KUSSEN)
	ArtVorm.bx(v, 10, 11, -6, 3, 1, 12, ArtDecor.KUSSEN)
	ArtVorm.bx(v, 2, 11, -6, 8, 1, 3, ArtDecor.KUSSEN)
	ArtVorm.bx(v, 2, 11, 3, 8, 1, 3, ArtDecor.KUSSEN)
	ArtVorm.verf(v, 2, 9, 10, 10, -3, 2, ArtDecor.WATER)
	ArtVorm.verf(v, 1, 10, 11, 11, -4, -4, ArtDecor.METAAL)
	ArtVorm.verf(v, 1, 10, 11, 11, 3, 3, ArtDecor.METAAL)
	ArtVorm.verf(v, 1, 1, 11, 11, -4, 3, ArtDecor.METAAL)
	ArtVorm.verf(v, 10, 10, 11, 11, -4, 3, ArtDecor.METAAL)
	# the tap
	ArtVorm.bx(v, 5, 12, -5, 2, 5, 2, ArtDecor.METAAL)
	ArtVorm.bx(v, 5, 16, -4, 2, 1, 4, ArtDecor.METAAL)
	# a cutting board and a mug beside the sink
	ArtVorm.bx(v, -11, 12, -3, 8, 1, 6, ArtDecor.HOUT)
	ArtVorm.verf(v, -11, -4, 12, 12, 2, 2, ArtDecor.HOUT_D)
	ArtVorm.ell(v, -2, 13, 1, 1.8, 1.8, 1.8, ArtDecor.STOF, {"e": 3.2, "ymin": 12})
	return v

# ------------------------------------------------------------------- het fornuis

## Stove, 14 x 10 on the floor and 12 tall to the hob (18 with the pan): four
## burner rings on the plate, a copper pan with a lid on the back-right one, and
## an oven door with a window and a handle on the front (+z).
static func fornuis(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -7, 0, -5, 14, 11, 10, ArtDecor.KUSSEN)
	ArtVorm.verf(v, -7, 6, 0, 0, -5, 4, ArtDecor.METAAL)
	ArtVorm.verf(v, -6, 5, 1, 8, 4, 4, ArtDecor.METAAL_L)
	ArtVorm.verf(v, -4, 3, 3, 6, 4, 4, ArtDecor.DEKEN_D)
	ArtVorm.bx(v, -5, 9, 5, 11, 1, 1, ArtDecor.METAAL)
	# the hob with its four rings
	ArtVorm.bx(v, -8, 11, -6, 16, 1, 12, ArtDecor.METAAL_L)
	for i in 2:
		for j in 2:
			var px := -5 + i * 7
			var pz := -4 + j * 6
			ArtVorm.verf(v, px, px + 3, 11, 11, pz, pz + 3, PIT)
			ArtVorm.verf(v, px + 1, px + 2, 11, 11, pz + 1, pz + 2, ArtDecor.METAAL)
	# a pan with a lid on the back-right ring
	ArtVorm.ell(v, 3, 13.5, -2, 3.2, 2.4, 3.2, KOPER, {"e": 3.0, "ymin": 12})
	ArtVorm.bx(v, 6, 14, -3, 3, 1, 2, ArtDecor.HOUT_D)
	ArtVorm.bx(v, 0, 16, -5, 7, 1, 7, ArtDecor.METAAL_L)
	ArtVorm.bx(v, 2, 17, -3, 2, 1, 2, ArtDecor.HOUT_D)
	return v

# ------------------------------------------------------------------ de koelkast

## Fridge, 12 x 10 on the floor and 26 tall: a light metal body, a darker line
## where the freezer door meets the fridge door, two handles and a note under a
## pink magnet.
static func koelkast(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -6, 0, -5, 12, 26, 10, ArtDecor.METAAL_L)
	ArtVorm.verf(v, -6, 5, 0, 0, -5, 4, ArtDecor.METAAL)
	ArtVorm.verf(v, -6, 5, 16, 16, -5, 4, ArtDecor.METAAL)
	ArtVorm.verf(v, -6, 5, 25, 25, -5, 4, ArtDecor.METAAL)
	ArtVorm.bx(v, 3, 9, 5, 1, 5, 1, ArtDecor.METAAL)
	ArtVorm.bx(v, 3, 18, 5, 1, 5, 1, ArtDecor.METAAL)
	ArtVorm.bx(v, -4, 19, 5, 5, 4, 1, ArtDecor.PAPIER)
	ArtVorm.bx(v, -3, 23, 5, 2, 2, 1, ArtDecor.STOF)
	return v

# -------------------------------------------------------- aan de wand (z = 0)

## Wall rack for the back wall: a rail on two brackets with a wide copper frying
## pan and a blue pot hanging from it on visible hooks.  Two big ones instead of
## three small ones, in two colours: at five voxels across a pan is a grey cube,
## and three metal ones beside each other run together into one blob.
## 19 x 2 against the wall, 12 tall; hang it with `{"ver": true, "y": 20}`.
static func pannenrek(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -9, 11, 0, 19, 1, 2, ArtDecor.METAAL)
	ArtVorm.bx(v, -9, 8, 0, 2, 4, 2, ArtDecor.METAAL)
	ArtVorm.bx(v, 8, 8, 0, 2, 4, 2, ArtDecor.METAAL)
	# a wide copper frying pan, hanging by its wooden handle
	ArtVorm.ell(v, -5, 4, 1, 3.6, 2.0, 1.2, KOPER, {"e": 2.4})
	ArtVorm.verf(v, -9, -1, 2, 2, 0, 2, ArtDecor.POT)
	ArtVorm.bx(v, -5, 6, 0, 1, 5, 2, ArtDecor.HOUT_D)
	# a blue pot with two ears
	ArtVorm.ell(v, 5, 4, 1, 3.0, 2.4, 1.2, ArtDecor.DEKEN, {"e": 2.6})
	ArtVorm.verf(v, 2, 8, 2, 2, 0, 2, ArtDecor.DEKEN_D)
	ArtVorm.bx(v, 1, 5, 1, 1, 1, 1, ArtDecor.METAAL)
	ArtVorm.bx(v, 9, 5, 1, 1, 1, 1, ArtDecor.METAAL)
	ArtVorm.bx(v, 5, 7, 0, 1, 4, 2, ArtDecor.METAAL)
	return v

## Wall shelf for the back wall with three jars on it: kibble, carrots and
## seeds.  The jars wear their contents on the outside — a white jar against a
## cream wall is invisible from across the room.  19 x 5 against the wall,
## 9 tall; hang it with `{"ver": true, "y": 18}` — lower than a shelf would
## really hang, so the voerkar's sum card (it opens beside the voerkast) does
## not land on top of the jars.
static func pottenplank(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -9, 1, 0, 19, 2, 5, ArtDecor.HOUT)
	ArtVorm.verf(v, -9, 9, 1, 1, 0, 4, ArtDecor.HOUT_D)
	ArtVorm.bx(v, -7, 0, 0, 2, 1, 3, ArtDecor.HOUT_D)
	ArtVorm.bx(v, 6, 0, 0, 2, 1, 3, ArtDecor.HOUT_D)
	var vulling := [ArtDecor.HOUT_D, WORTEL, ArtDecor.GOUD]
	var deksel := [ArtDecor.BLAD, ArtDecor.POT, ArtDecor.GOUD_D]
	for i in 3:
		var jx := -6 + i * 6
		ArtVorm.ell(v, jx, 5.5, 2, 2.4, 3.0, 1.8, ArtDecor.KUSSEN, {"e": 3.4, "ymin": 3})
		ArtVorm.verf(v, jx - 3, jx + 3, 3, 6, 0, 4, vulling[i])
		ArtVorm.bx(v, jx - 2, 8, 1, 5, 1, 3, deksel[i])
	return v

# ------------------------------------------------------------------- de tafel

## A little kitchen table, 17 x 17 on the floor and 12 tall, with a plate of
## biscuits on it.
static func keukentafel(_p := {}) -> Array:
	var v: Array = []
	ArtVorm.bx(v, -8, 8, -8, 17, 2, 17, ArtDecor.HOUT_L)
	ArtVorm.verf(v, -8, 8, 8, 8, -8, 8, ArtDecor.HOUT_D)
	for sx in [-6, 5]:
		for sz in [-6, 5]:
			ArtVorm.bx(v, sx, 0, sz, 2, 8, 2, ArtDecor.HOUT)
	# a round plate, one voxel thick, with three biscuits on it
	for px in range(-4, 5):
		for pz in range(-4, 5):
			if px * px + pz * pz <= 17:
				ArtVorm.bx(v, px, 10, pz, 1, 1, 1, ArtDecor.PAPIER)
	ArtVorm.verf(v, -4, 4, 10, 10, -4, 4, ArtDecor.KUSSEN)
	ArtVorm.verf(v, -2, 2, 10, 10, -2, 2, ArtDecor.PAPIER)
	for k in [[-2, -1], [1, 0], [0, 2]]:
		ArtVorm.bx(v, k[0] - 1, 11, k[1] - 1, 3, 1, 3, ArtDecor.HOUT_D)
		ArtVorm.verf(v, k[0], k[0], 11, 11, k[1], k[1], ArtDecor.HOUT)
	return v

# -------------------------------------------------------------------- de kar

## The feeding trolley of the kitchen: the same 27 x 19 deck, the same sweet jar
## and the same height as `ArtDecor.kar` (the entry button of the voerkar game
## hangs on it at y = 16), but it reads as a trolley instead of a bed — four
## round dark wheels under an open frame, a thin push bar on two uprights
## instead of a headboard, and the food showing in the three bins: kibble,
## carrots and seeds.
static func keukenkar(_p := {}) -> Array:
	var v: Array = []
	# four round wheels, flush with the edge of the deck so they stay in sight
	for wx in [-9, 9]:
		for wz in [-8, 8]:
			ArtVorm.ell(v, wx, 3.5, wz, 3.5, 3.5, 1.4, WIEL, {"e": 2.0})
			ArtVorm.verf(v, wx - 1, wx + 1, 3, 4, wz - 2, wz + 2, ArtDecor.METAAL_L)
	ArtVorm.bx(v, -11, 3, -7, 22, 1, 15, ArtDecor.HOUT_D)   # the lower shelf
	ArtVorm.bx(v, -13, 7, -9, 27, 2, 19, ArtDecor.HOUT)     # the deck
	ArtVorm.verf(v, -13, 13, 8, 8, -9, 9, ArtDecor.HOUT_L)
	# three bins with the food heaped over the rim: kibble, carrots, seeds
	var voer := [ArtDecor.HOUT_D, WORTEL, ArtDecor.GOUD]
	for i in 3:
		ArtVorm.bx(v, -12 + i * 8, 9, -6, 7, 5, 8, ArtDecor.HOUT_D)
		ArtVorm.bx(v, -11 + i * 8, 10, -5, 5, 3, 6, voer[i])
		ArtVorm.ell(v, -9 + i * 8, 13, -2, 2.6, 1.6, 2.6, voer[i], {"e": 2.6, "ymin": 13})
	# the sweet jar in the front corner, sweets showing through the glass
	ArtVorm.ell(v, 6, 12, 5, 4.4, 4.0, 4.4, SNOEP, {"e": 2.6, "ymin": 9})
	ArtVorm.verf(v, 1, 11, 9, 11, 2, 10, ArtDecor.STOF)
	ArtVorm.bx(v, 3, 16, 2, 7, 1, 7, SNOEP_D)
	# the push bar: two uprights and a bar two voxels thick
	ArtVorm.bx(v, -15, 8, -8, 2, 12, 2, ArtDecor.METAAL)
	ArtVorm.bx(v, -15, 8, 6, 2, 12, 2, ArtDecor.METAAL)
	ArtVorm.bx(v, -16, 20, -8, 3, 2, 16, ArtDecor.HOUT_D)
	return v

# --------------------------------------------------------------------- register

## `naam -> Callable(params) -> Array` of voxels {x, y, z, k}.
static func tabel() -> Dictionary:
	return {
		"fornuis": Callable(ArtDecorKeuken, "fornuis"),
		"aanrecht": Callable(ArtDecorKeuken, "aanrecht"),
		"koelkast": Callable(ArtDecorKeuken, "koelkast"),
		"pannenrek": Callable(ArtDecorKeuken, "pannenrek"),
		"pottenplank": Callable(ArtDecorKeuken, "pottenplank"),
		"keukentafel": Callable(ArtDecorKeuken, "keukentafel"),
		"keukenkar": Callable(ArtDecorKeuken, "keukenkar"),
	}
