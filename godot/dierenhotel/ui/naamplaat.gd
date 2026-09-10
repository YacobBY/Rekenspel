class_name UiNaamplaat
extends Label
## The name plate above a guest (world.md §2.10, art-sound-rules.md §16.10).
##
## It lives in `Naamlaag`, above the world and under the buttons, is never
## clickable, and its letters stay on the 12 px floor.
##
## Since I1 it is a hotspot of kind `naam`: `Hits` puts it against the top of
## the guest's own drawn rectangle and RESERVES the cells it takes, so a button
## can no longer end up underneath it (finding 3) and two plates cannot share a
## place.  The plate therefore has no placement code of its own any more.

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
