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

**De kast.**  Wat een dier koopt is van hem: `g.kast` (nieuw, optioneel veld; een save
zonder heeft een lege kast) plus wat hij draagt (`State.kast_van`).  `State.in_kast`.

## 3. De Winkelstraat (`winkels`)

| veld | waarde |
|---|---|
| id / naam / icoon | `winkels` / `Winkels` / 🛍️ |
| w × d / wand / vloer / loop | 132 × 112 / 54 / `tegel` / 1.5 |
| kader | `[-234, 274, -120, 254]` |
| mat | een warme loper x 0..132, z 28..42 (`#E9C2B4` / `#E2B5A6`): de straat |
| `kijk` | (96, 34): door de deur zie je de loper en de schoenenkraam |
| `mijd` | x 8..126 z 22..36 (voor de vier kraampjes) · x 34..58 z 50..74 (voor de vitrine) · x 0..24 z 38..84 (de strook tussen de pui en de vitrine) · x 26..76 z 76..104 (de vloer die de vitrine voor de deur verbergt) · x 8..26 z 84..102 (voor de spiegel) |
| zone | `kraam` x 112..124, z 28..40: de klant van de souvenirkraam, en waar een gast met de wens 🎁 wacht (`Hotel.plek_van_behoefte`) |
| deur | **de trap** (eigenaar, 2026-09-24: "Ik wil de winkels op een andere etage ... net als Habbo Hotel"; tot 2026-09-25 een lift: "Ik wil graag de lift vervangen voor een trap"): de winkelstraat is de **eerste verdieping** (`Kamer.etage` 1, world.md §1.2) en heeft geen deur naar de receptie meer; de trap staat in de linkerwand (x, at 24, deurpunt (0, 30), binnen (8, 30)), waar tot die dag de deur naar de receptie zat. In de receptie is waar de winkeldeur zat (achterwand rechts van de balie, z/106) nu de achterdeur naar de tuin. De trap van de receptie hierheen is één stap (`Rooms.pad("receptie", "winkels")` = 2 kamers) |
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
(124, 76) en een **bloembak** @ (90, 104).

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

`unlock`: N ≥ 1.  `kan`: er is een gast met een bed (anders geen knop).  Geen taak op het
prikbord (het bord houdt ≤ 3 kaartjes) — behalve de souvenirkraam, die de wens 🎁 en haar
kaartje uit de tuin meenam (§4.7).  Wat een dier al heeft ligt niet op de toonbank,
tenzij hij alles al heeft.

### 4.2 Het rekenen

Elke prijs is **k·N + r** (k = hoe duur het ding is, r uit het zaad van de dag),
teruggevouwen in het bereik van de groep.  Hele euro's, echte munten en briefjes.

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
- **de souvenirs zelf**: sjaaltje, hoedje en bal (`Beurt.WAREN["kraam"]`, goedkoop → duur),
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

## 6. Tests

`games/kraam/test_kraam.gd`: de souvenirkraam — de tuin zonder kraam, de vierde kraam in de
rij, geen loop door een kraam, wens en kaartje, wegsturen en terugkomen, een echte loop van
de klant, en een oude save (een muntbeurt in de la, een tuinkaartje, een hoedje uit de tuin)
via `State.lees()`.
`games/_winkel/test_winkel.gd`: aanmelding, prijzen en sommen per winkel/groep/N/dag,
betalen met echt geld, elke zin past, een hele beurt in elke winkel en groep via de echte
knoppen, **verkeerd geld stuurt het dier de winkel uit** (en dezelfde vraag daarna), een
verkeerde som ook, herladen, de paskamer, de knoppen op vier schermen.
`tests/test_world.gd`: één stuk per slot + de save, kleding blijft klein en de ogen vrij,
knipperen/kwispelen/tussenstap, een blik duurt even, sjokken is langzaam en sip.
`tests/test_binnenkomst.gd`: de zes nieuwe getekende houdingen.  `tests/test_rooms.gd`,
`test_plattegrond.gd`, `test_kamerbalk.gd`: de twaalfde kamer.
