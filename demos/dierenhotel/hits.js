/* ---------------------------------------------------------------
   hits.js - de HOTSPOT-LAAG boven het canvas.

   De wereld is het rekenblad: alles wat je aanraakt (de bel, een bed,
   een bakje, de voerkar, een sleutel) is een echt voorwerp IN de kamer.
   Daarom ligt er over het canvas een tweede doorzichtige laag
   (#worldHits, naast de naamplaatjes-laag #worldTags) met knoppen en
   sleep-doelen precies op de schermplek van dat voorwerp.

   Twee dingen zijn belangrijk:
     1. z-index volgt EXACT de tekenvolgorde (klein x+z eerst, dus
        achteraan onderop). Ligt een dier vóór een bed, dan pakt
        elementFromPoint het dier - net wat je oog verwacht.
        (HOTEL.md 8.5: dit is de engine-afspraak die alle games delen.)
     2. we verzetten de knoppen alleen als het beeld verandert; blijft
        alles staan, dan raakt de DOM niet aan.

   Publiek:
     Hits.maak(o)          - hotspot erbij of bijwerken
     Hits.weg(id)          - hotspot weg
     Hits.wisEigenaar(nm)  - alle hotspots van één eigenaar weg
     Hits.plaats(kamer,pr) - (door world.js) alles op zijn plek zetten
     Hits.debug()          - wat staat waar, met welke z-index
---------------------------------------------------------------- */
var Hits = (function () {
'use strict';

var MAX_PER_KAMER = 16;
var host = null, reg = Object.create(null), orde = [], laatsteKamer = null, teveel = 0;
/* De maten van het kader en van de knoppen bewaren we. Ze elke beeldflits
   opnieuw opmeten (clientWidth / offsetWidth) dwingt de browser tot een extra
   layout, en dat is precies wat je in een tekenlus niet wil. Opmeten gebeurt
   dus alleen als het kader van maat verandert of als er andere tekst in een
   knop komt te staan. */
var hostW = 0, hostH = 0;
/* Uitwijkplekjes voor knoppen die elkaar afdekken: eerst de echte plek, dan
   omhoog (zoals de naamplaatjes al deden), dan schuin, dan opzij. In stappen
   van een hele knop, en altijd binnen het kader. */
var UITWIJK = (function () {
  var l = [], dx, dy;
  for (dy = 1; dy >= -3; dy--) for (dx = -2; dx <= 2; dx++) l.push([dx, dy]);
  function kost(p) { return Math.abs(p[1]) * 2 + Math.abs(p[0]) * 3 + (p[1] > 0 ? 8 : 0); }
  l.sort(function (a, b) { return kost(a) - kost(b); });
  return l;
})();
/* leengoed: zolang een spel bezig is mag het een bestaande knop overnemen
   (de voerkar leent het bakje van het hotel: tikken levert dan af) */
var leen = Object.create(null);

function zorgHost() {
  if (!host || !host.isConnected) host = document.getElementById('worldHits');
  return host;
}

/* o = { id, kamer, x, z, y, icoon, label, badge, kind:'btn'|'drop',
        drop, data, klas, prio, d, volg(), aan(el) } */
function maak(o) {
  var s = reg[o.id];
  if (!s) { s = reg[o.id] = { id: o.id }; orde.push(o.id); }
  for (var k in o) s[k] = o[k];
  if (s.kind === undefined) s.kind = 'btn';
  if (s.prio === undefined) s.prio = 5;
  s.vuil = true;
  bouwEl(s);
  return s;
}

function weg(id) {
  var s = reg[id];
  if (!s) return;
  if (s.el && s.el.parentNode) s.el.parentNode.removeChild(s.el);
  delete reg[id];
  var i = orde.indexOf(id);
  if (i >= 0) orde.splice(i, 1);
}

function wisEigenaar(naam) {
  orde.slice().forEach(function (id) { if (reg[id] && reg[id].door === naam) weg(id); });
  laat(naam);
}

/* pak(id, wie, fn): deze knop is nu van mij. laat(wie): weer teruggeven.
   Het leengoed staat apart van de knoppen zelf, dus het hotel mag zijn
   knoppen ondertussen gewoon opnieuw opbouwen. */
function pak(id, wie, fn) { leen[id] = { door: wie, fn: fn }; }
function laat(wie) {
  for (var k in leen) if (!wie || leen[k].door === wie) delete leen[k];
}
function geleend(id) { return !!leen[id]; }

function bouwEl(s) {
  var h = zorgHost();
  if (!h) return;
  if (!s.el) {
    /* meestal een knop; het cijferpad is een doosje mét knopjes erin, en een
       knop in een knop mag niet van de browser */
    s.el = document.createElement(s.tagnaam || 'button');
    if (!s.tagnaam) s.el.type = 'button';
    s.el.setAttribute('data-hot', s.id);
    if (s.kind !== 'tag') s.el.addEventListener('click', function (ev) {
      ev.preventDefault();
      var q = reg[s.id];
      if (!q) return;
      var l = leen[s.id];
      if (l && l.fn) { l.fn(q, ev); return; }
      if (q.aan) q.aan(q, ev);
    });
    h.appendChild(s.el);
  }
  var kl = 'hot' + (s.kind === 'drop' ? ' hotdrop' : '') +
    (s.kind === 'tag' ? ' hottag' : '') + (s.klas ? ' ' + s.klas : '');
  if (s.el.className !== kl) s.el.className = kl;
  if (s.drop) s.el.setAttribute('data-drop', s.drop); else s.el.removeAttribute('data-drop');
  /* eigen gegevens krijgen een h- ervoor (data-h-kamer, data-h-slot, ...).
     Zonder dat voorvoegsel botst zo'n naam met de gewone data-attributen
     van het scherm - de kamerbalk gebruikt bijvoorbeeld ook data-kamer. */
  if (s.data) for (var k in s.data) s.el.setAttribute('data-h-' + k, s.data[k]);
  /* html mag alles overrulen: daarmee bouwt ui.js zijn spreekwolkjes,
     sommenkaartjes en het kleine cijferpad aan een voorwerp. */
  var inh = (s.html !== undefined && s.html !== null) ? s.html
    : ('<span class="ico">' + (s.icoon || '') + '</span>' +
       (s.getal !== undefined && s.getal !== null && s.getal !== ''
          ? '<span class="get">' + s.getal + '</span>' : '') +
       (s.label ? '<span class="lbl">' + s.label + '</span>' : '') +
       (s.badge ? '<span class="bdg">' + s.badge + '</span>' : ''));
  if (s.el.__inh !== inh) { s.el.innerHTML = inh; s.el.__inh = inh; }
  var titel = s.titel || s.label || s.id;
  if (s.kind === 'tag') {
    /* niet aan te tikken, niet aan te focussen, geen knoprol */
    if (s.el.getAttribute('aria-hidden') !== 'true') s.el.setAttribute('aria-hidden', 'true');
    if (s.el.hasAttribute('tabindex')) s.el.removeAttribute('tabindex');
  } else if (s.el.getAttribute('aria-label') !== titel) s.el.setAttribute('aria-label', titel);
  if (s._meet !== inh) { s._meet = inh; s._w = 0; s._h = 0; }
}

/* de knopmaat één keer opmeten (na een inhoudswijziging), daarna onthouden */
function maat(s) {
  if (!s._w) {
    s._w = s.el.offsetWidth || 56;
    s._h = s.el.offsetHeight || 48;
  }
  return s;
}
function hermeet() {
  var h = zorgHost();
  hostW = h ? h.clientWidth : 0;
  hostH = h ? h.clientHeight : 0;
  orde.forEach(function (id) { if (reg[id]) { reg[id]._w = 0; reg[id]._h = 0; } });
}

/* ---------- alles op zijn plek: één keer per (vuil) beeld ----------
   pr(x, z, y) geeft de plek in css-pixels binnen het wereldkader. */
function plaats(kamer, pr) {
  var h = zorgHost();
  if (!h) return;
  var i, s, zicht = [];
  /* eerst iedereen laten meebewegen: een wolkje boven een dier dat naar een
     andere kamer loopt, verhuist mee (en is daar dan zichtbaar, hier niet) */
  for (i = 0; i < orde.length; i++) {
    s = reg[orde[i]];
    if (!s || !s.volg) continue;
    var q = s.volg(s);
    if (!q) continue;
    if (q.x !== undefined) s.x = q.x;
    if (q.z !== undefined) s.z = q.z;
    if (q.y !== undefined) s.y = q.y;
    if (q.kamer) s.kamer = q.kamer;
    s.d = q.d;
  }
  for (i = 0; i < orde.length; i++) {
    s = reg[orde[i]];
    if (!s) continue;
    if (s.kamer && s.kamer !== kamer) { if (s.el.style.display !== 'none') s.el.style.display = 'none'; continue; }
    zicht.push(s);
  }
  /* te veel knoppen in één kamer: de minst belangrijke blijven weg
     (HOTEL.md: hooguit een handvol dingen per kamer om aan te raken) */
  teveel = Math.max(0, zicht.length - MAX_PER_KAMER);
  if (teveel > 0) {
    zicht.sort(function (a, b) { return b.prio - a.prio; });
    for (i = MAX_PER_KAMER; i < zicht.length; i++)
      if (zicht[i].el.style.display !== 'none') zicht[i].el.style.display = 'none';
    zicht = zicht.slice(0, MAX_PER_KAMER);
  }
  /* diepte: precies de tekensortering van world.js (klein x+z eerst) */
  for (i = 0; i < zicht.length; i++) {
    s = zicht[i];
    s._d = s.d === undefined || s.d === null ? s.x + s.z : s.d;
  }
  zicht.sort(function (a, b) { return a._d - b._d; });
  /* 1. plek uitrekenen en binnen het kader klemmen: een wens-wolkje boven een
        dier dat achteraan staat zou er anders half buiten vallen en niet meer
        te tikken zijn. */
  if (!hostW || !hostH) hermeet();
  /* Het kader heeft (nog) geen maat: dat gebeurt heel even bij het opstarten
     en bij het wisselen van staand naar liggend. Dan zetten we NIETS neer -
     anders klapt elke knop in de linkerbovenhoek op elkaar. Volgende beeld
     opnieuw. */
  if (!hostW || !hostH) return;
  var rand = 26, plekken = [];
  for (i = 0; i < zicht.length; i++) {
    s = maat(zicht[i]);
    var p = pr(s.x, s.z, s.y || 0);
    var hw = s._w / 2, hh = s._h / 2;
    if (hostW > 3 * rand && hostH > 3 * rand) {
      p.x = Math.max(hw + 2, Math.min(hostW - hw - 2, p.x));
      p.y = Math.max(hh + 2, Math.min(hostH - hh - 2, p.y));
    }
    plekken.push(p);
  }
  /* 2. knoppen die elkaar afdekken uit elkaar schuiven. We lopen van VOOR
        naar achter: het voorste voorwerp houdt zijn eigen plek (dat is ook
        wat je vooraan ziet staan), wat erachter ligt wijkt naar boven uit -
        precies zoals de naamplaatjes dat al deden. Zo is elke knop altijd
        apart aan te tikken, ook als de kamer krap in beeld staat. */
  var gedaan = [], j, g;
  /* Cijfers die ÓP een voorwerp horen (en het cijferpad) blijven staan waar
     ze horen: die plakken we eerst vast, daarna wijkt de rest eromheen. */
  for (i = zicht.length - 1; i >= 0; i--) {
    s = zicht[i];
    if (!s.vast && s.kind !== 'tag') continue;
    gedaan.push({ x: plekken[i].x, y: plekken[i].y, w: s._w, h: s._h });
  }
  for (i = zicht.length - 1; i >= 0; i--) {
    s = zicht[i];
    if (s.vast || s.kind === 'tag') continue;
    var q = plekken[i], w = s._w, hgt = s._h;
    var ox = q.x, oy = q.y, poging, gekozen = null;
    for (poging = 0; poging < UITWIJK.length; poging++) {
      var kx = ox + UITWIJK[poging][0] * (w + 4);
      var ky = oy + UITWIJK[poging][1] * (hgt + 3);
      kx = Math.max(w / 2 + 2, Math.min(Math.max(w / 2 + 2, hostW - w / 2 - 2), kx));
      ky = Math.max(hgt / 2 + 2, Math.min(Math.max(hgt / 2 + 2, hostH - hgt / 2 - 2), ky));
      var botst = false;
      for (j = 0; j < gedaan.length; j++) {
        g = gedaan[j];
        if (Math.abs(g.x - kx) < (g.w + w) / 2 - 1 && Math.abs(g.y - ky) < (g.h + hgt) / 2 - 1) { botst = true; break; }
      }
      if (!botst) { gekozen = [kx, ky]; break; }
      if (!gekozen) gekozen = [kx, ky];               /* laatste redmiddel */
    }
    q.x = gekozen[0]; q.y = gekozen[1];
    gedaan.push({ x: q.x, y: q.y, w: w, h: hgt });
  }
  /* 3. neerzetten; z-index blijft exact de tekenvolgorde */
  for (i = 0; i < zicht.length; i++) {
    s = zicht[i];
    var pp = plekken[i], zi = 20 + i;
    if (s._px !== pp.x || s._py !== pp.y) {
      s._px = pp.x; s._py = pp.y;
      s.el.style.transform = 'translate(-50%,-50%) translate(' + pp.x.toFixed(1) + 'px,' + pp.y.toFixed(1) + 'px)';
    }
    if (s._zi !== zi) { s._zi = zi; s.el.style.zIndex = zi; }
    if (s.el.style.display !== '') s.el.style.display = '';
    s.vuil = false;
  }
  laatsteKamer = kamer;
}

function lijst() { return orde.map(function (id) { return reg[id]; }).filter(Boolean); }

function debug() {
  var uit = { kamer: laatsteKamer, teveel: teveel, kader: [hostW, hostH], spots: [] };
  lijst().forEach(function (s) {
    if (!s.el) return;
    uit.spots.push({ id: s.id, kamer: s.kamer, d: s._d, z: s._zi, kind: s.kind,
                     zichtbaar: s.el.style.display !== 'none', klas: s.klas || null,
                     px: s._px, py: s._py, w: s._w, h: s._h, drop: s.drop || null });
  });
  uit.spots.sort(function (a, b) { return (a.z || 0) - (b.z || 0); });
  return uit;
}

/* voor de tests: wat pakt een tik precies op dit punt? */
function watRaakt(x, y) {
  var e = document.elementFromPoint(x, y);
  if (!e) return null;
  var h = e.closest ? e.closest('[data-hot]') : null;
  return h ? h.getAttribute('data-hot') : null;
}

return { maak: maak, weg: weg, wisEigenaar: wisEigenaar, plaats: plaats, hermeet: hermeet,
         pak: pak, laat: laat, geleend: geleend,
         lijst: lijst, debug: debug, watRaakt: watRaakt, MAX: MAX_PER_KAMER };
})();
