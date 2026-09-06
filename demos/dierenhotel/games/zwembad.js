/* ----------------------------------------------------------------
   HET ZWEMBAD (zwembad) - kamer zwembad, wens 🏊 zwemmen (golf 3, G1)

   Alles gebeurt ín de wereld (HOTEL.md 9): geen rekenblad naast de kamer.
     * het bad van rooms.js (Rooms.get('zwembad').bad) is de getallenlijn:
       een baan van L meter ligt LINEAIR op x = x0 + (x1 - x0) * p / L,
       de zwembaan is z = (z0 + z1) / 2;
     * op de badrand staan meterstrepen (0, 5, 10, ... als L <= 20, anders
       0, 10, 20, ...) en bij de overkant staat een vlag op L meter, met het
       getal erop als getalTag - dat is los decor van dit spel (P1b);
     * het dier zwemt precies één meter per slag (ctx.wereld.stappen met
       één punt per meter en pose 'zwem', P1c) en draagt zijn stand als
       cijfer ("30 m") mee (ctx.wereld.getalTag);
     * de sommenkaart hangt náást of ónder de kamer, nooit over de zwemmer:
       zin + tweede regel + één strook van vier keuzeknoppen met meters.

   HET REKENEN (HOTEL.md 3: T = k * N + r, plafond per band)
     groep 3   L = 5N + r, 8..20 m,  M = 10   -> 14 = 10 + 4
     groep 4   L = 8N + r, 21..50 m, M = 30   -> 43 = 30 + 13
     groep 5   L = 7N + r, 31..80 m, M = 30 of 40, rest over een tiental
                                              -> 76 = 40 + 36
   Groep 5 houdt in de praktijk op bij L = 76 (N = 10, r = 6): een baan mag
   hoogstens twee etappes kosten (L <= 2M) en M is 40, dus 80 is de harde
   grens. Verder (t/m 100, HOTEL.md 3) vraagt een derde etappe of M = 50;
   beide staan niet in de opdracht, dus dit blijft zo.
   r = L - p is wat er nog te zwemmen is; de juiste keuze is r als r <= M
   en anders M ("zo ver als kan"). Afleiders: juist ± 1..3, juist + 10, L
   zelf, M zelf en de hele rest - nooit negatief, nooit dubbel, precies één
   juiste, en de juiste knop staat niet elke beurt op dezelfde plek.

   NOOIT STRAFFEND (HOTEL.md 9)
     te kort   het dier zwemt zo ver en stopt; nieuwe kaart met de rest;
     te veel   het mag maar M per keer: het zwemt M en de rest volgt;
     te ver    het bótst zacht tegen de wand: Snd.au, een wolkje "Au!",
               even over zijn kop wrijven (<= 1,5 s) en dan blij aan de
               overkant. Geen rood, geen ster minder, geen herhaling.
   Hoe de beurt ook eindigt: het dier klimt eerst het water uit op het dek
   (dek.over of dek.start) en pas daarna is het hotel weer aan de beurt -
   dus begint er nooit een dwaaltocht vanuit het bad (api-p1a).

   WAT DIT SPEL VAN DE API GEBRUIKT
     Games.register({wens:'zwemmen', taak}) (P1d), Rooms.registerModel +
     ctx.wereld.decor/decorWeg/decorWisAlles (P1b), ctx.wereld.loopNaar/
     stappen/pose (P1c), ctx.wereld.getalTag/behoefteKlaar, ctx.ui.somkaart
     met keuzes, ctx.ui.wolk, ctx.ui.opKader (M1a), Snd.plons/au (P1f).
---------------------------------------------------------------- */
(function () {
'use strict';

var C = null;            /* de ctx */
var S = null;            /* de beurt; leeft in C.data().beurt en wordt bewaard */
var kaart = null;        /* de sommenkaart met de keuzestrook */
var klok = [];           /* lopende tikjes; stop() ruimt ze op */
var bezig = false;       /* er loopt een beweging: even geen tik erbij */
var anker = null;        /* waar de kaart hangt (hangt van het kader af) */
var kaderAf = null;      /* opzegger van ctx.ui.opKader */
var open = false;        /* staat dit spel nu open? */
var t0 = 0;              /* begin van de beurt, voor state.tel */

var KAART_ID = 'zb_som', WOLK_ID = 'zb_zeg', VLAG_ID = 'zb_vlag';

/* =====================================================================
   0. KLEINE HULPJES
===================================================================== */
function straks(ms, fn) { var t = setTimeout(fn, ms); klok.push(t); return t; }
function stopKlok() { klok.forEach(function (t) { clearTimeout(t); }); klok = []; }
/* dezelfde lineaire congruentie als rooms.js: zelfde zaad, zelfde rij */
function prng(z) {
  var s = (z | 0) || 1;
  return function () { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
}
function klem(v, lo, hi) { return v < lo ? lo : v > hi ? hi : v; }
function heel(v) { return Math.round(v); }

/* =====================================================================
   1. EIGEN DECORSTUKKEN (Rooms.registerModel, P1b)
   Twee kleine voxelmodellen: een meterstreep op de badrand en de vlag bij
   de overkant. Ze staan op de bijna witte steenrand (rooms.js BADRAND),
   dus ze zijn blauw/roze - nooit dezelfde kleur als de rand zelf.
===================================================================== */
var STREEP = '#4C7FA6', STREEP_L = '#8FB4CC', KNOP = '#FFFDF3';
var MAST = '#B98F62', VLAG = '#F5A8BE', VOET = '#EDEFF6';

function meldModellen() {
  if (!window.Rooms || !Rooms.registerModel) return false;
  /* een meterstreep: een geverfde streep over de rand plus een stokje.
     p.groot = een hele tien (of vijf bij een korte baan): dan hoger en
     donkerder, zodat de rand als een echt meetlint leest. */
  Rooms.registerModel('zb_streep', function (p) {
    var K = Art.kit, v = [], groot = !!(p && p.groot), h = groot ? 7 : 4;
    var kl = groot ? STREEP : STREEP_L;
    K.bx(v, -1, 0, -2, 2, 1, 4, kl);        /* streep over de steenrand (z0-2 .. z0+1) */
    K.bx(v, -1, 1, -1, 2, h, 2, kl);        /* stokje */
    K.bx(v, -2, h + 1, -2, 4, 1, 4, KNOP);  /* wit knopje bovenop */
    return v;
  });
  /* de vlag op L meter: mast met een driehoekig vaantje */
  Rooms.registerModel('zb_vlag', function () {
    var K = Art.kit, v = [], i;
    K.bx(v, -3, 0, -3, 7, 1, 7, VOET);
    K.bx(v, -1, 1, -1, 2, 21, 2, MAST);
    for (i = 0; i < 7; i++) K.bx(v, 1, 21 - i, -1, 7 - i, 1, 2, VLAG);
    return v;
  });
  return true;
}
meldModellen();

/* =====================================================================
   2. DE BAAN: L en M uit N, band en dag (HOTEL.md 3)
   T = k * N + r met 0 <= r < k; k, het plafond en het maximum per slag
   komen uit de band. Daarna klemmen we L in het venster van de band, zodat
   een afgedwongen band met heel weinig gasten ook een echte baan geeft.
===================================================================== */
var BANDEN = {
  3: { k: 5, lo: 8,  hi: 20, M: 10, plafond: 20 },
  4: { k: 8, lo: 21, hi: 50, M: 30, plafond: 100 },
  5: { k: 7, lo: 31, hi: 80, M: 0,  plafond: 100 }   /* M: 30 of 40, zie baan() */
};
function bandVan(b) { b = b | 0; return b <= 3 ? 3 : b >= 5 ? 5 : 4; }
function plafondVan(band) { return BANDEN[bandVan(band)].plafond; }

/* het maximum per slag: vast per band, in groep 5 40 m voor de lange banen */
function maxVan(L, band) {
  band = bandVan(band);
  if (band < 5) return BANDEN[band].M;
  return L >= 55 ? 40 : 30;
}

function baan(N, band, dag) {
  band = bandVan(band);
  var B = BANDEN[band];
  N = Math.max(1, N | 0);
  dag = Math.max(1, dag | 0);
  var r = (N + dag) % B.k;                     /* 0 <= r < k */
  var L = klem(B.k * N + r, B.lo, B.hi);
  var M = maxVan(L, band);
  /* groep 5 wil restanten die over een tiental heen gaan (76 - 40 = 36):
     een ronde rest (40, 30, 20) is te makkelijk, dus schuif de vlag drie
     meter op zolang dat binnen het venster blijft. */
  if (band >= 5 && L > M && (L - M) % 10 === 0) {
    L = klem(L + 3, B.lo, B.hi);
    M = maxVan(L, band);
  }
  /* nooit meer dan twee etappes nodig: dan blijft de tweede kaart de
     schoolsom "L - M = rest" (en rest <= M) */
  if (L > 2 * M) L = 2 * M;
  return { L: L, M: M, band: band, N: N, dag: dag, k: B.k, r: r,
           stap: L <= 20 ? 5 : 10, plafond: B.plafond };
}

/* =====================================================================
   3. DE KEUZES
   juist = r als r <= M, anders M. Vier knoppen, precies één juiste, geen
   dubbele getallen, alles >= 1 en <= het plafond van de band.
===================================================================== */
function juistVan(L, M, p) {
  var r = Math.max(0, L - p);
  return r <= M ? r : M;
}
function keuzeGetallen(L, M, p, band, leg) {
  var r = Math.max(0, L - p), juist = juistVan(L, M, p), plafond = plafondVan(band);
  /* Eerst de getallen die het kind in de WERELD ziet: de hele rest, de
     badlengte (de vlag), het maximum per keer, en wat er ná deze slag nog
     ligt. Dan een rond tiental eraf of erbij, en pas als opvulling de buren
     juist ± 1..3. Anders staan alle vier de knoppen binnen drie meter van
     elkaar (8/9/10/11) en is de kaart een gokje in plaats van een keuze;
     zo komt de kaart van de eigenaar er precies uit: 30 / 43 / 13 / 20. */
  var wens = [r, L, M, r - M, juist - 10, juist + 10,
              juist - 1, juist + 1, juist + 2, juist - 2, juist + 3, juist - 3];
  var goed = [], i, v;
  for (i = 0; i < wens.length; i++) {
    v = wens[i];
    if (!(v >= 1) || v > plafond || v === juist || goed.indexOf(v) >= 0) continue;
    goed.push(v);
  }
  for (v = 1; goed.length < 3 && v <= plafond; v++)          /* vangnet */
    if (v !== juist && goed.indexOf(v) < 0) goed.push(v);
  var uit = goed.slice(0, 3);
  var rnd = prng(L * 977 + M * 131 + p * 17 + (leg || 0) * 7 + 1);
  var plek = Math.min(3, Math.floor(rnd() * 4));             /* niet altijd links */
  uit.splice(plek, 0, juist);
  return { lijst: uit, juist: juist, plek: plek, rest: r };
}

/* =====================================================================
   4. DE WERELD: bad, dek, meters -> x
===================================================================== */
function kamer() { return (C ? C.wereld.kamer('zwembad') : (window.Rooms ? Rooms.get('zwembad') : null)) || null; }
function bad() {
  var r = kamer();
  return (r && r.bad) || { x0: 18, x1: 134, z0: 12, z1: 44 };
}
function dek() {
  var r = kamer(), b = bad();
  if (r && r.dek && r.dek.start) return r.dek;
  return { start: { x: b.x0 - 6, z: b.z1 + 12 }, over: { x: b.x1 - 2, z: b.z1 + 12 } };
}
function baanZ() { var b = bad(); return (b.z0 + b.z1) / 2; }
/* x(p) = x0 + (x1 - x0) * p / L  (api-p1a) */
function xVan(m) {
  var b = bad(), L = (S && S.L) || 1;
  return b.x0 + (b.x1 - b.x0) * klem(m, 0, L) / L;
}
function inBad(d) {
  if (!d || d.kamer !== 'zwembad') return false;
  var b = bad();
  return d.x >= b.x0 - 1 && d.x <= b.x1 + 1 && d.z >= b.z0 - 1 && d.z <= b.z1 + 1;
}

/* ---------- meterstrepen en de vlag ----------
   De grote strepen dragen hun getal als cijfer op de rand (0, 10, 20, ...),
   zodat het kind "Boef is bij 30 meter" van het dek kan aflezen. Staan die
   cijfers op dit scherm te dicht op elkaar, dan labelen we ruimer. */
var markTags = [];
function labelStapVan(k) {
  var b = bad(), stap = 2 * S.stap, breed = (b.x1 - b.x0) / S.L * 2 * (k || 1);
  while (stap < S.L && breed * stap < 34) stap += 2 * S.stap;
  return stap;
}
function bouwDecor() {
  if (!C || !S) return 0;
  var b = bad(), n = 0, m, groot, i;
  for (i = 0; i < markTags.length; i++) C.wereld.getalTag(null, null, { id: markTags[i] });
  markTags = [];
  C.wereld.decorWisAlles();
  var k = (C.wereld.schaal ? C.wereld.schaal().k : 1) || 1;
  var labelStap = labelStapVan(k);
  for (m = 0; m <= S.L; m += S.stap) {
    if (m === S.L) break;                       /* daar staat de vlag al */
    groot = (m % (2 * S.stap) === 0);
    if (!C.wereld.decor('zwembad', { id: 'zb_m' + m, model: 'zb_streep',
          x: heel(xVan(m)), z: b.z0 - 2, params: { groot: groot ? 1 : 0 } })) continue;
    n++;
    if (groot && m % labelStap === 0) {
      C.wereld.getalTag('zb_m' + m, m, { id: 'zb_mt' + m, y: 11, prio: 6 });
      markTags.push('zb_mt' + m);
    }
  }
  if (C.wereld.decor('zwembad', { id: VLAG_ID, model: 'zb_vlag',
        x: heel(xVan(S.L)), z: b.z0 - 6 })) n++;
  /* het getal op de vlag: zó ziet het kind waar de overkant ligt. Hij hangt
     hoog aan de mast, zodat hij niet op het cijfer van de zwemmer valt als
     die de overkant haalt. */
  C.wereld.getalTag(VLAG_ID, S.L + ' m', { id: 'zb_vlagtag', y: 34, prio: 8 });
  return n;
}
/* het cijfer op het dier: "30 m" (loopt met de zwemmer mee) */
function tag(m) {
  if (!C || !S || !S.gast) return;
  C.wereld.getalTag(S.gast, heel(m) + ' m', { id: 'zb_stand', y: 18, prio: 10 });
}
function tagWeg() { if (C) C.wereld.getalTag(null, null, { id: 'zb_stand' }); }

/* =====================================================================
   5. DE KAART: waar hangt hij, en wat staat erop

   Het bad ligt diagonaal over het hele kader, dus één vaste plek voor de
   kaart dekt vroeg of laat de zwemmer af. Daarom zoekt de kaart zijn plek
   in KADERPIXELS, rond het vak waar het dier op DIT moment staat: eerst
   eronder, dan erboven, dan links of rechts ernaast. Tijdens een slag
   staat er geen kaart (de strook gaat er bij de tik meteen af), dus de
   kaart hoeft alleen om een STILSTAAND dier heen.

   Rekenen zoals games/voerkar.js dat doet, met World.vloer() als ijkpunt:
     kader-x = vloer.x + (2(x - z) + 2d) * k
     kader-y = vloer.y + ((x + z) - 2y) * k
   en terug, op een gekozen diepte (x + z). Zo hoeft dit spel niets van de
   camera te weten en klopt het in élke kadermaat.
===================================================================== */
function kaderInfo() {
  var el = (typeof document !== 'undefined') &&
           (document.getElementById('worldHits') || document.getElementById('world'));
  var s = C && C.wereld.schaal ? C.wereld.schaal() : null;
  var vl = (window.World && World.vloer) ? World.vloer() : null;
  var r = kamer();
  if (!el || !s || !vl || !r || !el.clientWidth || !el.clientHeight) return null;
  return { w: el.clientWidth, h: el.clientHeight, k: s.k || 1,
           fx: vl.x, fy: vl.y, d: r.d || 88 };
}
function csX(F, x, z) { return F.fx + (2 * (x - z) + 2 * F.d) * F.k; }
function csY(F, x, z, y) { return F.fy + ((x + z) - 2 * (y || 0)) * F.k; }
/* kaderpixels terug naar voxels, op een gekozen diepte (diep = x + z) */
function voxVan(F, X, Y, diep) {
  var u = (X - F.fx) / F.k - 2 * F.d;          /* u = 2(x - z) */
  var v = (Y - F.fy) / F.k;                    /* v = (x + z) - 2y */
  return { x: (diep + u / 2) / 2, z: (diep - u / 2) / 2, y: (diep - v) / 2 };
}
/* de maat van een van onze eigen knoppen (offsetHeight klopt meteen) */
function elMaat(id, bw, bh) {
  var e = (typeof document !== 'undefined') && document.querySelector('[data-hot="' + id + '"]');
  if (!e || !e.offsetHeight) return { w: bw, h: bh, er: false };
  return { w: e.offsetWidth || bw, h: e.offsetHeight || bh, er: true };
}
/* het vak dat vrij moet blijven: het dier waar de kaart bij hoort */
function vrijVak(F) {
  var d = C && S ? C.wereld.dier(S.gast) : null, b = bad();
  /* onderweg naar het bad (nog in een andere kamer)? reken dan met de plek
     waar hij straks staat: de instapkant van de baan */
  if (d && d.kamer !== 'zwembad') d = null;
  var x = d ? d.x : b.x0, z = d ? d.z : baanZ();
  var voet = csY(F, x, z, 0), mid = csX(F, x, z);
  var hg = 36 * 2 * F.k, br = 30 * F.k + 10;   /* een gast is ~34 voxels hoog */
  return { top: voet - hg, bot: voet + 6, x0: mid - br, x1: mid + br };
}
/* Een knop alleen verzetten als hij écht ergens anders hoort. Zonder deze rem
   verschuift de kaart bij elke nameting een haarbreedte, en een tik die net
   op dat moment landt valt dan naast de knop. */
var plekNu = Object.create(null);
function zetPlek(id, v) {
  var was = plekNu[id];
  if (was && Math.abs(was.x - v.x) < 0.02 && Math.abs(was.z - v.z) < 0.02 &&
      Math.abs(was.y - v.y) < 0.02) return false;
  plekNu[id] = { x: v.x, z: v.z, y: v.y };
  C.hotspots.maak({ id: id, x: v.x, z: v.z, y: v.y });
  return true;
}
function plekVergeet() { plekNu = Object.create(null); }

/* de kaart (en zijn keuzestrook) exact neerleggen */
function kaartLeg() {
  if (!C || !kaart) return null;
  var F = kaderInfo();
  if (!F) return null;
  var K = elMaat(KAART_ID, 200, 78), R = elMaat(KAART_ID + '_keuzes', 230, 62);
  var gat = 5, nodig = K.h + (R.er ? gat + R.h : 0);
  var halfW = Math.max(K.w, R.er ? R.w : 0) / 2 + 2;
  var v = vrijVak(F), kant, X, Yt;
  var midX = klem(F.w / 2, halfW, Math.max(halfW, F.w - halfW));
  /* eronder: zo LAAG als het kader toelaat - staand houdt world.js daar een
     strook vrij (KADER_ONDER), dus dan ligt de kaart onder de kamer en niet
     over het bad */
  if (v.bot + 6 + nodig <= F.h - 2) { kant = 'onder'; X = midX; Yt = Math.max(v.bot + 6, F.h - 2 - nodig); }
  else if (v.top - 6 - nodig >= 2) { kant = 'boven'; X = midX; Yt = 2; }
  else if (v.x0 - 6 >= 2 * halfW) { kant = 'links'; X = v.x0 - 6 - halfW; Yt = klem((F.h - nodig) / 2, 2, Math.max(2, F.h - nodig - 2)); }
  else if (F.w - v.x1 - 6 >= 2 * halfW) { kant = 'rechts'; X = v.x1 + 6 + halfW; Yt = klem((F.h - nodig) / 2, 2, Math.max(2, F.h - nodig - 2)); }
  else { kant = 'krap'; X = midX; Yt = Math.max(2, F.h - nodig - 2); }
  var diep = 300;                              /* de kaart staat vooraan */
  zetPlek(KAART_ID, voxVan(F, X, Yt + K.h / 2, diep));
  if (R.er) zetPlek(KAART_ID + '_keuzes', voxVan(F, X, Yt + K.h + gat + R.h / 2, diep));
  anker = { kant: kant, X: heel(X), Y: heel(Yt), nodig: heel(nodig),
            kaartH: K.h, strookH: R.er ? R.h : 0, vrij: v, kader: [F.w, F.h] };
  return anker;
}
/* Na een kamerwissel of een herlaad zakt het kader nog: de kamerbalk breekt
   af, de liggende schil klapt in. Meten we dan één keer, dan kan de kaart
   onder de onderrand blijven hangen (gemeten na een herlaad in liggend
   kader: strook op py 350 in een kader van 294). Daarom kijken we het nog
   een paar keer na - zetPlek verzet alleen als het écht anders is. */
function kaartLegStraks() {
  kaartLeg();
  straks(140, kaartLeg);
  straks(420, kaartLeg);
  straks(900, kaartLeg);
  straks(1800, kaartLeg);
}

/* de kaart (opnieuw) neerzetten; het icoon wisselt mee, dus altijd een verse
   kaart (Ui.somkaart legt zijn icoon vast bij het maken) */
function kaartOp(icoon, zinnen, som, keuzes) {
  if (!C) return null;
  if (kaart) { kaart.weg(); kaart = null; }
  plekVergeet();                    /* verse kaart: de oude plek geldt niet meer */
  kaart = C.ui.somkaart({ x: 4, z: 4, kamer: 'zwembad' }, som || '', {
    id: KAART_ID, icoon: icoon, regel: zinnen, hoog: 0,
    pad: false, keuzes: keuzes || null,
    keuzeTitel: 'hoeveel meter zwemt hij?'
  });
  kaartLegStraks();
  return kaart;
}
/* de vraagkaart van deze etappe */
function kaartVraag() {
  if (!C || !S) return null;
  var g = C.state.gast(S.gast), naam = (g && g.naam) || 'De gast';
  var q = keuzeGetallen(S.L, S.M, S.p, S.band, S.leg || 0);
  S.juist = q.juist; S.plek = q.plek; S.keuzes = q.lijst.slice();
  var zinnen, som;
  if (!S.p) {
    zinnen = ['Het bad is ' + S.L + ' meter lang', 'Max ' + S.M + ' meter per keer'];
    som = 'nog ' + S.L + ' m';
  } else {
    zinnen = [naam + ' is bij ' + S.p + ' meter', 'Nog hoeveel meter?'];
    som = S.L + ' − ' + S.p + ' =';
  }
  var keuzes = q.lijst.map(function (v) {
    return { id: 'm' + v, icoon: '🏊', tekst: v + ' m',
             kies: function () { kies(v); } };
  });
  bewaar();
  return kaartOp('🏊', zinnen, som, keuzes);
}

/* =====================================================================
   6. DE BEURT
===================================================================== */
/* C is er alleen als het spel open staat; de testhaakjes mogen ook zonder */
function statePot() { return C ? C.state : (window.State || null); }
function dierVan(id) {
  if (C) return C.wereld.dier(id);
  return window.World ? World.dier(id) : null;
}
function gasten() {
  var st = statePot();
  if (!st) return [];
  return st.gasten().filter(function (g) { return !!g.bed; });
}
function wensGasten() {
  return gasten().filter(function (g) { return g.behoefte === 'zwemmen' && !g.blij; });
}
/* wie gaat zwemmen? eerst een gast met de wens 🏊 (die staat al op het dek),
   anders de gast die het dichtst bij het bad is, anders gewoon de eerste:
   een tik op het bad hoort nooit dood te zijn. */
function gastKies() {
  var wil = wensGasten(), i, d, best = null, bestD = 1e9, hier;
  if (wil.length) {
    for (i = 0; i < wil.length; i++) if (wil[i].waar === 'zwembad') return { gast: wil[i], wens: true };
    return { gast: wil[0], wens: true };
  }
  hier = gasten().filter(function (g) { return g.waar === 'zwembad'; });
  for (i = 0; i < hier.length; i++) {
    d = dierVan(hier[i].id);
    var afst = d ? Math.abs(d.x - bad().x0) + Math.abs(d.z - baanZ()) : 1e8;
    if (afst < bestD) { bestD = afst; best = hier[i]; }
  }
  if (best) return { gast: best, wens: false };
  var alle = gasten(), st = statePot();
  if (!alle.length && st) alle = st.gasten();
  return alle.length ? { gast: alle[0], wens: false } : null;
}

function bewaar() {
  if (!C || !S) return;
  var d = C.data();
  d.beurt = S;
  C.state.bewaar();
}
function nieuweBeurt() {
  var kies0 = gastKies();
  if (!kies0) return null;
  var b = baan(C.state.N(), C.state.band(), C.state.dag());
  return { gast: kies0.gast.id, wens: !!kies0.wens, L: b.L, M: b.M, stap: b.stap,
           band: b.band, N: b.N, dag: b.dag, p: 0, leg: 0, klaar: null,
           juist: null, plek: null, keuzes: null, misser: 0 };
}
function geldig(b) {
  if (!b || !C) return false;
  if (typeof b.L !== 'number' || typeof b.p !== 'number' || typeof b.M !== 'number') return false;
  if (!(b.L > 0) || b.p < 0 || b.p > b.L) return false;
  if (b.klaar) return false;                          /* die beurt is voorbij */
  return !!C.state.gast(b.gast);
}

/* ---------- het water in ----------
   Alleen dít spel zet een dier in het bad (api-p1a). De weg erheen loopt
   langs het water: eerst de instapvlonder op de startrand, dan de zwembaan
   in - zo wandelt er nooit een gast dwars door het bad. */
function zorgInWater(na) {
  if (!C || !S) return;
  var d = C.wereld.dier(S.gast);
  if (d && inBad(d) && Math.abs(d.x - xVan(S.p)) < 3) { if (na) na(); return; }
  naarWater(na);
}
function naarWater(na) {
  if (!C || !S) return;
  var d = C.wereld.dier(S.gast), z = baanZ();
  if (!d) { if (na) na(); return; }
  bezig = true;
  function instap() {
    if (!inZwembad()) { bezig = false; return; }
    tag(S.p);
    C.snd.plons();
    C.wereld.loopNaar(S.gast, xVan(S.p), z, { pose: 'zwem', tempo: 1.1 })
      .then(function (ok) {
        bezig = false;
        if (!ok) return;
        kaartLegStraks();               /* het dier staat nu ergens anders */
        if (na) na();
      });
  }
  /* niet in het zwembad? dan loopt hij er eerst zelf naartoe (door de deuren).
     Komt hij niet aan, dan gebeurt er NIETS: een zwempose buiten het bad zou
     een dier midden in de tuin laten zwemmen. */
  if (d.kamer !== 'zwembad') {
    C.wereld.reis(S.gast, 'zwembad', { x: dek().start.x, z: dek().start.z, na: 'wacht' });
    wachtTot(inZwembad, 25000, function (ok) {
      if (!ok) { bezig = false; return; }
      naarVlonder(instap);
    });
    return;
  }
  naarVlonder(instap);
}
function inZwembad() {
  var d = C && S ? C.wereld.dier(S.gast) : null;
  return !!d && d.kamer === 'zwembad';
}
/* eerst naar de instapvlonder op de startrand (x < x0, in de zwembaan): zo
   loopt hij langs het water en niet dwars door het bad (api-p1a) */
function naarVlonder(na) {
  var d = C.wereld.dier(S.gast), b = bad(), z = baanZ();
  if (!d || d.kamer !== 'zwembad') { bezig = false; return; }
  if (inBad(d)) { if (na) na(); return; }
  C.wereld.loopNaar(S.gast, Math.max(4, b.x0 - 9), z, { tempo: 1.2 })
    .then(function (ok) { if (ok && na) na(); else bezig = false; });
}
function wachtTot(test, ms, na) {
  var eind = C.ui.nu() + (ms || 6000);
  (function kijk() {
    if (!C || !S) return;
    if (test()) { na(true); return; }
    if (C.ui.nu() > eind) { na(false); return; }
    straks(220, kijk);
  })();
}

/* ---------- het tempo van de slagen ----------
   Eén hele baan kost bij tempo 1 ongeveer 4,3 s (api-p1c), dus de zwemmer
   doet L / 4,3 meter per seconde. In een baan van 76 m vliegt het cijfer op
   het dier dan voorbij (18 m/s). We houden hem onder ~5 m/s zolang de hele
   baan onder ~15 s blijft; korte banen (L <= 21) blijven op tempo 1. */
var BAAN_S = 4.3, LEES_MS = 5, BAAN_MAX = 15;
function tempoVan(L) {
  return klem(BAAN_S * LEES_MS / Math.max(1, L), BAAN_S / BAAN_MAX, 1);
}

/* ---------- zwemmen: één punt per meter, één plons per paar slagen ---------- */
function zwem(n, na) {
  if (!C || !S) return;
  if (!inZwembad()) { bezig = false; return; }   /* nooit zwemmen buiten het bad */
  n = Math.max(0, Math.min(heel(n), S.L - S.p));
  if (!n) { if (na) na(); return; }
  var p0 = S.p, z = baanZ(), punten = [], m;
  for (m = p0 + 1; m <= p0 + n; m++) punten.push([xVan(m), z]);
  /* niet plonzen bij elke slag: bij lange stukken hooguit vier keer */
  var elke = n > 10 ? Math.ceil(n / 4) : 5;
  bezig = true;
  C.wereld.stappen(S.gast, punten, {
    pose: 'zwem', tempo: tempoVan(S.L),
    perStap: function (i) {
      S.p = p0 + i + 1;
      tag(S.p);
      if (i % elke === 0) C.snd.plons();
    }
  }).then(function (ok) {
    bezig = false;
    if (!ok || !C || !S) return;                    /* ingehaald: niets doen */
    bewaar();
    if (na) na();
  });
}

/* ---------- een tik op een keuzeknop ----------
   De keuzestrook gaat er meteen af: dat is tegelijk de rem tegen twee
   tikken op één vraag (geen kaart = geen keuze open). */
function kies(n) {
  if (!C || !S || S.klaar || !kaart) return false;
  var r = Math.max(0, S.L - S.p), juist = juistVan(S.L, S.M, S.p);
  var soort = n === juist ? 'goed' : n < juist ? 'kort' : n <= r ? 'veel' : 'ver';
  var meters = soort === 'ver' ? r : soort === 'veel' ? juist : n;
  if (soort !== 'goed') S.misser = (S.misser || 0) + 1;
  S.leg = (S.leg || 0) + 1;
  S.laatsteP = S.p;                 /* voor de eindsom "43 − 30 = 13" */
  S.laatsteRest = r;
  S.laatsteKeuze = n;
  S.laatsteSoort = soort;
  C.ui.wolkWeg(WOLK_ID);
  kaart.weg(); kaart = null;
  bewaar();
  zorgInWater(function () {
    zwem(meters, function () {
      if (soort === 'ver') { bots(); return; }
      if (S.p >= S.L) { precies(); return; }
      /* pictogram + getal in hetzelfde wolkje, in gewoon Nederlands: het
         woordje hoort VÓÓR de meters ("nog 13 m"), niet erachter */
      if (soort === 'goed') { C.snd.ja(); zeg('✅', meters + ' m', 'gezwommen'); }
      else if (soort === 'veel') { C.snd.zacht(); zeg('🏊', 'hooguit ' + S.M + ' m'); }
      else { C.snd.zacht(); zeg('🏊', 'nog ' + (S.L - S.p) + ' m'); }
      kaartVraag();
    });
  });
  return soort;
}
/* Eén wolkje tegelijk boven de gast, en het opruimtikje van een OUD wolkje
   mag een nieuw wolkje niet weghalen: anders veegde de teller van "✅ 10 m
   gezwommen" na 1,9 s de "Au!" van 0,1 s oud weer weg. Vandaar het nummer. */
var zegNr = 0;
function zeg(icoon, getal, tekst, ms) {
  if (!C || !S) return null;
  var mijn = ++zegNr;
  C.ui.wolk(S.gast, { id: WOLK_ID, icoon: icoon, getal: getal, tekst: tekst, hoog: 56 });
  straks(ms || 1900, function () { if (C && zegNr === mijn) C.ui.wolkWeg(WOLK_ID); });
  return mijn;
}

/* ---------- de twee einden ---------- */
function precies() {
  if (!C || !S) return;
  C.snd.ja();
  afronden('precies', ['Precies aan de overkant!',
                       (naamVan() + ' zwom ' + S.L + ' meter')], somAf(), '✅');
}
function bots() {
  if (!C || !S) return;
  C.snd.au();
  /* Alleen het WOLKJE gaat op de klok weg (1,2 s); het wrijven over zijn kop
     komt ná de klim uit het water (zie afronden). Een pose haalt een lopende
     opdracht in (api-p1c), dus een houding op een tikje zou de klim kunnen
     afbreken en het dier in het water laten liggen. */
  zeg('💛', null, 'Au!', 1200);
  afronden('bots', [naamVan() + ' is aan de overkant',
                    'Het was nog ' + S.laatsteRest + ' meter'], somAf(), '💛');
}
function naamVan() {
  var g = C && S ? C.state.gast(S.gast) : null;
  return (g && g.naam) || 'De gast';
}
/* de som van de laatste etappe, mét antwoord: "43 − 30 = 13" */
function somAf() {
  if (!S) return '';
  if (!S.laatsteP) return S.L + ' m ✓';
  return S.L + ' − ' + S.laatsteP + ' = ' + S.laatsteRest;
}
function afronden(soort, zinnen, som, icoon) {
  S.klaar = soort;
  bewaar();
  /* de ster en de wens horen bij het HALEN van de overkant, niet bij goed
     gokken: ook na een bots gaat het taakje af en blijft de ster staan. */
  if (S.wens) C.wereld.behoefteKlaar(S.gast, 'zwemmen');
  C.state.tel(!S.misser, Math.max(0, C.ui.nu() - (t0 || C.ui.nu())));
  C.taakKlaar('zwemles');
  kaartOp(icoon, zinnen, som, null);
  /* klaar() tekent de kaart opnieuw op zijn MAAK-voxel (4, 4) - dat is midden
     boven het water. De plek-rem denkt dan dat hij al goed staat, dus eerst
     vergeten en dan opnieuw neerleggen, anders hangt de eindkaart 3,4 s over
     het bad en over de meterstrepen. */
  if (kaart) kaart.klaar();
  plekVergeet();
  kaartLegStraks();                 /* zonder keuzestrook past hij anders */
  C.ui.toast(soort === 'precies' ? '🏊 Precies aan de overkant! ⭐'
                                 : '🏊 Aan de overkant! ⭐', 'happy');
  uitHetWater(function () {
    if (!C || !S) return;
    if (soort === 'bots') {
      /* op het droge even over zijn kop wrijven (<= 1,5 s), daarna blij */
      C.wereld.pose(S.gast, 'snuif', 18);
      straks(1300, function () { if (C && S) C.wereld.pose(S.gast, 'blij', 45); });
    } else {
      C.wereld.pose(S.gast, 'blij', 45);
    }
    tagWeg();
    kaartLegStraks();               /* het dier staat nu op het dek */
    straks(3400, sluitAls);         /* zoals de tobbe: het spel gaat zelf dicht */
  });
  straks(11000, sluitAls);          /* vangnet als de klim onderbroken werd */
}
/* dicht, maar alleen als de beurt echt af is en niemand meer in het bad ligt */
function sluitAls() {
  if (!C || !S || !S.klaar) return;
  if (inBad(C.wereld.dier(S.gast))) { noodUit(); }
  C.sluit();
}

/* ---------- het water uit, op het dek (altijd vóór het hotel weer aan is) ---------- */
function uitHetWater(na) {
  if (!C || !S) { if (na) na(); return; }
  var d = C.wereld.dier(S.gast), b = bad(), dk = dek();
  if (!d) { if (na) na(); return; }
  var doel = (S.p >= S.L / 2) ? dk.over : dk.start;
  if (!inBad(d)) {
    C.wereld.loopNaar(S.gast, doel.x, doel.z, { tempo: 1.2, na: 'wacht' })
      .then(function (ok) { if (ok && na) na(); });
    return;
  }
  bezig = true;
  /* eerst naar de voorrand van het bad (nog zwemmend), dan het dek op */
  C.wereld.stappen(S.gast, [[klem(d.x, b.x0, b.x1), b.z1 - 1]], { pose: 'zwem', tempo: 1.2 })
    .then(function (ok) {
      if (!ok || !C || !S) { bezig = false; return; }
      return C.wereld.loopNaar(S.gast, doel.x, doel.z, { tempo: 1.2, na: 'wacht' });
    })
    .then(function (ok) {
      bezig = false;
      if (ok && na) na();
    });
}
/* noodgeval: het spel gaat dicht terwijl er iemand in het bad ligt. Dan
   zetten we hem meteen op het dek - een dier dat in het water blijft zou
   uit zichzelf dwars door het bad naar een dwaalplek lopen (api-p1a). */
function noodUit() {
  if (!C || !S || !S.gast) return false;
  var d = C.wereld.dier(S.gast), dk = dek();
  if (!inBad(d)) return false;
  var doel = (S.p >= S.L / 2) ? dk.over : dk.start;
  if (window.World && World.zet) { World.zet(S.gast, 'zwembad', doel.x, doel.z); return true; }
  C.wereld.ga(S.gast, doel.x, doel.z, 'wacht');
  return true;
}

/* =====================================================================
   7. START EN STOP
===================================================================== */
function beurtStarten(herstel) {
  t0 = C.ui.nu();
  bouwDecor();
  if (!herstel) {
    S.p = 0; S.leg = 0;
    naarWater(function () { tag(S.p); });
    kaartVraag();
    return;
  }
  /* na een herlaad: het dier staat weer op een dwaalplek (los decor en de
     wereld zijn nieuw), dus zetten we het terug op zijn meter in het bad */
  var d = C.wereld.dier(S.gast);
  if (S.p > 0 && d) {
    if (window.World && World.zet) World.zet(S.gast, 'zwembad', xVan(S.p), baanZ());
    C.wereld.pose(S.gast, 'zwem', 0);
    tag(S.p);
    kaartVraag();
  } else {
    naarWater(function () { tag(S.p); });
    kaartVraag();
  }
}

/* een bewaarde beurt uit een oudere opslag mist misschien een veld: hier
   krijgt hij alles wat de rest van het spel verwacht */
function normaliseer(b) {
  b.band = bandVan(b.band || (C ? C.state.band() : 3));
  b.M = b.M > 0 ? b.M : maxVan(b.L, b.band);
  b.stap = b.stap > 0 ? b.stap : (b.L <= 20 ? 5 : 10);
  b.p = klem(b.p | 0, 0, b.L);
  b.leg = b.leg | 0;
  b.misser = b.misser | 0;
  b.laatsteP = b.laatsteP | 0;
  b.laatsteRest = b.laatsteRest === undefined ? b.L : b.laatsteRest;
  return b;
}

function start(ctx) {
  C = ctx;
  meldModellen();
  var d = C.data();
  if (open && S && !S.klaar && geldig(S)) {         /* al open: alleen opnieuw tekenen */
    bouwDecor();
    if (!bezig && !kaart) kaartVraag();
    return;
  }
  open = true;
  S = geldig(d.beurt) ? d.beurt : null;
  var herstel = !!S;
  if (!S) {
    S = nieuweBeurt();
    if (!S) { C.ui.toast('🏊 Er is nog geen gast', 'kind'); open = false; return; }
    d.beurt = S;
  }
  normaliseer(S);
  if (kaderAf) { kaderAf(); kaderAf = null; }
  if (C.ui.opKader) kaderAf = C.ui.opKader(function () { opKader(); });
  beurtStarten(herstel);
  bewaar();
}
/* kantelen of een andere kadermaat: de kaart hoort dan misschien aan een
   andere kant van de zwemmer (eronder, erboven, ernaast) */
function opKader() {
  if (!C || !S) return;
  kaartLegStraks();
}

function stop() {
  stopKlok();
  if (C) {
    if (kaart) { kaart.weg(); kaart = null; }
    C.ui.wolkWeg(WOLK_ID);
    noodUit();
    tagWeg();
    C.wereld.getalTag(null, null, { id: 'zb_vlagtag' });
    C.wereld.decorWisAlles();
    C.hotspots.wisAlles();
    C.state.bewaar();
  }
  kaart = null; anker = null; bezig = false; open = false;
  markTags = [];
  plekVergeet();
  if (kaderAf) { kaderAf(); kaderAf = null; }
  C = null; S = null;
}

/* =====================================================================
   8. AANMELDEN
===================================================================== */
function zwemGast(s, ookAls) {
  var st = s || (window.State && State.ruw ? State.ruw() : null);
  var l = ((st && st.gasten) || []).filter(function (g) {
    return g.behoefte === 'zwemmen' && (ookAls || !g.blij);
  });
  return l[0] || null;
}
Games.register({
  id: 'zwembad',
  naam: 'Zwembad',
  kamer: 'zwembad',
  /* de knop hangt op de instapvlonder aan de startrand van het bad */
  hotspot: { obj: 'mat', icoon: '🏊', label: 'Zwemles', hoog: 12 },
  unlock: function (N) { return N >= 1; },
  wens: 'zwemmen',
  stub: false,
  taak: { id: 'zwemles', prio: 1, icoon: '🏊',
          wanneer: function (s) { return !!zwemGast(s); },
          tekst: function (s) {
            var g = zwemGast(s, true);
            return g ? 'Zwemles voor ' + g.naam : 'Zwemles';
          } },
  start: start,
  stop: stop,
  /* ---- haakjes voor de speeltest (het hotel gebruikt ze niet) ---- */
  proef: function (N, band, dag) { return baan(N, band, dag); },
  keuzeProef: function (L, M, p, band, leg) { return keuzeGetallen(L, M, p, band, leg); },
  debug: function () {
    if (!S) return null;
    var uit = JSON.parse(JSON.stringify(S));
    uit.bezig = bezig;
    uit.anker = anker;
    uit.xVanP = S ? xVan(S.p) : null;
    uit.juistNu = S ? juistVan(S.L, S.M, S.p) : null;
    return uit;
  },
  doe: function (wat, a, b) {
    if (wat === 'kies') return kies(a);
    if (wat === 'kaart') return !!kaartVraag();
    if (wat === 'xvan') return xVan(a);
    if (wat === 'juist') return S ? juistVan(S.L, S.M, a === undefined ? S.p : a) : null;
    if (wat === 'anker') return kaartLeg() || anker;
    if (wat === 'kader') return kaderInfo();
    if (wat === 'vrij') { var F = kaderInfo(); return F ? vrijVak(F) : null; }
    if (wat === 'gast') { var q = gastKies(); return q ? { id: q.gast.id, wens: q.wens } : null; }
    if (wat === 'nieuw') { if (C) { C.data().beurt = null; S = null; open = false; start(C); } return !!S; }
    if (wat === 'decor') return C ? C.wereld.decorLijst('zwembad').length : 0;
    if (wat === 'baanz') return baanZ();
    if (wat === 'tempo') return tempoVan(a === undefined ? (S && S.L) : a);
    if (wat === 'labelstap') return S ? labelStapVan(a) : null;
    if (wat === 'marktags') return markTags.slice();
    if (wat === 'inbad') return inBad(C ? C.wereld.dier(a || (S && S.gast)) : null);
    if (wat === 'zet') { if (S) { S.p = a; tag(a); bewaar(); } return S ? S.p : null; }
    return null;
  }
});
})();
