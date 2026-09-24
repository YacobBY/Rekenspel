# Godot-portspecificatie — games B: zwembad, wekker, hinkel, was, kraam

Bron: `demos/dierenhotel/games/{zwembad,wekker,hinkel,was,kraam}.js` (staat van
commit `e8c9bd2`), met de motorcontracten uit `demos/dierenhotel/GAMES-API.md`,
`demos/dierenhotel/games/registry.js`, `rooms.js`, `state.js`, `ui.js`,
`world.js`, `snd.js`, `hotel.js` en de bindende ontwerpregels uit `HOTEL.md` §3,
§4 en §9.

**Leeswijzer.** Alles in dit document is uit de code gelezen en, waar het om
gegenereerde getallen gaat, nagerekend met een losse Node-harnas die de
generatorfuncties letterlijk overneemt (zie *Nagerekend* per hoofdstuk). Wat
niet uit de code volgt staat expliciet als **(inferred)** gemarkeerd. Alle
Nederlandse kindtekst staat letterlijk tussen aanhalingstekens, inclusief
hoofdletters, spaties en het gebruikte minteken. Let op: de code gebruikt op
sommenkaarten het **echte minteken U+2212 (`−`)**, niet het koppelteken; het
teken `…` is U+2026, `€` is U+20AC.

---

## 0. Gemeenschappelijke basis (geldt voor alle vijf de spellen)

### 0.1 Coördinaten en projectie

De wereld is een voxelraster per kamer. Per kamer geldt: `x` loopt naar
rechtsonder, `z` naar linksonder, `y` omhoog. De schermprojectie (isometrie) is

```
scherm-x ≈ pxPerVoxelX · (x − z)
scherm-y ≈ pxPerVoxelY · (x + z − 2y)
```

met `pxPerVoxelX = 2k`, `pxPerVoxelY = k`, `pxPerHoogte = 2k`, waarbij `k` de
huidige kaderschaal is (`ctx.wereld.schaal()` geeft `{g, dpr, k, pxPerVoxelX,
pxPerVoxelY, pxPerHoogte}`). Een **grotere `x + z` staat dichter bij de kijker**
en wordt dus later getekend (staat er vóór). Bij gelijke diepte is de volgorde
niet gedefinieerd; wie dat nodig heeft geeft zelf een `d` mee.

Gevolg dat drie van de vijf spellen gebruiken: een rij voorwerpen die op het
**scherm horizontaal naast elkaar** moet staan, ligt in de wereld op een lijn
van gelijke diepte (`x + z = constant`).

### 0.2 Bandbegrip (HOTEL.md §3)

`ctx.state.band()` geeft 3, 4 of 5 (groep 3/4/5). De band volgt uit
`bandVanN(N)` (N ≤ 3 → 3, N ≤ 6 → 4, anders 5), begrensd door het adaptieve
signaal: `band = max(3, min(bandVanN(N), kunnen + 1))`. `kunnen` verandert pas
na ≥ 6 gemelde items: omhoog bij accuratesse ≥ 0,8 én gemiddelde twijfeltijd
< 7000 ms, omlaag bij accuratesse < 0,5. Goed/fout telt **nooit** voor sterren
of toegang, alleen voor de maat van de volgende som.

`ctx.state.tel(goed, ms)` meldt één item aan dat signaal (bewaart hooguit de
laatste 10, `ms` wordt geklemd op 0…20000).

De schaalregel is `T = k·N + r` met `0 ≤ r < k`; plafond ≤ 20 (groep 3, liefst
≤ 10), ≤ 100 (groep 4 en 5), geld ≤ €20 per betaling.

### 0.3 De sommenkaart (`ctx.ui.somkaart`)

```
ctx.ui.somkaart(obj, som, {
  id, kamer, hoog, icoon, regel, klas, pad, padPlek, open, max,
  keuzes, keuzeTitel, onOk
})  →  { regel(), som(), zet(), hulp(), open(), klaar(), weg(), getal(), id }
```

* `regel` is **verplicht**: één gewone Nederlandse zin met werkwoord of
  vraagwoord, pictogram vooraan op diezelfde regel, **≤ 8 woorden én
  ≤ 40 tekens**. Een tweede korte regel mag als er nog een getal bij hoort;
  drie regels bestaan niet. Overschrijding geeft één `console.warn` per kaartje
  en tekent gewoon door.
* Op één regel past ~34 tekens (gemeten op 420 en 860 px breed); 35–40 tekens
  breekt naar een tweede regel. Op een kader < 360 px is het kaartje 170 px en
  breekt elke zin; daar gaat "het dier blijft zichtbaar" vóór "de zin op één
  regel" en mag het cijferpad toetsen van 44 px hebben (elders 48 px).
* Met `keuzes` heeft de kaart **geen antwoordvakje en geen cijferpad**: er komt
  één knoppenstrook (`hotkeuzes`, `prio 20`, `vast: true`) onder de kaart, met
  per knop een pictogram (`.ico`) **en** een woord (`.lbl`). `keuzeTitel` is het
  toegankelijkheidslabel van die strook (standaard `'kies er één'`).
* De strook hangt op `keuzeY() = hoog − round((kaartH/2 + strookH/2 + 5) / (2k))`
  hoogte-eenheden, dus altijd 5 css-px onder de kaart, op elke schaal.
* Een `somkaart`, zijn pad en zijn keuzestrook staan **vast** (wijken niet uit
  voor andere knoppen; andere knoppen wijken voor hén). Er hoort er hooguit één
  tegelijk in beeld te zijn.
* `padPlek: 'auto' | 'binnen' | 'buiten'` — waar het cijferpad hoort. `'auto'`
  zet het pad ín het kader, behalve als het kader lager is dan 300 px; dan komt
  het als strook (`#padstrip`) ónder het kader.

### 0.4 Wolkje, cijfer op een voorwerp, sleepbron

* `ctx.ui.wolk(obj, {id, icoon, getal, tekst, hoog, prio, klas, tik})` —
  spreekwolkje aan een voorwerp of dier; standaard `hoog` = 52 voxels bij een
  dier, 20 bij een voorwerp; standaard `prio` 9. Inhoud is één regel
  `[icoon] [getal] [tekst]`. Een wolkje aan een **dier** loopt met het dier mee,
  ook naar een andere kamer. Zonder `tik` leest een tik het wolkje voor.
  `ctx.ui.wolkWeg(id)` haalt het weg.
* `ctx.wereld.getalTag(obj, n, {id, y, prio, klas, titel})` — een **cijfer** op
  een voorwerp: geen knop, niet tikbaar, niet focusbaar, **wijkt niet uit**.
  Standaard `y` = 8, standaard `prio` = 4. `n = null` haalt hem weg. De sleutel
  is `'getal_' + (o.id || objectnaam)`.
* `ctx.hotspots.bron(obj, {id, icoon, aantal, hand, hoog, prio, klas, titel,
  tik, sleep:{dropSel, ghostHTML, canDrag, onDrop, onTap}})` — sleepbron met
  teller; `bron.zet(aantal, handgreep)`, `bron.weg()`.
* Maximaal **±16 knoppen per kamer**; daarboven verdwijnen de knoppen met de
  laagste `prio`.

### 0.5 Geen hulp na een fout (eigenaar 2026-09-24) — bindend

> "Nee geef geen hulp na fouten. Kinderen moeten zelf leren rekenen. Fout
> antwoord kiezen moet niet beloond worden met hulp maar juist een teleurgesteld
> dier of andere "bestraffing" in het spel"

De hulpladder is weg, in alle vijf de spellen (en in alle andere; HOTEL.md §9).
Na een fout antwoord verschijnt **niets dat helpt**: geen `hulp`-regel op de
kaart, geen telladder, geen gerichtere zin, geen spookvormen of bleke cijfers,
geen oplichtende knoppen of strepen, geen wolkje dat zegt hoeveel er nog bij
moet of dat het te ver was, geen helper die het voordoet. Wat het kind wél ziet
is het **teleurgestelde dier** van de beurt (`sip`, met `🔄 Nog een keer`
ernaast, §0.6) — of, waar een spel geen dier van de beurt heeft, hetzelfde
wolkje bij het ding van de kaart — en daarna dezelfde vraag. De vaste zinnen
die er vanaf het begin van een beurt staan (de opdracht, de vaste doe-regel van
de wekker) blijven; ze veranderen na een misser niet. (Tot 2026-09-24 stond hier
de hulpladder van GAMES-API §6: samen tellen, nog eens, en bij de derde poging
spookvormen; de wekker al bij de tweede.)

### 0.6 Nooit straffend (HOTEL.md §9) — bindend

Geen rood, geen kruis, geen buzzer, geen timer, geen ster minder, geen herhaling
van een beurt als straf. Een fout antwoord levert een zacht geluid (`snd.zacht`)
plus een teleurgesteld dier — nooit een hulpje (§0.5). De ster hangt aan het
**meedoen**, niet aan goed rekenen.

S5 (eigenaar 2026-09-20) maakt dat scherper: geen herhaling van een *beurt* als
straf, wél dezelfde vraag opnieuw na een sip-pauze van ~1,2 s — het dier van de
beurt is even sip (`World.pose(id, "sip", 22)`), de antwoordstrook van `Ui` staat
in die tijd op slot, en daarna komen **dezelfde vier keuzes in dezelfde volgorde**
terug met leeg antwoordvakje. Het spel houdt zijn eigen `missers` (voor het
adaptieve signaal) en `snd.zacht()`, en verder niets; `Ui.misser(kaart, dier)`
doet het centraal voor de getallenstrook. Een spel zonder getallenstrook (eigen
keuzes, slepen, zwemmen) roept `ctx.ui.misser(kaart, dier)` zelf aan; `kaart`
mag `null` zijn (alleen het dier, geen slot). Heeft een kaart geen dier van de
beurt in beeld (de was, de slaper van de wekker ligt in zijn eigen kamer), dan
hangt `🔄 Nog een keer` bij het ding waar de kaart op mikt. Sinds 2026-09-24 duurt
de sip `Ui.SIP_TIKKEN` = 30 tikken (~2 s), iets langer dan het slot van 1,2 s:
het teleurgestelde dier is nu het hele antwoord op een misser. Een strook zonder
getallen (wekker, weeg, was groep 3, meubels) gaat net zo op slot.

### 0.7 Geluiden (namen, `ctx.snd.<naam>()`, geen argumenten)

| naam | waar in deze vijf spellen |
|---|---|
| `tik` | hinkel (sprongmaat gekozen), was (stuk oppakken), kraam (munt in de hand) |
| `plop(hand)` | was (blokje in de goede krat, `plop(1)`) |
| `terug` | was (mis: stuk terug op de berg), kraam (munt is teruggeschoven) |
| `zacht` | overal "dat is het nog niet" — nooit een foutbuzzer |
| `ja` | goed antwoord / etappe gehaald |
| `hoera` | einde van een beurt (hinkel, was, kraam) |
| `tover` | kraam (het souvenir gaat op het dier) |
| `munt` | kraam (munt op de toonbank) |
| `plons` | zwembad: het water in en tijdens het zwemmen |
| `au` | zwembad: de zachte bots tegen de wand — **nadrukkelijk geen schrikgeluid** |
| `klok` | wekker: de halklok slaat één keer |
| `hup` | hinkel: één sprong naar de volgende steen |

De geluidsband gaat pas open na de eerste echte aanraking van het kind; vóór die
tik doet elk geluid niets. Er bestaan **geen boze geluiden**.

### 0.8 Ster, taakje en prikbord

`ctx.taakKlaar(naam, {sterren})` geeft `sterren` (standaard 1) sterren, vinkt het
taakkaartje af op **de meegegeven naam én op de spel-id**, en bewaart. Een spel
meldt zijn prikbordkaartje in zijn registratie:

```
taak: { id, icoon, tekst | function(state), wanneer: function(state), prio, kamer }
```

`prio` lager = eerder; wensen van dieren staan op 0. Alles met `prio ≥ 5` telt
als "gewoon klusje": die klusjes roteren per dag één plaats (`start =
(dag − 1) mod n`), zodat elk spel aan de beurt komt. Het bord toont **hoogstens
drie** kaartjes, met pictogram en ≤ 6 woorden. Een afgevinkt kaartje blijft de
rest van de dag met een vinkje staan; morgen begint het bord leeg. Zodra een
spel start doet het hotel het prikbord automatisch dicht.

### 0.9 Wensen (`wens` in de registratie)

Het hotel deelt de wensen 🏊 `zwemmen` en 🎁 `souvenir` alleen uit als er een
niet-`stub` spel is dat ze inlost en `unlock(N, band)` doorlaat. Regels:
nieuwe wensen komen alleen op **oneven** dagen (even dagen zijn van de tobbe),
alleen bij gasten met een bed, hooguit één gast per ochtend en twee zodra er
meer dan vier gasten zijn. `ctx.wereld.behoefteKlaar(gastId, wens)` zet de vlag
(`blij`), haalt het wenswolkje weg, bewaart en tekent opnieuw — en geeft **geen**
ster.

### 0.10 Bewegen: `loopNaar`, `stappen`, `pose`

```
ctx.wereld.loopNaar(id, x, z, o) → Promise<bool>     // = stappen(id,[{x,z}],o)
ctx.wereld.stappen(id, punten, o) → Promise<bool>
ctx.wereld.pose(id, naam, duurInTikken) → bool       // 15 tikken = 1 s
```

`o` = `{pose, tempo, perStap(i, punt), na}`. `true` = het laatste punt gehaald in
eindhouding `na` (standaard `'wacht'`, en `'zwem'` bij `pose:'zwem'`). `false` =
de opdracht is **ingehaald** door een ander bevel (nieuwe `loopNaar`/`stappen`,
`ga`, `reis`, `slaap`, `pose`, `feest`, `setMood('blij')`, `solo`, kamerwissel,
uitchecken). Coördinaten zijn voxels **in de kamer waar het dier nu staat**: een
opdracht loopt nooit door een deur (dat blijft `reis`). Tempo schaalt de hele
duur lineair; het dier glijdt door over de punten en remt alleen af voor het
laatste, dus 43 punten over de badlengte kosten net zoveel tijd als één punt
(gemeten 4,3 s bij tempo 1 in een `loop 1.5`-kamer). Springen glijdt met opzet
níet door (≈ 0,6 s per steen).

Houdingen: `zwem` (dier zakt 7 voxels, buik op de waterlijn, zachte deining),
`spring` (parabool per punt met squash bij de landing), `wacht`, `stil`, `rust`,
`zit`, `kijk`, `snuif`, `blij`, `sip`.

### 0.11 Rustmodus (`prefers-reduced-motion: reduce`) — bindend

Wordt één keer gelezen bij het opstarten van `world.js`. In rustmodus:

* er beweegt niets en er zijn geen deeltjes;
* `perStap` gaat **wel** per punt af (met het dier op dát punt), het dier staat
  daarna op het laatste punt en krijgt zijn eindhouding, en de belofte is
  **direct** `true`.

Voor de port betekent dat: alle tel-, geluid- en cijferlogica in `perStap` moet
losstaan van de animatietijd, en elke `.then()` moet ook werken als hij in
dezelfde frame valt. De eigen `setTimeout`-ketens van de spellen (kaart
naleggen, wolkje weghalen, spel sluiten) lopen in rustmodus **onveranderd**
door — dat is geen bug maar het gedrag van de bron. **(inferred: dat is geen
bewuste keuze maar een gevolg; de port mag die wachttijden in rustmodus
inkorten, maar niet overslaan, anders sluit een spel voordat het kind de
eindkaart heeft gelezen.)**

### 0.12 Starten, stoppen en verdringen

`Games.start(id)`: draait er al een ander spel, dan wordt dat eerst gestopt;
prikbord dicht; `Hits.voorrang(id)` (alle knoppen van dit spel zijn VIP, de
knoppen van het hotel wijken uit en de wenswolkjes gaan even weg); als
`def.kamer` niet de huidige kamer is, `World.naar(def.kamer)`; dan `def.start(ctx)`
in een `try`. Gooit `start` een fout, dan is er geen actief spel meer en komt de
toast `'💛 Probeer iets anders'` (klas `kind`).

`Games.stop()`: roept `def.stop()` aan, wist alle hotspots van dat spel, geeft de
voorrang terug, leegt het paneel, herstelt de spelicoontjes en tekent het hotel
opnieuw (de wenswolkjes komen terug).

Elk spel bewaart zijn beurt in `ctx.data()` (= `State.spelData(id)`), dat mee
gaat in de opslag `kws-hotel-v7`. **Een belofte overleeft geen herlaad**; de
stand moet altijd uit `ctx.data()` te herstellen zijn.

**Het dier van de beurt** (Godot-poort, eigenaar 2026-09-23, world.md §5.8): zwembad,
wekker, hinkel en kraam hebben er één; de spelbalk toont het (`🐶 Boef 🔄`) zolang een
ander dier de beurt kan overnemen, en een tik geeft de beurt aan het volgende dier van
`spelers()` (check-in volgorde) in een verse beurt — `Games.start` van hetzelfde spel,
dus precies de verdringing hierboven. Het gekozen dier (`State.s.speler`, alleen deze
sessie) gaat bij elke volgende start vóór de eigen keuze van het spel, zolang het mee
mag doen; een bewaarde beurt van een ANDER dier wordt dan niet hervat maar is gewoon
niet afgemaakt. Er gaat niets af: geen ster, geen munt, en `tel()` telt alleen
afgemaakte beurten. `was` heeft geen dier van de beurt en geen dierknop.

**Het spel begint pas als het dier er is** (eigenaar 2026-09-23: "Bij het zwembad is er
geen volg optie om boef aan te komen tenzij ik eerst op 'terug' druk. Zorg dat de minigame
pas begint wanneer het dier er is"; world.md §5.8). Moet het dier van de beurt de kamer van
het spel nog in lopen, dan stuurt het spel hem met `ctx.wacht_op` en staat er niets dat op
een opdracht lijkt tot hij op zijn plek staat: geen kaart, geen strook, geen cijfer. Het
eigen decor van het spel staat er wel, en bij de deur hangt het hotelwolkje
`🐶 Boef komt eraan` met zijn balk en `👀 Volg` — ook tijdens het spel, zodat het kind met
hem mee kan lopen tot in de kamer van het spel (world.md §6.3). Staat hij er al, of in
rustmodus, dan komt de eerste kaart meteen. PLAN.md R1 ("binnen één seconde") telt voortaan
vanaf zijn aankomst; PLAN N3 stap 1 (zwembad) en N11 (hinkel) zijn daarmee overruled.

---

## 1. G1 — HET ZWEMBAD (`zwembad`)

### 1.1 Verhaal, kamer en gast

Een gast met de wens 🏊 zwemmen zwemt een baan van `L` meter. Het **bad zelf is
de getallenlijn**: het bad van de kamer `zwembad` (`Rooms.get('zwembad').bad =
{x0: 18, x1: 134, z0: 12, z1: 44}`) beeldt de baan lineair af,

```
x(p) = bad.x0 + (bad.x1 − bad.x0) · p / L        met p in meters, 0 ≤ p ≤ L
zwembaan: z = (bad.z0 + bad.z1) / 2 = 28
```

Kamer `zwembad`: 144 × 88 voxels, **buiten** (2026-09-14): geen wanden, vloer
`gras`, `erf`, `loop: 1.5`; de deur naar de tuin zit in het zijhek
(`x = 0`, z 60…72, poort op (4, 66)). Het hek staat op de eigen
`hek_x = hek_z = 4` van de kamer — verder van het water dan het tuinhek, om
ruimte te maken voor het startblok (owner, 2026-09-17: "Doe het hek verder
van beide kanten van het zwembad") — en het loopt **langs de lange
achterkant van het water, niet langs de korte kant bij het startblok**
(owner, 2026-09-23: "zet het hek aan de bovenste zijkant van het zwembad niet
aan de korte kant bij de startblokken"): `hekx`-palen op `z = 4` vanaf
`x = bad.x0 + 14 = 32` tot het eind van de kamer, geen `hekz`; aan de korte
kant staat alleen de rozenboog van de poort. Het hek begint één paal voorbij
de hoek boven het startblok, zodat de 🏊-knop van het blok die hoek vrij
heeft. (Tot 2026-09-23 andersom: een zijhek langs het startblok en achter het
water alleen de palen voorbij de twee uiteinden — owner, 2026-09-17: "Haal
het hek gedeelte dat op het zwembad zit weg".) Vast decor: `plant` op
(136, 80) en **één groot `startblok`** op (14, 28) op de baan (owner,
2026-09-17: "startblokken ... met een trappetje zodat het dier langzaam
omhoog kan springen" en "Maak het startblok groter en doe 1 ipv 3"). De oude
instapvlonder `mat` is weg (owner, 2026-09-17: "haal de oude houten plank
weg"); het 🏊-icoontje hangt nu op het startblok. Dekplekken:
`dek.start = (12, 56)` en `dek.over = (116, 56)` — beide vóór het water;
`over` staat naast de vlag (x 134, z 50) en niet in zijn voet (2026-09-23: op
(132, 56) stond wie eruit klom ín de vlag).

**Regel die hard is:** zet nooit een sta- of dwaalplek in het water. Alle
dwaalplekken, de deur en beide dekplekken liggen in de convexe strook `z ≥ 50`,
zodat geen enkele wandeling het bad kruist. Alleen dit spel zet een dier in het
bad.

**Wie zwemt** (`gastKies`, in deze volgorde):
1. gasten met een bed én `behoefte === 'zwemmen'` én `!blij`: eerst één die al in
   `zwembad` is, anders de eerste van die lijst → `wens = true`;
2. anders de gast met een bed die zich al in `zwembad` bevindt en het dichtst bij
   de startrand ligt (afstand `|d.x − bad.x0| + |d.z − 28|`) → `wens = false`;
3. anders de eerste gast met een bed; als er niemand met bed is, de eerste gast
   überhaupt. Is er helemaal niemand: toast `'🏊 Er is nog geen gast'` (klas
   `kind`) en het spel opent niet.

Heeft het kind op de spelbalk een dier gekozen (§0.12) en heeft dat dier een bed, dan
zwemt dát dier, vóór deze volgorde (`wens` = of het de wens 🏊 heeft en nog niet
`blij` is). `spelers()` = elke gast met een bed, in check-in volgorde. Een bewaarde
baan van een ander dier wordt niet hervat; bij de wissel legt `stop()` de zwemmer op
het dek, `ctx.laat_gaan` laat hem daar plaats maken (of terug naar bed gaan als hij nog
onderweg was), en de nieuwe begint op 0 m.

### 1.2 Aanmelding en start

```
id: 'zwembad'   naam: 'Zwembad'   kamer: 'zwembad'   stub: false
hotspot: { obj: 'mat', icoon: '🏊', label: 'Zwemles', hoog: 12 }
unlock: N >= 1
wens: 'zwemmen'
taak: { id: 'zwemles', prio: 1, icoon: '🏊',
        wanneer: er is een gast met behoefte 'zwemmen' en !blij,
        tekst: 'Zwemles voor ' + naam   (anders 'Zwemles') }
```

Het taakje kijkt voor `wanneer` naar `!g.blij`, maar de tekst zoekt de gast
**ook als hij al blij is** (`zwemGast(s, true)`), zodat het net afgevinkte
kaartje zijn naam houdt.

Ingangen: het 🏊-icoontje op de instapvlonder in de kamer `zwembad`, het
prikbordkaartje 🏊 met `prio 1`, en het wenswolkje van de gast.

### 1.3 Het rekenen per band

`baan(N, band, dag)`:

```
BANDEN = { 3: {k: 5, lo:  8, hi: 20, M: 10, plafond:  20},
           4: {k: 8, lo: 21, hi: 50, M: 30, plafond: 100},
           5: {k: 7, lo: 31, hi: 80, M:  0, plafond: 100} }   // M dynamisch

N   = max(1, N)          dag = max(1, dag)
r   = (N + dag) mod k
L   = klem(k·N + r, lo, hi)
if k·N + r < lo:                  // Godot, eigenaar 2026-09-14: met één of twee
        L = lo + (k·N + 3·dag) mod (hi − lo + 1)   // gasten was elke baan 8 m
M   = (band < 5) ? BANDEN[band].M : (L >= 55 ? 40 : 30)
if band >= 5 and L > M and (L − M) mod 10 == 0:
        L = klem(L + 3, lo, hi);  M = herbereken
if L > 2·M:  L = 2·M
stap = (L <= 20) ? 5 : 10        // afstand tussen meterstrepen
```

| band | k | L-venster | M (max per slag) | meterstreep | bereikbare L (N 1…12, dag 1…8) |
|---|---|---|---|---|---|
| 3 | 5 | 8…20 | 10 | elke 5 m | 8…20 |
| 4 | 8 | 21…50 | 30 | elke 10 m | 21…50 |
| 5 | 7 | 31…80 | 30 (L < 55) / 40 (L ≥ 55) | elke 10 m | 31…39, 41…49, 51…54, 55…59, 61…69, 71…80 |

De +3-schuif in band 5 zorgt dat de rest nooit een rond tiental is: **40, 50, 60
en 70 komen niet voor** (40 → 43, 50 → 53, 60 → 63, 70 → 73). De extra `L ≤ 2M`
klem garandeert dat een baan hoogstens twee etappes kost, dus de tweede kaart is
altijd de schoolsom `L − M = rest` met `rest ≤ M`.

Worked example (band 4, N = 5, dag = 1): `r = (5+1) mod 8 = 6`,
`L = klem(8·5+6, 21, 50) = 46`, `M = 30`, `stap = 10`. Eerste kaart vraagt 30
(want `r = 46 > M`), tweede kaart `46 − 30 = 16`.

**Nagerekend.** De koptekst van het bestand zegt "groep 5 houdt in de praktijk op
bij L = 76". Dat klopt tot N = 10; vanaf N = 11 levert `klem(7N + r, 31, 80)` ook
77, 78, 79 en **80** op. `L = 80` met `M = 40` is precies de `L ≤ 2M`-grens. Voor
de port: het venster is 31…80, niet 31…76.

### 1.4 De keuzes (de vier knoppen)

```
juist(L, M, p) = (r ≤ M) ? r : M       met r = max(0, L − p)   ("zo ver als kan")

wens = [ r, L, M, r − M, juist − 10, juist + 10,
         juist − 1, juist + 1, juist + 2, juist − 2, juist + 3, juist − 3 ]
```

Loop `wens` in deze volgorde af en neem elke waarde `v` over als
`v ≥ 1` **en** `v ≤ plafond(band)` **en** `v ≠ juist` **en** `v` nog niet in de
lijst staat. Stop bij drie afleiders. Vangnet: als er dan nog geen drie zijn, vul
aan met 1, 2, 3, … onder dezelfde voorwaarden.

De juiste knop wordt daarna op plek `plek` ingevoegd:

```
rnd  = LCG(zaad = L·977 + M·131 + p·17 + leg·7 + 1)
plek = min(3, floor(rnd() · 4))
uit  = afleiders.splice(plek, 0, juist)
```

De LCG is dezelfde als in `rooms.js`: `s = (s·1103515245 + 12345) & 0x7fffffff`,
`waarde = s / 0x7fffffff`, startwaarde `s = zaad|0 || 1`; de **eerste** trek na
het zaaien wordt gebruikt. `leg` is het aantal keuzes dat in deze beurt al is
gemaakt, dus de juiste knop staat niet elke beurt op dezelfde plek.

**De ordeningsregel uit de G1-F1-fix is bindend**: eerst de getallen die het kind
in de wereld ziet (de hele rest `r`, de badlengte `L`, het maximum `M`, en wat er
ná deze slag nog ligt `r − M`), dan een rond tiental eraf/erbij, en pas als
opvulling de buren `juist ± 1…3`. Zonder die volgorde staan alle vier de knoppen
binnen drie meter van elkaar (8/9/10/11) en is de kaart een gokje.

**Nagerekend (verified):**

| L | M | p | juist | knoppen (op volgorde) |
|---|---|---|---|---|
| 43 | 30 | 0 | 30 | 43, 13, 20, **30** |
| 43 | 30 | 30 | 13 | 43, 30, **13**, 3 |
| 14 | 10 | 0 | 10 | 14, **10**, 4, 20 |
| 14 | 10 | 10 | 4 | 14, **4**, 10, 3 |
| 76 | 40 | 0 | 40 | 76, 36, **40**, 30 |
| 76 | 40 | 40 | 36 | 76, 40, **36**, 26 |

De kaart van de eigenaar (30 / 43 / 13 / 20 bij een baan van 43 m met max 30) komt
er dus precies uit; alleen de volgorde op de strook is 43 / 13 / 20 / 30.

### 1.5 De beurt: wat er gebeurt bij een tik

`kies(n)` op een keuzeknop:

```
r      = max(0, L − p)
juist  = juist(L, M, p)
soort  = n == juist ? 'goed'
       : n <  juist ? 'kort'
       : n <= r     ? 'veel'
       :              'ver'
meters = soort == 'ver'  ? r          // hij zwemt tot de wand en botst
       : soort == 'veel' ? juist      // hij mag maar M per keer
       :                   n
```

Bij `soort ≠ 'goed'` gaat `misser` omhoog. `leg` gaat altijd omhoog. Het wolkje
gaat weg, **de kaart met de keuzestrook gaat er meteen af** (dat is tegelijk de
rem tegen twee tikken op één vraag: geen kaart = geen keuze open). Dan: zorg dat
het dier in het water op meter `p` ligt, zwem `meters` meter, en daarna:

| geval | wat het kind ziet | geluid |
|---|---|---|
| `ver` | de bots (§1.7) | `au` |
| `p ≥ L` na het zwemmen | precies aan de overkant (§1.7) | `ja` |
| `goed` | wolkje `✅ <meters> m gezwommen`, dan een nieuwe vraagkaart | `ja` |
| `veel` | het dier zwemt `M`, is dan even sip in het water met `🔄 Nog een keer` (1,4 s, `MIS_S` in `games/zwembad/spel.gd`), daarna drijft het weer en komt een nieuwe vraagkaart | `zacht` |
| `kort` | het dier zwemt zover, is dan even sip met `🔄 Nog een keer`, en daarna een nieuwe vraagkaart | `zacht` |

**Nooit straffend en nooit helpend (eigenaar 2026-09-24):** te kort → het dier
zwemt zover en stopt, kijkt teleurgesteld, en er komt een nieuwe kaart met de
rest; te veel → het mag maar `M` per keer, dus het zwemt `M`, kijkt
teleurgesteld, en de rest volgt op de volgende kaart; te ver → het bótst zacht
tegen de wand. Geen rood, geen ster minder, geen herhaling van de beurt — en geen
wolkje met `'nog <L−p> m'` of `'hooguit <M> m'` (tot 2026-09-24), geen hulpregel
op de volgende kaart, geen oplichtende strepen en geen bleke streep in het water.
De sip in het water duurt korter dan de pose van `Ui.misser`, zodat het spel hem
daarna zelf weer laat drijven (`World.blijf(gast, "zwem")`): een pose die in het
water afliep liet hem wegpeddelen.

### 1.6 Zwemmen zelf

* **Eerst de zwemmer, dan de vraag** (Godot-poort, eigenaar 2026-09-23, §0.12): de start
  haalt hem met `ctx.wacht_op(gast, dek.start)` — door de deuren met het hotelwolkje
  `komt eraan` en `👀 Volg` bij het hek — en pas als hij op het dek staat komen het cijfer
  op zijn rug (`0 m`) en de eerste vraagkaart. De baan zelf (streepjes, cijfers op de
  rand, de vlag met `<L> m`) staat er meteen. Een half gezwommen baan wacht op hem op het
  dek waar `stop()` hem neerzette (`dekNu`: `over` vanaf halverwege, anders `start`). Het
  trapje, de duik en het zwemmen blijven wat het eerste antwoord koopt: `zorgInWater`
  hieronder. (Tot 2026-09-23 stond de eerste vraag er meteen en liep hij pas na het
  antwoord het hotel door — PLAN N3 stap 1.)
* `zorgInWater(na)`: staat het dier al in het bad én binnen 3 voxels van
  `x(p)`, dan meteen door; anders `naarWater`.
* `naarWater`: is het dier niet in `zwembad` (sinds hij vóór de vraag al gehaald wordt
  alleen nog een vangnet), dan `reis(id, 'zwembad',
  {x: dek.start.x, z: dek.start.z, na: 'wacht'})` en elke **220 ms** kijken of
  hij er is, met een geduld van **25 000 ms**. Daarna naar de **trappenvoet
  van het startblok** bij het westeinde van het water, `x = blok_x − 8 = 6`,
  `z = 28`, met `tempo 1.2` — `omHetWater` houdt de wandeling droog en binnen
  het hek. Dan **drie trage hopjes** het trappetje op (`pose: 'spring'`,
  `tempo 0.85`, `land_hoogte` 3, 6, 8) en ten slotte een hop naar de
  **voorkant van het blok** (`land_hoogte 9`), een **adem van 0,7 s**, en de
  **duik** naar `x = bad.x0 + 2.5 = 20.5` met `tempo 1.6` en
  `land_hoogte = −ZWEM_DIEP` (de hoogte-bewuste sprong: hij landt in het
  water, niet op het blok; de duik begint aan de voorkant van het blok zodat
  hij het blok zelf niet raakt).
  Daar `snd.plons()` en `loopNaar(x(p), 28, {pose: 'zwem', tempo: 1.1})`.
  De startblokken en het verplaatste hek zijn eigenaarwerk 2026-09-17:
  "startblokken ... met een trappetje zodat het dier langzaam omhoog kan
  springen" en "Doe het hek verder van beide kanten van het zwembad".
* `zwem(n, na)`: `n` wordt geklemd op `0…L−p`. De punten zijn **één per meter**:
  `[[x(p+1), 28], [x(p+2), 28], …]`. Opties `{pose: 'zwem', tempo: tempoVan(L)}`.
  In `perStap(i)`: `p = p0 + i + 1`, het cijfer op het dier wordt bijgewerkt, en
  bij `i mod elke == 0` klinkt `plons`, met `elke = (n > 10) ? ceil(n/4) : 5` —
  dus hooguit vier plonzen over een lang stuk.
* **Een slag die bij de wand eindigt** (de precieze laatste etappe, en elke
  bots) remt af en stopt met zijn **neus** tegen de verre wand, niet met zijn
  midden op `x(L)` — dan stond zijn kop op de tegels achter het water (owner,
  2026-09-23: het dier dat zich stoot "is slecht geanimeerd"). `NEUS = 15`
  voxels (de gastmodellen zijn ~29 lang met hun anker op voxel 13), dus
  `wand_x = bad.x1 − NEUS = 119`. De meters van zo'n slag staan op de
  getallenlijn tot `wand_x − REM` (`REM = 10`); de meters daarna worden gelijk
  verdeeld over dat laatste stuk en traag gezwommen (`TRAAG = 0,6`), zodat het
  cijfer op zijn rug `L` zegt precies als zijn neus de wand raakt. Nog steeds
  één punt per meter, nooit achteruit (`ZwembadBeurt.slag_x`).
* Tempo: `tempoVan(L) = klem(4,3 · 5 / max(1, L), 4,3/15, 1)`. Verified:
  L ≤ 21 → 1,0; L = 22 → 0,977; L = 43 → 0,500; L = 76 → 0,287. Doel: het cijfer
  op de zwemmer blijft leesbaar (≈ 5 m/s) en een hele baan duurt nooit langer
  dan ≈ 15 s.
* Zwemmen buiten het bad gebeurt **nooit**: `zwem` en `naarWater` breken af als
  het dier niet in de kamer `zwembad` is.

### 1.7 De twee einden

**Precies** (`p ≥ L` en geen bots): `snd.ja()`, dan `afronden('precies', …)` met
de kaart `✅` en de regels
`'Precies aan de overkant!'` / `'<naam> zwom <L> meter'`.

**Bots** (`soort === 'ver'`) — sinds PLAN N3 geen einde van de beurt, en
sinds 2026-09-23 (owner: "Bij stoten moet de speler ook opnieuw rekenen met
een andere afstand") ook niet meer dezelfde vraag. Hij heeft de rest
gezwommen en ligt met zijn neus tegen de wand (§1.6); dan, in deze volgorde:

1. de wand gooit hem terug naar meter `p' = ZwembadBeurt.bots_plek(L, M, p,
   leg)` — dat wordt **meteen bewaard**, vóór hij beweegt (§1.12);
2. de aanraking: `snd.au()`, water spat over de wand, wolkje `💛 Au!`;
3. de bonk: zijn kop duikt tegen de wand (`snuif`, 250 ms) en komt dan
   een beetje duizelig omhoog (`kijk`, 950 ms) terwijl er een paar
   twinkelingetjes rond zijn kop draaien — wit en roze, **nooit** de
   sterkleur: de glans blijft de prijs van het precieze antwoord. Samen
   **1200 ms**: zo lang staat `💛 Au!`, en zolang ligt hij stil (twee
   houdingen, geen gewiebel: elke houding is een ander vak voor zijn cijfer,
   zijn naam en het wolkje, en op een telefoon sprongen die bij elke wissel
   naar de andere kant van hem);
4. de terugworp: de wand duwt hem terug door het water naar `x(p')`, het
   cijfer op zijn rug telt terug van `L` tot `p'`, een `plons`; de strepen die
   hij terug passeert worden weer wit;
5. een klein slagje vooruit draait zijn neus weer naar de wand; hij drijft;
6. na `WOLK_S` een **nieuwe vraag vanaf `p'`**: pictogram `🙃`, regel
   `'<naam> botste terug naar <p'> meter'`, regel 2 `'Nog hoeveel meter?'`,
   sombalk `'<L> − <p'> ='`, en de knoppen uit `keuzeGetallen(L, M, p', band,
   leg)`. Een andere afstand, dus opnieuw rekenen.

Er gaat niets af: geen ster, geen etappe; de misser voedt alleen het adaptieve
signaal. In rustmodus ligt hij stil tegen de wand zolang `💛 Au!` staat
(1200 ms) en daarna meteen op `x(p')`, zonder deeltjes.

`bots_plek(L, M, p, leg)` — deterministisch, per slag:

```
r   = L − p                         (≥ 1)
lo  = max(1, ceil(L/5));  hi = max(lo, ceil(L/3))      // een vijfde tot een derde
als r − 1 ≥ lo:  hi = min(hi, r − 1)                    // hij houdt wat hij zwom
                 worp = lo + min(hi − lo, floor(LCG(L·977 + M·131 + p·17 + leg·7 + 3) · (hi − lo + 1)))
anders:          worp = lo, of lo + 1 als lo == r       // dicht bij de wand: de kleinste worp
p'  = klem(L − worp, 1, L − 1)
```

Dus: nooit dezelfde afstand (`worp ≠ r`), nooit op of voorbij de wand, nooit
achter de start, altijd in één slag te halen (`L − p' ≤ M`), altijd ver genoeg
dat zijn neus los van de wand is, en vóór de meter waar hij de slag begon
zodra de baan daar ruimte voor laat. Worked example (band 3, `L = 16`,
`M = 10`): eerst netjes 10 m, dan een tik op 16 → hij zwemt 6 m tot de wand,
de wand gooit hem terug naar **11 m** (`bots_plek(16, 10, 10, 2) = 11`), en de
nieuwe kaart vraagt `16 − 11 =` met de knoppen `keuzeGetallen(16, 10, 11, 3,
2)` = 16 / 10 / **5** / 15 (vóór de bots: 16 / 6 / 10 / 5 met de vraag
`16 − 10 =`).

(De oude HTML-bots — `afronden('bots', …)` met de kaart `💛` en de regels
`'<naam> is aan de overkant'` / `'Het was nog <laatsteRest> meter'` — bestaat
sinds N3 niet meer als einde; de zinnen staan nog in `ZwembadBeurt`.)

De sombalk op de eindkaart is `somAf()`:
`'<L> − <laatsteP> = <laatsteRest>'`, of `'<L> m ✓'` als er nog geen etappe was.

`afronden(soort, zinnen, som, icoon)` doet, in deze volgorde:
1. `klaar = soort` en bewaren;
2. was het een wens, dan `behoefteKlaar(gast, 'zwemmen')`;
3. `state.tel(misser == 0, verstreken ms sinds het begin van de beurt)`;
4. `taakKlaar('zwemles')` — sinds PLAN N3 alleen nog na **precies**: een bots
   is geen einde meer (hierboven), dus de ster hoort bij de baan die echt
   gezwommen is;
5. de eindkaart neerzetten (zonder keuzestrook), `kaart.klaar()` (vinkje), de
   plek-rem vergeten en opnieuw neerleggen;
6. toast `'🏊 Precies aan de overkant! ⭐'` of `'🏊 Aan de overkant! ⭐'`
   (klas `happy`);
7. het dier uit het water halen (§1.8); pas dán, op het droge:
   bij een bots `pose('snuif', 18)` en na **1300 ms** `pose('blij', 45)`, anders
   meteen `pose('blij', 45)`; het cijfer op het dier gaat weg;
8. na **3400 ms** sluit het spel zichzelf (`sluitAls`), met een vangnet op
   **11 000 ms** voor het geval de klim onderbroken werd.

`sluitAls` sluit alleen als de beurt echt af is; ligt er dan nog iemand in het
bad, dan wordt hij eerst met `World.zet` op het dek gezet (`noodUit`).

### 1.8 Het water uit

`uitHetWater`: doel is `dek.over` als `p ≥ L/2`, anders `dek.start`. Ligt het dier
in het bad, dan eerst nog **zwemmend** naar de voorrand (`[klem(d.x, x0, x1),
z1 − 1]`, `pose 'zwem'`, `tempo 1.2`), dan **een hop over de rand het dek op**
(`[zelfde x, z1 + 6]`, `pose 'spring'`, `tempo 0.9`, `land_hoogte 0`, met een
spatje — 2026-09-23: hij liep het water uit alsof hij erop stond, en een
wandeling na de duik kwam aan op de diepte van die duik, zodat hij verzonken
in de tegels stond) en daarna lopend naar zijn dekplek (`tempo 1.2`,
`na: 'wacht'`). Zo begint er nooit een dwaaltocht vanuit het bad.

### 1.9 Eigen decor

Twee eigen voxelmodellen (`Rooms.registerModel`), beide in blauw/roze zodat ze
nooit dezelfde kleur hebben als de bijna witte steenrand:

**`zb_streep`** (meterstreep, parameter `groot`): kleuren `#4C7FA6` (groot) of
`#8FB4CC` (klein), knopje `#FFFDF3`.
`bx(−1, 0, −2, 2, 1, 4)` = de streep over de steenrand, `bx(−1, 1, −1, 2, h, 2)`
= het stokje met `h = groot ? 7 : 4`, `bx(−2, h+1, −2, 4, 1, 4)` = het witte
knopje bovenop.

**`zb_vlag`** (de vlag op L meter): voet `#EDEFF6` `bx(−3, 0, −3, 7, 1, 7)`, mast
`#B98F62` `bx(−1, 1, −1, 2, 21, 2)`, en een driehoekig vaantje `#F5A8BE`: voor
`i = 0…6` een `bx(1, 21−i, −1, 7−i, 1, 2)`.

`bouwDecor()`: voor `m = 0, stap, 2·stap, …` tot (maar niet op) `L` een streep op
`x = round(x(m))`, `z = bad.z1 + 2 = 46` — de **voorrand**, want de getallenlijn
ligt vóór het water en nooit in het achterhek (owner, 2026-09-16: "de duikplek
zit door een hek heen"; oud: `bad.z0 − 2`), met `groot = (m mod 2·stap == 0)`.
De vlag staat op `x = round(x(L))`, `z = bad.z1 + 6 = 50`, op het dek net
achter de strepen (oud: `bad.z0 − 6`, dat buiten het hek viel).

Cijfers op de rand: alleen op **grote** strepen, en alleen als `m mod labelStap
== 0` met

```
labelStap(k):  stap2 = 2·stap
               zolang stap2 < L en ((x1−x0)/L · 2 · k) · stap2 < 34:  stap2 += 2·stap
```

dus: label ruimer zodra twee labels dichter dan 34 css-px op elkaar zouden staan.
De labels hangen op `y = 11`, `prio 6`. Het getal op de vlag is `'<L> m'` op
`y = 34`, `prio 8`. Het cijfer op de zwemmer is `'<p> m'` op `y = 18`,
`prio 10`, en loopt met hem mee.

### 1.10 De kaart en haar marges (bindend — G1-F2)

Het bad ligt diagonaal over het hele kader, dus één vaste plek voor de kaart dekt
vroeg of laat de zwemmer af. De kaart zoekt daarom zijn plek **in kaderpixels**,
rond het vak waar het dier op dit moment staat.

Ijkpunt is `World.vloer()`; heen en terug:

```
kader-x = vloer.x + (2(x − z) + 2·d) · k
kader-y = vloer.y + ((x + z) − 2y) · k
terug op diepte  diep = x + z:
        u = (X − vloer.x)/k − 2d ;  v = (Y − vloer.y)/k
        x = (diep + u/2)/2 ;  z = (diep − u/2)/2 ;  y = (diep − v)/2
```

met `d = kamer.d = 88` en `diep = 300` (de kaart staat vooraan).

**Marges (in css-px):**

| naam | waarde | betekenis |
|---|---|---|
| `MARGE` | **8** | lucht die de kaart houdt van de zwemmer én van het cijfer op de vlag. Acht px, zodat er ná het afronden van de hotspot-laag (die op een tiende px neerzet) nog minstens zes px lucht zichtbaar overblijft |
| `RAND` | **6** | dezelfde lucht naar de kaderrand |
| `KRAP` | **2** | de harde kaderrand: hier mag niets meer voorbij |
| `EPS` | **0,01** | speling tegen kommagetallen |
| `gat` | **5** | verticale kier tussen kaart en keuzestrook |

Maten: `K = gemeten kaartmaat` (terugval 200 × 78), `R = gemeten strookmaat`
(terugval 230 × 62), `nodig = K.h + (strook ? gat + R.h : 0)`,
`halfW = max(K.w, R.w)/2 + 2`.

**Vier kandidaatplekken, in volgorde van voorkeur:**

| kant | X | Y (bovenrand) |
|---|---|---|
| `onder` | midX | `max(vrijVak.bot + MARGE, F.h − RAND − nodig)` |
| `boven` | midX | `RAND` |
| `links` | `vrijVak.x0 − MARGE − halfW` | midY |
| `rechts` | `vrijVak.x1 + MARGE + halfW` | midY |

met `midX = klem(F.w/2, halfW, max(halfW, F.w − halfW))` en
`midY = klem((F.h − nodig)/2, RAND, max(RAND, F.h − nodig − RAND))`.

De eerste plek die (a) helemaal binnen `KRAP…F.w−KRAP` × `KRAP…F.h−KRAP` valt en
(b) minstens `MARGE − EPS` lucht houdt van zowel het vrije vak als het
vlagcijfer, wint. Past er niets, dan de plek met de meeste lucht die nog binnen
het kader valt (`kant = 'krap'`), en anders zo laag als het kader toelaat.

**Het vrije vak** (`vrijVak`) is het dier plus zijn naamplaatje:
hoogte `36 · 2 · k` px, halve breedte `30k + 10` px rond `csX(x, z)`, met de
voet op `csY(x, z, 0)`. Daarbij komt de **lift** van de zwemmer: `world.js`
tekent een zwemmer niet op zijn vloervak maar `ZWEM_DIEP · HG` voxels lager (in
een liggend kader ≈ 16 css-px) en hij deint daar ook nog in op en neer (`bob`).
`zakOnder = (lift + max(0, bob))·k`, `zakBoven = (lift + min(0, bob))·k`. Zonder
die correctie lag de onderrand van de kaart precies op de buik van de zwemmer —
de gemeten G1-F2-fout was een overlapstrook van 44 × 1 px. Het naamplaatje wordt
echt opgemeten (het hangt boven het dier en is breder) en het vak wordt daarmee
uitgebreid. Is het dier nog in een andere kamer, dan rekent de kaart met de
instapkant van de baan (`x = bad.x0`, `z = 28`).

**Het vlagvak** is het gemeten doosje van `[data-hot="getal_zb_vlagtag"]`.

**Twee extra regels die de port over moet nemen:**

1. *Verse knop.* Een nieuw geplaatste hotspot staat één tekenbeurt lang nog
   zonder transform, dus linksboven in het kader (gemeten: de eindkaart op
   py 0 in een kader van 386 × 468, terwijl het anker py 356 zei). Daarom
   schrijft het spel het gemeten mikpunt zelf op de knop, in exact de vorm die
   de laag gebruikt: `translate(-50%,-50%) translate(<mx>px,<my>px)` — maar
   alléén als de laag er nog niets op gezet heeft.
2. *Plek-rem.* Een knop wordt alleen verzet als hij écht ergens anders hoort:
   verschilt de nieuwe voxelplek in x, z of y minder dan **0,02**, dan blijft
   hij staan. Zonder die rem verschuift de kaart bij elke nameting een
   haarbreedte, en een tik die net op dat moment landt valt naast de knop.
   Na het maken van een **verse** kaart wordt de rem gewist (`plekVergeet`).

**Naleggen na het tekenen:** `kaartLegStraks()` legt meteen én op
**140, 420, 900 en 1800 ms**. Reden: na een kamerwissel of een herlaad zakt het
kader nog (de kamerbalk breekt af, de liggende schil klapt in); één meting gaf
een strook op py 350 in een kader van 294 px hoog. Ook `ctx.ui.opKader(...)`
(kantelen, andere kadermaat) roept dit aan.

Op de **eindkaart** is dit extra kritiek: `kaart.klaar()` tekent de kaart opnieuw
op haar maak-voxel (4, 4) — midden boven het water. Daarom: eerst
`plekVergeet()`, dan `kaartLegStraks()`. Zonder die twee regels hangt de
eindkaart 3,4 s over het bad en over de meterstrepen.

### 1.11 Kindtekst, letterlijk en op volgorde

| moment | tekst |
|---|---|
| icoontje in de wereld | label `'Zwemles'`, icoon `🏊` |
| prikbord | `'Zwemles voor <naam>'` (of `'Zwemles'`) |
| kaart 1 (p = 0) | regels `'Het bad is <L> meter lang'` / `'Max <M> meter per keer'`; sombalk `'nog <L> m'` |
| kaart n (p > 0) | regels `'<naam> is bij <p> meter'` / `'Nog hoeveel meter?'`; sombalk `'<L> − <p> ='` |
| keuzestrook | titel `'hoeveel meter zwemt hij?'`, knoppen `🏊 <v> m` |
| goed | wolkje `✅` + `'<meters> m'` + `'gezwommen'` |
| te veel / te kort | het dier sip in het water met `🔄 Nog een keer` — geen tekst met de rest of het maximum (eigenaar 2026-09-24) |
| bots | wolkje `💛` + `'Au!'` (1200 ms) |
| kaart na een bots | pictogram `🙃`, regels `'<naam> botste terug naar <p> meter'` / `'Nog hoeveel meter?'`; sombalk `'<L> − <p> ='` |
| eind precies | kaart `✅`, `'Precies aan de overkant!'` / `'<naam> zwom <L> meter'` |
| eind bots | (sinds N3 geen einde meer) kaart `💛`, `'<naam> is aan de overkant'` / `'Het was nog <rest> meter'` |
| eindsombalk | `'<L> − <p> = <rest>'` of `'<L> m ✓'` |
| toast | `'🏊 Precies aan de overkant! ⭐'` of `'🏊 Aan de overkant! ⭐'` |
| geen gast | toast `'🏊 Er is nog geen gast'` |

Cijfers in de wereld: `'<p> m'` op het dier, `'<L> m'` op de vlag, en kale
getallen (0, 10, 20, …) op de grote meterstrepen.

### 1.12 Stoppen, herstellen en verdringing

`stop()`: alle tikjes afbreken, kaart weg, wolkje weg, **noodUit** (ligt de gast
nog in het bad, dan wordt hij direct op het dek gezet), cijfer op het dier weg,
vlagcijfer weg, al het eigen decor weg, alle eigen hotspots weg, bewaren, en de
kader-luisteraar opzeggen.

`start()` opnieuw terwijl het spel al open staat en de beurt geldig is: alleen
het decor opnieuw bouwen en, als er niets beweegt en er geen kaart is, de
vraagkaart terugzetten.

Tijdens een bots staat in de opslag al de meter waar de wand hem heen gooit
(§1.7 stap 1), nooit `p = L`: een herlaad midden in de bots vindt hem op die
meter met de nieuwe vraag.

Na een herlaad (`herstel`): staat `p > 0`, dan wordt het dier met `World.zet`
teruggezet op `x(p)`, `z = 28`, krijgt `pose('zwem', 0)`, zijn cijfer en zijn
vraagkaart. Anders loopt hij opnieuw het water in. **Godot-poort:** de vraagkaart komt
als hij op het dek staat (`ctx.wacht_op(gast, dekNu)`, §1.6 — een herlaad zet hem in zijn
kamer van `waar`, dus meestal loopt hij eerst een stukje); het eerste antwoord zet hem met
`World.zet` terug op `x(p)` en hij zwemt vandaar verder.

`normaliseer(b)` vult een oude bewaarde beurt aan: band klemmen, `M` uit
`maxVan(L, band)`, `stap` uit `L ≤ 20 ? 5 : 10`, `p` klemmen op `0…L`, `leg`,
`misser`, `laatsteP` op geheel getal, `laatsteRest` standaard `L`.

Een beurt is **geldig** als `L`, `p` en `M` getallen zijn, `L > 0`,
`0 ≤ p ≤ L`, `klaar` leeg is en de gast nog bestaat.

---

## 2. G2 — DE WEKKERDIENST (`wekker`)

### 2.1 Verhaal, kamer en gasten

In de **gang** hangt aan de achterwand een grote halklok. De gasten slapen; het
kind draait de wijzers naar het uur dat een gast wil opstaan en tikt ✅ Klaar.
Klopt het, dan slaat de klok, wordt het dier wakker en valt er een ster. Klopt
het niet, dan slaapt het dier gewoon door en blijven de wijzers staan waar ze
staan — **nooit terugzetten, nooit rood, geen timer**.

Kamer `gang`: 120 × 36 voxels, wand 56, vloer `loper`; vast decor `plant`
(44, 8), `plant` (82, 8), `kist` (114, 14); deuren naar receptie, kamer 1,
kamer 2 en keuken.

**Het rijtje gasten** (`rijtje()`): eerst alle gasten met een bed die **slapen**
(`d.inZijnBed()` of `d.staat === 'slaap'`); is dat leeg, dan alle gasten met een
bed; is dat leeg, alle gasten. Daarvan de **eerste drie** — een ronde blijft
kindermaat. Is die lijst leeg, dan een wolkje op de kist (`🛏 'nog geen gasten'`)
en na 1800 ms sluit het spel zichzelf.

**Het dier van de beurt** (Godot-poort, §0.12) is de gast die nu gewekt wordt.
`spelers()` = die lijst vóór de grens van drie, in check-in volgorde. Is er een dier
gekozen dat erop staat, dan begint een verse ronde bij hem en gaat rond: hooguit drie,
het gekozen dier voorop (`idx` 0, dus de getallen van de eerste beurt van de dag). Een
bewaarde ronde gaat alleen verder als het gekozen dier daarin al aan de beurt was of
is; bij de wissel wordt niemand gewekt, wie sliep slaapt door.

**Niemand loopt hier binnen** (eigenaar 2026-09-23, §0.12): de slapers worden gewekt
waar ze liggen en het wekkerkaartje hangt bij hen in hun eigen kamer, dus de kaart onder de
klok komt meteen — er is geen dier om op te wachten.

### 2.2 Aanmelding en start

```
id: 'wekker'   naam: 'Wekkerdienst'   kamer: 'gang'   stub: false
hotspot: { obj: 'kist', dx: KX − 114 = −66, dz: KZ − 14 = −13, hoog: 26,
           icoon: '⏰', label: 'Wekker' }
unlock: N >= 1
geen `wens`
taak: { id: 'wekker', icoon: '⏰', prio: 3, tekst: 'Wekker zetten',
        wanneer: er zijn gasten én (ronde == 'avond' of er slaapt er één) }
```

Het icoontje hoort **op de klok**, maar de stekkerdoos zoekt de plek van een
hotspot alleen bij losse dingen, slots en het **vaste** decor van de kamer; de
klok is los decor. Daarom hangt de knop aan het vaste decorstuk `kist` en wordt
hij met `dx`/`dz` naar de klok geschoven. Die kistplek wordt uit `rooms.js`
gelezen (eerste decorstuk met de naam `kist`, anders het eerste decorstuk,
anders (114, 14)), zodat het icoontje meeschuift als de kist ooit verhuist.

**Poort (eigenaar 2026-09-23: "Dan hangt elk spel aan iets wat je echt ziet").**
Zolang er niet gespeeld wordt hangt de klok er ook: `definitie().rust` =
`rust_wk_klok` (het model `wekker_klok` op 7 uur, `modellen` meldt de statische
bouwer aan), en `hotspot.rust` hangt het icoontje eraan.  Daarvoor hing "⏰
Wekker" op het pootjesschilderij, alsof dat de wekker was.

### 2.3 Het rekenen per band

**Het doeluur** komt uit de bevroren generator `State.sommen.klok(band)`, die
zelf `state.dag` leest:

```
u = 7 + (dag·3) mod 8
band 3:  { u, m: 0,  stap: 60 }
band 4:  { u, m: [0,15,30,45][(dag + u) mod 4], stap: 15 }
band 5:  { u, m: (dag·7 + u·5) mod 60, stap: 5, duur: 20 + (dag mod 4)·10 }
```

De generator blijft ongemoeid; de **minuten** worden hier per gast opgeschoven,
want de generator geeft in band 4 altijd 45 en in band 5 minuten die geen
veelvoud van 5 hoeven te zijn (dag 1: 10:57 — met stappen van 5 nooit te zetten):

```
doelTijd(band, dag, idx):
    k = sommen.klok(band)
    u = u12(k.u + idx)
    band 3:  m = 0
    band 4:  m = (k.m + (dag + idx)·15) mod 60
    band 5:  m = (klok5(k.m) + (dag + idx)·5) mod 60      klok5(m)=round(m/5)·5, 60→0
```

`idx` is de plaats van de gast in het rijtje (0, 1, 2): elke gast wil een uur
later op.

**De afstand die gedraaid moet worden** (`afstand(band, N, dag)`), `r = dag mod 2`:

| band | uren | kwartieren | vijfjes | totaal in minuten |
|---|---|---|---|---|
| 3 | `max(1, min(5, N + r))` | 0 | 0 | `uur·60` |
| 4 | `max(1, min(3, ceil(N/2)))` | `(N + dag) mod 4` | 0 | `uur·60 + kwart·15` |
| 5 | `max(1, min(3, ceil(N/3)))` | `(N + dag) mod 4` | `(N + dag) mod 3` | `uur·60 + kwart·15 + vijf·5` |

De **startstand** van de klok is `doel − afstand`, modulo 12 uur.

**De tijdsduurvraag (alleen band 5)**: `duur = (band ≥ 5) en ((dag + idx) mod 2 == 1)`.
Dan gaat het doel op een heel uur (`m = 0`), de klok start `uur` hele uren eerder,
en de kaart vraagt eerst *"Hoe laat is hij wakker?"* met vier uurknoppen:

```
duurKeuzes(startU, dh, dag):
    goed  = startU·60 + dh·60
    lijst = [goed, goed+60, goed−60, startU·60 − dh·60]
    neem in die volgorde de uren over, sla dubbele uren over
    vul aan met goed + 120 + i·60 (i = 1, 2, …) tot er vier zijn
    draai de rij: rot = dag mod 4  →  uit.slice(rot) ++ uit.slice(0, rot)
```

Vaste, maar per dag andere volgorde: geen willekeur in de opslag.

**Nagerekend (verified):**

| N | band | dag | idx | `sommen.klok` | start | doel | vorm |
|---|---|---|---|---|---|---|---|
| 2 | 3 | 1 | 0 | 10:00 | 7 uur | 10 uur | zetten |
| 3 | 3 | 2 | 0 | 13:00 | 10 uur | 1 uur | zetten |
| 5 | 4 | 1 | 0 | 10:45 | half 7 | 10 uur | zetten |
| 5 | 4 | 2 | 1 | 13:45 | kwart voor 11 | half 3 | zetten |
| 8 | 5 | 1 | 0 | 10:57 | 7 uur | 10 uur | **tijdsduur**, keuzes 11 / 9 / 4 / 10 |
| 8 | 5 | 2 | 0 | 13:19 | 5 voor 10 | half 2 | zetten |
| 9 | 5 | 3 | 0 | 8:01 | 5 uur | 8 uur | **tijdsduur**, keuzes 2 / 8 / 9 / 7 |

### 2.4 Tijd in woorden (Nederlandse afspraken)

```
tijdWoord(u, m), met u genormaliseerd naar 1…12 en m naar 0…59:
   m == 0   →  "<u> uur"
   m == 15  →  "kwart over <u>"
   m == 30  →  "half <u+1>"
   m == 45  →  "kwart voor <u+1>"
   m <  15  →  "<m> over <u>"
   m <  30  →  "<30−m> voor half <u+1>"
   m <  45  →  "<m−30> over half <u+1>"
   anders   →  "<60−m> voor <u+1>"
```

Verified: 7:00 → `7 uur`; 7:15 → `kwart over 7`; 7:30 → `half 8`; 7:45 →
`kwart voor 8`; 7:05 → `5 over 7`; 7:20 → `10 voor half 8`; 7:35 →
`5 over half 8`; 7:50 → `10 voor 8`; 12:30 → `half 1`; 11:55 → `5 voor 12`.

Het klokpictogram bij een uur komt uit
`UURICO = ['🕛','🕐','🕑','🕒','🕓','🕔','🕕','🕖','🕗','🕘','🕙','🕚']`, gekozen
op het **dichtstbijzijnde hele uur** (`vanMin(inMin(u,m) + 30)`).

### 2.5 Het klokmodel (eigen voxelmodel `klok`)

Plek: `KX = 48`, `KZ = 1` (aan de wand `z = 0`, tussen twee deuren), hart van de
wijzerplaat `CY = 34` voxels boven de vloer, geplaatst met `ver: 1`.

In één wandvlak (z vast) geldt op het scherm `X = 2·dx` en `Y = dx − 2·dy`. Een
wijzerplaat die op het **scherm** rond is, is in voxels dus een scheve ellips.
Daarom rekent alles via

```
naarVox(X, Y) = [ round(X/2), round((X/2 − Y)/2) ]
```

Stralen **op het scherm**: `R_KAST 25`, `R_RAND 22`, `R_PLAAT 19`,
`R_STREEP 16,5`, `R_UUR 10`, `R_MIN 15,5`.
Kleuren: kast `#7E6255`, rand `#E8C58E`, plaat `#FFF7E4`, streep `#7E6255`,
uurwijzer `#4A3B33`, minuutwijzer `#C9788F`, hart `#E0A86B`, bel `#E8C58E`.
(De bleke spookwijzers `#9A8578` / `#D9A0B0` bestaan sinds 2026-09-24 niet meer:
geen hulp na een fout, §0.5.)

Opbouw:
1. voor `dx = −13…13`, `dy = −19…19`: `X = 2dx`, `Y = dx − 2dy`, `d2 = X² + Y²`;
   `d2 > R_KAST²` → niets; `> R_RAND²` → kastvoxel op `z = 0` én `z = 1`;
   `> R_PLAAT²` → randvoxel op `z = 1` én `z = 2`; anders plaatvoxel op `z = 1`.
2. twee belletjes bovenop, op **schermhoogte** even hoog:
   `q = naarVox(−13, −23)`, `q2 = naarVox(13, −23)`, elk
   `bx(q.x − 1, CY + q.y, 1, 3, 3, 2)` in `bel`.
3. twaalf uurstreepjes: hoek `a = i·π/6` voor `i = 1…12`; is `i mod 3 == 0`, dan
   een streepje van `R_STREEP − 2,5` tot `R_STREEP + 0,5` (dikte 0,5), anders één
   stipje op `naarVox(R_STREEP·sin a, −R_STREEP·cos a)`; alles op `z = 2`.
4. de wijzers: uur van 0 tot `R_UUR` (dikte 1), minuut van 0 tot `R_MIN`
   (dikte 0,5), stap 0,5, op `z = 2`.  Er komen geen spookwijzers meer bij
   (eigenaar 2026-09-24); een oude `spookU`/`spookM` in de parameters tekent
   niets.
5. het hart: `bx(−1, CY − 1, 2, 2, 2, 1)` in `hart`.

Hoeken (0 = 12 uur, met de klok mee):
`hoekUur(u, m) = ((u mod 12 + m/60) / 12)·2π`, `hoekMin(m) = ((m mod 60)/60)·2π`.

Een streep tekenen: voor `r` van `r0` tot `r1` in stappen `stap` en `t` van
`−dik` tot `+dik` in stappen 0,5, zet een voxel op
`naarVox(r·sin a + t·cos a, −r·cos a + t·sin a)`, verschoven met `CY` in y.

**Elke tik zet nieuwe params**, dus de motor bakt precies één plaatje opnieuw.
Op de klok staat zijn eigen tijd als cijfer: `getalTag('klok', tijdWoord(u, m),
{y: 48, prio: 12, titel: 'de klok staat op <tijdWoord>'})`.

### 2.6 De wijzerplaat vrijhouden (bindend)

De deurknoppen van het hotel hangen in de gang precies in de band waar de klok
hangt; gemeten stonden "Kamer 1" en "Kamer 2" **op** de wijzerplaat. Oplossing:
het spel legt één **leeg** tagje van zichzelf precies op de plaat —

```
hotspots.maak({ id: 'wk_plaat', kind: 'tag', tagnaam: 'div', kamer: 'gang',
                x: KX, z: KZ, y: CY, op: 'midden', prio: 13,
                titel: 'de wijzerplaat',
                html: <span> van d × d px })     d = max(20, round(2·R_RAND·k))
```

met transparante achtergrond, geen rand, geen schaduw, geen padding. Het is niet
te zien en niet te tikken, maar het reserveert de plek: alles van de
voorrang-eigenaar is VIP en wie daar na het uitwijken nog overheen valt gaat even
weg. Zodra het spel stopt staan de deurknoppen weer waar ze willen.

### 2.7 De kaart onder de klok

Eén sommenkaart, `id 'wk_som'`, `hoog: 3`, `icoon '⏰'`, `pad: false`, verankerd
aan het losse decorstuk `klok` (`World.mik('klok')` vindt los decor wél).

**Poort (2026-09-23).** `_hang_kaart()` hangt de kaart onder de klok met haar
EERLIJKE hoogte (`Ui.kaart_mat`): de eigen minimummaat van een kaart is een toren
van één woord per regel zolang de labels niet op hun breedte staan, en daarmee
hing de kaart ver onder de vloer en viel ze op de onderrand, 290 eenheden van de
klok.  Tussen klok en kaart blijft één band vrij voor het tijdplaatje van de klok
(`wk_tijd`, "10 uur"); zonder die ruimte duwde de kaart het plaatje onder zich en
ging de knoppenstrook, die onder de kaart kleeft, naar de voet van het kader.  De
kaart draagt vanaf de eerste tik één vaste hulpregel, `'💛 draai tot de klok
klopt'` (K3); die is zo breed als hij is, tot het eigen maximum van de kaart, en
verandert na een misser niet (eigenaar 2026-09-24), dus de kaart is over de
stappen even hoog.

**De zin** (`zinZet`), met `naam` = de gast en `wil = tijdWoord(doelU, doelM)`:

* normaal regel 1: `'<naam> wil om <wil> op'`; is die langer dan **34 tekens**,
  dan in plaats daarvan `'Wek <naam> om <wil>'`;
* regel 2: `'Zet de klok'` als de gast slaapt, anders `'Zet de klok voor morgen'`;
* na een misser (`stap === 'mis'`): `'De klok staat op <tijdWoord(u,m)>'` /
  `'<naam> wil <wil>'`.

**De tijdsduurvraag** (`zinDuur`): `'<naam> slaapt nog <duur> uur'` /
`'Hoe laat is hij wakker?'`.

**De sombalk** is de live meelopende klokstand `'nu: <tijdWoord(u,m)>'`, behalve
in de stap `mis`: daar is de balk **leeg**, want de tijd staat dan al in de zin
(en de klok draagt hem zelf ook nog als cijfer) — anders zou het kind hem drie
keer lezen.

**De knoppenstrook** (`keuzeTitel 'draai de klok'`):

| band | knoppen (id, icoon, tekst lang → kort) | stap |
|---|---|---|
| 3 | `uur` 🕐 `'uur erbij'` → `'uur'`; `klaar` ✅ `'Klaar'` | +60 min |
| 4 | idem + `kwartier` 🕒 `'kwartier erbij'` → `'kwartier'` | +15 min |
| 5 | idem + `vijf` 🕧 `'5 minuten erbij'` → `'5 min'` | +5 min |

Bij de tijdsduurvraag (`keuzeTitel 'hoe laat wordt hij wakker?'`) staan er in
plaats daarvan vier uurknoppen `uurIco(u, 0)` + `'<u> uur'`.

**Korte woorden.** `kortWoord()` is waar als `kortDwang` gezet is, of als er
**vier** knoppen zijn (dus band 5) én het kader smaller is dan **370 px**.
Gemeten met de volle woorden zijn vier knoppen samen 361 px: dat past in een
kader van 386 px (420 × 860 staand) en 682 px (860 × 420 liggend), maar niet in
356 px (iPhone 13), 326 px (360 × 740) of 286 px (320 × 640). Met korte woorden
is de strook 245 px. Pictogram **én** woord blijven altijd staan.
Daarnaast meet `strookNakijken()` **140 ms** na het tekenen of de strook écht
past: is `offsetWidth > kaderPx() − 8`, dan `kortDwang = true` en één keer
opnieuw tekenen. Bij een kadermelding: is `kortDwang` gezet en het kader weer
≥ 400 px, dan gaat de dwang eraf; verandert de woordlengte, dan de kaart
opnieuw, anders alleen de klok hermeten.

**Het wekkerkaartje bij de gast** (`ui.wolk`, id `wk_gast`, `hoog 54`):
icoon `💤` als hij slaapt, anders `⏰`; tekst standaard `tijdWoord(doelU, doelM)`,
en na een misser `'slaapt nog'` (slapend) of `'nog niet'`.

### 2.8 Tikken

**Draaien** (`draai(stapMin)`): de wijzers gaan **vooruit**, na 12 begint het
gewoon weer bij 1. Nooit terugzetten. Stond de kaart in `mis`, dan gaat hij bij
de eerste draai terug naar de gewone zin. Elke draai geeft een zachte gong
(`snd.klok`), maar met een rem: nooit twee slagen binnen **120 ms**. Tijdens de
tijdsduurvraag doet draaien niets.

**✅ Klaar** (`klaarTik`): goed is `inMin(u,m) == inMin(doelU, doelM)`.

*Fout:* is er sinds de vorige keuring aan de wijzers gedraaid, dan `missers++`
en `stap = 'mis'` (twee keer ✅ zonder draai is geen tweede poging, R3 — voor het
adaptieve signaal); in beide gevallen `snd.zacht()`, het wekkerkaartje bij de
gast zegt `'slaapt nog'`, en `ctx.ui.misser(kaart, gast)`: de strook staat
1,2 s op slot met `🔄 Nog een keer` bij de klok — de slaper ligt in zijn eigen
kamer en wordt niet uit bed gehaald. **Verder niets** (eigenaar 2026-09-24): de
vaste hulpregel blijft staan, er komt geen `'💛 draai nog wat verder'`, geen
`'💛 draai eerst aan de wijzers'`, geen telladder en geen spookwijzers. De wijzers
blijven staan waar ze staan, zodat je verder kunt draaien. Het dier draait zich
om en slaapt door.

*Goed:* `wakkerWorden()`.

**Een tijd kiezen** (`kiesTijd(u)`, alleen in de tijdsduurstap): fout →
`missers++`, `snd.zacht()` en dezelfde misser (strook op slot, `🔄 Nog een
keer`), geen telladder. Goed → `snd.ja()`, `stap = 'zet'` en de kaart wordt met
de andere knoppen opnieuw gebouwd.

### 2.9 Wakker worden

1. `stap = 'wakker'`, hulp leeg, `snd.klok()` (**nooit afgeremd**), en na
   **220 ms** `snd.ja()`;
2. de kaart: hulp weg (de hint hoort bij het zoeken, niet bij het feest — met de
   hint erbij werd de kaart hoger en dekte hij de klok af), regel vervangen door
   **één** regel `'<naam> is wakker'` (twee regels maakten de feestkaart net hoog
   genoeg om de onderkant van de wijzerplaat te raken: gemeten 2 px), dan
   `kaart.klaar()` (vinkje);
3. het wekkerkaartje bij de gast gaat weg;
4. **camerasprong**: het wakker worden gebeurt in de kámer van de gast en het
   kind staat in de gang, dus `World.naar(gastkamer)`;
5. `pose(gast, 'blij', 60)` en het wolkje `☀ 'goedemorgen'` (`id wk_zon`,
   `hoog 54`);
6. eenmalig `taakKlaar('wekker', {sterren: 1})` en `Hotel.render()` (de ster
   meteen in de balk);
7. na **2200 ms** `volgende()`.

`volgende()`: `wk_zon` weg, terug naar de gang (daar hangen de kaart en de
knoppen). Is `idx + 1 >= rijtje.length`, dan `af = 1`, wolkje op de klok
`⏰ 'allemaal gewekt'` en na **2200 ms** wolkje weg + `ctx.sluit()`. Anders een
nieuwe beurt voor de volgende gast, met dezelfde `N`, `band` en `dag`, en de
sterstand blijft behouden (er valt hooguit één ster per ronde).

### 2.10 Kindtekst, letterlijk

| moment | tekst |
|---|---|
| icoontje | label `'Wekker'`, icoon `⏰` |
| prikbord | `'Wekker zetten'` |
| geen gasten | wolkje op de kist `🛏 'nog geen gasten'` |
| kaart, zetten | `'<naam> wil om <tijd> op'` (of `'Wek <naam> om <tijd>'`) / `'Zet de klok'` of `'Zet de klok voor morgen'` |
| kaart, na misser | `'De klok staat op <tijd>'` / `'<naam> wil <tijd>'` |
| kaart, tijdsduur | `'<naam> slaapt nog <n> uur'` / `'Hoe laat is hij wakker?'` |
| sombalk | `'nu: <tijd>'` (leeg na een misser) |
| knoppen | `'uur erbij'`/`'uur'`, `'kwartier erbij'`/`'kwartier'`, `'5 minuten erbij'`/`'5 min'`, `'Klaar'`; tijdsduur: `'<u> uur'` |
| strooktitel | `'draai de klok'` / `'hoe laat wordt hij wakker?'` |
| hulp | vast, vanaf de eerste tik: `'💛 draai tot de klok klopt'`; na een misser verandert hij niet (geen hulpladder meer, 2026-09-24) |
| misser | `🔄 Nog een keer` bij de klok, de strook 1,2 s op slot |
| bij de gast | `'<tijd>'`, na een misser `'slaapt nog'` of `'nog niet'` |
| wakker | kaart `'<naam> is wakker'`, wolkje `☀ 'goedemorgen'` |
| ronde af | wolkje op de klok `⏰ 'allemaal gewekt'` |
| op de klok | `'<tijd>'` met titel `'de klok staat op <tijd>'` |

### 2.11 Stoppen en herstellen

`stop()`: tikjes af, kader-luisteraar op, kaart weg, **al het eigen decor weg**
(ook zonder de knoppenlaag), alle eigen hotspots weg, geleende knoppen terug,
`kortDwang` en `kortWas` op nul.

`start()` hergebruikt de bewaarde stand alleen als `dag`, `N` en `band` nog
kloppen, de beurt niet `af` is, de gast nog bestaat en `doelU` gezet is. Na een
herlaad slaapt iedereen weer (`slaapt` opnieuw bepalen) en wordt de stap
`wakker` teruggezet naar `zet`. Bij het starten gaat de camera altijd naar de
gang.

---

## 3. G3 — HET HINKELPAD (`hinkel`)

### 3.1 Verhaal, kamer en gast

In de **tuin**, in de strook `Rooms.get('tuin').zones.hinkel` = `{x0: 24,
x1: 100, z0: 34, z1: 50}` (76 × 16 voxels vlak vóór het hok, met 4 voxels lucht
tot de souvenirkraam), ligt een **getallenlijn van stapstenen** van 0 tot `E`.
Bij het doel staat een houten trapje met het doelgetal erin gebakken. De gast
staat op een startsteen, het kind kiest eerst de **sprongmaat** en dan het
**aantal sprongen**, en het dier hupt steen voor steen mee-tellend naar het
trapje.

Gasten die niet meedoen worden van de stenenstrook af gestuurd en wachten
ernaast zolang de beurt loopt.

**Spelers** (`spelers()`): gasten met een bed; hebben er een of meer de wens
🧶 `spelen` en zijn ze niet blij, dan alleen die; daarna gesorteerd met wie al in
de tuin is vooraan. De eerste speelt. Is de lijst leeg: wolkje op het hok
`🛏 'nog geen gasten'` en na 1800 ms sluiten.

**Het dier van de beurt** (Godot-poort, §0.12). De eigen volgorde hierboven heet in de
poort `_spelers()`; de lijst waar de spelbalk doorheen gaat is `MiniGame.spelers()` =
elke gast met een bed, in check-in volgorde. Een gekozen dier dat erop staat hinkelt,
in een verse beurt vanaf de startsteen; een bewaarde beurt van een ander dier wordt
niet hervat. Wie bij de wissel op de stenen stond, wordt er net als elke andere gast
af gestuurd (§3.6); was hij nog onderweg naar de tuin, dan gaat hij terug naar bed
(`ctx.laat_gaan`).

### 3.2 Aanmelding en start

```
id: 'hinkel'   naam: 'Hinkelpad'   kamer: 'tuin'   stub: false
hotspot: { obj: 'hok', icoon: '🪨', label: 'Hinkelen', hoog: 6,
           dx: round(eerste − hok.x) = 27 − 67 = −40,
           dz: round(zSteen − hok.z) = 41 − 19 =  22 }
unlock: N >= 1
wens: 'spelen'
taak: { icoon: '🪨',
        prio: (er is een gast met wens 'spelen' en !blij) ? 2 : 5,
        wanneer: er is minstens één gast met een bed,
        tekst: '<naam> wil hinkelen'  of  'Hinkel op de stenen' }
```

`prio` is een **leesfunctie** (`get prio`), want `hotel.js` leest hem bij elke
hertekening opnieuw. Waarom niet altijd 1: het bord houdt er maar drie, en een
taakje dat net is afgevinkt blijft de rest van de dag staan; met een vaste
prio 1 duwde dit kaartje precies dat vinkje van het bord af.

### 3.3 De maatvoering van het pad (alles in voxels)

```
BAND = { 3: {E:  10, stap: 1, stenen: 11, sprongen: [1, 2, 5]},
         4: {E: 100, stap: 5, stenen: 21, sprongen: [2, 5, 10]},
         5: {E: 100, stap: 5, stenen: 21, sprongen: [2,3,4,5,6,7,8,9,10]} }

eerste = zone.x0 + 3 = 27          laatste = zone.x1 − 3 = 97
steek  = (laatste − eerste) / (stenen − 1)      band 3: 7,0   band 4/5: 3,5
zSteen = round((zone.z0 + zone.z1)/2) − 1 = 41
zDier  = zSteen + 3 = 44     zTrap = zSteen + 4 = 45     zTop = zSteen + 6 = 47
x(n)   = eerste + (laatste − eerste)·n / E
```

**Drie rijen in de diepte, met opzet apart:** de stenen op `z = 41`, het trapje
op `z = 45` (vóór de stenen — anders verdwijnt het achter de cijferbordjes van de
stenen rechts ervan, die een grotere diepte hebben) en de looplijn van het dier
op `z = 44`; alleen op het einde stapt de gast naar `z = 47` en staat hij ÓP het
trapje.

Omdat een stuk dat 3 voxels naar de kijker toe staat op het scherm 6 px naar
links opschuift, krijgt elke rij zijn x met precies dat verschil erbij:

```
xOpRij(n, z0) = x(n) + (z0 − zSteen)         zodat (x − z) voor alle rijen gelijk is
dierX(n)      = xOpRij(n, zDier)
```

**Welke steen krijgt een cijfer?** (PLAN.md `N5`, 2026-09-18 — de tientallen van
band 4/5 liepen in één witte band aan elkaar.) Band 3: **elke** steen (0…10); een
bordje van één teken is 5 voxels = 10·g px op een steek van 7 voxels = 14·g px.
Band 4/5: alleen elke **twintigste** (`i mod 4 == 0` → 0, 20, 40, 60, 80, 100);
een bordje van twee tekens is 9 voxels = 18·g px, en op een steek van 3,5 voxel
stond een bordje per tien maar 7·g px van het volgende. Vier stenen verderop is
dat 14 voxels = 28·g px, en ook het breedste bordje van de lijn ("100", 13 voxels
= 26·g px) heeft dan ruimte. De **dikke tellerstenen** blijven wél in vijven
(band 3) of tienen (band 4/5) doortellen, ook waar de lijn niets meer uitschrijft.

Hoogte van het bordje (`rij`): in band 3 gaat alleen "10" een rij hoger (twee
tekens); in band 4/5 hangt **elk** bordje laag — de om-en-om-lift
(`floor(i/2) mod 2`) is vervallen, want die maakte van één getallenlijn twee
rijen getallen en het kind moest uitzoeken welk getal bij welke steen hoorde.

Zijdelings (`bordDx`, met halve bordbreedte + 1 voxel rand): een bordje houdt
**2 voxels daglicht** tot het bordje links ervan en blijft binnen de zone zolang
dat zijn buurman niets kost. Het breedste getal van een lijn staat altijd op de
**laatste** steen en de strook houdt drie voxels achter die steen op, dus juist
het naar binnen trekken duwde "10" tegen "9" en "100" tegen "80". De tuin loopt
door tot x = 130 en de bordjes zijn los decor zonder knop: een bordje hangt
liever over het einde van de strook dan over het getal ernaast ("10" wijkt
2 voxels naar rechts, "100" kan er 1 naar binnen).

### 3.4 De getallen per band

```
beurt(N, band, dag):
    ruimte = E − stap                      // het doel ligt nooit op de laatste steen
    k = sprongen[(dag + N) mod aantal]
    n = min(max(2, N), 10)                 // MAX_HOP = 10
    verklein n (tot 2) zolang k·n > ruimte; lukt dat niet, kies een kleinere k
    past(a) = a ≥ 2 en a ≤ ruimte en a mod stap == 0 en (aantal maten dat
              precies op a past) ≥ 2
    zoek in de volgorde n + [0, +1, −1, +2, −2, +3, −3, +4, −4, +5, −5]
        de eerste nn (2 ≤ nn ≤ 10) waarvoor past(k·nn); anders dezelfde zoektocht
        met elke andere maat kk = sprongen[(j + dag) mod aantal]
    afstand = die gevonden waarde, anders max(stap, min(afstand − afstand mod stap, ruimte))
    maxS = max(0, ruimte − afstand)
    band 3:  start = k · (dag mod (floor(maxS/k) + 1))            // in de tafel van k
    band 4:  start = 10 · (dag mod (floor(maxS/10) + 1))          // op een tiental
    band 5:  start = maxS ≥ 5 ? 5 + 10·((dag+N) mod (floor((maxS−5)/10)+1)) : 0
    doel = start + afstand ;  n = afstand / k
```

Twee eisen aan de afstand: (1) er passen minstens **twee** sprongmaten precies
op, anders is de keuzestrook geen echte keuze; (2) de afstand is een veelvoud van
de stenenmaat, zodat het trapje altijd **op** een steen staat. Het doel ligt
nooit op de laatste steen — anders zou "te ver" niet kunnen bestaan.

| band | lijn | stenen | sprongmaten | startpunt | voorbeeld uit de code |
|---|---|---|---|---|---|
| 3 | 0–10, elke steen genummerd | 11 (elke 1) | 1, 2, 5 | in de tafel van k | van 0 naar 8 met 2 |
| 4 | 0–100 | 21 (elke 5) | 2, 5, 10 | op een tiental | van 30 naar 80 met 10 |
| 5 | 0–100 | 21 (elke 5) | 2 t/m 10 | 5, 15, 25, … (juist níet op een tiental) | van 15 naar 45 met 10 |

**Nagerekend (verified):**

| N | band | dag | start | doel | maat | sprongen | maten die passen |
|---|---|---|---|---|---|---|---|
| 2 | 3 | 1 | 1 | 3 | 1 | 2 | 1, 2 |
| 3 | 3 | 3 | 3 | 7 | 1 | 4 | 1, 2 |
| 5 | 4 | 1 | 10 | 20 | 2 | 5 | 2, 5, 10 |
| 6 | 4 | 2 | 20 | 70 | 10 | 5 | 5, 10 |
| 8 | 5 | 1 | 15 | 35 | 2 | 10 | 2, 4, 5, 10 |
| 9 | 5 | 2 | 55 | 95 | 4 | 10 | 4, 5, 8, 10 |
| 10 | 5 | 4 | 25 | 95 | 7 | 10 | 7, 10 |

**Sprongmaten op de strook** (`maten()`): alle maten die precies op de huidige
afstand passen (en waarvan het aantal sprongen 1…10 is); is dat leeg, dan alle
maten die de afstand delen; is dat nóg leeg, dan `[1]`. Zijn het er meer dan
drie, dan blijven alleen de **eerste, de middelste (`floor(len/2)`) en de
laatste** over. Voorbeeld: 2/4/5/10 → **2 / 5 / 10**.

**Aantalkeuzes** (`keuzeGetallen(n, zaad)`), met `zaad = s + dag + pogingen`:

```
pool = [−2, −1, +1, +2, +3]
uit  = [n]
loop i = 0… zolang uit < 4:  v = n + pool[(i + |zaad|) mod 5]; neem v over als v ≥ 1 en nieuw
vul aan met n+1, n+2, … tot er vier zijn
sorteer oplopend
```

Precies één goede, geen dubbele, nooit nul of negatief. Verified: `n = 4`,
zaad 0…4 → `[2,3,4,5]`, `[3,4,5,6]`, `[4,5,6,7]`, `[2,4,6,7]`, `[2,3,4,7]`;
`n = 1`, zaad 0 → `[1,2,3,4]`.

### 3.5 De modellen

**Cijfers** zijn 3 × 5 voxels, als patroon van 0/1-rijen (`CIJFER['0'] =
['111','101','101','101','111']`, enzovoort voor 0–9). Een getalbordje is
`len·4 − 1` voxels breed (3 per cijfer + 1 kier). Het bordje is **één plaat van
één voxel dik** met het cijfer op diezelfde plaat bijgeverfd — niet als blokjes
ervóór; dat is het verschil tussen een leesbaar cijfer en een rij bruine
bobbels. Het vlak dat naar de kijker kijkt (+z) krijgt zo een plat, scherp
patroon van 2 × 2 css-px per fontpunt. Rand rondom: één voxel `BORD` (`#FFFDF6`),
cijfer `INKT` (`#4A3B33`).

**`steen`** (params `getal`, `groot`, `dx`, `rij`): een platte tegel
`bx(−floor(b/2), 0, −2, b, 2, 5)` met `b = groot ? 5 : 4`, kleur `#C7C2B4`
(gewoon) of `#BFAE92` (mijlsteen), plus een lichte bovenkant
(`verf(−3…3, 1…1, −2…2)`) in `#DAD5C6` / `#D8CBAE`. Heeft de steen een getal, dan
staat het bordje **achter** de steen (`zp = −3`) op hoogte `y0 = 2 + rij·8`, zodat
het de steen niet afdekt en het pad een pad blijft (geen hek). `groot` is waar bij
`n mod 5 == 0` (band 3) of `n mod 10 == 0` (band 4/5).

**`trap`** (params `getal`, `dx`): drie treden die met het pad mee omhoog lopen
(naar +x): voor `j = 0,1,2` een `bx(−3 + 2j, 0, −2, 2, 3 + 3j, 5)` in `#D0A87A`,
met een lichte bovenkant `#E2C094` en een donkere stootrand `#B98F62`. Het
**doelgetal** zit in dit model (niet als losse chip — anders belanden het getal
van de gast en dat van de trap op het einde op elkaar). Het hangt aan een **mast**
(PLAN.md `N5`, 2026-09-18): `bx(rond(dx), 0, 0, 1, TRAP_BORD, 1)` in `#B98F62`,
waarvan de onderste helft binnen de treden staat en daar volledig wordt
weggesneden. Het bordje staat op `TRAP_BORD = 18`, `zp = 0` — een volle rij
(8 voxels) boven het hoogste bordje dat het pad zelf draagt — met een roze kapje
(`#F5B0C2`) erboven op `y = 23` en de vlag `bx(x0 − 1, 24, 0, w + 2, 1, 1)`.
Op het einde van een beurt staat de gast **op** de bovenste trede: gemeten vanaf
zijn eigen voetpunt haalt een konijn 34 voxel-px en het bordje op `y = 10`
verdween daar precies achter. Vanaf `TRAP_BORD` steekt de vlag bij elke
voxelmaat en op alle vier de kaders boven de kop van elke soort uit.

Het zetten van het decor: 11 of 21 stenen (`hk_steen0…`), overtollige stenen van
een vorige band worden expliciet weggehaald (tot `STENEN_MAX = 21`), en één
trapje `hk_trap` op `xOpRij(doel, zTrap)`, `z = zTrap`.

**De stenen en het trapje zijn los decor en kosten geen enkele knop.** Gemeten
tijdens een beurt met drie gasten staan er 6 knoppen in de tuin:
`deur_tuin_keuken`, `deur_tuin_zwembad`, `game_tobbe`, `hk_som`,
`hk_som_keuzes`, `getal_hk_gast`. Er is dus ruim plek over.

### 3.6 De gast halen en de anderen opzij

`opStartSteen()` is waar als het dier in de tuin is én
`|d.x − dierX(s)| ≤ 2,5` én `|d.z − zDier| ≤ 3,5`.

`haalGast()`: is het dier niet in de tuin, dan `g.waar = 'tuin'` en
`reis(id, 'tuin', {x: dierX(s), z: zDier, na: 'wacht'})`; is hij er wel maar niet
op zijn steen, dan `loopNaar(dierX(s), zDier, {tempo: 1.4, na: 'wacht'})`.

`wachtOpGast()` kijkt elke **500 ms**. Zodra hij er is en er werd gewacht, wordt
er opnieuw getekend (en dan verschijnt de keuzestrook). Bij de eerste wachtbeurt
wordt meteen getekend ("komt eraan"). Elke 24e beurt (≈ **12 s**) wordt hij
opnieuw op weg gestuurd. Er loopt altijd maar **één** wachtketting.

**Godot-poort (eigenaar 2026-09-23: "Zorg dat de minigame pas begint wanneer het dier er
is", §0.12 — dit overrulet PLAN.md N11 "de som staat er meteen, het dier komt eraan").**
`haalGast()` + `wachtOpGast()` zijn samen één `ctx.wacht_op(gast, {x: dierX(s), z: zDier},
{tempo: 1.4, marge: 2.5})` (world.md §5.3): hij kijkt elke 0,1 s en stuurt een ingehaalde
reis na een tel opnieuw. Er is nog steeds maar **één** wacht (`_wacht_loopt`). Zolang hij
loopt tekent het spel **niets** — geen kaart, geen strook, geen cijfer boven zijn kop; de
stenen en het trapje liggen er wel — en bij de tuindeur hangt het hotelwolkje
`🐶 Boef komt eraan` met zijn balk en `👀 Volg`. De kaart "komt eraan / Tel straks mee"
bestaat niet meer. Staat hij op zijn steen, dan komt de kaart met de eerste vraag.

`houdVrij()`: elke gast die niet meedoet en zich op of vlak bij de strook bevindt
(`x` binnen `zone.x0 − 10 … zone.x1 + 10`, `z` binnen `zone.z0 − 7 … zone.z1 + 7`)
wordt naar een vrij grasvak vóór de strook gestuurd met `na: 'wacht'`, zodat hij
niet terugdwaalt. De grasvakken zijn de vrije vakjes van de tuin met
`z ≥ zone.z1 + 10`, niet in de kraamzone, gesorteerd op `(x − z)`. Dit wordt elke
**2000 ms** herhaald zolang de beurt loopt. `stop()` geeft ze hun eigen gang
terug met `pose('rust')`.

### 3.7 De kaart

Staand ligt de kaart op het gras **vóór** de stenen (dezelfde `x − z`, grotere
diepte), liggend **ernaast** (dezelfde diepte, verder naar links en hoger):

```
xm = (eerste + laatste)/2 ;  u = xm − zSteen ;  d = xm + zSteen ;  y = 0
liggend  (kaderbreedte/hoogte > 1,15):
    u −= (laatste − eerste)/2 + round(120 / pxPerVoxelX)
    y  = round(max(40, kaderhoogte/2 − 46) / pxPerHoogte)
staand:
    d += (laatste − eerste)/2 + round(74 / pxPerVoxelY)
u += uitU ; y += uitY               // de correcties die kaartPast heeft gevonden
plek = { x: (d + u)/2, z: (d − u)/2, y }
```

**Nameten** (`kaartPast`, elke **110 ms**, hooguit **4** rondes per stap): uit de
gemeten plek van de kaart volgt de hele afbeelding terug
(`px = c + (x−z)·pxPerVoxelX`, `py = c2 + (x+z−2y)·pxPerVoxelY`); daarmee wordt in
één stap de gewenste bovenrand berekend. Staand: onder de laatste steen én onder
de pootjes van het dier (`max(yVan(laatste, zSteen) + 16, yVan(d.x, zDier) + 8)`).
Liggend: de rechterrand van kaart en strook blijft **26 px** links van het dier;
is er links minder dan 4 px, dan schuift hij 6 px naar binnen. De gewenste
bovenrand wordt geklemd op `6 … kaderhoogte − blokhoogte − 6`. Past het blok
sowieso niet in de breedte (`blokB > kaderbreedte − 8`), dan blijft het staan.
`uitY` is geklemd op −160…220, `uitU` op −160…160. Wisselt de fase (`fase|melding`),
dan mag er opnieuw gemeten worden.

Dit spel hangt **geen eigen resize-luisteraars** op: de hele opstelling is in
voxels uitgemeten en die schaalt de motor zelf mee.

### 3.8 Het spelen

`kiesSprong(k)` (fase `sprong`): `sprong = k`, `n = afstand/k`, fase → `aantal`,
`snd.tik()`, bewaren, opnieuw tekenen.

`antwoord(n)` (fase `aantal`): staat de gast nog niet op zijn steen, dan wordt hij
eerst gehaald en komt dezelfde vraag terug zodra hij er staat (er telt niets mee en er
gaat niets verloren; in de poort gaat de kaart zolang weg). Anders: `pogingen++`, bij fout `missers++`, `state.tel(goed, ms)` en
dan hoppen — **ook bij een fout antwoord**: het dier springt het gekozen aantal
en de kaart vraagt van daaruit verder.

`hop(aantal)`: richting `r = doel ≥ s ? +1 : −1`; het aantal wordt geklemd zodat
er nooit van de lijn af gehinkeld wordt
(`max = r > 0 ? floor((E − s)/sprong) : floor(s/sprong)`). Is dat 0, dan
`snd.zacht()` en `ctx.ui.misser(kaart, gast)` — het dier is even sip, de strook
op slot — en géén telhulp op de kaart (eigenaar 2026-09-24). Anders punten
`{x: dierX(s + r·sprong·i), z: zDier}` voor `i = 1…hops`, fase → `hop`, `tel = 0`,
en `stappen(..., {pose: 'spring', tempo: 1.25, perStap})`. In `perStap(i)`:
`tel = i + 1`, `snd.hup()`, en de cijferchip op het dier wordt op `tel` gezet
(titel `'sprong <tel>'`). Vóór de reeks wordt zo nodig nog even naar de steen
gelopen (`loopEerst`, `tempo 1.4`).

Elke sprongreeks krijgt een nummer (`hopNr`); een ingehaalde reeks die alsnog
terugkomt beslist niets meer. Valt de belofte `false` (ingehaald), dan gaat de
fase terug naar `sprong` met `sprong = null`.

`geland(pos)`: `s = pos`, `tel = 0`.

* `pos == doel` → `gelukt()`;
* anders `sprong = null`, fase → `sprong`, `melding = ''`, `snd.zacht()`, de
  kaart van de gewone sprongvraag vanaf de steen waar hij landde, en
  `ctx.ui.misser(kaart, gast)`: het dier is even sip met `🔄 Nog een keer`, de
  nieuwe strook staat 1,2 s op slot. **Nooit een kruis, en nooit een hint**
  (eigenaar 2026-09-24): geen wolkje `'te ver'`/`'nog verder'` meer (tot die
  datum `hk_zeg`, 2400 ms), geen kaart `'Oei, te ver!'` / `'Kies je sprong
  terug'` of `'Nog even verder'`, en geen telhulp. Dat hij terug moet, vertelt
  de strook zelf: vanaf een steen voorbij de trap staan er alleen
  `'terug <k>'`-knoppen.

`gelukt()`: fase → `af`, `snd.ja()`, opnieuw tekenen; eenmalig
`taakKlaar('hinkel', {sterren: 1})`; had de gast de wens 🧶, dan
`behoefteKlaar(id, 'spelen')`; bewaren en `Hotel.render()`. Daarna hinkelt het
dier **op** het trapje: één stap naar `{x: xOpRij(doel, zTop) + 1, z: zTop}` met
`pose 'spring'`, `tempo 1.1` en `snd.hup()` bij de landing (grotere diepte dan het
trapje zelf, dus het dier staat er bovenop). Daarna `pose('blij', 60)`,
`snd.hoera()` en het wolkje `⭐ 'op de trap'` (klas `goed`, `hoog 52`, `prio 12`).
In fase `af` tekent `tekenCijfers()` **geen cijferchip** meer (PLAN.md `N5`,
2026-09-18): de gast staat dan op het trapje met het doelbord vlak achter zijn
kop, dus die chip zette het doelgetal nog een keer boven het doelgetal. Het bord
zegt het, de kaart zegt het en het sterwolkje zegt het. Na **4600 ms** wordt de
bewaarde stand gewist en sluit het spel zichzelf.

### 3.9 Kindtekst, letterlijk en op volgorde

| moment | icoon | tekst |
|---|---|---|
| icoontje | 🪨 | label `'Hinkelen'` |
| prikbord | 🪨 | `'<naam> wil hinkelen'` of `'Hinkel op de stenen'` |
| geen gasten | 🛏 | `'nog geen gasten'` |
| sombalk (altijd, behalve op het eind) | — | `'van <s> naar <doel>'` |
| gast komt eraan | — | **geen kaart meer** (eigenaar 2026-09-23, §3.6): het hotelwolkje `'<naam> komt eraan'` met balk en `👀 Volg` bij de tuindeur (world.md §6.3) |
| kies je sprong | diersoort | `'<naam> staat op <s>, trap bij <doel>'` / `'Kies je sprong'` (krap: `'Kies je sprong'`) |
| na een foute landing | diersoort | dezelfde kaart als "kies je sprong", vanaf de nieuwe steen (tot 2026-09-24: `'Nog even verder'` / `'Oei, te ver!'` / `'Kies je sprong terug'`) |
| hoeveel sprongen | 🪨 | `'<naam> springt <k> per keer'` (terug: `'<naam> springt <k> terug'`) / `'Hoeveel sprongen?'` (krap: `'Hoeveel sprongen?'`) |
| tijdens het hinkelen | diersoort | `'<naam> hinkelt'` / `'Tel maar mee'` (krap: `'Tel maar mee'`) |
| eind | ✅ | `'Precies op de trap!'` (sombalk leeg, kaart met vinkje) |
| knoppen sprong | 🪨 | `'sprong <k>'` of `'terug <k>'`, strooktitel `'kies je sprong'` |
| knoppen aantal | 🪨 | `'<n> keer'`, strooktitel `'hoeveel sprongen?'` |
| hulp | — | geen: na een misser komt er geen telregel (eigenaar 2026-09-24) |
| bij het dier na een foute sprong | 🔄 | `'Nog een keer'`, het dier sip (`Ui.misser`) |
| bij het dier op het eind | ⭐ | `'op de trap'` |

Diersoortpictogrammen: `puppy 🐶`, `poes 🐱`, `konijn 🐰`, `gans 🦆`, onbekend
`🐾`. "Krap" is een kader smaller dan **320 px**: dan telt één korte regel zwaarder
dan een hele zin.

Cijfers in de wereld: het getal van de gast als grote chip boven zijn kop
(`getalTag`, `y: 30`, `prio 10`, 48 px) — tijdens het hinkelen de sprongteller
(1 … 2 … 3), daarna het getal van de steen, en in fase `af` geen chip meer (§3.8);
de getallen van de stenen en het doelgetal zitten **in de modellen**.

### 3.10 Stoppen en herstellen

`stop()`: tikjes af, `hopNr++` (lopende reeksen ongeldig), staat het spel midden
in een sprong dan `pose(gast, 'wacht')` (een houding is een nieuw bevel, dus de
belofte valt `false` en het dier blijft niet in de lucht hangen), de opzij
gestuurde gasten krijgen `pose('rust')`, alle hotspots weg, geleende knoppen
terug, al het eigen decor weg.

`start()` hergebruikt de bewaarde stand alleen als hij bestaat, niet `af` is, en
`dag`, `N`, `band` en de gast nog kloppen. **Een sprong overleeft geen herlaad**:
fase `hop` wordt teruggezet naar `sprong`.

---

## 4. G4 — DE WASMANDTOREN (`was`)

### 4.1 Verhaal en kamer

In de **wasserij** ligt een berg wasgoed op de vloer; tegen de achterhoek staan
2 tot 4 kratten, elk met zijn eigen pictogram. Elk stuk was dat in de goede krat
gaat wordt een blokje op een stapel, dus **de kratten worden samen een echt
staafdiagram**. Is de berg leeg, dan komt er één vraagkaart bij de kratten en
gaat het rekenen over dat diagram.

Kamer `wasserij`: 100 × 90 voxels, wand 52, vloer `tegel`, `loop 1.25`, één deur
naar de keuken in de achterwand (`x` 62…74 op `z = 0`); vast decor `kast`
(28, 6) als wasrek en `tobbe` (80, 74) als wastobbe.

**De vier soorten** (de volgorde is ook de moeilijkheidsvolgorde):

| i | id | icoon | meervoud | enkelvoud | kleur | naadkleur |
|---|---|---|---|---|---|---|
| 0 | `sok` | 🧦 | `sokken` | `sok` | `#E86A9A` | `#C9527E` |
| 1 | `sjaal` | 🧣 | `sjaals` | `sjaal` | `#5FA8D3` | `#3E85AE` |
| 2 | `doek` | 🧺 | `doeken` | `doek` | `#F2C14E` | `#D09F2E` |
| 3 | `knuf` | 🧸 | `knuffels` | `knuffel` | `#8DBF6B` | `#6C9E4C` |

Eén woord per soort, overal hetzelfde (kaart, keuzeknop, plaatje op de krat):
**"doeken", niet "handdoeken"** — een plaatje van 91 px past niet tussen kratten
die 63 px uit elkaar staan, en twee namen voor dezelfde stapel leest een kind
niet als dezelfde stapel. De langste zin blijft daarmee
`'Hoeveel meer knuffels dan doeken?'` (33 tekens).

### 4.2 Aanmelding en start

```
id: 'was'   naam: 'Wasmandtoren'   kamer: 'wasserij'   stub: false
hotspot: { obj: 'tobbe', icoon: '🧺', label: 'Was sorteren', hoog: 14,
           dx: −20, dz: −20 }          // (80,74) − (20,20) = (60,54) = de berg
unlock: N >= 1
geen `wens`
taak: { icoon: '🧺', tekst: 'Was sorteren', prio: 8 }   // altijd beschikbaar
```

Er is geen vast decorstuk "berg wasgoed" in `rooms.js` en los decor bestaat pas
zodra het spel loopt, dus de startknop hangt aan de wastobbe met een zetje naar
de plek waar de berg straks ligt.

### 4.3 De getallen per band

```
BAND = { 3: {plaf: 12, soorten: 3, per: 1, kset: [1, 2]},
         4: {plaf: 20, soorten: 3, per: 1, kset: [1, 2, 3, 4, 5]},
         5: {plaf: 30, soorten: 4, per: 2, kset: [1,2,3,4,5,6,7,8,9,10]} }
```

`per` is het aantal stuks per tik (groep 5 pakt er twee tegelijk). `plaf` is het
plafond aan stuks: 12 in groep 3, 20 in groep 4, 30 in groep 5 (dus hooguit 15
tikken).

**T kiezen** (`kiesT`): loop alle `(k, r)` met `k` uit `kset` en `r = k−1 … 0`
langs; `T = k·N + r`; sla over als `T > plaf` of (bij `per = 2`) `T` oneven is.
Per uniek `T` blijft de `(k, r)` bewaard waarvan `r` het dichtst bij de rest van
de **bevroren** `sommen.deel(N, band, dag)` ligt. Filter op `T ≥ 3·per`
(minstens 3 blokjes, anders zijn er geen twee verschillende stapels). Sorteer
aflopend op `T`, neem de kandidaten met `T ≥ Tmax − 2·per`, hooguit drie, en kies
daaruit nummer `(dag − 1) mod aantal`. Noodgeval (zelfs `k = 1` loopt over het
plafond): `T = plaf` (bij `per = 2` naar beneden afgerond op even) en `k = 0` —
de vorm `k·N + r` klopt dan niet meer en dat wordt eerlijk zo gemeld.

**Verdelen** (`verdeel(blokken, m)`), met `blokken = floor(T / per)`: basis
`1, 2, …, m`; is er te weinig, dan `m` gelijke stapels met het restje op de
laatste. Anders `q = floor((blokken − basis)/m)`, `rest = (blokken − basis) − q·m`,
en stapel `i` krijgt `1 + i + q + (i ≥ m − rest ? 1 : 0)`. Zo zijn alle stapels
**altijd verschillend**, dus "welke stapel is het hoogst" heeft precies één
antwoord.

**Hoeveel soorten** (`soortenVoor`): begin bij `BAND[band].soorten` en zak omlaag
(niet onder 2) zolang `blokken < m(m+1)/2`. Zo sorteert groep 5 met één gast
(T = 18, 9 blokjes) drie soorten in plaats van vier — een nette afbouw, geen
uitzondering.

**Door elkaar** (`prng(1000·band + 37·N + dag)`, mulberry32-achtige generator):
eerst de stapelgroottes Fisher-Yates schudden (zodat de hoogste niet elke dag
dezelfde soort is), daarna de rij op de berg (één plek per tik) uit dezelfde
generator schudden.

```
prng(seed):  a = seed >>> 0
             a = a + 0x6D2B79F5 | 0
             t = imul(a ^ a>>>15, 1|a)
             t = t + imul(t ^ t>>>7, 61|t) ^ t
             return ((t ^ t>>>14) >>> 0) / 4294967296
```

**Nagerekend (verified):**

| N | band | dag | k | r | T | per | soorten | stapels |
|---|---|---|---|---|---|---|---|---|
| 2 | 3 | 1 | 2 | 1 | 5 | 1 | 2 | 3, 2 |
| 3 | 3 | 2 | 2 | 0 | 6 | 1 | 3 | 1, 2, 3 |
| 3 | 3 | 3 | 2 | 1 | 7 | 1 | 3 | 2, 1, 4 |
| 5 | 4 | 1 | 4 | 0 | 20 | 1 | 3 | 8, 5, 7 |
| 6 | 4 | 2 | 3 | 1 | 19 | 1 | 3 | 8, 6, 5 |
| 8 | 5 | 1 | 3 | 2 | 26 | 2 | 4 | 4, 5, 1, 3 |
| 9 | 5 | 2 | 3 | 1 | 28 | 2 | 4 | 3, 4, 2, 5 |
| 10 | 5 | 3 | 3 | 0 | 30 | 2 | 4 | 6, 3, 2, 4 |
| 1 | 5 | 1 | 10 | 8 | 18 | 2 | 3 | 3, 4, 2 |

De hoogst mogelijke stapel is **8 blokjes** (groep 4, 3 soorten uit 20 stuks).

### 4.4 Waar staat wat

De kratten staan op één lijn van **gelijke diepte** in de achterhoek — op het
scherm een rechte horizontale grondlijn, alleen zo staan de stapels op dezelfde
vloerhoogte en is het echt een staafdiagram. Een rij langs één wand zou op het
scherm een steile schuine lijn zijn.

```
som = round((kamer.w + kamer.d) · 0,347) = round(190 · 0,347) = 66
krat i (van m):  x = round(som/2 − 4 + (i − (m−1)/2) · (m > 3 ? 16 : 22))
                 z = som − x
```

| m | kratten (x, z), van links naar rechts |
|---|---|
| 2 | (18, 48), (40, 26) |
| 3 | (7, 59), (29, 37), (51, 15) |
| 4 | (5, 61), (21, 45), (37, 29), (53, 13) |

De stap langs de lijn is 22 voxels bij twee of drie kratten (44 in `x − z`, dus
86 px bij `k = 1` en 59 px op een kleine telefoon: daar past het hele woord
naast elkaar) en 16 bij vier kratten, want breder botst de buitenste krat met de
wand of met de deuropening.

* berg: `Rooms.plek('wasserij', 0.60, 0.60)` = **(60, 54)** — midden-voor op de
  vloer, vóór de rij;
* vraagkaart: `Rooms.plek('wasserij', 0.88, 0.933)` = **(88, 84)** — nog verder
  naar voren (grotere `x + z`), dus zij dekt het diagram nooit af, en zij komt
  pas in beeld als de berg leeg is;
* legenda-wolkje: `Rooms.plek('wasserij', 0.12, 0.30)` = **(12, 27)**.

### 4.5 De modellen

**`was_krat`** (params `soort`, `n`, `voet`, `stap`), hout `#D0A87A` /
donker `#B98F62` / licht `#E2C094`:

* `y0 = klem(round(voet), 0, 18)`; `stap = klem(round(stap), 2, 3)`;
  `n = klem(round(n), 0, floor((50 − y0 − 2)/stap))` — de stapel blijft onder de
  wandhoogte van de wasserij (52 voxels);
* is `y0 ≥ 6`, dan een **bankje**: blad `bx(−6, y0−4, −5, 13, 4, 11)` donker en
  vier pootjes `bx(∓5/3, 0, ∓4/2, 3, y0−4, 3)` (achter donker, voor licht); is
  `0 < y0 < 6`, dan één blok `bx(−6, 0, −5, 13, y0, 11)`;
* bodem `bx(−6, y0, −5, 13, 2, 11)`, randen achter/voor/links/rechts
  (`bx(−6, y0+2, −5, 13, 3, 1)` donker, `bx(−6, y0+2, 5, 13, 3, 1)` licht,
  `bx(−6, y0+2, −4, 1, 3, 9)` donker, `bx(6, y0+2, −4, 1, 3, 9)` licht);
* per blokje `i`: `bx(−4, y0+2+i·stap, −3, 9, stap−1, 7)` in de soortkleur plus
  `bx(−4, y0+1+stap+i·stap, −3, 9, 1, 7)` in de naadkleur — **elk blokje is dus 2
  voxels kleur + 1 voxel donkere naad, zodat je de blokjes op het scherm echt
  kunt tellen**.

Waarom een bankje: de vraagkaart hangt vóór de kratten, en op een laag kader
(860 × 420 geeft 688 × 278; 320 × 640 zelfs 286 × 190) schuift die kaart omhoog
tot tegen de kratten. Staan de blokjes 18 voxels boven de vloer, dan dekt de
kaart hooguit het bankje af en blijft het staafdiagram in zijn geheel telbaar.

**`was_berg`** (param `n`): acht plukjes op **vaste** plekken, één keer bepaald
met `prng(90210)` bij het laden (`[dx, dy, dz, kleurkeus]` met
`dx, dz ∈ −8…8`, `dy ∈ 0…3`); getekend worden er `m = klem(ceil(n/2), 1, 8)`, elk
een `ell(dx, 2+dy, dz, 4.2, 2.8, 4.2, kleur, {e: 2.4, ymin: 0})`, in de kleur of
de naadkleur van soort `i mod 4`. Bij `n = 0` een **lege lijst**, dus geen
plaatje. Dezelfde params geven altijd dezelfde lijst (de motor cachet op params).

### 4.6 De indeling wordt gemeten, niet gegokt (bindend)

Twee dingen mogen nooit gebeuren:

* **C1** — het naamplaatje van een krat mag niet ónder de krat belanden. De
  hotspot-laag doet dat zelf zodra er boven de stapel geen 48 px over is, en
  onder de krat staat de vraagkaart; dan is niet meer te zien welke stapel de
  sokken zijn. Gemeten vóór deze regel liet 320 × 640 alleen `sokken` staan, en
  844 × 390 en 740 × 360 zetten alle drie de plaatjes achter de kaart.
* **C2** — de kaart mag geen blokje van het staafdiagram afdekken.

Beide hangen aan één knop: de hoogte van het bankje. Uit `Hits.debug()` komen het
anker van elk plaatje, de hoogte van het voorwerp eronder (`vh`), de
plaatjesbreedte en de voxelmaat `tk`; de bovenrand van de kaart komt uit de DOM
(`[data-hot="ws_vraag"]`).

```
vloer   = anker[1] van de eerste krat + vh                 // ligt vast
hoogste = max over i van DOEL[i]                           // het doel, niet de stand van nu
plaatH  = max plaatjeshoogte
stap    = 3
voetMax = floor((vloer − plaatH − 6)/tk) − 4 − stap·hoogste          // C1
voetMin = kTop === null ? 0 : ceil((vloer − kTop)/tk) − 2            // C2
als voetMin > voetMax en hoogste > 0:  stap = 2 en voetMax opnieuw
voet    = klem(voetMax, 0, 18)
als voetMin > voet en voetMin ≤ voetMax:  voet = klem(voetMin, 0, 18)
```

Kan het niet allebei — dat komt in geen van de zes gemeten kadermaten voor — dan
gaat **C1 voor**: een plaatje dat achter de kaart verdwijnt maakt de vraag
onbeantwoordbaar, een blokje dat onderaan een kiertje mist niet. Met blokjes van
2 in plaats van 3 voxels wordt de staaf korter en past het weer allebei
(320 × 640 op een scherm met dichtheid 2, acht blokjes).

**Plaatjesbreedte** (`tier`): 2 = het hele woord (`sokken`), 1 = enkelvoud
(`sok`), 0 = alleen het pictogram. Overlappen twee buren elkaar
(`over = max over buren van ((w_i + w_{i−1})/2 − (px_i − px_{i−1})) > −2`, dus
minder dan 2 px lucht), dan een maatje kleiner; past zelfs het pictogram alleen
niet, dan gaat `vast` uit en mogen de plaatjes **wél** uitwijken: dan is
niet-overlappen belangrijker dan pal boven de eigen krat staan.

**Meetmomenten:** `LAY_TIJD = [150, 90, 90, 120, 300, 500, 500, 900]` ms
(cumulatief tot ≈ 2,65 s na het tekenen). Reden: de knoppenlaag zet plekken pas
in de volgende tekenbeurt, `ui.js` zet zijn kaart in twee rondes van 90 ms vrij,
de cijferstrook onder het kader gaat open (dat maakt het kader lager en dus de
camera anders) en `ui.js` mag daar tot 400 ms later nog op terugkomen. Verandert
de kadermaat, dan wordt de indeling gereset en begint de reeks opnieuw; alleen de
**jongste** reeks loopt (`LAY.gen`). Zolang `vloer` of de bovenrand van de kaart
nog beweegt (`geo` verandert) blijft het spel doorkijken, ook als er niets te
veranderen valt. Dit hangt ook aan `ctx.ui.opKader`.

`kratY(i) = voet + 4 + stap · vak[i]` is de bovenkant van de stapel; daar hangt
het plaatje boven (`op: 'boven'`).

**Kadergrenzen:**

* `padPlek()` = `'buiten'` als kaderbreedte < **330** of kaderhoogte < **340**,
  anders `'auto'`. Op 320 × 640 (kader 286 × 312) is `auto` net niet laag genoeg
  voor de drempel van de schil, maar wel te laag voor kaart + pad: dan tilt
  `ui.js` de kaart over het staafdiagram heen en steekt het pad 2 px buiten het
  kader.
* `krapKader()` = kaderhoogte < **300** of kaderbreedte < **330**. Op een krap
  kader draagt de vraagkaart **één** regel in plaats van twee (twee regels zijn
  op 320 × 640 samen 114 px hoog, en dan verdwijnen juist de onderste blokjes
  achter de kaart) en staat de legenda als eigen wolkje in de kamer.

### 4.7 Sorteren

De berg is een sleepbron (`ws_berg`, `hoog 18`, `prio 11`) met een eigen
html-inhoud:

```
🧺  <aantal>  "nog te sorteren"   +   handgreep "pak <per>"
titel: 'berg met <n> stuks was, tik om er <per> te pakken'
```

De **teller** hoort bij de berg en wat je in je handen hebt bij je handen: samen
in één knop las een kind het als "🧦 26 twee sokken". Het handwolkje
(`ws_hand`, klas `goed`) hangt **laag** bij de berg (`hoog 2`, `prio 9`), zodat
het nooit bij de naamplaatjes boven de stapels in de weg komt, en zegt
`'een <ev>'` (per = 1) of `'twee <meervoud>'` (per = 2).

* **Tikken**: tik de berg (`pak()`) — dan zit het bovenste stuk in je hand — en
  tik daarna de krat (`legIn(i)`).
* **Slepen**: `dropSel '[data-drop="krat"]'`, sleepplaatje is het soortpictogram
  in een `.karghost`, `canDrag` alleen tijdens het sorteren en zolang er nog wat
  ligt. Wie sleept pakt onderweg op: `onDrop` doet eerst `pak()` en dan `legIn`.
  De hotspot-laag legt over knop + krat één vangvlak, dus je kunt naar de krat
  zelf slepen.
* **Goed**: `vak[i]++`, `i++`, `snd.plop(1)`.
* **Mis**: de krat **wipt even op** (`snd.terug()`), het stuk ligt weer op de
  berg, en bij die krat hangt 1,2 s `🔄 Nog een keer` (het spel heeft geen dier
  van de beurt en tijdens het sorteren geen kaart; eigenaar 2026-09-24). Geen
  tekst over welke krat het had moeten zijn, geen rood, geen ster minder. Het wipje is
  `[[0 ms, 3 voxels], [140, 2], [200, 1], [260, 0]]` en leeft in losse
  variabelen (níet in het decorstuk zelf), want het decor wordt bij elke tik
  opnieuw gezet en zou een losse `hoog: 3` in dezelfde tik weer op 0 zetten.
* **Lege hand op een krat**: `snd.zacht()` en de berg krijgt even de klasse
  `hulp` (320 ms), zodat het kind ziet waar het begint. Er gebeurt verder niets.
  (Dat is geen antwoord maar een tik op de verkeerde plek; het wijst de bediening
  aan, niet de som, en blijft dus.)

Is de rij op, dan `klaarMetSorteren()`: stap → `vraag1`, `missers = 0`, de klok
opnieuw, `snd.ja()`, en de vraagkaart komt.

### 4.8 De vragen over het diagram

`stuks(i) = vak[i] · per`; `hoogsteIdx` / `laagsteIdx` zijn de eerste index met
de grootste respectievelijk kleinste stapel (ze zijn altijd uniek).

| band | vraag 1 | vraag 2 |
|---|---|---|
| 3 | `'Welke stapel is het hoogst?'` — keuzestrook met de soorten (icoon + woord), strooktitel `'kies een stapel'`. Antwoord = `hoogsteIdx`. **Geen tweede vraag.** | — |
| 4 | `'Hoeveel meer <hoogste> dan <laagste>?'`, sombalk `'<stuks(h)> − <stuks(l)> ='`, cijferpad (`max 2`, `open: true`) | `'Hoeveel stuks samen?'`, sombalk `'<a> + <b> + <c> ='` |
| 5 | `'Hoeveel <hoogste> zijn het?'` (blokjes × 2), tweede regel `'📦 Elk blokje is 2 stuks'` (alleen op een ruim kader), cijferpad | `'Hoeveel meer <hoogste> dan <laagste>?'` |

Bij band 5 staat er **geen** sombalk (die is leeg): de opgave is het omrekenen
zelf.

**Geen hulp na een fout** (eigenaar 2026-09-24, §0.5): de hulpladder van
vroeger — `'tel de blokjes'`, `'kijk naar de hoogste stapel'`, de teller-rijen en
bij de derde poging de spookcijfers op de kratten of op de berg — bestaat niet
meer, ook niet na een herlaad.

**Goed antwoord**: `snd.ja()`, de kaart krijgt het antwoord en een vinkje
(`k.zet(n).klaar()` — bij band 3 `kaart.zet('✓').klaar()`), `volgende()`.
**Fout**: `snd.zacht()`, `missers++`, en de misser van `Ui`: de strook staat
1,2 s op slot (ook de soortenstrook van band 3) met `🔄 Nog een keer` bij de
kaart, het vakje toont zolang het getikte getal en is daarna leeg, en dezelfde
keuzes komen terug. Geen hulpregel, geen spookcijfers. Elk antwoord (goed of
fout) meldt `state.tel(goed, ms sinds de vraag)`.

`volgende()`: `missers = 0`; bij band 3, of als vraag 2 net is beantwoord, stap →
`af` en de ster valt; anders stap → `vraag2`. Na **750 ms** komt de nieuwe kaart.

**De eindkaart**: icoon `✅`, regel `'Alles gesorteerd!'`, één knop
`👍 'klaar'` met strooktitel `'klaar'`, die `ctx.sluit()` aanroept.

**De ster** (`ster()`): eenmalig, `snd.hoera()` en `taakKlaar('was',
{sterren: 1})`.

### 4.9 De legenda (alleen band 5)

Een wolkje `📦 'Elk blokje is 2 stuks'` (`id ws_legenda`, `hoog 20`, `prio 6`)
staat er tijdens het sorteren altijd, en tijdens de vraag alleen als de legenda
niet op de kaart zelf past (krap kader). Bij `stap === 'af'` staat hij er niet.

### 4.10 Kindtekst, letterlijk

| moment | tekst |
|---|---|
| icoontje / prikbord | `'Was sorteren'`, icoon `🧺` |
| berg | `🧺` + aantal + `'nog te sorteren'` + `'pak 1'` of `'pak 2'` |
| in je hand | `'een sok'` / `'een sjaal'` / `'een doek'` / `'een knuffel'`, of `'twee sokken'` / `'twee sjaals'` / `'twee doeken'` / `'twee knuffels'` |
| krat (label) | `'sokken'` → `'sok'` → alleen 🧦 (naar gelang de ruimte) |
| krat (titel) | `'krat met <meervoud>: <n> blokje'` / `'… blokjes'` |
| legenda | `'📦 Elk blokje is 2 stuks'` |
| band 3 | `'Welke stapel is het hoogst?'`, strooktitel `'kies een stapel'` |
| band 4 | `'Hoeveel meer <a> dan <b>?'`, dan `'Hoeveel stuks samen?'` |
| band 5 | `'Hoeveel <a> zijn het?'`, dan `'Hoeveel meer <a> dan <b>?'` |
| misser | `🔄 Nog een keer` (bij de kaart, of bij de krat na een foute sortering) — geen hulpregel meer (2026-09-24) |
| eind | `'Alles gesorteerd!'` met knop `'klaar'` |

### 4.11 Stoppen en herstellen

`stop()`: tikjes af, de kader-luisteraar op, wip-stand op nul, alle hotspots weg,
geleende knoppen terug, al het eigen decor weg.

`start()` hergebruikt de bewaarde stand alleen als hij bestaat, een rij en vakken
heeft, niet `af` is en `dag`, `N` en `band` nog kloppen. Staat de stand al bij de
vragen, dan komt de vraagkaart meteen terug, met de missers geteld maar zonder
hulp (die bestaat sinds 2026-09-24 niet meer).

---

## 5. G5 — DE SOUVENIRKRAAM (`kraam`)

### 5.1 Verhaal en kamer

In de **tuin**, in de zone `Rooms.get('tuin').zones.kraam` = `{x0: 104, x1: 126,
z0: 36, z1: 68}` (22 × 32 langs de rechter zijrand), staat een marktkraam met een
toonbank en drie of vier uitgestalde spullen, elk met zijn prijs als kaartje. De
gast met de wens 🎁 loopt ernaartoe en gaat ervóór staan. Het kind rekent (band 4
en 5) en legt daarna munten op de toonbank. Gelukt: het gekochte komt **zichtbaar
op het dier** en blijft daar tot uitchecken.

Alle stukken van de kraam zijn **los decor** van dit spel: ze staan er alleen
zolang je speelt, en nooit in de hinkelzone ernaast (`hinkel` x ≤ 100 < 104
`kraam`).

**Wie koopt** (`kandidaten`): gasten met een bed én `behoefte === 'souvenir'` én
`!blij`; is die lijst leeg, dan alle gasten met een bed (dezelfde vriendelijke
terugval als de tobbe). Is ook dát leeg: wolkje `🎁 'nog geen gasten'` bij
`(zone.x0, zone.z1)` en na 1800 ms sluiten.

**Het dier van de beurt** (Godot-poort, §0.12). `spelers()` = elke gast met een bed,
in check-in volgorde — ook een gast zonder de wens 🎁: die koopt gewoon iets zonder
wens (`wens: 0`, dus ook geen wens ingelost). Een gekozen dier dat erop staat koopt,
vóór `kandidaten`; een bewaarde beurt van een ander dier wordt niet hervat. Wie bij de
wissel nog aan de toonbank wachtte loopt naar een vrij plekje in de tuin, en wie nog
onderweg was gaat terug naar bed (`ctx.laat_gaan`, nadat de nieuwe gast op weg is
gestuurd; een slaper wordt nooit gewekt) — anders stonden er twee dieren op dezelfde
plek.

### 5.2 Aanmelding en start

```
id: 'kraam'   naam: 'Souvenirkraam'   kamer: 'tuin'   stub: false
hotspot: { obj: 'bal', dx: −5, dz: −18, icoon: '🎁', label: 'Kraam', hoog: 14 }
          // bal staat op (120, 76) → knop op (115, 58): op de toonbank
unlock: N >= 1
wens: 'souvenir'
taak: { id: 'souvenir', prio: 1, icoon: '🎁',
        wanneer: er is een gast met behoefte 'souvenir' en !blij,
        tekst: '<naam> wil een souvenir'  of  'Souvenir' }
```

### 5.3 De waren, de munten en het rekenen per band

```
WAREN (basisprijs uit de spec):  hoedje 🎩 'het' acc:hoedje   basis 4
                                 sjaaltje 🧣 'het' acc:sjaaltje basis 3
                                 bal ⚽ 'de' acc:bal            basis 5
                                 tas 🎒 'de' acc:null           vast €12
MUNTEN = { 3: [1, 2], 4: [1, 2], 5: [1, 2, 5] }      PLAFOND = €20
```

De 🎒 tas van band 5 is er alleen als **vierde prijskaartje**: de gast koopt
altijd iets dat hij ook kan **dragen**, zodat het gekochte na het afrekenen echt
op het dier te zien is (`ctx.wereld.accessoire` kent alleen `hoedje`, `sjaaltje`
en `bal`).

```
schuifVan(N, band, dag):
    v      = (N + dag) mod (band ≥ 5 ? 4 : 2)
    schuif = (band ≤ 3) ? −v : +v            // groep 3 gaat omlaag (liefst t/m 10)
    rot    = (N + 2·dag) mod 3               // de prijzen roteren over de spullen

opzet(N, band, dag):
    basis  = [4, 3, 5]
    prijs van waar i (i = 0,1,2) = basis[(i + rot) mod 3] + schuif ; tas = 12
    draag  = de waren met een accessoire (hoedje, sjaaltje, bal)
    i0     = (N + dag) mod 3
    band 3: keus = [draag[i0]]
    band 4/5: keus = [draag[i0], draag[(i0+1) mod 3]]
    kosten  = som van de gekozen prijzen
    betaald = (band ≥ 5) ? (kosten ≤ 9 ? 10 : 20) : kosten
    wissel  = betaald − kosten
    doel    = (band ≥ 5) ? wissel : kosten          // wat het kind neerlegt
    vraag   = band 4 → { som: '€a + €b =', goed: kosten }
              band 5 → { som: '€betaald − €kosten =', goed: wissel }
              band 3 → geen som
```

**De regels die hard zijn** (HOTEL.md §3 en §4): hele euro's, geen centen, nooit
meer dan **€20** per betaling, in groep 3 geen prijs boven €10, nooit twee keer
dezelfde prijs op de kraam, nooit een doelbedrag van €0 of negatief wisselgeld,
en in groep 5 altijd wisselgeld ≥ €1. `keuring(opzet)` rekent dat na en geeft
een lijst klachten; **leeg = goed**.

**Nagerekend (verified):** `keuring` geeft nul klachten over **alle**
combinaties N = 1…12 × dag = 1…12 × band 3, 4, 5.

| band | prijzen die voorkomen | kosten | betaald | wisselgeld |
|---|---|---|---|---|
| 3 | €2…€5 per spulletje | €2…€5 (één spulletje) | = kosten | €0 |
| 4 | €3…€6 per spulletje | €7…€11 (twee spullen) | = kosten | €0 |
| 5 | €3…€8 per spulletje, tas vast €12 | €7…€15 (twee spullen) | €10 (kosten ≤ 9) of €20 | €1…€10 |

Worked example (band 5, N = 9, dag = 2): `v = (9+2) mod 4 = 3`, `schuif = +3`,
`rot = (9 + 4) mod 3 = 1` → hoedje `basis[1]+3 = 6`, sjaaltje `basis[2]+3 = 8`,
bal `basis[0]+3 = 7`, tas 12. `i0 = 11 mod 3 = 2` → keus = bal + hoedje =
€7 + €6 = **€13**; `13 > 9` → betaald **€20**, wissel **€7**, doel €7, som
`'€20 − €13 ='`.

**De spookmunten** (voordoen-rij) worden sinds 2026-09-24 niet meer getoond (geen
hulp na een fout, §0.5); de bevroren kern draagt ze nog, byte-gelijk:
`SPOOK_MUNT = [5, 2, 1]` en hooguit `SPOOK_MAX = 4` munten: met €5, €2 en €1 is elk bedrag t/m €13 in hooguit vier
munten te leggen, en vier is precies wat er naast elkaar past. Met alleen €1 en
€2 zou €9 vijf munten kosten en werd er €8 voorgedaan waar €9 hoort (G5-F1).
`splitsMet(bedrag, munten)` is de gewone gulzige verdeling (grootste munt eerst).

### 5.4 De modellen en waar alles staat

```
xm     = round((zone.x0 + zone.x1)/2) = 115
kraamZ = zone.z0 + 4  = 40        (achterschot z 36…42)
bankZ  = zone.z1 − 12 = 56        (blad z 48…64)
bankD  = xm + bankZ   = 171       (de diepte-lijn waarop de spullen liggen)
```

* **kraam** (`kr_kraam`) op (115, 40) — langs de achterrand, dus achter de
  toonbank: zo dekt hij noch de toonbank noch de gast af. Achterschot
  `bx(−10, 0, 0, 21, 24, 2)` in `#D0A87A` met een plankenlijn
  (`verf(−10…10, 10…11, 0…1)` in `#B98F62`), twee staanders
  `bx(∓10/9, 0, −2, 2, 27, 2)`, en een gestreepte luifel: voor `i = 0…5`
  `bx(−10, 27 − floor(i/2), 1 − i, 21, 2, 1)`, om en om `#F5A8BE` en `#FFFDF6`.
* **toonbank** (`kr_bank`) op (115, 56) — een **vierkante** markttafel, want de
  spullen moeten op het scherm naast elkaar staan, en dat is in isometrie de lijn
  `x + z = vast`, die dwars over een vierkant blad loopt. Blok
  `bx(−10, 0, −7, 21, 11, 15)`, groef `verf(−10…10, 4…5, −7…7)` donker, blad
  `bx(−11, 11, −8, 23, 2, 17)` licht.
* **de spullen** liggen op `hoog: 13` (op het blad), op de lijn `x + z = 171`,
  van `(xm − 8, bankZ + 8)` naar `(xm + 8, bankZ − 8)`:
  `f = (n == 1) ? 0,5 : i/(n−1)`, `x = round(107 + 16f)`, `z = 171 − x`.
  Dat is de breedste lijn die helemaal op het blad past (16 voxels in `x`, dus
  32 in `x − z` = 64 css-px in portret).

  | n | plekken (x, z) | tagY per stuk |
  |---|---|---|
  | 3 | (107, 64), (115, 56), (123, 48) | 2, 26, 2 |
  | 4 | (107, 64), (112, 59), (118, 53), (123, 48) | 2, 26, 2, 26 |

  De **prijskaartjes** hangen om en om **26** en **2** voxels boven het blad. Dat
  moet: alle spullen staan op dezelfde diepte, dus zonder dat hoogteverschil
  zouden de kaartjes elkaar raken (band 5 heeft er vier, op 320 × 640 maar 16 px
  uit elkaar, en een kaartje is 33–42 px breed en 23 px hoog). 16 voxels is daar
  26 px, dus ze staan altijd los. Op 18 voxels lag het kaartje precies op het
  hoedje (gemeten: allebei py 220–232, dus het spulletje was onvindbaar).
* **het geld** (het sleep-doel) op `(115, zone.z1 − 4 = 64)`, `y = 13`,
  `op: 'onder'` — boven het blad staan de prijskaartjes (die wijken niet uit) en
  dan zou de laag deze knop een halve tuin naar links schuiven.
* **de gast** op `(zone.x0 − 4, zone.z1 + 26)` = **(100, 94)**: dichter bij de
  kijker dan de tafel en links van de bal. 26 voxels vóór de voorrand van de
  zone, want op 320 × 640 raakte de sommenkaart hem nog bij +10 (gemeten: kaart
  tot 133 px, gast vanaf 125 px).
* **de buidel en het klaar-knopje** staan op een vast plankje op het gras vóór
  de kraam, uitgerekend in **schermpixels**:

  ```
  opGras(uPx, dPx):  d   = zone.x1 + zone.z1 − 22 = 172   (+ round(dPx / pxPerVoxelY))
                     ver = round(uPx / pxPerVoxelX)
                     → { x: round((d + ver)/2), z: round((d − ver)/2) }
  ```

  De hele kraamzone is in portret (420 × 860) maar ≈ 108 px breed en 54 px hoog,
  en één knop is al 84 × 48 px: twee knoppen naast elkaar passen daar niet (de
  laag schoof de buidel naar x = 90). Muntknoppen staan op
  `opGras(−60 − i·62)` (een muntknop is ≈ 56 px breed omdat er alleen "€2" in
  staat) en het klaar-knopje op `opGras(−160)` (tot 2026-09-24 lagen daar ook de
  spookmunten, `opGras(−160 + i·40, 32)`). Dat gras ligt met `z ≥ 100` ruim
  buiten de hinkelzone.

**De uitgestalde spullen zijn met opzet flink** (op de tuinschaal is één voxel
maar 2 css-px): `kr_hoedje` (mint `#6BC5A4`, brede rand
`ell(0,1,0, 4.6,1.8,4.6, {ymin:0})` + hoge bol `ell(0,6,0, 3,4.6,3, {ymin:2})` +
wit lintje), `kr_sjaaltje` (oranje `#F6A957`, drie opgevouwen lagen
`bx(−4,0,−3, 9,4,7)`, `bx(−3,4,−2, 7,4,5)`, `bx(−2,8,−1, 5,2,3)` + witte franje),
`kr_bal` (roze `#F5A8BE`, `ell(0,4.4,0, 4.4,4.4,4.4, {e: 2.0})` + witte
evenaar), `kr_tas` (leer `#B4744A` / `#8E5B3A`, `bx(−4,0,−3, 9,8,6)` + flap +
hengsel). Alles blijft binnen 21 voxels in x en 11 in z, zodat elk stuk met zijn
anker midden in de zone helemaal binnen die zone valt.

### 5.5 De gast halen

Staat de gast in een andere kamer, dan `reis(id, 'tuin', {x, z, na: 'wacht'})` —
**één keer**, want onderweg opnieuw sturen begint zijn route opnieuw — en daarna
elke **700 ms** opnieuw kijken, hooguit **24** keer. Zodra hij in de tuin is,
`loopNaar(P.gast.x, P.gast.z, {na: 'wacht'})`; op zijn aankomst wordt de
sommenkaart opnieuw nagemeten, want pas dan weten we waar hij staat en **de kaart
mag nooit over hem heen liggen**.

**Godot-poort (eigenaar 2026-09-23, §0.12):** het halen is `ctx.wacht_op(gast, P.gast)`
(world.md §5.3) — ook die stuurt een reis maar één keer en laat een gast die al onderweg
is zijn route houden. De kraam, de toonbank en de waren staan er meteen; de sommenkaart,
de prijskaartjes, de munten en de ✔ komen pas als hij voor de toonbank staat. Tot dan
hangt het hotelwolkje `🐶 Boef komt eraan` met zijn balk en `👀 Volg` bij de tuindeur. Er
hoeft dus niets meer nagemeten te worden: de kaart wordt pas getekend als hij er staat.

### 5.6 De kaart, het cijferpad en de nameting (bindend — G5-F2)

* **`kortKader()`**: kaderhoogte < **340** of kaderbreedte < **360**. Dan draagt
  de kaart alleen de **eerste** zin (die noemt het spulletje en de prijs) en doet
  de somregel eronder de vraag. Een kaartje met twee zinnen is op 320 × 640
  129 px hoog en past samen met de gast (83 px) en de knoppen niet meer in
  304 px.
* **`padPlek()`**: is de **strookvrije** kaderhoogte kleiner dan
  `KADER_PADRUIM = 360` px, dan komt het cijferpad als **strook onder het kader**
  (`'buiten'`), anders `'auto'`. Strookvrij meten wil zeggen: staat onze eigen
  strook (`#padstrip` met `data-hot="kr_som_pad"`) er al, tel dan zijn hoogte
  plus 4 px kier bij de kaderhoogte op — anders hangt de meting van onze eigen
  keuze af en kan het pad heen en weer springen.
  Gemeten: op 860 × 420 (kader 682 × 340) lag het pad op 55…693 × 333…399, dus
  over de prijskaartjes (320…344) en over de gast (269…367); staand op 320 × 640
  (kader 304 px) lag het pad op 349…451 en de gast op 285…357, 8 px eroverheen.
  Boven de 360 px is er wél ruimte onder de kraam (360 × 740, kader 395: pad
  399…509, gast tot 383; 420 × 860, kader 468: pad 447…565, gast tot 429).
* **Kaarthoogte**: `kaartHoog() = round(145 / pxPerHoogte) + kaartLift`.
* **Nameten** (`kaartPast`, elke **120 ms**, hooguit **7** rondes):

  ```
  de harde regel gaat voor: raakt de kaart de gast (marge 2 px), dan
      stap = ceil((kaart.onder − (gast.boven − 6)) / pxPerHoogte)      // omhoog
  anders: valt de kaart boven de kaderrand + 4 px   → stap omlaag
          valt de kaart onder de kaderrand − 4 px   → stap omhoog
  kaartLift = klem(kaartLift + stap, −60, 80)
  ```

  Het gastvak volgt uit zijn **naamplaatje**: de onderrand van dat plaatje staat
  op zijn kop (30 voxels boven de vloer), dus `vloer = plaatje.bottom +
  30·pxPerHoogte`, halve breedte `max(24, 27·pxPerVoxelX/2)`.
  Nameten verandert alleen de hoogte van één hotspot en meldt dus niets terug —
  **hier nooit opnieuw `teken()`**, want een hertekening haalt de oude kaart weg
  en zet een nieuwe neer, dat zijn twee kaderveranderingen, dus twee meldingen,
  dus een lus (nagemeten: 86 busslagen in 2,6 s).
* **Bij een kadermelding** (`ctx.ui.opKader`): meteen nameten, én nog een keer na
  **560 ms** — voorbij de 400 ms die de mobiele schil zichzelf gunt, want bij een
  kadermelding zet de schil de kaart zelf terug op de hoogte waarmee hij gemaakt
  is en ging onze correctie eronderdoor. De luisteraar wordt **vóór** de eerste
  `teken()` aangemeld: de strook vraagt zelf meteen een hermeting aan en die bus
  slaat nog tijdens diezelfde `teken()` (gemeten op 860 × 420: 7 ms na
  `Games.start`).
* Extra nametingen na de start op **1500 ms** en **3200 ms**, voor het geval de
  gast nog uit een andere kamer onderweg is.

### 5.7 De zinnen op de kaart

```
band 3:  '<naam> wil <lid> <spul> van €<prijs>'
         'Leg de munten op de toonbank'
band 4, stap 'som':   '<Spul1> €<p1> en <spul2> €<p2>'     (eerste woord met hoofdletter)
                      'Hoeveel euro samen?'
band 4, stap 'leg':   'Samen kost het €<kosten>'
                      'Leg de munten op de toonbank'
band 5, stap 'som':   '<naam> gaf €<betaald>, het kost €<kosten>'
                      'Hoeveel krijgt hij terug?'
band 5, stap 'leg':   '<naam> krijgt €<wissel> terug'
                      'Leg het wisselgeld neer'
stap 'af':            'Veel plezier ermee!'
```

Somregel: bij de vraag de som zelf (`'€4 + €5 ='` of `'€20 − €13 ='`), bij het
betalen het **doelbedrag** (`'€7'`). Het antwoordvakje ernaast vult de kaart zelf
met wat er **nu** op de toonbank ligt, zodat er nooit een leeg vakje staat waar
je niets mee kunt. Icoon: `✅` (af), `👛` (band 5), anders `🎁`.

### 5.8 De munten

* **Elke munt heeft zijn eigen sleepbron** (`kr_m1`, `kr_m2`, `kr_m5`): €1 en €2
  in groep 3 en 4, en €1, €2 en €5 in groep 5. Eén knop met een wisselaar zou in
  groep 5 drie standen hebben, en dan is "welke munt heb ik in mijn hand" precies
  de fout die je bij het wisselgeld niet wil maken. De munt in je hand krijgt
  `hand: '☝'` en `prio + 1`.
* **Tikken** (`pakMunt`) pakt de munt in je hand: `snd.tik()` en het wolkje
  `🪙 '€<v>' 'in je hand'`. **Slepen** legt hem meteen op de toonbank
  (`dropSel '[data-drop="kr_geld"]'`, sleepplaatje `ctx.econ.munt(v)`, `canDrag`
  alleen in de stap `leg`).
* **De toonbank** (`kr_geld`, `prio 11`, klas `hotbron`) draagt `🧾` + `'€<som>'`
  met titel `'op de toonbank ligt €<som> van €<doel>'`; het vangvlak van de laag
  dekt knop én blad, dus je kunt ook gewoon naar de tafel slepen.
* **Te veel gelegd** (`som + v > doel`): de munt gaat er even op en **schuift na
  750 ms terug**; `snd.munt()` bij het leggen, `snd.terug()` bij het
  terugschuiven, `missers++`, en de klant is even sip met `🔄 Nog een keer`
  (`ctx.ui.misser`, geen slot: de munten liggen niet op een strook). Er komt
  géén wolkje meer dat zegt hoeveel te veel het was (tot 2026-09-24
  `🪙 '€<teveel>' 'terug'`). Zolang er een munt terugschuift neemt de kraam er
  geen nieuwe aan (dan alleen `snd.zacht()`) — zonder die poort legt elke tik in
  dat halve seconde-venster een munt bij terwijl er maar één terugkomt.
  **De geweigerde munt ligt alleen op het beeld, nooit in de opslag**: `gelegd`
  houdt altijd een geldige stand (`≤ doel`). Anders bleef een herlaad midden in
  die halve seconde met een volle toonbank zitten en weigerde elke tik — de beurt
  liep vast (G5-F1 punt 1). `herstelBank()` haalt bij het starten een
  eventueel teveel gewoon van de toonbank af.
* **✔ klaar** (`klaarMetTellen`): klopt het bedrag, dan `gelukt()`. Klopt het
  niet: `legPog++`, `missers++`, `snd.zacht()` en de klant is even sip met
  `🔄 Nog een keer`. Nooit rood, nooit een kruis — en nooit een hint (eigenaar
  2026-09-24): geen `'+€<verschil>' 'erbij'`, geen hulpregel
  `'€2 + €2 + €1'`, geen spookmunten. De tweede kaartregel `'Nog €<rest> erbij'`
  (N7) telt wél af zodra er iets ligt: die staat er vanaf de eerste munt, bij
  goed en fout gelijk, en is dus geen antwoord op een misser.

### 5.9 Het cijferpad (band 4 en 5)

`antwoordSom(n, k)`:

* `n == null` (op OK getikt zonder cijfer): wolkje `☝ 'tik een getal'`;
* fout: `somPog++`, `missers++`, `snd.zacht()`, en de misser van `Ui` via de
  kaart (die sinds 2026-09-24 `dier` = de klant meekrijgt): hij is even sip met
  `🔄 Nog een keer`, de strook staat 1,2 s op slot en dezelfde vier bedragen
  komen terug. De kaart wordt daarvoor niet opnieuw gebouwd. Geen hulpregel (tot
  2026-09-24: `telVanaf(prijs1, prijs2)` en `'€<kosten> → €<betaald>'`) en geen
  spookmunten.
* goed: `state.tel(somPog == 0, ms)`, `snd.ja()`, het vakje krijgt `'€<n>'`, stap
  → `leg`, wolkje leeg, en na **600 ms** opnieuw tekenen.

### 5.10 Gelukt

1. stap → `af`, wolkje leeg;
2. het gekochte gaat **zichtbaar op het dier**: voor elk gekocht stuk met een
   accessoire `ctx.wereld.accessoire(gastId, acc)` — eenmalig, en het blijft
   staan tot uitchecken;
3. `state.tel(missers == 0, ms)`;
4. **eerst** `ster()` (= `taakKlaar('souvenir', {sterren: 1})`), **dán**
   `behoefteKlaar(gast, 'souvenir')` — `behoefteKlaar` tekent het prikbord
   meteen opnieuw;
5. `snd.tover()` en `snd.hoera()`, bewaren, `Hotel.render()`, opnieuw tekenen;
6. `setMood(gast, 'bouncy')`;
7. het souvenirtje komt **naast** de gast als `getalTag` `🎁` op
   `(P.gast.x − 11, P.gast.z + 11)`, `y = 14`, `prio 12`, titel
   `'<naam> heeft zijn souvenir'`. Een cijfertag en geen wolkje: een wolkje van
   163 px werd door de laag 115 px de tuin in geschoven (de sommenkaart hangt er
   pal boven) en dan staat het praatje niet meer bij zijn eigen dier. Hij hangt
   links op borsthoogte en níet op de kop, want daar staat zijn naamplaatje.
8. na **3400 ms** sluit het spel zichzelf.

### 5.11 Kindtekst, letterlijk

| moment | tekst |
|---|---|
| icoontje / prikbord | label `'Kraam'`, `'<naam> wil een souvenir'` of `'Souvenir'`, icoon `🎁` |
| geen gasten | `'nog geen gasten'` |
| prijskaartje | `'€<prijs>'`, titel `'<lid> <spul> kost <prijs> euro'`; wat de gast wil krijgt de klasse `veel` (roze cijfer) |
| kaart band 3 | `'<naam> wil <lid> <spul> van €<p>'` / `'Leg de munten op de toonbank'` |
| kaart band 4, som | `'<Spul1> €<p1> en <spul2> €<p2>'` / `'Hoeveel euro samen?'` |
| kaart band 4, leggen | `'Samen kost het €<kosten>'` / `'Leg de munten op de toonbank'` |
| kaart band 5, som | `'<naam> gaf €<betaald>, het kost €<kosten>'` / `'Hoeveel krijgt hij terug?'` |
| kaart band 5, leggen | `'<naam> krijgt €<wissel> terug'` / `'Leg het wisselgeld neer'` |
| eind | `'Veel plezier ermee!'` |
| toonbank | `🧾 '€<som>'`, titel `'op de toonbank ligt €<som> van €<doel>'` |
| munt | `'€<v>'`, titel `'munt van <v> euro'` (+ `', in je hand'`) |
| klaar-knop | `✔ 'klaar'`, titel `'klaar met tellen'` |
| wolkjes | `🪙 '€<v>' 'in je hand'`, `☝ 'tik een getal'` |
| misser | de klant sip met `🔄 Nog een keer` (geen hulpregel, geen spookmunten, geen `'terug'`/`'erbij'`-wolkje: eigenaar 2026-09-24) |

Alle uitgestalde spullen houden altijd hun prijskaartje.

### 5.12 Stoppen en herstellen

`stop()`: tikjes af, kader-luisteraar op, alle hotspots weg, geleende knoppen
terug, al het eigen decor weg, en alle beeldstanden (kaartlift, terugschuivende
munt, gastteller) op nul.

`start()` hergebruikt de bewaarde stand alleen als hij bestaat, de gast nog
bestaat, `dag`, `N` en `band` nog kloppen, de stap niet `af` is en hij niet van een
ander dier is dan het gekozen dier (§5.1). `O` (de opzet)
en `P` (de plekken) worden altijd opnieuw berekend — ze zijn puur een functie van
N, band en dag. Zit er een munt in de hand die in deze band niet bestaat, dan
wordt de kleinste munt gepakt.

---

## 6. Open questions for the port

1. **Het bovenste zwembadvenster.** De koptekst van `zwembad.js` zegt dat groep 5
   in de praktijk ophoudt bij `L = 76`, maar `klem(7N + r, 31, 80)` levert vanaf
   N = 11 ook 77, 78, 79 en 80. Is 80 (met `M = 40`, precies `2M`) bedoeld, of
   hoort er een extra klem op 76? De port moet één van beide kiezen; ik heb
   80 als feitelijk gedrag gespecificeerd.
2. **De LCG in `zwembad.keuzeGetallen`.** De positie van de juiste knop hangt af
   van één trek uit een 32-bits LCG met `& 0x7fffffff`. In GDScript moet dat met
   64-bits ints en een expliciete mask worden nagebouwd, anders wijkt de
   knopvolgorde af. Is byte-identiek gedrag hier een eis (zoals bij de bevroren
   `sommen.*`), of mag de port een eigen deterministische bron gebruiken?
3. **`was.prng` en de schudvolgorde.** `recept()` gebruikt één generator voor
   zowel de stapels als de rij op de berg, in die volgorde. Als de port de
   Fisher-Yates-lus anders schrijft (bijvoorbeeld oplopend), verandert de hele
   beurt. Ik ga ervan uit dat de exacte volgorde ertoe doet; dat staat nergens
   expliciet.
4. **`Hits.debug()` in `was.meetIndeling`.** Het hele indelingsalgoritme leunt op
   een debugafslag van de knoppenlaag (anker, `vh`, `w`, `h`, `voxelPx`). In
   Godot bestaat die laag niet in dezelfde vorm. Welke gemeten grootheden moet de
   port aanbieden zodat C1 en C2 nog steeds afdwingbaar zijn?
5. **Rustmodus en de eigen wachttijden.** De motor maakt bewegingen in rustmodus
   direct klaar, maar de `setTimeout`-ketens van de spellen (1800/2200/3400/4600/
   11000 ms) lopen onveranderd door. Moet de port die in rustmodus verkorten? Als
   ja: met welke factor, en welke wachttijden zijn *leestijd* (mag niet korter)
   en welke *animatietijd* (mag weg)?
6. *(Vervallen 2026-09-24: er is geen hulpladder meer, §0.5.)* **De wekker en de
   hulpladder.** GAMES-API §6 schrijft spookvormen pas bij de
   **derde** poging voor; `wekker.js` zet de spookwijzers al bij de **tweede**
   (conform HOTEL.md §5 "spookwijzer na 2 pogingen"). Welke van de twee geldt
   voor de port? Ik heb het codegedrag gespecificeerd.
7. **`wekker`: tijd zonder dagdeel.** De klok is een 12-uursklok
   (`u12`), dus "10 uur" kan ochtend of avond zijn en het doeluur loopt via
   `7 + (dag·3) mod 8` ook door de middag heen ("1 uur", "2 uur"). Er is geen
   am/pm-onderscheid en geen dag/nacht in de wereld. Is dat bewust, of moet de
   port het doeluur op ochtenduren beperken?
8. **`hinkel`: fout antwoord springt tóch.** Een verkeerd aantal sprongen laat
   het dier dat aantal springen en de beurt gaat vanaf de nieuwe steen verder.
   Dat is "nooit straffend", maar het betekent ook dat een kind een beurt kan
   verlengen tot het pad op is (`hop` klemt op de laatste steen en doet dan
   niets behalve `snd.zacht()` + het sippe dier; sinds 2026-09-24 geen telhulp
   meer). Er is geen bovengrens aan het
   aantal pogingen; is dat bedoeld?
9. **`hinkel`: `melding` is nooit `'start'` na de eerste sprong.** `nieuweStand`
   zet `melding: 'start'`, maar `zinnen()` kent alleen `'ver'` en `'kort'` en
   valt anders terug op "Kies je sprong". `'start'` is dus effectief hetzelfde
   als "geen melding"; de port kan dat veld weglaten. **(inferred)** Sinds
   2026-09-24 kent `zinnen()` ook `'ver'` en `'kort'` niet meer (geen hint na een
   foute landing, §3.8); `melding` blijft leeg.
10. **`kraam`: `€10` wisselgeld.** Bij `kosten = 10` wordt er met €20 betaald en
    is het wisselgeld ook €10 — hetzelfde bedrag als de kosten. Dat is
    curriculair prima, maar het maakt de vraag "€20 − €10" wel de makkelijkste
    van de reeks. Bewust?
11. **`kraam`: de tas (🎒 €12) is nooit te koop.** Zij staat alleen als vierde
    prijskaartje op de kraam omdat de accessoirelaag haar niet kent. Moet de port
    een tas-accessoire toevoegen (en de tas dan ook koopbaar maken), of blijft
    zij decor?
12. **`was`: `k = 0` in het noodgeval.** Loopt zelfs `k = 1` over het plafond,
    dan geeft `kiesT` `k = 0, r = 0, T = plafond`. Dat is eerlijk gemeld maar
    breekt de vorm `T = k·N + r`. Er is geen bereikbare (N, band)-combinatie
    gevonden waarin dit gebeurt; moet de port die tak überhaupt overnemen?
13. **Kadermaat-drempels.** Elk spel heeft eigen drempels (`wekker` 370/400 px,
    `was` 330/340/300 px, `kraam` 340/360 px, `hinkel` 320 px, `zwembad` werkt
    met marges in plaats van drempels). Ze zijn allemaal empirisch op de zes
    geteste viewports bepaald. Voor Godot met een vaste basisresolutie + stretch
    zijn ze mogelijk niet één-op-één over te nemen; de port moet beslissen of hij
    de drempels omrekent of het onderliggende doel (kaart raakt dier/diagram
    nooit) opnieuw met metingen afdwingt. Zie ook de X4-spec over stretch en
    tabletdoelen.
14. **De taakrotatie op het prikbord.** `hinkel` (`prio 2` of `5`) en `was`
    (`prio 8`) zitten allebei in de "gewone klusjes"-rotatie, `zwembad` en
    `kraam` (`prio 1`) en `wekker` (`prio 3`) niet. Dat is nu een eigenschap van
    `hotel.js`, niet van de spellen; de port moet die rotatie meenemen, anders
    verdwijnt de was of het hinkelpad structureel van het bord.
