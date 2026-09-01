/* game.js - de dagcyclus: ochtend (delen), middag (klok), avond (plannen), adoptie */

var Scenes = {};
var vigTimer = null;

function go(phase) {
  clearTimeout(vigTimer);
  state.phase = phase;
  render();
  window.scrollTo(0, 0);
  if (phase === 'adoptie' || phase === 'klaar') Snd.hoera();
  else if (phase === 'morning') Snd.dag();
  bewaarSpel();
}

/* in welke fasen speelt het diorama mee (de avond en de adoptie hebben
   hun eigen dier-in-beeld, daar is de tuin niet nodig) */
var WERELD_FASE = { morning: 1, middag: 1 };

function render() {
  $('#dayNum').textContent = state.day;
  $('#scoopNum').textContent = state.scoops;
  $('#letterNum').textContent = state.brieven.length;
  if (window.World) {
    World.sync(state.dieren);
    World.toon(!!WERELD_FASE[state.phase]);
  }
  var orde = { morning: 0, middag: 1, avond: 2 };
  var cur = orde[state.phase] === undefined ? 3 : orde[state.phase];
  $$('#phasebar .pip').forEach(function (p) {
    var i = orde[p.getAttribute('data-p')];
    p.className = 'pip' + (i === cur ? ' on' : (i < cur ? ' done' : ''));
  });
  var host = $('#scene');
  host.innerHTML = '';
  (Scenes[state.phase] || Scenes.morning)(host);
}

/* =====================================================================
   OCHTEND - VOEDERTIJD  (eerlijk delen, rest naar de snoeppot)
===================================================================== */
Scenes.morning = function (host) {
  if (!state.morning) initMorning();
  host.innerHTML = '<div id="mArea"></div>';
  paintMorning();
};

function moodVoor(a) {
  var m = state.morning;
  if (m.klaar) return 'bouncy';
  if (m.feedback && m.bowls[a.id] < m.per) return 'droopy';
  return 'blij';
}

function koekjes(n, klaar) {
  var s = '';
  for (var i = 0; i < n; i++) {
    s += klaar
      ? '<span style="animation:fadeup .5s ease-in forwards;animation-delay:' + (i * 90) + 'ms">🍪</span>'
      : '<span>🍪</span>';
  }
  return s;
}

function paintMorning() {
  var m = state.morning, n = state.dieren.length, h = '';

  if (state.dagBericht) h += '<div class="card">' + state.dagBericht + '</div>';

  h += '<div class="card"><h1>☀️ Voedertijd</h1><div class="opdracht">';
  if (m.klaar) {
    h += '<p><b>Precies eerlijk!</b> Ieder dier ' + meervoud(m.per, 'koekje', 'koekjes') +
         (m.rest ? ' en ' + meervoud(m.rest, 'koekje', 'koekjes') + ' in de snoeppot' : '') +
         '. Smakelijk eten! 😋</p>';
  } else {
    h += '<p>Er zijn <b>' + m.total + ' koekjes</b> voor <b>' + n + ' dieren</b>. ' +
         'Verdeel ze <b>eerlijk</b>: ieder dier evenveel. Wat overblijft mag in de snoeppot.</p>' +
         '<p class="hint">Sleep de koekjes uit de zak naar een bakje. Tikken op een bakje mag ook.</p>';
  }
  h += '</div>';

  /* zak + handje */
  if (!m.klaar) {
    h += '<div class="bagrow"><div class="bag" id="bag">' +
         '<div class="n">🍪 ' + m.bag + '</div><div class="lbl">koekjes in de zak</div>' +
         '<div class="crumbs">' + koekjes(Math.min(m.bag, 14)) + '</div></div>' +
         '<div class="hand"><span class="hint">Pak per keer:</span>' +
         [1, 2, 5].map(function (k) {
           return '<button class="btn' + (m.hand === k ? ' on' : '') + '" data-h="' + k + '">' + k + ' 🍪</button>';
         }).join('') + '</div></div>';
  }

  /* bakjes: het rekenwerk staat hier, de dieren staan in de tuin erboven */
  h += '<div class="bowls">';
  state.dieren.forEach(function (a) {
    var c = m.bowls[a.id], mis = m.per - c;
    /* wereld-hook: bakje en stemming in de tuin volgen precies het scherm */
    if (!m.klaar) { Art.setFood(a.id, c, m.per); Art.setMood(a.id, moodVoor(a)); }
    h += '<div class="pet' + (m.feedback && !m.klaar && mis > 0 ? ' mis' : '') + '">' +
      '<div class="nm">' + esc(a.name) + '</div>' +
      '<div class="bowl" data-drop="bowl" data-id="' + a.id + '">' + koekjes(c, m.klaar) + '</div>' +
      '<div class="count">' + meervoud(c, 'koekje', 'koekjes') + '</div>';
    if (m.feedback && !m.klaar && mis > 0) h += '<div class="need">nog ' + mis + '? 🥺</div>';
    if (m.feedback && !m.klaar && mis < 0) h += '<div class="need over">' + (-mis) + ' te veel</div>';
    if (!m.klaar && c > 0) h += '<button class="mini" data-back="' + a.id + '">↩ eentje terug</button>';
    h += '</div>';
  });
  h += '<div class="jarwrap"><div style="font-size:2.2rem">🫙</div><div class="nm">Snoeppot</div>' +
       '<div class="bowl jar" data-drop="bowl" data-id="__pot">' + koekjes(m.pot, false) + '</div>' +
       '<div class="count">' + meervoud(m.pot, 'koekje', 'koekjes') + '</div>';
  if (m.feedback && !m.klaar && m.pot !== m.rest) {
    h += '<div class="need' + (m.pot > m.rest ? ' over' : '') + '">' +
      (m.rest === 0 ? 'hier hoort niets' : m.rest === 1 ? 'hier hoort er 1' : 'hier horen er ' + m.rest) + '</div>';
  }
  if (!m.klaar && m.pot > 0) h += '<button class="mini" data-back="__pot">↩ eentje terug</button>';
  h += '</div></div>';

  /* knoppen */
  h += '<div class="row center" style="margin-top:16px">';
  if (m.klaar) {
    h += '<button class="btn go big" id="naarMiddag">Verder naar de middag ▸</button>';
  } else {
    h += '<button class="btn go big" id="klaarBtn">Klaar! ✓</button>' +
         '<button class="btn soft" id="resetBtn">Opnieuw beginnen ↺</button>';
    if (m.misses >= 2) h += '<button class="btn" id="vetBtn">🩺 Vraag buurvrouw Els</button>';
  }
  h += '</div>';
  if (!m.klaar && m.misses >= 1) {
    h += '<p class="hint" style="text-align:center;margin-top:8px">Je mag het zo vaak proberen als je wil. Er gaat niets kapot. 💛</p>';
  }
  h += '</div>';

  $('#mArea').innerHTML = h;
  wireMorning();
  bewaarSpel();
}

function verplaats(id, aantal) {
  var m = state.morning;
  var k = Math.min(aantal, m.bag);
  if (k <= 0) { Snd.zacht(); toast('De zak is leeg!', 'kind'); return; }
  m.bag -= k;
  if (id === '__pot') m.pot += k; else m.bowls[id] += k;
  paintMorning();
  Snd.plop(m.hand);
}

function terug(id) {
  var m = state.morning;
  if (id === '__pot') { if (m.pot > 0) { m.pot--; m.bag++; Snd.terug(); } }
  else if (m.bowls[id] > 0) { m.bowls[id]--; m.bag++; Snd.terug(); }
  paintMorning();
}

function wireMorning() {
  var m = state.morning;
  var bag = $('#bag');
  if (bag) {
    makeDraggable(bag, {
      dropSel: '[data-drop="bowl"]',
      ghostHTML: function () { return '<div style="font-size:26px">' + koekjes(Math.min(m.hand, m.bag)) + '</div>'; },
      canDrag: function () { return m.bag > 0; },
      onDrop: function (t) { verplaats(t.getAttribute('data-id'), m.hand); },
      onTap: function () { toast('Sleep de koekjes naar een bakje, of tik op een bakje.', 'kind'); }
    });
  }
  $$('#mArea [data-h]').forEach(function (b) {
    b.onclick = function () { m.hand = +b.getAttribute('data-h'); paintMorning(); };
  });
  $$('#mArea [data-drop="bowl"]').forEach(function (b) {
    b.onclick = function () { if (!m.klaar) verplaats(b.getAttribute('data-id'), m.hand); };
  });
  $$('#mArea [data-back]').forEach(function (b) {
    b.onclick = function () { terug(b.getAttribute('data-back')); };
  });
  var kb = $('#klaarBtn'); if (kb) kb.onclick = checkMorning;
  var rb = $('#resetBtn'); if (rb) rb.onclick = function () { resetBakjes(); };
  var vb = $('#vetBtn'); if (vb) vb.onclick = vetVoorbeeld;
  var nm = $('#naarMiddag'); if (nm) nm.onclick = function () { go('middag'); };
}

function resetBakjes() {
  var m = state.morning;
  state.dieren.forEach(function (a) { m.bowls[a.id] = 0; });
  m.pot = 0; m.bag = m.total; m.feedback = null;
  paintMorning();
}

function checkMorning() {
  var m = state.morning;
  if (m.bag > 0) {
    m.misses++; m.feedback = true; paintMorning(); Snd.zacht();
    toast('Er ' + (m.bag === 1 ? 'zit nog 1 koekje' : 'zitten nog ' + m.bag + ' koekjes') + ' in de zak.', 'kind');
    return;
  }
  var goed = state.dieren.every(function (a) { return m.bowls[a.id] === m.per; }) && m.pot === m.rest;
  if (!goed) {
    m.misses++; m.feedback = true; paintMorning(); Snd.zacht();
    var tekort = state.dieren.filter(function (a) { return m.bowls[a.id] < m.per; });
    if (tekort.length) toast(tekort[0].name + ' kijkt een beetje sip... kijk eens bij de bakjes. 💛', 'kind');
    else toast('Bijna! Ieder dier moet evenveel krijgen.', 'kind');
    return;
  }
  m.klaar = true;
  state.fedOk = true;
  state.snoeppot += m.pot;
  paintMorning();
  /* voxel-hook: eerst smullen (bakje leeg, kruimels), daarna blij */
  Art.feast(state.dieren.map(function (a) { return a.id; }));
  toast('Eerlijk verdeeld! Iedereen smult. 🎉', 'happy');
  Snd.tover();
}

function vetVoorbeeld() {
  var m = state.morning, n = state.dieren.length;
  var tel = [], s = 0;
  for (var i = 0; i < n; i++) { s += m.per; tel.push(s); }
  var h = '<h2>🩺 Buurvrouw Els legt het even voor je neer</h2>' +
    '<p>Kijk, ik leg de ' + m.total + ' koekjes op het dienblad:</p><div class="tray">';
  state.dieren.forEach(function (a) {
    h += '<div class="trayrow"><span class="who">' + esc(a.name) + '</span>' + koekjes(m.per) + '</div>';
  });
  h += '<div class="trayrow"><span class="who">Snoeppot</span>' +
       (m.rest ? koekjes(m.rest) : '<span class="hint">leeg</span>') + '</div></div>';
  h += '<p><b>' + m.total + ' koekjes, ' + n + ' dieren.</b> Ieder <b>' + m.per + '</b>' +
       (m.rest ? ', en <b>' + m.rest + '</b> blijft over voor de snoeppot' : ', precies op') + '.</p>' +
       '<p class="hint">Tel maar mee met mij: ' + tel.join(' … ') +
       (m.rest ? ' … en dan nog ' + m.rest + ' over.' : '.') + '</p>' +
       '<div class="row center"><button class="btn go big" id="vetOk">Ik snap het – ik doe het zelf! ▸</button></div>';
  openSheet(h);
  Snd.brief();
  $('#vetOk').onclick = function () {
    closeSheet();
    state.morning.vetGezien = true;
    resetBakjes();
    toast('Zet jij ze nu maar neer. 💛', 'kind');
  };
}

/* =====================================================================
   MIDDAG - PLANBORD (klokstrook 14:00-16:00 in blokjes van 15 min)
===================================================================== */
function tijd(min) {
  var t = 14 * 60 + min, u = Math.floor(t / 60), m = t % 60;
  return u + ':' + (m < 10 ? '0' : '') + m;
}
var ACT_ZIN = { Wandeling: 'gaat lekker wandelen', Spelen: 'gaat spelen', Bad: 'gaat in bad',
                Plonzen: 'gaat plonzen', Dierenarts: 'kijkt alle dieren na',
                Bezoek: 'komt kijken bij de dieren', Voer: 'brengt de brokken',
                Klusje: 'maakt de hokken schoon' };
/* ACT_LID / actLid staan in state.js, zodat de regelkaartjes en de
   foutmelding gegarandeerd dezelfde woorden gebruiken */

Scenes.middag = function (host) {
  if (!state.middag) initMiddag();
  host.innerHTML = '<div id="dArea"></div>';
  paintMiddag();
};

function paintMiddag() {
  var d = state.middag;
  var vrij = d.blokken.filter(function (b) { return b.at === null; });
  var h = '<div class="card"><h1>🕑 Het planbord</h1>' +
    '<p>Alles moet <b>vóór 16:00</b> klaar zijn, en niet twee dingen tegelijk. Elk blokje is <b>15 minuten</b>.</p>';

  /* regels van vandaag: vriendelijke plaatjeskaartjes vóór de strook */
  if (d.regels.length) {
    h += '<div class="regels"><h2>📋 Regels van vandaag</h2><div class="regelrij">';
    d.regels.forEach(function (r, i) {
      h += '<div class="regel' + (d.markeer.indexOf('r' + i) >= 0 ? ' mis' : '') + '">' +
        '<span class="ico">' + r.emoji + '</span><span>' + esc(r.tekst) + '</span></div>';
    });
    h += '</div></div>';
  }
  if (d.fout) h += '<div class="uitleg">' + d.fout + '</div>';

  h += '<p class="hint">Sleep een blokje op de strook. Of: tik het blokje aan en tik dan op een vakje. ' +
    'Tik op een geplaatst blokje om het terug te leggen.</p>' +
    '<div class="clockends"><span>🕑 14:00</span><span>16:00 🕓</span></div>' +
    '<div class="stripwrap"><div class="strip" id="strip">';
  for (var i = 0; i < 8; i++) h += '<div class="cell" data-drop="cell" data-i="' + i + '">' + tijd(i * 15) + '</div>';
  d.blokken.forEach(function (b) {
    if (b.at === null) return;
    h += '<div class="placed' + (b.vast ? ' vast' : '') + (d.markeer.indexOf(b.id) >= 0 ? ' mis' : '') +
      '" data-blok="' + b.id + '" style="left:' + (b.at / 8 * 100) + '%;width:' +
      (b.cells / 8 * 100) + '%;background:' + (ACT_KLEUR[b.act] || '#FFDD8C') + '">' +
      '<div>' + (b.vast ? '🔒 ' : '') + (ACT_EMOJI[b.act] || '✨') + ' ' + esc(b.act) + '</div>' +
      '<div>' + esc(b.name) + '</div></div>';
  });
  h += '</div></div>';

  h += '<div class="blocks">';
  if (!vrij.length) h += '<p class="hint">Alle blokjes staan op de strook. 👍</p>';
  vrij.forEach(function (b) {
    h += '<div class="block' + (d.gekozen === b.id ? ' sel' : '') +
      (d.markeer.indexOf(b.id) >= 0 ? ' mis' : '') + '" data-blok="' + b.id +
      '" style="background:' + (ACT_KLEUR[b.act] || '#FFDD8C') + '">' +
      '<div>' + (ACT_EMOJI[b.act] || '✨') + ' ' + esc(b.act) + ' ' + esc(b.name) + '</div>' +
      '<div class="mins">' + b.mins + ' min</div></div>';
  });
  h += '</div>';

  h += '<div class="row center" style="margin-top:16px">' +
    '<button class="btn go big" id="startMiddag">Klaar! ✓</button>' +
    '<button class="btn soft" id="leegBtn">Strook leegmaken ↺</button></div>';
  if (d.pogingen >= 1) {
    h += '<p class="hint" style="text-align:center;margin-top:8px">' +
      'Schuif maar rustig door tot het klopt. Er gaat niets kapot. 💛</p>';
  }
  h += '</div>';

  $('#dArea').innerHTML = h;
  wireMiddag();
  bewaarSpel();
}

/* de vriendelijke controle: benoem precies wat er nog niet klopt */
function checkMiddag() {
  var d = state.middag;
  d.markeer = []; d.fout = null;
  var vrij = d.blokken.filter(function (b) { return b.at === null; });
  if (vrij.length) {
    d.pogingen++;
    d.markeer = vrij.map(function (b) { return b.id; });
    d.fout = vrij.length === 1
      ? 'Er ligt nog <b>1 blokje</b> naast de strook: ' + esc(vrij[0].act) + ' van ' + esc(vrij[0].name) + '.'
      : 'Er liggen nog <b>' + vrij.length + ' blokjes</b> naast de strook.';
    paintMiddag(); Snd.zacht();
    toast('Alles moet een plekje op de strook krijgen. 💛', 'kind');
    return;
  }
  var fouten = planFouten(d, planStand(d));
  if (fouten.length) {
    d.pogingen++;
    var r = fouten[0], A = blokVan(d, r.a), B = blokVan(d, r.b);
    var vanaf = tijd((B.at + B.cells) * 15);
    d.markeer = [A.id, B.id, 'r' + d.regels.indexOf(r)];
    d.fout = 'Kijk: ' + esc(bezit(A.name)) + ' ' + esc(String(A.act).toLowerCase()) +
      ' staat <b>vóór</b> ' + esc(actLid(B)) + ' van ' + esc(B.name) + '. ' +
      'Zet ' + esc(actLid(A)) + ' pas vanaf <b>' + vanaf + '</b> — dán klopt het.';
    paintMiddag(); Snd.zacht();
    toast(bezit(A.name) + ' ' + String(A.act).toLowerCase() + ' moet ná ' + actLid(B) + '. 💛', 'kind');
    return;
  }
  Snd.ja();
  speelMiddag();
}

function plaatsBlok(id, i) {
  var d = state.middag;
  var b = null, k;
  for (k = 0; k < d.blokken.length; k++) if (d.blokken[k].id === id) b = d.blokken[k];
  if (!b) return 'weg';
  if (b.vast) return 'vast';
  if (i < 0 || i + b.cells > 8) return 'laat';
  var bezet = {};
  d.blokken.forEach(function (x) {
    if (x === b || x.at === null) return;
    for (var j = 0; j < x.cells; j++) bezet[x.at + j] = true;
  });
  for (k = 0; k < b.cells; k++) if (bezet[i + k]) return 'overlap';
  b.at = i;
  return 'ok';
}

function probeer(id, i, node) {
  var r = plaatsBlok(id, i);
  if (r === 'vast') { shake(node); Snd.zacht(); toast('Dat blokje staat vast — dat mag niet verschuiven. 🔒', 'kind'); return; }
  if (r === 'overlap') { shake(node); Snd.zacht(); toast('Dat past niet tegelijk! 🙃', 'kind'); return; }
  if (r === 'laat') { shake(node); Snd.zacht(); toast('Dan zijn jullie pas ná 16:00 klaar. Probeer wat vroeger.', 'kind'); return; }
  state.middag.gekozen = null;
  state.middag.markeer = [];
  paintMiddag();
}

function wireMiddag() {
  var d = state.middag;
  $$('#dArea .block').forEach(function (node) {
    var id = node.getAttribute('data-blok');
    makeDraggable(node, {
      dropSel: '[data-drop="cell"]',
      ghostHTML: function () { return node.outerHTML; },
      onDrop: function (t) { probeer(id, +t.getAttribute('data-i'), node); },
      onTap: function () { d.gekozen = (d.gekozen === id ? null : id); paintMiddag(); }
    });
  });
  $$('#dArea .placed').forEach(function (node) {
    var id = node.getAttribute('data-blok');
    var blok = blokVan(d, id);
    if (blok && blok.vast) {
      node.onclick = function () { toast('Die afspraak staat vast. Plan de rest eromheen. 🔒', 'kind'); };
      return;
    }
    makeDraggable(node, {
      dropSel: '[data-drop="cell"]',
      ghostHTML: function () { return '<div class="block" style="background:' + node.style.background + '">' + node.innerHTML + '</div>'; },
      onDrop: function (t) { probeer(id, +t.getAttribute('data-i'), node); },
      onTap: function () {
        for (var k = 0; k < d.blokken.length; k++) if (d.blokken[k].id === id) d.blokken[k].at = null;
        d.markeer = [];
        paintMiddag();
      }
    });
  });
  $$('#dArea .cell').forEach(function (c) {
    c.onclick = function () {
      if (!d.gekozen) return;
      probeer(d.gekozen, +c.getAttribute('data-i'), c);
    };
  });
  $('#leegBtn').onclick = function () {
    d.blokken.forEach(function (b) { if (!b.vast) b.at = null; });
    d.gekozen = null; d.markeer = []; d.fout = null; paintMiddag();
  };
  var s = $('#startMiddag');
  if (s) s.onclick = checkMiddag;
}

function speelMiddag() {
  state.plannedOk = true;
  state.middag.klaar = true;
  var seq = state.middag.blokken.filter(function (b) { return b.at !== null; })
    .sort(function (x, y) { return x.at - y.at; });
  var i = 0;
  function toon() {
    clearTimeout(vigTimer);
    if (i >= seq.length) {
      $('#scene').innerHTML = '<div class="card vig"><div class="vigclock">16:00</div>' +
        '<div class="vigprop">🌇</div><h2>De middag is voorbij!</h2>' +
        '<p>Iedereen heeft precies gekregen wat er op het planbord stond.</p>' +
        '<button class="btn go big" id="naarAvond">Naar de avond ▸</button></div>';
      $('#naarAvond').onclick = function () { go('avond'); };
      return;
    }
    var b = seq[i];
    /* het dier doet zijn ding IN de tuin; het kaartje eronder vertelt wat */
    if (b.animal && window.World) World.solo(b.animal, b.act);
    $('#scene').innerHTML = '<div class="card vig">' +
      '<div class="vigclock">' + tijd(b.at * 15) + ' – ' + tijd((b.at + b.cells) * 15) + '</div>' +
      '<div class="vigprop">' + (ACT_EMOJI[b.act] || '✨') + '</div>' +
      '<h2>' + hoofdletter(esc(b.name) + ' ' + (ACT_ZIN[b.act] || 'heeft het gezellig')) + '</h2>' +
      '<p class="hint">' + b.mins + ' minuten</p>' +
      '<button class="btn soft" id="vigNext">Verder ▸</button></div>';
    $('#vigNext').onclick = function () { i++; toon(); };
    vigTimer = setTimeout(function () { i++; toon(); }, 2200);
  }
  toon();
}

/* =====================================================================
   AVOND - DE POORT (twee stappen rekenen, daarna een vrije keuze)
===================================================================== */
Scenes.avond = function (host) {
  if (!state.avond) {
    if (!state.poortDier) kiesPoortDier();
    initAvond();
  }
  host.innerHTML = '<div id="aArea"></div>';
  paintAvond();
};

function scoopjes(n) {
  var s = '';
  for (var i = 0; i < n; i++) s += '<span class="scoop">🥄</span>';
  return s;
}

function paintAvond() {
  var v = state.avond, g = v.dier;
  var vol = state.dieren.length >= MAX_DIEREN;
  var h = '<div class="card"><h1>🌙 De poort</h1>' +
    '<div class="stock">' +
    '<div class="chip">🥣 nog <b>' + v.voorraad + '</b> scheppen brokken</div>' +
    '<div class="chip b">🐾 samen <b>' + v.samen + '</b> scheppen per dag</div>' +
    '<div class="chip c">🚚 nieuw voer over <b>' + v.dagen + '</b> dagen</div></div>' +
    '<div class="gate">' + Art.animal(g, 'blij') +
    '<div class="speech"><b>' + esc(g.name) + '</b> staat bij de poort en kijkt je met grote ogen aan.<br>' +
    '&bdquo;Mag ik hier blijven? Ik eet <b>' + v.extra + '</b> scheppen per dag.&rdquo;</div></div>';

  if (v.stap === 1) {
    h += '<div class="qbox"><h2>Vraag 1 van 2</h2>' +
      '<p>Hoeveel scheppen eet iedereen <b>samen</b> per dag als ' + esc(g.name) + ' erbij komt?</p>' +
      '<div class="somregel"><span class="answer" id="ans">' + (v.invoer || '?') + '</span><span>scheppen</span></div>' +
      '<div class="pad">' +
      [1, 2, 3, 4, 5, 6, 7, 8, 9].map(function (k) { return '<button class="btn" data-k="' + k + '">' + k + '</button>'; }).join('') +
      '<button class="btn del" data-k="del">⌫</button><button class="btn" data-k="0">0</button>' +
      '<button class="btn ok" data-k="ok">✓</button></div>';
    if (v.fouten1 > 0) {
      h += '<div class="soft-note">Tel rustig mee. De dieren die er al zijn eten <b>' + v.samen + '</b>, ' +
        esc(g.name) + ' eet er <b>' + v.extra + '</b> bij:' +
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
      '<div class="row center"><button class="btn big" data-v="minder">Minder ⬇️</button>' +
      '<button class="btn big" data-v="precies">Precies evenveel ⚖️</button>' +
      '<button class="btn big" data-v="meer">Méér ⬆️</button></div>';
    if (v.fouten2 > 0) h += '<div class="soft-note">Tel met sprongen mee: ' + sprongen(v) + '</div>';
    h += '</div>';
  } else if (v.stap === 3) {
    var tot = v.dagen * v.nieuw, uitkomst = vergelijk(v);
    h += '<div class="good">Klopt! ' + v.dagen + ' × ' + v.nieuw + ' = <b>' + tot + '</b> scheppen. ' +
      'Je hebt er <b>' + v.voorraad + '</b>. Dat is dus ' +
      (uitkomst === 'meer' ? '<b>méér</b> dan je in huis hebt.'
        : uitkomst === 'minder' ? '<b>minder</b> dan je in huis hebt.'
        : '<b>precies evenveel</b> — het past precies!') + '</div>' +
      '<div class="qbox"><h2>Nu mag jij kiezen</h2>' +
      '<p class="hint">Allebei is goed. Er gaat niets mis: buurvrouw Els vult het voer aan als het krap wordt.</p>' +
      '<div class="row center">';
    if (vol) {
      h += '<button class="btn go big" data-c="els">🩺 Els neemt hem mee naar haar praktijk</button>';
    } else {
      h += '<button class="btn go big" data-c="ja">🏡 Opnemen: kom binnen!</button>';
    }
    h += '<button class="btn big" data-c="nee">🌙 Kom morgen terug</button></div>';
    if (vol) h += '<p class="hint" style="text-align:center">De opvang zit vol met ' + MAX_DIEREN + ' dieren — Els heeft nog een warm mandje over.</p>';
    h += '</div>';
  } else {
    h += '<div class="qbox"><h2>' + v.keuzeTitel + '</h2><p>' + v.keuzeTekst + '</p>' +
      '<div class="row center"><button class="btn go big" id="slaapBtn">Slaap lekker 💤 ▸</button></div></div>';
  }
  h += '</div>';
  $('#aArea').innerHTML = h;
  wireAvond();
  bewaarSpel();
}

function sprongen(v) {
  var l = [], s = 0;
  for (var i = 0; i < v.dagen; i++) { s += v.nieuw; l.push(s); }
  return l.join(' … ') + '. Dat is ' + s + ', en jij hebt ' + v.voorraad + '.';
}

function wireAvond() {
  var v = state.avond, g = v.dier;
  $$('#aArea [data-k]').forEach(function (b) {
    b.onclick = function () {
      var k = b.getAttribute('data-k');
      if (k === 'del') v.invoer = v.invoer.slice(0, -1);
      else if (k === 'ok') return antwoord1();
      else if (v.invoer.length < 2) v.invoer += k;
      paintAvond();
    };
  });
  $$('#aArea [data-v]').forEach(function (b) {
    b.onclick = function () { antwoord2(b.getAttribute('data-v')); };
  });
  $$('#aArea [data-c]').forEach(function (b) {
    b.onclick = function () { keuze(b.getAttribute('data-c'), g); };
  });
  var s = $('#slaapBtn'); if (s) s.onclick = eindeDag;
}

function antwoord1() {
  var v = state.avond;
  if (!v.invoer) { toast('Tik eerst een getal in. 🙂', 'kind'); return; }
  if (+v.invoer === v.nieuw) {
    v.stap = 2; v.invoer = ''; paintAvond(); Snd.ja();
    toast('Precies! 🎉', 'happy');
  } else {
    v.fouten1++; v.invoer = ''; paintAvond(); Snd.zacht();
    toast('Bijna! Tel de scheppen samen — ze staan eronder. 💛', 'kind');
  }
}

/* drie eerlijke uitkomsten: soms is het namelijk precies genoeg */
function vergelijk(v) {
  var tot = v.dagen * v.nieuw;
  if (tot > v.voorraad) return 'meer';
  if (tot < v.voorraad) return 'minder';
  return 'precies';
}

function antwoord2(keus) {
  var v = state.avond;
  if (keus === vergelijk(v)) { v.stap = 3; paintAvond(); Snd.ja(); toast('Goed gerekend! 🎉', 'happy'); }
  else { v.fouten2++; paintAvond(); Snd.zacht(); toast('Tel eerst met sprongen mee, dan zie je het. 💛', 'kind'); }
}

function keuze(c, g) {
  var v = state.avond;
  v.keuze = c;
  if (c === 'ja') {
    state.dieren.push(g);
    Snd.tover();
    v.weg = true;
    v.keuzeTitel = esc(g.name) + ' mag blijven! 🏡';
    v.keuzeTekst = g.name + ' krijgt vanavond een mandje bij de kachel. Morgenochtend staat er ook een bakje voor ' +
      g.name + ' klaar — dan verdeel je de koekjes over ' + (state.dieren.length) + ' dieren.';
  } else if (c === 'els') {
    v.weg = true;
    v.keuzeTitel = 'Els neemt ' + esc(g.name) + ' mee 🩺';
    v.keuzeTekst = 'Bij Els is het ook warm en er is genoeg eten. Je hebt goed nagedacht over hoeveel voer er is.';
  } else {
    v.keuzeTitel = 'Tot morgen, ' + esc(g.name) + '! 🌙';
    v.keuzeTekst = g.name + ' slaapt vannacht bij buurvrouw Els en komt morgenavond nog eens langs. ' +
      'Je hebt goed uitgerekend hoeveel voer er nodig is — dat is precies wat een goede verzorger doet.';
  }
  v.stap = 4;
  paintAvond();
}

/* =====================================================================
   EINDE DAG - voer, zorgdagen, adoptie
===================================================================== */
function eindeDag() {
  if (state.avond && state.avond.weg) state.poortDier = null;
  if (state.fedOk && state.plannedOk) {
    var roster = state.ochtendRoster || [];
    state.dieren.forEach(function (a) { if (roster.indexOf(a.id) >= 0) a.care++; });
  }

  var gebruik = dagVerbruik();
  state.scoops = Math.max(0, state.scoops - gebruik);
  state.levering--;
  state.leverBericht = false;
  /* de vraag 's avonds blijft zo altijd minstens 2 dagen vooruit kijken */
  if (state.levering <= 1) {
    /* de bezorging vult aan tot een overzichtelijk getal in plaats van eindeloos op te stapelen */
    state.scoops = 20 + Math.min(state.scoops, 4);
    state.levering = 4;
    state.leverBericht = true;
  }
  if (state.scoops < gebruik) {
    state.vetBij = { over: state.scoops, gebruik: gebruik, bij: 10 };
  } else state.vetBij = null;

  var kand = klaarVoorAdoptie();
  if (kand) { state.adoptie = { dier: kand, stap: 1 }; go('adoptie'); }
  else nieuweDag();
}

Scenes.adoptie = function (host) {
  var ad = state.adoptie, a = ad.dier;
  var h = '<div class="scene-warm">';
  if (ad.stap === 1) {
    h += '<h1>💐 Adoptiedag!</h1>' +
      '<p>' + esc(a.name) + ' is ' + a.care + ' dagen lang eerlijk gevoerd en fijn ingepland. ' +
      'Er staat een familie voor de deur die ' + esc(a.name) + ' heel graag wil.</p>' +
      '<div class="row center"><span class="family">👨‍👩‍👧</span>' +
      Art.animal(a, 'bouncy') + '<span class="family">🏡</span></div>' +
      '<div class="row center"><button class="btn go big" id="zwaai">Zwaai ' + esc(a.name) + ' gedag 👋</button></div>';
  } else {
    var br = ad.brief;
    h += '<h1>💌 Er is post!</h1>' +
      '<div class="letter pop"><h3>' + esc(br.titel) + '</h3>' + esc(br.tekst) + '</div>' +
      '<div class="row center"><button class="btn go big" id="pin">Hang de brief op de muur 📌</button></div>';
  }
  h += '</div>';
  host.innerHTML = h;
  if ($('#zwaai')) $('#zwaai').onclick = function () {
    state.adoptie.brief = nieuweBrief(a);
    state.adoptie.stap = 2;
    Snd.brief();
    render();
  };
  if ($('#pin')) $('#pin').onclick = function () {
    voltooiAdoptie(a);
    toast('De brief hangt aan de brievenmuur. 💛', 'happy');
    nieuweDag();
  };
};

/* apart gezet zodat de dagovergang ook zonder scherm te testen is */
function voltooiAdoptie(a) {
  state.brieven.push(state.adoptie.brief);
  state.dieren = state.dieren.filter(function (x) { return x.id !== a.id; });
  /* alleen een nieuw dier brengen als er ruimte is, zodat je 's avonds echt kunt kiezen */
  var ruimte = state.dieren.length < 4;
  state.binnenkomst = ruimte ? pakDier() : null;
  state.volleOpvang = !ruimte;
  state.adoptie = null;
}

function nieuweDag() {
  state.day++;
  state.fedOk = false; state.plannedOk = false;
  state.morning = null; state.middag = null; state.avond = null;

  var b = [];
  if (state.binnenkomst) {
    state.dieren.push(state.binnenkomst);
    b.push('🚚 Er is een nieuw dier gebracht: <b>' + esc(state.binnenkomst.name) + '</b>, ' +
      esc(metLidwoord(state.binnenkomst)) + '. Welkom in de Kwispelsteeg!');
    state.binnenkomst = null;
  }
  if (state.volleOpvang) {
    b.push('🏡 Er is vandaag geen nieuw dier gebracht: met <b>' + state.dieren.length +
      ' dieren</b> zit de Kwispelsteeg lekker vol. Els belt zodra er weer een plekje vrij is.');
    state.volleOpvang = false;
  }
  if (state.leverBericht) {
    b.push('📦 Het nieuwe voer is bezorgd! Je hebt weer <b>' + state.scoops + ' scheppen</b> brokken.');
    state.leverBericht = false;
  }
  if (state.vetBij) {
    var vb = state.vetBij;
    state.scoops += vb.bij;
    b.push('🩺 Buurvrouw Els kwam langs met brokken. &bdquo;Je had nog <b>' + vb.over + '</b> scheppen en jullie eten samen <b>' +
      vb.gebruik + '</b> per dag — dat is te weinig voor vandaag. Ik doe er <b>' + vb.bij + '</b> bij: ' +
      vb.over + ' + ' + vb.bij + ' = <b>' + (vb.over + vb.bij) + '</b> scheppen.&rdquo;');
    state.vetBij = null;
  }
  if (!state.poortDier) kiesPoortDier();
  state.dagBericht = b.length ? '<h2>Goedemorgen! ☀️</h2>' + b.map(function (x) { return '<p>' + x + '</p>'; }).join('') : null;

  if (state.day === 5 && !state.vrijSpel) { go('klaar'); return; }
  go('morning');
}

Scenes.klaar = function (host) {
  host.innerHTML = '<div class="scene-warm"><h1>🎉 Wat een week!</h1>' +
    '<p>Je hebt <b>4 dagen</b> voor de Kwispelsteeg gezorgd.</p>' +
    '<div class="row center"><div class="chip">💌 ' + state.brieven.length + ' brieven</div>' +
    '<div class="chip b">🐾 ' + state.dieren.length + ' dieren bij jou</div>' +
    '<div class="chip c">🍬 ' + state.snoeppot + ' koekjes in de snoeppot</div></div>' +
    '<p>Je mag zo lang doorspelen als je wil. Er komen steeds nieuwe dieren en nieuwe sommen.</p>' +
    '<div class="row center"><button class="btn go big" id="verder">Speel verder ▸</button>' +
    '<button class="btn soft" id="muurBtn">Bekijk de brievenmuur 💌</button></div></div>';
  $('#verder').onclick = function () { state.vrijSpel = true; go('morning'); };
  $('#muurBtn').onclick = brievenMuur;
};

/* =====================================================================
   BRIEVENMUUR
===================================================================== */
function brievenMuur() {
  var h = '<h2>💌 De brievenmuur</h2>';
  if (!state.brieven.length) {
    h += '<p>Hier komen straks de brieven van de families die een dier van jou hebben opgehaald.</p>' +
      '<p class="hint">Zorg twee dagen goed voor een dier: eerlijk voeren én de middag inplannen. Dan mag het op adoptiedag mee naar huis.</p>';
  } else {
    h += '<div class="wall">' + state.brieven.map(function (br) {
      return '<div class="letter"><h3>' + esc(br.titel) + '</h3>' + esc(br.tekst) + '</div>';
    }).join('') + '</div>';
  }
  h += '<div class="row center" style="margin-top:12px"><button class="btn go" id="dicht">Sluiten</button></div>';
  openSheet(h);
  Snd.brief();
  $('#dicht').onclick = closeSheet;
}

/* ===================================================================== */

/* elk begin: vraag of het oude spel verder mag of dat het opnieuw begint */
function beginScherm() {
  var s = leesSpel();
  newGame();
  render();
  if (!s) { startKeuze = true; bewaarSpel(); return; }
  var dagen = meervoud(s.day || 1, 'dag', 'dagen');
  var dieren = meervoud(s.dieren.length, 'dier', 'dieren');
  var snoep = meervoud(s.snoeppot || 0, 'snoepje', 'snoepjes');
  openSheet('<h2>Wel terug in de Kwispelsteeg! 👋</h2>' +
    '<p class="hint" style="text-align:center;margin:0 0 14px">Je was bij <b>' + dagen + '</b> — met ' +
    dieren + ' en ' + snoep + ' in de snoeppot.</p>' +
    '<div class="row center" style="gap:10px">' +
    '<button class="btn go big" id="verderBtn">Verder spelen ▸</button>' +
    '<button class="btn big" id="nieuwBtn">Nieuw spel</button></div>');
  $('#verderBtn').onclick = function () {
    closeSheet();
    state = s;
    startKeuze = true;
    go(state.phase || 'morning');
  };
  $('#nieuwBtn').onclick = function () {
    closeSheet();
    wisSpel();
    newGame();
    startKeuze = true;
    render();
    bewaarSpel();
  };
}

newGame();
$('#lettersBtn').addEventListener('click', brievenMuur);
$('#sndBtn').textContent = Snd.dempt() ? '🔇' : '🔊';
$('#sndBtn').addEventListener('click', function () {
  Snd.schakel();
  $('#sndBtn').textContent = Snd.dempt() ? '🔇' : '🔊';
});
/* elke knop krijgt een zacht tikgeluid — via delegatie, zo hoeft geen knop apart */
document.addEventListener('click', function (e) {
  if (e.target.closest && e.target.closest('.btn')) Snd.tik();
});
beginScherm();
