/* Zilverhoef — de zadelwinkel: betalen met munten en wisselgeld terugtellen.
   Hele euro's, bedragen t/m 20 (groep 3/4). Nooit een rood kruis, nooit een klok. */
(function (global) {
  'use strict';

  var WOORD = ['nul', 'een', 'twee', 'drie', 'vier', 'vijf', 'zes', 'zeven', 'acht', 'negen', 'tien',
    'elf', 'twaalf', 'dertien', 'veertien', 'vijftien', 'zestien', 'zeventien', 'achttien',
    'negentien', 'twintig'];
  function woord(n) { return (n >= 0 && n <= 20) ? WOORD[n] : String(n); }

  var WARES = [
    { id: 'noppen', naam: 'Bokkenschoenen met noppen', prijs: 9, icon: '🥾', fx: 'Nooit meer uitglijden bij de waterbak' },
    { id: 'zadel', naam: 'Lichter zadel', prijs: 7, icon: '🪶', fx: 'Vliegen over de heuvel' },
    { id: 'hoofdstel', naam: 'Gevlochten hoofdstel', prijs: 5, icon: '🎀', fx: 'Vlechtjes in de manen — puur voor de sier' },
    { id: 'zadeltassen', naam: 'Zadeltassen', prijs: 12, icon: '🎒', fx: 'Twee munten extra per rondje' },
    { id: 'hoefijzers', naam: 'Nieuwe hoefijzers', prijs: 6, icon: '💨', fx: 'Een sneller rondje — minder wachten' }
  ];

  /* Buidel: bouw op van klein naar groot zodat ELK bedrag t/m het totaal precies
     te leggen is (elke munt is hooguit 1 meer dan alles wat er al ligt).
     Het biljet van 10 komt er pas in als de losse munten samen al 9 halen. */
  var DENOMS = [10, 5, 2, 1];
  function makePurse(total) {
    var rest = total, som = 0, out = [], guard = 0;
    while (rest > 0 && guard++ < 60) {
      var d = 1, i;
      for (i = 0; i < DENOMS.length; i++) {
        if (DENOMS[i] <= rest && DENOMS[i] <= som + 1) { d = DENOMS[i]; break; }
      }
      out.push(d); som += d; rest -= d;
    }
    out.sort(function (a, b) { return b - a; });
    return out.map(function (v, k) { return { v: v, id: 'c' + k + '_' + v }; });
  }

  function splits(n) { var out = [], r = n;
    while (r >= 10) { out.push(10); r -= 10; }
    while (r >= 5) { out.push(5); r -= 5; }
    while (r >= 2) { out.push(2); r -= 2; }
    while (r >= 1) { out.push(1); r -= 1; }
    return out;
  }

  var S = null, el = {}, purse = [], counter = [], cur = null;
  var tries = 0, padVal = '', changeTries = 0, mode = 'pay';

  function $(id) { return document.getElementById(id); }
  function say(txt) { el.bubble.textContent = txt; el.bubble.classList.remove('pulse'); void el.bubble.offsetWidth; }
  function sum(arr) { return arr.reduce(function (a, c) { return a + c.v; }, 0); }

  function coinEl(c, extra) {
    var d = document.createElement('div');
    d.className = 'coin ' + (c.v === 10 ? 'note' : 'c' + c.v) + (extra ? ' ' + extra : '');
    d.textContent = '€' + c.v;
    return d;
  }

  function open(state, cb) {
    S = state; S.cb = cb;
    el = {
      bubble: $('bubble'), wares: $('shop-wares'), pay: $('shop-pay'), payWhat: $('pay-what'),
      payPrice: $('pay-price'), counter: $('counter'), counterCoins: $('counter-coins'),
      ghosts: $('ghosts'), total: $('counter-total'), purse: $('purse'), pad: $('pad'),
      padDisp: $('pad-display'), padKeys: $('pad-keys'), run: $('btn-shop-run')
    };
    purse = makePurse(S.coins); counter = []; cur = null;
    el.pay.classList.add('hidden');
    renderWares(); renderPurse(); renderCounter();
    buildPad();
    say('Hoi ' + S.name + '! Kijk maar rustig rond. Je hebt ' + woord(S.coins) + ' munten.');
    bindOnce();
  }

  var bound = false;
  function bindOnce() {
    if (bound) return; bound = true;
    $('btn-pay-close').addEventListener('click', closePay);
    $('btn-pay-clear').addEventListener('click', function () {
      while (counter.length) purse.push(counter.pop());
      purse.sort(function (a, b) { return b.v - a.v; });
      el.ghosts.innerHTML = ''; el.pad.classList.add('hidden'); mode = 'pay';
      renderPurse(); renderCounter();
      say('Geeft niks, we beginnen opnieuw. Leg maar neer.');
    });
    $('btn-pay-ok').addEventListener('click', klaar);
  }

  function renderWares() {
    el.wares.innerHTML = '';
    WARES.forEach(function (w) {
      var owned = !!S.owned[w.id];
      var card = document.createElement('div');
      card.className = 'ware' + (owned ? ' owned' : '');
      card.innerHTML = '<div class="icon">' + w.icon + '</div><div class="nm">' + w.naam +
        '</div><div class="fx">' + w.fx + '</div>' +
        (owned ? '<div class="price-tag">gekocht ✔</div>' : '<div class="price-tag">€' + w.prijs + '</div>');
      var b = document.createElement('button');
      b.className = 'buy';
      b.textContent = owned ? 'Die heb je al!' : 'Deze wil ik!';
      b.addEventListener('click', function () { pick(w); });
      card.appendChild(b);
      el.wares.appendChild(card);
    });
  }

  function pick(w) {
    if (S.owned[w.id]) { say('Die heb je al! Hij staat ' + S.name + ' prachtig.'); return; }
    cur = w; tries = 0; changeTries = 0; mode = 'pay'; padVal = '';
    while (counter.length) purse.push(counter.pop());
    purse.sort(function (a, b) { return b.v - a.v; });
    el.ghosts.innerHTML = ''; el.pad.classList.add('hidden');
    el.pay.classList.remove('hidden');
    el.payWhat.textContent = w.naam;
    el.payPrice.textContent = '€' + w.prijs;
    renderPurse(); renderCounter();
    if (S.coins < w.prijs) {
      say('Die kost ' + woord(w.prijs) + ' munten en je hebt er ' + woord(S.coins) +
        '. Doe eerst nog een rondje, dan lukt het vast!');
      el.run.classList.add('pulse');
    } else {
      el.run.classList.remove('pulse');
      say('Goede keus! Die kost ' + woord(w.prijs) + ' euro. Leg de munten maar op de toonbank.');
    }
    el.pay.scrollIntoView({ block: 'nearest' });
  }

  function closePay() {
    while (counter.length) purse.push(counter.pop());
    purse.sort(function (a, b) { return b.v - a.v; });
    cur = null; el.pay.classList.add('hidden');
    renderPurse(); renderCounter();
    say('Prima, kijk gerust verder.');
  }

  /* ---------- munten verplaatsen (pointer: muis én tablet) ---------- */
  function moveCoin(id, toCounter) {
    var from = toCounter ? purse : counter, to = toCounter ? counter : purse;
    for (var i = 0; i < from.length; i++) {
      if (from[i].id === id) { to.push(from.splice(i, 1)[0]); break; }
    }
    purse.sort(function (a, b) { return b.v - a.v; });
    renderPurse(); renderCounter();
    if (toCounter) say('Zo ja... dat is samen ' + woord(sum(counter)) + '.');
  }

  function overCounter(ev) {
    var r = el.counter.getBoundingClientRect();
    return ev.clientX >= r.left && ev.clientX <= r.right && ev.clientY >= r.top && ev.clientY <= r.bottom;
  }

  function attachDrag(node, coin, fromCounter) {
    node.addEventListener('pointerdown', function (e) {
      if (mode === 'change') return;
      e.preventDefault();
      var sx = e.clientX, sy = e.clientY, moved = false, ghost = null;
      try { node.setPointerCapture(e.pointerId); } catch (x) { }
      function mv(ev) {
        var dx = ev.clientX - sx, dy = ev.clientY - sy;
        if (!moved && Math.sqrt(dx * dx + dy * dy) > 9) {
          moved = true;
          ghost = coinEl(coin, 'drag');
          $('drag-layer').appendChild(ghost);
          node.style.opacity = '.35';
        }
        if (ghost) {
          ghost.style.left = ev.clientX + 'px'; ghost.style.top = ev.clientY + 'px';
          el.counter.classList.toggle('hot', !fromCounter && overCounter(ev));
        }
      }
      function up(ev) {
        node.removeEventListener('pointermove', mv);
        node.removeEventListener('pointerup', up);
        node.removeEventListener('pointercancel', up);
        if (ghost && ghost.parentNode) ghost.parentNode.removeChild(ghost);
        node.style.opacity = '';
        el.counter.classList.remove('hot');
        var drop = fromCounter ? !overCounter(ev) : overCounter(ev);
        if (!moved || drop) moveCoin(coin.id, !fromCounter);
      }
      node.addEventListener('pointermove', mv);
      node.addEventListener('pointerup', up);
      node.addEventListener('pointercancel', up);
    });
  }

  function renderPurse() {
    el.purse.innerHTML = '';
    if (!purse.length) {
      var p = document.createElement('div');
      p.className = 'purse-empty';
      p.textContent = 'Je buidel is leeg — verdien munten met een rondje!';
      el.purse.appendChild(p);
      return;
    }
    purse.forEach(function (c) {
      var n = coinEl(c);
      attachDrag(n, c, false);
      el.purse.appendChild(n);
    });
  }

  function renderCounter() {
    el.counterCoins.innerHTML = '';
    counter.forEach(function (c) {
      var n = coinEl(c, 'pulse');
      attachDrag(n, c, true);
      el.counterCoins.appendChild(n);
    });
    el.total.textContent = '€' + sum(counter);
  }

  function showGhosts(rest) {
    el.ghosts.innerHTML = '';
    var lbl = document.createElement('div');
    lbl.className = 'hint-lbl';
    lbl.textContent = 'nog nodig: €' + rest;
    el.ghosts.appendChild(lbl);
    splits(rest).forEach(function (v) {
      el.ghosts.appendChild(coinEl({ v: v, id: 'g' }, 'ghost'));
    });
  }

  /* ---------- afrekenen ---------- */
  function klaar() {
    if (!cur) { say('Kies eerst iets moois uit.'); return; }
    if (mode === 'change') { padOk(); return; }
    var t = sum(counter), p = cur.prijs;
    if (t === p) { gelukt(0); return; }
    if (t < p) {
      tries++;
      var rest = p - t;
      say('Dat is ' + woord(t) + '... nog ' + woord(rest) + ' erbij?');
      if (tries >= 3) {
        showGhosts(rest);
        say('Kijk, zó ziet ' + woord(rest) + ' eruit. Leg die er maar bij.');
      }
      if (sum(purse) < rest) {
        say('Je munten zijn op. Doe eerst nog een rondje, dan heb je er genoeg!');
        el.run.classList.add('pulse');
      }
      return;
    }
    mode = 'change'; changeTries = 0; padVal = '';
    el.ghosts.innerHTML = '';
    el.pad.classList.remove('hidden');
    el.padDisp.textContent = '–';
    el.pad.querySelector('.numline') && el.pad.querySelector('.numline').remove();
    say('Ik geef je wisselgeld — hoeveel krijg je terug?');
    el.pad.scrollIntoView({ block: 'nearest' });
  }

  function buildPad() {
    el.padKeys.innerHTML = '';
    var keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'wis', '0', 'ok'];
    keys.forEach(function (k) {
      var b = document.createElement('button');
      b.textContent = k === 'ok' ? 'OK ✔' : (k === 'wis' ? 'wis' : k);
      if (k === 'ok') b.className = 'ok';
      b.addEventListener('click', function () {
        if (k === 'wis') { padVal = ''; }
        else if (k === 'ok') { padOk(); return; }
        else if (padVal.length < 2) { padVal += k; }
        el.padDisp.textContent = padVal === '' ? '–' : '€' + padVal;
      });
      el.padKeys.appendChild(b);
    });
  }

  function numline(from, to) {
    var old = el.pad.querySelector('.numline');
    if (old) old.remove();
    var d = document.createElement('div');
    d.className = 'numline';
    for (var n = from; n <= to; n++) {
      var i = document.createElement('i');
      i.textContent = n;
      if (n > from) i.className = 'hit';
      d.appendChild(i);
    }
    el.pad.appendChild(d);
  }

  function padOk() {
    if (mode !== 'change' || !cur) return;
    var betaald = sum(counter), goed = betaald - cur.prijs;
    if (padVal === '') { say('Tik eerst een getal, dan kijken we samen.'); return; }
    if (parseInt(padVal, 10) === goed) { gelukt(goed); return; }
    changeTries++;
    padVal = ''; el.padDisp.textContent = '–';
    if (changeTries === 1) {
      say('Bijna! Kijk: van ' + woord(cur.prijs) + ' naar ' + woord(betaald) + '. Tel maar door.');
    } else if (changeTries === 2) {
      numline(cur.prijs, betaald);
      say('Tel de roze stapjes maar: van ' + woord(cur.prijs) + ' naar ' + woord(betaald) + '.');
    } else {
      numline(cur.prijs, betaald);
      showGhosts(goed);
      say('Zie je? Dat zijn ' + woord(goed) + ' stapjes. Zoveel krijg je terug!');
    }
  }

  function gelukt(change) {
    var w = cur;
    S.coins -= w.prijs;
    S.owned[w.id] = true;
    mode = 'pay'; cur = null;
    counter = []; purse = makePurse(S.coins);
    el.pay.classList.add('hidden');
    el.pad.classList.add('hidden');
    el.ghosts.innerHTML = '';
    var nl = el.pad.querySelector('.numline'); if (nl) nl.remove();
    renderWares(); renderPurse(); renderCounter();
    confetti(28);
    if (change > 0) say('Precies! ' + cap(woord(change)) + ' euro terug, alsjeblieft. Veel plezier ermee!');
    else say('Helemaal precies! Dankjewel. Dit staat ' + S.name + ' prachtig.');
    if (S.cb && S.cb.onBuy) S.cb.onBuy(w.id);
  }

  function cap(s) { return s.charAt(0).toUpperCase() + s.slice(1); }

  function confetti(n) {
    var lay = $('confetti');
    var cols = ['#e58fa8', '#f2c14e', '#8fcfa4', '#cfe6f7', '#e6dcf7'];
    for (var i = 0; i < n; i++) {
      var d = document.createElement('div');
      d.className = 'conf';
      d.style.left = Math.random() * 100 + 'vw';
      d.style.top = '-30px';
      d.style.background = cols[(Math.random() * cols.length) | 0];
      d.style.animationDuration = (1.6 + Math.random() * 1.6) + 's';
      d.style.animationDelay = (Math.random() * 0.5) + 's';
      lay.appendChild(d);
      (function (node) { setTimeout(function () { if (node.parentNode) node.parentNode.removeChild(node); }, 3600); })(d);
    }
  }

  global.Shop = { open: open, WARES: WARES, makePurse: makePurse, woord: woord, splits: splits, confetti: confetti };
})(window);
