# W1 — World: rooms, guests, movement, idle life, sleep

TASK
Implement the hotel world in the Godot project: all eight rooms from world.md §1 with their decor, doors and camera rules; the guest system from world.md §2 (species, palettes, poses, accessories, bowls, name plates); movement as awaitable coroutines (architecture.md §6.4: stappen, loop_naar, pose), idle wandering, sleeping on the bed with 💤, morning routine, the off-screen simulation, and the runtime decor API (registreer_model, decor, decor_plek). Replace the skeleton's placeholder room and guest with the real thing. Note: `World.decor*` is already implemented for real after the A1 fix batch; keep it working and build on it.

EXPECTED OUTCOME
- Every room in world.md §1 renders with the right size, floor and wall look, decor at the specified positions, doors and connections; `Rooms.lijst()` and `Rooms.get_kamer(id)` return real data; camera per room as specified.
- Four species with all fifteen poses via the `Art` baker (W4 delivers the baker; the skeleton already bakes six models and all four species in the poses listed in architecture.md §11 — code against `Art.plaat()` and register any missing model through `Art.registreer_model` in your own files; if a model is not yet bakeable, use the skeleton placeholder and list it in concerns).
- Movement: `await World.loop_naar(dier, kamer, punt)` walks along the door graph at the specified speed; `stappen` and `pose` per §6.4; two guests never occupy the same slot; a call supersedes a running one exactly as world.md describes.
- Idle rules, sleep (lying pose on the bed slot, rotated beds, 💤), morning routine, hidden-tab pause and reduced motion (architecture.md §13 decision) implemented.
- Tests: room data (sizes, door graph, plek constants recomputed as in world.md, e.g. plek('receptie',0.875,0.25) = 105,30), movement (a walk reaches its target within the expected tick count; supersede cancels), sleep placement, idle stays off reserved zones.
- The main scene shows the receptie with at least two guests walking and a room switch working, in the chromium probe (architecture.md §14.4) with 0 console errors on 1024×768 and 768×1024.

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
godot/dierenhotel/autoload/rooms.gd, autoload/world.gd, scenes/kamer.tscn, scenes/kamer.gd, scenes/vloer.gd, scenes/wereldobject.gd, scenes/dier.gd (new, if you want one), scenes/proef_modellen.gd (you delete it once real models exist), tests/test_skelet.gd (yours to adapt or replace), tests/test_rooms.gd, tests/test_world.gd, and new files under godot/dierenhotel/wereld/** only. Specs: world.md §0–§2, §6 (reduced motion, hidden tab), art-sound-rules.md for model names.
