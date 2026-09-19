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
## True while this strip docks in the maths bar (`B4`): no panel of its own,
## the bar's paper is behind it, and the buttons take their size from the bar
## table instead of the little chrome one.
var in_balk := false
var _balk := {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func bouw(keuzes: Array, kader_breed: float, mt: Dictionary, titel := "", kaart: RefCounted = null,
		balk: bool = false) -> void:
	tooltip_text = titel
	_kaart = kaart
	in_balk = balk
	_balk = UiThema.balk_maten(World.kader_rect().size) if in_balk else {}
	if in_balk:
		var kaal := StyleBoxFlat.new()
		kaal.bg_color = Color(0, 0, 0, 0)
		add_theme_stylebox_override("panel", kaal)
	else:
		var sb := UiThema.vulling(UiThema.vlak(UiThema.KAART, 16, 2, UiThema.WIT), 5, 4)
		add_theme_stylebox_override("panel", sb)
	var rij := HBoxContainer.new()
	rij.name = "Rij"
	rij.add_theme_constant_override("separation", 6 if in_balk else 4)
	add_child(rij)
	# In the bar the compact wording is the default: the bar is narrow and the
	# long word would push the strip out of its block.
	_vul(rij, keuzes, in_balk, mt)
	# The width the short-word choice is measured against: the whole bar in
	# `hoog`, the right-hand block in `laag` — never the whole frame (B4).
	var meet := kader_breed
	if in_balk:
		var b := Ui.balk_rect()
		meet = b.size.x
		if str(_balk.get("vorm", "hoog")) == "laag":
			meet = b.size.x * (1.0 - UiThema.BALK_LAAG_LINKS) - 12.0
	if meet > 0.0 and get_combined_minimum_size().x + 8.0 > meet:
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
	# In the bar the buttons wear their own stylebox set.  The `Keuzeknop`
	# variation carries 8 units of content margin on each side, and an
	# explicit stylebox margin beats a control-level `content_margin_*`
	# override, so trimming the constant does nothing.  In `laag` the row
	# lives in the narrow right-hand block beside the card: a money strip of
	# four "🪙 €10" buttons is 306 units wide at the 8 unit padding and cuts
	# into the card; at 2 units it is 274 and clears it.
	var stijlen := _balk_stijlen(2) if in_balk and str(_balk.get("vorm", "hoog")) == "laag" \
		else (_balk_stijlen(6) if in_balk else {})
	for keuze in keuzes:
		var woord: String = str(keuze.get("kort", keuze.get("tekst", ""))) if kort \
			else str(keuze.get("tekst", ""))
		var icoon := str(icoon_van(keuze))
		var b := Button.new()
		b.name = "K" + str(keuze.get("id", woord))
		b.theme_type_variation = "Keuzeknop"
		b.text = ("%s %s" % [icoon, woord]).strip_edges()
		b.tooltip_text = str(keuze.get("titel", woord))
		if in_balk:
			# The bar's own button size: never under the tap floor, and the
			# width and height come straight from the table (B4).
			b.custom_minimum_size = Vector2(float(_balk["knop_breed"]), float(_balk["knop_hoog"]))
			b.add_theme_font_size_override("font_size", int(_balk["knop"]))
			for toestand in stijlen:
				b.add_theme_stylebox_override(toestand, stijlen[toestand])
		else:
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

## The bar's own button stylebox set: the `Keuzeknop` look with a small
## content margin, so a wide money strip stays inside its block.  The hover
## and pressed tints are the theme's own, rebuilt here because the margin has
## to travel with the box that carries it.
static func _balk_stijlen(rand: int) -> Dictionary:
	var basis := UiThema.vulling(UiThema.vlak(UiThema.KAART, 14, 2, UiThema.WIT), rand, rand)
	var over := basis.duplicate() as StyleBoxFlat
	over.bg_color = over.bg_color.lerp(UiThema.ZON, 0.35)
	var druk := basis.duplicate() as StyleBoxFlat
	druk.bg_color = druk.bg_color.lerp(UiThema.PERZIK, 0.55)
	druk.content_margin_top = basis.content_margin_top + 2
	druk.content_margin_bottom = maxf(0.0, basis.content_margin_bottom - 2)
	return {
		"normal": basis,
		"hover": over,
		"pressed": druk,
		"hover_pressed": druk,
		"focus": UiThema.vlak(Color(0, 0, 0, 0), 14, 2, UiThema.PERZIK_D),
	}

static func icoon_van(keuze) -> String:
	return str(keuze.get("icoon", ""))
