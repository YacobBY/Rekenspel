# V1 — Blind verification of the wave-1 Godot port (world, hotel, UI shell, art, sounds, math core, CI)

You receive the original task and the acceptance criteria; you do not receive any worker's reasoning. Assume the work is broken until you have reproduced evidence otherwise. Read-only against source; run everything on a pristine rsync copy of the committed tree (`git stash` is forbidden; the tree must be clean and HEAD unchanged when you finish).

THE OWNER'S TASK (verbatim)
"I want to rebuild the game with Godot it has grown out of scope for what it is now. Then I want to host it on a github page so i can play reach online. I want to play it from a tablet." Later: "De game hoeft niet exact te werken als nu. Als Godot verbeteringen biedt implementeer die dan." And: "De deur bij de ingang is achter de balie. en de dieren moeten door de balie heen lopen. Kan de balie rechtsboven en de deur linksboven."

SCOPE OF THIS VERIFICATION
Wave 1 = everything except the ten minigames: the hotel world, guests, day cycle, economy, wishes, prikbord, check-in, bill, save, UI shell, fonts, art baker, sounds, the frozen math core, and the CI/Pages workflows. The minigames come in wave 2 and are out of scope (only the placeholder `_voorbeeld` exists).

CRITERIA
A. Build: from a cold copy (delete .godot), `tools/import.sh`, `tools/test.sh`, `tools/export.sh` all exit 0 with 0 ERROR lines; report the test count. Prove the runner is not vacuous: add a throwaway failing test in your copy and see the suite go red, then remove it.
B. Frozen math (architecture.md §1.1, §2): independently re-derive at least 30 cases across 6 generators from the JavaScript in demos/dierenhotel (run node yourself; do not trust .fanout/scratch/w5) and compare with the GDScript via a headless script; include the dagRnd 53-bit case and one sleutels LCG sequence.
C. World (world.md §1–§2, architecture.md §13 Q-X1-13 for the relaid receptie): in chromium (Playwright at /home/pc/work/ergomouse/node_modules/playwright, chromium with the swiftshader flags in architecture.md §14.4; serve the export with python http.server) on 1024×768@2 and 768×1024@2 touch: the receptie shows the desk top-right along the back wall and the door top-left; guests walk from the door to the mat without crossing the desk (observe positions over time via the [probe] lines or screenshots); room switching by finger works for all eight rooms; a sleeper appears in kamer1 with 💤 above (not on) its head at some point of the day cycle (drive the day via the chrome buttons).
D. Hotel loop (world.md §3): from a fresh save, ring the bell → a check-in card appears with a sum → answer via the keypad → the guest gets a bed; feed/play once; go to evening → the bill flow with its three steps and the coins; morning → day 2. Report every string you saw and check each against world.md §7 verbatim. Then reload the page: day, stars and coins persist; "Verder spelen ▸" resumes.
E. Tablet rules (HOTEL.md §9, art-sound-rules.md §16): measure in the DOM/console: every tap target ≥ 48 CSS px (44 only below a 360 px short side), text ≥ 12 px, cards ≤ 8 words / 40 chars, no hotspot button covering its object or a guest, no name plate over a button, on 1024×768@2, 768×1024@2, 1280×800@2, 360×740@3, 740×360@3. Report numbers where a rule is within 10 %.
F. Sound: silent before the first tap, plays after (measure via an AudioContext hook or the probe's peak line); the sound toggle persists across reload.
G. Art: 4 species × at least lig/loop/rust at g=4 compared against the extractor PNGs from the HTML (regenerate them yourself with node /tmp/dh-art/extract.js if present, else with the extractor in tests/gouden): silhouettes within 1 px; report the diff ratios.
H. CI: actionlint both workflows; run every `run:` step of test.yml locally in order with the same environment variables; confirm pages.yml cannot deploy without the test job; confirm the OFL licences are in the build.
I. Corrupt saves: craft five corrupt user:// files (truncated, wrong types, missing fields, wrong version, non-JSON) in your copy's user dir (headless via a script) and confirm each boots to the start screen with no SCRIPT ERROR and the running state untouched.

REPORT
Verdict first: PASS / PASS_WITH_NOTES / FAIL. Then per criterion one line PASS/FAIL with the decisive evidence (numbers, file:line, screenshot path under /tmp/v1/). Then findings ranked HIGH/MEDIUM/LOW with file:line. At most 45 lines. Confirm at the end that `git status` is clean and HEAD equals the commit you started from.
