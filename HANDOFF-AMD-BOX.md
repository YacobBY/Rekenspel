# HANDOFF — het werk verhuisde naar de AMD box (2026-09-22)

Dit bestand beschrijft waar het project nu draait en hoe je erbij komt. Het gaat
over de opstelling, niet over de inhoud van het spel; daarvoor zijn `AGENTS.md`
en `PLAN.md`.

## De kern in drie regels

1. Het lokale model werkt **op de AMD box** (192.168.100.1) in
   `~/Documents/Rekenspel`, niet meer op dit werkstation.
2. Deze map (`/home/pc/Documents/xnw/rkn`) is een **kopie**. Beide kanten staan
   op commit `1ec7dcb`, drie commits vóór `origin/main`.
3. Bewerk niet op twee plekken tegelijk. Kies één kant, en synchroniseer bewust.

## Vanaf dit werkstation

| wat | commando |
|---|---|
| bij de agent, zelf typen | `box-qwen.sh` |
| alleen meekijken | `box-qwen-kijk.sh` (of `--volg` voor elke 10 s) |
| draait er iets? | `box-qwen.sh --status` |
| sessie stoppen | `box-qwen.sh --kill` |
| bureaublad van de box | NoMachine naar 192.168.100.1, inloggen als `pc` |

Op het bureaublad staat ook het icoon **"Qwen op de AMD box (Rekenspel)"**.

Losmaken zonder te stoppen: `Ctrl+b` daarna `d`. De sessie leeft in tmux onder
de naam `qwen`, dus hij loopt door als je de verbinding verbreekt.

## Hoe de box is ingericht

- **Model**: halogen op `127.0.0.1:8080` op de box zelf. De agent praat daar
  rechtstreeks mee, dus de proxy op dit werkstation is niet meer nodig en dit
  werkstation mag uit.
- **Agent**: MiniMax Code 0.5.2 in `/home/pc/installs/minimax-code`. Instellingen
  in `~/.minimax/config.yaml`: `permissionMode: bypassPermissions` (statusbalk
  toont "Full access", hij vraagt dus nooit om toestemming),
  `dataContribution: enabled: false`, provider `custom_provider:provider-2619ef`.
- **Godot 4.7.2** staat er, met de exportsjablonen. Let op: `~/.local/bin` zit
  **niet** in het zoekpad van niet-interactieve shells, daarom staat er een
  koppeling in `/usr/local/bin/godot`. Zonder die koppeling faalt `tools/test.sh`
  met `exit 127` en de melding "godot niet gevonden".
- **Bewezen op de box**: `DH_TEST_FILTER=bedden tools/test.sh` → 23 goed, 0 fout.
- **Ontbreekt op de box**: `playwright`. Daardoor werken `tools/kiek.js` en
  `tools/speel.js` daar nog niet. Schermafbeeldingen maken en het spel spelen kan
  dus alleen op dit werkstation, waar playwright in
  `/home/pc/work/ergomouse/node_modules/playwright` staat.

## Synchroniseren

Van dit werkstation naar de box (overschrijft de box):

```bash
rsync -az --delete \
  --exclude 'godot/dierenhotel/build/' --exclude 'godot/dierenhotel/.godot/' --exclude 'tmp/' \
  /home/pc/Documents/xnw/rkn/ pc@192.168.100.1:/home/pc/Documents/Rekenspel/
```

Andersom kan met dezelfde regel met de paden omgedraaid. Netter is via GitHub:
de box kan `origin` bereiken, dus daar committen en pushen, en hier `git pull`.

## Stand van het werk

- Drie commits staan lokaal klaar en zijn **niet gepusht**: `1fd598a` (speel.js
  en de AGENTS-regels), `008dd37` (speelzaal R2), `1ec7dcb` (bedden, lege kamer
  bij de vraag).
- Ongevolgd in beide kopieën: `ANALYSIS.md` en `tools/export.sh.bak`; gewijzigd:
  `tools/speel.js`.
- De agent op de box werkt op dit moment aan **B4** uit PLAN.md: kaart en
  antwoordstrook in balkvorm met grote letters. Hij koos die taak zelf, na
  vaststelling dat batch 3 op 9 van 9 staat.

## Twee regels die in AGENTS.md zijn bijgekomen

- Alle logs, kiekjes en kladbestanden horen in `tmp/` binnen de repository, niet
  in `/tmp`. `tmp/` staat in `.gitignore`. Schrijven buiten de werkmap kostte
  goedkeuringsvensters en legde onbewaakte sessies stil.
- Er staat nu een kopje over zelf beslissen in plaats van vragen: kies de
  aanbevolen optie bij omkeerbare keuzes, en vraag alleen bij de bevroren
  rekenkern, bindende spec-teksten, gedeelde UI-code en taken die het plan als
  eigenaarsbeslissing markeert.
