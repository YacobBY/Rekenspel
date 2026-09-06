TICKET S3 — Shared fixes collected from the wave-3 reviews (Dierenhotel demo).

TASK
Seven small, independent fixes in shared files, found while reviewing the five new games and the mobile tickets. Isolated worktree off main (≥ 5b02bb9). Each item names its evidence.

EXPECTED OUTCOME
1. Hotspots on runtime decor (games/registry.js, and world.js only if needed): `registry.plek()` / the hotspot anchoring resolves only dingen, slots and fixed decor, so wekker, kraam and hinkel hang their entry hotspot on an unrelated fixed piece (kist, bal, hok) with dx/dz offsets. Extend the lookup additively: when `hotspot.obj` names an id of a runtime decor piece (`World.decorLijst(kamer)`, api-p1b.md), anchor to that piece; keep every existing behaviour for known names. A game's decor exists only while it runs, so the entry hotspot may still fall back to the fixed piece when the decor is absent — document that in GAMES-API.md (§ runtime decor) with a two-line example. Do not edit the game files.
2. Star counter (econ.js / games/registry.js): `ctx.taakKlaar` → `Econ.sterren`/geefSter awards the star but the topbar counter (#sterNum) only refreshes when the game closes (hotel.js:858 renders only an open prikbord; reported by G4 and confirmed by the reviewer). Refresh the counter immediately (call the existing topbar render, not a full Hotel.render if that is expensive); assert with a Playwright probe.
3. GAMES-API.md ~line 823 says the prikbord default exists "voor de vier bestaande spellen"; there are nine games now — correct that sentence only.
4. plugin.js crash on main (scratch suite .fanout/scratch/dierenhotel/plugin.js:331 `[data-hot="ap_som_pad"]` null since M1b's world.js): at the suite's viewport 420×900 the world frame drops under KADER_KORT = 300 px so the numpad moves to the shared #padstrip and the anchored pad hotspot never exists. First determine whether a portrait frame < 300 px at 420×900 is itself a regression (at 420×860 the frame is ~441 px; measure both and read world.js ruimteHoogte / kaderHoogte / schermHoogte): if the frame is wrongly small, fix world.js; in any case make plugin.js find the pad where it is (strip or in-frame) so it passes 54/0 against main.
5. 320×640: the bedden sum card (bd_som, 129 px) still overlaps the first row bd_rij0 by 123×39 px and a drag to the row centre misses (M1c residual; the card needs to be shorter or narrower in the smallest frames). In style.css (.hot.hotsom and its sentence/sum rows) reduce the card footprint below 360 px frames (one-line sentence allowed to wrap once, smaller paddings, ≥ 44 px targets kept) so bedden at 320×640 has no overlap; assert with the bedden suite or a small probe at 320×640.
6. voerkar-port 262/1 (pre-existing, `staand 6g hulp: geen kaartje dekt een ander kaartje af`, chips vk_zak × vk___pot overlap 33×48 px with 6 guests in the hulp state): fix the chip spacing in games/voerkar.js so the suite is 263/0 (do not loosen the assertion).
7. .fanout/specs/api-p1a.md:59 footprint comment (kist 90..100/18..28, bal 116..124) is one voxel off rooms.js:485-486 (kist 89..101/17..29): correct the note.

VERIFY against your worktree: plugin.js 54/0, regels, smoke, voerkar port + land, bedden (bedden/bedden.js) + bedden/layout.js, w1 port + land, mobiel.js one portrait and one landscape profile, mobiel-perf, hits-plaats, wekker/spel.js port (hotspot anchoring unchanged for existing names), k1 (frame heights). Report every number.

CONTEXT
Repo /home/pc/Documents/xnw/rkn; isolated worktree (absolute paths; fast-forward to main's HEAD if older). Scratch is gitignored: copy harnesses (DH_SRC / DH_OUT); plugin.js is a main-scratch file you may edit directly (atomically). Five game worktrees are open in parallel (games/zwembad.js, hinkel.js, was.js, kraam.js): do not touch those files or games/wekker.js. Kill only browsers you started. Long shell heredocs are rejected: use Write/Edit. No dependencies, no agents, no commit.

MUST NOT
Edit games/{zwembad,wekker,hinkel,was,kraam}.js, hits.js placement policy, ui.js, hotel.js (except if item 2 strictly needs a one-line topbar refresh export), rooms.js, state.js, art.js.

WRITE SET
demos/dierenhotel/games/registry.js, demos/dierenhotel/world.js (item 1 lookup and item 4 only), demos/dierenhotel/econ.js, demos/dierenhotel/GAMES-API.md (items 1 and 3), demos/dierenhotel/style.css (item 5), demos/dierenhotel/games/voerkar.js (item 6), .fanout/specs/api-p1a.md, .fanout/scratch/dierenhotel/plugin.js.

OUTPUT FORMAT
First line DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED; then ≤ 20 lines: per item file:line and evidence, the 420×900 frame diagnosis, suite numbers, worktree path/branch, concerns.
