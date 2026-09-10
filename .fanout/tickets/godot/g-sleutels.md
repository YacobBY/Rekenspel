# G-sleutels — Port the minigame "Het sleutelbord" (sleutels)

TASK
Implement the minigame sleutels in `godot/dierenhotel/games/sleutels/` at feature parity with games-a.md §4, under the common contract in `.fanout/tickets/godot/_gemeenschappelijk-wave2.md` (read it first, it is part of this ticket).

GAME-SPECIFIC NOTES
Room receptie, hotspot sleutelbordz 🔑, unlock N ≥ 2, taak sleutels prio 5. The only game with randomness: seeded by Sommen.Sleutels (dag*7919 + N*131 + band*17 + ronde*8191 + 1); kiesBlanco may return fewer blanks than asked, then an extra board follows (spec). The HTML opbouw() layout heuristic (gewoon/stapel/naast/krap) measured DOM sizes; replace it with a Control-based layout that picks the variant by frame size, preserving the four variants' intent. Note the receptie was relaid (desk top-right along the back wall, door top-left): the sleutelbord hangs on the desk side; take its position from Rooms, never hard-code.

WRITE SET, CHECKS, OUTPUT FORMAT: as in the common contract.
