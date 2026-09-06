/* ---------------------------------------------------------------
   games/kraam.js - DE SOUVENIRKRAAM (geld, HOTEL.md 9).

   Alles gebeurt ÍN de tuin, in de gereserveerde zone langs de
   rechter zijrand (Rooms.get('tuin').zones.kraam):
     * de kraam zelf, de toonbank en de uitgestalde spullen zijn LOS
       DECOR van dit spel (Rooms.registerModel + ctx.wereld.decor), dus
       ze staan er alleen zolang je speelt en ze staan nooit in de
       hinkelzone van G3 ernaast;
     * op elk uitgestald spulletje staat zijn prijs als prijskaartje
       (ctx.wereld.getalTag: "€4"), roze bij wat de gast wil;
     * de gast met de wens 🎁 loopt naar de kraam (ctx.wereld.loopNaar)
       en gaat er vóór staan;
     * één sommenkaart bij de toonbank draagt de zin ("🎁 Boef wil het
       hoedje van €4") plus de som; het kleine cijferpad hangt eraan;
     * de buidel is één sleepbron (ctx.hotspots.bron met sleep) met de munt
       die je in je hand hebt erop, en de toonbank is het sleep-doel met de
       teller erop ("🧾 €2"). Slepen kán, tikken hoeft: tik de buidel
       om te wisselen (€1 → €2 → €5) en tik dan de toonbank, of sleep
       de munt er meteen op;
     * te veel gelegd: die munt schuift terug ("🪙 €1 terug"), te
       weinig: "🪙 +€2 erbij". Nooit rood, nooit een klok;
     * gelukt: "✅ Veel plezier ermee!", het gekochte komt ZICHTBAAR op
       het dier (ctx.wereld.accessoire) en blijft daar tot uitchecken,
       de wens 🎁 is af (behoefteKlaar) en er valt één ster.

   HET REKENEN (IDEAS.md-curriculum, HOTEL.md 3 en 4: hele euro's,
   nooit meer dan €20 per betaling, geen centen)

     groep 3   één spulletje van €2..€5; precies betalen met €1 en €2
               voorbeeld  hoedje €4  ->  leg €2 + €2  (of 2+1+1)
     groep 4   twee spullen; eerst de som "€4 + €5 =" op het cijferpad,
               daarna precies €9 neerleggen met €1 en €2
     groep 5   twee spullen (kosten €7..€15), de gast betaalt met €10 of
               €20: "€10 − €7 =" op het pad, daarna €3 wisselgeld uit de
               la met €1, €2 en €5

   De prijzen komen uit N, de band en de dag - dezelfde vaste afleiding
   die state.js voor zijn eigen sommen gebruikt (HOTEL.md 3). Er staat
   nooit twee keer dezelfde prijs op de kraam, er komt nooit een bedrag
   boven €20 en het wisselgeld is nooit €0 of negatief: keuring() rekent
   dat na en de suite toetst het over alle banden, dagen en N.

   WAT DE API (NOG) NIET HEEFT - hier binnen opgelost:
   * Er is geen algemene `Econ.betaal(prijs, onKlaar)` (GAMES-API.md 7
     noemt die bewust uitgesteld). Het muntensleep-mechanisme is daarom
     NIET gekopieerd maar hergebruikt via de API: `ctx.hotspots.bron`
     met zijn `sleep`-blok (dat is precies dezelfde makeDraggable die de
     rekening gebruikt) en `ctx.econ.munt(v)` voor het sleepplaatje.
   * `ctx.wereld.accessoire` kent alleen `hoedje`, `sjaaltje` en `bal`
     (api-p1e.md). De 🎒 tas van band 5 is er daarom een uitgestald
     tweede prijskaartje: hij hangt met €12 op de kraam, maar de gast
     koopt altijd iets dat hij ook kan DRAGEN, zodat het gekochte na het
     afrekenen echt op het dier te zien is.
   * `registry.js` zoekt de plek van een `hotspot.obj` alleen bij losse
     dingen, slots en het VASTE decor van de kamer - niet bij los decor.
     De toonbank bestaat pas als het spel loopt, dus het 🎁-knopje hangt
     aan het dichtstbijzijnde vaste tuinstuk (`bal` op 120, 76) met een
     `dx`/`dz` die het precies op de toonbank in de kraamzone zet.
---------------------------------------------------------------- */
(function () {
'use strict';

/* =====================================================================
   0. DE SPULLEN, DE MUNTEN EN DE KLEUREN
===================================================================== */
/* lid = het lidwoord (het hoedje, de bal), acc = de naam die
   ctx.wereld.accessoire kent (null = niet te dragen), basis = de prijs
   uit de spec waar de bandschuif bij op komt */
var WAREN = [
  { id: 'hoedje',   ico: '🎩', naam: 'hoedje',   lid: 'het', acc: 'hoedje',   basis: 4,  model: 'kr_hoedje' },
  { id: 'sjaaltje', ico: '🧣', naam: 'sjaaltje', lid: 'het', acc: 'sjaaltje', basis: 3,  model: 'kr_sjaaltje' },
  { id: 'bal',      ico: '⚽', naam: 'bal',      lid: 'de',  acc: 'bal',      basis: 5,  model: 'kr_bal' },
  { id: 'tas',      ico: '🎒', naam: 'tas',      lid: 'de',  acc: null,       basis: 12, model: 'kr_tas' }
];
/* welke munten liggen er klaar? groep 3 en 4 betalen met €1 en €2,
   groep 5 geeft wisselgeld en heeft daar ook €5 voor nodig */
var MUNTEN = { 3: [1, 2], 4: [1, 2], 5: [1, 2, 5] };
var PLAFOND = 20;                 /* HOTEL.md 4: nooit meer dan €20 */

var HOUT = '#D0A87A', HOUT_D = '#B98F62', HOUT_L = '#E2C094';
var DOEK_A = '#F5A8BE', DOEK_B = '#FFFDF6';     /* gestreepte luifel */
var MINT = '#6BC5A4', ORANJE = '#F6A957', ROZE = '#F5A8BE', WIT = '#FFFDF6';
var LEER = '#B4744A', LEER_D = '#8E5B3A';

/* =====================================================================
   1. DE VOXELMODELLEN (Rooms.registerModel, api-p1b.md)
   Anker (0,0,0) ligt op de vloer, midden onder het stuk; y is omhoog.
   Alles blijft binnen 21 voxels in x en 11 in z, zodat elk stuk met zijn
   anker midden in de kraamzone (22 x 32) helemaal binnen die zone valt.
===================================================================== */
/* De kraam: achterschot met twee staanders en een gestreepte luifel.
   Hij staat langs de ACHTERRAND van de zone (kleine x + z), dus achter de
   toonbank: zo dekt hij noch de toonbank noch de gast af. */
Rooms.registerModel('kr_kraam', function () {
  var K = Art.kit, v = [], i;
  K.bx(v, -10, 0, 0, 21, 24, 2, HOUT);            /* achterschot */
  K.verf(v, -10, 10, 10, 11, 0, 1, HOUT_D);       /* een plankenlijn */
  K.bx(v, -10, 0, -2, 2, 27, 2, HOUT_D);          /* staander links */
  K.bx(v, 9, 0, -2, 2, 27, 2, HOUT_D);            /* staander rechts */
  for (i = 0; i < 6; i++)                          /* luifel, schuin naar voren */
    K.bx(v, -10, 27 - Math.floor(i / 2), 1 - i, 21, 2, 1, (i % 2) ? DOEK_A : DOEK_B);
  return v;
});
/* De toonbank: een vierkante markttafel. Vierkant, want de spullen moeten
   op het SCHERM naast elkaar staan, en dat is in isometrie de lijn
   x + z = vast - die loopt dwars over een vierkant blad. */
Rooms.registerModel('kr_bank', function () {
  var K = Art.kit, v = [];
  K.bx(v, -10, 0, -7, 21, 11, 15, HOUT);          /* het blok */
  K.verf(v, -10, 10, 4, 5, -7, 7, HOUT_D);        /* een groef */
  K.bx(v, -11, 11, -8, 23, 2, 17, HOUT_L);        /* het blad */
  return v;
});
/* De uitgestalde spullen zijn met opzet FLINK: op de tuinschaal is één
   voxel maar 2 css-px, dus een hoedje van 6 voxels hoog verdwijnt naast zijn
   prijskaartje van 23 px. Deze zijn 10-12 voxels hoog (20-24 px). */
Rooms.registerModel('kr_hoedje', function () {
  var K = Art.kit, v = [];
  K.ell(v, 0, 1, 0, 4.6, 1.8, 4.6, MINT, { ymin: 0 });     /* brede rand */
  K.ell(v, 0, 6, 0, 3, 4.6, 3, MINT, { ymin: 2 });         /* hoge bol */
  K.verf(v, -4, 4, 2, 2, -4, 4, WIT);                      /* lintje */
  return v;
});
Rooms.registerModel('kr_sjaaltje', function () {
  var K = Art.kit, v = [];
  K.bx(v, -4, 0, -3, 9, 4, 7, ORANJE);            /* opgevouwen stapel */
  K.bx(v, -3, 4, -2, 7, 4, 5, ORANJE);
  K.bx(v, -2, 8, -1, 5, 2, 3, ORANJE);
  K.verf(v, -4, -4, 0, 9, -3, 3, WIT);            /* franje aan de zijkant */
  return v;
});
Rooms.registerModel('kr_bal', function () {
  var K = Art.kit, v = [];
  K.ell(v, 0, 4.4, 0, 4.4, 4.4, 4.4, ROZE, { e: 2.0 });
  K.verf(v, -1, 1, 0, 9, -5, 5, WIT);             /* witte evenaar */
  return v;
});
Rooms.registerModel('kr_tas', function () {
  var K = Art.kit, v = [];
  K.bx(v, -4, 0, -3, 9, 8, 6, LEER);
  K.bx(v, -4, 8, -3, 9, 2, 6, LEER_D);            /* de flap */
  K.bx(v, -1, 10, -1, 3, 3, 1, LEER_D);           /* het hengsel */
  return v;
});

/* =====================================================================
   2. WAAR STAAT ALLES? (voxels, afgeleid van de zone)
   Alle stukken komen uit Rooms.get('tuin').zones.kraam, dus als die
   rechthoek ooit verschuift schuift de kraam mee - en niets van dit
   spel komt ooit in de hinkelzone van G3 (x 24..100) terecht.

   Isometrie (GAMES-API.md 4): horizontaal ~ (x - z), verticaal
   ~ (x + z - 2y), en een GROTERE (x + z) staat dichter bij de kijker.
   Daarom staat de kraam ACHTER de toonbank (kleinere z) en de gast
   ervóór (grotere z): zo dekt de kraam de gast nooit af.
===================================================================== */
function zone() {
  var t = window.Rooms ? Rooms.get('tuin') : null;
  var z = t && t.zones ? t.zones.kraam : null;
  return z ? z : { x0: 104, x1: 126, z0: 36, z1: 68 };
}
function plekken(n) {
  var z = zone(), i, waren = [], f;
  var xm = Math.round((z.x0 + z.x1) / 2);         /* 115 */
  var kraamZ = z.z0 + 4;                          /* 40: schot z 36..42 */
  var bankZ = z.z1 - 12;                          /* 56: blad z 48..64 */
  /* De spullen moeten op het SCHERM naast elkaar staan. Horizontaal is in
     isometrie de richting (x - z), dus liggen ze op één diepte-lijn
     x + z = bankD: van (xm - 8, bankZ + 8) naar (xm + 8, bankZ - 8). Dat
     is de breedste lijn die helemaal op het blad past (16 voxels in x, dus
     32 in (x - z) = 64 css-px in portret).
     De prijskaartjes hangen om en om 16 voxels hoger. Dat moet: alle
     spullen staan op dezelfde diepte, dus zonder dat hoogteverschil zouden
     de kaartjes elkaar raken (band 5 heeft er vier, op 320 x 640 maar 16 px
     uit elkaar, en een kaartje is 33-42 px breed en 23 px hoog). 16 voxels
     is daar 26 px, dus ze staan altijd los. */
  var bankD = xm + bankZ;                         /* 171 */
  for (i = 0; i < n; i++) {
    f = n === 1 ? 0.5 : i / (n - 1);
    var wx = Math.round((xm - 8) + 16 * f);
    /* De kaartjes hangen om en om 26 en 2 voxels boven het blad: de een
       zweeft net BOVEN zijn spulletje, de ander ligt ervóór op het blad.
       Op 18 voxels lag het kaartje precies op het hoedje (gemeten: allebei
       py 220-232, dus het spulletje was onvindbaar - G5-F1 punt 4). */
    waren.push({ x: wx, z: bankD - wx, tagY: (i % 2) ? 26 : 2 });
  }
  return {
    zone: z, xm: xm, bankD: bankD,
    kraam: { x: xm, z: kraamZ },
    bank: { x: xm, z: bankZ },
    waren: waren,
    /* het geld komt vooraan op het blad: grotere x + z dan de spullen, dus
       het ligt er op het scherm vóór (en het vangvlak van het sleep-doel
       dekt het hele blad, api-h1 3b) */
    geld: { x: xm, z: z.z1 - 4 },
    /* De gast staat vóór de kraam: dichter bij de kijker dan de tafel
       (grotere x + z, dus lager op het scherm) en links van de bal op
       (120, 76). Hij staat 26 voxels vóór de voorrand van de zone, want
       op 320 x 640 raakte de sommenkaart hem nog bij +10 (gemeten: kaart
       tot 133 px, gast vanaf 125 px). */
    gast: { x: z.x0 - 4, z: z.z1 + 26 },
    /* de buidel en het klaar-knopje op het gras (zie opGras). De buidel
       staat 70 px links van de gast: een knop is 84 px breed en een dier
       54 px, dus er moet ~69 px tussen hun middens zitten. Gemeten stond
       hij op -40 px nog 17 px over zijn schouder (liggend, 860 x 420). */
    buidel: opGras(-70),
    klaar: opGras(-160)
  };
}
/* ---------- het plankje op het gras vóór de kraam ----------
   Gemeten in portret (420 x 860, tuin): de hele kraamzone is op het scherm
   maar ~108 px breed en 54 px hoog, en één knop is al 84 x 48 px. Twee
   knoppen naast elkaar passen daar dus niet: de hotspot-laag zou ze de
   halve tuin in schuiven (gemeten: de buidel belandde op x = 90). Daarom
   staan de buidel en het klaar-knopje - net als het gereedschap bij de
   tobbe - op een vast plankje op het gras vóór de kraam, uitgerekend in
   SCHERMpixels zodat het staand én liggend klopt. Dat gras ligt met
   z >= 100 ook ruim buiten de hinkelzone van G3 (z 34..50). */
function opGras(uPx, dPx) {
  var s = sch(), z = zone(), d = z.x1 + z.z1 - 22;      /* 172: vlak vóór de kraam */
  d += Math.round((dPx || 0) / (s.pxPerVoxelY || 1));
  var ver = Math.round(uPx / (s.pxPerVoxelX || 2));
  return { x: Math.round((d + ver) / 2), z: Math.round((d - ver) / 2) };
}

/* =====================================================================
   3. HET REKENEN - prijzen, aankoop en betaling uit N, band en dag
===================================================================== */
function euro(n) { return '€' + n; }
/* samen doortellen: "5 … 6 … 7 … 8 … 9." - het eindigt dus ECHT op de som.
   Ui.telMee telt met stappen van de prijs ("5 … 10.") en dat is bij €5 + €4
   het verkeerde antwoord (G5-F1). */
function telVanaf(start, erbij) {
  var l = [String(start)], i;
  for (i = 1; i <= erbij; i++) l.push(String(start + i));
  return l.join(' … ') + '.';
}
function tel(lijst) { var s = 0, i; for (i = 0; i < lijst.length; i++) s += lijst[i]; return s; }
/* De munten waarmee de VOORDOEN-rij (spookmunten) een bedrag laat zien.
   Met €5, €2 en €1 is elk bedrag t/m €13 in hooguit vier munten te leggen,
   en vier is precies wat er naast elkaar past. Met alleen €1 en €2 zou €9
   vijf munten kosten en werd er €8 voorgedaan waar €9 hoort (G5-F1). */
var SPOOK_MUNT = [5, 2, 1];
var SPOOK_MAX = 4;
/* een bedrag in de munten die er ÉCHT liggen (Econ.splits kent ook een
   biljet van 10, en dat ligt hier niet in de la) */
function splitsMet(bedrag, munten) {
  var uit = [], r = Math.max(0, bedrag | 0), i, m = munten.slice().sort(function (a, b) { return b - a; });
  for (i = 0; i < m.length; i++) while (r >= m[i]) { uit.push(m[i]); r -= m[i]; }
  return uit;
}

/* De bandschuif: één getal uit N en de dag, precies zoals tobbe.js zijn
   soort kiest. Groep 3 gaat ermee omlaag (liefst t/m 10, HOTEL.md 3),
   groep 4 een stapje omhoog, groep 5 tot drie stapjes. */
function schuifVan(N, band, dag) {
  N = Math.max(1, N | 0);
  dag = Math.max(1, dag | 0);
  var v = (N + dag) % (band >= 5 ? 4 : 2);
  /* de prijzen ROTEREN ook over de drie spullen: zo is het hoedje niet elke
     keer het duurste en zijn er per band 3 x (2 of 4) x 3 = 18 tot 36
     verschillende beurten in plaats van 6 */
  return { v: v, schuif: band <= 3 ? -v : v, rot: (N + 2 * dag) % 3 };
}
function opzet(N, band, dag) {
  N = Math.max(1, N | 0);
  dag = Math.max(1, dag | 0);
  band = band <= 3 ? 3 : band >= 5 ? 5 : 4;
  var s = schuifVan(N, band, dag);
  /* de drie basisprijzen uit de spec (4, 3, 5), doorgeschoven met rot */
  var basis = WAREN.slice(0, 3).map(function (w) { return w.basis; });
  var waren = WAREN.slice(0, band >= 5 ? 4 : 3).map(function (w, i) {
    return { id: w.id, ico: w.ico, naam: w.naam, lid: w.lid, acc: w.acc, model: w.model,
             prijs: w.id === 'tas' ? 12 : basis[(i + s.rot) % 3] + s.schuif };
  });
  var draag = waren.filter(function (w) { return !!w.acc; });
  var i0 = (N + dag) % draag.length, keus;
  if (band <= 3) keus = [draag[i0]];
  else keus = [draag[i0], draag[(i0 + 1) % draag.length]];
  var kosten = tel(keus.map(function (w) { return w.prijs; }));
  /* groep 5 betaalt met een biljet en krijgt terug; de andere banden
     leggen het bedrag zelf neer */
  var betaald = band >= 5 ? (kosten <= 9 ? 10 : 20) : kosten;
  var wissel = betaald - kosten;
  return { band: band, N: N, dag: dag, waren: waren,
           keus: keus.map(function (w) { return w.id; }),
           kosten: kosten, betaald: betaald, wissel: wissel,
           /* hoeveel euro moet het kind neerleggen? */
           doel: band >= 5 ? wissel : kosten,
           /* het cijferpad: groep 4 telt de spullen op, groep 5 rekent terug */
           vraag: band === 4
             ? { som: euro(keus[0].prijs) + ' + ' + euro(keus[1].prijs) + ' =', goed: kosten }
             : band >= 5
               ? { som: euro(betaald) + ' − ' + euro(kosten) + ' =', goed: wissel }
               : null,
           munten: MUNTEN[band] };
}
/* Rekent de eigen generator na: dit is wat de suite over alle banden,
   dagen en N heen toetst (HOTEL.md 3 en 4). Geeft een lijst klachten;
   leeg = goed. */
function keuring(o) {
  var fout = [], i, p = o.waren.map(function (w) { return w.prijs; });
  if (o.kosten > PLAFOND) fout.push('kosten boven €20');
  if (o.betaald > PLAFOND) fout.push('betaling boven €20');
  for (i = 0; i < p.length; i++) {
    if (p[i] !== Math.round(p[i]) || p[i] < 1) fout.push('prijs geen hele euro: ' + p[i]);
    if (p.indexOf(p[i]) !== i) fout.push('twee keer dezelfde prijs: ' + p[i]);
    if (o.band <= 3 && p[i] > 10) fout.push('groep 3 boven 10: ' + p[i]);
    if (p[i] > PLAFOND) fout.push('prijs boven €20: ' + p[i]);
  }
  if (!(o.doel >= 1)) fout.push('niets te leggen');
  if (o.wissel < 0) fout.push('negatief wisselgeld');
  if (o.band >= 5 && o.wissel < 1) fout.push('groep 5 zonder wisselgeld');
  if (!o.keus.length) fout.push('geen aankoop');
  for (i = 0; i < o.keus.length; i++) {
    if (o.keus.indexOf(o.keus[i]) !== i) fout.push('twee keer hetzelfde spulletje');
    var w = o.waren.filter(function (q) { return q.id === o.keus[i]; })[0];
    if (!w || !w.acc) fout.push('gekocht spul is niet te dragen: ' + o.keus[i]);
  }
  if (o.vraag && !(o.vraag.goed >= 0)) fout.push('negatieve som');
  /* de voordoen-rij moet ALTIJD precies het bedrag laten zien */
  [o.doel, o.vraag ? o.vraag.goed : 0].forEach(function (bedrag) {
    if (!bedrag) return;
    var sp = splitsMet(bedrag, SPOOK_MUNT);
    if (tel(sp) !== bedrag) fout.push('spookmunten kloppen niet: ' + bedrag);
    if (sp.length > SPOOK_MAX) fout.push('te veel spookmunten voor ' + bedrag + ': ' + sp.length);
  });
  if (o.band <= 3 && o.vraag) fout.push('groep 3 hoort geen som te krijgen');
  if (o.band >= 4 && !o.vraag) fout.push('groep ' + o.band + ' hoort een som te krijgen');
  /* is het doelbedrag te leggen met de munten die er liggen? */
  if (tel(splitsMet(o.doel, o.munten)) !== o.doel) fout.push('doel niet te leggen met deze munten');
  return fout;
}

/* =====================================================================
   4. DE SPELSTAND
===================================================================== */
var C = null;              /* de ctx */
var S = null;              /* de stand, leeft in C.data() en wordt bewaard */
var P = null;              /* de plekken in de tuin */
var O = null;              /* de opzet van deze beurt (prijzen, aankoop) */
var kaart = null;          /* de sommenkaart */
var kaartLift = 0;         /* hoogtecorrectie van de kaart (kaartPast) */
var kaartRonde = 0, kaartT = null;
var kaartPad = '';         /* de padPlek waarmee de kaart nu getekend is */
var kaderAf = null;        /* opzegger van ctx.ui.opKader (api-m1a.md 2) */
var kaderT = null;         /* wachtje na een kadermelding (opKaderMaat) */
var terugNr = 0;           /* teken van de munt die aan het terugschuiven is */
/* De munt die geweigerd wordt ligt ALLEEN op het beeld, nooit in de opslag:
   S.gelegd houdt altijd een geldige stand (<= doel). Anders bleef een
   herlaad (of weglopen) midden in die halve seconde met een volle toonbank
   zitten en zei elke tik "€1 terug" - de beurt liep vast (G5-F1 punt 1). */
var terugMunt = 0;
var klok = [];

function straks(ms, fn) { var t = setTimeout(fn, ms); klok.push(t); return t; }
function stopKlok() { klok.forEach(function (t) { clearTimeout(t); }); klok = []; }
function bewaar() { if (C) C.state.bewaar(); }
/* wat LIGT er op de toonbank (inclusief de munt die terugschuift)? */
function opBank() { return tel(S.gelegd) + terugMunt; }
/* Een opslag van een afgebroken beurt (of van een oudere versie van dit
   spel) kan meer op de toonbank hebben dan het bedrag. Dan halen we het
   teveel er gewoon af, zodat de beurt altijd verder kan. */
function herstelBank() {
  if (!S || !O || !S.gelegd) return 0;
  var n = 0;
  while (S.gelegd.length && tel(S.gelegd) > O.doel) { S.gelegd.pop(); n++; }
  if (n) bewaar();
  return n;
}
function sch() {
  var s = C && C.wereld.schaal ? C.wereld.schaal() : null;
  if (!s || !s.pxPerHoogte) return { pxPerVoxelX: 2, pxPerVoxelY: 1, pxPerHoogte: 2, k: 1 };
  return s;
}
function waarVan(id) {
  var i;
  if (!O) return null;
  for (i = 0; i < O.waren.length; i++) if (O.waren[i].id === id) return O.waren[i];
  return null;
}
function gekocht() { return O.keus.map(waarVan).filter(Boolean); }
function gast() { return S && C ? C.state.gast(S.gast) : null; }

/* wie wil er een souvenir? Niemand met de wens 🎁? Dan mag iedereen
   (dezelfde vriendelijke terugval als de tobbe). */
function kandidaten() {
  var met = C.state.gasten().filter(function (g) {
    return g.behoefte === 'souvenir' && !g.blij && !!g.bed;
  });
  if (met.length) return met;
  return C.state.gasten().filter(function (g) { return !!g.bed; });
}

function nieuweStand(g, N, band, dag) {
  var b = band <= 3 ? 3 : band >= 5 ? 5 : 4;
  return { gast: g.id, dag: dag, N: N, band: band,
           stap: b >= 4 ? 'som' : 'leg',
           gelegd: [], hand: MUNTEN[b][0],
           somPog: 0, legPog: 0, missers: 0, spook: 0, hulp: '',
           wens: g.behoefte === 'souvenir' ? 1 : 0,
           ster: 0, acc: 0, zeg: null, t0: 0 };
}

/* =====================================================================
   5. START / STOP
===================================================================== */
function meldLeeg(tekst) {
  var z = zone();
  C.ui.wolk({ x: z.x0, z: z.z1, kamer: 'tuin' },
            { id: 'kr_leeg', icoon: '🎁', tekst: tekst, hoog: 24 });
  straks(1800, function () { if (C) { C.ui.wolkWeg('kr_leeg'); C.sluit(); } });
}

function start(ctx) {
  C = ctx;
  var kies = kandidaten();
  if (!kies.length) { meldLeeg('nog geen gasten'); return; }
  var d = C.data(), N = C.state.N(), band = C.state.band(), dag = C.state.dag();
  S = d.stand;
  var g = S ? C.state.gast(S.gast) : null;
  if (!S || !g || S.dag !== dag || S.N !== N || S.band !== band || S.stap === 'af') {
    g = kies[0];
    S = nieuweStand(g, N, band, dag);
    d.stand = S;
  }
  O = opzet(N, band, dag);
  P = plekken(O.waren.length);
  S.t0 = C.ui.nu();
  terugMunt = 0;
  herstelBank();                    /* nooit met een te volle toonbank starten */
  if (O.munten.indexOf(S.hand) < 0) S.hand = O.munten[0];
  kaartLift = 0; kaartRonde = 0; kaartT = null; kaartPad = ''; kaderT = null; terugNr = 0;
  gastGestuurd = 0; gastGelopen = 0; gastKeer = 0;
  /* Het kader kan van maat veranderen: draaien, maar ook onze eigen
     cijferstrook (die staat ín de pagina onder het kader, dus het kader
     krimpt zodra hij verschijnt - api-m1a.md 1). Dan klopt de hoogte van de
     kaart niet meer, en dat mag niet blijven staan: de kaart mag nooit over
     de gast liggen (HOTEL.md 9).
     VÓÓR de eerste teken(): de strook vraagt zelf meteen een hermeting aan
     (ui.js schilVeranderd -> World.hermeet), en die slaat de opmaat-bus nog
     tijdens diezelfde teken(). Gemeten op 860 x 420: de bus sloeg 7 ms na
     Games.start, dus een luisteraar die pas ná teken() wordt aangemeld hoort
     precies de melding niet waar het om gaat. */
  if (!kaderAf && C.ui.opKader) kaderAf = C.ui.opKader(opKaderMaat);
  C.wereld.naar('tuin');
  zetDecor();
  haalGast();
  teken();
  /* de gast kan nog uit een andere kamer onderweg zijn: dan staat hij pas
     later op zijn plek en moet de kaart nog een keer nagemeten worden */
  straks(1500, function () { if (C && S) { kaartRonde = 0; kaartNakijken(); } });
  straks(3200, function () { if (C && S) { kaartRonde = 0; kaartNakijken(); } });
}
/* Eén kadermelding: opnieuw nameten, en dat TWEE keer.
   Meteen, want de kamer staat in een nieuwe maat. En nog een keer voorbij de
   400 ms die de mobiele schil zichzelf gunt (VERSTIL_MS, api-m1a.md 1): bij
   een kadermelding zet de schil de kaart namelijk zelf terug op de hoogte
   waarmee hij gemaakt is (ui.js padOpnieuw: "hoog = hoogBasis"), en daar ging
   onze correctie onderdoor. Gemeten op 860 x 420: kaart om 251 ms netjes op
   84..192, om 495 ms door de schil terug op 128..236 met de gast op 229..312
   - 7 px eroverheen, tot de losse lus van 1500 ms hem alsnog optilde.
   Hier NIET opnieuw teken(): een hertekening haalt de oude kaart weg
   (hotspots.wisAlles -> onWeg -> de strook gaat even uit) en zet daarna een
   nieuwe neer (de strook weer aan). Dat zijn twee kaderveranderingen, dus
   twee meldingen, dus een lus - nagemeten: 86 busslagen in 2,6 s. Nameten
   verandert alleen de hoogte van één hotspot en meldt dus niets terug. */
function opKaderMaat() {
  if (!C || !S || !O) return;
  kaartRonde = 0;
  kaartNakijken();
  if (kaderT) return;
  kaderT = straks(560, function () {
    kaderT = null;
    if (!C || !S || !O) return;
    kaartRonde = 0;
    kaartNakijken();
  });
}

function stop() {
  stopKlok();
  if (kaderAf) { try { kaderAf(); } catch (e) { } kaderAf = null; }
  if (C) {
    C.hotspots.wisAlles();
    C.hotspots.laat();
    /* niet strikt nodig (world.js ruimt het decor van een spel zelf op),
       maar het kan geen kwaad en dan hangt het niet aan één aanname -
       zie api-p1b.md "TOCH OOK ZELF OPRUIMEN" */
    C.wereld.decorWisAlles();
  }
  C = null; S = null; P = null; O = null; kaart = null;
  kaartLift = 0; kaartRonde = 0; kaartT = null; kaartPad = ''; kaderT = null; terugNr = 0; terugMunt = 0;
  gastGestuurd = 0; gastGelopen = 0; gastKeer = 0;
}

/* de ster hoort bij de hele beurt en valt hooguit één keer */
function ster() {
  if (!S || S.ster) return false;
  S.ster = 1;
  C.taakKlaar('souvenir', { sterren: 1 });
  return true;
}

/* =====================================================================
   6. DE WERELD: kraam, toonbank en de spullen erop
===================================================================== */
function zetDecor() {
  C.wereld.decor('tuin', { id: 'kr_kraam', model: 'kr_kraam', x: P.kraam.x, z: P.kraam.z });
  C.wereld.decor('tuin', { id: 'kr_toonbank', model: 'kr_bank', x: P.bank.x, z: P.bank.z });
  O.waren.forEach(function (w, i) {
    C.wereld.decor('tuin', { id: 'kr_w' + i, model: w.model,
                             x: P.waren[i].x, z: P.waren[i].z, hoog: 13 });
  });
  C.wereld.vuil();
}

/* ---------- de gast loopt naar zijn plekje vóór de toonbank ----------
   Staat hij in een andere kamer, dan reist hij eerst door de deuren
   (World.reis); dat duurt een paar seconden en we sturen hem ONDERWEG niet
   nog eens, want dan begint zijn route opnieuw. Zodra hij in de tuin is
   loopt hij het laatste stukje met ctx.wereld.loopNaar, en op zijn
   aankomst meten we de sommenkaart opnieuw na: pas dan weten we waar hij
   staat, en de kaart mag nooit over hem heen liggen (HOTEL.md 9). */
var gastGestuurd = 0, gastGelopen = 0, gastKeer = 0;
function haalGast() {
  var g = gast();
  if (!g) return;
  var d = C.wereld.dier(g.id);
  if (!d) return;
  if (d.kamer !== 'tuin') {
    if (!gastGestuurd) {
      gastGestuurd = 1;
      C.wereld.reis(g.id, 'tuin', { x: P.gast.x, z: P.gast.z, na: 'wacht' });
      g.waar = 'tuin';
    }
    if (gastKeer++ < 24) straks(700, function () { if (C && S) haalGast(); });
    return;
  }
  if (gastGelopen) return;
  gastGelopen = 1;
  g.waar = 'tuin';
  if (C.wereld.loopNaar) {
    C.wereld.loopNaar(g.id, P.gast.x, P.gast.z, { na: 'wacht' }).then(function (ok) {
      if (ok && C && S) { kaartRonde = 0; kaartNakijken(); }
    });
  } else C.wereld.ga(g.id, P.gast.x, P.gast.z, 'wacht');
}

/* =====================================================================
   7. TEKENEN - alles hangt aan een voorwerp in de kraam
===================================================================== */
function zeg(o) { if (S) S.zeg = o || null; }

/* ---------- past er één zin of passen er twee? ----------
   Een kaartje met twee zinnen is op een smal kader 129 px hoog (gemeten op
   320 x 640: kader 286 x 304, elke zin breekt daar af naar twee regels).
   Samen met de gast (83 px) en de knoppen past dat niet meer in 304 px: de
   kaart kwam dan over de gast heen (HOTEL.md 9). In zo'n kort of smal kader
   houden we daarom de EERSTE zin - die noemt het spulletje en de prijs - en
   laat de somregel eronder de vraag doen ("€5 + €4 ="). Zelfde grenzen als
   de cijferstrook van de mobiele schil (api-m1a.md: 340 px hoog, 360 breed). */
function kortKader() {
  var w = document.getElementById('world');
  if (!w || !w.clientHeight) return false;
  return w.clientHeight < 340 || w.clientWidth < 360;
}
/* De zin boven de som: één gewone Nederlandse zin, hooguit 8 woorden en
   40 tekens (HOTEL.md 9). De tweede regel is de vraag of de opdracht. */
function zin() {
  var l = zinnen();
  return kortKader() ? l.slice(0, 1) : l;
}
function zinnen() {
  var g = gast(), naam = g ? g.naam : 'De gast', k = gekocht();
  if (S.stap === 'af') return ['Veel plezier ermee!'];
  if (O.band <= 3)
    return [naam + ' wil ' + k[0].lid + ' ' + k[0].naam + ' van ' + euro(k[0].prijs),
            'Leg de munten op de toonbank'];
  if (O.band === 4) {
    if (S.stap === 'som')
      return [C.ui.hoofd(k[0].naam) + ' ' + euro(k[0].prijs) + ' en ' + k[1].naam + ' ' + euro(k[1].prijs),
              'Hoeveel euro samen?'];
    return ['Samen kost het ' + euro(O.kosten), 'Leg de munten op de toonbank'];
  }
  if (S.stap === 'som')
    return [naam + ' gaf ' + euro(O.betaald) + ', het kost ' + euro(O.kosten),
            'Hoeveel krijgt hij terug?'];
  return [naam + ' krijgt ' + euro(O.wissel) + ' terug', 'Leg het wisselgeld neer'];
}
/* De somregel: bij de vraag de som zelf, bij het betalen het bedrag dat op
   de toonbank moet komen. Het antwoordvakje ernaast vult de kaart zelf met
   wat er NU ligt (zoals tobbe.js zijn tobbes optelt), zodat er nooit een
   leeg vakje staat waar je niets mee kunt (G5-F1 punt 4). */
function somLijn() {
  if (S.stap === 'som') return O.vraag.som;
  return euro(O.doel);
}
function kaartIco() {
  if (S.stap === 'af') return '✅';
  if (O.band >= 5) return '👛';
  return '🎁';
}

/* ---------- waar hoort het cijferpad? (G5-F2) ----------
   Het pad van groep 4 en 5 hangt onderaan de sommenkaart en is in een breed
   kader één rij van twaalf toetsen over bijna de hele kaderbreedte. Sinds
   M1b is het liggende kader ~310-340 px hoog, en dan valt die rij precies
   over de kraam: gemeten op 860 x 420 (kader 682 x 340) lag het pad op
   55..693 x 333..399, over de prijskaartjes kr_p0 en kr_p2 (320..344) en
   over de gast (269..367). Staand op 320 x 640 (kader 304 px) lag het pad
   op 349..451 en de gast op 285..357: 8 px eroverheen. Dat mag geen van
   beide (HOTEL.md 9).
   Boven de 360 px kaderhoogte is er wél ruimte onder de kraam - gemeten
   360 x 740 (kader 395): pad 399..509, gast tot 383; 420 x 860 (kader 468):
   pad 447..565, gast tot 429. Daarom: is het kader lager dan 360 px, dan
   vragen we het pad als STROOK onder het kader (api-m1a.md 1,
   padPlek 'buiten'). Daar botst het met niets, het houdt zijn toetsen van
   48 px en het draagt daar dezelfde data-hot="kr_som_pad". Is het kader
   hoger, dan laten we 'auto' staan: dan beslist de mobiele schil zelf (die
   kijkt ook naar een té smal kader).
   STROOKVRIJ meten, net als ui.js kaderHoogVrij: onze eigen strook staat ín
   de pagina onder het kader, dus zodra hij er is krimpt het kader. Meten we
   dat rauw, dan hangt de meting van onze eigen keuze af; met de hoogte van
   de strook erbij is de uitkomst dezelfde vóór en ná de wissel en kan het
   pad dus niet heen en weer springen. */
var KADER_PADRUIM = 360;
function kaderHoogVrij() {
  var w = document.getElementById('world');
  if (!w || !w.clientHeight) return 0;
  var h = w.clientHeight, s = document.getElementById('padstrip');
  if (s && !s.hidden && s.getAttribute('data-hot') === 'kr_som_pad' && s.offsetHeight)
    h += s.offsetHeight + 4;                  /* + de kier tussen kader en strook */
  return h;
}
function padPlek() {
  var h = kaderHoogVrij();
  return (h && h < KADER_PADRUIM) ? 'buiten' : 'auto';
}

/* De kaart hangt hoog boven de toonbank: hij mag nooit over de gast
   heen liggen (HOTEL.md 9) en ook niet over de spullen waar het kind op
   moet tikken. Eerst een schatting in schermpixels, daarna meten we het
   na (kaartPast) - net zoals de tobbe met zijn sommenkaart doet. */
function kaartHoog() {
  return Math.round(145 / sch().pxPerHoogte) + kaartLift;
}
function tekenKaart() {
  var open = S.stap === 'som';
  kaartPad = padPlek();
  kaart = C.ui.somkaart({ x: P.bank.x, z: P.bank.z, kamer: 'tuin' }, somLijn(), {
    id: 'kr_som', kamer: 'tuin', hoog: kaartHoog(), icoon: kaartIco(),
    regel: zin(), open: open, max: 2, pad: open, padPlek: kaartPad,
    klas: S.stap === 'af' ? 'af' : '',
    onOk: function (n, k) { antwoordSom(n, k); }
  });
  if (!kaart) return;
  if (S.hulp) kaart.hulp(S.hulp);
  if (S.stap === 'af') kaart.zet(euro(O.doel)).klaar();
  else if (S.stap === 'leg') kaart.zet(euro(opBank()));   /* wat er nu ligt */
  else if (S.somPog >= 3) spookNeer(O.vraag.goed, 'zoveel is het');
  kaartNakijken();
}

/* De prijskaartjes: bij elk uitgestald spulletje staat zijn prijs als
   cijfer ÓP het spulletje (ctx.wereld.getalTag - precies waar die functie
   voor is: "een cijfer op een voorwerp"). Ze hangen om en om iets hoger,
   dus ze overlappen elkaar nooit; ze wijken ook niet uit voor knoppen
   (hits.js zet cijfers vast), dus ze blijven bij hun eigen spulletje.
   Een prijskaartje is geen knop: het spulletje zelf hoeft niet getikt te
   worden, de gast zegt op de kaart al wat hij wil. */
function tekenWaren() {
  /* Alle uitgestalde spullen houden hun prijskaartje (spec G5: drie spullen
     MET prijskaartje). Alleen als de voordoen-rij eraan komt (derde poging)
     blijft het kaartje van het gekochte over: dan is de kamer rustig genoeg
     voor de spookmunten en blijft de tuin onder de 16 knoppen. */
  var alleen = S.spook ? O.keus : null;
  O.waren.forEach(function (w, i) {
    var p = P.waren[i];
    if (alleen && alleen.indexOf(w.id) < 0) return;
    C.wereld.getalTag({ x: p.x, z: p.z, kamer: 'tuin' }, euro(w.prijs),
                      { id: 'kr_p' + i, y: p.tagY, prio: 8,
                        /* 'veel' bestaat al in de opmaak: roze cijfer. Zo
                           valt op wat de gast wil, zonder nieuwe css */
                        klas: (O.keus.indexOf(w.id) >= 0 ? 'veel' : ''),
                        titel: w.lid + ' ' + w.naam + ' kost ' + w.prijs + ' euro' });
  });
}

/* de toonbank: sleep of tik de munten hierheen, het bedrag staat erop.
   Het vangvlak van de hotspot-laag legt zich over knop én blad, dus je
   kunt ook gewoon naar de tafel zelf slepen (api-h1 3b). */
function tekenBank() {
  var som = opBank();
  C.hotspots.maak({
    id: 'kr_geld', kamer: 'tuin', x: P.geld.x, z: P.geld.z, y: 13,
    icoon: '🧾', getal: euro(som),
    kind: 'drop', drop: 'kr_geld', klas: 'hotbron', prio: 11,
    /* ONDER het blad: boven het blad staan de prijskaartjes van de spullen
       (die wijken niet uit), en dan zou de laag deze knop een halve tuin
       naar links schuiven. Onder het blad staat hij vlak bij de toonbank en
       dekt zijn vangvlak precies het blad plus de knop (api-h1 3b). */
    op: 'onder',
    titel: 'op de toonbank ligt ' + euro(som) + ' van ' + euro(O.doel),
    aan: function () { legMunt(S.hand); }
  });
}

/* ---------- de buidel (groep 5: de la van de kraam) ----------
   ELKE munt heeft zijn eigen sleepbron: €1 en €2 in groep 3 en 4, en €1,
   €2 en €5 in groep 5. Ze staan naast elkaar op het gras vóór de kraam, 62
   css-px uit elkaar (een muntknop is ~56 px breed omdat er alleen "€2" in
   staat). Één knop met een wisselaar zou in groep 5 drie standen hebben, en
   dan is "welke munt heb ik in mijn hand" precies de fout die je bij het
   wisselgeld niet wil maken (G5-F1 punt 5).
   Tikken pakt de munt in je hand (tik-tik: dan de toonbank), slepen legt
   hem meteen op de toonbank. */
function tekenMunten() {
  O.munten.forEach(function (v, i) {
    var p = opGras(-60 - i * 62);
    C.hotspots.bron({ x: p.x, z: p.z, kamer: 'tuin' }, {
      id: 'kr_m' + v, hoog: 0, prio: 10 + (S.hand === v ? 1 : 0),
      icoon: euro(v), hand: S.hand === v ? '☝' : null,
      titel: 'munt van ' + v + ' euro' + (S.hand === v ? ', in je hand' : ''),
      tik: function () { pakMunt(v); },
      sleep: {
        dropSel: '[data-drop="kr_geld"]',
        ghostHTML: function () { return C.econ.munt(v); },
        canDrag: function () { return !!(S && S.stap === 'leg'); },
        onDrop: function () { legMunt(v); },
        onTap: function () { pakMunt(v); }
      }
    });
  });
}

function tekenKlaar() {
  C.hotspots.maak({
    id: 'kr_ok', kamer: 'tuin', x: P.klaar.x, z: P.klaar.z, y: 0,
    icoon: '✔', label: 'klaar', klas: 'hotwolk goed', prio: 9,
    titel: 'klaar met tellen', aan: function () { klaarMetTellen(); }
  });
}

/* Het souvenirtje NAAST de gast als de beurt af is. Een cijfertag en geen
   wolkje: een wolkje van 163 px werd door de hotspot-laag 115 px de tuin in
   geschoven (de sommenkaart hangt er pal boven), en dan staat het praatje
   niet meer bij zijn eigen dier. Een tag wijkt niet uit (hits.js zet cijfers
   vast), dus die blijft staan waar we hem zetten.
   Hij hangt links van het dier op borsthoogte en NIET op zijn kop: daar
   staat zijn naamplaatje (world.js zet dat 30 voxels boven de vloer) en dat
   dekte hij af (G5-F1 punt 4). De slotzin zelf staat op de kaart:
   "✅ Veel plezier ermee!". */
function tekenAf() {
  var g = gast();
  if (!g) return;
  C.wereld.getalTag({ x: P.gast.x - 11, z: P.gast.z + 11, kamer: 'tuin' }, '🎁',
                    { id: 'kr_af', y: 14, prio: 12,
                      titel: g.naam + ' heeft zijn souvenir' });
}

function tekenZeg() {
  if (!S.zeg) return;
  var z = S.zeg;
  C.ui.wolk({ x: P.bank.x, z: P.bank.z, kamer: 'tuin' },
            { id: 'kr_zeg', kamer: 'tuin', icoon: z.icoon,
              getal: z.getal === undefined ? null : z.getal, tekst: z.tekst,
              klas: z.klas || 'hulp',
              hoog: Math.round(66 / sch().pxPerHoogte), prio: 12 });
}

function teken() {
  if (!C || !S || !O) return;
  C.hotspots.wisAlles();
  tekenKaart();
  tekenWaren();
  if (S.stap === 'leg') { tekenBank(); tekenMunten(); tekenKlaar(); }
  if (S.stap === 'af') { tekenBank(); tekenAf(); }
  if (S.stap === 'leg' && S.spook) spookNeer(O.doel - tel(S.gelegd), 'dit moet er nog bij');
  tekenZeg();
  C.wereld.vuil();
}

/* ---------- de kaart mag niets afdekken (gemeten, niet gegokt) ----------
   De hotspot-laag klemt elke knop binnen het kader, dus een kaart die te
   hoog hangt wordt tegen de bovenrand geplakt en komt dan alsnog over de
   gast. We meten het na en tillen de kaart precies genoeg op of laten
   hem zakken; kaartLift onthoudt de correctie. */
function vak(sel) {
  var e = document.querySelector(sel);
  if (!e || !e.offsetHeight) return null;
  var r = e.getBoundingClientRect();
  return { l: r.left, t: r.top, r: r.right, b: r.bottom, w: r.width, h: r.height };
}
function raakt(a, b, marge) {
  if (!a || !b) return false;
  marge = marge || 0;
  return a.l < b.r + marge && a.r > b.l - marge && a.t < b.b + marge && a.b > b.t - marge;
}
/* Waar staat de gast op het scherm? Zijn naamplaatje staat met zijn
   onderrand op zijn kop (world.js naamplaatjes: 30 voxels boven de
   vloer), dus daaruit volgt zijn hele doosje. */
function gastVak() {
  var g = gast();
  if (!g) return null;
  var d = C.wereld.dier(g.id);
  if (!d || d.kamer !== 'tuin') return null;
  var lijst = document.querySelectorAll('#worldTags .wtag'), i, e, r, s = sch();
  for (i = 0; i < lijst.length; i++) {
    e = lijst[i];
    if (e.textContent !== g.naam || e.style.display === 'none' || !e.offsetHeight) continue;
    r = e.getBoundingClientRect();
    var vloer = r.bottom + 30 * s.pxPerHoogte;
    var mid = (r.left + r.right) / 2, hb = Math.max(24, 27 * s.pxPerVoxelX / 2);
    return { l: mid - hb, r: mid + hb, t: r.top, b: vloer, w: 2 * hb, h: vloer - r.top };
  }
  return null;
}
function kaartPast() {
  kaartT = null;
  if (!C || !S || kaartRonde > 7) return;
  var k = vak('[data-hot="kr_som"]');
  var h = document.getElementById('worldHits');
  if (!k || !h) return;
  var hb = h.getBoundingClientRect(), stap = 0;
  var per = Math.max(1, sch().pxPerHoogte);
  /* De harde regel gaat voor: de kaart mag NOOIT over de gast liggen
     (HOTEL.md 9). Pas als dat goed zit kijken we of hij nog wel netjes in
     het kader hangt. */
  var g = gastVak();
  if (g && raakt(k, g, 2)) stap = Math.ceil((k.b - (g.t - 6)) / per);
  else if (k.t < hb.top + 4) stap = -Math.ceil(((hb.top + 4) - k.t) / per);       /* omlaag */
  else if (k.b > hb.bottom - 4) stap = Math.ceil((k.b - (hb.bottom - 4)) / per);  /* omhoog */
  if (!stap) return;
  var nieuw = Math.max(-60, Math.min(80, kaartLift + stap));
  if (nieuw === kaartLift) return;
  kaartLift = nieuw;
  kaartRonde++;
  C.hotspots.maak({ id: 'kr_som', y: kaartHoog() });
  C.wereld.vuil();
  kaartNakijken();
}
function kaartNakijken() {
  if (kaartT) return;
  kaartT = straks(120, kaartPast);
}

/* ---------- spookmunten: pas bij de DERDE poging (HOTEL.md 9) ---------- */
function spookWeg() {
  var i;
  if (!C) return;
  for (i = 0; i < 4; i++) C.wereld.getalTag({ x: 0, z: 0 }, null, { id: 'kr_sp' + i });
}
/* De voordoen-rij ligt op het gras vóór de kraam, 40 css-px uit elkaar
   (een spookmuntje is 33 px breed en cijfers wijken niet uit), en op een
   diepte-lijn vóór de buidel zodat hij daar niet over valt. */
function spookNeer(bedrag, titel) {
  spookWeg();
  if (!(bedrag > 0) || !O) return;
  var munten = splitsMet(bedrag, SPOOK_MUNT), i, p;
  for (i = 0; i < munten.length && i < SPOOK_MAX; i++) {
    p = opGras(-160 + i * 40, 32);
    C.wereld.getalTag({ x: p.x, z: p.z, kamer: 'tuin' }, euro(munten[i]),
                      { id: 'kr_sp' + i, y: 0, klas: 'hotspook', prio: 7, titel: titel });
  }
}

/* =====================================================================
   8. HET CIJFERPAD: de som van groep 4 en het wisselgeld van groep 5
===================================================================== */
function antwoordSom(n, k) {
  if (!S || S.stap !== 'som') return;
  if (n === null) {
    zeg({ icoon: '☝', tekst: 'tik een getal' });
    teken();
    return;
  }
  if (n !== O.vraag.goed) {
    S.somPog++;
    S.missers++;
    C.snd.zacht();
    if (k) k.zet('');
    /* de hulpladder: eerst samen tellen, daarna nog eens, en pas bij de
       derde poging liggen er spookmunten (tekenKaart legt die neer) */
    S.hulp = O.band === 4
      ? telVanaf(gekocht()[0].prijs, gekocht()[1].prijs)
      : euro(O.kosten) + ' → ' + euro(O.betaald);
    zeg(null);
    bewaar();
    teken();
    return;
  }
  C.state.tel(S.somPog === 0, C.ui.nu() - S.t0);
  C.snd.ja();
  if (k) k.zet(euro(n));
  S.stap = 'leg';
  S.hulp = '';
  S.zeg = null;
  spookWeg();
  bewaar();
  straks(600, function () { if (C && S && S.stap === 'leg') teken(); });
}

/* =====================================================================
   9. DE MUNTEN
===================================================================== */
function pakMunt(v) {
  if (!S || S.stap !== 'leg' || !O) return;
  if (O.munten.indexOf(v) < 0) return;
  S.hand = v;
  C.snd.tik();
  zeg({ icoon: '🪙', getal: euro(v), tekst: 'in je hand' });
  bewaar();
  teken();
}
/* voor de speeltest: de volgende munt in je hand pakken */
function volgendeMunt() {
  if (!S || !O) return;
  pakMunt(O.munten[(O.munten.indexOf(S.hand) + 1) % O.munten.length]);
}

function legMunt(v) {
  if (!S || S.stap !== 'leg' || !O) return;
  if (O.munten.indexOf(v) < 0) v = S.hand;
  herstelBank();
  /* Er schuift al een munt terug: dan neemt de kraam er even geen nieuwe
     aan. Zonder deze poort legt elke tik in dat halve seconde-venster een
     munt bij terwijl er maar één terugkomt. */
  if (terugMunt) {
    C.snd.zacht();
    zeg({ icoon: '🪙', getal: euro(opBank() - O.doel), tekst: 'terug' });
    teken();
    return;
  }
  var som = tel(S.gelegd);
  S.hand = v;
  /* te veel: de munt gaat er even op en schuift dan terug. Zo ziet het
     kind hoeveel het te veel was; er wordt nooit iets afgepakt en de
     beurt gaat gewoon door. De munt zit alleen in terugMunt, dus de
     OPSLAG blijft op de laatste geldige stand staan. */
  if (som + v > O.doel) {
    terugMunt = v;
    S.missers++;
    terugNr++;
    var mijn = terugNr;
    C.snd.munt();
    zeg({ icoon: '🪙', getal: euro(som + v - O.doel), tekst: 'terug' });
    bewaar();                           /* alleen de geldige stand */
    teken();
    straks(750, function () {
      if (!C || !S || terugNr !== mijn) return;
      terugMunt = 0;
      C.snd.terug();
      teken();
    });
    return;
  }
  S.gelegd.push(v);
  C.snd.munt();
  zeg(null);
  S.spook = 0;
  spookWeg();
  bewaar();
  if (tel(S.gelegd) === O.doel) { gelukt(); return; }
  teken();
}

/* "zo is het goed": tikken mag altijd. Ligt er te weinig, dan zegt het
   wolkje rustig hoeveel er nog bij moet (nooit rood, nooit een kruis). */
function klaarMetTellen() {
  if (!S || S.stap !== 'leg' || !O) return;
  var som = opBank();
  if (som === O.doel) { gelukt(); return; }
  S.legPog++;
  S.missers++;
  C.snd.zacht();
  if (som < O.doel) zeg({ icoon: '🪙', getal: '+' + euro(O.doel - som), tekst: 'erbij' });
  else zeg({ icoon: '🪙', getal: euro(som - O.doel), tekst: 'terug' });
  if (S.legPog >= 2) S.hulp = splitsMet(O.doel, O.munten).map(euro).join(' + ');
  S.spook = S.legPog >= 3 ? 1 : 0;
  bewaar();
  teken();
}

/* =====================================================================
   10. GELUKT: het gekochte gaat mee op het dier
===================================================================== */
function gelukt() {
  if (!S || S.stap === 'af') return;
  S.stap = 'af';
  S.spook = 0;
  S.hulp = '';
  S.zeg = null;
  spookWeg();
  var g = gast();
  /* het gekochte blijft ZICHTBAAR op het dier tot uitchecken (P1e) */
  if (g && !S.acc) {
    gekocht().forEach(function (w) {
      if (w.acc && C.wereld.accessoire) C.wereld.accessoire(g.id, w.acc);
    });
    S.acc = 1;
  }
  C.state.tel(S.missers === 0, C.ui.nu() - S.t0);
  /* eerst het taakje afvinken (dat is ook de ster), dán de wens afmelden:
     behoefteKlaar tekent het prikbord meteen opnieuw (zie tobbe.js) */
  ster();
  if (g && S.wens) C.wereld.behoefteKlaar(g.id, 'souvenir');
  C.snd.tover();
  C.snd.hoera();
  bewaar();
  if (window.Hotel) Hotel.render();
  teken();
  if (g) {
    C.wereld.setMood(g.id, 'bouncy');
  }
  straks(3400, function () { if (C && S && S.stap === 'af') C.sluit(); });
}

/* =====================================================================
   AANMELDEN
===================================================================== */
Games.register({
  id: 'kraam',
  naam: 'Souvenirkraam',
  kamer: 'tuin',
  /* Het knopje hangt op de toonbank in de kraamzone. registry.js kent de
     plek van los decor niet, dus we hangen het aan het dichtstbijzijnde
     VASTE tuinstuk (de bal op 120, 76) en schuiven het met dx/dz naar de
     toonbank: (120 - 5, 76 - 18) = (115, 58) - precies de bank. */
  hotspot: { obj: 'bal', dx: -5, dz: -18, icoon: '🎁', label: 'Kraam', hoog: 14 },
  wens: 'souvenir',
  unlock: function (N) { return N >= 1; },
  stub: false,
  taak: { id: 'souvenir', prio: 1, icoon: '🎁',
          wanneer: function (s) {
            return s.gasten.some(function (g) { return g.behoefte === 'souvenir' && !g.blij; });
          },
          tekst: function (s) {
            var g = s.gasten.filter(function (q) { return q.behoefte === 'souvenir'; })[0];
            return g ? g.naam + ' wil een souvenir' : 'Souvenir';
          } },
  start: start,
  stop: stop,
  /* ---------- haakjes voor de speeltest (het hotel gebruikt ze niet) ---------- */
  proef: function (N, band, dag) { return opzet(N, band, dag); },
  keuring: keuring,
  plek: function (n) { return plekken(n || 3); },
  splits: function (bedrag, munten) { return splitsMet(bedrag, munten || [1, 2]); },
  spook: function (bedrag) { return splitsMet(bedrag, SPOOK_MUNT); },
  telVanaf: telVanaf,
  debug: function () {
    if (!S) return null;
    var uit = JSON.parse(JSON.stringify(S));
    uit.opzet = O ? JSON.parse(JSON.stringify(O)) : null;
    uit.plekken = P ? JSON.parse(JSON.stringify(P)) : null;
    uit.som = tel(S.gelegd);          /* de GELDIGE stand (dit gaat de opslag in) */
    uit.opBank = opBank();            /* wat er op het beeld ligt */
    uit.terugMunt = terugMunt;
    uit.kaartLift = kaartLift;
    uit.padPlek = kaartPad;           /* waar het cijferpad nu hoort (G5-F2) */
    uit.kaderHoogVrij = kaderHoogVrij();
    uit.gastVak = gastVak();
    uit.kaartVak = vak('[data-hot="kr_som"]');
    return uit;
  },
  doe: function (wat, a) {
    if (wat === 'leg') return legMunt(a);
    if (wat === 'pak') return pakMunt(a);
    if (wat === 'klaar') return klaarMetTellen();
    if (wat === 'som') return antwoordSom(a, kaart);
    if (wat === 'teken') return teken();
    if (wat === 'spook') return spookNeer(a, 'proef');
    if (wat === 'sluit') return C ? C.sluit() : null;
    return null;
  }
});
})();
