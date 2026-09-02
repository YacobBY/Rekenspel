/* ---------------------------------------------------------------
   games/bedden.js - PLAATSHOUDER.

   Dit spel is nog niet gebouwd. Het bestand meldt zich wél al aan bij
   de stekkerdoos, zodat de knop in de wereld staat, de pagina werkt en
   de bouwer van dit spel ALLEEN dit bestand hoeft te vervangen.
   Lees eerst GAMES-API.md (en games/voerkar.js als voorbeeld).
---------------------------------------------------------------- */
(function () {
'use strict';

var C = null;

function start(ctx) {
  C = ctx;
  var h = '<h1>📐 Bedden op rij</h1>' +
    '<div class="opdracht"><p><b>Dit spel wordt nog gebouwd.</b> De kamer wordt een rooster waarin je bedjes op rijen legt.</p>' +
    '<p class="hint">Straks reken je hier mee: rijen × bedden (de tafels als kamer) en de verdeelstrategie met een schuifwand.</p></div>' +
    '<div class="row center" style="margin-top:14px">' +
    '<button class="btn go big" type="button" id="stubDicht">Oké, tot straks ▸</button></div>';
  C.ui.paneel(h, 'stub');
  var b = document.getElementById('stubDicht');
  if (b) b.onclick = function () { C.sluit(); };
}

function stop() {
  if (C) C.hotspots.wisAlles();
  C = null;
}

Games.register({
  id: 'bedden',
  naam: 'Bedden op rij',
  kamer: 'kamer1',
  /* de knop staat naast het bed (dx/dz), niet bovenop het slapende dier;
     wie dit spel bouwt kiest natuurlijk zelf waar hij hangt */
  hotspot: { obj: 'bed1', icoon: '📐', label: 'Bedden', hoog: 15, dx: 16, dz: -2 },
  unlock: function (N) { return N >= 1; },
  stub: true,
  start: start,
  stop: stop
});
})();
