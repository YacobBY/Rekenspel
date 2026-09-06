/* ---------------------------------------------------------------
   games/sleutels.js - HET SLEUTELBORD (getalpatronen), HOTEL.md 9.

   Alles gebeurt ÍN de receptie, er is geen rekenblad ernaast:
     * aan de wand hangt een rij nummerplaatjes (hotspots op een
       schuine lijn, zodat ze op het scherm 52 px uit elkaar staan);
       één of twee plaatjes zijn leeg en tonen een "?";
     * aan de balie staat een gast met een sleutellabel: een wolkje
       "🔑 14" boven zijn kop en de sleutel zelf als sleepbron bij
       zijn pootjes;
     * aan het sleutelbord hangt één sommenkaartje met de rij zoals je
       hem in je schrift zou schrijven: "5, 10, __, 20" - en in het
       antwoordvakje de sleutel die je in je hand hebt;
     * goed: de sleutel rinkelt aan het haakje, het plaatje wordt zijn
       nummer en de gast loopt naar zijn eigen kamer. Boven zijn deur
       in de gang komt een plaatje "💡 14";
     * fout: het haakje wiebelt, de sleutel glijdt terug en de twee
       BUURPLAATJES lichten op (pictogram + getal, geen tekstlap).
       Na twee pogingen legt buurvrouw Els spookcijfers op de lege
       haakjes.
   Nooit een rood kruis, nooit een klok. De ster is voor het meedoen.

   ------------------------------------------------------------------
   DE GETALLENGENERATOR (sommen.* heeft geen reeks, dus hier afgeleid;
   zelfde schaalregel als HOTEL.md 3: N bepaalt de GROOTTE en de
   HOEVEELHEID werk, de band bepaalt de SOORT sprong)

     haakjes    H = 2 + ceil(N / 2), geklemd op 4..5 (groep 3 en 4) en
                op 4 bij groep 5, want een plaatje met drie cijfers is
                breder. Meer past niet in beeld: elk plaatje is een
                tikdoel van 48 px ÍN de wereld en de receptie is maar
                ~160 voxels breed - zie de meetlat in de speeltest.
     sleutels   B = ceil(N / 3), geklemd op 1..2 (groep 3 en 4) of
                1..3 (groep 5), en nooit meer dan er gasten zijn
     borden     per bord hooguit 2 lege haakjes (nooit twee naast
                elkaar, nooit op de rand), dus meer sleutels geven meer
                borden: het volgende bord is het volgende stuk van de
                reeks (of de tweede verdieping / de even rij)
     rij        waarde(i) = van + i * stap

   Welke rij bij welke groep (de dag wisselt de variant af):

     groep 3  telrij van 1 (1..5) of de tienovergang (16..20). stap 1.
     groep 4  sprongen van 5 (5..25 / 30..50), sprongen van 10
              (10..50 / 50..90), of oneven (1,3,5..) en dan even.
     groep 5  kamernummers per verdieping (111..114 en dan 211..214 ->
              "kamer 214 = verdieping 2, kamer 14") of sprongen van 25
              (25..100 / 125..200).

   Elk leeg haakje heeft PRECIES ÉÉN goed antwoord, en dat is na te
   rekenen: controleer() checkt dat alle getallen van een bord
   verschillend zijn, dat elke rij een echte rekenrij is, dat er nooit
   twee lege haakjes naast elkaar of op de rand hangen (er zijn dus
   altijd twee buren om de sprong uit te lezen) en dat het nummer van
   een sleutel op precies één haakje past.
   Games.get('sleutels').debug geeft die functies aan de speeltest.

   Dit bestand raakt niets van het hotel aan: alles loopt via de ctx
   uit GAMES-API.md.
---------------------------------------------------------------- */
(function () {
'use strict';

var PLAFOND   = { 3: 20, 4: 100, 5: 1000 };   /* getalbereik per groep */
var MAXBLANCO = { 3: 2, 4: 2, 5: 3 };         /* lege haakjes per opdracht */

/* ---------- waar hangt alles in de receptie? (voxels) ----------
   Alles staat als BREUK van de kamer (Rooms.plek / Rooms.hoogte), want de
   receptie is met K1 1,5x groter geworden (120 x 120 in plaats van 80 x 80)
   en dan schuift de hele opstelling automatisch mee. De breuken zijn precies
   de oude voxels gedeeld door 80.
   De haakjes liggen op de schuine lijn x + z = 0,625 (w + d) = 150: daar
   hebben twee plaatjes met 2 x 0,1625 w = 39 voxels verschil in (x - z) op
   het scherm ruim 52 px tussen zich, ook op de kleinste schaal. Ze staan
   bovendien VÓÓR de gast en het meubilair (grote x+z), dus de laag schuift
   hén niet weg maar de rest om hen heen. */
function vox(f) { return Rooms.hoogte('receptie', f); }   /* breuk -> voxels */
var HAAK_MID = vox(0.625);                    /* midden van de rij (x en z) */
var HAAK_SOM = 2 * HAAK_MID;                  /* de schuine lijn x + z */
var HAAK_DX = vox(0.1625), HAAK_DX3 = vox(0.2);
var HAAK_Y = vox(0.6);
var GAST_PLEK = Rooms.plek('receptie', 0.75, 0.85);   /* vrij vakje voor de balie */
var KEY_PLEK = Rooms.plek('receptie', 0.675, 0.975); /* de sleutel naast zijn poot */
var ELS_PLEK = Rooms.plek('receptie', 0.25, 0.975, vox(0.075));
/* De hoogtes zijn zo gekozen dat op het scherm niets elkaar afdekt:
   de sommenkaart hangt boven de rij haakjes, de rij hangt boven het wolkje
   van de gast, en het wolkje net boven zijn kop (het dier zelf blijft dus
   te zien). Zie de meetlat in de speeltest: verticaal = (x + z) - 2y. */
/* De sommenkaart hangt boven de rij haakjes. Met de zin erboven (HOTEL.md 9)
   is het kaartje ~85 px hoog in plaats van ~45, dus hij hangt zeven stappen
   hoger: anders raakt zijn onderrand de haakjes en schuift de knoppenlaag de
   rij uit elkaar (gemeten met sleutels/plek.js: één stap is ~2 px). */
var KAART_HOOG = vox(0.775);                  /* sommenkaart boven het bord */
var WOLK_HOOG = vox(0.4625), KEY_HOOG = vox(0.05);
var GAST_SOM = GAST_PLEK.x + GAST_PLEK.z;     /* de diepte (x + z) van de gast */

/* ---------- en waar past dat in DIT kader? (X1) ----------
   De hoogtes hierboven zijn voxels: ze krimpen en groeien met de voxelmaat k
   (HOTEL.md 1, per kamer). Een sommenkaart is dat niet: die is 92 css-px hoog
   omdat er een zin op staat, op elk scherm. Daardoor klopt één vaste breuk
   niet voor elk kader:
     portret 420x900   kader 386x473, k = 0,78 - de kaart hangt 79 px boven de
                       rij en dat is genoeg (11 px lucht): alles blijft staan
                       zoals het stond.
     liggend 1000x640  kader 966x378, k = 1,25 - de camera snijdt de kale wand
                       af, de kaart wil 54 px BOVEN het kader hangen en de
                       knoppenlaag klemt hem tegen de bovenrand (onderrand op
                       94 px). De rij hing op haar gewone hoogte 38 px ín de
                       kaart, en de laag schoof haakje 0 en 1 uit de rij.
     liggende telefoon kader 826x190 (860x420) of 706x190 (740x360) - daar
                       passen kaart (92) + rij (48) + wolkje (48) niet meer
                       boven de kop van de gast.
   Daarom meet opbouw() het kader op en kiest hij zijn opstelling: STAPEL
   (kaart boven, rij eronder, wolkje onder de rij, precies zo veel lager als
   nodig), NAAST (kaart uiterst links, rij rechts ernaast in de bovenste
   strook) of, in een kader waarin ook dat niet past, KRAP (de rij gaat vóór,
   het wolkje wijkt). Past alles al, dan blijft het GEWOON - portret verandert
   dus niet. Zie .fanout/specs/api-x1.md. */
var GAP = 4;              /* css-px lucht tussen de kaart en de rij */
var GAP_WOLK = 6;         /* ... en tussen de rij en het wolkje */
var KNOP = 48;            /* een tikdoel is minstens zo groot (style.css .hot) */
var DIER_HOOG = 28;       /* de gasten zijn 23-28 voxels hoog (art.js): daarboven blijft het wolkje */

var C = null;     /* de ctx */
var P = null;     /* de opdracht - hij woont in C.data(), dus hij blijft bewaard */
var U = null;     /* wat alleen op het scherm leeft: licht, buren, spook, tip */
/* de opzegger van de opmaat-bus (M1c). Hij staat BUITEN U, want U wordt bij
   elke start() opnieuw gemaakt en dan zou een oude aanmelding blijven hangen
   als er geen stop() tussen zat. */
var maatAf = null;

/* =====================================================================
   1. DE GETALLEN
===================================================================== */
function klem(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

/* een klein, voorspelbaar toevalsgetal: hetzelfde zaadje = hetzelfde bord,
   dus na "Verder spelen" hangt de rij er nog precies zo */
function zaadje(n) {
  var s = (n >>> 0) || 1;
  return function () { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
}

/* Meer haakjes passen niet: elk plaatje is een tikdoel van 48 px in de
   wereld en er is maar een strook van ~390 css-px breed voor de rij.
   Getallen van drie cijfers (groep 5) hebben een breder plaatje, dus daar
   hangen er vier. */
function aantalHaken(N, band) {
  return klem(2 + Math.ceil(Math.max(1, N) / 2), 4, (band || 3) >= 5 ? 4 : 5);
}
function aantalSleutels(N, band) {
  return klem(Math.ceil(Math.max(1, N) / 3), 1, MAXBLANCO[band] || 2);
}
function perBord(H) { return H >= 5 ? 2 : 1; }   /* twee lege haakjes vragen 5 haakjes */

/* welke variant hoort bij deze groep en deze dag? */
function variantVan(band, dag) {
  if (band <= 3) return dag % 2 === 0 ? 'telrij-tien' : 'telrij';
  if (band === 4) return ['sprong5', 'sprong10', 'evenoneven'][dag % 3];
  return dag % 2 === 0 ? 'kamers' : 'sprong25';
}

/* de rij van één bord: deel 0 is het eerste stuk, deel 1 het volgende
   (of de tweede verdieping / de even rij) */
function rijVan(variant, dag, H, deel) {
  var plaf, van, stap = 1, label = null;
  if (variant === 'telrij') { van = 1 + deel * H; stap = 1; plaf = PLAFOND[3]; }
  else if (variant === 'telrij-tien') { van = (PLAFOND[3] - H + 1) - deel * H; stap = 1; plaf = PLAFOND[3]; }
  else if (variant === 'sprong5') { van = 5 + deel * H * 5; stap = 5; plaf = PLAFOND[4]; }
  else if (variant === 'sprong10') {
    /* t/m 100; een bord met driecijferige getallen krijgt bredere plaatjes
       en dus meer ruimte tussen de haakjes (zie drieCijfers) */
    van = 10 + deel * H * 10; stap = 10; plaf = PLAFOND[4];
  }
  else if (variant === 'evenoneven') {
    van = deel ? 2 : 1; stap = 2; plaf = PLAFOND[4];
    label = deel ? 'even' : 'oneven';
  } else if (variant === 'kamers') {
    /* om en om verdieping 1 en 2; het derde bord is het volgende blok kamers,
       zodat geen enkel kamernummer twee keer op het bord komt */
    var s = (dag % 4 === 0) ? 11 : 1;
    var verd = 1 + (deel % 2), blok = Math.floor(deel / 2);
    van = 100 * verd + s + blok * H; stap = 1; plaf = PLAFOND[5];
    label = 'verdieping ' + verd;
  } else { van = 25 + deel * H * 25; stap = 25; plaf = PLAFOND[5]; }
  /* nooit boven het plafond van de groep, nooit onder 1 (en niet met de stap
     omhoog duwen: de oneven rij begint juist op 1) */
  van = Math.max(1, Math.min(van, plaf - (H - 1) * stap));
  return { van: van, stap: stap, n: H, label: label };
}

/* lege haakjes: nooit op de rand en nooit naast elkaar, zodat er altijd
   twee buren staan om de sprong uit te lezen */
function kiesBlanco(n, hoeveel, rnd) {
  var kand = [], uit = [], i, k;
  for (i = 1; i <= n - 2; i++) kand.push(i);
  while (uit.length < hoeveel && kand.length) {
    k = kand[Math.floor(rnd() * kand.length)];
    uit.push(k);
    kand = kand.filter(function (q) { return Math.abs(q - k) > 1; });
  }
  return uit.sort(function (a, b) { return a - b; });
}

function handtekening(N, band, dag, ronde) { return [N, band, dag, ronde || 0].join('|'); }

/* gasten = [{id, naam, soort}] - eentje per sleutel */
function maakOpdracht(N, band, dag, gasten, ronde) {
  band = klem(band || 3, 3, 5);
  var H = aantalHaken(N, band);
  var variant = variantVan(band, dag);
  var B = Math.min(aantalSleutels(N, band), gasten.length);
  var rnd = zaadje(dag * 7919 + N * 131 + band * 17 + (ronde || 0) * 8191 + 1);
  var borden = [], sleutels = [], deel = 0, over = B;
  while (over > 0 && deel < 3) {
    var hoeveel = Math.min(perBord(H), over);
    var rij = rijVan(variant, dag, H, deel);
    var blanco = kiesBlanco(H, hoeveel, rnd);
    var haken = [], i;
    for (i = 0; i < H; i++) {
      haken.push({ w: rij.van + i * rij.stap, blanco: blanco.indexOf(i) >= 0, sleutel: null });
    }
    borden.push({ van: rij.van, stap: rij.stap, n: H, label: rij.label,
                  blanco: blanco, haken: haken });
    blanco.forEach(function (i2) {
      var g = gasten[sleutels.length];
      if (!g) { haken[i2].blanco = false; return; }
      sleutels.push({ gast: g.id, naam: g.naam, soort: g.soort,
                      nummer: haken[i2].w, bord: deel, haak: i2, op: false, mis: 0 });
    });
    over -= blanco.length;
    deel++;
  }
  return { sig: handtekening(N, band, dag, ronde), band: band, N: N, dag: dag,
           ronde: ronde || 0, variant: variant, H: H,
           borden: borden, sleutels: sleutels,
           nu: 0, missers: 0, klaar: false, t0: 0 };
}

/* de nareken-functie: één goed antwoord per leeg haakje, netjes binnen de band */
function controleer(p) {
  var fout = [], plaf = PLAFOND[p.band] || 20, alle = {};
  p.borden.forEach(function (b, nr) {
    var tel = {};
    b.haken.forEach(function (h, i) {
      tel[h.w] = (tel[h.w] || 0) + 1;
      alle[h.w] = (alle[h.w] || 0) + 1;
      if (h.w !== b.van + i * b.stap) fout.push('bord ' + nr + ': haakje ' + i + ' is geen rekenrij');
      if (h.w > plaf || h.w < 1) fout.push('bord ' + nr + ': getal ' + h.w + ' buiten 1..' + plaf);
    });
    Object.keys(tel).forEach(function (w) {
      if (tel[w] !== 1) fout.push('bord ' + nr + ': getal ' + w + ' hangt ' + tel[w] + 'x');
    });
    if (b.haken.length !== b.n) fout.push('bord ' + nr + ': ' + b.haken.length + ' haakjes i.p.v. ' + b.n);
    var zicht = b.haken.filter(function (h) { return !h.blanco; }).length;
    if (zicht < 2) fout.push('bord ' + nr + ': maar ' + zicht + ' plaatje(s), sprong niet te zien');
    var bl = b.haken.map(function (h, i) { return h.blanco ? i : -1; })
                    .filter(function (i) { return i >= 0; });
    if (bl.length > 2) fout.push('bord ' + nr + ': ' + bl.length + ' lege haakjes op één bord');
    bl.forEach(function (i) {
      if (i === 0 || i === b.n - 1) fout.push('bord ' + nr + ': leeg haakje op de rand (' + i + ')');
      if (bl.indexOf(i + 1) >= 0) fout.push('bord ' + nr + ': twee lege haakjes naast elkaar');
    });
  });
  /* de getallen van de verschillende borden mogen niet door elkaar lopen */
  Object.keys(alle).forEach(function (w) {
    if (alle[w] !== 1) fout.push('getal ' + w + ' komt op twee borden voor');
  });
  var blanco = 0;
  p.borden.forEach(function (b) { b.haken.forEach(function (h) { if (h.blanco) blanco++; }); });
  if (blanco !== p.sleutels.length)
    fout.push(p.sleutels.length + ' sleutels voor ' + blanco + ' lege haakjes');
  var nrs = {};
  p.sleutels.forEach(function (s) {
    if (nrs[s.nummer]) fout.push('twee sleutels met nummer ' + s.nummer);
    nrs[s.nummer] = 1;
    var past = [];
    p.borden.forEach(function (b, nr) {
      b.haken.forEach(function (h, i) { if (h.w === s.nummer) past.push(nr + ':' + i); });
    });
    if (past.length !== 1) fout.push('sleutel ' + s.nummer + ' past op ' + past.length + ' haakjes');
    else if (past[0] !== s.bord + ':' + s.haak) fout.push('sleutel ' + s.nummer + ' wijst verkeerd');
    var h2 = p.borden[s.bord] && p.borden[s.bord].haken[s.haak];
    if (!h2 || !h2.blanco) fout.push('sleutel ' + s.nummer + ' hoort niet bij een leeg haakje');
  });
  var grootste = 0;
  p.borden.forEach(function (b) { b.haken.forEach(function (h) { grootste = Math.max(grootste, h.w); }); });
  return { ok: fout.length === 0, fout: fout, borden: p.borden.length,
           haken: p.borden.length ? p.borden[0].haken.length : 0,
           blanco: blanco, sleutels: p.sleutels.length,
           grootste: grootste, variant: p.variant, band: p.band };
}

/* =====================================================================
   2. STARTEN EN STOPPEN
===================================================================== */
function gastenMetBed() {
  return C.state.gasten().filter(function (g) { return !!g.bed && !!g.kamer; });
}
function sleutelNu() {
  if (!P || P.nu >= P.sleutels.length) return null;
  return P.sleutels[P.nu];
}
function bordNu() {
  var s = sleutelNu();
  if (s) return P.borden[s.bord];
  return P.borden[P.borden.length - 1];
}

function start(ctx) {
  C = ctx;
  U = { licht: null, buren: null, kaart: null, spook: false, tip: null,
        /* voor de opbouw in het kader (X1): het anker van de kaart aan de
           wand, de opstelling die het laatst gekozen is (debug.opbouw) en de
           luisteraar die na het kantelen opnieuw opbouwt */
        anker: null, opbouw: null, luister: null, wacht: 0 };
  var gasten = gastenMetBed();
  if (!gasten.length) {
    C.ui.wolk('sleutelbordz', { id: 'sl_leeg', door: 'sleutels', icoon: '🛏',
                                tekst: 'nog geen gasten', hoog: 26, klas: 'hulp' });
    setTimeout(function () { if (C) { C.ui.wolkWeg('sl_leeg'); C.sluit(); } }, 1900);
    return;
  }
  var D = C.data();
  var N = C.state.N(), band = C.state.band(), dag = C.state.dag();
  D.ronde = D.ronde || 0;
  var sig = handtekening(N, band, dag, D.ronde);
  if (!D.bord || D.bord.sig !== sig || D.bord.klaar || !gastenKloppen(D.bord)) {
    D.bord = maakOpdracht(N, band, dag, gasten.slice(0, MAXBLANCO[klem(band, 3, 5)]), D.ronde);
  }
  P = D.bord;
  if (!P.t0) P.t0 = C.ui.nu();
  C.wereld.naar('receptie');
  U.anker = C.wereld.mik('sleutelbordz', 'receptie') || { x: 1, z: 84 };
  haalGast();
  /* Kantelt het scherm, dan is het kader anders (van 386x473 naar 966x378) en
     hoort de opstelling opnieuw gekozen te worden. Net als het cijferpad van
     ui.js wachten we even tot de wereld haar nieuwe maat heeft genomen. */
  U.luister = function () {
    if (!U) return;
    clearTimeout(U.wacht);
    U.wacht = setTimeout(function () { if (C && P && U) teken(); }, 220);
  };
  /* Sinds M1c hangt dat aan de opmaat-bus (Ui.opKader -> World.onKader, M1b)
     in plaats van aan window resize + orientationchange: één melding per echte
     kaderverandering, en ook als alleen het kader krimpt. */
  if (maatAf) { maatAf(); maatAf = null; }
  maatAf = C.ui.opKader(U.luister);
  teken();
}

/* staan de gasten van deze opdracht er nog (niet uitgecheckt)? */
function gastenKloppen(p) {
  if (!p || !p.sleutels || !p.sleutels.length) return false;
  return p.sleutels.every(function (s) {
    var g = C.state.gast(s.gast);
    return !!(g && g.bed && g.kamer);
  });
}

function stop() {
  if (!C) return;
  if (maatAf) { maatAf(); maatAf = null; }
  if (U) { U.luister = null; clearTimeout(U.wacht); }
  /* wie nog met zijn sleutellabel aan de balie staat, gaat weer naar zijn
     eigen kamer: het hotel blijft opgeruimd achter */
  if (P) P.sleutels.forEach(function (s) { if (!s.op) naarKamer(s.gast, false); });
  C.hotspots.wisAlles();
  C.hotspots.laat();
  if (window.Hotel) Hotel.render();
  C = null; P = null; U = null;
}

/* de gast met het sleutellabel komt naar de balie */
function haalGast() {
  var s = sleutelNu();
  if (!s) return;
  var g = C.state.gast(s.gast);
  if (!g) return;
  var d = C.wereld.dier(s.gast);
  if (d && d.kamer === 'receptie' &&
      Math.abs(d.x - GAST_PLEK.x) + Math.abs(d.z - GAST_PLEK.z) < 8) return;
  C.wereld.reis(s.gast, 'receptie', { x: GAST_PLEK.x, z: GAST_PLEK.z, na: 'wacht' });
  g.waar = 'receptie';
  C.wereld.vuil();
}

/* het dier gaat naar zijn eigen kamer en kruipt in bed */
function naarKamer(gastId, blij) {
  var g = C.state.gast(gastId);
  if (!g) return;
  if (g.kamer && g.bed) {
    C.wereld.slaap(gastId, g.kamer, g.bed);
    g.waar = g.kamer;
    if (blij) C.wereld.setMood(gastId, 'blij');
  } else C.wereld.solo(gastId, 'blij');
  C.wereld.vuil();
}

/* =====================================================================
   3. HET BORD IN DE WERELD
===================================================================== */
function drieCijfers(b) { return b.van + (b.n - 1) * b.stap >= 100; }
/* y = de hoogte van de rij (gewoon HAAK_Y), schuif = hoeveel voxels de hele
   rij langs de wand opschuift (naar rechts op het scherm). De diepte x + z
   blijft HAAK_SOM, dus de rij houdt haar plek in de tekenvolgorde. */
function haakPlek(i, n, dx, y, schuif) {
  var x = Math.round(HAAK_MID + (schuif || 0) + (dx || HAAK_DX) * (i - (n - 1) / 2));
  return { x: x, z: HAAK_SOM - x, y: y === undefined || y === null ? HAAK_Y : y,
           kamer: 'receptie' };
}

function nrTekst(w) { return P.variant === 'kamers' ? 'kamer ' + w : 'nummer ' + w; }
function verdieping(w) {
  return 'kamer ' + w + ', verdieping ' + Math.floor(w / 100) + ', kamer ' + (w % 100);
}

/* de rij zoals je hem in je schrift schrijft: "5, 10, __, 20" */
function rijTekst(b) {
  var uit = b.haken.map(function (h) {
    return (h.blanco && h.sleutel === null) ? '__' : String(h.w);
  }).join(', ');
  return (b.label ? b.label + ': ' : '') + uit;
}

function teken() {
  if (!C || !P) return;
  C.hotspots.wisAlles();
  var b = bordNu(), s = sleutelNu();

  /* Eerst het bord op zijn gewone plek zetten en dan opmeten: een kaartje en
     een plaatje hebben pas een echte maat als ze in de pagina staan. Kiest
     opbouw() daardoor een andere opstelling (liggend), dan zetten we het bord
     meteen goed. De knoppenlaag verplaatst de knoppen pas in de volgende
     tekenbeurt (hits.plaats vanuit de tekenlus), dus dit tweede rondje is op
     het scherm niet te zien. */
  var lay = gewoon();
  tekenBord(b, s, lay);
  var lay2 = opbouw(b);
  if (verschilt(lay2, lay)) { lay = lay2; tekenBord(b, s, lay); }
  U.opbouw = lay;
  /* de plaatjes met het lampje boven de deuren in de gang horen bij de stand
     van het spel, dus tekenen we ze hier opnieuw: wisAlles() haalde ze net weg */
  deurPlaatjes();

  /* 3b. de sleutel bij zijn poot: de sleepbron. Hij hangt aan de PLEK bij de
         balie waar de gast naartoe loopt, niet aan het dier zelf (zie
         tekenBord), en hij schuift met geen enkele opstelling mee. */
  if (s) {
    C.hotspots.bron({ x: KEY_PLEK.x, z: KEY_PLEK.z, kamer: 'receptie' }, {
      id: 'sl_key', icoon: '🔑', aantal: s.nummer, hoog: KEY_HOOG, prio: 12,
      titel: 'de sleutel van ' + s.naam + ': ' + nrTekst(s.nummer),
      tik: function () { wijsAan(); },
      sleep: {
        dropSel: '[data-drop="haak"]',
        ghostHTML: function () {
          return '<div class="karghost">🔑<b>' + s.nummer + '</b></div>';
        },
        canDrag: function () { return !!P && !!sleutelNu(); },
        onDrop: function (t) { hang(+t.getAttribute('data-h-i')); },
        onTap: function () { wijsAan(); }
      }
    });
  }

  /* 4. buurvrouw Els: pas na twee pogingen, en ze legt spookcijfers neer */
  if (P.missers >= 2 && !P.klaar) {
    C.hotspots.maak({
      id: 'sl_els', kamer: 'receptie', x: ELS_PLEK.x, z: ELS_PLEK.z, y: ELS_PLEK.y,
      icoon: '🩺', klas: 'hotwolk hulp', prio: 8,
      titel: 'buurvrouw Els doet het voor', aan: hulp
    });
  }
  C.wereld.vuil();
}

/* de rij, de sommenkaart en het wolkje van de gast, op de plekken uit lay
   (zie opbouw). Alle drie horen bij elkaar: ze staan onder elkaar. */
function tekenBord(b, s, lay) {
  var i;
  /* 1. de nummerplaatjes aan de wand: sleep-doelen met hun getal erop */
  for (i = 0; i < b.haken.length; i++) tekenHaak(b, i, lay);

  /* 2. één sommenkaartje aan het sleutelbord: de rij + de sleutel in je hand */
  /* de rij staat er nooit kaal (HOTEL.md 9): één gewone vraag erboven, met
     het pictogram vooraan op dezelfde regel. Gewoon hangt de kaart aan het
     sleutelbord; in een laag kader (opstelling 'naast') uiterst links. */
  var anker = lay.kaartX === null ? 'sleutelbordz'
            : { x: lay.kaartX, z: lay.kaartZ, kamer: 'receptie' };
  U.kaart = C.ui.somkaart(anker, rijTekst(b), {
    id: 'sl_kaart', door: 'sleutels', pad: false, hoog: KAART_HOOG,
    klas: P.klaar ? 'af' : '', icoon: '🔑',
    regel: s ? (P.variant === 'kamers' ? 'Welk kamernummer hoort in het gat?'
                                       : 'Welk nummer hoort in het gat?')
             : 'De rij is nu af'
  });
  if (U.kaart) {
    if (s) U.kaart.zet('🔑' + s.nummer); else U.kaart.klaar();
    if (U.buren) U.kaart.hulp(burenTekst());
    else if (U.tip) U.kaart.hulp(U.tip);
  }

  /* 3. de gast met zijn sleutel: wolkje boven zijn kop.
        Het hangt aan de PLEK bij de balie waar de gast naartoe loopt, niet aan
        het dier zelf: een wolkje dat aan een dier hangt houdt de kamer waarin
        het dier stond toen het wolkje werd gemaakt (ui.wolk/volg geven geen
        nieuwe kamer door), en dan staat het in de verkeerde ruimte. */
  if (s) {
    /* langs de wand meeschuiven houdt de diepte (x + z) gelijk: het wolkje
       blijft dus vóór de balie staan en achter niets verdwijnen */
    var wx = GAST_PLEK.x + (lay.wolkX || 0);
    C.ui.wolk({ x: wx, z: GAST_SOM - wx, kamer: 'receptie' }, {
      /* pictogram, nummer EN woorden in hetzelfde wolkje (HOTEL.md 9). Het
         blijft kort: in portret is de receptie ~386 px breed en duwt een
         breder wolkje de bel van het hotel in de rij haakjes (192 px past
         nog, 204 px niet - sleutels/plek.js). De hele opdracht staat als zin
         op de sommenkaart. */
      id: 'sl_tag', door: 'sleutels', icoon: '🔑', getal: s.nummer,
      tekst: U.buren ? 'kijk bij de buren' : 'hang mij op',
      klas: U.buren ? 'hulp' : '', hoog: lay.wolkY, prio: 10
    });
  }
}

/* =====================================================================
   3b. DE OPSTELLING IN HET KADER (X1)
   Alles in css-px binnen het kader, precies zoals de knoppenlaag rekent:
     scherm-x = px0 + (x - z) * 2k        scherm-y = py0 + (x + z - 2y) * k
   met k uit ctx.wereld.schaal() en (px0, py0) de achterhoek van de vloer uit
   World.vloer() - net zoals voerkar.js zijn bakjes in de keuken uitzet. De
   laag klemt daarna nog elke knop binnen het kader (2 px rand) en schuift wat
   elkaar afdekt uit elkaar; dat blijft het vangnet, maar met een opstelling
   die past hoeft ze niets meer te verschuiven - en juist dat verschuiven
   haalde de rij haakjes uit de rij.
===================================================================== */
function gewoon() {
  return { modus: 'gewoon', haakY: HAAK_Y, haakX: 0, haakDx: 0, wolkY: WOLK_HOOG,
           wolkX: 0, kaartX: null, kaartZ: null };
}
function verschilt(a, q) {
  return !!a && (a.haakY !== q.haakY || a.haakX !== q.haakX || a.haakDx !== q.haakDx ||
                 a.wolkY !== q.wolkY || a.wolkX !== q.wolkX || a.kaartX !== q.kaartX);
}
function kaderMaat() {
  var host = document.getElementById('worldHits');
  var s = C.wereld.schaal ? C.wereld.schaal() : null;
  var vl = (window.World && World.vloer) ? World.vloer() : null;
  var r = C.wereld.kamer('receptie');
  if (!host || !host.clientWidth || !host.clientHeight) return null;
  if (!s || !s.k || !vl || !r) return null;
  return { k: s.k, px0: vl.x + r.d * 2 * s.k, py0: vl.y,
           breed: host.clientWidth, hoog: host.clientHeight };
}
function schermX(m, x, z) { return m.px0 + (x - z) * 2 * m.k; }
function schermY(m, som, y) { return m.py0 + (som - 2 * y) * m.k; }
/* de hoogte y die een punt met diepte som op scherm-y py zet. laag = naar
   beneden afgerond (het komt hooguit één stapje LAGER dan gevraagd, en dat is
   de veilige kant als het onder iets anders moet blijven). */
function hoogteVoor(m, som, py, laag) {
  var y = (som - (py - m.py0) / m.k) / 2;
  return laag ? Math.floor(y + 1e-6) : Math.ceil(y - 1e-6);
}
/* hoeveel voxels langs de wand is dit een verschuiving op het scherm?
   (x + 1, z - 1) schuift een knop 4k px naar rechts. Naar boven afgerond. */
function schuifVoor(m, px) { return Math.ceil(px / (4 * m.k) - 1e-6); }
function maatVan(id) {
  var e = document.querySelector('#worldHits [data-hot="' + id + '"]');
  return { w: e ? e.offsetWidth || 0 : 0, h: e ? e.offsetHeight || 0 : 0 };
}
/* zo klemt de knoppenlaag een knop binnen het kader (hits.js, plaats) */
function klemY(m, py, h) {
  if (m.breed <= 78 || m.hoog <= 78) return py;
  return Math.max(h / 2 + 2, Math.min(m.hoog - h / 2 - 2, py));
}

/* Waar hangen de rij en het wolkje in DIT kader? Aangeroepen NA een tekenbeurt
   op de gewone plekken, zodat de echte maten bekend zijn: de kaart (met of
   zonder hulpregel: 92 of ~107 px), de plaatjes (een oplichtend getal maakt er
   53 px van) en het wolkje. Geeft de gewone opstelling terug als alles al past
   (portret) of als er (nog) niets te meten valt. */
function opbouw(b) {
  var uit = gewoon();
  var m = kaderMaat();
  if (!m || !U || C.wereld.actief() !== 'receptie') return uit;
  var kaart = maatVan('sl_kaart'), wolk = maatVan('sl_tag'), sleutel = maatVan('sl_key');
  if (!kaart.h) return uit;
  var n = b.haken.length, knopH = KNOP, knopW = KNOP, i, q;
  for (i = 0; i < n; i++) {
    q = maatVan('sl_h' + i);
    knopH = Math.max(knopH, q.h); knopW = Math.max(knopW, q.w);
  }
  if (!sleutel.h) sleutel = { w: 0, h: KNOP };
  var anker = U.anker || { x: 1, z: 84 }, ankerSom = anker.x + anker.z;
  /* de kaart: op haar gewone hoogte, of door de laag tegen de rand geklemd */
  var kaartMid = klemY(m, schermY(m, ankerSom, KAART_HOOG), kaart.h);
  var kaartOnder = kaartMid + kaart.h / 2;
  /* De rij: n plaatjes, en twee buren schelen 2dx in (x - z), dus staan ze
     4dx*k px van elkaar. Op de kleinste maat (kader 286 px breed, k = 0,58)
     is 4 x 20 x k maar 47 px en dat is minder dan een plaatje breed: dan
     vindt de laag dat de plaatjes elkaar afdekken en schuift ze de rij zelf
     uit elkaar. Daarom houdt de stap altijd 53 px aan - zo breed als een
     oplichtend plaatje met drie cijfers. */
  var dx = Math.max(drieCijfers(b) ? HAAK_DX3 : HAAK_DX,
                    Math.ceil((KNOP + 5) / (4 * m.k)));
  var rijW = (n - 1) * 4 * dx * m.k + knopW;
  if (dx !== (drieCijfers(b) ? HAAK_DX3 : HAAK_DX)) uit.haakDx = dx;
  var rijNat = schermY(m, HAAK_SOM, HAAK_Y);
  var rijMax = m.hoog - knopH / 2 - 2;          /* lager klemt de laag hem terug */
  var wolkNat = schermY(m, GAST_SOM, WOLK_HOOG);
  var keyMid = schermY(m, KEY_PLEK.x + KEY_PLEK.z, KEY_HOOG);
  var kopY = schermY(m, GAST_SOM, DIER_HOOG);   /* de bovenkant van de gast */
  /* Zo ver moet het wolkje van de rij en van de sleutel af blijven; anders
     vindt de laag dat ze elkaar afdekken (hits.js: |dy| < (h1 + h2) / 2 - 1)
     en schuift ze het wolkje weg - en daarna de rij, want die kiest later. De
     sleutel ligt bij zijn poot en verschuift nooit: hij kiest als eerste. */
  var vanRij = (wolk.h + knopH) / 2, vanKey = (wolk.h + sleutel.h) / 2;

  /* Waar hangt het wolkje bij een rij op hoogte rijMid? Onder de rij, boven de
     sleutel, in beeld, en zo hoog (dus zo dicht bij zijn kop) als dat kan.
     bovenKop = het wolkje moet de gast heel laten. null = past niet. */
  function wolkPlek(rijMid, bovenKop, lucht) {
    if (!wolk.h) return WOLK_HOOG;
    var laagst = Math.min(keyMid - vanKey - lucht, m.hoog - wolk.h / 2 - 2);
    if (bovenKop) laagst = Math.min(laagst, kopY - wolk.h / 2);
    var hi = hoogteVoor(m, GAST_SOM, rijMid + vanRij + lucht, true);   /* onder de rij */
    var lo = hoogteVoor(m, GAST_SOM, laagst, false);                   /* boven de sleutel */
    if (lo > hi) return null;
    return Math.min(hi, Math.max(lo, WOLK_HOOG));
  }

  /* A. DE STAPEL (portret, en liggend op een tablet): de kaart boven, de rij
        eronder - precies zo veel lager als de kaart nodig heeft - en het
        wolkje onder de rij, maar altijd boven de kop van de gast. */
  var wens = Math.max(rijNat, kaartOnder + GAP + knopH / 2);
  var haakY = wens > rijNat + 0.5 ? hoogteVoor(m, HAAK_SOM, wens, true) : HAAK_Y;
  var rijMid = schermY(m, HAAK_SOM, haakY);
  var wolkY = rijMid <= rijMax ? wolkPlek(rijMid, true, GAP_WOLK) : null;
  if (wolkY !== null) {
    uit.haakY = haakY; uit.wolkY = wolkY;
    if (haakY !== HAAK_Y || wolkY !== WOLK_HOOG || uit.haakDx) uit.modus = 'stapel';
    return uit;
  }

  /* B. NAAST (liggende telefoon: kader ~190 px hoog): de kaart uiterst links
        tegen de rand, de rij rechts ernaast op haar gewone hoogte aan de wand.
        Het wolkje blijft bij de gast en zakt onder de rij; komt het dan nog
        tegen de kaart aan, dan schuift het langs de wand naar rechts tot het
        naast de kaart staat. */
  var kaartRechts = kaart.w + 2;                /* de kaart begint op 2 px */
  var rijNatX = schermX(m, HAAK_MID, HAAK_MID);
  var rijMidX = Math.max(rijNatX, kaartRechts + GAP + rijW / 2);
  wolkY = wolkPlek(rijNat, false, GAP_WOLK);
  if (rijMidX + rijW / 2 + 2 <= m.breed && wolkY !== null) {
    uit.modus = 'naast';
    uit.kaartX = Math.round((ankerSom + (kaart.w / 2 + 2 - m.px0) / (2 * m.k)) / 2);
    uit.kaartZ = ankerSom - uit.kaartX;
    uit.haakX = schuifVoor(m, rijMidX - rijNatX);
    uit.wolkY = wolkY;
    if (wolk.h) {
      var wolkMid = schermY(m, GAST_SOM, wolkY);
      var wolkX = schermX(m, GAST_PLEK.x, GAST_PLEK.z);
      if (wolkMid - wolk.h / 2 < kaartOnder + GAP && wolkX - wolk.w / 2 < kaartRechts + GAP)
        uit.wolkX = schuifVoor(m, kaartRechts + GAP + wolk.w / 2 - wolkX);
    }
    return uit;
  }

  /* C. past die ook niet (een smal én laag kader: een telefoon van 320 px
        staand, 568 px liggend), dan de stapel zo laag als het kader toelaat.
        De rij gaat dan vóór: daar sleep je de sleutel naartoe, dus die blijft
        heel en de kaart blijft erboven. Het wolkje mag over de kop van de gast
        hangen, en past het ook daar niet tussen de rij en de sleutel, dan gaat
        het onder de sleutel staan - lelijker, maar alles blijft te tikken. */
  uit.modus = 'krap';
  uit.haakY = hoogteVoor(m, HAAK_SOM, Math.min(wens, rijMax), true);
  wolkY = wolkPlek(schermY(m, HAAK_SOM, uit.haakY), false, 0);
  if (wolkY === null)
    wolkY = hoogteVoor(m, GAST_SOM, Math.min(keyMid + vanKey, m.hoog - wolk.h / 2 - 2), false);
  uit.wolkY = wolkY;
  return uit;
}

function tekenHaak(b, i, lay) {
  var breed = drieCijfers(b);
  var dx = Math.max(lay.haakDx || 0, breed ? HAAK_DX3 : HAAK_DX);
  var h = b.haken[i], p = haakPlek(i, b.haken.length, dx, lay.haakY, lay.haakX);
  var leeg = h.blanco && h.sleutel === null;
  /* na de hulp van Els staat het goede getal als spookcijfer op het haakje */
  var spook = leeg && U.spook;
  var licht = U.licht === i || (U.buren && U.buren.lijst.indexOf(i) >= 0);
  var kl = 'hotbron' + (leeg ? ' hotspook' : '') + (licht ? ' hotgame aan' : '');
  /* het plaatje moet smal blijven, anders schuift de laag de rij uit elkaar */
  var groot = licht && !leeg ? ' style="font-size:' + (breed ? '1.35' : '1.7') + 'rem"'
            : (breed ? ' style="font-size:1rem"' : '');
  C.hotspots.maak({
    id: 'sl_h' + i, kamer: 'receptie', x: p.x, z: p.z, y: p.y,
    kind: 'drop', drop: 'haak', data: { i: i }, klas: kl, prio: 11,
    html: (h.sleutel !== null ? '<span class="ico">🔑</span>' : '') +
          '<span class="get"' + groot + '>' + (spook ? h.w : leeg ? '?' : h.w) + '</span>',
    titel: leeg ? (spook ? 'hier hoort ' + h.w : 'leeg haakje') : nrTekst(h.w),
    aan: function () { tikHaak(i); }
  });
}

/* welke twee plaatjes lichten op? De buren links en rechts, en aan de rand
   de twee plaatjes die er wél zijn: van twee getallen lees je de sprong af. */
function burenVan(b, i) {
  var n = b.haken.length, uit = [];
  if (i - 1 >= 0) uit.push(i - 1);
  if (i + 1 < n) uit.push(i + 1);
  if (uit.length < 2 && i + 2 < n) uit.push(i + 2);
  if (uit.length < 2 && i - 2 >= 0) uit.push(i - 2);
  uit.sort(function (a, c) { return a - c; });
  return { i: i, lijst: uit, links: uit[0], rechts: uit[1] };
}

/* het kleine getallenlijntje in het antwoordvakje: 10 … ? … 20 */
function burenTekst() {
  var b = bordNu(), q = U.buren;
  if (!q) return '';
  var rij = q.lijst.concat([q.i]).sort(function (a, c) { return a - c; });
  return rij.map(function (k) {
    var h = b.haken[k];
    if (k === q.i) return (h.blanco && h.sleutel === null) ? '?' : String(h.w);
    return String(h.w);
  }).join(' … ');
}

/* =====================================================================
   4. SPELEN
===================================================================== */
function wijsAan() {
  var s = sleutelNu();
  if (!s) return;
  C.snd.tik();
  C.ui.spreek(P.variant === 'kamers' ? verdieping(s.nummer) : String(s.nummer));
}

function tikHaak(i) {
  var b = bordNu(), h = b.haken[i], s = sleutelNu();
  if (!h) return;
  if (h.blanco && h.sleutel === null && s) { hang(i); return; }
  /* een plaatje met een getal: tikken laat het nummer groot zien en leest voor */
  U.licht = i;
  U.buren = null;
  C.snd.tik();
  teken();
  C.ui.spreek(P.variant === 'kamers' ? verdieping(h.w) : String(h.w));
}

function hang(i) {
  var b = bordNu(), h = b.haken[i], s = sleutelNu();
  if (!h || !s) return;
  if (h.sleutel !== null) { mis(i); return; }
  if (h.w === s.nummer) goed(i); else mis(i);
}

function goed(i) {
  var b = bordNu(), h = b.haken[i], s = sleutelNu();
  h.sleutel = s.gast;
  s.op = true;
  U.buren = null;
  U.licht = i;
  spookWeg();
  C.snd.munt();                                   /* rinkel: de sleutel hangt */
  C.snd.ja();
  C.state.tel(s.mis === 0, C.ui.nu() - (P.t0 || C.ui.nu()));
  P.t0 = C.ui.nu();
  var gast = s.gast;
  naarKamer(gast, true);
  P.nu++;
  var volgende = sleutelNu();
  teken();
  /* de gast die net zijn sleutel kreeg loopt weg: kort wolkje mee */
  C.ui.wolk(gast, { id: 'sl_af', door: 'sleutels', icoon: '💤', getal: s.nummer,
                    tekst: 'naar mijn kamer', klas: 'goed', hoog: 40, prio: 13 });
  setTimeout(function () { if (C) { C.ui.wolkWeg('sl_af'); C.wereld.vuil(); } }, 2600);
  if (volgende) { haalGast(); C.state.bewaar(); return; }
  klaar();
}

function mis(i) {
  var b = bordNu(), h = b.haken[i], s = sleutelNu();
  P.missers++;
  s.mis++;
  U.licht = null;
  U.buren = burenVan(b, i);
  C.snd.zacht();
  C.snd.terug();                                  /* de sleutel glijdt terug */
  teken();
  wiebel(i);
}

/* het haakje wiebelt even (css .wiggle), de sleutel blijft in je hand */
function wiebel(i) {
  var el = document.querySelector('[data-hot="sl_h' + i + '"]');
  if (!el) return;
  el.classList.remove('wiggle');
  void el.offsetWidth;
  el.classList.add('wiggle');
}

function klaar() {
  P.klaar = true;
  C.taakKlaar('sleutels', { sterren: 1 });
  C.snd.tover();
  C.state.bewaar();
  teken();
  /* de finale in de gang: daar hangen de plaatjes met de lampjes boven de deuren */
  C.wereld.naar('gang');
  if (window.Hotel) Hotel.render();
  C.ui.wolk('kist', { id: 'sl_klaar', door: 'sleutels', icoon: '⭐',
                      tekst: 'alle sleutels hangen', hoog: 24, klas: 'goed', prio: 13,
                      tik: function () { if (C) C.sluit(); } });
  setTimeout(function () { if (C && P && P.klaar) C.sluit(); }, 3400);
}

/* de naamplaatjes met het lampje boven de deuren in de gang: één plaatje per
   kamer, met de nummers van de sleutels die daar zijn opgehangen */
function deurPlaatjes() {
  var gang = C.wereld.kamer('gang');
  if (!gang || !gang.deurPunten) return;
  var per = {};
  P.sleutels.forEach(function (s) {
    if (!s.op) return;
    var g = C.state.gast(s.gast);
    if (!g || !g.kamer) return;
    per[g.kamer] = per[g.kamer] || { nrs: [], namen: [] };
    per[g.kamer].nrs.push(s.nummer);
    per[g.kamer].namen.push(s.naam);
  });
  gang.deurPunten.forEach(function (dp) {
    var q = per[dp.naar];
    if (!q) { C.wereld.getalTag({ x: 0, z: 0, kamer: 'gang' }, null, { id: 'sl_deur_' + dp.naar }); return; }
    C.wereld.getalTag({ x: dp.x, z: dp.z, kamer: 'gang' }, '💡 ' + q.nrs.join(' · '),
                      { id: 'sl_deur_' + dp.naar, y: 26,
                        titel: q.namen.join(' en ') + ' slaapt hier: ' + q.nrs.join(' en ') });
  });
}

/* ---------- buurvrouw Els: spookcijfers op de lege haakjes ----------
   Ze legt het goede getal als spookcijfer ÓP het haakje (dan schuift er
   niets in de rij) en zet de sprong in het hulpregeltje van de kaart. */
function spookWeg() { if (U) { U.spook = false; U.tip = null; } }
function hulp() {
  var b = bordNu();
  U.spook = true;
  U.tip = b.label === 'oneven' || b.label === 'even' ? 'om en om' : '+ ' + b.stap;
  C.state.zetGezien('sleutels_els');
  C.snd.brief();
  teken();
}

/* =====================================================================
   AANMELDEN
===================================================================== */
Games.register({
  id: 'sleutels',
  naam: 'Het sleutelbord',
  kamer: 'receptie',
  /* het bord hangt links aan de wand (x=1, z=56); met dz:6 en hoog:13 staat
     de knop op het scherm ruim links van de bel en ver van het prikbord en
     de gangdeur (GAMES-API.md 4). Zodra je speelt haalt de stekkerdoos hem
     weg: dan zijn de haakjes zelf de knoppen. */
  hotspot: { obj: 'sleutelbordz', icoon: '🔑', label: 'Sleutels', hoog: 13, dz: 6 },
  unlock: function (N) { return N >= 2; },
  stub: false,
  start: start,
  stop: stop,
  /* voor de speeltest: de generator en de nareken-functie */
  debug: {
    maak: function (N, band, dag, gasten, ronde) {
      return maakOpdracht(N, band, dag, gasten || [{ id: 'a', naam: 'A', soort: 'poes' },
        { id: 'b', naam: 'B', soort: 'puppy' }, { id: 'c', naam: 'C', soort: 'konijn' }], ronde);
    },
    controleer: controleer,
    bord: function () { return P; },
    plek: haakPlek,
    haken: aantalHaken,
    sleutels: aantalSleutels,
    /* de opstelling die het laatst gekozen is (X1): gewoon, stapel, naast of krap */
    opbouw: function () { return U ? U.opbouw : null; }
  }
});
})();
