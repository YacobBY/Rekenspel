# Onderzoek 3: inhoud voor een dierenhotel (2026-10-08)

**Vraag.** Wat bieden andere hotel-, dieren- en levenssimulatiespellen aan kamers, activiteiten,
dieren, accessoires en evenementen? En welke ideeën daarvan dragen vanzelf een getal, zodat ze
passen bij Dierenhotel Kwispelsteeg: het getal leeft in de wereld, er hoeft niet gelezen te worden,
een fout wordt nooit gestraft en een antwoord is één tik op een strook van hoogstens vier keuzes?

**Lees eerst [§6 Top 10 ideeën](#6-top-10-ideeën).** Bronnen staan als `[B#]` in de tekst en worden
in §7 verantwoord. Daar staat ook welke bron ik zelf heb geopend en welke ik alleen uit een
zoekresultaat ken (*onbevestigd*).

**Wat er al is** (hier niet opnieuw voorgesteld): 15 kamers, 23 spellen, 6 diersoorten, 26
kledingstukken, 9 decoraties, de dagcyclus, wensen, check-in, avondronde, brieven, seizoensdecor
en de feesttaart. `HOTEL.md` §5 heeft ideeën die nog niet gebouwd zijn (Poetskar, Bagagelift,
Tafel dekken, Tot je schouders, Rijtjes in de moestuin, Feestzaal, Dansrijtje, De bus van tien
uur). Waar een voorstel hierop aansluit, staat dat erbij: het geeft dat idee een kamer en
concurreert er niet mee.

**Afkortingen.** `[S]` is minder dan een dag, `[M]` 1–3 dagen (vaak hergebruik van een
bestaande motor zoals `WinkelSpel`) en `[L]` een nieuwe kamer met modellen, spel, tests en specs.
`[g3]`, `[g4]` en `[g5]` staan voor groep 3, 4 en 5.

**Kaartzinnen.** Elke kaartzin staat tussen «…». Ik heb ze met een script gecontroleerd volgens
de telling van `Ui.keur_regel`: het pictogram telt als woord, en tekens zijn codepoints, dus ✂️
telt als twee. Nieuwe pictogrammen moeten in `fonts/tekens.txt` erbij, en daarna moet
`maak-fonts.sh` opnieuw draaien.

## 0. Grenzen die elk idee hier respecteert

Deze grenzen komen uit SLO en de bestaande vlaggen in `IDEAS.md`/`MINIGAMES-RESEARCH.md` §8:

| onderwerp | wat mag | bron |
|---|---|---|
| Lengte | groep 3–4: meterlat, liniaal, cm en m. Groep 3 in het spel alleen vergelijken en natuurlijke maten. dm en km vanaf groep 5–6 | [B31] |
| Gewicht | kg vanaf groep 3–4 (pak suiker als referentie), gram vanaf groep 5–6. `weeg` (kas) doet al kg | [B31] |
| Inhoud | **de liter in groep 3–4, met een literpak melk als referentie** (past precies bij een koe), ml/dl vanaf groep 5–6 | [B31] |
| Tijd/kalender | groep 3–4: hele en halve uren, kalender, **"nachten tellen tot een feestdag"**. Groep 5–6: alle kloktijden en tijdsduur | [B31] |
| Temperatuur | **pas in groep 5–6, en dan met negatieve getallen.** Dus geen thermometer bij de dierenarts en geen pinguïn met min-graden | [B31] |
| Breuken | alleen ½ en ¼ (vlag 6 in `MINIGAMES-RESEARCH.md`) | — |
| Kansmechanieken | geen lootboxen, gelukswielen of verrassingseieren. De Ksa vond in 2018 dat 4 van de 10 onderzochte lootboxen illegaal waren (overdraagbare prijzen). Bijna-winst-effecten, flitsende effecten en onbeperkt openen verhogen het verslavingsrisico, en de Ksa kon niet vaststellen dat aanbieders minderjarigen buitensluiten | [B44] |
| Tijdsdruk | geen timers of bijna-winst; `Overcooked` werkt juist door tempo en is voor 6-jarigen te snel | [B23] |

## 1. Wat andere spellen hebben

| spel | wat het biedt (kern) | wat een getal draagt: idee voor ons | bron |
|---|---|---|---|
| **Animal Crossing: NH**, museum | 80 vissen, 80 insecten, 40 zeedieren, 73 fossielen, 43 kunstwerken. Het museum komt pas na 5 en daarna 15 schenkingen | **Gastenboek of fotomuur** met vakjes per soort. "Na 5 gasten komt X" is een drempel die je kunt zien | [B7] |
| **AC: NH**, Nook Miles | stempelkaarten met trappen 10/100/500/2000/5000 (vissen) en 5/20/50 (moestuinplantjes) | trappen van 5 en 10 als **zichtbare kralenketting** in de receptie; geen los stempelspel, dat is verworpen (MR §9) | [B2] |
| **AC: NH**, DIY | een recept vraagt *getelde* materialen: 6 bloesemblaadjes + 2 hardhout + 3 onkruid + 3 klei | **Seizoensknutsels**: "3 eikels en 2 kastanjes" maken een herfstkrans. Optellen met voorwerpen | [B5] |
| **AC: NH**, evenementen | Vistoernooi met punten (4× per jaar), Paashaas-dag (8 dagen eieren zoeken), Toy Day (pakjes rondbrengen op 24/12), Countdown-klok op 31/12 | eieren zoeken als arrays (§5); **pakjes rondbrengen** past bij de postkamer; aftellen naar 12 uur past bij `wekker` | [B3] |
| **AC: NH**, Able Sisters | elke dag 6 stukken (één per categorie) en 2 complete outfits, plus een paskamer. 10 kledingcategorieën | de kraampjes doen dit al (`E2`). Nieuw: **"setje van de week"** op een paspop, met de prijs van het hele setje = optellen | [B4] [B49] |
| **AC: Happy Home Paradise** | een voorziening opent pas met een minimum aan meubels. School: 1 bureau, 2 tafels en 4 stoelen. Ziekenhuis: 1 balie, 4 stoelen en 3 bedden | **Kamer-recept**: een kamer gaat open als er precies zoveel meubels staan. Dat telt rechtstreeks in de lus *rekenen → meubels* | [B6] |
| **Neko Atsume** | snoepjes en speeltjes lokken katten (86 katten, 26 zeldzaam, alleen voor speciale spullen). Ze laten zilveren en gouden vis achter, en soms een aandenken | **VIP-gast die alleen komt bij een getelde wens** ("3 kussens en een aquarium"). Het aandenken is een zeldzaamheid zonder kansspel | [B1] |
| **Cats & Soup** | elke kookpost krijgt een kat als werker, en elk niveau maakt soep +1 duurder. Kleding, thema's, op reis sturen | "elk niveau +1" is een **getallenrij op een prijsbord**. Een gast **op reis sturen** geeft ansichtkaarten aan de postkamer (§5) | [B8] [B9] |
| **Hotel Hideaway** | avatar en kamers, seizoenskamers, ranglijsten. Klacht: steeds herhalingen bij het rad van fortuin | seizoenskamers wel, **rad en ranglijst niet** | [B10] |
| **Habbo** | zeldzame meubels en seizoenscampagnes (Habboween 2001, Kerst, Pasen). Meubels uit een campagne komen pas na 4–12 maanden terug | **seizoensvenster** als zeldzaamheid: het komt volgend jaar terug, dus er is geen spijt | [B11] |
| **Cozy Grove** | elke dag nieuwe taken van geestberen. Hun hulp maakt het eiland weer kleurig, en elke stap van het kampvuur vraagt meer houtblokken | **kleur die terugkomt** als beloning: met elke volle kamer kleurt de gevel verder. Een stijgende reeks blokken | [B12] |
| **Tsuki Adventure** | worteltjes als munt, een treinstation, vissen, een vlieger, een gacha met speeltjes | **station** als kamer (§2 K7); de **gacha niet** | [B13] |
| **Stardew Valley** | in de kippenhok: kip (elke dag een ei), eend (om de dag), konijn (om de 4 dagen). In de stal: koe (elke dag melk), schaap (wol om de 3 dagen) | **ritme per dier**: "het schaap geeft wol om de 3 dagen" is een kalender met sprongen (groep 4–5) | [B14] |
| **Hay Day** | bestelbord bij de vrachtwagen, de boot vraagt **3 kratten per product**, een kraampje met dozen van hoogstens 10 | **bestelbord met kratten**: 3 kratten van 4 eieren. Arrays die echt geladen worden | [B15] [B16] |
| **Pokémon Café ReMix** | klanten met een gedachtewolkje vol gerechten; om de 2 niveaus een nieuwe outfit | het wolkje toont **hoeveel** (3 ijsbolletjes als plaatjes), niet wat er geschreven staat | [B17] |
| **Toca Life World** | dierenhotel met aquarium, vier dierenhuisjes en een dokterspost; een dierenarts met wachtkamer. Geen regels | **dierenarts** en **aquarium** als plekken; het vrije spel bewijst dat kinderen dit herkennen | [B18] |
| **My Talking Tom Friends** | behoeften als pictogram-wolkjes (vork, wc, plus, douche, maan); 6 vrienden in het zwembad, 3 aan tafel | **capaciteit als getal**: de tafel heeft 3 plekken, dus hoeveel moeten wachten? | [B19] |
| **Pet World: My Animal Hotel** (Tivola) | katten, honden, hamsters, chinchilla's en ratten; verblijven uitbreiden, voeren, wassen, aaien | bevestigt het genre: **verzorging en trimmen** horen erbij (§2 K1). Klacht in recensies: voer kost te veel | [B20] |
| **Bluey: The Videogame** | 4 minispellen (Keepy Uppy: 3 tikken in het verhaal, 25 voor de prestatie); stickers en hoedjes als verzamelwerk | Keepy Uppy laat **tellen tijdens het spelen** zien. Stickerboek = zichtbare verzameling | [B21] |
| **Pip and Posy: Fun and Games** | memory met 8, 16 of 24 kaarten; puzzels van 6, 9 of 12 stukjes | moeilijkheid als **getelde maat** (6 → 9 → 12) in plaats van tijd | [B22] |
| **Crossy Road** | voxeldieren schuin van boven gezien, meer dan 50 figuren, puur cosmetisch | **verzamelen als motor**, zonder kansspel (zie Ksa) | [B24] [B25] |
| **Hello Kitty Island Adventure** | 3 cadeaus per vriend per dag, vriendschapsniveaus, kookposten per eiland | **"3 per dag"** is een zichtbare kraal-limiet. De voorkeuren passen op het bestaande wenssysteem | [B26] |

### 1.1 De Nederlandse kinderwereld: soorten en rollen die thuis voelen

Deze figuren zijn beschermd. Gebruik ze als inspiratie voor **diersoort en rol**, nooit voor
naam of uiterlijk.

| bron | wat het oplevert | getal |
|---|---|---|
| **De Fabeltjeskrant** (1968–1992; sinds aug 2026 hersteld op YouTube) | Meneer de Uil (vertelt voor het slapen), Stoffel de Schildpad (langzaam), Gerrit de Postduif (postbode), Myra Hamster, Greta Bontekoe [B39] | uil → avond en klok; schildpad → tijdsduur; postduif → postkamer |
| **nijntje** | betje big (varken), snuffie (hond), boris en barbara beer, nina (konijn). Kleuren: gedempt rood, geel, blauw, groen en bruin met dikke contouren [B38] | het **Bruna-palet** is een goede toets voor nieuwe dierkleuren |
| **Woezel & Pip** | twee hondjes, Buurpoes, Molletje (tunnels), Vlindertje [B40] | een mol hoort in de kelder (wasserij) |
| **Dikkie Dik** | rode kater, Poes Muis, Beer, Eekhoorn [B41] | eekhoorn (§3) |
| **Jip en Janneke** | Takkie (teckel), Siepie (poes) [B42] | — |
| **Efteling** | Holle Bolle Gijs roept "Papier hier!" en zegt "Dank u wel!"; er zijn er elf in het park [B43] | een **altijd-hongerige afvalbak** in de tuin: tellen wat erin gaat |
| **Lievelingszoogdier NL** (2009, 2267 stemmen) | 1 eekhoorn (379), 2 egel (232), 3 vos (179), 4 ree, 5 zeehond [B34] | de vos is al gast. Eekhoorn en egel zijn de volgende |
| **Huisdieren in NL** | huishoudens: kat 31,5 %, hond 27,4 %, vis 7,9 %, konijn 4,7 %, vogels 4,2 %, knaagdieren 2,7 %, kippen 2,4 % [B35] | aquarium en vissenkom zijn bekend terrein; kip en hamster ook |
| **Kinderboerderijen** | 550–600 in NL, 25–30 miljoen bezoeken per jaar; geiten, schapen, koeien, ganzen, konijnen, varkens, kippen, eenden [B37] | kamer K4 |

## 2. Nieuwe kamers

Acht voorstellen. Bewust **niet** opgenomen: de **lift** (de eigenaar verving hem op 2026-09-25
door een trap), een **strand met getijden** (te abstract voor groep 3–5), een **schatkamer**
(overlapt met het geld in de winkels) en een **klimrek** (de speelzaal heeft er al een). De
receptie heeft op een telefoon geen vijfde opening; daarom staat de postkamer achter de kas.
Nieuwe kamers op etage 0 komen dus achter tuin, zwembad of kas, of als zone bij de voordeur
(`Rooms.ingang`).

### K1. Trimsalon `[M–L]` `[g3–g5]`
- **Plek en waarom.** Etage 2, deur in de winkelstraat (of etage −1 naast de wasserij). Elk
  dierenhotelspel heeft trimmen en verzorgen: Tivola laat wassen en aaien [B20], Toca heeft een
  dokterspost in het hotel [B18]. Bij ons ontbreekt het.
- **Getal in de wereld.** Een meetlat naast de vacht (cm, om de 10 een kleur, de 5 gemarkeerd),
  strikjes in een strip van 10 en de wandklok van de salon.
- **g3:** elk oor evenveel strikjes, of aanvullen tot 10. «🎀 Hoeveel strikjes moeten er nog bij?»
- **g4:** de vacht is 14 cm en moet 9 worden (aftrekken tot 20). «✂️ Hoeveel cm knippen we eraf?»
- **g5:** een beurt duurt 15 minuten en er wachten 3 gasten (tijdsduur). «🕒 Hoe laat is Snuf klaar?»
- **Dier en let op.** Het dier zit stil, schudt zich na een *goed* antwoord en loopt met een
  nieuwe look weg. Bij een misser gebeurt niets (MR §7.2). Symmetrie zit al in `spiegel`.

### K2. Spreekuur bij de dierenarts `[M]` `[g3–g5]`
- **Plek en waarom.** Etage 1, deur in de gang. In Happy Home Paradise vraagt het ziekenhuis
  getelde meubels: 1 balie, 4 stoelen en 3 bedden [B6]. Toca heeft een dierenarts met
  wachtkamer [B18].
- **Getal in de wereld.** Een wachtkamer met 10 stoelen, een groeimeter in blokken van 10 cm en
  een potje vitaminesnoepjes naast de kalender.
- **g3:** vrije stoelen tellen en aanvullen tot 10. «🪑 Hoeveel stoelen zijn nog vrij?»
- **g4:** de lengte aflezen tussen 40 en 50, en het verschil tussen twee gasten. «📏 Hoe lang is Bello?»
- **g5:** 2 snoepjes per dag × de **nachten van zijn verblijf** (uit de check-in, dus k·N + r).
  «🍬 Hoeveel snoepjes voor alle nachten?»
- **Dier en let op.** Een check-up, geen ziekte: op de meter, een sticker, zwaaien. **Geen
  thermometer**: temperatuur komt pas in groep 5–6 en brengt negatieve getallen mee [B31].
  Bouwt op "Tot je schouders" (HOTEL.md #9).

### K3. Theater "Spot aan!" `[M–L]` `[g3–g5]`
- **Plek en waarom.** Etage 3, naast speelzaal en muziekkamer. De Kinderboekenweek loopt van
  30 september tot 11 oktober 2026 met het thema **"Spot aan!"**: toneel, dans en zang [B29]
  [B30]. Het rijen-rooster uit HOTEL.md §6 (moestuin-rijtjes) is niet gebouwd. `koekjes` en
  `sterren` tellen al rijen; het theater voegt het omgekeerde toe: hoeveel rijen?
- **Getal in de wereld.** Rijen stoelen, elke rij een eigen kleur (geen letters nodig), kaartjes
  met een stoelplaatje. Het gordijn gaat pas open als iedereen zit.
- **g3:** 2 rijen van 5 (via de 5). «🎭 Hoeveel stoelen staan er klaar?»
- **g4:** 3 rijen van 5 of 4 rijen van 10 (tafels 1–5 en 10).
- **g5:** 6 rijen van 7, en omgekeerd: 24 gasten in rijen van 6. «🎟️ Hoeveel rijen zijn er nodig?»
- **Dier en let op.** De gasten zijn het publiek; de band (`band`) speelt op het podium. De
  Feestzaal ("Wat wil de jubilaris?", HOTEL #12) en het Dansrijtje (#15) kunnen hier ook.

### K4. Kinderboerderij `[L]` `[g3–g5]`
- **Plek en waarom.** Etage 0, buiten achter de tuin. NL telt 550–600 kinderboerderijen met
  25–30 miljoen bezoeken per jaar [B37]. Stardew en Hay Day laten zien hoe dierproducten een
  ritme en bestellingen geven [B14] [B15].
- **Getal in de wereld.** Eieren in het stro, eierdozen van 10 en van 6, een koe met emmer en
  literpakken, een bestelbord met kratten.
- **g3:** de eierdoos van 10. In groep 3 is een volle doos van 10 één staaf [B48].
  «🥚 Hoeveel eieren passen er nog bij?»
- **g4:** de liter met het literpak als referentie [B31]; de koe geeft 8 liter, het kalf drinkt
  er 3. «🥛 Hoeveel pakken melk worden vol?»
- **g5:** 20 eieren in dozen van 6 geeft 3 vol en 2 over (het restje is voor de kok, zoals in
  `koekjes`). «🥚 Hoeveel doosjes worden er vol?»
- **Dier en let op.** Nieuwe wens 🐄 "naar de boerderij"; koe en kip (§3) zijn bewoners. Een doos
  van 6 is in groep 4 alleen herhaald optellen; de tafel van 6 is groep 5.

### K5. IJssalon `[M]` `[g3–g5]`
- **Plek en waarom.** Etage 0, terras naast het zwembad (de "ranja-kiosk" uit MR §6). Café-spellen
  draaien om een **bestelling in een wolkje** [B17].
- **Getal in de wereld.** Elke gast aan tafel heeft een wolkje met n bolletjes als plaatjes. De
  bak ijs wordt leger. De betaling gebruikt de muntenlade van `WinkelSpel`.
- **g3:** 2 + 3 bolletjes tot 10, € 1 per bolletje. «🍦 Hoeveel bolletjes zijn het samen?»
- **g4:** 5 gasten × 2 bolletjes, of 4 hoorntjes × € 3.
- **g5:** een ijstaart in ½ en ¼, en 3 × € 4 met wisselgeld van € 20. «🍦 Wat kosten de ijsjes samen?»
- **Dier en let op.** Bij een verkeerd bedrag geldt de winkelregel (het dier sjokt weg, dezelfde
  vraag blijft). Laag in kosten: geldregels en tests van `_winkel` gaan mee.

### K6. Fietsenstalling `[M]` `[g3–g5]`
- **Plek en waarom.** Een zone bij de voordeur of in de tuin, dus geen nieuwe deur. In elk
  voertuig zit een tafel: fiets 2, driewieler 3, bakfiets 3, tandem 2 dieren. Groep 4 kent
  precies de tafels 1–5 en 10, en niets is zo Nederlands als een fietsenrek.
- **Getal in de wereld.** Het rek met de voertuigen; gasten met een fietshelm (§4) komen fietsend aan.
- **g3:** 4 fietsen = 2 + 2 + 2 + 2. «🚲 Hoeveel wielen staan er in het rek?»
- **g4:** 6 fietsen en 2 driewielers = 12 + 6.
- **g5:** omgekeerd: 28 wielen, allemaal fietsen. «🚲 Hoeveel fietsen staan er?»
- **Dier.** De gans fietst niet maar waggelt aan; dat is meteen een tel-afleider.

### K7. Bushalte en station `[L]` `[g3–g5]`
- **Plek en waarom.** De aankomstscène vóór de voordeur (het "voorplein" uit MR §6). Tsuki heeft
  een treinstation als grote plek [B13]; HOTEL #16 "De bus van tien uur" heeft nog geen plek. De
  reizende gast (§5) komt hier aan.
- **Getal in de wereld.** Een stationsklok, een vertrekbord met klokgezichtjes (geen cijfers), een
  bus met banken voor 2 en uitstappende gasten.
- **g3:** hele uren; tellen wie uitstapt. «🚌 Hoeveel dieren stappen er uit?»
- **g4:** half en kwartier, banken van 2. «🚌 Hoeveel banken worden vol?»
- **g5:** tijdsduur: 25 minuten rijden vanaf 10:15 [B31]. «🚌 Hoe laat komt de bus aan?»
- **Let op.** `wekker` doet al het klokzetten. Het station voegt **tijdsduur** en **aankomst met
  N** toe.

### K8. Bieb (boekenkamer zonder lezen) `[M]` `[g3–g5]`
- **Plek en waarom.** Etage 1 of 3. In 2000 koppelde de CPNB Dierendag aan de Kinderboekenweek,
  met dieren-activiteiten in bibliotheken [B32]. Woezel & Pip heeft de Wijze Varen met een
  boekenboom [B40].
- **Getal in de wereld.** Boeken als gekleurde blokjes van verschillende dikte (dun 1 vak, dik 3),
  planken van 10 vakjes, een voorleeshoek waar gasten in slaap vallen.
- **g3:** een plank van 10 met 7 vol. «📚 Hoeveel vakjes zijn nog leeg?»
- **g4:** 4 planken van 5 boeken, of plankjes in tientallen.
- **g5:** 6 planken × 7 boeken. «📚 Hoeveel boeken staan er in de kast?»
- **Let op.** Geen ordenen op nummer: dat doen `sleutels` en `post` al. De Bieb gaat over
  **hoeveelheid en meten**.

## 3. Nieuwe dieren

Er zijn nu zes soorten, met deze hoofdkleuren: hond `#EEC194` (zandbruin), poes `#C9CCDC`
(grijsblauw), konijn `#F5E7EC` (roze-wit), gans `#FDF8EA` (wit), vos `#EC8752` (oranje) en varken
`#F6B8C4` (roze).

Twee regels gelden voor alle kandidaten:
- **Eén overdreven kenmerk per dier.** Vector-voxelkunst zoals Crossy Road leest goed op elke
  schaal [B25], en de makers draaiden de camera schuin omdat voxels er zo beter uitzien [B24].
  Dat sluit aan bij onze isometrie. Toets de silhouetten als groep tegen de zes die er al zijn
  (mijn advies).
- **Eén bed per dier, ook voor de koe.** De eigenaar vroeg eerder: "Waarom zijn er 5 bedden nodig
  voor 1 dier?" Grootte verandert dus nooit het aantal bedden.

| # | dier (voorstel naam) | waarom NL | silhouet op voxelmaat | palet en verschil met de zes | mechaniek die het meebrengt | groep |
|---|---|---|---|---|---|---|
| 1 | **Eekhoorn** (Nootje) | lievelingszoogdier van NL (379 van 2267 stemmen) [B34]; vriendje van Dikkie Dik [B41] | grote S-staart rechtop, oorpluimpjes | **botst met de oranje vos**. Kies donker kastanje `#8A4B2E` met een crème buik `#F3E3C8` en een donkerdere staart | **verstopt nootjes per 10** in holletjes en "spaart": tientallen en eenheden zie je. Herfst-wens 🌰 | g3–g5 |
| 2 | **Koe** (Bontje) | Lakenvelder: zwart met **witte band om het lijf**, al eeuwen een NL-ras en geliefd op kinderboerderijen [B45]; Greta Bontekoe [B39] | groot blok met een witte gordel. Herkenbaar op 2 pixels breed | zwart `#2B2B2B`, wit `#F7F7F2` en een roze snuit. Geen enkele gast is nu zwart | **melk in liters** (literpak, g3–4 [B31]); de koebel als geluid | g3–g4 |
| 3 | **Kip met kuikens** (Tok) | Barnevelder: bruin en dubbelgezoomd, uit Barneveld, legt donkerbruine eieren [B45]; 2,4 % van de huishoudens heeft kippen [B35] | kam, staartwaaier; kuikens als gele bolletjes | **bruin `#9B5A2E` met een zwarte rand, zodat hij niet op de witte gans lijkt** | **eieren in dozen van 10 en 6**. Een gezin checkt in als 1 + 4 (optellen); de kuikens slapen in moeders mand, dus geen extra bedden | g3–g5 |
| 4 | **Uil** (Oehoe) | Meneer de Uil, verteller voor het slapengaan [B39] | rond lijf, oorpluimen, **ogen van 2×2 geel** | bruin `#7A5A40`, crème `#EADBC0`, geel `#F2C230` | **nachtdier**: komt in de avondronde wakker en hoort op het dakterras. "De uil wordt wakker om 8 uur" (hele uren, g3) | g3–g4 |
| 5 | **Schildpad** (Sloffie) | Stoffel de Schildpad: langzaam en altijd wat kwaaltjes [B39] | laag en plat, een **koepel met zeshoeken** | de enige **groene** gast: `#5E8C4A` schild, `#B9C77A` huid | **langzaam**: 1 tegel per tik. Op het hinkelpad worden het kleine stapjes; tijdsduur ("hoe lang over de gang?") | g4–g5 |
| 6 | **Egel** (Prik) | nummer 2 van NL [B34] | halve koepel van stekels, spits snuitje | grijsbruin `#7C6A58`, crème gezichtje | **winterslaap = kalender**: slaapt van november tot maart, dus hoeveel maanden? (kalender g4–5 [B31]). Hij vertrekt zichtbaar en komt terug | g4–g5 |
| 7 | **Hamster** (Wangetje) | Myra Hamster [B39]; knaagdieren in 2,7 % van de huishoudens [B35] | klein en rond; **loopt alleen samen met zijn molen** | goud `#E8B04A` en wit | **rondjes in de molen** zijn sprongen (2, 5, 10 per rondje). Zijn wangzakken bewaren zaadjes per 10 | g3–g4 |
| 8 | **Pinguïn** (reserve) | populair, maar niet typisch NL | zwart-wit staand | **botst met de koe** | "kou = negatieve getallen" mag **niet** voor groep 3–5 [B31]. Alleen als wintergast op het ijs (getallenlijn op ijsschotsen) | g3–g4 |

**Reserves:** een **beer** (boris beer bij nijntje [B38], Beer bij Dikkie Dik [B41]; donkerbruin
om de hond niet te raken) en een **mol** (Molletje bij Woezel & Pip [B40]; woont in de kelder
naast de wasserij). Van de huidige gasten hebben Vlam en Knor een geleende stem
(`Snd.DIER_STEM`). Leen ook voor deze dieren eerst een stem, dan blijven de kosten laag
(koe → gans is nu het dichtstbij).

## 4. Accessoires en decoratie

**Wat verkoopt in aankleedspellen.**
- AC: NH heeft 10 kledingcategorieën. Able Sisters verkoopt elke dag één stuk per categorie plus
  2 complete outfits, met een paskamer [B4] [B49].
- Pokémon Café geeft om de 2 niveaus een nieuwe outfit in een andere kleur [B17].
- Habbo en Pocket Camp leunen op **seizoenscampagnes die terugkomen**. Bij Habbo komt
  campagnemeubilair pas na 4–12 maanden terug (onbevestigd). Pocket Camp Complete geeft "Complete
  Tickets" voor gemiste seizoensspullen [B11] [B5].
- De klacht bij Hotel Hideaway gaat over herhalingen bij het **rad** [B10].

**Zeldzaamheid zonder kansspel** (Ksa [B44]):
- (a) een **seizoensvenster** met een vaste datum dat volgend jaar terugkomt;
- (b) een **set die je met getelde verzameling afmaakt** ("5 eikels = eikelkroon", zoals de DIY-recepten
  [B5]);
- (c) een **aandenken van een VIP-gast** (de mementos van Neko Atsume [B1]);
- (d) **dagwaren die vastliggen en te zien zijn** op een gesloten kraam (`E2`, al gebouwd).
  Nooit willekeurig openen.

**Prijsbanden** volgen `games/_winkel/beurt.gd::_bereik`:
- *normaal*: g3 € 2–9 · g4 € 6–19 · g5 € 12–39;
- *luxe*: g3 € 5–10 · g4 € 20–60 · g5 € 40–98;
- *schoen* (per poot): g3 € 1–2 · g4 € 2–5 · g5 € 3–9.

De prijs blijft k·N + r. Ik noem hier dus de **band** en geen vaste prijs.

### 4.1 Twintig nieuwe stukken

| naam | slot | waar te koop | prijsband | getal-koppeling |
|---|---|---|---|---|
| klompjes | poten | schoenenkraam | schoen | **4 poten × prijs** (de gans 2): de bestaande schoenformule; heel NL |
| schaatsjes | poten | schoenenkraam (december–februari) | schoen | idem; wintervijver (§5) |
| wantjes | poten | sjaalkraam (winter) | schoen | per poot, dus de gans heeft er 2 |
| koksmuts | hoofd | hoedenkraam | normaal | wie hem draagt is "de kok" en krijgt het restje in `koekjes` en K4 |
| fietshelm | hoofd | hoedenkraam | normaal | fietsers tellen in K6 |
| oranje kroontje | hoofd | hoedenkraam (rond Koningsdag) | normaal | vrijmarkt (§5) |
| kerstmuts | hoofd | hoedenkraam (december) | normaal | — (seizoen) |
| koptelefoon | hoofd | luxe winkel | luxe | muziekkamer; de band telt maten |
| vlinderdas | nek | sjaalkraam | normaal | theater K3 |
| medaille | nek | **niet te koop**: na 5 keer hinkelen | — | een kralenteller van 5. Een *verrijking*, geen los stempelspel (MR §9) |
| oranje sjaal | nek | sjaalkraam (Koningsdag) | normaal | — |
| duikbril | ogen | souvenirkraam | normaal | zwembad |
| hartjesbril | ogen | luxe winkel | luxe | — |
| lampion | speel | souvenirkraam (11 november) | normaal | **elk brandend lampionnetje telt** in de optocht (§5) |
| pepernotenzakje | speel | souvenirkraam (eind november–5 december) | normaal | een `getal_tag` op het zakje: zoveel pepernoten |
| paasmandje | speel | souvenirkraam (Pasen) | normaal | eieren die gevonden zijn, als tag |
| ballon | speel | souvenirkraam | normaal | in de Feestzaal is **elke ballon een blokje in een staaf** (HOTEL #12) |
| vlieger | speel | souvenirkraam (herfst) | normaal | — (wind, §5) |
| knuffelbeer | speel | souvenirkraam | normaal | — (troost na vertrek) |
| rugzakje | **rug (nieuw slot)** | luxe winkel | luxe | ⚠️ een nieuw slot raakt `World.accessoire`, de paskamer en de save, dus `[L]` |

### 4.2 Tien decoraties die een getal tonen

Decoratie kost nu € 1–6 en hangt op `Rooms.vrije_wandplekken` of staat op de vloer.

| decoratie | plek | prijs | getal in de wereld |
|---|---|---|---|
| **wandklok** | wand | € 3 | toont het uur van het hotel. `wekker`, K1 en K7 lezen hem; de klok hangt in de kamer zelf |
| **scheurkalender** | wand | € 2 | **nachten tot het volgende feest**, de letterlijke SLO-activiteit voor groep 3–4 [B31] |
| **groeimeter** | wand | € 4 | streepjes van gasten die er waren, in blokken van 10 cm (K2) |
| **telraam** | vloer | € 3 | kralen = gasten in deze kamer, rood en wit in vijven. Bouwt op de "gastenteller" uit MR §6 |
| **fotomuur** | wand | € 3 | één foto per vertrokken gast, past bij de brieven en het fotohokje |
| **spaarpot** | vloer | € 2 | glas met munten in stapels van 10 (positiewaarde) |
| **scorebord** | wand | € 4 | het aantal optredens van de band, geturfd (turven g4) |
| **kapstok** | wand | € 2 | **één haakje per bed**: je ziet de capaciteit, de jasjes zijn de gasten |
| **lampionnenslinger** | wand (november) | € 2 | lichtjes tellen; hoort bij Sint-Maarten |
| **kerstboom** | vloer (december) | € 5 | ballen in rijen. Elke avond één lichtje meer laat de dagen tot Kerst zien |

## 5. Evenementen en speciale gasten

Volgens de NL-kalender, met per evenement de kamer, het getal en een kaartzin.

### 5.1 Herfst (nu)

- **Dierendag, 4 oktober** `[S]`. Wordt in NL sinds 1930 gevierd; op sommige scholen nemen
  kinderen een huisdier of knuffel mee [B32]. "Een extraatje voor het dier" is *onbevestigd* (Historiek gaf 403).
  - *Keuken (voerkar):* elke gast krijgt één koekje extra, dus T = k·N **+ N**.
    «🦴 Hoeveel extra koekjes zijn er nodig?»
- **Kinderboekenweek, 30 september–11 oktober, "Spot aan!"** [B29] [B30]. Het theater (K3)
  houdt een voorstelling, of eerst de muziekkamer als het theater er nog niet is.
- **Vistoernooi-dag** (naar AC [B3]). *Zwembad:* elke gevangen speelgoedvis geeft punten, en een
  rij van 5 is één stempel. Tellen in sprongen van 5.
- **Sint-Maarten, 11 november.** Kinderen lopen met lampionnen langs de deuren, zingen en
  krijgen snoep [B33].
  - *Gang en kamers:* de gasten lopen met de lampion langs de deuren en elke kamer geeft k
    snoepjes. g3 telt, g4 rekent k × kamers. «🏮 Hoeveel snoepjes kregen we samen?»
- **Herfstwind.** Vliegers in de tuin, en eikels en kastanjes zoeken voor een
  **herfstkrans-recept** ("3 eikels + 2 kastanjes", naar de DIY-recepten [B5]).

### 5.2 Winter

- **Sinterklaas, 5 december** `[M]`. Zwijsen heeft een rekencircuit voor groep 3 met deze doelen:
  aftrekken tot 20, meer/minder tot 20, tellen in sprongen van 2, 5 en 10, splitsen tot 12,
  bedragen met munten en drie getallen optellen tot 20 [B27].
  - *Gang:* elke gast zet een schoen bij zijn deur en Piet gooit pepernoten door de schoorsteen.
    g3 splitst tot 12 over twee schoenen, g4 legt k per schoen, g5 verdeelt met rest.
    «👞 Hoeveel pepernoten in elke schoen?»
- **Kerst.** De kerstboom-decoratie met ballen in rijen. Pakjes rondbrengen naar de kamers
  (Toy Day [B3]) in de postkamer.
- **Oud en Nieuw.** De Countdown-klok (AC [B3]): op de dakterras-klok tellen we terug naar 12
  uur, en er zijn oliebollen voor iedereen. «🥣 Hoeveel oliebollen zijn er nodig?»
- **Sneeuw en ijs.** In de tuin rollen de gasten sneeuwpoppen van 3 ballen (tafel van 3, g4).
  «⛄ Hoeveel ballen voor drie sneeuwpoppen?» Het zwembad bevriest en wordt een ijsbaan; de
  baan blijft de getallenlijn van `zwembad`. Schaatsjes (§4) zijn het seizoensvenster. De egel
  (§3) vertrekt voor zijn winterslaap.

### 5.3 Voorjaar

- **Week van het geld** (tweede helft van maart) [B46]. *Receptie:* de spaarpot-decoratie
  vult zich met stapels van 10.
- **Pasen** `[S–M]`. In AC liggen eieren 8 dagen overal verspreid [B3]. In de klas worden
  eierdozen gebruikt voor tienstructuur en groepjes, en sommen uit eieren [B48].
  - *Tuin en kas:* eieren zoeken en in dozen leggen. g3 een doos van 10, g4 rijen van 5, g5 dozen
    van 6. «🥚 Hoeveel eieren hebben we gevonden?»
- **Koningsdag, 27 april: de vrijmarkt** `[M]`. Zwijsen laat kleuters een vrijmarkt naspelen met
  prijskaartjes met cijfers **of dobbelsteenpatronen**: groep 1 met 5 munten van € 1, groep 2
  met 10, en betalen met gepast geld [B28].
  - *Tuin:* hier draaien de rollen om. **De gasten verkopen hun oude spullen op een kleedje, en
    het kind is de verkoper:** het telt wat de koper neerlegt en geeft in g5 wisselgeld. Het
    oranje kroontje en de oranje sjaal staan in het venster. «🧺 Wat kost het samen?»

### 5.4 Zomer

- **Hittegolf (weer).** Meer bestellingen bij de ijssalon (K5); de zwembadbaan is drukker.
- **Zomervakantie.** Gasten komen met **koffers** aan op het station (K7). Wegen hoort bij
  HOTEL.md #7 "Bagagelift" (kg, gram vanaf g5). «🧳 Hoe zwaar zijn de koffers samen?»
- **Avondvierdaagse-loopje:** 4 avonden een rondje door het hotel, 1 stempel per avond (km is g5–6 [B31]).

### 5.5 Het hele jaar

- **Verjaardag van een gast.** Bouwt op de bestaande feesttaart: **kaarsjes = leeftijd** (g3 tot
  10, g4 tot 20 in tientallen), de taart in ½ en ¼ voor g5. «🎂 Hoeveel kaarsjes moeten erop?»
- **Regen.** Regenlaarsjes bestaan al. Zet in de kas een regenemmer met een streepje per bui;
  turven is g4.
- **Pakketjes en ansichtkaarten.** Zoals Cats & Soup een kat op reis stuurt [B9], kan een gast
  op reis gaan. Zijn kaarten komen in de postkamer en de kalender telt de dagen tot hij terug is.

### 5.6 Speciale gasten

| gast | wat hij wil | getal | kamer | bron |
|---|---|---|---|---|
| **VIP-gast** (bijv. een pauw met kroon) | komt **alleen** als de kamer een getelde wens heeft: "3 kussens en 1 aquarium". Laat een aandenken achter | tellen wat er staat en wat nog nodig is. Dit trekt de decoratie de lus in | kamer 1/2 | [B1] [B6] |
| **Het reizende circus** | een wagen voor de deur; acrobaten staan op elkaar | **hoogte in blokjes**: 3 dieren van 4 blokjes; de stoelen rond de piste in rijen | station (K7) en tuin | — (eigen idee) |
| **De beroemde zanger** | één concert in het theater, kaartjes × prijs | arrays met stoelen en geld (g4–5) | theater (K3) | [B29] |
| **Kip met kuikens** | checkt in als gezin | 1 + 4 (optellen); de kuikens in één mand | receptie | §3 |
| **Gast met een huisdier** | de hond brengt een goudvis mee, de poes een vogeltje | het aquarium (bestaande decoratie) **telt** de visjes; een kooitje telt de vogels | kamers | [B35] |
| **De postduif** | brengt brieven van vertrokken gasten | het aantal brieven op de kar; dat bouwt op `post` | postkamer | [B39] |
| **Wintergast (pinguïn)** | wil schaatsen | stapjes op de ijsgetallenlijn, nooit onder nul | zwembad als ijsbaan | [B31] |

Kaartzinnen bij de speciale gasten: «🎪 Hoeveel dieren staan er op elkaar?» en
«👑 Hoeveel kussens wil de gast nog?»

## 6. Top 10 ideeën

1. **Trimsalon** (K1): meetlat in cm, strikjes tot 10 en tijdsduur op de wandklok. Het genre heeft het en wij missen het. `[M–L]` · *nu: geen spel meet nu lengte in cm* · [B20] [B18] [B31]
2. **Kinderboerderij met koe en kip** (K4 + §3): literpak melk (SLO-referentie), eierdozen van 10 en 6, delen met rest. `[L]` · *nu: geen spel rekent met de liter; 550–600 boerderijen in NL* · [B31] [B37] [B45] [B48]
3. **Theater "Spot aan!"** (K3): rijen stoelen als arrays, kaartjes, de band op het podium. `[M–L]` · *nu: het Kinderboekenweekthema 2026 loopt tot 11 oktober; het rijen-rooster uit HOTEL §6 is niet gebouwd* · [B29] [B30]
4. **Sinterklaasweek**: schoen per gast en pepernoten splitsen of verdelen over de schoenen. `[M]` · *nu: 5 december is over 8 weken* · [B27]
5. **VIP-gast met een getelde wens** ("3 kussens en 1 aquarium"). Trekt de 9 decoraties de lus in. `[M]` · *nu: de decoratie van 2026-10-07 heeft nog geen rekenfunctie* · [B1] [B6]
6. **Getal-decoraties**: wandklok, scheurkalender ("nachten tot het feest") en kapstok (één haakje per bed). `[S–M]` · *nu: past op het bestaande meubelboek-tabblad* · [B31]
7. **Fietsenstalling** (K6): wielen = tafels van 2 en 3, omgekeerd delen voor g5; zone, geen deur. `[M]` · *nu: precies de tafels van groep 4, heel NL* · [B31]
8. **Eekhoorn als 7e gast**: nootjes per 10 verstopt (positiewaarde). Donker kastanje tegen de vos. `[M]` · *nu: lievelingszoogdier van NL* · [B34] [B41]
9. **Klompjes en seizoensvensters** in plaats van verrassingen: de schoenformule (4 poten × prijs), de lampion op 11 november en het kroontje op Koningsdag. `[S]` · *nu: meteen inzetbaar, geen kansspel* · [B44] [B5] [B33]
10. **Dierendag**: T = k·N + N in de voerkar. Elke 4 oktober een klein extraatje. `[S]` · *nu: net geweest, dus klaar voor 2027; de goedkoopste feestdag* · [B32]

## 7. Bronnen

**O** = zelf geopend en gelezen. **Z** = alleen uit een zoekresultaat, *onbevestigd*.

| # | URL | notitie |
|---|---|---|
| B1 | https://en.wikipedia.org/wiki/Neko_Atsume | O: 86 katten waarvan 26 zeldzaam (v1.15.0), zilveren en gouden vis, aandenkens, zeldzame katten alleen bij speciale spullen |
| B2 | https://nookipedia.com/wiki/Nook_Miles | O: trappen van Nook Miles (vissen 10/100/500/2000/5000, oogst 10/50/150/500/1000) |
| B3 | https://nookipedia.com/wiki/Event/New_Horizons | O: Vistoernooi, Paashaas-dag (8 dagen eieren), Toy Day 24/12, Countdown-klok |
| B4 | https://nookipedia.com/wiki/Able_Sisters | O: 6 stukken per dag, 8 ontwerpen, 2 outfits, paskamer |
| B5 | https://nookipedia.com/wiki/DIY_recipes/Spring | O: recepten met getelde materialen (bonsai: 6 blaadjes, 2 hardhout, 3 onkruid, 3 klei) en seizoensvensters |
| B6 | https://www.thegamer.com/animal-crossing-happy-home-paradise-unlock-every-facility/ | O: minimale meubels per voorziening (school 1/2/4, ziekenhuis 1/4/1/1/1/3) |
| B7 | https://www.gamespot.com/gallery/animal-crossing-new-horizons-fossils-museum-blathers/2900-7410/ | Z: museumaantallen (80/80/40/73/43) en de ontgrendeling na 5 en 15. De fandom-wiki gaf HTTP 402 |
| B8 | https://metaphorsandmoonlight.com/game-review-cats-soup-by-hidea/ | O: kookposten, kleding, thema's, evenementen, rustig tempo |
| B9 | https://www.talkandroid.com/460384-cats-and-soup-game-guide-tips-tricks-and-strategies/ | Z: "+1 per niveau" op de soepprijs; een kat op reis sturen |
| B10 | https://apps.apple.com/us/app/hotel-hideaway-avatar-chat/id922825959 | Z: seizoenskamers en ranglijsten; de klacht over het rad komt uit Google Play-recensies |
| B11 | https://habboxwiki.com/Hotel_Versions_(V1-V10) | Z: Habboween 2001 en seizoenscampagnes. De Habbo-hulppagina "Furni Definitions" gaf HTTP 403; de 4–12 maanden zijn onbevestigd |
| B12 | https://en.wikipedia.org/wiki/Cozy_Grove | O: dagelijkse taken in echte tijd, geestberen. Kampvuur en kleur komen uit Z-recensies (Shacknews) |
| B13 | https://apps.apple.com/us/app/tsuki-adventure/id1436776211 | Z: worteltjes, treinstation, vissen, gacha |
| B14 | https://stardewvalleywiki.com/Animals | O: producten en ritme per dier (kip elke dag, eend om de dag, konijn om de 4 dagen, schaap om de 3 dagen) |
| B15 | https://en.wikipedia.org/wiki/Hay_Day | O: bestellingen per vrachtwagen en boot, kraampje |
| B16 | https://hayday.fandom.com/wiki/Truck | Z (fandom gaf 402): 3 kratten per product op de boot, dozen van hoogstens 10 in het kraampje |
| B17 | https://en.wikipedia.org/wiki/Pok%C3%A9mon_Caf%C3%A9_ReMix | O: klanten met bestellingen. De outfits (om de 2 niveaus) komen uit Z-Bulbapedia |
| B18 | https://toca-life-world.fandom.com/wiki/Pet_Hotel | Z (402): dierenhotel met aquarium, 4 huisjes en een dokterspost; dierenarts met wachtkamer |
| B19 | https://talkingfriends.fandom.com/wiki/My_Talking_Tom_Friends | Z: behoeften als pictogram, 6 in het zwembad, 3 aan tafel |
| B20 | https://apps.apple.com/app/id1163762034 | O: Pet World: My Animal Hotel; soorten, verzorging, verblijven uitbreiden |
| B21 | https://en.wikipedia.org/wiki/Bluey:_The_Videogame | O: 4 minispellen, stickers en hoedjes. De 3 en 25 tikken komen uit een Z-walkthrough |
| B22 | https://nosycrow.com/blog/our-latest-app-pip-and-posy-fun-and-games-is-out-today/ | Z: memory met 8/16/24 kaarten, puzzels met 6/9/12 stukjes |
| B23 | https://www.commonsensemedia.org/game-reviews/overcooked | Z: leeftijd 8+, het tempo als drempel voor jonge kinderen |
| B24 | https://www.pocketgamer.biz/making-of-crossy-road/ | O: voxels, schuine camera, figuren puur cosmetisch, verzamelen als motor |
| B25 | https://www.gamedeveloper.com/art/voxelart-styles-in-video-games | O: vector-voxels leesbaar op elke schaal |
| B26 | https://hellokittyislandadventure.wiki.gg/wiki/Island_Residents | Z: 3 cadeaus per dag, vriendschapsniveaus |
| B27 | https://www.zwijsen.nl/inspiratie/kant-en-klaar-sinterklaasrekencircuit-voor-groep-3 | O: zes rekendoelen van het Sinterklaascircuit voor groep 3 |
| B28 | https://www.zwijsen.nl/spelend-leren/gratis-activiteit-voor-kleuters-ter-voorbereiding-op-koningsdag/ | O: vrijmarkt, prijskaartjes met dobbelsteenpatronen, 5 en 10 munten |
| B29 | https://www.zwijsen.nl/themas/kinderboekenweek-2026-spot-aan/ | O: thema "Spot aan!": toneel, dans, zang |
| B30 | https://cpnb.nl/campagnes/kinderboekenweek/ | O: data 30 september–11 oktober 2026 (het thema staat niet op deze pagina) |
| B31 | https://www.slo.nl/thema/meer/tule/rekenen-wiskunde/kerndoel-33/ | O: meten per groep. Liter met literpak in g3–4, temperatuur en negatieve getallen in g5–6, tijdsduur in g5–6, nachten tellen tot een feest |
| B32 | https://nl.wikipedia.org/wiki/Dierendag | O: 4 oktober, sinds 1930 in NL, scholen, de koppeling met de Kinderboekenweek in 2000 |
| B33 | https://www.eo.nl/artikel/sint-maarten-feest-van-liedjes-en-lampionnen | O: lampionnen, liedjes, langs de deuren, snoep |
| B34 | https://www.zodion.nl/actueel/nieuws/favoriete-zoogdier-van-nederland-de-eekhoorn-audio | O: favoriet zoogdier 2009: eekhoorn 379, egel 232, vos 179 (van 2267) |
| B35 | https://www.hartvannederland.nl/milieu-gezondheid/dieren/artikelen/katten-honden-of-vissen-dit-zijn-de-populairste-huisdieren-van-nederland | O: huisdieren per huishouden (2023) |
| B36 | https://www.ipsos-publiek.nl/actueel/huisdierenpeiling-steeds-minder-vijvervissen-en-pluimvee-in-nederland/ | Z: 20,6 miljoen huisdieren (2026, Dibevo en NVG); niet gebruikt in de tekst |
| B37 | https://nl.wikipedia.org/wiki/Kinderboerderij | O: 550–600 kinderboerderijen, 25–30 miljoen bezoekers, de gangbare dieren |
| B38 | https://nl.wikipedia.org/wiki/Nijntje | O: figuren en het palet (gedempt rood, geel, blauw, groen, bruin, dikke contouren) |
| B39 | https://nl.wikipedia.org/wiki/De_Fabeltjeskrant | O: Meneer de Uil, Stoffel, Gerrit de Postduif, Myra Hamster, Greta Bontekoe; YouTube-herstel 2026 |
| B40 | https://www.woezelenpip.nl/vriendjes | O: Buurpoes, Charlie, Molletje, Vlindertje, Wijze Varen, Tante Perenboom |
| B41 | https://en.wikipedia.org/wiki/Dikkie_Dik | Z: Poes Muis, Beer, Eekhoorn |
| B42 | https://en.wikipedia.org/wiki/Jip_and_Janneke | O: makers en jaren. Takkie (teckel) en Siepie (poes) komen uit Z-bronnen |
| B43 | https://www.eftepedia.nl/lemma/Holle_Bolle_Gijs | O: "Papier hier!", "Dank u wel!", elf Gijzen |
| B44 | https://kansspelautoriteit.nl/sites/default/files/onderzoek_naar_loot_boxes_-_een_buit_of_een_last_-_nl.pdf | O (pdftotext): 4 van de 10 lootboxen illegaal, bijna-winst en effecten verhogen het risico, minderjarigen niet uitgesloten |
| B45 | https://nl.wikipedia.org/wiki/Lakenvelder_(rund) | O: witte band om het lijf, zwart of rood, op kinderboerderijen. Barnevelder (Z): https://barnevelderkip.nl/de-barnevelder |
| B46 | https://www.zwijsen.nl/algemeen/doe-jij-mee-met-de-week-van-het-geld-2026/ | Z: Week van het geld, 23–27 maart 2026 |
| B47 | https://kinderpostzegels.nl/en/blogs/news/kinderpostzegelactie-2026-is-van-start | Z: 16–23 september 2026, groep 6–8 (buiten onze leeftijd, daarom niet gebruikt) |
| B48 | https://derekenhoek.nl/pasen-en-rekenen/ | O: rekenen met eieren en eierdozen. Doos van 10 = staaf (Gynzy, Z: https://www.gynzy.com/nl-nl/bibliotheek/content/groep-3-blok-8-week-2-les-8) |
| B49 | https://nookipedia.com/wiki/Clothing/New_Horizons | Z: 10 kledingcategorieën in New Horizons |

**Interne bronnen:** `HOTEL.md` §5–6 (ideeën die nog niet gebouwd zijn), `IDEAS.md`
(curriculumladder), `MINIGAMES-RESEARCH.md` §6–9 (zones, vlaggen, wat verworpen is: "MR"),
`games/_winkel/beurt.gd` (prijsbanden), `art/gasten.gd` (paletten, kleding) en
`autoload/rooms.gd` (decoratie).
