/* ---------------------------------------------------------------
   games/voerkar.js - DE VOERKAR (referentie-implementatie, HOTEL.md 9).

   Alles gebeurt ín de keuken, niets op een rekenblad ernaast:
     * de zak koekjes is een sleepbron met de teller erop;
     * de vakjes van de kar staan als echte bakjes op de keukenvloer, met
       het aantal als cijfer op het bakje;
     * fout? dan hangt er een wolkje met een pictogram en een getal
       ("nog 2 🍪"), nooit een lap tekst en nooit een rood kruis;
     * buurvrouw Els doet het één keer voor door de goede aantallen als
       spookcijfers neer te leggen.
   Daarna duw je de kar door de gang en tik je in elke bezette kamer op
   het bakje; de dieren lopen zelf naar hun bakje en smullen het leeg.

   De getallen komen uit ctx.state.sommen.deel(N, band, dag) - in band 3
   is dat exact de bevroren koekjesSom uit de geteste demo.
---------------------------------------------------------------- */
(function () {
'use strict';

var C = null;          /* de ctx */
var K = null;          /* de kar-toestand */
var HAND = [1, 2, 5];
/* de vakjes staan op een diagonaal over de keukenvloer: zo liggen ze op het
   scherm ver genoeg uit elkaar om elk apart aan te tikken */
var VAK_PLEK = [[12, 60], [24, 48], [36, 36], [48, 24], [12, 36], [48, 48]];
var POT_PLEK = [60, 60];

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
function niveau(aantal) {
  if (!aantal) return 0;
  var per = K.per || 1;
  return Math.max(1, Math.min(4, Math.ceil(aantal / per * 4)));
}

/* =====================================================================
   START
===================================================================== */
function start(ctx) {
  C = ctx;
  var g = gasten();
  if (!g.length) {
    C.ui.wolk('kar', { id: 'vk_leeg', door: 'voerkar', icoon: '🛏', tekst: 'nog geen gasten' });
    setTimeout(function () { C && C.ui.wolkWeg('vk_leeg'); C && C.sluit(); }, 1800);
    return;
  }
  var bewaard = C.state.ruw().kar;
  if (bewaard && bewaard.T) K = bewaard;
  else {
    var som = C.state.sommen.deel(g.length, C.state.band(), C.state.dag());
    K = { T: som.T, per: som.k, rest: som.r, zak: som.T, vak: {}, pot: 0,
          hand: 1, missers: 0, vol: false, geleverd: {}, t0: C.ui.nu() };
    g.forEach(function (q) { K.vak[q.id] = 0; });
    C.state.ruw().kar = K;
  }
  g.forEach(function (q) { if (K.vak[q.id] === undefined) K.vak[q.id] = 0; });
  C.wereld.naar('keuken');
  if (K.vol) { rondje(); } else { vulOp(); }
}

function stop() {
  vakjesWeg();
  if (C) { C.hotspots.wisAlles(); C.hotspots.laat(); }
  C = null;
}

/* =====================================================================
   DE VAKJES: echte bakjes op de keukenvloer
===================================================================== */
function vakjesWeg() {
  if (!K || !K.slots) return;
  K.slots.forEach(function (q) { Rooms.meubelWeg(q.slot); });
  K.slots = null;
  World.herbouw();
}
function vakjesNeer() {
  var g = gasten(), i, m;
  K.slots = [];
  for (i = 0; i < g.length && i < VAK_PLEK.length; i++) {
    m = Rooms.meubelZet('keuken', 'bakje', VAK_PLEK[i][0], VAK_PLEK[i][1]);
    if (!m) continue;
    var sl = Rooms.slot('keuken', m.id);
    if (sl) sl.tijdelijk = 1;
    K.slots.push({ slot: m.id, gast: g[i].id, naam: g[i].naam });
  }
  m = Rooms.meubelZet('keuken', 'bakje', POT_PLEK[0], POT_PLEK[1]);
  if (m) {
    var sp = Rooms.slot('keuken', m.id);
    if (sp) sp.tijdelijk = 1;
    K.slots.push({ slot: m.id, gast: '__pot', naam: 'snoeppot' });
  }
  World.herbouw();
}
function slotVan(gastId) {
  var i;
  for (i = 0; K.slots && i < K.slots.length; i++) if (K.slots[i].gast === gastId) return K.slots[i];
  return null;
}

/* =====================================================================
   VULLEN
===================================================================== */
function vulOp() {
  if (!K.slots || !K.slots.length) vakjesNeer();
  teken();
}

function teken() {
  if (!C || !K || K.vol) return;
  C.hotspots.wisAlles();
  var g = gasten(), i;

  /* de zak: sleepbron met de teller erop; tikken wisselt de handgreep */
  C.hotspots.bron('zak', {
    id: 'vk_zak', icoon: '🍪', aantal: K.zak, hand: K.hand, hoog: 18,
    klas: K.zak ? '' : 'leeg',
    titel: 'zak met ' + K.zak + ' koekjes, pak ' + K.hand,
    tik: function () {
      K.hand = HAND[(HAND.indexOf(K.hand) + 1) % HAND.length];
      teken();
      C.snd.tik();
    },
    sleep: {
      dropSel: '[data-drop="vak"]',
      ghostHTML: function () { return '<div class="karghost">🍪</div>'; },
      canDrag: function () { return K.zak > 0; },
      onDrop: function (t) { verplaats(t.getAttribute('data-h-id'), K.hand); }
      /* geen onTap: de tik loopt via `tik` hierboven, precies één keer */
    }
  });

  /* elk vakje: drop-doel met het aantal als cijfer op het bakje */
  (K.slots || []).forEach(function (q) {
    var aantal = q.gast === '__pot' ? K.pot : (K.vak[q.gast] || 0);
    var sl = Rooms.slot('keuken', q.slot);
    if (!sl) return;
    C.wereld.setBak('keuken', q.slot, niveau(aantal));
    C.hotspots.maak({
      id: 'vk_' + q.gast, kamer: 'keuken', x: sl.x, z: sl.z, y: 10,
      icoon: q.gast === '__pot' ? '🫙' : '🍪',
      getal: aantal, kind: 'drop', drop: 'vak',
      data: { id: q.gast }, klas: 'hotbron', prio: 9,
      titel: q.naam + ': ' + aantal,
      aan: function () { verplaats(q.gast, K.hand); }
    });
    /* na een misser: hoeveel er nog bij of af moet, als pictogram + getal */
    if (K.feedback) {
      var doel = q.gast === '__pot' ? K.rest : K.per;
      var mis = doel - aantal;
      if (mis !== 0) {
        C.ui.wolk({ x: sl.x, z: sl.z, kamer: 'keuken' }, {
          id: 'vkm_' + q.gast, door: 'voerkar', icoon: mis > 0 ? '🍪' : '↩',
          getal: (mis > 0 ? '+' : '') + mis, hoog: 24, klas: 'hulp', prio: 8
        });
      }
    }
  });

  /* de kar: hier tik je op als je klaar bent */
  C.hotspots.maak({
    id: 'vk_klaar', kamer: 'keuken', x: 32, z: 44, y: 18,
    icoon: '🛒', label: 'klaar', klas: 'hotwolk goed', prio: 11,
    titel: 'de kar is klaar', aan: check
  });
  C.hotspots.maak({
    id: 'vk_opnieuw', kamer: 'keuken', x: 20, z: 32, y: 14,
    icoon: '↩', klas: 'hotwolk', prio: 7,
    titel: 'opnieuw beginnen', aan: leeg
  });
  if (K.missers >= 2) {
    C.hotspots.maak({
      id: 'vk_els', kamer: 'keuken', x: 44, z: 60, y: 14,
      icoon: '🩺', klas: 'hotwolk hulp', prio: 8,
      titel: 'buurvrouw Els doet het voor', aan: hulp
    });
  }
  /* één korte regel: hoeveel koekjes voor hoeveel gasten */
  /* één korte regel: het aantal koekjes en wat je ermee doet */
  C.ui.wolk('kast', { id: 'vk_som', door: 'voerkar', icoon: '🍪', getal: K.T,
                      tekst: 'eerlijk delen', hoog: 30, prio: 9 });
  C.wereld.vuil();
}

function verplaats(id, aantal) {
  if (!id || K.vol) return;
  var k = Math.min(aantal, K.zak);
  if (k <= 0) {
    C.snd.zacht();
    C.ui.wolk('zak', { id: 'vk_op', door: 'voerkar', icoon: '🍪', getal: 0, klas: 'hulp' });
    return;
  }
  K.zak -= k;
  if (id === '__pot') K.pot += k; else K.vak[id] = (K.vak[id] || 0) + k;
  K.feedback = null;
  C.ui.wolkWeg('vk_op');
  teken();
  C.snd.plop(K.hand);
}
function leeg() {
  gasten().forEach(function (a) { K.vak[a.id] = 0; });
  K.pot = 0; K.zak = K.T; K.feedback = null;
  spookWeg();
  teken();
  C.snd.terug();
}

/* ---------- de vriendelijke controle (zelfde regels als vroeger) ---------- */
function check() {
  var g = gasten();
  if (K.zak > 0) {
    K.missers++; K.feedback = true;
    teken(); C.snd.zacht();
    C.ui.wolk('zak', { id: 'vk_op', door: 'voerkar', icoon: '🍪', getal: K.zak,
                       tekst: 'nog in de zak', klas: 'hulp', prio: 10 });
    return;
  }
  var goed = g.every(function (a) { return K.vak[a.id] === K.per; }) && K.pot === K.rest;
  if (!goed) {
    K.missers++; K.feedback = true;
    teken(); C.snd.zacht();
    return;
  }
  K.vol = true;
  K.feedback = null;
  spookWeg();
  C.state.ruw().snoeppot += K.pot;
  C.state.tel(K.missers === 0, C.ui.nu() - K.t0);
  C.taakKlaar('voer', { sterren: 1 });
  C.snd.tover();
  vakjesWeg();
  rondje();
}

/* ---------- Els doet het voor: de goede aantallen als spookcijfers ---------- */
function spookWeg() {
  (K.slots || []).forEach(function (q) { C.wereld.getalTag({ x: 0, z: 0 }, null, { id: 'vs_' + q.gast }); });
}
function hulp() {
  var g = gasten();
  (K.slots || []).forEach(function (q) {
    var sl = Rooms.slot('keuken', q.slot);
    if (!sl) return;
    var doel = q.gast === '__pot' ? K.rest : K.per;
    C.wereld.getalTag({ x: sl.x, z: sl.z, kamer: 'keuken' }, doel,
                      { id: 'vs_' + q.gast, y: 18, klas: 'hotspook', titel: 'zoveel hoort er in' });
  });
  C.ui.wolk('kast', { id: 'vk_els_zeg', door: 'voerkar', icoon: '🩺',
                      getal: K.per, tekst: 'ieder evenveel', hoog: 30, klas: 'hulp', prio: 11,
                      tik: function () { C.ui.wolkWeg('vk_els_zeg'); spookWeg(); leeg(); } });
  C.state.zetGezien('voerkar_els');
  C.snd.brief();
}

/* =====================================================================
   HET RONDJE: de kar door de gang en de bakjes vullen
===================================================================== */
function rondje() {
  if (!C || !K) return;
  C.hotspots.wisAlles();
  var open = kamersMetGast().filter(function (q) { return !K.geleverd[q.kamer]; });
  var kar = C.wereld.ding('kar');
  karHotspot(open.length);
  leenBakjes();
  if (!open.length) {
    C.ui.wolk('kar', { id: 'vk_af', door: 'voerkar', icoon: '✅', tekst: 'alle bakjes vol',
                       hoog: 22, klas: 'goed', prio: 12,
                       tik: function () { klaarMetRondje(); } });
    setTimeout(function () { if (C && K && K.vol) klaarMetRondje(); }, 2600);
  } else {
    C.ui.wolk('kar', { id: 'vk_duw', door: 'voerkar', icoon: '🛒',
                       getal: K.per, tekst: 'per gast', hoog: 24, prio: 10 });
  }
  C.wereld.vuil();
}
function klaarMetRondje() {
  if (!C) return;
  C.state.ruw().kar = null;
  C.ui.wolkWeg('vk_af');
  C.sluit();
}

/* de kar is zelf een hotspot: sleep hem op een deur of op een bakje */
function karHotspot(nogOpen) {
  if (!C) return;
  var kar = C.wereld.ding('kar');
  if (!kar) return;
  C.hotspots.maak({
    id: 'karhot', kamer: kar.kamer, x: kar.x, z: kar.z, y: 16,
    icoon: '🛒', getal: nogOpen || null, titel: 'de voerkar', klas: 'hotkar', prio: 11,
    volg: function () {
      var q = C.wereld.ding('kar');
      return q ? { x: q.x, z: q.z, y: 16 } : null;
    },
    aan: function () { rondje(); }
  });
  var el = document.querySelector('[data-hot="karhot"]');
  if (el && !el.__sleep) {
    el.__sleep = 1;
    C.sleep(el, {
      dropSel: '[data-drop="deur"],[data-drop="bak"]',
      ghostHTML: function () { return '<div class="karghost">🛒</div>'; },
      onDrop: function (t) {
        if (t.getAttribute('data-drop') === 'deur') duwNaar(t.getAttribute('data-h-naar'));
        else lever(t.getAttribute('data-h-kamer'), t.getAttribute('data-h-slot'));
      },
      onTap: function () { rondje(); }
    });
  }
}

/* Zolang de kar vol is, is het BAKJE van het hotel even van de voerkar:
   tikken betekent dan "hier afleveren". */
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
  rondje();
}

/* het bakje vullen: de dieren van die kamer lopen erheen en smullen */
function lever(kamerId, slotId) {
  var kar = C.wereld.ding('kar');
  if (!kar || kar.kamer !== kamerId) {
    C.ui.wolk('kar', { id: 'vk_hier', door: 'voerkar', icoon: '🛒', tekst: 'duw mij hierheen',
                       klas: 'hulp', hoog: 24 });
    return;
  }
  var hier = gasten().filter(function (g) { return g.kamer === kamerId; });
  if (!hier.length || K.geleverd[kamerId]) return;
  var samen = 0;
  hier.forEach(function (g) { samen += K.vak[g.id] || 0; K.vak[g.id] = 0; });
  K.geleverd[kamerId] = samen;
  C.wereld.setBak(kamerId, slotId, 4);
  hier.forEach(function (g) { g.gegeten = true; g.behoefte = 'spelen'; g.blij = false; });
  C.wereld.feest(hier.map(function (g) { return g.id; }));
  C.snd.plop(3);
  C.ui.wolk(hier[0].id, { id: 'vk_smul', door: 'voerkar', icoon: '😋', getal: K.per, klas: 'goed' });
  setTimeout(function () { if (C) C.ui.wolkWeg('vk_smul'); }, 2600);
  C.state.bewaar();
  if (window.Hotel) Hotel.render();
  rondje();
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
