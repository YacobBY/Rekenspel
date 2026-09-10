# I1 — Wave-1 integration fixes across workstreams

TASK
Fix the integration defects that surfaced once all six wave-1 workstreams were in one tree (commit 90e7adb, suite 204/0). These cross the W2 (hotel) and W3 (UI/hits) write sets, so one worker owns all of them now; no other worker edits the Godot project during this ticket.

FINDINGS TO FIX
1. BLOCKING The prikbord task cards `bord_0`/`bord_1` (hotel.gd's Hotel.hotspots(), rendered through Hits) report a visible rectangle to the probe but never fire a `[probe] tik=<n> id=<id>` line and open nothing when tapped at their own rect (tools/probe.js step `kaart` fails on every profile; log .fanout/scratch/godot-w6/f1-probe4.log). Find the cause (input not reaching the Control? a mouse_filter? the Hotel.render() rebuild wiping the pressed handler? the `door: "hotel"` owner rebuild racing the tap?), fix it, and make the probe's `kaart` step pass: tapping a prikbord card must open its card/sheet, and tapping `bel` must produce the check-in card when a bed is free (day 1 now has 4 beds).
2. SHOULD-FIX Hotspot buttons far from their object: in .fanout/scratch/godot-w1/shots/ipad-land-receptie.png the 🔔 Bel button sits beside the door, far from the bell on the desk. A hotspot button must sit in the band directly above or below its object unless that band is full; check the band choice in hits.gd for objects at the back wall (top edge of the frame: the "boven" band is off-frame so it must flip to "onder", not slide sideways along the top). Add a test with the real receptie layout that asserts every hotspot button's centre is within one band height (52 units) vertically and within the object's width plus 56 units horizontally of its object, except when the band is full.
3. SHOULD-FIX Name plates over buttons: the "Boef" plate overlaps the Prikbord button in the same screenshot. Name plates (ui/naamplaat.gd) must take part in Hits' reservation (kind "tag", like the getal_tag) or be moved below the guest when the band above is taken. Test it in the receptie with three guests near the desk.
4. SHOULD-FIX Phone chrome: at 360×740@3 the top chrome wraps to three rows and the room bar to four (W6's f1-probe-telefoon.log), squeezing the world frame. Apply architecture.md §4.5: compact chrome on phones (icon-only chips with the day/coins/stars in one row, room bar as one scrolling row or the 152-unit rail rule in landscape), so the frame keeps ≥ 60 % of the height in portrait. Measure and report before/after frame sizes at 360×740 and 390×844.
5. SHOULD-FIX Hits rects for door hotspots and guest-following spots (W3's concern: vlakken 2 of 5): give door spots the door's rect from Rooms' door point plus the door model size, and guest-following spots the guest's plate rect via the animal id in the spot, so `dekking_max` covers all five receptie buttons.
6. NIT TOONBANK = plek(0.15, 0.5) = (18, 60) was the old desk arm and is now open floor (W1-F1 concern): move the counting counter used by the bill flow onto the new desk (Kamer.balie footprint) and make the bill cards anchor there. Coordinate with the desk test test_niemand_loopt_door_de_balie.

CONTEXT
Repo /home/pc/Documents/xnw/rkn, Godot at ~/.local/bin/godot, project godot/dierenhotel. Read architecture.md §4.3–§4.5, §5, §6 and §13, the ledger section "Run dierenhotel-godot" entries of 2026-09-09/10 for what each workstream did and the reviewers' remaining notes, and the probe scripts tools/probe.js and .fanout/scratch/godot-w3/opslag-probe.js. HOTEL.md §9 is binding. The owner allows Godot-native improvements everywhere outside architecture.md §1.1.

CONSTRAINTS
Write set: godot/dierenhotel/** except project.godot, export_presets.cfg, core/**, art/**, tests/gouden/**; plus tools/probe.js if a probe expectation must change (say so), plus surgical edits to architecture.md. No commits, no subagents, no blanket process kills.

MUST DO
Before reporting: import (0 ERROR), tools/test.sh (0 fout), export (0 ERROR), tools/probe.js on 1024×768@2, 768×1024@2 and 360×740@3 with all seven steps passing (paste the step line per profile), and one screenshot per profile of the receptie after a prikbord tap under .fanout/scratch/godot-i1/.

OUTPUT FORMAT
Status word first, then at most 25 lines: per finding "fixed: cause → fix", the check results with counts and exit codes, contract changes, concerns.
