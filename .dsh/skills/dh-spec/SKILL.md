---
name: dh-spec
description: Where every fact of this project lives (spec sections with line numbers, design rules, save format, strings) so you grep a section instead of reading whole documents.
whenToUse: Before opening any file under .fanout/specs/, HOTEL.md, HANDOFF.md, ANALYSIS.md or IDEAS.md.
---

Read a **section** (`read` with `offset`/`limit`, or `grep` for the heading),
never the whole file. Line numbers are from 2026-09-17.

# `.fanout/specs/godot/games-b.md` (2032 lines) — zwembad, wekker, hinkel, was, kraam
§0 shared basis 20–226 (0.3 sum card 57, 0.5 help ladder 106, 0.6 never
punishing 113, 0.7 sounds 119, 0.11 reduced motion 189, 0.12 start/stop 207) ·
§1 zwembad 226–626 (1.3 maths 277, 1.4 buttons 318, 1.5 the tap 365, 1.7 the
two ends 421, 1.9 decor 460, 1.10 card margins 492, 1.11 strings 580) ·
§2 wekker 626–953 · §3 hinkel 953– · §4 was · §5 kraam (grep `^## 4`, `^## 5`).

# `.fanout/specs/godot/games-a.md` (1583 lines) — bedden, sleutels, meubels, tobbe, voerkar
§1 shared 19 · §2 frozen maths core 176 · §3 bedden 375 · §4 sleutels 619 ·
§5 meubels 843 · §6 tobbe 1068 · §7 voerkar 1316 · §8 checklist 1515.

# `.fanout/specs/godot/world.md` (1517 lines)
§0 coordinates 16 · §1 rooms 54 · §2 guests 357 · §3 day/wishes/economy 569 ·
§4 save format 911 · §5 game contract 1001 (5.4 hotspot keys, 5.5–5.6 card,
bubble, tag keys) · §6 UI shell 1231 · §7 every world string verbatim 1379.

# `.fanout/specs/godot/architecture.md` (1921 lines) — binding design
§1 frozen vs free 28 · §2 number core 94 · §3 voxel rendering 258 · §4 layout on
tablets 520 · §5 scene tree/autoloads 830 · §6 game contract 906 · §7 project
settings/export/CI 1171 · §8 sound 1390 · §9 save 1477 · §10 input/drag 1547 ·
§11 file skeleton 1579 · §13 answered questions 1710 · §14 verification 1785.

# `.fanout/specs/godot/art-sound-rules.md` (1644 lines)
§2 palette 127 · §5 poses 319 · §8 decor models 445 · §9 game models 488 ·
§11 motion/particles 530 · §12 emoji/fonts 633 · §15 sound 876 · §17 binding
checklist 1234.

# `.fanout/specs/godot/toolchain.md` (445 lines)
§2 commands 79 · §3 export preset 113 · §6 browser verification 317 · §7 gotchas 362.

# Design and history (read only when asked)
`HOTEL.md` (121 lines): §3 the N scale rule 40, §5 game catalogue 58, §9 text
rules 112. `AGENTS.md` §4 autoload API, §5 contract, §6 game table, §8 gotchas.
`HANDOFF.md` §7 rediscovered facts; `ANALYSIS.md` §4 backlog; `IDEAS.md`
curriculum; `.fanout/ledger.md` append-only build log (huge — grep only).

# Code entry points
Autoloads `godot/dierenhotel/autoload/*.gd` (world.gd: `decor` 497,
`decor_lijst` 532, `deeltjes` 1264, `spetter` 1726); contract
`spel/minigame.gd`, `spel/ctx.gd`; shell `scenes/main.gd` (`[probe]` lines,
`?opslag=` hook 452); strings `ui/teksten.gd`; runner `tests/run_tests.gd`,
asserts `tests/proef.gd`.
