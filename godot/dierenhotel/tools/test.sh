#!/usr/bin/env bash
# The command CI and the tools use.  Runs the headless suite AND gates on
# anything the engine printed as an error, so a runtime SCRIPT ERROR inside a
# test can never be reported as a pass (architecture.md §2.4, §14.3).
#
# A test that walks an error path ON PURPOSE announces it with
# `Proef.verwacht_fout(n)`.  The runner adds those up and prints
# `verwachte motorfouten: n` as its last line; this wrapper allows exactly that
# many ERROR lines and not one more.  No such test, no such line -> zero allowed.
set -uo pipefail
GODOT="${GODOT:-godot}"
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$(mktemp -t dierenhotel-tests-XXXXXX.log)"
"$GODOT" --headless --path "$PROJ" --script res://tests/run_tests.gd > "$LOG" 2>&1
code=$?
cat "$LOG"
motor=$(grep -cE '^(USER )?(SCRIPT )?ERROR:' "$LOG")
verwacht=$(sed -n 's/^verwachte motorfouten: \([0-9][0-9]*\)$/\1/p' "$LOG" | tail -1)
verwacht="${verwacht:-0}"
if [ "$motor" -gt "$verwacht" ]; then
  echo "FOUT: de motor logde $motor fout(en) tijdens de suite, $verwacht aangekondigd (zie hierboven)"
  code=1
fi
rm -f "$LOG"
exit "$code"
