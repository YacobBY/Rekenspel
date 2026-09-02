/* ---------------------------------------------------------------
   state.js - de stand van het hotel + alle rekengetallen.

   Eén schaalregel (HOTEL.md 3): N = het aantal gasten bepaalt hoe
   GROOT de getallen zijn, het adaptieve signaal bepaalt hoe MOEILIJK
   ze mogen worden. Nooit het tempo: er staat geen klok op je vingers.

   Wat hier bevroren is (ongewijzigd overgenomen uit de geteste
   Kwispelsteeg-demo, want die sommen zijn nagerekend en gespeeld):
     koekjesSom()        - eerlijk delen met rest
     vergelijk()         - meer / minder / precies bij de check-in
     planbord-solver     - planOplossingen(), planFouten(), maakPlan()
                           (nog niet in gebruik; de dagplanner komt in
                           fase 3 op het prikbord)
---------------------------------------------------------------- */

/* =====================================================================
   GASTEN
===================================================================== */
function mkGast(id, naam, kind, soort, scoops, act, mins) {
  return { id: id, naam: naam, name: naam, kind: kind, soort: soort, scoops: scoops,
           act: act, mins: mins, kamer: null, bed: null, waar: 'receptie',
           nachten: 2, geslapen: 0, prijs: 1, behoefte: 'kamer', dagIn: 1 };
}

var GASTEN_POOL = [
  mkGast('boef',   'Boef',       'hond',   'puppy',  2, 'Wandeling', 30),
  mkGast('muis',   'Muis',       'poes',   'poes',   1, 'Spelen',    15),
  mkGast('wolkje', 'Wolkje',     'konijn', 'konijn', 1, 'Bad',       15),
  mkGast('gerrit', 'Gerrit',     'gans',   'gans',   2, 'Plonzen',   15),
  mkGast('pip',    'Pip',        'hond',   'puppy',  3, 'Wandeling', 30),
  mkGast('vlok',   'Vlok',       'poes',   'poes',   2, 'Spelen',    15),
  mkGast('stamp',  'Stampertje', 'konijn', 'konijn', 1, 'Bad',       15),
  mkGast('bikkel', 'Bikkel',     'hond',   'puppy',  2, 'Wandeling', 30),
  mkGast('pluis',  'Pluis',      'poes',   'poes',   1, 'Spelen',    15)
];

var FAMILIES = ['Van Dijk', 'De Groot', 'Bakker', 'Jansen', 'Visser', 'Mulder'];
var LIDWOORD = { puppy: 'de', poes: 'de', gans: 'de', konijn: 'het' };

/* Nederlandse bezits-s: apostrof alleen na een lange klinker, en na s/x/z alleen een apostrof */
function bezit(naam) {
  var l = naam.slice(-1).toLowerCase();
  if ('sxz'.indexOf(l) >= 0) return naam + "'";
  if ('aiouy'.indexOf(l) >= 0) return naam + "'s";
  return naam + 's';
}
function metLidwoord(a) { return (LIDWOORD[a.soort] || 'de') + ' ' + a.soort; }

var BEHOEFTE = {
  eten:   { icoon: '🍪', tekst: 'wil eten',      plek: 'bak' },
  kamer:  { icoon: '🛏', tekst: 'wil een bed',   plek: 'bed' },
  bad:    { icoon: '🛁', tekst: 'wil in de tobbe', plek: 'tobbe' },
  spelen: { icoon: '🧶', tekst: 'wil spelen',    plek: 'mand' }
};

var ACT_EMOJI = { Wandeling: '🦮', Spelen: '🧶', Bad: '🛁', Plonzen: '💦',
                  Dierenarts: '🩺', Bezoek: '👪', Voer: '📦', Klusje: '🧹' };
var ACT_KLEUR = { Wandeling: '#A9D3F0', Spelen: '#FFC7D9', Bad: '#A7DEC6', Plonzen: '#CBB8EA',
                  Dierenarts: '#FFD3C2', Bezoek: '#E6D3F5', Voer: '#CFE8C6', Klusje: '#FFE9B8' };
var ACT_LID = { Wandeling: 'de wandeling', Spelen: 'het spelen', Bad: 'het bad',
                Plonzen: 'het plonzen', Klusje: 'het klusje', Dierenarts: 'de dokter',
                Bezoek: 'het bezoek', Voer: 'de bezorging' };
function actLid(b) { return ACT_LID[b.act] || String(b.act).toLowerCase(); }
var NA_ACT = { Bad: 1, Plonzen: 1 };
var VOOR_ACT = { Wandeling: 1, Spelen: 1 };

var state = null;

/* alle bedden van het hotel, in vaste volgorde */
function alleBedden() {
  var uit = [];
  Rooms.lijst().forEach(function (r) {
    Rooms.slots(r.id, 'bed').forEach(function (s) { uit.push({ kamer: r.id, slot: s.id }); });
  });
  return uit;
}
function maxGasten() { return alleBedden().length; }

function newGame() {
  state = {
    v: 6,
    dag: 1,
    ronde: 'ochtend',
    munten: 0,
    sterren: 0,
    band: 3,
    kunnen: 3,
    signaal: [],
    gasten: [],
    wachtlijst: GASTEN_POOL.map(function (a) { return Object.assign({}, a); }),
    famIdx: 0,
    meubels: [],
    taken: [],
    brieven: [],
    scoops: 20,
    levering: 4,
    snoeppot: 0,
    checkin: null,
    rekening: null,
    uitcheck: [],
    kar: null,
    spel: {},          /* elk spelletje in games/ heeft hier zijn eigen laatje */
    gezien: {},
    kamerNu: 'receptie',
    dagBericht: null
  };
  herbereken();
}

/* ---------- gasten opzoeken ---------- */
function gastVan(id) {
  for (var i = 0; i < state.gasten.length; i++) if (state.gasten[i].id === id) return state.gasten[i];
  return null;
}
function aantalGasten() { return state ? state.gasten.length : 0; }
function bedVrij() {
  var b = alleBedden(), i, j, bezet;
  for (i = 0; i < b.length; i++) {
    bezet = false;
    for (j = 0; j < state.gasten.length; j++)
      if (state.gasten[j].kamer === b[i].kamer && state.gasten[j].bed === b[i].slot) bezet = true;
    if (!bezet) return b[i];
  }
  return null;
}
function bedVanGast(g) { return g && g.kamer ? { kamer: g.kamer, slot: g.bed } : null; }
function gastInBed(kamer, slot) {
  for (var i = 0; i < state.gasten.length; i++)
    if (state.gasten[i].kamer === kamer && state.gasten[i].bed === slot) return state.gasten[i];
  return null;
}
function gastenIn(kamerId) {
  return state.gasten.filter(function (g) { return g.waar === kamerId; });
}

/* de volgende gast van de wachtlijst; is die leeg, dan vullen we hem opnieuw */
function pakGast() {
  if (!state.wachtlijst.length) {
    state.wachtlijst = GASTEN_POOL.map(function (a) {
      return Object.assign({}, a, { id: a.id + '_d' + state.dag });
    });
  }
  var g = state.wachtlijst.shift();
  var bezet = {};
  state.gasten.forEach(function (q) { bezet[q.id] = 1; });
  var n = 2;
  while (bezet[g.id]) { g.id = g.id + '_' + n; n++; }
  return g;
}

function dagVerbruik() {
  return state.gasten.reduce(function (s, a) { return s + a.scoops; }, 0);
}

/* =====================================================================
   BEVROREN: EERLIJK DELEN  (uit de geteste demo, ongewijzigd)
===================================================================== */
var DEEL_PLAN = [
  { per: 4, rest: 0 },
  { per: 4, rest: 1 },
  { per: 3, rest: 2 },
  { per: 4, rest: 0 },
  { per: 3, rest: 1 },
  { per: 4, rest: 2 }
];

function koekjesSom(day, n) {
  var p = DEEL_PLAN[(day - 1) % DEEL_PLAN.length];
  var per = p.per, rest = p.rest;
  if (rest >= n) rest = n - 1;
  while (n * per + rest > 20 && per > 2) per--;
  return { per: per, rest: rest, total: n * per + rest };
}

/* =====================================================================
   BEVROREN: MEER / MINDER / PRECIES  (de check-invraag)
   drie eerlijke uitkomsten: soms is het namelijk precies genoeg
===================================================================== */
function vergelijk(v) {
  var tot = v.dagen * v.nieuw;
  if (tot > v.voorraad) return 'meer';
  if (tot < v.voorraad) return 'minder';
  return 'precies';
}

/* =====================================================================
   DE BAND: N bepaalt het getal, het adaptieve signaal begrenst het
===================================================================== */
function bandVanN(N) {
  if (N <= 3) return 3;
  if (N <= 6) return 4;
  return 5;
}

/* rollende accuratesse + twijfeltijd over de laatste ~10 items.
   goed/fout telt NOOIT voor sterren of toegang - alleen voor de maat
   van de volgende som. */
function tel(goed, ms) {
  if (!state) return;
  if (!state.signaal) state.signaal = [];
  state.signaal.push({ g: goed ? 1 : 0, t: Math.max(0, Math.min(20000, ms || 0)) });
  while (state.signaal.length > 10) state.signaal.shift();
  herbereken();
}
function signaalStand() {
  var sig = (state && state.signaal) || [];
  if (!sig.length) return { n: 0, acc: 1, twijfel: 0 };
  var g = 0, t = 0;
  sig.forEach(function (q) { g += q.g; t += q.t; });
  return { n: sig.length, acc: g / sig.length, twijfel: t / sig.length };
}
function herbereken() {
  if (!state) return;
  var s = signaalStand();
  if (s.n >= 6) {
    if (s.acc >= 0.8 && s.twijfel < 7000 && state.kunnen < 5) { state.kunnen++; state.signaal = []; }
    else if (s.acc < 0.5 && state.kunnen > 3) { state.kunnen--; state.signaal = []; }
  }
  state.band = Math.max(3, Math.min(bandVanN(aantalGasten()), (state.kunnen || 3) + 1));
  return state.band;
}

/* =====================================================================
   SOMMENFABRIEK - iedere minigame haalt zijn getallen hier op
===================================================================== */
var KSET = { 3: [1, 2, 3, 4], 4: [2, 3, 4, 5, 10], 5: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] };
var PLAFOND = { 3: 20, 4: 100, 5: 100 };

/* T = k * N + r, 0 <= r < k. Band 3 krijgt precies de bevroren
   koekjesSom (nagerekend, T <= 20); band 4 en 5 mogen k laten groeien,
   maar alleen binnen de tafels die bij die groep hóren:
   groep 4 kent alleen de tafels 1, 2, 3, 4, 5 en 10. */
function somDeel(N, band, dag) {
  N = Math.max(1, N | 0);
  band = band || 3;
  dag = dag || 1;
  var s = koekjesSom(dag, N);
  var k = s.per, r = s.rest;
  /* Vangnet buiten het bereik van de geteste demo. koekjesSom is gemaakt
     voor 3 t/m 5 dieren; bij 7 of meer dieren kan hij k = 2 met rest 2
     teruggeven, en dan is het delen niet meer eerlijk (r moet kleiner dan k
     zijn) en loopt de zak boven de 20 uit. De bandregel levert band 3 alleen
     bij N <= 3, dus voor élke bereikbare som verandert hier niets: t/m N = 6
     is deze uitkomst exact de bevroren koekjesSom. */
  if (r >= k) r = k - 1;
  while (k > 1 && k * N + r > 20) { k--; if (r > k - 1) r = k - 1; }
  if (band <= 3) return { T: k * N + r, k: k, r: r, band: 3 };
  var set = KSET[band] || KSET[4], plaf = PLAFOND[band] || 100, i, kand = [];
  for (i = 0; i < set.length; i++) {
    var kk = set[i];
    if (kk < k) continue;
    if (kk * N + Math.min(r, kk - 1) <= plaf) kand.push(kk);
  }
  if (!kand.length) kand = [k];
  var kk2 = kand[(dag + N) % kand.length];
  var r2 = Math.min(r, kk2 - 1);
  return { T: kk2 * N + r2, k: kk2, r: r2, band: band };
}

/* geld: hele euro's, altijd <= 20 per betaling (HOTEL.md 4).
   band 3: precies betalen; band 4: bedrag samenstellen;
   band 5: wisselgeld van een tientje of twintigje. */
function somGeld(band, nachten, prijs) {
  band = band || 3;
  var dag = state ? state.dag : 1;
  var kans = band <= 3 ? [1, 2] : band === 4 ? [1, 2, 5] : [2, 5];
  prijs = prijs || kans[dag % kans.length];
  nachten = nachten || (band <= 3 ? 2 : band === 4 ? 3 : 4);
  while (nachten * prijs > 20 && nachten > 1) nachten--;
  var totaal = nachten * prijs;
  /* groep 3: precies samen tellen. groep 4: bedrag samenstellen, de ene dag
     precies en de andere dag met een beetje wisselgeld. groep 5: altijd
     wisselgeld van een tientje of een twintigje (HOTEL.md 4). */
  var betaald = totaal;
  if (band === 4 && dag % 2 === 0 && totaal + 2 <= 20) betaald = totaal + 2;
  if (band >= 5) {
    while (totaal >= 20 && nachten > 1) { nachten--; totaal = nachten * prijs; }
    betaald = totaal < 10 ? 10 : 20;
  }
  return { nachten: nachten, prijs: prijs, totaal: totaal,
           betaald: betaald, wissel: betaald - totaal };
}

/* klok: hele uren -> kwartieren -> op de minuut + tijdsduur */
function somKlok(band) {
  var d = state ? state.dag : 1;
  var u = 7 + (d * 3) % 8;
  if (band <= 3) return { u: u, m: 0, stap: 60, tekst: u + ' uur' };
  if (band === 4) {
    var m = [0, 15, 30, 45][(d + u) % 4];
    return { u: u, m: m, stap: 15, tekst: u + ':' + (m < 10 ? '0' : '') + m };
  }
  var mm = (d * 7 + u * 5) % 60;
  return { u: u, m: mm, stap: 5, duur: 20 + (d % 4) * 10,
           tekst: u + ':' + (mm < 10 ? '0' : '') + mm };
}

/* Tafels binnen de band (HOTEL.md 3 + IDEAS.md valkuil #1):
     groep 3: nog geen tafels, alleen rijtjes t/m 20 (1, 2, 5 en 10)
     groep 4: ALLEEN de tafels 1, 2, 3, 4, 5 en 10, product t/m 100
     groep 5: alle tafels t/m 10
   De tweede factor wordt zo gekozen dat het product nooit boven het
   plafond van de band uitkomt: 10 x 5 = 50 hoort niet in groep 3. */
var TAFEL_SET = { 3: [1, 2, 5, 10], 4: [1, 2, 3, 4, 5, 10], 5: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] };
var TAFEL_MAX = { 3: 20, 4: 100, 5: 100 };
function somTafel(band) {
  band = band <= 3 ? 3 : band >= 5 ? 5 : 4;
  var set = TAFEL_SET[band], plaf = TAFEL_MAX[band];
  var d = state ? state.dag : 1, N = aantalGasten() || 2;
  var a = set[(d + N) % set.length];
  var maxB = Math.max(1, Math.min(10, Math.floor(plaf / a)));
  var b = 1 + (d * 3 + N) % maxB;
  return { a: a, b: b, uit: a * b, band: band, tafels: set, plafond: plaf };
}

var sommen = { deel: somDeel, geld: somGeld, klok: somKlok, tafel: somTafel,
               band: function () { return state ? state.band : 3; },
               N: aantalGasten };

/* =====================================================================
   ECONOMIE - sterren voor meedoen, munten uit het uitchecken
===================================================================== */
function geefSter(n, waarvoor) {
  state.sterren += (n || 1);
  state.laatsteSter = waarvoor || null;
  return state.sterren;
}
function geefMunt(n) {
  state.munten += (n || 0);
  return state.munten;
}

/* =====================================================================
   BRIEVEN
===================================================================== */
function nieuweBrief(a) {
  var fam = FAMILIES[state.famIdx % FAMILIES.length];
  state.famIdx++;
  var zinnen = [
    a.naam + ' heeft heerlijk geslapen in kamer ' + (a.kamer === 'kamer2' ? '2' : '1') + '.',
    a.naam + ' rende elke dag door de tuin en at netjes het bakje leeg.',
    a.naam + ' vond het bad het allerleukste van het hele hotel.',
    a.naam + ' lag het liefst bij het raam naar de vogels te kijken.'
  ];
  return {
    titel: 'Bedankje van familie ' + fam + ' 💌',
    tekst: 'Lieve hotelhouder,\n\n' + zinnen[state.famIdx % zinnen.length] +
           '\n\nDank je wel dat je zo goed voor ' + a.naam + ' hebt gezorgd. Het bed was zacht, het bakje vol en de rekening klopte precies.\n\nLiefs, familie ' + fam,
    dag: state.dag
  };
}

/* =====================================================================
   BEVROREN: DE PLANBORD-SOLVER
   Nog niet in gebruik: de dagplanner verhuist in fase 3 naar het
   prikbord. Ongewijzigd meegenomen zodat die som later exact hetzelfde
   rekent als in de geteste demo.
===================================================================== */
var CELLEN = 8;

var VASTE_AFSPRAKEN = [
  { act: 'Dierenarts', name: 'dokter Els', at: 4, cells: 1,
    tekst: 'Dokter Els komt om 15:00 langs voor de controle. Dat blokje staat vast.' },
  { act: 'Bezoek', name: 'een familie', at: 2, cells: 1,
    tekst: 'Om 14:30 komt er een familie kijken naar de dieren. Dat blokje staat vast.' },
  { act: 'Voer', name: 'de bezorger', at: 6, cells: 1,
    tekst: 'Om 15:30 wordt het nieuwe voer gebracht. Dat blokje staat vast.' },
  { act: 'Dierenarts', name: 'dokter Els', at: 3, cells: 2,
    tekst: 'Dokter Els komt om 14:45 en blijft een half uur. Dat blokje staat vast.' }
];

function dagRnd(zaad) {
  var a = (zaad * 2654435761 + 12345) >>> 0;
  return function () {
    a = (a * 1103515245 + 12345) >>> 0;
    return (a >>> 8) / 16777216;
  };
}

function blokCellen(plan, id) {
  for (var i = 0; i < plan.blokken.length; i++) if (plan.blokken[i].id === id) return plan.blokken[i].cells;
  return 1;
}
function blokVan(plan, id) {
  for (var i = 0; i < plan.blokken.length; i++) if (plan.blokken[i].id === id) return plan.blokken[i];
  return null;
}

function planFouten(plan, stand) {
  var fout = [], i, r, ta, tb;
  for (i = 0; i < plan.regels.length; i++) {
    r = plan.regels[i];
    if (r.soort !== 'na') continue;
    ta = stand[r.a]; tb = stand[r.b];
    if (ta === undefined || ta === null || tb === undefined || tb === null) continue;
    if (ta < tb + blokCellen(plan, r.b)) fout.push(r);
  }
  return fout;
}

function planOplossingen(plan, max) {
  var vrij = [], vast = 0, i, j, aantal = 0, eerste = null, stand = {};
  for (i = 0; i < plan.blokken.length; i++) {
    var b = plan.blokken[i];
    if (b.vast) { stand[b.id] = b.at; for (j = 0; j < b.cells; j++) vast |= 1 << (b.at + j); }
    else vrij.push(b);
  }
  max = max || 500;
  function loop(k, bezet) {
    if (aantal >= max) return;
    if (k >= vrij.length) {
      if (!planFouten(plan, stand).length) {
        aantal++;
        if (!eerste) { eerste = {}; for (var q in stand) eerste[q] = stand[q]; }
      }
      return;
    }
    var b = vrij[k], at, m, t;
    for (at = 0; at + b.cells <= CELLEN; at++) {
      m = 0;
      for (t = 0; t < b.cells; t++) m |= 1 << (at + t);
      if (m & bezet) continue;
      stand[b.id] = at;
      loop(k + 1, bezet | m);
      delete stand[b.id];
      if (aantal >= max) return;
    }
  }
  loop(0, vast);
  return { aantal: aantal, eerste: eerste };
}

function ordeTekst(na, voor) {
  var act = String(na.act).toLowerCase();
  if (NA_ACT[na.act] && VOOR_ACT[voor.act]) {
    return 'Eerst ' + actLid(voor) + ', dán ' + actLid(na) + ': ' + bezit(na.name) + ' ' + act +
      ' moet ná ' + actLid(voor) + ' van ' + voor.name + ' — anders is ' + na.name +
      ' meteen weer vies!';
  }
  return bezit(na.name) + ' ' + act + ' kan pas ná ' + actLid(voor) + ' van ' + voor.name + '.';
}

function maakPlan(dag, dieren, verzwak) {
  var rnd = dagRnd(dag * 7919 + dieren.length * 131 + verzwak);
  var blokken = dieren.map(function (a, i) {
    return { id: 'b' + i + '_' + a.id, animal: a.id, name: a.name || a.naam,
             act: a.act, mins: a.mins, cells: a.mins / 15, at: null, vast: false };
  });
  var regels = [];
  var wilVast = dag >= 2 && verzwak < 3;
  var wilOrde = dag >= 3 && verzwak < 2;
  var wilVol  = dag >= 4 && verzwak < 1;

  /* 1. het vaste blokje kiezen (verzwak 1 en 2 schuiven het op) */
  var vastCellen = 0, afspraak = null;
  if (wilVast) {
    afspraak = VASTE_AFSPRAKEN[(dag - 2 + verzwak) % VASTE_AFSPRAKEN.length];
    vastCellen = afspraak.cells;
  }

  /* 2. de dierblokken laten passen binnen wat er over is */
  var som = blokken.reduce(function (s, b) { return s + b.cells; }, 0);
  for (var i = 0; i < blokken.length && som > CELLEN - vastCellen; i++) {
    if (blokken[i].cells > 1) { som -= 1; blokken[i].cells = 1; blokken[i].mins = 15; }
  }
  if (som > CELLEN - vastCellen) { vastCellen = 0; afspraak = null; }
  if (afspraak) {
    blokken.push({ id: 'vast_' + afspraak.act, animal: null, name: afspraak.name,
                   act: afspraak.act, mins: afspraak.cells * 15, cells: afspraak.cells,
                   at: afspraak.at, vast: true });
    regels.push({ soort: 'vast', emoji: ACT_EMOJI[afspraak.act] || '📌',
                  tekst: afspraak.tekst, blok: 'vast_' + afspraak.act });
  }

  /* 3. een klusje erbij zodat de strook bijna vol loopt */
  if (wilVol) {
    var ruimte = CELLEN - vastCellen - som;
    var klus = Math.min(2, ruimte);
    if (klus >= 1) {
      blokken.push({ id: 'klus_dag', animal: null, name: 'Jij', act: 'Klusje',
                     mins: klus * 15, cells: klus, at: null, vast: false });
      som += klus;
      regels.push({ soort: 'vol', emoji: '🧹',
                    tekst: 'De kamers moeten vandaag ook schoon. Alles bij elkaar past nét — ' +
                           'er blijft bijna geen vakje over.' });
    }
  }

  /* 4. de ordeningsregel: eerst vies worden, dan in bad */
  if (wilOrde) {
    var na = null, voor = null;
    for (i = 0; i < blokken.length; i++) {
      var b = blokken[i];
      if (b.vast) continue;
      if (!na && NA_ACT[b.act]) na = b;
      else if (!voor && VOOR_ACT[b.act]) voor = b;
    }
    if (!na || !voor) {
      var los = blokken.filter(function (x) { return !x.vast; });
      if (los.length >= 2) {
        na = los[Math.floor(rnd() * los.length)];
        voor = los.filter(function (x) { return x !== na; })[0];
      }
    }
    if (na && voor && na !== voor) {
      regels.push({ soort: 'na', a: na.id, b: voor.id, emoji: NA_ACT[na.act] ? '🛁' : '⏱️',
                    tekst: ordeTekst(na, voor) });
    }
    /* 5. vanaf dag 6 een tweede ordeningsregel. Met twee regels én een
       volle strook blijven er maar een paar indelingen over - dan doet de
       plek van elk blokje echt iets. Een lus (a ná b én b ná a) kan niet
       ontstaan: we hergebruiken de twee blokjes van de eerste regel niet. */
    if (dag >= 6 && verzwak < 1 && na && voor) {
      var rest = blokken.filter(function (x) { return !x.vast && x !== na && x !== voor; });
      if (rest.length >= 2) {
        var tweede = rest[Math.floor(rnd() * rest.length)];
        var eerst = rest.filter(function (x) { return x !== tweede; })[0];
        regels.push({ soort: 'na', a: tweede.id, b: eerst.id, emoji: '⏱️',
                      tekst: 'En nog iets: ' + ordeTekst(tweede, eerst) });
      }
    }
  }

  return { blokken: blokken, regels: regels, gekozen: null, klaar: false,
           markeer: [], fout: null, pogingen: 0, dag: dag };
}

function planbord(dag, dieren) {
  for (var verzwak = 0; verzwak <= 5; verzwak++) {
    var plan = maakPlan(dag, dieren, verzwak);
    var opl = planOplossingen(plan, 400);
    if (opl.aantal > 0) {
      plan.oplossing = opl.eerste;
      plan.oplossingen = opl.aantal;
      plan.verzwakt = verzwak;
      plan.vrijeVakjes = CELLEN - plan.blokken.reduce(function (s, b) { return s + b.cells; }, 0);
      return plan;
    }
  }
  var kaal = maakPlan(1, dieren, 9);       /* laatste redmiddel: alleen inpassen */
  kaal.oplossingen = planOplossingen(kaal, 400).aantal;
  kaal.verzwakt = 9;
  kaal.vrijeVakjes = CELLEN - kaal.blokken.reduce(function (s, b) { return s + b.cells; }, 0);
  return kaal;
}

/* =====================================================================
   OPBERGEN - v6, met migratie van de oude Kwispelsteeg (v5)
===================================================================== */
var OPSLAG_SLEUTEL = 'kws-hotel-v6';
var OUDE_SLEUTEL = 'kws-spel-v5';
var startKeuze = false;

function bewaarSpel() {
  if (!startKeuze || !state) return;
  try {
    localStorage.setItem(OPSLAG_SLEUTEL, JSON.stringify({
      v: 6,
      s: {
        dag: state.dag, ronde: state.ronde, munten: state.munten, sterren: state.sterren,
        band: state.band, kunnen: state.kunnen, signaal: state.signaal,
        gasten: state.gasten, wachtlijst: state.wachtlijst, famIdx: state.famIdx,
        meubels: state.meubels, taken: state.taken, brieven: state.brieven,
        scoops: state.scoops, levering: state.levering, snoeppot: state.snoeppot,
        kar: state.kar, spel: state.spel, gezien: state.gezien, kamerNu: state.kamerNu,
        uitcheck: state.uitcheck,
        /* De gast die aan de balie staat is al van de wachtlijst gehaald.
           Zonder deze twee zou hij bij het afsluiten halverwege de check-in
           verdwijnen - en de wachtlijst één gast korter zijn. */
        nieuweGast: state.nieuweGast, checkin: state.checkin
      }
    }));
  } catch (e) {}
}

function wisSpel() {
  try { localStorage.removeItem(OPSLAG_SLEUTEL); } catch (e) {}
}

function vulAan(s) {
  var leeg = { dag: 1, ronde: 'ochtend', munten: 0, sterren: 0, band: 3, kunnen: 3,
               signaal: [], gasten: [], wachtlijst: [], famIdx: 0, meubels: [], taken: [],
               brieven: [], scoops: 20, levering: 4, snoeppot: 0, checkin: null,
               rekening: null, uitcheck: [], kar: null, spel: {}, gezien: {},
               kamerNu: 'receptie', dagBericht: null, nieuweGast: null, v: 6 };
  for (var k in leeg) if (s[k] === undefined || s[k] === null) s[k] = leeg[k];
  if (!s.wachtlijst.length) s.wachtlijst = GASTEN_POOL.map(function (a) { return Object.assign({}, a); });
  /* Half afgebroken check-in netjes rechtzetten: hoort er een gast bij, dan
     gaat de check-in door; is die kwijt, dan zet de gast weer vooraan op de
     wachtlijst. Er raakt dus nooit een gast zoek. */
  if (s.checkin && (!s.nieuweGast || s.nieuweGast.id !== s.checkin.gastId)) s.checkin = null;
  if (s.nieuweGast && !s.checkin) {
    s.wachtlijst.unshift(s.nieuweGast);
    s.nieuweGast = null;
  }
  s.gasten.forEach(function (g) {
    if (!g.naam) g.naam = g.name || g.id;
    if (!g.name) g.name = g.naam;
    if (!g.waar) g.waar = g.kamer || 'receptie';
    if (g.nachten === undefined) g.nachten = 2;
    if (g.geslapen === undefined) g.geslapen = 0;
    if (g.prijs === undefined) g.prijs = 1;
    if (!g.behoefte) g.behoefte = g.kamer ? 'eten' : 'kamer';
  });
  return s;
}

function leesSpel() {
  try {
    var r = localStorage.getItem(OPSLAG_SLEUTEL);
    if (!r) return null;
    var d = JSON.parse(r);
    if (!d || d.v !== 6 || !d.s) return null;
    return vulAan(d.s);
  } catch (e) { return null; }
}

/* de oude Kwispelsteeg-opvang (v5) mag mee naar het hotel:
   de dieren worden gasten die nog geen kamer hebben. */
function leesOudSpel() {
  try {
    var r = localStorage.getItem(OUDE_SLEUTEL);
    if (!r) return null;
    var d = JSON.parse(r);
    if (!d || d.v !== 5 || !d.s || !d.s.dieren || !d.s.dieren.length) return null;
    var o = d.s;
    var s = vulAan({
      dag: o.day || 1,
      ronde: 'ochtend',
      munten: 0,
      sterren: 0,
      brieven: (o.brieven || []).slice(),
      scoops: o.scoops === undefined ? 20 : o.scoops,
      levering: o.levering === undefined ? 4 : o.levering,
      snoeppot: o.snoeppot || 0,
      famIdx: o.famIdx || 0,
      gasten: o.dieren.map(function (a) {
        return Object.assign({}, mkGast(a.id, a.name || a.naam || a.id, a.kind, a.soort,
                                        a.scoops || 1, a.act, a.mins),
                             { kamer: null, bed: null, waar: 'receptie', behoefte: 'kamer' });
      }),
      wachtlijst: (o.pool || []).map(function (a) {
        return Object.assign({}, mkGast(a.id, a.name || a.id, a.kind, a.soort, a.scoops || 1, a.act, a.mins));
      }),
      gemigreerd: 1
    });
    return s;
  } catch (e) { return null; }
}
/* Let op: de oude opslag (kws-spel-v5) blijft staan. Die hoort bij de
   Kwispelsteeg-opvang zelf; die demo mag hier niets van merken. Zodra
   het hotel één keer bewaard heeft, wordt er niet meer naar gekeken. */

/* =====================================================================
   STATE - het luikje waarmee minigames de stand opvragen.
   (De losse functies hierboven blijven bestaan voor hotel.js.)
===================================================================== */
var State = {
  N: aantalGasten,
  band: function () { return state ? state.band : 3; },
  kunnen: function () { return state ? state.kunnen : 3; },
  dag: function () { return state ? state.dag : 1; },
  sommen: sommen,
  tel: tel,
  signaal: signaalStand,
  herbereken: herbereken,
  bandVanN: bandVanN,
  gasten: function () { return state ? state.gasten : []; },
  gast: gastVan,
  gastenIn: gastenIn,
  bedden: alleBedden,
  bedVrij: bedVrij,
  gastInBed: gastInBed,
  maxGasten: maxGasten,
  munten: function () { return state ? state.munten : 0; },
  sterren: function () { return state ? state.sterren : 0; },
  munt: geefMunt,
  ster: geefSter,
  bewaar: bewaarSpel,
  ruw: function () { return state; },
  gezien: function (k) { return !!(state && state.gezien && state.gezien[k]); },
  /* eigen laatje per spelletje; gaat automatisch mee in de opslag v6 */
  spelData: function (id) {
    if (!state) return {};
    state.spel = state.spel || {};
    state.spel[id] = state.spel[id] || {};
    return state.spel[id];
  },
  zetGezien: function (k) { if (state) { state.gezien = state.gezien || {}; state.gezien[k] = 1; } }
};
