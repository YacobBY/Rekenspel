/* ---------------------------------------------------------------
   econ.js - munten, sterren en DE REKENING bij het uitchecken.

   De muntenlade komt regelrecht uit de zadelwinkel van Zilverhoef
   (demos/silverhoof/shop.js): dezelfde buidel-opbouw, hetzelfde
   samen-tellen, dezelfde spookmunten na de derde poging en hetzelfde
   getallenlijntje. Hele euro's, bedragen t/m 20 (groep 3-5), nooit
   een rood kruis en de familie wacht geduldig.

   Publiek:
     Econ.rekening(o)  - het hele afrekenmoment (nachten x prijs)
     Econ.buidel(n)    - munten waarmee ELK bedrag t/m n te leggen is
     Econ.splits(n)    - n als losse munten (10/5/2/1)
     Econ.munt(v)      - html van één munt
     Econ.sterren(n)   - sterren erbij (voor meedoen, altijd)
---------------------------------------------------------------- */
var Econ = (function () {
'use strict';

var woord = Ui.woord;

/* Buidel: van klein naar groot opbouwen zodat ELK bedrag t/m het totaal
   precies te leggen is (elke munt is hooguit 1 meer dan alles wat er al
   ligt). Het biljet van 10 komt er pas in als de losse munten al 9 halen. */
var DENOMS = [10, 5, 2, 1];
function buidel(total) {
  var rest = total, som = 0, out = [], guard = 0;
  while (rest > 0 && guard++ < 60) {
    var d = 1, i;
    for (i = 0; i < DENOMS.length; i++) {
      if (DENOMS[i] <= rest && DENOMS[i] <= som + 1) { d = DENOMS[i]; break; }
    }
    out.push(d); som += d; rest -= d;
  }
  out.sort(function (a, b) { return b - a; });
  return out.map(function (v, k) { return { v: v, id: 'c' + k + '_' + v }; });
}

function splits(n) {
  var out = [], r = n;
  while (r >= 10) { out.push(10); r -= 10; }
  while (r >= 5) { out.push(5); r -= 5; }
  while (r >= 2) { out.push(2); r -= 2; }
  while (r >= 1) { out.push(1); r -= 1; }
  return out;
}

function munt(v, extra, id) {
  return '<div class="coin ' + (v === 10 || v === 20 ? 'note' : 'c' + v) + (extra ? ' ' + extra : '') +
    '"' + (id ? ' data-coin="' + id + '"' : '') + '>€' + v + '</div>';
}
function som(arr) { return arr.reduce(function (a, c) { return a + c.v; }, 0); }

/* =====================================================================
   DE REKENING
   o = { gast, nachten, prijs, totaal, betaald, onKlaar(uit) }
===================================================================== */
var R = null;

function rekening(o) {
  var tot = o.totaal || o.nachten * o.prijs;
  R = {
    gast: o.gast, nachten: o.nachten, prijs: o.prijs, totaal: tot,
    hand: buidel(o.betaald === undefined ? tot : o.betaald),
    bank: [],
    stap: 1,            /* 1 = som uitrekenen, 2 = munten tellen, 3 = wisselgeld */
    pogingen: 0, wissel: 0, wisselPog: 0,
    fam: o.fam || 'de familie',
    onKlaar: o.onKlaar,
    t0: Ui.nu(), klaar: false
  };
  R.pad = Ui.pad({ max: 2, euro: true, onOk: function (n) { somOk(n); } });
  R.wpad = Ui.pad({ max: 2, euro: true, onOk: function (n) { wisselOk(n); } });
  paint();
  return R;
}

function paint() {
  if (!R) return;
  var g = R.gast, h = '';
  h += '<h1>💰 De rekening</h1>';
  h += '<div class="opdracht"><p><b>Familie ' + esc(R.fam) + '</b> komt <b>' + esc(g.naam) +
    '</b> ophalen. ' + esc(g.naam) + ' heeft <b>' + meervoud(R.nachten, 'nacht', 'nachten') +
    '</b> geslapen. Eén nacht kost <b>€' + R.prijs + '</b>.</p></div>';

  if (R.stap === 1) {
    h += '<div class="qbox"><h2>Wat moet de familie betalen?</h2>' +
      '<div class="somregel"><b>' + R.nachten + ' × €' + R.prijs + ' =</b></div>' +
      R.pad.html();
    if (R.pogingen === 1) h += '<div class="soft-note">Tel de nachten met sprongen van ' + R.prijs +
      ' mee: ' + Ui.telMee(R.prijs, R.nachten) + '</div>';
    if (R.pogingen >= 2) {
      h += '<div class="soft-note">Kijk, ik leg elke nacht apart neer:' +
        '<div class="counton">' + nachtRij() + '</div>' +
        'Dat is samen <b>€' + R.totaal + '</b>.</div>';
    }
    h += '</div>';
  } else {
    h += '<div class="good">De rekening is <b>€' + R.totaal + '</b>. ' + R.nachten + ' × €' +
      R.prijs + ' = €' + R.totaal + '.</div>';
    h += '<div class="counter-wrap"><div class="counter-label">🧾 De toonbank</div>' +
      '<div class="counter' + (R.bank.length ? ' vol' : '') + '" data-drop="toonbank" id="toonbank">' +
      '<div class="counter-coins">' + R.bank.map(function (c) { return munt(c.v, 'pulse', c.id); }).join('') +
      (R.bank.length ? '' : '<span class="purse-empty">Leg de munten hier neer</span>') + '</div>' +
      '<div class="ghosts" id="spoken">' + (R.spook || '') + '</div>' +
      '<div class="counter-total">samen: <b>€' + som(R.bank) + '</b></div></div></div>';
    h += '<div class="purse-wrap"><div class="purse-title">🐾 Wat de familie geeft ' +
      '<span class="hint">(sleep naar de toonbank, of tik erop)</span></div>' +
      '<div class="purse" id="hand">' +
      (R.hand.length ? R.hand.map(function (c) { return munt(c.v, '', c.id); }).join('')
                     : '<span class="purse-empty">De familie heeft alles neergelegd.</span>') +
      '</div></div>';
    if (R.stap === 3) {
      h += '<div class="qbox"><h2>Hoeveel krijgt de familie terug?</h2>' +
        '<p>Er ligt <b>€' + som(R.bank) + '</b> op de toonbank en de rekening is <b>€' +
        R.totaal + '</b>.</p>' + R.wpad.html();
      if (R.wisselPog === 1) h += '<div class="soft-note">Bijna! Tel van <b>€' + R.totaal +
        '</b> naar <b>€' + som(R.bank) + '</b>. Hoeveel stapjes zijn dat?</div>';
      if (R.wisselPog >= 2) h += '<div class="soft-note">Tel de roze stapjes maar: van ' +
        woord(R.totaal) + ' naar ' + woord(som(R.bank)) + '.' + Ui.getallenlijn(R.totaal, som(R.bank)) + '</div>';
      h += '</div>';
    }
    h += '<div class="row center" style="margin-top:14px">' +
      '<button class="btn go big" type="button" id="rekOk">' +
      (R.stap === 3 ? 'Dit geef ik terug ✓' : 'Klaar met tellen ✓') + '</button>' +
      '<button class="btn soft" type="button" id="rekTerug">Opnieuw ↺</button></div>';
    if (R.pogingen >= 1 || R.wisselPog >= 1)
      h += '<p class="hint" style="text-align:center;margin-top:8px">' +
        'Rustig aan, de familie wacht gewoon. Er gaat niets kapot. 💛</p>';
  }
  Ui.paneel(h, 'rek');
  wire();
}

function nachtRij() {
  var s = '', i;
  for (i = 0; i < R.nachten; i++) s += '<span class="scoop">🌙 €' + R.prijs + '</span>';
  return s + '<b>=</b><span class="somvak"></span>';
}

function wire() {
  if (!R) return;
  var root = $('#paneel');
  if (!root) return;
  if (R.stap === 1) { R.pad.wire(root, paint); return; }
  if (R.stap === 3) R.wpad.wire(root, paint);
  /* munten van de familie naar de toonbank: slepen of tikken */
  $$('#hand [data-coin]', root).forEach(function (node) {
    var id = node.getAttribute('data-coin');
    makeDraggable(node, {
      dropSel: '[data-drop="toonbank"]',
      ghostHTML: function () { return node.outerHTML; },
      onDrop: function () { legNeer(id); },
      onTap: function () { legNeer(id); }
    });
  });
  $$('#toonbank [data-coin]', root).forEach(function (node) {
    node.onclick = function () { pakTerug(node.getAttribute('data-coin')); };
  });
  var ok = $('#rekOk'); if (ok) ok.onclick = function () { klaarMetTellen(); };
  var tg = $('#rekTerug');
  if (tg) tg.onclick = function () {
    while (R.bank.length) R.hand.push(R.bank.pop());
    R.hand.sort(function (a, b) { return b.v - a.v; });
    R.stap = 2; R.spook = ''; R.wpad.wis();
    paint();
    toast('Geeft niks, we beginnen opnieuw. 💛', 'kind');
  };
}

function legNeer(id) {
  for (var i = 0; i < R.hand.length; i++) {
    if (R.hand[i].id === id) {
      R.bank.push(R.hand.splice(i, 1)[0]);
      if (window.Snd) Snd.munt();
      var s = som(R.bank);
      paint();
      toast('Zo ja… dat is samen ' + woord(s) + '.', 'kind');
      return;
    }
  }
}
function pakTerug(id) {
  for (var i = 0; i < R.bank.length; i++) {
    if (R.bank[i].id === id) {
      R.hand.push(R.bank.splice(i, 1)[0]);
      R.hand.sort(function (a, b) { return b.v - a.v; });
      if (window.Snd) Snd.terug();
      R.stap = R.stap === 3 ? 2 : R.stap;
      paint();
      return;
    }
  }
}

function somOk(n) {
  if (n === null) { toast('Tik eerst een getal, dan kijken we samen. 🙂', 'kind'); return; }
  if (n === R.totaal) {
    if (window.State) State.tel(R.pogingen === 0, Ui.nu() - R.t0);
    R.stap = 2; R.pad.wis();
    paint();
    if (window.Snd) Snd.ja();
    toast('Precies! De rekening is €' + R.totaal + '. 🎉', 'happy');
    return;
  }
  R.pogingen++;
  R.pad.wis();
  paint();
  if (window.Snd) Snd.zacht();
  toast('Tel de nachten met sprongen mee. 💛', 'kind');
}

function klaarMetTellen() {
  if (R.stap === 3) { wisselOk(R.wpad.getal()); return; }
  var t = som(R.bank), p = R.totaal;
  if (t === p) { gelukt(0); return; }
  if (t < p) {
    R.pogingen++;
    var rest = p - t;
    toast('Dat is ' + woord(t) + '… nog ' + woord(rest) + ' erbij?', 'kind');
    if (R.pogingen >= 3) {
      R.spook = '<div class="hint-lbl">nog nodig: €' + rest + '</div>' +
        splits(rest).map(function (v) { return munt(v, 'ghost'); }).join('');
      paint();
      toast('Kijk, zó ziet ' + woord(rest) + ' eruit. Leg die er maar bij.', 'kind');
    } else paint();
    if (window.Snd) Snd.zacht();
    return;
  }
  R.stap = 3; R.wisselPog = 0; R.wpad.wis(); R.spook = ''; R.tw = Ui.nu();
  paint();
  toast('Er ligt meer dan de rekening — hoeveel krijgt de familie terug?', 'kind');
}

function wisselOk(n) {
  var goed = som(R.bank) - R.totaal;
  if (n === null) { toast('Tik eerst een getal, dan kijken we samen. 🙂', 'kind'); return; }
  if (n === goed) {
    if (window.State) State.tel(R.wisselPog === 0, Ui.nu() - (R.tw || R.t0));
    gelukt(goed);
    return;
  }
  R.wisselPog++;
  R.wpad.wis();
  if (R.wisselPog >= 3) {
    R.spook = '<div class="hint-lbl">dit krijgt de familie terug: €' + goed + '</div>' +
      splits(goed).map(function (v) { return munt(v, 'ghost'); }).join('');
  }
  paint();
  if (window.Snd) Snd.zacht();
  toast('Tel van €' + R.totaal + ' naar €' + som(R.bank) + '. 💛', 'kind');
}

function gelukt(wissel) {
  var uit = { totaal: R.totaal, betaald: som(R.bank), wissel: wissel,
              pogingen: R.pogingen + R.wisselPog, gast: R.gast };
  R.klaar = true;
  if (window.Snd) Snd.tover();
  var cb = R.onKlaar;
  var g = R.gast;
  var h = '<h1>💰 Betaald!</h1><div class="good">' +
    (wissel > 0
      ? 'Precies! ' + Ui.hoofd(woord(wissel)) + ' euro terug, alsjeblieft. De rekening van €' +
        R.totaal + ' is betaald.'
      : 'Helemaal precies! €' + R.totaal + ' betaald, geen wisselgeld nodig.') +
    '</div><p>' + esc(g.naam) + ' gaat met familie ' + esc(R.fam) + ' naar huis. 👋</p>' +
    '<div class="row center"><button class="btn go big" type="button" id="rekAf">Verder ▸</button></div>';
  Ui.paneel(h, 'rek');
  var b = $('#rekAf');
  if (b) b.onclick = function () { R = null; if (cb) cb(uit); };
  return uit;
}

function sterren(n, waarvoor) {
  if (window.geefSter) geefSter(n || 1, waarvoor);
  if (window.Snd) Snd.ster();
  return state ? state.sterren : 0;
}

return { rekening: rekening, buidel: buidel, splits: splits, munt: munt,
         som: som, sterren: sterren,
         stand: function () { return R; } };
})();
