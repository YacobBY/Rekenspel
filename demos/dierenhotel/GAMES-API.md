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
(de vier plaatshouders `bedden.js`, `sleutels.js`, `tobbe.js` en `meubels.js`
staan er al — vervang gewoon je eigen bestand).

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
| `reis(id, kamerId, {x,z,na})` | loop dóór de deuren naar een andere ruimte |
| `slaap(id, kamerId, slotId)` | in bed leggen (loopt er zelf naartoe) |
| `setMood(id, m)` | `'blij'`, `'droopy'`, `'bouncy'` (via art.js) |
| `setFood(id, n, per)` | vult het bakje van de kamer waar dat dier is |
| `setBak(kamerId, slotId, 0..4)` / `bakStand(...)` | bakje rechtstreeks vullen / uitlezen |
| `feest(ids)` | lopen → eten → blij spelen (de complete smulanimatie) |
| `solo(id, act)` | vignet: dit dier gaat op een vrije plek zijn ding doen |
| `ding(sleutel)` / `dingZet(sleutel, {kamer,x,z,y})` | los voorwerp opvragen / verzetten (de voerkar) |
| `vuil()` | zeg dat het beeld opnieuw getekend moet worden |
| `voegBed(kamerId, {x,z,rot})` | **een bed erbij** → de plek, of `null` als het niet past |
| `plaatsMeubel(kamerId, type, x, z, rot)` | meubel neerzetten → `{id,kamer,type,x,z,rot,soort}` of `null` |
| `verwijderMeubel(id)` | meubel weer weghalen |
| `kamerMeubels(kamerId)` | wat is er in deze ruimte bijgeplaatst |
| `meubeltypen()` | de namen die `plaatsMeubel` kent |

Coördinaten zijn **voxels**: `x` loopt naar rechtsonder, `z` naar linksonder,
`y` omhoog. Diepte (tekenvolgorde) is `x + z`; klein = achteraan.

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
* alles wordt bewaard in de opslag (v6) en staat na "Verder spelen" weer op
  zijn plek. Je hoeft zelf niets te onthouden.

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
| `bewaar()` | opslaan (v6) |
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
`tik, plop(hand), terug, zacht, ja, tover, dag, brief, hoera, bel, deur, kar, munt, ster`.
Er bestaan geen boze geluiden. `zacht` is "dat is het nog niet", nooit een fout-buzzer.

### `ctx.taakKlaar(naam, {sterren})` en `ctx.sluit()`
`taakKlaar` geeft een ster voor het **meedoen**, vinkt het taakje op het prikbord
af en bewaart het spel. Roep hem aan als het kind klaar is — hoe vaak het ook
geprobeerd heeft. `sluit()` sluit je spel netjes af (roept jouw `stop()` aan).

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
* In isometrie liggen dingen snel over elkaar heen. Op het scherm geldt
  (bij de gebruikte schalen) ongeveer: **horizontaal ≈ (x − z) × 2 px**,
  **verticaal ≈ (x + z − 2·y) px**. Een knop is ~50–70 px breed en 48 px hoog,
  dus twee knoppen staan pas echt naast elkaar als hun `x − z` zo'n **30 voxels**
  verschilt, of hun `x + z − 2y` zo'n **50**. Zet je voorwerpen dus uit elkaar,
  of verdeel ze over twee richtingen (zoals de L-vormige balie in de receptie).
  Reken het even na vóór je vier knoppen op één tafel legt: staat er een knop met
  een grotere diepte bovenop, dan gaat de tik dáárheen — dat is de bedoeling van
  de regel, maar het voelt als een bug in je spel.

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

## 6. Testen

```
node --check games/jouwspel.js
```
en spelen vanaf `file://.../demos/dierenhotel/index.html`. De speeltests van het
fundament staan in `.fanout/scratch/dierenhotel/` (`loop.js` = hele speelronde,
`regels.js` = curriculumregels en tikgrootte, `hotspots.js` = geen knop dekt een
andere af (dpr 1 én 3), `plugin.js` = deze API, `perf.js` = 60 fps met 12 dieren).
Kopieer die aanpak: laden → spelen → geen console-fouten → herladen → verder.
