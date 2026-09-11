class_name Proef
extends RefCounted
## The two lines of test framework this project needs.
##
## `gelijk` / `waar` / `fout` assert; `verwacht_fout` is the escape hatch for a
## test that deliberately walks an error path (architecture.md §2.4).

var _fouten := 0
var _meldingen: Array[String] = []
var _runner = null
## How many engine errors this test says it is going to cause.
var _verwacht := 0
var _verwacht_waarom: Array[String] = []

func gelijk(gekregen, verwacht, wat := "") -> void:
	if typeof(gekregen) == TYPE_FLOAT or typeof(verwacht) == TYPE_FLOAT:
		if is_equal_approx(float(gekregen), float(verwacht)):
			return
	elif str(gekregen) == str(verwacht):
		return
	fout("%s: kreeg %s, verwacht %s" % [wat, str(gekregen), str(verwacht)])

func waar(v: bool, wat := "") -> void:
	if not v:
		fout("%s: niet waar" % wat)

func fout(melding: String) -> void:
	_fouten += 1
	_meldingen.append(melding)

## Announce that this test makes the engine log `aantal` error(s) ON PURPOSE —
## an `Art.registreer_model` that refuses a protected name, a save file that is
## deliberately corrupt.  Without this the runner counts every engine error as a
## failure (and it should: a silent SCRIPT ERROR would otherwise pass as `ok`).
##
## The budget is EXACT, not a maximum: a test that announces one error and
## causes two fails, and so does a test that announces one and causes none —
## then the error path was not walked at all and the test proved nothing.
## May be called before or after the call that errors; the runner only compares
## the totals at the end of the test.
## `alleen_spellen(ids)` — hide every registered game except `ids` for the
## duration of this test (the hotel's wish and board rules depend on which
## games exist).  The runner calls `herstel_spellen()` after each test.
var _spellen_weg: Dictionary = {}
var _scenes_weg: Dictionary = {}

func alleen_spellen(ids: Array) -> void:
	for k in Games._defs.keys().duplicate():
		if not ids.has(str(k)):
			_spellen_weg[k] = Games._defs[k]
			_scenes_weg[k] = Games._scenes.get(k)
			Games._defs.erase(k)
			Games._scenes.erase(k)

func herstel_spellen() -> void:
	for k in _spellen_weg.keys():
		Games._defs[k] = _spellen_weg[k]
		if _scenes_weg.get(k) != null:
			Games._scenes[k] = _scenes_weg[k]
	_spellen_weg.clear()
	_scenes_weg.clear()

func verwacht_fout(aantal := 1, waarom := "") -> void:
	_verwacht += aantal
	if waarom != "":
		_verwacht_waarom.append(waarom)
