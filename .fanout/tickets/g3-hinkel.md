TICKET G3 — Minigame "Hinkelpad" (id `hinkel`, room `tuin`, zone Rooms.get('tuin').zones.hinkel) for the Dierenhotel demo. Read /home/pc/Documents/xnw/rkn/.fanout/tickets/_gemeenschappelijk-g.md first; it is part of this ticket.

TASK
Replace the stub demos/dierenhotel/games/hinkel.js with the full game (spec G3 in .fanout/specs/dierenhotel-golf3-games.md): a row of stepping stones as a number line from 0 to E along the back edge of the tuin, a little stair at the target; the guest hops stone by stone with a chosen jump size and the child decides how many jumps.

EXPECTED OUTCOME
1. Games.register({id:'hinkel', naam:'Hinkelpad', kamer:'tuin', hotspot on the first stone, unlock(N) true for N ≥ 1, start(ctx), stop(), taak → chip "🪨 Hinkelen" when a guest has the 🧶 spelen wish (existing wish) or always at low priority if that is how other chips work; if a guest carries 🧶, finishing the turn completes that wish via behoefteKlaar}).
2. World: stones and stair are runtime decor from your own registered models (Rooms.registerModel('steen', fn({getal})) and 'trap'), placed inside the reserved zone only (x0..x1, z0..z1 from Rooms.get('tuin').zones.hinkel); a number on each stone (via the model or getalTag) — groep 3 every stone numbered 0..20, groep 4/5 stones every 5 with numbers on the tens. Clear your decor in stop().
3. Turn: the guest stands on stone s. Card "🐇 Boef staat op 40, trap bij 70" / "Kies je sprong" with a strip of jump pebbles "🪨 sprong 2", "🪨 sprong 5", "🪨 sprong 10" (band dependent). Then "Hoeveel sprongen?" with a keypad or four choices (state "van 40 naar 70"). The animal hops stone by stone with ctx.wereld.stappen(id, punten, {pose:'spring', perStap}) — each landing counts aloud on the tag ("1… 2… 3") and plays Snd.hup. Too short: lands before the stair, card "🐇 Boef staat op 60" / "Nog even verder", the turn continues from 60. Too far: lands past the stair, "🐇 Oei, te ver!" (soft), stays there and the card asks the way back ("van 80 naar 70", a backward jump). Exactly: "✅ Precies op de trap!", taakKlaar + star, the animal climbs the stair happily.
4. Numbers per band: groep 3: E = 20, jumps 1, 2, 5, stones every 1, at most 10 jumps; groep 4: E = 100, stones every 5, jumps 2, 5, 10, jump count ≤ 10, start on a ten; groep 5: E = 100, jumps 2–10, start not on a ten (37 → 77 with jumps of 10). The target must be reachable with the chosen jump size (offer only jump sizes that divide the distance, or let the last card adjust) and the correct count must be unique.
5. Suite .fanout/scratch/dierenhotel/hinkel/spel.js per the common block: stones are inside the zone and not inside the kraam zone, numbers on stones match their positions, the animal's x after k jumps equals stone s + k·jump ± 1 voxel, too short / too far / exact each asserted, band ceilings, reload mid-turn restores s, target and jump, decor cleared on stop; screenshots hinkel-port-kaart.png, hinkel-port-springt.png (mid-hop, lift > 0), hinkel-land-kaart.png.

MUST NOT
Edit any file outside games/hinkel.js and your scratch folder. No timers as pressure, no red.

WRITE SET
demos/dierenhotel/games/hinkel.js; .fanout/scratch/dierenhotel/hinkel/**.

OUTPUT FORMAT
See the common block.
