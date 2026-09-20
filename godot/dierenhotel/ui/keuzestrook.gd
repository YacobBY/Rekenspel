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
var _knopen: Array[Button] = []
var op_slot := false

## Lock the strip for the length of a miss (S5).  Every button goes grey and
## deaf: a tap during the pause does nothing at all — no sound, no callback,
## no second answer.  `disabled` alone is not enough, because a test (and a
## scripted game) can fire `pressed` on a disabled button and the signal
## still arrives; the flag is what actually stops it.
func slot(aan: bool) -> void:
	op_slot = aan
	for b in _knopen:
		if not is_instance_valid(b):
			continue
		b.disabled = aan
		b.modulate = Color(1, 1, 1, 0.45) if aan else Color(1, 1, 1, 1)

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

# ------------------------------------------------------------------ slepen

## The strip is glued under the card and catches the finger, so a drop that
## lands on it dies there (Z1).  It hands the drop on to the catch area
## underneath it, like every hotspot Control does.
func _can_drop_data(at: Vector2, lading: Variant) -> bool:
	return Hits.vang_onder(get_global_position() + at, lading) != null

## In the TARGET's own coordinates, never the strip's `at`.
func _drop_data(at: Vector2, lading: Variant) -> void:
	var punt := get_global_position() + at
	var v := Hits.vang_onder(punt, lading)
	if v != null:
		v._drop_data(punt - v.get_global_position(), lading)

func _vul(rij: HBoxContainer, keuzes: Array, kort: bool, mt: Dictionary) -> void:
	_knopen.clear()
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
				if op_slot:
					return
				Snd.tik()
				Ui.roep(kies, [id, _kaart]))
		rij.add_child(b)
		_knopen.append(b)
	if op_slot:
		# a strip rebuilt while locked stays locked
		slot(true)
