#!/usr/bin/env bash
# tools/import.sh — the headless import pass (architecture.md §7.3, §14.1).
#
# Populates godot/dierenhotel/.godot/ and gates on every engine ERROR line, so
# the failure that stops CI stops a developer here in the same way.
#
#   tools/import.sh                 # normal run
#   GODOT=/path/to/godot tools/import.sh
#   DH_LOG_DIR=/tmp/logs tools/import.sh
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROJ="$ROOT/godot/dierenhotel"
GODOT="${GODOT:-godot}"
LOG_DIR="${DH_LOG_DIR:-${TMPDIR:-/tmp}/dierenhotel-log}"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/import.log"

command -v "$GODOT" >/dev/null 2>&1 || { echo "FOUT: godot niet gevonden (zet GODOT=)"; exit 127; }

importeer() { "$GODOT" --headless --import --path "$PROJ" > "$LOG" 2>&1; }

importeer
code=$?
# A parallel headless run may hold the import lock; one retry, then give up.
if [ "$code" -ne 0 ] && grep -qiE 'lock|already (in use|running)|another instance' "$LOG"; then
  echo "let op: import geblokkeerd door een andere run, één keer opnieuw over 3 s"
  sleep 3
  importeer
  code=$?
fi

cat "$LOG"
if grep -qE '^(USER )?(SCRIPT )?ERROR:' "$LOG"; then
  echo "FOUT: de motor logde fouten tijdens de import (zie hierboven)"
  code=1
fi
if [ "$code" -eq 0 ]; then
  echo "OK: import zonder fouten — log: $LOG"
fi
exit "$code"
