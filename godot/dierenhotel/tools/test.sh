#!/usr/bin/env bash
# The command CI and the tools use.  Runs the headless suite AND gates on
# anything the engine printed as an error, so a runtime SCRIPT ERROR inside a
# test can never be reported as a pass (architecture.md §2.4, §14.3).
set -uo pipefail
GODOT="${GODOT:-godot}"
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$(mktemp -t dierenhotel-tests-XXXXXX.log)"
"$GODOT" --headless --path "$PROJ" --script res://tests/run_tests.gd > "$LOG" 2>&1
code=$?
cat "$LOG"
if grep -qE '^(USER )?(SCRIPT )?ERROR:' "$LOG"; then
  echo "FOUT: de motor logde fouten tijdens de suite (zie hierboven)"
  code=1
fi
rm -f "$LOG"
exit "$code"
