class_name SterrenKijker
extends Control
## What the telescope sees, LARGE and flat while Sterren tellen runs — the way
## `SpiegelBord` brings the mask forward and `FotoScherm` the booth's screen.
## A patch of night sky in a brass rim, and in it the stars of the turn in
## their PATTERNS (`beurt.gd`): dice faces, ten-frames with their empty boxes,
## rows (a row of ten with a gap after five), blocks of a hundred (four fives
## of five) — so the child sees the structure instead of counting one by one.
## Nothing else shines in it: every star in the view is a star to count.
##
## The stars twinkle softly (not in reduced motion); after the right answer
## they light up (`juich`).  A miss changes nothing here (HOTEL.md §9).
##
## Not a button: a tap goes through it.  `Hits` puts it down and clears it like
## every element of the game (`kind: "eigen"`); its size it asks the game at
## every placement (`meet`), so it never comes under the maths bar.

const KL_LUCHT := Color("#14224A")
const KL_LUCHT_L := Color("#1E3163")
const KL_RAND := Color("#E3B04B")         ## the brass rim of the telescope
const KL_RAND_D := Color("#B98A2E")
const KL_STER := Color("#FFE27A")
const KL_STER_L := Color("#FFF8D6")
const KL_GLOED := Color("#FFE9A8")
const KL_RAAM := Color("#9FB4E8")         ## the lines of a ten-frame or a block of a hundred
const KL_LEEG := Color("#C9D6FF")         ## an empty box of a ten-frame
const KL_SCHADUW := Color(0.0, 0.0, 0.0, 0.22)

const GAT := 1.0           ## cells between two patterns on a line
const GAT_RIJ := 1.0       ## ... between two lines
const MARGE := 0.9         ## cells of sky round the stars
const SPLEET := 0.5        ## the gap after five in a row of ten (and in a block of a hundred)
const RAND := 0.035        ## the rim, as a share of the shortest side
const VERHOUDING_MIN := 0.7
const VERHOUDING_MAX := 2.6

## What the size is: `func() -> Vector2`, from the game.
var meet: Callable = Callable()
## 0 … 1, the soft twinkle, round and round.
var fonkel := 0.0:
	set(w):
		fonkel = w
		queue_redraw()
## 0 … 1, how much the stars light up after the right answer.
var glans := 0.0:
	set(w):
		glans = w
		queue_redraw()

var _patronen: Array = []
var _fonkel_tw: Tween = null
var _glans_tw: Tween = null

func _init() -> void:
	name = "SterrenKijker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE

func _ready() -> void:
	if not Ui.rust_modus() and DisplayServer.get_name() != "headless":
		_fonkel_tw = create_tween().set_loops()
		_fonkel_tw.tween_property(self, "fonkel", 1.0, 2.4).from(0.0)

## How large `Hits` must put it down (`hits.gd:_maat_van`).  `Hits` pins the
## size it placed into `custom_minimum_size` and takes the larger of that and
## this; the view also gets SMALLER (the maths bar docks), so it lets go of the
## old pin first.
func inhoud_maat() -> Vector2:
	var m: Vector2 = meet.call() if meet.is_valid() else custom_minimum_size
	if meet.is_valid():
		custom_minimum_size = Vector2.ZERO
	return Vector2(maxf(48.0, m.x), maxf(48.0, m.y))

## The patterns of the turn (`Beurt.maak(...)["patronen"]`).
func zet(patronen: Array) -> void:
	_patronen = patronen.duplicate(true)
	if meet.is_valid():
		var m: Variant = meet.call()
		if m is Vector2:
			size = m
	queue_redraw()

## The right answer: the stars light up, and stay a little brighter.
func juich() -> void:
	if _glans_tw != null:
		_glans_tw.kill()
		_glans_tw = null
	if Ui.rust_modus() or DisplayServer.get_name() == "headless" or not is_inside_tree():
		glans = 0.45
		return
	_glans_tw = create_tween()
	_glans_tw.tween_property(self, "glans", 1.0, 0.25).from(0.0)
	_glans_tw.tween_property(self, "glans", 0.45, 0.7)

# ------------------------------------------------------------- voor de tests

## Every star that shines in the view (a block of a hundred has a hundred).
func aantal_sterren() -> int:
	var n := 0
	for p in _patronen:
		n += ((p as Dictionary).get("cellen", []) as Array).size()
	return n

## The empty boxes of the ten-frames.
func aantal_leeg() -> int:
	var n := 0
	for p in _patronen:
		n += ((p as Dictionary).get("leeg", []) as Array).size()
	return n

func aantal_patronen() -> int:
	return _patronen.size()

## The kind of each pattern, in order (`dobbel`, `tien`, `rij`, `honderd`).
func vormen() -> Array[String]:
	var uit: Array[String] = []
	for p in _patronen:
		uit.append(str((p as Dictionary).get("vorm", "")))
	return uit

## What the stars in the view count for together (`Beurt.aantal`).
func waarde() -> int:
	var n := 0
	for p in _patronen:
		n += int((p as Dictionary).get("waarde", 0))
	return n

## Where each pattern is drawn, in my own coordinates.
func indeling() -> Array[Rect2]:
	var uit: Array[Rect2] = []
	var lay := _plaats(size)
	var o: Vector2 = lay["o"]
	var cel: float = lay["cel"]
	for rect in lay["plekken"]:
		var r: Rect2 = rect
		uit.append(Rect2(o + r.position * cel, r.size * cel))
	return uit

# ------------------------------------------------------------------ indeling

## The width over height the patterns want, margins included, for a view that
## is about 1.7 times as wide as it is tall — the game sizes the view with it.
static func verhouding(patronen: Array) -> float:
	var m := cellen(patronen)
	return clampf(m.x / maxf(0.001, m.y), VERHOUDING_MIN, VERHOUDING_MAX)

## How many cells wide and high the stars of `patronen` are, margins included,
## laid out for a view about 1.7 times as wide as it is tall: with a largest
## cell the game keeps a few stars from growing into dinner plates.
static func cellen(patronen: Array) -> Vector2:
	var lay := _kies(patronen, Vector2(1.7, 1.0))
	var maat: Vector2 = lay["maat"]
	return maat + Vector2(2.0 * MARGE, 2.0 * MARGE)

## A pattern's size in cells, with the gap after five in a row of ten and in a
## block of a hundred.
static func maat_van(p: Dictionary) -> Vector2:
	var b := float(int(p.get("breed", 5)))
	var h := float(int(p.get("hoog", 1)))
	if int(p.get("breed", 5)) == 10:
		b += SPLEET
	if str(p.get("vorm", "")) == "honderd":
		h += SPLEET
	return Vector2(b, h)

## The middle of cell `c` of pattern `p`, in cells from the pattern's corner.
static func cel_midden(p: Dictionary, c: Vector2i) -> Vector2:
	var x := float(c.x)
	var y := float(c.y)
	if int(p.get("breed", 5)) == 10 and c.x >= 5:
		x += SPLEET
	if str(p.get("vorm", "")) == "honderd" and c.y >= 5:
		y += SPLEET
	return Vector2(x + 0.5, y + 0.5)

## The patterns in lines no wider than `w_max` cells, every line centred:
## {plekken: [Rect2 in cells], maat: Vector2 cells}.
static func _lijnen(patronen: Array, w_max: float) -> Dictionary:
	var lijnen: Array = []
	var lijn: Array = []
	var x := 0.0
	for p in patronen:
		var m := maat_van(p)
		if not lijn.is_empty() and x + m.x > w_max + 0.001:
			lijnen.append(lijn)
			lijn = []
			x = 0.0
		lijn.append(m)
		x += m.x + GAT
	if not lijn.is_empty():
		lijnen.append(lijn)
	var breed := 0.0
	for l in lijnen:
		var w := -GAT
		for m in l:
			w += (m as Vector2).x + GAT
		breed = maxf(breed, w)
	var plekken: Array = []
	var y := 0.0
	for l in lijnen:
		var w := -GAT
		var h := 0.0
		for m in l:
			w += (m as Vector2).x + GAT
			h = maxf(h, (m as Vector2).y)
		var xx := (breed - w) * 0.5
		for m in l:
			var mm: Vector2 = m
			plekken.append(Rect2(Vector2(xx, y + (h - mm.y) * 0.5), mm))
			xx += mm.x + GAT
		y += h + GAT_RIJ
	return {"plekken": plekken, "maat": Vector2(breed, maxf(0.0, y - GAT_RIJ))}

## Of every way to break the patterns into lines, the one that gives the
## biggest stars in a view of size `vak`.
static func _kies(patronen: Array, vak: Vector2) -> Dictionary:
	var breedtes: Array = []
	for p in patronen:
		breedtes.append(maat_van(p).x)
	var kandidaten: Array = []
	for a in breedtes.size():
		var w := -GAT
		for b in range(a, breedtes.size()):
			w += float(breedtes[b]) + GAT
			if not kandidaten.has(w):
				kandidaten.append(w)
	kandidaten.sort()
	var beste := {"plekken": [], "maat": Vector2(1.0, 1.0)}
	var beste_cel := -1.0
	for w in kandidaten:
		var lay := _lijnen(patronen, float(w))
		var m: Vector2 = lay["maat"] + Vector2(2.0 * MARGE, 2.0 * MARGE)
		var cel := minf(vak.x / m.x, vak.y / m.y)
		if cel > beste_cel + 0.0001:
			beste_cel = cel
			beste = lay
	return beste

## The layout in my own coordinates: the plekken in cells, the cell size in
## pixels and the corner of the stars (`o`), centred in the rim.
func _plaats(vak: Vector2) -> Dictionary:
	var binnen := vak - Vector2.ONE * 2.0 * _rand(vak)
	var lay := _kies(_patronen, binnen)
	var maat: Vector2 = lay["maat"]
	var m := maat + Vector2(2.0 * MARGE, 2.0 * MARGE)
	var cel := minf(binnen.x / m.x, binnen.y / m.y)
	var o := (vak - maat * cel) * 0.5
	return {"plekken": lay["plekken"], "cel": cel, "o": o}

func _rand(vak: Vector2) -> float:
	return maxf(3.0, minf(vak.x, vak.y) * RAND)

# ------------------------------------------------------------------ tekenen

func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var vol := Rect2(Vector2.ZERO, size)
	var rand := _rand(size)
	var hoek := minf(size.x, size.y) * 0.08
	draw_style_box(_vlak(KL_SCHADUW, hoek), vol.grow(2.0).grow_individual(0, 0, 0, 3.0))
	draw_style_box(_vlak(KL_RAND_D, hoek), vol)
	draw_style_box(_vlak(KL_RAND, hoek), vol.grow(-rand * 0.35))
	var lucht := _vlak(KL_LUCHT, maxf(2.0, hoek - rand))
	lucht.border_width_top = int(maxf(1.0, rand * 0.6))
	lucht.border_color = KL_LUCHT_L
	draw_style_box(lucht, vol.grow(-rand))
	if _patronen.is_empty():
		return
	var lay := _plaats(size)
	var cel: float = lay["cel"]
	var o: Vector2 = lay["o"]
	var plekken: Array = lay["plekken"]
	var lijn := maxf(1.0, cel * 0.06)
	for j in mini(plekken.size(), _patronen.size()):
		var p: Dictionary = _patronen[j]
		var plek: Rect2 = plekken[j]
		var hoek_p := o + plek.position * cel
		var vorm := str(p.get("vorm", ""))
		# the frame of ten and the block of a hundred show their boxes
		if vorm == "tien" or vorm == "honderd":
			var kader := Rect2(hoek_p, plek.size * cel).grow(cel * 0.1)
			draw_rect(kader, Color(KL_RAAM, 0.55), false, lijn)
			if vorm == "tien":
				for c in range(1, 5):
					var x := hoek_p.x + float(c) * cel
					draw_line(Vector2(x, kader.position.y), Vector2(x, kader.end.y), Color(KL_RAAM, 0.28), lijn)
				var y := hoek_p.y + cel
				draw_line(Vector2(kader.position.x, y), Vector2(kader.end.x, y), Color(KL_RAAM, 0.28), lijn)
		var r := cel * (0.36 if vorm == "honderd" else 0.42)
		for c in p.get("leeg", []):
			var m := hoek_p + cel_midden(p, c) * cel
			draw_arc(m, r * 0.7, 0.0, TAU, 20, Color(KL_LEEG, 0.6), maxf(1.5, cel * 0.07), true)
		var cellen: Array = p.get("cellen", [])
		for n in cellen.size():
			var c: Vector2i = cellen[n]
			var m := hoek_p + cel_midden(p, c) * cel
			# a faint warm halo that breathes a little, much brighter once counted
			var fase := float((c.x * 7 + c.y * 13 + j * 5) % 17) / 17.0
			var gloed := 0.05 + 0.03 * sin(TAU * (fonkel + fase)) + 0.22 * glans
			draw_circle(m, r * (1.2 + 0.4 * glans), Color(KL_GLOED, clampf(gloed * 0.6, 0.0, 1.0)))
			draw_circle(m, r * (0.9 + 0.3 * glans), Color(KL_GLOED, clampf(gloed, 0.0, 1.0)))
			_ster(m, r * (1.0 + 0.12 * glans), KL_STER.lerp(KL_STER_L, 0.5 * glans))

## A five-pointed star round `m`, one point up, with a light dot in its heart.
func _ster(m: Vector2, r: float, kl: Color) -> void:
	var punten := PackedVector2Array()
	for i in 10:
		var hoek := -PI / 2.0 + PI * float(i) / 5.0
		var straal := r if i % 2 == 0 else r * 0.45
		punten.append(m + Vector2(cos(hoek), sin(hoek)) * straal)
	draw_colored_polygon(punten, kl)
	draw_circle(m - Vector2(r * 0.12, r * 0.12), r * 0.18, KL_STER_L)

func _vlak(kl: Color, hoek: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = kl
	s.set_corner_radius_all(int(hoek))
	s.anti_aliasing = true
	return s
