# De Rekenwacht — rekenen gaat voor

Voor ouders en de eigenaar: hoe het Dierenhotel ervoor zorgt dat een kind niet lang kan spelen
zonder te rekenen, en wat er per spelletje als rekenen telt.  Stand: `main` op `c72edf8`
(2026-10-09).

De wens van de eigenaar (2026-10-09, letterlijk):

> "Zorg wel dat rekenen altijd een prioriteit wordt en dat kinderen niet lang kunnen spelen
> zonder te rekenen. Minigames mogen een klein extra spel element hebben maar het moet niet
> mogelijk zijn om rekenen over te slaan en rekenen moet minstens 50% van de interactie zijn."

Er zijn twee lagen: de **Rekenwacht** voor het hele hotel (rondlopen, deuren, trappen, bladen,
de winkelstraat bekijken) en **per spelletje** de regel dat rekenen het grootste deel van de
beurt is en niet over te slaan valt.

## 1. Wat het kind merkt

- **Vrij rondkijken mag, maar niet eindeloos.**  Elk kind begint met **12 vrije tikken**:
  een deur, een trap, een kamerchip, een wolkje, het meubelboek openslaan.  Elk goed antwoord
  verdient vrije tikken terug.
- **Is het tegoed op, dan is er een rekenmoment** (buiten een spelletje; in een rekenspel
  speelt het kind gewoon verder, zie §2 regel 4).  Wat geen rekenen is, doet dan niets: de
  knop schudt even en een doorkijkwolkje zegt **"➕ Eerst even rekenen!"** (4 seconden, zodat
  een kind van zes het kan lezen).  De kamerbalk en de deur- en trapbordjes worden bleker.
  Onderin het beeld staat één grote, zacht kloppende knop **"➕ Rekenen"**, in elke kamer en op
  elk scherm op dezelfde plek.
- **Die knop leidt altijd naar een som**, nooit naar een doodlopend pad.  Hij kiest, in deze
  volgorde:
  1. de bovenste rekenkaart van het prikbord;
  2. een gast die aan de balie wacht (inchecken of de rekening);
  3. een rekenspel dat in deze kamer staat;
  4. anders **de snelle som**: er liggen koekjes op de vloer en de kaart vraagt
     **"🍪 Hoeveel koekjes zie je?"** (groep 3: 3 tot 7 koekjes, groep 4: 5 tot 10,
     groep 5: 8 tot 12).  Goed: **"Goed geteld! 🎉"**, en de koekjes gaan weg.
- **Na het goede antwoord** is het rekenmoment voorbij (zodra er weer tegoed is) en mag het kind
  verder rondkijken.
- **Ook met tegoed over:** wie 3 minuten actief speelt (het hotel in beeld en een tik in de
  laatste 20 seconden) zonder één goed antwoord, krijgt ook een rekenmoment.
- **Er wordt nooit iets afgepakt.**  Geen ster, munt of stuk weg, niets roods, geen klok in
  beeld.  Een geweigerde tik doet gewoon niets.
- **Tijdens een rekenmoment mag altijd:** de knop ➕ Rekenen; een som beantwoorden; alles wat
  rechtstreeks naar rekenen leidt (de ingang van een rekenspel, de bel, het prikbord en de
  rekenkaarten erop, 's avonds de familie aan de balie en de lamp als er iemand uitcheckt, de
  knoppen van de rekening); de spelbalk (⬅ Terug, het dier kiezen); de knoppen van een blad
  (een blad dichtdoen); het geluid aan of uit.
- **Tijdens een rekenmoment mag niet:** deuren, trappen, kamerchips, kamers op de plattegrond,
  💰 💌 🏨, 🌙 zonder iemand die uitcheckt, "Morgen ▸", wenswolkjes, 👀 Volg, bakjes, de
  speelmand, de 🧶-kaart op het prikbord en de ingang van de paskamer.
- **"🐾 Vrij spelen"** is alleen de naam van het dagdeel boven in beeld, geen uitweg: daar
  geldt hetzelfde tegoed.
- **Herladen helpt niet.**  Het tegoed, de klok en een lopend rekenmoment staan in een eigen
  bestand naast de hotels (`user://dierenhotel-reken.json`).  Herladen, een ander hotel of een
  nieuw hotel zetten niets terug.

## 2. De regels

1. **Tegoed.**  Het tegoed begint op 12 en kan nooit boven 12 komen.  Elke vrije tik
   ("spel") kost één.  Een goed antwoord betaalt de rekentikken terug die het kostte sinds het
   vorige goede antwoord, **foute pogingen meegeteld**, tot ten hoogste 12.
2. **Rekenen ≥ 50 % op de lange duur.**  Uit regel 1 volgt: zolang vrij spelen mag, is het
   aantal vrije tikken nooit meer dan het aantal rekentikken + 12.  Over duizend tikken is
   rekenen dus minstens de helft, op hooguit 0,6 procentpunt na (dat zijn de eerste 12 vrije
   tikken).  De test speelt
   twee kinderen van elk 1000 tikken (een gretig kind en een willekeurig kind) en toetst dat
   na elke vrije tik.  Na de eerste 12 vrije tikken is het ritme 1 : 1: één som koopt
   evenveel vrije tikken als hij rekentikken kostte.
3. **Klok.**  180 seconden actief spelen zonder goed antwoord opent ook een rekenmoment
   (net als een leeg tegoed: alleen buiten een lopend spel).
4. **In een rekenspel wordt nooit geweigerd.**  Daar telt elke tik mee (het tegoed mag even
   onder nul) en wordt hij terugbetaald door de sommen van dat spel.  Alleen een klein extra
   spelelement dat het spel als vrij heeft gemarkeerd (bijvoorbeeld 🔁 nog eens luisteren bij
   de band, een meubel draaien of oppakken) wacht als het tegoed op is.
5. **Per spelletje** (elke beurt, groep 3, 4 en 5, 1 tot 8 gasten): **minstens één rekentik
   meer dan andere tikken**, de tik die het spel opende niet meegeteld.  Met die tik erbij is
   rekenen dus nog steeds minstens de helft.  Als rekenen telt: een antwoord op een somstrook,
   en het zelf bouwen of neerleggen van een hoeveelheid die daarna wordt nagekeken (munten op
   de toonbank, gewichten op de weegschaal, sop in de tobbes, een sleutel aan het goede haakje).
6. **Niets is over te slaan** (zie §4).

De knop ➕ Rekenen zelf telt niet mee (anders bracht het eerste goede antwoord het tegoed
alleen terug op nul).  Een geweigerde tik telt ook niet mee.

## 3. Wat er per spel als rekenen telt

Per beurt, zonder fouten, na de tik die het spel opende.  Elke fout telt er één rekentik bij.

| spel | rekenen | ander (telt als spel) | per beurt rekenen / ander |
|---|---|---|---|
| inchecken (balie) | de som ("6 + 2 ="), "📦 In de kast: … Genoeg?", de beddensom | de kamer kiezen | 3 / 1 |
| bedden | de beddensom (slapers + 1) | — (de kamer is de opening) | 1 / 0 |
| rekening (uitchecken) | de som, elke munt op de toonbank, het wisselgeld | ✔ afrekenen (en de avondlamp) | 3–7 / 1 |
| speelmand | "Hoeveel balletjes samen?" | — | 1 / 0 |
| bakje (eten) | — (geeft geen ster meer; het voer is betaald door de voerkar) | — | niets te verdienen |
| sleutels | per sleutel: het getal kiezen + hem aan een leeg haakje hangen | een bordje laten voorlezen, de sleutel aantikken | 2 per sleutel / 0 |
| wekker | uur erbij / eraf, kwartier, 5 minuten, ✅ (groep 5 ook de uurvraag) | — | alles rekenen |
| meubelboek | kassa (munten tellen), som (2 stuks), "Is dat genoeg?", elke munt, wisselgeld (groep 4/5), "Hoeveel houd je over?" | tab, kiezen, ✨ neerzetten; 📦 Oppakken, 🔄 Draaien, « munt terug, ▸ Meer | 2–8 / 1–5 |
| tobbe | de openingssom, het sop verdelen (nagekeken) | het rek (handmaat), 🔄 opnieuw | 1 + verdelen / 0 |
| voerkar | "Hoeveel koekjes gaan op de kar?", per bakje de som | — (de kar rijdt zelf) | 1 + bakjes / 0 |
| zwembad | 1–2 antwoorden op de strook | — | 1–2 / 0 |
| hinkel | de sprongmaat (één maat past níet), het aantal sprongen | — | 2 / 0 |
| was | groep 3: 1 vraag, groep 4: 2, groep 5: 3 | — (de berg sorteert zichzelf) | 1–3 / 0 |
| oogst | 2 antwoorden | — (de gast plukt zelf) | 2 / 0 |
| weeg | de som, dan zelf het gewicht leggen (elk gewicht) | — | 1 + gewichten / 0 |
| spiegel | de som, elke kleur bij een stip | — | 1 + stippen / 0 |
| hoeden, sjaals, souvenirs | groep 3/4: betalen + "Hoeveel over?"; groep 5: halve prijs + wisselgeld | het ding kiezen | 2 / 1 |
| schoenen | de som (poten × prijs), betalen of wisselgeld | het ding kiezen | 2 / 1 |
| luxe | de som (met doosje), betalen of wisselgeld; groep 5: half, som, wisselgeld | het ding kiezen | 2 / 1, groep 5 3 / 1 |
| fotohokje | na elk dier "Hoeveel kost de foto nu?", daarna "Welk geld gooi je erin?" | de dieren kiezen (het eerste stapt zelf in) | 2 / 1, 3 / 2, 4 / 3 |
| koekjes | de som | — | 1 / 0 |
| band | het antwoord | 🔁 nog eens luisteren (de eerste herhaling speelt vanzelf) | 1 / 0 |
| sterren | het antwoord | — | 1 / 0 |
| post | per brief het goede vakje | — | aantal brieven / 0 |
| paskamer | — (vrij spel, zie §5) | alles | 0 / alles |

Bronnen per spel (voor/na-tabellen, testnamen): `.fanout/scratch/burn/GA.md` (winkels, foto,
paskamer), `GB.md` (was, oogst, weeg, spiegel), `GC.md` (meubelboek), `GD.md` (voerkar, tobbe,
hinkel, zwembad), `GE.md` (wekker, sleutels, bedden, band, koekjes, sterren, post), `GF.md`
(inchecken, rekening, speelmand, bakje).

## 4. Wat nooit kan

- **Een gemiste vraag overslaan.**  Een vraag waarop al een fout antwoord kwam, komt
  **onveranderd** terug (dezelfde som, dezelfde vier knoppen in dezelfde volgorde) na
  ⬅ Terug, een andere taakkaart, een ander dier op de spelbalk, herladen, een nieuwe dag, een
  gast erbij of een andere groep.
- **Na een fout iets makkelijkers kiezen.**  Geen goedkoper ding in de winkel of het
  meubelboek (📖 Boek verdwijnt na een fout), geen legere kamer bij het inchecken.
- **Een fout antwoord laten doorgaan.**  Het zwembaddier zwemt niet bij een fout getal, de
  hinkelaar springt niet, de voerkar rijdt niet.  Het dier van de beurt is teleurgesteld
  (`🔄 Nog een keer`), en in de winkels en het fotohokje gaat het dier de winkel uit; tik de
  winkel opnieuw aan voor dezelfde vraag.
- **Een beloning zonder rekenen.**  Geen ster, munt, kledingstuk, bed, meubel, versiering,
  foto, vervulde wens of afgevinkt taakje zonder eerst een goed antwoord.  (Het bakje en de
  speelmand gaven tot 2026-10-09 een ster zonder som; de speelmand vraagt nu een som, het bakje
  geeft niets meer.)
- **Hulp na een fout.**  Geen hulpregel, geen spookmunten, geen "nog te licht", geen
  kraantje dat voor het kind halveert.  Dat gold al (eigenaar 2026-09-24: "Nee geef geen hulp
  na fouten"); de rekening hielp nog wel en doet dat nu ook niet meer.

## 5. Besluit: de paskamer blijft vrij spel (terug te draaien)

De paskamer heeft geen som: het kind trekt zijn dier aan met wat het in de winkels heeft
gekocht.  Dat blijft zo, **onder het tegoed van de Rekenwacht**: de paskamer is gemarkeerd als
vrij spel, dus tijdens een rekenmoment gaat ze niet open, en een paskamer die openstaat sluit
zodra het tegoed op is.  Ze geeft niets wat niet al met rekenen betaald is (geen ster; alleen
stukken die met goede antwoorden zijn gekocht).

Waarom: een beurt in de paskamer is een paar tikken op kledingstukken.  Om daar per beurt
rekenen ≥ 50 % van te maken zouden er per verkleedronde minstens twee sommen in de spiegel
moeten komen, en de waarde van een hele outfit (tot €45) gaat boven wat groep 3 kan.

**Het alternatief** (niet gebouwd): in groep 4 en 5 per verandering één vraag
**"🪞 Wat kost alles samen?"**.  Zeg het als je dat liever hebt.

## 6. Het teken op de knop: ➕ in plaats van 🧮

Het ontwerp vroeg om een telraam 🧮 op de knop.  Dat teken zit niet in de lettersubset die het
spel meeneemt (`fonts/Emoji.ttf`), en een teken dat er niet in zit wordt niet getekend.  Daarom
draagt de knop **➕**, dat er wel in zit.  Terugzetten naar 🧮: `UiTekst.REKEN_ICOON` aanpassen
(`godot/dierenhotel/ui/teksten.gd`), `1F9EE` toevoegen aan `godot/dierenhotel/fonts/tekens.txt`
en `fonts/maak-fonts.sh` opnieuw draaien.

## 7. Voor wie verder bouwt

- Code: `godot/dierenhotel/autoload/reken.gd` (de autoload `Reken`); teksten `REKEN_*` in
  `godot/dierenhotel/ui/teksten.gd`; tests `godot/dierenhotel/tests/test_reken.gd` en per spel
  `test_rekenaandeel` in het eigen testbestand.
- Hoe een spel meedoet: `AGENTS.md` §5 (de regels R1–R4) en
  `.fanout/scratch/burn/golf2-regels.md`.
- Wat nog open staat: `PLAN.md` §7, de regel van 2026-10-09 (de lijst **OPEN**).
