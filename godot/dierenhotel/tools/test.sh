#!/usr/bin/env bash
# The command CI and the tools use.  Runs the headless suite AND gates on
# anything the engine printed as an error, so a runtime SCRIPT ERROR inside a
# test can never be reported as a pass (architecture.md §2.4, §14.3).
#
# A test that walks an error path ON PURPOSE announces it with
# `Proef.verwacht_fout(n)`.  The runner adds those up and prints
# `verwachte motorfouten: n` as its last line; this wrapper allows exactly that
# many ERROR lines and not one more.  No such test, no such line -> zero allowed.
#
# The suite also gets its OWN `user://`.  That path is per USER, not per
# checkout, so ten worktrees running their own suite in parallel (wave 2) and a
# CI job on the same runner share one `dierenhotel.json`: `test_state.gd` writes
# a corrupt-save fixture and another process replaces it with a valid save
# between two lines, which fails a test that is perfectly correct (V1-F1).
# `XDG_DATA_HOME` is what Godot builds `user://` from on Linux.
set -uo pipefail
GODOT="${GODOT:-godot}"
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$(mktemp -t dierenhotel-tests-XXXXXX.log)"
EIGEN_DATA=0
if [ -z "${DH_USERDATA:-}" ]; then
  DH_USERDATA="$(mktemp -d -t dierenhotel-user-XXXXXX)"
  EIGEN_DATA=1
fi
export XDG_DATA_HOME="$DH_USERDATA"
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
[ "$EIGEN_DATA" -eq 1 ] && rm -rf "$DH_USERDATA"
exit "$code"
