extends WinkelSpel
## schoenen — de schoenenkraam: sokjes, gympjes en laarsjes, per schoentje, één per poot (blauwe luifel).
## De hele beurt staat in `games/_winkel/winkel.gd` (games-d.md §4); hier staat
## alleen welke winkel dit is en waar alles staat.

func winkel() -> Dictionary:
	return {"id": "schoenen", "naam": "Schoenenkraam", "icoon": "👟", "label": "Schoenen",
		"decor": "schoenenkraam", "x": 86.0, "z": 12.0, "top": 10.0, "knop_hoog": 30.0,
		"plekken": [Vector2(-8, 4), Vector2(0, 4), Vector2(8, 4)],
		"klant": Vector2(86, 34), "buiten": Vector2(84, 82)}
