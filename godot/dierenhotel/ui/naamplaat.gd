class_name UiNaamplaat
extends Label
## The name plate above a guest (world.md §2.10, art-sound-rules.md §16.10).
##
## It lives in `Naamlaag`, above the world and under the buttons, is never
## clickable, and its letters stay on the 12 px floor.  `World` gives it the
## point; the plate is drawn centred on it and 100 % above it.

const MIJD_X := 62.0     ## another plate counts as a hit within this distance
const MIJD_Y := 24.0
const OMHOOG := 26.0     ## and then this plate moves up
const POGINGEN := 6

func bouw(naam: String, mt: Dictionary) -> void:
	text = naam
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", maxi(UiThema.VLOER, mt["klein"]))
	add_theme_color_override("font_color", Color("#5A4A3E"))
	add_theme_stylebox_override("normal",
		UiThema.vulling(UiThema.vlak(Color("#FFFDF6"), 999, 2, UiThema.WIT), 9, 1))

## Put the plate over `punt` (frame units), stepping up while it would land on
## a plate that is already placed.
func plaats(punt: Vector2, bezet: Array[Rect2]) -> Rect2:
	var maat := get_combined_minimum_size()
	size = maat
	var y := punt.y - maat.y
	for _poging in POGINGEN:
		var botst := false
		for r in bezet:
			if absf(r.get_center().x - punt.x) < MIJD_X and absf(r.get_center().y - (y + maat.y * 0.5)) < MIJD_Y:
				botst = true
				break
		if not botst:
			break
		y -= OMHOOG
	position = Vector2(punt.x - maat.x * 0.5, y)
	return Rect2(position, maat)
