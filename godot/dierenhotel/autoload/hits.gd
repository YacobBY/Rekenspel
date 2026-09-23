extends Node
## Hits — the button layer over the world.  Autoload #3.
##
## Replaces `demos/dierenhotel/hits.js`.  The HTML version measured every DOM
## button and then pushed them apart in four evasion rounds; this port places
## them STRUCTURALLY, in one deterministic pass, on a band grid (architecture.md
## §4.3).  A button anchored `boven` snaps its bottom edge to the bottom of the
## lowest band that still ends GAT px above the object -> 0 % coverage by
## construction, not by iteration.
##
## Controls live in `Ui.knoplaag`, a Control that exactly covers the world
## frame, so 1 unit = 1 css px and every hotspot is a real focusable Button.

const MAX_PER_KAMER := 16   ## world.md §5.4 step 3
const GAT := 4              ## css-px between a button and its object
const RIJ := 52             ## band height  = 48 px tap target + 4 px air
const KOL := 56             ## column width = the hits.js fallback button width
const RAND := 6             ## air to the frame edge
const TAG_IN := 0.1         ## a number tag may cover a tenth of its object
const GROOT := 3.0          ## `op: "aan"`: an object this many button areas big may carry the button
const KRAP := 2             ## the hard frame edge: nothing goes past it
const KLEEF := 5            ## css-px between a card and its choice strip

enum Laag {VAST = 0, SPEL = 1, HOTEL = 2, WENS = 3}

signal hotspot_getikt(id: String)

var _spots: Dictionary = {}        ## id -> Spot
var _volgorde: Array[String] = []  ## insertion order
var _voorrang: String = ""         ## the game that picks its places first
var _bezet: Dictionary = {}        ## "rij|kol" -> true, rebuilt every placement
var _geplaatst: Array[Rect2] = []  ## the rectangles already handed out this pass
var _vakken: Array[Rect2] = []     ## object boxes in view; a button avoids all of them
var _mijd_balie_nu := false        ## while placing a hotel element: the desk is a box too
var _kaart_vrij: Array[Rect2] = [] ## boxes a fixed card may not cover either (the desk)
var _laatste: Dictionary = {}   ## id -> {rect, vlak, dekking, op, laag, prio, krap, gestapeld}
## The maths bar of PLAN.md §3.1 as a wall.  The paper is walled off before
## anything chooses a place, so no band, no button and no loose card may end up
## inside it.  It is deliberately NOT in `_geplaatst`: the card and the strip
## that are docked in the bar are placed BY the bar and pass straight through
## the collision check, and their own rectangles must not make the paper look
## occupied to themselves.
var _balk_muur: Array[Rect2] = []

class Spot extends RefCounted:
	var id: String
	var kamer: String
	var x: float
	var z: float
	var y: float
	var vlak: Rect2 = Rect2()      ## the object's own screen rect, if the caller knows it
	var vlak_nu: Rect2 = Rect2()   ## and the one this pass really used
	var obj: String = ""           ## the object it hangs on, when it has a name
	var _voorwerp: Dictionary = {} ## the thing that was found for it, cached
	var _voorwerp_sleutel := ""
	var maat: Vector2 = Vector2.ZERO   ## explicit minimum size (0 = ask the Control)
	var kleef_aan: String = ""     ## glue my top edge under the rect of this id
	var kind: String = "btn"       ## btn | drop | tag | naam | ...
	var geen_vlak := false         ## sits ON its object on purpose (a dial tag): no lift-off
	var op: String = "auto"        ## auto | boven | onder | midden | rand
	var prio: int = 5
	var vast := false
	var d: float = NAN             ## depth override
	var klas: String = ""
	var door: String = ""          ## owner (game id, "hotel", "registry")
	var volg: Callable             ## optional per-frame position provider
	var aan: Callable              ## tap handler
	var on_weg: Callable
	var knoop: Control
	var vangvlak: UiVangvlak = null   ## union of button and object, for a drop
	var drop: String = ""             ## the name a dragged item must carry
	var data: Dictionary = {}
	var val: Callable                 ## the game's drop handler
	var geleend_door: String = ""     ## a game borrowed this hotel button
	var eigen_aan: Callable           ## and this is what it did before
	var laag := Laag.HOTEL
	var zichtbaar := true

# ------------------------------------------------------------------- API

## `Hits.maak(o)`.  Returns the id.  Every key of world.md §5.4 is accepted.
func maak(o: Dictionary) -> String:
	if Ui.knoplaag == null:
		push_error("Hits.maak before Ui.registreer_lagen()")
		return ""
	var id: String = o.get("id", "spot%d" % _spots.size())
	if _spots.has(id):
		weg(id)
	var s := Spot.new()
	s.id = id
	s.kamer = o.get("kamer", World.kamer_nu())
	s.x = o.get("x", 0.0)
	s.z = o.get("z", 0.0)
	s.y = o.get("y", 0.0)
	s.kind = o.get("kind", "btn")
	s.geen_vlak = bool(o.get("geen_vlak", false))
	s.op = o.get("op", "auto")
	s.prio = o.get("prio", 5)
	s.vast = o.get("vast", false)
	s.d = o.get("d", NAN)
	s.klas = o.get("klas", "")
	s.door = o.get("door", "")
	s.volg = o.get("volg", Callable())
	s.aan = o.get("aan", Callable())
	s.on_weg = o.get("on_weg", Callable())
	s.vlak = o.get("vlak", Rect2())
	s.obj = o.get("obj", "")
	s.maat = o.get("maat", Vector2.ZERO)
	s.kleef_aan = o.get("kleef_aan", "")
	s.drop = o.get("drop", "")
	s.data = o.get("data", {})
	s.val = o.get("val", Callable())
	s.knoop = Ui.maak_knop(s.kind, o)
	# Always connected, also when the hotspot has no handler yet: that is what
	# lets a game BORROW one of the hotel's buttons (`ctx.hotspots.pak`).
	if s.knoop is BaseButton:
		(s.knoop as BaseButton).pressed.connect(func() -> void:
			Snd.tik()
			hotspot_getikt.emit(s.id)
			if s.aan.is_valid():
				Ui.roep(s.aan, [s]))
	Ui.laag_voor(s.kind).add_child(s.knoop)
	if s.drop != "" and Ui.vanglaag != null:
		s.vangvlak = UiVangvlak.new()
		s.vangvlak.name = "V" + id
		s.vangvlak.drop = s.drop
		s.vangvlak.data = s.data
		s.vangvlak.val = s.val
		Ui.vanglaag.add_child(s.vangvlak)
	_spots[id] = s
	_volgorde.append(id)
	return id

func weg(id: String) -> void:
	if not _spots.has(id):
		return
	var s: Spot = _spots[id]
	if s.on_weg.is_valid():
		s.on_weg.call(s)
	if is_instance_valid(s.knoop):
		s.knoop.queue_free()
	if s.vangvlak != null and is_instance_valid(s.vangvlak):
		s.vangvlak.queue_free()
	_spots.erase(id)
	_volgorde.erase(id)
	_laatste.erase(id)

func wis_eigenaar(door: String) -> void:
	geef_terug(door)
	for id in _volgorde.duplicate():
		var s: Spot = _spots[id]
		if s.door == door:
			weg(id)

# --------------------------------------------------------------- lenen

## `ctx.hotspots.pak(id, fn)` — a game borrows one of the hotel's own buttons
## while it runs (world.md §5.3).  The button keeps its place and its picture;
## only what it does changes, and `Games.stop()` gives it back.
func leen(id: String, door: String, fn: Callable) -> bool:
	var s: Spot = _spots.get(id)
	if s == null or s.geleend_door != "":
		return false
	s.geleend_door = door
	s.eigen_aan = s.aan
	s.aan = fn
	return true

func geef_terug(door: String) -> void:
	for id in _volgorde:
		var s: Spot = _spots[id]
		if s.geleend_door == door:
			s.aan = s.eigen_aan
			s.eigen_aan = Callable()
			s.geleend_door = ""

# --------------------------------------------------------------- slepen

## The catch area under a screen point, or `null`.
##
## Godot hands a drop to the Control under the finger and then walks its PARENT
## chain, stopping at the first MOUSE_FILTER_STOP ancestor.  The catch areas
## live in `Ui.vanglaag`, a SIBLING of `Ui.knoplaag`, so a drop that lands on a
## button (every hotspot IS a button) never reached them and was refused in
## silence — and a hotspot without an object rectangle has no uncovered catch
## area at all, because there its catch area IS the button.  Every Control in
## the hotspot layers therefore asks this and forwards the drop itself.
##
## The SMALLEST catch area under the point wins: it is the most specific target
## a child can be aiming at.  Asking `_can_drop_data` is part of the answer, not
## a side effect — that is what lights the target up while the finger hovers
## (`ui/vangvlak.gd` `drop-hot`), so everything else is cooled down again in the
## same pass; otherwise a hook keeps glowing after the finger has moved on.
func vang_onder(punt: Vector2, lading: Variant) -> UiVangvlak:
	var beste: UiVangvlak = null
	var kleinste := INF
	for id in _volgorde:
		var s: Spot = _spots[id]
		var v := s.vangvlak
		if v == null or not is_instance_valid(v) or not v.is_inside_tree():
			continue
		if not v.is_visible_in_tree() or not s.zichtbaar:
			continue
		if not v.get_global_rect().has_point(punt):
			continue
		if not v._can_drop_data(punt - v.get_global_position(), lading):
			continue
		var opp := v.size.x * v.size.y
		if opp < kleinste:
			kleinste = opp
			beste = v
	_koel_vangvlakken(beste)
	return beste

## Is a drag running right now?  When it is not, no target may glow.
func sleept() -> bool:
	if Ui.knoplaag == null or not is_instance_valid(Ui.knoplaag) or not Ui.knoplaag.is_inside_tree():
		return false
	var vp := Ui.knoplaag.get_viewport()
	return vp != null and vp.gui_is_dragging()

## Every catch area but one back to cold.  An empty Dictionary carries no
## `sleep`, so `_can_drop_data` says no and clears the glow — the catch area
## keeps its own state, this only asks it the question again.
func _koel_vangvlakken(behalve: UiVangvlak) -> void:
	for id in _volgorde:
		var s: Spot = _spots[id]
		var v := s.vangvlak
		if v == null or v == behalve or not is_instance_valid(v):
			continue
		v._can_drop_data(Vector2.ZERO, {})

## Rewire what a hotspot accepts, in ONE call: Spot, catch area and the place
## over the button stay in step.  Setting `s.val` and `s.vangvlak.val` by hand
## (voerkar) is two half-truths; `data` was forgotten there every time.
##
## An empty `data` keeps the data the hotspot already had — a borrowed bowl
## keeps knowing which room and slot it is.  An empty `drop` takes the catch
## area away again.  Returns false when there is no such hotspot.
func zet_drop(id: String, drop: String, val: Callable, data: Dictionary = {}) -> bool:
	var s: Spot = _spots.get(id)
	if s == null:
		return false
	s.drop = drop
	s.val = val
	if not data.is_empty():
		s.data = data
	if drop.is_empty():
		if s.vangvlak != null and is_instance_valid(s.vangvlak):
			s.vangvlak.queue_free()
		s.vangvlak = null
		return true
	if (s.vangvlak == null or not is_instance_valid(s.vangvlak)) and Ui.vanglaag != null:
		s.vangvlak = UiVangvlak.new()
		s.vangvlak.name = "V" + id
		Ui.vanglaag.add_child(s.vangvlak)
	if s.vangvlak == null or not is_instance_valid(s.vangvlak):
		return false
	s.vangvlak.drop = s.drop
	s.vangvlak.data = s.data
	s.vangvlak.val = s.val
	var rect := Rect2()
	if _laatste.has(id):
		rect = _laatste[id]["rect"]
	elif is_instance_valid(s.knoop):
		rect = Rect2(s.knoop.position, s.knoop.size)
	# Before the first placement pass there is no rectangle to sit on yet; the
	# next `plaats()` gives it one.  Merging an empty one would stretch the
	# catch area from the frame's corner to the object.
	if rect.size.x > 0.0 and rect.size.y > 0.0:
		_zet_vangvlak(s, rect)
	return true

func wis_alles() -> void:
	for id in _volgorde.duplicate():
		weg(id)

## The running game picks its places first and its buttons never give way.
func voorrang(spel_id: String) -> void:
	_voorrang = spel_id

func voorrang_van() -> String:
	return _voorrang

func lijst() -> Array[String]:
	return _volgorde.duplicate()

func spot(id: String) -> Spot:
	return _spots.get(id)

## Diagnostics used by the tests and the browser probe: the placed rectangle of
## every hotspot and how much of its own object it covers (must be 0 %).
func debug() -> Dictionary:
	return _laatste.duplicate(true)

func dekking(id: String) -> float:
	var l: Dictionary = _laatste.get(id, {})
	return l.get("dekking", 0.0)

# ------------------------------------------------------------- de plaatsing

## Runs once per drawn frame, after the world has moved.  One pass, no evasion.
func plaats() -> void:
	var kader := World.kader_rect()
	if kader.size.x <= 0.0:
		return
	# A drag that ended somewhere else leaves its last target glowing: once the
	# finger is gone nothing asks the catch area anything again.  Since `S1` a
	# hover over a BUTTON lights its target too, so that stray mint frame would
	# now be easy to leave behind.  One sweep per frame while nothing is being
	# dragged; a catch area only redraws when its state really changed.
	if not sleept():
		_koel_vangvlakken(null)
	_bezet.clear()
	_geplaatst.clear()
	_vakken.clear()
	# The maths bar is walled off before anything chooses a place: the paper is
	# off limits to every band and every button (PLAN.md §3.1).  Its cells go
	# into `_bezet` so the band grid never hands one out, and the rectangle
	# itself into `_balk_muur` so the free-form checks see it too.  Empty for
	# the whole time no card is docked, which is most of the game.
	_balk_muur.clear()
	if Ui.balk_aan():
		var balk := Ui.balk_rect()
		if balk.size.x > 0.0 and balk.size.y > 0.0:
			_balk_muur.append(balk)
			for cel in _cellen_van(balk, kader):
				_bezet[cel] = true
	# The counter is the one piece of world a card may not hide: the bell, the
	# till, the book and the lamp all stand on it (V1 finding 4).
	_kaart_vrij.clear()
	var balie := World.vlak_van_balie()
	if balie.size.x > 0.0 and balie.size.y > 0.0:
		_kaart_vrij.append(balie)
	var lijstje: Array[Spot] = []
	for id in _volgorde.duplicate():
		var s: Spot = _spots[id]
		# A Control can be freed from under a hotspot when the whole shell goes
		# (a scene change, a test tearing down its viewport).  Drop the spot
		# instead of writing to a freed object one frame later.
		if not is_instance_valid(s.knoop):
			weg(id)
			continue
		if s.volg.is_valid():
			var v: Dictionary = s.volg.call()
			if not v.is_empty():
				s.x = v.get("x", s.x)
				s.z = v.get("z", s.z)
				s.y = v.get("y", s.y)
				s.kamer = v.get("kamer", s.kamer)
				s.vlak = v.get("vlak", s.vlak)
		s.laag = _laag_van(s)
		s.zichtbaar = s.kamer == World.kamer_nu()
		s.vlak_nu = Rect2() if s.geen_vlak else _vlak_van(s)
		# While a game has priority the wish bubbles step aside (world.md §5.2),
		# and so does every other button of the hotel: doors, bell, board, the
		# entries of the other games — they are not part of the sum and they
		# took half the frame (owner, 2026-09-18).  What the game BORROWED
		# (`ctx.hotspots.pak`) is its own for the time being and stays; the
		# fixed layer (name plates, number tags) is information, not a button.
		if _voorrang != "" and s.laag in [Laag.WENS, Laag.HOTEL] \
				and s.geleend_door != _voorrang:
			s.zichtbaar = false
		if s.zichtbaar:
			lijstje.append(s)
		else:
			# A hotspot in ANOTHER ROOM is not laid out this pass, so its Control
			# has to be taken off the glass here — it used to keep `visible =
			# true` at whatever size it last had, which for a bubble created
			# while its guest was already elsewhere is 0 x 0: a 10 px blob with
			# its sentence spilling down the frame, one letter per line (V1-1).
			_verberg(s)
	# cull: at most 16 per room, lowest layer and priority go first
	lijstje.sort_custom(func(a: Spot, b: Spot) -> bool:
		if a.laag != b.laag:
			return a.laag < b.laag
		var ak := a.kleef_aan != ""
		var bk := b.kleef_aan != ""
		if ak != bk:
			return not ak          # what glues onto something is placed last
		if a.prio != b.prio:
			return a.prio > b.prio
		# What hangs on an object has exactly ONE good place; what floats over
		# the room may go anywhere, so the bound element chooses first (I1
		# finding 2 — the morning board's task card used to take the cell under
		# the bell and push the 🔔 button a whole band further down).
		var av := a.vlak_nu.size.x > 0.0 and a.vlak_nu.size.y > 0.0
		var bv := b.vlak_nu.size.x > 0.0 and b.vlak_nu.size.y > 0.0
		if av != bv:
			return av
		return _diepte(a) > _diepte(b))
	# Cull (B3, PLAN.md): at most `MAX_PER_KAMER` per room, but a spot that
	# anchors to the maths bar is NOT counted.  The bar limits itself already
	# — one card and one strip, and `Ui.balk_bepaal()` lets go when they do
	# not fit — so charging those two against the ceiling of sixteen took two
	# places away from the room for nothing.  That is exactly what §4 asks
	# for here: "dat geeft de keuken meteen twee plaatsen terug".
	var geteld := 0
	for s in lijstje:
		if _op_van(s) == "balk":
			continue
		if geteld >= MAX_PER_KAMER:
			s.zichtbaar = false
			continue
		geteld += 1
	# every object still in view is a box that a button must stay off
	for s in lijstje:
		if s.zichtbaar and s.vlak_nu.size.x > 0.0 and s.vlak_nu.size.y > 0.0:
			_vakken.append(s.vlak_nu)
	# place front-most first inside each layer
	var rijen := maxi(1, int((kader.size.y - 2 * RAND) / RIJ))
	var kolommen := maxi(1, int((kader.size.x - 2 * RAND) / KOL))
	for s in lijstje:
		if not s.zichtbaar:
			_verberg(s)
			continue
		s.knoop.visible = true
		var maat := _maat_van(s)
		var mik := World.mik_punt(s.x, s.z, s.y)
		# The counter is a thing too (owner, 2026-09-14: the board's cards and
		# the 📋 button lay over it).  A game with priority keeps its own
		# plates on the desk (the key board's hooks, I2); everything of the
		# hotel stays off it.
		_mijd_balie_nu = s.laag != Laag.SPEL and s.op != "aan"
		var uit := _blijf_staan(s, mik, maat, kader)
		if uit.is_empty():
			uit = _kies_plek(s, mik, maat, kader, rijen, kolommen)
		var rect: Rect2 = uit["rect"]
		s.knoop.custom_minimum_size = maat
		s.knoop.size = maat
		s.knoop.position = rect.position
		_laatste[s.id] = {
			"id": s.id, "op": uit["op"], "laag": s.laag, "prio": s.prio,
			"rect": rect, "vlak": s.vlak_nu, "krap": uit["krap"], "mik": mik,
			# true when the two bands beside the object were full and the
			# element had to stack somewhere else in the frame
			"gestapeld": uit.get("gestapeld", false),
			"dekking": _dekking(rect, s.vlak_nu),
		}
		_zet_vangvlak(s, rect)

## Stay put (owner, 2026-09-14: opening the board reshuffled half the buttons).
## A band-placed element keeps last frame's rectangle when its aim point has
## not moved, the rectangle is the same size, still inside the frame, at most
## two bands from the aim point, and touches nothing placed and no object box.
## Anchored placements (a fixed card, a glued strip, a tag, the foot) choose
## afresh every pass: their place IS the rule.
const BLIJF_MIK := 4.0      ## css-px the aim point may drift before re-placing
const BLIJF_BANDEN := 2     ## how far from the object a kept place may be

func _blijf_staan(s: Spot, mik: Vector2, maat: Vector2, kader: Rect2) -> Dictionary:
	var l: Dictionary = _laatste.get(s.id, {})
	if l.is_empty() or not l.has("mik"):
		return {}
	var op := str(l["op"])
	# `balk` is in this list because its place is the bar, and the bar moves:
	# a card that kept last frame's rectangle would keep standing where the
	# paper used to be after the paper shrank or went away.
	if op in ["voet", "midden", "kleef", "rand", "aan", "balk"] or bool(l["krap"]):
		return {}
	var r: Rect2 = l["rect"]
	if not r.size.is_equal_approx(maat) or (l["mik"] as Vector2).distance_to(mik) > BLIJF_MIK:
		return {}
	if r.position.x < 0.0 or r.position.y < 0.0 or r.end.x > kader.size.x or r.end.y > kader.size.y:
		return {}
	var afstand := minf(absf(r.position.y - mik.y), absf(r.end.y - mik.y))
	if afstand > BLIJF_BANDEN * RIJ + maat.y:
		return {}
	if _botst(r) or _vak_kosten(r) > 0.0:
		return {}
	_reserveer(r, kader)
	return {"rect": r, "op": op, "krap": false, "gestapeld": bool(l.get("gestapeld", false))}

## Off the glass: a hotspot that is not placed this pass shows nothing at all.
func _verberg(s: Spot) -> void:
	if is_instance_valid(s.knoop):
		s.knoop.visible = false
	if s.vangvlak != null and is_instance_valid(s.vangvlak):
		s.vangvlak.visible = false
	_laatste.erase(s.id)

## The catch area is the union of the button and its object, so dragging onto
## the object itself works (world.md §5.4 step 8).  Nothing for a game to do:
## it only declares `drop`.
func _zet_vangvlak(s: Spot, rect: Rect2) -> void:
	if s.vangvlak == null or not is_instance_valid(s.vangvlak):
		return
	var vang := rect
	if s.vlak_nu.size.x > 0.0 and s.vlak_nu.size.y > 0.0:
		vang = rect.merge(s.vlak_nu)
	s.vangvlak.position = vang.position
	s.vangvlak.size = vang.size
	s.vangvlak.visible = s.zichtbaar

## How near an object has to stand to count as "the object this hotspot hangs on".
const VLAK_NABIJ := 2.0

## The screen rectangle a hotspot has to stay off.
##
## A caller may hand it in (`vlak`), name the object (`obj`), or hand in neither
## — and the hotel's own buttons hand in neither: they know where the bowl IS,
## not how big it draws.  In that case the object is looked up by position in
## the room (loose things, a game's loose decor, slots, fixed decor) and its
## baked plate gives the exact rectangle, so `Hits.dekking()` measures something
## real for every button and not only for the ones that were kind enough to say.
##
## The lookup is cached per room + decor version; the rectangle itself is
## recomputed every pass, because the camera moves.
func _vlak_van(s: Spot) -> Rect2:
	if s.vlak.size.x > 0.0 and s.vlak.size.y > 0.0:
		return s.vlak
	if not s.zichtbaar:
		return Rect2()
	var sleutel := "%s|%d" % [s.kamer, World.decor_versie()]
	if s._voorwerp_sleutel != sleutel:
		s._voorwerp_sleutel = sleutel
		s._voorwerp = _zoek_voorwerp(s)
	if s._voorwerp.is_empty():
		return Rect2()
	var stuk := s._voorwerp
	return World.vlak_van(str(stuk.get("model", stuk.get("n", ""))),
		float(stuk.get("x", 0.0)), float(stuk.get("z", 0.0)),
		float(stuk.get("hoog", stuk.get("y", 0.0))), stuk.get("params", {}),
		Vector2.ZERO, int(stuk.get("rot", 0)))

## The thing a hotspot stands on: by name when it has one, otherwise the nearest
## thing in the room within VLAK_NABIJ voxels of its aim point.
func _zoek_voorwerp(s: Spot) -> Dictionary:
	if s.obj != "":
		var op_naam := World.mik(s.obj, s.kamer)
		if _bruikbaar(op_naam):
			return op_naam
	var kandidaten: Array = []
	kandidaten.append_array(World.dingen(s.kamer))
	kandidaten.append_array(World.decor_lijst(s.kamer))
	var r := Rooms.get_kamer(s.kamer)
	if r != null:
		kandidaten.append_array(r.slots.values())
		kandidaten.append_array(r.decor)
	var beste: Dictionary = {}
	var dichtst := VLAK_NABIJ
	for stuk in kandidaten:
		if not _bruikbaar(stuk):
			continue
		var d := absf(float(stuk.get("x", 0.0)) - s.x) + absf(float(stuk.get("z", 0.0)) - s.z)
		if d <= dichtst:
			dichtst = d
			beste = stuk
	return beste

func _bruikbaar(stuk: Variant) -> bool:
	if typeof(stuk) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = stuk
	var naam := str(d.get("model", d.get("n", "")))
	return not naam.is_empty() and Art.heeft_model(naam)

## A tap target is at least 48 x 48; a number tag and a name plate keep their
## natural size — neither is clickable, so neither is a fingertip.
func _maat_van(s: Spot) -> Vector2:
	# Every sum card answers through `Ui.kaart_mat()`, never through its own
	# Control minimum.  A freshly built or just-released card has labels that
	# were never laid out at the width they are drawn at, so the Control
	# answers a one-word-per-line tower (1225 units for a card that draws 90)
	# and `Hits` would pin that into `custom_minimum_size` and place the card
	# far outside the frame.  `kaart_mat` measures the docked card with
	# `maat_balk()` and the floating card with the theme at its own width, so
	# neither a dock nor a float can place a tower (B4).
	if s.kind == "kaart" and s.knoop is UiSomkaart:
		var eerlijk := Ui.kaart_mat(s.knoop)
		if eerlijk.x > 0.0 and eerlijk.y > 0.0:
			return eerlijk
	# A Control that carries a Container inside a NON-Container says how big its
	# content is (`UiWolk` is a Button with a row in it); everything else answers
	# with its combined minimum, which for a Container is the same thing.
	var maat := Vector2.ZERO
	if s.knoop.has_method("inhoud_maat"):
		maat = s.knoop.call("inhoud_maat")
	var eigen := s.knoop.get_combined_minimum_size()
	maat.x = maxf(maat.x, eigen.x)
	maat.y = maxf(maat.y, eigen.y)
	if s.maat.x > 0.0:
		maat.x = maxf(maat.x, s.maat.x)
	if s.maat.y > 0.0:
		maat.y = maxf(maat.y, s.maat.y)
	if s.kind != "tag" and s.kind != "naam":
		maat.x = maxf(maat.x, 48.0)
		maat.y = maxf(maat.y, 48.0)
	return maat

func _laag_van(s: Spot) -> int:
	if s.vast or s.kind == "tag" or s.kind == "naam":
		return Laag.VAST
	if _voorrang != "" and s.door == _voorrang:
		return Laag.SPEL
	if s.klas.contains("hotwens"):
		return Laag.WENS
	return Laag.HOTEL

func _diepte(s: Spot) -> float:
	return s.d if not is_nan(s.d) else s.x + s.z

func _op_van(s: Spot) -> String:
	if s.op == "voet":
		return "voet"
	# The maths bar owns the card it has docked, and the answer strip that
	# hangs on it (PLAN.md §3.1).  This is asked BEFORE `kleef_aan` because
	# the strip of a docked card glues onto that card and has to follow it
	# onto the paper instead of hunting for a band under it.
	if Ui.balk_aan() and Ui.balk_kaart() != "":
		if s.kind == "kaart" and s.id == Ui.balk_kaart():
			return "balk"
		if s.kind == "keuzes" and s.kleef_aan == Ui.balk_kaart():
			return "balk"
	if s.op == "aan":
		return "aan" if s.vlak_nu.size.y > 0.0 else "boven"
	if s.kleef_aan != "":
		return "kleef"
	if s.op != "auto":
		return s.op
	if s.kind == "tag" or s.kind == "naam":
		return "rand"
	if s.vast or s.y <= 0.0:
		return "midden"
	return "boven"

## The heart of the structural rule.  Returns {rect, op, krap}.
##
## `midden` and `rand` are the only anchors that may stand over the world: a
## fixed card chooses first and everything gives way to it, a number tag covers
## at most a tenth of its own object.  Both RESERVE every cell they touch, so a
## later button can never land on them (the bug this pass was rewritten for).
##
## Everything else is placed on the band grid and must satisfy, in one pass:
##   a. inside the frame — true by construction, the grid lives inside it;
##   b. no reserved cell — so no two placed elements overlap;
##   c. no object box — 0 % coverage of every object in view, not just its own.
## Bands are tried closest-to-the-object first, then the other side, then the
## whole frame top-down (the HTML's "stacking" round).  Only if not one cell in
## the frame is free does it fall back to the aim point, and then `krap` is true
## and the tests fail — it is a diagnosis, not a silent overlap.
func _kies_plek(s: Spot, mik: Vector2, maat: Vector2, kader: Rect2, rijen: int, kolommen: int) -> Dictionary:
	var op := _op_van(s)
	var vlak := s.vlak_nu
	var top := vlak.position.y if vlak.size.y > 0.0 else mik.y - s.y * World.px_per_hoogte()
	var voet := vlak.end.y if vlak.size.y > 0.0 else mik.y
	if op == "balk":
		# The maths bar of PLAN.md §3.1: the card and its strip stand ON the
		# paper, which `Ui` measured and `plaats()` already walled off from
		# the rest of the frame.  No band and no object box applies here — the
		# bar is the one place that may sit where the world used to be,
		# because the world was moved out of it first.
		var balk_plek: Rect2 = Ui.balk_plek(s.kind, maat)
		if balk_plek.size.x > 0.0:
			_reserveer(balk_plek, kader)
			return {"rect": balk_plek, "op": op, "krap": false, "gestapeld": false}
		# The bar let go between the wall going up and this element asking; the
		# card falls back on where it would have gone anyway.
		op = "midden" if (s.kind == "kaart" or s.kind == "wolk") else "onder"
	if op == "voet":
		# The keypad band: docked to the bottom of the world frame, inside the
		# KADER_ONDER strip the camera already keeps free (architecture.md §4.4).
		# It is placed FIRST inside its layer, so a card that would land on it
		# lifts itself instead of the pad moving under the room.
		var r := _klem(Rect2(Vector2(kader.size.x * 0.5 - maat.x * 0.5,
			kader.size.y - RAND - maat.y), maat), kader)
		_reserveer(r, kader)
		return {"rect": r, "op": op, "krap": false, "gestapeld": false}
	if op == "midden":
		return _plaats_midden(mik, maat, kader, s.vlak_nu, s.kind == "kaart" or s.kind == "wolk")
	if op == "aan":
		# AT its own thing (owner, 2026-09-14): the thing stays visible, the
		# button sits right under it or right above it, whichever fits; a BIG
		# thing (the notice board, GROOT button areas or more) may carry the
		# button on itself, centred on the aim point.  Anything else placed and
		# every other object box stay clear — otherwise the bands decide.
		#
		# A DOOR is a way out, not a thing to use: its sign stands on the floor
		# straight in front of it, in every room, so a child finds every exit
		# the same way (owner, 2026-09-23: the buttons stood "op plekken die niet
		# consistent zijn").  Never ON the door as its first choice — a door
		# drawn big near the camera passed the GROOT test meant for the notice
		# board (gang → keuken) — but on the foot of its own door before ABOVE
		# it: a sign on the door still reads as that door, one over its lintel
		# read as the wall (keuken → wasserij, with the trolley's box right
		# under the threshold).
		var deur := s.klas.contains("hotdeur")
		# The notice board carries its button by name, not by arithmetic: it
		# is the thing that rule was written for, and it passed GROOT by a
		# hair (13520 against 12960) until the world's letters grew and the
		# 📋 button with them — then it moved above the board and pushed the
		# first task card 191 units along the wall (owner, 2026-09-23).
		var groot := not deur and (s.klas.contains("hotbord")
			or vlak.size.x * vlak.size.y >= GROOT * maat.x * maat.y)
		var x0 := mik.x - maat.x * 0.5
		var kandidaten: Array[Rect2] = []
		var op_eigen: Array[bool] = []     ## this candidate may stand on its own thing
		if groot:
			# The board carries its 📋 in its middle, not on its aim point at the
			# top edge: there the button straddled the band right over the board,
			# the one band its first task card (55 high, two bands) can stand in.
			var hart := vlak.get_center().y if s.klas.contains("hotbord") else mik.y
			kandidaten.append(Rect2(Vector2(x0, hart - maat.y * 0.5), maat))
			op_eigen.append(true)
		kandidaten.append(Rect2(Vector2(x0, voet + GAT), maat))
		op_eigen.append(false)
		if deur:
			kandidaten.append(Rect2(Vector2(x0, voet - GAT - maat.y), maat))
			op_eigen.append(true)
		kandidaten.append(Rect2(Vector2(x0, top - GAT - maat.y), maat))
		op_eigen.append(false)
		for i in kandidaten.size():
			var r := _klem(kandidaten[i], kader)
			var eigen_mag := op_eigen[i]
			if _botst(r):
				continue
			if _vak_kosten(r, vlak if eigen_mag else Rect2()) > 0.0:
				continue
			if not eigen_mag and _dekking(r, vlak) > 0.0:
				continue
			_reserveer(r, kader)
			return {"rect": r, "op": "aan", "krap": false, "gestapeld": false}
		op = "onder"
	if s.kleef_aan != "":
		var aan: Dictionary = _laatste.get(s.kleef_aan, {})
		if not aan.is_empty():
			var kr: Rect2 = aan["rect"]
			var mx := kr.position.x + kr.size.x * 0.5 - maat.x * 0.5
			# Under the card, else above it, else docked at the foot of the frame
			# (the KADER_ONDER strip the camera keeps free under the room) — each
			# only when it touches nothing placed AND no object box.  A strip of
			# four numbers is as wide as a keypad row; simply hung under the card
			# it covered the price tags (kraam, 740×360) and the till (meubels).
			var kandidaten: Array[Rect2] = [
				_klem(Rect2(Vector2(mx, kr.end.y + KLEEF), maat), kader),
				_klem(Rect2(Vector2(mx, kr.position.y - KLEEF - maat.y), maat), kader),
				_klem(Rect2(Vector2(kader.size.x * 0.5 - maat.x * 0.5,
					kader.size.y - RAND - maat.y), maat), kader),
				# K1 (2026-09-21): op een laag kader (liggende telefoon) zijn
				# onder de kaart, boven de kaart én de kadervoet alle drie door
				# de kaart zelf bezet — de strook met vier knoppen heeft dan
				# niets meer over en wordt `krap`.  Probeer daarom ook de
				# ZIJKANTEN van de kaart, op de hoogte van de kaart zelf.  De
				# vloer ernaast is vrij: de kaart staat aan de rand en de
				# strook is van dezelfde orde breed.  Laatst in de lijst, dus
				# elke opstelling die vandaag al werkt blijft zoals hij is.
				_klem(Rect2(Vector2(kr.end.x + KLEEF,
					kr.get_center().y - maat.y * 0.5), maat), kader),
				_klem(Rect2(Vector2(kr.position.x - KLEEF - maat.x,
					kr.get_center().y - maat.y * 0.5), maat), kader),
				# B4: the honest (unpinned) width of a floating card is a few
				# units narrower than the width it used to carry, so the strip
				# centred beside it can graze a tile that sits right at the
				# card's edge.  Slide the strip along the card's own height
				# column — top-aligned, then bottom-aligned — so it can dodge
				# such a sliver.  Last in the list: every arrangement that
				# already fits keeps its spot.
				_klem(Rect2(Vector2(kr.end.x + KLEEF, kr.position.y), maat), kader),
				_klem(Rect2(Vector2(kr.end.x + KLEEF, kr.end.y - maat.y), maat), kader),
				_klem(Rect2(Vector2(kr.position.x - KLEEF - maat.x, kr.position.y), maat), kader),
				_klem(Rect2(Vector2(kr.position.x - KLEEF - maat.x, kr.end.y - maat.y), maat), kader),
			]
			for i in kandidaten.size():
				var r := kandidaten[i]
				if not _botst(r) and _vak_kosten(r) <= 0.0:
					_reserveer(r, kader)
					return {"rect": r, "op": "voet" if i == 2 else "kleef", "krap": false,
						"gestapeld": i == 2}
			# nothing clean next to the card: the band grid below decides, with
			# the same rules as any button (no reserved cell, no object box)
			op = "onder"
		else:
			# the thing it glues onto is not on screen: fall back to the aim point
			return _plaats_midden(mik, maat, kader, s.vlak_nu, s.kind == "kaart" or s.kind == "wolk")
	if op == "rand":
		# A number tag may cover a tenth of its own object; a name plate hangs
		# clear of the guest.  Neither may land on something already placed —
		# that is what put the "Boef" plate over the Prikbord button (I1
		# finding 3), so it steps up in whole bands until it is free.
		var in_vlak := minf(maat.y, vlak.size.y * TAG_IN) if s.kind != "naam" else -2.0
		var y := top - maat.y + in_vlak
		var r := _klem(Rect2(Vector2(mik.x - maat.x * 0.5, y), maat), kader)
		r = _wijk_omhoog(r, kader)
		var krap_rand := _botst(r)
		_reserveer(r, kader)
		return {"rect": r, "op": op, "krap": krap_rand, "gestapeld": false}
	var volgorde := _bandvolgorde(op, top, voet, maat, rijen)
	var doel := vlak.get_center() if vlak.size.y > 0.0 else mik
	# pass 1a: the bands directly above and below the object, and in them the
	# cell block NEAREST to the object — a free cell at the other end of the
	# top band is not "above the bell", it is beside the door (I1 finding 2).
	var beste := Rect2()
	var beste_kosten := INF
	var beste_kant := ""
	var beste_dichtst := false
	for i in volgorde.size():
		var kant: String = volgorde[i]["kant"]
		if kant.is_empty():
			continue
		var rij: int = volgorde[i]["rij"]
		var kand := _zoek_cel(rij, mik.x, maat, kolommen, rijen, false,
			_band_y(rij, maat, kant, top, voet))
		if kand["rect"].size.x <= 0.0:
			continue
		# distance to the object, plus a hair per step down the preference list
		# so the asked side still wins a tie
		var afstand: float = (kand["rect"].get_center() - doel).length() + i * 0.01
		if afstand < beste_kosten:
			beste = kand["rect"]
			beste_kosten = afstand
			beste_kant = kant
			beste_dichtst = bool(volgorde[i]["dichtst"])
	if beste_kosten < INF:
		_reserveer(beste, kader)
		# `gestapeld` = the band DIRECTLY above or below the object had no free
		# block left for me, so I am one band further out; that is the "unless
		# the band is full" of architecture.md §4.3, said out loud instead of
		# silently drifting.
		return {"rect": beste, "op": beste_kant, "krap": false,
			"gestapeld": not beste_dichtst}
	# pass 1b: the stacking round — every remaining band from the top down
	for k in volgorde:
		if not str(k["kant"]).is_empty():
			continue
		var rij: int = k["rij"]
		var kand := _zoek_cel(rij, mik.x, maat, kolommen, rijen, false, _band_y(rij, maat, "", top, voet))
		if kand["rect"].size.x > 0.0:
			_reserveer(kand["rect"], kader)
			return {"rect": kand["rect"], "op": _werd(op, rij, top, maat), "krap": false,
				"gestapeld": true}
	# pass 2: a free cell with the least object overlap
	var beste_rij := -1
	beste = Rect2()
	beste_kosten = INF
	for k in volgorde:
		var rij: int = k["rij"]
		var kand := _zoek_cel(rij, mik.x, maat, kolommen, rijen, true,
			_band_y(rij, maat, str(k["kant"]), top, voet))
		if kand["rect"].size.x > 0.0 and kand["kosten"] < beste_kosten:
			beste = kand["rect"]
			beste_kosten = kand["kosten"]
			beste_rij = rij
	if beste_kosten < INF:
		_reserveer(beste, kader)
		return {"rect": beste, "op": _werd(op, beste_rij, top, maat), "krap": true,
			"gestapeld": true}
	# nothing free in the whole frame: the aim point, clamped, and flagged
	var laatste := _klem(Rect2(mik - maat * 0.5, maat), kader)
	_reserveer(laatste, kader)
	return {"rect": laatste, "op": op, "krap": true, "gestapeld": true}

## On the aim point, clamped into the frame, lifted clear of anything already
## placed and of its own object.
func _plaats_midden(mik: Vector2, maat: Vector2, kader: Rect2, eigen: Rect2, mijd_balie := true) -> Dictionary:
	# A fixed card or cloud gives way to the counter as well (V1 finding 4); a
	# game's own plates that HANG on the desk (the key board's hooks) do not, or
	# the row would be torn apart band by band (I2, sleutels).
	var r := _wijk_omhoog(_klem(Rect2(mik - maat * 0.5, maat), kader), kader, eigen, mijd_balie)
	var krap := _botst(r)
	_reserveer(r, kader)
	return {"rect": r, "op": "midden", "krap": krap, "gestapeld": false}

## A fixed card lifts itself off whatever is already on screen (its own keypad,
## in practice), in whole bands, upwards first and then downwards.  The test is
## a real rectangle overlap, not a shared grid cell: the choice strip is glued
## 5 units under its card ON PURPOSE and must not be pushed away for it.
func _wijk_omhoog(r: Rect2, kader: Rect2, eigen := Rect2(), mijd_balie := false) -> Rect2:
	if not _bezet_voor(r, eigen, mijd_balie):
		return r
	for stap in range(1, maxi(2, int(kader.size.y / RIJ)) + 1):
		var op_r := Rect2(Vector2(r.position.x, r.position.y - stap * RIJ), r.size)
		if op_r.position.y >= KRAP and not _bezet_voor(op_r, eigen, mijd_balie):
			return op_r
		var neer := Rect2(Vector2(r.position.x, r.position.y + stap * RIJ), r.size)
		if neer.end.y <= kader.size.y - KRAP and not _bezet_voor(neer, eigen, mijd_balie):
			return neer
	# Nowhere free: keep the aim point, but never at the cost of the invariant
	# that two placed elements do not overlap — that one is checked separately
	# and reported as `krap`.
	for stap in range(1, maxi(2, int(kader.size.y / RIJ)) + 1):
		var op_r := Rect2(Vector2(r.position.x, r.position.y - stap * RIJ), r.size)
		if op_r.position.y >= KRAP and not _botst(op_r):
			return op_r
		var neer := Rect2(Vector2(r.position.x, r.position.y + stap * RIJ), r.size)
		if neer.end.y <= kader.size.y - KRAP and not _botst(neer):
			return neer
	return r

## A fixed card may stand over the world, but never over the object it belongs
## to: the sum hangs ABOVE the bowl, the guest stays whole (HOTEL.md §9).
func _bezet_voor(r: Rect2, eigen: Rect2, mijd_balie := false) -> bool:
	if _botst(r):
		return true
	for vrij in (_kaart_vrij if mijd_balie else [] as Array[Rect2]):
		var s2 := r.intersection(vrij)
		if s2.size.x > 0.001 and s2.size.y > 0.001:
			return true
	if eigen.size.x <= 0.0 or eigen.size.y <= 0.0:
		return false
	var snij := r.intersection(eigen)
	return snij.size.x > 0.001 and snij.size.y > 0.001

## Does this rectangle touch anything already handed out in this pass, or the
## paper of the maths bar?
func _botst(r: Rect2) -> bool:
	for g in _geplaatst:
		var snij := r.intersection(g)
		if snij.size.x > 0.001 and snij.size.y > 0.001:
			return true
	for g in _balk_muur:
		var snij := r.intersection(g)
		if snij.size.x > 0.001 and snij.size.y > 0.001:
			return true
	return false

func _cellen_van(r: Rect2, kader: Rect2) -> Array[String]:
	var rijen := maxi(1, int((kader.size.y - 2 * RAND) / RIJ))
	var kolommen := maxi(1, int((kader.size.x - 2 * RAND) / KOL))
	var k0 := int(floor((r.position.x - RAND) / KOL))
	var k1 := int(floor((r.end.x - 0.001 - RAND) / KOL))
	var r0 := int(floor((r.position.y - RAND) / RIJ))
	var r1 := int(floor((r.end.y - 0.001 - RAND) / RIJ))
	var uit: Array[String] = []
	for rr in range(maxi(0, r0), mini(rijen - 1, r1) + 1):
		for kk in range(maxi(0, k0), mini(kolommen - 1, k1) + 1):
			uit.append("%d|%d" % [rr, kk])
	return uit

## What the anchor became, for Hits.debug() — `boven` may silently become `onder`.
func _werd(op: String, rij: int, top: float, maat: Vector2) -> String:
	if op != "boven":
		return op
	return "boven" if RAND + (rij + _rij_hoog(maat)) * RIJ <= top - GAT else "onder"

## Bands in order of preference: the side asked for (closest to the object
## first), then the other side, then every remaining band from the top down.
## Every entry says which side it is (`kant`); the stacking round carries "".
##
## A band qualifies when the element FITS INSIDE it while keeping `GAT` air to
## the object — not when the whole band clears the object.  A 48 unit button in
## a 52 unit band has four units of play, and that play is what lets it sit
## against the bell instead of a whole dead band lower (I1 finding 2): the old
## rule left up to 51 units of quantisation gap.
func _bandvolgorde(op: String, top: float, voet: float, maat: Vector2, rijen: int) -> Array[Dictionary]:
	var hoog := _rij_hoog(maat)
	var boven: Array[Dictionary] = []
	for r in range(rijen - hoog, -1, -1):
		if RAND + r * RIJ + maat.y <= top - GAT:
			boven.append({"rij": r, "kant": "boven", "dichtst": boven.is_empty()})
	var onder: Array[Dictionary] = []
	for r in range(0, rijen - hoog + 1):
		if RAND + (r + hoog) * RIJ - maat.y >= voet + GAT:
			onder.append({"rij": r, "kant": "onder", "dichtst": onder.is_empty()})
	var uit: Array[Dictionary] = []
	if op == "onder":
		uit.append_array(onder)
		uit.append_array(boven)
	else:
		uit.append_array(boven)
		uit.append_array(onder)
	var gehad := {}
	for k in uit:
		gehad[k["rij"]] = true
	for r in range(0, rijen - hoog + 1):
		if not gehad.has(r):
			uit.append({"rij": r, "kant": "", "dichtst": false})
	return uit

## Where the top edge of an element lands inside its band block: against the
## object when the band is the one above or below it, centred otherwise.
func _band_y(rij: int, maat: Vector2, kant: String, top: float, voet: float) -> float:
	var hoog := _rij_hoog(maat)
	var blok_top := float(RAND + rij * RIJ)
	var blok_voet := float(RAND + (rij + hoog) * RIJ)
	if kant == "onder":
		return clampf(voet + GAT, blok_top, blok_voet - maat.y)
	if kant == "boven":
		return clampf(top - GAT - maat.y, blok_top, blok_voet - maat.y)
	return blok_top + (hoog * RIJ - maat.y) * 0.5

func _rij_hoog(maat: Vector2) -> int:
	return maxi(1, ceili(maat.y / float(RIJ)))

## Nearest free column block in this band, searched outward from the aim point.
## Returns {rect, kosten}; an empty rect means "nothing free here".
func _zoek_cel(rij: int, wens_x: float, maat: Vector2, kolommen: int, rijen: int,
		sta_vak_toe: bool, y: float) -> Dictionary:
	var breed := maxi(1, ceili(maat.x / float(KOL)))
	var hoog := _rij_hoog(maat)
	if rij < 0 or rij + hoog > rijen or breed > kolommen:
		return {"rect": Rect2(), "kosten": INF}
	var start := clampi(int((wens_x - RAND) / KOL), 0, maxi(0, kolommen - breed))
	var beste := Rect2()
	var beste_kosten := INF
	for stap in kolommen:
		for teken in ([1] if stap == 0 else [1, -1]):
			var k: int = start + stap * int(teken)
			if k < 0 or k + breed > kolommen:
				continue
			if not _cellen_vrij(rij, k, breed, hoog):
				continue
			var r := _cel(rij, k, maat, y)
			var kosten := _vak_kosten(r)
			if kosten <= 0.0:
				return {"rect": r, "kosten": 0.0}
			if sta_vak_toe and kosten < beste_kosten:
				beste = r
				beste_kosten = kosten
	return {"rect": beste, "kosten": beste_kosten}

func _cellen_vrij(rij: int, kol: int, breed: int, hoog: int) -> bool:
	for i in breed:
		for j in hoog:
			if _bezet.has("%d|%d" % [rij + j, kol + i]):
				return false
	return true

## How much of the world this rectangle would cover.  0 = it covers nothing.
func _vak_kosten(r: Rect2, eigen := Rect2()) -> float:
	var som := 0.0
	for v in _vakken:
		if eigen.size.x > 0.0 and v.is_equal_approx(eigen):
			continue
		var snij := r.intersection(v)
		if snij.size.x > 0.0 and snij.size.y > 0.0:
			som += snij.size.x * snij.size.y
	if _mijd_balie_nu:
		for v in _kaart_vrij:
			var snij := r.intersection(v)
			if snij.size.x > 0.0 and snij.size.y > 0.0:
				som += snij.size.x * snij.size.y
	return som

## A placed rectangle blocks every cell it touches — cards and clamped
## placements included.  That is the invariant the review found missing.
func _reserveer(r: Rect2, kader: Rect2) -> void:
	_geplaatst.append(r)
	for cel in _cellen_van(r, kader):
		_bezet[cel] = true

## The rectangle of one cell block.  Inside the frame by construction: `y` comes
## from `_band_y`, which never leaves the block this call reserves.
func _cel(rij: int, kol: int, maat: Vector2, y: float) -> Rect2:
	var breed := maxi(1, ceili(maat.x / float(KOL)))
	var x := RAND + kol * KOL + (breed * KOL - maat.x) * 0.5
	return Rect2(Vector2(x, y), maat)

func _klem(r: Rect2, kader: Rect2) -> Rect2:
	r.position.x = clampf(r.position.x, KRAP, maxf(KRAP, kader.size.x - r.size.x - KRAP))
	r.position.y = clampf(r.position.y, KRAP, maxf(KRAP, kader.size.y - r.size.y - KRAP))
	return r

func _dekking(knop: Rect2, vlak: Rect2) -> float:
	if vlak.size.x <= 0.0 or vlak.size.y <= 0.0:
		return 0.0
	var snij := knop.intersection(vlak)
	if snij.size.x <= 0.0 or snij.size.y <= 0.0:
		return 0.0
	return 100.0 * (snij.size.x * snij.size.y) / (vlak.size.x * vlak.size.y)
