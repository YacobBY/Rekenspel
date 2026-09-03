/* ---------------------------------------------------------------
   games/bedden.js - BEDDEN OP RIJ.

   Het kernspel van het hotel (HOTEL.md 5, hotelwerk 1): de vloer van de
   kamer wordt een bedplan. Uit de dekenkist komen bedjes en die leg je in
   NETTE RIJEN: elke rij is zo breed als de kamer, en jij zoekt uit hoeveel
   rijen er nodig zijn.

   Alles gebeurt ín de kamer (HOTEL.md 9): geen rekenblad ernaast.
     * de dekenkist is een sleepbron met de teller erop: precies zoveel
       bedjes als er gasten komen (net als de zak van de voerkar);
     * elke rij ligt als strookje op de vloer met de bedjes die er al in
       liggen, spookbedjes voor de plekjes die nog leeg zijn, en het aantal
       als cijfer op de rij;
     * de som schrijft zichzelf: een sommenkaart aan de kamer telt de volle
       rijen mee ("2 x 4 = 8");
     * fout? een wolkje met pictogram en getal ("🛏 +2"), nooit een lap
       tekst, nooit een rood kruis, nooit een klok;
     * kamerhulp Wolkje legt na twee pogingen één rij voor met spookbedjes
       en een spookcijfer.

   Wat je hier neerlegt blijft staan: elk bedje dat op de vloer past wordt
   via ctx.wereld.voegBed een ECHT bed, en bedden zijn de harde gastenlimiet
   (HOTEL.md 2). Dit is dus het spel dat het hotel laat groeien.

   De getallen komen uit ctx.state.sommen.tafel(band), nooit uit een eigen
   ladder (GAMES-API.md 3.5):
     groep 3  rijtjes t/m 20, sprongen van 1, 2, 5 en 10 (geen tafels)
     groep 4  alleen de tafels 1, 2, 3, 4, 5 en 10
     groep 5  alle tafels t/m 10, plus de SCHUIFWAND: de rijen in twee
              stukken rekenen (3 rijen van 7 = 2 x 7 + 1 x 7)
   Wat de KAMER begrenst is het aantal rijen: op de vloer passen drie rijen
   plus een lege reserverij, dus het aantal rijen knijpen we tot wat er past.
   De tafel zelf - het aantal bedden per rij - blijft precies zoals de band
   hem geeft.

   Over het neerzetten: de wereld is isometrisch en de knoppenlaag schuift
   knoppen die elkaar afdekken uit elkaar (GAMES-API.md 4). Een rij zou dan
   niet meer op een rij liggen. Daarom rekenen we alle plekken in SCHERM-
   pixels uit en zetten we ze om naar voxels met de schaal van dat moment
   (die hangt af van de kamerbreedte en de scherpte van het scherm).
---------------------------------------------------------------- */
(function () {
'use strict';

var KAMER = 'kamer1';
var MAX_RIJEN = 3;          /* zoveel rijen passen er op deze vloer */
var MAX_PER_RIJ = 10;       /* zoveel bedjes passen er in één strookje */
var GOLF = 260;             /* ms tussen twee bedden van de deken-golf */

/* schermafstanden (px) tussen de kaartjes: een knop is 48 px hoog */
var STAP_PX = 50;           /* van rij naar rij, omlaag (een knop is 48 hoog) */
var BOVEN_PX = 80;          /* de sommenkaart boven de bovenste rij */
var ONDER_PX = 66;          /* de dekenkist onder de onderste rij */
var goot = 132;             /* naar de zijkant, langs de rijen heen; wordt
                               na het tekenen bijgesteld op de echte breedte
                               van een strookje (die hangt van de tafel af) */

var C = null;               /* de ctx */
var D = null;               /* mijn laatje in de opslag: ctx.data() */
var T = [];                 /* eigen tijdertjes (alleen animatie) */
var t0 = 0;
var bezig = false;          /* tijdens de golf even geen tikken */
var kaart = null;           /* de sommenkaart */
var bewaarT = null, maatT = null, opMaat = null;

function tik(fn, ms) { T.push(setTimeout(fn, ms)); }
function stopTikken() { T.forEach(clearTimeout); T = []; }
function bewaarStraks() {
  clearTimeout(bewaarT);
  bewaarT = setTimeout(function () { if (C) C.state.bewaar(); }, 400);
}

/* =====================================================================
   DE SCHAAL: hoeveel schermpixels is één voxel op dit moment?
   world.js tekent met een gehele voxelmaat (g) die met de kamerbreedte en
   de scherpte van het scherm meeschaalt; op een scherpe tablet is een kamer
   dus half zo groot in css-pixels als op een gewone laptop. Zonder deze
   omrekening liggen de rijen op de ene tablet netjes en op de andere niet.
===================================================================== */
var _sch = null, _schT = 0;
function schaal() {
  var nu = Date.now();
  if (_sch && nu - _schT < 250) return _sch;      /* even onthouden: teken()
                                                     vraagt hem tien keer */
  var g = 2, dp = 1, S = 2, H = 2, w;
  try { w = window.World && World.debug(); if (w && w.g) g = w.g; } catch (e) {}
  try { dp = Math.min(3, window.devicePixelRatio || 1); } catch (e) {}
  try { if (window.Art && Art.kit) { S = Art.kit.S || S; H = Art.kit.HG || H; } } catch (e) {}
  _schT = nu;
  _sch = { u: S * g / dp,          /* px per voxel in (x - z): zijwaarts */
           v: (S / 2) * g / dp,    /* px per voxel in (x + z): omlaag     */
           h: H * g / dp };        /* px per voxel omhoog                 */
  return _sch;
}
/* de diagonale stap tussen twee rijen, in voxels */
function rijStap() {
  var s = schaal();
  return Math.max(Math.ceil(STAP_PX / (2 * s.v)), 24);
}
function rijPlek(r) {
  var stap = rijStap(), n = aantalStroken();
  var begin = Math.max(2, Math.round((76 - (n - 1) * stap) / 2));
  return { kamer: KAMER, x: begin + r * stap, z: begin + r * stap };
}
/* een plek die op het scherm dx px opzij en dy px omhoog van rij r ligt */
function plekPx(r, dx, dy) {
  var s = schaal(), p = rijPlek(r), d = dx / (2 * s.u);
  return { kamer: KAMER, x: p.x + d, z: p.z - d, y: 6 + (dy || 0) / s.h };
}

/* =====================================================================
   DE OPDRACHT: rijen x bedden-per-rij, uit ctx.state.sommen.tafel
===================================================================== */
function opdracht() {
  var band = C.state.band();
  var s = C.state.sommen.tafel(band) || {};
  var perRij = Math.max(1, Math.min(MAX_PER_RIJ, s.a || 2));
  var rijen = Math.max(1, Math.min(MAX_RIJEN, s.b || 2));
  return { band: band, perRij: perRij, rijen: rijen, doel: rijen * perRij };
}
function signatuur(o) {
  return [o.band, C.state.dag(), C.state.N(), o.rijen, o.perRij].join('|');
}
function nieuweOpdracht(o, sig) {
  D.sig = sig;
  D.band = o.band;
  D.rijen = o.rijen;
  D.perRij = o.perRij;
  D.doel = o.doel;
  D.rij = [];                                  /* aantal bedjes per rij */
  D.missers = 0;
  D.klaar = false;
  D.nieuw = 0;
  D.over = 0;
  D.spook = false;
  D.fase = 'leg';            /* leg -> feest -> af */
  /* de schuifwand hoort bij groep 5 (verdeelstrategie, HOTEL.md 5) */
  D.wand = o.band >= 5 && o.rijen >= 2 ? o.rijen - 1 : 0;
}

/* =====================================================================
   DE RIJEN
===================================================================== */
function aantalStroken() { return Math.min(MAX_RIJEN + 1, (D ? D.rijen : 1) + 1); }
function rijTel(r) { return (D.rij && D.rij[r]) || 0; }
function totaal() {
  var n = 0, r;
  for (r = 0; r < aantalStroken(); r++) n += rijTel(r);
  return n;
}
function volleRijen() {
  var n = 0, r;
  for (r = 0; r < aantalStroken(); r++) if (rijTel(r) === D.perRij) n++;
  return n;
}
function eersteLegeRij() {
  var r;
  for (r = 0; r < aantalStroken(); r++) if (rijTel(r) < D.perRij) return r;
  return -1;
}
function kistOver() { return Math.max(0, D.doel - totaal()); }

function legIn(r) {
  if (!C || bezig || D.klaar) return;
  if (rijTel(r) >= D.perRij) {                 /* deze rij is al vol */
    C.snd.zacht();
    wolk('bd_op', plekPx(r, -goot, 0), { icoon: '🛏', getal: D.perRij, klas: 'hulp' });
    tik(function () { if (C) C.ui.wolkWeg('bd_op'); }, 1800);
    return;
  }
  if (kistOver() <= 0) {                       /* de kist is leeg */
    C.snd.zacht();
    wolk('bd_op', plekPx(aantalStroken() - 1, 0, -ONDER_PX), { icoon: '🧺', getal: 0, klas: 'hulp' });
    tik(function () { if (C) C.ui.wolkWeg('bd_op'); }, 1800);
    return;
  }
  D.rij[r] = rijTel(r) + 1;
  D.laatste = r;
  C.ui.wolkWeg('bd_op');
  C.ui.wolkWeg('bd_fout');
  C.snd.plop(1);
  bewaarStraks();
  teken();
}
function terug() {
  if (!C || bezig || D.klaar) return;
  var r = D.laatste, i;
  if (r === undefined || !rijTel(r)) {
    r = -1;
    for (i = aantalStroken() - 1; i >= 0; i--) if (rijTel(i)) { r = i; break; }
  }
  if (r < 0) { C.snd.zacht(); return; }
  D.rij[r] = rijTel(r) - 1;
  D.laatste = r;
  C.ui.wolkWeg('bd_fout');
  C.snd.terug();
  bewaarStraks();
  teken();
}

/* =====================================================================
   TEKENEN: alles hangt in de kamer
===================================================================== */
function wolk(id, obj, o) {
  o = o || {};
  o.id = id;
  o.door = 'bedden';
  if (o.hoog === undefined) o.hoog = 6;
  return C.ui.wolk(obj, o);
}

/* De kamer even rustig maken: de knoppen van het hotel die precies op onze
   rijen vallen (een vrij bed, de speelmand, het bakje) zeggen tijdens dit
   spel niets nuttigs en zouden de rijen uit elkaar duwen. stop() zet ze met
   Hotel.render() weer terug. */
function rustigeKamer() {
  if (!C) return;
  ['bed_' + KAMER + '_bed1', 'bed_' + KAMER + '_bed2',
   'mand_' + KAMER, 'bak_' + KAMER + '_bak'].forEach(function (id) { C.hotspots.weg(id); });
  C.wereld.kamerMeubels(KAMER).forEach(function (m) {
    if (m.soort === 'bed') C.hotspots.weg('bed_' + KAMER + '_' + m.id);
  });
}

/* het strookje van één rij: de bedjes die er liggen, spookbedjes voor de
   plekjes die nog leeg zijn, en het aantal als cijfer op de rij */
function strookHtml(r) {
  var n = rijTel(r), i, spook = D.spook && r === eersteLegeRij() && !D.klaar;
  /* bij tien bedjes in een rij wordt het strookje anders te breed voor een
     telefoon in portret; dan tekenen we de bedjes een tikje kleiner */
  var s = '<span class="ico" style="font-size:' + (D.perRij >= 10 ? '.8rem' : '.95rem') + '">';
  for (i = 0; i < n; i++) s += D.klaar ? '🛌' : '🛏';
  for (; i < D.perRij; i++) s += '<span style="opacity:' + (spook ? '.62' : '.22') + '">🛏</span>';
  return s + '</span><span class="get">' + n + '</span>';
}

function teken() {
  if (!C || !D) return;
  var r, p, laatste = aantalStroken() - 1, vol = volleRijen();
  rustigeKamer();
  /* Na het feest halen we de strookjes weg: dan zie je de kamer zoals hij
     nu is - vol met echte bedden. Dat is de beloning. */
  if (D.fase === 'af') { alleenSom(); return; }

  for (r = 0; r < aantalStroken(); r++) {
    p = rijPlek(r);
    (function (rr) {
      C.hotspots.maak({
        id: 'bd_rij' + rr, kamer: KAMER, x: p.x, z: p.z, y: 6,
        kind: 'drop', drop: 'bedrij', data: { rij: rr },
        klas: 'hotbron', html: strookHtml(rr), prio: 13,
        /* vast = dit strookje wijkt nooit uit; de andere knoppen (ook die
           van het hotel) schuiven eromheen. Zo blijft een rij een rij, op
           elk scherm en bij elke voxelmaat (hits.js). */
        vast: true,
        titel: 'rij ' + (rr + 1) + ': ' + rijTel(rr) + ' van ' + D.perRij,
        aan: function () { legIn(rr); }
      });
    })(r);
  }
  for (r = aantalStroken(); r < MAX_RIJEN + 2; r++) C.hotspots.weg('bd_rij' + r);
  /* hoe breed is een strookje echt? daarnaast passen de andere kaartjes */
  var el = document.querySelector('[data-hot="bd_rij0"]');
  goot = Math.max(88, ((el && el.offsetWidth) || 160) / 2 + 52);

  /* de dekenkist: sleepbron met de teller erop, aan het voeteneind */
  var kp = plekPx(laatste, 0, -ONDER_PX);
  C.hotspots.bron(kp, {
    id: 'bd_kist', icoon: '🧺', aantal: kistOver(), hoog: kp.y,
    klas: D.klaar ? 'leeg' : '', prio: 12, kamer: KAMER,
    titel: 'dekenkist met ' + kistOver() + ' bedjes',
    tik: function () { if (!D.klaar) C.snd.tik(); },
    sleep: {
      dropSel: '[data-drop="bedrij"]',
      ghostHTML: function () { return '<div style="font-size:34px">🛏</div>'; },
      canDrag: function () { return !bezig && !D.klaar && kistOver() > 0; },
      onDrop: function (t) { legIn(+t.getAttribute('data-h-rij')); },
      onTap: function () { C.snd.tik(); }
    }
  });

  /* eentje terug in de kist */
  if (!D.klaar && totaal() > 0) {
    var up = plekPx(laatste, -goot, 0);
    C.hotspots.maak({
      id: 'bd_undo', kamer: KAMER, x: up.x, z: up.z, y: up.y,
      icoon: '↩', klas: 'hotwolk', prio: 11, titel: 'eentje terug in de kist',
      aan: terug
    });
  } else C.hotspots.weg('bd_undo');

  /* de som schrijft zichzelf: zoveel volle rijen x zoveel per rij */
  if (!D.klaar) {
    kaart = C.ui.somkaart(plekPx(0, 0, BOVEN_PX), (vol || '?') + ' × ' + D.perRij + ' =',
      { id: 'bd_som', door: 'bedden', pad: false, hoog: plekPx(0, 0, BOVEN_PX).y, kamer: KAMER });
    if (kaart) kaart.zet(vol ? vol * D.perRij : '');
  }

  /* de opdracht hangt boven de gast die op een bed wacht: één pictogram,
     één getal, geen woord */
  var wacht = C.wereld.dieren().filter(function (g) { return !g.bed; })[0];
  var wd = wacht ? C.wereld.dier(wacht.id) : null;
  if (wd && wd.kamer === KAMER && !D.klaar)
    wolk('bd_wolk', wacht.id, { icoon: '🛏', getal: D.doel, hoog: 52, prio: 12 });
  else C.ui.wolkWeg('bd_wolk');

  /* de schuifwand van groep 5: de rijen in twee stukken rekenen */
  if (D.wand && !D.klaar) {
    var a = D.wand, b = D.rijen - D.wand;
    var wp = plekPx(D.wand, goot, STAP_PX / 2);
    C.hotspots.maak({
      id: 'bd_wand', kamer: KAMER, x: wp.x, z: wp.z, y: wp.y,
      klas: 'hotwolk hulp', prio: 11,
      html: '<span class="ico">🚧</span><span class="get" style="font-size:.95rem;line-height:1.02">' +
            (a * D.perRij) + '<br>+' + (b * D.perRij) + '</span>',
      titel: a + ' × ' + D.perRij + ' + ' + b + ' × ' + D.perRij,
      aan: schuif
    });
  } else C.hotspots.weg('bd_wand');

  /* klaar? tik op de deur van de kamer, of op dit pootje rechtsboven */
  if (!D.klaar) {
    var kl = plekPx(0, goot, 56);
    C.hotspots.maak({
      id: 'bd_klaar', kamer: KAMER, x: kl.x, z: kl.z, y: kl.y,
      icoon: '🐾', getal: D.doel, klas: 'hotwolk goed', prio: 14,
      titel: D.doel + ' gasten mogen erin', aan: check
    });
  } else C.hotspots.weg('bd_klaar');

  /* kamerhulp na twee pogingen */
  if (D.missers >= 2 && !D.klaar) {
    var hp = plekPx(laatste, -goot, -STAP_PX);
    C.hotspots.maak({
      id: 'bd_hulp', kamer: KAMER, x: hp.x, z: hp.z, y: hp.y,
      icoon: '🐑', klas: 'hotwolk hulp', prio: 11, titel: 'kamerhulp Wolkje',
      aan: hulp
    });
  } else C.hotspots.weg('bd_hulp');

  C.wereld.vuil();
}

/* de opgeruimde eindstand: alleen de sommenkaart en één wolkje */
function alleenSom() {
  var r;
  for (r = 0; r < MAX_RIJEN + 2; r++) C.hotspots.weg('bd_rij' + r);
  ['bd_kist', 'bd_undo', 'bd_wand', 'bd_klaar', 'bd_hulp'].forEach(function (id) {
    C.hotspots.weg(id);
  });
  C.ui.wolkWeg('bd_wolk');
  wolk('bd_goed', plekPx(0, goot, 0), {
    icoon: '🛏', getal: '+' + (D.nieuw || 0), klas: 'goed', prio: 14,
    tik: function () { C.sluit(); }
  });
  C.wereld.vuil();
}

function schuif() {
  if (!D.wand) return;
  D.wand = D.wand - 1 < 1 ? D.rijen - 1 : D.wand - 1;
  C.snd.tik();
  bewaarStraks();
  teken();
}

/* de deur van deze kamer, alleen uit de gedocumenteerde kamerdata */
function deurPlek() {
  var r = C.wereld.kamer(KAMER) || {};
  var d = (r.deuren || [])[0];
  var w = r.w || 76, dp = r.d || 76;
  if (!d) return { x: w / 2, z: 0, ix: w / 2, iz: 10 };
  var m = d.at + (d.breed || 12) / 2;
  if (d.wand === 'z') return { x: Math.min(m, w - 2), z: 0, ix: Math.min(m, w - 2), iz: 10 };
  return { x: 0, z: Math.min(m, dp - 2), ix: 10, iz: Math.min(m, dp - 2) };
}

/* =====================================================================
   DE CONTROLE - vriendelijk, en nooit een stap terug
===================================================================== */
function check() {
  if (!C || !D || bezig || D.klaar) return;
  var r, n, oneven = -1, vol = 0, leeg = -1, over = kistOver();
  for (r = 0; r < aantalStroken(); r++) {
    n = rijTel(r);
    if (n === D.perRij) vol++;
    else if (n > 0) { if (oneven < 0) oneven = r; }
    else if (leeg < 0) leeg = r;
  }
  if (!over && oneven < 0 && vol === D.rijen) { gelukt(); return; }

  /* ---- zachte hulp: pictogram + getal, precies bij het plekje dat het is ---- */
  D.missers++;
  var mik = null, ic = '🛏', getal = '';
  if (oneven >= 0) {                       /* een scheve rij: die vullen we aan */
    mik = plekPx(oneven, -goot, 0);
    getal = '+' + (D.perRij - rijTel(oneven));
  } else if (over > 0 && leeg >= 0) {      /* er kan nog een hele rij bij */
    mik = plekPx(leeg, -goot, 0);
    getal = '+' + Math.min(over, D.perRij);
  } else if (over > 0) {                   /* nog bedjes in de kist */
    mik = plekPx(aantalStroken() - 1, -goot, -ONDER_PX);
    getal = '+' + over;
  } else {                                 /* een rij te veel: er mag er een terug */
    mik = plekPx(Math.max(0, vol - 1), -goot, 0);
    ic = '↩';
    getal = '-' + Math.max(1, (vol - D.rijen) * D.perRij);
  }
  C.snd.zacht();
  teken();
  wolk('bd_fout', mik, { icoon: ic, getal: getal, klas: 'hulp', prio: 14 });
  if (wachtInDeuropening()) tik(function () { if (C) teken(); }, 2000);
  bewaarStraks();
  if (D.missers === 2) tik(hulp, 900);
}

/* het laatste dier gaat in de deuropening wachten - geduldig, nooit boos */
function wachtInDeuropening() {
  var zonder = C.wereld.dieren().filter(function (g) { return !g.bed; });
  if (!zonder.length) return null;
  var g = zonder[zonder.length - 1], p = deurPlek();
  C.wereld.reis(g.id, KAMER, { x: p.ix, z: p.iz, na: 'wacht' });
  return g;
}

/* =====================================================================
   GELUKT: de dekens vouwen open, de bedden worden ECHT
===================================================================== */
function gelukt() {
  D.klaar = true;
  D.fase = 'feest';
  D.spook = false;
  bezig = true;
  C.state.tel(!D.missers, C.ui.nu() - t0);
  C.snd.tover();
  C.ui.wolkWeg('bd_fout');
  spookWeg();
  somAf();
  D.nieuw = 0;
  D.over = D.doel;
  teken();
  wolk('bd_goed', plekPx(0, goot, 0), { icoon: '⭐', getal: D.doel, klas: 'goed', prio: 14 });
  bouwBedden(D.doel, function (gelegd) {
    bezig = false;
    if (!C) return;
    D.nieuw = gelegd.length;
    D.over = Math.max(0, D.doel - gelegd.length);
    C.taakKlaar('bedden', { sterren: 1 });
    C.hotspots.laat();                    /* de deur is weer gewoon de deur */
    teken();
    wolk('bd_goed', plekPx(0, goot, 0),
         { icoon: '🛏', getal: '+' + D.nieuw, klas: 'goed', prio: 14 });
    gastenErin(gelegd);
    bewaarStraks();
    /* even nagenieten, dan de kaartjes weg en de kamer terug aan het hotel */
    tik(function () {
      if (!C || !D) return;
      D.fase = 'af';
      teken();
      tik(function () { if (C) C.sluit(); }, 3400);
    }, 2600);
  });
}
function somAf() {
  if (kaart) { kaart.weg(); kaart = null; }
  var p = plekPx(0, 0, BOVEN_PX);
  kaart = C.ui.somkaart(p, D.rijen + ' × ' + D.perRij + ' =',
    { id: 'bd_som', door: 'bedden', pad: false, hoog: p.y, kamer: KAMER });
  if (kaart) { kaart.zet(D.doel); kaart.klaar(); }
}

/* het vrije vakje dat het verst van alle bedden af ligt: zo staan de nieuwe
   bedden mooi verdeeld door de kamer in plaats van tegen elkaar aan */
function besteVak() {
  var vrij = C.wereld.slots(KAMER, 'vrij').slice();
  var bedden = C.wereld.slots(KAMER, 'bed');
  var beste = null, best = -1, i, j, dm, d;
  for (i = 0; i < vrij.length; i++) {
    dm = 1e9;
    for (j = 0; j < bedden.length; j++) {
      d = Math.abs(bedden[j].x - vrij[i].x) + Math.abs(bedden[j].z - vrij[i].z);
      if (d < dm) dm = d;
    }
    if (dm > best) { best = dm; beste = vrij[i]; }
  }
  return beste;
}

/* Eén bed per stap: dat is de golf die je in de kamer ziet gebeuren.
   Past er geen bed meer bij, dan stoppen we - nooit een half bed. */
function bouwBedden(hoeveel, klaar) {
  var gelegd = [];
  function stap() {
    if (!C) return;
    if (gelegd.length >= hoeveel) { klaar(gelegd); return; }
    var v = besteVak();
    var b = v ? C.wereld.voegBed(KAMER, { x: v.x, z: v.z }) : null;
    if (!b) { klaar(gelegd); return; }
    gelegd.push(b);
    rustigeKamer();
    C.snd.plop(1);
    tik(stap, GOLF);
  }
  stap();
}

/* de gasten die nog geen bed hebben lopen naar hun nieuwe bed toe */
function gastenErin(gelegd) {
  var zonder = C.wereld.dieren().filter(function (g) { return !g.bed; });
  if (!zonder.length || !gelegd.length) return;
  gelegd.forEach(function (b, i) {
    var g = zonder[i];
    if (!g) return;
    tik(function () {
      if (!C) return;
      var s = C.wereld.slot(KAMER, b.id);
      if (s) C.wereld.reis(g.id, KAMER, { x: s.sx, z: s.sz, na: 'blij' });
      C.wereld.setMood(g.id, 'bouncy');
    }, 300 + i * 480);
  });
}

/* =====================================================================
   KAMERHULP WOLKJE doet één rij voor: spookbedjes + spookcijfer
===================================================================== */
function spookWeg() {
  if (!C) return;
  C.wereld.getalTag({ x: 0, z: 0 }, null, { id: 'bd_spook' });
}
function hulp() {
  if (!C || !D || D.klaar) return;
  var r = eersteLegeRij();
  if (r < 0) return;
  D.spook = true;
  teken();
  var p = plekPx(r, -(goot - 26), 0);
  C.wereld.getalTag({ kamer: KAMER, x: p.x, z: p.z }, D.perRij,
                    { id: 'bd_spook', y: p.y, klas: 'hotspook', titel: 'zoveel in een rij' });
  wolk('bd_wolkje', plekPx(r, -goot, STAP_PX), {
    icoon: '🐑', getal: D.perRij, klas: 'hulp', prio: 14,
    tik: function () {
      C.ui.wolkWeg('bd_wolkje');
      if (!D || D.klaar) return;
      D.rij[r] = D.perRij;                 /* Wolkje legt de rij echt neer */
      D.laatste = r;
      C.snd.ja();
      bewaarStraks();
      teken();
    }
  });
  C.state.zetGezien('bedden_wolkje');
  C.snd.brief();
}

/* =====================================================================
   START / STOP
===================================================================== */
function start(ctx) {
  C = ctx;
  D = C.data();
  var o = opdracht(), sig = signatuur(o);
  if (D.sig !== sig || !D.rij) nieuweOpdracht(o, sig);
  t0 = C.ui.nu();
  bezig = false;
  C.wereld.naar(KAMER);
  if (D.klaar) { if (D.fase !== 'af') D.fase = 'af'; somAf(); }
  else {
    /* de deur van de kamer is zolang het "klaar"-moment (GAMES-API.md 2) */
    (C.wereld.kamer(KAMER).deuren || []).forEach(function (d) {
      C.hotspots.pak('deur_' + KAMER + '_' + d.naar, check);
    });
  }
  /* draait het scherm, dan verandert de voxelmaat: opnieuw uitleggen */
  opMaat = function () {
    _sch = null;
    clearTimeout(maatT);
    maatT = setTimeout(function () { if (C) teken(); }, 260);
  };
  window.addEventListener('resize', opMaat);
  window.addEventListener('orientationchange', opMaat);
  teken();
}

function stop() {
  stopTikken();
  clearTimeout(bewaarT);
  clearTimeout(maatT);
  bewaarT = maatT = null;
  if (opMaat) {
    window.removeEventListener('resize', opMaat);
    window.removeEventListener('orientationchange', opMaat);
    opMaat = null;
  }
  if (C) {
    if (kaart) kaart.weg();
    ['bd_wolk', 'bd_fout', 'bd_goed', 'bd_op', 'bd_wolkje'].forEach(function (id) {
      C.ui.wolkWeg(id);
    });
    spookWeg();
    C.state.bewaar();
    C.hotspots.wisAlles();              /* geeft ook de geleende deur terug */
    if (window.Hotel) Hotel.render();   /* de kamer is weer van het hotel */
  }
  kaart = null;
  C = null;
  D = null;
  bezig = false;
}

/* =====================================================================
   AANMELDEN
===================================================================== */
Games.register({
  id: 'bedden',
  naam: 'Bedden op rij',
  kamer: KAMER,
  /* de dekenkist: de mand in de hoek van de kamer, ver van de bedden en van
     de deur af, zodat geen enkele knop een andere afdekt */
  hotspot: { obj: 'mand', icoon: '🛏', label: 'Bedden', hoog: 14, dx: -4, dz: -4 },
  unlock: function (N) { return N >= 1; },
  stub: false,
  start: start,
  stop: stop
});
})();
