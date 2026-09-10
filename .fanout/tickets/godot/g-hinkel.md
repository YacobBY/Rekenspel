# G-hinkel — Port the minigame "Hinkelpad" (hinkel)

TASK
Implement the minigame hinkel in `godot/dierenhotel/games/hinkel/` at feature parity with games-b.md §3, under the common contract in `.fanout/tickets/godot/_gemeenschappelijk-wave2.md` (read it first, it is part of this ticket).

GAME-SPECIFIC NOTES
Room tuin, hotspot hok 🪨, unlock N ≥ 1, wens spelen, taak prio per the spec (2 or 5). Sommen.Hinkel.* (beurt, matenVoor, keuze_getallen). Band 3 line 0–10 with a number on every stone; distances multiples of the stone pitch; the stair always on a stone; the animal hops the chosen count even when wrong (never blocked, no attempt cap, per spec); houdVrij keeps idle guests off the strip (World has the reserved-zone API); walk-up card only on the start stone; stop() cancels a hop.

WRITE SET, CHECKS, OUTPUT FORMAT: as in the common contract.
