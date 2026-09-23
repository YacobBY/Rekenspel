class_name SpelCtx
extends RefCounted
## The one object a minigame is given.  Everything it places through this ctx
## is owned by the game and disappears when the game stops — that is what makes
## "supersede = full stop" free (world.md §5.2, §5.3).

var id: String
var naam: String
var kamer: String
var wereld: Node          ## World
var state: Node           ## State
var econ: Node            ## Econ
var snd: Node             ## Snd
var hotspots: Knoppen
var ui: UiVoor

func _init(spel_id: String, def: Dictionary) -> void:
	id = spel_id
	naam = def.get("naam", spel_id)
	kamer = def.get("kamer", "")
	wereld = World
	state = State
	econ = Econ
	snd = Snd
	hotspots = Knoppen.new(spel_id)
	ui = UiVoor.new(spel_id)

## Its own drawer in the save.  Timers and awaits do not survive a reload;
## the turn must always be restorable from here (world.md §4.2 `spel`).
func data() -> Dictionary:
	return State.spel_data(id)

## One star for taking part, the task card ticked on `naam` AND on the game id,
## and the save written.  Never for being right.
##
## At most ONE star per game per day (§3.8 `N1`): playing the same game again
## still ticks its card and still feeds the adaptive signal, it just does not pay
## a second star.  `o.sterren = 0` asks for the tick without any star at all —
## the day is then not stamped either, so a later turn that does ask for a star
## still gets one.
func taak_klaar(taak_naam: String = "", o: Dictionary = {}) -> void:
	var n := int(o.get("sterren", 1))
	if n > 0 and not State.ster_gehad(id):
		Econ.sterren(n, id)
		State.zet_ster(id)
	if taak_naam != "":
		Hotel.taak_af(taak_naam)
	Hotel.taak_af(id)
	State.bewaar()

func sluit() -> void:
	Games.stop()

# ----------------------------------------------------- het dier van de beurt

## The animal you play with (owner, 2026-09-23: "een methode om te wisselen met
## welk dier je de spellen speelt").  The child picks it on the game bar and
## `State.s.speler` remembers it for the session (not a field of the save
## format: a reload forgets it).  A game asks `voorkeur(spelers())` when it
## builds a turn: the picked animal when it may take part in THIS game, "" when
## it may not or nothing was picked — then the game chooses as it always did.
func voorkeur(kandidaten: Array) -> String:
	var wil := str(State.s.get("speler", ""))
	if wil.is_empty() or not kandidaten.has(wil) or State.gast_van(wil).is_empty():
		return ""
	return wil

## This game's animal of the turn is now `gast_id` — the game bar shows it and
## offers the next one.  A game calls it whenever its turn takes (or moves on
## to) an animal; "" means the turn has none.
func speelt(gast_id: String) -> void:
	Games.meld_speler(id, gast_id)

## What the animal on the game bar does when it is tapped: the next animal of
## `spelers()` takes over in a fresh turn (`Games.wissel_speler`).
func wissel_speler() -> bool:
	return Games.wissel_speler()

## The animal whose unfinished turn this start drops must not stay in the new
## animal's way — at the counter of the stall, on the deck of the pool — nor
## arrive there after it.  Call it AFTER the new animal was sent, so the free
## place the old one walks to keeps off the new one's target.
##   * asleep or gone: left alone (a switch never wakes anybody);
##   * still on his way into this game's room: back to his own bed instead;
##   * on his way anywhere else: left alone (a `stop()` already sent him);
##   * in this game's room: off to a free place there (`World.solo`).
func laat_gaan(gast_id: String) -> void:
	var d = World.dier(gast_id)
	if d == null or World.slaapt(gast_id) or kamer.is_empty():
		return
	var onderweg := str(d.reis_doel)
	if onderweg == kamer and d.kamer != kamer:
		var g := State.gast_van(gast_id)
		if not str(g.get("bed", "")).is_empty() and not str(g.get("kamer", "")).is_empty():
			World.slaap(gast_id, str(g["kamer"]), str(g["bed"]))
			g["waar"] = g["kamer"]
		return
	if not onderweg.is_empty() or d.kamer != kamer:
		return
	World.solo(gast_id)

# ------------------------------------------------ wachten tot het dier er is

const WACHT_TIK := 0.1         ## how often a wait looks whether he is there
const WACHT_MARGE := 3.0       ## voxels from his place still count as "there"
const WACHT_HERSTUUR := 1.0    ## a guest who is on nobody's way is sent again after this

## `if not await ctx.wacht_op(gast_id, plek): return` — the game begins when
## its animal is there (owner, 2026-09-23: "Zorg dat de minigame pas begint
## wanneer het dier er is").  `plek` is his place in THIS game's room, in voxels.
##
##   * He is sent there — through the doors with `World.reis`, inside the room
##     with `World.stappen` — unless he is on his way there already: a guest
##     who walks into this room keeps his route, so the bar of his "komt eraan"
##     bubble never jumps back.
##   * Already there (within `o.marge`, standing still): true AT ONCE, in the
##     same call and without a frame in between.  Reduced motion resolves every
##     walk at once (world.md §2.5), so there it is always at once.
##   * Whenever it is true he stands in end state `o.na` (`World.blijf`): a
##     waiting guest does not wander off from under the card.
##   * Otherwise it looks every `WACHT_TIK` s, in the timer phase — where every
##     game makes its cards (games/zwembad `_bots_en_terug`) — and is true the
##     moment he stands at his place.  Meanwhile the running game waits for him
##     (`Games.verwacht_dier`): the hotel keeps his "komt eraan" bubble with its
##     bar and `👀 Volg` in view during the game, and `Hotel.volg` may follow
##     him into the game's room (world.md §5.8, §6.3).
##   * False when THIS start of the game is over — stopped, superseded, the
##     animal switched (`Games.wissel_speler` is a fresh start) — or when the
##     guest is gone.  The caller checks `actief` after it anyway.
##   * Nothing a reload would need lives in memory: a resumed turn simply asks
##     again, and a guest the reload put somewhere else is sent again.  A walk
##     that another order took over is sent again after `WACHT_HERSTUUR` s.
##
##   o = {na: "wacht", tempo: 1.0, marge: WACHT_MARGE}
func wacht_op(gast_id: String, plek: Vector2, o: Dictionary = {}) -> bool:
	var beurt: int = Games.beurt()
	if not _loopt(beurt) or World.dier(gast_id) == null:
		return false
	var marge := float(o.get("marge", WACHT_MARGE))
	var na := str(o.get("na", "wacht"))
	_stuur(gast_id, plek, o, marge)
	if is_er(gast_id, plek, marge):
		World.blijf(gast_id, na)
		return true
	Games.verwacht(gast_id, beurt, true)
	var boom := Engine.get_main_loop() as SceneTree
	var los := 0.0
	var er := false
	while boom != null:
		await boom.create_timer(WACHT_TIK).timeout
		if not _loopt(beurt) or World.dier(gast_id) == null:
			break
		if is_er(gast_id, plek, marge):
			er = true
			break
		los = 0.0 if _onderweg(gast_id, plek, marge) else los + WACHT_TIK
		if World.rust() or los >= WACHT_HERSTUUR:
			los = 0.0
			_stuur(gast_id, plek, o, marge)
			if is_er(gast_id, plek, marge):
				er = true
				break
	Games.verwacht(gast_id, beurt, false)
	if er:
		World.blijf(gast_id, na)
	return er

## Does `gast_id` stand at `plek` in this game's room — arrived, not walking?
func is_er(gast_id: String, plek: Vector2, marge: float = WACHT_MARGE) -> bool:
	var d = World.dier(gast_id)
	return d != null and d.kamer == kamer and str(d.reis_doel).is_empty() \
		and (d.route as Array).is_empty() and (d.punten as Array).is_empty() \
		and Vector2(d.x, d.z).distance_to(plek) <= marge

## This start of this game still runs.
func _loopt(beurt: int) -> bool:
	return Games.actief() == id and Games.beurt() == beurt

## On his way to `plek`: walking through the doors into this room, or inside it
## with his last point at `plek`.
func _onderweg(gast_id: String, plek: Vector2, marge: float) -> bool:
	var d = World.dier(gast_id)
	if d == null:
		return false
	if d.kamer != kamer:
		return str(d.reis_doel) == kamer
	var punten: Array = d.punten
	if punten.is_empty():
		return false
	var laatste: Vector2 = punten[punten.size() - 1]
	return laatste.distance_to(plek) <= marge

## Send him — unless he is there or on his way.  In reduced motion `reis`
## walks the doors at once and leaves the last leg for the ticks; `stappen`
## then puts him on his place in the same call.
func _stuur(gast_id: String, plek: Vector2, o: Dictionary, marge: float) -> void:
	var d = World.dier(gast_id)
	if d == null or kamer.is_empty() or is_er(gast_id, plek, marge) \
			or (_onderweg(gast_id, plek, marge) and not World.rust()):
		return
	var na := str(o.get("na", "wacht"))
	if d.kamer != kamer:
		World.reis(gast_id, kamer, {"x": plek.x, "z": plek.y, "na": na})
		var g := State.gast_van(gast_id)
		if not g.is_empty():
			g["waar"] = kamer          # the save says where he is going
		d = World.dier(gast_id)
		if d == null or d.kamer != kamer or not World.rust():
			return
	_loop_los(gast_id, plek, {"na": na, "tempo": float(o.get("tempo", 1.0))})

## A walk nobody waits for (the shape of hinkel's `_loop_los`): the wait looks
## at the world, not at this promise.
func _loop_los(gast_id: String, plek: Vector2, o: Dictionary) -> void:
	await World.stappen(gast_id, [plek], o)

## Owner-stamped hotspot API (`ctx.hotspots`).
class Knoppen extends RefCounted:
	var _door: String
	func _init(door: String) -> void:
		_door = door
	func maak(o: Dictionary) -> String:
		var kopie := o.duplicate()
		kopie["door"] = _door
		return Hits.maak(kopie)
	func weg(id: String) -> void:
		Hits.weg(id)
	func wis_alles() -> void:
		Hits.wis_eigenaar(_door)
	func bron(obj: Variant, o: Dictionary) -> String:
		var kopie := o.duplicate()
		kopie["door"] = _door
		return Ui.bron(obj, kopie)
	func lijst() -> Array[String]:
		return Hits.lijst()
	## Borrow one of the hotel's own buttons while the game runs: it keeps its
	## place and its picture, only what it does changes.  Every borrowed button
	## is handed back by `Games.stop()` (world.md §5.3).
	func pak(id: String, fn: Callable) -> bool:
		return Hits.leen(id, _door, fn)
	func laat() -> void:
		Hits.geef_terug(_door)
	func spot(id: String) -> Hits.Spot:
		return Hits.spot(id)

## Owner-stamped card/bubble API (`ctx.ui`).
class UiVoor extends RefCounted:
	var _door: String
	func _init(door: String) -> void:
		_door = door
	func wolk(o: Dictionary) -> String:
		var kopie := o.duplicate()
		kopie["door"] = _door
		return Ui.wolk(kopie)
	func wolk_weg(id: String) -> void:
		Ui.wolk_weg(id)
	func somkaart(obj: Variant, som: String, o: Dictionary) -> Ui.Kaart:
		var kopie := o.duplicate()
		kopie["door"] = _door
		return Ui.somkaart(obj, som, kopie)
	## A bare number ON an object (world.md §5.6); `n == null` removes it.
	func getal_tag(obj: Variant, n: Variant, o: Dictionary = {}) -> String:
		var kopie := o.duplicate()
		kopie["door"] = _door
		return Ui.getal_tag(obj, n, kopie)
	func toast(tekst: String, soort: String = "") -> void:
		Ui.toast(tekst, soort)
	func op_kader(fn: Callable) -> Callable:
		return Ui.op_kader(fn)
