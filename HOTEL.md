# Dierenhotel Kwispelsteeg — ontwerp (synthese)

Pivot van het Kwispelsteeg-diorama naar een Habbo-achtig dierenhotel waarin de rekenminigames IN de 3D-wereld gespeeld worden. Doelgroep ongewijzigd: meisjes 6–9, groep 3–5 (curriculum en ontwerpvalkuilen: zie IDEAS.md). Techniek ongewijzigd: de bestaande vanilla-JS voxelmotor (demos/waggletail). Gegenereerd 2026-08-24 uit drie ontwerp-lenzen (architectuur, hotelwerk-games, gastenplezier-games), samengevat en ontdubbeld door de lead.

## 1. Kernidee: de wereld is het rekenblad

- Geen rekenkaartjes onder het diorama meer. Alles wat je aanraakt (bakjes, bedden, sleutels, munten, wijzers, dieren) ligt in de wereld. Technisch: de bestaande naamplaatjes-laag (DOM boven het canvas op schermX/schermY) wordt een hotspot-laag met knoppen en drop-targets; het huidige sleepmechanisme blijft ongewijzigd werken.
- Kamer-camera: nooit uitzoomen, wel verhuizen. Eén ruimte vult altijd het scherm (voxels blijven scherp); groei = meer ruimtes. Wisselen via deur/trap, een kamerbalk met "hier wacht iemand"-badges, of een 2D-plattegrond.
- Ruimtes: receptie, gang met kamers, keuken, tuin (het huidige erf, hergebruikt), later wasserij, spelzaal, spa, feestzaal, verdieping 2.

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
11. **Rijtjes in de moestuin** — zaadjes in rijen × kolommen, twee vormen voor hetzelfde getal, rest in het kweekpotje. (Overlapt met Bedden op rij; zie §6.)
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

1. **Fundament** — rooms.js (ruimtes als data, deurgraaf met BFS), kamer-camera, hotspot-laag + hit-test, receptie met bel en check-in, bedden als limiet, save-formaat v6 met migratie van v5, dieren buiten beeld grof gesimuleerd. Voerkar en rekening-bij-uitchecken als eerste twee in-world taken.
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
