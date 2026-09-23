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

const KORT_KADER := 450         ## below this frame height other games' icons hide while one runs
const DUWTJE := 8.0             ## voxels (|dx| + |dz|): an entry this close still hangs ON its object
var _defs: Dictionary = {}      ## id -> definitie
var _scenes: Dictionary = {}    ## id -> PackedScene
var _ctx: Dictionary = {}       ## id -> SpelCtx
var _actief := ""
var _actieve_kamer := ""
var _knoop: Node = null         ## the running game's node

const EIGENAAR := "registry"

func _ready() -> void:
	scan()
	# Deferred: `Hotel` is autoload #10 and does not exist yet while #9 boots.
	_verbind.call_deferred()

## The entry buttons are re-stuck after every render, exactly as `hersteek()`
## does in the HTML: the hotel decides what is on screen, the registry only
## hangs its own icons on the objects that are there.
func _verbind() -> void:
	Hotel.bord_veranderd.connect(hersteek)
	World.kamer_veranderd.connect(func(_k: String) -> void: hersteek())

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
		_meld_modellen(def)

## The models a game's resting props are drawn with (`definitie().modellen`,
## name -> a STATIC builder), registered at the scan: the props stand in the
## room before the game ever ran.  A builder bound to the scanned instance
## would die with it, so the games hand in functions of their script.
func _meld_modellen(def: Dictionary) -> void:
	var modellen: Dictionary = def.get("modellen", {})
	for naam in modellen:
		if not Art.heeft_model(str(naam)):
			Art.registreer_model(str(naam), modellen[naam])

## Manual registration, for tests and for a game built at runtime.
func registreer(def: Dictionary, scene: PackedScene) -> void:
	_defs[def["id"]] = def
	_scenes[def["id"]] = scene
	_meld_modellen(def)

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
	if not _defs.has(id) or not _scenes.has(id):
		# world.md §5.2 step 7: a game that cannot be built never leaves the
		# child staring at a dead button.
		Ui.toast(UiTekst.SPEL_MIS, "kind")
		return false
	if _actief != "":
		stop()
	var def: Dictionary = _defs[id]
	# every game's resting props go: this game puts down its real ones, and
	# world.md §5.2 step 4 wants the others' out of the way
	for ander in _defs.keys():
		_zet_rust(str(ander), false)
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
	if _knoop == null:
		_actief = ""
		_actieve_kamer = ""
		Hits.voorrang("")
		Ui.toast(UiTekst.SPEL_MIS, "kind")
		return false
	add_child(_knoop)
	var ctx := _maak_ctx(id, def)
	if _knoop.has_method("_spel_start"):
		_knoop._spel_start(ctx)
	elif _knoop.has_method("start"):
		_knoop.start(ctx)
	# The game may have moved the camera itself; the hotel must know which room
	# is really in view (world.md §5.2 step 8).
	if World.kamer_nu() != _actieve_kamer:
		_actieve_kamer = World.kamer_nu()
		Hotel.render()
	hersteek()
	# `spel_gestart` is what swaps the room bar for the game bar (`⬅ Terug`,
	# scenes/main.gd): the shell owns the chrome, the registry only tells it.
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
	Hits.wis_eigenaar(id)          # returns every borrowed button as well
	World.decor_wis_eigenaar(id)
	Hits.voorrang("")
	Hotel.render()
	hersteek()
	spel_gestopt.emit(id)

func _maak_ctx(id: String, def: Dictionary) -> SpelCtx:
	if not _ctx.has(id):
		_ctx[id] = SpelCtx.new(id, def)
	return _ctx[id]

# ------------------------------------------------------------- de ingangen

## `hersteek()` — the entry icon of every playable game, hung on ITS OWN object
## (world.md §5.1).  Owner `registry`, class `hotgame`, prio 7, and it follows
## its object every frame, so it walks with a trolley that is being pushed.
##
## The icon disappears while its own game runs (unless `hotspot.blijf`), when
## `unlock` says no, and when the object is not in this room — which is exactly
## why an entry button must hang on a FIXED object, never on a game's own loose
## decor.
func hersteek() -> void:
	# the resting props first: they are world, not buttons, so they stand
	# there with or without a shell — but only while no game runs
	for sleutel in _defs.keys():
		var rid := str(sleutel)
		var rdef: Dictionary = _defs[rid]
		_zet_rust(rid, _actief == "" and not bool(rdef.get("stub", false))
			and ontgrendeld(rid))
	if Ui.knoplaag == null:
		return                     # headless, or before the shell registered
	var nu := World.kamer_nu()
	# On a short frame (under KORT_KADER units high) the entry icons of the OTHER
	# games leave while one runs: the running game needs the bands for its own
	# card and keypad (GAMES-API §9 "foreign buttons", architecture.md §4.5).
	var kort := World.kader_rect().size.y < KORT_KADER
	for sleutel in _defs.keys():
		var id := str(sleutel)
		var def: Dictionary = _defs[id]
		var knop_id := "spel_" + id
		var hs: Dictionary = def.get("hotspot", {})
		if hs.is_empty() or str(def.get("kamer", "")) != nu \
				or bool(def.get("stub", false)) \
				or not ontgrendeld(id) \
				or (_actief == id and not bool(hs.get("blijf", false))) \
				or (kort and _actief != "" and _actief != id):
			Hits.weg(knop_id)
			continue
		var plek := _plek_van(nu, str(hs.get("obj", "")))
		if plek.is_empty():
			Hits.weg(knop_id)
			continue
		var x: float = float(plek.get("x", 0.0)) + float(hs.get("dx", 0))
		var z: float = float(plek.get("z", 0.0)) + float(hs.get("dz", 0))
		var y: float = float(hs.get("hoog", 12))
		var volg := func() -> Dictionary:
			var p := _plek_van(World.kamer_nu(), str(hs.get("obj", "")))
			if p.is_empty():
				return {}
			return {"x": float(p.get("x", 0.0)) + float(hs.get("dx", 0)),
				"z": float(p.get("z", 0.0)) + float(hs.get("dz", 0)),
				"y": y, "kamer": World.kamer_nu()}
		var o := {
			"id": knop_id, "door": EIGENAAR, "kamer": nu, "x": x, "z": z, "y": y,
			"icoon": str(hs.get("icoon", "")), "label": str(hs.get("label", def.get("naam", id))),
			"titel": str(def.get("naam", id)), "prio": 7, "op": "aan",
			"klas": "hotgame aan" if _actief == id else "hotgame",
			"volg": volg, "aan": func(_s) -> void: start(id),
		}
		# An icon nudged a few voxels off its object still hangs ON that object,
		# so it names it: `Hits` looks for a thing within two voxels of the aim
		# point only, and the speelmand's 🛏 (4 + 4) and the sleutelbord's 🔑
		# (6) found nothing there, lost their object and floated off onto the
		# band grid — "Bedden" in the middle of kamer 1 (owner, 2026-09-23).
		# An icon moved FAR from its object (the laundry pile, the hopscotch
		# path, the stall) stands where the game will be, not at the object.
		# ... and an icon whose game leaves its props standing hangs on them
		# (`hotspot.rust`, owner 2026-09-23: "Dan hangt elk spel aan iets wat
		# je echt ziet")
		var rust_obj := str(hs.get("rust", ""))
		if rust_obj != "" and not World.decor_plek(rust_obj, nu).is_empty():
			o["obj"] = rust_obj
		elif absf(float(hs.get("dx", 0))) + absf(float(hs.get("dz", 0))) <= DUWTJE:
			o["obj"] = str(hs.get("obj", ""))
		Hits.maak(o)

## The props a game leaves standing while it does not run (`definitie().rust`:
## loose decor entries with ids of their own), so that its entry button hangs on
## something the child can see — the hopscotch stones, the market stall, the
## pile of washing (owner, 2026-09-23).  They belong to `rust:<id>`, not to the
## game: its own decor, and every test that counts it, stays its own.  Put down
## or taken away only when that changes, because every `World.decor()` redraws
## the room.
const RUST := "rust:"

func _zet_rust(id: String, aan: bool) -> void:
	var def: Dictionary = _defs.get(id, {})
	var kamer := str(def.get("kamer", ""))
	for stuk in def.get("rust", []):
		var sid := str((stuk as Dictionary).get("id", ""))
		var staat := not World.decor_plek(sid, kamer).is_empty()
		if aan and not staat:
			var o: Dictionary = (stuk as Dictionary).duplicate(true)
			o["door"] = RUST + id
			World.decor(kamer, o)
		elif not aan and staat:
			World.decor_weg(kamer, sid)

## The object an entry button hangs on: a loose thing first (the trolley, the
## desk lamp), then whatever `World.mik` finds (slots, fixed decor, the running
## game's own loose decor).
##
## A thing that is standing in ANOTHER room falls back to its home tile, as long
## as home is this room: the trolley left in kamer2 must never take the kitchen's
## 🛒 button with it, or the game becomes unreachable until the page is reloaded.
func _plek_van(kamer_id: String, obj: String) -> Dictionary:
	if obj.is_empty():
		return {}
	var ding := World.ding(obj)
	if not ding.is_empty():
		if str(ding.get("kamer", kamer_id)) == kamer_id:
			return ding
		var thuis := World.ding_thuis(obj)
		if not thuis.is_empty() and str(thuis.get("kamer", "")) == kamer_id:
			return thuis
	return World.mik(obj, kamer_id)
