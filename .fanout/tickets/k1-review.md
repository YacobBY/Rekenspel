PRELIMINARY CODE REVIEW (read-only: do not edit any file, do not spawn agents, kill only browser PIDs you started) — ticket K1 "Enlarge the Dierenhotel rooms by 1.5× (except the corridor) and make the camera/hotspots/positions/save follow". Produce a ≤35-line brief for the lead ending with one verdict line: LOOKS_GOOD / FIX_FIRST / REWORK.

WHERE
Repo /home/pc/Documents/xnw/rkn. The K1 change is commit 710003e (parent 25a4b52): `git --no-pager diff 25a4b52 710003e --stat` and per file. HEAD is af8ab32 (on top: an unrelated sleep-fix merge touching world.js sleep/arrival/zzz/pose regions, rooms.js sta-plek and pillow, hotel.js morgen, art.js, bedden.js:617-634, and a registry hook — ignore those hunks). Worker artefacts in .fanout/scratch/dierenhotel/: k1.js (probe suite, 191 assertions), k1-maten-voor-na.txt (scale table), k1-*-{420x860,860x420,360x740,320x640,768x1024,1280x800}.png (36 screenshots), k1-sleutels-land-HEAD.txt, alles.sh + alles-samenvatting.txt + alles-out/. Playwright: /home/pc/work/ergomouse/node_modules/playwright. The demo is vanilla JS loaded from file://demos/dierenhotel/index.html.

THE TICKET (essentials)
User: "Veel kamers voelen iets te klein maak ze 50% groter behalve de gang die ziet er wel goed uit." Enlarge floors of receptie (80×80→120×120), kamer1/kamer2 (76×76→114×114), keuken (80×76→120×114) in voxels; gang and tuin unchanged. Every enlarged room must still fill the frame as "one room on screen" on 420×860, 860×420, 360×740, 320×640, 768×1024, 1280×800 with no clipping of the room box and ≥60 % fill; all games and the guest flow play as before with objects re-based (positions derived from r.w/r.d, not new magic numbers); old saves migrate (v6→v7, furniture ×1.5 then snapped); frozen math in state.js byte-identical; alles.sh green except where a suite encoded the old dimension; HOTEL.md §1 documents the camera decision; ≥48 px targets, cards never cover their guest, nothing punishing.

WORKER'S CLAIMS TO GRADE
- Per-room scale q (world.js maatVan): each room fills the frame width; integer g 2..4; canvas renders at density dicht = max(screen dpr, g/q) and is CSS-scaled back; frame height global = min(available, smallest box·q/0.60); camDoel reserves the 132 px KADER_ONDER strip; rooms got loop: 1.5 so crossing time stays ~4 s. Bare top wall may crop in short frames ("pre-existing camera rule").
- Rebased constants via new Rooms.plek/hoogte fractions in rooms.js:330-420, world.js:876 RUST, hotel.js:69/404/410/481/812/819/1009 + ciHoog(), econ.js:78/99/141/256/263, meubels.js:70-77, sleutels.js:73-90 vox(f), voerkar.js:52-75, bedden.js:57-68 MAX_CAP=6 / :96 / :107 / :140 / :150.
- Migration: key kws-hotel-v7, leesSpel reads v7 else v6 → naarV7 (×1.5 in four rooms, snapped via Rooms.vrijVak); chain v5→v6→v7 asserted in k1.js and loop.js.
- hits.js:147/192 fix: hotspots measured while display:none cached a 56×48 fallback.
- alles.sh: 20/21 suites OK, 1867 pass / 4 fail; the 4 sleutels-land failures claimed pre-existing at 25a4b52.
- Frozen math: state.js lines 1-549 md5 identical before/after.
- Concerns: bedden room now holds ~19 beds while MAX_CAP=6; phones oversample the canvas (dicht 2.5–3.8, canvas up to ~1500×1450) → softer voxels, landscape floor −8 %.

CHECK SPECIFICALLY
1. Is the 1.5× applied to exactly the four rooms (rooms.js room table), with decor/slots/doors scaled consistently (beds on the 12-grid, doors reciprocal, balie walkable around)?
2. Scale design: read maatVan and the density/CSS-scale code. Any non-integer g? Any place still using the old global g (breedsteKamer/hoogsteKamer callers, plate cache key id|g, hits.js hermeet, ui.js pad anchoring, World.debug().dpr) that would misplace hotspots or cards after a room switch? Do hotspots re-measure on room switch; does the 4-slot plate cache thrash with 6 rooms?
3. Performance/memory: a canvas of ~1500×1450 at density 3.8 on a phone — is the world redrawn every frame or only when dirty; is this acceptable; would a cheaper density rule (cap dicht at screen dpr, accept slight g/q blur) be wiser?
4. Rebased constants: spot-check five in the screenshots (check-in card beside the guest, bill/change cards, sleutels hook row, voerkar bowls in the keuken, meubels bank) at 420×860 and 860×420 by viewing the k1-*.png files. Anything clipped, overlapping, or off-floor?
5. Bedden: with rows centred on r.w=114 and fractional rijStap, do 3 rows × 2 beds still read as a clear array; is guest capacity (State.bedVrij, MAX_CAP) consistent with the number of beds a child can lay?
6. Migration correctness: naarV7 on a v6 save with beds in kamer1 at x=8,z=20 and furniture in gang; on a v5 save; on a corrupt save; idempotence (v7 loaded twice). Cite lines.
7. Verify the "pre-existing" claim for the 4 sleutels-land failures (k1-sleutels-land-HEAD.txt; rerun against `git archive 25a4b52` if unconvincing).
8. Docs: HOTEL.md §1 and GAMES-API.md accurate (Rooms.plek/hoogte, camera rule)?
9. Anything in the diff outside the write set (art.js, ui.js wording, registry.js beyond migration, demos/waggletail, demos/silverhoof)?

OUTPUT FORMAT
≤35 lines: findings by severity with file:line, tagged BLOCKING / SHOULD-FIX / NIT; the worker's three concerns pre-graded (REAL / UNFOUNDED / DEFER); what you verified yourself vs took on trust; verdict line.