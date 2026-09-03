# Fanout Ledger

## Run: dierenhotel-ideation (2026-08-24)

**Mode:** Full (Agent tool + real shell). Crew pinned to claude-opus-5.
**Baseline:** b84f5ab (waggletail v5), working tree clean.
**Job:** Design pivot for Kwispelsteeg: Habbo-style animal hotel where math minigames happen INSIDE the 3D voxel world; more guests arrive over time; difficulty scales with guest count. Deliverable this run: ideation + design synthesis (no build yet — user pattern: ideas first, then chooses).

### Decisions / assumptions (autonomous run, no interview possible)
- Audience unchanged: girls 6–9, Dutch groep 3–5 curriculum (see IDEAS.md).
- Tech unchanged: vanilla JS isometric voxel engine (demos/waggletail/world.js, art.js); no engine switch.
- Existing minigames (feeding share, planbord, gate decision) become hotel tasks, not discarded.
- Output: HOTEL.md synthesis written by lead; user picks what to build.

### Routing
| ID | Ticket | Seat | Write set | Status |
|----|--------|------|-----------|--------|
| H1 | Hotel architecture, progression, in-world interaction model | fanout-worker (xhigh) | ∅ | DISPATCHED |
| H2 | Minigames: hotel operations (reception, kitchen, laundry, rooms, shop) | fanout-worker (xhigh) | ∅ | DISPATCHED |
| H3 | Minigames: guest activities (pool, playground, garden, party, spa) | fanout-worker (xhigh) | ∅ | DISPATCHED |

### Attempts
- 2026-08-24 H1–H3 dispatched in one parallel wave (empty write sets). No verifier: ideation, no code.
- 2026-08-24 H1 DONE: "wereld is het rekenblad" (hotspots op #worldTags), kamer-camera (verhuizen i.p.v. uitzoomen), bedden = gastcap, bel is van het kind, T=k*N+r bandregel (N2-3/4-6/7-10 = groep 3/4/5), sterren (meedoen) + munten (uitchecken), rooms.js + BFS deurgraaf, save v6.
- 2026-08-24 H3 DONE: 8 gastenplezier-games (zwembad meten, hinkelpad getallenlijn, moestuin arrays, feestzaal turven/staaf, tobbe verdubbelen/halveren, spiegelmaskers symmetrie, dansrijtje patronen, bus-klok). 8 domeinen, 4-6 icoon-only.
- 2026-08-24 H2 DONE: 8 hotelwerk-games. Lead synthese -> HOTEL.md (16 nieuwe + 3 herhuisveste games, overlap-keuzes, 4-fasen bouwplan). Run closed; wacht op keuze gebruiker.

## Run: dierenhotel-demo (2026-08-24)

**Baseline:** see commit above (HOTEL.md committed), working tree clean.
**Job:** Build playable demo of HOTEL.md phases 1+2 in new folder demos/dierenhotel/ (copy-evolve from demos/waggletail/, which stays untouched).

### Routing
| ID | Ticket | Seat | Write set | Status |
|----|--------|------|-----------|--------|
| D1 | Fundament: rooms, camera, hotspots, receptie/bel/check-in, bed cap, save v6, voerkar, rekening, minigame plugin API + GAMES-API.md | fanout-worker-max (cross-module engine work, hard) | demos/dierenhotel/** , .fanout/scratch/dierenhotel/** | DISPATCHED |
| D2 | Bedden op rij (games/bedden.js) | fanout-worker (xhigh) | demos/dierenhotel/games/bedden.js | PENDING (after D1) |
| D3 | Sleutelbord (games/sleutels.js) | fanout-worker (xhigh) | demos/dierenhotel/games/sleutels.js | PENDING |
| D4 | Tobbe-tijd (games/tobbe.js) | fanout-worker (xhigh) | demos/dierenhotel/games/tobbe.js | PENDING |
| D5 | Meubelboek + muntenlade (games/meubels.js) | fanout-worker (xhigh) | demos/dierenhotel/games/meubels.js | PENDING |

### Decisions
- D1 seated at max: cross-module engine refactor (scene graph, hit-testing in isometric painter order, save migration) — difficulty, not retry.
- Wave 2 parallel only because D1 defines a self-registering plugin API so game files never touch shared files.
- 2026-08-24 D1 attempt 1 interrupted by host restart (no report). Reconciled: demos/dierenhotel/ fully populated (5655 lines, GAMES-API.md, stubs, voerkar plugin, screenshots in scratch); no running jobs. Resumed same agent via SendMessage to finish verification + report.
- 2026-08-24 D1 DONE: 19 files/6466 lines, 213 asserts 0 fail, z-order proven, 60fps@12 animals, v5 migration, GAMES-API.md + voerkar reference plugin. Coordination flag: bed-slot additions live in rooms.js (needed by bedden.js and meubels.js) -> lead decision: D1 adds shared wereld.voegBed API in fix batch. R1 reviewer dispatched.
- 2026-08-24 R1 verdict FIX_FIRST: (1) pending guest lost on save mid-check-in, (2) sommen.tafel band-3 product up to 50, (3) no shared voegBed/plaatsMeubel API -> wave 2 blocked, (4) reception hotspot crowding portrait, (5) minors (hierboven text, dead var, 🛁 dead task, voerkar hotspot stacking, clientWidth per frame), (6) 82 vs 77 landscape count. Fix batch sent to D1 worker (attempt 2).
- 2026-08-24 D1 attempt 2 DONE: all 6 findings fixed + 2 extra defects (kamerbalk DOM rebuild, data-kamer attr collision); 281/281; voegBed/plaatsMeubel API documented; 6840 lines. V-D1 blind verifier dispatched.
- 2026-08-24 V-D1 verdict PASS_WITH_NOTES: F1 badge never hides (style.css .kb display overrides hidden), F2 kar drawn off floor in gang (dingZet copies only kamer), F3 day-1 prikbord stale, F4 snd.js mode 0600, F5 econ pogingen shared between sum and coin steps, F6 change unreachable at 4 beds (by design until meubels), F7 taps during camera slide. Lead: chmod fixed F4; checkpoint commit; fix batch F1/F2/F3/F5/F7 to D1 worker in parallel with wave 2 (disjoint write sets: games/*.js only).
- 2026-08-24 Checkpoint commit 2e8df1d (foundation). Wave 2 dispatched in parallel: D1 fix batch 2 (F1/F2/F3/F5/F7, foundation files only), D2 bedden.js, D3 sleutels.js, D4 tobbe.js, D5 meubels.js (each own file + own scratch dir). All fanout-worker xhigh.
- 2026-08-24 RATE LIMIT: all 5 wave-2 workers (D1 fix2, D2-D5) killed by crew session limit (claude-opus-5, resets 17:10 Europe/Amsterdam). Disk state: all game files written (bedden 572, sleutels 718, tobbe 793, meubels 864 lines, no stubs), fix batch 2 partially applied (hotel/style/world/econ modified), node --check clean on all 16 files, NOTHING verified. Note: D1 worker observed meubels.js mid-write at 15:30 (own write set of D5, not a breach).
- 2026-08-24 User feedback: math/text must live inside the 3D world, panels feel like a website, too much text. Lead wrote HOTEL.md §9 (in-world math UI rule + required API primitives wolk/somkaart/getalTag/bron). Plan after reset: (1) resume D1 with fix batch 2 + in-world UI primitives; (2) resume D2-D5 with delta ticket: migrate their UI to §9 primitives, then verify; (3) reviewer + blind integration verify; commit.
- 2026-09-03 Resume after rate-limit reset. Tree: foundation fix2 partially applied + 4 game files unverified. Killed 16 orphaned headless chromium from killed workers. D1 resumed: finish fix batch 2 + add HOTEL.md §9 in-world UI primitives + migrate foundation flows.
- 2026-09-03 D1 attempt 3 DONE: fix batch 2 (F1/F2/F3/F5/F7) proven; §9 primitives wolk/somkaart/getalTag/bron/spreek/mik added + documented (GAMES-API.md §6); check-in/voerkar/bill/prikbord migrated in-world, foundation no longer uses ui.paneel; 363/363; 60fps. Games D2-D5 unmigrated + unverified. Dispatch: R2 reviewer on D1 part B (parallel) + D2-D5 resumed with §9 delta tickets (own files only).
- 2026-09-03 LEAD screenshot check n9-port-02/07: §9 direction confirmed (wolk + somkaart + pad below room, bowls with digits, one klaar button). Lead finding L1 for next fix batch: room occupies only ~45% of world frame in portrait (large empty margins) — integer scale g should step up / frame should hug the room.
- 2026-09-03 R2 verdict FIX_FIRST: (1) ctx.ui passthrough -> wolk/somkaart not reaped on stop (blocks wave 2), (2) bron double-fire tik+onTap, (3) getalTag focusable button, (4) gelukt timer nulls R, (5) ghost thresholds differ, (6) cosmetics. + lead L1 room scale. Fix batch 3 sent to D1 (attempt 4), transparent to games.
- 2026-09-03 D1 attempt 4 DONE: ownership facade uiVoor(id) (transparent), bron single delivery, getalTag div/aria-hidden, bill timer guard, one ghost rule (3rd try), naarRaster tests occupancy, L1 frame hugs room (65% portrait, >=60% all rooms). 395/395. Games probe: 4 in-world, meubels panel (allowed). Awaiting D2-D5 reports.
- 2026-09-03 D2 bedden.js DONE_WITH_CONCERNS: 626 lines, zero words UI, 46/46, voegBed 4->10 persists. Gaps: no ctx.wereld.schaal(); rooms cap ~3 rows (doel<=30, 7x6 unreachable in one room); getalTag prio culled; removed hotel buttons manually (no sanctioned API); wolk volg does not follow room change; somkaart no .som setter; sommen.tafel returns {a,b,uit}. -> collect for API batch after D3-D5 reports.
- 2026-09-03 D5 meubels.js DONE_WITH_CONCERNS: 834 lines, catalogue compact panel, payment/placement in-world, 100/100 both orientations. Gaps: no generic Econ.betaal (composed from primitives); getalTag prio fixed; wolk/somkaart door (now fixed by D1 uiVoor - verify); single hotspot per game (boek only at balie); no cosmetic meubel types; prikbord cards collide with game buttons in receptie -> close bord when game starts. Awaiting D3, D4.
- 2026-09-03 D3 sleutels.js DONE: 617 lines, 96/96 x3 configs, 1296 generated boards uniquely solvable, no ui.paneel. Gaps: wolk/bron volg cannot cross rooms; door on wolk/somkaart (fixed by uiVoor, D3 coded before); no scale in ctx; groep 5 blanks spread over boards; prikbord has no sleutels task. Awaiting D4.
- 2026-09-03 D4 tobbe.js DONE: 862 lines, 20+82+82 asserts, recipes per band, in-world water gauge, need cleared via g.blij. Gaps: no halveer/verdubbel generator; no water level in engine; no behoefteKlaar API; getalTag prio fixed; Hits.plaats collapses at 0px host; somkaart no regel setter.
- 2026-09-03 Lead consolidation -> D1 API batch 4 (foundation only): close prikbord on game start; generic prikbord task chips for registered games; skip Hits.plaats at 0px host; getalTag prio option; wolk/bron volg across rooms; ctx.wereld.schaal(); ctx.wereld.behoefteKlaar(); somkaart.regel(); document. Deferred (noted in HOTEL): Econ.betaal generic, halveer/verdubbel generator, band-5 7x6 room cap, cosmetic meubel types. R3 reviewer on 4 game files dispatched in parallel.
- 2026-09-03 LEAD screenshot check: sleutels reads excellent (§9 compliant). bedden: 4 row cards stack over the room and hide it -> L2 polish (draw rows as floor strips / smaller tags), not blocking. Waiting on D1 batch 4 + R3.
- 2026-09-03 R3 (4 games) FIX_FIRST: tobbe double taakKlaar (MED), meubels cells in all rooms vs 16-cap (MED); lows: bedden wolk y ignored, bedden removes hotel hotspots by id (needs sanctioned API), tobbe free badkuipen ignore shop ones, meubels ghost >=2, direct window.Hotel/World.debug use (API gap). Sweeps: 4320 sleutels boards + 2520 tobbe recipes + 1440 bedden combos all curriculum-clean. Fix tickets sent to D4 (tobbe) and D5 (meubels). bedden L2 + #4 deferred to polish after batch 4 (schaal()).
- 2026-09-03 D5 fix DONE: cells active room only, max 4 + cycle, ghosts >=3; 106/106 x2; busy-room hotspots 11 <= 12. Awaiting D1 batch 4 + D4 fix.
- 2026-09-03 D4 fix DONE: single star per round, shop badkuipen counted; 89/89 x2 + 20/20. Note: prikbord now has bedden task (D1 batch 4 in progress). Awaiting D1 batch 4.
- 2026-09-03 D1 batch 4 DONE: bordDicht on game start, SPEL_TAAK prikbord tasks, hits skip at 0px, getalTag prio, follower kamer, schaal(), behoefteKlaar(), somkaart.regel(), GAMES-API §7 deferred list. 414/414 + all 4 game suites green unchanged. Checkpoint commit + V-INT blind integration verifier.
- 2026-09-03 V-INT verdict PASS_WITH_NOTES @93f19d1: (1) stale Morgen button skips a day (hotel.js:829), (2) bedden target can exceed free slots (star for 0 beds), (3) wish bubbles cover game buttons in busy room, (4) tobbe prikbord card vanishes un-ticked (render before taakAf), (5) tobbe places free badkuip persisted as shop meubel, (6) 8 toasts >6 words, portrait empty space. Fix round: D1 (1,3,4-foundation,6), D2 bedden (2), D4 tobbe (4-order,5).
- 2026-09-03 D2 fix DONE: target <= real capacity (dry-run placement), steps within band factor set, routes to kamer2 when full, no star for 0 beds; 54/54. Awaiting D1 batch 5 + D4 fix.
- 2026-09-03 D4 fix2 DONE: behoefteKlaar + ster() guard before board rebuild (card ticked), spa:1 fixture marking (no free shop badkuip), layout via schaal(); 20 + 95/95 x2. Awaiting D1 batch 5.
- 2026-09-03 D1 batch 5 DONE: avond spots wiped on morgen, priority layers (pad/digits > game > hotel > wishes) + wish bubbles parked during game, fulfilled cards tick not vanish, toasts <=6 tokens, portrait fill 88% (walls taller, width+height scale fit). 435/435 + games 54/96x2/95x2/20/106x2. Commit + V-INT2 targeted re-verify.
- 2026-09-03 V-INT2 @46c0dc8 PASS_WITH_NOTES: all 6 findings fixed (0/1728 bedden violations, 0 overlaps, bad✓, moon gone). New: F1 meubel id counter resets on reload -> duplicate ids, pick-up removes both tubs (medium); F2 spa flag lost on reload; F3 one 8-token toast; F4 portrait 74.8-76.6% borderline; F5 wishes parked only in declared room. Fix batch 6 -> D1.
- 2026-09-03 D1 batch 6 DONE: meubelNr persisted + derived from ids, extra meubel fields survive restore, toast 4 tokens, Games.actieveKamer() parks wishes in real room. 453/453 + games green. Commit + V-INT3 targeted re-check (F1/F2).
- 2026-09-03 V-INT3 @b3f03a9 PASS_WITH_NOTES: F1/F2/F3 + legacy-save all PASS; F5 cosmetic (render before start). LEAD inline one-line fix in registry.js (render after start when room changed); smoke NO CONSOLE ERRORS, bedden 54/54. Committed. Run closed.
