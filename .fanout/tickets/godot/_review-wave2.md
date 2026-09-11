# Common review brief for a wave-2 game (read with the game's ticket)

TASK
Review the worktree branch named in your dispatch message against the game's ticket (.fanout/tickets/godot/g-<id>.md), the common contract (_gemeenschappelijk-wave2.md), the game's spec section (games-a.md or games-b.md) and architecture.md §1.1/§4/§6/§12.2. Grade the change, not the worker's narrative. The worker's report is summarised in the ledger (.fanout/ledger.md, section "Run dierenhotel-godot", entry "G-<id>").

FOCUS
1. Frozen content: every child-facing string of the spec present verbatim (script the diff); generators called from Sommen, never re-implemented (grep for arithmetic that duplicates a generator); the band rules (groep 3/4/5) honoured; the never-punishing rule and help ladder as specified; owner's rules where the spec marks them.
2. Play it: export from a pristine copy of the worktree, drive one full turn per band in chromium (the worker's driver under .fanout/scratch/godot-g-<id>/ may be reused but verify it really taps the game's controls and asserts outcomes, not just log lines); screenshot at 1024×768@2 and 360×740@3 and look at them: is anything covering the guest, the object, the card; are the ≥ 48 px and 12 px rules met; does the card fit on one line.
3. Lifecycle: reload mid-turn restores from ctx.data(); stop()/supersede leaves no decor, hotspots or moved guests behind (assert World.decor_lijst empty and the guest's room/pose sane); the game registers via the scan and appears on the prikbord/hotspot per its row.
4. Write set: `git diff --stat main...<branch>` touches only games/<id>/** (plus the single allowed test file location); no autoload edited.
5. Tests: run tools/test.sh in the copy with an isolated XDG_DATA_HOME; list any red test and whether it is the game's or cross-cutting (the known cross-cutting red is test_hotel morgen for wish-granting games).
6. Grade the worker's concerns and contract gaps: real / cosmetic / wrong.

CONSTRAINTS
Read-only against the repo and the worktree; work on an rsync copy for anything that writes. No edits, no subagents, no blanket kills.

OUTPUT FORMAT
Verdict word first (LOOKS_GOOD / FIX_FIRST / REWORK), then findings ranked BLOCKING / SHOULD-FIX / NIT with file:line, then check results with counts and exit codes, then the graded concerns. At most 30 lines.
