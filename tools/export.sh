#!/usr/bin/env bash
# tools/export.sh — the release web export (architecture.md §7.3, §14.2).
#
# Creates build/web first (Godot does not, T0 gotcha G1), keeps build/.gdignore
# in place (T0 gotcha G2: without it the next import eats the exported PNGs back
# into the project) and gates on every engine ERROR line.
# Afterwards (W2, 2026-10-09) it checks that the page is the project's own shell
# (godot/dierenhotel/web/shell.html) and completes the PWA manifest for Android
# (short_name, scope, id, theme_color, 192 px + maskable icons); needs python3.
#
#   tools/export.sh                       # -> godot/dierenhotel/build/web/index.html
#   tools/export.sh /tmp/elders/index.html
#   PRESET=Web GODOT=/path/to/godot tools/export.sh
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROJ="$ROOT/godot/dierenhotel"
GODOT="${GODOT:-godot}"
# Godot writes its editor settings to $XDG_CONFIG_HOME/godot on every run; the
# agent sandbox denies writes to ~/.config, which trips the ERROR gate below.
# Redirect ONLY the config dir: moving HOME/XDG_DATA_HOME too would hide the
# export templates in ~/.local/share/godot and break the export outright.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${TMPDIR:-/tmp}/godot-config}"
PRESET="${PRESET:-Web}"
DOEL="${1:-build/web/index.html}"
LOG_DIR="${DH_LOG_DIR:-${TMPDIR:-/tmp}/dierenhotel-log}"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/export.log"

command -v "$GODOT" >/dev/null 2>&1 || { echo "FOUT: godot niet gevonden (zet GODOT=)"; exit 127; }

# The export path may be relative to the project (Godot's own rule) or absolute.
case "$DOEL" in
  /*) UITMAP="$(dirname -- "$DOEL")" ;;
  *)  UITMAP="$PROJ/$(dirname -- "$DOEL")" ;;
esac
mkdir -p "$UITMAP"
[ -e "$PROJ/build/.gdignore" ] || : > "$PROJ/build/.gdignore"

"$GODOT" --headless --path "$PROJ" --export-release "$PRESET" "$DOEL" > "$LOG" 2>&1
code=$?
cat "$LOG"
if grep -qE '^(USER )?(SCRIPT )?ERROR:' "$LOG"; then
  echo "FOUT: de motor logde fouten tijdens de export (zie hierboven)"
  code=1
fi

STAM="$(basename -- "$DOEL" .html)"
for f in "$STAM.html" "$STAM.wasm" "$STAM.pck" "$STAM.js"; do
  if [ ! -f "$UITMAP/$f" ]; then
    echo "FOUT: $UITMAP/$f ontbreekt na de export"
    code=1
  fi
done

# The OFL licences of the bundled fonts travel inside the pck (export_presets.cfg
# include_filter="fonts/*.txt"); copy them beside index.html as well, so they are
# readable on the deployed site without unpacking the game.
if [ "$code" -eq 0 ]; then
  licenties=0
  for lic in "$PROJ"/fonts/OFL-*.txt; do
    [ -f "$lic" ] || continue
    cp -f "$lic" "$UITMAP/"
    licenties=$((licenties + 1))
  done
  if [ "$licenties" -eq 0 ]; then
    echo "let op: geen fonts/OFL-*.txt gevonden om naast index.html te zetten"
  else
    echo "OK: $licenties OFL-licentie(s) naast $STAM.html gezet"
  fi
fi

# The page for phones and tablets (W2, 2026-10-09): the preset's own shell
# (godot/dierenhotel/web/shell.html) must really be the page, and the manifest
# Godot writes is completed for Android — short name, scope, id, theme colour,
# a 192 px icon and maskable icons (a launcher cuts its own shape out of them).
# Godot cannot write those fields itself; everything stays relative, so a
# project page under https://<user>.github.io/<repo>/ keeps working.
WEB="$PROJ/web"
if [ "$code" -eq 0 ]; then
  if ! grep -q 'dierenhotel-shell' "$UITMAP/$STAM.html"; then
    echo "FOUT: $STAM.html is niet de eigen shell (html/custom_html_shell in export_presets.cfg)"
    code=1
  fi
fi
if [ "$code" -eq 0 ]; then
  for paar in "icoon-192.png:$STAM.192x192.png" "icoon-maskable-192.png:$STAM.maskable.192x192.png" \
      "icoon-maskable-512.png:$STAM.maskable.512x512.png"; do
    if ! cp -f "$WEB/${paar%%:*}" "$UITMAP/${paar#*:}"; then
      echo "FOUT: $WEB/${paar%%:*} ontbreekt"
      code=1
    fi
  done
fi
if [ "$code" -eq 0 ]; then
  if ! command -v python3 >/dev/null 2>&1; then
    echo "FOUT: python3 ontbreekt — het manifest kan niet worden aangevuld"
    code=1
  elif ! python3 - "$UITMAP/$STAM.manifest.json" "$STAM" <<'PY'
import json
import sys

pad, stam = sys.argv[1], sys.argv[2]
with open(pad, encoding="utf-8") as f:
    m = json.load(f)
m.update({
    "name": "Dierenhotel Kwispelsteeg",
    "short_name": "Dierenhotel",
    "description": "Rekenen in een dierenhotel, voor groep 3 tot 5.",
    "lang": "nl",
    "dir": "ltr",
    "id": "./%s.html" % stam,
    "start_url": "./%s.html" % stam,
    "scope": "./",
    "display": m.get("display", "standalone"),
    "orientation": m.get("orientation", "any"),
    "background_color": m.get("background_color", "#fff7ec"),
    "theme_color": m.get("background_color", "#fff7ec"),
    "categories": ["education", "games", "kids"],
})
iconen = [i for i in m.get("icons", []) if i.get("sizes") != "192x192"]
for i in iconen:
    i.setdefault("purpose", "any")
iconen += [
    {"src": "%s.192x192.png" % stam, "sizes": "192x192", "type": "image/png", "purpose": "any"},
    {"src": "%s.maskable.192x192.png" % stam, "sizes": "192x192", "type": "image/png", "purpose": "maskable"},
    {"src": "%s.maskable.512x512.png" % stam, "sizes": "512x512", "type": "image/png", "purpose": "maskable"},
]
iconen.sort(key=lambda i: (i["purpose"], int(i["sizes"].split("x")[0])))
m["icons"] = iconen
with open(pad, "w", encoding="utf-8") as f:
    json.dump(m, f, ensure_ascii=False, indent=1)
    f.write("\n")
print("OK: manifest aangevuld (%d iconen, maskable erbij)" % len(iconen))
PY
  then
    echo "FOUT: het manifest $UITMAP/$STAM.manifest.json kon niet worden aangevuld"
    code=1
  fi
fi

if [ "$code" -eq 0 ]; then
  aantal=$(find "$UITMAP" -maxdepth 1 -type f | wc -l)
  bytes=$(du -sb "$UITMAP" | cut -f1)
  wasm=$(stat -c%s "$UITMAP/$STAM.wasm")
  pck=$(stat -c%s "$UITMAP/$STAM.pck")
  echo "OK: export zonder fouten — $aantal bestanden, $bytes B in $UITMAP"
  echo "    $STAM.wasm $wasm B · $STAM.pck $pck B · log: $LOG"
  # What really goes over the line: GitHub Pages compresses on the fly (gzip;
  # it does NOT serve pre-compressed .gz/.br files), so nothing is pre-packed
  # here — this line only says how big the download is for a phone.
  if command -v gzip >/dev/null 2>&1; then
    over=0
    for f in "$STAM.wasm" "$STAM.pck" "$STAM.js" "$STAM.html"; do
      over=$((over + $(gzip -6 -c "$UITMAP/$f" | wc -c)))
    done
    echo "    over de lijn met gzip: $over B (wasm + pck + js + html)"
  fi
  # index.service.worker.js has a timestamped CACHE_VERSION: never checksum-gate it (T0 G3).
fi
exit "$code"
