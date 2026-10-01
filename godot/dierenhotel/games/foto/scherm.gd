class_name FotoScherm
extends Control
## The screen of the photo booth, large and straight on, while `foto` runs —
## the way the wekker brings its clock forward and Spiegelmaskers its mask.
## The owner asked for "de prijs per dier daaronder": one frame per animal that
## goes on the photo, the animal in it, and under every frame its price.  Before
## two are chosen, empty frames with a "?" say how many at least, each with the
## price under it already.  When the money is in, the screen becomes the photo:
## white paper, the animals side by side and happy, a flash over it.
##
## Not a button: a tap goes through it.  `Hits` puts it down and clears it like
## every element of the game (`kind: "eigen"`); its size it asks the game at
## every placement (`meet`), so it never comes under the maths bar.

const KL_RAND := Color("#EF9483")       ## the booth's own coral
const KL_RAND_D := Color("#D97B6C")
const KL_SCHERM := Color("#E6F4FA")     ## the booth's screen
const KL_VAK := Color("#FFF6EA")
const KL_LEEG := Color("#B9A898")
const KL_PRIJS := Color("#F2C14E")      ## a price tag, as on the stalls
const KL_PRIJS_D := Color("#D9A53A")
const KL_INKT := Color("#4A3B33")
const KL_FOTO := Color("#FFFFFF")
const KL_FOTO_ACHTER := Color("#FDE3D3")
const KL_SCHADUW := Color(0.29, 0.231, 0.2, 0.16)

## The parts of a frame, as fractions of its width.
const PORTRET := 0.84      ## the picture is this tall (an animal is wider than tall)
const PRIJS_H := 0.3       ## the price tag under it
const GAT := 0.07          ## between frames and round the edge
const RAND := 0.12         ## the coral edge round the whole screen

## The animals on it, in the order they were chosen: [{kind, acc}].
var dieren: Array = []
## How many frames: at least two (the fewest that may go on the photo).
var vakken := 2
## The price per animal.
var prijs := 0
## The photo is taken.
var foto := false
## What the size is: `func() -> Vector2`, from the game.
var meet: Callable = Callable()
## 1 … 0, the flash over the photo.
var flits := 0.0:
	set(w):
		flits = w
		queue_redraw()

var _font: Font = null

func _init() -> void:
	name = "FotoScherm"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	# pixel art stays crisp when it is blown up; the voxel plates are smooth
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if Art.pixel() \
		else CanvasItem.TEXTURE_FILTER_LINEAR

## How large `Hits` must put it down (`hits.gd:_maat_van`).  `Hits` pins the
## size it placed into `custom_minimum_size` and takes the larger of that and
## this; but this screen also gets SMALLER (a third animal makes the frames
## narrower, the maths bar docks), so it lets go of the old pin first.
func inhoud_maat() -> Vector2:
	var m: Vector2 = meet.call() if meet.is_valid() else custom_minimum_size
	if meet.is_valid():
		custom_minimum_size = Vector2.ZERO
	return Vector2(maxf(48.0, m.x), maxf(48.0, m.y))

## The size that goes with a screen `breed` wide and `n` frames.
static func maat_bij(breed: float, n: int) -> Vector2:
	var vak := vak_breed(breed, n)
	return Vector2(breed, vak * (2.0 * RAND + PORTRET + PRIJS_H + GAT * 3.0))

## How wide one frame is on a screen `breed` wide with `n` frames: the frames,
## the gaps between them and the edge on both sides make up the width.
static func vak_breed(breed: float, n: int) -> float:
	var k := maxi(1, n)
	return breed / (float(k) + GAT * float(k + 1) + 2.0 * RAND)

## Show this: `dieren` [{kind, acc}], `prijs`, `foto`.
func zet(p: Dictionary) -> void:
	dieren = p.get("dieren", [])
	prijs = int(p.get("prijs", 0))
	foto = bool(p.get("foto", false))
	vakken = maxi(2, dieren.size())
	queue_redraw()

## A flash over the photo (`foto` on), fading out; nothing in reduced motion.
func klik() -> void:
	if Ui.rust_modus() or DisplayServer.get_name() == "headless":
		flits = 0.0
		return
	flits = 1.0
	create_tween().tween_property(self, "flits", 0.0, 0.6).set_trans(Tween.TRANS_QUAD)

## The rectangle of frame `i`'s picture, and of its price tag, in my own
## coordinates.
func vak_rect(i: int) -> Rect2:
	var vak := vak_breed(size.x, vakken)
	var rand := vak * RAND
	var x := rand + vak * GAT + float(i) * vak * (1.0 + GAT)
	return Rect2(x, rand + vak * GAT, vak, vak * PORTRET)

func prijs_rect(i: int) -> Rect2:
	var r := vak_rect(i)
	var h := r.size.x * PRIJS_H
	var w := r.size.x * 0.78
	return Rect2(r.position.x + (r.size.x - w) * 0.5, r.end.y + r.size.x * GAT, w, h)

func _rand() -> float:
	return vak_breed(size.x, vakken) * RAND

func _draw() -> void:
	if size.x < 16.0 or size.y < 16.0:
		return
	var heel := Rect2(Vector2.ZERO, size)
	var rand := _rand()
	draw_style_box(_vlak(KL_SCHADUW, rand * 1.2), heel.grow_individual(0, 0, 0, rand * 0.3))
	if foto:
		# the printed photo, a polaroid: white paper, one picture of the whole
		# group, and the wide white edge under it where the prices were
		draw_style_box(_vlak(KL_FOTO, rand * 0.6), heel)
		var a := vak_rect(0)
		var b := vak_rect(vakken - 1)
		var beeld := Rect2(a.position, b.end - a.position).grow(a.size.x * GAT * 0.5)
		draw_style_box(_vlak(KL_FOTO_ACHTER, rand * 0.4), beeld)
	else:
		draw_style_box(_vlak(KL_RAND, rand * 1.2), heel)
		draw_style_box(_vlak(KL_SCHERM, rand * 0.7), heel.grow(-rand * 0.55))
	for i in vakken:
		var r := vak_rect(i)
		if i < dieren.size():
			if not foto:
				draw_style_box(_vlak(KL_VAK, r.size.x * 0.12), r)
			_teken_dier(dieren[i], r)
		else:
			_teken_leeg(r)
		if not foto and prijs > 0:
			_teken_prijs(prijs_rect(i))
	if flits > 0.0:
		draw_rect(heel, Color(1, 1, 1, clampf(flits, 0.0, 1.0)))

## One animal, standing on the bottom of its frame and filling it: the plate
## of the largest whole scale that fits, blown up the rest of the way (a
## tablet draws two or three screen pixels per canvas pixel, so the uneven
## step of a fractional blow-up does not show).
func _teken_dier(d: Dictionary, r: Rect2) -> void:
	var kind := str(d.get("kind", "hond"))
	var pose := "blijA" if foto else "rust"
	var acc = d.get("acc", [])
	var een = Art.dier(kind, pose, 1, acc)
	if een == null or een.w <= 0 or een.h <= 0:
		return
	var doel := r.grow(-r.size.x * 0.05)
	var schaal := minf(doel.size.x / float(een.w), doel.size.y / float(een.h))
	var g := clampi(int(floor(schaal)), 1, 8)
	var p = een if g == 1 else Art.dier(kind, pose, g, acc)
	if p == null:
		return
	var maat := Vector2(een.w, een.h) * schaal
	var plek := Vector2(doel.position.x + (doel.size.x - maat.x) * 0.5, doel.end.y - maat.y)
	draw_texture_rect(p.tex, Rect2(plek.round(), maat.round()), false)

## An empty frame: a dashed outline and a question mark.
func _teken_leeg(r: Rect2) -> void:
	var dik := maxf(2.0, r.size.x * 0.03)
	var stap := r.size.x * 0.12
	var hoeken := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for z in 4:
		var a: Vector2 = hoeken[z]
		var b: Vector2 = hoeken[(z + 1) % 4]
		var lang := a.distance_to(b)
		var t := 0.0
		while t < lang:
			var e := minf(t + stap * 0.6, lang)
			draw_line(a.lerp(b, t / lang), a.lerp(b, e / lang), KL_LEEG, dik)
			t += stap
	_tekst("?", r, r.size.y * 0.5, KL_LEEG)

## The price tag: a gold label with "€3" on it, as on the stalls.
func _teken_prijs(r: Rect2) -> void:
	draw_style_box(_vlak(KL_PRIJS_D, r.size.y * 0.35), r.grow_individual(0, 0, 0, maxf(1.0, r.size.y * 0.08)))
	draw_style_box(_vlak(KL_PRIJS, r.size.y * 0.35), r)
	_tekst("€%d" % prijs, r, r.size.y * 0.66, KL_INKT)

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
	var s := StyleBoxFlat.new()
	s.bg_color = kl
	s.set_corner_radius_all(int(hoek))
	s.anti_aliasing = true
	return s
