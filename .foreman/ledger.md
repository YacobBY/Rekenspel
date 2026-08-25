# Foreman Ledger

## Run: math-games-ideation (2026-08-24)

**Mode:** Full (Agent tool + real shell; Codex CLI not installed — NO_CODEX)
**LEAD seat:** frontier-class (Fable 5)
**Baseline:** no commits yet (`git rev-parse HEAD` → NO_COMMITS); working tree: `main.py` staged, `.idea/` untracked. Workers are ideation-only, write set = ∅ for all tickets.

**Job:** Brainstorm math-game concepts for children (phone/tablet). Constraints from user: math must be a major, wanted part of the game, not a bolt-on; split play/math structure acceptable if math matters; show usefulness of math, not racing-drill patterns. Seed idea: autoplay horse level → shop where correct math buys equipment for the next autoplay level.

## Tasks

| ID | Ticket | Seat | Write set | Status |
|----|--------|------|-----------|--------|
| T1 | Ideas — lens: math IS the core mechanic/power | WORKHORSE (foreman-worker, opus xhigh) | ∅ | DISPATCHED |
| T2 | Ideas — lens: math useful inside a simulated world (sim/tycoon/building) | WORKHORSE | ∅ | DISPATCHED |
| T3 | Ideas — lens: play-phase creates desire, math-phase fulfils it (motivation loops, extends seed idea) | WORKHORSE | ∅ | DISPATCHED |
| T4 | Ideas — lens: non-arithmetic math (geometry, estimation, measurement, logic, spatial) | WORKHORSE | ∅ | DISPATCHED |

## Attempts (append-only)

- 2026-08-24 T1–T4 attempt 1: dispatched in one parallel wave (disjoint/empty write sets). Verifier note: no code diff produced → blind verifier not applicable; LEAD performs synthesis and judgment, labeled as such.
- 2026-08-24 mid-run: user clarified — pitch many ideas, may build several. Caveman output mode on. No change to dispatch plan.
- 2026-08-24 scope update: focus girls age 6-9 (groep 3-5 NL). T5 dispatched: Dutch rekenen curriculum map (WORKHORSE, web-verified). Girl-focus applied at LEAD synthesis.
- 2026-08-24 T2 (sim-world lens) DONE: 6 concepts (market stall, animal rescue, bridge building, winter provisioning, cafe scaling, aquarium ratios).
- 2026-08-24 T1 (math-as-mechanic lens) DONE: 6 concepts (Snailpost planks, Two Buckets balance, Furrow arrays, Beat Bakery fractions, Tintworks ratios, Hay & Miles provisioning ride).
- 2026-08-24 T3 (play-then-math lens) DONE: 6 concepts incl. Silverhoof (seed evolved), Nibblewick dragons, Moth & Lantern garden, Deepwake engineer, Bramblewood Post, Contraption Cove.
- 2026-08-24 T4 (non-arithmetic lens) DONE: 6 concepts (Foldlings symmetry, Beaverworks measurement, Sorting Shed logic, Tallybird data, Prize Alley probability, Facet 3D sections).
- 2026-08-24 T5 (curriculum) DONE_WITH_CONCERNS: new kerndoelen 10-18 live since aug 2026, per-groep detail from Tussendoelen 2017; corrections logged (7x8=groep 5, comma money=groep 5). All 5 tasks complete. LEAD synthesis written to IDEAS.md. Run closed.

## Run: demos (2026-08-24)
- Baseline: no commits; tree has main.py staged, IDEAS.md, .foreman/, .idea/ untracked.
- T6 Silverhoof demo -> WORKHORSE, write set demos/silverhoof/** : DISPATCHED
- T7 Waggletail demo -> WORKHORSE, write set demos/waggletail/** : DISPATCHED
- 2026-08-24 T7 Waggletail attempt 1: DONE_WITH_CONCERNS (concerns: 4x7 exceeds stated x-ceiling, softened to meer/minder + skip-count hint; dynamic totals; no physical-touch test). Verifier V7 dispatched.
- 2026-08-24 V7 verdict FAIL: evening meer/minder has reachable equality states (dagen*nieuw==voorraad, 7 states) + false text "16 minder dan 16". Fix ticket sent to T7 worker (attempt 2). Minor: adoption cap messaging, setTimeout vignette (accepted).
- 2026-08-24 T7 attempt 2 DONE: three-way meer/minder/precies branch, full-house adoption message; worker sim 5912 evening states clean. V7b re-verify dispatched.
- 2026-08-24 T6 Silverhoof attempt 1 DONE: 36/36 self-checks, exact-payability purse fix, gear causality proven. V6 blind verifier dispatched.
- 2026-08-24 V7b verdict PASS: three-way branch honest in all 896 simulated evenings, wrong answer never advances, division invariant holds. T7 ACCEPTED.
- 2026-08-24 V6 verdict PASS_WITH_NOTES (minor: >20 totals fall back to digits; change >20 in purse-hoard edge case). T6 ACCEPTED. Demo run closed: both demos accepted, blind-verified.

## Run: waggletail-v2 visuals (2026-08-24)
- Skill installs (npx skills add) blocked by permission classifier; surfaced to user with commands. Proceeding without skills.
- T8 voxel visual upgrade -> WORKHORSE, write set demos/waggletail/** : DISPATCHED (isometric canvas voxel, schoolbook panels, math logic frozen)
- Local server started: python3 http.server :8642 (repo root), Silverhoef opened in user preview.
- 2026-08-24 T8 attempt 1 DONE: voxel renderer + eat/happy/sad animations + rekenschrift styling; math trace byte-identical vs pre-change; 60fps/5 animals. V8 verifier dispatched.
- 2026-08-24 V8 verdict PASS: canvases render, math regression clean (all 3 evening buttons, wrong never advances), animations wired (sad only on shorted animal, kibble 4->0, happy), schoolbook CSS confirmed, no external refs, single rAF. T8 ACCEPTED. Run closed.

## Run: v3 polish (2026-08-24)
- T9 Waggletail voxel resolution bump -> WORKHORSE, write set demos/waggletail/** : DISPATCHED
- T10 Zilverhoef visual + auto-coin idle loop -> WORKHORSE, write set demos/silverhoof/** : DISPATCHED
- 2026-08-24 T9 attempt 1 DONE: dpr-aware rendering (was 6x upscale van 48x51 canvas) + ~2x dichtere modellen, 60fps/5 dieren, pose-cache. Write-set deviatie: scratch-artifacts in .foreman/scratch/ (benign, gedoogd). LEAD screenshot check: duidelijk beter. V9 dispatched.
- 2026-08-24 V9 verdict PASS_WITH_NOTES: backing store >= device res, math regressie schoon, 60fps. Note: geen git-baseline (repo zonder commits) - byte-identiteit onbewijsbaar. T9 ACCEPTED.
- 2026-08-24 T10 attempt 1 DONE_WITH_CONCERNS: auto-collect (0 input nodig), 3-rondjes-cap + purse cap 20 (sluit farming af, lost ook beide V6-notes op), 2 nieuwe waren (12/6), parallax/paard-rework, 53/53 checks, 60fps hersteld. Concern: +696 regels vs ~500 richtlijn (visueel werk, aanvaard). LEAD screenshot check OK. V10 dispatched.
- 2026-08-24 V10 verdict PASS: auto-collect bewezen (0 input = 6 munten, taps geven niets), caps sluiten farming, payability 0-20 gebruteforcet, gear-mapping beide kanten. T10 ACCEPTED. Run v3 closed.

## Run: waggletail-v4 wereld (2026-08-24)
- Baseline: ac68e98, werkboom schoon.
- T11 diorama-wereld + zachtere dieren + planbord-constraints -> WORKHORSE, write set demos/waggletail/** : DISPATCHED
- 2026-08-24 T11 attempt 1 DONE: world.js diorama (waypoint-AI, walk-to-bowl), zachter palet + organische motie, planbord-generator met DFS-solvability (360 configs 0 onoplosbaar), bevroren functies byte-identiek. LEAD screenshot check OK; twijfel: naamlabel-verankering. V11 dispatched.
- 2026-08-24 V11 attempt 1 LOST (API-sessielimiet, geen verdict; read-only dus niets te reconcilieren). V11b herstart.
- 2026-08-24 V11b attempt 2 verbroken (connection lost) na solvability-bevestiging; hervat via resume (zelfde context, geen dubbel werk).
- 2026-08-24 V11 verdict PASS: 1 scene-canvas, bevroren functies byte-identiek, labels volgen eigen dier (max 4px; "Wolkje bij hok" was dwalende Boef correct gelabeld), planaudit 360/360 oplosbaar, vast blok onwrikbaar, overtreding zacht benoemd. T11 ACCEPTED.
