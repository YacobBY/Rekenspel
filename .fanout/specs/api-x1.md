# X1 — de opstelling van het sleutelbord in een laag kader

Gedrag van `demos/dierenhotel/games/sleutels.js` sinds X1. Alleen de plékken
veranderen; de getallen, de zinnen, de hotspot-API en de rest van het spel
blijven zoals ze waren.

## Waarom

De hoogtes in het spel staan als breuk van de kamer (voxels, HOTEL.md 1) en
krimpen dus mee met de voxelmaat `k`. Een sommenkaart doet dat niet: die is
92 css-px hoog omdat er één gewone zin op staat (HOTEL.md 9), op elk scherm.
In een laag kader loopt dat mis:

| kader (viewport) | k | py0 | wat er gebeurde |
|---|---|---|---|
| 386×473 (420×900 staand) | 0,78 | 124 | kaart 79 px boven de rij: goed |
| 966×378 (1000×640 liggend) | 1,25 | 73 | de kaart wíl 54 px boven het kader hangen; de knoppenlaag klemt hem tegen de bovenrand (onderrand 94 px) en hij lag 38 px ín de rij haakjes. De laag schoof haakje 0 en 1 uit de rij |
| 826×190 (860×420) / 706×190 (740×360) | 0,64 | 38 | kaart (92) + rij (48) + wolkje (48) passen niet boven de kop van de gast (38 px wand) |

De sommenkaart is `vast` (ui.js `somkaart`): hij kiest als eerste zijn plek en
wijkt nooit uit. Alles wat later kiest — de sleutel bij de poot, het wolkje,
en dán de rij haakjes — moet dus om hém heen. Ligt de kaart op de rij, dan
schuift `hits.js` de haakjes weg en is de rij geen rij meer.

## De regel

`opbouw()` in `games/sleutels.js` (na de eerste tekenbeurt, dus met de echte
maten uit de pagina) rekent in css-px binnen `#worldHits`, met dezelfde
projectie als de knoppenlaag:

```
scherm-x = px0 + (x - z) * 2k        scherm-y = py0 + (x + z - 2y) * k
k = ctx.wereld.schaal().k    (px0, py0) = achterhoek van World.vloer()
```

Daarmee kiest hij één van drie opstellingen (`debug.opbouw()` vertelt welke):

1. **`gewoon` / `stapel`** — kaart boven, rij eronder, wolkje onder de rij.
   De rij zakt van HAAK_Y (72) naar precies zo laag als de kaart nodig heeft
   (`kaartOnder + 4 + knop/2`), het wolkje daaronder (48 px van de rij én van
   de sleutel af, want minder vindt de laag "dekt af"), maar altijd boven de
   kop van de gast. Past alles al, dan verandert er niets (`gewoon`, portret).
   Liggend 966×378 geeft `haakY = 55`, `wolkY = 54`: kaart 2–94, rij 99–147,
   wolkje 154–202, sleutel 282–330.
2. **`naast`** — blijft het wolkje niet boven zijn kop, dan komt de kaart
   uiterst links (2 px van de rand) en gaat de rij rechts ernaast op haar
   gewone wandhoogte staan; het wolkje zakt onder de rij en schuift zo nodig
   langs de wand naar rechts tot het naast de kaart staat. Zo staat het op een
   liggende telefoon: 826×190 → `haakX = 20`, `wolkX = 14`, kaart 2–345,
   rij 18–66, wolkje 73–121, sleutel 134–182.
3. **`krap`** — past `naast` ook niet in de breedte (kader < ~460 px voor de
   rij, of een staande telefoon van 356×401 en kleiner), dan gaat de rij vóór:
   die blijft heel en de kaart blijft erboven, en het wolkje mag over de kop
   van de gast hangen. Kan het ook daar niet tussen de rij en de sleutel
   staan (kader 326×397 en kleiner), dan staat het onder de sleutel.

Verder houdt de rij altijd 53 css-px tussen de plaatjes (zo breed als een
oplichtend plaatje met drie cijfers): bij `k = 0,58` (kader 286 px breed) was
4·20·k maar 47 px en schoof de laag de rij zelf uit elkaar.

Kantelt het scherm, dan bouwt het spel 220 ms later opnieuw op
(`resize`/`orientationchange`, zoals het cijferpad van ui.js dat al deed).

## Wat een ander spel hiervan kan gebruiken

`World.vloer()` + `ctx.wereld.schaal()` geven samen de projectie van de kamer
in css-px; `voerkar.js` zet zijn bakjes er al mee uit. Voor een spel dat een
rij of een raster in de wereld legt is dit het gereedschap:

* meet de echte maat van je kaartje/knopjes ná één tekenbeurt (`offsetWidth`);
* reken je wens in css-px uit en zet die met `y = (x+z - (py - py0)/k) / 2`
  terug in voxels;
* houd minstens `(h1 + h2) / 2` px tussen twee knoppen — daaronder schuift
  `hits.js` ze uit elkaar, en dat is wat een rij kapot maakt;
* wat `vast` is (sommenkaart, cijferpad) kiest eerst: reken erom heen.

## Grens

Op 534×190 (568×320 liggend) met de langste kaart (343 px, variant
"kamers") past `naast` niet in de breedte en `krap` niet in de hoogte: daar
staat het wolkje van de gast nog over de rij. Kader 286×314 (320×640 staand)
houdt de rij heel, maar het wolkje staat er onder de sleutel. Beide kaders
zijn kleiner dan waar HOTEL.md 9 een volledige garantie geeft.
