class_name FotoScherm
extends Control
## What the camera of the photo booth sees, large and straight on, while `foto`
## runs — the way the wekker brings its clock forward and Spiegelmaskers its
## mask.  Owner, 2026-10-06: "de dieren staan allemaal naast elkaar op de foto;
## kan het echt in het hokje geanimeerd worden van een camera hokje PoV met
## alle dieren die erin zitten".
##
## Inside the coral frame the picture is the cabin seen through the camera: the
## back wall in the light of the lamp, the bench, the teal curtain on the left,
## and the animals crowded in it — at the back a little smaller, in front a
## little larger, every nose toward the middle.  Whoever is chosen steps out
## from behind the curtain and takes the place nearest to it; the ones already
## in shuffle up ("schuif op!").  While they wait they breathe, blink and wag;
## at the "1" of the countdown they cheer; the click freezes them, the flash,
## and the screen is a polaroid that develops from white.  Under the picture,
## under every place, the price per animal (owner, 2026-10-01: "de prijs per
## dier daaronder"); while fewer than two are in, dashed "?" places say how
## many at least.  No words in the picture: digits only.
##
## Not a button: a tap goes through it.  `Hits` puts it down and clears it like
## every element of the game (`kind: "eigen"`); its size it asks the game at
## every placement (`meet`), so it never comes under the maths bar.  Given
## less height than `maat_bij` asks (a phone on its side), the picture first
## gets wider for its height — a wider view of the same cabin, down to
## `BEELD_MIN` — so the price tags keep their size; only below that does
## everything shrink, in the middle of the screen.
##
## One clock moves everything: `tik(dt)`, which `_process` turns.  In reduced
## motion, and headless in the tree (the suite), every change is final the
## moment it is made.  A screen outside the tree is never drawn, so it waits
## for whoever holds it to turn the clock: that is how a test sees every frame
## of a walk in.

const KL_RAND := Color("#EF9483")       ## the booth's own coral
const KL_RAND_D := Color("#D97B6C")
const KL_LEEG := Color("#A8978A")
const KL_PRIJS := Color("#F2C14E")      ## a price tag, as on the stalls
const KL_PRIJS_D := Color("#D9A53A")
const KL_INKT := Color("#4A3B33")
const KL_FOTO := Color("#FFFFFF")
const KL_SCHADUW := Color(0.29, 0.231, 0.2, 0.16)
## Inside the cabin (`ArtDecorWinkels.fotohokje`).  The cabin is dark inside;
## the picture is lit, so every colour is lightened toward cream until a pastel
## animal reads against it.
const KL_CREME := Color("#FFF6EE")
const KL_PERZIK := Color("#FFE6D8")     ## the lamp's warm light on the walls
const KL_ZOEKER := Color(1.0, 1.0, 1.0, 0.95)     ## the viewfinder's corners

## The parts of the screen, as fractions of its width.
const RAND := 0.04         ## the coral edge round the picture (the polaroid's white edge)
const BEELD := 0.6         ## the picture is this tall for its width: landscape ...
const BEELD_MIN := 0.45    ## ... and at least this tall on a screen lower than `maat_bij` asks
const LABEL := 0.1         ## a price tag is this tall
const LABEL_GAT := 0.022   ## between the picture and the price tags
## Inside the picture: across as a fraction of its width, down of its height.
const GORDIJN := 0.12      ## the curtain hangs along the left edge, this wide
const MUUR := 0.4          ## the back wall, down to the bench
const ZIT := 0.6           ## the seat of the bench
const VLOER := 0.7         ## the floor in front of it
const VOOR_Y := 0.94       ## the paws of the front row ...
const ACHTER_Y := 0.66     ## ... and of the back row, on the bench
const ACHTER := 0.82       ## the back row is this much smaller
const DIER_H := 0.62       ## a guest of the front row is this tall
## Three or four in the cabin: the camera takes a step back.
const GROOT := {3: 0.92, 4: 0.84}
const MIDDEN := 0.5        ## right of the middle place the nose points left
## The places per number of animals, left to right: (across, 0 front / 1 back),
## across as a fraction of the cabin right of the curtain.  The newest stands
## on the left, nearest the curtain.  There are always at least two places
## (`vakken`): a single animal takes the left one, a dashed "?" the right one.
const PLEKKEN := {
	2: [Vector2(0.30, 0.0), Vector2(0.70, 0.0)],
	3: [Vector2(0.25, 0.0), Vector2(0.50, 1.0), Vector2(0.75, 0.0)],
	4: [Vector2(0.17, 0.0), Vector2(0.39, 1.0), Vector2(0.61, 1.0), Vector2(0.83, 0.0)],
}
## A guest plate at voxel scale 1 is about this tall (the dog at rest).
const PLAAT_H := 64.0

const KOM_S := 0.5         ## the walk in, from behind the curtain
const SCHUIF_S := 0.35     ## the others shuffling up to their new places
const WEG_S := 0.6         ## everyone out through the curtain
const ONTWIKKEL_S := 1.0   ## the polaroid develops
const FLITS_S := 0.6       ## the flash fades
const POP_S := 0.18        ## a digit of the countdown pops in
const TEL_R := 0.15        ## its badge: this radius (of the picture height) ...
const TEL_IN := 0.02       ## ... this far in from the top-right corner
const KOM_NA := 0.3        ## several chosen at once: one after the other
const KOM_HOP := 10.0      ## px (at a picture 150 high): the hop of the walk in
const SCHUIF_HOP := 4.0    ## ... and of a shuffle
const KLAAR := -1.0e9      ## a start time long past: nothing is moving
const BUITEN := -9.0       ## "behind the curtain": worked out when it is drawn

## One animal on the screen.
class Gast extends RefCounted:
	var sleutel := ""          ## the guest id (and a "+" for every earlier time it is on the list)
	var waarde: Variant = null ## what `dieren` holds for it
	var kind := "hond"
	var acc: Variant = []
	var nr := 0                ## its own number: the phase of its breath, blink and wag
	var van := Vector3.ZERO    ## where its move started: (across, down, size)
	var start := -1.0e9        ## when its move started (it may wait behind the curtain)
	var duur := 0.0
	var hop := 0.0
	var komt := false          ## the move is its walk in
	var binnen_t := -1.0e9     ## from this moment it stands in the booth
	var weg := -1.0e9          ## when its walk out started
	var platen := {}           ## pose -> Art plate

## The guests on it, in the order they came in: guest ids.  A new id walks in
## through the curtain; an id that is gone is gone at once.
var dieren: Array = []:
	set(w):
		dieren = (w as Array).duplicate() if w is Array else []
		_volg_lijst()
## How many places: at least two (the fewest that may go on the photo).
var vakken: int:
	get:
		return maxi(2, dieren.size())
## The price per animal.
var prijs: int = 0:
	set(w):
		prijs = w
		queue_redraw()
## The photo is taken: the screen is a polaroid.
var foto: bool = false:
	set(w):
		if w and not foto:
			ontwikkel = 1.0
		foto = w
		queue_redraw()
## 1 … 0, the flash over the photo.
var flits: float = 0.0:
	set(w):
		flits = w
		queue_redraw()
## The digit of the countdown; 0 is none.
var tel_getal: int = 0
## 0 … 1, the polaroid developing from white.
var ontwikkel: float = 0.0
## What the size is: `func() -> Vector2`, from the game.
var meet: Callable = Callable()

var _rij: Array = []       ## Gast, in the order of `dieren`
var _t := 0.0              ## the clock
var _volgnr := 0           ## guests come in so far
var _juich := false        ## cheering since the "1"
var _klik := KLAAR         ## when the photo was taken
var _tel_t := KLAAR        ## when the digit came
var _vertrek := KLAAR      ## when everyone set off out
var _g := 0                ## the voxel scale of the plates
var _g_h := -1.0           ## the picture height `_g` was chosen for
var _vlakken := {}         ## StyleBoxFlat per colour and corner
var _tekent := false
static var _font: Font = null
static var _headless := -1

func _init() -> void:
	name = "FotoScherm"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	# pixel art stays crisp when it is blown up; the voxel plates are smooth
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if Art.pixel() \
		else CanvasItem.TEXTURE_FILTER_LINEAR

func _enter_tree() -> void:
	if _direct():
		_rond_af()

func _process(dt: float) -> void:
	if _direct():
		if _bezig():
			_rond_af()
		return
	tik(dt)

## How large `Hits` must put it down (`hits.gd:_maat_van`).  `Hits` pins the
## size it placed into `custom_minimum_size` and takes the larger of that and
## this; but this screen also gets SMALLER (the maths bar docks), so it lets go
## of the old pin first.
func inhoud_maat() -> Vector2:
	var m: Vector2 = meet.call() if meet.is_valid() else custom_minimum_size
	if meet.is_valid():
		custom_minimum_size = Vector2.ZERO
	return Vector2(maxf(48.0, m.x), maxf(48.0, m.y))

## The size that goes with a screen `breed` wide: the picture, the row of price
## tags under it and the edge round both.  The same for any number of animals.
static func maat_bij(breed: float, _n: int = 2) -> Vector2:
	return Vector2(breed, breed * (2.0 * RAND + BEELD * (1.0 - 2.0 * RAND) + LABEL_GAT + LABEL))

## How wide the share of one animal is on a screen `breed` wide with `n` of them.
static func vak_breed(breed: float, n: int) -> float:
	return breed * (1.0 - 2.0 * RAND) / float(maxi(1, n))

# ------------------------------------------------------------ what it shows

## The price per animal.
func zet(p: int) -> void:
	prijs = p
	queue_redraw()

## The big digit of the countdown (3, 2, 1); at 1 everybody cheers.  0: none —
## a countdown called off, so the cheering stops as well.  (On the photo
## nobody cheers: the click froze them with a smile, `_stand`.)
func tel(n: int) -> void:
	tel_getal = maxi(0, n)
	_juich = n == 1
	_tel_t = KLAAR if _direct() else _t
	queue_redraw()

## The shutter: everybody where they stand, happy, and the photo is taken —
## a flash, then the polaroid develops (both at once in reduced motion).  The
## price tags go: it is a photo now.
func klik() -> void:
	_sync()
	# whoever was walking in stands on his place, whoever was walking out is
	# back on it: the photo has them all, and keeps them
	_vertrek = KLAAR
	for g in _rij:
		(g as Gast).start = KLAAR
		(g as Gast).binnen_t = KLAAR
		(g as Gast).weg = KLAAR
	tel_getal = 0
	_juich = false
	foto = true
	if _direct():
		_klik = KLAAR
		ontwikkel = 1.0
		flits = 0.0
	else:
		_klik = _t
		ontwikkel = 0.0
		flits = 1.0
	queue_redraw()

## Everybody walks out through the curtain; then the booth is empty and live
## again.  At once in reduced motion.
func vertrek() -> void:
	_sync()
	tel_getal = 0
	_juich = false
	if _rij.is_empty() or _direct():
		_einde_vertrek()
		return
	if _vertrek > KLAAR:
		return
	var b := beeld_rect()
	for i in _rij.size():
		var g: Gast = _rij[i]
		g.van = _stand(g, i, b)["p"]
		g.weg = _t
	_vertrek = _t
	queue_redraw()

## Moves the clock on by `dt` seconds, and with it every walk, the countdown's
## pop, the flash and the developing.  `_process` turns it; a test may too.
func tik(dt: float) -> void:
	_sync()
	_t += maxf(0.0, dt)
	if _vertrek > KLAAR and _t >= _vertrek + WEG_S:
		_einde_vertrek()
	if _klik > KLAAR:
		var u := _t - _klik
		ontwikkel = clampf(u / ONTWIKKEL_S, 0.0, 1.0)
		flits = 1.0 - _zacht(clampf(u / FLITS_S, 0.0, 1.0))
		if u >= maxf(ONTWIKKEL_S, FLITS_S):
			_klik = KLAAR
			ontwikkel = 1.0
			flits = 0.0
	# a finished photo and an empty booth stand still: no redraw for them
	if beweegt():
		queue_redraw()

## Does the clock change what I show?  While a guest walks in or out, while
## the animals stand in the live booth (they breathe, blink, wag and cheer),
## while a digit of the countdown is up, and while the flash fades and the
## polaroid develops.  Never in reduced motion, nor headless in the tree:
## there every change is final the moment it is made.
func beweegt() -> bool:
	if _direct():
		return false
	if _klik > KLAAR or _vertrek > KLAAR or tel_getal > 0:
		return true
	return not foto and not _rij.is_empty()

## The guests whose walk in is over, in the order of `dieren` (all of them once
## everybody stands still; nobody who is walking out).
func binnen() -> Array:
	_sync()
	var uit: Array = []
	for g in _rij:
		var gast: Gast = g
		if gast.weg <= KLAAR and _t >= gast.binnen_t:
			uit.append(gast.waarde)
	return uit

## Where place `i` is on the screen NOW, counted left to right, in my own
## coordinates: the animal standing there (as it walks, hops and breathes) or,
## while the booth is not full, the dashed "?" place.
func vak_rect(i: int) -> Rect2:
	_sync()
	var n := _rij.size()
	if i < 0 or i >= vakken:
		return Rect2()
	if i >= n:
		return _leeg_rect(i)
	var b := beeld_rect()
	var idx := n - 1 - i
	var g: Gast = _rij[idx]
	var st := _stand(g, idx, b)
	var p = _plaat(g, "rust")
	var anker := _anker_px(g, st, b)
	var s := _schaal(b) * (st["p"] as Vector3).z
	if p == null:
		var w := b.size.x * 0.3 * (st["p"] as Vector3).z
		return Rect2(anker.x - w * 0.5, anker.y - w, w, w)
	return _plaat_rect(p, anker, s, bool(st["flip"]))

## How the animal on place `i` (left to right) is drawn right now: its `pose`,
## whether its nose points `links` (the plate mirrored), whether its place is
## `achter` on the bench, and whether there is a `plaat` for it — fetched the
## way `_draw` fetches it, so what gets baked can be counted.  Empty for a
## place without an animal.
func stand_van(i: int) -> Dictionary:
	_sync()
	var n := _rij.size()
	if i < 0 or i >= n:
		return {}
	var idx := n - 1 - i
	var g: Gast = _rij[idx]
	var st := _stand(g, idx, beeld_rect())
	return {"pose": str(st["pose"]), "links": bool(st["flip"]),
		"achter": _plek_van(idx).y < (ACHTER_Y + VOOR_Y) * 0.5,
		"plaat": _plaat(g, str(st["pose"])) != null}

## The places (left to right) in the order they are drawn: the back row
## first, so a guest in front stands before one on the bench.
func teken_volgorde() -> Array:
	_sync()
	var n := _rij.size()
	var uit: Array = []
	for e in _teken_lijst(beeld_rect()):
		uit.append(n - 1 - int(e[1]))
	return uit

## The price tag under place `i`, left to right: centred under its place, and
## never on its neighbour's.  None (an empty Rect2) on the photo and while
## everybody walks out: then no tag is drawn.
func prijs_rect(i: int) -> Rect2:
	var c := vakken
	if i < 0 or i >= c or foto or _vertrek > KLAAR:
		return Rect2()
	var b := beeld_rect()
	var br := _breed()
	var h := br * LABEL
	var gat := br * 0.03
	var stap := b.size.x
	for k in range(1, c):
		stap = minf(stap, (_plek(k, c).x - _plek(k - 1, c).x) * b.size.x)
	var w := maxf(4.0, minf(minf(b.size.x / float(c), stap) - gat, h * 2.4))
	var cx := clampf(b.position.x + _plek(i, c).x * b.size.x,
		b.position.x + w * 0.5, b.end.x - w * 0.5)
	return Rect2(cx - w * 0.5, b.end.y + br * LABEL_GAT, w, h)

## The countdown's badge at rest, in my own coordinates: in the top-right
## corner of the picture, clear of every head (it pops in from 1.3 × this).
func badge_rect() -> Rect2:
	var b := beeld_rect()
	var r := b.size.y * TEL_R
	var c := Vector2(b.end.x - b.size.y * TEL_IN - r, b.position.y + b.size.y * TEL_IN + r)
	return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)

## The picture, in my own coordinates: the same rectangle live and on the
## polaroid.  When I am lower than `maat_bij` asks, it gets wider for its
## height first (down to `BEELD_MIN`), and only then smaller (`_indeling`).
func beeld_rect() -> Rect2:
	var ind := _indeling()
	var br := ind.x
	var rand := br * RAND
	var w := maxf(0.0, br - 2.0 * rand)
	return Rect2((size.x - br) * 0.5 + rand, rand, w, w * ind.y)

## The width everything is measured against.
func _breed() -> float:
	return _indeling().x

## (the width everything is measured against, how tall the picture is for its
## width).  As high as `maat_bij` asks, or higher: my own width and `BEELD`.
## Lower: the edge, the gap and the row of price tags keep the size that goes
## with my width, and the picture takes what is left — a wider view of the
## same cabin — down to `BEELD_MIN`.  Lower still: all of it at `BEELD_MIN`,
## smaller, in the middle.
func _indeling() -> Vector2:
	var nodig := maat_bij(size.x).y
	if size.x <= 0.0 or nodig <= 0.0 or size.y >= nodig:
		return Vector2(size.x, BEELD)
	var vast := 2.0 * RAND + LABEL_GAT + LABEL      # per unit of width: what never bends
	var vorm := (size.y / size.x - vast) / (1.0 - 2.0 * RAND)
	if vorm >= BEELD_MIN:
		return Vector2(size.x, vorm)
	return Vector2(size.y / (vast + BEELD_MIN * (1.0 - 2.0 * RAND)), BEELD_MIN)

# ---------------------------------------------------------- the animals

## The list changed: walk in, shuffle up, vanish.  Never assigns `dieren`.
func _volg_lijst() -> void:
	var b := beeld_rect()
	var oud := {}
	var stond := {}
	for i in _rij.size():
		var g: Gast = _rij[i]
		oud[g.sleutel] = g
		stond[g.sleutel] = _stand(g, i, b)["p"]
	# a new list while they walk out: the walk out is over
	if _vertrek > KLAAR:
		_vertrek = KLAAR
		for g in _rij:
			(g as Gast).weg = KLAAR
	var direct := _direct()
	var sleutels := _sleutels(dieren)
	var nieuw: Array = []
	var komers: Array = []
	for i in dieren.size():
		var g: Gast = oud.get(sleutels[i], null)
		if g == null:
			g = Gast.new()
			g.sleutel = sleutels[i]
			_vul(g, dieren[i])
			g.nr = _volgnr
			_volgnr += 1
			komers.append(g)
		g.waarde = dieren[i]
		nieuw.append(g)
	_rij = nieuw
	for i in _rij.size():
		var g: Gast = _rij[i]
		if komers.has(g):
			continue
		var van: Vector3 = stond[g.sleutel]
		var naar := _plek_van(i)
		if direct:
			g.start = KLAAR
			g.binnen_t = KLAAR
			continue
		var loopt := g.start > KLAAR and _t < g.start + g.duur
		if van.distance_to(naar) < 0.002 and not loopt:
			continue
		if g.komt and _t < g.binnen_t and _t < g.start:
			# still behind the curtain: it will walk straight in to its new
			# place — along that place's row, at that place's size
			g.van = Vector3(BUITEN, naar.y, naar.z)
			continue
		g.van = van
		g.start = _t
		g.duur = SCHUIF_S
		g.hop = SCHUIF_HOP
		g.komt = g.komt and _t < g.binnen_t
		g.binnen_t = maxf(g.binnen_t, _t + SCHUIF_S) if g.komt else g.binnen_t
	# the newcomers step out from behind the curtain, the first chosen first
	# (it walks furthest)
	for k in komers.size():
		var g: Gast = komers[k]
		var naar := _plek_van(_rij.find(g))
		g.van = Vector3(BUITEN, naar.y, naar.z)
		g.komt = true
		g.hop = KOM_HOP
		g.duur = KOM_S
		if direct:
			g.start = KLAAR
			g.binnen_t = KLAAR
		else:
			g.start = _t + float(k) * KOM_NA
			g.binnen_t = g.start + KOM_S
	if not _tekent:
		queue_redraw()

## The list as it is now does not match the animals on screen: somebody
## changed `dieren` in place.  Catch up.
func _sync() -> void:
	var sl := _sleutels(dieren)
	if sl.size() != _rij.size():
		_volg_lijst()
		return
	for i in sl.size():
		if sl[i] != (_rij[i] as Gast).sleutel:
			_volg_lijst()
			return

## A key per entry of `lijst`: the guest id; the same id twice gets a second key.
static func _sleutels(lijst: Array) -> Array:
	var uit: Array = []
	for w in lijst:
		var s := str(w)
		while uit.has(s):
			s += "+"
		uit.append(s)
	return uit

## Kind and clothes, from the guest the id names.
func _vul(g: Gast, w: Variant) -> void:
	var id := str(w)
	var gast: Dictionary = State.gast_van(id)
	g.kind = str(gast.get("kind", "hond"))
	g.acc = World.accessoires(id) if World.dier(id) != null else gast.get("accessoires", [])
	if not ArtGasten.SOORTEN.has(g.kind):
		g.kind = "hond"

func _einde_vertrek() -> void:
	_vertrek = KLAAR
	tel_getal = 0
	_juich = false
	dieren = []
	foto = false
	queue_redraw()

## Everything that is under way, done at once (reduced motion, headless).
func _rond_af() -> void:
	for g in _rij:
		(g as Gast).start = KLAAR
		(g as Gast).binnen_t = KLAAR
	_tel_t = KLAAR
	if _klik > KLAAR:
		_klik = KLAAR
		ontwikkel = 1.0
		flits = 0.0
	if _vertrek > KLAAR:
		_einde_vertrek()
	queue_redraw()

func _bezig() -> bool:
	if _klik > KLAAR or _vertrek > KLAAR:
		return true
	for g in _rij:
		var gast: Gast = g
		if _t < gast.binnen_t or (gast.start > KLAAR and _t < gast.start + gast.duur):
			return true
	return false

## Reduced motion, or headless in the tree: no animation, everything final.
func _direct() -> bool:
	if Ui.rust_modus():
		return true
	if _headless < 0:
		_headless = 1 if DisplayServer.get_name() == "headless" else 0
	return _headless == 1 and is_inside_tree()

## Place `s` of `c` (left to right) as (across, paws down, size): across is
## where the middle of the animal goes, in the cabin right of the curtain.
static func _plek(s: int, c: int) -> Vector3:
	var v := _plek_fx(s, c)
	var groot: float = GROOT.get(c, 1.0 if c < 3 else 0.8)
	if v.y > 0.5:
		return Vector3(_over(v.x), ACHTER_Y, ACHTER * groot)
	return Vector3(_over(v.x), VOOR_Y, groot)

## A fraction of the cabin right of the curtain as a fraction of the picture.
static func _over(fx: float) -> float:
	return GORDIJN + fx * (1.0 - GORDIJN)

## Right of this the nose points left, toward the middle.
static func _kijkt_links(fx: float) -> bool:
	return fx > _over(MIDDEN) + 0.001

static func _plek_fx(s: int, c: int) -> Vector2:
	if PLEKKEN.has(c):
		var lijst: Array = PLEKKEN[c]
		if s >= 0 and s < lijst.size():
			return lijst[s]
	return Vector2((float(s) + 1.0) / (float(c) + 1.0), float(s % 2))

## The place of the guest at `idx` in `_rij`: the newest on the left.
func _plek_van(idx: int) -> Vector3:
	var n := _rij.size()
	return _plek(n - 1 - idx, maxi(2, n))

## How the guest at `idx` stands at this moment: where (across, paws down,
## size), how far up (`dy`, px), which pose and which way it looks.
func _stand(g: Gast, idx: int, b: Rect2) -> Dictionary:
	var doel := _plek_van(idx)
	var px := b.size.y / 150.0
	var leeft := not _direct()
	# the walk out first: it slides everybody out, off the photo as well
	if g.weg > KLAAR:
		var u := clampf((_t - g.weg) / WEG_S, 0.0, 1.0)
		var van := _los(g, g.van)
		var buiten := Vector3(_buiten_fx(g, van.z), van.y, van.z)
		var stap := int((_t - g.weg) / 0.16) % 2 if leeft else 0
		return {"p": van.lerp(buiten, u * u), "dy": 0.0,
			"pose": "sjokA" if stap == 0 else "sjokB", "flip": true}
	if foto:
		return {"p": doel, "dy": 0.0, "pose": "blijA", "flip": _kijkt_links(doel.x)}
	if g.start > KLAAR and _t < g.start + g.duur:
		var u := clampf((_t - g.start) / g.duur, 0.0, 1.0)
		var p := _los(g, g.van).lerp(doel, 1.0 - (1.0 - u) * (1.0 - u))
		var dy := -g.hop * sin(PI * u) * px
		if g.komt:
			return {"p": p, "dy": dy, "pose": "loopA", "flip": false}
		return {"p": p, "dy": dy, "pose": _pose(g, leeft), "flip": _kijkt_links(p.x)}
	var dy := 0.0
	if leeft:
		if _juich:
			dy = -6.0 * absf(sin(TAU * (_t + 0.11 * float(g.nr)) / 0.6)) * px
		else:
			dy = 1.5 * sin(TAU * _t / 2.4 + 1.7 * float(g.nr)) * px
	return {"p": doel, "dy": dy, "pose": _pose(g, leeft), "flip": _kijkt_links(doel.x)}

## Standing: a blink now and then, a wag every six seconds (fast for the dog,
## as in the world, `world.gd:_beeld_van`), and from the "1" on: cheering.
func _pose(g: Gast, leeft: bool) -> String:
	if _juich:
		if not leeft:
			return "blijA"
		return "blijA" if int((_t + 0.07 * float(g.nr)) / 0.15) % 2 == 0 else "blijB"
	if not leeft:
		return "rust"
	var per := 3.2 + 0.7 * float(g.nr % 4)
	if fposmod(_t + 0.37 * float(g.nr) + 1.1, per) < 0.13:
		return "knipper"
	var kw := fposmod(_t + 1.9 * float(g.nr) + 3.0, 6.0)
	if kw < 1.2:
		var snel := 0.13 if g.kind == "hond" else 0.26
		return "kwispelA" if int(kw / snel) % 2 == 0 else "kwispelB"
	return "rust"

## "Behind the curtain" made real.
func _los(g: Gast, v: Vector3) -> Vector3:
	if v.x <= BUITEN + 1.0:
		return Vector3(_buiten_fx(g, v.z), v.y, v.z)
	return v

## Across, where the guest is just out of the picture on the left.
func _buiten_fx(g: Gast, k: float) -> float:
	var b := beeld_rect()
	if b.size.x < 1.0:
		return -0.45
	var p = _plaat(g, "rust")
	if p == null:
		return -0.45
	return -float(p.w) * 0.5 * _schaal(b) * k / b.size.x - 0.01

## The canvas point the guest's anchor (the middle of its paws) goes on: the
## middle of its plate at rest on its place across, the lowest pixel of that
## plate on the line of its row.  Every other pose hangs on the same anchor,
## so a blink or a wag never shifts the animal.
func _anker_px(g: Gast, st: Dictionary, b: Rect2) -> Vector2:
	var p: Vector3 = st["p"]
	var x := b.position.x + p.x * b.size.x
	var y := b.position.y + p.y * b.size.y + float(st["dy"])
	var r = _plaat(g, "rust")
	if r == null:
		return Vector2(x, y)
	var s := _schaal(b) * p.z
	var a := _anker_in(r)
	var naar_mid := (float(r.w) * 0.5 - a.x) * s
	x += naar_mid if bool(st["flip"]) else -naar_mid
	return Vector2(x, y - (float(r.h) - a.y) * s)

## The anchor inside a plate's texture (`wereldobject.gd:ververs`).
func _anker_in(p) -> Vector2:
	var g := float(maxi(1, _g))
	var a := Vector2((Art.DIER_ANKER.x - Art.DIER_ANKER.y) * float(Art.S) * g,
		(Art.DIER_ANKER.x + Art.DIER_ANKER.y) * (float(Art.S) / 2.0) * g)
	return a - Vector2(float(p.dx), float(p.dy))

func _plaat_rect(p, anker: Vector2, s: float, flip: bool) -> Rect2:
	var a := _anker_in(p)
	var links := anker.x - ((float(p.w) - a.x) if flip else a.x) * s
	return Rect2(links, anker.y - a.y * s, float(p.w) * s, float(p.h) * s)

## Canvas px per plate px for the front row.
func _schaal(b: Rect2) -> float:
	_kies_g()
	if _g <= 0:
		return 0.0
	return DIER_H * b.size.y / PLAAT_H / float(_g)

## The voxel scale the plates are baked at: about one plate pixel per screen
## pixel (`World.scherm_dicht`), chosen once per picture height, and never
## finer than the world's own (4): a 600-wide screen blows them up a little.
func _kies_g() -> void:
	var h := beeld_rect().size.y
	if h < 1.0:
		return
	if _g > 0 and absf(h - _g_h) < 0.5:
		return
	_g_h = h
	var e := DIER_H * h / PLAAT_H * World.scherm_dicht()
	var g := clampi(floori(e + 0.25) if Art.pixel() else ceili(e - 0.25), 1, 4)
	if g != _g:
		_g = g
		for r in _rij:
			(r as Gast).platen.clear()

## One plate per guest and pose, fetched once (`Art.dier` keeps them too).
func _plaat(g: Gast, pose: String):
	_kies_g()
	if _g <= 0:
		return null
	if g.platen.has(pose):
		return g.platen[pose]
	var p = Art.dier(g.kind, pose, _g, g.acc)
	g.platen[pose] = p
	return p

## A dashed "?" place, standing on the line of its row.
func _leeg_rect(i: int) -> Rect2:
	var b := beeld_rect()
	var plek := _plek(i, vakken)
	var h := b.size.y * 0.42 * plek.z
	var w := b.size.y / BEELD * 0.22 * plek.z    # the same shape on a wider picture
	var voet := b.position.y + plek.y * b.size.y
	return Rect2(b.position.x + plek.x * b.size.x - w * 0.5, voet - h, w, h)

# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if size.x < 16.0 or size.y < 16.0:
		return
	_tekent = true
	_sync()
	_tekent = false
	var heel := Rect2(Vector2.ZERO, size)
	var br := _breed()
	var rand := br * RAND
	var b := beeld_rect()
	var hoek := b.size.y * 0.06
	draw_style_box(_vlak(KL_SCHADUW, rand * 1.4), heel.grow_individual(0, 0, 0, rand * 0.35))
	if foto:
		# the polaroid: white paper, the picture, and the wide strip under it
		draw_style_box(_vlak(KL_FOTO, rand * 0.5), heel)
	else:
		draw_style_box(_vlak(KL_RAND, rand * 1.4), heel)
		draw_style_box(_vlak(KL_RAND_D, hoek + rand * 0.3), b.grow(rand * 0.3))
	_teken_hokje(b)
	if not foto:
		for i in range(_rij.size(), vakken):
			_teken_leeg(_leeg_rect(i), b)
	_teken_dieren(b)
	_teken_gordijn(b)
	if foto:
		if ontwikkel < 1.0:
			var a := 1.0 - smoothstep(0.0, 1.0, ontwikkel)
			draw_rect(b, Color(1.0, 0.995, 0.98, a))
		_hoeken(b, hoek, KL_FOTO)
		draw_style_box(_rand_lijn(hoek), b)
	else:
		_hoeken(b, hoek, KL_RAND_D)
		_teken_zoeker(b)
		if tel_getal > 0:
			_teken_getal(b)
		# the price per animal, under every place — not while they walk out
		# (`prijs_rect` is empty then)
		if prijs > 0:
			for i in vakken:
				_teken_prijs(prijs_rect(i))
	if flits > 0.0:
		draw_rect(heel, Color(1, 1, 1, clampf(flits, 0.0, 1.0)))

## The cabin: the back wall lit by the lamp, the bench (its back in the colour
## of the cushion, its wooden seat) and the floor.
func _teken_hokje(b: Rect2) -> void:
	var muur := ArtDecorWinkels.HOKJE_BINNEN.lerp(KL_PERZIK, 0.76)
	var bank := ArtDecorWinkels.KUSSEN.lerp(KL_CREME, 0.42)
	var zit := ArtDecor.HOUT.lerp(KL_CREME, 0.3)
	var vloer := ArtDecorWinkels.HOKJE_BINNEN.lerp(KL_PERZIK, 0.6)
	var x := b.position.x
	var y := b.position.y
	var w := b.size.x
	var h := b.size.y
	draw_rect(b, muur)
	# the lamp: a soft round light high on the wall, behind the heads
	var licht := Vector2(x + w * (0.5 + GORDIJN * 0.5), y + h * 0.32)
	draw_texture_rect(_licht(), Rect2(licht - Vector2(w * 0.46, h * 0.5), Vector2(w * 0.92, h)), false)
	# the back of the bench, with a rounded top and buttons in the cushion
	var y0 := y + h * MUUR
	var y1 := y + h * ZIT
	draw_rect(Rect2(x, y0, w, y1 - y0), bank)
	draw_rect(Rect2(x, y0, w, maxf(1.5, h * 0.025)), bank.lerp(KL_CREME, 0.5))
	draw_rect(Rect2(x, y1 - maxf(1.0, h * 0.02), w, maxf(1.0, h * 0.02)), bank.darkened(0.08))
	var knoop := bank.darkened(0.12)
	for k in 7:
		draw_circle(Vector2(x + w * (0.2 + 0.11 * float(k)), y0 + (y1 - y0) * 0.5),
			maxf(1.0, h * 0.012), knoop, true, -1.0, true)
	# the seat, wood
	var y2 := y + h * VLOER
	draw_rect(Rect2(x, y1, w, y2 - y1), zit)
	draw_rect(Rect2(x, y1, w, maxf(1.0, h * 0.018)), zit.lerp(KL_CREME, 0.5))
	draw_rect(Rect2(x, y2 - maxf(1.0, h * 0.02), w, maxf(1.0, h * 0.02)), zit.darkened(0.12))
	# the floor
	draw_rect(Rect2(x, y2, w, b.end.y - y2), vloer)

## The teal curtain along the left edge, in four folds, on its golden rod —
## drawn over the guests: whoever comes in steps out from behind it.
func _teken_gordijn(b: Rect2) -> void:
	var licht := ArtDecorWinkels.HOKJE_GORDIJN.lerp(KL_CREME, 0.12)
	var donker := ArtDecorWinkels.HOKJE_GORDIJN_D.lerp(KL_CREME, 0.08)
	var w := b.size.x * GORDIJN
	var plooi := w / 4.0
	for k in 4:
		var x0 := b.position.x + float(k) * plooi
		draw_rect(Rect2(x0, b.position.y, plooi + 0.5, b.size.y), licht if k % 2 == 0 else donker)
		if k % 2 == 0:
			draw_rect(Rect2(x0 + plooi * 0.3, b.position.y, plooi * 0.22, b.size.y), licht.lerp(KL_CREME, 0.35))
	# its edge on the cabin side, a little shadow on the wall
	draw_rect(Rect2(b.position.x + w, b.position.y, maxf(1.0, w * 0.08), b.size.y), Color(KL_INKT, 0.12))
	draw_rect(Rect2(b.position.x, b.position.y, w * 1.15, maxf(2.0, b.size.y * 0.035)), ArtDecor.GOUD)

func _teken_dieren(b: Rect2) -> void:
	for e in _teken_lijst(b):
		var g: Gast = e[2]
		var st: Dictionary = e[3]
		var p = _plaat(g, str(st["pose"]))
		if p == null:
			continue
		var s := _schaal(b) * (st["p"] as Vector3).z
		var r := _plaat_rect(p, _anker_px(g, st, b), s, bool(st["flip"]))
		_teken_plaat(p.tex, r, Vector2(float(p.w), float(p.h)), bool(st["flip"]), b)

## The guests in the order they are drawn, `[row line, index in _rij, Gast,
## stand]`: the back row first (higher in the picture, further away); within
## a row the newer one further back.
func _teken_lijst(b: Rect2) -> Array:
	var lijst: Array = []
	for i in _rij.size():
		var g: Gast = _rij[i]
		var st := _stand(g, i, b)
		lijst.append([(st["p"] as Vector3).y, i, g, st])
	lijst.sort_custom(func(a: Array, c: Array) -> bool:
		return a[0] < c[0] or (a[0] == c[0] and a[1] > c[1]))
	return lijst

## A plate, mirrored or not, cut off at the edge of the picture.
func _teken_plaat(tex: Texture2D, r: Rect2, maat: Vector2, flip: bool, knip: Rect2) -> void:
	var vis := r.intersection(knip)
	if vis.size.x < 0.5 or vis.size.y < 0.5 or r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var sx := maat.x / r.size.x
	var sy := maat.y / r.size.y
	var v0 := (vis.position.y - r.position.y) * sy
	var v1 := (vis.end.y - r.position.y) * sy
	if flip:
		var u0 := maat.x - (vis.end.x - r.position.x) * sx
		var u1 := maat.x - (vis.position.x - r.position.x) * sx
		draw_set_transform(Vector2(vis.end.x, 0.0), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect_region(tex, Rect2(0.0, vis.position.y, vis.size.x, vis.size.y),
			Rect2(u0, v0, u1 - u0, v1 - v0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var u0 := (vis.position.x - r.position.x) * sx
		var u1 := (vis.end.x - r.position.x) * sx
		draw_texture_rect_region(tex, vis, Rect2(u0, v0, u1 - u0, v1 - v0))

## A place still free: a dashed outline and a question mark.
func _teken_leeg(r: Rect2, b: Rect2) -> void:
	var dik := maxf(2.0, b.size.y * 0.016)
	var stap := maxf(6.0, b.size.y * 0.05)
	draw_rect(r, Color(KL_CREME, 0.45))
	var hoeken := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for z in 4:
		var a: Vector2 = hoeken[z]
		var c: Vector2 = hoeken[(z + 1) % 4]
		var lang := a.distance_to(c)
		var t := 0.0
		while t < lang:
			var e := minf(t + stap * 0.6, lang)
			draw_line(a.lerp(c, t / lang), a.lerp(c, e / lang), KL_LEEG, dik)
			t += stap
	_tekst("?", r, r.size.y * 0.42, KL_LEEG)

## The viewfinder: four thin white corners, while the camera is live.
func _teken_zoeker(b: Rect2) -> void:
	var dik := maxf(2.0, b.size.y * 0.02)
	var arm := b.size.y * 0.12
	var r := b.grow(-b.size.y * 0.06)
	r.position.x += b.size.x * GORDIJN * 0.5
	r.size.x -= b.size.x * GORDIJN * 0.5
	var schaduw := Color(KL_INKT, 0.22)
	for hoek in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)],
			[r.end, Vector2(-1, -1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)]]:
		var p: Vector2 = hoek[0]
		var d: Vector2 = hoek[1]
		if tel_getal > 0 and d == Vector2(-1, 1):
			continue    # the countdown's badge sits in that corner
		var lijn := PackedVector2Array([p + Vector2(0.0, d.y * arm), p, p + Vector2(d.x * arm, 0.0)])
		var lijn2 := PackedVector2Array()
		for q in lijn:
			lijn2.append(q + Vector2(0.0, 1.0))
		draw_polyline(lijn2, schaduw, dik, true)
		draw_polyline(lijn, KL_ZOEKER, dik, true)

## The digit of the countdown: a coral badge in the top-right corner of the
## picture (`badge_rect`), popping in.
func _teken_getal(_b: Rect2) -> void:
	var u := 1.0 if _tel_t <= KLAAR else clampf((_t - _tel_t) / POP_S, 0.0, 1.0)
	var groot := lerpf(1.3, 1.0, 1.0 - (1.0 - u) * (1.0 - u))
	var rust := badge_rect()
	var c := rust.get_center()
	var r := rust.size.y * 0.5 * groot
	draw_circle(c + Vector2(0.0, r * 0.08), r * 1.04, Color(KL_INKT, 0.18), true, -1.0, true)
	draw_circle(c, r, Color.WHITE, true, -1.0, true)
	draw_circle(c, r * 0.87, KL_RAND, true, -1.0, true)
	_tekst(str(tel_getal), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), r * 2.05, Color.WHITE)

## The price tag: a gold label with "€3" on it, as on the stalls.
func _teken_prijs(r: Rect2) -> void:
	if r.size.x <= 0.0:
		return
	draw_style_box(_vlak(KL_PRIJS_D, r.size.y * 0.35), r.grow_individual(0, 0, 0, maxf(1.0, r.size.y * 0.08)))
	draw_style_box(_vlak(KL_PRIJS, r.size.y * 0.35), r)
	# never under the text floor of the house (HOTEL.md §9), whatever the size
	_tekst("€%d" % prijs, r, maxf(r.size.y * 0.7, float(UiThema.VLOER)), KL_INKT)

## The picture's rounded corners: the frame's colour over its square ones.
func _hoeken(b: Rect2, r: float, kl: Color) -> void:
	if r < 1.0:
		return
	var stappen := 8
	for z in 4:
		var hoek: Vector2 = [b.position, Vector2(b.end.x, b.position.y), b.end,
			Vector2(b.position.x, b.end.y)][z]
		var d: Vector2 = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)][z]
		var mid := hoek + d * r
		var pts := PackedVector2Array([hoek])
		for k in stappen + 1:
			var a := float(k) / float(stappen) * PI * 0.5
			pts.append(mid - Vector2(d.x * cos(a), d.y * sin(a)) * r)
		draw_colored_polygon(pts, kl)

func _rand_lijn(hoek: float) -> StyleBoxFlat:
	var sl := "lijn|%d" % int(hoek)
	if not _vlakken.has(sl):
		var s := StyleBoxFlat.new()
		s.draw_center = false
		s.border_color = Color(KL_INKT, 0.12)
		s.set_border_width_all(1)
		s.set_corner_radius_all(int(hoek))
		s.anti_aliasing = true
		_vlakken[sl] = s
	return _vlakken[sl]

## The lamp's light: cream in the middle, nothing at the edge.
static var _licht_tex: GradientTexture2D = null

static func _licht() -> GradientTexture2D:
	if _licht_tex == null:
		var gr := Gradient.new()
		gr.set_color(0, Color(KL_CREME, 0.9))
		gr.set_color(1, Color(KL_CREME, 0.0))
		var t := GradientTexture2D.new()
		t.gradient = gr
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_licht_tex = t
	return _licht_tex

func _tekst(t: String, r: Rect2, hoog: float, kl: Color) -> void:
	if _font == null:
		_font = UiThema.laad_font(true)
		if _font == null:
			_font = ThemeDB.fallback_font
	var maat := maxi(8, int(hoog))
	var asc := _font.get_ascent(maat)
	var desc := _font.get_descent(maat)
	var y := r.position.y + (r.size.y + asc - desc) * 0.5
	draw_string(_font, Vector2(r.position.x, y), t, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, maat, kl)

func _vlak(kl: Color, hoek: float) -> StyleBoxFlat:
	var sl := "%s|%d" % [kl.to_html(), int(hoek)]
	if not _vlakken.has(sl):
		if _vlakken.size() > 64:
			_vlakken.clear()
		var s := StyleBoxFlat.new()
		s.bg_color = kl
		s.set_corner_radius_all(int(hoek))
		s.anti_aliasing = true
		_vlakken[sl] = s
	return _vlakken[sl]

## Quad in and out, as the tween of the flash was.
static func _zacht(u: float) -> float:
	return 2.0 * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 2.0) / 2.0
