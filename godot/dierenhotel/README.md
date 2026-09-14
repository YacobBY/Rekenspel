# Dierenhotel — Godot 4.7

De Godot-versie van het rekenspel Dierenhotel (groep 3–5). GDScript, Compatibility-renderer, web-export zonder threads (werkt op GitHub Pages), PWA.

## Spelen

```
tools/export.sh          # bouwt build/web/
tools/serve.sh           # http://localhost:8642/
```

Op een tablet in hetzelfde netwerk: open het adres van deze computer op poort 8642. Na publicatie op GitHub Pages: open de Pages-URL en kies "Zet op beginscherm".

## Ontwikkelen

- Godot 4.7.2 (`~/.local/bin/godot`), export templates in `~/.local/share/godot/export_templates/4.7.2.stable/`.
- Tests: `tools/test.sh` (±390 tests, ±95 s). Eén spel: `DH_TEST_FILTER=kraam tools/test.sh`.
- Browser-controle: `tools/probe.js --viewport 1024x768@2:ipad --knop bel`.
- Een spel op een bepaalde dag/band bekijken: `index.html?opslag=<base64url van een volledige save>`.
- Ontwerp: `.fanout/specs/godot/architecture.md`. Regels voor kindteksten: `HOTEL.md` §9.
- Antwoorden: altijd een strook van hooguit vier knoppen onder het kaartje (`"goed": n` op `Ui.somkaart` maakt er vier getallen van via `ui/afleiders.gd`); er is geen cijferpad.
- Een gast die uit een kamer buiten beeld komt aanlopen krijgt een bubbel met balk bij de deur (`Hotel.komt_eraan`).

## Structuur

```
autoload/   Art, Rooms, Hits, World, Snd, Ui, State, Econ, Games, Hotel
core/       de bevroren rekenkern (Sommen), byte-gelijk aan de HTML-versie
spel/       MiniGame en SpelCtx: het contract voor elk minispel
games/<id>/ tien minispellen, elk met eigen tests
ui/, hotel/, wereld/, scenes/, art/, fonts/, tests/
```
