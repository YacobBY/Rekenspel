# Godot-poort — spelgroep A: bedden, sleutels, meubels, tobbe, voerkar

Bronbestanden (alleen gelezen, niets gewijzigd):
`demos/dierenhotel/games/{bedden,sleutels,meubels,tobbe,voerkar}.js`,
`games/registry.js`, `state.js`, `hotel.js`, `rooms.js`, `ui.js`, `hits.js`,
`econ.js`, `snd.js`, `art.js`, `world.js`, `GAMES-API.md`, `HOTEL.md` §9.

**Status van elke bewering.** Alles in dit document is uit de code gelezen en
nagerekend, tenzij er expliciet *(inferred)* achter staat. Getallen die uit een
formule volgen zijn met een script nagerekend (zie §2.9). Kinderteksten staan
letterlijk tussen aanhalingstekens; `+` betekent stringplakken zoals in de
JavaScript.

**Doelpubliek.** Een Godot 4.7-ontwikkelaar die de JavaScript niet leest. Waar
een gedrag afhangt van de curriculumband (groep 3 / 4 / 5) staat elke band apart.

---

## 1. Het fundament dat de vijf spellen delen

### 1.1 Levenscyclus (registry.js)

Een spel meldt zich aan met een definitie:

| veld | bedden | sleutels | meubels | tobbe | voerkar |
|---|---|---|---|---|---|
| `id` | `bedden` | `sleutels` | `meubels` | `tobbe` | `voerkar` |
| `naam` | `Bedden op rij` | `Het sleutelbord` | `Het meubelboek` | `Tobbe-tijd` | `De voerkar` |
| `kamer` | `kamer1` | `receptie` | `receptie` | `tuin` | `keuken` |
| `hotspot.obj` | `mand` | `sleutelbordz` | `boek` | `tobbe` | `kar` |
| `hotspot.icoon` | `🛏` | `🔑` | `📖` | `🛁` | `🛒` |
| `hotspot.label` | `Bedden` | `Sleutels` | `Boek` | `Tobbe` | `Voerkar` |
| `hotspot` offset | `hoog:14, dx:-4, dz:-4` | `hoog:13, dz:6` | `hoog:16` | `hoog:12` | `hoog:16` |
| `unlock` | `N >= 1` | `N >= 2` | `N >= 3` | `N >= 1` | `N >= 1` |

`N` = aantal gasten in het hotel (`State.N()`). Een niet-ontgrendeld spel heeft
géén icoontje in de wereld.

Volgorde bij `Games.start(id)`:
1. Draait er al een ander spel → `stop()` daarvan.
2. `actief = id`; het prikbord gaat dicht (`Hotel.bordDicht()`).
3. `Hits.voorrang(id)` — zolang dit spel speelt kiezen zijn knoppen als eerste
   hun plek en verdwijnen de wens-wolkjes van het hotel.
4. Het icoontje van het spel zelf wordt weggehaald (tenzij `hotspot.blijf`);
   geen van deze vijf zet `blijf`.
5. `World.naar(def.kamer)` als je er nog niet bent, dan `def.start(ctx)`.
6. Gooit `start()` een fout → `actief = null` en één toast: **"💛 Probeer iets anders"**.
7. Een spel mág onderweg van kamer wisselen (bedden doet dat); de motor neemt
   dan die kamer over als spelkamer.

`stop()` (via `ctx.sluit()`, een ander spel, of de motor): `def.stop()`,
`Hits.wisEigenaar(id)` (alle knoppen, wolkjes, sommenkaarten, cijfers van dít
spel weg), `Hits.voorrang(null)`, `Ui.leegPaneel()`, icoontjes terug,
`Hotel.render()`. Er is geen "pauze": supersede = volledige stop.

**Opslag.** `ctx.data()` geeft een eigen woordenboek per spel-id dat meegaat in
de savegame (`kws-hotel-v7`, veld `state.spel[<id>]`). Een spel dat zijn stand
daarin zet, hervat na "Verder spelen" precies waar het was. Beloftes/timers
overleven een herlaad niet.

### 1.2 De knoppenlaag (hits.js) — het model dat de plekken bepaalt

Elke knop is een DOM-knop van minstens **48 × 48 css-px** boven het isometrische
canvas. Projectie (identiek in world.js en in de spellen):

```
scherm-x = px0 + (x - z) * 2k
scherm-y = py0 + (x + z - 2y) * k
```

met `k = g / dpr` uit `World.schaal()`; `schaal()` levert
`{g, dpr, k, pxPerVoxelX: 2k, pxPerVoxelY: k, pxPerHoogte: 2k}`.
`x, z` zijn vloervoxels, `y` is hoogte in voxels.

Regels die het gedrag van deze spellen sturen:

* **Maximaal 16 zichtbare knoppen per kamer** (`MAX_PER_KAMER = 16`). Boven dat
  aantal vallen de laagste `prio` af. `prio` standaard 5; hoger = belangrijker.
  `getalTag` heeft vaste prio 4 en valt dus als eerste weg.
* **`vast: true`** = deze knop wijkt nooit uit; andere knoppen schuiven om hem
  heen. Sommenkaart, cijferpad en keuzestrook zijn altijd `vast` (prio 14).
* Knoppen die elkaar afdekken worden uit elkaar geschoven; elke knop wordt
  binnen het kader geklemd (2 px marge) zodra kader > 78 px.
* `Hits.pak(id, eigenaar, fn)` = een knop van het hotel lenen (bedden leent de
  deur, voerkar leent de voerbakjes); `Hits.laat(eigenaar)` geeft hem terug.
* `volg()` = een callback die elk beeld de nieuwe plek levert (voor dingen die
  bewegen: de voerkar, de doos van het meubelboek, een dier).

### 1.3 De vier wereldprimitieven voor rekenweergave

| primitief | wat het is |
|---|---|
| `ui.wolk(obj, o)` | spreekwolkje aan voorwerp/dier: `{icoon, getal, tekst, klas, hoog, prio, tik}`. Zonder `tik` leest een tik de tekst voor. Klassen: `''` (neutraal), `hulp` (zacht/roze), `goed` (groen). |
| `ui.somkaart(obj, som, o)` | het mini-rekenschrift: bovenaan één (of twee) verplichte **zin** met het pictogram vooraan, daaronder de somregel, daarnaast een antwoordvakje, optioneel een cijferpad of een keuzestrook. Handvat: `.zet(tekst)` `.hulp(html)` `.klaar()` `.regel(zin)` `.som(tekst)` `.weg()` `.getal()`. |
| `wereld.getalTag(obj, n, o)` | een kaal cijfer óp een voorwerp; niet aantikbaar. `n = null` haalt hem weg. `klas:'hotspook'` = het lichte spookcijfer. |
| `hotspots.bron(obj, o)` | sleepbron met teller: `{icoon, aantal, hand, klas, prio, titel, tik, sleep:{dropSel, ghostHTML, canDrag, onDrop, onTap}}`. |

**Tekstbudget (HOTEL.md §9, hard).** Elke sommenkaart draagt één gewone
Nederlandse zin met werkwoord of vraagwoord, pictogram vooraan op diezelfde
regel: **≤ 8 woorden en ≤ 40 tekens**. Eén regel blijft gegarandeerd tot ~34
tekens; 35–40 breekt naar twee regels. Een tweede korte zin mag als er een
extra getal bij hoort. Drie zinnen bestaan niet. Een kale uitdrukking zonder
zin mag nooit, en `?` mag nooit als vergelijkingsteken tussen twee
uitdrukkingen staan. Overtreding = één `console.warn` per kaartje, de kaart
tekent wél door.

**Hulpladder, overal gelijk:** 1e poging samen doortellen, 2e poging nog eens,
pas bij de **3e** poging spookvormen. (bedden/sleutels/tobbe zetten hun
helper-knop al na 2 missers neer; meubels/voerkar volgen de 3-ladder in de
kaart zelf. Zie per spel.)

### 1.4 Geluiden (snd.js) — namen zoals aangeroepen

`tik` (kort tikje 720→620 Hz), `plop(hand)` (480 + 40·hand Hz, gepitcht op de
schepgrootte), `terug` (300→460 Hz), `zacht` (de zachte "nee": 430 Hz + 340 Hz),
`ja` (660 + 880 Hz), `tover` (glinster), `munt`, `ster`, `brief` (papier —
altijd als de helper verschijnt), `hoera`, `kar`, `bel`, `deur`, `plons`, `au`,
`klok`, `hup`, `dag`. **Er is nergens een foutgeluid met negatieve lading:** een
misser is altijd `zacht()`.

### 1.5 Het prikbord

Hoogstens 3 kaartjes, pictogram + ≤ 6 woorden. Wensen van dieren gaan vóór
(prio 0), dan spellen. Kaartjes van deze vijf:

| bron | id | icoon | tekst | wanneer | prio |
|---|---|---|---|---|---|
| hotel zelf | `voer` | 🍪 | `Vul de voerkar` | een bakje in een kamer mét gasten staat leeg | 0 |
| tobbe (`SPEL_TAAK`) | `bad` | 🛁 | `<naam> wil in bad`, anders `Tobbe-tijd` | er is een gast met wens `bad` die nog niet blij is | 1 |
| bedden | `bedden` | 🛏 | `Zet de bedden op rij` | `gasten.length >= 2` | 5 |
| sleutels | `sleutels` | 🔑 | `Hang de sleutels op` | `gasten.length >= 2` | 5 |
| meubels | `meubels` | 📖 | `Koop iets moois` | `munten >= 5` | 5 |

Alle prio-5-kaartjes ("gewone klusjes") tellen even zwaar en **rouleren per
dag**: dag *d* begint bij index `(d - 1) mod n`. Een taakje aantikken doet
`bordDicht()`, zet `ronde = 'vrij'`, gaat naar de kamer en start het spel.
`ctx.taakKlaar(naam)` vinkt af op `naam` én op de spel-id; een afgevinkt kaartje
blijft de rest van de dag met ✅ staan.

**Wens ↔ spel.** Een gast krijgt de wens 🛁 alleen als de tobbe echt speelbaar
is (`WENS_SPEL = { bad: 'tobbe' }` + niet-stub + ontgrendeld). De wensen die het
hotel zelf inlost (`kamer`, `eten`, `spelen`) hebben geen spel nodig.
`wereld.behoefteKlaar(gastId, 'bad')` zet `g.blij` en tekent het bord opnieuw.

### 1.6 Beloning

`ctx.taakKlaar(naam, {sterren: n})` → `Econ.sterren(n, spel-id)` (default 1),
`Snd.ster()`, HUD-teller meteen bij, prikbord afgevinkt, `State.bewaar()`.
**Een ster is voor meedoen, nooit voor goed rekenen.** Alle vijf geven precies
1 ster per afgeronde ronde.

Los daarvan voedt elk spel het adaptieve signaal: `ctx.state.tel(goed, ms)` met
`goed = (aantal missers === 0)` en `ms` = verstreken tijd sinds `t0`. Zie §2.6.

### 1.7 Bewegingsreductie (`prefers-reduced-motion: reduce`)

Geverifieerd: **geen van de vijf spellen doet zelf een media-query.** De
reductie zit in drie lagen eronder, en die moet de poort overnemen:

* CSS: `.bouncy, .wiggle, .pop { animation: none }` — dus het wiebelende haakje
  (sleutels), de stuiterende dieren en de pop-animatie staan stil.
* `art.js`: per stemming één rustig plaatje in plaats van een lus.
* `world.js` (`rustModus`): geen deeltjes, niemand loopt; een loopopdracht komt
  meteen aan (`perStap` gaat per punt af, het dier staat op het eindpunt, de
  belofte is direct waar).

**Gevolg voor de poort:** de `setTimeout`-ketens van de spellen (de dekengolf
van 260 ms, de 2600/3400 ms nagenieten, het 900 ms wachten op een dier) blijven
in rustmodus gewoon lopen — ze zijn spel-logica, geen animatie. Alleen de
beweging eronder verdwijnt. *(inferred: de code zegt dit nergens expliciet;
het volgt uit het feit dat de timers in de spelbestanden staan en de media-query
niet.)*

---

## 2. De bevroren rekenkern (state.js) — byte-identiek overnemen

Alles hieronder is **gehele-getal-rekenen**; JavaScript `Math.floor`,
`Math.ceil`, `Math.round` (halve naar +∞: `Math.round(19.5) = 20`) en `%`
(rest houdt het teken van de deler-loze deeltal — hier altijd positief).

### 2.1 `koekjesSom(day, n)` — eerlijk delen met rest

```
DEEL_PLAN = [ {per:4,rest:0}, {per:4,rest:1}, {per:3,rest:2},
              {per:4,rest:0}, {per:3,rest:1}, {per:4,rest:2} ]

p    = DEEL_PLAN[(day - 1) mod 6]
per  = p.per ; rest = p.rest
if rest >= n : rest = n - 1
while n*per + rest > 20 and per > 2 : per = per - 1
return { per, rest, total: n*per + rest }
```

Voorbeeld: `koekjesSom(3, 5)` → plan-index 2 → per 3, rest 2, total 17.

### 2.2 `vergelijk(v)` — meer / minder / precies (check-in)

```
tot = v.dagen * v.nieuw
tot > v.voorraad -> 'meer'
tot < v.voorraad -> 'minder'
anders           -> 'precies'
```

Drie eerlijke uitkomsten; "precies" is een echte mogelijkheid en geen valstrik.
Wordt door géén van deze vijf spellen gebruikt (de check-in van het hotel doet
het), maar hoort bij de bevroren kern en staat er daarom compleet.

### 2.3 `sommen.deel(N, band, dag)` — de voerkar

```
N = max(1, floor(N))
(k, r) = koekjesSom(dag, N).per / .rest
if r >= k : r = k - 1
while k > 1 and k*N + r > 20 :
    k = k - 1 ; if r > k - 1 : r = k - 1
if band <= 3 : return { T: k*N + r, k, r, band: 3 }

KSET    = { 3:[1,2,3,4], 4:[2,3,4,5,10], 5:[1,2,3,4,5,6,7,8,9,10] }
PLAFOND = { 3:20, 4:100, 5:100 }
set = KSET[band] (fallback KSET[4]) ; plaf = PLAFOND[band] (fallback 100)
kand = [ kk in set : kk >= k and kk*N + min(r, kk-1) <= plaf ]
if kand leeg : kand = [k]
kk2 = kand[(dag + N) mod kand.length]
r2  = min(r, kk2 - 1)
return { T: kk2*N + r2, k: kk2, r: r2, band }
```

Nagerekend:

| N | band | dag | T | k (per gast) | r (in de pot) |
|---|---|---|---|---|---|
| 3 | 3 | 1 | 12 | 4 | 0 |
| 2 | 3 | 2 | 9 | 4 | 1 |
| 5 | 4 | 3 | 17 | 3 | 2 |
| 6 | 4 | 6 | 20 | 3 | 2 |
| 7 | 5 | 5 | 36 | 5 | 1 |

### 2.4 `sommen.tafel(band)` — bedden

```
band = (band <= 3) ? 3 : (band >= 5) ? 5 : 4
TAFEL_SET = { 3:[1,2,5,10], 4:[1,2,3,4,5,10], 5:[1..10] }
TAFEL_MAX = { 3:20, 4:100, 5:100 }
d = state.dag ; N = aantalGasten() of 2 als dat 0 is
a    = set[(d + N) mod set.length]
maxB = max(1, min(10, floor(plaf / a)))
b    = 1 + (d*3 + N) mod maxB
return { a, b, uit: a*b, band, tafels: set, plafond: plaf }
```

Nagerekend: `(band 4, dag 3, N 5)` → a 3, b 5, uit 15.
`(band 3, dag 1, N 3)` → a 1, b 7, uit 7. `(band 5, dag 5, N 7)` → a 3, b 3, uit 9.

### 2.5 `sommen.geld(band, nachten, prijs)` en `sommen.klok(band)`

Geen van de vijf gebruikt ze (het meubelboek maakt zijn eigen prijzen), maar ze
horen bij de bevroren kern:

```
geld:  kans = band<=3 ? [1,2] : band===4 ? [1,2,5] : [2,5]
       prijs   = prijs   of kans[dag mod kans.length]
       nachten = nachten of (band<=3 ? 2 : band===4 ? 3 : 4)
       while nachten*prijs > 20 and nachten > 1 : nachten--
       totaal = nachten*prijs ; betaald = totaal
       band 4 en dag even en totaal+2 <= 20 : betaald = totaal + 2
       band >= 5 : while totaal >= 20 and nachten > 1 { nachten--; totaal = nachten*prijs }
                   betaald = (totaal < 10) ? 10 : 20
       return { nachten, prijs, totaal, betaald, wissel: betaald - totaal }

klok:  u = 7 + (dag*3) mod 8
       band <= 3 : { u, m:0,  stap:60, tekst: u + " uur" }
       band == 4 : m = [0,15,30,45][(dag+u) mod 4] ; stap 15 ; tekst "u:mm"
       band >= 5 : mm = (dag*7 + u*5) mod 60 ; stap 5 ; duur = 20 + (dag mod 4)*10
```

### 2.6 De band: `bandVanN`, `tel`, `herbereken`

```
bandVanN(N) : N <= 3 -> 3 ; N <= 6 -> 4 ; anders 5

tel(goed, ms):
   signaal.push({ g: goed?1:0, t: clamp(ms, 0, 20000) })
   houd de laatste 10 items ; daarna herbereken()

signaalStand: acc = som(g)/n ; twijfel = som(t)/n

herbereken():
   als n >= 6:
      acc >= 0.8 en twijfel < 7000 en kunnen < 5 -> kunnen++ , signaal leeg
      acc <  0.5 en kunnen > 3                   -> kunnen-- , signaal leeg
   band = max(3, min(bandVanN(aantalGasten()), kunnen + 1))
```

Dus: **N bepaalt het plafond van de band, het signaal begrenst hem verder.**
Goed/fout telt nooit mee voor sterren of toegang — alleen voor de maat van de
volgende som. Er staat nergens een klok op de vingers van het kind.

### 2.7 De planbord-solver (`dagRnd`, `planFouten`, `planOplossingen`, `maakPlan`)

Bevroren, nog niet in gebruik door deze vijf spellen; hoort in de poort mee
omdat de ledger hem als bevroren noemt.

```
dagRnd(zaad):                       # LCG, 24 bits uitvoer
   a = (zaad * 2654435761 + 12345) mod 2^32
   next(): a = (a * 1103515245 + 12345) mod 2^32 ; return (a >>> 8) / 16777216

planFouten(plan, stand):
   voor elke regel r met soort 'na':
      ta = stand[r.a] ; tb = stand[r.b]
      sla over als ta of tb ontbreekt
      fout als ta < tb + cellen(r.b)

planOplossingen(plan, max=500):
   vaste blokken zetten hun bits in 'vast'
   backtrack over de vrije blokken, elk blok op elke at met at+cells <= CELLEN
   tel elke stand zonder planFouten; onthoud de eerste; stop bij max
   return { aantal, eerste }

maakPlan(dag, dieren, verzwak):
   rnd = dagRnd(dag*7919 + dieren.length*131 + verzwak)
   blok per dier: cells = mins / 15
   wilVast = dag>=2 en verzwak<3 ; wilOrde = dag>=3 en verzwak<2
   wilVol  = dag>=4 en verzwak<1
   1. vaste afspraak = VASTE_AFSPRAKEN[(dag - 2 + verzwak) mod 4]
   2. krimp dierblokken naar 1 cel tot de som past
   3. wilVol: klusje van min(2, ruimte) cellen erbij
   4. wilOrde: 'na'-regel tussen een NA_ACT-blok (Bad, Plonzen) en een
      VOOR_ACT-blok (Wandeling, Spelen); anders twee willekeurige via rnd()
   5. dag>=6 en verzwak<1: tweede 'na'-regel over twee ándere blokken
   planbord(dag, dieren) probeert verzwak 0..5 tot er een oplossing is,
   anders maakPlan(1, dieren, 9)
```

### 2.8 Het toevalsgetal van sleutels (`zaadje`) — de tweede generator

Een **andere** LCG dan `dagRnd`; sleutels is het enige van de vijf dat toeval
gebruikt, en dat is volledig gezaaid, dus reproduceerbaar:

```
zaadje(n):
   s = (n mod 2^32) ; als s == 0 dan s = 1
   next(): s = (s * 1664525 + 1013904223) mod 2^32 ; return s / 4294967296
```

Zaad in `maakOpdracht`: `dag*7919 + N*131 + band*17 + ronde*8191 + 1`.

**Geen enkel ander spel in deze groep roept `Math.random()` aan.** bedden,
meubels, tobbe en voerkar zijn volledig deterministisch uit `(dag, N, band)` plus
de stand in de savegame. Voor byte-identieke uitkomsten moet de poort dus alleen
deze twee LCG's exact overnemen — met 32-bits wrap-around en deling door 2^32
respectievelijk 2^24.

### 2.9 Muntenrekenen (econ.js) — meubels

```
buidel(total):   DENOMS = [10,5,2,1]
   rest = total ; som = 0 ; out = []
   while rest > 0 (max 60 rondes):
      d = eerste D in DENOMS met D <= rest en D <= som + 1 ; anders 1
      out.push(d) ; som += d ; rest -= d
   sorteer aflopend ; geef [{v, id:'c<index>_<v>'}]
   -> elk bedrag t/m total is precies te leggen; het biljet van 10 komt er
      pas in als de losse munten al 9 halen

splits(n):  zoveel mogelijk 10, dan 5, dan 2, dan 1
som(arr):   som van de v-waarden
munt(v, extra, id): het HTML-muntje ('note' bij 10 of 20, anders 'c<v>')
```

---

## 3. BEDDEN OP RIJ (`bedden.js`)

### 3.1 Verhaal, kamer, gast

De vloer van slaapkamer 1 wordt een bedplan. Uit de dekenkist komen bedjes; die
leg je in **nette rijen** — elke rij is even breed, en het kind zoekt uit hoeveel
rijen er nodig zijn. Elk bedje dat je neerlegt wordt een **echt bed** via
`wereld.voegBed`, en bedden zijn de harde gastenlimiet: dit is het spel dat het
hotel laat groeien.

Wie in beeld staat: de **eerste gast zonder bed** in de spelkamer krijgt het
opdrachtwolkje boven zijn kop. Bij een misser loopt de **laatste** gast zonder
bed naar de deuropening en wacht daar geduldig (`reis(..., na:'wacht')`).
Kamerhulp is **Wolkje** (🐑, het konijn uit de gastenpool).

### 3.2 Start, kamerkeuze en "vol"

* Het icoontje hangt op de speelmand (`mand`) in kamer 1, `hoog 14, dx -4, dz -4`.
* Bij `start()`: `kiesKamer()` neemt kamer 1 als die capaciteit ≥ 2 heeft;
  anders de slaapkamer (kamer mét bed-slots) met de hoogste capaciteit.
* Capaciteit `capaciteit(k) = min(MAX_CAP=6, ruweCapaciteit(k))`.
  `ruweCapaciteit` speelt de greedy plaatsing droog na: neem steeds het vrije
  vakje dat (manhattan) het verst van alle bestaande bedden ligt, zet daar een
  bed, en gooi alle vrije vakjes binnen **18 voxels** (manhattan) weg. Het
  aantal ronden = de capaciteit.
* **Capaciteit < 2 → het spel belooft niets:** wolkje op de mand,
  `🛏 "vol ✓"` (klas `goed`, prio 14, tikken sluit), `Snd.zacht()`, en na
  **2600 ms** sluit het spel zichzelf. Géén opdracht, géén ster.

### 3.3 De opdracht per band

```
s = ctx.state.sommen.tafel(band)                     # §2.4
set    = s.tafels, oplopend gesorteerd (fallback [1,2,5,10])
perRij = clamp(s.a, 1, MAX_PER_RIJ = 10)
rijen  = clamp(s.b, 1, MAX_RIJEN = 3)

# de kamer is de baas: eerst de tafel omlaag naar een tafel die de BAND kent,
# daarna het aantal rijen
while perRij > cap:
    kleiner = grootste getal in set met (getal < perRij en getal <= cap)
    als er geen is: perRij = max(1, min(perRij, cap)) ; break
    perRij = kleiner
rijen = max(1, min(rijen, floor(cap / perRij) of 1, 3, maxStroken() - 1))
doel  = rijen * perRij
```

Per band (uit `TAFEL_SET`, §2.4):

| band | toegestane rij-breedtes | plafond product | schuifwand |
|---|---|---|---|
| groep 3 | 1, 2, 5, 10 (rijtjes, **geen tafels**) | 20 | nee |
| groep 4 | 1, 2, 3, 4, 5, 10 | 100 | nee |
| groep 5 | 1 t/m 10 | 100 | **ja** |

**Schuifwand (alleen groep 5):** `D.wand = (band >= 5 && rijen >= 2) ? rijen - 1 : 0`.
De knop 🚧 splitst de rijen in twee stukken: `a = D.wand`, `b = rijen - a`,
label `a × perRij + b × perRij`, weergegeven als twee getallen onder elkaar
(`a*perRij` boven, `+b*perRij` eronder). Tikken verlaagt `D.wand` met 1 en
wikkelt om: `wand - 1 < 1 ? rijen - 1 : wand - 1`. Dit is de verdeelstrategie
"3 rijen van 7 = 2 × 7 + 1 × 7".

Verse opdracht zodra de **signatuur** verandert:
`[band, dag, N, kamer, cap, rijen, perRij].join('|')`. Anders wordt de bewaarde
stand hervat.

Nieuwe opdracht zet: `rij = []`, `missers = 0`, `klaar = false`, `nieuw = 0`,
`over = 0`, `spook = false`, `fase = 'leg'`, `vol = 0`.

**Worked example.** band 4, dag 3, N 5, cap 6 → `tafel` geeft a 3, b 5 →
perRij 3, rijen min(5, 3) = 3 → `perRij(3) <= cap(6)` dus geen tafelverlaging →
`rijen = max(1, min(3, floor(6/3)=2, 3, maxStroken()-1))`; op een staand kader
van 478 px is `maxStroken() = 4`, dus rijen = **2**, doel = **6**.

### 3.4 Beeldopbouw en maten (alles in css-pixels, dan terug naar voxels)

Constanten: `MAX_RIJEN 3`, `MAX_PER_RIJ 10`, `MAX_CAP 6`, `GOLF 260 ms`,
`STAP_PX 50` (rij→rij omlaag), `BOVEN_PX 80`, `ONDER_PX 66`, `KNOP_PX 48`,
`KAART_PX 92`, `MIN_BOVEN 74`, `MIN_ONDER 52`, `goot` start 132.

```
frameHoogte()  = hoogte van #world, fallback 480
maxStroken()   = max(3, min(4, floor((frameHoogte - 200) / 50) + 1))
                 (200 = 74 + 46 - 24 + 52 + 48 + 4)
                 kader 200/228/282/320 -> 3 ; 379/405/478/715 -> 4
aantalStroken()= min(4, rijen + 1)          # altijd één lege reserverij
marges():
   rij   = (n - 1)*50 + 48
   over  = max(0, frameHoogte - rij - 4) ; nodig = 96
   extra = max(0, over - nodig)
   boven = min(80, 74 + extra*0.6)
   onder = min(66, 52 + extra*0.4)
   (kader 478 met 4 stroken -> 80 / 66)
rijStap()   = max(50 / (2 * pxPerVoxelY), 24)          # NIET afronden
rijPlek(r)  = { x: begin + r*stap, z: begin + r*stap }
              met breed = kamerbreedte (114) en
              begin = max(2, (breed - (n-1)*stap) / 2)
plekPx(r, dx, dy) = rijPlek(r) verschoven dx px opzij en dy px omhoog:
              d = dx / (2 * pxPerVoxelX)
              { x: p.x + d, z: p.z - d, y: 6 + dy / pxPerHoogte }
goot        = max(88, breedte van strook 0 / 2 + 52), na elke tekenbeurt gemeten
```

De rijen liggen dus op de diagonaal `x = z` van de kamervloer, netjes onder
elkaar op precies 50 css-px.

**Objecten in beeld (id → wat):**

| id | plek | wat |
|---|---|---|
| `bd_rij0..N` | `rijPlek(r)`, y 6, **`vast`**, prio 13, klas `hotbron`, `kind:'drop'`, `drop:'bedrij'` | het strookje: `n` bedjes + `perRij - n` spookbedjes + het getal `n` |
| `bd_kist` | `plekPx(laatste, 0, -marges().onder)`, prio 12 | de dekenkist 🧺, sleepbron, teller = `doel - totaal` |
| `bd_undo` | `plekPx(laatste, -goot, 0)`, prio 11, klas `hotwolk` | ↩ eentje terug (alleen als er iets ligt en niet klaar) |
| `bd_som` | `plekPx(0, 0, marges().boven + somLift)` of ernaast | de sommenkaart |
| `bd_wolk` | boven de gast zonder bed, hoog 52, prio 12 | 🛏 `doel` + tekst |
| `bd_wand` | `plekPx(D.wand, goot, 25)`, prio 11, klas `hotwolk hulp` | 🚧 schuifwand (alleen groep 5) |
| `bd_klaar` | `plekPx(0, goot, 56)`, prio 14, klas `hotwolk goed` | 🐾 `doel`, de controle |
| `bd_hulp` | `plekPx(laatste, -goot, -50)`, prio 11, klas `hotwolk hulp` | 🐑 kamerhulp Wolkje (pas vanaf 2 missers) |
| `bd_spook` | `plekPx(r, -(goot-26), 0)` | spookcijfer `perRij` op de eerste lege rij |

Strookje-HTML: bedjes op `.95rem`, of `.8rem` zodra `perRij >= 10`. Gevulde
plekken zijn `🛏`, na afloop `🛌`; lege plekken zijn `🛏` met opacity **.22**,
of **.62** als het spookvoorbeeld aan staat op déze rij.

**De kamer rustig maken.** Bij elke tekenbeurt haalt bedden de hotel-knoppen weg
die op de rijen zouden vallen: `bed_<kamer>_bed1`, `bed_<kamer>_bed2`,
`mand_<kamer>`, `bak_<kamer>_bak` en `bed_<kamer>_<id>` voor elk eigen bed-meubel.
`stop()` zet ze terug met `Hotel.render()`.

**Sommenkaart vrijmaken (3 meetronden, teller buiten `teken()`):**
ronde 0 = raakt de kaart rij 0? til hem precies genoeg op (`somLift += ceil(overlap)`).
ronde 1 = nog steeds? dan is er boven de rij geen kader meer → kaart **ernaast**
(links van rij 0, `plekPx(0, -(rijbreedte/2 + 8 + kaartbreedte/2), 0)`).
ronde 2 = is ernaast slechter? dan tóch weer erboven. Daarna staat het vast;
`somOpnieuw()` reset bij nieuw kader, nieuwe opdracht of nieuwe start.
Meetvertraging telkens **90 ms**.

### 3.5 Beurtverloop

**Bedje leggen** — sleep uit de kist naar een strookje, of tik het strookje aan.
* Rij al vol → `Snd.zacht()`, wolkje `bd_op` op `plekPx(r, -goot, 0)` met
  icoon 🛏 en getal `perRij`, klas `hulp`, na **1800 ms** weg.
* Kist leeg → `Snd.zacht()`, wolkje `bd_op` bij de kist met icoon 🧺 en getal 0,
  na **1800 ms** weg.
* Anders: `rij[r]++`, wolkjes weg, `Snd.plop(1)`, opslaan (debounce 400 ms),
  hertekenen.

**Terug** (`bd_undo`): haalt er één weg uit de laatst aangeraakte rij, anders uit
de hoogste rij die iets bevat; `Snd.terug()`. Niets te halen → `Snd.zacht()`.

**Controleren** (🐾 `bd_klaar`, of tikken op de deur van de kamer — bedden leent
elke deur van de kamer via `hotspots.pak('deur_<kamer>_<naar>', check)`):

```
tel per strook: vol (== perRij), oneven (0 < n < perRij), leeg (n == 0)
over = doel - totaal
GOED als: over == 0 en er is geen oneven rij en vol == rijen
```

Anders `missers++` en **één** zacht wolkje `bd_fout` (klas `hulp`, prio 14),
op de plek van het probleem — nooit een kruis, nooit een stap terug:

| situatie | plek | icoon | getal |
|---|---|---|---|
| scheve rij `oneven` | `plekPx(oneven, -goot, 0)` | 🛏 | `+ (perRij - n)` |
| er kan nog een héle rij bij | `plekPx(leeg, -goot, 0)` | 🛏 | `+ min(over, perRij)` |
| nog bedjes in de kist | bij de kist | 🛏 | `+ over` |
| een rij te veel | `plekPx(max(0, vol-1), -goot, 0)` | ↩ | `- max(1, (vol - rijen) * perRij)` |

Daarna: het laatste dier zonder bed loopt naar de deuropening en wacht; 2000 ms
later nog een tekenbeurt. Bij **misser 2** verschijnt Wolkje na 900 ms vanzelf.

**Kamerhulp Wolkje** (🐑): zet `spook = true` (spookbedjes op de eerste lege
rij), legt het spookcijfer `perRij` naast die rij (`getalTag`, klas `hotspook`,
titel `"zoveel in een rij"`), en zet een wolkje `bd_wolkje` met icoon 🐑, getal
`perRij`, tekst `"in elke rij"`. **Tikken op dat wolkje legt de rij écht neer**
(`rij[r] = perRij`, `Snd.ja()`). Verder: `zetGezien('bedden_wolkje')`,
`Snd.brief()`.

### 3.6 Gelukt — de dekengolf

```
klaar = true ; fase = 'feest' ; spook = false ; bezig = true
state.tel(missers === 0, nu - t0)
Snd.tover()
somAf()                       # de kaart wordt de eindkaart, afgevinkt
wolkje bd_goed: ⭐ + doel, klas 'goed', prio 14, op plekPx(0, goot, 0)
bouwBedden(doel, ...)         # één bed per 260 ms
```

`bouwBedden` zet per stap het **vrije vakje dat het verst van alle bedden af
ligt** (zelfde greedy als `ruweCapaciteit`), via `wereld.voegBed(K, {x, z})`,
`Snd.plop(1)` per bed. Past er geen bed meer bij, dan stopt het — **nooit een
half bed**.

Daarna:
* `nieuw = aantal echt gelegde bedden`, `over = doel - nieuw`.
* Alleen als er echt een bed bij kwam: `taakKlaar('bedden', {sterren: 1})`.
  Kwam er niets bij → geen ster, en het wolkje zegt `🛏 "vol ✓"`.
* Anders `bd_goed` = `🛏 +<nieuw>`, klas `goed`.
* `hotspots.laat()` — de deur is weer gewoon de deur.
* De gasten zonder bed lopen naar hun nieuwe bed: per bed `reis(gast, K, {x: slot.sx, z: slot.sz, na:'blij'})` en `setMood(gast, 'bouncy')`, gestart op **300 + i·480 ms**. Ze gaan er blij *naast* staan — slapen doet het dier pas als de check-in dat bed aan die gast geeft.
* Na **2600 ms**: `fase = 'af'` → alle strookjes, kist, undo, wand, klaar-knop en
  hulp verdwijnen; alleen de eindkaart en één wolkje blijven. Dat is de beloning:
  je ziet de kamer zoals hij nu is.
* Na nog **3400 ms**: `ctx.sluit()`. Tikken op het wolkje sluit meteen.

### 3.7 Alle kinderteksten van bedden, in volgorde van verschijnen

| waar | tekst |
|---|---|
| icoontje | `Bedden` |
| strookje (titel) | `rij ` + (r+1) + `: ` + n + ` van ` + perRij |
| dekenkist (titel) | `dekenkist met ` + mv(n, `bedje`, `bedjes`) |
| undo (titel) | `eentje terug in de kist` |
| sommenkaart, som | `<volle rijen of "?">` + ` × ` + perRij + ` =` |
| sommenkaart, regel 1 | `Leg ` + mv(rijen, `rij`, `rijen`) + ` van ` + mv(perRij, `bed`, `bedden`) |
| sommenkaart, regel 2 | `Zo veel bedden staan er nu` |
| wolkje boven de gast | 🛏 + doel + ` ` + (`bed maken` als doel = 1, anders `bedden maken`) |
| schuifwand (titel) | a + ` × ` + perRij + ` + ` + b + ` × ` + perRij |
| klaar-knop (titel) | `1 gast mag erin` (doel = 1) / doel + ` gasten mogen erin` |
| hulp-knop (titel) | `kamerhulp Wolkje` |
| spookcijfer (titel) | `zoveel in een rij` |
| wolkje van Wolkje | 🐑 + perRij + ` ` + `in elke rij` |
| eindkaart, som | rijen + ` × ` + perRij + ` =` |
| eindkaart, regel | `Nu staat er ` + mv(doel,…) (doel = 1) / `Nu staan er ` + mv(doel, `bed`, `bedden`) |
| eindwolkje | 🛏 `+<nieuw>` — of 🛏 `vol ✓` als er niets meer bij kon |
| kamer vol bij start | 🛏 `vol ✓` |

Enkelvoud/meervoud: `mv(n, enk, mv) = n + ' ' + (n === 1 ? enk : mv)` — dus
"1 bed" en "3 bedden", nooit "van 1 bedden".

### 3.8 Herstellen, kader, stoppen

* `ctx.ui.opKader(fn)` = de opmaat-bus: één melding per échte kaderverandering.
  bedden reageert met: schaal-cache leeg, `somOpnieuw()`, en **260 ms** later
  opnieuw tekenen.
* `stop()` ruimt op: alle timers, de sommenkaart, de wolkjes
  (`bd_wolk, bd_fout, bd_goed, bd_op, bd_wolkje, bd_vol`), het spookcijfer,
  `state.bewaar()`, `hotspots.wisAlles()` (geeft ook de geleende deur terug) en
  `Hotel.render()`.

---

## 4. HET SLEUTELBORD (`sleutels.js`)

### 4.1 Verhaal, kamer, gast

In de receptie hangt een rij nummerplaatjes aan de wand; één of twee plaatjes
zijn leeg en tonen `?`. Aan de balie staat een gast met een sleutellabel (wolkje
`🔑 14` boven zijn kop) en de sleutel zelf als sleepbron bij zijn pootjes. Je
hangt de sleutel op het goede haakje; de gast loopt daarna naar zijn eigen kamer
en boven zijn deur in de gang komt een plaatje `💡 14`.

Welke gasten meedoen: `gastenMetBed()` = alle gasten met een `bed` én een
`kamer`. Heeft niemand een bed → wolkje op het sleutelbord, 🛏 `"nog geen
gasten"`, klas `hulp`, hoog 26, en na **1900 ms** sluit het spel zichzelf.
Helper is **buurvrouw Els** (🩺).

### 4.2 De generator (alles gezaaid, dus reproduceerbaar)

`sommen.*` kent geen reeksgenerator; deze is hier afgeleid volgens dezelfde
schaalregel (N = grootte + hoeveelheid werk, band = soort sprong).

```
PLAFOND   = { 3: 20, 4: 100, 5: 1000 }
MAXBLANCO = { 3: 2,  4: 2,   5: 3 }

aantalHaken(N, band)    H = clamp(2 + ceil(max(1,N)/2), 4, band >= 5 ? 4 : 5)
aantalSleutels(N, band) B = clamp(ceil(max(1,N)/3), 1, MAXBLANCO[band])
                        en nooit meer dan het aantal meespelende gasten
perBord(H)              H >= 5 -> 2 lege haakjes per bord, anders 1
zaad                    dag*7919 + N*131 + band*17 + ronde*8191 + 1
handtekening            [N, band, dag, ronde].join('|')
```

**Variant per band en dag:**

| band | dag | variant | rij |
|---|---|---|---|
| 3 | oneven | `telrij` | van = 1 + deel·H, stap 1, plafond 20 |
| 3 | even | `telrij-tien` | van = (20 − H + 1) − deel·H, stap 1 — de tienovergang |
| 4 | dag mod 3 = 0 | `sprong5` | van = 5 + deel·H·5, stap 5, plafond 100 |
| 4 | dag mod 3 = 1 | `sprong10` | van = 10 + deel·H·10, stap 10, plafond 100 |
| 4 | dag mod 3 = 2 | `evenoneven` | van = deel ? 2 : 1, stap 2, label `oneven` / `even` |
| 5 | oneven | `sprong25` | van = 25 + deel·H·25, stap 25, plafond 1000 |
| 5 | even | `kamers` | s = (dag mod 4 = 0) ? 11 : 1 ; verd = 1 + (deel mod 2) ; blok = floor(deel/2) ; van = 100·verd + s + blok·H, stap 1, label `verdieping <verd>` |

Daarna altijd: `van = max(1, min(van, plafond - (H-1)*stap))`.
Waarde van haakje *i* = `van + i * stap`.

**Lege haakjes** (`kiesBlanco(n, hoeveel, rnd)`): kandidaten zijn de indexen
`1 .. n-2` (dus **nooit op de rand**); kies er telkens één met
`kand[floor(rnd() * kand.length)]`, verwijder daarna alle kandidaten met
`|q - k| <= 1` (dus **nooit twee naast elkaar**). Gevolg: bij H = 5 vraagt het
spel om 2 lege haakjes maar kan het er 1 opleveren (kandidaten 1,2,3 — wie 2
kiest houdt niets over). Dat is toegestaan; er komt dan gewoon een bord bij.

**Borden:** zolang er sleutels over zijn en `deel < 3`: neem
`hoeveel = min(perBord(H), over)`, maak de rij voor dat `deel`, kies de lege
haakjes, hang er een gast aan (`gasten[sleutels.length]`; is die er niet, dan
wordt het haakje weer gewoon), en `over -= aantal gekozen lege haakjes`.
Er zijn dus **maximaal 3 borden**.

De opdracht wordt vers gemaakt als de handtekening niet klopt, als hij al
`klaar` was, of als een gast van de opdracht intussen is uitgecheckt
(`gastenKloppen`).

**`controleer(p)`** (de nareken-functie, ook voor de speeltest) eist:
elk haakje `w == van + i*stap`; `1 <= w <= plafond`; alle getallen binnen één
bord uniek; alle getallen over álle borden uniek; het aantal haakjes klopt; er
zijn minstens 2 zichtbare plaatjes per bord; hoogstens 2 lege haakjes per bord;
geen leeg haakje op index 0 of n−1; geen twee lege haakjes naast elkaar; evenveel
sleutels als lege haakjes; geen twee sleutels met hetzelfde nummer; elk
sleutelnummer past op **precies één** haakje en wel op het haakje waar hij bij
hoort; dat haakje is echt leeg.

**Worked examples** (nagerekend met de exacte LCG):

* `N 5, band 4, dag 3, 3 gasten` → H 5, variant `sprong5`, B 2, één bord
  `5, 10, 15, 20, 25` met lege haakjes op index **1 en 3**; sleutels **10** en **20**.
* `N 2, band 3, dag 1` → H 4, variant `telrij`, B 1, bord `1, 2, 3, 4`, leeg op
  index 1, sleutel **2**.
* `N 7, band 5, dag 4` → H 4, variant `kamers`, B 3, drie borden:
  `111,112,113,114` (leeg 2 → sleutel **113**, label `verdieping 1`),
  `211,212,213,214` (leeg 1 → sleutel **212**, label `verdieping 2`),
  `115,116,117,118` (leeg 1 → sleutel **116**, label `verdieping 1`).

### 4.3 Plekken in de receptie (voxels)

De receptie is 120 × 120. Alles staat als breuk (`Rooms.plek`,
`Rooms.hoogte` = `round(w * f)`), dus met de kamer mee:

| naam | breuk | voxels |
|---|---|---|
| `HAAK_MID` | `hoogte(0.625)` | 75 (midden van de rij, x en z) |
| `HAAK_SOM` | 2 × HAAK_MID | 150 (de schuine lijn x + z, vast) |
| `HAAK_DX` | `hoogte(0.1625)` | 20 (stap tussen twee plaatjes in x−z) |
| `HAAK_DX3` | `hoogte(0.2)` | 24 (bij drie cijfers) |
| `HAAK_Y` | `hoogte(0.6)` | 72 |
| `GAST_PLEK` | `plek(0.75, 0.85)` | (90, 102), `GAST_SOM` = 192 |
| `KEY_PLEK` | `plek(0.675, 0.975)` | (81, 117) |
| `ELS_PLEK` | `plek(0.25, 0.975)`, y = `hoogte(0.075)` | (30, 117), y 9 |
| `KAART_HOOG` | `hoogte(0.775)` | 93 |
| `WOLK_HOOG` | `hoogte(0.4625)` | 56 |
| `KEY_HOOG` | `hoogte(0.05)` | 6 |

`haakPlek(i, n, dx, y, schuif)`:
`x = round(HAAK_MID + schuif + dx * (i - (n-1)/2))`, `z = HAAK_SOM - x`, `y`.
De diepte `x + z` blijft dus altijd 150: de rij houdt haar plek in de
tekenvolgorde en staat vóór de balie en de gast.

**Poort (eigenaar 2026-09-23): `kan` — geen knop zonder iets te doen.**  `bedden`:
alleen als ergens nog plek is voor twee bedden en de beurt van vandaag niet al af is
(`kan_nu`, statisch; de capaciteit, `kies_kamer`, `max_stroken` en de signatuur zijn
daarvoor statisch gemaakt).  `voerkar`: alleen als er een leeg bakje is in een kamer
waar iemand slaapt (`Hotel.lege_bakken()`); en een kar in het laatje van een andere dag
telt niet meer — `Hotel.morgen()` zette alleen `state.kar` op null, dus de volgende
ochtend zei het spel "Alle bakjes vol!" terwijl elk bakje leeg was; een nieuwe kar
draagt `dag`.  `meubels`: alleen met munten, een ster of iets dat nog neergezet moet
worden.

### 4.4 De vier opstellingen (X1) — wat de poort moet nabootsen

Na een eerste tekenbeurt op de gewone plekken meet `opbouw()` de échte maten op
(`sl_kaart`, `sl_tag`, `sl_key`, alle `sl_h<i>`) en kiest:

Extra maten: `GAP 4 px` (kaart↔rij), `GAP_WOLK 6 px` (rij↔wolkje),
`KNOP 48 px`, `DIER_HOOG 28 voxels`.

```
dx (stap in x-z) = max(drieCijfers ? 24 : 20, ceil((48 + 5) / (4k)))
                   -> altijd minstens 53 css-px tussen twee plaatjes
rijW  = (n-1)*4*dx*k + knopbreedte
```

**A. `stapel`** (portret en liggende tablet). Kaart op haar hoogte (of tegen de
bovenrand geklemd), de rij precies zo veel lager als de kaart nodig heeft
(`wens = max(rijNat, kaartOnder + 4 + knopH/2)`), het wolkje **onder de rij maar
altijd boven de kop van de gast** (`DIER_HOOG`) en boven de sleutel. Lukt dat →
klaar. Blijft `haakY == HAAK_Y` en `wolkY == WOLK_HOOG` en is er geen dx-correctie,
dan heet het gewoon `gewoon`.

**B. `naast`** (liggende telefoon, kader ≈ 190 px hoog). De kaart uiterst links
(begint op 2 px), de rij rechts ernaast op haar gewone hoogte
(`rijMidX = max(rijNatX, kaartRechts + 4 + rijW/2)`), en het wolkje schuift langs
de wand naar rechts tot het naast de kaart staat, als het anders de kaart raakt.

**C. `krap`** (smal én laag kader). De rij gaat vóór: `haakY` zo laag als het
kader toelaat, wolkje mag over de kop van de gast; past het niet tussen rij en
sleutel, dan gaat het onder de sleutel staan.

**E. `wand` — de eerste keus** (poort, eigenaar 2026-09-23: "ja" op "zal ik het
sleutelspel ombouwen zodat de haakjes langs de muur hangen?").  De plaatjes hangen ÓP
de muur van het sleutelbord, op één hoogte `h`, van boven de voorkant van het bord
naar achteren: plaatje `i` op (1,5; `z0 − i·d`; `h`) aan de linkerwand, (`x0 + i·d`;
1,5; `h`) aan de achterwand.  Een horizontale lijn op de muur loopt op het scherm
schuin omhoog naar achteren, dus van links naar rechts lees je de getallen op
volgorde.  `d = ceil(53 / 2k)` voxels (één voxel langs de muur is `2k` px opzij), en
`h` is de laagste hoogte vanaf 6 waarop de hele rij vrij hangt: binnen het kader,
het midden van elk plaatje op de muur, en niets geraakt — geen meubel of ander
ding (schermrechthoek), niets vasts van een ander, en het bord (21 breed, 6..18
hoog) en de deuren van deze muur (opening + latei) met hun ECHTE schuine vorm,
want hun schermrechthoek is voor de helft lege muur.  De gasten tellen niet mee:
die lopen.  Het begin `z0` is de voorkant van het bord, het midden, de achterkant
of net erachter, in die volgorde.  De kaart zoekt dan een vrije plek bij de rij:
boven het begin, rechts van het eind, onder het begin op de vloer vóór bord en
bankje, of rechts onder het eind — nooit op een plaatje, het bord of de balie.  Een
plaatje aan de muur heeft geen eigen voorwerp (`geen_vlak`).  Op een ruim LIGGEND
kader (korte zijde ≥ 600, breder dan hoog) komt de kaart nooit in de rekenbalk
(`balk: false`): daar zou de ophangkaart de balk in gaan en de vraagkaart niet, de
wereld zou tussen twee stappen krimpen en de haakjes zouden van de muur naar een
rij bovenin springen.  Staand gaan beide kaarten de balk in en hangt de rij hoog
boven de gangdeur langs.  Op een telefoon passen vier tikdoelen niet langs één
muur: daar gelden A–D.

**D. `rechts`** (poort, eigenaar 2026-09-23: "helemaal niet relevant aan waar de
tekst geplaatst is").  Duwen A-C de rij van het bord af — onder het bord, of meer
dan twee banden van haar plek erboven — dan hangt de rij vlak boven het
sleutelbord of één of twee banden hoger (nooit lager: lager is de vloer), met de
gewone stap en anders met de kleinste, en de kaart rechts naast de rij op haar
hoogte, anders vlak onder de rij rechts van het bord; ze mijdt de rij, het bord
en de balie.  Staat de kaart in de rekenbalk, dan is het `gewoon` met die rij.
Aanleiding: aan de linkerwand van de receptie nam de kaart boven het bord de muur
in die de rij nodig had, en terwijl de gast nog achterin stond zakte de rij op het
kleed midden in de kamer.  De kaart schuift daarvoor over de diepte van het bord
(`(x+1, z-1)` = `4k` px naar rechts).

Schuiven langs de wand: `(x+1, z-1)` verplaatst een knop `4k` px naar rechts;
`schuifVoor(px) = ceil(px / (4k))`. Hoogte terugrekenen:
`hoogteVoor(som, py) = (som - (py - py0)/k) / 2`, naar beneden (`laag`) of boven
afgerond. De keuze wordt opnieuw gemaakt bij elke kaderverandering
(`ui.opKader`, met **220 ms** vertraging).

### 4.5 Beurtverloop

`sleutelNu()` = `sleutels[P.nu]`; het bord in beeld is dat van de huidige
sleutel (of het laatste bord als alles op is). De gast van de huidige sleutel
reist naar `GAST_PLEK` met `na: 'wacht'` — tenzij hij daar al binnen 8 voxels
(manhattan) staat.

**Tikken op een plaatje met een getal:** `licht = i`, buren uit,
`Snd.tik()`, hertekenen, en `ui.spreek(...)` leest het voor
(variant `kamers`: de volledige zin, anders alleen het getal).
Het plaatje wordt groter: `1.7rem`, of `1.35rem` bij drie cijfers; een gewoon
driecijferig plaatje staat op `1rem`.

**Sleutel ophangen** (slepen naar `[data-drop="haak"]` of tikken op een leeg
haakje terwijl je een sleutel hebt):
* Al bezet, of verkeerd getal → **mis**.
* `h.w === s.nummer` → **goed**.

**Goed:**
`h.sleutel = gast`, `s.op = true`, buren uit, spookcijfers weg,
`Snd.munt()` (het rinkelen) + `Snd.ja()`,
`state.tel(s.mis === 0, nu - P.t0)`, `P.t0 = nu`, de gast gaat slapen in zijn
eigen bed (`wereld.slaap(gast, kamer, bed)`, `setMood('blij')`), `P.nu++`.
Een kort wolkje aan de gast: 💤 + nummer + `"naar mijn kamer"`, klas `goed`,
hoog 40, prio 13, na **2600 ms** weg. Is er nog een sleutel → volgende gast
halen en opslaan; anders `klaar()`.

**Mis:** `P.missers++`, `s.mis++`, licht uit, **de twee buurplaatjes lichten op**
(`burenVan`: links en rechts; aan de rand de twee plaatjes die er wél zijn, dus
`i+2` of `i-2`), `Snd.zacht()` + `Snd.terug()` (de sleutel glijdt terug),
hertekenen, en het haakje **wiebelt** (CSS-klasse `wiggle`, opnieuw getriggerd
via een reflow; staat stil in rustmodus).
In het antwoordvakje van de kaart komt dan het getallenlijntje
`burenTekst()`: de buren en het gat op volgorde, met ` … ` ertussen, waarbij
het gat `?` is. Voorbeeld: `10 … ? … 20`.

**Els** (vanaf 2 missers, knop `sl_els` op `ELS_PLEK`, klas `hotwolk hulp`,
prio 8): `spook = true` → op elk leeg haakje komt het góede getal als
spookcijfer (klas `hotspook`), en de kaart krijgt een hulpregel
`tip`: `"om en om"` bij label `oneven`/`even`, anders `"+ " + stap`.
Verder `zetGezien('sleutels_els')` en `Snd.brief()`.

**Klaar:** `P.klaar = true`, `taakKlaar('sleutels', {sterren: 1})`,
`Snd.tover()`, opslaan, hertekenen, dan **naar de gang**: daar hangen de
naamplaatjes met de lampjes boven de deuren. Wolkje op de kist: ⭐
`"alle sleutels hangen"`, klas `goed`, prio 13; tikken sluit; anders sluit het
spel na **3400 ms** vanzelf.

**Deurplaatjes in de gang** (`deurPlaatjes`, ook tussentijds): per kamer met
opgehangen sleutels een `getalTag` op het deurpunt, y 26, tekst
`💡 <nrs met " · " ertussen>`, titel `<namen met " en "> slaapt hier: <nrs met " en ">`.
Kamers zonder sleutel krijgen `null` (weg).

**Stoppen:** wie nog met zijn sleutellabel aan de balie stond gaat terug naar
zijn eigen kamer en in bed (`naarKamer(gast, false)`), knoppen weg, geleende
knoppen terug, `Hotel.render()`.

### 4.6 Alle kinderteksten van sleutels

| waar | tekst |
|---|---|
| icoontje | `Sleutels` |
| geen gasten | 🛏 `nog geen gasten` |
| sommenkaart, som | `rijTekst`: (`label: ` als er een label is) + de getallen met `, ` ertussen, waarbij een leeg haakje `__` is — bijv. `5, 10, __, 20, 25` of `verdieping 2: 211, __, 213, 214` |
| sommenkaart, regel | `Welk nummer hoort in het gat?` — bij variant `kamers`: `Welk kamernummer hoort in het gat?` — als alles op is: `De rij is nu af` |
| sommenkaart, antwoordvak | `🔑<nummer>` |
| sommenkaart, hulpregel | `10 … ? … 20` (buren) of `om en om` / `+ 5` (Els) |
| wolkje bij de gast | 🔑 + nummer + ` ` + `hang mij op`, na een misser `kijk bij de buren` (klas `hulp`) |
| sleutel (titel) | `de sleutel van ` + naam + `: ` + (`kamer <w>` bij variant `kamers`, anders `nummer <w>`) |
| leeg haakje (titel) | `leeg haakje`, met Els: `hier hoort ` + w |
| gevuld haakje (titel) | `nummer <w>` / `kamer <w>` |
| voorlezen (variant kamers) | `kamer 214, verdieping 2, kamer 14` |
| Els (titel) | `buurvrouw Els doet het voor` |
| gast loopt weg | 💤 + nummer + ` ` + `naar mijn kamer` |
| einde | ⭐ `alle sleutels hangen` |
| deurplaatje | `💡 14 · 15`, titel `Boef en Muis slaapt hier: 14 en 15` |
| labels | `oneven`, `even`, `verdieping 1`, `verdieping 2` |

---

## 5. HET MEUBELBOEK (`meubels.js`)

### 5.1 Verhaal, kamer, gast

De groeilus: rekenen → inrichten → meer gasten. Er is **geen gast** in dit spel;
het speelt bij de balie van de receptie en daarna in de kamer die je zelf kiest.
Dit is het enige spel van de vijf met een 2D-paneel, en HOTEL.md §9 staat dat
maar voor één ding toe: het **overzicht** (welke meubels bestaan, wat kosten ze) —
alleen pictogrammen en prijzen, geen zinnen. Al het rekenen hangt aan voorwerpen.

### 5.2 Catalogus (prijzen uit HOTEL.md §4, hele euro's)

| type | icoon | naam | prijs | extra |
|---|---|---|---|---|
| `plant` | 🪴 | plant | €1 | |
| `bakje` | 🍽 | voerbakje | €2 | |
| `mandje` | 🧺 | mandje | €3 | |
| `speelmand` | 🧶 | speelmand | €4 | |
| `bed` | 🛏 | bed | €5 | `+1 🐾` — verhoogt de gastenlimiet |
| `badkuip` | 🛁 | badkuip | €8 | |

Sterrenpagina (versiering, nooit rekenen — er is altijd iets te halen):

| sleutel | icoon | naam | sterren |
|---|---|---|---|
| `vlag` | 🎉 | vlaggetjes | 1 |
| `bloem` | 🌸 | bloemetje | 1 |
| `kussen` | 🩷 | kleurkussen | 2 |
| `slinger` | 🎈 | ballonslinger | 3 |
| `ster` | ⭐ | sterrensticker | 1 |

### 5.3 Bandregels

| band | lijstje | buidelplafond | wisselgeld |
|---|---|---|---|
| groep 3 | `maxLijst() = 1` — één ding per keer | `buidelMax() = 10` | **nee**: precies betalen; te veel = munt terugpakken |
| groep 4 | 2 dingen samen (`€1 + €3 = ?`) | 20 | **ja**: `betaald − prijs = ?` |
| groep 5 | idem groep 4 | 20 | ja |

`cap = max(totaal, min(munten, buidelMax()))` is het bedrag dat in de buidel
komt; `rest = munten - cap` blijft in de kassa. De buidel zelf komt uit
`Econ.buidel(cap)` (§2.9), dus élk bedrag t/m `cap` is precies te leggen.

### 5.4 Plekken in de receptie (voxels, kamer 120 × 120)

| naam | breuk | voxels | wat |
|---|---|---|---|
| `KASSA` | decor `kassa` | (66, 60), y 14 | het sommenkaartje |
| `BANK` | `plek(0.55, 0.75)` | (66, 90) | de toonbank (sleepdoel `mbbank`), y 10 |
| `BUIDELPLEK` | `plek(0.075, 0.875)` | (9, 105) | je geldbuidel, y 10 |
| `OKPLEK` | `plek(0.95, 0.25)` | (114, 30) | ✔ klaar met tellen, y 8 |
| `TERUGPLEK` | `plek(0.375, 0.975)` | (45, 117) | ↩ munt terug / 📖 terug naar het boek, y 6 |
| `SPOOKPLEK` | `plek(0.75, 0.625)` | (90, 75) | de spookmunten, y 6 |

`MUNTSOORT = [1, 2, 5, 10]`.

### 5.5 Bladzijde 1 — het overzicht (het enige paneel)

`ui.paneel(html, 'meubelboek')` met:
* kop `📖 Meubelboek`;
* drie chips: `💰 <munten>`, `⭐ <sterren>` (klas `b`), `🛏 <maxGasten>` (klas `c`);
* twee tabknoppen: 🪑 (aria `Meubels`) en ⭐ (aria `Versiering met sterren`);
* per artikel een kaartje van 104 px: icoon (2.1rem), prijs-chip `€n`, bij het
  bed het pilletje `+1 🐾`, en een knop:
  * `maxLijst() > 1` (groep 4/5): knop `＋`, of `<aantal>×` als het al op het
    lijstje staat, aria `<naam> <prijs> euro erbij`;
  * `maxLijst() === 1` (groep 3): knop 🛒 als je genoeg geld hebt, anders 💛,
    aria `<naam> kopen, <prijs> euro`;
* met een lijstje: een chip `<iconen> €1 + €3` plus knoppen 🛒 (`Afrekenen`) en
  ↩ (`Lijstje leeg`);
* versieringpagina: per stuk `⭐ <n>`, `<aantal>×` als je hem hebt, knop 🛒/💛,
  aria `<naam> kopen voor <n> sterren`, en onderaan een bakje met de gekochte
  versiering (maximaal 8 zichtbaar, daarna `+n`);
* onderaan ✖ (`Boek dicht`) → `ctx.sluit()`.

**Lijstje vol** (groep 4/5, al 2 dingen): `Snd.zacht()` en wolkje `mb_vol`
🧺 + getal 2 + `"is genoeg"`, klas `hulp`.

**Te weinig geld** (`tekort`): spaarchip boven het blad
(`💛 <prijs>` + `💰 <munten>`) plus wolkje `mb_spaar`
💛 + `€<totaal>` + `"je hebt €<munten>"`, klas `hulp`, hoog 26, prio 11. Het
meubel blijft gewoon in het boek staan om voor te sparen; er gaat **niets op
slot**.

**Versiering kopen:** genoeg sterren → `state.ster(-n, 'versiering')`, teller
bij, `Snd.ster()`, wolkje `mb_af` met het icoon en `+1`, klas `goed`.
Te weinig → spaarchip `⭐ <nodig>` + `💰 <heb>` en wolkje ⭐ + nodig +
`"je hebt <sterren>"`.

### 5.6 Bladzijde 2 — afrekenen, helemaal ín de wereld

`koop(types)` zet `V.bet` op:
`{types, totaal, stap: types.length > 1 ? 'som' : 'munten', hand: Econ.buidel(cap),
bank: [], somPog: 0, telPog: 0, wisPog: 0, spook: null, hulp: null, rest, soort, t0}`.
Het paneel gaat leeg — de wereld is nu het speelvlak — en je gaat naar de receptie.

**Stap `som`** (alleen als er twee dingen op het lijstje staan, dus groep 4/5):
sommenkaart `mb_som` op de kassa, `open: true`, `max: 2` cijfers, icoon 🛒;
som = de prijzen met ` + ` ertussen + ` =`; regels:
`[somZin, "Hoeveel euro is dat samen?"]` met
`somZin = "Plant €1 en mandje €3"` (eerste letter een hoofdletter).
* fout → `somPog++`, `Snd.zacht()`;
* vanaf **1 poging**: hulpregel `doorTellen(prijs van het eerste ding, prijs van het tweede)` — samen doortellen, bijv. `2 … 3 … 4` (maximaal 12 stappen);
* vanaf **3 pogingen**: spookmunten (`spookZet(totaal, "zoveel is het samen")`);
* goed → `zet(€n).klaar()`, `Snd.ja()`, en **450 ms** later door naar `munten`.

**Stap `munten`:** kaart `mb_bon` (`pad: false`, hoog 24) met
som = `<iconen> =`, antwoordvakje al ingevuld met `€<totaal>`, icoon = 🛒 bij
twee dingen anders het icoon van het meubel, regels
`[prijsZin, "Leg de 🪙 munten op de toonbank"]` met
`prijsZin` = `"Mandje kost €3"` (één ding) of `"Plant en mandje kosten €4"`.

De toonbank (`mb_bank`, sleepdoel `mbbank`) draagt 🧾 en het bedrag `€n`; de
buidel (`mb_buidel`) draagt 🪙 (of 💶 vanaf €10), `€<soort>` als aantal en
`hand` = hoeveel je er nog van hebt. **Tikken op de buidel pakt de volgende
muntsoort die je nog hebt** (`kiesSoort` loopt cyclisch door `[1,2,5,10]`);
tikken op de toonbank legt de munt die je in je hand hebt neer.

* `mb_ok` ✔ (klas `hotwolk goed`, prio 10) = klaar met tellen.
* `mb_terug` ↩ (prio 9) = een munt terugpakken (alleen als er iets ligt).
* Ligt er niets, dan staat op diezelfde plek `mb_boek` 📖 = terug naar het boek
  (nog niet betaald).

**`klaarMetTellen()`**:
```
t = som(bank) ; p = totaal
t == p                      -> betaald(0)
t <  p  : telPog++ ; hulp = "🪙 +€<mist>" + nieuwe regel + doorTellen(t, mist)
          telPog >= 3 -> spookmunten van <mist>, label "dit moet er nog bij"
t >  p en band >= 4 : stap = 'wissel'
t >  p en band == 3 : telPog++ ; hulp = "↩ €<t-p> te veel"
          telPog >= 3 -> spookmunten van <p>, label "zoveel moet het zijn"
```

**Stap `wissel`** (groep 4/5): kaart `mb_wissel`, `open: true`, `max: 2`,
hoog 26, icoon 👛, som `€<betaald> − €<prijs> =`, regels
`["Je gaf €<betaald>, het kost €<prijs>", "Hoeveel krijg je terug?"]`.
Fout → `wisPog++`; vanaf 1 poging hulpregel `doorTellen(prijs, betaald - prijs)`;
vanaf 3 pogingen spookmunten met label `"zoveel krijg je terug"`.
Een munt neerleggen of terugpakken tijdens deze stap zet hem terug op `munten`
en `wisPog = 0`.

**Spookmunten** (`spookZet`): `Econ.splits(bedrag)`, hooguit 4 munten, als één
kaartje `mb_spook` bij `SPOOKPLEK`, klas `hotwolk hotspook`, prio 12; tikken
leest het label voor.

**Betaald:** `state.munt(-totaal)`,
`state.tel(somPog + telPog + wisPog === 0, nu - t0)`,
`wacht = {nog: types}`, `gekocht += types.length`, `Snd.tover()`,
`taakKlaar('meubel', {sterren: 1})`, opslaan, HUD bij, wereld leeg, en één
wolkje `mb_af` op de kassa: `💰 €<wissel> terug` als er wisselgeld was, anders
`✅ €<totaal> betaald`, klas `goed`, hoog 30, prio 12. Na **1200 ms** →
neerzetten.

*(let op: het prikbordkaartje heet `meubels`; `taakKlaar('meubel', …)` vinkt
via de spel-id alsnog het juiste kaartje af.)*

### 5.7 Bladzijde 3 — neerzetten op het voxelraster

Geen paneel: de kamer is het speelvlak. Sta je in de receptie, dan gaat het spel
eerst naar `V.thuis` (de kamer waar je vandaan kwam, of `kamer1`).

* **De doos** `mb_doos` reist met je mee: `volg()` zet hem elke tekenbeurt in de
  kamer waar je nú bent, op `doosPlek(r) = { x: round(r.w * 0.26), z: round(r.d * 0.88) }`,
  y 16, klas `hotbron`, prio 11. HTML: 📦 + het icoon van het eerstvolgende
  meubel + (bij meer dan één) het aantal in een `hand`-pilletje. Loop je door een
  deur, dan merkt `volg()` dat en tekent het spel de vakjes van de nieuwe kamer
  opnieuw (uitgesteld met `setTimeout(0)`, want `volg()` draait midden in de
  tekenlus). Tikken op de doos geeft de tip `✨ "sleep naar een plekje"`.
* De doos is sleepbaar naar `[data-drop="mbvak"]` (neerzetten),
  `[data-drop="deur"]` (naar die kamer lopen) en `bed` / `bak` / `toonbank`
  (dat is bezet).
* **De vakjes:** `vakjes(kamerId)` = de vrije vloervakjes van die kamer,
  gesorteerd op manhattan-afstand tot het **binnenkomstpunt van de eerste deur**
  (`deurPunten[0].ix/iz`), en daarna uitgedund zodat er nooit twee binnen
  **24 voxels** (manhattan) van elkaar liggen. Hooguit **`VAK_MAX = 4`** tegelijk
  in beeld (`mbvak_<kamer>_<id>`, icoon ✨, klas `hotgame`, prio 9,
  titel `hier neerzetten`); zijn er meer, dan staat er een ▸-knop
  (`mb_meer`, prio 8, titel `meer plekjes`) die met stappen van 4 door de lijst
  wandelt.
* **Neerzetten:** `bed` gaat via `wereld.voegBed` (dus de gastenlimiet gaat
  meteen omhoog), al het andere via `wereld.plaatsMeubel(kamer, type, x, z, 0)`.
  Lukt het niet → `bezet(...)`. Lukt het wel: id + type in het eigen laatje,
  `Snd.plop(2)`, opslaan, HUD bij, en een wolkje `mb_neer`:
  * bed → 🐾 + `<maxGasten>` + `"gasten"`, klas `goed`, hoog 26;
  * anders → het icoon + `✓`, klas `goed`, hoog 22.
  Na **2400 ms** weg. Is er nog iets over → opnieuw plaatsen, anders terug naar
  het boek.
* **Bezet:** `Snd.zacht()` + wolkje `mb_bezet` 🚫 `"bezet"`, klas `hulp`,
  hoog 26, na **2200 ms** weg.

### 5.8 Je eigen meubels

Op bladzijde 1 krijgen **hooguit 3 meubels per kamer** twee knopjes ernaast
(klas `hotkar`, prio 8, y 14):
* alleen bij een bed: `mbdraai_<id>` 🔄 op `(x+8, z-8)`, titel `bed draaien`;
* altijd: `mbop_<id>` 📦 op `(x-8, z+8)`, titel `<naam> oppakken`.

**Draaien** = weghalen en op hetzelfde vakje een kwartslag anders terugzetten
(`rot = (rot + 1) mod 2`). Lukt dat niet, dan gaat het bed **in de doos terug** —
nooit kwijt. Wolkje `mb_neer` 🔄 `✓`, klas `goed`, na 1800 ms weg.
**Oppakken** is gratis: het meubel gaat terug in `wacht.nog` en je gaat direct
naar de plaatsstap. Ligt er een gast in dat bed (`state.gastInBed`) → `Snd.zacht()`
en wolkje `mb_slaap` 💤 `"iemand slaapt"`, klas `hulp`, hoog 26.

### 5.9 Alle kinderteksten van meubels

Paneel: `📖 Meubelboek`; aria-labels `Meubels`, `Versiering met sterren`,
`Afrekenen`, `Lijstje leeg`, `Boek dicht`, `<naam> <prijs> euro erbij`,
`<naam> kopen, <prijs> euro`, `<naam> kopen voor <n> sterren`.
Wereld: `is genoeg`; `je hebt €<n>` / `je hebt <n>`;
`Hoeveel euro is dat samen?`; `Plant €1 en mandje €3`;
`Je gaf €12, het kost €9` / `Hoeveel krijg je terug?`;
`Mandje kost €3` / `Plant en mandje kosten €4`;
`Leg de 🪙 munten op de toonbank`; `tik een getal`;
`de toonbank: €n`; `munt van 5 euro (2 in je buidel)`; `klaar met tellen`;
`een munt terugpakken`; `terug naar het meubelboek`;
`zoveel is het samen` / `zoveel krijg je terug` / `dit moet er nog bij` /
`zoveel moet het zijn` / `zo ziet het uit` / `zoveel is het`;
`terug` / `betaald`; `<naam> neerzetten`; `sleep naar een plekje`;
`hier neerzetten`; `meer plekjes`; `bezet`; `gasten`; `iemand slaapt`;
`bed draaien`; `<naam> oppakken`.

---

## 6. TOBBE-TIJD (`tobbe.js`)

### 6.1 Verhaal, kamer, gast

Op het erf (de tuin) staan de tobbes. Uit het schuurrek (de kist) komen schepjes
sop; die verdeel je eerlijk over de tobbes. Daarna sleep je de dieren met de wens
🛁 in een tobbe: ze zakken met een zucht in het sop en komen er blinkend uit.

Meespelende gasten: `gasten()` = alle gasten met een bed. Wie in bad *moet*:
`badgasten()` = gasten met `behoefte === 'bad'` en `!blij`; is die lijst leeg,
dan mag iedereen. Geen gasten → wolkje 🛏 `"nog geen gasten"`, na **1800 ms**
sluit het spel. Helper is **buurvrouw Els** (🩺).

Dit spel levert het prikbordkaartje `bad` (prio 1) — een échte wens van een dier,
dus het staat vóór de gewone klusjes.

### 6.2 Het recept per band

```
PLAFOND = { 3: 10, 4: 20, 5: 36 }
CAP     = { 3: {eerlijk: 5},
            4: {eerlijk: 10, dubbel: 5, half: 10},
            5: {eerlijk: 10, dubbel: 9, half: 11} }

soorten(band) = band <= 3 ? ['eerlijk'] : ['eerlijk', 'dubbel', 'half']
soort   = soorten(band)[(dag + N) mod aantal]
perDier = (soort == 'half' en band >= 5) ? 3 : 2
n0      = max(1, min(N, CAP[band][soort]))
M       = (band >= 5 en soort != 'half') ? 3 : 2        # aantal tobbes
basis   = perDier * n0
T       = (soort == 'dubbel') ? basis * 2 : basis
while T > PLAFOND[band] en n0 > 1 :  n0-- ; basis = perDier*n0 ;
                                     T = dubbel ? basis*2 : basis
while M > 2 en floor(T/M) < 1 : M--                    # nooit een lege tobbe
per  = floor(T / M)
rest = T - per*M
```

| band | soorten | tobbes M | plafond T | rest mogelijk? |
|---|---|---|---|---|
| groep 3 | alleen `eerlijk` — splitsen t/m 10, even/oneven | 2 | 10 | **nee** (T altijd even) |
| groep 4 | `eerlijk`, `dubbel` (verdubbelen t/m 20), `half` (halveren) | 2 | 20 | **nee** |
| groep 5 | idem, plus delen mét rest | 3 (2 bij `half`) | 36 | **ja** |

Nagerekend:

| N | band | dag | soort | T | M | per | rest |
|---|---|---|---|---|---|---|---|
| 3 | 3 | 1 | eerlijk | 6 | 2 | 3 | 0 |
| 5 | 4 | 3 | half | 10 | 2 | 5 | 0 |
| 6 | 4 | 2 | half | 12 | 2 | 6 | 0 |
| 7 | 5 | 5 | eerlijk | 14 | 3 | 4 | **2** |
| 7 | 5 | 4 | half | 21 | 2 | 10 | **1** |
| 9 | 5 | 6 | eerlijk | 18 | 3 | 6 | 0 |

De stand wordt vers gemaakt zodra `dag`, `N` of `band` verandert, of als de
vorige stand `stap === 'af'` was; anders hervat hij uit `ctx.data().stand`.
Beginstand: `stap = (soort == 'eerlijk') ? 'vullen' : 'vraag'`;
`rek = eerlijk ? T : (dubbel ? basis : 0)`; `tob = [0,…]` en bij `half` gaat
**alle** sop alvast in tobbe 0 (`tob[0] = T`).

### 6.3 Tobbes neerzetten

Het erf heeft één vaste tobbe (slot `tobbe`, voxel (32, 94)). De rest zet het
spel er zelf bij met `wereld.plaatsMeubel('tuin', 'badkuip', x, z)`; die ids
staan in het eigen laatje (`d.kuipen`), zodat er na "Verder spelen" nooit een
tweede rij bij komt. Elke tobbe die het spel zelf neerzet krijgt het merkje
`spa: 1` in de gedeelde meubellijst; een badkuip die het kind zélf voor €8 in het
meubelboek kocht (die staat in `spel.meubels.mijn`) krijgt dat merkje **niet**,
en telt gewoon mee als tobbe. Zo is inventaris altijd van aankoop te
onderscheiden.

`kiesPlek(gekozen)` kiest uit de vrije vloervakjes van de tuin het vakje dat op
het **scherm** het mooist naast de rij past:
```
du = |(v.x - v.z) - (q.x - q.z)|      # horizontaal
dd = |(v.x + v.z) - (q.x + q.z)|      # verticaal
verboden als du < 50 en dd < 46 (ze zouden elkaar afdekken)
score = -maxDd*1.5 - |minDu - 62|*0.6     # zelfde rij, ruim ernaast
```
Lukken er minder tobbes dan `M`, dan herschaalt het spel de som
(`herschaal(M)`: `per = floor(T/M)`, `rest = T - per*M`). Minder dan 2 tobbes →
wolkje 🛁 `"geen plek"` en na 1800 ms sluiten.

De tobbes worden gesorteerd op `x - z` (links naar rechts op het scherm) en
`P` bevat er precies `M`.

### 6.4 Plekken (alles vanaf de tobbe-rij, in echte pixels)

```
rijD()  = gemiddelde (x + z) van de tobbes
inDeLucht(ver, hoogPx):
   y = round(hoogPx / pxPerHoogte)
   boven = kader-bovenrand van de tuin + 34 / pxPerVoxelY
   als (rijD - 2y) < boven : y = round((rijD - boven) / 2)
   plek = { x: round((rijD + ver)/2), z: round((rijD - ver)/2), y }
voorRijDiepte():
   wens  = diepste tobbe (x+z) + 62 / pxPerVoxelY
   onder = kader-onderrand - 46 / pxPerVoxelY
   return min(wens, onder)
opGras(uPx): ver = uPx / pxPerVoxelX, op diepte voorRijDiepte(), y 0
```

| ding | plek |
|---|---|
| tobbe-knop `tb_kuip<i>` | de tobbe zelf, y = `round(52 / pxPerHoogte)`, klas `hotkar`, prio 12, sleepdoel `tobbe` |
| cijfer op de tobbe `tb_n<i>` | `getalTag` op de tobbe, y 0 (verdwijnt zodra Els spookcijfers legt) |
| schuurrek `tb_rek` | het decor `kist` in de tuin (95, 23), hoog 14, prio 10 |
| sommenkaart `tb_som` | `opGras(0)`, hoogte `somHoog()` |
| kraantje `tb_kraan` | `opGras(150)`, y 0, prio 9 |
| kannetje `tb_kan` | `opGras(-150)`, y 0, prio 9, sleepdoel `tobbe` met data `kan` |
| ✓ klaar `tb_klaar` | `opGras(96)`, y 0, prio 13 |
| Els / opnieuw | `opGras(-96)`, y 0, prio 8 resp. 7 |
| vraagkaart `tb_vraag` | `inDeLucht(0, 110)` — hoog boven de rij, zodat het cijferpad eronder past |
| alle wolkjes `tb_zeg` etc. | `inDeLucht(0, 110)` — één vaste boodschapplek |

`somHoog()` = `round((kaderhoogte < 430 ? 26 : -16) / pxPerHoogte) + somLift`.
Na het tekenen meet `somPast()` na of de kaart binnen 8 px van de onder- of
bovenrand komt en corrigeert met hele hoogtestappen (`somLift`, geklemd op
±40, hooguit **5** rondes, nameten na **90 ms**).

`rand()` = `per + 2` — dat is de rand van de tobbe; méér erin laten lopen is een
overloop. Het **peilglaasje** op de knop is 30 × 34 px: de waterhoogte is
`min(100, round(n * 100 / max(per + 2, 3)))` procent, de streep staat op
`round(per * 100 / cap)` procent en is groen (`#5EBE97`) als het klopt, roze
(`#E58FA8`) als niet — maar alleen als `S.lijn` aan staat (na een misser of als
het goed is). In het glaasje staat altijd het getal (12 px vet, tekstbodem), en
ernaast 🫧 (of 💦 bij een overloop).

### 6.5 Beurtverloop

**A. De vraagstap** (alleen bij `dubbel` en `half`) — het enige moment met een
cijferpad:

* `dubbel`: wolkje bij de kist 🧴 + `basis` + `"morgen dubbel"`;
  kaart `tb_vraag` (open, max 2, icoon 🧴), som `<basis> + <basis> =`, regels
  `["Morgen twee keer <basis>", "Hoeveel samen?"]`, goed antwoord = `T`.
* `half`: wolkje bij het kraantje 🚰 + `T` + `"in twee helften"`;
  kaart som `helft van <T> =`, icoon 🚰, regels
  `[<T> + " halveren, " + rest + " over", "Hoeveel in elke helft?"]` als er een
  rest is, anders `["De helft van " + mv(T, "schepje", "schepjes"), "Hoeveel in elke helft?"]`.
  Goed antwoord = `per`.

Fout → `missers++`, `lijn = 1`, `Snd.zacht()`, antwoordvak leeg en een
hulpregel `ui.telMee(...)`: bij `dubbel` `telMee(basis, 2)` (`"6 … 12."`), bij
`half` `telMee(per, 2, rest ? " … en <rest> over." : ".")`.
Goed → `zet(n).klaar()`, `Snd.ja()`; bij `dubbel` komt `rek = T`, bij `half`
worden `tob[0]` en `tob[1]` alvast `per` en `kan = rest` (met wolkje
🫗 + rest + `"blijft over"`). Daarna `stap = 'vullen'`, `lijn = 1`, en na
**650 ms** de tekenbeurt.

**B. Vullen.** Sleep een schepje uit het rek naar een tobbe (of naar het
kannetje), of tik. `HAND = [1, 2, 5]`: tikken op het rek wisselt de schepgrootte
door (`Snd.tik()`), en de bron toont die als `hand`. `Snd.plop(hand)` per schep,
dus het geluid stijgt met de schepgrootte.
* Rek leeg → `Snd.zacht()` + wolkje 🧴 0 `"rek is leeg"`.
* **Tikken op een tobbe terwijl het rek leeg is** giet `min(hand, tob[i])`
  schepjes over naar de **leegste** andere tobbe — zo kun je ook zonder kraantje
  eerlijk verdelen.
* **Overloop** (`tob[i] > per + 2`): al het sop van die tobbe gaat terug op het
  rek, `missers++`, `lijn = 1`, `mors = i`, `Snd.zacht()`, wolkje 🦆 `"te vol"`,
  en alle gasten in de tuin krijgen `setMood('bouncy')` — **ze lachen**, er komt
  nooit een kruis. Na **1400 ms** verdwijnt de 💦.

**Het splitskraantje 🚰** halveert de **volste** tobbe naar de **leegste**:
`m = tob[bron]`, `h = floor(m/2)`, `r = m - 2h`.
* `tob[bron] < 2` of geen doel → `Snd.zacht()` + wolkje 🚰 `"eerst sop erin"`.
* `r != 0` en **band < 5** → dat mag niet: `lijn = 1`, `Snd.zacht()`, wolkje
  ⚖️ + m + `"is oneven"` (even/oneven, groep 3).
* Anders: `bron = h`, `doel += h`, `kan += r`, `Snd.plop(2)`, wolkje
  🫗 + r + `"blijft over"` als er een rest is, anders 🚰 + h + `"en <h>"`
  (klas `goed`).

**Opnieuw ↩** (`tb_opnieuw`, alleen als er al iets gebeurd is en er nog geen 2
missers zijn): alle tobbes leeg, `kan = 0`, `rek = T` (bij `half`: `tob[0] = T`,
`rek = 0`), hulp uit, `Snd.terug()`.

**C. Controle ✓** (`check`), in deze volgorde:

| test | reactie |
|---|---|
| `rek > 0` | wolkje 🥄 + rek + `"nog op het rek"` |
| een tobbe boven `per` | overloop van die tobbe |
| tobbes niet allemaal gelijk | wolkje ⚖️ `"even hoog"` |
| `kan != rest` | wolkje 🫗 + rest + `"hoort hierin"` |
| `tob[0] != per` | wolkje 🥄 + (per − tob[0]) + `"erbij"` |
| alles klopt | `geslaagd()` |

Elke misser: `missers++`, `lijn = 1`, `mors = -1`, `Snd.zacht()`.

**Els** (vanaf 2 missers): `hulp = 1`, wolkje 🩺 + per + `"ieder evenveel"`,
`zetGezien('tobbe_els')`, `Snd.brief()`. Op elke tobbe komt `per` als
spookcijfer (`getalTag`, klas `hotspook`, titel `"zoveel hoort erin"`), en bij
een rest ook `rest` bij het kannetje (titel `"zoveel blijft over"`). De gewone
cijfers op de tobbes verdwijnen zolang Els meekijkt — anders zouden er twee
getallen op één tobbe staan én is er ruimte tekort (hooguit 16 knoppen).

**D. Geslaagd:** `stap = 'baden'`, spookcijfers weg,
`state.tel(missers === 0, nu - t0)`, `Snd.tover()`, en iedereen die nog in bad
moet komt zelf aanlopen (`reis(gast, 'tuin', {x: max(12, P[0].x - 16), z: P[0].z, na:'wacht'})`).
Wolkje ✅ + per + `"even hoog"`, klas `goed`, na **2200 ms** weg.
**De ster valt hier nog niet** — die hoort bij de hele ronde (rekenen + baden).

**E. Baden.** Elk wachtend dier (hooguit 3 tegelijk) krijgt een knopje op zijn
eigen plek (`volg()` loopt mee), html = zijn diericoon + 🛁, klas `hotbron`,
prio 11, titel `<naam> wil in bad`. Het dier is óók sleepbaar naar een tobbe.
Eén tik-afhandelaar: de hotspot (`aan`), de sleep heeft géén `onTap`.

`inBad(id, i)`:
* meer dan 2 dieren in één tobbe → `Snd.zacht()` + wolkje 🛁 2 `"zit vol"`;
* anders: het dier reist naar `(max(12, P[i].x - 7), P[i].z + 7)` met `na: 'blij'`
  en `setMood('bouncy')`;
* had dit dier de wens `bad`: **eerst** `ster()` (taakje afvinken + 1 ster),
  **daarna** `wereld.behoefteKlaar(id, 'bad')` — die volgorde is essentieel,
  want `behoefteKlaar` tekent het prikbord meteen opnieuw en een nog niet
  afgevinkt kaartje zou zonder vinkje van het bord verdwijnen;
* `Snd.plop(1)` en wolkje 😌 `"lekker warm"` (klas `goed`) op de vaste
  boodschapplek, na **2600 ms** weg;
* is daarna niemand meer met een badwens over → **1200 ms** later `klaarMetBaden()`.

Dieren die nog onderweg zijn: het spel tekent hooguit **8 keer** met **900 ms**
tussenpozen opnieuw tot hun knopje er staat.

**F. Klaar:** `stap = 'af'`, `ster()` (valt hooguit één keer per ronde),
`Snd.hoera()`, prikbord bij, en wolkje ⭐ `"blinkend schoon"`, klas `goed`,
prio 13; tikken sluit, anders sluit het spel na **3200 ms**.

### 6.6 Alle kinderteksten van tobbe

`nog geen gasten`; `geen plek`;
`rek met 6 schepjes, pak 2`; `tobbe 1: 3 van 3`; `schepjes in tobbe 2`;
sommenkaart som `3 + 3 =` (of met kannetje `4 + 4 + 1 =`),
regel bezig `["<T> in <M> tobbes", "Verdeel het eerlijk"]`,
regel af `["Overal <per> erin", "Zo is het goed!"]`;
`splitskraantje: halveren`; `kannetje: <n>`; `zo is het goed`;
`klaar met badderen`; `buurvrouw Els doet het voor`; `opnieuw beginnen`;
`morgen dubbel`; `Morgen twee keer 6`; `Hoeveel samen?`;
`in twee helften`; `helft van 21 =`; `21 halveren, 1 over`;
`De helft van 10 schepjes`; `Hoeveel in elke helft?`;
`rek is leeg`; `blijft over`; `en 5`; `is oneven`; `eerst sop erin`;
`te vol`; `nog op het rek`; `even hoog`; `hoort hierin`; `erbij`;
`ieder evenveel`; `zoveel hoort erin`; `zoveel blijft over`;
`<naam> wil in bad`; `zit vol`; `lekker warm`;
`mag in de tobbe` / `mogen in de tobbe`; `blinkend schoon`.
Meervoud via `mv(n, enk, meerv)`, net als bij bedden.

---

## 7. DE VOERKAR (`voerkar.js`)

### 7.1 Verhaal, kamer, gasten

Twee fasen. **Vullen** in de keuken: op de voerkast hangt één sommenkaartje met
de opdracht in twee gewone zinnen; uit de zak komen koekjes die je over de
bakjes op de vloer verdeelt, met de rest in de snoeppot. **Het rondje**: zodra
de kar klopt duw (sleep) je hem door het hotel en vul je de bakjes in de kamers.

Meespelende gasten: alle gasten met een bed. Geen gasten → wolkje 🛏
`"nog geen gasten"` en na **1800 ms** sluiten.
Helper is **buurvrouw Els** (🩺). Dit spel is de referentie-implementatie van
HOTEL.md §9.

### 7.2 De som

`ctx.state.sommen.deel(N, band, dag)` (§2.3) levert `T` (koekjes in de zak),
`k` = per gast (`K.per`) en `r` = in de pot (`K.rest`). In band 3 is dat exact de
bevroren `koekjesSom`.

De kar-toestand leeft in `state.kar` (dus in de savegame, niet in `ctx.data()`):
`{T, per, rest, zak, vak: {gastId: n}, pot, hand, missers, vol, geleverd: {}, t0}`.
Bestaat hij al met een `T`, dan wordt hij hervat.

**Zinnen op de opdrachtkaart** (`zinnen`, altijd twee):
1. `"Verdeel <T> koekjes over <n> gast"` — met `gasten` bij n ≠ 1.
2. `"🫙 Ieder evenveel, de rest in de pot"` — of, zodra Els meekijkt:
   `"🩺 Iedereen <per>, rest in de pot"`.

**De somregel** onder de zinnen (`somRegel`):
* band 3: **leeg** — groep 3 kent het deelteken nog niet, en de lege somrij wordt
  verborgen;
* band ≥ 4 **én `rest === 0`**: `"<T> : <n>"`;
* band ≥ 4 met rest: leeg (delen mét rest hoort pas in groep 5, en `26 : 6` zou
  dat suggereren).

De deler volgt uit het aantal gasten en mag 6 zijn, ook in groep 4: de
**uitkomst** komt uit `sommen.deel` en blijft binnen de tafels die de band kent.

**Keuzestrook** (`keuzes` aan de kaart): drie knoppen met woord —
`🍪 pak 1`, `🍪 pak 2`, `🍪 pak 5` (`HAND = [1,2,5]`). De actieve knop krijgt de
peach-kleur van het hotel (`--peach` / `--peach-d`), **nooit een ✅** (dat teken
betekent hier "klaar"). Op een klein kader (`mini`) vervalt de strook: dan
schakelt een tik op de zak door en staat er `pak 2` op de zak zelf.

### 7.3 De keuken en de indeling

De keuken is 120 × 114. De bakjes staan als échte voxelbakjes
(`Rooms.meubelZet('keuken', 'bakje', …)`, gemarkeerd `tijdelijk`), op breuken van
de kamer — dat geeft:

| # | breuk | voxels |
|---|---|---|
| 1 | (0.05, 0.5789) | (6, 66) |
| 2 | (0.65, 0.0526) | (78, 6) |
| 3 | (0.25, 0.7895) | (30, 90) |
| 4 | (0.85, 0.2632) | (102, 30) |
| 5 | (0.4, 0.9474) | (48, 108) |
| 6 | (0.95, 0.3684) | (114, 42) |
| pot | (0.6, 0.6316) | (72, 72) |

Ze liggen in twee "kolommen" (`x−z` ≈ −60 en ≈ +72), zodat de kaartjes met de
naam erop ook op het scherm in twee kolommen staan. De zak staat op decor `zak`
(66, 18), de kar op (48, 66), `KAR_KNOP` (het vertrekpunt van de spelknoppen) op
`plek(0.5, 0.5)` = (60, 57), tekendiepte `DIEP_UI = 150`.

**Het kader en de maatjes:**
```
mini = breedte * hoogte < 140000     # bv. 326x312 op een telefoon van 360 px
krap = mini of hoogte < 240          # ook: vanaf 5 bakjes altijd krap
RIJ  = mini ? 50 : 52                # rijhoogte in css-px; vanaf 6 gasten 50
kort = (mini en gasten >= 4) ? 4 : 0 # naam afkappen op 4 letters
portret = hoogte > breedte * 0.75
```
`krap` maakt icoon 1.15rem, woord 12 px (tekstbodem!), getal 1rem en zet de
correctie **onder** de naam in plaats van erachter — dat scheelt ruim 50 px
breedte zonder extra hoogte.

**De plaatser** (`pakker`) is het hart van de indeling. Alle plekken worden in
css-pixels uitgerekend en pas daarna teruggerekend naar voxels
(`plek(F, X, Y, diep)`), zodat de knoppenlaag niets meer hoeft te verschuiven —
juist dat verschuiven maakte tekst onleesbaar.
```
STAP_X = 26 px opzij, PAD_X = ±14 stapjes, PAD_Y = ±5 rijen, dy = RIJ
rijY(Y) = 32 + n*RIJ met n geklemd op 0..floor((hoogte - 28 - 32)/RIJ)
kostfunctie: modus 'n' -> px² + py² ; 'h'/'x' -> px*2 + py*3.1 (+6 bij een rijsprong)
             anders  -> py*2 + px*3.1 (+10 als het omhoog moet)
modi: 'y' = blijf bij je voorwerp (hooguit 2 stapjes opzij)
      'x' = blijf op de rij ; 'h' = eerst naast de wens ; 'n' = dichtstbijzijnd
vier ronden: kier 4 px, kier 0, daarna hetzelfde maar een hotel-deur mag
             eronder verdwijnen; anders de plek die het mínst afdekt
gewichten: deuren van het hotel 0.25, opdrachtkaart 6, de rest 1
```
Volgorde van neerzetten: deuren vrijhouden → opdrachtkaart (+ strook) →
knoppen → de zak → de bakjes.

### 7.4 De kaartjes

`chip(ico, woord, getal, erbij, doel)` bouwt elk kaartje:
`<ico><woord><getal>` en, na een misser, het staartje `· <n> erbij` /
`· <n> eraf`; met Els erbij lichtgrijs het doelgetal `→ <n>`.
Krap of met Els → het staartje op een **tweede regel** onder de naam.

| knop | inhoud |
|---|---|
| `vk_zak` | 🍪 + `<zak>` + (staartje) + pilletje `pak <hand>`; `vast: true`; klas `hotbron hotwolk` (+ `leeg`, + `hulp`) |
| `vk_<gastId>` | diericoon + naam + aantal (+ staartje + doel); `vast: true`; sleepdoel `vak`; prio 10 |
| `vk___pot` | 🫙 + `pot` + aantal; prio 9 |
| `vk_klaar` | `🛒 Klaar`, klas `hotwolk goed`, prio 11 |
| `vk_opnieuw` | `↩ Opnieuw`, klas `hotwolk`, prio 7 |
| `vk_els` | `🩺 Els helpt`, klas `hotwolk hulp`, prio 8 (pas vanaf 2 missers, blijft dan staan) |

Knopposities: staand liggen `Klaar` en `Opnieuw` onderin
(`x = breedte·0.74` resp. `·0.26`, `y = hoogte - 27`, of op de laatste rij als er
geen halve knop meer onder past); liggend naast elkaar rechtsonder
(`breedte - 60` en `breedte - 175`). Els staat staand **links, één rij hoger**
(`breedte·0.3`, `laatsteRij - RIJ`), liggend op `breedte - 295`.
Het waterpeil van een bakje in de wereld:
`niveau(n) = n ? max(1, min(4, ceil(n / per * 4))) : 0`.

Diericonen: `puppy 🐶, poes 🐱, konijn 🐰, gans 🦆` (ook via `kind`: `hond 🐶`),
onbekend `🐾`.

### 7.5 Beurtverloop — vullen

* **Verplaatsen** (slepen uit de zak naar een bakje, of tikken op een bakje):
  `k = min(hand, zak)`; is dat 0 → `zakZeg = "zak is leeg"`, `Snd.zacht()`.
  Anders `zak -= k`, het bakje of de pot erbij, feedback gewist, `Snd.plop(hand)`.
* **Opnieuw** ↩: alles op 0, `zak = T`, feedback/Els/zakmelding weg, `Snd.terug()`.
* **Klaar 🛒** (`check`):
  * `zak > 0` → `missers++`, `feedback = true`, `zakZeg = "nog in de zak"`,
    `Snd.zacht()` — en élk bakje vertelt zelf hoeveel er bij of af moet;
  * elk bakje `== per` én `pot == rest` → **gelukt**;
  * anders `missers++`, `feedback = true`, `Snd.zacht()`.
* **Els 🩺** (vanaf 2 missers): `spook = 1` → de tweede zin van de kaart wordt
  `"🩺 Iedereen <per>, rest in de pot"` en elk bakje krijgt zijn doelgetal
  (`→ 4`). Het doelgetal vervalt in een laag kader (< 240 px) of bij ingekorte
  namen — dan zegt alleen de kaart het. `zetGezien('voerkar_els')`, `Snd.brief()`.
  Els blijft staan zolang er twee pogingen op zitten: een kind mag haar zo vaak
  vragen als het wil.

**Gelukt:** `vol = true`, feedback/Els/zakmelding weg,
`state.snoeppot += pot`, `state.tel(missers === 0, nu - t0)`,
`taakKlaar('voer', {sterren: 1})`, `Snd.tover()`, de tijdelijke bakjes worden
opgeruimd, en het rondje begint.

**Waarom Els geen spookcijfers meer legt** (belangrijk voor de poort): vroeger
was elk spookcijfer een aparte knop; bij zes gasten viel de helft weg door het
plafond van 16 knoppen per kamer. Nu zegt Els het waar het kind toch al kijkt —
in de kaart én in het bakje — zonder extra knoppen.

**Herstel na "Verder spelen":** de aantallen (`vak`, `pot`) worden bewaard, de
tijdelijke bakje-meubels niet. `slotsKwijt()` merkt dat en zet de bakjes opnieuw
neer; het kind ziet zijn eigen verdeling terug.

### 7.6 Beurtverloop — het rondje

* Open kamers = kamers met een gast en een bakje, waar nog niet geleverd is.
* **De kar** is zelf een knop (`karhot`, `volg()` loopt mee), html
  `🛒 nog <n> kamer(s)` of `🛒 kar is leeg`, klas `hotbron hotwolk`, prio 11.
  Sleepbaar naar `[data-drop="deur"]` (naar die kamer duwen, `Snd.kar()`) en
  `[data-drop="bak"]` (afleveren). Eén tik-afhandelaar (`aan` → `hoeDan()`), de
  sleep heeft géén `onTap`.
* **Tik op de kar** → wolkje 👉 `"Sleep de kar naar een deur"`, hoog 44.
* Zolang de kar vol is leent het spel de bakje-knoppen van het hotel
  (`hotspots.pak('bak_<kamer>_<slot>', …)`): tikken betekent dan "hier afleveren".
* **Afleveren in een kamer waar de kar niet staat** → wolkje bij het bakje
  🛒 `"Sleep de kar hierheen"`, klas `hulp`, hoog 26.
* **Afleveren** (`lever`): alle koekjes van de gasten in die kamer worden opgeteld
  en op 0 gezet, `geleverd[kamer] = samen`, het bakje in de wereld gaat op
  niveau 4, elke gast krijgt `gegeten = true`, `behoefte = 'spelen'`,
  `blij = false`, `wereld.feest(...)`, `Snd.plop(3)`, opslaan, prikbord bij.
  Daarna — ná het opnieuw tekenen, want dat begint met `wisAlles()` — het
  wolkje 😋 + `per` + `"koekjes"` (of `"koekjes elk"` als er twee gasten in die
  kamer liggen, zodat het getal niet als kamertotaal wordt gelezen), klas `goed`,
  na **2600 ms** weg.
* **De eerste keer** verschijnt bij de kar: 🛒 `"Breng <per> koekjes naar elke gast"`,
  hoog 30, prio 10.
* **Alles rond**: wolkje ✅ `"Alle bakjes vol!"`, hoog 22, klas `goed`, prio 12;
  tikken sluit meteen, anders na **2600 ms**. `klaarMetRondje()` zet
  `state.kar = null` en sluit.

### 7.7 Alle kinderteksten van voerkar

`nog geen gasten`; `Verdeel 17 koekjes over 5 gasten`;
`🫙 Ieder evenveel, de rest in de pot`; `🩺 Iedereen 4, rest in de pot`;
`12 : 3`; `pak 1` / `pak 2` / `pak 5`;
`zak met 12 koekjes, pak 2 per tik`; `nog in de zak`; `zak is leeg`;
`pot`; `<naam> heeft 12 koekjes`; `de snoeppot: 0 koekjes`;
`8 erbij` / `8 eraf`; `hier hoort 4 in`;
`🛒 Klaar` (`de kar is klaar`); `↩ Opnieuw` (`alles opnieuw verdelen`);
`🩺 Els helpt` (`buurvrouw Els doet het voor`);
`🛒 nog 2 kamers` / `de voerkar: nog 1 kamer`; `kar is leeg` / `de voerkar is leeg`;
`Sleep de kar naar een deur`; `Sleep de kar hierheen`;
`Breng 4 koekjes naar elke gast`; `Alle bakjes vol!`;
`koekjes` / `koekjes elk`.

---

## 8. Wat alle vijf gemeen hebben (de checklist voor de poort)

1. **Nooit straffen.** Er is geen rood kruis, geen fouten-teller in beeld, geen
   klok, geen terugzetten. Een misser is `Snd.zacht()` plus één pictogram met
   een getal, precies bij het plekje waar het over gaat.
2. **Eén ster per ronde**, voor het meedoen. `state.tel()` loopt apart en raakt
   nooit sterren, munten of toegang.
3. **De hulp komt na twee pogingen** als knop (bedden 🐑, sleutels/tobbe/voerkar
   🩺) en blijft daarna staan; binnen een kaart is het 1e/2e keer samen
   doortellen en pas de **3e** keer spookvormen (meubels, voerkar).
4. **Alles hangt in de wereld.** Eén sommenkaart tegelijk; het cijferpad is het
   enige 2D-ding; het meubelboek-overzicht is de enige toegestane uitzondering.
5. **Elke kaart draagt een zin** van ≤ 8 woorden en ≤ 40 tekens, met het
   pictogram vooraan op diezelfde regel.
6. **Elk spel bewaart zijn stand** in zijn eigen laatje (voerkar: in `state.kar`)
   en hervat er precies mee; timers en beloften overleven een herlaad niet.
7. **Supersede = stop.** Een ander spel starten, een taakje aantikken of
   `ctx.sluit()` roept `stop()` aan; die maakt de wereld leeg, geeft geleende
   knoppen terug en tekent het hotel opnieuw. Er is geen pauzestand.
8. **Kader verandert → opnieuw indelen** via `ui.opKader` (bedden 260 ms,
   sleutels 220 ms, voerkar en tobbe elke tekenbeurt, meubels niet).

---

## 9. Open questions for the port

1. **Timers in rustmodus.** De code zet `prefers-reduced-motion` alleen in
   `world.js`, `art.js` en CSS. Of de spel-eigen wachttijden (dekengolf 260 ms,
   2600/3400 ms nagenieten, 900 ms wachten op een dier) in rustmodus korter
   moeten, staat nergens. Aanname in dit document: ze blijven gelijk. Bevestigen.
2. **`taakKlaar('meubel')` versus taak-id `meubels`.** Het meubelboek vinkt af
   op de naam `meubel`, terwijl het prikbordkaartje `meubels` heet; het werkt
   alleen omdat `taakKlaar` óók op de spel-id afvinkt. Bedoeld of restje?
3. **`kiesBlanco` kan minder lege haakjes geven dan gevraagd** (H = 5, 2
   gevraagd, kandidaat 2 gekozen → 1 blanco). Er komt dan een extra bord bij.
   Is dat gewenst gedrag of een af te ronden randgeval?
4. **Sleutels: `MAXBLANCO[band]` begrenst zowel het aantal sleutels als de
   gastenselectie** (`gasten.slice(0, MAXBLANCO[band])`). Bij band 5 met veel
   gasten spelen er dus hooguit 3 mee — wie de andere gasten zijn is de
   volgorde van `state.gasten`. Moet dat een expliciete keuze worden (bijv. de
   gasten die net zijn ingecheckt)?
5. **Bedden: de opdracht mag krimpen tot 1 × 1.** Als de kamer bijna vol is
   zakt `perRij` naar 1 en `rijen` naar 1; er staat dan `1 × 1 =` op de kaart.
   Is dat een acceptabele opdracht of hoort het spel dan al "vol ✓" te zeggen
   (de grens ligt nu op capaciteit < 2)?
6. **Tobbe band 5, `half`, N ≥ 7:** `per` kan 10 of hoger worden (`T = 21` →
   `per = 10`) terwijl het peilglaasje op `per + 2` schaalt. Er is geen bovengrens
   op `per` behalve `PLAFOND[5] = 36`; hoe leesbaar is een tobbe met 16 schepjes
   op een telefoon? Niet in de code afgevangen.
7. **Voerkar: `somRegel` kan een deler tonen die niet in de tafels van de band
   zit** (`30 : 6` in groep 4). De code verdedigt dat expliciet in een
   commentaar. Blijft dat zo in de Godot-versie?
8. **Meubels: er is geen bovengrens op `wacht.nog`.** Oppakken en weer oppakken
   kan de wachtrij laten groeien; het spel dwingt niet af dat je eerst neerzet.
   Bewust?
9. **Meubels toont hooguit 3 eigen meubels per kamer** knopjes (draaien /
   oppakken). Meubel nummer 4 en verder zijn dus niet meer op te pakken zonder
   eerst een ander weg te halen. Bedoeld als knoppen-plafond of te weinig?
10. **Sleutels: de gang-plaatjes (`sl_deur_<kamer>`) worden bij `stop()`
    opgeruimd** samen met al het andere van het spel. Horen de `💡`-plaatjes
    boven de deuren permanent te blijven staan na een geslaagde ronde?
11. **`vergelijk()`, `sommen.geld()`, `sommen.klok()` en de planbord-solver**
    zijn bevroren maar worden door deze vijf spellen niet gebruikt. Ze staan in
    §2 zodat de poort ze byte-identiek kan meenemen; bevestigen of ze in deze
    wave überhaupt geport moeten worden.
12. **Twee LCG's naast elkaar** (`dagRnd` met 24-bits uitvoer, `zaadje` met
    32-bits) is historisch gegroeid. Voor byte-identieke uitkomsten moeten beide
    exact blijven — maar wil je ze in Godot samenvoegen tot één helper met twee
    parametersets, of letterlijk twee functies?
