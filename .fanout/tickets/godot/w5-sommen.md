# W5 — The frozen number core, complete

TASK
Finish `core/sommen.gd` and `core/jsgetal.gd`: port every frozen function in games-a.md and games-b.md that the skeleton does not yet have (the planbord solver planOplossingen/planFouten/maakPlan, the sleutels LCG and kiesBlanco, koekjesSom, vergelijk, deel/geld/klok/tafel, somDeel/somTafel/recept, the zwembad baan()/keuzeGetallen(), wekker doelTijd/afstand/duurKeuzes/tijdWoord, hinkel beurt()/matenVoor/keuzeGetallen, was kiesT/verdeel, kraam opzet()/keuring(), econ buidel/splits, and any other generator the ten wave-2 games need) with JavaScript integer semantics reproduced exactly (architecture.md §2.1), so that wave-2 workers only call these functions and never re-implement math.

EXPECTED OUTCOME
- Every function listed in games-a.md and games-b.md as frozen or as a generator exists in `Sommen` with the signature style of architecture.md §2.3, documented with its spec reference.
- Tests assert every worked example in the specs, the Node-verified tables in games-b.md (zwembad 43 → 43,13,20,30; wekker 14 cases; hinkel 9; was 9; kraam sweep band 3–5 × N 1–12 × dag 1–12 = 432 combos with 0 complaints), the Python worked examples in .fanout/scratch/games-a-worked-examples.txt, and the dagRnd 53-bit rounding case (678745088). Where a spec is ambiguous, settle it by running the original JavaScript with node (allowed for this ticket only, read-only) and record the case in the test.
- The runner stays under a minute; report its time.
- The runner now fails on any push_error; add a `verwacht_fout` escape hatch to `tests/proef.gd` so a test can deliberately exercise an error path (e.g. `Art.registreer_model` rejecting a world-model name) without failing the suite, and document it in architecture.md §2.4.

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
godot/dierenhotel/core/sommen.gd, core/jsgetal.gd, core/** (new files allowed), tests/test_sommen.gd, tests/test_sommen_*.gd (new), tests/proef.gd, tests/run_tests.gd (yours now: keep the engine-error logger and the non-zero exit on script errors), godot/dierenhotel/tools/test.sh only. Specs: games-a.md §2 and every generator section, games-b.md §0 and every generator section, world.md §3 generators, architecture.md §2.
