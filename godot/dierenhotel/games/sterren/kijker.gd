class_name SterrenKijker
extends Control
## The patch of night sky the telescope looks at, LARGE and flat while Sterren
## tellen runs — the way `SpiegelBord` brings the mask forward.  The stars in
## the sky over the deck are small; this draws the same dot patterns big
## enough to see the structure (a dice face, a ten-frame, rows, blocks of ten
## and a hundred) with the maths bar docked.
##
## Not a button: a tap goes through it.  `Hits` puts it down and clears it like
## every element of the game (`kind: "eigen"`); its size it asks the game at
## every placement (`meet`).

const KL_LUCHT := Color("#14213D")
const KL_RAND := Color("#3A4A7A")
const KL_STER := Color("#FFE27A")
const KL_STER_L := Color("#FFF8D6")
const KL_HONDERD := Color("#9AD0FF")
const KL_SCHADUW := Color(0.0, 0.0, 0.0, 0.25)

var meet: Callable = Callable()
var _patronen: Array = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(240, 150)

## The patterns of the turn (`Beurt.maak(...)["patronen"]`).
func zet(patronen: Array) -> void:
	_patronen = patronen.duplicate(true)
	if meet.is_valid():
		var m: Variant = meet.call()
		if m is Vector2:
			custom_minimum_size = m
			size = m
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(r.position + Vector2(-2.0, 1.0), r.size + Vector2(4.0, 4.0)), KL_SCHADUW)
	draw_rect(r, KL_LUCHT)
	draw_rect(r, KL_RAND, false, 2.0)
	if _patronen.is_empty():
		return
	# every pattern gets an equal column; the dot size follows the widest grid
	var n := _patronen.size()
	var kolom := (size.x - 16.0) / float(n)
	var breed_max := 1
	var hoog_max := 1
	for p in _patronen:
		var pd: Dictionary = p
		breed_max = maxi(breed_max, int(pd.get("breed", 5)))
		for c in pd.get("cellen", []):
			hoog_max = maxi(hoog_max, int((c as Vector2i).y) + 1)
	var cel := minf((kolom - 8.0) / float(breed_max), (size.y - 16.0) / float(hoog_max))
	var straal := maxf(2.0, cel * 0.32)
	for i in n:
		var pd: Dictionary = _patronen[i]
		var breed := int(pd.get("breed", 5))
		var x0 := 8.0 + kolom * float(i) + (kolom - cel * float(breed)) * 0.5
		var y0 := 8.0 + (size.y - 16.0 - cel * float(hoog_max)) * 0.5
		var kl := KL_HONDERD if str(pd.get("vorm", "")) == "honderd" else KL_STER
		for c in pd.get("cellen", []):
			var v: Vector2i = c
			var m := Vector2(x0 + (float(v.x) + 0.5) * cel, y0 + (float(v.y) + 0.5) * cel)
			draw_circle(m, straal, kl)
			draw_circle(m - Vector2(straal * 0.3, straal * 0.3), straal * 0.35, KL_STER_L)
