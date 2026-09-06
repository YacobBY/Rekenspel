# Minigame-API — Dierenhotel Kwispelsteeg

Elk rekenspelletje is **één bestand in `games/`** dat zichzelf aanmeldt zodra het
geladen is. Zo kunnen meerdere mensen tegelijk aan verschillende spellen bouwen
zonder ooit in hetzelfde bestand te werken.

> **Gouden regel:** raak alleen je eigen `games/<jouwspel>.js` aan. Alles wat je
> nodig hebt komt binnen via de `ctx` die je bij `start(ctx)` krijgt. Heb je iets
> nodig dat er niet is (een nieuw meubel in een kamer bijvoorbeeld, want dat
> staat in het gedeelde `rooms.js`), meld dat dan terug — bouw het niet zelf in
> een gedeeld bestand.

---

## 1. Aanmelden

```js
/* games/tobbe.js */
(function () {
'use strict';

var C = null;                              /* de ctx, bewaar hem even */

function start(ctx) {
  C = ctx;
  /* ... bouw je paneel, zet je hotspots, reken je som uit ... */
}

function stop() {                          /* optioneel maar netjes */
  if (C) C.hotspots.wisAlles();            /* je eigen hotspots opruimen */
  C = null;
}

Games.register({
  id: 'tobbe',                             /* uniek, = mapnaam van je bestand */
  naam: 'Tobbe-tijd',                      /* wat het kind ziet */
  kamer: 'tuin',                           /* in welke ruimte het spel woont */
  hotspot: { obj: 'tobbe', icoon: '🛁',    /* waar de knop aan hangt */
             label: 'Tobbe', hoog: 12,     /* hoog = voxels boven het voorwerp */
             dx: 0, dz: 0 },               /* en eventueel een zetje ernaast */
  unlock: function (N, band) { return N >= 1; },   /* mag het al? */
  start: start,
  stop: stop
});
})();
```

Zet je bestand daarna in `index.html` in de rij `<script src="games/...">`
(`voerkar.js`, `bedden.js`, `sleutels.js`, `tobbe.js` en `meubels.js` zijn af en
staan er al; `zwembad.js`, `wekker.js`, `hinkel.js`, `was.js` en `kraam.js` hangen
er al leeg in — vul het bestand van jouw spel, dan hoeft `index.html` niet mee).

### Wat de stekkerdoos voor je doet
* De **knop in de wereld** aanmaken op het voorwerp uit `hotspot.obj`, met de
  juiste z-index (zie §4) en met een tik die `start(ctx)` aanroept.
* Die knop **weghalen** zolang `unlock(N, band)` false teruggeeft.
* Bij het starten van een ander spel eerst **jouw `stop()`** aanroepen, jouw
  hotspots wissen en het paneel leegmaken.
* De **camera** naar jouw `kamer` schuiven als het kind ergens anders staat.

### Welke voorwerpen bestaan er om aan te hangen?
`hotspot.obj` mag zijn: de naam van een decorstuk in die kamer, de id van een
slot (`bed1`, `bed2`, `bak`, `tobbe`) of de sleutel van een los voorwerp (`kar`,
`balielamp`). Nu beschikbaar:

| kamer | obj | wat het is |
|---|---|---|
| receptie | `bel`, `kassa`, `boek`, `prikbord`, `sleutelbordz`, `balielamp` | balie met bel, kassa, meubelboek, prikbord, sleutelbord, lamp |
| gang | `kist`, `plant` | gangdecor |
| kamer1 / kamer2 | `bed1`, `bed2`, `bak`, `mand`, `plant` | twee bedden, voerbakje, speelmand |
| keuken | `kast`, `zak`, `kar` | voerkast, koekjeszak, voerkar |
| tuin | `tobbe`, `bal`, `kist`, `hok`, `boom` | het erf van de Kwispelsteeg |
| zwembad | `mat`, `plant` | het instapmatje op het dek, een plant in de hoek |
| wasserij | `kast`, `tobbe` | het wasrek tegen de achterwand, de wastobbe |

Staat het voorwerp waar jij je knop aan wil hangen er nog niet, dan hoef je
niet in `rooms.js`: zet het als **eigen decorstuk** in de wereld en hang je
knop daaraan (zie "Eigen decor in de wereld" in §2).

### Zeg welke wens je inlost (`wens`)

Een gast kan 🏊 willen zwemmen of 🎁 een souvenir willen. Het hotel deelt zo'n
wens **alleen uit als er een spel is dat hem inlost**, dus zeg het in je
registratie — anders staat er nooit een wolkje dat het kind niet kan afmaken:

```js
Games.register({ id: 'zwembad', naam: 'Zwembad', kamer: 'zwembad', wens: 'zwemmen', ... });
Games.register({ id: 'kraam',   naam: 'Kraam',   kamer: 'tuin',    wens: ['souvenir'], ... });
```

* `wens` is één naam of een lijstje namen. Nieuw zijn `zwemmen` (🏊, "wil
  zwemmen") en `souvenir` (🎁, "wil een souvenir"). `bad` (🛁) mag ook: die zat
  vroeger vast aan de tobbe.
* `kamer`, `eten` en `spelen` lost het hotel zelf op; die hebben geen spel nodig.
* De wens komt er pas als jouw spel **niet** `stub: true` is en `unlock(N, band)`
  hem doorlaat (`Hotel.wensMogelijk(type)` kijkt daarnaar).
* Wensen komen 's ochtends op de **oneven** dagen (de tobbe houdt de even
  dagen), alleen bij gasten die een bed hebben: hooguit één gast per ochtend,
  en twee zodra er meer dan vier gasten zijn.

Je vindt je gasten en hun plek zo:

```js
var wachtend = ctx.wereld.dieren('zwembad')
  .filter(function (g) { return g.behoefte === 'zwemmen' && !g.blij; });
/* de wens afronden — dit is de enige aanroep die je nodig hebt */
ctx.wereld.behoefteKlaar(gast.id, 'zwemmen');   /* of zonder tweede argument: de huidige wens */
```

`behoefteKlaar` zet de vlag (`eten` → gegeten, `bad`/`spelen`/`zwemmen`/
`souvenir` → blij), haalt het wenswolkje weg, bewaart en tekent opnieuw. Hij
geeft `true`, of `false` als die gast niet bestaat. Een **ster** geeft hij niet:
dat doe je zelf met `ctx.taakKlaar(naam)`. Een taakje op het prikbord komt er
ook niet automatisch — zet dat in je registratie (zie §6).

De gast loopt zelf naar zijn plek en wacht daar. Die plek is
`Rooms.get('zwembad').dek.start` (op het dek, vóór het water) of het midden
vóór `Rooms.get('tuin').zones.kraam`; `Hotel.plekVanBehoefte(g)` rekent hem uit
en valt netjes terug op een vrij vakje in de tuin als de kamer er niet is.

---

## 2. Wat zit er in `ctx`?

### `ctx.wereld` — de kamers en de dieren
| aanroep | doet |
|---|---|
| `kamers()` | lijst met alle ruimtes (data uit `rooms.js`) |
| `kamer(id)` | één ruimte: `{id, naam, icoon, w, d, wand, deuren, decor, slots, vrij, box}` |
| `pad(van, naar)` | kortste route door de deuren, bv. `['gang','kamer1']` |
| `slots(kamerId, soort)` | `'bed'`, `'bak'` of `'vrij'` (het vrije vloerraster) |
| `slot(kamerId, slotId)` | één plek: `{id, soort, x, z, sx, sz}` (`sx/sz` = sta-plek) |
| `actief()` / `naar(kamerId)` | welke ruimte in beeld staat / camera erheen (300 ms) |
| `dieren(kamerId)` | de gasten (uit de spelstand), eventueel gefilterd op ruimte |
| `dier(id)` | het levende diertje in de motor: `x, z, kamer, staat, pose` |
| `ga(id, x, z, na)` | loop in de eigen kamer naar (x,z); `na` = `'stil'\|'wacht'\|'blij'\|'eet'\|'snuif'` |
| `loopNaar(id, x, z, o)` / `stappen(id, punten, o)` | **lopen met een belofte**: `Promise<boolean>` (zie "Bewegen met een belofte") |
| `pose(id, naam, duur)` | **een houding zetten**, ook `'zwem'` en `'spring'` → `true`/`false` |
| `reis(id, kamerId, {x,z,na})` | loop dóór de deuren naar een andere ruimte |
| `slaap(id, kamerId, slotId)` | in bed leggen (loopt er zelf naartoe) |
| `setMood(id, m)` | `'blij'`, `'droopy'`, `'bouncy'` (via art.js) |
| `setFood(id, n, per)` | vult het bakje van de kamer waar dat dier is |
| `setBak(kamerId, slotId, 0..4)` / `bakStand(...)` | bakje rechtstreeks vullen / uitlezen |
| `feest(ids)` | lopen → eten → blij spelen (de complete smulanimatie) |
| `solo(id, act)` | vignet: dit dier gaat op een vrije plek zijn ding doen |
| `ding(sleutel)` / `dingZet(sleutel, {kamer,x,z,y})` | los voorwerp opvragen / verzetten (de voerkar). Geef je alleen `kamer` mee, dan krijgt het voorwerp vanzelf een nette plek op de vloer van die ruimte; een plek buiten de kamer wordt naar binnen gehaald. |
| `vuil()` | zeg dat het beeld opnieuw getekend moet worden |
| `mik(obj[, kamerId])` | waar hangt dit voorwerp/dier? → `{kamer,x,z,y,volg}` |
| `schaal()` | `{g, dpr, k, pxPerVoxelX, pxPerVoxelY, pxPerHoogte}` — hoeveel css-px is één voxel. `dpr` is de **tekendichtheid van het canvas**, niet `devicePixelRatio`: world.js tekent vaak dichter en laat de css terugschalen (HOTEL.md §1). Reken dus altijd met `k` (= `g / dpr`) en nooit zelf met `devicePixelRatio`. |
| `behoefteKlaar(gastId[, wens])` | de wens van een gast vervullen zoals het hotel dat doet (zie §1) |
| `decor(kamerId, o)` / `decorWeg(kamerId, id)` | **eigen decorstuk** neerzetten of bijwerken / weghalen |
| `decorLijst(kamerId)` / `decorWisAlles()` | wat staat er / al jouw stukken weg (aantal) |
| `accessoire(id, naam)` / `accessoireWeg(id, naam)` / `accessoires(id)` | een hoedje, sjaaltje of bal op een gast |
| `getalTag(obj, n[, o])` | **een cijfer ÓP het voorwerp** (bakje, haakje, toonbank); `n = null` haalt het weg; `o.prio` (standaard 4) bepaalt wie er blijft staan als een kamer vol raakt |
| `voegBed(kamerId, {x,z,rot})` | **een bed erbij** → de plek, of `null` als het niet past |
| `plaatsMeubel(kamerId, type, x, z, rot)` | meubel neerzetten → `{id,kamer,type,x,z,rot,soort}` of `null` |
| `verwijderMeubel(id)` | meubel weer weghalen |
| `kamerMeubels(kamerId)` | wat is er in deze ruimte bijgeplaatst |
| `meubeltypen()` | de namen die `plaatsMeubel` kent |

Coördinaten zijn **voxels**: `x` loopt naar rechtsonder, `z` naar linksonder,
`y` omhoog. Diepte (tekenvolgorde) is `x + z`; klein = achteraan. De wanden
staan altijd op `x = 0` (links) en `z = 0` (achter), de vloer is
`Rooms.get(k).w × .d`. Dezelfde maat geldt voor `decor`, `slots` en je eigen
decorstukken.

### De ruimtes van golf 3: zwembad, wasserij en de tuinzones

Het zwembad en de wasserij zijn gewone ruimtes in `rooms.js`; hun bijzondere
maten staan als **data op de ruimte**, dus je hoeft niets zelf op te meten.

```js
var b = ctx.wereld.kamer('zwembad').bad;   // { x0: 18, x1: 134, z0: 12, z1: 44 }
var d = ctx.wereld.kamer('zwembad').dek;   // { start: {x:12, z:56}, over: {x:132, z:56} }
var z = ctx.wereld.kamer('tuin').zones;    // { hinkel: {...}, kraam: {...} }
```

| veld | waarde | wat het is |
|---|---|---|
| `zwembad` | 144 × 88, wand 50, `loop: 1.5`, deur naar de tuin in de linkerwand | 🏊 het zwembad |
| `zwembad.bad` | `{x0: 18, x1: 134, z0: 12, z1: 44}` | het water: 116 × 32 voxels, tegen de achterwand |
| `zwembad.dek` | `start` (12, 56) en `over` (132, 56) | de twee **staplekken** op het dek vóór het water |
| `wasserij` | 100 × 90, wand 52, `loop: 1.25`, deur naar de keuken in de achterwand | 🧺 de wasserij |
| `tuin.zones.hinkel` | `{x0: 24, x1: 100, z0: 34, z1: 50}` | 76 × 16 vrije vloer vóór het hok: plaats voor 11+ stapstenen langs `x` |
| `tuin.zones.kraam` | `{x0: 104, x1: 126, z0: 36, z1: 68}` | 22 × 32 langs de rechterrand: een kraam met de lange kant langs `z`, gast ervoor |

* **Een baan van L meter op het bad afbeelden:**
  `x(p) = bad.x0 + (bad.x1 − bad.x0) × p / L`, met de zwembaan op
  `z = (bad.z0 + bad.z1) / 2` = 28. De overkant is `x = bad.x1`. Meterstrepen op
  de rand: `z = bad.z0 − 2` of `z = bad.z1 + 2`, met dezelfde formule voor `x`.
* **Zet nooit een sta- of dwaalplek in het water.** De dieren lopen in rechte
  lijnen, dus een plek aan de overkant zou een gast dwars door het bad laten
  wandelen. Alle dwaalplekken, de deur én `dek.start`/`dek.over` liggen in
  dezelfde strook vóór het water (`z ≥ 50`), en die strook is convex: geen
  enkele wandeling kruist het water. Wil je een dier ín het bad, stuur het er
  dan zelf naartoe (`loopNaar`, `stappen`, of `reis` **mét** doel).
* `reis(id, 'zwembad')` **zonder** doel mikt op het midden van de kamer, en dat
  is de voorrand van het bad. Geef dus altijd een doel mee, bijvoorbeeld
  `ctx.wereld.kamer('zwembad').dek.start`.
* De zones in de tuin zijn **alleen data**: ze zijn vrijgehouden van hek,
  decor en grasplukjes, maar je zet er zelf je stenen en je kraam neer.
* De badrand is vloerkleur, geen model: er is niets om je knop aan te hangen.
  Gebruik een eigen decorstuk (hieronder) of `Rooms.plek('zwembad', fx, fz)`.

### Bewegen met een belofte: `loopNaar`, `stappen`, `pose`

Voor "loop daarheen en doe dan X" — steen voor steen hinkelen, precies n meter
zwemmen, tellen bij elke stap:

```js
ctx.wereld.loopNaar(id, x, z, opties)      // → Promise<boolean>
ctx.wereld.stappen(id, punten, opties)     // → Promise<boolean>
ctx.wereld.pose(id, naam, duur)            // → boolean
```

| in `opties` | betekenis | standaard |
|---|---|---|
| `pose` | houding onderweg: `null` (lopen), `'zwem'`, `'spring'` | `null` |
| `tempo` | maal de loopsnelheid in deze kamer; bij `spring` maal de sprongduur | `1` |
| `perStap(i, punt)` | gaat af bij **elke** landing (ook bij `loopNaar`: één keer, `i = 0`), vóór de belofte | – |
| `na` | eindhouding: `'wacht'`, `'stil'`, `'rust'`, `'zit'`, `'kijk'`, `'snuif'`, `'blij'`, `'sip'`, `'zwem'`, `'spring'` | `'wacht'`, en `'zwem'` bij `pose: 'zwem'` |

`punten` mag `[{x, z}, …]` of `[[x, z], …]` zijn; punten zonder getal worden
overgeslagen. `loopNaar(id, x, z, o)` is precies `stappen(id, [{x, z}], o)`.
Coördinaten zijn voxels **in de kamer waar het dier nu staat**: een opdracht
loopt nooit door een deur (dat blijft `reis`).

* **`true`** = het laatste punt gehaald, exact op het punt, in de eindhouding
  `na`. Die is standaard `wacht` (rustig ademen, blijft staan tot het volgende
  bevel), zodat "loop erheen, dan X" niet stukloopt op een gast die alweer
  wegwandelt. Met `na: 'stil'` gaat het dier daarna weer zijn eigen gang.
* **`false`** (nooit een reject) = de opdracht is **ingehaald** door een ander
  bevel: een nieuwe `loopNaar`/`stappen`, `ga`, `reis`, `slaap`, `pose`,
  `feest`, `setMood('blij')`, `solo`, de kamer verlaten, of uitchecken. De oude
  belofte valt vóórdat de nieuwe start.
* Een bevel dat feitelijk niets doet, laat je opdracht met rust:
  `setMood(id, 'idle')`, voeren in een kamer zonder bakje, een onbekende
  houding, en `stappen(id, [])` (dat geeft meteen `true` en raakt het dier
  niet aan). Onbekend dier → meteen `false`.
* **Tempo schaalt de hele duur, lineair**: tempo 2 is dezelfde beweging, twee
  keer zo snel. Het dier **glijdt door** over de punten en remt alleen af voor
  het laatste, dus 43 punten over de badlengte kosten net zoveel tijd als één
  punt (gemeten 4,3 s). Reken op 20–35 voxel/s in een `loop 1.5`-kamer.
  Springen glijdt met opzet niet door: stoppen en squashen hoort bij hinkelen
  (≈ 0,6 s per steen).
* **Rustmodus** (`prefers-reduced-motion`): er beweegt niets, maar `perStap`
  gaat per punt af (met het dier op dát punt), het dier staat op het laatste
  punt, krijgt zijn eindhouding en de belofte is direct `true`.
* **Een belofte overleeft geen herlaad.** Houd een beurt dus nooit alléén in een
  `.then(...)` bij: zet de stand in `ctx.data()` en herstel hem in `start()`.
* Staat het tabblad op de achtergrond, dan staat de motor stil en valt een
  belofte pas als het spel weer in beeld is.

`pose(id, naam, duur)` — `duur` in tikken (15 per seconde); `0` of weggelaten
betekent voor `zwem`, `spring`, `wacht` en `sip`: tot het volgende bevel.
Onbekende naam of onbekend dier → `false` en er verandert niets. `pose` haalt
een lopende opdracht in.

| naam | wat je ziet |
|---|---|
| `zwem` | het dier zakt 7 voxels: de buik op de waterlijn, de pootjes vaag ónder een doorschijnende waterband. Zachte deining, peddelen, af en toe een plonsje |
| `spring` | ter plekke hupsen; als `pose` van `stappen` één parabool per punt, met een squash bij de landing |
| `stil` / `rust` | de gewone motor-toestand; daarna gaat het dier weer zijn eigen gang |
| `wacht` | staat rustig te ademen, kijkt naar voren, tot het volgende bevel |
| `zit`, `kijk`, `snuif`, `blij`, `sip` | de bestaande houdingen van de motor |

Op het dier (`ctx.wereld.dier(id)`) staat `hoogte` = voxels **boven** de vloer:
springer > 0, zwemmer −7, staand of geland 0. (`lift` is dezelfde waarde als
tekenafstand omlaag in pixels, de bedconventie van de motor.) Bij een landing
midden in een zwemopdracht blijft het dier drijven — een zwemmer gaat niet elke
meter even staan. De waterband tekent alleen in de houding `zwem`, en in een
kamer mét een `bad`-rechthoek alleen binnen die rechthoek: een gast die in
zwemhouding op het dek staat blijft droog.

```js
/* hinkelpad: steen voor steen, tellen bij elke landing */
C.wereld.stappen(g.id, [[40, 110], [46, 110], [52, 110]], {
  pose: 'spring',
  perStap: function (i, p) { C.wereld.getalTag(g.id, i + 1); C.snd.hup(); }
}).then(function (ok) { if (ok) vraagVolgende(); });   /* false = een ander bevel nam het dier over */

/* zwembad: precies 13 meter, daarna blijven drijven */
C.wereld.loopNaar(g.id, xVanMeter(p + 13), 28, { pose: 'zwem' })
 .then(function (ok) { if (ok) C.wereld.getalTag(g.id, (p + 13) + ' m'); });
```

### Eigen decor in de wereld: `Rooms.registerModel` + `ctx.wereld.decor`

Heb je een klok met wijzers, stapstenen met een cijfer, een vlag op L meter of
een kraam nodig, dan meld je één keer je **eigen voxelmodel** aan en zet je het
zo vaak als je wil in een kamer neer. Beide horen in je eigen bestand; je hoeft
`rooms.js` niet te openen.

```js
Rooms.registerModel('steen', function (p) {          /* fn(params) → voxellijst */
  var K = Art.kit, v = [];
  K.bx(v, -3, 0, -3, 7, 2, 7, p.aan ? '#C9E7D4' : '#E6E1D8');
  return v;
});
/* in start(ctx): */
ctx.wereld.decor('tuin', { id: 'steen3', model: 'steen', x: 45, z: 42, params: { aan: false } });
ctx.wereld.getalTag('steen3', 30);                   /* een cijfer erop, schuift mee */
/* alleen dit ene plaatje wordt opnieuw gebakken: */
ctx.wereld.decor('tuin', { id: 'steen3', params: { aan: true } });
ctx.wereld.decorWeg('tuin', 'steen3');
```

`Rooms.registerModel(naam, fn)` geeft `true`, of `false` bij een lege naam,
iets dat geen functie is, of een **beschermde** naam (alles wat het hotel zelf
al kent: `bed`, `balie`, `kast`, `kar`, `tobbe`, `plant`, …). Je eigen naam
opnieuw aanmelden mag (laatste wint). `Rooms.heeftModel(naam)` zegt of een naam
bestaat. `fn(params)` moet **zonder eigen toestand** werken: dezelfde `params`
horen dezelfde lijst te geven, want er wordt op `params` gecachet.

**De voxellijst.** Een array van `[x, y, z, kleur]`, met het anker (0, 0, 0) op
de vloer in het midden van je stuk en `y` omhoog. Kleur is `'#RRGGBB'` — één
kleur per blok is genoeg, `art.js` belicht de vlakken zelf. Dubbele
coördinaten: de laatste wint; binnenliggende vlakken worden weggelaten, dus
massieve blokken zijn goedkoop. Een **lege lijst mag** (niets te zien, geen
fout). Bouw met `Art.kit`: `K.bx` (blok), `K.ell` (ellipsoïde), `K.punt`,
`K.verf` (herkleuren binnen een gebied). Houd een stuk onder ~40 × 40 × 40
voxels: de wanden zijn 50–58 hoog en moeten hoger blijven dan wat ervoor staat.

`ctx.wereld.decor(kamerId, o)` met
`o = { id, model, x, z, params?, hoog?, rot?, ver? }`:

* `id` is verplicht en is de sleutel **binnen die kamer**. Bestaat hij al, dan
  werk je het stuk bij: alles wat je weglaat blijft zoals het was.
* `model` is verplicht bij een nieuw stuk; onbekend → `null` + één `console.warn`.
* `x, z` zijn kamervoxels, breuken mogen. Er wordt niet geklemd.
* `hoog` (alias `y`) = hoogte boven de vloer (op de balie 14, zoals de bel). Dat
  verschuift alleen het plaatje; in de tekenvolgorde blijft het stuk op de vloer.
* `rot` = 0..3 kwartslagen om de y-as (een echte draaiing, geen spiegeling).
* `ver` = altijd achteraan tekenen, voor wanddecor.
* Terug komt een **kopie** `{id, model, kamer, x, z, hoog, rot, ver, params, door}`,
  geen levend object: sleutels van de kopie veranderen raakt het stuk niet.
  Wil je andere params, roep dan `decor()` opnieuw aan.
* `null` bij: onbekende kamer, geen id, onbekend model, een stuk van een ánder
  spel, of een volle kamer (**48 stukken per kamer**). Een afgewezen aanroep
  laat niets achter.

**Eigenaarschap en opruimen.** Alles wat je via `ctx` neerzet staat op naam van
jóuw spel; je kunt alleen je eigen stukken bijwerken en weghalen. Bij het
starten of stoppen van een spel verdwijnt het decor van de andere spellen
automatisch. **Zet toch `ctx.wereld.decorWisAlles()` in je `stop()`** — dat is
één regel, het kan geen kwaad (na de automatische opruiming geeft hij 0 terug)
en je bent er dan niet van afhankelijk. Los decor zit **niet in de opslag**: na
een herlaad is het weg, dus zet het opnieuw in `start()`, ook als je een beurt
uit `ctx.data()` herstelt.

**Tekenvolgorde.** Eén rij voor alles in de kamer, gesorteerd op diepte `x + z`
(+0,3 als er een `hoog` is, −1000 als `ver`); dieren en bedden zitten in
dezelfde rij, een slaper op +0,5. Kleiner = verder weg = eerder getekend. Dus
een stuk op (30, 40) staat vóór een slaper in bed 1 van kamer 1, een stuk op
(30, 15) erachter. Gelijke diepte is niet gedefinieerd: geef stukken die elkaar
op het scherm raken een verschillende `x + z`.

**Kosten.** Elk stuk bakt één eigen plaatje en houdt dat vast; opnieuw bakken
gebeurt alleen als `model`, `rot`, de JSON van `params` of de voxelmaat
verandert. Per beeld kost een stuk één `drawImage` — precies zoveel als een
meubel — en het blijft buiten de gedeelde plaatjes-cache, dus het duwt de
vloerplaat er niet uit. Stukken in andere kamers worden overgeslagen.

**Je `hotspot.obj` mag een decor-id zijn.** `Games.register({hotspot:{obj:…}})`
zoekt in deze volgorde: losse dingen → slots → vast decor uit `rooms.js` → jouw
losse decor (`World.decorPlek`, dezelfde ids als `decorLijst(kamer)`). Je
hoeft je knop dus niet meer aan een vreemd vast stuk te hangen met `dx`/`dz`
erbij. **Maar:** jouw decor bestaat alleen zolang jouw spel draait, en de
instapknop staat er juist als het spel **niet** draait — dan vindt de zoektocht
niets en haalt `hersteek()` de knop weg. Hang de instapknop daarom aan een
vast stuk en gebruik het decor-id alleen voor knoppen die je zélf in `start()`
maakt (of zet `hotspot.blijf: true` erbij):

```js
hotspot: { obj: 'kist', dx: KX - 95, dz: KZ - 23, icoon: '⏰' },   /* instap: vast stuk, staat er altijd */
ctx.hotspots.maak({ id: 'wk_klok', kamer: 'gang', x: KX, z: KZ, y: 34, … });  /* tijdens het spel: bij de klok zelf */
```

**Twee dingen om op te letten.** `World.mik(id)` vindt een decorstuk **als
laatste** (dieren, losse dingen, slots en vast decor gaan voor), dus kies ids
die daar niet mee botsen: niet `bed1`, `bak`, `tobbe`, `kar`. En dieren lopen
dwars door los decor heen (er is geen botsing), dus zet je stukken op plekken
waar ze toch niet komen — de wandrand, de tuinrand, een gereserveerde zone.
Gaat je modelfunctie stuk, dan kost dat alleen dít stuk zijn plaatje: er komt
één `console.warn` en de rest van het beeld wordt gewoon afgemaakt.

### Accessoires op een gast: hoedje, sjaaltje, bal

Voor de souvenirkraam: een gast koopt iets en draagt het zichtbaar tot het
uitchecken, in elke houding en in elke kamer.

```js
ctx.wereld.accessoire(id, 'hoedje');      // erbij, idempotent → lijst (kopie), of null
ctx.wereld.accessoires(id);               // → lijst (kopie, gefilterd); [] als hij niets draagt
ctx.wereld.accessoireWeg(id, 'hoedje');   // eraf → lijst (kopie), of null bij onbekende gast
```

* De namen zijn `'hoedje'`, `'sjaaltje'` en `'bal'` (ook op te vragen als
  `Art.ACCESSOIRES`). **Elke andere naam wordt gefilterd** en doet niets.
* Het staat **op het gastrecord**: `g.accessoires = ['hoedje', …]`. Dat gaat al
  mee in de opslag (v7), dus het staat er na "Verder spelen" weer; een oude save
  laadt als `[]`. Bij het uitchecken verdwijnt het record en dus ook de spullen.
* `id` mag ook de gast aan de balie zijn. Elke wijziging tekent de wereld
  opnieuw en bewaart zelf — je hoeft niets aan te roepen.
* **Nooit zelf `g.accessoires.push(...)` doen**: een verse gast deelt zijn lege
  lijstje met de gastenpool. De API zet er altijd een nieuwe lijst neer.

### Inrichten: bedden en meubels bijplaatsen (zonder `rooms.js` te openen)
```js
/* een bed kopen: dat is meteen een gast erbij, want bedden zijn de limiet */
var bed = ctx.wereld.voegBed('kamer2', { x: 52, z: 52 });   // of zonder plek
if (!bed) ctx.ui.toast('Daar past geen bed meer. Probeer een ander plekje. 💛', 'kind');
else ctx.ui.toast('Er staat een bed bij! Nu kan er nog een gast slapen. 🛏', 'happy');

/* gewone meubels */
var m = ctx.wereld.plaatsMeubel('kamer1', 'mandje', 40, 52);
ctx.wereld.verwijderMeubel(m.id);
ctx.wereld.kamerMeubels('kamer1');    // [{id, kamer, soort, x, z}]
```
Typen: **bed** (+1 gast), **bakje** (een voerbakje waar de voerkar in kan
scheppen), **mandje**, **speelmand**, **plant**, **badkuip**.

Wat er automatisch gebeurt:
* het meubel gaat door dezelfde afleiding als de vaste inrichting, dus een
  dier kan er meteen naartoe lopen (sta-plek, vrije vakjes en dwaalplekken
  worden opnieuw bepaald);
* een plek die al bezet is wordt naar het dichtstbijzijnde vrije vakje van het
  vloerraster geschoven; past er niets, dan komt er `null` terug — nooit een
  half neergezet meubel;
* een bed erbij verhoogt meteen `ctx.state.maxGasten()`, dus de bel laat een
  gast extra binnen;
* alles wordt bewaard in de opslag (v7) en staat na "Verder spelen" weer op
  zijn plek. Je hoeft zelf niets te onthouden. Verbouwt een ticket een kamer
  (K1 maakte de vier speelkamers 1,5× groter), dan schuiven bewaarde meubels
  mee in de migratie in `state.js` — jij hoeft er niets voor te doen.

### `ctx.hotspots` — knoppen en sleep-doelen IN de wereld
```js
ctx.hotspots.maak({
  id: 'tobbe_kraan',        /* uniek */
  kamer: 'tuin',            /* alleen zichtbaar in die ruimte */
  x: 32, z: 94, y: 8,       /* wereldplek in voxels (y = hoogte) */
  icoon: '🚰', label: 'Kraan',
  badge: '3',               /* klein rondje rechtsboven (optioneel) */
  kind: 'drop', drop: 'tobbe',   /* maakt er een sleep-doel van */
  data: { kant: 'links' },  /* wordt data-h-kant="links" op de knop */
  klas: 'hotkar',           /* extra css-klasse (optioneel) */
  prio: 8,                  /* hoger = blijft staan als het te vol wordt */
  volg: function () { return { x: 30, z: 90, y: 8 }; },  /* beweegt mee */
  aan: function (spot, ev) { /* tik */ }
});
ctx.hotspots.weg('tobbe_kraan');
ctx.hotspots.wisAlles();                      /* alles van jou weg */
ctx.hotspots.pak('bak_kamer1_bak', function () { ... });  /* knop van het hotel lenen */
ctx.hotspots.bron('zak', { icoon: '🍪', aantal: 12, hand: 2,  /* sleepbron mét teller */
  sleep: { dropSel: '[data-drop="vak"]', onDrop: function (t) { ... } } });
ctx.hotspots.laat();                          /* weer teruggeven */
```
* Maximaal **±16 knoppen per kamer**; daarboven verdwijnen de knoppen met de
  laagste `prio`. Houd het rustig: een kamer is geen knoppenpaneel.
* `pak(id, fn)` leent tijdelijk een bestaande knop van het hotel. De voerkar
  doet dat met het bakje: zolang de kar vol is, betekent een tik op het bakje
  "hier afleveren" in plaats van "vertel wat er moet". `stop()` geeft alles
  automatisch terug.

### `ctx.sleep(node, opts)` — slepen met vinger, pen of muis
Precies het bestaande `makeDraggable`:
```js
ctx.sleep(el, {
  dropSel: '[data-drop="vak"],[data-drop="deur"]',
  ghostHTML: function () { return '<div>🍪</div>'; },
  canDrag: function () { return K.zak > 0; },
  onDrop: function (doel) { ... },     /* doel = het element onder je vinger */
  onTap: function () { ... }           /* kleine beweging = tik */
});
```
Werkt óók van het rekenblad náár de wereld (kaartje op een bed) en van de wereld
naar de wereld (de voerkar op een deur), want de hotspot-laag is gewoon DOM.

### `ctx.state` — de stand van het hotel (= het globale `State`)
| aanroep | geeft |
|---|---|
| `N()` | aantal gasten dat nu in het hotel slaapt |
| `band()` | 3, 4 of 5 (groep 3/4/5) — al begrensd door het adaptieve signaal |
| `dag()` | dagnummer |
| `sommen.deel(N, band, dag)` | `{T, k, r}` met **T = k·N + r** |
| `sommen.geld(band[, nachten, prijs])` | `{nachten, prijs, totaal, betaald, wissel}` |
| `sommen.klok(band)` | `{u, m, stap, duur?, tekst}` |
| `sommen.tafel(band)` | `{a, b, uit, tafels}` |
| `tel(goed, ms)` | meld één item aan het adaptieve signaal |
| `gasten()`, `gast(id)`, `gastenIn(kamer)` | de gasten |
| `bedden()`, `bedVrij()`, `gastInBed(k, s)`, `maxGasten()` | de bedden |
| `munten()`, `sterren()`, `munt(n)`, `ster(n, waarvoor)` | de economie |
| `gezien(k)`, `zetGezien(k)` | is deze uitleg al eens gezien? |
| `bewaar()` | opslaan (v7) |
| `ruw()` | het hele `state`-object (mag je lezen; schrijf alleen in je eigen laatje) |
| `spelData(id)` | jouw eigen laatje in de opslag |

`ctx.data()` is de korte vorm van `ctx.state.spelData(<jouw id>)`: een object dat
automatisch mee wordt bewaard en na "Verder spelen" weer terug is.

### `ctx.ui` — het rekenblad (= het globale `Ui`)
| aanroep | doet |
|---|---|
| `paneel(html, klas)` | zet je rekenblad onder (portret) of naast (liggend) de kamer |
| `leegPaneel()` | paneel weg, kamer blijft |
| `pad({max, euro, eenheid, onOk})` | cijfertoetsenbord: `p.html()`, `p.wire(root, herteken)`, `p.getal()`, `p.wis()` |
| `telMee(stap, aantal, staart)` | `"5 … 10 … 15."` — samen tellen |
| `telRij(n, icoon)` | rijtje losse dingen om na te tellen |
| `getallenlijn(van, tot)` | getallenlijn met roze stapjes |
| `voorbeeld({titel, intro, regels, slot, telmee, onOk})` | buurvrouw Els doet het één keer voor |
| `hulpNa2s(fn)` | **alleen voor memoriseer-items**: na 2 s hulp aanbieden; geeft een afzeg-functie terug |
| `wolk(obj, o)` / `wolkWeg(id)` | **spreekwolkje aan een voorwerp of dier** (zie §6) |
| `somkaart(obj, som, o)` | **sommenkaartje met verankerd cijferpad** (zie §6) |
| `bron(obj, o)` | sleepbron met teller (ook via `ctx.hotspots.bron`) |
| `spreek(tekst)` | voorlezen met de stem van het apparaat; alleen ná een tik |
| `chip`, `woord`, `hoofd`, `esc`, `toast`, `sheet`, `sluit`, `nu` | kleine dingen |

Het paneel gebruikt de bestaande schoolschrift-stijl: zet je som in
`<div class="qbox">` of `<div class="opdracht">` (gelinieerd papier met kantlijn),
een goed antwoord in `<div class="good">`, hulp in `<div class="soft-note">`.
Bakjes/vakjes: `<div class="bowl" data-drop="...">`, knoppen: `<button class="btn">`.

### `ctx.econ` — munten
`buidel(n)` (munten waarmee élk bedrag t/m n precies te leggen is), `splits(n)`,
`munt(waarde, extra, id)` (html), `som(lijst)`, `sterren(n)`,
en `rekening({gast, fam, nachten, prijs, totaal, betaald, onKlaar})` — het
complete afrekenmoment met toonbank, samen tellen, wisselgeld en spookmunten.

### `ctx.snd` — geluid
`tik, plop(hand), terug, zacht, ja, tover, dag, brief, hoera, bel, deur, kar, munt, ster`
en voor golf 3:

| naam | bedoeld voor |
|---|---|
| `plons` | een dier gaat het water in (start van een zwembeurt) |
| `au` | een zachte bots tegen de badwand — laag, kort en rond, **nadrukkelijk geen schrikgeluid** |
| `klok` | de halklok slaat één keer (de wekker goed gezet) |
| `hup` | één sprong naar de volgende steen (hinkelpad) |

Er bestaan geen boze geluiden. `zacht` is "dat is het nog niet", nooit een
fout-buzzer. Alle geluiden zijn `Snd.<naam>()`: geen argumenten, geen
bestanden. Roep ze nooit in een lus per beeld aan.

De geluidsband gaat **pas open na de eerste echte aanraking** van het kind (dat
eist de browser). Vóór die tik doet elk geluid niets — geen waarschuwing, niets
stuk. `ctx.snd.ontgrendeld()` zegt of de band al open is, `ctx.snd.dempt()` of
de speakerknop uit staat. Je hoeft er niets voor te doen: roep je geluid
gewoon aan.

### `ctx.taakKlaar(naam, {sterren})` en `ctx.sluit()`
`taakKlaar` geeft een ster voor het **meedoen**, vinkt het taakje op het prikbord
af en bewaart het spel. Roep hem aan als het kind klaar is — hoe vaak het ook
geprobeerd heeft. `sluit()` sluit je spel netjes af (roept jouw `stop()` aan).

### Alleen voor wie aan de motor bouwt: `window.CTX_UITBREIDINGEN`

Niet alles in `ctx.wereld` komt uit `games/registry.js`. Een motorbestand dat
iets nieuws aanbiedt, hangt dat bij het laden zelf aan de ctx:
`(window.CTX_UITBREIDINGEN = window.CTX_UITBREIDINGEN || []).push(function (ctx, eigen) { ctx.wereld.iets = …; })`.
`registry.js` laat die lijst één keer per spel over de verse ctx lopen (`eigen`
is de naam van het spel, voor eigenaarschap van hotspots en decor), dus de
stekkerdoos hoeft niet mee te veranderen als een module iets toevoegt. Zo komen
`decor`/`decorWeg`/`decorLijst`/`decorWisAlles` en `loopNaar`/`stappen`/`pose`
uit `world.js` en de accessoires uit `art.js`. **Voor een spelbouwer verandert
dit niets**: alles staat gewoon op je `ctx`. Bouw je aan de motor, dan is dit de
plek — nooit een regel in `registry.js`.

---

## 3. Spelregels waar we ons aan houden

1. **Nooit een rood kruis.** Een fout antwoord levert een zachter geluid en een
   hulpkaartje op ("tel maar mee: 5 … 10 … 15"), nooit straf. Na 2–3 pogingen
   doet buurvrouw Els het één keer voor (`ctx.ui.voorbeeld`) of komen er
   spookvormen te liggen.
2. **Sterren voor meedoen, munten uit het uitchecken.** Sterren hangen niet aan
   goed rekenen.
3. **Geen tijdsdruk.** Geen aftelklok, geen energie, geen streak. Alleen
   *memoriseer*-items (splitsingen t/m 10, tafels) mogen `hulpNa2s` gebruiken, en
   dat bepaalt uitsluitend of er hulp verschijnt — nooit of het antwoord telt.
4. **Curriculum (zie IDEAS.md).** Groep 4 kent alleen de tafels 1, 2, 3, 4, 5 en
   10 — `7 × 8` is groep 5. Geen komma-notatie en geen centen vóór groep 5; geld
   in hele euro's t/m €20 per betaling. Geen cijferen vóór groep 5.
5. **Eén schaalregel:** je getallen komen uit `ctx.state.sommen.*`, dus uit N en
   de band. Verzin geen eigen moeilijkheidsladder.
6. **Alles in het Nederlands**, tegen het kind in de jij-vorm, warm en kort.
7. **Tikdoelen minstens 48 px**, werkt staand en liggend, met vinger of muis.
8. **Geen externe bestanden, geen netwerk.** Alles moet vanaf `file://` werken.

---

## 4. De hotspot-laag en de tekenvolgorde (belangrijk!)

De wereld is een isometrisch diorama: alles wordt getekend van achter naar voren,
gesorteerd op `x + z`. De knoppenlaag `#worldHits` krijgt **exact dezelfde
volgorde** in zijn `z-index`. Daardoor pakt een tik altijd het voorwerp dat je
vooraan ziet staan, ook als twee dingen in isometrie op precies dezelfde pixel
belanden (HOTEL.md, open beslissing 5).

Tijdens het camera-schuiven (300 ms van kamer naar kamer) staan de knoppen
alvast stil op hun eindplek. Een kind dat halverwege de beweging tikt, raakt
dus gewoon het goede voorwerp — er gaat nooit een tik verloren.

Bovendien schuift de laag knoppen die elkaar zouden **afdekken** uit elkaar:
van voor naar achter, in stappen van een hele knop naar boven (net als de
naamplaatjes), en altijd binnen het kader. Elke knop blijft dus apart aan te
tikken, ook als de kamer krap in beeld staat. Liggen twee knoppen tóch precies
op elkaar, dan pakt de voorste de tik.

Wat dat voor jou betekent:
* Geef je hotspot de **wereldplek van het voorwerp** (`x`, `z`, `y`) en niet een
  zelfbedachte schermpositie. De laag rekent zelf uit waar dat op het scherm is
  en welke `z-index` daarbij hoort.
* Beweegt je voorwerp? Geef dan een `volg()` mee die de nieuwe plek teruggeeft.
* Ga **nooit zelf** aan `style.zIndex` of `style.transform` van een hotspot
  zitten; dat breekt de tik-volgorde.
* Kijk of er al een knop van het hotel op jouw voorwerp ligt (de speelmand, het
  bakje, een vrij bed en de bel hebben er één). Ze worden dan wel netjes uit
  elkaar geschoven, maar het leest rustiger als je zelf een ander voorwerp,
  een andere `hoog`, of een `dx`/`dz` kiest — of die knop leent met
  `ctx.hotspots.pak()`.
* Zolang jouw spel loopt haalt de stekkerdoos jouw eigen icoontje weg: het
  voorwerp is dan van jou (bijvoorbeeld de voerkar, die zijn eigen "duw mij"-
  knop neerzet). Wil je het icoontje toch laten staan, zet dan
  `hotspot.blijf = true`.
* In isometrie liggen dingen snel over elkaar heen. Op het scherm geldt met
  `k = ctx.wereld.schaal().k` (css-px per voxel-px; 0,58 op een kleine telefoon
  tot 2,0 op een laptop, en sinds K1 **per kamer verschillend**):
  **horizontaal ≈ (x − z) × 2k px**, **verticaal ≈ (x + z − 2·y) × k px**. Een knop is ~50–70 px breed en 48 px hoog, dus twee
  knoppen staan pas echt naast elkaar als hun `x − z` zo'n **50/(2k) voxels**
  verschilt (≈ 30 bij k = 1, ≈ 43 op de kleinste telefoon), of hun
  `x + z − 2y` zo'n **50/k**. Zet je voorwerpen dus uit elkaar, of verdeel ze
  over twee richtingen (zoals de L-vormige balie in de receptie).
  Reken het even na vóór je vier knoppen op één tafel legt: staat er een knop met
  een grotere diepte bovenop, dan gaat de tik dáárheen — dat is de bedoeling van
  de regel, maar het voelt als een bug in je spel.
* Zet vaste plekken in je spel **niet** in losse voxels neer maar als breuk van
  de kamer: `Rooms.plek(kamerId, fx, fz)` geeft `{kamer, x, z}` en
  `Rooms.hoogte(kamerId, f)` een hoogte (y) die met de kamer meeschaalt. Wordt
  een kamer verbouwd (K1: de receptie ging van 80 × 80 naar 120 × 120), dan
  schuift jouw opstelling automatisch mee en blijven de afstanden op het scherm
  gelijk — een 1,5× grotere kamer bij een 0,78× kleinere `k` geeft zelfs iets
  méér lucht tussen de knoppen. `games/sleutels.js` en `games/voerkar.js` zijn
  hiervan het voorbeeld.

### En nog iets over portret
In portret staat je rekenblad **onder** de kamer. Wil je iets van het blad naar
een hotspot in de wereld slepen (zoals het gastkaartje op een bed), zet dat
sleepbare ding dan **bovenaan** je paneel — anders staat het onder de onderrand
van het scherm en kan een kind er niet bij. Liggend staat het blad naast de
kamer, dan is alles altijd samen in beeld.

---

## 5. Voorbeeld van begin tot eind: `games/voerkar.js`

De voerkar is de referentie-implementatie en gebruikt alles hierboven:

| stap | in de code |
|---|---|
| Aanmelden op de kar in de keuken | `Games.register({ id:'voerkar', kamer:'keuken', hotspot:{obj:'kar', icoon:'🛒'} })` |
| Getallen ophalen: T = k·N + r | `C.state.sommen.deel(g.length, C.state.band(), C.state.dag())` |
| Toestand bewaren over sessies heen | `C.state.ruw().kar` (eigen laatje: `C.data()`) |
| Rekenblad opbouwen | `C.ui.paneel(h, 'voerkar')` met `.bag`, `.bowl`, `.jarwrap` |
| Koekjes slepen uit de zak | `C.sleep(zak, { dropSel:'[data-drop="vak"]', ... })` |
| Vriendelijke controle | `check()`: eerst "er zit nog X in de zak", dan per vakje "nog 2? 🥺" |
| Els doet het voor na 2 pogingen | `C.ui.voorbeeld({ regels: ..., telmee: C.ui.telMee(...) })` |
| Ster + taakje af + opslaan | `C.taakKlaar('voer', { sterren: 1 })` |
| De kar wordt zelf een hotspot | `C.hotspots.maak({ id:'karhot', volg: ... })` |
| Kar op een deur slepen | `dropSel:'[data-drop="deur"],[data-drop="bak"]'` → `C.wereld.dingZet('kar', {kamer})` |
| Bakje van het hotel lenen | `C.hotspots.pak('bak_'+kamer+'_'+slot, function(){ lever(...) })` |
| Eigen gegevens op een knop | `data: {kamer:..., slot:...}` → lees ze met `t.getAttribute('data-h-kamer')` |
| Dieren laten smullen | `C.wereld.setBak(kamer, slot, 4)` + `C.wereld.feest(ids)` |
| Overgeslagen kamer blijft zichtbaar | het bakje houdt `🍽 Leeg` met een `!`-badge — nooit een kruis |

---

## 6. Rekenen ín de wereld (HOTEL.md §9) — VERPLICHT voor nieuwe games

Uit de speeltest van het fundament: rekenpanelen naast het diorama voelen als
"een website naast het spel", en er staat te veel tekst. Daarom:

* **Geen rekenblad meer naast de wereld.** Sommen, aantallen en keuzes hangen
  aan een voorwerp of dier. `ctx.ui.paneel` blijft alleen voor het startblad en
  een overzicht als het meubelboek — niet voor sommen.
* **Elke sommenkaart draagt één gewone zin** (`regel`, VERPLICHT, ≤ 8 woorden
  **én ≤ 40 tekens**, met een werkwoord of een vraagwoord, pictogram vooraan op
  dezelfde regel). Op één regel past ongeveer **34 tekens** (gemeten op 420 en
  860 px breed); 35-40 tekens wordt een tweede regel. Op een smalle telefoon
  (kader < 360 px) is het kaartje 170 px en breekt élke zin af naar twee
  regels - anders staat de kaart over het dier heen. Het cijferpad krijgt daar
  toetsen van 44 px (elders 48). Schrijf je
  meer, dan waarschuwt de console. Een kale som ("4 × 2", "🪑 + 🛋 =") staat er
  nooit zonder zin. Feedback blijft pictogram + getal ("nog 2 🍪").
  *Herzien 2026-09-03 na speeltest: een kind van zes kon "4 × 2 ? 20" niet
  lezen. Een "?" tussen twee uitdrukkingen mag daarom niet meer.*
* **Keuzes zijn knoppen mét woord** (`keuzes`), in één strook aan het kaartje -
  nooit alleen een pictogram, nooit los verspreid door de kamer.
* **Slepen gebeurt in de wereld**: koekjes uit de zak naar de bakjes, munten uit
  de buidel naar de toonbank, sleutels naar de haakjes.
* **Het cijferpad is het enige 2D-ding** en hangt klein aan het voorwerp.

Je hoeft nooit een eigenaar (`door`) mee te geven: alles wat je via `ctx.ui`,
`ctx.hotspots` of `ctx.wereld` in de wereld zet staat automatisch op naam van
jóuw spel, en `stop()` ruimt het allemaal weer op — wolkjes, sommenkaartjes,
cijfers op voorwerpen en sleepbronnen.

```js
/* spreekwolkje aan een dier of voorwerp. Zelfde tekstbudget als de zin op een
   sommenkaart: tot ~34 tekens staat de tekst naast het pictogram op één regel,
   35-40 tekens wordt een tweede regel. */
var id = ctx.ui.wolk('boef', { icoon: '🍪', getal: 2, tekst: 'nog twee',
                               hoog: 52,          /* voxels boven het object */
                               tik: function () { ... } });   /* zonder tik: voorlezen */
ctx.ui.wolkWeg(id);

/* sommenkaartje met verankerd cijferpad.
   `regel` is de zin boven de som en is VERPLICHT; `icoon` staat vooraan op
   diezelfde regel (dus niet als eigen wolkje ernaast). */
var kaart = ctx.ui.somkaart('kassa', '3 × €2 =', {
  regel: 'Muis wil 3 zakjes, €2 per zakje',   /* VERPLICHT: ≤ 8 woorden, ≤ 40 tekens */
  icoon: '🛍',           /* vooraan IN de zin, zelfde regel */
  open: true,            /* pad meteen open */
  max: 2,                /* hoeveel cijfers */
  pad: false,            /* of juist géén pad: alleen de zin en de som */
  onOk: function (n, k) { if (n === 6) k.zet(n).klaar(); else k.hulp('2 … 4 … 6'); }
});
kaart.zet('6');  kaart.hulp('2 … 4 … 6');  kaart.klaar();  kaart.weg();

/* twee korte regels mogen als er nog een getal bij hoort (bijvoorbeeld de
   voorraad). Meer dan twee niet: een kaartje is geen lap tekst. */
ctx.ui.somkaart('bel', '4 × 2', {
  icoon: '🍽',
  regel: ['We eten 4 dagen lang 2 scheppen', '📦 In huis: 20 scheppen. Genoeg?'],
  /* `keuzes` = één strook knoppen MÉT woord, tegen de onderrand van de kaart.
     Met keuzes heeft de kaart geen antwoordvakje en geen cijferpad. */
  keuzes: [
    { id: 'meer',    icoon: '⬇', tekst: 'te weinig',   kies: function () { ... } },
    { id: 'precies', icoon: '⚖', tekst: 'precies',     kies: function () { ... } },
    { id: 'minder',  icoon: '⬆', tekst: 'blijft over', kies: function () { ... } }
  ]
});

/* een cijfer ÓP een voorwerp, en weer weg */
ctx.wereld.getalTag('bak', 4);
ctx.wereld.getalTag('bak', null);

/* een sleepbron met teller (zak, buidel, kist).
   Eén tik levert precies ÉÉN keer: geef je geen sleep.onTap mee, dan komt de
   tik bij `tik` terecht; geef je er wel een, dan gebruikt hij die. */
var zak = ctx.hotspots.bron('zak', { icoon: '🍪', aantal: 12, hand: 2,
  tik: function (h) { ... },
  sleep: { dropSel: '[data-drop="vak"]', onDrop: function (t) { ... } } });
zak.zet(10, 5);       /* nieuw aantal, nieuwe handgreep */   zak.weg();

/* voorlezen: alleen als het kind zelf tikt */
ctx.ui.spreek('Hoeveel samen?');
```

Wat het fundament zelf al zo doet (kijk hier af):
| flow | in de wereld |
|---|---|
| check-in | ÉÉN sommenkaart vóór de balie (niet op de bel: daar staat de gast), met twee korte zinnen ("🥄 De gasten eten 0 scheppen per dag" / "Boef eet 2 erbij. Samen?") + som + pad; vraag 2 dezelfde kaart met één keuzestrook ("⬇ te weinig", "⚖ precies", "⬆ blijft over") |
| voerkar | de zak is een `bron`, de vakjes zijn **echte bakjes** op de keukenvloer met het aantal als cijfer, fout = wolkje "+2 🍪", Els legt spookcijfers neer |
| rekening | één werkkaart vóór de balie met de zin "🛏 Boef sliep 3 nachten, €5 per nacht"; het afgevinkte bonnetje ligt op de kassa terwijl je munten telt en gaat weg bij de wisselgeldvraag (twee kaartjes passen niet in een liggend kader van 200 px) |
| prikbord | maximaal 3 taakkaartjes bij het bord, pictogram + ≤ 6 woorden |

### Nog een paar handigheidjes

```js
/* hoe groot is een voxel op dit scherm? (voor een eigen rij of raster)
     css-x  ~  pxPerVoxelX * (x - z)
     css-y  ~  pxPerVoxelY * (x + z - 2y)                                  */
var s = ctx.wereld.schaal();     // {g, dpr, k, pxPerVoxelX, pxPerVoxelY, pxPerHoogte}
var stap = Math.ceil(56 / s.pxPerVoxelX);   // ~56 px tussen twee knoppen

/* een wens van een gast vervullen (eten -> gegeten, bad/spelen -> blij) */
ctx.wereld.behoefteKlaar(gast.id);            /* huidige wens */
ctx.wereld.behoefteKlaar(gast.id, 'bad');     /* of een specifieke */

/* een cijfer dat beslist moet blijven staan als de kamer vol knoppen zit */
ctx.wereld.getalTag('bak', 4, { prio: 12 });

/* de zin boven de som vervangen (string of twee korte zinnen) */
kaart.regel('Muis wil er nog 2 bij');
kaart.regel(['Muis eet 3 koekjes', 'In de zak: 9']);

/* alleen de SOMREGEL vervangen, kaart, pad en keuzestrook blijven staan.
   LET OP: dit heette vroeger kaart.regel(); die naam is nu de zin erboven. */
kaart.som('5 + 5 =');
```

### Een taakje op het prikbord
Een geregistreerd spel mag zeggen wanneer het op het prikbord hoort:

```js
Games.register({
  id: 'sleutels', ...,
  taak: {
    icoon: '🔑',
    tekst: 'Hang de sleutels op',            /* of function (state) { return ...; } */
    wanneer: function (state) { return state.gasten.length >= 2; },
    id: 'sleutels',      /* optioneel: eigen naam voor het kaartje */
    prio: 5              /* lager = eerder; wensen van dieren staan op 0 */
  }
});
```
Zeg je niets, dan gebruikt het hotel een standaard uit `SPEL_TAAK` in
`hotel.js`. Die tabel komt uit golf 1–2 en heeft een regel voor vijf spellen
(`voerkar`, `tobbe`, `bedden`, `sleutels`, `meubels`); de spellen van golf 3
(zwembad, wekker, hinkel, was, kraam) staan er niet in en zeggen hun taakje dus
zelf met `taak`. `ctx.taakKlaar()`
zet het vinkje: dat werkt op de naam die je meegeeft **en** op de id van je
spel, dus `ctx.taakKlaar('bad')` en `ctx.taakKlaar()` vinken allebei het
juiste kaartje af. Een afgevinkt kaartje blijft de rest van de dag met een
vinkje staan; morgen begint het bord leeg. Er staan er nooit meer dan drie, en
de wensen van de dieren gaan voor.

Zodra je spel start doet het hotel het prikbord automatisch dicht, zodat de
taakkaartjes niet over jouw knoppen heen staan.

Twee dingen om op te letten:
* Zet je wolkjes en kaartjes niet allemaal op hetzelfde voorwerp: de laag schuift
  ze dan uit elkaar (dat mag, maar het leest rustiger als je ze zelf spreidt).
* Een `somkaart`, zijn pad en zijn keuzestrook staan **vast**: ze wijken niet uit
  voor andere knoppen, andere knoppen wijken voor hén. Gebruik er dus hooguit
  één tegelijk.
* Vergeet je `regel`, dan tekent de kaart wél (je spel breekt nooit halverwege),
  maar er komt één `console.warn` per kaartje: *"somkaart … heeft geen regel"*.
  Datzelfde gebeurt bij een zin van meer dan 8 woorden of 40 tekens. Een speeltest of
  nakijkronde ziet zo meteen welk kaartje nog een zin mist.
* Het pad komt automatisch ónder de kamer terecht (het kader is daar hoger dan
  de kamer zelf), dus het dekt de vloer niet af. Zet er zelf geen `padHoog` op
  tenzij je het echt ergens anders wil.
* Een `getalTag` is een cijfer, geen knop: niet aan te tikken, niet te
  focussen. Wil je dat er iets gebeurt bij een tik, gebruik dan een hotspot,
  een `wolk` of een `bron`.
* Eén ladder voor hulp, overal hetzelfde: 1e poging samen tellen, 2e poging nog
  eens, en pas bij de **derde** poging spookvormen (zoals de winkel van
  Zilverhoef).
* Een `wolk` of `bron` aan een **dier** loopt met het dier mee, ook naar een
  andere kamer: hij is alleen zichtbaar in de ruimte waar het dier op dat
  moment is. Je hoeft er zelf niets voor te doen.

## 7. Nog niet af (bewust uitgesteld)

Dit bestaat nog niet; bouw het niet stiekem in een gedeeld bestand, maar vraag
erom als je het nodig hebt:

* **Geen algemene `Econ.betaal(prijs, onKlaar)`.** Er is alleen
  `Econ.rekening(...)` voor het uitchecken; het meubelboek stelt zijn eigen
  betaalmoment samen uit `Econ.buidel/splits/munt` plus `ui.somkaart` en een
  `bron`. Een gedeelde betaalflow komt pas als een tweede spel hem nodig heeft.
* **Geen halveer/verdubbel-generator in `sommen`.** Er is `deel`, `geld`,
  `klok` en `tafel`; verdubbelen/halveren/splitsen rekent een spel voorlopig
  zelf uit (binnen de band-plafonds van HOTEL.md 3).
* **Eén kamer past ongeveer drie rijen bedden.** Een array van 7 × 6 (band 5)
  past niet in één kamer: gebruik twee kamers of wacht op een groter kamertype.
* **Geen sierlijke meubeltypen.** `plaatsMeubel` kent nog steeds alleen bed,
  bakje, mandje, speelmand, plant en badkuip. Wil je iets anders in beeld
  zetten, gebruik dan geen meubel maar je **eigen decorstuk** (§2): dat is
  precies waar `Rooms.registerModel` + `ctx.wereld.decor` voor zijn. Verschil:
  een meubel is blijvend, gaat mee in de opslag en verandert de sta- en
  dwaalplekken van de dieren; een decorstuk is van jouw spel, wordt niet
  bewaard en is voor de dieren niet meer dan een plaatje.

## 8. Testen

```
node --check games/jouwspel.js
```
en spelen vanaf `file://.../demos/dierenhotel/index.html`. De speeltests van het
fundament staan in `.fanout/scratch/dierenhotel/` (`loop.js` = hele speelronde,
`regels.js` = curriculumregels en tikgrootte, `hotspots.js` = geen knop dekt een
andere af, ook de wolkjes en kaartjes niet (dpr 1 én 3), `plugin.js` = deze API, `perf.js` = 60 fps met 12 dieren).
Kopieer die aanpak: laden → spelen → geen console-fouten → herladen → verder.

## 9. Op de telefoon

Het spel moet op een échte telefoon werken, staand én liggend. Dit is wat dat
voor jouw spel betekent.

### Je knop staat bóven zijn voorwerp, niet erop

Een knop met pictogram + woord dekte het voorwerp helemaal af (de speelmand en
het bakje waren onvindbaar onder hun eigen knop). Daarom kiest de knoppenlaag
nu zelf een plek. Dat is `o.op` op `ctx.hotspots.maak`:

| `op` | plek van de knop |
|---|---|
| `'boven'` | net **boven** het voorwerp: het voorwerp blijft heel in beeld |
| `'onder'` | net **onder** de vloerpunt van het voorwerp |
| `'midden'` | precies op het mikpunt — het oude gedrag |
| `'rand'` | (cijfertags) net over de bovenrand; hooguit een tiende van het voorwerp gaat schuil |
| `'auto'` | **de standaard**, zie hieronder |

`'auto'` kiest `'rand'` voor een cijfertag, `'midden'` voor een vaste kaart
(sommenkaart, cijferpad, keuzestrook), voor een plek zonder voorwerp (`y ≤ 0`),
voor een knop met eigen `html` en voor een wolkje of kaartje — en anders
`'boven'`. Die laatste twee regels zijn de rem: **rekent jouw spel zijn knop
zelf in schermpixels uit, dan houdt het zijn eigen opmaak.** Wil je de nieuwe
plaatsing tóch, zet er dan `op: 'boven'` bij; wil je een piepklein voorwerp
juist wél onder je knop, dan `op: 'midden'`.

Past een knop niet meer boven het voorwerp binnen het kader, dan wordt
`'boven'` stil `'onder'`. Dekken knoppen elkaar af, dan wijken ze uit — eerst
omhoog en opzij, dan alle kanten, en in een echt krap kader **stapelen** ze rij
voor rij vanaf de bovenrand. Een knop die een ándere knop afdekt is erger dan
een knop die een hoekje van zijn voorwerp afdekt. `Hits.debug().spots[].op`
vertelt wat het geworden is.

**Slepen blijft naar het voorwerp gaan.** De knop staat boven het bakje, maar
een kind sleept naar het bakje. Voor elke hotspot met `drop` die boven of onder
zijn voorwerp staat legt de laag daarom een doorzichtig **vangvlak** over knop
én voorwerp, met dezelfde `data-drop` en `data-h-*`. Dat vlak ligt in een eigen
laagje ónder de knoppen, dus een echte knop pakt altijd voor en `Hits.watRaakt`
ziet er niets van; een tik op het vlak doet hetzelfde als een tik op de knop.
Je hoeft er niets voor te doen — geef je hotspot gewoon zijn `drop`.

Ruim je zelf iets op als een hotspot verdwijnt (een luisteraar bijvoorbeeld),
gebruik dan `onWeg(spot)` op `ctx.hotspots.maak`: die gaat één keer af, vóór het
element uit de pagina gaat, ook bij `wisAlles()`.

### Het cijferpad kan als strook ónder het kader komen

Op een laag of smal kader lag het cijferpad midden ín de kamer. `Ui.somkaart`
heeft daarom `padPlek`: `'auto'` (de standaard — ín het kader, behalve als het
kader lager is dan 300 px of te smal voor één rij toetsen; dan als strook
eronder), `'binnen'` (altijd in het kader) of `'buiten'` (altijd de strook).
Je handvat verandert niet: `.regel()`, `.som()`, `.zet()`, `.hulp()`, `.open()`,
`.klaar()` en `.weg()` doen precies wat ze deden, en `klaar()`/`weg()` ruimen de
strook mee op.
De toetsen zijn ook altijd op dezelfde manier te vinden
(`[data-hot="<kaart-id>_pad"] [data-pk="7"]`), waar het pad ook staat.

Er is **één** strook. Zetten twee kaarten hun pad tegelijk buiten, dan neemt de
laatste hem over: houd dus hooguit één cijferpad open, of zet
`padPlek: 'binnen'` op de andere.

### Reken niet op `resize`, maar op één kadermelding

Alles wat je in **schermpixels** uitmeet (een rij, een raster, een eigen
plaatsing) moet opnieuw gelegd worden als het kader van maat verandert.
Gebruik daar `ctx.ui.opKader(fn)` voor; die geeft een opzegfunctie terug:

```js
var stopKader = ctx.ui.opKader(function () { legOpnieuw(); });
/* in stop(): */  stopKader();
```

`ctx.ui.opKader` hangt onder water aan de **opmaat-bus** van `world.js`. Bouw je
aan de motor, dan gebruik je die rechtstreeks:

| aanroep | wat het doet |
|---|---|
| `World.onKader(fn)` | aanmelden; geeft de **afmeldfunctie** terug. `fn({x, y, w, h}, schaal)` krijgt de kaderrechthoek in css-px en precies wat `World.schaal()` geeft, plus `schaal.kamer`. Hij gaat **niet** meteen af bij het aanmelden. |
| `World.kader()` | `{x, y, w, h}` van het kader uit de cache van de bus (geen layout-leesbeurt), of `null` |
| `World.hermeet()` | zelf een meting afdwingen; normaal doet de waarnemer dat |

Eén `ResizeObserver` op het kader, één wachtje van 120 ms, één signaal — en de
bus slaat alleen als er echt iets veranderd is. Een luisteraar die stukgaat
sleept de rest niet mee (één `console.warn`). **Meld je altijd af** als je laag
weggaat, anders houdt de bus je functie vast.

> **Let op het verschil:** `World.vuil()` vraagt alleen een nieuwe tekenbeurt
> met de huidige maat; **`World.hermeet()` meet het kader opnieuw op**. Verandert
> de schil boven of onder het kader (een balk erbij, een paneel dat open gaat),
> dan hoort daar `hermeet()` achter, niet `vuil()`. Vóór M1b deed `vuil()` beide.

Hang geen eigen `window.addEventListener('resize', …)` meer op. Verder pauzeert
de wereld zichzelf zodra het tabblad weg is (geen tikken, geen tekenbeurten,
geen batterij) en tekent hij bij terugkomst één keer opnieuw — een belofte van
`stappen` valt dus pas als het spel weer in beeld is.

Hoe je in schermpixels rekent staat in §4: `World.vloer()` geeft de achterhoek
van de kamer in css-px, `ctx.wereld.schaal().k` het aantal css-px per voxel, en
`scherm-x = px0 + (x − z)·2k`, `scherm-y = py0 + (x + z − 2y)·k`. Meet de echte
maat van je kaartje of knopje pas **ná één tekenbeurt** (`offsetWidth`), houd
minstens `(h1 + h2) / 2` px tussen twee knoppen — daaronder schuift de laag ze
uit elkaar en is je rij geen rij meer — en reken om alles heen wat `vast` is
(een sommenkaart en zijn cijferpad kiezen als eerste hun plek en wijken nooit).
`games/sleutels.js` doet dit voor drie kaderhoogtes en is het voorbeeld.

### Verder op een telefoon

* **Tekst is nooit kleiner dan 12 px.** De opmaak legt die bodem op de labels,
  badges, wolkjes, sommenzinnen en naamplaatjes. Zet je zélf een
  `style="font-size:…"` in de html van je knop, dan geldt die bodem daar niet:
  dan is het jouw bestand dat het te klein maakt.
* **Tikdoelen minstens 48 px** (44 px onder de 360 px schermbreedte), met de
  vinger én met de muis. Een pictogram staat altijd in hetzelfde wolkje als
  zijn woord of getal (HOTEL.md §9): nooit een pictogram alleen, nooit los
  verspreid door de kamer, en geen uitleg die gelezen moet worden — voordoen.
* **Slepen met de vinger** tilt het sleepplaatje 40 px boven de vingertop en
  meet het doel op díe plek, zodat het kind ziet wat het vasthoudt. Eén tik
  levert precies één keer (de na-klik van de browser wordt opgegeten), en het
  vasthoud-menu ("Kopiëren / Delen") is op een sleepbron uitgezet. Met muis of
  pen blijft alles zoals het was. Je hoeft hier niets voor te doen: dat zit in
  `ctx.sleep`.
* **Op een smalle telefoon** (kader < 360 px) is de sommenkaart 170 px, breekt
  élke zin af naar twee regels en zijn de cijfertoetsen 44 px. Reken daar dus
  niet op één regel.
* **Liggend onder 450 px hoog** wordt de schil compact: de balken worden één
  rij en de kamerbalk staat als blokje van 3 × 3 chips náást het kader. Er is
  dan minder hoogte dan je denkt — kijk of je opstelling ook in ~190 px past.

### Deze drie suites zijn de keuring

```
node mobiel.js            # acht telefoonprofielen: schil, tikken, slepen, geluid
node mobiel-perf.js       # kadermaat, dichtheid, tekenwerk, luisteraars (M1b)
node hits-plaats.js       # geen knop dekt zijn voorwerp of een andere knop af
```

Ze staan in `.fanout/scratch/dierenhotel/` en hangen in `alles.sh`. Een spel is
pas af als het daar doorheen komt, niet alleen op een laptop.
