TICKET S2 — Small shared fixes after the wave-2 merges (Dierenhotel demo).

TASK
Four independent, small, fully specified fixes in the main tree /home/pc/Documents/xnw/rkn (no worktree): work directly on main, do not commit.

EXPECTED OUTCOME
1. demos/dierenhotel/state.js leesSpel (around lines 640-650): the calls vulAan(...) and naarV7(...) (the v5→v6→v7 migration and defaults) run outside the surrounding try/catch, so a corrupt or hand-edited v6 blob throws and kills the start screen. Move them inside the try so a broken save falls back to "no save" like a JSON parse error does. No other change in state.js; the frozen math (koekjesSom, vergelijk, planOplossingen, sommen.*, antwoord1/antwoord2) stays byte-identical (prove with `git diff -U0 -- demos/dierenhotel/state.js`).
2. demos/dierenhotel/hotel.js tikBak (the handler that runs when a food bowl is filled): today it flips every guest in the room to gegeten and sets their wish to 🧶 spelen, erasing a 🛁, 🏊 or 🎁 wish when the child feeds first. Change it so a guest's wish is only rewritten when it is 'eten' (or absent); guests with another wish keep it (they still get gegeten). Check Hotel.render / prikbord expectations so the pill and the task chips stay consistent.
3. .fanout/scratch/dierenhotel/loop.js hard-codes 6 rooms and 7 room-bar chips ('kamerbalk heeft 6 ruimtes + plattegrond', '6 ruimtes in de deurgraaf', 'plattegrond met 6 ruimtes' around lines 102-103 and the plattegrond check): main now has 8 rooms (zwembad and wasserij were added) and 9 chips. Update the expected counts (derive them from Rooms.lijst() if that is cleaner) so `node loop.js` and `node loop.js land` pass against main.
4. .fanout/scratch/dierenhotel/alles.sh: add runner rows for the new suites, following the existing "tag|node path.js" pattern: `p1a|node p1a.js`, `p1b|node p1b.js`, `p1c|node p1c.js`, `p1d|node p1d.js`, `p1e|node p1e.js`, `p1f-port|node p1f.js`, `p1f-land|node p1f.js land` (add a row only for scripts that exist or are expected; a missing script prints SKIP so the rows are harmless). Confirm each new tag with `alles.sh <tag>` (or `--tags`) and that the parser accepts each suite's final line.

5. demos/dierenhotel/hotel.js plekVanBehoefte (around line 115, the 🏊 zwemmen branch): it sends the guest to x = bad.x0 − 6, z = (z0 + z1) / 2, which is next to the water; from there a wander walks through the pool. Use `Rooms.get('zwembad').dek.start` when present (ticket P1a-F1 adds `dek = {start:{x,z}, over:{x,z}}` on the deck in front of the water line), else keep the current fallback. One or two lines; keep the defensive structure.

VERIFY
node --check on state.js and hotel.js; run smoke.js, loop.js (port + land), w1.js (port + land) and regels.js against main and report numbers; simulate a corrupt v6 save in a Playwright page (localStorage kws-hotel-v6 = '{"v":6,"gasten":"nope"}' or similar) and show that the start screen still appears without console errors.

CONTEXT
Vanilla JS, offline file://. Playwright: require('/home/pc/work/ergomouse/node_modules/playwright'). Kill only browsers you started. Long shell heredocs are rejected by the sandbox: use the Edit tool. Do not spawn agents, do not commit, no dependencies. Other agents may run suites against the main tree concurrently: keep your edits minimal and atomic.

WRITE SET
demos/dierenhotel/state.js (leesSpel only), demos/dierenhotel/hotel.js (tikBak and the zwemmen branch of plekVanBehoefte only), .fanout/scratch/dierenhotel/loop.js, .fanout/scratch/dierenhotel/alles.sh.

OUTPUT FORMAT
First line DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED; then ≤ 15 lines: file:line per fix, suite numbers, the corrupt-save evidence, concerns.
