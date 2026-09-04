/* =====================================================================
   SND - HET GELUIDSMAATJE VAN DE KWISPELSTEEG
   Alle geluiden maken we zelf met WebAudio: er zijn geen bestandjes nodig.
   Hier bestaan geen boze geluiden, alleen zachte. Geluid uit? Tik rechts
   bovenop de speakerknop, dat onthouden we voor de volgende keer.
===================================================================== */
var Snd = (function () {
  var SLEUTEL = 'kws-geluid';
  var ctx = null, meester = null, demp = false;
  /* Vóór de eerste aanraking bestaat er GEEN geluidsband.
     Een browser mag een AudioContext niet laten spelen voordat het kind iets
     heeft aangeraakt; maakte je hem toch al aan (het hotel opent met Snd.deur),
     dan zette Chrome een waarschuwing in de console en stond de band daarna
     "suspended" te wachten. Dus: tot de eerste tik doet Snd gewoon niets.
     Dat scheelt ook batterij op een telefoon die alleen even kijkt. */
  var los = false;

  try { demp = localStorage.getItem(SLEUTEL) === '0'; } catch (e) { demp = false; }

  function band() {
    if (demp || !los) return null;
    if (!ctx) {
      var A = window.AudioContext || window.webkitAudioContext;
      if (!A) return null;
      try {
        ctx = new A();
        meester = ctx.createGain();
        meester.gain.value = 0.16;           /* altijd zacht, nooit hard */
        meester.connect(ctx.destination);
      } catch (e) { ctx = null; return null; }
    }
    return ctx;
  }

  /* Doe iets MET de band, maar alleen als hij echt loopt. Staat hij stil
     (net ontgrendeld, of net terug uit de achtergrond), dan wachten we tot
     resume() klaar is en spelen we daarna - nooit in het niets. */
  function metBand(fn) {
    var c = band(); if (!c) return;
    if (c.state === 'running') { fn(c); return; }
    if (!c.resume) return;
    try {
      var p = c.resume();
      if (p && p.then) p.then(function () { if (c.state === 'running') fn(c); }, function () {});
      else if (c.state === 'running') fn(c);
    } catch (e) { /* geeft niet: dan blijft het even stil */ }
  }

  /* De eerste echte aanraking maakt de band aan en wekt hem.
     Het lege sample van één tel is het trucje van iOS: zonder dat blijft een
     WebAudio-band daar soms stil tot de tweede tik. */
  function ontgrendel() {
    if (demp) return;
    if (!los) {
      los = true;
      var c = band();
      if (!c) return;
      try {
        var b = c.createBufferSource();
        b.buffer = c.createBuffer(1, 1, c.sampleRate);
        b.connect(c.destination);
        b.start(0);
      } catch (e) { /* geeft niet */ }
    }
    if (ctx && ctx.state !== 'running' && ctx.resume) { try { ctx.resume(); } catch (e) {} }
  }
  /* pointerdown dekt vinger, pen en muis; touchend is het net op oudere iOS.
     De haak blijft staan: hij wekt de band ook weer als de telefoon terugkomt
     uit de achtergrond. */
  if (window.addEventListener) {
    window.addEventListener('pointerdown', ontgrendel, true);
    window.addEventListener('touchend', ontgrendel, true);
    document.addEventListener('visibilitychange', function () {
      if (document.visibilityState !== 'hidden') return;
      if (ctx && ctx.state === 'running' && ctx.suspend) { try { ctx.suspend(); } catch (e) {} }
    });
  }

  /* één zachte toon, glijdt van f naar to (optioneel), met zachte start */
  function noot(f, to, duur, vorm, top, wacht) {
    metBand(function (c) {
    var t = c.currentTime + (wacht || 0);
    var o = c.createOscillator(), g = c.createGain();
    o.type = vorm || 'sine';
    o.frequency.setValueAtTime(f, t);
    if (to && to !== f) o.frequency.exponentialRampToValueAtTime(Math.max(40, to), t + duur);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(top || 0.4, t + Math.min(0.035, duur * 0.3));
    g.gain.exponentialRampToValueAtTime(0.0001, t + duur);
    o.connect(g); g.connect(meester);
    o.start(t); o.stop(t + duur + 0.03);
    });
  }

  /* ritselend papier: korte ruis door een filter */
  function papier(duur, freq, top, wacht) {
    metBand(function (c) {
    var t = c.currentTime + (wacht || 0);
    var n = Math.max(16, Math.floor(c.sampleRate * duur));
    var buf = c.createBuffer(1, n, c.sampleRate);
    var d = buf.getChannelData(0);
    for (var i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / n);
    var b = c.createBufferSource(); b.buffer = buf;
    var f = c.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = freq; f.Q.value = 0.7;
    var g = c.createGain(); g.gain.value = top;
    b.connect(f); f.connect(g); g.connect(meester);
    b.start(t);
    });
  }

  var A = {
    /* zacht tikje op een knop */
    tik: function () { noot(720, 620, 0.07, 'sine', 0.30); },
    /* koekje valt in een bakje: een vollere hand klinkt iets hoger */
    plop: function (hand) { noot(480 + 40 * (hand || 0), 190, 0.13, 'sine', 0.5); },
    /* een koekje rolt terug de zak in */
    terug: function () { noot(300, 460, 0.09, 'sine', 0.28); },
    /* dat is het nog niet - zacht meedenken, nooit een nee-geluid */
    zacht: function () { noot(430, 0, 0.15, 'sine', 0.30); noot(340, 0, 0.22, 'sine', 0.26, 0.13); },
    /* dat klopt! twee vrolijke toontjes */
    ja: function () { noot(660, 0, 0.10, 'triangle', 0.42); noot(880, 0, 0.16, 'triangle', 0.42, 0.09); },
    /* eerlijk verdeeld of een vriend die jou uitkiest: kleine magie */
    tover: function () {
      var n = [523, 659, 784, 1047], i;
      for (i = 0; i < n.length; i++) noot(n[i], 0, i === 3 ? 0.5 : 0.11, 'triangle', 0.34, i * 0.08);
    },
    /* goedemorgen, een nieuwe dag in de steeg */
    dag: function () { noot(587, 0, 0.12, 'sine', 0.26); noot(784, 0, 0.22, 'sine', 0.24, 0.11); },
    /* een brief door de brievenbus */
    brief: function () { papier(0.16, 1100, 0.5); papier(0.10, 700, 0.4, 0.10); noot(660, 0, 0.12, 'sine', 0.22, 0.16); },
    /* hoera! adoptiedag en het grote einde */
    hoera: function () {
      var n = [523, 659, 784, 1047], i;
      for (i = 0; i < n.length; i++) noot(n[i], 0, 0.14, 'triangle', 0.40, i * 0.13);
      noot(1047, 0, 0.55, 'triangle', 0.34, 0.52);
      noot(1319, 0, 0.55, 'sine', 0.22, 0.52);
    },
    /* de bel op de balie: helder, kort, nooit hard */
    bel: function () { noot(1046, 0, 0.34, 'sine', 0.42); noot(1568, 0, 0.28, 'sine', 0.20, 0.04); },
    /* een deur die opengaat en weer dichtvalt */
    deur: function () { noot(250, 190, 0.11, 'sine', 0.26); papier(0.09, 520, 0.22, 0.06); },
    /* de voerkar rolt over de gang */
    kar: function () { papier(0.24, 300, 0.26); noot(170, 210, 0.22, 'sine', 0.16); },
    /* een munt op de toonbank */
    munt: function () { noot(1180, 0, 0.07, 'triangle', 0.34); noot(1560, 0, 0.10, 'sine', 0.20, 0.05); },
    /* een sterretje erbij */
    ster: function () { noot(784, 0, 0.09, 'triangle', 0.30); noot(988, 0, 0.09, 'triangle', 0.28, 0.07);
                        noot(1319, 0, 0.20, 'sine', 0.24, 0.14); },
    /* een dier glijdt het zwembad in: een plons met wat spetters */
    plons: function () { noot(560, 150, 0.14, 'sine', 0.40); papier(0.20, 1500, 0.28, 0.03);
                         papier(0.13, 800, 0.16, 0.10); },
    /* zachte bots tegen de wand: een klein "au", nooit een schrikgeluid.
       Hier wordt niemand gestraft, dus blijft het laag, kort en rond. */
    au: function () { noot(240, 180, 0.09, 'sine', 0.26); noot(430, 350, 0.16, 'sine', 0.20, 0.06); },
    /* de halklok slaat een keer: een zachte gong die nog even naklinkt */
    klok: function () { noot(659, 0, 0.55, 'sine', 0.36); noot(988, 0, 0.40, 'sine', 0.16, 0.02); },
    /* hup, een sprongetje naar de volgende steen */
    hup: function () { noot(430, 720, 0.08, 'sine', 0.30); },
    /* staat het geluid uit? */
    dempt: function () { return demp; },
    /* is de geluidsband al door een echte aanraking wakker gemaakt?
       (voor de testsuites en voor een spel dat wil weten of het zin heeft) */
    ontgrendeld: function () { return los; },
    /* speakerknop: aan of uit, onthouden voor de volgende keer */
    schakel: function () {
      demp = !demp;
      try { localStorage.setItem(SLEUTEL, demp ? '0' : '1'); } catch (e) {}
      if (!demp) { ontgrendel(); A.tik(); }
      return demp;
    }
  };
  return A;
})();
