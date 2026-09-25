# AGENTS.md — Dierenhotel Kwispelsteeg (Godot 4.7 port)

Project knowledge for the coding agent. Read this instead of scanning the tree:
it names every file that matters, the commands, the contracts and the traps.
Written 2026-09-16 against `main`; skills refreshed 2026-09-19 (suite: 470 tests, 0 failures, ≈ 205 s).

## 0. Tool rules and skills (read first)

Skills live in `.dsh/skills/` and load with the `skill` tool: `dh-tools` (which
tool for what — load it first on every task), `dh-plan` (a task from PLAN.md:
which one, what "done" means — load it on every plan task), `dh-gdscript`
(the traps, before editing any `.gd`), `dh-tests`, `dh-minigame`,
`dh-screenshot`, `dh-export`, `dh-spec`, `dh-commit` (the gate: green suite,
files by path, PLAN.md bookkeeping). They contain the procedures; this file
contains the facts.

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

### Play the game yourself, do not only test it

A green suite proves the rules hold. It does not prove a six-year-old can get
through the game. So **play it** with `tools/speel.js`, which taps a sequence of
buttons in the real export and writes a screenshot plus the game's own probe
lines after every step.

```bash
node tools/speel.js --kamer receptie --band 4 --toon      # wat valt hier te tikken?
node tools/speel.js --kamer receptie --band 4 \
  --doe "bel; wacht 4500; ci_som_keuzes#2/4" --uit tmp/speel
```

A step is a hotspot id, `chip:<naam>` for the room bar, `vw:<id>` for the OBJECT
a borrowed hotel button hangs on (the bowl or the door opening itself, as a child
taps it), `kamer_<id>` for a room in the stairs' tower sheet, or `wacht <ms>`. A strip
reports itself as ONE rectangle (`ci_som_keuzes`), so tap the k-th of n boxes
inside it with `id#k/n`, or a free spot with `id@0.5,0.8`. An unknown id stops
the run and prints what the game did report — that answer is itself a finding.

What to do with it: **play a real run of about six animals** — the loop of
maths → coins → beds → more guests — and write down, per obstacle, where a child
would be stuck and why. A dead end, a button that is never reported, a card that
asks something the screen does not show, a strip that cannot be reached: report
it in your own words, with the step and the screenshot that proves it. Findings
belong in the PLAN.md §7 line of the task you are on, or as a new `- [ ]` task
when they are bigger than the task at hand.

### Deciding for yourself instead of asking

The owner is often away for hours. A question stops the work dead, so the
default is: **pick the option you would recommend, say in one line that you
picked it and why, and carry on.** Do not open an `ask` for something you can
answer yourself.

**The hard rule: if you can name a recommended option, you do not ask — you
take it.** An `ask` whose first line is "option 1 (recommended)" is a question
you have already answered yourself. Take that option, write one line about it,
and keep working. This costs an hour of waiting every time you get it wrong.

Decide and continue when the choice is:

- reversible in code (a layout constant, a helper, a test's own scaffolding,
  which of two equivalent fixes to use);
- covered by a rule you can look up (`HOTEL.md` §9 for text, the spec section
  for the game, the design contract in §1 of this file);
- a trade-off where one option is clearly the smallest change that keeps the
  suite green and the contract intact — that one wins;
- **touching a file outside your task's file set**, including shared code
  (`autoload/ui.gd`, `autoload/hits.gd`, `ui/kaart.gd`). That is allowed and
  normal. Keep the change additive, put new candidates or branches LAST so
  every arrangement that works today keeps working, run the full suite, and
  record the deviation in the PLAN.md §7 line. Green suite = proof.

Ask ONLY when you genuinely cannot continue on your own:

- the **frozen maths core** (`core/sommen.gd`) would have to change;
- a **binding string from the spec** must be altered (spec text is law; if it
  does not fit, that is a real question);
- the answer is information that is simply not in the repository (a wish of the
  owner, a choice between two designs that both satisfy the spec equally well);
- two instructions contradict each other and you cannot tell which wins;
- the plan marks the task itself as an owner decision.

Not a reason to ask: the change is bigger than expected, it spans more files
than the task named, you are unsure whether the owner will like it, or you want
a sanity check. Do it, prove it with the suite, and write down what you did.

When you do ask: put the recommended option first, keep it to three options,
and state in one sentence what you will do if there is no answer. When you
decide for yourself: record the decision and the alternative in the PLAN.md §7
line for that task, so the owner can overrule it afterwards. An assumption
written down and moved past is worth more than a session that waits.

## 1. What this is

A tablet maths game for Dutch children of 6–9 (groep 3–5): a voxel **animal
hotel** in which every number lives in the world (biscuits in a bag, beds in a
room, coins on a counter, hands on a clock). No quiz screens, no punishment, no
reading required. Seventeen minigames (§6), the rooms as data (`Rooms.lijst()`,
eleven of them today), a day cycle with guests, wishes, check-in and a bill at
checkout, and a wardrobe: what an animal buys in the shops it wears.
Exported to the web (GitHub Pages, PWA).

The design contract the code must keep serving (details: `ANALYSIS.md` §1,
`HOTEL.md`):

1. **One scale rule.** Every sum derives from N = number of guests
   (`T = k·N + r`); the band (groep 3/4/5) comes from an adaptive signal
   (`State.band()`, `State.tel(goed, ms)`). Right or wrong never buys access,
   only the size of the next sum.
2. **The loop closes through furniture.** Maths → coins → beds → more guests →
   bigger N → harder sums. Stars reward participation, coins come from maths.
3. **Never punishing, never helping after a miss.** No red X, no timers except
   a 2 s help window on memorisation items.  A wrong answer gets NO help (owner,
   2026-09-24: "Nee geef geen hulp na fouten"): the animal of the turn is
   disappointed (`Ui.misser`: `sip` + `🔄 Nog een keer`, the strip locked for a
   moment) and the same question stays — no help line, ghost, hint or helper.
   **In the shops** (`games/_winkel`, owner 2026-09-24) a wrong amount costs
   more time instead: the animal is sent out of the shop, sulks, walks out
   slowly (`sjok`), the game closes, and the child taps the shop again to get
   the SAME question back — against quick guessing. Still no help, no star or
   coin taken away.
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
  games/<id>/spel.gd      the games (+ spel.tscn, test_<id>.gd, sometimes modellen.gd)
  games/_voorbeeld/       reference game: copy its shape; it is a `stub` (never shown)
  games/_winkel/          the shared shop game (`WinkelSpel`), its maths (beurt.gd) and its
                          tests; no spel.tscn, so the scan skips it (games-d.md)
  ui/                     kaart, keuzestrook, afleiders, wolk, hud, kamerbalk, blad, thema, teksten …
  hotel/prikbord.gd       task board (≤ 3 cards);  hotel/rekening.gd  the checkout bill
  scenes/main.gd          the shell (boots the world, owns the `[probe] …` lines)
  scenes/kamer.gd dier.gd vloer.gd wereldobject.gd   the room in view
  art/                    voxel models (decor, gasten + the wardrobe, vorm, vloer, effect)
  tools/bak_dieren.gd     contact sheet of the guests (poses × outfit) as one PNG, headless
  tests/                  runner + shell tests; tests/gouden/ = golden images + sound oracle
  tools/test.sh           the suite (run via ../../tools/test.sh)
  build/web/              export output (gitignored)
tools/                    import.sh test.sh export.sh serve.sh probe.js  (the CI commands, §3)
.github/workflows/        test.yml (import+suite+export on push), pages.yml (deploy)
.fanout/specs/godot/      BINDING DESIGN: architecture.md, world.md, games-a.md, games-b.md,
                          games-c.md (kas), games-d.md (winkelstraat, kleding, the animation
                          review), art-sound-rules.md, toolchain.md (grep, do not read whole)
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
| `node tools/speel.js --kamer kamer1 --band 4 --toon` | list what is tappable in a room | ≈ 40 s |
| `node tools/speel.js --kamer receptie --band 4 --doe "bel; wacht 4500; ci_som_keuzes#2/4"` | PLAY: tap a sequence, screenshot + report after every step | ≈ 60 s |

Godot is `~/.local/bin/godot` (4.7.2.stable); set `GODOT=` if it is not on
`PATH`. Export templates: `~/.local/share/godot/export_templates/4.7.2.stable/`.
Playwright for probe.js: `/home/pc/work/ergomouse/node_modules/playwright`.

Sandbox rules (write ONLY inside this workspace — never outside it):

- **Every log, screenshot and scratch file goes in `tmp/` in this repository**,
  never in `/tmp`. `tmp/` is git-ignored, so it never shows up in a commit.
  Use it like this, always with a relative path from the repository root:

  ```bash
  mkdir -p tmp/log
  DH_TEST_FILTER=sleutels tools/test.sh > tmp/log/k1.log 2>&1; echo "exit=$?"
  DH_LOG_DIR=tmp/log tools/export.sh                 # export + import logs
  node tools/kiek.js --kamer keuken --uit tmp/kiek   # screenshots
  ```

  `tools/import.sh`, `tools/export.sh`, `probe.js` and `kiek.js` all read
  `DH_LOG_DIR` and create the directory themselves; without it they fall back to
  `/tmp/dierenhotel-log`, which is outside the workspace. So pass `DH_LOG_DIR`.
  Writing outside the workspace costs an approval prompt and stalls the run
  until a human answers it; staying in `tmp/` keeps you going.
- Godot writes editor settings to `$XDG_CONFIG_HOME/godot` on every run; when
  that is denied it logs an ERROR that trips the export gate. `tools/export.sh`
  sets this itself, so a plain `tools/export.sh` needs nothing. For a raw
  `godot` call set `XDG_CONFIG_HOME=$PWD/tmp/godot-config` yourself. NEVER
  redirect `HOME` or `XDG_DATA_HOME` for an export: the templates live in the
  real home. There is no `--user-data-dir` flag in Godot 4.7.
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
| `Rooms` | the rooms as data (`Kamer`, `lijst()` counts them), doors, paths, furniture slots | `get_kamer(id)`, `plek(kamer, fx, fz)`, `deur`, `pad(van, naar)`, `om_het_water`, `meubel_zet/meubel_weg/meubels`, `slots/slot`, `vrij_vak`, `ingang(kamer)` (the receptie's front door, outside the door graph), floors: `etage(kamer)`, `etages()` (top down), `op_etage(e)`, `trap_kamers()`, `trap_kamer(e)`, `via_trap(van, naar)`, `trap_punt(kamer)`, `buren(kamer)` |
| `Hits` | the hotspot layer: buttons/drop targets on world objects, band grid, 0 % overlap; the hotel's buttons (doors, stairs, bell, board, game entries, bowls) choose their place against what stands STILL — a walking guest moves none of them, one who stands on a place for 8 ticks makes it step aside once (2026-09-24, `tests/test_knoppen_staan_stil.gd`); name plates give way to them; a hotspot made with `tik_vlak` (the hotel's bowls and doors, 2026-09-25) also takes a tap on its OBJECT — its catch area presses the button (`Hits.tik_onder`) | `maak(o)`, `weg(id)`, `wis_eigenaar(door)`, `leen/geef_terug`, `spot(id)`, `dekking(id)`, `lijst()`; signal `hotspot_getikt` |
| `World` | camera/room in view, guests (`Dier`), movement, decor, particles | `naar(kamer)`, `kamer_nu()`, `dier(id)`, `dieren(kamer)`, `await stappen(id, punten)`, `await ga(id, x, z)`, `reis(id, kamer)`, `kom_binnen(id, x, z)` (a new guest through the front door, per kind), `vlak_van_ingang()`, `slaap`, `pose`, `mood`, `decor(kamer, o)`, `decor_weg`, `zet_bak`, `spetter(kamer, x, z, n, kl)`, `scherm(x, z, y)`, `verberg_bed(kamer, slot)` (a free bed out of sight until the camera leaves the room); signals `kamer_veranderd`, `getekend`, `reis_gestart` |
| `Snd` | 18 procedural sounds + per-room ambience loops, and per guest kind a sad and a happy sound (2026-09-24) | `tik plop ja hoera bel deur kar munt ster plons au klok hup tover dag brief terug zacht`, `ding` (the desk bell), `trap(op)` (four footfalls up or down the stairs to another floor), `sfeer(kamer)`, `dempt()`; `dier_sip(wie)` (plays in `Ui.misser` and when a shop sends an animal out, instead of `zacht`), `dier_blij(wie)` (follows every `ja()` for the animal of the turn); tests listen via `gehoord()` |
| `Ui` | cards, bubbles, strips, toasts, sheets, theme, text rules | `somkaart(obj, som, o)` (`reken: true` marks a maths card without a number answer or sum line), `wolk(o)`, `wolk_weg`, `getal_tag(obj, n)`, `bron(obj, o)`, `toast(tekst)`, `blad_open/blad_dicht`, `naamplaat`, `keur_regel(id, zin)`, `is_som(id)` (while a sum is on screen the room bar and the unborrowed door signs are hidden); `maak_knop` kind `"eigen"` = a game's own Control placed by `Hits` (the wekker's big clock) |
| `State` | the save (`State.s`, JSON in `user://dierenhotel.json`, atomic), band | `bewaar()`, `lees()`, `nieuw_spel()`, `spel_data(id)`, `band()`, `tel(goed, ms)`, `n_gasten()`, `max_gasten()`, `plek_voor_gast()`, `kamers_met_plek()`, `plek_in(kamer)`, `bed_plek(kamer)`, `bed_vrij(kamer?)`, `gasten_in(kamer)`, `herstel_bedden()` — beds stand on fixed bed places per bedroom (4 each, `Rooms.meubel_zet` snaps to the next free one), so the hotel holds 8 guests (2026-09-24) |
| `Econ` | stars, coins, the bill | `sterren(n)`, `geef_munt(n)`, `buidel(totaal)`, `splits(n)`, `rekening(o)`; signals `sterren_veranderd`, `munten_veranderd` |
| `Games` | registry of minigames, start/stop/supersede | `lijst()`, `definitie(id)`, `actief()`, `ontgrendeld(id)`, `start(id)`, `stop()`, `hersteek()`, `verhuis(kamer)` (the running game's room walks along with its animal); signals `spel_gestart`, `spel_gestopt` |
| `Hotel` | day cycle, wishes, board, check-in, evening round, letters, hotel buttons | `start()`, `bel()`, `morgen()`, `avondronde()`, `taak_af(id)`, `spel_taken()`, `wens_af(gast, welke)`, `kies_kamer(kamer)` / `checkin_terug()` / `wijs_bed(kamer, bed, {loop})` (check-in steps 3–4), `komt_eraan()`, `volg(id)`, `stop_volgen()`, `hotspots()`, `naar_kamer(id)`; signal `trap_gevraagd(kamer)` |

Rooms (`Rooms.lijst()`): `receptie` (desk top-right, stairs top-left, back door
to the garden right of the desk), `gang`,
`kamer1`, `kamer2`, `keuken`, `tuin` (outdoor, zone `hinkel`; the souvenir
stall moved to the shops on 2026-09-24),
`zwembad` (outdoor since 2026-09-14; `bad` rect = the lane), `wasserij`,
`speelzaal`, `kas` (glass house behind the garden), `winkels` (the shopping
arcade — stalls hoeden, sjaals, schoenen, souvenirs, the luxe shop and the mirror).
**The hotel is a tower** (owner 2026-09-24, "net als Habbo Hotel"; world.md §1.2):
`Kamer.etage` — 0 receptie, tuin, zwembad, kas (the ground floor is the lobby and
the outdoors only); 1 winkels; 2 speelzaal; 3 gang, kamer1, kamer2, keuken; −1
(cellar, "K") wasserij.  Doors stay on their floor; ONE stairwell (`Kamer.trap`, a
`deur_punten` entry per other floor marked `trap`; a lift until 2026-09-25, owner:
"Ik wil graag de lift vervangen voor een trap") joins the floors, so `pad` and
`World.reis` take it like a door.  `scenes/vloer.gd::_trap` draws a wooden flight
seen from the side through a door frame — up where there is a floor above, down on
the top floor.  Its button `trap_<kamer>` ("Trap" with a DRAWN pictogram, `UiTrapIcoon`
— there is no stairs emoji; a door sign) opens the tower sheet (`Hotel.trap_gevraagd`
→ `scenes/main.gd::_toren`, titled with the same picture); `World.naar` to another
floor slides the room in vertically and `Hotel.naar_kamer` plays `Snd.trap(op)`.
A hotspot button can carry such a picture as `beeld` (a `Texture2D`), a sheet too.
Every walk leg inside a room goes round what stands there (`World.looppad`,
A* in `wereld/looppad.gd` over `Rooms.hindernissen`, cached per obstacle set);
swimming, jumping and `per_stap` walks keep their exact points.  Door signs
stand on their door opening, or — the whole room at once — just above the
lintel (`Hits._kies_deurborden`); bubbles without an action are see-through
speech bubbles with a tail (`UiWolk.richt`).
Guests: four kinds, fifteen HTML poses (golden plates, never change them) plus
drawn extras in `POSE_EXTRA` (arrival, blink `knipper`, passing step `loopM`,
wag `kwispelA/B`, sad walk `sjokA/B`); `Dier.beeld` is the drawn frame, `Dier.pose`
the logical one every test reads.  Wardrobe: `ArtGasten.KLEDING` (slots hoofd,
nek, poten, ogen, speel; one piece per slot via `World.accessoire`, which also
writes `g.accessoires`), owned pieces `State.kast_van(id)` / `State.in_kast`.

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

## 6. The games

| id | naam | room | teaches | spec |
|---|---|---|---|---|
| `bedden` | Verdeel bedden over de kamers | receptie → kamer1/kamer2 (step 4 of the check-in, no entry button) | adding on: the animals of the chosen room + the new guest; the guest walks there, camera along | games-a §3 |
| `sleutels` | Het sleutelbord | receptie | number line / neighbours (missing numbers on a key board) | games-a §4 |
| `meubels` | Het meubelboek | receptie → room | money, the growth loop (buy beds/furniture) | games-a §5 |
| `tobbe` | Tobbe-tijd | tuin | fair sharing (division) of soap scoops | games-a §6 |
| `voerkar` | De voerkar | keuken → rooms | k·N biscuits: every bowl asks its own sum (guests × per), then the guests walk to the bowl and eat there; reference for HOTEL.md §9 | games-a §7 |
| `zwembad` | Zwembad | zwembad | the pool is a number line 0…L; lanes vary per day (`Sommen.Zwembad`) | games-b §1 |
| `wekker` | De wekkerdienst | gang | clock reading on a big front-facing clock (`WekkerKlok`); no time in words anywhere; uur erbij / ⏪ uur eraf | games-b §2 |
| `hinkel` | Hinkelpad | tuin (zone hinkel) | number line of stepping stones 0…E | games-b §3 |
| `was` | Wasmandtoren | wasserij | sorting/tallying into crates, bar chart | games-b §4 |
| `kraam` | Souvenirkraam | winkels (a `WinkelSpel` stall since 2026-09-24) | choose a souvenir, pay exactly; fulfils the 🎁 wish | games-d §4.7 |
| `oogst` | Aardbeien plukken | kas | place value, complements to 10 and 100 | games-c §2 |
| `weeg` | Groenten wegen | kas | weighing in kg with a balance | games-c §3 |
| `hoeden` `sjaals` `schoenen` | Hoeden-, Sjaal-, Schoenenkraam | winkels | choose a piece, pay exactly with real coins/notes; shoes: paws × price; groep 5: change | games-d §4 |
| `luxe` | Luxe winkel | winkels | sum with a gift box, half price, change from €50/€100 | games-d §4 |
| `paskamer` | Paskamer | winkels | dressing up from the wardrobe (no sum, no star) | games-d §5 |

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
