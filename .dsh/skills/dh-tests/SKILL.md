---
name: dh-tests
description: Run and read the headless Godot test suite of this repo (filtered or full), find WHY a test is red (engine errors sit at the TOP of the log, not next to the test), write a new test in the project's style.
whenToUse: Before running tests, after any code change, and whenever a test is red and you need the cause.
---

# Running (workdir = repository root; `mkdir -p /tmp/ds` first)

```bash
# one file (5–45 s). The filter is a SUBSTRING OF THE PATH res://games/<id>/test_<id>.gd
# or res://tests/test_x.gd — `DH_TEST_FILTER=games` runs every game. `tools/test.sh <arg>` does NOT filter.
DH_TEST_FILTER=sleutels tools/test.sh > /tmp/ds/f.log 2>&1; echo "exit=$?"; tail -4 /tmp/ds/f.log
# everything: 470 tests, ≈ 200–210 s → run_in_background: true, then ONE job_output wait: true, timeout_ms: 360000
tools/test.sh > /tmp/ds/test.log 2>&1; echo "exit=$?"; tail -4 /tmp/ds/test.log
```

Never run the suite and `tools/export.sh` at the same time (shared `.godot/`
cache), and never two suites at once. If a suite is already running (another
agent shares this checkout): `pgrep -a godot` — wait, do not start yours.

# Reading the result — in this order

1. **Summary** (last lines): `N goed, M fout, T ms` and `verwachte motorfouten: K`.
   Green = `0 fout` AND `exit=0`. A last line `FOUT: de motor logde X fout(en)`
   means the engine printed errors nobody announced: also red.
2. **Which tests**: `grep -n "^FOUT" -A3 /tmp/ds/test.log`. Format is
   `FOUT  test_x.gd.test_naam` followed by indented lines with each failed
   assert (`kreeg ..., verwacht ...`, `... : niet waar`).
3. **Why** — the cause is usually NOT next to the test. Engine errors are
   printed where they happen, mostly at the top of the log:
   `grep -n "SCRIPT ERROR\|Parse Error\|Failed to load script" /tmp/ds/test.log | head`.

| symptom | cause | do |
|---|---|---|
| many tests of ONE file red at once, `het spel start: niet waar`, `Invalid access to property or key 'x' on a base object of type 'Dictionary'` | that game's `spel.gd` does not PARSE, so it never registered | the `Parse Error` line at the top names file:line; fix it (see `dh-gdscript`), rerun the filter |
| `Cannot infer the type of "x" variable` | `var x := <untyped value>` | write the type: `var x: float = ...` |
| one test red only in the full run, green alone | order dependence: state left behind by an earlier file (`Ui`, `Hits`, `World`, `State.s`) | make the test `_af()` restore what it changed; never "fix" it by reordering |
| `krap` true / rects overlap in a placement test | the frame lost bands (something took frame height or a hotspot was added) | `Hits.debug()` per id: `rect`, `vlak`, `dekking`, `op`, `prio`, `krap`, `gestapeld` — print the ids that moved |
| `verwacht_fout(n)` mismatch | the count is exact, not a maximum | announce exactly the errors you trigger |

A red result is a finding, not a "known rest point": it blocks the commit
(`dh-commit`). Report it literally: `N goed, M fout` and the test names.

# Writing a test (games/<id>/test_<id>.gd or tests/test_<area>.gd)

- `extends Proef`; asserts `gelijk(got, want, "why")`, `waar(cond, "why")`,
  `fout("msg")`, `verwacht_fout(n, "why")`.
- Copy the file's own helpers (`_op()`, `_af()`, `_gasten(n)`, `_wacht()`,
  `_kaart_staat()`, `_druk()`); always `_af()` at the end — a test that leaks
  state breaks a LATER file, not itself.
- Turn tests run with `Ui.zet_rust_modus(true)` (instant movement); particle
  counts need `false`.
- A shell/layout test builds the real shell: `load("res://scenes/main.tscn")`
  instantiated inside a `SubViewport` of the wanted size, `set_meta("geen_start", true)`,
  then `await` 4 process frames before asking `Hits.debug()` — copy
  `test_dekking_is_nul_op_vier_schermen` in `games/sleutels/test_sleutels.gd`.
- Names Dutch and descriptive: `test_de_balk_geeft_zijn_ruimte_weer_vrij`.
