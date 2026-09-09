extends Node
## Econ — coins, stars, letters and the bill.  Autoload #8.
## Port of `demos/dierenhotel/econ.js` (world.md §3.5, §3.6).
##
## W2 fills in: the three-step bill (sum, counting coins, change) with the help
## ladder of world.md §3.5, the letters and the kassa sheet.  The coin helpers
## are frozen and already live in `Sommen`.

signal sterren_veranderd(aantal: int)
signal munten_veranderd(aantal: int)

## A star is for taking part, never for being right (HOTEL.md §9).
func sterren(n: int = 1, _bron: String = "") -> void:
	State.s["sterren"] = int(State.s["sterren"]) + n
	Snd.ster()
	sterren_veranderd.emit(int(State.s["sterren"]))
	Hotel.hud()

func geef_munt(n: int) -> void:
	State.s["munten"] = int(State.s["munten"]) + n
	munten_veranderd.emit(int(State.s["munten"]))
	Hotel.hud()

func buidel(totaal: int) -> Array[int]:
	return Sommen.buidel(totaal)

func splits(n: int) -> Array[int]:
	return Sommen.splits(n)

func rekening(_o: Dictionary) -> void:
	push_warning("Econ.rekening: W2")   # W2
