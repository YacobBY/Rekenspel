---
name: dh-screenshot
description: Make and look at a screenshot ("foto") of any room or game of the exported web build with one command (tools/kiek.js), then show it to the user.
whenToUse: The user asks for a picture, screenshot, "foto", "laat zien", or you want to see how something renders.
---

# The one command

```bash
# fresh build first when .gd files changed since the last export (60–90 s → background job)
tools/export.sh 2>&1 | tail -3
# the picture (≈ 30–60 s; background job + job_output wait if in doubt)
node tools/kiek.js --kamer zwembad --tik spel_zwembad --wacht 4000 --uit /tmp/kiek
```

Options: `--kamer receptie|gang|kamer1|kamer2|keuken|tuin|zwembad|wasserij`,
`--tik <hotspot id>` (taps it and takes a third picture; the tool prints the
hotspot ids it saw, e.g. `bel prikbord spel_zwembad deur_zwembad_tuin`),
`--wacht ms` (time after the tap), `--band 3|4|5` / `--gasten N` / `--dag N`
(the seeded save), `--viewport 360x740@3:telefoon` (default iPad landscape
1024x768@2). It serves `build/web` itself; no `serve.sh` needed.

Output lines: `foto: /tmp/kiek/<profiel>-1-blad.png` (start sheet),
`...-2-<kamer>.png` (the room), `...-3-<tik>.png` (after the tap), and the
verdict `KIEK OK` / `KIEK FOUT: <reason>`. `log.txt` next to them holds every
console line (`[probe] ...`).

Then: `read_image` on the PNG you want to judge, `present` the file(s) the user
asked for, and describe in two sentences what is visible. Do NOT write your own
Playwright script, do NOT look for Xvfb/`--write-movie`/`save_png`, do NOT
start the game on the desktop.

# When it fails

- `geen export` → run `tools/export.sh` first.
- `LET OP: de export is ouder dan de nieuwste .gd` → the picture shows old
  code; re-export.
- `"[probe] klaar" bleef uit` → read `log.txt` for `ERROR` lines; usually a
  GDScript error at boot from your change → fix, re-export.
- `hotspot "x" is niet gemeld` → the id does not exist in that room; use one
  from the printed list, or the room is wrong (check `--kamer`).
- A game needs guests: `--band 3` seeds 1 guest with the pool wish, `--band 4`
  seeds 4, `--band 5` seeds 7 with `kunnen: 5`.
