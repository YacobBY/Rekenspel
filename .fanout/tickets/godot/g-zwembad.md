# G-zwembad — Port the minigame "Zwembad" (zwembad)

TASK
Implement the minigame zwembad in `godot/dierenhotel/games/zwembad/` at feature parity with games-b.md §1, under the common contract in `.fanout/tickets/godot/_gemeenschappelijk-wave2.md` (read it first, it is part of this ticket).

GAME-SPECIFIC NOTES
Room zwembad (bad, dek), hotspot mat 🏊, unlock N ≥ 1, wens zwemmen, taak zwemles prio 1. THE OWNER'S RULES ARE BINDING VERBATIM: variable pool length (band 5 pool 31–80 m per Sommen, not 76), 1 m per stroke, four choices, max 30 m per pick, too short continues, too far bumps the wall with a short 💛 Au! and never a cross, exact finish 'Precies aan de overkant'; distractor ordering per the G1-F1 rules (Sommen.Zwembad.keuze_getallen reproduces the owner's card 43 → 43,13,20,30). Swimmer uses World pose zwem (water band, hoogte −7); finish card ≥ 8 px from the swimmer and the flag (structural via the band grid). Guest must never be left in the water on stop()/supersede.

WRITE SET, CHECKS, OUTPUT FORMAT: as in the common contract.
