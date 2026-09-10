# R-W3W6 — Preliminary review of W3 (UI shell) and W6 (CI + Pages)

TASK
Review the wave-1 work of tickets W3 (.fanout/tickets/godot/w3-ui.md) and W6 (w6-ci.md) against their tickets, architecture.md and the specs. They meet at the probe (tools/probe.js drives the shell W3 built) and at the export (fonts and resources must be packed by the frozen preset).

EXPECTED OUTCOME (focus)
1. Tablet layout, in the browser: run tools/probe.js from your copy at 1024×768@2, 768×1024@2, 1280×800@2, 360×740@3 and 740×360@3; open the screenshots in .fanout/scratch/godot-w3/ and yours; judge against HOTEL.md §9 and art-sound-rules.md §16: key sizes ≥ 48 px (44 below 360), 12 px text floor, cards ≤ 8 words / 40 chars on one line at phone width, nothing covering the guest or the object, safe areas, compact landscape rail. Report measured numbers where a rule is close.
2. Strings: diff ui/teksten.gd against world.md §7 mechanically (script it); every string verbatim, none missing, none invented.
3. Fonts: confirm the emoji subset covers every emoji used in the four specs (script the set difference); confirm Dutch diacritics render; confirm the OFL licence files are shipped or state the exact preset diff needed.
4. Hits contract for wave 2: W3 notes that object rectangles are learned only from spots with a vlak, so hotel buttons (W2) bind no rule. Decide whether that is a hole a game worker will fall into; if so, name the fix and the owner.
5. Gate holes: W3 found that a test file with a parse error is silently skipped by run_tests.gd (176 goed, 0 fout). Reproduce in your copy and state the fix (owner W5's runner or W6's tools/test.sh grep).
6. The save-does-not-survive-browser-reload observation (user:// on the web is IndexedDB and needs a flush or a sync call): reproduce with the probe (write a save, reload, check) and assign it.
7. CI (W6): read both workflows and the tools; confirm test.yml would fail on a test failure and on a SCRIPT ERROR line, that pages.yml has the right permissions/concurrency, that the pinned checksums match toolchain.md, that the stripped-template trick is sound, and that the probe is not needed in CI. Run actionlint.
8. Run: import, tools/test.sh, export, probe; report counts and exit codes.

CONTEXT
Repo /home/pc/Documents/xnw/rkn, Godot project godot/dierenhotel (Godot at ~/.local/bin/godot). Baseline commit 680f1a5 (skeleton); the wave-1 work is uncommitted in the working tree. The binding design is .fanout/specs/godot/architecture.md; behaviour specs .fanout/specs/godot/{world,art-sound-rules,toolchain}.md; HOTEL.md §9 binding. The ledger .fanout/ledger.md (section "Run dierenhotel-godot") summarises every worker report including their own concerns; grade those concerns (real / cosmetic / wrong). Two other reviewers cover W1+W4 and W2+W5 concurrently; do not duplicate them. The owner allows deviations from the HTML behaviour except architecture.md §1.1.

CONSTRAINTS
Read-only against source: work on a pristine rsync copy for anything that writes. You may run godot headless, node, python, actionlint. Do not edit repo files. Do not spawn subagents. No blanket process kills.

OUTPUT FORMAT
Verdict word first (one per workstream), then findings ranked BLOCKING / SHOULD-FIX / NIT with file:line and a one-line reason, then the check results with exit codes and counts. At most 35 lines. Nothing else.
