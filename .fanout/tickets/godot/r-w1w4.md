# R-W1W4 — Preliminary review of W1 (world) and W4 (art baker + sounds)

TASK
Review the wave-1 work of tickets W1 (.fanout/tickets/godot/w1-world.md) and W4 (w4-art-snd.md) against their tickets, architecture.md and the specs. These two workstreams meet at the Art API (every plate the world draws) and at the floor rendering, so grade the seam as well as each side.

EXPECTED OUTCOME (focus)
1. World correctness against world.md §1–§2: pick three rooms and verify sizes, door points, decor positions and the plek constants in the code and tests; verify the movement semantics (supersede, slot exclusivity, speed) by reading the coroutine code and running the tests; check the idle, sleep and morning rules; check reduced motion and hidden-tab pause.
2. The Art seam: does every model name the world requests exist in the baker (grep the request sites against the registry)? Are the plate anchors (§3.3) applied consistently by dier.gd, wereldobject.gd and the loose decor path? The 💤 placement and the rabbit lig pose concerns from W1: real or not, and whose file.
3. Floor rendering duplication (Art.vloer_plaat vs the ArrayMesh in vloer.gd): recommend one owner.
4. Baker fidelity and cost: read the golden-oracle table .fanout/scratch/w4/gouden-verschil.txt and spot-check two plates visually (render to PNG headlessly using the tools in tests/gouden/); judge whether the revised §3.6 tolerance is honest or a moved goalpost; judge the per-plate cost miss (hok 23 ms) against the room-level budget that does hold.
5. Sounds: verify three synthesis parameter sets against art-sound-rules.md; confirm the klok throttle; confirm no sound plays before the audio unlock.
6. Integration bugs already known: State.alle_bedden() guards on Rooms.has_method("slots") while W1 ships slots_van (check-in blocked); games/_voorbeeld names proefkamer/proef_blok. Confirm and assign to a workstream. Look for more of this class: any call from hotel.gd/econ.gd/state.gd into Rooms/World that does not resolve (grep every Rooms. and World. call site against the method lists).
7. Run: import, tools/test.sh, export, and the W1 probe (.fanout/scratch/godot-w1/probe.js) from your copy; report counts and exit codes.

CONTEXT
Repo /home/pc/Documents/xnw/rkn, Godot project godot/dierenhotel (Godot at ~/.local/bin/godot). Baseline commit 680f1a5 (skeleton); the wave-1 work is uncommitted in the working tree: `git status` and `git diff` against HEAD show it. The binding design is .fanout/specs/godot/architecture.md; the behaviour specs are .fanout/specs/godot/{world,games-a,games-b,art-sound-rules}.md; HOTEL.md §9 is binding. The ledger .fanout/ledger.md (section "Run dierenhotel-godot") has every worker report summarised, including their own concerns; grade those concerns too (real / cosmetic / wrong). The owner allows deviations from the HTML behaviour except architecture.md §1.1. Another reviewer covers the other workstreams concurrently; a third (W3 UI + W6 CI) starts when W3 lands, so the tree may still change under you in W3 files only (autoload/ui.gd, hits.gd, games.gd, spel/ctx.gd, scenes/main.*, ui/**, fonts/**).

CONSTRAINTS
Read-only against source: work on a pristine rsync copy of the tree if you run anything that writes (imports, exports). You may run godot headless, node, python. Do not edit repo files. Do not spawn subagents. No blanket process kills.

OUTPUT FORMAT
Verdict word first (LOOKS_GOOD / FIX_FIRST / REWORK, one per workstream), then findings ranked BLOCKING / SHOULD-FIX / NIT with file:line and a one-line reason, then the check results with exit codes and counts. At most 35 lines total. Nothing else.
