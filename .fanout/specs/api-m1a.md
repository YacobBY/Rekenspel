# API M1a — de mobiele schil: `padPlek`, `Ui.opKader`, de geluidsband en de css-haken

Geleverd door ticket M1a (mobiele schil, golf M). Aangeraakt: `demos/dierenhotel/style.css`, `index.html`, `ui.js`, `snd.js`, `game.js`. Niets in `world.js`, `hits.js`, `art.js`, `hotel.js`, `econ.js`, `rooms.js`, `state.js` of in een spelbestand. Alle namen hieronder zijn nieuw of gewijzigd; alles is achterwaarts compatibel, dus **geen enkel bestaand spel hoeft iets te veranderen**.

## 1. `Ui.somkaart(obj, som, { padPlek })` — waar het cijferpad staat

| waarde | betekenis |
|---|---|
| `'auto'` | **standaard.** Het pad staat ín het kader, behalve als het kader te laag of te smal is; dan komt het als strook ONDER het kader (zie de regel hieronder). |
| `'binnen'` | altijd ín het kader, aan de sommenkaart (het gedrag van vóór M1a). |
| `'buiten'` | altijd als strook onder het kader. |

**De 'auto'-regel.** Buiten zodra één van deze twee waar is, gemeten op `#world` (`clientWidth`/`clientHeight`, dus het binnenwerk zonder de rand van 5 px):

* **te laag:** kaderhoogte `< 300` px (en pas weer naar binnen boven **340** px, zie de dode zone hieronder). Gemeten vóór M1a op een liggende telefoon (844 × 390): kader 820 × 200, pad 638 × 66 middenin het kader, met vier botsingen (`ci_som` × `ci_som_pad` 278 × 42, `deur_receptie_gang` × pad 48 × 41, en de kaart over de deur en het prikbord).
* **te smal:** `clientWidth <` de breedte van één rij van zes toetsen: **286** px onder 360 px scherm (toetsen 44 px, kier 2 px), **310** px op 360 px zelf (toetsen 48 px, kier 2 px), **326** px daarboven (toetsen 48 px, kier 4 px). Gemeten: kader met 259 px binnenwerk, pad 286 px → 24 px stak zijwaarts uit het kader. De breedte hangt niet aan de strook, dus die kant heeft geen dode zone nodig.

**Waarom er een dode zone en een wisselrem zijn (geen lus).** `#padstrip` staat ín de pagina, ónder het kader: zichtbaar worden kost hoogte, dus het kader krimpt. Dat is zelf een kaderverandering, en met `World.onKader` (M1b: `ResizeObserver` op `#world`) komt die melding terug bij de kaart. Zonder rem tikt dat door — nagemeten met een echte `ResizeObserver` (120 ms ontdenderen): **44 wissels in 5 s** op 750 × 342, kader flipperend tussen 216 en 200 px, met tussenstanden zónder cijferpad. Drie sloten, samen:

1. **strookvrij meten.** De beslissing gebruikt `kaderHoogVrij()` = `#world.clientHeight` **plus** de hoogte die onze eigen strook nu inneemt (+ 4 px kier). Die maat verandert dus niet door onze eigen strook.
2. **dode zone 300 / 340 px.** Naar buiten onder 300, terug naar binnen pas boven 340. De optelling in stap 1 overschat het kader een beetje (bij 844 × 390: 258 + 66 = 324 waar het kader zonder strook 274 px is); die 40 px lucht vangt dat op.
3. **eigen melding negeren + wisselrem.** Na een eigen wissel is de kaart 400 ms stil (`VERSTIL_MS`) en kijkt daarna één keer opnieuw, zodat een echte draai binnen dat venster niet verdwijnt. Per schermmaat mag het pad hooguit **2 keer** in of uit het kader springen (`WISSEL_MAX`); daarna blijft het staan waar het staat, en bij twijfel is dat "buiten" — daar botst het pad met niets. De teller loopt per `innerWidth×innerHeight` en gaat op nul bij een echte maatverandering. Van vorm veranderen (zes toetsen of twaalf) mag altijd: dat kost geen hoogte.

Gemeten na de rem, met dezelfde nep-`World.onKader`: **0 wissels** in 5 s op 750 × 342 (kader 210, strook aan) en op 844 × 390 (kader 258), 100 van de 100 steekproeven met een volledig pad van twaalf toetsen. `mobiel.js` doet die proef zelf (stap 11).

**Met M1b erbij.** M1b-F1 tilt de chroom-bodem van world.js op; het kader wordt dan ongeveer 320 px op 844 × 390 en 290 px op 740 × 360. De drempels hierboven geven daar precies wat de bedoeling is: 320 ≥ 300 → pad **binnen** op 844 × 390; 290 < 300 → **strook** op 740 × 360, en met de strook erbij leest de meting 224 + 66 = 290 px, dus onder de 340 → hij blijft buiten (geen gewiebel).

**Eén strook, laatste kaart wint.** Er is één `#padstrip` in de pagina. Openen twee sommenkaarten tegelijk hun pad met `padPlek` op buiten, dan neemt de laatste de strook over: hij zet zijn eigen merkteken (`__eig`) en zijn eigen toetsafhandelaar (`__aan`), en de eerste kaart ruimt de strook niet meer op (`strookVanMij()` kijkt naar dat merkteken). De eerste kaart houdt dan een open pad zónder toetsen; dat is voor het fundament geen probleem (het hotel heeft nooit twee open cijferpads tegelijk, en een spel dat dat wel wil zet `padPlek:'binnen'` op één van de twee). Wil een spel echt twee stroken, dan is de goedkoopste uitbreiding: per kaart een eigen `<div class="padstrip">` in dezelfde kolom in plaats van één vaste `#padstrip`.

**Het handvat blijft hetzelfde.** `.regel() .som() .zet() .hulp() .open() .klaar() .weg()` doen precies wat ze deden; `klaar()` en `weg()` ruimen de strook mee op.

**De strook.** Eén `<div class="padstrip" id="padstrip">` in `index.html`, in `.stagecol` direct ónder `#world` en boven de kamerbalk. Leeg = `hidden`. Zolang een kaart hem gebruikt draagt hij **`data-hot="<kaart-id>_pad"`** — dezelfde naam als het pad ín het kader. Een spel, een speeltest of een testsuite vindt de toetsen dus altijd met `[data-hot="ci_som_pad"] [data-pk="7"]`, waar het pad ook staat. Eigenaarschap loopt via een privé-merkteken (`__eig`), niet via de id: een tweede kaart die de strook overneemt wordt niet door de eerste opgeruimd.

**Twaalf toetsen op één rij** als de strook minstens 620 px breed is (48 px + 4 px kier); is de strook smaller (een staand kader, of een kader met een rekenblad ernaast), dan breekt de rij af naar twee of drie rijen — nog altijd onder het kader, dus de kamer blijft vrij.

**Kader laten hermeten.** Gaat de strook aan of uit, dan is er plotseling minder of meer hoogte over: `schilVeranderd()` vraagt world.js om opnieuw te **meten**. Sinds M1b is dat `World.hermeet()`; `World.vuil()` vraagt daar alleen nog een nieuwe tekenbeurt. Beide staan achter een bestaanscontrole, met `vuil()` als terugval (vóór M1b deed die het meten óók), dus de code werkt in beide richtingen.

## 2. `Ui.opKader(fn) -> stop()` — "het kader is van maat veranderd"

Één deur voor elk stuk code dat in schermpixels rekent (de sommenkaart, de keuzestrook, een spel dat rijen legt).

```js
var stop = Ui.opKader(function () { /* opnieuw neerleggen */ });
// ... later:
stop();
```

* Bestaat `World.onKader` op dat moment (ticket M1b: één ontdenderde melding uit een `ResizeObserver` op `#world`, die een opzegger teruggeeft), dan gebruikt `Ui.opKader` die — mits het teruggegeven ding echt een functie is.
* Anders valt hij terug op eigen `resize` + `orientationchange` met 90 ms ontdenderen. De opzegger haalt beide luisteraars weg.

Dus: de code werkt vóór én na het samenvoegen van M1b, en `ui.js` hoeft daar niet nog een keer voor open.

## 3. Sommenkaart: eigenaarschap en `onWeg`

* Elke `Ui.somkaart` stempelt zijn knopje met een privé-merkteken (`el.__somEig`). Maakt `hotel.js` een nieuwe kaart onder dezelfde id (`ci_som` bij elke hertekening), dan ziet de oude luisteraar dat het merkteken niet meer van hem is, zegt zichzelf op (`padUit()`) en tekent niets meer terug. Vóór M1a bleven die luisteraars staan: kantelen tekende dan een kaartje terug dat al opgeruimd was.
* De kaart geeft `Hits.maak` een **`onWeg`**-functie mee. Roept de hotspot-laag die aan bij `Hits.weg(id)` / `Hits.wisEigenaar(door)` (ticket M1b bouwt die kant), dan gaan de kader-luisteraar en de cijferstrook meteen mee. Tot die kant er is doet het merkteken hierboven hetzelfde werk, één kadermelding later.

## 4. `Snd` — de geluidsband gaat pas open na een echte aanraking

| naam | gedrag |
|---|---|
| alle geluiden (`Snd.tik`, `deur`, `plons`, `au`, `klok`, `hup`, …) | doen **niets** zolang de band niet ontgrendeld is. Geen `AudioContext`, geen waarschuwing, geen batterij. `Hotel.start → naarKamer` mag dus rustig `Snd.deur()` roepen bij het laden. |
| ontgrendelen | de eerste `pointerdown` of `touchend` op het venster (capture). Dan pas: `new AudioContext()`, `resume()` en één leeg sample van één tel (het iOS-trucje). |
| spelen | alleen als de band `running` is; staat hij stil, dan `resume().then(spelen)`. |
| achtergrond | `visibilitychange` → `hidden`: `suspend()`. De volgende aanraking wekt hem weer (dezelfde haak). `game.js` bewaart het spel nog steeds zelf bij `hidden`. |
| `Snd.ontgrendeld()` | **nieuw**: `true` zodra de band open is. Voor een testsuite of een spel dat wil weten of geluid zin heeft. |
| `Snd.dempt()`, `Snd.schakel()` | ongewijzigd; `schakel()` naar "aan" ontgrendelt meteen (hij komt uit een echte tik). |

Meting: vóór M1a vier `The AudioContext was not allowed to start`-waarschuwingen per profiel bij het laden, op alle acht telefoonprofielen; na M1a nul.

## 5. Slepen met de vinger (`makeDraggable` / dragKit)

* **Sleepplaatje 40 px boven de vingertop** bij `pointerType === 'touch'` (`VINGER_LIFT`), en het doel wordt op díe plek gemeten (`elementFromPoint(x, y - 40)`), niet onder de vinger. Met muis of pen blijft alles zoals het was (lift 0).
* De speling waarbinnen het nog een tik is blijft 8 px (`TIK_SPELING = 64 = 8²`).
* `contextmenu` wordt op de sleepbron tegengehouden: een kind houdt een knop makkelijk een seconde vast, en dan kwam het menu "Kopiëren / Delen" in beeld.
* **Één tik = één keer.** Na een tik of een geslaagde sleep eet `slikEenKlik(node)` de ene `click` op die de browser daarna nog stuurt (capture op `window`, hooguit 400 ms, alleen voor die knop) en zet `node.__bronTik = 0`. Het oude vangnetje in `Ui.bron` en in de spellen mag blijven staan; het is nu overbodig en het blijft schoon achter. Blokkeert `canDrag()` de sleep, dan komt de klik gewoon door — precies zoals eerst.

## 6. CSS-haken (`style.css`)

| haak | waar het over gaat |
|---|---|
| `html{touch-action:manipulation}` | geen dubbeltik-zoom, dus geen 300 ms wachten bij elke tik. `touch-action:none` staat alleen nog op sleepbronnen en sleepdoelen (`.hot`, `.hotbron`, `.coin`, `.gastkaart`, `.bag`, `.placed`, `.block`). |
| `html.sheet-open{overflow:hidden}` | gezet door `openSheet()`, weg door `closeSheet()`: de pagina onder een blad schuift niet mee. |
| `.padstrip` | de cijferstrook onder het kader (zie 1). |
| `.chroom` | de omhulling om `.topbar` + `.rondebalk` in `index.html`. Liggend onder 450 px hoog worden die twee samen één rij van 48 px (met afbreken naar twee rijen als het smaller wordt dan ~700 px). |
| `@media (orientation:landscape) and (max-height:450px)` | de compacte liggende schil: `.foot` weg, `.logo` weg, `.stagecol` als raster `"wereld rail" / "strook strook"`, de kamerbalk als rail van **3 × 3 chips van 48 px = 148 × 148 px** náást het kader (het woord blijft staan en mag afbreken), kleinere plattegrondcellen, en de knoppenrij van een blad plakt onderaan vast (`position:sticky`) zodat "Sluiten" altijd in beeld staat. |
| railmaat | De rail is met opzet 148 px en geen 98 px: hij moet **korter** blijven dan het kader (minimaal 200 px), anders duwt hij zelf het kader kleiner. Gemeten op 740 × 360: rail 3 × 3 = 148 × 148 px → kader 572 × 228 en kamer 333 × 247; rail 2 × 5 = 98 × 252 px → kader 622 × **200** en kamer 320 × 237. Liggend is de kamermaat hoogte-gebonden, dus extra kaderbreedte levert alleen lucht naast de kamer op; hoogte levert kamer op. |
| `body:not(.metpaneel) .scene{display:none}` | een leeg rekenblad kost geen 12 px tussenruimte meer. |
| `@media (max-width:520px){.foot{display:none}}` | op een telefoon is die voetregel 44 px die de kamer beter kan gebruiken. Op tablet en laptop blijft hij staan. |
| tekstbodem | `clamp(12px,.75rem,14px)` op `.hot .lbl`, `.hot .bdg`, `.kb`, `.kchip .kn`, `.pcel .pn`, `.wtag` (het naamplaatje boven een dier), `.hot.hotbron .hand`, `.hot.hotwolk .zeg`, `.hot.hotsom .somzin`, `.hot.hotsom .somhulp`, `.hot.hotkeuzes .lbl`, `.hot.hotwens .lbl`. |
| `.hot.hotsom .somzin` | breekt af naar een tweede regel (`white-space:normal`) in plaats van te eindigen in "…". |
| `.kamerbalk` | `flex-wrap:wrap`, kier 4 px, geen zijwaarts schuiven meer: negen chips staan op 360-420 px in twee rijen (op 320 px in drie). Chips minstens 48 × 48 (44 breed onder 360 px). |
| `dvh` + `env(safe-area-inset-*)` | `body{min-height:100dvh}`, `.sheet{max-height:92dvh}`, `#app` met `max(…, env(safe-area-inset-*))`, `.toast` onderaan met de inset — alle vier achter een `@supports`, met de oude `vh`/px-waarde als terugval. |
| `.toast` | `pointer-events:none` (een mededeling is nooit een knop). Onder 450 px schermhoogte staat hij bovenaan, net onder de balk, dus nooit over de cijferstrook of de kamerbalk. |

## 7. Wat een spel hiervan merkt

Niets, tenzij het dat wil:

* `Ui.somkaart(..., { padPlek: 'binnen' })` als een spel het pad écht in het kader wil houden.
* `Ui.opKader(fn)` in plaats van een eigen `resize`-luisteraar (dan werkt het ook als M1b `World.onKader` levert).
* `Snd.ontgrendeld()` als het geluid wil aankondigen.
* Zet een spel zélf een `style="font-size:…"` in de html van zijn knop, dan gaat de tekstbodem van 12 px daar niet over: dat blijft het spelbestand. Gemeten met een tekst van 11,52 px: `games/voerkar.js:108` (en `games/tobbe.js:395,398`) — ticket M1c.

## 7b. Wat p1f.js meet sinds M1a

`p1f.js` (golf 3, de vier nieuwe geluiden) toetste het oude gedrag: "roep `Snd.tik()` uit een script en er is een AudioContext", en "de toontjes worden gemaakt terwijl de band `suspended` staat". Beide horen niet meer bij het contract van 4. De suite doet nu vóór de audiosectie één echte tik (`page.mouse.click`) en meet daarna: geen band vóór die tik (`Snd.ontgrendeld() === false`, nul contexten), band open en `running` erna, elk van de vier geluiden zet echt een oscillator of een ruisbuffer neer, en er wordt nooit iets in een slapende band gescheduled. Uitslag tegen deze schil: **53 goed, 0 fout** staand én liggend (was 39/9 met de oude regels; het aantal loopt van 48 naar 53 omdat drie regels door acht echte metingen zijn vervangen).

## 8. Suite

`.fanout/scratch/dierenhotel/mobiel.js` (Chromium, acht telefoonprofielen, echte tik- en sleepgebeurtenissen; stap 11 is de lus-proef met een zelf ingebouwde `World.onKader`). `node mobiel.js` doet alles, `node mobiel.js <profiel>` één profiel, `node mobiel.js --profielen` toont de namen; `DH_SRC` / `DH_OUT` verzetten de bron en de schermafdrukken. `alles.sh` heeft acht rijen `mobiel-<profiel>` (samen zijn ze te lang voor de tijdslimiet van 240 s per suite). Metingen die niet van de schil zijn (hotspot-plaatsing = M1b, tekstmaat in een spelbestand = M1c) worden geprint als `LET OP`-regel en maken de suite niet rood.
