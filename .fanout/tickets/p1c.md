TICKET P1c — Animal movement with completion promises and two new poses (zwem, spring) for Dierenhotel.

TASK
In demos/dierenhotel/world.js the Dier class moves with `ga(tx, tz, na)` where `na` is a pose string (no callback), `World.reisNaar` walks door-to-door, and games poll `ctx.wereld.dier(id)` on timers to learn a move finished (see games/tobbe.js ~891-899). Upcoming games need: a swimming animal that swims exactly n metres along the pool and reports arrival (zwembad, spec G1), an animal hopping stone by stone along a number line with a count per landing (hinkelpad, G3), and generally "walk there, then do X". Spec: /home/pc/Documents/xnw/rkn/.fanout/specs/dierenhotel-golf3-games.md (read G1 and G3).

EXPECTED OUTCOME
1. World-level functions, exposed to games by pushing an extension onto `window.CTX_UITBREIDINGEN` from world.js (read the comment at the end of ctxVoor in games/registry.js; do NOT edit registry.js):
   - `ctx.wereld.loopNaar(id, x, z, {pose, tempo}) → Promise<boolean>`: resolves true when the animal arrives at (x,z) in its current room; resolves false (never rejects) when the move is superseded by any other command (ga, zet, reisNaar, slaap, feest, solo, mood, a new loopNaar/stappen) or the animal leaves the room.
   - `ctx.wereld.stappen(id, punten, {pose, tempo, perStap}) → Promise<boolean>`: visits the points in order; `perStap(i, punt)` called on each landing; same supersede semantics; resolves true after the last point.
   - `ctx.wereld.pose(id, naam, duur?)`: set a pose (thin wrapper over zet) for names the engine handles.
   - New poses: `zwem` — body bobbing at water level with the belly at the surface (lift so the animal sits low; the legs may be hidden by the water because the pool floor is drawn below; add 2–3 light splash voxels or a ripple if cheap), and `spring` — a parabolic lift between consecutive points with a tiny squash on landing (used by stappen with pose 'spring'). Poses are handled in world.js (~275-345 at 25a4b52) as combinations of existing art poses; do not edit art.js.
   - Reduced-motion mode (rustModus): teleport to the target(s) and resolve immediately (true), calling perStap for each point.
   - Tempo: `tempo` multiplies the room's walking speed (rooms have a `loop` factor since 710003e); default 1.
2. Do not break sleeping: the sleep fix (Dier.inZijnBed, slaapDoel consumed on arrival, stilzetten keeping sleepers in bed) lives in the same class; `.fanout/scratch/dierenhotel/slaap.js` must remain 124 PASS / 0 FAIL against your worktree.
3. Suite .fanout/scratch/dierenhotel/p1c.js (port + land, ≥35 assertions): loopNaar resolves true on arrival and the animal is within 1 voxel of the target; a second command mid-walk resolves the first promise false and the second true; stappen visits 5 points in order with perStap called 5 times and pose spring showing lift > 0 mid-hop and lift 0 after landing; pose zwem keeps the animal low (lift < 0) while moving and lift 0 after pose reset; rustModus resolves immediately with perStap counts; tempo 2 arrives in about half the time; no console errors; screenshots p1c-spring.png and p1c-zwem.png (mid-motion, 420×860). Existing suites smoke, loop (port+land), w1 (port+land), slaap.js stay green against your worktree (override hard-coded main-tree URLs locally; do not change their defaults).
4. .fanout/specs/api-p1c.md in your worktree: signatures, semantics (supersede rules, rooms, reduced motion), pose names and what they look like, timing model.

CONTEXT
Repo /home/pc/Documents/xnw/rkn; isolated git worktree branched from main at af8ab32 (rooms 1.5× with per-room scale — HOTEL.md §1; guests sleep on beds). Vanilla JS, offline, no build. Playwright at /home/pc/work/ergomouse/node_modules/playwright; harness patterns in .fanout/scratch/dierenhotel/ (slaap.js, k1.js, tobbe/spel.js). .fanout/scratch is gitignored: write your suite under your worktree's .fanout/scratch/dierenhotel/ and copy it plus screenshots to /home/pc/Documents/xnw/rkn/.fanout/scratch/dierenhotel/ at the end. Do not edit GAMES-API.md. Hard rules: HOTEL.md §9 (never punishing, soft animals). No new dependencies; no blanket pkill; you do not spawn agents; do not commit. Parallel tickets in their own worktrees edit world.js drawing/cache regions (runtime decor), world.js RUST line, rooms.js, hotel.js, art.js, state.js. Keep your hunks inside the Dier class / World movement functions and one extension block; add new functions instead of rewriting existing ones so merges stay clean.

MUST NOT
Change camera/scale code, drawing/plate cache, RUST, rooms.js, art.js, hotel.js, state.js, any game, registry.js.

WRITE SET
demos/dierenhotel/world.js (Dier class, World movement functions, one CTX_UITBREIDINGEN block), .fanout/specs/api-p1c.md, scratch suite + screenshots.

OUTPUT FORMAT
First line DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED; then ≤30 lines: signatures and semantics, file:line hunks, suite numbers, screenshots, worktree path/branch, concerns.