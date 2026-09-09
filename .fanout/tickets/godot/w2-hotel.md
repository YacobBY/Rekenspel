# W2 — Hotel: day cycle, economy, wishes, check-in, prikbord, save

TASK
Implement the hotel logic in the Godot project: the day cycle and morgen() steps, wishes and the nieuweWensen algorithm, check-in, feeding and playing, the bill flow, stars/coins/letters, the prikbord with its 3-chip cap and fair rotation, the HUD data, the band and sum generators that live in the hotel (world.md §3), and the save document (architecture.md §9: every field, atomic write, corrupt file → start screen, versioned from 1).

EXPECTED OUTCOME
- `Hotel`, `Econ` and `State` autoloads fully implemented per world.md §3–§4 and architecture.md §5, §9, with every signal listed there emitted at the right moment.
- Save/load round-trips every field; a corrupt or truncated file leads to the start screen with no crash; a save written mid-bill restores the bill (architecture.md §13 decision on the X1 open question about bill state).
- Wishes: the distribution and timing from world.md §3 reproduced; a completed wish awards exactly what the spec says; wish chips keep order on the prikbord; game chips with prio ≥ 5 rotate round-robin by day under the 3-chip cap.
- Tests: morgen() sequence over 8 days for 3 guests traced against world.md's worked trace; nieuweWensen for days 3/5/7; buidel(13) = [5,2,2,2,1,1]; deel(5,4,2) = k 10, r 1, T 51; geld(band 5, day 4) = 2×4 = 8, paid 10, change 2; prikbord rotation over 6 days; save round-trip and 4 corrupt-save cases.
- Logic is tested through State and signals, not pixels. Where Ui or World are not yet real (skeleton stubs), code against the documented signatures; do not stub them yourself in shared files.

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
godot/dierenhotel/autoload/hotel.gd, autoload/econ.gd, autoload/state.gd, tests/test_hotel.gd, tests/test_econ.gd, tests/test_state.gd, and new files under godot/dierenhotel/hotel/** only. Specs: world.md §3, §4, §5 (reward, taak_klaar), §7 strings; architecture.md §5, §9, §13.
