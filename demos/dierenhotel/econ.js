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
   DE REKENING - helemaal ín de wereld (HOTEL.md 9)

   Aan de balie staat de kassa; vóór de balie ligt één sommenkaartje waar je
   aan rekent: bovenaan één gewone zin die zegt waar het geld voor is ("Boef
   sliep 3 nachten, EUR5 per nacht"), daaronder de som (3 x EUR5 =) met een
   klein cijferpad eronder. Een kaal sommetje zonder zin snapt een kind van zes
   niet (HOTEL.md 9). De familie houdt een buidel vast:
   sleep of tik de munten naar de kassa, het bedrag staat als cijfer op de
   toonbank. Feedback is een wolkje met een pictogram en een getal; na de
   derde keer tellen liggen er spookmunten. Geen rekenblad, geen lappen tekst.
===================================================================== */
var R = null;
var BANK = 'kassa', BUIDEL = 'boek';        /* kassa en buidel op de balie */
/* De kaart waar je AAN REKENT ligt rechts achterin, op dezelfde plek als het
   check-inkaartje (hotel.js CI_PLEK) - de familie wacht links vooraan
   (hotel.js WACHTPLEK). Op de kassa zelf (44,40) stond de kaart over de
   familie (naamplaatje 97%, dier 100%) en in liggend beeld ook over de buidel
   (100%); bij het wisselgeld lag hij bovendien over het bonnetje. Twee
   kaartjes ónder elkaar kan niet: in liggend beeld is het kader maar 200 px
   hoog, dus de hotspot-laag klemt ze tegen elkaar (gemeten 38-64% dekking bij
   elke hoogte). Daarom: ÉÉN werkkaart. Het bonnetje ligt op die plek zolang er
   munten geteld worden en gaat weg bij de wisselgeldvraag, die dezelfde plek
   inneemt (dekking bonnetje-door-wisselkaart: 0%). */
var WERKPLEK = { x: 70, z: 20, kamer: 'receptie' };
var WERKHOOG = 16;

function rekening(o) {
  var tot = o.totaal || o.nachten * o.prijs;
  R = {
    gast: o.gast, nachten: o.nachten, prijs: o.prijs, totaal: tot,
    hand: buidel(o.betaald === undefined ? tot : o.betaald),
    bank: [],
    stap: 1,            /* 1 = som, 2 = munten tellen, 3 = wisselgeld */
    pogingen: 0,        /* pogingen op de som nachten x prijs */
    telPog: 0,          /* pogingen op het muntjes tellen */
    wissel: 0, wisselPog: 0,
    fam: o.fam || 'de familie',
    onKlaar: o.onKlaar,
    t0: Ui.nu(), klaar: false, kaart: null, bronH: null
  };
  if (window.Hotel) Hotel.naarKamer('receptie');
  bouw();
  return R;
}

/* ---------- alles wat de rekening in de wereld neerzet ---------- */
function wis() {
  Hits.wisEigenaar('rekening');
  spookWeg();
}
function spookWeg() {
  for (var i = 0; i < 6; i++) World.getalTag({ x: 0, z: 0 }, null, { id: 'spook' + i });
}
function spook(bedrag, lbl) {
  spookWeg();
  /* De spookmunten liggen op de vrije vloer vóór de balie, onder de werkkaart
     en rechts van de wachtende familie: op hun oude plek (30..72, z 26..40)
     lagen ze precies achter het kaartje. */
  var munten = splits(bedrag), i;
  for (i = 0; i < munten.length && i < 6; i++) {
    World.getalTag({ x: 40 + (i % 3) * 15, z: 70 + (i > 2 ? 6 : 0), kamer: 'receptie' },
                   '\u20AC' + munten[i],
                   { id: 'spook' + i, door: 'rekening', y: 4, klas: 'hotspook',
                     titel: lbl || 'zo ziet het uit' });
  }
}

function bouw() {
  if (!R) return;
  wis();
  var g = R.gast;
  /* de familie met de gast: één korte regel boven het dier */
  Ui.wolk(g.id, { id: 'rek_gast', door: 'rekening', icoon: '👪',
                  tekst: g.naam + ' gaat naar huis', klas: 'goed', prio: 8 });
  if (R.stap === 1) somStap();
  else muntStap();
}

/* de zin boven de rekening: wie er sliep, hoeveel nachten, en de prijs per
   nacht. Eén nacht blijft "1 nacht" - meervoud() doet dat. */
function bonZin() {
  return R.gast.naam + ' sliep ' + meervoud(R.nachten, 'nacht', 'nachten') +
         ', \u20AC' + R.prijs + ' per nacht';
}

/* ---------- stap 1: nachten x prijs ---------- */
function somStap() {
  R.kaart = Ui.somkaart(WERKPLEK, R.nachten + ' \u00D7 \u20AC' + R.prijs + ' =', {
    id: 'rek_som', door: 'rekening', open: true, max: 2, hoog: WERKHOOG,
    icoon: '\uD83D\uDECF', regel: bonZin(),
    onOk: function (n) { somOk(n); }
  });
  /* Zelfde ladder als in de winkel van Zilverhoef, en overal dezelfde:
     1e keer samen tellen, 2e keer nog eens, en pas bij de DERDE poging
     liggen er spookvormen. Dat geldt hier, bij het munten tellen en bij
     het wisselgeld. */
  if (R.pogingen >= 1) R.kaart.hulp(Ui.telMee(R.prijs, R.nachten, ''));
  if (R.pogingen >= 3) spook(R.totaal, 'zoveel is het samen');
  World.getalTag({ x: 30, z: 44, kamer: 'receptie' }, null, { id: 'bank' });
}

function somOk(n) {
  if (n === null) { Ui.wolk(BANK, { id: 'rek_hint', door: 'rekening', icoon: '☝', tekst: 'tik een getal', klas: 'hulp' }); return; }
  if (n === R.totaal) {
    if (window.State) State.tel(R.pogingen === 0, Ui.nu() - R.t0);
    R.kaart.zet(n).klaar();
    R.stap = 2;
    if (window.Snd) Snd.ja();
    setTimeout(function () { if (R && R.stap === 2) { bouw(); } }, 500);
    return;
  }
  R.pogingen++;
  R.kaart.zet('');
  if (window.Snd) Snd.zacht();
  bouw();
}

/* ---------- stap 2 en 3: munten leggen en wisselgeld ---------- */
function muntStap() {
  var betaald = som(R.bank);
  /* Tijdens het TELLEN blijft de rekening als afgevinkt kaartje liggen op
     precies de plek waar je hem net uitrekende: dat is de regel waar je dan
     naar kijkt, en hij springt niet weg. Op de kassa zelf lag hij over de
     buidel van de familie (liggend: buidel 100% bedekt, bonnetje 28% bedekt
     door bel + buidel); op de werkplek is de somregel 0% bedekt.
     Bij het wisselgeld gaat het bonnetje weg: de wisselkaart komt op dezelfde
     plek en zegt zelf al wie wat gaf en wat het kost. Het betaalde bedrag
     blijft als cijfer op de toonbank staan. */
  if (R.stap !== 3) {
    Ui.somkaart(WERKPLEK, R.nachten + ' \u00D7 \u20AC' + R.prijs + ' = ' + R.totaal, {
      id: 'rek_bon', door: 'rekening', pad: false, hoog: WERKHOOG,
      icoon: '\uD83D\uDECF', regel: bonZin()
    }).klaar();
  }

  if (R.stap === 3) {
    World.getalTag({ x: 30, z: 44, kamer: 'receptie' }, '\u20AC' + betaald,
                   { id: 'bank', door: 'rekening', y: 18, titel: 'op de toonbank' });
    wisselKaart();
    return;
  }

  /* de toonbank: sleep of tik de munten hierheen, het bedrag staat erop */
  Hits.maak({
    id: 'rek_bank', door: 'rekening', kamer: 'receptie', x: 30, z: 44, y: 18,
    icoon: '\uD83E\uDDFE', getal: '\u20AC' + betaald,
    kind: 'drop', drop: 'toonbank', klas: 'hotbron', prio: 11,
    titel: 'de toonbank', aan: function () { legNeer(); }
  });
  /* de buidel van de familie: de volgende munt staat erop */
  var volgende = R.hand.length ? R.hand[0] : null;
  R.bronH = Ui.bron(BUIDEL, {
    id: 'rek_buidel', door: 'rekening', hoog: 18,
    icoon: volgende ? '\uD83E\uDE99' : '\uD83D\uDC4D',
    aantal: volgende ? '\u20AC' + volgende.v : '',
    hand: R.hand.length || null,
    klas: R.hand.length ? '' : 'leeg',
    titel: volgende ? 'munt van ' + volgende.v + ' euro' : 'de buidel is leeg',
    tik: function () { legNeer(); },
    sleep: {
      dropSel: '[data-drop="toonbank"]',
      ghostHTML: function () { return '<div class="karghost">\uD83E\uDE99</div>'; },
      canDrag: function () { return !!(R && R.hand.length); },
      onDrop: function () { legNeer(); }
      /* geen onTap: een tik komt via `tik` binnen, precies één keer */
    }
  });
  /* klaar-met-tellen staat naast de toonbank */
  Hits.maak({
    id: 'rek_ok', door: 'rekening', kamer: 'receptie', x: 62, z: 22, y: 14,
    icoon: '\u2714', label: 'klaar', klas: 'hotwolk goed', prio: 10,
    titel: 'klaar met tellen', aan: function () { klaarMetTellen(); }
  });
}
function mikx(obj) {
  var p = World.mik(obj, 'receptie');
  return p || { x: 44, z: 40 };
}

function wisselKaart() {
  var betaald = som(R.bank);
  R.kaart = Ui.somkaart(WERKPLEK, '\u20AC' + betaald + ' \u2212 \u20AC' + R.totaal + ' =', {
    /* dezelfde werkplek vóór de balie als de eerste som en het bonnetje: het
       bonnetje is bij deze stap weg, dus er staat niets onder of over */
    id: 'rek_wissel', door: 'rekening', open: true, max: 2, hoog: WERKHOOG,
    icoon: '\uD83D\uDC5B',
    regel: R.gast.naam + ' gaf \u20AC' + betaald + ', het kost \u20AC' + R.totaal,
    onOk: function (n) { wisselOk(n); }
  });
  if (R.wisselPog === 1) R.kaart.hulp(R.totaal + ' \u2192 ' + betaald);
  if (R.wisselPog >= 2) R.kaart.hulp(Ui.telMee(1, betaald - R.totaal, ''));
  if (R.wisselPog >= 3) spook(betaald - R.totaal, 'zoveel krijgt de familie terug');
}

function legNeer() {
  if (!R || R.stap === 3 || !R.hand.length) return;
  R.bank.push(R.hand.shift());
  if (window.Snd) Snd.munt();
  var s = som(R.bank);
  bouw();
  Ui.wolk(BANK, { id: 'rek_tel', door: 'rekening', icoon: '🪙', getal: '\u20AC' + s, prio: 7 });
}

/* Klaar-met-tellen zit alleen in stap 2: in stap 3 (wisselgeld) staat deze
   knop er niet, want dan rekent het kind af met het cijferpad. */
function klaarMetTellen() {
  if (!R || R.stap !== 2) return;
  var t = som(R.bank), p = R.totaal;
  if (t === p) { gelukt(0); return; }
  if (t < p) {
    /* eigen teller: een misrekening bij de SOM mag de spookmunten bij het
       TELLEN niet vooruit halen (zoals in de winkel van Zilverhoef) */
    R.telPog++;
    var rest = p - t;
    if (window.Snd) Snd.zacht();
    bouw();
    Ui.wolk(BANK, { id: 'rek_hint', door: 'rekening', icoon: '🪙',
                    getal: '+\u20AC' + rest, klas: 'hulp', prio: 9 });
    if (R.telPog >= 3) spook(rest, 'dit moet er nog bij');
    return;
  }
  R.stap = 3; R.wisselPog = 0; spookWeg();
  bouw();
}

function wisselOk(n) {
  var goed = som(R.bank) - R.totaal;
  if (n === null) { Ui.wolk(BANK, { id: 'rek_hint', door: 'rekening', icoon: '☝', tekst: 'tik een getal', klas: 'hulp' }); return; }
  if (n === goed) {
    if (window.State) State.tel(R.wisselPog === 0, Ui.nu() - (R.tw || R.t0));
    gelukt(goed);
    return;
  }
  R.wisselPog++;
  if (window.Snd) Snd.zacht();
  bouw();
}

function gelukt(wissel) {
  var uit = { totaal: R.totaal, betaald: som(R.bank), wissel: wissel,
              pogingen: R.pogingen + R.telPog + R.wisselPog, gast: R.gast };
  R.klaar = true;
  R.wissel = wissel;
  if (window.Snd) Snd.tover();
  var cb = R.onKlaar, g = R.gast, mijn = R;      /* token van déze rekening */
  wis();
  Ui.wolk(g.id, { id: 'rek_af', door: 'rekening', icoon: '👋',
                  getal: wissel > 0 ? '\u20AC' + wissel : '\u2714',
                  tekst: wissel > 0 ? 'terug' : 'betaald', klas: 'goed', prio: 12 });
  setTimeout(function () {
    Hits.weg('rek_af');
    if (R === mijn) R = null;                   /* staat er alweer een nieuwe? laat staan */
    if (cb) cb(uit);
  }, 1100);
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
