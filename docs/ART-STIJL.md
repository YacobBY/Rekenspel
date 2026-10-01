# De art-stijl van Dierenhotel Kwispelsteeg: zacht pastel isometrische pixelart

> **2026-10-01 — de standaard is weer de voxelstijl.** De eigenaar: *"Ik wil het spel
> eigenlijk toch graag terug naar de oude isometrische 3d files. Gooi de nieuwe art style niet
> weg maar bewaar het als backup zodat ik uiteindelijk eventueel kan vergelijken."* Het spel
> tekent weer in de gladde isometrische voxelstijl (`Art.STANDAARD = "voxel"`). Alles in dit
> document blijft gelden voor de **pixelstijl als backup**: die zit volledig in de code en is te
> zien met **`index.html?stijl=pixel`** (naast de standaard, om te vergelijken); de tak
> `backup/pixelart` op GitHub bewaart het spel zoals het in pixelart was. De pixeltests
> (`tests/test_pixelstijl.gd`, de gouden pixelplaatjes) schakelen zelf naar de pixelstijl en
> blijven dus bewaken dat de backup heel blijft. Een nieuw model maak je voortaan voor de
> voxelstijl; de pixelplaatjes schrijf je daarna nog wel opnieuw (§6, stap 2).

Vastgelegd op 2026-09-30 na de keuze van de eigenaar ("Zacht pastel is het mooist"), uit drie
mockups: A Habbo-klassiek (zwarte randen), **B zacht pastel** (gekozen) en C grove pixels. Dit
document is de regel voor alles wat in de wereld getekend wordt. Het vervangt voor de standaardstijl
de schaduw- en omlijningsregels van `.fanout/specs/godot/art-sound-rules.md` §1.1, §1.6 en §3. De
modellen zelf (vormen, kleuren, poses, maten) blijven die van de spec: de stijl zit in de tekenaar,
niet in de modellen.

## 1. In één zin

Elk ding in het hotel is gebouwd uit blokjes (voxels). Het wordt getekend als **isometrische
pixelart in 2:1**, **één pixel per voxel-px**, met **drie vlakke tinten per kleur**, een **rand
van één pixel in een donkerdere versie van de eigen kleur**, **zonder anti-aliasing**, en daarna
met een hele factor `g` vergroot zonder glad te maken.

## 2. Projectie en raster

- **2:1 dimetrisch**, zoals Habbo. Een stap in `x` gaat 2 pixels naar rechts en 1 naar beneden,
  een stap in `z` 2 naar links en 1 naar beneden, en een stap in `y` (hoogte) 2 omhoog.
  `x` loopt naar rechtsonder, `z` naar linksonder. De muren staan op `x = 0` (links) en `z = 0`
  (rechts achter).
- **Eén voxel in pixels**: de bovenkant is een ruitje van 2 + 4 pixels (twee rijen), en elke
  zijkant is 2 × 2 pixels. Dezelfde geometrie als de oude tekenaar (`Art.S = 2`,
  `Art.HG = 2`), maar nu als harde pixels in plaats van gladde veelhoeken.
- **Vergroting**: alles wordt op 1 pixel per voxel-px getekend en daarna met de hele factor `g`
  van de kamer (2 tot 4) vergroot, met `INTERPOLATE_NEAREST` / `TEXTURE_FILTER_NEAREST`. Een
  pixel van de art is dus altijd een blok van `g × g` schermpixels.
- **Het pixelraster ligt vast**: het nulpunt is het schermpunt van voxel-px (0, 0) van de kamer
  (`World.scherm(0, 0, 0)`). Vloer, muren en alle plaatjes liggen op hetzelfde raster; een lopend
  dier springt steeds een hele pixel (`Art.op_raster`). Zo "zwemmen" de pixels niet.

## 3. Kleur en licht

- **Palet**: de pastelkleuren van de modellen (`art/decor*.gd`, `art/gasten.gd`,
  `art/vloer.gd`, en de muurkleuren in `scenes/vloer.gd`). Zacht, warm en licht. Geen pure
  zwarte of pure witte vlakken in modellen. De ogen zijn de enige echt donkere pixels.
- **Drie tinten per kleur, vlak**, zonder verloop en zonder ambient occlusion:

  | vlak | tint | constante |
  |---|---|---|
  | bovenkant | 10 % richting wit | `Art.P_TOP` |
  | rechterkant (+x, vangt het licht) | kleur × 0,97 | `Art.P_RECHTS` |
  | linkerkant (+z, schaduw) | kleur × (0,82 · 0,80 · 0,88), een koele lila schaduw | `Art.P_LINKS` |

- **Randlicht**: een pixel van een bovenkant die direct boven een zijkant ligt, krijgt 18 %
  extra richting wit (`Art.P_RAND`). Dat geeft de lichte bovenrand van elke kant, zoals in Habbo.

## 4. Omlijning

- **Eén pixel buiten het silhouet** van elk plaatje. De kleur is de aangrenzende pixel binnen de
  vorm × 0,58 (`Art.P_OMLIJN`): **een donkerdere versie van de eigen kleur, nooit zwart**. Een
  blauw deken krijgt een donkerblauwe rand, een wit konijn een grijslila rand.
- **Geen binnenlijnen** tussen materialen. Dat is het verschil met stijl A (Habbo-klassiek).
- **Het voerbakje** heeft twee helften (achter en voor, zodat een dier erin kan bijten): de rand
  loopt om het hele bakje en hoort bij de achterste helft. De voorkant heeft geen eigen rand.
- **De kamer zelf** krijgt dezelfde ring: een donkere lijn van één pixel onder de twee voorranden
  van de vloer (`RAND_VLOER`), over de achterrand van de muurkappen en langs de open uiteinden van
  de muren (`RAND_WAND`). De muren hebben in de pixelstijl echte kopse kanten en een dichte hoek
  bovenin. De tuin (`erf`), die voorbij de lijst doorloopt, heeft geen ring.

## 5. Wat niet mag

- **Geen anti-aliasing** en geen halfdoorzichtige pixels in een model (alfa 0 of 255,
  gecontroleerd in `test_geen_halve_pixels`). Doorzichtig mogen alleen: de grondschaduw onder een
  dier (15 %), de muurschaduw op de vloer, de schaduw onder een latei, het water over een zwemmer
  en het zachte vignet over het beeld.
- **Geen gladde vormen** in de wereld. Cirkels worden getrapte pixel-ellipsen (de grondschaduw:
  `ArtEffect.schaduw_pixels`), deeltjes zijn vierkantjes.
- **Geen achteraanzicht** van dieren. Een dier kijkt altijd schuin naar voren. De andere kant is
  hetzelfde plaatje gespiegeld (`flip_h`), zoals het spel altijd al deed.
- **Geen halve vergroting.** `g` is altijd een heel getal.
- De tekst- en knoppenlaag (kaartjes, wolkjes, de rekenbalk) is **geen** pixelart. Die blijft
  scherp en leesbaar in het lettertype van het spel (HOTEL.md §9).

## 6. Een model maken of aanpassen

De modellen staan in `godot/dierenhotel/art/`: `decor.gd` en de themabestanden `decor_*.gd`
(meubels per kamer), `gasten.gd` (de vier dieren, poses, hoedje, sjaaltje, bal, voerbakje) en
`vorm.gd` (de bouwstenen `bx`, `ell`, `hals`, `punt`, `verf`). Een spel kan eigen modellen
registreren (`Art.registreer_model("<spel>_naam", fn)`).

Tips voor een goed pixelresultaat:

1. **Details minstens één voxel.** Eén voxel is 4 pixels breed; een detail van een halve voxel
   bestaat niet. Ogen, knoppen en sleutelgaten zijn 1–2 voxels.
2. **Geen losse uitsteeksels van één voxel dik** tussen twee kleuren die op elkaar lijken: de rand
   van één pixel slokt ze op.
3. **Contrast tussen buren.** Twee delen die tegen elkaar aan liggen, moeten in helderheid
   verschillen, want er komt geen binnenlijn tussen. Een deken op een laken: kleur tegen wit.
4. **Rond = ellipsoïde (`ell`) met `e` rond 2–3**; bij deze grootte geeft dat een net getrapte
   pixelrand.
5. **Kleuren uit de pastelfamilie** van het bestand zelf (bovenin elk `decor_*.gd`).

Daarna, in deze volgorde:

```bash
# 1. zien of het nog bakt en welke gouden plaatjes veranderd zijn
DH_TEST_FILTER=test_pixelstijl tools/test.sh
# 2. de nieuwe look vastleggen (schrijft tests/gouden_pixel/*.png opnieuw) en de plaatjes bekijken
DH_GOUD_SCHRIJF=1 DH_TEST_FILTER=test_pixelstijl tools/test.sh
# 3. de kamer bekijken zoals een kind hem ziet (na tools/export.sh)
node tools/kiek.js --kamer kamer1 --uit tmp/kiek
```

De gouden plaatjes in `tests/gouden_pixel/` zijn op `g = 1` gebakken: dat is de pixelart zelf,
één pixel per voxel-px, en je kunt ze in elk tekenprogramma openen. Een bewuste wijziging betekent
dat je die plaatjes opnieuw schrijft (stap 2) en meecommit. Een onbewuste wijziging laat de test
rood worden.

## 7. De voxelstijl (sinds 2026-10-01 weer de standaard)

De oorspronkelijke look (gladde vlakken, occlusie-schaduw, zachte donkere contour) blijft bestaan
om te kunnen vergelijken: open het spel als **`index.html?stijl=voxel`**. De gouden plaatjes van
die stijl (`tests/gouden/`, uit de HTML-versie) blijven hem testen (`tests/test_art.gd` schakelt
per test naar voxel). Zodra niemand hem meer nodig heeft, kan hij weg: het `else`-pad van
`Art.bak`, `draw_mesh` in `scenes/vloer.gd` en de voxeltests.

## 8. Waar het in de code zit

| wat | waar |
|---|---|
| stijlkeuze, `?stijl=voxel`, `Art.pixel()`, `Art.zet_stijl()`, `Art.op_raster()` | `autoload/art.gd` bovenin |
| de pixeltekenaar van alle modellen en dieren | `Art._bak_pixel`, `Art._pixel_lijst`, tinten in `Art._tint` (`P_*`-constanten) |
| vloer, muren, deuren, trap, gevel als pixels | `scenes/vloer.gd`: `_rasteriseer`, de ring in `_randen` |
| sprites op het pixelraster | `scenes/wereldobject.gd` `ververs()` |
| de pixel-grondschaduw | `ArtEffect.schaduw_pixels` (`art/effect.gd`), getekend in `scenes/dier.gd` |
| tests en gouden plaatjes | `tests/test_pixelstijl.gd`, `tests/gouden_pixel/` |

## 9. Mockups

De vergelijking A/B/C, de lopende demo's en de mockup-tekenaar staan in `tmp/pixel/`
(`render.py`, `anim.py`, `dump.gd`, `demo-b-*.gif`). `tmp/` staat niet in git: bewaar die map,
maar het echte spel is nu de maatstaf.
