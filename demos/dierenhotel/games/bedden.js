/* ---------------------------------------------------------------
   games/bedden.js - BEDDEN OP RIJ.

   Het kernspel van het hotel (HOTEL.md 5, hotelwerk 1): de vloer van de
   kamer wordt een bedplan. Uit de dekenkist komen bedjes en die leg je in
   NETTE RIJEN: elke rij is zo breed als de kamer, en jij zoekt uit hoeveel
   rijen er nodig zijn.

   Alles gebeurt ín de kamer (HOTEL.md 9): geen rekenblad ernaast.
     * de dekenkist is een sleepbron met de teller erop: precies zoveel
       bedjes als er gasten komen (net als de zak van de voerkar);
     * elke rij ligt als strookje op de vloer met de bedjes die er al in
       liggen, spookbedjes voor de plekjes die nog leeg zijn, en het aantal
       als cijfer op de rij;
     * de som schrijft zichzelf: een sommenkaart aan de kamer telt de volle
       rijen mee ("2 x 4 = 8");
     * fout? een wolkje met pictogram en getal ("🛏 +2"), nooit een lap
       tekst, nooit een rood kruis, nooit een klok;
     * kamerhulp Wolkje legt na twee pogingen één rij voor met spookbedjes
       en een spookcijfer.

   Wat je hier neerlegt blijft staan: elk bedje dat op de vloer past wordt
   via ctx.wereld.voegBed een ECHT bed, en bedden zijn de harde gastenlimiet
   (HOTEL.md 2). Dit is dus het spel dat het hotel laat groeien.

   De getallen komen uit ctx.state.sommen.tafel(band), nooit uit een eigen
   ladder (GAMES-API.md 3.5):
     groep 3  rijtjes t/m 20, sprongen van 1, 2, 5 en 10 (geen tafels)
     groep 4  alleen de tafels 1, 2, 3, 4, 5 en 10
     groep 5  alle tafels t/m 10, plus de SCHUIFWAND: de rijen in twee
              stukken rekenen (3 rijen van 7 = 2 x 7 + 1 x 7)
   Wat de KAMER begrenst is de grootte van de opdracht. Er passen drie rijen
   plus een lege reserverij op de vloer, en er passen maar zoveel bedden in
   een kamer als het vloerraster toelaat (capaciteit()). De opdracht belooft
   dus nooit meer bedden dan er echt bij kunnen: eerst zakt de tafel naar de
   eerstvolgende die de band WEL kent, daarna het aantal rijen. Is kamer 1
   vol, dan lopen we door naar de volgende slaapkamer; zit het hele hotel
   vol, dan zegt het spel dat vriendelijk ("🛏 vol ✓") en belooft het niets -
   en zonder nieuw bed is er ook geen ster.

   Over het neerzetten: de wereld is isometrisch en de knoppenlaag schuift
   knoppen die elkaar afdekken uit elkaar (GAMES-API.md 4). Een rij zou dan
   niet meer op een rij liggen. Daarom rekenen we alle plekken in SCHERM-
   pixels uit en zetten we ze om naar voxels met de schaal van dat moment
   (die hangt af van de kamerbreedte en de scherpte van het scherm).
---------------------------------------------------------------- */
(function () {
'use strict';

var KAMER = 'kamer1';       /* waar het icoontje hangt */
var K = KAMER;              /* waar we nu spelen (kamer2 als kamer1 vol is) */
var MAX_RIJEN = 3;          /* zoveel rijen passen er op deze vloer */
var MAX_PER_RIJ = 10;       /* zoveel bedjes passen er in één strookje */
/* Sinds K1 is de vloer 1,5x groter (114 x 114) en levert het vloerraster 19
   plekjes in plaats van 6. De OPDRACHT blijft even groot: rijen x bedden per
   rij komt uit ctx.state.sommen.tafel en die sommen mogen niet veranderen
   (HOTEL.md 5). We rekenen daarom met hooguit MAX_CAP plekjes per opdracht -
   de extra vloer is beenruimte, geen grotere som. (Er passen wél meer BEDDEN
   in een kamer, en dat mag: de gastenpool is 9 lang, dus N verandert niet.)
   Wil je ooit een rij van 6 of 7 (band 5, 7 x 6): zet MAX_CAP hoger EN
   MAX_PER_RIJ / MAX_RIJEN erbij, en meet de rijen na - 6 rijen x rijStap (24
   voxels op een tablet) is 144 voxels en dat past niet meer in 114. */
var MAX_CAP = 6;
var GOLF = 260;             /* ms tussen twee bedden van de deken-golf */

/* schermafstanden (px) tussen de kaartjes: een knop is 48 px hoog */
var STAP_PX = 50;           /* van rij naar rij, omlaag (een knop is 48 hoog) */
var BOVEN_PX = 80;          /* de sommenkaart boven de bovenste rij */
var ONDER_PX = 66;          /* de dekenkist onder de onderste rij */
var KNOP_PX = 48;           /* een tikdoel (style.css .hot) */
/* Een sommenkaart MET zin is ~92 px hoog, niet 46 (HOTEL.md 9: elke kaart
   draagt één gewone zin, en die breekt op een telefoon af naar twee regels).
   maxStroken() rekende met 46 en reserveerde dus 46 px te weinig; op een
   liggende telefoon (kader 320 px) koos hij daardoor VIER strookjes, en dan
   klemt de knoppenlaag de kaart bovenop de bovenste rij. Gemeten op
   844 x 390: bd_som over bd_rij0 heen, 123 x 26 px, en een sleep van de
   dekenkist naar het HART van rij 0 kwam niet aan (het hart lag onder de
   kaart, dus elementFromPoint gaf de kaart). Met de echte hoogte erin komt
   dat kader op drie strookjes en is de rij weer een heel sleepdoel. */
var KAART_PX = 92;
/* hart-op-hart afstand die de kaart en de kist minimaal nodig hebben om de
   buitenste rij niet te raken (halve kaart + halve knop + 4 px lucht) */
var MIN_BOVEN = (KAART_PX + KNOP_PX) / 2 + 4;   /* 74 */
var MIN_ONDER = KNOP_PX + 4;                    /* 52 */
var goot = 132;             /* naar de zijkant, langs de rijen heen; wordt
                               na het tekenen bijgesteld op de echte breedte
                               van een strookje (die hangt van de tafel af) */

var C = null;               /* de ctx */
var D = null;               /* mijn laatje in de opslag: ctx.data() */
var T = [];                 /* eigen tijdertjes (alleen animatie) */
var t0 = 0;
var bezig = false;          /* tijdens de golf even geen tikken */
var kaart = null;           /* de sommenkaart */
var bewaarT = null, maatT = null, opMaat = null, maatAf = null;

function tik(fn, ms) { T.push(setTimeout(fn, ms)); }
function stopTikken() { T.forEach(clearTimeout); T = []; }
function bewaarStraks() {
  clearTimeout(bewaarT);
  bewaarT = setTimeout(function () { if (C) C.state.bewaar(); }, 400);
}

/* =====================================================================
   DE SCHAAL: hoeveel schermpixels is één voxel op dit moment?
   world.js tekent met een gehele voxelmaat (g) die met de kamerbreedte en
   de scherpte van het scherm meeschaalt; op een scherpe tablet is een kamer
   dus half zo groot in css-pixels als op een gewone laptop. Zonder deze
   omrekening liggen de rijen op de ene tablet netjes en op de andere niet.
===================================================================== */
var _sch = null, _schT = 0;
function schaal() {
  var nu = Date.now();
  if (_sch && nu - _schT < 250) return _sch;      /* even onthouden: teken()
                                                     vraagt hem tien keer */
  var g = 2, dp = 1, S = 2, H = 2, w;
  /* g EN de tekendichtheid komen uit world.js: het canvas staat vaak op een
     hogere dichtheid dan het scherm zelf (world.js maatVan), dus met
     devicePixelRatio zou een rij bedjes op de verkeerde plek liggen. */
  try { w = window.World && World.debug(); if (w && w.g) g = w.g; if (w && w.dpr) dp = w.dpr; } catch (e) {}
  if (!dp) { try { dp = Math.min(3, window.devicePixelRatio || 1); } catch (e) { dp = 1; } }
  try { if (window.Art && Art.kit) { S = Art.kit.S || S; H = Art.kit.HG || H; } } catch (e) {}
  _schT = nu;
  _sch = { u: S * g / dp,          /* px per voxel in (x - z): zijwaarts */
           v: (S / 2) * g / dp,    /* px per voxel in (x + z): omlaag     */
           h: H * g / dp };        /* px per voxel omhoog                 */
  return _sch;
}
/* hoe hoog is het wereldkader nu? (korte kaders: één rij minder, en de
   kaartjes eromheen schuiven dichter naar de rijen toe) */
function frameHoogte() {
  var e = document.getElementById('world');
  return (e && e.clientHeight) || 480;
}
/* Hoeveel stroken passen er in dit kader? Een strook is STAP_PX hoog en de
   sommenkaart en de dekenkist moeten er in hun kleinste maat bij. Sinds K1 is
   het kader wat lager (de kamers werden breder, dus vullen ze het kader eerder
   in de breedte - world.js pasKader), dus rekenen we het uit in plaats van een
   vaste grens van 430 px te gebruiken. M1c heeft de reservering voor de kaart
   op haar echte hoogte gezet (zie KAART_PX); de uitkomst per kader staat
   hieronder in de functie. */
function maxStroken() {
  /* wat er BUITEN de rijen nog moet: de kaart boven de bovenste rij
     (MIN_BOVEN hart-op-hart, dus MIN_BOVEN + halve kaart - halve knop boven
     haar bovenrand), de kist onder de onderste rij, de 48 px van de rij zelf
     en 4 px lucht. Met de echte kaarthoogte is dat 200 px:
       kader 200 -> 3 (de ondergrens), 228 -> 3, 282 -> 3, 320 -> 3,
             379 -> 4, 405 -> 4, 478 -> 4, 715 -> 4. */
  var vast = (MIN_BOVEN + KAART_PX / 2 - KNOP_PX / 2) + MIN_ONDER + KNOP_PX + 4;
  var over = frameHoogte() - vast;
  return Math.max(3, Math.min(MAX_RIJEN + 1, Math.floor(over / STAP_PX) + 1));
}
function marges() {
  var h = frameHoogte(), n = aantalStroken();
  var rij = (n - 1) * STAP_PX + KNOP_PX;             /* wat de rijen innemen */
  var over = Math.max(0, h - rij - 4);
  var nodig = (MIN_BOVEN + KAART_PX / 2 - KNOP_PX / 2) + MIN_ONDER;
  var extra = Math.max(0, over - nodig);
  /* Is er meer ruimte dan nodig, dan mag het ruimer - tot BOVEN_PX/ONDER_PX,
     precies de maten van vóór M1c. Op een staand kader (478 px, vier
     strookjes) komt daar 80 / 66 uit: exact hetzelfde als eerst. */
  return { boven: Math.min(BOVEN_PX, MIN_BOVEN + extra * 0.6),
           onder: Math.min(ONDER_PX, MIN_ONDER + extra * 0.4) };
}

/* ---------- de sommenkaart écht vrij zetten (M1c) ----------
   marges() rekent met KAART_PX, maar de kaart is niet altijd 92 px hoog: op
   een smal kader krimpt hij naar 170 px breed en breekt de zin naar drie
   regels (gemeten 129 px op 320 x 640 en op 360 x 740). Daarom meten we na
   het tekenen na of hij de bovenste rij raakt - net zoals ui.js dat met het
   cijferpad doet (kaartVrij) - en tillen hem dan precies genoeg op. Lukt dat
   niet, omdat er boven de rij simpelweg geen kader meer is (802 x 293: kader
   223 px, kaart 109 + rijen 98 + kist 48 = 255 px nodig), dan gaat de kaart
   ERNAAST staan: links van de bovenste rij, op dezelfde hoogte. Dat is
   dezelfde uitweg die games/sleutels.js in X1 kreeg.
   ZOWEL de rij als de kaart zijn `vast` hotspots, dus de knoppenlaag schuift
   ze niet voor elkaar weg; alleen wíj kunnen dit oplossen. */
var somLift = 0, somNaast = false, somT = null, somRonde = 0, somOverBoven = 0;
function somOpnieuw() {
  somLift = 0; somNaast = false; somRonde = 0; somOverBoven = 0;
  clearTimeout(somT); somT = null;
}
function somPlekNaast() {
  var el = document.querySelector('[data-hot="bd_rij0"]');
  var k = document.querySelector('[data-hot="bd_som"]');
  var rw = (el && el.offsetWidth) || 123;
  var kw = (k && k.offsetWidth) || 187;
  return plekPx(0, -(rw / 2 + 8 + kw / 2), 0);
}
/* Hooguit drie meetrondes per kadermaat, en de teller staat BUITEN teken():
   teken() vraagt na elke hertekening om een meting, dus zonder teller zou
   ronde 0 zichzelf blijven herhalen.
     ronde 0  raakt de kaart de rij? -> precies genoeg optillen
     ronde 1  nog steeds? -> dan is er boven de rij geen kader meer: ERNAAST
     ronde 2  is ernaast SLECHTER (een smal kader klemt de kaart terug tegen
              de linkerrand)? -> dan toch weer erboven, met de lift
   Daarna staat het; somOpnieuw() zet de teller op nul bij een nieuw kader,
   een nieuwe opdracht of een nieuwe start. */
function somVrijStraks() {
  clearTimeout(somT);
  if (somRonde > 2) return;
  if (C && C.wereld.vuil) C.wereld.vuil();
  somT = setTimeout(function () { somT = null; somVrij(somRonde++); }, 90);
}
function somOverlap() {
  var k = document.querySelector('[data-hot="bd_som"]');
  var r0 = document.querySelector('[data-hot="bd_rij0"]');
  if (!k || !r0) return null;
  var a = k.getBoundingClientRect(), c = r0.getBoundingClientRect();
  if (!a.height || !c.height) return null;
  var dx = Math.min(a.right, c.right) - Math.max(a.left, c.left);
  if (dx <= 1) return 0;                       /* naast elkaar: niets erover */
  return Math.max(0, a.bottom - c.top + 4);
}
function somVrij(ronde) {
  if (!C || !D || D.klaar) return;
  var over = somOverlap();
  if (over === null) return;
  if (ronde === 0) {
    if (over <= 0) { somRonde = 9; return; }   /* de rij is een heel sleepdoel */
    somLift += Math.ceil(over);
    teken();
    return;
  }
  if (ronde === 1) {
    if (over <= 0) { somRonde = 9; return; }
    somOverBoven = over;                       /* dit haalden we mét de lift */
    somNaast = true;
    teken();
    return;
  }
  /* ronde 2: ernaast gemeten. Was het slechter, dan gaan we terug. */
  if (over > 0 && over >= somOverBoven) { somNaast = false; teken(); }
}

/* De diagonale stap tussen twee rijen, in voxels. NIET afronden op hele
   voxels: de voxelmaat is sinds K1 vaak een breuk (world.js maatVan), en met
   een hele voxelstap komen de strookjes dan 50, 50, 51 px onder elkaar in
   plaats van precies STAP_PX. Met een breuk staan ze op de pixel gelijk. */
function rijStap() {
  var s = schaal();
  return Math.max(STAP_PX / (2 * s.v), 24);
}
function rijPlek(r) {
  var stap = rijStap(), n = aantalStroken();
  /* de rijen liggen op de diagonaal, netjes midden op de vloer van DEZE
     kamer (sinds K1 is die 114 x 114 in plaats van 76 x 76) */
  var breed = ((C && C.wereld.kamer(K)) || {}).w || 114;
  var begin = Math.max(2, (breed - (n - 1) * stap) / 2);
  return { kamer: K, x: begin + r * stap, z: begin + r * stap };
}
/* een plek die op het scherm dx px opzij en dy px omhoog van rij r ligt */
function plekPx(r, dx, dy) {
  var s = schaal(), p = rijPlek(r), d = dx / (2 * s.u);
  return { kamer: K, x: p.x + d, z: p.z - d, y: 6 + (dy || 0) / s.h };
}

/* =====================================================================
   HOEVEEL BEDDEN PASSEN ER ECHT NOG BIJ?
   De opdracht mag nooit meer bedden beloven dan de vloer kan dragen, want
   elk bedje wordt straks een ECHT bed. Een bed dat neergezet wordt haalt de
   vakjes binnen 18 voxels van zich af uit het vloerraster (rooms.js), dus
   het aantal vrije vakjes is niet het aantal bedden. We spelen de greedy
   plaatsing van besteVak() hier droog na en tellen hoeveel er echt passen.
===================================================================== */
function capaciteit(kamerId) {
  return Math.min(MAX_CAP, ruweCapaciteit(kamerId));
}
function ruweCapaciteit(kamerId) {
  var vrij = C.wereld.slots(kamerId, 'vrij').map(function (v) { return { x: v.x, z: v.z }; });
  var bedden = C.wereld.slots(kamerId, 'bed').map(function (b) { return { x: b.x, z: b.z }; });
  var n = 0, i, j, dm, d, best, beste, p;
  while (vrij.length) {
    beste = -1; best = -1;
    for (i = 0; i < vrij.length; i++) {
      dm = 1e9;
      for (j = 0; j < bedden.length; j++) {
        d = Math.abs(bedden[j].x - vrij[i].x) + Math.abs(bedden[j].z - vrij[i].z);
        if (d < dm) dm = d;
      }
      if (dm > best) { best = dm; beste = i; }
    }
    if (beste < 0) break;
    p = vrij[beste];
    bedden.push(p);
    n++;
    vrij = vrij.filter(function (v) {
      return Math.abs(v.x - p.x) + Math.abs(v.z - p.z) >= 18;
    });
  }
  return n;
}

/* In welke kamer spelen we? Het liefst de kamer van het icoontje; is die vol,
   dan lopen we door naar de volgende slaapkamer die nog plek heeft. Zo blijft
   de groeilus van het hotel doorlopen (HOTEL.md 2). */
function kiesKamer() {
  var beste = { kamer: KAMER, cap: capaciteit(KAMER) };
  if (beste.cap >= 2) return beste;
  C.wereld.kamers().forEach(function (r) {
    if (r.id === KAMER || !C.wereld.slots(r.id, 'bed').length) return;
    var c = capaciteit(r.id);
    if (c > beste.cap) beste = { kamer: r.id, cap: c };
  });
  return beste;
}

/* =====================================================================
   DE OPDRACHT: rijen x bedden-per-rij, uit ctx.state.sommen.tafel
===================================================================== */
function opdracht(cap) {
  var band = C.state.band();
  var s = C.state.sommen.tafel(band) || {};
  var set = (s.tafels && s.tafels.length ? s.tafels : [1, 2, 5, 10]).slice()
              .sort(function (a, b) { return a - b; });
  var perRij = Math.max(1, Math.min(MAX_PER_RIJ, s.a || 2));
  var rijen = Math.max(1, Math.min(MAX_RIJEN, s.b || 2));
  /* De kamer is de baas. Een rij kan nooit breder zijn dan wat er nog past,
     dus zakken we naar de eerstvolgende tafel die de band WEL kent (nooit een
     zelfbedacht getal, IDEAS.md); daarna knijpen we het aantal rijen. */
  var i, kleiner;
  while (perRij > cap) {
    kleiner = 0;
    for (i = 0; i < set.length; i++) if (set[i] < perRij && set[i] <= cap) kleiner = set[i];
    if (!kleiner) { perRij = Math.max(1, Math.min(perRij, cap)); break; }
    perRij = kleiner;
  }
  rijen = Math.max(1, Math.min(rijen, Math.floor(cap / perRij) || 1,
                                MAX_RIJEN, maxStroken() - 1));
  return { band: band, perRij: perRij, rijen: rijen, doel: rijen * perRij, cap: cap };
}
function signatuur(o) {
  return [o.band, C.state.dag(), C.state.N(), K, o.cap, o.rijen, o.perRij].join('|');
}
function nieuweOpdracht(o, sig) {
  somOpnieuw();               /* andere opdracht = andere rijen = opnieuw meten */
  D.sig = sig;
  D.kamer = K;
  D.cap = o.cap;
  D.band = o.band;
  D.rijen = o.rijen;
  D.perRij = o.perRij;
  D.doel = o.doel;
  D.rij = [];                                  /* aantal bedjes per rij */
  D.missers = 0;
  D.klaar = false;
  D.nieuw = 0;
  D.over = 0;
  D.spook = false;
  D.fase = 'leg';            /* leg -> feest -> af (of 'vol') */
  D.vol = 0;
  /* de schuifwand hoort bij groep 5 (verdeelstrategie, HOTEL.md 5) */
  D.wand = o.band >= 5 && o.rijen >= 2 ? o.rijen - 1 : 0;
}

/* =====================================================================
   DE RIJEN
===================================================================== */
function aantalStroken() { return Math.min(MAX_RIJEN + 1, (D ? D.rijen : 1) + 1); }
function rijTel(r) { return (D.rij && D.rij[r]) || 0; }
function totaal() {
  var n = 0, r;
  for (r = 0; r < aantalStroken(); r++) n += rijTel(r);
  return n;
}
function volleRijen() {
  var n = 0, r;
  for (r = 0; r < aantalStroken(); r++) if (rijTel(r) === D.perRij) n++;
  return n;
}
function eersteLegeRij() {
  var r;
  for (r = 0; r < aantalStroken(); r++) if (rijTel(r) < D.perRij) return r;
  return -1;
}
function kistOver() { return Math.max(0, D.doel - totaal()); }

function legIn(r) {
  if (!C || bezig || D.klaar) return;
  if (rijTel(r) >= D.perRij) {                 /* deze rij is al vol */
    C.snd.zacht();
    wolk('bd_op', plekPx(r, -goot, 0), { icoon: '🛏', getal: D.perRij, klas: 'hulp' });
    tik(function () { if (C) C.ui.wolkWeg('bd_op'); }, 1800);
    return;
  }
  if (kistOver() <= 0) {                       /* de kist is leeg */
    C.snd.zacht();
    wolk('bd_op', plekPx(aantalStroken() - 1, 0, -marges().onder), { icoon: '🧺', getal: 0, klas: 'hulp' });
    tik(function () { if (C) C.ui.wolkWeg('bd_op'); }, 1800);
    return;
  }
  D.rij[r] = rijTel(r) + 1;
  D.laatste = r;
  C.ui.wolkWeg('bd_op');
  C.ui.wolkWeg('bd_fout');
  C.snd.plop(1);
  bewaarStraks();
  teken();
}
function terug() {
  if (!C || bezig || D.klaar) return;
  var r = D.laatste, i;
  if (r === undefined || !rijTel(r)) {
    r = -1;
    for (i = aantalStroken() - 1; i >= 0; i--) if (rijTel(i)) { r = i; break; }
  }
  if (r < 0) { C.snd.zacht(); return; }
  D.rij[r] = rijTel(r) - 1;
  D.laatste = r;
  C.ui.wolkWeg('bd_fout');
  C.snd.terug();
  bewaarStraks();
  teken();
}

/* =====================================================================
   TEKENEN: alles hangt in de kamer
===================================================================== */
/* Eén regel voor enkelvoud en meervoud: mv(1, 'bed', 'bedden') geeft
   "1 bed", mv(3, ...) geeft "3 bedden". Zonder dit stond er "van 1 bedden"
   op de kaart zodra een rij één bedje breed is (band 3, kleine kamer). */
function mv(n, enk, meerv) { return n + ' ' + (n === 1 ? enk : meerv); }

function wolk(id, obj, o) {
  o = o || {};
  o.id = id;
  o.door = 'bedden';
  if (o.hoog === undefined) o.hoog = 6;
  return C.ui.wolk(obj, o);
}

/* De kamer even rustig maken: de knoppen van het hotel die precies op onze
   rijen vallen (een vrij bed, de speelmand, het bakje) zeggen tijdens dit
   spel niets nuttigs en zouden de rijen uit elkaar duwen. stop() zet ze met
   Hotel.render() weer terug. */
function rustigeKamer() {
  if (!C) return;
  ['bed_' + K + '_bed1', 'bed_' + K + '_bed2',
   'mand_' + K, 'bak_' + K + '_bak'].forEach(function (id) { C.hotspots.weg(id); });
  C.wereld.kamerMeubels(K).forEach(function (m) {
    if (m.soort === 'bed') C.hotspots.weg('bed_' + K + '_' + m.id);
  });
}

/* het strookje van één rij: de bedjes die er liggen, spookbedjes voor de
   plekjes die nog leeg zijn, en het aantal als cijfer op de rij */
function strookHtml(r) {
  var n = rijTel(r), i, spook = D.spook && r === eersteLegeRij() && !D.klaar;
  /* bij tien bedjes in een rij wordt het strookje anders te breed voor een
     telefoon in portret; dan tekenen we de bedjes een tikje kleiner */
  var s = '<span class="ico" style="font-size:' + (D.perRij >= 10 ? '.8rem' : '.95rem') + '">';
  for (i = 0; i < n; i++) s += D.klaar ? '🛌' : '🛏';
  for (; i < D.perRij; i++) s += '<span style="opacity:' + (spook ? '.62' : '.22') + '">🛏</span>';
  return s + '</span><span class="get">' + n + '</span>';
}

function teken() {
  if (!C || !D) return;
  var r, p, laatste = aantalStroken() - 1, vol = volleRijen();
  rustigeKamer();
  /* Na het feest halen we de strookjes weg: dan zie je de kamer zoals hij
     nu is - vol met echte bedden. Dat is de beloning. */
  if (D.fase === 'af') { alleenSom(); return; }

  for (r = 0; r < aantalStroken(); r++) {
    p = rijPlek(r);
    (function (rr) {
      C.hotspots.maak({
        id: 'bd_rij' + rr, kamer: K, x: p.x, z: p.z, y: 6,
        kind: 'drop', drop: 'bedrij', data: { rij: rr },
        klas: 'hotbron', html: strookHtml(rr), prio: 13,
        /* vast = dit strookje wijkt nooit uit; de andere knoppen (ook die
           van het hotel) schuiven eromheen. Zo blijft een rij een rij, op
           elk scherm en bij elke voxelmaat (hits.js). */
        vast: true,
        titel: 'rij ' + (rr + 1) + ': ' + rijTel(rr) + ' van ' + D.perRij,
        aan: function () { legIn(rr); }
      });
    })(r);
  }
  for (r = aantalStroken(); r < MAX_RIJEN + 2; r++) C.hotspots.weg('bd_rij' + r);
  /* hoe breed is een strookje echt? daarnaast passen de andere kaartjes */
  var el = document.querySelector('[data-hot="bd_rij0"]');
  goot = Math.max(88, ((el && el.offsetWidth) || 160) / 2 + 52);

  /* de dekenkist: sleepbron met de teller erop, aan het voeteneind */
  var kp = plekPx(laatste, 0, -marges().onder);
  C.hotspots.bron(kp, {
    id: 'bd_kist', icoon: '🧺', aantal: kistOver(), hoog: kp.y,
    klas: D.klaar ? 'leeg' : '', prio: 12, kamer: K,
    titel: 'dekenkist met ' + mv(kistOver(), 'bedje', 'bedjes'),
    tik: function () { if (!D.klaar) C.snd.tik(); },
    sleep: {
      dropSel: '[data-drop="bedrij"]',
      ghostHTML: function () { return '<div style="font-size:34px">🛏</div>'; },
      canDrag: function () { return !bezig && !D.klaar && kistOver() > 0; },
      onDrop: function (t) { legIn(+t.getAttribute('data-h-rij')); },
      onTap: function () { C.snd.tik(); }
    }
  });

  /* eentje terug in de kist */
  if (!D.klaar && totaal() > 0) {
    var up = plekPx(laatste, -goot, 0);
    C.hotspots.maak({
      id: 'bd_undo', kamer: K, x: up.x, z: up.z, y: up.y,
      icoon: '↩', klas: 'hotwolk', prio: 11, titel: 'eentje terug in de kist',
      aan: terug
    });
  } else C.hotspots.weg('bd_undo');

  /* de som schrijft zichzelf: zoveel volle rijen x zoveel per rij */
  if (!D.klaar) {
    var sp = somNaast ? somPlekNaast() : plekPx(0, 0, marges().boven + somLift);
    kaart = C.ui.somkaart(sp, (vol || '?') + ' × ' + D.perRij + ' =',
      { id: 'bd_som', door: 'bedden', pad: false, hoog: sp.y, kamer: K,
        /* één gewone zin boven de som, met het pictogram vooraan op
           dezelfde regel (HOTEL.md 9): een kale "? × 4 =" leest een kind
           van zes niet. */
        icoon: '🛏',
        /* Deze kaart telt zichzelf mee (pad: false): het antwoordvakje laat
           zien hoeveel bedden er NU liggen. Een vraag ("Hoeveel bedden zijn
           dat?") zou dus boven een som staan die halverwege een ander getal
           laat zien; daarom beschrijft de tweede regel de stand. */
        regel: ['Leg ' + mv(D.rijen, 'rij', 'rijen') + ' van ' +
                mv(D.perRij, 'bed', 'bedden'), 'Zo veel bedden staan er nu'] });
    if (kaart) kaart.zet(vol ? vol * D.perRij : '');
    /* nameten: raakt de kaart de bovenste rij? (zie somVrij hierboven) */
    somVrijStraks();
  }

  /* de opdracht hangt boven de gast die op een bed wacht: het pictogram staat
     in hetzelfde wolkje als zijn woorden (HOTEL.md 9) */
  var wacht = C.wereld.dieren().filter(function (g) { return !g.bed; })[0];
  var wd = wacht ? C.wereld.dier(wacht.id) : null;
  if (wd && wd.kamer === K && !D.klaar)
    wolk('bd_wolk', wacht.id, { icoon: '🛏', getal: D.doel,
                                tekst: D.doel === 1 ? 'bed maken' : 'bedden maken',
                                hoog: 52, prio: 12 });
  else C.ui.wolkWeg('bd_wolk');

  /* de schuifwand van groep 5: de rijen in twee stukken rekenen */
  if (D.wand && !D.klaar) {
    var a = D.wand, b = D.rijen - D.wand;
    var wp = plekPx(D.wand, goot, STAP_PX / 2);
    C.hotspots.maak({
      id: 'bd_wand', kamer: K, x: wp.x, z: wp.z, y: wp.y,
      klas: 'hotwolk hulp', prio: 11,
      html: '<span class="ico">🚧</span><span class="get" style="font-size:.95rem;line-height:1.02">' +
            (a * D.perRij) + '<br>+' + (b * D.perRij) + '</span>',
      titel: a + ' × ' + D.perRij + ' + ' + b + ' × ' + D.perRij,
      aan: schuif
    });
  } else C.hotspots.weg('bd_wand');

  /* klaar? tik op de deur van de kamer, of op dit pootje rechtsboven */
  if (!D.klaar) {
    var kl = plekPx(0, goot, 56);
    C.hotspots.maak({
      id: 'bd_klaar', kamer: K, x: kl.x, z: kl.z, y: kl.y,
      icoon: '🐾', getal: D.doel, klas: 'hotwolk goed', prio: 14,
      titel: D.doel === 1 ? '1 gast mag erin' : D.doel + ' gasten mogen erin', aan: check
    });
  } else C.hotspots.weg('bd_klaar');

  /* kamerhulp na twee pogingen */
  if (D.missers >= 2 && !D.klaar) {
    var hp = plekPx(laatste, -goot, -STAP_PX);
    C.hotspots.maak({
      id: 'bd_hulp', kamer: K, x: hp.x, z: hp.z, y: hp.y,
      icoon: '🐑', klas: 'hotwolk hulp', prio: 11, titel: 'kamerhulp Wolkje',
      aan: hulp
    });
  } else C.hotspots.weg('bd_hulp');

  C.wereld.vuil();
}

/* de opgeruimde eindstand: alleen de sommenkaart en één wolkje */
function alleenSom() {
  var r;
  for (r = 0; r < MAX_RIJEN + 2; r++) C.hotspots.weg('bd_rij' + r);
  ['bd_kist', 'bd_undo', 'bd_wand', 'bd_klaar', 'bd_hulp'].forEach(function (id) {
    C.hotspots.weg(id);
  });
  C.ui.wolkWeg('bd_wolk');
  wolk('bd_goed', plekPx(0, goot, 0), D.nieuw
    ? { icoon: '🛏', getal: '+' + D.nieuw, klas: 'goed', prio: 14,
        tik: function () { C.sluit(); } }
    : { icoon: '🛏', tekst: 'vol ✓', klas: 'goed', prio: 14,
        tik: function () { C.sluit(); } });
  C.wereld.vuil();
}

function schuif() {
  if (!D.wand) return;
  D.wand = D.wand - 1 < 1 ? D.rijen - 1 : D.wand - 1;
  C.snd.tik();
  bewaarStraks();
  teken();
}

/* de deur van deze kamer, alleen uit de gedocumenteerde kamerdata */
function deurPlek() {
  var r = C.wereld.kamer(K) || {};
  var d = (r.deuren || [])[0];
  var w = r.w || 114, dp = r.d || 114;
  if (!d) return { x: w / 2, z: 0, ix: w / 2, iz: 10 };
  var m = d.at + (d.breed || 12) / 2;
  if (d.wand === 'z') return { x: Math.min(m, w - 2), z: 0, ix: Math.min(m, w - 2), iz: 10 };
  return { x: 0, z: Math.min(m, dp - 2), ix: 10, iz: Math.min(m, dp - 2) };
}

/* =====================================================================
   DE CONTROLE - vriendelijk, en nooit een stap terug
===================================================================== */
function check() {
  if (!C || !D || bezig || D.klaar) return;
  var r, n, oneven = -1, vol = 0, leeg = -1, over = kistOver();
  for (r = 0; r < aantalStroken(); r++) {
    n = rijTel(r);
    if (n === D.perRij) vol++;
    else if (n > 0) { if (oneven < 0) oneven = r; }
    else if (leeg < 0) leeg = r;
  }
  if (!over && oneven < 0 && vol === D.rijen) { gelukt(); return; }

  /* ---- zachte hulp: pictogram + getal, precies bij het plekje dat het is ---- */
  D.missers++;
  var mik = null, ic = '🛏', getal = '';
  if (oneven >= 0) {                       /* een scheve rij: die vullen we aan */
    mik = plekPx(oneven, -goot, 0);
    getal = '+' + (D.perRij - rijTel(oneven));
  } else if (over > 0 && leeg >= 0) {      /* er kan nog een hele rij bij */
    mik = plekPx(leeg, -goot, 0);
    getal = '+' + Math.min(over, D.perRij);
  } else if (over > 0) {                   /* nog bedjes in de kist */
    mik = plekPx(aantalStroken() - 1, -goot, -marges().onder);
    getal = '+' + over;
  } else {                                 /* een rij te veel: er mag er een terug */
    mik = plekPx(Math.max(0, vol - 1), -goot, 0);
    ic = '↩';
    getal = '-' + Math.max(1, (vol - D.rijen) * D.perRij);
  }
  C.snd.zacht();
  teken();
  wolk('bd_fout', mik, { icoon: ic, getal: getal, klas: 'hulp', prio: 14 });
  if (wachtInDeuropening()) tik(function () { if (C) teken(); }, 2000);
  bewaarStraks();
  if (D.missers === 2) tik(hulp, 900);
}

/* het laatste dier gaat in de deuropening wachten - geduldig, nooit boos */
function wachtInDeuropening() {
  var zonder = C.wereld.dieren().filter(function (g) { return !g.bed; });
  if (!zonder.length) return null;
  var g = zonder[zonder.length - 1], p = deurPlek();
  C.wereld.reis(g.id, K, { x: p.ix, z: p.iz, na: 'wacht' });
  return g;
}

/* =====================================================================
   GELUKT: de dekens vouwen open, de bedden worden ECHT
===================================================================== */
function gelukt() {
  D.klaar = true;
  D.fase = 'feest';
  D.spook = false;
  bezig = true;
  C.state.tel(!D.missers, C.ui.nu() - t0);
  C.snd.tover();
  C.ui.wolkWeg('bd_fout');
  spookWeg();
  somAf();
  D.nieuw = 0;
  D.over = D.doel;
  teken();
  wolk('bd_goed', plekPx(0, goot, 0), { icoon: '⭐', getal: D.doel, klas: 'goed', prio: 14 });
  bouwBedden(D.doel, function (gelegd) {
    bezig = false;
    if (!C) return;
    D.nieuw = gelegd.length;
    D.over = Math.max(0, D.doel - gelegd.length);
    /* Een ster hoort bij bedden die er echt bij zijn gekomen. Past er
       onverwacht toch niets meer (een ander spel heeft de kamer intussen
       volgezet), dan zeggen we dat vriendelijk en beloven we niets. */
    if (gelegd.length) C.taakKlaar('bedden', { sterren: 1 });
    C.hotspots.laat();                    /* de deur is weer gewoon de deur */
    teken();
    wolk('bd_goed', plekPx(0, goot, 0), gelegd.length
      ? { icoon: '🛏', getal: '+' + D.nieuw, klas: 'goed', prio: 14 }
      : { icoon: '🛏', tekst: 'vol ✓', klas: 'goed', prio: 14 });
    gastenErin(gelegd);
    bewaarStraks();
    /* even nagenieten, dan de kaartjes weg en de kamer terug aan het hotel */
    tik(function () {
      if (!C || !D) return;
      D.fase = 'af';
      teken();
      tik(function () { if (C) C.sluit(); }, 3400);
    }, 2600);
  });
}
function somAf() {
  if (kaart) { kaart.weg(); kaart = null; }
  var p = plekPx(0, 0, marges().boven);
  kaart = C.ui.somkaart(p, D.rijen + ' × ' + D.perRij + ' =',
    { id: 'bd_som', door: 'bedden', pad: false, hoog: p.y, kamer: K,
      icoon: '🛏',
      regel: (D.doel === 1 ? 'Nu staat er ' : 'Nu staan er ') +
             mv(D.doel, 'bed', 'bedden') });
  if (kaart) { kaart.zet(D.doel); kaart.klaar(); }
}

/* het vrije vakje dat het verst van alle bedden af ligt: zo staan de nieuwe
   bedden mooi verdeeld door de kamer in plaats van tegen elkaar aan */
function besteVak() {
  var vrij = C.wereld.slots(K, 'vrij').slice();
  var bedden = C.wereld.slots(K, 'bed');
  var beste = null, best = -1, i, j, dm, d;
  for (i = 0; i < vrij.length; i++) {
    dm = 1e9;
    for (j = 0; j < bedden.length; j++) {
      d = Math.abs(bedden[j].x - vrij[i].x) + Math.abs(bedden[j].z - vrij[i].z);
      if (d < dm) dm = d;
    }
    if (dm > best) { best = dm; beste = vrij[i]; }
  }
  return beste;
}

/* Eén bed per stap: dat is de golf die je in de kamer ziet gebeuren.
   Past er geen bed meer bij, dan stoppen we - nooit een half bed. */
function bouwBedden(hoeveel, klaar) {
  var gelegd = [];
  function stap() {
    if (!C) return;
    if (gelegd.length >= hoeveel) { klaar(gelegd); return; }
    var v = besteVak();
    var b = v ? C.wereld.voegBed(K, { x: v.x, z: v.z }) : null;
    if (!b) { klaar(gelegd); return; }
    gelegd.push(b);
    rustigeKamer();
    C.snd.plop(1);
    tik(stap, GOLF);
  }
  stap();
}

/* De gasten die nog geen bed hebben lopen naar hun nieuwe bed toe. Een net
   gelegd bed is nog van niemand, dus het dier gaat er BLIJ NAAST staan: op
   de sta-plek van het bed, nooit op de matras. Slapen doet het pas als de
   check-in dit bed aan deze gast geeft - dan legt World.slaap() het netjes
   midden op de matras. */
function gastenErin(gelegd) {
  var zonder = C.wereld.dieren().filter(function (g) { return !g.bed; });
  if (!zonder.length || !gelegd.length) return;
  gelegd.forEach(function (b, i) {
    var g = zonder[i];
    if (!g) return;
    tik(function () {
      if (!C) return;
      var s = C.wereld.slot(K, b.id);
      if (!s) return;
      C.wereld.reis(g.id, K, { x: s.sx, z: s.sz, na: 'blij' });
      C.wereld.setMood(g.id, 'bouncy');
    }, 300 + i * 480);
  });
}

/* =====================================================================
   KAMERHULP WOLKJE doet één rij voor: spookbedjes + spookcijfer
===================================================================== */
function spookWeg() {
  if (!C) return;
  C.wereld.getalTag({ x: 0, z: 0 }, null, { id: 'bd_spook' });
}
function hulp() {
  if (!C || !D || D.klaar) return;
  var r = eersteLegeRij();
  if (r < 0) return;
  D.spook = true;
  teken();
  var p = plekPx(r, -(goot - 26), 0);
  C.wereld.getalTag({ kamer: K, x: p.x, z: p.z }, D.perRij,
                    { id: 'bd_spook', y: p.y, klas: 'hotspook', titel: 'zoveel in een rij' });
  wolk('bd_wolkje', plekPx(r, -goot, STAP_PX), {
    icoon: '🐑', getal: D.perRij, tekst: 'in elke rij', klas: 'hulp', prio: 14,
    tik: function () {
      C.ui.wolkWeg('bd_wolkje');
      if (!D || D.klaar) return;
      D.rij[r] = D.perRij;                 /* Wolkje legt de rij echt neer */
      D.laatste = r;
      C.snd.ja();
      bewaarStraks();
      teken();
    }
  });
  C.state.zetGezien('bedden_wolkje');
  C.snd.brief();
}

/* =====================================================================
   START / STOP
===================================================================== */
/* De kamers zitten helemaal vol met bedden. Dat is geen fout maar een
   compliment: één kaartje, en het spel doet zichzelf weer dicht. */
function vol() {
  D.vol = 1;
  D.klaar = false;
  D.fase = 'vol';
  wolk('bd_vol', 'mand', { icoon: '🛏', tekst: 'vol ✓', hoog: 20, klas: 'goed',
                           prio: 14, tik: function () { C.sluit(); } });
  C.snd.zacht();
  tik(function () { if (C) C.sluit(); }, 2600);
}
function start(ctx) {
  C = ctx;
  somOpnieuw();
  D = C.data();
  bezig = false;
  t0 = C.ui.nu();
  var keus = kiesKamer();
  K = keus.kamer;
  C.wereld.naar(K);
  /* Is er nergens meer plek voor een bed? Dan beloven we ook niets: één
     vriendelijk kaartje ("vol"), geen opdracht, geen ster. */
  if (keus.cap < 2) { vol(); return; }
  var o = opdracht(keus.cap), sig = signatuur(o);
  if (D.sig !== sig || !D.rij) nieuweOpdracht(o, sig);
  if (D.klaar) { if (D.fase !== 'af') D.fase = 'af'; somAf(); }
  else {
    /* de deur van de kamer is zolang het "klaar"-moment (GAMES-API.md 2) */
    (C.wereld.kamer(K).deuren || []).forEach(function (d) {
      C.hotspots.pak('deur_' + K + '_' + d.naar, check);
    });
  }
  /* Draait het scherm, dan verandert de voxelmaat: opnieuw uitleggen. Sinds
     M1c via de opmaat-bus (Ui.opKader -> World.onKader): één melding per
     echte kaderverandering in plaats van resize ÉN orientationchange, en ook
     als alleen het kader krimpt (de cijferstrook eronder). */
  opMaat = function () {
    _sch = null;
    somOpnieuw();                 /* de gemeten lift hoort bij het OUDE kader */
    clearTimeout(maatT);
    maatT = setTimeout(function () { if (C) teken(); }, 260);
  };
  if (maatAf) { maatAf(); maatAf = null; }
  maatAf = C.ui.opKader(opMaat);
  teken();
}

function stop() {
  stopTikken();
  clearTimeout(bewaarT);
  clearTimeout(maatT);
  somOpnieuw();
  bewaarT = maatT = null;
  if (maatAf) { maatAf(); maatAf = null; }
  opMaat = null;
  if (C) {
    if (kaart) kaart.weg();
    ['bd_wolk', 'bd_fout', 'bd_goed', 'bd_op', 'bd_wolkje', 'bd_vol'].forEach(function (id) {
      C.ui.wolkWeg(id);
    });
    spookWeg();
    C.state.bewaar();
    C.hotspots.wisAlles();              /* geeft ook de geleende deur terug */
    if (window.Hotel) Hotel.render();   /* de kamer is weer van het hotel */
  }
  kaart = null;
  C = null;
  D = null;
  bezig = false;
}

/* =====================================================================
   AANMELDEN
===================================================================== */
Games.register({
  id: 'bedden',
  naam: 'Bedden op rij',
  kamer: KAMER,
  /* de dekenkist: de mand in de hoek van de kamer, ver van de bedden en van
     de deur af, zodat geen enkele knop een andere afdekt */
  hotspot: { obj: 'mand', icoon: '🛏', label: 'Bedden', hoog: 14, dx: -4, dz: -4 },
  unlock: function (N) { return N >= 1; },
  stub: false,
  start: start,
  stop: stop,
  /* haakje voor de speeltest: enkelvoud/meervoud naregenen */
  mv: mv
});
})();
