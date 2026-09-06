TICKET D2 — Consolidate the wave-2 API notes into GAMES-API.md and HOTEL.md for the Dierenhotel demo.

TASK
Eleven tickets each documented their API in /home/pc/Documents/xnw/rkn/.fanout/specs/: api-p1a.md … api-p1f.md (rooms, models/decor, movement, wishes, accessories, sounds/stubs), api-x1.md (sleutels landscape layout rule), api-h1.md (hotspot placement `op`, short-frame policy, drop catch area, onWeg), api-m1a.md (padPlek, opKader helper, Snd unlock, CSS hooks), api-m1b.md (World.onKader/hermeet, density rule, pause semantics); read the code where a note is missing. Merge them into /home/pc/Documents/xnw/rkn/demos/dierenhotel/GAMES-API.md so a game author needs only that file, and refresh HOTEL.md §1 (rooms) where the notes changed it.

EXPECTED OUTCOME
1. GAMES-API.md gains or updates sections (keep the existing numbering style): rooms `zwembad` and `wasserij` with `Rooms.get('zwembad').bad` and `Rooms.get('tuin').zones` (values, coordinate conventions); `Rooms.registerModel(naam, fn(params))` with the voxel-list shape and `ctx.wereld.decor / decorWeg / decorLijst` (ownership, cleanup on stop, cost, draw order); `ctx.wereld.loopNaar / stappen / pose` with the supersede semantics, reduced motion and tempo, poses `zwem` and `spring`; the `wens` declaration in Games.register and the exact completion call for a wish; `ctx.wereld.accessoire / accessoires / accessoireWeg` and where the field is stored; sounds `Snd.plons / au / klok / hup`; the extension hook `window.CTX_UITBREIDINGEN` (for engine authors, one paragraph); a new section "Op de telefoon" for game authors: hotspot placement `op` and the drop catch area (H1), padPlek and the keypad strip in short frames (M1a), World.onKader instead of window resize listeners and World.hermeet after chrome changes (M1b), 12 px text floor, touch-only rules from HOTEL.md §9, and the device suites mobiel.js / mobiel-perf.js / hits-plaats.js as acceptance gates. Every signature must match the code in the main tree at the current HEAD: verify each one by reading the implementation (grep the function names in world.js, rooms.js, art.js, hotel.js, snd.js, games/registry.js) and note any discrepancy between a note and the code in your report rather than documenting the note.
2. §7 "deferred" list updated: remove items that this run delivered, keep the rest.
3. HOTEL.md §1: the room list matches rooms.js (names, sizes, doors, purpose one sentence each).
4. No other content changes; wording in the same register as the existing docs (Dutch where the file is Dutch, English where it is English — follow each file).

CONTEXT
Repo /home/pc/Documents/xnw/rkn, main tree at the commit named in your dispatch. Read-only for code; you edit only the two docs. No agents, no commit.

WRITE SET
demos/dierenhotel/GAMES-API.md, HOTEL.md.

OUTPUT FORMAT
First line DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED; then ≤ 20 lines: sections added/changed, discrepancies found between notes and code (file:line), anything left undocumented.
