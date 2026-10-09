# Godot-spec — games E: de bakkerij, de muziekkamer, het dakterras en de postkamer

Geschreven 2026-10-08 na de integratie (commits `312f1be` kamers, `d20824f` spellen, `0ee2813`
gasten/accessoires/emoji).  De eigenaar vroeg:

> "Verzin nog vier kamers met activiteiten en maak nog twee extra dieren. En nog extra
> accessoires om te kopen bij de kraapjes voor decoratie. En eventueel ook accessoires om in de
> kamers te zetten of de kamers te decoreren."

Dit bestand beschrijft de vier kamers met hun spel.  De kamerdata staan in world.md §1.10, de
twee nieuwe diersoorten in world.md §2.1 en art-sound-rules.md §2.1, de elf nieuwe
kledingstukken in games-d.md §2 en §4.1, de decoratietab van het meubelboek in games-a.md §5.10.
Net als games-c en games-d is dit geen port: alles is nieuw.  De regels zijn die van games-b.md
§0, HOTEL.md §9 en PLAN.md §1: elk getal ligt in de wereld, één tik op een strook van vier, een
misser is alleen het teleurgestelde dier met `🔄 Nog een keer` (`Ui.misser`) en dezelfde vraag,
geen hulp, één ster voor meedoen.  `core/sommen.gd` blijft bevroren: elk spel heeft zijn eigen
`games/<id>/beurt.gd` (puur en statisch; koekjes en band lezen alleen `Sommen.Prng`, sterren
gebruikt een `RandomNumberGenerator` met een vast zaad, post rekent zonder toeval).

Ontwerp en stand per werkstroom: `.fanout/scratch/uitbreiding/U1-bakkerij.md` … `U4-postkamer.md`
in de worktrees (zie `docs/STATUS-2026-10-08.md`), integratie in `I1a-integratie.md` en
`I1b-integratie.md`.

**Pictogrammen.**  Tijdens de bouw ontbraken 🔭 📮 🥁 🎵 👂 🔁 🥐 in de gebundelde emoji-subset;
de spellen gebruikten ⭐, 💌, 🔔 en 🔄.  F1 zette 33 tekens in `fonts/tekens.txt` (Emoji.ttf
258 776 → 324 936 B) en de polijstpas van 2026-10-08 wisselde ze: hieronder staat de nieuwe
stand, met de oude tussen haakjes.  `tests/test_tekens.gd`, `test_elke_zin_past` van elk spel en
`Ui.mist_tekens` bewaken dat elk teken bestaat.

**Rekenen ≥ 50 % (2026-10-09).** Eigenaar: *"Minigames mogen een klein extra spel element hebben maar het moet niet mogelijk zijn om rekenen over te slaan en rekenen moet minstens 50% van de interactie zijn."* Sinds `c72edf8` houdt elk spel per beurt **R1** (rekentikken ≥ andere tikken + 1, de tik die het spel opent niet meegeteld; groep 3/4/5, N 1–8) en **R2** (geen ster, munt, stuk of voortgang zonder goed antwoord; een vraag met een misser komt onveranderd terug na ⬅ Terug, een ander dier, herladen, een nieuwe dag of een andere N of groep). Onder de kop van elk spel hieronder staat een notitie "(2026-10-09, rekenen ≥ 50 %)" met de nieuwe beurt; waar de oudere tekst eronder iets anders zegt, wint die notitie. De Rekenwacht voor het hele hotel en de tabel per spel: `docs/REKENWACHT.md`; de regels voor wie bouwt: `AGENTS.md` §5.

---

## 1. Koekjes bakken (`koekjes`, bakkerij)

**Notitie (2026-10-09, rekenen ≥ 50 %).** De beurt bleef 1 rekentik en 0 andere. R2: een gemiste som blijft na een nieuwe dag, een andere N of groep en de dierwissel (het gekozen dier neemt de plaat over, de som blijft); de som komt uit de bewaarde N, groep en dag, en de strook houdt dezelfde vier getallen (zaad = de dag van de beurt). Bron: `.fanout/scratch/burn/GE.md`.

**De kamer.**  De bakkerij (etage 1, achter de keuken; world.md §1.10).  Tegen de achterwand
links een stenen **oven** (30, 10), midden op de vloer een grote **bakkerstafel** (56, 50,
`BANK_W` 46 × `BANK_D` 38) met een lege bakplaat, een deegroller en wat bloem.  Oven en tafel
zijn van het spel: rustspullen zolang niemand speelt (`definitie().rust`, ids `rust_kk_oven`,
`rust_kk_bank`, modellen `koekjes_oven`/`koekjes_bank` uit `art/decor_bakkerij.gd`), het decor
van het spel tijdens een beurt.  Er staat dus precies één oven; `mijd` houdt hun vloer vrij.
Ze staan er altijd (`unlock` is altijd waar, ook zonder gasten): een bakkerij zonder oven is
geen bakkerij.  De knop `🍪 Bakken` hangt op de oven (anker `aanrecht`, verschoven naar de oven,
`hotspot.rust`) en komt, net als het kaartje `🍪 Bak koekjes` (prio 5), pas als er een gast met
een bed is (`kan`).  Geen `wens`: de wens 🍪 blijft die van de voerkar.

**De beurt** (`games/koekjes/spel.gd`, `beurt.gd`, `bord.gd`):

1. De bakker (een gast met een bed; het dier van de spelbalk gaat voor, `ctx.voorkeur`) loopt
   naar de linkerkant van de tafel (`ctx.wacht_op`, het hotel toont "komt eraan").  Op de tafel
   ligt de som zelf (`KoekjesBeurt.bank`).
2. Staat hij er, dan toont het **grote bord** (`KoekjesBord`, `kind: "eigen"`, vast, prio 20)
   de tafel groot naast hem, en dokt één kaart in de rekenbalk: pictogram + zin + somregel +
   strook van vier (`goed`, `liever`, `min: 1`).  Het bord bedekt nooit de bakker, de kaart of
   de strook; het neemt het grootste vrije stuk naast, boven of onder hem.
3. **Fout:** `Ui.misser` (de bakker is sip, `🔄 Nog een keer`, strook 1,2 s dicht), `zacht`,
   `missers + 1`; dezelfde vraag met dezelfde vier getallen.
4. **Goed:** ✓, `ja` (+ de blije stem van het dier), `ctx.state.tel(missers == 0, ms)`, één ster
   (`ctx.taak_klaar("koekjes")`), bewaard.  Dan ligt het antwoord in de wereld: bij een plaat
   gaat de plaat de gloeiende oven in, `ding`, en komt terug met **gouden koekjes**; bij de
   eieren rollen ze één voor één de kom in (`plop`); bij het dubbele recept worden beide kommen
   beslag; bij het delen liggen de koekjes in N rijen van k en de rest op een bordje op de oven
   (`tover`).  Eindkaart (✨ + slotzin, de som, het antwoord), `hoera`, drie spetters boven de
   tafel, de bakker huppelt en knabbelt (`knabbel`) met "😋 lekker!", 3,6 s later dicht.

De bakker blijft de hele beurt bij de tafel (een dwaalwandeling wordt teruggedraaid, zijn
wachttijd elke 12 s vernieuwd).

**Het rekenen** (`KoekjesBeurt.maak(n, band, dag)`, zaad `Sommen.Prng.new(90317 + dag·31 +
n·7 + band)`, N = `State.n_gasten()` begrensd 1..8).  De rijen op de plaat zijn de gasten, de
kolommen wat elk dier krijgt: de tafelsom is iets om te tellen.

| groep | soort | wat er ligt | som (voorbeelden uit `beurt.gd`) | kaartzin |
|---|---|---|---|---|
| 3 | `koekjes` (alleen 2 ≤ N ≤ 5) | N rijen van 2 deegbolletjes | `2 + 2 + 2 =` (≤ 10) | "🍪 Hoeveel koekjes op de plaat?" |
| 3 | `eieren` (altijd bij N = 1 of N > 5) | N eieren in de kom, r = 1..3 ernaast | `3 + 2 =` | "🍪 Hoeveel eieren in de kom?" |
| 4 | `plaat` | N rijen × k, k ∈ {2, 5, 10} | `3 × 5 =`; in de export gespeeld: `4 × 5 =` | "🍪 Hoeveel koekjes op de plaat?" |
| 4 | `dubbel` | twee kommen met e = min(N+1+0..2, 10) eieren | `4 + 4 =` (≤ 20) | "🍪 Dubbel recept: hoeveel eieren?" |
| 5 | `tafel` | N rijen × k, k ∈ {3, 4, 6, 7, 8, 9} | `6 × 7 =` (alle tafels, ≤ 72) | "🍪 Hoeveel koekjes op de plaat?" |
| 5 | `verdeel` (N ≥ 2) | T = k·N + r koekjes in rijen van tien, k 2..9, r 0..N−1 | `14 : 3 =`, antwoord k | "🍪 Hoeveel koekjes per dier?" + regel 2 "▸ De rest is voor de kok" |

Afleiders (`_liever`): ±1, ±k, N + k, de rest r — altijd > 0 en nooit het antwoord.  Groep 5
heeft één plaat met alle tafels tot 10 (IDEAS.md); een "2 × N × k" met twee platen paste op
geen tafel en verviel.

**Kindtekst, letterlijk** (`beurt.gd`; pictogram `ICOON` 🍪 vóór elke kaartzin):
"Hoeveel koekjes op de plaat?" · "Hoeveel eieren in de kom?" · "Dubbel recept: hoeveel eieren?" ·
"Hoeveel koekjes per dier?" · "▸ De rest is voor de kok" · slot met ✨: "Klaar! Ze zijn gaar"
(plaat), "Alle eieren in de kom!" (eieren), "Het deeg is klaar" (dubbel), "Eerlijk verdeeld!"
(delen) · wolk "😋 lekker!" · wolk "🛏 nog geen gasten" · knop `🍪 Bakken` · taak `🍪 Bak koekjes`.

**Bewaren.**  `spel.koekjes.stand = {gast, dag, N, band, stap: som|bak|af, pog, missers, ster}`.
Alleen in stap `som` en voor dezelfde dag, N, band en bakker gaat een beurt verder (de vraag
wordt opnieuw berekend, dus dezelfde); JSON-floats worden ints.

**Tests** (`games/koekjes/test_koekjes.gd`, 16): `test_groep3_telt_tot_twintig`,
`test_groep4_tafels_2_5_10_en_verdubbelen`, `test_groep5_alle_tafels_en_delen_met_rest`,
`test_zelfde_dag_zelfde_vraag`, `test_zinnen_volgen_de_tekstregels`,
`test_de_bakkerij_is_een_kamer_op_de_eerste_verdieping`, `test_decormodellen_bakken`,
`test_het_grote_bord_meet_zich`, `test_aanmelding`, `test_de_rustende_oven_en_tafel`,
`test_een_beurt_per_band` (een fout vakje: sip, 🔄, niets erbij, dezelfde vier getallen; goed:
`ja`, ster + 1, één `tel`, de geluiden, bord en tafel tonen het antwoord, dicht),
`test_elke_soort_legt_zijn_antwoord_neer`, `test_herladen_geeft_dezelfde_vraag`,
`test_het_gekozen_dier_bakt`, `test_zonder_gasten`, `test_op_vier_schermen`.

---

## 2. De dierenband (`band`, muziekkamer)

**Notitie (2026-10-09, rekenen ≥ 50 %).** Eén antwoord en 0 andere tikken: de **eerste herhaling speelt vanzelf** (`_gratis_nog_eens`, 1,2 s na het eerste ritme; nooit na een misser) en elke tik op 🔁 is `vrij: true`. Niet gekozen: een ongemarkeerde eerste 🔁-tik (1 : 1, haalt R1 niet). R2 zoals bij koekjes; het ritme komt uit de bewaarde N, groep, dag en nummer. Bron: `.fanout/scratch/burn/GE.md`.

**De kamer.**  De muziekkamer (etage 3, achter de speelzaal; world.md §1.10): warm hout, een rond
perzikkleurig kleed als podium (zone `podium`, `mijd`).  Zolang er niet gespeeld wordt staan de
vier rustspullen van het spel (`rust_band_*`, modellen uit `art/decor_muziek.gd`): trommel
(44, 44), xylofoon (66, 30), staande piano (34, 1) tegen de achterwand, muziekstandaard (24, 34).
De knop `🥁 Dierenband` (was 🔔) hangt op de trommel (`hotspot.obj` muziekdoos + dx/dz,
`hotspot.rust` de trommel), vanaf één gast (`unlock` N ≥ 1, `kan`: een gast met een bed); taak
`🥁 Speel mee in de band` (prio 5).

**De beurt** (`games/band/spel.gd`, `beurt.gd`, `notenbalk.gd`):

1. De rustspullen gaan weg, het spel zet zijn eigen `bd_*` neer en de **notenbalk**
   (`BandNotenbalk`, `kind: "eigen"`) staat er meteen, alle noten bleek: één tegel per maat, de
   noten van een maat als een trapje.
2. Het dier van de beurt (spelbalk, anders `(dag + N + nr) % aantal`) loopt naar zijn plek
   (74, 56) rechts van de trommel.  Dan pas de knop `🔁 Nog een keer luisteren` (was 🔄) en de
   wolk `👂 Luister en kijk goed` (was 🔔).
3. Het ritme: `hup`, 0,6 s, dan per tik `plop(j)` (de toon stijgt in de maat), de noot licht op
   (rood; het tweede ritme van "samen" blauw), een vonkje van het trommelvel en het dier knikt.
   Tussen twee maten `klok` + 0,5 s rust.  Tempo: groep 3 0,42 s per tik; groep 4/5 een maat in
   ±2,1 s (`clamp(2,1 / k, 0,22, 0,42)`).  Langste ritme (6 maten van 10) 16,3 s.  Een stomme
   tablet mist niets: elke tik is ook een lichtje.
4. De kaart komt na het eerste ritme, of na `KAART_NA_S` = 8 s terwijl de trommel doorspeelt.
5. **Fout:** `Ui.misser`, `zacht`, `missers + 1`, dezelfde vraag en dezelfde vier getallen.  🔁
   speelt het ritme altijd opnieuw vanaf de eerste noot; die knop staat er vanaf het begin en is
   dus geen hulp na een fout.
6. **Goed:** ✓, `ja`, `tel`, één ster (`ctx.taak_klaar("band")`), 🔁 weg; de slotkaart "🎉 De band
   speelt!" met regel 2 "%d tikken, goed geteld", een gloed over de hele balk, `hoera`, vonken,
   elk dier in de muziekkamer juicht, wolk "😍 mooi!", `tover`, 3,4 s later dicht.

**Het rekenen** (`games/band/beurt.gd` `opzet(n, band, dag, nr)`, zaad `60487 + dag·7919 + N·131 + band·17 +
nr·104729`; één maat per gast, M = N begrensd 2..6; `nr` telt de afgemaakte beurten van vandaag,
zodat een tweede beurt een ander ritme is en herladen hetzelfde):

| groep | soort | wat het kind hoort en ziet | som | kaartzin |
|---|---|---|---|---|
| 3 | `tel` | één ritme van T tikken, T 2..10 | — (alleen het getal) | "🥁 Hoeveel tikken hoorde je?" |
| 3 | `samen` (vanaf dag 3, de helft van de keren) | twee ritmes, a 3..10 en c 2..10, rood en blauw | `a + c =` (≤ 20) | "🥁 Hoeveel tikken samen?" |
| 4 | `maten` | M maten van k, k ∈ {2, 5, 10} | `M × k =`; in de export gespeeld: 4 maten van 5, `4 × 5 =`, "20 tikken, goed geteld" | "🥁 Hoeveel tikken in 4 maten?" |
| 5 | `tafel` (oneven dagen) | M maten van k, k ∈ {3, 4, 6, 7, 8} | `M × k =`, bijvoorbeeld `6 × 6 =` (raster 3 × 2) | "🥁 Hoeveel tikken in %d maten?" |
| 5 | `omgekeerd` (even dagen) | één maat van k wordt getoond, D = k·M | `D : k =`, antwoord M; bijvoorbeeld "Hoeveel maten voor 48 tikken?" met k = 8 → 6 | "🥁 Hoeveel maten voor %d tikken?" |

Afleiders (`liever`, de echte vergissingen): één tik ernaast, één maat ernaast (`k·(M−1)`,
`k·(M+1)`), de tikken van één maat, `k + M` in plaats van `k × M`; bij `omgekeerd` M ± 1 en k.

**Kindtekst, letterlijk** (`beurt.gd`): taak "Speel mee in de band" · knop "Dierenband" ·
"Luister en kijk goed" · "Hoeveel tikken hoorde je?" · "Hoeveel tikken samen?" · "Hoeveel tikken in
%d maten?" · "Hoeveel maten voor %d tikken?" · knop "Nog een keer luisteren" · slot "De band
speelt!" · regel 2 "%d tikken, goed geteld" · wolk "nog geen gasten" (🛏) · wolk "mooi!" (😍).
Pictogrammen: `ICOON` 🥁 (was 🔔), `ICOON_LUISTER` 👂 (was 🔔), `ICOON_NOG` 🔁 (was 🔄: met 🔄 op
de knop én 🔄 op de mokwolk stonden er twee "nog een keer" tegelijk), `ICOON_AF` 🎉, `ICOON_AF2`
🎵 (was 🔔), `ICOON_LEEG` 🛏, `ICOON_BLIJ` 😍.

**Bewaren.**  `stand = {gast, dag, N, band, nr, stap: luister|som|af, pog, missers, ster}`; het
ritme zelf wordt bij elke start opnieuw berekend.  Herladen midden in de beurt: hetzelfde ritme,
dezelfde vraag, dezelfde strook, de misser telt nog; in stap `som` staat de kaart er meteen en
speelt het ritme nog één keer.  Een afgemaakte beurt van vandaag → `nr + 1`; een nieuwe dag →
`nr = 0`.

**Tests** (`games/band/test_band.gd`, 16): `test_aanmelding`, `test_een_maat_per_gast`,
`test_de_getallen_per_band` (+ strook, duur ≤ 20 s), `test_hetzelfde_zaad_hetzelfde_ritme`,
`test_elke_zin_past`, `test_de_modellen_bakken`, `test_de_notenbalk_telt_zijn_lichtjes`,
`test_de_notenbalk_groepeert_de_maten`, `test_een_hele_beurt` (tikken in de maat, plops =
lichtjes, misser zonder hulp, 🔁, ja/hoera/tover, ster), `test_een_beurt_in_groep_4_en_5`,
`test_het_dier_blijft_bij_de_trommel` (elk frame bekeken: een knik eindigt het spel zelf, anders
liep het dier midden in het ritme weg — in de export gevonden), `test_een_lang_ritme_laat_de_kaart_niet_wachten`,
`test_herladen_hervat_de_beurt`, `test_de_rustende_band`, `test_zonder_gasten`,
`test_op_vier_schermen`.

---

## 3. Sterren tellen (`sterren`, dakterras)

**Notitie (2026-10-09, rekenen ≥ 50 %).** De beurt bleef 1 rekentik en 0 andere. R2 zoals bij koekjes; de hemel komt uit het bewaarde zaad. Bron: `.fanout/scratch/burn/GE.md`.

**De kamer.**  Het dakterras (etage 4, de top van de toren, via de nieuwe trap omhoog van de
speelzaal; world.md §1.10) is altijd **nacht** (`Kamer.nacht`): `scenes/vloer.gd` tekent een
donkerblauwe lucht met sterren, een paar fonkelende en een maansikkel over het hele beeld (de
lucht hangt aan het beeld, niet aan de kamer), een planken dek met een stenen rand, onder het dek
de twee buitenmuren van de toren met verlichte ramen, een reling langs de twee achterranden, een
traphuis om de trap omlaag en slingers lampjes.  De meubels zijn wereldmodellen (lantaarns,
bloembakken, bankje, plant, kussenhoek).  In de hoek rechtsvoor (zone `sterren`, `mijd`) staat de
**telescoop** (94, 74; rustspul `rust_st_telescoop`, model `sterren_telescoop` uit
`art/decor_dak.gd`); de knop `🔭 Sterren tellen` (was ⭐) hangt erop, vanaf één gast; taak
`🔭 Tel de sterren` (prio 6).

**De beurt** (`games/sterren/spel.gd`, `beurt.gd`, `kijker.gd`):

1. Het dier van de beurt klimt de trap op ("komt eraan") en gaat naast de telescoop staan
   (104, 90); een ander dier dat daar staat stapt opzij.
2. Het beeld van de telescoop komt groot naar voren (`SterrenKijker`, `kind: "eigen"`, vast,
   prio 20: een marineblauw paneel in een koperen rand) met de sterren van de beurt in hun
   **patronen** — dobbelsteenogen, tienvelden met hun lege vakjes als ringen, rijen, blokken van
   honderd; geen andere ster in het beeld, elke ster telt.  De kaart vraagt één vraag met vier
   getallen.
3. **Fout:** `Ui.misser`, `zacht`, de misser telt; verder verandert er niets.
4. **Goed:** de kaart wordt groen met het getal in het vak, `ja`, de sterren in het beeld lichten
   op (`juich`), vonken bij de telescoop en het dier, elk dier op het dak kijkt omhoog (`kijk`),
   `tel(missers == 0, ms)`, één ster per dag (`taak_klaar("sterren")`), na 2,6 s dicht.

**Het rekenen** (`games/sterren/beurt.gd` `maak(band, n, beurt_nr, zaad)`; een vaste rij soorten per groep over
`beurt_nr` (+ 1 per afgemaakte beurt), zodat een kind elke soort tegenkomt; zaad `90317 + dag`):

| groep | soort | wat de kijker toont | antwoord (bijvoorbeeld) | kaartzin |
|---|---|---|---|---|
| 3 | `patroon` | één patroon 1..10 (dobbelsteen tot 6, daarboven een tienveld) | k | "🔭 Hoeveel sterren zie je?" |
| 3 | `samen` (N ≥ 2) | twee sterrenbeelden, a ≤ 10, a + b ≤ 20 | a + b | "🔭 Hoeveel sterren zijn het samen?" |
| 3 | `tot_tien` | een tienveld met k sterren en 10 − k lege vakjes | 10 − k | "🔭 Hoeveel sterren erbij tot 10?" |
| 4 | `rijen` | r rijen van 2, 5 of 10, r 2..min(10, N+2) | in de export gespeeld: 3 rijen van 2 → 6 | "🔭 Hoeveel sterren in %d rijen van %d?" |
| 4 | `dubbel` | hetzelfde patroon k twee keer, k 2..10 | 2k | "🔭 Dubbel: hoeveel sterren samen?" |
| 5 | `tientallen` | t tienvelden (1..min(9, N+2)) + e losse | 10t + e, bijvoorbeeld 3 tienvelden en 4 → 34 | "🔭 Hoeveel sterren bij elkaar?" |
| 5 | `honderden` | h blokken van honderd (1..min(3, N)) + t tienvelden | 100h + 10t, bijvoorbeeld 2 blokken en 3 tienvelden → 230 | "🔭 Hoeveel sterren bij elkaar?" |
| 5 | `rijen_van` | r rijen van s, r 2..min(9, N+3), s 2..9 | r·s | "🔭 Hoeveel sterren in %d rijen van %d?" |

Afleiders: structuurfouten — ±1, ±een rij, ±10, ±100, "alleen één groep"; het antwoordvak heeft
drie cijfers vanaf 100 (`Beurt.cijfers`).

**Kindtekst, letterlijk** (`beurt.gd`; de kaart zet `ICOON` 🔭 (was ⭐) ervoor, met het pictogram
erbij elke zin ≤ 8 woorden en ≤ 40 tekens): "Hoeveel sterren zie je?" · "Hoeveel sterren zijn het
samen?" · "Hoeveel sterren erbij tot 10?" · "Hoeveel sterren in %d rijen van %d?" · "Dubbel:
hoeveel sterren samen?" · "Hoeveel sterren bij elkaar?" · knop "Sterren tellen" · taak "Tel de
sterren" · wolk "🛏 nog geen gasten" · kamer `🌙 Dakterras`.

**Bewaren.**  `stand = {gast, dag, N, band, nr, zaad, stap, missers, ster}` en `beurt_nr` in de la
van het spel.  Verder alleen voor dezelfde dag, N en band, een stap die niet `af` is, en hetzelfde
dier (een ander gekozen dier begint een nieuwe beurt).

**Tests** (`games/sterren/test_sterren.gd`, 15): `test_patronen_kloppen`,
`test_elke_groep_elke_beurt_is_een_kloppende_som`, `test_dezelfde_dag_dezelfde_vraag`,
`test_de_definitie_op_het_dakterras`, `test_het_dakterras_is_de_top_van_de_toren`,
`test_de_modellen_van_het_dak_bakken`, `test_de_kijker_toont_de_patronen`,
`test_de_kijker_is_geen_knop_en_glanst`, `test_elke_zin_past`, `test_een_beurt_per_band` (met een
misser), `test_meteen_goed_en_een_tweede_beurt`, `test_herladen_toont_dezelfde_hemel`,
`test_zonder_gasten`, `test_de_rustende_telescoop`, `test_op_vier_schermen`.
`tests/test_trap.gd` kent de nieuwe vluchten (speelzaal omhoog, dakterras omlaag).

---

## 4. De post sorteren (`post`, postkamer)

**Notitie (2026-10-09, rekenen ≥ 50 %).** Per brief één vakje op een `reken: true`-strook, 0 andere tikken; `ctx.reken_goed()` per goed vakje. R2: een gemiste brief (`pog > 0`) blijft na een andere dag, N of groep; de stapel komt uit de bewaarde groep, N, dag en ronde. De dierwissel houdt de stapel én de voortgang (vroeger: dezelfde stapel vanaf brief 0). Bron: `.fanout/scratch/burn/GE.md`.

**De kamer.**  De postkamer (etage 0, achter de **kas**, niet achter de receptie; world.md
§1.10): 96 × 88, houten vloer, pictogram 📮 (was 💌).  Langs de achterwand de **vakkenkast**
(82 lang, vier vakjes van 18 op een steek van 20, een bordjesrand met vier witte kaartjes) op
(48, 1); langs de linkerwand de **zegelbalie** met een vel zegels en de **pakketweegschaal** op
(1, 34); de rode **postkar** midden op de vloer (40, 44).  Alle drie zijn rustspullen van het spel
(`rust_po_kast`, `rust_po_balie`, `rust_po_kar`; modellen `post_kast/post_kar/post_balie` uit
`ArtDecorPost.spel_tabel()`); de kamer zelf heeft alleen een klok, een postzak en een plant.
De knop `📮 Post` hangt op de rustende kar; vanaf één gast; taak `📮 Sorteer de post` (prio 6).
Zonder gasten: geen spullen, geen knop, geen kaartje.

**De beurt** (`games/post/spel.gd`, `beurt.gd`):

1. De **postbode** (het dier van de spelbalk, anders een gast met een bed, index (dag + N) mod n)
   loopt naar zijn plek links van de kar (22, 64).  Is er niemand met een bed, dan sorteert het
   kind alleen.
2. Meteen: kast, balie en kar met de stapel als decor van het spel; de vier **bordjes** "50 - 59"
   … als getalplaatjes op de bordjesrand, elk boven zijn vakje — alleen waar er vier naast elkaar
   passen (tablet, desktop); op een telefoon draagt de strook de getallen alleen.
3. Staat hij bij de kar: het **adres** van de bovenste brief ("📮 69", groep 5 "📮 7 × 8") en de
   kaart "📮 In welk vakje hoort deze brief?" met het adres op de somregel (`reken: true`).  De
   strook: precies vier knoppen = de vier vakjes, in de volgorde van de kast, "📮 50 - 59"; op een
   smalle balk het pictogram boven de getallen ("📮⏎50-59").
4. **Fout:** `ctx.ui.misser(_kaart, postbode)`, dezelfde brief blijft, verder verandert er niets.
5. **Goed:** `Snd.brief()` + `ja`, ✓, de brief ligt in zijn vakje (kastparameter `vol`),
   papierspetter, de stapel één lager; na 0,6 s de volgende brief.
6. **Lege kar:** "✅ Alle post is gesorteerd!" + ✓, `tel(missers == 0, ms)`,
   `ctx.taak_klaar("post", {sterren: 1})`, `hoera`, gouden spetter over de vakjes, de postbode
   huppelt, na 3,4 s dicht; de rustspullen komen terug.

Waarom een strook en niet een tik op het vakje: de strook is het contract van elk spel (AGENTS.md
§1.4), dokt op elk scherm en draagt de mokpauze van `Ui.misser`; vier vakjes 20 voxels uit elkaar
worden op een telefoon door het knoppenraster geplet (de wasserij had er een eigen oplosser voor
nodig).  De wereld legt het toch uit: de knoppen staan in de volgorde van de vakjes met de
woorden van hun bordje, en een goede brief valt zichtbaar in zijn vakje.

**Het rekenen** (`games/post/beurt.gd` `maak(band, n_gasten, dag, ronde)`, zonder toeval).  De kast is een
**getallenlijn in vier stukken**; de vraag is altijd dezelfde.  N brieven (één per gast, 2..6);
binnen één stapel komt elke brief één keer voor; `ronde` geeft dezelfde dag een nieuwe stapel bij
dezelfde vakjes.

| groep | vakjes | op de brief | stapel van dag 1 (nagerekend) |
|---|---|---|---|
| 3 | 1-5 · 6-10 · 11-15 · 16-20 | een los getal 1..20 | 1 gast (2 brieven): 6, 13 |
| 4 | vier tientallen a0-a9 … d9, a = (N + dag) mod 7 | een getal uit dat venster | 4 gasten: 69, 82, 55, 68 in 50..89 |
| 5 | hetzelfde venster | een keersom k × m (2..10) met het product in het venster | 7 gasten (6 brieven): 3 × 2, 3 × 7, 4 × 3, 4 × 8, 5 × 5, 6 × 4 in 0..39 |

`7 × 8` hoort in "50 - 59" en `9 × 9` in "80 - 89" (`test_de_voorbeelden_uit_het_ontwerp`).
**Groep 5:** keersommen op de brieven zijn gebouwd; zegels betalen met wisselgeld en pakketten in
kilo's zijn niet gebouwd (die vragen de geldstrook en de muntregels van `games/_winkel`, een
tweede stap met een eigen kaart; PLAN.md §4 `E5`).

**Kindtekst, letterlijk** (`beurt.gd`; `ICOON` 📮, `ICOON_AF` ✅): kaart "📮 In welk vakje hoort
deze brief?" (7 woorden, 33 tekens) · slot "✅ Alle post is gesorteerd!" · strooktitel "kies een
vakje" · knoppen "📮 30 - 39" / kort "📮⏎30-39" · adres "📮 34" / "📮 7 × 8" · knop `📮 Post` ·
taak `📮 Sorteer de post` · kamer `📮 Postkamer`.  💌 blijft het hotelpictogram voor brieven
("💌 Er is post!", de brievenmuur).

**Bewaren.**  `stand = {gast, dag, N, band, ronde, stap, i, pog, missers, ster}`, na elke stap
bewaard; de stapel wordt herberekend uit (band, N, dag, ronde), dus na herladen dezelfde brief
en liggen de gesorteerde brieven nog in hun vakjes.  Een volle stapel van vandaag → `ronde + 1`;
een andere dag, N of band → een nieuwe beurt.

**Tests** (`games/post/test_post.gd`, 22): `test_een_brief_per_gast_tussen_twee_en_zes`,
`test_groep_3_vakjes_van_vijf_tot_twintig`, `test_groep_4_en_5_vier_tientallen_tot_honderd`,
`test_elke_brief_past_in_een_vakje`, `test_de_voorbeelden_uit_het_ontwerp`,
`test_een_tweede_ronde_is_een_nieuwe_stapel`, `test_elke_zin_past`, `test_definitie_en_scene`,
`test_aanmelding`, `test_de_kamer_bestaat_en_hangt_aan_de_kas`, `test_de_modellen_bakken`,
`test_een_beurt_in_groep_3/4/5`, `test_geen_hulp_na_een_fout`, `test_zonder_postbode`,
`test_herladen_hervat_de_beurt`, `test_na_de_stapel_een_nieuwe_stapel`,
`test_het_kind_kiest_de_postbode`, `test_de_rustende_postkamer`, `test_de_ingang_hangt_aan_de_kar`,
`test_op_vier_schermen`.

---

## 5. Wat de vier gemeen hebben

- Elk spel heeft **rustspullen** (`definitie().rust`) die in de kamer staan als niemand speelt, en
  `mijd` in de kamerdata houdt hun vloer vrij van dwaalplekken en gekochte meubels
  (`test_rooms.gd::test_de_kas_is_een_glazen_kas_achter_het_hotel` kent de lijst: kas, winkels,
  speelzaal, bakkerij, muziekkamer, dakterras, postkamer).  Hun modellen meldt het spel zelf aan
  (`definitie().modellen`); `ArtDecor._extra()` noemt de vier thema-bestanden en
  `ArtDecorVersiering` als laatste, zodat elke oudere naam zijn plek houdt (hun wereldmodellen
  hebben pixelgoudplaten in `tests/gouden_pixel/decor_*`).
- Het dier komt eerst (`ctx.wacht_op`), dan de vraag; het blijft tijdens de beurt bij zijn plek.
- Een groot beeld naast het dier (`KoekjesBord`, `BandNotenbalk`, `SterrenKijker`) waar het
  voxelding met de rekenbalk erbij een postzegel zou zijn — zoals `SpiegelBord` en `FotoScherm`;
  de post heeft geen groot beeld (de kast staat groot genoeg in de kamer).
- Kamergeluid (`Snd.SFEER`, 2026-10-08, bestaande lussen): bakkerij `warm`, muziekkamer
  `speeldoos`, dakterras `wind`, postkamer `tiktak`.
- Een prikbordkaartje per spel (prio 5 of 6, gewone spelchip): ze schuiven de dagrotatie van de
  andere kaartjes één plek op.
- Probe-regels (alleen web): `[probe] koekjes stap=…`, `[probe] band stap=… keuzes=…`,
  `[probe] sterren stap=…`, `[probe] post …`; de strookknoppen heten `kk_kaart_keuzes`,
  `band_som_keuzes`, `st_som_keuzes`, `po_som_keuzes` (speel.js: `<id>#k/4`).

Wat open bleef staat genummerd in PLAN.md §7 (2026-10-08) en in `docs/STATUS-2026-10-08.md`.
