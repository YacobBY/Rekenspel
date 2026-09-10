# G-bedden — Port the minigame "Bedden op rij" (bedden)

TASK
Implement the minigame bedden in `godot/dierenhotel/games/bedden/` at feature parity with games-a.md §3, under the common contract in `.fanout/tickets/godot/_gemeenschappelijk-wave2.md` (read it first, it is part of this ticket).

GAME-SPECIFIC NOTES
Room kamer1, hotspot mand 🛏, unlock N ≥ 1, taak bedden prio 5. The bed arrays per band (band 5 7×6 arrays needed a bigger room in the HTML; in Godot the room is 1.5× already, verify the array fits at 360×740 and fall back per spec). Use Sommen.Bedden.*. The card 3-round placement of the HTML is replaced by the band grid.

WRITE SET, CHECKS, OUTPUT FORMAT: as in the common contract.
