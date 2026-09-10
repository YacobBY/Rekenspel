# tests/gouden — de gouden-plaat orakel

63 PNG-platen, verliesloos uit de draaiende HTML-motor getrokken
(`extract.js` + `probe.html`, Playwright/chromium, art-sound-rules.md §14.1),
plus `meta.json` met per plaat de maat en de `dx`/`dy` offset.
`modelmaat.js` en `posemaat.js` meten de voxel-omvang van de decorstukken en
de houdingen; ze staan hier als bewijsstuk, niet als test.

`tests/test_art.gd` bakt dezelfde modellen in Godot en vergelijkt ze pixel voor
pixel met deze platen (architecture.md §3.6).

De map draagt een `.gdignore`: Godot importeert de PNG's dus niet en ze komen
niet in de web-export terecht (dat zou de pck van 108 kB naar ~1,5 MB duwen
voor bestanden die alleen een test leest). De test leest ze rechtstreeks met
`FileAccess` + `Image.load_png_from_buffer`; dat werkt vanuit de projectmap
(waar de suite draait) en slaat zichzelf over in een geëxporteerde build.

## Het geluid

`wav/*.wav` zijn de 18 geluiden zoals de HTML-motor ze offline rendert
(48 kHz, 16 bits, mono), afgeknipt op hun hoorbare lengte plus 30 ms nagalm:
445 kB in plaats van 2,6 MB, want de rest was stilte. Dit is het orakel;
`tests/test_snd.gd` leest de bestanden zelf, dus het overleeft /tmp.

`snd-oracle.json` beschrijft ze: per geluid het aantal monsters, de piek, de
RMS, de hoorbare lengte, een RMS-omhullende in 16 plakken, en de spreiding over
**acht** onafhankelijke export-runs.

Die acht runs beslechten meteen een verschil dat in de specificatie stond:
art-sound-rules.md §15.3 noemt `kar` −29,6 dBFS, de eerste export −31,5. Geen
van beide is fout. `kar` is `papier(0.24, 300, 0.26)` plus een toon, en
`papier()` gebruikt `Math.random()`, dus de piek is een kansvariabele. Acht
runs geven −31,77 … −29,90 dBFS met gemiddelde **−31,06**; beide gepubliceerde
getallen zijn trekkingen uit diezelfde verdeling. Hetzelfde geldt voor `brief`
(−28,85 … −26,09), `plons` (−23,24 … −21,54) en niet voor `deur`, waarvan de
piek uit de toon komt en dus vaststaat. De 14 oscillatorgeluiden zijn over alle
acht runs bit-identiek.

## Opnieuw uitbakken (alleen nodig als de HTML-motor verandert)

    node tests/gouden/extract.js       # platen  -> /tmp/dh-art
    node tests/gouden/snd-export.js    # geluid  -> /tmp/dh-snd

## De meetlat

`_meet.gd` is geen test maar het meetgereedschap; het drukt de getallen af die
architecture.md §3.5 en §8 begroten:

    godot --headless --path godot/dierenhotel --script res://tests/gouden/_meet.gd
