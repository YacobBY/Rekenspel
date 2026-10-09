class_name UiWeb
extends Node
## The browser around the game (W2, 2026-10-09; owner: "Het moet in browser
## werken ook op Android niet IOS specifiek").  `scenes/main.gd` makes ONE of
## these, and only in the web export.  Generic web standards only: no
## user-agent sniffing, nothing written for one browser.  What the page can do
## on its own — no zoom, no pull-to-refresh, no long-press menu, the WebGL 2
## check, the sound while the tab is hidden — is the HTML shell's job
## (`web/shell.html`); this is the part that needs the game:
##
## * **Back.**  The Android back button or back gesture, a desktop browser's
##   ⬅, Alt+← or a mouse's back button acts like the game's own `⬅ Terug` and
##   never leaves the app: one history entry of our own lies on top of the
##   page, a back press pops it, `popstate` calls `terug()` and the entry is
##   laid back at once.  What `terug()` does is decided by `beslis()` alone —
##   pure, so the suite walks every row headless (tests/test_web.gd).
##   The entry is first laid inside a user gesture (the first tap or key), not
##   at boot: Chrome's history-manipulation intervention skips an entry that a
##   page added before the user ever touched it, and the back button would then
##   leave the game after all.  For the same reason a page can never trap the
##   back button completely: pressing back again and again WITHOUT tapping
##   anything in between ends up leaving the page (browser rule, by design).
## * **Safe areas.**  The page has `viewport-fit=cover` (Chrome on Android
##   then draws under the gesture bar and a display cutout); CSS
##   `env(safe-area-inset-*)` reaches the shell's margins through `randen()`,
##   in units (= CSS px), the same shape as `_veilige_randen()` of the shell.
## * **Storage.**  `navigator.storage.persist()` once, after the first tap
##   (Chrome grants it to an installed app); the answer is a probe line.
## * **Screen on.**  A Screen Wake Lock while a game runs or a sum card is open,
##   so the screen does not go dark while a child is counting; let go when
##   neither, and taken again when the tab comes back.
##
## Probe lines (`[probe] web …`) tell `tools/speel.js` and the notes what
## happened: `klaar`, `terug=<actie>`, `randen=`, `opslag_blijvend=`, `wakker=`.

## The insets changed (rotation, a cutout, the gesture bar): lay the shell out.
signal randen_veranderd()

## Buttons on a sheet that mean "back" when the sheet cannot simply be closed:
## the hotels sheet's `⬅ Terug` and the questions' `⬅ Nee, terug`.
const TERUG_KNOPPEN: Array[String] = ["Kterug", "Knee"]
## s between two looks at whether the screen must stay on.
const WAKKER_ELKE := 0.5

## The glue on the page: the history entry, the insets, storage, wake lock.
## Evaluated once, in the page's global scope; `window.dhWeb` is its face.
const JS_LIJM := """
(function () {
  if (window.dhWeb) return 'al';
  var MERK = 'dierenhotel';
  var opTerug = null, opVorm = null, opOpslag = null;
  var wapens = 0, terugs = 0, laatsteRanden = '', opslag = '';
  var slot = null, wakker = false;
  function eigen(s) { return !!(s && s[MERK] === 'terug'); }
  function staat(w) { var s = {}; s[MERK] = w; return s; }
  function wapen() {
    if (eigen(history.state)) return false;
    try {
      if (!(history.state && history.state[MERK] === 'basis')) history.replaceState(staat('basis'), '');
      history.pushState(staat('terug'), '');
      wapens++;
      return true;
    } catch (e) { return false; }
  }
  window.addEventListener('popstate', function (e) {
    if (eigen(e.state)) return;
    terugs++;
    wapen();
    if (opTerug) opTerug(terugs);
  });
  function vraagOpslag() {
    var s = navigator.storage;
    opslag = 'bezig';
    function klaar(w) { opslag = w; if (opOpslag) opOpslag(w); }
    if (!s || !s.persist) { klaar('onbekend'); return; }
    (s.persisted ? s.persisted() : Promise.resolve(false))
      .then(function (al) { return al ? true : s.persist(); })
      .then(function (ja) { klaar(ja ? 'ja' : 'nee'); }, function () { klaar('onbekend'); });
  }
  function gebaar() {
    if (!eigen(history.state)) wapen();
    if (!opslag) vraagOpslag();
  }
  ['pointerdown', 'pointerup', 'touchend', 'mousedown', 'keydown'].forEach(function (t) {
    window.addEventListener(t, gebaar, { capture: true, passive: true });
  });
  function randen() {
    var el = document.getElementById('dh-veilig');
    if (!el) {
      el = document.createElement('div');
      el.id = 'dh-veilig';
      el.setAttribute('aria-hidden', 'true');
      el.style.cssText = 'position:fixed;left:0;top:0;width:0;height:0;visibility:hidden;pointer-events:none;' +
        'padding-top:env(safe-area-inset-top,0px);padding-right:env(safe-area-inset-right,0px);' +
        'padding-bottom:env(safe-area-inset-bottom,0px);padding-left:env(safe-area-inset-left,0px)';
      document.body.appendChild(el);
    }
    var cs = getComputedStyle(el);
    return [cs.paddingLeft, cs.paddingTop, cs.paddingRight, cs.paddingBottom]
      .map(function (v) { return Math.round(parseFloat(v) || 0); }).join(',');
  }
  function vorm() {
    var r = randen();
    if (r !== laatsteRanden) { laatsteRanden = r; if (opVorm) opVorm(r); }
  }
  function vormLater() { vorm(); requestAnimationFrame(vorm); setTimeout(vorm, 300); }
  window.addEventListener('resize', vormLater);
  window.addEventListener('orientationchange', vormLater);
  if (screen.orientation && screen.orientation.addEventListener) {
    screen.orientation.addEventListener('change', vormLater);
  }
  function pakSlot() {
    if (!wakker || slot || document.visibilityState !== 'visible' || !navigator.wakeLock) return;
    slot = 'bezig';
    navigator.wakeLock.request('screen').then(function (s) {
      if (!wakker) { slot = null; s.release(); return; }
      slot = s;
      s.addEventListener('release', function () { if (slot === s) slot = null; });
    }, function () { slot = null; });
  }
  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'visible') pakSlot();
  });
  window.dhWeb = {
    zetTerug: function (cb) { opTerug = cb; },
    zetVorm: function (cb) { opVorm = cb; },
    zetOpslag: function (cb) { opOpslag = cb; if (opslag && opslag !== 'bezig') cb(opslag); },
    wapen: wapen,
    gewapend: function () { return eigen(history.state); },
    stand: function () {
      return 'historie=' + history.length + ' gewapend=' + (eigen(history.state) ? 1 : 0) +
        ' wapens=' + wapens + ' terugs=' + terugs + ' opslag=' + (opslag || '-');
    },
    randen: function () { laatsteRanden = randen(); return laatsteRanden; },
    wakker: function (aan) {
      wakker = !!aan;
      if (wakker) pakSlot();
      else if (slot && slot !== 'bezig') { var s = slot; slot = null; s.release(); }
      return !!navigator.wakeLock;
    },
    slot: function () { return slot && slot !== 'bezig' ? 'aan' : 'uit'; }
  };
  // a child that tapped before this glue was there has already given a gesture
  if (navigator.userActivation && navigator.userActivation.hasBeenActive) gebaar();
  return 'ok';
})()
"""

## `scenes/main.gd`, for the intro and the game bar's `⬅ Terug`; null in a
## test that only walks the sheets and the games.
var shell: Node = null
## The glue is on the page (web export only).
var actief := false
## Back presses handled since boot (the probe counts them).
var aantal_terug := 0

var _dh = null                 ## window.dhWeb (a JavaScriptObject)
var _cb_terug = null           ## the callbacks: kept, or they are collected
var _cb_vorm = null
var _cb_opslag = null
var _randen := Rect2()
var _wakker := false
var _wakker_t := 0.0

func _init() -> void:
	name = "Web"

func _ready() -> void:
	if not OS.has_feature("web"):
		set_process(false)
		return
	var uit = JavaScriptBridge.eval(JS_LIJM, true)
	_dh = JavaScriptBridge.get_interface("dhWeb")
	if _dh == null:
		push_warning("UiWeb: de browserlijm kwam niet op (%s)" % str(uit))
		set_process(false)
		return
	actief = true
	_cb_terug = JavaScriptBridge.create_callback(_op_terug)
	_cb_vorm = JavaScriptBridge.create_callback(_op_vorm)
	_cb_opslag = JavaScriptBridge.create_callback(_op_opslag)
	_dh.zetTerug(_cb_terug)
	_dh.zetVorm(_cb_vorm)
	_dh.zetOpslag(_cb_opslag)
	_randen = lees_randen(str(_dh.randen()))
	get_window().size_changed.connect(_op_venster)
	print("[probe] web klaar ", str(_dh.stand()), " randen=", randen_tekst(_randen),
		" eigen_randen=", DisplayServer.get_display_safe_area(),
		" scherm=", DisplayServer.screen_get_usable_rect())

## The window turned or changed size (a phone rotated, the URL bar came or
## went): once it has settled, say where the buttons stand now, so a probe
## that plays on after a rotation taps the new places, not the old ones.
var _venster_nr := 0
func _op_venster() -> void:
	_venster_nr += 1
	var nr := _venster_nr
	await get_tree().create_timer(0.6).timeout
	if nr != _venster_nr or not is_inside_tree():
		return
	var scherm = shell.get("scherm") if shell != null and is_instance_valid(shell) else null
	print("[probe] web venster=", get_window().size, " randen=", randen_tekst(_randen),
		" scherm=", (scherm as Control).size if scherm is Control else Vector2.ZERO,
		" zicht=", (scherm as Control).get_viewport_rect().size if scherm is Control else Vector2.ZERO,
		" min=", (scherm as Control).get_combined_minimum_size() if scherm is Control else Vector2.ZERO)
	if shell != null and is_instance_valid(shell) and shell.has_method("_meld_knoppen"):
		await shell.call("_meld_knoppen")

# ------------------------------------------------------------------- terug

## What a back press does, given what is on the glass.  `t` is `toestand()`:
##   the welcome card is up            -> "intro_weg"  (as a tap does)
##   a sheet that a tap beside closes  -> "blad_dicht" (exactly that tap)
##   a sheet with ⬅ Terug / ⬅ Nee     -> "blad_knop"  (that button)
##   any other sheet (the start sheet) -> "niets"      (it must be answered)
##   a game runs                       -> "spel_terug" (the game bar's ⬅ Terug)
##   nothing                           -> "niets"      (and the app stays)
static func beslis(t: Dictionary) -> String:
	if bool(t.get("intro", false)):
		return "intro_weg"
	if bool(t.get("blad", false)):
		if bool(t.get("blad_sluitbaar", false)):
			return "blad_dicht"
		if str(t.get("blad_knop", "")) != "":
			return "blad_knop"
		return "niets"
	if str(t.get("spel", "")) != "":
		return "spel_terug"
	return "niets"

## What is on the glass right now, in the words of `beslis()`.
func toestand() -> Dictionary:
	var blad := Ui.huidig_blad()
	var knop := blad_terug_knop(blad)
	return {
		"intro": shell != null and shell.has_method("intro_loopt") and bool(shell.call("intro_loopt")),
		"blad": blad != null,
		"blad_sluitbaar": blad != null and blad.sluitbaar,
		"blad_knop": str(knop.name) if knop != null else "",
		"spel": Games.actief(),
	}

## One back press, done the way the child would have done it by hand.
## Returns what it did (one of `beslis()`'s answers).
func terug() -> String:
	var t := toestand()
	var actie := beslis(t)
	match actie:
		"intro_weg":
			var intro = shell.get("intro")
			if intro != null and is_instance_valid(intro) and intro.has_method("sluit"):
				intro.sluit("tik")
		"blad_dicht":
			Ui.blad_dicht()
		"blad_knop":
			var knop := blad_terug_knop(Ui.huidig_blad())
			if knop != null:
				knop.pressed.emit()
		"spel_terug":
			var knop := _spel_terug_knop()
			if knop != null:
				knop.pressed.emit()          # Snd.tik() and Games.stop, as a tap
			else:
				Snd.tik()
				Games.stop()
	aantal_terug += 1
	print("[probe] web terug=", actie, " n=", aantal_terug,
		" blad=", t["blad_knop"] if actie == "blad_knop" else str(t["blad"]),
		" spel=", t["spel"] if str(t["spel"]) != "" else "-")
	return actie

## The sheet's own "back" button, if it has one that can be pressed.
static func blad_terug_knop(blad: Node) -> Button:
	if blad == null or not is_instance_valid(blad):
		return null
	for naam in TERUG_KNOPPEN:
		var k := blad.find_child(naam, true, false) as Button
		if k != null and k.is_visible_in_tree() and not k.disabled:
			return k
	return null

func _spel_terug_knop() -> Button:
	if shell == null or not is_instance_valid(shell):
		return null
	var balk = shell.get("spelbalk")
	if balk == null or not is_instance_valid(balk) or not (balk as Control).is_visible_in_tree():
		return null
	var k = balk.get("terug_knop")
	if k == null or not is_instance_valid(k):
		return null
	return k as Button

## `popstate`: the browser's back.  The game is touched on its own frame,
## never inside the browser's event.
func _op_terug(_args: Array) -> void:
	terug.call_deferred()

# ------------------------------------------------------------------ randen

## The four insets in units (= CSS px): position = (left, top), size =
## (right, bottom) — the shape of `_veilige_randen()` in scenes/main.gd.
func randen() -> Rect2:
	return _randen

## "l,t,r,b" from the page -> Rect2(l, t, r, b); anything unreadable is 0.
static func lees_randen(tekst: String) -> Rect2:
	var d := tekst.split(",")
	var v: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for i in mini(4, d.size()):
		v[i] = maxf(0.0, d[i].strip_edges().to_float())
	return Rect2(v[0], v[1], v[2], v[3])

static func randen_tekst(r: Rect2) -> String:
	return "%d,%d,%d,%d" % [int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)]

func _op_vorm(args: Array) -> void:
	var nieuw := lees_randen(str(args[0]) if args.size() > 0 and args[0] != null else "")
	if nieuw == _randen:
		return
	_randen = nieuw
	print("[probe] web randen=", randen_tekst(_randen))
	call_deferred("emit_signal", "randen_veranderd")

# ------------------------------------------------------- opslag en scherm

func _op_opslag(args: Array) -> void:
	var w := str(args[0]) if args.size() > 0 and args[0] != null else "onbekend"
	print("[probe] web opslag_blijvend=", w, " userfs=", OS.is_userfs_persistent())

## Should the screen stay on?  While a game runs, or a sum card is open.
func wakker_nodig() -> bool:
	if Games.actief() != "":
		return true
	return Ui.has_method("som_in_beeld") and bool(Ui.call("som_in_beeld"))

func _process(delta: float) -> void:
	_wakker_t += delta
	if _wakker_t < WAKKER_ELKE:
		return
	_wakker_t = 0.0
	var nodig := wakker_nodig()
	if nodig == _wakker:
		return
	_wakker = nodig
	var kan = _dh.wakker(nodig)
	print("[probe] web wakker=", "aan" if nodig else "uit", " api=", bool(kan))
