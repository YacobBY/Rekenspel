# HANDOFF — Dierenhotel Godot port, run "dierenhotel-godot" (closed 2026-09-11; follow-up 2026-09-14 in §0)

Written by the lead so a fresh session (any agent or the owner) can continue without the chat history. Full append-only log: `.fanout/ledger.md` (section "Run dierenhotel-godot"); tickets `.fanout/tickets/godot/`; specs `.fanout/specs/godot/` (architecture.md is the binding design; world/games-a/games-b/art-sound-rules/toolchain are the port specifications extracted from the HTML original). The previous run's handoff (HTML version, run "slaap-zwembad-kamers") is in git history at e8c9bd2.

## 0. Follow-up 2026-09-14 (fonly mode, lead alone) — on main

Owner asks, verbatim: "het klikken van antwoorden in een keer gaat zonder 'enter' klik, altijd alles multiple choice met max 4 opties", and "wanneer een dier vanuit een kamer komt die niet zichtbaar is naar een andere kamer … een cue … als een popup bubbel met het dier dat eraan komt en een progress bar". Plus the reviewer's implementation plan (another agent's `implementation_plan.md`: polish pillars 1–4).

- **Answers**: `Ui.somkaart` with `goed` draws a strip of four numbers (`ui/afleiders.gd`: the game's `liever` slips first, then seeded neighbours, sorted; same card → same strip), pictogram + number per button, the tapped number lands in the box and `on_ok(n, kaart)` fires at once. Strips are capped at four. The keypad (`ui/keypad.gd`), `Kaart.open()`, `pad_id` and the `pad` hotspot kind are gone. Nine sites converted (check-in, bill ×2, meubels ×2, kraam, tobbe ×2, was). `Hits`: a glued strip must also clear every object box — under the card, above it, at the foot of the frame, else the band grid.
- **Komt eraan**: `World.reis` records doors and legs (`reis_voortgang`, `onderweg_naar`, `reis_van`, signal `reis_gestart`); `Hotel.komt_eraan()` (on `World.getekend` and `kamer_veranderd`) hangs a `UiWolk` with a `ProgressBar` (`voortgang`) at the door the guest will come through: "🐶 Boef komt eraan". Gone when he steps into the room. Owner `komt`. Tests: `tests/test_komt.gd`.
- **Polish (plan pillars)**: pillar 2/3 by the owner's other agent (drop shadows, pop-in/tap tweens, active room chip, bell badge when a bed is free; all skipped headless/rust). Pillar 1: `Snd.sfeer(kamer)` — looping generated ambience per room kind (`SFEER`: tuin wind, receptie tiktak, zwembad water, keuken/wasserij warm; corridor and bedrooms silent), own player, ≤ 30 % of MEESTER, off when muted/asleep/background; the 18 sounds untouched (`tests/test_sfeer.gd`). Pillar 4: `World.spetter(kamer, x, z, n, kl, omhoog, hoog)`; voerkar crumbs per scoop, sparkles when the sharing is right and a `hoera` when the last bowl in the hotel is filled; tobbe soap bubbles during the bath step; zwembad splashes at every plons.
- **Same day, later**: zwembad lanes vary with the day when k·N + r falls under the band window (was always 8 m with one guest; `Sommen.Zwembad.baan`, kruis fingerprint updated, games-b.md §1.3); every walk goes round the pool (`Rooms.om_het_water`, applied in World.stappen/ga/doors/wander; swimmers and a guest leaving the water keep their line). Notice board: the sample game `_voorbeeld` is a `stub` (no card, no button); hotel-layer elements treat the desk as an object box (`Hits._mijd_balie_nu`); band-placed elements keep their place while it is still good (`Hits._blijf_staan`) so opening the board no longer reshuffles the buttons; the bell decor sorts after the desk (`"d": 12.5` in rooms.gd, `d` read by scenes/kamer.gd); tooltips are ink on a card (desktop only).
- **Same day, evening**: hotel buttons hang AT their thing (`op: "aan"` in Hits: right under or right above a small thing, ON a big one such as the notice board or the chest; the thing itself stays visible) — used by the bell, board, doors, beds, basket, bowls and the game entry buttons; tests accept own-object coverage only for `op == "aan"`. The pool is outdoors (`erf`, lawn, fence with a gate to the garden, a 16-voxel tiled deck round the water; `ArtVloer.kleur` draws the water before the lawn). Tooling: `/tmp/maak_opslag.gd` pattern lives in the ledger; a room screenshot needs a Playwright tap on the room bar (the morning routine always opens in the reception).
- Suite after this follow-up: see the last line of `tools/test.sh` (388+ tests, 0 failures at commit time). CI: the pages workflow's deploy step fails until the owner sets Settings → Pages → Source = "GitHub Actions" (the push itself and the CI suite/build were green).

## 1. The task (owner, verbatim)

"I want to rebuild the game with Godot it has grown out of scope for what it is now. Then I want to host it on a github page so i can play reach online. I want to play it from a tablet." Answers: only dierenhotel; all games at feature parity; Godot 4.3+ with GDScript in this repo; Godot and gh may be installed locally. Later: "De game hoeft niet exact te werken als nu. Als Godot verbeteringen biedt implementeer die dan." and "Kan de balie rechtsboven en de deur linksboven" (receptie relaid).

## 2. Result — everything is on main (HEAD 9f79bff)

- `godot/dierenhotel/`: Godot 4.7.2 project, GDScript, Compatibility renderer, single-threaded web export, PWA. Ten autoloads (Art, Rooms, Hits, World, Snd, Ui, State, Econ, Games, Hotel), the `MiniGame`/`SpelCtx` contract, eight rooms with guests and awaitable movement, day cycle/economy/wishes/prikbord/check-in/bill/letters, save v1 in `user://` (JSON, atomic, corrupt → start screen), voxel baker with golden-image oracle (72 plates, silhouettes within 1 px of the HTML), 18 procedural sounds with a WAV oracle, frozen math core byte-identical to the JavaScript (23 042 cases), band-grid hotspots (0 % coverage by construction), fonts subset (Nunito, Noto Symbols 2, Noto Color Emoji; OFL).
- All ten minigames under `games/<id>/` (bedden, sleutels, meubels, tobbe, voerkar, zwembad, wekker, hinkel, was, kraam), each with its own headless test file; the owner's zwembad rules verbatim; wekker ghost hands at the 2nd miss; receptie desk top-right, door top-left.
- Suite: `godot/dierenhotel/tools/test.sh` → 386 tests, 0 failures, about 95 s (at 9f79bff; see §0 for the 2026-09-14 state). Web export 40.9 MB (wasm 39.5 MB, gzips to 10 MB). Shell probe (`tools/probe.js`) passes all seven steps on 1024×768@2, 768×1024@2, 1280×800@2, 360×740@3 and 740×360@3 (the last with `--knop bel`).
- CI: `.github/workflows/test.yml` (import, suite, export on every push/PR) and `pages.yml` (calls test.yml, then export → GitHub Pages). Not yet pushed or enabled (see §4).

## 3. How to run and test

- Godot: `~/.local/bin/godot` (4.7.2.stable), export templates in `~/.local/share/godot/export_templates/4.7.2.stable/`. gh CLI: `~/.local/bin/gh` (not logged in).
- From the repo root: `tools/import.sh`, `tools/test.sh` (wraps `godot/dierenhotel/tools/test.sh`; isolates `user://` per run; `DH_TEST_FILTER=kraam` runs one game's tests), `tools/export.sh` (→ `godot/dierenhotel/build/web/`), `tools/serve.sh` (port 8642), `tools/probe.js --viewport 1024x768@2:ipad --knop bel` (chromium via Playwright at `/home/pc/work/ergomouse/node_modules/playwright`, swiftshader flags built in). Do not run the suite and an export at the same time in one project directory (the shared `.godot/` cache crashed the suite once).
- Browser proof of a game at a given day/band: `index.html?opslag=<base64url of a complete save JSON>` writes the save before it is read; make the JSON with a headless script that calls `State.nieuw_spel()`, sets fields, `State.bewaar()` and prints `user://dierenhotel.json` (example in the ledger, 2026-09-11). Workers' game drivers live in `.fanout/scratch/godot-g-<id>/` (gitignored scratch; wekker's driver is proven against the final export).
- Play locally: `tools/export.sh && tools/serve.sh`, open http://localhost:8642/ on the tablet in the same network.

## 4. Publishing to GitHub Pages (owner action, once)

1. `gh auth login` (browser flow, no sudo), then `git push origin main`.
2. Repo Settings → Pages → Source = "GitHub Actions". The `pages.yml` workflow then runs the suite, exports and deploys; the site root is the game. Every later push to main redeploys after a green suite.
3. On the tablet open the Pages URL; "Add to Home Screen" installs the PWA (offline after the first load).

## 5. Verification status (honest)

- Wave 1 (world, hotel, UI, art, sound, math, CI): reviewed by three fanout-reviewers, blind-verified (V1: FAIL on two HIGH items → fixed in V1-F1; the fixes were re-checked by the lead's probes, not by a second blind pass).
- Wave 2 (games): kraam reviewed LOOKS_GOOD; wekker reviewed FIX_FIRST → fixed. hinkel, zwembad, sleutels, meubels, was, bedden, voerkar, tobbe: self-reviewed by the lead through their suites, the merged suite and the shell/driver probes; NOT blind-verified (the Opus session limit ended the reviewers; the owner switched to fonly mode). A future run should start with one blind verifier pass over the ten games (brief: play one turn per band per game in chromium via the `?opslag=` hook, check strings against games-a/games-b, coverage, reload, stop()).
- Real iPad Safari and Android Chrome were never touched: chromium device emulation only. One real-device pass is the most valuable next step (audio unlock, IndexedDB persistence, memory, touch).

## 6. Known limits and deferred items

- Landscape phones (740×360): the three-column room-bar rail cuts long words mid-word ("Kame/r 1"); a two-column 80-unit rail was tried and reverted (segfault in the kraam shell tests during fast shell create/free). Cosmetic.
- The generic probe's `kaart` step fails at 740×360 when it taps "prikbord" first; tapping `bel` works (7/7 with `--knop bel`).
- A headless shell at 296×314 segfaults (pre-existing, no such device).
- Suite time 95 s (budget was 60 s): four shell viewports per game test; share or cache shells per file if it grows.
- Per-plate bake cost in the browser exceeds 25 ms for `baliez`/`hok` (28–46 ms) though every room stays inside the 300 ms slide; fix proposed: spread the bake over the slide frames.
- Hits: door hotspots and guest-following spots have rects since I1; the two prikbord cards have rects since V1-F1; a speech cloud may still overlap the desk front.
- Deviations accepted from the HTML (all documented in architecture.md §13 or the ledger): meubels does not surface the planbord solver; drag-to-door dropped; volgende() in wekker walks the row captured at round start; help-ladder sentences of zwembad are new (the spec fixed none); "🩺 Els" carries a word; tobbe and voerkar use 🔄 for "opnieuw" and ▸ for "→" (glyphs not in any bundled font).
- Toolchain: pushed to origin/main on 2026-09-14; Pages source not yet set to "GitHub Actions", so the deploy job fails while test and build pass.

## 7. Facts that cost time to rediscover

- `user://` is per project name, so parallel worktrees and test runs share one save unless `XDG_DATA_HOME`/`DH_USERDATA` is set (test.sh does this now).
- The runner buffers stdout: a crash loses every "ok" line; bisect with `DH_TEST_FILTER=<file part>`.
- `set_anchors_preset` keeps offsets: a code-built full-rect Control stays 0×0; use `set_anchors_and_offsets_preset`.
- A Label with word wrapping reports its longest word as minimum width; inside the shell that can loop the layout. The room bar uses ARBITRARY wrap on purpose.
- `Games.registreer` writes into `Games._defs`; tests narrow the registry with `Proef.alleen_spellen(ids)` and the runner restores it after each test.
- URL query base64: use base64url (`-`/`_`), `uri_decode()` turns `+` into a space.
- Godot's `--script` SceneTree scripts cannot name autoloads at compile time; use `root.get_node("State")`.
