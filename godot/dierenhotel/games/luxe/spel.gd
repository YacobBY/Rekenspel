extends WinkelSpel
## luxe — de luxe winkel: een gouden pui met etalages en een glazen vitrine
## met een kroon, een parelketting, een zonnebril en gouden slofjes (drie per
## dag op de vitrine).  Duur, en
## er komt een cadeaudoosje bij, dus hier wordt het meest gerekend: samen,
## terug van €100, en in groep 5 eerst de halve prijs (`beurt.gd`).
## De hele beurt staat in `games/_winkel/winkel.gd` (games-d.md §4).

func winkel() -> Dictionary:
	return {"id": "luxe", "naam": "Luxe winkel", "icoon": "💎", "label": "Luxe",
		"decor": "luxepuiz", "x": 16.0, "z": 62.0, "top": 9.0, "knop_hoog": 24.0,
		"plekken": [Vector2(0, -8), Vector2(0, 0), Vector2(0, 8)], "toon": 3,
		"klant": Vector2(36, 62), "buiten": Vector2(84, 64), "doos": Vector2(16, 44)}
