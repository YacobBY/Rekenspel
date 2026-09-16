#!/usr/bin/env bash
# tools/export.sh — the release web export (architecture.md §7.3, §14.2).
#
# Creates build/web first (Godot does not, T0 gotcha G1), keeps build/.gdignore
# in place (T0 gotcha G2: without it the next import eats the exported PNGs back
# into the project) and gates on every engine ERROR line.
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

if [ "$code" -eq 0 ]; then
  aantal=$(find "$UITMAP" -maxdepth 1 -type f | wc -l)
  bytes=$(du -sb "$UITMAP" | cut -f1)
  wasm=$(stat -c%s "$UITMAP/$STAM.wasm")
  pck=$(stat -c%s "$UITMAP/$STAM.pck")
  echo "OK: export zonder fouten — $aantal bestanden, $bytes B in $UITMAP"
  echo "    $STAM.wasm $wasm B · $STAM.pck $pck B · log: $LOG"
  # index.service.worker.js has a timestamped CACHE_VERSION: never checksum-gate it (T0 G3).
fi
exit "$code"
