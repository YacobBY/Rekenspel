# G-meubels — Port the minigame "Het meubelboek" (meubels)

TASK
Implement the minigame meubels in `godot/dierenhotel/games/meubels/` at feature parity with games-a.md §5, under the common contract in `.fanout/tickets/godot/_gemeenschappelijk-wave2.md` (read it first, it is part of this ticket).

GAME-SPECIFIC NOTES
Room receptie, hotspot boek 📖, unlock N ≥ 3, taak meubels prio 5. Uses the planbord solver Sommen.maak_plan/plan_oplossingen/plan_fouten and the WINKEL/VERSIERING catalogue in Sommen.Meubels; buying furniture goes through the furniture API (World.kamer_meubels, verwijder_meubel, meubeltypen; Hotel.bewaar_inrichting mirrors it into the save). Drag placement: use the ctx pak/laat drag contract (architecture.md §10).

WRITE SET, CHECKS, OUTPUT FORMAT: as in the common contract.
