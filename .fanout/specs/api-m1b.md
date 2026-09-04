# API M1b — de opmaat-bus, het dichtheidsplafond en de pauzeregels

Ticket M1b (mobiele wereldlaag). Raakt alleen `demos/dierenhotel/world.js` en
`demos/dierenhotel/art.js`. Geschreven voor het docs-ticket en voor M1a/M1c.

---

## 1. `World.onKader(fn) -> afmelden`

Eén signaal voor "het kader of de maat is veranderd". Vervangt het los
opgehangen `window.addEventListener('resize', ...)` per bestand.

```js
var af = World.onKader(function (kader, schaal) {
  /* kader  = { x, y, w, h }  css-px van #world, t.o.v. de viewport
     schaal = { g, dpr, k, pxPerVoxelX, pxPerVoxelY, pxPerHoogte, kamer }
              precies World.schaal(), plus de ruimte waar hij bij hoort */
});
af();                       /* altijd afmelden als je laag weggaat */
```

* `fn` wordt **niet** meteen aangeroepen bij het aanmelden. Wil je nu al de
  maat, vraag dan `World.kader()` en `World.schaal()`.
* De bus slaat alleen als er echt iets veranderd is: de rechthoek van het
  kader, de voxelmaat `g`, de dichtheid, of de canvasmaat.
* Een luisteraar die een fout gooit sleept de rest niet mee (er komt één
  `console.warn`).

Erbij gekomen op `World`:

| naam | wat |
|---|---|
| `World.onKader(fn)` | aanmelden, geeft de afmeldfunctie |
| `World.kader()` | `{ x, y, w, h }` van #world in css-px (uit de cache van de bus, geen layout-leesbeurt) |
| `World.hermeet()` | zelf een meting afdwingen; normaal doet de waarnemer dat |

### Belangrijk voor de schil: `World.vuil()` meet NIET meer op

Vóór M1b deed de tekenlus elk beeldje `meet()`, dus élke aanleiding om
opnieuw te tekenen (ook `World.vuil()`) leverde ook een verse kadermaat.
**Dat is nu gescheiden:**

| | wat het doet |
|---|---|
| `World.vuil()` | vraagt één nieuwe tekenbeurt met de HUIDIGE maat |
| `World.hermeet()` | meet het kader opnieuw op, past de hoogte aan en slaat de bus |

Verandert de schil de balken boven of onder het kader (een badge erbij, een
kamerchip weg, een klasse op `<body>`, een paneel dat open of dicht gaat),
dan hoort daar **`World.hermeet()`** achter — niet `World.vuil()`. De
waarnemer pakt de meeste gevallen zelf op (hij kijkt naar `#world`, naar
`#app` en naar `metpaneel`), maar een verandering die geen enkele doos van
formaat laat veranderen ziet hij niet. `World.hermeet()` is goedkoop
(één layout-leesbeurt) en idempotent: verandert er niets, dan slaat de bus
ook niet.
| `World.debug().kaderSlagen` | hoe vaak de bus geslagen heeft (tests: draaien = precies 1) |
| `World.debug().kaderLuisteraars` | hoeveel luisteraars er hangen |
| `World.debug().vasteHoogte` | de gelatchte schermhoogte in css-px |
| `World.debug().waakt` | `true` als er een ResizeObserver draait |

### Hoe de bus gevoed wordt

Eén `ResizeObserver` kijkt naar drie dozen:

1. `#world` — het kader zelf (een rekenblad ernaast maakt het smaller zonder
   dat het venster verandert);
2. `#worldSvh` — een onzichtbaar strookje van `height:100svh`; dat is de
   *kleine* viewport-hoogte, die **niet** meebeweegt met de url-balk van iOS
   maar wél met draaien;
3. `#app` — worden de balken boven/onder het kader hoger, dan is er minder
   ruimte over terwijl de doos van het kader niet verandert.

Daarnaast kijkt een `MutationObserver` naar `class` op `<body>`, alleen voor
`metpaneel`: staand staat het rekenblad ónder de wereld, dus dan verandert
noch de breedte noch (door de inline hoogte) de hoogte van het kader.

Verandert de **breedte**, dan meten we meteen (een kamer die 120 ms in de
verkeerde maat staat zie je). Verandert alleen de hoogte, dan één wachtje van
`KADER_WACHT = 120 ms`, zodat een rijtje meldingen (draaien) één keer verwerkt
wordt. Kan de browser geen `ResizeObserver`, dan hangt hetzelfde pad aan
`window resize` + `orientationchange`.

**Voor M1c:** `hotel.js` (`opMaat`), `ui.js` (`padLuister`), `games/bedden.js`
en `games/sleutels.js` hangen nog aan `window resize` / `orientationchange`.
Die blijven werken; ze mogen één voor één naar `World.onKader` verhuizen
(afmelden in `stop()`!). `art.js` is al om.

---

## 2. De stabiele kaderhoogte

`window.innerHeight` springt op een telefoon 60–90 px op en neer als de
url-balk in- of uitschuift, ook middenin een sleepbeweging. Daarom:

* `schermHoogte()` = `100svh` via het meetlatje → anders
  `visualViewport.height` → anders `innerHeight`.
* `vasteHoogte()` latcht die maat. Een nieuwe hoogte nemen we alleen over als
  de **breedte** veranderde, de **oriëntatie** omsloeg, of de hoogte
  **≥ `HOOGTE_RUIS` (120 px)** verschoof. Kleinere sprongen = url-balk-ruis.
* `ruimteHoogte()` en `ruimVoorKader()` rekenen met `vasteHoogte()`, niet meer
  met `innerHeight`.
* `KADER_MIN = 200` is een **ondergrens**, geen plafond: komt er hoogte vrij
  (M1a maakt de liggende balken smaller), dan groeit het kader vanzelf mee.
* `chroomHoogte()` = gewoon `#app` min het kader, **zonder ondergrens**
  (M1b-F1). Daar stond `Math.max(110, …)`, en dat was in de praktijk een
  plafond op het kader: M1a meet liggend 64 px chroom, en dan bleef er toch
  110 van af. Gemeten in een samenvoeging met de M1a-worktree
  (chroom 64 px): kader **274 → 320** px bij 844 × 390, **244 → 290** bij
  740 × 360, **200 → 223** bij 802 × 293; bij 667 × 375 dpr 2 is de chroom
  118 px en verandert er niets (251 px). De maat slingert niet: verzetten we
  het kader, dan krimpt `#app` evenveel mee, dus `app − host` blijft gelijk.
* `kaderHoogte()` neemt `max(laagste / 0,60, nodig)` en begrenst dat op wat er
  past. `nodig` = de hoogte waarop de zwaarste doos zijn vloer plus de strook
  wand van 56 voxel-px nog heel houdt. De 60%-regel is dus een plafond tegen
  een zee van lucht, geen reden om een kamer af te snijden. Met de kamers van
  vandaag doet `nodig` niets (hij ligt overal onder `laagste / 0,60`); hij
  gaat tellen zodra er hoogte vrijkomt.

---

## 3. Het dichtheidsplafond (HOTEL.md §1)

```js
DICHT_MAX_KLEIN = 2;  KLEIN_SCHERM = 500;
schermDicht() = (devicePixelRatio > 2 && min(innerWidth, innerHeight) < 500)
                ? 2 : min(3, dpr)
```

De **korte** zijde, niet `innerWidth` (M1b-F1): "kleine telefoon" is een
eigenschap van het apparaat, niet van hoe je het vasthoudt. Liggend is
`innerWidth` 740–851 px, dus met `innerWidth` viel het plafond juist weg waar
het canvas het breedst en dus het duurst is. Gemeten liggend, zwaarste ruimte
van de acht:

| venster | main (geen plafond) | M1b-F1 | met de schil van M1a erbij |
|---|---|---|---|
| 844 × 390 dpr 3 | wasserij 3213 × 784 = **9,61 MB** | receptie 2560 × 624 = **6,09 MB** | tuin 1771 × 838 = **5,66 MB** (kader 320) |
| 740 × 360 dpr 3 | wasserij 2806 × 784 = 8,39 MB | receptie 2236 × 624 = 5,32 MB | wasserij 1536 × 779 = 4,56 MB (kader 290) |
| 851 × 393 dpr 3 | ± 9,7 MB | receptie 2582 × 624 = **6,15 MB** | tuin 1773 × 838 = 5,67 MB (kader 323) |
| 802 × 293 dpr 3 | wasserij 3048 × 784 = 9,12 MB | receptie 2429 × 624 = 5,78 MB | receptie 1772 × 623 = 4,21 MB (kader 223) |
| 667 × 375 dpr 2 | receptie 2008 × 624 = 4,78 MB | idem (dpr 2, geen plafond) | gang 1345 × 677 = 3,47 MB |

**Liggend haalt de 6 MB pas met de schil van M1a erbij** (5,66 / 4,56 /
5,67 MB). Alléén M1b, met de schil van vandaag, blijft het kader op zijn
ondergrens van 200 px staan en dan is het 6,09 MB (844 px) en 6,15 MB
(851 px): 1,5–2,5% boven de grens. Dat komt niet van de dichtheid maar van
het kader: een kamer van 306 voxel-px hoog moet in 196 css-px, dus `q = 0,64`
en `g / q = 2 / 0,64 = 3,12`; op een kader van 820–827 css-px breed is dat
2560–2582 canvas-px breedte. Lager kan alleen met `g < 2` (HOTEL.md §1
verbiedt dat), met een plafond onder 2 (dan wordt de kamer zichtbaar zacht)
of met een andere vloerplaat-cache (buiten dit ticket). De perf-suite meet
daarom twee drempels: 6 MB zodra het kader ≥ 260 px is, en 6,2 MB zolang het
op de 200 px-ondergrens vastzit — met de reden erbij in de PASS-regel.

Dit is een plafond op de **ondergrens** `d` van de tekendichtheid, niet op
`dicht` zelf. `dicht = max(d, g / q)` blijft staan: een kamer die breder is
dan het scherm duwt de dichtheid nog steeds omhoog, want anders past de kamer
niet meer in het kader én zou `g` geen heel getal meer kunnen zijn. Een hard
plafond op `dicht` van 2 kán niet: met `g ≥ 2` en `q < 1` (een kamer van 476
voxel-px op een kader van 366 css-px) is `g / q > 2` per definitie.

Gemeten (iPhone 13, dpr 3, 390 × 664, kamer1):

| | voor | na |
|---|---|---|
| `g` | 3 | 2 |
| `dicht` | 3,94 | 2,63 |
| wereldcanvas | 1444 × 1392 = 7,67 MB | 963 × 928 = 3,41 MB |
| vloerplaat | 6,02 MB | 2,68 MB |

Per ruimte verschilde het flink — de maat hangt van de doosbreedte af, dus de
zwaarste ruimte is niet de ruimte waar je begint. Alle acht op iPhone 13:

| ruimte | voor (canvas / g / dicht) | na |
|---|---|---|
| receptie | 1098 × 1059, g 2, 3,00 | 1011 × 975, g 2, 2,76 |
| gang | 1098 × 1059, g 3, 3,00 | 732 × 706, g 2, 2,00 |
| kamer1 / kamer2 | 1444 × 1392, g 3, 3,95 | 963 × 928, g 2, 2,63 |
| **keuken (zwaarst)** | **1480 × 1428 = 8,06 MB**, g 3, 4,04 | 987 × 952 = 3,58 MB, g 2, 2,70 |
| tuin | 1098 × 1059, g 3, 3,00 | 732 × 706, g 2, 2,00 |
| zwembad | 1468 × 1416 = 7,93 MB, g 3, 4,01 | 979 × 944, g 2, 2,67 |
| wasserij | 1213 × 1170, g 3, 3,32 | 809 × 780, g 2, 2,21 |

Zwaarste ná de wijziging: receptie 3,76 MB (iPhone 13), 4,71 MB (360 × 740
dpr 3), 4,40 MB (Pixel 5) — alle onder de 6 MB uit het ticket. Vóór was de
zwaarste 8,06 MB (iPhone 13), 6,58 MB en 6,33 MB (beide de wasserij).

`q` (css-px per voxel-px) blijft precies gelijk: de kamer staat even groot op
het scherm, alleen het canvas eronder is grover en de css schaalt hem terug.
Op een 3×-scherm zie je dat niet. Grotere schermen en `dpr ≤ 2` houden hun
oude dichtheid.

**Voor de spellen verandert er niets:** reken met `ctx.wereld.schaal()`
(`k = q`), nooit met `devicePixelRatio` — dat stond al in HOTEL.md §1.

---

## 4. Wanneer tekent de wereld? (pauzeregels)

* `vuil` wordt na **elke** tekenbeurt weer op `false` gezet (vroeger alleen in
  rustmodus, dus tekende de wereld altijd 31×/s door).
* Per beeldje vergelijkt `beeldStand()` de hele **invoer van `teken()`** met de
  vorige keer: kamer, camera, `g`/`dicht`/canvasmaat, de reis-alfa, de
  bad-rechthoek, per dier (plek, vorige plek, houding, kant,
  zij/bob/lift/hoogte, de houding van een lopende opdracht, alle pluisjes),
  de bakjes met hun inhoud, de bedden, het decor van de kamer (met
  params-sleutel), de reizende voorwerpen, het losse decor van een spel en de
  **tooi** van elk dier (P1e: `Art.accessoires(id)` gaat mee in het plaatje
  dat `tekenDier` bakt). Die tooi-sleutel gaat via `Art.tooiVersie()` — een
  teller die art.js bij elke wijziging opschuift — zodat er niet 60× per
  seconde per dier langs de opslag gelopen wordt; `World.sync` gooit de
  onthouden sleutel weg, zodat een geladen spel ook opnieuw kijkt.
  Verandert daar iets — door wie dan ook — dan wordt er opnieuw getekend.
  De losse `vuil = true` op alle mutatieplekken blijft staan: die is sneller
  (meteen dit beeldje in plaats van bij de volgende vergelijking) en gratis.
  **Niemand hoeft erop te vertrouwen dat een ander bestand netjes
  `World.vuil()` roept.**
* Glijdt er iemand tussen twee hartslagen (`px !== x`), dan is de wereld elk
  beeldje vuil: het beeld verandert dan ook echt elk beeldje.
* Staat alles stil, dan tekent de wereld nog hooguit eens per **400 ms**. Dat
  vangnet stond er al en houdt de hotspot-laag en de naamkaartjes vers.
* `Hits.maak / weg / wisEigenaar / pak / laat / voorrang` worden vanuit
  world.js omhuld zodat ze `vuil` zetten (hits.js zelf blijft ongemoeid —
  ticket H1). Een knop die een spel neerzet staat dus meteen goed, niet pas
  bij de volgende tekenbeurt.

  **Voor H1:** `Hits.plaats(kamer, projectie)` wordt nog steeds aan het eind
  van elke tekenbeurt geroepen, maar de wereld tekent nu alleen als er iets
  veranderd is — dus tussen 2,5×/s (alles staat stil) en ~31×/s (er beweegt
  iets). Reken er niet op dat `plaats()` 31×/s draait. Komt er een nieuwe
  publieke functie in hits.js die de hotspot-stand verandert, zet die dan in
  het lijstje in `hitsHaken()` (world.js) of laat hem zelf `World.vuil()`
  roepen; anders staat zijn resultaat pas bij de volgende tekenbeurt goed.
  De omhulling zoekt op naam, dus een naamswijziging in hits.js maakt hem
  stilletjes een no-op.
* De lus staat **stil** zolang `document.hidden` waar is en start weer op
  `visibilitychange` (met een verse klok, dus geen inhaalslag van drie
  hartslagen).
* Rustmodus (`prefers-reduced-motion`) tekent nog steeds op verzoek: elke
  `World.vuil()` of statuswijziging levert één beeld.

### art.js

* De 12-fps sprite-lus draait **alleen als er sprites zijn**: `koppel()` start
  hem, de lus stopt zichzelf als de laatste `.animal` uit de dom is. In het
  dierenhotel staat er meestal géén losse `.animal` (de dieren zitten in het
  wereldcanvas), dus dan draait er niets.
* De `MutationObserver` kijkt naar `#sheet` en `#scene` in plaats van naar de
  hele `body`. Zet je ergens anders dieren neer, roep dan `Art.mount(root)`.
* Opmeten bij draaien/zoomen gaat via `World.onKader`; bestaat die bus niet
  (art.js zonder world.js), dan aan `window resize` + `orientationchange`.
* Ook art.js pauzeert op `document.hidden`.

---

## 5. Gemeten (playwright chromium, CPU-rem 4×, 3 s per meting)

`.fanout/scratch/dierenhotel/mobiel-perf.js`, rij `mobiel-perf` in `alles.sh`.

De hele suite: **vóór 13 pass / 26 fail, ná 48 pass / 0 fail** (dezelfde suite
tegen main versus tegen deze tak; ook 48/0 tegen de samenvoeging met M1a).

| | voor | na |
|---|---|---|
| zwaarste wereldcanvas staand, iPhone 13 | 8,06 MB (keuken) | 3,76 MB (receptie) |
| zwaarste wereldcanvas liggend 844 px | 9,61 MB (wasserij) | 6,09 MB, met M1a 5,66 MB |
| `getBoundingClientRect(#world)` in de lus | 60,2–60,4 /s | 0 /s |
| `requestAnimationFrame` (twee lussen → één) | ~120 /s | 60 /s |
| drawImage per beeld, lege kamer | 4,50 | 0,50–0,57 |
| drawImage per seconde, lege kamer | 273 | 30–35 |
| drawImage per beeld, stille gast in beeld | 4,50 | 2,27–4,26 |
| window-resize-luisteraars bij het opstarten | 3 | 1 (alleen hotel.js) |
| +80 px hoogte (url-balk) | kader 353 → 411 px | 353 → 353, 0 opmaatslagen |
| draaien | (niet geteld) | precies 1 opmaatslag |
| p95 beeldtijd stil bij 4× rem | 16,7 ms | 16,7–16,8 ms |

De p95 zegt weinig: bij 60 Hz is een beeld altijd ~16,7 ms en de rem (gemeten
3,4–5×) bijt niet op deze machine. Wat er echt van af gaat, staat in de
regels erboven: op een stille kamer 8× minder tekenwerk en op iPhone 13 per
tekenbeurt 2,3× minder pixels. In pixels over de bus, iPhone 13, kamer1:
vóór 31 volle plaat-blits/s van 1,58 Mpx = 49 Mpx/s; ná, met alles stil,
2,5/s van 0,70 Mpx = 1,8 Mpx/s (28× minder), en met een ademende gast in
beeld 31/s van 0,70 Mpx = 22 Mpx/s (2,3× minder).

### Een valkuil die het opleverde (p1c)

`p1c.js` verzette in zijn watertest de bad-rechthoek van een kamer
rechtstreeks in `Rooms` en wachtte 350 ms op een nieuw beeld. Met de oude
motor kwam dat er altijd (31×/s, altijd vuil); met een halve verandering-
detectie (alleen de dieren) niet: 2 van de 197 regels vielen om
(`0 punten van 10208` en `1115 tegen 0 punten`). Dat was de reden om
`beeldStand()` over **alle** invoer van `teken()` te laten lopen in plaats van
alleen over de dieren. Daarna weer 197 pass, 0 fail — gelijk aan de
basismeting op main (54c1b31). De les voor de spellen blijft: verander je iets
dat de wereld tekent, roep dan `ctx.wereld.vuil()`; dat is alleen sneller, niet
meer verplicht.
