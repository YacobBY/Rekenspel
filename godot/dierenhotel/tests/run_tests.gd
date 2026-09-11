extends SceneTree
## The test runner.
##
## DECISION (architecture.md §2.4): no vendored test addon.  GUT and GdUnit4 are
## large third-party trees that have to track the engine version, and the whole
## suite here is "call a pure function, compare an integer".  A SceneTree script
## starts in well under a second, prints a plain summary and returns an honest
## exit code, which is all CI needs.
##
##   godot --headless --path godot/dierenhotel --script res://tests/run_tests.gd
##   godot/dierenhotel/tools/test.sh          # the same, plus the stderr gate
##
## Every file `res://tests/test_*.gd` and every `res://games/<id>/test_*.gd` is
## loaded; every method named `test_*` is run on a fresh instance.
##
## A test fails when it calls `fout(...)` **or when the engine logs any error
## while it runs**.  The second half matters: a runtime `SCRIPT ERROR` (a null
## call, a bad index) aborts the test function silently, so without this the
## runner would print `ok` for a test that never reached its assertions.  Errors
## are caught with an `OS.add_logger()` hook; warnings (`push_warning`, the `# Wn`
## stubs) are deliberately NOT failures.  `tools/test.sh` greps stderr for the
## same thing, so a failure survives even if a future engine drops the hook.
##
## A test that walks an error path ON PURPOSE says so with `Proef.verwacht_fout()`.
## The runner then demands EXACTLY that many engine errors during that test, and
## reports the total on the last line (`verwachte motorfouten: n`) so that the
## shell gate in `tools/test.sh` can allow the same number and no more.

const MAP := "res://tests"
const SPELLEN := "res://games"

var _goed := 0
var _fout := 0
var _verwacht_totaal := 0
var _regels: Array[String] = []
var _teller: FoutTeller = null

## Counts everything the engine logs as an error while a test runs.
class FoutTeller extends Logger:
	var aantal := 0
	var laatste: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		aantal += 1
		if laatste.size() < 4:
			laatste.append("%s:%d %s %s" % [file.get_file(), line,
				code if code != "" else function, rationale])

	func neem() -> Array[String]:
		var uit := laatste.duplicate()
		laatste.clear()
		return uit

func _initialize() -> void:
	# The autoloads are in the tree but have not run _ready() yet when a custom
	# SceneTree is initialised; one frame fixes that.
	await process_frame
	_teller = FoutTeller.new()
	OS.add_logger(_teller)
	var start := Time.get_ticks_msec()
	var bestanden: Array[String] = []
	for f in DirAccess.get_files_at(MAP):
		if f.begins_with("test_") and f.ends_with(".gd"):
			bestanden.append("%s/%s" % [MAP, f])
	# a game keeps its own tests inside res://games/<id>/ so that a wave-2
	# ticket never writes outside its own directory
	for map in DirAccess.get_directories_at(SPELLEN):
		for f in DirAccess.get_files_at("%s/%s" % [SPELLEN, map]):
			if f.begins_with("test_") and f.ends_with(".gd"):
				bestanden.append("%s/%s/%s" % [SPELLEN, map, f])
	bestanden.sort()
	for pad in bestanden:
		await _draai_bestand(pad)
	var ms := Time.get_ticks_msec() - start
	for r in _regels:
		print(r)
	print("----")
	print("%d goed, %d fout, %d ms" % [_goed, _fout, ms])
	# tools/test.sh reads this line: it allows exactly this many ERROR lines
	print("verwachte motorfouten: %d" % _verwacht_totaal)
	quit(1 if _fout > 0 else 0)

func _draai_bestand(pad: String) -> void:
	# A file that does not compile is a FAILURE, never a skip.  `load()` on a
	# script with a parse error hands back a GDScript that is not null but has an
	# empty method list, so the loop below would simply not run and the file would
	# vanish from the suite without a line — the bare `--script` command would
	# print "n goed, 0 fout" while a test file was broken (W5-F1).
	var scr: GDScript = load(pad)
	if scr == null or not scr.can_instantiate():
		_mis(pad.get_file(), "kan niet laden — parseerfout?", [])
		return
	var namen: Array[String] = []
	for m in scr.get_script_method_list():
		var naam: String = m["name"]
		if naam.begins_with("test_"):
			namen.append(naam)
	if namen.is_empty():
		_mis(pad.get_file(), "geen enkele test_-methode — parseerfout?", [])
		return
	for naam in namen:
		var proef = scr.new()
		if proef == null:
			_mis("%s.%s" % [pad.get_file(), naam], "kan geen exemplaar maken", [])
			continue
		proef.set("_runner", self)
		var voor := _teller.aantal
		_teller.neem()
		# `await` is mandatory here, also for a test without one.  A test method
		# that awaits is a coroutine; a plain `proef.call(naam)` on one logs
		# `SCRIPT ERROR: Trying to call an async function without "await"` AND
		# abandons the rest of that file — the test and everything after it in it
		# silently disappear from the suite (measured: 14 tests in test_ui.gd, 13
		# lines of output).  Awaiting a value that is not a coroutine simply
		# returns it, so this one word covers both kinds.
		await proef.call(naam)
		if proef.has_method("herstel_spellen"):
			proef.herstel_spellen()
		var motor := _teller.aantal - voor
		var verwacht := 0
		if proef.get("_verwacht") != null:
			verwacht = int(proef.get("_verwacht"))
		_verwacht_totaal += verwacht
		var meldingen: Array = []
		if proef.get("_meldingen") != null:
			meldingen = proef.get("_meldingen")
		if motor != verwacht:
			meldingen = meldingen.duplicate()
			if verwacht == 0:
				meldingen.append("%d motorfout(en) tijdens de test:" % motor)
			else:
				meldingen.append("verwachtte %d motorfout(en), kreeg er %d:" % [verwacht, motor])
			meldingen.append_array(_teller.neem())
		else:
			_teller.neem()
		if (proef.get("_fouten") != null and int(proef.get("_fouten")) > 0) or motor != verwacht:
			_mis("%s.%s" % [pad.get_file(), naam], "", meldingen)
		else:
			_goed += 1
			_regels.append("ok    %s.%s" % [pad.get_file(), naam])
		if proef is Node:
			proef.free()

func _mis(wat: String, waarom: String, meldingen: Array) -> void:
	_fout += 1
	_regels.append("FOUT  %s%s" % [wat, "" if waarom.is_empty() else ": " + waarom])
	for r in meldingen:
		_regels.append("      " + str(r))
