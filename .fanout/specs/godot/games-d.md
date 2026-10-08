# Godot-spec — games D: de Winkelstraat 🛍️, de kleding en de nakijkronde van de dieren

Geschreven 2026-09-24 bij de bouw.  De eigenaar vroeg:

> "Kun je alle animaties en personages nakijken en verbeteren? Ik zou ook graag meer
> aanpassingsmogelijkheden willen hebben in de minigames, zoals kleding of andere
> outfit-opties. Maak een level in een winkel level in het hotel met kraampjes en een
> luxe winkel waarin veel gerekend moet worden, bijvoorbeeld om prijzen te berekenen en
> betalingen af te handelen. Maak verschillende winkels met verschillende items zoals
> hoeden sjalen, schoenen etc. Maak ze niet te groot op het dier wanneer ze gedragen
> worden, het dier moet wel een beetje herkenbaar blijven. Zorg ervoor dat het dier
> teleurgesteld de winkel uit wordt gestuurd en het dier langzaam wegloopt als de spelen
> niet het goede aantal geld aanklikt en de speler daarna weer terug de winkel in moet
> klikken om te voorkomen dat de speler probeert snel een van de knoppen als resultaat
> te gokken"

Net als games-c is dit geen port: de kamer, de kleding en de vijf spellen zijn nieuw.
Later dezelfde dag kwam er een zesde bij, de **souvenirkraam** (`kraam`), die uit de tuin
verhuisde (eigenaar, 2026-09-24: "De kraam in de tuin voelt nu dubbelop die kan verwerkt
worden in de winkels"; §4.7).
De regels zijn die van games-b.md §0, HOTEL.md §9 en PLAN.md §1.  Waar iets daarvan
afwijkt staat het er met reden bij.  De getallen komen uit `games/_winkel/beurt.gd`
(gezaaid met `Sommen.Prng`, dat alleen gelezen wordt: `core/sommen.gd` blijft
byte-gelijk).  *Nagerekend* = in `games/_winkel/test_winkel.gd` over alle winkels,
groepen, N 1–10 en dagen 1–7 doorgerekend.

---

## 1. De nakijkronde van de dieren (art/gasten.gd, autoload/world.gd)

De vijftien houdingen van de HTML en de drie accessoires op de hond blijven
**byte-gelijk** aan hun gouden platen (`tests/test_art.gd`, 23 goed).  Wat erbij kwam
of beter werd:

| wat | was | nu |
|---|---|---|
| knipperen | een wachtend dier knipperde nooit; `tril`/`kijk` was de enige "blik" | `knipper` (ogen dicht, 2 tikken) elke 3,2–5 s, per dier een eigen ritme (`nr`, `fase`) |
| lopen | twee standen, `loopA` ↔ `loopB` | vier tellen: A, **tussenstap** `loopM`, B, `loopM` |
| wachten | stil | een wachtend dier (`wacht`: aan een toonbank, bij een spel) kwispelt elke 6 s een seconde (`kwispelA`/`B`; de hond snel, de rest rustig) |
| een blik | `tril`/`kijk` bleef staan tot de toestand afliep: een dier aan de balie staarde tot 16 s met gespitste oren | een blik duurt `World.BLIK_TIKKEN` = 9 tikken (0,6 s) |
| sip weglopen | bestond niet | `sjokA`/`sjokB`: kop omlaag, oren hangend, staart laag, mondhoeken omlaag; `World.stappen(id, p, {pose: "sjok", tempo: 0.4})`, amper een huppel |
| hoedje op de gans | de klep zat óver de ogen, de gans was een hoed op een snavel | een laag hoger en smaller (`hoedje(v, k, til, krimp)`) |
| sjaaltje op de gans | de hele hals oranje, van lijf tot snavel | een smalle band en een kort slipje (`sjaal_maat`) |
| sjaaltje op poes en konijn | het slipje bedekte de borst | 4 lagen in plaats van 7, 3 breed in plaats van 4 |
| souvenir van de kraam | viel af bij herladen (`World.accessoire` schreef niet in de gast) | `World.accessoire` schrijft `g.accessoires`; `sync` zet het terug |
| platencache | 110 platen | 160 (knipper, kwispel en tussenstap per dier erbij) |

**Getekend, niet logisch.**  Knipperen, kwispelen en de tussenstap zijn *getekende*
beelden: `Dier.beeld` (`World._beeld_van`), terwijl `Dier.pose` — wat elk spel en elke
test leest — `rust`, `loopA` of `loopB` blijft.  Ze komen uit de tikteller en de fase
van het dier, niet uit zijn generator, dus het dwalen van een dag is precies wat het
was.  In rustmodus niets van dit alles.

**Zes soorten (2026-10-07, eigenaar: "maak nog twee extra dieren").**  De **vos** (Vlam, de 4e
gast) en het **varken** (Knor, de 7e) kregen eigen voxelbouwers (`ArtGasten.vos()`,
`varken()`; de vier HTML-bouwers byte-gelijk), een eigen binnenkomst
(art-sound-rules.md §11.8), een eigen loopje (`World._zaai`: de vos een lichte draf, het varken
waggelt, `ZIJ_VARKEN`) en de pictogrammen 🦊 en 🐷 (`Hotel.DIER_ICOON` en de icoontabellen van
voerkar, hinkel en tobbe).  De vos gebruikt de ankers van de hond; het varken heeft eigen
garderobe-ankers (`ankers`, `_kop_vrij`, `_ogen_van`), zodat een hoed boven de ogen blijft.  Elk
kledingstuk is op beide bekeken en getoetst (`test_kleding_blijft_klein_en_de_ogen_vrij`,
`games/_winkel/test_winkel.gd::test_de_nieuwe_waren` bakt elk nieuw stuk op alle
`ArtGasten.SOORTEN`).  Geen HTML-goudplaat: alleen pixelgoudplaten
`tests/gouden_pixel/gast_{vos,varken}_{rust,lig,loopA,loopB,zit,sip,blijA}.png`.  Op het varken
is de HTML-bal blauw in plaats van roze (`BAL_KL_VARKEN`, 2026-10-08: roze op roze viel weg).

## 2. De kleding (ArtGasten.KLEDING)

Eén stuk per **slot**; `World.accessoire` zet het oude stuk van dat slot af.

| slot | stukken (pictogram) | regel voor de maat |
|---|---|---|
| hoofd | hoedje 🎩, pet 🧢, strohoed 👒, strik 🎀, kroon 👑 | nooit lager dan de bovenkant van de ogen (`_kop_vrij`), hooguit 3–4 lagen boven de kop |
| nek | sjaaltje 🧣, streepsjaal 🧣, das 👔, parelketting 📿 | hooguit één voxel van de huid; de das zit onder de kin, waar de camera hem ziet |
| poten | gympjes 👟, laarsjes 👢, sokjes 🧦, gouden slofjes 🥿 | alleen overschilderen (geen voxel erbij), gemeten vanaf de onderkant van elke kolom, dus ook een opgetilde poot; het konijn alleen de onderste 2 lagen |
| ogen | zonnebril 🕶️ | één voxel voor het gezicht, zo groot als de ogen |
| speel | bal ⚽ (de HTML-bal) | tegen de borst |

De sleutel van een plaat blijft `ACC_NAMEN` in vaste volgorde, met de drie van de HTML
vooraan: elke oude sleutel en gouden plaat is ongewijzigd.  *Nagerekend*
(`test_kleding_blijft_klein_en_de_ogen_vrij`): elk stuk op elke soort ≤ 4 lagen hoger
dan het kale dier, ≤ 1/5 van zijn voxels erbij, en geen hoedvoxel op de ogen.

**Elf stukken erbij (2026-10-07, eigenaar: "En nog extra accessoires om te kopen bij de kraapjes
voor decoratie").**  Achteraan in `KLEDING` en `ACC_NAMEN` (26 stukken; elke oude sleutel en
plaat ongewijzigd), elk met een uitstalmodel `waar_<naam>` (`art/decor_winkels.gd::waar()`),
getekend met dezelfde functies en kleuren als op het dier:

| id | naam (strookwoord) | slot | pictogram | op het dier |
|---|---|---|---|---|
| `feestmuts` | feestmuts | hoofd | 🥳 (eerst 🎉) | roze/witte kegel met een gouden pompon (`feestmuts()`) |
| `bloem` | bloem | hoofd | 🌸 | geel hart met vier roze blaadjes (`bloem()`) |
| `tiara` | tiara | hoofd | ✨ | `kroon()` in donkerder zilver (`TIARA_KL`) op een gouden band met een saffier — licht zilver viel weg op konijn en gans |
| `bandana` | bandana | nek | 💙 | `sjaaltje()` in blauw, slip 3 |
| `belletjes` | belletjes | nek | 🔔 | een parelring goud/rood met één gouden belletje onder de kin (de ring alleen viel bij de hond onder het oor weg) |
| `regenlaarsjes` | regenlaarsjes | poten | 💙 (☔ zit niet in de subset) | `schoenen()` drie lagen blauw met een lichte rand |
| `zwemvliezen` | zwemvliezen | poten | 🦆 | `schoenen()` één laag zeegroen `ZWEMVLIES` (oranje viel weg op de eigen poten van de gans) |
| `pantoffels` | pantoffels | poten | 🩰 (eerst 🌙) | `schoenen()` één laag lila |
| `sterrenbril` | sterrenbril | ogen | 👓 (eerst ⭐) | `zonnebril()` met een gouden montuur en lichtblauw glas |
| `pompoen` | pompoen | speel | 🎃 | `bal()` oranje met een groene band |
| `goudbal` | goudbal | speel | 🎾 (eerst ⭐) | `bal()` goud met een witte band; tot 2026-10-08 heette hij "gouden bal", en de strook zei dan "Bal" naast de "⚽ Bal" van de HTML |

Een paar (`veel: true`) is buiten de schoenenkraam één ding met één prijs: alleen
`winkel == "schoenen"` rekent × poten (`Beurt.sommen`;
`test_een_paar_is_een_ding_buiten_de_schoenenkraam`).  Zwemvliezen en pantoffels zijn daarom
souvenirs: de schoenenkraam heeft in groep 4 maar vier prijzen (€2–5) en dus hooguit vier dingen.

**De kast.**  Wat een dier koopt is van hem: `g.kast` (nieuw, optioneel veld; een save
zonder heeft een lege kast) plus wat hij draagt (`State.kast_van`).  `State.in_kast`.

## 3. De Winkelstraat (`winkels`)

| veld | waarde |
|---|---|
| id / naam / icoon | `winkels` / `Winkels` / 🛍️ |
| w × d / wand / vloer / loop | 156 × 112 / 54 / `tegel` / 1.5 (tot 2026-10-01 132 breed: het fotohokje kwam erbij, §5a) |
| kader | `[-234, 322, -120, 278]` |
| mat | een warme loper x 0..156, z 28..42 (`#E9C2B4` / `#E2B5A6`): de straat |
| `kijk` | (96, 34): door de deur zie je de loper en de schoenenkraam |
| `mijd` | x 8..126 z 22..36 (voor de vier kraampjes) · x 34..58 z 50..74 (voor de vitrine) · x 0..24 z 38..84 (de strook tussen de pui en de vitrine) · x 26..76 z 76..104 (de vloer die de vitrine voor de deur verbergt) · x 8..26 z 84..102 (voor de spiegel) · x 110..156 z 22..50 (voor het fotohokje: de vier fotoplekken) · x 130..156 z 50..112 (de nieuwe strook rechts: geen dwaalplek waaruit een wandeling door het hokje of de plant loopt) |
| zone | `kraam` x 112..124, z 28..40: de klant van de souvenirkraam, en waar een gast met de wens 🎁 wacht (`Hotel.plek_van_behoefte`) |
| deur | **de trap** (eigenaar, 2026-09-24: "Ik wil de winkels op een andere etage ... net als Habbo Hotel"; tot 2026-09-25 een lift: "Ik wil graag de lift vervangen voor een trap"): de winkelstraat is een eigen verdieping (sinds 2026-10-01 de **tweede**, `Kamer.etage` 2, tussen de gastenkamers en de speelzaal — eigenaar: "Maak de kamers de eerste verdieping"; world.md §1.2) en heeft geen deur naar de receptie meer; de trap staat in de linkerwand (x, at 24, deurpunt (0, 30), binnen (8, 30)), waar tot die dag de deur naar de receptie zat. In de receptie is waar de winkeldeur zat (achterwand rechts van de balie, z/106) nu de achterdeur naar de tuin. De trap van de receptie hierheen is één stap (`Rooms.pad("receptie", "winkels")` = 2 kamers). Sinds 2026-10-01 twee vluchten naast elkaar op de linkerwand: **trap omhoog** x/16 (11 breed, opstappunt z 26) en **trap omlaag** x/29 (11 breed, opstappunt z 30), elk met een eigen deurbordje (world.md §1.2); de lantaarn schoof naar (4, 14). |
| geluid | `SFEER["winkels"] = "speeldoos"` (hergebruik: een winkel met muziek) |
| plattegrond | vak `[1, 3]`, onder de receptie |

**Decor** (`art/decor_winkels.gd`): vier **kraampjes** met een schuine gestreepte luifel
en een geschulpte rand — `hoedenkraam` (roze) @ (22, 12), `sjaalkraam` (mint) @ (54, 12),
`schoenenkraam` (blauw) @ (86, 12), `souvenirkraam` (geel, met een bordje met een roze
cadeautje op de luifel en een hoedje, sjaaltje en bal op de plank) @ (118, 12) —, de
**luxe pui** `luxepuiz` @ (1, 62) (paars sokkeltje, roomwitte pilaren met gouden
kapitelen, twee etalages met een kroon en een parelketting, een paars uithangbord met een
gouden kroontje en een luifel met gouden franje), de glazen **vitrine** `vitrinez` @
(30, 62), de **spiegel** van de paskamer `spiegelz` @ (1, 94) met een roze gordijntje, een
**lantaarn** @ (4, 18) naast de deur, een stapel **tassen** @ (122, 102), een plant @
(146, 84) (tot 2026-10-01 @ (124, 76)) en een **bloembak** @ (90, 104), en sinds
2026-10-01 aan het eind van de rij het **fotohokje** `fotohokje` @ (144, 12) (§5a).

**De vierde kraam en de lopen (2026-09-24).**  Elke wand was vol, dus de souvenirkraam
kwam in de rij langs de achterwand, op de plek van de deur; de deur ging naar de linkerwand,
waar de lantaarn stond.  Daardoor loopt elke klant van de deur **langs de straat** naar
zijn kraam (daarvoor sneed de loop van de deur naar de hoeden- en de sjaalkraam door de
toonbank van de schoenenkraam).  De vitrine staat 14 verder van de pui (x 30): de loop van
de deur naar de spiegel gaat tussen de pui en de vitrine door, en de klant van de luxe
winkel (52, 62) en het doosje (40, 46) schoven mee.  De wegstuurplekken liggen zo dat de
weg erheen én terug naar de deur vrij is: hoeden (66, 50), sjaals (74, 80), schoenen
(92, 90), luxe (84, 64), souvenirs (108, 86).  Een los ding (eerst voorgesteld: een
souvenirkraam vrij op de vloer) maakte een hoekje waaruit elke wandeling door de kraam liep;
de gebouwde rij heeft dat niet.  *Nagerekend* (`games/kraam/test_kraam.gd`): geen loop van
een spel (deur → toonbank, toonbank → buiten, buiten → deur, deur → spiegel) gaat door een
kraam, de vitrine, de pot of de tassen, en geen wandeling tussen twee dwaalplekken ook
niet; één klant loopt echt van zijn kamer naar de souvenirkraam en komt nergens over een
kraam.  In de
receptie hangt boven de nieuwe deur het **winkelbord** met een roze tas (`winkelbord` @
(112, 1), y 29, `ver`); de pootjesposter schoof naar (88, 1), y 36.

**De balie.**  De winkeldeur zit áchter het uiteinde van de balie, dus de rechte lijn
van de vloer naar die deur sneed de hoek van de toonbank.  `Rooms.om_het_water` gaat nu
ook om de balie heen (het balievak + 2, hoeken 5 verder) — elke andere loop in de
receptie blijft voor de balie en merkt er niets van (`test_niemand_loopt_door_de_balie`).

**De kamerbalk met twaalf chips.**  Elf chips pasten op 1024 × 768 alleen met de krappe
vulling (games-c §1.5).  Een rij probeert nu, vóór hij breekt, eerst een stap kleinere
plaatjes (0,85 ×) en dan een kleiner woord (nooit onder de 12 px-vloer, nooit
afgekapt), zoals de rail al deed (`UiKamerbalk._rij_trappen`).  Een rij die past houdt
haar maten.

**De koopwaar** heeft uitstalmodellen `waar_<naam>` (een hoed op een houten hoofdje,
een opgevouwen sjaal, een paar schoentjes, een kroon op een kussen); de hoeden zijn met
dezelfde functies getekend als op het dier.  In rust staan ze op de toonbanken
(`definitie().rust`), in een beurt zet het spel ze er zelf neer.

## 4. De winkels: `hoeden`, `sjaals`, `schoenen`, `kraam`, `luxe`

Vijf spellen met één gedeeld spel `games/_winkel/winkel.gd` (`WinkelSpel`); elk spel
zegt alleen wélke winkel het is (`winkel()`: kraam, plekken van de waren, waar de klant
staat, waar hij heen sjokt).  `games/_winkel/` heeft geen `spel.tscn`, dus de scan ziet
het niet als spel.

### 4.1 Aanmelding

| spel | naam | ingang | verkoopt (goedkoop → duur) |
|---|---|---|---|
| `hoeden` | Hoedenkraam | 🎩 Hoeden, op `hoedenkraam` | strik, pet, strohoed |
| `sjaals` | Sjaalkraam | 🧣 Sjaals, op `sjaalkraam` | das, sjaaltje, streepsjaal |
| `schoenen` | Schoenenkraam | 👟 Schoenen, op `schoenenkraam` | sokjes, gympjes, laarsjes (per schoentje) |
| `kraam` | Souvenirkraam | 🎁 Souvenirs, op `souvenirkraam` | sjaaltje, hoedje, bal (de souvenirs van de tuinkraam) |
| `luxe` | Luxe winkel | 💎 Luxe, op `luxepuiz` | zonnebril, gouden slofjes, parelketting, kroon (drie per dag op de vitrine) |

**Sinds 2026-10-07** verkoopt elke winkel meer (`Beurt.WAREN`, de nieuwe achteraan): hoeden
strik, pet, strohoed, **feestmuts, bloem** · sjaals das, sjaaltje, streepsjaal, **bandana,
belletjes** · schoenen sokjes, gympjes, laarsjes, **regenlaarsjes** · luxe zonnebril, gouden
slofjes, parelketting, kroon, **tiara, sterrenbril** · souvenirs sjaaltje, hoedje, bal,
**pompoen, goudbal, zwemvliezen, pantoffels**.  Op de toonbank staan er hooguit drie (`toon`).
Wat het dier al heeft valt weg; zijn er dan meer dan vier over, dan draait de lijst elke dag
op `(dag + N) mod aantal` en staan de eerste drie er; precies vier: één valt weg op die plek
(`WinkelSpel._te_koop`).  Zo komt elk ding aan de beurt.  **In rust** (zonder spel) tonen de
kraampjes nog de eerste drie waren: `Games._zet_rust` leest `definitie().rust` één keer bij het
opstarten (open, PLAN.md §4 `E2`).

`unlock`: N ≥ 1.  `kan`: er is een gast met een bed (anders geen knop).  Geen taak op het
prikbord (het bord houdt ≤ 3 kaartjes) — behalve de souvenirkraam, die de wens 🎁 en haar
kaartje uit de tuin meenam (§4.7).  Wat een dier al heeft ligt niet op de toonbank,
tenzij hij alles al heeft.

### 4.2 Het rekenen

Elke prijs is **k·N + r** (k = hoe duur het ding is, r uit het zaad van de dag),
teruggevouwen in het bereik van de groep.  Hele euro's, echte munten en briefjes.
k is de plek in `WAREN` (1, 2, 3, …): de nieuwe dingen staan achteraan (k 4–7), dus de oude
houden hun k en hun prijzen van gisteren.  Twee dingen op één toonbank kosten nooit hetzelfde
(behalve schoenen in groep 3).  De elf nieuwe vallen in hetzelfde bereik als hun winkel: hoeden,
sjaals en souvenirs €2–9 / €6–19 / €12–39 (groep 3 / 4 / 5; zwemvliezen en pantoffels één prijs
voor het paar), regenlaarsjes €1–2 / €2–5 / €3–9 per laarsje, tiara en sterrenbril €5–10 /
€20–60 per 5 / €40–98 even (2026-10-07).

| winkel | groep 3 | groep 4 | groep 5 |
|---|---|---|---|
| kraampjes (hoeden, sjaals, souvenirs) | €2–9 · **betaal precies** | €6–19 · **betaal precies** | €12–39 · **betaalt €50, hoeveel terug?** |
| schoenen (per schoentje; 4 poten, de gans 2) | €1–2 · **4 × €2** (verdubbelen, ≤ 8) · betaal | €2–5 · **4 × €5** (≤ 20) · betaal | €3–9 · **4 × €9** (≤ 36) · terug van €50 |
| luxe (+ cadeaudoosje) | €5–10, doosje €1–3 · **samen** (≤ 13) · betaal | €20–60 per 5, doosje €2–9 · **samen** (≤ 69) · **terug** van €50/€100 | €40–98 even · **halve prijs** · **samen** met het doosje · **terug** |

**Betalen** = vier handjes geld op de strook ("€5 + €2", smal "5+2"), precies één is het
bedrag; de andere zijn een euro minder, een euro meer en twee meer (of drie), elk op zijn
kleinst in munten en briefjes van de groep (groep 3: €10 €5 €2 €1; groep 4: €20 erbij),
hooguit vier stuks; de volgorde komt uit het zaad.  **Terug** = het kleinste briefje dat
méér is dan de rekening (groep 3–4 €20/€50/€100, groep 5 €50/€100), dus er is altijd
wisselgeld.  Getallenvragen hebben vier getallen (`Afleiders.vier`) met de echte
vergissingen: optellen in plaats van keer, één schoentje, een poot te veel; de prijs in
plaats van het wisselgeld; tien ernaast.

### 4.3 De beurt

0. De klant (het dier van de beurt) loopt naar de toonbank (`ctx.wacht_op`); de waren
   staan er met hun prijskaartje.
1. **kies** — "🎩 Wat kiest Boef?" met één knop per ding: pictogram, naam en prijs
   ("🧢 Pet €4").  Geen goed of fout: het kind kiest (aanpassingsmogelijkheid).  Daarna
   staat alleen het gekozen ding nog op de toonbank.
2. **som / half / betaal / terug** — zie §4.2, elk een strook van vier.
3. **af** — "✅ Boef draagt nu de pet!"; het dier draagt het meteen en houdt het (`kast`),
   springt blij rond met sterretjes en "🧢 mooi!", `tover` + `hoera`, één ster
   (`taak_klaar`), `tel(missers == 0)`, na 3,4 s dicht.

### 4.4 Een fout: de winkel uit (eigenaar, 2026-09-24)

Een verkeerd bedrag, een verkeerde som of verkeerd wisselgeld:

1. de kaart en de strook gaan **meteen** weg — er valt niets meer te tikken;
2. `zacht`; het dier is sip (1,2 s), met het wolkje "😞 Dat klopt niet";
3. het dier **sjokt langzaam** de winkel uit (`sjok`, tempo 0,4: ruim twee keer zo lang
   als lopen) naar een plek midden op de straat (`winkel().buiten`), en blijft daar sip;
4. zodra hij buiten staat sluit het spel zich; de knop van de winkel hangt weer op de
   kraam;
5. een tik op die knop: het dier loopt terug naar de toonbank en **dezelfde vraag** komt
   terug, met dezelfde vier keuzes in dezelfde volgorde (de beurt staat in de save,
   `stand.weg`).

Geen hulp, geen hint, geen ster minder, geen munt minder — alleen tijd, en daarmee is
gokken geen goed plan meer.  (De centrale S5-misser met `🔄 Nog een keer` wordt hier
bewust níet gebruikt: de winkels bouwen hun eigen strook.)

### 4.5 Kindtekst, letterlijk

| waar | tekst |
|---|---|
| ingangen | "🎩 Hoeden" · "🧣 Sjaals" · "👟 Schoenen" · "🎁 Souvenirs" · "💎 Luxe" · "🪞 Paskamer" |
| taakkaart (souvenirkraam) | "🎁 %s wil een souvenir" · anders "🎁 Souvenir" |
| kiezen | "Wat kiest %s?" |
| schoenen | "Hoeveel kosten %d %s?" · som "4 × €3 =" |
| luxe | "Hoeveel samen met het doosje?" · som "€35 + €4 =" · "Halve prijs! Hoeveel is dat?" · som "€48 / 2 =" |
| betalen | "💶 Met welk geld betaal je €7?" |
| wisselgeld | "%s betaalt €50. Hoeveel terug?" · som "€50 − €23 =" |
| klaar | "✅ %s draagt nu %s %s!" · wolkje "<pictogram> mooi!" |
| fout | wolkje "😞 Dat klopt niet" |
| niemand | "🛏 nog geen gasten" |

Alles ≤ 8 woorden en ≤ 40 tekens met de langste naam (Stampertje).  Nieuw in de
emoji-subset: 🛍 🧢 👒 🎀 👔 📿 👟 👢 🥿 🕶 💎 🪞 😞.

**2026-10-07.**  Op de kiesstrook staat een ding met het **laatste woord** van zijn naam
("🧢 Pet €4", "🥿 Slofjes", "🎾 Goudbal"); geen twee dingen van één kraam delen dat woord
(`test_elk_strookwoord_is_uniek_per_kraam`, 2026-10-08).  Op de geldstrook staat 💶 alleen nog
in het lange woord ("💶 €5 + €2"), niet als pictogram: zonder dat passen de vier korte woorden
("10+5+2+1") naast elkaar op 360×740, voor elk bedrag dat een kraam kan vragen
(`test_elke_strook_past_op_elk_scherm`); de lange strook op een tablet is ongewijzigd.  Klaar
met een nieuw stuk: "✅ Boef draagt nu de feestmuts!" — elke naam houdt die zin onder de 40
tekens.  Nieuw in de emoji-subset (F1): 🦊 🐷 👓 🎾 🩰 🥳 (en de tekens van games-e.md).

### 4.6 Stoppen en herstellen

`ctx.data().stand` = `{gast, dag, N, band, stap, waar, plek, pog, missers, weg, ster,
keer, wens}`, na elke stap bewaard (`wens` = 1 als het dier kwam voor de wens van de
winkel, §4.7).  Dezelfde dag, N en band en een stap die niet `af` is: verder waar het kind
was, ook na het wegsturen.  Bij het lezen blijven alleen deze velden over
(`WinkelSpel._normaliseer`); een stap die de winkel niet kent, of een rekenstap zonder
gekozen ding, wordt een nieuwe keuze voor hetzelfde dier, zonder missers.

### 4.7 De souvenirkraam (`kraam`, uit de tuin, 2026-09-24)

Eigenaar: "De kraam in de tuin voelt nu dubbelop die kan verwerkt worden in de winkels".
De souvenirkraam van games-b.md §5 (munten op een toonbank in de tuin slepen) is nu de
**vierde kraam** van de winkelstraat en een `WinkelSpel` zoals de andere: kiezen, precies
betalen (groep 3–4) of wisselgeld van €50 (groep 5), en een verkeerd bedrag stuurt het dier
de winkel uit (§4.4).  Eén manier van betalen in één straat.  Wat bleef:

- **het spel-id `kraam`**: de la in de save, de ster van de dag en `ontgrendeld` werken
  door.  Een oude beurt in die la (`stap` `som`/`leg`, `gelegd`, `hand`, `zeg` …) wordt een
  nieuwe keuze voor hetzelfde dier, met zijn `wens`; een afgemaakte beurt blijft af;
- **de souvenirs zelf**: sjaaltje, hoedje en bal (`Beurt.WAREN["kraam"]`, goedkoop → duur; sinds
  2026-10-07 gevolgd door pompoen, goudbal, zwemvliezen en pantoffels, drie per dag),
  dezelfde kledingstukken; wat een dier in de tuin kocht is van hem (`State.kast_van` telt
  wat hij draagt) en ligt dus niet op de toonbank.  De tas (🎒, alleen een prijskaartje in
  de tuin) viel weg: geen kledingstuk;
- **de wens 🎁 en haar kaartje**: `definitie().wens = "souvenir"` en `taak {id: souvenir,
  prio 1, icoon 🎁, "%s wil een souvenir"}` (alleen voor een gast met een bed).  Wie de wens
  heeft koopt eerst (`WinkelSpel._kandidaten`, `winkel().wens`); zijn aankoop vervult de
  wens (`behoefte_klaar`, na `taak_klaar`).  Zonder wens koopt iedereen met een bed.  De
  gast met de wens wacht in de zone `kraam` van de winkelstraat (118, 34); een oud
  kaartje dat nog naar de tuin wees krijgt bij de eerste herbouw van het bord de kamer
  `winkels`, en `Games.start` gaat hoe dan ook naar de winkelstraat.

Weg: de kraam, de toonbank, de zone en de knop in de tuin (daar groeit nu gras,
world.md §1), `games/kraam/modellen.gd`, het slepen van munten en de `kr_`-knoppen.
`Sommen.Kraam` blijft in `core/sommen.gd` staan (bevroren, met zijn vingerafdruk in
`tests/test_sommen_kruis.gd`), maar geen spel leest het nog.

## 5. De paskamer (`paskamer`)

Voor de spiegel kiest het kind wat een dier draagt: één knop per slot waar het dier iets
voor heeft (hooguit vier), elke tik het volgende stuk van dat slot, na het laatste niets
("🎩 Geen").  Het dier draagt het meteen, kijkt blij of kijkt even (`blijA` / `kijk`), en
de save onthoudt het.  Geen som en geen ster: aankleden is geen rekenen.  `kan`: iemand
met een bed heeft iets in zijn kast.  Regel "🪞 Wat trekt %s aan?".

## 5a. Het fotohokje (`foto`, eigenaar 2026-10-01)

> "Ik wil bij de winkel ook graag een fotohokje maken waar je minimaal 2 dieren moet kiezen
> die op de foto gaan en de prijs per dier daaronder en dan een hoe veel geld je moet
> inwerpen"

**Het hokje** (`art/decor_winkels.gd::fotohokje`, 18 × 16, koraalrood) is het vijfde in de rij
langs de achterwand, rechts naast de souvenirkraam @ (144, 12); de winkelstraat werd daarvoor
24 breder (132 → 156) en de plant schoof naar rechtsvoor @ (146, 84).  Links het hokje zelf,
open naar de straat (donker binnenste, bankje, groen gordijn opzij), rechts de automaat met
een schermpje, de geldgleuf en het luikje waar de foto uit komt; op de zijkant een
fotostrook, op het dak een gouden bord met een fototoestel.  Tegen de wand verbergt het geen
klant en geen toonbank — een los hokje midden op de vloer stond voor de klant van de
schoenenkraam.  Knop `📸 Foto` (`spel_foto`), open vanaf twee gasten met een bed.

**De beurt** (`games/foto/spel.gd`, `beurt.gd`):

1. **Kiezen.** "📸 Wie gaan er op de foto?" — op de strook de dieren die mee mogen (hooguit
   vier: eerst wie al gekozen is, dan het dier van de spelbalk, dan de rest vanaf een plek die
   elke dag opschuift) en vanaf het tweede gekozen dier "📸 Klaar".  Elk gekozen dier loopt naar
   zijn plek voor het hokje (vier plekken in twee rijen: (140, 28), (124, 30), (132, 42),
   (116, 42)).  Zijn alle vier gekozen, dan gaat het meteen door.
   **Het hokje in (2026-10-07).**  Bij zijn plek kijkt het dier naar het hokje (`kijk`), en
   `STAP_IN_S` (0,3 s) later stapt het door het gordijn naar binnen: `zwiep`, een paar
   teal sterretjes bij het gordijn (`GORDIJN` (141, 21)), en het is weg uit de straat
   (`World.verstop`); pas dan komt het in beeld op het scherm.  Wie binnen zit blijft
   verstopt staan waar hij stond (zijn plek, kamer en save veranderen niet; hij dwaalt niet
   weg).  `World.verstop` houdt op vanzelf bij `reis`, elke kamerwissel, `weg`, een nieuwe
   dag en elke start van het hotel (`zet_dag`), en een nieuw of gelezen hotel
   (`State.veranderd`); `stop()` van het spel haalt iedereen er zelf ook uit.  De volgorde
   van binnenkomen (`_binnen`) staat niet in de save: na herladen loopt iedereen weer naar
   het hokje en stapt opnieuw in.
2. **Het scherm** (`games/foto/scherm.gd`, `FotoScherm`, `kind: "eigen"`; sinds 2026-10-07 de
   zoeker van de camera van het hokje, eigenaar: "kan het echt in het hokje geanimeerd worden
   van een camera hokje PoV"): binnen de koraalrode rand het hokje van binnen — de
   achterwand in het licht van de lamp, het bankje, links het teal gordijn, de vier witte
   hoeken van de zoeker.  Een dier dat instapt glijdt achter het gordijn vandaan het beeld
   in (`KOM_S` 0,5 s) en neemt de plek het verst links, het dichtst bij het gordijn; wie al
   binnen is schuift op (`SCHUIF_S` 0,35 s).  Binnen staan ze in twee rijen (drie of vier:
   achteraan op het bankje iets kleiner, en de camera doet een stap terug), elke neus naar
   het midden, en ze ademen, knipperen en kwispelen.  De dieren zijn de isometrische
   platen van `Art` (er is geen pose recht van voren).  Onder elke plek **de prijs per dier**
   (een gouden prijskaartje "€3") zolang de camera live is; zolang er nog geen twee binnen
   zijn, lege gestippelde plekken met een "?" en toch de prijs eronder.  Het beeld is 5:3
   (`BEELD`), op een scherm dat lager is dan gevraagd breder voor zijn hoogte tot `BEELD_MIN`,
   zodat het in de band van 115 px boven de dieren past op een telefoon liggend (740×360)
   en de prijskaartjes hun maat houden.  Eén klok beweegt alles: `tik(dt)`, gedraaid door
   `_process`; in rustige beweging en headless is elke verandering meteen af.  Het scherm
   staat in de grootste vrije band boven of onder de dieren bij het hokje (tablet: erboven,
   over de achterwand; telefoon rechtop: eronder), nooit over hen heen; vanaf de geldvraag
   liggen zijn maat, zijn kant en (zolang die in de band past) zijn plek vast tot het spel
   sluit, zodat het bij een fout niet meegroeit met de kamer.
3. **Het geld.** Zodra iedereen in het hokje zit (sinds 2026-10-07; daarvoor: bij het hokje
   staat): "💶 Hoeveel geld gooi je erin?" met de som eronder en vier bedragen op de strook.
4. **Goed** (2026-10-07): de munten vallen erin (`munt`), één ster, dan telt het scherm af —
   3, 2, 1, elk cijfer groot in een koraalrode badge (`tel`), elk met een `tik`, `TEL_S`
   (0,6 s) per cijfer; bij de 1 juichen de dieren.  Dan de sluiter: `klik`, de flits (het
   scherm wit), en het scherm wordt een polaroid die uit het wit verschijnt
   (`ONTWIKKEL_S` 1,0 s), de dieren zoals ze stonden, blij, zonder prijskaartjes — "✨ Klik!
   Wat een mooie foto!".  Daarna `tover`, de dieren komen weer naar buiten (`zwiep`, de
   straat in, `bouncy`), 😍 mooi!, en `AF_S` (3,5 s; was 5,0 s, het aftellen en het
   ontwikkelen kosten samen 2,8 s) later sluit het spel.
5. **Fout:** zoals in elke winkel (§4.4): de kaart gaat meteen weg, de dieren glijden uit het
   beeld door het gordijn (`vertrek`, `WEG_S` 0,6 s) en staan weer in de straat (sinds
   2026-10-07), kijken sip
   ("😞 Dat klopt niet"), sjokken langzaam weg naar (122, 70), (96, 54), (104, 88), (78, 70),
   en het spel sluit.  Een tik op het hokje brengt dezelfde dieren terug en dezelfde vraag met
   dezelfde vier bedragen.  Geen hulp, niets kwijt.

**Het rekenen.**  Eén prijs per dier, voor elk dier dezelfde, zoals in een echt fotohokje;
`k·N + r` in het bereik van de groep (eigen zaad, `core/sommen.gd` blijft bevroren):

| groep | prijs per dier | som | bereik |
|---|---|---|---|
| 3 | €2 … €5 | `€2 + €2 + €2 =` (herhaald optellen: wat onder elk vakje staat) | tot €20 |
| 4 | €2, €3, €4, €5, €10 (de tafels van groep 4) | `3 × €2 =` | tot €40 |
| 5 | €3 … €9 | `4 × €7 =` | tot €36 |

Afleiders: één dier te weinig of te veel, aantal + prijs, de prijs van één dier.

**Kindtekst, letterlijk:** knop `📸 Foto` · "📸 Wie gaan er op de foto?" · knop `📸 Klaar` ·
"💶 Hoeveel geld gooi je erin?" · "✨ Klik! Wat een mooie foto!" · "😞 Dat klopt niet" ·
"😍 mooi!" · "🛏 nog te weinig gasten".

**Geen nieuwe kindtekst en geen nieuw geluid (2026-10-07):** het scherm toont alleen cijfers
(de prijs, het aftellen); de geluiden zijn bestaande (`zwiep`, `tik`, `klik`, `tover`,
`hoera`) — een veertiende wereldgeluid zou de telling van `test_snd_wereld` breken.

**Tests:** `games/foto/test_foto.gd` — aanmelding, prijs en som per groep/N/dag, elke zin past,
een hele beurt per groep via de echte knoppen (Klaar pas bij twee), vier dieren gaan meteen
door, verkeerd geld stuurt ze weg (en dezelfde vraag daarna), herladen, te weinig gasten, het
hokje in de rij (geen loop door een kraam of het hokje), op vier schermen (het scherm ligt
niet over de kaart, de strook of de dieren); sinds 2026-10-07 ook: een dier stapt het hokje in
(weg uit de straat, op het scherm, `binnen=` in de probe-regel), het aftellen, de klik en weer
naar buiten (`tel=`, `foto=` in de probe-regel), `stop()` haalt iedereen uit het hokje, wie
binnen zit blijft binnen, herladen bij de geldvraag (iedereen stapt opnieuw in).
`games/foto/test_foto_scherm.gd` (nieuw, 17 tests, gedreven door `tik(dt)` op een scherm
buiten de boom) — maat en vorm, lager dan gevraagd, de plekken per aantal, de kijkrichting,
de achterste rij eerst, binnenkomen, opschuiven, ademen, knipperen en kwispelen, alleen
tekenen als er iets beweegt, aftellen en juichen, klik/flits/ontwikkelen, geen prijskaartjes
op de foto, `vertrek`, rustige beweging en headless.  `tests/test_world.gd` — de regels van
`World.verstop`/`verstopt`.

## 6. Tests

`games/kraam/test_kraam.gd`: de souvenirkraam — de tuin zonder kraam, de vierde kraam in de
rij, geen loop door een kraam, wens en kaartje, wegsturen en terugkomen, een echte loop van
de klant, en een oude save (een muntbeurt in de la, een tuinkaartje, een hoedje uit de tuin)
via `State.lees()`; sinds 2026-10-07 zeven souvenirs met drie getoond (de eerste drie zijn de
oude, de wensbeurt koopt het eerste getoonde, een oud hoedje uit de tuin staat er niet).
`games/_winkel/test_winkel.gd`: aanmelding, prijzen en sommen per winkel/groep/N/dag,
betalen met echt geld, elke zin past, een hele beurt in elke winkel en groep via de echte
knoppen, **verkeerd geld stuurt het dier de winkel uit** (en dezelfde vraag daarna), een
verkeerde som ook, herladen, de paskamer, de knoppen op vier schermen.
Sinds 2026-10-07: `test_de_nieuwe_waren` (elk nieuw stuk te koop, met uitstalmodel,
gebakken op alle zes soorten), `test_elke_strook_past_op_elk_scherm` (elke winkel × groep 3–5 ×
1–14 gasten × dag 1–7 × ding × 4/2 poten; de breedste drie per scherm echt geplaatst),
`test_een_paar_is_een_ding_buiten_de_schoenenkraam`; 2026-10-08 `test_elk_strookwoord_is_uniek_per_kraam`
en `test_de_bal_van_het_varken_is_blauw`.
`tests/test_world.gd`: één stuk per slot + de save, kleding blijft klein en de ogen vrij,
knipperen/kwispelen/tussenstap, een blik duurt even, sjokken is langzaam en sip.
`tests/test_binnenkomst.gd`: de zes nieuwe getekende houdingen.  `tests/test_rooms.gd`,
`test_plattegrond.gd`, `test_kamerbalk.gd`: de twaalfde kamer.
