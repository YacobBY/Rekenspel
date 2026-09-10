class_name UiKeuzes
extends PanelContainer
## One strip of answer buttons, glued under the card.
##
## Pictogram AND word, always (HOTEL.md §9 / F4): never a lone pictogram.  The
## short word (`kort`) is taken when the long strip does not fit the frame —
## decided synchronously with `get_combined_minimum_size()` BEFORE the first
## draw, which is what removes `strookNakijken()` and the per-game width
## thresholds of the HTML (architecture.md §4.4).

var kort_gekozen := false
var _kaart: RefCounted = null      ## the Ui.Kaart handle, second argument of `kies`

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func bouw(keuzes: Array, kader_breed: float, mt: Dictionary, titel := "", kaart: RefCounted = null) -> void:
	tooltip_text = titel
	_kaart = kaart
	var sb := UiThema.vulling(UiThema.vlak(UiThema.KAART, 16, 2, UiThema.WIT), 5, 4)
	add_theme_stylebox_override("panel", sb)
	var rij := HBoxContainer.new()
	rij.name = "Rij"
	rij.add_theme_constant_override("separation", 4)
	add_child(rij)
	_vul(rij, keuzes, false, mt)
	if kader_breed > 0.0 and get_combined_minimum_size().x + 8.0 > kader_breed:
		for k in rij.get_children():
			rij.remove_child(k)
			k.queue_free()
		kort_gekozen = true
		_vul(rij, keuzes, true, mt)

func _vul(rij: HBoxContainer, keuzes: Array, kort: bool, mt: Dictionary) -> void:
	for keuze in keuzes:
		var woord: String = str(keuze.get("kort", keuze.get("tekst", ""))) if kort \
			else str(keuze.get("tekst", ""))
		var icoon := str(keuze.get("icoon", ""))
		var b := Button.new()
		b.name = "K" + str(keuze.get("id", woord))
		b.theme_type_variation = "Keuzeknop"
		b.text = ("%s %s" % [icoon, woord]).strip_edges()
		b.tooltip_text = str(keuze.get("titel", woord))
		b.custom_minimum_size = Vector2(UiThema.HOT, UiThema.HOT)
		b.add_theme_font_size_override("font_size", mt["klein"])
		b.clip_text = false
		var kies: Callable = keuze.get("kies", Callable())
		var id := str(keuze.get("id", ""))
		if kies.is_valid():
			b.pressed.connect(func() -> void:
				Snd.tik()
				Ui.roep(kies, [id, _kaart]))
		rij.add_child(b)
