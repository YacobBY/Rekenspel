# X1 — Port specification: hotel world, state and game contract

TASK
Write `.fanout/specs/godot/world.md`: a complete specification of everything outside the individual minigames, so that a Godot developer can rebuild the hotel world at feature parity without reading the JavaScript.

EXPECTED OUTCOME
A document covering, at minimum:
1. Rooms (rooms.js): every room with its id, size in tiles or voxels, floor and wall look, decor objects with positions, doors and connections, the gang, the tuin and its zones, zwembad (bad, dek), wasserij; the camera rules per room; the runtime decor API (registerModel, decor, decorPlek).
2. Guests (hotel.js, state.js, world.js): species, names, appearance parameters, accessories (hoedje, sjaaltje, bal), poses (walk, lie, zwem, spring, sleep with 💤), movement API semantics (loopNaar, stappen, pose promises), idle wandering rules, the sleep-on-bed behaviour, morning routine.
3. Day cycle and economy (econ.js, hotel.js): what a day is, how it advances, stars, wishes (🏊 zwemmen, 🎁 souvenir and every other wish), check-in flow, the prikbord chips and the fair rotation rule with the 3-chip cap, HUD elements and their strings.
4. Save format (state.js): every field of save v7, the v6→v7 migration, corrupt-save behaviour, storage key.
5. The game contract (games/registry.js, game.js, GAMES-API.md): Games.register fields (id, prio, wens, start/stop, ctx.*), the lifecycle (start, klaar, stop, supersede, evening), how a game receives its band, guest, room; hotspot buttons and their placement rules (above/below the object, coverage 0 %, catch area = button ∪ object, 4-round evasion); the keypad/pad strip (padPlek) and the answer input contract; the star reward and Hotel.hud().
6. UI shell (ui.js, index.html, hits.js): start screen, room navigation, frame/kader layout bus (World.onKader, Ui.opKader), stable frame height, safe areas, audio unlock, hidden-tab pause, reduced-motion behaviour, the 12 px text floor, the hit-testing rules in hits.js.
7. Every child-facing string used by the world (not the games), verbatim, grouped by screen.

CONTEXT
The repo at /home/pc/Documents/xnw/rkn contains "Dierenhotel", a Dutch math game for children (groep 3–5) written in plain HTML and JavaScript under demos/dierenhotel/. It is being rebuilt in Godot 4.7 (GDScript) in a later wave by workers who will NOT read the JavaScript; they will read only your specification. Every rule, number, string and behaviour that matters must therefore be in your document, stated precisely, with child-facing Dutch strings quoted verbatim. Design rules that bind every game are in HOTEL.md §9 and GAMES-API.md (demos/dierenhotel/GAMES-API.md). Earlier design specs exist in .fanout/specs/dierenhotel-golf3-games.md and .fanout/tickets/g*.md; they may help but the code is the truth where they differ.

CONSTRAINTS
- Read-only against the game code. Write only the single spec file named in WRITE SET.
- Precise prose and tables; no code dumps except tiny formulas or constant lists where prose would be ambiguous. Quote all Dutch strings exactly.
- Where behaviour depends on the curriculum band (groep 3 / 4 / 5), give each band separately.
- Where a value is derived, give the formula and one worked example.

MUST DO
- State facts you verified in the code; mark anything inferred as "inferred".
- End with a section "Open questions for the port" listing anything the JavaScript leaves ambiguous.

MUST NOT
- Do not spawn subagents. Do not modify any file other than your spec file. Do not summarise loosely where exactness matters (generator constants, band limits, strings, timings).

OUTPUT FORMAT
Open with exactly one status: DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT or BLOCKED. Then at most 20 lines: what the spec covers, its length, the three most surprising facts, and concerns. Do not paste the spec into the report.

WRITE SET
.fanout/specs/godot/world.md only.
