class_name WereldLooppad
extends RefCounted
## The way round things (owner, 2026-09-24: "Dieren lopen ook vaak door objecten
## heen als ze naar andere maps toe lopen en ik ze volg").  A guest used to walk
## a straight line from where he stood to the door, through the room to the
## next door and on to his bed or bowl — straight through beds, the desk,
## plants, stalls and the food trolley.  Only the pool was walked round
## (`Rooms.om_het_water`).  This is the walking grid of ONE room as it stands
## right now, and the way across it.
##
## The grid is built from what actually stands on the floor (`World`
## `_hindernissen`: the room's fixed decor and slots, bought furniture, the two
## movable things and a game's loose decor, the water and the strip behind the
## desk) — never from a list of its own, so a bed bought a minute ago, the
## trolley that was pushed into kamer 2 and the stall a game put down are all
## in it.  `World` keeps one grid per room and builds a new one the moment
## that list changes.
##
## Three layers, each coarser than the last:
##   * the voxel columns a piece occupies (1 voxel): every column with a voxel
##     between VLOER and KOP over the floor.  Flat things (mats, hopscotch
##     stones, a threshold) lie under a guest's paws and do not count; what
##     hangs over his back (a garland, a tree's crown, a parasol, the bar over
##     a gate) does not either.
##   * the class of every CEL x CEL cell, from the columns around its middle:
##     DICHT (a column within HARD — a guest's body would be in it), KRAP
##     (within RUIM, or against the edge of the room: allowed, but only when
##     there is no roomier way) or OPEN.
##   * A* over KNOOP x KNOOP nodes (2 x 2 cells, the worst class of the four),
##     eight neighbours, costs W_OPEN / W_KRAP / W_DICHT per voxel walked.
##     DICHT is expensive, never forbidden: a goal INSIDE a piece (the bed's
##     own point, a spot in the doorway of a gate) is still reached, by the
##     shortest way in, and a guest who stands inside something walks out.
## The node path is then pulled straight (string pulling): a corner is dropped
## whenever the straight line past it runs no deeper into DICHT cells than the
## part of the path it replaces and costs at most GLAD times as much, checked
## every half voxel on the cells.  So the guest walks natural diagonals, not
## stair steps, and never closer to a piece than the node path already went.
##
## A point in a cell that is not DICHT lies at least 2.5 voxels from every
## blocked column, so a walk between two free points never enters a footprint.

const CEL := 2            ## voxels per cell of the class grid
const KNOOP := 4          ## voxels per A* node (2 x 2 cells)
const VLOER := 2          ## a voxel lower than this over the floor is flat on it
const KOP := 12           ## ... and one higher than this is over a guest's back
const HARD := 3           ## a column this close to a cell's middle: DICHT
const RUIM := 6           ## ... this close: KRAP
const RAND := 4           ## the edge of the room is KRAP this far in
const OPEN := 0
const KRAP := 1
const DICHT := 2
const W_OPEN := 1.0
const W_KRAP := 1.5
const W_DICHT := 200.0
const STAP := 0.5         ## sample distance along a line, in voxels
const GLAD := 1.25        ## a straighter line may cost this much more (never more DICHT)
const KOLOM_MAX := 256    ## model footprints kept in the cache

## model|params|rot|height -> PackedInt32Array [x, z, x, z, ...]: the blocked
## columns of one model, relative to its own origin.  Shared by every room.
static var _kolom_cache: Dictionary = {}

var w := 1
var d := 1
var _bezet := PackedByteArray()   ## w * d voxel columns, 1 = something stands there
var _som := PackedInt32Array()    ## (w + 1) * (d + 1) summed-area table of `_bezet`
var cw := 1                       ## cells along x
var cd := 1                       ## cells along z
var _klasse := PackedByteArray()  ## cw * cd: OPEN, KRAP or DICHT
var kw := 1                       ## nodes along x
var kd := 1                       ## nodes along z
var _gewicht := PackedFloat32Array()   ## kw * kd: the node's cost per voxel
var _midden := PackedVector2Array()    ## kw * kd: the node's middle
var _deel := PackedInt32Array()        ## kw * kd: connected part, -1 = DICHT
var sleutel := ""                 ## what the grid was built from (World's cache key)
## the search's own scratch space, reused from walk to walk
var _g := PackedFloat32Array()
var _vorig := PackedInt32Array()
var _af := PackedByteArray()
var _hoop_f := PackedFloat32Array()
var _hoop_i := PackedInt32Array()

# ------------------------------------------------------------------ bouwen

## The blocked columns of a model: every (x, z) with a voxel between VLOER and
## KOP over the floor once the piece stands at height `hoog`, after `rot`
## quarter turns (the rotation `World._roteer` draws with).
static func kolommen(model: String, params: Dictionary = {}, rot: int = 0,
		hoog: float = 0.0) -> PackedInt32Array:
	if not Art.heeft_model(model):
		return PackedInt32Array()          # not (yet) registered: nothing, and not cached
	var y0 := int(roundf(hoog))
	var sleutel_k := "%s|%s|%d|%d" % [model, JSON.stringify(params), posmod(rot, 4), y0]
	if _kolom_cache.has(sleutel_k):
		return _kolom_cache[sleutel_k]
	var gezien := {}
	var uit := PackedInt32Array()
	for v in Art.model(model, params):
		var h := int(v["y"]) + y0
		if h < VLOER or h > KOP:
			continue
		var x := int(v["x"])
		var z := int(v["z"])
		for _ronde in posmod(rot, 4):
			var t := x
			x = z
			z = -t
		var k := Vector2i(x, z)
		if gezien.has(k):
			continue
		gezien[k] = true
		uit.append(x)
		uit.append(z)
	if _kolom_cache.size() >= KOLOM_MAX:
		_kolom_cache.clear()
	_kolom_cache[sleutel_k] = uit
	return uit

## Build the grid of a room `breed` x `diep` voxels from its pieces:
##   {kolommen: PackedInt32Array, x, z, ax, az}  columns relative to (x − ax, z − az)
##   {x0, x1, z0, z1}                             a blocked floor rectangle (water)
static func bouw(breed: int, diep: int, stukken: Array) -> WereldLooppad:
	var g := WereldLooppad.new()
	g.w = maxi(1, breed)
	g.d = maxi(1, diep)
	g._bezet.resize(g.w * g.d)
	g._bezet.fill(0)
	for s in stukken:
		var stuk: Dictionary = s
		if stuk.has("kolommen"):
			var kol: PackedInt32Array = stuk["kolommen"]
			var ox := float(stuk.get("x", 0.0)) - float(stuk.get("ax", 0.0))
			var oz := float(stuk.get("z", 0.0)) - float(stuk.get("az", 0.0))
			var i := 0
			while i + 1 < kol.size():
				g._zet(int(floorf(ox + kol[i] + 0.5)), int(floorf(oz + kol[i + 1] + 0.5)))
				i += 2
		elif stuk.has("x0"):
			for z in range(int(ceilf(float(stuk["z0"]))), int(floorf(float(stuk["z1"]))) + 1):
				for x in range(int(ceilf(float(stuk["x0"]))), int(floorf(float(stuk["x1"]))) + 1):
					g._zet(x, z)
	g._bouw_som()
	g._bouw_klassen()
	g._bouw_knopen()
	return g

func _zet(x: int, z: int) -> void:
	if x >= 0 and z >= 0 and x < w and z < d:
		_bezet[z * w + x] = 1

func _bouw_som() -> void:
	var b := w + 1
	_som.resize(b * (d + 1))
	_som.fill(0)
	for z in d:
		var rij := 0
		for x in w:
			rij += _bezet[z * w + x]
			_som[(z + 1) * b + x + 1] = _som[z * b + x + 1] + rij

## How many blocked columns lie in [x0, x1] x [z0, z1] (inclusive, clipped).
func _in_vak(x0: int, x1: int, z0: int, z1: int) -> int:
	x0 = maxi(x0, 0)
	z0 = maxi(z0, 0)
	x1 = mini(x1, w - 1)
	z1 = mini(z1, d - 1)
	if x0 > x1 or z0 > z1:
		return 0
	var b := w + 1
	return _som[(z1 + 1) * b + x1 + 1] - _som[z0 * b + x1 + 1] \
		- _som[(z1 + 1) * b + x0] + _som[z0 * b + x0]

func _bouw_klassen() -> void:
	cw = maxi(1, ceili(float(w) / CEL))
	cd = maxi(1, ceili(float(d) / CEL))
	_klasse.resize(cw * cd)
	for j in cd:
		var mz := j * CEL + CEL / 2
		for i in cw:
			var mx := i * CEL + CEL / 2
			var k := OPEN
			if _in_vak(mx - HARD, mx + HARD, mz - HARD, mz + HARD) > 0:
				k = DICHT
			elif _in_vak(mx - RUIM, mx + RUIM, mz - RUIM, mz + RUIM) > 0 \
					or mx < RAND or mz < RAND or mx > w - RAND or mz > d - RAND:
				k = KRAP
			_klasse[j * cw + i] = k

func _bouw_knopen() -> void:
	kw = maxi(1, ceili(float(cw) / 2.0))
	kd = maxi(1, ceili(float(cd) / 2.0))
	_gewicht.resize(kw * kd)
	_midden.resize(kw * kd)
	_deel.resize(kw * kd)
	for v in kd:
		for u in kw:
			var slechtst := OPEN
			var som := Vector2.ZERO
			var n := 0
			for dj in 2:
				for di in 2:
					var i := u * 2 + di
					var j := v * 2 + dj
					if i >= cw or j >= cd:
						continue
					slechtst = maxi(slechtst, _klasse[j * cw + i])
					som += Vector2(minf(i * CEL + CEL * 0.5, w), minf(j * CEL + CEL * 0.5, d))
					n += 1
			var idx := v * kw + u
			_gewicht[idx] = _w(slechtst)
			_midden[idx] = som / maxf(1.0, float(n))
			_deel[idx] = -1
	# the connected parts of the floor a guest can reach without squeezing
	# through anything: 8-neighbour flood fill over the nodes that are not DICHT
	var nr := 0
	for start in kw * kd:
		if _deel[start] != -1 or _gewicht[start] >= W_DICHT:
			continue
		var rij := PackedInt32Array([start])
		_deel[start] = nr
		var kop := 0
		while kop < rij.size():
			var n := rij[kop]
			kop += 1
			var u := n % kw
			var v := n / kw
			for dv in range(-1, 2):
				for du in range(-1, 2):
					var nu: int = u + du
					var nv: int = v + dv
					if nu < 0 or nv < 0 or nu >= kw or nv >= kd:
						continue
					var m := nv * kw + nu
					if _deel[m] == -1 and _gewicht[m] < W_DICHT:
						_deel[m] = nr
						rij.append(m)
		nr += 1

static func _w(klasse: int) -> float:
	return W_DICHT if klasse == DICHT else (W_KRAP if klasse == KRAP else W_OPEN)

# ------------------------------------------------------------------ vragen

## The class of the cell a floor point lies in; KRAP outside the room.
func klasse(p: Vector2) -> int:
	var i := int(floorf(p.x / CEL))
	var j := int(floorf(p.y / CEL))
	if i < 0 or j < 0 or i >= cw or j >= cd:
		return KRAP
	return _klasse[j * cw + i]

## Is there something standing on this voxel column?  (x, z) rounded.
func bezet(x: float, z: float) -> bool:
	var ix := int(floorf(x + 0.5))
	var iz := int(floorf(z + 0.5))
	return ix >= 0 and iz >= 0 and ix < w and iz < d and _bezet[iz * w + ix] == 1

## A guest can stand here: the point is not DICHT.
func vrij(p: Vector2) -> bool:
	return klasse(p) != DICHT

func _knoop(p: Vector2) -> int:
	var u := clampi(int(floorf(p.x / KNOOP)), 0, kw - 1)
	var v := clampi(int(floorf(p.y / KNOOP)), 0, kd - 1)
	return v * kw + u

## The connected parts this point touches: its own node's, or — when that node
## is DICHT (he stands in something: the customer's spot at the stall's counter,
## a mattress) — the parts of the nearest ring of nodes around it that has any,
## because that is where he walks out to.
func _delen(p: Vector2) -> Dictionary:
	var uit := {}
	var n := _knoop(p)
	if _deel[n] >= 0:
		uit[_deel[n]] = true
		return uit
	var u := n % kw
	var v := n / kw
	for r in range(1, maxi(kw, kd)):
		for dv in range(-r, r + 1):
			for du in range(-r, r + 1):
				if maxi(absi(du), absi(dv)) != r:
					continue
				var nu: int = u + du
				var nv: int = v + dv
				if nu >= 0 and nv >= 0 and nu < kw and nv < kd and _deel[nv * kw + nu] >= 0:
					uit[_deel[nv * kw + nu]] = true
		if not uit.is_empty():
			break
	return uit

## Can a guest walk from `a` to `b` without squeezing through anything?
func bereikbaar(a: Vector2, b: Vector2) -> bool:
	var da := _delen(a)
	for k in _delen(b):
		if da.has(k):
			return true
	return false

## What walking the straight line a–b costs: x = the cost (voxels times the
## class weight), y = the voxels of it in DICHT cells.  Sampled every STAP.
func kosten(a: Vector2, b: Vector2) -> Vector2:
	var lengte := a.distance_to(b)
	if lengte < 0.0001:
		return Vector2.ZERO
	var n := maxi(1, ceili(lengte / STAP))
	var stuk := lengte / n
	# the sample points in cell units, stepped (the hot loop of the search)
	var px := a.x / CEL
	var pz := a.y / CEL
	var sx := (b.x - a.x) / CEL / n
	var sz := (b.y - a.y) / CEL / n
	px += sx * 0.5
	pz += sz * 0.5
	var open := 0
	var krap := 0
	var dicht := 0
	for _i in n:
		var i := int(floorf(px))
		var j := int(floorf(pz))
		var k := KRAP
		if i >= 0 and j >= 0 and i < cw and j < cd:
			k = _klasse[j * cw + i]
		if k == OPEN:
			open += 1
		elif k == KRAP:
			krap += 1
		else:
			dicht += 1
		px += sx
		pz += sz
	return Vector2((open * W_OPEN + krap * W_KRAP + dicht * W_DICHT) * stuk, dicht * stuk)

# ------------------------------------------------------------------ de weg

## The walk from `van` to `naar`: the points AFTER `van`, the last one exactly
## `naar`.  A straight line that only crosses OPEN cells is kept as it is.
## [] when no way was found (never, on a grid of finite costs).
func pad(van: Vector2, naar: Vector2) -> Array:
	if van.distance_to(naar) < 0.01:
		return [naar]
	var recht := kosten(van, naar)
	if recht.x <= van.distance_to(naar) * W_OPEN + 0.001:
		return [naar]
	var ruw := _zoek(van, naar)
	if ruw.size() < 2:
		return []                          # nothing found: the caller's old walk
	var glad := _trek_strak(ruw)
	# the straight line after all, when it is no worse than the way found
	var weg := _kosten_van(glad)
	if recht.y <= weg.y + 0.01 and recht.x <= weg.x * GLAD + 0.01:
		return [naar]
	glad.remove_at(0)
	glad[glad.size() - 1] = naar
	return glad

func _kosten_van(punten: Array) -> Vector2:
	var som := Vector2.ZERO
	for i in range(1, punten.size()):
		som += kosten(punten[i - 1], punten[i])
	return som

## A* from `van` to `naar` over the nodes.  The node `van` stands in and the
## node of `naar` are not walked through their middles: the first leg runs from
## `van` itself to a neighbour's middle and the last from a neighbour's middle
## to `naar`, both costed on the cells (`kosten`).  Returns [van, middles...,
## naar], or [] when nothing is found.
func _zoek(van: Vector2, naar: Vector2) -> Array:
	var s := _knoop(van)
	var t := _knoop(naar)
	if s == t:
		return [van, naar]
	var n := kw * kd
	var doel := n                         ## the virtual node "arrived at naar"
	_g.resize(n + 1)
	_g.fill(INF)
	_vorig.resize(n + 1)
	_vorig.fill(-1)
	_af.resize(n + 1)
	_af.fill(0)
	_hoop_f.clear()
	_hoop_i.clear()
	_af[s] = 1
	var tu := t % kw
	var tv := t / kw
	var su := s % kw
	var sv := s / kw
	# the first leg: from `van` to the middle of every neighbour of its node
	for dv in range(-1, 2):
		for du in range(-1, 2):
			var mu := su + du
			var mv := sv + dv
			if (du == 0 and dv == 0) or mu < 0 or mv < 0 or mu >= kw or mv >= kd:
				continue
			var m := mv * kw + mu
			if m == t:
				var c_recht: float = kosten(van, naar).x
				if c_recht < _g[doel]:
					_g[doel] = c_recht
					_vorig[doel] = s
					_duw(c_recht, doel)
				continue
			var c: float = kosten(van, _midden[m]).x
			if c < _g[m]:
				_g[m] = c
				_vorig[m] = s
				_duw(c + _midden[m].distance_to(naar) * W_OPEN, m)
	while not _hoop_i.is_empty():
		var nu := _pak()
		if nu == doel:
			break
		if _af[nu] == 1:
			continue
		_af[nu] = 1
		var mid: Vector2 = _midden[nu]
		var g_nu: float = _g[nu]
		var w_nu: float = _gewicht[nu]
		var u := nu % kw
		var v := nu / kw
		if absi(u - tu) <= 1 and absi(v - tv) <= 1:
			# a neighbour of the goal's node: the last leg, straight to `naar`
			var c_doel: float = g_nu + kosten(mid, naar).x
			if c_doel < _g[doel]:
				_g[doel] = c_doel
				_vorig[doel] = nu
				_duw(c_doel, doel)
		for dv in range(-1, 2):
			var mv := v + dv
			if mv < 0 or mv >= kd:
				continue
			for du in range(-1, 2):
				var mu := u + du
				if (du == 0 and dv == 0) or mu < 0 or mu >= kw:
					continue
				var m := mv * kw + mu
				if m == t or _af[m] == 1:
					continue
				var stap := 1.4142136 if du != 0 and dv != 0 else 1.0
				var c: float = g_nu + stap * KNOOP * (w_nu + _gewicht[m]) * 0.5
				if c < _g[m]:
					_g[m] = c
					_vorig[m] = nu
					_duw(c + _midden[m].distance_to(naar) * W_OPEN, m)
	if _vorig[doel] == -1:
		return []
	var uit: Array = [naar]
	var k := _vorig[doel]
	while k != s and k != -1:
		uit.push_front(_midden[k])
		k = _vorig[k]
	uit.push_front(van)
	return uit

## String pulling: from every corner kept, straight on to the FARTHEST corner of
## the path whose straight line runs no further through DICHT cells than the
## path it cuts off, and costs at most GLAD times as much — a little margin
## (KRAP) is worth a natural line, a piece of furniture never is.
func _trek_strak(ruw: Array) -> Array:
	# only the corners: a middle point on a straight run changes nothing
	var p: Array = [ruw[0]]
	for i in range(1, ruw.size() - 1):
		var a: Vector2 = p[p.size() - 1]
		var b: Vector2 = ruw[i]
		var c: Vector2 = ruw[i + 1]
		if absf((b - a).cross(c - b)) > 0.001 or (b - a).dot(c - b) <= 0.0:
			p.append(b)
	p.append(ruw[ruw.size() - 1])
	var som := PackedFloat32Array([0.0])
	var som_dicht := PackedFloat32Array([0.0])
	for i in range(1, p.size()):
		var k := kosten(p[i - 1], p[i])
		som.append(som[i - 1] + k.x)
		som_dicht.append(som_dicht[i - 1] + k.y)
	var uit: Array = [p[0]]
	var i := 0
	while i < p.size() - 1:
		var beste := i + 1
		var j := p.size() - 1
		while j > i + 1:
			var k := kosten(p[i], p[j])
			if k.y <= som_dicht[j] - som_dicht[i] + 0.01 and k.x <= (som[j] - som[i]) * GLAD + 0.01:
				beste = j
				break
			j -= 1
		uit.append(p[beste])
		i = beste
	return uit

# ---------------------------------------------------------------- een hoop
##
## The open list of the search: a binary heap in two packed arrays, members of
## the grid because a packed array handed to a function is a copy.

func _duw(waarde: float, n: int) -> void:
	_hoop_f.append(waarde)
	_hoop_i.append(n)
	var i := _hoop_f.size() - 1
	while i > 0:
		var ouder := (i - 1) / 2
		if _hoop_f[ouder] <= _hoop_f[i]:
			break
		var tf := _hoop_f[ouder]
		_hoop_f[ouder] = _hoop_f[i]
		_hoop_f[i] = tf
		var ti := _hoop_i[ouder]
		_hoop_i[ouder] = _hoop_i[i]
		_hoop_i[i] = ti
		i = ouder

func _pak() -> int:
	var uit := _hoop_i[0]
	var laatst := _hoop_f.size() - 1
	_hoop_f[0] = _hoop_f[laatst]
	_hoop_i[0] = _hoop_i[laatst]
	_hoop_f.resize(laatst)
	_hoop_i.resize(laatst)
	var i := 0
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var klein := i
		if l < laatst and _hoop_f[l] < _hoop_f[klein]:
			klein = l
		if r < laatst and _hoop_f[r] < _hoop_f[klein]:
			klein = r
		if klein == i:
			break
		var tf := _hoop_f[klein]
		_hoop_f[klein] = _hoop_f[i]
		_hoop_f[i] = tf
		var ti := _hoop_i[klein]
		_hoop_i[klein] = _hoop_i[i]
		_hoop_i[i] = ti
		i = klein
	return uit
