/* ---------------------------------------------------------------
   games/tobbe.js - TOBBE-TIJD (HOTEL.md 9: rekenen ín de wereld).

   Alles gebeurt in de tuin, er komt geen rekenblad naast de kamer:
     * de kist is het schuurrek: een sleepbron met de schepjes erop;
     * de tobbes staan als echte badkuipen op het erf, met het water
       zichtbaar in een klein peilglaasje op de knop en het aantal als
       cijfer óp de tobbe (wereld.getalTag);
     * de som hangt als sommenkaart vóór de tobbes: "3 + 3 = 6";
     * tussen de tobbes hangt het splitskraantje 🚰 (halveren) en ernaast
       staat het kannetje 🫗 voor wat er overblijft;
     * feedback is een wolkje met pictogram + getal ("🦆 te vol"),
       nooit een lap tekst, nooit een rood kruis;
     * alleen waar een getal getypt moet worden (verdubbelen, halveren)
       hangt het kleine cijferpad aan de sommenkaart.
   Daarna sleep je het dier met de wens 🛁 in een tobbe: het zakt met een
   zucht in het sop en komt er blinkend uit.

   HET REKENEN (IDEAS.md-curriculum, HOTEL.md 3 en spel 13):
     groep 3  splitsen t/m 10, even/oneven        6 = 3 + 3
     groep 4  verdubbelen t/m 20, halveren        6 -> dubbel 12 = 6 + 6
     groep 5  delen/halveren met rest             9 = 4 + 4, 1 in het kannetje
                                                  verdubbelen tot 36
   Drie soorten opdracht, gekozen met (dag + N) - dezelfde vaste afleiding
   die state.js voor zijn eigen sommen gebruikt:
     eerlijk  T schepjes eerlijk over de tobbes
     dubbel   "morgen dubbel zoveel gasten": 2 x het recept van vandaag
     half     de grote tobbe zit vol: halveren over twee tobbes
   Plafond per band: 10 / 20 / 36. Een REST kan alleen in band 5 ontstaan:
   in band 3 en 4 is T altijd even en zijn er precies twee tobbes.

   WAT DE API (NOG) NIET HEEFT - hier binnen opgelost, zie het rapport:
   * `state.sommen` kent geen halveer/verdubbel-generator (alleen deel,
     geld, klok, tafel). De getallen komen daarom uit N, band en dag -
     precies de schaalregel van HOTEL.md 3 - maar de afleiding staat hier.
   * de motor kent geen waterstand in een tobbe (`setBak` bestaat alleen
     voor voerbakjes). Het niveau staat daarom als peilglaasje op de knop
     van de tobbe, plus het cijfer óp de tobbe met wereld.getalTag.
   * (vervallen) een behoefte afvinken kan wel via ctx: `wereld.behoefteKlaar`
     (registry.js) zet `g.blij` en tekent het prikbord opnieuw. Dit spel
     gebruikt die functie zelf, zodra een gast in de tobbe stapt.
   * `wereld.getalTag` heeft een vaste prio 4, dus bij meer dan 16 knoppen
     in een kamer verdwijnen juist de cijfers het eerst. Dit spel houdt zijn
     eigen knoppen daarom bewust krap (hooguit 14 in de tuin).
---------------------------------------------------------------- */
(function () {
'use strict';

var C = null;          /* de ctx */
var S = null;          /* de spelstand (leeft in C.data(), wordt bewaard) */
var P = [];            /* de plekken van de tobbes in de tuin */
var kaart = null;      /* de sommenkaart met het cijferpad (vraagstap) */
var somLift = 0;       /* hoogtecorrectie van de sommenkaart (somPast) */
var somRondes = 0;     /* hoe vaak we die correctie al bijstelden */
var somCheckT = null;  /* het tikje dat de correctie nakijkt */
var klok = [];         /* lopende tikjes; stop() ruimt ze op */

var PLAFOND = { 3: 10, 4: 20, 5: 36 };
/* hoeveel dieren mag het briefje van vandaag hoogstens noemen, zodat T
   nooit boven het plafond van de band uitkomt */
var CAP = { 3: { eerlijk: 5 },
            4: { eerlijk: 10, dubbel: 5, half: 10 },
            5: { eerlijk: 10, dubbel: 9, half: 11 } };
var HAND = [1, 2, 5];
var DIER_ICO = { puppy: '🐶', poes: '🐱', konijn: '🐰', gans: '🦆' };

/* Eén regel voor enkelvoud en meervoud: mv(1, 'schepje', 'schepjes') geeft
   "1 schepje", mv(6, ...) geeft "6 schepjes". */
function mv(n, enk, meerv) { return n + ' ' + (n === 1 ? enk : meerv); }

function straks(ms, fn) { var t = setTimeout(fn, ms); klok.push(t); return t; }
function stopKlok() { klok.forEach(function (t) { clearTimeout(t); }); klok = []; }

/* =====================================================================
   1. HET RECEPT - N, band en dag bepalen de getallen (HOTEL.md 3)
===================================================================== */
function soorten(band) {
  /* band 3 doet alleen eerlijk splitsen t/m 10; verdubbelen en halveren
     komen erbij vanaf groep 4 */
  return band <= 3 ? ['eerlijk'] : ['eerlijk', 'dubbel', 'half'];
}

function recept(N, band, dag) {
  N = Math.max(1, N | 0);
  band = band <= 3 ? 3 : band >= 5 ? 5 : 4;
  dag = Math.max(1, dag | 0);
  var lijst = soorten(band), soort = lijst[(dag + N) % lijst.length];
  /* extra vieze beurt in groep 5: 3 schepjes per dier, dan kan er bij het
     halveren een rest overblijven (9 = 4 en 4, 1 over) */
  var perDier = (soort === 'half' && band >= 5) ? 3 : 2;
  var n0 = Math.max(1, Math.min(N, CAP[band][soort]));
  var M = (band >= 5 && soort !== 'half') ? 3 : 2;
  var basis = perDier * n0;
  var T = soort === 'dubbel' ? basis * 2 : basis;
  while (T > PLAFOND[band] && n0 > 1) {          /* vangnet: nooit erboven */
    n0--;
    basis = perDier * n0;
    T = soort === 'dubbel' ? basis * 2 : basis;
  }
  /* nooit een tobbe die leeg moet blijven: dan liever één tobbe minder
     (kan alleen bij een afgedwongen band met heel weinig gasten) */
  while (M > 2 && Math.floor(T / M) < 1) M--;
  return { soort: soort, band: band, n0: n0, perDier: perDier, basis: basis,
           T: T, M: M, per: Math.floor(T / M), rest: T - Math.floor(T / M) * M };
}

/* =====================================================================
   2. DE WERELD: tobbes erbij zetten
===================================================================== */
function gasten() {
  return C.state.gasten().filter(function (g) { return !!g.bed; });
}
function badgasten() {
  var wil = C.state.gasten().filter(function (g) { return g.behoefte === 'bad' && !g.blij; });
  if (wil.length) return wil;
  return gasten();                     /* niemand hoeft: dan mag iedereen */
}
function decorPlek(naam) {
  var r = C.wereld.kamer('tuin'), i;
  for (i = 0; i < r.decor.length; i++) if (r.decor[i].n === naam) return r.decor[i];
  return null;
}
/* ---------- plekken uitrekenen op SCHERMMAAT (GAMES-API.md 4) ----------
   In isometrie geldt: horizontaal ~ (x - z) * 2 px, verticaal ~ (x + z - 2y) px.
   Een knop is ~48-56 px, dus twee knoppen staan pas los als ze 55 px naast
   elkaar of 50 px boven elkaar staan. Daarom rekenen we alles uit vanaf de
   TOBBE-RIJ: dan blijft elke knop bij zijn eigen tobbe staan en schuift de
   hotspot-laag niets meer heen en weer. */
function rijU() { var u = 0; P.forEach(function (p) { u += p.x - p.z; }); return u / P.length; }
function rijD() { var d = 0; P.forEach(function (p) { d += p.x + p.z; }); return d / P.length; }
function uVan(i) { return P[i].x - P[i].z; }

/* Hoeveel css-pixels is één voxel? Dat verschilt per kamer en per stand van
   het scherm (de tuin is groot, dus in portret staat hij ver weg). Met
   ctx.wereld.schaal() rekenen we onze plekken in ECHTE pixels uit; zo klopt
   dezelfde opstelling staand én liggend. */
function sch() {
  var s = C.wereld.schaal ? C.wereld.schaal() : null;
  if (!s || !s.pxPerVoxelY) return { pxPerVoxelX: 2, pxPerVoxelY: 1, pxPerHoogte: 2 };
  return s;
}
/* boven de tobbe-rij: ver = (x - z) in voxels, hoogPx = echte pixels omhoog */
function inDeLucht(ver, hoogPx) {
  var s = sch(), som = rijD(), y = Math.round(hoogPx / s.pxPerHoogte);
  var r = C.wereld.kamer('tuin'), boven = (r.box ? r.box[2] : -10) + 34 / s.pxPerVoxelY;
  if (som - 2 * y < boven) y = Math.round((som - boven) / 2);   /* niet buiten het kader */
  return { kamer: 'tuin', x: Math.round((som + ver) / 2), z: Math.round((som - ver) / 2), y: y };
}
/* De voorste rij (sommenkaart, ✓, ↩, kraantje, kannetje) ligt op het gras
   vóór de tobbes: een vast plankje, midden in beeld (x = z), ver genoeg onder
   de cijfers op de tobbes en altijd binnen de onderrand van het kader. */
function voorRijDiepte() {
  var s = sch(), r = C.wereld.kamer('tuin'), diepste = 0;
  P.forEach(function (p) { diepste = Math.max(diepste, p.x + p.z); });
  var wens = diepste + 62 / s.pxPerVoxelY;
  var onder = (r.box ? r.box[3] : 220) - 46 / s.pxPerVoxelY;
  return Math.min(wens, onder);
}
function opGras(uPx) {
  var s = sch(), som = voorRijDiepte(), ver = uPx / s.pxPerVoxelX;
  return { kamer: 'tuin', x: Math.round((som + ver) / 2),
           z: Math.round((som - ver) / 2), y: 0 };
}
/* Het kraantje en het kannetje staan op het gras VÓÓR de tobbes, naast de
   sommenkaart. Tussen of naast de tobbes zelf is in portret geen ruimte: de
   tobbes staan daar ~65 px uit elkaar en een knop is al 48-56 px breed, dus
   dan zou de laag de tobbe-knoppen van hun eigen tobbe wegschuiven. Zo blijft
   de tobbe-rij rustig en staat het gereedschap op een vast plankje. */
function kraanPlek() { return opGras(150); }
function kanPlek() { return opGras(-150); }
/* de sommenkaart staat vóór de rij, op het gras. Met de zin erboven (HOTEL.md
   9) is de kaart ~100 px hoog in plaats van ~45, dus hij hangt een paar pixels
   boven de rij: anders klemt zijn onderrand tegen de onderkant van het kader
   (gemeten in liggend, kader 966x378 - zie tobbe/plek.js). */
function somPlek() { return opGras(0); }
/* somLift = de correctie die na het tekenen nodig bleek (zie somPast) */
function somHoog() {
  var f = document.getElementById('world');
  var hf = (f && f.clientHeight) || 480;
  /* kort kader (liggend): onder de rij is geen 55 px meer, dus omhoog.
     Hoog kader (portret): juist een stukje omlaag, dan raakt de kaart de
     knoppen op de tobbes niet. */
  return Math.round((hf < 430 ? 26 : -16) / sch().pxPerHoogte) + somLift;
}
/* De hotspot-laag klemt elke knop binnen het kader (hits.js), dus een kaart
   die te laag (of te hoog) hangt wordt tegen de rand geplakt en staat dan
   niet meer bij de tobbes. Na het tekenen meten we dat één keer na en tillen
   we de kaart precies genoeg op of laten we hem zakken; somLift onthoudt de
   correctie, zodat het niet elk beeld opnieuw hoeft. */
function somPast() {
  somCheckT = null;
  if (!C || !S) return;
  var el = document.querySelector('[data-hot="tb_som"]');
  var host = document.getElementById('worldHits');
  if (!el || !host || !el.offsetHeight) return;
  var r = el.getBoundingClientRect(), h = host.getBoundingClientRect();
  var per = Math.max(1, sch().pxPerHoogte), stap = 0;
  if (r.bottom > h.bottom - 8) stap = Math.ceil((r.bottom - (h.bottom - 8)) / per);
  else if (r.top < h.top + 8) stap = -Math.ceil(((h.top + 8) - r.top) / per);
  if (!stap || somRondes > 5) return;
  var nieuw = Math.max(-40, Math.min(40, somLift + stap));
  if (nieuw === somLift) return;
  somLift = nieuw;
  somRondes++;
  C.hotspots.maak({ id: 'tb_som', y: somHoog() });
  somNakijken();
}
function somNakijken() {
  if (somCheckT) return;
  somCheckT = straks(90, somPast);
}
/* de VRAAG (met het cijferpad eronder) hangt hoog bóven de rij: het pad zelf
   komt onder de kamer te hangen, en dan dekken ze elkaar niet af */
function vraagPlek() { return inDeLucht(0, 110); }
/* Alle wolkjes van het spel komen op dezelfde plek boven de tobbes te hangen.
   Een wolkje is 130-160 px breed; hing het aan de buitenste tobbe, dan zou de
   laag het tegen de rand van het kader duwen. Eén vaste plek leest ook
   rustiger: het kind weet waar het praatje verschijnt. */
function zegPlek() { return inDeLucht(0, 110); }

/* Een plekje voor een tobbe erbij: uit het vrije vloerraster van de tuin,
   zó gekozen dat de knoppen elkaar niet afdekken (GAMES-API.md 4:
   horizontaal ~ (x-z)*2 px, verticaal ~ (x+z-2y) px). */
function kiesPlek(gekozen) {
  var vrij = C.wereld.kamer('tuin').vrij || [], best = null, bestS = -1e9;
  vrij.forEach(function (v) {
    var ok = true, sep = 1e9, rij = 0;
    gekozen.forEach(function (q) {
      var du = Math.abs((v.x - v.z) - (q.x - q.z));
      var dd = Math.abs((v.x + v.z) - (q.x + q.z));
      if (du < 50 && dd < 46) ok = false;
      if (du < sep) sep = du;
      if (dd > rij) rij = dd;
    });
    if (!ok) return;
    var s = -rij * 1.5 - Math.abs(sep - 62) * 0.6;   /* zelfde rij, ruim ernaast */
    if (s > bestS) { bestS = s; best = v; }
  });
  return best;
}

/* De extra tobbes van de wasplaats zijn INVENTARIS van het spel, geen aankoop
   uit het meubelboek: ze kosten het kind niets en zijn daar niet te koop of op
   te pakken (het meubelboek werkt alleen met wat in zijn eigen laatje staat).
   Om ze ook in de gedeelde meubellijst herkenbaar te houden krijgt elke tobbe
   van dit spel het merkje `spa`, en de ids staan in ons eigen laatje. Zo is
   een badkuip die het kind zelf voor 8 munten koopt altijd te onderscheiden
   van een tobbe die de wasplaats zelf heeft neergezet. */
function gekochteKuip(id) {
  /* alles wat het meubelboek in zijn eigen laatje heeft staan is écht gekocht */
  var mijn = (C.state.spelData('meubels') || {}).mijn || [], i;
  for (i = 0; i < mijn.length; i++) if (mijn[i].id === id) return true;
  return false;
}
function merkSpa(id) {
  if (gekochteKuip(id)) return null;        /* van het kind, niet van ons */
  var lijst = (C.state.ruw() && C.state.ruw().meubels) || [], i;
  for (i = 0; i < lijst.length; i++) {
    if (lijst[i].id === id) { lijst[i].spa = 1; return lijst[i]; }
  }
  return null;
}

/* Het erf heeft al één tobbe; de rest zetten we er één keer bij met
   ctx.wereld.plaatsMeubel('badkuip'). De ids onthouden we in ons eigen
   laatje, zodat er na "Verder spelen" nooit een tweede rij bij komt. */
function zorgTobbes(M) {
  var uit = [], d = C.data();
  var t = C.wereld.slot('tuin', 'tobbe');
  if (t) uit.push({ x: t.x, z: t.z, vast: true });
  d.kuipen = d.kuipen || [];
  /* Élke badkuip die in de tuin staat telt mee - ook eentje die het kind in
     het meubelboek heeft gekocht (die kost munten). Zo zet dit spel er nooit
     eentje bovenop en blijft het aantal tobbes precies wat de band vraagt.
     Een badkuip is een decor-meubel met het tobbe-model. */
  C.wereld.kamerMeubels('tuin').forEach(function (m) {
    if (m.n === 'tobbe' || d.kuipen.indexOf(m.id) >= 0) uit.push({ x: m.x, z: m.z, id: m.id });
  });
  /* na "Verder spelen" bouwt het hotel de meubellijst opnieuw op; onze eigen
     tobbes krijgen hun merkje dan meteen terug */
  d.kuipen.forEach(function (id) { merkSpa(id); });
  while (uit.length < M) {
    var p = kiesPlek(uit);
    if (!p) break;
    var m = C.wereld.plaatsMeubel('tuin', 'badkuip', p.x, p.z);
    if (!m) break;
    d.kuipen.push(m.id);
    merkSpa(m.id);                       /* van de wasplaats, niet gekocht */
    uit.push({ x: m.x, z: m.z, id: m.id });
  }
  uit.sort(function (a, b) { return (a.x - a.z) - (b.x - b.z); });
  return uit.slice(0, M);
}

/* =====================================================================
   3. START / STOP
===================================================================== */
function nieuweStand(N, band, dag) {
  var r = recept(N, band, dag), i;
  var s = { dag: dag, N: N, band: r.band, soort: r.soort, n0: r.n0, perDier: r.perDier,
            basis: r.basis, T: r.T, M: r.M, per: r.per, rest: r.rest,
            stap: r.soort === 'eerlijk' ? 'vullen' : 'vraag',
            rek: r.soort === 'eerlijk' ? r.T : (r.soort === 'dubbel' ? r.basis : 0),
            tob: [], kan: 0, inbad: [], hand: 1, missers: 0, lijn: 0,
            hulp: 0, wens: 0, ster: 0, mors: -1, zeg: null, t0: 0 };
  for (i = 0; i < r.M; i++) { s.tob.push(0); s.inbad.push([]); }
  if (r.soort === 'half') s.tob[0] = r.T;
  return s;
}

function start(ctx) {
  C = ctx;
  var g = gasten();
  if (!g.length) {
    C.ui.wolk('tobbe', { id: 'tb_leeg', door: 'tobbe', kamer: 'tuin',
                         icoon: '🛏', tekst: 'nog geen gasten', hoog: 20 });
    straks(1800, function () { if (C) { C.ui.wolkWeg('tb_leeg'); C.sluit(); } });
    return;
  }
  var d = C.data(), N = g.length, band = C.state.band(), dag = C.state.dag();
  S = d.stand;
  if (!S || !S.T || S.stap === 'af' || S.dag !== dag || S.N !== N || S.band !== band) {
    S = nieuweStand(N, band, dag);
    d.stand = S;
  }
  S.t0 = C.ui.nu();
  somLift = 0; somRondes = 0; somCheckT = null;
  P = zorgTobbes(S.M);
  if (P.length < 2) {                       /* zou niet moeten kunnen */
    C.ui.wolk('tobbe', { id: 'tb_leeg', door: 'tobbe', kamer: 'tuin',
                         icoon: '🛁', tekst: 'geen plek', hoog: 20 });
    straks(1800, function () { if (C) { C.ui.wolkWeg('tb_leeg'); C.sluit(); } });
    return;
  }
  if (P.length < S.M) herschaal(P.length);
  C.wereld.naar('tuin');
  teken();
}

/* minder tobbes dan gehoopt: de som opnieuw verdelen (band 3 en 4 houden
   dan nog steeds twee tobbes en dus nooit een rest) */
function herschaal(M) {
  S.M = M;
  S.per = Math.floor(S.T / M);
  S.rest = S.T - S.per * M;
  S.tob = S.tob.slice(0, M);
  S.inbad = S.inbad.slice(0, M);
  while (S.tob.length < M) { S.tob.push(0); S.inbad.push([]); }
}

function stop() {
  stopKlok();
  if (C) { C.hotspots.wisAlles(); C.hotspots.laat(); }
  C = null; S = null; P = []; kaart = null;
  somLift = 0; somRondes = 0; somCheckT = null;
}

function bewaar() { if (C) C.state.bewaar(); }

/* De ster (en het vinkje op het prikbord) hoort bij de hele ronde: het
   rekenwerk plus de badbeurt. Hij valt hooguit één keer per ronde. */
function ster() {
  if (!S || S.ster) return false;
  S.ster = 1;
  C.taakKlaar('bad', { sterren: 1 });
  return true;
}

/* =====================================================================
   4. TEKENEN - alles hangt aan een voorwerp in de tuin
===================================================================== */
function rand() { return S.per + 2; }          /* de rand van de tobbe */
function kanNodig() { return S.rest > 0 || S.band >= 5; }
function ico(g) { return DIER_ICO[g.soort] || '🐾'; }

/* het peilglaasje op de knop: zoveel water als er in zit, met de streep
   erbij zodra die aan mag (na een misser of als het goed is) */
function peil(n, mors) {
  var cap = Math.max(rand(), 3);
  var hp = Math.min(100, Math.round(n * 100 / cap));
  var mp = Math.round(S.per * 100 / cap);
  var s = '<span style="position:relative;display:block;width:30px;height:34px;box-sizing:border-box;' +
    'border:3px solid #D0A87A;border-top:none;border-radius:3px 3px 13px 13px;' +
    'background:#FBEEDD;overflow:hidden">' +
    '<span style="position:absolute;left:0;right:0;bottom:0;height:' + hp +
    '%;background:linear-gradient(#D6EFF8,#8FCFE3)"></span>';
  if (S.lijn) {
    s += '<span style="position:absolute;left:0;right:0;bottom:' + mp +
      '%;border-top:3px dashed ' + (n === S.per ? '#5EBE97' : '#E58FA8') + '"></span>';
  }
  /* het aantal ook ÍN het glaasje: zo is de knop nooit een leeg chipje, en
     tijdens de hulp van Els (dan liggen er spookcijfers op de tobbe in plaats
     van het echte cijfer) blijft de inhoud te zien */
  s += '<span style="position:absolute;left:0;right:0;top:8px;text-align:center;' +
    'font-size:.72rem;font-weight:700;color:#3F4F57;text-shadow:0 1px 0 #FFFFFFAA">' +
    n + '</span>';
  s += '</span>';
  if (n > 0) s += '<span style="font-size:.7rem;line-height:1">' + (mors ? '💦' : '🫧') + '</span>';
  return s;
}

function tekenTobbes() {
  P.forEach(function (p, i) {
    var n = S.tob[i], vol = S.stap === 'baden' || S.stap === 'af';
    var html = peil(vol ? S.per : n, S.mors === i);
    if (vol && S.inbad[i].length) {
      html += '<span style="font-size:1rem;line-height:1">' +
        S.inbad[i].map(function (id) {
          var g = C.state.gast(id);
          return g ? ico(g) : '🐾';
        }).join('') + '</span>';
    }
    C.hotspots.maak({
      id: 'tb_kuip' + i, kamer: 'tuin', x: p.x, z: p.z,
      y: Math.round(52 / sch().pxPerHoogte),
      html: html, kind: 'drop', drop: 'tobbe', data: { tob: i },
      klas: 'hotkar', prio: 12,
      titel: 'tobbe ' + (i + 1) + ': ' + n + (S.lijn ? ' van ' + S.per : ''),
      aan: function () { tikTobbe(i); }
    });
    /* het aantal als cijfer ÓP de tobbe (tijdens de hulp van Els liggen
       daar de spookcijfers, en 16 knoppen per kamer is het maximum) */
    if (!S.hulp) {
      C.wereld.getalTag({ x: p.x, z: p.z, kamer: 'tuin' }, vol ? S.per : n,
                        { id: 'tb_n' + i, y: 0, titel: 'schepjes in tobbe ' + (i + 1) });
    } else C.wereld.getalTag({ x: 0, z: 0 }, null, { id: 'tb_n' + i });
  });
}

function tekenRek() {
  var kist = decorPlek('kist');
  if (!kist) return;
  C.hotspots.bron({ x: kist.x, z: kist.z, kamer: 'tuin' }, {
    id: 'tb_rek', icoon: '🧴', aantal: S.rek, hand: S.rek ? S.hand : null, hoog: 14,
    klas: S.rek ? '' : 'leeg', prio: 10,
    titel: 'rek met ' + mv(S.rek, 'schepje', 'schepjes') + ', pak ' + S.hand,
    tik: function () { wisselHand(); },
    sleep: {
      dropSel: '[data-drop="tobbe"]',
      ghostHTML: function () { return '<div style="font-size:26px">🥄</div>'; },
      canDrag: function () { return !!S && S.stap === 'vullen' && S.rek > 0; },
      onDrop: function (t) { schep(doelVan(t), S.hand); },
      onTap: function () { wisselHand(); }
    }
  });
}

function tekenSom() {
  /* het kannetje hoort in de som mee, anders zou er "4 + 4 = 9" staan */
  var delen = S.tob.slice();
  if (kanNodig()) delen.push(S.kan);
  var lijn = delen.join(' + ') + ' =';
  var totaal = delen.reduce(function (a, b) { return a + b; }, 0);
  var af = S.stap !== 'vullen' && S.stap !== 'vraag';
  /* één gewone zin boven de som (HOTEL.md 9): "3 + 3 =" alleen zegt een
     kind van zes niets; de zin noemt de schepjes en de tobbes. */
  kaart = C.ui.somkaart(somPlek(), lijn, {
    id: 'tb_som', door: 'tobbe', kamer: 'tuin', pad: false, hoog: somHoog(),
    klas: af ? 'af' : '', icoon: '🧴',
    /* Deze kaart vult zichzelf in (pad: false): hij telt mee wat er NU in de
       tobbes zit. Daarom staat er geen vraag boven - "Hoeveel elk?" boven een
       som die "1 + 1 = 2" laat zien is een vraag met een fout antwoord. De
       zin beschrijft dus de opdracht; het vragen gebeurt op de vraagkaart met
       het cijferpad. Kort houden: de kaart staat in de voorste rij naast het
       vinkje en het kraantje, en die rij is in portret maar ~386 px breed
       (tobbe/breedte.js: 137 px past, 146 px is de grens). */
    regel: af ? ['Overal ' + S.per + ' erin', 'Zo is het goed!']
              : [S.T + ' in ' + mv(S.M, 'tobbe', 'tobbes'), 'Verdeel het eerlijk']
  });
  if (kaart) kaart.zet(totaal);
  somNakijken();
}

function tekenKraan() {
  var p = kraanPlek();
  C.hotspots.maak({
    id: 'tb_kraan', kamer: 'tuin', x: p.x, z: p.z, y: 0,
    icoon: '🚰', klas: 'hotwolk', prio: 9, titel: 'splitskraantje: halveren',
    aan: function () { kraantje(); }
  });
}

function tekenKan() {
  var l = kanPlek();
  C.hotspots.maak({
    id: 'tb_kan', kamer: 'tuin', x: l.x, z: l.z, y: 0,
    icoon: '🫗', getal: S.kan || null, kind: 'drop', drop: 'tobbe',
    data: { tob: 'kan' }, prio: 9, titel: 'kannetje: ' + S.kan,
    aan: function () { schep('kan', S.hand); }
  });
}

function tekenZeg() {
  if (!S.zeg) return;
  var z = S.zeg, p = zegPlek();
  C.ui.wolk(z.obj || p, { id: 'tb_zeg', door: 'tobbe', kamer: 'tuin', icoon: z.icoon,
                          getal: z.getal === undefined ? null : z.getal, tekst: z.tekst,
                          klas: z.klas || 'hulp',
                          hoog: z.hoog === undefined ? p.y : z.hoog, prio: 11 });
}

function teken() {
  if (!C || !S) return;
  C.hotspots.wisAlles();
  if (S.stap === 'baden' || S.stap === 'af') { tekenBaden(); return; }
  tekenTobbes();
  tekenRek();
  if (S.stap === 'vraag') { tekenVraag(); C.wereld.vuil(); return; }
  tekenSom();
  tekenKraan();
  if (kanNodig()) tekenKan();
  /* één korte regel: het recept van vandaag, zolang er nog niets staat */
  if (S.rek === S.T && !S.missers) {
    C.ui.wolk({ x: (decorPlek('kist') || P[0]).x, z: (decorPlek('kist') || P[0]).z, kamer: 'tuin' },
              { id: 'tb_recept', door: 'tobbe', icoon: '🧴', getal: S.T,
                tekst: mv(S.M, 'tobbe', 'tobbes'), hoog: 52, prio: 9 });
  }
  /* "zo is het goed": tikken mag altijd. Staan er nog schepjes op het rek,
     dan zegt het wolkje dat rustig ("🥄 2 nog op het rek"). */
  var k = opGras(96);
  C.hotspots.maak({
    id: 'tb_klaar', kamer: 'tuin', x: k.x, z: k.z, y: 0,
    icoon: '✓', klas: 'hotwolk goed', prio: 13, titel: 'zo is het goed',
    aan: function () { check(); }
  });
  if (S.missers >= 2) {
    var e = opGras(-96);
    C.hotspots.maak({
      id: 'tb_els', kamer: 'tuin', x: e.x, z: e.z, y: 0,
      icoon: '🩺', klas: 'hotwolk hulp', prio: 8, titel: 'buurvrouw Els doet het voor',
      aan: function () { hulp(); }
    });
  } else if (S.rek < S.T || S.tob.some(function (n) { return n > 0; })) {
    var o = opGras(-96);
    C.hotspots.maak({
      id: 'tb_opnieuw', kamer: 'tuin', x: o.x, z: o.z, y: 0,
      icoon: '↩', klas: 'hotwolk', prio: 7, titel: 'opnieuw beginnen',
      aan: function () { leeg(); }
    });
  }
  if (S.hulp) spookNeer();
  tekenZeg();
  C.wereld.vuil();
}

/* ---------- de vraagstap: het enige moment met een cijferpad ---------- */
function tekenVraag() {
  var kist = decorPlek('kist') || { x: P[0].x, z: P[0].z };
  if (S.soort === 'dubbel') {
    C.ui.wolk({ x: kist.x, z: kist.z, kamer: 'tuin' },
              { id: 'tb_recept', door: 'tobbe', icoon: '🧴', getal: S.basis,
                tekst: 'morgen dubbel', hoog: 52, prio: 9 });
    kaart = C.ui.somkaart(vraagPlek(), S.basis + ' + ' + S.basis + ' =',
      { id: 'tb_vraag', door: 'tobbe', kamer: 'tuin', open: true, max: 2,
        hoog: vraagPlek().y, icoon: '🧴',
        regel: ['Morgen twee keer ' + S.basis, 'Hoeveel samen?'],
        onOk: function (n, k) { antwoord(n, S.T, k); } });
  } else {
    var p = kraanPlek();
    C.ui.wolk({ x: p.x, z: p.z, kamer: 'tuin' },
              { id: 'tb_recept', door: 'tobbe', icoon: '🚰', getal: S.T,
                tekst: 'in twee helften', hoog: 26, prio: 9 });
    kaart = C.ui.somkaart(vraagPlek(), 'helft van ' + S.T + ' =',
      { id: 'tb_vraag', door: 'tobbe', kamer: 'tuin', open: true, max: 2,
        hoog: vraagPlek().y, icoon: '🚰',
        /* Bij een ONEVEN aantal is "de helft van 9" niet 4: er blijft een
           schepje over (band 5, HOTEL.md 5). Dan zegt de zin dat ook, anders
           staat er een leesbare leugen boven de som. */
        /* Bij een ONEVEN aantal is "de helft van 9" niet 4: er blijft een
           schepje over (band 5, HOTEL.md 5). Dat staat op de eerste regel, de
           vraag zelf is een hele vraag (geen "Hoeveel in elke? 1 over" meer).
           Gemeten met tobbe/breedte.js: 177-186 px, ruim binnen de ~200 px
           die hier boven de tobbes past. */
        regel: S.rest
          ? [S.T + ' halveren, ' + S.rest + ' over', 'Hoeveel in elke helft?']
          : ['De helft van ' + mv(S.T, 'schepje', 'schepjes'),
             'Hoeveel in elke helft?'],
        onOk: function (n, k) { antwoord(n, S.per, k); } });
  }
  tekenZeg();
}

function antwoord(n, goed, k) {
  if (n === null) return;
  if (n !== goed) {
    S.missers++;
    S.lijn = 1;
    C.snd.zacht();
    k.zet('').hulp(S.soort === 'dubbel'
      ? C.ui.telMee(S.basis, 2)
      : C.ui.telMee(goed, 2, S.rest ? ' … en ' + S.rest + ' over.' : '.'));
    bewaar();
    return;
  }
  k.zet(n).klaar();
  C.snd.ja();
  if (S.soort === 'dubbel') S.rek = S.T;
  else {
    S.tob[0] = S.per; S.tob[1] = S.per; S.kan = S.rest;
    if (S.rest) zeg({ icoon: '🫗', getal: S.rest, tekst: 'blijft over', klas: '' });
  }
  S.stap = 'vullen';
  S.lijn = 1;
  bewaar();
  straks(650, function () { if (C && S) teken(); });
}

/* =====================================================================
   5. SCHEPPEN, GIETEN, KRAANTJE
===================================================================== */
function doelVan(t) {
  if (!t) return null;
  var v = t.getAttribute('data-h-tob');
  if (v === null) return null;
  return v === 'kan' ? 'kan' : parseInt(v, 10);
}
function zeg(o) { S.zeg = o || null; }
function wisselHand() {
  S.hand = HAND[(HAND.indexOf(S.hand) + 1) % HAND.length];
  C.snd.tik();
  teken();
}

function schep(doel, k) {
  if (!S || S.stap !== 'vullen' || doel === null || doel === undefined) return;
  k = Math.min(Math.max(1, k | 0), S.rek);
  if (k <= 0) {
    C.snd.zacht();
    zeg({ icoon: '🧴', getal: 0, tekst: 'rek is leeg' });
    teken();
    return;
  }
  S.mors = -1; zeg(null);
  S.rek -= k;
  if (doel === 'kan') { S.kan += k; C.snd.plop(1); }
  else {
    var i = doel | 0;
    if (!(i >= 0 && i < S.M)) { S.rek += k; return; }
    S.tob[i] += k;
    C.snd.plop(S.hand);
    if (S.tob[i] > rand()) { overloop(i); return; }
  }
  bewaar();
  teken();
}

/* tikken op een tobbe: is het rek leeg, dan giet je van deze tobbe over
   naar de leegste - zo kun je ook zonder kraantje eerlijk verdelen */
function giet(i) {
  var doel = -1, j;
  for (j = 0; j < S.M; j++) if (j !== i && (doel < 0 || S.tob[j] < S.tob[doel])) doel = j;
  if (doel < 0 || S.tob[i] <= 0) {
    C.snd.zacht();
    return;
  }
  var k = Math.min(S.hand, S.tob[i]);
  S.tob[i] -= k;
  S.tob[doel] += k;
  S.mors = -1; zeg(null);
  C.snd.plop(1);
  if (S.tob[doel] > rand()) { overloop(doel); return; }
  bewaar();
  teken();
}

function tikTobbe(i) {
  if (!S) return;
  if (S.stap === 'baden') { volgendeInBad(i); return; }
  if (S.stap !== 'vullen') return;
  if (S.rek > 0) schep(i, S.hand);
  else giet(i);
}

/* het splitskraantje: de volste tobbe wordt gehalveerd naar de leegste */
function kraantje() {
  if (!S || S.stap !== 'vullen') return;
  var bron = 0, doel = -1, i;
  for (i = 1; i < S.M; i++) if (S.tob[i] > S.tob[bron]) bron = i;
  for (i = 0; i < S.M; i++) if (i !== bron && (doel < 0 || S.tob[i] < S.tob[doel])) doel = i;
  if (doel < 0 || S.tob[bron] < 2) {
    C.snd.zacht();
    zeg({ icoon: '🚰', tekst: 'eerst sop erin' });
    teken();
    return;
  }
  var m = S.tob[bron], h = Math.floor(m / 2), r = m - 2 * h;
  if (r && S.band < 5) {                       /* even/oneven, groep 3 */
    S.lijn = 1;
    C.snd.zacht();
    zeg({ icoon: '⚖️', getal: m, tekst: 'is oneven' });
    teken();
    return;
  }
  S.tob[bron] = h; S.tob[doel] += h; S.kan += r;
  S.mors = -1;
  C.snd.plop(2);
  zeg(r ? { icoon: '🫗', getal: r, tekst: 'blijft over', klas: '' }
        : { icoon: '🚰', getal: h, tekst: 'en ' + h, klas: 'goed' });
  bewaar();
  teken();
  if (S.tob[bron] > rand()) overloop(bron);
}

function leeg() {
  if (!S) return;
  var i;
  for (i = 0; i < S.M; i++) S.tob[i] = 0;
  S.kan = 0;
  S.rek = S.T;
  if (S.soort === 'half') { S.tob[0] = S.T; S.rek = 0; }
  S.mors = -1; S.hulp = 0; zeg(null);
  spookWeg();
  C.snd.terug();
  bewaar();
  teken();
}

/* =====================================================================
   6. DE VRIENDELIJKE CONTROLE - nooit een kruis
===================================================================== */
/* te vol: het sop glijdt over de rand op de tegels, de dieren liggen
   dubbel, de eend drinkt het op en de schepjes staan weer op het rek */
function overloop(i) {
  S.rek += S.tob[i];
  S.tob[i] = 0;
  S.missers++;
  S.lijn = 1;
  S.mors = i;
  C.snd.zacht();
  zeg({ icoon: '🦆', tekst: 'te vol' });
  C.state.gasten().forEach(function (g) {
    if (g.waar === 'tuin') C.wereld.setMood(g.id, 'bouncy');   /* ze lachen */
  });
  bewaar();
  teken();
  straks(1400, function () { if (C && S && S.mors === i) { S.mors = -1; teken(); } });
}

function check() {
  if (!S || S.stap !== 'vullen') return;
  var i;
  if (S.rek > 0) {
    mis({ icoon: '🥄', getal: S.rek, tekst: 'nog op het rek' });
    return;
  }
  for (i = 0; i < S.M; i++) if (S.tob[i] > S.per) { overloop(i); return; }
  var gelijk = true;
  for (i = 1; i < S.M; i++) if (S.tob[i] !== S.tob[0]) gelijk = false;
  if (!gelijk) {
    mis({ icoon: '⚖️', tekst: 'even hoog' });
    return;
  }
  if (S.kan !== S.rest) {
    mis({ icoon: '🫗', getal: S.rest, tekst: 'hoort hierin' });
    return;
  }
  if (S.tob[0] !== S.per) {
    mis({ icoon: '🥄', getal: S.per - S.tob[0], tekst: 'erbij' });
    return;
  }
  geslaagd();
}

function mis(o) {
  S.missers++;
  S.lijn = 1;
  S.mors = -1;
  C.snd.zacht();
  zeg(o);
  bewaar();
  teken();
}

function geslaagd() {
  S.stap = 'baden';
  S.lijn = 1;
  S.mors = -1;
  S.tel = 0;
  zeg(null);
  spookWeg();
  /* het water is klaar: wie in bad moet komt er zelf aan lopen */
  moetNogInBad().forEach(function (g) {
    var d = C.wereld.dier(g.id), p = P[0];
    if (d && d.kamer === 'tuin') return;
    C.wereld.reis(g.id, 'tuin', { x: Math.max(12, p.x - 16), z: p.z, na: 'wacht' });
    g.waar = 'tuin';
  });
  /* Het adaptieve signaal telt hier al mee; de STER (en het afvinken van
     het taakje) hoort bij de hele ronde en valt pas als de gasten gebaad
     hebben - zie klaarMetBaden(). Anders krijgt één ronde twee sterren. */
  C.state.tel(S.missers === 0, C.ui.nu() - S.t0);
  C.snd.tover();
  bewaar();
  teken();
  var gp = zegPlek();
  C.ui.wolk(gp, { id: 'tb_goed', door: 'tobbe', kamer: 'tuin', icoon: '✅', getal: S.per,
                  tekst: 'even hoog', klas: 'goed', hoog: gp.y, prio: 12 });
  straks(2200, function () { if (C) C.ui.wolkWeg('tb_goed'); });
}

/* ---------- Els doet het voor: de goede aantallen als spookcijfers ---------- */
function spookWeg() {
  if (!C) return;
  P.forEach(function (p, i) { C.wereld.getalTag({ x: 0, z: 0 }, null, { id: 'tb_s' + i }); });
  C.wereld.getalTag({ x: 0, z: 0 }, null, { id: 'tb_sk' });
}
function spookNeer() {
  P.forEach(function (p, i) {
    C.wereld.getalTag({ x: p.x, z: p.z, kamer: 'tuin' }, S.per,
                      { id: 'tb_s' + i, y: 0, klas: 'hotspook', titel: 'zoveel hoort erin' });
  });
  if (S.rest > 0) {
    var l = kanPlek();
    C.wereld.getalTag({ x: l.x, z: l.z, kamer: 'tuin' }, S.rest,
                      { id: 'tb_sk', y: Math.round(30 / sch().pxPerHoogte),
                        klas: 'hotspook', titel: 'zoveel blijft over' });
  }
}
function hulp() {
  S.hulp = 1;
  zeg({ icoon: '🩺', getal: S.per, tekst: 'ieder evenveel' });
  C.state.zetGezien('tobbe_els');
  C.snd.brief();
  bewaar();
  teken();
}

/* =====================================================================
   7. DE DIEREN IN BAD
===================================================================== */
function inBadIds() {
  var uit = [];
  S.inbad.forEach(function (l) { l.forEach(function (id) { uit.push(id); }); });
  return uit;
}
function wachtenden() {
  var er = inBadIds();
  return badgasten().filter(function (g) { return er.indexOf(g.id) < 0; });
}
function moetNogInBad() {
  var er = inBadIds();
  return C.state.gasten().filter(function (g) {
    return g.behoefte === 'bad' && !g.blij && er.indexOf(g.id) < 0;
  });
}

function tekenBaden() {
  tekenTobbes();
  tekenSom();
  var wacht = wachtenden();
  wacht.slice(0, 3).forEach(function (g) {
    var d = C.wereld.dier(g.id);
    if (!d || d.kamer !== 'tuin') return;
    C.hotspots.maak({
      id: 'tb_dier' + g.id, kamer: 'tuin', x: d.x, z: d.z, y: 34,
      html: '<span class="ico">' + ico(g) + '</span><span class="get">🛁</span>',
      klas: 'hotbron', prio: 11, titel: g.naam + ' wil in bad',
      volg: function () {
        var q = C.wereld.dier(g.id);
        return q ? { x: q.x, z: q.z, y: 34 } : null;
      },
      aan: function () { volgendeInBad(-1); }
    });
    dierSleep(g.id);
  });
  var bp = zegPlek();
  if (S.stap === 'af') {
    C.ui.wolk(bp, { id: 'tb_af', door: 'tobbe', kamer: 'tuin', icoon: '⭐',
                    tekst: 'blinkend schoon', klas: 'goed', hoog: bp.y, prio: 13,
                    tik: function () { C.sluit(); } });
  } else if (wacht.length && !S.zeg) {
    /* één praatje tegelijk: staat er een wolkje van "😌 lekker warm", dan
       hoeft de uitleg er niet ook nog bij te hangen */
    C.ui.wolk(bp, { id: 'tb_bad', door: 'tobbe', kamer: 'tuin', icoon: '🛁',
                    getal: wacht.length,
                    tekst: wacht.length === 1 ? 'mag in de tobbe' : 'mogen in de tobbe',
                    hoog: bp.y, prio: 10 });
  }
  if (S.stap === 'baden' && !wacht.length && inBadIds().length) {
    var k = opGras(96);
    C.hotspots.maak({
      id: 'tb_klaar', kamer: 'tuin', x: k.x, z: k.z, y: 0,
      icoon: '✓', klas: 'hotwolk goed', prio: 13, titel: 'klaar met badderen',
      aan: function () { klaarMetBaden(); }
    });
  }
  tekenZeg();
  /* een dier met de wens 🛁 kan nog onderweg zijn: dan tekenen we straks
     opnieuw, zodat zijn knopje er staat zodra het bij de tobbe is (hooguit
     een paar keer, nooit een eindeloze lus) */
  if (S.stap === 'baden' && (S.tel || 0) < 8) {
    var onderweg = moetNogInBad().some(function (g) {
      var d = C.wereld.dier(g.id);
      return !d || d.kamer !== 'tuin';
    });
    if (onderweg) {
      S.tel = (S.tel || 0) + 1;
      straks(900, function () { if (C && S && S.stap === 'baden') teken(); });
    }
  }
  C.wereld.vuil();
}

/* het dier zelf is sleepbaar: van het gras zó de tobbe in */
function dierSleep(id) {
  var el = document.querySelector('[data-hot="tb_dier' + id + '"]');
  if (!el || el.__tobsleep) return;
  el.__tobsleep = 1;
  C.sleep(el, {
    dropSel: '[data-drop="tobbe"]',
    ghostHTML: function () {
      var g = C.state.gast(id);
      return '<div style="font-size:30px">' + (g ? ico(g) : '🐾') + '</div>';
    },
    onDrop: function (t) { inBad(id, doelVan(t)); },
    onTap: function () { volgendeInBad(-1); }
  });
}

function volgendeInBad(i) {
  var w = wachtenden();
  if (!w.length) return;
  if (i === undefined || i === null || i < 0) {
    /* geen tobbe aangewezen: pak de leegste */
    i = 0;
    for (var j = 1; j < S.M; j++) if (S.inbad[j].length < S.inbad[i].length) i = j;
  }
  inBad(w[0].id, i);
}

function inBad(id, i) {
  if (!S || S.stap !== 'baden' || !id) return;
  if (i === 'kan' || i === null || i === undefined) return;
  i = i | 0;
  if (!(i >= 0 && i < S.M)) return;
  if (inBadIds().indexOf(id) >= 0) return;
  if (S.inbad[i].length >= 2) {
    C.snd.zacht();
    zeg({ icoon: '🛁', getal: 2, tekst: 'zit vol' });
    teken();
    return;
  }
  var g = C.state.gast(id);
  if (!g) return;
  S.inbad[i].push(id);
  var p = P[i];
  C.wereld.reis(id, 'tuin', { x: Math.max(12, p.x - 7), z: p.z + 7, na: 'blij' });
  C.wereld.setMood(id, 'bouncy');
  if (g.behoefte === 'bad') {
    /* Eerst het taakje afvinken (dat is ook de ster voor deze ronde), DAARNA
       pas de wens afmelden. behoefteKlaar tekent het prikbord meteen opnieuw,
       en een kaartje dat op dat moment nog niet is afgevinkt zou zonder
       vinkje van het bord verdwijnen - dan mist het kind zijn succesje. */
    ster();
    C.wereld.behoefteKlaar(id, 'bad');   /* zet g.blij en werkt het bord bij */
    S.wens = 1;
  }
  g.waar = 'tuin';
  C.snd.plop(1);
  /* het praatje komt op de vaste boodschapplek boven de tobbes: hing het
     aan het dier zelf, dan zou het bij de linker tobbe half buiten het
     kader vallen (de laag klemt het dan tegen de rand) */
  zeg({ icoon: '😌', tekst: 'lekker warm', klas: 'goed' });
  straks(2600, function () {          /* het wolkje mag daarna weer weg */
    if (C && S && S.zeg && S.zeg.icoon === '😌') { zeg(null); teken(); }
  });
  bewaar();
  if (window.Hotel) Hotel.render();
  teken();
  if (S.wens && !moetNogInBad().length) straks(1200, klaarMetBaden);
}

function klaarMetBaden() {
  if (!S || S.stap !== 'baden' || !inBadIds().length) return;
  S.stap = 'af';
  zeg(null);
  ster();                       /* had een badgast al een ster? dan niet nog een */
  C.snd.hoera();
  bewaar();
  if (window.Hotel) Hotel.render();
  teken();
  straks(3200, function () { if (C && S && S.stap === 'af') C.sluit(); });
}

/* =====================================================================
   AANMELDEN
===================================================================== */
Games.register({
  id: 'tobbe',
  naam: 'Tobbe-tijd',
  kamer: 'tuin',
  hotspot: { obj: 'tobbe', icoon: '🛁', label: 'Tobbe', hoog: 12 },
  unlock: function (N) { return N >= 1; },
  stub: false,
  start: start,
  stop: stop,
  /* haakjes voor de speeltest (het hotel gebruikt ze niet) */
  proef: function (N, band, dag) { return recept(N, band, dag); },
  mv: mv,                             /* enkelvoud/meervoud naregenen */
  debug: function () { return S ? JSON.parse(JSON.stringify(S)) : null; },
  doe: function (wat, a, b) {          /* speeltest: tikken zonder muis */
    if (wat === 'schep') return schep(a, b === undefined ? 1 : b);
    if (wat === 'giet') return giet(a);
    if (wat === 'check') return check();
    if (wat === 'kraan') return kraantje();
    if (wat === 'leeg') return leeg();
    if (wat === 'hulp') return hulp();
    if (wat === 'bad') return volgendeInBad(a === undefined ? -1 : a);
    if (wat === 'klaar') return klaarMetBaden();
    return null;
  }
});
})();
