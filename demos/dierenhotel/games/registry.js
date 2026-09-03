/* ---------------------------------------------------------------
   games/registry.js - de stekkerdoos voor minigames.

   Elk spel is ÉÉN bestand in games/ dat zichzelf aanmeldt zodra het
   geladen is. Zo hoeven twee mensen die aan twee spellen bouwen nooit
   in hetzelfde bestand te werken:

     Games.register({
       id: 'tobbe', naam: 'Tobbe-tijd',
       kamer: 'tuin',                       // waar het spel woont
       hotspot: { obj: 'tobbe', icoon: '🛁' },
       unlock: function (N, band) { return N >= 1; },
       start: function (ctx) { ... },        // paneel opbouwen
       stop: function () { ... }             // opruimen (optioneel)
     });

   Het enige wat een spel van buiten mag aanraken is de ctx die het bij
   start() krijgt. Alles daarin is bevroren: de motor verandert niet
   meer onder je handen. Zie GAMES-API.md voor de volledige lijst.
---------------------------------------------------------------- */
var Games = (function () {
'use strict';

var reg = [], byId = Object.create(null), actief = null, actieveKamer = null,
    ctxCache = Object.create(null);

function register(def) {
  if (!def || !def.id) return null;
  if (byId[def.id]) {                       /* twee keer geladen: laatste wint */
    reg[reg.indexOf(byId[def.id])] = def;
  } else reg.push(def);
  byId[def.id] = def;
  return def;
}

function lijst() { return reg.slice(); }
function get(id) { return byId[id] || null; }
function open() { return actief; }

function ontgrendeld(def) {
  var N = State.N(), band = State.band();
  if (typeof def.unlock !== 'function') return true;
  try { return !!def.unlock(N, band); } catch (e) { return true; }
}

/* waar staat het voorwerp waar dit spel aan hangt? */
function plek(kamerId, obj) {
  var d = World.dingPlek(obj);
  if (d) return { kamer: d.kamer, x: d.x, z: d.z, y: d.y || 0 };
  var s = Rooms.slot(kamerId, obj);
  if (s) return { kamer: kamerId, x: s.x, z: s.z, y: 0 };
  var r = Rooms.get(kamerId);
  if (r) {
    for (var i = 0; i < r.decor.length; i++)
      if (r.decor[i].n === obj || r.decor[i].sleutel === obj)
        return { kamer: kamerId, x: r.decor[i].x, z: r.decor[i].z, y: r.decor[i].y || 0 };
  }
  return null;
}

/* de icoontjes van alle spellen op hun voorwerp zetten (of weghalen) */
function hersteek() {
  reg.forEach(function (def) {
    var id = 'game_' + def.id;
    if (!def.hotspot || !ontgrendeld(def)) { Hits.weg(id); return; }
    /* Loopt het spel al? Dan is het voorwerp van het spel zelf: twee knoppen
       op dezelfde voxel zou de tik-volgorde in de weg zitten (GAMES-API.md 4).
       Wie zijn icoontje toch wil laten staan zet hotspot.blijf op true. */
    if (actief === def.id && !def.hotspot.blijf) { Hits.weg(id); return; }
    var kamerId = def.kamer, h = def.hotspot;
    var p = plek(kamerId, h.obj);
    if (!p) { Hits.weg(id); return; }
    /* dx/dz/hoog schuiven de knop een paar voxels op, zodat hij niet precies
       op een andere knop (of op een slapend dier) belandt */
    function waar(q) {
      if (!q) return null;
      return { x: q.x + (h.dx || 0), z: q.z + (h.dz || 0),
               y: (q.y || 0) + (h.hoog === undefined ? 12 : h.hoog) };
    }
    var w = waar(p);
    Hits.maak({
      id: id, door: 'registry', kamer: p.kamer, x: w.x, z: w.z, y: w.y,
      icoon: h.icoon || '✨', label: h.label || null,
      titel: def.naam, klas: 'hotgame' + (actief === def.id ? ' aan' : ''),
      prio: 7,
      volg: function () { return waar(plek(def.kamer, h.obj)); },
      aan: function () { start(def.id); }
    });
  });
}

/* meubel neerzetten + onthouden + de wereld bijwerken */
function zetMeubel(kamerId, type, plek) {
  plek = plek || {};
  var m = Rooms.meubelZet(kamerId, type, plek.x, plek.z, plek.rot);
  if (!m) return null;
  var st = State.ruw();
  st.meubels = st.meubels || [];
  st.meubels.push(m);
  st.meubelNr = Rooms.nrStand();        /* teller mee in de opslag */
  naInrichten();
  return m;
}
function naInrichten() {
  World.herbouw();
  hersteek();
  if (window.Hotel) Hotel.render();
  State.bewaar();
}
/* bij het laden: de bewaarde inrichting terugzetten (zelfde ids) */
function herstelInrichting() {
  Rooms.herstel();
  var st = State.ruw();
  var lijst = (st.meubels || []).slice(), goed = [];
  /* de meubelteller weer op stand brengen: uit de opslag, en anders uit de
     hoogste naam die al bestaat (oude opslag) */
  Rooms.zetNr(st.meubelNr || 0);
  Rooms.nrUitIds(lijst);
  lijst.forEach(function (m) {
    var q = Rooms.meubelZet(m.kamer, m.type, m.x, m.z, m.rot, m.id);
    if (!q) return;
    /* eigen velden van het spel (bijvoorbeeld spa: 1 van de tobbe) blijven
       staan: het bewaarde blaadje gaat over het herbouwde heen */
    for (var k in m) if (q[k] === undefined) q[k] = m[k];
    goed.push(q);
  });
  st.meubels = goed;
  st.meubelNr = Rooms.nrStand();
  World.herbouw();
  return goed;
}

/* het ui-luikje: dezelfde functies, maar met eigenaar erop gestempeld */
function uiVoor(eigen) {
  var f = Object.create(Ui);
  f.wolk = function (obj, o) { o = o || {}; o.door = eigen; return Ui.wolk(obj, o); };
  f.somkaart = function (obj, som, o) { o = o || {}; o.door = eigen; return Ui.somkaart(obj, som, o); };
  f.bron = function (obj, o) { o = o || {}; o.door = eigen; return Ui.bron(obj, o); };
  f.eigenaar = eigen;
  return f;
}

function ctxVoor(def) {
  if (ctxCache[def.id]) return ctxCache[def.id];
  var eigen = def.id;
  var ctx = {
    id: def.id,
    naam: def.naam,
    kamer: def.kamer,

    /* ---------- de wereld ---------- */
    wereld: {
      kamers: function () { return Rooms.lijst(); },
      kamer: function (id) { return Rooms.get(id); },
      pad: function (a, b) { return Rooms.pad(a, b); },
      slots: function (kamerId, soort) { return Rooms.slots(kamerId, soort); },
      slot: function (kamerId, slotId) { return Rooms.slot(kamerId, slotId); },
      actief: function () { return World.actief(); },
      naar: function (kamerId) { return World.naar(kamerId); },
      dieren: function (kamerId) {
        return State.gasten().filter(function (g) { return !kamerId || g.waar === kamerId; });
      },
      dier: function (id) { return World.dier(id); },
      ga: function (id, x, z, na) { World.ga(id, x, z, na); },
      reis: function (id, kamerId, doel) { return World.reis(id, kamerId, doel); },
      slaap: function (id, kamerId, slotId) { World.slaap(id, kamerId, slotId); },
      setMood: function (id, m) { Art.setMood(id, m); },
      setFood: function (id, n, per) { Art.setFood(id, n, per); },
      setBak: function (kamerId, slotId, n) { World.setBak(kamerId, slotId, n); },
      bakStand: function (kamerId, slotId) { return World.bakStand(kamerId, slotId); },
      feest: function (ids) { Art.feast(ids); },
      solo: function (id, act) { World.solo(id, act); },
      ding: function (sleutel) { return World.dingPlek(sleutel); },
      dingZet: function (sleutel, o) { var d = World.dingZet(sleutel, o); hersteek(); return d; },
      vuil: function () { World.vuil(); },
      /* waar hangt dit voorwerp / dier in de wereld? */
      mik: function (obj, kamerId) { return World.mik(obj, kamerId); },
      /* hoeveel css-pixels is één voxel nu? (voor eigen rijtjes en rasters)
         css-x ~ pxPerVoxelX * (x - z), css-y ~ pxPerVoxelY * (x + z - 2y) */
      schaal: function () { return World.schaal(); },
      /* een wens van een gast vervullen zoals het hotel dat zelf doet */
      behoefteKlaar: function (gastId, behoefte) {
        return window.Hotel ? Hotel.wensAf(gastId, behoefte) : false;
      },
      /* een cijfer ÓP een voorwerp (n = null haalt het weg) */
      getalTag: function (obj, n, o) {
        o = o || {}; o.door = eigen;
        return World.getalTag(obj, n, o);
      },

      /* ---------- inrichten: bedden en meubels bijplaatsen ----------
         Dit loopt via rooms.js, wordt bewaard in de opslag (v6) en staat
         er na "Verder spelen" weer. Zo hoeft een spel nooit in een
         gedeeld bestand te schrijven. */
      voegBed: function (kamerId, plek) { return zetMeubel(kamerId, 'bed', plek); },
      plaatsMeubel: function (kamerId, type, x, z, rot) {
        return zetMeubel(kamerId, type, { x: x, z: z, rot: rot });
      },
      verwijderMeubel: function (id) {
        if (!Rooms.meubelWeg(id)) return false;
        var st = State.ruw();
        st.meubels = (st.meubels || []).filter(function (m) { return m.id !== id; });
        naInrichten();
        return true;
      },
      kamerMeubels: function (kamerId) { return Rooms.meubels(kamerId); },
      meubeltypen: function () { return Object.keys(Rooms.MEUBEL); }
    },

    /* ---------- de hotspot-laag (z-index volgt de tekenvolgorde) ---------- */
    hotspots: {
      maak: function (o) { o.door = eigen; return Hits.maak(o); },
      weg: function (id) { Hits.weg(id); },
      wisAlles: function () { Hits.wisEigenaar(eigen); },
      /* een sleepbron in de wereld: zak, buidel, kist - met teller erop */
      bron: function (obj, o) {
        o = o || {}; o.door = eigen;
        return Ui.bron(obj, o);
      },
      /* leen een knop van het hotel zolang dit spel bezig is */
      pak: function (id, fn) { Hits.pak(id, eigen, fn); },
      laat: function () { Hits.laat(eigen); },
      lijst: function () { return Hits.lijst(); }
    },
    sleep: function (node, opts) { return makeDraggable(node, opts); },

    /* ---------- de stand van het hotel ---------- */
    state: State,
    /* je eigen laatje in de opslag (wordt bewaard in kws-hotel-v6) */
    data: function () { return State.spelData(def.id); },

    /* ---------- het scherm ----------
       Een eigen luikje op Ui: alles wat een knopje, wolkje of kaartje in de
       wereld zet krijgt automatisch de naam van DIT spel als eigenaar. Zo
       ruimt stop() ook de wolkjes en sommenkaartjes weer op, zonder dat een
       spel ergens 'door' hoeft mee te geven. De rest van Ui gaat gewoon door
       (paneel, telMee, voorbeeld, spreek, ...). */
    ui: uiVoor(def.id),
    econ: Econ,
    snd: Snd,

    /* ---------- taak afgerond: een ster voor het meedoen ---------- */
    taakKlaar: function (naam, o) {
      o = o || {};
      Econ.sterren(o.sterren || 1, def.id);
      if (window.Hotel) {
        /* op de naam die het spel doorgeeft ÉN op de naam van het spel zelf:
           zo vinkt het altijd het juiste kaartje af */
        Hotel.taakAf(naam || def.id);
        if (naam && naam !== def.id) Hotel.taakAf(def.id);
      }
      State.bewaar();
    },
    sluit: function () { stop(); }
  };
  ctxCache[def.id] = ctx;
  return ctx;
}

function start(id) {
  var def = byId[id];
  if (!def) return false;
  if (actief && actief !== id) stop();
  actief = id;
  actieveKamer = def.kamer || null;
  /* het prikbord dicht: de taakkaartjes staan anders over de knoppen van
     het spel heen (de bel en de avondronde doen dat al net zo) */
  if (window.Hotel && Hotel.bordDicht) Hotel.bordDicht();
  /* zolang dit spel speelt kiest het als eerste zijn plekken; de knoppen van
     het hotel wijken ervoor uit (hits.js) en de wens-wolkjes gaan even weg */
  Hits.voorrang(def.id);
  if (window.Hotel) Hotel.render();
  hersteek();
  if (def.kamer && World.actief() !== def.kamer) World.naar(def.kamer);
  try {
    if (def.start) def.start(ctxVoor(def));
    /* een spel mag onderweg een andere kamer kiezen (bedden valt bijvoorbeeld
       terug op kamer 2): dáár staan zijn knoppen, dus dáár wijkt het hotel */
    if (actief === id) actieveKamer = World.actief();
  } catch (e) {
    actief = null;
    toast('💛 Probeer iets anders', 'kind');
    return false;
  }
  return true;
}

function stop() {
  if (!actief) return;
  var def = byId[actief];
  actief = null;
  actieveKamer = null;
  try { if (def && def.stop) def.stop(); } catch (e) {}
  if (def) Hits.wisEigenaar(def.id);
  Hits.voorrang(null);
  Ui.leegPaneel();
  hersteek();
  if (window.Hotel) Hotel.render();      /* de wens-wolkjes komen weer terug */
}

function debug() {
  return { actief: actief, spellen: reg.map(function (d) {
    return { id: d.id, naam: d.naam, kamer: d.kamer, aan: ontgrendeld(d),
             hotspot: d.hotspot ? d.hotspot.obj : null, stub: !!d.stub };
  }) };
}

return { register: register, lijst: lijst, get: get, start: start, stop: stop,
         open: open, hersteek: hersteek, plek: plek, debug: debug,
         ontgrendeld: ontgrendeld, herstelInrichting: herstelInrichting,
         actieveKamer: function () { return actieveKamer; },
         zetMeubel: zetMeubel };
})();
