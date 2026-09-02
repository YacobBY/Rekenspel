/* ---------------------------------------------------------------
   games/meubels.js - PLAATSHOUDER.

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
  var h = '<h1>📖 Het meubelboek</h1>' +
    '<div class="opdracht"><p><b>Dit spel wordt nog gebouwd.</b> Uit dit boek koop je straks bedden, mandjes en badkuipen.</p>' +
    '<p class="hint">Straks reken je hier mee: hele euro’s t/m 20 betalen met munten, en bouwdelen van 5 sparen.</p></div>' +
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
  id: 'meubels',
  naam: 'Het meubelboek',
  kamer: 'receptie',
  hotspot: { obj: "boek", icoon: "📖", label: "Boek", hoog: 16 },
  unlock: function (N) { return N >= 3; },
  stub: true,
  start: start,
  stop: stop
});
})();
