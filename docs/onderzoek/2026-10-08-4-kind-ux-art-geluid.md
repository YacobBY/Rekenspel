# Onderzoek 4: kind-UX, beeld, geluid en techniek op de tablet

*Dierenhotel Kwispelsteeg, 2026-10-08. Bureauonderzoek (web) plus een korte blik in de code om de adviezen op onze
eigen maten te zetten. Haast? Lees eerst §9 "Top 10 ideeën".*

**Hoe te lezen.** Elk hoofdstuk heeft eerst "Wat bronnen zeggen" en daarna een blok **Wat betekent dit voor ons spel**.
Achter een bewering staat de bron als [Sn] (zie §10). **[onbevestigd]** = alleen uit een zoekmachine-samenvatting of
uit eigen kennis, niet zelf in de bron nagelezen. **[eigen voorstel]** = mijn advies, geen onderzoeksuitkomst.
Aan het eind van de ronde was het zoekbudget op; twee vragen (Switch Control op iPad, AccessKit op het web) konden
daardoor niet verder worden uitgezocht.

**Belangrijk voor alle maten hieronder.** In ons spel is één eenheid één CSS-pixel (`scenes/main.gd::_op_venster` zet
`content_scale_size` = venster / devicePixelRatio). De "1024×768-basis" uit `project.godot` is dus alleen de
editormaat; op een iPad rekent het spel in CSS-px (= iOS-punten), op Android in dp. Omrekening (fabrieksgegevens,
**[onbevestigd]**, niet in deze ronde nagekeken):

| toestel (CSS-maat liggend) | mm per px | 9 mm | 10 mm | 12,7 mm | 15 mm | 20 mm |
|---|---|---|---|---|---|---|
| iPad 10,2"/10,9"/11"/13" (264 ppi, ×2; bv. 1180×820) | 0,192 | 47 px | 52 px | 66 px | 78 px | 104 px |
| iPad mini 6/7 (326 ppi, ×2; 1133×744) | 0,156 | 58 px | 64 px | 81 px | 96 px | 128 px |
| Android-telefoon 360×740 (bv. 570 ppi, ×4) | 0,178 | 51 px | 56 px | 71 px | 84 px | 112 px |

---

## 1. Aanraken: knoppen, tikken en vingers

### Wat bronnen zeggen

- **Kinderen missen kleine doelen veel vaker, niet minder.** Op een 4"-telefoon misten 7–10-jarigen gemiddeld 30 % van de "small" doelen (0,25" = 6,4 mm) bij de eerste poging; de allerkleinste (3,2 mm) ging ongeveer de helft mis. De auteurs hadden het omgekeerde verwacht: "the younger the child, the larger the targets are actually necessary to be" [S1]. Een latere studie citeert dat zelfs Androids 9 mm tot 17 jaar één op de zes keer gemist wordt [S4].
- **"Holdovers": de tweede tik op de plek van de vorige knop.** Als het scherm na een tik verandert, tikt een kind nog eens op dezelfde plek. Op de telefoon was dat 3,9 % van alle tikken bij 7–10-jarigen (81 % van alle holdovers kwam van kinderen) [S1]; op een tablet zelfs 9,9 %, omdat het nieuwe doel daar relatief kleiner is [S3]. Advies van de auteurs: negeer een tik op de plek van de net geactiveerde knop binnen een korte tijd, en reageer sneller [S1].
- **Lange en verschoven tikken.** Bij 89 kinderen van 3–6 hielden kinderen boven de 5 een gewone tik tot 1,5 s vast (3-jarigen tot 5,1 s); volwassenen gemiddeld 53 ms. De app moet dat gewoon als tik tellen [S4]. Kinderen "slepen" ook tijdens een tik zonder dat er iets beweegt: accepteer wat verschuiving [S3]. Het TIDRC-raamwerk vat het onderzoek samen als: accepteer tiktijden tot 5 s en afwijkingen tot 10 mm, en maak de actieve zone groter dan de knop [S2].
- **Afwijking in mm.** Kinderen van 3–6 tikten gemiddeld 3,3 mm naast het midden op een telefoon en 4,5 mm op een 10"-tablet [S4]. Vatavu gebruikte zelf 20 mm-doelen op de tablet met een tikzone van 23 mm [S4].
- **Plaats op het scherm.** Op een tablet (5–10 jaar) werd 50 % van de doelen bovenaan gemist tegen 38 % in het midden en onderaan, en links meer dan rechts (rechtshandige kinderen, tablet op tafel). Advies: zet knoppen dicht bij het kind [S3].
- **Meer vingers, handpalm.** Op de tablet gebruikte een kind in 17 % van de gevallen niet de wijsvinger en in 4,5 % meer vingers of beide handen. Twee-vingerslepen lukte maar 53,7 % (op de tablet 30,7 %) [S4]. TIDRC: laat één vinger en meer vingers hetzelfde doen [S2].
- **Dubbeltikken en slepen.** Een dubbeltik duurde ongeveer drie keer zo lang als een tik [S4]; TIDRC: geen dubbeltik voor kinderen tot 5, of een ruimere pauze [S2]. Precies slepen naar één plek is moeilijk voor kinderen; bied tikken naast slepen aan [S5]. Lange sleepafstanden op een tablet mislukten vaker (11,5 % tegen 4,2 % op de telefoon) [S4].
- **Maten.** Nielsen Norman Group adviseert voor jonge kinderen minstens 2 × 2 cm, vier keer de 1 × 1 cm voor volwassenen; een kruisje van 5 mm was te klein voor 7-jarigen [S5]. Volwassenenminima: Apple 44 × 44 pt [S8], Android 48 × 48 dp (≈ 9 mm) met ≥ 8 dp ertussen [S9], WCAG 2.5.5 (AAA) 44 × 44 CSS-px, "larger sizes are recommended" [S10]. TIDRC: genoeg ruimte tussen twee klikbare dingen [S2].
- **Wachten.** Kinderen willen directe beloning en haken af als iets niet werkt [S6]. Onder 0,1 s voelt een reactie direct, tot 1 s blijft de gedachte doorlopen [S7]. TIDRC: laat zien dat de app bezig is, geef grotere en langere visuele feedback [S2].
- **Liggend of rechtop op een telefoon.** Geen onderzoek gevonden dat dit voor 6-jarigen beslist.

**Zo staat het nu (uit de code).** Antwoordknop in de rekenbalk (onderin): tablet 64 px hoog en tot 150 px breed
(12,3 × 28,8 mm op een iPad, 10 mm hoog op een mini); telefoon rechtop 60 px hoog en (360 − 48)/4 = 78 px breed
(≈ 10,7 × 13,9 mm); telefoon liggend 60 × max 96 px. Tussenruimte in de strook 4–8 px (≈ 1–1,5 mm). Hotspots op
wereldobjecten minimaal 48 × 48 (`Hits`, ≈ 9,2 mm iPad, 7,5 mm mini). `touch-action: none` staat al in de HTML-shell.

> **Wat betekent dit voor ons spel**
> 1. **Antwoordstrook tablet:** `knop_hoog` 64 → **84 px** (16 mm iPad, 13 mm mini); zichtbare tussenruimte **12 px**, maar laat de tikzones tegen elkaar aan lopen (de tik in de tussenruimte gaat naar de dichtstbijzijnde knop) [S1, S2]. Breedte (≤ 150 px ≈ 29 mm) is al ruim.
> 2. **Telefoon rechtop (360×740):** vier naast elkaar kan niet breder dan ±78 px (14 mm); maak ze **72 px hoog** (12,8 mm) en laat ook hier de tikzones aansluiten. Een 💶-boven-getal-knop past dan: pictogram 20 px, getal 24 px, 6 px lucht. **Liggend:** 96 × 64 px (17 × 11 mm) is prima.
> 3. **Wereldknoppen (`Hits`):** zichtbaar 48 px mag, maar geef het vangvlak (`tik_vlak`) minimaal **64 × 64 px** (12 mm iPad) waar de 0 %-overlapregel dat toelaat [S2, S4].
> 4. **Holdoverfilter [eigen voorstel]:** als een strook verdwijnt en er binnen **350 ms** een nieuwe op dezelfde plek staat, negeer tikken in die tijd; elke knop daarna **400 ms** doof voor een tweede tik. Zo kan een dubbeltik op `trap_op_<kamer>` niet twee verdiepingen gaan en beantwoordt een dubbeltik niet meteen de volgende som [S1, S3].
> 5. **Lange tik en verschuiving:** een druk tot 2 s moet een gewone tik blijven (Godot `BaseButton` vuurt standaard bij loslaten, `action_mode` = release [S26]: goed). Godot telt loslaten buiten de knop niet; overweeg dat loslaten tot **±50 px** (≈ 10 mm) buiten de knop nog telt als de druk erbinnen begon [S2, S3]. `gui/common/drag_threshold` staat op 10 px [S27]; check dat de kamerbalk niet per ongeluk gaat scrollen bij een trillende vinger.
> 6. **Onderin = goed.** De rekenbalk zit al onderin. Zet bovenin alleen dingen voor ouders of die zelden nodig zijn (🏨 Hotels, 💾/📂); dat ze daar vaker gemist worden is daar zelfs handig [S3].
> 7. **Duim of handpalm op het scherm:** test of een knop nog reageert als een andere vinger al op het glas ligt. Godot maakt muisklikken van aanraking (`emulate_mouse_from_touch`, standaard aan [S27]); dat dit alleen de eerste vinger volgt is **[onbevestigd]**, maar het zou precies dit geval breken. Zie checklist §7.
> 8. **Feedback < 100 ms:** de knop zakt in en `tik()` klinkt bij het neerdrukken, ook als het echte gevolg (een dier dat loopt) langer duurt [S7].
> 9. **Liggend of rechtop:** beide blijven ondersteunen, niet dwingen. Liggend geeft bredere antwoordknoppen (96 tegen 78 px) [eigen voorstel]; laat twee kinderen beide proberen.

---

## 2. Spelen zonder lezen: pictogrammen, kleur en voorlezen

### Wat bronnen zeggen

- **Kinderen van 4–8 herkennen goede pictogrammen.** Twaalf kinderen kozen uit vier pictogrammen in 84 % van de gevallen een van de twee bedoelde (kans: 50 %); kleur of lijntekening maakte geen verschil (86 % tegen 81 %); de score steeg met de leeftijd en een paar pictogrammen ("arcade") werkten slecht. Pictogrammen moet je dus testen en bijschaven [S11].
- **Concreet wint van conventie.** Bij kleuters herkende 14 % de afspeeldriehoek niet als "spelen"; een concreet beeld werkte beter **[onbevestigd]** (Icon Design Principles for Preschoolers, via zoekresultaat). TIDRC: maak beelden consistent met de echte wereld en haal versiering weg uit symbolen [S2].
- **Emoji zijn dubbelzinnig.** Bij dezelfde emoji-tekening waren mensen het 25 % van de keren oneens of hij positief, neutraal of negatief was; tussen platforms (Apple, Google, Samsung) werd dat erger [S12, onbevestigd: alleen samenvatting gelezen]. Wij bundelen Noto Color Emoji: overal dezelfde tekening, dus het platformprobleem is weg; de dubbelzinnigheid van een emoji zelf blijft.
- **Pictogramsets en licenties.** ARASAAC: CC BY-NC-SA 4.0, niet-commercieel en "gelijk delen" **[onbevestigd]**; Sclera: CC BY-NC 2.0 BE, commercieel alleen met toestemming **[onbevestigd]**; OpenMoji: CC BY-SA 4.0 **[onbevestigd]**. Bliss is een abstracte symbooltaal voor ondersteunde communicatie; voor een spel te abstract [eigen oordeel].
- **Kleurenblindheid.** "One in twelve Caucasian (8%)" jongens is rood-groen kleurenblind; regel één: "Do not convey information in color only"; combineer kleur met vorm of label [S13]. Het Okabe-Ito-palet (populair gemaakt door Wong, 2011) is ontworpen om voor iedereen onderscheidbaar te blijven [S14]: oranje `#E69F00`, hemelsblauw `#56B4E9`, blauwgroen `#009E73`, geel `#F0E442`, blauw `#0072B2`, vermiljoen `#D55E00`, roodpaars `#CC79A7` **[hexwaarden onbevestigd: niet in een primaire bron nagelezen]**.
- **Voorlezen.** TIDRC: geef een optie om teksten voor te lezen; audio-aanwijzingen altijd met beeld, want jonge kinderen letten niet op audio alleen; zet het belangrijke woord aan het eind van de gesproken zin; gebruik liever geluid of beeld dan tekst als aanwijzing [S2]. Khan Academy Kids maakt elk tekstelement tikbaar om het te laten voorlezen en gebruikt een vrolijke "ding" bij goed en een zachte "bong" bij fout, "language agnostic" [S15].
- **Spraaksynthese (TTS) op het web.** Godot heeft `DisplayServer.tts_speak()`; het staat standaard uit (projectinstelling) en heeft vooral op Android en het web vertraging, omdat "some of the voices depend on web services" [S25]. Een stem met `localService = false` draait op een server, niet op het toestel [S28]. Op iOS zijn via de Web Speech API alleen vooraf geïnstalleerde stemmen beschikbaar, spreken werkt alleen na een tik, en de stemmenlijst is bij de eerste keer laden soms leeg (Godot-issue #103262) **[onbevestigd]**.
- **Wat Rekentuin doet.** Rekentuin geeft munten naar resterende tijd: snel goed levert veel op, snel fout kost veel ("High Speed High Stakes") [S30]. Een latere studie meldt dat scholen klaagden over die zware straf en dat er een vaste, kleine straf voor in de plaats kwam **[onbevestigd]**. Ons spel kiest bewust geen tijd en geen straf.

> **Wat betekent dit voor ons spel**
> 1. **Leg een pictogramwoordenboek vast** en gebruik het overal hetzelfde: 🔄 nog een keer (bestaat al), ⬅ terug, 🔊 luister, ✅ klaar. Eén betekenis per pictogram, nooit twee pictogrammen voor één handeling [S2].
> 2. **Pictogramtest [eigen voorstel, naar S11]:** laat 3 kinderen (6 en 8 jaar) bij elk nieuw pictogram zeggen "wat gebeurt er als je hierop tikt?". Onder 4 van 5 goed: tekening aanpassen.
> 3. **Kleur nooit alleen.** Bij `spiegel` ("welke van drie gekleurde tekens") en bij sorteren op kleur (`was`?) elk teken ook een eigen vorm geven (● ▲ ■) en Okabe-Ito-kleuren als accent gebruiken [S13, S14].
> 4. **🔊 op de kaart, als optie.** Een ouderinstelling "Voorlezen"; dan een 🔊-knop op elke somkaart die de `regel` via `tts_speak` met een `nl`-stem uitspreekt, alleen na een tik (iOS), nooit automatisch. Geen stem gevonden: knop verbergen. Onze zinnen zijn sjablonen met getallen en namen (`"%s gaf €%d, het kost €%d"`), dus een ingesproken stem vraagt losse fragmenten plus getallen 0–100: later, en alleen als TTS tegenvalt [S2, S15, S25].
> 5. **Privacy:** een kaartzin bevat geen gegevens van het kind (alleen diernamen en getallen); een externe stem is daarom privacy-arm, maar werkt niet offline. Kies een stem met `localService == true` als die er is [S28].

---

## 3. Isometrische voxelkunst leesbaar houden; "juice" en prikkels

### Wat bronnen zeggen

- **Leesbaarheid gaat voor sfeer.** Crossy Road draaide de camera omdat "voxels look better at an angle" en koos voor "really obvious hit boxes and sharp edges" [S16]. Monument Valley gebruikt kleur om te tonen waar je kunt handelen en hing alle schermen naast elkaar als "colour script" **[onbevestigd]**.
- **Voorgrond helderder dan achtergrond.** TIDRC: voorgrond duidelijker en gedetailleerder dan de achtergrond; geen drukke achtergronden; niet te veel kleuren en tinten; klikbare dingen zichtbaar anders, "e.g., use different colors or dark outlines" [S2]. Pixelpraktijk: eerst het silhouet, een donkere of "selectieve" omlijning, en de grijswaardetest (desatureer een schermafbeelding; vind je de figuur niet meteen, dan liggen de waarden te dicht bij elkaar) **[onbevestigd: alleen praktijkgidsen]**.
- **Contrast van knoppen.** WCAG 1.4.11: onderdelen van de interface en grafische delen die je nodig hebt om iets te snappen, minstens 3:1 tegen hun omgeving [S17].
- **Juice helpt de ervaring, maar versiering kan het leren schaden.** Extra, overbodige feedback ("juiciness") verbeterde in een experiment de spelerservaring [S18, onbevestigd: samenvatting]. Een meta-analyse vond dat "interessante maar irrelevante" details het leren schaden (g ≈ 0,33) [S19, onbevestigd: samenvatting].
- **Prikkelbelasting.** TIDRC: wees voorzichtig met geanimeerde hotspots en houd elk interactief element bij zijn doel, zonder extra animatie of geluid [S2]. Game Accessibility Guidelines: geen flikkerende beelden of herhaalde patronen, een optie om achtergrondbeweging te verbergen, geen plotselinge onverwachte gebeurtenissen [S20]. Een studie over apps voor autistische kinderen noemt overprikkeling als oorzaak van angst en afwijzing **[onbevestigd]**.
- **Flitsregel.** WCAG 2.3.1: niets mag vaker dan 3 keer per seconde flitsen, tenzij het onder de drempels blijft; de oppervlaktegrens is een rechthoek van 341 × 256 px bij 1024 × 768 (25 % van 10° gezichtsveld); verzadigd rood telt apart [S21]. `prefers-reduced-motion` is voor mensen met evenwichtsklachten en staat op iOS onder Instellingen > Toegankelijkheid > Beweging [S22].

**Zo staat het nu.** Tekstinkt `#4A3B33` op kaart `#FFFDF8`: **10,5:1** (goed). Knoprand `KNOP_RAND #E2BE8E` op
kaart: **1,72:1**, op achtergrond `#FFF4E8`: **1,61:1** (onder 3:1). Pastelvullingen als `MUNT #A7DEC6` (1,49:1) zijn
als vlak geen probleem, zolang de rand of het woord het contrast draagt. Reduced motion wordt al uit
`matchMedia('(prefers-reduced-motion: reduce)')` gelezen (`autoload/ui.gd`).

> **Wat betekent dit voor ons spel**
> 1. **Donkerdere knoprand:** `KNOP_RAND` → `#B07A3C` (**3,63:1** op `#FFFDF8`) of `#9C6B35` (4,24:1 op `#FFF4E8`); de pastelvulling blijft. Eén regel, groot effect op een iPad in fel licht [S17, S2].
> 2. **Grijswaardetest per kamer:** maak met `kiek.js` van elke kamer een plaatje, zet het op grijs en kijk of dieren, naamplaatjes en knoppen er meteen uit springen [eigen voorstel].
> 3. **Nacht (dakterras):** dieren en knoppen op een donkere lucht een lichte rand (1 px, warm, bv. `ZON #FFDD8C`) of een donkere omlijning geven; verlichte ramen warm en klein, nooit knipperend.
> 4. **Juicebudget [eigen voorstel, naar S2/S19]:** feest pas *na* het antwoord en ≤ 1 s (spetter, `ja()`, `dier_blij`); niets dat beweegt naast de kaart zolang een som open staat; nooit een schermbrede flits. Twinkelende sterren ≤ 2 Hz en samen kleiner dan 341 × 256 px [S21].
> 5. **Goedkoop leven [eigen voorstel]:** knipperen om de 3–6 s (willekeurig per dier), op-en-neer 1–2 px in ~2 s, staart kwispelen alleen als het dier blij is. Klein, langzaam, voorspelbaar.
> 6. **Ouderschakelaar "Rustig"** naast de systeeminstelling, zodat een ouder minder beweging kan kiezen zonder de iPad om te zetten [S20].

---

## 4. Geluid en muziek

### Wat bronnen zeggen

- **Elk geluid een betekenis.** TIDRC: "every sound used in the interface has a specific meaning and function"; gebruik geluid om aandacht te richten; bevestig geaccepteerde invoer met geluid; applaus of waardering na een taak; geen achtergrondmuziek bij video voor kinderen tot 5 [S2]. Khan Kids: "ding" en een zachte "bong" [S15].
- **Geluid alleen is te weinig.** Kinderen van 6–7 herkennen "auditieve iconen" minder goed dan 8–9-jarigen **[onbevestigd]**; Game Accessibility Guidelines: geef essentiële informatie nooit alleen via geluid, en bied aparte volumes voor effecten, spraak en muziek [S20].
- **Muziek en rekenen.** Kalmerende achtergrondmuziek verbeterde rekenen en geheugen bij 10–12-jarigen [S23]. Opwindende muziek schaadde geheugenwerk, en jongere kinderen zijn gevoeliger voor irrelevant geluid **[onbevestigd]**. Onze kinderen (6–9) zijn jonger dan in [S23]: voorzichtig zijn.
- **Trillen (haptiek).** De Vibration API werkt niet in Safari, ook niet op iOS; wel in Chrome op Android [S24]; hij vraagt een eerdere tik van de gebruiker [S29].
- **Gratis muziek, met licentie:**

| stuk | maker | licentie | wat | bron |
|---|---|---|---|---|
| Children's March Theme | Cleyton Kauffman | CC0 | 1:04, naadloze loop, WAV/OGG (MP3 heeft een gat) | [S31] |
| Happy Clappy Loop | OwlishMedia | CC0 | piano, vrolijk, naadloze loop, WAV 6,2 MB | [S32] |
| Music Jingles (85 stuks) | Kenney | CC0 | korte jingles, bv. voor "hoera" | [S33] |
| Feel Good Island Loop | AntumDeluge | CC0 of OGA-BY 3.0 | rustige tropische loop | [onbevestigd] |
| Flowerbed Fields [Loop] | Zane Little | CC0 | chiptune, vrolijk | [onbevestigd] |
| werk van Kevin MacLeod | incompetech | CC BY 4.0 | groot archief; naam + titel + licentie verplicht zichtbaar | [S34] |

**Zo staat het nu.** Alle geluiden worden procedureel als `AudioStreamWAV` (22 050 Hz) gemaakt; ieder speler +12 dB,
luidste piek ≈ −6 dBFS, sfeerloop ≈ −24 dBFS. Er is een mute (`Snd.dempt()`), geen aparte muziekregelaar.

> **Wat betekent dit voor ons spel**
> 1. **Procedureel blijft goed:** het werkt in Godots web-"Sample"-modus, omdat het geluid vooraf als buffer bestaat; alleen live genereren (`AudioStreamGenerator`) wordt daar niet ondersteund [S35].
> 2. **Muziek per kamer: ja, maar rustig en optioneel.** Eén zachte loop per kamer, **−18 dB onder de effecten**, en **gedempt (−12 dB extra) zolang een somkaart open staat**; geen muziek in winkels tijdens het afrekenen [S2, S23, eigen voorstel]. Begin met Children's March (CC0) of Happy Clappy (CC0) om te proeven.
> 3. **Geheugen [afgeleid]:** Web Audio bewaart een buffer als 32-bit float; 60 s stereo 44,1 kHz is dan ±21 MB in het geheugen. Maak loops **mono, 22,05 kHz, ≤ 40 s** (±3,5 MB) en laad alleen de kamer die in beeld is.
> 4. **Misgeluid:** `Snd.dier_sip` is goed (een teleurgesteld dier, geen zoemer); houd het korter (< 0,5 s) en zachter dan `ja()`. Geen geluid bij een tik op een vergrendelde strook (zo is het nu: goed) [S15].
> 5. **Twee schuiven in het ouderblad:** 🎵 Muziek en 🔔 Geluiden, onthouden in de save [S20].
> 6. **Trillen:** alleen Android, 10–20 ms bij goed, standaard uit; nooit bij fout [S24, eigen voorstel].
> 7. **Credits:** CC0 hoeft niet, maar noem maker en titel in een ouderblad "Over"; voor MacLeod is dat verplicht [S34].

---

## 5. Techniek: het spel uitbrengen op iPads en Android-tablets

### Wat bronnen zeggen

- **WebGL2 en threads.** Godot 4 kan op het web alleen WebGL 2.0 (Compatibility); de documentatie waarschuwt dat Safari extra WebGL2-problemen heeft [S35]. Sinds 4.3 is een export zonder threads standaard; "The single-threaded export works very well on macOS and iOS too". COOP/COEP-headers (`SharedArrayBuffer`) zijn alleen nodig met threads [S35, S36].
- **Geluid op iOS.** Godot 4.4.1 tot 4.5-dev crashte op iOS na 1–3 minuten geluid (#107390) [S37]; opgelost in 4.5 met PR #107948: WebKit ruimt audio-worklets niet op en het geheugen liep vol; een iPad Pro M3 draaide daarna 18 minuten zonder probleem [S38]. **Nog open (#116750, sinds 25 feb 2026):** Godot 4.5.1 op iOS 26.3, steeds opnieuw `AudioStreamPlayer.play()` gedurende 10–30 minuten laat de pagina herladen; met `audio/general/default_playback_type.web` = **Stream** in plaats van Sample niet [S39]. Sample (standaard) is Web Audio met lage vertraging, zonder effecten en zonder live gegenereerd geluid; Stream heeft alle functies maar meer vertraging [S35].
- **Geluid pas na een tik.** Browsers blokkeren autoplay; laat het eerste geluid op een tik volgen [S35]. `navigator.audioSession` bestaat in Safari iOS vanaf 16.4 [S40] en kent o.a. de types `playback` en `ambient` [S41]; dat het standaardtype op een iPhone in stille modus zwijgt en `playback` dat omzeilt is **[onbevestigd]**.
- **Opslag op iOS.** Safari wist alle door script geschreven opslag (IndexedDB, LocalStorage, service-worker-cache) na 7 dagen Safari-gebruik zonder bezoek aan de site; een webapp op het beginscherm is daarvan uitgezonderd en zijn gegevens zijn **gescheiden van Safari** [S42]. Sinds Safari 17 is het quotum een deel van de schijf; bij gebrek aan ruimte wist WebKit hele sites, oudste eerst, tenzij de site "persistent" is; `navigator.storage.persist()` wordt toegekend op heuristiek, zoals "opened as a Home Screen Web App" [S43]. Chrome kent `persist()` automatisch toe bij betrokkenheid, installatie of bladwijzer [S44]. Godot bewaart `user://` in IndexedDB; `OS.is_userfs_persistent()` kan vals-positief zijn [S35].
- **iOS 26.** Elke site die je op het beginscherm zet opent standaard als webapp; een manifest met iconen wordt gebruikt; "there are now zero requirements for 'installability'" [S45].
- **Geheugen.** Een te groot WebAssembly-maximum gaf "out of memory" op iOS 16.2 (#70621, nog open) [S46]; gebruikers melden WebGL-contextverlies op iOS 18 dat op 17 niet optrad, verklaard als te veel geheugen [S47]. Een budget van ±300 MB wordt op fora genoemd **[onbevestigd]**.
- **Oudere iPads.** Godot 4.5 gebruikt WebAssembly-SIMD [S48]; Safari iOS kan dat vanaf 16.4 [S49]. Afgeleid: iPads die niet verder komen dan iPadOS 15 (zoals iPad Air 2 en mini 4) starten ons spel niet **[onbevestigd]**.
- **Downloadgrootte.** Onze export: `index.wasm` 39,5 MB (10,1 MB gzip) + `index.pck` 2,9 MB (2,8 MB gzip), samen ±13 MB over de lijn. GitHub Pages gzipt `.wasm` onderweg **[onbevestigd]**. Een eigen exporttemplate zonder 3D en ongebruikte modules brengt de wasm naar ±17–20 MB **[onbevestigd]**; de documentatie raadt een op maat gebouwd template en compressie aan [S35].
- **Native.** iOS-export kan alleen op macOS met Xcode [S50]; het Apple Developer Program kost 99 USD per jaar [S51]. Kids Category: kies leeftijdsband 6–8; ouderpoort voor links naar buiten, aankopen en toestemmingen; geen persoons- of toestelgegevens naar derden zonder toestemming van de ouder [S52]. Google Play: nieuwe persoonlijke accounts moeten eerst 14 dagen een gesloten test met minstens 12 testers draaien; de Families-regels verbieden niet-goedgekeurde advertentie-SDK's **[onbevestigd]**.

> **Wat betekent dit voor ons spel**
> 1. **Houd** `variant/thread_support=false` en `ensure_cross_origin_isolation_headers=false`: geen headers nodig op GitHub Pages [S35, S36].
> 2. **Geluid-duurtest** (30 min, echte iPad, veel korte geluiden). Herlaadt de pagina: zet Projectinstellingen > Audio > General > Default Playback Type.web op **Stream** (`audio/general/default_playback_type.web`; standaard staat hij op Sample [S27]). Onze buffers zijn vooraf gemaakt, dus Stream kan alles wat we gebruiken; let wel op extra vertraging bij `tik` [S39, S35].
> 3. **Stille modus respecteren** (standaard laten) en in het ouderblad één regel: "Geen geluid? Kijk of de iPad op stil staat." Forceer `audioSession.type = 'playback'` niet: dat zou ook de muziek van de ouder onderbreken [eigen voorstel].
> 4. **Opslag beschermen:** bij de start `navigator.storage.persist()` aanroepen (via `JavaScriptBridge`); in een Safari-tab (niet `display-mode: standalone`) een ouderhint tonen "Zet het hotel op je beginscherm"; en na ±7 dagen spelen een zachte 💾-herinnering in het ouderblad [S42, S43, S44].
> 5. **Delen tussen tablets:** het 💾-bestand via AirDrop/Bestanden en 📂 Open *in* de beginscherm-app werkt het zekerst. Een **QR-code** met een `?opslag=`-link opent Safari, niet de beginscherm-app (aparte opslag [S42]): het hotel komt dan in de verkeerde "la". QR alleen als extra voor Android of een Safari-tab. Grootte: onze save is 2,7–3,1 kB JSON en ±0,6 kB na gzip (`PackedByteArray.compress`), base64url ±0,9 kB: past in één QR-code (bytemodus tot ±2,9 kB) **[capaciteit onbevestigd]**.
> 6. **Geheugen meten:** log `Performance.RENDER_TEXTURE_MEM_USED` en `OS.get_static_memory_usage()` in een `[probe]`-regel; bezoek alle 15 kamers; laat gebakken platen van kamers buiten beeld los (LRU) als het boven ±150 MB textuur komt [eigen voorstel, naar S46/S47].
> 7. **Offlinepagina** (`progressive_web_app/offline_page` is leeg): een eigen pagina met een dier en "Even geen internet. Probeer het zo weer." [S35].
> 8. **Te oude iPad:** vang in de HTML-shell een mislukte start af met een Nederlandse melding ("Deze iPad is te oud; update naar iPadOS 16.4 of nieuwer") in plaats van Godots Engelse fout [eigen voorstel].
> 9. **Native nu niet nodig.** De PWA dekt iPad en Android; een App Store-versie kost een Mac, 99 USD per jaar en Kids Category-werk (ouderpoort voor 💾/📂 is waarschijnlijk niet nodig, want dat zijn geen links naar buiten) [S51, S52]. Pas overwegen als scholen erom vragen.

---

## 6. Toegankelijkheid

### Wat bronnen zeggen

- **Dyscalculie.** Ontwerpaanbevelingen: adaptief, inhoud van getalbegrip naar bewerkingen opgebouwd, veel herhaling in kleine stukjes, directe visuele feedback **[onbevestigd]**. "Geen tijdsdruk" komt uit praktijkadvies, niet uit gecontroleerd onderzoek **[onbevestigd]**. Bij Rekentuin vonden onderzoekers geen verschil in werking van de snelheidsregel tussen kinderen met en zonder prestatieangst [S30].
- **Motoriek.** Game Accessibility Guidelines (basis): bedieningselementen groot en ver uit elkaar, vooral op aanraakschermen; geen knoppen ingedrukt houden; geen snel herhaald tikken; precieze timing niet nodig maken; zeer eenvoudige bediening die met schakelaars werkt (gevorderd) [S20].
- **Schermlezer en schakelbediening.** Godot 4.5 voegde (experimentele) schermlezer-ondersteuning voor Control-nodes toe via AccessKit; of dat op het web werkt staat niet in de release-notes [S48]. Of iPad-schakelbediening (Switch Control) in een canvas-spel kan tikken: niet uitgezocht (zoekbudget op).
- **Ouders.** Met "Begeleide toegang" (Instellingen > Toegankelijkheid) vergrendelt een ouder de iPad op één app, met tijdslimiet en uitgeschakelde schermdelen; drie keer op de bovenste knop starten/stoppen [S53].
- **Nederland en EU.** De Europese Toegankelijkheidsakte geldt sinds 28 juni 2025 voor o.a. e-commerce; games worden niet genoemd maar zijn ook niet uitgezonderd; micro-ondernemingen (< 10 mensen, < € 2 mln) vallen erbuiten **[onbevestigd]**. Voor leermiddelen verwijst de branche naar het Programma van Eisen (PO-Raad/VO-raad, 2017) en in de praktijk naar WCAG 2.1 AA via EN 301 549 **[onbevestigd]**. Voor een gratis spel van een ouder vond ik geen wettelijke plicht.

> **Wat betekent dit voor ons spel**
> 1. **Wat al goed is:** geen tijdsdruk (op het 2 s-hulpvenster na), één tik per antwoord, geen toetsenbord, geen straf, reduced motion, emoji + woord op elke knop. Dat dekt de basisrichtlijnen voor motoriek en cognitie [S20].
> 2. **Getallen overal hetzelfde laten zien [eigen voorstel]:** één vaste kleur per plaatswaarde (tientallen ↔ eenheden) en hetzelfde stippenpatroon (dobbelsteen, tienvak) in `oogst`, `sterren`, `koekjes` en `post`.
> 3. **Slepen altijd met tik-alternatief:** check dat munten in `meubels` (sleepbron op de buidel) ook met tikken naar de toonbank kunnen [S5, S20].
> 4. **"Grote knoppen" in het ouderblad:** één schakelaar die `knop_hoog`/`knop_breed` en de vangvlakken ±25 % groter maakt, voor kinderen met een motorische beperking of slecht zicht [eigen voorstel, naar S20].
> 5. **Tekstmaat:** zin op de kaart 22 px tablet (≈ 4,2 mm) en 20 px telefoon zit boven Apple's 11 pt-minimum [S8]; TIDRC noemt 14 pt voor 7–11 jaar [S2]; niet kleiner maken.
> 6. **Begeleide toegang** in de ouderuitleg zetten (op een iPad de belangrijkste "kindslot") [S53].
> 7. **Voor scholen later:** een korte toegankelijkheidsverklaring (wat werkt, wat niet: geen schermlezer) [eigen voorstel].

---

## 7. Checklist "Voor de eerste echte iPad-test" (in deze volgorde)

1. **Voorbereiden.** Noteer model en iPadOS-versie (≥ 16.4 nodig). Nieuwste export op GitHub Pages. Indien mogelijk een Mac met Safari Web Inspector (Geheugen-tijdlijn). Begeleide toegang ingesteld [S53].
2. **Eerste keer laden in een Safari-tab.** Stopwatch: tijd tot het startblad op wifi. Komt het startblad goed in beeld (geen witte rand, geen scrollbalk)?
3. **Geluid.** Eerste tik op het startblad: klinkt er iets? Stille modus aan en uit. Volumeknoppen.
4. **Beginscherm.** Deel > Zet op beginscherm (iOS 26: schakelaar "Open als webapp" aan) [S45]. Openen vanaf het icoon: schermvullend, juist icoon, draaien liggend/rechtop.
5. **Opslag.** Twee dieren inchecken, app wegvegen, opnieuw openen: hotel nog daar? Vliegtuigmodus: start het offline? Let op: het hotel uit de Safari-tab staat *niet* in de beginscherm-app [S42].
6. **Aanraken met een kind (6 jaar, en 8 jaar).** 10 minuten spelen; turf gemiste tikken en dubbele tikken. Daarna gericht: tikken terwijl een duim op de rand van het scherm rust; een knop 2 s vasthouden; tikken en wegschuiven; dubbeltikken op een antwoord, een deurbord en ⬆ Omhoog [S1, S3, S4].
7. **Draaien midden in een som** (liggend ↔ rechtop): blijft de som en de strook goed?
8. **Achtergrond.** Midden in een som naar een andere app, na 5 minuten terug: zelfde som, geluid terug?
9. **Duurtest geluid, 30 minuten** met veel korte geluiden (bv. `speel.js`-reeks in een lus): verschijnt "Deze webpagina is opnieuw geladen"? Zo ja: Stream proberen [S39].
10. **Geheugen.** Alle 15 kamers bezoeken, piek noteren (Web Inspector of `[probe]`-regel); herhalen op de oudste iPad.
11. **Leesbaarheid.** Op armlengte, in fel licht en op lage helderheid: naamplaatjes, deurborden, getallen op munten.
12. **Reduced motion** aan (Instellingen > Toegankelijkheid > Beweging) [S22]: is het spel rustig?
13. **Bewaren en openen.** 💾 naar Bestanden, AirDrop naar een tweede iPad, daar 📂 Open in de beginscherm-app.
14. **Pictogramtest.** Laat het kind bij vijf knoppen zeggen wat ze doen, vóór het erop tikt [S11].

---

## 8. Risico's bij uitbrengen

| risico | kans × impact | maatregel | inspanning |
|---|---|---|---|
| Hotel weg na 7 Safari-dagen zonder spelen (Safari-tab, niet op beginscherm) [S42] | middel × groot | ouderhint "zet op beginscherm", `storage.persist()`, 💾-herinnering | klein |
| Hotel uit Safari-tab of `?opslag=`-link staat niet in de beginscherm-app (aparte opslag) [S42] | groot × middel | delen via 💾/📂 in de app; QR alleen als extra; uitleg voor ouders | klein |
| Opslag gewist bij schijfruimtegebrek (best-effort) [S43, S44] | klein × groot | `persist()`; 💾-bestand als reservekopie | klein |
| Pagina herlaadt na lang spelen met geluid (#116750 open) [S39] | middel × groot | 30-min-duurtest; zo nodig `default_playback_type.web` = Stream | klein |
| Geen geluid: eerste tik of stille modus [S35] | groot × klein | startblad = eerste tik (is er); uitleg in ouderblad | klein |
| WebGL-contextverlies of herladen door geheugen op iPads met 2–3 GB [S46, S47] | middel × groot | meten in `[probe]`; platen buiten beeld loslaten; muziek mono/22 kHz | middel |
| iPad met iPadOS < 16.4 start niet (SIMD) [S48, S49] | klein × middel | Nederlandse foutmelding in de shell | klein |
| ±13 MB downloaden op traag netwerk | middel × middel | laadbalk met dier; later eigen exporttemplate (2D-only) [S35] | groot |
| Service worker houdt een oude versie vast | middel × klein | `CACHE_VERSION` per export (is er); bij nieuwe versie één keer herladen | klein |
| COOP/COEP-headers op GitHub Pages | n.v.t. (threads uit) [S35, S36] | niets doen; threads uit laten | — |
| Godot-update breekt webgeluid opnieuw (gebeurde in 4.4) [S37] | middel × groot | versie vastzetten; duurtest bij elke engine-update | klein |
| Geen stem voor voorlezen of veel vertraging [S25] | middel × klein | 🔊 verbergen als er geen `nl`-stem is | klein |
| Geen trillen op iOS [S24] | zeker × klein | haptiek alleen als extra op Android | — |
| Native App Store: Mac, 99 USD per jaar, Kids Category-regels [S50–S52] | — | nu niet; PWA eerst | groot |

---

## 9. Top 10 ideeën

1. **Grotere tikzones:** strook tablet 64 → 84 px hoog, telefoon 60 → 72 px, tikzones sluiten aan, vangvlak ≥ 64 px. [klein] [waarom nu: 7–10-jarigen missen 30 % van 6 mm-doelen, onze telefoonknop is 10,7 mm] [S1, S2, S5]
2. **Holdover- en dubbeltikfilter:** 350 ms geen tik op een net vervangen strook, 400 ms per knop; ook op deurbord en trap. [klein] [waarom nu: 9,9 % van de tikken op een tablet is een holdover] [S1, S3]
3. **Lange en verschoven tikken tellen:** druk tot 2 s en loslaten tot ±50 px buiten de knop is nog een tik. [klein–middel] [waarom nu: tikken tot 1,5 s bij kinderen boven de 5] [S2, S3, S4]
4. **Geluid-duurtest 30 min op een echte iPad**, zo nodig `default_playback_type.web` = Stream. [klein] [waarom nu: open bug #116750 past precies op ons patroon van veel korte `play()`] [S37, S39]
5. **Opslag beschermen:** `navigator.storage.persist()`, hint "zet op beginscherm" in een Safari-tab, 💾-herinnering. [klein] [waarom nu: een Safari-tab verliest het hotel na 7 dagen] [S42, S43]
6. **Knoprand `#E2BE8E` → `#B07A3C`** (1,7:1 → 3,6:1). [klein] [waarom nu: één regel, beter zichtbaar in fel licht] [S17, S2]
7. **Kleur nooit alleen:** vorm (● ▲ ■) bij gekleurde tekens in `spiegel`/`was`, Okabe-Ito-accenten. [klein] [waarom nu: 1 op 12 jongens is kleurenblind] [S13, S14]
8. **Rust tijdens de som:** sfeergeluid en (latere) muziek −12 dB zolang een kaart open is; feest pas na het antwoord, ≤ 1 s. [klein] [waarom nu: irrelevante prikkels kosten leren] [S2, S19, S23]
9. **🔊 Voorlezen als ouderoptie** met `tts_speak` (nl, alleen na een tik), stil verbergen als er geen stem is. [middel] [waarom nu: groep 3 leest nog niet vlot; Khan Kids doet het zo] [S2, S15, S25]
10. **Pictogramwoordenboek + pictogramtest met 3 kinderen** vóór elk nieuw pictogram. [klein] [waarom nu: 84 % juiste keuze is goed, maar enkele pictogrammen faalden] [S11, S2]

---

## 10. Bronnen

[gelezen] = zelf geopend en nagelezen; [zoekresultaat] = alleen via de samenvatting van een zoekmachine.

- **S1** Anthony e.a. (2013), *Designing Smarter Touch-Based Interfaces for Educational Contexts*, JPUC. https://lisa-anthony.com/wp-content/uploads/2013/04/anthony-et-al-jpuc2013.pdf — missers per doelgrootte, holdovers, randgoot, ontwerpadvies [gelezen].
- **S2** Soni, Aloba, Morga, Wisniewski, Anthony (2019), TIDRC-raamwerk, IDC 2019. https://init.cise.ufl.edu/wp-content/uploads/sites/378/2019/04/TIDRC-Framework-soni-et-al-IDC19-final.pdf — overzicht van onderzoeksgebaseerde aanraakregels voor kinderen [gelezen].
- **S3** Woodward e.a. (2017), *Tablets, Tabletops, and Smartphones*, ICMI 2017. https://init.cise.ufl.edu/wp-content/uploads/sites/378/2017/12/Woodward-et-al-ICMI2017.pdf — tablet, 5–10 jaar: holdovers 9,9 %, boven/links vaker mis [gelezen].
- **S4** Vatavu, Cramariuc, Schipor (2015), *Touch interaction for children aged 3 to 6 years*, IJHCS 74. https://mintviz.usv.ro/publications/ijhcs2015.pdf — afwijking in mm, tikduur, multi-touch, vingerkeuze [gelezen].
- **S5** Nielsen Norman Group (2018), *Design for Kids Based on Their Stage of Physical Development*. https://www.nngroup.com/articles/children-ux-physical-development/ — 2 × 2 cm, slepen moeilijk [gelezen].
- **S6** Nielsen Norman Group (2019), *Children's UX: Usability Issues in Designing for Young People*. https://www.nngroup.com/articles/childrens-websites-usability-issues/ — verschillen kind/volwassene [gelezen].
- **S7** Nielsen Norman Group, *Response Times: The 3 Important Limits*. https://www.nngroup.com/articles/response-times-3-important-limits/ — 0,1 s / 1 s / 10 s [gelezen].
- **S8** Apple, *UI Design Dos and Don'ts*. https://developer.apple.com/design/tips/ — 44 × 44 pt, tekst ≥ 11 pt [gelezen].
- **S9** Google, *Touch target size* (Android Accessibility Help). https://support.google.com/accessibility/android/answer/7101858 — 48 × 48 dp, 8 dp, ≈ 9 mm [gelezen].
- **S10** W3C, *Understanding SC 2.5.5 Target Size (Enhanced)*. https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html — 44 × 44 CSS-px [gelezen].
- **S11** Wiebe e.a. (2016), *Icons for Kids*, Graphics Interface 2016. https://graphicsinterface.org/wp-content/uploads/gi2016-20.pdf — 84 % juiste keuze (kans 50 %) bij 4–8 jaar, kleur maakt niet uit [gelezen].
- **S12** Miller e.a. (2016), *"Blissfully happy" or "ready to fight": Varying Interpretations of Emoji*, ICWSM. https://experts.umn.edu/en/publications/blissfully-happy-or-ready-to-fight-varying-interpretations-of-emo/ — 25 % onenigheid over gevoel [zoekresultaat].
- **S13** Okabe & Ito, *Color Universal Design*. https://jfly.uni-koeln.de/color/ — 1 op 12 mannen, "do not convey information in color only" [gelezen].
- **S14** Krzywinski, *Designing for color blindness* (palet naar Wong, Nature Methods 2011). https://mk.bcgsc.ca/colorblind/palettes.mhtml — 8-kleurenpalet; hexwaarden zelf niet op de pagina gezien [gelezen].
- **S15** Khan Academy Blog, *Supporting English Language Acquisition with Khan Academy Kids*. https://blog.khanacademy.org/supporting-english-language-acquisition-with-khan-academy-kids/ — tikken om voor te lezen, ding/bong [gelezen].
- **S16** PocketGamer.biz, *Why did the chicken... the making of Crossy Road*. https://www.pocketgamer.biz/making-of-crossy-road/ — schuine camera, duidelijke vormen [gelezen].
- **S17** W3C, *Understanding SC 1.4.11 Non-text Contrast*. https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html — 3:1 [gelezen].
- **S18** Hicks e.a. (2019), *Juicy Game Design*, CHI PLAY 2019. https://dblp.org/rec/conf/chiplay/HicksGDA19 [zoekresultaat].
- **S19** Sundararajan & Adesope (2020), *Keep it Coherent: A Meta-Analysis of the Seductive Details Effect*. https://link.springer.com/article/10.1007/s10648-020-09522-4 [zoekresultaat].
- **S20** Game Accessibility Guidelines, volledige lijst. https://gameaccessibilityguidelines.com/full-list/ [gelezen].
- **S21** W3C, *Understanding SC 2.3.1 Three Flashes or Below Threshold*. https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html — 3 per s, 341 × 256 px [gelezen].
- **S22** MDN, *prefers-reduced-motion*. https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion [gelezen].
- **S23** Hallam, Price & Katsarou (2002), *The Effects of Background Music on Primary School Pupils' Task Performance*. https://eric.ed.gov/?id=EJ670484 — kalme muziek, 10–12 jaar [gelezen].
- **S24** Can I use, *Vibration API*. https://caniuse.com/vibration — niet in Safari/iOS [gelezen].
- **S25** Godot docs, *Text to speech*. https://docs.godotengine.org/en/stable/tutorials/audio/text_to_speech.html [gelezen].
- **S26** Godot docs, *BaseButton*. https://docs.godotengine.org/en/stable/classes/class_basebutton.html — `action_mode` [gelezen].
- **S27** Godot docs, *ProjectSettings*. https://docs.godotengine.org/en/stable/classes/class_projectsettings.html — standaardwaarden (alleen de tabel) [gelezen].
- **S28** MDN, *SpeechSynthesisVoice.localService*. https://developer.mozilla.org/en-US/docs/Web/API/SpeechSynthesisVoice/localService [gelezen].
- **S29** MDN, *Navigator.vibrate()*. https://developer.mozilla.org/en-US/docs/Web/API/Navigator/vibrate [gelezen].
- **S30** Klinkenberg (2014), *High Speed High Stakes Scoring Rule*. https://www.surf.nl/files/2019-04/Artikel%20High%20Speed%20High%20Stakes%20Scoring%20Rule.pdf — Rekentuin-scoreregel [gelezen]. De latere klacht over de straf: https://www.sciencedirect.com/science/article/pii/S2666920X25000165 [zoekresultaat; pagina gaf 403].
- **S31** OpenGameArt, *Children's March Theme*. https://opengameart.org/content/childrens-march-theme — CC0 [gelezen].
- **S32** OpenGameArt, *Happy Clappy Loop*. https://opengameart.org/content/happy-clappy-loop — CC0 [gelezen].
- **S33** Kenney, *Music Jingles*. https://kenney.nl/assets/music-jingles — CC0, 85 bestanden [gelezen].
- **S34** incompetech (Kevin MacLeod), licenties en FAQ. https://incompetech.com/music/royalty-free/licenses/ [gelezen]; creditformaat: https://incompetech.com/music/royalty-free/faq.html [zoekresultaat].
- **S35** Godot docs (4.7), *Exporting for the Web*. https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html [gelezen].
- **S36** Godot blog (Adam Scott, 15 mei 2024), *Web Export in 4.3*. https://godotengine.org/article/progress-report-web-export-in-4-3/ [gelezen].
- **S37** Godot issue #107390, iOS-crash met geluid. https://github.com/godotengine/godot/issues/107390 [gelezen].
- **S38** Godot PR #107948, WebKit-lek in audio-worklets. https://github.com/godotengine/godot/pull/107948 [gelezen].
- **S39** Godot issue #116750 (open, 25 feb 2026). https://github.com/godotengine/godot/issues/116750 [gelezen].
- **S40** Can I use, *navigator.audioSession*. https://caniuse.com/mdn-api_navigator_audiosession [gelezen].
- **S41** W3C Editor's Draft, *Audio Session*. https://w3c.github.io/audio-session/ [gelezen].
- **S42** WebKit, *Tracking Prevention*. https://webkit.org/tracking-prevention/ — 7 dagen, beginscherm uitgezonderd, aparte opslag [gelezen].
- **S43** WebKit blog (10 aug 2023), *Updates to Storage Policy*. https://webkit.org/blog/14403/updates-to-storage-policy/ [gelezen].
- **S44** web.dev, *Persistent storage*. https://web.dev/articles/persistent-storage [gelezen].
- **S45** WebKit blog, *WebKit Features in Safari 26.0*. https://webkit.org/blog/17333/webkit-features-in-safari-26-0/ [gelezen].
- **S46** Godot issue #70621, WASM-geheugen op iOS. https://github.com/godotengine/godot/issues/70621 [gelezen].
- **S47** Godot Forum, *WebGL Context Loss and App Crash in Godot 4.3 Exported Web on iOS Browsers*. https://forum.godotengine.org/t/webgl-context-loss-and-app-crash-in-godot-4-3-exported-web-on-ios-browsers/81024 [gelezen].
- **S48** Godot, *Release 4.5*. https://godotengine.org/releases/4.5/ — WASM-SIMD, AccessKit [gelezen, deels].
- **S49** Can I use, *WebAssembly SIMD*. https://caniuse.com/wasm-simd — Safari iOS 16.4+ [gelezen].
- **S50** Godot docs, *Exporting for iOS*. https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html [gelezen].
- **S51** Apple, *Apple Developer Program*. https://developer.apple.com/programs/whats-included/ — 99 USD/jaar [gelezen].
- **S52** Apple, *Kids Category*. https://developer.apple.com/app-store/kids-apps/ [gelezen]; App Review Guidelines 1.3 en 5.1.4: https://developer.apple.com/app-store/review/guidelines/ [zoekresultaat].
- **S53** Apple Support, *Use Guided Access on iPhone or iPad*. https://support.apple.com/en-us/111795 [gelezen].

Alleen via zoekresultaat (niet zelf nagelezen; gebruikt bij de **[onbevestigd]**-punten):
- Google Play, testeisen nieuwe persoonlijke accounts: https://support.google.com/googleplay/android-developer/answer/14151465
- Google Play Families-beleid: https://support.google.com/googleplay/android-developer/answer/9893335
- Sclera-licentie: https://www.sclera.be/nl/picto/copyright ; ARASAAC via Global Symbols: https://globalsymbols.com/symbolsets/arasaac?locale=en ; OpenMoji: https://openmoji.org/faq/
- OpenGameArt *Feel Good Island Loop*: https://opengameart.org/content/feel-good-island-loop ; *Flowerbed Fields*: https://opengameart.org/content/flowerbed-fields-loop
- Godot-issue #103262 (lege stemmenlijst op het web): https://github.com/godotengine/godot/issues/103262
- Godot docs, *Optimizing a build for size*: https://docs.godotengine.org/en/4.4/contributing/development/compiling/optimizing_for_size.html
- Dyscalculie-ontwerpaanbevelingen (2016): https://link.springer.com/chapter/10.1007/978-3-319-39483-1_42
- Europese Toegankelijkheidsakte en games: https://www.playerresearch.com/blog/european-accessibility-act-video-games-going-over-the-facts-june-2025/
- Kennisnet, Programma van Eisen leermiddelen: https://www.kennisnet.nl/leermiddelen/het-programma-van-eisen-voor-de-leermiddelenmarkt-dit-moet-je-weten/
- Lospec, contrast-tutorials (pixelpraktijk): https://lospec.com/pixel-art-tutorials/tags/contrast
- Monument Valley (kleur toont interactie, kleurscript): https://en.wikipedia.org/wiki/Monument_Valley_(video_game) ; https://www.creativebloq.com/computer-arts/making-monument-valley-71412213
- Icon Design Principles for Preschoolers (afspeeldriehoek): https://www.sciencedirect.com/science/article/pii/S1877042812050045
- Jacko & Rosenthal (1997), auditieve iconen groep 1 vs 3: https://doi.org/10.2466/pms.1997.84.3c.1223
- Interface-ontwerp van apps voor autistische kinderen (prikkels, eenvoud): https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11894442/
- Rekentuin, vaste straf na klachten (Elo-psychometrie, 2025): https://www.sciencedirect.com/science/article/pii/S2666920X25000165
- Godot-docs (bron, master) over gzip op GitHub Pages: https://github.com/godotengine/godot-docs/blob/master/tutorials/export/exporting_for_web.rst
- Kleinere Godot-builds (wasm-groottes per vlag): https://popcar.bearblog.dev/how-to-minify-godots-build-size/
- Web Speech op iOS, alleen vooraf geïnstalleerde stemmen: https://developer.apple.com/forums/thread/723503
- Europese Toegankelijkheidsakte, micro-ondernemingen: https://www.taylorwessing.com/en/insights-and-events/insights/2025/03/accessibility-in-the-gaming-industry
- `navigator.audioSession` en de stille modus van iOS: alleen genoemd in zoeksamenvattingen (GitHub-PR's van derden), geen primaire bron gevonden.
