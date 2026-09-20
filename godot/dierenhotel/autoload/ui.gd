extends Node
## Ui — cards, bubbles, choice strips, name plates, toasts and sheets.  Autoload #6.
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
var balklaag: UiRekenbalk = null ## the maths bar of PLAN.md §3.1, UNDER the buttons

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
##
## `balk_l` is the sixth and optional layer: the paper of the maths bar.  It is
## optional because the thirteen test files that register their own plain
## `Control` do not build one — and they do not need to, because every number
## in §3.1 is derived from the frame, not from this node.
func registreer_lagen(knop: Control, naam: Control, toast_l: Control,
		blad_l: Control = null, vang_l: Control = null,
		balk_l: UiRekenbalk = null) -> void:
	knoplaag = knop
	naamlaag = naam
	toastlaag = toast_l
	bladlaag = blad_l
	vanglaag = vang_l
	balklaag = balk_l

## Which layer a hotspot Control belongs in.  Everything is a button over the
## world; a name plate is the exception — it lives UNDER the buttons so a finger
## always reaches the button, and it is not clickable at all (world.md §2.10).
func laag_voor(kind: String) -> Control:
	if kind == "naam" and naamlaag != null and is_instance_valid(naamlaag):
		return naamlaag
	return knoplaag

# --------------------------------------------------------------- rekenbalk
#
# PLAN.md §3.1 — the maths bar as a card dock.  Everything in this section is
# a PURE function of the frame and of the card that is docked, and of nothing
# else.  That is the property the whole design turns on: `World.zet_balk()`
# changes the SCALE of the world, so if the height of the bar were measured
# from what the world looks like after that rescale, the two would chase each
# other forever.  The reverted attempt of 2026-09-19 (`0ba9e63`) did exactly
# that and grew the bar to 48 % of the frame.
#
# The owner's rule of 2026-09-19: the bar may only cost the world space while
# a card really stands in it.  With nothing docked `balk_kost()` is 0 and the
# world is fitted into the whole frame, exactly as it was before the bar was
# invented — which is why every existing test still sees the old numbers.
#
# The card does not "ask" to be docked and the bar does not reach for it.  The
# dock is decided here, from the priority the card already carries, and `Hits`
# only ever asks two questions: is the bar on (`balk_aan`), and where does my
# kind belong on it (`balk_plek`).

## §3.1: the bar never takes more than a third of the frame.  The owner keeps
## two thirds of the screen for the hotel, whatever is standing in the bar.
const BALK_DAK := 0.34
## Air between the edge of the paper and whatever stands on it.  Two units,
## not four, because the difference decides whether a card that grew a worked
## example still fits under the third-of-the-frame ceiling on a tablet: at 4
## the stack is 220 in a 990x637 frame whose cap is 216 and the bar lets go
## exactly when the child needs it most; at 2 it is 216 and it docks.
const BALK_LUCHT := 2.0
## Air between the card and the answer strip under it.
const BALK_GAT := 8.0
## How many bands of the hit grid the room must keep above the bar.  The bar
## is not the only thing that wants the bottom of the frame: every game hangs
## its own buttons there, and a button is 52 units tall (`Hits.RIJ`, the 48
## px tap target plus its air) and does not shrink when the world does.
## Five is the least a room needs to lay its rows out without them climbing
## over each other — measured, not guessed: at 740x360 a 122 unit bar leaves
## 238 units, four and a half bands, and the bed rows overlap by 2500 px and
## come home `krap`.  The 0.34 ceiling of §3.1 alone lets that bar in; this
## one does not.
const WERELD_BANDEN := 5

var _balk_kaart := ""     ## id of the card that owns the bar right now, "" = none
var _balk_kost := 0.0     ## what the bar costs the world; cached, see _balk_herstel
var _balk_stil := 0       ## > 0: cards are swapping, do not rescale mid-swap
var _balk_tellingen := 0  ## how often the bar was recomputed; `test_balk.gd`
                        ## counts these to prove nothing recomputes per frame

## The design height of the bar for the frame as it stands: the table of
## §3.1, already clamped to `BALK_DAK` by `UiThema.balk_maten()`.  This is
## what the bar WANTS; `balk_kost()` is what it actually takes.
func balk_hoog() -> float:
	var k := World.kader_rect()
	if k.size.x < 1.0 or k.size.y < 1.0:
		return 0.0
	return float(UiThema.balk_maten(k.size)["hoog"])

## `hoog` stacks the card over its strip; `laag` puts them side by side in a
## frame that is short in the tall direction (§3.1).
func balk_vorm() -> String:
	var k := World.kader_rect()
	if k.size.x < 1.0 or k.size.y < 1.0:
		return "hoog"
	return str(UiThema.balk_maten(k.size)["vorm"])

## The most the bar may ever take of this frame.
func balk_dak() -> float:
	return floorf(World.kader_rect().size.y * BALK_DAK)

## The most the bar may take AND leave the room able to place its own
## buttons.  The real ceiling: `balk_dak()` protects the child's view of the
## hotel, this protects the hotel's own tap targets.  On a short landscape
## frame the two disagree, and this one wins — the bar lets go.
func balk_ruimte() -> float:
	return maxf(0.0, World.kader_rect().size.y - float(WERELD_BANDEN * Hits.RIJ))

## The card that owns the bar: the open card with the highest `prio`, newest
## first among equals.  `""` while nothing is docked.
func balk_kaart() -> String:
	return _balk_kaart

## The Control that draws the docked card.  `_kaarten` holds the `Kaart`
## wrapper, not the node — the node lives on the spot, which is also the only
## place that knows whether it is still alive.
func balk_kaart_node() -> UiSomkaart:
	if _balk_kaart == "":
		return null
	var s = Hits.spot(_balk_kaart)
	if s == null or not is_instance_valid(s.knoop):
		return null
	return s.knoop as UiSomkaart

## The answer strip that hangs on the docked card, or `null`.
##
## `Hits.Spot` is an inner class of the `Hits` script and `Hits` is reached by
## its autoload name, not by a `class_name`, so the spot is held untyped here.
func balk_strook_node() -> Control:
	if _balk_kaart == "":
		return null
	var s = Hits.spot(_balk_kaart + "_keuzes")
	if s == null:
		return null
	var knoop = s.knoop
	return (knoop as Control) if knoop != null and is_instance_valid(knoop) else null

## The real minimum size of a card, help line included.
##
## A `Label` under `AUTOWRAP_WORD_SMART` reports its LONGEST WORD as its
## minimum width, so an unwrapped help line inflates the card's own minimum
## into a tower of one word per line — 551 units for a card that draws 114.
## The theme's `wrap_hoogte()` is the honest measure, at the width the card
## is actually drawn.
func kaart_mat(k: UiSomkaart) -> Vector2:
	# `Hits` writes the size it placed a card at back into
	# `custom_minimum_size` (hits.gd:418), so a card that was once measured
	# while its help line was laid out at a narrow width carries that number
	# forever.  Clear the pin for the measure or the card can never shrink
	# again, and the second question of the zwembad turn is 40 units taller
	# than the first for no reason at all.
	var pin := k.custom_minimum_size
	k.custom_minimum_size = Vector2.ZERO
	var hulp := k.hulp_label
	var was := hulp != null and hulp.visible
	if hulp != null:
		hulp.visible = false
	var m := k.get_combined_minimum_size()
	if hulp != null:
		hulp.visible = was
		if was:
			m.y += UiThema.wrap_hoogte(hulp, maxf(60.0, m.x - 24.0)) + 4.0
	k.custom_minimum_size = pin
	return m

func _strook_mat() -> Vector2:
	var s := balk_strook_node()
	return s.get_combined_minimum_size() if s != null else Vector2.ZERO

## What the docked card and its strip need, in frame units, in the form the
## frame asks for.  `INF` when there is nothing to dock.
func balk_nodig() -> float:
	var k := balk_kaart_node()
	if k == null:
		return INF
	var km := kaart_mat(k)
	var sm := _strook_mat()
	if sm.y <= 0.0:
		return km.y + 2.0 * BALK_LUCHT
	if balk_vorm() == "laag":
		return maxf(km.y, sm.y) + 2.0 * BALK_LUCHT
	return km.y + BALK_GAT + sm.y + 2.0 * BALK_LUCHT

## The width the same stack needs.
func balk_breed_nodig() -> float:
	var k := balk_kaart_node()
	if k == null:
		return 0.0
	var km := kaart_mat(k)
	var sm := _strook_mat()
	if sm.y <= 0.0:
		return km.x + 2.0 * BALK_LUCHT
	if balk_vorm() == "laag":
		return km.x + sm.x + 3.0 * BALK_LUCHT
	return maxf(km.x, sm.x) + 2.0 * BALK_LUCHT

## What the bar costs the world RIGHT NOW: 0 while nothing is docked, and 0
## when the frame has no room for the card that would dock.  Never more than
## `balk_dak()`, and never less than the design height of the rung when it is
## on.  Cached; `_balk_herstel()` is what recomputes it.
func balk_kost() -> float:
	return _balk_kost

func balk_aan() -> bool:
	return _balk_kost > 0.0

## The paper itself.  Empty while the bar is off.
func balk_rect() -> Rect2:
	var k := World.kader_rect()
	if _balk_kost <= 0.0 or k.size.x < 1.0:
		return Rect2()
	return Rect2(Vector2(k.position.x, k.end.y - _balk_kost), Vector2(k.size.x, _balk_kost))

## Where a thing of `kind` ("kaart" | "keuzes") of size `maat` stands on the
## paper.  Everything is anchored to the BOTTOM edge of the bar and grows
## upward, so the strip of answer buttons is always the closest thing to the
## finger.  An empty Rect2 means "this does not belong in the bar".
func balk_plek(kind: String, maat: Vector2) -> Rect2:
	var b := balk_rect()
	if b.size.x < 1.0 or maat.x < 1.0 or maat.y < 1.0:
		return Rect2()
	var bodem := b.end.y - BALK_LUCHT
	if balk_vorm() == "laag":
		if kind == "kaart":
			return Rect2(Vector2(b.position.x + BALK_LUCHT, bodem - maat.y), maat)
		return Rect2(Vector2(b.end.x - BALK_LUCHT - maat.x, bodem - maat.y), maat)
	var strook := _strook_mat()
	if kind == "keuzes":
		return Rect2(Vector2(b.position.x + (b.size.x - maat.x) * 0.5,
			bodem - maat.y), maat)
	var verhang := (strook.y + BALK_GAT) if strook.y > 0.0 else 0.0
	return Rect2(Vector2(b.position.x + (b.size.x - maat.x) * 0.5,
		bodem - verhang - maat.y), maat)

## Decide again which card owns the bar and what it costs the frame.  This
## COMPUTES and caches; it does not tell the world.  `World.meet()` calls it
## between taking the new frame and fitting the room into it, because the fit
## has to know what the bar takes before the scale is taken — asking
## afterwards would mean two `kader_veranderd` per resize, the first one
## carrying a scale that is already wrong.
func balk_bepaal() -> float:
	# The owner is written down FIRST: `balk_nodig()` asks the card and the
	# strip what they measure, and both of them look up `_balk_kaart` to find
	# the strip.  Deciding after measuring would measure nothing.
	_balk_kaart = balk_kandidaat()
	var kost := 0.0
	if _balk_kaart != "":
		var nodig := balk_nodig()
		# Both ceilings apply, whichever is lower.  `balk_dak()` is the
		# owner's rule of a third; `balk_ruimte()` is the room's own claim.
		var plafond := minf(balk_dak(), balk_ruimte())
		var bodem := minf(balk_hoog(), plafond)
		if nodig <= plafond and balk_breed_nodig() \
				<= World.kader_rect().size.x - 2.0 * BALK_LUCHT:
			kost = clampf(nodig, bodem, plafond)
	if kost <= 0.0:
		_balk_kaart = ""
	_balk_kost = maxf(0.0, kost)
	return _balk_kost

## Recompute what the bar costs and hand the result to the world.  Called on
## the events that can change it — a card opening or closing, a sentence, a
## second sentence, a help line, an answer in the box — and from nowhere
## else.  `World.zet_balk()` returns straight away when the height is the
## same, so an event that changed nothing costs one minimum-size query.
## `_balk_tellingen` is what `test_balk.gd` watches: nothing may tick while
## the screen stands still.
func _balk_herstel() -> void:
	_balk_tellingen += 1
	if _balk_stil > 0:
		return
	_balk_pas()
	# One more settle at the end of the same frame.  A game is allowed to
	# tidy the card it just got — `games/voerkar/spel.gd` hides the som line
	# and the answer box right after `somkaart()` returns — and it owes the
	# bar no call for that.  A notification from inside the emit chain of a
	# pass lands here too and is remembered rather than obeyed, which is what
	# keeps that chain from recursing.
	if not _balk_bezig and not _balk_nameeting:
		_balk_nameeting = true
		call_deferred("_balk_na_meeting")


func _balk_na_meeting() -> void:
	_balk_nameeting = false
	if _balk_stil > 0:
		return
	_balk_pas()


## True while a pass is running, so the `kader_veranderd` chain it starts
## cannot start another one.
var _balk_bezig := false

## True while a deferred settle is already queued for this frame.
var _balk_nameeting := false

## One settle: compute what the bar costs and hand it to the world, and if
## the world's answer changed the very card being measured, settle again —
## four times at most.  `games/was/spel.gd` answers `kader_veranderd` by
## re-weighing its legend, and that calls `Kaart.regel2()`, which notifies
## the bar: without this guard that loop ran until the stack overflowed.
func _balk_pas() -> void:
	if _balk_bezig:
		return
	_balk_bezig = true
	for _pas in 4:
		var oud := _balk_kost
		World.zet_balk(balk_bepaal())
		if is_equal_approx(_balk_kost, oud):
			break
	_balk_bezig = false

## The open card with the highest `prio`, newest first among equals.  A card
## that is no longer in `_kaarten` (closed, or never opened through `Ui`) is
## not a candidate and is dropped from the list, so the bar can never be held
## up by a ghost.
func balk_kandidaat() -> String:
	var beste := ""
	var beste_prio := -2147483648
	var weg: Array[String] = []
	for i in range(_balk_volgorde.size() - 1, -1, -1):
		var id: String = _balk_volgorde[i]
		var k = _kaarten.get(id)
		if k == null or not is_instance_valid(k):
			weg.append(id)
			continue
		var s = Hits.spot(id)
		if s == null:
			weg.append(id)
			continue
		var prio := int(s.prio)
		if prio >= beste_prio:
			beste_prio = prio
			beste = id
	for id in weg:
		_balk_volgorde.erase(id)
	return beste

## Opened through `somkaart`, in opening order; the newest of equal priority
## wins, so `balk_kandidaat()` walks this backwards.
var _balk_volgorde: Array[String] = []

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

## Tests build several shells in one process; this forgets the last one.
func vergeet_scherm() -> void:
	_scherm = Vector2.ZERO

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
## `kind` is btn | drop | tag | naam | kaart | keuzes | wolk | bron.
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
	# Under 450 units of height the toast moves to the top of the frame, out of
	# the way of the card and its strip (art-sound-rules.md §16.8).
	var boven := band.size.y < 450.0
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

func _process(delta: float) -> void:
	# Nothing about the bar is measured here.  It used to be, and that meant a
	# minimum-size query on the docked card in EVERY frame a sum was open —
	# and because `kaart_mat()` also flips the help rule and clears
	# `custom_minimum_size`, every one of those frames re-laid the card out.
	# The bar is event-driven now: `somkaart`, the card's `on_weg`, and the
	# `Kaart` setters that can change its shape each call `_balk_herstel()`.
	# A resize is not missing from that list on purpose — `World.meet()` asks
	# `Ui.balk_bepaal()` itself BEFORE it computes the new frame, and asking
	# again from `kader_veranderd` would feed the frame's own height back into
	# the bar's ceiling (0.34 of a frame the bar just shrank) and let the two
	# chase each other.
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
		"voortgang": o.get("voortgang", null),
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
## sentence, the sum line, and one strip of choices glued 5 units under it at
## any scale (world.md §5.5).
##
## Every answer is a tap on the strip — there is no keypad and no ✓ (owner,
## 2026-09-14).  A game gives either its own `keuzes` (at most four, pictogram
## AND word) or the right number in `goed`: then the strip carries four numbers
## from `Afleiders.vier` (plus `liever`, the slips the game expects, and `min`),
## the tapped number lands in the answer box and `on_ok(n, kaart)` is called at
## once.  `max` is the digit budget of the box and the ceiling of the numbers.
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
	var vak := keuzes.is_empty()
	if keuzes.is_empty() and o.has("goed"):
		keuzes = _getal_keuzes(id, int(o["goed"]), kaart, o)
	elif keuzes.is_empty() and kaart.on_ok.is_valid():
		push_warning('somkaart "%s" heeft on_ok maar geen goed of keuzes: er valt niets te kiezen' % id)
	if keuzes.size() > MAX_KEUZES:
		push_warning('somkaart "%s" heeft %d keuzes; hooguit %d' % [id, keuzes.size(), MAX_KEUZES])
		keuzes = keuzes.slice(0, MAX_KEUZES)
	var plek: Dictionary = _mik_van(obj, o)
	var spot := {
		"id": id, "kind": "kaart", "kamer": kaart.kamer,
		"vlak": o.get("vlak", _vlak_van(plek, kaart.kamer)),
		"x": plek.get("x", 0.0), "z": plek.get("z", 0.0), "y": o.get("hoog", 22.0),
		"op": "midden", "vast": true, "prio": o.get("prio", 14),
		"door": kaart.door, "titel": o.get("titel", ""),
		"icoon": o.get("icoon", ""), "regel": o.get("regel", ""),
		"regel2": o.get("regel2", ""), "som": som,
		"max": kaart.max_cijfers, "keuzes": keuzes, "vak": vak,
		"on_weg": func(_s) -> void:
			_kaarten.erase(id)
			# The bar lets go of the card the moment it goes, and the world
			# takes back what it gave.  This is the line whose absence made
			# `0ba9e63` fail: a card that closed left the bar grown forever.
			_balk_herstel(),
	}
	if o.has("volg"):
		spot["volg"] = o["volg"]
	# `Hits.maak` first: a spot with the same id is removed and its `on_weg`
	# erases that id — only then may the new card be remembered (I2, hinkel).
	# `_balk_stil` keeps that removal from dropping the bar to zero and back up
	# again inside one call: the world is told once, at the end.
	_balk_stil += 1
	Hits.maak(spot)
	_kaarten[id] = kaart
	if not _balk_volgorde.has(id):
		_balk_volgorde.append(id)
	_balk_stil -= 1
	_balk_herstel()
	kaart_geopend.emit(id)
	keur_regel(id, o.get("regel", ""))
	if not str(o.get("regel2", "")).is_empty():
		keur_regel(id + " (regel2)", o.get("regel2", ""))
	if not keuzes.is_empty():
		kaart.strook_id = id + "_keuzes"
		_balk_stil += 1
		Hits.maak({
			"id": kaart.strook_id, "kind": "keuzes", "kamer": kaart.kamer,
			"x": plek.get("x", 0.0), "z": plek.get("z", 0.0), "y": o.get("hoog", 22.0),
			"vast": true, "prio": 13, "door": kaart.door,
			"kleef_aan": id, "keuzes": keuzes, "kaart": kaart,
			"titel": o.get("keuze_titel", "kies er een"),
		})
		_balk_stil -= 1
		_balk_herstel()
	return kaart

## At most this many buttons on one strip (owner, 2026-09-14).
const MAX_KEUZES := 4

## The four number buttons of a card with `goed`: pictogram and number in one
## button (HOTEL.md §9), the tapped number in the box, `on_ok` straight away.
## The seed is the card, the answer and the day, so a slip brings the same
## strip back and a reload draws the same one.
func _getal_keuzes(id: String, goed: int, kaart: Kaart, o: Dictionary) -> Array:
	var dag: int = int(State.s.get("dag", 1)) if State.s is Dictionary else 1
	var zaad: int = int(o.get("zaad", (hash(id) % 100003) + dag * 17))
	var plafond: int = int(pow(10, kaart.max_cijfers)) - 1
	var getallen := Afleiders.vier(goed, zaad,
		{"min": o.get("min", 0), "max": o.get("max_getal", plafond), "liever": o.get("liever", [])})
	var icoon := str(o.get("icoon", ""))
	var uit: Array = []
	for g in getallen:
		var n: int = g
		uit.append({"id": "n%d" % n, "icoon": icoon, "tekst": str(n), "kort": str(n),
			"titel": str(n),
			"kies": func(_k, k: Kaart) -> void:
				k.zet(str(n))
				k.zet_goed(false)
				roep(k.on_ok, [n, k])})
	return uit

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
	var kamer := ""
	var door := ""
	var max_cijfers := 2
	var on_ok: Callable
	var _getikt := ""            ## what the child chose, never what a game wrote

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
			# a different sentence wraps to a different number of lines
			Ui._balk_herstel()

	func regel2(zin: String) -> void:
		var k := _knoop()
		if k != null:
			k.zet_regel2(zin)
			if not zin.is_empty():
				Ui.keur_regel(id + " (regel2)", zin)
			# a whole second line appears or disappears
			Ui._balk_herstel()

	func som(tekst: String) -> void:
		var k := _knoop()
		if k != null and k.som_label != null:
			k.som_label.text = tekst
			Ui._balk_herstel()

	func zet(tekst: String) -> void:
		_getikt = tekst
		var k := _knoop()
		if k != null and k.vak_label != null:
			k.vak_label.text = tekst
			Ui._balk_herstel()

	func hulp(tekst: String) -> void:
		var k := _knoop()
		if k == null or k.hulp_label == null:
			return
		# The help line is the one thing that changes the height of a card
		# after it opened, so it is the one thing the bar of §3.1 has to
		# follow.  It never reads this label's own minimum: an autowrap
		# Label reports the height at whatever width it last had, and a
		# card whose help line arrived before its first frame answers 631
		# units for "Tel de ballen: 3 en nog 2".  `Ui.kaart_mat()` asks
		# the theme instead, at the width the card is really drawn at.
		k.hulp_label.text = tekst
		k.hulp_label.visible = not tekst.is_empty()
		Ui._balk_herstel()

	func getal() -> Variant:
		if _getikt.is_empty() or not _getikt.is_valid_int():
			return null
		return _getikt.to_int()

	func zet_goed(goed: bool) -> void:
		var k := _knoop()
		if k != null:
			k.zet_goed(goed)

	## Tick the card: the strip goes, the card stays readable.
	func klaar() -> void:
		if strook_id != "":
			Hits.weg(strook_id)
			strook_id = ""
		var k := _knoop()
		if k != null:
			k.zet_goed(true)
			k.zet_af()
		zet("✓")
		# the strip that set the bar's width is gone
		Ui._balk_herstel()

	func weg() -> void:
		if strook_id != "":
			Hits.weg(strook_id)
			strook_id = ""
		Hits.weg(id)

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
