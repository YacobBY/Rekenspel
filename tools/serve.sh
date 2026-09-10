#!/usr/bin/env bash
# tools/serve.sh — serve the exported web build for a local browser test.
#
# Plain static hosting on 127.0.0.1, no compression and no COOP/COEP headers:
# that is exactly what GitHub Pages gives us, and it is enough because the Web
# preset has variant/thread_support=false (architecture.md §7.2).
#
#   tools/serve.sh            # http://127.0.0.1:8642/index.html
#   tools/serve.sh 9000
#   POORT=9000 tools/serve.sh
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MAP="${DH_WEB_DIR:-$ROOT/godot/dierenhotel/build/web}"
POORT="${1:-${POORT:-8642}}"

if [ ! -f "$MAP/index.html" ]; then
  echo "FOUT: $MAP/index.html ontbreekt — draai eerst tools/export.sh"
  exit 1
fi
echo "serveert $MAP op http://127.0.0.1:$POORT/index.html  (ctrl-c stopt)"
exec python3 -m http.server "$POORT" --bind 127.0.0.1 --directory "$MAP"
