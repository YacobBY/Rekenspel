# API P1a — ruimtes `zwembad` en `wasserij`, zones in de tuin

Geleverd door ticket P1a (run dierenhotel-slaap-zwembad-kamers, golf 3). Alles is data in `demos/dierenhotel/rooms.js` (RUIMTES-tabel), plus één kaartcel per ruimte in `hotel.js` (KAART) en één rustplek per ruimte voor de voerkar in `world.js` (RUST). Geen spel-logica; de spellen G1 (zwembad), G3 (hinkelpad), G4 (wasmandtoren) en G5 (souvenirkraam) lezen wat hieronder staat. Maten in voxels, assen zoals overal: wanden op x = 0 (links) en z = 0 (achter), x loopt naar rechtsonder op het scherm, z naar linksonder.

## 1. Zwembad (`Rooms.get('zwembad')`)

| veld | waarde |
|---|---|
| `id`, `naam`, `icoon` | `zwembad`, "Zwembad", 🏊 |
| `w × d`, `wand` | 144 × 88, wandhoogte 50 (kamerdoos 484 × 354 voxel-px) |
| `vloer`, `loop` | `tegel`, 1.5 (zelfde loopmaat als de grote kamers: de doos is even breed) |
| `bad` | `{ x0: 18, x1: 134, z0: 12, z1: 44 }` — het water, 116 × 32 voxels, 81 % van `w` |
| `dek` | `{ start: { x: 12, z: 56 }, over: { x: 132, z: 56 } }` — de twee **staplekken** op het dek vóór het water (zie "Wachten op het dek") |
| rand | 4 voxels bijna witte steen rondom het water (x 14..138, z 8..48) plus een donkerder waterrand van 4 voxels aan de binnenkant; alleen vloerkleuren (`Rooms.vloerKleur`: `BADRAND`, `BADKANT`, `BADWATER`), geen model, geen veld |
| `deuren` | `[{ naar: 'tuin', wand: 'x', at: 60, breed: 12 }]` → `deurPunten[0] = { x: 0, z: 66, ix: 8, iz: 66 }` |
| `decor` | `mat` op (9, 28) = het instapmatje op de startrand, in de zwembaan; `plant` op (136, 80) |
| `slots` | leeg |
| dwaalplekken | 9 stuks, allemaal vóór het water (z = 60 en z = 72); `Rooms.plekken('zwembad')` en `Rooms.slots('zwembad','vrij')` liggen nooit in of naast het water |
| kaart / rust | KAART `[4, 3]` (onder de tuin); RUST voerkar `Rooms.plek('zwembad', 0.5, 0.8)` = (72, 70) |

**Baan van L meter → x.** Het bad blijft even groot; de spellengte L wordt op de badlengte geschaald:
`x(p) = bad.x0 + (bad.x1 - bad.x0) * p / L` (p = positie in meters, 0 ≤ p ≤ L), zwembaan op `z = (bad.z0 + bad.z1) / 2 = 28`.
Meterstrepen op de rand: z = bad.z0 - 2 (achterrand) of z = bad.z1 + 2 (voorrand), x volgens dezelfde formule. Vlag/lijn bij de overkant: x = x(L) = bad.x1.

**Wachten op het dek (`dek`).** Een gast die naar het zwembad gaat, **staat op `dek.start` (12, 56)** — bij de startrand, snuit naar +x — of op `dek.over` (132, 56) bij de overkant. Beide plekken liggen op het dek vóór het water: 12 voxels onder de waterlijn (`bad.z1` = 44) en 12 voxels van de vloerrand, dus een gast van ~17 voxels breed staat er helemaal op de tegels en raakt het water niet. `plekVanBehoefte` en elk spel dat een dier wil laten wachten gebruiken `Rooms.get('zwembad').dek.start`, niet de zwembaan.

De korte kanten van het bad zijn géén staplekken: de startrand is maar 14 voxels breed (x < 14, met het instapmatje op (9, 28) in de zwembaan) en de overkant 6 (x > 138) — te smal voor een hele gast. Een dier dat de overkant haalt, staat op x ≈ `bad.x1` in het water; het klimt eruit naar `dek.over`.

**Waarom alles wat een gast zélf doet vóór het water ligt.** De dieren lopen in rechte lijnen (`world.js` `Dier.rijd`). Met plekken aan beide lange kanten zou een gast dwars door het bad wandelen. `bouwAf` gooit daarom elk vrij vakje met `z < bad.z1 + 6` weg, en de deur (8, 66) én `dek.start`/`dek.over` (z = 56) liggen in diezelfde strook z ≥ 50. Die strook is convex, dus geen enkele wandeling tussen die punten — dwaalplek ↔ dwaalplek, dek ↔ dwaalplek, dek ↔ deur, dek ↔ dek — kruist het water. p1a.js toetst dat paarsgewijs (9 dwaalplekken + deur + 2 dek-plekken, 22 dek-lijnen erbij) én met echte gasten: twee gasten die 15 s vanaf het dek dwalen en vier gasten × 2000 tikken komen nooit in het bad.

De zwembaan `z = (bad.z0 + bad.z1) / 2 = 28` ligt ín het water en is **alleen** voor een spel dat het dier zelf stuurt: wie een dier op het instapmatje of in het bad wil hebben, zet het er zelf neer (`World.zet`/`World.ga`/`ctx.wereld.reis(id, 'zwembad', { x, z, na })` mét doel). Zet nooit een dwaal- of staplek in het water, en laat een dier nooit uit zichzelf van een plek in het water naar een dwaalplek lopen. `World.reis` zónder doel in de rust-modus mikt op het midden van de kamer (72, 44) — dat is de voorrand van het bad: geef altijd een doel mee (bijvoorbeeld `dek.start`).

## 2. Wasserij (`Rooms.get('wasserij')`)

| veld | waarde |
|---|---|
| `id`, `naam`, `icoon` | `wasserij`, "Wasserij", 🧺 |
| `w × d`, `wand` | 100 × 90, wandhoogte 52 (kamerdoos 400 × 316 voxel-px) |
| `vloer`, `loop` | `tegel`, 1.25 |
| `deuren` | `[{ naar: 'keuken', wand: 'z', at: 62, breed: 12 }]` → `deurPunten[0] = { x: 68, z: 0, ix: 68, iz: 8 }` |
| keuken-kant | keuken `deuren` kreeg `{ naar: 'wasserij', wand: 'x', at: 30, breed: 12 }` → `{ x: 0, z: 36, ix: 8, iz: 36 }` |
| `decor` | `kast` op (28, 6) = wasrek tegen de achterwand; `tobbe` op (80, 74) = wastobbe (géén `mand`: het hotel hangt aan elke `mand` de speelmand-knop) |
| `slots` | leeg; dwaalplekken 16 stuks (`Rooms.plekken('wasserij')`), 36 vrije vakjes |
| kaart / rust | KAART `[3, 3]` (onder de keuken); RUST voerkar `Rooms.plek('wasserij', 0.45, 0.6)` = (45, 54) |

Vrije wand voor de kratten van G4: de achterwand rechts van de kast (x 44..60 en 76..100, z 0..10) en de linkerwand (x 0..10, z 12..88). De berg wasgoed past midden op de vloer (bijv. `Rooms.plek('wasserij', 0.5, 0.45)`).

## 3. Tuin: doorgang en zones (`Rooms.get('tuin')`)

- `deuren` kreeg `{ naar: 'zwembad', wand: 'z', at: 38, breed: 12, poort: 1 }` → `deurPunten[1] = { x: 44, z: 0, ix: 44, iz: 8, poort: true }`. `poort: 1` betekent: geen deurgat in een wand (de tuin heeft geen wanden); `bouwTuin` laat het hekpaaltje op x = 38 weg, zodat het achterhek (z = 10) een gat heeft van x 36 tot 52. Er is nog geen gedraaid poortje-model (`poortz`): dat kan straks via `Rooms.registerModel` (ticket P1b). De deur-hotspot "Zwembad" hangt op (44, 0).
- `zones` (alleen data; de spellen zetten er zelf hun stenen en hun kraam neer):

| zone | rechthoek | bedoeld voor |
|---|---|---|
| `zones.hinkel` | `{ x0: 24, x1: 100, z0: 34, z1: 50 }` — 76 × 16 | G3: strook langs de achterrand, vlak vóór het hok; 11+ stapstenen langs x (steek ≈ 7), de trap bij x1 |
| `zones.kraam` | `{ x0: 104, x1: 126, z0: 36, z1: 68 }` — 22 × 32 | G5: langs de rechterzijrand; kraam met de lange kant langs z (≈ 10 × 30) en een gast ervoor (x ≈ 108) |

Beide zones liggen binnen het hek, in het vaste tuinkader (`x - z` in −85..95 en `x + z` ≤ 220), los van elkaar (4 voxels tussen hinkel.x1 en kraam.x0) en vrij van de voetafdruk van het tuindecor en van beide doorgangen (marge 8). `bouwTuin` zet er geen grasplukjes in (marge 4). De p1a-suite toetst dit uit de voxels van de modellen zelf, dus een verschoven decorstuk valt meteen op.

De voetafdrukken hieronder komen uit de voxels van `Rooms.model(n)` zelf (nagemeten voor S3; de eerdere regel was er bij hok, boom en bal één tot twee voxels naast):

| stuk | anker | voetafdruk in kamervoxels |
|---|---|---|
| `hok` | (67, 19) | x 55..78, z 8..29 |
| `kist` | (95, 23) | x 90..100, z 18..28 |
| `boom` | (16, 68) | x 1..29, z 56..80 |
| `bal` | (120, 76) | x 117..123, z 73..79 |
| `tobbe` | (32, 94) | x 27..37, z 89..99 |
| `poort` | (10, 40) | x 9..11, z 31..49 |

De opmerking in `rooms.js` bij `zones` noemt afgeronde rechthoeken (kist `89..101 / 17..29`, hok `56..78 / 9..31`). Die zijn bedoeld als "hier moet je vandaan blijven" en wijken een voxel of twee af van de meting; ze zijn geen tweede bron. Wie precies wil weten wat een stuk beslaat, neemt de tabel hierboven of meet opnieuw met `Rooms.model(n)`.

## 4. Kaart en rustplekken

- `hotel.js` KAART: `wasserij: [3, 3]`, `zwembad: [4, 3]` (kolom, rij in het raster van 4 kolommen; rij 3 was nog leeg behalve kamer 2).
- `world.js` RUST.kar: zie de tabellen. `World.dingZet('kar', { kamer: 'zwembad' })` zet de kar op (72, 70), op het dek vóór het water.

## 5. Wat P1a niet doet (en wie wel)

- Geen modellen (badrand, vlag, meterstrepen, stapstenen, trap, kraam, kratten): P1b (`Rooms.registerModel`) en de spellen.
- Geen wens 🏊/🎁, geen `plekVanBehoefte`: P1d leest `Rooms.get('zwembad').dek.start` (dáár wacht de gast) en `Rooms.get('tuin').zones.kraam`; `bad` is voor het spel zelf.
- Geen zwem- of springanimatie: P1c.
- De opslag (state.js) kent geen kamerlijst; `kamerNu: 'zwembad'` overleeft een herlaad zoals elke andere kamer.

## 6. Test

`.fanout/scratch/dierenhotel/p1a.js` (portret 420×860 en liggend 860×420, 103 assertions): bereikbaarheid (Rooms.pad, chips, plattegrond), bad-maten, dwaalraster buiten het water incl. de rechte-lijn-toets, de twee `dek`-plekken (heel op de vloer, ≥ 8 voxels van het water, geen rechte lijn naar een dwaalplek/deur/dek door het water, plus twee echte dwaalproeven), de zichtbaarheid van de badrand (steenrand lichter dan de tegels, waterrand donkerder dan het middenwater), tuinzones (los, binnen, vrij van decor/pollen/hek/deuren, hekgat), kaderkeuring van beide kamers (k1-controles), rustplek van de kar, geen console-fouten. Schermafdrukken `p1a-zwembad-*.png`, `p1a-wasserij-*.png`, `p1a-tuin-zones-420x860.png` (zones als doorschijnende laag door de test getekend). `DH_SRC` en `DH_OUT` kiezen de bron en de map voor de afdrukken.

Let op voor de merge: `loop.js` (hoofdboom) telt hard 6 ruimtes / 7 chips (regels 102–103); met deze twee ruimtes wordt dat 8 / 9.
