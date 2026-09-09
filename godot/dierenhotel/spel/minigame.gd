class_name MiniGame
extends Node
## The base class of every minigame.  A game is a scene whose root has a script
## extending MiniGame, in `res://games/<id>/spel.tscn`.
##
## Lifecycle (architecture.md §5):
##   definitie() -> Dictionary   read once at boot, WITHOUT the scene in the tree
##   start(ctx)                  build the turn; the camera is already in `kamer`
##   stop()                      clean up; runs on supersede, on ctx.sluit() and
##                               when the child taps another task card
##   avond()                     optional; the evening round started, the game
##                               keeps playing and keeps its priority
##
## Rules a game must obey, all of them enforceable by review:
##  * `_ready()` may not touch the world — the registry instantiates the scene
##    only when the game actually starts.
##  * After EVERY `await`, check `actief`: an await resolves false when another
##    game took over, and the node is freed right after `stop()`.
##  * Use `na()` for delays instead of a raw SceneTreeTimer: those are cancelled
##    for you in `stop()`.  A timer that fires after stop() is the classic bug.
##  * Store the turn in `ctx.data()` after every step that a reload must survive;
##    awaits and timers do not survive a reload.
##  * Everything visible goes through `ctx` so it carries the game's owner stamp.

var ctx: SpelCtx = null
var actief := false

var _timers: Array[SceneTreeTimer] = []

## The registration record.  Override.  Keys (world.md §5.1):
##   naam, kamer, hotspot {obj, icoon, label, hoog, dx, dz, blijf},
##   unlock: Callable(N, band) -> bool, wens: String|Array, stub: bool,
##   taak: {id, icoon, tekst, wanneer, kamer, prio}
func definitie() -> Dictionary:
	return {"naam": name, "kamer": ""}

## Build the turn.  Called once per start; never called twice without stop().
func start(_ctx: SpelCtx) -> void:
	pass

## Clean up.  Always called before the node is freed.
func stop() -> void:
	pass

## The evening round started while this game was playing.  Optional.
func avond() -> void:
	pass

# ------------------------------------------------------------ engine hooks

func _spel_start(c: SpelCtx) -> void:
	ctx = c
	actief = true
	start(c)

func _spel_stop() -> void:
	actief = false
	for t in _timers:
		if t != null:
			t.time_left = 0.0
	_timers.clear()
	stop()
	ctx.hotspots.wis_alles()

## `await na(1.2)` — a delay that is cancelled when the game stops.
## Returns false when the game was stopped in the meantime; check it.
func na(seconden: float) -> bool:
	var t := get_tree().create_timer(seconden)
	_timers.append(t)
	await t.timeout
	return actief
