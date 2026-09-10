# G-was — Port the minigame "Wasmandtoren" (was)

TASK
Implement the minigame was in `godot/dierenhotel/games/was/` at feature parity with games-b.md §4, under the common contract in `.fanout/tickets/godot/_gemeenschappelijk-wave2.md` (read it first, it is part of this ticket).

GAME-SPECIFIC NOTES
Room wasserij, hotspot tobbe 🧺, unlock N ≥ 1, taak was prio 8. Sommen.Was.* (koekjesSom → somDeel → kiesT → verdeel → recept). Crates, plates with word/singular/icon tiers, the pile text '26 nog te sorteren / pak 2', the hand cloud, turven and the bar chart. The HTML meetIndeling was built on DOM measurement: replace it with a container layout that guarantees every crate plate visible in the four frame sizes and three bands (assert it in a test, 0 misses).

WRITE SET, CHECKS, OUTPUT FORMAT: as in the common contract.
