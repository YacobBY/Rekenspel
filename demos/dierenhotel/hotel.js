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

/* de plattegrond: waar hangt elke ruimte in het overzicht */
var KAART = { receptie: [1, 2], gang: [2, 2], kamer1: [2, 1], kamer2: [2, 3],
              keuken: [3, 2], tuin: [4, 2] };

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
/* waar hoort dit dier te staan met zijn behoefte? */
function plekVanBehoefte(g) {
  var b = g.behoefte;
  if (b === 'kamer' || !g.kamer) return { kamer: 'receptie', x: 30, z: 62 };
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
  return null;
}
function wachtIn(kamerId) {
  var n = 0;
  state.gasten.forEach(function (g) {
    var p = plekVanBehoefte(g);
    if (p && p.kamer === kamerId && !behoefteKlaar(g)) n++;
  });
  if (kamerId === 'receptie' && state.nieuweGast) n++;
  return n;
}
function behoefteKlaar(g) {
  if (g.behoefte === 'kamer') return !!g.bed;
  if (g.behoefte === 'eten') return !!g.gegeten;
  return !!g.blij;
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
var balkChips = null;
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
    if (w) {
      if (bdg.textContent !== String(w)) bdg.textContent = w;
      if (bdg.hidden) bdg.hidden = false;
    } else if (!bdg.hidden) bdg.hidden = true;
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
                        titel: 'Het prikbord met de taakjes', prio: 9, aan: prikbord });
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
  var wensNr = 0;
  alleDieren().forEach(function (g) {
    if (g.waar !== nu) return;
    var bh = BEHOEFTE[g.behoefte];
    if (!bh || behoefteKlaar(g)) return;
    var d0 = World.dier(g.id);
    if (d0 && d0.staat === 'eet') { Hits.weg('wens_' + g.id); return; }
    var hoog = 58 + (wensNr % 2) * 13;
    wensNr++;
    Hits.maak({ id: 'wens_' + g.id, door: 'hotel', kamer: nu, x: 0, z: 0, y: hoog,
                icoon: bh.icoon, titel: g.naam + ' ' + bh.tekst, klas: 'hotwens', prio: 6,
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
  if (state.checkin) { paintCheckin(); toast('Er staat al iemand aan de balie. 🙂', 'kind'); return; }
  var vrij = bedVrij();
  if (!vrij) {
    if (window.Snd) Snd.zacht();
    openSheet('<h2>🔔 Even geen plek</h2>' +
      '<p>In alle <b>' + meervoud(maxGasten(), 'bed', 'bedden') + '</b> van het hotel slaapt al iemand. ' +
      'Er staat dus niemand nieuw aan de balie.</p>' +
      '<p class="hint">Zodra er een gast uitcheckt komt er een bed vrij — en met munten kun je later ' +
      'nieuwe bedden kopen. Er gaat niets mis. 💛</p>' +
      '<div class="row center"><button class="btn go big" type="button" id="belOk">Oké ▸</button></div>');
    $('#belOk').onclick = closeSheet;
    return;
  }
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
  World.ga(g.id, 30, 62, 'wacht');
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

function scoopjes(n) {
  var s = '';
  for (var i = 0; i < n; i++) s += '<span class="scoop">🥄</span>';
  return s;
}
function sprongen(v) {
  var l = [], s = 0;
  for (var i = 0; i < v.dagen; i++) { s += v.nieuw; l.push(s); }
  return l.join(' … ') + '. Dat is ' + s + ', en jij hebt ' + v.voorraad + '.';
}

function paintCheckin() {
  var v = state.checkin;
  if (!v) return;
  var g = gastById(v.gastId);
  if (!g) { state.checkin = null; Ui.leegPaneel(); return; }
  var h = '<h1>🛎️ Check-in</h1>';
  if (v.stap === 1 || v.stap === 2) {
    h += '<div class="stock">' +
      '<div class="chip">🥣 nog <b>' + v.voorraad + '</b> scheppen brokken</div>' +
      '<div class="chip b">🐾 samen <b>' + v.samen + '</b> scheppen per dag</div>' +
      '<div class="chip c">🚚 nieuw voer over <b>' + v.dagen + '</b> dagen</div></div>' +
      '<div class="gast"><b>' + esc(g.naam) + '</b>, ' + esc(metLidwoord(g)) +
      ', wil <b>' + meervoud(g.nachten, 'nacht', 'nachten') + '</b> blijven.<br>' +
      '&bdquo;Mag ik hier slapen? Ik eet <b>' + v.extra + '</b> scheppen per dag.&rdquo;</div>';
  }

  if (v.stap === 1) {
    h += '<div class="qbox"><h2>Vraag 1 van 2</h2>' +
      '<p>Hoeveel scheppen eet iedereen <b>samen</b> per dag als ' + esc(g.naam) + ' erbij komt?</p>' +
      '<div class="somregel"><span class="answer" id="ans">' + (v.invoer || '?') + '</span><span>scheppen</span></div>' +
      '<div class="pad">' +
      [1, 2, 3, 4, 5, 6, 7, 8, 9].map(function (k) { return '<button class="btn" type="button" data-k="' + k + '">' + k + '</button>'; }).join('') +
      '<button class="btn del" type="button" data-k="del">⌫</button><button class="btn" type="button" data-k="0">0</button>' +
      '<button class="btn ok" type="button" data-k="ok">✓</button></div>';
    if (v.fouten1 > 0) {
      h += '<div class="soft-note">Tel rustig mee. De gasten die er al zijn eten <b>' + v.samen + '</b>, ' +
        esc(g.naam) + ' eet er <b>' + v.extra + '</b> bij:' +
        '<div class="counton">' + scoopjes(v.samen) + '<b>+</b>' + scoopjes(v.extra) +
        '<b>=</b><span class="somvak"></span></div></div>';
    }
    h += '</div>';
  } else if (v.stap === 2) {
    h += '<div class="good">Goed geteld! ' + v.samen + ' + ' + v.extra + ' = <b>' + v.nieuw + '</b> scheppen per dag.</div>' +
      '<div class="qbox"><h2>Vraag 2 van 2</h2>' +
      '<p>Het nieuwe voer komt pas over <b>' + v.dagen + ' dagen</b>. Je hebt nog <b>' + v.voorraad + '</b> scheppen.</p>' +
      '<p><b>Is ' + v.dagen + ' dagen × ' + v.nieuw + ' scheppen méér of minder dan ' + v.voorraad +
      ' — of precies evenveel?</b></p>' +
      '<div class="row center"><button class="btn big" type="button" data-v="minder">Minder ⬇️</button>' +
      '<button class="btn big" type="button" data-v="precies">Precies evenveel ⚖️</button>' +
      '<button class="btn big" type="button" data-v="meer">Méér ⬆️</button></div>';
    if (v.fouten2 > 0) h += '<div class="soft-note">Tel met sprongen mee: ' + sprongen(v) + '</div>';
    h += '</div>';
  } else if (v.stap === 3) {
    var tot = v.dagen * v.nieuw, uitkomst = vergelijk(v);
    var vrij = bedVrij();
    /* het kaartje staat bovenaan: dan zie je de kamer én het kaartje samen
       en kun je het echt van het blad op een bed slepen */
    h += '<h2 class="bedvraag">Waar mag ' + esc(g.naam) + ' slapen?</h2>' +
      '<div class="gastkaartrij"><div class="gastkaart" id="gastkaart" data-gast="' + g.id + '">' +
      '<span class="gk-ico">' + (BEHOEFTE.kamer.icoon) + '</span>' +
      '<span class="gk-nm">' + esc(g.naam) + '</span>' +
      '<span class="gk-sub">' + meervoud(g.nachten, 'nacht', 'nachten') + ' · €' + g.prijs + ' per nacht</span>' +
      '</div></div>' +
      (vrij && World.actief() === vrij.kamer
        ? '<p class="hint" style="text-align:center">Sleep het kaartje op een <b>leeg bed</b> hierboven. ' +
          'Tikken op het bed mag ook.</p>'
        : '<p class="hint" style="text-align:center">Er is een leeg bed in <b>' +
          (vrij ? esc(Rooms.get(vrij.kamer).naam) : 'het hotel') +
          '</b>. Ga daar eerst naartoe, dan sleep je het kaartje op het bed.</p>');
    if (vrij && World.actief() !== vrij.kamer)
      h += '<div class="row center"><button class="btn soft" type="button" id="naarBed">Ga naar ' +
        esc(Rooms.get(vrij.kamer).naam) + ' ▸</button></div>';
    h += '<div class="good">Klopt! ' + v.dagen + ' × ' + v.nieuw + ' = <b>' + tot + '</b> scheppen. ' +
      'Je hebt er <b>' + v.voorraad + '</b>. Dat is dus ' +
      (uitkomst === 'meer' ? '<b>méér</b> dan je in huis hebt.'
        : uitkomst === 'minder' ? '<b>minder</b> dan je in huis hebt.'
        : '<b>precies evenveel</b> — het past precies!') + '</div>';
  } else {
    h += '<div class="qbox"><h2>' + v.keuzeTitel + '</h2><p>' + v.keuzeTekst + '</p>' +
      '<div class="row center"><button class="btn go big" type="button" id="ciKlaar">Fijn! ▸</button></div></div>';
  }
  Ui.paneel(h, 'checkin');
  wireCheckin();
}

function wireCheckin() {
  var v = state.checkin;
  if (!v) return;
  var g = gastById(v.gastId);
  $$('#paneel [data-k]').forEach(function (b) {
    b.onclick = function () {
      var k = b.getAttribute('data-k');
      if (k === 'del') v.invoer = v.invoer.slice(0, -1);
      else if (k === 'ok') return antwoord1();
      else if (v.invoer.length < 2) v.invoer += k;
      paintCheckin();
    };
  });
  $$('#paneel [data-v]').forEach(function (b) {
    b.onclick = function () { antwoord2(b.getAttribute('data-v')); };
  });
  var nb = $('#naarBed');
  if (nb) nb.onclick = function () {
    var vrij = bedVrij();
    if (vrij) { naarKamer(vrij.kamer); toast('Sleep ' + g.naam + ' op het lege bed. 🛏', 'kind'); }
  };
  var kk = $('#gastkaart');
  if (kk) makeDraggable(kk, {
    dropSel: '[data-drop="bed"]',
    ghostHTML: function () { return kk.outerHTML; },
    onDrop: function (t) { wijsBed(t.getAttribute('data-h-kamer'), t.getAttribute('data-h-slot')); },
    onTap: function () { toast('Sleep het kaartje op een leeg bed, of tik op een bed. 🛏', 'kind'); }
  });
  var ok = $('#ciKlaar');
  if (ok) ok.onclick = function () {
    state.checkin = null;
    Ui.leegPaneel();
    if (state.ronde === 'ochtend') state.ronde = 'vrij';
    render();
  };
}

/* ---------- BEVROREN: antwoord 1 en 2 (zelfde rekencheck) ---------- */
function antwoord1() {
  var v = state.checkin;
  if (!v.invoer) { toast('Tik eerst een getal in. 🙂', 'kind'); return; }
  if (+v.invoer === v.nieuw) {
    v.stap = 2; v.invoer = ''; paintCheckin(); Snd.ja();
    toast('Precies! 🎉', 'happy');
    State.tel(v.fouten1 === 0, Ui.nu() - v.t0);
  } else {
    v.fouten1++; v.invoer = ''; paintCheckin(); Snd.zacht();
    toast('Bijna! Tel de scheppen samen — ze staan eronder. 💛', 'kind');
  }
}

function antwoord2(keus) {
  var v = state.checkin;
  if (keus === vergelijk(v)) {
    v.stap = 3; paintCheckin(); Snd.ja(); toast('Goed gerekend! 🎉', 'happy');
    State.tel(v.fouten2 === 0, Ui.nu() - v.t0);
  } else { v.fouten2++; paintCheckin(); Snd.zacht(); toast('Tel eerst met sprongen mee, dan zie je het. 💛', 'kind'); }
}

/* ---------- het bed toewijzen ---------- */
function tikBed(kamerId, slotId) {
  var v = state.checkin;
  var er = gastInBed(kamerId, slotId);
  if (er) { toast(er.naam + ' slaapt hier. 💤', 'kind'); return; }
  if (v && v.stap === 3) { wijsBed(kamerId, slotId); return; }
  toast('Een leeg bed. Bel bij de balie om een gast te halen! 🔔', 'kind');
}

function wijsBed(kamerId, slotId) {
  var v = state.checkin;
  if (!v || v.stap !== 3) return;
  var g = gastById(v.gastId);
  if (!g) return;
  if (gastInBed(kamerId, slotId)) { toast('Daar slaapt al iemand. 💤', 'kind'); return; }
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
  v.stap = 4;
  v.keuzeTitel = esc(g.naam) + ' mag blijven! 🛏';
  v.keuzeTekst = g.naam + ' krijgt bed ' + (slotId === 'bed2' ? '2' : '1') + ' in ' +
    esc(Rooms.get(kamerId).naam) + ' en gaat er meteen even liggen. ' +
    'Morgen wil ' + g.naam + ' natuurlijk eten — vul de voerkar in de keuken!';
  if (window.Snd) Snd.tover();
  Econ.sterren(1, 'checkin');
  taakAf('bed');
  State.bewaar();
  naarKamer(kamerId);
  paintCheckin();
  toast(g.naam + ' ligt in bed. 💤', 'happy');
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
      gasten.forEach(function (g) { g.gegeten = true; g.behoefte = 'spelen'; });
      Art.feast(eters);
      toast('Smakelijk eten! 😋', 'happy');
      Econ.sterren(1, 'voeren');
      taakAf('voer');
      State.bewaar();
      setTimeout(render, 60);
    }
    return;
  }
  if (!gasten.length) { toast('In deze kamer slaapt niemand, dus dit bakje mag leeg blijven. 🙂', 'kind'); return; }
  toast('Dit bakje is nog leeg. Vul de voerkar in de keuken! 🍪', 'kind');
}

/* spelen met de speelmand: het dier holt erheen en danst van blijdschap */
function tikMand(kamerId) {
  var mp = decorPlek(kamerId, 'mand');
  var hier = state.gasten.filter(function (g) {
    return g.kamer === kamerId && g.behoefte === 'spelen' && !g.blij;
  });
  if (!hier.length) {
    toast('De speelmand met het balletje. Na het eten wil er vast iemand spelen! 🧶', 'kind');
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
   er dus ook nooit een taakje op het prikbord dat je niet kunt afmaken. */
function badMogelijk() {
  var g = window.Games && Games.get('tobbe');
  return !!(g && !g.stub && Games.ontgrendeld(g));
}

function bouwTaken() {
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
    t.push({ id: 'bel', icoon: '🔔', tekst: 'Bel de eerste gast binnen', kamer: 'receptie', actie: 'bel' });
  else if (bedVrij())
    t.push({ id: 'bel', icoon: '🔔', tekst: 'Er is nog een bed vrij: bel een gast', kamer: 'receptie', actie: 'bel' });
  if (zonderBed.length)
    t.push({ id: 'bed', icoon: '🛏', tekst: 'Geef ' + zonderBed[0].naam + ' een bed', kamer: 'receptie', actie: 'bel' });
  if (legeBak.length)
    t.push({ id: 'voer', icoon: '🍪', tekst: 'Vul de voerkar en breng het eten rond', kamer: 'keuken', actie: 'game:voerkar' });
  if (state.uitcheck && state.uitcheck.length)
    t.push({ id: 'uit', icoon: '💰', tekst: 'Familie komt ' + (gastVan(state.uitcheck[0]) || { naam: 'een gast' }).naam + ' ophalen', kamer: 'receptie', actie: 'avond' });
  var spelen = state.gasten.filter(function (g) { return g.behoefte === 'spelen' && !g.blij; });
  if (spelen.length)
    t.push({ id: 'spelen', icoon: '🧶', tekst: spelen[0].naam + ' wil spelen',
             kamer: spelen[0].kamer || 'kamer1', actie: 'kamer' });
  if (badMogelijk()) {
    var bad = state.gasten.filter(function (g) { return g.behoefte === 'bad'; });
    if (bad.length)
      t.push({ id: 'bad', icoon: '🛁', tekst: bad[0].naam + ' wil in de tobbe', kamer: 'tuin', actie: 'game:tobbe' });
  }
  var oud = {};
  (state.taken || []).forEach(function (q) { if (q.klaar) oud[q.id] = 1; });
  t = t.filter(function (q) { return !oud[q.id]; });
  state.taken = t.slice(0, 3).map(function (q) { q.klaar = false; return q; });
  return state.taken;
}
function openTaken() {
  return (state.taken || []).filter(function (t) { return !t.klaar; }).length;
}
function taakAf(id) {
  (state.taken || []).forEach(function (t) { if (t.id === id) t.klaar = true; });
}

function prikbord() {
  if (!state.taken || !state.taken.length) bouwTaken();
  var t = state.taken || [];
  var h = '<h1>📋 Het prikbord</h1><div class="opdracht"><p><b>Dag ' + state.dag + '</b> — ' +
    (t.length ? 'dit staat er vandaag op het prikbord. Je mag zelf kiezen waar je begint.'
              : 'er staat niets meer op het prikbord. Speel gewoon lekker rond! 🐾') + '</p></div>';
  if (state.dagBericht) h += '<div class="soft-note">' + state.dagBericht + '</div>';
  h += '<div class="taken">';
  t.forEach(function (q, i) {
    h += '<button class="taak' + (q.klaar ? ' af' : '') + '" type="button" data-taak="' + i + '">' +
      '<span class="ti">' + q.icoon + '</span><span class="tt">' + esc(q.tekst) + '</span>' +
      '<span class="tk">' + (q.klaar ? '✓ klaar' : Rooms.get(q.kamer) ? Rooms.get(q.kamer).naam : '') + '</span></button>';
  });
  h += '</div><div class="row center" style="margin-top:14px">' +
    '<button class="btn go big" type="button" id="pbDicht">Aan de slag ▸</button></div>';
  Ui.paneel(h, 'prik');
  $$('#paneel [data-taak]').forEach(function (b) {
    b.onclick = function () {
      var q = state.taken[+b.getAttribute('data-taak')];
      if (!q) return;
      Ui.leegPaneel();
      state.ronde = 'vrij';
      if (q.kamer) naarKamer(q.kamer);
      if (q.actie === 'bel') { if (!state.gasten.length || bedVrij()) bel(); }
      else if (q.actie === 'avond') avondronde();
      else if (q.actie && q.actie.indexOf('game:') === 0) Games.start(q.actie.slice(5));
      render();
    };
  });
  $('#pbDicht').onclick = function () {
    Ui.leegPaneel();
    state.ronde = 'vrij';
    render();
  };
}

/* =====================================================================
   DE AVONDRONDE: uitchecken, rekeningen, dagoverzicht
===================================================================== */
function avondKlaar() { return !!(state.uitcheck && state.uitcheck.length); }

function avondronde() {
  state.ronde = 'avond';
  World.dingZet('balielamp', { n: 'lampaan' });
  naarKamer('receptie');
  paintAvond();
}

function paintAvond() {
  var uit = (state.uitcheck || []).map(gastVan).filter(Boolean);
  var h = '<h1>🌙 Avondronde</h1>';
  if (uit.length) {
    h += '<div class="opdracht"><p>Er staat familie aan de balie! ' +
      (uit.length === 1 ? '<b>' + esc(uit[0].naam) + '</b> heeft lang genoeg geslapen en mag naar huis.'
                        : 'Er worden <b>' + uit.length + ' gasten</b> opgehaald.') +
      ' Eerst nog even afrekenen.</p></div><div class="taken">';
    uit.forEach(function (g) {
      h += '<button class="taak" type="button" data-uit="' + g.id + '">' +
        '<span class="ti">👪</span><span class="tt">Reken af voor ' + esc(g.naam) + '</span>' +
        '<span class="tk">' + meervoud(g.nachten, 'nacht', 'nachten') + ' × €' + g.prijs + '</span></button>';
    });
    h += '</div>';
  } else {
    var som = state.gasten.length;
    h += '<div class="opdracht"><p>Alle gasten liggen in bed. Vanavond checkt er niemand uit.</p></div>' +
      '<div class="row center" style="gap:10px">' +
      '<div class="chip">🐾 <b>' + som + '</b> ' + (som === 1 ? 'gast' : 'gasten') + '</div>' +
      '<div class="chip b">💰 <b>' + state.munten + '</b> munten</div>' +
      '<div class="chip c">⭐ <b>' + state.sterren + '</b> sterren</div>' +
      '<div class="chip">💌 <b>' + state.brieven.length + '</b> brieven</div></div>';
  }
  h += '<div class="row center" style="margin-top:14px">' +
    (uit.length ? '' : '<button class="btn go big" type="button" id="morgenBtn">Slaap lekker 💤 — morgen ▸</button>') +
    '<button class="btn soft" type="button" id="avDicht">Nog even rondkijken</button></div>';
  Ui.paneel(h, 'avond');
  $$('#paneel [data-uit]').forEach(function (b) {
    b.onclick = function () { rekenAf(b.getAttribute('data-uit')); };
  });
  var m = $('#morgenBtn');
  if (m) m.onclick = morgen;
  var d = $('#avDicht');
  if (d) d.onclick = function () { Ui.leegPaneel(); state.ronde = 'vrij'; render(); };
}

function rekenAf(id) {
  var g = gastVan(id);
  if (!g) return;
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
      briefOpMuur(brief, function () { paintAvond(); render(); });
    }
  });
}

function briefOpMuur(brief, na) {
  var h = '<h2>💌 Er is post!</h2><div class="letter pop"><h3>' + esc(brief.titel) + '</h3>' +
    esc(brief.tekst) + '</div>' +
    '<div class="row center"><button class="btn go big" type="button" id="pin">Hang de brief op de muur 📌</button></div>';
  openSheet(h);
  if (window.Snd) Snd.brief();
  $('#pin').onclick = function () { closeSheet(); toast('De brief hangt aan de muur. 💛', 'happy'); if (na) na(); };
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
function morgen() {
  var b = [];
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
    b.push('📦 Het nieuwe voer is bezorgd! Je hebt weer <b>' + state.scoops + ' scheppen</b> brokken.');
  }
  if (state.scoops < gebruik) {
    var bij = 10;
    b.push('🩺 Buurvrouw Els kwam brokken brengen. &bdquo;Je had nog <b>' + state.scoops +
      '</b> scheppen en jullie eten samen <b>' + gebruik + '</b> per dag. Ik doe er <b>' + bij +
      '</b> bij.&rdquo;');
    state.scoops += bij;
  }

  /* bakjes leeg, iedereen wakker, nieuwe behoeften */
  Rooms.lijst().forEach(function (r) {
    Rooms.slots(r.id, 'bak').forEach(function (s) { World.setBak(r.id, s.id, 0); });
  });
  state.kar = null;
  var badBeurt = badMogelijk() && state.dag % 2 === 0;
  state.gasten.forEach(function (g, i) {
    g.gegeten = false; g.blij = false;
    g.behoefte = g.bed ? 'eten' : 'kamer';
    if (g.bed && badBeurt && i === 0) g.behoefte = 'bad';
    if (g.bed) {
      g.waar = g.kamer;
      World.zet(g.id, g.kamer);
      stuurNaarBehoefte(g);
    }
  });
  state.uitcheck = state.gasten.filter(function (g) { return g.geslapen >= g.nachten; })
                              .map(function (g) { return g.id; });
  if (state.uitcheck.length) {
    var n = gastVan(state.uitcheck[0]);
    b.push('👪 Vanavond komt de familie van <b>' + esc(n.naam) + '</b> langs om ' + esc(n.naam) + ' op te halen.');
  }
  state.dagBericht = b.length ? b.map(function (x) { return '<p>' + x + '</p>'; }).join('') : null;
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
    World.zet(state.nieuweGast.id, 'receptie', 30, 62);
    World.ga(state.nieuweGast.id, 30, 62, 'wacht');
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
  kamerbalk();
  hotspots();
  Games.hersteek();
}

function start() {
  herstelWereld();
  if (!state.taken || !state.taken.length) bouwTaken();
  render();
  /* een halve check-in gaat vóór: die maak je eerst af */
  if (state.checkin) paintCheckin();
  else if (state.ronde === 'ochtend') prikbord();
}

return { start: start, render: render, naarKamer: naarKamer, bel: bel,
         prikbord: prikbord, avondronde: avondronde, morgen: morgen,
         brievenMuur: brievenMuur, plattegrond: plattegrond, badMogelijk: badMogelijk,
         taakAf: taakAf, bouwTaken: bouwTaken, hotspots: hotspots, tikMand: tikMand,
         alleDieren: alleDieren, plekVanBehoefte: plekVanBehoefte,
         stuurNaarBehoefte: stuurNaarBehoefte, wachtIn: wachtIn,
         paintCheckin: paintCheckin, kassa: kassa };
})();
