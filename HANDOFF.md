# HANDOFF — Dierenhotel run "slaap-zwembad-kamers" (state on 2026-09-06)

Written by the lead so a fresh session (any agent or the owner) can continue without the chat history. The full append-only log is `.fanout/ledger.md`; tickets are in `.fanout/tickets/`; per-ticket API notes in `.fanout/specs/api-*.md`; the game design in `.fanout/specs/dierenhotel-golf3-games.md`. Operating mode: standard fanout (Opus crew via the Agent tool, ticket → worker → reviewer → fix batch → merge), economical (no redundant panels), chat in Dutch, everything persisted in precise English/Dutch prose.

## 1. The task (owner, verbatim)

"Mooi. Wanneer de dieren op hun bed gaan slapen dan slapen ze ernaast. Breidt het spel ook uit met meer minigames inclusief zwembad. Veel kamers voelen iets te klein maak ze 50% groter behalve de gang die ziet er wel goed uit." Later additions: "i also want the game to work on mobile", and "Bij veel objecten als de speelmand staat de tekst over het object". Zwembad rules are the owner's own design (variable pool length, 1 m per stroke, four choices, max 30 m per pick, too short → continue, too far → bump the wall and a short "Au!", never punishing). Extra games chosen in the interview: Wekkerdienst (klok), Hinkelpad (getallenlijn), Wasmandtoren (turven/staafdiagram), Souvenirkraam (geld/wisselgeld).

## 2. What is on main (HEAD a622880, clean apart from this file, the ledger and the tickets)

Merged and verified in this run, in order: S1 guests sleep on their bed (25d3c44); K1 rooms 1.5× with per-room camera and save v7 (710003e); registry extension hook (af8ab32); P1f sounds/stubs/wiring (3c6ef21); P1d wishes 🏊 zwemmen and 🎁 souvenir with registry-driven `wens` (ed55d0b); P1b Rooms.registerModel + runtime decor (4c6861c); P1a rooms zwembad (bad, dek) and wasserij, tuin zones (c151ee2); S2 shared fixes: leesSpel try-wrap, tikBak keeps wishes, 🏊 spot on the deck (c963c00); X1 sleutels landscape layout (8cce0bd); P1c loopNaar/stappen/pose promises, poses zwem (water band) and spring (54c1b31); P1e accessories hoedje/sjaaltje/bal (6c452d0); H1 hotspots above their object, short-frame hiding, drop catch area, onWeg (e2d855a); M1a mobile shell (971950e); M1b canvas bus, stable frame, density cap, redraw-on-change (bd27d35); D2 docs GAMES-API.md + HOTEL.md §1 (b29a40a); registry.js comment fix (a622880).

Last measured on main (all in `.fanout/scratch/dierenhotel/`, gitignored): smoke clean; slaap 124/0; k1 191/0; p1a 103/0; p1b 123/0; p1c 197/0; p1d 70/0; p1e 101/0; p1f 53/0; kapot 30/0; hits-plaats 162/0; hotspots 46/0; w1 76/0 ×2; loop 157/0 ×2; sleutels/test.js 112/0 ×2; mobiel iphone13-land 148/0 and 360x740 157/0; mobiel-perf 48/0. Known pre-existing: voerkar-port 262/1 (its own two `op:'midden'` chips `vk_zak/vk___pot` overlap 30×48 — belongs to M1c). `plugin.js` reportedly crashes against main since M1a (`#padstrip` take-over, 2/2; G3 worker's note, `hinkel/gedeeld-let-op.txt`, `plugin-diag.js`) — verify and fix in S3.

## 3. Open worktrees (uncommitted work, nothing lost)

All under `.claude/worktrees/`, branches `worktree-agent-<id>`; each holds exactly one changed game file unless stated. Suites live in the gitignored main scratch `.fanout/scratch/dierenhotel/<id>/spel.js` (default URL = main tree; `DH_SRC=<worktree>/demos/dierenhotel DH_OUT=/tmp/x node spel.js [land]` runs them against a worktree). alles.sh already has rows `<id>-port` / `<id>-land` for all five games.

| ticket | worktree | base | state | suites (worker / reviewer) | next |
|---|---|---|---|---|---|
| G1 zwembad | agent-a4730b510934cd05b | 971950e | DONE, review not run (429) | zwembad 116/0 ×2; smoke, plugin 54/0, regels 37/0, loop 157/0 ×2 | run the review (ticket text in ledger + `g1-zwembad.md`), fix batch if any, merge |
| G2 wekker | agent-a239f0d18fb509f9f | 971950e | DONE, review LOOKS_GOOD; fix batch G2-F1 was in progress when the agent died (wekker.js now +686 vs +648 reported: partial edits, untested) | wekker 117/0 ×2 (before F1); generator audit 540 cases clean | audit the diff, finish G2-F1 items (celebration in the guest's room + assertion; chip anchor derived from the kist decor entry + radius assertion; miss card states the time once; darker ghost hand), re-run suite, merge |
| G3 hinkel | agent-aba65374185edc9e1 | 971950e | DONE_WITH_CONCERNS, review not run | hinkel 92/0 ×2; smoke, regels 37/0, plugin 54/0, loop 157/0 ×2 | review (concerns: band 3 numbers only on the fives because 7.6 px per stone; dynamic chip prio; hotspot anchored on hok; jumps between stones in band 4/5), fix batch, merge |
| G4 was | agent-ad3206a76d5bffba5 | 971950e | DONE, review FIX_FIRST; fix batch G4-F1 barely started when the agent died (was.js +742 vs +746: probably untouched, verify) | was 162/0 ×2, getallen 10/0 | do G4-F1: card must not cover the crate labels on 320×640 / 844×390 (assert elementFromPoint per plate); real 3-voxel bounce that survives zetDecor; plates must not overlap (drop vast or space them); pile wolk counter separate from the hand text; "doeken" everywhere; NIT help counts on from the low stack. Then merge |
| G5 kraam | agent-adcadf770f89c7b3b | 971950e | DONE_WITH_CONCERNS, review not run (429) | kraam 121/0 ×2, sweep 288 turns clean; smoke, plugin 54/0, regels 37/0, loop 157/0 ×2 | review (judge the single cycling €1→€2→€5 purse vs separate sources, chip wording, tas not worn), fix batch, merge |
| M1c hotel + games on phones | agent-a5a4fb17660307f6d | bd27d35 | near done (hotel.js, voerkar/bedden/sleutels/tobbe.js +246/−38, api-m1c.md written; the agent was writing the spec "while the suites run" when it died; no report) | unknown — run them | resume with a reconcile-then-finish instruction (ticket `m1c-games-touch.md`): mobiel.js game steps for all 8 profiles, landscape check-in placement, onKader migration, text floors, duplicate handlers, rekening purse; review; merge last (touches five shared files) |

Merge recipe used all run (worker branches are committed by the lead, then merged with `--no-ff`; suites re-run on main; worktree removed):

```
wt=.claude/worktrees/agent-<id>; git -C $wt add -A && git -C $wt commit -m "<Dutch summary> (<ticket>)"
git merge --no-ff worktree-agent-<id> -m "Merge worktree-agent-<id> (<ticket>)"
cd .fanout/scratch/dierenhotel && node <id>/spel.js && node <id>/spel.js land && node smoke.js
git worktree remove --force $wt && git branch -d worktree-agent-<id>
```

Merge order suggestion: G2, G1, G3, G4, G5 (each one file, no conflicts), then M1c (merge main into its branch first because it is based on bd27d35 and edits hotel.js and four game files).

## 4. Remaining steps after the merges

1. S3 shared fix batch (one worker, main tree or worktree): (a) `registry.plek()` / hotspot anchoring cannot resolve runtime decor, so G2 and G5 hang their entry hotspot on a fixed decor piece with offsets — let it resolve `World.decorLijst()` ids additively; (b) `ctx.taakKlaar` does not refresh the topbar star counter until the game closes (econ geefSter without Hotel.render); (c) GAMES-API.md:823 says "vier bestaande spellen" (now nine games); (d) plugin.js vs `#padstrip` (see §2); (e) voerkar-port 262/1 own-chip overlap if M1c did not fix it; (f) api-p1a.md footprint comment off by one voxel (cosmetic).
2. Full runner: `.fanout/scratch/dierenhotel/alles.sh` (50 rows incl. the five games ×2, mobiel ×8, mobiel-perf, hits-plaats, kapot; ~20–30 min; summary in `alles-samenvatting.txt`; the runner kills only its own process group).
3. Blind verification (fanout-verifier, fresh context, original task verbatim from §1): sleeping on the bed; rooms 1.5× except gang; five games playable per band and on the phone profiles with real taps; zwembad rules exactly as the owner wrote them; hotspot text no longer covers objects (speelmand); no console errors; frozen math byte-identical to waggletail (`koekjesSom, vergelijk, planOplossingen, sommen.*`). Verify from a committed, clean state.
4. Update the memory file `~/.claude/projects/-home-pc-Documents-xnw-rkn/memory/dierenhotel-project-state.md` and close the run in the ledger; final report to the owner in short Dutch.

## 5. Facts that cost time to rediscover

- Playwright: `require('/home/pc/work/ergomouse/node_modules/playwright')`, chromium only (no WebKit installed; do not install). Real-phone Safari never tested.
- Suites hard-code the main-tree URL; most honour `DH_SRC` / `DH_OUT`. The sleutels suite is `sleutels/test.js`, not spel.js. Never `pkill -f chrome` (other agents' browsers); kill only PIDs you started.
- The sandbox rejects long shell heredocs for agents: they create files with the Write tool. Worktree-isolated agents cannot Edit main-tree files (they use temp file + rename for scratch files).
- Session limits: three 429 events this run (Fable limit twice, Opus session limit at ~22:10 Europe/Amsterdam resets). Dead agents keep their worktree; resume via SendMessage with the agent id when the process still exists, otherwise re-dispatch with an "audit the partial diff first" instruction (see ledger for the wording that worked).
- Routing: owner asked for standard fanout (Opus crew) and no token burning; hard tickets (owner's design, cross-module, layout geometry) went to fanout-worker-max, the rest to fanout-worker xhigh, every logic-bearing change got a fanout-reviewer pass and one batched fix ticket.
- HOTEL.md §9 rules are binding for every child-facing string (≤ 8 words / 40 chars above a sum, icon with its word, ≥ 48 px targets, 44 only below 360 px, never punishing, curriculum bands groep 3 ≤ 20 / groep 4 tafels 1–5 and 10, ≤ 100 / groep 5 ≤ 100, money whole euros ≤ €20).
