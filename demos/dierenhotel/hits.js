/* ---------------------------------------------------------------
   hits.js - de HOTSPOT-LAAG boven het canvas.

   De wereld is het rekenblad: alles wat je aanraakt (de bel, een bed,
   een bakje, de voerkar, een sleutel) is een echt voorwerp IN de kamer.
   Daarom ligt er over het canvas een tweede doorzichtige laag
   (#worldHits, naast de naamplaatjes-laag #worldTags) met knoppen en
   sleep-doelen precies op de schermplek van dat voorwerp.

   Drie dingen zijn belangrijk:
     1. z-index volgt EXACT de tekenvolgorde (klein x+z eerst, dus
        achteraan onderop). Ligt een dier vóór een bed, dan pakt
        elementFromPoint het dier - net wat je oog verwacht.
        (HOTEL.md 8.5: dit is de engine-afspraak die alle games delen.)
     2. we verzetten de knoppen alleen als het beeld verandert; blijft
        alles staan, dan raakt de DOM niet aan.
     3. een knop die bij een VOORWERP hoort staat ERBOVEN, niet erop:
        een kind moet de speelmand, het bakje en het bed nog kunnen zien.
        Zie "WAAR MAG EEN KNOP STAAN" hieronder.

   WAAR MAG EEN KNOP STAAN (het plaatsbeleid, o.op)
     Een hotspot krijgt van world.js één mikpunt: pr(x, z, y). Dat punt ligt
     op de BOVENKANT van het voorwerp (de eigenaar geeft y = de hoogte van
     het voorwerp in voxels: het bakje 7, de speelmand 8, een bed 13, de bel
     20). Het voorwerp zelf beslaat dus het strookje van dat punt naar
     beneden tot de vloer: hoog = y * (px per voxel).
       'boven'  (standaard voor een knop AAN een voorwerp)
                onderrand van de knop een kiertje boven het mikpunt; het
                voorwerp blijft helemaal in beeld. Uitwijken (UITWIJK) gaat
                dan eerst alleen omhoog of opzij, daarna alle kanten op maar
                niet óp het eigen voorwerp, en pas als het kader écht vol is
                alle kanten op (een knop die een ANDERE knop afdekt is erger
                dan een knop die een hoekje van zijn voorwerp afdekt).
       'onder'  past de knop niet meer boven in het kader, dan gaat hij
                onder het voorwerp staan (bovenrand een kiertje onder de
                vloerpunt). Uitwijken gaat dan eerst omlaag of opzij.
       'midden' precies op het mikpunt (het oude gedrag). Dat is wat een
                vrije plek, een kaartje, een cijferpad, een keuzestrook, een
                praatwolkje en een zelf-getekende knop (o.html) krijgen - en
                wat een spel expliciet mag vragen voor een voorwerp dat
                kleiner is dan de knop zelf: Hits.maak({..., op:'midden'}).
       'rand'   een cijfertag (kind:'tag') hoort ÓP zijn voorwerp, maar dekt
                hooguit een tiende ervan af: hij zakt met zijn onderrand net
                over de bovenrand van het voorwerp.
     'auto' (geen o.op meegegeven) kiest: 'rand' voor een tag, 'midden' voor
     een vaste kaart / eigen html / kaartklasse / y <= 0 (geen voorwerp
     eronder), anders 'boven'.

   SLEEP-DOELEN
     Een knop met `drop` die boven of onder zijn voorwerp staat krijgt een
     doorzichtig VANGVLAK over knop + voorwerp samen, in een eigen laagje
     onder de knoppen. Zo komt slepen naar het voorwerp zelf ook aan. Zie
     "VANGVLAK" verderop.

   KORT KADER (liggende telefoon)
     Heeft het spel dat nu speelt een vaste kaart in beeld (somkaart,
     cijferpad, keuzestrook), dan is die kaart plus de eigen knoppen van dat
     spel onaantastbaar: een knop van een ANDERE eigenaar die na het
     uitwijken nog steeds over die kaart of over die knoppen zou vallen gaat
     even weg (display:none) in plaats van eroverheen te liggen. Zodra de
     kaart weg is staat hij er het volgende beeld weer: we rekenen elk beeld
     opnieuw. debug().verstopt vertelt hoeveel er zo weg staan.

   Publiek:
     Hits.maak(o)          - hotspot erbij of bijwerken
     Hits.weg(id)          - hotspot weg (roept o.onWeg(spot) als die er is)
     Hits.wisEigenaar(nm)  - alle hotspots van één eigenaar weg (idem)
     Hits.plaats(kamer,pr) - (door world.js) alles op zijn plek zetten
     Hits.debug()          - wat staat waar, met welke z-index

   o.onWeg(spot)
     Optionele opruimhaak op de hotspot zelf. Hits.weg (en dus ook
     Hits.wisEigenaar) roept hem één keer aan, vóór het element uit de
     pagina gaat. ui.js hangt hier het opruimen van de resize-luisteraars
     van de sommenkaart aan. Gooit de haak, dan gaat de hotspot alsnog weg.
---------------------------------------------------------------- */
var Hits = (function () {
'use strict';

var MAX_PER_KAMER = 16;
var host = null, reg = Object.create(null), orde = [], laatsteKamer = null, teveel = 0, verstopt = 0;
/* De maten van het kader en van de knoppen bewaren we. Ze elke beeldflits
   opnieuw opmeten (clientWidth / offsetWidth) dwingt de browser tot een extra
   layout, en dat is precies wat je in een tekenlus niet wil. Opmeten gebeurt
   dus alleen als het kader van maat verandert of als er andere tekst in een
   knop komt te staan. */
var hostW = 0, hostH = 0;
/* Wie mag als eerste zijn plek kiezen? Zolang er een spel speelt is dat het
   spel: knoppen van het hotel (en zeker de wens-wolkjes) wijken dan uit, en
   niet andersom. De stekkerdoos zet dit bij start/stop. */
var voorrang = null;
function zetVoorrang(wie) { voorrang = wie || null; }
function laagVan(s) {
  if (s.vast || s.kind === 'tag') return 3;      /* cijfers en het pad staan vast */
  if (voorrang && s.door === voorrang) return 2; /* het spel dat nu speelt */
  if (s.klas && s.klas.indexOf('hotwens') >= 0) return 0;   /* wolkjes wijken het eerst */
  return 1;
}
/* ---------- het plaatsbeleid (zie de kop van dit bestand) ---------- */
var GAT = 4;            /* kiertje tussen knop en voorwerp, in css-px */
/* Zoveel van het voorwerp mag een cijfertag afdekken: een tiende. De
   plaatstest meet 15 % en offsetHeight rondt af op hele pixels, dus met een
   tiende houdt de tag ook op een scherp scherm marge over. */
var TAG_IN = 0.1;
/* Klassen die zeggen: dit is een kaartje of een praatje, geen naamplaatje van
   een voorwerp. Die zet de eigenaar zelf op zijn plek (hij rekent in
   schermpixels terug naar voxels), dus die laten we staan waar hij hem zet. */
var KAARTKLAS = /(^|\s)(hotwens|hotwolk|hotsom|hotpad|hotkeuzes|hotgetal)(\s|$)/;
function beleid(s) {
  var op = s.op || 'auto';
  if (op !== 'auto') return op;
  if (s.kind === 'tag') return 'rand';            /* cijfer ÓP het voorwerp */
  if (s.vast) return 'midden';                    /* kaart, pad, keuzestrook */
  if (!(s.y > 0)) return 'midden';                /* vrije plek op de vloer */
  if (s.html !== undefined && s.html !== null) return 'midden';   /* eigen inhoud */
  if (s.klas && KAARTKLAS.test(s.klas)) return 'midden';
  return 'boven';                                 /* knop AAN een voorwerp */
}
/* Hoeveel css-px is één voxel hoogte? Dat hangt aan g en dpr van world.js, en
   die veranderen alleen in meet() - dat is precies de plek die hermeet()
   aanroept. Dus: één keer opmeten met twee pr()-aanroepen na elke hermeet, en
   daarna onthouden. Zo komt er in de tekenlus geen enkele aanroep bij. */
var vSchaal = 0;
function voxelPx(pr, s) {
  if (!vSchaal) {
    var a = pr(s.x, s.z, 0), b = pr(s.x, s.z, 1);
    vSchaal = a.y - b.y;
    if (!(vSchaal > 0)) vSchaal = 2;
  }
  return vSchaal;
}
/* Uitwijkplekjes voor knoppen die elkaar afdekken: eerst de echte plek, dan
   omhoog (zoals de naamplaatjes al deden), dan schuin, dan opzij. In stappen
   van een hele knop, en altijd binnen het kader. */
/* Omhoog en opzij komen ALTIJD eerst (dat is waar een naamplaatje hoort);
   pas als daar niets vrij is proberen we omlaag, en dan twee stappen omlaag -
   in een kort kader is die tweede stap het verschil tussen "onder het
   voorwerp" en "weer bovenop het voorwerp". */
var UITWIJK = (function () {
  var op = [], neer = [], dx, dy;
  for (dy = 0; dy >= -3; dy--) for (dx = -2; dx <= 2; dx++) op.push([dx, dy]);
  for (dy = 1; dy <= 2; dy++) for (dx = -2; dx <= 2; dx++) neer.push([dx, dy]);
  function kost(p) { return Math.abs(p[1]) * 2 + Math.abs(p[0]) * 3; }
  function opKost(a, b) { return kost(a) - kost(b); }
  op.sort(opKost);
  neer.sort(opKost);
  return op.concat(neer);
})();
/* leengoed: zolang een spel bezig is mag het een bestaande knop overnemen
   (de voerkar leent het bakje van het hotel: tikken levert dan af) */
var leen = Object.create(null);

/* ---------- VANGVLAK: een sleep-doel is ook zijn voorwerp ----------
   De knop staat nu BOVEN het bakje, maar een kind sleept naar het bakje
   zelf. Daarom legt de laag over knop + voorwerp samen (de omhullende
   rechthoek) een doorzichtig vangvlak met dezelfde data-drop en data-h-*
   als de knop: ui.js zoekt bij het loslaten met
   elementFromPoint(...).closest(dropSel), dus zo'n vlak is een geldig doel.
   Waar hij ligt:
     * in een EIGEN laagje naast #worldHits, met z-index 2 (de knoppenlaag
       staat op 3). Zo pakt een echte knop altijd voor, en alles wat
       '#worldHits [data-hot]' of '#worldHits .hot' opvraagt (de tests, de
       games, watRaakt) ziet er niets van;
     * alleen voor een hotspot MET drop die ook echt boven of onder zijn
       voorwerp staat - een knop op 'midden' dekt zijn voorwerp zelf al.
   Tikken op het vlak doet hetzelfde als tikken op de knop: anders zou het
   vlak een tik op het voorwerp opslokken. */
var vangHost = null;
function zorgVangHost() {
  var h = zorgHost();
  if (!h || !h.parentNode) return null;
  if (!vangHost || !vangHost.isConnected) {
    vangHost = h.parentNode.querySelector('.vanglaag');
    if (!vangHost) {
      vangHost = document.createElement('div');
      vangHost.className = 'vanglaag';
      vangHost.setAttribute('aria-hidden', 'true');
      vangHost.style.cssText = 'position:absolute;inset:0;pointer-events:none;z-index:2';
      h.parentNode.insertBefore(vangHost, h);
    }
  }
  return vangHost;
}
function vangWeg(s) {
  if (s.vang && s.vang.parentNode) s.vang.parentNode.removeChild(s.vang);
  s.vang = null;
}
function vangUit(s) {
  if (s.vang && s.vang.style.display !== 'none') s.vang.style.display = 'none';
}
/* px, py = het middelpunt van de knop zoals hij nu staat; zi = plek in de rij */
function vangZet(s, px, py, zi) {
  var vl = zorgVangHost();
  if (!vl) return;
  if (!s.vang) {
    s.vang = document.createElement('div');
    s.vang.style.cssText = 'position:absolute;left:0;top:0;background:transparent;border:0;pointer-events:auto';
    s.vang.addEventListener('click', function (ev) {
      ev.preventDefault();
      var q = reg[s.id];
      if (!q) return;
      var l = leen[s.id];
      if (l && l.fn) { l.fn(q, ev); return; }
      if (q.aan) q.aan(q, ev);
    });
    vl.appendChild(s.vang);
  }
  var e = s.vang, w = breed(s), h = hoog(s);
  var x0 = Math.min(px - w / 2, s._ax - w / 2), x1 = Math.max(px + w / 2, s._ax + w / 2);
  var y0 = Math.min(py - h / 2, s._ay), y1 = Math.max(py + h / 2, s._ay + s._vh);
  var sl = x0.toFixed(1) + ',' + y0.toFixed(1) + ',' + (x1 - x0).toFixed(1) + ',' + (y1 - y0).toFixed(1);
  if (e.__vak !== sl) {
    e.__vak = sl;
    e.style.width = (x1 - x0).toFixed(1) + 'px';
    e.style.height = (y1 - y0).toFixed(1) + 'px';
    e.style.transform = 'translate(' + x0.toFixed(1) + 'px,' + y0.toFixed(1) + 'px)';
  }
  if (e.__zi !== zi) { e.__zi = zi; e.style.zIndex = zi; }
  if (e.__drop !== s.drop) { e.__drop = s.drop; e.setAttribute('data-drop', s.drop); }
  /* dezelfde eigen gegevens als de knop: de games lezen data-h-kamer,
     data-h-slot, data-h-naar, ... uit het doel dat ze vinden */
  var k, sleutel = '';
  if (s.data) for (k in s.data) sleutel += k + '' + s.data[k] + '';
  if (e.__dk !== sleutel) {
    e.__dk = sleutel;
    if (s.data) for (k in s.data) e.setAttribute('data-h-' + k, s.data[k]);
  }
  if (e.style.display === 'none') e.style.display = '';
}

function zorgHost() {
  if (!host || !host.isConnected) host = document.getElementById('worldHits');
  return host;
}

/* o = { id, kamer, x, z, y, icoon, label, getal, badge, titel, html,
        kind:'btn'|'drop'|'tag', drop, data, klas, prio, vast, d,
        op:'auto'|'boven'|'onder'|'midden'|'rand',   (zie het plaatsbeleid)
        volg(), aan(spot, ev), onWeg(spot) } */
function maak(o) {
  var s = reg[o.id];
  if (!s) { s = reg[o.id] = { id: o.id }; orde.push(o.id); }
  for (var k in o) s[k] = o[k];
  if (s.kind === undefined) s.kind = 'btn';
  if (s.prio === undefined) s.prio = 5;
  s.vuil = true;
  bouwEl(s);
  return s;
}

function weg(id) {
  var s = reg[id];
  if (!s) return;
  /* opruimhaak van de eigenaar: precies één keer, en een fout erin mag het
     weghalen niet tegenhouden (anders blijft er een dode knop staan) */
  if (s.onWeg) {
    var opruimen = s.onWeg;
    s.onWeg = null;
    try { opruimen(s); } catch (e) { console.warn('onWeg ' + id + ': ' + e.message); }
  }
  if (s.el && s.el.parentNode) s.el.parentNode.removeChild(s.el);
  vangWeg(s);
  delete reg[id];
  var i = orde.indexOf(id);
  if (i >= 0) orde.splice(i, 1);
}

function wisEigenaar(naam) {
  orde.slice().forEach(function (id) { if (reg[id] && reg[id].door === naam) weg(id); });
  laat(naam);
}

/* pak(id, wie, fn): deze knop is nu van mij. laat(wie): weer teruggeven.
   Het leengoed staat apart van de knoppen zelf, dus het hotel mag zijn
   knoppen ondertussen gewoon opnieuw opbouwen. */
function pak(id, wie, fn) { leen[id] = { door: wie, fn: fn }; }
function laat(wie) {
  for (var k in leen) if (!wie || leen[k].door === wie) delete leen[k];
}
function geleend(id) { return !!leen[id]; }

function bouwEl(s) {
  var h = zorgHost();
  if (!h) return;
  if (!s.el) {
    /* meestal een knop; het cijferpad is een doosje mét knopjes erin, en een
       knop in een knop mag niet van de browser */
    s.el = document.createElement(s.tagnaam || 'button');
    if (!s.tagnaam) s.el.type = 'button';
    s.el.setAttribute('data-hot', s.id);
    if (s.kind !== 'tag') s.el.addEventListener('click', function (ev) {
      ev.preventDefault();
      var q = reg[s.id];
      if (!q) return;
      var l = leen[s.id];
      if (l && l.fn) { l.fn(q, ev); return; }
      if (q.aan) q.aan(q, ev);
    });
    h.appendChild(s.el);
  }
  var kl = 'hot' + (s.kind === 'drop' ? ' hotdrop' : '') +
    (s.kind === 'tag' ? ' hottag' : '') + (s.klas ? ' ' + s.klas : '');
  if (s.el.className !== kl) s.el.className = kl;
  if (s.drop) s.el.setAttribute('data-drop', s.drop); else s.el.removeAttribute('data-drop');
  /* eigen gegevens krijgen een h- ervoor (data-h-kamer, data-h-slot, ...).
     Zonder dat voorvoegsel botst zo'n naam met de gewone data-attributen
     van het scherm - de kamerbalk gebruikt bijvoorbeeld ook data-kamer. */
  if (s.data) for (var k in s.data) s.el.setAttribute('data-h-' + k, s.data[k]);
  /* html mag alles overrulen: daarmee bouwt ui.js zijn spreekwolkjes,
     sommenkaartjes en het kleine cijferpad aan een voorwerp. */
  var inh = (s.html !== undefined && s.html !== null) ? s.html
    : ('<span class="ico">' + (s.icoon || '') + '</span>' +
       (s.getal !== undefined && s.getal !== null && s.getal !== ''
          ? '<span class="get">' + s.getal + '</span>' : '') +
       (s.label ? '<span class="lbl">' + s.label + '</span>' : '') +
       (s.badge ? '<span class="bdg">' + s.badge + '</span>' : ''));
  if (s.el.__inh !== inh) { s.el.innerHTML = inh; s.el.__inh = inh; }
  var titel = s.titel || s.label || s.id;
  if (s.kind === 'tag') {
    /* niet aan te tikken, niet aan te focussen, geen knoprol */
    if (s.el.getAttribute('aria-hidden') !== 'true') s.el.setAttribute('aria-hidden', 'true');
    if (s.el.hasAttribute('tabindex')) s.el.removeAttribute('tabindex');
  } else if (s.el.getAttribute('aria-label') !== titel) s.el.setAttribute('aria-label', titel);
  if (s._meet !== inh) { s._meet = inh; s._w = 0; s._h = 0; }
}

/* De knopmaat één keer opmeten (na een inhoudswijziging), daarna onthouden.
   LET OP: een knop die nog op display:none staat meet 0 bij 0. Dat gebeurt
   precies één beeld lang als je een kamer binnenkomt (zijn knoppen stonden
   uit). Die 0 mogen we NIET onthouden: dan blijft de noodmaat van 56 x 48
   hangen, klemt de laag de knop op de verkeerde plek en schuift hij kaartjes
   uit elkaar die elkaar niet eens raken. We onthouden dus alleen een echte
   maat en meten anders het volgende beeld opnieuw. */
function maat(s) {
  if (!s._w || !s._h) {
    var w = s.el.offsetWidth, h = s.el.offsetHeight;
    if (w && h) { s._w = w; s._h = h; } else { s._w = 0; s._h = 0; }
  }
  return s;
}
function breed(s) { return s._w || 56; }
function hoog(s) { return s._h || 48; }
function hermeet() {
  var h = zorgHost();
  hostW = h ? h.clientWidth : 0;
  hostH = h ? h.clientHeight : 0;
  vSchaal = 0;                       /* andere voxelmaat: opnieuw opmeten */
  orde.forEach(function (id) { if (reg[id]) { reg[id]._w = 0; reg[id]._h = 0; } });
}

/* ---------- alles op zijn plek: één keer per (vuil) beeld ----------
   pr(x, z, y) geeft de plek in css-pixels binnen het wereldkader. */
function plaats(kamer, pr) {
  var h = zorgHost();
  if (!h) return;
  var i, s, zicht = [];
  /* eerst iedereen laten meebewegen: een wolkje boven een dier dat naar een
     andere kamer loopt, verhuist mee (en is daar dan zichtbaar, hier niet) */
  for (i = 0; i < orde.length; i++) {
    s = reg[orde[i]];
    if (!s || !s.volg) continue;
    var q = s.volg(s);
    if (!q) continue;
    if (q.x !== undefined) s.x = q.x;
    if (q.z !== undefined) s.z = q.z;
    if (q.y !== undefined) s.y = q.y;
    if (q.kamer) s.kamer = q.kamer;
    s.d = q.d;
  }
  for (i = 0; i < orde.length; i++) {
    s = reg[orde[i]];
    if (!s) continue;
    if (s.kamer && s.kamer !== kamer) {
      if (s.el.style.display !== 'none') s.el.style.display = 'none';
      vangUit(s);                    /* het vangvlak gaat mee uit */
      continue;
    }
    /* meteen aanzetten: anders meet hij straks 0 bij 0 (zie maat()) */
    if (s.el.style.display === 'none') s.el.style.display = '';
    zicht.push(s);
  }
  /* te veel knoppen in één kamer: de minst belangrijke blijven weg
     (HOTEL.md: hooguit een handvol dingen per kamer om aan te raken) */
  teveel = Math.max(0, zicht.length - MAX_PER_KAMER);
  if (teveel > 0) {
    zicht.sort(function (a, b) {
      var la = laagVan(a), lb = laagVan(b);
      if (la !== lb) return lb - la;
      return b.prio - a.prio;
    });
    for (i = MAX_PER_KAMER; i < zicht.length; i++) {
      if (zicht[i].el.style.display !== 'none') zicht[i].el.style.display = 'none';
      vangUit(zicht[i]);
    }
    zicht = zicht.slice(0, MAX_PER_KAMER);
  }
  /* diepte: precies de tekensortering van world.js (klein x+z eerst) */
  for (i = 0; i < zicht.length; i++) {
    s = zicht[i];
    s._d = s.d === undefined || s.d === null ? s.x + s.z : s.d;
  }
  zicht.sort(function (a, b) { return a._d - b._d; });
  /* 1. plek uitrekenen en binnen het kader klemmen: een wens-wolkje boven een
        dier dat achteraan staat zou er anders half buiten vallen en niet meer
        te tikken zijn. */
  if (!hostW || !hostH) hermeet();
  /* Het kader heeft (nog) geen maat: dat gebeurt heel even bij het opstarten
     en bij het wisselen van staand naar liggend. Dan zetten we NIETS neer -
     anders klapt elke knop in de linkerbovenhoek op elkaar. Volgende beeld
     opnieuw. */
  if (!hostW || !hostH) return;
  var rand = 26, plekken = [];
  for (i = 0; i < zicht.length; i++) {
    s = maat(zicht[i]);
    var p = pr(s.x, s.z, s.y || 0);
    var hw = breed(s) / 2, hh = hoog(s) / 2;
    /* Het mikpunt ligt op de bovenkant van het voorwerp; het voorwerp zelf
       hangt eronder tot de vloer. Die twee getallen bewaren we (debug leest
       ze, en de knop mag straks alleen nog omhoog of opzij uitwijken). */
    var op = beleid(s), vh = s.y > 0 ? s.y * voxelPx(pr, s) : 0;
    s._ax = p.x; s._ay = p.y;
    if (op !== 'midden') {
      if (op === 'boven') {
        /* past de knop niet meer boven het voorwerp binnen het kader, dan
           gaat hij eronder staan - liever onder dan eroverheen */
        if (p.y - hoog(s) - GAT < 2 && p.y + vh + hoog(s) + GAT < hostH - 2) op = 'onder';
      }
      if (op === 'boven') p.y -= hh + GAT;
      else if (op === 'onder') p.y += vh + hh + GAT;
      else if (op === 'rand') p.y -= hh - Math.min(GAT, vh * TAG_IN);
    }
    s._op = op; s._vh = vh;
    if (hostW > 3 * rand && hostH > 3 * rand) {
      p.x = Math.max(hw + 2, Math.min(hostW - hw - 2, p.x));
      p.y = Math.max(hh + 2, Math.min(hostH - hh - 2, p.y));
    }
    plekken.push(p);
  }
  /* 2. knoppen die elkaar afdekken uit elkaar schuiven. We lopen van VOOR
        naar achter: het voorste voorwerp houdt zijn eigen plek (dat is ook
        wat je vooraan ziet staan), wat erachter ligt wijkt naar boven uit -
        precies zoals de naamplaatjes dat al deden. Zo is elke knop altijd
        apart aan te tikken, ook als de kamer krap in beeld staat. */
  var gedaan = [], j, g;
  /* Wie heeft er een VASTE kaart in beeld? Zolang die er staat is er in een
     kort kader (liggende telefoon) geen ruimte meer over: knoppen van andere
     eigenaars die er na het uitwijken nog overheen zouden vallen gaan even
     weg in plaats van eroverheen te liggen (zie de kop van dit bestand).
     Het spel dat nu speelt gaat voor; speelt er niets, dan is het de
     eigenaar van de kaart zelf (de rekening aan de balie bijvoorbeeld). */
  var kaartVan = null, anderKaart = false;
  for (i = 0; i < zicht.length; i++) {
    s = zicht[i];
    if (!s.vast || !s.door) continue;
    if (voorrang && s.door === voorrang) { kaartVan = s.door; break; }
    if (kaartVan === null) kaartVan = s.door;
    else if (kaartVan !== s.door) anderKaart = true;
  }
  if (!voorrang && anderKaart) kaartVan = null;   /* twee kaarten, geen baas */
  verstopt = 0;
  /* De volgorde waarin iedereen zijn plek kiest: eerst wat vastzit (cijfers
     op een voorwerp, het cijferpad), dan het spel dat nu speelt, dan de
     gewone hotelknoppen, en als laatste de wens-wolkjes. Binnen elke laag
     kiest het voorste voorwerp eerst. Wie later kiest, wijkt uit. */
  var orde2 = [];
  for (i = 0; i < zicht.length; i++) orde2.push(i);
  orde2.sort(function (a, b) {
    var la = laagVan(zicht[a]), lb = laagVan(zicht[b]);
    if (la !== lb) return lb - la;
    return zicht[b]._d - zicht[a]._d;
  });
  for (var oi = 0; oi < orde2.length; oi++) {
    i = orde2[oi];
    s = zicht[i];
    s._weg = 0;
    if (s.vast || s.kind === 'tag') {
      gedaan.push({ x: plekken[i].x, y: plekken[i].y, w: breed(s), h: hoog(s),
                    vip: kaartVan && s.door === kaartVan ? 1 : 0 });
      continue;
    }
    var q = plekken[i], w = breed(s), hgt = hoog(s);
    var ox = q.x, oy = q.y, poging, gekozen = null, laatste = null, ronde;
    /* Vier rondes, van netjes naar noodgeval. Een knop aan een voorwerp wijkt
       normaal alleen omhoog of opzij uit (en een knop ONDER een voorwerp
       alleen omlaag of opzij), want terugzakken dekt het voorwerp weer af:
         ronde 0  alleen die richting;
         ronde 1  alle richtingen, maar niet ÓP het eigen voorwerp;
         ronde 2  STAPELEN: rij voor rij van de bovenrand van het kader naar
                  beneden, per rij een paar kolommen. Dat is de enige manier
                  om drie brede kaartjes (de taakjes van het prikbord zijn
                  148 px breed) én vijf knoppen in een kader van 326 x 383
                  kwijt te kunnen: het rooster van UITWIJK hangt aan het
                  mikpunt, en die mikpunten liggen soms allemaal in dezelfde
                  band;
         ronde 3  alles - twee knoppen die elkaar afdekken is erger dan een
                  knop die een hoekje van zijn voorwerp afdekt. (In de gang
                  schoof de deurknop anders precies onder het wolkje van de
                  voerkar, en dan is die deur geen sleep-doel meer.)
       Lukt zelfs ronde 3 niet, dan valt hij terug op zijn eerste keus: boven
       het voorwerp (zie `laatste`). In een gewone kamer is de plek al in de
       eerste paar pogingen van ronde 0 gevonden. */
    var STAPEL_DX = [0, -1, 1, -2, 2];
    for (ronde = 0; ronde < 4 && !gekozen; ronde++) {
      var n = ronde === 2 ? STAPEL_DX.length * Math.max(1, Math.ceil(hostH / (hgt + 3)))
                          : UITWIJK.length;
      for (poging = 0; poging < n; poging++) {
        var kx, ky;
        if (ronde === 2) {
          kx = ox + STAPEL_DX[poging % STAPEL_DX.length] * (w + 4);
          ky = hgt / 2 + 2 + Math.floor(poging / STAPEL_DX.length) * (hgt + 3);
          if (ky > hostH - hgt / 2 - 2) continue;
        } else {
          if (ronde === 0) {
            if (s._op === 'boven' && UITWIJK[poging][1] > 0) continue;
            if (s._op === 'onder' && UITWIJK[poging][1] < 0) continue;
          }
          kx = ox + UITWIJK[poging][0] * (w + 4);
          ky = oy + UITWIJK[poging][1] * (hgt + 3);
        }
        kx = Math.max(w / 2 + 2, Math.min(Math.max(w / 2 + 2, hostW - w / 2 - 2), kx));
        ky = Math.max(hgt / 2 + 2, Math.min(Math.max(hgt / 2 + 2, hostH - hgt / 2 - 2), ky));
        if (ronde >= 1 && ronde <= 2 && s._vh > 0 && (s._op === 'boven' || s._op === 'onder') &&
            ky - hgt / 2 < s._ay + s._vh && ky + hgt / 2 > s._ay) continue;
        var botst = false;
        for (j = 0; j < gedaan.length; j++) {
          g = gedaan[j];
          if (Math.abs(g.x - kx) < (g.w + w) / 2 - 1 && Math.abs(g.y - ky) < (g.h + hgt) / 2 - 1) { botst = true; break; }
        }
        if (!botst) { gekozen = [kx, ky]; break; }
        if (!laatste && ronde !== 2) laatste = [kx, ky];   /* laatste redmiddel */
      }
    }
    if (!gekozen) gekozen = laatste || [ox, oy];
    q.x = gekozen[0]; q.y = gekozen[1];
    /* kort kader: valt deze knop van een ander nog steeds over de kaart of
       over de knoppen van het spel dat speelt? Dan gaat hij even weg. */
    if (kaartVan && s.door !== kaartVan) {
      for (j = 0; j < gedaan.length; j++) {
        g = gedaan[j];
        if (!g.vip) continue;
        if (Math.abs(g.x - q.x) < (g.w + w) / 2 - 1 && Math.abs(g.y - q.y) < (g.h + hgt) / 2 - 1) {
          s._weg = 1; verstopt++;
          break;
        }
      }
      if (s._weg) continue;      /* niet in gedaan: de plek blijft vrij */
    }
    gedaan.push({ x: q.x, y: q.y, w: w, h: hgt,
                  vip: kaartVan && s.door === kaartVan ? 1 : 0 });
  }
  /* 3. neerzetten; z-index blijft exact de tekenvolgorde */
  for (i = 0; i < zicht.length; i++) {
    s = zicht[i];
    var pp = plekken[i], zi = 20 + i;
    if (s._px !== pp.x || s._py !== pp.y) {
      s._px = pp.x; s._py = pp.y;
      s.el.style.transform = 'translate(-50%,-50%) translate(' + pp.x.toFixed(1) + 'px,' + pp.y.toFixed(1) + 'px)';
    }
    if (s._zi !== zi) { s._zi = zi; s.el.style.zIndex = zi; }
    /* een knop die voor de kaart van het spel moest wijken staat even uit;
       het volgende beeld (kaart weg) staat hij er weer */
    var wil = s._weg ? 'none' : '';
    if (s.el.style.display !== wil) s.el.style.display = wil;
    /* sleep-doel boven of onder zijn voorwerp: het vangvlak dekt knop én
       voorwerp, zodat slepen naar het voorwerp zelf ook aankomt */
    if (!s._weg && s.drop && s._vh > 0 && (s._op === 'boven' || s._op === 'onder'))
      vangZet(s, pp.x, pp.y, 1 + i);
    else vangUit(s);
    s.vuil = false;
  }
  laatsteKamer = kamer;
}

function lijst() { return orde.map(function (id) { return reg[id]; }).filter(Boolean); }

function debug() {
  var uit = { kamer: laatsteKamer, teveel: teveel, verstopt: verstopt,
              kader: [hostW, hostH], voxelPx: vSchaal, spots: [] };
  lijst().forEach(function (s) {
    if (!s.el) return;
    uit.spots.push({ id: s.id, kamer: s.kamer, door: s.door || null, d: s._d, z: s._zi, kind: s.kind,
                     zichtbaar: s.el.style.display !== 'none', klas: s.klas || null,
                     px: s._px, py: s._py, w: s._w, h: s._h, drop: s.drop || null,
                     /* het plaatsbeleid, het mikpunt vóór het opschuiven en het
                        voorwerp eronder: vak = [x, y, w, h] om het middelpunt.
                        vh (= y * voxelPx) is echt gemeten; de breedte van een
                        voorwerp weet deze laag niet, dus die schatten we op de
                        knopbreedte (het strookje dat de knop kán afdekken).
                        vak is er ALLEEN als de laag deze knop ook echt aan een
                        voorwerp hangt: bij op:'midden' (een kaartje, een
                        wolkje, een vrije plek) weet de laag van geen voorwerp
                        en doet ze er dus ook geen uitspraak over. */
                     op: s._op || null, anker: s._ax === undefined ? null : [s._ax, s._ay],
                     vh: s._vh || 0, weg: !!s._weg,
                     /* het vangvlak (knop + voorwerp samen) als "x,y,w,h" */
                     vang: (s.vang && s.vang.style.display !== 'none') ? s.vang.__vak : null,
                     vak: (s._vh > 0 && s._op && s._op !== 'midden')
                            ? [s._ax, s._ay + s._vh / 2, Math.max(breed(s), s._vh), s._vh] : null });
  });
  uit.voorrang = voorrang;
  uit.spots.sort(function (a, b) { return (a.z || 0) - (b.z || 0); });
  return uit;
}

/* voor de tests: wat pakt een tik precies op dit punt? */
function watRaakt(x, y) {
  var e = document.elementFromPoint(x, y);
  if (!e) return null;
  var h = e.closest ? e.closest('[data-hot]') : null;
  return h ? h.getAttribute('data-hot') : null;
}

return { maak: maak, weg: weg, wisEigenaar: wisEigenaar, plaats: plaats, hermeet: hermeet,
         voorrang: zetVoorrang,
         pak: pak, laat: laat, geleend: geleend,
         lijst: lijst, debug: debug, watRaakt: watRaakt, MAX: MAX_PER_KAMER };
})();
