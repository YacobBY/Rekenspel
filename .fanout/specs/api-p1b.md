# API P1b — modelhook en los decor voor minigames (Dierenhotel)

Branch `worktree-agent-ab743f26f6bfa4d7e` (van af8ab32). Bestanden: `demos/dierenhotel/rooms.js`
(MODEL-regio + export), `demos/dierenhotel/world.js` (`decorPlaat`, painter in `teken`, blok LOS DECOR,
`mik`, `debug`, `api`). Suite: `.fanout/scratch/dierenhotel/p1b.js` (portret 420×860 + liggend 860×420).
Voor de games G1–G5 uit `dierenhotel-golf3-games.md`: klok met draaiende wijzers, kratten die volstromen,
stapstenen met een cijfer, vlag op L meter, kraam met spullen.

## 1. Rooms — eigen voxelmodellen

### `Rooms.registerModel(naam, fn) → boolean`
- `naam`: niet-lege string. Ingebouwde namen (alles in de MODEL-tabel: `bed`, `bedz`, `balie`, `kast`,
  `kar`, `tobbe`, `plant`, …) zijn beschermd: aanmelden geeft `false` en verandert niets.
  Een eigen naam opnieuw aanmelden mag (laatste wint).
- `fn(params)`: wordt aangeroepen zodra het stuk (opnieuw) gebakken wordt, met `params` = het object dat
  de aanroeper meegaf, of `{}` als er niets was. Geeft een voxellijst terug (§2). Houd geen toestand vast:
  zelfde params ⇒ zelfde lijst, want er wordt gecachet op params.
- Geeft `true` bij succes; `false` bij lege naam, niet-functie of beschermde naam.

### `Rooms.heeftModel(naam) → boolean`
`true` voor ingebouwde namen, aangemelde namen en de `polN`-terugval (`pol0`, `pol1`, …: grasplukjes).
Alleen EIGEN sleutels van de tabellen tellen (`hasOwnProperty`), dus namen uit `Object.prototype` zijn
gewoon vrij: `heeftModel('toString')` is `false`, `registerModel('toString', fn)` mag en werkt, en
`decor({model: 'constructor'})` wordt netjes geweigerd (`null` + console.warn) in plaats van elk beeld
te klappen op een functie die geen model is.

### `Rooms.model(naam, params?) → voxels`
- Ingebouwd: `MODEL[naam](params)`; de ingebouwde functies negeren `params`, hun uitvoer is ongewijzigd.
- Aangemeld: `fn(params || {})`.
- Onbekend: `pPol(+naam.slice(3) || 0)`, de stille terugval van vroeger blijft bestaan.

### Vast decor met params (RUIMTES-tabel)
`decor: [{ n: 'klok', x: 60, z: 1, y?: 0, ver?: 1, params?: { uur: 7 } }]` — world.js bakt dat via
`Rooms.model(n, params)` en cachet het in de gedeelde Art-cache op sleutel `h|naam|g|JSON(params)`.
Params van vast decor zijn statisch (wijzig ze niet tijdens het spel; daarvoor is los decor, §3).

## 2. Vorm van een voxellijst
Array van voxels `[x, y, z, kleur, voor?]`, dezelfde vorm als de vaste stukken in rooms.js:
- `x, y, z`: gehele voxelcoördinaten t.o.v. het anker van het stuk. Het anker (0, 0, 0) ligt op de vloer
  in het midden van het stuk; `y` telt omhoog (0 = op de vloer). Op het scherm loopt +x naar
  rechts-onder (langs de x-wand, naar de kijker toe) en +z naar links-onder (langs de z-wand):
  `px = (x − z)·S`, `py = (x + z)·S/2 − y·HG` met S = 2 en HG = 2 tekenpixels (× voxelmaat g).
- `kleur`: `'#RRGGBB'`. art.js belicht per vlak (boven lichter, rechts iets donkerder, links het donkerst)
  door te mengen richting warm ivoor / koel violet: de tint blijft herkenbaar, gebruik dus gewoon één kleur
  per blok.
- `voor` (optioneel): alleen voor dieren-silhouetten in art.js; laat weg.
- Dubbele coördinaten: de laatste wint. Binnenliggende vlakken worden weggelaten (culling), dus massieve
  blokken zijn goedkoop.
- Bouwstenen uit `Art.kit`: `K.bx(v, x, y, z, w, h, d, kleur)` (blok), `K.ell(v, cx, cy, cz, rx, ry, rz,
  kleur, {e, ymin})` (ellipsoïde), `K.punt(v, x, y, z, w, h, d, kleur)`, `K.verf(v, x0, x1, y0, y1, z0, z1,
  kleur)` (herkleuren binnen een gebied). Zie `pBed`, `pKar`, `pPrikbord` in rooms.js als voorbeelden.
- Een lege lijst mag (een stapel van 0 blokjes): leeg plaatje, niets te zien, geen fout.
- Maat: houd een stuk onder ~40 × 40 × 40 voxels; de wanden zijn 54–58 voxels hoog en moeten hoger blijven
  dan wat ervoor staat (rooms.js, MATEN regel 2).

## 3. Los decor (runtime) — World en ctx

### Signaturen
```
World.decor(kamerId, o, door?)        → kopie | null    door weglaten = bevoorrecht (hotel, tests)
World.decorWeg(kamerId, id, door?)    → boolean
World.decorLijst(kamerId?)            → [kopie]          zonder kamer: alle kamers
World.decorWisEigenaar(door)          → aantal weg       door === null: al het hotel-decor
ctx.wereld.decor(kamerId, o)          → kopie | null    door = het spel zelf
ctx.wereld.decorWeg(kamerId, id)      → boolean         alleen eigen stukken
ctx.wereld.decorLijst(kamerId?)       → [kopie]          alle stukken in die kamer, met .door
ctx.wereld.decorWisAlles()            → aantal weg       alle eigen stukken (bv. tussen twee beurten)
```
`o = { id, model, x, z, params?, hoog?, rot?, ver? }`
- `id` (verplicht; string of getal, wordt string): sleutel binnen de kamer. Bestaat het id al in die kamer:
  bijwerken; alles wat je weglaat blijft zoals het was (`model`, `x`, `z`, `params`, `hoog`, `rot`, `ver`).
- `model`: naam die `Rooms.heeftModel` kent; verplicht bij een nieuw stuk. Onbekend ⇒ `null` + console.warn.
- `x, z`: kamervoxels, hetzelfde stelsel als `decor`/`slots` in RUIMTES: de wanden staan op x = 0 en
  z = 0, de vloer is `Rooms.get(k).w × .d` (kamer1 114 × 114, tuin 130 × 130). Breuken mogen. Geen
  clamping: buiten de kamer wordt gewoon buiten de kamer getekend.
- `params`: object voor de modelfunctie. Wordt binnen op referentie bewaard en met `JSON.stringify`
  vergeleken;
  verandert die tekst, dan wordt alléén dit stuk opnieuw gebakken. Sleutelvolgorde telt mee
  (`{a, b}` ≠ `{b, a}`: onnodige maar onschadelijke herbak). `null`/weglaten bij een nieuw stuk = `{}`.
- `hoog` (alias `y`): hoogte in voxels boven de vloer (op de balie: 14, zoals de bel). Verschuift alleen
  het plaatje; in de tekenvolgorde blijft het stuk "op de vloer" (+0,3 diepte, zoals vast decor met y).
- `rot`: 0..3 kwartslagen om de y-as; `rot 1`: [x, y, z] → [z, y, −x] (een stuk dat naar +z kijkt, kijkt
  daarna naar +x). Echte draaiing, geen spiegeling: wijzers blijven met de klok mee draaien. 4 = 0.
- `ver`: altijd achteraan tekenen (wanddecor zoals het prikbord: diepte −1000).
- Teruggave: een kopie `{ id, model, kamer, x, z, hoog, rot, ver, params, door }`, geen levend object.
  `params` is daarin een ONDIEPE kopie (arrays via `slice`): sleutels van de teruggave veranderen
  (`z.params.n = 9`) raakt het stuk niet, dus de herbak-sleutel blijft kloppen. Wil je andere params,
  roep dan `decor()` opnieuw aan. Diepere lagen (`params.lijst[0]`) zijn wél gedeeld: geef geneste
  params mee als verse objecten.
  `null` bij: onbekende kamer, geen id, onbekend model, stuk van een ander spel, kamer vol. Een
  afgewezen aanroep laat niets achter (geen leeg kamerlijstje, geen half stuk).

### Tekenvolgorde (world.js `teken`)
Eén painter voor alles in de kamer, gesorteerd op diepte `d`: vast decor en los decor `x + z`
(+0,3 als er een hoogte is, −1000 als `ver`), losse dingen (voerkar) `x + z + 0,2`, bedden en bakjes
`x + z`, dieren `x + z` (slaper +0,5). Kleinere `d` = verder van de kijker = eerder getekend. Dus:
- een stuk met `x + z` kleiner dan dat van een bed wordt door dat bed afgedekt waar de plaatjes elkaar
  overlappen (het staat erachter); groter ⇒ het staat ervoor en dekt het bed af;
- een dier op (64, 64) dekt een stuk op (58, 58) af en wordt zelf afgedekt door een stuk op (70, 70);
- een slaper in bed1 van kamer1 (30, 27) heeft diepte 57,5: een stuk op (30, 40) staat ervoor, op
  (30, 15) erachter (suite C1–C6).
Gelijke diepte is niet gedefinieerd (Array.sort): zet stukken die elkaar op het scherm raken op
verschillende `x + z`.

### Renderen en cache — kosten per beeld
- Elk los stuk bakt één eigen plaatje (`K.plaat(K.bake(voxels), g)`) en bewaart dat op het stuk
  (`it.plaat`, met de voxelmaat `it.plaatG`). Herbakken gebeurt alleen als `model`, `rot` of de JSON van
  `params` verandert, of als `g` verandert (andere kamer-maat sinds 710003e, draaien van het scherm).
  Het zit NIET in de gedeelde Art-cache (110 slots) en NIET in de vloerplaat: de 4 plaat-slots blijven
  onaangeroerd (suite D1: gelijk na 20 keer bijwerken; `World.debug().platen`).
- Per beeld per stuk: één `lijst.push` (precies wat een meubel ook kost) en één `drawImage`. Geen andere
  allocaties in de lus; JSON/vergelijken gebeurt alleen in `decor()` zelf. Stukken in andere kamers
  worden overgeslagen (`losDecor[kamerId]` per kamer). Ook `volg()` van een mikpunt maakt niets aan
  (zie hieronder), en een stuk dat niet gebakken kan worden krijgt het gedeelde lege plaatje: één
  plaatje per voxelmaat, hoeveel kapotte stukken er ook zijn.
- `decor()`/`decorWeg()` zetten `vuil`, dus ook in rustmodus (prefers-reduced-motion) wordt het volgende
  beeld getekend.
- Los decor zit niet in de opslag (`State.bewaar`, suite H2). Na herladen is het weg: een spel zet het in
  `start()` opnieuw, ook bij het herstellen van een beurt uit `ctx.data()`.

### Eigenaarschap en opruimen
- `door` = de naam van het spel (via ctx automatisch) of `null` (via `World.decor` zonder derde argument:
  het hotel, een test).
- Een spel kan alleen eigen stukken bijwerken/weghalen (anders `null`/`false`); `World.decor` zonder
  eigenaar is bevoorrecht en laat de eigenaar staan (suite G3).
- Stopsignaal, zonder registry.js te wijzigen: registry.js roept bij `Games.start(id)` `Hits.voorrang(id)`
  aan en bij `Games.stop()` `Hits.voorrang(null)`. world.js omhult `Hits.voorrang` één keer bij het laden
  (hits.js staat vóór world.js in index.html; `Hits.voorrang` heeft geen andere aanroepers) en verwijdert
  dan alle stukken waarvan `door` een AANGEMELD spel is dat niet het startende spel is. Gevolg:
  - `Games.start(B)` terwijl A speelt ⇒ A's decor weg vóór `B.start()`; B's decor uit `start()` blijft;
  - `Games.stop()` ⇒ decor van het gestopte spel weg (suite G4, G6);
  - hotel-decor (`door === null`) blijft altijd staan tot `decorWeg` / `decorWisEigenaar(null)` (G5);
  - een spel dat decor zet terwijl het NIET actief is (bij het laden bijvoorbeeld) raakt dat kwijt bij de
    eerstvolgende start of stop van welk spel dan ook — zet decor dus in `start()`.
- TOCH OOK ZELF OPRUIMEN: zet `ctx.wereld.decorWisAlles()` in de `stop()` van je spel. Dat is één regel
  en het kan geen kwaad (het haalt precies je eigen stukken weg, en na de automatische opruiming geeft
  het gewoon 0 terug). De automatische opruiming hangt namelijk aan één aanname: dat de registry de
  enige aanroeper van `Hits.voorrang` is en dat `Hits` er is. Verandert dat, of laadt hits.js niet (dan
  waarschuwt world.js één keer bij het laden), dan blijft het decor van je spel na `stop()` in beeld
  staan. Met die ene regel in `stop()` ben je daar niet van afhankelijk.
- Cijfers en kaartjes: los decor heeft geen eigen hotspot, maar `World.mik(id)` vindt het (ná dieren,
  losse dingen, slots en vast decor — kies dus ids die daar niet mee botsen, niet `bed1`/`bak`/`tobbe`/
  `kar`), met `volg` zodat een getalTag meeschuift. `volg` blijft in de kamer waar het stuk stond toen
  je `mik`te, en maakt niets aan (geen kamerlijstje, geen nieuw antwoord-object per beeld) — Hits roept
  het namelijk voor élke hotspot per beeld aan (20 stapstenen met een cijfer = 20 keer). Het antwoord is
  een vast doosje per mikpunt: uitlezen mag, bewaren niet. Verhuist een stuk naar een andere kamer
  (weghalen + in een andere kamer neerzetten), `mik` dan opnieuw. `ctx.wereld.getalTag('steen3', 30)`,
  `ctx.ui.wolk('klok', …)`, `ctx.ui.somkaart('kraam', …)` werken dus gewoon (suite H1). Die tags zijn van
  het spel en gaan bij `stop()` al weg via `Hits.wisEigenaar`.

### Limieten
- `LOS_MAX = 48` stukken per kamer (20 stapstenen + rand + vlag past ruim); daarboven `null` +
  console.warn (suite F3).
- Ids zijn per kamer uniek; hetzelfde id in twee kamers zijn twee stukken. `World.mik(id)` zonder kamer
  zoekt eerst in de kamer die in beeld is.
- Een modelfunctie die STUKGAAT — hij gooit een fout, óf hij geeft iets terug wat geen voxellijst is
  (`'kapot'`, `null`, een getal, een voxel zonder kleur `[[0, 0, 0]]`, waar `K.bake`/`K.plaat` op
  afknappen) — kost het stuk zijn plaatje en niets meer: er komt een leeg (doorzichtig) plaatje op te
  staan, één `console.warn('decor <id>: model <naam> faalt', e)` PER STUK (niet per beeld, want het lege
  plaatje wordt net zo gecachet als een goed plaatje), en géén paginafout — de rest van het beeld
  (meubels, dieren, `Hits.plaats`) wordt gewoon afgemaakt. Bij nieuwe `params`/`model`/`rot`, of bij een
  andere voxelmaat `g`, wordt het opnieuw geprobeerd (en mag er weer één keer gewaarschuwd worden).
  Suite F2/F5–F10. `null`, `undefined` of een lege lijst is géén rommel maar gewoon "niets te zien"
  (een stapel van nul blokjes): leeg plaatje, geen waarschuwing.
- Geen botsing: dieren lopen dwars door los decor heen (dwaalplekken komen uit `Rooms.plekken`). Zet
  stukken dus op plekken waar de dieren toch niet komen (wandrand, tuinrand), zoals vast decor zonder slot.
- `params` moet JSON-serialiseerbaar zijn (geen functies, geen kringen); anders valt de sleutel terug op
  `String(params)` en wordt er niet meer per wijziging herbakken.

## 4. Voorbeeld: halklok met draaiende wijzers (G2)
```js
Rooms.registerModel('klok', function (p) {
  var K = Art.kit, v = [], i, a;
  K.bx(v, -8, 20, 0, 17, 17, 2, '#FFFDF3');                       /* wijzerplaat aan de z-wand */
  for (i = 1; i <= 12; i++) {
    a = i / 12 * 6.2832;
    K.bx(v, Math.round(7 * Math.sin(a)), 28 + Math.round(7 * Math.cos(a)), 2, 1, 1, 1, '#7E6255');
  }
  var u = (((p.uur || 0) % 12) + (p.min || 0) / 60) / 12 * 6.2832, m = (p.min || 0) / 60 * 6.2832;
  for (i = 1; i <= 4; i++) K.bx(v, Math.round(i * Math.sin(u)), 28 + Math.round(i * Math.cos(u)), 2, 1, 1, 1, '#7E6255');
  for (i = 1; i <= 6; i++) K.bx(v, Math.round(i * Math.sin(m)), 28 + Math.round(i * Math.cos(m)), 2, 1, 1, 1, '#C08F6B');
  return v;
});
/* in start(ctx): */
ctx.wereld.decor('gang', { id: 'klok', model: 'klok', x: 60, z: 1, ver: 1, params: { uur: 5, min: 0 } });
ctx.wereld.getalTag('klok', '5 uur', { y: 34 });
/* bij elke tik op "uur erbij": alleen dit ene plaatje wordt opnieuw gebakken */
ctx.wereld.decor('gang', { id: 'klok', params: { uur: 6, min: 0 } });
/* stop(): niets nodig, de wereld ruimt het decor van het spel zelf op */
```
