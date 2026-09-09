# W6 — CI and GitHub Pages

TASK
Create the GitHub Actions workflows from architecture.md §7.4: one that runs the headless import, the tests and the web export on every push and pull request, and one that exports the web build and publishes it to GitHub Pages from main. Plus the local helper scripts under `tools/` at the repo root (import, test, export, serve, probe); note that `godot/dierenhotel/tools/test.sh` already exists and belongs to W5, so your `tools/test.sh` wraps it rather than duplicating it so that a developer runs the same commands as CI.

EXPECTED OUTCOME
- `.github/workflows/test.yml`: ubuntu-latest, Godot 4.7.2 downloaded and cached (binary + export templates, checksums from toolchain.md), import, tests, export; fails on any ERROR line or test failure; artifact upload of build/web.
- `.github/workflows/pages.yml`: on push to main (and manual dispatch), export with the Web preset, upload-pages-artifact, deploy-pages with the required permissions and concurrency group; a note in the workflow header on the one-time repo setting (Pages source = GitHub Actions).
- `tools/import.sh`, `tools/test.sh`, `tools/export.sh`, `tools/serve.sh` (python http.server on 8642 from build/web), `tools/probe.js` (the chromium/swiftshader probe from architecture.md §14.4, parameterised by viewport); all executable, all documented in `tools/README.md`.
- Validate the workflows locally as far as possible: run every step's command locally with the same flags; lint the YAML (python -c yaml load, or actionlint if available offline); dry-run the Godot download step's URLs with curl -I. Do not push anything.
- Also: `.gitignore` at the repo root gains the Godot entries if missing (`.godot/`, `godot/dierenhotel/build/web/`).

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
.github/workflows/test.yml, .github/workflows/pages.yml, tools/**, the repo-root .gitignore only. Specs: toolchain.md, architecture.md §7.3–§7.4, §14.
