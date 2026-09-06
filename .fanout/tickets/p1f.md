TICKET P1f — Sounds, game stubs, script wiring, runner rows and stale-doc fixes for five upcoming Dierenhotel minigames.

TASK
Five games (ids zwembad, wekker, hinkel, was, kraam; spec /home/pc/Documents/xnw/rkn/.fanout/specs/dierenhotel-golf3-games.md) will be written by parallel workers each confined to games/<id>.js. Prepare the shared wiring so they never touch shared files.

EXPECTED OUTCOME
1. snd.js: four new sounds in the existing Web-Audio style (no files): `plons` (soft splash), `au` (a soft, short, non-alarming bump — nothing harsh; this game is never punishing), `klok` (a soft single chime), `hup` (a small hop blip). Same API shape as the existing ones (snd.js ~61-97 at 25a4b52); respect the mute toggle.
2. Stub files demos/dierenhotel/games/zwembad.js, wekker.js, hinkel.js, was.js, kraam.js containing only a header comment ("Wordt gevuld door ticket G1 … — nog geen Games.register, zodat er niets verandert tot het spel af is") — no registration, no code.
3. index.html: five script tags for those files after the existing game scripts and before game.js (check load order at index.html ~54-71).
4. .fanout/scratch/dierenhotel/alles.sh: ten rows (`zwembad-port|node zwembad/spel.js`, `zwembad-land|node zwembad/spel.js land`, same for wekker, hinkel, was, kraam) following the existing row pattern (alles.sh ~18-40); a missing script prints SKIP (~99-103) — confirm by running `alles.sh zwembad-port`. Copy the updated alles.sh to /home/pc/Documents/xnw/rkn/.fanout/scratch/dierenhotel/alles.sh as well (scratch is gitignored, so the main copy is the one that counts).
5. Stale claims: games/tobbe.js ~39-41 says there is no ctx function to tick off a wish, but ctx.wereld.behoefteKlaar exists (registry.js) and tobbe uses it (~955) — fix the comment. GAMES-API.md ~49-50 still calls the four games "placeholders" — correct that sentence only (other API docs are consolidated later by the lead; do not add sections).
6. Suite .fanout/scratch/dierenhotel/p1f.js (port + land, ≥15 assertions): page loads with the five stubs without console errors or 404s; Games has exactly the same registered ids as before (bedden, sleutels, tobbe, meubels, voerkar — verify the actual list); each new Snd function exists and can be called without throwing with the audio context suspended and with sound muted; script order as required. Existing suites smoke, plugin, regels stay green against your worktree (override hard-coded main-tree URLs locally; do not change their defaults).

CONTEXT
Repo /home/pc/Documents/xnw/rkn; isolated git worktree branched from main at af8ab32. Vanilla JS, offline, no build. Playwright at /home/pc/work/ergomouse/node_modules/playwright. .fanout/scratch is gitignored: write your suite in your worktree's copy and copy it to /home/pc/Documents/xnw/rkn/.fanout/scratch/dierenhotel/ at the end. No new dependencies; no blanket pkill; you do not spawn agents; do not commit. Parallel tickets in their own worktrees edit rooms.js, world.js, hotel.js, state.js, art.js — do not touch those.

MUST NOT
Edit rooms.js, world.js, hotel.js, state.js, art.js, registry.js, ui.js, econ.js, existing sounds, existing games (except the tobbe.js comment).

WRITE SET
demos/dierenhotel/snd.js, demos/dierenhotel/index.html, demos/dierenhotel/games/{zwembad,wekker,hinkel,was,kraam}.js (stubs), demos/dierenhotel/games/tobbe.js (comment ~39-41 only), demos/dierenhotel/GAMES-API.md (one stale sentence only), .fanout/scratch/dierenhotel/alles.sh and p1f.js.

OUTPUT FORMAT
First line DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED; then ≤20 lines: file:line hunks, sound names, suite numbers, worktree path/branch, concerns.