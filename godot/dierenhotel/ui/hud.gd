class_name UiHud
extends HFlowContainer
## The chrome row: day, coins, stars, letters, sound, the round name and the two
## round buttons (world.md §3.8 and §7.1, architecture.md §5).
##
## `Hotel.hud()` writes five numbers and nothing else; this Control owns the
## wording and reads the numbers straight from `State`, so W2 never has to know
## a node path.  It wraps to a second row rather than letting a button fall
## under 48 units (art-sound-rules.md §16.4).

var dag_badge: Label
var munt_badge: Button
var ster_badge: Label
var brief_badge: Button
var geluid_knop: Button
var ronde_label: Label
var prikbord_knop: Button
var avond_knop: Button
var logo: Label

## Safe to call again: the breakpoint moved and every label wants a new size.
func bouw(mt: Dictionary) -> void:
	for k in get_children():
		remove_child(k)
		k.queue_free()
	name = "Chroom"
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 4)

	logo = Label.new()
	logo.name = "Logo"
	logo.theme_type_variation = "Logo"
	logo.text = UiTekst.LOGO
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", mt["logo"])
	add_child(logo)

	dag_badge = _plaatje("Dag", "%s 1" % UiTekst.DAG, UiTekst.DAG_TITEL, mt)
	munt_badge = _badge("Munt", "💰 0", UiTekst.MUNT_TITEL, mt)
	ster_badge = _plaatje("Ster", "⭐ 0", UiTekst.STER_TITEL, mt)
	brief_badge = _badge("Brieven", "💌 0", UiTekst.BRIEVEN_TITEL, mt)
	geluid_knop = _badge("Geluid", UiTekst.GELUID_AAN, UiTekst.GELUID_TITEL, mt)
	geluid_knop.set_meta("uitleg", UiTekst.GELUID_UITLEG)

	ronde_label = Label.new()
	ronde_label.name = "Ronde"
	ronde_label.theme_type_variation = "Ronde"
	ronde_label.text = UiTekst.RONDE_OCHTEND
	ronde_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ronde_label.add_theme_font_size_override("font_size", mt["ronde"])
	ronde_label.add_theme_stylebox_override("normal",
		UiThema.vulling(UiThema.vlak(UiThema.ZON, 999, 0), 12, 5))
	add_child(ronde_label)

	prikbord_knop = _knop("Prikbord", UiTekst.PRIKBORD, mt)
	avond_knop = _knop("Avond", UiTekst.AVOND, mt)
	ververs()

## A badge that opens something is a real button, so it is a real tap target
## (48 x 48).  A badge that only shows a number is a Label and keeps the 38 unit
## chrome height — it is not a target and must not pretend to be one
## (art-sound-rules.md §16.4, world.md §7.1).
func _badge(naam: String, tekst: String, titel: String, mt: Dictionary) -> Button:
	var b := Button.new()
	b.name = naam
	b.theme_type_variation = "Badge"
	b.text = tekst
	b.tooltip_text = titel
	b.clip_text = false
	b.add_theme_font_size_override("font_size", mt["badge"])
	b.custom_minimum_size = Vector2(UiThema.HOT, UiThema.HOT)
	b.focus_mode = Control.FOCUS_ALL
	add_child(b)
	return b

func _plaatje(naam: String, tekst: String, titel: String, mt: Dictionary) -> Label:
	var l := Label.new()
	l.name = naam
	l.text = tekst
	l.tooltip_text = titel
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", mt["badge"])
	l.add_theme_color_override("font_color", UiThema.INKT)
	l.add_theme_stylebox_override("normal",
		UiThema.vulling(UiThema.vlak(UiThema.KAART, 999, 2, UiThema.WIT), 9, 4))
	l.custom_minimum_size = Vector2(0, 38)
	add_child(l)
	return l

func _knop(naam: String, tekst: String, mt: Dictionary) -> Button:
	var b := Button.new()
	b.name = naam
	b.text = tekst
	b.tooltip_text = tekst
	b.clip_text = false
	b.custom_minimum_size = Vector2(0, UiThema.HOT)
	b.add_theme_font_size_override("font_size", mt["knop"])
	add_child(b)
	return b

## The five numbers of world.md §3.8, plus the round name.
func ververs() -> void:
	var s: Dictionary = State.s
	dag_badge.text = "%s %d" % [UiTekst.DAG, int(s.get("dag", 1))]
	munt_badge.text = "💰 %d" % int(s.get("munten", 0))
	ster_badge.text = "⭐ %d" % int(s.get("sterren", 0))
	brief_badge.text = "💌 %d" % (s.get("brieven", []) as Array).size()
	geluid_knop.text = UiTekst.GELUID_AAN if bool(s.get("geluid", true)) else UiTekst.GELUID_UIT
	match str(s.get("ronde", "ochtend")):
		"avond": ronde_label.text = UiTekst.RONDE_AVOND
		"vrij": ronde_label.text = UiTekst.RONDE_VRIJ
		_: ronde_label.text = UiTekst.RONDE_OCHTEND

## The compact landscape shell hides the title — it is decoration, not a button.
func zet_compact(compact: bool) -> void:
	logo.visible = not compact
