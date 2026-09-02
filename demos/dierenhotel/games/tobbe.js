/* ---------------------------------------------------------------
   games/tobbe.js - PLAATSHOUDER.

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
  var h = '<h1>🛁 Tobbe-tijd</h1>' +
    '<div class="opdracht"><p><b>Dit spel wordt nog gebouwd.</b> In de tuin komt een tobbe met een splitskraantje.</p>' +
    '<p class="hint">Straks reken je hier mee: verdubbelen, halveren en splitsen t/m 10 — helemaal zonder tekst.</p></div>' +
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
  id: 'tobbe',
  naam: 'Tobbe-tijd',
  kamer: 'tuin',
  hotspot: { obj: 'tobbe', icoon: '🛁', label: 'Tobbe', hoog: 12 },
  unlock: function (N) { return N >= 1; },
  stub: true,
  start: start,
  stop: stop
});
})();
