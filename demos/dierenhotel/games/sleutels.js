/* ---------------------------------------------------------------
   games/sleutels.js - PLAATSHOUDER.

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
  var h = '<h1>🔑 Het sleutelbord</h1>' +
    '<div class="opdracht"><p><b>Dit spel wordt nog gebouwd.</b> Elke gast krijgt straks een sleutel aan het juiste haakje.</p>' +
    '<p class="hint">Straks reken je hier mee: getalpatronen: 1 t/m 20, sprongen van 5, en kamer 214 = verdieping 2.</p></div>' +
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
  id: 'sleutels',
  naam: 'Het sleutelbord',
  kamer: 'receptie',
  hotspot: { obj: 'sleutelbordz', icoon: '🔑', label: 'Sleutels', hoog: 20 },
  unlock: function (N) { return N >= 2; },
  stub: true,
  start: start,
  stop: stop
});
})();
