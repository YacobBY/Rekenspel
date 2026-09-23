class_name WereldBinnenkomst
extends RefCounted
## How a guest comes into the hotel (owner, 2026-09-23: "... die komen momenteel
## vanuit de gang binnen ipv ingang.  Doe ook een leuke animatie wanneer ze
## binnenkomen dat per dier anders is").
##
## The front door of the receptie (`Rooms.ingang`) opens, the guest appears on
## its threshold and makes its way round the end of the desk to its spot at the
## counter — each kind in its own way (art-sound-rules.md §11.8):
##   hond    peeks in, wags, bounds in with three happy hops, trots to the desk
##           and spins round there, bouncing and wagging;
##   poes    peeks round the door, slinks in low and slow, and at the desk
##           stretches — front down, tail up, a yawn — and sits;
##   konijn  twitches its ears and hops all the way in little jumps, then one
##           big twisting hop at the desk;
##   gans    honks and flaps its wings in the doorway, waddles in flapping,
##           waddles on with a big sway, and flaps once more at the desk.
## Three to four seconds each, and every one ends in the plain waiting pose, on
## the spot the hotel asked for.
##
## This file only WRITES the choreography, as a list of beats.  `World` plays
## it on its own 15 Hz tick (`World.kom_binnen`), so an arrival is
## deterministic, a test can step it, any other order supersedes it exactly as
## it supersedes a walk, and nothing waits on a timer.  A beat is a Dictionary:
##   {soort: "stil", n, poses, per, draai, hup, zij}
##       stand for n ticks, showing the next pose of `poses` every `per` ticks;
##       `draai` turns round with every pose, `hup` bounces once per pose (in
##       the bob's pixels, like `blij`), `zij` sways
##   {soort: "loop", naar, v, poses, stap, bob, zij, rem}
##       walk straight to `naar` at `v` voxels a tick, a gait frame of `poses`
##       every `stap` voxels; `rem` slows down into the last few voxels
##   {soort: "hup", naar, n, hoog, land, draai}
##       one jump to `naar` (to where he stands when it is left out): n ticks in
##       the air, `hoog` voxels high, `land` ticks squatting on landing;
##       `draai` looks round at the top of the arc
##   {soort: "geluid", naam, hand}   one sound (`Snd`)
##   {soort: "pluis", n, kl, omhoog} particles at the guest (`ArtEffect.pluis`)
##   {soort: "deur"}                 the front door falls shut behind him, with
##                                   the door's own sound (`Snd.deur`)
## The first three take ticks; the last three happen at once.  `plan` puts the
## door beat in by itself, once the guest is DEUR_AF voxels clear of the
## threshold: until then the open door with the sky in it shows where he came
## from, and a door that shut right behind him would hide behind him.

## How far a little hop goes, and how many ticks it takes.
const HOP := 10.0
const HOP_TIKKEN := 4
## A white feather: the goose's own light colour (`ArtGasten.PAL.gans.l`).
const VEER := Color("#FFFCF4")
## How far from the threshold a guest is before the door falls shut behind him.
const DEUR_AF := 22.0

## The beats of one guest's arrival: from the threshold of the front door
## `ingang` (a `Rooms.ingang` record) to `doel`, round the desk of `r`.  A kind
## without an arrival of its own comes in like the puppy.
static func plan(kind: String, r, ingang: Dictionary, doel: Vector2) -> Array:
	var pad := route(r, ingang, doel)
	var slagen: Array
	match kind:
		"poes":
			slagen = _poes(pad)
		"konijn":
			slagen = _konijn(pad)
		"gans":
			slagen = _gans(pad)
		_:
			slagen = _hond(pad)
	return _met_deur(slagen, pad[0])

## The door beat goes in right after the first beat that ends DEUR_AF voxels or
## more from the threshold — or at the very end, if none does.
static func _met_deur(slagen: Array, drempel: Vector2) -> Array:
	var uit: Array = []
	var hier := drempel
	var dicht := false
	for slag in slagen:
		uit.append(slag)
		if slag.has("naar"):
			hier = slag["naar"]
		if not dicht and hier.distance_to(drempel) >= DEUR_AF:
			uit.append({"soort": "deur"})
			dicht = true
	if not dicht:
		uit.append({"soort": "deur"})
	return uit

## The way in: the threshold, the step inside, then round the end of the desk
## when the straight line to the spot would cut across it (world.md §1.3: no
## walk in the receptie crosses the counter), then the spot.  Every leg is a
## straight line, so a test can hold each one against the desk.
static func route(r, ingang: Dictionary, doel: Vector2) -> Array[Vector2]:
	var uit: Array[Vector2] = []
	var drempel := Vector2(float(ingang.get("dx", doel.x)), float(ingang.get("dz", doel.y)))
	var binnen := Vector2(float(ingang.get("ix", doel.x)), float(ingang.get("iz", doel.y)))
	uit.append(drempel)
	uit.append(binnen)
	if r != null and not (r.balie as Dictionary).is_empty():
		var b: Dictionary = r.balie
		var vak := Rect2(float(b["x0"]) - 3.0, float(b["z0"]) - 3.0,
			float(b["x1"]) - float(b["x0"]) + 6.0, float(b["z1"]) - float(b["z0"]) + 6.0)
		if _raakt(vak, binnen, doel):
			# in front of the end of the desk on the door's side, clear of it
			var voor := float(b["z1"]) + 9.0
			var x := binnen.x - 2.0 if binnen.x > float(b["x1"]) else binnen.x + 2.0
			uit.append(Vector2(x, voor))
	uit.append(doel)
	return uit

## Does the straight line a–b touch the rectangle?  Sampled every half voxel.
static func _raakt(vak: Rect2, a: Vector2, b: Vector2) -> bool:
	var n := maxi(1, int(ceil(a.distance_to(b) * 2.0)))
	for i in n + 1:
		if vak.has_point(a.lerp(b, float(i) / float(n))):
			return true
	return false

## `n` points evenly along the legs of `pad` from `van` (index) to its end,
## the last one exactly on the last point — the landing places of hops.
static func _langs(pad: Array[Vector2], van: int, stap: float) -> Array[Vector2]:
	var uit: Array[Vector2] = []
	for i in range(van, pad.size() - 1):
		var a: Vector2 = pad[i]
		var b: Vector2 = pad[i + 1]
		var n := maxi(1, int(ceil(a.distance_to(b) / stap)))
		for j in range(1, n + 1):
			uit.append(a.lerp(b, float(j) / float(n)))
	return uit

# ----------------------------------------------------------------- de vier

## The puppy: a peek, a wag, three bounds to the corner of the desk, a trot to
## the counter and a happy spin there, turning round four times and bouncing.
static func _hond(pad: Array[Vector2]) -> Array:
	var hoek: Vector2 = pad[pad.size() - 2]
	var uit: Array = [
		{"soort": "stil", "n": 5, "poses": ["kijk"], "per": 5},
		{"soort": "stil", "n": 4, "poses": ["blijA", "blijB"], "per": 2, "hup": 4.0},
		{"soort": "geluid", "naam": "hup"},
	]
	var drempel: Vector2 = pad[0]
	for i in 3:
		uit.append({"soort": "hup", "naar": drempel.lerp(hoek, float(i + 1) / 3.0),
			"n": 5, "hoog": 6.0, "land": 1})
		if i == 1:
			uit.append({"soort": "geluid", "naam": "hup"})
	uit.append({"soort": "loop", "naar": pad[pad.size() - 1], "v": 3.0,
		"poses": ["loopA", "loopB"], "stap": 3.5, "bob": 2.4, "rem": true})
	uit.append({"soort": "pluis", "n": 2, "kl": ArtEffect.STER_KL[0], "omhoog": true})
	uit.append({"soort": "stil", "n": 13, "poses": ["blijA", "blijB"], "per": 3,
		"draai": true, "hup": 6.0})
	uit.append({"soort": "pluis", "n": 2, "kl": ArtEffect.STER_KL[1], "omhoog": true})
	return uit

## The cat: peeks round the door, slinks in low — careful first steps, then
## on round the desk — walks the last stretch tail up, and at the counter
## stretches with a little "mrrp" and sits down neatly.
static func _poes(pad: Array[Vector2]) -> Array:
	var uit: Array = [
		{"soort": "stil", "n": 5, "poses": ["kijk", "tril"], "per": 3},
		{"soort": "loop", "naar": pad[1], "v": 1.2, "poses": ["sluipA", "sluipB"],
			"stap": 2.5, "bob": 0.4},
	]
	for i in range(2, pad.size() - 1):
		uit.append({"soort": "loop", "naar": pad[i], "v": 2.5,
			"poses": ["sluipA", "sluipB"], "stap": 3.0, "bob": 0.5})
	uit.append({"soort": "loop", "naar": pad[pad.size() - 1], "v": 2.8,
		"poses": ["loopA", "loopB"], "stap": 3.5, "bob": 1.2, "rem": true})
	uit.append({"soort": "geluid", "naam": "terug"})
	uit.append({"soort": "stil", "n": 11, "poses": ["strek"], "per": 11})
	uit.append({"soort": "stil", "n": 5, "poses": ["zit"], "per": 5})
	uit.append({"soort": "pluis", "n": 2, "kl": ArtEffect.STER_KL[1], "omhoog": true})
	return uit

## The rabbit: an ear twitch, then little hops all the way — a "hup" on every
## other one — and one big hop at the counter with a look round at its top.
static func _konijn(pad: Array[Vector2]) -> Array:
	var uit: Array = [
		{"soort": "stil", "n": 4, "poses": ["tril", "kijk"], "per": 2},
	]
	var hops := _langs(pad, 0, HOP)
	for i in hops.size():
		if i % 2 == 0:
			uit.append({"soort": "geluid", "naam": "hup"})
		uit.append({"soort": "hup", "naar": hops[i], "n": HOP_TIKKEN, "hoog": 4.0, "land": 1})
	uit.append({"soort": "geluid", "naam": "hup"})
	uit.append({"soort": "hup", "n": 7, "hoog": 10.0, "land": 2, "draai": true})
	uit.append({"soort": "pluis", "n": 2, "kl": ArtEffect.STER_KL[0], "omhoog": true})
	return uit

## The goose: a double "gak" and four flaps in the doorway with a puff of
## feathers, the first steps in flapping, a big waddle round the desk, and a
## last flap at the counter.
static func _gans(pad: Array[Vector2]) -> Array:
	var uit: Array = [
		{"soort": "stil", "n": 3, "poses": ["kijk"], "per": 3},
		{"soort": "geluid", "naam": "plop", "hand": 3},
		{"soort": "stil", "n": 2, "poses": ["fladder"], "per": 2},
		{"soort": "geluid", "naam": "plop", "hand": 1},
		{"soort": "stil", "n": 6, "poses": ["blijB", "fladder"], "per": 2, "zij": 1.0},
		{"soort": "pluis", "n": 3, "kl": VEER, "omhoog": true},
		{"soort": "loop", "naar": pad[1], "v": 1.4, "poses": ["fladderA", "fladderB"],
			"stap": 1.6, "bob": 1.0, "zij": 3.0},
	]
	for i in range(2, pad.size() - 1):
		uit.append({"soort": "loop", "naar": pad[i], "v": 2.2,
			"poses": ["fladderA", "fladderB"], "stap": 2.2, "bob": 1.2, "zij": 3.0})
	uit.append({"soort": "loop", "naar": pad[pad.size() - 1], "v": 2.5,
		"poses": ["loopA", "loopB"], "stap": 3.0, "bob": 1.4, "zij": 3.0, "rem": true})
	uit.append({"soort": "geluid", "naam": "plop", "hand": 3})
	uit.append({"soort": "stil", "n": 6, "poses": ["fladder", "blijB"], "per": 2})
	uit.append({"soort": "pluis", "n": 3, "kl": VEER, "omhoog": true})
	uit.append({"soort": "stil", "n": 2, "poses": ["rust"], "per": 2})
	return uit
