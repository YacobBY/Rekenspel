# R-W2W5 — Preliminary review of W2 (hotel, economy, save) and W5 (frozen math core)

TASK
Review the wave-1 work of tickets W2 (.fanout/tickets/godot/w2-hotel.md) and W5 (w5-sommen.md) against their tickets, architecture.md and the specs. These meet at the generators the hotel calls (band, tel, deel/geld/klok/tafel, buidel/splits) and at the test runner, so grade the seam as well as each side.

EXPECTED OUTCOME (focus)
1. Hotel logic against world.md §3–§4: trace morgen() over the 8-day worked trace yourself from the code (not from the tests), the nieuweWensen days 3/5/7, the check-in flow, the bill's three steps and the help ladder, the prikbord cap and rotation. Flag any step whose order differs from the spec without a documented reason.
2. Save format against architecture.md §9: every field present, atomic write, the seven corrupt cases, mid-bill reload. Try two corrupt files of your own making.
3. W2's own concerns: tik_mand without World.mood; wens_af(id,"kamer") literal per Q-X1-8; bill sheet no longer waiting 1100 ms. Grade each: keep, fix, or ask the owner.
4. The known integration bug: State.alle_bedden() guards on Rooms.has_method("slots") while W1 ships slots_van, so max_gasten() is 0 and check-in is blocked, and four test_hotel tests assert a bedless hotel. Confirm, and state the exact fix and which tests must change. Look for more unresolved cross-autoload calls from hotel.gd/econ.gd/state.gd (grep every Rooms./World./Ui./Snd./Art. call site against the actual method lists).
5. Math core: verify the byte-identity harness (.fanout/scratch/w5/: bouw_harnas.py, harnas.js, vergelijk.py) is honest: the JavaScript is lifted from demos/dierenhotel by line range, and the comparison covers every generator the ten games need (list any generator in games-a.md/games-b.md that is NOT in the sweep). Re-run the comparison. Check the JsGetal semantics for the 53-bit rounding case and the |0 / >>> 0 cases by reading the code.
6. Runner: the verwacht_fout hatch and the await fix; confirm a coroutine test that fails is now reported (write a throwaway one in your copy) and that the announced-error budget cannot hide an unrelated error.
7. Run: import, tools/test.sh, export from your copy; report counts and exit codes and the suite time.

CONTEXT
Repo /home/pc/Documents/xnw/rkn, Godot project godot/dierenhotel (Godot at ~/.local/bin/godot). Baseline commit 680f1a5 (skeleton); the wave-1 work is uncommitted in the working tree: `git status` and `git diff` against HEAD show it. The binding design is .fanout/specs/godot/architecture.md; the behaviour specs are .fanout/specs/godot/{world,games-a,games-b,art-sound-rules}.md; HOTEL.md §9 is binding. The ledger .fanout/ledger.md (section "Run dierenhotel-godot") has every worker report summarised, including their own concerns; grade those concerns too (real / cosmetic / wrong). The owner allows deviations from the HTML behaviour except architecture.md §1.1. Another reviewer covers the other workstreams concurrently; a third (W3 UI + W6 CI) starts when W3 lands, so the tree may still change under you in W3 files only (autoload/ui.gd, hits.gd, games.gd, spel/ctx.gd, scenes/main.*, ui/**, fonts/**).

CONSTRAINTS
Read-only against source: work on a pristine rsync copy of the tree if you run anything that writes (imports, exports). You may run godot headless, node, python. Do not edit repo files. Do not spawn subagents. No blanket process kills.

OUTPUT FORMAT
Verdict word first (LOOKS_GOOD / FIX_FIRST / REWORK, one per workstream), then findings ranked BLOCKING / SHOULD-FIX / NIT with file:line and a one-line reason, then the check results with exit codes and counts. At most 35 lines total. Nothing else.
