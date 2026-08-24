/* Zilverhoef — de rit.
   De pony draaft zelf én pakt onderweg zelf alle munten en appels op: het kind
   hoeft niets te tikken om te verdienen. Tikken geeft alleen linten (versiering).
   Geen timer, geen faalmoment, geen straf. */
(function (global) {
  'use strict';

  var TRACK = 4400, BASE = 178, RIVAL_V = 162;
  var HILL_X = 3200, HILL_W = 560, HILL_H = 86;

  /* Wat er per rondje op het pad ligt (alles is 1 munt waard, hele euro's). */
  var MUNT = [560, 1450, 2750, 3500];        /* vier munten           */
  var APPEL = [900, 4020];                   /* twee appels           */
  var MUNT_TAS = [2000, 4180];               /* met zadeltassen: +2   */

  var cv, ctx, ov, hint, dotMe, dotRival, hudCoins, hudLap, W = 0, H = 0, dpr = 1;
  var raf = 0, prev = 0, st = null, bound = false;
  var lay = null, layKey = '', vgr = null;

  function terrain(wx) {
    if (wx < HILL_X || wx > HILL_X + HILL_W) return 0;
    return HILL_H * Math.sin(Math.PI * (wx - HILL_X) / HILL_W);
  }

  /* schaal volgt de kleinste kant, zodat de pony op telefoon (staand én liggend) groot blijft */
  function scale() { return Math.max(0.62, Math.min(1.45, Math.min(W / 460, H / 430))); }
  function groundY() { return H * 0.78; }
  function camX() { return st ? st.horse.wx - W * 0.30 : 0; }

  function resize() {
    if (!cv) return;
    var r = cv.getBoundingClientRect();
    W = Math.max(320, r.width); H = Math.max(240, r.height);
    /* Scherpte volgen, maar met een dak op het aantal beeldpunten: op een groot
       retina-scherm blijft de rit zo ook op een trage tablet vloeiend. */
    dpr = Math.min(global.devicePixelRatio || 1, 2);
    var BUDGET = 2400000;
    if (W * H * dpr * dpr > BUDGET) dpr = Math.max(1, Math.sqrt(BUDGET / (W * H)));
    cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    vgr = null;
    buildLayers();
  }

  /* ---------- vaste achtergrondlagen, één keer getekend en daarna geschoven ----------
     Elke laag is precies zo hoog als hij nodig heeft. Dat scheelt op een tablet
     miljoenen doorzichtige beeldpunten per frame. */
  function mkSprite(w, h) {
    var c = document.createElement('canvas');
    c.width = Math.max(1, Math.round(w * dpr));
    c.height = Math.max(1, Math.round(h * dpr));
    var x = c.getContext('2d');
    x.setTransform(dpr, 0, 0, dpr, 0, 0);
    return { cv: c, ctx: x, w: w, h: h, top: 0 };
  }
  function mkLayer(h) { return mkSprite(W, h); }

  function ridge(x, tile, n, baseY, top, amp, ks, col) {
    var stp = tile / n, i, u, y;
    x.beginPath(); x.moveTo(0, baseY);
    for (i = 0; i <= n; i++) {
      u = 2 * Math.PI * i / n;
      y = top - Math.sin(u * ks[0]) * amp - Math.sin(u * ks[1] + 1.7) * amp * 0.45;
      x.lineTo(i * stp, y);
    }
    x.lineTo(tile, baseY); x.closePath();
    x.fillStyle = col; x.fill();
  }

  function buildLayers() {
    var S = scale(), gY = groundY(), tile = Math.round(W);
    var key = tile + 'x' + Math.round(gY) + '@' + dpr;
    if (lay && layKey === key) return;
    layKey = key;
    lay = { tile: tile };

    /* lucht + zon: staan stil, dus één keer tekenen en daarna alleen kopiëren.
       Gemeten: het kopiëren van deze laag is goedkoper dan elk frame opnieuw een
       schermgroot kleurverloop vullen. */
    var Z = mkLayer(gY + 4), z = Z.ctx;
    var sky = z.createLinearGradient(0, 0, 0, gY + 10);
    sky.addColorStop(0, '#a9d8f2'); sky.addColorStop(0.45, '#cfe9f8');
    sky.addColorStop(0.82, '#eef2e6'); sky.addColorStop(1, '#f9f3e4');
    z.fillStyle = sky; z.fillRect(0, 0, W, gY + 4);
    var sx0 = W * 0.82, sy0 = gY * 0.13;
    var gl = z.createRadialGradient(sx0, sy0, 8 * S, sx0, sy0, 110 * S);
    gl.addColorStop(0, 'rgba(255,244,196,.95)'); gl.addColorStop(0.35, 'rgba(255,238,175,.40)');
    gl.addColorStop(1, 'rgba(255,238,175,0)');
    z.fillStyle = gl; z.beginPath(); z.arc(sx0, sy0, 110 * S, 0, 7); z.fill();
    z.fillStyle = '#fff4c4';
    z.beginPath(); z.arc(sx0, sy0, 32 * S, 0, 7); z.fill();
    Z.top = 0;
    lay.back = Z;

    /* verre bergen — hoog, hazig, blauw */
    var hA = 190 * S, A = mkLayer(hA), a = A.ctx;
    ridge(a, tile, 84, hA, hA - 128 * S, 34 * S, [2, 5], '#c2d7e8');
    ridge(a, tile, 84, hA, hA - 92 * S, 26 * S, [3, 7], '#b0c9de');
    var hz = a.createLinearGradient(0, hA - 96 * S, 0, hA - 30 * S);
    hz.addColorStop(0, 'rgba(246,240,226,0)'); hz.addColorStop(1, 'rgba(250,246,235,.85)');
    a.fillStyle = hz; a.fillRect(0, hA - 96 * S, tile, 70 * S);
    A.top = gY - hA;
    lay.far = A;

    /* groene heuvels met boompjes en schaapjes op de rand */
    var hB = 128 * S, B = mkLayer(hB), b = B.ctx;
    ridge(b, tile, 96, hB, hB - 84 * S, 22 * S, [2, 3], '#bfe0c6');
    ridge(b, tile, 96, hB, hB - 58 * S, 15 * S, [3, 5], '#a8d4b3');
    for (var k = 0; k < 14; k++) {
      var tx = (k + 0.4) * tile / 14;
      var u = 2 * Math.PI * (k + 0.4) / 14;
      var ty = hB - 58 * S - Math.sin(u * 3) * 15 * S - Math.sin(u * 5 + 1.7) * 6.75 * S;
      b.fillStyle = '#8fc79e';
      b.beginPath(); b.moveTo(tx - 5 * S, ty + 2); b.lineTo(tx, ty - 15 * S); b.lineTo(tx + 5 * S, ty + 2);
      b.closePath(); b.fill();
    }
    for (var sp = 0; sp < 4; sp++) {
      var sx = (sp + 0.7) * tile / 4, us = 2 * Math.PI * (sp + 0.7) / 4;
      var sy = hB - 40 * S - Math.abs(Math.sin(us * 2)) * 8 * S;
      b.fillStyle = '#fbf7f0';
      b.beginPath(); b.ellipse(sx, sy, 7 * S, 4.6 * S, 0, 0, 7); b.fill();
      b.fillStyle = '#a49aa8';
      b.beginPath(); b.arc(sx + 6 * S, sy - 2 * S, 2.4 * S, 0, 7); b.fill();
    }
    B.top = gY - hB;
    lay.hill = B;

    /* bomenrij — verschillende maten, anders valt de herhaling op */
    var hC = 162 * S, C = mkLayer(hC), c2 = C.ctx, nt = 5;
    var VAR = [1.0, 0.78, 1.12, 0.86, 0.96], OFF = [0, 6, -3, 8, 2];
    for (var t = 0; t < nt; t++) {
      Art.bush(c2, (t + 0.15) * tile / nt, hC - 40 * S, 54 * S, 26 * S, '#8bc79b');
      Art.tree(c2, (t + 0.5) * tile / nt, hC - 46 * S + OFF[t] * S, S * 0.92 * VAR[t], 0);
    }
    C.top = gY - hC;
    lay.trees = C;

    /* weilandhek met een strook gras eronder */
    var hD = 90 * S, D = mkLayer(hD), d = D.ctx, base = hD - 40 * S;
    var fg = d.createLinearGradient(0, base - 6 * S, 0, hD);
    fg.addColorStop(0, '#cfe8ce'); fg.addColorStop(1, '#addfb6');
    d.fillStyle = fg; d.fillRect(0, base - 4 * S, tile, hD - base + 8 * S);
    var np = 9, ps = tile / np;
    for (var r2 = 0; r2 < 2; r2++) {
      var ry = base - (26 - r2 * 12) * S;
      for (var q = 0; q < np; q++) {
        d.fillStyle = r2 ? '#e6d0b0' : '#f0dcc0';
        d.beginPath();
        d.moveTo(q * ps, ry);
        d.quadraticCurveTo(q * ps + ps / 2, ry + 2.6 * S, (q + 1) * ps, ry);
        d.lineTo((q + 1) * ps, ry + 5.5 * S);
        d.quadraticCurveTo(q * ps + ps / 2, ry + 8.4 * S, q * ps, ry + 5.5 * S);
        d.closePath(); d.fill();
      }
    }
    for (var p2 = 0; p2 < np; p2++) {
      var px = p2 * ps;
      d.fillStyle = '#d9c1a0';
      Art.rrect(d, px - 3.4 * S, base - 34 * S, 6.8 * S, 36 * S, 2.5 * S); d.fill();
      d.fillStyle = '#c2a883';
      Art.rrect(d, px + 0.6 * S, base - 34 * S, 2.8 * S, 36 * S, 1.4 * S); d.fill();
      Art.bush(d, px + ps * 0.5, base + 2 * S, 46 * S, 20 * S, '#93cca1');
    }
    D.top = gY - hD;
    lay.fence = D;

    /* wolk-sprites in vier maten */
    lay.clouds = [];
    for (var ci = 0; ci < 4; ci++) {
      var cw = (96 + ci * 34) * S, chh = cw * 0.72;
      var CS = mkSprite(cw * 1.4, chh);
      cloudInto(CS.ctx, cw * 0.7, chh * 0.5, cw);
      lay.clouds.push(CS);
    }

    /* slinger met vlaggetjes: één sprite, drie keer gebruikt */
    var hG = 34 * S + 26 * S + 8;
    var G = mkSprite(W, hG);
    buntingInto(G.ctx, 5, S);
    lay.garland = G;
  }

  function blit(L, off) {
    var tile = lay.tile;
    var x = -(((off % tile) + tile) % tile);
    while (x < W) { ctx.drawImage(L.cv, x, L.top, W, L.h); x += tile; }
  }

  /* ---------- overlay-tekst ---------- */
  function toast(txt, cls, topPct) {
    var d = document.createElement('div');
    d.className = 'toast ' + (cls || '');
    d.textContent = txt;
    d.style.top = (topPct || 26) + '%';
    ov.appendChild(d);
    setTimeout(function () { d.classList.add('fade'); }, 900);
    setTimeout(function () { if (d.parentNode) d.parentNode.removeChild(d); }, 1500);
  }

  function part(o) { st.parts.push(o); }

  function burst(x, y, cols, n, spread, kind) {
    for (var i = 0; i < n; i++) {
      var a = -Math.PI / 2 + (Math.random() - 0.5) * spread;
      var v = 120 + Math.random() * 210;
      part({
        x: x, y: y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, life: 1, decay: 0.85,
        col: cols[(Math.random() * cols.length) | 0], sz: 5 + Math.random() * 7,
        rot: Math.random() * 6, vr: (Math.random() - 0.5) * 12, kind: kind || 'ribbon', grav: 620
      });
    }
  }

  /* ---------- start ---------- */
  function start(opts) {
    cv = document.getElementById('cv-run');
    ctx = cv.getContext('2d');
    ov = document.getElementById('run-overlay');
    hint = document.getElementById('tap-hint');
    dotMe = document.getElementById('dot-me');
    dotRival = document.getElementById('dot-rival');
    hudCoins = document.getElementById('hud-coins');
    hudLap = document.getElementById('hud-lap');
    ov.innerHTML = '';
    lay = null; layKey = '';
    resize();

    var g = opts.gear || {};
    var picks = [];
    MUNT.forEach(function (x) { picks.push({ x: x, kind: 'munt', got: false, bob: Math.random() * 6 }); });
    APPEL.forEach(function (x) { picks.push({ x: x, kind: 'appel', got: false, bob: Math.random() * 6 }); });
    if (g.zadeltassen) {
      MUNT_TAS.forEach(function (x) { picks.push({ x: x, kind: 'munt', got: false, bob: Math.random() * 6 }); });
    }
    picks.sort(function (p, q) { return p.x - q.x; });
    if (opts.ere) picks = [];        /* ererondje: alles is al gekocht, puur voor de sier */

    st = {
      opts: opts, gear: g,
      willWin: !!(g.noppen && g.zadel),
      lap: opts.lap || 1, lapMax: opts.lapMax || 3, ere: !!opts.ere,
      room: opts.room == null ? 99 : opts.room, full: false,
      horse: { wx: 0, phase: 0, jump: null, tilt: 0, stumble: 0, jumpY: 0 },
      rival: { wx: 250, phase: 1.6 },
      obs: [
        { type: 'heg', x: 1150, jump: true, jumped: false, hit: false },
        { type: 'water', x: 2300, jump: true, jumped: false, hit: false },
        { type: 'heuvel', x: HILL_X, jump: false, jumped: false, hit: false }
      ],
      picks: picks, parts: [], coins: 0, munt: 0, appel: 0,
      t: 0, over: 0, done: false, sprint: false, dust: 0, shown: 0
    };

    document.getElementById('hud-name').textContent = opts.name;
    hudCoins.textContent = '🪙 0';
    hudLap.textContent = st.ere ? 'ererondje 🏆' : 'rondje ' + st.lap + '/' + st.lapMax;

    if (!bound) {
      bound = true;
      cv.addEventListener('pointerdown', onTap);
      global.addEventListener('resize', resize);
    }
    hint.textContent = 'Tik voor linten 🎀 — hoeft niet!';
    hint.classList.add('on');
    setTimeout(function () { if (hint) hint.classList.remove('on'); }, 3200);

    prev = 0;
    cancelAnimationFrame(raf);
    raf = requestAnimationFrame(frame);
  }

  function stop() { cancelAnimationFrame(raf); raf = 0; st = null; }

  /* Tikken is pure sier: nooit nodig, levert nooit munten op. */
  var CHEER = ['Wat mooi! 🎀', 'Hoepla! 🎀', 'Linten! 🎀', 'Hoera! 🎀'];
  function onTap(e) {
    if (!st || st.done) return;
    var r = cv.getBoundingClientRect();
    var px = e.clientX - r.left, py = e.clientY - r.top;
    burst(px, py, ['#ffd9e3', '#e6dcf7', '#cfe6f7', '#fff3b0'], 12, 5, 'ribbon');
    hint.classList.remove('on');
    if (st.t - st.shown > 1.6) {
      st.shown = st.t;
      toast(CHEER[(Math.random() * CHEER.length) | 0], 'ribbon', 20);
    }
  }

  function frame(ts) {
    if (!st) return;
    if (!prev) prev = ts;
    var dt = Math.min(0.05, (ts - prev) / 1000); prev = ts;
    update(dt);
    if (!st) return;          /* rit afgelopen tijdens update() */
    draw();
    raf = requestAnimationFrame(frame);
  }

  /* ---------- logica ---------- */
  function collect(p, S, gY, cam) {
    p.got = true;
    st.coins++;
    if (p.kind === 'munt') st.munt++; else st.appel++;
    hudCoins.textContent = '🪙 ' + st.coins;
    hudCoins.classList.remove('bump'); void hudCoins.offsetWidth; hudCoins.classList.add('bump');
    var sx = p.x - cam, sy = gY - terrain(p.x) * S - 96 * S;
    burst(sx, sy, ['#fff3b0', '#ffe08a', '#fff', '#ffd9e3'], 11, 4.2, 'star');
    part({ x: sx, y: sy, vx: 0, vy: -40, life: 1, decay: 1.4, kind: 'ring', sz: 9 * S, col: '#ffe07a', grav: 0, rot: 0, vr: 0 });
    part({ x: sx, y: sy - 8 * S, vx: 0, vy: -62, life: 1, decay: 0.62, kind: 'text', txt: '+1', sz: 17 * S, col: '#7a5a10', grav: 0, rot: 0, vr: 0 });
  }

  function update(dt) {
    st.t += dt;
    var h = st.horse, S = scale(), gY = groundY(), cam = camX();

    /* snelheid */
    var f = 1;
    if (h.stumble > 0) { h.stumble -= dt; f = 0.34; h.tilt = Math.sin(st.t * 26) * 0.12; }
    else h.tilt += (0 - h.tilt) * Math.min(1, dt * 8);
    var onHill = h.wx > HILL_X && h.wx < HILL_X + HILL_W * 0.62;
    if (onHill) f *= st.gear.zadel ? 0.92 : 0.50;
    if (st.gear.hoefijzers) f *= 1.22;              /* hoefijzers = sneller rondje */
    if (st.sprint) f *= 1.08;
    if (h.wx >= TRACK) f *= Math.max(0.25, 1 - (h.wx - TRACK) / 260);

    h.wx += BASE * f * dt;
    h.phase += dt * (7 + f * 5);

    /* zelf oppakken: alles wat de pony passeert gaat de buidel in */
    for (var c = 0; c < st.picks.length; c++) {
      var p = st.picks[c];
      if (p.got || h.wx + 30 < p.x) continue;
      if (st.coins >= st.room) {
        if (!st.full) { st.full = true; toast('Je buidel zit vol! 🪙', 'ribbon', 30); }
        continue;
      }
      collect(p, S, gY, cam);
    }

    /* hindernissen */
    for (var i = 0; i < st.obs.length; i++) {
      var o = st.obs[i];
      if (o.jump && !o.jumped && h.wx >= o.x - 82 * S) {
        o.jumped = true;
        h.jump = { from: h.wx, len: 200 * S };
      }
      if (!o.jump && !o.jumped && h.wx >= HILL_X - 30) {
        o.jumped = true;
        toast(st.gear.zadel ? 'Licht zadel! 🪶' : 'Zwaar zadel... zwoeg!', '', 30);
      }
      if (o.type === 'water' && o.jumped && !o.hit && h.wx >= o.x + 60 * S) {
        o.hit = true;
        var sx = W * 0.30, sy = groundY();
        if (st.gear.noppen) {
          toast('Noppen! Droge hoeven ✨', '', 30);
          burst(sx, sy - 30, ['#fff3b0', '#fff'], 12, 3, 'star');
        } else {
          h.stumble = 2.5;
          burst(sx - 20, sy - 20, ['#9fd4f0', '#cfe6f7', '#eaf6ff'], 26, 3.6, 'drop');
          toast('Plons! ' + st.opts.name + ' glijdt uit 💦', '', 30);
        }
      }
    }

    /* sprong-boog */
    if (h.jump) {
      var u = (h.wx - h.jump.from) / h.jump.len;
      if (u >= 1) { h.jump = null; h.jumpY = 0; }
      else h.jumpY = Math.sin(Math.PI * u) * 105 * S;
    } else h.jumpY = 0;

    /* stofwolkjes achter de hoeven */
    st.dust -= dt;
    if (!h.jump && h.stumble <= 0 && st.dust <= 0 && !st.done) {
      st.dust = 0.10;
      part({
        x: W * 0.30 - (34 + Math.random() * 20) * S, y: gY - terrain(h.wx) * S - 3 * S,
        vx: -26 - Math.random() * 26, vy: -16 - Math.random() * 22, life: 1, decay: 1.5,
        kind: 'dust', sz: (6 + Math.random() * 6) * S, col: '#fffaf0', grav: -22, rot: 0, vr: 0
      });
    }

    /* eindspurt */
    if (!st.sprint && st.willWin && h.wx > TRACK - 700) {
      st.sprint = true; toast('Zilverhoef-spurt! 💨', 'ribbon', 30);
    }

    /* Tegenstander: houdt de hele rit een net verschil aan, zodat de pony's nooit
       over elkaar heen lopen en de uitslag klopt met de uitrusting. */
    var target = h.wx + (st.willWin ? -250 : 250) + Math.sin(st.t * 0.35) * 55;
    var rv = Math.max(70, Math.min(330, RIVAL_V + (target - st.rival.wx) * 0.8));
    if (st.willWin && st.rival.wx > TRACK - 40 && h.wx < TRACK) rv = 0;
    st.rival.wx += rv * dt;
    st.rival.phase += dt * 11;

    /* deeltjes */
    for (var q = st.parts.length - 1; q >= 0; q--) {
      var s = st.parts[q];
      s.vy += (s.grav || 0) * dt; s.x += s.vx * dt; s.y += s.vy * dt;
      s.rot += s.vr * dt; s.life -= dt * s.decay;
      if (s.life <= 0) st.parts.splice(q, 1);
    }

    /* finish */
    if (!st.done && h.wx >= TRACK) {
      st.done = true; st.over = 0;
      hint.classList.remove('on');
      toast(st.willWin ? '🏆 Eerste! ' + st.opts.name + ' wint!' : '🏁 Finish! Tweede plaats', 'ribbon', 26);
      if (st.willWin) burst(W / 2, H * 0.5, ['#f2c14e', '#e58fa8', '#8fcfa4', '#cfe6f7'], 60, 5.5, 'ribbon');
    }
    if (st.done) {
      st.over += dt;
      if (st.over > 0.9 && !st.told) {
        st.told = true;
        toast(st.ere ? 'Ererondje klaar! 🏆' : 'Rondje ' + st.lap + ': +' + st.coins + ' munten 🪙', '', 44);
      }
      if (st.over > 2.4) {
        var res = {
          place: st.willWin ? 1 : 2, ere: st.ere,
          coins: st.coins, munt: st.munt, apples: st.appel,
          weakness: !st.gear.noppen ? 'water' : (!st.gear.zadel ? 'heuvel' : null)
        };
        var cb = st.opts.onFinish; stop(); cb(res);
        return;
      }
    }

    dotMe.style.left = 'calc(' + Math.min(100, h.wx / TRACK * 100) + '% - 12px)';
    dotRival.style.left = 'calc(' + Math.min(100, st.rival.wx / TRACK * 100) + '% - 12px)';
  }

  /* ---------- tekenen ---------- */
  function draw() {
    var S = scale(), gY = groundY(), cam = camX();
    if (!lay) buildLayers();

    /* lucht + zon staan stil: kant-en-klare laag erop kopiëren */
    ctx.drawImage(lay.back.cv, 0, 0, W, lay.back.h);

    /* slingers met vlaggetjes — vult ook een hoge, staande lucht */
    var gsp = lay.garland;
    garland(gsp, gY * 0.11, 0);
    if (gY > 420) garland(gsp, gY * 0.34, 1.4);
    if (gY > 560) garland(gsp, gY * 0.50, 2.8);

    /* wolken op drie snelheden, gelijkmatig over de lucht verdeeld */
    var CL = [0.09, 0.20, 0.14, 0.30, 0.24, 0.38, 0.33, 0.46, 0.55, 0.42, 0.62];
    var span = W + 380;
    for (var c = 0; c < CL.length; c++) {
      if (CL[c] * gY > gY - 126 * S) continue;
      var sp = 0.08 + (c % 3) * 0.045;
      var cx = ((c / CL.length * span - cam * sp) % span + span) % span - 190;
      var spr = lay.clouds[c % 4];
      ctx.drawImage(spr.cv, cx - spr.w / 2, gY * CL[c] - spr.h / 2, spr.w, spr.h);
    }

    /* luchtballon: net boven de bergtoppen, zodat hij nooit achter de bomen zakt */
    var bY = gY - 252 * S;
    if (bY > gY * 0.22) {
      balloon(W * (0.27 + Math.sin(st.t * 0.07) * 0.17),
        bY + Math.sin(st.t * 0.5) * 6 * S, S * 0.85);
    }

    /* vogeltjes */
    ctx.strokeStyle = 'rgba(255,255,255,.9)'; ctx.lineWidth = 2.4 * S; ctx.lineCap = 'round';
    for (var b2 = 0; b2 < 4; b2++) {
      var bx = ((b2 * 260 - cam * 0.05) % (W + 400) + W + 400) % (W + 400) - 150;
      var by = gY * (0.16 + (b2 % 2) * 0.07) + Math.sin(st.t * 1.4 + b2) * 5;
      var fl = Math.sin(st.t * 6 + b2 * 2) * 4 * S;
      ctx.beginPath();
      ctx.moveTo(bx - 9 * S, by + fl); ctx.quadraticCurveTo(bx, by - 6 * S, bx + 9 * S, by + fl);
      ctx.stroke();
    }

    /* parallax-lagen: ver → dichtbij */
    blit(lay.far, cam * 0.16);
    blit(lay.hill, cam * 0.30);
    blit(lay.trees, cam * 0.44);
    blit(lay.fence, cam * 0.58);

    drawGround(S, gY, cam);
    drawObstacles(S, gY, cam);

    /* tegenstander (verder weg, dus iets kleiner en hoger) */
    var rvx = st.rival.wx - cam;
    if (rvx > -220 && rvx < W + 220) {
      Art.drawHorse(ctx, {
        x: rvx, y: gY - terrain(st.rival.wx) * S - 26 * S, scale: S * 0.80,
        coat: 'grijs', gear: { zadel: true }, phase: st.rival.phase, t: st.t
      });
    }

    drawFinish(S, gY, cam);
    drawPicks(S, gY, cam);

    /* pony */
    var h = st.horse;
    Art.drawHorse(ctx, {
      x: W * 0.30, y: gY - terrain(h.wx) * S - h.jumpY, scale: S,
      coat: st.opts.coat, gear: st.gear, phase: h.phase, tilt: h.tilt, t: st.t,
      air: Math.min(1, h.jumpY / (105 * S))
    });

    drawTufts(S, gY, cam, 2, 3);   /* voorste rij gras vóór de pony */
    drawParts();
    drawFore(S, cam);              /* onscherpe voorgrond onderaan */

    /* zachte schaduw langs de onderrand (goedkoper dan een volledig vignet) */
    if (!vgr) {
      vgr = ctx.createLinearGradient(0, H * 0.76, 0, H);
      vgr.addColorStop(0, 'rgba(110,88,130,0)'); vgr.addColorStop(1, 'rgba(104,82,124,.20)');
    }
    ctx.fillStyle = vgr; ctx.fillRect(0, H * 0.76, W, H * 0.24 + 1);
  }

  /* Slinger één keer in een sprite tekenen; daarna alleen nog kopiëren met een
     zacht deinend hoogteverschil. */
  function buntingInto(x, top, S) {
    var sag = 34 * S, n = 13, w = W + 20;
    x.strokeStyle = 'rgba(255,255,255,.8)'; x.lineWidth = 2.2 * S;
    x.beginPath();
    for (var i = 0; i <= n; i++) {
      var u = i / n;
      x.lineTo(u * w - 10, top + Math.sin(Math.PI * u) * sag);
    }
    x.stroke();
    var COL = ['#ffd9e3', '#e6dcf7', '#cfe6f7', '#fff3b0', '#cfeede'];
    for (var k = 0; k < n; k++) {
      var u2 = (k + 0.5) / n, fx = u2 * w - 10;
      var fy = top + Math.sin(Math.PI * u2) * sag;
      var tl = (k % 3 - 1) * 0.09;
      x.save(); x.translate(fx, fy); x.rotate(tl);
      x.fillStyle = COL[k % COL.length];
      x.beginPath(); x.moveTo(-8 * S, 0); x.lineTo(8 * S, 0); x.lineTo(0, 22 * S);
      x.closePath(); x.fill();
      x.fillStyle = 'rgba(255,255,255,.35)';
      x.beginPath(); x.moveTo(-8 * S, 0); x.lineTo(0, 0); x.lineTo(0, 22 * S);
      x.closePath(); x.fill();
      x.restore();
    }
  }
  function garland(spr, y, ph) {
    ctx.drawImage(spr.cv, 0, y - 5 + Math.sin(st.t * 0.6 + ph) * 3, spr.w, spr.h);
  }

  function cloudInto(x, cx, cy, w) {
    var h = w * 0.42;
    Art.bush(x, cx, cy + h * 0.12, w, h, 'rgba(222,230,244,.60)');
    Art.bush(x, cx, cy, w * 0.92, h * 0.88, 'rgba(255,255,255,.90)');
    x.fillStyle = 'rgba(255,255,255,.72)';
    x.beginPath(); x.ellipse(cx - w * 0.16, cy - h * 0.22, w * 0.22, h * 0.3, 0, 0, 7); x.fill();
  }

  /* Luchtballon in pasteltinten */
  function balloon(x, y, s) {
    ctx.save(); ctx.translate(x, y); ctx.scale(s, s);
    ctx.strokeStyle = 'rgba(140,120,150,.5)'; ctx.lineWidth = 1.4;
    ctx.beginPath(); ctx.moveTo(-9, 34); ctx.lineTo(-6, 46);
    ctx.moveTo(9, 34); ctx.lineTo(6, 46); ctx.stroke();
    var COL = ['#f4a9bd', '#fbe1a0', '#a9d8ee', '#c9b6e8'];
    for (var i = 0; i < 4; i++) {
      ctx.fillStyle = COL[i];
      ctx.beginPath();
      ctx.moveTo(0, -34);
      ctx.bezierCurveTo(-26 + i * 13, -30, -30 + i * 15, 8, 0, 34);
      ctx.bezierCurveTo(-13 + i * 15, 8, -17 + i * 13, -30, 0, -34);
      ctx.fill();
    }
    ctx.fillStyle = 'rgba(255,255,255,.35)';
    ctx.beginPath(); ctx.ellipse(-9, -14, 6, 12, -0.3, 0, 7); ctx.fill();
    ctx.fillStyle = '#c08c58';
    Art.rrect(ctx, -8, 45, 16, 13, 4); ctx.fill();
    ctx.fillStyle = '#8d5f38';
    Art.rrect(ctx, -8, 45, 16, 4, 2); ctx.fill();
    ctx.restore();
  }

  function drawGround(S, gY, cam) {
    var i, y;

    /* weide */
    var gg = ctx.createLinearGradient(0, gY - HILL_H * S, 0, H);
    gg.addColorStop(0, '#a9dcb2'); gg.addColorStop(0.5, '#95d2a1'); gg.addColorStop(1, '#7ec38d');
    ctx.fillStyle = gg;
    ctx.beginPath(); ctx.moveTo(0, H);
    for (i = 0; i <= W; i += 8) ctx.lineTo(i, gY - terrain(i + cam) * S);
    ctx.lineTo(W, H); ctx.closePath(); ctx.fill();

    /* gemaaide banen geven diepte */
    ctx.fillStyle = 'rgba(255,255,255,.055)';
    var per = 330, s0 = Math.floor(cam / per) * per;
    for (var w = s0; w < cam + W + per; w += per) {
      var bx = w - cam;
      ctx.beginPath();
      ctx.moveTo(bx, gY - terrain(w) * S);
      ctx.lineTo(bx + 165, gY - terrain(w + 165) * S);
      ctx.lineTo(bx + 240, H); ctx.lineTo(bx - 34, H);
      ctx.closePath(); ctx.fill();
    }

    /* zandpad met zachte randen */
    ctx.beginPath();
    for (i = 0; i <= W; i += 8) ctx.lineTo(i, gY - terrain(i + cam) * S - 10 * S);
    for (i = W; i >= 0; i -= 8) ctx.lineTo(i, gY - terrain(i + cam) * S + 25 * S);
    ctx.closePath();
    var pg = ctx.createLinearGradient(0, gY - 12 * S, 0, gY + 26 * S);
    pg.addColorStop(0, '#e0c49c'); pg.addColorStop(0.45, '#eed9b4'); pg.addColorStop(1, '#d9bd93');
    ctx.fillStyle = pg; ctx.fill();
    ctx.strokeStyle = 'rgba(120,150,110,.35)'; ctx.lineWidth = 2 * S;
    ctx.beginPath();
    for (i = 0; i <= W; i += 8) {
      y = gY - terrain(i + cam) * S - 10 * S;
      if (i === 0) ctx.moveTo(i, y); else ctx.lineTo(i, y);
    }
    ctx.stroke();

    /* hoefsporen en steentjes op het pad */
    var hp = 96, h0 = Math.floor(cam / hp) * hp;
    for (var hx = h0; hx < cam + W + hp; hx += hp) {
      var sxp = hx - cam, syp = gY - terrain(hx) * S;
      ctx.fillStyle = 'rgba(150,118,80,.20)';
      ctx.beginPath(); ctx.ellipse(sxp, syp + 6 * S, 5 * S, 3 * S, 0, 0, 7); ctx.fill();
      ctx.beginPath(); ctx.ellipse(sxp + 42, syp + 15 * S, 5.5 * S, 3.2 * S, 0, 0, 7); ctx.fill();
      if ((hx / hp) % 3 === 0) {
        ctx.fillStyle = 'rgba(160,150,140,.45)';
        ctx.beginPath(); ctx.ellipse(sxp + 20, syp + 19 * S, 3 * S, 2 * S, 0, 0, 7); ctx.fill();
      }
    }

    drawTufts(S, gY, cam, 0, 2);   /* rijen achter de pony */
  }

  /* Graspollen en bloemetjes in drie rijen. Per rij één pad per soort, zodat de
     hele rij in twee vullingen klaar is (scheelt honderden fills per frame). */
  var ROWS = [{ off: -4, sc: 0.55, step: 96 }, { off: 34, sc: 0.95, step: 124 }, { off: 76, sc: 1.35, step: 158 }];
  var TCOL = ['#8ecb9a', '#7abb88', '#68ab78'];
  function drawTufts(S, gY, cam, from, to) {
    for (var ri = from; ri < to; ri++) {
      var R = ROWS[ri], n = Math.ceil(W / R.step) + 3;
      var first = Math.floor((cam - ri * 37) / R.step);
      var flowers = null;
      ctx.beginPath();
      for (var q = 0; q < n; q++) {
        var tf = first + q;
        var fx = tf * R.step + ri * 37 - cam;
        if (fx < -60 || fx > W + 60) continue;
        var fy = gY - terrain(fx + cam) * S + R.off * S;
        if (fy > H + 20) continue;
        var g = S * R.sc, sway = Math.sin(st.t * 1.6 + tf * 0.7) * 2 * g;
        if (((tf % 5) + 5) % 5) {
          ctx.moveTo(fx - 8 * g, fy);
          ctx.quadraticCurveTo(fx - 2 * g + sway, fy - 18 * g, fx + 8 * g, fy);
          ctx.moveTo(fx - 2 * g, fy);
          ctx.quadraticCurveTo(fx + 6 * g + sway, fy - 13 * g, fx + 11 * g, fy);
        } else {
          (flowers || (flowers = [])).push(fx, fy, g, sway, tf);
        }
      }
      ctx.fillStyle = TCOL[ri]; ctx.fill();
      if (!flowers) continue;
      ctx.strokeStyle = '#7dbd8b'; ctx.lineWidth = 2 * S * R.sc;
      ctx.beginPath();
      for (var f = 0; f < flowers.length; f += 5) {
        ctx.moveTo(flowers[f], flowers[f + 1]);
        ctx.lineTo(flowers[f] + flowers[f + 3] * 0.5, flowers[f + 1] - 9 * flowers[f + 2]);
      }
      ctx.stroke();
      for (var f2 = 0; f2 < flowers.length; f2 += 5) {
        var px = flowers[f2] + flowers[f2 + 3] * 0.5, py = flowers[f2 + 1] - 9 * flowers[f2 + 2];
        var gg = flowers[f2 + 2], m3 = ((flowers[f2 + 4] % 3) + 3) % 3;
        ctx.fillStyle = m3 === 0 ? '#ffd9e3' : (m3 === 1 ? '#fff3b0' : '#e6dcf7');
        ctx.beginPath();
        for (var pe = 0; pe < 5; pe++) {
          var an = pe / 5 * Math.PI * 2;
          var ax = px + Math.cos(an) * 3.4 * gg, ay = py + Math.sin(an) * 3.4 * gg;
          ctx.moveTo(ax + 2.6 * gg, ay);
          ctx.arc(ax, ay, 2.6 * gg, 0, 7);
        }
        ctx.fill();
        ctx.fillStyle = '#ffe9a8';
        ctx.beginPath(); ctx.arc(px, py, 2 * gg, 0, 7); ctx.fill();
      }
    }
  }

  /* Grote, donkere grassprieten langs de onderrand: schuiven sneller dan de
     grond en geven het beeld diepte (en vullen een hoog, staand scherm). */
  function drawFore(S, cam) {
    var per = 132, s0 = Math.floor(cam * 1.35 / per) * per;
    for (var w = s0; w < cam * 1.35 + W + per; w += per) {
      var x = w - cam * 1.35, k = (w / per) | 0;
      var r = Math.sin(k * 12.9898) * 0.5 + 0.5;
      var g = S * (1.0 + r * 0.9), sway = Math.sin(st.t * 1.3 + k) * 4 * g;
      ctx.fillStyle = (k % 2) ? 'rgba(84,134,96,.40)' : 'rgba(64,112,80,.34)';
      for (var b = 0; b < 3; b++) {
        var bx = x + (b - 1) * (13 + r * 8) * g;
        ctx.beginPath();
        ctx.moveTo(bx - 8 * g, H + 4);
        ctx.quadraticCurveTo(bx - 2 * g + sway, H - (20 + r * 16) * g, bx + 7 * g, H + 4);
        ctx.closePath(); ctx.fill();
      }
    }
  }

  function drawObstacles(S, gY, cam) {
    for (var i = 0; i < st.obs.length; i++) {
      var o = st.obs[i], x = o.x - cam;
      if (o.type === 'heuvel' || x < -260 || x > W + 260) continue;
      if (o.type === 'heg') {
        ctx.fillStyle = 'rgba(74,63,82,.10)';
        ctx.beginPath(); ctx.ellipse(x, gY + 4 * S, 62 * S, 8 * S, 0, 0, 7); ctx.fill();
        for (var pz = 0; pz < 2; pz++) {
          var qx = x + (pz ? 44 : -44) * S;
          ctx.fillStyle = '#c8a97e';
          Art.rrect(ctx, qx - 4 * S, gY - 44 * S, 8 * S, 46 * S, 3 * S); ctx.fill();
          ctx.fillStyle = '#b0906a';
          Art.rrect(ctx, qx + 0.8 * S, gY - 44 * S, 3.2 * S, 46 * S, 1.6 * S); ctx.fill();
        }
        ctx.fillStyle = '#e6d0b0';
        Art.rrect(ctx, x - 48 * S, gY - 30 * S, 96 * S, 7 * S, 3 * S); ctx.fill();
        Art.bush(ctx, x, gY - 26 * S, 106 * S, 44 * S, '#4f9268');
        Art.bush(ctx, x, gY - 36 * S, 100 * S, 50 * S, '#6fb884');
        Art.bush(ctx, x - 18 * S, gY - 50 * S, 58 * S, 36 * S, '#89cf9b');
        Art.bush(ctx, x + 24 * S, gY - 48 * S, 44 * S, 30 * S, '#9ad9aa');
        for (var f = 0; f < 7; f++) {
          ctx.fillStyle = f % 2 ? '#ffd9e3' : '#fff6c9';
          ctx.beginPath();
          ctx.arc(x - 40 * S + f * 13.5 * S, gY - 44 * S + (f % 3) * 9 * S, 3.8 * S, 0, 7); ctx.fill();
        }
        sign(ctx, 'heg', x, gY - 74 * S, S);
      } else if (o.type === 'water') {
        ctx.fillStyle = 'rgba(74,63,82,.10)';
        ctx.beginPath(); ctx.ellipse(x, gY + 4 * S, 60 * S, 8 * S, 0, 0, 7); ctx.fill();
        var wg = ctx.createLinearGradient(0, gY - 32 * S, 0, gY + 2 * S);
        wg.addColorStop(0, '#c69a72'); wg.addColorStop(1, '#9c7550');
        ctx.fillStyle = wg;
        Art.rrect(ctx, x - 54 * S, gY - 32 * S, 108 * S, 34 * S, 9 * S); ctx.fill();
        ctx.fillStyle = 'rgba(90,64,40,.35)';
        for (var sv = 0; sv < 5; sv++) ctx.fillRect(x - 40 * S + sv * 20 * S, gY - 30 * S, 1.8 * S, 30 * S);
        ctx.fillStyle = '#8d95a3';
        ctx.fillRect(x - 54 * S, gY - 24 * S, 108 * S, 3.4 * S);
        ctx.fillRect(x - 54 * S, gY - 8 * S, 108 * S, 3.4 * S);
        var lg = ctx.createLinearGradient(0, gY - 28 * S, 0, gY - 6 * S);
        lg.addColorStop(0, '#8fcbec'); lg.addColorStop(1, '#5fa9d6');
        ctx.fillStyle = lg;
        Art.rrect(ctx, x - 46 * S, gY - 28 * S, 92 * S, 21 * S, 6 * S); ctx.fill();
        ctx.fillStyle = 'rgba(255,255,255,.55)';
        for (var w = 0; w < 3; w++) {
          ctx.beginPath();
          ctx.ellipse(x - 26 * S + w * 26 * S + Math.sin(st.t * 1.3 + w) * 4 * S,
            gY - 21 * S + Math.sin(st.t * 3 + w) * 1.6 * S, 11 * S, 2.6 * S, 0, 0, 7);
          ctx.fill();
        }
        ctx.fillStyle = '#7cc08a';
        ctx.beginPath(); ctx.ellipse(x + 30 * S, gY - 18 * S, 9 * S, 4 * S, 0, 0, 7); ctx.fill();
        ctx.fillStyle = '#ffd9e3';
        ctx.beginPath(); ctx.arc(x + 32 * S, gY - 20 * S, 3 * S, 0, 7); ctx.fill();
        sign(ctx, 'waterbak', x, gY - 50 * S, S);
      }
    }
    var hx = HILL_X + HILL_W / 2 - cam;
    if (hx > -300 && hx < W + 300) {
      /* keitjes op de heuvelrug */
      for (var r = 0; r < 4; r++) {
        var rw = HILL_X + 90 + r * 130, rx = rw - cam;
        if (rx < -40 || rx > W + 40) continue;
        ctx.fillStyle = '#b9b3ae';
        ctx.beginPath(); ctx.ellipse(rx, gY - terrain(rw) * S + 20 * S, (7 + r % 3 * 3) * S, (5 + r % 2 * 2) * S, 0, 0, 7);
        ctx.fill();
      }
      sign(ctx, 'heuvel', hx, gY - (HILL_H + 44) * S, S);
    }
  }

  function sign(c2, txt, x, y, S) {
    c2.save();
    c2.font = '700 ' + Math.round(15 * S) + 'px system-ui,sans-serif';
    c2.textAlign = 'center';
    var w = c2.measureText(txt).width + 20 * S;
    c2.fillStyle = 'rgba(120,96,66,.22)';
    Art.rrect(c2, x - w / 2, y - 13 * S, w, 24 * S, 11 * S); c2.fill();
    c2.fillStyle = 'rgba(255,253,246,.92)';
    Art.rrect(c2, x - w / 2, y - 15 * S, w, 24 * S, 11 * S); c2.fill();
    c2.fillStyle = '#7a6a58';
    c2.fillText(txt, x, y + 2 * S);
    c2.restore();
  }

  function drawFinish(S, gY, cam) {
    var fx = TRACK - cam;
    if (fx < -140 || fx > W + 140) return;
    for (var sd = 0; sd < 2; sd++) {
      var px = fx + (sd ? 58 : -58) * S;
      ctx.fillStyle = '#efe4d3';
      ctx.fillRect(px - 5 * S, gY - 200 * S, 10 * S, 200 * S);
      ctx.fillStyle = '#d6c7b1';
      ctx.fillRect(px + 1 * S, gY - 200 * S, 4 * S, 200 * S);
    }
    ctx.fillStyle = '#fffdf6';
    Art.rrect(ctx, fx - 70 * S, gY - 214 * S, 140 * S, 30 * S, 6 * S); ctx.fill();
    for (var cq = 0; cq < 10; cq++) for (var r = 0; r < 2; r++) {
      if ((r + cq) % 2) continue;
      ctx.fillStyle = '#5d5268';
      ctx.fillRect(fx - 68 * S + cq * 13.6 * S, gY - 212 * S + r * 13 * S, 13.6 * S, 13 * S);
    }
    ctx.strokeStyle = 'rgba(229,143,168,.85)'; ctx.lineWidth = 4 * S;
    ctx.beginPath();
    ctx.moveTo(fx - 58 * S, gY - 130 * S);
    ctx.quadraticCurveTo(fx, gY - 118 * S + Math.sin(st.t * 2) * 4 * S, fx + 58 * S, gY - 130 * S);
    ctx.stroke();
  }

  function drawPicks(S, gY, cam) {
    for (var i = 0; i < st.picks.length; i++) {
      var p = st.picks[i];
      if (p.got) continue;
      var x = p.x - cam;
      if (x < -70 || x > W + 70) continue;
      var y = gY - terrain(p.x) * S - 96 * S + Math.sin(st.t * 2 + p.bob) * 7 * S;
      ctx.save();
      if (st.coins >= st.room) ctx.globalAlpha = 0.32;
      /* zachte schaduw op het pad, zodat je ziet waar het ding hangt */
      ctx.fillStyle = 'rgba(120,96,66,.13)';
      ctx.beginPath();
      ctx.ellipse(x, gY - terrain(p.x) * S + 8 * S, 12 * S, 4 * S, 0, 0, 7); ctx.fill();
      if (p.kind === 'munt') Art.coin(ctx, x, y, 17 * S, st.t * 2.2 + p.bob);
      else Art.apple(ctx, x, y, 17 * S, st.t * 1.6 + p.bob);
      ctx.restore();
    }
  }

  function drawParts() {
    for (var i = 0; i < st.parts.length; i++) {
      var p = st.parts[i], a = Math.max(0, Math.min(1, p.life));
      ctx.save(); ctx.globalAlpha = a;
      if (p.kind === 'ring') {
        ctx.strokeStyle = p.col; ctx.lineWidth = 3 * (1 - p.life) + 1.5;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.sz * (1.9 - p.life * 0.95), 0, 7); ctx.stroke();
      } else if (p.kind === 'text') {
        ctx.font = '900 ' + Math.round(p.sz) + 'px system-ui,sans-serif';
        ctx.textAlign = 'center';
        ctx.lineWidth = 4; ctx.strokeStyle = 'rgba(255,255,255,.95)';
        ctx.strokeText(p.txt, p.x, p.y);
        ctx.fillStyle = p.col; ctx.fillText(p.txt, p.x, p.y);
      } else if (p.kind === 'dust') {
        ctx.fillStyle = p.col; ctx.globalAlpha = a * 0.5;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.sz * (1.6 - p.life * 0.6), 0, 7); ctx.fill();
      } else if (p.kind === 'star') {
        Art.star(ctx, p.x, p.y, p.sz * 0.9, p.col);
      } else if (p.kind === 'drop') {
        ctx.fillStyle = p.col;
        ctx.beginPath(); ctx.arc(p.x, p.y, p.sz * 0.55, 0, 7); ctx.fill();
      } else {
        ctx.translate(p.x, p.y); ctx.rotate(p.rot);
        ctx.fillStyle = p.col;
        Art.rrect(ctx, -p.sz / 2, -p.sz * 0.75, p.sz, p.sz * 1.5, 2); ctx.fill();
      }
      ctx.restore();
    }
  }

  global.Run = { start: start, stop: stop, TRACK: TRACK };
})(window);
