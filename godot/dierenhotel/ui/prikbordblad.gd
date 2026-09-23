class_name UiPrikbordBlad
extends Control
## The prikbord seen up close (world.md §3.7): today's task cards pinned on a
## piece of cork, each saying what to do AND where.
##
## OWNER, 2026-09-23: "Plaatjes als [de receptie met het open bord] zijn veel te
## druk in iconen. en wekker zetten is bijvoorbeeld helemaal niet relevant aan
## waar de tekst geplaatst is".  The cards used to hang as bubbles in the
## receptie, round the little board on the wall, and wherever the band grid had
## room: "⏰ Wekker zetten" stood on the floor by the corridor door, as if that
## door were the alarm clock.  A card belongs to a room somewhere else in the
## hotel, so no place in the receptie is its right place.  On the sheet it is
## the board that carries them, and every card names its room.
##
## Laid out by hand, like the map (`ui/plattegrond.gd`): a `Button` is not a
## `Container`, and the sheet measures its content before the first layout
## pass, so every note and every label gets its `position` and `size` here and
## the whole board reports itself as this control's minimum size.

signal taak_gekozen(q: Dictionary)
signal leeg_getikt()

const RAND := 12.0        ## the cork round the notes
const GAT := 10.0         ## between two notes
const VULLING_X := 12.0   ## inside a note
const VULLING_Y := 8.0
const ICOON_GAT := 10.0   ## between the pictogram and the words
const REGEL_GAT := 2.0    ## between the task and the room under it
const SPELD := 5.0        ## the pin at the top of every note
const LEEG_BREED := 320.0 ## an empty board is not stretched over the sheet
## Below this screen height the notes stand side by side: under each other the
## board is taller than a phone held sideways, and the third card and
## `Sluiten` were only reached by scrolling.
const LAAG_SCHERM := 450.0
## Paper in three soft colours, one per place on the board, so the three cards
## read as three separate notes and not as one list.
const PAPIER := [Color("#FFF3C4"), Color("#FFE4EC"), Color("#DDF4EA")]
const SPELD_KLEUR := [Color("#E8766A"), Color("#6FA8DC"), Color("#F2C14E")]

var _maten: Dictionary = {}
var _notes: Array = []       ## [{knop, icoon, tekst, waar}]
var _regels: Array[Label] = []
var _kurk := Rect2()
var _leeg := false
var _bezig := false

func bouw(taken: Array, berichten: Array, mt: Dictionary) -> void:
	name = "Prikbord"
	_maten = mt
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	for k in get_children():
		remove_child(k)
		k.queue_free()
	_notes.clear()
	_regels.clear()
	# An empty board is one note of its own (`leeg`): the hotel's "🐾 Speel
	# lekker rond", which belongs to no room and only closes the sheet.
	_leeg = taken.size() == 1 and bool((taken[0] as Dictionary).get("leeg", false))
	for i in taken.size():
		var q: Dictionary = taken[i]
		var klaar := bool(q.get("klaar", false))
		var note := _maak_note(i, "✅" if klaar else str(q.get("icoon", "✨")),
			str(q.get("tekst", "")), "" if _leeg else _waar(str(q.get("kamer", ""))), klaar)
		(note["knop"] as Button).pressed.connect(func() -> void:
			Snd.tik()
			if bool(q.get("leeg", false)):
				leeg_getikt.emit()
			else:
				taak_gekozen.emit(q))
	for bericht in berichten:
		var l := _label("Bericht", ("%s %s" % [str(bericht.get("icoon", "")),
			str(bericht.get("tekst", ""))]).strip_edges(), int(mt.get("klein", 14)), UiThema.INKT2)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(l)
		_regels.append(l)
	_leg_uit()

## "in de gang": where the task is done, in words only — at the size of this
## line a room pictogram is a smudge, and the card already has its own.
static func _waar(kamer_id: String) -> String:
	if kamer_id.is_empty():
		return ""
	var r := Rooms.get_kamer(kamer_id)
	if r == null:
		return ""
	return UiTekst.in_kamer(kamer_id, r.naam)

func _maak_note(i: int, icoon: String, tekst: String, waar: String, klaar: bool) -> Dictionary:
	var b := Button.new()
	b.name = "Taak%d" % i
	b.text = ""                      # the labels below are the whole note
	b.tooltip_text = ("%s %s" % [tekst, waar]).strip_edges()
	b.focus_mode = Control.FOCUS_ALL
	b.clip_text = false
	var kl: Color = UiThema.KAART_AF if klaar else PAPIER[i % PAPIER.size()]
	b.add_theme_stylebox_override("normal", _papier(kl, false))
	b.add_theme_stylebox_override("hover", _papier(kl.darkened(0.03), false))
	b.add_theme_stylebox_override("pressed", _papier(kl.darkened(0.08), true))
	b.add_theme_stylebox_override("hover_pressed", _papier(kl.darkened(0.08), true))
	b.add_theme_stylebox_override("focus",
		UiThema.vlak(Color(0, 0, 0, 0), 10, 3, UiThema.PERZIK_D))
	var speld: Color = SPELD_KLEUR[i % SPELD_KLEUR.size()]
	b.draw.connect(func() -> void:
		b.draw_circle(Vector2(b.size.x * 0.5, SPELD + 1.0), SPELD, speld)
		b.draw_circle(Vector2(b.size.x * 0.5 - 1.5, SPELD - 0.5), 1.6, Color(1, 1, 1, 0.7)))
	add_child(b)
	var inkt := UiThema.INKT2 if klaar else UiThema.INKT
	var ic := _label("Icoon", icoon, int(_maten.get("icoon", 23)), UiThema.INKT)
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(ic)
	var tk := _label("Tekst", tekst, int(_maten.get("basis", 18)), inkt)
	tk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var vet := UiThema.laad_font(true)
	if vet != null:
		tk.add_theme_font_override("font", vet)
	b.add_child(tk)
	var wr: Label = null
	if not waar.is_empty():
		wr = _label("Waar", waar, int(_maten.get("klein", 14)), UiThema.INKT2)
		wr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_child(wr)
	var note := {"knop": b, "icoon": ic, "tekst": tk, "waar": wr}
	_notes.append(note)
	return note

func _papier(kl: Color, in_druk: bool) -> StyleBoxFlat:
	var sb := UiThema.vlak(kl, 8, 2, UiThema.WIT)
	sb.shadow_color = UiThema.SCHADUW_KL
	sb.shadow_size = 1 if in_druk else 3
	sb.shadow_offset = Vector2(0, 1 if in_druk else 2)
	return sb

func _label(naam: String, tekst: String, maat: int, kleur: Color) -> Label:
	var l := Label.new()
	l.name = naam
	l.text = tekst
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", maxi(UiThema.VLOER, maat))
	l.add_theme_color_override("font_color", kleur)
	return l

# ------------------------------------------------------------------ meten

func _ready() -> void:
	_leg_uit()

func _notification(wat: int) -> void:
	if wat == NOTIFICATION_RESIZED:
		_leg_uit()

## The width the sheet gives the board, with the sheet's own rule before the
## first layout pass (the same answer `ui/plattegrond.gd` gives).
func _beschikbaar() -> float:
	var ouder := get_parent() as Control
	if ouder != null and ouder.size.x > 1.0:
		return ouder.size.x
	var kader := Vector2.ZERO
	if Ui.bladlaag != null and is_instance_valid(Ui.bladlaag):
		kader = Ui.bladlaag.size
	if kader.x > 1.0:
		return minf(float(UiBlad.BREED), maxf(240.0, kader.x - 2.0 * UiBlad.RAND)) \
			- 2.0 * UiBlad.VULLING
	return float(UiBlad.BREED) - 2.0 * UiBlad.VULLING

## Notes under each other on the cork, the day's messages under the cork.
## Only measures once the labels have a font (in a themed tree); before that
## the size stays what it was.
func _leg_uit() -> void:
	if _bezig or not is_inside_tree():
		return
	_bezig = true
	var breedte := _beschikbaar()
	var kurk_w := minf(breedte, LEEG_BREED) if _leeg else breedte
	var kurk_x := (breedte - kurk_w) * 0.5
	var kolommen := 1
	if not _leeg and _notes.size() > 1 and _scherm_hoog() < LAAG_SCHERM:
		kolommen = _notes.size()
	var note_w := (kurk_w - 2.0 * RAND - float(kolommen - 1) * GAT) / float(kolommen)
	# first every note's height at that width, then one height per row, so the
	# notes of a row stand level with each other
	var hoogtes: Array[float] = []
	for note in _notes:
		hoogtes.append(_note_hoogte(note, note_w))
	var rij_h := 0.0
	for h in hoogtes:
		rij_h = maxf(rij_h, h)
	var y := RAND
	for i in _notes.size():
		var note: Dictionary = _notes[i]
		var h := rij_h if kolommen > 1 else hoogtes[i]
		var kol := i % kolommen
		_leg_note(note, Vector2(kurk_x + RAND + float(kol) * (note_w + GAT), y), note_w, h)
		if kol == kolommen - 1:
			y += h + GAT
	y += RAND - GAT
	_kurk = Rect2(Vector2(kurk_x, 0.0), Vector2(kurk_w, y))
	for l in _regels:
		y += 6.0
		var lh := UiThema.wrap_hoogte(l, breedte)
		_pin(l, Vector2(0.0, y), Vector2(breedte, lh))
		y += lh
	custom_minimum_size = Vector2(0.0, ceilf(y))
	queue_redraw()
	_bezig = false

## The height of the whole screen the sheet is on.
func _scherm_hoog() -> float:
	if Ui.bladlaag != null and is_instance_valid(Ui.bladlaag) and Ui.bladlaag.size.y > 1.0:
		return Ui.bladlaag.size.y
	return float(get_viewport_rect().size.y)

func _note_maten(note: Dictionary, note_w: float) -> Dictionary:
	var ic: Label = note["icoon"]
	var tk: Label = note["tekst"]
	var wr: Label = note["waar"]
	var ic_w := maxf(28.0, float(ic.get_theme_font_size("font_size")) * 1.5)
	var tekst_w := maxf(60.0, note_w - 2.0 * VULLING_X - ic_w - ICOON_GAT)
	var tk_h := UiThema.wrap_hoogte(tk, tekst_w)
	var wr_h := 0.0 if wr == null else UiThema.wrap_hoogte(wr, tekst_w)
	return {"ic_w": ic_w, "tekst_w": tekst_w, "tk_h": tk_h, "wr_h": wr_h,
		"binnen_h": tk_h + (0.0 if wr == null else REGEL_GAT + wr_h)}

func _note_hoogte(note: Dictionary, note_w: float) -> float:
	var m := _note_maten(note, note_w)
	return maxf(float(UiThema.TAP), float(m["binnen_h"]) + 2.0 * VULLING_Y + SPELD)

func _leg_note(note: Dictionary, plek: Vector2, note_w: float, h: float) -> void:
	var m := _note_maten(note, note_w)
	var b: Button = note["knop"]
	var ic: Label = note["icoon"]
	var tk: Label = note["tekst"]
	var wr: Label = note["waar"]
	b.position = plek
	b.size = Vector2(note_w, h)
	b.custom_minimum_size = b.size
	var boven := SPELD + (h - SPELD - float(m["binnen_h"])) * 0.5
	ic.position = Vector2(VULLING_X, SPELD)
	ic.size = Vector2(float(m["ic_w"]), h - SPELD)
	# The measured size is pinned BEFORE the size is set, and `clip_text`
	# takes the Label's own guess out of it: an autowrapping Label answers
	# the height it would need at the width it had a moment ago — one letter
	# per line, 450 units for "Vul de voerkar" — and a Control never gets
	# smaller than its minimum.  It never really clips: the pin is the height
	# the words need at this width (the same trick as `ui/wolk.gd`).
	_pin(tk, Vector2(VULLING_X + float(m["ic_w"]) + ICOON_GAT, boven),
		Vector2(float(m["tekst_w"]), float(m["tk_h"])))
	if wr != null:
		_pin(wr, Vector2(tk.position.x, boven + float(m["tk_h"]) + REGEL_GAT),
			Vector2(float(m["tekst_w"]), float(m["wr_h"])))

func _pin(l: Label, plek: Vector2, maat: Vector2) -> void:
	l.clip_text = true
	l.custom_minimum_size = maat
	l.position = plek
	l.size = maat

func _draw() -> void:
	if _kurk.size.x <= 0.0:
		return
	var sb := UiThema.vlak(UiThema.KURK, 12, 3, Color("#C9A77A"))
	draw_style_box(sb, _kurk)
