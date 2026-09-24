extends WinkelSpel
## sjaals — de sjaalkraam: een das, het oranje sjaaltje en een streepsjaal (mint luifel).
## De hele beurt staat in `games/_winkel/winkel.gd` (games-d.md §4); hier staat
## alleen welke winkel dit is en waar alles staat.
## Weggestuurd sjokt het dier naar (74, 80): van zijn oude plek (60, 84) liep
## de weg terug naar de deur, die sinds 2026-09-24 in de linkerwand zit, door
## de vitrine van de luxe winkel (games-d.md §3).

func winkel() -> Dictionary:
	return {"id": "sjaals", "naam": "Sjaalkraam", "icoon": "🧣", "label": "Sjaals",
		"decor": "sjaalkraam", "x": 54.0, "z": 12.0, "top": 10.0, "knop_hoog": 30.0,
		"plekken": [Vector2(-8, 4), Vector2(0, 4), Vector2(8, 4)],
		"klant": Vector2(54, 34), "buiten": Vector2(74, 80)}
