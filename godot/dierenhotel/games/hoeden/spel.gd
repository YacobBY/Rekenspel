extends WinkelSpel
## hoeden — de hoedenkraam: een pet, een strohoed en een strik (roze luifel).
## De hele beurt staat in `games/_winkel/winkel.gd` (games-d.md §4); hier staat
## alleen welke winkel dit is en waar alles staat.

func winkel() -> Dictionary:
	return {"id": "hoeden", "naam": "Hoedenkraam", "icoon": "🎩", "label": "Hoeden",
		"decor": "hoedenkraam", "x": 22.0, "z": 12.0, "top": 10.0, "knop_hoog": 30.0,
		"plekken": [Vector2(-8, 4), Vector2(0, 4), Vector2(8, 4)],
		"klant": Vector2(22, 34), "buiten": Vector2(28, 82)}
