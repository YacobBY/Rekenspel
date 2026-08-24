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

var ACT_EMOJI = { Wandeling: '🦮', Spelen: '🧶', Bad: '🛁', Plonzen: '💦' };
var ACT_KLEUR = { Wandeling: '#A9D3F0', Spelen: '#FFC7D9', Bad: '#A7DEC6', Plonzen: '#CBB8EA' };

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

/* ---- middag: activiteitenblokken ---- */
function initMiddag() {
  var blokken = state.dieren.map(function (a, i) {
    return { id: 'b' + i + '_' + a.id, animal: a.id, name: a.name,
             act: a.act, mins: a.mins, cells: a.mins / 15, at: null };
  });
  var totaal = blokken.reduce(function (s, b) { return s + b.cells; }, 0);
  // altijd oplosbaar houden binnen 8 blokjes (14:00-16:00)
  for (var i = 0; i < blokken.length && totaal > 8; i++) {
    if (blokken[i].cells > 1) { totaal -= 1; blokken[i].cells = 1; blokken[i].mins = 15; }
  }
  state.middag = { blokken: blokken, gekozen: null, klaar: false };
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
