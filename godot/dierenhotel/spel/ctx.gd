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
