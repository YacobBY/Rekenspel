/* ---------------------------------------------------------------
   games/voerkar.js - DE VOERKAR (referentie-implementatie).

   Dit bestand is het voorbeeld waar GAMES-API.md naar verwijst: het
   raakt geen enkel gedeeld bestand aan, meldt zichzelf aan bij de
   stekkerdoos en werkt alleen met de ctx die het bij start() krijgt.

   Het spel: in de keuken staat een zak met T = k · N + r koekjes en
   een kar met N vakjes plus een snoeppot. Verdeel eerlijk (ieder dier
   evenveel, de rest in de snoeppot), duw de kar door de gang en tik in
   elke bezette kamer op het bakje. De dieren lopen zelf naar hun bakje
   en smullen het leeg.

   De getallen komen uit ctx.state.sommen.deel(N, band, dag) - en die
   geeft in band 3 precies de bevroren koekjesSom uit de geteste demo.
---------------------------------------------------------------- */
(function () {
'use strict';

var C = null;          /* de ctx */
var K = null;          /* de kar-toestand */

/* ---------- welke gasten en welke kamers doen mee? ---------- */
function gasten() {
  return C.state.gasten().filter(function (g) { return !!g.bed; });
}
function kamersMetGast() {
  var uit = [], zien = {};
  gasten().forEach(function (g) {
    if (zien[g.kamer]) return;
    zien[g.kamer] = 1;
    var bak = C.wereld.slots(g.kamer, 'bak')[0];
    if (bak) uit.push({ kamer: g.kamer, slot: bak.id });
  });
  return uit;
}

function koekjes(n, klaar) {
  var s = '', i;
  for (i = 0; i < Math.min(n, 30); i++) {
    s += klaar
      ? '<span style="animation:fadeup .5s ease-in forwards;animation-delay:' + (i * 90) + 'ms">🍪</span>'
      : '<span>🍪</span>';
  }
  if (n > 30) s += '<b>+' + (n - 30) + '</b>';
  return s;
}

/* =====================================================================
   START
===================================================================== */
function start(ctx) {
  C = ctx;
  var g = gasten();
  if (!g.length) {
    C.ui.toast('Er slaapt nog niemand in het hotel — eerst een gast inchecken! 🔔', 'kind');
    C.sluit();
    return;
  }
  var bewaard = C.state.ruw().kar;
  if (bewaard && bewaard.T) K = bewaard;
  else {
    var som = C.state.sommen.deel(g.length, C.state.band(), C.state.dag());
    K = { T: som.T, per: som.k, rest: som.r, zak: som.T, vak: {}, pot: 0,
          hand: 1, missers: 0, hulp: false, vol: false, geleverd: {}, t0: C.ui.nu() };
    g.forEach(function (q) { K.vak[q.id] = 0; });
    C.state.ruw().kar = K;
  }
  g.forEach(function (q) { if (K.vak[q.id] === undefined) K.vak[q.id] = 0; });
  if (K.vol) { karHotspot(); leenBakjes(); }
  paint();
}

function stop() {
  if (C) C.hotspots.wisAlles();
  C = null;
}

/* =====================================================================
   HET REKENBLAD: de kar vullen
===================================================================== */
function paint() {
  if (!C) return;
  if (K.vol) { paintRondje(); return; }
  var g = gasten(), n = g.length, h = '';
  h += '<h1>🍪 De voerkar</h1><div class="opdracht">';
  h += '<p>Er zijn <b>' + K.T + ' koekjes</b> voor <b>' + n + ' ' + (n === 1 ? 'gast' : 'gasten') +
    '</b>. Verdeel ze <b>eerlijk</b> over de vakjes van de kar: ieder dier evenveel. ' +
    'Wat overblijft mag in de snoeppot.</p>' +
    '<p class="hint">Sleep de koekjes uit de zak naar een vakje. Tikken op een vakje mag ook.</p></div>';

  h += '<div class="bagrow"><div class="bag" id="karzak">' +
    '<div class="n">🍪 ' + K.zak + '</div><div class="lbl">koekjes in de zak</div>' +
    '<div class="crumbs">' + koekjes(Math.min(K.zak, 14)) + '</div></div>' +
    '<div class="hand"><span class="hint">Pak per keer:</span>' +
    [1, 2, 5].map(function (k) {
      return '<button class="btn' + (K.hand === k ? ' on' : '') + '" type="button" data-h="' + k + '">' + k + ' 🍪</button>';
    }).join('') + '</div></div>';

  h += '<div class="bowls">';
  g.forEach(function (a) {
    var c = K.vak[a.id], mis = K.per - c;
    h += '<div class="pet' + (K.feedback && mis !== 0 ? ' mis' : '') + '">' +
      '<div class="nm">' + C.ui.esc(a.naam) + '</div>' +
      '<div class="bowl" data-drop="vak" data-id="' + a.id + '">' + koekjes(c, false) + '</div>' +
      '<div class="count">' + meervoud(c, 'koekje', 'koekjes') + '</div>';
    if (K.feedback && mis > 0) h += '<div class="need">nog ' + mis + '? 🥺</div>';
    if (K.feedback && mis < 0) h += '<div class="need over">' + (-mis) + ' te veel</div>';
    if (c > 0) h += '<button class="mini" type="button" data-back="' + a.id + '">↩ eentje terug</button>';
    h += '</div>';
  });
  h += '<div class="jarwrap"><div style="font-size:2.2rem">🫙</div><div class="nm">Snoeppot</div>' +
    '<div class="bowl jar" data-drop="vak" data-id="__pot">' + koekjes(K.pot, false) + '</div>' +
    '<div class="count">' + meervoud(K.pot, 'koekje', 'koekjes') + '</div>';
  if (K.feedback && K.pot !== K.rest) {
    h += '<div class="need' + (K.pot > K.rest ? ' over' : '') + '">' +
      (K.rest === 0 ? 'hier hoort niets' : K.rest === 1 ? 'hier hoort er 1' : 'hier horen er ' + K.rest) + '</div>';
  }
  if (K.pot > 0) h += '<button class="mini" type="button" data-back="__pot">↩ eentje terug</button>';
  h += '</div></div>';

  h += '<div class="row center" style="margin-top:16px">' +
    '<button class="btn go big" type="button" id="karKlaar">Kar is klaar! ✓</button>' +
    '<button class="btn soft" type="button" id="karReset">Opnieuw beginnen ↺</button>';
  if (K.missers >= 2) h += '<button class="btn" type="button" id="karHulp">🩺 Vraag buurvrouw Els</button>';
  h += '<button class="btn soft" type="button" id="karWeg">Later ▸</button></div>';
  if (K.missers >= 1) h += '<p class="hint" style="text-align:center;margin-top:8px">' +
    'Je mag het zo vaak proberen als je wil. Er gaat niets kapot. 💛</p>';

  C.ui.paneel(h, 'voerkar');
  wire();
}

function wire() {
  var root = $('#paneel');
  if (!root) return;
  var zak = $('#karzak');
  if (zak) C.sleep(zak, {
    dropSel: '[data-drop="vak"]',
    ghostHTML: function () { return '<div style="font-size:26px">' + koekjes(Math.min(K.hand, K.zak)) + '</div>'; },
    canDrag: function () { return K.zak > 0; },
    onDrop: function (t) { verplaats(t.getAttribute('data-id'), K.hand); },
    onTap: function () { C.ui.toast('Sleep de koekjes naar een vakje, of tik op een vakje.', 'kind'); }
  });
  $$('#paneel [data-h]').forEach(function (b) {
    b.onclick = function () { K.hand = +b.getAttribute('data-h'); paint(); };
  });
  $$('#paneel [data-drop="vak"]').forEach(function (b) {
    b.onclick = function () { verplaats(b.getAttribute('data-id'), K.hand); };
  });
  $$('#paneel [data-back]').forEach(function (b) {
    b.onclick = function () { terug(b.getAttribute('data-back')); };
  });
  var k = $('#karKlaar'); if (k) k.onclick = check;
  var r = $('#karReset'); if (r) r.onclick = leeg;
  var hu = $('#karHulp'); if (hu) hu.onclick = hulp;
  var w = $('#karWeg'); if (w) w.onclick = function () { C.sluit(); };
}

function verplaats(id, aantal) {
  var k = Math.min(aantal, K.zak);
  if (k <= 0) { C.snd.zacht(); C.ui.toast('De zak is leeg!', 'kind'); return; }
  K.zak -= k;
  if (id === '__pot') K.pot += k; else K.vak[id] = (K.vak[id] || 0) + k;
  paint();
  C.snd.plop(K.hand);
}
function terug(id) {
  if (id === '__pot') { if (K.pot > 0) { K.pot--; K.zak++; C.snd.terug(); } }
  else if (K.vak[id] > 0) { K.vak[id]--; K.zak++; C.snd.terug(); }
  paint();
}
function leeg() {
  gasten().forEach(function (a) { K.vak[a.id] = 0; });
  K.pot = 0; K.zak = K.T; K.feedback = null;
  paint();
}

/* ---------- de vriendelijke controle (zelfde toon als vroeger) ---------- */
function check() {
  var g = gasten();
  if (K.zak > 0) {
    K.missers++; K.feedback = true; paint(); C.snd.zacht();
    C.ui.toast('Er ' + (K.zak === 1 ? 'zit nog 1 koekje' : 'zitten nog ' + K.zak + ' koekjes') +
      ' in de zak.', 'kind');
    return;
  }
  var goed = g.every(function (a) { return K.vak[a.id] === K.per; }) && K.pot === K.rest;
  if (!goed) {
    K.missers++; K.feedback = true; paint(); C.snd.zacht();
    var tekort = g.filter(function (a) { return K.vak[a.id] < K.per; });
    if (tekort.length) C.ui.toast(tekort[0].naam + ' kijkt een beetje sip… kijk eens bij de vakjes. 💛', 'kind');
    else C.ui.toast('Bijna! Ieder dier moet evenveel krijgen.', 'kind');
    return;
  }
  K.vol = true;
  K.feedback = null;
  C.state.ruw().snoeppot += K.pot;
  C.state.tel(K.missers === 0, C.ui.nu() - K.t0);
  C.taakKlaar('voer', { sterren: 1 });
  C.snd.tover();
  C.ui.toast('Eerlijk verdeeld! Duw de kar nu naar de kamers. 🛒', 'happy');
  paintRondje();
  karHotspot();
  leenBakjes();
}

function hulp() {
  var g = gasten();
  C.ui.voorbeeld({
    titel: 'Buurvrouw Els legt het even voor je neer',
    intro: 'Kijk, ik leg de ' + K.T + ' koekjes op het dienblad:',
    regels: g.map(function (a) { return { wie: a.naam, inhoud: koekjes(K.per) }; })
      .concat([{ wie: 'Snoeppot', inhoud: K.rest ? koekjes(K.rest) : '<span class="hint">leeg</span>' }]),
    slot: '<b>' + K.T + ' koekjes, ' + g.length + ' ' + (g.length === 1 ? 'gast' : 'gasten') +
      '.</b> Ieder <b>' + K.per + '</b>' +
      (K.rest ? ', en <b>' + K.rest + '</b> blijft over voor de snoeppot' : ', precies op') + '.',
    telmee: C.ui.telMee(K.per, g.length, K.rest ? ' … en dan nog ' + K.rest + ' over.' : '.'),
    onOk: function () { leeg(); C.ui.toast('Zet jij ze nu maar neer. 💛', 'kind'); }
  });
}

/* =====================================================================
   HET RONDJE: de kar door de gang en de bakjes vullen
===================================================================== */
function paintRondje() {
  var lijst = kamersMetGast();
  var kar = C.wereld.ding('kar');
  var open = lijst.filter(function (q) { return !K.geleverd[q.kamer]; });
  var h = '<h1>🛒 Het rondje</h1><div class="opdracht">' +
    '<p>De kar staat klaar met <b>' + K.per + ' ' + (K.per === 1 ? 'koekje' : 'koekjes') +
    '</b> per gast. Duw de kar naar een kamer en tik op het <b>bakje</b>.</p>' +
    '<p class="hint">Sleep de kar op een <b>deur</b> om hem mee te nemen. ' +
    'Een kamer die je overslaat blijft gewoon staan — je kunt altijd terug. 💛</p></div>';
  h += '<div class="karrij">';
  lijst.forEach(function (q) {
    var r = C.wereld.kamer(q.kamer);
    var af = !!K.geleverd[q.kamer];
    h += '<div class="karkamer' + (af ? ' af' : '') + '">' +
      '<span class="ki">' + r.icoon + '</span><b>' + C.ui.esc(r.naam) + '</b>' +
      '<span class="kb2">' + (af ? '✓ gevuld' : '🍽 nog leeg') + '</span></div>';
  });
  h += '</div>';
  h += '<div class="row center" style="margin-top:12px">' +
    '<div class="chip">🛒 kar staat in <b>' + C.ui.esc(C.wereld.kamer(kar ? kar.kamer : 'keuken').naam) + '</b></div>' +
    '<div class="chip b">🍪 nog <b>' + open.length + '</b> ' + (open.length === 1 ? 'kamer' : 'kamers') + '</div></div>';
  h += '<div class="row center" style="margin-top:12px">';
  if (!open.length) h += '<button class="btn go big" type="button" id="karAf">Alle bakjes vol! ▸</button>';
  else h += '<button class="btn soft" type="button" id="karWeg">Later verder ▸</button>';
  h += '</div>';
  C.ui.paneel(h, 'voerkar');
  var a = $('#karAf');
  if (a) a.onclick = function () {
    C.state.ruw().kar = null;
    C.ui.toast('Alle bakjes zijn gevuld. Wat een goede hotelhouder! ⭐', 'happy');
    C.sluit();
  };
  var w = $('#karWeg'); if (w) w.onclick = function () { C.sluit(); };
}

/* de kar is zelf een hotspot: sleep hem op een deur of op een bakje */
function karHotspot() {
  if (!C) return;
  var kar = C.wereld.ding('kar');
  if (!kar) return;
  C.hotspots.maak({
    id: 'karhot', kamer: kar.kamer, x: kar.x, z: kar.z, y: 16,
    icoon: '🛒', label: K.vol ? 'Duw mij' : 'Vul mij', titel: 'De voerkar',
    klas: 'hotkar', prio: 9,
    volg: function () {
      var q = C.wereld.ding('kar');
      return q ? { x: q.x, z: q.z, y: 16 } : null;
    },
    aan: function () { K.vol ? paintRondje() : paint(); }
  });
  var el = document.querySelector('[data-hot="karhot"]');
  if (el && K.vol && !el.__sleep) {
    el.__sleep = 1;
    C.sleep(el, {
      dropSel: '[data-drop="deur"],[data-drop="bak"]',
      ghostHTML: function () { return '<div class="karghost">🛒</div>'; },
      onDrop: function (t) {
        if (t.getAttribute('data-drop') === 'deur') duwNaar(t.getAttribute('data-h-naar'));
        else lever(t.getAttribute('data-h-kamer'), t.getAttribute('data-h-slot'));
      },
      onTap: function () { paintRondje(); }
    });
  }
}

/* Zolang de kar vol is, is het BAKJE van het hotel even van de voerkar:
   tikken betekent dan "hier afleveren" in plaats van "vertel wat er moet". */
function leenBakjes() {
  kamersMetGast().forEach(function (q) {
    C.hotspots.pak('bak_' + q.kamer + '_' + q.slot, function () { lever(q.kamer, q.slot); });
  });
}

function duwNaar(kamerId) {
  if (!kamerId) return;
  C.wereld.dingZet('kar', { kamer: kamerId });
  C.wereld.naar(kamerId);
  C.snd.kar();
  if (window.Hotel) Hotel.render();
  karHotspot();
  leenBakjes();
  paintRondje();
  var open = kamersMetGast().filter(function (q) { return q.kamer === kamerId && !K.geleverd[q.kamer]; });
  if (open.length) C.ui.toast('Tik nu op het bakje. 🍽', 'kind');
}

/* het bakje vullen: de dieren van die kamer lopen erheen en smullen */
function lever(kamerId, slotId) {
  var kar = C.wereld.ding('kar');
  if (!kar || kar.kamer !== kamerId) {
    C.ui.toast('De kar staat nog niet in deze kamer. Duw hem eerst hierheen. 🛒', 'kind');
    return;
  }
  var hier = gasten().filter(function (g) { return g.kamer === kamerId; });
  if (!hier.length) { C.ui.toast('Hier slaapt niemand — dit bakje mag leeg blijven. 🙂', 'kind'); return; }
  if (K.geleverd[kamerId]) { C.ui.toast('Dit bakje is al gevuld. 🍪', 'kind'); return; }
  var samen = 0;
  hier.forEach(function (g) { samen += K.vak[g.id] || 0; K.vak[g.id] = 0; });
  K.geleverd[kamerId] = samen;
  C.wereld.setBak(kamerId, slotId, 4);
  hier.forEach(function (g) { g.gegeten = true; g.behoefte = 'spelen'; g.blij = false; });
  C.wereld.feest(hier.map(function (g) { return g.id; }));
  C.snd.plop(3);
  C.ui.toast(hier.length === 1 ? hier[0].naam + ' smult! 😋' : 'Ze smullen allemaal! 😋', 'happy');
  C.state.bewaar();
  if (window.Hotel) Hotel.render();
  paintRondje();
}

/* =====================================================================
   AANMELDEN
===================================================================== */
Games.register({
  id: 'voerkar',
  naam: 'De voerkar',
  kamer: 'keuken',
  hotspot: { obj: 'kar', icoon: '🛒', label: 'Voerkar', hoog: 16 },
  unlock: function (N) { return N >= 1; },
  start: start,
  stop: stop
});
})();
