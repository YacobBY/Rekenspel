class_name KoekjesBord
extends Control
## The baker's table LARGE and straight on, while Koekjes bakken runs — the way
## Spiegelmaskers brings its mask forward (`SpiegelBord`) and the photo booth
## its screen (`FotoScherm`).  On the table in the bakery the sum lies as voxel
## decor (`ArtDecorBakkerij.werkbank`): a cookie there is three voxels, and
## with the maths bar docked it is a speck.  This draws the same things flat
## and big enough to count: the tray with its rows of dough or golden cookies,
## the bowls with their eggs (and the eggs beside them), the batter, the plate
## with the rest for the cook, and — while it bakes — the tray inside the
## glowing mouth of the oven.  The same params as the table model
## (`KoekjesBeurt.bord`), so the board can never show another number.
##
## Not a button: a tap goes through it.  `Hits` puts it down and clears it like
## every element of the game (`kind: "eigen"`); its size it asks the game at
## every placement (`meet`), so it never comes under the maths bar.

const KL_TAFEL := Color("#E2C094")       ## ArtDecor.HOUT_L, the table top
const KL_TAFEL_D := Color("#B98F62")     ## ArtDecor.HOUT_D, its edge
const KL_PLAAT := Color("#9EA4BA")       ## the tray (ArtDecorBakkerij.PLAAT)
const KL_PLAAT_L := Color("#C9CCDC")     ## its rim
const KL_DEEG := Color("#F7EAD0")
const KL_DEEG_D := Color("#E6CFA4")
const KL_DEEG_L := Color("#FFF8EA")
const KL_KOEK := Color("#D9A066")
const KL_KOEK_D := Color("#B9803F")
const KL_CHOCO := Color("#5A3A28")
const KL_KOM := Color("#86B2DB")
const KL_KOM_L := Color("#CFE3F6")
const KL_EI := Color("#FFF4E0")
const KL_EI_D := Color("#E8D3B0")
const KL_BESLAG := Color("#F7D774")
const KL_BESLAG_L := Color("#FBE6A0")
const KL_BORD := Color("#FFF7EC")
const KL_BORD_D := Color("#E8DCCB")
const KL_MOND := Color("#3A2E33")
const KL_STEEN := Color("#C9A48A")
const KL_GLOED := Color("#FFB24A")
const KL_VUUR := Color("#FFE08A")
const KL_SCHADUW := Color(0.29, 0.231, 0.2, 0.16)

## In cells (one cookie = one cell):
const PAD := 0.45          ## the table round everything
const RIM := 0.3           ## the tray's rim
const KOM := 5.0           ## a bowl: four eggs across and its wall
const KOM_GAT := 0.6       ## between two bowls
const EI_GAT := 0.5        ## between the bowl and the eggs beside it
const BORD := 3.4          ## the plate with the rest: three by three
const BORD_GAT := 0.5
const BOOG := 0.9          ## the oven's arch over the tray
const ZIJ := 0.5           ## the oven's wall beside the tray

var p: Dictionary = {}
## What the size is: `func() -> Vector2`, from the game.
var meet: Callable = Callable()

func _init() -> void:
	name = "KoekjesBord"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE

## How large `Hits` must put it down (`hits.gd:_maat_van`).  The board gets
## smaller too (the maths bar docks, the plate of the rest goes away), so it
## lets go of the size `Hits` pinned first, as `FotoScherm` does.
func inhoud_maat() -> Vector2:
	var m: Vector2 = meet.call() if meet.is_valid() else custom_minimum_size
	if meet.is_valid():
		custom_minimum_size = Vector2.ZERO
	return Vector2(maxf(48.0, m.x), maxf(48.0, m.y))

## Show this (`KoekjesBeurt.bord`).
func zet(params: Dictionary) -> void:
	p = params.duplicate(true)
	queue_redraw()

## The size of the board in cells for these params.
static func cellen(q: Dictionary) -> Vector2:
	var inhoud := _inhoud(q)
	return inhoud + Vector2(2.0 * PAD, 2.0 * PAD)

## The size that goes with cells of `cel` pixels.
static func maat_bij(cel: float, q: Dictionary) -> Vector2:
	return (cellen(q) * cel).floor()

static func _plaat_maat(q: Dictionary) -> Vector2:
	var rijen := int(q.get("rijen", 0))
	var kolommen := int(q.get("kolommen", 0))
	if rijen <= 0 or kolommen <= 0:
		return Vector2.ZERO
	var m := Vector2(float(kolommen) + 2.0 * RIM, float(rijen) + 2.0 * RIM)
	if bool(q.get("oven", false)):
		m += Vector2(2.0 * ZIJ, BOOG + ZIJ)
	return m

static func _inhoud(q: Dictionary) -> Vector2:
	var plaat := _plaat_maat(q)
	var w := plaat.x
	var h := plaat.y
	if int(q.get("rest", 0)) > 0:
		w += BORD_GAT + BORD
		h = maxf(h, BORD)
	var kommen: Array = q.get("kommen", [])
	var los := int(q.get("los", 0))
	if not kommen.is_empty() or los > 0:
		var kw := float(kommen.size()) * KOM + maxf(0.0, float(kommen.size()) - 1.0) * KOM_GAT
		if los > 0:
			kw += EI_GAT + float(los)
		w = maxf(w, kw)
		h = maxf(h, KOM)
	return Vector2(maxf(w, 1.0), maxf(h, 1.0))

func _cel() -> float:
	var c := cellen(p)
	return minf(size.x / c.x, size.y / c.y)

func _draw() -> void:
	if size.x < 16.0 or size.y < 16.0:
		return
	var cel := _cel()
	var heel := Rect2(Vector2.ZERO, size)
	# a soft shadow and the table top with its darker edge
	draw_style_box(_vlak(KL_SCHADUW, cel * 0.5), heel.grow_individual(0, 0, 0, cel * 0.12))
	draw_style_box(_vlak(KL_TAFEL_D, cel * 0.45), heel)
	draw_style_box(_vlak(KL_TAFEL, cel * 0.4), heel.grow_individual(0, 0, 0, -cel * 0.14))
	var inhoud := _inhoud(p) * cel
	var o := (size - inhoud) * 0.5
	var plaat := _plaat_maat(p) * cel
	if plaat.x > 0.0:
		var vak := Rect2(Vector2(o.x, o.y + (inhoud.y - plaat.y) * 0.5), plaat)
		if bool(p.get("oven", false)):
			_teken_oven(vak, cel)
			vak = Rect2(vak.position + Vector2(ZIJ, BOOG) * cel,
				vak.size - Vector2(2.0 * ZIJ, BOOG + ZIJ) * cel)
		_teken_plaat(vak, cel)
		if int(p.get("rest", 0)) > 0:
			var b := Rect2(Vector2(vak.end.x + BORD_GAT * cel, o.y + (inhoud.y - BORD * cel) * 0.5),
				Vector2(BORD, BORD) * cel)
			_teken_bord(b, cel, int(p["rest"]))
	var kommen: Array = p.get("kommen", [])
	var los := int(p.get("los", 0))
	if not kommen.is_empty() or los > 0:
		var x := o.x
		var y := o.y + (inhoud.y - KOM * cel) * 0.5
		for n in kommen:
			_teken_kom(Rect2(Vector2(x, y), Vector2(KOM, KOM) * cel), cel, int(n),
				bool(p.get("beslag", false)))
			x += (KOM + KOM_GAT) * cel
		if los > 0:
			x += (EI_GAT - KOM_GAT) * cel if not kommen.is_empty() else 0.0
			for i in los:
				_teken_ei(Vector2(x + (float(i) + 0.5) * cel, y + KOM * cel * 0.5), cel)

## The tray: a rim, the metal, and the cookies in rows (row 0 at the top).
func _teken_plaat(vak: Rect2, cel: float) -> void:
	draw_style_box(_vlak(KL_PLAAT_L, cel * 0.25), vak)
	draw_style_box(_vlak(KL_PLAAT, cel * 0.18), vak.grow(-cel * RIM * 0.55))
	var rijen := int(p.get("rijen", 0))
	var kolommen := int(p.get("kolommen", 0))
	var aantal := clampi(int(p.get("aantal", rijen * kolommen)), 0, rijen * kolommen)
	var gaar := bool(p.get("gaar", false))
	var start := vak.position + Vector2(RIM, RIM) * cel
	for i in aantal:
		@warning_ignore("integer_division")
		var r := i / kolommen
		var k := i % kolommen
		_teken_koekje(start + Vector2(float(k) + 0.5, float(r) + 0.5) * cel, cel, gaar)

## One cookie: dough is a pale ball with a highlight; baked it is golden with
## a darker rim and three chips of chocolate.
func _teken_koekje(m: Vector2, cel: float, gaar: bool) -> void:
	var r := cel * 0.38
	if gaar:
		draw_circle(m, r, KL_KOEK_D)
		draw_circle(m, r * 0.82, KL_KOEK)
		for d in [Vector2(-0.12, -0.1), Vector2(0.14, -0.02), Vector2(-0.02, 0.15)]:
			draw_circle(m + d * cel, cel * 0.055, KL_CHOCO)
	else:
		draw_circle(m, r, KL_DEEG_D)
		draw_circle(m - Vector2(r, r) * 0.08, r * 0.86, KL_DEEG)
		draw_circle(m - Vector2(r, r) * 0.32, r * 0.28, KL_DEEG_L)

## A bowl seen from above with its eggs in rows of four, or full of batter.
func _teken_kom(vak: Rect2, cel: float, n: int, beslag: bool) -> void:
	var m := vak.get_center()
	var straal := vak.size.x * 0.5
	draw_circle(m + Vector2(0, cel * 0.12), straal, KL_SCHADUW)
	draw_circle(m, straal, KL_KOM)
	draw_circle(m, straal - cel * 0.4, KL_BESLAG if beslag else KL_KOM_L)
	if beslag:
		for i in 3:
			draw_arc(m, straal * (0.25 + 0.2 * i), 0.4 + i, 2.4 + i, 12, KL_BESLAG_L,
				maxf(2.0, cel * 0.12))
		return
	@warning_ignore("integer_division")
	var rijen := (n + 3) / 4
	for i in n:
		@warning_ignore("integer_division")
		var rij := i / 4
		var k := i % 4
		var in_rij := mini(4, n - rij * 4)
		var x := m.x + (float(k) - (float(in_rij) - 1.0) * 0.5) * cel
		var y := m.y + (float(rij) - (float(rijen) - 1.0) * 0.5) * cel
		_teken_ei(Vector2(x, y), cel)

## One egg: an upright oval with a soft edge.
func _teken_ei(m: Vector2, cel: float) -> void:
	var rx := cel * 0.32
	var ry := cel * 0.42
	draw_colored_polygon(_ovaal(m, rx, ry), KL_EI_D)
	draw_colored_polygon(_ovaal(m - Vector2(0, cel * 0.03), rx * 0.86, ry * 0.88), KL_EI)

## The plate with the rest for the cook, three by three.
func _teken_bord(vak: Rect2, cel: float, n: int) -> void:
	var m := vak.get_center()
	draw_circle(m, vak.size.x * 0.5, KL_BORD_D)
	draw_circle(m, vak.size.x * 0.5 - cel * 0.12, KL_BORD)
	var stap := cel * 0.95
	for i in mini(n, 9):
		@warning_ignore("integer_division")
		var r := i / 3
		var k := i % 3
		_teken_koekje(m + Vector2(float(k) - 1.0, float(r) - 1.0) * stap, cel * 0.9, true)

## The mouth of the oven round the tray while it bakes: stone, a dark arch and
## the fire glowing under the tray.
func _teken_oven(vak: Rect2, cel: float) -> void:
	draw_style_box(_vlak(KL_STEEN, cel * 0.5), vak)
	var mond := Rect2(vak.position + Vector2(ZIJ, ZIJ) * cel * 0.6,
		vak.size - Vector2(2.0 * ZIJ, ZIJ) * cel * 0.6)
	var s := _vlak(KL_MOND, cel * 0.3)
	s.corner_radius_top_left = int(minf(mond.size.x, mond.size.y) * 0.5)
	s.corner_radius_top_right = int(minf(mond.size.x, mond.size.y) * 0.5)
	draw_style_box(s, mond)
	var vuur := Rect2(Vector2(mond.position.x + cel * 0.3, mond.end.y - cel * 0.55),
		Vector2(mond.size.x - cel * 0.6, cel * 0.4))
	draw_style_box(_vlak(KL_GLOED, cel * 0.2), vuur)
	draw_style_box(_vlak(KL_VUUR, cel * 0.15), vuur.grow(-cel * 0.1))

static func _ovaal(m: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var punten := PackedVector2Array()
	for i in 20:
		var hoek := TAU * float(i) / 20.0
		punten.append(m + Vector2(cos(hoek) * rx, sin(hoek) * ry))
	return punten

func _vlak(kl: Color, hoek: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = kl
	s.set_corner_radius_all(int(hoek))
	s.anti_aliasing = true
	return s
