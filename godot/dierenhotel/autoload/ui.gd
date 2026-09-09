extends Node
## Ui — cards, bubbles, the keypad, toasts and the shell.  Autoload #6.
## Port of `demos/dierenhotel/ui.js` + `style.css` (world.md §5.5-5.7, §6;
## art-sound-rules.md §16).
##
## Everything a child reads is built from Control nodes with Containers, so the
## HTML measure-and-shove machinery is gone: `get_combined_minimum_size()` is
## synchronous, which is what lets Hits place buttons in one pass and lets a
## choice strip pick its short words before the first frame instead of 140 ms
## after it.
##
## W3 fills in: somkaart (the squared-paper card with its mandatory sentence),
## the keypad band, the choice strip, wolk/bron/getalTag, name plates, the HUD,
## the room bar, sheets and the start screen.  The skeleton ships the layers,
## the toast, a minimal bubble and the button factory Hits needs.

const TEKST_VLOER := 12      ## px; never below this (HOTEL.md §9)
const TAP := 48              ## px; minimum tap target (44 below 360 px wide)
const TOAST_MS := 2600

var knoplaag: Control = null     ## hotspot layer, exactly over the world frame
var naamlaag: Control = null     ## name plates
var toastlaag: Control = null
var _toast_tijd := 0.0
var _toast: Control = null

## Registered by scenes/main.tscn at boot.
func registreer_lagen(knop: Control, naam: Control, toast_l: Control) -> void:
	knoplaag = knop
	naamlaag = naam
	toastlaag = toast_l

# ---------------------------------------------------------------- knoppen

## The button factory used by Hits.  `kind` is btn | drop | tag | kaart | keuzes.
func maak_knop(kind: String, o: Dictionary) -> Control:
	if kind == "kaart":
		return _maak_kaart(o)
	if kind == "keuzes":
		return _maak_keuzes(o)
	if kind == "tag":
		var tag := Label.new()
		tag.text = str(o.get("getal", ""))
		tag.add_theme_font_size_override("font_size", maxi(TEKST_VLOER, 14))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.focus_mode = Control.FOCUS_NONE
		return tag
	var b := Button.new()
	var icoon: String = o.get("icoon", "")
	var label: String = o.get("label", "")
	b.text = (icoon + " " + label).strip_edges()
	b.tooltip_text = o.get("titel", label)
	b.custom_minimum_size = Vector2(TAP, TAP)
	b.add_theme_font_size_override("font_size", maxi(TEKST_VLOER, 15))
	b.focus_mode = Control.FOCUS_NONE if o.get("kind", "btn") == "tag" else Control.FOCUS_ALL
	return b

# ------------------------------------------------------------------ toast

## A message, never a button (pointer-events: none in the HTML).
func toast(tekst: String, _soort: String = "") -> void:
	if toastlaag == null:
		print("toast: ", tekst)
		return
	if _toast != null and is_instance_valid(_toast):
		_toast.queue_free()
	var doos := PanelContainer.new()
	var lbl := Label.new()
	lbl.text = tekst
	lbl.add_theme_font_size_override("font_size", maxi(TEKST_VLOER, 15))
	doos.add_child(lbl)
	doos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doos.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toastlaag.add_child(doos)
	doos.position = Vector2(toastlaag.size.x * 0.5 - doos.size.x * 0.5, toastlaag.size.y - 60)
	_toast = doos
	_toast_tijd = TOAST_MS / 1000.0

func _process(delta: float) -> void:
	if _toast_tijd > 0.0:
		_toast_tijd -= delta
		if _toast_tijd <= 0.0 and _toast != null and is_instance_valid(_toast):
			_toast.queue_free()
			_toast = null

# ------------------------------------------------------- wereldprimitieven

## `Ui.wolk(obj, {icoon, getal, tekst, hoog, klas, prio, tik})` — a speech
## bubble on an object or an animal.  One line: [icoon] [getal] [tekst].
func wolk(o: Dictionary) -> String:
	var id: String = o.get("id", "wolk%d" % Time.get_ticks_msec())
	var tekst := "%s %s %s" % [o.get("icoon", ""), o.get("getal", ""), o.get("tekst", "")]
	return Hits.maak({
		"id": id, "kamer": o.get("kamer", World.kamer_nu()),
		"x": o.get("x", 0.0), "z": o.get("z", 0.0), "y": o.get("hoog", 20.0),
		"icoon": "", "label": tekst.strip_edges(), "titel": o.get("titel", tekst.strip_edges()),
		"klas": "hotwolk " + str(o.get("klas", "")), "prio": o.get("prio", 9),
		"door": o.get("door", ""), "volg": o.get("volg", Callable()),
		"vlak": o.get("vlak", Rect2()), "aan": o.get("tik", Callable()),
	})

func wolk_weg(id: String) -> void:
	Hits.weg(id)

## `Ui.somkaart(obj, som, o)` — the mini squared-paper card: one mandatory Dutch
## sentence, the sum line, an answer box, and optionally one strip of choices
## glued 5 px under it at any scale.
##
## `o.regel` is mandatory and binding (HOTEL.md §9, architecture.md §1.1 F4):
## one plain sentence with a verb or a question word, pictogram first on that
## same line, <= 8 words AND <= 40 characters.  A violation still draws, and
## logs exactly one warning per card — the same behaviour as the HTML.
##
## W3 completes: the squared-paper styling, the keypad band (`open()`, `getal()`,
## `on_ok`), the ghost-shape help ladder and the tick animation.
func somkaart(obj: Variant, som: String, o: Dictionary) -> Kaart:
	var id: String = o.get("id", "kaart%d" % Time.get_ticks_msec())
	var kaart := Kaart.new()
	kaart.id = id
	var plek: Dictionary = _mik_van(obj, o)
	Hits.maak({
		"id": id, "kind": "kaart", "kamer": o.get("kamer", World.kamer_nu()),
		"x": plek.get("x", 0.0), "z": plek.get("z", 0.0), "y": o.get("hoog", 22.0),
		"op": "midden", "vast": true, "prio": o.get("prio", 14),
		"door": o.get("door", ""), "titel": o.get("titel", ""),
		"icoon": o.get("icoon", ""), "regel": o.get("regel", ""), "som": som,
	})
	keur_regel(id, o.get("regel", ""))
	var keuzes: Array = o.get("keuzes", [])
	if not keuzes.is_empty():
		kaart.strook_id = id + "_keuzes"
		Hits.maak({
			"id": kaart.strook_id, "kind": "keuzes",
			"kamer": o.get("kamer", World.kamer_nu()),
			"x": plek.get("x", 0.0), "z": plek.get("z", 0.0), "y": o.get("hoog", 22.0),
			"vast": true, "prio": 20, "door": o.get("door", ""),
			"kleef_aan": id, "keuzes": keuzes,
			"titel": o.get("keuze_titel", "kies er een"),
		})
	return kaart

## The mandatory sentence, checked.  Returns true when it fits the budget.
func keur_regel(id: String, zin: String) -> bool:
	if zin.strip_edges().is_empty():
		push_warning('somkaart "%s" heeft geen regel' % id)
		return false
	var woorden := zin.split(" ", false).size()
	if woorden > 8 or zin.length() > 40:
		push_warning('somkaart "%s" heeft een regel van %d woorden en %d tekens; hooguit 8 woorden en 40 tekens'
			% [id, woorden, zin.length()])
		return false
	return true

func _mik_van(obj: Variant, o: Dictionary) -> Dictionary:
	if obj is Dictionary:
		return obj
	if obj is String:
		var stuk := World.decor_plek(obj, o.get("kamer", World.kamer_nu()))
		if not stuk.is_empty():
			return stuk
	return {"x": o.get("x", 0.0), "z": o.get("z", 0.0)}

## The handle a game holds on to.
class Kaart extends RefCounted:
	var id: String
	var strook_id: String = ""

	func _knoop() -> Control:
		var s = Hits.spot(id)
		return null if s == null else s.knoop

	func regel(zin: String) -> void:
		var k := _knoop()
		if k != null:
			k.get_node("Kolom/Regel").text = zin
			Ui.keur_regel(id, zin)

	func som(tekst: String) -> void:
		var k := _knoop()
		if k != null:
			k.get_node("Kolom/Rij/Som").text = tekst

	func zet(tekst: String) -> void:
		var k := _knoop()
		if k != null:
			k.get_node("Kolom/Rij/Vak").text = tekst

	func hulp(tekst: String) -> void:
		var k := _knoop()
		if k != null:
			var h: Label = k.get_node("Kolom/Hulp")
			h.text = tekst
			h.visible = not tekst.is_empty()

	func getal() -> Variant:
		var k := _knoop()
		if k == null:
			return null
		var t: String = k.get_node("Kolom/Rij/Vak").text
		return null if t.is_empty() else t.to_int()

	func open() -> void:
		pass                       # W3: the keypad band

	## Tick the card: the strip and the keypad go, the card stays readable.
	func klaar() -> void:
		if strook_id != "":
			Hits.weg(strook_id)
			strook_id = ""
		zet("\u2713")

	func weg() -> void:
		if strook_id != "":
			Hits.weg(strook_id)
			strook_id = ""
		Hits.weg(id)

## `World.getalTag(obj, n, o)` — a bare number ON an object.  W3.
func getal_tag(_obj: Variant, _n: Variant, _o: Dictionary = {}) -> String:
	return ""                         # W3

## `ctx.hotspots.bron(obj, o)` — a drag source with a counter.  W3.
func bron(_obj: Variant, _o: Dictionary) -> String:
	return ""                         # W3

func _maak_kaart(o: Dictionary) -> Control:
	var paneel := PanelContainer.new()
	paneel.mouse_filter = Control.MOUSE_FILTER_STOP
	var kolom := VBoxContainer.new()
	kolom.name = "Kolom"
	paneel.add_child(kolom)
	var regel := Label.new()
	regel.name = "Regel"
	regel.text = ("%s %s" % [o.get("icoon", ""), o.get("regel", "")]).strip_edges()
	regel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	regel.custom_minimum_size = Vector2(180, 0)
	regel.add_theme_font_size_override("font_size", maxi(TEKST_VLOER, 15))
	kolom.add_child(regel)
	var rij := HBoxContainer.new()
	rij.name = "Rij"
	kolom.add_child(rij)
	var som := Label.new()
	som.name = "Som"
	som.text = o.get("som", "")
	som.add_theme_font_size_override("font_size", maxi(TEKST_VLOER, 17))
	rij.add_child(som)
	var vak := Label.new()
	vak.name = "Vak"
	vak.custom_minimum_size = Vector2(40, 34)
	vak.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vak.add_theme_font_size_override("font_size", maxi(TEKST_VLOER, 17))
	rij.add_child(vak)
	var hulp := Label.new()
	hulp.name = "Hulp"
	hulp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hulp.custom_minimum_size = Vector2(180, 0)
	hulp.add_theme_font_size_override("font_size", maxi(TEKST_VLOER, 13))
	hulp.visible = false
	kolom.add_child(hulp)
	return paneel

## One strip of choices: pictogram AND word, always (HOTEL.md §9).  The short
## word is chosen synchronously when the long one does not fit the frame — no
## measure-after-paint, no per-game width threshold.
func _maak_keuzes(o: Dictionary) -> Control:
	var paneel := PanelContainer.new()
	var rij := HBoxContainer.new()
	rij.name = "Rij"
	paneel.add_child(rij)
	var keuzes: Array = o.get("keuzes", [])
	_vul_keuzes(rij, keuzes, false)
	var breed := World.kader_rect().size.x
	if breed > 0.0 and paneel.get_combined_minimum_size().x > breed - 8.0:
		for k in rij.get_children():
			k.queue_free()
			rij.remove_child(k)
		_vul_keuzes(rij, keuzes, true)
	return paneel

func _vul_keuzes(rij: HBoxContainer, keuzes: Array, kort: bool) -> void:
	for keuze in keuzes:
		var b := Button.new()
		var woord: String = keuze.get("kort", keuze.get("tekst", "")) if kort \
			else keuze.get("tekst", "")
		b.text = ("%s %s" % [keuze.get("icoon", ""), woord]).strip_edges()
		b.custom_minimum_size = Vector2(TAP, TAP)
		b.add_theme_font_size_override("font_size", maxi(TEKST_VLOER, 15))
		var kies: Callable = keuze.get("kies", Callable())
		if kies.is_valid():
			b.pressed.connect(func():
				Snd.tik()
				kies.call(keuze.get("id", "")))
		rij.add_child(b)

# -------------------------------------------------------------- taalhulpjes

## `meervoud(n, een, veel)` — always used; a wrong plural makes a six-year-old
## read the sentence twice.
func meervoud(n: int, een: String, veel: String) -> String:
	return "%d %s" % [n, een if n == 1 else veel]

const WOORDEN := ["nul", "een", "twee", "drie", "vier", "vijf", "zes", "zeven",
	"acht", "negen", "tien", "elf", "twaalf", "dertien", "veertien", "vijftien",
	"zestien", "zeventien", "achttien", "negentien", "twintig"]

func woord(n: int) -> String:
	return WOORDEN[n] if n >= 0 and n < WOORDEN.size() else str(n)

## Optional read-aloud of a short prompt (HOTEL.md §9: never compulsory, never
## repeating).  Out of scope for this run, see architecture.md §13 Q-X4-10; it exists
## as a no-op so a later JavaScriptBridge implementation needs no call-site change.
func spreek(_zin: String) -> void:
	pass

## Reduced motion.  Godot exposes no `prefers-reduced-motion`, so this owns it.
func rust_modus() -> bool:
	return _rust

var _rust := false

func _ready() -> void:
	if OS.has_feature("web"):
		var uit = JavaScriptBridge.eval("matchMedia('(prefers-reduced-motion: reduce)').matches", true)
		_rust = bool(uit) if uit != null else false

## `Ui.opKader(fn)` — subscribe to frame changes; returns the unsubscribe.
## Always unsubscribe in stop().
func op_kader(fn: Callable) -> Callable:
	World.kader_veranderd.connect(fn)
	return func():
		if World.kader_veranderd.is_connected(fn):
			World.kader_veranderd.disconnect(fn)
