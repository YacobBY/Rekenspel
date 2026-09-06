TICKET G5 — Minigame "Souvenirkraam" (id `kraam`, room `tuin`, zone Rooms.get('tuin').zones.kraam) for the Dierenhotel demo. Read /home/pc/Documents/xnw/rkn/.fanout/tickets/_gemeenschappelijk-g.md first; it is part of this ticket.

TASK
Replace the stub demos/dierenhotel/games/kraam.js with the full game (spec G5 in .fanout/specs/dierenhotel-golf3-games.md): a little stall in the tuin with three wares and price tags; a guest with the 🎁 souvenir wish comes to buy one and the child pays with coins (and, in groep 5, gives change). The bought item stays visible on the animal until checkout.

EXPECTED OUTCOME
1. Games.register({id:'kraam', naam:'Souvenirkraam', kamer:'tuin', hotspot on the stall counter, unlock(N) true for N ≥ 1, wens:'souvenir', start(ctx), stop(), taak → chip "🎁 Souvenir" whenever a guest carries the 🎁 wish}). Registering makes the hotel hand out the 🎁 wish (ticket P1d): confirm in the suite.
2. World: the stall, counter and three displayed wares are runtime decor from your own registered models, placed inside the reserved zone only (Rooms.get('tuin').zones.kraam); price tags as getalTag or in the model (🎩 hoedje €4, 🧣 sjaaltje €3, ⚽ bal €5, band 5 also 🎒 tas €12 — check the accessory names supported by ctx.wereld.accessoire: hoedje, sjaaltje, bal; a tas is only drawn if the accessory API supports it, otherwise the band-5 extra ware is a second-priced item that is not worn). The coins: reuse the existing coin-drag mechanism from econ.js / the bill through whatever the API exposes (GAMES-API §7 / api-p1*.md); if no generic Econ.betaal exists, build the coin purse and counter inside your file with ctx.sleep / dragKit, but do not copy econ.js code wholesale — keep it small. Tap-to-place must work as well as drag (phones).
3. Turn: the guest with 🎁 walks to the stall (ctx.wereld.loopNaar). Groep 3: "🎁 Boef wil het hoedje van €4" / "Leg de munten op de toonbank" → the child drags or taps €1/€2 coins until the counter shows exactly €4; too much: "nog 1 terug" (a coin slides back), too little: "nog 2 erbij", never red. Groep 4: two wares: "🎁 Hoedje €4 en bal €5" / "Hoeveel euro samen?" sum "4 + 5 =" keypad, then lay the coins. Groep 5: the guest pays with €10 or €20: "👛 Boef gaf €10, het kost €7" / "Hoeveel krijgt hij terug?" sum "€10 − €7 =" and the child gives change from the drawer (coins €1, €2, €5). Success: "✅ Veel plezier ermee!", the ware appears on the animal (ctx.wereld.accessoire(id, 'hoedje' | 'sjaaltje' | 'bal')), behoefteKlaar for the wish, taakKlaar + star. Whole euros only, totals ≤ €20.
4. Suite .fanout/scratch/dierenhotel/kraam/spel.js per the common block: the counter total follows the coins, overpaying and underpaying give the gentle messages and no advance, exact payment completes the wish and adds the accessory (ctx.wereld.accessoires(id) contains it; it survives a reload), band-4 sum and band-5 change are checked, prices and totals within the ceilings, decor inside the zone and not inside the hinkel zone, decor cleared on stop, targets ≥ 48 px; screenshots kraam-port-kaart.png, kraam-port-betaald.png (guest wearing the item), kraam-land-kaart.png.

MUST NOT
Edit any file outside games/kraam.js and your scratch folder (no econ.js, art.js, hotel.js). No timers, no red.

WRITE SET
demos/dierenhotel/games/kraam.js; .fanout/scratch/dierenhotel/kraam/**.

OUTPUT FORMAT
See the common block.
