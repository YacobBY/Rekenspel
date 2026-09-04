# API P1c — bewegen met een belofte, houdingen `zwem` en `spring`

Geleverd door `demos/dierenhotel/world.js` (Dier-klasse + World-bewegingsfuncties)
en aan de spellen gehangen via `window.CTX_UITBREIDINGEN`; `games/registry.js`
blijft ongewijzigd. Dezelfde drie functies staan ook op `World` zelf
(`World.loopNaar`, `World.stappen`, `World.pose`) voor hotel.js en de tests.
Bedoeld voor G1 zwembad (precies n meter zwemmen), G3 hinkelpad (steen voor
steen hupsen en tellen) en alles van de vorm "loop daarheen en doe dan X".

Gemeten met `.fanout/scratch/dierenhotel/p1c.js` — 197 PASS / 0 FAIL
(portret 420×860, liggend 860×420, rustmodus), en 197/0 op de drie-wegs-merge
van deze tak met main (8cce0bd: P1a zwembad, P1b decor, P1d wensen, S2, X1).
Zet je de vier reparaties van P1c-F1 weer uit (doorglijden, tempo, waterband,
lege lijst / `reis` zonder pad), dan vallen precies de 15 assertions om die
daarover gaan en geen enkele andere — ze meten dus echt wat ze beweren.

## 1. Handtekeningen

```js
ctx.wereld.loopNaar(id, x, z, opties)      // → Promise<boolean>
ctx.wereld.stappen(id, punten, opties)     // → Promise<boolean>
ctx.wereld.pose(id, naam, duur)            // → boolean
```

| veld in `opties` | betekenis | standaard |
|---|---|---|
| `pose` | houding onderweg: `null` (lopen), `'zwem'`, `'spring'` | `null` |
| `tempo` | maal de loopsnelheid van dit dier in deze kamer (`vmax × kamer.loop × tempo`); bij `spring` maal de sprongduur | `1` |
| `perStap(i, punt)` | gaat af bij ELKE landing (ook bij `loopNaar`: één keer, `i = 0`), vóór de belofte valt | – |
| `na` | eindhouding na het laatste punt: `'wacht'`, `'stil'`, `'zit'`, `'kijk'`, `'snuif'`, `'blij'`, `'sip'`, `'zwem'`, `'spring'`; iets anders valt terug op de gewone aankomst van de motor | `'wacht'`, en `'zwem'` als `pose: 'zwem'` |

`punten` mag `[{x, z}, …]` of `[[x, z], …]` zijn; punten die geen getal zijn
worden overgeslagen. `loopNaar(id, x, z, o)` is precies `stappen(id, [{x, z}], o)`.
Coördinaten zijn voxels in de kamer waar het dier NU is.

## 2. Betekenis van de belofte

* **true**: het dier heeft het laatste punt gehaald. Het staat er dan exact op
  (de landing zet `x, z` op het punt; gemeten afwijking 0 voxel) met
  `hoogte = 0` en `lift = 0` — behalve met eindhouding `zwem` (de standaard bij
  `pose: 'zwem'`): dan blijft hij drijven op `hoogte = -7` / `lift = +14`,
  waterband en al — in de eindhouding `na`. Standaard is dat `wacht`
  (rustig ademen, blijft staan tot het volgende bevel), zodat "loop erheen, dan
  X" niet stukloopt op een gast die alweer wegwandelt. Met `na: 'stil'` gaat het
  dier daarna weer zijn eigen gang.
* **false, nooit een reject**: de opdracht is ingehaald. Gemeten inhalers:
  een nieuwe `loopNaar`/`stappen` (ook vanuit `perStap`), `World.ga`,
  `World.zet`, `World.reis`, `World.slaap` (in bed stappen), `Art.feast` →
  `World.feed`, `Art.setMood('happy')` → `World.mood`, `World.solo`,
  `ctx.wereld.pose(...)`, de kamer verlaten, en uitchecken (uit `World.sync`
  verdwijnen). De oude belofte valt (false) VOORDAT de nieuwe start; de
  resolve-volgorde is gemeten (`c1a=false` vóór `c1b=true`).
* Een bevel dat feitelijk niets doet, laat de opdracht met rust. Gemeten:
  `feed` in een kamer zonder bakje (de tuin) en `Art.setMood(id,'idle')` bij
  een lopend dier (C10), `World.reis` naar een kamer die niet bestaat (E2, en
  de zwemmer blijft ook in het water liggen — zie het Tijdmodel), een `pose`
  met een onbekende naam (E), en `stappen(id, [])` (C7b/C7c). Ook een
  `Hotel.render()` / `World.sync()` met dezelfde gastenlijst breekt niets af
  (gemeten met twee dieren tegelijk).
* **`mood('idle')` haalt niet in, de andere stemmingen wel.** Dat is de motor:
  `World.mood(id,'idle')` doet alleen iets voor een dier dat sip zit (dan
  kiest het weer iets nieuws) en is verder een lege opdracht — er is geen
  toestand die het dier krijgt, dus er is ook niets om een belofte voor af te
  breken. `'happy'` (`Art.setMood('happy')` → `zet('blij')`) en `'sad'`
  (wandelen naar de sipplek) zetten wél een nieuwe toestand en halen de
  opdracht dus in. Bewust zo gelaten: een spel dat "blij" of "sip" zegt,
  neemt het dier over; een spel dat "idle" zegt, zegt niets.
* **Herladen**: een belofte hoort bij het JS-geheugen van de pagina. Wie F5
  indrukt (of het spel opnieuw laadt), gooit de hele wereld weg: de belofte
  wordt niet meer `true` of `false`, hij verdwijnt gewoon met de pagina. Een
  spel mag een beurt dus nooit alléén in een `.then(...)` bijhouden — zet de
  stand in `ctx.data()` en herstel de beurt bij het opstarten (GAMES-API §5,
  ook al de eis voor golf 3).
* **Kamers**: een opdracht loopt altijd BINNEN de kamer waar het dier nu is; er
  wordt niet door deuren gelopen (gebruik daarvoor `World.reis`). Verandert de
  kamer van het dier tussentijds, dan valt de belofte false. Een dier in een
  kamer die niet in beeld staat, loopt zijn opdracht gewoon af (de grove tik
  gebruikt dezelfde motor), dus een spel mag ook een dier buiten beeld sturen.
* **Onbekend dier**: meteen `false` (0 ms). **Lege puntenlijst** (of alleen
  punten zonder getallen): meteen `true` en het dier wordt NIET aangeraakt —
  geen route, geen `eindDoel`, geen `slaapDoel`, geen hoogte en geen lopende
  opdracht gaan eraan. `stappen(id, [])` is dus geen bevel maar een vraag die
  meteen met "klaar" antwoordt; een gast die naar zijn bed loopt, loopt door
  en gaat gewoon liggen (gemeten C7b), en een lopende opdracht loopt af
  (gemeten C7c: beide beloftes true).
* Twee (of meer) dieren kunnen tegelijk een eigen opdracht hebben; ze zitten
  elkaar niet in de weg (gemeten: beide true, elk op zijn eigen laatste punt).
* **Rustmodus** (`prefers-reduced-motion: reduce`): er beweegt niets. Het dier
  gaat langs de punten (per punt: positie zetten, dan `perStap(i, punt)`, dus de
  haak ziet het dier op DAT punt), staat op het laatste punt, krijgt de
  eindhouding en de belofte is direct `true` (gemeten 0 ms). Geen deeltjes.
  Een drijver blijft drijven als `World.sync` in rustmodus alles stilzet — net
  als een slaper in zijn bed; `ga`, `reis`, `stappen` en `pose` halen hem wél
  uit het water.
* Slapen is onaangeroerd: `inZijnBed`, `slaapDoel` en het stilzetten van
  slapers werken als in S1 (`slaap.js` 124/0, ook na de merge). Wie vanuit een
  opdracht in bed stapt, ligt gewoon op de matras (`lift = -7 × HG`, gemeten).

## 3. Houdingen

`ctx.wereld.pose(id, naam, duur)` — `duur` in tikken (15 per seconde), `0` of
weggelaten = tot het volgende bevel voor `zwem`, `spring`, `wacht` en `sip`.
Onbekende naam of onbekend dier → `false`, er verandert niets. `pose` haalt een
lopende opdracht in (belofte false). Geen wijziging in art.js: beide nieuwe
houdingen zijn combinaties van bestaande frames plus `lift`.

| naam | wat je ziet | duur |
|---|---|---|
| `zwem` | het dier zakt 7 voxels (`ZWEM_DIEP` = de hoogte van de pootjes, art.js `POOT`): de buik ligt op de waterlijn, de pootjes eronder. Over die onderste ~40% van het plaatje komt een doorschijnende **waterband** (zie hieronder), dus je ziet de pootjes vaag ONDER water. Zachte deining (bob ±0,9 px, zijwaarts ±0,6), peddelen met `loopA`/`loopB`, en zwemmend elke 5 tikken 1–2 lichte plonsvoxels bij de voorpootjes (wit/lichtblauw, 9 tikken); stilliggend elke 30 tikken één rimpel | 0 = blijven drijven |
| `spring` | ter plekke hupsen: 6 tikken boog + 3 tikken plat. Als `pose` van `stappen`: één parabool per punt, top = 5 (hond) / 6 (poes) / 7 (konijn) / 4 (gans) voxels, houdingen `loopA` → `blijA` (in de lucht) → `loopB`, bij de landing 3 tikken `blijB` met bob +1 (de squash) | 0 = blijven hupsen |
| `stil` / `rust` | de gewone motor-toestand `stil`; daarna gaat het dier weer zijn eigen gang | 10 |
| `wacht` | staat rustig te ademen, kijkt naar voren, tot het volgende bevel | 0 |
| `zit`, `kijk`, `snuif`, `blij` | de bestaande houdingen van de motor | 45 / 30 / 30 / 50 |
| `sip` | zit sip (`zitsip`) tot het volgende bevel | 0 |

**Hoogte op het dier** (`World.dier(id)` / `ctx.wereld.dier(id)`):

* `d.hoogte` = voxels BOVEN de vloer, omhoog is +. Springer `> 0` (top 4..7),
  zwemmer `= -7`, staand/geland `= 0`. Dit is wat het ticket "lift" noemt.
* `d.lift` = de tekenafstand in pixels OMLAAG (de bedconventie van de motor:
  matras = `-MATRAS × HG` = `-14`). Dus `lift = -hoogte × HG` (HG = 2):
  springer `lift < 0`, zwemmer `lift = +14`. De motor tekent met `lift`; die
  kant kon niet omgedraaid worden zonder de tekencode en het bed te raken
  (buiten dit ticket), vandaar de tweede naam.
* Na een landing en na `pose('rust'|'wacht'|…)` zijn beide 0. Uitzondering: bij
  een landing MIDDEN in een zwemopdracht blijft het dier drijven, dus daar
  leest `perStap` `hoogte = -7` / `lift = +14` (een zwemmer gaat niet elke
  meter even staan). Bij lopen en springen is het bij elke landing 0.

**De waterband (P1c-F1).** Het badwater van rooms.js (`bad`-rechthoek,
`BADWATER`) wordt in de VLOERPLAAT gebakken en ligt dus onder het dier; alleen
`lift` gaf daarom een dier dat tot zijn buik in de vloer wádt, niet een dier
dat drijft. Daarom tekent world.js na het dier een doorschijnende band water
over de onderste ~40% van zijn plaatje:

* De waterlijn is de vloer onder het dier (`schermY(x, z)`); omdat een zwemmer
  precies `ZWEM_DIEP` voxels zakt, ligt zijn buik daar altijd op. De band deint
  NIET mee: het water blijft liggen, het dier deint erin.
* De snijlijn is een ellips (het oppervlak in vogelvlucht: achter het dier
  ligt de lijn hoger op het scherm dan ervoor), daaronder alles water.
* Kleur `#9CD1E4` (= `BADWATER[0]` uit rooms.js) op alfa `0,75`, en ALLEEN op
  de voxels van het dier zelf (`source-atop` op één hergebruikt hulpdoek), dus
  er ligt nooit een plas naast hem op de badrand of de tegels. Per beeldje
  worden er geen nieuwe objecten of canvassen gemaakt.
* De rimpels en plonsjes komen er daarna nog bovenop (`tekenPluis`).
* Alleen in de houding `zwem` (`d.inWater()`), en als de kamer een
  `bad`-rechthoek heeft (rooms.js, zwembad) alleen binnen die rechthoek: een
  gast die in zwemhouding op het dek staat krijgt geen band. Heeft de kamer
  geen bad (de tuin met de tobbe, een testkamer), dan tekent de band altijd —
  daar máákt de houding zelf het water.
* Gemeten (p1c.js sectie K, portret): met de band verschillen 1115 beeldpunten
  op het dier, alle 1115 ónder de waterlijn en alle 1115 dichter bij de
  waterkleur; zonder band 0. Schermplaatje: `p1c-zwem-close.png` (echte
  zwembad-kamer na de merge met main).

## 4. Tijdmodel

* De motor tikt 15× per seconde (`STAP = 1000/15`) op de KLOK, niet op de
  beeldjes (`lus()` haalt tikken in met `nu - vorigeTik`); tekenen gaat met
  interpolatie tussen twee tikken. Alles hieronder is dus even lang op een
  trage telefoon als op een snelle pc.
* Lopen en zwemmen: `rijd(tempo, verder)` — aanloop en remweg zoals altijd,
  met `vmax = dier.vmax × kamer.loop × tempo`.

  **Eén doorlopende glijbeweging over alle punten (P1c-F1).** Het dier stopt
  niet per punt: de snelheid gaat over de punten heen mee, het remt alleen af
  voor het LAATSTE punt (`verder` = wat er na het huidige punt nog op de lijst
  staat, één keer per opdracht uitgerekend), en wat er van de stap van een tik
  overblijft als het een punt raakt, loopt door naar het volgende punt.
  `perStap` gaat nog steeds precies één keer per punt af, op volgorde, met het
  dier exact op dat punt. Een rij punten kost dus net zoveel tijd als één
  rechte lijn van dezelfde lengte — hoe fijn je de baan ook verdeelt.

  Gemeten (poes, `vmax` vastgezet op 1,3, zwembad `loop 1,5`, 116 voxels):

  | wat | tempo 1 | tempo 0,5 | tempo 2 |
  |---|---|---|---|
  | 1 punt (116 voxels) | 4,26 s | 8,86 s (2,08 ×) | 2,20 s (0,52 ×) |
  | 43 punten (1 per meter) | 4,27 s | 8,86 s (2,08 ×) | 2,20 s (0,52 ×) |

  Snelheid bij tempo 1 (zelfde dier, over een rechte lijn incl. aanloop en
  remweg): kamer met `loop 1` (tuin, gang) 18,7 voxel/s, `loop 1,5`
  (receptie, zwembad, speelkamers, keuken) 26–27 voxel/s. Voor `loop 1,25`
  (wasserij) reken ertussenin; de kruissnelheid is
  `vmax × loop × 15` voxel/s (bij `vmax` 1,3 en `loop` 1,5 = 29,3); de rest is
  aanloop en remweg. Elk dier heeft zijn eigen `tempo` (0,78–1,28), dus reken
  in de praktijk op 20–35 voxel/s in een `loop 1,5`-kamer.

  **Tempo schaalt de hele duur, lineair.** Snelheid × tempo, versnelling ×
  tempo², remweg in voxels onafhankelijk van tempo: de beweging bij tempo *k*
  is precies dezelfde beweging, *k* keer zo snel afgespeeld. Gemeten over 5
  punten / 80 voxels: tempo 2 = 0,48–0,50 × de tijd van tempo 1, tempo 0,5 =
  2,04–2,06 ×. Met `maat = 1` (de gewone loop van de motor, alle bestaande
  wandelingen) rekent `rijd` exact zoals vroeger.

  *Voor P1c-F1 was dit anders*: elke landing zette `v = 0`, dus 43 punten over
  116 voxels kostten 13–17 s in plaats van 4,3 s (2,2–4,8 × zo lang als één
  segment) en tempo 2 haalde maar 0,79 ×.
* Springen: `vlieg(snel)` — vaste snelheid per sprong (geen aanloop/remweg, dus
  de boog is ook in de tijd een parabool):
  `snel = min(vmax × loop × tempo, lengte / max(2, round(6 / tempo)))`, plus
  `max(1, round(3 / tempo))` tikken squash na de landing. Een sprong van 12
  voxels duurt zo 6 tikken (0,40 s) + 3 tikken squash ≈ 0,60 s per steen;
  gemeten 4 sprongen: tempo 1 = 2,4 s, tempo 2 = 1,3 s (0,54 ×).
  Een heel lang stuk met `pose: 'spring'` wordt één lange parabool — het spel
  kiest zelf de afstand tussen de punten (stapstenen).
  Springen glijdt met opzet NIET door: stoppen en squashen per steen hoort bij
  het hinkelen (G3). Het tempo werkt daar dus per sprong en in hele tikken
  (`round(6 / tempo)` in de lucht, `round(3 / tempo)` plat), zodat tempo 2 op
  ongeveer 0,54 × uitkomt in plaats van precies op 0,5 ×.
* Zwemmen: "1 meter per slag" is de zaak van het spel (G1): kies één punt per
  meter en tel in `perStap` — dat kost geen extra tijd meer (zie het
  doorglijden hierboven: 43 punten = 1 punt) — of laat het dier in één keer
  naar de eindmeter zwemmen en zet zelf de getaltag.
* `perStap` gaat af in de tik van de landing (het dier staat exact op het
  punt; `hoogte`/`lift` = 0 bij lopen en springen, en `-7`/`+14` bij zwemmen,
  want een zwemmer blijft drijven) en vóór de belofte. Gooit `perStap` een fout, dan
  wordt die gelogd (`console.error('perStap', e)`) en gaat de opdracht door.
  Zet `perStap` zelf een nieuwe opdracht, dan valt de oude belofte false.
* Let op: staat het tabblad op de achtergrond, dan staat `requestAnimationFrame`
  stil en dus ook de motor; een belofte valt dan pas als het spel weer in beeld
  is. Een spel mag daar geen beurt van laten afhangen (zoals nu ook al geldt
  voor `World.ga`).

## 5. Voorbeelden

```js
/* G3 hinkelpad: steen voor steen, tellen bij elke landing */
var stenen = [[40, 110], [46, 110], [52, 110]];
C.wereld.stappen(g.id, stenen, {
  pose: 'spring',
  perStap: function (i, p) { C.wereld.getalTag(g.id, i + 1); }
}).then(function (ok) {
  if (ok) vraagVolgende();          /* false = een ander bevel nam het dier over */
});

/* G1 zwembad: precies 13 meter zwemmen, daarna blijven drijven */
C.wereld.loopNaar(g.id, xVanMeter(p + 13), badZ, { pose: 'zwem' })
 .then(function (ok) { if (ok) C.wereld.getalTag(g.id, (p + 13) + ' m'); });

/* G1 zwembad, slag per slag tellen: één punt per meter kost geen extra tijd
   (43 punten over de hele baan = 4,3 s, net als één punt), dus het dier
   glijdt door en de teller loopt gewoon mee */
var slagen = [];
for (var m = p + 1; m <= p + 13; m++) slagen.push([xVanMeter(m), badZ]);
C.wereld.stappen(g.id, slagen, {
  pose: 'zwem',
  perStap: function (i) { C.wereld.getalTag(g.id, (p + i + 1) + ' m'); }
}).then(function (ok) { if (ok) klaarMetBaantje(); });

/* "loop daarheen, dan X" */
C.wereld.loopNaar(g.id, 70, 90).then(function (ok) {
  if (ok) C.wereld.pose(g.id, 'blij');
});
```

## 6. Plek in de code (world.js, tak `worktree-agent-a9e3b331dc27583ab`)

* Dier-klasse: velden `hoogte`, `zwemT`, `opdracht` (100–102); `zet` en `ga`
  roepen `onderbreek` (106, 114); `rijd(maat, verder)` met tempo- en
  doorglij-factor (162–195); `tik` (298) en `grofTik` (385) sturen een opdracht
  of een zwem/spring-houding naar `opdrachtTik`; `stilzetten` laat een drijver
  drijven (415–435).
* Blok "OPDRACHTEN MET EEN BELOFTE (P1c)" (439–686), direct na de Dier-klasse:
  constanten (`POOT_HOOG`, `ZWEM_DIEP`, `SPRING_HOOG`, `SPRING_TIKKEN`,
  `SQUASH`, `ZWEM_KL`, `OD_STAAT`, `OD_STIL`, `OD_DUUR`), `onderbreek` (470),
  `opdrachtStop/Start` (477, 483) met `odRestLijst` (504), `opdrachtVolgende`,
  `springTikken`, `vlieg`, `opdrachtTik` (536), `glijTik` (565, het
  doorglijden), `opdrachtLanding` (588), `opdrachtVerder/Klaar`, `eindHouding`,
  `drijf` (632), `inWater` (648, de poort voor de waterband), `plons` (656,
  slaat deeltjes buiten beeld over), `springHouding`, `houdingTik`.
* Tekenen: `waterDoek` (1053) en `tekenWater` (1061) vlak vóór `tekenDier`
  (1099), dat na het dier één regel `if (d.inWater()) tekenWater(...)` doet.
* `sync` stopt de opdracht van een dier dat uitcheckt (1387).
* `reisNaar` (1422) laat een zwemmer/opdracht met rust als er geen pad is.
* Blok "P1c: bewegen met een belofte" (1557–1639), na `solo()`: `odPunt`,
  `odLijst`, `odRust`, `stappen` (1595, met de lege-lijst-poort), `loopNaar`,
  `poseZet` en de push op `window.CTX_UITBREIDINGEN` (1633).
* `api.loopNaar = loopNaar; api.stappen = stappen; api.pose = poseZet;` (1812).
* Suite: `.fanout/scratch/dierenhotel/p1c.js` (197 assertions; secties A–K);
  schermplaatjes `p1c-spring.png`, `p1c-zwem.png` (420×860, midden in de
  beweging, knoppen- en naamlaag even uit), close-ups `p1c-spring-close.png`,
  `p1c-zwem-close.png` (in de echte zwembad-kamer als die er is, anders in de
  tuin), en `p1c-rust.png`.
* Andere suites tegen deze tak: `slaap.js` 124/0, `smoke.js` foutvrij,
  `tobbe/spel.js` (portret) 111/0, `loop.js` (portret) 156/1 — die ene is de
  eis "8 ruimtes in de deurgraaf" van main (P1a zwembad + wasserij), die deze
  tak (basis af8ab32) nog niet heeft; op de drie-wegs-merge met main is
  `loop.js` 157/0.
