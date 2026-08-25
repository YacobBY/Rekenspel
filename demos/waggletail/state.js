/* state.js - spelstatus + de rekensommen per dag */
var MAX_DIEREN = 5;

function mkAnimal(id, name, kind, soort, scoops, act, mins) {
  return { id: id, name: name, kind: kind, soort: soort, scoops: scoops,
           act: act, mins: mins, care: 0, adopted: false };
}

var START_DIEREN = [
  mkAnimal('boef',   'Boef',   'hond',   'puppy',  2, 'Wandeling', 30),
  mkAnimal('muis',   'Muis',   'poes',   'poes',   1, 'Spelen',    15),
  mkAnimal('wolkje', 'Wolkje', 'konijn', 'konijn', 1, 'Bad',       15)
];

/* dieren die bij de poort kunnen staan of gebracht worden */
var NIEUWE_DIEREN = [
  mkAnimal('pip',    'Pip',       'hond',   'puppy',  3, 'Wandeling', 30),
  mkAnimal('vlok',   'Vlok',      'poes',   'poes',   2, 'Spelen',    15),
  mkAnimal('stamp',  'Stampertje','konijn', 'konijn', 1, 'Bad',       15),
  mkAnimal('gerrit', 'Gerrit',    'gans',   'gans',   2, 'Plonzen',   15),
  mkAnimal('bikkel', 'Bikkel',    'hond',   'puppy',  2, 'Wandeling', 30),
  mkAnimal('pluis',  'Pluis',     'poes',   'poes',   1, 'Spelen',    15)
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

var ACT_EMOJI = { Wandeling: '🦮', Spelen: '🧶', Bad: '🛁', Plonzen: '💦',
                  Dierenarts: '🩺', Bezoek: '👪', Voer: '📦', Klusje: '🧹' };
var ACT_KLEUR = { Wandeling: '#A9D3F0', Spelen: '#FFC7D9', Bad: '#A7DEC6', Plonzen: '#CBB8EA',
                  Dierenarts: '#FFD3C2', Bezoek: '#E6D3F5', Voer: '#CFE8C6', Klusje: '#FFE9B8' };
/* 'de wandeling', 'het bad' - voor de regelkaartjes en de foutmelding */
var ACT_LID = { Wandeling: 'de wandeling', Spelen: 'het spelen', Bad: 'het bad',
                Plonzen: 'het plonzen', Klusje: 'het klusje', Dierenarts: 'de dokter',
                Bezoek: 'het bezoek', Voer: 'de bezorging' };
function actLid(b) { return ACT_LID[b.act] || String(b.act).toLowerCase(); }
/* activiteiten die eerst moeten (vies worden) en die daarna moeten (schoon) */
var NA_ACT = { Bad: 1, Plonzen: 1 };
var VOOR_ACT = { Wandeling: 1, Spelen: 1 };

var state = null;

function newGame() {
  state = {
    day: 1,
    phase: 'morning',
    dieren: START_DIEREN.map(function (a) { return Object.assign({}, a); }),
    pool: NIEUWE_DIEREN.map(function (a) { return Object.assign({}, a); }),
    famIdx: 0,
    scoops: 20,
    levering: 4,          // over hoeveel dagen komt nieuw voer
    brieven: [],
    poortDier: null,
    binnenkomst: null,    // dier dat morgenochtend gebracht wordt
    dagBericht: null,     // vriendelijk berichtje bovenaan de ochtend
    fedOk: false,
    plannedOk: false,
    snoeppot: 0,
    leverBericht: false,
    volleOpvang: false,
    vetBij: null,
    vrijSpel: false,
    morning: null, middag: null, avond: null, adoptie: null
  };
  kiesPoortDier();
}

/* haal het volgende dier uit de wachtlijst; is die leeg, dan vullen we hem opnieuw */
function pakDier() {
  if (state.pool.length === 0) {
    state.pool = NIEUWE_DIEREN.map(function (a) {
      return Object.assign({}, a, { id: a.id + '_d' + state.day });
    });
  }
  return state.pool.shift();
}

function kiesPoortDier() {
  state.poortDier = pakDier();
}

function dagVerbruik() {
  return state.dieren.reduce(function (s, a) { return s + a.scoops; }, 0);
}

/* ---- ochtend: eerlijk delen, som groeit rustig mee ---- */
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

function initMorning() {
  var n = state.dieren.length;
  var som = koekjesSom(state.day, n);
  var bowls = {};
  state.dieren.forEach(function (a) { bowls[a.id] = 0; });
  /* wie er 's ochtends is, kan vandaag een zorgdag verdienen */
  state.ochtendRoster = state.dieren.map(function (a) { return a.id; });
  state.morning = {
    total: som.total, per: som.per, rest: som.rest,
    bag: som.total, bowls: bowls, pot: 0,
    hand: 1, misses: 0, klaar: false, feedback: null, vetGezien: false
  };
}

/* =====================================================================
   MIDDAG - HET PLANBORD MET REGELS VAN DE DAG
   De strook blijft 14:00-16:00 in acht kwartieren. Wat erbij komt zijn
   echte beperkingen, zodat het uitmaakt WAAR je een blokje neerlegt:

     dag 1   : alles moet er alleen maar in passen (zoals eerst)
     dag 2 + : één vast blokje dat al staat en niet mag verschuiven
     dag 3 + : een ordeningsregel ("het bad moet ná de wandeling")
     dag 4 + : de strook loopt bijna vol, dus de ruimte is krap

   Iedere dag wordt gebouwd én daarna nagerekend: planOplossingen()
   loopt alle plaatsingen af. Is er geen oplossing, dan haalt de
   generator één regel weg en probeert opnieuw. Dag 1 zonder regels is
   altijd oplosbaar, dus de reeks eindigt gegarandeerd.
===================================================================== */
var CELLEN = 8;

/* vaste afspraken die op de strook al klaarstaan */
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

/* piepklein toevalletje dat per dag hetzelfde blijft, zodat een dag
   naspeelbaar is en de test dezelfde dag kan narekenen */
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

/* welke ordeningsregels worden overtreden bij deze plaatsing? */
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

/* alle geldige plaatsingen aflopen (max = stop na zoveel oplossingen) */
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

/* één kandidaat-dag bouwen. verzwak = hoeveel regels we laten vallen. */
function maakPlan(dag, dieren, verzwak) {
  var rnd = dagRnd(dag * 7919 + dieren.length * 131 + verzwak);
  var blokken = dieren.map(function (a, i) {
    return { id: 'b' + i + '_' + a.id, animal: a.id, name: a.name,
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
                    tekst: 'De hokken moeten vandaag ook schoon. Alles bij elkaar past nét — ' +
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

function ordeTekst(na, voor) {
  var act = String(na.act).toLowerCase();
  if (NA_ACT[na.act] && VOOR_ACT[voor.act]) {
    return 'Eerst ' + actLid(voor) + ', dán ' + actLid(na) + ': ' + bezit(na.name) + ' ' + act +
      ' moet ná ' + actLid(voor) + ' van ' + voor.name + ' — anders is ' + na.name +
      ' meteen weer vies!';
  }
  return bezit(na.name) + ' ' + act + ' kan pas ná ' + actLid(voor) + ' van ' + voor.name + '.';
}

/* de dag bouwen én narekenen; hij is altijd oplosbaar */
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

function initMiddag() {
  state.middag = planbord(state.day, state.dieren);
}

/* de stand van het bord: welk blokje staat waar */
function planStand(plan) {
  var s = {};
  plan.blokken.forEach(function (b) { if (b.at !== null) s[b.id] = b.at; });
  return s;
}

/* alleen voor de tests: is elke gegenereerde dag oplosbaar? */
function planAudit(tmDag) {
  var alles = START_DIEREN.concat(NIEUWE_DIEREN), uit = [], dag, n, i, dr;
  for (dag = 1; dag <= (tmDag || 10); dag++) {
    for (n = 3; n <= MAX_DIEREN; n++) {
      for (var v = 0; v < 3; v++) {
        dr = [];
        for (i = 0; i < n; i++) dr.push(Object.assign({}, alles[(i * 2 + v * 3 + dag) % alles.length],
                                                      { id: 'a' + i, name: 'Dier' + i }));
        var plan = planbord(dag, dr);
        var opl = planOplossingen(plan, 400);
        uit.push({ dag: dag, dieren: n, variant: v, oplossingen: opl.aantal,
                   regels: plan.regels.length, verzwakt: plan.verzwakt,
                   vast: plan.blokken.some(function (b) { return b.vast; }),
                   orde: plan.regels.some(function (r) { return r.soort === 'na'; }),
                   vrij: plan.vrijeVakjes, cellen: plan.blokken.reduce(function (s, b) { return s + b.cells; }, 0) });
      }
    }
  }
  return uit;
}

/* ---- avond: opname-vraag ---- */
function initAvond() {
  var samen = dagVerbruik();
  var extra = state.poortDier ? state.poortDier.scoops : 0;
  state.avond = {
    dier: state.poortDier,
    samen: samen, extra: extra, nieuw: samen + extra,
    dagen: state.levering, voorraad: state.scoops,
    stap: 1, fouten1: 0, fouten2: 0, invoer: '', keuze: null, weg: false
  };
}

function nieuweBrief(a) {
  var fam = FAMILIES[state.famIdx % FAMILIES.length];
  state.famIdx++;
  var zinnen = [
    a.name + ' heeft een eigen kussen bij de kachel en slaapt daar de hele middag.',
    a.name + ' rent elke dag door de tuin en eet netjes het bakje leeg.',
    a.name + ' is dol op onze dochter en volgt haar overal.',
    a.name + ' heeft een mandje bij het raam en kijkt naar de vogels.'
  ];
  return {
    titel: 'Brief van ' + bezit(a.name) + ' nieuwe familie 💌',
    tekst: 'Lieve dierenverzorger,\n\n' + zinnen[state.famIdx % zinnen.length] +
           '\n\nDank je wel dat je zo goed voor ' + a.name + ' hebt gezorgd. Je hebt het eten eerlijk verdeeld en de dagen fijn ingepland.\n\nLiefs, familie ' + fam,
    dag: state.day
  };
}

function klaarVoorAdoptie() {
  var kand = state.dieren.filter(function (a) { return a.care >= 2; });
  kand.sort(function (x, y) { return y.care - x.care; });
  return kand[0] || null;
}
