class_name BandNotenbalk
extends Control
## The stave of De dierenband, large and straight on, while `band` runs — the
## way the wekker brings its clock forward and the photo booth its screen.
##
## One TILE per bar (`maat`), side by side and wrapping into rows: five stave
## lines, a bar line at both ends, and in it one note per tick, climbing like
## the pitch of the drum (`Snd.plop(j)` rises with the tick j of the bar).  A
## gap of paper between two tiles makes the groups of groep 4/5 something a
## child sees at once: four tiles of five notes ARE 4 × 5.
##
## The notes stand there pale from the start; every tick of the drum lights
## ONE more (`slag(n)`), in the drum's red — or, for the second rhythm of
## "samen" (groep 3), in blue — with a yellow glow that fades.  After the
## rhythm every note stays lit, so a child with the sound off counts the lit
## notes: the number lives in the world, not only in the ear.
##
## Not a button: a tap goes through it.  `Hits` puts it down and clears it like
## every element of the game (`kind: "eigen"`); its size it asks the game at
## every placement (`meet`).  It lays itself out in whatever size it gets:
## as many tiles per row as give the largest notes (`indeling`).
##
## One clock moves the glow: `tik(dt)`, which `_process` turns.  In reduced
## motion, and headless in the tree (the suite), every change is final the
## moment it is made: a lit note is simply lit.  A stave outside the tree is
## never drawn, so it waits for whoever holds it to turn the clock — that is
## how a test sees every frame of a glow.  WHEN a note lights is the game's
## (`spel.gd::_speel_ritme`, one `na()` per tick): sound and light come from
## the same line of code, so they can never drift apart.

const KL_RAND := Color("#7E6255")       ## the brown edge (the wekker's case)
const KL_PAPIER := Color("#FFF7E4")     ## the cream sheet
const KL_TEGEL := Color("#FFFDF6")      ## a bar's own tile, a shade lighter
const KL_LIJN := Color("#CDB9A5")       ## the stave lines
const KL_STREEP := Color("#7E6255")     ## the bar lines
const KL_DOOF := Color("#EADCCB")       ## a note that has not sounded yet
const KL_DOOF_RAND := Color("#C9B6A2")
const KL_AAN: Array[Color] = [Color("#E2574C"), Color("#4F8FD0")]   ## rhythm A (the drum), rhythm B
const KL_AAN_RAND: Array[Color] = [Color("#A93B33"), Color("#33689F")]
const KL_GLOED := Color("#F5D37A")      ## the spark on the drumhead (`spel.gd::VONK`)
const KL_SCHADUW := Color(0.29, 0.231, 0.2, 0.16)

## The parts, in `cel` — the width of one note's slot.
const RAND := 0.7          ## the edge round the sheet (frame and air)
const PAD := 0.4           ## inside a tile, before the first and after the last note
const GAT := 0.7           ## paper between two tiles in a row
const RIJ_GAT := 0.35      ## paper between two rows
const LIJN := 0.6          ## one stave space
const RIJ_H := 4.5         ## a row: the stave with the highest head and the longest stem
const KOP_X := 0.38        ## half the width of a note head
const STEEL := 3.4         ## a stem, in stave spaces
const HOOGSTE := 9         ## the top position on the stave (0 = the bottom line)
const CEL_MAX := 44.0      ## px: a short rhythm does not blow up into giant notes
const CEL_MIN := 6.0

const GLOED_S := 0.45      ## seconds: the glow of a note that just sounded
const FEEST_S := 0.9       ## seconds: the glow of the whole stave at the right answer
const FEEST_STAP := 0.035  ## seconds between two notes of that sweep

## The bars on the stave: one Array of ticks per bar (`Beurt.opzet().maten`,
## only the ones the stave SHOWS).
var maten: Array = []
## The colour of every bar: 0 = rhythm A, 1 = rhythm B.
var kleuren: Array = []
## What the size is: `func() -> Vector2`, from the game.
var meet: Callable = Callable()

var _aan := 0              ## how many notes are lit (a prefix: they light in order)
var _t := 0.0              ## the clock
var _t_aan: Array[float] = []    ## per note: when it lit (-INF: never, or long ago)
var _t_feest := -INF
var _feest_aan := false
var _vlakken := {}
static var _headless := -1

func _init() -> void:
	name = "BandNotenbalk"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE

func _enter_tree() -> void:
	if _direct():
		_rond_af()

func _process(dt: float) -> void:
	if _direct():
		if _bezig():
			_rond_af()
		return
	tik(dt)

## How large `Hits` must put it down (`hits.gd:_maat_van`).  It also gets
## SMALLER (the maths bar docks), so it lets go of the old pin first.
func inhoud_maat() -> Vector2:
	var m: Vector2 = meet.call() if meet.is_valid() else custom_minimum_size
	if meet.is_valid():
		custom_minimum_size = Vector2.ZERO
	return Vector2(maxf(48.0, m.x), maxf(48.0, m.y))

# ------------------------------------------------------------ what it shows

## Show these bars, every note pale.  `o.kleuren`: per bar 0 or 1.
func zet(nieuw: Array, o: Dictionary = {}) -> void:
	maten = nieuw.duplicate(true)
	kleuren = []
	var kl: Array = o.get("kleuren", [])
	for m in maten.size():
		kleuren.append(int(kl[m]) if m < kl.size() else 0)
	_t_aan.clear()
	_t_aan.resize(aantal())
	_t_aan.fill(-INF)
	_aan = 0
	_feest_aan = false
	_t_feest = -INF
	queue_redraw()

## Tick `n` of the rhythm sounds: notes 1 … n are lit, note n just now.
func slag(n: int) -> void:
	var nieuw := clampi(n, 0, aantal())
	for i in range(_aan, nieuw):
		_t_aan[i] = KLAAR if _direct() else _t
	_aan = nieuw
	queue_redraw()

## Every note pale again: the rhythm starts over.
func doof() -> void:
	_aan = 0
	_t_aan.fill(-INF)
	_feest_aan = false
	_t_feest = -INF
	queue_redraw()

## Every note lit, without a glow (a turn that comes back after a reload).
func alles_aan() -> void:
	_aan = aantal()
	_t_aan.fill(KLAAR)
	queue_redraw()

## The right answer: every note lit, and a glow sweeps over the stave once.
func feest() -> void:
	alles_aan()
	_feest_aan = true
	_t_feest = KLAAR if _direct() else _t
	queue_redraw()

## Moves the clock on by `dt` seconds, and with it every glow.  `_process`
## turns it; a test may too.
func tik(dt: float) -> void:
	var was := beweegt()
	_t += maxf(0.0, dt)
	if was or beweegt():
		queue_redraw()

## Does the clock change what I show?  While a glow fades.  Never in reduced
## motion, nor headless in the tree.
func beweegt() -> bool:
	if _direct():
		return false
	for i in aantal():
		if gloed(i) > 0.0:
			return true
	return false

# ------------------------------------------------------------- the public face

## How many notes the stave holds.
func aantal() -> int:
	var n := 0
	for m in maten:
		n += (m as Array).size()
	return n

## How many notes are lit: after the rhythm, the number the child counts.
func aantal_aan() -> int:
	return _aan

func is_aan(i: int) -> bool:
	return i >= 0 and i < _aan

## 1 … 0: how bright the glow of note `i` (0-based) is right now.
func gloed(i: int) -> float:
	if _direct() or i < 0 or i >= aantal():
		return 0.0
	var g := 0.0
	if i < _aan and _t_aan[i] > KLAAR:
		g = 1.0 - (_t - _t_aan[i]) / GLOED_S
	if _feest_aan and _t_feest > KLAAR:
		var u := _t - _t_feest - float(i) * FEEST_STAP
		if u >= 0.0:
			g = maxf(g, 1.0 - u / FEEST_S)
	return clampf(g, 0.0, 1.0)

## Tiles per row and rows, for my size now.
func indeling() -> Vector2i:
	return Vector2i(_lay()["per_rij"], _lay()["rijen"])

## The tile of bar `m`, in my own coordinates.
func maat_rect(m: int) -> Rect2:
	var l := _lay()
	var tegels: Array = l["tegels"]
	return tegels[m] if m >= 0 and m < tegels.size() else Rect2()

## The head of note `i` (0-based, in the order they sound), in my coordinates.
func noot_rect(i: int) -> Rect2:
	var plek := _noot_van(i)
	if plek.x < 0:
		return Rect2()
	var l := _lay()
	var cel: float = l["cel"]
	var c := _kop_midden(l, plek.x, plek.y)
	return Rect2(c - Vector2(KOP_X * cel, LIJN * cel * 0.5), Vector2(2.0 * KOP_X * cel, LIJN * cel))

## The bar note `i` belongs to.
func maat_van(i: int) -> int:
	return _noot_van(i).x

## The kind of size the game asks for: the best layout of `maten` inside
## `breed` × `hoog`, never notes larger than `CEL_MAX`.
static func past(breed: float, hoog: float, wat: Array) -> Vector2:
	var l := _beste(breed, hoog, wat)
	return Vector2(float(l["w"]) * float(l["cel"]), float(l["h"]) * float(l["cel"]))

# ------------------------------------------------------------------ layout

const KLAAR := -1.0e12     ## "lit long ago": no glow

## The arrangement with the largest notes that fits in `breed` × `hoog`:
## {per_rij, rijen, cel, w, h} (w and h in cels).
static func _beste(breed: float, hoog: float, wat: Array) -> Dictionary:
	var n := maxi(1, wat.size())
	var beste := {}
	for per_rij in range(1, n + 1):
		var rijen := int(ceil(float(n) / float(per_rij)))
		var w := 0.0
		for r in rijen:
			var rij := 0.0
			for c in per_rij:
				var m := r * per_rij + c
				if m >= wat.size():
					break
				rij += float((wat[m] as Array).size()) + 2.0 * PAD + (GAT if c > 0 else 0.0)
			w = maxf(w, rij)
		w += 2.0 * RAND
		var h := float(rijen) * RIJ_H + float(rijen - 1) * RIJ_GAT + 2.0 * RAND
		var cel := minf(CEL_MAX, minf(breed / w, hoog / h))
		if beste.is_empty() or cel > float(beste["cel"]) + 0.01:
			beste = {"per_rij": per_rij, "rijen": rijen, "cel": maxf(cel, 0.0), "w": w, "h": h}
	return beste

## The layout for my size now: the tiles, centred row by row.
func _lay() -> Dictionary:
	var l := _beste(size.x, size.y, maten)
	var cel: float = l["cel"]
	var per_rij: int = l["per_rij"]
	var rijen: int = l["rijen"]
	var vol := Vector2(float(l["w"]), float(l["h"])) * cel
	var hoek := (size - vol) * 0.5
	var tegels: Array = []
	for r in rijen:
		var rij_w := 0.0
		for c in per_rij:
			var m := r * per_rij + c
			if m >= maten.size():
				break
			rij_w += float((maten[m] as Array).size()) + 2.0 * PAD + (GAT if c > 0 else 0.0)
		var x := hoek.x + (vol.x - rij_w * cel) * 0.5
		var y := hoek.y + (RAND + float(r) * (RIJ_H + RIJ_GAT)) * cel
		for c in per_rij:
			var m := r * per_rij + c
			if m >= maten.size():
				break
			if c > 0:
				x += GAT * cel
			var w := (float((maten[m] as Array).size()) + 2.0 * PAD) * cel
			tegels.append(Rect2(x, y, w, RIJ_H * cel))
			x += w
	l["tegels"] = tegels
	l["vol"] = Rect2(hoek, vol)
	return l

## (bar, tick in the bar) of note `i`; (-1, -1) when there is none.
func _noot_van(i: int) -> Vector2i:
	var rest := i
	if rest < 0:
		return Vector2i(-1, -1)
	for m in maten.size():
		var k := (maten[m] as Array).size()
		if rest < k:
			return Vector2i(m, rest)
		rest -= k
	return Vector2i(-1, -1)

## Where on the stave tick `j` of a bar of `k` ticks sits: a staircase up,
## in the middle of the stave when it is short.
static func positie(j: int, k: int) -> int:
	var begin := maxi(0, int(floor(float(HOOGSTE - k + 1) / 2.0)))
	return mini(HOOGSTE, begin + j)

## The bottom stave line of a tile (y), and the middle of a head.
func _basis(l: Dictionary, tegel: Rect2) -> float:
	var cel: float = l["cel"]
	# the row holds the highest head and stem above the top line, the lowest
	# stem below the bottom line: 5 spaces up, 1.5 down, in RIJ_H
	return tegel.position.y + tegel.size.y - (RIJ_H * cel - 6.5 * LIJN * cel) * 0.5 - 1.5 * LIJN * cel

func _kop_midden(l: Dictionary, m: int, j: int) -> Vector2:
	var cel: float = l["cel"]
	var tegel: Rect2 = (l["tegels"] as Array)[m]
	var k := (maten[m] as Array).size()
	var x := tegel.position.x + (PAD + 0.5 + float(j)) * cel
	var y := _basis(l, tegel) - float(positie(j, k)) * LIJN * cel * 0.5
	return Vector2(x, y)

# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if size.x < 16.0 or size.y < 16.0 or maten.is_empty():
		return
	var l := _lay()
	var cel: float = l["cel"]
	if cel <= 0.5:
		return
	var vol: Rect2 = l["vol"]
	var rand := RAND * cel
	draw_style_box(_vlak(KL_SCHADUW, rand * 0.9), vol.grow_individual(0, 0, 0, rand * 0.25))
	draw_style_box(_vlak(KL_RAND, rand * 0.9), vol)
	draw_style_box(_vlak(KL_PAPIER, rand * 0.6), vol.grow(-rand * 0.32))
	var tegels: Array = l["tegels"]
	var dun := maxf(1.0, cel * 0.05)
	var dik := maxf(1.5, cel * 0.09)
	for m in tegels.size():
		var t: Rect2 = tegels[m]
		draw_style_box(_vlak(KL_TEGEL, cel * 0.25), t)
		var basis := _basis(l, t)
		for i in 5:
			var y := basis - float(i) * LIJN * cel
			draw_line(Vector2(t.position.x, y), Vector2(t.end.x, y), KL_LIJN, dun, true)
		var top := basis - 4.0 * LIJN * cel
		for x in [t.position.x, t.end.x]:
			draw_line(Vector2(x, top), Vector2(x, basis), KL_STREEP, dik, true)
	var i := 0
	for m in maten.size():
		var k := (maten[m] as Array).size()
		for j in k:
			_teken_noot(l, m, j, i)
			i += 1

## One quarter note: a tilted head and a stem — up below the middle line,
## down from it on.  Pale until it sounded; lit in the colour of its rhythm,
## with the yellow glow round it while that fades.
func _teken_noot(l: Dictionary, m: int, j: int, i: int) -> void:
	var cel: float = l["cel"]
	var k := (maten[m] as Array).size()
	var c := _kop_midden(l, m, j)
	var aan := is_aan(i)
	var kleur := int(kleuren[m]) if m < kleuren.size() else 0
	var vul: Color = KL_AAN[kleur] if aan else KL_DOOF
	var rand: Color = KL_AAN_RAND[kleur] if aan else KL_DOOF_RAND
	var g := gloed(i)
	var groot := 1.0 + 0.35 * g
	var rx := KOP_X * cel * groot
	var ry := LIJN * cel * 0.5 * groot
	if g > 0.0:
		draw_circle(c, rx * 1.9, Color(KL_GLOED, 0.85 * g))
	var op := positie(j, k) < 4
	var steel_x := c.x + (rx * 0.92 if op else -rx * 0.92)
	var steel_y := c.y + (-1.0 if op else 1.0) * STEEL * LIJN * cel
	draw_line(Vector2(steel_x, c.y), Vector2(steel_x, steel_y), rand, maxf(1.5, cel * 0.08), true)
	_ovaal(c, rx + maxf(1.0, cel * 0.05), ry + maxf(1.0, cel * 0.05), rand)
	_ovaal(c, rx, ry, vul)

## A note head: an oval tilted a little, like a real one.
func _ovaal(c: Vector2, rx: float, ry: float, kl: Color) -> void:
	var punten := PackedVector2Array()
	var draai := -0.35
	for s in 20:
		var a := TAU * float(s) / 20.0
		punten.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(draai))
	draw_colored_polygon(punten, kl)

func _vlak(kl: Color, hoek: float) -> StyleBoxFlat:
	var sleutel := "%s|%d" % [kl.to_html(), int(hoek)]
	if _vlakken.has(sleutel):
		return _vlakken[sleutel]
	var s := StyleBoxFlat.new()
	s.bg_color = kl
	s.set_corner_radius_all(int(hoek))
	s.anti_aliasing = true
	_vlakken[sleutel] = s
	return s

# ------------------------------------------------------------------ the clock

## Everything under way, done at once (reduced motion, headless in the tree).
func _rond_af() -> void:
	for i in _t_aan.size():
		if _t_aan[i] > KLAAR:
			_t_aan[i] = KLAAR
	if _t_feest > KLAAR:
		_t_feest = KLAAR
	queue_redraw()

func _bezig() -> bool:
	if _t_feest > KLAAR:
		return true
	for v in _t_aan:
		if v > KLAAR:
			return true
	return false

## Reduced motion, or headless in the tree: no animation, everything final.
func _direct() -> bool:
	if Ui.rust_modus():
		return true
	if _headless < 0:
		_headless = 1 if DisplayServer.get_name() == "headless" else 0
	return _headless == 1 and is_inside_tree()
