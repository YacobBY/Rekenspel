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
func taak_klaar(taak_naam: String = "", o: Dictionary = {}) -> void:
	Econ.sterren(o.get("sterren", 1), id)
	if taak_naam != "":
		Hotel.taak_af(taak_naam)
	Hotel.taak_af(id)
	State.bewaar()

func sluit() -> void:
	Games.stop()

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
	## Borrow one of the hotel's own buttons while the game runs.
	func pak(_id: String, _fn: Callable) -> void:
		push_warning("hotspots.pak: W3")     # W3
	func laat() -> void:
		push_warning("hotspots.laat: W3")    # W3

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
	func toast(tekst: String, soort: String = "") -> void:
		Ui.toast(tekst, soort)
	func op_kader(fn: Callable) -> Callable:
		return Ui.op_kader(fn)
