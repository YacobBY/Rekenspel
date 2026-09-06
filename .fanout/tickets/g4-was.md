TICKET G4 — Minigame "Wasmandtoren" (id `was`, room `wasserij`) for the Dierenhotel demo. Read /home/pc/Documents/xnw/rkn/.fanout/tickets/_gemeenschappelijk-g.md first; it is part of this ticket.

TASK
Replace the stub demos/dierenhotel/games/was.js with the full game (spec G4 in .fanout/specs/dierenhotel-golf3-games.md): a pile of laundry and 2–4 crates against the wall, each crate with a pictogram; every item sorted into a crate becomes a block on a stack, so the crates form a real bar chart; when the pile is empty the child answers questions about the chart.

EXPECTED OUTCOME
1. Games.register({id:'was', naam:'Wasmandtoren', kamer:'wasserij', hotspot on the laundry pile, unlock(N) true for N ≥ 1, start(ctx), stop(), taak → chip "🧺 Was sorteren" always available at low priority}).
2. World: pile = a source hotspot with a counter (ctx.ui bron pattern from voerkar/tobbe); crates = runtime decor from your own registered models (Rooms.registerModel('krat', fn({soort, n})) drawing the crate and n stacked blocks in the item colour), updated through ctx.wereld.decor as blocks are added; a pictogram label on each crate (🧦 sokken, 🧣 sjaals, 🧺 handdoeken, 🧸 knuffels). Clear your decor in stop().
3. Sorting: the child taps an item on the pile (it shows its kind as icon + word), then taps a crate (or drags with ctx.sleep / dragKit; tap-tap must work on phones). Right crate → block appears on the stack, soft sound; wrong crate → gentle bounce, the item returns to the pile, no text, no red. When the pile is empty the question card appears next to the crates.
4. Questions per band (all generated in your file): groep 3 (2–3 kinds, total ≤ 12): "📊 Welke stapel is het hoogst?" with the kinds as icon+word choices (stacks never equal). Groep 4 (3 kinds, ≤ 20): "📊 Hoeveel meer sokken dan sjaals?" with the sum "7 − 4 =" and a keypad, then "Hoeveel stuks samen?". Groep 5 (4 kinds, ≤ 30 items arriving as pairs, so ≤ 15 taps): legend "Elk blokje is 2 stuks", questions "Hoeveel sokken?" (blocks × 2) and the difference. Totals T = k·N + r within those ceilings. Success: "✅ Alles gesorteerd!", taakKlaar + star.
5. Suite .fanout/scratch/dierenhotel/was/spel.js per the common block: the block count on each crate equals the items sorted into it (read the decor params), wrong crate leaves counts unchanged and the pile count intact, "hoogst" question never has a tie, band ceilings and kind counts, keypad answers checked, reload mid-sort restores pile and stacks, decor cleared on stop, targets ≥ 48 px including the crates; screenshots was-port-sorteren.png, was-port-vraag.png, was-land-vraag.png.

MUST NOT
Edit any file outside games/was.js and your scratch folder. No timers, no red.

WRITE SET
demos/dierenhotel/games/was.js; .fanout/scratch/dierenhotel/was/**.

OUTPUT FORMAT
See the common block.
