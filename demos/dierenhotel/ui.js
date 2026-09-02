/* ui.js - kleine helpers: selecteren, toast, sheet en slepen met pointer events */
function $(sel, root) { return (root || document).querySelector(sel); }
function $$(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

function esc(s) {
  return String(s).replace(/[&<>"]/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
  });
}

function meervoud(n, een, veel) { return n === 1 ? n + ' ' + een : n + ' ' + veel; }

/* 'de bezorger brengt de brokken' -> 'De bezorger brengt de brokken' */
function hoofdletter(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s; }

var _toastT = null;
function toast(msg, kind) {
  var t = $('#toast');
  t.textContent = msg;
  t.className = 'toast ' + (kind || '');
  clearTimeout(_toastT);
  _toastT = setTimeout(function () { t.className = 'toast hidden'; }, 2600);
}

function openSheet(html) {
  var o = $('#overlay');
  $('#sheet').innerHTML = html;
  o.classList.remove('hidden');
  o.setAttribute('aria-hidden', 'false');
  return $('#sheet');
}
function closeSheet() {
  var o = $('#overlay');
  o.classList.add('hidden');
  o.setAttribute('aria-hidden', 'true');
  $('#sheet').innerHTML = '';
}
document.addEventListener('click', function (e) {
  if (e.target && e.target.id === 'overlay') closeSheet();
});

function shake(node) {
  if (!node) return;
  node.classList.remove('wiggle');
  void node.offsetWidth;
  node.classList.add('wiggle');
}

/* ---------------------------------------------------------------
   dragKit: werkt met muis, pen en vinger (pointer events).
   opts = { ghostHTML(), dropSel, canDrag(), onDrop(target), onTap() }
   Kleine beweging telt als tik -> ook bruikbaar zonder slepen.
---------------------------------------------------------------- */
function makeDraggable(node, opts) {

  function targetAt(x, y) {
    var e = document.elementFromPoint(x, y);
    return e && e.closest ? e.closest(opts.dropSel) : null;
  }

  node.addEventListener('pointerdown', function (ev) {
    if (opts.canDrag && !opts.canDrag()) return;
    if (ev.button !== undefined && ev.button !== 0) return;

    var sx = ev.clientX, sy = ev.clientY, pid = ev.pointerId;
    var ghost = null, hot = null, dragging = false;
    ev.preventDefault();
    /* capture is fijn, maar we luisteren op window zodat het ook zonder werkt */
    try { node.setPointerCapture(pid); } catch (e) { /* geeft niet */ }

    function stop() {
      window.removeEventListener('pointermove', move, true);
      window.removeEventListener('pointerup', up, true);
      window.removeEventListener('pointercancel', cancel, true);
      document.body.classList.remove('sleept');
      if (ghost && ghost.parentNode) ghost.parentNode.removeChild(ghost);
      if (hot) hot.classList.remove('drop-hot');
      ghost = null; hot = null;
    }

    function move(e2) {
      if (e2.pointerId !== pid) return;
      var dx = e2.clientX - sx, dy = e2.clientY - sy;
      if (!dragging && dx * dx + dy * dy < 64) return;
      if (!dragging) {
        dragging = true;
        /* tijdens het slepen mogen geplaatste blokjes de vakjes eronder niet afschermen */
        document.body.classList.add('sleept');
        ghost = document.createElement('div');
        ghost.className = 'ghost';
        ghost.innerHTML = opts.ghostHTML ? opts.ghostHTML() : node.outerHTML;
        document.body.appendChild(ghost);
      }
      ghost.style.left = e2.clientX + 'px';
      ghost.style.top = e2.clientY + 'px';
      var t = targetAt(e2.clientX, e2.clientY);
      if (t !== hot) {
        if (hot) hot.classList.remove('drop-hot');
        hot = t;
        if (hot) hot.classList.add('drop-hot');
      }
    }

    function up(e2) {
      if (e2.pointerId !== pid) return;
      var wasDrag = dragging;
      var t = wasDrag ? targetAt(e2.clientX, e2.clientY) : null;
      stop();
      if (wasDrag) { if (t && opts.onDrop) opts.onDrop(t); }
      else if (opts.onTap) opts.onTap();
    }

    function cancel(e2) { if (e2.pointerId === pid) stop(); }

    window.addEventListener('pointermove', move, true);
    window.addEventListener('pointerup', up, true);
    window.addEventListener('pointercancel', cancel, true);
  });
}

/* =====================================================================
   UI - de vaste gereedschapskist voor het hotel en voor elke minigame.
   Alles wat een spel op het scherm nodig heeft staat hier één keer:
   een schoolschrift-paneel, een cijfertoetsenbord, samen-tellen en een
   voorgedaan voorbeeld (buurvrouw Els legt het even neer).
===================================================================== */
var Ui = (function () {
'use strict';

var WOORD = ['nul', 'een', 'twee', 'drie', 'vier', 'vijf', 'zes', 'zeven', 'acht', 'negen', 'tien',
  'elf', 'twaalf', 'dertien', 'veertien', 'vijftien', 'zestien', 'zeventien', 'achttien',
  'negentien', 'twintig'];
function woord(n) { return (n >= 0 && n <= 20) ? WOORD[n] : String(n); }
function hoofd(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s; }

/* ---------- het paneel onder (of naast) de wereld ----------
   Eén plek waar een spel zijn rekenblad neerzet. Het is nooit een
   scherm dat de wereld afsluit: de kamer blijft altijd in beeld. */
function paneel(html, klas) {
  var host = $('#scene');
  if (!host) return null;
  host.innerHTML = '<div class="card ' + (klas || '') + '" id="paneel">' + html + '</div>';
  return $('#paneel');
}
function leegPaneel() {
  var host = $('#scene');
  if (host) host.innerHTML = '';
}
function inPaneel() { var h = $('#scene'); return !!(h && h.firstChild); }

/* ---------- cijfertoetsenbord (zoals de poortvraag) ----------
   p = Ui.pad({max:2, eenheid:'scheppen', onOk:fn});
   ...html: p.html()   ...na elke herteken: p.wire(rootEl, hertekenFn)  */
function pad(o) {
  o = o || {};
  var st = { val: o.waarde || '' };
  var api = {
    val: function () { return st.val; },
    getal: function () { return st.val === '' ? null : parseInt(st.val, 10); },
    wis: function () { st.val = ''; },
    zet: function (v) { st.val = String(v || ''); },
    html: function () {
      var toon = st.val === '' ? '?' : (o.euro ? '€' + st.val : st.val);
      var h = '<div class="somregel"><span class="answer" data-padshow>' + esc(toon) + '</span>' +
        (o.eenheid ? '<span>' + esc(o.eenheid) + '</span>' : '') + '</div><div class="pad">';
      [1, 2, 3, 4, 5, 6, 7, 8, 9].forEach(function (k) {
        h += '<button class="btn" type="button" data-pk="' + k + '">' + k + '</button>';
      });
      h += '<button class="btn del" type="button" data-pk="del">⌫</button>' +
        '<button class="btn" type="button" data-pk="0">0</button>' +
        '<button class="btn ok" type="button" data-pk="ok">✓</button></div>';
      return h;
    },
    wire: function (root, herteken) {
      $$('[data-pk]', root || document).forEach(function (b) {
        b.onclick = function () {
          var k = b.getAttribute('data-pk');
          if (k === 'del') st.val = st.val.slice(0, -1);
          else if (k === 'ok') { if (o.onOk) o.onOk(api.getal(), api); return; }
          else if (st.val.length < (o.max || 2)) st.val += k;
          if (herteken) herteken();
          else {
            var el = $('[data-padshow]', root || document);
            if (el) el.textContent = st.val === '' ? '?' : (o.euro ? '€' + st.val : st.val);
          }
        };
      });
    }
  };
  return api;
}

/* ---------- samen tellen: 5 … 10 … 15 (nooit "fout", altijd meetellen) ---------- */
function telMee(stap, aantal, staart) {
  var l = [], s = 0, i;
  for (i = 0; i < aantal; i++) { s += stap; l.push(s); }
  return l.join(' … ') + (staart || '.');
}
function telRij(n, icoon) {
  var s = '', i;
  for (i = 0; i < n; i++) s += '<span class="scoop">' + (icoon || '🥄') + '</span>';
  return s;
}
/* de getallenlijn met roze stapjes, net als in de winkel van Zilverhoef */
function getallenlijn(van, tot) {
  var h = '<div class="numline">', n;
  if (tot - van > 24) return '';
  for (n = van; n <= tot; n++)
    h += '<i class="' + (n > van ? 'hit' : '') + '">' + n + '</i>';
  return h + '</div>';
}

/* ---------- voorgedaan voorbeeld: het staat er even, dan doe je het zelf ----------
   o = { titel, regels:[{wie, inhoud}], slot, telmee, knop, onOk } */
function voorbeeld(o) {
  var h = '<h2>' + (o.icoon || '🩺') + ' ' + esc(o.titel || 'Kijk, zo doe je het') + '</h2>';
  if (o.intro) h += '<p>' + o.intro + '</p>';
  if (o.regels && o.regels.length) {
    h += '<div class="tray">';
    o.regels.forEach(function (r) {
      h += '<div class="trayrow"><span class="who">' + esc(r.wie) + '</span>' + r.inhoud + '</div>';
    });
    h += '</div>';
  }
  if (o.slot) h += '<p>' + o.slot + '</p>';
  if (o.telmee) h += '<p class="hint">Tel maar mee met mij: ' + o.telmee + '</p>';
  h += '<div class="row center"><button class="btn go big" type="button" id="vbOk">' +
    esc(o.knop || 'Ik snap het – ik doe het zelf! ▸') + '</button></div>';
  openSheet(h);
  if (window.Snd) Snd.brief();
  var b = $('#vbOk');
  if (b) b.onclick = function () { closeSheet(); if (o.onOk) o.onOk(); };
}

/* ---------- hulp na 2 seconden ----------
   Alleen memoriseer-items (splitsingen t/m 10, tafels) krijgen een
   venster van 2 seconden, en dat bepaalt ALLEEN of er hulp verschijnt.
   Er is nooit een zichtbare klok en het antwoord blijft altijd goed. */
function hulpNa2s(fn) {
  var t = setTimeout(function () { t = null; if (fn) fn(); }, 2000);
  return function () { if (t) { clearTimeout(t); t = null; } };
}

/* ---------- kleine dingen ---------- */
function chip(tekst, klas) { return '<div class="chip ' + (klas || '') + '">' + tekst + '</div>'; }
function nuMs() { return (window.performance && performance.now) ? performance.now() : Date.now(); }

return { paneel: paneel, leegPaneel: leegPaneel, inPaneel: inPaneel,
         pad: pad, telMee: telMee, telRij: telRij, getallenlijn: getallenlijn,
         voorbeeld: voorbeeld, hulpNa2s: hulpNa2s, chip: chip,
         woord: woord, hoofd: hoofd, esc: esc, toast: toast,
         sheet: openSheet, sluit: closeSheet, nu: nuMs };
})();
