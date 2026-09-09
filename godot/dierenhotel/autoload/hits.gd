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
const KRAP := 2             ## the hard frame edge: nothing goes past it
const KLEEF := 5            ## css-px between a card and its choice strip

enum Laag {VAST = 0, SPEL = 1, HOTEL = 2, WENS = 3}

signal hotspot_getikt(id: String)

var _spots: Dictionary = {}        ## id -> Spot
var _volgorde: Array[String] = []  ## insertion order
var _voorrang: String = ""         ## the game that picks its places first
var _bezet: Dictionary = {}        ## "rij|kol" -> true, rebuilt every placement
var _vakken: Array[Rect2] = []     ## object boxes in view; a button avoids all of them
var _laatste: Dictionary = {}      ## id -> {rect, vlak, dekking, op, laag, prio, krap}

class Spot extends RefCounted:
	var id: String
	var kamer: String
	var x: float
	var z: float
	var y: float
	var vlak: Rect2 = Rect2()      ## the object's own screen rect, if known
	var maat: Vector2 = Vector2.ZERO   ## explicit minimum size (0 = ask the Control)
	var kleef_aan: String = ""     ## glue my top edge under the rect of this id
	var kind: String = "btn"       ## btn | drop | tag
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
	s.maat = o.get("maat", Vector2.ZERO)
	s.kleef_aan = o.get("kleef_aan", "")
	s.knoop = Ui.maak_knop(s.kind, o)
	if s.knoop is BaseButton and s.aan.is_valid():
		(s.knoop as BaseButton).pressed.connect(func():
			Snd.tik()
			hotspot_getikt.emit(s.id)
			s.aan.call(s))
	Ui.knoplaag.add_child(s.knoop)
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
	_spots.erase(id)
	_volgorde.erase(id)
	_laatste.erase(id)

func wis_eigenaar(door: String) -> void:
	for id in _volgorde.duplicate():
		var s: Spot = _spots[id]
		if s.door == door:
			weg(id)

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
	_bezet.clear()
	_vakken.clear()
	var lijstje: Array[Spot] = []
	for id in _volgorde:
		var s: Spot = _spots[id]
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
		if s.zichtbaar:
			lijstje.append(s)
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
		return _diepte(a) > _diepte(b))
	for i in lijstje.size():
		if i >= MAX_PER_KAMER:
			lijstje[i].zichtbaar = false
	# every object still in view is a box that a button must stay off
	for s in lijstje:
		if s.zichtbaar and s.vlak.size.x > 0.0 and s.vlak.size.y > 0.0:
			_vakken.append(s.vlak)
	# place front-most first inside each layer
	var rijen := maxi(1, int((kader.size.y - 2 * RAND) / RIJ))
	var kolommen := maxi(1, int((kader.size.x - 2 * RAND) / KOL))
	for s in lijstje:
		if not s.zichtbaar:
			s.knoop.visible = false
			_laatste.erase(s.id)
			continue
		s.knoop.visible = true
		var maat := _maat_van(s)
		var mik := World.mik_punt(s.x, s.z, s.y)
		var uit := _kies_plek(s, mik, maat, kader, rijen, kolommen)
		var rect: Rect2 = uit["rect"]
		s.knoop.custom_minimum_size = maat
		s.knoop.size = maat
		s.knoop.position = rect.position
		_laatste[s.id] = {
			"id": s.id, "op": uit["op"], "laag": s.laag, "prio": s.prio,
			"rect": rect, "vlak": s.vlak, "krap": uit["krap"],
			"dekking": _dekking(rect, s.vlak),
		}

## A tap target is at least 48 x 48; a number tag keeps its natural size.
func _maat_van(s: Spot) -> Vector2:
	var maat := s.knoop.get_combined_minimum_size()
	if s.maat.x > 0.0:
		maat.x = maxf(maat.x, s.maat.x)
	if s.maat.y > 0.0:
		maat.y = maxf(maat.y, s.maat.y)
	if s.kind != "tag":
		maat.x = maxf(maat.x, 48.0)
		maat.y = maxf(maat.y, 48.0)
	return maat

func _laag_van(s: Spot) -> int:
	if s.vast or s.kind == "tag":
		return Laag.VAST
	if _voorrang != "" and s.door == _voorrang:
		return Laag.SPEL
	if s.klas.contains("hotwens"):
		return Laag.WENS
	return Laag.HOTEL

func _diepte(s: Spot) -> float:
	return s.d if not is_nan(s.d) else s.x + s.z

func _op_van(s: Spot) -> String:
	if s.kleef_aan != "":
		return "kleef"
	if s.op != "auto":
		return s.op
	if s.kind == "tag":
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
	var vlak := s.vlak
	var top := vlak.position.y if vlak.size.y > 0.0 else mik.y - s.y * World.px_per_hoogte()
	var voet := vlak.end.y if vlak.size.y > 0.0 else mik.y
	if op == "midden":
		var r := _klem(Rect2(mik - maat * 0.5, maat), kader)
		_reserveer(r, kader)
		return {"rect": r, "op": op, "krap": false}
	if s.kleef_aan != "":
		var aan: Dictionary = _laatste.get(s.kleef_aan, {})
		if not aan.is_empty():
			var kr: Rect2 = aan["rect"]
			var mx := kr.position.x + kr.size.x * 0.5 - maat.x * 0.5
			var r := _klem(Rect2(Vector2(mx, kr.end.y + KLEEF), maat), kader)
			if r.intersects(kr):        # no room under it: glue it above instead
				r = _klem(Rect2(Vector2(mx, kr.position.y - KLEEF - maat.y), maat), kader)
			_reserveer(r, kader)
			return {"rect": r, "op": "kleef", "krap": r.intersects(kr)}
		op = "midden"
	if op == "rand":
		var y := top - maat.y + minf(maat.y, vlak.size.y * TAG_IN)
		var r := _klem(Rect2(Vector2(mik.x - maat.x * 0.5, y), maat), kader)
		_reserveer(r, kader)
		return {"rect": r, "op": op, "krap": false}
	var volgorde := _bandvolgorde(op, top, voet, maat, rijen)
	# pass 1: a cell that is free AND touches no object
	for rij in volgorde:
		var kand := _zoek_cel(rij, mik.x, maat, kolommen, rijen, false)
		if kand["rect"].size.x > 0.0:
			_reserveer(kand["rect"], kader)
			return {"rect": kand["rect"], "op": _werd(op, rij, top, maat), "krap": false}
	# pass 2: a free cell with the least object overlap
	var beste := Rect2()
	var beste_kosten := INF
	var beste_rij := -1
	for rij in volgorde:
		var kand := _zoek_cel(rij, mik.x, maat, kolommen, rijen, true)
		if kand["rect"].size.x > 0.0 and kand["kosten"] < beste_kosten:
			beste = kand["rect"]
			beste_kosten = kand["kosten"]
			beste_rij = rij
	if beste_kosten < INF:
		_reserveer(beste, kader)
		return {"rect": beste, "op": _werd(op, beste_rij, top, maat), "krap": true}
	# nothing free in the whole frame: the aim point, clamped, and flagged
	var laatste := _klem(Rect2(mik - maat * 0.5, maat), kader)
	_reserveer(laatste, kader)
	return {"rect": laatste, "op": op, "krap": true}

## What the anchor became, for Hits.debug() — `boven` may silently become `onder`.
func _werd(op: String, rij: int, top: float, maat: Vector2) -> String:
	if op != "boven":
		return op
	return "boven" if RAND + (rij + _rij_hoog(maat)) * RIJ <= top - GAT else "onder"

## Bands in order of preference: the side asked for (closest to the object
## first), then the other side, then every remaining band from the top down.
func _bandvolgorde(op: String, top: float, voet: float, maat: Vector2, rijen: int) -> Array[int]:
	var hoog := _rij_hoog(maat)
	var boven: Array[int] = []
	for r in range(rijen - hoog, -1, -1):
		if RAND + (r + hoog) * RIJ <= top - GAT:
			boven.append(r)
	var onder: Array[int] = []
	for r in range(0, rijen - hoog + 1):
		if RAND + r * RIJ >= voet + GAT:
			onder.append(r)
	var uit: Array[int] = []
	if op == "onder":
		uit.append_array(onder)
		uit.append_array(boven)
	else:
		uit.append_array(boven)
		uit.append_array(onder)
	for r in range(0, rijen - hoog + 1):
		if not uit.has(r):
			uit.append(r)
	return uit

func _rij_hoog(maat: Vector2) -> int:
	return maxi(1, ceili(maat.y / float(RIJ)))

## Nearest free column block in this band, searched outward from the aim point.
## Returns {rect, kosten}; an empty rect means "nothing free here".
func _zoek_cel(rij: int, wens_x: float, maat: Vector2, kolommen: int, rijen: int, sta_vak_toe: bool) -> Dictionary:
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
			var r := _cel(rij, k, maat)
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
func _vak_kosten(r: Rect2) -> float:
	var som := 0.0
	for v in _vakken:
		var snij := r.intersection(v)
		if snij.size.x > 0.0 and snij.size.y > 0.0:
			som += snij.size.x * snij.size.y
	return som

## A placed rectangle blocks every cell it touches — cards and clamped
## placements included.  That is the invariant the review found missing.
func _reserveer(r: Rect2, kader: Rect2) -> void:
	var rijen := maxi(1, int((kader.size.y - 2 * RAND) / RIJ))
	var kolommen := maxi(1, int((kader.size.x - 2 * RAND) / KOL))
	var k0 := int(floor((r.position.x - RAND) / KOL))
	var k1 := int(floor((r.end.x - 0.001 - RAND) / KOL))
	var r0 := int(floor((r.position.y - RAND) / RIJ))
	var r1 := int(floor((r.end.y - 0.001 - RAND) / RIJ))
	for rr in range(maxi(0, r0), mini(rijen - 1, r1) + 1):
		for kk in range(maxi(0, k0), mini(kolommen - 1, k1) + 1):
			_bezet["%d|%d" % [rr, kk]] = true

## The rectangle of one cell block.  Inside the frame by construction.
func _cel(rij: int, kol: int, maat: Vector2) -> Rect2:
	var breed := maxi(1, ceili(maat.x / float(KOL)))
	var hoog := _rij_hoog(maat)
	var x := RAND + kol * KOL + (breed * KOL - maat.x) * 0.5
	var y := RAND + rij * RIJ + (hoog * RIJ - maat.y) * 0.5
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
