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
  /* Zolang het blad open staat schuift de pagina eronder niet mee. Zonder dit
     duwt een vinger op een telefoon het hele hotel weg achter het blad, en dan
     staat de kamer scheef als het blad weer dichtgaat. */
  document.documentElement.classList.add('sheet-open');
  return $('#sheet');
}
function closeSheet() {
  var o = $('#overlay');
  o.classList.add('hidden');
  o.setAttribute('aria-hidden', 'true');
  $('#sheet').innerHTML = '';
  document.documentElement.classList.remove('sheet-open');
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

   Met een VINGER staat het sleepplaatje 40 px boven de vingertop en wordt het
   doel daar gemeten, niet onder de vinger: anders hou je je eigen bakje af en
   zie je niet waar het koekje heen gaat. Met de muis blijft alles zoals het was.
---------------------------------------------------------------- */
/* hoeveel het sleepplaatje boven de vingertop hangt */
var VINGER_LIFT = 40;
/* de speling waarbinnen het nog een tik is (8 px, dus 64 = 8*8) */
var TIK_SPELING = 64;

/* Eén tik = één keer afleveren. Na een tik met de vinger stuurt de browser óók
   nog een 'click' naar dezelfde knop, en die knop heeft via de hotspot-laag
   zijn eigen klik-handler: zonder poortwachter legt één tik twee koekjes neer.
   We vangen die ene click in de capture-fase van het venster (dus vóórdat de
   knop zelf hem ziet) en laten hem vallen. Het oude vangnetje in de spellen
   (__bronTik) mag blijven staan - we zetten het meteen terug op 0 zodat het
   nooit een echte tik tegenhoudt. */
function slikEenKlik(node) {
  var t0 = null;
  function weg() { window.removeEventListener('click', eet, true); clearTimeout(t0); }
  function eet(ev) {
    weg();
    var d = ev.target;
    if (d !== node && !(node.contains && node.contains(d))) return;
    ev.stopImmediatePropagation();
    ev.preventDefault();
    node.__bronTik = 0;
    /* het zachte tikje van game.js hangt aan de click; die valt nu weg, dus
       geven we hem hier - een knop zonder tikje voelt kapot */
    if (window.Snd && Snd.tik && node.closest && node.closest('.btn,.hot,.kchip')) Snd.tik();
  }
  t0 = setTimeout(weg, 400);
  window.addEventListener('click', eet, true);
}

function makeDraggable(node, opts) {

  function targetAt(x, y) {
    var e = document.elementFromPoint(x, y);
    return e && e.closest ? e.closest(opts.dropSel) : null;
  }

  /* een lange druk op een plaatje of een woord opent op de telefoon het menu
     "Kopiëren / Delen"; hier sleep je, dus dat menu hoort er niet te zijn */
  node.addEventListener('contextmenu', function (ev) { ev.preventDefault(); });

  node.addEventListener('pointerdown', function (ev) {
    if (opts.canDrag && !opts.canDrag()) return;
    if (ev.button !== undefined && ev.button !== 0) return;

    var sx = ev.clientX, sy = ev.clientY, pid = ev.pointerId;
    var lift = ev.pointerType === 'touch' ? VINGER_LIFT : 0;
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
      if (!dragging && dx * dx + dy * dy < TIK_SPELING) return;
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
      ghost.style.top = (e2.clientY - lift) + 'px';
      var t = targetAt(e2.clientX, e2.clientY - lift);
      if (t !== hot) {
        if (hot) hot.classList.remove('drop-hot');
        hot = t;
        if (hot) hot.classList.add('drop-hot');
      }
    }

    function up(e2) {
      if (e2.pointerId !== pid) return;
      var wasDrag = dragging;
      var t = wasDrag ? targetAt(e2.clientX, e2.clientY - lift) : null;
      stop();
      if (wasDrag) { if (t && opts.onDrop) { opts.onDrop(t); slikEenKlik(node); } }
      else if (opts.onTap) { opts.onTap(); slikEenKlik(node); }
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
  /* met een blad ernaast wordt het diorama kleiner; zonder blad mag de
     wereld het hele scherm hebben (HOTEL.md 9) */
  document.body.classList.add('metpaneel');
  return $('#paneel');
}
function leegPaneel() {
  var host = $('#scene');
  if (host) host.innerHTML = '';
  document.body.classList.remove('metpaneel');
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

/* =====================================================================
   REKENEN ÍN DE WERELD  (HOTEL.md 9)
   Geen rekenpaneel naast het diorama meer: sommen, aantallen en keuzes
   hangen als kleine wolkjes en kaartjes aan een voorwerp of een dier.
   Elke sommenkaart draagt één gewone zin (richtlijn: 8 woorden, met een
   werkwoord of een vraagwoord, pictogram vóór de zin op dezelfde regel)
   vlak boven de som: een kale som staat er nooit alleen (speeltest: het
   kind kon "4 × 2 ? 20" niet lezen). Keuzes zijn knoppen mét woord in één
   strook aan de kaart, nooit losse pictogrammen door de kamer. Alles gaat
   via de hotspot-laag, dus het schuift automatisch mee met de camera,
   wijkt uit voor andere knoppen en blijft in beeld.
===================================================================== */
var wolkNr = 0, somNr = 0;

/* ---------- spreekwolkje aan een voorwerp of dier ----------
   Ui.wolk('boef', { icoon:'🍪', getal:2, tekst:'nog twee', tik:fn })   */
function wolk(obj, o) {
  o = o || {};
  var p = World.mik(obj, o.kamer);
  if (!p) return null;
  var id = o.id || ('wolk_' + (typeof obj === 'string' ? obj : 'x' + (++wolkNr)));
  var hoog = o.hoog === undefined ? (p.dier ? 52 : 20) : o.hoog;
  var tekst = o.tekst === undefined || o.tekst === null ? '' : String(o.tekst);
  var getal = o.getal === undefined || o.getal === null ? '' : String(o.getal);
  var zeg = (o.icoon ? o.icoon + ' ' : '') + (getal ? getal + ' ' : '') + tekst;
  Hits.maak({
    id: id, door: o.door || 'wolk', kamer: p.kamer, x: p.x, z: p.z, y: hoog,
    klas: 'hotwolk' + (o.klas ? ' ' + o.klas : ''),
    html: '<span class="ico">' + (o.icoon || '') + '</span>' +
          (getal ? '<span class="get">' + esc(getal) + '</span>' : '') +
          (tekst ? '<span class="zeg">' + esc(tekst) + '</span>' : ''),
    titel: zeg || 'praatje', prio: o.prio === undefined ? 9 : o.prio,
    /* loopt het dier naar een andere kamer, dan gaat het wolkje mee */
    volg: p.volg ? function () {
      var q = p.volg();
      return q ? { x: q.x, z: q.z, y: hoog, kamer: q.kamer } : null;
    } : null,
    /* Tikken leest het wolkje voor - alleen als het kind daar zelf op tikt. */
    aan: function () { if (o.tik) o.tik(); else spreek(zeg); }
  });
  return id;
}
function wolkWeg(id) { Hits.weg(id); }

/* ---------- het kader in de gaten houden ----------
   Verandert de maat van het kader (kantelen, adresbalk die wegschuift, een
   spel dat een rekenblad naast de wereld zet), dan moet alles wat in
   SCHERMpixels is uitgemeten opnieuw gelegd worden.
   world.js krijgt daar één nette bron voor: World.onKader(fn) - één ontdenderde
   melding uit een ResizeObserver op #world, die een opzegger teruggeeft. Zolang
   die er niet is doen we het zelf met resize + orientationchange, achter
   precies dezelfde deur. Zo werkt de code vóór én na die samenvoeging. */
function opKader(fn) {
  if (window.World && typeof World.onKader === 'function') {
    try {
      var af = World.onKader(fn);
      if (typeof af === 'function') return af;
    } catch (e) { /* dan doen we het zelf */ }
  }
  var t = null;
  function op() { clearTimeout(t); t = setTimeout(function () { t = null; fn(); }, 90); }
  window.addEventListener('resize', op);
  window.addEventListener('orientationchange', op);
  return function () {
    clearTimeout(t);
    window.removeEventListener('resize', op);
    window.removeEventListener('orientationchange', op);
  };
}

/* ---------- de schil is van maat veranderd ----------
   Zet de schil iets neer of weg dat hoogte kost (de cijferstrook), dan is er
   plotseling meer of minder over voor het kader en moet world.js zijn kader
   opnieuw OPMETEN - niet alleen opnieuw tekenen.
   Sinds M1b is opmeten World.hermeet(); World.vuil() vraagt daar alleen nog een
   nieuwe tekenbeurt. Vóór M1b deed vuil() beide, dus die is de terugval. */
function schilVeranderd() {
  if (window.World && typeof World.hermeet === 'function') {
    try { World.hermeet(); return; } catch (e) { /* dan de terugval */ }
  }
  if (window.World && typeof World.vuil === 'function') {
    try { World.vuil(); } catch (e) { /* geeft niet */ }
  }
}

/* ---------- klein cijferpad, verankerd aan het voorwerp ----------
   Het enige 2D-ding dat mag (HOTEL.md 9): twee rijen van zes toetsen,
   elke toets minstens 48 px, en het staat vlak onder de sommenkaart. */
/* Twee rijen van zes op een telefoon; op een breed scherm passen alle
   toetsen op één rij, en dan is het pad half zo hoog en dekt het de vloer
   van de kamer niet af. */
var PAD_KEYS = ['1', '2', '3', '4', '5', 'del', '6', '7', '8', '9', '0', 'ok'];
function kaderEl() { return document.getElementById('world'); }
function padBreed() {
  var w = kaderEl();
  return !!(w && w.clientWidth >= 660);
}
/* Onder deze kaderhoogte past een pad niet meer ÍN het kader.
   Gemeten op een liggende telefoon (844x390, vóór M1a): kader 820x200, pad
   638x66 middenin het kader - dat lag over de sommenkaart, over de deurknop
   en over het prikbord (4 botsingen). Bij zo'n laag kader hoort het pad als
   strook ONDER het kader, over de volle breedte.

   KADER_RUIM is de terugweg, en die ligt hoger: de cijferstrook staat ín de
   pagina, dus zodra hij zichtbaar wordt krimpt het kader. Meet je dan opnieuw
   met dezelfde grens, dan wil het pad weer naar binnen, krimpt het kader weer
   niet meer, wil het weer naar buiten... (nagemeten met een ResizeObserver op
   #world: 44 wissels in 5 seconden op 750x342). Vandaar drie sloten:
     1. we meten de kaderhoogte ZONDER onze eigen strook (kaderHoogVrij),
     2. een dode zone tussen 300 en 340 px,
     3. onze eigen wissel maakt zelf een kadermelding: die negeren we even
        (VERSTIL_MS), en per schermmaat wisselen we hooguit WISSEL_MAX keer.
        Daarna blijft het staan waar het staat; "buiten" is altijd veilig,
        want daar botst het pad met niets. */
var KADER_KORT = 300, KADER_RUIM = 340, VERSTIL_MS = 400, WISSEL_MAX = 2;
/* de hoogte die het kader zou hebben zonder onze cijferstrook: de strook staat
   eronder in dezelfde kolom, dus zijn hoogte plus de kier van 4 px komt erbij */
function kaderHoogVrij(strookPx) {
  var w = kaderEl();
  if (!w || !w.clientHeight) return 0;
  return w.clientHeight + (strookPx || 0);
}
/* ... en ook niet als het kader te SMAL is voor één rij van zes toetsen.
   Hoe breed die rij is staat in de opmaak en is opgemeten: onder 360 px zijn de
   toetsen 44 px met 2 px kier (pad 286 px), op 360 px zelf 48 px met 2 px kier
   (310 px) en daarboven 48 px met 4 px kier (326 px). Past die rij niet in het
   kader, dan stak het pad zijwaarts uit (gemeten: kader 259 px binnenwerk, pad
   286 px, 24 px eruit) - en dan hoort het als strook onder het kader. */
function padMinBreed() {
  var w = window.innerWidth;
  if (w < 360) return 286;
  if (w <= 360) return 310;
  return 326;
}
function kaderSmal() {
  var w = kaderEl();
  return !!(w && w.clientWidth > 0 && w.clientWidth < padMinBreed());
}
/* padPlek: 'auto' (standaard) | 'binnen' | 'buiten'
   nu = waar het pad NU staat ('buiten' of iets anders), strookPx = de hoogte
   die onze eigen strook op dit moment inneemt (0 als hij er niet staat). */
function padBuiten(plek, nu, strookPx) {
  if (plek === 'binnen') return false;
  if (plek === 'buiten') return true;
  if (kaderSmal()) return true;               /* te smal: breedte hangt niet aan de strook */
  var h = kaderHoogVrij(strookPx);
  if (!h) return nu === 'buiten';
  /* naar buiten onder 300 px, terug naar binnen pas boven 340 px */
  return nu === 'buiten' ? h < KADER_RUIM : h < KADER_KORT;
}
function padHtml(perRij) {
  var h = '<div class="padrij">', i, k;
  perRij = perRij || 6;
  for (i = 0; i < PAD_KEYS.length; i++) {
    if (i && i % perRij === 0) h += '</div><div class="padrij">';
    k = PAD_KEYS[i];
    h += '<button type="button" class="padk' + (k === 'ok' ? ' ok' : k === 'del' ? ' del' : '') +
      '" data-pk="' + k + '">' + (k === 'del' ? '⌫' : k === 'ok' ? '✓' : k) + '</button>';
  }
  return h + '</div>';
}

/* ---------- de zin boven de som ----------
   Eén gewone Nederlandse zin die de getallen in wereldwoorden noemt, met
   een werkwoord of een vraagwoord erin. Hij hoort ÍN hetzelfde kaartje,
   vlak boven de somregel; het pictogram staat vooraan op diezelfde regel.
   Twee korte zinnen mogen (een tweede regel met bijvoorbeeld de voorraad),
   meer niet: een kaartje is nooit een lap tekst. */
/* Het budget: hooguit 8 woorden EN hooguit 40 tekens. De harde grens is het
   aantal tekens - op een telefoon van 420 px past een zin van ongeveer 34
   tekens naast zijn pictogram op één regel; daarboven breekt hij naar een
   tweede regel (dat mag, meer dan twee regels niet). */
var ZIN_MAX = 8, ZIN_TEKENS = 40;
var zinKlacht = Object.create(null);
function zinLijst(r) {
  var l = (r === undefined || r === null) ? [] : (r.join ? r : [r]);
  var uit = [], i, t;
  for (i = 0; i < l.length && uit.length < 2; i++) {
    t = (l[i] === undefined || l[i] === null) ? '' : String(l[i]).trim();
    if (t) uit.push(t);
  }
  return uit;
}
function woordenTel(t) { return String(t).split(/\s+/).filter(Boolean).length; }
/* De regel is voor games VERPLICHT. We tekenen wel gewoon door - een spel
   halverwege stukmaken is erger - maar we klagen één keer per kaartje in de
   console, zodat een speeltest of nakijkronde het meteen ziet. */
function klaagZin(id, som, zin) {
  if (!window.console || !console.warn) return;
  var k, i;
  if (!zin.length) {
    k = id + '|leeg';
    if (zinKlacht[k]) return;
    zinKlacht[k] = 1;
    console.warn('somkaart "' + id + '" heeft geen regel: de kale som "' + som +
      '" hoort nooit zonder één gewone zin erboven (HOTEL.md 9).');
    return;
  }
  for (i = 0; i < zin.length; i++) {
    if (woordenTel(zin[i]) <= ZIN_MAX && zin[i].length <= ZIN_TEKENS) continue;
    k = id + '|lang' + i;
    if (zinKlacht[k]) continue;
    zinKlacht[k] = 1;
    console.warn('somkaart "' + id + '" heeft een regel van ' + woordenTel(zin[i]) +
      ' woorden en ' + zin[i].length + ' tekens; hooguit ' + ZIN_MAX + ' woorden en ' +
      ZIN_TEKENS + ' tekens (HOTEL.md 9): "' + zin[i] + '"');
  }
}

/* ---------- sommenkaartje aan een voorwerp ----------
   Ui.somkaart('kassa', '3 × €2 =', { regel:'Boef sliep 3 nachten, €5 per nacht',
                                      icoon:'🛏', open:true, onOk:fn })
   Keuzes in plaats van cijfers (dan geen antwoordvakje en geen pad):
   Ui.somkaart('bel', '4 × 2', { regel:[...], keuzes:[{id,icoon,tekst,kies}] })
   padPlek:'auto'|'binnen'|'buiten' - waar het cijferpad hoort. 'auto' (de
   standaard, dus geen enkel spel hoeft iets te veranderen) zet het pad ÍN het
   kader, behalve als het kader lager is dan 300 px: dan komt het als strook
   onder het kader te staan en blijft de kamer vrij.
   Geeft een handvat terug: .regel(zin) .som(tekst) .zet(tekst) .hulp(h)
                            .open() .klaar() .weg()                       */
function somkaart(obj, som, o) {
  o = o || {};
  var p = World.mik(obj, o.kamer);
  if (!p) return null;
  var id = o.id || ('som' + (++somNr));
  var keuzes = (o.keuzes && o.keuzes.length) ? o.keuzes : null;
  var st = { val: '', klaar: false, open: !!o.open && !keuzes, extra: '',
             zin: zinLijst(o.regel) };
  var hoogBasis = o.hoog === undefined ? 22 : o.hoog;
  var hoog = hoogBasis;        /* + lift zodra het pad de kaart zou afdekken */
  /* Het merkteken van DEZE kaart. hotel.js maakt bij elke hertekening een
     nieuwe somkaart onder dezelfde id (ci_som); de hotspot-laag geeft dan
     hetzelfde DOM-knopje terug. Zonder merkteken bleven de luisteraars van de
     oude kaart aan datzelfde knopje hangen en tekenden ze bij het kantelen een
     kaartje terug dat al opgeruimd was. */
  var mij = {};

  function zinHtml() {
    var h = '', i;
    for (i = 0; i < st.zin.length; i++)
      h += '<span class="somzin">' +
           (i === 0 && o.icoon ? '<span class="ico">' + o.icoon + '</span>' : '') +
           esc(st.zin[i]) + '</span>';
    return h;
  }
  /* met keuzes is de strook het antwoord: dan hoort er geen vakje op de
     kaart. Zodra het klaar is komt er alleen een vinkje. */
  function vakHtml() {
    if (keuzes && !st.klaar) return '';
    return '<span class="somvak' + (st.klaar ? ' ok' : '') + '">' +
      (st.klaar ? '✓' : (st.val === '' ? '&nbsp;' : esc(st.val))) + '</span>';
  }
  function kaart() {
    klaagZin(id, som, st.zin);
    var metzin = st.zin.length > 0;
    var s = Hits.maak({
      id: id, door: o.door || 'som', kamer: p.kamer, x: p.x, z: p.z, y: hoog,
      klas: 'hotsom' + (metzin ? ' metzin' : '') + (st.klaar ? ' af' : '') +
            (o.klas ? ' ' + o.klas : ''),
      vast: true, prio: 14,
      html: zinHtml() + (metzin ? '<span class="somrij">' : '') +
            '<span class="somlijn">' + esc(String(som)) + '</span>' + vakHtml() +
            (metzin ? '</span>' : '') +
            (st.extra ? '<span class="somhulp">' + st.extra + '</span>' : ''),
      titel: (st.zin.length ? st.zin.join(' ') + ' ' : '') + String(som) +
             (keuzes ? '' : ' ' + (st.val || '?')),
      aan: function () { if (!st.klaar && !keuzes && o.pad !== false) padAan(); },
      /* Ruimt de hotspot-laag dit kaartje op (Hits.weg of Hits.wisEigenaar),
         dan gaan onze luisteraars en de cijferstrook mee. hits.js roept dit
         zelf aan zodra die kant er is; tot dan doet padOpnieuw hetzelfde werk
         aan de hand van het merkteken hieronder. */
      onWeg: function () { padUit(); }
    });
    if (s && s.el) {
      /* Neemt deze kaart het knopje over van een OUDERE somkaart met dezelfde
         id (hotel.js maakt ci_som bij elke hertekening opnieuw)? Dan zegt die
         oude zijn luisteraars nu meteen op, en niet pas bij het volgende
         kantelen: gemeten hielden tien kaarten onder dezelfde id tien
         kaderluisteraars vast. Zijn strook gaat mee, de nieuwe staat er nog
         niet (kaart() loopt vóór padAan()). */
      var oud = (s.el.__somEig && s.el.__somEig !== mij) ? s.el.__somAf : null;
      s.el.__somEig = mij;
      s.el.__somAf = padUit;
      if (typeof oud === 'function') oud();
    }
  }
  /* Het pad hoort ONDER de kamer te liggen, in de lucht onder de vloer: zo
     dekt het de kamer niet af. We rekenen de hoogte terug uit de onderrand
     van het kamerkader (schermhoogte v = (x+z) - 2y). */
  function padY() {
    if (o.padHoog !== undefined) return o.padHoog;
    var r = Rooms.get(p.kamer);
    var vDoel = (r && r.box ? r.box[3] : 180) + 44;
    return Math.round(((p.x + p.z) - vDoel) / 2);
  }
  /* De kaart mag niet achter zijn eigen cijferpad verdwijnen. Op een smal
     scherm (kader 296x324) is het kader zo laag dat het pad tot over de
     somregel komt; dan tillen we de kaart precies genoeg op. Meten na het
     tekenen, hooguit twee keer - daarna staat het. */
  function kaartVrijStraks() {
    /* hits.js zet de plek pas in de volgende tekenbeurt: eerst laten tekenen */
    if (World.vuil) World.vuil();
    setTimeout(function () { kaartVrij(0); }, 90);
  }
  function kaartVrij(ronde) {
    if (strookVanMij()) return;         /* pad staat buiten: niets af te dekken */
    var k = document.querySelector('[data-hot="' + id + '"]');
    var pd = document.querySelector('[data-hot="' + id + '_pad"]');
    if (!k || !pd) return;
    var rk = k.getBoundingClientRect(), rp = pd.getBoundingClientRect();
    if (!rk.height || !rp.height) return;
    var over = rk.bottom - rp.top + 4;
    if (over <= 0) return;
    var s = World.schaal ? World.schaal() : null;
    var kf = (s && s.k) || 1;
    hoog += Math.ceil(over / (2 * kf));
    kaart();
    if (World.vuil) World.vuil();
    if ((ronde || 0) < 1) setTimeout(function () { kaartVrij(1); }, 90);
  }

  /* ---------- het pad als strook ONDER het kader ----------
     Eén rij van twaalf toetsen over de volle breedte van het speelveld, in
     #padstrip (buiten #world, dus buiten de hotspot-laag). Het draagt wél
     data-hot="<id>_pad": voor een spel, een speeltest of een testsuite is het
     hetzelfde pad, alleen op een andere plek. */
  function strook() { return document.getElementById('padstrip'); }
  function strookVanMij() {
    var s = strook();
    return (s && !s.hidden && s.__eig === mij) ? s : null;
  }
  /* De strook staat BUITEN de hotspot-laag, dus hij gaat niet mee als die laag
     wordt leeggehaald. hotel.js begint elke hertekening met
     Hits.wisEigenaar('checkin'): dan is het kaartje er ineens niet meer en zou
     de cijferstrook alleen achterblijven (gemeten: vraag 2 van de check-in had
     nog een pad). We kijken daarom mee met de hotspot-laag: verdwijnt ons
     kaartje of neemt een andere kaart het over, dan ruimt de strook zich op.
     (Levert hits.js later een onWeg-haak - ticket M1b - dan is dit het vangnet
     ernaast, niet in plaats daarvan.) */
  var strookWacht = null;
  function strookLet() {
    if (strookWacht || !window.MutationObserver) return;
    var host = document.getElementById('worldHits');
    if (!host) return;
    strookWacht = new MutationObserver(function () {
      var el = document.querySelector('[data-hot="' + id + '"]');
      if (el && el.__somEig === mij) return;
      padUit();
    });
    strookWacht.observe(host, { childList: true });
  }
  function strookLetUit() {
    if (!strookWacht) return;
    strookWacht.disconnect();
    strookWacht = null;
  }
  function strookAan() {
    var s = strook();
    if (!s) return false;
    var nieuw = !!s.hidden;             /* stond hij nog weg? dan verandert de schil */
    s.innerHTML = padHtml(12);
    s.setAttribute('data-hot', id + '_pad');
    s.hidden = false;
    s.__eig = mij;
    strookLet();
    s.__aan = padTik;                   /* wie er nu de baas over de strook is */
    if (nieuw) schilVeranderd();        /* de strook kost hoogte: kader hermeten */
    if (!s.__gehaakt) {
      s.__gehaakt = 1;
      s.addEventListener('click', function (ev) {
        var b = ev.target && ev.target.closest ? ev.target.closest('[data-pk]') : null;
        if (!b || !s.__aan) return;
        s.__aan(b.getAttribute('data-pk'));
      });
    }
    return true;
  }
  function strookUit() {
    strookLetUit();
    var s = strookVanMij();
    if (!s) return;
    s.hidden = true;
    s.innerHTML = '';
    s.removeAttribute('data-hot');
    s.__eig = null;
    s.__aan = null;
    schilVeranderd();                   /* er is weer hoogte over: kader hermeten */
  }
  /* één toets, waar het pad ook staat */
  function padTik(k) {
    if (k === 'del') st.val = st.val.slice(0, -1);
    else if (k === 'ok') { if (o.onOk) o.onOk(st.val === '' ? null : parseInt(st.val, 10), api); return; }
    else if (st.val.length < (o.max || 2)) st.val += k;
    kaart();
  }

  /* Kantelt het scherm, dan verandert de vorm van het pad (twee rijen van zes
     op een telefoon, één rij van twaalf op een breed scherm, of een strook
     onder een laag kader). De html van een hotspot blijft anders staan zoals
     hij gemaakt is: een pad van twaalf toetsen stak zo 273 px buiten een staand
     kader. Dus: bij een nieuwe kadermaat het pad opnieuw tekenen en de kaart
     opnieuw vrij zetten. */
  var padAf = null, padWas = null, padHerT = null;
  /* wisselteller per schermmaat: een lus zit altijd op één schermmaat vast */
  var padWissels = 0, padVpWas = '', padStilTot = 0;
  function padUit() {
    clearTimeout(padHerT); padHerT = null;
    if (padAf) { padAf(); padAf = null; }
    strookUit();
  }
  /* hoeveel hoogte neemt ONZE strook nu in? (0 als hij er niet staat) */
  function strookPx() {
    var s = strookVanMij();
    if (!s) return 0;
    var h = s.offsetHeight;
    return h ? h + 4 : 0;               /* + de kier van 4 px uit de opmaak */
  }
  function padVorm() {
    var vp = window.innerWidth + 'x' + window.innerHeight;
    if (vp !== padVpWas) { padVpWas = vp; padWissels = 0; }   /* nieuwe maat: opnieuw mogen kiezen */
    var wil = padBuiten(o.padPlek, padWas, strookPx()) ? 'buiten'
            : (padBreed() ? 'breed' : 'smal');
    if (padWas === null || wil === padWas) return wil;
    var vanBuiten = padWas === 'buiten', naarBuiten = wil === 'buiten';
    /* Een sprong ÍN of ÚIT het kader mag hooguit WISSEL_MAX keer per
       schermmaat. Daarna blijft het pad staan waar het staat; van vorm
       veranderen (zes toetsen of twaalf) mag altijd, dat kost geen hoogte. */
    if (vanBuiten !== naarBuiten) {
      if (padWissels >= WISSEL_MAX)
        return padWas === 'buiten' ? 'buiten' : (padBreed() ? 'breed' : 'smal');
      padWissels++;
    }
    return wil;
  }
  function padOpnieuw() {
    var el = document.querySelector('[data-hot="' + id + '"]');
    /* Is het kaartje opgeruimd (Hits.wisEigenaar na een check-in of een spel
       dat stopt), of heeft een NIEUWE somkaart deze id overgenomen? Dan hoort
       deze luisteraar er niet meer te zijn: anders tekent hij bij het kantelen
       een verdwenen kaartje terug, of vecht hij met de nieuwe kaart. */
    if (!el || el.__somEig !== mij) { padUit(); return; }
    if (!st.open || st.klaar || keuzes || o.pad === false) { padUit(); return; }
    /* Onze eigen wissel verandert het kader, en dat geeft weer een
       kadermelding. Die melding is van onszelf: even niets doen, en daarna één
       keer opnieuw kijken (zodat een echte draai binnen dat venster niet
       verloren gaat). */
    if (nuMs() < padStilTot) {
      if (!padHerT) padHerT = setTimeout(function () { padHerT = null; padOpnieuw(); },
                                         padStilTot - nuMs() + 20);
      return;
    }
    var vorm = padVorm();
    hoog = hoogBasis;           /* de lift hoort bij het oude kader */
    kaart();
    if (vorm !== padWas) padAan();      /* andere vorm: pad opnieuw tekenen */
    else if (vorm === 'buiten') strookAan();
    else kaartVrijStraks();             /* zelfde vorm, ander kader: opnieuw meten */
  }
  function padAan() {
    if (st.klaar || o.pad === false) return;
    st.open = true;
    var vorig = padWas;
    padWas = padVorm();
    if (padWas !== vorig) padStilTot = nuMs() + VERSTIL_MS;   /* eigen wissel: even stil */
    if (!padAf) padAf = opKader(padOpnieuw);
    if (padWas === 'buiten') {
      Hits.weg(id + '_pad');            /* nooit binnen ÉN buiten */
      if (strookAan()) return;
      padWas = padBreed() ? 'breed' : 'smal';   /* geen strook in de opmaak: dan toch binnen */
    }
    strookUit();
    Hits.maak({
      id: id + '_pad', door: o.door || 'som', kamer: p.kamer, x: p.x, z: p.z,
      y: padY(),
      tagnaam: 'div', klas: 'hotpad', vast: true, prio: 20,
      html: padHtml(padWas === 'breed' ? 12 : 6), titel: 'cijfers',
      aan: function (spot, ev) {
        var b = ev.target && ev.target.closest ? ev.target.closest('[data-pk]') : null;
        if (!b) return;
        padTik(b.getAttribute('data-pk'));
      }
    });
    kaartVrijStraks();
  }
  /* ---------- keuzestrook: 2-3 knoppen MÉT woord, aan de onderrand ----------
     Nooit losse pictogrammen door de kamer: alle keuzes staan in één strook
     tegen het kaartje aan. Dezelfde laag als het cijferpad (vast, hoge prio),
     dus hij schuift met de kaart mee en wijkt niet uit voor andere knoppen. */
  function keuzeHtml() {
    var h = '<div class="kzrij">', i, k;
    for (i = 0; i < keuzes.length; i++) {
      k = keuzes[i];
      h += '<button type="button" class="kzk" data-kz="' +
        esc(k.id === undefined || k.id === null ? i : k.id) + '">' +
        (k.icoon ? '<span class="ico">' + k.icoon + '</span>' : '') +
        '<span class="lbl">' + esc(k.tekst || k.id || '') + '</span></button>';
    }
    return h + '</div>';
  }
  function hoogteVan(hid, terug) {
    var el = document.querySelector('[data-hot="' + hid + '"]');
    return (el && el.offsetHeight) ? el.offsetHeight : terug;
  }
  /* Van hart tot hart: een halve kaart plus een halve strook plus een kiertje.
     Eén hoogtestap is 2k schermpixels (World.schaal), dus zo blijft de strook
     tegen de kaart geplakt op elk scherm en bij elke kaarthoogte. */
  function keuzeY() {
    var s = World.schaal ? World.schaal() : null;
    var k = (s && s.k) || 1;
    var px = hoogteVan(id, 52) / 2 + hoogteVan(id + '_keuzes', 62) / 2 + 5;
    return hoog - Math.round(px / (2 * k));
  }
  function keuzeAan() {
    if (!keuzes || st.klaar) return;
    Hits.maak({
      id: id + '_keuzes', door: o.door || 'som', kamer: p.kamer, x: p.x, z: p.z,
      y: keuzeY(),
      tagnaam: 'div', klas: 'hotkeuzes', vast: true, prio: 20,
      html: keuzeHtml(), titel: o.keuzeTitel || 'kies er één',
      aan: function (spot, ev) {
        var b = ev && ev.target && ev.target.closest ? ev.target.closest('[data-kz]') : null;
        if (!b) return;
        var w = b.getAttribute('data-kz'), i, k;
        for (i = 0; i < keuzes.length; i++) {
          k = keuzes[i];
          if (String(k.id === undefined || k.id === null ? i : k.id) !== w) continue;
          if (k.kies) k.kies(k, api);
          return;
        }
      }
    });
    /* nu de strook er staat kennen we haar echte hoogte: één keer bijstellen */
    Hits.maak({ id: id + '_keuzes', y: keuzeY() });
  }

  var api = {
    id: id,
    getal: function () { return st.val === '' ? null : parseInt(st.val, 10); },
    /* de zin boven de som vervangen (string of twee korte zinnen) */
    regel: function (t) { st.zin = zinLijst(t); kaart(); keuzeAan(); return api; },
    /* alleen de somregel vervangen; kaartje, pad en strook blijven staan */
    som: function (t) { som = t === undefined || t === null ? som : String(t); kaart(); keuzeAan(); return api; },
    zet: function (t) { st.val = t === null || t === undefined ? '' : String(t); kaart(); return api; },
    hulp: function (h) { st.extra = h || ''; kaart(); keuzeAan(); return api; },
    /* met een keuzestrook is er geen cijferpad: .open() doet dan niets, anders
       zou een spel per ongeluk pad ÉN strook onder de kaart krijgen */
    open: function () { if (!keuzes) padAan(); return api; },
    klaar: function () {
      st.klaar = true;
      padUit();
      Hits.weg(id + '_pad');
      Hits.weg(id + '_keuzes');
      kaart();
      return api;
    },
    weg: function () {
      padUit();
      Hits.weg(id + '_pad'); Hits.weg(id + '_keuzes'); Hits.weg(id);
    }
  };
  kaart();
  if (keuzes) keuzeAan();
  else if (st.open) padAan();
  return api;
}

/* ---------- sleepbron met teller ----------
   Een zak koekjes, een buidel munten, een kist met bedjes: het ding waar je
   dingen VANDAAN haalt, met het aantal erop. Slepen doet ctx.sleep; geef je
   de sleep-opties mee als `sleep`, dan hangt dit ze zelf aan de knop (en
   opnieuw als de knop tussendoor is herbouwd).
   Ui.bron('zak', { icoon:'🍪', aantal:12, hand:2, sleep:{dropSel:...} })   */
function bron(obj, o) {
  o = o || {};
  var p = World.mik(obj, o.kamer);
  if (!p) return null;
  var id = o.id || ('bron_' + (typeof obj === 'string' ? obj : 'x' + (++wolkNr)));
  var hoog = o.hoog === undefined ? 16 : o.hoog;
  var h = { id: id, el: null };
  /* Eén tik = één keer afleveren. Het sleepmechanisme meldt een tik al via
     onTap; de klik die de browser daarna nog stuurt zetten we stil. Zonder
     dit legt één tik twee munten neer. */
  var sl = null;
  function viaSleep() { if (h.el) h.el.__bronTik = 1; }
  if (o.sleep) {
    sl = {};
    for (var k in o.sleep) sl[k] = o.sleep[k];
    sl.onTap = function () {
      viaSleep();
      if (o.sleep.onTap) o.sleep.onTap.apply(null, arguments);
      else if (o.tik) o.tik(h);
    };
    sl.onDrop = function (t) {
      viaSleep();
      if (o.sleep.onDrop) o.sleep.onDrop.apply(null, arguments);
    };
  }
  function teken() {
    Hits.maak({
      id: id, door: o.door || 'bron', kamer: p.kamer, x: p.x, z: p.z, y: hoog,
      klas: 'hotbron' + (o.klas ? ' ' + o.klas : ''),
      prio: o.prio === undefined ? 10 : o.prio,
      html: '<span class="ico">' + (o.icoon || '') + '</span>' +
            (o.aantal === undefined || o.aantal === null ? ''
              : '<span class="get">' + o.aantal + '</span>') +
            (o.hand ? '<span class="hand">' + o.hand + '</span>' : ''),
      titel: o.titel || 'pak hier',
      volg: p.volg ? function () {
        var q = p.volg();
        return q ? { x: q.x, z: q.z, y: hoog, kamer: q.kamer } : null;
      } : null,
      aan: function () {
        if (h.el && h.el.__bronTik) { h.el.__bronTik = 0; return; }   /* al via slepen */
        if (o.tik) o.tik(h);
      }
    });
    h.el = document.querySelector('[data-hot="' + id + '"]');
    if (h.el && sl && h.el.__bron !== id) {
      h.el.__bron = id;
      makeDraggable(h.el, sl);
    }
  }
  h.zet = function (aantal, hand) {
    if (aantal !== undefined) o.aantal = aantal;
    if (hand !== undefined) o.hand = hand;
    teken();
    return h;
  };
  h.weg = function () { Hits.weg(id); };
  teken();
  return h;
}

/* ---------- voorlezen: alleen als er op getikt wordt ----------
   Werkt met de spraakstem van het apparaat zelf (offline). Kan het niet,
   dan gebeurt er simpelweg niets. Nooit automatisch, nooit herhalend. */
function spreek(tekst) {
  try {
    if (!tekst || !window.speechSynthesis || !window.SpeechSynthesisUtterance) return false;
    var u = new window.SpeechSynthesisUtterance(String(tekst));
    u.lang = 'nl-NL';
    u.rate = 0.95;
    u.pitch = 1.05;
    window.speechSynthesis.cancel();
    window.speechSynthesis.speak(u);
    return true;
  } catch (e) { return false; }
}

/* ---------- kleine dingen ---------- */
function chip(tekst, klas) { return '<div class="chip ' + (klas || '') + '">' + tekst + '</div>'; }
function nuMs() { return (window.performance && performance.now) ? performance.now() : Date.now(); }

return { paneel: paneel, leegPaneel: leegPaneel, inPaneel: inPaneel,
         pad: pad, telMee: telMee, telRij: telRij, getallenlijn: getallenlijn,
         voorbeeld: voorbeeld, hulpNa2s: hulpNa2s, chip: chip,
         woord: woord, hoofd: hoofd, esc: esc, toast: toast,
         sheet: openSheet, sluit: closeSheet, nu: nuMs,
         /* rekenen ín de wereld (HOTEL.md 9) */
         wolk: wolk, wolkWeg: wolkWeg, somkaart: somkaart, spreek: spreek,
         bron: bron,
         /* "het kader is van maat veranderd" - één melding, met opzegger.
            Gebruikt World.onKader als die er is, anders resize/orientationchange. */
         opKader: opKader };
})();
