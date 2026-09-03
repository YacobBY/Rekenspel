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
   De haakjes liggen op de schuine lijn x + z = 100: daar hebben twee
   plaatjes met 26 voxels verschil in (x - z) op het scherm 52 px tussen
   zich, ook op de kleinste schaal. Ze staan bovendien VÓÓR de gast en
   het meubilair (grote x+z), dus de laag schuift hén niet weg maar de
   rest om hen heen. */
var HAAK_SOM = 100, HAAK_DX = 13, HAAK_DX3 = 16, HAAK_Y = 48;
var GAST_PLEK = { x: 60, z: 68 };             /* vrij vakje voor de balie */
var KEY_PLEK = { x: 54, z: 80 };              /* de sleutel ligt naast zijn poot */
var ELS_PLEK = { x: 20, z: 78, y: 6 };
/* De hoogtes zijn zo gekozen dat op het scherm niets elkaar afdekt:
   de sommenkaart hangt boven de rij haakjes, de rij hangt boven het wolkje
   van de gast, en het wolkje net boven zijn kop (het dier zelf blijft dus
   te zien). Zie de meetlat in de speeltest: verticaal = (x + z) - 2y. */
/* De sommenkaart hangt boven de rij haakjes. Met de zin erboven (HOTEL.md 9)
   is het kaartje ~85 px hoog in plaats van ~45, dus hij hangt zeven stappen
   hoger: anders raakt zijn onderrand de haakjes en schuift de knoppenlaag de
   rij uit elkaar (gemeten met sleutels/plek.js: één stap is ~2 px). */
var KAART_HOOG = 62;                          /* sommenkaart boven het bord */
var WOLK_HOOG = 37, KEY_HOOG = 4;

var C = null;     /* de ctx */
var P = null;     /* de opdracht - hij woont in C.data(), dus hij blijft bewaard */
var U = null;     /* wat alleen op het scherm leeft: licht, buren, spook, tip */

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
   wereld en de receptie is bij dpr 1 maar ~90 voxels breed in beeld.
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
  U = { licht: null, buren: null, kaart: null, spook: false, tip: null };
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
  haalGast();
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
function haakPlek(i, n, dx) {
  var x = Math.round(50 + (dx || HAAK_DX) * (i - (n - 1) / 2));
  return { x: x, z: HAAK_SOM - x, y: HAAK_Y, kamer: 'receptie' };
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
  var b = bordNu(), s = sleutelNu(), i;

  /* 1. de nummerplaatjes aan de wand: sleep-doelen met hun getal erop */
  for (i = 0; i < b.haken.length; i++) tekenHaak(b, i);
  /* de plaatjes met het lampje boven de deuren in de gang horen bij de stand
     van het spel, dus tekenen we ze hier opnieuw: wisAlles() haalde ze net weg */
  deurPlaatjes();

  /* 2. één sommenkaartje aan het sleutelbord: de rij + de sleutel in je hand */
  /* de rij staat er nooit kaal (HOTEL.md 9): één gewone vraag erboven, met
     het pictogram vooraan op dezelfde regel */
  U.kaart = C.ui.somkaart('sleutelbordz', rijTekst(b), {
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

  /* 3. de gast met zijn sleutel: wolkje boven zijn kop, sleutel bij zijn poot.
        Ze hangen aan de PLEK bij de balie waar de gast naartoe loopt, niet aan
        het dier zelf: een wolkje dat aan een dier hangt houdt de kamer waarin
        het dier stond toen het wolkje werd gemaakt (ui.wolk/volg geven geen
        nieuwe kamer door), en dan staat het in de verkeerde ruimte. */
  if (s) {
    C.ui.wolk({ x: GAST_PLEK.x, z: GAST_PLEK.z, kamer: 'receptie' }, {
      /* pictogram, nummer EN woorden in hetzelfde wolkje (HOTEL.md 9). Het
         blijft kort: in portret is de receptie ~386 px breed en duwt een
         breder wolkje de bel van het hotel in de rij haakjes (192 px past
         nog, 204 px niet - sleutels/plek.js). De hele opdracht staat als zin
         op de sommenkaart. */
      id: 'sl_tag', door: 'sleutels', icoon: '🔑', getal: s.nummer,
      tekst: U.buren ? 'kijk bij de buren' : 'hang mij op',
      klas: U.buren ? 'hulp' : '', hoog: WOLK_HOOG, prio: 10
    });
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

function tekenHaak(b, i) {
  var breed = drieCijfers(b);
  var h = b.haken[i], p = haakPlek(i, b.haken.length, breed ? HAAK_DX3 : HAAK_DX);
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
    sleutels: aantalSleutels
  }
});
})();
