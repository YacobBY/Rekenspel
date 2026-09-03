/* ---------------------------------------------------------------
   games/voerkar.js - DE VOERKAR (referentie-implementatie, HOTEL.md 9).

   Twee fasen, en bij elke stap staat er in gewone woorden bij wat je doet:

   1. VULLEN, in de keuken. Op de voerkast hangt ÉÉN sommenkaartje met de
      opdracht in twee korte zinnen ("🍪 Verdeel 12 koekjes over 3 gasten" /
      "🫙 Ieder evenveel, de rest in de pot"); vanaf groep 4 staat er als het
      eerlijk uitkomt "12 : 3" onder. De strook aan het kaartje zegt met
      woorden hoeveel er per tik uit de zak komt ("pak 1 / pak 2 / pak 5",
      de gekozen knop is gekleurd); op de zak staat hetzelfde als "pak 2",
      plus het aantal dat er nog in zit.
      Elk bakje op de vloer draagt het dier waar het van is: "🐶 Boef 2", en
      de snoeppot zegt "🫙 pot 0". Verkeerd verdeeld? Dan staat het er in dat
      kaartje zelf bij: "🐶 Boef 12 · 8 eraf", "🐰 Wolkje 0 · 4 erbij",
      "🫙 pot 0 · 2 erbij", en op de zak "🍪 3 · nog in de zak". Dus geen los
      wolkje dat ergens anders belandt of wegvalt, en nooit een tweede
      betekenis voor ↩. De knoppen dragen altijd een woord: "🛒 Klaar" en
      "↩ Opnieuw", en na twee pogingen "🩺 Els helpt" (die blijft staan): dan
      zegt de tweede regel van de kaart "🩺 Iedereen 4, rest in de pot", en de
      bakjes vertellen zelf hoeveel er bij of af moet.
   2. HET RONDJE door het hotel. Zodra de kar klopt zegt de kar wat er nu
      moet ("🛒 Breng 4 koekjes naar elke gast"), houdt de kar zelf de stand
      bij ("🛒 nog 2 kamers"), en in een kamer zónder kar staat bij het
      bakje "🛒 Sleep de kar hierheen". Bij het smullen: "😋 4 koekjes"
      (of "😋 4 koekjes elk" als er twee gasten in die kamer liggen).

   Krap scherm? Dan past de indeling zich aan, in deze volgorde:
     * vanaf vijf bakjes (of in een laag/klein kader) worden de kaartjes een
       maatje kleiner en zet de correctie zich ONDER de naam - dat maakt een
       kaartje ruim 50 px smaller zonder dat het hoger wordt;
     * op een klein kader (320 px breed: 286 x 312 css-px) vervalt de
       keuzestrook - een tik op de zak schakelt de schep dan door, en op de
       zak staat welke ("pak 2");
     * en vanaf vier bakjes op zo'n klein kader staat alleen het begin van de
       naam op het kaartje ("🐰 Wolk"), zodat de opdrachtkaart en de
       correcties leesbaar blijven.

   De getallen komen uit ctx.state.sommen.deel(N, band, dag) - in band 3 is
   dat exact de bevroren koekjesSom uit de geteste demo. Aan die som, aan de
   controle en aan de volgorde vullen -> controleren -> rondje is niets
   veranderd; alleen aan wat je ziet en hoort.
---------------------------------------------------------------- */
(function () {
'use strict';

var C = null;          /* de ctx */
var K = null;          /* de kar-toestand */
var LAY = null;        /* de indeling van dit beeld: kader + plaatser */
var HAND = [1, 2, 5];

/* De bakjes staan als echte voxelbakjes op de keukenvloer. Ze staan als BREUK
   van de kamer (Rooms.plek): de keuken werd met K1 1,5x groter (120 x 114 in
   plaats van 80 x 76) en dan schuiven de bakjes mee. De breuken zijn de oude
   voxels gedeeld door 80 en 76, dus alle onderlinge afstanden zijn 1,5x zo
   groot geworden en blijven ruim boven wat rooms.js eist: minstens 15 voxels
   van de kast (33,6), de zak (66,18), de kar (48,66), de plant (108,93) én
   van elkaar, en 12 van een deuropening. Anders schuift rooms.js ze zelf naar
   een ander vloervakje.
   Ze liggen in twee "kolommen" (links x-z = -60, rechts x-z = +72), zodat de
   kaartjes met de naam erop ook op het scherm in twee kolommen staan. */
var VAKBREUK = [[0.05, 0.5789], [0.65, 0.0526], [0.25, 0.7895],
                [0.85, 0.2632], [0.4, 0.9474], [0.95, 0.3684]];
var VAK_PLEK = VAKBREUK.map(function (b) {
  var p = Rooms.plek('keuken', b[0], b[1]);
  return [p.x, p.z];
});
var POT_PLEK = (function () { var p = Rooms.plek('keuken', 0.6, 0.6316); return [p.x, p.z]; })();
var KEUKEN_D = (Rooms.get('keuken') || {}).d || 114;   /* diepte van de keuken */
var RIJ = 52;              /* hoogte van één rij kaartjes in css-pixels */
                           /* (op een krap scherm 50: dan past er nog een rij bij) */
var DIEP_UI = 150;         /* tekendiepte van kaart en knoppen: vóór de bakjes */
/* de knoppen van het spel zijn 'vast': ze staan op een schermplek (zetOp),
   dus deze kamerplek is alleen hun vertrekpunt - midden in de keuken */
var KAR_KNOP = Rooms.plek('keuken', 0.5, 0.5);

/* dezelfde dierpictogrammen als de rest van het hotel (games/tobbe.js) */
var SOORT_ICO = { puppy: '🐶', poes: '🐱', konijn: '🐰', gans: '🦆' };
var KIND_ICO = { hond: '🐶', poes: '🐱', konijn: '🐰', gans: '🦆' };
function dierIco(g) {
  if (!g) return '🐾';
  return SOORT_ICO[g.soort] || KIND_ICO[g.kind] || '🐾';
}

/* ---------- één regel op een knopje: pictogram, woord, getal ----------
   'hotbron' geeft de rij-opmaak van een sleepbron (pictogram groot, getal
   groot), 'hotwolk' geeft het woord ernaast de leesbare wolkjesmaat. Zo
   staat er nooit een kaal pictogram in de keuken (HOTEL.md 9). Het getal
   staat alleen in .get: daar leest de speeltest het aantal uit. */
var CHIP = 'hotbron hotwolk';
/* Op een klein scherm (een telefoon van 360 px: het kader is dan maar
   326 x 312 css-px) en in een laag kader (liggend: 826 x 190) worden
   pictogram, woord en getal een maatje kleiner: anders passen zes bakjes met
   een naam én een correctie erop er niet meer bij. Het woord blijft boven de
   11 px, dus leesbaar. `mini` is alleen het echt kleine scherm: daar past de
   keuzestrook met drie knoppen niet en wordt het één knop die doorschakelt. */
var krap = false, mini = false, kort = 0;
/* de naam op het kaartje; op een heel klein kader met veel bakjes ingekort */
function naamKort(n) {
  return (kort && n.length > kort) ? n.slice(0, kort) : n;
}
/* `erbij` is het staartje na een misser ("· 8 te veel"): dat hoort ín het
   kaartje van dat bakje, niet in een los wolkje ernaast. Zo staat de
   correctie altijd bij de naam van het dier waar hij over gaat, hoeft er
   geen knop bij (hooguit 16 per kamer) en valt er nooit een wolkje weg. */
function chip(ico, woord, getal, erbij, doel) {
  var i = krap ? ' style="font-size:1.15rem"' : '';
  var w = krap ? ' style="font-size:.72rem"' : '';
  var g = krap ? ' style="font-size:1rem"' : '';
  /* Krap (of Els kijkt mee)? Dan zet de correctie zich ONDER de naam in
     plaats van erachter. Het kaartje wordt daar ruim 50 px smaller van en
     blijft toch 48 px hoog (de minimumhoogte van een tikdoel is ruimer dan
     die twee regeltjes nodig hebben), dus er passen twee kaartjes naast
     elkaar in plaats van één - en op die tweede regel is plek voor het
     doelgetal van Els ("· 8 eraf → 4"), zonder dat dat een knop kost. */
  var tweeRij = (krap || doel !== null && doel !== undefined) && woord && erbij;
  var staart = erbij ? '· ' + erbij : '';
  var mik = (doel === null || doel === undefined) ? ''
    : '<span style="opacity:.62"> ' + C.ui.esc('→ ' + doel) + '</span>';
  var zin = tweeRij ? C.ui.esc(woord) + '<br>' + C.ui.esc(staart) + mik
                    : (woord ? C.ui.esc(woord) : '');
  return '<span class="ico"' + i + '>' + (ico || '') + '</span>' +
    (zin ? '<span class="zeg"' + w + '>' + zin + '</span>' : '') +
    (getal === null || getal === undefined ? ''
      : '<span class="get"' + g + '>' + getal + '</span>') +
    (staart && !tweeRij
      ? '<span class="zeg"' + w + '>' + C.ui.esc(staart) + mik + '</span>' : '');
}

/* ---------- welke gasten en welke kamers doen mee? ---------- */
function gasten() {
  return C.state.gasten().filter(function (g) { return !!g.bed; });
}
function kamersMetGast() {
  var uit = [], zien = {};
  gasten().forEach(function (g) {
    if (zien[g.kamer]) return;
    zien[g.kamer] = 1;
    var bak = C.wereld.slots(g.kamer, 'bak')[0];
    if (bak) uit.push({ kamer: g.kamer, slot: bak.id });
  });
  return uit;
}
function niveau(aantal) {
  if (!aantal) return 0;
  var per = K.per || 1;
  return Math.max(1, Math.min(4, Math.ceil(aantal / per * 4)));
}

/* =====================================================================
   DE INDELING VAN DE KEUKEN
   Elk kaartje draagt nu een woord, dus het is drie keer zo breed als een
   pictogram. Zes bakjes + pot + zak + opdrachtkaart + twee knoppen passen
   dan niet meer "zomaar" op de vloer: op een telefoon is de keukenvloer
   maar 312 x 156 css-pixels. Daarom rekenen we de plekken zelf uit in
   schermpixels (World.vloer() geeft de vloer in het kader) en zetten we ze
   daarna terug om naar voxels. De knoppenlaag hoeft dan niets uit elkaar te
   schuiven - juist dát schuiven maakt tekst onleesbaar. Een kaartje zoekt
   zijn plek in de kolom van zijn eigen bakje en gaat alleen een rij hoger of
   lager als het daar niet past, dus je ziet nog steeds bij welk bakje het
   hoort.
===================================================================== */
function kader() {
  var el = document.getElementById('worldHits') || document.getElementById('world');
  var s = C.wereld.schaal ? C.wereld.schaal() : null;
  var vl = (window.World && World.vloer) ? World.vloer() : null;
  var w = (el && el.clientWidth) || 380, h = (el && el.clientHeight) || 440;
  mini = w * h < 140000;
  krap = mini || h < 240;
  RIJ = mini ? 50 : 52;
  return { w: w, h: h, k: (s && s.k) || 1,
           fx: vl ? vl.x : w / 2 - 156, fy: vl ? vl.y : h * 0.4,
           portret: h > w * 0.75, krap: krap, mini: mini };
}
/* u = 2*(x-z) en v = (x+z) - 2*y: precies de projectie van world.js */
function csX(F, u) { return F.fx + (u + 2 * KEUKEN_D) * F.k; }
function csY(F, v) { return F.fy + v * F.k; }
/* een schermplek terug naar een voxelplek in de keuken; diep = x+z, dat is
   de tekendiepte (wie staat er vóór) */
function plek(F, X, Y, diep) {
  var u = (X - F.fx) / F.k - 2 * KEUKEN_D;
  var v = (Y - F.fy) / F.k;
  return { x: (diep + u / 2) / 2, z: (diep - u / 2) / 2, y: (diep - v) / 2 };
}
/* de rijen liggen vast: zo staan de kaartjes netjes onder elkaar */
function rijY(F, Y) {
  var y0 = 32, max = Math.max(0, Math.floor((F.h - 28 - y0) / RIJ));
  var n = Math.max(0, Math.min(max, Math.round((Y - y0) / RIJ)));
  return y0 + n * RIJ;
}
function laatsteRij(F) { return rijY(F, F.h); }

/* hoe groot is dit knopje echt? (na het tekenen op te meten) */
function maat(id, bw, bh) {
  var el = document.querySelector('[data-hot="' + id + '"]');
  return { w: (el && el.offsetWidth) || bw, h: (el && el.offsetHeight) || bh };
}

/* de plaatser: hij houdt bij wat er al staat en zoekt de vrije plek die het
   dichtst bij de wens ligt - eerst een rij hoger of lager (dan blijft een
   kaartje in de kolom van zijn bakje), daarna stapjes opzij. De stapjes
   opzij zijn klein (26 px) en gaan ver (±14): in een liggend kader is het
   maar 190 px hoog en 826 px breed, dus dan moet een kaartje ver opzij
   kunnen én precies in een gaatje tussen twee andere kaartjes passen. */
var STAP_X = 26, PAD_X = 14, PAD_Y = 5;
function pakker(F) {
  var vast = [];
  /* hoeveel dekken deze twee elkaar af? (m = de kier die we willen houden) */
  function dek(a, b, m) {
    var dx = (a.w + b.w) / 2 + m - Math.abs(a.X - b.X);
    var dy = (a.h + b.h) / 2 + m - Math.abs(a.Y - b.Y);
    return (dx > 0 && dy > 0) ? dx * dy : 0;
  }
  /* `hard` = alleen kijken naar wat écht niet mag overlappen (onze eigen
     kaartjes); de deuren van het hotel wegen lichter en mogen in het uiterste
     geval onder een kaartje verdwijnen - de kamerbalk onderin brengt je ook
     naar de gang. */
  function last(b, m, hard) {
    var s = 0, i, g;
    for (i = 0; i < vast.length; i++) {
      g = vast[i].g === undefined ? 1 : vast[i].g;
      if (hard && g < 1) continue;
      s += dek(vast[i], b, m) * g;
    }
    return s;
  }
  function klem(b) {
    b.X = Math.max(b.w / 2 + 3, Math.min(Math.max(b.w / 2 + 3, F.w - b.w / 2 - 3), b.X));
    b.Y = Math.max(b.h / 2 + 3, Math.min(Math.max(b.h / 2 + 3, F.h - b.h / 2 - 3), b.Y));
    return b;
  }
  return {
    /* een plek die al vast staat (de opdrachtkaart, de keuzestrook, een
       een deur van het hotel). `gewicht` zegt hoe
       erg het is om er tóch over te moeten: een deur van het hotel weegt
       lichter dan onze eigen tekst, want de kamerbalk onderin brengt je ook
       naar de gang. */
    houd: function (X, Y, w, h, gewicht) {
      vast.push(klem({ X: X, Y: Y, w: w, h: h, g: gewicht === undefined ? 1 : gewicht }));
    },
    /* de vrije plek die het dichtst bij de wens ligt. Eerst met een kier van
       4 px, dan zonder kier, en als de keuken écht vol staat de plek die het
       minst afdekt - liever een kaartje dat een pixel raakt dan een kaartje
       dat een ander helemaal onleesbaar maakt. `b.vrij` zegt of het echt
       gelukt is; een extra wolkje dat niet past laten we liever weg.
       modus: 'y' = blijf vlak bij je voorwerp, 'x' = blijf op de rij, 'h' = eerst
       naast de wens kijken, 'n' = de plek die er in pixels het dichtst bij
       ligt, anders eerst een rij hoger of lager. */
    zoek: function (X, Y, w, h, modus, geenDeur) {
      /* de verticale stap is precies één rij: dan blijft alles op het
         rijenraster staan en gaan de kaartjes niet scheef door het kader
         zwerven (ook een hoog blok schuift met hele rijen) */
      var dy = RIJ, dx = STAP_X, ix, iy;
      var hor = modus === 'h' || modus === 'x';
      /* de kandidaten op kosten sorteren: hoeveel pixels van de wens af, en
         welke richting mag het liefst */
      function kost(p) {
        var px = Math.abs(p[0]) * dx, py = Math.abs(p[1]) * dy;
        if (modus === 'n') return px * px + py * py;
        if (hor) return px * 2 + py * 3.1 + (p[1] ? 6 : 0);
        return py * 2 + px * 3.1 + (p[1] < 0 ? 10 : 0);
      }
      var pad = [];
      for (iy = -PAD_Y; iy <= PAD_Y; iy++)
        for (ix = -PAD_X; ix <= PAD_X; ix++) {
          /* 'y' = blijf bij je eigen voorwerp: hooguit twee stapjes (52 px)
             opzij, want de zak moet wel op de zak blijven liggen */
          if (modus === 'y' && Math.abs(ix) > 2) continue;
          if (modus === 'x' && iy) continue;
          pad.push([ix, iy]);
        }
      pad.sort(function (a, b) { return kost(a) - kost(b); });
      /* vier rondes: met een kier ernaast, zonder kier, en daarna hetzelfde
         maar dan mag een deur van het hotel eronder verdwijnen */
      var RONDE = geenDeur ? [[4, false], [0, false]]
                           : [[4, false], [0, false], [4, true], [0, true]];
      var beste = null, bestLast = -1, i, r, q, b, l;
      for (r = 0; r < RONDE.length; r++) {
        for (i = 0; i < pad.length; i++) {
          q = pad[i];
          b = { X: X + q[0] * dx, Y: Y + q[1] * dy, w: w, h: h };
          klem(b);
          /* Een plek die tegen de rand geklemd is valt van het rijenraster af
             en versnippert dan de rijen voor de rest. In de eerste twee
             rondes slaan we die over; lukt het nergens, dan mag het alsnog. */
          if (r < 2 && Math.abs(b.Y - (Y + q[1] * dy)) > 1) continue;
          l = last(b, RONDE[r][0], RONDE[r][1]);
          if (!l) { b.vrij = true; vast.push(b); return b; }
          if (r === 0) {
            /* voor de noodplek kijken we naar de ÉCHTE overlap (zonder kier):
               een kaartje dat een ander een paar pixels raakt is beter dan
               een kaartje dat er half over heen valt */
            l = last(b, 0, false);
            if (bestLast < 0 || l < bestLast) { bestLast = l; beste = b; }
          }
        }
      }
      beste = beste || klem({ X: X, Y: Y, w: w, h: h });
      beste.vrij = false;
      vast.push(beste);
      return beste;
    }
  };
}
/* knopje dat er al staat naar zijn definitieve plek verhuizen */
function zetOp(id, X, Y, diep, bw, bh, modus, groei, geenDeur) {
  var m = maat(id, bw, bh);
  var b = LAY.P.zoek(X, Y, m.w + (groei || 0), m.h + (groei || 0), modus, geenDeur);
  var q = plek(LAY.F, b.X, b.Y, diep);
  C.hotspots.maak({ id: id, x: q.x, z: q.z, y: q.y });
  return b;
}
/* de deuren van de keuken staan er al: die plekken houden we vrij, anders
   dekt een kaartje de uitgang af (de knoppen van het hotel wijken wel uit,
   maar in een laag kader is er nergens meer plek om naartoe te wijken) */
function deurenVrij(F) {
  var r = C.wereld.kamer('keuken');
  ((r && r.deurPunten) || []).forEach(function (dp) {
    LAY.P.houd(csX(F, 2 * (dp.x - dp.z)), csY(F, dp.x + dp.z - 18), 52, 52, 0.25);
  });
}

/* =====================================================================
   START
===================================================================== */
function start(ctx) {
  C = ctx;
  var g = gasten();
  if (!g.length) {
    C.ui.wolk('kar', { id: 'vk_leeg', door: 'voerkar', icoon: '🛏', tekst: 'nog geen gasten' });
    setTimeout(function () { C && C.ui.wolkWeg('vk_leeg'); C && C.sluit(); }, 1800);
    return;
  }
  var bewaard = C.state.ruw().kar;
  if (bewaard && bewaard.T) K = bewaard;
  else {
    var som = C.state.sommen.deel(g.length, C.state.band(), C.state.dag());
    K = { T: som.T, per: som.k, rest: som.r, zak: som.T, vak: {}, pot: 0,
          hand: 1, missers: 0, vol: false, geleverd: {}, t0: C.ui.nu() };
    g.forEach(function (q) { K.vak[q.id] = 0; });
    C.state.ruw().kar = K;
  }
  g.forEach(function (q) { if (K.vak[q.id] === undefined) K.vak[q.id] = 0; });
  C.wereld.naar('keuken');
  if (K.vol) { rondje(); } else { vulOp(); }
}

function stop() {
  vakjesWeg();
  LAY = null;
  if (C) { C.hotspots.wisAlles(); C.hotspots.laat(); }
  C = null;
}

/* =====================================================================
   DE VAKJES: echte bakjes op de keukenvloer
===================================================================== */
function vakjesWeg() {
  if (!K || !K.slots) return;
  K.slots.forEach(function (q) { Rooms.meubelWeg(q.slot); });
  K.slots = null;
  World.herbouw();
}
function vakjesNeer() {
  var g = gasten(), i, m;
  K.slots = [];
  for (i = 0; i < g.length && i < VAK_PLEK.length; i++) {
    m = Rooms.meubelZet('keuken', 'bakje', VAK_PLEK[i][0], VAK_PLEK[i][1]);
    if (!m) continue;
    var sl = Rooms.slot('keuken', m.id);
    if (sl) sl.tijdelijk = 1;
    K.slots.push({ slot: m.id, gast: g[i].id, naam: g[i].naam });
  }
  m = Rooms.meubelZet('keuken', 'bakje', POT_PLEK[0], POT_PLEK[1]);
  if (m) {
    var sp = Rooms.slot('keuken', m.id);
    if (sp) sp.tijdelijk = 1;
    K.slots.push({ slot: m.id, gast: '__pot', naam: 'snoeppot' });
  }
  World.herbouw();
}
/* =====================================================================
   VULLEN
===================================================================== */
/* Staan de bakjes van deze kar er nog? De aantallen (K.vak, K.pot) worden wél
   bewaard, maar de tijdelijke bakje-meubels niet: na "verder spelen" midden in
   het vullen is K.slots dus een lijst met plekken die niet meer bestaan. Dan
   zetten we de bakjes opnieuw neer; de aantallen staan per gast in K.vak, dus
   het kind ziet zijn eigen verdeling terug. */
function slotsKwijt() {
  var i;
  if (!K.slots || !K.slots.length) return true;
  for (i = 0; i < K.slots.length; i++)
    if (!Rooms.slot('keuken', K.slots[i].slot)) return true;
  return false;
}
function vulOp() {
  if (slotsKwijt()) { K.slots = null; vakjesNeer(); }
  teken();
}

/* ---------- de opdracht in twee gewone zinnen ---------- */
function zinnen(g) {
  var n = g.length;
  return ['Verdeel ' + K.T + ' koekjes over ' + n + (n === 1 ? ' gast' : ' gasten'),
          /* Els doet het voor: dan zegt de tweede regel het antwoord per
             bakje, op precies dezelfde plek waar de opdracht stond. Zo komt
             er geen extra wolkje bij in een keuken die al vol staat. */
          K.spook ? '🩺 Iedereen ' + K.per + ', rest in de pot'
                  : '🫙 Ieder evenveel, de rest in de pot'];
}
/* De somregel onder de zinnen.
   - Groep 3 (band 3) kent het deelteken nog niet, en een regel als
     "12 koekjes, 3 bakjes" zegt hetzelfde als de zin erboven met een derde
     woord voor dezelfde dingen. Voor band 3 staat er dus GEEN somregel: het
     kaartje is dan twee gewone zinnen.
   - Vanaf groep 4 komt "12 : 3" erbij, maar alléén als het eerlijk uitkomt.
     Blijft er iets over, dan zou "26 : 6" een deling met rest suggereren en
     die hoort pas in groep 5; dan blijft het bij de twee zinnen.
   - Let op de deler: die volgt uit het aantal gasten en kan 6 zijn, terwijl
     groep 4 alleen de tafels 1-5 en 10 kent. Dat mag hier, want de UITKOMST
     (K.per) komt uit state.sommen.deel en blijft binnen die tafels: 30 : 6
     hoort bij "6 x 5 = 30". Er komt hier geen som bij die het kind nog niet
     kan; het blijft bij dezelfde getallen als de zin erboven.
   - Nooit een vraagteken tussen twee uitdrukkingen (HOTEL.md 9). */
function somRegel(g) {
  if (C.state.band() >= 4 && !K.rest) return K.T + ' : ' + g.length;
  return '';
}
/* De keuzestrook aan de kaart: hoeveel koekjes komen er per tik uit de zak?
   Drie knoppen mét woord; welke aan staat zie je aan de kleur (handAan).
   Op een krap scherm is er geen plek voor drie: dan staat er één knop die
   vertelt wat je nu pakt en die bij een tik doorschakelt (1 - 2 - 5), net
   als een tik op de zak zelf. */
function volgendeHand() {
  return HAND[(HAND.indexOf(K.hand) + 1) % HAND.length];
}
function handKeuzes() {
  /* Op een heel klein kader (320 px breed: 286 x 312) kost de strook een
     hele rij, en die rij is nodig voor de bakjes. Dan schakelt een tik op de
     zak de schep door en staat er "pak 2" op de zak zelf. */
  if (mini) return null;
  return HAND.map(function (h) {
    return { id: 'h' + h, icoon: '🍪', tekst: 'pak ' + h,
             kies: function () { zetHand(h); } };
  });
}
/* De knop die nu aan staat krijgt de "aan"-kleur van het hotel (peach, zoals
   .hand .btn.on op het startblad). Géén ✅: dat vinkje betekent in dit spel
   "klaar" ("✅ Alle bakjes vol!"), en één teken mag niet twee dingen zeggen. */
function handAan() {
  if (mini) return;
  var el = document.querySelector('[data-hot="vk_kaart_keuzes"] [data-kz="h' + K.hand + '"]');
  if (!el) return;
  el.style.background = 'var(--peach)';
  el.style.borderColor = 'var(--peach-d)';
}
function zetHand(h) {
  K.hand = h;
  teken();
  C.snd.tik();
}
function opdrachtKaart(F, g) {
  var zin = zinnen(g), som = somRegel(g);
  /* Eerst neerzetten (nog niets in beeld: hits.js tekent pas aan het eind
     van dit beeldje), dan echt opmeten, en dán de kaart MET zijn keuzestrook
     als één blok op een vrije plek zetten. Zo weten we de maten precies en
     staat de strook altijd tegen de onderrand van de kaart. */
  var keuzes = handKeuzes(), strook = !!keuzes;
  var a = plek(F, F.w / 2, 90, DIEP_UI);
  C.ui.somkaart({ x: a.x, z: a.z, kamer: 'keuken' }, som, {
    id: 'vk_kaart', icoon: '🍪', regel: zin, hoog: a.y, pad: false,
    keuzes: keuzes
  });
  /* ui.somkaart tekent de somregel altijd, ook als hij leeg is: dat geeft een
     blanco regel onder de twee zinnen (band 3 heeft geen somregel). En zonder
     keuzestrook zet hij er een leeg antwoordvakje bij, terwijl er niets te
     typen valt. Beide halen we hier weg, vóór we de kaart opmeten. */
  if (!som) {
    var rij0 = document.querySelector('[data-hot="vk_kaart"] .somrij');
    if (rij0) rij0.style.display = 'none';
  }
  if (!strook) {
    var vak0 = document.querySelector('[data-hot="vk_kaart"] .somvak');
    if (vak0) vak0.style.display = 'none';
  }
  var mk = maat('vk_kaart', 260, 78);
  var ms = strook ? maat('vk_kaart_keuzes', 180, 64) : { w: 0, h: -5 };
  var blokH = mk.h + 5 + ms.h, blokW = Math.max(mk.w, ms.w);
  var wensX = F.portret ? F.w / 2 : Math.min(F.w * 0.24, 150);
  /* gewicht 6: de opdracht is het enige dat een kind ECHT moet kunnen lezen,
     dus als de keuken overvol staat gaat er liever iets anders overheen dan
     dit kaartje (de plaatser kiest de minst zware overlap) */
  var b = LAY.P.zoek(wensX, 8 + blokH / 2, blokW, blokH, 'x');
  b.g = 6;
  var kY = b.Y - (blokH - mk.h) / 2, sY = kY + mk.h / 2 + ms.h / 2 + 5;
  var q = plek(F, b.X, kY, DIEP_UI);
  /* tikken leest de opdracht voor - nooit automatisch (HOTEL.md 9) */
  C.hotspots.maak({ id: 'vk_kaart', x: q.x, z: q.z, y: q.y, titel: zin.join('. '),
    aan: function () { C.ui.spreek(zin[0] + '. ' + zin[1].replace(/^\S+\s/, '')); } });
  if (strook) {
    var t = plek(F, b.X, sY, DIEP_UI);
    C.hotspots.maak({ id: 'vk_kaart_keuzes', x: t.x, z: t.z, y: t.y });
  }
  handAan();
  /* Het blok kaart+strook is hoger dan een rij en eindigt dus meestal midden
     in de rij eronder. Die rij claimen we er helemaal bij (alleen onder het
     blok, niet over de hele breedte): anders schuift er een kaartje twee of
     drie pixels onder de strook, en dat leest als een fout. `b` staat in de
     lijst van de plaatser, dus dit past de gereserveerde plek meteen aan. */
  var boven = b.Y - b.h / 2, onder = b.Y + b.h / 2;
  var rijOnder = rijY(F, onder + 24);
  if (rijOnder - 28 < onder) {
    b.h = (rijOnder + 28) - boven;
    b.Y = boven + b.h / 2;
  }
}

/* ---------- de zak koekjes ---------- */
function zakNeer(F) {
  C.hotspots.bron('zak', {
    id: 'vk_zak', icoon: '🍪', aantal: K.zak, hand: 'pak ' + K.hand, hoog: 16,
    klas: K.zak ? 'hotwolk' : 'hotwolk leeg', prio: 10,
    titel: 'zak met ' + K.zak + ' koekjes, pak ' + K.hand + ' per tik',
    tik: function () { zetHand(volgendeHand()); },
    sleep: {
      dropSel: '[data-drop="vak"]',
      ghostHTML: function () { return '<div class="karghost">🍪</div>'; },
      canDrag: function () { return K.zak > 0; },
      onDrop: function (t) { verplaats(t.getAttribute('data-h-id'), K.hand); }
      /* geen onTap: de tik loopt via `tik` hierboven, precies één keer */
    }
  });
  /* Wat de zak te zeggen heeft ("nog in de zak", "zak is leeg") komt ÍN het
     kaartje van de zak, net als de correctie bij een bakje. Zo hangt er geen
     los wolkje bij en verdwijnt de melding nooit door plaatsgebrek.
     bron() kent `vast` en eigen html niet: die zetten we er los op. Vast =
     deze knop wijkt nooit; de knoppen van het hotel schuiven eromheen. */
  C.hotspots.maak({
    id: 'vk_zak', vast: true,
    html: chip('🍪', null, K.zak, K.zakZeg) +
          '<span class="hand">pak ' + K.hand + '</span>',
    klas: 'hotbron hotwolk' + (K.zak ? '' : ' leeg') + (K.zakZeg ? ' hulp' : ''),
    titel: 'zak met ' + K.zak + ' koekjes, pak ' + K.hand + ' per tik' +
           (K.zakZeg ? ' (' + K.zakZeg + ')' : '')
  });
  /* het pilletje "pak 2" hangt buiten de knop: 14 px extra vrijhouden */
  zetOp('vk_zak', csX(F, 2 * (44 - 12)), rijY(F, csY(F, 56) - 26), 56, 130, 48, 'y', 14);
}

/* ---------- de bakjes met naam en aantal ---------- */
function bakjeNeer(F, q, gast) {
  var pot = q.gast === '__pot';
  var aantal = pot ? K.pot : (K.vak[q.gast] || 0);
  var sl = Rooms.slot('keuken', q.slot);
  if (!sl) return null;
  var ico = pot ? '🫙' : dierIco(gast);
  var woord = pot ? 'pot' : naamKort(q.naam);
  var doel = pot ? K.rest : K.per;
  var mis = doel - aantal;
  /* Na een misser staat er in dit kaartje bij hoeveel er nog bij of af moet:
     "🐶 Boef 12 · 8 te veel". Dat staat pal naast de naam van het dier, dus
     het kan nooit bij het verkeerde bakje horen, en het kost geen extra knop
     (een kamer houdt hooguit 16 knoppen). Het kaartje krijgt dan de zachte
     hulp-kleur van de oude wolkjes. */
  var zeg = (K.feedback && mis) ? Math.abs(mis) + (mis > 0 ? ' erbij' : ' eraf') : null;
  /* Els erbij? Dan staat haar doelgetal er lichtgrijs achter: "· 8 eraf → 4".
     Dat is haar oude spookcijfer, maar nu ín het kaartje - dus zonder knop en
     dus zonder dat het bij zes bakjes wegvalt door het plafond van 16.
     In een laag kader (liggend: 826 x 190) en op een klein kader met vier of
     meer bakjes is er geen millimeter over: daar laten we het doelgetal weg
     en zegt alleen de kaart het ("🩺 Iedereen 4, rest in de pot"). Anders
     valt er een kaartje over een ander heen, en dat is erger dan één getal
     minder. */
  var mik = (K.spook && zeg && F.h >= 240 && !kort) ? doel : null;
  C.wereld.setBak('keuken', q.slot, niveau(aantal));
  C.hotspots.maak({
    id: 'vk_' + q.gast, kamer: 'keuken', x: sl.x, z: sl.z, y: 10,
    html: chip(ico, woord, aantal, zeg, mik), kind: 'drop', drop: 'vak',
    data: { id: q.gast }, klas: CHIP + (zeg ? ' hulp' : ''),
    prio: pot ? 9 : 10, vast: true,
    titel: (pot ? 'de snoeppot: ' + aantal + ' koekjes'
                : q.naam + ' heeft ' + aantal + ' koekjes') +
           (zeg ? ', ' + zeg : '') + (mik !== null ? ', hier hoort ' + mik + ' in' : ''),
    aan: function () { verplaats(q.gast, K.hand); }
  });
  var b = zetOp('vk_' + q.gast, csX(F, 2 * (sl.x - sl.z)),
                rijY(F, csY(F, sl.x + sl.z) - 26), sl.x + sl.z, 150, 48);
  return { b: b, sl: sl, aantal: aantal, doel: doel, ico: ico };
}

function teken() {
  if (!C || !K || K.vol) return;
  C.hotspots.wisAlles();
  var g = gasten(), F = kader(), gm = {};
  /* Vanaf vijf bakjes worden de kaartjes een maatje kleiner, ook op een groot
     scherm: met een naam ÉN een correctie erop ("🐶 Boef 12 · 8 eraf") passen
     zes kaartjes anders niet meer naast elkaar. En op een echt klein kader
     (320 px breed: 286 x 312) korten we vanaf vier bakjes de naam in tot vier
     letters - dan blijven de opdrachtkaart en de correcties leesbaar, wat
     belangrijker is dan de hele naam. */
  if (g.length >= 5) krap = true;
  kort = F.mini && g.length >= 4 ? 4 : 0;
  LAY = { F: F, P: pakker(F) };
  g.forEach(function (a) { gm[a.id] = a; });

  /* 1. de uitgangen blijven vrij, daarna de opdracht: het enige kaartje */
  deurenVrij(F);
  opdrachtKaart(F, g);
  /* 3. de knoppen; ze dragen altijd een woord */
  /* Staand liggen de knoppen onderaan het kader, onder de bakjes. Liggend is
     het kader maar 190 px hoog: dan staan ze naast elkaar op de onderste rij
     rechts, zodat de rijen erboven vrij blijven voor de bakjes.
     Blijft er onder de laatste rij kaartjes geen halve knop over, dan gaan de
     knoppen op die laatste rij staan - anders raken ze elkaar. */
  var kY = F.h - 27;
  if (kY - laatsteRij(F) < 48) kY = laatsteRij(F);
  var rij = F.portret ? kY : laatsteRij(F);
  knop('vk_klaar', '🛒', 'Klaar', 'hotwolk goed', 11, 'de kar is klaar', check,
       F.portret ? F.w * 0.74 : F.w - 60, rij);
  knop('vk_opnieuw', '↩', 'Opnieuw', 'hotwolk', 7, 'alles opnieuw verdelen', leeg,
       F.portret ? F.w * 0.26 : F.w - 175, rij);
  /* Els blijft staan zolang er twee pogingen op zitten - ook terwijl haar
     hulpregel op de kaart staat, precies zoals de basisversie het deed: een
     kind mag haar zo vaak vragen als het wil. */
  /* Els staat staand niet in het MIDDEN van een rij: op een smal kader zou
     hij de rij dan in twee te kleine helften knippen. Links, één rij boven de
     twee knoppen: dan blijft de rechterhelft van die rij bruikbaar. */
  if (K.missers >= 2)
    knop('vk_els', '🩺', 'Els helpt', 'hotwolk hulp', 8, 'buurvrouw Els doet het voor',
         hulp, F.portret ? F.w * 0.3 : F.w - 295,
         F.portret ? laatsteRij(F) - RIJ : rij);
  /* 4. de zak */
  zakNeer(F);
  /* 5. de bakjes, in dezelfde volgorde als de gasten. Staat er een misser
     open (K.feedback), dan draagt elk bakje zelf zijn correctie: er komt geen
     los wolkje en geen los spookcijfer bij, dus je ziet ze ALLEMAAL - ook met
     zes bakjes en ook terwijl Els meekijkt. */
  (K.slots || []).forEach(function (q) { bakjeNeer(F, q, gm[q.gast]); });
  C.wereld.vuil();
}

function knop(id, ico, woord, klas, prio, titel, fn, X, Y) {
  C.hotspots.maak({
    id: id, kamer: 'keuken', x: KAR_KNOP.x, z: KAR_KNOP.z, y: 0,
    html: chip(ico, woord, null), klas: klas, prio: prio, vast: true,
    titel: titel, aan: fn
  });
  zetOp(id, X, Y, DIEP_UI, 130, 48);
}

function verplaats(id, aantal) {
  if (!id || K.vol) return;
  var k = Math.min(aantal, K.zak);
  if (k <= 0) {
    /* de zak zegt het zelf op zijn kaartje: "🍪 0 · zak is leeg" */
    K.zakZeg = 'zak is leeg';
    C.snd.zacht();
    teken();
    return;
  }
  K.zak -= k;
  if (id === '__pot') K.pot += k; else K.vak[id] = (K.vak[id] || 0) + k;
  K.feedback = null;
  K.zakZeg = null;
  teken();
  C.snd.plop(K.hand);
}
function leeg() {
  gasten().forEach(function (a) { K.vak[a.id] = 0; });
  K.pot = 0; K.zak = K.T; K.feedback = null; K.spook = 0; K.zakZeg = null;
  teken();
  C.snd.terug();
}

/* ---------- de vriendelijke controle (zelfde regels als vroeger) ---------- */
function check() {
  var g = gasten();
  if (K.zak > 0) {
    /* er zit nog voer in de zak: dat zegt de zak zelf op zijn kaartje, en de
       bakjes vertellen er meteen bij hoeveel ze nog missen */
    K.missers++; K.feedback = true;
    K.zakZeg = 'nog in de zak';
    teken(); C.snd.zacht();
    return;
  }
  var goed = g.every(function (a) { return K.vak[a.id] === K.per; }) && K.pot === K.rest;
  if (!goed) {
    K.missers++; K.feedback = true;
    teken(); C.snd.zacht();
    return;
  }
  K.vol = true;
  K.feedback = null;
  K.spook = 0;
  K.zakZeg = null;
  C.state.ruw().snoeppot += K.pot;
  C.state.tel(K.missers === 0, C.ui.nu() - K.t0);
  C.taakKlaar('voer', { sterren: 1 });
  C.snd.tover();
  vakjesWeg();
  rondje();
}

/* ---------- Els doet het voor ----------
   Vroeger legde Els een spookcijfer ÓP elk bakje (wereld.getalTag). Dat was
   één knop per bakje: bij zes gasten viel de helft ervan weg door het plafond
   van 16 knoppen per kamer (hits.js) én de deuren van de keuken erbij. Nu
   zegt Els het waar het kind toch al kijkt en waar het geen knop kost:
     * op het opdrachtkaartje: "🩺 Iedereen 4, rest in de pot" (zinnen());
     * in elk bakje zelf: "🐶 Boef 12 · 8 eraf" (bakjeNeer).
   Samen is dat precies haar voordoen: het doelgetal én wat je moet doen. */
function hulp() {
  K.spook = 1;
  teken();                       /* de hulpzin op het kaartje + de bakjes */
  C.state.zetGezien('voerkar_els');
  C.snd.brief();
}

/* =====================================================================
   HET RONDJE: de kar door de gang en de bakjes vullen
===================================================================== */
function rondje() {
  if (!C || !K) return;
  C.hotspots.wisAlles();
  var open = kamersMetGast().filter(function (q) { return !K.geleverd[q.kamer]; });
  karHotspot(open.length);
  leenBakjes();
  if (!open.length) {
    C.ui.wolk('kar', { id: 'vk_af', icoon: '✅', tekst: 'Alle bakjes vol!',
                       hoog: 22, klas: 'goed', prio: 12,
                       tik: function () { klaarMetRondje(); } });
    setTimeout(function () { if (C && K && K.vol) klaarMetRondje(); }, 2600);
  } else if (!telGeleverd()) {
    /* de eerste keer: zeg wat er nu gaat gebeuren */
    C.ui.wolk('kar', { id: 'vk_duw', icoon: '🛒',
                       tekst: 'Breng ' + K.per + ' koekjes naar elke gast',
                       hoog: 30, prio: 10 });
  }
  C.wereld.vuil();
}
function telGeleverd() {
  var n = 0, k;
  for (k in K.geleverd) if (K.geleverd.hasOwnProperty(k)) n++;
  return n;
}
function klaarMetRondje() {
  if (!C) return;
  C.state.ruw().kar = null;
  C.ui.wolkWeg('vk_af');
  C.sluit();
}

/* de kar is zelf een hotspot: sleep hem op een deur of op een bakje */
function karHotspot(nogOpen) {
  if (!C) return;
  var kar = C.wereld.ding('kar');
  if (!kar) return;
  C.hotspots.maak({
    id: 'karhot', kamer: kar.kamer, x: kar.x, z: kar.z, y: 16,
    html: nogOpen ? chip('🛒', 'nog', nogOpen) +
            '<span class="zeg">' + (nogOpen === 1 ? 'kamer' : 'kamers') + '</span>'
          : chip('🛒', 'kar is leeg', null),
    titel: nogOpen ? 'de voerkar: nog ' + nogOpen + (nogOpen === 1 ? ' kamer' : ' kamers')
                   : 'de voerkar is leeg',
    klas: CHIP, prio: 11,
    volg: function () {
      var q = C.wereld.ding('kar');
      return q ? { x: q.x, z: q.z, y: 16 } : null;
    },
    aan: function () { hoeDan(); }
  });
  var el = document.querySelector('[data-hot="karhot"]');
  if (el && !el.__sleep) {
    el.__sleep = 1;
    C.sleep(el, {
      dropSel: '[data-drop="deur"],[data-drop="bak"]',
      ghostHTML: function () { return '<div class="karghost">🛒</div>'; },
      onDrop: function (t) {
        if (t.getAttribute('data-drop') === 'deur') duwNaar(t.getAttribute('data-h-naar'));
        else lever(t.getAttribute('data-h-kamer'), t.getAttribute('data-h-slot'));
      },
      onTap: function () { hoeDan(); }
    });
  }
}
/* tik op de kar: vertel in woorden hoe je hem verplaatst */
function hoeDan() {
  if (!C) return;
  C.ui.wolk('kar', { id: 'vk_hoe', icoon: '👉', tekst: 'Sleep de kar naar een deur',
                     hoog: 44, prio: 11 });
  C.wereld.vuil();
}

/* Zolang de kar vol is, is het BAKJE van het hotel even van de voerkar:
   tikken betekent dan "hier afleveren". */
function leenBakjes() {
  kamersMetGast().forEach(function (q) {
    C.hotspots.pak('bak_' + q.kamer + '_' + q.slot, function () { lever(q.kamer, q.slot); });
  });
}

function duwNaar(kamerId) {
  if (!kamerId) return;
  C.ui.wolkWeg('vk_hoe');
  C.wereld.dingZet('kar', { kamer: kamerId });
  C.wereld.naar(kamerId);
  C.snd.kar();
  if (window.Hotel) Hotel.render();
  rondje();
}

/* het bakje vullen: de dieren van die kamer lopen erheen en smullen */
function lever(kamerId, slotId) {
  var kar = C.wereld.ding('kar');
  if (!kar || kar.kamer !== kamerId) {
    var sl = C.wereld.slot(kamerId, slotId);
    C.ui.wolk(sl ? { x: sl.x, z: sl.z, kamer: kamerId } : 'kar',
              { id: 'vk_hier', icoon: '🛒', tekst: 'Sleep de kar hierheen',
                klas: 'hulp', hoog: 26, prio: 11 });
    C.wereld.vuil();
    return;
  }
  var hier = gasten().filter(function (g) { return g.kamer === kamerId; });
  if (!hier.length || K.geleverd[kamerId]) return;
  var samen = 0;
  hier.forEach(function (g) { samen += K.vak[g.id] || 0; K.vak[g.id] = 0; });
  K.geleverd[kamerId] = samen;
  C.ui.wolkWeg('vk_hier');
  C.ui.wolkWeg('vk_hoe');
  C.wereld.setBak(kamerId, slotId, 4);
  hier.forEach(function (g) { g.gegeten = true; g.behoefte = 'spelen'; g.blij = false; });
  C.wereld.feest(hier.map(function (g) { return g.id; }));
  C.snd.plop(3);
  C.state.bewaar();
  if (window.Hotel) Hotel.render();
  rondje();
  /* Ná rondje(), want die begint met wisAlles() en zou dit wolkje meteen
     weer weghalen. In een kamer met twee gasten krijgt ELK dier K.per
     koekjes: dat zegt het wolkje er dan bij, zodat het getal niet als
     kamertotaal wordt gelezen. */
  C.ui.wolk(hier[0].id, { id: 'vk_smul', icoon: '😋', getal: K.per,
                          tekst: hier.length > 1 ? 'koekjes elk' : 'koekjes',
                          klas: 'goed' });
  setTimeout(function () { if (C) C.ui.wolkWeg('vk_smul'); }, 2600);
  C.wereld.vuil();
}

/* =====================================================================
   AANMELDEN
===================================================================== */
Games.register({
  id: 'voerkar',
  naam: 'De voerkar',
  kamer: 'keuken',
  hotspot: { obj: 'kar', icoon: '🛒', label: 'Voerkar', hoog: 16 },
  unlock: function (N) { return N >= 1; },
  start: start,
  stop: stop
});
})();
