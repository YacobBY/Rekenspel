TICKET P1e — Accessories worn by the animals (hoedje, sjaaltje, bal) for the Dierenhotel demo.

TASK
The upcoming souvenirkraam game (spec /home/pc/Documents/xnw/rkn/.fanout/specs/dierenhotel-golf3-games.md, G5) lets a guest buy a hat, a scarf or a ball that stays visible on the animal until checkout. Add the drawing, the data field and a small API.

EXPECTED OUTCOME
1. art.js: each guest record may carry `accessoires: ['hoedje' | 'sjaaltje' | 'bal', …]`; the voxel builder draws a hat on the head voxels, a scarf around the neck, and a ball as a small separate model beside the animal, for all four species (hond, poes, konijn, gans) and in every pose including the new lying pose `lig` (added in commit 25d3c44: see POSE.lig, liggen(), oog:3 — do not break them). Soft, chunky look matching the animals; colours from the existing palette; reuse the existing voxel helpers. If model caches exist per species/pose, the cache key must include the accessory set.
2. Persistence: the field lives on the guest record and survives save/reload (find how guests are serialised in state.js / the v7 payload; an optional field defaulting to [] needs no version bump). Checkout must not crash on guests with accessories; a new guest starts with none.
3. API through the registry extension hook (push a function onto `window.CTX_UITBREIDINGEN` from art.js or from the module that owns guest records; read the comment at the end of ctxVoor in games/registry.js; do NOT edit registry.js): `ctx.wereld.accessoire(id, naam)` adds one (idempotent), `ctx.wereld.accessoires(id)` returns the list, `ctx.wereld.accessoireWeg(id, naam)`. Rendering must refresh immediately (whatever invalidation the world uses, e.g. World.vuil()).
4. Suite .fanout/scratch/dierenhotel/p1e.js (port + land, ≥25 assertions): pixel diff of a guest with and without hoedje, sjaaltje, bal for each species (standing and lig); persistence across reload; idempotence; removal; checkout of a guest wearing all three does not throw; no console errors; screenshot p1e-accessoires.png showing four species wearing hoedje+sjaaltje with a bal, standing and lying, at 420×860. Existing suites smoke, loop (port+land), slaap.js (124/0), w1 (port+land) stay green against your worktree (override hard-coded main-tree URLs locally; do not change their defaults).
5. .fanout/specs/api-p1e.md in your worktree: signatures, accessory names, where they are stored, drawing notes.

CONTEXT
Repo /home/pc/Documents/xnw/rkn; isolated git worktree branched from main at af8ab32. Vanilla JS, offline, no build. Playwright at /home/pc/work/ergomouse/node_modules/playwright; harness patterns in .fanout/scratch/dierenhotel/ (slaap.js, w1.js, s1-houdingen rendering trick if present). .fanout/scratch is gitignored: write your suite in your worktree's copy and copy it plus screenshots to /home/pc/Documents/xnw/rkn/.fanout/scratch/dierenhotel/ at the end. Do not edit GAMES-API.md. Hard rules: HOTEL.md §9 (soft animals). No new dependencies; no blanket pkill; you do not spawn agents; do not commit. Parallel tickets in their own worktrees edit state.js BEHOEFTE (wishes), hotel.js wish code, world.js, rooms.js: keep your hunks to art.js, the guest-record/save lines of state.js (not BEHOEFTE, not the frozen math: koekjesSom, vergelijk, planOplossingen, sommen.* must stay byte-identical — prove with `git diff -U0`), and, only if strictly needed for guest creation, a one-line hotel.js change.

MUST NOT
Edit registry.js, rooms.js, world.js (except calling an existing invalidation function from your extension), any game, ui.js, econ.js.

WRITE SET
demos/dierenhotel/art.js, demos/dierenhotel/state.js (guest record / save payload only), demos/dierenhotel/hotel.js (at most one line at guest creation), .fanout/specs/api-p1e.md, scratch suite + screenshot.

OUTPUT FORMAT
First line DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED; then ≤25 lines: file:line hunks, signatures, suite numbers, frozen-math proof, screenshot path, worktree path/branch, concerns.