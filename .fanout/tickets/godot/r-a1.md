# R-A1 — Preliminary review of the architecture and skeleton

TASK
Review the output of ticket A1 (`.fanout/tickets/godot/a1-architecture.md`): the document `.fanout/specs/godot/architecture.md` and the skeleton project `godot/dierenhotel/` (all staged, uncommitted; `git diff --cached --stat` lists it). Sixteen later tickets (six subsystems, ten minigames) will be built on it in parallel, so a design flaw here multiplies. Grade the change, not the worker's narrative.

EXPECTED OUTCOME
A brief of at most 30 lines, opening with LOOKS_GOOD, FIX_FIRST or REWORK, then findings ranked BLOCKING / SHOULD-FIX / NIT, each with file:line and a one-line reason. Focus on:
1. Contract completeness: can a wave-2 game worker implement, say, wekker (games-b.md §2) using only architecture.md §4–§6 and the skeleton, without guessing? Name any missing signature, signal or service.
2. Parallel safety: are the wave-1 write sets in §12.1 truly disjoint and are the shared files (project.godot, export_presets.cfg, run_tests.gd) really untouched by the wave-1 tickets as planned? Does the registry-by-directory-scan actually work inside a PCK (the worker claims a probe proved it; check the code path).
3. The JS integer semantics in `core/jsgetal.gd` and `core/sommen.gd`: verify at least three frozen functions against games-a.md / games-b.md by hand or with a quick Python replica, including the `dagRnd` 53-bit rounding claim (678745088 vs 678745307) — check it against the actual JavaScript in `demos/dierenhotel/state.js:380-386` by running node.
4. The layout claims in §4: 1 unit = 1 CSS px, band grid 0 % coverage, SubViewport density. Are they sound for 1024×768 landscape, 768×1024 portrait, and a 360×740 phone? Flag anything that breaks the ≥ 48 px target rule or the 12 px text floor.
5. Binding rules (architecture.md §1.1, HOTEL.md §9): any place the design quietly weakens them.
6. Run the deterministic checks yourself and report exit codes: headless import, tests, export (commands in architecture.md §14).

CONTEXT
Repo /home/pc/Documents/xnw/rkn. Godot at ~/.local/bin/godot. Specs in .fanout/specs/godot/. Ledger section "Run dierenhotel-godot" in .fanout/ledger.md has the decisions. The owner allows deviations from the HTML behaviour except for the frozen items in §1.1.

CONSTRAINTS
Read-only against source; you may run godot headless and node. Do not edit files. Do not spawn subagents. No blanket process kills.

OUTPUT FORMAT
Verdict word first, then the ranked findings, then the three check results with exit codes. Nothing else.
