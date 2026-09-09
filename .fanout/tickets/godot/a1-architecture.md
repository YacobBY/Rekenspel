# A1 — Architecture of the Godot port, plus the skeleton project that proves it

TASK
Design the architecture of the Godot 4.7 rebuild of Dierenhotel and write it down as `.fanout/specs/godot/architecture.md`, then create the skeleton project under `godot/dierenhotel/` that embodies the architecture: project settings, autoloads, base classes, directory layout, export preset, and one running placeholder room, exporting headlessly to the web with zero errors. Later workers (one ticket per subsystem, then one per minigame) will build on your skeleton and read only your document plus the wave-0 specs, so the document must define every contract they need.

EXPECTED OUTCOME
1. `.fanout/specs/godot/architecture.md` (precise prose, diagrams as indented text or tables), covering at least:
   a. Goals and freedoms. The owner said: "De game hoeft niet exact te werken als nu. Als Godot verbeteringen biedt implementeer die dan. Ik merkte dat de HTML versie tegen beperkingen aanliep." Parity is binding for: curriculum bands and generators (the frozen math, byte-identical outputs for the same inputs), the owner's zwembad rules, all child-facing strings, and the HOTEL.md §9 / GAMES-API §9 design rules (target sizes, text floors, never punishing, in-world math, ≤ 6 words). Everything else may be rebuilt the Godot way. List explicitly which HTML mechanisms are replaced by Godot features (layout bus, hits.js measurement and 4-round evasion, padPlek, per-game frame-width thresholds, density cap, redraw-on-change, DOM card placement) and which limitations of the HTML version the port removes.
   b. Rendering approach for the voxel art: decide between (i) a GDScript voxel baker that renders the models from art-sound-rules.md into ImageTextures once per plate size at startup or on demand, (ii) Node2D _draw per model, (iii) pre-baked sprite sheets from the extractor. Justify by the X4 findings (parameterised models, non-integer plate scaling, 40 MB wasm baseline, tablet memory). State the projection and camera model, z-sorting, room scenes, and how guests, decor and runtime decor are nodes.
   c. Resolution and layout for tablets and phones: base viewport size, stretch mode/aspect, orientation handling (portrait and landscape both supported), safe areas, how the keypad and cards are laid out with Control containers instead of measured placement, how the 0 % coverage rule for hotspot buttons is achieved structurally (e.g. reserved bands above/below objects) rather than by iterative evasion. Give the concrete numbers.
   d. Scene tree and autoloads: e.g. State (save/load), Hotel (day cycle, economy, wishes, prikbord), World (rooms, guests, movement with awaitable signals or coroutines instead of promises), Ui (start screen, HUD, cards, keypad), Snd (procedural sounds generated into AudioStreamWAV at startup from the parameters in art-sound-rules.md, or pre-generated files, decide), Games (registry by directory scan of `res://games/*/game.gd` or a static list, decide, with the constraint that adding a game must not require editing a shared file so ten game workers can run in parallel in worktrees without merge conflicts).
   e. The game contract in GDScript: a base class `MiniGame` (scene + script) with the lifecycle start/klaar/stop/supersede/evening, what the game receives (band, guest, room, day, save slot), the services it may call (world movement, decor, hotspots, cards, keypad, sounds, reward), and how it persists in-progress state. Signals and method signatures written out. Include a worked example: the sequence of calls for one wekker turn.
   f. The math core: one script `res://core/sommen.gd` (name it as you see fit) that ports every frozen function from games-a.md and games-b.md with identical integer semantics (24-bit dagRnd, 32-bit sleutels LCG with JS `|0` and `>>> 0` behaviour reproduced exactly using GDScript int masking), plus a test file that asserts the worked examples in the specs. Decide the test framework (GUT or GdUnit4, vendored under `addons/` or a minimal home-grown headless runner via `godot --headless -s`) with the constraint that tests must run in CI on ubuntu-latest and locally in under a minute.
   g. Save format: a new JSON document in `user://` with the same semantic fields as save v7 (list them), versioned from 1, no migration from the HTML saves (different origin), corrupt file → start screen.
   h. Input: touch first (Emulate mouse from touch off, emulate touch from mouse on for desktop testing), drag semantics for the games that drag (voerkar, meubels, kraam coins: check the specs), single-fire taps, ≥ 48 px targets.
   i. Web export specifics from toolchain.md: preset keys, PWA, `build/.gdignore`, threads off, the headless import+export commands, and the plan for the GitHub Actions workflow (export + deploy-pages) and for running the tests in CI.
   j. The ticket plan for the next waves: wave 1 subsystem tickets with disjoint write sets (proposed: W1 world+rooms+guests+movement, W2 hotel day cycle+economy+wishes+prikbord+save, W3 UI shell+cards+keypad+HUD+start screen, W4 art baker+sounds, W5 math core+tests, W6 CI workflow+Pages), and wave 2 with one ticket per game (bedden, sleutels, meubels, tobbe, voerkar, zwembad, wekker, hinkel, was, kraam) each confined to `res://games/<id>/`. Name for each ticket the interfaces it depends on and which stubs your skeleton provides so the wave-1 tickets can run in parallel.
   k. Open questions from the four wave-0 specs (world.md §8, games-a.md, games-b.md, art-sound-rules.md): give a decision for each one, or state that it is delegated to a named ticket.
2. The skeleton at `godot/dierenhotel/`: `project.godot` (Compatibility renderer, viewport/stretch settings, autoloads, touch settings, application name "Dierenhotel", main scene), `export_presets.cfg` (Web preset per toolchain.md), `build/.gdignore`, `.gitignore` (`.godot/`, `build/web/`), directory layout with the autoload scripts as real but minimal implementations (signals and method signatures present, bodies stubbed with clear `# W1` style markers naming the ticket that fills them), the `MiniGame` base class, one placeholder game under `games/_voorbeeld/` that exercises the contract, the test runner with one passing test, and a main scene that shows a placeholder room with a tappable guest that walks. Headless import and export must succeed with zero `ERROR:` lines, and the export must load in chromium (Playwright at /home/pc/work/ergomouse/node_modules/playwright with the swiftshader flags from toolchain.md) with zero console errors on a 1024×768 touch viewport. Record the exact verification commands in the document.

CONTEXT
Repo: /home/pc/Documents/xnw/rkn. Read first, in this order: `.fanout/specs/godot/toolchain.md`, `.fanout/specs/godot/world.md`, `.fanout/specs/godot/art-sound-rules.md`, then skim `.fanout/specs/godot/games-a.md` and `.fanout/specs/godot/games-b.md` for the contract needs of the games (§0 of each, plus the launch, layout and open-question sections). `HOTEL.md` §9 is binding. The ledger `.fanout/ledger.md` (section "Run dierenhotel-godot") holds the decisions so far. Godot 4.7.2 is at `~/.local/bin/godot` with export templates installed. The HTML game in `demos/dierenhotel/` stays untouched and is not to be read except to settle a contradiction between specs.

CONSTRAINTS
- Write set only: `.fanout/specs/godot/architecture.md`, `godot/dierenhotel/**`. Do not edit the ledger, the tickets, the demos folder, or `.github/`.
- GDScript only, no C#, no GDExtension.
- Renderer Compatibility; the web export must be single-threaded.
- Keep the skeleton small: interfaces and one vertical slice, not features.
- Do not run any blanket process kills; close only the browsers you launch.

MUST DO
- Every contract that a wave-1 or wave-2 worker needs must be in the document with signatures; a worker must never have to guess.
- Run: `godot --headless --import --path godot/dierenhotel`, then the export, then the test runner, then the browser probe; paste the exact commands and their exit status into the report and the document.
- Commit nothing; leave the working tree with your files added but uncommitted.

MUST NOT
- Do not spawn subagents.
- Do not port any minigame or any real world content beyond the placeholder slice.
- Do not weaken the binding rules listed under 1a to make the design easier.

WRITE SET
.fanout/specs/godot/architecture.md, godot/dierenhotel/** (new directory).

OUTPUT FORMAT
Open with exactly one status: DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT or BLOCKED. Then at most 30 lines: the key decisions (rendering path, resolution/stretch, registry mechanism, test framework), the verification commands with their results, the proposed wave-1 and wave-2 ticket list with write sets in one compact table, and concerns.
