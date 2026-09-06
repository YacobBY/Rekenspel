/* ---------------------------------------------------------------
   games/hinkel.js - HET HINKELPAD (HOTEL.md 9: rekenen ín de wereld).

   Alles gebeurt in de tuin, in de strook die P1a langs de achterrand
   heeft vrijgehouden (Rooms.get('tuin').zones.hinkel: 76 x 16 voxels
   vlak vóór het hok, met 4 voxels lucht tot de souvenirkraam):

     * de stapstenen liggen als GETALLENLIJN van 0 tot E in die strook, elk
       als eigen los decorstuk (Rooms.registerModel 'steen' +
       ctx.wereld.decor) met zijn getal als voxelbordje IN het model - een
       cijfer per steen kán geen hotspot zijn, want de knoppenlaag houdt er
       maar 16 per kamer. Band 3: 11 stenen (0..10), steek 7 voxels = 14 px,
       en ELKE steen draagt zijn cijfer. Band 4/5: 21 stenen (elke 5), steek
       3,5 voxel = 7 px, dus daar dragen de tientallen het cijfer (een bordje
       van twee tekens is 9 voxels = 18 px breed; zie steenGetal);
     * bij het doel staat een houten trapje ('trap') met het DOELGETAL in
       zijn eigen model gebakken - niet als losse chip, want dan belandden
       het getal van de trap en het getal van de gast op het einde op
       elkaar;
     * het getal van de gast staat als grote, leesbare cijferchip boven zijn
       kop (wereld.getalTag, 48 px) en telt tijdens het hinkelen de sprongen
       mee (1 … 2 … 3);
     * de gasten die niet meedoen worden van de stenenstrook af gestuurd (de
       tuin heeft daar dwaalplekken) en blijven ernaast wachten zolang de
       beurt loopt (houdVrij);
     * de kaart laat zijn keuzestrook pas zien als de gast op zijn startsteen
       staat; komt hij nog aanlopen uit een andere kamer, dan zegt de kaart
       "<naam> komt eraan / Tel straks mee" (een opdracht loopt namelijk
       binnen de huidige kamer, api-p1c, dus er wordt nooit buiten de tuin
       gehinkeld);
     * de kaart vóór het pad vraagt eerst de SPRONGMAAT (keuzestrook
       "🪨 sprong 2 / 5 / 10" - alleen maten die de afstand precies
       opdelen) en daarna het AANTAL sprongen (vier keuzes, precies één
       goede, nooit twee dezelfde, nooit nul);
     * het dier hupt steen voor steen (wereld.stappen met pose 'spring'),
       telt bij elke landing mee op zijn eigen getaltag (1 … 2 … 3) en
       laat Snd.hup horen;
     * te kort: het dier staat vóór de trap en de beurt gaat gewoon
       verder vanaf die steen; te ver: "Oei, te ver!" en de kaart vraagt
       de weg terug (sprongen achteruit); precies: "Precies op de trap!",
       een ster, en het dier hinkelt blij het trapje op.

   HET REKENEN (HOTEL.md 3: T = k·N + r, hier met r = 0, zodat de
   afstand altijd precies deelbaar is door de sprongmaat):

     band  lijn   stenen  sprongmaten  start              voorbeeld
     3     0-10   11 (1)  1, 2, 5      in de tafel van k  van 0 naar 8 met 2
     4     0-100  21 (5)  2, 5, 10     op een tiental      van 30 naar 80 met 10
     5     0-100  21 (5)  2 t/m 10     5, 15, 25, ...      van 15 naar 45 met 10

   De sprongmaat k komt uit de bandlijst (dag + N), het aantal sprongen
   uit N (minstens 2, hooguit 10) en de afstand is k × aantal, zo nodig
   bijgeschoven tot er minstens TWEE sprongmaten precies op passen (dan
   is de keuzestrook een echte keuze) en tot de afstand een veelvoud is van
   de stenenmaat, zodat het trapje altijd ÓP een steen staat. Het doel ligt
   nooit op de laatste steen: er blijft altijd minstens één steen over, anders
   zou "te ver" niet kunnen bestaan. Cijfers blijven binnen de band: band 3
   t/m 10, band 4 alleen de tafels 2, 5 en 10, band 5 t/m 10 × 10.

   WAT DE API (NOG) NIET HEEFT - hier binnen opgelost:
   * registry.js hangt de spelknop aan een VAST voorwerp (World.dingPlek /
     Rooms.slot / kamer.decor). Onze stenen zijn los decor dat pas in
     start() bestaat, dus de knop hangt aan het hok - het vaste voorwerp
     waar de hinkelstrook vlak vóór ligt - en schuift met dx/dz precies
     op de eerste steen. Zo staat het icoontje toch op steen 0.
   * er is geen getallenlijn-generator in state.sommen (alleen deel, geld,
     klok, tafel); de getallen komen daarom uit N, band en dag, precies
     de schaalregel van HOTEL.md 3, maar de afleiding staat hier.
   * Dit spel hangt geen eigen resize-luisteraars op: de hele opstelling is in
     VOXELS uitgemeten en die schaalt de motor zelf mee. Alleen de plek van de
     kaart wordt ná het tekenen nagemeten en dan in één stap goed gezet
     (kaartPast, hooguit vier rondes). Wie hier tóch op een kadermaat moet
     rekenen, gebruikt Ui.opKader(fn) - dat leunt op World.onKader als die er
     is en doet het anders zelf.

   KNOPPEN IN DE TUIN (hits.js houdt er 16 per kamer). Gemeten tijdens een
   beurt met drie gasten: 6 - deur_tuin_keuken, deur_tuin_zwembad, game_tobbe,
   hk_som, hk_som_keuzes, getal_hk_gast. De wenswolkjes van de gasten staan
   tijdens een spel geparkeerd en de naamplaatjes komen uit world.js, dus die
   tellen niet mee. De 11 (band 3) of 21 (band 4/5) stenen en het trapje zijn
   LOS DECOR en kosten geen enkele knop; het doelgetal zit in het model van het
   trapje. Er is dus ruim plek over voor het spel dat straks in de kraamzone
   komt te staan (G5).
---------------------------------------------------------------- */
(function () {
'use strict';

var C = null;          /* de ctx */
var S = null;          /* de beurt (leeft in C.data().stand, wordt bewaard) */
var kaart = null;      /* de sommenkaart */
var klok = [];         /* lopende tikjes; stop() ruimt ze op */
var uitU = 0, uitY = 0;   /* correctie op de kaartplek, in voxels (kaartPast) */
var kaartRondes = 0, kaartCheckT = null, kaartFase = '';
var wachtT = null;     /* het tikje dat op een aanlopende gast wacht */
var opzij = [];        /* gasten die we van de stenenstrook af hebben gestuurd */
var hopNr = 0;         /* elke sprongreeks krijgt een nummer: een ingehaalde
                          reeks die alsnog terugkomt beslist niets meer */

var MAX_HOP = 10;      /* nooit meer dan tien sprongen (HOTEL.md 3) */
/* Band 3 heeft een KORTE lijn: 0 t/m 10 met 11 stenen. Op de 76 voxels van de
   zone is de steek dan 7 voxels = 14 css-px, en daar past een cijferbordje van
   één teken (5 voxels = 10 px) op ÉLKE steen. HOTEL.md 3 vraagt voor groep 3
   ook "≤ 20, liefst ≤ 10". Band 4 en 5 hebben 21 stenen (elke 5) met de
   cijfers op de tientallen; daar is de steek 3,5 voxel en past alleen op elke
   tweede steen een bordje van twee tekens (zie steenGetal). */
var BAND = {
  3: { E: 10,  stap: 1, stenen: 11, sprongen: [1, 2, 5] },
  4: { E: 100, stap: 5, stenen: 21, sprongen: [2, 5, 10] },
  5: { E: 100, stap: 5, stenen: 21, sprongen: [2, 3, 4, 5, 6, 7, 8, 9, 10] }
};
var DIER_ICO = { puppy: '🐶', poes: '🐱', konijn: '🐰', gans: '🦆' };

/* kleuren uit hetzelfde warme palet als rooms.js */
var STEEN = '#C7C2B4', STEEN_TOP = '#DAD5C6';          /* gewone stapsteen */
var STEEN_G = '#BFAE92', STEEN_G_TOP = '#D8CBAE';      /* elke vijfde / tiental */
var BORD = '#FFFDF6', INKT = '#4A3B33';
var HOUT = '#D0A87A', HOUT_D = '#B98F62', HOUT_L = '#E2C094', VLAG = '#F5B0C2';

function straks(ms, fn) { var t = setTimeout(fn, ms); klok.push(t); return t; }
function stopKlok() { klok.forEach(function (t) { clearTimeout(t); }); klok = []; }
function mv(n, enk, meerv) { return n + ' ' + (n === 1 ? enk : meerv); }

/* =====================================================================
   1. DE MODELLEN: een stapsteen met zijn getal, en het trapje
   Voxellijst [x, y, z, kleur]; het anker (0,0,0) ligt op de vloer, in het
   midden van het stuk. +x loopt naar rechtsonder, +z naar linksonder,
   y omhoog.
===================================================================== */
/* Cijfers van 3 x 5 voxels. bake() laat van een voxel het bovenvlak, het
   +x-vlak en het +z-vlak zien, en het +z-vlak kijkt naar de kijker. Een
   bordje in het x/y-vlak met de cijfers één voxel ervóór leest dus als een
   plat naambordje - net als de wijzerplaat van de halklok in api-p1b. */
var CIJFER = {
  '0': ['111', '101', '101', '101', '111'],
  '1': ['010', '110', '010', '010', '111'],
  '2': ['111', '001', '111', '100', '111'],
  '3': ['111', '001', '111', '001', '111'],
  '4': ['101', '101', '111', '001', '001'],
  '5': ['111', '100', '111', '001', '111'],
  '6': ['111', '100', '111', '101', '111'],
  '7': ['111', '001', '010', '010', '010'],
  '8': ['111', '101', '111', '101', '111'],
  '9': ['111', '101', '111', '001', '111']
};
/* breedte van een getalbordje in voxels: 3 per cijfer + 1 kier ertussen */
function getalBreed(txt) { return String(txt).length * 4 - 1; }
/* Het bordje is ÉÉN plaat van één voxel dik, en het cijfer is op diezelfde
   plaat bijgeverfd - niet als blokjes ervóór. Dat is het verschil tussen een
   leesbaar cijfer en een rij bruine bobbels: het vlak dat naar de kijker
   kijkt (+z) krijgt zo een plat, scherp patroon van 2 x 2 css-px per
   fontpunt in plaats van twintig kubusjes met elk drie eigen vlakken. */
function bakGetal(v, txt, dx, y0, zp) {
  var w = getalBreed(txt), x0 = Math.round(dx - (w - 1) / 2);
  var r, c, i, kol, rij, aan;
  for (r = -1; r <= 5; r++) {
    for (c = -1; c <= w; c++) {
      aan = false;
      if (r >= 0 && r <= 4 && c >= 0 && c < w) {
        i = Math.floor(c / 4);
        kol = c - i * 4;
        rij = CIJFER[txt.charAt(i)];
        aan = kol < 3 && !!rij && rij[r].charAt(kol) === '1';
      }
      v.push([x0 + c, y0 + 4 - r, zp, aan ? INKT : BORD]);
    }
  }
}

/* Rooms.registerModel geeft false bij een beschermde (ingebouwde) naam;
   'steen' en 'trap' zijn vrij, en opnieuw aanmelden mag. */
Rooms.registerModel('steen', function (p) {
  var K = Art.kit, v = [], getal = p ? p.getal : null, groot = !!(p && p.groot);
  var kl = groot ? STEEN_G : STEEN, top = groot ? STEEN_G_TOP : STEEN_TOP;
  var dx = (p && p.dx) || 0, b = groot ? 5 : 4, y0;
  /* de tegel: een platte stapsteen, de mijlsteen (elk vijfde/tiende) iets
     groter en donkerder, zodat het pad zelf al een maatstreepje heeft */
  K.bx(v, -Math.floor(b / 2), 0, -2, b, 2, 5, kl);
  K.verf(v, -3, 3, 1, 1, -2, 2, top);              /* lichte bovenkant */
  if (getal !== null && getal !== undefined && getal !== '') {
    /* het cijferbordje staat ACHTER de steen en komt er net bovenuit: zo
       dekt het de steen niet af en blijft het pad een pad (niet een hek) */
    y0 = 2 + (((p && p.rij) || 0) | 0) * 8;
    bakGetal(v, String(getal), dx, y0, -3);
  }
  return v;
});

Rooms.registerModel('trap', function (p) {
  var K = Art.kit, v = [], j, h, getal = p ? p.getal : null;
  /* drie treden die met het pad mee omhoog lopen (naar +x), met een lichte
     bovenkant per trede en een donkere stootrand: zo lees je het als een
     trapje en niet als een houtblok */
  for (j = 0; j < 3; j++) {
    h = 3 + 3 * j;
    K.bx(v, -3 + 2 * j, 0, -2, 2, h, 5, HOUT);
    K.verf(v, -3 + 2 * j, -2 + 2 * j, h - 1, h - 1, -2, 2, HOUT_L);
    K.verf(v, -3 + 2 * j, -2 + 2 * j, 0, h - 2, 2, 2, HOUT_D);
  }
  /* Het DOELGETAL hoort bij het trapje en zit daarom IN dit model, niet in een
     losse cijferchip: twee chips (het getal van de gast en het getal van de
     trap) belandden op het einde precies op elkaar boven het naamplaatje. Het
     bordje staat boven de bovenste trede - dus vrij van de stenen ervoor - met
     een roze kapje als vlaggetje, want dit is het doel van de beurt. */
  if (getal !== null && getal !== undefined && getal !== '') {
    var dx = (p && p.dx) || 0, w = getalBreed(String(getal));
    var x0 = Math.round(dx - (w - 1) / 2);
    bakGetal(v, String(getal), dx, 10, 0);
    K.verf(v, x0 - 1, x0 + w, 15, 15, 0, 0, VLAG);
    K.bx(v, x0 - 1, 16, 0, w + 2, 1, 1, VLAG);     /* het kapje twee voxels hoog */
  }
  return v;
});

/* =====================================================================
   2. DE MAATVOERING VAN HET PAD - alles in voxels, dus schermmaat-vrij
   Band 3: 11 stenen (elke 1, lijn 0..10), steek 7 voxels. Band 4 en 5: 21
   stenen (elke 5, lijn 0..100), steek 3,5 voxel. De tegel is 4 voxels breed
   en het breedste bordje 13, dus het pad begint 3 voxels binnen de rand van
   de zone en eindigt 3 voxels ervoor; een bordje dat buiten de zone zou
   vallen schuift met dx naar binnen.
   DRIE RIJEN IN DE DIEPTE, met opzet apart (api-p1b: gelijke diepte is niet
   gedefinieerd): de stenen op z = 41, het trapje op z = 45 (vóór de stenen,
   anders verdwijnt het achter de bordjes van de stenen rechts ervan) en de
   looplijn van het dier op z = 44 - behalve op het einde, dan stapt de gast
   naar z = 47 en staat hij ÓP het trapje.
===================================================================== */
var STENEN_MAX = 21;   /* de meeste stenen die een band kan hebben */
function zone() {
  var r = (C ? C.wereld.kamer('tuin') : (window.Rooms && Rooms.get('tuin'))) || null;
  var z = r && r.zones && r.zones.hinkel;
  if (z && z.x0 !== undefined) return z;
  return { x0: 24, x1: 100, z0: 34, z1: 50 };      /* terugval, mocht P1a wijken */
}
function stenenVan(band) { return BAND[bandOf(band)].stenen; }
function padMaat(band) {
  var z = zone(), n = stenenVan(band);
  var eerste = z.x0 + 3, laatste = z.x1 - 3;
  var zs = Math.round((z.z0 + z.z1) / 2) - 1;      /* 41 in de echte zone */
  return { eerste: eerste, laatste: laatste, stenen: n,
           steek: (laatste - eerste) / (n - 1),
           zSteen: zs, zDier: zs + 3, zTrap: zs + 4, zTop: zs + 6, zone: z };
}
function bandOf(band) {
  band = (band === undefined || band === null) ? (S ? S.band : 3) : band;
  return band <= 3 ? 3 : band >= 5 ? 5 : 4;
}
/* x van getal n op de lijn (0 = eerste steen, E = laatste steen) */
function xVan(n, band) {
  var m = padMaat(band), E = BAND[bandOf(band)].E;
  return m.eerste + (m.laatste - m.eerste) * (+n || 0) / E;
}
/* Een stuk dat 3 voxels naar de kijker toe staat, staat op het scherm 6 px
   naar LINKS (px = (x - z) * 2): de diepte-rijen hierboven zouden het dier en
   het trapje dus naast hun eigen steen zetten. Elke rij krijgt daarom zijn x
   met precies dat verschil erbij, zodat alles in dezelfde SCHERMKOLOM als de
   steen blijft staan (x - z is voor alle vier de rijen gelijk). */
function xOpRij(n, z0, band) {
  var m = padMaat(band);
  return xVan(n, band) + (z0 - m.zSteen);
}
function dierX(n, band) { return xOpRij(n, padMaat(band).zDier, band); }
function getalVanSteen(i, band) { return i * BAND[bandOf(band)].stap; }
/* WELKE STEEN KRIJGT EEN CIJFER? De zone is 76 voxels lang, en gemeten op een
   telefoon van 420 px is dat 152 css-px (127 px op 320 px breed).
     band 3: 11 stenen -> steek 7 voxels = 14 px, en een bordje van ÉÉN teken
             is 5 voxels = 10 px: elke steen krijgt zijn getal (0..10).
     band 4/5: 21 stenen -> steek 3,5 voxel = 7 px, en een bordje van twee
             tekens is 9 voxels = 18 px. Daar past dus alleen op elke tweede
             steen een cijfer: de tientallen, over twee hoogtes afgewisseld. */
function steenGetal(i, band) {
  var b = bandOf(band), n = getalVanSteen(i, b);
  if (b === 3) return n;                           /* elke steen zijn getal */
  return n % 10 === 0 ? n : null;                  /* de tientallen */
}
/* Op welke hoogte hangt het bordje? Twee bordjes op dezelfde hoogte moeten los
   van elkaar staan. In band 3 is alleen "10" twee tekens breed (9 voxels op een
   steek van 7): dat ene bordje gaat een rij hoger. In band 4/5 wisselen de
   tientallen om en om van hoogte. */
function rijVanSteen(i, band) {
  var b = bandOf(band), n = steenGetal(i, b);
  if (n === null) return 0;
  if (b === 3) return String(n).length > 1 ? 1 : 0;
  return Math.floor(i / 2) % 2;
}
/* het bordje binnen de zone houden (het randje van 1 voxel telt mee) */
function bordDx(x, txt) {
  var z = zone(), hw = getalBreed(txt) / 2 + 1, dx = 0;
  if (x - hw < z.x0) dx = z.x0 - (x - hw);
  if (x + hw > z.x1) dx = z.x1 - (x + hw);
  return Math.round(dx);
}

/* =====================================================================
   3. DE GETALLEN
===================================================================== */
/* hoeveel sprongmaten passen precies op deze afstand? */
function matenVoor(afst, band) {
  var B = BAND[bandOf(band)], uit = [], i, k;
  for (i = 0; i < B.sprongen.length; i++) {
    k = B.sprongen[i];
    if (afst % k === 0 && afst / k <= MAX_HOP && afst / k >= 1) uit.push(k);
  }
  return uit;
}
function beurt(N, band, dag) {
  band = bandOf(band);
  N = Math.max(1, N | 0);
  dag = Math.max(1, dag | 0);
  var B = BAND[band], E = B.E, stap = B.stap, lijst = B.sprongen;
  /* het doel ligt nooit op de laatste steen: anders kan "te ver" niet */
  var ruimte = E - stap;
  var k = lijst[(dag + N) % lijst.length];
  var n = Math.min(Math.max(2, N), MAX_HOP), i, kl;
  while (k * n > ruimte && n > 2) n--;
  while (k * n > ruimte) {                 /* zelfs twee sprongen passen niet */
    kl = k;
    for (i = 0; i < lijst.length; i++) if (lijst[i] < k && lijst[i] * 2 <= ruimte) { kl = lijst[i]; break; }
    if (kl === k) break;
    k = kl;
  }
  /* Twee eisen aan de afstand:
     1. de keuzestrook moet een ÉCHTE keuze zijn: er passen minstens TWEE
        sprongmaten precies op de afstand;
     2. de afstand is een veelvoud van de stenenmaat, zodat de TRAP altijd op
        een steen staat (band 4/5: elke 5; band 3: elke 1, dus altijd waar).
     Klopt dat niet, dan schuiven we het AANTAL sprongen op (eerst omhoog: een
     langer pad is leerzamer dan een korter) en anders de sprongmaat. */
  var past = function (a) {
    return a >= 2 && a <= ruimte && a % stap === 0 && matenVoor(a, band).length >= 2;
  };
  var afst = k * n, best = 0, orde = [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5], i2, j, kk, nn;
  for (i2 = 0; i2 < orde.length && !best; i2++) {
    nn = n + orde[i2];
    if (nn < 2 || nn > MAX_HOP) continue;
    if (past(k * nn)) { best = k * nn; n = nn; }
  }
  for (j = 0; j < lijst.length && !best; j++) {           /* dan een andere maat */
    kk = lijst[(j + dag) % lijst.length];
    for (i2 = 0; i2 < orde.length && !best; i2++) {
      nn = n + orde[i2];
      if (nn < 2 || nn > MAX_HOP) continue;
      if (past(kk * nn)) { best = kk * nn; k = kk; n = nn; }
    }
  }
  afst = best || Math.max(stap, Math.min(afst - (afst % stap), ruimte));
  var maxS = Math.max(0, ruimte - afst), s;
  if (band === 4) {
    s = 10 * (dag % (Math.floor(maxS / 10) + 1));            /* op een tiental */
  } else if (band === 5) {
    /* juist NIET op een tiental, maar wel op een steen: 5, 15, 25, … */
    s = maxS >= 5 ? 5 + 10 * ((dag + N) % (Math.floor((maxS - 5) / 10) + 1)) : 0;
  } else {
    s = k * (dag % (Math.floor(maxS / k) + 1));              /* in de tafel van k */
  }
  return { band: band, E: E, stap: stap, s: s, doel: s + afst,
           sprong: k, n: Math.round(afst / k), afstand: afst };
}

/* afstand, richting en sprongmaten van de HUIDIGE stand */
function afstand() { return Math.abs(S.doel - S.s); }
function richting() { return S.doel >= S.s ? 1 : -1; }
function maten() {
  var a = afstand(), uit = matenVoor(a, S.band), B = BAND[bandOf(S.band)], i;
  if (!uit.length)                        /* liever veel stapjes dan geen weg */
    for (i = 0; i < B.sprongen.length; i++) if (a % B.sprongen[i] === 0) uit.push(B.sprongen[i]);
  if (!uit.length) uit.push(1);
  if (uit.length > 3) uit = [uit[0], uit[Math.floor(uit.length / 2)], uit[uit.length - 1]];
  return uit;
}
function aantalGoed(k) { return afstand() / (k || S.sprong || 1); }
/* vier keuzes: precies één goede, geen dubbele, nooit nul of negatief */
function keuzeGetallen(n, zaad) {
  var pool = [-2, -1, 1, 2, 3], uit = [n], i, k, v;
  zaad = Math.abs(zaad | 0);
  for (i = 0; i < pool.length && uit.length < 4; i++) {
    k = pool[(i + zaad) % pool.length];
    v = n + k;
    if (v >= 1 && uit.indexOf(v) < 0) uit.push(v);
  }
  for (v = n + 1; uit.length < 4; v++) if (uit.indexOf(v) < 0) uit.push(v);
  uit.sort(function (a, b) { return a - b; });
  return uit;
}
/* samen tellen langs de lijn: "50 … 60 … 70." */
function telPad(k) {
  var n = aantalGoed(k), r = richting(), l = [], i;
  for (i = 1; i <= Math.min(n, 4); i++) l.push(S.s + r * k * i);
  if (n > 4) { l.push('…'); l.push(S.doel); }
  return l.join(' … ') + '.';
}

/* =====================================================================
   4. DE GASTEN
===================================================================== */
function gasten() {
  return C.state.gasten().filter(function (g) { return !!g.bed; });
}
function spelers() {
  var alle = gasten();
  var wil = alle.filter(function (g) { return g.behoefte === 'spelen' && !g.blij; });
  var lijst = wil.length ? wil : alle;
  /* wie al in de tuin is, hoeft niet eerst het halve hotel door te lopen */
  return lijst.slice().sort(function (a, b) {
    var da = C.wereld.dier(a.id), db = C.wereld.dier(b.id);
    return ((db && db.kamer === 'tuin') ? 1 : 0) - ((da && da.kamer === 'tuin') ? 1 : 0);
  });
}
function gast() { return S ? C.state.gast(S.gast) : null; }
function ico(g) { return (g && DIER_ICO[g.soort]) || '🐾'; }
function naam() { var g = gast(); return (g && g.naam) || 'De gast'; }

/* =====================================================================
   5. START / STOP
===================================================================== */
function nieuweStand(N, band, dag, gastId) {
  var b = beurt(N, band, dag);
  return { dag: dag, N: N, band: b.band, E: b.E, stap: b.stap, gast: gastId,
           s: b.s, doel: b.doel, sprong: null, n: b.n, hops: 0, tel: 0, wacht: 0,
           fase: 'sprong', melding: 'start', missers: 0, pogingen: 0,
           ster: 0, wens: 0, t0: 0 };
}

function start(ctx) {
  C = ctx;
  var lijst = spelers();
  if (!lijst.length) {
    C.ui.wolk('hok', { id: 'hk_leeg', kamer: 'tuin', icoon: '🛏',
                       tekst: 'nog geen gasten', hoog: 26 });
    straks(1800, function () { if (C) { C.ui.wolkWeg('hk_leeg'); C.sluit(); } });
    return;
  }
  var d = C.data(), N = gasten().length, band = C.state.band(), dag = C.state.dag();
  S = d.stand;
  /* een halve beurt uit de opslag mag verder, maar alleen als de dag, het
     aantal gasten, de band én de gast nog kloppen */
  if (!S || S.fase === 'af' || S.dag !== dag || S.N !== N || S.band !== bandOf(band) ||
      !S.gast || !C.state.gast(S.gast)) {
    S = nieuweStand(N, band, dag, lijst[0].id);
    d.stand = S;
  }
  S.t0 = C.ui.nu();
  S.wacht = 0;
  if (S.fase === 'hop') S.fase = 'sprong';    /* een sprong overleeft geen herlaad */
  uitU = 0; uitY = 0; kaartRondes = 0; kaartCheckT = null; kaartFase = '';
  hopNr++;
  opzij = [];
  zetDecor();
  haalGast();
  C.wereld.naar('tuin');
  teken();
  houdVrij();          /* de rest van de gasten van de stenen af */
  wachtStart();        /* en kijken wanneer onze gast op zijn steen staat */
  C.state.bewaar();
}

function stop() {
  stopKlok();
  hopNr++;
  wachtT = null;
  if (C) {
    /* een lopende sprongreeks netjes afbreken: een houding is een nieuw bevel,
       dus de belofte van stappen() valt false en het dier blijft niet in de
       lucht hangen als het spel midden in een sprong stopt (api-p1c 2) */
    if (S && S.fase === 'hop' && S.gast) C.wereld.pose(S.gast, 'wacht');
    laatLos();
    C.hotspots.wisAlles();
    C.hotspots.laat();
    /* het los decor gaat ook automatisch weg (Hits.voorrang wordt door
       world.js omhuld), maar niet als hits.js er niet is: deze ene regel
       maakt het opruimen daar onafhankelijk van */
    C.wereld.decorWisAlles();
  }
  C = null; S = null; kaart = null;
  uitU = 0; uitY = 0; kaartRondes = 0; kaartCheckT = null; kaartFase = '';
}

/* =====================================================================
   6. DE WERELD: stenen en trapje neerzetten
===================================================================== */
function zetDecor() {
  var m = padMaat(), i, x, n, dx, groot = bandOf(S.band) === 3 ? 5 : 10;
  for (i = 0; i < m.stenen; i++) {
    x = m.eerste + m.steek * i;
    n = steenGetal(i, S.band);
    dx = n === null ? 0 : bordDx(x, String(n));
    C.wereld.decor('tuin', {
      id: 'hk_steen' + i, model: 'steen', x: x, z: m.zSteen,
      params: { getal: n, rij: rijVanSteen(i, S.band), dx: dx,
                groot: n !== null && n % groot === 0 }
    });
  }
  /* een band met minder stenen laat er nooit een paar van de vorige staan */
  for (i = m.stenen; i < STENEN_MAX; i++) C.wereld.decorWeg('tuin', 'hk_steen' + i);
  /* Het trapje staat VÓÓR de stenenrij (vier voxels), want anders verdwijnt
     het achter de cijferbordjes van de stenen die er rechts van liggen: die
     hebben een grotere diepte en worden dus later getekend (api-p1b: gelijke
     diepte is niet gedefinieerd, en groter = vóór). Alleen op het einde stapt
     de gast er nog een stukje vóór, zodat hij ÓP het trapje lijkt te staan. */
  x = xOpRij(S.doel, m.zTrap);
  C.wereld.decor('tuin', { id: 'hk_trap', model: 'trap', x: x, z: m.zTrap,
                           params: { getal: S.doel, dx: bordDx(x, String(S.doel)) } });
}

/* ---------- de gast naar zijn startsteen brengen ----------
   Een opdracht loopt altijd BINNEN de kamer waar het dier nu is (api-p1c), dus
   een gast die nog in kamer 1 ligt moet eerst het hotel door lopen. Zolang hij
   niet op zijn steen staat, laat de kaart alleen zien dat hij eraan komt: de
   keuzestrook verschijnt pas als hij er is. */
function opStartSteen() {
  if (!C || !S) return false;
  var g = gast(), m = padMaat(), d = g && C.wereld.dier(g.id);
  if (!d || d.kamer !== 'tuin') return false;
  return Math.abs(d.x - dierX(S.s)) <= 2.5 && Math.abs(d.z - m.zDier) <= 3.5;
}
function haalGast() {
  var g = gast(), m = padMaat(), d;
  if (!g) return;
  d = C.wereld.dier(g.id);
  if (!d) return;
  if (d.kamer !== 'tuin') {
    g.waar = 'tuin';
    C.wereld.reis(g.id, 'tuin', { x: dierX(S.s), z: m.zDier, na: 'wacht' });
    return;
  }
  if (!opStartSteen()) C.wereld.loopNaar(g.id, dierX(S.s), m.zDier, { tempo: 1.4, na: 'wacht' });
}
/* Elke halve seconde kijken of hij er al is; is hij er, dan tekenen we opnieuw
   (en dan staat de keuzestrook er). Duurt het lang (na ~12 s) en is hij nóg in
   een andere kamer, dan sturen we hem opnieuw op weg - een reis kan onderweg
   zijn ingehaald door de motor of door een ander spel. */
function wachtOpGast() {
  wachtT = null;
  if (!C || !S || S.fase === 'af') return;
  if (opStartSteen()) { if (S.wacht) { S.wacht = 0; teken(); } return; }
  var g = gast(), d = g && C.wereld.dier(g.id);
  S.wacht = (S.wacht || 0) + 1;
  if (S.wacht === 1) teken();                       /* meteen "komt eraan" */
  if (S.wacht % 24 === 0 && d) haalGast();          /* ~12 s: nog eens sturen */
  wachtT = straks(500, wachtOpGast);
}
/* één ketting tegelijk: anders staan er na een paar tikken tien tijdklokjes
   naast elkaar te wachten op dezelfde gast */
function wachtStart() { if (!wachtT && C && S) wachtOpGast(); }

/* =====================================================================
   7. TEKENEN
===================================================================== */
function sch() {
  var s = C && C.wereld.schaal ? C.wereld.schaal() : null;
  if (!s || !s.pxPerVoxelY) return { pxPerVoxelX: 2, pxPerVoxelY: 1, pxPerHoogte: 2, k: 1 };
  return s;
}
function kader() {
  var h = document.getElementById('worldHits') || document.getElementById('world');
  var r = h && h.getBoundingClientRect ? h.getBoundingClientRect() : null;
  return { w: (r && r.width) || 386, h: (r && r.height) || 468,
           left: (r && r.left) || 0, top: (r && r.top) || 0 };
}
/* liggend kader: de kaart past niet meer ónder het pad, maar wel ernaast */
function liggend() { var f = kader(); return f.w / Math.max(1, f.h) > 1.15; }
/* heel smal kader: dan is één korte regel belangrijker dan een hele zin
   (HOTEL.md 9: het dier blijft zichtbaar gaat vóór de zin) */
function krap() { return kader().w < 320; }

/* Waar hangt de kaart? Staand ligt hij op het gras VÓÓR de stenen (in
   isometrie: dezelfde (x - z), maar dieper), liggend ernaast (dezelfde
   diepte, verder naar links en hoger). uitU/uitY zijn de correcties die
   kaartPast na het meten heeft gevonden. */
function kaartPlek() {
  var m = padMaat(), s = sch(), f = kader();
  var xm = (m.eerste + m.laatste) / 2;
  var u = xm - m.zSteen, d = xm + m.zSteen, y = 0;
  if (liggend()) {
    u -= (m.laatste - m.eerste) / 2 + Math.round(120 / s.pxPerVoxelX);
    y = Math.round(Math.max(40, f.h / 2 - 46) / s.pxPerHoogte);
  } else {
    d += (m.laatste - m.eerste) / 2 + Math.round(74 / s.pxPerVoxelY);
  }
  u += uitU; y += uitY;
  return { kamer: 'tuin', x: (d + u) / 2, z: (d - u) / 2, y: y };
}
/* De hotspot-laag klemt elke knop binnen het kader, dus een kaart die te
   hoog of te laag hangt wordt tegen een rand geplakt. Uit de GEMETEN plek
   van de kaart volgt de hele afbeelding terug (px = c + (x-z)·pxPerVoxelX,
   py = c2 + (x+z-2y)·pxPerVoxelY); daarmee zetten we hem in één stap op de
   plek die vrij is van het pad, van de gast en van de rand. */
function kaartPast() {
  kaartCheckT = null;
  if (!C || !S || kaartRondes > 4) return;
  var host = document.getElementById('worldHits');
  var el = document.querySelector('[data-hot="hk_som"]');
  /* De laag zet een nieuwe knop pas in de VOLGENDE tekenbeurt op zijn plek, en
     in rustmodus kan die even op zich laten wachten. Dan nog niet meten maar
     het opnieuw proberen (hooguit een paar keer, zie kaartRondes). */
  if (!host || !el || !el.offsetHeight) {
    kaartRondes++;
    kaartNakijken();
    return;
  }
  var kz = document.querySelector('[data-hot="hk_som_keuzes"]');
  var h = host.getBoundingClientRect(), r = el.getBoundingClientRect();
  var rk = (kz && kz.offsetHeight) ? kz.getBoundingClientRect() : null;
  var s = sch(), p = kaartPlek(), m = padMaat(), g = gast();
  var d = C.wereld.dier(g && g.id);
  /* de afbeelding terugrekenen uit de gemeten plek van de kaart */
  var cy = (r.top + r.height / 2 - h.top) - ((p.x + p.z) - 2 * p.y) * s.pxPerVoxelY;
  var cx = (r.left + r.width / 2 - h.left) - (p.x - p.z) * s.pxPerVoxelX;
  var yVan = function (x, z, hoog) { return cy + ((x + z) - 2 * (hoog || 0)) * s.pxPerVoxelY; };
  var xVanP = function (x, z) { return cx + (x - z) * s.pxPerVoxelX; };
  var top = r.top - h.top, links = r.left - h.left;
  var blokH = (rk ? rk.bottom - r.top : r.height);
  var blokB = Math.max(r.width, rk ? rk.width : 0);
  var wil, stapY = 0, stapU = 0;
  if (liggend()) {
    wil = 8;
    /* naast het pad: de rechterrand van de kaart blijft links van het dier */
    var dierPx = xVanP(d && d.kamer === 'tuin' ? d.x : m.eerste, m.zDier);
    var rechts = Math.max(r.right - h.left, rk ? rk.right - h.left : 0);
    if (rechts > dierPx - 26) stapU = -Math.round((rechts - (dierPx - 26)) / s.pxPerVoxelX);
    else if (links < 4) stapU = Math.round((6 - links) / s.pxPerVoxelX);
  } else {
    /* onder het pad: onder de laatste steen én onder de pootjes van het dier */
    wil = Math.max(yVan(m.laatste, m.zSteen, 0) + 16,
                   d && d.kamer === 'tuin' ? yVan(d.x, m.zDier, 0) + 8 : 0);
  }
  wil = Math.max(6, Math.min(wil, h.height - blokH - 6));
  stapY = Math.round((top - wil) / s.pxPerHoogte);
  if (blokB > h.width - 8) stapU = 0;             /* past toch niet: laat staan */
  if (!stapY && !stapU) return;
  uitY = Math.max(-160, Math.min(220, uitY + stapY));
  uitU = Math.max(-160, Math.min(160, uitU + stapU));
  kaartRondes++;
  tekenKaart();
  kaartNakijken();
}
function kaartNakijken() { if (!kaartCheckT) kaartCheckT = straks(110, kaartPast); }

function somRegel() { return 'van ' + S.s + ' naar ' + S.doel; }

/* de zin(nen) boven de som: één gewone zin, ≤ 8 woorden en ≤ 40 tekens */
function zinnen() {
  var g = gast(), nm = naam(), k = krap();
  if (S.fase === 'af') return { icoon: '✅', zin: ['Precies op de trap!'] };
  /* nog onderweg naar zijn steen? Dan vertelt de kaart dat, in elke fase, en
     staat er geen keuzestrook onder (tekenKaart) */
  if (!opStartSteen() && S.fase !== 'hop')
    return { icoon: ico(g), zin: k ? ['Komt eraan'] : [nm + ' komt eraan', 'Tel straks mee'] };
  if (S.fase === 'hop') {
    if (!opStartSteen() && !S.tel)
      return { icoon: ico(g), zin: k ? ['Komt eraan'] : [nm + ' komt eraan', 'Tel straks mee'] };
    return { icoon: ico(g), zin: k ? ['Tel maar mee'] : [nm + ' hinkelt', 'Tel maar mee'] };
  }
  if (S.fase === 'aantal') {
    return { icoon: '🪨',
             zin: k ? ['Hoeveel sprongen?']
                    : [nm + ' springt ' + S.sprong + (richting() < 0 ? ' terug' : ' per keer'),
                       'Hoeveel sprongen?'] };
  }
  if (S.melding === 'ver')
    return { icoon: ico(g), zin: k ? ['Oei, te ver!'] : ['Oei, te ver!', 'Kies je sprong terug'] };
  if (S.melding === 'kort')
    return { icoon: ico(g), zin: k ? ['Nog even verder'] : [nm + ' staat op ' + S.s, 'Nog even verder'] };
  return { icoon: ico(g),
           zin: k ? ['Kies je sprong']
                  : [nm + ' staat op ' + S.s + ', trap bij ' + S.doel, 'Kies je sprong'] };
}

function tekenKaart() {
  var z = zinnen(), p = kaartPlek(), keuzes = null, lijst, klaar = opStartSteen();
  if (!klaar) keuzes = null;              /* eerst aankomen, dan kiezen */
  else if (S.fase === 'sprong') {
    lijst = maten();
    keuzes = lijst.map(function (k) {
      return { id: 'k' + k, icoon: '🪨',
               tekst: (richting() < 0 ? 'terug ' : 'sprong ') + k,
               kies: function () { kiesSprong(k); } };
    });
  } else if (klaar && S.fase === 'aantal') {
    lijst = keuzeGetallen(aantalGoed(S.sprong), S.s + S.dag + S.pogingen);
    keuzes = lijst.map(function (n) {
      return { id: 'n' + n, icoon: '🪨', tekst: mv(n, 'keer', 'keer'),
               kies: function () { antwoord(n); } };
    });
  }
  /* Op het einde geen som meer: "van 7 naar 7" is een lege mededeling; dan
     draagt de kaart alleen "✅ Precies op de trap!" met een vinkje. */
  kaart = C.ui.somkaart(p, S.fase === 'af' ? '' : somRegel(), {
    id: 'hk_som', kamer: 'tuin', hoog: p.y, icoon: z.icoon, regel: z.zin,
    klas: S.fase === 'af' ? 'af' : '', keuzes: keuzes, pad: false,
    keuzeTitel: S.fase === 'aantal' ? 'hoeveel sprongen?' : 'kies je sprong'
  });
  if (kaart && S.fase === 'af') kaart.klaar();
  /* de hulpladder van GAMES-API 6: pas bij de tweede misser tellen we samen */
  if (kaart && S.fase === 'aantal' && S.missers >= 2 && !krap()) kaart.hulp(telPad(S.sprong));
  kaartNakijken();
}

/* Het getal van de gast, groot en leesbaar boven zijn kop: tijdens het
   hinkelen telt die chip de sprongen mee (1 … 2 … 3) en daarna staat er het
   getal van de steen waar hij op staat. Het DOELGETAL is geen chip maar zit
   in het model van het trapje (zie hierboven), zodat de twee getallen nooit
   op elkaar kunnen belanden. */
function tekenCijfers() {
  var g = gast(), n;
  C.wereld.getalTag({ x: 0, z: 0 }, null, { id: 'hk_doel' });   /* oude chip weg */
  if (!g) return;
  n = S.fase === 'hop' ? S.tel : S.s;
  C.wereld.getalTag(g.id, n, { id: 'hk_gast', y: 30, prio: 10,
                               titel: S.fase === 'hop' ? 'sprong ' + n
                                                       : g.naam + ' staat op ' + n });
}

function teken() {
  if (!C || !S) return;
  /* Een nieuwe stap in de beurt geeft een kaart van een andere hoogte (met of
     zonder tweede regel, met of zonder strook), dus die mag opnieuw worden
     nagemeten. Binnen één stap blijft het aantal rondes begrensd: nameten
     tekent de kaart opnieuw en dat mag nooit een lus worden. */
  if (kaartFase !== S.fase + '|' + S.melding) {
    kaartFase = S.fase + '|' + S.melding;
    kaartRondes = 0;
  }
  C.hotspots.wisAlles();
  tekenCijfers();
  tekenKaart();
  C.wereld.vuil();
}

/* =====================================================================
   8. SPELEN
===================================================================== */
function kiesSprong(k) {
  if (!S || S.fase !== 'sprong') return;
  S.sprong = k;
  S.n = aantalGoed(k);
  S.fase = 'aantal';
  C.snd.tik();
  C.state.bewaar();
  teken();
}

function antwoord(n) {
  if (!S || S.fase !== 'aantal') return;
  if (!n || n < 1) return;
  /* De keuzestrook staat er pas als de gast op zijn steen staat; via de
     testhaak kan een antwoord toch vroeg binnenkomen. Dan halen we hem eerst
     en blijft de vraag gewoon staan (niets telt mee, niets gaat verloren). */
  if (!opStartSteen()) { haalGast(); wachtStart(); teken(); return; }
  var goed = aantalGoed(S.sprong);
  S.pogingen++;
  if (n !== goed) S.missers++;
  C.state.tel(n === goed, C.ui.nu() - (S.t0 || C.ui.nu()));
  hop(n);
}

/* het dier hupt steen voor steen; per landing telt de tag mee en klinkt hup */
function hop(aantal) {
  var g = gast(), m = padMaat(), r = richting(), i, pos, punten = [];
  if (!g) return;
  /* Een opdracht loopt binnen de kamer waar het dier NU is (api-p1c): staat de
     gast nog niet op zijn steen, dan eerst laten aankomen. De kaart laat op dat
     moment ook geen keuzestrook zien, dus dit is de vangrail voor de testhaak. */
  if (!opStartSteen()) { haalGast(); wachtStart(); return; }
  /* nooit van de lijn af hinkelen: hoogstens tot 0 of tot de laatste steen */
  var max = r > 0 ? Math.floor((S.E - S.s) / S.sprong) : Math.floor(S.s / S.sprong);
  var hops = Math.max(0, Math.min(aantal, max));
  if (!hops) {                            /* er is geen steen om heen te gaan */
    C.snd.zacht();
    if (kaart) kaart.hulp(telPad(S.sprong));
    return;
  }
  for (i = 1; i <= hops; i++) {
    pos = S.s + r * S.sprong * i;
    punten.push({ x: dierX(pos), z: m.zDier });
  }
  S.fase = 'hop';
  S.hops = hops;
  S.tel = 0;
  S.wacht = 0;
  C.state.bewaar();
  teken();
  var mijn = ++hopNr, eind = S.s + r * S.sprong * hops;
  loopEerst(g.id, mijn, function () {
    if (!C || !S || mijn !== hopNr) return;
    C.wereld.stappen(g.id, punten, {
      pose: 'spring', tempo: 1.25,
      perStap: function (i) {
        if (!C || !S || mijn !== hopNr) return;
        S.tel = i + 1;
        C.snd.hup();
        C.wereld.getalTag(g.id, S.tel, { id: 'hk_gast', y: 30, prio: 10,
                                         titel: 'sprong ' + S.tel });
      }
    }).then(function (ok) {
      if (!C || !S || mijn !== hopNr) return;
      if (!ok) { S.fase = 'sprong'; S.sprong = null; teken(); return; }
      geland(eind);
    });
  });
}

/* Laatste correctie vóór de sprongreeks: het dier staat al in de tuin (hop()
   laat niets beginnen zolang dat niet zo is), maar misschien een paar voxels
   naast zijn steen. Buiten de tuin springt hier NOOIT iets: een opdracht loopt
   binnen de huidige kamer (api-p1c), dus dan wachten we op de reis. */
function loopEerst(id, mijn, na) {
  var m = padMaat(), d = C.wereld.dier(id), doelX = dierX(S.s);
  if (!d || d.kamer !== 'tuin') { haalGast(); wachtStart(); return; }
  if (Math.abs(d.x - doelX) <= 2.5 && Math.abs(d.z - m.zDier) <= 3.5) { na(); return; }
  C.wereld.loopNaar(id, doelX, m.zDier, { tempo: 1.4 }).then(function () {
    if (C && S && mijn === hopNr) na();
  });
}

/* =====================================================================
   DE ANDERE GASTEN VAN DE STENENSTROOK AF
   De tuin heeft dwaalplekken midden op de hinkelstrook (drie op z = 42 en nog
   negen ernaast): een gast die daar gaat staan, staat over de cijferbordjes en
   over het trapje heen, en dan is de getallenlijn niet meer te lezen. Bij het
   begin van de beurt sturen we iedereen die niet meedoet naar het gras vóór de
   strook, met na: 'wacht' (dan blijft hij daar tot het volgende bevel: hij
   dwaalt dus niet terug). Elke twee seconden kijken we het na, want een ander
   spel of het hotel kan een dier opnieuw op pad sturen. stop() geeft ze hun
   eigen gang terug met pose('rust').
===================================================================== */
function opStrook(d) {
  var z = zone();
  return !!d && d.kamer === 'tuin' &&
         d.x > z.x0 - 10 && d.x < z.x1 + 10 && d.z > z.z0 - 7 && d.z < z.z1 + 7;
}
/* vrije vakjes op het gras vóór de strook, van links naar rechts */
function grasPlekken() {
  var r = C.wereld.kamer('tuin'), z = zone(), kr = (r.zones && r.zones.kraam) || null;
  return ((r && r.vrij) || []).filter(function (v) {
    if (v.z < z.z1 + 10) return false;                    /* nog te dicht bij het pad */
    if (kr && v.x > kr.x0 - 8 && v.z < kr.z1 + 8) return false;   /* niet bij de kraam */
    return true;
  }).sort(function (a, b) { return (a.x - a.z) - (b.x - b.z); });
}
function houdVrij() {
  if (!C || !S) return;
  var vrij = grasPlekken(), i = 0;
  C.state.gasten().forEach(function (g) {
    if (g.id === S.gast) return;
    var d = C.wereld.dier(g.id);
    if (!opStrook(d)) return;
    var v = vrij[(i++) % Math.max(1, vrij.length)];
    if (!v) return;
    if (opzij.indexOf(g.id) < 0) opzij.push(g.id);
    C.wereld.loopNaar(g.id, v.x, v.z, { na: 'wacht' });
  });
  if (C && S && S.fase !== 'af') straks(2000, houdVrij);
}
function laatLos() {
  if (!C) return;
  opzij.forEach(function (id) { C.wereld.pose(id, 'rust'); });
  opzij = [];
}

function geland(pos) {
  var r = richting(), teVer = (r > 0 && pos > S.doel) || (r < 0 && pos < S.doel), g;
  S.s = pos;
  S.tel = 0;
  if (pos === S.doel) { gelukt(); return; }
  S.sprong = null;
  S.fase = 'sprong';
  S.melding = teVer ? 'ver' : 'kort';
  C.snd.zacht();
  C.state.bewaar();
  teken();
  /* een zacht praatje bij het dier - nooit een kruis */
  g = gast();
  if (g) {
    C.ui.wolk(g.id, { id: 'hk_zeg', kamer: 'tuin', klas: teVer ? 'hulp' : '',
                      icoon: teVer ? '🙃' : '🪨', getal: pos,
                      tekst: teVer ? 'te ver' : 'nog verder', hoog: 52, prio: 9 });
    straks(2400, function () { if (C) C.ui.wolkWeg('hk_zeg'); });
  }
}

function gelukt() {
  var g = gast(), m = padMaat(), mijn;
  S.fase = 'af';
  S.sprong = null;
  C.snd.ja();
  teken();
  if (!S.ster) {
    S.ster = 1;
    C.taakKlaar('hinkel', { sterren: 1 });
  }
  if (g && g.behoefte === 'spelen' && !g.blij) {
    C.wereld.behoefteKlaar(g.id, 'spelen');
    S.wens = 1;
  }
  C.state.bewaar();
  if (window.Hotel) Hotel.render();
  /* het dier hinkelt ÓP het trapje (op de bovenste trede, dus met een grotere
     diepte dan het trapje zelf: dan staat het dier ervóór in de tekenvolgorde
     en dus bovenop) en danst daar even */
  if (g) {
    mijn = ++hopNr;
    C.wereld.stappen(g.id, [{ x: xOpRij(S.doel, m.zTop) + 1, z: m.zTop }], {
      pose: 'spring', tempo: 1.1, perStap: function () { C.snd.hup(); }
    }).then(function (ok) {
      if (!C || !S || mijn !== hopNr) return;
      if (ok) C.wereld.pose(g.id, 'blij', 60);
      C.snd.hoera();
      C.ui.wolk(g.id, { id: 'hk_goed', kamer: 'tuin', icoon: '⭐', tekst: 'op de trap',
                        klas: 'goed', hoog: 52, prio: 12 });
      C.wereld.getalTag(g.id, S.doel, { id: 'hk_gast', y: 30, prio: 10,
                                        titel: 'op ' + S.doel });
    });
  }
  straks(4600, function () {
    if (C && S && S.fase === 'af') { C.data().stand = null; C.sluit(); }
  });
}

/* =====================================================================
   AANMELDEN
===================================================================== */
/* registry.js hangt de spelknop aan een VAST voorwerp; onze stenen zijn los
   decor dat pas in start() bestaat. Het hok is het vaste voorwerp waar de
   hinkelstrook vlak vóór ligt, dus we schuiven de knop met dx/dz precies op
   de eerste steen. */
/* is er een gast die 🧶 wil spelen? (voor de voorrang van het taakje; dit
   loopt buiten start() om, dus het leest State en niet de ctx) */
function hinkelGast() {
  var l = (window.State && State.gasten && State.gasten()) || [];
  for (var i = 0; i < l.length; i++)
    if (l[i].bed && l[i].behoefte === 'spelen' && !l[i].blij) return l[i];
  return null;
}
function knopPlek() {
  var m = padMaat(), h = { x: 67, z: 19 }, r = window.Rooms && Rooms.get('tuin'), i;
  if (r) for (i = 0; i < r.decor.length; i++) if (r.decor[i].n === 'hok') h = r.decor[i];
  return { dx: Math.round(m.eerste - h.x), dz: Math.round(m.zSteen - h.z) };
}
var KNOP = knopPlek();

Games.register({
  id: 'hinkel',
  naam: 'Hinkelpad',
  kamer: 'tuin',
  hotspot: { obj: 'hok', icoon: '🪨', label: 'Hinkelen', hoog: 6,
             dx: KNOP.dx, dz: KNOP.dz },
  wens: 'spelen',
  unlock: function (N) { return N >= 1; },
  stub: false,
  /* Het taakje op het prikbord. De voorrang hangt af van de gast: wil er
     iemand 🧶 spelen, dan hoort dit kaartje er bijna bovenaan (2, net achter
     de wensen van de dieren zelf); is het gewoon een spelletje voor wie er is,
     dan gaat het op de stapel van de andere spellen (5, de standaard van
     bedden/sleutels/meubels). hotel.js leest `t.prio` per hertekening, dus een
     leesfunctie werkt hier gewoon.
     WAAROM NIET ALTIJD 1 (zoals de tobbe): het bord houdt er maar drie, en een
     taakje dat NET is afgevinkt blijft de rest van de dag met zijn vinkje
     staan. Met een vaste prio 1 duwde dit chipje precies dat vinkje van het
     bord af - gemeten met loop.js: "een taakje dat een spel vervult verdwijnt
     niet maar krijgt een vinkje" viel om (155/2), met de voorrang hieronder is
     het weer 157/0. */
  taak: {
    icoon: '🪨',
    get prio() { return hinkelGast() ? 2 : 5; },
    wanneer: function (s) { return s.gasten.some(function (g) { return !!g.bed; }); },
    tekst: function (s) {
      var g = s.gasten.filter(function (q) { return q.behoefte === 'spelen' && !q.blij; })[0];
      return g ? g.naam + ' wil hinkelen' : 'Hinkel op de stenen';
    }
  },
  start: start,
  stop: stop,
  /* ---------- haakjes voor de speeltest (het hotel gebruikt ze niet) ---------- */
  proef: function (N, band, dag) { return beurt(N, band, dag); },
  xVan: function (n, band) { return xVan(n, band); },
  dierX: function (n, band) { return dierX(n, band); },
  xOpRij: function (n, z0, band) { return xOpRij(n, z0, band); },
  padMaat: function () { return padMaat(); },
  opStartSteen: function () { return opStartSteen(); },
  steenGetal: function (i, band) { return steenGetal(i, band); },
  maten: function () { return S ? maten() : []; },
  keuzes: function () { return S && S.fase === 'aantal'
    ? keuzeGetallen(aantalGoed(S.sprong), S.s + S.dag + S.pogingen) : []; },
  debug: function () { return S ? JSON.parse(JSON.stringify(S)) : null; },
  doe: function (wat, a) {
    if (!S) return null;
    if (wat === 'sprong') return kiesSprong(a);
    if (wat === 'aantal') return antwoord(a);
    if (wat === 'goed') return aantalGoed(S.sprong || maten()[0]);
    if (wat === 'nieuw') { var c = C; c.data().stand = null; S = null; start(c); return null; }
    return null;
  }
});
})();
