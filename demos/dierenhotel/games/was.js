/* ---------------------------------------------------------------
   games/was.js - DE WASMANDTOREN (G4, kamer `wasserij`, HOTEL.md 9).

   Op de vloer van de wasserij ligt een berg wasgoed; tegen de linkerwand
   staan 2 tot 4 kratten, elk met zijn eigen pictogram (🧦 sokken,
   🧣 sjaals, 🧺 handdoeken, 🧸 knuffels). Elk stuk was dat in de goede
   krat gaat wordt een blokje op een stapel, dus de kratten worden samen
   een echt staafdiagram. Is de berg leeg, dan komt er één vraagkaart bij
   de kratten en gaat het rekenen over dat diagram.

   HET RONDJE
   1. SORTEREN. Tik op de berg (dan zegt het wolkje wat je in je handen
      hebt: "🧦 een sok") en tik daarna op de krat. Slepen mag ook: de
      hotspot-laag legt over knop + krat één vangvlak, dus je kunt naar de
      krat zelf slepen (api-h1 3b). Goed → een blokje erop en een zacht
      plopje; mis → de krat wipt even op en het stuk ligt weer op de berg.
      Geen tekst, geen rood, geen ster minder.
   2. VRAGEN over het diagram, per band:
      groep 3  "📊 Welke stapel is het hoogst?" met de soorten als
               icoon+woord-knoppen (de stapels zijn nooit even hoog);
      groep 4  "📊 Hoeveel meer sokken dan sjaals?" met de som "8 − 5 ="
               en een cijferpad, daarna "📊 Hoeveel stuks samen?";
      groep 5  de was komt per twee op de berg en de kaart draagt de
               legenda "📦 Elk blokje is 2 stuks": eerst "Hoeveel sokken
               zijn het?" (blokjes × 2), daarna het verschil.
   3. KLAAR. "✅ Alles gesorteerd!" met één knop, plus de ster voor het
      meedoen (ctx.taakKlaar).

   DE GETALLEN (alleen hier, afgeleid van N en de band; state.js blijft
   onaangeroerd). T = k·N + r met k uit de bandset en r < k, en dan onder
   het plafond van dit spel: 12 stuks in groep 3 (2 of 3 soorten), 20 in
   groep 4 (3 soorten), 30 in groep 5 (4 soorten, per twee, dus hooguit
   15 tikken). De stapels worden altijd ONGELIJK verdeeld (1, 2, 4 / 5, 7,
   8 / ...), zodat "welke is het hoogst" precies één antwoord heeft.
   Bij heel weinig gasten past het aantal soorten zich aan: vier stapels
   hebben minstens 1+2+3+4 = 10 blokjes nodig, dus groep 5 met één gast
   (T = 18, 9 blokjes) sorteert drie soorten in plaats van vier. Dat is
   een nette afbouw, geen uitzondering: soortenVoor() rekent het uit.

   WAT DIT SPEL VAN DE MOTOR GEBRUIKT
     Rooms.registerModel('was_krat'|'was_berg')   eigen voxelmodellen (P1b)
     ctx.wereld.decor / decorWisAlles             de kratten en de berg
     ctx.hotspots.bron / maak (kind:'drop')       berg + kratten als doel
     ctx.sleep via bron.sleep                     slepen met vinger of muis
     ctx.ui.wolk / somkaart(regel, keuzes)        rekenen ín de wereld
     ctx.wereld.getalTag                          spookcijfers bij de 3e poging
     ctx.data() / ctx.state.bewaar()              herladen midden in een beurt
---------------------------------------------------------------- */
(function () {
'use strict';

var C = null;        /* de ctx */
var S = null;        /* de stand; leeft in C.data().stand en wordt bewaard */
var klok = [];       /* eigen wekkertjes (het wippen van een krat) */
var berg = null;     /* handvat van de sleepbron op de berg */
var kaart = null;    /* handvat van de vraagkaart */

var KAMER = 'wasserij';

/* ---------- de vier soorten was ----------
   De volgorde is ook de moeilijkheidsvolgorde: groep 3 sorteert de eerste
   twee of drie, groep 4 drie, groep 5 alle vier.
   Eén woord per soort, overal hetzelfde (kaart, keuzeknop en het plaatje op
   de krat): "doeken" en niet "handdoeken", want een plaatje van 91 px past
   niet tussen kratten die 63 px uit elkaar staan, en twee namen voor
   dezelfde stapel leest een kind niet als dezelfde stapel. De langste zin
   blijft daarmee "Hoeveel meer knuffels dan doeken?" (33 tekens).
   `ev` is het enkelvoud; dat is ook het korte plaatje op een krap kader. */
var SOORTEN = [
  { id: 'sok',   ico: '🧦', naam: 'sokken',   ev: 'sok',     kl: '#E86A9A', kl2: '#C9527E' },
  { id: 'sjaal', ico: '🧣', naam: 'sjaals',   ev: 'sjaal',   kl: '#5FA8D3', kl2: '#3E85AE' },
  { id: 'doek',  ico: '🧺', naam: 'doeken',   ev: 'doek',    kl: '#F2C14E', kl2: '#D09F2E' },
  { id: 'knuf',  ico: '🧸', naam: 'knuffels', ev: 'knuffel', kl: '#8DBF6B', kl2: '#6C9E4C' }
];

/* per band: het plafond aan stuks, hoeveel soorten, hoeveel stuks per tik
   en uit welke k gekozen mag worden (groep 4 kent alleen de tafels 1-5 en
   10; 10 komt hier nooit onder het plafond van 20 uit) */
var BAND = {
  3: { plaf: 12, soorten: 3, per: 1, kset: [1, 2] },
  4: { plaf: 20, soorten: 3, per: 1, kset: [1, 2, 3, 4, 5] },
  5: { plaf: 30, soorten: 4, per: 2, kset: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] }
};

/* hout van de kratten: dezelfde tinten als de meubels in rooms.js */
var HOUT = '#D0A87A', HOUT_D = '#B98F62', HOUT_L = '#E2C094';

/* =====================================================================
   1. DE VOXELMODELLEN (P1b: Rooms.registerModel, één keer bij het laden)
===================================================================== */
function prng(seed) {
  var a = seed >>> 0;
  return function () {
    a = a + 0x6D2B79F5 | 0;
    var t = Math.imul(a ^ a >>> 15, 1 | a);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

/* De krat staat op een laag bankje tegen de wand, met n blokjes erin
   gestapeld in de kleur van zijn soort. Elk blokje is 2 voxels kleur plus
   1 voxel donkere naad, dus je kunt de blokjes op het scherm echt tellen.
   Waarom een bankje: de vraagkaart hangt vóór de kratten, en op een laag
   kader (860 x 420 geeft een kader van 688 x 278, en 320 x 640 zelfs
   286 x 190) schuift die kaart omhoog tot tegen de kratten. Staan de blokjes
   18 voxels boven de vloer, dan dekt de kaart hooguit het bankje af en blijft
   het staafdiagram in zijn geheel te tellen. */
var KRAT_VOET = 18;                     /* standaardhoogte van het bankje */
var KRAT_VOET_MIN = 0, KRAT_VOET_MAX = 18;
Rooms.registerModel('was_krat', function (p) {
  var K = Art.kit, v = [], i;
  var so = SOORTEN[p && (p.soort === undefined ? p.s : p.soort)] || SOORTEN[0];
  var y0 = Math.max(KRAT_VOET_MIN, Math.min(KRAT_VOET_MAX,
             Math.round((p && p.voet === undefined ? KRAT_VOET : p.voet) || 0)));
  /* de stapel blijft onder de wandhoogte van de wasserij (52 voxels,
     rooms.js MATEN regel 2). De hoogste stapel die een band kan opleveren is
     8 blokjes (groep 4, 3 soorten uit 20 stuks), maar een kapot getal mag
     nooit door de wand heen. */
  var stap = Math.max(2, Math.min(3, Math.round((p && p.stap === undefined ? 3 : p.stap) || 3)));
  var n = Math.max(0, Math.min(Math.floor((50 - y0 - 2) / stap), Math.round((p && p.n) || 0)));
  if (y0 >= 6) {                                     /* een bankje eronder */
    K.bx(v, -6, y0 - 4, -5, 13, 4, 11, HOUT_D);      /* het blad */
    K.bx(v, -5, 0, -4, 3, y0 - 4, 3, HOUT_D);        /* pootje links-achter */
    K.bx(v, 3, 0, -4, 3, y0 - 4, 3, HOUT_D);         /* pootje rechts-achter */
    K.bx(v, -5, 0, 2, 3, y0 - 4, 3, HOUT);           /* pootje links-voor */
    K.bx(v, 3, 0, 2, 3, y0 - 4, 3, HOUT);            /* pootje rechts-voor */
  } else if (y0 > 0) {
    K.bx(v, -6, 0, -5, 13, y0, 11, HOUT_D);          /* te laag voor pootjes */
  }
  K.bx(v, -6, y0, -5, 13, 2, 11, HOUT);              /* bodem van de krat */
  K.bx(v, -6, y0 + 2, -5, 13, 3, 1, HOUT_D);         /* rand achter (z-) */
  K.bx(v, -6, y0 + 2, 5, 13, 3, 1, HOUT_L);          /* rand voor  (z+) */
  K.bx(v, -6, y0 + 2, -4, 1, 3, 9, HOUT_D);          /* rand links (x-) */
  K.bx(v, 6, y0 + 2, -4, 1, 3, 9, HOUT_L);           /* rand rechts (x+) */
  for (i = 0; i < n; i++) {
    K.bx(v, -4, y0 + 2 + i * stap, -3, 9, stap - 1, 7, so.kl);
    K.bx(v, -4, y0 + 1 + stap + i * stap, -3, 9, 1, 7, so.kl2);
  }
  return v;
});

/* De berg wasgoed: acht plukjes op vaste plekken (zelfde zaadje bij elke
   aanroep, dus dezelfde params geven dezelfde lijst - P1b eist dat, want
   er wordt op params gecachet). Hoe minder er nog ligt, hoe minder plukjes
   getekend worden; bij 0 komt er een lege lijst en dus geen plaatje. */
var BERG_PLUK = (function () {
  var r = prng(90210), uit = [], i;
  for (i = 0; i < 8; i++)
    uit.push([Math.round(r() * 16 - 8), Math.round(r() * 3), Math.round(r() * 16 - 8), r()]);
  return uit;
})();
Rooms.registerModel('was_berg', function (p) {
  var K = Art.kit, v = [], i, q, so;
  var n = Math.max(0, Math.round((p && p.n) || 0));
  if (!n) return v;
  var m = Math.max(1, Math.min(BERG_PLUK.length, Math.ceil(n / 2)));
  for (i = 0; i < m; i++) {
    q = BERG_PLUK[i];
    so = SOORTEN[i % SOORTEN.length];
    K.ell(v, q[0], 2 + q[1], q[2], 4.2, 2.8, 4.2, q[3] < 0.5 ? so.kl : so.kl2,
          { e: 2.4, ymin: 0 });
  }
  return v;
});

/* =====================================================================
   2. WAAR STAAT WAT (als breuk van de kamer, GAMES-API 4)

   De kratten staan op één lijn in de ACHTERHOEK, langs een lijn van
   gelijke diepte (x + z is voor alle kratten hetzelfde). Dat is op het
   scherm een RECHTE horizontale grondlijn - alleen zo staan de stapels
   naast elkaar op dezelfde vloerhoogte en is het echt een staafdiagram.
   Een rij langs één wand (x of z vast) zou op het scherm een steile
   schuine lijn zijn: dan staat elke stapel op een andere hoogte en valt
   er niets meer te vergelijken. De stap langs de lijn is 22 voxels bij twee
   of drie kratten (44 in x − z, dus 86 px bij k = 1 en 59 px op een kleine
   telefoon: daar past het hele woord naast elkaar) en 16 bij vier kratten,
   want breder botst de buitenste krat met de wand of met de deuropening.

   De berg wasgoed ligt midden-voor op de vloer, vóór de rij, en de
   vraagkaart hangt nog verder naar voren (grotere x + z): zo dekt zij het
   staafdiagram nooit af, en zij komt pas in beeld als de berg leeg is.
===================================================================== */
function kamerR() { return Rooms.get(KAMER) || { w: 100, d: 90 }; }
function bergPlek() { return Rooms.plek(KAMER, 0.60, 0.60); }         /* (60, 54) */
function kaartPlek() { return Rooms.plek(KAMER, 0.88, 0.933); }       /* (88, 84) */
function kratPlek(m, i) {
  var r = kamerR();
  /* de grondlijn: x + z = 66 bij een kamer van 100 x 90. Ver genoeg van de
     wasrek-hoek (die reikt tot z = 15 bij x <= 42) en van de deuropening
     naar de keuken (x 62..74 op z = 0). */
  var som = Math.round((r.w + r.d) * 0.347);
  var x = Math.round(som / 2 - 4 + (i - (m - 1) / 2) * (m > 3 ? 16 : 22));
  return { x: x, z: som - x };
}
/* Hoe groot is het kader nu? (zelfde truc als voerkar/tobbe/sleutels) */
function kaderMaat() {
  var el = document.getElementById('worldHits') || document.getElementById('world');
  return [(el && el.clientWidth) || 400, (el && el.clientHeight) || 440];
}
/* Waar hoort het cijferpad? 'auto' zet het ÍN het kader zolang dat hoger is
   dan 300 px (api-m1a 1). Op een kleine telefoon (320 x 640 geeft een kader
   van 286 x 312) is dat net niet laag genoeg voor de drempel, maar wel te
   laag voor kaart + pad: ui.js tilt de kaart dan over het staafdiagram heen
   en het pad steekt 2 px buiten het kader. Op zo'n kader kiezen we zelf de
   strook onder het kader, dan blijven de stapels heel. */
function padPlek() {
  var m = kaderMaat();
  return (m[0] < 330 || m[1] < 340) ? 'buiten' : 'auto';
}
/* Krap kader: dan draagt de vraagkaart ÉÉN regel in plaats van twee. Reden:
   op 320 x 640 (kader 286 x 190) is een kaart van twee regels 114 px hoog en
   dan is er onder de kaart geen ruimte meer voor het hele staafdiagram - de
   onderste blokjes verdwijnen erachter, en juist die moet je in groep 5
   kunnen tellen. De legenda staat dan als eigen wolkje in de kamer. */
function krapKader() {
  var m = kaderMaat();
  return m[1] < 300 || m[0] < 330;
}
function kratId(i) { return 'was_krat' + i; }
function kratHot(i) { return 'ws_k' + i; }

/* =====================================================================
   2b. DE INDELING WORDT GEMETEN, NIET GEGOKT

   Het kader is per telefoon en per stand heel anders: 386 x 468 (420 x 860
   staand) tot 286 x 190 (320 x 640 staand, waar de cijferstrook 154 px
   opeet) en 562 x 218 (740 x 360 liggend). Twee dingen mogen daar nooit
   gebeuren:
     C1  het naamplaatje van een krat mag niet ONDER de krat belanden. De
         hotspot-laag doet dat zelf zodra er boven de stapel geen 48 px
         over is (api-h1 2, "automatisch terugvallen"), en onder de krat
         staat de vraagkaart - dan is niet meer te zien welke stapel de
         sokken zijn. Gemeten vóór deze regel: 320 x 640 liet alleen
         "sokken" staan, 844 x 390 en 740 x 360 alle drie de plaatjes
         achter de kaart.
     C2  de kaart mag geen blokje van het staafdiagram afdekken.
   Beide hangen aan één knop: de hoogte van het bankje onder de krat. Hoger
   bankje = stapel hoger in beeld = meer lucht onder de blokjes (goed voor
   C2) maar minder boven de stapel (slecht voor C1). Daarom meten we na het
   tekenen wat er echt staat (Hits.debug: het anker van elk plaatje, de
   hoogte van het voorwerp eronder, de plaatjesbreedte, en de bovenrand van
   de kaart uit de dom) en rekenen we de bank uit die aan beide voldoet.
   Dezelfde meting kiest hoe breed het plaatje mag zijn: heel woord ->
   enkelvoud -> alleen het pictogram, en als zelfs dat niet past mogen de
   plaatjes uitwijken (dan is niet-overlappen belangrijker dan pal boven
   de eigen krat staan). Lukt het met een bank van 0 t/m 18 voxels nog niet
   (320 x 640 op een scherm met dichtheid 2, acht blokjes), dan worden de
   blokjes twee voxels in plaats van drie: de staaf wordt korter en het past
   weer allebei.
   De reeks meetmomenten loopt tot ~2,65 s na het tekenen (hits.js plaatst
   pas in de volgende tekenbeurt, ui.js zet zijn kaart in twee rondes van
   90 ms vrij en mag tot 400 ms later nog van cijferstrook wisselen, en dat
   verandert de kadermaat opnieuw). Opnieuw bij elke kadermaat, ook via
   Ui.opKader (api-m1a 2).
===================================================================== */
var LAY = { voet: KRAT_VOET, stap: 3, tier: 2, vast: true, maat: '', geo: '', gen: 0 };
var layStop = null, layLog = [];

function layReset() {
  LAY.voet = KRAT_VOET; LAY.stap = 3; LAY.tier = 2; LAY.vast = true; LAY.geo = '';
}
/* het woord op de krat: heel, kort, of alleen het pictogram */
function kratWoord(i) {
  if (LAY.tier >= 2) return SOORTEN[i].naam;
  if (LAY.tier === 1) return SOORTEN[i].ev;
  return null;
}
function spotVan(dbg, id) {
  for (var j = 0; j < dbg.spots.length; j++) if (dbg.spots[j].id === id) return dbg.spots[j];
  return null;
}
/* Meet en stel bij; geeft true terug als er iets veranderd is (dan opnieuw
   tekenen). Zonder Hits.debug (een andere motor) doet dit niets en houdt het
   spel de standaardindeling - dat is geen fout, alleen minder fijn. */
function meetIndeling() {
  if (!C || !S || !window.Hits || typeof Hits.debug !== 'function') return false;
  var host = document.getElementById('worldHits');
  if (!host) return false;
  var dbg = Hits.debug(), tk = dbg.voxelPx || 2, i, sp, plaat = [];
  for (i = 0; i < S.m; i++) {
    sp = spotVan(dbg, kratHot(i));
    if (!sp || !sp.anker || !sp.w || !sp.h) return 'wacht';       /* nog niet gemeten */
    plaat.push(sp);
  }
  /* de vloerlijn van de kratten: anker (bovenkant stapel) + de hoogte van
     het voorwerp eronder. Die ligt vast, wat de bank ook doet. */
  var vloer = plaat[0].anker[1] + plaat[0].vh;
  var hoogste = 0, plaatH = 0;
  for (i = 0; i < S.m; i++) {
    /* het DOEL, niet de stand van nu: dan staat de indeling meteen goed en
       verschuift er niets meer terwijl de stapels vollopen */
    hoogste = Math.max(hoogste, S.doel[i]);
    plaatH = Math.max(plaatH, plaat[i].h);
  }
  var kEl = document.querySelector('[data-hot="ws_vraag"]');
  var kTop = null;
  if (kEl && kEl.offsetHeight)
    kTop = kEl.getBoundingClientRect().top - host.getBoundingClientRect().top;
  /* C1 en C2 in voxels bank */
  /* C1: het anker (bovenkant stapel) moet minstens plaatje + kier + 2 px
     onder de bovenrand van het kader liggen, anders klapt de laag het
     plaatje onder de krat (hits.js: p.y - hoogte - GAT < 2). De stapel meet
     voet + 4 + stap x blokjes voxels. */
  var stap = 3;
  var voetMax = Math.floor((vloer - plaatH - 6) / tk) - 4 - stap * hoogste;
  /* C2: de onderkant van de blokjes (voet + 2 voxels) moet onder de bovenrand
     van de kaart uit blijven. Op 320 x 640 (kader 286 x 190, kaart 99 px) is
     dat precies raken: daar past een bank van 13 voxels én tegen C1 aan én
     tegen de kaart aan, en het bankje eronder mag de kaart wel raken. */
  var voetMin = kTop === null ? KRAT_VOET_MIN : Math.ceil((vloer - kTop) / tk) - 2;
  /* Kan het met blokjes van drie voxels niet allebei (320 x 640 op een scherm
     met dichtheid 2: kader 286 x 190, kaart 99 px, acht blokjes), dan worden
     de blokjes twee voxels: de staaf wordt korter, en dan past het plaatje
     erboven ÉN blijft elk blokje onder de kaart uit. */
  if (voetMin > voetMax && hoogste > 0) {
    stap = 2;
    voetMax = Math.floor((vloer - plaatH - 6) / tk) - 4 - stap * hoogste;
  }
  var voet = Math.max(KRAT_VOET_MIN, Math.min(KRAT_VOET_MAX, voetMax));
  /* Past C2 er ook nog bij, dan de bank zo hoog als C2 vraagt (dat geeft de
     kaart de meeste lucht). Kan het niet allebei - dat komt in geen van de
     zes gemeten kadermaten voor - dan gaat C1 voor: een plaatje dat achter
     de kaart verdwijnt maakt de vraag onbeantwoordbaar ("welke stapel is
     nou sjaals?"), een blokje dat onderaan een kiertje mist niet. */
  if (voetMin > voet && voetMin <= voetMax)
    voet = Math.max(KRAT_VOET_MIN, Math.min(KRAT_VOET_MAX, voetMin));
  /* overlappen de plaatjes elkaar? dan een maatje kleiner, en als het
     pictogram alleen ook niet past: laat ze uitwijken */
  var rij = plaat.slice().sort(function (a, b) { return a.px - b.px; });
  var over = -999;                 /* niet 0: negatief is juist de lucht */
  for (i = 1; i < rij.length; i++)
    over = Math.max(over, (rij[i].w + rij[i - 1].w) / 2 - (rij[i].px - rij[i - 1].px));
  var tier = LAY.tier, vast = LAY.vast;
  /* -2 en niet 0: twee plaatjes die elkaar precies raken lezen als één
     lange strook, dus we willen minstens 2 px lucht ertussen */
  if (over > -2 && vast) {
    if (tier > 0) tier--;
    else vast = false;
  }
  layLog.push({ t: Math.round(C.ui.nu() - (S.t0 || 0)), maat: kaderMaat().join('x'), vloer: Math.round(vloer), kTop: kTop === null ? null : Math.round(kTop),
                tk: +tk.toFixed(2), hoog: hoogste, pH: plaatH, over: Math.round(over),
                vMin: voetMin, vMax: voetMax, voet: voet, stap: stap, tier: tier, vast: vast });
  if (layLog.length > 14) layLog.shift();
  /* De meetkunde zelf kan nog schuiven: de cijferstrook onder het kader gaat
     pas open als de kaart er staat, en zonder World.hermeet (M1b) meet
     world.js de camera niet meteen opnieuw - dan staat pr() nog op de oude
     kadermaat. Zolang vloer of de bovenrand van de kaart nog beweegt blijven
     we dus doorkijken, ook als er niets te veranderen valt. */
  var geo = Math.round(vloer) + '/' + (kTop === null ? '-' : Math.round(kTop));
  var stil = geo === LAY.geo;
  LAY.geo = geo;
  if (voet === LAY.voet && stap === LAY.stap && tier === LAY.tier && vast === LAY.vast)
    return stil ? false : 'opnieuw';
  LAY.voet = voet; LAY.stap = stap; LAY.tier = tier; LAY.vast = vast;
  return true;
}
/* Na het tekenen laten hermeten. Waarom een hele reeks momenten en niet
   één keer: hits.js zet de plekken pas in de VOLGENDE tekenbeurt, ui.js zet
   zijn kaart in twee rondes van 90 ms vrij, de cijferstrook onder het kader
   gaat open (dat maakt het kader lager, en dus de camera anders) en ui.js
   mag daar tot 400 ms later (VERSTIL_MS) nog één keer op terugkomen. Elke
   stap kost één Hits.debug() en hooguit één hertekening. */
var LAY_TIJD = [150, 90, 90, 120, 300, 500, 500, 900];
function regelIndeling(ronde) {
  if (!C || !S) return;
  ronde = ronde || 0;
  var maat = kaderMaat().join('x');
  if (maat !== LAY.maat) { LAY.maat = maat; layReset(); ronde = 0; teken(); }
  if (!ronde) LAY.gen = (LAY.gen || 0) + 1;    /* alleen de jongste reeks loopt */
  var gen = LAY.gen;
  if (ronde >= LAY_TIJD.length) return;
  straks(LAY_TIJD[ronde], function () {
    if (!C || !S || gen !== LAY.gen) return;
    var nu = kaderMaat().join('x');
    if (nu !== LAY.maat) { LAY.maat = nu; layReset(); teken(); regelIndeling(0); return; }
    if (meetIndeling() === true) teken();
    regelIndeling(ronde + 1);
  });
}
/* de bovenkant van de stapel in voxels: daar hangt het plaatje met het
   pictogram boven (op: 'boven'), zodat het plaatje het diagram niet afdekt */
function kratY(i) { return LAY.voet + 4 + LAY.stap * (S && S.vak ? S.vak[i] : 0); }

/* =====================================================================
   3. DE GETALLEN (T = k·N + r, HOTEL.md 3, binnen het plafond van dit spel)
===================================================================== */
function somFabriek() { return (C ? C.state : State).sommen; }

/* Elke (k, r) die onder het plafond van dit spel blijft, met de grootste
   totalen vooraan; in groep 5 moet T even zijn, want de was komt per twee
   op de berg. De drie grootste totalen wisselen per dag af, zodat er niet
   elke dag exact dezelfde beurt komt; bij gelijke T wint de r die het
   dichtst bij de bevroren som (koekjesSom) ligt. */
function kiesT(N, band, dag) {
  var B = BAND[band], basis = somFabriek().deel(N, band, dag);
  var lijst = [], i, j, k, r, T, al;
  for (i = 0; i < B.kset.length; i++) {
    k = B.kset[i];
    for (r = k - 1; r >= 0; r--) {
      T = k * N + r;
      if (T > B.plaf) continue;
      if (B.per === 2 && T % 2) continue;
      al = -1;
      for (j = 0; j < lijst.length; j++) if (lijst[j].T === T) { al = j; break; }
      if (al < 0) lijst.push({ k: k, r: r, T: T });
      else if (Math.abs(r - basis.r) < Math.abs(lijst[al].r - basis.r))
        lijst[al] = { k: k, r: r, T: T };
    }
  }
  /* minstens 3 blokjes: anders zijn er geen twee verschillende stapels */
  var goed = lijst.filter(function (q) { return q.T >= 3 * B.per; });
  if (!goed.length) goed = lijst;
  if (!goed.length) {
    /* Noodgeval: zelfs k = 1 loopt over het plafond (meer gasten dan er
       stuks mogen zijn). Dan zakt T naar het plafond zelf; de vorm k·N + r
       klopt dan niet meer, dus zeggen we dat eerlijk met k = 0. */
    T = B.plaf - (B.per === 2 ? B.plaf % 2 : 0);
    return { k: 0, r: 0, T: T };
  }
  goed.sort(function (a, b) { return b.T - a.T; });
  var top = goed.filter(function (q) { return q.T >= goed[0].T - 2 * B.per; }).slice(0, 3);
  return top[(dag - 1) % top.length];
}

/* T over m stapels verdelen, allemaal verschillend en allemaal minstens 1:
   basis 1, 2, 3, ... m, dan de rest gelijk verdelen en het laatste beetje
   bovenop de hoogste stapels. Verschillend blijft het daardoor altijd, dus
   "welke stapel is het hoogst" heeft precies één antwoord. */
function verdeel(T, m) {
  var basis = m * (m + 1) / 2, uit = [], q, rest, i;
  if (m < 1) return uit;
  if (T < basis) {                        /* te weinig voor m verschillende */
    q = Math.max(1, Math.floor(T / m));
    for (i = 0; i < m; i++) uit.push(q);
    uit[m - 1] += T - q * m;
    return uit;
  }
  q = Math.floor((T - basis) / m);
  rest = (T - basis) - q * m;
  for (i = 0; i < m; i++) uit.push(1 + i + q + (i >= m - rest ? 1 : 0));
  return uit;
}

/* hoeveel soorten passen er bij dit aantal blokjes? (m verschillende
   stapels hebben minstens 1+2+...+m blokjes nodig) */
function soortenVoor(band, blokken) {
  var m = BAND[band].soorten;
  while (m > 2 && blokken < m * (m + 1) / 2) m--;
  return m;
}

/* het complete recept van een beurt; ook de testhaak `proef` */
function recept(N, band, dag) {
  N = Math.max(1, N | 0);
  band = band === 4 ? 4 : (band === 5 ? 5 : 3);
  dag = Math.max(1, dag | 0) || 1;
  var B = BAND[band], t = kiesT(N, band, dag);
  var blokken = Math.floor(t.T / B.per);
  var m = soortenVoor(band, blokken);
  var stapel = verdeel(blokken, m);
  /* welke stapel bij welke soort? deterministisch door elkaar, zodat de
     hoogste niet elke dag dezelfde soort is */
  var r = prng(1000 * band + 37 * N + dag), i, j, q;
  for (i = stapel.length - 1; i > 0; i--) {
    j = Math.floor(r() * (i + 1));
    q = stapel[i]; stapel[i] = stapel[j]; stapel[j] = q;
  }
  /* de rij op de berg: één plek per tik, ook door elkaar */
  var rij = [];
  for (i = 0; i < m; i++) for (j = 0; j < stapel[i]; j++) rij.push(i);
  for (i = rij.length - 1; i > 0; i--) {
    j = Math.floor(r() * (i + 1));
    q = rij[i]; rij[i] = rij[j]; rij[j] = q;
  }
  return { band: band, N: N, dag: dag, k: t.k, r: t.r, T: blokken * B.per,
           per: B.per, m: m, blok: stapel, rij: rij };
}

function nieuweStand(N, band, dag) {
  var q = recept(N, band, dag), i;
  var s = { dag: q.dag, N: q.N, band: q.band, k: q.k, r: q.r, T: q.T, per: q.per,
            m: q.m, doel: q.blok.slice(), rij: q.rij.slice(), i: 0,
            vak: [], hand: null, stap: 'sorteren', missers: 0, ster: 0, t0: 0 };
  for (i = 0; i < q.m; i++) s.vak.push(0);
  return s;
}

/* =====================================================================
   4. START / STOP
===================================================================== */
function straks(ms, fn) { klok.push(setTimeout(fn, ms)); }
function stopKlok() { klok.forEach(function (t) { clearTimeout(t); }); klok = []; }
function bewaar() { if (C) C.state.bewaar(); }

function start(ctx) {
  C = ctx;
  var d = C.data(), N = Math.max(1, C.state.N()), band = C.state.band(), dag = C.state.dag();
  S = d.stand;
  if (!S || !S.rij || !S.rij.length || !S.vak || S.stap === 'af' ||
      S.dag !== dag || S.N !== N || S.band !== band) {
    S = nieuweStand(N, band, dag);
    d.stand = S;
  }
  S.t0 = C.ui.nu();
  kaart = null; berg = null;
  wipKrat = -1; wipHoog = 0;
  LAY.maat = ''; layReset();
  if (!layStop && C.ui.opKader) layStop = C.ui.opKader(function () { regelIndeling(0); });
  C.wereld.naar(KAMER);
  zetDecor();
  teken();
  if (S.stap !== 'sorteren') {
    vraagKaart();
    /* De hulp die het kind al verdiend had komt terug: bij drie missers
       liggen de spookcijfers er weer, anders het samen-tel-lijntje. Anders
       is herladen een straf ("mijn hulp is weg"). */
    if (S.stap !== 'af' && S.missers) {
      if (kaart) kaart.hulp(hulpZin());
      if (S.missers >= 3) spook();
    }
  }
  regelIndeling(0);
  bewaar();
}

function stop() {
  stopKlok();
  if (layStop) { try { layStop(); } catch (e) {} layStop = null; }
  wipKrat = -1; wipHoog = 0;
  if (C) {
    C.hotspots.wisAlles();
    C.hotspots.laat();
    /* zelf opruimen, ook al doet de wereld het bij een spelwissel al:
       één regel en het kan geen kwaad (api-p1b 3) */
    C.wereld.decorWisAlles();
  }
  C = null; S = null; kaart = null; berg = null;
}

/* =====================================================================
   5. DE WERELD: berg en kratten als los decor
===================================================================== */
function overBerg() { return S ? Math.max(0, S.rij.length - S.i) : 0; }
function stuksOver() { return overBerg() * (S ? S.per : 1); }

/* Het wipje van een krat leeft in deze twee variabelen en NIET in het
   decorstuk zelf: zetDecor() loopt bij elke tik opnieuw (teken()) en zou een
   losse hoog: 3 in dezelfde tik weer op 0 zetten. Gemeten vóór deze regel:
   0 -> 1 -> 0, één voxel in plaats van drie. */
var wipKrat = -1, wipHoog = 0;

function zetDecor() {
  if (!C || !S) return;
  var p = bergPlek(), i, q;
  C.wereld.decor(KAMER, { id: 'was_berg', model: 'was_berg', x: p.x, z: p.z,
                          params: { n: overBerg() } });
  for (i = 0; i < S.m; i++) {
    q = kratPlek(S.m, i);
    C.wereld.decor(KAMER, { id: kratId(i), model: 'was_krat', x: q.x, z: q.z,
                            hoog: i === wipKrat ? wipHoog : 0,
                            params: { soort: i, n: S.vak[i], voet: LAY.voet,
                                      stap: LAY.stap } });
  }
}

/* de krat wipt even op: een zacht "nee" zonder tekst en zonder rood.
   Drie voxels omhoog, ruim 250 ms, en elke tussenstand overleeft een
   hertekening omdat zetDecor() de stand uit wipHoog leest. */
var WIP = [[0, 3], [140, 2], [200, 1], [260, 0]];
function wip(i) {
  if (!C || !S) return;
  wipKrat = i;
  WIP.forEach(function (stap) {
    if (!stap[0]) { wipHoog = stap[1]; zetKratHoog(i); return; }
    straks(stap[0], function () {
      if (!C || wipKrat !== i) return;
      wipHoog = stap[1];
      if (!wipHoog) wipKrat = -1;
      zetKratHoog(i);
    });
  });
}
function zetKratHoog(i) {
  C.wereld.decor(KAMER, { id: kratId(i), hoog: i === wipKrat ? wipHoog : 0 });
}

/* =====================================================================
   6. TEKENEN - alles hangt aan een voorwerp in de wasserij
===================================================================== */
function handTekst() {
  var so = SOORTEN[S.hand];
  if (!so) return null;
  return S.per === 1 ? 'een ' + so.ev : 'twee ' + so.naam;
}

function tekenBerg() {
  var over = stuksOver(), hand = S.hand === null || S.hand === undefined ? null : SOORTEN[S.hand];
  if (!berg) {
    berg = C.hotspots.bron('was_berg', {
      id: 'ws_berg', icoon: '🧺', aantal: over, hoog: 18, prio: 11,
      klas: 'hotwolk', titel: 'berg met ' + over + ' stuks was',
      tik: function () { pak(); },
      sleep: {
        dropSel: '[data-drop="krat"]',
        ghostHTML: function () {
          var so = SOORTEN[S && (S.hand === null || S.hand === undefined ? S.rij[S.i] : S.hand)];
          return '<div class="karghost">' + (so ? so.ico : '🧺') + '</div>';
        },
        canDrag: function () { return !!S && S.stap === 'sorteren' && S.i < S.rij.length; },
        /* Wie sleept, pakt onderweg op: de sleep begint op de berg, dus het
           bovenste stuk zit al in je hand als je bij de krat aankomt. */
        onDrop: function (t) { pak(); legIn(parseInt(t.getAttribute('data-h-i'), 10)); }
      }
    });
  }
  if (!berg) return;
  berg.zet(over, S.per === 1 ? 'pak 1' : 'pak 2');
  /* De TELLER hoort bij de berg ("🧺 26 nog te sorteren") en wat je in je
     handen hebt bij je handen ("🧦 twee sokken"): samen in één knop las een
     kind het als "🧦 26 twee sokken". */
  C.hotspots.maak({
    id: 'ws_berg',
    html: '<span class="ico">🧺</span><span class="get">' + over + '</span>' +
          '<span class="zeg">nog te sorteren</span>' +
          '<span class="hand">pak ' + S.per + '</span>',
    klas: 'hotbron hotwolk',
    titel: 'berg met ' + over + ' stuks was, tik om er ' + S.per + ' te pakken'
  });
  if (!hand) { C.hotspots.weg('ws_hand'); return; }
  /* het wolkje van de hand hangt LAAG bij de berg (hoog 2), zodat het nooit
     bij de naamplaatjes boven de stapels in de weg komt */
  C.ui.wolk('was_berg', {
    id: 'ws_hand', hoog: 2, prio: 9, klas: 'goed',
    icoon: hand.ico, tekst: handTekst(),
    tik: function () { pak(); }
  });
}
function bergWeg() {
  if (berg) { berg.weg(); berg = null; }
  C.hotspots.weg('ws_hand');
  C.wereld.decor(KAMER, { id: 'was_berg', params: { n: 0 } });
}

function tekenKratten() {
  var i, q;
  for (i = 0; i < S.m; i++) {
    q = kratPlek(S.m, i);
    C.hotspots.maak({
      id: kratHot(i), kamer: KAMER, x: q.x, z: q.z, y: kratY(i),
      icoon: SOORTEN[i].ico, label: kratWoord(i),
      /* alle kratten staan op dezelfde diepte (x + z), en bij gelijke diepte
         is de sorteervolgorde niet gedefinieerd; met een eigen d liggen ze
         altijd in dezelfde orde van links naar rechts (api-p1b 3) */
      d: q.x + q.z + i / 100,
      /* VAST + op:'boven': het naamplaatje staat pal boven ZIJN krat en
         wijkt nooit uit. Dat is hier belangrijker dan een kiertje tussen de
         plaatjes: met uitwijken belandde het plaatje boven de krat van de
         buurman - en dan weet een kind niet meer waar de doeken heen. Past
         zelfs het pictogram alleen niet meer (vier kratten op een kader van
         286 px), dan zet meetIndeling() `vast` uit en wijken ze wél uit:
         niet-overlappen gaat dán voor. Het vangvlak (knop + krat) blijft in
         beide gevallen werken (api-h1 3b). */
      vast: LAY.vast, op: 'boven',
      kind: 'drop', drop: 'krat', data: { i: i }, prio: 10,
      titel: 'krat met ' + SOORTEN[i].naam + ': ' + S.vak[i] +
             (S.vak[i] === 1 ? ' blokje' : ' blokjes'),
      aan: (function (n) { return function () { legIn(n); }; })(i)
    });
  }
}

function tekenLegenda() {
  /* tijdens het sorteren altijd; bij de vraag alleen als de legenda niet op
     de kaart zelf staat (krap kader) */
  var wil = S.per === 2 && S.stap !== 'af' && (S.stap === 'sorteren' || krapKader());
  if (!wil) { C.hotspots.weg('ws_legenda'); return; }
  C.ui.wolk(Rooms.plek(KAMER, 0.12, 0.30), {
    id: 'ws_legenda', kamer: KAMER, hoog: 20, prio: 6,
    icoon: '📦', tekst: 'Elk blokje is 2 stuks'
  });
}

function teken() {
  if (!C || !S) return;
  zetDecor();
  tekenKratten();
  if (S.stap === 'sorteren') tekenBerg(); else bergWeg();
  tekenLegenda();
  C.wereld.vuil();
}

/* =====================================================================
   7. SORTEREN
===================================================================== */
function pak() {
  if (!C || !S || S.stap !== 'sorteren' || S.i >= S.rij.length) return false;
  if (S.hand === null || S.hand === undefined) {
    S.hand = S.rij[S.i];
    C.snd.tik();
    bewaar();
  }
  teken();
  return true;
}

function legIn(i) {
  if (!C || !S || S.stap !== 'sorteren') return false;
  if (!(i >= 0 && i < S.m)) return false;
  if (S.i >= S.rij.length) return false;
  /* met een lege hand (een tik op een krat zonder eerst de berg) gebeurt er
     niets: de berg wipt even op, zodat het kind ziet waar het begint */
  if (S.hand === null || S.hand === undefined) {
    C.snd.zacht();
    C.hotspots.maak({ id: 'ws_berg', klas: 'hotbron hotwolk hulp' });
    straks(320, function () { if (C && S) teken(); });
    return false;
  }
  var soort = S.hand;
  S.hand = null;
  if (soort === i) {
    S.vak[i]++;
    S.i++;
    C.snd.plop(1);
  } else {
    wip(i);
    C.snd.terug();
  }
  bewaar();
  teken();
  if (S.i >= S.rij.length && S.stap === 'sorteren') klaarMetSorteren();
  return soort === i;
}

/* testhaak: de hele berg in één keer goed sorteren */
function sorteerAlles() {
  var veilig = 0;
  while (S && S.stap === 'sorteren' && S.i < S.rij.length && veilig++ < 200) {
    S.hand = S.rij[S.i];
    legIn(S.hand);
  }
  return S ? S.i : 0;
}

function klaarMetSorteren() {
  S.stap = 'vraag1';
  S.missers = 0;
  S.t0 = C.ui.nu();
  C.snd.ja();
  bewaar();
  teken();
  vraagKaart();
}

/* =====================================================================
   8. DE VRAGEN OVER HET DIAGRAM
===================================================================== */
function stuks(i) { return S.vak[i] * S.per; }
function samen() { var n = 0, i; for (i = 0; i < S.m; i++) n += stuks(i); return n; }
function hoogsteIdx() {
  var b = 0, i;
  for (i = 1; i < S.m; i++) if (S.vak[i] > S.vak[b]) b = i;
  return b;
}
function laagsteIdx() {
  var b = 0, i;
  for (i = 1; i < S.m; i++) if (S.vak[i] < S.vak[b]) b = i;
  return b;
}

/* wat is het goede antwoord op de vraag die nu open staat? */
function antwoordNu() {
  if (!S) return null;
  if (S.band === 3) return hoogsteIdx();
  if (S.stap === 'vraag1') {
    if (S.band === 4) return stuks(hoogsteIdx()) - stuks(laagsteIdx());
    return stuks(hoogsteIdx());                    /* groep 5: blokjes x 2 */
  }
  if (S.band === 4) return samen();
  return stuks(hoogsteIdx()) - stuks(laagsteIdx());
}

/* doortellen van `van` naar `tot` in stappen: "5 … 6 … 7 … 8".
   Dát is het hulpje bij "hoeveel meer": je begint op de lage stapel en telt
   door tot de hoge, en het aantal stappen is het antwoord. */
function telDoor(van, tot, stap) {
  var l = [String(van)], n = van, veilig = 0;
  while (n < tot && veilig++ < 12) { n += stap; l.push(String(n)); }
  return l.join(' … ') + ' …';
}
function hulpZin() {
  var h = hoogsteIdx(), l = laagsteIdx(), i, som = 0, rij;
  if (S.band === 3) return 'tel de blokjes';
  if (S.stap === 'vraag1' && S.band === 5)
    return C.ui.telMee(2, Math.min(8, S.vak[h]), ' …');   /* blokjes x 2 */
  if (S.stap === 'vraag2' && S.band === 4) {              /* alles samen */
    rij = [];
    for (i = 0; i < S.m; i++) { som += stuks(i); rij.push(String(som)); }
    return rij.join(' … ') + ' …';
  }
  /* het verschil: doortellen van de lage stapel naar de hoge */
  return telDoor(stuks(l), stuks(h), S.per);
}

/* derde poging: de aantallen komen als spookcijfers op de kratten te staan
   (dezelfde hulpladder als bij de voerkar en de winkel van Zilverhoef) */
function spook() {
  var i;
  for (i = 0; i < S.m; i++)
    C.wereld.getalTag(kratId(i), stuks(i), { id: 'ws_sp' + i, y: kratY(i) - 2, prio: 3 });
}
function spookWeg() {
  var i;
  for (i = 0; i < S.m; i++) C.wereld.getalTag(kratId(i), null, { id: 'ws_sp' + i });
}

function keuzeStrook() {
  var uit = [], i;
  for (i = 0; i < S.m; i++) uit.push((function (n) {
    return { id: SOORTEN[n].id, icoon: SOORTEN[n].ico, tekst: SOORTEN[n].naam,
             kies: function () { kies(n); } };
  })(i));
  return uit;
}

function vraagKaart() {
  if (!C || !S) return null;
  if (kaart) { kaart.weg(); kaart = null; }
  var h = hoogsteIdx(), l = laagsteIdx(), i, som = '', o;
  S.t0 = C.ui.nu();
  if (S.stap === 'af') {
    kaart = C.ui.somkaart(kaartPlek(), '', {
      id: 'ws_vraag', kamer: KAMER, icoon: '✅', regel: 'Alles gesorteerd!',
      keuzes: [{ id: 'ok', icoon: '👍', tekst: 'klaar', kies: function () { C.sluit(); } }],
      keuzeTitel: 'klaar'
    });
    regelIndeling(0);
    return kaart;
  }
  if (S.band === 3) {
    kaart = C.ui.somkaart(kaartPlek(), '', {
      id: 'ws_vraag', kamer: KAMER, icoon: '📊', regel: 'Welke stapel is het hoogst?',
      keuzes: keuzeStrook(), keuzeTitel: 'kies een stapel'
    });
    regelIndeling(0);
    return kaart;
  }
  o = { id: 'ws_vraag', kamer: KAMER, icoon: '📊', open: true, max: 2,
        padPlek: padPlek(), onOk: function (n, k) { antwoord(n, k); } };
  if (S.band === 4) {
    if (S.stap === 'vraag1') {
      o.regel = 'Hoeveel meer ' + SOORTEN[h].naam + ' dan ' + SOORTEN[l].naam + '?';
      som = stuks(h) + ' − ' + stuks(l) + ' =';
    } else {
      o.regel = 'Hoeveel stuks samen?';
      som = [];
      for (i = 0; i < S.m; i++) som.push(stuks(i));
      som = som.join(' + ') + ' =';
    }
  } else {
    /* groep 5: de blokjes zijn per twee, dus het omrekenen is de opgave.
       De legenda staat als tweede korte regel op de kaart zelf. */
    o.regel = [S.stap === 'vraag1'
      ? 'Hoeveel ' + SOORTEN[h].naam + ' zijn het?'
      : 'Hoeveel meer ' + SOORTEN[h].naam + ' dan ' + SOORTEN[l].naam + '?'];
    /* op een ruim kader past de legenda op de kaart; op een krap kader zou
       die tweede regel het diagram achter de kaart drukken (zie krapKader) */
    if (!krapKader()) o.regel.push('📦 Elk blokje is 2 stuks');
  }
  kaart = C.ui.somkaart(kaartPlek(), som, o);
  regelIndeling(0);          /* de kaart is er nu: bank en plaatjes bijstellen */
  return kaart;
}

/* groep 3: een keuze uit de strook */
function kies(n) {
  if (!C || !S || S.band !== 3 || S.stap === 'af') return false;
  var goed = n === hoogsteIdx();
  C.state.tel(goed, C.ui.nu() - (S.t0 || C.ui.nu()));
  if (goed) {
    C.snd.ja();
    if (kaart) kaart.zet('✓').klaar();
    spookWeg();
    volgende();
    return true;
  }
  C.snd.zacht();
  S.missers++;
  if (kaart) kaart.hulp(S.missers >= 2 ? 'kijk naar de hoogste stapel' : hulpZin());
  if (S.missers >= 3) spook();
  bewaar();
  return false;
}

/* groep 4 en 5: een getal van het cijferpad */
function antwoord(n, k) {
  if (!C || !S || S.stap === 'af') return false;
  if (n === null || n === undefined || isNaN(n)) { if (k) k.hulp(hulpZin()); return false; }
  var goed = n === antwoordNu();
  C.state.tel(goed, C.ui.nu() - (S.t0 || C.ui.nu()));
  if (goed) {
    C.snd.ja();
    if (k) k.zet(n).klaar();
    spookWeg();
    volgende();
    return true;
  }
  C.snd.zacht();
  S.missers++;
  if (k) k.zet(null).hulp(hulpZin());
  if (S.missers >= 3) spook();
  bewaar();
  return false;
}

/* een vraag is goed: naar de volgende, of klaar */
function volgende() {
  var eerste = S.stap === 'vraag1';
  S.missers = 0;
  if (S.band !== 3 && eerste) S.stap = 'vraag2';
  else S.stap = 'af';
  bewaar();
  if (S.stap === 'af') ster();
  straks(750, function () {
    if (!C || !S) return;
    vraagKaart();
    teken();
  });
}

function ster() {
  if (!S || S.ster) return false;
  S.ster = 1;
  C.snd.hoera();
  C.taakKlaar('was', { sterren: 1 });
  bewaar();
  return true;
}

/* =====================================================================
   AANMELDEN
===================================================================== */
Games.register({
  id: 'was',
  naam: 'Wasmandtoren',
  kamer: KAMER,
  /* Er is (nog) geen vast decorstuk "berg wasgoed" in rooms.js, en los decor
     bestaat pas zodra het spel loopt: Games.plek() kent alleen slots, losse
     dingen en vast decor. Daarom hangt de startknop aan de wastobbe, met een
     zetje naar de plek waar de berg straks ligt (60, 54) - precies op het
     wasgoed dus, en niet op de tobbe. */
  hotspot: { obj: 'tobbe', icoon: '🧺', label: 'Was sorteren', hoog: 14, dx: -20, dz: -20 },
  unlock: function (N) { return N >= 1; },
  stub: false,
  /* het taakje op het prikbord: altijd beschikbaar, lage voorrang (de wensen
     van de dieren en de andere taakjes staan op 0 t/m 5) */
  taak: { icoon: '🧺', tekst: 'Was sorteren', prio: 8 },
  start: start,
  stop: stop,
  /* haakjes voor de speeltest (het hotel gebruikt ze niet) */
  proef: function (N, band, dag) { return recept(N, band, dag); },
  debug: function () { return S ? JSON.parse(JSON.stringify(S)) : null; },
  doe: function (wat, a) {
    if (wat === 'pak') return pak();
    if (wat === 'leg') return legIn(a);
    if (wat === 'sorteer') return sorteerAlles();
    if (wat === 'kies') return kies(a);
    if (wat === 'antwoord') return antwoord(a, kaart);
    if (wat === 'goed') return S && S.band === 3 ? kies(antwoordNu()) : antwoord(antwoordNu(), kaart);
    if (wat === 'juist') return antwoordNu();
    if (wat === 'voet') return LAY.voet;
    if (wat === 'lay') return { voet: LAY.voet, stap: LAY.stap, tier: LAY.tier, vast: LAY.vast, maat: LAY.maat };
    if (wat === 'laylog') return layLog.slice();
    if (wat === 'plek') return { berg: bergPlek(), kaart: kaartPlek(),
                                 kratten: (function () {
                                   var uit = [], i, m = S ? S.m : 0;
                                   for (i = 0; i < m; i++) uit.push(kratPlek(m, i));
                                   return uit;
                                 })() };
    return null;
  }
});
})();
