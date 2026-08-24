/* Zilverhoef — tekenwerk (canvas 2D). Alles met paden: geen plaatjes, geen fonts nodig. */
(function (global) {
  'use strict';

  var COATS = {
    vos:      { id:'vos',      naam:'Vos',      body:'#cd8348', dark:'#a35f2b', light:'#e8ae76', mane:'#6b4326', hoof:'#4a3a2c' },
    zwartje:  { id:'zwartje',  naam:'Zwartje',  body:'#5a5162', dark:'#3f3847', light:'#7d748a', mane:'#2c2632', hoof:'#2b2530' },
    schimmel: { id:'schimmel', naam:'Schimmel', body:'#e6e9f1', dark:'#c2c9d9', light:'#fdfdff', mane:'#c6cfe3', hoof:'#7a7686', dapple:1 },
    grijs:    { id:'grijs',    naam:'Grijs',    body:'#a79fb3', dark:'#8a8397', light:'#c4bdcd', mane:'#6f6a7a', hoof:'#5b5665' }
  };

  function rrect(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  /* Eén been: schouder → knie → kogel → hoef. De onderdelen lopen iets na op de
     bovenbeen-zwaai, daardoor ziet de gang vloeiend uit in plaats van hoekig. */
  function leg(ctx, hx, hy, ph, col, dark, g) {
    var s = Math.sin(ph), s2 = Math.sin(ph - 0.6);
    var lift = Math.max(0, s) * 10;
    var kx = hx + s * 6.5 + 1, ky = hy * 0.46 - lift * 0.30;
    var fx = hx + s2 * 12 + 1, fy = hy * 0.15 - lift * 0.72;
    var tx = hx + s2 * 13, ty = -lift;
    ctx.strokeStyle = col; ctx.lineCap = 'round';
    ctx.lineWidth = 10.5; ctx.beginPath(); ctx.moveTo(hx, hy); ctx.lineTo(kx, ky); ctx.stroke();
    ctx.lineWidth = 7.6; ctx.beginPath(); ctx.moveTo(kx, ky); ctx.lineTo(fx, fy); ctx.stroke();
    ctx.lineWidth = 6; ctx.beginPath(); ctx.moveTo(fx, fy); ctx.lineTo(tx, ty - 4); ctx.stroke();
    if (g.noppen) {
      ctx.fillStyle = '#6b5645';
      rrect(ctx, tx - 8, ty - 16, 16, 16, 5); ctx.fill();
      ctx.fillStyle = '#8a7059';
      rrect(ctx, tx - 8, ty - 16, 16, 5, 2.5); ctx.fill();
      ctx.fillStyle = '#f7e08a';
      for (var i = 0; i < 3; i++) { ctx.beginPath(); ctx.arc(tx - 4 + i * 4, ty - 2.5, 1.8, 0, 7); ctx.fill(); }
    } else {
      ctx.fillStyle = dark;
      rrect(ctx, tx - 6.5, ty - 10, 13, 10, 3.5); ctx.fill();
      if (g.hoefijzers) {
        ctx.fillStyle = '#c3cad6';
        rrect(ctx, tx - 7.5, ty - 3.4, 15, 4, 2); ctx.fill();
        ctx.fillStyle = '#8d95a3';
        rrect(ctx, tx - 7.5, ty - 3.4, 15, 1.6, 1); ctx.fill();
      }
    }
  }

  /* o = {x,y,scale,coat,gear,phase,tilt,t} — (x,y) = grond tussen de hoeven */
  function drawHorse(ctx, o) {
    var c = COATS[o.coat] || COATS.vos;
    var g = o.gear || {};
    var s = o.scale == null ? 1 : o.scale;
    var ph = o.phase || 0;
    var T = o.t == null ? ph * 0.42 : o.t;
    var bob = Math.sin(ph * 2) * 1.7;          /* draf-wiegen */
    var nod = Math.sin(ph * 2 - 0.7) * 0.05;   /* hoofd knikt mee */
    var air = o.air || 0;                      /* 0..1 hoe hoog in de lucht */

    ctx.save();
    ctx.translate(o.x, o.y);
    ctx.scale(s, s);
    if (o.tilt) ctx.rotate(o.tilt);

    /* schaduw: kleiner en lichter als de pony in de lucht hangt */
    ctx.fillStyle = 'rgba(74,63,82,' + (0.16 - air * 0.10).toFixed(3) + ')';
    ctx.beginPath(); ctx.ellipse(0, 2 + air * 4, 48 - air * 14, 8 - air * 2.5, 0, 0, 7); ctx.fill();

    ctx.translate(0, bob);

    /* ---- benen aan de overkant (donkerder, achter de romp) ---- */
    leg(ctx, -22, -54, ph, c.dark, c.hoof, g);
    leg(ctx, 21, -52, ph + Math.PI + 0.3, c.dark, c.hoof, g);

    /* ---- staart: één volle bundel die met de gang meezwaait ---- */
    var sw = Math.sin(ph) * 4.5, sw2 = Math.sin(ph - 0.8) * 6;
    ctx.beginPath();
    ctx.moveTo(-38, -78);
    ctx.bezierCurveTo(-58 + sw, -80, -72 + sw2, -52, -62 + sw2 * 1.4, -14);
    ctx.bezierCurveTo(-56 + sw2, -10, -46 + sw2 * 0.7, -10, -44 + sw2 * 0.8, -16);
    ctx.bezierCurveTo(-50 + sw, -46, -44 + sw * 0.4, -64, -32, -66);
    ctx.closePath();
    ctx.fillStyle = c.mane; ctx.fill();
    ctx.strokeStyle = 'rgba(74,63,82,.16)'; ctx.lineWidth = 2; ctx.stroke();
    ctx.strokeStyle = c.dapple ? '#dfe3ee' : c.dark;
    ctx.lineWidth = 3; ctx.lineCap = 'round';
    for (var t = 0; t < 3; t++) {
      var o = t * 5 - 5;
      ctx.beginPath();
      ctx.moveTo(-40 + o * 0.3, -74 + t * 3);
      ctx.quadraticCurveTo(-58 + sw + o, -50, -54 + sw2 * 1.2 + o, -20 + t * 4);
      ctx.stroke();
    }
    ctx.fillStyle = c.mane;
    ctx.beginPath(); ctx.ellipse(-36, -74, 9, 8, -0.3, 0, 7); ctx.fill();

    /* ---- romp met ronding ---- */
    var bg = ctx.createLinearGradient(0, -92, 0, -34);
    bg.addColorStop(0, c.light); bg.addColorStop(0.55, c.body); bg.addColorStop(1, c.dark);
    ctx.fillStyle = bg;
    ctx.beginPath(); ctx.ellipse(-2, -62, 41, 26, -0.04, 0, 7); ctx.fill();
    ctx.beginPath(); ctx.arc(-26, -62, 25, 0, 7); ctx.fill();
    ctx.beginPath(); ctx.arc(22, -59, 22, 0, 7); ctx.fill();
    /* buik iets donkerder, rug een lichte glans */
    ctx.fillStyle = 'rgba(74,50,30,.10)';
    ctx.beginPath(); ctx.ellipse(-4, -42, 30, 7, 0, 0, 7); ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,.20)';
    ctx.beginPath(); ctx.ellipse(-8, -82, 24, 5.5, -0.10, 0, 7); ctx.fill();
    if (c.dapple) {
      ctx.fillStyle = 'rgba(160,172,196,.30)';
      for (var d = 0; d < 6; d++) {
        ctx.beginPath();
        ctx.arc(-30 + d * 12, -56 + (d % 3) * 9, 4.6 - (d % 2), 0, 7); ctx.fill();
      }
    }

    /* ---- zadeltassen (achter het zadel, over de flank) ---- */
    if (g.zadeltassen) {
      ctx.strokeStyle = '#8d5f38'; ctx.lineWidth = 4; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(-34, -82); ctx.lineTo(-12, -80); ctx.stroke();
      ctx.fillStyle = '#a9764a';
      rrect(ctx, -46, -74, 22, 27, 7); ctx.fill();
      ctx.fillStyle = '#c08c58';
      rrect(ctx, -40, -78, 24, 30, 8); ctx.fill();
      ctx.fillStyle = '#8d5f38';
      rrect(ctx, -40, -78, 24, 9, 4); ctx.fill();
      ctx.fillStyle = '#f2c14e';
      ctx.beginPath(); ctx.arc(-28, -68, 3, 0, 7); ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,.18)';
      rrect(ctx, -38, -76, 6, 26, 3); ctx.fill();
    }

    /* ---- zadel ---- */
    if (g.zadel) {
      ctx.fillStyle = '#f3ddba';
      ctx.beginPath();
      ctx.moveTo(-21, -80); ctx.quadraticCurveTo(-4, -93, 15, -80);
      ctx.quadraticCurveTo(7, -66, -6, -66); ctx.quadraticCurveTo(-17, -66, -21, -80);
      ctx.closePath(); ctx.fill();
      ctx.fillStyle = '#dcbb8b';
      rrect(ctx, -23, -83, 11, 9, 4); ctx.fill();
      ctx.strokeStyle = '#c9a97a'; ctx.lineWidth = 3;
      ctx.beginPath(); ctx.moveTo(-4, -71); ctx.lineTo(-2, -50); ctx.stroke();
      ctx.fillStyle = '#b98f5f';
      rrect(ctx, -7, -52, 8, 6, 2); ctx.fill();
    }

    /* ---- nek ---- */
    var ng = ctx.createLinearGradient(20, -110, 40, -60);
    ng.addColorStop(0, c.light); ng.addColorStop(1, c.body);
    ctx.fillStyle = ng;
    ctx.beginPath();
    ctx.moveTo(11, -74); ctx.quadraticCurveTo(29, -86, 42, -110);
    ctx.lineTo(64, -103); ctx.quadraticCurveTo(51, -73, 39, -54);
    ctx.quadraticCurveTo(23, -53, 11, -74);
    ctx.closePath(); ctx.fill();

    /* ---- manen: kam langs de nek met een schulprand die meedeint ---- */
    ctx.fillStyle = c.mane;
    ctx.beginPath();
    ctx.moveTo(11, -70);
    ctx.quadraticCurveTo(26, -94, 43, -116);
    ctx.lineTo(54, -111);
    ctx.quadraticCurveTo(37, -90, 24, -65);
    ctx.closePath(); ctx.fill();
    for (var m = 0; m <= 6; m++) {
      var u = m / 6, wob = Math.sin(ph * 1.2 - m * 0.6) * 1.8;
      ctx.beginPath();
      ctx.arc(13 + u * 33 - 2 + wob * 0.6, -65 - u * 48 + 3 + wob, 6.6 - u * 2.4, 0, 7);
      ctx.fill();
    }
    /* korte punten bij de schoft, blijven op de nek */
    ctx.strokeStyle = c.mane; ctx.lineCap = 'round';
    for (var mk = 0; mk < 3; mk++) {
      var fl = Math.sin(ph - mk * 0.7) * 2.6;
      ctx.lineWidth = 5 - mk;
      ctx.beginPath();
      ctx.moveTo(14 + mk * 4, -66 - mk * 6);
      ctx.quadraticCurveTo(8 + mk * 3, -60 - mk * 5 + fl, 5 + mk * 3, -54 - mk * 5 + fl);
      ctx.stroke();
    }
    if (g.hoofdstel) {
      for (var b = 0; b < 4; b++) {
        var bt = 0.14 + b * 0.24;
        ctx.fillStyle = b % 2 ? '#e58fa8' : '#f7c6d5';
        ctx.beginPath(); ctx.arc(14 + 33 * bt, -64 - 48 * bt, 3.7, 0, 7); ctx.fill();
        ctx.fillStyle = 'rgba(255,255,255,.6)';
        ctx.beginPath(); ctx.arc(13 + 33 * bt, -65.5 - 48 * bt, 1.3, 0, 7); ctx.fill();
      }
    }

    /* ---- hoofd ---- */
    ctx.save();
    ctx.translate(57, -112); ctx.rotate(0.42 + nod);
    /* oren: afgeronde driehoekjes, af en toe een oorflik */
    var flick = Math.sin(T * 1.7) > 0.9 ? 0.20 : 0;
    function ear(ox, oy, tipx, tipy, w2, rot) {
      ctx.save(); ctx.translate(ox, oy); ctx.rotate(rot);
      ctx.fillStyle = c.body;
      ctx.beginPath();
      ctx.moveTo(-w2, 0);
      ctx.quadraticCurveTo(tipx - 3, tipy + 3, tipx, tipy);
      ctx.quadraticCurveTo(tipx + 4, tipy + 4, w2, 1);
      ctx.quadraticCurveTo(0, 3, -w2, 0);
      ctx.closePath(); ctx.fill();
      ctx.fillStyle = 'rgba(120,70,60,.26)';
      ctx.beginPath();
      ctx.moveTo(-w2 * 0.45, -0.5);
      ctx.quadraticCurveTo(tipx * 0.6, tipy * 0.6, tipx * 0.35, tipy * 0.72);
      ctx.quadraticCurveTo(w2 * 0.5, tipy * 0.25, w2 * 0.5, 0);
      ctx.closePath(); ctx.fill();
      ctx.restore();
    }
    ear(-11, -9, -5, -15, 6, flick);
    ear(-1, -11, -1.5, -15, 5.6, 0);
    /* schedel + snuit */
    var hg = ctx.createLinearGradient(0, -12, 6, 12);
    hg.addColorStop(0, c.light); hg.addColorStop(1, c.body);
    ctx.fillStyle = hg;
    ctx.beginPath(); ctx.ellipse(0, 0, 21, 13.5, 0, 0, 7); ctx.fill();
    ctx.beginPath(); ctx.ellipse(18, 5, 10.5, 8.5, 0.3, 0, 7); ctx.fill();
    /* wang-blos + neusgat */
    ctx.fillStyle = 'rgba(230,140,160,.20)';
    ctx.beginPath(); ctx.arc(6, 5, 5.5, 0, 7); ctx.fill();
    ctx.fillStyle = c.dark;
    ctx.beginPath(); ctx.ellipse(23, 8, 2.7, 3.5, 0.3, 0, 7); ctx.fill();
    /* voorlok tussen de oren */
    ctx.strokeStyle = c.mane; ctx.lineWidth = 4.5; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(-10, -10);
    ctx.quadraticCurveTo(-2, -14 + Math.sin(ph) * 1.5, 4, -6); ctx.stroke();
    /* oog, knippert af en toe */
    if ((T % 4.4) < 0.13) {
      ctx.strokeStyle = '#3a3140'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(-1.5, -2); ctx.lineTo(5, -2.6); ctx.stroke();
    } else {
      ctx.fillStyle = '#fff';
      ctx.beginPath(); ctx.ellipse(2, -2, 4.4, 4, 0, 0, 7); ctx.fill();
      ctx.fillStyle = '#3a3140';
      ctx.beginPath(); ctx.arc(2.6, -2, 3.1, 0, 7); ctx.fill();
      ctx.fillStyle = '#fff';
      ctx.beginPath(); ctx.arc(3.6, -3.3, 1.3, 0, 7); ctx.fill();
    }
    if (g.hoofdstel) {
      ctx.strokeStyle = '#e58fa8'; ctx.lineWidth = 3.4; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(-9, -4); ctx.lineTo(13, 2); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(8, -6); ctx.quadraticCurveTo(11, 6, 7, 13); ctx.stroke();
      ctx.fillStyle = '#f7c6d5';
      ctx.beginPath(); ctx.arc(9, 3, 3.8, 0, 7); ctx.fill();
    }
    ctx.restore();

    /* ---- benen aan deze kant (vóór de romp) ---- */
    leg(ctx, 25, -54, ph + 0.3, c.body, c.hoof, g);
    leg(ctx, -16, -56, ph + Math.PI, c.body, c.hoof, g);

    ctx.restore();
  }

  /* Zachte bol-vorm voor struiken, wolken en boomkronen */
  function bush(ctx, x, y, w, h, col) {
    ctx.fillStyle = col;
    ctx.beginPath();
    ctx.ellipse(x, y, w * 0.5, h * 0.5, 0, 0, 7);
    ctx.ellipse(x - w * 0.3, y + h * 0.15, w * 0.34, h * 0.36, 0, 0, 7);
    ctx.ellipse(x + w * 0.3, y + h * 0.15, w * 0.34, h * 0.36, 0, 0, 7);
    ctx.fill();
  }

  function tree(ctx, x, groundY, sc, sway) {
    var sw = sway || 0;
    ctx.fillStyle = '#a9805a';
    ctx.beginPath();
    ctx.moveTo(x - 6 * sc, groundY);
    ctx.quadraticCurveTo(x - 3 * sc, groundY - 30 * sc, x - 3 * sc + sw, groundY - 56 * sc);
    ctx.lineTo(x + 3.5 * sc + sw, groundY - 56 * sc);
    ctx.quadraticCurveTo(x + 3.5 * sc, groundY - 30 * sc, x + 6 * sc, groundY);
    ctx.closePath(); ctx.fill();
    ctx.fillStyle = '#8a6644';
    ctx.beginPath(); ctx.ellipse(x, groundY - 1 * sc, 12 * sc, 3.4 * sc, 0, 0, 7); ctx.fill();
    bush(ctx, x + sw, groundY - 70 * sc, 78 * sc, 64 * sc, '#79bd8d');
    bush(ctx, x + sw + 9 * sc, groundY - 86 * sc, 54 * sc, 46 * sc, '#96d3a6');
    bush(ctx, x + sw - 14 * sc, groundY - 88 * sc, 34 * sc, 30 * sc, '#a8ddb6');
    ctx.fillStyle = 'rgba(255,255,255,.28)';
    ctx.beginPath(); ctx.ellipse(x + sw + 12 * sc, groundY - 96 * sc, 15 * sc, 8 * sc, -0.4, 0, 7); ctx.fill();
  }

  /* Munt die om haar as tolt (spin = radialen). r = straal. */
  function coin(ctx, x, y, r, spin) {
    var w = Math.abs(Math.cos(spin)) * r * 0.86 + r * 0.14;
    ctx.save(); ctx.translate(x, y);
    var gl = ctx.createRadialGradient(0, 0, r * 0.4, 0, 0, r * 2.1);
    gl.addColorStop(0, 'rgba(255,231,150,.50)'); gl.addColorStop(1, 'rgba(255,231,150,0)');
    ctx.fillStyle = gl;
    ctx.beginPath(); ctx.arc(0, 0, r * 2.1, 0, 7); ctx.fill();
    ctx.fillStyle = '#c9922a';
    ctx.beginPath(); ctx.ellipse(0, 0, w, r, 0, 0, 7); ctx.fill();
    var f = ctx.createLinearGradient(-w, -r, w, r);
    f.addColorStop(0, '#fff5d0'); f.addColorStop(0.48, '#f6cd5f'); f.addColorStop(1, '#dfa72c');
    ctx.fillStyle = f;
    ctx.beginPath(); ctx.ellipse(0, 0, w * 0.8, r * 0.8, 0, 0, 7); ctx.fill();
    if (w > r * 0.5) {
      ctx.strokeStyle = 'rgba(180,130,25,.75)';
      ctx.lineWidth = r * 0.17; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.arc(0, r * 0.04, r * 0.38, Math.PI * 0.78, Math.PI * 0.22); ctx.stroke();
    }
    ctx.fillStyle = 'rgba(255,255,255,.6)';
    ctx.beginPath(); ctx.ellipse(-w * 0.36, -r * 0.4, w * 0.2, r * 0.2, -0.5, 0, 7); ctx.fill();
    ctx.restore();
  }

  function apple(ctx, x, y, r, t) {
    ctx.save(); ctx.translate(x, y); ctx.rotate(Math.sin(t) * 0.09);
    ctx.fillStyle = '#dd505a';
    ctx.beginPath();
    ctx.moveTo(0, -r * 0.72);
    ctx.bezierCurveTo(-r * 1.18, -r * 1.02, -r * 1.14, r * 0.58, 0, r * 0.96);
    ctx.bezierCurveTo(r * 1.14, r * 0.58, r * 1.18, -r * 1.02, 0, -r * 0.72);
    ctx.fill();
    ctx.fillStyle = 'rgba(150,32,44,.30)';
    ctx.beginPath();
    ctx.moveTo(r * 0.1, -r * 0.72);
    ctx.bezierCurveTo(r * 1.14, -r * 1.0, r * 1.14, r * 0.58, r * 0.05, r * 0.94);
    ctx.bezierCurveTo(r * 0.6, r * 0.4, r * 0.66, -r * 0.3, r * 0.1, -r * 0.72);
    ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,.55)';
    ctx.beginPath(); ctx.ellipse(-r * 0.42, -r * 0.26, r * 0.19, r * 0.32, -0.5, 0, 7); ctx.fill();
    ctx.strokeStyle = '#8a5a34'; ctx.lineWidth = r * 0.17; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(0, -r * 0.66);
    ctx.quadraticCurveTo(r * 0.12, -r * 1.1, r * 0.06, -r * 1.28); ctx.stroke();
    ctx.fillStyle = '#7cc08a';
    ctx.beginPath(); ctx.ellipse(r * 0.44, -r * 1.06, r * 0.38, r * 0.19, -0.45, 0, 7); ctx.fill();
    ctx.restore();
  }

  /* Vierpuntige twinkel voor pak-effectjes */
  function star(ctx, x, y, r, col) {
    ctx.fillStyle = col;
    ctx.beginPath();
    ctx.moveTo(x, y - r);
    ctx.quadraticCurveTo(x + r * 0.22, y - r * 0.22, x + r, y);
    ctx.quadraticCurveTo(x + r * 0.22, y + r * 0.22, x, y + r);
    ctx.quadraticCurveTo(x - r * 0.22, y + r * 0.22, x - r, y);
    ctx.quadraticCurveTo(x - r * 0.22, y - r * 0.22, x, y - r);
    ctx.fill();
  }

  global.Art = {
    COATS: COATS, drawHorse: drawHorse, rrect: rrect, bush: bush,
    tree: tree, coin: coin, apple: apple, star: star
  };
})(window);
