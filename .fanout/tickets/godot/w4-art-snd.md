# W4 — Art baker and sounds

TASK
Complete the voxel art baker and the sound system of the Godot project: every model in art-sound-rules.md (4 guests × 15 poses with accessories, bowl, 33 decor models, floors and walls, particles, 💤, shadows, water band) bakes through `Art.plaat()` with the projection, shading, outline and rondAf rules of the spec; all 18 sounds are generated from the synthesis parameters into AudioStreamWAV at startup (or pre-generated, per architecture.md §8) and play through `Snd.<naam>()`.

EXPECTED OUTCOME
- `Art` bakes every named model at every plate scale g the world uses; the LRU stays within the bake budget of architecture.md §3.5; a cold bake of the receptie set completes within the time budget stated there (measure and report).
- Golden-image oracle: the extractor output in /tmp/dh-art/ (64 PNG, byte-exact from the HTML original; re-run `node /tmp/dh-art/extract.js` if missing) is compared against the Godot bake for at least the 20 most used plates; report the per-plate pixel difference; exact match is the goal, small documented deviations are acceptable when the Godot rendering is better (owner allows improvements) but each must be listed.
- Sounds: all 18 from art-sound-rules.md; a headless test asserts sample count, peak level within 1 dB of the WAV exports in /tmp/dh-snd/, and that repeated generation is deterministic where the spec says so.
- Web check: sound plays after the first tap in the chromium probe (audio unlock is W3's, but verify the stream starts; if W3 is not there yet, use the skeleton's probe game).

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
godot/dierenhotel/autoload/art.gd, autoload/snd.gd, art/**, geluid/** (new, if you pre-generate), tests/test_art.gd, tests/test_snd.gd, tests/gouden/** only. Specs: art-sound-rules.md (whole), architecture.md §3, §8.
