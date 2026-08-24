/* Zilverhoef — spelverloop: start → rondje(s) → diagnose → winkel → stal → rondje ...

   Economie (groep 3/4: hele euro's, alles t/m 20):
   - de pony pakt onderweg zélf munten en appels op — 6 per rondje, 8 met zadeltassen
   - de buidel houdt maximaal 20 munten vast (LAP_CAP/PURSE_CAP): sparen loopt vast,
     dus rekenen in de winkel is de enige manier om verder te komen
   - hoogstens 3 rondjes tussen twee winkelbezoeken, zodat rondjes draven nooit
     het rekenen vervangt */
(function () {
  'use strict';

  var LAP_CAP = 3, PURSE_CAP = 20;
  var state = {
    name: 'Sterre', coat: 'vos', coins: 0, owned: {},
    runs: 0, lapsSinceShop: 0, autoLap: false
  };
  var $ = function (id) { return document.getElementById(id); };
  var previewRaf = 0, pt = 0, lastTs = 0;

  function lapsLeft() { return Math.max(0, LAP_CAP - state.lapsSinceShop); }
  function room() { return Math.max(0, PURSE_CAP - state.coins); }
  /* Alles gekocht? Dan is er niets meer om voor te sparen: ererondjes mogen
     eindeloos, maar leveren ook niets meer op. */
  function allOwned() { return Shop.WARES.every(function (w) { return !!state.owned[w.id]; }); }
  function canLap() { return allOwned() || (lapsLeft() > 0 && room() > 0); }
  function lapWhy() {
    if (allOwned()) return 'Alles gekocht! Draaf zoveel ererondjes als je wilt. 🏆';
    if (room() <= 0) return 'Je buidel zit vol met twintig munten — ga lekker iets kopen!';
    if (lapsLeft() <= 0) return state.name + ' heeft drie rondjes gedraafd en wil even uitblazen. Naar de winkel!';
    return '';
  }

  /* ---------- schermen ---------- */
  function show(id) {
    ['scr-start', 'scr-run', 'scr-diag', 'scr-shop', 'scr-stable'].forEach(function (s) {
      $(s).classList.toggle('active', s === id);
    });
    cancelAnimationFrame(previewRaf); previewRaf = 0; lastTs = 0;
    if (id === 'scr-start') loopPreview($('cv-start'), {});
    if (id === 'scr-stable') loopPreview($('cv-stable'), state.owned);
    gateLapButtons();
    window.scrollTo(0, 0);
  }

  function gateLapButtons() {
    var ok = canLap(), why = lapWhy(), ere = allOwned();
    [[$('btn-diag-lap'), 'Nog een rondje 🔁'], [$('btn-stable-run'), 'Nog een rondje 🏇']]
      .forEach(function (pair) {
        var b = pair[0];
        b.disabled = !ok;
        b.classList.toggle('off', !ok);
        b.textContent = !ok ? 'Buidel of pony is klaar 🛒'
          : (ere ? 'Ererondje draven 🏆' : pair[1] + ' (' + lapsLeft() + ' te gaan)');
        b.title = ok ? '' : why;
      });
    var sr = $('btn-shop-run');
    sr.disabled = !ok;
    sr.classList.toggle('off', !ok);
    sr.textContent = !ok ? 'Buidel vol — kies iets uit! 🪙'
      : (ere ? 'Ererondje draven 🏆' : 'Eerst nog een rondje 🏇');
  }

  /* ---------- pony-voorbeeld op start- en stalscherm ---------- */
  function loopPreview(cv, gear) {
    if (cv.width !== 880) { cv.width = 880; cv.height = 520; }
    var ctx = cv.getContext('2d');
    function step(ts) {
      if (!lastTs) lastTs = ts;
      pt += Math.min(0.05, (ts - lastTs) / 1000); lastTs = ts;
      ctx.setTransform(2, 0, 0, 2, 0, 0);
      ctx.clearRect(0, 0, 440, 260);
      var sky = ctx.createLinearGradient(0, 0, 0, 260);
      sky.addColorStop(0, '#dff0fb'); sky.addColorStop(1, '#f2faee');
      ctx.fillStyle = sky; ctx.fillRect(0, 0, 440, 260);
      ctx.fillStyle = '#ffffffcc';
      Art.bush(ctx, 90 + Math.sin(pt * 0.3) * 8, 52, 120, 44, '#ffffffcc');
      Art.bush(ctx, 340 - Math.sin(pt * 0.24) * 8, 38, 92, 34, '#ffffffdd');
      ctx.fillStyle = '#fff4c4';
      ctx.beginPath(); ctx.arc(390, 44, 24, 0, 7); ctx.fill();
      Art.bush(ctx, 30, 214, 120, 46, '#bfe0c6');
      Art.bush(ctx, 410, 212, 130, 50, '#bfe0c6');
      var g = ctx.createLinearGradient(0, 226, 0, 260);
      g.addColorStop(0, '#a9dcb2'); g.addColorStop(1, '#84c793');
      ctx.fillStyle = g; ctx.fillRect(0, 228, 440, 32);
      ctx.fillStyle = '#eed9b4';
      ctx.beginPath(); ctx.ellipse(220, 244, 190, 13, 0, 0, 7); ctx.fill();
      for (var i = 0; i < 9; i++) {
        var fx = 22 + i * 51, fy = 252 - (i % 2) * 5, sw = Math.sin(pt * 1.4 + i) * 2;
        ctx.fillStyle = i % 3 ? '#7abb88' : '#68ab78';
        ctx.beginPath();
        ctx.moveTo(fx - 7, fy); ctx.quadraticCurveTo(fx - 1 + sw, fy - 15, fx + 7, fy);
        ctx.closePath(); ctx.fill();
      }
      Art.drawHorse(ctx, {
        x: 212, y: 240 + Math.sin(pt * 1.6) * 1.5, scale: 1.42,
        coat: state.coat, gear: gear, phase: pt * 2.1, t: pt
      });
      previewRaf = requestAnimationFrame(step);
    }
    previewRaf = requestAnimationFrame(step);
  }

  /* ---------- startscherm ---------- */
  function buildSwatches() {
    var box = $('swatches');
    box.innerHTML = '';
    ['vos', 'zwartje', 'schimmel'].forEach(function (k) {
      var c = Art.COATS[k];
      var b = document.createElement('button');
      b.className = 'swatch' + (state.coat === k ? ' sel' : '');
      b.innerHTML = '<i style="background:' + c.body + '"></i><span>' + c.naam + '</span>';
      b.addEventListener('click', function () {
        state.coat = k;
        [].forEach.call(box.children, function (n) { n.classList.remove('sel'); });
        b.classList.add('sel');
      });
      box.appendChild(b);
    });
  }

  $('btn-go').addEventListener('click', function () {
    var n = ($('inp-name').value || '').trim();
    state.name = n ? n.slice(0, 12) : 'Sterre';
    startRun();
  });

  /* ---------- het rondje ---------- */
  function startRun() {
    if (!canLap()) { gateLapButtons(); return; }
    show('scr-run');
    var stopBtn = $('btn-stop-laps');
    stopBtn.disabled = false;
    stopBtn.textContent = 'Laatste rondje ✋';
    stopBtn.classList.toggle('on', state.autoLap);
    requestAnimationFrame(function () {
      Run.start({
        name: state.name, coat: state.coat, gear: state.owned,
        lap: state.lapsSinceShop + 1, lapMax: LAP_CAP, room: room(),
        ere: allOwned(), onFinish: finishRun
      });
    });
  }

  function finishRun(res) {
    state.runs++;
    state.lapsSinceShop++;
    state.coins = Math.min(PURSE_CAP, state.coins + res.coins);
    $('btn-stop-laps').classList.remove('on');
    var won = res.place === 1;
    if (state.autoLap && !won && canLap()) { startRun(); return; }
    state.autoLap = false;
    showDiag(res, won);
  }

  function showDiag(res, won) {
    $('diag-rosette').textContent = won ? '🏆' : '🥈';
    $('diag-title').textContent = won ? 'Eerste plaats!' : 'Tweede plaats!';

    if (won) {
      $('diag-line').textContent = 'Je hebt de Zilverhoef gewonnen!';
      $('diag-tip').textContent = state.name + ' vloog over alles heen. Wat een span!';
      Shop.confetti(70);
    } else if (res.weakness === 'water') {
      $('diag-line').textContent = state.name + ' gleed uit bij de waterbak!';
      $('diag-tip').textContent = 'Met noppen onder de schoenen glijdt ze niet meer weg.';
    } else {
      $('diag-line').textContent = state.name + ' zwoegde op de heuvel!';
      $('diag-tip').textContent = 'Een lichter zadel scheelt een hoop klimwerk.';
    }

    /* elk opgepakt ding was één munt: precies natellen kan dus */
    var row = $('diag-coins'); row.innerHTML = '';
    for (var i = 0; i < res.coins; i++) {
      var d = document.createElement('div');
      d.className = 'mini-coin'; d.textContent = '€1';
      row.appendChild(d);
    }
    var stuk = [];
    if (res.munt) stuk.push(res.munt + ' ' + (res.munt === 1 ? 'munt' : 'munten'));
    if (res.apples) stuk.push(res.apples + ' ' + (res.apples === 1 ? 'appel' : 'appels'));
    $('diag-earn').textContent = res.ere
      ? 'Ererondje gedraafd! Je hebt alles al: ' + state.coins + ' munten in de buidel. 🏆'
      : 'Rondje ' + state.lapsSinceShop + ': ' +
        (stuk.length ? stuk.join(' + ') + ' = ' + res.coins + ' munten' : 'niets erbij') +
        '. Samen heb je er nu ' + state.coins + '! 🪙';
    $('diag-note').textContent = lapWhy();
    show('scr-diag');
  }

  /* ---------- stal ---------- */
  var GEAR_NAMEN = {
    noppen: '🥾 bokkenschoenen met noppen',
    zadel: '🪶 lichter zadel',
    hoofdstel: '🎀 gevlochten hoofdstel',
    zadeltassen: '🎒 zadeltassen',
    hoefijzers: '💨 nieuwe hoefijzers'
  };
  function toStable() {
    $('stable-title').textContent = 'De stal van ' + state.name;
    var g = [];
    Object.keys(GEAR_NAMEN).forEach(function (k) { if (state.owned[k]) g.push(GEAR_NAMEN[k]); });
    $('stable-gear').textContent = g.length ? 'Aan: ' + g.join(' · ') : 'Nog geen spullen — de winkel wacht!';
    $('stable-coins').textContent = state.coins;
    show('scr-stable');
  }

  /* ---------- winkel: hier begint het rondjes-tellertje weer op nul ---------- */
  function toShop() {
    state.lapsSinceShop = 0;
    state.autoLap = false;
    show('scr-shop');
    Shop.open(state, { onBuy: gateLapButtons });
  }

  $('btn-diag-shop').addEventListener('click', toShop);
  $('btn-diag-stable').addEventListener('click', toStable);
  $('btn-diag-lap').addEventListener('click', function () {
    state.autoLap = true;          /* de pony blijft rondjes draven tot de rem erop gaat */
    startRun();
  });
  $('btn-stable-run').addEventListener('click', function () {
    state.autoLap = false;
    startRun();
  });
  $('btn-stable-shop').addEventListener('click', toShop);
  $('btn-shop-stable').addEventListener('click', toStable);
  $('btn-shop-run').addEventListener('click', function () {
    $('btn-shop-run').classList.remove('pulse');
    state.autoLap = false;
    startRun();
  });
  $('btn-stop-laps').addEventListener('click', function () {
    state.autoLap = false;
    var b = $('btn-stop-laps');
    b.textContent = 'Laatste rondje ✔';
    b.disabled = true;
  });

  buildSwatches();
  show('scr-start');
})();
