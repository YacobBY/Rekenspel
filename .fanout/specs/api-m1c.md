# API M1c — wat een spel op een telefoon moet doen

Ticket M1c (het hotel en de vijf bestaande spellen op een telefoon). Raakt
`demos/dierenhotel/hotel.js`, `econ.js` en `games/{voerkar,bedden,sleutels,
tobbe,meubels}.js`. Niets in `world.js`, `hits.js`, `ui.js`, `style.css`,
`index.html`, `snd.js`, `game.js`, `art.js`, `rooms.js`, `state.js`,
`registry.js` of in de vijf nieuwe spelbestanden.

Hieronder staat wat een spel (of het hotel zelf) moet doen om met een vinger
op een telefoon te werken. Vijf regels, elk met de meting die hem oplevert.

---

## 1. Hang aan de opmaat-bus, niet aan `window`

```js
/* in start() */
maatAf = C.ui.opKader(function () { /* opnieuw neerleggen */ });
/* in stop() */
if (maatAf) { maatAf(); maatAf = null; }
```

`Ui.opKader` (M1a) gebruikt `World.onKader` (M1b) als die er is en valt anders
terug op `resize` + `orientationchange`. Winst: één ontdenderde melding per
echte kaderverandering in plaats van twee (kantelen stuurt ze beide), en de bus
slaat ook als alleen het KADER verandert — een rekenblad ernaast, de
cijferstrook eronder — zonder dat het venster van maat verandert.

Omgezet in M1c: `hotel.js` (`opMaat`), `games/bedden.js` (`opMaat`),
`games/sleutels.js` (`U.luister`). `window`-luisteraars in deze drie
bestanden: **3 → 0** (gemeten met een omhulde `addEventListener`, staand en
liggend; `m1c-lus.js`).

**Bewaar de opzegger BUITEN je scherm-object.** `games/sleutels.js` maakte bij
elke `start()` een nieuwe `U`; met de opzegger daarin bleef een oude
aanmelding hangen zodra er geen `stop()` tussen zat. Hij staat nu op
modulehoogte (`maatAf`), met `if (maatAf) maatAf();` vóór het aanmelden.

### De valkuil: een lus, want jouw hertekening verandert het kader zélf

Een hertekening die een sommenkaart opruimt en opnieuw maakt, zet daarbij het
cijferpad even uit en meteen weer aan. Staat dat pad als **strook onder het
kader** (M1a `padPlek:'auto'` in een kort kader), dan vraagt `ui.js` daarvoor
twee keer `World.hermeet()` — en dat is twee echte kaderveranderingen
(572 × 228 → 572 × 290 → 572 × 228). De bus slaat, `opMaat` gaat af, de kaart
wordt hertekend: **een lus**.

Gemeten op 740 × 360, `hotel.js` zonder slot: **61 kadermeldingen en 61
`World.hermeet()` in 5 seconden** (basismeting met de oude window-luisteraars:
1), en een tik op het cijferpad kwam niet meer aan omdat het kaartje ~5× per
seconde werd vervangen (`mobiel.js`: "vakje leeg", 4 fail op dit profiel).

**Het slot** (`hotel.js` `maatNu()` / `maatWas`): onthoud vóór welk kader je de
knoppen hebt neergelegd en doe niets als dat kader er nog precies zo bij staat.
Vergelijk op het moment dat je wachtje AFGAAT, niet bij de melding: dan vallen
de twee tussenmeldingen van je eigen strook in één wachtje samen en ziet dat
wachtje het kader terug op zijn oude maat. Een echte draai heeft een andere
maat en komt gewoon door.

```js
function maatNu() {
  var k = World.kader && World.kader(), s = World.schaal && World.schaal();
  if (!k) return '';
  return Math.round(k.w) + 'x' + Math.round(k.h) +
         '|' + (s ? s.g + ':' + s.dicht + ':' + (s.kamer || '') : '') +
         '|' + World.actief();
}
```

Na het slot: **3 kadermeldingen** in de eerste 5 s van een check-in en **0** na
het kantelen, op 740 × 360; de tik op het pad komt aan.

Een spel dat géén cijferpad opent (bedden, sleutels, voerkar) heeft dit slot
niet nodig: gemeten 0–2 meldingen per 5 s met het spel open.

## 1b. Ruim je oude kaart zelf op

Maak je een nieuwe `Ui.somkaart` onder dezelfde id (`hotel.js paintCheckin`
doet dat bij elke hertekening van `ci_som`), roep dan eerst `weg()` op de
oude:

```js
if (ciKaart && ciKaart.weg) ciKaart.weg();
Hits.wisEigenaar('checkin');
```

`weg()` zegt de kaderluisteraar op, laat de cijferstrook los en haalt kaart +
pad + keuzestrook weg. Zonder dat hangt het aan de opruimhaak van de
hotspot-laag (H1 `onWeg`) of aan het merkteken van ui.js (M1a) — allebei
vangnetten, geen opdracht.

## 2. Eén tik = één actie: kies `aan` óf `sleep.onTap`, nooit beide

Een hotspot met een eigen sleep had er twee:

| plek | had | heeft |
|---|---|---|
| `games/voerkar.js` `karhot` | `aan: hoeDan` **én** `sleep.onTap: hoeDan` | alleen `aan` |
| `games/tobbe.js` `tb_dier<id>` | `aan: volgendeInBad` **én** `sleep.onTap: volgendeInBad` | alleen `aan` |

Vóór M1a gingen die twee samen af (één tik zette twee dieren in bad). M1a
zette in `makeDraggable` een klik-slikker (`slikEenKlik`) die de klik ná een
tik opeet, dus sinds M1a gaat er precies één af — gemeten met een echte
vinger (CDP touch) én met de muis: **1 aanroep, niet 2** (`m1c-dubbel.js`).
De tweede afhandelaar was dus dood, maar hij liet het enige-keer-zijn van een
tik afhangen van een klik-slikker die op tijd moet zijn. Nu is het
structureel: er is één afhandelaar.

**Regel:** een hotspot met `drop`/sleep laat het tikken aan de hotspot-laag
(`aan`) en geeft `makeDraggable` alleen `onDrop`. `econ.js` deed dit al
(`rek_buidel`: "geen onTap: een tik komt via `tik` binnen, precies één keer").

`Ui.bron(obj, { tik: fn, sleep: { onTap: fn } })` is een aparte, ONSCHULDIGE
dubbeling: `Ui.bron` roept `sleep.onTap` áls die er is en anders `tik`, en
zet er zelf een `__bronTik`-slot bij. Vier plekken doen dat nog
(`games/meubels.js mb_buidel`, `games/sleutels.js sl_key`,
`games/bedden.js bd_kist`, `games/tobbe.js tb_rek`); ze vuren één keer per
tik en zijn met opzet niet aangeraakt. Nieuwe code geeft er één van de twee.

## 3. Tekstbodem: 12 px, ook in je eigen `style="font-size:…"`

`style.css` zet sinds M1a een bodem van 12 px op elk kinderwoord
(`clamp(12px,.75rem,14px)`), maar een `style="font-size:…"` in de html van een
spel gaat daar bovenuit. Rechtgezet in M1c:

| plek | was | is |
|---|---|---|
| `games/voerkar.js:113` (`.zeg` in een krap bakje) | `.72rem` = 11,52 px | `12px` |
| `games/tobbe.js:401` (het getal ín het glaasje) | `.72rem` = 11,52 px | `12px` |
| `games/tobbe.js:404` (het 💦/🫧 naast het glaasje) | `.7rem` = 11,2 px | `12px` |

Alles wat overblijft in de vijf spellen is `.8rem` (12,8 px) of groter.
`mobiel.js` meet dit nu als een **harde regel** in elke stap
("kindertekst van een SPEL is nooit kleiner dan 12 px"); tot M1c was het een
`LET OP`-regel, omdat het bestand dat het moest oplossen buiten M1a viel.

## 4. De sommenkaart laat het dier van de beurt zien

`hotel.js WACHTPLEK` is van `0,25 × 0,925` naar **`0,2 × 0,95`** gegaan (6
voxels verder van de balie, 3 verder naar voren = 9 stappen van `x − z`, dat
is 12–14 px naar links op een telefoon). Waarom: de sommenkaart is 258 px
breed (op een scherm ≤ 360 px krimpt hij naar 170) en de hotspot-laag klemt
hem tegen de RECHTERrand van het kader, dus hij staat op elke staande maat al
zo ver naar rechts als hij kan. Gemeten in het kader, met het doosje van
56 × 52 px waarin het dier onder zijn naamplaatje zit:

| kader | kaart | linkerrand kaart | dier | vrij |
|---|---|---|---|---|
| 386 × 468 (420 × 860) | 258 px | 126 px | 43..99 | 27 px |
| 356 × 431 (390 × 844) | 258 px | 96 px | 38..94 | 2 px |
| **341 × 387 (375 × 667)** | 258 px | 81 px | 35..91 | **−10 px** |
| 326 × 395 (360 × 740) | 170 px | 154 px | 32..88 | 66 px |
| 286 × 304 (320 × 640) | 170 px | 114 px | 25..81 | 33 px |

Op 375 × 667 ging daardoor **15 % van het naamplaatje en 18 % van het dier**
schuil achter de kaart, waar `w1.js` hooguit 10 % toestaat. Optillen helpt
daar niet (de kaart zou 86 px hoger moeten en valt dan uit het kader) en naar
rechts kán de kaart niet meer. Ná de verschuiving: **0 % en 0 %** op
320 × 640, 360 × 740, 375 × 667, 390 × 844, 420 × 860, 667 × 375, 740 × 360,
750 × 342, 844 × 390 en 860 × 420 — staand én liggend, ook na het kantelen en
met een tweede gast aan de balie. Verder naar links kan niet: de z-vleugel van
de balie staat op x 11..19 (`rooms.js` decor `baliez`).

**Wat NIET meetelt.** Een dier dat lóópt of dat SLAAPT. De route van de
gangdeur naar de balie gaat onder de kaart langs: gemeten dekt `ci_som` de
aankomende gast 2,2–5,5 s lang 100 % af, op élke maat (ook staand 420 × 860),
en dat is de looptijd van de gast. Een slaper ligt onder het bedkaartje van
`games/bedden.js` en dat is de bedoeling. `mobiel.js` meet die twee als
`LET OP`-regel mét hun getallen en hangt de harde regel aan het dier waar de
beurt over gaat (de naam gaat mee als `keur(..., { gast: naam })`).

## 5. De kaart mag geen sleepdoel afdekken

`games/bedden.js` legde zijn sommenkaart `marges().boven` px boven rij 0 en
rekende in `maxStroken()` met een kaart van 46 px. Een kaart MET zin is
**92 px** (twee regels) tot **129 px** (drie regels, op een kader < 360 px).
Gevolg op een liggende telefoon: `bd_som` lag 123 × 26 px over `bd_rij0`, en
een sleep van de dekenkist naar het HART van rij 0 kwam **niet** aan —
`elementFromPoint` gaf de kaart, niet de rij. Rij én kaart zijn beide `vast`,
dus de hotspot-laag schuift ze niet voor elkaar weg: alleen het spel kan dit
oplossen.

Wat er nu staat (`bedden.js`):

1. `maxStroken()` reserveert de echte kaarthoogte: kader 200/228/282/**320** →
   3 strookjes, 379/405/478/715 → 4 (was 4 vanaf 282).
2. `marges()` houdt een ondergrens hart-op-hart aan: `MIN_BOVEN = 74`
   (halve kaart + halve knop + 4 px), `MIN_ONDER = 52`. Is er meer ruimte, dan
   mag het ruimer tot de oude 80 / 66 — op een staand kader van 478 px komt
   daar exact 80 / 66 uit, dus portret verandert niet.
3. **Nameten in hooguit drie rondes** (`somVrij`), net zoals `ui.js` dat met
   het cijferpad doet: raakt de kaart de rij, til hem dan precies genoeg op;
   lukt dat niet (boven de rij is geen kader meer), zet hem dan ERNAAST — links
   van rij 0, op dezelfde hoogte, de uitweg die `games/sleutels.js` in X1 al
   kreeg; is ERNAAST slechter (een smal kader klemt de kaart terug tegen de
   linkerrand), ga dan toch weer erboven. De rondeteller staat buiten `teken()`
   en gaat op nul bij een nieuw kader, een nieuwe opdracht of een nieuwe start.

Gemeten (`m1c-bedden.js`, echte vingersleep kist → hart van rij 0):

| venster | kader | `bd_som` × `bd_rij0` vóór | ná | sleep |
|---|---|---|---|---|
| 844 × 390 | 676 × 320 | 123 × 26 | 0 | **MIS → OK** |
| 802 × 293 | 634 × 223 | 123 × 40 | 0 (ernaast) | **MIS → OK** |
| 740 × 360 | 572 × 290 | 123 × 4 | 0 | OK → OK |
| 360 × 740 | 336 × 405 | 123 × 11 | 123 × 11 | OK → OK |
| 860 × 420 / 667 × 375 / 420 × 860 / 375 × 667 / 390 × 844 | | 0 | 0 | OK → OK |
| **320 × 640** | 286 × 304 | 123 × 39 | 123 × 39 | **MIS → MIS** |

320 × 640 blijft staan: daar is de kaart 129 px hoog (drie regels op 170 px
breed) en past hij noch boven de rij (7 px kader over) noch ernaast (286 px
kader tegen 170 + 123 px). Onveranderd t.o.v. de basismeting, dus geen
regressie. Het is alleen op te lossen met een kortere of smallere kaart
(`style.css .hot.hotsom`, of één zin in plaats van twee) en dat valt buiten
M1c.

## 6. Waar staat het cijferpad? Vraag het niet, meet het

Elk pad hangt met `padPlek:'auto'` (de standaard, M1a) ín het kader of als
strook eronder. Een spel of een speeltest vindt de toetsen altijd met
`[data-hot="<kaart>_pad"] [data-pk="7"]`, waar het pad ook staat.

Welke spellen een pad hebben (nagemeten, ticket M1c item 6):

| kaart | pad | wanneer |
|---|---|---|
| `ci_som` (hotel.js) | ja (`open:true`) | check-in, vraag 1 |
| `tb_vraag` (tobbe) | ja | alleen de vraagstap, en die bestaat alleen bij soort `dubbel` of `half` — dus vanaf band 4 (`soorten()`) |
| `mb_som`, `mb_wissel` (meubels) | ja | `mb_som` alleen als je TWEE dingen samen koopt, en dat mag pas vanaf band 4 (`maxLijst()`) |
| `rek_som`, `rek_wissel` (econ.js) | ja | de rekening |
| `bd_som` (bedden), `sl_kaart` (sleutels), `vk_kaart` (voerkar), `tb_som`, `mb_bon`, `rek_bon`, `ci_som` vraag 2 | **nee** (`pad:false`) | die kaarten vullen zichzelf in of hebben een keuzestrook |

Het ticket noemde bedden, sleutels en voerkar als spellen "met een keypad";
dat is er niet. Hun kaart is `pad:false` en telt zichzelf mee. `mobiel.js`
meet dat nu als contract ("bedden: de kaart bd_som telt zichzelf mee, zonder
cijferpad").

Gemeten met een echte tik-reeks op 740 × 360 (kader 572 × 228) en 844 × 390
(kader 676 × 320), plus alle acht telefoonprofielen: pad in de strook zodra
het kader < 300 px of te smal is, 12 toetsen op één rij van 48 px, en het
antwoord komt in het vakje. Uitzondering: op 802 × 293 (pixel5-land) staat het
kader op zijn ondergrens van 200 px terwijl er maar 223 px ruimte is; dan valt
de strook onder de vouw. Dat is `world.js`/M1b, niet het spel, en `mobiel.js`
print het als `LET OP` met de ruimte erbij.

## 7. Sleep-doelen: mik op de KNOP, niet op het vangvlak

H1 legt naast elke `drop`-knop een doorzichtig **vangvlak** met dezelfde
`data-drop` in `div.vanglaag` (z-index 2 tegen 3 voor de knoppen). Dat vlak is
groot en zijn middelpunt kan onder een ándere knop liggen. Gemeten op
740 × 360: het vangvlak van de toonbank is 172 × 126 px met zijn hart op
(265, 126), en daar staat de bel (z-index 21) — een sleep naar dát punt komt
dus niet aan, precies zoals H1 het bedoelt ("een echte knop pakt altijd
voor"). Een sleep naar `[data-hot="rek_bank"]` komt wél aan (€0 → €1).

Voor een testsuite: zoek een sleepdoel als `#worldHits [data-drop="..."]`.
Voor een spel: geen actie nodig, dit is alleen de meetkant.

## 8. De rekening met vier gasten (item 5 van het ticket)

`P1e` meldde dat de muntbuidel op 860 × 420 met 4 gasten niet aan te tikken
was. Nagemeten op alle acht profielen, in de eigen stand ÉN gekanteld, met
vier gasten in de receptie: de buidel is **84 × 48 px** (boven de 48 px-regel),
ligt vrij, en een echte vingersleep buidel → toonbank levert af (`€0 → €1`).
De som ervoor (`rek_som`) gaat met het cijferpad in de strook. Geen enkel
profiel faalt hierop; de oude klacht is met M1a (tikmaten, vingerlift) + M1b
(kader 200 → 290/320 px) verdwenen.

## 9. Suite

`.fanout/scratch/dierenhotel/mobiel.js` (acht telefoonprofielen, echte tik- en
sleepgebeurtenissen). M1c heeft er stap 10b bij: **één rondje per spel met
echte gebaren** — voerkar (zak → bakje + de correctie-chips), tobbe (rek →
tobbe + cijferpad), sleutels (sleutel → haakje), bedden (kist → rij), meubels
(twee dingen kopen → cijferpad → munt → toonbank → doos → vakje) en de
rekening (cijferpad → munt → toonbank, in beide standen, met 4 gasten). Per
stap dezelfde ronde als de rest van de suite: tikmaten ≥ 48 px (44 onder
360 px), geen overlappende tikdoelen, geen tekst onder 12 px, geen sommenkaart
over het dier van de beurt, niets afgesneden, geen console-fout — plus de
vraag die alleen dát spel kan antwoorden: is de stand écht veranderd?

Uitslag na M1c, acht profielen, echte tik- en sleepgebeurtenissen:

| profiel | venster | pass | fail | sec |
|---|---|---|---|---|
| iphone13 | 390 × 844 dpr 3 | 363 | 0 | 70 |
| iphone13-land | 844 × 390 dpr 3 | 344 | 0 | 71 |
| pixel5 | 393 × 851 dpr 3 | 362 | 0 | 70 |
| pixel5-land | 802 × 293 dpr 3 | 334 | 0 | 71 |
| 375 × 667 | dpr 2 | 363 | 0 | 70 |
| 667 × 375 | dpr 2 | 344 | 0 | 70 |
| 360 × 740 | dpr 3 | 363 | 0 | 70 |
| 740 × 360 | dpr 3 | 344 | 0 | 72 |

Samen **2917 pass, 0 fail**; de langste rij is 72 s, ruim binnen de 240 s die
`alles.sh` per suite geeft.

De ontwikkelprobes van M1c staan in de scratch van de M1c-worktree
(`.claude/worktrees/agent-a5a4fb17660307f6d/.fanout/scratch/dierenhotel/`),
niet in de hoofdboom — het ticket liet alleen `mobiel.js` en de
schermafdrukken daarheen schrijven:
`m1c-lus.js` (kadermeldingen en window-luisteraars per spel),
`m1c-dubbel.js` (één tik = één keer),
`m1c-bedden.js` (kaart over de rij, echte sleep naar het hart van rij 0),
`m1c-munt.js` (waarom een sleep niet aankomt),
`m1c-bus.js` (de lus in beeld),
`m1c-probe.js` / `m1c-draai.js` / `m1c-375.js` / `m1c-bel.js` (dekking van de
gast, ook na het kantelen en met een tweede gast).
