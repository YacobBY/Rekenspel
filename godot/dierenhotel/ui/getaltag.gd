class_name UiGetalTag
extends Label
## `World.getalTag(obj, n, o)` — a bare number ON an object (world.md §5.6).
##
## HOTEL.md §9: "numbers on objects" — the bowl shows its count on the bowl, a
## hook its number, the counter its amount.  It is not clickable and not
## focusable (`aria-hidden` in the HTML), so a finger always reaches the object
## or the real button behind it, and `Hits` lets it cover at most a tenth of its
## own object (`TAG_IN`).

func bouw(o: Dictionary, mt: Dictionary) -> void:
	text = str(o.get("getal", o.get("tekst", "")))
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	add_theme_font_size_override("font_size", maxi(UiThema.VLOER, mt["klein"]))
	add_theme_color_override("font_color", UiThema.INKT)
	add_theme_stylebox_override("normal",
		UiThema.vulling(UiThema.vlak(UiThema.ZON, 999, 2, UiThema.WIT), 7, 1))
	tooltip_text = str(o.get("titel", ""))

func zet(n: Variant) -> void:
	text = "" if n == null else str(n)
