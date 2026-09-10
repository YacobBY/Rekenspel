class_name UiKeypad
extends PanelContainer
## The keypad band — the only permitted 2-D element (HOTEL.md §9).
##
## architecture.md §4.4/§4.5 replaced `padPlek` entirely: there is no
## `binnen`/`buiten` switch, no 300/340 unit dead zone and no switch counter,
## because the frame is no longer capped by a CSS aspect ratio and the camera
## already keeps `KADER_ONDER = 132` units free under the room.  The band docks
## to the bottom of the world frame and its shape is decided ONCE, from the
## frame rectangle, before the first draw.
##
## Key order is unchanged: `1 2 3 4 5 ⌫ 6 7 8 9 0 ✓`.

signal toets_getikt(teken: String)

const TOETSEN := ["1", "2", "3", "4", "5", "⌫", "6", "7", "8", "9", "0", "✓"]
const WIS := "⌫"
const OK := "✓"
const GAT := 4           ## air between two keys
const RAND := 3          ## the band's own padding

## Which shape fits this frame (architecture.md §4.5, worked out for the
## smallest legal frame).  Returns {kolommen, toets, breed, hoog}.
##
## `tap` is the key size the screen allows (48, or 44 below a 360 px screen);
## it defaults to whatever `Ui` measured.  The frame only decides the SHAPE.
static func vorm(kader: Vector2, tap := 0) -> Dictionary:
	var t: int = tap if tap > 0 else Ui.tap_maat()
	var kolommen := 6
	if kader.x >= 660.0:
		kolommen = 12
	elif kader.y < 450.0:
		# A low frame has room for exactly one band: 12 keys in one row.  That
		# needs 620 units at 48 px keys and 572 at 44 px; under 572 the strip
		# wraps to two rows and the room loses 52 units instead.
		if kader.x >= 620.0:
			kolommen = 12
		elif kader.x >= 572.0:
			kolommen = 12
			t = UiThema.HOT_KRAP
	var rijen := 12 / kolommen
	return {
		"kolommen": kolommen, "toets": t,
		"breed": kolommen * t + (kolommen - 1) * GAT + 2 * RAND,
		"hoog": rijen * t + (rijen - 1) * GAT + 2 * RAND,
	}

var _vorm := {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Cijfers"

func bouw(kader: Vector2, mt: Dictionary) -> void:
	_vorm = vorm(kader)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiThema.KAART
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = UiThema.WIT
	sb.content_margin_left = RAND
	sb.content_margin_right = RAND
	sb.content_margin_top = RAND
	sb.content_margin_bottom = RAND
	add_theme_stylebox_override("panel", sb)
	var raster := GridContainer.new()
	raster.name = "Toetsen"
	raster.columns = _vorm["kolommen"]
	raster.add_theme_constant_override("h_separation", GAT)
	raster.add_theme_constant_override("v_separation", GAT)
	add_child(raster)
	var maat: int = _vorm["toets"]
	var lettermaat: int = mt["toets"] if maat >= UiThema.HOT else maxi(UiThema.VLOER, mt["toets"] - 2)
	for teken in TOETSEN:
		var k := Button.new()
		k.name = "T" + ("wis" if teken == WIS else ("ok" if teken == OK else teken))
		k.theme_type_variation = "Padtoets"
		k.text = teken
		k.custom_minimum_size = Vector2(maat, maat)
		k.add_theme_font_size_override("font_size", lettermaat)
		k.focus_mode = Control.FOCUS_ALL
		k.tooltip_text = "wissen" if teken == WIS else ("klaar" if teken == OK else teken)
		k.pressed.connect(func() -> void:
			Snd.tik()
			toets_getikt.emit(teken))
		raster.add_child(k)

func toets_maat() -> int:
	return int(_vorm.get("toets", UiThema.HOT))

func kolommen() -> int:
	return int(_vorm.get("kolommen", 6))
