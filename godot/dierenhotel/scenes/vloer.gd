extends Node2D
## Placeholder floor + walls, drawn straight to the canvas.
## W1/W4: bake this into ONE plate (floor tiles in 4x4 blocks, both back walls,
## the skirting, the rail, the door holes and the vignette) — world.md §1.4.

const HOUT := [Color("#E4CBA6"), Color("#DCC29B")]
const HOUT_D := Color("#D2B58C")
const WAND_Z := Color("#DFC6A8")
const WAND_X := Color("#EDD8BC")
const RAND_Z := Color("#E9D4BA")
const RAND_X := Color("#F5E5CE")
const PLINT := Color("#C08F6B")

func _draw() -> void:
	var r := Rooms.get_kamer(World.kamer_nu())
	if r == null:
		return
	for x in range(0, r.w, 4):
		for z in range(0, r.d, 4):
			var kl: Color = HOUT_D if ((z >> 2) & 3) == 0 else HOUT[(z >> 2) & 1]
			draw_colored_polygon(PackedVector2Array([
				World.scherm(x, z), World.scherm(x + 4, z),
				World.scherm(x + 4, z + 4), World.scherm(x, z + 4)]), kl)
	_wand_z(r)
	_wand_x(r)

func _wand_z(r: Rooms.Kamer) -> void:
	var h := r.wand
	draw_colored_polygon(PackedVector2Array([
		World.scherm(0, 0, 0), World.scherm(r.w, 0, 0),
		World.scherm(r.w, 0, h), World.scherm(0, 0, h)]), WAND_Z)
	draw_colored_polygon(PackedVector2Array([
		World.scherm(0, 0, 9), World.scherm(r.w, 0, 9),
		World.scherm(r.w, 0, 10.4), World.scherm(0, 0, 10.4)]), RAND_Z)
	draw_colored_polygon(PackedVector2Array([
		World.scherm(0, 0, 0), World.scherm(r.w, 0, 0),
		World.scherm(r.w, 0, 3), World.scherm(0, 0, 3)]), PLINT)

func _wand_x(r: Rooms.Kamer) -> void:
	var h := r.wand
	draw_colored_polygon(PackedVector2Array([
		World.scherm(0, 0, 0), World.scherm(0, r.d, 0),
		World.scherm(0, r.d, h), World.scherm(0, 0, h)]), WAND_X)
	draw_colored_polygon(PackedVector2Array([
		World.scherm(0, 0, 9), World.scherm(0, r.d, 9),
		World.scherm(0, r.d, 10.4), World.scherm(0, 0, 10.4)]), RAND_X)
	draw_colored_polygon(PackedVector2Array([
		World.scherm(0, 0, 0), World.scherm(0, r.d, 0),
		World.scherm(0, r.d, 3), World.scherm(0, 0, 3)]), PLINT)
