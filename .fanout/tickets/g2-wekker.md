TICKET G2 — Minigame "Wekkerdienst" (id `wekker`, room `gang`) for the Dierenhotel demo. Read /home/pc/Documents/xnw/rkn/.fanout/tickets/_gemeenschappelijk-g.md first; it is part of this ticket.

TASK
Replace the stub demos/dierenhotel/games/wekker.js with the full game (spec G2 in .fanout/specs/dierenhotel-golf3-games.md): a big hall clock on the gang wall whose hands really turn; the child sets the clock to the time a sleeping guest wants to wake up.

EXPECTED OUTCOME
1. Games.register({id:'wekker', naam:'Wekkerdienst', kamer:'gang', hotspot on the clock, unlock(N) true for N ≥ 1, start(ctx), stop(), taak → chip "⏰ Wekker zetten" when at least one guest is sleeping or when it is the evening round (find the round state through ctx / Hotel; if no guest sleeps, the game still works with the first guest as "wil morgen om … op")}). No new wish is needed (lead decision): the wake-up card floats above the sleeping guest and the clock.
2. World: the clock is runtime decor on the gang wall built from your own model registered with Rooms.registerModel('klok', fn) where fn({uur, min}) returns a voxel list with a dial, hour marks and two hands that follow the parameters; update it with ctx.wereld.decor every time the time changes (the engine re-renders on parameter change; confirm the cost is acceptable: at most one re-render per tap). Below the clock a card.
3. Turn: card sentence "⏰ Boef wil om 7 uur op" / second line "Zet de klok"; a state line "nu: 5 uur" that updates live. Buttons in one strip: "🕐 uur erbij" (all bands), "🕒 kwartier erbij" (band ≥ 4), "🕧 5 minuten erbij" (band 5), "✅ Klaar". Every tap turns the hands visibly and plays Snd.klok softly. Klaar with the right time: soft chime, the guest wakes (pose happy, ☀ wolk), taakKlaar + star. Klaar with a wrong time: the guest stays asleep, card "⏰ De klok staat op 6 uur" / "Boef wil 7 uur", the hands stay where they are so the child keeps turning; "uur erbij" wraps after 12; never a reset needed, no red.
4. Variants per band: groep 3 whole hours (target 1–12, start differs from target by 1–5 hours); groep 4 half hours and quarters written in words ("half 8", "kwart over 7", "kwart voor 8"); groep 5 additionally durations: "Boef slaapt nog 2 uur, het is 7 uur" / "Hoe laat is hij wakker?" with four choices ("🕘 9 uur", …). Use state.js sommen.klok where it fits (read-only); otherwise derive from band and N in your file. The time words must match Dutch conventions (half 8 = 7:30).
5. Suite .fanout/scratch/dierenhotel/wekker/spel.js per the common block: hand angles follow the state (read the decor params or the model), whole-hour band never offers quarter/minute buttons, band-4 wording for 7:30 is "half 8", wrong Klaar leaves the hands unchanged and the guest asleep, right Klaar wakes the guest and awards the star, the decor disappears after stop(), reload mid-turn restores the current time and target; screenshots wekker-port-kaart.png, wekker-port-klaar.png, wekker-land-kaart.png.

MUST NOT
Edit any file outside games/wekker.js and your scratch folder. No timers as pressure, no red.

WRITE SET
demos/dierenhotel/games/wekker.js; .fanout/scratch/dierenhotel/wekker/**.

OUTPUT FORMAT
See the common block.
