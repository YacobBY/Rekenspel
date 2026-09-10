# G-kraam — Port the minigame "Souvenirkraam" (kraam)

TASK
Implement the minigame kraam in `godot/dierenhotel/games/kraam/` at feature parity with games-b.md §5, under the common contract in `.fanout/tickets/godot/_gemeenschappelijk-wave2.md` (read it first, it is part of this ticket).

GAME-SPECIFIC NOTES
Room tuin, hotspot bal 🎁 (offset), unlock N ≥ 1, wens souvenir, taak souvenir prio 1. Sommen.Kraam.* (opzet, keuring; the 432-combo sweep is already green). Whole euros ≤ €20; three separate icon-only coin sources €1/€2(/€5) ≥ 53×48 px; ghost coins [5,2,1] exact; overpaid coin never saved before the slide-back (herstelBank repair on reload); help counts by ones (telVanaf); self-filling answer box; 🎁 beside the guest; all three price tags; the keypad falls outside the frame when the strip-free frame is < 360 px (padPlek 'buiten' rule → in Godot use the band grid's keypad band).

WRITE SET, CHECKS, OUTPUT FORMAT: as in the common contract.
