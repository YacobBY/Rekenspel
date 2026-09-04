/* ---------------------------------------------------------------
   world.js - het hotel als isometrische voxelwereld.

   Eén ruimte vult altijd het kader: we zoomen NOOIT uit, we verhuizen.
   Van kamer naar kamer schuift de camera in 300 ms door (kamer-camera,
   HOTEL.md 1). De voxelschaal g blijft een heel getal (2..4), dus de blokjes
   zijn nooit uitgerekt; past een kamer bij die schaal niet op het scherm,
   dan tekenen we het canvas op een hogere dichtheid en schaalt de css hem
   terug (zie maatVan).

   Techniek:
     * dezelfde voxelmotor als de dieren (Art.kit): zelfde licht,
       zelfde plaatjes-cache, zelfde zachte contour.
     * de vloer + de twee achterwanden van een kamer worden één keer
       gebakken op een eigen plaatje (per kamer, per schaal) en daarna
       alleen nog geblit - daarom kost het camera-schuiven niets.
     * alles wat ervoor staat wordt per beeld op diepte gesorteerd
       (painter: klein x+z eerst) en als plaatje geblit.
     * dieren BUITEN de kamer die je ziet, denken grof mee: ze lopen
       hun route af en komen door de deuren, maar er wordt niets
       getekend. Zo blijft één rAF-lus genoeg.
     * prefers-reduced-motion: iedereen blijft staan, geen deeltjes.

   Publiek:
     World.sync(gasten)          - wie wonen er (id, kind, naam, kamer)
     World.naar(kamer)           - camera naar die ruimte (300 ms)
     World.actief()              - welke ruimte staat in beeld
     World.zet(id, kamer, x, z)  - dier neerzetten (bij opslag laden)
     World.ga(id, x, z, na)      - loop in de eigen kamer naar (x,z)
     World.reis(id, kamer, doel) - loop door de deuren naar een kamer
     World.slaap(id, kamer, slot)- in bed leggen
     World.setFood(id, niveau)   - 0..4 brokjes in het bakje van de kamer
     World.setBak(kamer,slot,n)  - idem, maar per bakje
     World.feed(ids)             - lopen -> eten -> blij spelen
     World.mood(id, m)           - 'idle' | 'sad' | 'happy'
     World.solo(id, act)         - vignet: dit dier gaat iets doen
     World.dingZet(sleutel, o)   - los voorwerp (bv. de voerkar) verzetten
     World.dingPlek(sleutel)     - waar staat dat voorwerp
     World.decor(kamer, o, door) - los decor van een spel zetten/bijwerken
     World.decorWeg(kamer,id,door)  ... en weer weghalen
     World.decorLijst(kamer?)    - wat staat er los (kopieën)
     World.decorWisEigenaar(door)- alles van één eigenaar weg
     World.debug()               - stand van zaken (voor de tests)
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
var ZAAD = (Date.now() >>> 3) & 0xffff;

/* ---------- wandkleuren: hetzelfde licht als de voxels ---------- */
var W_L = '#DFC6A8', W_L2 = '#E9D4BA', W_R = '#EDD8BC', W_R2 = '#F5E5CE';
var W_TOP = '#FCF0DE', W_PLINT = '#C08F6B', GAT = '#7A6250', GAT_L = '#9C8168';
var GRAS1 = '#AAD190';

/* =====================================================================
   DIEREN
===================================================================== */
var BLIJ_STIJL = ['draai', 'hup', 'wiebel'];
var STIJL_START = ZAAD % 3;
function stijlVan(i) { return BLIJ_STIJL[(i + STIJL_START) % BLIJ_STIJL.length]; }

function Dier(a, i) {
  var r = prng(hash(a.id) ^ ZAAD);
  this.id = a.id; this.kind = a.kind || 'hond'; this.naam = a.name || a.naam || a.id;
  this.rnd = r;
  this.nr = i;
  this.kamer = a.kamer || 'receptie';
  this.fase = r() * 6.283;
  this.tempo = 0.78 + r() * 0.5;
  this.staartSnel = 0.16 + r() * 0.2;
  this.rustig = 0.6 + r() * 0.9;
  this.wandelKans = 0.34 + r() * 0.22;
  this.blijStijl = stijlVan(i);
  this.vmax = (this.kind === 'konijn' ? 1.5 : this.kind === 'gans' ? 1.0 : 1.3) * this.tempo;
  this.stapLengte = this.kind === 'konijn' ? 0.26 : this.kind === 'gans' ? 0.60 : 0.46;
  this.bobHoog = this.kind === 'konijn' ? 5.0 : this.kind === 'gans' ? 1.4 : 2.1;
  var p = Rooms.plekken(this.kamer);
  var q = p[(i * 3 + 1) % p.length];
  this.x = q[0]; this.z = q[1]; this.tx = this.x; this.tz = this.z;
  this.px = this.x; this.pz = this.z;
  this.v = 0; this.gang = r() * 4; this.face = -1;
  this.staat = 'stil'; this.na = null; this.t = 0; this.duur = 10 + Math.floor(r() * 40);
  this.pose = 'rust'; this.bob = 0; this.zij = 0; this.lift = 0;
  this.flikT = 0; this.flikPose = 'tril';
  this.route = null; this.eindDoel = null; this.bed = null;
  this.pluis = [];
  this.hoogte = 0;          /* voxels boven de vloer (omhoog = +); lift = -hoogte * HG */
  this.zwemT = 0;           /* eigen klok van de zwemhouding (deining, plonsjes) */
  this.opdracht = null;     /* lopende belofte van loopNaar/stappen (zie OPDRACHTEN) */
}

Dier.prototype.zet = function (staat, duur, na) {
  this.onderbreek(staat);
  this.staat = staat; this.t = 0; this.duur = duur || 0; this.na = na || null;
  if (staat !== 'loop') {
    this.v = 0;
    if (this.rnd() < 0.8) this.face = 1;
  }
};
Dier.prototype.ga = function (tx, tz, na) {
  this.onderbreek('loop');
  this.tx = tx; this.tz = tz; this.na = na || 'stil';
  this.staat = 'loop'; this.t = 0;
  this.lift = 0;
};

/* Afstand zoals je die op het SCHERM ziet. */
function beeldAf(x1, z1, x2, z2) {
  var dx = x1 - x2, dz = z1 - z2, a = (dx - dz) * S, b = (dx + dz) * (S / 2);
  return Math.sqrt(a * a + b * b);
}
function vrijePlek(d) {
  var P = Rooms.plekken(d.kamer);
  var beste = null, bestD = -1, i, j, p, ver, ok, start = Math.floor(d.rnd() * P.length);
  for (i = 0; i < P.length; i++) {
    p = P[(i + start) % P.length];
    ok = true;
    for (j = 0; j < dieren.length; j++) {
      if (dieren[j] === d || dieren[j].kamer !== d.kamer) continue;
      if (beeldAf(dieren[j].tx, dieren[j].tz, p[0], p[1]) < 66) { ok = false; break; }
    }
    if (!ok) continue;
    ver = beeldAf(d.x, d.z, p[0], p[1]);
    if (ver < 40) continue;
    if (ver > bestD) { bestD = ver; beste = p; }
    if (d.rnd() < 0.45) break;
  }
  return beste || P[Math.floor(d.rnd() * P.length)];
}

Dier.prototype.kies = function () {
  if (this.route && this.route.length) { volgendeStap(this); return; }
  var r = this.rnd(), w = this.wandelKans, p;
  if (r < w) { p = vrijePlek(this); this.ga(p[0], p[1], 'stil'); }
  else if (r < w + 0.17) { p = vrijePlek(this); this.ga(p[0], p[1], 'snuif'); }
  else if (r < w + 0.32) this.zet('zit', 24 + Math.floor(this.rnd() * 50));
  else if (r < w + 0.44) this.zet('kijk', 6 + Math.floor(this.rnd() * 12));
  else this.zet('stil', Math.round((12 + this.rnd() * 46) * this.rustig));
};

/* De stapmaat van dit dier in de kamer waar het nu is. De dieren zijn niet
   groter geworden, de kamers wel (K1: de vier speelkamers 1,5x). Zonder deze
   factor doet een gast anderhalf keer zo lang over een kamer; mét is het op
   het scherm precies dezelfde loop als vroeger (rooms.js, veld loop). */
function loopMaat(d) {
  var r = Rooms.get(d.kamer);
  return (r && r.loop) || 1;
}
/* maat = tempo-factor van een opdracht (1 = de gewone loop van de motor),
   verder = wat er NA dit punt nog te lopen is (doorglijden over de punten).
   Tempo schaalt de hele beweging in de TIJD: snelheid maal tempo, versnelling
   maal tempo^2 en een remweg in voxels die niet van het tempo afhangt. Dan
   duurt tempo 2 precies de helft en tempo 0,5 precies het dubbele. Met
   maat = 1 en verder = 0 rekent dit stuk exact zoals vroeger. */
Dier.prototype.rijd = function (maat, verder) {
  var dx = this.tx - this.x, dz = this.tz - this.z;
  var d = Math.sqrt(dx * dx + dz * dz);
  var m = maat > 0 ? maat : 1, na = verder > 0 ? verder : 0;
  if (d < 0.02) { if (!na) this.v = 0; return true; }
  var vmax = this.vmax * loopMaat(this) * m;
  var acc = vmax / 5.5 * m;
  var rem = this.v * this.v / (2 * acc) + vmax * 0.4 / m;
  this.v += (d + na <= rem ? -acc * 1.5 : acc);
  if (this.v > vmax) this.v = vmax;
  if (this.v < vmax * 0.14) this.v = vmax * 0.14;
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

Dier.prototype.ademen = function () {
  var p = this.t * 0.085 + this.fase;
  this.bob = Math.sin(p) * 0.8 - 0.4;
  this.zij = Math.sin(p * 0.47 + 1.1) * 0.55;
  var q = Math.sin(this.t * this.staartSnel + this.fase * 2);
  this.pose = q > 0.22 ? 'zwaai' : 'rust';
  if (this.flikT > 0) { this.flikT--; this.pose = this.flikPose; }
  else if (this.rnd() < 0.035) {
    this.flikT = 1 + Math.floor(this.rnd() * 4);
    this.flikPose = this.rnd() < 0.55 ? 'tril' : 'kijk';
  }
};

/* ---------- bakje van de kamer waarin dit dier staat ---------- */
function bakVan(d) {
  var s = Rooms.slots(d.kamer, 'bak')[0];
  return s ? bakken[d.kamer + '|' + s.id] : null;
}
Dier.prototype.mijnBak = function () {
  var b = bakVan(this);
  return b ? [b.x, b.z] : [Rooms.get(this.kamer) ? Rooms.get(this.kamer).w / 2 : 20, 20];
};
Dier.prototype.eetPlek = function () {
  var b = this.mijnBak();
  return [b[0] - 13, b[1] + (this.nr % 2 ? 7 : -7)];
};
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

/* ---------- route door de deuren ---------- */
function volgendeStap(d) {
  if (d.route && d.route.length) {
    var dp = Rooms.deur(d.kamer, d.route[0]);
    if (dp) { d.ga(dp.ix, dp.iz, 'deur'); return true; }
    d.route = null;
  }
  if (d.eindDoel) {
    var p = d.eindDoel;
    d.eindDoel = null;
    d.ga(p.x, p.z, p.na || 'stil');
    return true;
  }
  return false;
}
/* het dier is er: door de deur, aan het eten, of gewoon klaar */
Dier.prototype.aangekomen = function () {
  if (this.na === 'deur' && this.route && this.route.length) {
    var nieuw = this.route.shift();
    var terug = Rooms.deur(nieuw, this.kamer);
    this.kamer = nieuw;
    this.x = terug ? terug.ix : 10; this.z = terug ? terug.iz : 10;
    this.px = this.x; this.pz = this.z;
    if (!volgendeStap(this)) this.zet('stil', 8 + Math.floor(this.rnd() * 16));
    vuil = true;
    return;
  }
  /* Onderweg naar bed? Dan stapt het dier er nu in - wat er ook als 'na'
     bij de aankomst hoorde. Anders bleef een dier dat met een ander slotje
     (blij, wacht, stil) bij zijn bed aankwam NAAST het bed staan. */
  if (this.slaapDoel && this.slaapDoel.kamer === this.kamer) {
    var sd = this.slaapDoel;
    if (inBed(this, sd.kamer, sd.slot)) return;   /* inBed wist slaapDoel zelf */
    this.slaapDoel = null;                        /* bed weg: gewoon aankomen */
  }
  if (this.na === 'eet') { this.zet('eet', 0); this.hap = 0; }
  else if (this.na === 'sip') { this.zet('sip', 0); this.face = 1; }
  else if (this.na === 'wacht') { this.zet('wacht', 0); this.face = 1; }
  else if (this.na === 'snuif') this.zet('snuif', 12 + Math.floor(this.rnd() * 20));
  else if (this.na === 'blij') this.zet('blij', 46 + Math.floor(this.rnd() * 34));
  else if (this.na === 'slaap') { this.zet('slaap', 0); this.face = 1; }
  else this.zet('stil', Math.round((10 + this.rnd() * 40) * this.rustig));
};

/* ---------- één hartslag (15x per seconde), volledig getekend ---------- */
Dier.prototype.tik = function () {
  this.px = this.x; this.pz = this.z;
  this.t++;
  this.pluisStap();
  var s;

  if (this.opdracht || this.staat === 'zwem' || this.staat === 'spring') { this.opdrachtTik(); return; }
  if (this.staat === 'loop') {
    if (this.rijd()) this.aangekomen();
    return;
  }
  if (this.staat === 'eet') {
    this.face = 1; this.zij = 0;
    this.hap = (this.hap || 0) + 1;
    var bak = bakVan(this) || { eten: 0 };
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
    if (this.blijStijl === 'draai') {
      if (this.t % 3 === 0) this.face = -this.face;
      this.pose = this.t % 6 < 3 ? 'blijA' : 'blijB';
      this.bob = -1.5 - Math.abs(Math.sin(this.t * 0.5)) * 2;
      this.zij = Math.sin(this.t * 0.52) * 1.6;
    } else if (this.blijStijl === 'hup') {
      s = Math.abs(Math.sin(this.t * 0.42 + this.fase));
      this.bob = -s * 7.5;
      this.pose = s > 0.4 ? 'blijA' : 'blijB';
      this.zij = 0;
    } else {
      this.pose = this.t % 4 < 2 ? 'blijA' : 'blijB';
      this.bob = -1 - Math.abs(Math.sin(this.t * 0.7)) * 1.4;
      this.zij = Math.sin(this.t * 0.85 + this.fase) * 2.6;
    }
    if (this.t % (9 + this.nr * 2) === 1) this.pluisje(2, true, this.rnd() < 0.5 ? '#FFE9A8' : '#FFF6EA');
    if (this.t >= this.duur) { this.zet('stil', 8 + Math.floor(this.rnd() * 20)); this.wandelKans = Math.min(0.62, this.wandelKans + 0.06); }
    return;
  }
  if (this.staat === 'sip') {
    this.pose = 'zitsip';
    this.bob = this.t % 52 < 26 ? 0.6 : 0;
    this.zij = 0;
    return;
  }
  if (this.staat === 'slaap') {                     /* op de matras: rustig ademen */
    this.pose = 'lig';
    this.bob = Math.sin(this.t * 0.045) * 0.6;
    this.zij = 0;
    return;
  }
  if (this.staat === 'wacht') {                     /* wacht geduldig bij zijn plek */
    this.ademen();
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
  this.ademen();
  if (this.t >= this.duur) this.kies();
};

/* ---------- grof meedenken: dieren in een kamer die je niet ziet ----------
   Alleen plek en route; geen houdingen, geen deeltjes, niets getekend. */
Dier.prototype.grofTik = function () {
  this.t++;
  if (this.pluis.length) this.pluis.length = 0;
  if (this.opdracht || this.staat === 'zwem' || this.staat === 'spring') { this.opdrachtTik(); return; }
  if (this.staat === 'loop') {
    var dx = this.tx - this.x, dz = this.tz - this.z;
    var d = Math.sqrt(dx * dx + dz * dz);
    var vm = this.vmax * loopMaat(this);
    if (d < vm) { this.x = this.tx; this.z = this.tz; this.px = this.x; this.pz = this.z; this.aangekomen(); }
    else { this.x += dx / d * vm; this.z += dz / d * vm; this.px = this.x; this.pz = this.z; }
    return;
  }
  if (this.staat === 'eet') {
    var bak = bakVan(this);
    if (bak && bak.eten > 0) bak.eten = 0;
    this.zet('stil', 20);
    return;
  }
  if (this.staat === 'wacht' || this.staat === 'slaap' || this.staat === 'sip') return;
  if (this.t < this.duur) return;
  if (this.route && this.route.length) { volgendeStap(this); return; }
  if (this.rnd() < 0.5) { var p = vrijePlek(this); this.ga(p[0], p[1], 'stil'); }
  else this.zet('stil', 20 + Math.floor(this.rnd() * 40));
};

/* Ligt dit dier op DIT moment in zijn eigen bed? Alleen dan mag het blijven
   liggen als de wereld alles stilzet. */
Dier.prototype.inZijnBed = function () {
  if (this.staat !== 'slaap' || !this.bedPlek) return false;
  if (this.kamer !== this.bedPlek.kamer) return false;
  var s = Rooms.slot(this.bedPlek.kamer, this.bedPlek.slot);
  return !!s && this.x === s.x && this.z === s.z;
};
Dier.prototype.stilzetten = function (pose) {
  /* Een drijver blijft drijven: World.sync zet in rustmodus iedereen stil,
     maar wie in het bad ligt hoort daar te blijven (net als een slaper in
     zijn bed, hieronder). Wie het water uit moet, zet eerst lift op 0 - dat
     doen ga, reis, stappen en pose - of vraagt een andere houding dan rust. */
  if (this.staat === 'zwem' && this.lift > 0 && (!pose || pose === 'rust')) {
    this.drijf(false);
    this.pluis.length = 0; this.v = 0; this.px = this.x; this.pz = this.z;
    vuil = true;
    return;
  }
  this.onderbreek('stil');
  this.bob = 0; this.zij = 0; this.v = 0; this.pluis.length = 0;
  this.px = this.x; this.pz = this.z;
  /* Een slaper blijft slapen. In rustmodus zet elke World.sync (de bel, een
     bed geven, uitchecken) alles stil; zonder deze regel schoot een gast
     daar rechtop overeind terwijl hij 7 voxels boven zijn matras bleef
     hangen. Wie NIET in bed ligt, komt altijd met beide pootjes op de vloer. */
  if (this.inZijnBed()) { this.pose = 'lig'; vuil = true; return; }
  this.staat = 'stil'; this.pose = pose || 'rust';
  this.lift = 0;
  vuil = true;
};

/* =====================================================================
   OPDRACHTEN MET EEN BELOFTE (P1c): loopNaar / stappen / pose

   Een spel zegt "ga daarheen en zeg het als je er bent". Het dier krijgt
   dan een opdracht: een rij punten in zijn eigen kamer, een houding
   onderweg (lopen, zwem of spring), een tempo, en een perStap-haakje dat
   bij elke landing afgaat. De belofte wordt true zodra het laatste punt
   bereikt is en false zodra iets anders het dier overneemt (ga, zet, reis,
   slaap, feest, solo, mood, een nieuwe opdracht, uitchecken of een
   kamerwissel buitenom). Nooit een reject.

   Hoogte: d.hoogte telt in VOXELS OMHOOG (springer > 0, zwemmer < 0);
   d.lift is de tekenafstand in pixels OMLAAG, precies zoals bij het bed
   (matras = -MATRAS * HG). Dus lift = -hoogte * HG: de motor tekent met
   lift, de spellen en de tests lezen liever hoogte.
   Tijd rekent in TIKKEN van de motor (STAP = 1/15 s, aan de klok en niet
   aan de beeldjes), dus een sprong duurt op een trage telefoon net zo lang.
===================================================================== */
var POOT_HOOG = 7;                    /* art.js POOT: de pootjes zijn de onderste 7 lagen */
var ZWEM_DIEP = POOT_HOOG;            /* zo diep zakt een zwemmer: pootjes onder water, buik erop */
var SPRING_HOOG = { hond: 5, poes: 6, konijn: 7, gans: 4 };   /* top van de boog, in voxels */
var SPRING_TIKKEN = 6;                /* tikken in de lucht per sprong (bij tempo 1) */
var SQUASH = 3;                       /* tikken plat op de steen na de landing */
var ZWEM_KL = ['#E6F5FF', '#FFFFFF', '#CFE9FF'];
var OD_STAAT = ['stil', 'rust', 'zit', 'kijk', 'snuif', 'blij', 'wacht', 'sip', 'zwem', 'spring'];
var OD_STIL = { zit: 'zit', kijk: 'kijk', snuif: 'snuif', blij: 'blijA', sip: 'zitsip', wacht: 'rust' };
var OD_DUUR = { zit: 45, kijk: 30, snuif: 30, blij: 50 };

/* Wie een nieuwe toestand krijgt, laat zijn opdracht vallen (belofte false)
   en komt uit het water of uit de lucht met beide pootjes op de vloer.
   Alleen wie in bed gaat houdt zijn hoogte: inBed zet die zelf op de matras. */
Dier.prototype.onderbreek = function (staat) {
  var mijn = this.staat === 'zwem' || this.staat === 'spring';
  if (this.opdracht && !this.opdracht.zelf) { this.opdrachtStop(false); mijn = true; }
  if (!mijn) return;
  this.hoogte = 0; this.bob = 0;
  if (staat !== 'slaap') this.lift = 0;
};
Dier.prototype.opdrachtStop = function (ok) {
  var od = this.opdracht;
  if (!od) return;
  this.opdracht = null;
  od.klaar(!!ok);
};
Dier.prototype.opdrachtStart = function (punten, o, klaar) {
  o = o || {};
  /* Een LEGE lijst is geen bevel: meteen true en het dier niet aanraken (dus
     ook geen lopende opdracht, route, slaapDoel of hoogte weggooien - anders
     zette stappen(id, []) een gast die naar zijn bed loopt stil). */
  if (!punten.length) { klaar(true); return; }
  this.opdrachtStop(false);                        /* de vorige belofte valt eerst */
  this.route = null; this.eindDoel = null; this.slaapDoel = null;
  this.lift = 0; this.hoogte = 0; this.bob = 0;
  this.opdracht = { punten: punten, i: -1, kamer: this.kamer,
                    pose: o.pose === 'zwem' || o.pose === 'spring' ? o.pose : null,
                    tempo: o.tempo > 0 ? +o.tempo : 1, na: o.na || null,
                    perStap: typeof o.perStap === 'function' ? o.perStap : null,
                    klaar: klaar, wacht: 0, len: 1, zelf: false,
                    rest: odRestLijst(punten) };
  this.opdrachtVolgende();
  vuil = true;
};
/* rest[i] = wat er NA punt i nog te lopen is, langs het pad. Eén keer per
   opdracht gerekend (niet per tik): rijd remt daarmee alleen voor het
   LAATSTE punt af, dus een rij punten is één doorlopende glijbeweging. */
function odRestLijst(punten) {
  var rest = [], i, s = 0, dx, dz;
  rest[punten.length - 1] = 0;
  for (i = punten.length - 1; i > 0; i--) {
    dx = punten[i].x - punten[i - 1].x; dz = punten[i].z - punten[i - 1].z;
    s += Math.sqrt(dx * dx + dz * dz);
    rest[i - 1] = s;
  }
  return rest;
}
Dier.prototype.opdrachtVolgende = function () {
  var od = this.opdracht, p = od.punten[++od.i];
  od.len = Math.max(0.01, Math.sqrt((p.x - this.x) * (p.x - this.x) + (p.z - this.z) * (p.z - this.z)));
  od.zelf = true; this.ga(p.x, p.z, 'opdracht'); od.zelf = false;   /* eigen ga: geen onderbreking */
  if (od.pose === 'zwem') this.drijf(true);
};
/* Een sprong loopt met een VASTE snelheid (geen aanloop en geen remweg zoals
   bij rijd), dan is de boog ook in de tijd een echte parabool. Een korte
   sprong wordt over SPRING_TIKKEN tikken uitgesmeerd, anders zie je hem niet;
   tempo maakt die tijd korter (2 = half) of langer (0,5 = dubbel). */
function springTikken(od) { return Math.max(2, Math.round(SPRING_TIKKEN / od.tempo)); }
Dier.prototype.vlieg = function (snel) {
  var dx = this.tx - this.x, dz = this.tz - this.z;
  var d = Math.sqrt(dx * dx + dz * dz);
  if (d < 0.02) { this.v = 0; return true; }
  var stap = Math.min(snel, d);
  this.v = snel;
  this.x += dx / d * stap; this.z += dz / d * stap;
  this.face = (dx - dz) >= 0 ? 1 : -1;
  return stap >= d - 0.02;
};
/* één tik van een lopende opdracht (of van een losse zwem/spring-houding) */
Dier.prototype.opdrachtTik = function () {
  this.px = this.x; this.pz = this.z;
  var od = this.opdracht;
  if (!od) { this.houdingTik(); return; }
  if (od.kamer !== this.kamer) { this.opdrachtStop(false); return; }   /* kamer verlaten */
  if (od.wacht > 0) {                              /* even plat op de steen */
    od.wacht--;
    this.pose = 'blijB'; this.bob = 1; this.zij = 0; this.v = 0;
    if (od.wacht === 0) this.opdrachtVerder();
    return;
  }
  var f, dx, dz;
  if (od.pose === 'spring') {
    var er = this.vlieg(Math.max(0.05, Math.min(this.vmax * loopMaat(this) * od.tempo,
                                                od.len / springTikken(od))));
    dx = this.tx - this.x; dz = this.tz - this.z;
    f = 1 - Math.sqrt(dx * dx + dz * dz) / od.len;
    this.springHouding(f < 0 ? 0 : f > 1 ? 1 : f);
    if (er) this.opdrachtLanding();                /* springen = stop en squash per steen */
    return;
  }
  this.glijTik(od);
};
/* LOPEN EN ZWEMMEN: één doorlopende glijbeweging over alle punten. De
   snelheid gaat over de punten heen mee (geen stop per punt) en wat er van
   de stap van deze tik overblijft als het dier een punt raakt, loopt door
   naar het volgende punt. Zo kost een baantje van 43 punten precies zo lang
   als één rechte lijn van dezelfde lengte, en gaat perStap nog steeds
   precies één keer per punt af, op volgorde. */
Dier.prototype.glijTik = function (od) {
  var d0 = Math.sqrt((this.tx - this.x) * (this.tx - this.x) + (this.tz - this.z) * (this.tz - this.z));
  var over, dx, dz, d, stap;
  if (!this.rijd(od.tempo, od.rest[od.i])) {       /* nog onderweg naar dit punt */
    if (od.pose === 'zwem') this.drijf(true);      /* het zwemlijf over de loopdeining heen */
    return;
  }
  over = this.v - d0;                              /* rest van de stap van deze tik */
  while (true) {
    this.opdrachtLanding();
    if (this.opdracht !== od || od.wacht > 0) return;   /* klaar, ingehaald of even wachten */
    dx = this.tx - this.x; dz = this.tz - this.z;
    d = Math.sqrt(dx * dx + dz * dz);
    if (d < 0.02) continue;                        /* twee keer hetzelfde punt */
    if (over < 0.02) return;
    stap = Math.min(over, d);
    this.x += dx / d * stap; this.z += dz / d * stap;
    this.gang += stap * this.stapLengte;
    this.face = (dx - dz) >= 0 ? 1 : -1;
    over -= stap;
    if (stap < d - 0.02) return;                   /* volgend punt komt volgende tik */
  }
};
Dier.prototype.opdrachtLanding = function () {
  var od = this.opdracht, p = od.punten[od.i];
  var glij = od.pose !== 'spring' && od.i < od.punten.length - 1;   /* doorglijden */
  this.x = p.x; this.z = p.z;
  if (!glij) { this.v = 0; this.bob = 0; this.zij = 0; }
  if (od.pose === 'zwem') this.drijf(glij);         /* blijft drijven tussen twee slagen */
  else {
    this.hoogte = 0; this.lift = 0;
    if (od.pose === 'spring') { this.pose = 'blijB'; this.bob = 1; }
  }
  vuil = true;
  if (od.perStap) {
    try { od.perStap(od.i, p); }
    catch (e) { if (window.console) console.error('perStap', e); }
  }
  if (this.opdracht !== od) return;                /* perStap nam het dier over */
  od.wacht = od.pose === 'spring' ? Math.max(1, Math.round(SQUASH / od.tempo)) : 0;
  if (!od.wacht) this.opdrachtVerder();
};
Dier.prototype.opdrachtVerder = function () {
  var od = this.opdracht;
  if (od.i >= od.punten.length - 1) this.opdrachtKlaar();
  else this.opdrachtVolgende();
};
Dier.prototype.opdrachtKlaar = function () {
  var od = this.opdracht;
  this.opdracht = null;
  this.hoogte = 0; this.lift = 0; this.bob = 0; this.v = 0;
  this.eindHouding(od.na || (od.pose === 'zwem' ? 'zwem' : 'wacht'));
  od.klaar(true);
  vuil = true;
};
/* na het laatste punt: blijven drijven, blijven hupsen, of gewoon aankomen */
Dier.prototype.eindHouding = function (na) {
  if (na === 'zwem' || na === 'spring') { this.zet(na, 0); this.houdingTik(); return; }
  if (na === 'zit' || na === 'kijk') { this.zet(na, OD_DUUR[na]); return; }
  this.na = na;
  this.aangekomen();
};

/* ---------- de twee nieuwe houdingen (combinaties van bestaande frames) ---------- */
/* zwem: de buik op de waterlijn en de pootjes eronder (de badvloer ligt lager,
   dus het water verbergt ze), zachte deining, peddelen met de pootjes en
   onderweg een paar lichte plonsjes bij de voorpootjes. */
Dier.prototype.drijf = function (beweegt) {
  var t = ++this.zwemT;                            /* eigen klok: loopt door over de punten heen */
  var s = Math.sin(t * 0.42 + this.fase);
  this.hoogte = -ZWEM_DIEP; this.lift = ZWEM_DIEP * HG;
  this.bob = s * 0.9;
  this.zij = Math.sin(t * 0.21 + this.fase) * 0.6;
  this.pose = beweegt ? (s > 0 ? 'loopA' : 'loopB') : (t % 40 < 20 ? 'loopA' : 'rust');
  if (beweegt) { if (t % 5 === 0) this.plons(1 + (t % 10 === 0 ? 1 : 0), true); }
  else if (t % 30 === 0) this.plons(1, false);
};
/* Zwemt dit dier NU, en zo ja: zit het in het water van deze kamer? Alleen
   dan legt het tekenwerk een waterband over zijn onderste helft (tekenWater).
   Een kamer met een bad (rooms.js, veld bad) weet precies waar het water
   ligt, dus een dier dat op het dek in de zwemhouding staat krijgt geen
   band; in een kamer zonder bad (de tobbe in de tuin, een testkamer) hoort
   de houding zelf het water te maken. */
Dier.prototype.inWater = function () {
  if (this.hoogte >= 0) return false;
  if (this.staat !== 'zwem' && !(this.opdracht && this.opdracht.pose === 'zwem')) return false;
  var r = Rooms.get(this.kamer), b = r && r.bad;
  if (!b) return true;
  return this.x >= b.x0 && this.x < b.x1 && this.z >= b.z0 && this.z < b.z1;
};
/* plonsjes (spat) of een rimpel (geen spat), in de kleur van het water */
Dier.prototype.plons = function (n, spat) {
  if (rustModus) return;                           /* rustmodus: geen deeltjes */
  if (this.kamer !== kamerNu) return;              /* buiten beeld: grofTik veegt ze toch weg */
  var i, vx = this.face * 4;
  for (i = 0; i < n; i++) {
    this.pluis.push({
      x: this.x + vx + (this.rnd() - 0.5) * 3, z: this.z + (this.rnd() - 0.5) * 6,
      y: spat ? 0.5 : 0,
      vx: (this.rnd() - 0.5) * 0.5, vy: spat ? 0.45 + this.rnd() * 0.4 : 0,
      g: spat ? 0.09 : 0, t: spat ? 9 : 12,
      c: ZWEM_KL[Math.floor(this.rnd() * ZWEM_KL.length)], s: spat ? 1.1 : 1.5
    });
  }
};
/* spring: een boogje tussen twee punten; f = hoever de sprong is (0..1) */
Dier.prototype.springHouding = function (f) {
  var h = (SPRING_HOOG[this.kind] || 5) * 4 * f * (1 - f);
  this.hoogte = h; this.lift = -h * HG;
  this.bob = 0; this.zij = 0;
  this.pose = f < 0.25 ? 'loopA' : f < 0.75 ? 'blijA' : 'loopB';
};
/* zwem/spring als LOSSE houding (World.pose): drijven, of ter plekke hupsen,
   tot de duur om is (dan blijft het dier staan) of tot het volgende bevel */
Dier.prototype.houdingTik = function () {
  if (this.staat === 'zwem') this.drijf(false);
  else if (this.staat === 'spring') {
    var f = (this.t % (SPRING_TIKKEN + SQUASH)) / SPRING_TIKKEN;
    if (f < 1) this.springHouding(f);
    else { this.hoogte = 0; this.lift = 0; this.pose = 'blijB'; this.bob = 1; }
  }
  if (this.duur && this.t >= this.duur) { this.zet('wacht', 0); this.face = 1; }
};

/* =====================================================================
   CANVAS, CAMERA EN VLOERPLATEN
===================================================================== */
var host = null, cv = null, ctx = null, tagHost = null;
var W = 0, H = 0, g = 2, camX = 0, camY = 0, dpr = 1;
var vuil = true, aan = false, rustModus = false, tonen = false;
var dieren = [], bakken = {}, dingen = [], kamerNu = 'receptie';
var reis = null;                       /* camera onderweg naar een kamer */

function kamer() { return Rooms.get(kamerNu) || Rooms.lijst()[0]; }

function camDoel(r) {
  var b = r.box;
  var cx = W / 2 - (b[0] + b[1]) / 2 * g;
  var hoog = (b[3] - b[2]) * g, over = H - hoog;
  /* ONDER de kamer hoort een strook: daar hangt het cijferpad (ui.js zet het
     44 voxel-px onder de kamerdoos) en daar staat de dekenkist van de bedden.
     Is er hoogte over, dan reserveren we KADER_ONDER css-px onderaan en staat
     de kamer daar netjes midden boven; is er minder over, dan gaat alles wat
     over is naar die strook en staat de kamer bovenaan.
     Past de doos niet (een heel laag kader), dan houden we de VLOER helemaal
     in beeld en snijden we bovenaan kale wand af - nooit de vloer waar de
     dieren en de bakjes staan. */
  var onder = Math.min(KADER_ONDER * dpr, Math.max(0, over));
  var cy = over >= 0 ? (over - onder) / 2 - b[2] * g : H - 4 - b[3] * g;
  return [cx, cy];
}
function camZet() {
  var c = camDoel(kamer());
  camX = Math.round(c[0]); camY = Math.round(c[1]);
}

/* =====================================================================
   HET KADER EN DE VOXELMAAT (HOTEL.md 1)
   Drie getallen horen bij elkaar, per RUIMTE:
     q      css-px per voxel-px    - hoe groot staat de kamer op het scherm
     g      canvas-px per voxel-px - de VOXELMAAT, altijd een heel getal 2..4
     dicht  canvas-px per css-px   - de tekendichtheid van het canvas
   q = g / dicht. Sinds K1 zijn de vier speelkamers 1,5x groter dan de gang
   en de tuin, en dus heeft elke ruimte zijn EIGEN maat: hij vult het kader
   in de breedte en zijn vloer past altijd in de hoogte. We zoomen dus nog
   steeds nooit uit (je ziet nooit het hele hotel), we verhuizen - en bij het
   verhuizen verandert de maat mee, want een kleine gang hoort niet klein in
   beeld te staan omdat de receptie breed is.
   Daarna kiezen we de dichtstbijzijnde HELE g: is die groter dan het scherm
   zelf kan geven (op een telefoon is g = 2 al te groot voor een kamer van
   500 voxel-px breed), dan tekenen we het canvas op een hógere dichtheid dan
   het scherm en laat de css hem terugschalen. Zo blijft g heel (de blokjes
   zijn nooit uitgerekt) en past de kamer altijd.
   De hoogte van het KADER is wél voor alle ruimtes gelijk (anders springt de
   pagina bij elke deur): hij is zo hoog dat de kleinst uitvallende doos nog
   60% vult, en niet hoger dan er op het scherm over is.
===================================================================== */
var KADER_ONDER = 132;          /* css-px onder de kamer: daar past het pad */
var KADER_RAND = 4;             /* css-px lucht links en rechts van de doos */
/* Wat er van een kamerdoos ALTIJD in beeld moet blijven: de vloer, de rand
   eronder en een strook wand van WAND_ZICHT voxel-px. Daarboven staat kale
   wand; die mag in een laag kader (liggende telefoon) wegvallen, precies
   zoals de camera dat altijd deed. Het prikbord is 23 voxels hoog (46
   voxel-px), het sleutelbord 19, dus met 56 blijven ze heel. */
var WAND_ZICHT = 56;
function doosVan(r) { return r.box || Rooms.kader(r); }
function doosBreed(r) { var b = doosVan(r); return b[1] - b[0]; }
function doosHoog(r) { var b = doosVan(r); return b[3] - b[2]; }
/* de hoogte die er van deze doos echt in het kader moet passen */
function nodigHoog(r) {
  var b = doosVan(r), lucht = Math.max(0, -b[2] - WAND_ZICHT);
  return (b[3] - b[2]) - lucht;
}
/* hoeveel hoogte gaat er op aan balken boven en onder het kader? */
function chroomHoogte() {
  var app = document.getElementById('app');
  if (!app || !host) return 200;
  return Math.max(110, app.offsetHeight - host.offsetHeight);
}
/* hoeveel hoogte is er over voor het kader zelf? */
function ruimteHoogte() {
  return Math.max(200, window.innerHeight - chroomHoogte() - 6);
}
/* ... en hoeveel daarvan mag het kader echt gebruiken (de balken van het
   hotel moeten er ook nog bij: staand 78%, liggend 90% van het scherm) */
function ruimVoorKader() {
  var staand = window.innerHeight >= window.innerWidth;
  return Math.min(ruimteHoogte(), Math.round(window.innerHeight * (staand ? 0.78 : 0.90)));
}
/* de maat van ÉÉN ruimte in een kader van cssW breed en hoogPx hoog */
function maatVan(r, cssW, hoogPx) {
  var d = Math.min(3, window.devicePixelRatio || 1);
  /* Deze doos past: in de breedte helemaal, in de hoogte tot op de kale wand.
     KADER_RAND is het strookje lucht dat we vrijhouden - onderaan houdt de
     camera diezelfde 4 px ook echt vrij (camDoel) als hij wand afsnijdt. */
  var q = Math.min((Math.max(240, cssW) - KADER_RAND) / doosBreed(r),
                   Math.max(120, hoogPx - KADER_RAND) / nodigHoog(r));
  var ng = Math.max(2, Math.min(4, Math.round(q * d)));
  /* Zou de kamer met die hele maat veel kleiner uitvallen dan er ruimte is
     (meer dan een tiende), dan nemen we de eerstvolgende hele maat: liever
     een kamer die het kader vult dan een kamer die klein en scherp in een
     hoekje staat (l1: wereld + balken vullen 75% van het scherm). */
  if (ng / d < q * 0.9) ng = Math.max(2, Math.min(4, Math.ceil(q * d)));
  /* nooit UITrekken: de dichtheid is minstens die van het scherm zelf */
  var dicht = Math.max(d, ng / q);
  return { q: ng / dicht, g: ng, dicht: dicht };
}
/* Hoe hoog wordt het kader? Voor álle ruimtes hetzelfde, anders springt de
   pagina bij elke deur. Zo hoog als er over is, maar nooit zó hoog dat de
   kleinst uitvallende doos minder dan 60% vult (dan kijk je in een zee van
   lucht) - en de hoogste doos mag er alleen kale wand bij inschieten. */
function kaderHoogte(cssW, ruim) {
  var laagste = 0;
  Rooms.lijst().forEach(function (r) {
    var h = doosHoog(r) * maatVan(r, cssW, ruim).q;
    if (!laagste || h < laagste) laagste = h;
  });
  return Math.max(200, Math.min(ruim, Math.round(laagste / 0.60)));
}
/* geeft true als de hoogte van het kader veranderd is */
function pasKader(cssW) {
  if (!host) return false;
  if (document.body && document.body.classList.contains('metpaneel')) {
    /* een spel met een rekenblad ernaast: laat de opmaak het regelen */
    if (host.style.height) { host.style.height = ''; host.style.maxHeight = ''; return true; }
    return false;
  }
  var wil = kaderHoogte(cssW, ruimVoorKader());
  if (host.style.height === wil + 'px') return false;
  host.style.height = wil + 'px';
  host.style.maxHeight = wil + 'px';
  return true;
}

function meet() {
  if (!host) return false;
  var r = host.getBoundingClientRect();
  if (r.width < 8 || r.height < 8) return false;
  if (pasKader(r.width)) r = host.getBoundingClientRect();
  var m = maatVan(kamer(), r.width, r.height);
  var nw = Math.max(240, Math.round(r.width * m.dicht)), nh = Math.max(180, Math.round(r.height * m.dicht));
  if (nw === W && nh === H && m.g === g && m.dicht === dpr) return false;
  W = nw; H = nh; g = m.g; dpr = m.dicht;
  cv.width = W; cv.height = H;
  cv.style.width = r.width + 'px'; cv.style.height = r.height + 'px';
  ctx.imageSmoothingEnabled = false;
  camZet();
  if (window.Hits) Hits.hermeet();
  vuil = true;
  return true;
}

/* ---------- van voxels naar schermpunten ---------- */
function schermX(x, z) { return camX + (x - z) * S * g; }
function schermY(x, z) { return camY + (x + z) * (S / 2) * g; }

/* =====================================================================
   DE VLOERPLAAT: vloer + twee achterwanden, één keer per kamer gebakken
===================================================================== */
var platen = {}, plaatOrde = [], PLAAT_MAX = 4;

function vlak(cc, pts, kleur) {
  cc.fillStyle = kleur;
  cc.beginPath();
  cc.moveTo(pts[0][0], pts[0][1]);
  for (var i = 1; i < pts.length; i++) cc.lineTo(pts[i][0], pts[i][1]);
  cc.closePath();
  cc.fill();
}
/* voxelpunt -> plaatpixel */
function mk(o) {
  return function (x, y, z) {
    return [((x - z) * S) * o.g + o.ox, ((x + z) * (S / 2) - y * HG) * o.g + o.oy];
  };
}
/* vloervakje van sx bij sz voxels */
function vak(cc, P, x, z, sx, sz, kleur) {
  vlak(cc, [P(x, 0, z), P(x + sx, 0, z), P(x + sx, 0, z + sz), P(x, 0, z + sz)], kleur);
}
/* het gras van de tuin: ruitjes die iets overlappen, net als vroeger */
function tegel(cc, o, u, w, kleur) {
  var x = u * S * o.g + o.ox, y = w * (S / 2) * o.g + o.oy;
  var bw = 2 * S * o.g + 1, bh = S * o.g + 0.5;
  cc.fillStyle = kleur;
  cc.beginPath();
  cc.moveTo(x, y - bh); cc.lineTo(x + bw, y); cc.lineTo(x, y + bh); cc.lineTo(x - bw, y);
  cc.closePath(); cc.fill();
}

function wandDeuren(r, wand) {
  var uit = [];
  for (var i = 0; i < r.deuren.length; i++)
    if (r.deuren[i].wand === wand && !r.deuren[i].poort) uit.push(r.deuren[i]);
  uit.sort(function (a, b) { return a.at - b.at; });
  return uit;
}
/* Eén achterwand als vlakken: muur, plint, lambrisering, deurgaten en de
   dikke bovenrand. wand 'z' loopt met x mee (kijkt naar +z, dus donkerder
   licht); wand 'x' loopt met z mee (kijkt naar +x). */
function bouwWand(cc, P, r, wand) {
  var Hh = r.wand, dik = 3, lang = wand === 'z' ? r.w : r.d;
  var basis = wand === 'z' ? W_L : W_R, band = wand === 'z' ? W_L2 : W_R2;
  var deuren = wandDeuren(r, wand), deurH = Math.min(Hh - 6, 26);
  function q(a, b, y0, y1, kl) {                    /* stuk wand van a..b, y0..y1 */
    var p = wand === 'z'
      ? [P(a, y0, 0), P(b, y0, 0), P(b, y1, 0), P(a, y1, 0)]
      : [P(0, y0, a), P(0, y0, b), P(0, y1, b), P(0, y1, a)];
    vlak(cc, p, kl);
  }
  function cap(a, b, y, kl) {                       /* bovenkant van de wand */
    var p = wand === 'z'
      ? [P(a, y, -dik), P(b, y, -dik), P(b, y, 0), P(a, y, 0)]
      : [P(-dik, y, a), P(-dik, y, b), P(0, y, b), P(0, y, a)];
    vlak(cc, p, kl);
  }
  var stukken = [], vorig = 0, i;
  for (i = 0; i < deuren.length; i++) {
    stukken.push([vorig, deuren[i].at]);
    vorig = deuren[i].at + deuren[i].breed;
  }
  stukken.push([vorig, lang]);
  for (i = 0; i < stukken.length; i++) {
    var a = stukken[i][0], b = stukken[i][1];
    if (b - a < 0.5) continue;
    q(a, b, 0, Hh, basis);
    q(a, b, 9, 10.4, band);                          /* lambriseringslat */
    q(a, b, 0, 3, W_PLINT);                          /* plint */
  }
  /* deurgaten: donker gat + kozijn */
  for (i = 0; i < deuren.length; i++) {
    var d0 = deuren[i].at, d1 = d0 + deuren[i].breed;
    q(d0, d1, 0, deurH, GAT);
    q(d0, d1, deurH - 1.2, deurH, GAT_L);
    q(d0, d1, deurH, Hh, basis);
    q(d0, d0 + 1, 0, deurH + 1.4, Rooms.HOUT_D);
    q(d1 - 1, d1, 0, deurH + 1.4, Rooms.HOUT_D);
    q(d0, d1, deurH, deurH + 1.4, Rooms.HOUT);
  }
  cap(0, lang, Hh, W_TOP);
  /* zachte schaduw waar de wand op de vloer staat */
  cc.save();
  cc.globalAlpha = 0.10;
  if (wand === 'z') vak(cc, P, 0, 0, lang, 4, '#6E5A4A');
  else vak(cc, P, 0, 0, 4, lang, '#6E5A4A');
  cc.restore();
}

function bouwPlaat(r) {
  var b = r.box;
  var pw = Math.max(8, Math.ceil((b[1] - b[0]) * g) + 4);
  var ph = Math.max(8, Math.ceil((b[3] - b[2]) * g) + 4);
  var c = K.canvas(pw, ph), cc = c.getContext('2d');
  var o = { g: g, ox: -b[0] * g + 2, oy: -b[2] * g + 2 };
  var P = mk(o), x, z, u, w;
  if (r.erf) {
    /* de tuin: gras dat rustig doorloopt tot buiten het kader */
    cc.fillStyle = GRAS1;
    cc.fillRect(0, 0, pw, ph);
    var u0 = Math.floor((b[0] / S - 8) / 4) * 4, u1 = b[1] / S + 8;
    var w0 = Math.floor((b[2] / (S / 2) - 8) / 4) * 4, w1 = b[3] / (S / 2) + 8;
    for (w = w0; w <= w1; w += 4) for (u = u0; u <= u1; u += 4) {
      x = (u + w) / 2; z = (w - u) / 2;
      tegel(cc, o, u, w, Rooms.vloerKleur(r, x, z));
    }
  } else {
    for (x = 0; x < r.w; x += 4) for (z = 0; z < r.d; z += 4)
      vak(cc, P, x, z, Math.min(4, r.w - x), Math.min(4, r.d - z), Rooms.vloerKleur(r, x, z));
    /* dunne voorrand, zodat de vloer een dikte krijgt */
    vlak(cc, [P(r.w, 0, 0), P(r.w, 0, r.d), P(r.w, -1.6, r.d), P(r.w, -1.6, 0)], '#C9AC8A');
    vlak(cc, [P(0, 0, r.d), P(r.w, 0, r.d), P(r.w, -1.6, r.d), P(0, -1.6, r.d)], '#BB9C79');
    bouwWand(cc, P, r, 'z');
    bouwWand(cc, P, r, 'x');
  }
  /* zachte hoeken: het diorama loopt rustig weg */
  var vg = cc.createRadialGradient(pw / 2, ph * 0.55, Math.min(pw, ph) * 0.34,
                                   pw / 2, ph * 0.55, Math.max(pw, ph) * 0.72);
  vg.addColorStop(0, 'rgba(120,96,70,0)');
  vg.addColorStop(1, 'rgba(120,96,70,.18)');
  cc.fillStyle = vg;
  cc.fillRect(0, 0, pw, ph);
  return { cv: c, dx: b[0] * g - 2, dy: b[2] * g - 2 };
}
function plaat(r) {
  var k = r.id + '|' + g;
  var p = platen[k];
  if (p) return p;
  p = platen[k] = bouwPlaat(r);
  plaatOrde.push(k);
  while (plaatOrde.length > PLAAT_MAX) {
    var oud = plaatOrde.shift();
    if (oud !== k) delete platen[oud];
  }
  return p;
}

/* =====================================================================
   TEKENEN
===================================================================== */
function put(p, sx, sy) { ctx.drawImage(p.cv, Math.round(sx + p.dx), Math.round(sy + p.dy)); }
function putSpiegel(p, sx, sy, mx) {
  ctx.save();
  ctx.translate(mx, 0); ctx.scale(-1, 1);
  ctx.drawImage(p.cv, Math.round(sx + p.dx - mx), Math.round(sy + p.dy));
  ctx.restore();
}
/* it = het decor-item (optioneel): draagt het params, dan hoort die gedaante
   bij een eigen plaatje in de cache (sleutel = naam | g | params) */
function decorPlaat(naam, it) {
  var k = 'h|' + naam + '|' + g;
  if (it && it.params) k += '|' + paramSleutel(it);
  return K.cache(k, function () {
    return K.plaat(K.bake(Rooms.model(naam, it && it.params)), g);
  });
}
function grondschaduw(x, z, r) {
  ctx.save();
  ctx.globalAlpha = 0.15;
  ctx.fillStyle = '#6E5A4A';
  ctx.beginPath();
  ctx.ellipse(schermX(x, z), schermY(x, z), r * g, r * 0.5 * g, 0, 0, 6.2832);
  ctx.fill();
  ctx.restore();
}
/* 💤 boven een slaper: drie z-jes van blokjes, klein naar groot, recht boven
   zijn kop. Ze schuiven maar een paar voxels op, dus ze blijven binnen de
   omtrek van zijn EIGEN bed en komen nooit boven het bed van de buurman.
   Stil beeld: geen animatie die nooit stopt; ze zijn weg zodra hij opstaat.
   Z_KOP = waar de kop zit (voxels op de schermas), per z-je [dx, dy boven de
   matras, celmaat]. face < 0 = gespiegeld dier, dus ook de z-jes de andere
   kant op. De kleur is hetzelfde zachte bruin als een neusje: leesbaar op
   een lichte wand, nooit hard. */
var ZZZ_KL = '#7E6255', Z_KOP = 8, ZZZ = [[0, 17.5, 0.85], [2, 20.5, 1.15], [4, 24, 1.5]];
function tekenZ(px, py, m) {                /* dakje, twee schuine blokjes, vloertje */
  ctx.fillRect(px, py, m * 4, m);
  ctx.fillRect(px + m * 2, py + m, m, m);
  ctx.fillRect(px + m, py + m * 2, m, m);
  ctx.fillRect(px, py + m * 3, m * 4, m);
}
function tekenZzz(d, x, z) {
  var bx = schermX(x, z), by = schermY(x, z) + (d.lift + d.bob) * g;
  var kop = d.face < 0 ? -1 : 1, i, q, m;
  ctx.save();
  ctx.globalAlpha = 0.8;
  ctx.fillStyle = ZZZ_KL;
  for (i = 0; i < ZZZ.length; i++) {
    q = ZZZ[i];
    m = Math.max(1, Math.round(q[2] * g));
    tekenZ(Math.round(bx + kop * (Z_KOP + q[0]) * S * g) - (kop < 0 ? m * 4 : 0),
           Math.round(by - q[1] * HG * g), m);
  }
  ctx.restore();
}
/* WATER OVER EEN ZWEMMER (P1c-F1). Het badwater is in de VLOERPLAAT gebakken
   en ligt dus ONDER het dier: een zwemmer leek daardoor te waden. Daarom
   komt er na het dier een doorschijnende band water over zijn onderste deel
   (ongeveer 40% van het plaatje): de buik op de waterlijn, de pootjes
   eronder in het water.
   De waterlijn is de vloer onder het dier (schermY): het dier zakt precies
   ZWEM_DIEP voxels, dus zijn buik ligt er altijd op. De band deint NIET mee -
   het water blijft liggen, het dier deint erin - en wordt afgesneden op het
   plaatje van het dier zelf, dus er ligt nooit een plas naast hem: over het
   badwater heen zou een tweede laag water alleen maar een vlek geven.
   De snijlijn met het water is een ellips (het oppervlak in vogelvlucht: aan
   de achterkant van het dier ligt de lijn hoger op het scherm dan aan de
   voorkant), daaronder alles blauw. Het water komt ALLEEN op de voxels van
   het dier zelf ('source-atop' op een hulpdoek), dus er ligt nooit een vlek
   water naast hem op de badrand of op de tegels. Kleur = het badwater van
   rooms.js (BADWATER[0]). Het hulpdoek wordt één keer gemaakt en daarna
   hergebruikt: geen nieuw canvas of object per beeldje. De rimpels en
   plonsjes komen er daarna nog bovenop (tekenPluis). */
var WATER_KL = '#9CD1E4', WATER_A = 0.75;
var waterCv = null, waterCx = null;
function waterDoek(w, h) {
  if (!waterCv) { waterCv = document.createElement('canvas'); waterCx = waterCv.getContext('2d'); }
  if (waterCv.width < w || waterCv.height < h) {        /* alleen groeien, nooit per beeldje */
    waterCv.width = Math.max(w, waterCv.width);
    waterCv.height = Math.max(h, waterCv.height);
  }
  return waterCx;
}
function tekenWater(d, x, z, p, ox, oy) {
  var w = p.cv.width, h = p.cv.height;
  if (w < 2 || h < 2) return;
  var top = schermY(x, z) - (camY + oy + p.dy);         /* de waterlijn IN het plaatje */
  if (top >= h) return;                                 /* alles al onder water */
  if (top < 0) top = 0;
  var cx = w / 2, rx = w / 2, ry = Math.max(2, Math.min(rx * 0.42, 5 * g));
  var c = waterDoek(w, h);
  c.setTransform(1, 0, 0, 1, 0, 0);
  c.globalCompositeOperation = 'source-over';
  c.globalAlpha = 1;
  c.clearRect(0, 0, w, h);
  c.drawImage(p.cv, 0, 0);
  c.globalCompositeOperation = 'source-atop';           /* alleen op het dier zelf */
  c.globalAlpha = WATER_A;
  c.fillStyle = WATER_KL;
  c.beginPath();
  c.moveTo(cx + rx, top);
  c.ellipse(cx, top, rx, ry, 0, 0, 6.2832);             /* de snijlijn met het water */
  c.rect(0, top, w, h - top);                           /* alles onder de waterlijn */
  c.fill();
  /* Alleen het stuk vanaf de bovenkant van de ellips terugtekenen: hoger op
     het dier blijft precies staan wat de motor net getekend heeft (een tweede
     keer tekenen maakt de zachte randpuntjes van het plaatje donkerder). */
  var ty = Math.round(top - ry), hy, mx;
  if (ty < 0) ty = 0;
  hy = h - ty;
  if (hy < 1) return;
  if (d.face < 0) {
    mx = schermX(x, z) + d.zij * g;
    ctx.save();
    ctx.translate(mx, 0); ctx.scale(-1, 1);
    ctx.drawImage(waterCv, 0, ty, w, hy, Math.round(camX + ox + p.dx - mx),
                  Math.round(camY + oy + p.dy) + ty, w, hy);
    ctx.restore();
  } else ctx.drawImage(waterCv, 0, ty, w, hy, Math.round(camX + ox + p.dx),
                       Math.round(camY + oy + p.dy) + ty, w, hy);
}
function tekenDier(d, mengen) {
  var x = d.px + (d.x - d.px) * mengen, z = d.pz + (d.z - d.pz) * mengen;
  var a = K.dierAnker;
  var ox = ((x - a[0]) - (z - a[1])) * S * g + d.zij * g;
  var oy = ((x - a[0]) + (z - a[1])) * (S / 2) * g + (d.bob + d.lift) * g;
  var p = K.dier(d.kind, d.pose, g);
  if (d.face < 0) putSpiegel(p, camX + ox, camY + oy, schermX(x, z) + d.zij * g);
  else put(p, camX + ox, camY + oy);
  if (d.inWater()) tekenWater(d, x, z, p, ox, oy);
  if (d.staat === 'slaap') tekenZzz(d, x, z);
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
  if (deel === 0) put(decorPlaat('mat'), schermX(b.x, b.z), schermY(b.x, b.z));
  put(K.kom(b.eten, g, deel), camX + ox, camY + oy);
}

var lijst = [];
function teken(mengen) {
  if (!ctx || !W) return;
  var r = kamer(), i, d, j;
  var p = plaat(r);
  ctx.clearRect(0, 0, W, H);
  ctx.save();
  if (reis) ctx.globalAlpha = reis.alfa;
  ctx.drawImage(p.cv, Math.round(camX + p.dx), Math.round(camY + p.dy));

  /* schaduwen liggen allemaal plat op de vloer */
  for (i = 0; i < dieren.length; i++) {
    d = dieren[i];
    if (d.kamer !== r.id || d.staat === 'slaap') continue;
    grondschaduw(d.px + (d.x - d.px) * mengen, d.pz + (d.z - d.pz) * mengen,
                 d.staat === 'zit' || d.staat === 'sip' ? 7 : 8);
  }

  lijst.length = 0;
  for (i = 0; i < r.decor.length; i++) {
    var it = r.decor[i];
    lijst.push({ n: it.n, x: it.x, z: it.z, y: it.y || 0, it: it,
                 d: it.x + it.z + (it.y ? 0.3 : 0) - (it.ver ? 1000 : 0) });
  }
  /* los decor van een spel: zelfde painter als de meubels (zie LOS DECOR) */
  var los = losDecor[r.id];
  if (los) for (i = 0; i < los.length; i++) {
    var lo = los[i];
    lijst.push({ los: lo, d: lo.x + lo.z + (lo.hoog ? 0.3 : 0) - (lo.ver ? 1000 : 0) });
  }
  for (i = 0; i < dingen.length; i++) {
    if (dingen[i].kamer !== r.id) continue;
    lijst.push({ n: dingen[i].n, x: dingen[i].x, z: dingen[i].z, y: dingen[i].y || 0,
                 d: dingen[i].x + dingen[i].z + 0.2 });
  }
  for (i = 0; i < r.slots.length; i++) {
    var s = r.slots[i];
    if (s.soort === 'bed') lijst.push({ n: s.model || (s.draai ? 'bedz' : 'bed'), x: s.x, z: s.z, d: s.x + s.z });
    else if (s.soort === 'bak') {
      var b = bakken[r.id + '|' + s.id];
      if (!b) continue;
      var eter = null;
      for (j = 0; j < dieren.length; j++)
        if (dieren[j].kamer === r.id && dieren[j].staat === 'eet') eter = dieren[j];
      lijst.push({ bak: b, eter: eter, d: b.x + b.z });
    }
  }
  for (i = 0; i < dieren.length; i++) {
    d = dieren[i];
    if (d.kamer !== r.id) continue;
    if (d.staat === 'eet') continue;
    lijst.push({ dier: d, d: d.px + d.pz + (d.x + d.z - d.px - d.pz) * mengen + (d.staat === 'slaap' ? 0.5 : 0) });
  }
  lijst.sort(function (a, b) { return a.d - b.d; });

  for (i = 0; i < lijst.length; i++) {
    var q = lijst[i];
    if (q.n) put(decorPlaat(q.n, q.it), schermX(q.x, q.z), schermY(q.x, q.z) - (q.y || 0) * HG * g);
    else if (q.los) tekenLos(q.los);
    else if (q.bak) {
      if (q.eter) { tekenBak(q.bak, 0); tekenDier(q.eter, mengen); tekenBak(q.bak, 1); }
      else { tekenBak(q.bak, 0); tekenBak(q.bak, 1); }
    } else tekenDier(q.dier, mengen);
  }
  for (i = 0; i < dieren.length; i++)
    if (dieren[i].kamer === r.id && dieren[i].pluis.length) tekenPluis(dieren[i]);
  ctx.restore();
  naamplaatjes(mengen, r.id);
  Hits.plaats(r.id, projectie);
}

/* =====================================================================
   LOS DECOR: voorwerpen die een minigame zelf neerzet en bijwerkt
   (een klok waarvan de wijzers draaien, kratten die volstromen, stapstenen
   met een cijfer, een vlag op L meter). Ze staan NIET in Rooms (dus niet in
   de opslag) en NIET in de vloerplaat: elk stuk bakt zijn eigen plaatje en
   doet per beeld gewoon mee in de painter (x + z) met de meubels en de
   dieren. Wisselen de params, dan wordt alleen dát ene plaatje opnieuw
   gebakken; de vloerplaat (4 slots) en de gedeelde plaatjes-cache van Art
   blijven met rust. Per beeld kost een stuk één lijst.push - hetzelfde als
   een meubel.

   Eigenaar (door) = het spel dat het neerzette (via ctx.wereld.decor gaat
   dat vanzelf). Stopt dat spel, of begint een ander spel, dan ruimt de
   wereld het op: registry.js zet bij elke start/stop Hits.voorrang(spel |
   null), en daar haken we op in (spelWissel). Eigenaars die geen aangemeld
   spel zijn (het hotel zelf, een test) blijven staan tot decorWeg.
   Zie .fanout/specs/api-p1b.md.
===================================================================== */
var losDecor = Object.create(null);     /* kamerId -> [stuk] */
var LOS_MAX = 48;                        /* per kamer: 20 stenen + rand + vlag past ruim */

function paramSleutel(it) {
  if (!it.params) return '';
  if (it._pk === undefined) {
    try { it._pk = JSON.stringify(it.params); } catch (e) { it._pk = String(it.params); }
  }
  return it._pk;
}
/* kwartslagen om de y-as: rot 1 = [x, y, z] -> [z, y, -x]. Een klok die met
   zijn wijzerplaat naar +z kijkt (aan de z-wand) kijkt na rot 1 naar +x (aan
   de x-wand). Het is een echte draaiing, geen spiegeling: wijzers draaien
   nog steeds met de klok mee. */
function draaiVox(v, rot) {
  var r = ((rot % 4) + 4) % 4, u = [], i, q;
  if (!r) return v;
  for (i = 0; i < v.length; i++) {
    q = v[i];
    if (r === 1) u.push([q[2], q[1], -q[0], q[3], q[4]]);
    else if (r === 2) u.push([-q[0], q[1], -q[2], q[3], q[4]]);
    else u.push([-q[2], q[1], q[0], q[3], q[4]]);
  }
  return u;
}
/* het lege plaatje (een doorzichtig velletje van een paar pixels): één keer
   per voxelmaat maken en delen, voor een stapel van nul blokjes en voor een
   stuk dat niet gebakken kan worden. Er wordt alleen uit gelezen (put), dus
   delen is veilig. */
var leegPlaat = null, leegPlaatG = 0;
function leegStuk() {
  if (!leegPlaat || leegPlaatG !== g) { leegPlaat = K.plaat(K.bake([]), g); leegPlaatG = g; }
  return leegPlaat;
}
/* ALLES wat uit een modelfunctie komt hoort in DEZELFDE try: niet alleen de
   functie kan gooien, ook K.bake / K.plaat doen dat op een lijst die geen
   lijst is ('kapot') of op een voxel zonder kleur ([[0, 0, 0]]). Zou dat
   buiten de try gebeuren, dan gaf één kapot stuk elk beeld een paginafout
   en brak teken() halverwege af: de rest van de painter (meubels, dieren)
   en Hits.plaats bleven dan liggen. Mislukt het: het lege plaatje komt op
   het stuk te staan, dus één waarschuwing per stuk in plaats van één per
   beeld; bij nieuwe params (decorZet zet _fout terug) wordt het opnieuw
   geprobeerd. */
function losPlaat(it) {
  if (it.plaat && it.plaatG === g) return it.plaat;
  var p = null;
  try {
    var v = Rooms.model(it.model, it.params);
    if (!v || !v.length) v = null;
    else {
      if (it.rot) v = draaiVox(v, it.rot);
      p = K.plaat(K.bake(v), g);
    }
  } catch (e) {
    p = null;
    if (!it._fout) { it._fout = true; console.warn('decor ' + it.id + ': model ' + it.model + ' faalt', e); }
  }
  it.plaat = p || leegStuk();
  it.plaatG = g;
  return it.plaat;
}
function tekenLos(it) {
  put(losPlaat(it), schermX(it.x, it.z), schermY(it.x, it.z) - it.hoog * HG * g);
}
function losVind(lijst, id) {
  for (var i = 0; i < lijst.length; i++) if (lijst[i].id === id) return i;
  return -1;
}
/* opzoeken zonder ook maar iets te maken: een afgewezen decor() laat geen
   lege lijst in losDecor achter en losZoek hoeft geen lijstje kamers te
   bouwen (volg() draait per beeld, zie losMik). */
function losIn(kamerId, id) {
  var l = losDecor[kamerId];
  if (!l) return null;
  var j = losVind(l, id);
  return j >= 0 ? l[j] : null;
}
function losZoek(id, kamerId) {
  /* zonder kamer: eerst de kamer die nu in beeld is, dan de rest */
  if (kamerId) return losIn(kamerId, id);
  var it = losIn(kamerNu, id), k;
  if (it) return it;
  for (k in losDecor) { it = losIn(k, id); if (it) return it; }
  return null;
}
/* params gaat als eigen laagje mee naar buiten: wie in de teruggave rommelt,
   verandert niets aan het stuk (en dus ook niets aan de herbak-sleutel) */
function losParams(p) {
  var u, k;
  if (!p || typeof p !== 'object') return p;
  if (Object.prototype.toString.call(p) === '[object Array]') return p.slice();
  u = {};
  for (k in p) if (Object.prototype.hasOwnProperty.call(p, k)) u[k] = p[k];
  return u;
}
function losKopie(it) {
  return { id: it.id, model: it.model, kamer: it.kamer, x: it.x, z: it.z, hoog: it.hoog,
           rot: it.rot, ver: it.ver, params: losParams(it.params), door: it.door };
}
/* zetten of bijwerken op id.
     o = {id, model, x, z, params?, hoog?, rot?, ver?}  (bij bijwerken mag
         alles behalve id weg blijven: wat ontbreekt blijft zoals het was)
     eigen = de eigenaar (via ctx: het spel zelf; undefined = bevoorrecht)
   Geeft een kopie van het stuk terug, of null: onbekende kamer, onbekend
   model, stuk van een ander spel, of kamer vol (LOS_MAX). */
function decorZet(kamerId, o, eigen) {
  var r = Rooms.get(kamerId);
  if (!r || !o || o.id === undefined || o.id === null || o.id === '') return null;
  var id = String(o.id), lijst = losDecor[kamerId] || null, it = lijst ? losIn(kamerId, id) : null;
  if (it && eigen !== undefined && it.door !== eigen) return null;      /* niet van jou */
  var model = o.model !== undefined ? String(o.model) : (it ? it.model : null);
  if (!model || !Rooms.heeftModel(model)) { console.warn('decor ' + id + ': onbekend model ' + model); return null; }
  if (!it) {
    if (lijst && lijst.length >= LOS_MAX) { console.warn('decor: kamer ' + kamerId + ' is vol (' + LOS_MAX + ')'); return null; }
    it = { id: id, kamer: kamerId, model: model, x: 0, z: 0, hoog: 0, rot: 0, ver: false,
           params: null, _pk: '', door: eigen === undefined ? null : eigen,
           plaat: null, plaatG: 0, _fout: false };
    /* pas hier de lijst maken: een afgewezen aanroep laat niets achter */
    if (!lijst) lijst = losDecor[kamerId] = [];
    lijst.push(it);
  }
  var params = o.params === undefined ? it.params : (o.params || null), pk = '';
  if (params) { try { pk = JSON.stringify(params); } catch (e) { pk = String(params); } }
  var rot = o.rot === undefined ? it.rot : ((Math.round(+o.rot || 0) % 4) + 4) % 4;
  if (model !== it.model || rot !== it.rot || pk !== it._pk) { it.plaat = null; it._fout = false; }
  it.model = model; it.rot = rot; it.params = params; it._pk = pk;
  if (o.x !== undefined) it.x = +o.x || 0;
  if (o.z !== undefined) it.z = +o.z || 0;
  if (o.hoog !== undefined) it.hoog = +o.hoog || 0;
  else if (o.y !== undefined) it.hoog = +o.y || 0;
  if (o.ver !== undefined) it.ver = !!o.ver;
  vuil = true;
  return losKopie(it);
}
function decorWeg(kamerId, id, eigen) {
  var lijst = losDecor[kamerId];
  if (!lijst) return false;
  var i = losVind(lijst, String(id));
  if (i < 0 || (eigen !== undefined && lijst[i].door !== eigen)) return false;
  lijst.splice(i, 1);
  vuil = true;
  return true;
}
function decorLijst(kamerId) {
  var uit = [], k, i, l;
  for (k in losDecor) {
    if (kamerId && k !== kamerId) continue;
    l = losDecor[k];
    for (i = 0; i < l.length; i++) uit.push(losKopie(l[i]));
  }
  return uit;
}
function decorWisEigenaar(eigen) {
  var k, l, i, n = 0;
  for (k in losDecor) {
    l = losDecor[k];
    for (i = l.length - 1; i >= 0; i--) if (l[i].door === eigen) { l.splice(i, 1); n++; }
  }
  if (n) vuil = true;
  return n;
}
/* het stopsignaal: alles van een AANGEMELD spel dat niet `wie` is gaat weg */
function spelWissel(wie) {
  if (!window.Games || typeof Games.get !== 'function') return;
  var k, l, i, n = 0;
  for (k in losDecor) {
    l = losDecor[k];
    for (i = l.length - 1; i >= 0; i--)
      if (l[i].door && l[i].door !== wie && Games.get(l[i].door)) { l.splice(i, 1); n++; }
  }
  if (n) vuil = true;
}
if (window.Hits && typeof Hits.voorrang === 'function') {
  if (!Hits.voorrang._losDecor) {
    var hitsVoorrang = Hits.voorrang;
    Hits.voorrang = function (wie) { hitsVoorrang(wie); spelWissel(wie || null); };
    Hits.voorrang._losDecor = true;
  }
} else {
  /* geen stopsignaal om op te haken (hits.js niet geladen of veranderd): dan
     ruimt de wereld het decor van een spel NIET meer automatisch op. Eén
     regel, meteen bij het laden, zodat dat opvalt. */
  console.warn('los decor: Hits.voorrang ontbreekt - decor van een spel wordt niet ' +
               'automatisch opgeruimd; roep ctx.wereld.decorWisAlles() in stop()');
}
/* De ctx van elk spel krijgt dezelfde vier functies, met het spel zelf als
   eigenaar. registry.js roept dit één keer per spel aan bij het bouwen van
   zijn ctx (zie de opmerking aan het eind van ctxVoor). Dit blok hoort hier,
   bij het losse decor - andere modules hangen hun eigen uitbreiding op hun
   eigen plek aan dezelfde lijst. De functies hieronder zijn declaraties, dus
   het maakt niet uit dat `api` pas onderaan het bestand bestaat. */
(window.CTX_UITBREIDINGEN = window.CTX_UITBREIDINGEN || []).push(function (c, eigen) {
  if (!c || !c.wereld) return;
  c.wereld.decor = function (kamerId, o) { return decorZet(kamerId, o, eigen); };
  c.wereld.decorWeg = function (kamerId, id) { return decorWeg(kamerId, id, eigen); };
  c.wereld.decorLijst = function (kamerId) { return decorLijst(kamerId); };
  c.wereld.decorWisAlles = function () { return decorWisEigenaar(eigen); };
});
/* mikpunt op een los stuk (ui.wolk, ui.somkaart, getalTag aan een klok of
   steen). mik() kijkt hier als laatste: dieren, losse dingen, slots en vast
   decor gaan voor, dus kies ids die daar niet mee botsen (niet 'bed1', 'bak',
   'tobbe', 'kar', ...). */
/* volg() draait per beeld voor ELKE hotspot (Hits.plaats), dus daar mag niets
   gemaakt worden: de kamer staat vast in de sluiting (geen lijstje kamers om
   te zoeken) en het antwoord gaat in een eigen vast doosje per mikpunt. Hits
   leest het meteen uit en houdt het niet vast. */
function losMik(id, kamerId) {
  var it = losZoek(id, kamerId);
  if (!it) return null;
  var kamer = it.kamer, uit = { x: it.x, z: it.z, kamer: kamer };
  return { kamer: kamer, x: it.x, z: it.z, y: it.hoog || 0, los: id,
           volg: function () {
             var q = losIn(kamer, id);
             if (!q) return null;
             uit.x = q.x; uit.z = q.z;
             return uit;
           } };
}

/* De hotspot-laag rekent in css-pixels binnen het wereldkader.
   Tijdens het 300 ms camera-schuiven rekenen we met de camera van de
   BESTEMMING: de knoppen staan dan meteen stil op hun eindplek, dus een tik
   halverwege de beweging landt gewoon op het juiste voorwerp (en de dom
   hoeft ondertussen niet te verschuiven). */
function projectie(x, z, y) {
  var cx = camX, cy = camY;
  if (reis) { cx = reis.naar[0]; cy = reis.naar[1]; }
  return { x: (cx + (x - z) * S * g) / dpr,
           y: (cy + (x + z) * (S / 2) * g - (y || 0) * HG * g) / dpr };
}

/* ---------- naamkaartjes ---------- */
var tagPlek = [];
function naamplaatjes(mengen, kid) {
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
    if (d.kamer !== kid) { if (el.style.display !== 'none') el.style.display = 'none'; continue; }
    if (el.style.display === 'none') el.style.display = '';
    var x = d.px + (d.x - d.px) * mengen, z = d.pz + (d.z - d.pz) * mengen;
    sx = schermX(x, z) / sc;
    sy = (schermY(x, z) - (30 * HG + 8) * g + (d.bob + d.lift) * g) / sc;
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
var STAP = 1000 / 15, TEKEN = 1000 / 31, REIS_MS = 300;
var vorigeTik = 0, vorigeTeken = 0, restTijd = 0;

function reisStap(nu) {
  if (!reis) return;
  var t = Math.min(1, (nu - reis.t0) / REIS_MS);
  var e = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;   /* zacht in en uit */
  camX = Math.round(reis.van[0] + (reis.naar[0] - reis.van[0]) * e);
  camY = Math.round(reis.van[1] + (reis.naar[1] - reis.van[1]) * e);
  reis.alfa = 0.35 + 0.65 * e;
  vuil = true;
  if (t >= 1) { reis = null; camZet(); }
}

function lus(nu) {
  requestAnimationFrame(lus);
  if (!host || !host.isConnected) return;
  if (meet()) vuil = true;
  if (!W) return;
  if (!tonen) return;

  if (!rustModus) {
    if (!vorigeTik) vorigeTik = nu;
    var n = 0;
    while (nu - vorigeTik >= STAP && n < 3) {
      vorigeTik += STAP;
      for (var i = 0; i < dieren.length; i++) {
        if (dieren[i].kamer === kamerNu) dieren[i].tik();
        else dieren[i].grofTik();
      }
      vuil = true; n++;
    }
    if (nu - vorigeTik > STAP * 6) vorigeTik = nu;
    restTijd = Math.max(0, Math.min(1, (nu - vorigeTik) / STAP));
  } else restTijd = 1;

  if (reis) reisStap(nu);
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

function bouwBakken() {
  bakken = {};
  Rooms.lijst().forEach(function (r) {
    Rooms.slots(r.id, 'bak').forEach(function (s) {
      bakken[r.id + '|' + s.id] = { kamer: r.id, slot: s.id, x: s.x, z: s.z, eten: 0 };
    });
  });
}
/* Waar staat een reizend voorwerp in elke ruimte? De voerkar staat in de gang
   netjes langs de loper en in een kamer naast het bakje. */
var RUST = {
  kar: { keuken: Rooms.plek('keuken', 0.4, 0.579), gang: { x: 60, z: 20 },
         kamer1: Rooms.plek('kamer1', 0.579, 0.579), kamer2: Rooms.plek('kamer2', 0.579, 0.579),
         receptie: Rooms.plek('receptie', 0.7, 0.3),
         /* zwembad: midden op het dek vóór het water; wasserij: midden */
         zwembad: Rooms.plek('zwembad', 0.5, 0.8), wasserij: Rooms.plek('wasserij', 0.45, 0.6) }
};

/* losse voorwerpen (de voerkar) uit het decor lichten: die kunnen reizen */
function bouwDingen() {
  dingen = [];
  Rooms.lijst().forEach(function (r) {
    r.decor = r.decor.filter(function (it) {
      if (!it.sleutel && it.n !== 'kar') return true;
      dingen.push({ sleutel: it.sleutel || it.n, n: it.n, kamer: r.id,
                    x: it.x, z: it.z, y: it.y || 0,
                    rust: RUST[it.sleutel || it.n] || null });
      return false;
    });
  });
}
/* Er is een bed of bakje bijgeplaatst: de bakjes-administratie opnieuw
   opbouwen, met behoud van wat er al in de bakjes lag. */
function herbouw() {
  var oud = bakken, k;
  bouwBakken();
  for (k in bakken) if (oud[k]) bakken[k].eten = oud[k].eten;
  vuil = true;
}

function ding(sleutel) {
  for (var i = 0; i < dingen.length; i++) if (dingen[i].sleutel === sleutel) return dingen[i];
  return null;
}
/* Een voorwerp dat verhuist moet in de NIEUWE kamer op de vloer staan. De
   voerkar stond bijvoorbeeld op z = 44, en de gang is maar 36 diep - dan
   zweeft de kar naast het tapijt. Heeft het voorwerp voor die kamer een eigen
   plek (RUST), dan gebruiken we die; anders vraagt Rooms.vrijVak het
   dichtstbijzijnde vakje van het vloerraster dat op dit moment ook echt leeg
   is. Daarna houden we het voorwerp altijd binnen de kamer. */
function rustPlek(d, kamerId) {
  var r = Rooms.get(kamerId);
  if (!r || r.erf) return null;
  if (d.rust && d.rust[kamerId]) return d.rust[kamerId];
  var v = Rooms.vrijVak(kamerId, r.w * 0.45, r.d * 0.55);
  return v ? { x: v.x, z: v.z } : { x: Math.round(r.w / 2), z: Math.round(r.d / 2) };
}
function inKamer(d) {
  var r = Rooms.get(d.kamer);
  if (!r || r.erf) return;
  var m = 6;
  d.x = Math.max(m, Math.min(r.w - m, d.x));
  d.z = Math.max(m, Math.min(r.d - m, d.z));
}
function dingZet(sleutel, o) {
  var d = ding(sleutel);
  if (!d) return null;
  var oudeKamer = d.kamer;
  for (var k in o) d[k] = o[k];
  if (d.kamer !== oudeKamer && (o.x === undefined || o.z === undefined)) {
    var p = rustPlek(d, d.kamer);
    if (p) { d.x = p.x; d.z = p.z; }
  }
  inKamer(d);
  vuil = true;
  return d;
}

function sync(lijstGasten) {
  var oud = dieren, i, j, d, nieuw = [];
  for (i = 0; i < lijstGasten.length; i++) {
    var a = lijstGasten[i];
    d = null;
    for (j = 0; j < oud.length; j++) if (oud[j].id === a.id) d = oud[j];
    if (!d) d = new Dier(a, i);
    else {
      d.naam = a.name || a.naam || d.naam;
      if (d.tag) d.tag.textContent = d.naam;
    }
    d.nr = i;
    d.blijStijl = stijlVan(i);
    nieuw.push(d);
  }
  for (i = 0; i < oud.length; i++) if (nieuw.indexOf(oud[i]) < 0) oud[i].opdrachtStop(false);
  for (i = 0; i < oud.length; i++)
    if (nieuw.indexOf(oud[i]) < 0 && oud[i].tag && oud[i].tag.parentNode)
      oud[i].tag.parentNode.removeChild(oud[i].tag);
  dieren = nieuw;
  if (rustModus) for (i = 0; i < dieren.length; i++) dieren[i].stilzetten('rust');
  vuil = true;
}

function zet(id, kamerId, x, z) {
  var d = vind(id);
  if (!d) return;
  if (kamerId && Rooms.get(kamerId)) d.kamer = kamerId;
  var P = Rooms.plekken(d.kamer);
  var q = P[(d.nr * 3 + 1) % P.length];
  d.x = x === undefined || x === null ? q[0] : x;
  d.z = z === undefined || z === null ? q[1] : z;
  d.px = d.x; d.pz = d.z;
  /* wie ergens neergezet wordt, is niet meer op weg naar zijn bed en
     zweeft ook niet meer op matrashoogte */
  d.route = null; d.eindDoel = null; d.slaapDoel = null; d.lift = 0;
  d.zet('stil', 12);
  vuil = true;
}

function ga(id, x, z, na) {
  var d = vind(id);
  if (!d) return;
  d.route = null; d.eindDoel = null; d.slaapDoel = null; d.lift = 0;
  if (rustModus) { d.x = x; d.z = z; d.px = x; d.pz = z; d.stilzetten('rust'); return; }
  d.ga(x, z, na || 'stil');
  vuil = true;
}

/* door de deuren naar een andere kamer; doel = {x,z,na} in die kamer */
function reisNaar(id, kamerId, doel) {
  var d = vind(id);
  if (!d) return [];
  var p = Rooms.pad(d.kamer, kamerId);
  /* Geen pad (dezelfde kamer, of een kamer die niet bestaat)? Dan is dit geen
     bevel: laat een zwemmer of een lopende opdracht met rust, anders stond
     zijn lift één tik op 0 en wipte hij een beeldje uit het water (P1c-F1). */
  if (!p.length && (d.opdracht || d.staat === 'zwem')) return [];
  d.lift = 0; d.slaapDoel = null;
  if (!p.length) return [];
  d.route = p.slice(1);
  d.eindDoel = doel || null;
  if (rustModus) {
    d.kamer = kamerId; d.route = null;
    var q = doel || { x: (Rooms.get(kamerId).w) / 2, z: (Rooms.get(kamerId).d) / 2 };
    d.x = q.x; d.z = q.z; d.px = q.x; d.pz = q.z;
    d.eindDoel = null;
    d.stilzetten('rust');
    return p;
  }
  if (!volgendeStap(d)) d.zet('stil', 10);
  vuil = true;
  return p;
}

/* ---------- in bed: het dier ligt ÓP de matras en slaapt rustig ----------
   MATRAS = de bovenkant van de matras van pBed (rooms.js): dat kussenblok
   ligt op y 4..6, dus het dier begint op 7. Eén voxel te laag en het dier
   zakt in het bed weg. lift rekent in tekenpixels, vandaar de HG.
   Een GEDRAAID bed (bedz) is lang in de z-richting. face = -1 spiegelt het
   dier op het scherm, en dat is in deze isometrie precies een kwartslag
   draaien (model-x wordt wereld-z). Zo ligt het dier ook dán in de lengte
   van het bed en niet dwars erover. */
var MATRAS = 7;
function gedraaidBed(s) { return !!(s && (s.draai || s.model === 'bedz')); }
function inBed(d, kamerId, slotId) {
  var s = Rooms.slot(kamerId, slotId);
  if (!s) return false;
  d.route = null; d.eindDoel = null; d.slaapDoel = null;
  d.kamer = kamerId; d.bedPlek = { kamer: kamerId, slot: slotId };
  d.x = s.x; d.z = s.z; d.px = d.x; d.pz = d.z;
  d.lift = -MATRAS * HG;
  d.zet('slaap', 0); d.face = gedraaidBed(s) ? -1 : 1;
  /* de houding hier meteen zetten: in rustmodus tikt er niets, dus anders
     bleef een slaper in rustmodus rechtop staan */
  d.pose = 'lig'; d.bob = 0; d.zij = 0;
  vuil = true;
  return true;
}
function slaap(id, kamerId, slotId) {
  var d = vind(id);
  if (!d) return;
  var s = Rooms.slot(kamerId, slotId);
  if (!s) return;
  /* In rustmodus loopt er niemand: dan gaat het dier meteen liggen, anders
     bleef het aan de zijkant van het bed staan. Verder wandelt het naar de
     STA-PLEK naast het bed en stapt het bij aankomst in (slaapDoel).
     reisNaar() wist een oud slaapDoel, dus dit hoort er ná. */
  if (d.kamer === kamerId || rustModus) {
    inBed(d, kamerId, slotId);
  } else {
    reisNaar(id, kamerId, { x: s.sx, z: s.sz, na: 'wacht' });
    d.slaapDoel = { kamer: kamerId, slot: slotId };
  }
  vuil = true;
}

function setBak(kamerId, slotId, niveau) {
  var b = bakken[kamerId + '|' + slotId];
  if (!b) return;
  b.eten = Math.max(0, Math.min(4, niveau | 0));
  vuil = true;
}
function bakStand(kamerId, slotId) {
  var b = bakken[kamerId + '|' + slotId];
  return b ? b.eten : 0;
}
/* Art.setFood(id, ...) komt hier binnen: het bakje van de kamer waar dit
   dier is. Zo blijft de brug tussen art.js en de wereld ongewijzigd. */
function setFood(id, niveau) {
  var d = vind(id);
  if (!d) return;
  if (d.staat === 'eet') return;
  var b = bakVan(d);
  if (!b) return;
  b.eten = Math.max(0, Math.min(4, niveau | 0));
  vuil = true;
}

function feed(ids) {
  (ids || []).forEach(function (id) {
    var d = vind(id);
    if (!d) return;
    var b = bakVan(d);
    if (!b) return;
    d.route = null; d.eindDoel = null; d.slaapDoel = null; d.lift = 0;
    if (rustModus) { d.stilzetten('blijA'); b.eten = 0; return; }
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
    if (d.staat === 'slaap') return;              /* wie slaapt, laten we slapen */
    if (rustModus) { var q = d.sipPlek(); d.x = q[0]; d.z = q[1]; d.face = 1; d.stilzetten('zitsip'); return; }
    if (d.staat === 'sip' || (d.staat === 'loop' && d.na === 'sip')) return;
    var p = d.sipPlek();
    d.slaapDoel = null;
    d.ga(p[0], p[1], 'sip');
  } else if (m === 'happy') {
    if (rustModus) { d.stilzetten('blijA'); return; }
    if (d.staat !== 'eet' && d.staat !== 'blij' && d.staat !== 'slaap') d.zet('blij', 50 + Math.floor(d.rnd() * 30));
  } else {
    if (rustModus) { d.stilzetten('rust'); return; }
    if (d.staat === 'sip') d.kies();
  }
  vuil = true;
}

/* vignet: dit dier gaat op een vrije plek in zijn kamer zijn ding doen */
function solo(id, act) {
  var d = vind(id);
  if (!d) return;
  var p = vrijePlek(d);
  if (rustModus) { d.x = p[0]; d.z = p[1]; d.stilzetten('blijA'); return; }
  d.route = null; d.eindDoel = null; d.slaapDoel = null; d.lift = 0;
  d.ga(p[0], p[1], 'blij');
  vuil = true;
}

/* ---------- P1c: bewegen met een belofte (zie OPDRACHTEN bij Dier) ----------
   loopNaar(id, x, z, o) en stappen(id, punten, o) met o = {pose, tempo,
   perStap, na} geven een Promise<boolean>: true als het dier het laatste punt
   heeft gehaald, false zodra een ander bevel het dier overneemt (nooit een
   reject). pose(id, naam, duur) zet één houding.
   In rustmodus beweegt er niets: het dier gaat langs de punten (perStap per
   punt, op volgorde), staat op het laatste en de belofte is meteen true. */
function odPunt(p) {
  var q = Array.isArray(p) ? { x: +p[0], z: +p[1] } : { x: +(p || {}).x, z: +(p || {}).z };
  return isFinite(q.x) && isFinite(q.z) ? q : null;
}
function odLijst(punten) {
  var lijst = [], i, q;
  for (i = 0; i < (punten || []).length; i++) { q = odPunt(punten[i]); if (q) lijst.push(q); }
  return lijst;
}
/* rustmodus: geen loopjes en geen deeltjes, wel dezelfde haakjes en hetzelfde
   eindresultaat als een echte opdracht */
function odRust(d, lijst, o, klaar) {
  var i, p, haak = typeof o.perStap === 'function' ? o.perStap : null;
  d.opdrachtStop(false);
  d.route = null; d.eindDoel = null; d.slaapDoel = null;
  d.lift = 0; d.hoogte = 0;                        /* uit het water, uit de lucht */
  d.pluis.length = 0;
  if (!lijst.length) { klaar(true); return; }
  for (i = 0; i < lijst.length; i++) {
    p = lijst[i];
    d.face = (p.x - d.x) - (p.z - d.z) >= 0 ? 1 : -1;
    d.x = p.x; d.z = p.z; d.px = d.x; d.pz = d.z;
    d.tx = d.x; d.tz = d.z;                        /* geen loopdoel laten hangen */
    if (haak) { try { haak(i, p); } catch (e) { if (window.console) console.error('perStap', e); } }
  }
  var na = o.na || (o.pose === 'zwem' ? 'zwem' : 'wacht');
  if (na === 'zwem' || na === 'spring') { d.zet(na, 0); d.houdingTik(); }
  else d.stilzetten(OD_STIL[na] || 'rust');
  vuil = true;
  klaar(true);
}
function stappen(id, punten, o) {
  o = o || {};
  var d = vind(id), lijst = odLijst(punten);
  return new Promise(function (klaar) {
    try {
      if (!d) { klaar(false); return; }            /* onbekend dier: meteen false */
      if (!lijst.length) { klaar(true); return; }  /* geen punten = geen bevel: niets afbreken */
      if (rustModus) odRust(d, lijst, o, klaar);
      else d.opdrachtStart(lijst, o, klaar);
    } catch (e) {
      if (window.console) console.error('stappen', e);
      klaar(false);
    }
  });
}
function loopNaar(id, x, z, o) { return stappen(id, [{ x: x, z: z }], o); }
/* Een houding zetten: een dun laagje over zet() voor de toestanden die de
   motor al kent (stil/rust, zit, kijk, snuif, blij, wacht, sip) plus de
   nieuwe zwem en spring. duur in tikken (15 per seconde); 0 betekent voor
   zwem, spring, wacht en sip: tot het volgende bevel. */
function poseZet(id, naam, duur) {
  var d = vind(id);
  if (!d) return false;
  naam = naam === 'rust' ? 'stil' : (naam || 'stil');
  if (OD_STAAT.indexOf(naam) < 0) return false;    /* onbekende houding: niets veranderen */
  d.route = null; d.eindDoel = null; d.slaapDoel = null;
  d.lift = 0; d.hoogte = 0;
  duur = duur > 0 ? Math.round(duur) : (OD_DUUR[naam] || 0);
  if (naam === 'zwem' || naam === 'spring') { d.zet(naam, duur); d.houdingTik(); }
  else if (rustModus) d.stilzetten(OD_STIL[naam] || 'rust');
  else if (naam === 'stil') d.zet('stil', duur || 10);
  else { d.zet(naam, duur); if (naam === 'sip' || naam === 'wacht') d.face = 1; }
  vuil = true;
  return true;
}
/* Voor de spellen: registry.js (ctxVoor) laat elke uitbreiding uit deze lijst
   één keer per spel over de ctx lopen, dus registry.js hoeft niet mee te
   veranderen. Dezelfde drie staan ook op World zelf (zie api, onderaan). */
(window.CTX_UITBREIDINGEN = window.CTX_UITBREIDINGEN || []).push(function (c) {
  if (!c || !c.wereld) return;
  c.wereld.loopNaar = loopNaar;
  c.wereld.stappen = stappen;
  c.wereld.pose = poseZet;
});

function naar(kamerId, meteen) {
  var r = Rooms.get(kamerId);
  if (!r || kamerId === kamerNu) return false;
  var oudIdx = 0, nieuwIdx = 0, L = Rooms.lijst(), i;
  for (i = 0; i < L.length; i++) { if (L[i].id === kamerNu) oudIdx = i; if (L[i].id === kamerId) nieuwIdx = i; }
  kamerNu = kamerId;
  /* Elke ruimte heeft zijn eigen voxelmaat (maatVan): eerst opmeten, dan pas
     het camera-doel uitrekenen. Anders schuift de camera in de maat van de
     vorige kamer en springt het beeld aan het eind van de reis. */
  meet();
  var doel = camDoel(r);
  if (meteen || rustModus || !W) { camZet(); reis = null; vuil = true; return true; }
  var schuif = (nieuwIdx >= oudIdx ? 1 : -1) * W * 0.40;
  reis = { t0: (window.performance && performance.now ? performance.now() : Date.now()),
           van: [doel[0] + schuif, doel[1]], naar: doel, alfa: 0.35 };
  camX = Math.round(reis.van[0]); camY = Math.round(reis.van[1]);
  vuil = true;
  return true;
}

function toon(ja) {
  tonen = !!ja;
  if (host) host.classList.toggle('uit', !tonen);
  if (tonen) { vuil = true; vorigeTik = 0; }
}
function vuilMaken() { vuil = true; }

/* =====================================================================
   MIKPUNT: waar in de wereld hangt dit ding?
   Een spel mag een voorwerp aanwijzen met een naam ('bel', 'kar', 'bed1'),
   met een dier-id ('boef') of met losse coördinaten {x, z, kamer, y}.
   ui.wolk, ui.somkaart en wereld.getalTag gebruiken dit allemaal.
===================================================================== */
function mik(obj, kamerId) {
  if (!obj && obj !== 0) return null;
  if (typeof obj === 'object') {
    if (obj.dier) return mik(obj.dier, kamerId);
    if (obj.x === undefined) return null;
    return { kamer: obj.kamer || kamerId || kamerNu, x: obj.x, z: obj.z, y: obj.y || 0, volg: null };
  }
  var d = vind(obj);
  if (d) {
    return { kamer: d.kamer, x: d.x, z: d.z, y: 0, dier: obj,
             volg: function () { var q = vind(obj); return q ? { x: q.x, z: q.z, kamer: q.kamer } : null; } };
  }
  var t = ding(obj);
  if (t) {
    return { kamer: t.kamer, x: t.x, z: t.z, y: t.y || 0, ding: obj,
             volg: function () { var q = ding(obj); return q ? { x: q.x, z: q.z, kamer: q.kamer } : null; } };
  }
  var lijst = kamerId ? [kamerId] : [kamerNu].concat(Rooms.lijst().map(function (r) { return r.id; }));
  for (var i = 0; i < lijst.length; i++) {
    var r = Rooms.get(lijst[i]);
    if (!r) continue;
    var sl = Rooms.slot(lijst[i], obj);
    if (sl) return { kamer: lijst[i], x: sl.x, z: sl.z, y: 0, volg: null };
    for (var j = 0; j < r.decor.length; j++)
      if (r.decor[j].n === obj || r.decor[j].meubel === obj)
        return { kamer: lijst[i], x: r.decor[j].x, z: r.decor[j].z, y: r.decor[j].y || 0, volg: null };
  }
  /* als laatste: een los stuk van een spel (zie LOS DECOR) */
  return losMik(obj, kamerId);
}

/* een cijfer ÓP een voorwerp (het aantal in een bakje, het bedrag op de
   toonbank, het nummer van een haakje). n = null haalt het weg. */
function getalTag(obj, n, o) {
  o = o || {};
  /* een eigen id gaat vóór: zo kun je meerdere cijfers bij één voorwerp
     hangen (spookmunten) en ze later met dezelfde sleutel weghalen */
  var sleutel = 'getal_' + (o.id || (typeof obj === 'string' ? obj
                  : ((obj && obj.id) || (obj.x + '_' + obj.z))));
  if (n === null || n === undefined || n === false) { Hits.weg(sleutel); return null; }
  var p = mik(obj, o.kamer);
  if (!p) return null;
  Hits.maak({
    id: sleutel, door: o.door || 'wereld', kamer: p.kamer,
    x: p.x, z: p.z, y: o.y === undefined ? 8 : o.y,
    /* een doosje, geen knop: een cijfer op een bakje hoort niet in de
       tab-volgorde en is niet aan te tikken */
    kind: 'tag', tagnaam: 'div', klas: 'hotgetal' + (o.klas ? ' ' + o.klas : ''),
    html: '<span class="getal">' + n + '</span>', titel: o.titel || String(n),
    /* standaard laag in de rij (het is maar een cijfertje), maar een spel mag
       hem hoger zetten als het cijfer belangrijker is dan een knop erbij */
    prio: o.prio === undefined ? 4 : o.prio,
    volg: p.volg ? function () {
      var q = p.volg();
      return q ? { x: q.x, z: q.z, y: o.y === undefined ? 8 : o.y } : null;
    } : null
  });
  return sleutel;
}

/* Hoe groot is een voxel op het scherm? Handig als een spel zelf een rijtje
   wil uitzetten: horizontaal telt (x - z), verticaal (x + z) en de hoogte y.
     css-x  ~  2k * (x - z)        met k = g / dicht  (NIET devicePixelRatio:
     css-y  ~  k  * (x + z - 2y)    het canvas staat vaak dichter, zie meet())
   Twee knoppen staan pas echt naast elkaar bij ongeveer 30 voxels verschil
   in (x - z), of 50 in (x + z - 2y). */
function schaal() {
  var k = g / (dpr || 1);
  return { g: g, dpr: dpr, k: k,
           pxPerVoxelX: 2 * k,      /* per stap in (x - z) */
           pxPerVoxelY: k,          /* per stap in (x + z) */
           pxPerHoogte: 2 * k };    /* per stap in y */
}

/* de vloer van de kamer als rechthoek op het scherm (css-px in het kader) */
function vloerRect() {
  var r = kamer();
  if (!r) return null;
  var pts = [[0, 0], [r.w, 0], [r.w, r.d], [0, r.d]], i, p, x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9;
  for (i = 0; i < pts.length; i++) {
    p = projectie(pts[i][0], pts[i][1], 0);
    if (p.x < x0) x0 = p.x;
    if (p.x > x1) x1 = p.x;
    if (p.y < y0) y0 = p.y;
    if (p.y > y1) y1 = p.y;
  }
  return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
}

function debug() {
  var o = { kamer: kamerNu, rustig: rustModus, tonen: tonen, g: g,
            /* dicht = canvas-px per css-px (kan een breuk zijn, zie maatVan),
               q = css-px per voxel-px. Reken NOOIT met devicePixelRatio zelf:
               het canvas staat vaak op een hogere dichtheid dan het scherm. */
            dpr: dpr, q: g / (dpr || 1), canvas: [W, H],
            cam: [camX, camY], reis: !!reis, dieren: {}, bakken: {}, dingen: {},
            kader: host ? [Math.round(host.clientWidth), Math.round(host.clientHeight)] : null,
            box: (kamer() || {}).box || null, vloer: vloerRect() };
  for (var i = 0; i < dieren.length; i++) {
    var d = dieren[i];
    o.dieren[d.id] = { staat: d.staat, pose: d.pose, naam: d.naam, kamer: d.kamer,
                       x: Math.round(d.x * 10) / 10, z: Math.round(d.z * 10) / 10,
                       bijBak: d.bijBak(), face: d.face, route: d.route ? d.route.slice() : null,
                       pluis: d.pluis.length, doel: [d.tx, d.tz] };
  }
  for (var k in bakken) o.bakken[k] = bakken[k].eten;
  for (i = 0; i < dingen.length; i++) o.dingen[dingen[i].sleutel] = { kamer: dingen[i].kamer, x: dingen[i].x, z: dingen[i].z };
  /* de vloerplaat-cache en het losse decor (P1b) */
  o.platen = plaatOrde.length;
  o.losDecor = {};
  for (k in losDecor) if (losDecor[k].length) o.losDecor[k] = losDecor[k].length;
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
  bouwBakken();
  bouwDingen();
  host.classList.toggle('uit', !tonen);
  meet();
  Art.wereld(api);
  window.addEventListener('resize', function () { vuil = true; });
  window.addEventListener('orientationchange', function () { vuil = true; });
  requestAnimationFrame(lus);
}

var api = { sync: sync, setFood: setFood, setBak: setBak, bakStand: bakStand,
            feed: feed, mood: mood, solo: solo, slaap: slaap,
            ga: ga, reis: reisNaar, zet: zet, naar: naar, actief: function () { return kamerNu; },
            dingZet: dingZet, dingPlek: ding, vuil: vuilMaken, herbouw: herbouw,
            mik: mik, getalTag: getalTag, vloer: vloerRect, schaal: schaal,
            heeft: heeft, toon: toon, debug: debug, dier: vind,
            klaar: function () { return aan; } };
/* los decor van minigames (zie LOS DECOR); door = eigenaar, weglaten = bevoorrecht */
api.decor = decorZet;
api.decorWeg = decorWeg;
api.decorLijst = decorLijst;
api.decorWisEigenaar = decorWisEigenaar;

/* P1c: bewegen met een belofte, ook rechtstreeks via World (zie stappen) */
api.loopNaar = loopNaar; api.stappen = stappen; api.pose = poseZet;

begin();
if (!aan) {
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', begin);
  else begin();
}

return api;
})();
