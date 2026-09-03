/* ---------------------------------------------------------------
   world.js - het hotel als isometrische voxelwereld.

   Eén ruimte vult altijd het kader: we zoomen NOOIT uit, we verhuizen.
   Van kamer naar kamer schuift de camera in 300 ms door (kamer-camera,
   HOTEL.md 1). De voxelschaal blijft een heel getal, dus de blokjes
   blijven altijd even scherp.

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
}

Dier.prototype.zet = function (staat, duur, na) {
  this.staat = staat; this.t = 0; this.duur = duur || 0; this.na = na || null;
  if (staat !== 'loop') {
    this.v = 0;
    if (this.rnd() < 0.8) this.face = 1;
  }
};
Dier.prototype.ga = function (tx, tz, na) {
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
  if (this.na === 'eet') { this.zet('eet', 0); this.hap = 0; }
  else if (this.na === 'sip') { this.zet('sip', 0); this.face = 1; }
  else if (this.na === 'wacht') {
    this.zet('wacht', 0); this.face = 1;
    /* onderweg naar bed? dan stapt het dier er nu in */
    if (this.slaapDoel && this.slaapDoel.kamer === this.kamer) {
      var sd = this.slaapDoel;
      this.slaapDoel = null;
      inBed(this, sd.kamer, sd.slot);
    }
  }
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
  if (this.staat === 'slaap') {                     /* in bed: rustig ademen */
    this.pose = this.t % 60 < 30 ? 'zit' : 'zitsip';
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
  if (this.staat === 'loop') {
    var dx = this.tx - this.x, dz = this.tz - this.z;
    var d = Math.sqrt(dx * dx + dz * dz);
    if (d < this.vmax) { this.x = this.tx; this.z = this.tz; this.px = this.x; this.pz = this.z; this.aangekomen(); }
    else { this.x += dx / d * this.vmax; this.z += dz / d * this.vmax; this.px = this.x; this.pz = this.z; }
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

Dier.prototype.stilzetten = function (pose) {
  this.staat = 'stil'; this.pose = pose || 'rust';
  this.bob = 0; this.zij = 0; this.v = 0; this.pluis.length = 0;
  this.px = this.x; this.pz = this.z;
  vuil = true;
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
  return [W / 2 - (b[0] + b[1]) / 2 * g, H / 2 - (b[2] + b[3]) / 2 * g];
}
function camZet() {
  var c = camDoel(kamer());
  camX = Math.round(c[0]); camY = Math.round(c[1]);
}

/* =====================================================================
   HET KADER PAST ZICH AAN DE KAMER AAN
   De voxelschaal is een heel getal (nooit uitzoomen), dus we kunnen de
   kamer niet groter maken dan g toestaat. Wat we WEL doen: het kader net
   zo hoog maken als de hoogste kamer plus een strook eronder voor het
   cijferpad. Anders staat de kamer klein in een zee van lucht.
===================================================================== */
var KADER_ONDER = 132;          /* css-px onder de kamer: daar past het pad */
function hoogsteKamer() {
  var h = 0;
  Rooms.lijst().forEach(function (r) {
    var b = r.box || Rooms.kader(r);
    if (b[3] - b[2] > h) h = b[3] - b[2];
  });
  return h;
}
/* geeft true als de hoogte van het kader veranderd is */
function pasKader(ng, breedte) {
  if (!host) return false;
  if (document.body && document.body.classList.contains('metpaneel')) {
    /* een spel met een rekenblad ernaast: laat de opmaak het regelen */
    if (host.style.height) { host.style.height = ''; host.style.maxHeight = ''; return true; }
    return false;
  }
  var staand = window.innerHeight >= window.innerWidth;
  var ruim = Math.round(window.innerHeight * (staand ? 0.66 : 0.86));
  var kamerCss = hoogsteKamer() * ng / Math.min(3, window.devicePixelRatio || 1);
  var wil = Math.round(Math.min(ruim, kamerCss + KADER_ONDER));
  wil = Math.max(200, wil);
  if (host.style.height === wil + 'px') return false;
  host.style.height = wil + 'px';
  host.style.maxHeight = wil + 'px';
  return true;
}

function meet() {
  if (!host) return false;
  var r = host.getBoundingClientRect();
  if (r.width < 8 || r.height < 8) return false;
  dpr = Math.min(3, window.devicePixelRatio || 1);
  var ng = Math.max(2, Math.min(4, Math.round(Math.max(240, Math.round(r.width * dpr)) / 370)));
  if (pasKader(ng, r.width)) r = host.getBoundingClientRect();
  var nw = Math.max(240, Math.round(r.width * dpr)), nh = Math.max(180, Math.round(r.height * dpr));
  if (nw === W && nh === H && ng === g) return false;
  W = nw; H = nh; g = ng;
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
function decorPlaat(naam) {
  return K.cache('h|' + naam + '|' + g, function () {
    return K.plaat(K.bake(Rooms.model(naam)), g);
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
function tekenDier(d, mengen) {
  var x = d.px + (d.x - d.px) * mengen, z = d.pz + (d.z - d.pz) * mengen;
  var a = K.dierAnker;
  var ox = ((x - a[0]) - (z - a[1])) * S * g + d.zij * g;
  var oy = ((x - a[0]) + (z - a[1])) * (S / 2) * g + (d.bob + d.lift) * g;
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
    lijst.push({ n: it.n, x: it.x, z: it.z, y: it.y || 0,
                 d: it.x + it.z + (it.y ? 0.3 : 0) - (it.ver ? 1000 : 0) });
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
    if (q.n) put(decorPlaat(q.n), schermX(q.x, q.z), schermY(q.x, q.z) - (q.y || 0) * HG * g);
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
  kar: { keuken: { x: 32, z: 44 }, gang: { x: 60, z: 20 },
         kamer1: { x: 44, z: 44 }, kamer2: { x: 44, z: 44 },
         receptie: { x: 56, z: 24 } }
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
  d.route = null; d.eindDoel = null; d.lift = 0;
  d.zet('stil', 12);
  vuil = true;
}

function ga(id, x, z, na) {
  var d = vind(id);
  if (!d) return;
  d.route = null; d.eindDoel = null; d.lift = 0;
  if (rustModus) { d.x = x; d.z = z; d.px = x; d.pz = z; d.stilzetten('rust'); return; }
  d.ga(x, z, na || 'stil');
  vuil = true;
}

/* door de deuren naar een andere kamer; doel = {x,z,na} in die kamer */
function reisNaar(id, kamerId, doel) {
  var d = vind(id);
  if (!d) return [];
  var p = Rooms.pad(d.kamer, kamerId);
  d.lift = 0;
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

/* in bed: het dier ligt op de matras en slaapt rustig */
function inBed(d, kamerId, slotId) {
  var s = Rooms.slot(kamerId, slotId);
  if (!s) return;
  d.route = null; d.eindDoel = null; d.slaapDoel = null;
  d.kamer = kamerId;
  d.x = s.x - 1; d.z = s.z; d.px = d.x; d.pz = d.z;
  d.lift = -6 * HG;
  d.zet('slaap', 0); d.face = 1;
  vuil = true;
}
function slaap(id, kamerId, slotId) {
  var d = vind(id);
  if (!d) return;
  var s = Rooms.slot(kamerId, slotId);
  if (!s) return;
  if (d.kamer === kamerId) {
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
    d.route = null; d.eindDoel = null; d.lift = 0;
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
    if (rustModus) { var q = d.sipPlek(); d.x = q[0]; d.z = q[1]; d.face = 1; d.stilzetten('zitsip'); return; }
    if (d.staat === 'sip' || (d.staat === 'loop' && d.na === 'sip')) return;
    if (d.staat === 'slaap') return;
    var p = d.sipPlek();
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
  d.route = null; d.eindDoel = null; d.lift = 0;
  d.ga(p[0], p[1], 'blij');
  vuil = true;
}

function naar(kamerId, meteen) {
  var r = Rooms.get(kamerId);
  if (!r || kamerId === kamerNu) return false;
  var vanaf = [camX, camY];
  var oudIdx = 0, nieuwIdx = 0, L = Rooms.lijst(), i;
  for (i = 0; i < L.length; i++) { if (L[i].id === kamerNu) oudIdx = i; if (L[i].id === kamerId) nieuwIdx = i; }
  kamerNu = kamerId;
  var doel = camDoel(r);
  if (meteen || rustModus || !W) { camZet(); reis = null; vuil = true; return true; }
  var schuif = (nieuwIdx >= oudIdx ? 1 : -1) * W * 0.40;
  reis = { t0: (window.performance && performance.now ? performance.now() : Date.now()),
           van: [doel[0] + schuif, vanaf[1]], naar: doel, alfa: 0.35 };
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
  return null;
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
     css-x  ~  2k * (x - z)        met k = g / devicePixelRatio
     css-y  ~  k  * (x + z - 2y)
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
  var o = { kamer: kamerNu, rustig: rustModus, tonen: tonen, g: g, canvas: [W, H],
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

begin();
if (!aan) {
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', begin);
  else begin();
}

return api;
})();
