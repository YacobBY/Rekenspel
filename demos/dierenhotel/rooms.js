/* ---------------------------------------------------------------
   rooms.js - de ruimtes van Dierenhotel Kwispelsteeg ALS DATA.

   Een ruimte is een doos van voxels (w x d) met twee achterwanden
   (het vlak x = 0 en het vlak z = 0), een vloerpatroon, decor,
   plekken (bed / bakje / vrij vakje) en deuren naar andere ruimtes.
   De deuren vormen samen een graaf; Rooms.pad() zoekt er met een
   breedte-eerst-zoektocht de kortste route doorheen.

   Alles is data: world.js tekent het, hits.js zet er knoppen op en
   de minigames in games/ vragen ernaar. Wie een kamer wil bijbouwen
   voegt hier één regel toe.

   Publiek:
     Rooms.lijst()                - alle ruimtes op volgorde
     Rooms.get(id)                - één ruimte
     Rooms.pad(van, naar)         - ['gang','kamer1'] (BFS, [] = niet)
     Rooms.deur(kamerId, naar)    - {x,z,ix,iz,breed,wand} van die deur
     Rooms.slots(kamerId, soort)  - bed- / bak- / vrije plekken
     Rooms.slot(kamerId, slotId)  - één plek
     Rooms.plekken(kamerId)       - dwaalplekken voor de dieren
     Rooms.model(naam)            - voxels van een decorstuk
     Rooms.vloerKleur(kamer,x,z)  - kleur van een vloervakje
---------------------------------------------------------------- */
var Rooms = (function () {
'use strict';

var K = Art.kit;

/* ---------- palet: hetzelfde warme hout als in de tuin ---------- */
var HOUT = '#D0A87A', HOUT_D = '#B98F62', HOUT_L = '#E2C094', STAM = '#B08A6A';
var BLAD = '#A6CE8E', BLAD_A = '#A9D08F', BLAD_B = '#B2D797';
var DAK = '#E79C7C', MUUR = '#F6E2C8', DEURKL = '#8B6F5C';
var WATER = '#A9D8E6', KUSSEN = '#FFF7EC', DEKEN = '#A9D3F0', DEKEN_D = '#84B4D8';
var STOF = '#F5B0C2', METAAL = '#C9CCDC', METAAL_L = '#EDEFF6';
var GOUD = '#F2C14E', GOUD_D = '#D9A72F', POT = '#D98E6A', PAPIER = '#FFFDF3';

/* =====================================================================
   DECORSTUKKEN - kleine voxelmodellen, midden op (0,0,0) op de vloer
===================================================================== */
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
  K.verf(v, 10, 10, 0, 11, -4, 4, DEURKL);
  K.verf(v, 10, 10, 12, 12, -5, 5, HOUT_D);
  K.bx(v, -11, 0, -10, 22, 1, 20, HOUT_D);
  return v;
}
function pMat() {
  var v = [];
  K.bx(v, -8, 0, -8, 17, 1, 17, HOUT);
  K.verf(v, -8, 8, 0, 0, -8, -8, HOUT_D);
  K.verf(v, -8, 8, 0, 0, 8, 8, HOUT_D);
  K.verf(v, -8, -8, 0, 0, -8, 8, HOUT_D);
  K.verf(v, 8, 8, 0, 0, -8, 8, HOUT_D);
  return v;
}
function pHekX() {
  var v = [];
  K.bx(v, -1, 0, -1, 3, 13, 3, HOUT_D);
  K.bx(v, -2, 13, -2, 5, 1, 5, HOUT);
  K.bx(v, 1, 9, -1, 11, 2, 3, HOUT);
  K.bx(v, 1, 4, -1, 11, 2, 3, HOUT);
  return v;
}
function pHekZ() {
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
  K.bx(v, -5, 8, -5, 11, 1, 11, HOUT_L);
  return v;
}
function pPol(n) {
  var v = [], r = prng(4711 + n * 977), i, h, c;
  for (i = 0; i < 5 + (n % 3); i++) {
    h = 2 + Math.round(r() * 4);
    c = r() < 0.5 ? '#93C57E' : '#A8D48F';
    K.punt(v, Math.round(r() * 7 - 3), 0, Math.round(r() * 7 - 3), 2, h, 2, c);
  }
  if (n % 4 === 1) K.punt(v, 1, 0, 1, 2, 6, 2, r() < 0.5 ? '#F7C0D2' : '#FFE49B');
  return v;
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

/* ---------- hotelmeubels ---------- */
/* de balie loopt in de x-richting; de brede voorkant kijkt naar +z,
   dus recht naar het kind toe */
function pBalie() {
  var v = [];
  K.bx(v, -17, 0, -5, 35, 12, 11, HOUT);
  K.bx(v, -19, 12, -7, 39, 2, 15, HOUT_L);
  K.verf(v, -17, 17, 4, 5, 5, 5, HOUT_D);
  K.verf(v, -17, 17, 9, 9, 5, 5, HOUT_L);
  K.verf(v, -17, 17, 0, 0, -5, 5, HOUT_D);
  return v;
}
function pBel() {
  var v = [];
  K.bx(v, -3, 0, -3, 7, 1, 7, DEURKL);
  K.ell(v, 0, 3.6, 0, 3.0, 3.2, 3.0, GOUD, { e: 2.4, ymin: 1 });
  K.bx(v, -1, 6, -1, 3, 2, 3, GOUD_D);
  return v;
}
function pKassa() {
  var v = [];
  K.bx(v, -5, 0, -6, 11, 7, 13, METAAL);
  K.bx(v, -5, 7, -6, 11, 2, 8, METAAL_L);
  K.verf(v, -5, 5, 3, 4, 6, 6, '#A0A6C0');
  K.bx(v, -3, 9, -1, 7, 5, 2, METAAL_L);
  K.verf(v, -3, 3, 11, 12, 0, 0, '#8FA9C4');
  return v;
}
function pBoek() {
  var v = [];
  K.bx(v, -5, 0, -4, 11, 2, 9, PAPIER);
  K.bx(v, -5, 0, -4, 11, 1, 9, '#E08FA6');
  K.verf(v, 0, 0, 0, 2, -4, 4, '#C9788F');
  return v;
}
function pPrikbord() {                     /* hangt aan de wand z = 0 */
  var v = [];
  K.bx(v, -11, 4, 0, 23, 19, 2, HOUT_D);
  K.bx(v, -10, 5, 1, 21, 17, 2, '#E8CFA6');
  K.bx(v, -8, 8, 3, 6, 6, 1, PAPIER);
  K.bx(v, 0, 9, 3, 6, 7, 1, '#FFF0C6');
  K.bx(v, -3, 16, 3, 5, 4, 1, '#FFC7D9');
  return v;
}
function pSleutelbord() {                  /* hangt aan de wand z = 0 */
  var v = [], i;
  K.bx(v, -10, 6, 0, 21, 13, 2, HOUT);
  K.verf(v, -10, 10, 6, 6, 1, 1, HOUT_D);
  for (i = 0; i < 5; i++) {
    K.bx(v, -8 + i * 4, 14, 2, 1, 1, 1, GOUD_D);
    K.bx(v, -8 + i * 4, 10, 2, 2, 4, 1, GOUD);
  }
  return v;
}
/* Het bed is een tikje langer dan het langste dier (30 voxels), zodat een
   slapende hond er echt IN ligt in plaats van eruit te steken. */
function pBed() {                          /* ligt in de x-richting */
  var v = [];
  K.bx(v, -16, 0, -8, 33, 4, 17, HOUT_D);
  K.bx(v, -15, 4, -7, 31, 3, 15, KUSSEN);
  K.bx(v, -17, 0, -8, 3, 13, 17, HOUT);
  K.bx(v, 14, 0, -8, 3, 9, 17, HOUT);
  K.bx(v, -13, 7, -7, 9, 2, 15, KUSSEN);
  K.bx(v, -3, 7, -7, 16, 2, 15, DEKEN);
  K.verf(v, -3, -3, 7, 8, -7, 7, DEKEN_D);
  K.verf(v, -16, 13, 3, 3, -8, 8, HOUT_L);
  return v;
}
function pMand() {
  var v = [], x, z, q;
  for (x = -7; x <= 7; x++) for (z = -7; z <= 7; z++) {
    q = x * x + z * z;
    if (q > 46) continue;
    if (q > 26) { K.bx(v, x, 0, z, 1, 7, 1, HOUT); K.verf(v, x, x, 6, 6, z, z, HOUT_L); }
    else K.bx(v, x, 0, z, 1, 3, 1, STOF);
  }
  return v;
}
function pKast() {                         /* voerkast tegen de wand z = 0 */
  var v = [];
  K.bx(v, -12, 0, -2, 25, 27, 10, HOUT);
  K.verf(v, -12, 12, 0, 26, 7, 7, HOUT_L);
  K.verf(v, -1, 0, 0, 26, 7, 7, HOUT_D);
  K.verf(v, -12, 12, 13, 13, 7, 7, HOUT_D);
  K.bx(v, -4, 12, 8, 1, 2, 1, GOUD);
  K.bx(v, 3, 12, 8, 1, 2, 1, GOUD);
  K.bx(v, -13, 27, -3, 27, 2, 12, HOUT_D);
  return v;
}
function pZak() {
  var v = [];
  K.ell(v, 0, 7, 0, 6.5, 7, 6.5, '#E8CFA6', { e: 2.6, ymin: 0 });
  K.verf(v, -7, 7, 3, 7, 5, 7, '#D9B98A');
  K.bx(v, -2, 13, -2, 5, 3, 5, '#C99B63');
  K.verf(v, -3, 3, 5, 8, -7, -5, '#C99B63');
  return v;
}
function pKar() {                          /* de voerkar: vakjes + snoeppot */
  var v = [], i;
  K.bx(v, -13, 4, -9, 27, 3, 19, HOUT);
  K.bx(v, -13, 7, -9, 27, 1, 19, HOUT_L);
  for (i = 0; i < 3; i++) {
    K.bx(v, -12 + i * 8, 8, -8, 7, 5, 8, HOUT_D);
    K.bx(v, -11 + i * 8, 9, -7, 5, 4, 6, MUUR);
  }
  K.ell(v, 6, 11, 4, 4.4, 4, 4.4, '#DFF1FB', { e: 2.6, ymin: 8 });
  K.bx(v, 3, 15, 1, 7, 1, 7, '#C5E4F7');
  K.bx(v, -11, 0, -8, 4, 5, 4, '#6E5A4A');
  K.bx(v, -11, 0, 5, 4, 5, 4, '#6E5A4A');
  K.bx(v, 8, 0, -8, 4, 5, 4, '#6E5A4A');
  K.bx(v, 8, 0, 5, 4, 5, 4, '#6E5A4A');
  K.bx(v, -15, 7, -9, 2, 14, 19, HOUT_D);
  K.bx(v, -16, 20, -9, 4, 2, 19, HOUT);
  return v;
}
function pLamp() {
  var v = [];
  K.bx(v, -3, 0, -3, 7, 1, 7, METAAL);
  K.bx(v, -1, 1, -1, 3, 8, 3, METAAL);
  K.ell(v, 0, 11, 0, 4.6, 3.2, 4.6, '#CFD6E0', { e: 2.6, ymin: 9 });
  return v;
}
function pLampAan() {
  var v = pLamp();
  K.verf(v, -6, 6, 8, 16, -6, 6, '#FFE9A8');
  return v;
}
function pPlant() {
  var v = [];
  K.bx(v, -4, 0, -4, 9, 6, 9, POT);
  K.bx(v, -5, 6, -5, 11, 2, 11, '#E8A97F');
  K.ell(v, 0, 13, 0, 5.5, 5.5, 5.5, BLAD, { e: 2.2 });
  K.ell(v, 3, 17, -2, 4, 4, 4, BLAD_B, { e: 2.2 });
  K.ell(v, -3, 16, 3, 3.6, 3.6, 3.6, BLAD_A, { e: 2.2 });
  return v;
}
function pPoort() {                        /* tuinpoortje in het hek */
  var v = [];
  K.bx(v, -1, 0, -9, 3, 15, 3, HOUT_D);
  K.bx(v, -1, 0, 7, 3, 15, 3, HOUT_D);
  K.bx(v, -1, 13, -9, 3, 2, 19, HOUT);
  K.bx(v, -1, 4, -7, 3, 2, 15, HOUT);
  return v;
}

/* spiegelen over de diagonaal: hetzelfde meubel, een kwartslag gedraaid */
function draai(maak) {
  return function () {
    var v = maak(), u = [], i;
    for (i = 0; i < v.length; i++) u.push([v[i][2], v[i][1], v[i][0], v[i][3], v[i][4]]);
    return u;
  };
}

var MODEL = {
  boom: pBoom, hok: pHok, hekx: pHekX, hekz: pHekZ, tobbe: pTobbe, bal: pBal,
  kist: pKist, mat: pMat, poort: pPoort,
  balie: pBalie, baliez: draai(pBalie), bel: pBel, kassa: pKassa, boek: pBoek, prikbord: pPrikbord,
  sleutelbord: pSleutelbord, bed: pBed, bedz: draai(pBed), mand: pMand,
  kast: pKast, kastz: draai(pKast), zak: pZak, kar: pKar, lamp: pLamp,
  lampaan: pLampAan, plant: pPlant, prikbordz: draai(pPrikbord),
  sleutelbordz: draai(pSleutelbord)
};
function model(naam) {
  return MODEL[naam] ? MODEL[naam]() : pPol(+String(naam).slice(3) || 0);
}

/* =====================================================================
   DE RUIMTES
   w x d = vloer in voxels; de wanden staan op x = 0 en z = 0.
   deuren:  {naar, wand:'x'|'z', at, breed}  - at = begin van het gat
   decor:   {n, x, z, y?, ver?}              - ver = altijd achteraan
   slots:   {id, soort:'bed'|'bak'|'vrij', x, z}
===================================================================== */
/* De wandhoogtes zijn zo gekozen dat elke kamerdoos even hoog uitvalt
   (~290 voxel-px). Daardoor staat elke ruimte even groot in beeld en hoeft
   het kader niet te springen als je van kamer wisselt. */
var RUIMTES = [
  {
    id: 'receptie', naam: 'Receptie', icoon: '🛎️', w: 80, d: 80,
    wand: 54, vloer: 'hout',
    matten: [{ x0: 30, z0: 52, x1: 66, z1: 76, kl: ['#E9BFC9', '#E3B4C0'] }],
    deuren: [{ naar: 'gang', wand: 'z', at: 58, breed: 12 }],
    /* De balie is een L: een deel langs x en een vleugel langs z. Daardoor
       liggen de vier dingen erop ook op het SCHERM ver uit elkaar - anders
       dekken de hotspot-knoppen elkaar af (isometrie duwt alles op één rij). */
    decor: [
      { n: 'balie', x: 30, z: 40 },
      { n: 'baliez', x: 10, z: 62 },
      { n: 'bel', x: 22, z: 40, y: 14 },
      { n: 'kassa', x: 44, z: 40, y: 14 },
      { n: 'boek', x: 10, z: 50, y: 14 },
      { n: 'lamp', x: 10, z: 70, y: 14, sleutel: 'balielamp' },
      { n: 'prikbord', x: 26, z: 1, ver: 1 },
      { n: 'sleutelbordz', x: 1, z: 56, ver: 1 },
      { n: 'plant', x: 70, z: 12 },
      { n: 'plant', x: 72, z: 54 }
    ],
    slots: []
  },
  {
    id: 'gang', naam: 'Gang', icoon: '🚪', w: 120, d: 36,
    wand: 56, vloer: 'loper',
    deuren: [
      { naar: 'receptie', wand: 'x', at: 10, breed: 12 },
      { naar: 'kamer1', wand: 'z', at: 24, breed: 12 },
      { naar: 'kamer2', wand: 'z', at: 60, breed: 12 },
      { naar: 'keuken', wand: 'z', at: 96, breed: 12 }
    ],
    decor: [
      { n: 'plant', x: 44, z: 8 },
      { n: 'plant', x: 82, z: 8 },
      { n: 'kist', x: 114, z: 14 }
    ],
    slots: []
  },
  {
    id: 'kamer1', naam: 'Kamer 1', icoon: '🛏️', w: 76, d: 76,
    wand: 58, vloer: 'zacht',
    matten: [{ x0: 34, z0: 30, x1: 62, z1: 58, kl: ['#DFCBEA', '#D6BFE4'] }],
    deuren: [{ naar: 'gang', wand: 'z', at: 48, breed: 12 }],
    decor: [
      { n: 'plant', x: 68, z: 8 },
      { n: 'mand', x: 62, z: 66 }
    ],
    slots: [
      { id: 'bed1', soort: 'bed', x: 20, z: 18 },
      { id: 'bed2', soort: 'bed', x: 20, z: 50 },
      { id: 'bak', soort: 'bak', x: 56, z: 22 }
    ]
  },
  {
    id: 'kamer2', naam: 'Kamer 2', icoon: '🛏️', w: 76, d: 76,
    wand: 58, vloer: 'zacht',
    matten: [{ x0: 34, z0: 30, x1: 62, z1: 58, kl: ['#CBE3D6', '#BFDBCB'] }],
    deuren: [{ naar: 'gang', wand: 'z', at: 48, breed: 12 }],
    decor: [
      { n: 'plant', x: 8, z: 66 },
      { n: 'mand', x: 62, z: 66 }
    ],
    slots: [
      { id: 'bed1', soort: 'bed', x: 20, z: 18 },
      { id: 'bed2', soort: 'bed', x: 20, z: 50 },
      { id: 'bak', soort: 'bak', x: 56, z: 22 }
    ]
  },
  {
    id: 'keuken', naam: 'Keuken', icoon: '🍪', w: 80, d: 76,
    wand: 56, vloer: 'tegel',
    deuren: [
      { naar: 'gang', wand: 'x', at: 50, breed: 12 },
      { naar: 'tuin', wand: 'z', at: 60, breed: 12 }
    ],
    decor: [
      { n: 'kast', x: 22, z: 6 },
      { n: 'zak', x: 44, z: 12 },
      { n: 'kar', x: 32, z: 44 },
      { n: 'plant', x: 72, z: 62 }
    ],
    slots: []
  },
  {
    id: 'tuin', naam: 'Tuin', icoon: '🌳', w: 130, d: 130,
    wand: 0, vloer: 'gras', erf: 1,
    kader: [-170, 190, -70, 220],
    deuren: [{ naar: 'keuken', wand: 'x', at: 34, breed: 12, poort: 1 }],
    decor: [
      { n: 'boom', x: 16, z: 68 }, { n: 'hok', x: 67, z: 19 },
      { n: 'tobbe', x: 32, z: 94 }, { n: 'bal', x: 120, z: 76 },
      { n: 'kist', x: 95, z: 23 }, { n: 'poort', x: 10, z: 40, ver: 1 }
    ],
    slots: [{ id: 'tobbe', soort: 'vrij', x: 32, z: 94 }]
  }
];

/* ---------- tuin: hek en plukjes gras erbij, net als vroeger ---------- */
var HEK_X = 10, HEK_Z = 10;
(function bouwTuin() {
  var t = null, i, j;
  for (i = 0; i < RUIMTES.length; i++) if (RUIMTES[i].id === 'tuin') t = RUIMTES[i];
  if (!t) return;
  var groot = [[16, 68], [67, 19], [32, 94], [120, 76], [95, 23]];
  for (i = HEK_Z; i <= 130; i += 14) if (i < 34 || i > 46) t.decor.push({ n: 'hekz', x: HEK_X, z: i, ver: 1 });
  for (i = HEK_X + 14; i <= 130; i += 14) t.decor.push({ n: 'hekx', x: i, z: HEK_Z, ver: 1 });
  var r = prng(90210);
  for (i = 0; i < 30; i++) {
    var u = Math.round(r() * 300 - 150), w = 24 + Math.round(r() * 220);
    var px = (u + w) / 2, pz = (w - u) / 2, vrij = px > HEK_X + 2 && pz > HEK_Z + 2;
    for (j = 0; j < groot.length && vrij; j++)
      if (Math.abs(px - groot[j][0]) + Math.abs(pz - groot[j][1]) < 22) vrij = false;
    if (vrij) t.decor.push({ n: 'pol' + (i % 5), x: px, z: pz });
  }
})();

/* =====================================================================
   AFLEIDINGEN: kader, deuren, vrije vakjes, dwaalplekken
===================================================================== */
var S = K.S, HG = K.HG;

function kader(r) {
  if (r.kader) return r.kader;
  var u0 = -r.d * S - 10, u1 = r.w * S + 10;
  var v0 = -r.wand * HG - 12, v1 = (r.w + r.d) * (S / 2) + 10;
  return [u0, u1, v0, v1];
}

/* de deur als wereldpunt: (x,z) in het wandvlak, (ix,iz) een stapje
   de kamer in - daar gaat een dier staan voordat het doorloopt */
function deurPunt(r, dr) {
  var m = dr.at + dr.breed / 2;
  if (dr.wand === 'z') return { x: m, z: 0, ix: m, iz: 8, wand: 'z', breed: dr.breed, naar: dr.naar, poort: !!dr.poort };
  return { x: 0, z: m, ix: 8, iz: m, wand: 'x', breed: dr.breed, naar: dr.naar, poort: !!dr.poort };
}

/* de sta-plek van een plek: waar gaat een dier staan om hem te gebruiken */
function afSlot(s) {
  if (s.soort === 'bed') { s.sx = s.x + 2; s.sz = s.z + 12; }
  else if (s.soort === 'bak') { s.sx = s.x - 13; s.sz = s.z; }
  else { s.sx = s.x; s.sz = s.z; }
  return s;
}

function bouwAf(r) {
  var i, j, s;
  r.box = kader(r);
  r.deurPunten = r.deuren.map(function (d) { return deurPunt(r, d); });
  /* vrije vakjes: een raster van 12 voxels, ruim van de muren en het decor */
  var vrij = [], stap = 12, marge = r.erf ? 18 : 12;
  for (var x = marge; x <= r.w - marge; x += stap) {
    for (var z = marge; z <= r.d - marge; z += stap) {
      var ok = true;
      for (i = 0; i < r.decor.length && ok; i++)
        if (Math.abs(r.decor[i].x - x) + Math.abs(r.decor[i].z - z) < 18) ok = false;
      for (i = 0; i < r.slots.length && ok; i++)
        if (Math.abs(r.slots[i].x - x) + Math.abs(r.slots[i].z - z) < 18) ok = false;
      for (i = 0; i < r.deurPunten.length && ok; i++)
        if (Math.abs(r.deurPunten[i].ix - x) + Math.abs(r.deurPunten[i].iz - z) < 14) ok = false;
      if (ok) vrij.push({ id: 'v' + x + '_' + z, soort: 'vrij', x: x, z: z });
    }
  }
  r.vrij = vrij;
  /* dwaalplekken: de vrije vakjes, maar niet te dicht op elkaar */
  var pl = [];
  for (i = 0; i < vrij.length; i++) {
    var goed = true;
    for (j = 0; j < pl.length; j++)
      if (Math.abs(pl[j][0] - vrij[i].x) + Math.abs(pl[j][1] - vrij[i].z) < 22) goed = false;
    if (goed) pl.push([vrij[i].x, vrij[i].z]);
  }
  if (!pl.length) pl.push([r.w / 2, r.d / 2]);
  r.plekkenLijst = pl;
  /* bedden en bakjes krijgen hun eigen sta-plek erbij */
  for (i = 0; i < r.slots.length; i++) afSlot(r.slots[i]);
  return r;
}

var BY_ID = {};
RUIMTES.forEach(function (r) { bouwAf(r); BY_ID[r.id] = r; });

/* =====================================================================
   MEUBELS EN BEDDEN BIJPLAATSEN
   Dit is de gedeelde plaats-API: een minigame in games/ hoeft rooms.js
   nooit te openen om een bed of een plant neer te zetten. Alles loopt
   door dezelfde afleiding als de vaste inrichting (sta-plekken, vrije
   vakjes, dwaalplekken), zodat een dier er meteen naartoe kan lopen.

   TYPEN: bed (+1 gast), bakje, mandje, speelmand, plant, badkuip.
===================================================================== */
var MEUBEL = {
  bed:       { soort: 'bed',  model: 'bed',   naam: 'bed' },
  bakje:     { soort: 'bak',  model: null,    naam: 'voerbakje' },
  mandje:    { soort: 'decor', model: 'mand', naam: 'mandje' },
  speelmand: { soort: 'decor', model: 'mand', naam: 'speelmand' },
  plant:     { soort: 'decor', model: 'plant', naam: 'plant' },
  badkuip:   { soort: 'decor', model: 'tobbe', naam: 'badkuip' }
};

/* de eerste keer dat er iets verandert leggen we de basisinrichting vast,
   zodat "Nieuw spel" het hotel weer kaal kan opleveren */
function basis(r) {
  if (!r._basis) {
    r._basis = { slots: r.slots.map(function (q) { return Object.assign({}, q); }),
                 decor: r.decor.map(function (q) { return Object.assign({}, q); }) };
  }
  return r._basis;
}
function herstel() {
  RUIMTES.forEach(function (r) {
    if (!r._basis) return;
    r.slots = r._basis.slots.map(function (q) { return Object.assign({}, q); });
    r.decor = r._basis.decor.map(function (q) { return Object.assign({}, q); });
    bouwAf(r);
  });
}

/* ligt hier al iets? (meubels, plekken, deuren) */
function bezet(r, x, z, marge) {
  var m = marge || 15, i;
  for (i = 0; i < r.slots.length; i++)
    if (Math.abs(r.slots[i].x - x) + Math.abs(r.slots[i].z - z) < m) return true;
  for (i = 0; i < r.decor.length; i++)
    if (Math.abs(r.decor[i].x - x) + Math.abs(r.decor[i].z - z) < m) return true;
  for (i = 0; i < r.deurPunten.length; i++)
    if (Math.abs(r.deurPunten[i].ix - x) + Math.abs(r.deurPunten[i].iz - z) < 12) return true;
  return false;
}
/* Naar het dichtstbijzijnde vakje van het vloerraster toe schuiven dat NU
   ook echt leeg is. Het raster zelf is al vrij van de vaste inrichting;
   deze extra controle kijkt naar wat er ná die berekening is bijgezet
   (een bijgeplaatst bed, een tijdelijk bakje van de voerkar). Is alles
   bezet, dan geven we het dichtstbijzijnde vakje terug en mag de beller
   zelf beslissen. */
function naarRaster(r, x, z) {
  var beste = null, best = 1e9, bezetste = null, bezetBest = 1e9, i, v, af;
  for (i = 0; i < r.vrij.length; i++) {
    v = r.vrij[i];
    af = Math.abs(v.x - x) + Math.abs(v.z - z);
    if (bezet(r, v.x, v.z)) {
      if (af < bezetBest) { bezetBest = af; bezetste = v; }
      continue;
    }
    if (af < best) { best = af; beste = v; }
  }
  return beste || bezetste;
}

var meubelNr = 0;
function nieuwId(type) { meubelNr++; return 'm' + meubelNr + '_' + type; }

/* Zet een meubel neer. Geeft {id, kamer, type, x, z, rot, soort} terug,
   of null als het niet past (buiten de kamer / vakje al bezet). */
function meubelZet(kamerId, type, x, z, rot, id) {
  var r = BY_ID[kamerId], t = MEUBEL[type];
  if (!r || !t) return null;
  basis(r);
  var vak = (x === undefined || x === null) ? null : { x: x, z: z };
  if (vak && (vak.x < 4 || vak.z < 4 || vak.x > r.w - 4 || vak.z > r.d - 4)) vak = null;
  if (vak && bezet(r, vak.x, vak.z)) vak = naarRaster(r, vak.x, vak.z);
  if (!vak) vak = naarRaster(r, x === undefined || x === null ? r.w / 2 : x,
                                z === undefined || z === null ? r.d / 2 : z);
  if (!vak || bezet(r, vak.x, vak.z)) return null;
  var m = { id: id || nieuwId(type), kamer: kamerId, type: type,
            x: vak.x, z: vak.z, rot: rot || 0, soort: t.soort };
  if (t.soort === 'decor') {
    r.decor.push({ n: t.model, x: m.x, z: m.z, meubel: m.id });
  } else {
    var mod = t.model;
    if (type === 'bed' && (m.rot % 2)) mod = 'bedz';          /* tik = draaien */
    r.slots.push(afSlot({ id: m.id, soort: t.soort, x: m.x, z: m.z,
                          model: mod, meubel: m.id, draai: !!(m.rot % 2) }));
  }
  bouwAf(r);
  return m;
}

/* Een bed erbij: dat is meteen een gast erbij, want bedden zijn de
   harde gastenlimiet (HOTEL.md 2). */
function voegBed(kamerId, plek, id) {
  var p = plek || {};
  return meubelZet(kamerId, 'bed', p.x, p.z, p.rot, id);
}

function meubelWeg(id) {
  var weg = false;
  RUIMTES.forEach(function (r) {
    var s = r.slots.length, d = r.decor.length;
    r.slots = r.slots.filter(function (q) { return q.meubel !== id; });
    r.decor = r.decor.filter(function (q) { return q.meubel !== id; });
    if (r.slots.length !== s || r.decor.length !== d) { basis(r); bouwAf(r); weg = true; }
  });
  return weg;
}

function meubels(kamerId) {
  var uit = [];
  RUIMTES.forEach(function (r) {
    if (kamerId && r.id !== kamerId) return;
    r.slots.forEach(function (q) {
      if (q.meubel) uit.push({ id: q.meubel, kamer: r.id, soort: q.soort, x: q.x, z: q.z });
    });
    r.decor.forEach(function (q) {
      if (q.meubel) uit.push({ id: q.meubel, kamer: r.id, soort: 'decor', x: q.x, z: q.z, n: q.n });
    });
  });
  return uit;
}

/* =====================================================================
   DEURGRAAF: kortste route van kamer naar kamer (breedte-eerst)
===================================================================== */
function pad(van, naar) {
  if (van === naar) return [van];
  if (!BY_ID[van] || !BY_ID[naar]) return [];
  var rij = [van], gezien = {}, vorige = {}, i, k, buur;
  gezien[van] = 1;
  while (rij.length) {
    k = rij.shift();
    var dp = BY_ID[k].deurPunten;
    for (i = 0; i < dp.length; i++) {
      buur = dp[i].naar;
      if (gezien[buur] || !BY_ID[buur]) continue;
      gezien[buur] = 1; vorige[buur] = k;
      if (buur === naar) {
        var uit = [naar], q = naar;
        while (vorige[q]) { q = vorige[q]; uit.unshift(q); }
        return uit;
      }
      rij.push(buur);
    }
  }
  return [];
}

function deur(kamerId, naar) {
  var r = BY_ID[kamerId];
  if (!r) return null;
  for (var i = 0; i < r.deurPunten.length; i++) if (r.deurPunten[i].naar === naar) return r.deurPunten[i];
  return null;
}

function slots(kamerId, soort) {
  var r = BY_ID[kamerId];
  if (!r) return [];
  var uit = soort === 'vrij' ? r.vrij : r.slots.filter(function (s) { return !soort || s.soort === soort; });
  return uit;
}
function slot(kamerId, slotId) {
  var lijst = slots(kamerId);
  for (var i = 0; i < lijst.length; i++) if (lijst[i].id === slotId) return lijst[i];
  var v = slots(kamerId, 'vrij');
  for (i = 0; i < v.length; i++) if (v[i].id === slotId) return v[i];
  return null;
}

/* =====================================================================
   VLOEREN - kleur per vakje van 4 x 4 voxels
===================================================================== */
var PLANK = ['#E4CBA6', '#DCC29B'], PLANK_D = '#D2B58C';
var TEGEL = ['#EDE6DA', '#D9E6E2'];
var ZACHT = ['#E6D3B8', '#DFC9AC'];
var LOPER = ['#E9DCC6', '#E2D3BA'], LOPER_M = ['#D68FA0', '#CE8496'];
var GRAS = ['#AFD595', '#AAD190', '#B4D89A', '#ACD392'];
var WEI = ['#9DC486', '#98C081'];

function hash2(x, z) {
  return (Math.imul(x * 73856093 ^ z * 19349663, 2654435761) >>> 24);
}
function vloerKleur(r, x, z) {
  var k = hash2(x, z), i;
  if (r.matten) {
    for (i = 0; i < r.matten.length; i++) {
      var m = r.matten[i];
      if (x >= m.x0 && x < m.x1 && z >= m.z0 && z < m.z1) return m.kl[k & 1];
    }
  }
  if (r.vloer === 'gras') {
    if (x < HEK_X || z < HEK_Z) return WEI[k & 1];
    return GRAS[k & 3];
  }
  if (r.vloer === 'tegel') return TEGEL[((x >> 2) + (z >> 2)) & 1];
  if (r.vloer === 'loper') {
    if (z >= 8 && z < r.d - 6) return LOPER_M[(x >> 2) & 1];
    return LOPER[k & 1];
  }
  if (r.vloer === 'zacht') return ZACHT[(z >> 2) & 1];
  return ((z >> 2) & 3) === 0 ? PLANK_D : PLANK[(z >> 2) & 1];
}

return {
  lijst: function () { return RUIMTES; },
  get: function (id) { return BY_ID[id] || null; },
  pad: pad, deur: deur, slots: slots, slot: slot,
  plekken: function (id) { return (BY_ID[id] || {}).plekkenLijst || [[0, 0]]; },
  model: model, vloerKleur: vloerKleur, kader: kader,
  meubelZet: meubelZet, voegBed: voegBed, meubelWeg: meubelWeg,
  meubels: meubels, herstel: herstel, MEUBEL: MEUBEL,
  vrijVak: function (kamerId, x, z) { var r = BY_ID[kamerId]; return r ? naarRaster(r, x, z) : null; },
  MUUR: MUUR, HOUT: HOUT, HOUT_D: HOUT_D, DEURKL: DEURKL
};
})();
