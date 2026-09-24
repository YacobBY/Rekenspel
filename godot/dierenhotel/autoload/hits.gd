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
const PAAR_BANDEN := 6      ## how many bands a card may step to find room for its strip
const PAAR_SCHUIF := 40.0   ## how far the frame edge may slide a strip along its card

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
var _strook_van: Dictionary = {}   ## card id -> the answer strip glued to it, this pass
var _strook_plek: Dictionary = {}  ## card id -> the place its pair kept for the strip
var _paar_cache: Dictionary = {}   ## card id -> the last pair, while nothing changed
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
	var paar := true               ## a card placed together with its answer strip (`paar: false`: its game plans that)
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
	s.paar = bool(o.get("paar", true))
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
	# till, the book and the lamp all stand on it (V1 finding 4).  Piece by
	# piece, not the one box round the diagonal desk: that box is mostly the
	# floor in front of the counter, and everything that belongs AT the counter
	# — the check-in card, the families, the bill's hints — was pushed away
	# from it (owner, 2026-09-23).
	_kaart_vrij.clear()
	_kaart_vrij.append_array(World.vlakken_van_balie())
	var som_nu := Ui.som_in_beeld()     # asked once per pass (door signs, below)
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
		# (`ctx.hotspots.pak`) is its own for the time being and stays, and so
		# does what the hotel hangs up FOR it (`data.spel`): the "komt eraan"
		# bubble of the animal the game waits for (owner, 2026-09-23); the
		# fixed layer (name plates, number tags) is information, not a button.
		if _voorrang != "" and s.laag in [Laag.WENS, Laag.HOTEL] \
				and s.geleend_door != _voorrang \
				and str(s.data.get("spel", "")) != _voorrang:
			s.zichtbaar = false
		# While a sum is being answered the hotel's door signs step aside too
		# (owner, 2026-09-24: "Kan je tijdens een rekensom de hotkeys voor
		# mappen verbergen"); the rule is `Ui.is_som`.  A BORROWED door is the
		# game's own tool and stays.
		if som_nu and s.zichtbaar and s.klas.contains("hotdeur") and s.geleend_door == "":
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
		# The door signs before everything else, in every layer: a sign has ONE
		# place — on its door — and every other element gives way to it, not
		# the other way round (owner, 2026-09-24: "Kamer 2 staat onder de deur
		# maar kamer 1 boven de deur. Dit is geen consistente plaats").
		var ad := _is_deurbord(a)
		var bd := _is_deurbord(b)
		if ad != bd:
			return ad
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
	# which card carries which answer strip: the two are placed as a pair
	_strook_van.clear()
	_strook_plek.clear()
	for s in lijstje:
		if s.zichtbaar and s.kind == "keuzes" and s.kleef_aan != "":
			_strook_van[s.kleef_aan] = s
	# every object still in view is a box that a button must stay off
	for s in lijstje:
		if s.zichtbaar and s.vlak_nu.size.x > 0.0 and s.vlak_nu.size.y > 0.0:
			_vakken.append(s.vlak_nu)
	# The front door of the receptie is a thing as well, though no button hangs
	# on it: without its box the evening's 🌙 button covered up to 69 % of it and
	# the bill's buttons 42 % (2026-09-23, the entrance of `Rooms.ingang`).
	var ingang := World.vlak_van_ingang(World.kamer_nu())
	if ingang.size.x > 0.0 and ingang.size.y > 0.0:
		_vakken.append(ingang)
	_verzamel_dingen(World.kamer_nu())
	# the door signs of this room, chosen as one set before anything is placed
	_kies_deurborden(lijstje, kader)
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
		# a bubble that only speaks points its tail at what it talks about
		if s.knoop is UiWolk:
			(s.knoop as UiWolk).richt(_richtpunt(rect, s.vlak_nu, mik) - rect.position)
		_laatste[s.id] = {
			"id": s.id, "op": uit["op"], "laag": s.laag, "prio": s.prio,
			"rect": rect, "vlak": s.vlak_nu, "krap": uit["krap"], "mik": mik,
			# true when the two bands beside the object were full and the
			# element had to stack somewhere else in the frame
			"gestapeld": uit.get("gestapeld", false),
			"dekking": _dekking(rect, s.vlak_nu),
			# a door sign: "deur" (on the opening), "latei" (over the lintel)
			# or "" (neither: the band grid took it — a finding for the tests)
			"deurplek": uit.get("deurplek", ""),
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
	# A button that hangs ON its thing asks for its own place again every pass,
	# also when it had to fall back on a band once: the check-in card that
	# walked past the board pushed "Prikbord" onto the floor, and the rule
	# below kept it there after the card had gone (owner, 2026-09-23).
	if s.op == "aan":
		return {}
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

## What a bubble talks about, as a point in the frame: the point of its thing
## nearest to the bubble, or its aim point when it hangs on no thing.
## `Vector2.INF` when that point lies under the bubble itself (no tail then).
static func _richtpunt(r: Rect2, vlak: Rect2, mik: Vector2) -> Vector2:
	var p := mik
	if vlak.size.x > 0.0 and vlak.size.y > 0.0:
		var c := r.get_center()
		p = Vector2(clampf(c.x, vlak.position.x, vlak.end.x),
			clampf(c.y, vlak.position.y, vlak.end.y))
	return Vector2.INF if r.has_point(p) else p

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
	var model := str(stuk.get("model", stuk.get("n", "")))
	# A bowl is drawn round `Art.KOM_ANKER` (scenes/kamer.gd), not round the
	# corner of its model: measured without it its box lay some 88 × 70 units
	# below-right of the drawn bowl, so "🍽 Leeg" hung beside the bowl and a drop
	# on the drawn bowl missed (found by the voerkar branch, 2026-09-23).
	var anker := Art.KOM_ANKER if (model == "kom" or str(stuk.get("soort", "")) == "bak") \
		else Vector2.ZERO
	return World.vlak_van(model,
		float(stuk.get("x", 0.0)), float(stuk.get("z", 0.0)),
		float(stuk.get("hoog", stuk.get("y", 0.0))), stuk.get("params", {}),
		anker, int(stuk.get("rot", 0)))

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

## A door's sign (`hotel.gd` hangs one on every door, `klas: hotdeur`).
static func _is_deurbord(s: Spot) -> bool:
	return s.op == "aan" and s.klas.contains("hotdeur")

## Where a door sign stands, in this order and nowhere else: centred on the
## door opening at its half height, and — only when something is in the way
## there — straight over it, just above its lintel.  That one fallback has a
## second row a sign higher, still straight over the same door, for the phone
## corridor, whose four doors stand closer together than two signs are wide.
## The heights are fixed; sideways a sign may only be pushed by the frame edge
## or slide past a neighbour, and never so far that it leaves the middle of its
## door (`DEUR_RAND`).  Public for the tests, which hold every sign in every
## room to exactly these heights.
const DEURPLEK := ["deur", "latei", "latei"]
const DEUR_KOSTEN := [0.0, 1000.0, 2000.0]  ## what each height costs the set
const DEUR_GEEN := 1000000.0                 ## no place of the rule at all: the band grid
const DEUR_RAND := 8.0   ## a sign keeps the middle of its door at least this far inside it

static func deurbord_plekken(deur: Rect2, maat: Vector2) -> Array[Rect2]:
	var x := deur.get_center().x - maat.x * 0.5
	var latei := deur.position.y - GAT - maat.y
	return [
		Rect2(Vector2(x, deur.get_center().y - maat.y * 0.5), maat),
		Rect2(Vector2(x, latei), maat),
		Rect2(Vector2(x, latei - maat.y - GAT), maat),
	]

var _deur_keuze: Dictionary = {}   ## door sign id -> {rect, plek}, chosen per pass

## The door signs of the room in view, chosen TOGETHER and before anything
## else is placed (owner, 2026-09-24: the signs have to stand in one consistent
## place, and the trolley, its bubble and the game's buttons give way to them).
## Every sign takes the cheapest height of `deurbord_plekken` — on the opening,
## else over the lintel — such that the set is free of the maths bar, of every
## object box but its own door and of each other; of all sets the cheapest
## wins.  One at a time, the first sign could take the one place its neighbour
## needed: on a phone the corridor's four doors are closer together than two
## signs are wide, and a greedy pass sent one of them onto the band grid.
## A room has at most five doors, and the first all-on-the-door set that fits
## ends the search, so it stays small.
func _kies_deurborden(lijstje: Array[Spot], kader: Rect2) -> void:
	_deur_keuze.clear()
	var borden: Array[Spot] = []
	for s in lijstje:
		if s.zichtbaar and _is_deurbord(s) and s.vlak_nu.size.x > 0.0 and s.vlak_nu.size.y > 0.0:
			borden.append(s)
	if borden.is_empty():
		return
	# left to right: a sign that has to slide steps away from the one before it
	borden.sort_custom(func(a: Spot, b: Spot) -> bool:
		return a.vlak_nu.get_center().x < b.vlak_nu.get_center().x)
	var maten: Array[Vector2] = []
	for s in borden:
		maten.append(_maat_van(s))
	_mijd_balie_nu = false
	var beste := {"kosten": INF, "keuze": []}
	_zoek_deurborden(borden, maten, kader, 0, 0.0, [], beste)
	# the search borrowed `_geplaatst` as its stack; it is empty again here
	var keuze: Array = beste["keuze"]
	for i in mini(borden.size(), keuze.size()):
		var k: Dictionary = keuze[i]
		if not k.is_empty():
			_deur_keuze[borden[i].id] = k

func _zoek_deurborden(borden: Array[Spot], maten: Array[Vector2], kader: Rect2, i: int,
		kosten: float, pad: Array, beste: Dictionary) -> void:
	if kosten >= float(beste["kosten"]):
		return
	if i >= borden.size():
		beste["kosten"] = kosten
		beste["keuze"] = pad.duplicate()
		return
	var deur := borden[i].vlak_nu
	var plekken := deurbord_plekken(deur, maten[i])
	for h in plekken.size():
		var r := _deurbord_op(plekken[h], deur, kader)
		if r.size.x <= 0.0:
			continue
		# a hair per unit of sliding, so the most centred set wins a tie
		var k := kosten + float(DEUR_KOSTEN[h]) + absf(r.get_center().x - deur.get_center().x) * 0.01
		_geplaatst.append(r)
		pad.append({"rect": r, "plek": DEURPLEK[h]})
		_zoek_deurborden(borden, maten, kader, i + 1, k, pad, beste)
		pad.pop_back()
		_geplaatst.pop_back()
	pad.append({})
	_zoek_deurborden(borden, maten, kader, i + 1, kosten + DEUR_GEEN, pad, beste)
	pad.pop_back()

## One height of a door sign made real: inside the frame (which may push it
## sideways, never up or down), free of everything already chosen and of every
## object box but its own door — sliding sideways past a neighbour if it has
## to, as long as the middle of its door stays `DEUR_RAND` inside it.  Empty
## when that height does not fit.
func _deurbord_op(p: Rect2, deur: Rect2, kader: Rect2) -> Rect2:
	var r := _klem(p, kader)
	if absf(r.position.y - p.position.y) > 0.5:
		return Rect2()
	var cx := deur.get_center().x
	var speel := maxf(0.0, r.size.x * 0.5 - DEUR_RAND)
	return _schuif_vrij(r, kader, cx - speel, cx + speel,
		func(q: Rect2) -> bool: return not _botst(q) and _vak_kosten(q, deur) <= 0.0)

## The nearest place along its own row where `r` is free (`vrij`), with its
## middle between `hart_min` and `hart_max` and inside the frame: `r` itself
## when that is free, else `r` slid just past the edge of something that
## shares its row.  Empty when no such place exists.
func _schuif_vrij(r: Rect2, kader: Rect2, hart_min: float, hart_max: float,
		vrij: Callable) -> Rect2:
	var hart := r.get_center().x
	if hart >= hart_min - 0.01 and hart <= hart_max + 0.01 and bool(vrij.call(r)):
		return r
	var randen: Array[Rect2] = []
	randen.append_array(_geplaatst)
	randen.append_array(_balk_muur)
	randen.append_array(_vakken)
	var stappen: Array[float] = []
	for b in randen:
		if b.end.y <= r.position.y or b.position.y >= r.end.y:
			continue
		stappen.append(b.end.x - r.position.x + 0.01)
		stappen.append(b.position.x - r.end.x - 0.01)
	stappen.sort_custom(func(a: float, b: float) -> bool: return absf(a) < absf(b))
	for dx in stappen:
		var q := Rect2(Vector2(r.position.x + dx, r.position.y), r.size)
		if q.position.x < KRAP or q.end.x > kader.size.x - KRAP:
			continue
		var h := q.get_center().x
		if h < hart_min or h > hart_max:
			continue
		if bool(vrij.call(q)):
			return q
	return Rect2()

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
		if s.kind == "kaart" and s.paar and _strook_van.has(s.id):
			var paar := _plaats_kaart_paar(s, _strook_van[s.id], mik, maat, kader)
			if not paar.is_empty():
				return paar
		return _plaats_midden(mik, maat, kader, s.vlak_nu, s.kind == "kaart" or s.kind == "wolk")
	if op == "aan" and _is_deurbord(s):
		# A door carries its sign ON itself, in the middle of the opening
		# (owner, 2026-09-23: "wekker zetten is bijvoorbeeld helemaal niet
		# relevant aan waar de tekst geplaatst is ... Dit gebeurt vaak over het
		# hele spel").  In front of the door is exactly where the furniture
		# stands — the bench in the receptie, the chest in the corridor, the
		# ball pit, the ironing board — and a sign on that read as ITS name.
		# The opening itself is kept clear of furniture (test_rooms: no fixed
		# piece hides more than 3 % of a door), so nothing but the door is ever
		# under the sign.  The floor seen through the door stays visible.
		#
		# And ONLY there, or — when a thing with a button of its own stands in
		# the opening (the trolley pushed up to the door) or a neighbouring
		# door's sign already hangs there — straight over it, just above its
		# lintel.  One place and one fallback, the same for every door in every
		# room (owner, 2026-09-24: "Kamer 2 staat onder de deur maar kamer 1
		# boven de deur. Dit is geen consistente plaats").  The foot of the door
		# and the floor under it are gone as places: they read as the thing
		# standing in front of the door.  The signs of a room are chosen as one
		# set before anything else is placed (`_kies_deurborden`), so every
		# other element gives way to them.
		var keuze: Dictionary = _deur_keuze.get(s.id, {})
		if not keuze.is_empty():
			var r: Rect2 = keuze["rect"]
			if r.size.is_equal_approx(maat) and not _botst(r):
				_reserveer(r, kader)
				return {"rect": r, "op": "aan", "krap": false,
					"gestapeld": str(keuze["plek"]) != "deur", "deurplek": keuze["plek"]}
		# No place of the rule (no room and no screen of the suite gets here):
		# the band grid below keeps the invariants, and the empty `deurplek` in
		# `debug()` says so.
		op = "onder"
	if op == "aan":
		# AT its own thing (owner, 2026-09-14): the thing stays visible, the
		# button sits right under it or right above it, whichever fits; a BIG
		# thing (the notice board, GROOT button areas or more) may carry the
		# button on itself, centred on the aim point.  Anything else placed and
		# every other object box stay clear — otherwise the bands decide.  A
		# door sign has its own two places (above).
		#
		# The notice board carries its button by name, not by arithmetic: it
		# is the thing that rule was written for, and it passed GROOT by a
		# hair (13520 against 12960) until the world's letters grew and the
		# 📋 button with them — then it moved above the board and pushed the
		# first task card 191 units along the wall (owner, 2026-09-23).
		var groot := s.klas.contains("hotbord") \
			or vlak.size.x * vlak.size.y >= GROOT * maat.x * maat.y
		# Centred on the thing as it is DRAWN, not on its aim point: a bowl's
		# plate stands well to the right of its slot point, and "Leeg" hung
		# beside the bowl instead of under it (owner, 2026-09-23).
		var x0 := (vlak.get_center().x if vlak.size.x > 0.0 else mik.x) - maat.x * 0.5
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
		kandidaten.append(Rect2(Vector2(x0, top - GAT - maat.y), maat))
		op_eigen.append(false)
		if vlak.size.y > 0.0:
			# beside it, level with its middle: for a thing with something else
			# right under it and right over it (the key board behind its plant)
			var hart_y := vlak.get_center().y - maat.y * 0.5
			kandidaten.append(Rect2(Vector2(vlak.end.x + GAT, hart_y), maat))
			op_eigen.append(false)
			kandidaten.append(Rect2(Vector2(vlak.position.x - GAT - maat.x, hart_y), maat))
			op_eigen.append(false)
		# The first place that hides nothing of another thing wins; failing
		# that, the one that hides the least (`_vreemd_kosten`).  Before this a
		# button took the first place free of other BUTTONS and landed on the
		# plant in front of the key board, and "Sleutels" read as the plant.
		var beste := Rect2()
		var beste_kosten := INF
		for i in kandidaten.size():
			var r := _klem(kandidaten[i], kader)
			var eigen_mag := op_eigen[i]
			if _botst(r):
				continue
			if _vak_kosten(r, vlak if eigen_mag else Rect2()) > 0.0:
				continue
			if not eigen_mag and _dekking(r, vlak) > 0.0:
				continue
			var kosten := _vreemd_kosten(r, vlak)
			if kosten < beste_kosten:
				beste = r
				beste_kosten = kosten
			if kosten <= 0.0:
				break
		if beste_kosten < INF:
			_reserveer(beste, kader)
			return {"rect": beste, "op": "aan", "krap": false, "gestapeld": false}
		op = "onder"
	if s.kleef_aan != "":
		# its card was placed as a pair: this place is already kept for it
		var gehouden: Rect2 = _strook_plek.get(s.kleef_aan, Rect2())
		if gehouden.size.x > 0.0 and gehouden.size.is_equal_approx(maat):
			return {"rect": gehouden, "op": "kleef", "krap": false, "gestapeld": false}
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
		if s.kind == "naam" and vlak.size.x > 0.0:
			r = _plaat_plek(r, kader, vlak)
		else:
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
	# pass 1c (2026-09-24): the door signs choose first, at their own heights
	# and not on the grid, so a sign that straddles two bands takes both of
	# them in the cell count although it covers only a part of each — on a
	# 558 x 289 kitchen the voerkar's bubble found no block of free cells left.
	# Before giving up, every band once more with the REAL rectangles: the
	# element slides along the band to the nearest place that touches nothing
	# placed and no object box.  Last, so every arrangement that already found
	# a place keeps it.
	var schuif_beste := Rect2()
	var schuif_af := INF
	var schuif_rij := -1
	for k in volgorde:
		var rij: int = k["rij"]
		var y := _band_y(rij, maat, str(k["kant"]), top, voet)
		var r0 := _klem(Rect2(Vector2(mik.x - maat.x * 0.5, y), maat), kader)
		if absf(r0.position.y - y) > 0.5:
			continue
		var zij := _schuif_vrij(r0, kader, -INF, INF,
			func(q: Rect2) -> bool: return not _botst(q) and _vak_kosten(q) <= 0.0)
		if zij.size.x <= 0.0:
			continue
		var af := (zij.get_center() - doel).length()
		if af < schuif_af:
			schuif_beste = zij
			schuif_af = af
			schuif_rij = rij
	if schuif_af < INF:
		_reserveer(schuif_beste, kader)
		return {"rect": schuif_beste, "op": _werd(op, schuif_rij, top, maat), "krap": false,
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
## A card and its answer strip are placed as ONE pair (owner, 2026-09-23: "de
## text van opdrachten staat soms ver van waar ik kan klikken voor
## antwoorden").  A card may float over the room, but its strip may not cover a
## thing — and under the check-in card stands the desk, so the strip fell back
## on the foot of the frame while the card stayed up at the guest, the width of
## the room away.  Now the card takes the first place, in the order the single
## card always chose (`_plaats_midden`), at which its strip fits right beside
## it — under, over, left or right, clear of every placed element and every
## object box.  Where the strip fitted before, nothing moves.  That place of the
## strip is kept for it (`_strook_plek`) and handed over when its turn comes.
## When no such pair fits anywhere, card and strip go down TOGETHER onto the
## foot of the frame, the strip at the bottom and the card straight over it.
## Empty: not even that fits — then the single rules apply.
func _plaats_kaart_paar(s: Spot, strook: Spot, mik: Vector2, maat: Vector2, kader: Rect2) -> Dictionary:
	var ms := _maat_van(strook)
	if ms.x <= 0.0 or ms.y <= 0.0:
		return {}
	var eigen := s.vlak_nu
	# The search tries up to a few hundred rectangles; every frame runs a
	# placement pass, so the pair is kept while its inputs stay the same and
	# both rectangles are still free.
	var sleutel := [mik.round(), maat, ms, kader.size, eigen, _geplaatst.size(),
		_vakken.size(), _kaart_vrij.size()]
	var vorig: Dictionary = _paar_cache.get(s.id, {})
	if not vorig.is_empty() and vorig["sleutel"] == sleutel:
		var kv: Rect2 = vorig["kaart"]
		var sv: Rect2 = vorig["strook"]
		# a guest walks: a box can slide under the kept strip without the
		# count of boxes changing, so the strip is checked against them again
		# (not on the foot, where the pair never asked the boxes)
		var voet := bool(vorig["voet"])
		if not _bezet_voor(kv, Rect2(), true) and not _botst(sv) \
				and (voet or _vak_kosten(sv) <= 0.0):
			return _houd_paar(s, kv, sv, kader, voet)
	# Near its own place first, then further away, and only when no place in
	# the room fits the pair, both on the foot of the frame: the question stays
	# with its guest (the check-in) as long as there is room for its answers.
	# A game that plans card and row itself says `paar: false` (the key board).
	var gevonden := _eerste_paar(_kaart_plekken(mik, maat, kader, eigen), ms, kader, eigen)
	if gevonden.is_empty():
		gevonden = _voet_paar(maat, ms, kader)
	if gevonden.is_empty():
		_paar_cache.erase(s.id)
		return {}
	gevonden["sleutel"] = sleutel
	_paar_cache[s.id] = gevonden
	return _houd_paar(s, gevonden["kaart"], gevonden["strook"], kader, bool(gevonden["voet"]))

func _eerste_paar(kandidaten: Array[Rect2], ms: Vector2, kader: Rect2, eigen: Rect2) -> Dictionary:
	for kr in kandidaten:
		if _bezet_voor(kr, eigen, true):
			continue
		var sr := _strook_bij(kr, ms, kader)
		if sr.size.x > 0.0:
			return {"kaart": kr, "strook": sr, "voet": false}
	return {}

## The strip on the bottom of the frame and the card straight over it.
func _voet_paar(maat: Vector2, ms: Vector2, kader: Rect2) -> Dictionary:
	var sv := _klem(Rect2(Vector2(kader.size.x * 0.5 - ms.x * 0.5,
		kader.size.y - RAND - ms.y), ms), kader)
	var kv := _klem(Rect2(Vector2(kader.size.x * 0.5 - maat.x * 0.5,
		sv.position.y - KLEEF - maat.y), maat), kader)
	if _raakt(kv, sv) or _botst(sv) or _botst(kv):
		return {}
	return {"kaart": kv, "strook": sv, "voet": true}

func _houd_paar(s: Spot, kr: Rect2, sr: Rect2, kader: Rect2, voet: bool) -> Dictionary:
	_reserveer(kr, kader)
	_reserveer(sr, kader)
	_strook_plek[s.id] = sr
	return {"rect": kr, "op": "midden", "krap": false, "gestapeld": voet}

## Where a card may stand, in the order `_plaats_midden` prefers: beside its
## own thing when its aim point lies on that thing (nearest first), on its aim
## point, then whole bands up and down (up first, as `_wijk_omhoog` steps) —
## and after all of those the same places shifted sideways by two and four
## columns, for a strip that needs the room beside a wall.
func _kaart_plekken(mik: Vector2, maat: Vector2, kader: Rect2, eigen: Rect2) -> Array[Rect2]:
	var r0 := _klem(Rect2(mik - maat * 0.5, maat), kader)
	var uit: Array[Rect2] = []
	var heeft_eigen := eigen.size.x > 0.0 and eigen.size.y > 0.0
	if heeft_eigen and _raakt(r0, eigen):
		var hart_y := clampf(mik.y, eigen.position.y + maat.y * 0.5, eigen.end.y - maat.y * 0.5) \
			if eigen.size.y >= maat.y else eigen.get_center().y
		var naast: Array[Rect2] = [
			_klem(Rect2(Vector2(mik.x - maat.x * 0.5, eigen.end.y + GAT), maat), kader),
			_klem(Rect2(Vector2(mik.x - maat.x * 0.5, eigen.position.y - GAT - maat.y), maat), kader),
			_klem(Rect2(Vector2(eigen.end.x + GAT, hart_y - maat.y * 0.5), maat), kader),
			_klem(Rect2(Vector2(eigen.position.x - GAT - maat.x, hart_y - maat.y * 0.5), maat), kader),
		]
		naast.sort_custom(func(a: Rect2, b: Rect2) -> bool:
			return (a.get_center() - mik).length() < (b.get_center() - mik).length())
		uit.append_array(naast)
	var kolom: Array[Rect2] = [r0]
	for stap in range(1, mini(PAAR_BANDEN, maxi(2, int(kader.size.y / RIJ))) + 1):
		for dy in [-stap * RIJ, stap * RIJ]:
			var r := Rect2(Vector2(r0.position.x, r0.position.y + dy), maat)
			if r.position.y >= KRAP and r.end.y <= kader.size.y - KRAP:
				kolom.append(r)
	uit.append_array(kolom)
	for dx in [-2 * KOL, 2 * KOL, -4 * KOL, 4 * KOL]:
		for r in kolom:
			var zij := Rect2(Vector2(r.position.x + dx, r.position.y), maat)
			if zij.position.x >= KRAP and zij.end.x <= kader.size.x - KRAP:
				uit.append(zij)
	return uit

## The strip's place right beside a card, the same four sides and in the same
## order as the glued strip always tried (the `kleef_aan` rule in `_kies_plek`),
## clear of the card, of everything placed and of every object box.  A clamp at
## the frame edge may slide it a little, never off its side of the card.
func _strook_bij(kr: Rect2, ms: Vector2, kader: Rect2) -> Rect2:
	var mx := kr.position.x + kr.size.x * 0.5 - ms.x * 0.5
	var hy := kr.get_center().y - ms.y * 0.5
	var zijden: Array[Rect2] = [
		Rect2(Vector2(mx, kr.end.y + KLEEF), ms),
		Rect2(Vector2(mx, kr.position.y - KLEEF - ms.y), ms),
		Rect2(Vector2(kr.end.x + KLEEF, hy), ms),
		Rect2(Vector2(kr.position.x - KLEEF - ms.x, hy), ms),
		Rect2(Vector2(kr.end.x + KLEEF, kr.position.y), ms),
		Rect2(Vector2(kr.end.x + KLEEF, kr.end.y - ms.y), ms),
		Rect2(Vector2(kr.position.x - KLEEF - ms.x, kr.position.y), ms),
		Rect2(Vector2(kr.position.x - KLEEF - ms.x, kr.end.y - ms.y), ms),
	]
	for z in zijden:
		var r := _klem(z, kader)
		if (r.position - z.position).length() > PAAR_SCHUIF:
			continue
		if _raakt(r, kr) or _botst(r) or _vak_kosten(r) > 0.0:
			continue
		return r
	return Rect2()

func _plaats_midden(mik: Vector2, maat: Vector2, kader: Rect2, eigen: Rect2, mijd_balie := true) -> Dictionary:
	# A fixed card or cloud gives way to the counter as well (V1 finding 4); a
	# game's own plates that HANG on the desk (the key board's hooks) do not, or
	# the row would be torn apart band by band (I2, sleutels).
	var r := _klem(Rect2(mik - maat * 0.5, maat), kader)
	# A card that would lie ON its own thing steps beside it — under it, over
	# it, right or left of it, the nearest free one — instead of climbing whole
	# bands away from it: under a big thing near the top of the frame the band
	# stepping ends a whole screen lower, where the card says nothing about its
	# thing (owner, 2026-09-23: "helemaal niet relevant aan waar de tekst
	# geplaatst is").  Only when it is its OWN thing that is in the way: a card
	# that merely meets another element keeps the old column, which the key
	# board works its hook row out from.
	if eigen.size.x > 0.0 and eigen.size.y > 0.0 and _raakt(r, eigen):
		var naast := _naast_eigen(mik, maat, kader, eigen, mijd_balie)
		if naast.size.x > 0.0:
			_reserveer(naast, kader)
			return {"rect": naast, "op": "midden", "krap": false, "gestapeld": false}
	r = _wijk_omhoog(r, kader, eigen, mijd_balie)
	var krap := _botst(r)
	_reserveer(r, kader)
	return {"rect": r, "op": "midden", "krap": krap, "gestapeld": false}

func _raakt(a: Rect2, b: Rect2) -> bool:
	var snij := a.intersection(b)
	return snij.size.x > 0.001 and snij.size.y > 0.001

## The free place right beside a card's own thing that is nearest to where the
## card wanted to be: under it, over it, to its right or to its left, each with
## GAT of air and inside the frame.  Empty when all four are taken.
func _naast_eigen(mik: Vector2, maat: Vector2, kader: Rect2, eigen: Rect2,
		mijd_balie: bool) -> Rect2:
	var hart_y := clampf(mik.y, eigen.position.y + maat.y * 0.5, eigen.end.y - maat.y * 0.5) \
		if eigen.size.y >= maat.y else eigen.get_center().y
	var plekken: Array[Rect2] = [
		Rect2(Vector2(mik.x - maat.x * 0.5, eigen.end.y + GAT), maat),
		Rect2(Vector2(mik.x - maat.x * 0.5, eigen.position.y - GAT - maat.y), maat),
		Rect2(Vector2(eigen.end.x + GAT, hart_y - maat.y * 0.5), maat),
		Rect2(Vector2(eigen.position.x - GAT - maat.x, hart_y - maat.y * 0.5), maat),
	]
	var beste := Rect2()
	var beste_af := INF
	for p in plekken:
		var r := _klem(p, kader)
		if _raakt(r, eigen) or _bezet_voor(r, eigen, mijd_balie):
			continue
		var af := (r.get_center() - mik).length()
		if af < beste_af:
			beste = r
			beste_af = af
	return beste

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

## A guest's name plate that finds its place taken — since 2026-09-24 by a door
## sign as well, which chooses first and hangs over the head of a guest who
## stands in front of that door — steps the way `_wijk_omhoog` does, whole bands
## up and down, but on every band it first slides sideways along it, as long as
## it stays over its own guest.  A plate a few units beside its place is still
## that guest's name; one a band higher, over the next guest, is not.
func _plaat_plek(r: Rect2, kader: Rect2, gast: Rect2) -> Rect2:
	var zij := _plaat_rij(r, kader, gast)
	if zij.size.x > 0.0:
		return zij
	for stap in range(1, maxi(2, int(kader.size.y / RIJ)) + 1):
		for dy in [-stap * RIJ, stap * RIJ]:
			var q := Rect2(Vector2(r.position.x, r.position.y + dy), r.size)
			if q.position.y < KRAP or q.end.y > kader.size.y - KRAP:
				continue
			zij = _plaat_rij(q, kader, gast)
			if zij.size.x > 0.0:
				return zij
	return _wijk_omhoog(r, kader)

## A plate on one row: where it is when that is free, else slid along the row.
func _plaat_rij(q: Rect2, kader: Rect2, gast: Rect2) -> Rect2:
	if not _botst(q):
		return q
	return _schuif_vrij(q, kader, gast.position.x, gast.end.x,
		func(p: Rect2) -> bool: return not _botst(p))

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

## The boxes of every THING in the room in view — fixed decor, slots, the
## movable things, loose decor and the guests — whether it has a button or not.
## `_vakken` only knows the things that carry a button; this is what a button
## hanging ON its thing looks at, so that it does not stand on the thing next
## to it instead.
var _dingen_vak: Array[Rect2] = []

func _verzamel_dingen(kamer: String) -> void:
	_dingen_vak.clear()
	var bronnen: Array = []
	var r := Rooms.get_kamer(kamer)
	if r != null:
		bronnen.append_array(r.decor)
		bronnen.append_array(r.slots.values())
	bronnen.append_array(World.dingen(kamer))
	bronnen.append_array(World.decor_lijst(kamer))
	for stuk in bronnen:
		if not _bruikbaar(stuk):
			continue
		var v := World.vlak_van(str(stuk.get("model", stuk.get("n", ""))),
			float(stuk.get("x", 0.0)), float(stuk.get("z", 0.0)),
			float(stuk.get("hoog", stuk.get("y", 0.0))), stuk.get("params", {}),
			Vector2.ZERO, int(stuk.get("rot", 0)))
		if v.size.x > 0.0 and v.size.y > 0.0:
			_dingen_vak.append(v)
	for d in World.dieren(kamer):
		var v := World.vlak_van_dier(d.id)
		if v.size.x > 0.0 and v.size.y > 0.0:
			_dingen_vak.append(v)

## A button may lie over a small part of something big — the front of the desk
## under the bell, the ball pit's rim — without anybody reading it as that
## thing's name.  From this share of a thing on, it does.
const VREEMD_DEEL := 0.15

## How much of OTHER things this rectangle hides: the sum of the shares it
## covers of every thing that is not `eigen`, counting only a share of at least
## VREEMD_DEEL.  0 = it stands on nothing but its own thing and the floor.
##
## A door sign never asks: on its own door it is that door's sign, whatever
## stands next to the opening (the fence posts round the pool gate, the rose
## arch), and its one fallback over the lintel is the same for every door.
func _vreemd_kosten(r: Rect2, eigen: Rect2) -> float:
	var som := 0.0
	for v in _dingen_vak:
		if eigen.size.x > 0.0 and v.is_equal_approx(eigen):
			continue
		var snij := r.intersection(v)
		if snij.size.x <= 0.0 or snij.size.y <= 0.0:
			continue
		var deel := (snij.size.x * snij.size.y) / maxf(1.0, v.size.x * v.size.y)
		if deel >= VREEMD_DEEL:
			som += deel
	return som

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
