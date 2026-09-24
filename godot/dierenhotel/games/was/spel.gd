extends MiniGame
## G4 — DE WASMANDTOREN (`was`), games-b.md §4.
##
## In the wasserij a pile of washing lies on the floor; against the back corner
## stand two to four crates, each with its own pictogram.  Every piece that
## goes into the right crate becomes a block on a stack, so the crates together
## grow into a real bar chart.  Once the pile is empty one question card joins
## the crates and the sum is about that chart.
##
## What is ported unchanged: the numbers (`Sommen.Was.*`), every Dutch string,
## the never-punishing rule, and the two layout rules C1 and C2 of §4.6.  The
## help ladder is GONE (owner, 2026-09-24: "Nee geef geen hulp na fouten.
## Kinderen moeten zelf leren rekenen"): a wrong answer on the chart, or a
## piece in the wrong crate, is seen — `🔄 Nog een keer`, the strip locked for
## a moment, the crate bouncing — and nothing more: no counting line, no
## pointer to the highest stack, no ghost numbers on the crates or the pile.
##
## What is NOT ported is HOW those two layout rules are enforced: the
## HTML read `Hits.debug()` and the DOM eight times over 2.65 s, because the
## button layer only placed in the next paint.  Here `World`'s projection is a
## closed form and a Control measures itself synchronously, so `WasIndeling`
## SOLVES the bench height, the block height and the plate word in one pass,
## before the first draw, and again only when the frame really changes.

const KAMER := "wasserij"

## Loose decor, models and hotspots.  Every model name carries the game id
## (architecture.md §13, Q-X1-11).
const MODEL_KRAT := "was_krat"
const MODEL_BERG := "was_berg"
const DECOR_BERG := "was_berg"
const HOT_BERG := "ws_berg"
const HOT_HAND := "ws_hand"
const HOT_LEGENDA := "ws_legenda"
const HOT_KAART := "ws_vraag"
const SLEEP := "krat"
const LEGENDA := "📦 Elk blokje is 2 stuks"
## The pile gets the broom.  The basket 🧺 is the pictogram of the kind
## "doeken" (`WasSoorten.LIJST[2]`), and a child who is asked "hoeveel
## doeken?" and sees 🧺 on the pile and 🧺 on the crate reads two different
## things with the same picture.  The broom is the pile, nothing else.
const BERG_ICOON := "🧹"
## Group 5's opening sum (N8): the count on the pile is the given, the blocks
## it makes are the answer.  Groups 3 and 4 opened with `Hoeveel stuks liggen
## er?` and every group had `Hoeveel liggen er nog?` halfway, but the pile is a
## heap of at most eight tufts: the only way to answer either was to read the
## number on the pile, which was the answer itself.  Both are gone (owner,
## 2026-09-24: "Haal die hints weg").
const VRAAG_BLOK := "Hoeveel blokjes worden dat?"

## Where things stand (games-b.md §4.4), as a fraction of the room.
const BERG_F := Vector2(0.60, 0.60)      ## (60, 54) — in front of the row
const RUST_BERG := 12                     ## the resting pile: six pieces of washing
const KAART_F := Vector2(0.88, 0.933)    ## (88, 84) — further forward still
const LEGENDA_F := Vector2(0.12, 0.30)   ## (12, 27)
## The card aims at the FLOOR of its point: the lower its aim, the further it
## stays from the bar chart at the back (C2 of games-b.md §4.6).
const KAART_HOOG := 0.0
const GROND := 0.347                     ## the ground line: round(190 * 0.347) = 66

## The crate bounces once, three voxels, in a little over a quarter second.
## The state lives here and NOT in the decor record, because `_teken()` rewrites
## every record on every tap and would put a loose `hoog: 3` straight back to 0.
const WIP := [[0.140, 2], [0.060, 1], [0.060, 0]]

var _s: Dictionary = {}
var _kaart: Ui.Kaart = null
var _kader_af: Callable = Callable()
var _voet := WasSoorten.VOET
var _stap := WasSoorten.STAP
var _tier := WasIndeling.TIER_WOORD
var _wip_krat := -1
var _wip_hoog := 0
var _t0 := 0
## Did the last solve manage C2 (no block behind the card)?  On a frame that
## cannot do both, C1 wins and this says so out loud (games-b.md §4.6).
var _c2 := true
## What the child last handed in, for the browser probe only.
var _getikt := -1

# ----------------------------------------------------------------- aanmelding

func definitie() -> Dictionary:
	return {
		"naam": "Wasmandtoren",
		"kamer": KAMER,
		"stub": false,
		# There is no fixed "pile of washing" in `rooms.gd` and loose decor only
		# exists once the game runs, so the entry button hangs on the wash tub
		# with a nudge to where the pile will be: (80,74) − (20,20) = (60,54).
		"hotspot": {"obj": "tobbe", "icoon": "🧺", "label": "Was sorteren",
			"hoog": 14, "dx": -20, "dz": -20, "rust": "rust_was_berg"},
		# The pile of washing stays on the bath mat while nobody sorts (owner,
		# 2026-09-23: "Dan hangt elk spel aan iets wat je echt ziet"); the
		# crates come with a turn.
		"modellen": {MODEL_KRAT: WasSoorten.krat, MODEL_BERG: WasSoorten.berg},
		"rust": [{"id": "rust_was_berg", "model": MODEL_BERG,
			"x": _plek(BERG_F).x, "z": _plek(BERG_F).y, "params": {"n": RUST_BERG}}],
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		# always available, low priority: the animals' wishes and the other
		# chores sit on 0 … 5
		"taak": {"id": "was", "icoon": "🧺", "tekst": "Was sorteren", "prio": 8},
	}

# ------------------------------------------------------------- start en stop

func start(_c: SpelCtx) -> void:
	Art.registreer_model(MODEL_KRAT, WasSoorten.krat)
	Art.registreer_model(MODEL_BERG, WasSoorten.berg)
	var d := ctx.data()
	var n: int = maxi(1, ctx.state.n_gasten())
	var band: int = ctx.state.band()
	var dag: int = maxi(1, int(ctx.state.s.get("dag", 1)))
	var bewaard = d.get("stand", null)
	_s = _herstel(bewaard, n, band, dag)
	if _s.is_empty():
		_s = _nieuwe_stand(n, band, dag)
	d["stand"] = _s
	_t0 = Time.get_ticks_msec()
	_wip_krat = -1
	_wip_hoog = 0
	_voet = WasSoorten.VOET
	_stap = WasSoorten.STAP
	_tier = WasIndeling.TIER_WOORD
	_kaart = null
	if not _kader_af.is_valid():
		_kader_af = ctx.ui.op_kader(_op_kader)
	_teken()
	if _stap_nu() != "sorteren":
		_vraag_kaart()
	_regel_indeling()
	State.bewaar()
	_meld("start")

func stop() -> void:
	_wip_krat = -1
	_wip_hoog = 0
	if _kader_af.is_valid():
		_kader_af.call()
		_kader_af = Callable()
	if ctx != null:
		if not _s.is_empty():
			ctx.data()["stand"] = _s
		ctx.hotspots.wis_alles()
		ctx.hotspots.laat()
		ctx.wereld.decor_wis_alles()
		State.bewaar()
	_kaart = null
	_s = {}

## The saved turn is reused only when it exists, has a row and boxes, is not
## finished, and the day, the guest count and the band still agree.  Numbers
## come back from JSON as floats, so everything is read as an int here — once,
## and never again below.
func _herstel(bewaard, n: int, band: int, dag: int) -> Dictionary:
	if typeof(bewaard) != TYPE_DICTIONARY:
		return {}
	var b: Dictionary = bewaard
	if str(b.get("stap", "")) == "af" or not b.has("rij") or not b.has("vak"):
		return {}
	if int(b.get("dag", -1)) != dag or int(b.get("N", -1)) != n or int(b.get("band", -1)) != band:
		return {}
	var rij := _ints(b.get("rij", []))
	var vak := _ints(b.get("vak", []))
	var doel := _ints(b.get("doel", []))
	var m := int(b.get("m", vak.size()))
	if rij.is_empty() or vak.size() != m or doel.size() != m or m < 2:
		return {}
	var i: int = clampi(int(b.get("i", 0)), 0, rij.size())
	return {"dag": dag, "N": n, "band": band,
		"k": int(b.get("k", 0)), "r": int(b.get("r", 0)), "T": int(b.get("T", 0)),
		"per": maxi(1, int(b.get("per", 1))), "m": m, "doel": doel, "rij": rij,
		"i": i, "vak": vak, "hand": int(b.get("hand", -1)),
		"stap": _stap_van(str(b.get("stap", "")), band),
		"missers": maxi(0, int(b.get("missers", 0))), "ster": int(b.get("ster", 0))}

## Only group 5 opens with a question; the others start sorting at once.
static func _eerste_stap(band: int) -> String:
	return "vraag0" if band == 5 else "sorteren"

## A saved step that no longer exists goes back to the sorting: the opening
## question of groups 3 and 4 and the one halfway (`vraagT`) of an old save.
static func _stap_van(stap: String, band: int) -> String:
	if stap == "vraag0":
		return _eerste_stap(band)
	if stap in ["sorteren", "vraag1", "vraag2"]:
		return stap
	if stap == "vraagT":
		return "sorteren"
	return _eerste_stap(band)

func _nieuwe_stand(n: int, band: int, dag: int) -> Dictionary:
	var q := Sommen.Was.recept(n, band, dag)
	var m := int(q["m"])
	var vak: Array[int] = []
	for _i in m:
		vak.append(0)
	return {"dag": int(q["dag"]), "N": int(q["N"]), "band": int(q["band"]),
		"k": int(q["k"]), "r": int(q["r"]), "T": int(q["T"]), "per": int(q["per"]),
		"m": m, "doel": _ints(q["blok"]), "rij": _ints(q["rij"]),
		"i": 0, "vak": vak, "hand": -1, "stap": _eerste_stap(int(q["band"])),
		"missers": 0, "ster": 0}

static func _ints(bron) -> Array[int]:
	var uit: Array[int] = []
	if typeof(bron) == TYPE_ARRAY:
		for v in bron:
			uit.append(int(v))
	return uit

# ------------------------------------------------------------ de stand lezen

func _stap_nu() -> String:
	return str(_s.get("stap", "sorteren"))

func _per() -> int:
	return maxi(1, int(_s.get("per", 1)))

func _m() -> int:
	return int(_s.get("m", 0))

func _vak() -> Array:
	return _s.get("vak", [])

func _missers() -> int:
	return int(_s.get("missers", 0))

func _hand() -> int:
	return int(_s.get("hand", -1))

## Blocks still on the pile — one per tap.
func _over_berg() -> int:
	var rij: Array = _s.get("rij", [])
	return maxi(0, rij.size() - int(_s.get("i", 0)))

## Pieces still on the pile.
func _stuks_over() -> int:
	return _over_berg() * _per()

## Does the pile say how many pieces lie on it?  Only in group 5, where that
## count is the given of the opening sum.  In groups 3 and 4 no question needs
## it, and in group 4 it is the answer to `Hoeveel stuks samen?` at the end.
func _toont_aantal() -> bool:
	return int(_s.get("band", 3)) == 5

func _stuks(i: int) -> int:
	return int(_vak()[i]) * _per()

func _samen() -> int:
	var n := 0
	for i in _m():
		n += _stuks(i)
	return n

func _hoogste_idx() -> int:
	var b := 0
	for i in range(1, _m()):
		if int(_vak()[i]) > int(_vak()[b]):
			b = i
	return b

func _laagste_idx() -> int:
	var b := 0
	for i in range(1, _m()):
		if int(_vak()[i]) < int(_vak()[b]):
			b = i
	return b

## The right answer to the question that is open right now.
func _antwoord_nu() -> int:
	if _stap_nu() == "vraag0":
		return _vraag0_goed()
	if int(_s.get("band", 3)) == 3:
		return _hoogste_idx()
	if _stap_nu() == "vraag1":
		if int(_s["band"]) == 4:
			return _stuks(_hoogste_idx()) - _stuks(_laagste_idx())
		return _stuks(_hoogste_idx())          # group 5: blocks x 2
	if int(_s["band"]) == 4:
		return _samen()
	return _stuks(_hoogste_idx()) - _stuks(_laagste_idx())

## The opening sum of group 5: the whole pile in blocks of two.  `Sommen.Was`
## guarantees an even `T` where `per == 2`, so this never rounds.
func _vraag0_goed() -> int:
	return int(int(_s.get("T", 0)) / 2)

# ------------------------------------------------------------- waar staat wat

## The crates stand on one line of EQUAL DEPTH in the back corner — on screen a
## straight horizontal ground line.  Only then do the stacks stand at the same
## floor height and is it really a bar chart; a row along one wall would be a
## steep diagonal on screen and there would be nothing left to compare.
func _krat_plek(m: int, i: int) -> Vector2:
	var r := Rooms.get_kamer(KAMER)
	var w := 100.0 if r == null else float(r.w)
	var diep := 90.0 if r == null else float(r.d)
	var som := float(JsGetal.rond((w + diep) * GROND))
	var stap := 16.0 if m > 3 else 22.0
	var x := float(JsGetal.rond(som / 2.0 - 4.0 + (float(i) - float(m - 1) / 2.0) * stap))
	return Vector2(x, som - x)

func _krat_id(i: int) -> String:
	return "%s%d" % [MODEL_KRAT, i]

func _krat_hot(i: int) -> String:
	return "ws_k%d" % i

## The top of a stack in voxels; the plate hangs above it (`op: "boven"`), so
## the plate never covers the chart.
func _krat_y(i: int) -> int:
	return _voet + 4 + _stap * int(_vak()[i] if i < _vak().size() else 0)

func _plek(f: Vector2) -> Vector2:
	var p := Rooms.plek(KAMER, f.x, f.y)
	return Vector2(float(p.get("x", 0)), float(p.get("z", 0)))

# ------------------------------------------------------------------- tekenen

func _teken() -> void:
	if ctx == null or _s.is_empty():
		return
	_zet_decor()
	_teken_kratten()
	var stap := _stap_nu()
	if stap == "sorteren":
		_teken_berg()
	elif stap == "vraag0":
		# The pile has to be SEEN for the question to be about it, but it may
		# not be touched yet: the child answers first and sorts after.
		_teken_berg(true)
	else:
		_berg_weg()
	_teken_legenda()
	ctx.wereld.vuil()

func _zet_decor() -> void:
	var p := _plek(BERG_F)
	ctx.wereld.decor(KAMER, {"id": DECOR_BERG, "model": MODEL_BERG,
		"x": p.x, "z": p.y, "params": {"n": _over_berg()}})
	for i in _m():
		_zet_krat(i)

func _zet_krat(i: int) -> void:
	var q := _krat_plek(_m(), i)
	ctx.wereld.decor(KAMER, {"id": _krat_id(i), "model": MODEL_KRAT,
		"x": q.x, "z": q.y, "hoog": float(_wip_hoog if i == _wip_krat else 0),
		"params": {"soort": i, "n": int(_vak()[i]), "voet": _voet, "stap": _stap}})

func _teken_kratten() -> void:
	var m := _m()
	var k := float(World.schaal().get("k", 1.0))
	for i in m:
		var idx := i
		var q := _krat_plek(m, idx)
		var so := WasSoorten.soort(idx)
		var n := int(_vak()[idx])
		ctx.hotspots.maak({
			"id": _krat_hot(idx), "kamer": KAMER, "x": q.x, "z": q.y,
			"y": float(_krat_y(idx)),
			# the plate hangs on the BAR, not on the bench under it, and on the
			# anchor rect that turns `rand`'s tenth into GAT units of air
			"vlak": WasIndeling.anker_vlak(World.mik_punt(q.x, q.y, 0.0), k,
				_voet, _stap, n),
			"icoon": str(so["ico"]), "label": _plaat_tekst(idx, _tier),
			# every crate stands at the same depth (x + z); with its own `d`
			# they keep the same left-to-right order every pass
			"d": q.x + q.y + float(idx) / 100.0,
			# `vast` + `op: "rand"`: the plate stands right above ITS crate, is
			# centred exactly on it and steps UP a whole band when that place is
			# taken — never down (C1).  `prio` puts it ahead of the card and the
			# keypad, so it takes its own band first and they give way, exactly
			# as the HTML's `vast: true` meant (games-b.md §4.6).
			"op": "rand", "vast": true, "kind": "drop", "drop": SLEEP,
			"data": {"i": idx}, "prio": 16,
			"titel": "krat met %s: %d %s" % [str(so["naam"]), n,
				"blokje" if n == 1 else "blokjes"],
			"aan": func(_spot) -> void: _leg_in(idx),
			"val": func(_lading, data) -> void: _sleep_in(int(data.get("i", -1))),
		})

## The word on the plate: whole, short, or the pictogram on its own.
func _plaat_tekst(i: int, tier: int) -> String:
	var so := WasSoorten.soort(i)
	if tier >= WasIndeling.TIER_WOORD:
		return str(so["naam"])
	if tier == WasIndeling.TIER_EV:
		return str(so["ev"])
	return ""

## The pile is a drag source with a counter.  The COUNT belongs to the pile
## ("🧺 26 nog te sorteren") and what you hold belongs to your hands
## ("🧦 twee sokken"): together in one button a child read it as "🧦 26 twee
## sokken" (games-b.md §4.7).
func _teken_berg(stil := false) -> void:
	var stuks := _stuks_over()
	var per := _per()
	ctx.hotspots.bron(DECOR_BERG, {
		"id": HOT_BERG, "kamer": KAMER, "icoon": BERG_ICOON,
		# `aantal: 0` is what makes a source undraggable (`UiBron._get_drag_data`),
		# so during the opening sum the child can look at the pile and read it,
		# but not yet empty it.
		"aantal": 0 if stil else stuks, "hand": 0,
		"hoog": 18.0, "prio": 11, "klas": "hotwolk",
		"titel": _berg_titel(stuks, per, stil),
		# dragging picks up on the way: the drag starts on the pile, so the top
		# piece is already in your hand when you arrive at the crate
		"sleep": SLEEP, "data": {},
		"tik": func(_spot) -> void: _pak(),
	})
	_kleed_berg(stuks, per, stil)
	if stil:
		return
	var hand := _hand()
	if hand < 0:
		ctx.hotspots.weg(HOT_HAND)
		return
	# The hand bubble hangs LOW at the pile (`hoog` 2), so it never gets in the
	# way of the plates above the stacks.
	ctx.ui.wolk({"id": HOT_HAND, "kamer": KAMER, "hoog": 2.0, "prio": 9,
		"klas": "goed", "x": _plek(BERG_F).x, "z": _plek(BERG_F).y,
		"icoon": str(WasSoorten.soort(hand)["ico"]), "tekst": _hand_tekst(),
		"tik": func(_spot) -> void: _pak()})

## `UiBron` draws a bare pictogram with two number pills.  This game needs the
## sentence in the same button as the pictogram (HOTEL.md §9), so the count goes
## into the button's own text and the drag handle ("pak 2") joins the pill row.
## No other game is touched: this is one Control, built for this game by `Ui`.
func _kleed_berg(stuks: int, per: int, stil := false) -> void:
	var b := Ui.bron_van(HOT_BERG)
	if b == null:
		return
	if _toont_aantal():
		b.text = "%s %d" % [BERG_ICOON, stuks] if _berg_kort \
			else "%s %d nog te sorteren" % [BERG_ICOON, stuks]
	else:
		b.text = BERG_ICOON if _berg_kort else "%s nog te sorteren" % BERG_ICOON
	b.zet(0, 0)                      # the pills stay out: the count is in the sentence
	var rij := b.get_node_or_null("Tellers")
	if rij == null:
		return
	var greep := rij.get_node_or_null("Greep") as Label
	if greep == null:
		greep = Label.new()
		greep.name = "Greep"
		greep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		greep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		greep.add_theme_font_size_override("font_size", UiThema.VLOER)
		greep.add_theme_color_override("font_color", UiThema.INKT)
		greep.add_theme_stylebox_override("normal",
			UiThema.vulling(UiThema.vlak(UiThema.MUNT, 999, 2, UiThema.WIT), 6, 0))
		rij.add_child(greep)
	greep.text = "pak %d" % per
	# During the opening sum the pile cannot be emptied (`aantal` is 0),
	# so a handle that says "pak 2" would be a button that lies.  It goes away
	# with the drag, and the pile takes one pill-row less height with it.
	greep.visible = not stil
	# a Button never measures its children, so the pill row is added by hand
	var pil_h := 0.0 if stil else greep.get_combined_minimum_size().y
	b.custom_minimum_size = Vector2(UiThema.HOT, float(UiThema.HOT) + pil_h)

## The pile's tooltip carries its count only where the pile itself shows it.
func _berg_titel(stuks: int, per: int, stil: bool) -> String:
	if stil:
		return "berg met %d stuks was, kijk er goed naar" % stuks
	if _toont_aantal():
		return "berg met %d stuks was, tik om er %d te pakken" % [stuks, per]
	return "berg met was, tik om er %d te pakken" % per

func _hand_tekst() -> String:
	var so := WasSoorten.soort(_hand())
	return "een %s" % str(so["ev"]) if _per() == 1 else "twee %s" % str(so["naam"])

func _berg_weg() -> void:
	ctx.hotspots.weg(HOT_BERG)
	ctx.hotspots.weg(HOT_HAND)
	ctx.wereld.decor(KAMER, {"id": DECOR_BERG, "model": MODEL_BERG,
		"x": _plek(BERG_F).x, "z": _plek(BERG_F).y, "params": {"n": 0}})

## While sorting always; during the question only when the legend does not fit
## on the card itself.
func _teken_legenda() -> void:
	var wil := _per() == 2 and _stap_nu() != "af" and _legenda_wolk \
		and (_stap_nu() == "sorteren" or not _legenda_op_kaart())
	if not wil:
		ctx.hotspots.weg(HOT_LEGENDA)
		return
	var p := _plek(LEGENDA_F)
	ctx.ui.wolk({"id": HOT_LEGENDA, "kamer": KAMER, "x": p.x, "z": p.y,
		"hoog": 20.0, "prio": 6, "icoon": "📦", "tekst": LEGENDA.substr(2).strip_edges()})

## The legend rides on the card only while it does not cost the bar chart.  The
## HTML decided this with `krapKader()` — two hard pixel thresholds per game,
## which architecture.md §13 Q-X3-13 replaced.  Here it is a measurement: the
## second line makes the card taller, the taller card reaches further up, and
## the moment a block would disappear behind it the legend becomes a bubble in
## the room instead (games-b.md §4.9).
var _legenda_kaart := true
## May the legend stand as a bubble in the room at all?  On a frame with no free
## cell left it would land on the bar chart, and then it hides the very blocks
## it explains.
var _legenda_wolk := true
## A shorter sentence on the pile when the long one no longer fits the frame.
var _berg_kort := false

func _legenda_op_kaart() -> bool:
	return _legenda_kaart

## Try the legend on the card; if that second line would hide a block, try it as
## a bubble in the room; and if the room has no place for it either, put it back
## on the card — without "elk blokje is 2 stuks" the group-5 question cannot be
## answered at all, and a bubble that lands on the chart hides the same blocks.
func _weeg_legenda(bodem: float) -> void:
	if _kaart == null or _per() != 2:
		return
	if _stap_nu() == "af" or _stap_nu() == "sorteren":
		return
	_legenda_kaart = true
	_kaart.regel2(LEGENDA)
	if _kaart_top() >= bodem - 0.01:
		return
	_kaart.regel2("")
	_legenda_kaart = false
	_teken_legenda()
	Hits.plaats()                     # synchronous; the HTML needed a paint
	var d := Hits.debug()
	if d.has(HOT_LEGENDA) and not bool(d[HOT_LEGENDA]["krap"]):
		return
	ctx.hotspots.weg(HOT_LEGENDA)
	_legenda_kaart = true
	_kaart.regel2(LEGENDA)

# ------------------------------------------------------------------ sorteren

func _pak() -> bool:
	if ctx == null or _s.is_empty() or _stap_nu() != "sorteren":
		return false
	var rij: Array = _s["rij"]
	var i := int(_s["i"])
	if i >= rij.size():
		return false
	if _hand() < 0:
		_s["hand"] = int(rij[i])
		ctx.snd.tik()
		State.bewaar()
	_teken()
	_meld("pak")
	return true

func _sleep_in(i: int) -> void:
	# whoever drags picks up on the way
	_pak()
	_leg_in(i)

func _leg_in(i: int) -> bool:
	if ctx == null or _s.is_empty() or _stap_nu() != "sorteren":
		return false
	if i < 0 or i >= _m():
		return false
	var rij: Array = _s["rij"]
	if int(_s["i"]) >= rij.size():
		return false
	# An empty hand on a crate does nothing: the pile lights up for a moment so
	# the child sees where to start.
	if _hand() < 0:
		ctx.snd.zacht()
		_wijs_berg_aan()
		return false
	var soort := _hand()
	_s["hand"] = -1
	if soort == i:
		_s["vak"][i] = int(_s["vak"][i]) + 1
		_s["i"] = int(_s["i"]) + 1
		ctx.snd.plop(1)
	else:
		ctx.snd.terug()
	State.bewaar()
	_teken()
	if soort != i:
		# the crate bounces and says `🔄 Nog een keer` — nothing about which
		# crate it should have been (owner, 2026-09-24)
		_wip(i)
		_mis_bij_krat(i)
	if int(_s["i"]) >= rij.size() and _stap_nu() == "sorteren":
		_klaar_met_sorteren()
	else:
		_meld("sorteer")
	return soort == i

## Sort the whole pile correctly — the test hook of the HTML (`doe('sorteer')`).
func sorteer_alles() -> int:
	var veilig := 0
	while not _s.is_empty() and _stap_nu() == "sorteren" \
			and int(_s["i"]) < (_s["rij"] as Array).size() and veilig < 200:
		veilig += 1
		_s["hand"] = int((_s["rij"] as Array)[int(_s["i"])])
		_leg_in(int(_s["hand"]))
	return 0 if _s.is_empty() else int(_s["i"])

func _wijs_berg_aan() -> void:
	var b := Ui.bron_van(HOT_BERG)
	if b == null:
		return
	b.add_theme_stylebox_override("normal",
		UiThema.vulling(UiThema.vlak(UiThema.WOLK_HULP, 16, 2, UiThema.WIT), 10, 6))
	if not await na(0.32):
		return
	if is_instance_valid(b):
		b.remove_theme_stylebox_override("normal")

## A piece in the wrong crate, seen: the same `🔄 Nog een keer` as every miss
## in the hotel, at that crate, for as long as a miss pauses a strip.  This
## game has no animal of the turn to sulk (games-b.md §0.12), and while the
## child sorts there is no card either, so the bubble hangs at the crate.
func _mis_bij_krat(i: int) -> void:
	var id := Ui.MIS_WOLK + _krat_id(i)
	var q := _krat_plek(_m(), i)
	ctx.ui.wolk({"id": id, "kamer": KAMER, "x": q.x, "z": q.y,
		"hoog": float(_krat_y(i) + 6), "prio": 12,
		"icoon": UiTekst.MIS_ICOON, "tekst": UiTekst.MIS_ZIN})
	if not await na(Ui.MIS_PAUZE):
		return
	ctx.ui.wolk_weg(id)
	ctx.wereld.vuil()

## The crate bounces: a soft "no" without a word and without red.
func _wip(i: int) -> void:
	if ctx == null or _s.is_empty():
		return
	_wip_krat = i
	_wip_hoog = 3
	_zet_krat(i)
	for stap in WIP:
		if not await na(float(stap[0])):
			return
		if ctx == null or _s.is_empty() or _wip_krat != i:
			return
		_wip_hoog = int(stap[1])
		if _wip_hoog == 0:
			_wip_krat = -1
		_zet_krat(i)
		ctx.wereld.vuil()

func _klaar_met_sorteren() -> void:
	_s["stap"] = "vraag1"
	_s["missers"] = 0
	_t0 = Time.get_ticks_msec()
	ctx.snd.ja()
	State.bewaar()
	_teken()
	_vraag_kaart()
	_regel_indeling()
	_meld("vraag")

# -------------------------------------------------------------- de vragen

func _keuze_strook() -> Array:
	var uit: Array = []
	for i in _m():
		var idx := i
		var so := WasSoorten.soort(idx)
		uit.append({"id": str(so["id"]), "icoon": str(so["ico"]),
			"tekst": str(so["naam"]), "kort": str(so["ev"]),
			"kies": func(_id, _k) -> void: _kies(idx)})
	return uit

func _vraag_kaart() -> Ui.Kaart:
	if ctx == null or _s.is_empty():
		return null
	if _kaart != null:
		_kaart.weg()
		_kaart = null
	var plek := _plek(KAART_F)
	var obj := {"x": plek.x, "z": plek.y}
	var band := int(_s.get("band", 3))
	_t0 = Time.get_ticks_msec()
	if _stap_nu() == "af":
		_kaart = ctx.ui.somkaart(obj, "", {
			"id": HOT_KAART, "kamer": KAMER, "hoog": KAART_HOOG, "icoon": "✅",
			"regel": "Alles gesorteerd!", "keuze_titel": "klaar",
			"keuzes": [{"id": "ok", "icoon": "👍", "tekst": "klaar",
				"kies": func(_id, _k) -> void: ctx.sluit()}]})
		_regel_indeling()
		return _kaart
	# Group 5's opening sum (N8), before a single piece moves: the pile says
	# how many pieces, the card asks how many blocks.  The legend rides along
	# on the card, because without it the question is unanswerable.
	if _stap_nu() == "vraag0":
		_kaart = ctx.ui.somkaart(obj, "", {"id": HOT_KAART, "kamer": KAMER,
			"hoog": KAART_HOOG, "icoon": "📊", "goed": _vraag0_goed(),
			"regel": VRAAG_BLOK, "regel2": LEGENDA,
			"on_ok": func(n, k) -> void: _antwoord(n, k)})
		_regel_indeling()
		return _kaart
	if band == 3:
		_kaart = ctx.ui.somkaart(obj, "", {
			"id": HOT_KAART, "kamer": KAMER, "hoog": KAART_HOOG, "icoon": "📊",
			"regel": "Welke stapel is het hoogst?",
			"keuze_titel": "kies een stapel", "keuzes": _keuze_strook()})
		_regel_indeling()
		return _kaart
	var h := _hoogste_idx()
	var l := _laagste_idx()
	var som := ""
	var o := {"id": HOT_KAART, "kamer": KAMER, "hoog": KAART_HOOG, "icoon": "📊",
		"max": 2, "goed": _antwoord_nu(), "liever": [_stuks(h), _stuks(l), _samen()],
		"on_ok": func(n, k) -> void: _antwoord(n, k)}
	if band == 4:
		if _stap_nu() == "vraag1":
			o["regel"] = "Hoeveel meer %s dan %s?" % [str(WasSoorten.soort(h)["naam"]),
				str(WasSoorten.soort(l)["naam"])]
			som = "%d − %d =" % [_stuks(h), _stuks(l)]        # U+2212, the real minus
		else:
			o["regel"] = "Hoeveel stuks samen?"
			var delen: Array[String] = []
			for i in _m():
				delen.append(str(_stuks(i)))
			som = "%s =" % " + ".join(delen)
	else:
		# group 5: the blocks come in twos, so the conversion IS the sum.  The
		# legend is the second short line on the card itself; on a narrow frame
		# it would push the chart behind the card, and then it is a bubble.
		if _stap_nu() == "vraag1":
			o["regel"] = "Hoeveel %s zijn het?" % str(WasSoorten.soort(h)["naam"])
		else:
			o["regel"] = "Hoeveel meer %s dan %s?" % [str(WasSoorten.soort(h)["naam"]),
				str(WasSoorten.soort(l)["naam"])]
		# The legend is asked for on every group-5 question and weighed from
		# scratch each time; deciding it from the previous card's verdict left
		# the opening sum's card with a stale "no room" that then stuck to
		# vraag 1.
		o["regel2"] = LEGENDA
	_kaart = ctx.ui.somkaart(obj, som, o)
	_regel_indeling()
	return _kaart

## group 3: one button of the strip
func _kies(n: int) -> bool:
	if ctx == null or _s.is_empty() or int(_s.get("band", 3)) != 3 or _stap_nu() == "af":
		return false
	var goed := n == _hoogste_idx()
	ctx.state.tel(goed, Time.get_ticks_msec() - _t0)
	if goed:
		ctx.snd.ja()
		if _kaart != null:
			_kaart.klaar()                 # klaar() writes the ✓ itself
		_volgende()
		return true
	# no help (owner, 2026-09-24): the strip pauses with `🔄 Nog een keer` at
	# the card, and the same three piles are the same question
	ctx.snd.zacht()
	_s["missers"] = _missers() + 1
	ctx.ui.misser(_kaart, "")
	State.bewaar()
	_meld("mis")
	return false

## group 4 and 5: a number from the strip
func _antwoord(n, k) -> bool:
	if ctx == null or _s.is_empty() or _stap_nu() == "af":
		return false
	if n == null:
		return false
	_getikt = int(n)
	var goed := int(n) == _antwoord_nu()
	ctx.state.tel(goed, Time.get_ticks_msec() - _t0)
	if goed:
		ctx.snd.ja()
		if k != null:
			k.zet(str(int(n)))
			k.klaar()
		_volgende()
		return true
	# no help (owner, 2026-09-24): `Ui` pauses the strip with `🔄 Nog een keer`
	# and brings the same four numbers back; the card stays as it was
	ctx.snd.zacht()
	_s["missers"] = _missers() + 1
	State.bewaar()
	_meld("mis")
	return false

## A question is right: on to the next one, back to the crates, or done.
func _volgende() -> void:
	var stap := _stap_nu()
	_s["missers"] = 0
	if stap == "vraag0":
		_s["stap"] = "sorteren"
	elif int(_s.get("band", 3)) != 3 and stap == "vraag1":
		_s["stap"] = "vraag2"
	else:
		_s["stap"] = "af"
	State.bewaar()
	var bestemming := _stap_nu()
	if bestemming == "af":
		_ster()
	if not await na(0.75):
		return
	if ctx == null or _s.is_empty():
		return
	# An answer that came in while this one was waiting has already carried the
	# turn further; resuming here would rebuild a card that is not the current
	# question's.
	if _stap_nu() != bestemming:
		return
	if bestemming == "sorteren":
		# The card steps aside for the pile: from here the crates are the toy.
		if _kaart != null:
			_kaart.weg()
			_kaart = null
		_teken()
		_regel_indeling()
		_meld("sorteer")
		return
	_vraag_kaart()
	_teken()
	_meld("af" if _stap_nu() == "af" else "vraag")

func _ster() -> bool:
	if _s.is_empty() or int(_s.get("ster", 0)) != 0:
		return false
	_s["ster"] = 1
	print("[probe] was=ster sterren=", int(State.s["sterren"]) + 1)
	ctx.snd.hoera()
	ctx.taak_klaar("was", {"sterren": 1})
	State.bewaar()
	return true

# --------------------------------------------------------------- de indeling

func _op_kader(_rect: Rect2, _schaal: Dictionary) -> void:
	_regel_indeling()

## C1 and C2 of games-b.md §4.6, solved instead of measured.  One pass: the
## projection is a closed form, a Control measures itself synchronously, and
## the only thing that has to be looked up is where the question card landed —
## which `Hits` knows the moment it has placed it.
func _regel_indeling() -> void:
	if ctx == null or _s.is_empty() or Ui.knoplaag == null:
		return
	var kader := World.kader_rect()
	if kader.size.x < 1.0 or kader.size.y < 1.0:
		return
	var m := _m()
	if m < 1:
		return
	var sch := World.schaal()
	var k := float(sch.get("k", 1.0))
	var dicht := maxf(1.0, float(sch.get("dicht", 1.0)))
	var q0 := _krat_plek(m, 0)
	var hoogste := 0
	for v in _s.get("doel", []):
		hoogste = maxi(hoogste, int(v))
	var mikken: Array = []
	for i in m:
		var q := _krat_plek(m, i)
		mikken.append(World.mik_punt(q.x, q.y, float(_krat_y(i))).x)
	var uit := WasIndeling.los({
		"vloer": World.mik_punt(q0.x, q0.y, 0.0).y,
		"k": k, "pad": float(Art.PAD) / dicht,
		"hoogste": hoogste,
		"plaat_h": _plaat_maat(m).y,
		"kaart_top": _kaart_top(),
		"mikken": mikken, "breedtes": _plaat_breedtes(m),
		"kolommen": maxi(1, int((kader.size.x - 2.0 * Hits.RAND) / Hits.KOL)),
	})
	# every solve starts from the roomy assumption again, so a frame that grows
	# gets its words back
	_legenda_wolk = true
	_berg_kort = false
	# During the opening sum the card asks the question, so the pile does not
	# have to say it too: the number stays, the words go.  That frees the band
	# cells the second line of the card needs (games-b.md §4.6).
	if _stap_nu() == "vraag0":
		_berg_kort = true
	_voet = int(uit["voet"])
	_stap = int(uit["stap"])
	_tier = int(uit["tier"])
	# the legend costs a line on the card, so it is weighed against the chart
	var bodem := WasIndeling.blok_bodem(World.mik_punt(q0.x, q0.y, 0.0).y, k, _voet)
	_weeg_legenda(bodem)
	_teken()
	_mik_kaart()
	_pas_in_het_kader()
	_c2 = _kaart == null or _kaart_top() >= bodem - 0.01

## One synchronous fit pass.  The band grid reports `krap` when an element found
## no free cell in the whole frame (architecture.md §4.3), and it reports it in
## the same call — the HTML only learned it a paint later, and never acted on
## it.  So when a frame turns out to be too small for everything at once, the
## least important thing gives way first, in this order:
##
##   1. the legend bubble (it would land on the chart it explains),
##   2. the sentence on the pile (the number stays, the words go),
##   3. the second line of the card.
##
## The bar chart and its plates never give way: C1 is what makes the question
## answerable at all (games-b.md §4.6).
func _pas_in_het_kader() -> void:
	for _ronde in 4:
		Hits.plaats()
		var d := Hits.debug()
		if _legenda_wolk and _krap(d, HOT_LEGENDA):
			_legenda_wolk = false
			_teken_legenda()
			continue
		if not _berg_kort and _krap(d, HOT_BERG):
			_berg_kort = true
			_teken_berg()
			continue
		if _legenda_kaart and _kaart != null and _krap(d, HOT_KAART):
			# the second line made the card unplaceable: try the legend as a
			# bubble instead, and rule 1 above drops that too if the room has no
			# place for it either — then the last resort below puts it back.
			_legenda_kaart = false
			_kaart.regel2("")
			_mik_kaart()
			_teken_legenda()
			continue
		break
	# Out of rounds.  Rule 1 above can drop the bubble and rule 3 the second
	# line, and then nothing is left of the legend at all — and in group 5 the
	# question cannot be answered without it.  So it goes back on the card,
	# the same last resort `_weeg_legenda` ends with.
	if _per() == 2 and _kaart != null and not _legenda_kaart \
			and Hits.spot(HOT_LEGENDA) == null:
		_legenda_kaart = true
		_kaart.regel2(LEGENDA)
		_mik_kaart()

static func _krap(d: Dictionary, id: String) -> bool:
	return d.has(id) and bool(d[id]["krap"])

## Aim the card at the gap of §`_kaart_hoog`.  The hotspot keeps its point in
## the room (88, 84) — only its height above the floor is chosen, which is what
## `hoog` is for.
func _mik_kaart() -> void:
	if _kaart == null:
		return
	var s := Hits.spot(HOT_KAART)
	if s == null:
		return
	var maat := _kaart_maat()
	if maat.y <= 0.0:
		return
	s.y = _kaart_hoog(maat.y)
	var strook := Hits.spot(_kaart.strook_id) if _kaart.strook_id != "" else null
	if strook != null:
		strook.y = s.y

## The plate of a crate, measured on the real Control (never below a tap target).
func _plaat_maat(m: int) -> Vector2:
	var uit := Vector2(Hits.RIJ - 4, Hits.RIJ - 4)
	var tap := float(Ui.tap_maat())
	for i in m:
		var s := Hits.spot(_krat_hot(i))
		if s == null or not is_instance_valid(s.knoop):
			continue
		s.knoop.custom_minimum_size = Vector2(tap, tap)   # unpin, see _kaart_maat
		var maat := s.knoop.get_combined_minimum_size()
		uit.x = maxf(uit.x, maat.x)
		uit.y = maxf(uit.y, maat.y)
	return uit

## How wide a plate would be with the whole word, the singular, the pictogram.
## `Button.get_minimum_size()` is recomputed the moment the text changes, so all
## three sizes are known before anything is drawn — this is the measurement the
## HTML could only do after a paint.
func _plaat_breedtes(m: int) -> Array:
	var uit: Array = [float(Hits.RIJ - 4), float(Hits.RIJ - 4), float(Hits.RIJ - 4)]
	for i in m:
		var s := Hits.spot(_krat_hot(i))
		if s == null or not is_instance_valid(s.knoop):
			continue
		var knop := s.knoop as UiHotKnop
		if knop == null:
			continue
		var oud := knop.text
		var oud_maat := knop.custom_minimum_size
		knop.custom_minimum_size = Vector2(Ui.tap_maat(), Ui.tap_maat())
		var ico := str(WasSoorten.soort(i)["ico"])
		for t in 3:
			knop.text = ("%s %s" % [ico, _plaat_tekst(i, t)]).strip_edges()
			uit[t] = maxf(float(uit[t]), knop.get_combined_minimum_size().x)
		knop.text = oud
		knop.custom_minimum_size = oud_maat
	return uit

## How high above the floor of its point the question card aims, in voxels.
##
## The card wants to be as LOW as the frame allows: everything of the bar chart
## that stands above its top edge stays countable (C2).  Its own aim point is
## the front of the room, and the only thing under it is its own strip of four
## numbers, whose height is a closed form as well.  So the card is aimed at
## the gap that really exists instead of being dropped at a fixed height and
## then shoved a whole band at a time by the placement pass — which is what put
## it straight over the diagram on a compact landscape phone.
func _kaart_hoog(h_kaart: float) -> float:
	var kader := World.kader_rect().size
	var k := maxf(0.001, float(World.schaal().get("k", 1.0)))
	var p := _plek(KAART_F)
	var grond := World.mik_punt(p.x, p.y, 0.0).y
	var onder := kader.y - float(Hits.KRAP)
	if _heeft_pad():
		onder = kader.y - float(Hits.KRAP) - float(UiThema.HOT + 10) - float(Hits.KLEEF)
	var doel: float = minf(grond - h_kaart * 0.5, onder - h_kaart)
	doel = maxf(doel, float(Hits.KRAP))
	return (grond - doel - h_kaart * 0.5) / (2.0 * k)

## Does this question carry the strip of four numbers under the card?  Band 3
## answers with a strip of piles, the end card with one button.
func _heeft_pad() -> bool:
	return _kaart != null and int(_s.get("band", 3)) != 3 \
		and _stap_nu() != "af" and _stap_nu() != "sorteren"

## The size the card really needs, from its own Control (`Hits` floors it at a
## tap target, so this floor is the same one).
##
## `Hits.plaats()` writes the size it handed out back into the Control's
## `custom_minimum_size`, so a card that LOSES a line keeps reporting the height
## it had — the same trap `UiWolk.inhoud_maat()` documents.  The pin is cleared
## before measuring; the next placement pass writes it again.
func _kaart_maat() -> Vector2:
	var s := Hits.spot(HOT_KAART)
	if s == null or not is_instance_valid(s.knoop):
		return Vector2.ZERO
	# B4: the card's own Control minimum answers a one-word-per-line tower
	# when its wrapping labels have not been laid out at the width they are
	# drawn at (a freshly built or re-rendered card).  Ask the theme at the
	# card's width instead — the same honest measure `Hits._maat_van` now uses
	# to place the card — so the legend's card-vs-bubble decision sees the
	# height the card really has, not the tower.
	var maat := Ui.kaart_mat(s.knoop)
	return Vector2(maxf(maat.x, 48.0), maxf(maat.y, 48.0))

## Where the top edge of the question card will be, in frame units.  `INF` while
## there is no card — then C2 does not apply and the bench only serves C1.
func _kaart_top() -> float:
	if _kaart == null:
		return INF
	var maat := _kaart_maat()
	if maat.y <= 0.0:
		return INF
	var k := maxf(0.001, float(World.schaal().get("k", 1.0)))
	var p := _plek(KAART_F)
	return World.mik_punt(p.x, p.y, _kaart_hoog(maat.y)).y - maat.y * 0.5

# ---------------------------------------------------------------- de probe

## Everything the browser probe needs to drive a real turn with a finger:
## the state in one line, and where every hotspot of this game IS right now.
## `[probe]` lines are the repo convention (architecture.md §14.4); the crate
## plates move up as the stacks grow, so the rectangles are reported again after
## every tap that changed something.
func _meld(waarom: String) -> void:
	if not actief or _s.is_empty():
		return
	# `Hits` places in `World._process`, so the rectangles of buttons built in
	# this call are only real one frame later (scenes/main.gd `_na_plaatsing`).
	await get_tree().process_frame
	await get_tree().process_frame
	if not actief or _s.is_empty():
		return
	var rij: Array = _s.get("rij", [])
	print("[probe] was=", waarom, " band=", int(_s.get("band", 0)), " stap=", _stap_nu(),
		" per=", _per(), " m=", _m(), " T=", int(_s.get("T", 0)),
		" i=", int(_s.get("i", 0)), "/", rij.size(), " vak=", str(_s.get("vak", [])),
		" hand=", _hand(), " ster=", int(_s.get("ster", 0)),
		" juist=", _antwoord_nu(), " getikt=", _getikt, " voet=", _voet, " blokstap=", _stap,
		" tier=", _tier, " c2=", _c2, " legenda=", _legenda_kaart)
	_meld_knop(HOT_BERG)
	_meld_knop(HOT_HAND)
	_meld_knop(HOT_LEGENDA)
	_meld_knop(HOT_KAART)
	for i in _m():
		_meld_knop(_krat_hot(i))
	_meld_keuzes()

func _meld_knop(id: String) -> void:
	var s := Hits.spot(id)
	if s != null and is_instance_valid(s.knoop) and s.knoop.visible:
		print("[probe] was_knop ", id, "=", s.knoop.get_global_rect())

## The buttons of the choice strip under the card, by name.
func _meld_keuzes() -> void:
	if _kaart == null or _kaart.strook_id == "":
		return
	var s := Hits.spot(_kaart.strook_id)
	if s == null or not is_instance_valid(s.knoop):
		return
	var rij := s.knoop.get_node_or_null("Rij")
	if rij == null:
		return
	for k in rij.get_children():
		print("[probe] was_keuze ", (k as Control).name, "=", (k as Control).get_global_rect())

# ------------------------------------------------------------- testhaakjes

## Hooks the hotel never uses; `test_was.gd` drives the turn through them the
## way a finger would (games-b.md §4, the `doe()` of the HTML).
func stand() -> Dictionary:
	return _s.duplicate(true)

func indeling() -> Dictionary:
	return {"voet": _voet, "stap": _stap, "tier": _tier, "c2": _c2,
		"legenda_op_kaart": _legenda_kaart, "legenda_wolk": _legenda_wolk,
		"legenda_zichtbaar": _legenda_kaart or Hits.spot(HOT_LEGENDA) != null,
		"berg_kort": _berg_kort}

func juist() -> int:
	return _antwoord_nu()

func kaart() -> Ui.Kaart:
	return _kaart
