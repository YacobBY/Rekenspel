# P1d — wensen 🏊 zwemmen en 🎁 souvenir: wat een spel moet weten

Bron: demos/dierenhotel/state.js (BEHOEFTE) en demos/dierenhotel/hotel.js
(WENSWOORD, plekVanBehoefte, behoefteKlaar, wensAf, wensMogelijk, nieuweWensen,
morgen). Geverifieerd met .fanout/scratch/dierenhotel/p1d.js (port + land).

## 1. Aanmelden: zeg welke wens je inlost (`wens`)

```js
Games.register({ id: 'zwembad', naam: 'Zwembad', kamer: 'zwembad', wens: 'zwemmen',   ... });
Games.register({ id: 'kraam',   naam: 'Kraam',   kamer: 'tuin',    wens: ['souvenir'], ... });
```

- `wens`: een string of een array van wensnamen uit BEHOEFTE. Nieuw zijn
  `zwemmen` (🏊, "wil zwemmen", plek `zwembad`) en `souvenir` (🎁, "wil een
  souvenir", plek `kraam`).
- Het hotel deelt zo'n wens pas uit als er een aangemeld spel is dat hem
  noemt, dat geen plaatshouder is (`stub` niet true) en dat open staat
  (`unlock(N, band)` true of afwezig): `Hotel.wensMogelijk(type)`. Anders
  bestaat de wens niet - geen wolkje, geen wachtende gast, geen taakje dat
  je niet kunt afmaken.
- Oude wensen: `kamer`, `eten`, `spelen` zijn van het hotel zelf (altijd
  mogelijk). `bad` blijft aan het tobbe-spel gebonden zoals vroeger:
  `Hotel.badMogelijk() === Hotel.wensMogelijk('bad')`; een ander spel mag
  ook `wens: 'bad'` opgeven.
- registry.js is niet veranderd: hotel.js loopt `Games.lijst()` af, net als
  voor de taakchips (spelTaken).

## 2. Wanneer krijgt een gast de wens (morgen → nieuweWensen)

- Even dagen zijn van de tobbe (gast 1 krijgt 🛁, ongewijzigd). De nieuwe
  wensen komen op de **oneven dagen**, zodat er nooit twee "uitjes" op één
  dag zijn en 🍪 eten het gewone ochtendwolkje blijft.
- Hooguit **één gast per ochtend zolang N ≤ 4, hooguit twee als N > 4**;
  alleen gasten met een bed; alleen de 🍪 van die gast wordt geruild. 🛏 en
  🛁 worden precies zo vaak uitgedeeld als voorheen (p1d.js telt 30
  ochtenden met en zonder spel: 🍪 + 🏊 = 🍪 van vroeger).
- Volgorde: een teller per oneven dag gaat eerst alle gasten langs met de
  eerste wens, dan met de tweede; met één gast om de andere oneven dag.
  `Hotel.nieuweWensen(badBeurt)` geeft `{ gastId: wens }` terug (testhaak).
- Een gast met 🏊/🎁 eet nog gewoon mee: het bakje vullen (tikBak) zet zoals
  altijd alle gasten in die kamer op `gegeten` + 🧶 spelen. Dat gold al voor
  🛁 en is niet veranderd; wie de wens wil bewaren speelt het spel vóór het
  voeren (zelfde volgorde als bij de tobbe).

## 3. Waar staat de gast (plekVanBehoefte) - met terugval

| wens | als de kamerdata er is | terugval |
|---|---|---|
| 🏊 zwemmen | `Rooms.get('zwembad').bad = {x0,x1,z0,z1}` → `{ kamer:'zwembad', x: x0 − 6, z: (z0+z1)/2 }` (geklemd op 4..w−4, 4..d−4): op het dek, net vóór de startrand. Zwembad zonder `bad` → `Rooms.vrijVak('zwembad', 12, d/2)`. | geen zwembad, óf `Rooms.pad(g.kamer, 'zwembad')` leeg → vrij vakje in de tuin bij (58, 106) |
| 🎁 souvenir | `Rooms.get('tuin').zones.kraam = {x0,x1,z0,z1}` → midden vóór de kant die naar het midden van de tuin kijkt, 8 voxels ervoor (zijrand: x0 − 8 of x1 + 8 op z-midden; achterrand: z0 − 8 of z1 + 8 op x-midden) | geen `zones.kraam` → vrij vakje in de tuin bij (106, 58) |

De gast loopt er zelf heen (`stuurNaarBehoefte` → `World.reis(id, kamer,
{x, z, na:'wacht'})`) en `g.waar` wordt die kamer. Een spel vindt zijn gasten
met `ctx.wereld.dieren(kamerId).filter(g => g.behoefte === 'zwemmen' && !g.blij)`
en zijn plek met `Hotel.plekVanBehoefte(g)` (of `ctx.wereld.dier(id)` voor de
werkelijke positie).

## 4. De wens afronden - de enige aanroep

```js
ctx.wereld.behoefteKlaar(gast.id, 'zwemmen');   // of zonder tweede argument: de huidige wens
```

registry.js stuurt dit door naar `Hotel.wensAf(gastId, wens)`:
`eten` → `g.gegeten = true`; `bad`, `spelen`, `zwemmen`, `souvenir`
(WENS_BLIJ) → `g.blij = true`; `kamer` → alleen een bed lost dat op (geeft
`!!g.bed`). Daarna gaat het wolkje weg (`Hits.weg('wens_' + id)`),
`State.bewaar()` en `Hotel.render()`. Geeft `true`; `false` als de gast niet
bestaat. `behoefteKlaar(g)` in hotel.js is vanaf dan waar (`g.blij`), dus
`wachtIn(kamer)` telt de gast niet meer mee en `g.behoefte` blijft staan
(handig voor je taakchip). Geverifieerd in p1d.js sectie e (via de echte ctx
van een dummy-spel) en f (`Hotel.wensAf(id)` zonder argument).

Een ster geeft dit niet: dat doe je zelf met `ctx.taakKlaar(naam)`.

## 5. Taakchip op het prikbord

Niet automatisch. Een spel zet het zelf in zijn registratie, zoals de tobbe
(SPEL_TAAK in hotel.js):

```js
taak: { icoon: '🏊', prio: 1,
        wanneer: function (s) { return s.gasten.some(function (g) { return g.behoefte === 'zwemmen' && !g.blij; }); },
        tekst:   function (s) { var g = s.gasten.filter(function (q) { return q.behoefte === 'zwemmen'; })[0];
                                return g ? g.naam + ' wil zwemmen' : 'Zwemles'; } }
```

## 6. Het wolkje

"🏊 zwemmen" en "🎁 souvenir" (WENSWOORD): pictogram en woord in hetzelfde
wolkje (HOTEL.md §9), tikdoel ≥ 48 px, titel "<naam> wil zwemmen" /
"<naam> wil een souvenir". Het wolkje wijkt zolang een spel in die kamer
open staat (bestaand gedrag) en komt terug bij `Games.stop()`.

## 7. Testhaakjes (Hotel.*)

`wensMogelijk(type)`, `nieuweWensen(badBeurt)`, `plekVanBehoefte(g)`,
`wensAf(id[, wens])`, `wachtIn(kamerId)`, `badMogelijk()`.
