/* ---------------------------------------------------------------
   games/wekker.js - DE WEKKERDIENST (HOTEL.md 9: rekenen ín de wereld)

   Alles gebeurt in de gang, er komt geen rekenblad naast de kamer:
     * aan de achterwand hangt de grote halklok: los decor van een eigen
       voxelmodel (Rooms.registerModel('klok', ...)) met een wijzerplaat,
       twaalf uurstreepjes en TWEE wijzers die echt met de parameters
       meedraaien - elke tik zet nieuwe params, dus de motor bakt precies
       één plaatje opnieuw (World.debug/decor, api-p1b);
     * op de klok staat zijn eigen tijd als cijfer (wereld.getalTag);
     * onder de klok hangt één sommenkaart: de wekkerwens van de gast
       ("⏰ Boef wil om 7 uur op" / "Zet de klok") met de stand van de klok
       als sombalk ("nu: 5 uur") en één knoppenstrook met woorden;
     * bij het slapende dier hangt zijn eigen wekkerkaartje (💤), zodat je
       in zijn kamer ziet wie er gewekt wordt;
     * goed gezet: de klok slaat zacht, het dier wordt wakker (houding blij
       + ☀-wolkje) en er valt een ster;
     * verkeerd gezet: het dier slaapt door, de kaart zegt wat de klok NU
       zegt en wat de gast WIL, en de wijzers blijven staan zodat je verder
       kunt draaien. Nooit terugzetten, nooit rood, geen timer.

   HET REKENEN (HOTEL.md 3, spec G2)
     groep 3  hele uren            doel 1-12, start 1-5 uur eerder
     groep 4  kwartieren en halve uren, uitgeschreven ("half 8")
     groep 5  op de 5 minuten + tijdsduur ("slaapt nog 2 uur" -> keuzes)
   De afstand die het kind moet draaien komt uit N en de band (T = k·N + r):
   band 3 hele uren (N + dag%2, hooguit 5), band 4 uren + kwartieren,
   band 5 uren + kwartieren + vijfjes. Het DOELUUR komt uit de bevroren
   generator state.sommen.klok(band) (alleen lezen); band 5 rondt de
   minuten van die generator af op vijf, want een wekker die op :57 staat
   is met stappen van 5 nooit te zetten.

   HULPLADDER (HOTEL.md 5 "spookwijzer na 2 pogingen", GAMES-API 6)
     1e misser: een hint op de kaart; vanaf de 2e misser komen er bleke
     SPOOKWIJZERS op de wijzerplaat te staan die de gewenste tijd wijzen.

   WAT DE API (NOG) NIET HEEFT - hier binnen opgelost:
   * registry.js zoekt het voorwerp van een hotspot met World.dingPlek,
     Rooms.slot en het VASTE decor van de kamer; los decor (§3 van api-p1b)
     kent het niet. Het icoontje van dit spel hangt daarom aan de kist in
     de gang met dx/dz/hoog erop, precies op de plek waar de klok komt.
     World.mik('klok') vindt het losse stuk wél, dus de kaart, het cijfer
     en de wolkjes hangen gewoon aan de klok zelf.
   * state.sommen.klok(5) geeft minuten die geen veelvoud van 5 zijn
     (dag 1: 10:57). Afronden gebeurt hier, de generator blijft ongemoeid.
---------------------------------------------------------------- */
(function () {
'use strict';

var C = null;          /* de ctx */
var S = null;          /* de beurt (leeft in C.data().stand, gaat mee in de opslag) */
var kaart = null;      /* de sommenkaart onder de klok */
var klokjes = [];      /* lopende tikjes; stop() ruimt ze op */
var bakken = 0;        /* hoe vaak het klokmodel gebakken is (voor de suite) */
var slagT = 0;         /* rem op de gong: niet twee slagen binnen 120 ms */
var kortWas = false;   /* staan er korte woorden op de knoppen? (kadermaat) */
var kortDwang = false; /* de strook paste niet in het kader: korte woorden */
var kaderAf = null;    /* opzegger van Ui.opKader */

function straks(ms, fn) { var t = setTimeout(fn, ms); klokjes.push(t); return t; }
function stopKlokjes() { klokjes.forEach(function (t) { clearTimeout(t); }); klokjes = []; }

/* =====================================================================
   1. HET MODEL: de halklok met twee draaiende wijzers
   -------------------------------------------------------------------
   Voxels tellen in het stelsel van art.js: op het scherm is
     X = (x − z)·2       (naar rechts)
     Y = (x + z) − y·2   (naar ONDER)
   In één wandvlak (z vast) geldt dus X = 2·dx en Y = dx − 2·dy. Een
   wijzerplaat die op het SCHERM rond is, is in voxels dus een scheve
   ellips; naarVox() rekent een schermpunt terug naar voxels, zodat de
   plaat rond blijft en de wijzers echt onder de juiste hoek staan.
===================================================================== */
var KX = 48, KZ = 1;            /* plek aan de wand z = 0, tussen twee deuren */
var HAAK = null;                /* het vaste decorstuk waar het icoontje aan hangt */
var CY = 34;                    /* hart van de wijzerplaat, voxels boven de vloer */
var R_PLAAT = 19, R_RAND = 22, R_KAST = 25;   /* stralen op het SCHERM */
var R_STREEP = 16.5, R_UUR = 10, R_MIN = 15.5;
var KL = { kast: '#7E6255', rand: '#E8C58E', plaat: '#FFF7E4', streep: '#7E6255',
           uur: '#4A3B33', min: '#C9788F', hart: '#E0A86B',
           /* de spookwijzers van de hulpladder: dezelfde twee wijzers, bleek */
           spookU: '#9A8578', spookM: '#D9A0B0',
           bel: '#E8C58E' };

/* Waar hangt het ⏰-icoontje aan? registry.plek zoekt alleen dingen, slots en
   VAST decor, en de klok is los decor. We hangen de knop dus aan een vast
   stuk in de gang en schuiven hem met dx/dz naar de klok - maar we lezen die
   plek uit rooms.js in plaats van hem hier over te typen: verhuist de kist,
   dan schuift het icoontje mee. Zelfde zoekorde als registry.plek (eerste
   decorstuk met die naam). */
function haakPlek() {
  var r = window.Rooms && Rooms.get('gang'), i, d, kist = null, eerste = null;
  if (r && r.decor) {
    for (i = 0; i < r.decor.length; i++) {
      d = r.decor[i];
      if (!d || !d.n) continue;
      if (!eerste) eerste = d;
      if (d.n === 'kist' && !kist) kist = d;
    }
  }
  d = kist || eerste;
  return d ? { n: d.n, x: d.x, z: d.z } : { n: 'kist', x: 114, z: 14 };
}

function naarVox(X, Y) {
  var dx = X / 2;
  return [Math.round(dx), Math.round((dx - Y) / 2)];
}
/* een streepje of wijzer onder schermhoek a (0 = 12 uur, met de klok mee),
   van straal r0 tot r1, dik = halve breedte in schermpunten. stap groter
   dan 1 geeft een STIPPELlijn: zo lezen de spookwijzers als een hint en
   niet als een tweede stel echte wijzers. */
function streep(v, r0, r1, a, dik, kl, z, stap) {
  var s = Math.sin(a), c = Math.cos(a), r, t, q;
  for (r = r0; r <= r1 + 0.01; r += (stap || 0.5)) {
    for (t = -dik; t <= dik + 0.01; t += 0.5) {
      q = naarVox(r * s + t * c, -r * c + t * s);
      v.push([q[0], CY + q[1], z, kl]);
    }
  }
}
function klokModel(p) {
  bakken++;
  var K = Art.kit, v = [], dx, dy, X, Y, d2, i, a, q, q2;
  var uur = (p && p.uur) || 12, mn = (p && p.min) || 0;
  /* kast, rand en wijzerplaat in één ronde: per voxel de schermafstand */
  for (dx = -13; dx <= 13; dx++) {
    X = 2 * dx;
    for (dy = -19; dy <= 19; dy++) {
      Y = dx - 2 * dy;
      d2 = X * X + Y * Y;
      if (d2 > R_KAST * R_KAST) continue;
      if (d2 > R_RAND * R_RAND) {
        v.push([dx, CY + dy, 0, KL.kast]);
        v.push([dx, CY + dy, 1, KL.kast]);
      } else if (d2 > R_PLAAT * R_PLAAT) {
        v.push([dx, CY + dy, 1, KL.rand]);
        v.push([dx, CY + dy, 2, KL.rand]);
      } else {
        v.push([dx, CY + dy, 1, KL.plaat]);
      }
    }
  }
  /* twee belletjes bovenop: dit is de wekker van het hotel. Ze staan op
     SCHERMhoogte even hoog (naarVox), anders zet de scheve projectie ze
     schuin naast elkaar. */
  q = naarVox(-13, -23); q2 = naarVox(13, -23);
  K.bx(v, q[0] - 1, CY + q[1], 1, 3, 3, 2, KL.bel);
  K.bx(v, q2[0] - 1, CY + q2[1], 1, 3, 3, 2, KL.bel);
  /* twaalf uurstreepjes; 12, 3, 6 en 9 als streepje, de rest een stipje */
  for (i = 1; i <= 12; i++) {
    a = i * Math.PI / 6;
    if (i % 3 === 0) { streep(v, R_STREEP - 2.5, R_STREEP + 0.5, a, 0.5, KL.streep, 2); continue; }
    q = naarVox(R_STREEP * Math.sin(a), -R_STREEP * Math.cos(a));
    v.push([q[0], CY + q[1], 2, KL.streep]);
  }
  /* spookwijzers (hulpladder): eerst, zodat de echte wijzers ze overschrijven */
  if (p && p.spookU !== undefined && p.spookU !== null) {
    streep(v, 2, R_UUR, hoekUur(p.spookU, p.spookM || 0), 1, KL.spookU, 2, 1.5);
    streep(v, 2, R_MIN, hoekMin(p.spookM || 0), 0.5, KL.spookM, 2, 1.5);
  }
  streep(v, 0, R_UUR, hoekUur(uur, mn), 1, KL.uur, 2);
  streep(v, 0, R_MIN, hoekMin(mn), 0.5, KL.min, 2);
  K.bx(v, -1, CY - 1, 2, 2, 2, 1, KL.hart);
  return v;
}
function hoekUur(u, m) { return (((u % 12) + (m || 0) / 60) / 12) * Math.PI * 2; }
function hoekMin(m) { return ((m % 60) / 60) * Math.PI * 2; }

Rooms.registerModel('klok', klokModel);
HAAK = haakPlek();

/* =====================================================================
   2. TIJD IN WOORDEN (Nederlandse afspraken: half 8 = 7:30)
===================================================================== */
function u12(u) { u = Math.round(u) % 12; return u <= 0 ? u + 12 : u; }
function volgU(u) { return u12(u + 1); }
function inMin(u, m) { return (u12(u) % 12) * 60 + (((m % 60) + 60) % 60); }
function vanMin(t) {
  t = ((Math.round(t) % 720) + 720) % 720;
  return { u: u12(Math.floor(t / 60)), m: t % 60 };
}
function tijdWoord(u, m) {
  u = u12(u); m = ((Math.round(m) % 60) + 60) % 60;
  if (m === 0) return u + ' uur';
  if (m === 15) return 'kwart over ' + u;
  if (m === 30) return 'half ' + volgU(u);
  if (m === 45) return 'kwart voor ' + volgU(u);
  if (m < 15) return m + ' over ' + u;
  if (m < 30) return (30 - m) + ' voor half ' + volgU(u);
  if (m < 45) return (m - 30) + ' over half ' + volgU(u);
  return (60 - m) + ' voor ' + volgU(u);
}
/* het klokje dat bij dit uur hoort: pictogram en getal in één knop */
var UURICO = ['🕛', '🕐', '🕑', '🕒', '🕓', '🕔', '🕕', '🕖', '🕗', '🕘', '🕙', '🕚'];
function uurIco(u, m) {
  var t = vanMin(inMin(u, m) + 30);        /* naar het dichtstbijzijnde uur */
  return UURICO[u12(t.u) % 12];
}

/* =====================================================================
   3. DE BEURT: getallen uit N, band en dag (HOTEL.md 3)
===================================================================== */
function bandKlem(b) { return b <= 3 ? 3 : b >= 5 ? 5 : 4; }
function klok5(m) { var q = Math.round(m / 5) * 5; return q >= 60 ? 0 : q; }

/* het uur dat de gast wil: uit de bevroren generator, per gast een uur op */
function doelTijd(band, dag, idx) {
  var k = State.sommen.klok(band) || { u: 7, m: 0 };
  var u = u12(k.u + idx), m = 0;
  /* De bevroren generator geeft het UUR (7 + (dag*3)%8, dus elke dag anders).
     Zijn minuten kunnen we niet zo overnemen: voor band 4 rekent hij altijd
     (dag + uur) % 4 == 3 uit en dus ALTIJD 45 (kwart voor), en voor band 5
     komt er een getal uit dat geen veelvoud van 5 hoeft te zijn (dag 1: :57).
     Daarom schuiven we hier zelf per dag en per gast een kwartier (band 4)
     of vijf minuten (band 5) op; de generator blijft ongemoeid. */
  if (band === 4) m = (((k.m || 0) + (dag + idx) * 15) % 60);
  else if (band >= 5) m = ((klok5(k.m || 0) + (dag + idx) * 5) % 60);
  return { u: u, m: m };
}
/* hoe ver moet er gedraaid worden? T = k·N + r, plafond per band */
function afstand(band, N, dag) {
  var r = dag % 2, uur, kwart = 0, vijf = 0;
  if (band <= 3) { uur = Math.max(1, Math.min(5, N + r)); }
  else if (band === 4) { uur = Math.max(1, Math.min(3, Math.ceil(N / 2))); kwart = (N + dag) % 4; }
  else { uur = Math.max(1, Math.min(3, Math.ceil(N / 3))); kwart = (N + dag) % 4; vijf = (N + dag) % 3; }
  return { uur: uur, kwart: kwart, vijf: vijf, min: uur * 60 + kwart * 15 + vijf * 5 };
}
/* vier tijden om uit te kiezen bij een tijdsduurvraag (band 5) */
function duurKeuzes(nuU, dh, dag) {
  var goed = inMin(nuU, 0) + dh * 60;
  var lijst = [goed, goed + 60, goed - 60, inMin(nuU, 0) - dh * 60], uit = [], i, t, gezien = {};
  for (i = 0; i < lijst.length; i++) {
    t = vanMin(lijst[i]);
    if (gezien[t.u]) continue;             /* nooit twee keer hetzelfde getal */
    gezien[t.u] = 1;
    uit.push(t.u);
  }
  i = 0;
  while (uit.length < 4 && i < 24) {
    i++; t = vanMin(goed + 120 + i * 60);
    if (!gezien[t.u]) { gezien[t.u] = 1; uit.push(t.u); }
  }
  /* vaste, maar per dag andere volgorde: geen willekeur in de opslag */
  var k = dag % 4, gedraaid = uit.slice(k).concat(uit.slice(0, k));
  return gedraaid;
}

function nieuweBeurt(N, band, dag, idx, gast, dutje) {
  band = bandKlem(band);
  var doel = doelTijd(band, dag, idx), a = afstand(band, N, dag);
  var duur = band >= 5 && (dag + idx) % 2 === 1;
  var start, keuzes = null, dh = a.uur;
  if (duur) {
    doel = { u: doel.u, m: 0 };                     /* tijdsduur gaat op hele uren */
    start = vanMin(inMin(doel.u, 0) - dh * 60);
    keuzes = duurKeuzes(start.u, dh, dag);
  } else {
    start = vanMin(inMin(doel.u, doel.m) - a.min);
  }
  return { dag: dag, N: N, band: band, idx: idx, gast: gast, slaapt: !!dutje,
           doelU: doel.u, doelM: doel.m, u: start.u, m: start.m,
           stap: duur ? 'duur' : 'zet', duur: duur ? dh : 0, keuzes: keuzes,
           missers: 0, ster: 0, af: 0, hulp: '' };
}

/* =====================================================================
   4. DE GASTEN: wie slaapt er?
===================================================================== */
function slaapt(g) {
  if (!g || !window.World) return false;
  var d = World.dier(g.id);
  if (!d) return false;
  if (d.inZijnBed && d.inZijnBed()) return true;
  return d.staat === 'slaap';
}
function slapers(lijst) {
  return (lijst || []).filter(function (g) { return !!g.bed && slaapt(g); });
}
/* voor de taakchip: hotel.js geeft de ruwe stand mee, geen ctx */
function eersteSlaper(s) {
  var l = slapers((s && s.gasten) || []);
  return l.length ? l[0] : null;
}
function rijtje() {
  var alle = C.state.gasten(), l = slapers(alle);
  if (!l.length) l = alle.filter(function (g) { return !!g.bed; });
  if (!l.length) l = alle.slice();
  return l.slice(0, 3);                    /* een ronde blijft kindermaat */
}
function gastVan(id) {
  var l = C.state.gasten(), i;
  for (i = 0; i < l.length; i++) if (l[i].id === id) return l[i];
  return null;
}
function naamVan(id) { var g = gastVan(id); return g ? g.naam : 'De gast'; }

/* =====================================================================
   5. DE WERELD: de klok neerzetten en bijwerken
===================================================================== */
function klokParams() {
  var p = { uur: S.u, min: S.m };
  /* hulpladder: vanaf de tweede misser wijzen bleke spookwijzers mee, zowel
     op de gewone zetkaart als op de kaart na een misser (HOTEL.md 5) */
  if (S.missers >= 2 && (S.stap === 'zet' || S.stap === 'mis')) {
    p.spookU = S.doelU; p.spookM = S.doelM;
  }
  return p;
}
function zetKlok() {
  C.wereld.decor('gang', { id: 'klok', model: 'klok', x: KX, z: KZ, ver: 1,
                           params: klokParams() });
  /* het cijfer ÓP de klok (HOTEL.md 9), net boven de kast tussen de belletjes */
  C.wereld.getalTag('klok', tijdWoord(S.u, S.m), { y: 48, prio: 12,
                     titel: 'de klok staat op ' + tijdWoord(S.u, S.m) });
  plaatVrij();
}
/* ---------- de wijzerplaat vrijhouden ----------
   De deurknoppen van het hotel hangen in de gang precies in de band waar de
   klok hangt (deur op y = 9, knop erboven): gemeten stonden "Kamer 1" en
   "Kamer 2" ÓP de wijzerplaat, en dan is er niets meer te lezen. De
   knoppenlaag houdt wél rekening met de knoppen van het spel dat speelt
   (hits.js: alles van de voorrang-eigenaar is VIP, en wie daar na het
   uitwijken nog overheen valt gaat even weg). Daarom leggen we één LEEG
   tagje van onszelf precies op de plaat: het is niet te zien en niet te
   tikken, maar het reserveert de plek van de wijzers. Zodra het spel stopt
   is het weg en staan de deurknoppen weer waar ze willen. */
function plaatVrij() {
  var k = (C.wereld.schaal ? C.wereld.schaal().k : 1) || 1;
  var d = Math.max(20, Math.round(2 * R_RAND * k));
  var s = C.hotspots.maak({
    id: 'wk_plaat', kind: 'tag', tagnaam: 'div', kamer: 'gang',
    x: KX, z: KZ, y: CY, op: 'midden', prio: 13, titel: 'de wijzerplaat',
    html: '<span style="display:block;width:' + d + 'px;height:' + d + 'px"></span>'
  });
  if (s && s.el && !s.el.__leeg) {
    s.el.__leeg = 1;
    s.el.style.background = 'transparent';
    s.el.style.border = '0';
    s.el.style.boxShadow = 'none';
    s.el.style.padding = '0';
  }
  return s;
}
function slaanZacht() {
  var nu = C.ui.nu();
  if (nu - slagT < 120) return;            /* twee tikken op één knop: één slag */
  slagT = nu;
  C.snd.klok();
}

/* =====================================================================
   6. DE KAART onder de klok
===================================================================== */
/* De zin op de kaart blijft binnen het budget van HOTEL.md 9: hooguit 8
   woorden EN 40 tekens, en op één regel past ongeveer 34 tekens. Met de
   langste naam (Stampertje) en de langste tijd ("5 over half 12") loopt
   "... wil om ... op" daar net over; dan zegt de kaart het korter. */
function zinZet() {
  var naam = naamVan(S.gast);
  var wil = tijdWoord(S.doelU, S.doelM);
  if (S.stap === 'mis')
    return ['De klok staat op ' + tijdWoord(S.u, S.m), naam + ' wil ' + wil];
  var een = naam + ' wil om ' + wil + ' op';
  if (een.length > 34) een = 'Wek ' + naam + ' om ' + wil;
  return [een, S.slaapt ? 'Zet de klok' : 'Zet de klok voor morgen'];
}
function zinDuur() {
  return [naamVan(S.gast) + ' slaapt nog ' + S.duur + ' uur',
          'Hoe laat is hij wakker?'];
}
/* Hoe breed is het kader nu? (zelfde maat als ui.js voor het cijferpad) */
function kaderPx() {
  var w = document.getElementById('world');
  return (w && w.clientWidth) ? w.clientWidth : 420;
}
/* De strook moet ÍN het kader passen. Gemeten met de volle woorden: vier
   knoppen samen 361 px. Dat past in een kader van 386 px (420x860 staand)
   en 682 px (860x420 liggend), maar niet in 356 px (iPhone 13), 326 px
   (360x740) of 286 px (320x640) - daar stak de strook buiten het kader.
   In zo'n kader staat het korte woord op de knop (strook 245 px);
   pictogram ÉN woord blijven staan (HOTEL.md 9). Naast deze grens meet
   strookNakijken() na het tekenen of het écht past. */
function kortWoord() {
  if (kortDwang) return true;
  var n = S.band >= 5 ? 4 : S.band >= 4 ? 3 : 2;
  return n >= 4 && kaderPx() < 370;
}
function strookNakijken() {
  straks(140, function () {
    if (!C || !S || kortDwang || S.af) return;
    var e = document.querySelector('[data-hot="wk_som_keuzes"]');
    if (!e || !e.offsetWidth || e.offsetWidth <= kaderPx() - 8) return;
    kortDwang = true;                    /* nog één keer, nu met korte woorden */
    teken(true);
  });
}
function knoppen() {
  var kort = kortWoord();
  var l = [{ id: 'uur', icoon: '🕐', tekst: kort ? 'uur' : 'uur erbij',
             kies: function () { draai(60); } }];
  if (S.band >= 4) l.push({ id: 'kwartier', icoon: '🕒', tekst: kort ? 'kwartier' : 'kwartier erbij',
                            kies: function () { draai(15); } });
  if (S.band >= 5) l.push({ id: 'vijf', icoon: '🕧', tekst: kort ? '5 min' : '5 minuten erbij',
                            kies: function () { draai(5); } });
  l.push({ id: 'klaar', icoon: '✅', tekst: 'Klaar', kies: function () { klaarTik(); } });
  return l;
}
function tijdKnoppen() {
  return S.keuzes.map(function (u) {
    return { id: 'u' + u, icoon: uurIco(u, 0), tekst: u + ' uur',
             kies: function () { kiesTijd(u); } };
  });
}
/* De sombalk is de stand van de klok, die live meeloopt terwijl je draait.
   Na een misser staat de tijd al in de zin ("De klok staat op 6 uur"); dan
   zou "nu: 6 uur" eronder hem voor de derde keer zeggen (de klok draagt zijn
   tijd zelf ook als cijfer). Dus: één keer zeggen. */
function somBalk() {
  return S.stap === 'mis' ? '' : 'nu: ' + tijdWoord(S.u, S.m);
}
/* de kaart opnieuw opbouwen (andere knoppenstrook); anders alleen bijwerken */
function tekenKaart(nieuw) {
  var duur = S.stap === 'duur';
  if (nieuw && kaart) { kaart.weg(); kaart = null; }
  kortWas = kortWoord();
  if (!kaart) {
    kaart = C.ui.somkaart('klok', somBalk(), {
      id: 'wk_som', hoog: 3, icoon: '⏰', pad: false,
      regel: duur ? zinDuur() : zinZet(),
      keuzeTitel: duur ? 'hoe laat wordt hij wakker?' : 'draai de klok',
      keuzes: duur ? tijdKnoppen() : knoppen()
    });
    if (kaart && S.hulp) kaart.hulp(S.hulp);
    strookNakijken();
    return kaart;
  }
  kaart.regel(duur ? zinDuur() : zinZet());
  kaart.som(somBalk());
  kaart.hulp(S.hulp || '');
  return kaart;
}
/* het wekkerkaartje bij het slapende dier: in zijn eigen kamer te zien.
   Ui.wolk werkt hetzelfde wolkje bij (zelfde id), dus er wordt niets
   afgebroken en opnieuw gebouwd bij elke tik. */
function tekenGast(zeg) {
  if (!S.gast || S.af) { C.ui.wolkWeg('wk_gast'); return; }
  C.ui.wolk(S.gast, { id: 'wk_gast', icoon: S.slaapt ? '💤' : '⏰',
                      tekst: zeg || tijdWoord(S.doelU, S.doelM), hoog: 54 });
}
function teken(nieuw, zeg) {
  zetKlok();
  tekenKaart(nieuw);
  tekenGast(zeg);
}

/* =====================================================================
   7. TIKKEN
===================================================================== */
function bewaar() { if (C) C.state.bewaar(); }

/* "uur erbij" / "kwartier erbij" / "5 minuten erbij": de wijzers draaien
   door, na 12 begint het gewoon weer bij 1. Nooit terugzetten. */
function draai(stapMin) {
  if (!C || !S || S.af) return null;
  if (S.stap === 'duur') return null;        /* eerst de tijdsduurvraag */
  var t = vanMin(inMin(S.u, S.m) + stapMin);
  S.u = t.u; S.m = t.m;
  if (S.stap === 'mis') S.stap = 'zet';      /* verder draaien: gewone zin terug */
  slaanZacht();
  teken(false);
  bewaar();
  return { u: S.u, m: S.m };
}
function goed() { return inMin(S.u, S.m) === inMin(S.doelU, S.doelM); }

/* ✅ Klaar */
function klaarTik() {
  if (!C || !S || S.af || S.stap === 'duur') return null;
  if (!goed()) {
    S.missers++;
    S.stap = 'mis';
    S.hulp = S.missers >= 2 ? '👻 de spookwijzers wijzen mee' : '💛 draai nog wat verder';
    C.snd.zacht();
    /* zacht in de wereld: het dier draait zich om en slaapt door */
    teken(false, S.slaapt ? 'slaapt nog' : 'nog niet');
    bewaar();
    return false;
  }
  wakkerWorden();
  return true;
}
function wakkerWorden() {
  S.stap = 'wakker';
  S.hulp = '';
  slagT = C.ui.nu();
  C.snd.klok();                            /* de slag bij het goede uur: nooit afgeremd */
  straks(220, function () { if (C) C.snd.ja(); });
  if (kaart) {
    /* de hint van de hulpladder hoort bij het zoeken, niet bij het feest:
       laat hij staan, dan wordt de kaart hoger en dekt hij de klok af */
    kaart.hulp('');
    /* ÉÉN regel: de feestkaart krijgt er een vinkvakje bij en werd met twee
       regels net hoog genoeg om de onderkant van de wijzerplaat te raken
       (gemeten in de suite: 2 px). De tijd staat al in de sombalk. */
    kaart.regel(naamVan(S.gast) + ' is wakker');
    kaart.klaar();
  }
  C.ui.wolkWeg('wk_gast');
  /* Het wakker worden gebeurt in de KAMER van de gast, en het kind staat in
     de gang: zonder deze camerasprong zag het alleen de groene kaart en
     nooit het dier dat overeind komt. Even mee naar de slaapkamer, en
     volgende() brengt de camera terug naar de klok. */
  var g = gastVan(S.gast), kam = g && (g.waar || g.kamer);
  if (kam && kam !== C.wereld.actief()) C.wereld.naar(kam);
  C.wereld.pose(S.gast, 'blij', 60);
  C.ui.wolk(S.gast, { id: 'wk_zon', icoon: '☀', tekst: 'goedemorgen', hoog: 54 });
  if (!S.ster) {
    S.ster = 1;
    C.taakKlaar('wekker', { sterren: 1 });
    if (window.Hotel) Hotel.render();      /* de ster in de balk meteen bijwerken */
  }
  zetKlok();
  bewaar();
  straks(2200, function () { if (C && S && S.stap === 'wakker') volgende(); });
  return true;
}
/* een tijd kiezen bij de tijdsduurvraag (band 5) */
function kiesTijd(u) {
  if (!C || !S || S.af || S.stap !== 'duur') return null;
  if (u12(u) !== u12(S.doelU)) {
    S.missers++;
    S.hulp = telLadder();
    C.snd.zacht();
    teken(false, S.slaapt ? 'slaapt nog' : 'nog niet');
    bewaar();
    return false;
  }
  S.stap = 'zet';
  S.hulp = '';
  C.snd.ja();
  teken(true);                               /* andere knoppen: kaart opnieuw */
  bewaar();
  return true;
}
/* samen tellen: van nu naar de wektijd, uur voor uur */
function telLadder() {
  var l = [], i;
  for (i = 0; i <= S.duur; i++) l.push(u12(S.u + i));
  return '💛 ' + l.join(' … ');
}

/* de volgende slaper, of klaar */
function volgende() {
  if (!C || !S) return false;
  var l = rijtje(), idx = S.idx + 1;
  C.ui.wolkWeg('wk_zon');
  /* het feestje in de slaapkamer is voorbij: terug naar de klok in de gang,
     want daar hangen de kaart en de knoppen van dit spel */
  if (C.wereld.actief() !== 'gang') C.wereld.naar('gang');
  if (idx >= l.length) {
    S.af = 1; S.stap = 'af';
    bewaar();
    C.ui.wolk('klok', { id: 'wk_af', icoon: '⏰', tekst: 'allemaal gewekt', hoog: 26 });
    straks(2200, function () { if (C) { C.ui.wolkWeg('wk_af'); C.sluit(); } });
    return true;
  }
  var g = l[idx], ster = S.ster;
  S = nieuweBeurt(S.N, S.band, S.dag, idx, g.id, slaapt(g));
  S.ster = ster;
  C.data().stand = S;
  if (kaart) { kaart.weg(); kaart = null; }
  teken(true);
  bewaar();
  return true;
}

/* =====================================================================
   8. START EN STOP
===================================================================== */
function start(ctx) {
  C = ctx;
  var l = rijtje();
  if (!l.length) {
    C.ui.wolk('kist', { id: 'wk_leeg', icoon: '🛏', tekst: 'nog geen gasten', hoog: 20 });
    straks(1800, function () { if (C) { C.ui.wolkWeg('wk_leeg'); C.sluit(); } });
    return;
  }
  var d = C.data(), N = Math.max(1, C.state.N()), band = bandKlem(C.state.band()), dag = C.state.dag();
  S = d.stand;
  var zelfde = S && S.dag === dag && S.N === N && S.band === band && !S.af &&
               gastVan(S.gast) && S.doelU;
  if (!zelfde) {
    S = nieuweBeurt(N, band, dag, 0, l[0].id, slaapt(l[0]));
    d.stand = S;
  } else {
    S.slaapt = slaapt(gastVan(S.gast));      /* na herladen slaapt iedereen weer */
    if (S.stap === 'wakker') S.stap = 'zet';
  }
  kaart = null;
  slagT = 0;
  kortDwang = false;
  C.wereld.naar('gang');
  teken(true);
  /* Kantelen maakt het kader smaller of breder: dan hoort er een andere
     woordlengte op de knoppen. Ui.opKader gebruikt World.onKader als die
     bestaat en anders zijn eigen ontdenderde melding (api-m1a 2). */
  if (C.ui.opKader) {
    kaderAf = C.ui.opKader(function () {
      if (!C || !S || S.af) return;
      if (kortDwang && kaderPx() >= 400) kortDwang = false;   /* weer ruimte */
      if (kortWoord() !== kortWas) teken(true);
      else zetKlok();                       /* andere voxelmaat: plaat hermeten */
    });
  }
  bewaar();
}

function stop() {
  stopKlokjes();
  if (kaderAf) { try { kaderAf(); } catch (e) {} kaderAf = null; }
  if (C) {
    if (kaart) kaart.weg();
    C.wereld.decorWisAlles();                /* eigen decor weg, ook zonder Hits */
    C.hotspots.wisAlles();
    C.hotspots.laat();
  }
  C = null; S = null; kaart = null;
  kortDwang = false; kortWas = false;
}

/* =====================================================================
   AANMELDEN
===================================================================== */
Games.register({
  id: 'wekker',
  naam: 'Wekkerdienst',
  kamer: 'gang',
  /* Het icoontje hoort ÓP de klok; haakPlek() leest de plek van het vaste
     decorstuk waar het aan hangt uit rooms.js, dus de knop schuift mee als
     dat stuk ooit verhuist (zie haakPlek). */
  hotspot: { obj: HAAK.n, dx: KX - HAAK.x, dz: KZ - HAAK.z, hoog: 26,
             icoon: '⏰', label: 'Wekker' },
  unlock: function (N) { return N >= 1; },
  stub: false,
  taak: {
    id: 'wekker', icoon: '⏰', prio: 3, tekst: 'Wekker zetten',
    wanneer: function (s) {
      if (!s || !s.gasten || !s.gasten.length) return false;
      return s.ronde === 'avond' || !!eersteSlaper(s);
    }
  },
  start: start,
  stop: stop,
  /* haakjes voor de speeltest en de suite (het hotel gebruikt ze niet).
     LET OP bij proef(): het DOELUUR komt uit state.sommen.klok(band), en die
     bevroren generator leest state.dag zelf. Wil je een andere dag proeven,
     zet dan eerst state.dag (zo doet de suite het ook). */
  proef: function (N, band, dag, idx) {
    return nieuweBeurt(N, bandKlem(band), dag, idx || 0, 'x', true);
  },
  woord: tijdWoord,
  kleuren: function () { return { uur: KL.uur, min: KL.min,
                                 spookU: KL.spookU, spookM: KL.spookM }; },
  maten: function () {
    return { x: KX, z: KZ, cy: CY, plaat: R_PLAAT, rand: R_RAND, kast: R_KAST,
             uur: R_UUR, minuut: R_MIN };
  },
  debug: function () {
    if (!S) return null;
    var q = JSON.parse(JSON.stringify(S));
    q.bakken = bakken;
    q.goed = goed();
    q.woord = tijdWoord(S.u, S.m);
    q.doelWoord = tijdWoord(S.doelU, S.doelM);
    return q;
  },
  doe: function (wat, a) {
    if (wat === 'uur') return draai(60);
    if (wat === 'kwartier') return draai(15);
    if (wat === 'vijf') return draai(5);
    if (wat === 'klaar') return klaarTik();
    if (wat === 'kies') return kiesTijd(a);
    if (wat === 'volgende') return volgende();
    if (wat === 'bakken') return bakken;
    return null;
  }
});
})();
