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
#   tools/serve.sh --gzip     # zoals GitHub Pages: gzip onderweg (W2, 2026-10-09)
#
# `--gzip` packs every response except images on the fly with gzip, as GitHub
# Pages does (measured 2026-10-09: wasm, pck and js come with
# `content-encoding: gzip`, never brotli, also when the browser offers `br`),
# with Pages' `cache-control: max-age=600`.  Use it to see the real download
# size and time of a phone; the plain mode stays the default.
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MAP="${DH_WEB_DIR:-$ROOT/godot/dierenhotel/build/web}"
GZIP_AAN=0
if [ "${1:-}" = "--gzip" ]; then
  GZIP_AAN=1
  shift
fi
POORT="${1:-${POORT:-8642}}"

if [ ! -f "$MAP/index.html" ]; then
  echo "FOUT: $MAP/index.html ontbreekt — draai eerst tools/export.sh"
  exit 1
fi
if [ "$GZIP_AAN" -eq 0 ]; then
  echo "serveert $MAP op http://127.0.0.1:$POORT/index.html  (ctrl-c stopt)"
  exec python3 -m http.server "$POORT" --bind 127.0.0.1 --directory "$MAP"
fi
echo "serveert $MAP met gzip op http://127.0.0.1:$POORT/index.html  (ctrl-c stopt)"
exec python3 - "$MAP" "$POORT" <<'PY'
import functools
import gzip
import http.server
import io
import os
import sys

MAP, POORT = sys.argv[1], int(sys.argv[2])
INGEPAKT = {}


class Gzip(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                      ".wasm": "application/wasm", ".js": "text/javascript",
                      ".json": "application/json", ".pck": "application/octet-stream"}

    def end_headers(self):
        self.send_header("Cache-Control", "max-age=600")
        super().end_headers()

    def send_head(self):
        pad = self.translate_path(self.path)
        if os.path.isdir(pad):
            pad = os.path.join(pad, "index.html")
        if ("gzip" not in self.headers.get("Accept-Encoding", "") or not os.path.isfile(pad)
                or pad.endswith(".png")):
            return super().send_head()
        sleutel = (pad, os.stat(pad).st_mtime)
        if sleutel not in INGEPAKT:
            with open(pad, "rb") as f:
                INGEPAKT[sleutel] = gzip.compress(f.read(), 6)
        data = INGEPAKT[sleutel]
        self.send_response(200)
        self.send_header("Content-Type", self.guess_type(pad))
        self.send_header("Content-Encoding", "gzip")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Vary", "Accept-Encoding")
        self.end_headers()
        return io.BytesIO(data)


http.server.ThreadingHTTPServer(("127.0.0.1", POORT),
                                functools.partial(Gzip, directory=MAP)).serve_forever()
PY
