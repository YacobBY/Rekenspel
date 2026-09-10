# Common contract for every wave-2 game ticket (read with your game's ticket)

CONTEXT
Repo /home/pc/Documents/xnw/rkn, Godot 4.7.2 at ~/.local/bin/godot, project godot/dierenhotel. You work in your own git worktree (the harness created it); the main tree is off limits. Read in this order: your game ticket; `.fanout/specs/godot/architecture.md` §1 (what is frozen), §2 (the math core: call `Sommen.<Spel>.*`, never re-implement generators), §3.3 (plate anchors), §4.3–§4.4 (hotspots, cards, keypad, choice strip), §6 (MiniGame, SpelCtx, movement, the wekker worked example), §8 (sounds), §12.2 (your row and the definition of done), §13 (decided open questions); then your game's section in games-a.md or games-b.md in full, plus its §0/§2 shared foundation; then `games/_voorbeeld/spel.gd` as the living example of the contract; then HOTEL.md §9 (binding). The HTML original in demos/dierenhotel/games/<id>.js may be read to settle a contradiction between specs, never to copy its DOM measurement or placement code.

WHAT PARITY MEANS HERE (owner's words: "De game hoeft niet exact te werken als nu. Als Godot verbeteringen biedt implementeer die dan.")
Binding: the curriculum per band (groep 3/4/5) and the generators (already in Sommen; use them), the owner's own rules where the spec marks them, every child-facing string verbatim, the never-punishing rule, the help ladder, HOTEL.md §9 (≤ 6 words in-world, ≤ 8 words / 40 chars on a card, ≥ 48 px targets, 12 px floor, icon with its word). Free: layout mechanics, animation, how cards and objects are placed, anything the HTML did only because of DOM limits. Prefer Godot-native means: tweens, AnimationPlayer, Control containers, the band grid, awaitable movement.

WRITE SET
`godot/dierenhotel/games/<id>/**` only: `spel.tscn` (root inherits `spel/minigame.tscn`), `spel.gd` (extends MiniGame), your own models registered as `<id>_<naam>` via `Art.registreer_model`, your own scenes/scripts, and `tests/test_<id>.gd` placed INSIDE your game folder as `games/<id>/test_<id>.gd` if the runner picks it up there (check `tests/run_tests.gd`; if it only scans `tests/`, put the file at `godot/dierenhotel/tests/test_<id>.gd` — that single file is then also yours). Nothing else. Never edit project.godot, export_presets.cfg, autoloads, core/, art/, ui/, spel/, scenes/, other games, tests of others, or architecture.md. If the contract is missing something you need, do not patch the autoload: implement a local workaround inside your folder, and report the exact missing signature under "Contract gaps" so the lead can add it centrally.

DEFINITION OF DONE (architecture.md §12.2)
The game registers by directory scan and shows on the prikbord/hotspot per your row; the turn plays at bands 3, 4 and 5; every string matches the spec verbatim; Hits.dekking is 0 % for every button on an object in four frame sizes (1024×768, 768×1024, 360×740, 740×360); the sum card obeys F4 (≤ 8 words, ≤ 40 chars, sentence present); a turn survives a reload from ctx.data(); stop() leaves the world clean (decor_wis_alles, guests returned, hotspots removed); the suite runs green headlessly.

TESTS (headless, in your test file)
At minimum: registration and launch conditions; one full turn per band driven through the ctx (answer via the keypad/strip API, not by calling internals); a wrong answer path with the help ladder and the never-punishing rule; the reload-from-ctx.data() case; stop() cleanliness; string assertions against the spec literals; and the four-viewport hotspot coverage check using Hits like tests/test_hits.gd does.

BROWSER PROOF
Export from your worktree (`mkdir -p build/web && godot --headless --path . --export-release "Web" build/web/index.html`, 0 ERROR lines) and drive one full turn per band in chromium with the repo probe conventions (tools/probe.js shows the flags and `[probe]` lines; write your own small driver if the generic steps do not reach your game; the swiftshader flags are in architecture.md §14.4). Save screenshots of the game at 1024×768@2 and 360×740@3 under `.fanout/scratch/godot-g-<id>/` in your worktree, and copy them to the same path under the main repo only if that directory does not exist yet (it is gitignored scratch).

CHECKS BEFORE REPORTING
`godot --headless --import --path .` (0 ERROR), `tools/test.sh` (0 fout), the export (0 ERROR), the browser proof. Commit your work on the worktree branch with a message starting "Dierenhotel Godot: <id>" (this is the one exception to the no-commit rule: the lead merges worktree branches). Do not push.

MUST NOT
Do not spawn subagents. Do not touch the main tree. Do not weaken a §1.1 rule. Do not implement any other game.

OUTPUT FORMAT
Status word first (DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED), then at most 25 lines: what was built, the check results with counts and exit codes, the branch name and commit, contract gaps, deviations from the spec with reasons, concerns. No diffs.
