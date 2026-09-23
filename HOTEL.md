# Dierenhotel Kwispelsteeg — ontwerp (synthese)

Pivot van het Kwispelsteeg-diorama naar een Habbo-achtig dierenhotel waarin de rekenminigames IN de 3D-wereld gespeeld worden. Doelgroep ongewijzigd: meisjes 6–9, groep 3–5 (curriculum en ontwerpvalkuilen: zie IDEAS.md). Techniek ongewijzigd: de bestaande vanilla-JS voxelmotor (demos/waggletail). Gegenereerd 2026-08-24 uit drie ontwerp-lenzen (architectuur, hotelwerk-games, gastenplezier-games), samengevat en ontdubbeld door de lead.

## 1. Kernidee: de wereld is het rekenblad

- Geen rekenkaartjes onder het diorama meer. Alles wat je aanraakt (bakjes, bedden, sleutels, munten, wijzers, dieren) ligt in de wereld. Technisch: de bestaande naamplaatjes-laag (DOM boven het canvas op schermX/schermY) wordt een hotspot-laag met knoppen en drop-targets; het huidige sleepmechanisme blijft ongewijzigd werken.
- Kamer-camera: nooit uitzoomen, wel verhuizen. Eén ruimte vult altijd het scherm (voxels blijven scherp); groei = meer ruimtes. Wisselen via deur/trap, een kamerbalk met "hier wacht iemand"-badges, of een 2D-plattegrond.
- Ruimtes: receptie, gang met kamers, keuken, tuin (het huidige erf, hergebruikt), zwembad en wasserij (golf 3); later spelzaal, spa, feestzaal, verdieping 2.

**De acht ruimtes (`rooms.js`, maten in voxels; de wanden staan op x = 0 en z = 0).** Dit is de lijst zoals hij in de code staat:

| id | naam | w × d | wand | deuren naar | waarvoor |
|---|---|---|---|---|---|
| `receptie` | Receptie 🛎️ | 120 × 120 | 54 | gang | de balie als L: bel, kassa, meubelboek, prikbord, sleutelbord — hier komt een gast binnen en checkt hij uit. |
| `gang` | Gang 🚪 | 120 × 36 | 56 | receptie, kamer 1, kamer 2, keuken | de verdeelruimte: vier deuren, twee planten en een kist, en de route van de voerkar. |
| `kamer1` | Kamer 1 🛏️ | 114 × 114 | 58 | gang | twee bedden, een voerbakje en een speelmand: hier slapen en eten de gasten. |
| `kamer2` | Kamer 2 🛏️ | 114 × 114 | 58 | gang | dezelfde inrichting als kamer 1, tweede slaapkamer (en de uitwijkkamer van "bedden op rij"). |
| `keuken` | Keuken 🍪 | 120 × 114 | 56 | gang, tuin, wasserij | voerkast, koekjeszak en de voerkar: hier wordt het eten verdeeld. |
| `tuin` | Tuin 🌳 | 130 × 130 | — (erf, vast kader) | keuken, zwembad | het gazon áchter het hotel: links de achtergevel met de keukendeur (luifel, deurmat, keukenraam), achter het hek het zwembad met parasol en trapje, verder tobbe, hok, boom, bal, kist, plus twee vrijgehouden vloerzones. |
| `zwembad` | Zwembad 🏊 | 144 × 88 | 50 | tuin | een langwerpig bad ín de vloer tegen de achterwand, met een dek ervóór: de zwemles (G1). |
| `wasserij` | Wasserij 🧺 | 100 × 90 | 52 | keuken | wasrek en wastobbe, vrije wand voor de kratten: de wasmandtoren (G4). |
| `speelzaal` | Speelzaal 🧸 | 114 × 100 | 56 | receptie | klimrek, ballenbak, blokkentoren, kussenhoek en muziekdoos om een lichtblauwe mat: de dansvloer is vrijgehouden zone. |
| `kas` | Kas 🪴 | 128 × 112 | 40 (glas) | tuin | de glazen kas achter het hotel (R3): moesbakken langs de achterwand, de aardbeienbak met de pluktafel (**aardbeien plukken**: tientallen en eenheden, aanvullen tot 10 en tot 100) en de marktweegschaal met haar gewichten (**groenten wegen**: meten in kilo's met een balans), zonnebloemen, pompoenen, een potkast en een terracotta pad. |

De deurgraaf is één samenhangend geheel (`Rooms.pad`). **Elke overgang laat zien waar hij heen gaat** (eigenaar, 2026-09-23): door elke deur zie je de vloer van de kamer erachter (de roze loper van de gang, de tegels en de abrikozen loper van de keuken, het gras van de tuin), de keuken en de tuin hebben aan beide kanten een echte deur (in de keuken in de hoek na de koelkast, in de tuin in de achtergevel van het hotel), en de enige poort is die tussen tuin en zwembad: vanuit de tuin een witte zwembadpoort met reddingsboei en het water erachter, vanuit het zwembad een rozenboog met de tuinboom erachter. De kas heeft een glazen deur in de achtergevel, waar het keukenraam hing, met een glazen luifel erboven: door die deur zie je het terracotta pad van de kas, en binnen zijn de wanden van glas (games-c.md §1).

**Nieuwe ruimtes (golf 3, ticket P1a).** Het zwembad hangt aan de tuin via een opening in het achterhek. Het bad staat als data op de ruimte (`Rooms.get('zwembad').bad` = x 18..134, z 12..44), zodat een spel er een baan van L meter lineair op afbeeldt; de twee wachtplekken staan er ook (`.dek.start` en `.dek.over`). De dieren dwalen alleen op het dek vóór het water — de dwaalplekken, de deur en beide dek-plekken liggen in dezelfde convexe strook, dus geen enkele wandeling kruist het bad. De wasserij ligt naast de keuken en is de kamer van de wasmandtoren (G4). De tuin houdt twee kale vloerzones vrij (`Rooms.get('tuin').zones`): `hinkel` langs de achterrand vóór het hok (76 × 16, voor de stapstenen van G3) en `kraam` langs de rechterzijrand (22 × 32, voor de souvenirkraam van G5).

**Kamermaten (voxels, `rooms.js`).** De vier speelkamers in de tabel hierboven zijn 1,5× groter dan de eerste opzet — ze voelden te klein. De gang en de tuin (vast kader) bleven zoals ze waren. De wandhoogtes bleven ook staan (50–58), dus de kamerdoos van die vier is hoger geworden (290 → 366–370 voxel-px) en hun vloer is 1,5× zo diep. Meubels worden niet groter: de balie is daarom een L van twee + twee stukken, en álle plekken in een kamer staan als bréuk van `r.w` / `r.d` in de code (`Rooms.plek`, `Rooms.hoogte`) — een volgende verbouwing schuift ze automatisch mee. De dieren zijn ook niet groter geworden; die vier kamers krijgen daarom `loop: 1.5` (rooms.js), zodat een gast er op het scherm net zo hard loopt als vroeger en een kamer oversteken even lang duurt.

**Camera en voxelmaat.** Drie getallen horen bij elkaar, per ruimte: `q` = css-px per voxel-px (hoe groot staat de kamer op het scherm), `g` = de voxelmaat in canvas-px (altijd een heel getal 2..4, want uitgerekte blokjes willen we niet) en `dicht` = canvas-px per css-px, met `q = g / dicht`. Omdat de kamers niet meer allemaal even groot zijn heeft **elke ruimte zijn eigen maat**: hij vult het kader in de breedte, en in de hoogte past minstens de hele vloer plus een strook wand van 28 voxels (daar hangen het prikbord en het sleutelbord). Boven die strook staat kale wand; in een laag kader (een liggende telefoon, 200 px) snijdt de camera daar een stuk van af — nooit van de vloer. Dat is geen uitzoomen: je ziet nooit het hele hotel, je verhuist, en bij het verhuizen verandert de maat mee (anders zou de smalle gang klein in beeld staan omdat de receptie breed is). Daarna kiezen we de dichtstbijzijnde héle `g`; is die groter dan het scherm zelf kan geven (op een telefoon is `g = 2` al te groot voor een kamer van 500 voxel-px breed), dan tekenen we het canvas op een hógere dichtheid dan het scherm en laat de css het terugschalen. Zo blijft de voxelmaat heel, past de kamer altijd, en houden de knoppen en de tekst van de hotspot-laag hun echte css-maat (≥ 48 px). **Dichtheidsplafond (M1b).** Op een klein scherm — de **korte** zijde onder de 500 px, dus een telefoon staand én liggend — met `devicePixelRatio > 2` rekenen we met 2 als ondergrens van `dicht` in plaats van 3. Daarmee valt `g` daar op 2 en werd het wereldcanvas van een iPhone 13 staand 3,4 MB in plaats van 7,7 MB (vloerplaat 2,8 in plaats van 6,3 MB) en liggend 6,1 MB in plaats van 9,6 MB, terwijl `q` (hoe groot de kamer op het scherm staat) precies gelijk blijft: de css schaalt het canvas terug en op een 3×-scherm zie je dat niet. Het blijft een plafond op de **ondergrens**: `dicht = max(ondergrens, g / q)`, dus een kamer die niet in het kader past duwt de dichtheid nog steeds omhoog (anders zou `g` geen heel getal meer kunnen zijn). Liggend is dat goed te zien: hoe lager het kader, hoe hoger `dicht` — een hoger kader is daar dus ook een goedkoper kader. De hoogte van het kader is voor alle ruimtes gelijk (anders springt de pagina bij elke deur): zo hoog als er op het scherm over is, maar nooit zó hoog dat de kleinst uitvallende doos minder dan 60% vult; onder de kamer blijft een strook van 132 px vrij voor het cijferpad. Reken in een minigame dus met `ctx.wereld.schaal()` (`k = q`, per kamer) en **nooit** met `devicePixelRatio`.

## 2. Gastenstroom en progressie

- Gast arriveert als het kind op de bel tikt (nooit automatisch, geen oplopende wachtrij). Check-in aan de balie = de bestaande poortvragen plus "is er een vrij bed?".
- Bedden zijn de harde gastenlimiet. Meer bedden kopen = meer gasten = grotere getallen. Rekenen koopt beter, nooit toegang: het hotel gaat nooit op slot.
- Behoeften (eten, kamer, spelen, bad) staan als pictogram boven het dier; het dier loopt zelf naar de plek en wacht daar geduldig. Geen verval, geen meters, nooit boos of ziek.
- Uitchecken: familie aan de balie, brief/foto voor de muur, rekening betalen (rekenmoment).
- Dagloop: ochtendronde (prikbord, max 3 taakchips) → vrij spelen (taken in willekeurige volgorde, meubels zetten, bel) → avondronde (uitchecken, sterren, morgen).

## 3. Eén schaalregel: N bepaalt het getal, nooit het tempo

Elke minigame leidt zijn getallen af uit N (aantal gasten) met T = k·N + r, 0 ≤ r < k; k en het plafond komen uit de band:

| Band | N | k | Plafond | Extra |
|---|---|---|---|---|
| groep 3 | 2–3 | 1–2 | ≤ 20 (liefst ≤ 10) | r = 0 of 1; klok hele uren; icoon-only |
| groep 4 | 4–6 | 2,3,4,5,10 (alleen die tafels) | ≤ 100 | rest < k; kwartieren; hele euro's |
| groep 5 | 7–10 | t/m 10 | ≤ 100 (geld ≤ €20 per betaling) | verdeelstrategie, tijdsduur, wisselgeld |

De band wordt begrensd door het adaptieve signaal (rollende accuratesse + twijfeltijd): hooguit één stap boven het kunnen van het kind. Een snelle zesjarige mag een groot hotel hebben zonder groep-5-sommen. Nooit levelnummers tonen. Timers: alleen memoriseer-items (splitsingen t/m 10, tafels) hebben een 2-secondenvenster, en dat bepaalt alleen of er hulp verschijnt (rekenrek/getallenlijn), nooit of het antwoord telt.

## 4. Economie

- Sterren: voor meedoen (taak afgerond, hoe dan ook) → versiering (vlaggetjes, kleuren, stickers). Beloning die niet aan goed rekenen hangt.
- Munten (hele euro's): uit uitchecken. Rekening = nachten × prijs (€1/€2/€5), totaal ≤ €20; familie legt munten neer, kind telt en geeft wisselgeld (groep 3: samen tellen; 4: bedrag samenstellen; 5: wisselgeld van €20). Muntenlade van Zilverhoef hergebruikt.
- Meubelboek, alles ≤ €20: plant €1, bakje €2, mandje €3, bed €5 (+1 gast), speelmand €4, badkuip €8; nieuwe kamer = 4 bouwdelen × €5; verdieping = 4 × €10 (tafel van 10 met biljetten). Meubels slepen op het voxelraster, tik = draaien.

## 5. Minigame-catalogus (in-world, schaalt met N)

Bestaande drie, opnieuw gehuisvest:
- **Voerkar** (was: eerlijk delen) — keuken: zak van T koekjes, kar met N vakjes + snoeppot, door de gang, elk bezet bakje vullen. Overgeslagen kamer is zichtbaar.
- **Dagplanner op het prikbord** (was: planbord) — regels komen uit het gebouw (één tobbe, wasserij voor 2, dokter Els om 15:00); na "Klaar" speelt het hotel het plan echt af. Solver ongewijzigd.
- **Check-in aan de balie** (was: poort) — voorraad vs dagen × nieuw, plus "vrij bed?".

Hotelwerk (nieuw):
1. **Bedden op rij** — kamer als rooster, bedjes slepen tot rijen × bedden; schuifwand = verdeelstrategie (7×6 = 5×6 + 2×6). Tafels als kamer. Icoon-only. Kernspel: bepaalt gastcapaciteit.
2. **Sleutelbord** — sleutel naar juiste haakje; blanco nummerplaatjes uit het patroon opmaken (1–20 → sprongen van 5 → kamer 214 = verdieping 2). Gast loopt daarna naar zijn deur.
3. **Souvenirkraam** — gast met verlanglijst, munten slepen, wisselgeld; het gekochte (sjaaltje, hoedje, bal) blijft zichtbaar op het dier.
4. **Wasmandtoren** — wasgoed sorteren in kratten; kratten worden echte staven (turven, verschil, legenda 1 = 2). Icoon-only.
5. **Poetskar** — tegelmat (oppervlakte) en plintlatten (omtrek) laden en leggen; L-vormige kamer bij groep 5. Tekort = tweede loopje, geen fout.
6. **Wekkerdienst** — wijzers van de halklok draaien naar wekkerkaartje (hele uren → kwartieren → minuten + tijdsduur). Spookwijzer na 2 pogingen.
7. **Bagagelift** — koffers in de liftbak tot de grens (touw zakt door, naald draait); balansplank = getal in twee gelijke delen. Kilo's, later gram.
8. **Tafel dekken** — spiegelbeeld van de gedekte tafelhelft, later twee assen. (Overlapt met Spiegelmaskers; zie §6.)

Gastenplezier (nieuw):
9. **Tot je schouders** — zwembad met aflopende bodem; meetlat, dier naar de zone waar het water tot zijn schouders komt, opstapblokjes van 10 cm. Meten cm/dm.
10. **Hinkelpad** — stapstenen als getallenlijn (20 → 100 → 1000); sprongkeitjes 2/5/10 op een dier; het dier hupt en moet precies op de trap landen.
11. **Rijtjes in de moestuin** — zaadjes in rijen × kolommen, twee vormen voor hetzelfde getal, rest in het kweekpotje. (Overlapt met Bedden op rij; zie §6.) De moesbakken van de kas (zone `rijen`) en de zaadkist staan er klaar voor.

In de kas gebouwd (2026-09-23, games-c.md):
- **Aardbeien plukken** (`oogst`) — pluktafel met bakjes van tien (het honderdveld): tel de tientallen en eenheden, reken uit hoeveel er nog bij moeten (splitsen tot 10, aanvullen tot 100), pluk ze zelf; groep 5 plukt na het volle bakje een heel bakje per tik ("via de tien").
- **Groenten wegen** (`weeg`) — een marktbalans met een pompoen, een meloen of een zak aardappels: lees af wat de gewichten samen wegen, leg zelf gewichten op tot de balans recht staat (hij helt naar de zwaarste kant) en lees je eigen meting af; 1, 2, 5 kg · + 10 kg · 1, 5, 10, 20 kg tot de reuzenpompoen van 60 kilo.
12. **Wat wil de jubilaris?** — feestzaal: stemmen turven op het krijtbord, ballonnen als echte staven, hoogste kolom wint.
13. **Tobbe-tijd** — scheppen shampoo, splitskraantje = halveren, twee tobbes even hoog; verdubbelen/halveren, splitsen t/m 10. Icoon-only.
14. **Spiegelmaskers** — stickers op linkerhelft, tafel klapt dicht, masker op de snuit; as verticaal → horizontaal → diagonaal.
15. **Dansrijtje** — polonaise op lichttegels, dansmove per dier, patronen ABAB/AABB/groeiend; muziek wacht altijd op jou.
16. **De bus van tien uur** — wijzers op vertrektijd, activiteiten met duur, retourtijd; bus rijdt echt door het diorama.

Domeindekking: delen met rest, tafels/arrays, geld, tijd/klok, tijdsduur, meten (cm/dm, kg/g, oppervlakte/omtrek), getallenlijn/sprongen, getalpatronen/positiewaarde, data/turven/staafdiagram, symmetrie, patronen, verdubbelen/halveren/splitsen.

## 6. Lead-keuzes bij overlap

- Arrays: **Bedden op rij** is primair (stuurt de gastenlimiet). Moestuin-rijtjes later als groep-5-variant (verdeelstrategie over twee bakken).
- Data: beide houden, andere band: **Wasmandtoren** (groep 3–4, icoon-only) en **Feestzaal** (groep 4–5, legenda).
- Symmetrie: **Spiegelmaskers** wint (eigen masker, gedragen door het dier). Tafel dekken vervalt of wordt patroonvariant.
- Tijd: beide houden: **Wekkerdienst** (groep 3–4) en **Bus** (groep 5 tijdsduur).
- Geld: één muntenlade-component voor rekening bij uitchecken, Souvenirkraam en meubelboek.

## 7. Bouwplan (fasen, elk apart verifieerbaar)

1. **Fundament** — rooms.js (ruimtes als data, deurgraaf met BFS), kamer-camera, hotspot-laag + hit-test, receptie met bel en check-in, bedden als limiet, save-formaat v7 met migratie van v6 en v5, dieren buiten beeld grof gesimuleerd. Voerkar en rekening-bij-uitchecken als eerste twee in-world taken.
2. **Kern-lus** — Bedden op rij (capaciteit), Sleutelbord, Tobbe-tijd, meubelboek + muntenlade. Hiermee sluit de lus rekenen → inrichten → meer gasten → moeilijker.
3. **Verbreding** — Wekkerdienst, Hinkelpad, Souvenirkraam, Wasmandtoren, dagplanner in-world.
4. **Feest** — Feestzaal, Spiegelmaskers, Dansrijtje, Bagagelift, Poetskar, Zwembad, Bus.

## 8. Open beslissingen voor de ontwikkelaar

1. Eén ruimte per scherm of toch een uitgezoomd hotel-overzicht (Habbo-gevoel)? Advies: kamer-camera + 2D-plattegrond; papieren prototype op telefoonformaat eerst.
2. Band-van-N versus adaptief: adaptief begrenst de band, N de grootte. Productkeuze.
3. Prijzen ≤ €20 dwingen tot bouwdelen (kamer = 4 × €5): sparen of gedruppel? Playtesten.
4. Uitcheck-cadans: met 2–4 nachten per gast kan N schommelen in plaats van groeien; eerst een simulatie van bedden × nachten op papier.
5. Hotspots bij overlap in isometrie: z-index moet exact de tekenvolgorde volgen (anders pakt een tik het verkeerde object). Engine-ticket die alle games delen.

*Status: ontwerp, niet gebouwd, niet geplaytest. Motorclaims zijn door de workers tegen world.js/ui.js/state.js/shop.js gecheckt (hergebruik van naamplaatjes-laag, makeDraggable, planOplossingen, koekjesSom, muntenlade).*

## 9. Ontwerpregel: rekenen ín de wereld, zonder leeswerk (toegevoegd na speeltest fundament)

Feedback op het fundament: de rekenpanelen naast het diorama voelen als "een website naast het spel", en er staat te veel tekst. Vanaf nu geldt voor het fundament en alle minigames:

- **Geen rekenpaneel naast de wereld.** Sommen, aantallen en keuzes verschijnen als kleine kaartjes of spreekwolkjes die aan een object of dier in de wereld hangen (zelfde verankering als de naamplaatjes). De wereld blijft altijd zichtbaar en is het enige speelvlak.
- **Getallen op objecten.** Bakjes tonen hun aantal als cijfer op het bakje, haakjes hun nummer, de toonbank het bedrag, bedden hun rij. Het rekenschrift-uiterlijk mag terugkomen als één kleine "sommenkaart" aan het object, nooit als een lap tekst.
- **Tekstbudget (herzien 2026-09-03 na speeltest: een kind van zes kon "4 × 2 ? 20" niet ontcijferen).** Elke sommenkaart draagt één gewone Nederlandse zin, vlak bóven de som, met een werkwoord of een vraagwoord erin en met het pictogram vooraan op diezelfde regel. **Budget: ≤ 8 woorden én ≤ 40 tekens.** De één-regel-garantie geldt tot ongeveer 34 tekens (gemeten op 420 en 860 px breed); 35-40 tekens breekt naar een tweede regel, en meer dan twee regels per zin bestaat niet. Op een smalle telefoon (kader < 360 px) krimpt het kaartje naar 170 px en breekt elke zin af: daar gaat "het dier blijft zichtbaar" vóór "de zin op één regel", en het cijferpad mag daar toetsen van 44 px hebben. Een tweede korte zin mag als er nog een getal bij hoort, bijvoorbeeld de voorraad; drie zinnen niet. De zin noemt de getallen in hotelwoorden: "🍽 We eten 4 dagen lang 2 scheppen" boven "4 × 2". Een kale uitdrukking ("4 × 2 ? 20", "12 : 3", "🪑 + 🛋 =") staat er nooit zonder die zin, en "?" wordt nooit als vergelijkingsteken tussen twee uitdrukkingen gebruikt. Antwoordkeuzes zijn knoppen met pictogram ÉN woord ("⬇ te weinig", "⚖ precies", "⬆ blijft over") in één strook aan het kaartje: nooit alleen een pictogram, nooit verspreid door de kamer. Een pictogram staat altijd in hetzelfde wolkje als zijn woord of getal - ook de wenspictogrammen boven de dieren ("🍪 eten", "🛏 bed"). Verder blijft het bij pictogrammen en getallen: uitleg gebeurt door voordoen (uitgewerkt voorbeeld in de wereld), niet door lezen, en feedback is pictogram + getal ("nog 2 🍪", "3 + 3 ✓"). Taakkaartjes op het prikbord houden hun eigen korte regel (≤ 6 woorden).
- **Slepen gebeurt in de wereld.** Koekjes komen uit een zak-hotspot en gaan naar bakjes in de kamer; munten uit de buidel naar de toonbank; sleutels naar haakjes op de muur; bedjes uit de kist op de vloer. Het cijferpad is het enige toegestane 2D-element en verschijnt klein, aan het object verankerd.
- **Optioneel voorlezen.** Korte prompts mogen via de browser-spraaksynthese (Web Speech API, offline beschikbaar op de meeste apparaten) worden voorgelezen bij een tik op het wolkje; nooit verplicht, nooit automatisch herhalend.
- **Elk woord hangt aan het ding waar het over gaat (eigenaarswens 2026-09-23).** "Plaatjes als [de receptie met het open bord] zijn veel te druk in iconen. en wekker zetten is bijvoorbeeld helemaal niet relevant aan waar de tekst geplaatst is. Dit gebeurt vaak over het hele spel". Een knop staat óp of tegen zijn eigen ding, nooit op het ding ernaast (een knop die van een ander ding 15 % of meer afdekt, kiest een andere kant); een deurbordje hangt óp zijn deur; een spel dat niet loopt laat zijn eigen spullen staan en zijn ingang hangt daaraan; een rekenkaart die op haar eigen voorwerp zou vallen stapt ernaast. Het prikbord is een **blad**: zijn taakjes gaan over kamers elders in het hotel, dus er is in de receptie geen plek die bij ze hoort — op het blad staat onder elk briefje in welke kamer het is. Het blad is geen rekenpaneel (er staat geen som op) en valt dus buiten de eerste regel van deze lijst, net als de plattegrond en de brievenmuur.
- **Een misser (S5, eigenaarswens 2026-09-20).** Een fout antwoord doet iets zichtbaars en kost niets (R6): het dier van de beurt is even sip, er hangt `🔄 Nog een keer` bij, en de antwoordstrook gaat ~1,2 s op slot zodat doortikken niet tot het goede antwoord leidt — daarna komen **dezelfde vier keuzes in dezelfde volgorde** terug met leeg antwoordvakje. Geen rood, geen kruis, geen straf, geen ster eraf; het spel houdt zijn eigen `missers` en hulpladder. (Het plan vroeg om `😢`; dat teken zit niet in de subset `fonts/Emoji.ttf` en zou tofu tekenen, dus het huispictogram voor "opnieuw" uit `voerkar`/`tobbe`.)
- **Technisch.** Het fundament levert hiervoor primitieven in de plugin-API: `ui.wolk(obj, {icoon, getal, tekst?})` (spreekwolkje aan object), `ui.somkaart(obj, som, {regel, icoon, keuzes})` (mini-rekenschrift aan object; `regel` = de verplichte zin, `keuzes` = de knoppenstrook met woorden), `wereld.getalTag(obj, n)` (cijfer op object), en sleepbronnen met teller (`hotspots.bron(obj, {icoon, aantal})`). Games gebruiken uitsluitend deze primitieven voor rekenweergave; het oude `ui.paneel` blijft alleen voor het startblad en het meubelboek-overzicht.
