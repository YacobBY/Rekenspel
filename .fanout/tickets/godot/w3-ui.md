# W3 — UI shell: start screen, HUD, room bar, cards, keypad, choice strip, hotspot layer, fonts

TASK
Implement the user-facing shell of the Godot project: start screen, HUD (stars, day, coins), room navigation bar, the som card, the wolk (speech cloud), bron/getal_tag, the keypad band and the choice strip, sheets/toasts, the hotspot button layer on the band grid (Hits), the game registry and SpelCtx wiring, fonts and emoji rendering for the web export (architecture.md §7.5), safe areas and orientation handling, audio unlock on first tap, and the main scene composition that keeps 1 unit = 1 CSS px on every resize (architecture.md §4).

EXPECTED OUTCOME
- All world strings from world.md §7 present verbatim on their screens.
- Keypad: ≥ 48 px keys (44 only when the short side is below 360 px), single-fire taps, answer box contract from world.md §5 and architecture.md §4.4; works in portrait and landscape at 1024×768, 768×1024, 1280×800, 360×740 and 740×360.
- Cards obey F4 (≤ 8 words, ≤ 40 characters), never cover the guest or the object they belong to (structural placement per §4.4), 12 px text floor everywhere.
- Hotspot buttons: 0 % coverage of every object in every room in the five frame sizes above, proven by a headless test that walks every room's decor through Hits.
- Registry: directory scan finds every `res://games/*/spel.tscn` both in the editor tree and inside the exported PCK (the skeleton probe covers this; keep the test). Note: `Ui.somkaart` is already real after the A1 fix batch, minus the keypad; build on it rather than restarting. The `ui/` directory does not exist yet; you create it.
- Fonts: a bundled open-licence font with Dutch diacritics and the emoji used by the game (list them from the specs) rendering in the web export; measure that the longest card string fits one line at the phone width.
- Tests: hits coverage, card fit, keypad size rules per viewport, registry scan. Browser probe (§14.4) at the five sizes with 0 console errors; screenshots saved under .fanout/scratch/godot-w3/.

CONTEXT
Repo /home/pc/Documents/xnw/rkn. The Godot 4.7.2 project is `godot/dierenhotel/` (Godot at ~/.local/bin/godot). Read first: `.fanout/specs/godot/architecture.md` in full (it defines every contract, the skeleton file by file in §11, your ticket in §12.1, the answered open questions in §13, and the exact verification commands in §14). Then the wave-0 specs named below. The HTML original in `demos/dierenhotel/` is the reference implementation; read it only to settle a contradiction between specs, and never copy its DOM-measurement machinery. Binding, non-negotiable: architecture.md §1.1 (frozen math, owner rules, verbatim strings, HOTEL.md §9 design rules). Everything else may be done the Godot way; the owner explicitly wants improvements where Godot offers them.

CONSTRAINTS
- Touch only the files in your WRITE SET. `project.godot`, `export_presets.cfg` and `tests/run_tests.gd` are frozen; if you need a change there, report it as a concern with the exact diff instead of applying it.
- Five other workers edit disjoint files of the same tree at the same time. Do not run `git add`, `git commit`, `git stash` or `git checkout`. Do not delete `.godot/`; if you must re-import, run `godot --headless --import --path godot/dierenhotel` and accept that another worker may be importing too (retry once on a lock error).
- Keep the `# Wn` markers of other tickets intact; remove only your own.
- Dutch child-facing strings verbatim from the specs; code identifiers and comments in the style of the skeleton (Dutch identifiers, precise English or Dutch comments, either is fine, be consistent within a file).
- No blanket process kills; close only browsers you launch.

MUST DO
- Write headless tests under `tests/` for your ticket (the runner picks up `tests/test_*.gd` automatically) and keep the whole suite green: `godot --headless --path godot/dierenhotel --script res://tests/run_tests.gd`.
- Before reporting, run the full check: import (0 ERROR lines), tests (0 fout), export (0 ERROR lines), commands in architecture.md §14. Paste exit codes and counts in the report.
- Keep the interfaces in architecture.md §4–§6 stable; if you find a contract that cannot work, implement the smallest correct change, document it in a short "Contract changes" list in your report, and update the corresponding paragraph of architecture.md (that one file is a shared write exception for contract fixes only: edit surgically, never rewrite sections).

MUST NOT
- Do not spawn subagents. Do not port any minigame (wave 2). Do not touch `demos/`, the ledger, or tickets.

OUTPUT FORMAT
Open with exactly one status: DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT or BLOCKED. Then at most 25 lines: what was built, the check results with exit codes and counts, contract changes (if any), and concerns. Do not paste diffs.

WRITE SET
godot/dierenhotel/autoload/ui.gd, autoload/hits.gd, autoload/games.gd, spel/ctx.gd, spel/minigame.tscn, scenes/main.tscn, scenes/main.gd, ui/**, fonts/**, icon.svg, tests/test_ui.gd, tests/test_hits.gd, tests/test_games.gd, and .fanout/scratch/godot-w3/** only. Do not edit spel/minigame.gd (its API is frozen for wave 2; report needed changes). Specs: world.md §5–§7; art-sound-rules.md §style/layout, §checklists, §tablet; architecture.md §4, §6, §7.5, §10.
