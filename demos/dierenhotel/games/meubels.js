/* ---------------------------------------------------------------
   games/meubels.js - HET MEUBELBOEK: kopen en inrichten (HOTEL.md 9).

   De groeilus van het hotel: rekenen -> inrichten -> meer gasten.
   Prijzen uit HOTEL.md 4, hele euro's: plant EUR1, voerbakje EUR2,
   mandje EUR3, speelmand EUR4, bed EUR5 (+1 gast), badkuip EUR8.

   Alles gebeurt ín de wereld, met één uitzondering die HOTEL.md 9
   toestaat: het OVERZICHT (welke meubels bestaan er, wat kosten ze)
   is een klein ui.paneel met alleen pictogrammen en prijzen - geen
   zinnen. Het rekenen zelf hangt aan de voorwerpen in de receptie:

     * de prijs staat als sommenkaartje op de kassa (met cijferpad als
       er iets uit te rekenen valt: EUR1 + EUR3 = ? of EUR10 - EUR5 = ?);
     * je munten liggen als sleepbronnen op de balie, één per soort,
       met het aantal erop; sleep of tik ze naar de toonbank;
     * op de toonbank staat het bedrag als cijfer;
     * te weinig? wolkje "+EUR3" en samen doortellen op het kaartje;
       na de derde poging liggen de spookmunten erbij;
     * te veel? groep 3 pakt een munt terug (knopje "terug"), groep 4/5
       rekent het wisselgeld uit op het kaartje;
     * te weinig geld in de kassa: wolkje "EUR5 - je hebt EUR3" en het
       meubel blijft gewoon in het boek staan om voor te sparen.

   Neerzetten is ook helemaal ín de wereld: uit de doos (bron 📦) sleep
   je het meubel naar een ✨-vakje op de vloer van welke kamer je maar
   wil; een bezet vakje geeft een wolkje "bezet 🚫". Tikken op je eigen
   bed draait het, tikken op de doos-knop bij een meubel pakt het weer
   op (gratis). Een bed erbij loopt via wereld.voegBed, dus de
   gastenlimiet gaat meteen omhoog - dat is de hele lus.

   Bandregels (ctx.state.band(), nooit een eigen ladder):
     groep 3: één ding per keer, precies betalen, geen wisselgeld;
     groep 4: twee dingen samen (EUR1 + EUR3 = ?), totaal t/m EUR20,
              wisselgeld uitrekenen;
     groep 5: idem, met een buidel t/m EUR20.

   Sterren (voor meedoen, nooit voor goed rekenen) kopen versiering op
   de tweede bladzijde: geen rekenwerk, altijd iets leuks te halen.
---------------------------------------------------------------- */
(function () {
'use strict';

var C = null;            /* de ctx die we bij start() krijgen */
var V = null;            /* wat er nu speelt (niet bewaard) */

/* ---------- de prijslijst uit HOTEL.md 4 (hele euro's) ---------- */
var WINKEL = [
  { type: 'plant',     icoon: '🪴', naam: 'plant',     prijs: 1 },
  { type: 'bakje',     icoon: '🍽', naam: 'voerbakje', prijs: 2 },
  { type: 'mandje',    icoon: '🧺', naam: 'mandje',    prijs: 3 },
  { type: 'speelmand', icoon: '🧶', naam: 'speelmand', prijs: 4 },
  { type: 'bed',       icoon: '🛏', naam: 'bed',       prijs: 5, plus: '+1 🐾' },
  { type: 'badkuip',   icoon: '🛁', naam: 'badkuip',   prijs: 8 }
];

/* ---------- de sterrenpagina: versiering, nooit rekenen ---------- */
var VERSIERING = [
  { sleutel: 'vlag',    icoon: '🎉', naam: 'vlaggetjes',     ster: 1 },
  { sleutel: 'bloem',   icoon: '🌸', naam: 'bloemetje',      ster: 1 },
  { sleutel: 'kussen',  icoon: '🩷', naam: 'kleurkussen',    ster: 2 },
  { sleutel: 'slinger', icoon: '🎈', naam: 'ballonslinger',  ster: 3 },
  { sleutel: 'ster',    icoon: '⭐', naam: 'sterrensticker', ster: 1 }
];

/* ---------- waar in de receptie hangt het rekenwerk? ----------
   De balie is een L, dus deze plekken liggen op het scherm ver uit
   elkaar (GAMES-API.md 4: horizontaal ~ (x-z)*2 px). */
var KASSA = 'kassa';                     /* het sommenkaartje op de kassa */
var BANK = { x: 44, z: 60 };             /* de toonbank, voor de balie */
var BUIDELPLEK = { x: 6, z: 70 };        /* je geldbuidel op de zijvleugel */
var OKPLEK = { x: 76, z: 20 };           /* klaar-met-tellen */
var TERUGPLEK = { x: 30, z: 78 };        /* een munt terugpakken / het boek */
var SPOOKPLEK = { x: 60, z: 50 };        /* de spookmunten */
var MUNTSOORT = [1, 2, 5, 10];

/* =====================================================================
   KLEINE HULPJES
===================================================================== */
/* mijn laatje in de opslag (gaat automatisch mee in kws-hotel-v6) */
function D() {
  var q = C.data();
  if (!q.mijn) q.mijn = [];                  /* [{id,type}] van wat ik neerzette */
  if (!q.versiering) q.versiering = {};      /* {sleutel: aantal} */
  if (q.wacht === undefined) q.wacht = null; /* betaald, nog niet neergezet */
  if (!q.gekocht) q.gekocht = 0;
  q.mijn = q.mijn.map(function (m) {
    return typeof m === 'string' ? { id: m, type: 'plant' } : m;
  });
  return q;
}
function item(type) {
  for (var i = 0; i < WINKEL.length; i++) if (WINKEL[i].type === type) return WINKEL[i];
  return null;
}
function versier(sleutel) {
  for (var i = 0; i < VERSIERING.length; i++) if (VERSIERING[i].sleutel === sleutel) return VERSIERING[i];
  return null;
}
function munten() { return C.state.munten(); }
function band() { return C.state.band(); }
function maxLijst() { return band() >= 4 ? 2 : 1; }    /* twee dingen samen = de som */
function buidelMax() { return band() >= 4 ? 20 : 10; } /* geld t/m 20 (groep 3 t/m 10) */
function eur(n) { return '€' + n; }
function totaalVan(types) {
  var t = 0;
  types.forEach(function (q) { var w = item(q); if (w) t += w.prijs; });
  return t;
}
function iconen(types) {
  return types.map(function (t) { var w = item(t); return w ? w.icoon : '?'; }).join('');
}
/* de zin boven de som (HOTEL.md 9, VERPLICHT): één gewone regel met een
   werkwoord of een vraagwoord, hooguit 8 woorden, pictogram vooraan */
function kap(t) { return String(t).charAt(0).toUpperCase() + String(t).slice(1); }
function naamVan(type) { var w = item(type); return w ? w.naam : 'meubel'; }
/* "Mandje kost €3" of "Plant en mandje kosten €4" */
function prijsZin(types, totaal) {
  if (types.length === 1)
    return kap(naamVan(types[0])) + ' kost ' + eur(totaalVan(types));
  return kap(types.map(naamVan).join(' en ')) + ' kosten ' + eur(totaal);
}
/* "Plant €1 en mandje €3" */
function somZin(types) {
  return kap(types.map(function (t) {
    return naamVan(t) + ' ' + eur(item(t).prijs);
  }).join(' en '));
}
/* samen doortellen: "6 … 7 … 8" (nooit een lap tekst, nooit een kruis) */
function doorTellen(van, stappen) {
  var l = [], i;
  for (i = 1; i <= stappen && i <= 12; i++) l.push(van + i);
  return l.join(' … ');
}
/* een plek in de ruimte waar je NU staat: een wolkje in een andere kamer
   zou je nooit zien */
function hier() {
  var k = C.wereld.actief() || 'receptie', r = C.wereld.kamer(k);
  if (k === 'receptie') return 'boek';
  return { x: Math.round(r.w * 0.5), z: Math.round(r.d * 0.22), kamer: k };
}
function bewaar() { C.state.bewaar(); }
function hud() { if (window.Hotel) Hotel.render(); }
function wolk(obj, o) { o.door = 'meubels'; return C.ui.wolk(obj, o); }
function wolkWeg(id) { C.ui.wolkWeg(id); }

/* =====================================================================
   START / STOP
===================================================================== */
function start(ctx) {
  C = ctx;
  var q = D();
  V = { view: 'boek', tab: 'meubels', lijst: [], bet: null, spaar: null,
        kamerNu: C.wereld.actief(), vakOffset: 0, hertekenT: null,
        thuis: C.wereld.actief() || 'receptie' };
  if (V.thuis === 'receptie') V.thuis = 'kamer1';   /* inrichten doe je in een kamer */
  /* Al betaald maar nog niet neergezet (ook na "Verder spelen")? Dan mag dat
     eerst een plekje krijgen: daar is immers al voor gerekend. */
  if (q.wacht && q.wacht.nog && q.wacht.nog.length) plaats();
  else { q.wacht = null; boek(); }
}

function stop() {
  if (!C) return;
  if (V && V.hertekenT) { clearTimeout(V.hertekenT); V.hertekenT = null; }
  if (V && V.bet && V.bet.kaart) V.bet.kaart.weg();
  spookWeg();
  C.hotspots.wisAlles();
  C.hotspots.laat();
  V = null;
  C = null;
}

/* alles van mij uit de wereld halen (wolkjes, kaartjes, bronnen, cijfers) */
function leegWereld() {
  if (V && V.bet && V.bet.kaart) { V.bet.kaart.weg(); V.bet.kaart = null; }
  spookWeg();
  C.hotspots.wisAlles();
}

/* =====================================================================
   BLADZIJDE 1: HET OVERZICHT (pictogram + prijs, geen zinnen)
   Het enige rekenblad dat HOTEL.md 9 nog toestaat: een overzicht.
===================================================================== */
function boek() {
  var q = D(), h = '';
  V.view = 'boek';
  leegWereld();
  h += '<h1>📖 Meubelboek</h1>';
  h += '<div class="row center">' +
    C.ui.chip('💰 <b>' + munten() + '</b>') +
    C.ui.chip('⭐ <b>' + C.state.sterren() + '</b>', 'b') +
    C.ui.chip('🛏 <b>' + C.state.maxGasten() + '</b>', 'c') + '</div>';
  h += '<div class="row center" style="margin:8px 0">' +
    '<button class="btn' + (V.tab === 'meubels' ? ' go' : ' soft') + '" type="button" ' +
    'data-tab="meubels" aria-label="Meubels">🪑</button>' +
    '<button class="btn' + (V.tab === 'versiering' ? ' go' : ' soft') + '" type="button" ' +
    'data-tab="versiering" aria-label="Versiering met sterren">⭐</button></div>';
  h += (V.tab === 'versiering') ? bladVersiering(q) : bladMeubels(q);
  h += '<div class="row center" style="margin-top:12px">' +
    '<button class="btn soft" type="button" id="mbDicht" aria-label="Boek dicht">✖</button></div>';
  C.ui.paneel(h, 'meubelboek');
  wireBoek();
  mijnMeubelKnoppen();
  C.wereld.vuil();
}

function kaartje(inh) {
  return '<div class="pet" style="width:104px;padding:8px 6px">' + inh + '</div>';
}
function spaarChip() {
  if (!V.spaar) return '';
  return '<div class="row center" style="margin:4px 0">' +
    C.ui.chip(V.spaar.icoon + ' <b>' + V.spaar.nodig + '</b>') +
    C.ui.chip('💰 <b>' + V.spaar.heb + '</b>', 'b') + '</div>';
}
function bladMeubels(q) {
  var h = spaarChip() + '<div class="bowls">', m = munten(), max = maxLijst();
  WINKEL.forEach(function (w) {
    var kan = w.prijs <= m;
    var aantal = V.lijst.filter(function (t) { return t === w.type; }).length;
    var inh = '<div style="font-size:2.1rem;line-height:1.1">' + w.icoon + '</div>' +
      '<div class="chip" style="background:#FFE7C9;font-size:1.2rem;padding:4px 12px">' + eur(w.prijs) + '</div>' +
      (w.plus ? '<div class="need" style="font-size:.8rem;padding:1px 8px">' + w.plus + '</div>' : '');
    if (max > 1) {
      inh += '<button class="btn' + (aantal ? ' go' : '') + '" type="button" data-erbij="' + w.type +
        '" aria-label="' + w.naam + ' ' + w.prijs + ' euro erbij" style="margin-top:6px;padding:10px 16px">' +
        (aantal ? aantal + '×' : '＋') + '</button>';
    } else {
      inh += '<button class="btn' + (kan ? ' go' : ' soft') + '" type="button" data-koop="' + w.type +
        '" aria-label="' + w.naam + ' kopen, ' + w.prijs + ' euro" style="margin-top:6px;padding:10px 16px">' +
        (kan ? '🛒' : '💛') + '</button>';
    }
    h += kaartje(inh);
  });
  h += '</div>';
  if (max > 1 && V.lijst.length) {
    h += '<div class="row center" style="margin-top:10px">' +
      '<div class="chip" style="font-size:1.15rem">' + iconen(V.lijst) + ' ' +
      V.lijst.map(function (t) { return eur(item(t).prijs); }).join(' + ') + '</div>' +
      '<button class="btn go" type="button" id="mbAfrekenen" aria-label="Afrekenen">🛒</button>' +
      '<button class="btn soft" type="button" id="mbLeeg" aria-label="Lijstje leeg">↩</button></div>';
  }
  return h;
}

function bladVersiering(q) {
  var h = spaarChip() + '<div class="bowls">', s = C.state.sterren();
  VERSIERING.forEach(function (v) {
    var heb = q.versiering[v.sleutel] || 0, kan = v.ster <= s;
    h += kaartje('<div style="font-size:2.1rem;line-height:1.1">' + v.icoon + '</div>' +
      '<div class="chip b" style="font-size:1.1rem;padding:4px 12px">⭐ ' + v.ster + '</div>' +
      (heb ? '<div class="need" style="font-size:.8rem;padding:1px 8px">' + heb + '×</div>' : '') +
      '<button class="btn' + (kan ? ' go' : ' soft') + '" type="button" data-ster="' + v.sleutel +
      '" aria-label="' + v.naam + ' kopen voor ' + v.ster + ' sterren" style="margin-top:6px;padding:10px 16px">' +
      (kan ? '🛒' : '💛') + '</button>');
  });
  h += '</div>';
  var heeft = VERSIERING.filter(function (v) { return q.versiering[v.sleutel]; });
  if (heeft.length) {
    h += '<div class="tray"><div class="trayrow">' +
      heeft.map(function (v) {
        var n = q.versiering[v.sleutel], s2 = '', i;
        for (i = 0; i < Math.min(n, 8); i++) s2 += '<span class="scoop">' + v.icoon + '</span>';
        return s2 + (n > 8 ? '<b>+' + (n - 8) + '</b>' : '');
      }).join('') + '</div></div>';
  }
  return h;
}

function wireBoek() {
  if (!$('#paneel')) return;
  $$('#paneel [data-tab]').forEach(function (b) {
    b.onclick = function () { V.tab = b.getAttribute('data-tab'); boek(); };
  });
  $$('#paneel [data-koop]').forEach(function (b) {
    b.onclick = function () { koop([b.getAttribute('data-koop')]); };
  });
  $$('#paneel [data-erbij]').forEach(function (b) {
    b.onclick = function () { opLijstje(b.getAttribute('data-erbij')); };
  });
  $$('#paneel [data-ster]').forEach(function (b) {
    b.onclick = function () { koopVersiering(b.getAttribute('data-ster')); };
  });
  var a = $('#mbAfrekenen'); if (a) a.onclick = function () { koop(V.lijst.slice()); };
  var l = $('#mbLeeg'); if (l) l.onclick = function () { V.lijst = []; boek(); };
  var w = $('#mbDicht'); if (w) w.onclick = function () { C.sluit(); };
}

function opLijstje(type) {
  if (V.lijst.length >= maxLijst()) {
    C.snd.zacht();
    wolk(hier(), { id: 'mb_vol', icoon: '🧺', getal: 2, tekst: 'is genoeg', klas: 'hulp' });
    C.wereld.vuil();
    return;
  }
  V.lijst.push(type);
  V.spaar = null;
  C.snd.tik();
  boek();
}

/* Te weinig geld: één wolkje met de prijs en wat je hebt. Het meubel blijft
   in het boek staan om voor te sparen; er gaat niets op slot. */
function tekort(totaal) {
  V.spaar = { icoon: '💛', nodig: eur(totaal), heb: eur(munten()) };
  boek();
  C.snd.zacht();
  wolk(hier(), { id: 'mb_spaar', icoon: '💛', getal: eur(totaal),
                 tekst: 'je hebt ' + eur(munten()), klas: 'hulp', hoog: 26, prio: 11,
                 tik: function () { wolkWeg('mb_spaar'); C.wereld.vuil(); } });
  C.wereld.vuil();
}

function koopVersiering(sleutel) {
  var q = D(), v = versier(sleutel), s = C.state.sterren();
  if (!v) return;
  if (v.ster > s) {
    V.spaar = { icoon: '⭐', nodig: v.ster, heb: s };
    boek();
    C.snd.zacht();
    wolk(hier(), { id: 'mb_spaar', icoon: '⭐', getal: v.ster, tekst: 'je hebt ' + s,
                   klas: 'hulp', hoog: 26, prio: 11 });
    C.wereld.vuil();
    return;
  }
  C.state.ster(-v.ster, 'versiering');
  q.versiering[sleutel] = (q.versiering[sleutel] || 0) + 1;
  V.spaar = null;
  C.snd.ster();
  bewaar(); hud();
  boek();
  wolk(hier(), { id: 'mb_af', icoon: v.icoon, getal: '+1', klas: 'goed', hoog: 26, prio: 11 });
  C.wereld.vuil();
}

/* =====================================================================
   BLADZIJDE 2: AFREKENEN, HELEMAAL ÍN DE WERELD
   Zelfde muntenlade als de rekening bij het uitchecken: de munten en
   het samen-tellen komen uit econ.js (buidel / splits / munt / som),
   het beeld uit de wereldprimitieven (bron, somkaart, getalTag, wolk).
===================================================================== */
function koop(types) {
  if (!types || !types.length) return;
  var tot = totaalVan(types);
  if (tot > munten()) { tekort(tot); return; }
  var cap = Math.max(tot, Math.min(munten(), buidelMax()));
  V.spaar = null;
  V.view = 'betaal';
  V.bet = {
    types: types.slice(), totaal: tot,
    stap: types.length > 1 ? 'som' : 'munten',   /* twee dingen = eerst de som */
    hand: C.econ.buidel(cap), bank: [],
    somPog: 0, telPog: 0, wisPog: 0, spook: null, hulp: null,
    rest: munten() - cap, kaart: null, soort: 1, t0: C.ui.nu()
  };
  kiesSoort(V.bet, 1);
  C.ui.leegPaneel();                              /* de wereld is nu het speelvlak */
  if (window.Hotel && Hotel.naarKamer) Hotel.naarKamer('receptie');
  else C.wereld.naar('receptie');
  C.snd.tik();
  betaalTeken();
}

/* welke muntsoort heb je in je hand? (zoals de handgreep van de voerkar:
   tikken op de buidel gaat naar de volgende soort die je nog hebt) */
function heeft(b, v) { return b.hand.filter(function (c) { return c.v === v; }).length; }
function kiesSoort(b, vanaf) {
  var i, v;
  for (i = 0; i < MUNTSOORT.length; i++) {
    v = MUNTSOORT[(MUNTSOORT.indexOf(vanaf) + i) % MUNTSOORT.length];
    if (heeft(b, v)) { b.soort = v; return v; }
  }
  b.soort = null;
  return null;
}
function volgendeSoort() {
  var b = V.bet, i = MUNTSOORT.indexOf(b.soort);
  kiesSoort(b, MUNTSOORT[(i + 1) % MUNTSOORT.length]);
  C.snd.tik();
  betaalTeken();
}

function betaalTeken() {
  if (!C || !V || !V.bet) return;
  var b = V.bet, i;
  C.hotspots.wisAlles();
  b.kaart = null;

  /* het kaartje op de kassa: de som of de prijs, met het cijferpad eronder */
  if (b.stap === 'som') {
    b.kaart = C.ui.somkaart(KASSA, b.types.map(function (t) { return eur(item(t).prijs); }).join(' + ') + ' =',
      { id: 'mb_som', door: 'meubels', open: true, max: 2, icoon: '🛒',
        regel: [somZin(b.types), 'Hoeveel euro is dat samen?'],
        onOk: function (n) { somOk(n); } });
    if (b.somPog >= 1) b.kaart.hulp(doorTellen(item(b.types[0]).prijs, item(b.types[1]).prijs));
    if (b.somPog >= 3) spookZet(b.totaal, 'zoveel is het samen');
  } else if (b.stap === 'wissel') {
    var betaald = C.econ.som(b.bank);
    b.kaart = C.ui.somkaart(KASSA, eur(betaald) + ' − ' + eur(b.totaal) + ' =',
      { id: 'mb_wissel', door: 'meubels', open: true, max: 2, hoog: 26,
        icoon: '👛',
        regel: ['Je gaf ' + eur(betaald) + ', het kost ' + eur(b.totaal),
                'Hoeveel krijg je terug?'],
        onOk: function (n) { wisselOk(n); } });
    if (b.wisPog >= 1) b.kaart.hulp(doorTellen(b.totaal, betaald - b.totaal));
    if (b.wisPog >= 3) spookZet(betaald - b.totaal, 'zoveel krijg je terug');
  } else {
    /* de prijs als afgevinkt sommenkaartje: dat is de regel waar je naar kijkt.
       De pictogram-som ("🪑 =") staat er nooit zonder zin erboven. */
    b.kaart = C.ui.somkaart(KASSA, iconen(b.types) + ' =',
      { id: 'mb_bon', door: 'meubels', pad: false, hoog: 24,
        icoon: b.types.length > 1 ? '🛒' : item(b.types[0]).icoon,
        /* het pictogram hoort bij het WOORD munten, niet vooraan de regel */
        regel: [prijsZin(b.types, b.totaal), 'Leg de 🪙 munten op de toonbank'] });
    b.kaart.zet(eur(b.totaal));
    if (b.hulp) b.kaart.hulp(b.hulp);
    if (b.spook) spookZet(b.spook.bedrag, b.spook.lbl);
  }

  /* de toonbank: sleep de munten hierheen, het bedrag staat erop.
     Tikken legt de munt die je in je hand hebt neer - zo kun je ook
     spelen zonder te slepen. */
  C.hotspots.maak({
    id: 'mb_bank', kamer: 'receptie', x: BANK.x, z: BANK.z, y: 10,
    icoon: '🧾', getal: eur(C.econ.som(b.bank)),
    kind: 'drop', drop: 'mbbank', klas: 'hotbron', prio: 11,
    titel: 'de toonbank: ' + eur(C.econ.som(b.bank)),
    aan: function () { legNeer(V.bet ? V.bet.soort : null); }
  });

  /* je geldbuidel: de munt die je in je hand hebt staat erop, met hoeveel
     je er nog van hebt. Tikken pakt de volgende muntsoort. */
  if (b.soort) {
    C.hotspots.bron({ x: BUIDELPLEK.x, z: BUIDELPLEK.z, kamer: 'receptie' }, {
      id: 'mb_buidel', icoon: b.soort >= 10 ? '💶' : '🪙', aantal: eur(b.soort),
      hand: heeft(b, b.soort), hoog: 10, prio: 10,
      titel: 'munt van ' + b.soort + ' euro (' + heeft(b, b.soort) + ' in je buidel)',
      tik: function () { volgendeSoort(); },
      sleep: {
        dropSel: '[data-drop="mbbank"]',
        ghostHTML: function () { return C.econ.munt((V.bet && V.bet.soort) || 1); },
        canDrag: function () { return !!(V && V.bet && V.bet.stap !== 'som' && V.bet.soort); },
        onDrop: function () { legNeer(V.bet ? V.bet.soort : null); },
        onTap: function () { volgendeSoort(); }
      }
    });
  }

  /* klaar met tellen, en een munt terugpakken */
  if (b.stap !== 'som') {
    C.hotspots.maak({
      id: 'mb_ok', kamer: 'receptie', x: OKPLEK.x, z: OKPLEK.z, y: 8,
      icoon: '✔', klas: 'hotwolk goed', prio: 10, titel: 'klaar met tellen',
      aan: function () { klaarMetTellen(); }
    });
  }
  if (b.bank.length) {
    C.hotspots.maak({
      id: 'mb_terug', kamer: 'receptie', x: TERUGPLEK.x, z: TERUGPLEK.z, y: 6,
      icoon: '↩', klas: 'hotwolk', prio: 9, titel: 'een munt terugpakken',
      aan: function () { muntTerug(); }
    });
  } else {
    /* niets neergelegd? dan is dit de weg terug naar het boek (nog niet betaald) */
    C.hotspots.maak({
      id: 'mb_boek', kamer: 'receptie', x: TERUGPLEK.x, z: TERUGPLEK.z, y: 6,
      icoon: '📖', klas: 'hotgame', prio: 9, titel: 'terug naar het meubelboek',
      aan: function () { V.bet = null; boek(); }
    });
  }
  C.wereld.vuil();
}

/* ---------- spookmunten: zo ziet het bedrag eruit ----------
   Precies de spookmunten van de rekening: econ.splits() knipt het bedrag
   in munten en econ.munt(v, 'ghost') tekent ze. Ze hangen in één kaartje
   bij de toonbank, en dat kaartje schuift met de knoppenlaag mee - zo dekt
   het nooit een andere knop af, ook niet in de drukke receptie. */
function spookWeg() {
  if (C) C.hotspots.weg('mb_spook');
}
function spookZet(bedrag, lbl) {
  var m = C.econ.splits(bedrag).slice(0, 4), i, h = '<span class="ico">🪙</span>';
  for (i = 0; i < m.length; i++) h += '<span class="get">' + eur(m[i]) + '</span>';
  C.hotspots.maak({
    id: 'mb_spook', kamer: 'receptie', x: SPOOKPLEK.x, z: SPOOKPLEK.z, y: 6,
    klas: 'hotwolk hotspook', prio: 12, html: h, titel: lbl || 'zo ziet het uit',
    aan: function () { C.ui.spreek(lbl || 'zoveel is het'); }
  });
}

function legNeer(v) {
  var b = V.bet, i;
  if (!b || b.stap === 'som' || !v) return;
  for (i = 0; i < b.hand.length; i++) {
    if (b.hand[i].v === v) {
      b.bank.push(b.hand.splice(i, 1)[0]);
      b.hulp = null;
      if (b.stap === 'wissel') { b.stap = 'munten'; b.wisPog = 0; b.spook = null; }
      if (!heeft(b, v)) kiesSoort(b, v);      /* die soort is op: pak de volgende */
      C.snd.munt();
      betaalTeken();
      return;
    }
  }
  /* geen munt van deze soort meer: pak de volgende, zonder gemopper */
  kiesSoort(b, v);
  betaalTeken();
}
function muntTerug() {
  var b = V.bet;
  if (!b || !b.bank.length) return;
  b.hand.push(b.bank.pop());
  b.hand.sort(function (a, c) { return c.v - a.v; });
  b.hulp = null; b.spook = null;
  if (b.stap === 'wissel') { b.stap = 'munten'; b.wisPog = 0; }
  C.snd.terug();
  betaalTeken();
}

function somOk(n) {
  var b = V.bet;
  if (n === null) {
    wolk(KASSA, { id: 'mb_tip', icoon: '☝', tekst: 'tik een getal', klas: 'hulp', hoog: 34 });
    C.wereld.vuil();
    return;
  }
  if (n === b.totaal) {
    b.kaart.zet(eur(n)).klaar();
    b.stap = 'munten';
    C.snd.ja();
    setTimeout(function () { if (C && V && V.bet && V.bet.stap === 'munten') betaalTeken(); }, 450);
    return;
  }
  b.somPog++;
  C.snd.zacht();
  betaalTeken();
}

function klaarMetTellen() {
  var b = V.bet;
  if (!b) return;
  if (b.stap === 'wissel') { wisselOk(b.kaart ? b.kaart.getal() : null); return; }
  var t = C.econ.som(b.bank), p = b.totaal;
  if (t === p) { betaald(0); return; }

  if (t < p) {                                    /* nog niet genoeg: samen doortellen */
    b.telPog++;
    var mist = p - t;
    /* pictogram + getal, en samen doortellen: "+€2  6 … 7 … 8" */
    b.hulp = '🪙 +' + eur(mist) + '<br>' + doorTellen(t, mist);
    b.spook = b.telPog >= 3 ? { bedrag: mist, lbl: 'dit moet er nog bij' } : null;
    C.snd.zacht();
    betaalTeken();
    return;
  }
  /* er ligt meer dan het kost */
  if (band() >= 4) {                              /* groep 4/5: wisselgeld uitrekenen */
    b.stap = 'wissel'; b.wisPog = 0; b.hulp = null; b.spook = null;
    betaalTeken();
    return;
  }
  /* groep 3 rekent nog geen wisselgeld: precies leggen, munt terugpakken mag */
  b.telPog++;
  b.hulp = '↩ ' + eur(t - p) + ' te veel';
  b.spook = b.telPog >= 3 ? { bedrag: p, lbl: 'zoveel moet het zijn' } : null;
  C.snd.zacht();
  betaalTeken();
}

function wisselOk(n) {
  var b = V.bet, goed = C.econ.som(b.bank) - b.totaal;
  if (n === null) {
    wolk(KASSA, { id: 'mb_tip', icoon: '☝', tekst: 'tik een getal', klas: 'hulp', hoog: 34 });
    C.wereld.vuil();
    return;
  }
  if (n === goed) { betaald(goed); return; }
  b.wisPog++;
  C.snd.zacht();
  betaalTeken();
}

/* betaald! De munten gaan uit de kassa, het meubel gaat in de doos en er
   is een ster voor het meedoen (nooit voor goed rekenen). */
function betaald(wissel) {
  var b = V.bet, q = D();
  C.state.munt(-b.totaal);
  C.state.tel(b.somPog + b.telPog + b.wisPog === 0, C.ui.nu() - b.t0);
  q.wacht = { nog: b.types.slice() };
  q.gekocht = (q.gekocht || 0) + b.types.length;
  V.lijst = [];
  V.bet = null;
  C.snd.tover();
  C.taakKlaar('meubel', { sterren: 1 });
  bewaar(); hud();
  leegWereld();
  wolk(KASSA, { id: 'mb_af', icoon: wissel > 0 ? '💰' : '✅',
                getal: wissel > 0 ? eur(wissel) : eur(b.totaal),
                tekst: wissel > 0 ? 'terug' : 'betaald', klas: 'goed', hoog: 30, prio: 12 });
  setTimeout(function () {
    if (!C || !V) return;
    wolkWeg('mb_af');
    plaats();
  }, 1200);
}

/* =====================================================================
   BLADZIJDE 3: NEERZETTEN OP HET VOXELRASTER (in de wereld)
   Uit de doos (📦) sleep je het meubel naar een ✨-vakje op de vloer.
   Elke ruimte heeft zijn eigen doos en zijn eigen vakjes, dus je kunt
   inrichten waar je wil; een bezet plekje geeft een wolkje "bezet 🚫".
===================================================================== */
function plaats() {
  var q = D();
  V.view = 'plaats';
  V.bet = null;
  C.ui.leegPaneel();                      /* geen blad: de kamer is het speelvlak */
  if (!q.wacht || !q.wacht.nog || !q.wacht.nog.length) { boek(); return; }
  var nu = C.wereld.actief();
  if (nu === 'receptie') {
    if (window.Hotel && Hotel.naarKamer) Hotel.naarKamer(V.thuis);
    else C.wereld.naar(V.thuis);
  }
  plaatsTeken();
}

/* Hooguit vier vakjes tegelijk: een kamer mag maar een handvol knoppen
   hebben (hits.js laat er 16 toe en die zijn ook van het hotel zelf).
   Zijn er meer vrije plekjes, dan wandelt "meer ▸" er doorheen. */
var VAK_MAX = 4;

function plaatsTeken() {
  if (!C || !V || V.view !== 'plaats') return;
  var q = D(), nog = (q.wacht && q.wacht.nog) || [];
  if (!nog.length) { boek(); return; }
  var w = item(nog[0]) || WINKEL[0];
  var nu = C.wereld.actief();
  V.kamerNu = nu;
  C.hotspots.wisAlles();

  /* DE DOOS reist met je mee: hij hoort bij geen enkele kamer, en zijn
     volg() zet hem in de ruimte waar je nu staat. Datzelfde volg() merkt
     ook dat je door een deur bent gelopen en tekent de vakjes opnieuw. */
  C.hotspots.maak({
    id: 'mb_doos', x: doosPlek(C.wereld.kamer(nu)).x, z: doosPlek(C.wereld.kamer(nu)).z, y: 16,
    klas: 'hotbron', prio: 11, titel: w.naam + ' neerzetten',
    html: '<span class="ico">📦</span><span class="get">' + w.icoon + '</span>' +
          (nog.length > 1 ? '<span class="hand">' + nog.length + '</span>' : ''),
    volg: function () {
      var k = C.wereld.actief(), dp = doosPlek(C.wereld.kamer(k));
      if (k !== V.kamerNu) hertekenStraks(k);
      return { x: dp.x, z: dp.z, y: 16 };
    },
    aan: function () {
      var dp = doosPlek(C.wereld.kamer(C.wereld.actief()));
      wolk({ x: dp.x, z: dp.z, kamer: C.wereld.actief() },
           { id: 'mb_tip', icoon: '✨', tekst: 'sleep naar een plekje', klas: 'hulp', hoog: 30 });
      C.wereld.vuil();
    }
  });
  var el = document.querySelector('[data-hot="mb_doos"]');
  if (el && !el.__mbsleep) {
    el.__mbsleep = 1;
    C.sleep(el, {
      dropSel: '[data-drop="mbvak"],[data-drop="deur"],[data-drop="bed"],[data-drop="bak"],[data-drop="toonbank"]',
      ghostHTML: function () {
        var qq = D(), t0 = qq.wacht && qq.wacht.nog[0], it = item(t0) || w;
        return '<div class="karghost">' + it.icoon + '</div>';
      },
      onDrop: function (t) {
        var soort = t.getAttribute('data-drop');
        if (soort === 'mbvak') {
          zetNeer(t.getAttribute('data-h-kamer'), +t.getAttribute('data-h-x'), +t.getAttribute('data-h-z'));
        } else if (soort === 'deur') {
          naarKamer(t.getAttribute('data-h-naar'));
        } else {
          bezet(t.getAttribute('data-h-kamer') || C.wereld.actief(),
                +t.getAttribute('data-h-x') || null, +t.getAttribute('data-h-z') || null, t);
        }
      }
    });
  }

  /* de vrije vakjes van DEZE ruimte, hooguit vier tegelijk */
  var alle = vakjes(nu), i, v;
  if (V.vakOffset >= alle.length) V.vakOffset = 0;
  for (i = 0; i < Math.min(VAK_MAX, alle.length); i++) {
    v = alle[(V.vakOffset + i) % alle.length];
    (function (vv) {
      C.hotspots.maak({
        id: 'mbvak_' + nu + '_' + vv.id, kamer: nu, x: vv.x, z: vv.z, y: 0,
        icoon: '✨', kind: 'drop', drop: 'mbvak',
        data: { kamer: nu, x: vv.x, z: vv.z }, klas: 'hotgame', prio: 9,
        titel: 'hier neerzetten',
        aan: function () { zetNeer(nu, vv.x, vv.z); }
      });
    })(v);
  }
  if (alle.length > VAK_MAX) {
    v = alle[(V.vakOffset + VAK_MAX) % alle.length];
    C.hotspots.maak({
      id: 'mb_meer', kamer: nu, x: v.x, z: v.z, y: 0,
      icoon: '▸', klas: 'hotwolk', prio: 8, titel: 'meer plekjes',
      aan: function () { V.vakOffset = (V.vakOffset + VAK_MAX) % alle.length; plaatsTeken(); C.snd.tik(); }
    });
  }
  C.wereld.vuil();
}

/* door een deur gelopen? dan de vakjes van de nieuwe kamer neerleggen.
   Even uitstellen: volg() draait midden in het tekenen van de knoppenlaag. */
function hertekenStraks(k) {
  V.kamerNu = k;
  V.vakOffset = 0;
  if (V.hertekenT) return;
  V.hertekenT = setTimeout(function () {
    V.hertekenT = null;
    if (C && V && V.view === 'plaats') plaatsTeken();
  }, 0);
}

/* de doos staat vooraan in de ruimte, uit de weg van de deur */
function doosPlek(r) {
  if (!r) return { x: 30, z: 60 };
  return { x: Math.round(r.w * 0.26), z: Math.round(r.d * 0.88) };
}

/* de vrije vakjes, netjes uit elkaar en op volgorde van de deur af: wat
   het dichtst bij binnenkomen ligt zie je het eerst (GAMES-API.md 4) */
function vakjes(kamerId) {
  var vrij = (C.wereld.slots(kamerId, 'vrij') || []).slice(), uit = [], i, j, ok;
  var r = C.wereld.kamer(kamerId);
  var dp = (r && r.deurPunten && r.deurPunten[0]) || null;
  var dx = dp ? (dp.ix === undefined ? dp.x : dp.ix) : (r ? r.w / 2 : 0);
  var dz = dp ? (dp.iz === undefined ? dp.z : dp.iz) : (r ? r.d / 2 : 0);
  vrij.sort(function (a, b) {
    return (Math.abs(a.x - dx) + Math.abs(a.z - dz)) - (Math.abs(b.x - dx) + Math.abs(b.z - dz));
  });
  for (i = 0; i < vrij.length; i++) {
    ok = true;
    for (j = 0; j < uit.length; j++)
      if (Math.abs(uit[j].x - vrij[i].x) + Math.abs(uit[j].z - vrij[i].z) < 24) ok = false;
    if (ok) uit.push(vrij[i]);
  }
  return uit;
}

function naarKamer(kamerId) {
  if (!kamerId || !C.wereld.kamer(kamerId)) return;
  V.thuis = kamerId;
  if (window.Hotel && Hotel.naarKamer) Hotel.naarKamer(kamerId);
  else C.wereld.naar(kamerId);
  if (V.view === 'plaats') plaatsTeken();
  else if (V.view === 'boek') mijnMeubelKnoppen();
  C.wereld.vuil();
}

function bezet(kamerId, x, z, el) {
  C.snd.zacht();
  var p = { kamer: kamerId || C.wereld.actief(), x: x, z: z };
  if (p.x === null || isNaN(p.x)) {
    var r = C.wereld.kamer(p.kamer);
    p.x = doosPlek(r).x; p.z = doosPlek(r).z;
  }
  wolk({ x: p.x, z: p.z, kamer: p.kamer },
       { id: 'mb_bezet', icoon: '🚫', tekst: 'bezet', klas: 'hulp', hoog: 26, prio: 11 });
  C.wereld.vuil();
  setTimeout(function () { if (C) { wolkWeg('mb_bezet'); C.wereld.vuil(); } }, 2200);
}

function zetNeer(kamerId, x, z) {
  var q = D(), nog = (q.wacht && q.wacht.nog) || [];
  if (!nog.length) return;
  if (!C.wereld.kamer(kamerId) || isNaN(x) || isNaN(z)) return;
  var type = nog[0], w = item(type);
  /* een bed erbij loopt via voegBed: dat verhoogt meteen de gastenlimiet */
  var m = (type === 'bed') ? C.wereld.voegBed(kamerId, { x: x, z: z, rot: 0 })
                           : C.wereld.plaatsMeubel(kamerId, type, x, z, 0);
  if (!m) { bezet(kamerId, x, z); return; }
  q.mijn.push({ id: m.id, type: type });
  nog.shift();
  if (!nog.length) q.wacht = null;
  C.snd.plop(2);
  bewaar(); hud();
  if (q.wacht) plaatsTeken();
  else boek();
  /* feedback als pictogram + getal: een bed betekent een gast erbij */
  if (type === 'bed') {
    wolk({ x: m.x, z: m.z, kamer: kamerId },
         { id: 'mb_neer', icoon: '🐾', getal: C.state.maxGasten(), tekst: 'gasten',
           klas: 'goed', hoog: 26, prio: 12 });
  } else {
    wolk({ x: m.x, z: m.z, kamer: kamerId },
         { id: 'mb_neer', icoon: w.icoon, getal: '✓', klas: 'goed', hoog: 22, prio: 12 });
  }
  C.wereld.vuil();
  setTimeout(function () { if (C) { wolkWeg('mb_neer'); C.wereld.vuil(); } }, 2400);
}

/* =====================================================================
   JE EIGEN MEUBELS: tik = draaien (HOTEL.md 4), doos = weer oppakken
===================================================================== */
function mijnMeubel(id) {
  var q = D(), i;
  for (i = 0; i < q.mijn.length; i++) if (q.mijn[i].id === id) return q.mijn[i];
  return null;
}
function rotVan(id) {
  var l = (C.state.ruw() && C.state.ruw().meubels) || [], i;
  for (i = 0; i < l.length; i++) if (l[i].id === id) return l[i].rot || 0;
  return 0;
}

function mijnMeubelKnoppen() {
  if (!C || !V || V.view !== 'boek') return;
  C.wereld.kamers().forEach(function (r) {
    var n = 0;
    C.wereld.kamerMeubels(r.id).forEach(function (m) {
      var mine = mijnMeubel(m.id);
      if (!mine || n >= 3) return;
      n++;
      var w = item(mine.type) || { icoon: '🪑', naam: 'meubel' };
      /* de twee knopjes staan NAAST het meubel (x+8/z-8 is op het scherm een
         halve knop naar rechts, dezelfde diepte), zodat ze niet op de knop
         van het hotel of op elkaar belanden */
      if (mine.type === 'bed') {
        C.hotspots.maak({
          id: 'mbdraai_' + m.id, kamer: r.id, x: m.x + 8, z: m.z - 8, y: 14,
          icoon: '🔄', klas: 'hotkar', prio: 8, titel: 'bed draaien',
          aan: function () { draai(mine, r.id, m.x, m.z); }
        });
      }
      C.hotspots.maak({
        id: 'mbop_' + m.id, kamer: r.id, x: m.x - 8, z: m.z + 8, y: 14,
        icoon: '📦', klas: 'hotkar', prio: 8, titel: w.naam + ' oppakken',
        aan: function () { pakOp(mine, r.id, m.x, m.z); }
      });
    });
  });
}

/* Draaien = weghalen en op hetzelfde vakje een kwartslag anders terugzetten.
   Lukt dat onverhoopt niet, dan gaat het bed terug in de doos: nooit kwijt. */
function draai(mine, kamerId, x, z) {
  var q = D();
  if (C.state.gastInBed(kamerId, mine.id)) {
    C.snd.zacht();
    wolk({ x: x, z: z, kamer: kamerId }, { id: 'mb_slaap', icoon: '💤', tekst: 'iemand slaapt',
                                           klas: 'hulp', hoog: 26, prio: 11 });
    C.wereld.vuil();
    return;
  }
  var rot = (rotVan(mine.id) + 1) % 2;
  if (!C.wereld.verwijderMeubel(mine.id)) return;
  q.mijn = q.mijn.filter(function (e) { return e.id !== mine.id; });
  var m = C.wereld.voegBed(kamerId, { x: x, z: z, rot: rot }) ||
          C.wereld.voegBed(kamerId, { x: x, z: z }) ||
          C.wereld.voegBed(kamerId, {});
  if (!m) {
    q.wacht = { nog: ((q.wacht && q.wacht.nog) || []).concat(['bed']) };
    bewaar();
    plaats();
    return;
  }
  q.mijn.push({ id: m.id, type: 'bed' });
  C.snd.plop(1);
  bewaar(); hud();
  boek();
  wolk({ x: m.x, z: m.z, kamer: kamerId }, { id: 'mb_neer', icoon: '🔄', getal: '✓',
                                             klas: 'goed', hoog: 24, prio: 12 });
  C.wereld.vuil();
  setTimeout(function () { if (C) { wolkWeg('mb_neer'); C.wereld.vuil(); } }, 1800);
}

function pakOp(mine, kamerId, x, z) {
  var q = D();
  if (mine.type === 'bed' && C.state.gastInBed(kamerId, mine.id)) {
    C.snd.zacht();
    wolk({ x: x, z: z, kamer: kamerId }, { id: 'mb_slaap', icoon: '💤', tekst: 'iemand slaapt',
                                           klas: 'hulp', hoog: 26, prio: 11 });
    C.wereld.vuil();
    return;
  }
  if (!C.wereld.verwijderMeubel(mine.id)) return;
  q.mijn = q.mijn.filter(function (e) { return e.id !== mine.id; });
  q.wacht = { nog: ((q.wacht && q.wacht.nog) || []).concat([mine.type]) };
  C.snd.terug();
  bewaar(); hud();
  V.thuis = kamerId;
  plaats();
}

/* =====================================================================
   AANMELDEN
===================================================================== */
Games.register({
  id: 'meubels',
  naam: 'Het meubelboek',
  kamer: 'receptie',
  hotspot: { obj: 'boek', icoon: '📖', label: 'Boek', hoog: 16 },
  /* Vanaf drie gasten: dan zijn er munten uit het uitchecken en is er ook
     een reden om bij te bouwen (het hotel begint met vier bedden). */
  unlock: function (N) { return N >= 3; },
  stub: false,
  start: start,
  stop: stop
});
})();
