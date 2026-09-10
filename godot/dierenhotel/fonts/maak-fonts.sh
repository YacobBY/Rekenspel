#!/usr/bin/env bash
# Build the three bundled subsets from `fonts/tekens.txt` (architecture.md §7.5).
#
#   fonts/maak-fonts.sh
#
# Needs fonttools (`pip install fonttools brotli`) and the three upstream files;
# it downloads Nunito and Noto Sans Symbols 2 from google/fonts and takes Noto
# Color Emoji from the system font directory (or $EMOJI_TTF).  All three are
# SIL OFL 1.1; the licences are next to the fonts.
#
# W3 note: architecture.md §7.5 names this script `tools/emoji-subset.sh`.  It
# lives here instead because `tools/` is not in W3's write set and this script
# builds the text subset as well, not only the emoji one.
set -euo pipefail
hier="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
werk="${TMPDIR:-/tmp}/dh-fonts"
mkdir -p "$werk"

haal() {  # haal <url> <doel>
  [ -s "$2" ] || curl -sSL --retry 3 -o "$2" "$1"
}
haal "https://github.com/google/fonts/raw/main/ofl/nunito/Nunito%5Bwght%5D.ttf" "$werk/Nunito.ttf"
haal "https://github.com/google/fonts/raw/main/ofl/notosanssymbols2/NotoSansSymbols2-Regular.ttf" "$werk/Symbols2.ttf"
haal "https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/OFL.txt" "$hier/OFL-Nunito.txt"
haal "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssymbols2/OFL.txt" "$hier/OFL-NotoSansSymbols2.txt"
haal "https://raw.githubusercontent.com/googlefonts/noto-emoji/main/fonts/LICENSE" "$hier/OFL-NotoColorEmoji.txt"
emoji="${EMOJI_TTF:-/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf}"
[ -f "$emoji" ] || { echo "geen Noto Color Emoji gevonden ($emoji); zet EMOJI_TTF" >&2; exit 1; }

python3 - "$hier" "$werk" "$emoji" <<'PY'
import subprocess, sys, re
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

hier, werk, emoji = sys.argv[1], sys.argv[2], sys.argv[3]

def lees(pad):
    vak, uit = None, {"tekst": [], "symbolen": [], "emoji": []}
    for regel in open(pad, encoding="utf-8"):
        regel = regel.split("#")[0].strip()
        if not regel:
            continue
        kop = re.fullmatch(r"\[(\w+)\]", regel)
        if kop:
            vak = kop.group(1); continue
        if vak:
            uit[vak].extend(regel.split())
    return uit

def subset(bron, doel, punten, extra=()):
    subprocess.run(["python3", "-m", "fontTools.subset", bron,
        "--unicodes=" + ",".join(punten), "--output-file=" + doel,
        "--layout-features=*", "--name-IDs=*", "--notdef-outline",
        "--drop-tables+=DSIG", *extra], check=True)

vak = lees(hier + "/tekens.txt")

# Nunito is a variable font: pin one static instance per weight, then subset.
for naam, gewicht in (("Regular", 400), ("Bold", 700)):
    var = TTFont(werk + "/Nunito.ttf")
    instancer.instantiateVariableFont(var, {"wght": gewicht}, inplace=True, updateFontNames=True)
    tijd = "%s/Nunito-%s-vol.ttf" % (werk, naam)
    var.save(tijd)
    subset(tijd, "%s/Nunito-%s.ttf" % (hier, naam), vak["tekst"])

subset(werk + "/Symbols2.ttf", hier + "/Symbolen.ttf", vak["symbolen"])
# The CBDT/CBLC colour bitmap strikes are subsetted with the glyphs: 24 MB -> ~200 kB.
subset(emoji, hier + "/Emoji.ttf", vak["emoji"])
PY

ls -l "$hier"/*.ttf
