#!/usr/bin/env bash
# tools/test.sh — the headless test suite (architecture.md §2.4, §14.3).
#
# A thin wrapper around godot/dierenhotel/tools/test.sh, which owns the suite
# and its stderr gate (W5).  It is deliberately not duplicated here: CI and a
# developer must run the one command that also fails on a runtime SCRIPT ERROR
# inside a test.
#
#   tools/test.sh
#   GODOT=/path/to/godot tools/test.sh
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROJ="$ROOT/godot/dierenhotel"
GODOT="${GODOT:-godot}"
SUITE="$PROJ/tools/test.sh"

command -v "$GODOT" >/dev/null 2>&1 || { echo "FOUT: godot niet gevonden (zet GODOT=)"; exit 127; }
[ -f "$SUITE" ] || { echo "FOUT: $SUITE ontbreekt (hoort bij W5)"; exit 1; }

export GODOT
if [ -x "$SUITE" ]; then
  exec "$SUITE" "$@"
else
  exec bash "$SUITE" "$@"
fi
