extends Node
## Games — the minigame registry.  Autoload #9.
## Port of `demos/dierenhotel/games/registry.js` (world.md §5).
##
## DECISION (architecture.md §6.1): a game is discovered by SCANNING
## `res://games/*/`; every directory that holds a `spel.tscn` is a game and its
## directory name is its id.  Adding a game therefore never touches a shared
## file, which is what lets the ten wave-2 workers run in parallel worktrees
## without a single merge conflict.  The scan runs in the exported build too
## (DirAccess lists the PCK) — proven by the browser probe, which prints the
## discovered ids to the console.

signal spel_gestart(id: String)
signal spel_gestopt(id: String)

const MAP := "res://games"

var _defs: Dictionary = {}      ## id -> definitie
var _scenes: Dictionary = {}    ## id -> PackedScene
var _ctx: Dictionary = {}       ## id -> SpelCtx
var _actief := ""
var _actieve_kamer := ""
var _knoop: Node = null         ## the running game's node

func _ready() -> void:
	scan()

## Discover every game.  Safe to call again.
func scan() -> void:
	for map in DirAccess.get_directories_at(MAP):
		if map.begins_with("."):
			continue
		var pad := "%s/%s/spel.tscn" % [MAP, map]
		if not ResourceLoader.exists(pad):
			continue
		var scene: PackedScene = load(pad)
		if scene == null:
			continue
		var proef := scene.instantiate()
		if not proef.has_method("definitie"):
			proef.free()
			continue
		var def: Dictionary = proef.definitie()
		proef.free()
		def["id"] = map
		_defs[map] = def
		_scenes[map] = scene

## Manual registration, for tests and for a game built at runtime.
func registreer(def: Dictionary, scene: PackedScene) -> void:
	_defs[def["id"]] = def
	_scenes[def["id"]] = scene

func lijst() -> Array[String]:
	var uit: Array[String] = []
	for k in _defs.keys():
		uit.append(k)
	uit.sort()
	return uit

func definitie(id: String) -> Dictionary:
	return _defs.get(id, {})

func actief() -> String:
	return _actief

func actieve_kamer() -> String:
	return _actieve_kamer

## `unlock(N, band)` — may it be played?  Absent means yes.
func ontgrendeld(id: String) -> bool:
	var def := definitie(id)
	if def.is_empty():
		return false
	var slot = def.get("unlock", null)
	if slot is Callable:
		return bool(slot.call(State.n_gasten(), State.band()))
	return true

## world.md §5.2.  Starting another game supersedes the running one completely:
## there is no pause.
func start(id: String) -> bool:
	if not _defs.has(id):
		return false
	if _actief != "":
		stop()
	var def: Dictionary = _defs[id]
	_actief = id
	_actieve_kamer = def.get("kamer", World.kamer_nu())
	Hotel.bord_dicht()
	Hits.voorrang(id)
	# world.md §5.2 step 4: the loose decor of every OTHER game goes
	for ander in _defs.keys():
		if ander != id:
			World.decor_wis_eigenaar(ander)
	Hotel.render()
	if World.kamer_nu() != _actieve_kamer:
		World.naar(_actieve_kamer)
	_knoop = _scenes[id].instantiate()
	add_child(_knoop)
	var ctx := _maak_ctx(id, def)
	if _knoop.has_method("_spel_start"):
		_knoop._spel_start(ctx)
	elif _knoop.has_method("start"):
		_knoop.start(ctx)
	spel_gestart.emit(id)
	return true

func stop() -> void:
	if _actief == "":
		return
	var id := _actief
	_actief = ""
	_actieve_kamer = ""
	if _knoop != null and is_instance_valid(_knoop):
		if _knoop.has_method("_spel_stop"):
			_knoop._spel_stop()
		elif _knoop.has_method("stop"):
			_knoop.stop()
		_knoop.queue_free()
	_knoop = null
	Hits.wis_eigenaar(id)
	World.decor_wis_eigenaar(id)
	Hits.voorrang("")
	Hotel.render()
	spel_gestopt.emit(id)

func _maak_ctx(id: String, def: Dictionary) -> SpelCtx:
	if not _ctx.has(id):
		_ctx[id] = SpelCtx.new(id, def)
	return _ctx[id]
