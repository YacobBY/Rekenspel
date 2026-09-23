# Godot-spec — games C: de Kas 🪴 en zijn twee spellen (oogst, weeg)

Geschreven 2026-09-23 bij de bouw (PLAN.md R3, eigenaar: "Kan je met een aparte agent
nog een nieuwe map verzinnen en extra reken minigames daarvoor?").  Anders dan games-a
en games-b is dit geen port van een HTML-bron: de kamer en beide spellen zijn nieuw
in de Godot-versie.  De regels waar ze zich aan houden zijn die van games-b.md §0
(sommenkaart, hulpladder, nooit straffend, geluiden, rustmodus, starten en stoppen),
HOTEL.md §9 (rekenen ín de wereld, tekstbudget, elk woord aan zijn ding) en PLAN.md
§1 R1–R10.  Waar een spel daarvan afwijkt staat het er met reden bij.

**Leeswijzer.** Alle kindertekst staat letterlijk tussen aanhalingstekens.  De
getallen komen uit de eigen generatoren `games/oogst/beurt.gd` en
`games/weeg/beurt.gd` (gezaaid met `Sommen.Prng`, dat alleen gelezen wordt:
`core/sommen.gd` blijft byte-gelijk, R8); *Nagerekend* betekent: in de tests over
alle banden, dagen 1–14 en hotelgroottes doorgerekend.

---

## 1. De Kas (`kas`)

### 1.1 De kamer

| veld | waarde |
|---|---|
| id / naam / icoon | `kas` / `Kas` / 🪴 |
| w × d / wand / vloer / loop | 128 × 112 / 40 / `tegel` / 1.25 |
| kader (`Rooms.kader`) | `[-234, 266, -92, 250]` — 500 × 342, even breed als de receptie |
| wanden | **glas** (`Kamer.glas`, §1.3) |
| mat | terracotta pad x 50..66 over de hele diepte, `#DDA88C` / `#D39B7E` |
| `kijk` | (58, 48), op het pad: door de kasdeur zie je terracotta, geen tegels |
| zone | `rijen` x 12..102, z 3..17 (de moesbakken; voor een later zaaispel) |
| `mijd` | x 16..44 z 19..57 (pluktafel) · x 68..112 z 32..76 (weegschaal) · x 74..122 z 54..102 (de rij gewichten) |
| geluid | `Snd.SFEER["kas"] = "warm"` (hergebruik, geen nieuwe lus) |
| plattegrond | vak `[4, 1]`, boven de tuin: de deur tussen die twee vakken wordt getekend |

PLAN.md R3 plande 110 × 96 met ≥ 16 loopplekken en een poort in de linker hekwand van
de tuin.  Twee dingen zijn sindsdien anders: de linkerkant van de tuin is sinds
2026-09-23 de achtergevel van het hotel (dus de deur zit in de gevel, §1.2), en in de
kas staan nu twee spellen.  Op 110 × 96 lieten hun tafels 6 loopplekken over; op
128 × 112 zijn het er **13** (≥ 8, de regel van `test_elke_kamer_is_compleet`).  De
≥ 16 van R3 is met twee spellen in de kamer niet haalbaar; dat is bewust zo gelaten.

**`mijd`** is een nieuw kamerveld (`Rooms.Kamer.mijd`, leeg in elke andere kamer):
vloerrechthoeken waar geen loopplek (`_cel_vrij`, 3 voxels marge) en geen gekocht
meubel (`_bezet`, 4 voxels marge) mag komen — daar staan de tafels van de spellen, die
los decor zijn (hun rustspullen, world.md §5.1) en dus nergens anders meetellen.

### 1.2 De deur

| van | naar | wand | at | breed | deurpunt | stap binnen |
|---|---|---|---|---|---|---|
| tuin | kas | x (de gevel) | 62 | 12 | (0, 68) | (8, 68) |
| kas | tuin | z | 52 | 12 | (58, 0) | (58, 8) |

In de tuin zit de kasdeur in de **achtergevel**, waar het keukenraam hing: z ≤ 85 is het
enige stuk gevel in beeld, en dat was keukendeur (34..46) + open deurblad (47..58) +
raam (62..79).  Het keukenraam (`gevelraamz`) is daarvoor weggehaald.  Boven de deur
hangt een glazen luifel (`kasluifelz` @ 1, 68, y 27, `ver`), naast de deur staat een
potje met een plant (`kaspot` @ 4, 58).  De gouden pollentabel van de tuin blijft
**letterlijk** staan (het potje ligt ≥ 22 van elke pol, de luifel is wanddecor), net
als de hekpalen.

Een deur **naar een glazen kamer** krijgt een wit kozijn (zoals een deur naar buiten)
en geen opengeklapt deurblad (de glazen deur schuift weg), en de doorkijk wordt van
buitenaf maar 16 % donkerder in plaats van 36 %: een kas is binnen net zo licht als het
gazon (`scenes/vloer.gd`, `_deuren`, `_doorkijk`).

### 1.3 De glazen wanden

`scenes/vloer.gd` `_wanden_glas`: dezelfde twee vlakken als een pleisterwand, dus deuren,
doorkijk en schaduwstroken werken ongewijzigd.  Per wand, van onder naar boven: een
bakstenen borstwering y 0..6 (`#C98B6B`, bovenste laag `#B67858`), dan ruiten die laag
het groen van de tuin laten zien (`#BCDDB7`, verlopend over 14 voxels) en hoger licht
glas (`#CFE7E3` op de z-wand, `#DCEFEB` op de x-wand), witte glasroeden om de 12 voxels
en één kalf op y 22 (`#FBF7EE` / `#E6DDCC`), een witte bovenrand en kap.  De negge van
een deur in een glazen wand is wit (`#E6DDCC`).

### 1.4 Het vaste decor

`art/decor_kas.gd` (`class_name ArtDecorKas`, aangemeld in `ArtDecor._extra()`; de
basis-`NAMEN` blijven 34):

| model | waar | vorm |
|---|---|---|
| `zonnebloem` | (6, 6), de achterhoek | pot met drie zonnebloemen van 21, 27 en 33 hoog; de koppen staan in het vlak x + z = constant, dus naar de kijker, en zijn half zo diep als hoog zodat ze op het scherm rond zijn |
| `moesbak` (`params.groei` 0–3) | (28, 10) groei 3, (86, 10) groei 2 | verhoogde bak 30 × 12 van planken, potgrond met twee voren; 0 kale aarde, 1 kiempjes, 2 blaadjes, 3 kroppen sla |
| `moesbakz`, `moesinhoud` | — | de gedraaide bak, en alleen de inhoud (voor de dagdressing van R6) |
| `aardbeienbakz` | (7, 38), langs de linkerwand | plantenbak 34 × 10 met vijf aardbeiplanten; rode aardbeien hangen over de voorrand en liggen in het blad, witte bloemetjes |
| `potkast` / `potkastz` | (118, 5) | open plankenkast 18 × 24 met drie planken terracotta potjes met zaailingen |
| `zaadkist` | (118, 20) | kist met open deksel vol gekleurde zakjes zaad (R3: het toekomstige ingangsvoorwerp van een zaaispel) |
| `hangplant` / `hangplantz` | z-wand x 28 y 22, x-wand z 76 y 22 (`ver`) | pot aan een houten arm met ranken die 7 voxels naar beneden hangen |
| `gieter` | (14, 66) | groene gieter met tuit en broes |
| `pompoenen` | (114, 100), de voorhoek rechts | drie geribbelde pompoenen tussen platte bladeren; hier is de ingang van `weeg` aan verankerd |
| `kruiwagen` | (22, 104), de voorhoek links | groene kruiwagen vol potgrond, één wiel |
| `kasluifel` / `kasluifelz` | tuin, boven de kasdeur | glazen luifel met witte stijlen op twee schoren |
| `kaspot` | tuin, naast de kasdeur | terracotta potje met een plantje |

Elk model bakt op g = 2, 3 en 4 (`test_art`), geen enkel vast stuk dekt meer dan 3 %
van een deur (`test_rooms`), elke loopplek ligt ≥ 18 van elk stuk.

### 1.5 De kamerbalk met elf chips

Met de kas heeft het hotel elf chips.  Op de tablet (1024 × 768, balk 1000 eenheden)
hebben die 1029 eenheden nodig; een tweede rij kost het wereldkader een hele band
(990 × 637 → 990 × 585) en toen hing de inchecksom in `test_hits` 97 eenheden van de
gast.  `ui/kamerbalk.gd` probeert daarom éérst de krappe vulling (`VULLING_KRAP` = 4 in
plaats van 6) en breekt pas af als het zelfs dan niet past.  Een rij die vandaag past
houdt precies zijn vulling; 768 × 1024 (twee rijen hoe dan ook) ook.  Gemeten kaders
met de kas: 990 × 637, 734 × 788, 1170 × 669, 1170 × 629 (1536 × 760), 326 × 558,
558 × 289 — allemaal gelijk aan die van vóór de kas.

---

## 2. G6 — AARDBEIEN PLUKKEN (`oogst`)

### 2.1 Verhaal

Voor de aardbeienbak staat de pluktafel met tien plekken voor bakjes van tien, in twee
kolommen van vijf (het honderdveld).  Er staan volle bakjes en één open bakje.  Het kind
telt hoeveel aardbeien er liggen, rekent uit hoeveel er nog bij moeten, en plukt ze dan
zelf uit de aardbeienbak — in groep 5 na het volle bakje een heel bakje per tik.  De
gast van de beurt staat naast de tafel en proeft aan het eind.

### 2.2 Aanmelding

```
id: 'oogst'   naam: 'Aardbeien plukken'   kamer: 'kas'   stub: false
hotspot: { obj: 'aardbeienbakz', dx: 23, dz: 0, icoon: '🍓', label: 'Plukken',
           hoog: 14, rust: 'rust_og_tafel' }      // (7, 38) + (23, 0) = de tafel
modellen: { oogst_tafel }                         // games/oogst/modellen.gd
rust: [ { id: 'rust_og_tafel', model: 'oogst_tafel', x: 30, z: 38,
          params: { b: [0, 0, 0, 0, 0] } } ]      // vijf lege bakjes wachten
unlock: N >= 1
taak: { id: 'oogst', icoon: '🍓', tekst: 'Pluk de aardbeien', kamer: 'kas', prio: 6 }
```

### 2.3 Het rekenen per band

```
opzet(N, band, dag):                   rnd = Prng(60617 + dag·7919 + N·131 + band·17)
  band 3: vol = 0 als N = 1 of (dag + N) even, anders 1
          los = 3 … 9 (vol = 0) of 1 … 9 (vol = 1)
  band 4: vol = clamp(N − 1, 2, 5),  los = 1 … 9
  band 5: vol = clamp(N − 1, 5, 8),  los = 1 … 9
  T     = 10·vol + los                 // tientallen en eenheden
  doel  = band 5 ? 10 : vol + 1        // bakjes die aan het eind vol zijn
  nodig = 10·doel − T                  // band 3/4: 10 − los; band 5: 100 − T
```

Eén vol bakje per gast behalve de gast van de beurt, wiens bakje het open bakje is: het
getal groeit met het hotel (T = 10·(N − 1) + r, HOTEL.md §3).

| band | vraag 1 (tellen) | vraag 2 (aanvullen) | curriculum (IDEAS.md) |
|---|---|---|---|
| 3 | 3 … 19 | 1 … 9: splitsen tot 10 | tot 20, splitsingen t/m 10 |
| 4 | 21 … 59 | 1 … 9: aanvullen tot het tiental | tot 100, via de 10 |
| 5 | 51 … 89 | 11 … 49: aanvullen tot 100 | tot 100 via de tientallen |

**De vier antwoorden** (`Afleiders.vier`, `max_getal` 100): vraag 1 liever de
omgedraaide cijfers (`10·los + vol`: "veertien" is vier-tien, dus 14 wordt 41 — de
Nederlandse slip), de cijfers opgeteld (`vol + los`) en één bakje te veel (`T + 10`);
vraag 2 liever `los` (wat er al ligt), `10` (een heel bakje) en `nodig + 1`; in groep 5
`10 − los` (alleen de eenheden), `100 − 10·vol` (alleen de tientallen) en `nodig + 10`.

**Plukken** (`pluk_stap`): één aardbei per tik tot het open bakje vol is; daarna (groep 5)
een heel bakje per tik tot alle tien vol zijn — de strategie "via de tien" in het echt.
`bakjes(o, geplukt)` geeft de tafel zoals hij er dan bij staat; op tafel ligt altijd
`T + geplukt`.  *Nagerekend* in `test_plukken_via_de_tien` en `test_de_getallen_per_band`.

### 2.4 De tafel

`oogst_tafel` (`games/oogst/modellen.gd`): een tafel 26 × 37, blad op y 8, en daarop de
bakjes als deel van **hetzelfde model** (`params.b`: per plek −1 = geen bakje, 0–10 =
zoveel aardbeien; `params.spook`: de plek waarvan de lege gaatjes bleke aardbeien tonen).
Los decor sorteert op zijn vloerpunt, dus een los bakje op de achterste helft van de
tafel zou eronder verdwijnen; één model, één plaat.  Een bakje is 12 × 6, groen, met
aardbeien van 2 × 2 × 2 in twee rijen van vijf (het tienveld: eerst de achterste rij);
elke aardbei heeft een eigen groen kroontje, zodat twee aardbeien die elkaar raken er
twee blijven.  Plek 0..4 is de linker kolom van achter naar voor, 5..9 de rechter.

### 2.5 Waar alles hangt

| element | id | hangt aan |
|---|---|---|
| de kaart | `og_som` | de tafel (`somkaart('og_tafel', …)`); dokt in de rekenbalk (§3.1 PLAN.md) |
| de antwoordstrook | `og_som_keuzes` | onder de kaart |
| de plukknop | `og_pluk` | `op: aan` de aardbeienbak ("🍓 Pluk", groep 5 na het volle bakje "🧺 Pluk een bakje") |
| samen tellen | `og_hulp` | `op: aan` de tafel, wolkje (tablet en groter); op een telefoon de hulpregel van de kaart |
| het spookgetal | `og_spook` | cijfer op de tafel |
| "😋 lekker!" | `og_lekker` | volgt de gast |
| de gast | — | (64, 32), rechts naast de tafel op het pad — nooit vóór de bakjes |

De gast wacht naast de tafel zolang de beurt duurt: elke 1,5 s gaat hij terug naar zijn
plek als hij er niet is en niet bezig is (sip na een misser, blij aan het eind) — een
wachtende gast gaat na 16 s anders dwalen en liep dan vóór de bakjes.

### 2.6 De beurt

0. **de plukker komt** (eigenaar 2026-09-23: "Zorg dat de minigame pas begint wanneer het
   dier er is", world.md §5.8) — de tafel met haar bakjes staat er meteen; de gast van de
   beurt wordt gehaald met `ctx.wacht_op(gast, (64, 32))`, en tot hij naast de tafel staat
   is er geen kaart, maar hangt het hotelwolkje "🐶 Boef komt eraan" met zijn balk en
   `👀 Volg` aan de kasdeur.  Staat hij er al, dan meteen door naar stap 1.
1. **tel** — de kaart zodra hij er staat (R1 telt vanaf zijn aankomst): regel "Hoeveel aardbeien liggen er?", in groep 3 met
   een vol bakje erbij de tweede zin "Een vol bakje heeft 10 aardbeien"; somregel leeg,
   het antwoordvakje en vier getallen.
2. **bij** — regel "Hoeveel passen er nog bij?" (groep 5: "Hoeveel nog tot
   100?"), somregel `7 + __ = 10` (groep 5: `63 + __ = 100`), met het gat van het
   sleutelbord — nooit een "?" tussen twee uitdrukkingen (HOTEL.md §9).
3. **pluk** — regel "Pluk er nog 3", somregel `37 + 0 =` met het totaal in het vakje;
   elke tik op de plukknop: `plop`, een wolkje rode deeltjes op het bakje, de tafel en de
   kaart tellen mee.
4. **af** — `✓`, regel "✅ Alle bakjes zijn vol!", tweede zin "40 aardbeien voor de
   gasten", het vakje zegt het totaal; `tel(missers == 0, ms)`, één ster
   (`taak_klaar('oogst')`), `hoera`, de gast wordt blij, na 3,4 s sluit het spel.

Eén zin per vraag: met twee zinnen over zijn strook was de kaart te hoog voor de
rekenbalk en zweefde hij over de aardbeienbak.

### 2.7 De hulpladder en een misser

Een misser: `zacht`, de centrale S5-pauze van `Ui` (de gast even sip, `🔄 Nog een keer`,
de strook 1,2 s op slot, daarna **dezelfde vier keuzes**) — de kaart wordt daarvoor
nooit opnieuw gebouwd.  Stap 1 en 2: samen tellen, "💛 10 … 20 … 30 en nog 7"
(vraag 1) of "💛 8 … 9 … 10" (vraag 2; groep 5 "💛 63 ▸ 70 ▸ 80 ▸ 90 ▸ 100"), als wolkje
op de tafel — op de kaart maakte die regel de kaart te hoog voor de balk — en op een
kader met een korte zijde onder 400 (telefoon) als hulpregel op de kaart, de plek die
games-b.md §0.5 noemt (naast de tafel was er daar geen plek voor een wolkje).  Stap 3
(derde misser): het antwoord bleek op de tafel, "30 + 7" (vraag 1) en bij vraag 2 bleke
aardbeien in de lege gaatjes van het open bakje (groep 5: "7 + 30").  Nooit een kruis,
nooit een ster minder.

### 2.8 Kindtekst, letterlijk

| waar | tekst |
|---|---|
| ingang | "🍓 Plukken" |
| spelbalk | "Aardbeien plukken" |
| prikbord | "🍓 Pluk de aardbeien", eronder "in de kas" |
| vraag 1 | "🍓 Hoeveel aardbeien liggen er?" (+ groep 3: "Een vol bakje heeft 10 aardbeien") |
| vraag 2 | "🍓 Hoeveel passen er nog bij?" · groep 5 "🍓 Hoeveel nog tot 100?" (niet "… tot 100 aardbeien?": te lang voor de rekenbalk van een telefoon van 360 breed) |
| plukken | "🍓 Pluk er nog %d" · knop "🍓 Pluk" / "🧺 Pluk een bakje" |
| klaar | "✅ Alle bakjes zijn vol!" · "%d aardbeien voor de gasten" · wolkje "😋 lekker!" |
| niemand | wolkje "🛏 nog geen gasten" bij de aardbeienbak, na 1,8 s dicht |

### 2.9 Stoppen en herstellen

De stand staat in `ctx.data().stand` = `{gast, dag, N, band, stap, geplukt, pog, missers,
ster}` en wordt na elke stap bewaard; `opzet` wordt nooit bewaard maar uit N, band en
dag herrekend.  Een start met dezelfde dag, N en band en een stap die niet `af` is gaat
verder waar het kind was (`test_herladen_hervat_de_beurt`); JSON-getallen worden eerst
gehele getallen.  `stop()` bewaart en haalt het eigen losse decor weg; het register zet
de rustende tafel terug.

**Het dier van de beurt** (world.md §5.8): `spelers()` = elke gast met een bed, in
check-in volgorde; de start vraagt `ctx.voorkeur(spelers())` en meldt `ctx.speelt(gast)`.
Een bewaarde beurt van een ander dier dan het gekozen gaat niet verder: het gekozen dier
begint bij de telvraag en de vorige plukker maakt plaats (`ctx.laat_gaan`), na het sturen
van de nieuwe (`test_het_kind_kiest_wie_er_plukt`).

---

## 3. G7 — GROENTEN WEGEN (`weeg`)

### 3.1 Verhaal

Rechts in de kas staat de grote marktweegschaal, met ervoor op de vloer een rij
gewichten.  Een beurt is meten met een balans: eerst staat de weegschaal recht met een
pompoen links en gewichten rechts (hoeveel weegt de pompoen?), dan komt er iets anders
op en zakt de balans naar die kant: leg zelf gewichten op tot hij weer recht staat — hij
helt naar de zwaarste kant, dus het kind vergelijkt vóór het optelt — en lees dan af
hoeveel het weegt.

### 3.2 Aanmelding

```
id: 'weeg'   naam: 'Groenten wegen'   kamer: 'kas'   stub: false
hotspot: { obj: 'pompoenen', dx: −24, dz: −46, icoon: '⚖️', label: 'Wegen',
           hoog: 16, rust: 'rust_wg_schaal' }      // (114, 100) + (−24, −46) = de weegschaal
modellen: { weeg_schaal, weeg_gewicht }            // games/weeg/modellen.gd
rust: de rechte, lege weegschaal op (90, 54) en de gewichten 1, 2, 5, 10 kg in hun rij
unlock: N >= 1
taak: { id: 'weeg', icoon: '⚖️', tekst: 'Weeg de groente', kamer: 'kas', prio: 7 }
```

### 3.3 Het rekenen per band

```
REK    = { 3: [1, 2, 5], 4: [1, 2, 5, 10], 5: [1, 5, 10, 20] }   // kg, lichtste eerst
DINGEN = { 3: [pompoen, meloen], 4: [pompoen, zak], 5: [pompoen, zak] }
opzet(N, band, dag):                 rnd = Prng(51329 + dag·7919 + N·131 + band·17)
  gewicht1: band 3: 3 … 10 · band 4: 11 … 20 · band 5: 21 … 60, zo gekozen dat
            splits(gewicht1) 2 … 4 gewichten is; set1 = splits(gewicht1)
  gewicht2: band 3: 3 + N + rnd·4 · band 4: 8 + 3(N − 4) + rnd·6 · band 5: 21 + 8(N − 7) + rnd·16,
            geklemd op 3 … 9 · 8 … 19 · 21 … 59, nooit gelijk aan gewicht1 en
            met hooguit 4 gewichten recht te krijgen (het dichtstbijzijnde getal dat past)
  ding1 / ding2 = de twee DINGEN van de band, om de dag andersom
splits(g, rek) = zo min mogelijk gewichten, zwaarste eerst
kant(ding, gewichten) = 0 als gelijk; −2/+2 als het verschil groter is dan
            max(2, ding / 4), anders −1/+1  (−: het ding zakt, +: de gewichten zakken)
```

| band | gewichten | vraag 1 | zelf wegen | curriculum (IDEAS.md) |
|---|---|---|---|---|
| 3 | 1, 2, 5 kg | 3 … 10 kg | 3 … 9 kg | vergelijken, natuurlijke maten, splitsen t/m 10 |
| 4 | 1, 2, 5, 10 kg | 11 … 20 kg | 8 … 19 kg | kg, optellen tot 20 |
| 5 | 1, 5, 10, 20 kg | 21 … 60 kg | 21 … 59 kg | kg tot 100 (de reuzenpompoen) |

Groep 5 weegt zonder 2 kg: een strook heeft hooguit vier knoppen (HOTEL.md §9), en 1, 5,
10, 20 zijn de stappen van de munten en biljetten die groep 5 kent.  De pompoen is in
groep 3 klein, in groep 4 groot en in groep 5 de reuzenpompoen (`lm` 0, 1, 2).

**De vier antwoorden**: de som, één gewicht vergeten (`som − kleinste`), het aantal
gewichten (geteld in plaats van opgeteld) en één gewicht te veel (`som + kleinste`).

### 3.4 De modellen

`weeg_schaal` (`games/weeg/modellen.gd`): een houten voet 12 × 12, een blikken zuil, een
lampje op het draaipunt (groen `#8CC08A` als de balk recht staat, anders grijs — nooit
rood), een balk van twee voxels dik langs de schermhorizontaal (de lijn x + z =
constant) en twee blikken pannen (straal 8) op ARM = 14 van het draaipunt: links
(−14, +14) het ding, rechts (+14, −14) de gewichten.  `params.kant` −2 … 2 zet de pannen
3 voxels per stap omhoog of omlaag (`pan_hoog`).  Wat op de pannen ligt hoort bij
**hetzelfde model** (`params.l`, `.lm`, `.r`): een geribbelde pompoen, een gestreepte
meloen of een jute zak met aardappels links, en rechts de gewichten **op een stapel** in
de volgorde waarin ze erop gelegd zijn (vijf naast elkaar passen niet op een pan).
`weeg_gewicht` (`params.kg`): één gewicht met een koperen knopje, voor de rij op de vloer.

| kg | maat (breed × hoog) | kleur |
|---|---|---|
| 1 | 3 × 2 | geel `#F2C14E` |
| 2 | 4 × 3 | groen `#8CC08A` |
| 5 | 5 × 4 | blauw `#6FA3CC` |
| 10 | 6 × 5 | roze `#F19FB5` |
| 20 | 7 × 6 | paars `#B58FD1` |

### 3.5 Waar alles hangt

| element | id | hangt aan |
|---|---|---|
| de kaart | `wg_som` | de weegschaal; dokt in de rekenbalk |
| de antwoordstrook / de gewichten | `wg_som_keuzes` | onder de kaart: bij het aflezen vier getallen, bij het wegen één knop per gewicht "⬇ 5 kg" (kort, zoals in de balk en op een telefoon: "⬇ 5") |
| eraf | `wg_eraf` | `op: aan` de weegschaal, "⬆ eraf", alleen als er een gewicht op ligt |
| de balans zegt | `wg_zeg` | `op: aan` de weegschaal: "⬆ nog te licht", "⬇ te zwaar", "⚖️ precies!", "💛 Neem een zwaarder gewicht"; op een telefoon de hulpregel van de kaart |
| samen tellen, het recept | `wg_hulp` | `op: aan` de weegschaal (telefoon: de hulpregel) |
| het spookgetal | `wg_spook` | cijfer op de weegschaal |
| "🥔 9 kilo" | `wg_af` | volgt de gast |
| de gewichten op de vloer | `wg_kg1` … | los decor in een rij langs de schermhorizontaal rond (98, 78), 10 voxels uit elkaar; een gewicht dat op de pan gaat, pluft even |
| de gast | — | (62, 88), links vóór de weegschaal, nooit vóór wat er gewogen wordt |

**Waarom de gewichten op de strook staan en niet op de vloer:** een knop op elk van vijf
kleine gewichten in een rij vond op geen enkel scherm een plek óp zijn eigen gewicht;
"5 kg" hing dan boven de moesbak en "10 kg" bij de zaadkist (eigenaar, 2026-09-23: labels
die zweven waar ze niet horen).  Op de strook hangen ze aan hun kaart, met pictogram én
woord, en de rij op de vloer laat zien welk gewicht welke kleur heeft.

### 3.6 De beurt

0. **de weger komt** (eigenaar 2026-09-23, world.md §5.8) — de weegschaal met de pompoen
   en de rij gewichten staan er meteen; de gast van de beurt wordt gehaald met
   `ctx.wacht_op(gast, (62, 88))`, en tot hij naast de weegschaal staat is er geen kaart,
   maar hangt het hotelwolkje "komt eraan" met `👀 Volg` aan de kasdeur.
1. **lees1** — de kaart zodra hij er staat (R1 telt vanaf zijn aankomst): "🎃 Hoeveel kilo is de pompoen?", somregel
   `10 + 2 + 1 =`, vier getallen; de weegschaal staat recht.
2. **leg** — na een goed antwoord gaat de pompoen eraf en ligt het tweede ding erop; de
   balans zakt naar die kant.  "⚖️ Maak de weegschaal weer recht", de strook met de
   gewichten.  Elke tik: `plop`, het gewicht op de stapel, de balans helt opnieuw en zegt
   wat er aan de hand is; "⬆ eraf" haalt het laatste gewicht weer af (`terug`).  Te zwaar
   is **geen misser**: de balans helt gewoon de andere kant op.  Hooguit vijf gewichten
   (`PAN_MAX`); een zesde: `zacht` en "💛 Neem een zwaarder gewicht".  Recht: `ja`,
   "⚖️ precies!", het lampje wordt groen, en 0,9 s later de volgende vraag.
3. **lees2** — "🥔 Hoeveel kilo is de zak?", somregel met de eigen gewichten
   (`5 + 2 + 2 =`), vier getallen.
4. **af** — "✅ De zak weegt 9 kilo!", het vakje zegt 9; `tel(missers == 0, ms)`, één
   ster (`taak_klaar('weeg')`), `hoera`, de gast blij met "🥔 9 kilo", na 3,4 s dicht.

### 3.7 De hulpladder en een misser

Een misser op een leesvraag: `zacht` en de centrale S5-pauze (de kaart blijft staan).
Stap 1 en 2: doortellen over de gewichten, "💛 10 ▸ 12 ▸ 13", in een wolkje bij de
weegschaal (telefoon: op de kaart); stap 3: het antwoord bleek op de weegschaal.  Bij het
wegen na acht gewichten erop en eraf het recept: "💛 5 + 2 + 2".

### 3.8 Kindtekst, letterlijk

| waar | tekst |
|---|---|
| ingang | "⚖️ Wegen" |
| spelbalk | "Groenten wegen" |
| prikbord | "⚖️ Weeg de groente", eronder "in de kas" |
| lezen | "🎃 Hoeveel kilo is de pompoen?" · "🍉 … de meloen?" · "🥔 … de zak?" (niet "weegt": dan is de regel op een telefoon van 360 breed te lang voor de rekenbalk) |
| wegen | "⚖️ Maak de weegschaal weer recht" · knoppen "⬇ 1 kg" … "⬇ 20 kg" (in de rekenbalk kort: "⬇ 1" … "⬇ 20") · "⬆ eraf" |
| de balans | "⬆ nog te licht" · "⬇ te zwaar" · "⚖️ precies!" · "💛 Neem een zwaarder gewicht" |
| klaar | "✅ De zak weegt 9 kilo!" · wolkje "🥔 9 kilo" |
| niemand | wolkje "🛏 nog geen gasten" bij de pompoenen, na 1,8 s dicht |

### 3.9 Stoppen en herstellen

`ctx.data().stand` = `{gast, dag, N, band, stap, pan, pog, missers, acties, ster, zeg?}`,
na elke stap bewaard; `opzet` wordt herrekend.  Dezelfde dag, N en band en een stap die
niet `af` is: verder waar het kind was, ook midden in het wegen met de gewichten op de
pan (`test_herladen_hervat_de_weging`).

**Het dier van de beurt** (world.md §5.8): als bij het plukken — `spelers()` = elke gast
met een bed, in check-in volgorde; een beurt van een ander dier dan het gekozen gaat niet
verder, het gekozen dier begint bij de eerste leesvraag en de vorige weger maakt plaats
(`test_het_kind_kiest_wie_er_weegt`).

---

## 4. Pictogrammen

Nieuw in de emoji-subset (`fonts/tekens.txt` [emoji], alleen `Emoji.ttf` herbouwd uit de
systeem-Noto Color Emoji; de herbouw geeft voor de oude 112 tekens een byte-gelijk
bestand): 🍉 1F349, 🍓 1F353, 🎃 1F383, 🥔 1F954.  🪴 ⚖️ 🧺 💛 ⬆ ⬇ ✅ 😋 🛏 bestonden al.

## 5. Tests

`games/oogst/test_oogst.gd` (15) en `games/weeg/test_weeg.gd` (13): aanmelding, modellen
op elke schaal, de getallen per band over dagen 1–14, de antwoorden, de hele beurt per
band met de vinger (een misser, dezelfde vier keuzes, te licht/te zwaar/eraf, recht,
aflezen, klaar), de hulpladder, herladen, zonder gasten, het rustspul en `mijd`, en de
echte schil op 1024 × 768, 768 × 1024, 360 × 740 en 740 × 360: elke knop een tikdoel
binnen het kader, nooit `krap`, niets van een ander ding afgedekt, en elk wolkje en elke
knop bij zijn ding; op de drie hoge schermen staan de vragen in de rekenbalk (ook de
vraag tot 100 van groep 5 op de telefoon, `test_groep_5_op_de_telefoon`).  Eén
uitzondering, genoemd in de test: het S5-wolkje van `Ui` ("🔄 Nog een keer", 1,2 s)
raakt op 740 × 360 de strook, waar de balk loslaat (B3).
`tests/test_rooms.gd` `test_de_kas_is_een_glazen_kas_achter_het_hotel`,
`tests/test_kamerbalk.gd` `test_elf_chips_op_een_rij_op_de_tablet`.
