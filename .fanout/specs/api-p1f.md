# API-notities P1f — geluiden, stubs, laadorde, runner (golf 3)

Bron voor G1–G5 zolang GAMES-API.md deze punten nog niet zelf noemt.
Basis: worktree agent-ac5a197655b5d09cf op af8ab32.

## 1. Vier nieuwe geluiden in `snd.js` (regels 97-106)

Zelfde vorm als de bestaande: `Snd.<naam>()`, geen argumenten, geen
retourwaarde, geen bestanden (WebAudio). Elke toon loopt via `band()`, dus
met de speakerknop uit (`Snd.dempt() === true`) klinkt er niets en gaat er
niets stuk; met een slapende audiocontext wordt `resume()` geprobeerd en
wordt de toon gewoon gepland. Roep ze aan zoals `Snd.tik()`; nooit in een
lus per frame.

| naam        | bedoeld voor                                        | klank                                  |
|-------------|-----------------------------------------------------|----------------------------------------|
| `Snd.plons` | dier het water in (zwembad, start van een zwembeurt) | plonstoon 560→150 Hz + twee spetters    |
| `Snd.au`    | zachte bots tegen de badwand ("Au!"-wolk, ≤ 1,5 s)   | twee lage, ronde sine-tonen, 0,25 s     |
| `Snd.klok`  | de halklok slaat één keer (wekker goed gezet)        | één aanslag 659 Hz + boventoon, 0,58 s  |
| `Snd.hup`   | één sprong naar de volgende steen (hinkelpad)        | blipje 430→720 Hz, 0,11 s               |

Grenzen (gemeten in p1f.js): gain ≤ 0,40, alleen sine, `au` ≤ 0,26 en
≤ 0,6 s — dit spel straft nooit, dus `au` is nadrukkelijk geen schrikgeluid.
Voor de wasmandtoren en de kraam zijn de bestaande `Snd.plop`, `Snd.terug`,
`Snd.munt`, `Snd.ja` en `Snd.zacht` genoeg.

## 2. Stubbestanden en laadorde

`games/zwembad.js`, `games/wekker.js`, `games/hinkel.js`, `games/was.js`,
`games/kraam.js` bestaan en bevatten alleen een kopcommentaar (geen
`Games.register`, geen code). Ze hangen al in `index.html` (regels 71-76)
achter `games/meubels.js` en vóór `game.js`, dus na `games/registry.js`,
`hotel.js` en alle vijf bestaande spellen. Wie zijn spel bouwt vervangt
alleen de inhoud van zijn eigen bestand; `index.html` blijft ongemoeid.
Zolang een stub leeg is meldt `Games.lijst()` nog precies
`voerkar, bedden, sleutels, tobbe, meubels` (in die volgorde).

## 3. Runner-rijen in `alles.sh`

Tien rijen achter `voerkar-land`: `<id>-port|node <id>/spel.js` en
`<id>-land|node <id>/spel.js land` voor de vijf ids. Zolang
`.fanout/scratch/dierenhotel/<id>/spel.js` ontbreekt print de runner
`[<id>-port] SKIP (<id>/spel.js ontbreekt)` met exitcode 0 (bevestigd met
`alles.sh zwembad-port`). De teller leest de laatste regel
`N pass, M fail` of `N goed, M fout`; anders telt hij `^PASS`/`^FAIL`-regels.

## 4. Bijgewerkte documentatie

* `games/tobbe.js` 39-41: de oude claim "geen ctx-functie om een behoefte af
  te vinken" is vervangen; `ctx.wereld.behoefteKlaar(gastId, behoefte)`
  (registry.js 182 → `Hotel.wensAf`) zet `g.blij` voor `bad`/`spelen`, haalt
  het wenswolkje weg, bewaart en tekent opnieuw. Tobbe roept het zelf aan
  (tobbe.js 955).
* `GAMES-API.md` 49-51: de vier "plaatshouders" zijn af; de vijf nieuwe
  bestanden hangen er leeg in.

## 5. Suite

`.fanout/scratch/dierenhotel/p1f.js [land]` — 48 assertions per stand:
stubs op schijf, runner-rijen, schone laadronde (geen console-fout, geen
404), zelfde `Games`-lijst, laadorde, de vier geluiden bij slapende,
lopende en gedempte audiocontext, schermafdruk `p1f-port.png`/`p1f-land.png`.
Met `DH_SRC=<map>` meet je een andere kopie van `demos/dierenhotel`.
