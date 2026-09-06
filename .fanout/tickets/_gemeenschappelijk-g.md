COMMON BLOCK FOR THE WAVE-3 GAME TICKETS (G1–G5) — read together with your own ticket.

REPO AND WORKTREE
- Repo /home/pc/Documents/xnw/rkn (Dutch children's math game "Dierenhotel", girls 6–9, groep 3–5; vanilla HTML/CSS/JS, offline file://, no build). You work in an isolated git worktree that the harness created for you; run `git rev-parse --show-toplevel` and `git status` first and use absolute paths inside that worktree for everything. Never edit the main tree under /home/pc/Documents/xnw/rkn/demos. The only main-tree writes allowed: copying your finished suite folder and screenshots into /home/pc/Documents/xnw/rkn/.fanout/scratch/dierenhotel/<id>/ at the end (scratch is gitignored, so the worktree has no copy of the existing harnesses: copy the ones you need into <worktree>/.fanout/scratch/dierenhotel/ and point them at file://<worktree>/demos/dierenhotel/index.html; change only your local copies).

READ IN THIS ORDER
1. /home/pc/Documents/xnw/rkn/demos/dierenhotel/GAMES-API.md — the plugin contract (Games.register, ctx.wereld / ctx.ui / ctx.hits / ctx.data, somkaart {regel, icoon, keuzes}, wolk, bron, taakKlaar, behoefteKlaar, and the sections added in this run: rooms zwembad/wasserij + tuin zones, Rooms.registerModel + ctx.wereld.decor/decorWeg/decorLijst, ctx.wereld.loopNaar/stappen/pose + poses zwem/spring, wish declaration `wens` in Games.register, accessories, sounds plons/au/klok/hup). If a section is missing there, the per-ticket notes are in /home/pc/Documents/xnw/rkn/.fanout/specs/api-p1a.md … api-p1f.md.
2. /home/pc/Documents/xnw/rkn/.fanout/specs/dierenhotel-golf3-games.md — the design of your game (your section) and the shared requirements at the end.
3. /home/pc/Documents/xnw/rkn/HOTEL.md §3 (T = k·N + r scaling per band) and §9 (the child-facing rules, binding).
4. Reference plugins: /home/pc/Documents/xnw/rkn/demos/dierenhotel/games/tobbe.js (wish-driven game, guest walks, behoefteKlaar), games/voerkar.js (chips, corrections), games/sleutels.js (card + in-world hotspots), games/registry.js (ctx builder, ownership rules). Do not edit any of them.
5. An existing suite as a harness pattern: /home/pc/Documents/xnw/rkn/.fanout/scratch/dierenhotel/tobbe/spel.js (port + land), and the runner alles.sh (your rows `<id>-port|node <id>/spel.js` and `<id>-land|node <id>/spel.js land` already exist; a missing script prints SKIP).

HARD RULES (HOTEL.md §9, non-negotiable)
- The math happens in the world: the child acts on objects (animal, pool, clock, stones, crates, coins); the sum card only names what the world shows.
- Above every sum exactly one plain sentence, at most 8 words and 40 characters, in the guest's voice or about the guest ("🏊 Boef is bij 30 meter"). Pictogram always in the same bubble as its word. Choice buttons are icon + word/number in one strip; never bare digits without context.
- Every tap target at least 48 × 48 CSS px (44 px only on frames narrower than 360 px). Portrait 420×860, landscape 860×420, small phones 360×740 and 320×640: the card never covers the active guest or the objects the child must tap; hotspot layer limit 16 per layer.
- Never punishing: no red crosses, no timers, no lost stars, animals never angry, sick or hurt for longer than a short "Au!"; wrong answers get a gentle in-world consequence and the turn simply continues.
- Curriculum bands: groep 3 numbers ≤ 20 (prefer ≤ 10), groep 4 ≤ 100 with only tafels 1–5 and 10, groep 5 ≤ 100; money whole euros ≤ €20. Exactly one correct choice among four, no duplicate numbers, never negative.
- Frozen math in state.js untouched (koekjesSom, vergelijk, planOplossingen, sommen.*, antwoord1/antwoord2). New generators live only in your game file, derived from N (guest count) and the band.
- Mobile is a hard requirement: touch phones in both orientations. Use pointer events (ui.js dragKit / ctx.sleep for drags), touch-action none on anything draggable, no hover-only affordances, no double-tap zoom on repeated taps (buttons already carry touch-action manipulation via the shared CSS; check what your hotspots inherit). Your suite must include a device-emulated pass (Playwright devices['iPhone 13'] with hasTouch, using page.tap) that plays one full turn.
- Console error-free; reloading the page in the middle of a turn restores the turn from ctx.data() (store everything the turn needs: guest id, generated numbers, progress).
- Sounds only through Snd (respect mute); no new assets, no dependencies, no network.

SUITE (deterministic gate; the runner will run it)
- File <worktree>/.fanout/scratch/dierenhotel/<id>/spel.js, run as `node spel.js` (portrait 420×860) and `node spel.js land` (landscape 860×420) plus an internal 360×740 pass and the iPhone 13 tap pass; ≥ 25 assertions each run; prints PASS/FAIL counts in the same format as tobbe/spel.js (a final line like `RESULT 111 pass 0 fail` is what alles.sh parses — check the runner). Cover all three bands by forcing state.band, correct / too-short / too-far (or the equivalent wrong paths) with the gentle consequences asserted, wish completion and the star, reload mid-turn, no console errors, target sizes ≥ 48 px, card not covering the guest. Screenshots <id>-port-*.png and <id>-land-*.png at meaningful moments (card visible, mid-animation, success).
- Also run against your worktree: smoke, plugin, regels, loop (port + land) from the main-tree scratch (local copies with the URL changed) and report their numbers.

REPORTING
- First line exactly one status: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED. If the engine API lacks something you need, do not edit shared files: implement a local workaround inside your game file when it is clean, otherwise report NEEDS_CONTEXT with the exact gap (function, file, what it should do) and finish everything else.
- Then at most 30 lines: design per band with example numbers, API members used, file:line of the register call and the generators, suite numbers per run, screenshot paths, worktree path/branch, concerns.
- Do not commit. Do not spawn agents. Kill only browsers you started (never a blanket pkill). The sandbox rejects very long shell heredocs: create files with the Write tool.
