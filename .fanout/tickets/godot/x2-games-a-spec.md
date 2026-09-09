# X2 — Port specification: games bedden, sleutels, meubels, tobbe, voerkar

TASK
Write `.fanout/specs/godot/games-a.md`: complete specifications of the five minigames bedden.js, sleutels.js, meubels.js, tobbe.js and voerkar.js in demos/dierenhotel/games/, so that a Godot developer can rebuild each at feature parity without reading the JavaScript.

EXPECTED OUTCOME
For each game, a section with: the in-world story and which room and guest it uses; how it is launched (prikbord chip, wish, hotspot) and its prio and wens fields; the mathematical goal per band (groep 3 / 4 / 5) with every generator rule and constant (ranges, step sizes, distractor rules, how many turns, repetition rules, what makes a turn "distinct"); the full turn flow (what the child sees, taps, types; help after wrong answers; the never-punishing rule; what counts as done); every child-facing string verbatim in the order it appears; the visual layout (objects drawn, cards, keypad placement, where the guest stands, animations and timings in ms, sounds by name); the reward and how it reports back to the hotel; reduced-motion and stop/supersede behaviour; the "frozen math" functions noted in the ledger (koekjesSom, vergelijk, planOplossingen, planFouten, sommen.*) reproduced exactly as formulas so the port gives byte-identical results for the same seed, including the random number source used.

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
.fanout/specs/godot/games-a.md only.
