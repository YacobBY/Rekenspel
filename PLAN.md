# PLAN.md — Dierenhotel, ontwikkelfase "het rekenen naar onderen"

Geschreven 2026-09-18 tegen `main` (`e720436`, suite 405 goed / 0 fout / ±153 s).
Dit document is het contract: voor de eigenaar (§7 Voortgang, je kunt na elke
taak stoppen) en voor de agenten die de taken uitvoeren (§4 en §5).

Bronnen: negen verkenningsrapporten, zes ontwerpen, een jury over negen
spelvoorstellen en een haalbaarheidskritiek. Alles wat hieronder als feit
staat is opnieuw in de code nagekeken — waar de verkenning of een ontwerp
ernaast zat, staat de correctie erbij.

---

## 0. Hoe je dit document leest

| ik ben … | ik lees |
|---|---|
| de eigenaar | §1 (de regels), §2.3 (de audittabel), §6 (vragen aan jou), §7 (voortgang) |
| een uitvoerende agent | §5 (werkwijze), dan **alleen jouw taak** in §4 en het bijbehorende stukje §3 |
| de lead (merge) | §3.9 (besliste conflicten), §4 (batches, bestandssets), §5 |

Elke taak in §4 heeft een aankruisvakje. Aangekruist = gemerged op `main`.

---

## 1. Doel en spelregels

De eigenaar wil het spel beter maken. Zijn wensen, samengevat en vertaald naar
regels waar élke taak zich aan houdt:

**R1 — Rekenen eerst.** Binnen één seconde na de tik op een spelknop staat er
een somkaart mét antwoordstrook. Een reis, een animatie, een winkelblad of een
sorteerronde vóór de eerste som is een overtreding.

**R2 — Minstens de helft is rekenen.** Van de handelingen in één beurt is de
helft óf een antwoord kiezen, óf tellen/verdelen/meten met getallen die in de
wereld staan. Sjouwen telt niet mee. Niet-rekenmomenten (snel tikken bij het
zwembad, boenen in de tobbe, de bel luiden, de polonaise) zijn welkom, maar ze
staan **altijd ná** een som, nooit ervoor en nooit in plaats ervan.

**R3 — Het rekenen is niet ontkoombaar.** Een beurt is niet af te ronden (ster,
taakkaartje af) zonder ten minste één som goed te beantwoorden. Er is geen
tweede route langs de som heen.

**R4 — Altijd één duidelijke "Nu"-stap.** Op elk moment weet het kind wat het
nu kan doen en waar. De uitroeptekens blijven; er komt één doorlopend kanaal
bij (de Nu-chip in de rekenbalk, §3.1). Binnen een spel draagt precies één
zichtbaar element de aandachtkleur `UiThema.ZON`.

**R5 — HOTEL.md §9 blijft bindend.** Eén Nederlandse zin van **≤ 8 woorden én
≤ 40 tekens** boven de som, pictogram vooraan op diezelfde regel; hoogstens
vier knoppen per strook, elk met pictogram **én** woord/getal; getallen staan
óp voorwerpen; taakkaartjes ≤ 6 woorden. `Ui.keur_regel` / `Ui.keur_taak`
bewaken het. **Wijziging in deze fase (taak `B5`):** de sommenkaart hangt niet
meer los aan haar voorwerp maar staat in een vaste strook onder de wereld; de
band naar het voorwerp blijft zichtbaar via een wijzertje en een ringetje. Die
alinea wordt in dezelfde commit in HOTEL.md §9 bijgeschreven.

**R6 — Nooit straffen.** Geen kruis, geen klok als druk, geen pogingenlimiet,
niets gaat op slot. Een fout antwoord kost niets en levert een hulptrede op.
Een ster is voor meedoen, nooit voor goed zijn (`Econ.sterren`, `econ.gd:27`).

**R7 — Zacht en rustig.** Aaien kost energie en rekenen vult haar aan; er loopt
niets leeg door de klok en er is geen meter en geen verdrietig dier.

**R8 — De bevroren kern blijft bevroren.** `core/sommen.gd` (1620 regels) blijft
byte-identiek; `tests/test_sommen_kruis.gd` houdt 51 vingerafdrukken over 23 042
gevallen. Nieuwe sommen krijgen een **eigen gezaaide generator naast de kern**
(`Sommen.Prng` / `Sommen.Lcg31` lezen mag) in `games/<id>/beurt.gd`, met een
eigen test. `Sommen.<Spel>` mag alleen gelézen worden.

**R9 — De .md's zijn leidraad, geen wet.** `.fanout/specs/godot/*.md`,
`HOTEL.md` en oude kindzinnen mogen wijken. Wie ze tegenspreekt, **wijzigt de
specparagraaf en de test in dezelfde commit** en zegt het in de
commitboodschap. Wat níet wijkt: R8 en de tien regels hierboven.

**R10 — Nieuwe pictogrammen.** De fontsubset (`fonts/tekens.txt`) is met de hand
gemaakt. **🎭 (1F3AD), 🪞 (1FA9E) en 🧮 (1F9EE) zitten er NIET in** — nagekeken.
🫧 🧸 🎉 🪴 🩷 🐾 💤 📋 💛 wél. Gebruik alleen bestaande tekens; anders eerst
`fonts/maak-fonts.sh` (netwerk + fonttools) en dan pas de zin. `Ui.mist_tekens(zin)`
geeft het antwoord; `tests/test_tekens.gd` faalt erop (maar scant alleen
`res://games`, `res://hotel`, `res://ui` en `res://autoload`).

---

## 2. Wat de verkenning vond

Alle regelnummers zijn tegen de werkboom van 2026-09-18 gecontroleerd. Waar de
verkenner ernaast zat staat het erbij.

### 2.1 Blokkerend

| # | defect | plek | reproductie in één regel |
|---|---|---|---|
| Z1 | **Een drop die op een KNOP landt wordt stil geweigerd.** `Vanglaag` (`scenes/main.tscn:78`) is een broer vóór `Knoplaag` (`:83`); `Hits.maak` hangt elk `UiVangvlak` in `Ui.vanglaag` (`hits.gd:122`), en Godot's `_gui_drop` loopt alleen de ouderketen omhoog en sterft op de `Button` (MOUSE_FILTER_STOP). Hotspots zónder voorwerpvlak (`sl_h*`, `bd_rij*`, `mbvak_*`) hebben helemáál geen onbedekt vangvlak, want `_zet_vangvlak` maakt het dan gelijk aan de knop (`hits.gd:342-352`). | `autoload/hits.gd:116-122`, `:342-352` | Sleep in de receptie de sleutel op een leeg haakje → niets. Tik erop → werkt. Idem: voer in de kar, kar naar de deur, was naar een krat, munt naar de toonbank. |
| Z2 | **De voerkar komt nooit thuis: na één ronde is het spel onbereikbaar.** `World._bouw_dingen` (`world.gd:573-587`) tilt het decorstuk met `sleutel: "kar"` uit de keuken; niets zet het terug. Daarna faalt `Games._plek_van` (`games.gd:216-222`) → `Hits.weg("spel_voerkar")` (`games.gd:191-194`). | `games/voerkar/spel.gd:908`, `:1009` | Speel een ronde uit, ga terug naar de keuken: geen kar, geen 🛒-knop. Alleen een paginaherlaad herstelt het. |
| Z3 | **De tobbe-badstap is onbereikbaar.** `_geslaagd` nodigt alleen `_moet_nog_in_bad()` uit terwijl `_wachtenden()` de bredere `_badgasten()` telt, en de hertekenlus stopt na `tel >= 8` (7,2 s) terwijl een dier uit een slaapkamer 11-15 s onderweg is. | `games/tobbe/spel.gd:883-890`, `:1013-1023` | Open de tobbe zonder 🛁-wens: "4 mogen in de tobbe", geen dier, geen ✓, na 20 s nog niets. |

### 2.2 Hoog

**Rekenen is ontkoombaar (R3-overtredingen)**

- Zwembad: één tik op een te groot getal = botsen = beurt af mét ster. `games/zwembad/spel.gd:387-395` → `:407 ctx.taak_klaar("zwemles")`. 12 van de 13 band-3-banen zo uit te spelen.
- Wekker: twee keer op ✅ tikken zónder te draaien zet de spookwijzers op de doelstand. `games/wekker/spel.gd:703-716` + `:432-440`.
- Bedden: de kaart `? × 5 =` vult haar eigen antwoord in (geen `goed`, geen `keuzes`) en `hulp()` legt de hele rij in één tik. `games/bedden/spel.gd:765-786`, `:978`.
- Sleutels: bij ≤ 4 gasten heeft elk bord precies één `?`, en het antwoord staat al in het antwoordvakje (`🔑30`). `games/sleutels/spel.gd:723`; de kern (`sommen.gd:1241-1250`) is bevroren, dus de oplossing moet in de spellaag.
- Voeren: een tik op een vol bakje voedt de kamer, geeft `Econ.sterren(1, "voeren")` en vinkt `taak_af("voer")` af, buiten het spel om. `autoload/hotel.gd:843-845`.
- Meubels: bij één artikel vervalt de somstap. `games/meubels/spel.gd:763`.
- Herspelen geeft onbeperkt sterren. `spel/ctx.gd:35-40` + `econ.gd:27-31`.

**Het spel begint niet met rekenen (R1-overtredingen)**

- Zwembad: 19-33 s reis, trapje en duik vóór de eerste kaart (`spel.gd:152-159`).
- Hinkel: de keuzes worden pas gebouwd als de gast op zijn steen staat, 11-17 s later (`spel.gd:733-745`).
- Was: 20-40 sorteertikken vóór de eerste vraag (`spel.gd:552-561`).
- Tobbe: soort `eerlijk` (de énige soort op band 3) opent in `vullen` met `0 + 0 = 0` en geen strook (`spel.gd:102`).
- Meubels: opent op het winkelblad (`spel.gd:145`).
- Voerkar: begint wél met een som, maar daarna 40-60 sjouwtikken.

**Beeld en plaatsing**

- De antwoordstrook belandt **boven** de vraag, op telefoon én tablet. `hits.gd:528-539`: kandidaat (a) onder de kaart, (b) bóven de kaart, (c) gedokt aan de voet — (a) en (b) heten allebei `"kleef"`, dus geen test ziet het verschil (`tests/test_hits.gd:215` keurt "boven" goed).
- Op een laag liggend kader (558×289) raakt de strook helemaal los van de kaart en valt terug op het gewone bandenraster.
- **Alle kindtekst zit vast op 14 px** door één klem: `ui/thema.gd:81` `"klein": clampi(round(0.75*basis), VLOER, 14)`. `klein` is de enige maatsleutel met een bovengrens; de chroomknoppen ("Prikbord" 19 px, "Avond" 22 px) zijn daarmee de grootste letters op het scherm — groter dan de som.
- Op de telefoon is 47 % van het kader leeg crème terwijl kaart, strook en naamplaatjes bovenin vechten (`world.gd:283-284` past de kamer in de vólle kaderhoogte; `KADER_ONDER := 132` wordt alleen als camera-offset gebruikt, `world.gd:312`).
- Wekker: kaart en strook verspringen tot 190 px tussen twee tikken (`spel.gd:578-597`); na een misser valt de kaart deels buiten het kader.
- Sleutels: de hele nummerrij springt 414 px na elke misser (`spel.gd:554` via `:366`).
- Hinkel band 4/5: de cijferbordjes overlappen (steek 7 voxels, bordje 9 breed) en het doeltrapje is onzichtbaar (`spel.gd:276-285`, `:319-327`).
- Kraam: de waren liggen op de hoekpunten van het tafelblad, de gast staat 53 voxels verderop midden op het gras (`spel.gd:351-378`).
- Bedden: de gewonnen bedden landen kriskras en overlappen elkaar en de speelmand (`spel.gd:1043-1057`).
- Kaarten zonder som tonen twee lege liniaturen, en de liniatuur loopt dwars door de zinnen (`ui/kaart.gd:191-195`).
- De teller van een sleepbron tekent ónder zijn knop (`ui/bron.gd:31-36`).

**De hotel-lus (zonder eigenaar in de ontwerpen — hier alsnog opgepakt)**

- De drie bordkaartjes staan in **omgekeerde** prioriteitsvolgorde op het scherm (`hotel.gd:1038`: alle drie krijgen `obj: "prikbord"`, waarna `Hits` op diepte sorteert).
- De eerste tik op het prikbord maakt het bord leeg in plaats van het te openen (`hotel.gd:1014`, toggle op een vlag die al `true` staat).
- Deurbadges wijzen nooit naar de gang of de keuken: `wacht_in()` telt alleen gasten wier wensplek ín die kamer ligt (`hotel.gd:1232`, `:351-362`).
- 75 % van de wensen is "eten"; het bad gaat altijd naar index 0; "souvenir" verschijnt pas op dag 9 (`hotel.gd:519`, `:443-476`).
- De ochtendronde is voorbij na de eerste tik (`hotel.gd:975`).
- Buiten de receptie is er geen enkel teken dat er taken openstaan (`ui/hud.gd:55`).
- Spelknoppen dragen nooit een "!"-merkje (`games.gd:205-213`) en het prikbord heeft maar drie plekken.
- Na herladen slaapt elke gast met een bed, midden op de dag, en wordt nooit meer wakker (`hotel.gd:116`).

**Twee correcties op de verkenning** (belangrijk, want er hing planning aan):

1. *"Headless GUI-hittesten werkt niet in Godot 4.7.2, dus een test die de echte
   sleeproute loopt bestaat niet."* — **Onjuist.** `games/voerkar/test_voerkar.gd:719`
   heeft een `_sleep(vp, van, naar)` die echte `InputEventMouseButton`/`MouseMotion`
   in een `SubViewport` duwt; twee tests gebruiken hem (`:671`, `:770`) en ze zijn
   groen in CI. Ze mikken alleen op het **voorwerpvlak** — precies het geval dat
   wérkt. De regressietest van `S1` mikt op het **midden van de knop**.
   Gevolg: `tools/speel.js` is géén voorwaarde en staat niet in dit plan.
2. *"De kar heet `keukenkar` en niet `kar`, dáárom faalt `World.ding`."* —
   **Half.** De dingsleutel ís `"kar"` (`rooms.gd:616`) en `World.ding("kar")`
   werkt. De echte oorzaak is dat `_bouw_dingen` het decorstuk uit `r.decor`
   haalt, zodat `World.mik("kar","keuken")` niets meer vindt zodra het ding
   verhuisd is.

### 2.3 De audittabel per spel

"nu" = gemeten; "na" = na de taken in dit plan.

| spel | R1 begint met rekenen | R2 ≥ helft rekenen | R3 onontkoombaar | taken |
|---|---|---|---|---|
| **bedden** | ✗ kaart vult eigen antwoord in → ✓ | ✓ telwerk | ✗ 2× 🐾 + wolkje = ster → ✓ | `N9`, `N10` |
| **hinkel** | ✗ som pas na 11-17 s → ✓ | ✓ | ✓ | `N5`, `N11` |
| **kraam** | ✓ | ✓ | ✓ | `N7` (beeld) |
| **meubels** | ✗ opent op het winkelblad → ✓ | ~ 6/12 → ✓ | ✗ bij één artikel geen som → ✓ | `N6`, `N12` |
| **sleutels** | ✓ → ✓✓ (sleutel zonder getal) | ~ → ✓ | ✗ één `?` per bord → ✓ | `K1`, `K2` |
| **tobbe** | ✗ `eerlijk` start in `vullen` → ✓ | ~ 1/6 → ✓ | ✗ blind tikken → ✓ | `N4`, `N13` |
| **voerkar** | ✓ → ✓ | ~ 1 som op 40 tikken → ✓ (3 sommen, 2 tikken) | ✗ tweede voerroute → ✓ | `V1`-`V5`, `L1` |
| **was** | ✗ 20-40 sorteertikken → ✓ | ✗ 2/42 → ~ 4/44 | ✓ | `N8` |
| **wekker** | ✓ | ✓ | ✗ 2× ✅ verklapt → ✓ | `N2`, `K3`-`K5` |
| **zwembad** | ✗ 19-33 s → ✓ | ✓ | ✗ botsen = ster → ✓ | `N3`, `N14` |
| **polonaise** *(nieuw)* | ✓ | ✓ 2 kaarten vs 8 tikken | ✓ dans opent pas na 2 antwoorden | `M1`, `M2` |
| **spiegelmaskers** *(nieuw)* | ✓ | ✓ antwoord = voorraad | ✓ | `M3`, `M4` |
| **bellensprint** *(nieuw)* | ✓ | ✓ tussensom per strook | ✓ | `M5` |

Na `S3` bewaakt één gedeelde test (`tests/test_regels.gd`) R1 en R3 voor **elk**
spel, zodat het volgende spel niet ongemerkt wegglijdt.

### 2.4 De twee hete bestanden (hier serialiseert het plan)

Twee bestanden worden door veel taken geraakt en bepalen daarom de lengte van
het plan. Ze staan per batch hoogstens één keer in een taak:

- `autoload/hotel.gd` (1436 regels): `L1` (b5) → `B6` (b6) → `D2` (b7) → `B10` (b8) → `L2` (b9).
- `autoload/rooms.gd` (770 regels): `R2` (b3) → `R3` (b4) → `R4` (b5) → `R5` (b6).

Daarnaast werkt er een **tweede agent** in dezelfde werkboom aan
`autoload/hotel.gd`, `ui/wolk.gd`, `tests/test_hotel.gd` en `tests/test_ui.gd`
(ongecommit, +59/−2). Zijn werk: een const `WENSSPEL`, `wens_spel(behoefte)`,
`tik_wens(gast, behoefte)` en het wenswolkje krijgt klas `"hotwens hint"` met de
gele `UiThema.ZON`-kleur. Elke taak die een van die vier bestanden raakt draagt
de vlag **"raakt het bestand van de tweede agent"** en staat in batch 5 of later.

---

## 3. De ontwerpen zoals ze gebouwd worden

Dit zijn de ontwerpen **ná** de haalbaarheidskritiek. Waar twee ontwerpen
hetzelfde claimden, staat in §3.9 welke taak wint.

### 3.1 De rekenbalk en de Nu-chip

**Besluit (staat vast, niet heropenen): de balk komt er.** Onder de kamer, bínnen
het kader, staat voortaan altijd dezelfde strook: de verplichte zin, daaronder de
som groot, daaronder vier brede antwoordknoppen. De kamer wordt erbóven ingepast,
dus de balk dekt nul wereld af.

**Vorm en maten** (nieuw in `UiThema`: `balk_vorm(kader) -> String` en
`balk_maten(kader) -> Dictionary`; de globale klem van 14 px op `klein` blijft
staan, alleen de balk krijgt eigen grote maten):

| rung | kader in units | vorm | H | zin | som | knop | nu | knophoogte | knopbreedte |
|---|---|---|---|---|---|---|---|---|---|
| A | x ≥ 900, y ≥ 440 (990×637, 1170×669) | hoog | 160 | 22 | 34 | 24 | 21 | 64 | `clamp((x−54)/4, 56, 150)` |
| B | 520 ≤ x < 900, y ≥ 440 (734×788) | hoog | 152 | 21 | 32 | 23 | 20 | 60 | `clamp((x−54)/4, 56, 140)` |
| C | x < 520, y ≥ 440 (326×558) | hoog | 160 | 20 | 30 | 22 | 19 | 60 | `clamp((x−48)/4, 48, 120)` |
| D | y < 440, x ≥ 470 (558×289, 676×320) | laag | 96 | 18 | 26 | 20 | 18 | 60 | `clamp((x*0.48−18)/4, 48, 96)` |
| E | y < 440, x < 470 (296×314) | hoog | 132 | 17 | 24 | 19 | 17 | 52 | `clamp((x−42)/4, 48, 96)` |

Daarna `H = clampi(H, 72, int(kader.y * 0.34))`. De tien kaders die de suite
echt draait staan in `tests/test_ui.gd:8-12` en `tests/test_hits.gd:9-17`
(990×637, 734×788, 1170×669, 326×558, 558×289, 1000×648, 768×1024, 360×740,
296×314, 676×320) — de maattest loopt ze alle tien.

**Het gat dat de kritiek vond, en het antwoord.** Dertien testbestanden roepen
`Ui.registreer_lagen(...)` aan. Nagekeken: de functie heeft **vijf** parameters
waarvan de laatste twee optioneel (`ui.gd:57-58`), en er zijn 18 aanroepen met
vijf argumenten. Daarom geldt: **`Ui.balk_aan()` is waar zodra `World.kader_rect()`
een geldig kader heeft, en `Ui.balk_rect()` wordt puur uit dat kader afgeleid —
zonder Balklaag-node.** De Balklaag tékent alleen. Zo werkt de balk in alle
suites zonder één `registreer_lagen`-aanroep te wijzigen, en bewijst de
acceptatie van `B3` echt iets. De Balklaag komt als **zesde, optionele**
parameter, dus nul testwijzigingen.

**Wat de wereld inlevert.** Twee plekken trekken de balkhoogte af:
`world.gd:283-284` (de échte inpassing: `maxf(120.0, _kader.size.y - 4.0) / nodig_h`
wordt `maxf(120.0, _kader.size.y - 4.0 - _balk) / nodig_h`) en `world.gd:312`
(`onder = minf((KADER_ONDER + _balk) * dicht, maxf(0.0, over))`, camera-offset).
Prijs: op iPad-landschap zakt de voxelstap `g` van 4 naar 3 in receptie en tuin;
op de telefoon kost het niets (daar bindt de breedte en stond 47 % leeg). Zie
open vraag **V2**.

**Hoe kaart en strook in de balk komen.** `Hits` krijgt een nieuw anker `"balk"`
in `_op_van` (`hits.gd:447`), vóór `kleef_aan` getest. `plaats()` (`hits.gd:199`)
zet het balkvlak meteen na `_kaart_vrij.clear()` in `_geplaatst` én `_kaart_vrij`
en reserveert zijn cellen — dan kan geen enkele knop er ooit op landen en blijft
de dekkingsinvariant van `tests/test_hits.gd::_keur` triviaal waar. **Let op:**
`op: "voet"` bestaat al (`hits.gd:482-490`) en claimt exact dezelfde rechthoek
als kleef-kandidaat 3 (`hits.gd:531-532`); die derde kandidaat moet vervallen,
anders vechten balk en strook om hetzelfde vlak. `_blijf_staan` (`hits.gd:311-329`)
weigert al elk anker opnieuw te gebruiken — `"balk"` erbij in de lijst op regel 316.

De aanroep van `Ui.somkaart()` verandert **niet**: alle 38 aanroepplekken blijven
zoals ze zijn, de kaart houdt haar id, haar strook-id `<id>_keuzes`, haar
node-namen (`Kolom/Regel`, `Rij/Som`, `Rij/Vak`, `Hulp`, `Rij/K<id>`) en haar
type. Acht speltests lopen langs `Hits.spot("<id>_keuzes").knoop.get_node("Rij/K<id>")`
— dat blijft werken.

**De haak naar het voorwerp.** `ui/rekenbalk.gd` is één `Control` over het hele
kader (`mouse_filter = IGNORE`, onder `Knoplaag`) dat in één `_draw()` het
balkvlak tekent (gelinieerd papier, lijnen op de regelhoogtes van de balk zelf,
dus nooit meer dwars door een letter zoals in `ui/kaart.gd:191-195`), plus een
driehoekje 12×8 op de bovenrand recht onder het voorwerp en een dun ringetje van
2 px om het voorwerp. Kost **nul hotspots** — belangrijk, want `MAX_PER_KAMER = 16`
en de keuken zit daar al tegenaan.

**Eén ding tegelijk in de balk**, in deze volgorde: **som > melding > Nu-chip**.
Bestaan er twee kaarten tegelijk (check-in + rekening), dan pakt de hoogste prio
de balk en valt de ander terug op de oude `midden`-plaatsing bij zijn voorwerp.

**De Nu-chip.** Een gele pil (`UiThema.ZON`) met links het grijze woordje "Nu",
dan pictogram + tekst (≤ 6 woorden, gemeten met `Ui.keur_taak`), rechts een
kamerchip als het doel elders ligt. Een tik voert `Hotel.doe_taak(q)` uit —
exact dezelfde weg als een bordkaartje (`hotel.gd:973`). Gevuld door een nieuwe
`Hotel.volgende_stap() -> Dictionary`, van dringend naar rustig:

1. een draaiend spel zegt het zelf (`Games.stap_nu()`, gevuld door `ctx.nu(icoon, tekst)`);
2. halve check-in of lopende rekening → `🛎️ Help de nieuwe gast` / `💰 Tel het geld na`;
3. een onvervulde wens in de kamer waar je staat → `🍪 Boef wil eten` (doel = het dier, de balk tekent de ring eromheen);
4. het eerste niet-afgevinkte bordkaartje (**let op: dat vereist `L1`, anders toont de chip de verkeerd gesorteerde taak**);
5. de avond mag → `🌙 Sluit de dag af`;
6. niets → `🐾 Speel lekker rond`.

Standaardtekst als een spel niets zegt: **`📋 Maak eerst de som`** — niet `🧮`,
dat teken zit niet in de fontsubset (R10).

**Kindtekst van de balk** (woorden/tekens zonder pictogram): `🔔 Bel een gast`
3/13 · `🛏 Boef wil een bed` 4/16 · `🍪 Vul de voerkar` 3/15 · `🍪 Boef wil eten`
3/13 · `🛁 Boef wil in de tobbe` 5/21 · `💰 Reken af: Boef` 3/15 ·
`🛎️ Help de nieuwe gast` 4/19 · `💰 Tel het geld na` 4/15 · `🌙 Sluit de dag af`
4/16 · `🐾 Speel lekker rond` 3/18 · `📋 Maak eerst de som` 4/17 ·
`🪙 Leg de munten op de toonbank` 6/28 · `🛏 Kies een bed voor Boef` 5/22 · chiplabel `Nu`.

**Wat blijft bij het voorwerp:** getal-tags (`Ui.getal_tag`), wenswolkjes,
sleepbronnen met teller, wereldknoppen (deuren, bakjes, bel), prijskaartjes.
**Wat naar boven verhuist:** de lof-toast — `Ui.toast` staat voortaan altijd
bovenin (`ui.gd:239-241`, `boven := band.size.y < 450.0 or Ui.balk_aan()`), want
hij stond precies waar de antwoordknoppen komen.

### 3.2 Voeren opnieuw

Het huidige spel is niet kapot maar wel onbegrijpelijk: zestien knoppen in de
keuken, zes bakjes op de vloer (waarvan er één in het fornuis staat), een schep
die op 1 staat en 40 tot 60 losse tikken. Het rekenen duurt 10 seconden, het
sjouwen drie keer zo lang.

**De nieuwe beurt**, scherm voor scherm:

- **S1 — de som (keuken).** Geen decor meer op de vloer: geen bakjes, geen zak,
  geen pot, geen pak-knoppen, geen Klaar, geen Opnieuw. In beeld: de somkaart in
  de balk, de drie deuren, en ná twee missers de Els-knop. Zes knoppen in plaats
  van zestien.
  Kaart: `🍪 Verdeel 40 koekjes over 4 gasten` / `Hoeveel krijgt ieder dier?` /
  `40 : 4` / `[🍪 4] [🍪 10] [🍪 12] [🍪 40]`.
  Goed → fonkels, geluid, **de ster valt hier** (`Econ.sterren(1, ctx.id)`; meedoen
  is verdiend, ook als het kind daarna wegloopt), `K.op_kar = per * n`.
  Fout → nooit straffen: hulpregel `🥄 4 gasten · 40 koekjes`, vanaf de tweede
  misser de knop `🩺 Els helpt` die het getal op de kaart zet.
- **S1b — de pot** (alleen als `rest > 0`, in de praktijk zeldzaam op band 4/5):
  `🫙 Hoeveel blijft er over?`, som leeg, `goed: rest`.
- **S2 — duwen, één tik.** Op de kar één gele knop: `🛒 Duw naar Kamer 1`, met de
  teller van wat er nog op ligt. Een tik verhuist de kar naar een **vrije** cel
  bij het bak-slot (`Rooms.vrij_vak`, fix van "de kar staat dwars door het bed"),
  reist de camera mee en hertekent. Slepen naar een deur blijft bestaan en werkt
  na `S1`, maar is nooit meer nodig.
- **S3 — opscheppen, opnieuw rekenen.** Bij aankomst één wolkje op het bakje:
  `👉 Tik op het bakje`. De bakknop van het hotel wordt geleend
  (`ctx.hotspots.pak("bak_<kamer>_<slot>", _tik_bak)`) en opent de kaart:
  één gast → `🐶 Hoeveel scheppen krijgt Boef?`; twee of meer →
  `🍽 2 gasten, ieder 10 scheppen` met sombalk `2 × 10`. De sombalk verschijnt
  **alleen** als `hier in Sommen.TAFEL_SET[band]`, zodat er nooit een tafel op het
  scherm staat die het kind nog niet mag kennen. Fout → hulpregel met de herhaalde
  optelling `🥄 10 + 10`.
- **S4 — het kind loopt weg.** Staat het kind elders, dan hangt er één tikbaar
  wolkje op de deur: `👉 De kar staat in Kamer 1`. Daarmee is ook gerepareerd dat
  een tik op een deurknop het hele spel liet verdwijnen.
- **S5 — klaar.** `✅ Alle bakjes vol!`, dan in deze volgorde: `ctx.state.tel(...)`
  één keer voor de héle beurt, `ctx.taak_klaar("voer", {"sterren": 0})` (het
  bordkaartje pas nú af — nu de wereld echt gevoerd is), `World.ding_thuis_zet("kar")`
  (zonder de camera mee te nemen) en na 2,6 s `ctx.sluit()`.

**Verhouding:** 3 rekenmomenten tegenover 2 duw-tikken en 1 afsluitende tik.
**Onontkoombaar:** de bakknop is tijdens het rondje geleend en opent een kaart in
plaats van gratis te voeren; buiten het spel geeft hij geen ster meer (`L1`).

**Eén bewuste gedragswijziging in de invoer van de kern:** `deelnemers()` telt
voortaan alleen gasten in een kamer mét een `bak`-slot. Vandaag telt het elke
gast met een bed, terwijl alleen kamer1 en kamer2 een bakje hebben — een gast in
een gekochte kamer kreeg zijn koekjes nooit en het spel zei tóch "Alle bakjes vol".
`Sommen.deel` zelf blijft ongemoeid; alleen N verandert. Noem het in de commit.

**Nieuwe kindtekst:** `Hoeveel krijgt ieder dier?` 4/26 · `Hoeveel blijft er over?`
4/23 · `Hoeveel scheppen krijgt %s?` 4/35 · `%d gasten, ieder %d scheppen` 4/27 ·
`Duw naar %s` 4/16 · `Tik op het bakje` 4/16 · `De kar staat in %s` 6/25 ·
`🩺 Iedereen krijgt %d` 3/20. Vervallen: `T_PAK`, `T_ZAK_TITEL`, `T_NOG_IN_ZAK`,
`T_ZAK_LEEG`, `T_KLAAR`, `T_OPNIEUW`, `T_ERBIJ`, `T_ERAF`, `T_HIER_HOORT`,
`T_SLEEP_DEUR`, `T_SLEEP_HIER`, `T_BRENG`, `T_KEUZE_TITEL`, `T_POT`, `T_GAST_TITEL`,
`T_KAR_NOG`, `T_KAR_TITEL`, `T_KAMER(S)` — die worden **geschrapt** uit de bron,
uit `test_voerkar.gd:251` én uit `.fanout/specs/godot/games-a.md §7.7`, in dezelfde
commit (R9).

**Haken:** `games/voerkar/spel.gd` (`start`, `_teken`, `_kaart_neer`, `check`,
`_rondje`, `duw_naar`, `lever`, `_klaar_met_rondje`, `stop`) · `Sommen.deel`
(`sommen.gd:163-187`, alleen lezen) · `Sommen.TAFEL_SET` (`:189`) ·
`autoload/hotel.gd:1290-1306` bouwt `bak_<kamer>_<slot>` · `World.set_bak`,
`World.feest`, `World.ding_zet` · `Rooms.vrij_vak` (`rooms.gd:329`).

### 3.3 Sleutelbord en wekker

**Sleutels — de beurt wordt twee stappen**, bewaard in `ctx.data()["bord"]["stap"]`
zodat een herlaad ze meeneemt.

- **Stap `reken`.** De sleutel bij de gast draagt **geen getal**:
  `ctx.hotspots.bron(..., {"aantal": 0})`. `UiBron.zet()` verbergt de teller bij 0
  en `_get_drag_data` geeft `null` terug zolang `aantal <= 0` (`bron.gd:67-69`,
  nagekeken) — de sleutel is dus vanzelf nog niet sleepbaar en het rekenen is niet
  te omzeilen: het getal bestáát nog niet. De kaart vraagt het getal met een strook
  van vier; `liever:` = de twee **zichtbare** buren van het gat. Het actieve gat
  (het meest linkse lege haakje) gloeit `UiThema.ZON`.
  Kaart: `Welk nummer mist er?` 4/20 · `Stampertje wacht op zijn sleutel` 5/32 ·
  sombalk = de rij als schrift met het actieve gat als `__` en een later gat als `?`
  · hulp `tel met de sprongen mee` 4/23.
- **Stap `hang`.** De sleutel krijgt het gekozen getal, alle lege haakjes gloeien,
  tikken én slepen werken (dankzij `S1`). Fout haakje = wiebelen + zacht geluid,
  nooit een straf.
  Kaart: `Hang 30 op het lege haakje` 6/27 · `Stampertje krijgt nummer 30` ·
  hulp `sleep of tik het lege haakje` 6/28.
- **Daarna loopt de gast zichtbaar weg**: haakje vullen → `_teken()` → afscheids-
  wolkje `sl_af` → `ctx.wereld.ga(gast, dp.ix, dp.iz)` naar het deurpunt →
  `await na(1.2)` → `ctx.wereld.slaap(...)` → 💡 boven zijn deur in de gang. En
  `_klaar()` veegt dat wolkje niet meer in hetzelfde beeld weg: eerst 1,4 s in de
  receptie blijven, dán naar de gang.
- **Hulpladder, altijd één regel** (`_hulp_tekst()`): stap `hang` →
  `sleep of tik het lege haakje`; misser ≥ 1 → het getallenlijntje **over het gat
  van de sleutel** (niet over het haakje waar het kind naar wees — dat is bug B3);
  misser ≥ 2 → hetzelfde lijntje mét de sprong erachter (`20 … ? … 40   + 10`).
  En `_licht = -1` zodra `_p["nu"]` naar een ander bord springt.
- **`Ui.spreek()` is een lege stub** (`ui.gd:635`, nagekeken) met drie aanroepplekken:
  `games/sleutels/spel.gd:895`, `:912` en `games/meubels/spel.gd:1023`. De eerste
  twee worden korte wolkjes (`🔑 nummer 30`, `🔑 kies eerst het getal`,
  `🔑 welk nummer ben ik?`); de derde wordt in `S4` geschrapt samen met de stub zelf.
- **Het houten rek is geschrapt.** Het ontwerp wilde een nieuw voxelrek plus ~330
  regels opstellingscode stabiliseren. Met de balk verhuist de kaart naar beneden
  en verdwijnt de oorzaak van het 414 px-springen. Wat blijft (`K2`, klein):
  `dx = dx_min + 1` zodat de rij hooguit ~60 % van de kaderbreedte beslaat, de
  opstelling wordt **één keer per beurt** gekozen (bij `start()` en bij een echte
  kaderwissel, niet bij elke `_teken()`), en `_wijk_van_voorwerpen` hoeft alleen
  nog de balk te mijden.

**Wekker.** Het hele wekkerspel hoort bij deze werkstroom (§3.9).

- `N2`: `_s["gedraaid"]` — een tik op ✅ telt alleen als misser wanneer er sinds
  de vorige keuring aan de wijzers is gedraaid. Twee keer tikken zonder draaien
  geeft dus geen missers en geen spookwijzers meer. `klok_params()` eist naast
  `missers >= 2` ook `draaien >= 2`. Beide velden mee in `_bewaar()`.
- `K3`: hulpladder — begin `draai tot de klok klopt` 5/23 (meteen de to-do-regel),
  misser 1 `💛 draai nog wat verder`, misser 2 de telladder `tel_ladder()`
  (`spel.gd:737`, bestaat al), misser 3 `👻 de spookwijzers wijzen mee` én pas dán
  de spookmarkeringen. En `wk_plaat` krijgt prio 15 in plaats van 13, zodat de
  wijzerplaat gereserveerd wordt vóór de kaart geplaatst wordt.
  *De `_hang_kaart`-klem uit het ontwerp vervalt: de balk doet dat werk.*
- `K4` — de wijzerplaat is echt af te lezen: de naaf vóór de wijzers tekenen (nu
  snijdt hij ze door, `spel.gd:427`), de uurwijzer kort en **dik** (`dik` 1.0 → 2.0,
  donkerder) tegenover een lange dunne minuutwijzer, een grotere plaat
  (`R_KAST` 25→30, `R_RAND` 27, `R_PLAAT` 24, `R_STREEP` 20, `R_UUR` 12, `R_MIN` 19),
  12/3/6/9 als echte wiggen met de 12 in een eigen donkerder kleur, en de
  spookwijzers worden **mikpunten** (één bleek blokje van 3×3 op de tip) in plaats
  van een tweede stel wijzers.
- `K5` — het wekmoment. Nieuwe stap `bel` tussen goed antwoord en wakker worden:
  `De klok staat goed` 4/18 / `Luid de wekker` 3/14 / hulp `tik op de bel` 4/13,
  en de strook wordt één knop `🔔 Bel`. Tik → `Snd.bel()`, de belletjes wippen,
  en **dán** pas reist de camera naar de kamer van de gast, waar de kaart weggaat
  en het feest bij het dier hoort (`VOLGENDE_S` 2,2 → 3,2 s). Verlaat het kind de
  gang, dan hangt er op de deur terug een wolkje `⏰ de klok staat in de gang` 6/26.

### 3.4 Aaien en energie

**Het teken staat om** (besluit van de lead, niet heropenen): de teller gaat
**alleen omlaag door aaien** en **alleen omhoog door rekenen**. De klok raakt hem
nooit aan. Op nul weigert het dier niets — het doet een dutje en de knop wijst
naar het rekenen. Wie alleen maar aait, raakt vanzelf door zijn aaien heen; dat
is precies "te lang niet gerekend", maar het kind heeft het zelf uitgegeven in
plaats van het door treuzelen verloren. Aaien is **geen minigame**: het levert
nooit sterren of munten en blokkeert nooit iets.

**Wat het kind ziet.** Onder elk rustig staand dier een knopje `🐾 Aaien`. Tik →
pose `zwaai` (bestaat al in `art/gasten.gd:48` en wordt vandaag nergens gebruikt),
drie roze hartjes, `Snd.hup()`, `aai` 3 → 2. Tweede tik: twee hartjes. Derde tik:
één hartje, `aai` → 0, het dier gaat zitten (`World.pose(id, "zit", 45)`) en zegt
`💤 Boef doet een dutje` 4/21; het knopje wordt `💤 Rust`. Een tik dáárop verwijt
niets maar wijst de weg — om en om `💤 Boef rust even` 3/17 en
`📋 Eerst rekenen, dan aaien` 4/26. Elke som die het kind ergens beantwoordt —
goed óf fout — geeft alle dieren er één aai bij met één hartje boven elk dier in
beeld; elke afgeronde taak vult iedereen; een nieuwe dag ook.

**Waarom geen meter:** HOTEL.md §2 verbiedt meters, elk permanent element per dier
kost een hotspot uit de 16, en de stand staat al op twee plekken die niets kosten —
de knop zelf (`🐾` vs `💤`) en het aantal hartjes dat opstijgt (3 → 2 → 1).

**Opslag:** één geheel getal `aai` op de gast-Dictionary (`State.mk_gast`,
`state.gd:45-51`), `AAI_MAX := 3`, `"aai"` erbij in `const GAST_INT` (`state.gd:300`)
zodat `_normaliseer()` en `_gast_vorm_klopt()` hem gratis bewaken, en een
terugval in `_repareer_gast()` (`state.gd:368`) zodat een oude opslag drie aaien
cadeau krijgt. Vier functies + één signaal op `State`: `aai_van`, `aai_uit`,
`aai_bij`, `aai_vol`, `signal aai_gevuld`. Onderaan `State.tel(goed, ms)`
(`state.gd:518-523`, roept zelf geen `bewaar()` aan) komt
`if aai_bij(1): aai_gevuld.emit()` — **ook bij een fout antwoord**: meedoen telt,
niet correct zijn.

**De knoppen** leven in een nieuw bestand `hotel/aaien.gd` (`class_name HotelAaien
extends RefCounted`), zodat `autoload/hotel.gd` op zes kleine plekken na ongemoeid
blijft. Aaibaar = de gast staat in de kamer in beeld, is niet de gast aan de balie,
`World.dier(id) != null`, en `d.staat` staat in
`["stil","wacht","zit","kijk","snuif","blij","pose","sip"]`. Dat laatste is niet
alleen fysiek juist maar ook de bugpreventie: `World.pose()` roept `_breek(d, false)`
aan en zou een lopende opdracht van een spel afbreken. `knoppen()` stopt helemaal
zodra er een spel in deze kamer draait, er een check-in loopt of er een rekening
open staat. Knop: `op: "onder"` (dus ónder het dier, nul dekking — bewust niet
`op: "aan"`, want een dierrechthoek is `groot` en de knop zou het dier afdekken),
`prio: 5`, `klas: "hotaai"`. Eén regel in `Hits._laag_van` (`hits.gd:435-442`,
nagekeken) zet `"hotaai"` in `Laag.WENS`: de cull knipt van achteren en binnen een
laag eerst de laagste prio, dus in een volle kamer **verdwijnt eerst de aai-knop,
nooit het to-do-signaal**. Dat is de goede kant om te falen, maar het betekent wel
dat aaien in de volle tuin (7 gasten) onzichtbaar is — bewust, en genoteerd.

### 3.5 Kamers, decor en dagvariatie

**Twee nieuwe kamers, niet drie.** De Speelzaal 🧸 (cel [1,1], deur in de receptie)
en de Kas 🪴 (cel [4,1], poort in het tuinhek). De Feestzaal 🎉 valt af voor deze
fase: het spel dat haar zou vullen verloor bij de jury, de feestdag-aankleding kan
in receptie en gang, en elke extra kamer verlengt de `rooms.gd`-ketting met een
hele batch. Zie open vraag **V5**.

De Speelzaal is meteen het huis van het nieuwe spel **Spiegelmaskers** — daarmee is
het conflict opgelost dat het jury-voorstel een tweede, bijna gelijknamige
"Spelzaal" wilde (§3.9).

**Wat een nieuwe kamer raakt** (gemeten, niet gegokt): `Rooms._bouw_kamers()` één
`_kamer({...})`-blok · de deur in de **buurkamer** · `ui/plattegrond.gd KAART` één
cel · `Snd.SFEER` (ontbreken = stil, dat mag) · `tests/test_rooms.gd` vier gouden
tabellen (`ORDE` :11, maten :21-29, kaders :42-51, deurpunten :59-80) ·
`tests/test_plattegrond.gd:60` · `HOTEL.md` §1 · de helpregel van `tools/kiek.js`.
Gratis meebewegend: de kamerbalk, camera, vloer, wanden, `test_art`, `test_hits`,
`test_world`, `test_ui`. De drie iconen 🧸 🪴 🎉 zitten al in `fonts/tekens.txt`.

**Regel voor de gouden tabellen:** kaders en deurpunten worden **geregenereerd uit
een headless run**, nooit overgetypt uit een ontwerp. De voorspelde getallen in de
ontwerpen zijn voorspellingen.

**De Kas en het tuinhek horen bij elkaar.** De poort komt in de **linker** hekwand
(`_bouw_tuin`, `rooms.gd:737-747`): `if z < 34 or z > 46` wordt
`if (z < 34 or z > 46) and (z < 84 or z > 96)`, waardoor de paal op z = 94 vervalt
en `hekz` van 8 naar 7 gaat (`tests/test_rooms.gd:199`). In dezelfde taak schuift
de **hinkelzone** van `z0/z1 34/50` naar `44/60` (`rooms.gd:620`) zodat het pad
vóór de zwembadpoort langs loopt in plaats van erdoorheen — en dan wordt de gouden
pollentabel (`tests/test_rooms.gd:201-212`) **één keer** opnieuw gezaaid. Nooit
twee taken parallel op deze tabel.

**Dagvariatie — `hotel/sier.gd`.** De vaste inrichting blijft precies zoals ze is;
de variatie is **los decor** (`World.decor(kamer, {..., "door": "hotel"})`) dat elke
dag opnieuw wordt neergezet uit één gezaaide `Sommen.Prng` op vooraf vastgelegde
sierplekken. Waarom dat de goedkoopste weg is, in de code gecontroleerd: los decor
staat niet in de opslag, `Games.start()` wist alleen decor van ándere spel-id's
(`games.gd:105-110`), het zit niet in `r.decor` en raakt dus `_cel_vrij`, de
dwaalplekken, de capaciteitsberekening van `bedden` en de gouden pollentabel níet,
en zonder hotspot kost het niets van het plafond van 16 knoppen.

**Haakpunt: `World.zet_dag(dag)`** (`world.gd:748-752`), niet `Hotel.morgen()` —
`zet_dag` wordt al door `morgen()` aangeroepen, dus `autoload/hotel.gd` blijft
ongemoeid. (Dat is de reden dat de twee concurrerende ontwerpen hier samengevoegd
zijn, §3.9.) Determinisme: alleen `dag`, nooit de wandklok.

Sierplekken: balie (bloemen/boeket/bloesem/dennentak), receptiewand (poster of
niets), gangwand (poster of krans — **alleen wand**, de gang heeft maar 4
dwaalplekken), nachtkastje kamer1, boekenplank kamer2, waslijn wasserij (**0-4
stuks**, een telbaar detail), tuin twee plekken, zwembaddek, keukentafel,
speelzaal, en vier plekken op de moesbakken van de Kas waar `groei` met het seizoen
meeloopt. Regel, getest: elke sierplek ligt ≥ 14 voxels manhattan van elke
dwaalplek en elke deurstap, en ≥ 12 van elk vast decorstuk. De dagdressing heeft
**geen enkele tekst** — variatie die je moet lezen is geen variatie.

**Seizoenen:** 7 speeldagen per seizoen, 28 dagen rond (open vraag **V6**).
**Feestdag:** `not State.s["uitcheck"].is_empty()` — de dag dat een gast naar huis
gaat hangt er een slinger en staat er een taart, met één wolkje `🎉 Feest voor Boef!`
3/18. (🎂 zit níet in de fontsubset, 🎉 wél.)

**De gekochte versiering komt écht in de kamer.** `Sommen.Meubels.VERSIERING` kent
vlaggetjes 🎉, bloemetje 🌸, kleurkussen 🩷, ballonslinger 🎈 en sterrensticker ⭐,
maar `_koop_versiering()` (`games/meubels/spel.gd:590`) schrijft alleen een teller.
`HotelSier` krijgt een tabel `VERSIERPLEK: sleutel -> [{kamer, x, z, y, ver}]` en
zet voor teller `n` de eerste `n` plekken neer. Geen nieuwe opslagsleutel, geen
migratie. Het bestaande wolkje krijgt de kamer erbij:
`🎉 Vlaggetjes in de gang!` 4/25 (langste: `🎈 Ballonslinger in de feestzaal!` 4/32).
Dit is de goedkoopste zichtbare winst van het hele decorontwerp.

### 3.6 De hotel-lus

De hotel-lus had in geen enkel ontwerp een eigenaar, terwijl de vier defecten die
erin zitten direct de eigenaarswens "altijd een duidelijke to-do suggestie" raken
en de Nu-chip (§3.1 stap 4) erop leest. Daarom staat hij hier als eigen werkstroom.

**`L1` repareert het bord en de dagronde:**

- De drie bordkaartjes krijgen niet meer alle drie `obj: "prikbord"` maar elk hun
  eigen mikpunt, zodat `Hits` ze niet op diepte omkeert; het kaartje met de hoogste
  prioriteit staat bovenaan (`hotel.gd:1038`).
- De eerste tik opent het bord in plaats van het leeg te maken: `prikbord_tik()`
  wordt geen blinde toggle meer maar kijkt of er ook echt iets op het scherm staat
  (`hotel.gd:1014`, oorzaak: `start()` zet `_bord_open` al op `true` op de lege
  standaardstaat en `render()` ziet daarna geen verschil in `kaart_afdruk()`).
- Een afgevinkt kaartje zakt naar onderen in plaats van de bovenste van drie plekken
  te bezetten (`hotel/prikbord.gd:106`).
- `State.s["ronde"]` blijft "ochtend" tot de ochtendtaken af zijn, in plaats van na
  de allereerste tik op "vrij" te springen (`hotel.gd:975`, `:808`).
- De "🌙 Avond"-knop in de chroombalk krijgt dezelfde poort als de balielamp in de
  wereld: `Hotel.avond_klaar()` (`scenes/main.gd:135` vs `hotel.gd:1262`).
- **Eén voerroute:** `Hotel.tik_bak()` (`hotel.gd:828-855`) laat het eten, het
  wolkje en de vervolgwens staan, maar `Econ.sterren(1, "voeren")` en
  `taak_af("voer")` gaan eruit (`:843-845`). Bij een leeg bakje wordt de toast
  `🍪 Haal eerst de voerkar` 4/24.
- De dode tabel `Hotel.KAART` (`hotel.gd:68-70`) gaat weg — nagekeken: nul
  verwijzingen in de hele repo, `UiPlattegrond.KAART` is de echte.

**`L2` maakt de lus af** (laatste batch, want `hotel.gd`):

- Deurbadges wijzen naar het wérk: `wacht_in()` (`hotel.gd:351-362`) telt nu alleen
  gasten wier wensplek ín de buurkamer ligt, waardoor de gang en de keuken nooit een
  badge krijgen. De badge wordt "hoeveel open stappen liggen er achter deze deur",
  gerekend over het pad (`Rooms.pad`), niet over de directe buur.
- Meer wensvariatie: `nieuwe_wensen()` deelt ook op even dagen uit, het bad roteert
  echt (nu hard aan index 0, `hotel.gd:519`) en "souvenir" en "spelen" komen eerder
  in beeld. Meetlat: over 14 dagen met 4 gasten mag geen enkele wenssoort boven 50 %
  uitkomen (vandaag: eten 42 van 56).
- De dieren komen naar de nieuwe kamers: `plek_van_behoefte` laat `spelen` naar de
  Speelzaal wijzen en `World._kies` mag bij het dwalen één deur verder kijken. Zonder
  dit zijn twee nieuwe kamers twee lege kamers — precies de kwaal die de tuin en het
  zwembad vandaag al hebben.
- De slaapbug: na een herlaad slaapt elke gast met een bed, midden op de dag, en
  wordt nooit meer wakker (`hotel.gd:116-122`); `herstel_wereld` zet bovendien een
  gast in kamer `waar` neer met coördinaten uit een ándere kamer.

### 3.7 De nieuwe minigames

De vijf juryvoorstellen waren eenpagina-kaarten zonder taken of tests. Hier staan
de drie die de lead koos, uitgewerkt tot bouwbaar niveau. **Goed nieuws uit de
verificatie:** een spel wordt gevonden door `res://games/*/` te scannen op
`spel.tscn` (`games.gd:41-59`) — er is **geen registertabel en geen lijst met
spel-id's**. Een nieuw spel raakt dus **nul gedeelde bestanden** en kan altijd
parallel gebouwd worden.

#### 3.7.1 `polonaise` — De polonaise (gang, S, goedkoopst)

Domein: **patronen** (ABAB, AAB/ABC, groeiende rijen) — staat in de curriculumtabel
van IDEAS.md en komt in geen van de tien spellen voor. Nul nieuwe voxelmodellen:
de gasten zelf zijn het materiaal en de loper ligt er al.

```gdscript
func definitie() -> Dictionary:
    return {"naam": "De polonaise", "kamer": "gang",
        "hotspot": {"obj": "kist", "icoon": "🐾", "label": "Polonaise",
            "hoog": 14, "dx": -6, "dz": 8},
        "unlock": func(n, _band): return n >= 3,
        "taak": {"id": "polonaise", "icoon": "🐾",
            "tekst": "Maak een polonaise", "kamer": "gang", "prio": 6}}
```

**Verloop.** (0) Tik → de eerste drie gasten vertrekken met `ctx.wereld.reis(id, "gang")`
en hun plek op de loper wordt meteen met een bleke chip aangekondigd; de kaart staat
er in dezelfde tekenbeurt, dus het kind rekent terwijl ze lopen. (1) **Kaart 1 —
patroon:** vier knoppen mét pictogram én woord (`🐶 hond`, `🐱 poes`, `🐰 konijn`,
`🦆 gans`). Misser: `💛 Kijk: hond, poes, hond …` en de rij licht om en om op;
tweede misser: een bleek spookdier op het lege plekje. (2) Goed → dat dier draaft
naar de staart en het patroon staat er compleet — uitleggen door voordoen.
(3) **Kaart 2 — tellen, en die opent de dans.** (4) **Het spelmoment:** één knop
`🔔 Tik mee` met een wolkje `🔔 Tik mee op de maat` 5/18; de knop pulst door elke
halve seconde zijn badge te wisselen in een `await na(0.5)`-lus — geen aftelklok,
geen faalstaat. Elke tik laat de hele rij één plek vooruit hoppen (`World.stappen`
met pose `spring` + `Snd.hup()` per landing, letterlijk het `_hop`-patroon van
`games/hinkel/spel.gd:834-887`, inclusief de bewaking `mijn != _hop_nr`, anders
vallen de meetel-chips weg). Op de maat: ✨ boven de rij. Acht tikken, ±6 s.
(5) De rij loopt één rondje en elk dier haakt af bij zijn eigen deur. (6) Eindkaart,
`ctx.taak_klaar("polonaise")`, `ctx.state.tel(...)`, sluiten na 3 s.

**Per band.** Band 3: AB-patroon, kaart 2 `🐾 Hoeveel poezen staan er?` 4/23 met
`2 + 2 =`. Band 4: AAB of ABC, kaart 2 `🐾 Hoeveel dieren dansen er?` 4/26 met
`3 × 2 =` of `9 : 3 =` (valt binnen `TAFEL_SET[4]`). Band 5: groeiend patroon in
sprongen, `🐾 Hoeveel sprongen doet de vierde?` 5/32 en `1 + 2 + 3 + 4 =`.
Eigen generator `games/polonaise/beurt.gd` op `Sommen.Prng`, gezaaid op dag en
aantal gasten, met een eigen test; de bevroren kern blijft ongemoeid.

**Kindtekst:** `🐾 Wie komt hierna in de rij?` 6/24 · de drie telvragen hierboven ·
`🔔 Tik mee op de maat` 5/18 · `🎉 Wat een mooie polonaise!` 4/25 ·
`💛 Kijk: hond, poes, hond …`.

**Knoppenbudget:** de gang heeft vier deuren en het wekkericoon; het spel houdt zelf
drie hotspots (kaart, strook, tikknop) en zet de deurknoppen tijdens de dans stil
met `ctx.hotspots.pak/laat`. Het spel zit in `Laag.SPEL` en overleeft de cull.

**Bewaakte zwakte** (jurykritiek): kaart 1 is een patroonvraag, geen sombalk. Daarom
is **kaart 2 verplicht vóór de dans** en is dat een echte som — anders zou R1 te ruim
uitgelegd zijn.

**Tests** (`games/polonaise/test_polonaise.gd`): het patroon is deterministisch per
dag en band; kaart 1 staat er binnen de eerste tekenbeurt; de dansknop bestaat niet
vóór twee goede antwoorden; een misser straft niet en laat dezelfde keuzes staan;
elke kindzin staat woordelijk in de bron en past in `Ui.keur_regel`; dekking 0 % op
vier kaders; een herlaad midden in de dans zet de stand terug.

#### 3.7.2 `spiegel` — Spiegelmaskers (speelzaal, L, hoogste jurycijfer)

Domein: **meetkunde — spiegelbeeld en lijnsymmetrie**. Nul dekking in de tien
bestaande spellen. En spiegelen ís rekenen: verdubbelen (groep 4), twee assen = de
tafel van 4 (groep 5).

**Het sterkste onontkoombaarheidsmechanisme van alle voorstellen: het antwoord ÍS
de voorraad.** De teller op de stickerbak wordt op het gegeven getal gezet
(`ctx.hotspots.bron` met `aantal`), dus je krijgt precies zoveel stippen als je zei.
Verkeerd geteld = te weinig of te veel stickers, en dat merk je meteen aan de bak.

**Kamer.** Woont in de **Speelzaal 🧸** uit `R2` — niet in een tweede, eigen
"Spelzaal" (§3.9). Ingang: 🧸 op de vaste `muziekdoos`/knutseltafel.
**Pictogrammen:** het ontwerp wilde 🎭 en 🪞; die zitten **niet** in de fontsubset.
Gebruikt worden 🧸 (kaart en knop) en 🩷 (stickers) — beide gecontroleerd aanwezig.

**Verloop.** (1) `start()` registreert `spiegel_masker` (de plaat met een raster van
R × K vakjes, de gevulde vakjes als param) en `spiegel_klap` (de scharnierende
spiegel op de vouwlijn). De linkerhelft is al beplakt uit de gezaaide generator; de
somkaart staat er in dezelfde tekenbeurt en er is dan **geen stickerbak en geen
aantikbaar vakje**. (2) Misser 1: `💛 kijk naar de vouwlijn` en de spiegel glimt op;
misser 2: één bleek spookstipje op het vakje dat gespiegeld hoort. (3) Goed → de
stickerbak verschijnt met de teller op het gegeven getal, plus
`🩷 Plak de stippen rechts` 4/22. Tik de bak = sticker in je hand, tik een vakje
rechts. Klopt het: `Snd.plop()` en de teller zakt. Klopt het niet: het stipje glijdt
rustig terug met `Snd.terug()` en `🙃 Nog niet in de spiegel` 5/22 — geen kruis,
niets afgenomen, meteen opnieuw. De vakjes zijn géén aparte knoppen maar **één
vangvlak over de rechterhelft met een raster eronder**, zodat het spel op vijf
hotspots blijft. (4) Band 5: na de verticale as draait de tafel een kwartslag en
komt de horizontale as erbij — en de sombalk die je aan het begin beantwoordde
(`6 × 4 =`) blijkt precies te kloppen met wat je nu ziet. (5) ✓ → de spiegel klapt
dicht met `Snd.tover()`, het masker licht op en zweeft van de tafel, het dier maakt
een pirouette (`World.pose(id, "zwaai", 20)`) en er dwarrelen sterretjes. Daarna
hangt het masker als los decor met `"door": "hotel"` aan de wand — over de dagen
groeit er een **galerij**: een verzamelmoment zonder meter en zonder verval.

**Per band.** Band 3: links liggen 5 stippen, rechts 2 — `🧸 Hoeveel stippen nog
rechts?` 4/26, sombalk `5 − 2 =`. Band 4: `🧸 Hoeveel stippen in totaal?` 4/26,
`7 + 7 =`. Band 5: `🧸 Hoeveel stippen na twee vouwen?` 5/31, `6 × 4 =`. Eigen
gezaaide generator `games/spiegel/beurt.gd` op `Sommen.Prng`, gezaaid op spel-id ^ dag,
met een eigen test. De kern wordt niet aangeraakt.

**Verhouding:** 1 verplichte somkaart + 3-8 plaatsingen die elk een spiegelberekening
zijn ("welk vakje hoort bij dit vakje?"), tegenover één afsluitende animatie van 5 s.

**To-do-regel:** één "!"-merkje tegelijk — op de kaart zolang de som open staat, op
de stickerbak zolang er stippen in zitten, op de ✓ als de helften gelijk zijn.

**Tests:** de generator is deterministisch per dag/band; de kaart staat er in de
eerste tekenbeurt en er bestaat dan geen stickerbak; de teller van de bak is gelijk
aan het gegeven antwoord; een fout vakje verandert niets aan de teller; twee assen
op band 5; dekking 0 % op vier kaders; elke kindzin woordelijk in de bron;
`Ui.mist_tekens` leeg voor elke zin.

#### 3.7.3 `sprint` — Bellensprint (zwembad, L, optioneel)

Dit is de letterlijke wens van de eigenaar ("snel tikken bij het zwembad per
strook"). De jury vond hem leuk maar waarschuwde: het is een tweede zwemspel in
dezelfde baan met dezelfde houding — "zwemles 2". Daarom in twee stappen:

- **`N14` (batch 5) bouwt het tikmoment ín de bestaande zwemles.** Na `N3` heeft de
  zwemles al een lus per etappe; de haak ligt klaar in `_zwem`'s `per_stap`-callback
  (`games/zwembad/spel.gd:369-380`). Tijdens het zwemmen hangt er één knop op de
  zwemmer (`🫧 Tik!`, badge "!") met het wolkje `🫧 Tik snel mee!` 3/14. Elke tik is
  één zwemslag: `Snd.plop(1)`, drie zeepbelletjes, en `d.beweeg_tempo` omhoog met
  0,12 (geklemd op 0,6..2,2). **Nagekeken: dat kost nul motorwijziging** —
  `beweeg_tempo` is een gewoon veld op `World.Dier` (`world.gd:112`), wordt door
  `stappen()` gezet (`:855`) en elke wereldtik gelezen (`:1425`). Niet tikken kan
  ook: op het basistempo komt hij er altijd. In rustmodus verschijnt de knop niet.
  Dit is **S**, en het is de hele eigenaarswens.
- **`M5` (batch 9, optioneel) bouwt het losse spel.** Wat het toevoegt boven `N14`:
  de openingssom bepaalt het **speelveld** (`🫧 Hoeveel stroken van 2 meter?`, en de
  drijflijnen zakken pas ná het goede antwoord in het water), en **elke drijflijn
  heeft zijn eigen tussensom** (`🫧 Hoeveel meter heeft hij nu?` 5/27) — zonder die
  som gaat de sprint niet verder. Dat maakt het rekenen onontkoombaar tot aan de
  finish, niet alleen bij de start. Ingang op het dek aan de **overkant**
  (`plant`, `rooms.gd:650`), zodat de zwemles op het startblok blijft. Band 3
  vermijdt het deelteken: `🫧 Hoeveel stroken van 2 meter?` met sombalk `2 + 2 + 2 =`
  (herhaald optellen) in plaats van `8 : 2 =` — de bevroren kern legt zelf vast dat
  groep 3 het deelteken nog niet kent, en twee juryleden struikelden hierover.
  Eigen generator `games/sprint/beurt.gd` op `Sommen.Lcg31`, hergebruik van
  `ZwembadBeurt.baan_x/baan_z/rand_z/blok_x` (statische, wereldvrije helpers).

De eigenaar beslist na `N14` of `M5` er nog moet komen (open vraag **V7**).

### 3.8 Nakijkreparaties

Negentien voorgestelde reparaties, na de kritiek teruggebracht en verdeeld. Per
spel staat het doel hier; de stappen staan bij de taak.

- **Zwembad** (`N3`): `_begin()` wordt `_zet_gasttag(); _vraag()` — de reis, de vier
  trapjes en de duik verhuizen naar ná het eerste antwoord en worden daarmee de
  belóning in plaats van de wachtkamer. `_bots()` doet alleen nog de plons; bij
  `soort == "ver"` zwemt hij de rest, botst, zwemt terug naar zijn oude plek en de
  vraag komt terug — **nooit meer `_afronden`**. Daarmee is het vinkje op de
  eindkaart eerlijk en is hulptrede 3 eindelijk bereikbaar. Nieuwe kaartregel:
  `🙃 Te ver, hij tikt de rand` 6/24. *Dit gaat in tegen een in de code vastgelegde
  beslissing (`games/zwembad/spel.gd:406-408`: "de ster hoort bij het BEREIKEN van de
  overkant") — zie open vraag **V1**, met het antwoord dat het plan aanneemt.*
- **Tobbe** (`N4`): `"stap": "vraag"` voor alle drie de soorten, dus ook `eerlijk`
  (de énige soort op band 3). Nieuwe tak in `_teken_vraag`: bij `M == 2` de som
  `helft van %d =`, bij `M == 3` `%d : %d =`; regel `%d schepjes, %d tobbes` 4/21,
  regel2 `Hoeveel in elke tobbe?` 4/22. En `_antwoord` vult **niets** meer zelf in —
  bij `half` blijft al het sop in tob[0] en haalt het kind het antwoord met één tik
  op 🚰 halveren of door over te gieten. Daarmee is `half` eindelijk een som **én**
  een handeling.
- **Tobbe badstap** (`N13`, blokkerend): `_geslaagd()` nodigt dezelfde dieren uit
  die `_wachtenden()` telt; de hertekenlus telt door zolang er iemand onderweg is
  (plafond 30 × 0,9 s in plaats van 8); en een nieuwe `World.in_kuip(id, x, z, hoogte)`
  naar het voorbeeld van `_in_bed` (`world.gd:1021-1036`) zet het dier écht ín de
  kuip met pose `zit` en zeepbellen — vandaag staat het ernaast.
- **Bedden** (`N9`, `N10`): nieuwe eerste fase `"vraag"` met `%d × %d =`, `goed: _doel()`
  en vier knoppen `🛏 <n>`; regel `Hoeveel bedden heb je nodig?` 5/28. Pas na het goede
  antwoord verschijnen de strookjes, de kist en 🐾. Het 🐑-wolkje legt **één** bedje in
  plaats van de hele rij. De deur is weer een deur (niet langer de controleknop —
  dat gaat in tegen `games-a.md §3.5`, zie open vraag **V3**). En `_bed_raster()` legt
  de gewonnen bedden in echte rijen: groepeer de vrije cellen op z-band (±6), minstens
  36 voxels x-afstand en 20 voxels z-afstand, rechthoekbotsing in plaats van manhattan
  — want het bedmodel beslaat 34 × 17 voxels terwijl `Rooms` op 15/18 filtert.
- **Was** (`N8`): stap `"vraag0"` vóór het sorteren (band 3/4 `Hoeveel stuks liggen er?`
  4/24 met `goed = T`; band 5 `Hoeveel blokjes worden dat?` 4/27 met `goed = T/2`), en
  een tussensom `Hoeveel liggen er nog?` 4/22 halverwege, alleen bij `T >= 8`. De berg
  krijgt pictogram 🧹 in plaats van 🧺, zodat berg en de soort "doeken" niet meer
  hetzelfde plaatje dragen. *De strook-plaatsingsreparatie (`_heeft_pad`) vervalt: de
  balk beslist de plaatsing.*
- **Meubels** (`N6`, `N12`): het spel opent met een kassavraag in de wereld in plaats
  van met het winkelblad — `Hoeveel euro heb je?` 4/20, `goed: _munten()`, knoppen
  `🪙 €<n>`, met de buidel als `Ui.bron` op de toonbank. **Met nul munten meteen door
  naar het boek met een wolkje `💰 Nog geen munten`** (anders is `goed = 0` en staan er
  vier afleiders rond nul). Daarna: een rustige kamer tijdens het plaatsen (de
  hotelknoppen weg, zoals `bedden` dat al doet), `mb_boek` in de kamer waar de camera
  staat in plaats van hard in de receptie, de vier ✨-plekken verspreid door de kamer
  (sorteren op afstand tot het dichtstbijzijnde **gelijksoortige** meubel in plaats van
  tot de deur), 🔄 draaien voor élk eigen meubel, en het plafond van drie bedienbare
  stukken per kamer naar zes.
- **Hinkel** (`N5`, `N11`): op band 4/5 nog maar een bordje op elke twintig
  (`i % 4 == 0` → 0, 20, 40, 60, 80, 100) en de om-en-om-lift vervalt — steek tussen
  bordjes wordt 14 voxels = 28·g px tegenover 18·g px bordbreedte. Het doelgetal gaat
  een rij omhoog en de vlaggenmast wordt hoger, zodat het trapje boven het dier uitkomt.
  En de strook staat er meteen: een antwoord dat vóór de aankomst van het dier valt
  wordt bewaard in `_s["wacht_keuze"]` en uitgevoerd zodra hij op zijn steen staat.
- **Kraam** (`N7`): spreiding ±6 in plaats van ±8 (het blad is x −11..+11, z −8..+8,
  dus ±8 valt precies op de hoeken), bij vier waren twee ondiepe rijtjes, de gast
  vóór de toonbank (dezelfde schermkolom, ±16 voxels naar de kijker) in plaats van 53
  voxels verderop op het gras, en in de betaalstap `Nog €%d erbij` 3/12 zodra er iets
  ligt (nu leest de kaart "€11 €0").
- **Sterren** (`N1`): één ster per spel per dag. `spel/ctx.gd:35-40` geeft alleen een
  ster als `State.ster_gehad(id)` onwaar is; bewaard in de bestaande, al opgeslagen
  `s["gezien"]` met sleutel `"ster_" + id` en het dagnummer als waarde, zodat het
  opslagformaat v1 niet verandert. Het taakkaartje wordt nog steeds afgevinkt, het
  adaptieve signaal telt nog steeds mee, herspelen mag — het levert alleen geen
  tweede ster op. In dezelfde taak: `taak_klaar` slaat `Econ.sterren` over bij
  `sterren <= 0`, zodat `voerkar` het vinkje kan zetten zonder een tweede ster.
- **Zwembad en tuin aankleden** (`R4`): een lage tegelrand achter het water (nagerekend:
  van x = 24 met stap 14 valt élke `hekx` tussen `bad.x0 = 18` en `bad.x1 = 134` weg,
  dus er staat vandaag precies één paal op x = 136 en verder geen achterrand), plus
  twee ligbedden, een parasol, een handdoekenrek en een duikplank op de lege
  rechterhelft, en badeendjes op het water. Alles weg van z = 46 en z = 50, waar de
  meterstreepjes en de vlag van het zwemspel liggen.

### 3.9 De besliste conflicten — wie wint

| conflict | beslissing |
|---|---|
| Drie ontwerpen bouwen dezelfde sleepreparatie (voeren V2, sleutels T1, nakijken T01) | **`S1` wint**, één keer, als eerste taak van het plan. De andere twee vervallen. `S1` neemt het beste uit alle drie: `Hits.vang_onder(punt, lading)` uit sleutels (dekt óók het geval dat een vréémd Control over het doel ligt), het testvoorstel uit nakijken (echte muisdrag naar het **midden van de knop**) en `Hits.zet_drop()` uit voeren. `_drop_data` geeft het punt in **doelcoördinaten** door (vandaag gaat de lokale `at` van de bron naar het vangvlak van het doel — `ui/vangvlak.gd:29` negeert hem, dus het valt niet op, maar het is fout van constructie). |
| Twee ontwerpen claimen het hele wekkerspel (sleutels T5/T6/T7 vs nakijken T07/T08) | **Sleutels wint**, want die behandeling bevat ook de wijzerplaat en het belmoment. `N2` (de ✅-lek) blijft als losse S-taak vooraan staan omdat hij de flagrantste R3-overtreding van alle spellen is en nergens van afhangt. Nakijken T08 (kaart en strook laten staan) **vervalt**: de balk doet dat werk. Nakijken's observatie dat `wk_plaat` prio 13 < kaart prio 14 gaat mee in `K3`. |
| Twee ontwerpen bouwen dagvariatie (kamers K5/K6 vs nakijken T19) | **Samengevoegd tot `R6`/`R7`**, met **het haakpunt van T19** (`World.zet_dag()`, raakt `autoload/hotel.gd` niet) en **de inhoud van K5/K6** (sierplekken, seizoenen, feestdag). |
| Kamers K4 (kas, tuinhek) vs nakijken T17 (hinkelzone) — één gouden tuintabel | **Samengevoegd tot `R3`.** Eerst het hek, dan de zone, en de pollentabel wordt **één keer** geregenereerd. Nooit parallel. |
| Kamers K2 "Speelzaal" vs het juryspel-voorstel "Spelzaal" — twee speelzalen in vier vrije cellen | **`R2` bouwt één Speelzaal 🧸** en het spel `spiegel` woont daarin (`M3`/`M4`). Geen tweede zaal. |
| De rekenbalk vs de plaatsingsinvestering van sleutels T3, nakijken T08/T09 | **De balk wint** (besluit van de lead). Sleutels T3 (het houten rek, ~330 regels opstellingscode) **vervalt**; wat overblijft is de krimp van de rij in `K2`. Nakijken T08 **vervalt**. Nakijken T09 krimpt tot de lege-liniatuur-reparatie in `ui/kaart.gd`, die in **`B4`** landt (één eigenaar voor die functie). |
| Rekenbalk T6 vs voeren V3/V4 — dezelfde kaartplaatsing in `games/voerkar/spel.gd` | **Voeren eerst** (`V2`-`V4`, batch 3-5), **`B8` daarna** (batch 6). `B8` haalt alleen nog de plaatsingshacks weg die er waren omdat de kaart aan haar voorwerp hing. |
| Nakijken T18 vs voeren V4 stap 1 — dezelfde vier regels in `spel/ctx.gd:35-40` | **Samengevoegd in `N1`.** Eén taak, beide gedragingen. |
| Rekenbalk T2 stap 5 vs nakijken T09 stap 3 — dezelfde zichtbaarheidslogica in `ui/kaart.gd` | **`B4` is de enige eigenaar** van `som_label`/`vak_label`-zichtbaarheid. |
| Kamers K3 (`matten` ongetypt) vs het juryspel `poets` | `poets` zit niet in dit plan; de typewijziging `var matten = {}` zit in **`R2`** en is daarmee gratis beschikbaar als `poets` later komt. |
| `Hotel.KAART` (dood) — kamers K1 wil hem weg, K5 wil er twee regels in | **Weg**, in **`L1`** (de enige `hotel.gd`-taak die vroeg genoeg staat). `R1` doet de testkant zonder `hotel.gd` aan te raken. |
| Aaien AAI-2 vs kamers-decor: waar hoort de aai-interactie thuis? | De **kussenhoek in de Speelzaal** is een lighoek, geen tweede aai-mechaniek. Eén gedrag, overal hetzelfde. |
| Sleutels T0 (`tools/speel.js`) als voorwaarde voor de sleepfix | **Geschrapt.** De premisse ("headless sleeptesten kan niet") is onjuist — zie §2.2. `S1` krijgt een echte headless regressietest. |
| Voeren V9 (koekjes vangen onderweg) en V8 (de kar vult zichtbaar) | **Geschrapt** uit deze fase: ze repareren niets en vullen geen wens in. De haken blijven beschreven, de eigenaar kan ze later vragen. |
| Aaien AAI-3 (hartjes in plaats van roze blokjes) | **Optioneel** (`D3`, laatste batch). Roze blokjes kosten niets aan begrijpelijkheid. |
| Drie kamers (Speelzaal, Feestzaal, Kas) | **Twee**: Speelzaal en Kas. De Feestzaal is open vraag **V5**. |

---

## 4. Takenlijst

**58 taken in 9 batches.** Binnen een batch mogen alle taken **tegelijk** in
aparte worktrees draaien: hun bestandsverzamelingen zijn disjunct (per batch
nagelopen, zie de tabellen). Batches draaien in volgorde. Elke taak is in één
zitting te doen (≤ ±400 gewijzigde regels), headless te bewijzen en los te
committeren. **Model van elke taak: `opus`** (effort max). "fable" komt alleen
voor als de review-/merge-stap van de lead, nooit als eigenaar van een taak.

🔎 = **blind check**: de lead laat deze taak door een verse agent verifiëren die
de opdracht wél maar de redenering van de uitvoerder níet krijgt.
⚠️ = raakt een bestand van de tweede agent (`autoload/hotel.gd`, `ui/wolk.gd`,
`tests/test_hotel.gd`, `tests/test_ui.gd`) — pas inplannen nadat die gecommit heeft,
en begin de taak met `git diff <bestand>`.

---

### Batch 1 — Fundament en blokkerende bugs

*Doel: de sleep werkt, de voerkar is weer bereikbaar, de balkmaten bestaan, het
kamerfundament staat, en twee R3-overtredingen zijn weg.*

| taak | bestanden |
|---|---|
| `S1` | `autoload/hits.gd`, `ui/hotknop.gd`, `ui/bron.gd`, `ui/kaart.gd`, `ui/keuzestrook.gd`, `tests/test_hits.gd`, `games/sleutels/test_sleutels.gd` |
| `B1` | `ui/thema.gd`, `tests/test_balk.gd` *(nieuw)* |
| `R1` | `tests/test_rooms.gd`, `tests/test_plattegrond.gd`, `tests/test_kamerbalk.gd` *(nieuw)*, `ui/kamerbalk.gd`, `AGENTS.md` |
| `V1` | `autoload/world.gd`, `autoload/games.gd`, `games/voerkar/spel.gd`, `games/voerkar/test_voerkar.gd`, `tests/test_world.gd` |
| `N1` | `spel/ctx.gd`, `autoload/state.gd`, `tests/test_state.gd` |
| `N2` | `games/wekker/spel.gd`, `games/wekker/test_wekker.gd` |

*Overlap gecontroleerd: geen enkel bestand komt twee keer voor.*

#### `S1` — Slepen op een knop komt aan, in elk minispel 🔎
- [x] omvang **M** · model **opus** · hangt af van: —
- **stappen** 1) Nieuw in `autoload/hits.gd`: `func vang_onder(punt: Vector2, lading: Variant) -> UiVangvlak` — loop `_volgorde` af, sla spots zonder vangvlak / niet zichtbaar / waarvan `get_global_rect()` het punt niet bevat over, vraag de rest `_can_drop_data` (zodat de `drop-hot`-gloed van `ui/vangvlak.gd:36` aangaat) en geef het vangvlak met het **kleinste oppervlak** terug (meest specifieke doel). Koel alle andere via een helper `_koel_vangvlakken(behalve)`, anders blijft er een gloeiend haakje achter als de vinger wegtrekt. 2) Voeg in `ui/hotknop.gd`, `ui/bron.gd`, `ui/kaart.gd` en `ui/keuzestrook.gd` telkens dezelfde twee virtuals toe: `_can_drop_data` geeft `Hits.vang_onder(get_global_position() + at, lading) != null`; `_drop_data` zoekt hetzelfde vangvlak en roept `v._drop_data(punt - v.get_global_position(), lading)` aan — **in doelcoördinaten**, niet de lokale `at` van de bron. Verder niets aanraken. 3) Nieuwe publieke `Hits.zet_drop(id, drop, val, data = {}) -> bool` die Spot, vangvlak én knop in één keer bijwerkt. 4) `games/sleutels/test_sleutels.gd:_hang()` laat het slepen niet meer via `s.vangvlak._drop_data` lopen maar via `s.knoop._can_drop_data/_drop_data` — die test dekte de bug af.
- **acceptatie** `DH_TEST_FILTER=test_hits tools/test.sh` groen met drie nieuwe tests: (a) **een echte muisdrag door een `SubViewport` die loslaat op het MIDDEN VAN DE KNOP** van een drop-hotspot zónder `obj`/`vlak` roept `val` precies één keer aan — neem de helper `_sleep(vp, van, naar)` uit `games/voerkar/test_voerkar.gd:719` over (die werkt aantoonbaar headless; de bewering dat dat niet kan is onjuist); (b) een lading met een andere `sleep`-naam vuurt niets; (c) een **vreemd Control** bovenop het vangvlak (bouw een somkaart die het doel overlapt) schakelt óók door. Daarna **één keer volledig** `DH_TEST_FILTER=games tools/test.sh` (±170 s): deze fix raakt alle spellen tegelijk. Beeld: `tools/export.sh`, dan `node tools/kiek.js --kamer wasserij --band 4 --tik spel_was --uit /tmp/s1` en een eigen sleepproef berg → midden van de kratknop; de krat moet tijdens het slepen mint oplichten en de probe-regel `was=sorteer` moet verschijnen.

#### `B1` — De balkmaten in het thema
- [x] omvang **S** · model **opus** · hangt af van: —
- **stappen** 1) `UiThema.balk_vorm(kader) -> String` en `UiThema.balk_maten(kader) -> Dictionary` met exact de tabel uit §3.1 (rungs A-E, sleutels `vorm, hoog, zin, som, knop, nu, knop_hoog, knop_breed`), gevolgd door `H = clampi(H, 72, int(kader.y * 0.34))`. 2) Nog géén hysterese (dat is `B5`) en nog geen node. 3) De globale klem op `klein` (`thema.gd:81`) blijft ongemoeid — die voedt 28 plekken; alleen de balk krijgt eigen grote maten. 4) Nieuw `tests/test_balk.gd` (`extends Proef`).
- **acceptatie** `DH_TEST_FILTER=test_balk tools/test.sh` groen: voor elk van de **tien** kaders uit `tests/test_ui.gd:8-12` + `tests/test_hits.gd:9-17` levert `balk_maten` de vorm en de hoogte uit de tabel, ligt elke lettermaat ≥ `UiThema.VLOER` (12), is elke knop ≥ 48×48 (44 alleen onder een 360 px scherm), en past `4 * knop_breed + 3 * 8 <= kader.x - 12` in vorm `hoog` respectievelijk het rechterblok in vorm `laag`. `DH_TEST_FILTER=test_ui tools/test.sh` blijft groen (niets bestaands verandert).

#### `R1` — Kamerfundament: het hotel telt zijn eigen kamers
- [x] omvang **S** · model **opus** · hangt af van: —
- **stappen** 1) `tests/test_rooms.gd:15` `gelijk(Rooms.lijst().size(), 8, "acht kamers")` wordt `gelijk(Rooms.lijst().size(), ORDE.size(), ...)`. 2) Nieuwe test `test_elke_kamer_is_compleet()` — de checklist voor elke volgende kamer: voor elke id in `Rooms.lijst()` geldt (a) `UiPlattegrond.KAART.has(id)`, (b) `r.vloer ∈ {hout, tegel, zacht, loper, gras}`, (c) `r.deuren.size() >= 1` en elke `naar` bestaat, (d) `Rooms.pad("receptie", id).size() > 0`, (e) `r.plekken.size() >= 8` (gang: >= 4), (f) elk model uit `Rooms.gebruikte_modellen()` bestaat in `Art`, (g) `r.icoon` en `r.naam` niet leeg. 3) `tests/test_plattegrond.gd:60` `KAART.size() == 8` wordt `== Rooms.lijst().size()`, plus een lus die voor élke kamer een cel eist. 4) Nieuw `tests/test_kamerbalk.gd`: `pas_aan()` op de vier kaders 1024×768, 768×1024, 360×740, 740×360 houdt elke chip binnen de balk en `kolommen() >= 1`; in de rail-modus wordt de balk niet hoger dan de hoogte die hij meekrijgt. Loopt `_meet_rail` bij 11+ chips over zijn budget, voeg dan één trap toe aan `trappen` (icoon 14, woord `VLOER`). 5) `AGENTS.md` regels 35 en 133: "eight rooms" → "the rooms as data". **Raak `autoload/hotel.gd` niet aan** — de dode `Hotel.KAART` gaat weg in `L1`.
- **acceptatie** `DH_TEST_FILTER=test_rooms`, `=test_plattegrond`, `=test_kamerbalk` alle drie 0 fout. Beeld: `node tools/kiek.js --kamer receptie --chip kaart --uit /tmp/r1` toont de plattegrond ongewijzigd met acht cellen.

#### `V1` — De voerkar komt altijd thuis 🔎
- [x] omvang **S** · model **opus** · hangt af van: —
- **stappen** 1) `World._bouw_dingen()` (`world.gd:573-587`) onthoudt per ding zijn startplek in `_dingen_thuis[id] = {kamer, x, z, hoog, model}` — een kopie, vóór het uit `r.decor` wordt gehaald. 2) Twee functies naast `World.ding()` (`:589`): `ding_thuis(id) -> Dictionary` en `ding_thuis_zet(id) -> Dictionary` (zet het ding terug op plek én oorspronkelijk model, roept `vuil()` aan). 3) `Games._plek_van()` (`games.gd:216-222`): staat het ding in een andere kamer, val dan terug op `World.ding_thuis(obj)` als díe thuisplek in deze kamer ligt — dan hangt `spel_voerkar` weer in de keuken ook als de kar nog in kamer2 staat. Gedrag voor een ding dat wél in deze kamer staat blijft gelijk. 4) `games/voerkar/spel.gd`: `stop()` (`:158`) en `_klaar_met_rondje()` (`:1009`) roepen `ctx.wereld.ding_thuis_zet("kar")` aan; in `_klaar_met_rondje()` **zonder** de camera mee te nemen.
- **acceptatie** `DH_TEST_FILTER=voerkar` en `=test_world` groen, met twee nieuwe tests: `ding_thuis("kar")` geeft de keuken (48, 66) terug en `ding_thuis_zet` herstelt dat na een `zet_ding` naar kamer2; en `test_kar_staat_na_de_ronde_weer_in_de_keuken()` — hele ronde spelen, daarna `World.ding("kar")["kamer"] == "keuken"` en `Games.hersteek()` in de keuken levert een zichtbare hotspot `spel_voerkar`. Beeld: `node tools/kiek.js --kamer keuken --band 4 --uit /tmp/v1` ná een volledige ronde toont de kar én de knop 🛒 Voerkar.

#### `N1` — Eén ster per spel per dag, en een taak zonder ster
- [x] omvang **S** · model **opus** · hangt af van: —
- **stappen** 1) Twee helpers in `autoload/state.gd` naast `gezien`/`zet_gezien` (`:412-417`): `ster_gehad(spel) -> bool` (waar als `s["gezien"].get("ster_" + spel, 0) == s["dag"]`) en `zet_ster(spel)`. `gezien` staat al in `standaard()` en draagt al ints, dus het opslagformaat v1 verandert niet — controleer dat expliciet in de test. 2) `spel/ctx.gd:taak_klaar` (`:35-40`): roep `Econ.sterren(...)` alleen aan als `State.ster_gehad(id)` onwaar is **én** `o.get("sterren", 1) > 0`, en zet daarna `State.zet_ster(id)`. Het taakkaartje wordt nog steeds afgevinkt en het adaptieve signaal telt nog steeds mee. 3) Laat `Hotel.morgen()` ongemoeid — de dagvergelijking maakt opruimen overbodig, en `hotel.gd` is van de tweede agent.
- **acceptatie** `DH_TEST_FILTER=test_state tools/test.sh` groen met `test_een_spel_geeft_een_ster_per_dag` (twee keer `taak_klaar("zwemles")` op dezelfde dag = één ster; na `dag += 1` weer één), `test_sterren_nul_slaat_de_ster_over` en `test_de_opslag_overleeft_de_sterdag`. Plus `DH_TEST_FILTER=hinkel`, `=tobbe`, `=kraam`, `=zwembad` groen (hun eindtests tellen sterren).

#### `N2` — Wekker: twee keer ✅ verklapt de wijzerstand niet meer
- [x] omvang **S** · model **opus** · hangt af van: —
- **stappen** 1) `draai(stap_min)` (`games/wekker/spel.gd:681`) verhoogt `_s["draaien"]`. 2) `klaar_tik()` (`:703-716`): is er sinds de vorige keuring niets gedraaid (`int(_s.get("draaien",0)) == int(_s.get("gekeurd",-1))`), dan géén misser — alleen `Snd.zacht()` en de hulpregel `💛 draai eerst aan de wijzers` (5 woorden, 26 tekens). Anders `_s["gekeurd"] = _s["draaien"]` en de misser telt zoals nu. 3) `klok_params()` (`:432-440`) eist naast `missers >= 2` ook `draaien >= 2`. 4) Beide velden mee in `_bewaar()` en in de normalisatie van de stand (JSON maakt er floats van). 5) Werk de woordelijke teksttest (`test_wekker.gd:548-652`) bij.
- **acceptatie** `DH_TEST_FILTER=wekker tools/test.sh` groen (21 bestaande + 2 nieuwe): `test_klaar_zonder_draaien_telt_geen_misser` (twee keer `klaar_tik()` zonder `draai()` → `missers == 0` en `klok_params()` heeft geen `spookU`/`spookM`) en `test_spookwijzers_pas_na_twee_echte_pogingen`. Beeld: `node tools/kiek.js --kamer gang --band 4 --tik spel_wekker --uit /tmp/n2` plus een eigen driver die twee keer ✅ tikt — de wijzerplaat toont geen tweede stel wijzers.

---

### Batch 2 — De balk staat, en de eerste regelovertredingen zijn weg

*Doel: onder de wereld verschijnt een lege papierstrook en de kamer staat erbóven;
vier spellen beginnen voortaan met rekenen.*

| taak | bestanden |
|---|---|
| `B2` | `ui/rekenbalk.gd` *(nieuw)*, `autoload/world.gd`, `autoload/ui.gd`, `autoload/hits.gd`, `scenes/main.tscn`, `scenes/main.gd`, `tests/test_balk.gd` |
| `D1` | `autoload/state.gd`, `tests/test_aaien.gd` *(nieuw)* |
| `N3` | `games/zwembad/spel.gd`, `games/zwembad/beurt.gd`, `games/zwembad/test_zwembad.gd` |
| `N4` | `games/tobbe/spel.gd`, `games/tobbe/test_tobbe.gd` |
| `N5` | `games/hinkel/spel.gd`, `games/hinkel/test_hinkel.gd` |
| `N6` | `games/meubels/spel.gd`, `games/meubels/test_meubels.gd` |
| `N7` | `games/kraam/spel.gd`, `games/kraam/test_kraam.gd` |
| `V6` | `ui/bron.gd`, `tests/test_hits.gd` |

*Overlap gecontroleerd: `B2` raakt `autoload/hits.gd`, `V6` raakt `tests/test_hits.gd` — verschillende bestanden. Verder geen overlap.*

#### `B2` — De Balklaag bestaat en de kamer staat erbóven 🔎
- [x] omvang **M** · model **opus** · hangt af van: `B1`, `S1`, `V1`
- **stappen** 1) Nieuw `ui/rekenbalk.gd` (`class_name UiRekenbalk extends Control`): full-rect, `mouse_filter = IGNORE`, kent `balk_rect()` en tekent in `_draw()` alleen het balkvlak (`UiThema.PAPIER` met `PAPIER_RAND` bovenrand, afgeronde bovenhoeken). Twee lege sloten voorbereiden: `zet_kaart(rect)` (voor `B3`) en een `Nu`-knop-kind dat nu nog onzichtbaar is (voor `B6`). 2) `Ui`: `balk_aan() -> bool`, `balk_rect() -> Rect2` (in kadercoördinaten) en `balk_hoog() -> float`. **`balk_aan()` is waar zodra `World.kader_rect()` een geldig kader heeft; `balk_rect()` wordt puur uit dat kader afgeleid — zonder Balklaag-node.** Herberekend op `kader_veranderd` en doorgegeven aan `World.zet_balk(h)`. 3) `scenes/main.tscn`: `Balklaag` als `Control` (anchors full rect, `mouse_filter = 2`) tussen `Vanglaag` (`:78`) en `Knoplaag` (`:83`) onder `Kaderdoos/Kader`; `Ui.registreer_lagen` krijgt hem als **zesde, optionele** parameter (`ui.gd:57-58` heeft er nu vijf, twee optioneel) — dan hoeft geen enkele van de 17 testopstellingen te wijzigen. `scenes/main.gd:46` geeft hem mee. 4) `autoload/world.gd`: veld `_balk := 0.0` + `zet_balk(h)` (bij verandering `_bereken_schaal`, `_cam_doel` en `kader_veranderd` opnieuw); in `_bereken_schaal` wordt `maxf(120.0, _kader.size.y - 4.0)` (`:284`) → `maxf(120.0, _kader.size.y - 4.0 - _balk)`; in `cam_doel` wordt `onder = minf((KADER_ONDER + _balk) * dicht, maxf(0.0, over))` én de `over < 0`-tak `h - 4.0 - _balk * dicht - box[3] * g`, zodat de vloer in beide takken bóven de balk eindigt (`:308-314`). 5) `autoload/hits.gd:plaats()` (`:199`): direct na `_kaart_vrij.clear()` het balkvlak in `_geplaatst` én `_kaart_vrij` zetten en zijn cellen reserveren met `_reserveer`. **Laat de derde kleef-kandidaat (de voetdok, `:531-532`) vervallen** — die claimt exact dezelfde rechthoek als de balk.
- **acceptatie** `DH_TEST_FILTER=test_balk tools/test.sh` groen met minstens: (a) op de tien kaders geeft `Ui.balk_rect()` de hoogte uit de tabel en ligt hij tegen de onderrand; (b) voor **elke** kamer uit `Rooms.lijst()` en elk kader liggen de vier vloerhoeken (`World.mik_punt`) volledig boven `kader.y - balk_hoog`; (c) `World.schaal()["g"]` blijft 2..4 in elke kamer op elk kader; (d) een hotspot op een mikpunt midden in de balk landt erbóven. `DH_TEST_FILTER=test_hits` en `=test_world` blijven groen. Beeld: `node tools/kiek.js --kamer keuken --band 4 --uit /tmp/b2a`, `--kamer tuin`, `--viewport 360x740@3:telefoon --kamer receptie` — op alle drie is onderaan een lege papierstrook zichtbaar, staat de hele kamer erboven en overlapt niets.

#### `D1` — De aai-voorraad in de opslag
- [x] omvang **S** · model **opus** · hangt af van: `N1`
- **stappen** In `autoload/state.gd`: `const AAI_MAX := 3` en `signal aai_gevuld()` bij de andere constanten. `mk_gast()` (`:45-51`) krijgt `"aai": AAI_MAX`. `const GAST_INT` (`:300`) krijgt `"aai"` erbij — daarmee normaliseert `_normaliseer()` hem al naar int over gasten/wachtlijst/nieuweGast en bewaakt `_gast_vorm_klopt()` het type gratis. `_repareer_gast()` (`:368`) krijgt `if not g.has("aai") or g["aai"] == null: g["aai"] = AAI_MAX` gevolgd door `clampi(int(...), 0, AAI_MAX)`. `standaard()` **niet** aanpassen (gastveld, geen topsleutel). Vier functies: `aai_van(id) -> int` (−1 bij onbekende gast), `aai_uit(id) -> int`, `aai_bij(n := 1) -> bool`, `aai_vol() -> bool`; geen van vieren roept `bewaar()` aan. Onderaan `tel(goed, ms)` (`:518-523`, ná `_herbereken()`): `if aai_bij(1): aai_gevuld.emit()` — **ook bij `goed == false`**. Let op: `tests/test_state.gd:274` roept `tel()` aan zonder gasten; `aai_bij` moet een lege lijst netjes verdragen en `false` geven. Nieuw `tests/test_aaien.gd` met alleen de datatests.
- **acceptatie** `DH_TEST_FILTER=test_aaien tools/test.sh` groen met minstens: een verse gast heeft `aai == AAI_MAX` en `"aai" in State.GAST_INT`; `aai_uit` telt 3→2→1→0 af en blijft op 0; `State.tel(true, 1000)` én `State.tel(false, 9000)` geven allebei +1, nooit boven `AAI_MAX`; `aai_vol()` zet iedereen vol; een gast met `aai = 1` overleeft `bewaar()` + `lees()` als **int**; een gast-Dictionary zónder `aai` komt er met `AAI_MAX` uit. `DH_TEST_FILTER=test_state` blijft groen.

#### `N3` — Zwembad: eerst de som, en botsen is geen eindstreep 🔎
- [x] omvang **M** · model **opus** · hangt af van: — · **eigenaarsbeslissing V1 nodig**
- **stappen** 1) `_begin()` (`games/zwembad/spel.gd:152-159`) wordt `_zet_gasttag(); _vraag()`; de `await _zorg_in_water()` vervalt daar — `_kies()` doet hem al vóór `_zwem()`. Zorg dat `_zet_gasttag`/`_vrij_vak` aankunnen dat de gast nog in een andere kamer is (terugval bestaat al op `:604-609`). 2) `_bots()` (`:387-395`) doet alleen nog `Snd.au()`, `_spat(6)` en het 💛-wolkje; de `await _afronden("bots")` eruit. 3) In `_kies()` bij `soort == "ver"`: bewaar `p_voor`, laat hem de rest zwemmen, botsen, terugzwemmen naar `ZwembadBeurt.baan_x(bad, L, p_voor)` (pose `zwem`, tempo 1,1), zet `_b["p"] = p_voor`, `_bewaar()` en roep `_vraag()` opnieuw aan — **nooit `_afronden`**. 4) Nieuwe kaartregel in `beurt.gd`: `🙃 Te ver, hij tikt de rand` (6 woorden, 24 tekens), tweede regel de bestaande `Nog hoeveel meter?`. 5) `_afronden` wordt alleen nog via `precies` bereikt (plus het bestaande vangnet als het dier weg is); de ster en het vinkje horen daar. 6) `_eindkaart` mikt op het dek in plaats van op het vak van de nog zwemmende gast. **`core/sommen.gd` niet aanraken.**
- **acceptatie** `DH_TEST_FILTER=zwembad tools/test.sh` groen (29 bestaande) plus: `test_de_vraag_staat_er_voor_de_duik` (direct na `Games.start("zwembad")` bestaat de strook-hotspot en draagt de kaart keuzes), `test_een_te_ver_antwoord_eindigt_de_beurt_niet` (`_b["klaar"]` blijft leeg, `State.s["sterren"]` onveranderd, er staat weer een kaart met vier keuzes), `test_de_ster_valt_alleen_bij_precies`. Beeld: `node tools/kiek.js --kamer zwembad --band 4 --tik spel_zwembad --wacht 1200 --uit /tmp/n3` — binnen 1,2 s staat de somkaart met vier `🏊 <n> m`-knoppen en zwemt het dier nog niet.

#### `N4` — Tobbe: elke ronde begint met een som, niets wordt voorgedaan
- [x] omvang **M** · model **opus** · hangt af van: —
- **stappen** 1) `_nieuwe_stand` (`games/tobbe/spel.gd:86-107`): `"stap": "vraag"` voor alle drie de soorten; `rek` blijft `T` bij `eerlijk` en `tob[0]` blijft `T` bij `half`. 2) `_teken_vraag` (`:607-640`) krijgt een derde tak voor `eerlijk`: bij `M == 2` som `helft van %d =`, bij `M == 3` som `%d : %d =`; `goed = per`, `liever: [T, per + 1, rest]`, pictogram 🧴, regel `%d schepjes, %d tobbes` (4 woorden, 21 tekens), regel2 `Hoeveel in elke tobbe?` (4/22), titel `de som van het sop`. 3) `_antwoord` (`:642-670`) vult **niets** meer in: bij `eerlijk` alleen `stap = "vullen"`, bij `dubbel` `rek = T` zoals nu, bij `half` blijft al het sop in `tob[0]` zodat het kind zelf halveert met 🚰 of overgiet (`_kraantje`, `:756-795`, zet de rest al in het kannetje). 4) Controleer dat `_check` (`:841-864`) ongewijzigd klopt voor alle drie de soorten. 5) Werk de woordelijke teksttest bij.
- **acceptatie** `DH_TEST_FILTER=tobbe tools/test.sh` groen (8 bestaande) plus: `test_elke_soort_begint_met_een_vraag` (voor `eerlijk`/`dubbel`/`half` × band 3/4/5 is `_s["stap"] == "vraag"` direct na start en bestaat er een kaart met vier keuzes) en `test_een_goed_antwoord_verdeelt_niet_zelf` (bij `half` is `tob == [T, 0]`, bij `eerlijk` `tob == [0, 0]`). Beeld: `node tools/kiek.js --kamer tuin --band 3 --tik spel_tobbe --uit /tmp/n4` — op band 3 staat er nu een somkaart met vier knoppen in plaats van `0 + 0 = 0`.

#### `N5` — Hinkel: een leesbare getallenlijn en een zichtbaar trapje
- [x] omvang **M** · model **opus** · hangt af van: —
- **stappen** 1) `_steen_getal(i, band)` (`games/hinkel/spel.gd:309-314`): op band 4/5 alleen nog een bordje op elke twintig (`i % 4 == 0` → 0, 20, 40, 60, 80, 100). 2) `_rij_van_steen` (`:319-327`) mag voor band 4/5 gewoon 0 teruggeven; de om-en-om-lift vervalt. Band 3 (11 stenen, steek 7 voxels, bordje 5 breed) blijft ongewijzigd. 3) `_trap_model` (`:390-407`): het doelgetal op rij 1 (8 voxels hoger dan een padbordje) en de vlaggenmast hoger (vlag op y ≈ 22 voxels), zodat het doel boven het dier uitkomt. 4) Zet de rekensom in een commentaarregel: steek tussen bordjes 14 voxels = 28·g px tegenover 18·g px bordbreedte.
- **acceptatie** `DH_TEST_FILTER=hinkel tools/test.sh` groen (17 bestaande) plus `test_geen_twee_getalbordjes_overlappen` (bereken voor band 3/4/5 de schermrechthoeken van alle bordjes uit de gebakken platen en eis dat geen twee elkaar raken, op vier kaders) en `test_het_trapje_is_zichtbaar`. Beeld: `node tools/kiek.js --kamer tuin --band 4 --tik spel_hinkel --uit /tmp/n5` — de lijn leest 0 20 40 60 80 100 en het roze vlaggetje steekt boven het dier uit.

#### `N6` — Meubels: eerst de buidel tellen, dan het boek
- [x] omvang **M** · model **opus** · hangt af van: — · **eigenaarsbeslissing V4 nodig**
- **stappen** 1) `start()` (`games/meubels/spel.gd:145`) opent niet meer `_boek()` maar `_kassa_vraag()`: camera naar de receptie, de buidel met de echte munten uit `ctx.econ.buidel(_munten())` als `Ui.bron` op de toonbank, en een somkaart bij de kassa met regel `Hoeveel euro heb je?` (4 woorden, 20 tekens), pictogram 💰, `"goed": _munten()`, `"max": 2`, knoppen `🪙 €<n>`. **Stap 0: bij `_munten() == 0` meteen door naar het boek met een wolkje `💰 Nog geen munten` (3/16) — geen somkaart**, anders is `goed = 0` en staan er vier afleiders rond nul. 2) Fout = `Snd.zacht()` + de munt-telladder als hulpregel; vanaf drie pogingen spookmunten via het bestaande `_spook_neer`. Nooit een kruis. 3) Goed = vinkje, daarna `Ui.blad_open` met het boek zoals nu. 4) `{"view": "kassa"}` in `ctx.data()` zodat "Verder spelen" er middenin terugkomt; `stop()` ruimt buidel en kaart op. 5) De somstap bij het afrekenen blijft ongewijzigd. 6) Teksttest bijwerken.
- **acceptatie** `DH_TEST_FILTER=meubels tools/test.sh` groen (20 bestaande) plus `test_het_spel_begint_met_een_muntvraag`, `test_nul_munten_slaat_de_vraag_over`, `test_het_boek_komt_pas_na_het_goede_antwoord` en `test_de_kassavraag_overleeft_een_herlaad`. Beeld: `node tools/kiek.js --kamer receptie --band 4 --tik spel_meubels --uit /tmp/n6` — het eerste beeld is de muntvraag bij de balie, niet het winkelblad.

#### `N7` — Kraam: de waren op tafel, de gast voor de toonbank
- [x] omvang **M** · model **opus** · hangt af van: —
- **stappen** 1) `_plekken(n)` (`games/kraam/spel.gd:351-378`): spreid over ±6 voxels in plaats van ±8 — het blad is x −11..+11, z −8..+8 (`games/kraam/modellen.gd:54-58`), dus ±8 valt precies op de hoeken. Bij vier waren de even indexen op `bank_d` en de oneven op `bank_d + 4`: twee ondiepe rijtjes. 2) `gast` komt van de toonbank in plaats van de zonehoek: dezelfde schermkolom (`x − z` gelijk aan die van `bank`) en ±16 voxels naar de kijker toe, bijvoorbeeld `_pt(bank.x + 8, bank.z + 8)`; blijf binnen de kraamzone en uit de buurt van de bal op (120, 76). 3) In de stap `leg`: zolang de toonbank leeg is regel2 `Leg de munten op de toonbank` (bestaand); zodra er iets ligt en er nog iets bij moet `Nog €%d erbij` (3 woorden, 12 tekens). Somregel blijft het doelbedrag, het vak de lopende stand. 4) Teksttest bijwerken.
- **acceptatie** `DH_TEST_FILTER=kraam tools/test.sh` groen (19 bestaande) plus `test_elke_waar_staat_op_het_blad` (voor 2, 3 en 4 waren ligt de gebakken rechthoek van elke waar volledig binnen die van `kr_toonbank`, op vier kaders), `test_de_gast_staat_voor_de_toonbank` (`abs((gx − gz) − (bx − bz)) <= 6` en `gx + gz > bx + bz`) en `test_de_restregel_telt_af`. Beeld: `node tools/kiek.js --kamer tuin --band 5 --tik spel_kraam --uit /tmp/n7`.

#### `V6` — De teller van een sleepbron past binnen zijn eigen knop
- [x] omvang **S** · model **opus** · hangt af van: —
- **stappen** 1) `UiBron.bouw()` (`ui/bron.gd:31-36`) zet de teller-HBox binnen de knop in plaats van eronder: laat de HBox een gewoon kind zijn met `PRESET_BOTTOM_WIDE` en `grow_vertical = GROW_DIRECTION_BEGIN`, en zet met `get_combined_minimum_size()` een `custom_minimum_size.y` van minimaal `tap` + de pilhoogte. 2) De test komt in `tests/test_hits.gd` (**niet** in `tests/test_ui.gd`, dat van de tweede agent is): maak een `Ui.bron` met `aantal: 40`, laat `Hits.plaats()` lopen en eis dat de globale rechthoek van de teller-Label volledig binnen die van de knop ligt.
- **acceptatie** `DH_TEST_FILTER=test_hits tools/test.sh` groen met de nieuwe test; `DH_TEST_FILTER=voerkar`, `=was`, `=kraam` blijven groen. Beeld: de keuken tijdens het rondje — het getal op de kar staat IN de knop, niet erboven of eronder op een andere knop.

---

### Batch 3 — De balk krijgt zijn anker; de reworks beginnen

*Doel: kaart en strook dokken onderin; de keukenvloer wordt leeg; vier spellen
krijgen hun echte eerste vraag; de Speelzaal bestaat.*

**Bestandssets** — `B3`: `autoload/hits.gd`, `autoload/ui.gd`, `ui/rekenbalk.gd`, `tests/test_hits.gd` · `V2`: `games/voerkar/spel.gd`, `games/voerkar/test_voerkar.gd` · `V5`: `autoload/world.gd`, `scenes/main.gd`, `tests/test_world.gd` · `N8`: `games/was/spel.gd`, `games/was/soorten.gd`, `games/was/test_was.gd` · `N9`: `games/bedden/spel.gd`, `games/bedden/test_bedden.gd` · `K1`: `games/sleutels/spel.gd`, `games/sleutels/test_sleutels.gd` · `K3`: `games/wekker/spel.gd`, `games/wekker/test_wekker.gd` · `R2`: `autoload/rooms.gd`, `ui/plattegrond.gd`, `autoload/snd.gd`, `art/decor_speelzaal.gd` *(nieuw)*, `art/decor.gd`, `tests/test_rooms.gd`, `tests/test_sfeer.gd`, `tests/test_plattegrond.gd`, `tests/test_art.gd`, `HOTEL.md`, `tools/kiek.js`. *Geen overlap.*

#### `B3` — Anker "balk": de kaart en de strook dokken onderin 🔎
- [ ] omvang **M** · model **opus** · hangt af van: `B2`
- **stappen** 1) `Hits._op_van` (`hits.gd:447`): nieuw anker `"balk"`, getest **vóór** `kleef_aan` — een spot krijgt het als `Ui.balk_aan()` én (`s.kind == "kaart"` en `Ui.balk_kaart() == s.id`) of (`s.kind == "keuzes"` en `Ui.balk_kaart() == s.kleef_aan`). `Ui.balk_kaart()` = de laatst geopende nog bestaande kaart met de hoogste prio; een tweede kaart houdt het oude `midden`-gedrag. 2) `Hits._kies_plek` (`:477`): tak `op == "balk"` die `Ui.balk_plek(kind, maat) -> Rect2` aanroept, het resultaat reserveert en `{rect, op: "balk", krap: false, gestapeld: false}` teruggeeft. Zet `"balk"` in de overslaglijst van `_blijf_staan` (`:316`). 3) Spots met anker `"balk"` tellen **niet** mee tegen `MAX_PER_KAMER` (`:263-265`) — dat geeft de keuken meteen twee plaatsen terug. 4) `UiRekenbalk.balk_plek(kind, maat)`: vorm `hoog` → kaart gecentreerd op `balk.y + 8`, strook gecentreerd op `kaart.end.y + 8`; vorm `laag` → kaart links op `balk.x + 12`, strook rechts tegen `balk.end.x − 12`, beide verticaal gecentreerd. De kaart wordt altijd vóór de strook geplaatst (prio 14 > 13). 5) De aanroep van `Ui.somkaart()` verandert niet; id, strook-id en node-namen blijven.
- **acceptatie** `DH_TEST_FILTER=test_hits tools/test.sh` groen met herschreven tests: `test_keuzestrook_kleeft_onder_de_kaart` (`:199`, eiste `op == "kleef"` en kéurde daarmee "boven de kaart" goed) wordt `test_strook_staat_onder_de_som_in_de_balk` — anker `"balk"`, kaart én strook volledig binnen `Ui.balk_rect()`, en in vorm `hoog` geldt `kaart.rect.end.y <= strook.rect.position.y`, in vorm `laag` `kaart.rect.end.x <= strook.rect.position.x`. `test_antwoordstrook_kleeft_aan_de_kaart` (`:146`) houdt alles behalve de afstandseis. `test_kaart_laat_de_balie_vrij` (`:428`) wordt: de balk raakt de balie nooit, de winnende kaart staat in de balk, de tweede bij haar voorwerp. `_keur` (geen overlap, geen dekking, `krap == false`) blijft gelden op alle tien kaders. Bewijs dat de spellen ongemoeid blijven: `DH_TEST_FILTER=wekker` en `=hinkel` groen **zonder wijziging in die spellen**. Beeld: `--kamer receptie --tik bel` op tablet, telefoon en `740x360@3:laag-land`.

#### `V2` — De keukenvloer wordt leeg (sloop, gedrag gelijk)
- [ ] omvang **M** · model **opus** · hangt af van: `V1`
- **stappen** Verwijder uit `games/voerkar/spel.gd`: `VAKBREUK`, `POTBREUK`, `BAK_DX/DZ`, `MODEL_BAKJE` + `_bakje_model` + `_bakje_zet` + `_bakjes_weg` + `_bakjes_neer` + `_bakje_hotspot` + `bak_plek` + `_bak_id` + `_bak_index`, `_zak_neer` + `_tik_zak`, `_knoppen_neer` (Klaar/Opnieuw weg, Els blijft), `verplaats`, `_kruimels`, `opnieuw`, `zet_hand`/`_kies_hand`/`volgende_hand`/`_kleur_hand`, en de meet-/chip-helpers `_meet_kader`/`_mini`/`_krap`/`_kort`/`_snap_hoogte`/`_chip`/`_chip_hoog`/`_naam_kort`. Repareer `deelnemers()` (`:181`): tel alleen gasten met een bed in een kamer waarvan `ctx.wereld.slots(kamer, "bak")` niet leeg is. Zet de nieuwe `K`-vorm neer (`{T, per, rest, op_kar, pot, stap, geleverd, missers, spook, t0}`) met `_herstel()` en een terugval: een oude save met `"vol": true` wordt `stap = "duwen"`, zonder `vol` wordt het `stap = "som"`. Dit is een **pure opruimcommit**: het oude rondje blijft voorlopig werken. Netto wordt het bestand korter.
- **acceptatie** `DH_TEST_FILTER=voerkar tools/test.sh` groen (testbestand meebijgewerkt zodat het gedrag ongewijzigd blijft). Beeld: `node tools/kiek.js --kamer keuken --band 4 --tik spel_voerkar --uit /tmp/v2` — geen bakje op de keukenvloer, geen zak, geen pak-knoppen. Tel de knoppen in het log en noem het aantal in de commitboodschap.

#### `V5` — Het volle bakje blijft even vol, en de knop liegt niet meer
- [ ] omvang **S** · model **opus** · hangt af van: —
- **stappen** 1) `World._eet()` (`world.gd:1386`): vervang de globale poort `_tikken % 5 == 0` door een teller op het dier zelf (`d.kauw`, één niveau eraf per 24 tikken ≈ 1,6 s). Vier niveaus duren dan ±6,4 s, ruim langer dan het 😋-wolkje van 2,6 s, ongeacht hoeveel dieren er eten. Het bestaande gedrag buiten beeld (`:1287-1292`, in één keer leeg) blijft. 2) Nieuw `signal bak_veranderd(kamer, slot)` dat `World.zet_bak()` (`:658`) uitzendt als het niveau echt verandert. 3) Verbind het in `scenes/main.gd` (**niet** in `hotel.gd`) met een handler die `Hotel.render()` **`call_deferred`** aanroept als het de huidige kamer is — `zet_bak` wordt midden in de wereldtik aangeroepen terwijl er over de dieren geïtereerd wordt, dus nooit direct.
- **acceptatie** `DH_TEST_FILTER=test_world tools/test.sh` groen met: bakje op 4 + twee etende dieren + 20 tikken → stand ≥ 3, na 100 tikken → 0; `bak_veranderd` vuurt precies één keer per echte verandering; en een render midden in de eetlus gooit niets om. `=voerkar` en `=test_ui` blijven groen. Beeld: kamer1 drie seconden na het vullen — het bakje bevat nog zichtbaar voer en de knop zegt 🍪 Vol.

#### `N8` — Was: een openingssom en een tussensom
- [ ] omvang **M** · model **opus** · hangt af van: —
- **stappen** 1) Nieuwe stap `"vraag0"` vóór `"sorteren"` in `_nieuwe_stand` (`games/was/spel.gd:160-169`) — het recept kent `T` en de stapels dan al. Kaart via `ctx.ui.somkaart` met `goed`: band 3/4 regel `Hoeveel stuks liggen er?` (4/24) en `goed = T`; band 5 regel `Hoeveel blokjes worden dat?` (4/27), regel2 de bestaande `📦 Elk blokje is 2 stuks` en `goed = T / 2`. Knoppen `📊 <n>`. 2) Nieuwe stap `"vraagT"` zodra `_stuks_over() <= T / 2`, alleen bij `T >= 8`: regel `Hoeveel liggen er nog?` (4/22), `goed = _stuks_over()`; daarna terug naar `"sorteren"`. 3) Hulpladder: `_hulp_zin()` uitbreiden met `Econ.tel_mee(1, …)` respectievelijk `tel_mee(2, …)`; bij drie missers een spookcijfer op de berg (`_spook`, `:715-718`). 4) Beide stappen in `_meld(...)` en in `_normaliseer`. 5) De wasberg krijgt pictogram 🧹 (zit al in de subset) in plaats van 🧺, zodat berg en de soort "doeken" (`games/was/soorten.gd:21`) niet meer hetzelfde plaatje dragen. 6) Teksttest bijwerken. *De `_heeft_pad`-plaatsingsreparatie vervalt: de balk beslist.*
- **acceptatie** `DH_TEST_FILTER=was tools/test.sh` groen (19 bestaande) plus `test_het_spel_begint_met_een_vraag` (na start is `_stap_nu() == "vraag0"`, er is een kaart met vier keuzes en de berg is nog niet aan te raken), `test_de_tussensom_komt_halverwege` (band 4 met T = 20 wél, band 3 met T = 3 niet) en de teksttest over de nieuwe zinnen. Beeld: `--kamer wasserij --band 4 --tik spel_was --wacht 1000 --uit /tmp/n8`.

#### `N9` — Bedden: een echte vraag vooraf, het wolkje legt één bedje 🔎
- [ ] omvang **M** · model **opus** · hangt af van: — · **eigenaarsbeslissing V3 nodig**
- **stappen** 1) Nieuwe eerste fase `"vraag"` in `ctx.data()["fase"]`: `_som_bij` toont de kaart `%d × %d =` (rijen × perRij) **mét** `"goed": _doel()` en `on_ok`; regel `Hoeveel bedden heb je nodig?` (5/28), pictogram 🛏, vier knoppen `🛏 <n>`. Fout = `Snd.zacht()` + telladder als hulpregel, nooit een kruis, nooit een stap terug. Goed = `_kaart.klaar()` en fase `"leggen"`. 2) In `"vraag"` bestaan de strookjes, de kist, 🔄 en 🐾 nog **niet**; in `"leggen"` verschijnen ze en houdt de kaart haar bestaande regel `Leg %s van %s` met het meetellende antwoordvak. 3) `hulp()` (`:961-988`): de tik op het 🐑-wolkje doet `_leg_in(rr)` (**één** bedje) in plaats van `_zet_rij(rr, _per_rij())`; spookbedjes en spookcijfer blijven, titel `nog een bedje erbij`. 4) `start()` (`:346-347`): de deuren niet meer lenen — 🐾 `bd_klaar` blijft de enige controle, weglopen is weglopen. 5) De nieuwe fase overleeft een herlaad.
- **acceptatie** `DH_TEST_FILTER=bedden tools/test.sh` groen (18 bestaande) plus `test_het_spel_begint_met_een_vraag` (fase `"vraag"`, `bd_som_keuzes` bestaat, geen `bd_rij0`), `test_wolkje_legt_een_bedje` (+1, niet +perRij), `test_twee_missers_en_hulp_geven_geen_ster` en `test_de_deur_verlaat_de_kamer` (een tik op `deur_kamer1_gang` telt geen misser). Beeld: `--kamer kamer1 --band 4 --tik spel_bedden --uit /tmp/n9` — eerste beeld is de vraagkaart met vier knoppen.

#### `K1` — Sleutels: eerst het getal kiezen, dan pas ophangen 🔎
- [ ] omvang **M** · model **opus** · hangt af van: —
- **stappen** De beurt wordt twee stappen; `_p["stap"]` (`"reken"`/`"hang"`) en `_p["gekozen"]` in `ctx.data()`. 1) Stap `reken`: `_teken_sleutel` geeft de bron `"aantal": 0` mee — geen getal te zien en dankzij `UiBron._get_drag_data` (`ui/bron.gd:67-69`) niet sleepbaar. De kaart krijgt `goed` = het getal van het actieve gat, icoon 🔑, `min` 1, `max_getal` 20/100/1000 per band, `max` 3 zodra de rij drie cijfers haalt (`_drie_cijfers` bestaat al) anders 2, en `liever` = de twee **zichtbare** buren van het gat. Goed → `Snd.munt()` + `ja()`, `_p["gekozen"] = n`, `stap = "hang"`, `Ui.bron_van("sl_key").zet(n, 1)`, hertekenen. Fout → `Snd.zacht()`, misser, hulpladder een trede verder, dezelfde vier keuzes komen terug (het zaad regelt dat). 2) Het actieve gat is het meest linkse lege haakje van het huidige bord en dat plaatje gloeit tijdens `reken`; in de sombalk staat het actieve gat als `__` en een later gat als `?`. 3) Stap `hang`: alle lege haakjes gloeien; `_hang(i)` werkt via tik én sleep maar doet niets zolang `stap == "reken"` (een tik op het `?` geeft dan het wolkje `🔑 kies eerst het getal`). 4) Alle kindtekst als `const` bovenaan (de tekstkeuring leest de bron): `Welk nummer mist er?` 4/20 · `Stampertje wacht op zijn sleutel` 5/32 · `Hang 30 op het lege haakje` 6/27 · `Stampertje krijgt nummer 30` · `tel met de sprongen mee` 4/23 · `sleep of tik het lege haakje` 6/28. 5) Hulpregel **altijd** gevuld via één `_hulp_tekst()`. 6) Repareer B2 (`_licht = -1` zodra `_p["nu"]` naar een ander bord gaat, `:944`), B3 (`_buren_van` over het gat van de **sleutel**, niet over het aangewezen haakje, `:984-985`) en B4 (buurlijn én tip samen op één hulpregel, `:709-712`). 7) Vervang de twee aanroepen van de lege `Ui.spreek()` (`:895`, `:912`) door korte wolkjes van 1,6 s. 8) `_meld_rij()` meldt voortaan ook `stap`, `gekozen`, `sl_key`, `sl_tag` en `sl_els`.
- **acceptatie** `DH_TEST_FILTER=sleutels tools/test.sh`: de 15 bestaande groen plus minstens zes nieuwe — de sleutel draagt geen getal vóór het antwoord; een fout antwoord straft niet en laat dezelfde vier keuzes staan; het gekozen getal ligt binnen de band; de stap overleeft een herlaad; **bij N ≤ 4 is er precies één gat en tóch een som** (leg die aanname vast, de kern is bevroren); en geen enkele `push_warning` over een te lange regel. Beeld: `--kamer receptie --tik spel_sleutels --uit /tmp/k1` op 1024×768 en 360×740 — op beide staat `Welk nummer mist er?` met vier getalknoppen, staat er **geen** getal op de sleutel en gloeit precies één haakje.

#### `K3` — Wekker: de hulpladder klopt en de wijzerplaat wordt gereserveerd
- [ ] omvang **S** · model **opus** · hangt af van: `N2`
- **stappen** 1) `som_balk()` geeft **altijd** `nu: <tijd>` terug, ook in de stand `mis`; `zin_zet()` herhaalt de klokstand niet meer in die stand (regel blijft `<naam> wil om <tijd> op`, regel2 blijft `Zet de klok`) en de misser leeft alleen in de hulpregel. 2) De hulpregel is **altijd** gevuld: beginwaarde `draai tot de klok klopt` (5/23) — meteen de to-do-regel; misser 1 `💛 draai nog wat verder`; misser 2 de telladder `tel_ladder()` (`:737`, bestaat al); misser 3 `👻 de spookwijzers wijzen mee` én pas dán de spookmarkeringen in `klok_params()`. 3) `wk_plaat` krijgt prio **15** in plaats van 13, zodat de wijzerplaat gereserveerd wordt vóór de kaart geplaatst wordt. 4) Teksttest bijwerken. *De `_hang_kaart`-klem uit het ontwerp vervalt: de balk doet dat werk (§3.9).*
- **acceptatie** `DH_TEST_FILTER=wekker tools/test.sh` groen met een nieuwe test dat de kaarthoogte in de standen `zet`, `mis` en `duur` gelijk is (≤ 2 px verschil) en dat `wk_plaat` in alle vier de kaders minstens 20×20 vrij houdt. Beeld: `--kamer gang --band 4 --tik spel_wekker --uit /tmp/k3` vóór en ná een misser.

#### `R2` — De Speelzaal 🧸 🔎
- [ ] omvang **M/L** · model **opus** · hangt af van: `R1`
- **stappen** 1) `rooms.gd:53`: maak `Kamer.matten` **ongetypt** (`var matten = {}`) zodat een lijst matten mag; `ArtVloer._matten()` (`art/vloer.gd:49-54`) slikt die al. Grep dat niemand anders `r.matten` leest. 2) Nieuw `art/decor_speelzaal.gd` (`class_name ArtDecorSpeelzaal`, eigen `const NAMEN: Array[String]` + `tabel()`, in de stijl van `art/decor_wasserij.gd`): `klimrek`, `ballenbak`, `blokkentoren`, `kussenhoek` (de lighoek), `muziekdoos` (toekomstig ingangsvoorwerp van `spiegel`), `wimpel`. Aanmelden in `ArtDecor._extra()` (`art/decor.gd:44-46`). **Namen moeten uniek zijn over álle themabestanden** en op g = 2, 3 en 4 bakken; ze horen **niet** in `ArtDecor.NAMEN` (`tests/test_art.gd:267` eist `NAMEN.size() + POL_AANTAL == 34`). 3) `_kamer({...})`-blok voor `speelzaal` onderaan `_bouw_kamers`, vóór `_bouw_tuin`: `w 114, d 100, wand 56, vloer "hout", loop 1.5`, mat lichtblauw, zone `dans`, deur naar de receptie. 4) In de receptie één deurregel erbij; verplaats verder **niets** (de plant op (16, 96) had die hoek al leeg gemaakt, dus het kost nul vrije vakjes). 5) `ui/plattegrond.gd KAART`: `"speelzaal": [1, 1]`. 6) `Snd.SFEER["speelzaal"] = "speeldoos"` plus een tak `"speeldoos"` in `sfeer_monster()`: vier `_noot`-tonen op hele seconden (C-E-G-E, 880/1109/1319/1109 Hz, sine, top 0.05) met een zachte `_ruisband` eronder; hele periodes per lus, dus naadloos. `SFEER` staat buiten de bevroren 18 van `Snd.namen()`. 7) `tests/test_rooms.gd`: `ORDE` erbij, maten `[114, 100, 56, "hout", 1.5]`, kader en deurpunten — **geregenereerd uit een headless run, niet overgetypt**; in `test_niemand_loopt_door_de_balie` wordt `gelijk(r.deuren.size(), 1, ...)` → 2 en komt de nieuwe stap-binnen bij de doelenlijst. 8) `tests/test_sfeer.gd`: `Snd.sfeer_naam("speelzaal") == "speeldoos"`. 9) Helpregel van `tools/kiek.js` + één rij in de HOTEL.md §1-tabel.
- **acceptatie** `DH_TEST_FILTER=test_rooms`, `=test_art`, `=test_sfeer`, `=test_plattegrond`, `=test_ui`, `=test_kamerbalk` alle 0 fout; `test_elke_kamer_is_compleet` (uit `R1`) slaagt voor de nieuwe kamer, die ≥ 19 dwaalplekken houdt en geen plek binnen 18 voxels van decor heeft. Beeld: `node tools/kiek.js --kamer speelzaal --band 4 --uit /tmp/r2` en dezelfde met `--viewport 360x740@3:telefoon`: klimrek, ballenbak, kussenhoek en de mat in beeld, niets door een wand; `--kamer receptie --uit /tmp/r2r` toont twee deurknoppen en een onaangeroerde balie.

---

### Batch 4 — Grote letters in de balk; de reworks ronde 2

**Bestandssets** — `B4`: `ui/kaart.gd`, `ui/keuzestrook.gd`, `ui/thema.gd`, `tests/test_balk.gd` · `V3`: `games/voerkar/spel.gd`, `games/voerkar/test_voerkar.gd` · `N10`: `games/bedden/spel.gd`, `games/bedden/test_bedden.gd` · `N12`: `games/meubels/spel.gd`, `games/meubels/test_meubels.gd` · `N13`: `games/tobbe/spel.gd`, `autoload/world.gd`, `games/tobbe/test_tobbe.gd`, `tests/test_world.gd` · `K2`: `games/sleutels/spel.gd`, `games/sleutels/test_sleutels.gd` · `R3`: `autoload/rooms.gd`, `art/decor_kas.gd` *(nieuw)*, `art/decor.gd`, `autoload/snd.gd`, `ui/plattegrond.gd`, `tests/test_rooms.gd`, `tests/test_art.gd`, `games/hinkel/test_hinkel.gd`, `HOTEL.md`, `tools/kiek.js`. *Geen overlap.*

#### `B4` — Kaart en strook in balkvorm, met grote letters 🔎
- [ ] omvang **M** · model **opus** · hangt af van: `B3`
- **stappen** 1) `ui/kaart.gd`: stand `in_balk` — geen eigen paneel, **geen liniatuur** (`_draw`, `:191-195`), maten `balk_zin`/`balk_som` in plaats van `klein`/`somlijn`, breedte = balkbreedte − 24 in plaats van `BREED` (`:46-48`), `regel2` verborgen in vorm `laag` (één `push_warning`). 2) De krimp van de somlijn op smalle schermen (`:89`, `somlijn − 4`) vervalt in de balk: die kocht ruimte voor een cijferpad dat niet meer bestaat. 3) **De lege liniaturen weg** (de enige eigenaar van deze functie): `som_label.visible = not som_label.text.is_empty()`, de hele `Rij`-HBox onzichtbaar als som én vak onzichtbaar zijn, en `Ui.Kaart.som()` (`ui.gd:518-521`) werkt die zichtbaarheid mee bij. Dat haalt de lege regels weg op élke kaart zonder som (was band 3, was-eindkaart, zwembad-startkaart). 4) `ui/keuzestrook.gd:bouw()` (`:17`) krijgt de maat `balk_knop` en een minimum `knop_breed`/`knop_hoog` uit de tabel; de kort-woordkeuze (`:27-32`) meet tegen de **balkbreedte** in plaats van de kaderbreedte. Node-namen `Rij` en `Rij/K<id>` blijven.
- **acceptatie** `DH_TEST_FILTER=test_balk` en `=test_hits` groen: op alle tien kaders staan kaart en strook binnen `Ui.balk_rect()`, de zin staat bóven de som bóven de knoppen, elke knop haalt de knopbreedte uit de tabel en elke lettermaat is ≥ 12. `Hits.spot("<id>_keuzes").knoop.get_node("Rij/K<id>")` werkt onveranderd — bewijs met `DH_TEST_FILTER=games` één keer volledig. Nieuwe test: een kaart zonder somregel toont geen lege regel. Beeld: `--kamer keuken --band 4 --tik spel_voerkar`, `--kamer receptie --tik bel`, en dezelfde twee op `360x740@3` en `740x360@3` — op alle vier is de som aantoonbaar de grootste tekst op het scherm.

#### `V3` — De deling wordt de poort: één som in de keuken
- [ ] omvang **M** · model **opus** · hangt af van: `V2`
- **stappen** 1) `_som_kaart()`: `ctx.ui.somkaart(_kaart_punt(), Sommen.Voerkar.som_regel(band, T, n, rest), {id: "vk_kaart", icoon: "🍪", regel: T_VERDEEL % …, regel2: rest > 0 ? T_IEDER : T_IEDER_HOEVEEL, goed: per, liever: [T, n], prio: 14, on_ok: _op_som})`. Verberg de somrij als de somregel leeg is (band 3 kent het deelteken niet), maar laat het **antwoordvak wél** zien — er valt nu iets in te vullen. 2) `_pot_kaart()` idem met `T_POT_HOEVEEL`, `goed: rest`, `liever: [0, per]`; alleen als `rest > 0`. 3) `_op_som` / `_op_pot`: goed → `zet_goed(true)`, `ctx.snd.tover()`, `ctx.wereld.spetter()` op de kar, **`Econ.sterren(1, ctx.id)` hier** (meedoen is verdiend), `K.op_kar = per * n`, `K.stap` door, `_bewaar_kar()`, `_teken()`. Fout → `K.missers += 1`, `ctx.snd.zacht()`, hulpregel `🥄 %d gasten · %d koekjes`; vanaf twee missers de knop `🩺 Els helpt` die `🩺 Iedereen krijgt %d` (3/20) op de kaart zet en de goede strookknop perzik verft (`_kleur_goed()`). 4) `check()` verdwijnt; na de laatste kaart roept het spel het bestaande `_rondje()` aan met `K.stap = "duwen"` — zo is `V3` los te committen. 5) Nieuwe zinnen als `const` bovenaan; de twintig vervallen zinnen **schrappen** uit de bron, uit `test_voerkar.gd:251` én uit `.fanout/specs/godot/games-a.md §7.7`, in deze commit (R9), en dat zeggen in de commitboodschap.
- **acceptatie** `DH_TEST_FILTER=voerkar tools/test.sh` groen: `test_beurt_band_3/4/5` tikken nu de kaartknop met het goede getal; `test_de_schep_schakelt_door` wordt `test_de_kaart_vraagt_hoeveel_ieder_krijgt`; nieuw `test_fout_antwoord_straft_niet` (missers stijgt, geen ster, dezelfde vier keuzes terug) en `test_pot_alleen_bij_rest`; `test_kindteksten_staan_er_verbatim` bijgewerkt. Ook `DH_TEST_FILTER=test_sommen` groen. Beeld: `--kamer keuken --band 4 --tik spel_voerkar` op tablet én telefoon: één kaart met twee zinnen + `40 : 4` + vier getalknoppen, hoogstens zes knoppen in beeld.

#### `N10` — Bedden: de gewonnen bedden staan echt op een rij
- [ ] omvang **M** · model **opus** · hangt af van: `N9`
- **stappen** 1) Nieuw `_bed_raster(kamer, rijen, per_rij) -> Array`: neem `Rooms.get_kamer(kamer).vrij`, groepeer op z-band (tolerantie ±6), kies per band cellen met minstens **36** voxels x-afstand en neem zoveel banden als er rijen zijn met minstens **20** voxels z-afstand. Reden: het bedmodel beslaat x −17..+16 (34 voxels) en z −8..+8 (17), terwijl `Rooms._bouw_vrij` op 18 en `_bezet` op 15 manhattan filtert — twee bedden komen door beide controles en overlappen toch. 2) Sla een punt over als een bestaand bed er in x binnen 36 **én** in z binnen 20 van ligt (rechthoekbotsing, geen manhattan). 3) `_bouw_bedden` (`:1043-1057`) loopt dat raster af in plaats van `_beste_vak()`; past een bed nergens, dan stopt de golf (bestaand gedrag). 4) `capaciteit()`/`_ruwe_capaciteit()` (`:192-211`) gebruiken dezelfde maten. **`autoload/rooms.gd` blijft ongemoeid** (gouden tabellen).
- **acceptatie** `DH_TEST_FILTER=bedden tools/test.sh` groen plus `test_de_gewonnen_bedden_overlappen_niet` (speel een beurt uit in kamer1 en kamer2 op band 3/4/5; geen twee bedslots naderen elkaar in x binnen 34 én in z binnen 17, en geen bed staat binnen 15 van een decorstuk) en `test_de_bedden_staan_in_rijen` (de z-waarden vallen in precies `rijen` groepen). Draai ook `DH_TEST_FILTER=test_rooms` en let op de plekken-invariant (`tests/test_rooms.gd:215-232`). Beeld: `--kamer kamer1 --band 4 --tik spel_bedden --wacht 9000 --uit /tmp/n10`.

#### `N12` — Meubels: rustige kamer, boek overal, plekken verspreid, alles draaien
- [ ] omvang **M** · model **opus** · hangt af van: `N6`
- **stappen** 1) `_rustige_kamer()` naar het voorbeeld van `games/bedden/spel.gd:527-533`: tijdens `betaal` en `plaats` gaan de hotelknoppen `spel_*`, `bel`, `prikbord`, `mand_*` en `bak_*` weg; ze komen terug in `stop()`. Roep hem ook aan ná `Hotel.render()`/`Hotel.naar_kamer()` in `_zet_neer` en `_plaats` — die zetten ze nu terug. 2) `mb_boek` (`:626-631`) krijgt `"kamer": World.kamer_nu()` in plaats van hard `receptie`, zodat er overal een weg terug is. 3) `_vakjes` (`:1286-1311`) sorteert niet op afstand tot het eerste deurpunt maar **aflopend op afstand tot het dichtstbijzijnde meubel van hetzelfde type**, zodat planten niet naast planten belanden en de vier ✨-plekken verspreid liggen. 4) 🔄 Draaien voor **elk** eigen meubel (`:651`, nu alleen bij `type == "bed"`): vier standen voor decor, twee voor een bed; `Rooms.meubel_zet` bewaart `rot` al en de hele keten geeft hem door. 5) Het plafond van drie bedienbare eigen meubels per kamer naar zes.
- **acceptatie** `DH_TEST_FILTER=meubels tools/test.sh` groen plus `test_geen_hotelknop_tijdens_het_plaatsen`, `test_het_boek_is_overal_bereikbaar` (kamer1, tuin, keuken), `test_de_plekken_liggen_verspreid` en `test_een_plant_is_te_draaien`. Beeld: `--kamer kamer1 --band 5 --tik spel_meubels --uit /tmp/n12`.

#### `N13` — Tobbe: de badstap werkt en het dier zit in de kuip 🔎
- [ ] omvang **M** · model **opus** · hangt af van: `N4`, `S1`
- **stappen** 1) `_geslaagd()` (`:875-904`) nodigt dezelfde gasten uit die `_wachtenden()` (`:959-965`) telt — dus `_badgasten()` met zijn terugval, hoogstens `M * 2` dieren — zodat het wolkje `N mogen in de tobbe` niet meer over dieren gaat die nooit komen. 2) De hertekenlus in `_teken_baden` (`:1013-1023`) telt door zolang er iemand onderweg is, met een plafond van 30 × 0,9 s in plaats van 8 (een gast uit een slaapkamer is 11-15 s onderweg), en stopt zodra iedereen er is. 3) Nieuwe `World.in_kuip(id, x, z, hoogte)` naar het voorbeeld van `_in_bed` (`world.gd:1021-1036`): kamer + plek van de tobbe, `hoogte`/`lift` op de sopstand, `pose = "zit"`, `staat = "pose"`, route leeg. `_in_bad` (`:1044-1082`) gebruikt die in plaats van `World.reis` naar (x−7, z+7) — náást de kuip. Zeepbellen via het bestaande `_bubbels()`. 4) De ✓-knop van de badstap op dezelfde gereedschapsplek bij elke band. 5) Controleer met `S1` erbij dat het slepen van een dier naar een tobbe werkt (`_val`, `:686-692`, kent `wat: "dier"` al).
- **acceptatie** `DH_TEST_FILTER=tobbe` en `=test_world` groen plus `test_de_badstap_krijgt_zijn_dieren` (voor elk wachtend dier bestaat een `tb_dier<id>`-hotspot zodra het in de tuin staat, ook uit kamer1), `test_een_dier_in_bad_zit_in_de_kuip` (`World.dier(id).x/z` binnen 2 voxels van het tobbepunt, `hoogte > 0`) en `test_klaar_met_badderen_geeft_een_ster`. Beeld: `--kamer tuin --band 4 --tik spel_tobbe --wacht 12000 --uit /tmp/n13` — een dier zit zichtbaar ín de kuip met zeepbellen.

#### `K2` — Sleutels: de gast loopt zichtbaar weg, en de rij staat stil
- [ ] omvang **S** · model **opus** · hangt af van: `K1`
- **stappen** 1) `_goed()` herordenen: haakje vullen, geluid, `state.tel`, `_teken()`, **dán** het afscheidswolkje `sl_af` maken, dan `ctx.wereld.ga(gast, dp.ix, dp.iz)` met `dp = Rooms.deur(ctx.kamer, "gang")`, dan `await na(1.2)` (met de verplichte `if not actief: return`), dan `ctx.wereld.slaap(gast, kamer, bed)`, dan het 💡-plaatje boven zijn deur bijwerken, en pas dan de volgende sleutel of `_klaar()`. 2) `_klaar()` mag het afscheidswolkje niet in hetzelfde beeld wegvegen (`_teken()` begint met `wis_alles()`, `:663`): eerst `await na(1.4)` in de receptie, dán `ctx.wereld.naar("gang")` en het ⭐-wolkje. 3) Rij-krimp (de rest van het geschrapte rek-ontwerp): `dx` wordt `dx_min + 1` in plaats van `_hoog(0.1625)`, zodat de rij hooguit ~60 % van de kaderbreedte beslaat in plaats van dwars door de kamer (gemeten: nu 310 px tussen twee plaatjes); `_lay` wordt bij `start()` en bij een echte kaderwissel gekozen, niet bij elke `_teken()`; `_wijk_van_voorwerpen` ontwijkt alleen nog de balk. 4) Controleer dat `stop()` nog steeds iedereen netjes in bed legt.
- **acceptatie** `DH_TEST_FILTER=sleutels tools/test.sh` groen plus: na een goed antwoord bestaat `Hits.spot("sl_af")` nog en staat de camera nog in de receptie (in rustmodus lopen de wachttijden meteen af, dus niet op echte tijd wachten); de schermrechthoeken van `sl_h0..sl_hN` liggen binnen 4 px van dezelfde y; **één misser verandert de y van `sl_h0` met hoogstens 1 px** (regressie op het 414 px-springen). Beeld: `--kamer receptie --tik spel_sleutels` op vier kaders.

#### `R3` — De Kas 🪴 achter het tuinhek, en het hinkelpad kruist de poort niet meer 🔎
- [ ] omvang **M/L** · model **opus** · hangt af van: `R2`
- **stappen** 1) Nieuw `art/decor_kas.gd` (`class_name ArtDecorKas`): `moesbak` (met `params.groei` 0..3: kale aarde / kiempjes / blaadjes / rijtjes sla), `moesinhoud` (alleen de inhoud, voor de dagdressing), `potkast`, `zaadkist` (toekomstig ingangsvoorwerp), `kruiwagen`, `gieter`, `hangplant`. Aanmelden in `ArtDecor._extra()`; unieke namen, bakbaar op g = 2/3/4. 2) `_kamer({...})`-blok voor `kas` onderaan `_bouw_kamers`: `w 110, d 96, wand 40, vloer "tegel", loop 1.25`, zone `rijen`, poort naar de tuin. Een ommuurde kas kost nul nieuwe vloer- of camerabouw (een `erf: true` zou een `vast_kader`, een hekgenerator en gazon in `scenes/vloer.gd` vragen). 3) In de tuin: de poortdeur in de **linker** hekwand plus `{"n": "poort", "x": 10, "z": 90, "ver": true}`. De achterwand mag niet: die is bezet door het hok (x 56..78) en de kist op (95, 23), en die kist staat in de `groot`-lijst van `_bouw_tuin`. 4) `_bouw_tuin` (`rooms.gd:737-747`): `if z < 34 or z > 46` wordt `if (z < 34 or z > 46) and (z < 84 or z > 96)`; de paal op z = 94 vervalt, **`hekz` gaat van 8 naar 7** (`tests/test_rooms.gd:199`), `hekx` blijft 7. 5) **In dezelfde taak:** schuif de hinkelzone (`rooms.gd:620`) van `z0/z1 34/50` naar `44/60`, zodat het pad vóór de zwembadpoort langs loopt. Zet twee lage struiken en een bankje **buiten** de zone langs het pad. 6) De 14 gezaaide graspollen verschuiven daardoor: regenereer de gouden tabel (`tests/test_rooms.gd:201-212`) **uit een headless run, bit voor bit** — één keer, aan het eind. 7) `ui/plattegrond.gd KAART`: `"kas": [4, 1]`. 8) `Snd.SFEER["kas"] = "warm"` (hergebruik, geen nieuwe lus). 9) `ORDE`, maten `[110, 96, 40, "tegel", 1.25]`, kader en deurpunten geregenereerd. 10) Helpregel `kiek.js` + HOTEL.md-rij.
- **acceptatie** `DH_TEST_FILTER=test_rooms tools/test.sh` 0 fout met de bijgewerkte hek- en pollentabellen en `test_elke_kamer_is_compleet` voor de kas (≥ 16 dwaalplekken); `=test_art`, `=test_plattegrond`, `=test_ui` 0 fout; `=hinkel` en `=kraam` groen (hun dekkings- en kadertests gebruiken de zones), met een nieuwe test `test_het_pad_raakt_de_poort_niet` in `games/hinkel/test_hinkel.gd`. Beeld: `--kamer kas --band 4 --uit /tmp/r3` (vier moesbakken in twee rijen, niets door een wand) en `--kamer tuin --band 5 --uit /tmp/r3t` (twee openingen in het linkerhek, hok en kist onveranderd, het pad vóór de poort langs).

---

### Batch 5 — De balk is af; de hotel-lus; het voerrondje

**Bestandssets** — `B5`: `ui/rekenbalk.gd`, `ui/thema.gd`, `autoload/hits.gd`, `autoload/ui.gd`, `tests/test_balk.gd`, `HOTEL.md` · `V4`: `games/voerkar/spel.gd`, `games/voerkar/test_voerkar.gd` · `N11`: `games/hinkel/spel.gd`, `games/hinkel/test_hinkel.gd` · `N14`: `games/zwembad/spel.gd`, `games/zwembad/test_zwembad.gd` · `K4`: `games/wekker/spel.gd`, `games/wekker/test_wekker.gd` · `L1`: `autoload/hotel.gd`, `hotel/prikbord.gd`, `scenes/main.gd`, `tests/test_hotel.gd` · `R4`: `autoload/rooms.gd`, `art/decor_zwembad.gd` *(nieuw)*, `art/decor.gd`, `tests/test_rooms.gd`, `tests/test_art.gd` · `S2`: `ui/wolk.gd`, `tests/test_hits.gd`. *Geen overlap.*

#### `B5` — De wijzer, het papier en de hysterese
- [ ] omvang **M** · model **opus** · hangt af van: `B4`
- **stappen** 1) `Hits.mik_van(id) -> Vector2` en `Hits.vlak_van_spot(id) -> Rect2` als kleine lezers op `_laatste`. 2) `UiRekenbalk._draw()` uitbreiden: een driehoekje 12 × 8 op de bovenrand op `clamp(mik.x, rect.x + 24, rect.end.x − 24)`; heeft het voorwerp in deze kamer een echt vlak, dan een afgerond ringetje van 2 px (`PERZIK_D`) eromheen plus een 1 px verbindingslijn. Niets hiervan vangt tikken (`mouse_filter = IGNORE`). 3) De balk krijgt het rekenschrift-uiterlijk: `PAPIER` als vlak en `PAPIER_LIJN` op **de regelhoogtes van de balk zelf** (zodat een lijn nooit door een letter loopt, anders dan `ui/kaart.gd:191-195` vandaag) en `SCHADUW_KL` als bovenrand. 4) Hysterese op de vormwissel: dode zone 440/480 op kaderhoogte, 400 ms stilte na een eigen wissel, hoogstens 2 wissels per schermmaat (dezelfde getallenvorm als `world.md §5.5`). **Bij een vormwissel alleen `add_theme_font_size_override` opnieuw zetten op de bestaande Controls en opnieuw laten plaatsen — géén `Hits.maak` met hetzelfde id, géén nieuwe `Ui.Kaart`**: een herbouw zou elke mutatie ná het maken van de kaart wissen (`bedden` roept `_kaart.som()` + `.zet()` per bedje aan, `wekker`/`zwembad`/`was` roepen `.hulp()` en `.zet_goed()`). 5) `Ui.toast` (`ui.gd:239-241`): `var boven := band.size.y < 450.0 or balk_aan()` — de toast staat voortaan altijd bovenin, nooit meer over de antwoordknoppen. 6) **HOTEL.md §9**: één alinea bijschrijven dat de rekenbalk de plek van de sommenkaart is, met de wijzer als verplichte haak naar het voorwerp (R9).
- **acceptatie** `DH_TEST_FILTER=test_balk tools/test.sh` groen met: de wijzer-x ligt binnen 1 px van `Hits.mik_van(id).x`, geklemd in de balk; 40 wisselingen tussen kaderhoogte 430 en 470 leveren hoogstens 2 vormwissels op; na een vormwissel heeft de kaart de lettermaat van de nieuwe rung **en houdt ze haar inhoud** (zet een `hulp()`-regel, wissel de vorm, controleer dat de regel er nog staat). `=test_ui` groen (toast bovenin). Beeld: `--kamer kamer1 --band 4 --tik spel_bedden --uit /tmp/b5a` en `--kamer tuin --tik spel_kraam` — de wijzer staat aantoonbaar onder het juiste voorwerp, het ringetje eromheen, geen liniatuur door letters.

#### `V4` — Het rondje: één tik duwt de kar, elk bakje vraagt zijn eigen som 🔎
- [ ] omvang **M** · model **opus** · hangt af van: `V3`, `S1`
- **stappen** 1) Vervang `_rondje()` door `_teken()` met een schakelaar op `K.stap` en `World.kamer_nu()`. 2) `_duw_knop()`: `ctx.hotspots.bron("kar", {id: "karhot", sleep: "deur", aantal: K.op_kar, prio: 11, tik: _tik_duw, volg: _volg_kar(16.0)})`, label `🛒 ` + `T_DUW_NAAR % kamernaam`, en `_verf("karhot", UiThema.ZON)`. 3) `duw(kamer)`: `ctx.snd.kar()`, `ctx.wereld.ding_zet("kar", {kamer, x, z})` waarbij (x, z) de dichtstbijzijnde **vrije** cel bij het bak-slot is — loop `Rooms.get_kamer(kamer).vrij` af, kies de kleinste manhattan-afstand tot `(slot.sx − 14, slot.sz + 10)` waarvoor `Rooms.vrij_vak()` waar is, val terug op het midden van de kamer (fix: de kar stond dwars door het bed). Dan `ctx.wereld.naar(kamer)`, `Hotel.render()`, `_teken()`. 4) `_bak_wolk()`: `👉 Tik op het bakje` op het bak-slot, in `UiThema.ZON`. `_leen_doelen()` krimpt tot: leen `bak_<kamer>_<slot>` met `ctx.hotspots.pak(id, _tik_bak)` en zet er via `Hits.zet_drop` (uit `S1`) `drop: "deur"` + `val: _val_lever` op, elk beeld opnieuw. **De deuren worden niet meer gemanipuleerd** (vandaag verving `_leen_doelen` alleen `s.val` en nooit `s.aan`, waardoor een tik op een deur het hele spel liet verdwijnen). 5) `_bak_kaart(kamer, slot)`: `hier` = de meespelende gasten van deze kamer, `goed = hier.size() * K.per`; somregel `"%d × %d"` **alleen** als `hier.size() in Sommen.TAFEL_SET[band]`. Goed → bakje vol, `feest`, `K.op_kar -= samen`, 😋-wolkje, `Hotel.render()`, `_teken()`. Fout → misser, hulpregel met de herhaalde optelling `🥄 10 + 10`, vanaf twee missers Els. 6) Staat het kind elders: één tikbaar wolkje op de deur met `👉 De kar staat in %s`. 7) Slot: `ctx.state.tel(K.missers == 0, nu − K.t0)` **één keer voor de hele beurt**, `ctx.taak_klaar("voer", {"sterren": 0})` (het vinkje pas nú — de ster viel al bij `V3`), `ctx.wereld.ding_thuis_zet("kar")` zonder camerareis, ✅-wolkje 2,6 s, `ctx.sluit()`. 8) Nieuwe publieke `todo() -> Dictionary` volgens §3.2 — nooit leeg zolang het spel draait.
- **acceptatie** `DH_TEST_FILTER=voerkar tools/test.sh` groen (alle bestaande plus zes nieuwe): `_hele_beurt` speelt deling → duw → bakjesom per kamer; `test_tik_op_een_deur_verliest_het_spel_niet`; `test_de_kar_staat_nooit_op_een_bed`; `test_altijd_precies_een_todo` (in elke stap is `todo()` niet leeg en draagt precies één zichtbare eigen hotspot de ZON-kleur); `test_taak_voer_pas_als_alle_bakjes_vol_zijn`; `test_herstel_midden_in_het_rondje`. Ook `=test_hotel` groen. Beeld: vier PNG's (som / duwknop / bakjeswolkje / bakjessom) die elk precies één geel oplichtend element tonen, plus één op `360x740@3`.

#### `N11` — Hinkel: de som staat er meteen, het dier komt eraan
- [ ] omvang **S** · model **opus** · hangt af van: `N5`
- **stappen** 1) `_teken_kaart()` (`:728-745`) bouwt de keuzes ook wanneer `_op_start_steen()` nog onwaar is; de kaart toont meteen de gewone vraag in plaats van `Tel straks mee`. 2) Een antwoord dat vóór zijn aankomst valt wordt bewaard in `_s["wacht_keuze"]` en uitgevoerd zodra `_wacht_lus()` (`:478-495`) merkt dat hij op zijn steen staat — er is en blijft precies één lus. 3) Laat `_gast()` echt de voorkeur geven aan een dier dat al in de tuin staat (`_spelers()` sorteert daar al op), zodat de wandeling meestal kort is. 4) Het `komt eraan`-wolkje blijft bij de deur staan zolang hij loopt.
- **acceptatie** `DH_TEST_FILTER=hinkel tools/test.sh` groen plus `test_de_strook_staat_er_voor_de_gast_er_is` (met de gast in kamer1 bestaat `hk_som_keuzes` direct na start met ≥ 2 knoppen) en `test_een_antwoord_voor_de_aankomst_gaat_niet_verloren` (precies één keer uitgevoerd). Beeld: `--kamer tuin --band 4 --tik spel_hinkel --wacht 1200 --uit /tmp/n11`.

#### `N14` — Zwembad: snel meetikken per strook (de eigenaarswens)
- [ ] omvang **S** · model **opus** · hangt af van: `N3`
- **stappen** 1) In `_zwem`'s `per_stap`-callback (`games/zwembad/spel.gd:369-380`) hangt tijdens het zwemmen één knop op de zwemmer: icoon 🫧, label `Tik!`, badge `!`, plus het wolkje `🫧 Tik snel mee!` (3 woorden, 14 tekens). 2) Elke tik = één zwemslag: `Snd.plop(1)`, drie zeepbelletjes (`World.spetter` met `ArtEffect.ZEEP_KL`) en `d.beweeg_tempo += 0.12`, geklemd op 0,6..2,2. Nagekeken: `beweeg_tempo` is een gewoon veld op `World.Dier` (`world.gd:112`), wordt door `stappen()` gezet (`:855`) en elke wereldtik gelezen (`:1425`) — **nul motorwijziging**. In `per_stap` zakt het weer terug naar het basistempo. 3) Niet tikken kan ook: op het basistempo komt hij er altijd. Geen klok, geen faalstaat, geen tegenstander. 4) In rustmodus (`World.rust()`) verschijnt de knop niet. 5) De knop verdwijnt zodra de etappe klaar is, zodat hij nooit met de som concurreert (R2: ná de som, nooit ervoor).
- **acceptatie** `DH_TEST_FILTER=zwembad tools/test.sh` groen plus `test_tikken_versnelt_maar_is_nooit_nodig` (tien tikken verhogen `beweeg_tempo` en verlagen de duur; nul tikken bereikt dezelfde eindplek) en `test_de_tikknop_bestaat_alleen_tijdens_het_zwemmen` (niet terwijl de kaart open staat, niet in rustmodus). Dekkingstest op vier kaders blijft groen en de kamer blijft onder 16 hotspots. Beeld: twee foto's tijdens het zwemmen, met en zonder tikken, plus het log met `beweeg_tempo`.

#### `K4` — Wekker: de wijzerplaat is echt af te lezen
- [ ] omvang **M** · model **opus** · hangt af van: `K3`
- **stappen** Alles in `_klok_model()` en de stralenconstanten. 1) De naaf (`ArtVorm.bx(v, -1, CY-1, 2, 2, 2, 1, KL_HART)`, `:427`) **vóór** de twee `_streep`-aanroepen tekenen, zodat de wijzers erover komen in plaats van doorgesneden te worden. 2) De uurwijzer kort en **dik** (`dik` 1.0 → 2.0, donkerder), de minuutwijzer langer en dunner — het verschil moet in de dikte zitten, niet alleen in de lengte; een kind leest "dik en kort = uur". 3) Grotere plaat: `R_KAST` 25→30, `R_RAND` 27, `R_PLAAT` 24, `R_STREEP` 20, `R_UUR` 12, `R_MIN` 19 (past binnen de gangwand van 56 bij `CY` 34). 4) 12/3/6/9 als echte wiggen van `R_STREEP − 5` tot `R_STREEP + 1`, de overige acht als stipje, en de 12 in een eigen donkerder kleur zodat "boven = 12" vastligt. 5) De spookwijzers worden **mikpunten**: één bleek blokje van ±3 × 3 schermpunten op de tip van elke doelwijzer (de stippellijn van `_streep(stap: 1.5)` smelt na `_naar_vox` toch dicht tot een massieve balk die als tweede wijzer leest). Behoud `KL_SPOOK_U` en `KL_SPOOK_M` — `test_klokmodel` controleert erop. 6) Controleer dat `_plaat_vrij()` op alle vier de kaders nog minstens 20 × 20 reserveert.
- **acceptatie** `DH_TEST_FILTER=wekker tools/test.sh` groen, `test_klokmodel` meegewijzigd (twee spookkleuren blijven aanwezig, het voxelaantal groeit). Beeld: `--kamer gang --band 4 --tik spel_wekker --uit /tmp/k4` op 1024×768 en 360×740 plus een uitsnede van de klok, en één foto in de stand met drie missers. Beoordeling met het blote oog: uur- en minuutwijzer zijn zonder twijfel uit elkaar te houden, de naaf snijdt geen wijzer door, 12/3/6/9 zijn duidelijk groter, en de spookmarkeringen lezen als mikpunten.

#### `L1` — De hotel-lus klopt weer: bord, dagronde en één voerroute 🔎 ⚠️
- [ ] omvang **M** · model **opus** · hangt af van: — · **eerst `git diff autoload/hotel.gd tests/test_hotel.gd` draaien**
- **stappen** 1) `toon_bord()` (`hotel.gd:1038`) geeft de drie kaartjes niet meer alle drie `"obj": "prikbord"` maar elk een eigen mikpunt, zodat `Hits` ze niet op diepte omkeert (`hits.gd:259-262` sorteert bij gelijke prio op diepte en plaatst rond het object, `:559`). Het kaartje met de hoogste prioriteit staat bovenaan. 2) `prikbord_tik()` (`:1014`) is geen blinde toggle meer: hij opent als er niets zichtbaars op het scherm staat. Oorzaak van vandaag: `main.gd:87` roept `Hotel.start()` al aan op de lege standaardstaat, waardoor `_bord_open` op `true` staat terwijl `render()` in `kaart_afdruk()` geen verschil ziet (`:198` vs `:203`) en niets tekent. 3) `hotel/prikbord.gd:106`: een afgevinkt kaartje zakt naar onderen in plaats van de bovenste van drie plekken te bezetten. 4) `State.s["ronde"]` blijft `"ochtend"` tot de ochtendtaken af zijn in plaats van na de eerste tik op `"vrij"` te springen (`:975`, `:808`). 5) `scenes/main.gd:135`: de chroomknop "🌙 Avond" krijgt dezelfde poort als de balielamp — `Hotel.avond_klaar()` (`:1262`). 6) **Eén voerroute:** `tik_bak()` (`:828-855`) houdt het eten, `World.feed`, de vervolgwens en de toast, maar `Econ.sterren(1, "voeren")` en `taak_af("voer")` gaan eruit (`:843-845`); bij een leeg bakje wordt de toast `🍪 Haal eerst de voerkar` (4 woorden, 24 tekens). 7) De dode `const KAART` (`:68-70`) weg — nul verwijzingen in de repo, `UiPlattegrond.KAART` is de echte. Raak de `WENSSPEL`/`tik_wens`-code van de tweede agent niet aan.
- **acceptatie** `DH_TEST_FILTER=test_hotel tools/test.sh` groen (29 bestaande, inclusief de nieuwe test van de tweede agent) plus: `test_het_bord_staat_op_prioriteit` (de y van bord_0 ≤ die van bord_1 ≤ die van bord_2 en `bord_0` heeft de hoogste prio), `test_de_eerste_tik_opent_het_bord`, `test_een_afgevinkt_kaartje_zakt`, `test_een_tik_op_een_vol_bakje_geeft_geen_ster` (sterrentotaal gelijk, kaartje `voer` blijft open). `grep -rn 'Hotel.KAART'` leeg. Beeld: `--kamer receptie --band 4 --uit /tmp/l1a` en `--tik prikbord --uit /tmp/l1b` — de eerste tik toont drie kaartjes in de goede volgorde.

#### `R4` — Zwembad: een achterrand en een dek dat leeft
- [ ] omvang **M** · model **opus** · hangt af van: `R3`
- **stappen** 1) Nieuw `art/decor_zwembad.gd` via `ArtDecor._extra()`; unieke namen, bakbaar op g = 2/3/4, **niet** in `ArtDecor.NAMEN` (`tests/test_art.gd:267` eist `NAMEN.size() + POL_AANTAL == 34`). Modellen: `zwembadrand` (lage tegelrand achter het water, snijdt het bad niet), `ligbed`, `parasol`, `handdoekrek`, `duikplank`, `badeend`. 2) In `autoload/rooms.gd` het `zwembad`-blok aanvullen. Nagerekend waarom er vandaag geen achterrand is: `_bouw_zwembad` slaat elke `hekx` over die tussen `bad.x0 = 18` en `bad.x1 = 134` valt, en met stappen van 14 vanaf x = 24 blijft er precies **één** paal over (x = 136). De tegelrand vervangt dat. 3) Twee ligbedden en een parasol op de lege rechterhelft, een handdoekrek bij `dek.over`, de duikplank naast het startblok. 4) **Houd alles weg van z = 46 en z = 50**: daar liggen de meterstreepjes en de vlag van het zwemspel (`games/zwembad/spel.gd:493-523`). 5) Badeendjes als los decor met `"door": "hotel"`.
- **acceptatie** `DH_TEST_FILTER=test_rooms` groen (elk decormodel bestaat, `:164`), `=test_art` groen (unieke namen, drie schalen), `=zwembad` groen — met name de dekkingstest: geen knop en geen streepje valt op een nieuw voorwerp, en de dwaalplekken-invariant (`tests/test_rooms.gd:215-232`) houdt. Beeld: `--kamer zwembad --band 4 --uit /tmp/r4a` en `--tik spel_zwembad --uit /tmp/r4b` — rand achter het water, rechterhelft niet meer leeg, getallenlijn met vlag volledig zichtbaar.

#### `S2` — Ook een wolkje schakelt een drop door ⚠️
- [ ] omvang **S** · model **opus** · hangt af van: `S1` · **eerst `git diff ui/wolk.gd` draaien**
- **stappen** Voeg in `ui/wolk.gd` dezelfde twee virtuals toe als in `S1` (`_can_drop_data` / `_drop_data` via `Hits.vang_onder`), zodat een drop die op een wenswolkje of een to-do-wolkje landt ook aankomt. **Alleen die zes regels; herschrijf niets** — dit bestand heeft een `hint`-tak van de tweede agent (`:38-41`). Test erbij in `tests/test_hits.gd` (niet in `tests/test_ui.gd`).
- **acceptatie** `DH_TEST_FILTER=test_hits tools/test.sh` groen met een test die een wolkje over een drop-doel legt en bewijst dat de drop aankomt; `=games` één keer volledig groen.

---

### Batch 6 — De Nu-chip, en de spellen verhuizen naar de balk (A)

**Bestandssets** — `B6`: `autoload/hotel.gd`, `autoload/games.gd`, `spel/ctx.gd`, `ui/rekenbalk.gd`, `scenes/main.gd`, `ui/hud.gd`, `tests/test_balk.gd`, `tests/test_hotel.gd` · `B8`: `games/bedden/spel.gd`, `games/meubels/spel.gd`, `games/sleutels/spel.gd`, `games/tobbe/spel.gd`, `games/voerkar/spel.gd` · `K5`: `games/wekker/spel.gd`, `games/wekker/test_wekker.gd` · `R5`: `autoload/rooms.gd`, `art/decor_hotel.gd`, `art/decor_slaapkamer.gd`, `art/decor_keuken.gd`, `tests/test_rooms.gd`, `tests/test_hits.gd` · `M1`: `games/polonaise/beurt.gd`, `games/polonaise/test_polonaise.gd` *(beide nieuw)*. *Geen overlap.*

#### `B6` — `Hotel.volgende_stap()` en de "Nu"-chip 🔎 ⚠️
- [ ] omvang **M** · model **opus** · hangt af van: `B2`, `L1` · **eerst `git diff autoload/hotel.gd` draaien**
- **stappen** 1) `Hotel.volgende_stap() -> Dictionary` met de zes stappen uit §3.1; elke tekst door `Ui.keur_taak` (≤ 6 woorden). Stap 4 leest de gesorteerde takenlijst van `hotel/prikbord.gd:107` — die klopt pas ná `L1`. 2) `Games.stap_nu() -> Dictionary` + `ctx.nu(icoon, tekst)` in `spel/ctx.gd` (klasse `UiVoor`); `Games.start()`/`stop()` wissen hem. Géén spel hoeft dit nu al te gebruiken — de standaardtekst **`📋 Maak eerst de som`** dekt het af (**niet** 🧮: dat teken zit niet in de fontsubset, R10). 3) `UiRekenbalk`: een `Nu`-knop (pil in `UiThema.ZON`, links het grijze woordje "Nu", dan pictogram + tekst in maat `balk_nu`, rechts optioneel een kamerchip als `kamer != World.kamer_nu()`), minimaal 48 hoog, zichtbaar zodra er geen kaart en geen melding in de balk staat. Een tik doet `Hotel.doe_taak({kamer, actie})` — exact de weg van een bordkaartje (`hotel.gd:973`); bij `bron == "spel"` is de chip **niet** tikbaar (hij beschrijft de stap; een tik zou een halve beurt afbreken). 4) `scenes/main.gd`: ververs op `Hotel.bord_veranderd`, `hud_veranderd`, `dag_veranderd`, `checkin_veranderd`, `avond_veranderd`, `World.kamer_veranderd`, `Games.spel_gestart`, `Games.spel_gestopt`. De balk vergelijkt met het vorige woordenboek en tekent alleen bij verschil opnieuw — geen werk per frame. 5) `ui/hud.gd:55`: de chroomknop 📋 Prikbord krijgt `Hotel.open_taken()` als teller, zodat het getal buiten de receptie niet verdwijnt.
- **acceptatie** `DH_TEST_FILTER=test_balk tools/test.sh` groen met een test die `volgende_stap()` in zes toestanden controleert: leeg hotel (bel), gast zonder bed, leeg bakje met gasten, **een onvervulde wens in de huidige kamer wint van het bordkaartje**, draaiend spel, en alles af + uitcheck (avond). Elke tekst ≤ 6 woorden, draagt een pictogram en `Ui.mist_tekens(zin) == []`. `=test_hotel` groen. Beeld: `--kamer receptie --band 4 --uit /tmp/b6a` en `--kamer kamer1 --band 4 --uit /tmp/b6b` — in beide kamers staat onderin één gele chip met de volgende stap, in kamer 1 mét kamerchip naar de keuken.

#### `B8` — Spellen A in de balk: bedden, meubels, sleutels, tobbe, voerkar
- [ ] omvang **M** · model **opus** · hangt af van: `B5`, `V4`, `K2`, `N9`, `N12`, `N13`
- **stappen** 1) Haal de plaatsingshacks weg die er alleen waren omdat de kaart aan haar voorwerp hing: `games/voerkar/spel.gd` gaf een kaal punt naast de kast op in plaats van het echte voorwerp — geef nu het voorwerp op; `games/bedden/spel.gd` verlaagde de prio naar 13 — terug naar de standaard 14; `som_plek()`/`_snap_hoogte`-berekeningen die alleen de kaart positioneerden vervallen. **Het `obj`-argument van `ctx.ui.somkaart` blijft staan**: dat is nu de bron van de wijzer en de ring. 2) Loop per spel de beurt op band 3, 4 en 5 na op drie kaders en controleer dat de zin nog past (≤ 8 woorden / ≤ 40 tekens) nu hij op 22 px staat in plaats van 14. 3) Wijzig geen kindzin zonder hem woordelijk ook in de speltest bij te werken.
- **acceptatie** `DH_TEST_FILTER=bedden`, `=meubels`, `=sleutels`, `=tobbe`, `=voerkar` alle vijf groen, inclusief de eigen dekkingstest op vier kaders en de "elke kindzin staat woordelijk in de bron"-test. Beeld per spel op tablet én telefoon: de kaart staat in de balk, de wijzer onder het juiste voorwerp, en geen enkele spelknop staat nog in de balkstrook.

#### `K5` — Wekker: zelf de bel luiden, en het wakker worden duurt lang genoeg
- [ ] omvang **M** · model **opus** · hangt af van: `K4`
- **stappen** 1) Nieuwe stap `bel` tussen goed antwoord en wakker worden, in `_s["stap"]` (dus herlaadbestendig; ook in `_lees_stand()`). Bij een goed antwoord: `Snd.klok(true)`, de kaart wordt regel `De klok staat goed` (4/18) / regel2 `Luid de wekker` (3/14) / hulp `tik op de bel` (4/13), en de strook wordt **één** knop `🔔 Bel`. Alle vier de teksten als `const` bovenaan. 2) Tik op 🔔 Bel: `Snd.bel()`, de twee belletjes bovenop de klok wippen kort (extra param in `klok_params`), en **dán** pas reist de camera naar de kamer van de gast. 3) Bij het wakker worden gaat de kaart **weg** in plaats van mee — het feest hoort bij het dier: pose `blij`, het bestaande wolkje `☀ goedemorgen`, `Snd.hoera()`, de ster. `VOLGENDE_S` van 2,2 naar 3,2 s. (Vandaag springt de camera meteen naar de slaapkamer terwijl de kaart met "Boef is wakker" in de gáng blijft hangen, dus het kind ziet die tekst nooit.) 4) Verlaat het kind tijdens het spel de gang, dan komt er op de deur terug een wolkje `⏰ de klok staat in de gang` (6/26); haak aan op het bestaande `_op_kamer()`. 5) Werk `test_de_wekslag_wordt_nooit_afgeremd` bij: de gong klinkt nog steeds bij het goede uur, de bel is een extra geluid.
- **acceptatie** `DH_TEST_FILTER=wekker tools/test.sh` groen met een test die de hele keten speelt (goed zetten → `stap == "bel"` en de strook heeft precies één knop → knop tikken → `stap == "wakker"`, wolkje `wk_zon` bestaat, precies één ster per ronde) en een test dat de kaart in de stand `wakker` weg is. Beeld: na de bel staat de camera in de slaapkamer met het dier en het ☀-wolkje in beeld.

#### `R5` — Meer decor in de bestaande kamers, binnen het vakjesbudget
- [ ] omvang **M** · model **opus** · hangt af van: `R4`
- **stappen** Harde regel: **wanddecor** (`ver: true`, `x <= 2` of `z <= 2`) kost hoogstens één vrij vakje en mag altijd; **vloerdecor** kost ~12 vakjes en mag alleen als de kamer daarna nog ≥ 8 dwaalplekken houdt. Gemeten uitgangsstand: gang 7 vrije vakjes / 4 dwaalplekken, wasserij 32/17, kamer2 38/18, kamer1 41/18, receptie 46/25, keuken 56/29. 1) **Gang: uitsluitend wanddecor** (een vierde wandhaakje, een bordje). 2) Receptie: een tweede koffer, een tijdschriftenrek, een wimpel boven de nieuwe deur. 3) Kamer1 een tweede schilderij, kamer2 een raam in de achterwand — beide op de wand. 4) Wasserij: een wasmand en een wasrek (dat laatste is meteen de waslijn-sierplek van `R6`). 5) Keuken: een broodplank en een kruidenrek aan de wand. 6) **Gratis variatie op wat er al staat:** geef de graspollen van tuin en zwembad een `rot` (`"rot": i % 4` in de pollenlus) en de hekpalen een afwisselende `rot`. `Rooms` geeft `rot` al door de hele keten (`scenes/kamer.gd:92` → `WereldObject.zet_model` → `World.plaat`, echte kwartslagen met een cache van 24) maar gebruikt hem voor vast decor nergens; de gouden pollentabel leest alleen `n`, `x` en `z` en blijft dus **letterlijk** staan — dat is meteen het bewijs dat de ingreep veilig is. 7) Geef `plant` twee potkleuren via `params`, afwisselend per plek. 8) Voeg aan `test_elke_kamer_is_compleet` (uit `R1`) de assertie toe dat elke kamer ≥ 8 dwaalplekken heeft en de gang ≥ 4.
- **acceptatie** `DH_TEST_FILTER=test_rooms tools/test.sh` 0 fout met de ongewijzigde gouden pollentabel en de nieuwe minimum-plekken-assertie; `=test_hits` 0 fout (geen knop dekt een nieuw voorwerp af op de vier kaders); `=test_world` 0 fout. Beeld: vóór en ná van gang, kamer1, kamer2, wasserij, receptie en keuken op tablet én telefoon — nergens steekt een prop door een wand of staat er iets in een deuropening.

#### `M1` — Polonaise: de patroongenerator
- [ ] omvang **S** · model **opus** · hangt af van: —
- **stappen** Nieuw `games/polonaise/beurt.gd` (`class_name PolonaiseBeurt`, alleen statische, wereldvrije functies) met een eigen `Sommen.Prng`, gezaaid op `dag ^ aantal gasten` — **de bevroren kern wordt alleen gelezen**. Levert per band: het patroon (band 3 AB, band 4 AAB/ABC, band 5 groeiend in sprongen), de volgende soort, en de telsom met haar sombalk (band 3 `2 + 2 =`, band 4 `3 × 2 =` of `9 : 3 =` binnen `Sommen.TAFEL_SET[4]`, band 5 `1 + 2 + 3 + 4 =`). Neem de soort→pictogram-tabel over als eigen `const` (het voorbeeld staat in `games/voerkar/spel.gd:48-49`). Nieuw `games/polonaise/test_polonaise.gd`. **Nog geen `spel.tscn`** — zonder scene scant `Games` de map niet als spel (`games.gd:41-59`), dus deze taak is volledig onzichtbaar en veilig los te committen.
- **acceptatie** `DH_TEST_FILTER=polonaise tools/test.sh` groen: hetzelfde zaad geeft hetzelfde patroon; band 3 kent geen deelteken; elke sombalk van band 4 valt binnen `TAFEL_SET[4]`; elk antwoord is een geheel getal ≥ 0; het patroon is nooit constant (anders is "wie komt hierna" geen vraag). `DH_TEST_FILTER=test_games tools/test.sh` blijft groen (de map telt nog niet als spel).

---

### Batch 7 — Meldingen, aaien, de spellen in de balk (B), en het eerste nieuwe spel

**Bestandssets** — `B7`: `autoload/ui.gd`, `ui/rekenbalk.gd`, `ui/wolk.gd`, `ui/thema.gd`, `ui/hotknop.gd`, `hotel/rekening.gd`, `tests/test_balk.gd` · `B9`: `games/zwembad/spel.gd`, `games/wekker/spel.gd`, `games/hinkel/spel.gd`, `games/was/spel.gd`, `games/kraam/spel.gd` · `D2`: `hotel/aaien.gd` *(nieuw)*, `autoload/hotel.gd`, `autoload/hits.gd`, `art/effect.gd`, `tests/test_aaien.gd`, `tests/test_hits.gd` · `M2`: `games/polonaise/spel.gd`, `games/polonaise/spel.tscn`, `games/polonaise/test_polonaise.gd` · `K6`: `games/sleutels/spel.gd`, `games/sleutels/test_sleutels.gd` · `R6`: `hotel/sier.gd` *(nieuw)*, `autoload/world.gd`, `art/decor_hotel.gd`, `tests/test_sier.gd` *(nieuw)*, `tests/test_world.gd`. *Geen overlap.*

#### `B7` — Meldingen onderin en grotere tekst in de wereld ⚠️
- [ ] omvang **M** · model **opus** · hangt af van: `B5` · **eerst `git diff ui/wolk.gd` draaien**
- **stappen** 1) `Ui.melding(icoon, tekst, o = {})` — zet een boodschap in het melding-slot van de balk in maat `balk_zin`, met een optionele knop rechts; verdwijnt na `o.ms` (standaard 3200) of blijft bij `o.blijf = true`. Voorrang in de balk: **som > melding > Nu-chip**. 2) `Ui.keur_regel` ook op de meldingtekst (≤ 8 woorden / ≤ 40 tekens). 3) `ui/wolk.gd`: de wolkzin krijgt een eigen maat `wolk_zin` (= `klein + 3`, dus 17 bij basis 18) in plaats van `klein`; `ZIN_BREED` blijft 228, de wolk wordt dus hooguit één regel hoger. **Alleen die regel en de nieuwe themasleutel aanraken.** 4) Hotspotknoppen in de wereld (`ui/hotknop.gd`) krijgen `knop_wereld = klein + 2`. **Terugval, expliciet:** valt de dekkings- of de 16-knoppentest om, dan blijven de knoplabels op `klein` en gaat alleen de wolkzin omhoog — de keuken zit al rond 15 van de 16 hotspots. 5) Eén echte gebruiker als bewijs: `hotel/rekening.gd` stap 2 krijgt de ontbrekende instructie `Ui.melding("🪙", "Leg de munten op de toonbank")` (6 woorden, 28 tekens).
- **acceptatie** `DH_TEST_FILTER=test_balk` groen met een nieuwe test: een melding staat binnen `Ui.balk_rect()`, wijkt voor een som en komt terug als de som weg is. `=test_hits` groen (grotere wolkjes en knoppen dekken nog steeds 0 % van elk voorwerp op alle kaders en de keuken blijft ≤ 16). `=test_ui` groen. Beeld: `--kamer receptie --band 4 --tik lamp --uit /tmp/b7` (de rekening loopt) — de zin staat onderin in grote letters en de wenswolkjes zijn zichtbaar groter dan op de oude opname.

#### `B9` — Spellen B in de balk: zwembad, wekker, hinkel, was, kraam
- [ ] omvang **M** · model **opus** · hangt af van: `B5`, `N3`, `N5`, `N7`, `N8`, `N11`, `N14`, `K5`
- **stappen** 1) Dezelfde opruiming als `B8` voor deze vijf. Let op `games/hinkel/spel.gd:792` en `games/wekker/spel.gd:662`, die de strook-hotspot rechtstreeks opzoeken: de id `<kaart>_keuzes` verandert niet, dus die code blijft werken — controleer wel dat ze niet op de plaatsing rekenen. 2) `games/zwembad/spel.gd:21 STROOK_ID` en `games/was/spel.gd:_meld_keuzes` nalopen. 3) `kraam` was het spel waarvoor de noodoplossing "dok de strook onderaan" ooit werd gebouwd: controleer dat de prijskaartjes op de spullen nu ongemoeid blijven. 4) Per spel de drie banden en de vier kaders nalopen.
- **acceptatie** `DH_TEST_FILTER=zwembad`, `=wekker`, `=hinkel`, `=was`, `=kraam` alle vijf groen. Beeld per spel op tablet én op `740x360@3:laag-land`: de som staat onderin, de knoppen eronder (vorm `hoog`) of ernaast (vorm `laag`), de prijskaartjes van de kraam zijn niet afgedekt, en de strook staat nooit meer bóven de vraag.

#### `D2` — De aai-knop, de reactie en het rustwolkje 🔎 ⚠️
- [ ] omvang **M** · model **opus** · hangt af van: `D1` · **eerst `git diff autoload/hotel.gd` draaien; beperk je tot de zes genoemde plekken**
- **stappen** 1) Nieuw `hotel/aaien.gd` (`class_name HotelAaien extends RefCounted`, zelfde vorm als `hotel/prikbord.gd`), volledig beschreven in §3.4: constanten `EIGENAAR = "aai"`, `ZEG = "aaizeg"`, `ZEG_ID = "aai_zeg"`, `ZEG_S = 1.8`; functies `knoppen(nu, spel_hier)`, `tik(id)`, `vol()`, `gevuld()`, `_zeg(...)` met generatieteller, `_hartjes(d, n)` via `World.spetter(d.kamer, d.x, d.z, n, ArtEffect.HART_KL, true, 18.0)`, `_volg_dier(id)` (kopie van het patroon in `hotel.gd:1397`). **Voeg `if not Hotel.scherm_klaar(): return` óók toe aan `gevuld()`**, niet alleen aan `_zeg()` en `_puf()` — `State.tel()` wordt midden in de antwoordafhandeling van elk spel aangeroepen, vaak binnen een `await`, en ook vanuit tests zonder shell. 2) `art/effect.gd`: `const HART_KL := Color("#F5B0C2")`. 3) `autoload/hits.gd:435-442` `_laag_van`: `if s.klas.contains("hotwens") or s.klas.contains("hotaai"): return Laag.WENS`. 4) In `autoload/hotel.gd` **precies zes plekken**: `var _aaien: HotelAaien = null` bij `_prikbord` (`:79`); `_aaien = HotelAaien.new()` + `State.aai_gevuld.connect(...)` in `_ready()` (`:85`); het `spel_hier`-blok uit `_wens_wolken()` (`:1313-1324`) verhuizen naar een nieuwe publieke `func spel_in_kamer(nu) -> bool` en `_wens_wolken(nu, spel_hier)` de bool meegeven — **raak de wenslus eronder (`:1344-1348`) niet aan, daar zit het werk van de tweede agent**; aan het slot van `hotspots()` (`:1307`) `var sh := spel_in_kamer(nu)` + `_wens_wolken(nu, sh)` + `_aaien.knoppen(nu, sh)`; `_aaien.vol()` in `taak_af()` (`:963`); `State.aai_vol()` in `morgen()` (na de gastenlus, ±`:528`); publieke `func aai(id) -> void: _aaien.tik(id)` voor de tests.
- **acceptatie** `DH_TEST_FILTER=test_aaien`, `=test_hits` en `=test_tekens` groen. Nieuwe tests: met twee stille gasten bestaat `Hits.spot("aai_boef")` na `Hotel.render()`; na `World.slaap(...)` of tijdens een lopend nepspel in die kamer bestaat hij **niet**; `Hotel.aai("boef")` drie keer verlaagt `State.aai_van` naar 0 en de knop toont daarna `💤 Rust`; een vierde tik verlaagt niets en laat `aai_zeg` bestaan; elke kindzin ≤ 8 woorden én ≤ 40 tekens, `Ui.mist_tekens(zin) == []` en staat woordelijk in `hotel/aaien.gd`; en in `tests/test_hits.gd` een test dat bij een overvol kamerbudget een spot met `klas: "hotaai"` prio 5 **eerder** onzichtbaar wordt dan een spot met `klas: "hotwens"` prio 6. Beeld: `--kamer kamer1 --band 4 --uit /tmp/d2a` (log bevat `knop aai_boef=`, de PNG toont 🐾 Aaien onder elk dier en het dier blijft volledig zichtbaar) en `--tik aai_boef --wacht 300 --uit /tmp/d2b` (Boef in kwispelpose met roze deeltjes). **Noteer expliciet:** in de tuin met 7 gasten sneuvelt de aai-knop door de cull — bewust, de goede kant om te falen.

#### `M2` — Polonaise: het spel
- [ ] omvang **M** · model **opus** · hangt af van: `M1`, `B5`
- **stappen** 1) `games/polonaise/spel.gd` + `spel.tscn` volgens §3.7.1; de map wordt vanaf nu automatisch als spel gescand (`games.gd:41-59`) — **nul gedeelde bestanden**. `definitie()` exact zoals in §3.7.1. 2) Bij `start()` vertrekken de eerste drie gasten met `ctx.wereld.reis(id, "gang")` en verschijnt de kaart in **dezelfde tekenbeurt**, met bleke chips op hun plek in de rij (R1). 3) Kaart 1 (patroon) met vier `keuzes` mét pictogram én woord; hulpladder: `💛 Kijk: hond, poes, hond …` + de rij licht om en om op, daarna een bleek spookdier op het lege plekje. Nooit een kruis. 4) Kaart 2 (tellen) met `goed` — **verplicht vóór de dans**; fout → `Econ.tel_mee`-regel en de rij telt zichzelf mee. 5) Het spelmoment: één knop `🔔 Tik mee` met badge, pulsend via `await na(0.5)` (nooit een rauwe `SceneTreeTimer`, en na élke `await` `if not actief: return`). Elke tik laat de hele rij één plek vooruit hoppen — één `ctx.wereld.stappen`-order per dier met pose `spring`, tempo 1,25 en `Snd.hup()` per landing, **met de hinkel-bewaking `mijn != _hop_nr`** (`games/hinkel/spel.gd:834-887`), anders vallen de meetel-chips weg bij drie gelijktijdige orders. Op de maat ✨ boven de rij; naast de maat hoppen ze gewoon zonder sparkel. Acht tikken, ±6 s. In rustmodus lost de hop in hetzelfde frame op. 6) Afhaken: de rij loopt één rondje en elk dier reist naar zijn eigen kamer. 7) Slot: eindkaart, `ctx.state.tel(missers == 0, ms)`, `ctx.taak_klaar("polonaise")`, sluiten na 3 s. 8) Stand `{patroon, rij, stap, tel, missers}` na élke stap in `ctx.data()`. 9) Knoppenbudget: het spel houdt zelf drie hotspots en zet de vier deurknoppen tijdens de dans stil met `ctx.hotspots.pak/laat`.
- **acceptatie** `DH_TEST_FILTER=polonaise tools/test.sh` groen met: kaart 1 staat er binnen de eerste tekenbeurt en er is dan **geen** dansknop; de dansknop bestaat pas na twee goede antwoorden; een misser straft niet en laat dezelfde keuzes staan; elke kindzin staat woordelijk in de bron, past in `Ui.keur_regel` en `Ui.mist_tekens` is leeg; dekking 0 % op vier kaders en ≤ 16 hotspots in de gang; een herlaad midden in de dans zet de stand terug; `stop()` laat de wereld schoon achter. `=test_games` groen (de scan vindt het elfde spel). Beeld: `--kamer gang --band 3 --tik spel_polonaise --uit /tmp/m2a` (de kaart, drie dieren onderweg) en `--wacht 6000 --uit /tmp/m2b` (de rij compleet, de tikknop met badge).

#### `K6` — Sleutels: lampjes aandoen in de gang als slotbeat *(optioneel)*
- [ ] omvang **S** · model **opus** · hangt af van: `K2`
- **stappen** Puur speelmoment ná al het rekenen; mag als eerste vervallen. In `_klaar()`, als de camera in de gang staat: maak van elk 💡-plaatje boven een deur een tikbare hotspot (kind `btn`, prio 6) die bij de eerste tik het licht aandoet — `Snd.plop()`, het plaatje krijgt een lichtere achtergrond (stylebox met `UiThema.ZON`, zelfde patroon als `_kleur_haak`) en er valt een wolkje `💡 licht aan` (3 woorden). Zijn alle deuren aan, dan sluit het spel meteen; is er niets aangetikt, dan sluit het na `WACHT_EIND` zoals nu. Houd de gang onder 16 hotspots (er staan al vier deuren + de klok).
- **acceptatie** `DH_TEST_FILTER=sleutels tools/test.sh` groen; nieuwe test dat de lampjeshotspots alleen in de gang en alleen ná afloop bestaan en dat `stop()` ze opruimt (`test_stop_laat_de_wereld_schoon_achter` blijft groen). Beeld: de gang na afloop met de lampjes aan.

#### `R6` — Dagdressing: los decor dat elke dag anders is
- [ ] omvang **M** · model **opus** · hangt af van: `R3`
- **stappen** 1) Nieuw `hotel/sier.gd` (`class_name HotelSier`) met `ZAAD := 61803`, `SEIZOEN_DAGEN := 7`, `VOOR := "sier_"`, `static func seizoen(dag) -> int`, `const PLEKKEN`, `const THEMA`, `static func zet(dag, feest)` en `static func ververs()`. Werking: eerst elke losse id met het voorvoegsel weghalen (`World.decor_lijst()` + `World.decor_weg`), dan **één** `Sommen.Prng.new(ZAAD ^ dag * 2654435761)`, dan de kamers in `Rooms.lijst()`-volgorde en per kamer de plekken in tabelvolgorde; per plek `prng.volgende() > kans` → niets, anders een model uit `THEMA[thema]`. Altijd `"door": "hotel"`. 2) **Haakpunt: `World.zet_dag(dag)`** (`world.gd:748-752`), niet `Hotel.morgen()` — `zet_dag` wordt al door `morgen()` aangeroepen, dus `autoload/hotel.gd` blijft ongemoeid (§3.9). Wis eerst het decor van gisteren, blijf ruim onder `LOS_MAX` (48 per kamer). 3) Vul `PLEKKEN` met de tabel uit §3.5 (nog zonder seizoenen: thema's `bloem`, `wand`, `was`, `blad`, `fruit`). 4) Nieuwe modellen alleen waar ze nog niet bestaan, in `art/decor_hotel.gd`: `vaas`, `waslijn` (met `params.n` 0..4 — het aantal stuks aan de lijn is de telbare variatie), `fruitschaal`, `bladerhoop`. Alle overige thema-opties hergebruiken bestaande modellen. 5) Nieuw `tests/test_sier.gd`.
- **acceptatie** `DH_TEST_FILTER=test_sier tools/test.sh` 0 fout met: (a) determinisme — `zet(5, false)` twee keer geeft exact dezelfde `World.decor_lijst()`; (b) dag 5 ≠ dag 6; (c) elke sierplek ligt ≥ 14 manhattan van elke dwaalplek en elke deurstap van zijn kamer en ≥ 12 van elk vast decorstuk; (d) elk model in `THEMA` bestaat in `Art`; (e) ná `Games.start("bedden")` staat het sierdecor er nog (bewijs dat `door: "hotel"` een spel overleeft — `games.gd:105-110` wist alleen andere spel-eigenaars); (f) `Rooms.get_kamer(id).plekken` verandert **niet** door `zet()` (bewijs dat los decor de loopvakjes niet raakt); (g) `seizoen(1) == 0`, `seizoen(8) == 1`, `seizoen(29) == 0`. `=test_rooms`, `=test_world`, `=test_hotel` 0 fout. Beeld: `--kamer receptie --dag 1|4|9` — drie zichtbaar verschillende foto's; `--kamer wasserij --dag 3` toont een waslijn met een telbaar aantal stuks.

---

### Batch 8 — Check-in in de balk, seizoenen, en het tweede nieuwe spel

**Bestandssets** — `B10`: `autoload/hotel.gd`, `hotel/rekening.gd`, `autoload/ui.gd`, `tests/test_hotel.gd` · `M3`: `games/spiegel/beurt.gd`, `games/spiegel/modellen.gd`, `games/spiegel/test_spiegel.gd` *(alle nieuw)* · `R7`: `hotel/sier.gd`, `art/decor_hotel.gd`, `art/decor_kas.gd`, `tests/test_sier.gd` · `D3`: `art/effect.gd`, `autoload/world.gd`, `wereld/voor.gd`, `hotel/aaien.gd`, `tests/test_art.gd`, `tests/test_world.gd` · `S3`: `tests/test_regels.gd` *(nieuw)*. *Geen overlap.*

#### `B10` — Check-in en rekening in de balk, met één zin per stap ⚠️
- [ ] omvang **M** · model **opus** · hangt af van: `B5`, `B7` · **eerst `git diff autoload/hotel.gd tests/test_hotel.gd` draaien**
- **stappen** 1) `Hotel.paint_checkin` (`:633-699`): stap 1 en 2 gebruiken nu twee zinnen (`regel` én `regel2`) — terug naar één zin per stap zoals HOTEL.md §9 wil, bijvoorbeeld stap 1 `🥄 Boef eet 2 scheppen erbij. Samen?` (36 tekens) en stap 2 `📦 Is 40 genoeg voor 4 dagen?` (27 tekens). De weggevallen voorraadzin wordt een `Ui.getal_tag` op de zak — een getal óp een voorwerp, niet een tweede regel. 2) De vraagtitel boven een keuzestrook (`keuze_titel`, nu alleen `tooltip_text`, `ui.gd:422` → `keuzestrook.gd:18`) wordt in de balk een **zichtbaar** grijs kopje boven de knoppen; op een tablet was hij tot nu toe onzichtbaar. 3) `Ui._getal_keuzes` neemt nu het icoon van de kaart over, wat bij de rekening 🛏 op euroknoppen oplevert; geef de getalknoppen een eigen sleutel `keuze_icoon`, met 🪙 / 💶 voor geld. 4) `hotel/rekening.gd:227 _som_stap` en `:292 _wissel_kaart`: de werkplek-berekening voor de kaart vervalt (de balk beslist); het `obj`-argument blijft de balie, zodat de wijzer naar de toonbank wijst. Dat repareert meteen dat som en antwoordknoppen aan tegenovergestelde kanten van het kader stonden.
- **acceptatie** `DH_TEST_FILTER=test_hotel tools/test.sh` groen, inclusief `test_check_in_twee_vragen_en_een_bed` en `test_avondronde_en_afrekenen`, met een nieuwe assertie dat **geen enkele check-instap nog een `regel2` zet**. `=test_ui` groen. Beeld: `--kamer receptie --band 4 --tik bel` (check-in stap 1 en 2) en `--tik lamp` (rekening stap 1, 2, 3) op tablet én telefoon: één zin per kaart, de knoppen dragen 🪙 in plaats van 🛏, en de vier antwoordknoppen staan direct onder de som in de balk.

#### `M3` — Spiegelmaskers: de generator en de twee modellen
- [ ] omvang **M** · model **opus** · hangt af van: `R2`
- **stappen** 1) `games/spiegel/beurt.gd` (`class_name SpiegelBeurt`, statisch en wereldvrij): eigen `Sommen.Prng`, gezaaid op `hash("spiegel") ^ dag * 2654435761`. Levert per band het raster (R × K), de al beplakte linkerhelft, het goede antwoord en de sombalk — band 3 `5 − 2 =`, band 4 `7 + 7 =`, band 5 `6 × 4 =` met twee assen. **De bevroren kern wordt alleen gelezen.** 2) `games/spiegel/modellen.gd`: `spiegel_masker` (de plaat met het raster, de gevulde vakjes als `params`) en `spiegel_klap` (de scharnierende spiegel op de vouwlijn), aangemeld met `Art.registreer_model` — **de naam MOET met `spiegel_` beginnen** (`art.gd:170-185`; een botsing met een wereldmodel wordt hard geweigerd, een ontbrekend voorvoegsel is een waarschuwing). 3) `games/spiegel/test_spiegel.gd`. **Nog geen `spel.tscn`**, dus de map telt nog niet als spel.
- **acceptatie** `DH_TEST_FILTER=spiegel tools/test.sh` groen: hetzelfde zaad geeft hetzelfde raster; het aantal ontbrekende stippen is altijd gelijk aan het goede antwoord (dat is de hele onontkoombaarheid); de sombalk per band klopt met de notatieregels (band 3 geen deelteken, band 4 verdubbelen, band 5 binnen `TAFEL_SET[5]`); beide modellen bakken op g = 2, 3 en 4 en hun namen zijn uniek over alle themabestanden. `=test_art` en `=test_games` blijven groen.

#### `R7` — Seizoen en feestdag: bloesem, bladeren, sneeuw en een taart
- [ ] omvang **M** · model **opus** · hangt af van: `R6`, `R3`
- **stappen** 1) Maak `THEMA` echt per seizoen: `THEMA[thema][seizoen] -> Array` met vier kolommen. Lente = bloesem/kiemplantjes, zomer = bloemen/ligstoel/picknickkleed, herfst = bladerhoop/pompoen, winter = dennentak/sneeuwplek/krans. 2) Voeg de kas-regels toe: vier sierplekken, één per moesbak, die de `params` van het losse model `moesinhoud` (uit `R3`) zetten met `groei = seizoen` (lente 1, zomer 3, herfst 2, winter 0). **Teken de bak niet dubbel** — de losse plek levert alleen de inhoud. 3) `feest()` = `not (State.s["uitcheck"] as Array).is_empty()`. Is dat waar: een slinger en een taart in de receptie en een extra wimpel, plus één wolkje bij binnenkomst `🎉 Feest voor %s!` (3 woorden, max 18 tekens bij de langste gastnaam). *(🎂 zit niet in de fontsubset, 🎉 wél — R10.)* 4) Nieuwe modellen in `art/decor_hotel.gd`: `bloesemhoop`, `sneeuwplek`, `dennentak`, `krans`, `pompoen`, `ligstoel`, `picknickkleed`, `taart`, `slinger`. 5) Zet de feestzin door `Ui.keur_regel` en controleer hem voor **elke** naam uit `State.POOL`.
- **acceptatie** `DH_TEST_FILTER=test_sier tools/test.sh` 0 fout, uitgebreid met: elk seizoen zet iets anders neer in de tuin; op een feestdag staat er een taart en zonder uitcheck niet; de feestzin voldoet aan HOTEL.md §9 voor elke gastnaam. `=test_ui` 0 fout (elk gebruikt pictogram zit in het lettertype). Beeld: vier foto's van de tuin op dag 1, 8, 15 en 22 — zichtbaar verschillend; en de kas op dag 1 versus dag 15 — moesbakken leeg respectievelijk vol.

#### `D3` — Hartjes in plaats van blokjes *(optioneel)*
- [ ] omvang **S** · model **opus** · hangt af van: `D2`
- **stappen** 1) `ArtEffect.pluis(n, x, y, kl, omhoog, rnd)` krijgt een laatste optionele parameter `soort := ""` en zet `q["v"] = soort` **alleen als die niet leeg is** — geen enkele bestaande aanroeper verandert. 2) Nieuwe `const HART` (een 5 × 5 pixelhart als rechthoeklijst) en `static func hart_rechthoeken(m) -> Array[Rect2i]` in de stijl van `zzz_rechthoeken` (`art/effect.gd:75-86`), met `e := maxi(1, JsGetal.rond(m / 5.0))` en het hart gecentreerd op de deeltjespositie. 3) `World.spetter(...)` krijgt er `soort := ""` achteraan bij en geeft die door (`world.gd:1740-1748`). 4) In de deeltjeslus van `wereld/voor.gd` (`:19-24`): is `p.get("v", "") == "hart"`, teken dan de rechthoeken van `hart_rechthoeken(m)` in plaats van één `draw_rect` (zes rechthoekjes per deeltje, bij drie hartjes 18 — verwaarloosbaar). 5) `hotel/aaien.gd:_hartjes()` geeft `"hart"` mee. Zet de tests in `tests/test_art.gd` en `tests/test_world.gd`.
- **acceptatie** `DH_TEST_FILTER=test_art` en `=test_world` groen met: `hart_rechthoeken(m)` geeft voor `m` bij g = 2, 3 en 4 zes rechthoeken binnen een vierkant van 5·e en is deterministisch; `World.spetter(..., "hart")` levert deeltjes met `v == "hart"`; **dezelfde aanroep zónder soort levert deeltjes zónder `v`-sleutel** (elk bestaand deeltje blijft ongewijzigd); en met `Ui.zet_rust_modus(true)` nul deeltjes. Beeld: `--kamer kamer1 --tik aai_boef --wacht 250 --uit /tmp/d3` — drie herkenbare roze hartjes in plaats van vierkantjes.

#### `S3` — De regeltest: elk spel begint met een som en is niet te omzeilen 🔎
- [ ] omvang **S** · model **opus** · hangt af van: `B9`, `M2`
- **stappen** Nieuw `tests/test_regels.gd` (`extends Proef`) — de blijvende bewaking die in geen enkel ontwerp zat. Loop over `Games.lijst()` (de registratie is een mapscan, dus elk nieuw spel doet automatisch mee) en sla `stub`-spellen over. Per spel, per band 3/4/5: 1) **R1** — start het spel en eis dat er binnen de eerste tekenbeurt een kaart bestaat mét een antwoordstrook (`Hits.spot("<id>_keuzes")` met ≥ 2 knoppen onder `Rij`). 2) **R3** — eis dat `State.s["sterren"]` en het taakkaartje onveranderd zijn zolang er geen enkel goed antwoord is gegeven: tik elke niet-antwoord-hotspot van het spel één keer aan en controleer dat er geen ster valt. 3) **R5** — elke zichtbare kindzin van elk spel voldoet aan `Ui.keur_regel` en `Ui.mist_tekens(zin) == []`. Documenteer in de testkop welke spellen om welke reden een uitzondering hebben (en houd die lijst leeg als het kan).
- **acceptatie** `DH_TEST_FILTER=test_regels tools/test.sh` groen voor **elk** spel op elke band, zonder uitzonderingslijst. Draai daarna één keer volledig `tools/test.sh`.

---

### Batch 9 — Slot: de lus af, de galerij, de specs

**Bestandssets** — `L2`: `autoload/hotel.gd`, `autoload/world.gd`, `tests/test_hotel.gd`, `tests/test_world.gd` · `R8`: `hotel/sier.gd`, `games/meubels/spel.gd`, `games/meubels/test_meubels.gd`, `art/decor_hotel.gd`, `tests/test_sier.gd` · `M4`: `games/spiegel/spel.gd`, `games/spiegel/spel.tscn`, `games/spiegel/test_spiegel.gd` · `M5`: `games/sprint/*` *(nieuw)* · `S4`: `.fanout/specs/godot/*.md`, `HOTEL.md`, `AGENTS.md`. *Geen overlap.*

#### `L2` — De hotel-lus af: badges, wensen, en de dieren komen naar de nieuwe kamers 🔎 ⚠️
- [ ] omvang **M** · model **opus** · hangt af van: `L1`, `R3` · **eerst `git diff autoload/hotel.gd` draaien**
- **stappen** 1) **Deurbadges wijzen naar het werk.** `hotspots()` (`:1226-1235`) zet vandaag `wacht_in(<directe buur>)` als badge, en `wacht_in()` (`:351-362`) telt alleen gasten wier eigen wensplek ín die kamer ligt — de gang is nooit iemands wensplek, dus de deur vanuit de receptie is altijd kaal, en de keuken, wáár het probleem juist opgelost wordt, telt nul. Maak de badge "hoeveel open stappen liggen er achter deze deur", gerekend over `Rooms.pad(van, naar)` in plaats van over de directe buur. 2) **Meer wensvariatie.** `nieuwe_wensen()` (`:443-476`) geeft op even dagen niets terug en deelt op oneven dagen hoogstens één wens uit; het bad gaat hard naar index 0 (`:519`) terwijl het commentaar bij `bad_gast()` (`:427-429`) een rotatie belooft; "souvenir" verschijnt pas op dag 9 en "spelen" komt in `morgen()` helemaal niet voor. Deel ook op even dagen uit, laat het bad echt roteren en haal "souvenir" en "spelen" naar voren. 3) **De dieren komen naar de nieuwe kamers.** `plek_van_behoefte` laat `spelen` naar de Speelzaal wijzen (de kussenhoek), en `World._kies` mag bij het dwalen één deur verder kijken. Zonder dit zijn twee nieuwe kamers twee lege kamers. 4) **De slaapbug.** `herstel_wereld()` (`:116-122`) legt na een herlaad elke gast met een bed slapend neer, midden op de dag, en hij wordt nooit meer wakker; bovendien wordt de opgeslagen standplaats `waar` weggegooid en krijgt de gast coördinaten uit een ándere kamer. Herstel `waar` en leg alleen te slapen wie 's avonds sliep.
- **acceptatie** `DH_TEST_FILTER=test_hotel` en `=test_world` groen plus: `test_de_deur_naar_de_gang_draagt_een_badge` (met twee hongerige dieren in kamer2 draagt de deur in kamer1 badge 2); `test_de_wensen_zijn_verdeeld` (over 14 dagen met 4 gasten komt geen enkele wenssoort boven 50 % — vandaag 42 van 56 "eten"); `test_een_dier_loopt_naar_de_speelzaal`; `test_na_een_herlaad_slaapt_niemand_overdag`. Beeld: `--kamer receptie --band 4 --uit /tmp/l2a` (de deur naar de gang draagt een getal) en `--kamer speelzaal --band 5 --uit /tmp/l2b` (er staat een dier in).

#### `R8` — De gekochte versiering komt écht in de kamer te staan
- [ ] omvang **M** · model **opus** · hangt af van: `R6`, `N12`
- **stappen** 1) `hotel/sier.gd` krijgt een tweede tabel `VERSIERPLEK: sleutel -> [{kamer, x, z, y, ver}]` met vijf sleutels (`vlag`, `bloem`, `kussen`, `slinger`, `ster`), elk minstens zes plekken in een vaste, betekenisvolle volgorde (vlaggetjes eerst in de gang, dan receptie, dan speelzaal …). Nieuwe `zet_versiering()` leest de tellers uit `State.spel_data("meubels").get("versiering", {})` en vult voor teller `n` de eerste `n` plekken met los decor `door: "hotel"`, id `sier_v_<sleutel>_<i>`. Roep hem aan vanuit `zet()`. **Geen nieuwe opslagsleutel, geen migratie.** 2) Modellen in `art/decor_hotel.gd` waar ze nog niet bestaan: `vlaggetjes`, `kleurkussen`, `ballonslinger`, `sterstickers`; `bloem` hergebruikt `ArtDecor.bloemen`. 3) `games/meubels/spel.gd:_koop_versiering()` (`:590`): na `State.bewaar()` één regel `HotelSier.ververs()`, en het bestaande wolkje `mb_af` krijgt de kamernaam erbij — `"%s %s in de %s!"`. Controleer die zin voor **alle vijf** de versieringen tegen `Ui.keur_regel` (langste: `🎈 Ballonslinger in de feestzaal!` 4 woorden / 32 tekens; zonder feestzaal wordt dat `… in de speelzaal!`).
- **acceptatie** `DH_TEST_FILTER=meubels tools/test.sh` 0 fout (was 20 goed), met de letterlijke-tekstentest uitgebreid en een nieuwe test dat `_koop_versiering("vlag")` echt een los decorstuk toevoegt en een tweede aankoop een **tweede** plek vult. `=test_sier` 0 fout: teller 0 = niets, teller 3 = precies drie stukken op de eerste drie plekken, teller boven het aantal plekken = geen fout en geen dubbele id. Beeld: koop vlaggetjes in het meubelboek en fotografeer de gang — de vlaggetjes hangen er zichtbaar.

#### `M4` — Spiegelmaskers: het spel 🔎
- [ ] omvang **M/L** · model **opus** · hangt af van: `M3`, `B5`, `R2`
- **stappen** 1) `games/spiegel/spel.gd` + `spel.tscn` volgens §3.7.2. `definitie()`: naam "Spiegelmaskers", kamer `speelzaal`, hotspot op `muziekdoos` met icoon 🧸, `unlock: n >= 2`, taak `{id: "masker", icoon: "🧸", tekst: "Maak een masker", kamer: "speelzaal", prio: 5}`. **Gebruik 🧸 en 🩷 — 🎭 en 🪞 zitten niet in de fontsubset** (R10). 2) `start()` legt de maskerplaat met de linkerhelft al beplakt en de spiegel op de vouwlijn neer, en zet in **dezelfde tekenbeurt** de somkaart; er is dan **geen stickerbak en geen aantikbaar vakje** (R1 + R3). 3) Hulpladder: misser 1 `💛 kijk naar de vouwlijn` + de spiegel glimt op; misser 2 één bleek spookstipje op het vakje dat gespiegeld hoort. Nooit een kruis. 4) Goed → de stickerbak verschijnt met **de teller op het gegeven getal** (`ctx.hotspots.bron` met `aantal`) plus `🩷 Plak de stippen rechts` (4/22). Tik de bak = sticker in de hand, tik een vakje rechts: goed → `Snd.plop()` en de teller zakt; fout → het stipje glijdt rustig terug met `Snd.terug()` en `🙃 Nog niet in de spiegel` (5/22), niets afgenomen, meteen opnieuw. 5) **De vakjes zijn géén aparte knoppen** maar één vangvlak over de rechterhelft met een raster eronder, zodat het spel op vijf hotspots blijft. 6) Band 5: na de verticale as draait de tafel een kwartslag en komt de horizontale as erbij; vier kwadranten, en de sombalk van het begin blijkt te kloppen — uitleggen door voordoen. 7) ✓ → de spiegel klapt dicht (`Snd.tover()`), het masker zweeft van de tafel, het dier maakt een pirouette (`World.pose(id, "zwaai", 20)`) en er dwarrelen sterretjes; daarna hangt het masker als los decor met `"door": "hotel"` aan de wand — over de dagen groeit er een galerij. 8) `ctx.state.tel(misser == 0, ms)`, `ctx.taak_klaar("masker")`, sluiten na 3,5 s. 9) To-do-regel: één "!"-merkje tegelijk — kaart, dan de stickerbak, dan de ✓. 10) Stand na élke stap in `ctx.data()`.
- **acceptatie** `DH_TEST_FILTER=spiegel tools/test.sh` groen met: de kaart staat er in de eerste tekenbeurt en de stickerbak bestaat dan niet; **de teller van de bak is gelijk aan het gegeven antwoord**; een fout vakje verandert de teller niet en straft niet; twee assen op band 5; dekking 0 % op vier kaders en ≤ 16 hotspots in de speelzaal; elke kindzin woordelijk in de bron, binnen `Ui.keur_regel` en met lege `Ui.mist_tekens`; het masker overleeft `Games.stop()`; `stop()` laat de wereld verder schoon. `=test_games`, `=test_regels`, `=test_art` groen. Beeld: `--kamer speelzaal --band 4 --tik spel_spiegel --uit /tmp/m4a` (de kaart, de halve plaat, geen bak) en na het antwoord `--uit /tmp/m4b` (de bak met de teller), plus de wand met twee maskers na twee dagen.

#### `M5` — Bellensprint: de zwemles met stroken *(optioneel — eigenaar beslist na `N14`)*
- [ ] omvang **L** · model **opus** · hangt af van: `N14`, `B9`
- **stappen** Alleen bouwen als de eigenaar open vraag **V7** met "ja" beantwoordt. Nieuw `games/sprint/` (`beurt.gd` op `Sommen.Lcg31` met eigen test, `spel.gd`, `spel.tscn`, `test_sprint.gd`) volgens §3.7.3 — nul gedeelde bestanden. Ingang op het dek aan de **overkant** (het vaste decorstuk `plant`, `rooms.gd:650`), zodat de zwemles op het startblok blijft. Het openingsantwoord bepaalt het speelveld: pas ná het goede antwoord zakken `k` drijflijnen in het water op `ZwembadBeurt.baan_x(bad, L, i·m)`. **Elke drijflijn heeft zijn eigen tussensom** (`🫧 Hoeveel meter heeft hij nu?` 5/27); zonder die som gaat de sprint niet verder. Hergebruik de tikversnelling uit `N14`. **Band 3 vermijdt het deelteken**: `🫧 Hoeveel stroken van 2 meter?` met sombalk `2 + 2 + 2 =` (herhaald optellen), niet `8 : 2 =` — de bevroren kern legt zelf vast dat groep 3 het deelteken nog niet kent.
- **acceptatie** `DH_TEST_FILTER=sprint tools/test.sh` groen: de generator is deterministisch; band 3 kent geen deelteken; de drijflijnen bestaan niet vóór het goede antwoord; een strook gaat niet open zonder tussensom; `=test_regels` groen; dekking 0 % op vier kaders en het zwembad blijft ≤ 16 hotspots met de zwemles-ingang erbij. Beeld: `--kamer zwembad --band 4 --tik spel_sprint` vóór en ná het eerste antwoord.

#### `S4` — De specs bijtrekken
- [ ] omvang **S** · model **opus** · hangt af van: alle voorgaande taken
- **stappen** Vier specs worden door dit plan tegengesproken; trek ze aan het eind in één commit bij (R9). 1) `.fanout/specs/godot/games-a.md §7.7` (voerkar-teksten) — de twintig geschrapte zinnen weg, de acht nieuwe erin (`V3` deed dit al deels; controleer). 2) `games-a.md §3.5` — de kamerdeur is niet langer de controleknop van `bedden` (`N9`). 3) `architecture.md §1.1 F5` — een bots in het zwembad is niet langer het einde van de beurt (`N3`). 4) `world.md §5.5`/§6 — het anker `"balk"`, `Ui.balk_rect()` en de hysterese beschrijven; `architecture.md §10` — de sleepdoorschakeling via `Hits.vang_onder` (`S1`). 5) `HOTEL.md` §1-tabel: de twee nieuwe kamers; §5-catalogus: de drie nieuwe minigames afvinken. 6) `AGENTS.md` §6: de tabel van "de tien games" wordt dertien (of twaalf zonder `M5`); §2 en §9: de nieuwe bestanden (`ui/rekenbalk.gd`, `hotel/aaien.gd`, `hotel/sier.gd`, `tests/test_balk.gd`, `tests/test_aaien.gd`, `tests/test_sier.gd`, `tests/test_regels.gd`, `tests/test_kamerbalk.gd`) en de nieuwe suitecijfers.
- **acceptatie** Eén keer volledig `tools/test.sh` groen, `tools/import.sh` groen, `tools/export.sh` groen, en `grep` bevestigt dat geen specparagraaf nog een geschrapte kindzin of een vervallen regel bevat.

---

## 5. Werkwijze

### 5.1 Hoe een agent één taak doet

1. **Eigen worktree.** `git worktree add /tmp/dh-<taak> -b taak/<taak> main`. Nooit
   twee taken in dezelfde werkboom: ze delen de `.godot/`-cache.
2. **Lees eerst.** De taak in §4, het bijbehorende stukje §3, het `spel.gd` en het
   `test_<id>.gd` van het spel dat je raakt, en de matchende specparagraaf
   (`games-a.md` voor bedden/sleutels/meubels/tobbe/voerkar, `games-b.md` voor
   zwembad/wekker/hinkel/was/kraam, `world.md` voor de wereld, `architecture.md`
   voor het spelcontract). Raakt je taak een bestand van de tweede agent (⚠️),
   draai dan **eerst** `git diff <bestand>`.
3. **Import.** `tools/import.sh` (±20 s) voordat je begint als je nieuwe bestanden
   toevoegt (`.gd` krijgt een `.uid`; die **moet** mee in de patch).
4. **Bouw.** Blijf binnen de bestandenlijst van je taak. Kom je erbuiten, stop en
   meld het — dan klopt de batchindeling niet meer.
5. **Test gefilterd.** `DH_TEST_FILTER=<deel van het pad> tools/test.sh`.
   **Let op:** de filter is een substring van het **pad** (`res://games/<id>/test_<id>.gd`
   of `res://tests/test_x.gd`), niet van de bestandsnaam — `DH_TEST_FILTER=games`
   draait álle spellen. En `tools/test.sh <arg>` werkt **niet**: de binnenste
   `tools/test.sh` laat `"$@"` vallen, alleen de omgevingsvariabele selecteert.
   Elke engine-ERROR is een fout; `verwacht_fout(n)` is exact, geen maximum.
6. **Draai de volle suite** voordat je klaar meldt: `tools/test.sh` (±153 s, nu 405
   goed / 0 fout). Een taak die alleen gefilterd groen is, is niet af.
7. **Beeld.** `tools/export.sh` (±60 s) en dan
   `node tools/kiek.js --kamer <kamer> --band 4 --tik <hotspot> --uit /tmp/<taak>`.
   Flags: `--kamer --tik --chip --wacht --band --gasten --dag --uit --viewport --url`.
   **Nooit exporteren terwijl de suite draait** (gedeelde cache). Draai `kiek` op
   minstens twee kaders als de taak iets zichtbaars doet: tablet (`1024x768@2:ipad`,
   standaard) en telefoon (`--viewport 360x740@3:telefoon`); bij plaatsingswerk ook
   `--viewport 740x360@3:laag-land`.
8. **Rapporteer.** Wat je deed, wat groen is (met de cijfers vóór en ná), welke
   schermafdrukken je maakte en waar ze staan, wat je *niet* deed, en elke aanname
   die je moest maken. **Commit niets** — de lead merget per patch.

### 5.2 Hoe de lead merget

- Neem de patch met `git diff main...taak/<taak> -- <exact de bestandenlijst>` en
  pas hem toe op `main`. Staat er een bestand in dat niet in de takenlijst stond,
  dan is dat een gesprek, geen merge.
- Draai daarna één keer volledig `tools/test.sh` op `main` vóór de volgende batch.
- **Commit per pad**, met de bestandenlijst uit de taak: dan blijft het werk van de
  tweede agent in de werkboom ongemoeid.
- Bij een 🔎-taak: stuur de opdracht **verbatim** plus de diff naar een verse agent
  die de redenering van de uitvoerder niet krijgt, en laat die de acceptatie zelf
  reproduceren.
- De review-/mergestap is de enige plek waar het model `fable` voorkomt; elke taak
  zelf is `opus`.

### 5.3 De regels waar elke taak zich aan houdt

- `core/sommen.gd` blijft byte-identiek (R8). Nieuwe sommen krijgen een eigen
  generator in `games/<id>/beurt.gd` met een eigen test.
- Nieuw voxelmodel: `Art.registreer_model("<spelid>_naam", fn)` — een botsing met een
  wereldmodel wordt hard geweigerd (`art.gd:174-176`), een ontbrekend voorvoegsel
  geeft een waarschuwing. Nieuw **decor**model hoort in een themabestand via
  `ArtDecor._extra()`, **niet** in `ArtDecor.NAMEN` (`tests/test_art.gd:267` eist
  `NAMEN.size() + POL_AANTAL == 34`), en moet uniek zijn over álle themabestanden.
- Na elke `await`: `if not actief: return`. Vertragingen via `await na(s)`, nooit een
  rauwe `SceneTreeTimer`. De stand na elke stap in `ctx.data()`.
- Elke kindzin door `Ui.keur_regel` (≤ 8 woorden én ≤ 40 tekens) en `Ui.mist_tekens`
  (R10). Verandert een zin, werk hem dan **woordelijk** bij in de speltest in
  dezelfde commit — twaalf van de vijftien sleutels-tests en zeven wekker-tests
  keuren de tekst letterlijk uit de bron.
- Wijkt een taak van een spec af, dan **wijzigt hij die specparagraaf en de test in
  dezelfde commit** en zegt het in de commitboodschap (R9).

### 5.4 De tweede agent

`autoload/hotel.gd`, `ui/wolk.gd`, `tests/test_hotel.gd` en `tests/test_ui.gd`
hebben ongecommitte wijzigingen (+59/−2: `WENSSPEL`, `wens_spel()`, `tik_wens()`,
de klas `"hotwens hint"` op het wenswolkje en de gele `UiThema.ZON`-kleur). Alle
taken die die bestanden raken staan in batch 5 of later en dragen ⚠️. Volgorde voor
`hotel.gd`: `L1` → `B6` → `D2` → `B10` → `L2`. Begin zo'n taak altijd met
`git diff <bestand>` en beperk je tot de genoemde plekken.

### 5.5 Pauzeren en hervatten

Elke taak is los committeerbaar en heeft een eigen aankruisvakje. Je kunt **na elke
taak** stoppen. Om te hervatten: kijk in §7 welke vakjes aan staan, pak de eerste
batch waarvan nog niet alles aan staat, en draai die taken parallel. De enige harde
regels: een taak wacht op zijn `hangt af van`, en binnen een batch mogen twee taken
nooit hetzelfde bestand raken.

Toestanden die het waard zijn om op te pauzeren, want ze zijn op zichzelf af:

- **na batch 1**: slepen werkt overal, de voerkar is weer bereikbaar, twee
  R3-gaten dicht.
- **na batch 4**: de balk staat en werkt, en zeven spellen zijn nagekeken.
- **na batch 6**: de Nu-chip staat er, de hotel-lus klopt, er is een elfde spel.
- **na batch 9**: alles.

---

## 6. Open vragen voor de eigenaar

Alleen vragen waarvan het antwoord de bouw echt verandert. Bij elke vraag staat wat
het plan aanneemt als je niets zegt — dan gaat het gewoon door.

**V1 — Zwembad: mag een te grote tik een plons + terugzwemmen worden in plaats van
het einde van de beurt?** (`N3`) Vandaag is één tik op een te groot getal genoeg:
hij zwemt de rest, botst, en de beurt is af mét ster — 12 van de 13 band-3-banen zijn
zo in één tik uit te spelen. In de code staat letterlijk vastgelegd dat de ster hoort
bij het **bereiken** van de overkant, ook na een bots (`games/zwembad/spel.gd:406-408`,
`architecture.md §1.1 F5`). Dit is dus een ontwerpwijziging tegen een eerdere
beslissing in, geen bugfix. *Aanname: ja — botsen is een plons, hij zwemt terug en de
vraag komt terug. Dat is de enige manier om het rekenen onontkoombaar te maken zonder
de bevroren kern aan te raken; het maakt een beurt wel langer.*

**V2 — Mag de balk op een 1024×768-tablet één voxelstap kamer kosten?** (`B2`) De
kamer wordt bóven de balk ingepast, dus `g` zakt van 4 naar 3 in de receptie en de
tuin. Op de telefoon kost het niets (daar bindt de breedte en stond 47 % van het
kader leeg). Het alternatief is de kamerbalk op breed landschap naar de rail náást
het kader verhuizen — dat geeft ±52 units hoogte terug en houdt `g = 4`, maar het is
een aparte verbouwing van de hele shell. *Aanname: ja, accepteren; de kamer vult
daarna nog ~95 % van de ruimte boven de balk en HOTEL.md §1 ("de doos vult minstens
60 %") blijft gehaald.*

**V3 — Bedden: mag de kamerdeur ophouden de controleknop te zijn?** (`N9`) De spec
(`games-a.md §3.5`) maakt de deur de knop waarmee je je rij laat nakijken; gevolg is
dat weglopen uit de kamer een misser kost. *Aanname: ja, de deur wordt weer een deur
en 🐾 blijft de enige controle; de beurt staat in `ctx.data()` en is er bij terugkomst
nog.*

**V4 — Meubels: is "Hoeveel euro heb je?" de juiste eerste som?** (`N6`) Het
alternatief is meteen een prijsvraag over het eerste artikel — maar dan moet het boek
eerst open en is de winkel weer het eerste beeld, wat R1 breekt. *Aanname: de
buidel tellen bij de kassa, in de wereld, met de munten echt op de toonbank.*

**V5 — Twee nieuwe kamers of drie?** (`R2`, `R3`) Het plan bouwt de **Speelzaal** (huis
van Spiegelmaskers en de aaihoek) en de **Kas** (seizoensetalage, toekomstig
moestuinspel). De **Feestzaal** is geschrapt: het spel dat haar zou vullen kwam bij de
jury als op één na laatste uit, en elke extra kamer verlengt de `rooms.gd`-ketting met
een hele batch. *Aanname: twee. Wil je de Feestzaal toch, dan is dat één extra taak in
een eigen batch na `R3` — zeg het vóór `R2` begint, want dan verandert de
plattegrondindeling.*

**V6 — Hoe lang duurt een seizoen?** (`R7`) Het plan rekent met **7 speeldagen per
seizoen**, dus 28 dagen rond. Korter (3-4 dagen) maakt de variatie zichtbaarder voor
een kind dat maar een paar dagen speelt; langer maakt elk seizoen bijzonderder. *Eén
constante om te draaien (`HotelSier.SEIZOEN_DAGEN`).*

**V7 — Moet de Bellensprint een apart spel worden?** (`N14`, `M5`) `N14` bouwt jouw
wens ("snel tikken bij het zwembad per strook") **in de bestaande zwemles** — klein,
vroeg, en zonder een tweede zwemspel in dezelfde baan. `M5` maakt er daarbovenop een
eigen spel van waarin de openingssom het speelveld bepaalt en elke drijflijn zijn
eigen tussensom heeft. De jury waarschuwde: voor een kind leest dat als "weer
zwemmen". *Aanname: eerst `N14`, en `M5` alleen als je na het spelen zegt dat je hem
wilt. Hij staat daarom als optioneel in de laatste batch.*

**V8 — Aaien: is drie het goede aantal?** (`D1`) `AAI_MAX = 3`, +1 per som, vol bij
elke afgeronde taak en bij een nieuwe dag. Royaler kan (5 aaien, +2 per som) — het is
één constante. *Aanname: 3. Klein genoeg dat een kind de lus binnen tien seconden
ziet, groot genoeg dat het nooit gierig voelt.* En ter bevestiging, want het is een
eigenaarsbeslissing en geen implementatiedetail: **aaien raakt op door te aaien, niet
door te treuzelen** — akkoord?

**V9 — Was: mag het kind meer dan één stuk tegelijk van de berg pakken?** (`N8`) Met
een "pak 1 / 2 / 5"-strook zoals de voerkar die had wordt het sorteren zelf telwerk en
komt de verhouding rekenen/sjouwen in tikken écht boven de helft; nu blijft het 40
sorteertikken tegen 4 vragen. *Aanname: nee, niet in deze fase — het is een halve taak
extra en de openings- en tussensom lossen R1 al op.*

**V10 — Mag het pictogram één keer boven de antwoordstrook staan?** (`B4`) HOTEL.md §9
en `tests/test_ui.gd:216` eisen pictogram **én** woord op elke knop. Bij getalknoppen
levert dat vier keer hetzelfde plaatje op (`🔑 20  🔑 30  🔑 40  🔑 50`) en dat kost op
een telefoon ±40 % van de knopbreedte die het getal zou kunnen krijgen. *Aanname: de
regel blijft zoals hij is; de balk geeft de knoppen zoveel extra breedte dat het past.*

---

## 7. Voortgang

- 2026-09-18 01:30Z — batch 1 (S1 B1 R1 V1 N1 N2) gebouwd door Opus-max-agents in worktrees, blind gecontroleerd, samengevoegd; suite 422/0; commits a121365 fad9b05 c7717bc d764cbc e0c3483 e3f398c. Batch 2 gestart.
- 2026-09-18 (avond) — **buiten de batches, op verzoek van de eigenaar** (commit "spelbalk"): (a) zodra een spel voorrang heeft verbergt `Hits.plaats()` elke hotelknop in het kader (deuren, bel, prikbord, ingangen van andere spellen, wensen) behalve wat het spel geleend heeft; naamplaatjes en getalplaatjes blijven. (b) Nieuwe `ui/spelbalk.gd`: zolang een spel loopt neemt `⬅ Terug` + spelnaam de rij van de kamerbalk over (zelfde voetafdruk, kader beweegt niet; in de compacte shell de rail), altijd op dezelfde plek; Terug = `Games.stop()`. Een balk ín het kader is geprobeerd en verworpen: op 740×360 en 360×740 vocht hij met de kaarten van hinkel, sleutels, meubels en voerkar om dezelfde hoek. (c) De voerkar leent nu ook de deuren (`pak`), tik = kar erdoor duwen. (d) ⬅ (U+2B05) in de emoji-subset. **Gevolg voor B2/B3/B6**: de "Nu"-knop en de terugweg hoeven niet meer in de balklaag; B2 alleen nog als kaartdok. Eigenaar wil eerst testen vóór batch 3.
- 2026-09-19 — **teruggedraaid op `main`**: commit 0ba9e63 ("Rekenbalk: dynamische balk + muntstrip-fix", lokaal model Qwen3.8, B2/B3/B4 ineens) is met een revert van `main` gehaald en staat ongewijzigd op de tak `qwen/rekenbalk-b2-b3-b4`. Reden: gepusht met 5 rode tests (bedden ×2, sleutels K1, was N8, balk), CI en Pages rood. Vier daarvan komen door één ding: een permanente balk tot 48 % van de kaderhoogte laat op lage kaders geen banden over voor de spelknoppen — dezelfde was/sleutels-regressies waarop B2 eerder is afgekeurd. De vijfde is een echte bug: `Ui._balk_kaart_rect` wordt bij het sluiten van een kaart nooit gewist (alleen overschreven in `balk_meld`), dus de balk blijft gegroeid en het nieuwe laatste-redmiddel in `Hits._kies_plek` zet knoppen óp het papier. **Opdracht voor het lokale model (eigenaar, 2026-09-19): bouw alleen wat nog open staat, taak voor taak volgens §4 en §5.1, op `main` zoals hij nu is.** Klaar en gemerged: batch 1 (6/6) en batch 2 zonder B2 (7/8). Open, in deze volgorde: eerst B2 als kaartdok samen met N8 en de sleutels-opstellingsregel (zie de regel hieronder), daarna batch 3. Regels die hierbij gelden: (1) de spelbalk uit `ui/spelbalk.gd` blijft; de "Nu"-chip en de terugweg horen niet meer in het kader (zie de regel van 2026-09-18 avond), dus B2/B3/B6 zijn kleiner dan §3.1 beschrijft; (2) het balkplafond blijft 0.34 uit §3.1 tenzij de eigenaar anders zegt, en de balk mag pas ruimte kosten als er echt een kaart in staat; (3) `tools/test.sh` moet 0 fout geven vóór een commit, en nooit pushen met rode tests; (4) één taak per commit, alleen de bestanden van die taak; (5) `core/sommen.gd` blijft byte-gelijk. De tak `qwen/rekenbalk-b2-b3-b4` mag als bron dienen (de Keuzeknop-muntstrip-fix en de wens-tik `Hotel.tik_wens` zijn bruikbaar), maar niet als geheel terug.
- 2026-09-18 04:05Z — batch 2: D1 N3 N4 N5 N6 N7 V6 gebouwd, blind gecontroleerd, samengevoegd; suite 461/0. **B2 (balklaag) NIET samengevoegd**: de tweede controle faalde op twee kadergebonden regressies buiten zijn bestandsset (test_was kratplaatjes op 740×360, test_sleutels opstelling op 1024×768); het werk staat in worktree `.claude/worktrees/wf_d8939a2e-e84-1` (tak worktree-wf_d8939a2e-e84-1, basis 2fa48de) met 437/2 in die worktree. Volgende sessie: B2 hervatten samen met N8 (was-indeling) en de sleutels-opstellingsregel; daarna batch 3.
- 2026-09-19 (avond, lokaal model) — **B2 + de sleutels-opstellingsregel, de balk is een kaartdok.** Nieuw `ui/rekenbalk.gd`: een Control over het hele kader met `mouse_filter = IGNORE` die alleen het gelinieerde papier tekent (afgeronde bovenhoeken, `PAPIER`/`PAPIER_RAND`/`PAPIER_LIJN`), geen knoppen — de kaart en de strook blijven hotspots van `Hits`. `Ui` kreeg de hele balksectie: `balk_hoog/balk_vorm` (de tabel van §3.1 via `UiThema.balk_maten`), `balk_dak` (0.34), `balk_ruimte`, `balk_kaart`, `balk_kost`, `balk_aan`, `balk_rect`, `balk_plek(kind, maat)`, `balk_bepaal`, `balk_kandidaat`, `kaart_mat`, `_strook_mat`, `_balk_herstel`; `registreer_lagen` kreeg een zesde optionele parameter `balk_l`, dus geen van de dertien testopstellingen hoefde te veranderen. `World.meet()` vraagt `Ui.balk_bepaal()` **vóór** de schaal (de fit moet weten wat de balk afpakt voordat de schaal genomen wordt) en `World.zet_balk(h)` herbouwt camera en schaal; `Hits` kent anker `"balk"`, vóór `kleef_aan`, zet het balkvlak in `_bezet` en laat `_botst` er ook tegen botsen, en `_maat_van` vraagt `Ui.kaart_mat()` zodra de hulplijn zichtbaar is. **De kernregel van de eigenaar (2): de balk kost niets zolang er geen kaart in staat** — met niets gedokt is `balk_kost()` 0 en wordt de wereld in het hele kader gepast zoals altijd, en dat is waarom elke bestaande test de oude cijfers blijft zien. **Twee plafonds, niet één:** 0.34 uit §3.1 én `balk_ruimte()` = kaderhoogte − `WERELD_BANDEN`(5) × `Hits.RIJ`. De 0.34 alleen liet op 740×360 een balk van 122 toe met 238 units wereld over; de beddenrijen overlapten toen 2500 px en kwamen `krap` home. Een kamer heeft banden nodig om zijn eigen knoppen te leggen, en een knoop van 48 px krimpt niet mee met de wereld. **Buiten de bestandsset van B2, en alleen omdat §7 deze taak samen met N8 en de sleutelsregel noemt:** `tests/test_hits.gd` — de strook kleeft niet meer onder haar kaart maar hangt naast haar in de balk, `op` is `"balk"` als de balk aan is en `"kleef"` als hij uit is, plus een assertie dat de strook niet op de kaart staat. Zonder die wijziging was B2 niet groen te krijgen. **Niet gedaan:** de driehoek van de kaart naar het voorwerp en het ringetje om het voorwerp (§3.1) — die horen bij B3/B6; de `Nu`-knop blijft een onzichtbaar kind tot B6; de balk is nog niet te verslepen. **Gemeten op de echte frames:** op 990×637 docks de sleutelkaart (balk 160 hoog, `op=balk`), op 326×558 ook, op 740×360 laat de balk los en staat de kaart ouderwets boven in de kamer. 471 goed, 0 fout.
- 2026-09-19 (avond, lokaal model) — **de sleutels-opstellingsregel, bij B2 horen.** `games/sleutels/spel.gd`: `_bodem(kader)` geeft de onderkant terug die de rij mag gebruiken — de kaderonderkant als de balk uit is, de bovenrand van het papier als de vraagkaart erin staat; `_opbouw` werkt met `werk` (het kader tot die bodem) en met `in_balk = Ui.balk_aan() and Ui.balk_kaart() == KAART`.  Daarmee is "past de kaart boven of naast de rij" niet meer aan de orde als de kaart gedokt is: `kaart_r` wordt leeg en de rij krijgt de ruimte die de kaart net nog aan de kamer afstond, in plaats van hem twee keer te betalen.  De **echte** kaderhoogte blijft de `kort`/`smal`-keuze maken — de eerste poging (alles via een gekrompen kader laten lopen) maakte 326×558 `krap` waar `stapel` hoorde.  De `stapel`→`gewoon`-afzwakking eist niet langer dat `kaart_py == kaart_py_nat` als de kaart in de balk staat.  Modusverdeling over de vijf frames ongewijzigd: `gewoon` 990×637, `stapel` 326×558 en 734×788, `naast` 558×322, `krap` 236×236; `MODUS` in de test niet aangeraakt.  15 goed, 0 fout.

Vink aan wat gemerged is op `main`. Zet erachter wie het deed en op welke datum.

| batch | taken | klaar |
|---|---|---|
| **1 — Fundament** | `S1` `B1` `R1` `V1` `N1` `N2` | 6 / 6 |
| **2 — De balk staat** | `B2` `D1` `N3` `N4` `N5` `N6` `N7` `V6` | 8 / 8 |
| **3 — Het balkanker** | `B3` `V2` `V5` `N8` `N9` `K1` `K3` `R2` | 0 / 8 |
| **4 — Grote letters** | `B4` `V3` `N10` `N12` `N13` `K2` `R3` | 0 / 7 |
| **5 — De balk af, de lus** | `B5` `V4` `N11` `N14` `K4` `L1` `R4` `S2` | 0 / 8 |
| **6 — De Nu-chip** | `B6` `B8` `K5` `R5` `M1` | 0 / 5 |
| **7 — Aaien en polonaise** | `B7` `B9` `D2` `M2` `K6` `R6` | 0 / 6 |
| **8 — Check-in, seizoen, spiegel** | `B10` `M3` `R7` `D3` `S3` | 0 / 5 |
| **9 — Slot** | `L2` `R8` `M4` `M5` `S4` | 0 / 5 |

**Vervallen uit de oorspronkelijke ontwerpen** (met opzet, zie §3.9): de tweede en
derde uitvoering van de sleepreparatie · `tools/speel.js` als voorwaarde · het houten
sleutelrek · de wekker-kaartklem · de was-strookplaatsing · de dubbele dagvariatie ·
de tweede Speelzaal · de Feestzaal (open vraag V5) · koekjes vangen onderweg · de
zichtbaar vullende voerkar.

**Metingen om bij te houden** (noteer ze bij elke batch, ze zijn het bewijs):
suitecijfers (start: 405 goed / 0 fout / ±153 s) · aantal knoppen in de keuken tijdens
`voerkar` (start: 16) · `World.schaal()["g"]` per kamer per kader · de verhouding
wenssoorten over 14 dagen (start: eten 42 van 56).
