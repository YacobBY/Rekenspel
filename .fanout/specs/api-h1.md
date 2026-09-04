# api-h1 — de hotspot-laag: waar staat een knop, en wie ruimt hem op

Ticket H1, `demos/dierenhotel/hits.js`. Aanleiding (eigenaar, 2026-09-04):
*"Bij veel objecten als de speelmand staat de tekst over het object"* — de knop
met pictogram + woord stond precies óp het voorwerp en dekte het helemaal af
(zie `.fanout/scratch/dierenhotel/k1-kamer1-420x860.png`: de speelmand en het
bakje zijn onvindbaar onder hun eigen knop).

Alles hieronder is additief: geen id's veranderd, geen bestaande
`Hits`-signatuur veranderd, de 16-per-kamer-grens en de meetreparatie van
710003e (`display:none` meet 0×0, die 0 niet onthouden) staan er nog.

## 1. Wat de laag van een voorwerp weet

`world.js` geeft de laag per beeld één functie: `pr(x, z, y)` → een punt in
css-px binnen het wereldkader. `mik()` / `volg()` geven **geen** schermvak,
alleen wereldcoördinaten; de eigenaar van de hotspot geeft `y` = de hoogte van
het voorwerp in voxels (bakje 7, speelmand 8, bed 13, deur 9, bel 20,
prikbord 22, spelknop = voorwerp + 12).

Daaruit rekent de laag zelf twee getallen uit:

| naam | betekenis |
|---|---|
| `anker` = `pr(x, z, y)` | het punt op de **bovenkant** van het voorwerp |
| `vh` = `y * voxelPx` | de hoogte van het voorwerp op het scherm (px) |

`voxelPx` (= px per voxel hoogte) meet de laag met twee extra `pr()`-aanroepen,
en alleen na een `Hits.hermeet()`. `world.js` roept `hermeet()` precies in
`meet()`, dus precies als `g`/`dpr` veranderen — in de tekenlus komt er dus
**geen** aanroep en geen allocatie per knop bij.

Het vak van het voorwerp is dan `[anker.x, anker.y + vh/2, breedte, vh]` om het
middelpunt. De **breedte** kent deze laag niet (world.js vertelt geen
voetafdruk); die schat `debug()` op de knopbreedte — dat is precies het
strookje dat de knop kán afdekken. `vh` is echt gemeten.

## 2. Het plaatsbeleid: `o.op`

```js
Hits.maak({ id: 'mand_kamer1', x: 40, z: 40, y: 8, icoon: '🧶', label: 'Speelmand' });
Hits.maak({ id: 'tb_kan', ..., op: 'midden' });   // ik plaats zelf
```

| `op` | plek van de knop |
|---|---|
| `'boven'` | onderrand een kiertje (4 px) **boven** het anker: het voorwerp blijft heel in beeld. |
| `'onder'` | bovenrand een kiertje **onder** de vloerpunt (`anker.y + vh`). |
| `'midden'` | precies op het anker — het oude gedrag. |
| `'rand'` | (cijfertags) onderrand net over de bovenrand van het voorwerp: hooguit `min(4 px, 10% van vh)` van het voorwerp gaat schuil (gemeten 11-12 %; `offsetHeight` rondt af op hele pixels, dus die tien procent houdt marge onder de 15 % die de plaatstest meet). |
| `'auto'` | de standaard, zie hieronder. |

`'auto'` kiest:

1. `kind === 'tag'` → `'rand'` (een cijfer hóórt op zijn voorwerp).
2. `vast` (sommenkaart, cijferpad, keuzestrook) → `'midden'`.
3. `y <= 0` → `'midden'` (een vrije plek op de vloer: geen voorwerp bekend).
4. eigen `html` → `'midden'` (de eigenaar tekent en plaatst zelf).
5. klasse `hotwens|hotwolk|hotsom|hotpad|hotkeuzes|hotgetal` → `'midden'`
   (een kaartje of praatje, geen naamplaatje van een voorwerp).
6. anders → `'boven'`.

Regel 4 en 5 zijn de rem: een spel dat zijn knop zelf in schermpixels
uitrekent (het sleutelbord rekent `haakY`/`wolkY`/kaarthoogte terug naar
voxels, ui.js hangt cijferpad en keuzestrook aan de kaart) houdt zijn eigen
opmaak. Wil zo'n eigenaar de nieuwe plaatsing tóch, dan zet hij er
`op: 'boven'` bij; wil een eigenaar een piepklein voorwerp juist wél onder
zijn knop, dan `op: 'midden'`.

**Automatisch terugvallen:** past de knop niet meer boven het voorwerp binnen
het kader (`anker.y − hoogte − 4 < 2`) en past hij eronder wél, dan wordt
`'boven'` stil `'onder'`. `debug().spots[].op` vertelt wat het geworden is.

**Uitwijken (UITWIJK) in vier rondes.** De uitwijktabel is dx −2..2, dy +2..−3;
omhoog en opzij komen altijd eerst (eigen kostensortering per blok), daarna
omlaag. Wat een knop aan een voorwerp mag kiezen, gaat van netjes naar
noodgeval:

0. alleen omhoog of opzij (bij `'onder'`: omlaag of opzij);
1. alle richtingen, maar geen plek die óp het eigen voorwerp valt;
2. **stapelen**: rij voor rij van de bovenrand van het kader naar beneden, per
   rij vijf kolommen. Het rooster van ronde 0/1 hangt aan het mikpunt, en die
   mikpunten liggen soms allemaal in dezelfde band; dit is de enige manier om
   drie brede kaartjes (de taakjes van het prikbord zijn 148 px breed) plus
   vijf knoppen in 326 × 383 px kwijt te kunnen;
3. alles — een knop die een ANDERE knop afdekt is erger dan een knop die een
   hoekje van zijn voorwerp afdekt. Concreet gemeten: in een kader van
   826 × 190 px schoof de deurknop in de gang anders precies onder het
   wolkje van de voerkar, en dan is die deur geen sleep-doel meer (de kar kon
   niet naar de kamer van de gast; `voerkar/spel.js land` 260/3 → 263/0).

Lukt ronde 3 ook niet, dan valt de knop terug op zijn eerste keus (boven het
voorwerp). In een gewone kamer is de plek al in de eerste paar pogingen van
ronde 0 gevonden.

## 3b. Sleep-doelen: het voorwerp zelf is ook een doel

De knop staat nu boven het bakje, maar een kind sleept naar het bakje. Voor
elke hotspot met `drop` die op `'boven'` of `'onder'` staat legt de laag daarom
een doorzichtig **vangvlak** over de omhullende rechthoek van knop + voorwerp,
met dezelfde `data-drop` en `data-h-*`. `ui.js` zoekt bij het loslaten met
`elementFromPoint(...).closest(dropSel)`, dus zo'n vlak is een geldig doel —
gemeten met een echte muissleep in `hits-plaats.js` (bak in kamer 1, bed in
kamer 2, alle vier de vensters).

Waar het vlak ligt:

* in een **eigen laagje** (`div.vanglaag`) naast `#worldHits`, met `z-index:2`
  tegen de 3 van de knoppenlaag. Een echte knop pakt dus altijd voor, en alles
  wat `#worldHits [data-hot]` of `#worldHits .hot` opvraagt (de tests, de
  games, `Hits.watRaakt`) ziet er niets van;
* niet voor `op:'midden'` (die knop dekt zijn voorwerp zelf al) en niet voor
  een knop die voor de kaart van een spel moest wijken.

Een tik op het vlak doet hetzelfde als een tik op de knop (leen-functie of
`aan`), anders zou het vlak een tik op het voorwerp opslokken.
`debug().spots[].vang` geeft `"x,y,w,h"` van het vlak, of `null`.

## 3. Kort kader: de kaart van het spel is onaantastbaar

Heeft de eigenaar die voorrang heeft (`Hits.voorrang(spel)`) een `vast`
hotspot in beeld — speelt er niets, dan de enige eigenaar met een vaste kaart
— dan geldt voor knoppen van **andere** eigenaars: na het uitwijken nog steeds
over die kaart of over de knoppen van dat spel heen? Dan gaat de knop even weg
(`display:none`) in plaats van eroverheen te liggen. Er wordt elk beeld
opnieuw gerekend, dus zodra de kaart weg is staat hij er weer.
`debug().verstopt` = hoeveel er zo weg staan, `debug().spots[].weg` = welke.

Bewijs van het probleem dat dit oplost:
`.fanout/scratch/dierenhotel/sleutels/x1-sleutels-740x360-na.png` (Boek en
Prikbord lagen op de kaart en op de haakjes).

## 4. `o.onWeg(spot)` — opruimhaak

`Hits.weg(id)` (en dus ook `Hits.wisEigenaar(naam)`) roept `spot.onWeg(spot)`
één keer aan, vóór het element uit de pagina gaat. De haak wordt eerst op
`null` gezet, dus hij loopt nooit twee keer en `Hits.weg` mag er zelf in
voorkomen. Gooit de haak een fout, dan komt er een `console.warn` en gaat de
hotspot alsnog weg.

Bedoeld voor ui.js: de sommenkaart hangt `resize`/`orientationchange`-
luisteraars op voor haar cijferpad en keuzestrook, en kan die nu opruimen
zonder een eigen levensduur-boekhouding.

```js
Hits.maak({ id: 'som1', ..., vast: true, onWeg: function () {
  window.removeEventListener('resize', padLuister);
  window.removeEventListener('orientationchange', padLuister);
} });
```

## 5. `Hits.debug()` erbij

Per hotspot: `op`, `anker: [x, y]` (vóór het opschuiven), `vh`, `weg`,
`vak: [midX, midY, w, h] | null`. Op het geheel: `verstopt`, `voxelPx`.
De plaatstest `.fanout/scratch/dierenhotel/hits-plaats.js` leest precies deze
velden — de knopvakken komen uit de dom (`getBoundingClientRect`), het vak van
het voorwerp uit dezelfde `pr()` die de laag zelf gebruikt.
