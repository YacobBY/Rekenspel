extends Proef
## The runner's own two gates (architecture.md §2.4).  This file lives under the
## `test_sommen_*` prefix because that is W5's write set; it tests the harness,
## not the sums.
##
## Gate 1 (in-engine): every engine error during a test is a failure, so a
## silent `SCRIPT ERROR` can never be reported as `ok`.
## Gate 2 (`tools/test.sh`): the same thing again by grepping stderr, so it
## survives an engine that drops the logger hook.
## `verwacht_fout()` is the one door through both: a test that walks an error
## path on purpose says how many errors it will cause, exactly.

## One announced error, one raised: the suite stays green and `tools/test.sh`
## allows exactly this one ERROR line.
func test_verwacht_fout_laat_een_foutpad_toe() -> void:
	verwacht_fout(1, "de foutmelder van de proefopstelling zelf")
	push_error("W5-proef: deze fout hoort erbij en telt niet als mislukking")
	gelijk(1 + 1, 2, "de test loopt gewoon door na de fout")

## Two announced, two raised — the budget is a count, not a flag.  A warning is
## deliberately NOT an error (the `# Wn` stubs of the other tickets warn).
func test_verwacht_fout_telt_precies() -> void:
	verwacht_fout(2, "twee foutpaden achter elkaar")
	push_error("W5-proef: fout 1 van 2")
	push_warning("W5-proef: een waarschuwing telt niet mee")
	push_error("W5-proef: fout 2 van 2")
	waar(true, "en de gewone asserties blijven werken")
