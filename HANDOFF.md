# HANDOFF — Dierenhotel run "slaap-zwembad-kamers" (closed 2026-09-07)

Written by the lead so a fresh session (any agent or the owner) can continue without the chat history. Full append-only log: `.fanout/ledger.md`; tickets: `.fanout/tickets/`; per-ticket API notes: `.fanout/specs/api-*.md`; game design: `.fanout/specs/dierenhotel-golf3-games.md`; blind-verification brief: `.fanout/tickets/v-final.md`. Operating mode: standard fanout (Opus crew via the Agent tool, ticket → worker → reviewer → fix batch → merge → blind verifier), economical, chat in Dutch, persisted text in precise prose.

## 1. The task (owner, verbatim)

"Mooi. Wanneer de dieren op hun bed gaan slapen dan slapen ze ernaast. Breidt het spel ook uit met meer minigames inclusief zwembad. Veel kamers voelen iets te klein maak ze 50% groter behalve de gang die ziet er wel goed uit." Later: "i also want the game to work on mobile" and "Bij veel objecten als de speelmand staat de text over het object". Zwembad rules are the owner's own design (variable pool length, 1 m per stroke, four choices, max 30 m per pick, too short → continue, too far → bump the wall and a short "Au!", never punishing). Extra games chosen: Wekkerdienst (klok), Hinkelpad (getallenlijn), Wasmandtoren (turven/staafdiagram), Souvenirkraam (geld/wisselgeld).

## 2. Result — everything is on main

HEAD after the run: see `git log` (last merges: G5-F2 66826b9, S4 6b0473b, then ledger commits; the final zwembad margin fix G1-F2 lands after afc872a). No open worktrees. Delivered and verified:

- Guests sleep on their bed (lying pose, 💤, rotated beds, morning, reduced motion).
- Rooms receptie, kamer1, kamer2, keuken exactly 1.5× (gang 120×36 unchanged, tuin unchanged by design); per-room camera; save v7 with v6 migration; corrupt saves boot to the start screen.
- Prep APIs: rooms zwembad (bad, dek) and wasserij, tuin zones; Rooms.registerModel + runtime decor (ctx.wereld.decor…); movement promises loopNaar/stappen/pose with poses zwem (water band) and spring; wishes 🏊 zwemmen / 🎁 souvenir via `wens` in Games.register; accessories hoedje/sjaaltje/bal; sounds plons/au/klok/hup; hotspots on runtime decor (decorPlek); live star counter.
- Five new games (nine total): zwembad (owner's rules verbatim), wekker, hinkel, was, kraam — each with its own suite `.fanout/scratch/dierenhotel/<id>/spel.js` (port + land + 360×740/320×640 + iPhone 13 tap pass).
- Mobile: keypad strip under short frames (padPlek auto), compact landscape chrome, dvh/safe-area/overscroll, touch semantics (touch-action, ghost above the finger, single-fire taps), audio unlock on first tap, 12 px text floor, World.onKader layout bus, stable frame height, density cap on phones, redraw only on change, hidden-tab pause, hotel and existing games migrated; device suites mobiel.js (8 profiles, ~2900 assertions) and mobiel-perf.js.
- Hotspot buttons sit above/below their object (coverage 0 % for every object button in 5 rooms × 4 viewports; the speelmand example fixed), short-frame hiding of foreign buttons, drop catch area = button ∪ object, 4-round evasion incl. stacking, fair prikbord rotation of low-priority game chips.
- Docs: GAMES-API.md consolidated (incl. §9 "Op de telefoon"), HOTEL.md §1 room table.

Blind verification (fanout-verifier, fresh context, brief `.fanout/tickets/v-final.md`, at afc872a): **PASS_WITH_NOTES** — criteria A–G PASS with independent probes (§9 audit 810/810; frozen math byte-identical to waggletail; mobile profiles clean); H: runner 48/49 OK, the one red row `zwembad-land 124/1` was a 1-px flush edge between the card and the swimmer box after the prikbord rotation changed the swimming guest (visually 0 px) → fixed by G1-F2 (margin ≥ 6 px + deterministic finish-card anchor; see the ledger for its numbers).

## 3. How to run and test

- Runner: `.fanout/scratch/dierenhotel/alles.sh` (~50 rows, ~25 min, each suite in its own process group, summary appended to `alles-samenvatting.txt` — read the last block). Single row: `./alles.sh <tag>`; `--tags` lists them.
- Playwright: `require('/home/pc/work/ergomouse/node_modules/playwright')`, chromium only (no WebKit installed). Suites default to the main tree; `DH_SRC=<tree>/demos/dierenhotel DH_OUT=/tmp/x node <suite>` redirects. Sleutels suite is `sleutels/test.js`, bedden is `bedden/bedden.js`. Never `pkill -f chrome` blanket.
- Browser: `python3 -m http.server 8642` at the repo root, open /demos/dierenhotel/index.html (or file://).

## 4. Known limits and deferred items

- Real touch hardware and iOS Safari never tested (chromium device emulation only): dvh/svh, audio unlock and rubber-banding deserve one real-iPhone pass.
- Rare flake: zwembad "eindkaart hangt op de plek van de vraagkaarten" (kaart.y=0) seen once in batch runs; G1-F2 makes the anchor deterministic — watch the next full runs.
- Landscape 568×320 band 4/5 sleutels has no fitting layout (documented in api-x1.md); 320×640 band 4 was-crates draw 2-voxel blocks; band-5 7×6 bedden arrays need a bigger room; tobbe tool row width; eb0db0b layout blind re-check never completed (superseded by this run's verifier).
- Cosmetic: the Bedden game button stacks above a mattress in kamer1 when it shares the mand anchor; tuin floor extends past its frame by design.
- Engine notes for future games: GAMES-API.md §9 (phone rules), decorPlek for hotspots on runtime decor, decorWisAlles in stop(), World.hermeet after chrome changes, Ui.opKader instead of window listeners.

## 5. Facts that cost time to rediscover

- The sandbox rejects long shell heredocs for agents (use the Write tool); worktree-isolated agents cannot Edit main-tree files (they stage scratch copies; the lead installs them).
- Session limits hit four times this run (Fable twice, Opus twice); dead agents keep their worktree — resume with SendMessage if the process still exists, else re-dispatch with "audit the partial diff first".
- Merge recipe: commit on the worktree branch, `git merge --no-ff`, re-run the suites on main, `git worktree remove --force`, `git branch -d`.
- HOTEL.md §9 rules are binding for every child-facing string (≤ 8 words / 40 chars above a sum, icon with its word, ≥ 48 px targets, 44 only below 360 px, never punishing, curriculum bands groep 3 ≤ 20 / groep 4 tafels 1–5 and 10, ≤ 100 / groep 5 ≤ 100, money whole euros ≤ €20).
