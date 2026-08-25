/* ---------------------------------------------------------------
   world.js - het diorama van de Kwispelsteeg.

   Eén isometrische scène (één canvas) in plaats van losse kaartjes:
   gras met plukjes, een houten hek, een boom, het hok, een tobbe, een
   bal, een kist en de voerbakjes STAAN in de wereld. De dieren wonen
   erin: ze wandelen van plek naar plek, snuffelen, gaan zitten en
   kijken rond. Bij het voeren loopt ieder dier naar zijn eigen bakje,
   eet het leeg (de brokjes slinken, er vliegen kruimels) en speelt
   daarna blij in de tuin.

   Techniek:
     * dezelfde voxel-motor als de dieren (Art.kit): zelfde licht,
       zelfde bak-cache, zelfde zachte contour.
     * de grond is één keer getekend op een achtergrond-canvas.
     * alles wat beweegt wordt per beeld op diepte gesorteerd
       (painter: klein x+z eerst) en als plaatje geblit.
     * de wereld denkt 15x per seconde en tekent ~30x per seconde,
       met vloeiende tussenstanden. Dat is rustig voor een tablet.
     * prefers-reduced-motion: iedereen blijft op zijn plek staan,
       geen gedwaal, geen deeltjes, één stilstaand beeld.

   Publiek:
     World.sync(dieren)         - wie wonen er (volgorde = bakje)
     World.setFood(id, niveau)  - 0..4 brokjes in het bakje
     World.feed(ids)            - lopen -> eten -> blij spelen
     World.mood(id, m)          - 'idle' | 'sad' | 'happy'
     World.solo(id, act)        - middagvignet: dit dier gaat iets doen
     World.debug()              - stand van zaken (voor de tests)
---------------------------------------------------------------- */
var World = (function () {
'use strict';

var K = Art.kit, S = K.S, HG = K.HG;

/* ---------- toeval met een eigen zaadje per dier ---------- */
function hash(s) {
  var h = 2166136261, i;
  for (i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}
function prng(seed) {
  var a = seed >>> 0;
  return function () {
    a = a + 0x6D2B79F5 | 0;
    var t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}
/* elke sessie een ander ritme, zodat het nooit hetzelfde filmpje is */
var ZAAD = (Date.now() >>> 3) & 0xffff;

/* =====================================================================
   DE TUIN - wereldcoördinaten in voxels.
   x loopt naar rechtsonder, z naar linksonder; scherm-x = (x-z)*S,
   scherm-y = (x+z)*S/2. Klein x+z = achteraan.
===================================================================== */
/* De tuin is zo groot gemaakt dat de dieren er ruim in passen: het decor
   beslaat ongeveer 360 voxel-px breed en 230 hoog, precies wat er bij
   G = kaderbreedte / 370 in beeld valt. INHOUD is die doos (in voxel-px);
   de camera zet hem netjes midden in het kader, welke vorm dat ook heeft. */
var INHOUD = [-170, 190, -10, 220];           /* wat er in het kader moet passen, in voxel-px */
var HEK_X = 10, HEK_Z = 10;                   /* de twee achterranden */
var BOOM = [16, 68], HOK = [67, 19], TOBBE = [32, 94], BAL = [120, 76], KIST = [95, 23];
/* De voerplek: één rij bakjes vóór in de tuin, om en om iets naar voren
   gezet. De rij staat altijd MIDDEN in beeld, ook met drie dieren, en de
   bakjes staan zo ver uit elkaar dat de dieren elkaar niet afdekken. */
function bakPlek(i, n) {
  var u = 13 + (i - (n - 1) / 2) * 32, w = 176 + (i % 2) * 24;
  return [(u + w) / 2, (w - u) / 2];
}
/* Dwaalplekken liggen allemaal ACHTER de voerrij (x+z <= 152), zodat een
   rondstruinend dier nooit over de bakjes heen komt te staan. */
var PLEKKEN = [[14, 62], [40, 22], [78, 18], [53, 67], [106, 44],
               [38, 102], [86, 66], [38, 70], [83, 39], [27, 35]];
/* dingen om aan te snuffelen: net naast het voorwerp gaan staan */
var SNUFFEL = [[30, 72], [79, 29], [45, 100], [104, 74], [61, 37], [55, 55], [95, 75]];
var ACT_PLEK = { Wandeling: [32, 74], Spelen: [104, 74],
                 Bad: [46, 100], Plonzen: [46, 100], Dierenarts: [60, 38] };

/* ---------- decorkleuren: warm hout, zacht gras ---------- */
var HOUT = '#D0A87A', HOUT_D = '#B98F62', STAM = '#B08A6A';
var BLAD = '#A6CE8E', BLAD_A = '#A9D08F', BLAD_B = '#B2D797';
var DAK = '#E79C7C', MUUR = '#F6E2C8', DEUR = '#8B6F5C';
var WATER = '#A9D8E6';
/* de tinten liggen dicht bij elkaar: een zacht deken van gras, geen schaakbord */
var GRAS = ['#AFD595', '#AAD190', '#B4D89A', '#ACD392'];
var WEI = ['#9DC486', '#98C081'];
var AARDE = ['#DCC7A6', '#D7C2A0'], PAD = ['#E1D0B0', '#DDCBAA'];

/* ---------- decorstukken: kleine voxelmodellen ---------- */
/* De kroon is een bosje van vijf kleine bollen in plaats van één grote.
   Eén grote bol geeft een bijna rechte zijkant, en daarop wordt elk
   trapje een lichte streep - dat leest als schuurpapier. Kleine bollen
   lopen schuin af: de trapjes worden bladtextuur in plaats van strepen. */
function pBoom() {
  var v = [], i;
  var kl = [BLAD_A, BLAD_B, BLAD, BLAD_B, BLAD_A];
  var bol = [[0, 29, 0, 8.5], [-8, 25, 5, 7], [7, 26, -6, 6.5], [1, 35, 2, 6.5], [-4, 32, -6, 5.5]];
  K.bx(v, -3, 0, -3, 7, 2, 7, STAM);
  K.bx(v, -2, 1, -2, 4, 21, 4, STAM);
  for (i = 0; i < bol.length; i++)
    K.ell(v, bol[i][0], bol[i][1], bol[i][2], bol[i][3], bol[i][3] * 0.92, bol[i][3], kl[i], { e: 2.2 });
  return v;
}
function pHok() {
  var v = [], j;
  K.bx(v, -11, 0, -10, 22, 17, 20, MUUR);
  for (j = 0; j < 9; j++) K.bx(v, -12 + j, 17 + j, -11, 24 - 2 * j, 1, 22, DAK);
  K.verf(v, 10, 10, 0, 11, -4, 4, DEUR);       /* deurgat in de voorkant */
  K.verf(v, 10, 10, 12, 12, -5, 5, HOUT_D);
  K.bx(v, -11, 0, -10, 22, 1, 20, HOUT_D);
  return v;
}
/* houten matje onder het voerbakje: maakt de voerplek leesbaar */
function pMat() {
  var v = [];
  K.bx(v, -8, 0, -8, 17, 1, 17, HOUT);
  K.verf(v, -8, 8, 0, 0, -8, -8, HOUT_D);
  K.verf(v, -8, 8, 0, 0, 8, 8, HOUT_D);
  K.verf(v, -8, -8, 0, 0, -8, 8, HOUT_D);
  K.verf(v, 8, 8, 0, 0, -8, 8, HOUT_D);
  return v;
}
function pHekX() {                              /* hekvak dat naar +x loopt */
  var v = [];
  K.bx(v, -1, 0, -1, 3, 13, 3, HOUT_D);
  K.bx(v, -2, 13, -2, 5, 1, 5, HOUT);
  K.bx(v, 1, 9, -1, 11, 2, 3, HOUT);
  K.bx(v, 1, 4, -1, 11, 2, 3, HOUT);
  return v;
}
function pHekZ() {                              /* hetzelfde, maar naar +z */
  var v = [];
  K.bx(v, -1, 0, -1, 3, 13, 3, HOUT_D);
  K.bx(v, -2, 13, -2, 5, 1, 5, HOUT);
  K.bx(v, -1, 9, 1, 3, 2, 11, HOUT);
  K.bx(v, -1, 4, 1, 3, 2, 11, HOUT);
  return v;
}
function pTobbe() {
  var v = [], x, z, q;
  for (x = -5; x <= 5; x++) for (z = -5; z <= 5; z++) {
    q = x * x + z * z;
    if (q > 27) continue;
    if (q > 15) { K.bx(v, x, 0, z, 1, 6, 1, HOUT); K.verf(v, x, x, 5, 5, z, z, HOUT_D); }
    else K.bx(v, x, 0, z, 1, 4, 1, WATER);
  }
  return v;
}
function pBal() {
  var v = [];
  K.ell(v, 0, 3.4, 0, 3.4, 3.4, 3.4, '#F5A8BE', { e: 2.0 });
  K.verf(v, -1, 1, 0, 7, -4, 4, '#FFF0C6');
  return v;
}
function pKist() {
  var v = [];
  K.bx(v, -4, 0, -4, 9, 8, 9, HOUT);
  K.verf(v, -4, 4, 3, 4, -4, 4, HOUT_D);
  K.bx(v, -5, 8, -5, 11, 1, 11, '#E2C094');
  return v;
}
function pPol(n) {                              /* plukje gras, soms met een bloemetje */
  var v = [], r = prng(4711 + n * 977), i, h, c;
  for (i = 0; i < 5 + (n % 3); i++) {
    h = 2 + Math.round(r() * 4);
    c = r() < 0.5 ? '#93C57E' : '#A8D48F';
    K.punt(v, Math.round(r() * 7 - 3), 0, Math.round(r() * 7 - 3), 2, h, 2, c);
  }
  if (n % 4 === 1) K.punt(v, 1, 0, 1, 2, 6, 2, r() < 0.5 ? '#F7C0D2' : '#FFE49B');
  return v;
}
var DECOR = { boom: pBoom, hok: pHok, hekx: pHekX, hekz: pHekZ,
              tobbe: pTobbe, bal: pBal, kist: pKist, mat: pMat };
function decorPlaat(naam, g) {
  return K.cache('w|' + naam + '|' + g, function () {
    return K.plaat(K.bake(DECOR[naam] ? DECOR[naam]() : pPol(+naam.slice(3))), g);
  });
}

/* ---------- de vaste voorwerpen op hun plek ---------- */
var decor = null;
function bouwDecor() {
  if (decor) return decor;
  var d = [], i, j, r = prng(90210);
  var groot = [{ n: 'boom', p: BOOM }, { n: 'hok', p: HOK }, { n: 'tobbe', p: TOBBE },
               { n: 'bal', p: BAL }, { n: 'kist', p: KIST }];
  for (i = 0; i < groot.length; i++) d.push({ n: groot[i].n, x: groot[i].p[0], z: groot[i].p[1] });
  /* het hek staat op de achterranden en hoort dus ALTIJD achter de tuin:
     met een gewone x+z-sortering schuift een lange lat soms vóór een dier */
  for (i = HEK_Z; i <= 130; i += 14) d.push({ n: 'hekz', x: HEK_X, z: i, ver: 1 });
  for (i = HEK_X + 14; i <= 130; i += 14) d.push({ n: 'hekx', x: i, z: HEK_Z, ver: 1 });
  /* plukjes gras: vaste, maar willekeurig ogende plekken, niet bovenop het decor */
  for (i = 0; i < 30; i++) {
    var u = Math.round(r() * 300 - 150), w = 24 + Math.round(r() * 220);
    var px = (u + w) / 2, pz = (w - u) / 2, vrij = px > HEK_X + 2 && pz > HEK_Z + 2;
    for (j = 0; j < groot.length && vrij; j++)
      if (Math.abs(px - groot[j].p[0]) + Math.abs(pz - groot[j].p[1]) < 22) vrij = false;
    for (j = 0; j < 5 && vrij; j++) {
      var bp = bakPlek(j, 5);
      if (Math.abs(px - bp[0]) + Math.abs(pz - bp[1]) < 26) vrij = false;
    }
    if (vrij) d.push({ n: 'pol' + (i % 5), x: px, z: pz });
  }
  for (i = 0; i < d.length; i++) d[i].d = d[i].x + d[i].z - (d[i].ver ? 1000 : 0);
  decor = d;
  return d;
}

/* =====================================================================
   DIEREN: elk met een eigen zaadje, tempo, staartritme en speelstijl
===================================================================== */
var BLIJ_STIJL = ['draai', 'hup', 'wiebel'];
/* Welk blijdansje welk dier doet, hangt aan de PLEK in het rijtje - niet
   aan een dobbelsteen per dier. Anders rolt het toeval er soms drie keer
   dezelfde dans uit en staat de hele tuin toch weer in de maat. Welke
   dans bij plek 0 hoort, wisselt wel per sessie. */
var STIJL_START = ZAAD % 3;
function stijlVan(i) { return BLIJ_STIJL[(i + STIJL_START) % BLIJ_STIJL.length]; }

function Dier(a, i) {
  var r = prng(hash(a.id) ^ ZAAD);
  this.id = a.id; this.kind = a.kind || 'hond'; this.naam = a.name || a.id;
  this.rnd = r;
  this.bak = i;
  this.fase = r() * 6.283;
  this.tempo = 0.78 + r() * 0.5;
  this.staartSnel = 0.16 + r() * 0.2;
  this.rustig = 0.6 + r() * 0.9;
  this.wandelKans = 0.34 + r() * 0.22;
  this.blijStijl = stijlVan(i);
  this.vmax = (this.kind === 'konijn' ? 1.5 : this.kind === 'gans' ? 1.0 : 1.3) * this.tempo;
  this.stapLengte = this.kind === 'konijn' ? 0.26 : this.kind === 'gans' ? 0.60 : 0.46;
  this.bobHoog = this.kind === 'konijn' ? 5.0 : this.kind === 'gans' ? 1.4 : 2.1;
  var p = PLEKKEN[(i * 3 + 1) % PLEKKEN.length];
  this.x = p[0]; this.z = p[1]; this.tx = this.x; this.tz = this.z;
  this.px = this.x; this.pz = this.z;            /* vorige stand, voor tussenbeelden */
  this.v = 0; this.gang = r() * 4; this.face = -1;
  this.staat = 'stil'; this.na = null; this.t = 0; this.duur = 10 + Math.floor(r() * 40);
  this.pose = 'rust'; this.bob = 0; this.zij = 0;
  this.flikT = 0; this.flikPose = 'tril';
  this.pluis = [];
}

Dier.prototype.zet = function (staat, duur, na) {
  this.staat = staat; this.t = 0; this.duur = duur || 0; this.na = na || null;
  if (staat !== 'loop') {
    this.v = 0;
    /* wie stilstaat draait meestal even naar de kijker: dan zie je het
       snuitje en de oogjes, en dat is precies wat een kind nodig heeft */
    if (this.rnd() < 0.8) this.face = 1;
  }
};
Dier.prototype.ga = function (tx, tz, na) {
  this.tx = tx; this.tz = tz; this.na = na || 'stil';
  this.staat = 'loop'; this.t = 0;
};

/* Afstand zoals je die op het SCHERM ziet. Twee dieren die 7 voxels naar
   voren en 7 naar rechts van elkaar staan, staan in isometrie bijna
   bovenop elkaar; in wereldcoördinaten lijkt dat juist ver. */
function beeldAf(x1, z1, x2, z2) {
  var dx = x1 - x2, dz = z1 - z2, a = (dx - dz) * S, b = (dx + dz) * (S / 2);
  return Math.sqrt(a * a + b * b);
}
/* een plek zoeken die op het scherm vrij ligt en niet te dichtbij is */
function vrijePlek(d) {
  var beste = null, bestD = -1, i, j, p, ver, ok, start = Math.floor(d.rnd() * PLEKKEN.length);
  for (i = 0; i < PLEKKEN.length; i++) {
    p = PLEKKEN[(i + start) % PLEKKEN.length];
    ok = true;
    for (j = 0; j < dieren.length; j++) {
      if (dieren[j] === d) continue;
      if (beeldAf(dieren[j].tx, dieren[j].tz, p[0], p[1]) < 74) { ok = false; break; }
    }
    if (!ok) continue;
    ver = beeldAf(d.x, d.z, p[0], p[1]);
    if (ver < 40) continue;                 /* niet drie stapjes verzetten */
    if (ver > bestD) { bestD = ver; beste = p; }
    if (d.rnd() < 0.45) break;              /* niet altijd de verste kiezen */
  }
  return beste || PLEKKEN[Math.floor(d.rnd() * PLEKKEN.length)];
}

Dier.prototype.kies = function () {
  var r = this.rnd(), w = this.wandelKans, p;
  if (r < w) { p = vrijePlek(this); this.ga(p[0], p[1], 'stil'); }
  else if (r < w + 0.17) { p = SNUFFEL[Math.floor(this.rnd() * SNUFFEL.length)]; this.ga(p[0], p[1], 'snuif'); }
  else if (r < w + 0.32) this.zet('zit', 24 + Math.floor(this.rnd() * 50));
  else if (r < w + 0.44) this.zet('kijk', 6 + Math.floor(this.rnd() * 12));
  else this.zet('stil', Math.round((12 + this.rnd() * 46) * this.rustig));
};

/* ---------- rijden met vaart maken en afremmen ---------- */
Dier.prototype.rijd = function () {
  var dx = this.tx - this.x, dz = this.tz - this.z;
  var d = Math.sqrt(dx * dx + dz * dz);
  if (d < 0.02) { this.v = 0; return true; }
  var acc = this.vmax / 5.5;
  var rem = this.v * this.v / (2 * acc) + this.vmax * 0.4;
  this.v += (d <= rem ? -acc * 1.5 : acc);
  if (this.v > this.vmax) this.v = this.vmax;
  if (this.v < this.vmax * 0.14) this.v = this.vmax * 0.14;
  var stap = Math.min(this.v, d);
  this.x += dx / d * stap; this.z += dz / d * stap;
  this.gang += stap * this.stapLengte;
  this.face = (dx - dz) >= 0 ? 1 : -1;
  var s = Math.abs(Math.sin(this.gang * Math.PI));
  this.bob = -s * this.bobHoog;
  if (this.kind === 'konijn') this.pose = s > 0.30 ? 'loopA' : 'loopB';
  else this.pose = (Math.floor(this.gang) % 2) ? 'loopB' : 'loopA';
  this.zij = this.kind === 'gans' ? Math.sin(this.gang * Math.PI) * 1.6 : 0;
  return stap >= d - 0.02;
};

/* ---------- stilstaan is nooit helemaal stil ---------- */
Dier.prototype.ademen = function () {
  var p = this.t * 0.085 + this.fase;
  this.bob = Math.sin(p) * 0.8 - 0.4;                       /* gewicht van poot naar poot */
  this.zij = Math.sin(p * 0.47 + 1.1) * 0.55;
  var q = Math.sin(this.t * this.staartSnel + this.fase * 2);
  this.pose = q > 0.22 ? 'zwaai' : 'rust';
  if (this.flikT > 0) { this.flikT--; this.pose = this.flikPose; }
  else if (this.rnd() < 0.035) {
    this.flikT = 1 + Math.floor(this.rnd() * 4);
    this.flikPose = this.rnd() < 0.55 ? 'tril' : 'kijk';    /* oortje / kopje omhoog */
  }
};

Dier.prototype.mijnBak = function () {
  var b = bakken[this.bak];
  return b ? [b.x, b.z] : bakPlek(0, 1);
};
Dier.prototype.eetPlek = function () {
  var b = this.mijnBak();
  return [b[0] - 13, b[1]];        /* snuit hangt dan net boven de brokjes */
};
/* Sip zit VÓÓR zijn bakje (dus dichter bij de kijker): daar kan geen
   ander dier hem afdekken en zie je meteen bij wélk bakje hij hoort. */
Dier.prototype.sipPlek = function () {
  var b = this.mijnBak();
  return [b[0] - 5, b[1] + 13];
};
Dier.prototype.bijBak = function () {
  var p = this.eetPlek();
  return Math.abs(this.x - p[0]) + Math.abs(this.z - p[1]) < 2.5;
};

Dier.prototype.pluisje = function (n, omhoog, kleur) {
  var i, b = this.mijnBak();
  var bx = omhoog ? this.x + 6 : b[0], bz = omhoog ? this.z : b[1];
  for (i = 0; i < n; i++) {
    this.pluis.push({
      x: bx + (this.rnd() - 0.5) * 5, z: bz + (this.rnd() - 0.5) * 5,
      y: omhoog ? 20 + this.rnd() * 8 : 6,
      vx: (this.rnd() - 0.5) * 1.4, vy: omhoog ? 0.5 + this.rnd() : 0.9 + this.rnd(),
      g: omhoog ? 0.03 : 0.14, t: omhoog ? 12 : 9, c: kleur, s: omhoog ? 1.7 : 1.2
    });
  }
};
Dier.prototype.pluisStap = function () {
  for (var i = this.pluis.length - 1; i >= 0; i--) {
    var q = this.pluis[i];
    q.x += q.vx; q.y += q.vy; q.vy -= q.g; q.t--;
    if (q.y < 0) q.y = 0;
    if (q.t <= 0) this.pluis.splice(i, 1);
  }
};

/* ---------- één hartslag van een dier (15x per seconde) ---------- */
Dier.prototype.tik = function () {
  this.px = this.x; this.pz = this.z;
  this.t++;
  this.pluisStap();
  var p, s;

  if (this.staat === 'loop') {
    if (this.rijd()) {
      if (this.na === 'eet') { this.zet('eet', 0); this.hap = 0; }
      else if (this.na === 'sip') { this.zet('sip', 0); this.face = 1; }
      else if (this.na === 'snuif') this.zet('snuif', 12 + Math.floor(this.rnd() * 20));
      else if (this.na === 'blij') this.zet('blij', 46 + Math.floor(this.rnd() * 34));
      else this.zet('stil', Math.round((10 + this.rnd() * 40) * this.rustig));
    }
    return;
  }

  if (this.staat === 'eet') {
    this.face = 1; this.zij = 0;
    this.hap = (this.hap || 0) + 1;
    var bak = bakken[this.bak] || { eten: 0 };
    if (this.hap % 5 === 0) {
      if (bak.eten > 0) { bak.eten--; this.pluisje(3, false, K.KOM.brok); vuil = true; }
    }
    s = this.hap % 5;
    this.pose = s < 2 ? 'hap1' : s < 4 ? 'hap2' : 'hap1';
    this.bob = s === 2 || s === 3 ? 1.5 : 0;
    if (bak.eten <= 0 && this.hap % 5 === 0) this.zet('blij', 50 + Math.floor(this.rnd() * 36));
    return;
  }

  if (this.staat === 'blij') {
    if (this.blijStijl === 'draai') {              /* rondjes draaien van blijdschap */
      if (this.t % 3 === 0) this.face = -this.face;
      this.pose = this.t % 6 < 3 ? 'blijA' : 'blijB';
      this.bob = -1.5 - Math.abs(Math.sin(this.t * 0.5)) * 2;
      this.zij = Math.sin(this.t * 0.52) * 1.6;
    } else if (this.blijStijl === 'hup') {         /* hoog springen */
      s = Math.abs(Math.sin(this.t * 0.42 + this.fase));
      this.bob = -s * 7.5;
      this.pose = s > 0.4 ? 'blijA' : 'blijB';
      this.zij = 0;
    } else {                                        /* met de billen wiebelen */
      this.pose = this.t % 4 < 2 ? 'blijA' : 'blijB';
      this.bob = -1 - Math.abs(Math.sin(this.t * 0.7)) * 1.4;
      this.zij = Math.sin(this.t * 0.85 + this.fase) * 2.6;
    }
    if (this.t % (9 + this.bak * 2) === 1) this.pluisje(2, true, this.rnd() < 0.5 ? '#FFE9A8' : '#FFF6EA');
    if (this.t >= this.duur) { this.zet('stil', 8 + Math.floor(this.rnd() * 20)); this.wandelKans = Math.min(0.62, this.wandelKans + 0.06); }
    return;
  }

  if (this.staat === 'sip') {                       /* zacht verdrietig bij het lege bakje */
    this.pose = 'zitsip';
    this.bob = this.t % 52 < 26 ? 0.6 : 0;
    this.zij = 0;
    return;
  }

  if (this.staat === 'snuif') {
    s = this.t % 8;
    this.pose = s < 5 ? 'snuif' : 'rust';
    this.bob = s < 5 ? 0.6 : 0;
    this.zij = Math.sin(this.t * 0.3 + this.fase) * 0.6;
    if (this.t >= this.duur) this.kies();
    return;
  }

  if (this.staat === 'zit') {
    this.pose = 'zit';
    this.bob = Math.sin(this.t * 0.06 + this.fase) * 0.5;
    this.zij = 0;
    if (this.flikT > 0) { this.flikT--; }
    else if (this.rnd() < 0.03) this.flikT = 2 + Math.floor(this.rnd() * 3);
    if (this.t >= this.duur) this.kies();
    return;
  }

  if (this.staat === 'kijk') {
    this.pose = this.t % 10 < 6 ? 'kijk' : 'rust';
    this.bob = -0.3;
    this.zij = Math.sin(this.t * 0.22 + this.fase) * 0.8;
    if (this.t >= this.duur) this.kies();
    return;
  }

  this.ademen();                                    /* 'stil' */
  if (this.t >= this.duur) this.kies();
};

/* met prefers-reduced-motion: één rustige houding, geen gedwaal */
Dier.prototype.stilzetten = function (pose) {
  this.staat = 'stil'; this.pose = pose || 'rust';
  this.bob = 0; this.zij = 0; this.v = 0; this.pluis.length = 0;
  this.px = this.x; this.pz = this.z;
  vuil = true;
};

/* =====================================================================
   CANVAS, CAMERA EN GROND
===================================================================== */
var host = null, cv = null, ctx = null, tagHost = null;
var W = 0, H = 0, g = 2, camX = 0, camY = 0, dpr = 1;
var achter = null, vuil = true, aan = false;
var dieren = [], bakken = [], rustModus = false, tonen = false;

function meet() {
  if (!host) return false;
  var r = host.getBoundingClientRect();
  if (r.width < 8 || r.height < 8) return false;
  dpr = Math.min(3, window.devicePixelRatio || 1);
  var nw = Math.max(240, Math.round(r.width * dpr)), nh = Math.max(180, Math.round(r.height * dpr));
  var ng = Math.max(2, Math.min(4, Math.round(nw / 370)));
  if (nw === W && nh === H && ng === g) return false;
  W = nw; H = nh; g = ng;
  cv.width = W; cv.height = H;
  cv.style.width = r.width + 'px'; cv.style.height = r.height + 'px';
  ctx.imageSmoothingEnabled = false;
  /* de camera zet het hele decor netjes midden in het kader, hoe hoog of
     breed dat kader ook uitvalt (46vh staand, vierkant liggend, ...) */
  camX = Math.round(W / 2 - (INHOUD[0] + INHOUD[1]) / 2 * g);
  camY = Math.round(H / 2 - (INHOUD[2] + INHOUD[3]) / 2 * g);
  achter = null;
  vuil = true;
  return true;
}

function tegel(c, u, w, kleur) {
  var x = camX + u * S * g, y = camY + w * (S / 2) * g;
  var bw = 2 * S * g + 1, bh = S * g + 0.5;
  c.fillStyle = kleur;
  c.beginPath();
  c.moveTo(x, y - bh); c.lineTo(x + bw, y); c.lineTo(x, y + bh); c.lineTo(x - bw, y);
  c.closePath(); c.fill();
}
/* afstand tot het wandelpaadje, in (u,w)-schermruimte */
var PADLIJN = [[48, 86], [10, 132], [-20, 184]];
function padAf(u, w) {
  var best = 1e9, i, a, b, dx, dy, t, qx, qy;
  for (i = 0; i < PADLIJN.length - 1; i++) {
    a = PADLIJN[i]; b = PADLIJN[i + 1];
    dx = b[0] - a[0]; dy = b[1] - a[1];
    t = ((u - a[0]) * dx + (w - a[1]) * dy) / (dx * dx + dy * dy);
    t = t < 0 ? 0 : t > 1 ? 1 : t;
    qx = a[0] + dx * t; qy = a[1] + dy * t;
    best = Math.min(best, Math.abs(u - qx) * 0.5 + Math.abs(w - qy));
  }
  return best;
}
function bouwGrond() {
  var c = K.canvas(W, H), cc = c.getContext('2d');
  var u0 = Math.floor((-camX / (S * g) - 8) / 4) * 4, u1 = (W - camX) / (S * g) + 8;
  var w0 = Math.floor((-camY / ((S / 2) * g) - 8) / 4) * 4, w1 = (H - camY) / ((S / 2) * g) + 8;
  var u, w, x, z, k, kl;
  cc.fillStyle = GRAS[1];
  cc.fillRect(0, 0, W, H);
  for (w = w0; w <= w1; w += 4) {
    for (u = u0; u <= u1; u += 4) {
      x = (u + w) / 2; z = (w - u) / 2;
      k = (Math.imul(x * 73856093 ^ z * 19349663, 2654435761) >>> 24);
      if (x < HEK_X || z < HEK_Z) kl = WEI[k & 1];                          /* wei achter het hek */
      else if (w > 156 && w < 244 && Math.abs(u) < 142) kl = AARDE[k & 1];  /* aangestampte voerplek */
      else if (padAf(u, w) < 13) kl = PAD[k & 1];                           /* paadje naar het hok */
      else kl = GRAS[k & 3];
      tegel(cc, u, w, kl);
    }
  }
  /* zachte rand: het diorama loopt naar de hoeken toe rustig weg */
  var vg = cc.createRadialGradient(W / 2, H * 0.55, Math.min(W, H) * 0.30,
                                   W / 2, H * 0.55, Math.max(W, H) * 0.72);
  vg.addColorStop(0, 'rgba(120,96,70,0)');
  vg.addColorStop(1, 'rgba(120,96,70,.20)');
  cc.fillStyle = vg;
  cc.fillRect(0, 0, W, H);
  return c;
}

/* =====================================================================
   TEKENEN: alles op diepte sorteren en blitten
===================================================================== */
function put(p, sx, sy) { ctx.drawImage(p.cv, Math.round(sx + p.dx), Math.round(sy + p.dy)); }
function putSpiegel(p, sx, sy, mx) {
  ctx.save();
  ctx.translate(mx, 0); ctx.scale(-1, 1);
  ctx.drawImage(p.cv, Math.round(sx + p.dx - mx), Math.round(sy + p.dy));
  ctx.restore();
}
function schermX(x, z) { return camX + (x - z) * S * g; }
function schermY(x, z) { return camY + (x + z) * (S / 2) * g; }

function grondschaduw(x, z, r) {
  ctx.save();
  ctx.globalAlpha = 0.17;
  ctx.fillStyle = '#6E5A4A';
  ctx.beginPath();
  ctx.ellipse(schermX(x, z), schermY(x, z), r * g, r * 0.5 * g, 0, 0, 6.2832);
  ctx.fill();
  ctx.restore();
}

function tekenDier(d, mengen) {
  var x = d.px + (d.x - d.px) * mengen, z = d.pz + (d.z - d.pz) * mengen;
  var a = K.dierAnker;
  var ox = ((x - a[0]) - (z - a[1])) * S * g + d.zij * g;
  var oy = ((x - a[0]) + (z - a[1])) * (S / 2) * g + d.bob * g;
  var p = K.dier(d.kind, d.pose, g);
  if (d.face < 0) putSpiegel(p, camX + ox, camY + oy, schermX(x, z) + d.zij * g);
  else put(p, camX + ox, camY + oy);
}
function tekenPluis(d) {
  var i, q, m;
  for (i = 0; i < d.pluis.length; i++) {
    q = d.pluis[i];
    m = Math.max(2, Math.round(q.s * g));
    ctx.globalAlpha = Math.min(1, q.t / 6);
    ctx.fillStyle = q.c;
    ctx.fillRect(Math.round(schermX(q.x, q.z)), Math.round(schermY(q.x, q.z) - q.y * HG * g), m, m);
  }
  ctx.globalAlpha = 1;
}
function tekenBak(b, deel) {
  var a = K.komAnker;
  var ox = ((b.x - a[0]) - (b.z - a[1])) * S * g;
  var oy = ((b.x - a[0]) + (b.z - a[1])) * (S / 2) * g;
  /* eerst het houten matje, dan de achterkant van het bakje */
  if (deel === 0) put(decorPlaat('mat', g), schermX(b.x, b.z), schermY(b.x, b.z));
  put(K.kom(b.eten, g, deel), camX + ox, camY + oy);
}

var lijst = [];
function teken(mengen) {
  if (!ctx || !W) return;
  if (!achter) achter = bouwGrond();
  ctx.clearRect(0, 0, W, H);
  ctx.drawImage(achter, 0, 0);

  var i, d, dd = bouwDecor();
  /* schaduwen eerst: ze liggen allemaal plat op het gras */
  for (i = 0; i < dieren.length; i++) {
    d = dieren[i];
    grondschaduw(d.px + (d.x - d.px) * mengen, d.pz + (d.z - d.pz) * mengen,
                 d.staat === 'zit' || d.staat === 'sip' ? 7 : 8);
  }

  lijst.length = 0;
  for (i = 0; i < dd.length; i++) lijst.push(dd[i]);
  for (i = 0; i < bakken.length; i++) {
    var b = bakken[i];
    var eter = null, j;
    for (j = 0; j < dieren.length; j++)
      if (dieren[j].bak === i && dieren[j].staat === 'eet') eter = dieren[j];
    lijst.push({ bak: b, eter: eter, d: b.x + b.z });
  }
  for (i = 0; i < dieren.length; i++) {
    d = dieren[i];
    if (d.staat === 'eet') continue;              /* die wordt bij zijn bakje getekend */
    lijst.push({ dier: d, d: d.px + d.pz + (d.x + d.z - d.px - d.pz) * mengen });
  }
  lijst.sort(function (p, q) { return p.d - q.d; });

  for (i = 0; i < lijst.length; i++) {
    var it = lijst[i];
    if (it.n) put(decorPlaat(it.n, g), schermX(it.x, it.z), schermY(it.x, it.z));
    else if (it.bak) {
      if (it.eter) { tekenBak(it.bak, 0); tekenDier(it.eter, mengen); tekenBak(it.bak, 1); }
      else { tekenBak(it.bak, 0); tekenBak(it.bak, 1); }
    } else tekenDier(it.dier, mengen);
  }
  for (i = 0; i < dieren.length; i++) if (dieren[i].pluis.length) tekenPluis(dieren[i]);
  naamplaatjes(mengen);
}

/* ---------- naamkaartjes: echte tekst boven het dier ---------- */
var tagPlek = [];
function naamplaatjes(mengen) {
  if (!tagHost) return;
  var i, j, d, el, sx, sy, sc = dpr;
  tagPlek.length = 0;
  for (i = 0; i < dieren.length; i++) {
    d = dieren[i];
    el = d.tag;
    if (!el) {
      el = d.tag = document.createElement('span');
      el.className = 'wtag';
      el.textContent = d.naam;
      tagHost.appendChild(el);
    }
    var x = d.px + (d.x - d.px) * mengen, z = d.pz + (d.z - d.pz) * mengen;
    sx = schermX(x, z) / sc;
    sy = (schermY(x, z) - (30 * HG + 8) * g + d.bob * g) / sc;
    /* twee kaartjes over elkaar is onleesbaar: schuif er dan één omhoog */
    for (var poging = 0; poging < 6; poging++) {
      var raak = false;
      for (j = 0; j < tagPlek.length; j++) {
        if (Math.abs(tagPlek[j][0] - sx) < 62 && Math.abs(tagPlek[j][1] - sy) < 24) { sy = tagPlek[j][1] - 26; raak = true; }
      }
      if (!raak) break;
    }
    tagPlek.push([sx, sy]);
    el.style.transform = 'translate(-50%,-100%) translate(' + sx.toFixed(1) + 'px,' + sy.toFixed(1) + 'px)';
  }
}

/* =====================================================================
   DE LUS: 15x per seconde denken, ~30x per seconde tekenen
===================================================================== */
var STAP = 1000 / 15, TEKEN = 1000 / 31;
var vorigeTik = 0, vorigeTeken = 0, restTijd = 0;

function lus(nu) {
  requestAnimationFrame(lus);
  if (!tonen || !host || !host.isConnected) return;
  if (meet()) vuil = true;
  if (!W) return;

  if (!rustModus) {
    if (!vorigeTik) vorigeTik = nu;
    var n = 0;
    while (nu - vorigeTik >= STAP && n < 3) {
      vorigeTik += STAP;
      for (var i = 0; i < dieren.length; i++) dieren[i].tik();
      vuil = true; n++;
    }
    if (nu - vorigeTik > STAP * 6) vorigeTik = nu;
    restTijd = Math.max(0, Math.min(1, (nu - vorigeTik) / STAP));
  } else restTijd = 1;

  if (!vuil && nu - vorigeTeken < 400) return;
  if (nu - vorigeTeken < TEKEN) return;
  vorigeTeken = nu;
  teken(rustModus ? 1 : restTijd);
  if (rustModus) vuil = false;
}

/* =====================================================================
   PUBLIEK
===================================================================== */
function heeft(id) {
  for (var i = 0; i < dieren.length; i++) if (dieren[i].id === id) return true;
  return false;
}
function vind(id) {
  for (var i = 0; i < dieren.length; i++) if (dieren[i].id === id) return dieren[i];
  return null;
}

function sync(lijstDieren) {
  var oud = dieren, i, j, d, nieuw = [];
  for (i = 0; i < lijstDieren.length; i++) {
    d = null;
    for (j = 0; j < oud.length; j++) if (oud[j].id === lijstDieren[i].id) d = oud[j];
    if (!d) d = new Dier(lijstDieren[i], i);
    else if (d.tag) d.tag.textContent = d.naam;
    d.bak = i;
    d.blijStijl = stijlVan(i);
    nieuw.push(d);
  }
  for (i = 0; i < oud.length; i++)
    if (nieuw.indexOf(oud[i]) < 0 && oud[i].tag && oud[i].tag.parentNode)
      oud[i].tag.parentNode.removeChild(oud[i].tag);
  dieren = nieuw;
  bakken = [];
  for (i = 0; i < dieren.length; i++) {
    var bp = bakPlek(i, dieren.length);
    bakken.push({ x: bp[0], z: bp[1], eten: 0 });
  }
  if (rustModus) for (i = 0; i < dieren.length; i++) dieren[i].stilzetten('rust');
  vuil = true;
}

function setFood(id, niveau) {
  var d = vind(id);
  if (!d || !bakken[d.bak]) return;
  if (d.staat === 'eet') return;                 /* niet ingrijpen tijdens het smullen */
  bakken[d.bak].eten = niveau;
  vuil = true;
}

function feed(ids) {
  (ids || []).forEach(function (id) {
    var d = vind(id);
    if (!d) return;
    if (rustModus) { d.stilzetten('blijA'); if (bakken[d.bak]) bakken[d.bak].eten = 0; return; }
    var p = d.eetPlek();
    d.ga(p[0], p[1], 'eet');
    d.hap = 0;
  });
  vuil = true;
}

function mood(id, m) {
  var d = vind(id);
  if (!d) return;
  if (m === 'sad') {
    if (rustModus) { var q = d.sipPlek(); d.x = q[0]; d.z = q[1]; d.face = 1; d.stilzetten('zitsip'); return; }
    if (d.staat === 'sip' || (d.staat === 'loop' && d.na === 'sip')) return;
    var p = d.sipPlek();
    d.ga(p[0], p[1], 'sip');
  } else if (m === 'happy') {
    if (rustModus) { d.stilzetten('blijA'); return; }
    if (d.staat !== 'eet' && d.staat !== 'blij') d.zet('blij', 50 + Math.floor(d.rnd() * 30));
  } else {
    if (rustModus) { d.stilzetten('rust'); return; }
    if (d.staat === 'sip') d.kies();
  }
  vuil = true;
}

/* middagvignet: dit dier gaat op de goede plek zijn ding doen */
function solo(id, act) {
  var d = vind(id);
  if (!d) return;
  var p = ACT_PLEK[act] || PLEKKEN[0];
  if (rustModus) { d.x = p[0]; d.z = p[1]; d.stilzetten('blijA'); return; }
  d.ga(p[0], p[1], 'blij');
  vuil = true;
}

function toon(ja) {
  tonen = !!ja;
  if (host) host.classList.toggle('uit', !tonen);
  if (tonen) { vuil = true; vorigeTik = 0; }
}

function debug() {
  var o = { rustig: rustModus, tonen: tonen, g: g, canvas: [W, H], dieren: {}, bakken: [] };
  for (var i = 0; i < dieren.length; i++) {
    var d = dieren[i];
    o.dieren[d.id] = { staat: d.staat, pose: d.pose, naam: d.naam, bak: d.bak,
                       x: Math.round(d.x * 10) / 10, z: Math.round(d.z * 10) / 10,
                       bijBak: d.bijBak(), face: d.face, stijl: d.blijStijl,
                       pluis: d.pluis.length, doel: [d.tx, d.tz] };
  }
  for (i = 0; i < bakken.length; i++) o.bakken.push(bakken[i].eten);
  return o;
}

function begin() {
  if (aan) return;
  host = document.getElementById('world');
  cv = document.getElementById('worldCv');
  tagHost = document.getElementById('worldTags');
  if (!host || !cv) return;
  ctx = cv.getContext('2d');
  ctx.lineWidth = 1; ctx.lineJoin = 'bevel';
  try { rustModus = !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches); }
  catch (e) { rustModus = false; }
  aan = true;
  host.classList.toggle('uit', !tonen);
  meet();
  Art.wereld(api);
  window.addEventListener('resize', function () { vuil = true; });
  window.addEventListener('orientationchange', function () { vuil = true; });
  requestAnimationFrame(lus);
}

var api = { sync: sync, setFood: setFood, feed: feed, mood: mood, solo: solo,
            heeft: heeft, toon: toon, debug: debug,
            klaar: function () { return aan; } };

/* de scripttags staan onderaan de body, dus #world bestaat hier al;
   lukt dat niet, dan wachten we netjes op DOMContentLoaded */
begin();
if (!aan) {
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', begin);
  else begin();
}

return api;
})();
