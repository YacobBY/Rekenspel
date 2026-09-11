extends Node
## Ui — cards, bubbles, the keypad, name plates, toasts and sheets.  Autoload #6.
## Port of `demos/dierenhotel/ui.js` + `style.css` (world.md §5.5-5.7, §6;
## art-sound-rules.md §16).
##
## Everything a child reads is built here, from Control nodes with Containers,
## so the HTML measure-and-shove machinery is gone: `get_combined_minimum_size()`
## is synchronous, which is what lets `Hits` place buttons in one pass and lets a
## choice strip pick its short words before the first frame instead of 140 ms
## after it.
##
## This module also owns the theme (`ui/thema.gd`).  That is deliberate: in the
## HTML a game's own inline `font-size` escaped the 12 px floor; here there is
## exactly one place where a child-facing size is decided, and a game cannot
## reach past it (architecture.md §1.3 point 5).

const TEKST_VLOER := UiThema.VLOER   ## px; never below this (HOTEL.md §9)
const TAP := UiThema.HOT             ## px; minimum tap target (44 below 360 px)
const TOAST_MS := 2600
const PLAAT := "naam_"               ## hotspot id prefix of a name plate

## The breakpoint moved: the chrome rebuilds its own labels at the new size.
signal thema_veranderd()
## A sum card was opened — the shell reports it as one `[probe]` line, which is
## how the browser probe knows a tap really produced a card (I1 finding 1).
signal kaart_geopend(id: String)

var knoplaag: Control = null     ## hotspot layer, exactly over the world frame
var naamlaag: Control = null     ## name plates
var toastlaag: Control = null
var bladlaag: Control = null     ## modal sheets
var vanglaag: Control = null     ## drop catch areas, UNDER the buttons

var thema: Theme = null
var maten: Dictionary = {}
var _basis := 18
var _tap := UiThema.HOT
var _toast_tijd := 0.0
var _toast: Control = null
var _blad: UiBlad = null
var _kaarten: Dictionary = {}    ## card id -> Kaart, for the frame-change rebuild
var _naamplaten: Dictionary = {} ## id -> UiNaamplaat
var _wortels: Array[Control] = []  ## the Controls the theme is stamped on
var _scherm := Vector2.ZERO        ## the CSS size of the whole screen, from the shell
var _rust := false

# ------------------------------------------------------------------- opzet

func _ready() -> void:
	_bouw_thema(18)
	if OS.has_feature("web"):
		var uit = JavaScriptBridge.eval("matchMedia('(prefers-reduced-motion: reduce)').matches", true)
		_rust = bool(uit) if uit != null else false
	World.kader_veranderd.connect(_op_kader_veranderd)

## Registered by `scenes/main.tscn` at boot.
func registreer_lagen(knop: Control, naam: Control, toast_l: Control,
		blad_l: Control = null, vang_l: Control = null) -> void:
	knoplaag = knop
	naamlaag = naam
	toastlaag = toast_l
	bladlaag = blad_l
	vanglaag = vang_l

## Which layer a hotspot Control belongs in.  Everything is a button over the
## world; a name plate is the exception — it lives UNDER the buttons so a finger
## always reaches the button, and it is not clickable at all (world.md §2.10).
func laag_voor(kind: String) -> Control:
	if kind == "naam" and naamlaag != null and is_instance_valid(naamlaag):
		return naamlaag
	return knoplaag

# ------------------------------------------------------------------- thema

func _bouw_thema(basis: int) -> void:
	_basis = basis
	maten = UiThema.maten(basis)
	thema = UiThema.bouw(basis)
	var venster := get_window()
	if venster != null:
		venster.theme = thema
	_stempel()

## A Control inherits a theme only from a Control or Window ANCESTOR, and the
## shell's root node is a plain `Node` (architecture.md §5), so the window's
## theme never reaches `Scherm`.  Every top-level Control of the shell is
## therefore stamped by hand — and `tests/test_ui.gd` checks a Label inside the
## real shell, because the tofu this caused was invisible to a headless
## assertion on `Ui.thema` itself.
func registreer_wortels(wortels: Array) -> void:
	_wortels.clear()
	for c in wortels:
		if c is Control:
			_wortels.append(c)
	_stempel()

func _stempel() -> void:
	for c in _wortels:
		if is_instance_valid(c):
			c.theme = thema

## The shell reports the CSS size of the whole screen; `Ui` needs it because the
## tap rule is a rule about fingers, not about frames (art-sound-rules.md §16.5).
func zet_scherm(maat: Vector2) -> void:
	if maat.x < 1.0 or maat.y < 1.0 or maat == _scherm:
		return
	_scherm = maat
	_herzie_maten(World.kader_rect())

func scherm_maat() -> Vector2:
	return _scherm if _scherm.x > 0.0 else World.kader_rect().size

func _op_kader_veranderd(rect: Rect2, _schaal: Dictionary) -> void:
	_herzie_maten(rect)

## world.md §6.5 / art-sound-rules.md §16.9, evaluated in units on the shell:
##   * the base font drops below a 520 unit FRAME — that is reading size, and
##     the card and the bubbles live in the frame;
##   * a tap target drops to 44 only below a 360 px SCREEN, never at exactly 360
##     (§16.5: `max-width:359px` → 44, `min-width:360px` → 48).  A fingertip
##     does not shrink because the chrome took some room, so this one is
##     measured on the window and not on the world frame.
func _herzie_maten(rect: Rect2) -> void:
	var basis := UiThema.basis_van(rect.size.x)
	var kort := scherm_maat()
	var tap := UiThema.tap_van(minf(kort.x, kort.y))
	var anders := basis != _basis or tap != _tap
	if basis != _basis:
		_bouw_thema(basis)
	_tap = tap
	if anders:
		thema_veranderd.emit()
	# A keypad built for 48 px keys does not fit a frame that just became
	# narrow: rebuild the open one, and let the strip pick its words again.
	if knoplaag == null:
		return
	for id in _kaarten.keys():
		var k: Kaart = _kaarten[id]
		if k != null and k.pad_id != "":
			k.open()

func basis_maat() -> int:
	return _basis

func tap_maat() -> int:
	return _tap

## True below a 360 unit frame: the card shrinks to ~170 units and every
## sentence wraps (art-sound-rules.md §16.6).
func smal() -> bool:
	return World.kader_rect().size.x < 360.0

# ---------------------------------------------------------------- knoppen

## The button factory used by `Hits`.
## `kind` is btn | drop | tag | naam | kaart | keuzes | pad | wolk | bron.
func maak_knop(kind: String, o: Dictionary) -> Control:
	match kind:
		"kaart":
			var k := UiSomkaart.new()
			k.bouw(o, maten, smal())
			return k
		"keuzes":
			var s := UiKeuzes.new()
			s.bouw(o.get("keuzes", []), World.kader_rect().size.x, maten,
				str(o.get("titel", "")), o.get("kaart", null))
			return s
		"pad":
			var p := UiKeypad.new()
			p.bouw(World.kader_rect().size, maten)
			var kaart = o.get("kaart", null)
			if kaart != null:
				p.toets_getikt.connect(kaart._toets)
			return p
		"tag":
			var t := UiGetalTag.new()
			t.bouw(o, maten)
			return t
		"wolk":
			var w := UiWolk.new()
			w.bouw(o, maten, smal())
			return w
		"bron":
			var b := UiBron.new()
			b.bouw(o, maten, _tap)
			return b
		"naam":
			var n := UiNaamplaat.new()
			n.bouw(str(o.get("tekst", o.get("label", ""))), maten)
			return n
	var knop := UiHotKnop.new()
	knop.bouw(o, maten, _tap)
	return knop

# ------------------------------------------------------------------ toast

## A message, never a button (`pointer-events: none` in the HTML).
func toast(tekst: String, soort: String = "") -> void:
	if toastlaag == null:
		print("toast: ", tekst)
		return
	if _toast != null and is_instance_valid(_toast):
		_toast.queue_free()
	var kleur := UiThema.INKT
	var letter := UiThema.WIT
	if soort == "happy":
		kleur = UiThema.MUNT_D
	elif soort == "kind":
		kleur = UiThema.PERZIK_D
	var doos := PanelContainer.new()
	doos.name = "Toast"
	doos.add_theme_stylebox_override("panel",
		UiThema.vulling(UiThema.vlak(kleur, 999, 0), 16, 8))
	doos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = tekst
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", maten["klein"])
	lbl.add_theme_color_override("font_color", letter)
	doos.add_child(lbl)
	toastlaag.add_child(doos)
	# The toast lives INSIDE the world frame (V1 finding 4): the toast layer
	# covers the whole screen, so a toast at its bottom edge lay over the room
	# bar — "Precies! 🎉" sat on the Zwembad chip and the chip could not be
	# tapped while it faded.  The frame excludes the chrome and the room bar by
	# construction, because it is the band between them.
	var band := toast_band()
	# The Label trap of §4.4 again: an autowrapping Label reports width 1, so a
	# PanelContainer that is sized from its minimum becomes a 33 unit column with
	# one character per line.  The sentence gets the width it needs (capped at
	# 92 % of the band) and the height that width really takes.
	var breed_max := maxf(120.0, band.size.x * 0.92 - 32.0)
	var f := lbl.get_theme_font("font")
	var nodig := breed_max
	if f != null:
		nodig = f.get_string_size(tekst, HORIZONTAL_ALIGNMENT_LEFT, -1,
			lbl.get_theme_font_size("font_size")).x
	var breed := clampf(nodig, 24.0, breed_max)
	# `clip_text` takes the Label's own guess (one letter per line) out of the
	# sum; the minimum below is the size it really needs, so nothing is clipped.
	lbl.clip_text = true
	lbl.custom_minimum_size = Vector2(breed, UiThema.wrap_hoogte(lbl, breed))
	var maat := doos.get_combined_minimum_size()
	maat.x = minf(maat.x, band.size.x * 0.92)
	doos.size = maat
	# Under 450 units of height, or with the keypad open, the toast moves to the
	# top of the frame, out of the way of the keys (art-sound-rules.md §16.8).
	var boven := band.size.y < 450.0 or _pad_open()
	doos.position = band.position + Vector2(band.size.x * 0.5 - maat.x * 0.5,
		12.0 if boven else band.size.y - maat.y - 18.0)
	_toast = doos
	_toast_tijd = TOAST_MS / 1000.0

## The strip a toast may use, in toast-layer coordinates: the world frame, which
## is exactly the band between the chrome and the room bar.  Without a frame
## (headless, before the shell registered) the whole layer is the band.
func toast_band() -> Rect2:
	if knoplaag != null and is_instance_valid(knoplaag) and knoplaag.size.x > 1.0 \
			and toastlaag != null and is_instance_valid(toastlaag):
		var kader := knoplaag.get_global_rect()
		var laag := toastlaag.get_global_rect()
		if kader.size.x > 1.0 and laag.size.x > 1.0:
			return Rect2(kader.position - laag.position, kader.size)
	return Rect2(Vector2.ZERO, toastlaag.size if toastlaag != null else Vector2.ZERO)

## Is a keypad on screen?  Then the bottom of the frame belongs to the keys.
func _pad_open() -> bool:
	for id in Hits.lijst():
		var s := Hits.spot(id)
		if s != null and s.kind == "pad" and is_instance_valid(s.knoop) and s.knoop.visible:
			return true
	return false

func _process(delta: float) -> void:
	if _toast_tijd > 0.0:
		_toast_tijd -= delta
		if _toast_tijd <= 0.0 and _toast != null and is_instance_valid(_toast):
			_toast.queue_free()
			_toast = null

# ------------------------------------------------------------------ bladen

## A modal sheet.  `o = {titel, hint, inhoud: Array[Control], knoppen, sluitbaar}`.
func blad_open(o: Dictionary) -> UiBlad:
	blad_dicht()
	if bladlaag == null:
		return null
	var b := UiBlad.new()
	b.name = "Blad"
	bladlaag.add_child(b)
	var kader := bladlaag.size
	if kader.x < 1.0 or kader.y < 1.0:
		kader = Vector2(get_window().content_scale_size)
	b.bouw(o, maten, kader)
	_blad = b
	return b

func blad_dicht() -> void:
	if _blad != null and is_instance_valid(_blad):
		_blad.sluit()
	_blad = null

func blad_open_nu() -> bool:
	return _blad != null and is_instance_valid(_blad)

# ------------------------------------------------------ wereldprimitieven

## `Ui.wolk(o)` — a speech bubble on an object or an animal (world.md §5.6).
## One line: pictogram · number · sentence.
func wolk(o: Dictionary) -> String:
	var id: String = o.get("id", "wolk%d" % Time.get_ticks_msec())
	var tik: Callable = o.get("tik", Callable())
	var getal = o.get("getal", null)
	var zin := ("%s %s %s" % [str(o.get("icoon", "")),
		"" if getal == null else str(getal), str(o.get("tekst", ""))]).strip_edges()
	if not tik.is_valid():
		# Without `tik` a tap reads the text aloud (world.md §5.6); `spreek()`
		# is a no-op in this run (architecture.md §13 Q-X4-10).
		tik = func(_s) -> void: spreek(zin)
	return Hits.maak({
		"id": id, "kind": "wolk", "kamer": o.get("kamer", World.kamer_nu()),
		"x": o.get("x", 0.0), "z": o.get("z", 0.0), "y": o.get("hoog", 20.0),
		# what the bubble belongs to, when it is not simply standing on it: the
		# board's task cards hang on the notice board (V1 finding 5)
		"obj": o.get("obj", ""),
		"icoon": o.get("icoon", ""), "getal": getal,
		"tekst": o.get("tekst", ""), "label": zin,
		"titel": o.get("titel", zin),
		"klas": "hotwolk " + str(o.get("klas", "")), "prio": o.get("prio", 9),
		"door": o.get("door", ""), "volg": o.get("volg", Callable()),
		"vlak": o.get("vlak", Rect2()), "aan": tik,
	})

func wolk_weg(id: String) -> void:
	Hits.weg(id)

## `World.getalTag(obj, n, o)` — a bare number ON an object (world.md §5.6).
## `n == null` removes it.  Not clickable, not focusable.
func getal_tag(obj: Variant, n: Variant, o: Dictionary = {}) -> String:
	var id: String = o.get("id", "tag_%s" % str(obj))
	if n == null:
		Hits.weg(id)
		return ""
	var plek := _mik_van(obj, o)
	return Hits.maak({
		"id": id, "kind": "tag", "kamer": o.get("kamer", plek.get("kamer", World.kamer_nu())),
		"x": plek.get("x", 0.0), "z": plek.get("z", 0.0), "y": o.get("y", 8.0),
		"getal": n, "op": "rand", "prio": o.get("prio", 4),
		"titel": o.get("titel", ""), "klas": "hotgetal " + str(o.get("klas", "")),
		"door": o.get("door", ""), "volg": o.get("volg", Callable()),
		"vlak": o.get("vlak", Rect2()),
	})

## `ctx.hotspots.bron(obj, o)` — a drag source with a counter (world.md §5.6).
func bron(obj: Variant, o: Dictionary) -> String:
	var id: String = o.get("id", "bron_%s" % str(obj))
	var plek := _mik_van(obj, o)
	Hits.maak({
		"id": id, "kind": "bron", "kamer": o.get("kamer", plek.get("kamer", World.kamer_nu())),
		"x": plek.get("x", 0.0), "z": plek.get("z", 0.0), "y": o.get("hoog", 12.0),
		"icoon": o.get("icoon", ""), "label": o.get("label", ""),
		"titel": o.get("titel", ""), "aantal": o.get("aantal", 0), "hand": o.get("hand", 0),
		"klas": "hotbron " + str(o.get("klas", "")), "prio": o.get("prio", 6),
		"door": o.get("door", ""), "aan": o.get("tik", Callable()),
		"drop": o.get("drop", ""), "sleep": o.get("sleep", ""), "data": o.get("data", {}),
		"vlak": o.get("vlak", Rect2()), "volg": o.get("volg", Callable()),
	})
	return id

## The live source Control, so a game can call `zet(aantal, hand)` on it.
func bron_van(id: String) -> UiBron:
	var s := Hits.spot(id)
	return null if s == null or not is_instance_valid(s.knoop) else s.knoop as UiBron

# ------------------------------------------------------------------ kaart

## `Ui.somkaart(obj, som, o)` — the mini squared-paper card: one mandatory Dutch
## sentence, the sum line, an answer box with its keypad, or one strip of
## choices glued 5 units under it at any scale (world.md §5.5).
##
## `o.regel` is mandatory and binding (HOTEL.md §9, architecture.md §1.1 F4):
## one plain sentence with a verb or a question word, pictogram first on that
## same line, <= 8 words AND <= 40 characters.  A violation still draws, and
## logs exactly one warning per card — the same behaviour as the HTML.
func somkaart(obj: Variant, som: String, o: Dictionary) -> Kaart:
	var id: String = o.get("id", "kaart%d" % Time.get_ticks_msec())
	var kaart := Kaart.new()
	kaart.id = id
	kaart.max_cijfers = int(o.get("max", 2))
	kaart.on_ok = o.get("on_ok", Callable())
	kaart.kamer = o.get("kamer", World.kamer_nu())
	kaart.door = o.get("door", "")
	var keuzes: Array = o.get("keuzes", [])
	kaart.heeft_pad = keuzes.is_empty() and bool(o.get("pad", true))
	_kaarten[id] = kaart
	var plek: Dictionary = _mik_van(obj, o)
	Hits.maak({
		"id": id, "kind": "kaart", "kamer": kaart.kamer,
		"vlak": o.get("vlak", _vlak_van(plek, kaart.kamer)),
		"x": plek.get("x", 0.0), "z": plek.get("z", 0.0), "y": o.get("hoog", 22.0),
		"op": "midden", "vast": true, "prio": o.get("prio", 14),
		"door": kaart.door, "titel": o.get("titel", ""),
		"icoon": o.get("icoon", ""), "regel": o.get("regel", ""),
		"regel2": o.get("regel2", ""), "som": som,
		"max": kaart.max_cijfers, "keuzes": keuzes,
		"on_weg": func(_s) -> void: _kaarten.erase(id),
	})
	kaart_geopend.emit(id)
	keur_regel(id, o.get("regel", ""))
	if not str(o.get("regel2", "")).is_empty():
		keur_regel(id + " (regel2)", o.get("regel2", ""))
	if not keuzes.is_empty():
		kaart.strook_id = id + "_keuzes"
		Hits.maak({
			"id": kaart.strook_id, "kind": "keuzes", "kamer": kaart.kamer,
			"x": plek.get("x", 0.0), "z": plek.get("z", 0.0), "y": o.get("hoog", 22.0),
			"vast": true, "prio": 13, "door": kaart.door,
			"kleef_aan": id, "keuzes": keuzes, "kaart": kaart,
			"titel": o.get("keuze_titel", "kies er een"),
		})
	elif kaart.heeft_pad and bool(o.get("open", false)):
		kaart.open()
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

## A task card on the prikbord keeps its own short line: <= 6 words (HOTEL.md §9).
func keur_taak(id: String, tekst: String) -> bool:
	var woorden := tekst.split(" ", false).size()
	if woorden > 6:
		push_warning('taakkaart "%s" heeft %d woorden; hooguit 6' % [id, woorden])
		return false
	return true

## The screen rectangle of the object a card hangs on, when the object is a
## real thing with a plate.  `Hits` uses it to keep the card OFF it: the sum
## hangs above the bowl, the guest stays whole (HOTEL.md §9).
func _vlak_van(plek: Dictionary, kamer: String) -> Rect2:
	var model := str(plek.get("model", plek.get("n", "")))
	if model.is_empty() or kamer != World.kamer_nu():
		return Rect2()
	return World.vlak_van(model, float(plek.get("x", 0.0)), float(plek.get("z", 0.0)),
		float(plek.get("hoog", plek.get("y", 0.0))), plek.get("params", {}))

## Where a card, a bubble or a tag hangs.  `World.mik` knows the whole search
## order (loose decor, slots, fixed decor); a raw {x, z} always wins.
func _mik_van(obj: Variant, o: Dictionary) -> Dictionary:
	var stuk := World.mik(obj, o.get("kamer", World.kamer_nu()))
	if not stuk.is_empty():
		return stuk
	return {"x": o.get("x", 0.0), "z": o.get("z", 0.0)}

## The handle a game holds on to (architecture.md §6.3).
class Kaart extends RefCounted:
	var id: String
	var strook_id := ""
	var pad_id := ""
	var kamer := ""
	var door := ""
	var max_cijfers := 2
	var heeft_pad := true
	var on_ok: Callable
	var _getikt := ""            ## what the child typed, never what a game wrote

	func _knoop() -> UiSomkaart:
		var s = Hits.spot(id)
		if s == null or not is_instance_valid(s.knoop):
			return null
		return s.knoop as UiSomkaart

	func regel(zin: String) -> void:
		var k := _knoop()
		if k != null and k.regel_label != null:
			k.zet_regel(zin)
			Ui.keur_regel(id, zin)

	func regel2(zin: String) -> void:
		var k := _knoop()
		if k != null:
			k.zet_regel2(zin)
			if not zin.is_empty():
				Ui.keur_regel(id + " (regel2)", zin)

	func som(tekst: String) -> void:
		var k := _knoop()
		if k != null and k.som_label != null:
			k.som_label.text = tekst

	func zet(tekst: String) -> void:
		_getikt = tekst
		var k := _knoop()
		if k != null and k.vak_label != null:
			k.vak_label.text = tekst

	func hulp(tekst: String) -> void:
		var k := _knoop()
		if k != null and k.hulp_label != null:
			k.hulp_label.text = tekst
			k.hulp_label.visible = not tekst.is_empty()

	func getal() -> Variant:
		if _getikt.is_empty() or not _getikt.is_valid_int():
			return null
		return _getikt.to_int()

	## Open the keypad band under the world (architecture.md §4.4).  There is at
	## most one: a second card taking it over wins, exactly as in the HTML.
	func open() -> void:
		if not heeft_pad:
			return
		Ui.pad_weg_behalve(id)
		pad_id = id + "_pad"
		Hits.maak({
			"id": pad_id, "kind": "pad", "kamer": kamer,
			"x": 0.0, "z": 0.0, "y": 0.0, "op": "voet",
			"vast": true, "prio": 15, "door": door,
			"titel": "Cijfers", "kaart": self,
		})

	func pad_dicht() -> void:
		if pad_id != "":
			Hits.weg(pad_id)
			pad_id = ""

	## One key.  `⌫` wipes the last digit, `✓` hands the number to the game.
	func _toets(teken: String) -> void:
		if teken == UiKeypad.WIS:
			if not _getikt.is_empty():
				zet(_getikt.substr(0, _getikt.length() - 1))
			return
		if teken == UiKeypad.OK:
			var k := _knoop()
			if k != null:
				k.zet_goed(false)
			if on_ok.is_valid():
				Ui.roep(on_ok, [getal(), self])
			return
		if not _getikt.is_empty() and not _getikt.is_valid_int():
			_getikt = ""          # the box carried a ✓ or a game's own text
		if _getikt.length() >= max_cijfers:
			return
		zet(_getikt + teken)

	## Tick the card: the strip and the keypad go, the card stays readable.
	func klaar() -> void:
		if strook_id != "":
			Hits.weg(strook_id)
			strook_id = ""
		pad_dicht()
		var k := _knoop()
		if k != null:
			k.zet_goed(true)
			k.zet_af()
		zet("✓")

	func weg() -> void:
		if strook_id != "":
			Hits.weg(strook_id)
			strook_id = ""
		pad_dicht()
		Hits.weg(id)

## Exactly one keypad on screen (world.md §5.5).
func pad_weg_behalve(id: String) -> void:
	for k in _kaarten.keys():
		if k != id:
			var kaart: Kaart = _kaarten[k]
			if kaart != null:
				kaart.pad_dicht()

func kaart_van(id: String) -> Kaart:
	return _kaarten.get(id)

# -------------------------------------------------------------- naamplaten

## The name plate above a guest (world.md §2.10).  `World` owns the point.
##
## The plate is a hotspot of kind `naam`: it lives in `Naamlaag` (under the
## buttons, never clickable) but it takes part in the band grid's RESERVATION
## like a number tag, so a button can no longer land under it — that is what put
## "Boef" over the Prikbord button (I1 finding 3).  It follows its guest by the
## guest's own plate rectangle, so it hangs against the head at any scale.
func naamplaat(id: String, naam: String, punt: Vector2 = Vector2.ZERO) -> void:
	if naamlaag == null:
		return
	var spot_id := PLAAT + id
	var s := Hits.spot(spot_id)
	if s != null and is_instance_valid(s.knoop):
		var p := s.knoop as UiNaamplaat
		if p != null and p.text != naam:
			p.text = naam
			p.update_minimum_size()
		return
	var d = World.dier(id)
	Hits.maak({
		"id": spot_id, "kind": "naam", "door": PLAAT, "prio": 3,
		"kamer": d.kamer if d != null else World.kamer_nu(),
		"x": d.x if d != null else punt.x, "z": d.z if d != null else 0.0, "y": 0.0,
		"tekst": naam, "volg": _volg_plaat(id),
	})
	_naamplaten[id] = spot_id

## Where the plate hangs: on its guest, with the guest's own drawn rectangle so
## the band grid knows exactly what to keep clear.
func _volg_plaat(id: String) -> Callable:
	return func() -> Dictionary:
		var d = World.dier(id)
		if d == null:
			return {}
		return {"x": d.x, "z": d.z, "kamer": d.kamer, "vlak": World.vlak_van_dier(id)}

func naamplaat_weg(id: String) -> void:
	Hits.weg(PLAAT + id)
	_naamplaten.erase(id)

func naamplaten_leeg() -> void:
	for id in _naamplaten.keys():
		Hits.weg(PLAAT + id)
	_naamplaten.clear()

## The live plate Control of a guest, for the tests.
func naamplaat_van(id: String) -> UiNaamplaat:
	var s := Hits.spot(PLAAT + id)
	return null if s == null or not is_instance_valid(s.knoop) else s.knoop as UiNaamplaat

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
## repeating).  Out of scope for this run, see architecture.md §13 Q-X4-10; it
## exists as a no-op so a later JavaScriptBridge implementation needs no
## call-site change.
func spreek(_zin: String) -> void:
	pass

## Reduced motion.  Godot exposes no `prefers-reduced-motion`, so this owns it.
func rust_modus() -> bool:
	return _rust

func zet_rust_modus(aan: bool) -> void:
	_rust = aan

## `Ui.opKader(fn)` — subscribe to frame changes; returns the unsubscribe.
## Always unsubscribe in stop().
func op_kader(fn: Callable) -> Callable:
	World.kader_veranderd.connect(fn)
	return func() -> void:
		if World.kader_veranderd.is_connected(fn):
			World.kader_veranderd.disconnect(fn)

## Call a game's callback with as many arguments as it declared.  The specs
## document `kies(k, kaart)` and `on_ok(n, kaart)`, while the reference game in
## `res://games/_voorbeeld/` declares one parameter; GDScript refuses a call
## with too many, so the arity is honoured instead of being assumed.
func roep(cb: Callable, args: Array) -> Variant:
	if not cb.is_valid():
		return null
	var n := cb.get_argument_count()
	if n >= args.size():
		return cb.callv(args)
	return cb.callv(args.slice(0, n))

# ---------------------------------------------------------- tekencontrole

## Does the bundled font subset carry this character?  `Font.has_char()` walks
## the fallbacks, so one call covers Nunito, the symbol subset and the colour
## emoji subset (architecture.md §7.5).
func heeft_teken(teken: int) -> bool:
	if thema == null or thema.default_font == null:
		return true
	if teken < 32 or teken == 0xFE0F:
		return true          # control characters and the variation selector
	return thema.default_font.has_char(teken)

## Every character of a child-facing string that the subset does not carry.
func mist_tekens(zin: String) -> Array[String]:
	var uit: Array[String] = []
	for i in zin.length():
		var c := zin.unicode_at(i)
		if not heeft_teken(c) and not uit.has(char(c)):
			uit.append(char(c))
	return uit
