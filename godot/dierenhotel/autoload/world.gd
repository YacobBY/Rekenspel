extends Node
## World — camera, scale, the room in view and the animal runtime.  Autoload #4.
## Port of `demos/dierenhotel/world.js` (world.md §0, §1.9, §2).
##
## The world is drawn inside a SubViewport of `kader * dicht` canvas pixels and
## shown in a TextureRect of `kader` units, exactly reproducing HOTEL.md §1:
## voxels are rasterised at the whole number `g` and the canvas is then scaled
## down smoothly.  `schaal()` is the only source of scale numbers a game may
## read; never the device pixel ratio.
##
## The think tick runs at 15 Hz and is completely independent of the draw rate.
## Between two ticks the room scene glides the animals (`glij()`), so movement
## is smooth without the world thinking any faster.  Animals in rooms you
## cannot see run a coarse tick: they keep their route, but get no poses, no
## particles and no drawing (world.md §2.9).
##
## Determinism (architecture.md §13, Q-X1-1): an animal's idle behaviour is
## seeded from its id and the day, not from the clock, so the same day gives the
## same wandering — reproducible bugs and testable idle rules.

signal kader_veranderd(rect: Rect2, schaal: Dictionary)
signal kamer_veranderd(kamer: String)
signal getekend()
signal reis_gestart(id: String, kamer: String)   ## a guest set off through the doors
signal bak_veranderd(kamer: String, slot: String)  ## a bowl really changed level

const TIK := 1.0 / 15.0     ## world.js STAP: one think tick
const MAX_INHAAL := 3       ## at most 3 catch-up ticks per frame
const KADER_ONDER := 132    ## css-px reserved under the room (keypad band)
const WAND_ZICHT := 56      ## voxel-px of wall that must stay visible
const KADER_MIN := 200
const DICHT_KLEIN := 900    ## short side under this -> density lower bound 2
const REIS_S := 0.300       ## camera slide between two rooms
const REIS_ZIJ := 0.40      ## it starts 40 % of the frame width sideways
const REIS_ALFA := 0.35     ## ... and at this alpha

const MATRAS := 7           ## the top of a mattress, in voxels
const ZWEM_DIEP := ArtEffect.ZWEM_DIEP   ## a swimmer sinks this many voxels
const SPRING_TIKKEN := 6    ## ticks in the air per jump, at tempo 1
const SQUASH := 3           ## ticks flat on the stone after landing
const SPRING_HOOG := {"hond": 5.0, "poes": 6.0, "konijn": 7.0, "gans": 4.0}
## The hop onto a bed (owner, 2026-09-23: "een animatie dat het dier op het bed
## springt wanneer je een vrij bed kiest"): the hinkel's own arc, a little
## slower and this much higher, so the child sees the guest jump in.
const BED_SPRONG_TEMPO := 0.7
const BED_SPRONG_EXTRA := 4.0
const GANG_K := 16.0        ## gait phase per voxel; world.md does not pin it
const DRIJF_PLONS := 30     ## a floating swimmer splashes every 30th tick
const KAUW_PER_NIVEAU := 24  ## ticks one level is chewed off the bowl (V5, ≈1,6 s)

var _kamer_nu: String = ""
var _kader := Rect2()
var _balk := 0.0                   ## units of the frame the maths bar takes (§3.1)
var _schaal := {"g": 3, "dicht": 2.0, "k": 1.5, "q": 1.5,
		"pxPerVoxelX": 3.0, "pxPerVoxelY": 1.5, "pxPerHoogte": 3.0, "kamer": ""}
var _cam := Vector2.ZERO           ## camera origin in canvas px, while sliding
var _cam_doel := Vector2.ZERO      ## where it is going — hotspots already use this
var _reis := 1.0                   ## 0..1 of the slide; 1 = standing still
var _reis_zij := 0.0
var _viewport: SubViewport = null
var _kamerscene: Node2D = null
var _dieren: Dictionary = {}       ## id -> Dier
var _volgorde: Array[String] = []  ## insertion order, for the wander places
var _bakken: Dictionary = {}       ## "kamer|slot" -> 0..4
var _bak_kauw: Dictionary = {}     ## "kamer|slot" -> think ticks chewed on it (V5)
var _kauwers: Dictionary = {}      ## "kamer|slot" -> the animal chewing it this tick
var _deeltjes: Array = []          ## particles, in voxel-px around the room origin
var _tijd := 0.0
var _tikken := 0
var _vuil := true
var _stil_tijd := 0.0
var _pauze := false
var _zaad_dag := 1
var _js_zicht = null
var _rnd := RandomNumberGenerator.new()   ## particles only; seeded per day

## One animal.  `hoogte` is voxels up (+ jump, − swim); `lift` is the same value
## as a downward pixel offset, which is what the HTML calls it.
class Dier extends RefCounted:
	var id: String
	var naam: String
	var kind := "hond"
	var kamer: String
	var x: float
	var z: float
	var px: float                  ## the position at the previous tick (gliding)
	var pz: float
	var face := 1
	var pose := "rust"
	var staat := "stil"
	var bob := 0.0
	var zij := 0.0
	var hoogte := 0.0
	var lift := 0.0
	var acc: Array = []
	var voer := 0                  ## the level its card bowl shows (setFood)
	var model := ""
	var params: Dictionary = {}
	var nr := 0                    ## check-in order, seeds the start place
	## per-animal constants, from its own seeded generator (world.md §2.4)
	var fase := 0.0
	var tempo := 1.0
	var staart_snel := 0.2
	var rustig := 1.0
	var wandel_kans := 0.45
	var blij_stijl := "draai"
	var vmax := 1.3
	var stap_lengte := 0.46
	var bob_hoog := 2.1
	## running state
	var v := 0.0
	var gang := 0.0
	var tikken := 0                ## ticks left in this state
	var kauw := 0                  ## ticks chewed since this bout of eating began (V5)
	var na := ""
	var punten: Array = []         ## points still to walk, in this room
	var route: Array = []          ## rooms still to travel through
	var route_doel := Vector2.INF
	var route_na := ""
	var slaap_doel := ""
	var slaap_kamer := ""
	var beweeg_pose := ""          ## "" | "zwem" | "spring"
	var beweeg_tempo := 1.0
	var per_stap: Callable
	var eind_pose := ""
	var stap_nr := 0
	var spring_t := 0
	var spring_van := Vector2.ZERO
	var spring_naar := Vector2.ZERO
	var spring_h0 := 0.0           ## the height he springs FROM (the stair)
	var spring_land := 0.0         ## the height he springs TO (NAN = same as h0)
	var land_hoogte := NAN         ## the `land_hoogte` of the current order
	var spring_extra := 0.0        ## voxels added to the top of this jump's arc
	var bed_sprong := false        ## this jump ends on the mattress (`_spring_in_bed`)
	var reis_doel := ""            ## the room a `reis` heads for; "" once he is in it
	var reis_deuren := 0           ## doors on that journey
	var reis_klaar := 0            ## doors already passed
	var been_van := Vector2.INF    ## where the leg he is walking started
	## coming in through the front door (`kom_binnen`, state `komt`): the beats
	## still to play (`WereldBinnenkomst`), the ticks into the current one, where
	## it started, and the spot the arrival ends on
	var komt: Array = []
	var komt_t := 0
	var komt_van := Vector2.ZERO
	var komt_doel := Vector2.INF
	var rnd: Sommen.Prng
	var opdracht: Object = null    ## Opdracht, resolved true/false

	func plek() -> Vector2:
		return Vector2(x, z)

## The awaitable movement order.  `await World.stappen(...)` gives a bool:
## true = the last point was reached, false = another order took over.
class Opdracht extends RefCounted:
	signal af(gehaald: bool)
	var klaar := false
	func rond(gehaald: bool) -> void:
		if klaar:
			return
		klaar = true
		af.emit(gehaald)

# ------------------------------------------------------------------ opzet

func registreer_viewport(vp: SubViewport, scene: Node2D) -> void:
	_viewport = vp
	_kamerscene = scene

func _ready() -> void:
	_kamer_nu = "receptie" if Rooms.bestaat("receptie") else ""
	_bouw_dingen()
	_luister_naar_tabblad()

## Hidden tab: the think tick stops completely and the clock restarts on
## return — it never catches up three heartbeats (world.md §6.6).
func _luister_naar_tabblad() -> void:
	if not OS.has_feature("web"):
		return
	_js_zicht = JavaScriptBridge.create_callback(_op_zichtbaarheid)
	var doc = JavaScriptBridge.get_interface("document")
	if doc != null:
		doc.addEventListener("visibilitychange", _js_zicht)

func _op_zichtbaarheid(_args: Array) -> void:
	var verborgen = JavaScriptBridge.eval("document.hidden", true)
	pauzeer(bool(verborgen))

func _notification(wat: int) -> void:
	if wat == NOTIFICATION_APPLICATION_PAUSED:
		pauzeer(true)
	elif wat == NOTIFICATION_APPLICATION_RESUMED:
		pauzeer(false)

func pauzeer(aan: bool) -> void:
	if _pauze == aan:
		return
	_pauze = aan
	_tijd = 0.0
	if not aan:
		_vuil = true

func gepauzeerd() -> bool:
	return _pauze

func _process(delta: float) -> void:
	if not _pauze:
		_tijd += delta
		var tikken := 0
		while _tijd >= TIK and tikken < MAX_INHAAL:
			_tijd -= TIK
			tikken += 1
			_tik()
		if _tijd > TIK * 6.0:
			_tijd = 0.0
		_reis_stap(delta)
		if _glijdt():
			_vuil = true          # somebody is between two ticks: every frame counts
		_stil_tijd += delta
		if _stil_tijd >= 0.4:     # nothing moved: one lazy redraw, as in the HTML
			_stil_tijd = 0.0
			_vuil = true
	if _vuil and _kamerscene != null:
		_kamerscene.queue_redraw()
		_vuil = false
		getekend.emit()
	Hits.plaats()

func vuil() -> void:
	_vuil = true
	_stil_tijd = 0.0

## How far the world is between two think ticks, 0..1 — the room scene glides
## the animals over that fraction so 15 Hz thinking draws smoothly.
func glij() -> float:
	return 0.0 if rust() else clampf(_tijd / TIK, 0.0, 1.0)

func _glijdt() -> bool:
	for d in _dieren.values():
		if d.kamer == _kamer_nu and (not is_equal_approx(d.px, d.x) or not is_equal_approx(d.pz, d.z)):
			return true
	return false

## Reduced motion (architecture.md §5.1): nothing moves, the camera jumps,
## there are no particles and a walk resolves in the same frame.
func rust() -> bool:
	return Ui.rust_modus()

# ------------------------------------------------------------ kader en maat

## Called by the world frame Control whenever its rectangle changes.
func meet(rect: Rect2) -> void:
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	var oud := _kader
	_kader = rect
	# The maths bar of PLAN.md §3.1 is measured on the frame and the world is
	# fitted ABOVE it, so its height has to be known BEFORE the scale is
	# taken.  Asking for it afterwards would mean two `kader_veranderd` per
	# resize, the first one carrying a scale that is already wrong.
	_balk = maxf(0.0, Ui.balk_bepaal())
	_herbouw()
	if oud != _kader:
		kader_veranderd.emit(_kader, _schaal)

## Scale, canvas and camera again for the frame as it stands right now.
func _herbouw() -> void:
	_bereken_schaal()
	if _viewport != null:
		var canvas := Vector2i(
			maxi(1, JsGetal.rond(_kader.size.x * _schaal["dicht"])),
			maxi(1, JsGetal.rond(_kader.size.y * _schaal["dicht"])))
		if _viewport.size != canvas:
			_viewport.size = canvas
	_cam_doel = cam_doel(Rooms.get_kamer(_kamer_nu))
	if _reis >= 1.0:
		_cam = _cam_doel
	_vuil = true

## PLAN.md §3.1 — the units at the bottom of the frame the maths bar takes.
## The world gives way: the room is re-fitted in what is left and the camera
## drops the floor above the paper, so the bar covers no world at all.
##
## `Ui` is the one that measures it, and `meet()` asks before every fit; this
## setter is for a height that changes WITHOUT the frame changing — a card
## docking or letting go mid-turn, and the shape hysteresis of `B5`.
##
## The height is 0 for all the time no card stands in the bar, which is most
## of the game.  That is the owner's rule of 2026-09-19 and the reason this
## task lands without moving a single existing number: with `_balk == 0` every
## line below is the line it used to be.
func zet_balk(h: float) -> void:
	var nieuw := maxf(0.0, h)
	if is_equal_approx(nieuw, _balk):
		return
	_balk = nieuw
	if _kader.size.x < 1.0 or _kader.size.y < 1.0:
		return
	_herbouw()
	kader_veranderd.emit(_kader, _schaal)

## What the bar takes of the frame right now.  0 while nothing is docked.
func balk_hoog() -> float:
	return _balk

func kader_rect() -> Rect2:
	return _kader

func hermeet() -> void:
	meet(_kader)

## `World.schaal()` — {g, dicht, k, q, pxPerVoxelX, pxPerVoxelY, pxPerHoogte}.
func schaal() -> Dictionary:
	return _schaal.duplicate()

func px_per_hoogte() -> float:
	return _schaal["pxPerHoogte"]

## world.md §1.9 `schermDicht()`, with the tablet cap of art-sound-rules §18.3.
func scherm_dicht() -> float:
	var dpr := 1.0
	if DisplayServer.has_method("screen_get_scale"):
		dpr = maxf(1.0, DisplayServer.screen_get_scale())
	var kort := minf(_kader.size.x, _kader.size.y)
	if dpr > 2.0 and kort < DICHT_KLEIN:
		return 2.0
	return minf(3.0, dpr)

## world.md §1.9 `maatVan()`: q, then the whole-number g, then dicht.
func _bereken_schaal() -> void:
	var r := Rooms.get_kamer(_kamer_nu)
	var d := scherm_dicht()
	var box_w := 200.0
	var nodig_h := 150.0
	if r != null:
		var box := Rooms.kader(r)
		box_w = float(box[1] - box[0])
		nodig_h = nodig_hoog(r)
	# The maths bar comes off the top of the height budget before anything is
	# fitted: the room is drawn in the frame MINUS the strip (PLAN.md §3.1).
	var q := minf((maxf(240.0, _kader.size.x) - 4.0) / box_w,
			maxf(120.0, _kader.size.y - 4.0 - _balk) / nodig_h)
	q = maxf(q, 0.01)
	var ng := clampi(JsGetal.rond(q * d), 2, 4)
	if float(ng) / d < q * 0.9:
		ng = clampi(JsGetal.plafond(q * d), 2, 4)
	var dicht := maxf(d, float(ng) / q)
	var k := float(ng) / dicht
	_schaal = {"g": ng, "dicht": dicht, "k": k, "q": k,
			"pxPerVoxelX": 2.0 * k, "pxPerVoxelY": k, "pxPerHoogte": 2.0 * k,
			"kamer": _kamer_nu}

## The floor plus a 56 voxel-px strip of wall must always fit; bare wall above
## that may be cut off.  The floor never may be.
func nodig_hoog(r: Rooms.Kamer) -> float:
	var box := Rooms.kader(r)
	return float(box[3] - box[2]) - maxf(0.0, float(-box[2] - WAND_ZICHT))

## world.md §1.9 `camDoel()` — the floor stays whole; bare wall is cut at the top.
func cam_doel(r: Rooms.Kamer) -> Vector2:
	if r == null or _viewport == null:
		return Vector2.ZERO
	var box := Rooms.kader(r)
	var g: int = _schaal["g"]
	var dicht: float = _schaal["dicht"]
	var w := float(_viewport.size.x)
	var h := float(_viewport.size.y)
	var cx := w / 2.0 - float(box[0] + box[1]) / 2.0 * g
	var over := h - float(box[3] - box[2]) * g
	# The strip of the maths bar is part of what the camera keeps free under
	# the room, so the room ends ABOVE the paper in both branches (§3.1).
	var onder := minf((KADER_ONDER + _balk) * dicht, maxf(0.0, over))
	# The lowest the box may ever hang: its bottom edge against the top of the
	# bar, with the same four pixels of air the old bottom edge had.
	var laagst := h - 4.0 - _balk * dicht - float(box[3]) * g
	var cy := laagst
	if over >= 0.0:
		# It does fit: centre it in what is left, minus the strip the camera
		# keeps free underneath.  But `over` is measured on the WHOLE box
		# while the fit above only had to make `nodig_hoog` fit (bare wall may
		# be cut off), so the air under the room can be far less than the bar
		# is tall — and then centring would drop the floor straight into the
		# paper.  The lowest the box may hang is the same edge the other
		# branch uses.
		cy = minf((over - onder) / 2.0 - float(box[2]) * g, laagst)
	return Vector2(cx, cy)

func cam() -> Vector2:
	return _cam

## 0.35 -> 1 while the camera slides, so the room fades in with its own move.
func reis_alfa() -> float:
	return 1.0 if _reis >= 1.0 else REIS_ALFA + (1.0 - REIS_ALFA) * _ease(_reis)

func _ease(t: float) -> float:
	return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0

func _reis_stap(delta: float) -> void:
	if _reis >= 1.0:
		return
	_reis = minf(1.0, _reis + delta / REIS_S)
	_cam = _cam_doel + Vector2(_reis_zij * (1.0 - _ease(_reis)), 0.0)
	_vuil = true

# ------------------------------------------------------------- projectie

## Canvas px inside the world SubViewport (world.md §0), with the camera where
## it is RIGHT NOW — this is what the drawing uses.
func scherm(x: float, z: float, y: float = 0.0) -> Vector2:
	var g: float = float(_schaal["g"])
	return Vector2(
		_cam.x + (x - z) * Art.S * g,
		_cam.y + (x + z) * (Art.S / 2.0) * g - y * Art.HG * g)

## The same point with the camera where it is GOING.  During the 300 ms slide
## the hotspots already sit at their destination, so a tap halfway through
## lands on the right object (world.md §1.9).
func scherm_doel(x: float, z: float, y: float = 0.0) -> Vector2:
	var g: float = float(_schaal["g"])
	return Vector2(
		_cam_doel.x + (x - z) * Art.S * g,
		_cam_doel.y + (x + z) * (Art.S / 2.0) * g - y * Art.HG * g)

## The point in frame units (css px) — what a hotspot or a card uses.
func mik_punt(x: float, z: float, y: float = 0.0) -> Vector2:
	return scherm_doel(x, z, y) / _schaal["dicht"]

## `World.mik(obj)` — the aim point of a decor piece, a slot or a raw point.
func mik(obj: Variant, kamer_id: String = "") -> Dictionary:
	if obj is Dictionary:
		return obj
	if obj is String:
		var k: String = kamer_id if kamer_id != "" else _kamer_nu
		var los := decor_plek(obj, k)
		if not los.is_empty():
			return los
		var r := Rooms.get_kamer(k)
		if r != null:
			if r.slots.has(obj):
				return r.slots[obj]
			for stuk in r.decor:
				if stuk["n"] == obj:
					return stuk
	return {}

## The screen rectangle a model occupies, in frame units.  Hotspots need it to
## guarantee 0 % coverage; it comes straight from the baked plate — the turned
## plate when the piece stands turned (`rot`), or a turned board or bed got the
## box of the unturned one.
func vlak_van(model: String, x: float, z: float, y: float, params: Dictionary = {},
		anker := Vector2.ZERO, rot := 0) -> Rect2:
	var p = plaat(model, _schaal["g"], params, rot)
	if p == null:
		return Rect2()
	var g: float = float(_schaal["g"])
	var dicht: float = _schaal["dicht"]
	var mid := scherm_doel(x, z, y)
	var ank := Vector2(
		(anker.x - anker.y) * Art.S * g,
		(anker.x + anker.y) * (Art.S / 2.0) * g)
	return Rect2((mid + Vector2(p.dx, p.dy) - ank) / dicht, Vector2(p.w, p.h) / dicht)

## The screen rectangle of a door opening, in frame units (I1 finding 5).
##
## A door is not a model: `scenes/vloer.gd` cuts the hole out of the wall, so
## its rectangle is that hole projected — the door point plus the opening's own
## width and the height the wall drawing uses (`Rooms.deur_hoog`).  Without it a
## door button had nothing to stay off and `Hits.dekking()` proved nothing for
## it.  A garden gate cuts no hole: its rectangle is the gate model standing in
## the fence line (`hek_x` / `hek_z`), as tall as that gate — measured on the
## door line instead, the pool gate's button landed on the gate itself.
func vlak_van_deur(kamer_id: String, naar: String) -> Rect2:
	var r := Rooms.get_kamer(kamer_id)
	if r == null:
		return Rect2()
	for dr in r.deuren:
		if str(dr.get("naar", "")) != naar:
			continue
		var a := float(dr.get("at", 0))
		var b := a + float(dr.get("breed", 12))
		var h := float(Rooms.deur_hoog(r, dr))
		var langs_z := str(dr.get("wand", "z")) == "z"
		var lijn := 0.0
		if bool(dr.get("poort", false)):
			lijn = float(r.hek_z if langs_z else r.hek_x)
		var randen: Array = [[a, lijn], [b, lijn]] if langs_z else [[lijn, a], [lijn, b]]
		var hoeken: Array[Vector2] = []
		for xz in randen:
			hoeken.append(mik_punt(float(xz[0]), float(xz[1]), 0.0))
			hoeken.append(mik_punt(float(xz[0]), float(xz[1]), h))
		var vak := Rect2(hoeken[0], Vector2.ZERO)
		for p in hoeken:
			vak = vak.expand(p)
		return vak
	return Rect2()

## The screen rectangle of a room's front door (`Kamer.ingang`, the receptie
## only), in frame units: the opening and its frame, as tall as every door
## (`Rooms.deur_hoog`) plus the lintel.  `Rect2()` for a room without one.  The
## front door is no door of the graph, so no door button stands on it and
## `vlak_van_deur` does not know it; this is its box for whatever has to keep
## off it or measure against it.
func vlak_van_ingang(kamer_id: String = "") -> Rect2:
	var r := Rooms.get_kamer(kamer_id if kamer_id != "" else _kamer_nu)
	if r == null or r.ingang.is_empty():
		return Rect2()
	var a := float(r.ingang.get("at", 0)) - 1.0
	var b := a + float(r.ingang.get("breed", 12)) + 2.0
	var h := float(Rooms.deur_hoog(r, r.ingang)) + 2.0
	var langs_z := str(r.ingang.get("wand", "z")) == "z"
	var randen: Array = [[a, 0.0], [b, 0.0]] if langs_z else [[0.0, a], [0.0, b]]
	var vak := Rect2(mik_punt(float(randen[0][0]), float(randen[0][1]), 0.0), Vector2.ZERO)
	for xz in randen:
		vak = vak.expand(mik_punt(float(xz[0]), float(xz[1]), 0.0))
		vak = vak.expand(mik_punt(float(xz[0]), float(xz[1]), h))
	return vak

## The screen rectangle of the reception desk (`Kamer.balie`), in frame units.
##
## The desk carries the bell, the till, the guest book and the lamp — everything
## the child taps at the counter — so a fixed card may hang OVER the world but
## never over this box (V1 finding 4).  It is the footprint projected at floor
## level and at the desk top, so the front face counts too.
const BALIE_HOOG := 16.0

func vlak_van_balie(kamer_id: String = "") -> Rect2:
	var r := Rooms.get_kamer(kamer_id if kamer_id != "" else _kamer_nu)
	if r == null or (r.balie as Dictionary).is_empty():
		return Rect2()
	var x0 := float(r.balie["x0"])
	var x1 := float(r.balie["x1"])
	var z0 := float(r.balie["z0"])
	var z1 := float(r.balie["z1"])
	var vak := Rect2(mik_punt(x0, z0, 0.0), Vector2.ZERO)
	for hoek in [[x0, z0], [x1, z0], [x1, z1], [x0, z1]]:
		vak = vak.expand(mik_punt(hoek[0], hoek[1], 0.0))
		vak = vak.expand(mik_punt(hoek[0], hoek[1], BALIE_HOOG))
	return vak

## The desk as the button layer keeps off it: the plate of every piece that
## stands on the `Kamer.balie` footprint — the two desk halves and the bell,
## till, flowers, book and lamp on top — instead of the one box round the
## whole footprint.  The desk runs diagonally across the screen, so that box
## is mostly FLOOR: the whole strip in front of the counter, where a guest
## checks in, was off limits, and the check-in card, the family bubbles and the
## bill's hints were pushed out into the room far from the counter (owner,
## 2026-09-23: "helemaal niet relevant aan waar de tekst geplaatst is").
func vlakken_van_balie(kamer_id: String = "") -> Array[Rect2]:
	var uit: Array[Rect2] = []
	var k := kamer_id if kamer_id != "" else _kamer_nu
	var r := Rooms.get_kamer(k)
	if r == null or (r.balie as Dictionary).is_empty():
		return uit
	var x0 := float(r.balie["x0"])
	var x1 := float(r.balie["x1"])
	var z0 := float(r.balie["z0"])
	var z1 := float(r.balie["z1"])
	var stukken: Array = []
	stukken.append_array(r.decor)
	stukken.append_array(dingen(k))      # the desk lamp is a movable thing
	for stuk in stukken:
		var x := float(stuk.get("x", 0.0))
		var z := float(stuk.get("z", 0.0))
		if x < x0 or x > x1 or z < z0 or z > z1:
			continue
		var model := str(stuk.get("model", stuk.get("n", "")))
		if model.is_empty() or not Art.heeft_model(model):
			continue
		var v := vlak_van(model, x, z, float(stuk.get("y", 0.0)), stuk.get("params", {}),
			Vector2.ZERO, int(stuk.get("rot", 0)))
		if v.size.x > 0.0 and v.size.y > 0.0:
			uit.append(v)
	return uit

## The rectangle of one guest, from its own plate — used by the hotspot layer.
func vlak_van_dier(id: String) -> Rect2:
	var d: Dier = _dieren.get(id)
	if d == null:
		return Rect2()
	return vlak_van(d.model, d.x, d.z, d.hoogte, d.params, Art.DIER_ANKER)

## Where the name plate of a guest hangs, in frame units (world.md §2.10).
func naam_punt(id: String) -> Vector2:
	var d: Dier = _dieren.get(id)
	if d == null:
		return Vector2.ZERO
	var g: float = float(_schaal["g"])
	var p := scherm_doel(d.x, d.z, 0.0)
	p.y += (-(30.0 * Art.HG + 8.0) + d.bob + d.lift) * g
	return p / _schaal["dicht"]

# ------------------------------------------------------------------ kamers

func kamer_nu() -> String:
	return _kamer_nu

## world.md §1.9 — re-measure first (the new room may have another `g`), then
## slide the camera in from the side while the frame fades in.
func naar(kamer_id: String) -> void:
	if not Rooms.bestaat(kamer_id) or kamer_id == _kamer_nu:
		return
	var oud := _kamer_nu
	_kamer_nu = kamer_id
	_bereken_schaal()
	hermeet()
	_cam_doel = cam_doel(Rooms.get_kamer(kamer_id))
	var lijst := Rooms.lijst()
	var later := lijst.find(kamer_id) > lijst.find(oud)
	if rust() or _kader.size.x < 1.0 or _viewport == null:
		_reis = 1.0
		_cam = _cam_doel
	else:
		_reis = 0.0
		_reis_zij = (REIS_ZIJ if later else -REIS_ZIJ) * float(_viewport.size.x)
		_cam = _cam_doel + Vector2(_reis_zij, 0.0)
	_vuil = true
	kamer_veranderd.emit(kamer_id)

func reist() -> bool:
	return _reis < 1.0

# ------------------------------------------------------------- los decor
##
## `World.decor(kamer, o)` — a game's own loose decor (world.md §1.7).  Not
## saved; owned by the game that placed it; wiped when another game starts.

const LOS_MAX := 48                ## pieces of loose decor per room

var _decor: Dictionary = {}        ## kamer -> {id -> stuk}
var _decor_versie := 0

## Create or update one piece.  Returns a COPY, or {} on: unknown room, missing
## id, unknown model, a piece owned by another game, or a full room.
func decor(kamer_id: String, o: Dictionary) -> Dictionary:
	if not Rooms.bestaat(kamer_id):
		return {}
	var id: String = o.get("id", "")
	var model: String = o.get("model", "")
	if id.is_empty() or not Art.heeft_model(model):
		return {}
	if not _decor.has(kamer_id):
		_decor[kamer_id] = {}
	var kamer: Dictionary = _decor[kamer_id]
	var door: String = o.get("door", Games.actief())
	if kamer.has(id) and kamer[id]["door"] != door:
		return {}
	if not kamer.has(id) and kamer.size() >= LOS_MAX:
		return {}
	var stuk := {
		"id": id, "model": model, "kamer": kamer_id,
		"x": float(o.get("x", 0.0)), "z": float(o.get("z", 0.0)),
		"hoog": float(o.get("hoog", o.get("y", 0.0))),
		"rot": int(o.get("rot", 0)), "ver": bool(o.get("ver", false)),
		"params": o.get("params", {}), "door": door,
	}
	kamer[id] = stuk
	_decor_versie += 1
	vuil()
	return stuk.duplicate(true)

func decor_weg(kamer_id: String, id: String) -> bool:
	if not _decor.has(kamer_id) or not _decor[kamer_id].has(id):
		return false
	_decor[kamer_id].erase(id)
	_decor_versie += 1
	vuil()
	return true

func decor_lijst(kamer_id: String = "") -> Array:
	var uit: Array = []
	for k in _decor.keys():
		if kamer_id != "" and k != kamer_id:
			continue
		for stuk in _decor[k].values():
			uit.append(stuk.duplicate(true))
	return uit

## Where a piece stands, for a hotspot that hangs on it.
func decor_plek(id: String, kamer_id: String = "") -> Dictionary:
	for k in _decor.keys():
		if kamer_id != "" and k != kamer_id:
			continue
		if _decor[k].has(id):
			return _decor[k][id].duplicate(true)
	return {}

func decor_wis_eigenaar(door: String) -> void:
	for k in _decor.keys():
		for id in _decor[k].keys():
			if _decor[k][id]["door"] == door:
				_decor[k].erase(id)
	_decor_versie += 1
	vuil()

## Bumped on every change; the room scene rebuilds its nodes when it moves.
func decor_versie() -> int:
	return _decor_versie

# -------------------------------------------------------------- de dingen
##
## Two pieces of decor are movable "dingen" (world.md §1.3): the desk lamp and
## the food trolley.  They are lifted out of the room's decor list at boot, so
## a game can push them around without touching the room itself.

var _dingen: Dictionary = {}       ## id -> {id, model, kamer, x, z, hoog}
var _dingen_thuis: Dictionary = {} ## id -> the same record as it stood at boot

func _bouw_dingen() -> void:
	_dingen.clear()
	_dingen_thuis.clear()
	for kid in Rooms.lijst():
		var r := Rooms.get_kamer(kid)
		for i in range(r.decor.size() - 1, -1, -1):
			var stuk: Dictionary = r.decor[i]
			var sleutel: String = stuk.get("sleutel", "")
			if sleutel.is_empty() and stuk["n"] != "kar":
				continue
			var id := sleutel if sleutel != "" else "kar"
			_dingen[id] = {"id": id, "model": stuk["n"], "kamer": kid,
				"x": float(stuk["x"]), "z": float(stuk["z"]),
				"hoog": float(stuk.get("y", 0.0))}
			_dingen_thuis[id] = _dingen[id].duplicate()
			r.decor.remove_at(i)
		Rooms.bouw_af(r)

func ding(id: String) -> Dictionary:
	return _dingen.get(id, {}).duplicate()

## Where a thing stood when the world was built: the trolley in the kitchen at
## (48, 66), the desk lamp on the reception counter.  A game that pushes a thing
## through the hotel needs this to bring it back, because its entry button hangs
## on the thing itself (`Games._plek_van`) and would otherwise be unreachable in
## the room the thing belongs to.
func ding_thuis(id: String) -> Dictionary:
	return _dingen_thuis.get(id, {}).duplicate()

## Put a thing back: its home room, its home tile and the model it started with
## (`lampaan` -> `lamp`).  Redraws through `zet_ding`; the camera stays where it
## is, so a game may call this while the child is looking at another room.
func ding_thuis_zet(id: String) -> Dictionary:
	var thuis: Dictionary = _dingen_thuis.get(id, {})
	if thuis.is_empty():
		return {}
	return zet_ding(id, {"kamer": thuis["kamer"], "x": thuis["x"],
		"z": thuis["z"], "hoog": thuis["hoog"], "model": thuis["model"]})

func dingen(kamer_id: String = "") -> Array:
	var uit: Array = []
	for id in _dingen:
		if kamer_id == "" or _dingen[id]["kamer"] == kamer_id:
			uit.append(_dingen[id].duplicate())
	return uit

## Move a thing, change its model (`lamp` -> `lampaan`), or both.
func zet_ding(id: String, o: Dictionary) -> Dictionary:
	if not _dingen.has(id):
		return {}
	var stuk: Dictionary = _dingen[id]
	for sleutel in ["kamer", "x", "z", "hoog", "model"]:
		if o.has(sleutel):
			stuk[sleutel] = o[sleutel]
	vuil()
	return stuk.duplicate()

# ------------------------------------------------------------------ platen

const DRAAI_MAX := 24              ## rotated plates kept beside the Art cache

var _draai_cache: Dictionary = {}
var _draai_orde: Array[String] = []

## The plate of a model, with the quarter turns of `rot` applied.  `rot == 0`
## is the plain `Art.plaat()` and its LRU; a rotated piece is baked from the
## same voxel list through `Art.bak()` and kept in a small cache of its own, so
## the model registry does not need a rotation parameter (world.md §1.7).
func plaat(model: String, g: int, params: Dictionary = {}, rot: int = 0):
	if posmod(rot, 4) == 0:
		return Art.plaat(model, g, params)
	var sleutel := "%s|%d|%s|%d" % [model, g, JSON.stringify(params), posmod(rot, 4)]
	if _draai_cache.has(sleutel):
		_draai_orde.erase(sleutel)
		_draai_orde.append(sleutel)
		return _draai_cache[sleutel]
	var voxels := Art.model(model, params)
	if voxels.is_empty():
		return null
	var p = Art.bak(_roteer(voxels, rot), g)
	if p == null:
		return null
	_draai_cache[sleutel] = p
	_draai_orde.append(sleutel)
	while _draai_orde.size() > DRAAI_MAX:
		_draai_cache.erase(_draai_orde.pop_front())
	return p

## `rot` quarter turns about y — a real rotation, not a mirror (world.md §1.7):
##   rot 1: [x, y, z] -> [z, y, -x]
func _roteer(voxels: Array, rot: int) -> Array:
	var uit: Array = voxels
	for _ronde in posmod(rot, 4):
		var stap: Array = []
		for stuk in uit:
			var kopie: Dictionary = stuk.duplicate()
			kopie["x"] = stuk["z"]
			kopie["z"] = -int(stuk["x"])
			stap.append(kopie)
		uit = stap
	return uit

# ------------------------------------------------------------------ bakken

## `World.setBak(kamer, slot, 0..4)` — how full a feeding bowl is (world.md §2.8).
## `bak_veranderd` goes out only when the level really moves (V5, PLAN.md): the
## shell repaints the bowl button off that signal, and writing 4 over 4 says
## nothing, so it must not wake a repaint either.
func zet_bak(kamer_id: String, slot: String, niveau: int) -> int:
	var n := clampi(niveau, 0, 4)
	var oud := bak_stand(kamer_id, slot)
	_bakken["%s|%s" % [kamer_id, slot]] = n
	if oud != n:
		# the chew restarts with the change: the counter counts ticks chewed
		# since this bowl last moved, so every level costs KAUW_PER_NIVEAU
		_bak_kauw.erase("%s|%s" % [kamer_id, slot])
		bak_veranderd.emit(kamer_id, slot)
	vuil()
	return n

func bak_stand(kamer_id: String, slot: String) -> int:
	return _bakken.get("%s|%s" % [kamer_id, slot], 0)

## `Art.niveau(aantal, per)` — how many scoops map to which of the four levels.
func voer_niveau(aantal: int, per: int) -> int:
	return Art.niveau(aantal, per)

# ------------------------------------------------------------------ dieren

## Which model draws a guest of this species.  W4 may register the real models
## under the same names; if it only registers a bare `hond`, that is used.
func gast_model(kind: String) -> String:
	if Art.heeft_model("gast_" + kind):
		return "gast_" + kind
	if Art.heeft_model(kind):
		return kind
	return "gast_hond"

## Teleport.  Clears the route, the bed target and the lift; state `stil` for
## 12 ticks.  Without x/z it uses wander place `[(nr*3 + 1) % n]`.
func zet(id: String, kamer: String, x: float = NAN, z: float = NAN,
		o: Dictionary = {}) -> Dier:
	var d: Dier = _dieren.get(id)
	if d == null:
		d = Dier.new()
		d.id = id
		d.nr = _volgorde.size()
		_dieren[id] = d
		_volgorde.append(id)
	_breek(d, false)
	d.naam = o.get("naam", d.naam if d.naam != "" else id)
	d.kind = o.get("kind", d.kind)
	if o.has("acc"):
		d.acc = o["acc"]
	if o.has("nr"):
		d.nr = int(o["nr"])
	_zaai(d)
	if Rooms.bestaat(kamer):
		d.kamer = kamer
	if is_nan(x) or is_nan(z):
		var r := Rooms.get_kamer(d.kamer)
		if r != null and not r.plekken.is_empty():
			var p: Array = r.plekken[(d.nr * 3 + 1) % r.plekken.size()]
			x = p[0]
			z = p[1]
		else:
			x = 0.0
			z = 0.0
	d.x = x
	d.z = z
	d.px = x
	d.pz = z
	d.route = []
	d.punten = []
	d.slaap_doel = ""
	d.slaap_kamer = ""
	d.hoogte = 0.0
	d.lift = 0.0
	d.v = 0.0
	d.staat = "stil"
	d.tikken = 12
	d.pose = "rust"
	_model_bij(d)
	vuil()
	return d

## The animal's own generator: same day, same guest, same wandering
## (architecture.md §13, Q-X1-1).  Never `Date.now()`.
func _zaai(d: Dier) -> void:
	var zaad := JsGetal.u32(Sommen.hash_tekst(d.id) ^ JsGetal.u32(_zaad_dag * 2654435761))
	d.rnd = Sommen.Prng.new(zaad)
	var r := d.rnd
	d.fase = r.volgende() * 6.283
	d.tempo = 0.78 + r.volgende() * 0.5
	d.staart_snel = 0.16 + r.volgende() * 0.2
	d.rustig = 0.6 + r.volgende() * 0.9
	d.wandel_kans = 0.34 + r.volgende() * 0.22
	d.blij_stijl = ["draai", "hup", "wiebel"][(d.nr + int(_zaad_dag)) % 3]
	var basis := 1.5 if d.kind == "konijn" else (1.0 if d.kind == "gans" else 1.3)
	d.vmax = basis * d.tempo
	d.stap_lengte = 0.26 if d.kind == "konijn" else (0.60 if d.kind == "gans" else 0.46)
	d.bob_hoog = 5.0 if d.kind == "konijn" else (1.4 if d.kind == "gans" else 2.1)

## The day seeds every animal; call it from `Hotel.morgen()`.
func zet_dag(dag: int) -> void:
	_zaad_dag = maxi(1, dag)
	_rnd.seed = JsGetal.u32(dag * 2654435761)
	for d in _dieren.values():
		_zaai(d)

func _model_bij(d: Dier) -> void:
	d.model = gast_model(d.kind)
	d.params = {"pose": d.pose, "acc": ArtGasten.acc_sleutel(d.acc)}

func dier(id: String) -> Dier:
	return _dieren.get(id)

func dieren(kamer: String = "") -> Array:
	var uit: Array = []
	for id in _volgorde:
		var d: Dier = _dieren[id]
		if kamer == "" or d.kamer == kamer:
			uit.append(d)
	return uit

func weg(id: String) -> void:
	var d: Dier = _dieren.get(id)
	if d == null:
		return
	_breek(d, false)
	_dieren.erase(id)
	_volgorde.erase(id)
	vuil()

## Bring the world in line with the save: every guest in its own room, sleepers
## in their bed.  `Hotel.start()` calls this after the furniture is restored.
func sync(gasten: Array) -> void:
	var gezien := {}
	for g in gasten:
		var id: String = g.get("id", "")
		if id.is_empty():
			continue
		gezien[id] = true
		var kamer: String = g.get("waar", g.get("kamer", "receptie"))
		if not Rooms.bestaat(kamer):
			kamer = "receptie"
		var d: Dier = _dieren.get(id)
		if d == null:
			d = zet(id, kamer, NAN, NAN, {"naam": g.get("naam", id),
				"kind": g.get("kind", "hond"), "acc": g.get("accessoires", [])})
		else:
			d.naam = g.get("naam", d.naam)
			d.kind = g.get("kind", d.kind)
			d.acc = g.get("accessoires", d.acc)
			_model_bij(d)
	for id in _volgorde.duplicate():
		if not gezien.has(id):
			weg(id)
	vuil()

## An accessory change is idempotent and always REPLACES the list.
func accessoire(id: String, naam: String, aan: bool = true) -> Array:
	var d: Dier = _dieren.get(id)
	if d == null:
		return []
	var uit: Array = []
	for a in ArtGasten.ACC_NAMEN:
		var heeft: bool = d.acc.has(a)
		if a == naam:
			heeft = aan
		if heeft:
			uit.append(a)
	d.acc = uit
	_model_bij(d)
	vuil()
	return uit.duplicate()

# -------------------------------------------------------- bewegen (world.md §2.5)

## `World.loopNaar(id, x, z, o)` — awaitable.  See `stappen`.
func loop_naar(id: String, x: float, z: float, o: Dictionary = {}) -> bool:
	return await stappen(id, [Vector2(x, z)], o)

## `World.stappen(id, punten, o)` — walk a list of points in the animal's own
## room.  Returns true when the last point was reached, false as soon as another
## order takes the animal over.  Never throws, never rejects.
##
##   o = {pose: "" | "zwem" | "spring", tempo: 1.0, per_stap: Callable, na: ""}
##
## Walking and swimming glide through the points and brake only for the last
## one; jumping deliberately does not glide.  A game MUST re-check `actief`
## after every await (architecture.md §6.2).
func stappen(id: String, punten: Array, o: Dictionary = {}) -> bool:
	var d: Dier = _dieren.get(id)
	if d == null:
		return false
	var lijst := _punten_van(punten)
	if lijst.is_empty():
		return true
	if str(o.get("pose", "")).is_empty() and not (o.get("per_stap", o.get("perStap", Callable())) as Callable).is_valid():
		# a walk: every leg goes round the water (a walk that counts its own
		# points keeps them, or the count would be off)
		var droog: Array = []
		var van := Vector2(d.x, d.z)
		for p in lijst:
			droog.append_array(Rooms.om_het_water(d.kamer, van, p))
			droog.append(p)
			van = p
		lijst = droog
	_breek(d, false)
	d.beweeg_pose = o.get("pose", "")
	d.beweeg_tempo = maxf(0.05, float(o.get("tempo", 1.0)))
	d.per_stap = o.get("per_stap", o.get("perStap", Callable()))
	d.eind_pose = o.get("na", "wacht")
	d.land_hoogte = float(o.get("land_hoogte", NAN))
	if rust():
		for i in lijst.size():
			if d.per_stap.is_valid():
				d.per_stap.call(i, lijst[i])
		_zet_plek(d, lijst[lijst.size() - 1])
		d.punten = []
		_eind_staat(d)
		vuil()
		return true
	var op := Opdracht.new()
	d.opdracht = op
	d.punten = lijst
	d.stap_nr = 0
	d.staat = "spring" if d.beweeg_pose == "spring" else \
		("zwem" if d.beweeg_pose == "zwem" else "loop")
	d.na = d.eind_pose
	d.v = maxf(d.v, 0.14 * d.vmax)
	if d.staat == "spring":
		_spring_start(d)
	vuil()
	return await op.af

## The walking points to `doel` from where `d` stands: round the water when the
## straight line would cut through it (Rooms.om_het_water).  Swimmers and
## jumpers keep their own line.
func _droog_pad(d: Dier, doel: Vector2) -> Array:
	var uit: Array = Rooms.om_het_water(d.kamer, Vector2(d.x, d.z), doel)
	uit.append(doel)
	return uit

## Only finite points count; `{x, z}`, `[x, z]` and `Vector2` are all accepted.
func _punten_van(punten: Array) -> Array:
	var uit: Array = []
	for p in punten:
		var v := Vector2.INF
		if p is Vector2:
			v = p
		elif p is Dictionary and p.has("x") and p.has("z"):
			v = Vector2(p["x"], p["z"])
		elif p is Array and p.size() >= 2:
			v = Vector2(p[0], p[1])
		if is_finite(v.x) and is_finite(v.y):
			uit.append(v)
	return uit

## Walk inside the current room, then take state `na`.  Not awaitable.
func ga(id: String, x: float, z: float, na: String = "") -> bool:
	var d: Dier = _dieren.get(id)
	if d == null:
		return false
	_breek(d, false)
	d.beweeg_pose = ""
	d.beweeg_tempo = 1.0
	d.per_stap = Callable()
	d.eind_pose = na
	d.na = na
	if rust():
		_zet_plek(d, Vector2(x, z))
		_eind_staat(d)
		vuil()
		return true
	d.punten = _droog_pad(d, Vector2(x, z))
	d.staat = "loop"
	vuil()
	return true

## Walk THROUGH the doors to another room.  Returns the path it will take.
## No path (same room, unknown room) is not an order at all: a swimmer or a
## running command is left alone.
func reis(id: String, kamer: String, o: Dictionary = {}) -> Array:
	var d: Dier = _dieren.get(id)
	if d == null or not Rooms.bestaat(kamer):
		return []
	var route := Rooms.pad(d.kamer, kamer)
	if route.size() < 2:
		return []
	_breek(d, false)
	d.route = route.slice(1)
	d.reis_doel = kamer
	d.reis_deuren = d.route.size()
	d.reis_klaar = 0
	d.been_van = Vector2(d.x, d.z)
	d.route_na = o.get("na", "")
	d.route_doel = Vector2.INF
	if o.has("x") and o.has("z"):
		d.route_doel = Vector2(o["x"], o["z"])
	d.beweeg_pose = ""
	d.beweeg_tempo = 1.0
	d.per_stap = Callable()
	if rust():
		while not d.route.is_empty():
			_stap_door_deur(d)
		_klaar_met_route(d)
		vuil()
		return route
	_volgende_deur(d)
	vuil()
	reis_gestart.emit(id, kamer)
	return route

## Guests walking to `kamer` through the doors who are not there yet — the
## ones a "komt eraan" bubble is for (owner, 2026-09-14).
func onderweg_naar(kamer: String) -> Array[String]:
	var uit: Array[String] = []
	for id in _volgorde:
		var d: Dier = _dieren[id]
		if d.reis_doel == kamer and d.kamer != kamer:
			uit.append(id)
	return uit

## How far along his journey a guest is, 0..1, counted in doors: the doors
## passed plus the part of the leg he is on, over the doors of the whole trip.
## 1 the moment he steps into the room he is heading for.
func reis_voortgang(id: String) -> float:
	var d: Dier = _dieren.get(id)
	if d == null or d.reis_doel == "" or d.reis_deuren <= 0:
		return 1.0
	var deel := 0.0
	if not d.punten.is_empty() and is_finite(d.been_van.x):
		var doel: Vector2 = d.punten[0]
		var heel := d.been_van.distance_to(doel)
		if heel > 0.001:
			deel = clampf(1.0 - Vector2(d.x, d.z).distance_to(doel) / heel, 0.0, 1.0)
	return clampf((float(d.reis_klaar) + deel) / float(d.reis_deuren), 0.0, 1.0)

## The room a travelling guest steps out of into the room he is heading for —
## that is the door his bubble hangs on.
func reis_van(id: String) -> String:
	var d: Dier = _dieren.get(id)
	if d == null or d.reis_doel == "":
		return ""
	var route := Rooms.pad(d.kamer, d.reis_doel)
	return "" if route.size() < 2 else str(route[route.size() - 2])

## Go to bed (world.md §2.7).  Already in that room — or reduced motion — and
## the animal lies down straight away.
func slaap(id: String, kamer: String, slot: String) -> bool:
	var d: Dier = _dieren.get(id)
	var r := Rooms.get_kamer(kamer)
	if d == null or r == null or not r.slots.has(slot):
		return false
	var bed: Dictionary = r.slots[slot]
	if d.kamer == kamer or rust():
		_breek(d, false)
		d.slaap_doel = slot
		d.slaap_kamer = kamer
		d.kamer = kamer
		_in_bed(d)
		vuil()
		return true
	# the walk first, THEN the bed target: `reis`/`ga` supersede the running
	# order, and superseding is exactly what clears a bed target
	if d.kamer != kamer:
		reis(d.id, kamer, {"x": bed["sx"], "z": bed["sz"], "na": "wacht"})
	else:
		ga(d.id, bed["sx"], bed["sz"], "wacht")
	d.slaap_doel = slot
	d.slaap_kamer = kamer
	return true

## Lie on the mattress: the bed's own point, `hoogte = MATRAS`, pose `lig`, and
## `face = −1` for a rotated bed — mirroring is exactly a quarter turn here.
func _in_bed(d: Dier) -> void:
	var r := Rooms.get_kamer(d.slaap_kamer)
	if r == null or not r.slots.has(d.slaap_doel):
		return
	var bed: Dictionary = r.slots[d.slaap_doel]
	d.kamer = d.slaap_kamer
	_zet_plek(d, Vector2(bed["x"], bed["z"]))
	d.hoogte = MATRAS
	d.lift = -MATRAS * Art.HG
	d.face = -1 if (bed.get("draai", false) or bed.get("model", "") == "bedz") else 1
	d.staat = "slaap"
	d.pose = "lig"
	d.punten = []
	d.route = []
	d.v = 0.0
	_model_bij(d)

## Is this guest asleep in a bed?  The 💤 hang on this.
func slaapt(id: String) -> bool:
	var d: Dier = _dieren.get(id)
	return d != null and d.staat == "slaap"

## Walk to the eating place and eat (world.md §2.8).
func feed(ids: Array) -> void:
	var i := 0
	for id in ids:
		var d: Dier = _dieren.get(id)
		if d == null:
			continue
		var r := Rooms.get_kamer(d.kamer)
		var bak := _bak_van(r)
		if bak.is_empty():
			i += 1
			continue
		var zij := 7.0 if i % 2 == 0 else -7.0
		ga(id, bak["x"] - 13.0, bak["z"] + zij, "eet")
		i += 1

func _bak_van(r: Rooms.Kamer) -> Dictionary:
	if r == null:
		return {}
	for sid in r.slots:
		if r.slots[sid]["soort"] == "bak":
			var kopie: Dictionary = r.slots[sid].duplicate()
			kopie["slot"] = sid
			return kopie
	return {}

## Eat where you stand — the trolley delivers, nobody has to walk (games-a §7).
func feest(ids: Array) -> void:
	for id in ids:
		var d: Dier = _dieren.get(id)
		if d == null:
			continue
		_breek(d, false)
		d.staat = "eet"
		d.tikken = 0
		d.punten = []
	vuil()

## Walk to a free place and be happy there.
func solo(id: String, _act: String = "") -> bool:
	var d: Dier = _dieren.get(id)
	if d == null:
		return false
	var p := _vrije_plek(d)
	return ga(id, p.x, p.y, "blij")

## Stay where you stand and take end state `na` (§2.5), in this frame: the
## order a game gives the animal of its turn once he is at his place
## (`ctx.wacht_op`) — "wacht" keeps him there instead of wandering off.
func blijf(id: String, na: String = "wacht") -> bool:
	var d: Dier = _dieren.get(id)
	if d == null:
		return false
	_breek(d, false)
	d.na = na
	_eind_staat(d)
	vuil()
	return true

## 'sad' | 'happy' | 'idle' — sulk at the sulking place, bounce, or resume.
func mood(id: String, stemming: String) -> bool:
	var d: Dier = _dieren.get(id)
	if d == null:
		return false
	match stemming:
		"sad", "droopy":
			var r := Rooms.get_kamer(d.kamer)
			var bak := _bak_van(r)
			if bak.is_empty():
				_breek(d, false)
				d.staat = "sip"
				d.pose = "sip"
				d.tikken = 60
				vuil()
				return true
			return ga(id, bak["x"] - 5.0, bak["z"] + 13.0, "sip")
		"happy", "bouncy", "blij":
			_breek(d, false)
			d.staat = "blij"
			d.tikken = 46 + int(d.rnd.volgende() * 34.0)
			d.wandel_kans = minf(0.62, d.wandel_kans + 0.06)
			vuil()
			return true
		_:
			_breek(d, false)
			d.staat = "stil"
			d.tikken = 12
			d.pose = "rust"
			vuil()
			return true

## One pose for `duur` ticks (15 ticks = 1 s), then back to idle.
func pose(id: String, naam: String, duur: int = 0) -> bool:
	var d: Dier = _dieren.get(id)
	if d == null:
		return false
	_breek(d, false)
	d.punten = []
	d.staat = "pose"
	d.pose = naam
	d.tikken = maxi(1, duur)
	d.v = 0.0
	_model_bij(d)
	vuil()
	return true

## Any new order supersedes the running one (world.md §2.5).
func _breek(d: Dier, gehaald: bool) -> void:
	if d.opdracht != null:
		var op: Opdracht = d.opdracht
		d.opdracht = null
		op.rond(gehaald)
	d.punten = []
	d.per_stap = Callable()
	d.reis_doel = ""
	if d.staat == "slaap":
		# out of bed: the next order is never "lie down again", and the bed
		# target must go with it or he would climb back in on arrival
		d.hoogte = 0.0
		d.lift = 0.0
	if d.staat == "komt":
		# an arrival cut short in mid-hop comes down to the floor at once
		d.hoogte = 0.0
		d.lift = 0.0
		d.bob = 0.0
		d.zij = 0.0
	d.komt = []
	d.komt_doel = Vector2.INF
	d.slaap_doel = ""
	d.slaap_kamer = ""
	d.bed_sprong = false
	d.spring_extra = 0.0

func _zet_plek(d: Dier, p: Vector2) -> void:
	d.x = p.x
	d.z = p.y
	d.px = p.x
	d.pz = p.y

# --------------------------------------------------- de wereld-API van §5.3
##
## `ctx.wereld` IS this autoload (architecture.md §6.3), so every name world.md
## §5.3 promises a minigame has to answer here.  The ones below are thin
## passthroughs to `Rooms`, which is where that data lives; a game never has to
## know that there are two autoloads.

## `kamers()` — the room ids in bar order.
func kamers() -> Array[String]:
	return Rooms.lijst()

## `kamer(id)` — one room, or null.
func kamer(id: String) -> Rooms.Kamer:
	return Rooms.get_kamer(id)

## `pad(a, b)` — the door path, start room included.
func pad(van: String, naar: String) -> Array[String]:
	return Rooms.pad(van, naar)

## `slots(kamer, soort)` — every slot of a room (empty room = all of them).
func slots(kamer_id: String = "", soort: String = "") -> Array:
	return Rooms.slots(kamer_id, soort)

## `slot(kamer, slotId)` — one slot, or {}.
func slot(kamer_id: String, slot_id: String) -> Dictionary:
	return Rooms.slot(kamer_id, slot_id)

## `actief()` — the room in view.
func actief() -> String:
	return _kamer_nu

## `verwijderMeubel(id)` — take a bought piece away again.
func verwijder_meubel(id: String) -> bool:
	return Rooms.meubel_weg(id)

## `kamerMeubels(kamer?)` — the bought pieces, as save records.
func kamer_meubels(kamer_id: String = "") -> Array:
	return Rooms.meubels(kamer_id)

## `meubeltypen()` — the six types a child can buy, with their soort and model.
func meubeltypen() -> Dictionary:
	return Rooms.MEUBEL.duplicate(true)

## `setFood(id, aantal, per)` — how full THIS guest's bowl looks on its card;
## `Art.niveau` maps the scoops onto the four levels (art-sound-rules.md §7).
func set_food(id: String, aantal: int, per: int) -> int:
	var d: Dier = _dieren.get(id)
	var niv := Art.niveau(aantal, per)
	if d != null:
		d.voer = niv
		vuil()
	return niv

## `setBak(kamer, slot, 0..4)` and `setMood(id, stemming)` under the spelling
## world.md §5.3 uses; `zet_bak` and `mood` are the same calls.
func set_bak(kamer_id: String, slot_id: String, niveau: int) -> int:
	return zet_bak(kamer_id, slot_id, niveau)

func set_mood(id: String, stemming: String) -> bool:
	return mood(id, stemming)

## `dingZet(sleutel, o)` — the spelling of §5.3 for `zet_ding`.
func ding_zet(sleutel: String, o: Dictionary) -> Dictionary:
	return zet_ding(sleutel, o)

## `decorWisAlles()` — every loose piece of every game, gone.
func decor_wis_alles() -> void:
	_decor.clear()
	_decor_versie += 1
	vuil()

## `accessoires(id)` — what this guest is wearing, in the fixed order.
func accessoires(id: String) -> Array:
	var d: Dier = _dieren.get(id)
	return [] if d == null else d.acc.duplicate()

## `accessoireWeg(id, naam)` — take one off.
func accessoire_weg(id: String, naam: String) -> Array:
	return accessoire(id, naam, false)

# ------------------------------------------------------- doorgeefluik hotel

## `ctx.wereld.behoefteKlaar(gastId, welke)` — the hotel resolves the wish.
func behoefte_klaar(gast_id: String, welke: String) -> bool:
	return Hotel.wens_af(gast_id, welke)

## `wereld.voegBed(kamer, {x, z})` — a bed added is a guest added (HOTEL.md §2).
func voeg_bed(kamer_id: String, o: Dictionary = {}) -> Dictionary:
	return Rooms.meubel_zet(kamer_id, "bed", o.get("x", NAN), o.get("z", NAN),
		int(o.get("rot", 0)))

## `wereld.plaatsMeubel(kamer, type, x, z, rot)`.
func plaats_meubel(kamer_id: String, type: String, x: float = NAN, z: float = NAN,
		rot: int = 0) -> Dictionary:
	return Rooms.meubel_zet(kamer_id, type, x, z, rot)

## Zet de bedden van de kamer in het zicht of weg, samen met de gasten die
## erin slapen (scenes/kamer.gd `verberg_bedden`). Bedoeld voor `bedden`: bij
## de vraag "hoeveel bedden heb je nodig?" moet de kamer leeg zijn. Geen
## kamer in beeld, of een scene zonder deze methode: doet niets.
func bedden_verberg(aan: bool) -> void:
	if _kamerscene != null and _kamerscene.has_method("verberg_bedden"):
		_kamerscene.verberg_bedden(aan)

## `wereld.getalTag(obj, n, o)` — a bare number ON an object.
func getal_tag(obj: Variant, n: Variant, o: Dictionary = {}) -> String:
	return Ui.getal_tag(obj, n, o)

func vloer() -> String:
	var r := Rooms.get_kamer(_kamer_nu)
	return "" if r == null else r.vloer

# ------------------------------------------------------------------- de tik

func tikken() -> int:
	return _tikken

func deeltjes() -> Array:
	return _deeltjes

func _tik() -> void:
	# the tick counter belongs to the tick, not to the frame clock: a test
	# drives `_tik()` by hand and every phase must move with it
	_tikken += 1
	for id in _volgorde:
		var d: Dier = _dieren[id]
		d.px = d.x
		d.pz = d.z
		if d.kamer != _kamer_nu:
			_grof_tik(d)
		else:
			_fijn_tik(d)
	_bakjes_kauwen()
	_deeltjes_tik()

## world.md §2.9 — off screen: keep the route, one step per tick, straight to
## the target.  No poses, no particles, no drawing.
func _grof_tik(d: Dier) -> void:
	if d.staat == "komt":
		# nobody sees the front door: he is at the desk already
		_komt_af(d)
		return
	if d.staat == "eet":
		# world.md §2.9: off screen the bowl is emptied at once, not chewed
		var bak := _bak_van(Rooms.get_kamer(d.kamer))
		if not bak.is_empty():
			zet_bak(d.kamer, bak["slot"], 0)
		d.staat = "blij"
		d.tikken = 30
	if d.punten.is_empty():
		if not d.route.is_empty():
			_stap_door_deur(d)
			if d.route.is_empty():
				_klaar_met_route(d)
		return
	var r := Rooms.get_kamer(d.kamer)
	var stap := d.vmax * (1.0 if r == null else r.loop)
	var doel: Vector2 = d.punten[0]
	var weg := doel - Vector2(d.x, d.z)
	if weg.length() <= stap:
		d.x = doel.x
		d.z = doel.y
		d.punten.pop_front()
		if d.punten.is_empty():
			_aangekomen(d)
	else:
		var stapv := weg.normalized() * stap
		d.x += stapv.x
		d.z += stapv.y

func _fijn_tik(d: Dier) -> void:
	match d.staat:
		"loop":
			_rijd(d)
		"zwem":
			if d.punten.is_empty():
				_drijf(d)
			else:
				_rijd(d)
		"spring":
			_spring(d)
		"komt":
			_komt_tik(d)
		"slaap":
			d.bob = sin(_tikken * 0.045) * 0.6
			d.pose = "lig"
		"eet":
			_eet(d)
		"blij":
			_blij(d)
		"sip":
			d.pose = "zitsip" if d.tikken % 40 < 20 else "sip"
			d.bob = 0.0
			_aftellen(d)
		"zit":
			d.pose = "zit"
			_aftellen(d)
		"kijk":
			d.pose = "kijk"
			_aftellen(d)
		"snuif":
			d.pose = "snuif"
			_aftellen(d)
		"pose":
			_aftellen(d)
		_:
			_ademen(d)
			_aftellen(d)
	_model_bij(d)
	vuil()

func _aftellen(d: Dier) -> void:
	d.tikken -= 1
	if d.tikken <= 0:
		_kies(d)

## `stil`/`wacht` just breathe, with a random blink.
func _ademen(d: Dier) -> void:
	d.bob = sin(_tikken * 0.085 + d.fase) * 0.8 - 0.4
	d.zij = 0.0
	if d.pose != "tril" and d.pose != "kijk":
		d.pose = "rust"
	if d.rnd.volgende() < 0.035:
		d.pose = "tril" if d.rnd.volgende() < 0.5 else "kijk"
		d.tikken = maxi(d.tikken, 1 + int(d.rnd.volgende() * 4.0))

## `blij` — 46..79 ticks in one of three styles, with two sparkles now and then.
func _blij(d: Dier) -> void:
	d.pose = "blijA" if (_tikken / 5) % 2 == 0 else "blijB"
	match d.blij_stijl:
		"draai":
			if _tikken % 3 == 0:
				d.face = -d.face
		"hup":
			d.bob = -7.5 * absf(sin(_tikken * 0.32))
		_:
			d.zij = sin(_tikken * 0.4) * 2.6
	if not rust() and _tikken % (9 + d.nr * 2) == 0:
		_pluis(d, ArtEffect.STER_N, ArtEffect.STER_KL[_tikken % 2], true)
	_aftellen(d)

## `eet` — the chew.  The animal only moves its jaw here; the bowl itself is
## chewed once per think tick by `_bakjes_kauwen()`, not once per animal
## (V5, PLAN.md).  With the old `_tikken % 5` gate every eating guest took a
## level off on the very same tick, so four of them emptied a full bowl in a
## third of a second — while the 😋 bubble of 2,6 s was still up and the bowl
## button still said "Vol".  A bowl now loses one level per `KAUW_PER_NIVEAU`
## ticks however many animals stand at it, so four levels last ±6,4 s whether
## one guest eats or four.  Off screen nothing chews: `_grof_tik` still
## empties the bowl in one go (world.md §2.9).
func _eet(d: Dier) -> void:
	d.kauw += 1
	d.pose = "hap2" if (d.kauw % 5) < 2 else "hap1"
	d.bob = 0.0
	var bak := _bak_van(Rooms.get_kamer(d.kamer))
	if bak.is_empty() or bak_stand(d.kamer, str(bak["slot"])) <= 0:
		d.staat = "blij"
		d.tikken = 50 + int(d.rnd.volgende() * 36.0)
		return
	_kauwers["%s|%s" % [d.kamer, str(bak["slot"])]] = d

## The other half of the chew, run once per think tick after the animals.
## One bowl, one rate: the counter belongs to the bowl and only moves while
## somebody is eating from it, so the number of guests does not change how
## long the food lasts.  The last animal to report drops the crumbs.
func _bakjes_kauwen() -> void:
	for sleutel in _kauwers.keys():
		var n := int(_bak_kauw.get(sleutel, 0)) + 1
		_bak_kauw[sleutel] = n
		if n < KAUW_PER_NIVEAU:
			continue
		var delen: PackedStringArray = String(sleutel).split("|")
		var stand := bak_stand(delen[0], delen[1])
		if stand <= 0:
			continue
		zet_bak(delen[0], delen[1], stand - 1)
		if not rust():
			_pluis(_kauwers[sleutel] as Dier, ArtEffect.KRUIMEL_N, ArtEffect.KRUIMEL_KL, false)
	_kauwers.clear()

## Floating: he stays in the water, sways, paddles slowly and drops one splash
## every 30th tick (world.md §2.5).  He does NOT arrive again every tick — that
## would re-arm the order and reset the state forever.
func _drijf(d: Dier) -> void:
	d.hoogte = -ZWEM_DIEP
	d.lift = ZWEM_DIEP * Art.HG
	d.zij = sin(_tikken * 0.42 + d.fase) * 0.9
	d.bob = 0.0
	d.pose = "loopA" if (_tikken / 8) % 2 == 0 else "loopB"
	if not rust() and _tikken % DRIJF_PLONS == 0:
		_pluis(d, 1, ArtEffect.PLONS_KL[_tikken % 3], true)

## world.md §2.4 — accelerate, brake for the LAST point only, glide through the
## rest.  43 points along the pool cost the same time as one straight line.
func _rijd(d: Dier) -> void:
	if d.punten.is_empty():
		_aangekomen(d)
		return
	var r := Rooms.get_kamer(d.kamer)
	var loop := 1.0 if r == null else r.loop
	var vmax := d.vmax * loop * d.beweeg_tempo
	var acc := vmax / 5.5 * d.beweeg_tempo
	var rem := d.v * d.v / (2.0 * acc) + d.vmax * 0.4 / d.beweeg_tempo
	var rest := _rest_afstand(d)
	if rest <= rem:
		d.v -= acc
	else:
		d.v += acc
	d.v = clampf(d.v, 0.14 * vmax, vmax)
	var budget := d.v
	while budget > 0.0 and not d.punten.is_empty():
		var doel: Vector2 = d.punten[0]
		var weg := doel - Vector2(d.x, d.z)
		var af := weg.length()
		if af <= budget or af < 0.0001:
			d.x = doel.x
			d.z = doel.y
			budget -= af
			d.punten.pop_front()
			if d.per_stap.is_valid():
				d.per_stap.call(d.stap_nr, doel)
			d.stap_nr += 1
			d.gang += af / (d.stap_lengte * GANG_K)
			if d.punten.is_empty():
				_aangekomen(d)
				return
		else:
			var stapv := weg / af * budget
			d.x += stapv.x
			d.z += stapv.y
			d.face = 1 if (stapv.x - stapv.y) >= 0.0 else -1
			d.gang += budget / (d.stap_lengte * GANG_K)
			budget = 0.0
	_loop_beeld(d)

func _rest_afstand(d: Dier) -> float:
	var som := 0.0
	var vorig := Vector2(d.x, d.z)
	for p in d.punten:
		som += vorig.distance_to(p)
		vorig = p
	return som

func _loop_beeld(d: Dier) -> void:
	if d.staat == "zwem":
		d.pose = "loopA" if int(d.gang * 2.0) % 2 == 0 else "loopB"
		d.hoogte = -ZWEM_DIEP
		d.lift = ZWEM_DIEP * Art.HG
		d.zij = sin(_tikken * 0.42 + d.fase) * 0.9
		d.bob = 0.0
		if not rust() and _tikken % 5 == 0:
			_pluis(d, 1, ArtEffect.PLONS_KL[_tikken % 3], true)
		return
	d.pose = "loopA" if int(d.gang) % 2 == 0 else "loopB"
	d.hoogte = 0.0                  # whoever walks, walks on the floor
	d.lift = 0.0
	d.bob = -absf(sin(d.gang * PI)) * d.bob_hoog
	d.zij = sin(d.gang * PI) * 1.6 if d.kind == "gans" else 0.0

## Jumping deliberately does not glide: it stops and squashes on every stone.
func _spring_start(d: Dier) -> void:
	d.spring_van = Vector2(d.x, d.z)
	d.spring_naar = d.punten[0]
	d.spring_t = 0
	d.spring_h0 = d.hoogte
	d.spring_land = d.land_hoogte if is_finite(d.land_hoogte) else d.hoogte

func _spring(d: Dier) -> void:
	if d.punten.is_empty():
		_aangekomen(d)
		return
	var lucht := maxi(2, JsGetal.rond(float(SPRING_TIKKEN) / d.beweeg_tempo))
	d.spring_t += 1
	if d.spring_t <= lucht:
		var f := float(d.spring_t) / float(lucht)
		var plek := d.spring_van.lerp(d.spring_naar, f)
		d.x = plek.x
		d.z = plek.y
		var top: float = SPRING_HOOG.get(d.kind, 5.0) + d.spring_extra
		d.hoogte = lerpf(d.spring_h0, d.spring_land, f) + top * 4.0 * f * (1.0 - f)
		d.lift = -d.hoogte * Art.HG
		d.pose = "loopA" if f < 0.25 else ("blijA" if f < 0.75 else "loopB")
		var weg := d.spring_naar - d.spring_van
		d.face = 1 if (weg.x - weg.y) >= 0.0 else -1
		return
	# a landing on solid ground squats; a dive into water (a negative landing)
	# never touches the surface, so it skips the squat
	if d.spring_land >= 0.0 and d.spring_t <= lucht + SQUASH:
		d.hoogte = d.spring_land
		d.lift = -d.hoogte * Art.HG
		d.pose = "zit"
		return
	d.x = d.spring_naar.x
	d.z = d.spring_naar.y
	d.hoogte = d.spring_land
	d.lift = -d.hoogte * Art.HG
	d.punten.pop_front()
	if d.per_stap.is_valid():
		d.per_stap.call(d.stap_nr, d.spring_naar)
	d.stap_nr += 1
	if d.punten.is_empty():
		_aangekomen(d)
		return
	_spring_start(d)

## Arrived at the last point of this leg.
func _aangekomen(d: Dier) -> void:
	d.v = 0.0
	if d.bed_sprong:
		# landed on the mattress: lie down right there
		d.bed_sprong = false
		d.spring_extra = 0.0
		d.beweeg_pose = ""
		d.land_hoogte = NAN
		_in_bed(d)
		return
	# a dive lands in the water and stays there; a hop lands where it started
	if d.spring_land < 0.0:
		d.hoogte = d.spring_land
	else:
		d.hoogte = 0.0 if d.beweeg_pose != "zwem" else -ZWEM_DIEP
	d.lift = -d.hoogte * Art.HG
	if not d.route.is_empty():
		_stap_door_deur(d)
		if d.route.is_empty():
			_klaar_met_route(d)
		return
	if d.opdracht != null:
		var op: Opdracht = d.opdracht
		d.opdracht = null
		_eind_staat(d)
		op.rond(true)
		return
	if d.slaap_doel != "" and d.kamer == d.slaap_kamer:
		_spring_in_bed(d)
		return
	_eind_staat(d)

## Walked up to the side of the bed: hop from the floor onto the mattress, then
## lie down (owner, 2026-09-23).  The jump is the hinkel's arc (`_spring`),
## slower and higher, landing at MATRAS on the bed's own point; `_aangekomen`
## sees `bed_sprong` and puts the guest to bed where it landed.  With reduced
## motion there is no jump — the guest lies down at once, as before.
func _spring_in_bed(d: Dier) -> void:
	var r := Rooms.get_kamer(d.slaap_kamer)
	if r == null or not r.slots.has(d.slaap_doel) or rust():
		_in_bed(d)
		return
	var bed: Dictionary = r.slots[d.slaap_doel]
	d.punten = [Vector2(bed["x"], bed["z"])]
	d.stap_nr = 0
	d.per_stap = Callable()
	d.beweeg_pose = "spring"
	d.beweeg_tempo = BED_SPRONG_TEMPO
	d.land_hoogte = MATRAS
	d.spring_extra = BED_SPRONG_EXTRA
	d.bed_sprong = true
	d.staat = "spring"
	_spring_start(d)
	Snd.hup()
	vuil()

## `na` on arrival (world.md §2.5): a known state, or `stil` for a while.
func _eind_staat(d: Dier) -> void:
	var na := d.na if d.na != "" else d.eind_pose
	d.na = ""
	match na:
		"eet":
			d.staat = "eet"
			d.tikken = 0
		"sip":
			d.staat = "sip"
			d.pose = "sip"
			d.tikken = 90
		"wacht":
			d.staat = "wacht"
			d.pose = "rust"
			d.tikken = 240
		"snuif":
			d.staat = "snuif"
			d.pose = "snuif"
			d.tikken = 24
		"blij":
			d.staat = "blij"
			d.tikken = 46 + int(d.rnd.volgende() * 34.0)
		"slaap":
			if d.slaap_doel != "":
				_in_bed(d)
			else:
				d.staat = "stil"
				d.tikken = 30
		"zwem":
			d.staat = "zwem"
			d.hoogte = -ZWEM_DIEP
			d.lift = ZWEM_DIEP * Art.HG
			d.tikken = 600
		"deur":
			d.staat = "stil"
			d.pose = "rust"
			d.tikken = 20
		_:
			d.staat = "stil"
			d.pose = "rust"
			d.tikken = JsGetal.rond((10.0 + d.rnd.volgende() * 40.0) * d.rustig)

# ---------------------------------------------------------------- binnenkomen
##
## A guest who arrives at the hotel comes in from OUTSIDE, through the front
## door of the receptie (`Rooms.ingang`), and not out of the corridor (owner,
## 2026-09-23: "die komen momenteel vanuit de gang binnen ipv ingang.  Doe ook
## een leuke animatie wanneer ze binnenkomen dat per dier anders is").  The
## door opens, he appears on its threshold and plays his own little entrance
## on the way to the desk — the beats are `WereldBinnenkomst`'s, this is the
## player.  It runs on the think tick like every walk, so it is deterministic,
## and any other order (`ga`, `reis`, `slaap`, `pose`, `zet`, ...) takes the
## guest over at once, exactly as it would take over a walk.

const DEUR_OPEN_MAX := 45       ## the front door falls shut after 3 s at the latest

var _ingang_dicht_op: Dictionary = {}   ## kamer -> the tick its front door falls shut

## `World.kom_binnen(id, x, z)` — the guest comes in through the front door of
## `kamer_id` and ends on (x, z) waiting (`wacht`), as `ga(id, x, z, "wacht")`
## would leave him.  A room without a front door, and reduced motion: he simply
## stands there.  Not awaitable: nothing waits for him (the check-in card hangs
## at the desk while he is still on his way).
func kom_binnen(id: String, x: float, z: float, kamer_id := "receptie") -> bool:
	var d: Dier = _dieren.get(id)
	if d == null or not Rooms.bestaat(kamer_id):
		return false
	var doel := Vector2(x, z)
	var ing := Rooms.ingang(kamer_id)
	if ing.is_empty() or rust():
		zet(id, kamer_id, x, z)
		d.na = "wacht"
		_eind_staat(d)
		return true
	zet(id, kamer_id, float(ing["dx"]), float(ing["dz"]))
	d.komt = WereldBinnenkomst.plan(d.kind, Rooms.get_kamer(kamer_id), ing, doel)
	d.komt_t = 0
	d.komt_van = d.plek()
	d.komt_doel = doel
	# he faces into the room: away from the wall the door is in
	d.face = -1 if str(ing.get("wand", "z")) == "z" else 1
	d.staat = "komt"
	# the door swings open without a sound — the desk bell has just rung; it
	# falls shut with the door's own sound once he is in (the `deur` beat)
	_ingang_dicht_op[kamer_id] = _tikken + DEUR_OPEN_MAX
	vuil()
	return true

## Is this guest still on his way in through the front door?
func komt_binnen(id: String) -> bool:
	var d: Dier = _dieren.get(id)
	return d != null and d.staat == "komt"

## Does the front door of this room stand open right now?  `scenes/kamer.gd`
## draws it open or shut from this.
func ingang_open(kamer_id: String = "") -> bool:
	var k := kamer_id if kamer_id != "" else _kamer_nu
	return _tikken < int(_ingang_dicht_op.get(k, -1))

## One tick of the arrival: the beats that happen at once (a sound, particles,
## the door), then one tick of the beat that takes time.
func _komt_tik(d: Dier) -> void:
	if rust():
		_komt_af(d)
		return
	var gespeeld := false
	while not d.komt.is_empty():
		var slag: Dictionary = d.komt[0]
		var soort := str(slag.get("soort", ""))
		if soort == "geluid" or soort == "pluis" or soort == "deur":
			_komt_meteen(d, slag)
			d.komt.pop_front()
			continue
		if gespeeld:
			break
		gespeeld = true
		d.komt_t += 1
		if _komt_speel(d, slag):
			d.komt.pop_front()
			d.komt_t = 0
			d.komt_van = Vector2(d.x, d.z)
	if d.komt.is_empty():
		_komt_af(d)

func _komt_meteen(d: Dier, slag: Dictionary) -> void:
	match str(slag["soort"]):
		"geluid":
			var naam := str(slag.get("naam", ""))
			if naam == "plop":
				Snd.plop(int(slag.get("hand", 0)))
			elif naam != "" and Snd.has_method(naam):
				Snd.call(naam)
		"pluis":
			var kl: Color = slag.get("kl", ArtEffect.STER_KL[0])
			_pluis(d, int(slag.get("n", 2)), kl, bool(slag.get("omhoog", true)))
		"deur":
			if ingang_open(d.kamer):
				Snd.deur()
			_ingang_dicht_op[d.kamer] = _tikken

## One tick of a beat that takes time (`stil`, `loop`, `hup`); true once it is
## done.  `komt_t` counts the ticks of this beat from 1.
func _komt_speel(d: Dier, slag: Dictionary) -> bool:
	var t := d.komt_t
	match str(slag["soort"]):
		"stil":
			var n := maxi(1, int(slag.get("n", 1)))
			var per := maxi(1, int(slag.get("per", n)))
			var poses: Array = slag.get("poses", ["rust"])
			var fase := (t - 1) % per
			if fase == 0 and t > 1 and bool(slag.get("draai", false)):
				d.face = -d.face
			d.pose = str(poses[((t - 1) / per) % poses.size()])
			d.bob = -sin(PI * float(fase) / float(per)) * float(slag.get("hup", 0.0))
			d.zij = sin(float(t) * 0.9) * float(slag.get("zij", 0.0))
			d.hoogte = 0.0
			d.lift = 0.0
			return t >= n
		"loop":
			var naar: Vector2 = slag["naar"]
			var weg := naar - Vector2(d.x, d.z)
			var af := weg.length()
			var v := float(slag.get("v", 2.0))
			if bool(slag.get("rem", false)):
				v *= clampf(af / (v * 4.0), 0.4, 1.0)
			var stap := minf(v, af)
			if af > 0.0001:
				d.x += weg.x / af * stap
				d.z += weg.y / af * stap
				d.face = 1 if (weg.x - weg.y) >= 0.0 else -1
			d.gang += stap / maxf(0.5, float(slag.get("stap", 3.0)))
			var poses: Array = slag.get("poses", ["loopA", "loopB"])
			d.pose = str(poses[int(d.gang) % poses.size()])
			d.bob = -absf(sin(d.gang * PI)) * float(slag.get("bob", d.bob_hoog))
			d.zij = sin(d.gang * PI) * float(slag.get("zij", 0.0))
			d.hoogte = 0.0
			d.lift = 0.0
			if af <= stap + 0.0001:
				d.x = naar.x
				d.z = naar.y
				return true
			return false
		"hup":
			var n := maxi(2, int(slag.get("n", SPRING_TIKKEN)))
			var land := maxi(0, int(slag.get("land", 1)))
			var naar: Vector2 = slag.get("naar", d.komt_van)
			d.bob = 0.0
			d.zij = 0.0
			if t <= n:
				var f := float(t) / float(n)
				var p := d.komt_van.lerp(naar, f)
				d.x = p.x
				d.z = p.y
				d.hoogte = float(slag.get("hoog", SPRING_HOOG.get(d.kind, 5.0))) * 4.0 * f * (1.0 - f)
				d.lift = -d.hoogte * Art.HG
				d.pose = "loopA" if f < 0.25 else ("blijA" if f < 0.75 else "loopB")
				var weg := naar - d.komt_van
				if weg.length() > 0.01:
					d.face = 1 if (weg.x - weg.y) >= 0.0 else -1
				if bool(slag.get("draai", false)) and (t == (n + 1) / 2 or t == n):
					d.face = -d.face       # a look round at the top, back on landing
				return t >= n and land == 0
			d.x = naar.x
			d.z = naar.y
			d.hoogte = 0.0
			d.lift = 0.0
			d.pose = "zit"                 # the squat of a landing, as `_spring` has it
			return t >= n + land
	return true

## The arrival is over — or cut short, off screen or by reduced motion: he
## stands on his spot and waits, and the front door is shut.
func _komt_af(d: Dier) -> void:
	if is_finite(d.komt_doel.x):
		_zet_plek(d, d.komt_doel)
	d.komt = []
	d.komt_t = 0
	d.komt_doel = Vector2.INF
	d.hoogte = 0.0
	d.lift = 0.0
	d.bob = 0.0
	d.zij = 0.0
	d.v = 0.0
	d.na = "wacht"
	_eind_staat(d)
	_ingang_dicht_op[d.kamer] = mini(int(_ingang_dicht_op.get(d.kamer, -1)), _tikken)
	_model_bij(d)
	vuil()

# ------------------------------------------------------------------- reizen

## Walk to the door of the next room on the route.
func _volgende_deur(d: Dier) -> void:
	if d.route.is_empty():
		return
	var naar: String = d.route[0]
	var dp := Rooms.deur(d.kamer, naar)
	if dp.is_empty():
		d.route = []
		_klaar_met_route(d)
		return
	d.punten = _droog_pad(d, Vector2(dp["ix"], dp["iz"]))
	d.been_van = Vector2(d.x, d.z)
	d.staat = "loop"
	d.na = "deur"

## Step through the door: the animal appears just inside the next room.
func _stap_door_deur(d: Dier) -> void:
	if d.route.is_empty():
		return
	var vorige := d.kamer
	var naar: String = d.route.pop_front()
	d.kamer = naar
	d.reis_klaar += 1
	if naar == d.reis_doel:
		d.reis_doel = ""            # in view: the bubble may go
	var terug := Rooms.deur(naar, vorige)
	if not terug.is_empty():
		_zet_plek(d, Vector2(terug["ix"], terug["iz"]))
	if not d.route.is_empty():
		_volgende_deur(d)

## The route is walked: go to the point that was asked for, or stop here.
func _klaar_met_route(d: Dier) -> void:
	if d.slaap_doel != "" and d.kamer == d.slaap_kamer and is_inf(d.route_doel.x):
		_in_bed(d)
		return
	if is_finite(d.route_doel.x):
		# the last leg inside the target room; NOT through `ga()`, because that
		# would supersede the order that started this journey
		var doel := d.route_doel
		d.route_doel = Vector2.INF
		d.punten = _droog_pad(d, doel)
		d.staat = "loop"
		d.na = d.route_na
		d.v = maxf(d.v, 0.14 * d.vmax)
		return
	d.na = d.route_na
	_eind_staat(d)

# ------------------------------------------------------------------- idle

## world.md §2.6 — when a `stil`/`zit`/`kijk`/`snuif` state runs out.
func _kies(d: Dier) -> void:
	if not d.route.is_empty():
		_volgende_deur(d)
		return
	if d.staat == "slaap" or d.staat == "zwem":
		d.tikken = 120
		return
	var w := d.wandel_kans
	var rol := d.rnd.volgende()
	if rol < w or rol < w + 0.17:
		var p := _vrije_plek(d)
		d.punten = _droog_pad(d, p)
		d.staat = "loop"
		d.na = "" if rol < w else "snuif"
		d.v = maxf(d.v, 0.14 * d.vmax)
		return
	if rol < w + 0.32:
		d.staat = "zit"
		d.pose = "zit"
		d.tikken = 24 + int(d.rnd.volgende() * 50.0)
		return
	if rol < w + 0.44:
		d.staat = "kijk"
		d.pose = "kijk"
		d.tikken = 6 + int(d.rnd.volgende() * 12.0)
		return
	d.staat = "stil"
	d.pose = "rust"
	d.tikken = JsGetal.rond((12.0 + d.rnd.volgende() * 46.0) * d.rustig)

## A free wander place: not on top of another animal's target, not right under
## the animal's own nose, and the farthest one of the candidates it looked at.
func _vrije_plek(d: Dier) -> Vector2:
	var r := Rooms.get_kamer(d.kamer)
	if r == null or r.plekken.is_empty():
		return Vector2(d.x, d.z)
	var n: int = r.plekken.size()
	var start := int(d.rnd.volgende() * n)
	var beste := Vector2(r.plekken[start][0], r.plekken[start][1])
	var beste_af := -1.0
	for i in n:
		var p: Array = r.plekken[(start + i) % n]
		var kand := Vector2(p[0], p[1])
		var bezet := false
		for ander in _dieren.values():
			if ander == d or ander.kamer != d.kamer:
				continue
			var doel: Vector2 = ander.punten[ander.punten.size() - 1] if not ander.punten.is_empty() \
				else Vector2(ander.x, ander.z)
			if _iso_afstand(kand, doel) < 66.0:
				bezet = true
				break
		if bezet:
			continue
		var eigen := _iso_afstand(kand, Vector2(d.x, d.z))
		if eigen < 40.0:
			continue
		if eigen > beste_af:
			beste_af = eigen
			beste = kand
		if d.rnd.volgende() < 0.45:
			break
	return beste

## Distance as it looks on screen, in voxel-px — the isometry squashes z.
func _iso_afstand(a: Vector2, b: Vector2) -> float:
	var dx := ((a.x - a.y) - (b.x - b.y)) * Art.S
	var dy := ((a.x + a.y) - (b.x + b.y)) * (Art.S / 2.0)
	return sqrt(dx * dx + dy * dy)

# --------------------------------------------------------------- deeltjes

## Particles are `ArtEffect`'s (art-sound-rules.md §11.2): it owns the count,
## the spawn jitter, the gravity, the life and the colours, and it steps them.
## The world only says where and adds the room the particle belongs to, in
## voxel-px around the room origin so a scale change moves it along.
func _pluis(d: Dier, n: int, kl: Color, omhoog: bool) -> void:
	if rust():
		return
	var basis := Vector2((d.x - d.z) * Art.S, (d.x + d.z) * (Art.S / 2.0))
	basis.y -= 14.0 if omhoog else 4.0
	for q in ArtEffect.pluis(n, basis.x, basis.y, kl, omhoog, _rnd):
		q["kamer"] = d.kamer
		_deeltjes.append(q)

## Particles at a floor point of a room, for the games (review plan pillar 4):
## crumbs fall (`omhoog` false), sparkles and soap bubbles rise.  `hoog` lifts
## the source in voxels.  Nothing in reduced motion.
func spetter(kamer: String, x: float, z: float, n: int, kl: Color, omhoog := true, hoog := 0.0) -> void:
	if rust() or not Rooms.bestaat(kamer):
		return
	var basis := Vector2((x - z) * Art.S, (x + z) * (Art.S / 2.0) - hoog * Art.HG)
	basis.y -= 14.0 if omhoog else 4.0
	for q in ArtEffect.pluis(n, basis.x, basis.y, kl, omhoog, _rnd):
		q["kamer"] = kamer
		_deeltjes.append(q)
	vuil()

func _deeltjes_tik() -> void:
	ArtEffect.pluis_stap(_deeltjes)
