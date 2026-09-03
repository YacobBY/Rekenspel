# Dierenhotel — specificaties nieuwe minigames (run dierenhotel-slaap-zwembad-kamers, 2026-09-03)

Geschreven door de lead als gedeelde bron voor de tickets P1 (voorbereiding) en G1–G5 (games). Alle games volgen HOTEL.md §3 (T = k·N + r per band), §9 (rekenen in de wereld, één zin ≤ 8 woorden/≤ 40 tekens boven de som, keuzes als icoon+woord-knoppen in één strook, nooit straffend) en GAMES-API.md. Bandgrenzen: groep 3 getallen ≤ 20 (liefst ≤ 10), groep 4 ≤ 100 en alleen tafels 1–5 en 10, groep 5 ≤ 100, geld ≤ €20, hele euro's. Geen timers, geen rood kruis, dieren nooit boos of ziek. Elke game: eigen bestand games/<id>.js, registratie via Games.register, eigen save-lade via ctx.data(), eigen Playwright-suite .fanout/scratch/dierenhotel/<id>/spel.js (port + land) en een regel in alles.sh.

## G1 Zwembad (`zwembad`, kamer `zwembad`) — ontwerp van de gebruiker

- Wereld: langwerpig bad langs de x-as met meterstrepen op de rand (0, 5, 10, … of 0, 10, 20, … afhankelijk van L) en een vlag/lijn bij de overkant op L meter. De badlengte L wisselt per beurt (de vlag verschuift; het voxelbad zelf blijft even groot en L wordt geschaald op de badlengte in voxels).
- Beurt: een gast met wens 🏊 zwemmen staat op de startrand (positie p = 0). Kaart aan het dier: "🏊 Het bad is 43 meter lang" + tweede regel "Max 30 meter per keer" → som "43 − 0" niet tonen; wel "nog 43 m". Vier keuzeknoppen met afstanden in meters (bijv. "🏊 30 m", "🏊 43 m", "🏊 13 m", "🏊 20 m"). Kind kiest; het dier zwemt precies dat aantal meters (1 m per slag, zichtbaar als slagen/plonsjes), een getaltag op het dier toont de nieuwe positie ("30 m").
- Regels: per keuze maximaal M meter (M per band). Als r = L − p ≤ M is de juiste keuze r; als r > M is de juiste keuze M ("zo ver als kan"). Te kort (keuze < juiste): het dier zwemt gewoon zo ver en stopt; nieuwe kaart "🏊 Boef is bij 30 meter" / "Nog hoeveel meter?" met som "43 − 30 =" en vier nieuwe keuzes. Te ver (keuze > r): het dier zwemt tot de wand, botst: korte "Au!"-wolk, wrijft even over zijn hoofd (≤ 1,5 s), daarna gewoon blij aan de overkant; geen ster minder, geen rood, geen herhaling van de beurt. Precies: "✅ Precies aan de overkant!" + 🏊 wens af.
- Getallen per band: groep 3: L ≤ 20, M = 10, afstanden hele meters, keuzes ≤ 20. Groep 4: L 21–50, M = 30 (voorbeeld gebruiker: 43 m bad, 30 max, dan 13). Groep 5: L 31–100, M = 30 of 40, met restanten die over een tiental heen gaan (bijv. 76 − 40 = 36). Afleiders: r ± 1..3, r + 10, L zelf, M zelf; nooit negatief, nooit twee keer hetzelfde getal, altijd precies één juiste keuze.
- Aantal beurten per taak: één lengte per gast met de wens; taakchip "🏊 Zwemles" als er een gast met 🏊 is. Ster bij afronden hoe dan ook.
- Vereist van P1: kamer `zwembad`, wens 🏊 (BEHOEFTE/WENSWOORD/plekVanBehoefte/behoefteKlaar/morgen), zwempose + zwem-animatie met voltooiingscallback, modelhook voor badrand/vlag/strepen.

## G2 Wekkerdienst (`wekker`, kamer `gang`)

- Wereld: grote halklok aan de gangmuur (voxelmodel met wijzerplaat en twee wijzers die echt draaien). Onder de klok een kaart.
- Beurt: gast met wekkerkaartje (nieuwe wens ⏰ wekken, of taakchip "⏰ Wekker zetten" die N gasten langsgaat). Kaart: "⏰ Boef wil om 7 uur op" / "Zet de klok" met sombalk "nu: 5 uur". Knoppen: "🕐 uur erbij", "🕒 kwartier erbij" (band ≥ 4), "🕧 5 minuten erbij" (band 5), "✅ Klaar". Elke tik draait de wijzers zichtbaar. Klaar met de juiste tijd: klok rinkelt zacht, gast wordt wakker (pose blij, ☀-wolkje), wens af. Klaar met verkeerde tijd: gast blijft slapen, kaart zegt "⏰ De klok staat op 6 uur" / "Boef wil 7 uur" en de wijzers blijven staan zodat je verder kunt draaien; nooit terugzetten nodig (uur erbij draait door na 12).
- Varianten per band: groep 3 hele uren (doel 1–12); groep 4 halve uren en kwartieren ("half 8", "kwart over 7", uitgeschreven in de zin); groep 5 bovendien tijdsduur: "Boef slaapt nog 2 uur, het is 7 uur" / "Hoe laat is hij wakker?" met vier keuzes ("🕘 9 uur" enz.).
- Getallen: gebruik sommen.klok uit state.js waar het past (niet wijzigen); anders afleiden uit band/N.
- Vereist van P1: modelhook (klok), wens ⏰ of alleen taakchip (lead-keuze: alleen taakchip + wekkerkaartje boven het slapende dier; geen nieuwe wens nodig), wijzerdraai via eigen model-render (model hook moet een parameter kunnen meenemen, bijv. model('klok', {uur, min})).

## G3 Hinkelpad (`hinkel`, kamer `tuin`, zone langs de achterrand)

- Wereld: rij stapstenen als getallenlijn van 0 tot E met een cijfer op elke steen (getalTag) en een trapje bij het doel. Zone: achterste rand van de tuin (P1 reserveert x-bereik en z-bereik), buiten de souvenirkraam-zone.
- Beurt: gast met wens 🧶 spelen (bestaand) of taakchip "🪨 Hinkelen". Gast staat op steen s. Kaart: "🐇 Boef staat op 40, trap bij 70" / "Kies je sprong" met keuzestrook van sprongkeitjes "🪨 sprong 2", "🪨 sprong 5", "🪨 sprong 10" (band-afhankelijk). Daarna cijferpad op de kaart: "Hoeveel sprongen?" (som "40 + ? × 10 = 70" niet zo tonen; toon "van 40 naar 70"). Het dier hupt zichtbaar steen voor steen (arc-sprong), tellend ("1… 2… 3") met getaltag.
- Te kort: dier landt vóór de trap, kaart "🐇 Boef staat op 60" / "Nog even verder" en de beurt gaat door vanaf 60. Te ver: het dier landt voorbij de trap, "🐇 Oei, te ver!" en hupt zelf één steen terug naar de trap? Nee: het blijft staan en de kaart vraagt de rest terug ("van 80 naar 70": sprong achteruit). Precies: "✅ Precies op de trap!".
- Getallen per band: groep 3: E = 20, sprongen 1, 2, 5, stenen elke 1; groep 4: E = 100, stenen elke 5 met cijfers op de tientallen, sprongen 2, 5, 10, aantal sprongen ≤ 10; groep 5: E = 100, sprongen 2–10, start niet op een tiental (bijv. van 37 naar 77 met sprongen van 10).
- Vereist van P1: sprong-animatie met callback (stappen(id, punten, {pose:'spring'})), modelhook voor stenen en trap, zone-afspraak in de tuin.

## G4 Wasmandtoren (`was`, kamer `wasserij`)

- Wereld: berg wasgoed (bron-hotspot met teller) en 2–4 kratten tegen de muur, elk met een pictogram (🧦 sokken, 🧣 sjaals, 🧺 handdoeken, 🧸 knuffels). Elk item dat in een krat gaat, wordt een blokje in een stapel: de kratten worden een echt staafdiagram.
- Beurt: taakchip "🧺 Was sorteren" (altijd beschikbaar, prio laag) of wens 🛁 bad-variant niet gebruiken. Kind tikt een item op de berg (het toont zijn soort) en dan een krat; goed → blokje erop; verkeerd → zachte bounce, item terug op de berg, geen tekst. Als de berg leeg is: vraagkaart bij de kratten. Groep 3: "📊 Welke stapel is het hoogst?" met keuzes (de soorten). Groep 4: "📊 Hoeveel meer sokken dan sjaals?" met som "7 − 4 =" en cijferpad; daarna "Hoeveel stuks samen?". Groep 5: legenda "Elk blokje is 2 stuks" (items komen als paren op de berg), vragen "Hoeveel sokken?" (blokjes × 2) en het verschil.
- Getallen: totaal T = k·N + r ≤ 12 (groep 3, 2–3 soorten), ≤ 20 (groep 4, 3 soorten), ≤ 30 (groep 5, 4 soorten in paren dus ≤ 15 tikken). Stapels nooit even hoog bij "hoogst"-vraag.
- Vereist van P1: kamer `wasserij`, modelhook voor krat en blokjes (of gebruik getalTag + kleurblokken via model met parameter).

## G5 Souvenirkraam (`kraam`, kamer `tuin`, zone langs de zijrand)

- Wereld: kraampje met 3 uitgestalde spullen met prijskaartje (🎩 hoedje €4, 🧣 sjaaltje €3, ⚽ bal €5, band 5: 🎒 tas €12), toonbank, muntenbuidel van de gast (bron) zoals bij de rekening (econ.js) — hergebruik het muntensleep-mechanisme, niet kopiëren.
- Beurt: gast met nieuwe wens 🎁 souvenir loopt naar de kraam. Groep 3: "🎁 Boef wil het hoedje van €4" / "Leg de munten op de toonbank" → sleep €1/€2-munten tot precies €4 (teller op de toonbank). Groep 4: twee spullen: "🎁 Hoedje €4 en bal €5" / "Hoeveel euro samen?" som "4 + 5 =" cijferpad, daarna munten leggen. Groep 5: gast betaalt met €10 of €20: "👛 Boef gaf €10, het kost €7" / "Hoeveel krijgt hij terug?" som "€10 − €7 =" en wisselgeld uit de la. Te veel gelegd: "nog 1 terug", te weinig: "nog 2 erbij", nooit rood.
- Het gekochte blijft zichtbaar op het dier (hoedje op het hoofd, sjaaltje om de nek, bal ernaast) tot uitchecken; opgeslagen in de gastdata.
- Vereist van P1: wens 🎁, modelhook voor kraam en spullen, accessoire-haak op het dier (art.js: draw-hook per dier voor `g.accessoires`), Econ-primitief voor munten leggen als het nu in econ.js verweven zit (GAMES-API §7 noemt generieke Econ.betaal als uitgesteld: P1 levert die).

## Gedeelde eisen voor alle vijf

- Portret 420×860 en landschap 860×420 plus 360×740 en 320×640: kaart nooit over de eigen gast, hotspots ≥ 48 px, hotspotlimiet 16 per laag respecteren.
- Frozen math onaangeroerd; nieuwe generatoren alleen binnen het eigen gamebestand, afgeleid van N en band.
- Console foutvrij; herladen midden in een beurt herstelt de beurt uit ctx.data().
- Suite: minstens 25 assertions per game, alle banden (3, 4, 5) en beide oriëntaties, plus screenshots <id>-port-*.png en <id>-land-*.png.
