# X4 — Port specification: art, sound, style and binding design rules, plus an asset-extraction proposal

TASK
Write `.fanout/specs/godot/art-sound-rules.md` covering demos/dierenhotel/art.js, snd.js, style.css, index.html, HOTEL.md (whole file, §9 verbatim) and GAMES-API.md §9 "Op de telefoon", so that a Godot developer can reproduce the look, the sounds and obey every binding rule without reading the JavaScript. Also assess and propose how the artwork can be carried over to Godot.

EXPECTED OUTCOME
1. Art: how drawing works (voxel, pixel, vector, emoji, canvas 2D?), the unit size, the palette with hex values, the list of every sprite/model (guests per species and pose, decor, room tiles, cards, chips, coins, crates, clock, pool, and so on) with their dimensions, how animation frames are built, the 💤 and other emoji usage, fonts and text sizes, the density cap on phones, redraw-on-change rule.
2. Asset extraction proposal: judge whether the sprites can be rendered to PNG sprite sheets from the existing JavaScript in headless chromium (Playwright at /home/pc/work/ergomouse/node_modules/playwright) so that Godot loads them as textures, versus re-drawing them procedurally in GDScript. Prototype the extraction for at least two sprites (one guest pose and one decor object) into /tmp/dh-art/ and report the exact approach, output sizes, and whether it preserved the look (attach a screenshot path). Recommend one path with reasons.
3. Sound (snd.js): every sound by name (plons, au, klok, hup and all others) with the synthesis parameters (oscillator type, frequencies, envelope, durations) so they can be reproduced, or be exported to WAV/OGG by the same headless route; prototype the export for two sounds into /tmp/dh-snd/ and report.
4. Style and layout (style.css, index.html, ui.js as far as needed): the frame (kader) sizing rules for portrait and landscape, dvh/safe-area, the keypad strip, chrome sizes, colours, button sizes (≥ 48 px, 44 only below 360 px), the 12 px text floor, breakpoints, reduced-motion.
5. HOTEL.md in full (rules verbatim, room table) and GAMES-API §9 rules as a checklist a game worker can tick off.
6. Tablet targets: from the rules and the current viewports tested (360×740, 320×640, 568×320, 740×360, iPhone 13, 420×900), derive what an iPad (1024×768 and 1180×820 logical) and an Android tablet (1280×800 logical) should get: proposed base resolution and stretch policy for Godot, stated as a recommendation.

CONTEXT
The repo at /home/pc/Documents/xnw/rkn contains "Dierenhotel", a Dutch math game for children (groep 3–5) written in plain HTML and JavaScript under demos/dierenhotel/. It is being rebuilt in Godot 4.7 (GDScript) in a later wave by workers who will NOT read the JavaScript; they will read only your specification. Every rule, number, string and behaviour that matters must therefore be in your document, stated precisely, with child-facing Dutch strings quoted verbatim. Design rules that bind every game are in HOTEL.md §9 and GAMES-API.md (demos/dierenhotel/GAMES-API.md). Earlier design specs exist in .fanout/specs/dierenhotel-golf3-games.md and .fanout/tickets/g*.md; they may help but the code is the truth where they differ.

CONSTRAINTS
- Read-only against the game code. Write only the single spec file named in WRITE SET.
- Precise prose and tables; no code dumps except tiny formulas or constant lists where prose would be ambiguous. Quote all Dutch strings exactly.
- Where behaviour depends on the curriculum band (groep 3 / 4 / 5), give each band separately.
- Where a value is derived, give the formula and one worked example.

MUST DO
- State facts you verified in the code; mark anything inferred as "inferred".
- End with a section "Open questions for the port" listing anything the JavaScript leaves ambiguous.

MUST NOT
- Do not spawn subagents. Do not modify any file other than your spec file. Do not summarise loosely where exactness matters (generator constants, band limits, strings, timings).

OUTPUT FORMAT
Open with exactly one status: DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT or BLOCKED. Then at most 20 lines: what the spec covers, its length, the three most surprising facts, and concerns. Do not paste the spec into the report.

WRITE SET
.fanout/specs/godot/art-sound-rules.md, /tmp/dh-art/, /tmp/dh-snd/ only.
