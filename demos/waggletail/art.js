/* ---------------------------------------------------------------
   art.js - voxel-dieren voor de Kwispelsteeg.
   Isometrisch (2:1 dimetrisch), painter's algorithm.

   Resolutie-opzet (belangrijk):
     * De modellen staan op een fijn raster: 21-29 voxels lang,
       10-18 diep, 23-28 hoog (was 15 x 8 x 16). Daardoor zijn
       pootjes met voetjes, snuit, oortjes en staart echte vormen
       in plaats van één blokje.
     * Elk <canvas> wordt op APPARAAT-resolutie getekend: de
       voxelvlakken gaan door een hele schaalfactor
       G = ceil(cssbreedte * devicePixelRatio / rasterbreedte),
       dus het canvas is nooit kleiner dan het scherm en er is
       geen wazige nearest-neighbour opschaling meer.
     * Vlakken krijgen 3 richtingstinten x 5 stapjes hoekdonkering
       (ambient occlusion) plus een dun donker randje, zodat de
       vlakken ook klein netjes leesbaar blijven.
     * Per houding (en per bakje-niveau) wordt één plaatje op een
       offscreen canvas gebakken en daarna alleen nog geblit, dus
       12 fps met 5 dieren kost bijna niets.

   Publiek (ongewijzigd):
     Art.animal(a, mood, extraClass) -> html-plaatshouder
     Art.setFood(id, aantal, per)    -> vult het voerbakje
     Art.feast(ids)                  -> eten -> blij
     Art.setMood(id, mood)           -> 'blij' | 'droopy' | 'bouncy'
     Art.debug()                     -> stand van zaken (voor tests)
---------------------------------------------------------------- */
var Art = (function () {
'use strict';

/* ---------- palet: b = vacht, d = donkere vacht, e = accent, l = licht ----------
   ZACHTHEID: de tinten zijn iets warmer en de contrasten kleiner dan in de
   eerste versie. Ogen en neusjes zijn niet meer bijna-zwart maar warm bruin;
   dat haalt de robot-blik uit de koppen. */
var INK = '#4A3B33', WIT = '#FFF7EC';
var OOG = '#5B4840';           /* oogje: zacht donkerbruin, nooit zwart */
var NEUS = '#7E6255';          /* neus / mondlijntje: nog een stap zachter */
var PAL = {
  hond:   { b: '#EEC194', d: '#D3996A', e: '#B4744A', l: '#FCE8D3' },
  poes:   { b: '#C9CCDC', d: '#A0A6C0', e: '#F4C8D5', l: '#EDEFF6' },
  konijn: { b: '#F5E7EC', d: '#DCC6D3', e: '#F5B0C2', l: '#FFFBF6' },
  gans:   { b: '#FDF8EA', d: '#E0D8C2', e: '#F6A957', l: '#FFFCF4' }
};
var KOM = { schaal: '#DFC6D6', rand: '#F8E7F1', brok: '#BC8149', brok2: '#97663A' };
var BAND = '#6BC5A4';          /* halsbandje van de hond */

/* ---------- isometrie: 1 voxel = 2S breed, S hoog (top), HG diep ---------- */
var S = 2, HG = 2;
/* zachter licht: minder afstand tussen boven-, rechter- en linkervlak */
var F_TOP = 1.10, F_RECHTS = 0.90, F_LINKS = 0.72;
/* hoekdonkering: hoe meer buren tegen een vlak aan, hoe donkerder (nu subtieler) */
var AO = [1, 0.972, 0.946, 0.928, 0.914];
var RAND_INK = 'rgba(112,90,76,.26)';  /* dun, zacht contourlijntje */

/* Licht en schaduw als kleurmenging in plaats van een kale vermenigvuldiging:
   licht loopt naar warm ivoor, schaduw naar een zachte violet-bruine tint.
   Dat is precies het verschil tussen "plastic blokje" en "geverfd hout". */
var WARM = [255, 248, 236], KOEL = [116, 100, 116];
var tint = Object.create(null);
function shade(hex, m) {
  var k = hex + '|' + m;
  var c = tint[k];
  if (c) return c;
  var n = parseInt(hex.slice(1), 16);
  var r = n >> 16 & 255, g = n >> 8 & 255, b = n & 255;
  var doel = m >= 1 ? WARM : KOEL;
  var t = m >= 1 ? Math.min(1, (m - 1) * 1.25) : Math.min(1, (1 - m) * 1.55);
  r = Math.max(0, Math.min(255, Math.round(r + (doel[0] - r) * t)));
  g = Math.max(0, Math.min(255, Math.round(g + (doel[1] - g) * t)));
  b = Math.max(0, Math.min(255, Math.round(b + (doel[2] - b) * t)));
  return (tint[k] = 'rgb(' + r + ',' + g + ',' + b + ')');
}

/* ---------- bouwstenen ---------- */
function bx(v, x, y, z, w, h, d, c) {
  x = Math.round(x); y = Math.round(y); z = Math.round(z);
  for (var i = 0; i < w; i++)
    for (var j = 0; j < h; j++)
      for (var k = 0; k < d; k++) v.push([x + i, y + j, z + k, c]);
}
/* superellipsoïde: ronde lijven en koppen zonder harde trapjes.
   o.e = bolligheid (2 = ei, 3 = afgeronde kubus), o.ymin = platte onderkant */
function ell(v, cx, cy, cz, rx, ry, rz, c, o) {
  o = o || {};
  var e = o.e || 2.2, lim = o.lim || 1.02;
  var ymin = o.ymin === undefined ? -1e9 : o.ymin;
  var x, y, z, ax, ay, az;
  for (x = Math.ceil(cx - rx); x <= Math.floor(cx + rx); x++) {
    ax = Math.pow(Math.abs((x - cx) / rx), e);
    if (ax > lim) continue;
    for (y = Math.max(Math.ceil(cy - ry), ymin); y <= Math.floor(cy + ry); y++) {
      ay = Math.pow(Math.abs((y - cy) / ry), e);
      if (ax + ay > lim) continue;
      for (z = Math.ceil(cz - rz); z <= Math.floor(cz + rz); z++) {
        az = Math.pow(Math.abs((z - cz) / rz), e);
        if (ax + ay + az <= lim) v.push([x, y, z, c]);
      }
    }
  }
}
/* hals: een ronde koker (capsule) van (x0,y0) naar (x1,y1). Een rechte
   buis van blokjes geeft bij het happen een lelijk trappetje en een rij
   losse bollen geeft een dambord-rand; met de echte afstand-tot-lijn
   blijft de hals glad en vergroeit hij netjes met kop en lijf. */
function hals(v, x0, y0, x1, y1, cz, r, rz, c) {
  var dx = x1 - x0, dy = y1 - y0, L2 = dx * dx + dy * dy, x, y, z, t, qx, qy, d2, zr;
  for (x = Math.floor(Math.min(x0, x1) - r); x <= Math.ceil(Math.max(x0, x1) + r); x++) {
    for (y = Math.floor(Math.min(y0, y1) - r); y <= Math.ceil(Math.max(y0, y1) + r); y++) {
      t = L2 ? ((x - x0) * dx + (y - y0) * dy) / L2 : 0;
      t = t < 0 ? 0 : t > 1 ? 1 : t;
      qx = x0 + dx * t; qy = y0 + dy * t;
      d2 = (x - qx) * (x - qx) + (y - qy) * (y - qy);
      if (d2 > r * r) continue;
      zr = rz * (0.55 + 0.45 * Math.sqrt(1 - d2 / (r * r)));
      for (z = Math.ceil(cz - zr); z <= Math.floor(cz + zr); z++) v.push([x, y, z, c]);
    }
  }
}
/* spits oortje / puntige staart: wordt smaller naar boven toe */
function punt(v, x, y, z, w, h, d, c) {
  for (var j = 0; j < h; j++) {
    var ww = Math.max(1, w - Math.floor(j * w / h));
    bx(v, x, y + j, z, ww, 1, d, c);
  }
}
/* alleen bestaande voxels bijverven: ogen, neus, sokjes, halsband, bef.
   Zo landt een detail altijd op het buitenste vlak van de vorm en steekt
   er nooit iets los uit. */
function verf(v, x0, x1, y0, y1, z0, z1, c) {
  for (var i = 0; i < v.length; i++) {
    var p = v[i];
    if (p[0] >= x0 && p[0] <= x1 && p[1] >= y0 && p[1] <= y1 && p[2] >= z0 && p[2] <= z1) p[3] = c;
  }
}

/* ogen: blokje op de kop, gespiegeld in z, met een lichtje erin.
   o.h hoogte, o.w diepte, o.dik hoeveel lagen naar binnen (zodat het
   oog altijd op het buitenste vlak terechtkomt) */
function ogen(v, p, x, y, z1, z2, o) {
  o = o || {};
  var h = o.h || 2, w = o.w || 2, dik = o.dik || 2, yy = y;
  if (p.oog === 1) { yy = y + h - 1; h = 1; }         /* blij: knijpoogjes */
  else if (p.oog === 2) { h = Math.max(1, h - 1); }   /* sip: half dicht */
  else if (p.oog === -1) { yy = y - 1; }              /* naar het bakje kijken */
  verf(v, x, x + dik - 1, yy, yy + h - 1, z1, z1 + w - 1, OOG);
  verf(v, x, x + dik - 1, yy, yy + h - 1, z2 - w + 1, z2, OOG);
  if (h > 1 && o.glans !== false) {
    verf(v, x, x + dik - 1, yy + h - 1, yy + h - 1, z1, z1, WIT);
    verf(v, x, x + dik - 1, yy + h - 1, yy + h - 1, z2, z2, WIT);
  }
}
/* mond: 1 = open (blij/happend), 2 = zachte omlaag-mondhoekjes (sip) */
function mond(v, p, x, y, z1, z2, zacht) {
  if (p.mond === 1) verf(v, x, x + 1, y, y, z1 + 1, z2 - 1, NEUS);
  else if (p.mond === 2) {
    verf(v, x, x + 1, y, y, z1, z1, zacht || NEUS);
    verf(v, x, x + 1, y, y, z2, z2, zacht || NEUS);
  }
}

/* ---------- gang: welke poot staat vooruit (p.stap 0/1/2) ----------
   Eén klein getalletje per poot; de wereldmotor laat het tempo van de
   pasjes meelopen met de snelheid, dus versnellen en afremmen zie je. */
function duwen(stap) {
  var s = stap === 1 ? 1 : stap === 2 ? -1 : 0;
  return [s, -s, -s, s];        /* diagonaal: linksachter+rechtsvoor samen */
}

/* =====================================================================
   DE VIER DIEREN - raster: x = lengte (0 = staart, ~29 = neus),
   y = hoogte (0 = grond), z = diepte 0..15 met het hart op 7.5.
   Het voerbakje staat op x 26..33. Alles is ongeveer 2x zo fijn als
   de eerste versie: lijf ~14 lang / 9 hoog / 12 diep, kop ~9x11x12.
===================================================================== */

function hond(p) {
  var C = PAL.hond, v = [], hx = p.hx, hy = p.hy, i;
  var tz = p.staart === 'l' ? -2 : p.staart === 'r' ? 2 : 0;

  /* vier stevige pootjes met een licht voetje en een teenstreepje.
     Ze staan zo ver naar binnen dat het lijf de bovenkant netjes afdekt. */
  var poot = [[5, 3], [5, 9], [13, 3], [13, 9]], duw = duwen(p.stap), px, py, ph;
  for (i = 0; i < 4; i++) {
    px = poot[i][0] + duw[i] * 2;                 /* stap naar voren / naar achter */
    py = duw[i] > 0 ? 1 : 0;                      /* voorwaartse poot komt los */
    ph = 7 - py;
    bx(v, px, py, poot[i][1], 4, ph, 4, C.d);
    bx(v, px, py, poot[i][1], 5, 2, 4, C.l);
    verf(v, px, px + 4, py + 1, py + 1, poot[i][1] + 2, poot[i][1] + 2, C.d);
  }

  /* lijf: afgeronde doos met een plat rugje */
  ell(v, 10.5, 9.5, 7.5, 7.0, 4.4, 5.8, C.b, { e: 3.4, ymin: 5 });
  verf(v, 14, 18, 5, 9, 3, 12, C.l);                 /* lichte bef tussen de voorpoten */

  /* kwispelstaart: drie blokjes die vanuit het lijf omhoog krullen */
  if (p.staart === 'laag') {
    bx(v, 2, 7, 6, 3, 3, 3, C.d); bx(v, 0, 5, 6, 3, 3, 3, C.d); bx(v, 0, 4, 6, 2, 2, 3, C.l);
  } else {
    bx(v, 3, 9, 6 + tz, 3, 3, 3, C.d);
    bx(v, 2, 12, 6 + tz, 3, 3, 3, C.d);
    bx(v, 1, 15, 6 + tz, 2, 3, 3, C.l);
  }

  /* hals volgt de kop, zodat hij bij het happen niet losraakt */
  hals(v, 16, 12, 20 + hx, 15 + hy, 7.5, 2.8, 3.6, C.b);
  verf(v, 15, 16, 9, 12, 3, 12, BAND);               /* halsbandje op de bef */

  /* kop, snuit, neusje */
  ell(v, 22 + hx, 17 + hy, 7.5, 4.4, 5.0, 5.6, C.b, { e: 3.2 });
  ell(v, 27 + hx, 15 + hy, 7.5, 2.4, 2.4, 3.4, C.l, { e: 2.8 });
  verf(v, 28 + hx, 29 + hx, 16 + hy, 17 + hy, 7, 8, NEUS);

  /* flaporen: hangen langs de kop naar buiten, omhoog = blij.
     Ze zitten hoog op de kop; anders bungelt het verre oor over het lijf. */
  var oy = 17, ox = 21;
  if (p.oor === 'perk') oy = 21;
  else if (p.oor === 'hang') oy = 14;
  else if (p.oor === 'vooruit') { ox = 23; oy = 18; }
  ell(v, ox + hx, oy + hy, 0.6, 1.9, 3.4, 1.8, C.e, { e: 3.0 });
  ell(v, ox + hx, oy + hy, 14.4, 1.9, 3.4, 1.8, C.e, { e: 3.0 });

  mond(v, p, 28 + hx, 14 + hy, 6, 9, C.d);
  ogen(v, p, 25 + hx, 18 + hy, 4, 11, { h: 2, w: 2, dik: 2 });
  return v;
}

function poes(p) {
  var C = PAL.poes, v = [], hx = p.hx, hy = p.hy, i;
  var tz = p.staart === 'l' ? -2 : p.staart === 'r' ? 2 : 0;

  /* slanke pootjes met witte sokjes */
  var poot = [[6, 4], [6, 9], [13, 4], [13, 9]], duw = duwen(p.stap), px, py, ph;
  for (i = 0; i < 4; i++) {
    px = poot[i][0] + duw[i] * 2;
    py = duw[i] > 0 ? 1 : 0;
    ph = 8 - py;
    bx(v, px, py, poot[i][1], 3, ph, 3, C.d);
    bx(v, px, py, poot[i][1], 4, 3, 3, C.l);
    verf(v, px, px + 3, py + 2, py + 2, poot[i][1] + 1, poot[i][1] + 1, C.d);
  }

  /* lijf */
  ell(v, 10.5, 10.5, 7.5, 6.4, 4.2, 5.0, C.b, { e: 3.2, ymin: 6 });
  verf(v, 14, 17, 6, 10, 4, 11, C.l);                /* wit befje */

  /* lange staart met donkere ringen en een wit puntje */
  if (p.staart === 'laag') {
    bx(v, 4, 8, 7, 3, 3, 3, C.b); bx(v, 2, 6, 7, 3, 3, 3, C.b); bx(v, 1, 5, 7, 2, 2, 3, C.l);
  } else {
    bx(v, 4, 10, 6 + tz, 3, 4, 3, C.b);
    bx(v, 3, 13, 6 + tz, 3, 4, 3, C.b);
    bx(v, 3, 16, 6 + tz, 2, 3, 3, C.l);
    verf(v, 3, 6, 11, 11, 6 + tz, 8 + tz, C.d);
    verf(v, 3, 6, 14, 14, 6 + tz, 8 + tz, C.d);
  }

  hals(v, 15, 12, 19 + hx, 15 + hy, 7.5, 2.4, 3.0, C.b);

  /* kop met wangen, roze neusje en snorharen */
  ell(v, 21 + hx, 16.5 + hy, 7.5, 3.8, 4.0, 4.8, C.b, { e: 3.2 });
  ell(v, 25.5 + hx, 14.5 + hy, 7.5, 1.8, 1.8, 3.2, C.l, { e: 2.8 });
  verf(v, 26 + hx, 27 + hx, 15 + hy, 15 + hy, 7, 8, C.e);

  /* spitse oortjes met roze binnenkant; sip = plat naar buiten */
  if (p.oor === 'hang') {
    bx(v, 17 + hx, 18 + hy, 2, 3, 2, 3, C.b); bx(v, 17 + hx, 18 + hy, 11, 3, 2, 3, C.b);
    verf(v, 18 + hx, 19 + hx, 18 + hy, 19 + hy, 2, 2, C.e);
    verf(v, 18 + hx, 19 + hx, 18 + hy, 19 + hy, 13, 13, C.e);
  } else {
    var eo = p.oor === 'perk' ? 1 : 0, ex = p.oor === 'vooruit' ? 20 : 18;
    punt(v, ex + hx, 18 + eo + hy, 4, 3, 5, 3, C.b);
    punt(v, ex + hx, 18 + eo + hy, 9, 3, 5, 3, C.b);
    verf(v, ex + 1 + hx, ex + 1 + hx, 18 + eo + hy, 21 + eo + hy, 4, 5, C.e);
    verf(v, ex + 1 + hx, ex + 1 + hx, 18 + eo + hy, 21 + eo + hy, 9, 10, C.e);
  }

  mond(v, p, 26 + hx, 13 + hy, 6, 9, C.d);
  ogen(v, p, 24 + hx, 17 + hy, 4, 11, { h: 2, w: 2, dik: 2 });
  return v;
}

function konijn(p) {
  var C = PAL.konijn, v = [], hx = p.hx, hy = p.hy;
  var tz = p.staart === 'l' ? -1 : p.staart === 'r' ? 1 : 0;

  /* lange achtervoeten + kleine voorpootjes.
     Huppelen in plaats van lopen: stap 1 = zweven met de achtervoeten naar
     voren getrokken, stap 2 = landen. Zo beweegt het konijn niet in de
     maat van de hond. */
  var hs = p.stap === 1 ? 2 : p.stap === 2 ? -1 : 0, vy = p.stap === 1 ? 2 : 0;
  bx(v, 5 + hs, 0, 3, 7, 3, 4, C.l); bx(v, 5 + hs, 0, 9, 7, 3, 4, C.l);
  verf(v, 5 + hs, 11 + hs, 2, 2, 5, 5, C.d); verf(v, 5 + hs, 11 + hs, 2, 2, 11, 11, C.d);
  ell(v, 9 + hs, 5, 4.8, 3.5, 3.7, 2.3, C.b, { e: 3.0, ymin: 2 });
  ell(v, 9 + hs, 5, 10.2, 3.5, 3.7, 2.3, C.b, { e: 3.0, ymin: 2 });
  bx(v, 14, vy, 4, 3, 7 - vy, 3, C.b); bx(v, 14, vy, 9, 3, 7 - vy, 3, C.b);
  bx(v, 14, vy, 4, 4, 2, 3, C.l); bx(v, 14, vy, 9, 4, 2, 3, C.l);

  /* rond lijf */
  ell(v, 11, 10, 7.5, 6.2, 5.0, 5.2, C.b, { e: 3.2, ymin: 5 });
  verf(v, 14, 18, 5, 10, 4, 11, C.l);

  /* pluimstaartje achter het lijf */
  ell(v, 3.2, p.staart === 'laag' ? 9.5 : 12, 7.5 + tz, 2.3, 2.3, 2.3, C.l, { e: 3.0 });

  hals(v, 15, 13, 19 + hx, 16 + hy, 7.5, 2.6, 3.2, C.b);

  /* kop met snuitje, roze neus en tandjes */
  ell(v, 21 + hx, 17 + hy, 7.5, 4.2, 4.4, 5.2, C.b, { e: 3.2 });
  ell(v, 25.5 + hx, 15 + hy, 7.5, 1.8, 1.8, 3.0, C.l, { e: 2.8 });
  verf(v, 26 + hx, 27 + hx, 15 + hy, 15 + hy, 7, 8, C.e);
  verf(v, 26 + hx, 27 + hx, 13 + hy, 13 + hy, 7, 8, WIT);

  /* lange oren: rechtop, vooruit of slap langs de kop */
  if (p.oor === 'hang') {
    ell(v, 18 + hx, 13 + hy, 1.6, 1.8, 4.6, 1.6, C.d, { e: 3.0 });
    ell(v, 18 + hx, 13 + hy, 13.4, 1.8, 4.6, 1.6, C.d, { e: 3.0 });
    verf(v, 19 + hx, 20 + hx, 9 + hy, 17 + hy, 0, 1, C.e);
    verf(v, 19 + hx, 20 + hx, 9 + hy, 17 + hy, 14, 15, C.e);
  } else {
    var ox = p.oor === 'vooruit' ? 22 : 19, oh = p.oor === 'perk' ? 5.0 : 4.4;
    ell(v, ox + hx, 19 + oh + hy, 4.4, 1.8, oh, 1.6, C.d, { e: 3.0 });
    ell(v, ox + hx, 19 + oh + hy, 10.6, 1.8, oh, 1.6, C.d, { e: 3.0 });
    verf(v, ox + 1 + hx, ox + 1 + hx, 18 + hy, 28 + hy, 4, 5, C.e);
    verf(v, ox + 1 + hx, ox + 1 + hx, 18 + hy, 28 + hy, 10, 11, C.e);
  }

  mond(v, p, 26 + hx, 13 + hy, 6, 9, C.d);
  ogen(v, p, 24 + hx, 18 + hy, 4, 11, { h: 2, w: 2, dik: 2 });
  return v;
}

function gans(p) {
  /* de gans heeft een lange hals: die reikt verder dan een snuit */
  var C = PAL.gans, v = [];
  var hx = Math.round(p.hx * 2.5), hy = p.hy < 0 ? Math.round(p.hy * 2.2) : p.hy;
  var tz = p.staart === 'l' ? -1 : p.staart === 'r' ? 1 : 0;

  /* oranje zwempoten - waggelen: het ene been voor, het andere achter */
  var gs = p.stap === 1 ? 2 : p.stap === 2 ? -2 : 0;
  bx(v, 8 + gs, 0, 3, 5, 1, 3, C.e); bx(v, 8 - gs, 0, 10, 5, 1, 3, C.e);
  bx(v, 9 + gs, 1, 4, 2, 7, 2, C.e); bx(v, 9 - gs, 1, 10, 2, 7, 2, C.e);

  /* mollig lijf */
  ell(v, 10, 10.5, 7.5, 6.2, 4.6, 5.2, C.b, { e: 3.0, ymin: 5 });
  /* vleugels: platte panelen met één veerlijn */
  var wy = p.oor === 'perk' ? 11.5 : p.oor === 'hang' ? 9.5 : 10.5;
  ell(v, 10, wy, 2.0, 4.6, 3.0, 1.5, C.b, { e: 3.0 });
  ell(v, 10, wy, 13.0, 4.6, 3.0, 1.5, C.b, { e: 3.0 });
  verf(v, 8, 13, wy - 1, wy - 1, 1, 2, C.d);
  verf(v, 8, 13, wy - 1, wy - 1, 13, 14, C.d);
  /* puntige staart */
  punt(v, 3, p.staart === 'laag' ? 9 : 11, 6 + tz, 3, 3, 4, C.b);

  /* lange hals + kleine kop met snavel */
  var ky = 21 + hy;
  hals(v, 14, 13, 19 + hx, ky + 1, 7.5, 1.9, 2.2, C.b);
  ell(v, 19 + hx, ky + 3, 7.5, 2.8, 2.8, 3.0, C.b, { e: 2.8 });
  bx(v, 21 + hx, ky + 2, 6, 3, 2, 4, C.e);
  verf(v, 23 + hx, 23 + hx, ky + 3, ky + 3, 7, 7, C.d);
  if (p.mond === 1) bx(v, 21 + hx, ky + 1, 6, 3, 1, 4, C.e);
  else if (p.mond === 2) verf(v, 23 + hx, 23 + hx, ky + 2, ky + 2, 6, 9, C.d);
  ogen(v, p, 20 + hx, ky + 4, 5, 10, { h: 1, w: 1, dik: 2 });
  return v;
}

var SOORT = { hond: hond, poes: poes, konijn: konijn, gans: gans };

/* ---------- zitten: het achterlijf zakt, de kop blijft omhoog ----------
   Geen extra model per dier: we duwen de voxels van achter naar voren
   steeds minder omlaag. Zo zakt de staartkant naar de grond en houdt de
   snuit zijn hoogte - precies wat een dier doet dat gaat zitten. */
function zitten(v) {
  var i, x0 = 1e9, x1 = -1e9, t, zak;
  for (i = 0; i < v.length; i++) { if (v[i][0] < x0) x0 = v[i][0]; if (v[i][0] > x1) x1 = v[i][0]; }
  var sp = Math.max(1, x1 - x0);
  for (i = 0; i < v.length; i++) {
    t = (v[i][0] - x0) / sp;
    zak = Math.round((1 - t) * (1 - t) * 5);
    v[i][1] = Math.max(0, v[i][1] - zak);
  }
  return v;
}

/* ---------- houdingen (frame-poses, geen css-transforms) ---------- */
var POSE = {
  rust:  { hx: 0, hy: 0,  oor: 'rust',    staart: 'mid',  mond: 0, oog: 0 },
  tril:  { hx: 0, hy: 0,  oor: 'perk',    staart: 'r',    mond: 0, oog: 0 },
  hap1:  { hx: 1, hy: -4, oor: 'vooruit', staart: 'l',    mond: 1, oog: -1 },
  hap2:  { hx: 2, hy: -7, oor: 'vooruit', staart: 'r',    mond: 1, oog: -1 },
  blijA: { hx: 0, hy: 0,  oor: 'perk',    staart: 'l',    mond: 1, oog: 1 },
  blijB: { hx: 0, hy: 2,  oor: 'perk',    staart: 'r',    mond: 1, oog: 1 },
  /* sip = zacht verdrietig: kop iets omlaag naar het bakje, oren en staart hangen.
     Nooit huilen, nooit boos - het gezicht moet zichtbaar blijven. */
  sip:   { hx: 0, hy: -1, oor: 'hang',    staart: 'laag', mond: 2, oog: 2 },
  /* --- wereld-houdingen: zwaaien, rondkijken, lopen, zitten, snuffelen --- */
  zwaai: { hx: 0, hy: 0,  oor: 'rust',    staart: 'l',    mond: 0, oog: 0 },
  kijk:  { hx: -1, hy: 1, oor: 'perk',    staart: 'l',    mond: 0, oog: 0 },
  loopA: { hx: 1, hy: 0,  oor: 'rust',    staart: 'l',    mond: 0, oog: 0, stap: 1 },
  loopB: { hx: 1, hy: 0,  oor: 'rust',    staart: 'r',    mond: 0, oog: 0, stap: 2 },
  zit:   { hx: 0, hy: 1,  oor: 'rust',    staart: 'laag', mond: 0, oog: 0, zit: 1 },
  zitsip:{ hx: 0, hy: 0,  oor: 'hang',    staart: 'laag', mond: 2, oog: 2, zit: 1 },
  snuif: { hx: 1, hy: -6, oor: 'vooruit', staart: 'mid',  mond: 0, oog: -1 }
};
/* alleen deze houdingen bepalen hoe groot een dier-canvas moet zijn */
var POSE_NAMEN = ['rust', 'tril', 'hap1', 'hap2', 'blijA', 'blijB', 'sip', 'snuif', 'loopA'];

/* ---------- voerbakje: rond schaaltje rond (KOM_CX, KOM_CZ) ----------
   In het diorama staat het bakje op een houten matje in het gras; daar is
   een klein schaaltje niet meer te zien. Met groot = 1 rolt hetzelfde
   bakje ruim anderhalf keer zo groot uit de bak, met meer brokjes per
   niveau, zodat je het slinken ook van een afstandje ziet. */
var KOM_CX = 29.5, KOM_CZ = 7.5, KOM_R = 3.9, KOM_H = 4, KOM_VOOR = 38;
function komVox(niveau, groot) {
  var v = [], cel = [], x, z, q, mid, i, j;
  var R = groot ? 6.3 : KOM_R, HH = groot ? 6 : KOM_H, BOD = groot ? 3 : 2;
  var grens = groot ? KOM_CX + KOM_CZ + R * 0.72 : KOM_VOOR;
  var x0 = Math.floor(KOM_CX - R), x1 = Math.ceil(KOM_CX + R);
  var z0 = Math.floor(KOM_CZ - R), z1 = Math.ceil(KOM_CZ + R);
  for (x = x0; x <= x1; x++) {
    for (z = z0; z <= z1; z++) {
      q = Math.pow(Math.abs((x - KOM_CX) / R), 2.5) + Math.pow(Math.abs((z - KOM_CZ) / R), 2.5);
      if (q > 1) continue;
      mid = q < (groot ? 0.36 : 0.30);
      /* voorste wandje komt ná het dier op het canvas (dier hapt erin) */
      var voor = !mid && (x + z) >= grens ? 1 : 0;
      if (mid) { bx(v, x, 0, z, 1, BOD, 1, KOM.schaal); cel.push([x, z, q]); }
      else {
        bx(v, x, 0, z, 1, HH, 1, KOM.schaal);
        verf(v, x, x, HH - 1, HH - 1, z, z, KOM.rand);
        if (voor) for (i = v.length - HH; i < v.length; i++) v[i][4] = 1;
      }
    }
  }
  /* brokken: van het midden naar buiten opvullen */
  cel.sort(function (a, b) { return a[2] - b[2]; });
  var trap = groot ? [0, 10, 21, 34, 50] : [0, 3, 6, 10, 15];
  var n = trap[niveau] || 0;
  for (j = 0; j < n && j < cel.length * 2; j++) {
    var c = cel[j % cel.length], laag = BOD + (j < cel.length ? 0 : 1);
    v.push([c[0], laag, c[1], j % 3 === 2 ? KOM.brok2 : KOM.brok]);
  }
  return v;
}

/* ---------- bakken: voxels -> gesorteerde, gecullde vlakkenlijst ---------- */
function buur(map, x, y, z) { return map[x + '|' + y + '|' + z] !== undefined ? 1 : 0; }
function bake(vox) {
  var map = Object.create(null), i, v, k;
  for (i = 0; i < vox.length; i++) { v = vox[i]; map[v[0] + '|' + v[1] + '|' + v[2]] = v; }
  var out = [];
  for (k in map) {
    v = map[k];
    var x = v[0], y = v[1], z = v[2], c = v[3];
    var t = !buur(map, x, y + 1, z), r = !buur(map, x + 1, y, z), l = !buur(map, x, y, z + 1);
    if (!t && !r && !l) continue;
    var f = { d: x + y + z, px: (x - z) * S, py: (x + z) * (S / 2) - (y + 1) * HG,
              ct: null, cr: null, cl: null, voor: v[4] ? 1 : 0 };
    if (t) f.ct = shade(c, F_TOP * AO[buur(map, x + 1, y + 1, z) + buur(map, x - 1, y + 1, z) +
                                     buur(map, x, y + 1, z + 1) + buur(map, x, y + 1, z - 1)]);
    if (r) f.cr = shade(c, F_RECHTS * AO[buur(map, x + 1, y + 1, z) + buur(map, x + 1, y - 1, z) +
                                         buur(map, x + 1, y, z + 1) + buur(map, x + 1, y, z - 1)]);
    if (l) f.cl = shade(c, F_LINKS * AO[buur(map, x, y + 1, z + 1) + buur(map, x, y - 1, z + 1) +
                                        buur(map, x + 1, y, z + 1) + buur(map, x - 1, y, z + 1)]);
    out.push(f);
  }
  out.sort(function (a, b) { return a.d - b.d; });
  return out;
}

var poseCache = Object.create(null), komCache = [];
function bouw(kind, pose) {
  var p = POSE[pose] || POSE.rust;
  var v = (SOORT[kind] || hond)(p);
  return p.zit ? zitten(v) : v;
}
function faces(kind, pose) {
  var k = kind + '/' + pose;
  return poseCache[k] || (poseCache[k] = bake(bouw(kind, pose)));
}
function komFaces(n, groot) {
  var k = (groot ? 'g' : 'k') + n;
  return komCache[k] || (komCache[k] = bake(komVox(n, groot)));
}

/* ---------- canvasmaat: het bereik van alles wat we ooit tekenen ---------- */
var CW = 0, CH = 0, OX = 0, OY = 0, GEEN_KOM = 0, GEEN_KOM_Y = 0, klaar = false;
var SCHADUW = [3, 1, 19, 14];   /* x0,z0,x1,z1 op de grond */
var KRUIMEL = [0, 0], STER = [0, 0];

function extent(list, box) {
  for (var i = 0; i < list.length; i++) {
    var f = list[i];
    if (f.px - S < box[0]) box[0] = f.px - S;
    if (f.px + S > box[1]) box[1] = f.px + S;
    if (f.py < box[2]) box[2] = f.py;
    if (f.py + S + HG > box[3]) box[3] = f.py + S + HG;
  }
}
function init() {
  if (klaar) return;
  klaar = true;
  var dier = [1e9, -1e9, 1e9, -1e9], alles, kom = [1e9, -1e9, 1e9, -1e9], s;
  for (var kind in SOORT)
    for (var i = 0; i < POSE_NAMEN.length; i++) extent(faces(kind, POSE_NAMEN[i]), dier);
  alles = dier.slice();
  extent(komFaces(4), kom);
  extent(komFaces(4), alles);
  /* de schaduw hoort er ook helemaal op */
  s = [(SCHADUW[0] - SCHADUW[3]) * S, (SCHADUW[2] - SCHADUW[1]) * S,
       (SCHADUW[0] + SCHADUW[1]) * (S / 2), (SCHADUW[2] + SCHADUW[3]) * (S / 2)];
  alles[0] = Math.min(alles[0], s[0]); alles[1] = Math.max(alles[1], s[1]);
  alles[2] = Math.min(alles[2], s[2]); alles[3] = Math.max(alles[3], s[3]);
  dier[0] = Math.min(dier[0], s[0]); dier[1] = Math.max(dier[1], s[1]);
  dier[2] = Math.min(dier[2], s[2]); dier[3] = Math.max(dier[3], s[3]);
  CW = Math.ceil(alles[1] - alles[0]) + 4;
  CH = Math.ceil(alles[3] - alles[2]) + 4;
  OX = Math.round(-alles[0]) + 2;
  OY = Math.round(-alles[2]) + 2;
  /* zonder bakje het dier netjes in het midden zetten */
  GEEN_KOM = Math.round(((alles[1] - alles[0]) - (dier[1] - dier[0])) / 2);
  GEEN_KOM_Y = Math.round(((alles[3] - alles[2]) - (dier[3] - dier[2])) / 2);
  /* waar kruimels en sterretjes vandaan komen (in voxel-px, net als px/py) */
  KRUIMEL = [Math.round((kom[0] + kom[1]) / 2), Math.round(kom[2] + (kom[3] - kom[2]) * 0.25)];
  STER = [Math.round(dier[0] + (dier[1] - dier[0]) * 0.68), Math.round(dier[2] + 6)];
  var r = document.documentElement;
  r.style.setProperty('--vox-w', CW);
  r.style.setProperty('--vox-h', CH);
}

/* ---------- tekenen ---------- */
function poly(ctx, col, p) {
  ctx.fillStyle = col; ctx.strokeStyle = col;
  ctx.beginPath();
  ctx.moveTo(p[0], p[1]);
  for (var i = 2; i < p.length; i += 2) ctx.lineTo(p[i], p[i + 1]);
  ctx.closePath(); ctx.fill(); ctx.stroke();
}
/* één voxel: bovenvlak, rechtervlak, linkervlak - op apparaat-pixels */
function vlak(ctx, f, ox, oy, g) {
  var x = f.px * g + ox, y = f.py * g + oy, b = S * g, h = g, d = HG * g;
  if (f.ct) poly(ctx, f.ct, [x, y, x + b, y + h, x, y + b, x - b, y + h]);
  if (f.cr) poly(ctx, f.cr, [x + b, y + h, x, y + b, x, y + b + d, x + b, y + h + d]);
  if (f.cl) poly(ctx, f.cl, [x - b, y + h, x, y + b, x, y + b + d, x - b, y + h + d]);
}
function schaduw(ctx, ox, oy, g) {
  var h = S / 2, i, w, x0, z0, x1, z1;
  /* twee ringen over elkaar: buitenkant licht, midden iets dieper */
  for (i = 0; i < 2; i++) {
    w = i * 2;
    x0 = SCHADUW[0] + w; z0 = SCHADUW[1] + w; x1 = SCHADUW[2] - w; z1 = SCHADUW[3] - w;
    ctx.fillStyle = 'rgba(74,59,51,.07)';
    ctx.beginPath();
    ctx.moveTo(((x0 - z0) * S + ox) * g, ((x0 + z0) * h + oy) * g);
    ctx.lineTo(((x1 - z0) * S + ox) * g, ((x1 + z0) * h + oy) * g);
    ctx.lineTo(((x1 - z1) * S + ox) * g, ((x1 + z1) * h + oy) * g);
    ctx.lineTo(((x0 - z1) * S + ox) * g, ((x0 + z1) * h + oy) * g);
    ctx.closePath(); ctx.fill();
  }
}

/* ---------- offscreen platen: één keer bakken, daarna alleen blitten ---------- */
function maakCanvas(w, h) {
  var c = document.createElement('canvas');
  c.width = Math.max(1, w); c.height = Math.max(1, h);
  return c;
}
/* dun donker randje rondom de silhouetvorm, zodat de vlakken los komen
   van de kaart-achtergrond. Eén keer per plaat, dus gratis in de lus. */
function omlijn(cv, ctx, w) {
  var h = maakCanvas(cv.width, cv.height), hc = h.getContext('2d'), dx, dy;
  for (dx = -w; dx <= w; dx++)
    for (dy = -w; dy <= w; dy++) {
      if ((!dx && !dy) || Math.abs(dx) + Math.abs(dy) > w) continue;
      hc.drawImage(cv, dx, dy);
    }
  hc.globalCompositeOperation = 'source-in';
  hc.fillStyle = RAND_INK; hc.fillRect(0, 0, h.width, h.height);
  ctx.globalCompositeOperation = 'destination-over';
  ctx.drawImage(h, 0, 0);
  ctx.globalCompositeOperation = 'source-over';
}
/* Zachte silhouetrand: elk buitenste puntje dat aan twee kanten niets naast
   zich heeft (dus een scherpe trapjeshoek) wordt half doorzichtig gemaakt.
   Dat haalt precies één pixel van de zaagtandjes af - de vorm blijft
   voxel, maar de rand bijt niet meer. */
function rondAf(cv) {
  var w = cv.width, h = cv.height;
  if (w < 4 || h < 4) return;
  var ctx = cv.getContext('2d'), img;
  try { img = ctx.getImageData(0, 0, w, h); } catch (e) { return; }
  var d = img.data, a = new Uint8Array(w * h), i, x, y, leeg, hoek = [];
  for (i = 0; i < w * h; i++) a[i] = d[i * 4 + 3];
  for (y = 1; y < h - 1; y++) {
    for (x = 1; x < w - 1; x++) {
      i = y * w + x;
      if (a[i] < 200) continue;
      leeg = (a[i - 1] < 40 ? 1 : 0) + (a[i + 1] < 40 ? 1 : 0) +
             (a[i - w] < 40 ? 1 : 0) + (a[i + w] < 40 ? 1 : 0);
      if (leeg >= 2) hoek.push(i);
    }
  }
  if (!hoek.length) return;
  for (i = 0; i < hoek.length; i++) d[hoek[i] * 4 + 3] = 112;
  ctx.putImageData(img, 0, 0);
}

function plaat(list, g, silhouet) {
  var box = [1e9, -1e9, 1e9, -1e9];
  /* het vlak moet groot genoeg zijn voor lijst én silhouet (contour) */
  var bron = (silhouet && silhouet.length) ? silhouet : list;
  extent(bron.length ? bron : [{ px: 0, py: 0 }], box);
  var pad = 2, i;
  var cv = maakCanvas((box[1] - box[0]) * g + pad * 2, (box[3] - box[2]) * g + pad * 2);
  var ctx = cv.getContext('2d');
  ctx.lineWidth = 1; ctx.lineJoin = 'bevel';
  var ox = -box[0] * g + pad, oy = -box[2] * g + pad;
  for (i = 0; i < list.length; i++) vlak(ctx, list[i], ox, oy, g);
  if (silhouet) {
    /* het randje op de hele vorm baseren (ook het deel dat vóór het dier komt) */
    var sc = maakCanvas(cv.width, cv.height), sx = sc.getContext('2d');
    sx.lineWidth = 1; sx.lineJoin = 'bevel';
    for (i = 0; i < silhouet.length; i++) vlak(sx, silhouet[i], ox, oy, g);
    omlijn(sc, ctx, Math.max(1, Math.round(g / 2.6)));
  } else if (silhouet !== false) {
    omlijn(cv, ctx, Math.max(1, Math.round(g / 2.6)));
  }
  if (g >= 2) rondAf(cv);
  return { cv: cv, dx: box[0] * g - pad, dy: box[2] * g - pad };
}

var plaatCache = Object.create(null), plaatOrde = [], PLAAT_MAX = 110;
function haalPlaat(k, maak) {
  var e = plaatCache[k];
  if (e) return e;
  e = plaatCache[k] = maak();
  plaatOrde.push(k);
  while (plaatOrde.length > PLAAT_MAX) {
    var oud = plaatOrde.shift();
    if (oud !== k) delete plaatCache[oud];
  }
  return e;
}
function dierPlaat(kind, pose, g) {
  return haalPlaat('d|' + kind + '|' + pose + '|' + g, function () {
    return plaat(faces(kind, pose), g);
  });
}
function komPlaat(n, g, voor, groot) {
  return haalPlaat('k|' + n + '|' + g + '|' + voor + '|' + (groot ? 1 : 0), function () {
    var all = komFaces(n, groot), deel = [], i;
    for (i = 0; i < all.length; i++) if (!!all[i].voor === !!voor) deel.push(all[i]);
    return plaat(deel, g, voor ? false : all);
  });
}
function blit(ctx, p, ox, oy, g) {
  if (p.cv.width > 1) ctx.drawImage(p.cv, ox * g + p.dx, oy * g + p.dy);
}

/* ---------- deeltjes (kruimels + sterretjes) ---------- */
function pluis(st, n, x, y, kleur, omhoog) {
  for (var i = 0; i < n; i++) {
    st.pluis.push({
      x: x + (Math.random() * 14 - 7), y: y + (Math.random() * 7 - 3.5),
      vx: (Math.random() - 0.5) * 3.2, vy: omhoog ? -(1.4 + Math.random() * 2) : -(0.6 + Math.random() * 1.2),
      g: omhoog ? 0.08 : 0.5, t: omhoog ? 9 : 7, c: kleur, s: omhoog ? 2 : 1.5
    });
  }
}
function pluisStap(st) {
  for (var i = st.pluis.length - 1; i >= 0; i--) {
    var q = st.pluis[i];
    q.x += q.vx; q.y += q.vy; q.vy += q.g; q.t--;
    if (q.t <= 0) st.pluis.splice(i, 1);
  }
}

/* ---------- toestand per dier (blijft leven als de dom opnieuw getekend wordt) ---------- */
var reg = Object.create(null), sprites = [], rustig = false;

function stand(id, kind) {
  var st = reg[id];
  if (!st) st = reg[id] = { kind: kind || 'hond', mood: 'idle', pose: 'rust', dy: 0,
                            eten: 0, f: 0, seq: null, si: 0, sf: 0, pluis: [], stap: 0 };
  if (kind) st.kind = kind;
  return st;
}
var MOOD = { blij: 'idle', droopy: 'sad', bouncy: 'happy' };
/* met prefers-reduced-motion tekenen we per stemming één rustig plaatje */
var STIL = { idle: 'rust', sad: 'sip', happy: 'blijA', eat: 'hap2' };

/* De wereld (world.js) meldt zich hier aan. Staat hij er, dan gaan voer-,
   stemmings- en smulopdrachten naar de diorama-dieren; de losse kaart-
   dieren (poort, vignet, adoptie) blijven gewoon door art.js getekend. */
var wereld = null;
function koppelWereld(w) { wereld = w; }

function setMood(id, mood) {
  if (wereld && wereld.heeft(id)) wereld.mood(id, MOOD[mood] || mood || 'idle');
  var st = stand(id);
  var m = MOOD[mood] || mood || 'idle';
  if (st.seq && m === 'happy') return;      /* eerst het bakje leegeten */
  if (st.mood === m) return;
  st.mood = m; st.f = 0; st.seq = null;
  if (m === 'happy') st.eten = 0;
  if (rustig) { st.pose = STIL[m] || 'rust'; st.dy = 0; }
}
function setFood(id, aantal, per) {
  if (wereld) wereld.setFood(id, niveau(aantal, per));
  var st = stand(id);
  if (st.seq) return;                        /* niet ingrijpen tijdens het eten */
  st.eten = niveau(aantal, per);
}
function niveau(aantal, per) {
  if (!aantal) return 0;
  var f = per > 0 ? aantal / per : 1;
  return Math.max(1, Math.min(4, Math.ceil(f * 4)));
}
/* smakelijk eten: hap voor hap leeg, daarna blij */
function feast(ids) {
  init();
  if (wereld) wereld.feed(ids || []);
  (ids || []).forEach(function (id) {
    var st = reg[id];
    if (!st) return;
    var happen = Math.max(2, st.eten), seq = [['rust', 2]], i;
    for (i = 0; i < happen; i++) seq.push(['hap1', 1], ['hap2', 3], ['hap1', 1]);
    seq.push(['blijA', 0]);
    st.seq = seq; st.si = 0; st.sf = 0; st.mood = 'eat'; st.f = 0;
    if (rustig) { st.seq = null; st.mood = 'happy'; st.eten = 0; st.pose = 'blijA'; st.dy = 0; }
  });
  teken();
}

/* ---------- animatie: een enkele rAF-lus, alleen vuile canvassen ---------- */
function stap(st) {
  st.f++;
  pluisStap(st);
  if (st.seq) {
    var s = st.seq[st.si];
    if (st.sf === 0) {
      st.pose = s[0];
      if (s[0] === 'hap2') {
        if (st.eten > 0) st.eten--;
        pluis(st, 3, KRUIMEL[0], KRUIMEL[1], KOM.brok, false);
      }
    }
    st.dy = st.pose === 'hap2' ? 2 : 0;
    if (++st.sf >= s[1]) {
      st.sf = 0; st.si++;
      if (st.si >= st.seq.length - 1) { st.seq = null; st.mood = 'happy'; st.f = 0; }
    }
    return;
  }
  if (st.mood === 'eat') { st.mood = 'happy'; st.f = 0; }   /* nooit halverwege blijven hangen */
  if (st.mood === 'happy') {
    var k = st.f % 8;
    st.pose = k < 4 ? 'blijA' : 'blijB';
    st.dy = [0, -4, -6, -4, 0, -2, -4, -2][k];
    if (k === 1) pluis(st, 2, STER[0], STER[1], Math.random() < 0.5 ? '#FFE9A8' : WIT, true);
  } else if (st.mood === 'sad') {
    st.pose = 'sip';
    st.dy = st.f % 46 < 23 ? 2 : 0;
  } else {
    st.pose = st.f % 108 < 4 ? 'tril' : 'rust';
    st.dy = st.f % 26 < 13 ? 0 : -2;
  }
}

function sleutel(st) {
  return st.pose + '|' + st.dy + '|' + st.eten + '|' + (st.pluis.length ? st.f : 0);
}
function tekenSprite(sp) {
  var st = sp.st, ctx = sp.ctx, g = sp.g;
  var ox = OX + (sp.kom ? 0 : GEEN_KOM), oy = OY + (sp.kom ? 0 : GEEN_KOM_Y);
  ctx.clearRect(0, 0, sp.w, sp.h);
  schaduw(ctx, ox, oy + 1, g);
  if (sp.kom) blit(ctx, komPlaat(st.eten, g, 0), ox, oy, g);
  blit(ctx, dierPlaat(st.kind, st.pose, g), ox, oy + st.dy, g);
  if (sp.kom) blit(ctx, komPlaat(st.eten, g, 1), ox, oy, g);
  for (var i = 0; i < st.pluis.length; i++) {
    var q = st.pluis[i], m = Math.max(2, Math.round(q.s * g));
    ctx.globalAlpha = Math.min(1, q.t / 5);
    ctx.fillStyle = q.c;
    ctx.fillRect(Math.round((q.x + ox) * g), Math.round((q.y + oy) * g), m, m);
  }
  ctx.globalAlpha = 1;
  if (sp.el.getAttribute('data-vox') !== st.mood) sp.el.setAttribute('data-vox', st.mood);
  sp.key = sleutel(st);
}

function teken() {
  for (var i = 0; i < sprites.length; i++) {
    var sp = sprites[i];
    if (sleutel(sp.st) !== sp.key) tekenSprite(sp);
  }
}

/* ---------- hoeveel apparaat-pixels krijgt dit dier? ---------- */
function meet(sp) {
  var r = sp.el.getBoundingClientRect();
  var dpr = window.devicePixelRatio || 1;
  var ratio = (r.width > 4 ? r.width * dpr : CW * 1.5 * dpr) / CW;
  /* naar boven afronden: het canvas mag nooit kleiner zijn dan het aantal
     apparaat-pixels, anders wordt het weer opgeschaald en dus zacht */
  var g = Math.max(1, Math.min(5, Math.ceil(ratio - 0.08)));
  if (g === sp.g) return false;
  sp.g = g; sp.w = CW * g; sp.h = CH * g;
  sp.cv.width = sp.w; sp.cv.height = sp.h;
  sp.ctx.lineWidth = 1; sp.ctx.lineJoin = 'bevel';
  sp.key = '';
  return true;
}

var vorige = 0, STAP = 1000 / 12;
function lus(nu) {
  requestAnimationFrame(lus);
  if (nu - vorige < STAP) return;
  vorige = nu;
  koppel();
  var i;
  for (i = sprites.length - 1; i >= 0; i--) if (!sprites[i].el.isConnected) sprites.splice(i, 1);
  if (!sprites.length) return;
  if (!rustig) {
    var gedaan = Object.create(null);
    for (i = 0; i < sprites.length; i++) {
      var st = sprites[i].st;
      if (gedaan[st.id]) continue;
      gedaan[st.id] = 1;
      stap(st);
    }
  }
  teken();
}

/* ---------- html + koppelen ---------- */
function animal(a, mood, extraClass) {
  var kind = (a && a.kind) || 'hond', id = (a && a.id) || kind;
  return '<div class="animal' + (extraClass ? ' ' + extraClass : '') + '" data-animal="' + id +
    '" data-kind="' + kind + '" data-mood="' + (mood || 'blij') +
    '" role="img" aria-label="' + kind + '"></div>';
}

function koppel(root) {
  init();
  var lijst = (root || document).querySelectorAll('.animal[data-animal]'), i;
  for (i = 0; i < lijst.length; i++) {
    var el = lijst[i];
    if (el.__vox) continue;
    var id = el.getAttribute('data-animal');
    var st = stand(id, el.getAttribute('data-kind'));
    st.id = id;
    var cv = document.createElement('canvas');
    el.appendChild(cv);
    var sp = { el: el, cv: cv, ctx: cv.getContext('2d'), st: st, g: 0, w: 0, h: 0,
               kom: !!(el.closest && el.closest('.pet')), key: '' };
    el.__vox = sp;
    sprites.push(sp);
    meet(sp);
    if (!sp.kom && st.seq) { st.seq = null; st.mood = 'happy'; }
    setMood(id, el.getAttribute('data-mood'));
    tekenSprite(sp);
  }
}

/* bij draaien / zoomen kan de apparaat-resolutie veranderen */
function hermeet() {
  for (var i = 0; i < sprites.length; i++) if (sprites[i].el.isConnected) meet(sprites[i]);
  teken();
}

function debug() {
  var o = {}, id;
  for (id in reg) o[id] = { mood: reg[id].mood, pose: reg[id].pose, eten: reg[id].eten,
                            eet: !!reg[id].seq, pluis: reg[id].pluis.length };
  return o;
}
/* alleen voor tests: hoe fijn zijn de modellen en wat kost het? */
function stats() {
  init();
  var o = { raster: [CW, CH], sprites: [], vlakken: {} };
  for (var kind in SOORT) {
    var vox = SOORT[kind](POSE.rust), b = [1e9, -1e9, 1e9, -1e9, 1e9, -1e9], i;
    for (i = 0; i < vox.length; i++) {
      var p = vox[i];
      if (p[0] < b[0]) b[0] = p[0]; if (p[0] > b[1]) b[1] = p[0];
      if (p[1] < b[2]) b[2] = p[1]; if (p[1] > b[3]) b[3] = p[1];
      if (p[2] < b[4]) b[4] = p[2]; if (p[2] > b[5]) b[5] = p[2];
    }
    o.vlakken[kind] = { voxels: vox.length, vlakken: faces(kind, 'rust').length,
                        lxhxd: [b[1] - b[0] + 1, b[3] - b[2] + 1, b[5] - b[4] + 1] };
  }
  for (var j = 0; j < sprites.length; j++)
    o.sprites.push({ id: sprites[j].st.id, g: sprites[j].g, canvas: [sprites[j].w, sprites[j].h] });
  o.platen = plaatOrde.length;
  o.plaat_kb = 0;
  for (var q = 0; q < plaatOrde.length; q++) {
    var pc = plaatCache[plaatOrde[q]];
    if (pc) o.plaat_kb += Math.round(pc.cv.width * pc.cv.height * 4 / 1024);
  }
  return o;
}

/* ---------- start ---------- */
function begin() {
  try { rustig = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches; }
  catch (e) { rustig = false; }
  init();
  koppel();
  if (window.MutationObserver) {
    new MutationObserver(function () { koppel(); }).observe(document.body, { childList: true, subtree: true });
  }
  window.addEventListener('resize', hermeet);
  window.addEventListener('orientationchange', hermeet);
  requestAnimationFrame(lus);
}
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', begin);
else begin();

/* alleen voor de tekentest: zet een houding vast */
function poseer(id, naam, eten) {
  var st = stand(id);
  if (st.seq) { st.seq = null; st.mood = 'idle'; }
  st.pose = naam; st.dy = 0;
  if (eten !== undefined) st.eten = eten;
  teken();
}

/* ---------- gereedschapskist voor world.js ----------
   De wereld bouwt zijn eigen decor (boom, hok, hek, plukjes gras) met
   dezelfde blokjes, hetzelfde licht en dezelfde bak-cache als de dieren.
   Zo blijft er één tekenstijl en één plaatjes-geheugen. */
var kit = {
  S: S, HG: HG, KOM: KOM,
  bx: bx, ell: ell, punt: punt, verf: verf, bake: bake,
  plaat: plaat, cache: haalPlaat, canvas: maakCanvas,
  dier: function (kind, pose, g) { init(); return dierPlaat(kind, pose, g); },
  kom: function (n, g, voor) { init(); return komPlaat(n, g, voor, 1); },
  komAnker: [KOM_CX, KOM_CZ],       /* midden van het voerbakje in voxels */
  dierAnker: [13, 7.5]              /* midden van de vier pootjes */
};

return { animal: animal, mount: koppel, setMood: setMood, setFood: setFood,
         feast: feast, debug: debug, pose: poseer, PAL: PAL, stats: stats,
         kit: kit, wereld: koppelWereld, niveau: niveau,
         size: function () { return [CW, CH]; } };
})();
