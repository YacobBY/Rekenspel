# P1e — Accessoires op de gasten (hoedje, sjaaltje, bal)

Voor de souvenirkraam (G5, `dierenhotel-golf3-games.md`): een gast koopt een
hoedje, een sjaaltje of een bal en draagt het zichtbaar tot het uitchecken.

Aangeraakt: `demos/dierenhotel/art.js` (tekenen + API), `state.js` (drie
regels: het veld op het gastrecord en twee aanvullingen voor oude opslag) en
**één regel** in `world.js`: de tekenregel van `tekenDier()`. **Niet**
aangeraakt: `registry.js`, `rooms.js`, `hotel.js`, `ui.js`, `econ.js`, geen
enkel spel.

## Namen

`'hoedje'`, `'sjaaltje'`, `'bal'` — ook op te vragen als `Art.ACCESSOIRES`
(een kopie van de lijst). **Elke andere naam wordt gefilterd**, op alle drie
de plekken waar hij binnen kan komen:

- `accessoire(id, naam)` met een onbekende naam doet niets en geeft `null`;
- `accessoires(id)` geeft alleen bekende namen terug, dus een oude of met de
  hand aangepaste save kan geen rommel in de tekenkant duwen;
- `accSleutel()` in de tekenkant laat onbekende namen vallen, dus ook
  `Art.kit.dier(kind, pose, g, ['pet'])` geeft het kale dier.

## Waar het staat

Op het gastrecord: `g.accessoires = ['hoedje', 'sjaaltje', 'bal']` (een
deelverzameling; de volgorde in het lijstje doet niets).

- `mkGast()` (state.js:20) geeft elke gast `accessoires: []`, dus een nieuwe
  gast begint zonder.
- `vulAan()` (state.js:616 en 618) geeft elke gast uit een oudere save een
  leeg lijstje — de gasten in het hotel, én de gasten op de wachtlijst en de
  gast aan de balie (`s.nieuweGast`).
- Het hele gastrecord gaat al mee in `bewaarSpel()` (v7, sleutel
  `kws-hotel-v7`, `s.gasten[]` en `s.nieuweGast`), dus **geen versiebump**:
  een save zonder het veld laadt als `[]`, en een save mét het veld is voor
  oudere code gewoon een onbekend extra veld.
- Bij het uitchecken verdwijnt het record en dus ook de accessoires; er is
  niets extra's op te ruimen. `accessoires(<vertrokken id>)` geeft `[]`.

**Nooit `g.accessoires.push(...)` doen.** De wachtlijst wordt met
`Object.assign({}, a)` uit `GASTEN_POOL` gekopieerd, dus een verse gast deelt
zijn lege lijstje met zijn poolregel. De API zet er daarom altijd een NIEUWE
lijst neer (`concat` / `filter`).

## API (via de uitbreidingshaak `window.CTX_UITBREIDINGEN`, dus op elke `ctx`)

```js
ctx.wereld.accessoire(id, naam)     // erbij, idempotent -> lijst (kopie), of null bij onbekende gast/naam
ctx.wereld.accessoires(id)          // -> lijst (kopie, gefilterd); [] als hij niets draagt of niet bestaat
ctx.wereld.accessoireWeg(id, naam)  // eraf; niet-gedragen naam = niets -> lijst (kopie), of null bij onbekende gast
```

De haak wordt bij het laden van art.js op `window.CTX_UITBREIDINGEN` gezet
(zie de opmerking aan het eind van `ctxVoor` in `games/registry.js`), dus
`registry.js` verandert niet. `id` mag ook de gast aan de balie zijn
(`state.nieuweGast`). Elke wijziging zet de wereld vuil (`World.vuil()`) —
de volgende frame tekent het al — en bewaart (`State.bewaar()`). Dezelfde
drie functies staan ook direct op `Art`: `Art.accessoire`, `Art.accessoires`,
`Art.accessoireWeg` (zo test de suite ze zonder spel).

Voor een eigen voorbeeldplaatje (de kraam, een spec-plaat):
`Art.kit.dier(kind, pose, g, acc)` met `acc = ['hoedje', 'bal']` of
`'hoedje,bal'` geeft precies die variant; `acc = []`, `null` of weggelaten de
kale.

## De haak in world.js (één regel)

`tekenDier()` in world.js vraagt de plaat van het dier op. Die regel geeft nu
ook de accessoires mee:

```js
var p = K.dier(d.kind, d.pose, g, Art.accessoires ? Art.accessoires(d.id) : null);
```

Dat is de hele wijziging in world.js. `d.id` is het gast-id, dus er is geen
giswerk over wélk dier getekend wordt (een eerdere versie leidde dat af uit
de leesorde van `d.kind`/`d.pose`; die truc is weg). De guard houdt world.js
overeind als art.js ooit zonder P1e geladen wordt. `Art.kit.dier` gebruikt
altijd zijn vierde argument: geen argument, `null` of `[]` geeft het kale
dier uit `poseCache`.

Kosten per dier per beeld: één `State.ruw()` + een lineair zoekje over de
gasten (er zijn er maximaal een handvol), drie `indexOf` in `accSleutel()` en
één cache-lookup op een string. De plaat zelf wordt niet opnieuw gebakken.

## Tekenen (art.js)

- `bouw(kind, pose, sleutel)`; de sleutel is de vaste volgorde
  `'hoedje,sjaaltje,bal'` (`accSleutel()`), zodat elke combinatie precies één
  cache-ingang heeft. Kale modellen blijven in `poseCache`, aangeklede in een
  begrensd laatje (`tooiCache`, `TOOI_MAX = 72`; vier bedden × 15 houdingen
  = 60 in het ergste geval). De sleutel van de gebakken plaat is
  `d|kind|pose|g|sleutel`.
- Ankers per soort en houding (`ankers(kind, p)`): kop `[midden-x,
  bovenkant-y, rx, rz]`, hals `[x0, y0, x1, y1, straal, diepte, plek op de
  as (0..1), extra dikte]` — dezelfde getallen als in
  `hond()/poes()/konijn()/gans()`, inclusief de gans-omrekening van hx/hy. De
  tooi beweegt dus mee met happen, blij zijn en snuffelen.
- Twee meetlatjes op het model zelf, zodat er geen tabel met vaste
  sprongetjes per soort nodig is:
  `huid(v, x0, x1, y0, y1)` geeft `[hoogste z, laagste y, hoogste y]` van die
  kolommen (de hoogste z is de kant van de kijker), en `pyMax(v, van, tot)`
  geeft het laagste punt op het SCHERM (`(x+z)*S/2 - (y+1)*HG`, dezelfde
  formule als `bake()`).

### Zichtbaarheidsregels (P1e-F1)

1. **Elk stuk moet op galerij-schaal (g = 2) op ELKE soort en in ELKE houding
   te zien zijn.** De suite legt daar ondergrenzen op: sjaaltje ≥ 800 px
   staand en ≥ 400 px liggend, bal ≥ 300 px, per soort.
2. **Niets mag het gezichtje bedekken** (HOTEL.md §9). De sjaal staat dwars
   op de hals en de `t`-grens sluit kop en staart uit; het hoedje blijft
   boven de kop.
3. **De bal hoort bij de omtrek van het dier zelf**, dus binnen de
   rechthoek van het kale dier: hij zit tegen de borst/buik aan de kant van
   de kijker en `pyMax()` tilt hem op als hij onder het dier uit zou zakken.
   Zo kan een bed dat ná het dier getekend wordt hem niet meer opslokken.
4. **Niets mag buiten het dier zweven.** De kraag van de sjaal blijft onder
   `dakVan(v)` (per x-kolom de hoogste y van het dier) én onder de halslijn:
   de poes en het konijn leggen hun oren liggend langs de rug, en zonder dat
   plafond werd zo'n oor een oranje stok over de rug.

### Per stuk

- **Hoedje**: platte rand (`ell`, rx+0.7, 2 lagen) die één laag in de kop
  zakt, daarop een kroon (`ell`, ry 3.2 met `ymin`) en een wit lintje als
  eerste laag boven de rand. Kleur mint (`BAND`), lintje `WIT`. De kroon is
  ten opzichte van de eerste versie een laag lager en smaller: hij was ~22 %
  van de omtrek, nu ~18 %. Konijnenoren steken er ruim bovenuit; het hoedje
  van de poes staat één blokje verder naar de snuit (`ankers`), zodat haar
  spitse oortjes er achter langs naar buiten piepen. De flaporen van de hond
  blijven aan weerskanten zichtbaar.
- **Sjaaltje**: drie stappen. `ringVerf()` verft eerst de BESTAANDE blokjes
  in een schijf loodrecht op de halsas bij (kin, hals, bovenkant borst) —
  dat is de manier van art.js voor details (halsband, sokjes) en zorgt dat
  de kleur altijd op het buitenste vlak landt. Daarna komt `ring()` erbij
  voor de dikte van de kraag (onder `dak`). Ten slotte de **slip**: zes lagen
  omlaag vanaf de halsaanzet, per laag de voorste kolom die er echt is (bij
  de hond houdt het lijf al bij x 17 op) en telkens één blokje búiten de
  huid, met een witte franje op de onderste laag. Kleur `PAL.gans.e`
  (oranje), franje `WIT`. Zonder die slip was de sjaal bij de hond
  onzichtbaar: 150 px staand / 58 px liggend (g = 2), nu 859 / 510.
- **Bal**: bol r 2.7 met een witte evenaar, `PAL.poes.e` (roze), tegen de
  borst/buik op ~45 % van de hoogte van het lijf en 1,4 blokje búiten de
  huid, dus aan de kant van de kijker. De eerste versie legde hem met een
  vaste sprong (z 17.6) vóór de pootjes op de grond; daar hoorde hij niet bij
  de omtrek van het dier en schoof een bed er zo overheen (17 px verschil in
  de wereld tegenover 1053 op de kale plaat). Nu: 1002 px op de bedplek,
  504 px met het bed ná hem getekend, 687 px liggend ín het bed.
- De kaart-dieren (`Art.animal`: poort, vignet, rekening) blijven kaal. Hun
  canvasmaat (`CW`/`CH`, en de css-variabelen `--vox-w/--vox-h`) wordt in
  `init()` berekend uit een vaste lijst kale houdingen; een hoedje erbij zou
  de maat van élk kaartje veranderen. Dat is bewust buiten dit ticket
  gehouden.

## Getest

`.fanout/scratch/dierenhotel/p1e.js` (`node p1e.js` / `node p1e.js land`;
`DH_SRC` en `DH_OUT` werken). **101 assertions per oriëntatie, beide 0 fail**:
de bouwer voor alle vier de soorten staand én liggend (pixelverschil,
kleurtellingen, omtrek, de ondergrenzen op galerij-schaal en de omtrek-test
van de bal) en voor alle 15 houdingen, de cache-sleutel, de API op
`ctx.wereld`, de wereld (in rustmodus, dus stilstaand canvas) inclusief de
bal op de bedplek / achter het bed / liggend in bed, de opslag (v7,
herladen, een save van vóór P1e) en het uitchecken van een gast met alle
drie. Schermafdruk: `p1e-accessoires.png` (420×860, vier soorten staand en
liggend met hoedje + sjaaltje + bal), plus `p1e-<tag>-wereld-staand.png`,
`p1e-<tag>-wereld-lig.png`, `p1e-<tag>-bal-achter-bed.png`,
`p1e-<tag>-bal-in-bed.png` en `p1e-<tag>-na-uitcheck.png`.

Meegedraaid tegen dezelfde worktree: `slaap.js` 124/0, `p1c.js` 197/0
(world.js is aangeraakt), `loop.js` 157/0, `w1.js` 76/0, `smoke.js` zonder
console-fouten.

**Bekende grens.** De bal hoort nu bij de omtrek van het dier en is dus net
zo goed te verstoppen als het dier zelf: staat een gast pal achter een bed
dat 43 % van hem afdekt, dan blijft er van de bal ~133 px (g = 2) over. Over
een raster van 49 plekjes rond bed 1 was de slechtste plek met de eerste bal
58 px, nu 133 px; onder de 100 px komt hij nergens meer.
