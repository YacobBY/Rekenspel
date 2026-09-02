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
