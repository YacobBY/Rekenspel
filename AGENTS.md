# AGENTS.md — Dierenhotel Kwispelsteeg (Godot 4.7 port)

Project knowledge for the coding agent. Read this instead of scanning the tree:
it names every file that matters, the commands, the contracts and the traps.
Written 2026-09-16 against `main` (suite: 393 tests, 0 failures, ≈ 95 s).

## 0. Tool rules and skills (read first)

Skills live in `.dsh/skills/` and load with the `skill` tool: `dh-tools` (which
tool for what — load it first on every task), `dh-tests`, `dh-minigame`,
`dh-screenshot`, `dh-export`, `dh-spec`, `dh-commit`. They contain the
procedures; this file contains the facts.

- `read`/`grep`/`glob`/`edit`/`write` for files (an `edit` needs a `read` of that
  file first); `bash` with `workdir` for commands (fresh shell per call);
  commands over ~60 s (full suite, export, probe, kiek) as `run_in_background`
  + one `job_output` with `wait: true`; `read_image` to look at a PNG.
- Do not use `subagent`, `workflow`, `ralph`, `web_search`, `web_fetch`.
- At most 8 read/grep calls before the first edit when the task names the
  files; do not read ANALYSIS/HANDOFF/IDEAS/ledger unless asked.
- A picture of a room or game: `node tools/kiek.js --kamer zwembad --tik spel_zwembad`
  (see `dh-screenshot`), never a hand-written browser script.
- **Always show the owner an image of a change when you finish, if the change
  is visible in the world.** After the tests pass and the export is rebuilt,
  take a screenshot of the affected room/game with `kiek.js` and present it
  (the `present` tool) before reporting done — the owner wants to *see* what
  changed, not just read about it. Skip only when the change has nothing to
  show (pure maths/logic, no visual difference).

## 1. What this is

A tablet maths game for Dutch children of 6–9 (groep 3–5): a voxel **animal
hotel** in which every number lives in the world (biscuits in a bag, beds in a
room, coins on a counter, hands on a clock). No quiz screens, no punishment, no
reading required. Ten minigames, eight rooms, a day cycle with guests, wishes,
check-in and a bill at checkout. Exported to the web (GitHub Pages, PWA).

The design contract the code must keep serving (details: `ANALYSIS.md` §1,
`HOTEL.md`):

1. **One scale rule.** Every sum derives from N = number of guests
   (`T = k·N + r`); the band (groep 3/4/5) comes from an adaptive signal
   (`State.band()`, `State.tel(goed, ms)`). Right or wrong never buys access,
   only the size of the next sum.
2. **The loop closes through furniture.** Maths → coins → beds → more guests →
   bigger N → harder sums. Stars reward participation, coins come from maths.
3. **Never punishing.** No red X, no timers except a 2 s help window on
   memorisation items, wrong answers get a worked example.
4. **No reading required.** Every card sentence ≤ 8 words AND ≤ 40 characters,
   pictogram AND word on every button, answers are one tap on a strip of at
   most four choices. There is **no keypad** (removed 2026-09-14).
5. **Curriculum honesty** (`IDEAS.md`): 7×8 is groep 5, no comma money before
   groep 5, no column arithmetic, realistic euro denominations.

## 2. Repository layout

```
godot/dierenhotel/        THE GAME (Godot 4.7.2, GDScript). Everything you edit is here.
  project.godot           10 autoloads, GL Compatibility, 1024×768 canvas_items/expand
  autoload/               Art Rooms Hits World Snd Ui State Econ Games Hotel (see §4)
  core/sommen.gd          FROZEN number core, byte-identical to the HTML original (see §6)
  core/jsgetal.gd         JavaScript integer semantics, reproduced exactly
  spel/minigame.gd        MiniGame base class — the contract of every game (see §5)
  spel/ctx.gd             SpelCtx — the one object a game receives
  games/<id>/spel.gd      the ten games (+ spel.tscn, test_<id>.gd, sometimes modellen.gd)
  games/_voorbeeld/       reference game: copy its shape; it is a `stub` (never shown)
  ui/                     kaart, keuzestrook, afleiders, wolk, hud, kamerbalk, blad, thema, teksten …
  hotel/prikbord.gd       task board (≤ 3 cards);  hotel/rekening.gd  the checkout bill
  scenes/main.gd          the shell (boots the world, owns the `[probe] …` lines)
  scenes/kamer.gd dier.gd vloer.gd wereldobject.gd   the room in view
  art/                    voxel models (decor, gasten, vorm, vloer, effect)
  tests/                  runner + shell tests; tests/gouden/ = golden images + sound oracle
  tools/test.sh           the suite (run via ../../tools/test.sh)
  build/web/              export output (gitignored)
tools/                    import.sh test.sh export.sh serve.sh probe.js  (the CI commands, §3)
.github/workflows/        test.yml (import+suite+export on push), pages.yml (deploy)
.fanout/specs/godot/      BINDING DESIGN: architecture.md, world.md, games-a.md, games-b.md,
                          art-sound-rules.md, toolchain.md (≈ 9 000 lines; grep, do not read whole)
.fanout/tickets/godot/    the tickets the port was built from
(demos/ removed 2026-09-16 at the owner's request; the HTML/JS original and the
 two older prototypes are in git history at 7945251 — `git show 7945251:demos/dierenhotel/state.js`)
HANDOFF.md                state of the port, verification status, known limits, gotchas
ANALYSIS.md               2026-09-15 analysis: shortfalls + prioritised improvements (§4), and
                          §5 "things deliberately NOT to change"
HOTEL.md                  game design; §9 = the rules for every child-facing text
IDEAS.md                  curriculum table (groep 3/4/5) and design traps
main.py                   PyCharm leftover, ignore
```

## 3. Commands (run from the repository root)

| command | does | time |
|---|---|---|
| `tools/test.sh` | whole headless suite, own `user://`, fails on ANY engine ERROR line | ≈ 95 s |
| `DH_TEST_FILTER=zwembad tools/test.sh` | only test files whose name contains the filter | 5–20 s |
| `tools/import.sh` | headless import pass, gated on ERROR lines | ≈ 20 s |
| `tools/export.sh` | release web export → `godot/dierenhotel/build/web/` (≈ 41 MB) | ≈ 60 s |
| `tools/serve.sh [port]` | static server on 8642 for the export | — |
| `node tools/probe.js --viewport 1024x768@2:ipad --knop bel` | chromium finger probe of the export, screenshots + rapport.json | ≈ 60 s |
| `node tools/kiek.js --kamer zwembad --tik spel_zwembad` | one screenshot of one room/game of the export (serves build/web itself, seeds a save) | ≈ 40 s |

Godot is `~/.local/bin/godot` (4.7.2.stable); set `GODOT=` if it is not on
`PATH`. Export templates: `~/.local/share/godot/export_templates/4.7.2.stable/`.
Playwright for probe.js: `/home/pc/work/ergomouse/node_modules/playwright`.

Sandbox rules (the agent may only write inside this workspace and `/tmp`):

- Godot writes editor settings to `$XDG_CONFIG_HOME/godot` on every run; when
  that is denied it logs an ERROR that trips the export gate. `tools/export.sh`
  already sets `XDG_CONFIG_HOME=/tmp/godot-config`. For a raw `godot` call do
  the same. NEVER redirect `HOME` or `XDG_DATA_HOME` for an export: the templates
  live in the real home. There is no `--user-data-dir` flag in Godot 4.7.
- `tools/test.sh` and `probe.js` work unchanged in the sandbox.
- Never run the suite and an export at the same time in one checkout (shared
  `.godot/` cache; it crashed the suite once).
- Do not commit or push unless asked. Never commit `.godot/` or `build/web/`.

Workflow for a change: read the game's `spel.gd`, its `test_<id>.gd` and the
matching spec section (`games-a.md` for bedden/sleutels/meubels/tobbe/voerkar,
`games-b.md` for zwembad/wekker/hinkel/was/kraam) → edit → run
`DH_TEST_FILTER=<id> tools/test.sh` → run the full `tools/test.sh` before you
report done. Add or adapt tests in the game's own test file.

## 4. Architecture: the ten autoloads

All identifiers are Dutch. `x`/`z` are floor coordinates in voxels, `y` is
height; rooms have walls at x = 0 and z = 0. Public functions listed are the
ones a game or a feature normally needs.

| autoload | owns | key API |
|---|---|---|
| `Art` | voxel models, baking to plates (`Plaat`), golden-image cache | `registreer_model(naam, fn)` (namespace with your game id), `model`, `plaat`, `bak`, `dier(kind, pose, g)` |
| `Rooms` | the eight rooms as data (`Kamer`), doors, paths, furniture slots | `get_kamer(id)`, `plek(kamer, fx, fz)`, `deur`, `pad(van, naar)`, `om_het_water`, `meubel_zet/meubel_weg/meubels`, `slots/slot`, `vrij_vak` |
| `Hits` | the hotspot layer: buttons/drop targets on world objects, band grid, 0 % overlap | `maak(o)`, `weg(id)`, `wis_eigenaar(door)`, `leen/geef_terug`, `spot(id)`, `dekking(id)`, `lijst()`; signal `hotspot_getikt` |
| `World` | camera/room in view, guests (`Dier`), movement, decor, particles | `naar(kamer)`, `kamer_nu()`, `dier(id)`, `dieren(kamer)`, `await stappen(id, punten)`, `await ga(id, x, z)`, `reis(id, kamer)`, `slaap`, `pose`, `mood`, `decor(kamer, o)`, `decor_weg`, `zet_bak`, `spetter(kamer, x, z, n, kl)`, `scherm(x, z, y)`; signals `kamer_veranderd`, `getekend`, `reis_gestart` |
| `Snd` | 18 procedural sounds + per-room ambience loops | `tik plop ja hoera bel deur kar munt ster plons au klok hup tover dag brief terug zacht`, `sfeer(kamer)`, `dempt()` |
| `Ui` | cards, bubbles, strips, toasts, sheets, theme, text rules | `somkaart(obj, som, o)`, `wolk(o)`, `wolk_weg`, `getal_tag(obj, n)`, `bron(obj, o)`, `toast(tekst)`, `blad_open/blad_dicht`, `naamplaat`, `keur_regel(id, zin)` |
| `State` | the save (`State.s`, JSON in `user://dierenhotel.json`, atomic), band | `bewaar()`, `lees()`, `nieuw_spel()`, `spel_data(id)`, `band()`, `tel(goed, ms)`, `n_gasten()`, `max_gasten()`, `bed_vrij()`, `gasten_in(kamer)` |
| `Econ` | stars, coins, the bill | `sterren(n)`, `geef_munt(n)`, `buidel(totaal)`, `splits(n)`, `rekening(o)`; signals `sterren_veranderd`, `munten_veranderd` |
| `Games` | registry of minigames, start/stop/supersede | `lijst()`, `definitie(id)`, `actief()`, `ontgrendeld(id)`, `start(id)`, `stop()`, `hersteek()`; signals `spel_gestart`, `spel_gestopt` |
| `Hotel` | day cycle, wishes, board, check-in, evening round, letters, hotel buttons | `start()`, `bel()`, `morgen()`, `avondronde()`, `taak_af(id)`, `spel_taken()`, `wens_af(gast, welke)`, `komt_eraan()`, `hotspots()`, `naar_kamer(id)` |

Rooms (`Rooms.lijst()`): `receptie` (desk top-right, door top-left), `gang`,
`kamer1`, `kamer2`, `keuken`, `tuin` (outdoor, zones `hinkel` and `kraam`),
`zwembad` (outdoor since 2026-09-14; `bad` rect = the lane), `wasserij`.
Guests: four kinds, fifteen poses (`art/gasten.gd`); ids like `gast1`.

## 5. The minigame contract (`spel/minigame.gd`, architecture.md §5–6)

A game = `res://games/<id>/spel.tscn` whose root script `extends MiniGame`.
The directory name IS the game id. Lifecycle:

- `definitie() -> Dictionary` — read once at boot, scene NOT in the tree. Keys:
  `naam`, `kamer`, `hotspot {obj, icoon, label, hoog, dx, dz, blijf}`,
  `unlock: Callable(N, band) -> bool`, `wens`, `stub`, `taak {id, icoon, tekst, wanneer, kamer, prio}`.
- `start(ctx)` — build the turn; the camera is already in `kamer`.
- `stop()` — clean up; called on supersede, on `ctx.sluit()` and when the child
  taps another task card. Always before the node is freed.
- `avond()` — optional, evening round started while playing.

Rules (all enforced by review and by the tests):

- `_ready()` may not touch the world.
- After EVERY `await`, check `actief` (`if not actief: return`).
- Delays: `if not await na(1.2): return` — never a raw `SceneTreeTimer`.
- Store the turn in `ctx.data()` (its own drawer in the save) after every step
  a reload must survive; awaits and timers do not survive a reload.
- Everything visible goes through `ctx` so it carries the game's owner stamp and
  disappears on stop: `ctx.hotspots.maak(o)`, `ctx.hotspots.pak(id, fn)` (borrow
  a hotel button), `ctx.ui.somkaart(obj, som, o)`, `ctx.ui.wolk(o)`,
  `ctx.ui.getal_tag(obj, n)`, `ctx.ui.toast(t)`, `ctx.wereld.decor(kamer, o)`.
- Own voxel models: `Art.registreer_model("<id>_naam", fn)`.
- End of a turn: `ctx.taak_klaar(taak_naam)` (one star for taking part, task
  ticked, save written — never for being right) then `ctx.sluit()`.
- Feed the adaptive band once per turn: `ctx.state.tel(first_try_ok, ms)` —
  every game does this itself at the end of a turn (first-try semantics: `goed`
  is "zero misses", `ms` is measured from the turn's `_t0`).

`ctx.ui.somkaart(obj, som, o)`: `o.regel` is MANDATORY — one plain Dutch
sentence with a verb or question word, pictogram first, ≤ 8 words and ≤ 40
characters (violations still draw but log a warning; `Ui.keur_regel` checks
it). Give either `keuzes` (≤ 4, each `{id, icoon, tekst, kort, kies}`) or
`goed: n` (+ optional `liever`, `min`, `max`): then `ui/afleiders.gd` builds a
strip of four numbers and `on_ok(n, kaart)` fires on the tap. `kaart.zet(str)`,
`kaart.klaar()`.

Sounds: `ctx.snd.plop(i)`, `ja()`, `hoera()` … Particles: `World.spetter`.

## 6. The ten games

| id | naam | room | teaches | spec |
|---|---|---|---|---|
| `bedden` | Bedden op rij | kamer1/kamer2 | equal rows, multiplication as arrays | games-a §3 |
| `sleutels` | Het sleutelbord | receptie | number line / neighbours (missing numbers on a key board) | games-a §4 |
| `meubels` | Het meubelboek | receptie → room | money, the growth loop (buy beds/furniture) | games-a §5 |
| `tobbe` | Tobbe-tijd | tuin | fair sharing (division) of soap scoops | games-a §6 |
| `voerkar` | De voerkar | keuken → rooms | k·N biscuits, filling and distributing bowls; reference for HOTEL.md §9 | games-a §7 |
| `zwembad` | Zwembad | zwembad | the pool is a number line 0…L; lanes vary per day (`Sommen.Zwembad`) | games-b §1 |
| `wekker` | De wekkerdienst | gang | clock reading; ghost hands at the 2nd miss | games-b §2 |
| `hinkel` | Hinkelpad | tuin (zone hinkel) | number line of stepping stones 0…E | games-b §3 |
| `was` | Wasmandtoren | wasserij | sorting/tallying into crates, bar chart | games-b §4 |
| `kraam` | Souvenirkraam | tuin (zone kraam) | money, paying and change | games-b §5 |

Each has `test_<id>.gd` next to it (200–1000 lines, run headless with shells
at four viewports). Owner's rules for zwembad are verbatim in games-b §1.

**`core/sommen.gd` is frozen**: it reproduces the HTML `state.js` (git
history, 7945251) byte for byte; `tests/test_sommen_kruis.gd` holds a fingerprint over 23 042
differential cases. Changing a number rule means changing the rule, the test
fingerprint and the spec together — do it only when asked, never by accident.
Per-game maths lives in the classes `Sommen.Zwembad`, `.Wekker`, `.Hinkel`,
`.Was`, `.Kraam`, `.Sleutels`, `.Tobbe`, `.Bedden`, `.Meubels`, `.Voerkar`.

## 7. Tests

- Runner: `tests/run_tests.gd` loads every `tests/test_*.gd` and every
  `games/<id>/test_*.gd`; each `test_*` method runs on a fresh instance.
- Helpers (`tests/proef.gd`): `gelijk(gekregen, verwacht, wat)`, `waar(v, wat)`,
  `fout(melding)`, `verwacht_fout(n)` (announce n deliberate engine errors —
  exact, not a maximum), `alleen_spellen(ids)` (narrow the registry; restored
  after each test).
- **Any engine ERROR during a test fails it**, and `tools/test.sh` greps
  stderr for the same. A silent `SCRIPT ERROR` can never pass as `ok`.
- The runner buffers stdout: a crash loses every `ok` line; bisect with
  `DH_TEST_FILTER=<file part>`.
- Warnings (`push_warning`) are not failures.

## 8. Facts that cost time to rediscover (HANDOFF.md §7 + toolchain.md)

- `user://` is per project name: parallel runs share one save unless
  `XDG_DATA_HOME`/`DH_USERDATA` is set (test.sh does this).
- `set_anchors_preset` keeps offsets: a code-built full-rect Control stays 0×0;
  use `set_anchors_and_offsets_preset`.
- A word-wrapping Label reports its longest word as minimum width and can loop
  the layout inside the shell; the room bar uses ARBITRARY wrap on purpose.
- `Games.registreer` writes into `Games._defs`; tests narrow it with
  `Proef.alleen_spellen`.
- Godot `--script` SceneTree scripts cannot name autoloads at compile time; use
  `root.get_node("State")`.
- URL save hook: `index.html?opslag=<base64url of a complete save JSON>` writes
  the save before it is read (base64url: `-`/`_`; `uri_decode()` turns `+` into
  a space). Make the JSON with a headless script: `State.nieuw_spel()`, set
  fields, `State.bewaar()`, print `user://dierenhotel.json`.
- Godot refuses to create the export folder (export.sh does); `build/.gdignore`
  must stay or the next import eats the exported PNGs.
- `index.service.worker.js` carries a timestamped `CACHE_VERSION`: never
  checksum-gate it.
- Glyphs not in the bundled fonts (Nunito, Noto Symbols 2, Noto Color Emoji)
  do not render: `Ui.mist_tekens(zin)` tells you; tobbe/voerkar use 🔄 and ▸
  for that reason.
- Headless shell at 296×314 segfaults (pre-existing, no such device).

## 9. Current state and backlog (2026-09-16)

- Everything is on `main`; pushed to origin. GitHub Pages deploy fails until
  the owner sets Settings → Pages → Source = "GitHub Actions" (owner action).
- Never tested on a real iPad/Android: chromium device emulation only.
- 8 of 10 games were never blind-verified (HANDOFF §5).
- Known cosmetic limit: landscape phones (740×360) cut long words in the room
  bar.
- Improvement backlog with priorities: `ANALYSIS.md` §4 (a: the growth loop
  dead-ends after ~10 guests; b: 6 of 16 catalogue games unbuilt; c: timing in
  the adaptive signal; d: first-morning guidance; e: shipping risks). Read §5
  there before changing anything it lists as deliberately kept.

## 10. Where to look for more

- Game contract, scene tree, hotspot rules: `architecture.md` §5–6 (lines ≈ 830–1170).
- Save format: `architecture.md` §9. Sound: §8. Web export/CI: §7.
- Hotspot option keys: `world.md` §5.4; card/bubble/tag keys: §5.5–5.6; room data: §1.
- Every child-facing string the shell owns: `godot/dierenhotel/ui/teksten.gd`.
- Text rules for children: `HOTEL.md` §9. Curriculum: `IDEAS.md`.
- Append-only build log of the port: `.fanout/ledger.md`.
