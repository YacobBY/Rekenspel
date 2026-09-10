class_name UiPlattegrond
extends GridContainer
## The map sheet (world.md §6.3/§7.3): a 4 × 3 grid of rooms.
##
## The grid positions are the hotel's floor plan, not a list — the child learns
## where the kitchen is relative to the garden, which is why the empty cells
## stay empty instead of the rooms closing ranks.

signal kamer_gekozen(kamer: String)

## `kamer id -> [kolom, rij]`, one-based, exactly the KAART table of §6.3.
const KAART := {
	"receptie": [1, 2], "gang": [2, 2], "kamer1": [2, 1], "kamer2": [2, 3],
	"keuken": [3, 2], "tuin": [4, 2], "wasserij": [3, 3], "zwembad": [4, 3],
}
const KOLOMMEN := 4
const RIJEN := 3
const CEL := 48

func bouw(mt: Dictionary) -> void:
	name = "Plattegrond"
	columns = KOLOMMEN
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 6)
	# Rooms without a place in the table (the skeleton's proefkamer, and any
	# room a later run adds) are appended after the plan instead of vanishing.
	var raster: Dictionary = {}
	var rest: Array[String] = []
	for id in Rooms.lijst():
		if KAART.has(id):
			var p: Array = KAART[id]
			raster["%d|%d" % [int(p[1]), int(p[0])]] = id
		else:
			rest.append(id)
	for rij in range(1, RIJEN + 1):
		for kol in range(1, KOLOMMEN + 1):
			var id: String = raster.get("%d|%d" % [rij, kol], "")
			if id == "" and not rest.is_empty():
				id = rest.pop_front()
			add_child(_cel(id, mt))

func _cel(id: String, mt: Dictionary) -> Control:
	if id == "":
		var leeg := Control.new()
		leeg.custom_minimum_size = Vector2(CEL, CEL)
		leeg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return leeg
	var r := Rooms.get_kamer(id)
	var b := Button.new()
	b.name = "P" + id
	b.theme_type_variation = "Kamerchip"
	b.custom_minimum_size = Vector2(CEL + 20, CEL)
	b.tooltip_text = UiTekst.ga_naar(r.naam)
	b.clip_text = false
	var kolom := VBoxContainer.new()
	kolom.name = "Kolom"
	kolom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kolom.set_anchors_preset(Control.PRESET_FULL_RECT)
	kolom.add_theme_constant_override("separation", 0)
	kolom.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(kolom)
	for stuk in [[r.icoon, mt["icoon"]], [r.naam, maxi(UiThema.VLOER, mt["klein"])]]:
		var l := Label.new()
		l.text = str(stuk[0])
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", int(stuk[1]))
		l.add_theme_color_override("font_color", UiThema.INKT)
		kolom.add_child(l)
	var n := 0
	if Hotel.has_method("wacht_in"):
		n = int(Hotel.call("wacht_in", id))
	if n > 0:
		var bdg := Label.new()
		bdg.name = "Wacht"
		bdg.text = str(n)
		bdg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bdg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bdg.add_theme_font_size_override("font_size", UiThema.VLOER)
		bdg.add_theme_color_override("font_color", UiThema.INKT)
		bdg.add_theme_stylebox_override("normal",
			UiThema.vulling(UiThema.vlak(UiThema.PERZIK, 999, 2, UiThema.WIT), 4, 0))
		kolom.add_child(bdg)
	b.pressed.connect(func() -> void:
		Snd.tik()
		kamer_gekozen.emit(id))
	return b

## The cells can only be measured once the theme is resolved, i.e. once they
## are in the tree; every cell keeps its 48 unit floor whatever it measures.
func _ready() -> void:
	for cel in get_children():
		var kolom: Control = cel.get_node_or_null("Kolom")
		if kolom == null:
			continue
		var nodig := kolom.get_combined_minimum_size()
		cel.custom_minimum_size = Vector2(maxf(CEL + 20.0, nodig.x + 8.0),
			maxf(CEL, nodig.y + 6.0))
