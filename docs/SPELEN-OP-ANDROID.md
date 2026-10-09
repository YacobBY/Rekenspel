# Spelen op Android

Voor ouders: hoe je het Dierenhotel op een Android-telefoon of -tablet speelt.  Het hotel is
een gewone webpagina; er zit niets in dat alleen op een iPad werkt (eigenaar, 2026-10-09:
*"Het moet in browser werken ook op Android niet IOS specifiek."*).

> **Let op (stand 2026-10-09).** Wat hieronder staat, zit in de commit `9d9c957` op `main`.
> Die is nog niet gepusht.  De site op internet draait nog de versie van 1 oktober, zonder
> deze verbeteringen, tot de eigenaar pusht.

## Openen

Open in **Chrome** op de telefoon of tablet het adres van het Dierenhotel.  De eerste keer
laden duurt even (ongeveer 13 MB over de lijn; op 4G gemeten: ongeveer 30 seconden tot je kunt
spelen).  Daarna gaat het veel sneller, want dan komt alles uit de opslag van de browser.

## Op het beginscherm zetten

Tik in Chrome op het menu (⋮) en kies **App installeren** of **Toevoegen aan startscherm**.
Het hotel krijgt dan een eigen icoon met de bel en de pootafdruk, opent zonder adresbalk en
draait mee als je de tablet kantelt.

## Zonder internet

Speel het hotel één keer met internet.  Daarna start het ook zonder internet.  Zie je
"📶 Even geen internet", dan was het hotel nog niet helemaal binnen: probeer het opnieuw met
internet.

Het hotel (de dieren, de munten, de sterren) wordt in de browser op het toestel bewaard.
Chrome bewaart het extra goed als het hotel op het beginscherm staat.  Een reservekopie maak je
met **💾 Bewaar** op het startblad; met **📂 Open** zet je hem terug.

## De terugknop

De terugknop of terugveeg van Android doet hetzelfde als **⬅ Terug** in het spel:

- een open blad (bijvoorbeeld de kassa of het meubelboek) gaat dicht;
- een spelletje stopt, en je staat weer in het hotel;
- in het hotel zelf gebeurt er niets: het spel sluit dus niet per ongeluk.

Twee uitzonderingen beslist de browser zelf: vlak na het openen, vóór de eerste tik, gaat
terug wél de pagina uit (er is dan nog niets te verliezen); en wie heel vaak achter elkaar op
terug drukt zonder tussendoor iets aan te tikken, komt ook buiten de pagina.

## Scherm en geluid

- Zolang er een som of spelletje open staat, houdt het hotel het scherm aan (als de browser dat
  toestaat).
- Het geluid gaat aan na de eerste tik en zwijgt als je naar een andere app gaat.  Kom je terug,
  dan speelt het weer.
- Knijpen, dubbeltikken en lang drukken doen op het speelveld niets: er zoomt niets in en er
  springt geen menu open.  Naar beneden trekken ververst de pagina niet.
- Kantelen mag altijd: rechtop en liggend passen allebei.

## Werkt het niet?

- **"🙈 Dit scherm kan het hotel niet tonen"**: de browser mist WebGL 2.  Open het hotel in
  Chrome, of werk de browser bij.
- **"😴 Het hotel viel even in slaap"**: tik op **▶ Verder spelen**.  Het hotel gaat verder waar
  het bewaard was.
- **"📶 Het hotel laadt niet"**: de download is mislukt of stokt.  Controleer het internet en
  probeer het opnieuw.

## Wat er getest is

Getest in **Chromium 148 met Android-emulatie** (Playwright, echte aanraking, Android-Chrome als
browsernaam), op vijf toestelmaten:

| profiel | scherm | soort |
|---|---|---|
| `pixel7` | 412 × 915, rechtop | telefoon |
| `pixel7-land` | 915 × 412, liggend | telefoon |
| `galaxy-a` | 360 × 800, rechtop | kleine telefoon |
| `galaxy-tab` | 1280 × 800, liggend | tablet |
| `galaxy-tab-staand` | 800 × 1280, rechtop | tablet |

Daarin is nagegaan:

- **openen en spelen**: het startblad en de eerste inchecksom passen op 360 px breed; de
  wekker op de tablet en het sleutelbord op een liggende telefoon zijn gespeeld;
- **terug**: kassa open → terug sluit hem; sleutelbord → terug stopt het spel; drie keer terug
  zonder iets open → er gebeurt niets en de pagina blijft;
- **herladen**: de pagina opnieuw geladen → het bewaarde hotel komt terug, en het geluid
  staat nog uit als het kind 🔇 had gekozen;
- **draaien**: rechtop → liggend → rechtop; daarbij is een fout gevonden en hersteld (na het
  terugdraaien bleef de brede indeling staan en viel de rechterhelft weg);
- **geluid**: aan na de eerste tik, stil als de pagina verborgen is, weer aan bij terugkomst
  (het verbergen is nagebootst);
- **foutmeldingen**: geen WebGL 2, WebGL-contextverlies, mislukte download en de offlinepagina
  — elk met een Nederlandse melding in plaats van een Engels venster;
- **installeerbaar**: Chrome meldt geen bezwaren tegen het manifest (eigen naam, kleuren,
  iconen die de Android-launcher zelf rond of vierkant kan snijden);
- **veilige randen** (gebarenbalk, notch): nagebootst; de knoppen schuiven naar binnen.

## Wat er níet getest is

- **Een echt Android-toestel.**  Alles hierboven is emulatie op een computer.  Niet na te gaan
  zonder toestel: de echte terugknop via Chrome zelf (de browserregel die een terugstap kan
  overslaan), echte app-wissels en een scherm op slot, de beeldsnelheid van een echte
  telefoon-GPU, warmte en geheugendruk.
- **Firefox** (ook Firefox voor Android) en **Samsung Internet**: niet getest; de Firefox-versie
  voor de testtool is niet geïnstalleerd.
- **Installeren** zelf: het icoon in de launcher, het venster zonder adresbalk en de themakleur
  zijn niet op een toestel gezien.
- **Het scherm aanhouden** (Wake Lock) en **extra goed bewaren** (`storage.persist()`): de
  testbrowser weigert allebei, dus alleen de code is er, het effect is niet gezien.

Technische details, metingen en de screenshots: `.fanout/scratch/burn/W2-web.md`.
