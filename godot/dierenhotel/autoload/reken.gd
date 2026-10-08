extends Node
## Reken — de rekenwacht ("the maths guard").  Autoload #11, registered LAST.
##
## Owner, 2026-10-09, verbatim: "Zorg wel dat rekenen altijd een prioriteit
## wordt en dat kinderen niet lang kunnen spelen zonder te rekenen. Minigames
## mogen een klein extra spel element hebben maar het moet niet mogelijk zijn
## om rekenen over te slaan en rekenen moet minstens 50% van de interactie
## zijn."
##
## Every interaction of the child — a tap, a drop — is counted ONCE, at the
## place where it is dispatched, as `reken` (an answer box of a maths card, a
## hotspot made with `reken: true`, the coins of the bill) or as `spel`
## (everything else).  The places: `Hits` (every hotspot tap and drop),
## `UiKeuzes` (every answer strip), `UiKamerbalk` (the room chips), `UiBlad`
## (sheet buttons), `Ui.prikbord_blad` (the board's cards) and the shell's
## chrome, floor plan and game bar (`scenes/main.gd`).  The rules:
##
##   1. The free budget starts at BUDGET_MAX.  A `spel` interaction costs one;
##      a right answer (`goed()`) pays back as many as there were `reken`
##      interactions since the last pay-back (wrong tries included), never
##      above BUDGET_MAX.  So whenever free play is allowed, spel <= reken +
##      BUDGET_MAX: maths is at least half of what the child does in the long
##      run (`tests/test_reken.gd` plays a thousand taps to prove it).
##   2. Active play time (the app visible, a tap in the last ACTIEF_S seconds)
##      since the last right answer runs up to TIJD_MAX; there a rekenmoment
##      starts even with budget left.
##   3. A rekenmoment starts when the budget reaches 0 or the clock reaches
##      TIJD_MAX OUTSIDE a running game.  Inside a running maths game taps are
##      counted and never refused (the budget may go negative and is paid back
##      by maths before free play resumes) — except an in-game free action, a
##      hotspot made with `vrij: true`, which is refused once the budget is
##      out.  A game whose `definitie()` says `vrij: true` (the paskamer) IS
##      free play: its entry is refused and a running one closes.
##   4. During a rekenmoment a free tap does nothing: the button shakes, a
##      see-through bubble says `➕ Eerst even rekenen!`, the room bar and the
##      door signs dim, and one big pulsing `➕ Rekenen` button stands at the
##      foot of the frame.  It starts the best maths there is (`doe_rekenen`).
##      Always allowed: that button, whatever leads straight to maths (the
##      entry of a maths game, the bell, a maths card on the board, the family
##      at the desk in the evening), answering a card, the game bar, sheet
##      buttons (closing a sheet), sound on/off.  The moment ends on the next
##      right answer that leaves the budget above 0.
##   5. Nothing is taken away, nothing is red, no clock is shown.
##   6. Everything is kept in its own file next to the hotel choice
##      (`PAD`), outside the hotels: a reload, another hotel, a new hotel or
##      the start sheet leave the budget, the clock and a moment as they were.
##
## The abacus the design asked for (U+1F9EE) is not in the bundled emoji subset
## (`fonts/tekens.txt`); the gate wears ➕, which the intro already gives to
## the sums ("➕ Met sommen help je de dieren!").

## The gate closed (`true`) or opened again (`false`).
signal rekenmoment(aan: bool)
## Something was counted, paid back or refused.
signal veranderd()

const BUDGET_MAX := 12          ## starting / maximum free interactions
const TIJD_MAX := 180.0         ## seconds of ACTIVE play without a right answer
const ACTIEF_S := 20.0          ## a tap keeps the clock running this long
const VENSTER := 40             ## the default window of `aandeel()`
const GESCHIEDENIS := 1000      ## how many interactions `aandeel()` remembers
const PAD := "user://dierenhotel-reken.json"
const VERSIE := 1
const EIGENAAR := "reken"       ## the owner stamp of the gate's own things in `Hits`
const KNOP := "reken_knop"      ## the big button
const WOLK := "reken_eerst"     ## the see-through bubble of a refused tap
const KAART := "reken_som"      ## the quick sum
const KOEK := "reken_koek"      ## the quick sum's biscuits: the model and the decor ids
const REKENING := "rekening"    ## `HotelRekening.EIGENAAR`: counting the bill's coins IS maths
const WOLK_S := 2.4             ## how long the bubble of a refused tap hangs
const KLAAR_S := 1.4            ## a counted quick sum stays this long, ticked
const BEWAAR_S := 5.0           ## the clock goes to the file every this many seconds
const STAP_MAX := 0.5           ## one frame never adds more to the clock than this
const BUDGET_MIN := -999        ## a budget read from the file is clamped to this
const DIM := 0.45               ## the room bar and the door signs while the gate is shut

enum Besluit {TEL, NEUTRAAL, WEIGER}

var _budget := BUDGET_MAX
var _reken_sinds := 0           ## `reken` interactions since the last pay-back
var _tijd := 0.0                ## active seconds since the last right answer
var _moment := false
var _geschiedenis := ""         ## "r"/"s" per interaction, newest last
var _totaal := {"reken": 0, "spel": 0, "goed": 0, "geweigerd": 0}
var _beurt := {"reken": 0, "spel": 0, "goed": 0}
var _nr := 0                    ## counts the interactions of this session
var _goed_nr := -1              ## `_nr` at the last right answer
var _actief_ms := -1000000000   ## the clock's reading at the last tap
var _tijd_bewaard := 0.0
var _aan := true                ## `zet_wacht(false)`: a test that is about something else
var _sluit_gepland := false
var _snel: Dictionary = {}      ## the quick sum on screen: {kamer, n, ids, nr}
var _snel_nr := 0
var _wolk_nr := 0               ## counts the bubbles of refused taps (their timers)
## Test hook: a fake clock in milliseconds (`Callable() -> int`).  Unset, the
## engine's own ticks.
var klok: Callable = Callable()

# ------------------------------------------------------------------ opzet

func _ready() -> void:
	_lees()
	if not Art.heeft_model(KOEK):
		Art.registreer_model(KOEK, _koek_model)
	Games.spel_gestart.connect(_op_spel_gestart)
	Games.spel_gestopt.connect(_op_spel_gestopt)
	# the bill's last right answer: counting the coins out exactly is maths too
	Econ.rekening_klaar.connect(func(_uit: Dictionary) -> void: goed(REKENING))
	State.veranderd.connect(_op_hotel)
	_herzie()

func _notification(wat: int) -> void:
	if wat == NOTIFICATION_WM_CLOSE_REQUEST or wat == NOTIFICATION_APPLICATION_PAUSED \
			or wat == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_bewaar()

func _process(delta: float) -> void:
	if not _aan:
		return
	if not World.gepauzeerd():
		_tel_tijd(minf(delta, STAP_MAX))
	_ververs_knop()

# ------------------------------------------------------------------- API

## One interaction of the child: `soort` is "reken" or "spel", `bron` says
## where (a hotspot id, `chip:<kamer>`, `strook:<kaart>` ...).  Counts and
## nothing else: the gate itself is `laat_door`.
func tik(soort: String, bron: String) -> void:
	if soort != "reken" and soort != "spel":
		push_warning('Reken.tik: "%s" (%s) is geen "reken" of "spel"' % [soort, bron])
		return
	_nr += 1
	_actief_ms = _nu()
	if soort == "reken":
		_reken_sinds += 1
		_totaal["reken"] = int(_totaal["reken"]) + 1
		_geschiedenis += "r"
	else:
		_budget -= 1
		_totaal["spel"] = int(_totaal["spel"]) + 1
		_geschiedenis += "s"
	if _geschiedenis.length() > GESCHIEDENIS:
		_geschiedenis = _geschiedenis.right(GESCHIEDENIS)
	if not Games.actief().is_empty():
		_beurt[soort] = int(_beurt[soort]) + 1
	_herzie()
	_bewaar()
	_meld()
	veranderd.emit()

## A right maths answer landed: the budget gets back what the maths since the
## last pay-back earned (capped at BUDGET_MAX) and the clock starts again.
## Idempotent per interaction: a second call for the same tap pays nothing.
func goed(bron: String = "") -> void:
	var nieuw := _nr != _goed_nr
	_goed_nr = _nr
	_budget = mini(BUDGET_MAX, _budget + _reken_sinds)
	_reken_sinds = 0
	_tijd = 0.0
	_tijd_bewaard = 0.0
	if nieuw:
		_totaal["goed"] = int(_totaal["goed"]) + 1
		if not Games.actief().is_empty():
			_beurt["goed"] = int(_beurt["goed"]) + 1
	if _moment and _budget > 0:
		_zet_moment(false)
	_herzie()
	_bewaar()
	_meld("goed=" + bron if not bron.is_empty() else "goed")
	veranderd.emit()

## False during a rekenmoment.
func vrij() -> bool:
	return not _moment

## Free interactions left; negative inside a game that was played without maths.
func budget() -> int:
	return _budget

## The share of `reken` among the last `venster` interactions; 1.0 without any.
func aandeel(venster: int = VENSTER) -> float:
	var n := mini(maxi(venster, 0), _geschiedenis.length())
	if n <= 0:
		return 1.0
	return float(_geschiedenis.right(n).count("r")) / float(n)

## {reken, spel, goed} since the running game started (counted while a game
## runs; kept after it stops until the next start).
func beurt() -> Dictionary:
	return _beurt.duplicate()

func aandeel_beurt() -> float:
	var r := int(_beurt["reken"])
	var s := int(_beurt["spel"])
	return 1.0 if r + s <= 0 else float(r) / float(r + s)

## Would a `spel` interaction on `bron` go through right now?
func mag(bron: String) -> bool:
	return _beslis("spel", bron, Hits.spot(bron), false) != Besluit.WEIGER

## The gate as the dispatch points use it: decides, counts (or not) and on a
## refusal shakes `knop`, says why and returns false — then the caller does
## nothing at all.  `vrij_actie`: an in-game free action (a game's own button
## that is not part of the maths), refused once the budget is out.
func laat_door(soort: String, bron: String, knop: Control = null, vrij_actie := false) -> bool:
	return _poort(soort, bron, knop, vrij_actie, Hits.spot(bron))

## The same for a hotspot of `Hits`: a tap, or (`drop`) a drop on its catch
## area.  Its kind comes from the spot itself: `reken: true`, or a coin of the
## bill, is maths.
func laat_door_spot(s, drop := false) -> bool:
	if s == null:
		return true
	var bron := ("drop:" if drop else "") + str(s.id)
	return _poort(soort_van(s), bron, s.knoop as Control, bool(s.vrij), s)

## "reken" or "spel" for a hotspot.
func soort_van(s) -> String:
	if s == null:
		return "spel"
	return "reken" if bool(s.reken) or str(s.door) == REKENING else "spel"

## The gate is shut where the child is: the room bar and the door signs dim.
func dimt() -> bool:
	return _aan and _moment and _vrije_context()

## Mark the child active (every press, `scenes/main.gd _input`): the clock only
## runs while somebody plays.
func wakker() -> void:
	_actief_ms = _nu()

## Seconds of active play since the last right answer.
func tijd() -> float:
	return _tijd

## The `[probe]` line of the play tools.
func probe_regel() -> String:
	return "[probe] reken vrij=%d budget=%d tijd=%d aandeel=%.2f beurt=%d/%d moment=%d" % [
		1 if vrij() else 0, _budget, int(_tijd), aandeel(), int(_beurt["reken"]),
		int(_beurt["spel"]), 1 if _moment else 0]

## The totals since the file began: {reken, spel, goed, geweigerd}.
func totaal() -> Dictionary:
	return _totaal.duplicate()

# -------------------------------------------------------------- de poort

func _poort(soort: String, bron: String, knop: Control, vrij_actie: bool, spot) -> bool:
	match _beslis(soort, bron, spot, vrij_actie):
		Besluit.WEIGER:
			_weiger(bron, knop, spot)
			return false
		Besluit.NEUTRAAL:
			_actief_ms = _nu()
			return true
	tik(soort, bron)
	return true

func _beslis(soort: String, bron: String, spot, vrij_actie: bool) -> int:
	if not _aan or soort == "reken":
		return Besluit.TEL
	# the gate's own button, and the start sheet and its tiles, are no play
	if bron == KNOP or bron.begins_with("systeem:"):
		return Besluit.NEUTRAAL
	var vrij_hier := vrij_actie or (spot != null and bool(spot.vrij))
	var spel := Games.actief()
	if not spel.is_empty() and not _is_vrij_spel(spel):
		# inside a maths game everything counts and nothing is refused — but a
		# free action of the game itself waits for the maths, like free play
		if vrij_hier and _op():
			return Besluit.WEIGER
		return Besluit.TEL
	if not (_moment or _op()):
		return Besluit.TEL
	if _altijd(bron, spot):
		return Besluit.NEUTRAAL
	return Besluit.WEIGER

## What stays allowed during a rekenmoment (rule 4).  Not counted then.
func _altijd(bron: String, spot) -> bool:
	if bron == "chroom:Geluid":
		return true
	for voor in ["blad:", "strook:", "spelbalk:"]:
		if bron.begins_with(voor):
			return true
	if bron.begins_with("taak:"):
		return _taak_rekent(bron.substr(5), true)
	# the bell only stands where ringing brings a guest to check in
	if bron == "bel":
		return true
	# the evening: the families at the desk come to pay their bill
	if bron == "lamp" or bron == "chroom:Avond":
		return Hotel.avond_klaar()
	if bron.begins_with("av_"):
		return bron != "av_morgen"
	if bron.begins_with("spel_"):
		return _rekenspel(bron.substr(5))
	return spot != null and str(spot.door) == REKENING

func _op() -> bool:
	return _budget <= 0 or _tijd >= TIJD_MAX

func _is_vrij_spel(id: String) -> bool:
	return bool(Games.definitie(id).get("vrij", false))

func _vrij_spel_loopt() -> bool:
	var a := Games.actief()
	return not a.is_empty() and _is_vrij_spel(a)

## No game runs, or a free-play game: here a moment can start.
func _vrije_context() -> bool:
	return Games.actief().is_empty() or _vrij_spel_loopt()

## Does the moment start (or does a free-play game have to close)?
func _herzie() -> void:
	if not _aan:
		return
	if not _moment and _op() and _vrije_context():
		_zet_moment(true)
	if (_moment or _op()) and _vrij_spel_loopt() and not _sluit_gepland:
		_sluit_gepland = true
		_sluit_vrij_spel.call_deferred()

func _zet_moment(aan: bool) -> void:
	if _moment == aan:
		return
	_moment = aan
	_bewaar()
	rekenmoment.emit(aan)
	_ververs_knop()
	_meld("moment=%d" % (1 if aan else 0))

## A free-play game (the paskamer) that ran out of budget closes: free play
## waits for the maths, in a game as in the hotel.
func _sluit_vrij_spel() -> void:
	_sluit_gepland = false
	if not _vrij_spel_loopt() or not (_moment or _op()):
		return
	Games.stop()
	_herzie()
	_toon_wolk_later()

## A game started: the turn's own counters begin at zero.
func _op_spel_gestart(id: String) -> void:
	_beurt = {"reken": 0, "spel": 0, "goed": 0}
	_snel_weg()
	if _is_vrij_spel(id):
		_herzie()
	_ververs_knop()

func _op_spel_gestopt(_id: String) -> void:
	_herzie()
	_ververs_knop()

## Another hotel (or a new one) took the stage: the counters are the tablet's,
## not the hotel's, so they stay; only the quick sum of the old world goes.
func _op_hotel() -> void:
	if not _snel.is_empty():
		_snel_weg()

# ------------------------------------------------------------ de klok

func _nu() -> int:
	if klok.is_valid():
		return int(klok.call())
	return Time.get_ticks_msec()

func _tel_tijd(dt: float) -> void:
	if dt <= 0.0 or _nu() - _actief_ms > int(ACTIEF_S * 1000.0):
		return
	var voor := _tijd
	_tijd = minf(_tijd + dt, TIJD_MAX)
	if _tijd - _tijd_bewaard >= BEWAAR_S:
		_tijd_bewaard = _tijd
		_bewaar()
	if voor < TIJD_MAX and _tijd >= TIJD_MAX:
		_herzie()
		_meld("tijd")

## Test hook: `seconden` of play pass, by the same rule as the frames (only
## while the child was active in the last ACTIEF_S seconds of `klok`).
func verstrijk(seconden: float) -> float:
	_tel_tijd(seconden)
	return _tijd

# --------------------------------------------------------- een weigering

func _weiger(bron: String, knop: Control, spot) -> void:
	_totaal["geweigerd"] = int(_totaal["geweigerd"]) + 1
	_actief_ms = _nu()
	Snd.zacht()
	_schud(knop)
	# a refused room on the floor plan or card on the board: the sheet goes,
	# so the big button and its bubble are what the child sees next
	if (bron.begins_with("toren:") or bron.begins_with("taak:")) and Ui.blad_open_nu():
		Ui.blad_dicht()
	_toon_wolk(spot)
	_meld("weiger=" + bron)
	veranderd.emit()

## A friendly "no": the button shakes its head once.  `reken_geschud` counts
## it for the tests, which run headless and never see the movement.
func _schud(c: Control) -> void:
	if c == null or not is_instance_valid(c):
		return
	c.set_meta("reken_geschud", int(c.get_meta("reken_geschud", 0)) + 1)
	if Ui.rust_modus() or DisplayServer.get_name() == "headless" or not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "rotation", -0.12, 0.06)
	tw.tween_property(c, "rotation", 0.12, 0.08)
	tw.tween_property(c, "rotation", -0.06, 0.07)
	tw.tween_property(c, "rotation", 0.0, 0.07)

## `➕ Eerst even rekenen!` as a bubble that only speaks: at the big button
## when it stands, else at the sum on screen, else at the refused thing; a
## toast when none of them is in the frame (a chip, the chrome).
func _toon_wolk(spot = null) -> void:
	if not Hotel.scherm_klaar():
		return
	Hits.weg(WOLK)
	var anker := ""
	if Hits.rect_van(KNOP).size.x > 0.0:
		anker = KNOP
	elif not Ui.som_kaart_in_beeld().is_empty() and Hits.rect_van(Ui.som_kaart_in_beeld()).size.x > 0.0:
		anker = Ui.som_kaart_in_beeld()
	elif spot != null and Hits.rect_van(str(spot.id)).size.x > 0.0:
		anker = str(spot.id)
	if anker.is_empty():
		Ui.toast("%s %s" % [UiTekst.REKEN_ICOON, UiTekst.REKEN_EERST], "kind")
		return
	var kamer := World.kamer_nu()
	Ui.wolk({"id": WOLK, "door": EIGENAAR, "kamer": kamer, "x": 0.0, "z": 0.0, "hoog": 0.0,
		"op": "aan", "prio": 25, "icoon": UiTekst.REKEN_ICOON, "tekst": UiTekst.REKEN_EERST,
		"volg": func() -> Dictionary:
			var r := Hits.rect_van(anker)
			return {} if r.size.x <= 0.0 else {"vlak": r, "kamer": World.kamer_nu()}})
	if Hits.spot(WOLK) == null:
		return
	# the timer holds a number, never the bubble itself: a bubble that was
	# wiped before the timer ran out (another hotel, a test) is already freed
	_wolk_nr += 1
	var nr := _wolk_nr
	var boom := get_tree()
	if boom != null:
		boom.create_timer(WOLK_S).timeout.connect(func() -> void:
			if _wolk_nr == nr:
				Hits.weg(WOLK))

## The same a moment later, once the big button has a place (a game that just
## closed).
func _toon_wolk_later() -> void:
	var boom := get_tree()
	if boom == null:
		return
	boom.create_timer(0.25).timeout.connect(func() -> void:
		if _moment:
			_toon_wolk())

# ------------------------------------------------------- de grote knop

## The big button stands while the gate is shut, no game runs, and nothing
## to count is already on screen (a sum, the check-in or the bill at the desk).
func _knop_hoort() -> bool:
	return _aan and _moment and Games.actief().is_empty() and Hotel.scherm_klaar() \
		and not _rekenwerk_in_beeld()

func _rekenwerk_in_beeld() -> bool:
	if Ui.som_in_beeld():
		return true
	if World.kamer_nu() == "receptie" and (State.s.get("checkin") != null or Econ.rekening_bezig()):
		return true
	return Ui.kaart_van(KAART) != null and str(_snel.get("kamer", "")) == World.kamer_nu()

func _ververs_knop() -> void:
	var hoort := _knop_hoort()
	var er := Hits.spot(KNOP) != null
	if hoort and not er:
		_maak_knop()
	elif not hoort and er:
		Hits.weg(KNOP)

## Through `Hits`, like every hotel button: at the foot of the frame (`voet`,
## the strip the camera keeps free under the room), in every room and on every
## screen, the same place; pictogram AND word, pulsing.
func _maak_knop() -> void:
	Hits.maak({"id": KNOP, "door": EIGENAAR, "kamer": World.kamer_nu(),
		"x": 0.0, "z": 0.0, "y": 0.0, "op": "voet", "prio": 30, "klas": "hotreken",
		"icoon": UiTekst.REKEN_ICOON, "label": UiTekst.REKEN_KNOP,
		"titel": UiTekst.REKEN_TITEL, "puls": -1.0,
		"volg": func() -> Dictionary: return {"kamer": World.kamer_nu()},
		"aan": func(_s) -> void: _op_knop()})
	var s = Hits.spot(KNOP)
	if s != null and s.knoop is Button:
		var b := s.knoop as Button
		b.theme_type_variation = "KnopActief"
		b.add_theme_font_size_override("font_size", int(Ui.maten.get("knop_groot", 22)))
	_meld_knop_later()

func _op_knop() -> void:
	Hits.weg(WOLK)
	doe_rekenen()

## What the big button does: the best maths there is right now, in this order —
## the top maths card on the board; a guest waiting at the desk (the check-in,
## or a family with its bill); a maths game of this room; and else the quick
## sum, which always works.  Returns which one ("bord", "checkin", "rekening",
## "spel", "snel").  Whatever was chosen, if no maths is on screen after it,
## the quick sum comes: the gate never dead-ends.
func doe_rekenen() -> String:
	var tak := _kies_rekenwerk()
	if tak != "snel" and not _rekent_nu():
		_snelle_som()
		tak = "snel"
	_meld("rekenen=" + tak)
	return tak

func _kies_rekenwerk() -> String:
	for q in State.s.get("taken", []):
		if typeof(q) != TYPE_DICTIONARY or bool((q as Dictionary).get("klaar", false)):
			continue
		if _taak_rekent(str((q as Dictionary).get("actie", ""))):
			_doe_taak(q)
			return "bord"
	if State.s.get("checkin") != null:
		Hotel.naar_kamer("receptie")
		Hotel.paint_checkin()
		return "checkin"
	if Econ.rekening_bezig():
		Econ.herstel_rekening()
		return "rekening"
	var spel := _rekenspel_hier()
	if not spel.is_empty() and Games.start(spel):
		return "spel"
	_snelle_som()
	return "snel"

func _rekent_nu() -> bool:
	return not Games.actief().is_empty() or State.s.get("checkin") != null \
		or Econ.rekening_bezig() or Ui.som_in_beeld()

## Does a board card with this action lead straight to maths?  `ook_bezig`:
## the bell's card also while a guest is already checking in (it shows him).
func _taak_rekent(actie: String, ook_bezig := false) -> bool:
	if actie == "bel":
		return State.plek_voor_gast() or (ook_bezig and State.s.get("checkin") != null)
	if actie == "avond":
		return Hotel.avond_klaar()
	if actie.begins_with("game:"):
		return _rekenspel(actie.substr(5))
	return false

## The board card's own action — the evening card straight to the first bill.
func _doe_taak(q: Dictionary) -> void:
	if str(q.get("actie", "")) == "avond":
		Hotel.avondronde()
		var uit: Array = State.s.get("uitcheck", [])
		if not uit.is_empty():
			Hotel.reken_af(str(uit[0]))
		return
	Hotel.doe_taak(q)

## A maths game that can be played right now (not a stub, not free play).
func _rekenspel(id: String) -> bool:
	var def := Games.definitie(id)
	if def.is_empty() or bool(def.get("stub", false)) or bool(def.get("vrij", false)):
		return false
	return Games.ontgrendeld(id) and Games.speelbaar_nu(id)

func _rekenspel_hier() -> String:
	var nu := World.kamer_nu()
	for id in Games.lijst():
		var def := Games.definitie(id)
		if str(def.get("kamer", "")) != nu or (def.get("hotspot", {}) as Dictionary).is_empty():
			continue
		if _rekenspel(id):
			return id
	return ""

# ------------------------------------------------------- de snelle som

## The quick sum: biscuits on the free floor of the room in view, as many as
## the band asks for, and the card "🍪 Hoeveel koekjes zie je?" with a strip
## of four numbers.  The biscuits stand still (they are the gate's own decor,
## not guests that walk in and out), so the right answer is always what the
## child sees.  Fewer than two free places — no room has that few — and it is
## a plain sum.
func _snelle_som() -> void:
	_snel_weg()
	if not Hotel.scherm_klaar():
		return
	_snel_nr += 1
	var kamer := World.kamer_nu()
	var plekken := _koek_plekken(kamer, _snel_aantal())
	if plekken.size() < 2:
		_kale_som(kamer)
		return
	var ids: Array[String] = []
	for i in plekken.size():
		var id := "%s%d" % [KOEK, i]
		var p: Vector2 = plekken[i]
		World.decor(kamer, {"id": id, "model": KOEK, "x": p.x, "z": p.y, "door": EIGENAAR})
		ids.append(id)
	var n := ids.size()
	_snel = {"kamer": kamer, "n": n, "ids": ids, "nr": _snel_nr}
	Ui.somkaart(ids[0], "", {"id": KAART, "door": EIGENAAR, "kamer": kamer,
		"goed": n, "min": 1, "max": 2, "max_getal": 20, "liever": [n - 1, n + 1],
		"icoon": UiTekst.REKEN_TEL_ICOON, "regel": UiTekst.REKEN_TEL,
		"volg": _koek_volg(kamer, ids),
		"on_ok": func(g, k) -> void: _snel_antwoord(int(g), k)})

## Never needed in the hotel as it is built; the last rung so the gate can not
## dead-end in a room without free floor.
func _kale_som(kamer: String) -> void:
	var r = Rooms.get_kamer(kamer)
	var a := 2 + posmod(_zaad(), 5)
	var b := 1 + posmod(_zaad() * 7 + 3, 4)
	var plek := {"x": float(r.w) * 0.5 if r != null else 40.0,
		"z": float(r.d) * 0.5 if r != null else 40.0}
	_snel = {"kamer": kamer, "n": a + b, "ids": [], "nr": _snel_nr}
	Ui.somkaart(plek, "%d + %d =" % [a, b], {"id": KAART, "door": EIGENAAR, "kamer": kamer,
		"goed": a + b, "min": 1, "max": 2, "max_getal": 20,
		"icoon": UiTekst.REKEN_ICOON, "regel": UiTekst.REKEN_SAMEN,
		"on_ok": func(g, k) -> void: _snel_antwoord(int(g), k)})

func _snel_antwoord(g: int, k) -> void:
	if _snel.is_empty() or g != int(_snel.get("n", -1)):
		return          # a miss: `Ui.misser` answered it, the same question stays
	if k != null:
		k.klaar()
	Snd.ja()
	Ui.toast(UiTekst.REKEN_GOED, "happy")
	var nr := int(_snel.get("nr", 0))
	var boom := get_tree()
	if boom != null:
		boom.create_timer(KLAAR_S).timeout.connect(func() -> void:
			if int(_snel.get("nr", -1)) == nr:
				_snel_weg())

func _snel_weg() -> void:
	var k = Ui.kaart_van(KAART)
	if k != null:
		k.weg()
	if not _snel.is_empty():
		var kamer := str(_snel.get("kamer", ""))
		for id in (_snel.get("ids", []) as Array):
			World.decor_weg(kamer, str(id))
	_snel = {}

## The quick sum on screen: {kamer, n, ids, nr}, empty when there is none.
func snelle_som() -> Dictionary:
	return _snel.duplicate(true)

## How many biscuits: groep 3 three to seven, groep 4 five to ten, groep 5
## eight to twelve — a different number each time.
func _snel_aantal() -> int:
	var band := State.band()
	var lo := 3
	var hi := 7
	if band >= 5:
		lo = 8
		hi = 12
	elif band == 4:
		lo = 5
		hi = 10
	return lo + posmod(_zaad(), hi - lo + 1)

func _zaad() -> int:
	return int(State.s.get("dag", 1)) * 31 + int(_totaal["goed"]) * 7 \
		+ int(_totaal["geweigerd"]) * 3 + _snel_nr * 11

## `n` free places close together in the middle of the free floor: the room's
## own wander cells (`Kamer.vrij`, a grid of RASTER voxels) that are still
## free, away from the guests and from the loose decor of the games.
func _koek_plekken(kamer: String, n: int) -> Array[Vector2]:
	var uit: Array[Vector2] = []
	var r = Rooms.get_kamer(kamer)
	if r == null or n <= 0:
		return uit
	var dieren: Array[Vector2] = []
	for d in World.dieren(kamer):
		dieren.append(Vector2(float(d.x), float(d.z)))
	var los: Array[Vector2] = []
	for stuk in World.decor_lijst(kamer):
		if str(stuk.get("door", "")) != EIGENAAR:
			los.append(Vector2(float(stuk.get("x", 0.0)), float(stuk.get("z", 0.0))))
	var cellen: Array[Vector2] = []
	for cel in r.vrij:
		var p := Vector2(float(cel["x"]), float(cel["z"]))
		if not Rooms.vrij_vak(kamer, p.x, p.y) or _dichtbij(p, dieren, 10.0) \
				or _dichtbij(p, los, 14.0):
			continue
		cellen.append(p)
	if cellen.is_empty():
		return uit
	var midden := Vector2.ZERO
	for p in cellen:
		midden += p
	midden /= float(cellen.size())
	var start := cellen[0]
	for p in cellen:
		if p.distance_squared_to(midden) < start.distance_squared_to(midden):
			start = p
	cellen.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var da := a.distance_squared_to(start)
		var db := b.distance_squared_to(start)
		if not is_equal_approx(da, db):
			return da < db
		if not is_equal_approx(a.x, b.x):
			return a.x < b.x
		return a.y < b.y)
	for i in mini(n, cellen.size()):
		uit.append(cellen[i])
	return uit

static func _dichtbij(p: Vector2, lijst: Array[Vector2], afstand: float) -> bool:
	for q in lijst:
		if p.distance_to(q) < afstand:
			return true
	return false

## The card keeps clear of every biscuit: their boxes together are its thing.
func _koek_volg(kamer: String, ids: Array[String]) -> Callable:
	return func() -> Dictionary:
		var vak := Rect2()
		for id in ids:
			var p := World.decor_plek(id, kamer)
			if p.is_empty():
				continue
			var v := World.vlak_van(KOEK, float(p["x"]), float(p["z"]), 0.0)
			if v.size.x <= 0.0:
				continue
			vak = v if vak.size.x <= 0.0 else vak.merge(v)
		return {"vlak": vak, "kamer": kamer} if vak.size.x > 0.0 else {"kamer": kamer}

const KOEK_KLEUR := Color("#E2A85E")
const KOEK_RAND := Color("#C7863F")
const KOEK_CHOCO := Color("#6B3F23")

## A round biscuit on the floor, seven voxels across, with chocolate on top.
func _koek_model(_p := {}) -> Array:
	var v: Array = []
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var r2 := dx * dx + dz * dz
			if r2 > 10:
				continue
			var rand := r2 >= 7
			v.append({"x": dx, "y": 0, "z": dz, "k": KOEK_RAND if rand else KOEK_KLEUR})
			if not rand:
				v.append({"x": dx, "y": 1, "z": dz, "k": KOEK_KLEUR})
	for c in [Vector2i(-1, -1), Vector2i(1, 0), Vector2i(-1, 1)]:
		v.append({"x": c.x, "y": 2, "z": c.y, "k": KOEK_CHOCO})
	return v

# ------------------------------------------------------------- opslag

## Atomic, like `State`: the whole document to `<pad>.tmp`, then over the old.
func _bewaar() -> void:
	var doc := {"v": VERSIE, "budget": _budget, "reken_sinds": _reken_sinds,
		"tijd": snappedf(_tijd, 0.1), "moment": _moment,
		"geschiedenis": _geschiedenis, "totaal": _totaal}
	var tmp := PAD + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(doc))
	f.close()
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove(PAD.get_file())
		dir.rename(tmp.get_file(), PAD.get_file())

## Anything odd in the file reads as its default: a broken file never gives
## MORE free play than a fresh one would.
func _lees() -> void:
	if not FileAccess.file_exists(PAD):
		return
	var lezer := JSON.new()
	if lezer.parse(FileAccess.get_file_as_string(PAD)) != OK:
		return
	var d = lezer.data
	if typeof(d) != TYPE_DICTIONARY or int(_getal(d.get("v", 0), 0)) != VERSIE:
		return
	_budget = clampi(int(_getal(d.get("budget"), BUDGET_MAX)), BUDGET_MIN, BUDGET_MAX)
	_reken_sinds = maxi(0, int(_getal(d.get("reken_sinds"), 0)))
	_tijd = clampf(float(_getal(d.get("tijd"), 0.0)), 0.0, TIJD_MAX)
	_tijd_bewaard = _tijd
	_moment = d.get("moment") is bool and bool(d.get("moment"))
	var g = d.get("geschiedenis", "")
	_geschiedenis = ""
	if g is String:
		for c in (g as String).right(GESCHIEDENIS):
			if c == "r" or c == "s":
				_geschiedenis += c
	var t = d.get("totaal", {})
	if t is Dictionary:
		for k in _totaal.keys():
			_totaal[k] = maxi(0, int(_getal((t as Dictionary).get(k), 0)))

static func _getal(v, standaard) -> Variant:
	return v if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT else standaard

## A fresh `Reken` reads the file again (a test of rule 6).
func lees_opnieuw() -> void:
	_lees()

# --------------------------------------------------------------- probe

func _spreekt() -> bool:
	return DisplayServer.get_name() != "headless"

## One `[probe] reken ...` line after every change (and a `wat` line before
## it when there is something to say), for `tools/speel.js`.
func _meld(wat := "") -> void:
	if not _spreekt():
		return
	if not wat.is_empty():
		print("[probe] reken ", wat)
	print(probe_regel())

## Where the big button stands, once `Hits` placed it: a probe taps it by id.
func _meld_knop_later() -> void:
	if not _spreekt() or not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var s = Hits.spot(KNOP)
	if s != null and is_instance_valid(s.knoop) and (s.knoop as Control).visible:
		print("[probe] knop ", KNOP, "=", (s.knoop as Control).get_global_rect())

# --------------------------------------------------------------- tests

## The runner calls this before every test (`tests/run_tests.gd`): a full
## budget, a clock at zero, no moment, no file — so a test that taps many
## hotel buttons for another reason starts where a fresh tablet starts.
func voor_test() -> void:
	_aan = true
	klok = Callable()
	_budget = BUDGET_MAX
	_reken_sinds = 0
	_tijd = 0.0
	_tijd_bewaard = 0.0
	_moment = false
	_geschiedenis = ""
	_totaal = {"reken": 0, "spel": 0, "goed": 0, "geweigerd": 0}
	_beurt = {"reken": 0, "spel": 0, "goed": 0}
	_nr = 0
	_goed_nr = -1
	_actief_ms = -1000000000
	_sluit_gepland = false
	Hits.weg(KNOP)
	Hits.weg(WOLK)
	if not _snel.is_empty() or Ui.kaart_van(KAART) != null:
		_snel_weg()
	if FileAccess.file_exists(PAD):
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.remove(PAD.get_file())

## `Proef.rekenwacht_uit()`: a test about something else that has to tap more
## free buttons in a row than one budget holds.  The runner turns it back on.
func zet_wacht(aan: bool) -> void:
	_aan = aan
	if not aan:
		_zet_moment(false)
		Hits.weg(KNOP)

func wacht_aan() -> bool:
	return _aan
