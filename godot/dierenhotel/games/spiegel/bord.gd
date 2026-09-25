class_name SpiegelBord
extends Control
## The mask LARGE and straight on, while Spiegelmaskers runs — the way the
## wekker brings its clock forward (`WekkerKlok`).  The mask on the easel is a
## voxel model at the side of the playroom: small, a dot is a few voxels, and
## with the maths bar docked it is a thumbnail.  This draws the same mask flat:
## the purple edge with two ears, the white face in cells, the mirror line
## (two in groep 5), the pink dots, the dot that is asked in a dark ring that
## breathes, and the three coloured marks — in the colours of the strip's
## buttons, so "which colour is the mirror image?" can be answered by looking.
##
## Not a button: a tap goes through it.  `Hits` puts it down and clears it like
## every element of the game (`kind: "eigen"`); its size it asks the game at
## every placement (`meet`), so it grows with the frame and never comes under
## the maths bar.

const KL_RAND := Color("#B57EDC")
const KL_RAND_D := Color("#9A63C4")
const KL_VLAK := Color("#FFF6EA")
const KL_LIJN := Color("#EADCCB")
const KL_SPIEGEL := Color("#9FB4C8")
const KL_SPIEGEL_L := Color("#E6EEF6")
const KL_STIP := Color("#F06BA8")
const KL_STIP_L := Color("#FF9CCB")
const KL_BRON := Color("#4B2E63")
const KL_SCHADUW := Color(0.29, 0.231, 0.2, 0.16)
## The marks, in the order of `SpiegelBeurt.MERKEN`: blauw, groen, geel.
const KL_MERK := [Color("#3D8BEA"), Color("#4DB86A"), Color("#F2C230")]

## Ears over the edge, in cells.
const OOR := 0.7
const RAND := 0.35          ## the purple edge, in cells
const SPLEET := 0.18        ## the mirror line, in cells

var r := 4
var k := 6
var as_ := "v"
var stip: Array = []
var merk: Array = []
var bron: Array = []
## What the size is: `func() -> Vector2`, from the game.
var meet: Callable = Callable()
## 0 … 1, the breathing of the ring round the dot that is asked.
var adem := 0.0:
	set(w):
		adem = w
		queue_redraw()

var _adem_tw: Tween = null

func _init() -> void:
	name = "SpiegelBord"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE

func _ready() -> void:
	if not Ui.rust_modus() and DisplayServer.get_name() != "headless":
		_adem_tw = create_tween().set_loops()
		_adem_tw.tween_property(self, "adem", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
		_adem_tw.tween_property(self, "adem", 0.0, 0.6).set_trans(Tween.TRANS_SINE)

## How large `Hits` must put it down (`hits.gd:_maat_van`).
func inhoud_maat() -> Vector2:
	var m: Vector2 = meet.call() if meet.is_valid() else custom_minimum_size
	return Vector2(maxf(48.0, m.x), maxf(48.0, m.y))

## The size that goes with a board `breed` wide, for `r` rows and `k` columns.
static func maat_bij(breed: float, rijen: int, kolommen: int) -> Vector2:
	var cel := breed / (float(kolommen) + 2.0 * RAND + SPLEET)
	return Vector2(breed, cel * (float(rijen) + 2.0 * RAND + OOR + SPLEET))

## Show this mask (the same params as the easel model `spiegel_ezel`).
func zet(p: Dictionary) -> void:
	r = int(p.get("r", 4))
	k = int(p.get("k", 6))
	as_ = str(p.get("as", "v"))
	stip = p.get("stip", [])
	merk = p.get("merk", [])
	bron = p.get("bron", [])
	queue_redraw()

## The rectangle of cell [rij, kol] in my own coordinates.
func cel_rect(rij: int, kol: int) -> Rect2:
	var cel := _cel()
	var x := cel * RAND + float(kol) * cel + (cel * SPLEET if kol >= k / 2 else 0.0)
	var y := cel * (OOR + RAND) + float(rij) * cel \
		+ (cel * SPLEET if as_ == "vh" and rij >= r / 2 else 0.0)
	return Rect2(x, y, cel, cel)

func _cel() -> float:
	return size.x / (float(k) + 2.0 * RAND + SPLEET)

func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var cel := _cel()
	var top := cel * OOR
	var lijf := Rect2(0.0, top, size.x, size.y - top)
	# a soft shadow, the ears, the purple edge and the white face
	draw_style_box(_vlak(KL_SCHADUW, cel * 0.35), lijf.grow(cel * 0.08).grow_individual(0, 0, 0, cel * 0.1))
	for x in [cel * 0.5, size.x - cel * 1.7]:
		var oor := PackedVector2Array([Vector2(x, top + cel * 0.2), Vector2(x + cel * 0.6, 0.0),
			Vector2(x + cel * 1.2, top + cel * 0.2)])
		draw_colored_polygon(oor, KL_RAND_D)
	draw_style_box(_vlak(KL_RAND, cel * 0.4), lijf)
	draw_style_box(_vlak(KL_VLAK, cel * 0.2), lijf.grow(-cel * RAND * 0.75))
	# the cells, as faint lines
	for rij in r:
		for kol in k:
			draw_rect(cel_rect(rij, kol).grow(-1.0), KL_LIJN, false, 1.0)
	# the mirror line(s): a strip of mirror with a light edge
	var dik := maxf(3.0, cel * SPLEET)
	var sx := cel_rect(0, k / 2).position.x - cel * SPLEET * 0.5
	var y0 := cel_rect(0, 0).position.y
	var y1 := cel_rect(r - 1, 0).end.y
	draw_line(Vector2(sx, y0), Vector2(sx, y1), KL_SPIEGEL, dik)
	draw_line(Vector2(sx - dik * 0.25, y0), Vector2(sx - dik * 0.25, y1), KL_SPIEGEL_L, maxf(1.0, dik * 0.3))
	if as_ == "vh":
		var sy := cel_rect(r / 2, 0).position.y - cel * SPLEET * 0.5
		var x0 := cel_rect(0, 0).position.x
		var x1 := cel_rect(0, k - 1).end.x
		draw_line(Vector2(x0, sy), Vector2(x1, sy), KL_SPIEGEL, dik)
		draw_line(Vector2(x0, sy - dik * 0.25), Vector2(x1, sy - dik * 0.25), KL_SPIEGEL_L, maxf(1.0, dik * 0.3))
	# the three marks: a coloured ring with a small heart-coloured centre
	for i in mini(merk.size(), KL_MERK.size()):
		var c = merk[i]
		if c == null or (c as Array).size() < 2:
			continue
		var cr := cel_rect(int(c[0]), int(c[1]))
		draw_arc(cr.get_center(), cel * 0.32, 0.0, TAU, 32, KL_MERK[i], maxf(3.0, cel * 0.11))
		draw_circle(cr.get_center(), cel * 0.1, KL_MERK[i])
	# the dots
	for c in stip:
		var cr := cel_rect(int(c[0]), int(c[1]))
		draw_circle(cr.get_center(), cel * 0.3, KL_STIP)
		draw_circle(cr.get_center() - Vector2(cel * 0.08, cel * 0.1), cel * 0.1, KL_STIP_L)
	# the dot that is asked: a dark ring that breathes
	if bron.size() >= 2:
		var cr := cel_rect(int(bron[0]), int(bron[1]))
		var straal := cel * (0.4 + 0.05 * adem)
		draw_arc(cr.get_center(), straal, 0.0, TAU, 32, KL_BRON, maxf(2.5, cel * 0.08))

func _vlak(kl: Color, hoek: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = kl
	s.set_corner_radius_all(int(hoek))
	s.anti_aliasing = true
	return s
