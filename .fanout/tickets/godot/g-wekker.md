# G-wekker — Port the minigame "Wekkerdienst" (wekker)

TASK
Implement the minigame wekker in `godot/dierenhotel/games/wekker/` at feature parity with games-b.md §2, under the common contract in `.fanout/tickets/godot/_gemeenschappelijk-wave2.md` (read it first, it is part of this ticket).

GAME-SPECIFIC NOTES
Room gang, hotspot kist + offset ⏰, unlock N ≥ 1, taak wekker prio 3. Sommen.Wekker.* (doelTijd, afstand, duurKeuzes, tijdWoord). Ghost hands at the 2nd miss (HOTEL.md §5 wins over GAMES-API §6, per architecture.md §13). architecture.md §6.5 walks one wekker turn call by call: follow it. Register the clock as wekker_klok.

WRITE SET, CHECKS, OUTPUT FORMAT: as in the common contract.
