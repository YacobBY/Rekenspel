extends WinkelSpel
## sjaals — de sjaalkraam: een das, het oranje sjaaltje en een streepsjaal (mint luifel).
## De hele beurt staat in `games/_winkel/winkel.gd` (games-d.md §4); hier staat
## alleen welke winkel dit is en waar alles staat.

func winkel() -> Dictionary:
	return {"id": "sjaals", "naam": "Sjaalkraam", "icoon": "🧣", "label": "Sjaals",
		"decor": "sjaalkraam", "x": 54.0, "z": 12.0, "top": 10.0, "knop_hoog": 30.0,
		"plekken": [Vector2(-8, 4), Vector2(0, 4), Vector2(8, 4)],
		"klant": Vector2(54, 34), "buiten": Vector2(60, 84)}
