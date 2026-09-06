/* ---------------------------------------------------------------
   hotel.js - de gastenstroom en de dag.

   Wat hier gebeurt:
     * de BEL op de balie haalt de volgende gast (alleen als er een bed
       vrij is; anders zegt de bel dat vriendelijk).
     * CHECK-IN = de twee poortvragen uit de geteste demo (voorraad vs.
       dagen x nieuw) plus "waar mag hij slapen?". Een fout antwoord
       brengt je NOOIT een stap verder, maar er gaat ook nooit iets
       kapot: je mag zo vaak proberen als je wil.
     * BEHOEFTEN staan als pictogram boven het dier. Het dier loopt zelf
       naar de plek en wacht daar. Niets vervalt, niemand wordt zielig
       van wachten.
     * UITCHECKEN: familie aan de balie, bedankbriefje voor de muur en
       de rekening (nachten x prijs, munten van Zilverhoef).
     * DE DAG: ochtendronde (prikbord, hooguit 3 taakjes) -> vrij spelen
       -> avondronde (de lamp op de balie). Geen enkele ronde zet iets
       op slot.
---------------------------------------------------------------- */
var Hotel = (function () {
'use strict';

/* Bij elk behoefte-pictogram hoort ALTIJD het woord (HOTEL.md 9): een bolletje
   met alleen 🛁 erop leest een kind van zes niet. De pictogrammen en de lange
   tekst staan in BEHOEFTE (state.js, bevroren); hier staat het korte woord dat
   naast het plaatje past. Komt er ooit een nieuwe behoefte bij, dan valt het
   label terug op de naam van de behoefte zelf (en klaagt de console één keer),
   zodat er nooit een woordloos bolletje in de wereld komt. */
var WENSWOORD = { eten: 'eten', kamer: 'bed', bad: 'bad', spelen: 'spelen',
                  zwemmen: 'zwemmen', souvenir: 'souvenir' };
/* Waarmee is een wens INGELOST? 🛏 bed door een bed, 🍪 eten door gegeten, en
   al het andere (🛁 bad, 🧶 spelen, 🏊 zwemmen, 🎁 souvenir) door g.blij. Eén
   lijstje, zodat behoefteKlaar() en wensAf() nooit uit elkaar lopen. */
var WENS_BLIJ = { bad: 1, spelen: 1, zwemmen: 1, souvenir: 1 };
var wensKlacht = {};
function wensWoord(behoefte) {
  if (WENSWOORD[behoefte]) return WENSWOORD[behoefte];
  if (!wensKlacht[behoefte] && window.console && console.warn) {
    wensKlacht[behoefte] = 1;
    console.warn('behoefte "' + behoefte + '" heeft geen kort woord in WENSWOORD ' +
      '(hotel.js); het pictogram krijgt nu de naam van de behoefte als label (HOTEL.md 9).');
  }
  return String(behoefte || 'wens');
}

/* de plattegrond: waar hangt elke ruimte in het overzicht */
var KAART = { receptie: [1, 2], gang: [2, 2], kamer1: [2, 1], kamer2: [2, 3],
              keuken: [3, 2], tuin: [4, 2], wasserij: [3, 3], zwembad: [4, 3] };

/* =====================================================================
   HULP
===================================================================== */
function alleDieren() {
  var l = state.gasten.slice();
  if (state.nieuweGast) l.push(state.nieuweGast);
  return l;
}
function gastById(id) {
  if (state.nieuweGast && state.nieuweGast.id === id) return state.nieuweGast;
  return gastVan(id);
}
function decorPlek(kamerId, naam) {
  var r = Rooms.get(kamerId);
  if (!r) return null;
  for (var i = 0; i < r.decor.length; i++)
    if (r.decor[i].n === naam) return { kamer: kamerId, x: r.decor[i].x, z: r.decor[i].z };
  var d = World.dingPlek(naam);
  if (d) return { kamer: d.kamer, x: d.x, z: d.z };
  return null;
}
function klem(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v); }
/* Een rustige plek in de TUIN: Rooms schuift hem naar een vrij vakje toe, dus
   hij blijft goed ook als een ander ticket er decor bij zet. Dit is de
   terugval voor 🏊 en 🎁 zolang het zwembad en de kraam er nog niet zijn. */
function tuinPlek(x, z) {
  var v = Rooms.vrijVak ? Rooms.vrijVak('tuin', x, z) : null;
  return { kamer: 'tuin', x: v ? v.x : x, z: v ? v.z : z };
}
/* Het punt VÓÓR een rechthoek {x0,x1,z0,z1}: midden op de zijde die naar het
   midden van de kamer kijkt, een paar voxels ervoor. Een kraam staat tegen een
   rand, dus dat is precies "midden voor de toonbank". */
function voorRand(kamerId, rc, af) {
  var r = Rooms.get(kamerId);
  if (!r || !rc || rc.x0 === undefined || rc.z0 === undefined) return null;
  af = af === undefined ? 8 : af;
  var cx = (rc.x0 + rc.x1) / 2, cz = (rc.z0 + rc.z1) / 2;
  var dx = Math.min(rc.x0, r.w - rc.x1), dz = Math.min(rc.z0, r.d - rc.z1);
  var p = dx <= dz ? { x: rc.x0 <= r.w / 2 ? rc.x1 + af : rc.x0 - af, z: cz }
                   : { x: cx, z: rc.z0 <= r.d / 2 ? rc.z1 + af : rc.z0 - af };
  return { kamer: kamerId, x: klem(p.x, 4, r.w - 4), z: klem(p.z, 4, r.d - 4) };
}
/* waar hoort dit dier te staan met zijn behoefte? */
function plekVanBehoefte(g) {
  var b = g.behoefte;
  if (b === 'kamer' || !g.kamer) return Rooms.plek('receptie', 0.375, 0.775);
  if (b === 'eten') {
    var s = Rooms.slots(g.kamer, 'bak')[0];
    return s ? { kamer: g.kamer, x: s.sx, z: s.sz } : null;
  }
  if (b === 'bad') {
    var t = Rooms.slot('tuin', 'tobbe');
    return t ? { kamer: 'tuin', x: t.x - 14, z: t.z } : null;
  }
  if (b === 'spelen') {
    var m = decorPlek(g.kamer, 'mand');
    return m ? { kamer: m.kamer, x: m.x - 12, z: m.z } : null;
  }
  if (b === 'zwemmen') {
    /* de startrand van het bad: op het dek, net vóór x0 (zwembad-spel, G1).
       De kamer komt uit een ander ticket; zolang die er niet is (of er nog
       geen weg naartoe loopt) wacht het dier gewoon in de tuin. */
    var zb = Rooms.get('zwembad');
    if (!zb || !(Rooms.pad(g.kamer, 'zwembad') || []).length) return tuinPlek(58, 106);
    if (zb.dek && zb.dek.start)          /* het dek VÓÓR de waterlijn (P1a-F1) */
      return { kamer: 'zwembad', x: klem(zb.dek.start.x, 4, zb.w - 4),
               z: klem(zb.dek.start.z, 4, zb.d - 4) };
    if (zb.bad && zb.bad.x0 !== undefined)
      return { kamer: 'zwembad', x: klem(zb.bad.x0 - 6, 4, zb.w - 4),
               z: klem((zb.bad.z0 + zb.bad.z1) / 2, 4, zb.d - 4) };
    var v = Rooms.vrijVak ? Rooms.vrijVak('zwembad', 12, zb.d / 2) : null;
    return { kamer: 'zwembad', x: v ? v.x : 12, z: v ? v.z : Math.round(zb.d / 2) };
  }
  if (b === 'souvenir') {
    /* midden vóór de souvenirkraam in de tuin (kraam-spel, G5); de zone komt
       uit een ander ticket, anders een vrij vakje in de tuin. */
    var tu = Rooms.get('tuin');
    return voorRand('tuin', tu && tu.zones ? tu.zones.kraam : null) || tuinPlek(106, 58);
  }
  return null;
}
/* "Hier wacht iemand": hoeveel gasten hebben in DEZE ruimte iets van jou
   nodig? Een gast wiens wens al ingelost is telt niet mee, en een wens die
   nergens naartoe kan (geen plek voor) ook niet - anders blijft er een
   bolletje staan waar je niets kunt doen. */
function wachtIn(kamerId) {
  var n = 0;
  state.gasten.forEach(function (g) {
    if (behoefteKlaar(g)) return;
    var p = plekVanBehoefte(g);
    if (p && p.kamer === kamerId) n++;
  });
  if (kamerId === 'receptie' && state.nieuweGast) n++;
  return n;
}
function behoefteKlaar(g) {
  if (g.behoefte === 'kamer') return !!g.bed;
  if (g.behoefte === 'eten') return !!g.gegeten;
  return !!g.blij;      /* WENS_BLIJ: bad, spelen, zwemmen, souvenir */
}

/* het dier loopt zelf naar zijn plek en wacht daar geduldig */
function stuurNaarBehoefte(g) {
  var p = plekVanBehoefte(g);
  if (!p) return;
  g.waar = p.kamer;
  World.reis(g.id, p.kamer, { x: p.x, z: p.z, na: 'wacht' });
}

/* =====================================================================
   HET SCHERM: hud, kamerbalk, hotspots
===================================================================== */
function hud() {
  var e = $('#dayNum'); if (e) e.textContent = state.dag;
  e = $('#muntNum'); if (e) e.textContent = state.munten;
  e = $('#sterNum'); if (e) e.textContent = state.sterren;
  e = $('#letterNum'); if (e) e.textContent = state.brieven.length;
  e = $('#rondeNaam');
  if (e) e.textContent = state.ronde === 'ochtend' ? '☀️ Ochtendronde'
    : state.ronde === 'avond' ? '🌙 Avondronde' : '🐾 Vrij spelen';
}

/* De kamerbalk wordt ÉÉN keer opgebouwd en daarna alleen bijgewerkt: de
   knoppen blijven dus dezelfde knoppen. Anders springt de rij bij elke
   gebeurtenis terug naar links, verdwijnt je zijwaartse stand en tik je
   zomaar de kamer ernaast aan. */
var balkChips = null, takenSig = '';
function kamerbalk() {
  var host = $('#kamerbalk');
  if (!host) return;
  var nu = World.actief();
  if (!balkChips || !host.firstChild) {
    var h = '';
    Rooms.lijst().forEach(function (r) {
      h += '<button class="kchip" type="button" data-kamer="' + r.id + '">' +
        '<span class="ki">' + r.icoon + '</span><span class="kn">' + esc(r.naam) + '</span>' +
        '<span class="kb" hidden></span></button>';
    });
    h += '<button class="kchip kaart" type="button" id="kaartBtn"><span class="ki">🗺️</span>' +
      '<span class="kn">Plattegrond</span></button>';
    host.innerHTML = h;
    balkChips = {};
    $$('#kamerbalk [data-kamer]').forEach(function (b) {
      var id = b.getAttribute('data-kamer');
      balkChips[id] = b;
      b.onclick = function () { naarKamer(id); };
    });
    $('#kaartBtn').onclick = plattegrond;
  }
  Rooms.lijst().forEach(function (r) {
    var b = balkChips[r.id];
    if (!b) return;
    var aan = r.id === nu;
    if (b.classList.contains('aan') !== aan) b.classList.toggle('aan', aan);
    var w = wachtIn(r.id), bdg = b.querySelector('.kb');
    if (!bdg) return;
    /* leeg = weg: het bolletje houdt nooit een oud getal vast */
    var tekst = w ? String(w) : '';
    if (bdg.textContent !== tekst) bdg.textContent = tekst;
    if (bdg.hidden !== !w) bdg.hidden = !w;
  });
}

function plattegrond() {
  var nu = World.actief();
  var h = '<h2>🗺️ De plattegrond</h2><p class="hint">Tik op een ruimte om er naartoe te gaan.</p>' +
    '<div class="pgrid">';
  Rooms.lijst().forEach(function (r) {
    var k = KAART[r.id] || [1, 1], w = wachtIn(r.id);
    h += '<button class="pcel' + (r.id === nu ? ' aan' : '') + '" type="button" data-pk="' + r.id +
      '" style="grid-column:' + k[0] + ';grid-row:' + k[1] + '">' +
      '<span class="pi">' + r.icoon + '</span><span class="pn">' + esc(r.naam) + '</span>' +
      (w ? '<span class="kb">' + w + '</span>' : '') + '</button>';
  });
  h += '</div><div class="row center" style="margin-top:12px">' +
    '<button class="btn go" type="button" id="pgDicht">Sluiten</button></div>';
  openSheet(h);
  $$('#sheet [data-pk]').forEach(function (b) {
    b.onclick = function () { closeSheet(); naarKamer(b.getAttribute('data-pk')); };
  });
  $('#pgDicht').onclick = closeSheet;
}

function naarKamer(id) {
  if (!Rooms.get(id)) return;
  World.naar(id);
  state.kamerNu = id;
  if (window.Snd) Snd.deur();
  render();
}

/* ---------- hotspots van het hotel zelf ---------- */
function hotspots() {
  Hits.wisEigenaar('hotel');
  var nu = World.actief(), r = Rooms.get(nu);
  if (!r) return;
  /* deuren */
  r.deurPunten.forEach(function (dp) {
    var doel = Rooms.get(dp.naar);
    if (!doel) return;
    var w = wachtIn(dp.naar);
    /* de deur is ook een sleep-doel: zo duw je de voerkar de gang in */
    Hits.maak({ id: 'deur_' + nu + '_' + dp.naar, door: 'hotel', kamer: nu,
                x: dp.x, z: dp.z, y: 9, icoon: doel.icoon,
                label: doel.naam, titel: 'Ga naar ' + doel.naam,
                badge: w ? String(w) : null, klas: 'hotdeur', prio: 8,
                drop: 'deur', data: { naar: dp.naar, kamer: nu },
                aan: function () { naarKamer(dp.naar); } });
  });
  /* vaste voorwerpen per ruimte */
  if (nu === 'receptie') {
    var bp = decorPlek('receptie', 'bel');
    if (bp) Hits.maak({ id: 'bel', door: 'hotel', kamer: 'receptie', x: bp.x, z: bp.z, y: 20,
                        icoon: '🔔', label: 'Bel', titel: 'Bel voor de volgende gast',
                        klas: 'hotbel', prio: 10, aan: bel });
    var pp = decorPlek('receptie', 'prikbord');
    if (pp) Hits.maak({ id: 'prikbord', door: 'hotel', kamer: 'receptie', x: pp.x, z: pp.z, y: 22,
                        icoon: '📋', label: 'Prikbord',
                        badge: openTaken() ? String(openTaken()) : null,
                        titel: 'Het prikbord met de taakjes', prio: 9, aan: prikbordTik });
    /* De kassa zit in de muntenknop bovenin en de avondronde in de balk:
       twee knoppen minder op de balie, want tijdens een check-in staat daar
       ook nog het naamplaatje en het wenswolkje van de gast. De lamp gaat
       alleen aan als er 's avonds echt iets te doen is. */
    var lp = World.dingPlek('balielamp');
    if (avondKlaar() && lp) {
      Hits.maak({ id: 'lamp', door: 'hotel', kamer: 'receptie', x: lp.x, z: lp.z, y: 20,
                  icoon: '🌙', label: 'Avond', titel: 'De avondronde',
                  klas: 'hotlamp aan', prio: 9, aan: avondronde });
    } else Hits.weg('lamp');
  }
  /* bedden en bakjes */
  Rooms.slots(nu, 'bed').forEach(function (s) {
    var g = gastInBed(nu, s.id);
    /* Een BEZET bed krijgt geen knop: het slapende dier met zijn naamplaatje
       vertelt het al, en zo blijft de kamer rustig om naar te kijken. */
    if (g) { Hits.weg('bed_' + nu + '_' + s.id); return; }
    Hits.maak({ id: 'bed_' + nu + '_' + s.id, door: 'hotel', kamer: nu, x: s.x, z: s.z, y: 13,
                icoon: '🛏', label: 'Vrij bed', titel: 'Een vrij bed',
                kind: 'drop', drop: 'bed', data: { kamer: nu, slot: s.id },
                klas: 'hotbed vrij', prio: 7,
                aan: function () { tikBed(nu, s.id); } });
  });
  /* de speelmand: hier wordt de wens "spelen" ingelost */
  var mp = decorPlek(nu, 'mand');
  if (mp) {
    var wil = state.gasten.filter(function (g) { return g.kamer === nu && g.behoefte === 'spelen' && !g.blij; });
    Hits.maak({ id: 'mand_' + nu, door: 'hotel', kamer: nu, x: mp.x, z: mp.z, y: 8,
                icoon: '🧶', label: 'Speelmand', titel: 'De speelmand',
                badge: wil.length ? String(wil.length) : null, prio: 7,
                aan: function () { tikMand(nu); } });
  }
  Rooms.slots(nu, 'bak').forEach(function (s) {
    /* bakjes die een spel even zelf neerzet (de vakjes van de voerkar)
       krijgen geen hotelknop: dat spel doet ze zelf */
    if (s.tijdelijk) { Hits.weg('bak_' + nu + '_' + s.id); return; }
    var niv = World.bakStand(nu, s.id);
    var gasten = state.gasten.filter(function (g) { return g.kamer === nu; });
    Hits.maak({ id: 'bak_' + nu + '_' + s.id, door: 'hotel', kamer: nu, x: s.x, z: s.z, y: 7,
                icoon: niv > 0 ? '🍪' : '🍽', label: niv > 0 ? 'Vol' : 'Leeg',
                badge: !niv && gasten.length ? '!' : null,
                titel: niv > 0 ? 'Er ligt eten in het bakje' : 'Het bakje is nog leeg',
                kind: 'drop', drop: 'bak', data: { kamer: nu, slot: s.id },
                klas: 'hotbak' + (niv ? ' vol' : ''), prio: 7,
                aan: function () { tikBak(nu, s.id); } });
  });
  /* Behoefte-pictogrammen boven de dieren die er nu zijn. Ze hangen bóven het
     naamplaatje, en twee dieren naast elkaar krijgen hun wolkje net op een
     andere hoogte - anders dekken de rondjes elkaar af. Een dier dat op dit
     moment aan het eten is heeft geen wens nodig. */
  /* Speelt er een spel in deze kamer? Dan zijn de knoppen van het spel de
     baas: de wens-wolkjes van het hotel gaan even weg (ze komen terug zodra
     het spel klaar is) zodat ze geen enkele spelknop kunnen afdekken. */
  var spelHier = false;
  if (window.Games && Games.open()) {
    var spelId = Games.open(), sd = Games.get(spelId);
    /* de kamer waar het spel echt speelt (bedden valt soms terug op kamer 2),
       plus: heeft het spel hier knoppen staan? dan wijken de wolkjes ook */
    var speelKamer = Games.actieveKamer ? Games.actieveKamer() : null;
    spelHier = (speelKamer === nu) || !!(sd && sd.kamer === nu) ||
      Hits.lijst().some(function (q) { return q.door === spelId && q.kamer === nu; });
  }
  var wensNr = 0;
  alleDieren().forEach(function (g) {
    if (g.waar !== nu) return;
    if (spelHier) { Hits.weg('wens_' + g.id); return; }
    /* de gast die aan de balie ingecheckt wordt heeft al een eigen wolkje */
    if (state.nieuweGast && state.nieuweGast.id === g.id) { Hits.weg('wens_' + g.id); return; }
    var bh = BEHOEFTE[g.behoefte];
    if (!bh || behoefteKlaar(g)) return;
    var d0 = World.dier(g.id);
    if (d0 && d0.staat === 'eet') { Hits.weg('wens_' + g.id); return; }
    var hoog = 58 + (wensNr % 2) * 13;
    wensNr++;
    Hits.maak({ id: 'wens_' + g.id, door: 'hotel', kamer: nu, x: 0, z: 0, y: hoog,
                icoon: bh.icoon, label: wensWoord(g.behoefte),
                titel: g.naam + ' ' + bh.tekst, klas: 'hotwens', prio: 6,
                volg: function () {
                  var d = World.dier(g.id);
                  if (!d) return null;
                  return { x: d.x, z: d.z, y: hoog, d: d.x + d.z + 0.6 };
                },
                aan: function () { toast(g.naam + ' ' + bh.tekst + '. ' + bh.icoon, 'kind'); } });
  });
}

/* =====================================================================
   DE BEL EN DE CHECK-IN
===================================================================== */
function bel() {
  if (state.checkin) { paintCheckin(); toast('🛎️ Er staat al iemand', 'kind'); return; }
  var vrij = bedVrij();
  if (!vrij) {
    /* vriendelijk en zonder leeswerk: één wolkje bij de bel (HOTEL.md 9) */
    if (window.Snd) Snd.zacht();
    Ui.wolk('bel', { id: 'bel_vol', door: 'wolk', icoon: '🛏', getal: maxGasten(),
                     tekst: 'alle bedden vol', klas: 'hulp', hoog: 26, prio: 12 });
    setTimeout(function () { Ui.wolkWeg('bel_vol'); World.vuil(); }, 3200);
    return;
  }
  bordDicht();                         /* het prikbord gaat dicht: nu de gast */
  var g = pakGast();
  var geld = sommen.geld(state.band);
  g.nachten = geld.nachten;
  g.prijs = geld.prijs;
  g.betaald = geld.betaald;
  g.dagIn = state.dag;
  g.kamer = null; g.bed = null; g.waar = 'receptie';
  g.behoefte = 'kamer'; g.geslapen = 0; g.gegeten = false; g.blij = false;
  state.nieuweGast = g;
  initCheckin(g);
  if (window.Snd) Snd.bel();
  World.sync(alleDieren());
  var dp = Rooms.deur('receptie', 'gang');
  World.zet(g.id, 'receptie', dp ? dp.ix : 60, dp ? dp.iz : 60);
  World.ga(g.id, WACHTPLEK.x, WACHTPLEK.z, 'wacht');
  naarKamer('receptie');
  paintCheckin();
  toast(g.naam + ' staat aan de balie! 🔔', 'happy');
}

/* ---------- BEVROREN REKENWERK: dezelfde twee poortvragen ---------- */
function initCheckin(g) {
  var samen = dagVerbruik();
  var extra = g ? g.scoops : 0;
  state.checkin = {
    gastId: g.id,
    samen: samen, extra: extra, nieuw: samen + extra,
    dagen: state.levering, voorraad: state.scoops,
    stap: 1, fouten1: 0, fouten2: 0, invoer: '', keuze: null, weg: false,
    t0: Ui.nu()
  };
}

/* "1 schep" en "2 scheppen", "1 dag" en "4 dagen": een zin met een fout
   meervoud leest een kind van zes twee keer (HOTEL.md 9) */
function scheppen(n) { return meervoud(n, 'schep', 'scheppen'); }
function dagen(n) { return meervoud(n, 'dag', 'dagen'); }

/* korte, woordloze hulp: pictogrammen en getallen (HOTEL.md 9) */
function scoopjes(n) {
  var s = '', i;
  if (n > 8) return n + ' 🥄';
  for (i = 0; i < n; i++) s += '🥄';
  return s || '0';
}

/* =====================================================================
   CHECK-IN ÍN DE WERELD (HOTEL.md 9)
   Op de balie ligt ÉÉN sommenkaartje. Daarop staat eerst een gewone zin die
   de getallen in hotelwoorden noemt ("De gasten eten 0 scheppen per dag" /
   "Boef eet 2 erbij. Samen?"), daaronder
   de som met het cijferpad. Bij vraag 2 hoort geen pad maar één strook met
   drie knoppen mét woord: losse pijltjes door de kamer bleken onleesbaar.
===================================================================== */
var ciKaart = null;

/* WAAR HANGT DE KAART? Niet meer boven de bel (22,40): met een zin erboven is
   het kaartje 260 px breed en de keuzestrook eronder nog 62 px hoog, en dat
   blok stond precies over de gast die aan de balie wacht - de speeltest zag
   50% van het naamplaatje verdwijnen bij vraag 1 en 100% bij vraag 2.
   Nu: kaart rechts achterin (0,875 x 0,25 van de kamer = 105,30 sinds K1),
   gast links vooraan (WACHTPLEK).
   Gemeten met het breedste naamplaatje uit de pool ("Stampertje", 88 px):
     420x860  0% van het plaatje, 0% van het dier
     860x420  0% / 0%
     1000x640 0% / 0%
     320x640  0% / 0%  (met de smalle-schermregels uit style.css: daar krimpt
              het kaartje van 266 naar 170 px, anders staat het over het dier -
              vóór die regels was het daar 70% van het plaatje en 91% van het
              dier, en dat is precies wat de verifier vond)
   Kaart én strook blijven in alle vier de kaders binnen beeld en de strook
   blijft tegen de kaart aan (gat 0-6 px). Hoger dan 16 mag niet: dan loopt het
   plaatje wél onder de kaart (13%). Over de tekst van de kaart ligt nergens
   iets (0%). Wel het omgekeerde: op een liggende telefoon (kader 836x200) is
   er geen vrij plekje meer voor de deurknop, en hits.js laat een knop dan
   staan waar hij staat; de kaart ligt er dan bovenop (de kaart is dieper in
   beeld). De deurknop blijft met zijn hart in beeld en dus aan te tikken. */
/* Alle plekken in de receptie zijn BREUKEN van de kamer (Rooms.plek): de
   receptie is met K1 1,5x groter geworden en dan schuift dit mee. De breuken
   zijn precies de oude voxels van de kamer van 80 x 80 (70/80, 20/80). */
var CI_PLEK = Rooms.plek('receptie', 0.875, 0.25);
var CI_HOOG = Rooms.hoogte('receptie', 0.2);   /* was 16 bij w = 80 */
/* In een LAAG kader (liggende telefoon: 200 px) moeten de kaart (~92 px) en
   de keuzestrook eronder (~64 px) er samen onder passen. Passen ze niet, dan
   klemt de knoppenlaag de strook tegen de onderrand en ligt hij over de tekst
   van de kaart. We tillen de kaart daar een paar hoogtestappen op; één stap
   is 2k schermpixels (World.schaal), net zoals games/tobbe.js dat doet. */
function ciHoog() {
  var f = document.getElementById('world');
  var h = (f && f.clientHeight) || 480;
  if (h >= 300) return CI_HOOG;
  var s = World.schaal ? World.schaal() : null, k = (s && s.k) || 1;
  return CI_HOOG + Math.ceil(20 / (2 * k));
}
/* En daarom wacht de gast links vóór de balie in plaats van midden ervoor:
   met het kaartje rechts achterin en het dier links vooraan zijn ze in elk
   beeld los van elkaar te zien (gemeten met het breedste naamplaatje: 0%
   van het plaatje én 0% van het dier bedekt, staand en liggend).

   M1c: 0,25 x 0,925 was op één telefoonmaat te weinig. De sommenkaart is
   258 px breed (op een scherm van 360 px of smaller krimpt hij naar 170) en de
   hotspot-laag klemt hem tegen de RECHTERrand van het kader; hij staat dus op
   elke staande maat even ver naar rechts als hij kan. Gemeten in het kader
   (binnenwerk, na M1a+M1b), met het doosje van 56 px waarin het dier onder
   zijn naamplaatje zit:

     kader      kaart          linkerrand kaart   dier       vrij
     386x468    258 px         126 px             43..99     27 px
     356x431    258 px          96 px             38..94      2 px
     341x387    258 px          81 px             35..91    -10 px  (375x667!)
     326x395    170 px         154 px             32..88     66 px
     286x304    170 px         114 px             25..81     33 px

   Op 375 x 667 (dpr 2) paste het dus net niet: 18% van het dier en 15% van het
   naamplaatje gingen schuil achter de kaart, waar w1.js hooguit 10% toestaat.
   Optillen helpt daar niet - de kaart zou 86 px hoger moeten en dan valt hij
   uit het kader - en naar rechts kán de kaart niet meer. Daarom staat de gast
   nu 6 voxels verder van de balie en 3 voxels verder naar voren: in
   schermtermen 9 stappen van (x - z), dat is 12-14 px naar links op deze
   maten. Nagemeten: 0% en 0% op 320x640, 360x740, 375x667, 390x844, 420x860,
   667x375, 740x360, 750x342, 844x390 en 860x420, staand én liggend, ook na
   het kantelen en met een tweede gast erbij.
   Verder naar links kan niet: de z-vleugel van de balie staat op x 11..19
   (decor `baliez`), dus dan zou de gast ín de balie staan. */
var WACHTPLEK = Rooms.plek('receptie', 0.2, 0.95);

/* De drie keuzes bij vraag 2. LET OP de koppeling met het bevroren
   vergelijk(): dat vergelijkt dagen × per dag MET de voorraad.
     'meer'    -> er is méér nodig dan er in huis is  -> TE WEINIG eten
     'precies' -> het komt precies uit
     'minder'  -> er is minder nodig dan er ligt      -> er BLIJFT OVER
   De knoppen praten over het eten in huis, dus 'te weinig' hoort bij 'meer'.
   De pijltjes zijn versiering; het woord doet het werk. */
var CI_KEUZE = [
  { id: 'meer',    icoon: '⬇', tekst: 'te weinig' },
  { id: 'precies', icoon: '⚖', tekst: 'precies' },
  { id: 'minder',  icoon: '⬆', tekst: 'blijft over' }
];

function paintCheckin() {
  /* Eerst de OUDE kaart netjes afsluiten, dan de laag legen. Elke hertekening
     maakt een nieuwe somkaart onder dezelfde id (ci_som); zijn weg() zegt de
     kaderluisteraar op, laat de cijferstrook los en haalt kaart + pad + keuzes
     weg. Zonder dat hangt het aan de opruimhaak van de hotspot-laag (H1
     onWeg) of aan het merkteken van ui.js (M1a) - allebei vangnetten, geen
     opdracht. Met weg() erbij is de volgorde ook onder een oudere hits.js
     goed. */
  if (ciKaart && ciKaart.weg) { try { ciKaart.weg(); } catch (e) { /* laat staan */ } }
  Hits.wisEigenaar('checkin');
  ciKaart = null;
  var v = state.checkin;
  if (!v) return;
  var g = gastById(v.gastId);
  if (!g) { state.checkin = null; return; }

  if (v.stap === 1) {
    /* twee korte zinnen: eerst wat er nu elke dag opgaat, dan wat deze gast
       erbij eet - en de vraag zelf ("Samen?") */
    ciKaart = Ui.somkaart(CI_PLEK, v.samen + ' + ' + v.extra + ' =', {
      id: 'ci_som', door: 'checkin', open: true, max: 2, hoog: ciHoog(),
      icoon: '🥄',
      regel: ['De gasten eten ' + scheppen(v.samen) + ' per dag',
              g.naam + ' eet ' + v.extra + ' erbij. Samen?'],
      onOk: function (n) { v.invoer = (n === null ? '' : String(n)); antwoord1(); }
    });
    if (v.fouten1 > 0) ciKaart.hulp(scoopjes(v.samen) + ' + ' + scoopjes(v.extra));
  } else if (v.stap === 2) {
    /* Na een misser komt het product er zelf bij te staan (4 × 2 = 8): dat is
       de hulp, geen los hintje. Zelfde pictogram als bij vraag 1: het gaat nog
       steeds over scheppen eten. */
    var tot = v.dagen * v.nieuw;
    ciKaart = Ui.somkaart(CI_PLEK, v.dagen + ' × ' + v.nieuw + (v.fouten2 > 0 ? ' = ' + tot : ''), {
      id: 'ci_som', door: 'checkin', pad: false, hoog: ciHoog(),
      icoon: '🥄',
      regel: ['Elke dag ' + scheppen(v.nieuw) + ', ' + dagen(v.dagen) + ' lang',
              '📦 In huis: ' + scheppen(v.voorraad) + '. Genoeg?'],
      keuzeTitel: 'is er genoeg eten?',
      keuzes: CI_KEUZE.map(function (k) {
        return { id: k.id, icoon: k.icoon, tekst: k.tekst,
                 kies: function () { antwoord2(k.id); } };
      })
    });
  } else if (v.stap === 3) {
    var vrij = bedVrij();
    Ui.wolk(g.id, {
      id: 'ci_vraag', door: 'checkin', icoon: '🛏', prio: 11,
      tekst: vrij ? 'Kies een bed' : 'Alles bezet',
      tik: function () { if (vrij) naarKamer(vrij.kamer); }
    });
    if (vrij && World.actief() !== vrij.kamer) {
      Ui.wolk(Rooms.plek('receptie', 0.775, 0.05), {
        id: 'ci_wijs', door: 'checkin', icoon: Rooms.get(vrij.kamer).icoon,
        tekst: Rooms.get(vrij.kamer).naam, hoog: ciHoog(), prio: 10,
        tik: function () { naarKamer(vrij.kamer); }
      });
    }
  }
  World.vuil();
}

/* ---------- BEVROREN: antwoord 1 en 2 (zelfde rekencheck) ---------- */
function antwoord1() {
  var v = state.checkin;
  if (!v.invoer) { toast('👆 Tik eerst een getal', 'kind'); return; }
  if (+v.invoer === v.nieuw) {
    v.stap = 2; v.invoer = ''; paintCheckin(); Snd.ja();
    toast('Precies! 🎉', 'happy');
    State.tel(v.fouten1 === 0, Ui.nu() - v.t0);
  } else {
    v.fouten1++; v.invoer = ''; paintCheckin(); Snd.zacht();
    toast('🥄 Tel ze samen', 'kind');
  }
}

function antwoord2(keus) {
  var v = state.checkin;
  if (keus === vergelijk(v)) {
    v.stap = 3; paintCheckin(); Snd.ja(); toast('Goed gerekend! 🎉', 'happy');
    State.tel(v.fouten2 === 0, Ui.nu() - v.t0);
  } else {
    /* de kaart rekent het product nu zelf voor; de toast zegt precies hetzelfde
       (het oude "Tel met sprongen" wees naar een sprongenrijtje dat er niet
       meer is). Alleen de tekst is anders - de telling blijft gelijk. */
    v.fouten2++; paintCheckin(); Snd.zacht();
    toast('🥄 ' + v.dagen + ' × ' + v.nieuw + ' = ' + (v.dagen * v.nieuw), 'kind');
  }
}

/* ---------- het bed toewijzen ---------- */
function tikBed(kamerId, slotId) {
  var v = state.checkin;
  var er = gastInBed(kamerId, slotId);
  if (er) { toast(er.naam + ' slaapt hier. 💤', 'kind'); return; }
  if (v && v.stap === 3) { wijsBed(kamerId, slotId); return; }
  toast('🛏 Bel eerst een gast', 'kind');
}

function wijsBed(kamerId, slotId) {
  var v = state.checkin;
  if (!v || v.stap !== 3) return;
  var g = gastById(v.gastId);
  if (!g) return;
  if (gastInBed(kamerId, slotId)) { toast('💤 Hier slaapt iemand', 'kind'); return; }
  g.kamer = kamerId; g.bed = slotId; g.waar = g.waar || 'receptie';
  if (state.nieuweGast && state.nieuweGast.id === g.id) {
    state.gasten.push(g);
    state.nieuweGast = null;
  }
  herbereken();
  World.sync(alleDieren());
  World.slaap(g.id, kamerId, slotId);
  g.waar = kamerId;
  g.behoefte = 'eten';
  g.gegeten = false;
  /* klaar: geen vervolgpaneel meer, alleen een wolkje boven het dier */
  state.checkin = null;
  Hits.wisEigenaar('checkin');
  if (window.Snd) Snd.tover();
  Econ.sterren(1, 'checkin');
  taakAf('bed');
  if (state.ronde === 'ochtend') state.ronde = 'vrij';
  State.bewaar();
  naarKamer(kamerId);
  Ui.wolk(g.id, { id: 'ci_af', door: 'wolk', icoon: '💤', tekst: 'welterusten',
                  klas: 'goed', prio: 12 });
  setTimeout(function () { Ui.wolkWeg('ci_af'); World.vuil(); }, 3600);
}

/* =====================================================================
   BAKJES: tikken vertelt wat er te doen is (vullen doet de voerkar)
===================================================================== */
function tikBak(kamerId, slotId) {
  var niv = World.bakStand(kamerId, slotId);
  var gasten = state.gasten.filter(function (g) { return g.kamer === kamerId; });
  if (niv > 0) {
    var eters = gasten.map(function (g) { return g.id; });
    if (eters.length) {
      /* Voeren lost ALLEEN de eet-wens in. Een gast die op een 🛁, 🏊 of 🎁
         wacht heeft straks ook gegeten, maar houdt zijn eigen wens: die kreeg
         hij omdat er echt een spel voor is (wensMogelijk), en het kind hoort
         hem niet kwijt te raken door eerst het bakje te vullen. */
      gasten.forEach(function (g) {
        g.gegeten = true;
        if (!g.behoefte || g.behoefte === 'eten') g.behoefte = 'spelen';
      });
      Art.feast(eters);
      toast('Smakelijk eten! 😋', 'happy');
      Econ.sterren(1, 'voeren');
      taakAf('voer');
      State.bewaar();
      setTimeout(render, 60);
    }
    return;
  }
  if (!gasten.length) { toast('🍽 Hier slaapt niemand', 'kind'); return; }
  toast('🍪 Vul eerst de voerkar', 'kind');
}

/* spelen met de speelmand: het dier holt erheen en danst van blijdschap */
function tikMand(kamerId) {
  var mp = decorPlek(kamerId, 'mand');
  var hier = state.gasten.filter(function (g) {
    return g.kamer === kamerId && g.behoefte === 'spelen' && !g.blij;
  });
  if (!hier.length) {
    toast('🧶 Straks samen spelen', 'kind');
    return;
  }
  hier.forEach(function (g, i) {
    g.blij = true;
    g.waar = kamerId;
    if (mp) World.ga(g.id, mp.x - 12 - i * 4, mp.z + (i % 2 ? 6 : -6), 'blij');
    else World.solo(g.id, 'Spelen');
    Art.setMood(g.id, 'bouncy');
  });
  Econ.sterren(1, 'spelen');
  taakAf('spelen');
  State.bewaar();
  toast(hier.length === 1 ? hier[0].naam + ' speelt met het balletje! 🧶'
                          : 'Ze spelen allemaal met het balletje! 🧶', 'happy');
  render();
}

/* Een wens van een gast vervullen, op de manier die het hotel zelf ook
   gebruikt: eten -> gegeten, de rest (bad, spelen, zwemmen, souvenir) -> blij.
   De spellen die de vlaggen zelf al zetten (voerkar: gegeten, tobbe: blij)
   blijven gewoon werken. Dit is de enige weg voor een spel: het krijgt hem
   als ctx.wereld.behoefteKlaar(gastId, 'zwemmen') (registry.js). */
function wensAf(gastId, welke) {
  var g = gastVan(gastId);
  if (!g && state.nieuweGast && state.nieuweGast.id === gastId) g = state.nieuweGast;
  if (!g) return false;
  var b = welke || g.behoefte;
  if (b === 'eten') g.gegeten = true;
  else if (WENS_BLIJ[b]) g.blij = true;
  else if (b === 'kamer') return !!g.bed;      /* alleen een bed lost dat op */
  Hits.weg('wens_' + g.id);
  State.bewaar();
  render();
  return true;
}

function kassa() {
  var h = '<h2>💰 De kassa</h2>' +
    '<div class="row center" style="gap:10px">' +
    '<div class="chip">💰 <b>' + state.munten + '</b> munten</div>' +
    '<div class="chip b">⭐ <b>' + state.sterren + '</b> sterren</div>' +
    '<div class="chip c">🍬 <b>' + state.snoeppot + '</b> in de snoeppot</div></div>' +
    '<p>Munten komen uit het <b>uitchecken</b>: elke gast betaalt zijn nachten. ' +
    'Sterren krijg je voor <b>meedoen</b> — of je som klopt of niet.</p>' +
    '<p class="hint">In het meubelboek koop je straks nieuwe bedden, mandjes en badkuipen. ' +
    'Meer bedden = meer gasten = grotere sommen.</p>' +
    '<div class="row center"><button class="btn go" type="button" id="kaDicht">Sluiten</button></div>';
  openSheet(h);
  $('#kaDicht').onclick = closeSheet;
}

/* =====================================================================
   HET PRIKBORD: hooguit 3 taakjes, afgeleid uit de behoeften
===================================================================== */
/* Een gast wil pas in bad als er een ECHT tobbe-spel is aangemeld (dus geen
   plaatshouder meer). Zolang dat er niet is bestaat de wens 🛁 niet, en staat
   er dus ook nooit een taakje op het prikbord dat je niet kunt afmaken.

   Datzelfde geldt voor elke NIEUWE wens: een spel meldt zelf welke wens het
   inlost, in zijn eigen bestand, met één regel in Games.register:

       Games.register({ id: 'zwembad', ..., wens: 'zwemmen' });
       Games.register({ id: 'kraam',   ..., wens: ['souvenir', 'geld'] });

   morgen() deelt zo'n wens pas uit als zo'n spel bestaat, niet als
   plaatshouder is aangemeld (stub) en niet meer op slot zit (unlock). Er
   verschijnt dus nooit een wolkje waar het kind niets mee kan. De wensen die
   het hotel ZELF inlost (een bed, een bakje, de speelmand) hebben geen spel
   nodig en staan in HOTEL_WENS. */
var HOTEL_WENS = { kamer: 1, eten: 1, spelen: 1 };
var WENS_SPEL = { bad: 'tobbe' };            /* wens uit golf 2: vast spel */
function spelWil(def, type) {
  var w = def && def.wens;
  if (!w) return false;
  if (typeof w === 'string') return w === type;
  return !!(w.length && Array.prototype.indexOf.call(w, type) >= 0);
}
function speelbaar(def) {
  return !!(def && !def.stub && Games.ontgrendeld(def));
}
function wensMogelijk(type) {
  if (HOTEL_WENS[type]) return true;
  if (!window.Games) return false;
  if (WENS_SPEL[type] && speelbaar(Games.get(WENS_SPEL[type]))) return true;
  var l = Games.lijst();
  for (var i = 0; i < l.length; i++)
    if (spelWil(l[i], type) && speelbaar(l[i])) return true;
  return false;
}
function badMogelijk() { return wensMogelijk('bad'); }

/* =====================================================================
   TAAKJES VAN DE SPELLEN
   Een spel mag zelf zeggen wanneer het op het prikbord hoort:
       Games.register({ ..., taak: { icoon:'🔑', tekst:'Hang de sleutels op',
                                     wanneer: function (state) { return ...; } } })
   Zegt een spel niets, dan geldt de standaard hieronder. tekst mag ook een
   functie(state) zijn. Gasten gaan altijd vóór: eerst de wensen van de
   dieren, dan de spellen, en nooit meer dan drie kaartjes.
===================================================================== */
function badGast(ookAls) {
  var l = state.gasten.filter(function (g) {
    return g.behoefte === 'bad' && (ookAls || !g.blij);
  });
  return l[0] || null;
}
var SPEL_TAAK = {
  voerkar: null,                       /* heeft al een eigen taakje ('voer') */
  /* de tobbe hoort bij een WENS van een gast: eigen naam 'bad' en hoge
     voorrang, zodat hij vóór de gewone spel-taakjes op het bord komt */
  tobbe: { id: 'bad', prio: 1, icoon: '🛁', wanneer: function () { return !!badGast(); },
           tekst: function () { var g = badGast(true); return g ? g.naam + ' wil in bad' : 'Tobbe-tijd'; } },
  bedden: { icoon: '🛏', tekst: 'Zet de bedden op rij',
            wanneer: function (s) { return s.gasten.length >= 2; } },
  sleutels: { icoon: '🔑', tekst: 'Hang de sleutels op',
              wanneer: function (s) { return s.gasten.length >= 2; } },
  meubels: { icoon: '📖', tekst: 'Koop iets moois',
             wanneer: function (s) { return s.munten >= 5; } }
};
function spelTaken() {
  var uit = [];
  if (!window.Games) return uit;
  Games.lijst().forEach(function (def) {
    var t = def.taak !== undefined ? def.taak : SPEL_TAAK[def.id];
    if (!t) return;
    if (!Games.ontgrendeld(def)) return;
    var aan = true;
    try { aan = t.wanneer ? !!t.wanneer(state) : true; } catch (e) { aan = false; }
    if (!aan) return;
    var tekst = typeof t.tekst === 'function' ? t.tekst(state) : (t.tekst || def.naam);
    uit.push({ id: t.id || def.id, spel: def.id, icoon: t.icoon || '✨', tekst: tekst,
               kamer: t.kamer || def.kamer, actie: 'game:' + def.id,
               prio: t.prio === undefined ? 5 : t.prio });
  });
  return uit;
}

/* ---- de gewone klusjes van de spellen krijgen om de beurt een plek -------
   Er zijn meer spellen dan de drie plekken op het prikbord. Een paar klusjes
   mogen ALTIJD (het hinkelpad zodra er een gast in bed ligt, de was altijd),
   en die vochten om dezelfde laatste plek: wie het laagste getal had stond er
   elke dag, de ander nooit. Daarom tellen alle GEWONE klusjes (voorrang LAAG
   of hoger getal, dus géén wens van een dier) op het bord even zwaar, en
   schuiven ze per dag één plaats door: dag 1 begint bij de eerste, dag 2 bij
   de tweede, enzovoort. Zo komt elk spel aan de beurt.
   Wensen van dieren (voorrang 0 t/m 4, bijvoorbeeld 🛁 bad, 🏊 zwemles,
   🎁 souvenir, ⏰ wekker) houden hun eigen voorrang en hun eigen volgorde,
   en het bord blijft bij hoogstens drie kaartjes. */
var LAAG = 5;
function laagTaak(q) { return !!q.spel && (q.prio || 0) >= LAAG; }
function bordPrio(q) { var p = q.prio || 0; return p >= LAAG ? LAAG : p; }
function roteerSpel(sp) {
  var laag = sp.filter(laagTaak), n = laag.length;
  if (n < 2) return sp;
  var dag = state && state.dag ? state.dag : 1;
  var start = ((dag - 1) % n + n) % n;
  var rij = laag.slice(start).concat(laag.slice(0, start));
  var k = 0;
  return sp.map(function (q) { return laagTaak(q) ? rij[k++] : q; });
}

/* Een vingerafdruk van alles waar een taakje van afhangt. Verandert die,
   dan wordt het prikbord opnieuw opgemaakt - ook midden op dag 1. */
function taakSignatuur() {
  var s = [state.dag, state.ronde, state.gasten.length, state.munten,
           (state.uitcheck || []).length, bedVrij() ? 1 : 0, state.nieuweGast ? 1 : 0];
  spelTaken().forEach(function (q) { s.push('sp:' + q.id + ':' + q.tekst); });
  state.gasten.forEach(function (g) {
    s.push(g.id + ':' + (g.bed || '-') + ':' + g.behoefte + ':' + (g.gegeten ? 1 : 0) + ':' + (g.blij ? 1 : 0));
  });
  Rooms.lijst().forEach(function (r) {
    Rooms.slots(r.id, 'bak').forEach(function (q) { s.push(r.id + '=' + World.bakStand(r.id, q.id)); });
  });
  return s.join('|');
}

function bouwTaken(forceer) {
  var sig = taakSignatuur();
  if (!forceer && sig === takenSig && state.taken && state.taken.length) return state.taken;
  takenSig = sig;
  var t = [], i;
  var zonderBed = state.gasten.filter(function (g) { return !g.bed; });
  var legeBak = [];
  Rooms.lijst().forEach(function (r) {
    Rooms.slots(r.id, 'bak').forEach(function (s) {
      var gasten = state.gasten.filter(function (g) { return g.kamer === r.id; });
      if (gasten.length && !World.bakStand(r.id, s.id)) legeBak.push({ kamer: r.id, slot: s.id });
    });
  });
  if (bedVrij() && !state.gasten.length)
    t.push({ id: 'bel', icoon: '🔔', tekst: 'Bel een gast', kamer: 'receptie', actie: 'bel' });
  else if (bedVrij())
    t.push({ id: 'bel', icoon: '🔔', tekst: 'Nog een bed vrij', kamer: 'receptie', actie: 'bel' });
  if (zonderBed.length)
    t.push({ id: 'bed', icoon: '🛏', tekst: zonderBed[0].naam + ' wil een bed', kamer: 'receptie', actie: 'bel' });
  if (legeBak.length)
    t.push({ id: 'voer', icoon: '🍪', tekst: 'Vul de voerkar', kamer: 'keuken', actie: 'game:voerkar' });
  if (state.uitcheck && state.uitcheck.length)
    t.push({ id: 'uit', icoon: '💰', tekst: 'Reken af: ' + (gastVan(state.uitcheck[0]) || { naam: 'gast' }).naam, kamer: 'receptie', actie: 'avond' });
  var spelen = state.gasten.filter(function (g) { return g.behoefte === 'spelen' && !g.blij; });
  if (spelen.length)
    t.push({ id: 'spelen', icoon: '🧶', tekst: spelen[0].naam + ' wil spelen',
             kamer: spelen[0].kamer || 'kamer1', actie: 'kamer' });
  /* het badtaakje komt uit de tobbe zelf (zie SPEL_TAAK) */
  /* Een taakje verdwijnt van het bord zodra het niet meer nodig is (het bakje
     is vol, de gast heeft een bed). Wat je net hebt afgevinkt blijft nog even
     met een vinkje staan zolang het er nog is. */
  var vorige = (state.taken || []).slice(), af = {};
  vorige.forEach(function (q) { if (q.klaar) af[q.id] = 1; });
  /* wensen van de dieren eerst (prio 0), dan de spellen op hun eigen
     voorrang; de volgorde binnen dezelfde voorrang blijft zoals hij is */
  t.forEach(function (q) { if (q.prio === undefined) q.prio = 0; });
  var alles = t.concat(roteerSpel(spelTaken()));
  /* Wat je net hebt afgevinkt blijft de rest van de dag met een vinkje
     staan, ook als het niet meer "nodig" is - anders verdwijnt je succesje
     meteen van het bord. Morgen begint het bord weer leeg. */
  /* Stond het taakje er net nog en is het nu niet meer nodig? Dan is het
     gedaan - ook als het spel z'n taakKlaar() pas ná het opnieuw tekenen
     stuurt. Het kaartje blijft dus staan met een vinkje in plaats van
     ongemerkt te verdwijnen. Een taakKlaar die later binnenkomt zet het
     vinkje gewoon nog eens; hij haalt nooit een kaartje terug. */
  vorige.forEach(function (q) {
    for (var i = 0; i < alles.length; i++) if (alles[i].id === q.id) return;
    q.klaar = true;
    af[q.id] = 1;
    alles.push(q);
  });
  /* de gewone klusjes tellen even zwaar (bordPrio); hun onderlinge volgorde is
     de beurtvolgorde van roteerSpel, en die blijft staan omdat sort stabiel is */
  alles.sort(function (a, b) { return bordPrio(a) - bordPrio(b); });
  state.taken = alles.slice(0, 3).map(function (q) { q.klaar = !!af[q.id]; return q; });
  return state.taken;
}
function openTaken() {
  return (state.taken || []).filter(function (t) { return !t.klaar; }).length;
}
function taakAf(id) {
  var raak = false;
  (state.taken || []).forEach(function (t) {
    if (t.id === id || t.spel === id) { t.klaar = true; raak = true; }
  });
  if (raak && bordOpen) toonBord();
  return raak;
}

var bordOpen = false;

/* de taakjes hangen als kaartjes bij het prikbord: pictogram + korte regel */
function kortTaak(q) { return q.tekst; }

function doeTaak(q) {
  bordDicht();
  state.ronde = 'vrij';
  if (q.kamer) naarKamer(q.kamer);
  if (q.actie === 'bel') { if (!state.gasten.length || bedVrij()) bel(); }
  else if (q.actie === 'avond') avondronde();
  else if (q.actie && q.actie.indexOf('game:') === 0) Games.start(q.actie.slice(5));
  render();
}

function toonBord() {
  Hits.wisEigenaar('bord');
  if (!bordOpen) return;
  var t = state.taken || [];
  if (!t.length) {
    Ui.wolk('prikbord', { id: 'bord_leeg', door: 'bord', icoon: '🐾',
                          tekst: 'Speel lekker rond', hoog: 26, prio: 10 });
    return;
  }
  t.forEach(function (q, i) {
    Ui.wolk(Rooms.plek('receptie', 0.075 + i * 0.325, 0.025 + i * 0.325), {
      id: 'bord_' + i, door: 'bord', icoon: q.klaar ? '✅' : q.icoon,
      tekst: kortTaak(q), hoog: 22, prio: 10,
      tik: function () { doeTaak(q); }
    });
  });
  /* de berichtjes van vandaag: hooguit twee korte regels bij de balie */
  (state.dagBericht || []).slice(0, 2).forEach(function (b, i) {
    Ui.wolk(Rooms.plek('receptie', 0.375, 0.5), {
      id: 'dag_' + i, door: 'bord', icoon: b.icoon, tekst: b.tekst,
      hoog: Rooms.hoogte('receptie', 0.375 + i * 0.15), prio: 9,
      tik: function () { Ui.wolkWeg('dag_' + i); World.vuil(); }
    });
  });
}

function prikbord() {
  bouwTaken();
  bordOpen = true;
  naarKamer('receptie');
  toonBord();
}
/* het prikbord dichtdoen (de bel, een taakje, de avondronde en elk spel dat
   start doen dat: anders staan de taakkaartjes over de knoppen van het spel) */
function bordDicht() {
  if (!bordOpen) return false;
  bordOpen = false;
  Hits.wisEigenaar('bord');
  World.vuil();
  return true;
}
function prikbordTik() {
  if (bordOpen) { bordOpen = false; Hits.wisEigenaar('bord'); World.vuil(); return; }
  prikbord();
}

/* =====================================================================
   DE AVONDRONDE: uitchecken, rekeningen, dagoverzicht
===================================================================== */
function avondKlaar() { return !!(state.uitcheck && state.uitcheck.length); }

function avondronde() {
  state.ronde = 'avond';
  World.dingZet('balielamp', { n: 'lampaan' });
  bordDicht();
  naarKamer('receptie');
  toonAvond();
}

/* Aan de balie staat de familie (één wolkje per gast die naar huis mag) of
   de lamp met "morgen". Geen dagoverzicht in tekst: de cijfers staan al
   bovenin (dag, munten, sterren, brieven). */
function toonAvond() {
  Hits.wisEigenaar('avond');
  if (state.ronde !== 'avond') return;
  var uit = (state.uitcheck || []).map(gastVan).filter(Boolean);
  if (uit.length) {
    uit.slice(0, 3).forEach(function (g, i) {
      Ui.wolk({ x: 8 + i * 24, z: 60 - i * 6, kamer: 'receptie' }, {
        id: 'av_' + g.id, door: 'avond', icoon: '👪', tekst: g.naam,
        hoog: 16, prio: 11, tik: function () { rekenAf(g.id); }
      });
    });
  } else {
    Ui.wolk('balielamp', {
      id: 'av_morgen', door: 'avond', icoon: '🌙', tekst: 'Morgen ▸', hoog: 24, prio: 11,
      tik: function () { morgen(); }
    });
  }
  World.vuil();
}
var paintAvond = toonAvond;

function rekenAf(id) {
  var g = gastVan(id);
  if (!g) return;
  Hits.wisEigenaar('avond');
  /* de gast loopt zelf naar de balie: daar staat zijn familie te wachten */
  if (g.waar !== 'receptie') {
    g.waar = 'receptie';
    World.reis(g.id, 'receptie', { x: WACHTPLEK.x, z: WACHTPLEK.z, na: 'wacht' });
  }
  var fam = FAMILIES[state.famIdx % FAMILIES.length];
  Econ.rekening({
    gast: g, fam: fam, nachten: g.nachten, prijs: g.prijs,
    totaal: g.nachten * g.prijs,
    betaald: g.betaald || sommen.geld(state.band, g.nachten, g.prijs).betaald,
    onKlaar: function (r) {
      geefMunt(r.totaal);
      Econ.sterren(1, 'rekening');
      var brief = nieuweBrief(g);
      state.brieven.push(brief);
      state.gasten = state.gasten.filter(function (q) { return q.id !== g.id; });
      state.uitcheck = (state.uitcheck || []).filter(function (q) { return q !== g.id; });
      herbereken();
      World.sync(alleDieren());
      taakAf('uit');
      State.bewaar();
      briefOpMuur(brief, function () { toonAvond(); render(); });
    }
  });
}

function briefOpMuur(brief, na) {
  var h = '<h2>💌 Er is post!</h2><div class="letter pop"><h3>' + esc(brief.titel) + '</h3>' +
    esc(brief.tekst) + '</div>' +
    '<div class="row center"><button class="btn go big" type="button" id="pin">Hang de brief op de muur 📌</button></div>';
  openSheet(h);
  if (window.Snd) Snd.brief();
  $('#pin').onclick = function () { closeSheet(); toast('💌 Aan de muur!', 'happy'); if (na) na(); };
}

function brievenMuur() {
  var h = '<h2>💌 De brievenmuur</h2>';
  if (!state.brieven.length) {
    h += '<p>Hier komen de bedankjes van de families die hun dier bij jou lieten slapen.</p>' +
      '<p class="hint">Laat een gast zijn nachten uitslapen en reken netjes af — dan komt er post.</p>';
  } else {
    h += '<div class="wall">' + state.brieven.map(function (br) {
      return '<div class="letter"><h3>' + esc(br.titel) + '</h3>' + esc(br.tekst) + '</div>';
    }).join('') + '</div>';
  }
  h += '<div class="row center" style="margin-top:12px"><button class="btn go" type="button" id="dicht">Sluiten</button></div>';
  openSheet(h);
  if (window.Snd) Snd.brief();
  $('#dicht').onclick = closeSheet;
}

/* =====================================================================
   MORGEN: een nieuwe dag
===================================================================== */
/* De nieuwe wensen (🏊 zwemmen, 🎁 souvenir) van deze ochtend uitdelen.

   Vier regels, in deze volgorde:
     1. alleen een wens waar een aangemeld spel bij hoort (wensMogelijk),
     2. de oude wensen blijven precies zoals ze waren: wie geen bed heeft
        houdt 🛏, de 🛁-gast van vandaag blijft de 🛁-gast, en de rest wil
        gewoon 🍪 eten - alleen de uitgekozen gast ruilt zijn 🍪 om,
     3. de ochtend raakt niet vol: hooguit één gast per dag, en pas boven de
        vier gasten hooguit twee,
     4. de even dagen zijn van de tobbe (badBeurt); de nieuwe wensen komen op
        de ONEVEN dagen. Zo blijft 🍪 eten het gewone ochtendwolkje en is er
        nooit meer dan één "uitje" per dag in het hotel.
   Per oneven dag schuift een teller c één (of twee) plaatsen op. Eerst gaan
   alle gasten langs met dezelfde wens, dan volgt de volgende wens: zo krijgt
   elke gast elke wens, ook met twee gasten en twee wensen (een rondje dat
   gast én wens tegelijk laat draaien loopt dan vast op één paar). Met één
   gast is de ring twee lang: die gast krijgt om de andere keer een uitje, en
   wil de andere ochtenden gewoon eten. Geeft { gastId: wens } terug. */
var NIEUWE_WENS = ['zwemmen', 'souvenir'];
function nieuweWensen(badBeurt) {
  var uit = {};
  if (state.dag % 2 === 0) return uit;                 /* de tobbe-dag */
  var kan = NIEUWE_WENS.filter(function (t) { return wensMogelijk(t); });
  if (!kan.length) return uit;
  var kies = state.gasten.filter(function (g, i) {
    return !!g.bed && !(badBeurt && i === 0);
  });
  if (!kies.length) return uit;
  var hoeveel = state.gasten.length > 4 ? 2 : 1;
  var beurt = (state.dag - 1) / 2;                     /* 1, 2, 3, ... */
  var ring = Math.max(kies.length, 2);
  for (var k = 0; k < hoeveel; k++) {
    var c = beurt * hoeveel + k, i = c % ring;
    if (i >= kies.length) continue;
    var g = kies[i];
    if (!uit[g.id]) uit[g.id] = kan[Math.floor(c / ring) % kan.length];
  }
  return uit;
}

function morgen() {
  var b = [];
  /* de avondronde is voorbij: de maan en de familie-wolkjes van gisteren
     moeten weg, anders kun je er nog een keer op tikken en slaat de dag
     over zonder avondronde */
  Hits.wisEigenaar('avond');
  bordDicht();
  state.dag++;
  state.gasten.forEach(function (g) { if (g.bed) g.geslapen++; });

  /* voerboekhouding: hetzelfde ritme als in de geteste demo, zodat de
     check-invraag altijd minstens twee dagen vooruit kijkt */
  var gebruik = dagVerbruik();
  state.scoops = Math.max(0, state.scoops - gebruik);
  state.levering--;
  if (state.levering <= 1) {
    state.scoops = 20 + Math.min(state.scoops, 4);
    state.levering = 4;
    b.push({ icoon: '📦', tekst: 'voer: ' + state.scoops + ' 🥄' });
  }
  if (state.scoops < gebruik) {
    var bij = 10;
    state.scoops += bij;
    b.push({ icoon: '🩺', tekst: 'Els bracht ' + bij + ' 🥄' });
  }

  /* bakjes leeg, iedereen wakker, nieuwe behoeften */
  Rooms.lijst().forEach(function (r) {
    Rooms.slots(r.id, 'bak').forEach(function (s) { World.setBak(r.id, s.id, 0); });
  });
  state.kar = null;
  var badBeurt = badMogelijk() && state.dag % 2 === 0;
  var nieuw = nieuweWensen(badBeurt);
  state.gasten.forEach(function (g, i) {
    g.gegeten = false; g.blij = false;
    g.behoefte = g.bed ? 'eten' : 'kamer';
    if (g.bed && badBeurt && i === 0) g.behoefte = 'bad';
    else if (g.bed && nieuw[g.id]) g.behoefte = nieuw[g.id];
    if (g.bed) {
      /* Opstaan doe je NAAST je bed, op de sta-plek. Zonder plek erbij zette
         World.zet het dier op een willekeurig dwaalvakje - dan stond het 's
         ochtends ineens ergens anders in de kamer. */
      g.waar = g.kamer;
      var sb = Rooms.slot(g.kamer, g.bed);
      World.zet(g.id, g.kamer, sb ? sb.sx : null, sb ? sb.sz : null);
      stuurNaarBehoefte(g);
    }
  });
  state.uitcheck = state.gasten.filter(function (g) { return g.geslapen >= g.nachten; })
                              .map(function (g) { return g.id; });
  if (state.uitcheck.length) {
    var n = gastVan(state.uitcheck[0]);
    b.push({ icoon: '👪', tekst: n.naam + ' gaat naar huis' });
  }
  state.dagBericht = b.length ? b : null;
  state.ronde = 'ochtend';
  state.taken = [];
  bouwTaken();
  World.dingZet('balielamp', { n: 'lamp' });
  herbereken();
  if (window.Snd) Snd.dag();
  naarKamer('receptie');
  prikbord();
  State.bewaar();
}

/* =====================================================================
   OPSTARTEN
===================================================================== */
function herstelWereld() {
  /* eerst de inrichting: gekochte bedden en meubels staan in de opslag en
     bepalen mede hoeveel gasten er kunnen slapen */
  if (window.Games) Games.herstelInrichting();
  World.sync(alleDieren());
  state.gasten.forEach(function (g) {
    if (g.bed && g.kamer) { g.waar = g.kamer; World.slaap(g.id, g.kamer, g.bed); }
    else { g.waar = g.waar || 'receptie'; World.zet(g.id, g.waar); }
  });
  /* de gast die halverwege de check-in aan de balie stond, staat er weer */
  if (state.nieuweGast) {
    state.nieuweGast.waar = 'receptie';
    var np = Rooms.plek('receptie', 0.375, 0.775);
    World.zet(state.nieuweGast.id, 'receptie', np.x, np.z);
    World.ga(state.nieuweGast.id, np.x, np.z, 'wacht');
  }
  World.toon(true);
  World.naar(state.kamerNu || 'receptie', true);
}

function render() {
  /* de wereld beslist waar een dier IS; wij schrijven dat terug in de opslag */
  state.gasten.forEach(function (g) {
    var d = World.dier(g.id);
    if (d) g.waar = d.kamer;
  });
  hud();
  var voor = takenSig;
  bouwTaken();
  kamerbalk();
  hotspots();
  Games.hersteek();
  /* staat het bord open en is er iets veranderd? dan meteen bijwerken:
     anders blijft er een taakje hangen dat al klaar is */
  if (takenSig !== voor && bordOpen) toonBord();
}

/* Kantelt of verandert het scherm, dan verandert de voxelmaat van de kamer
   (world.js maatVan) - en daarmee alles wat in SCHERMpixels is uitgemeten,
   zoals de keuzestrook onder een sommenkaart (ui.js keuzeY, in hoogtestappen
   van 2k px). We leggen de hotspots dan opnieuw neer, net zoals
   games/bedden.js dat voor zijn rijen doet.

   Sinds M1c hangt dat aan de OPMAAT-BUS (Ui.opKader -> World.onKader, M1b) in
   plaats van aan een eigen window-luisteraar. Winst: één ontdenderde melding
   per echte kaderverandering in plaats van twee (resize + orientationchange
   komen bij het kantelen beide langs), en de bus slaat ook als alleen het
   KADER verandert - een rekenblad ernaast, de cijferstrook eronder - zonder
   dat het venster van maat verandert. Het eigen wachtje van 180 ms blijft:
   world.js heeft na een melding nog een tekenbeurt nodig voordat de
   hotspot-plekken kloppen. */
/* WAAROM ER EEN SLOT OP ZIT. Een hertekening van de check-in ruimt de
   sommenkaart op en maakt hem opnieuw. Staat het cijferpad als STROOK onder
   het kader (M1a, een liggende telefoon), dan gaat die strook daarbij even uit
   en meteen weer aan - en elke keer vraagt ui.js world.js om te hermeten. Dat
   is een echte kaderverandering (572 x 228 -> 572 x 290 -> 572 x 228), dus de
   bus slaat, dus opMaat gaat af, dus de check-in wordt hertekend: een lus.
   Gemeten op 740 x 360 zonder slot: 61 kadermeldingen en 61 World.hermeet()
   in 5 seconden (basismeting met de oude window-luisteraars: 1), en een tik op
   het cijferpad kwam niet meer aan omdat het kaartje 5x per seconde werd
   vervangen ("vakje leeg" in mobiel.js).
   Het slot: we onthouden voor WELK kader we de knoppen hebben neergelegd en
   doen niets als dat kader er nog precies zo bij staat. De vergelijking gebeurt
   op het moment dat het wachtje afgaat (niet bij de melding), dus de twee
   tussenmeldingen van onze eigen strook vallen samen in één wachtje en dat
   wachtje ziet het kader terug op zijn oude maat. Een echte draai heeft een
   andere maat en komt dus gewoon door. */
var maatT = null;
function maatNu() {
  var k = (window.World && World.kader) ? World.kader() : null;
  var s = (window.World && World.schaal) ? World.schaal() : null;
  if (!k) return '';
  return Math.round(k.w) + 'x' + Math.round(k.h) +
         '|' + (s ? s.g + ':' + s.dicht + ':' + (s.kamer || '') : '') +
         '|' + World.actief();
}
var maatWas = '';
function opMaat() {
  clearTimeout(maatT);
  maatT = setTimeout(function () {
    maatT = null;
    if (!state) return;
    var sig = maatNu();
    if (sig && sig === maatWas) return;      /* dit kader ligt er al zo */
    maatWas = sig;
    render();
    if (state.checkin) paintCheckin();
  }, 180);
}
/* de opzegger van de bus: start() mag twee keer langskomen (nieuw spel na
   herladen) en dan hoort er niet een tweede luisteraar bij te komen */
var maatAf = null;

function start() {
  herstelWereld();
  bouwTaken(true);
  render();
  if (maatAf) { maatAf(); maatAf = null; }
  maatAf = Ui.opKader(opMaat);
  /* een halve check-in gaat vóór: die maak je eerst af */
  if (state.checkin) paintCheckin();
  else if (state.ronde === 'ochtend') prikbord();
}
return { start: start, render: render, hud: hud, naarKamer: naarKamer, bel: bel,
         prikbord: prikbord, avondronde: avondronde, morgen: morgen,
         brievenMuur: brievenMuur, plattegrond: plattegrond, badMogelijk: badMogelijk,
         wensMogelijk: wensMogelijk, nieuweWensen: nieuweWensen,
         taakAf: taakAf, bouwTaken: bouwTaken, hotspots: hotspots, tikMand: tikMand,
         alleDieren: alleDieren, plekVanBehoefte: plekVanBehoefte,
         stuurNaarBehoefte: stuurNaarBehoefte, wachtIn: wachtIn,
         paintCheckin: paintCheckin, kassa: kassa, toonBord: toonBord,
         toonAvond: toonAvond, doeTaak: doeTaak, bordOpen: function () { return bordOpen; },
         bordDicht: bordDicht, wensAf: wensAf, spelTaken: spelTaken, SPEL_TAAK: SPEL_TAAK };
})();
