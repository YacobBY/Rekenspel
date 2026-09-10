/* X4 prototype: bak de voxelplaten van art.js/rooms.js uit in koploos
   chromium en schrijf ze weg als PNG. Read-only tegen de spelcode. */
const { chromium } = require('/home/pc/work/ergomouse/node_modules/playwright');
const fs = require('fs'), path = require('path');
const OUT = '/tmp/dh-art';

const POSES = ['rust','tril','hap1','hap2','blijA','blijB','sip','zwaai','kijk',
               'loopA','loopB','zit','zitsip','lig','snuif'];
const KINDS = ['hond','poes','konijn','gans'];
const DECOR = ['boom','hok','bed','prikbord','kar','tobbe','kist','plant','balie','mand','bal','zak','kast','lamp'];

(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1200, height: 900 } });
  p.on('pageerror', e => console.log('PAGEERROR', e.message));
  await p.goto('file:///tmp/dh-art/probe.html');

  const werk = await p.evaluate(({ POSES, KINDS, DECOR }) => {
    const uit = [];
    const K = Art.kit;
    function bewaar(naam, plaat, extra) {
      uit.push(Object.assign({
        naam, w: plaat.cv.width, h: plaat.cv.height,
        dx: plaat.dx, dy: plaat.dy,
        png: plaat.cv.toDataURL('image/png')
      }, extra || {}));
    }
    /* 1. alle houdingen van de hond op g = 4 */
    POSES.forEach(po => bewaar('gast_hond_' + po + '_g4', K.dier('hond', po, 4), { soort: 'gast', kind: 'hond', pose: po, g: 4 }));
    /* 2. elke soort in rust op g = 4, plus de hond op g = 2 en 3 */
    KINDS.forEach(k => bewaar('gast_' + k + '_rust_g4', K.dier(k, 'rust', 4), { soort: 'gast', kind: k, pose: 'rust', g: 4 }));
    /* 2b. W4-F1: de andere drie soorten ook liggend en lopend op g = 4.
       (Er is GEEN houding 'zwem': art.js kent 15 houdingen en zwemmen is er
       geen van; een zwemmer houdt zijn houding en krijgt er in world.js een
       waterband overheen - zie art-sound-rules.md 11.5.) */
    ['poes', 'konijn', 'gans'].forEach(k =>
      ['lig', 'loopA', 'loopB'].forEach(po =>
        bewaar('gast_' + k + '_' + po + '_g4', K.dier(k, po, 4), { soort: 'gast', kind: k, pose: po, g: 4 })));
    [2, 3, 5].forEach(g => bewaar('gast_hond_rust_g' + g, K.dier('hond', 'rust', g), { soort: 'gast', kind: 'hond', pose: 'rust', g: g }));
    /* 3. accessoires */
    ['hoedje', 'sjaaltje', 'bal', 'hoedje,sjaaltje,bal'].forEach(a =>
      bewaar('gast_hond_rust_g4_' + a.replace(/,/g, '+'), K.dier('hond', 'rust', 4, a), { soort: 'gast_tooi', acc: a, g: 4 }));
    /* 4. het voerbakje, achter- en voorwand apart, per niveau */
    for (let n = 0; n <= 4; n++) {
      bewaar('kom_n' + n + '_achter_g4', K.kom(n, 4, 0), { soort: 'kom', niveau: n, deel: 'achter', g: 4 });
      bewaar('kom_n' + n + '_voor_g4', K.kom(n, 4, 1), { soort: 'kom', niveau: n, deel: 'voor', g: 4 });
    }
    /* 5. decor uit rooms.js op g = 2 (de tuinschaal) en g = 4 */
    DECOR.forEach(n => {
      [2, 4].forEach(g => bewaar('decor_' + n + '_g' + g, K.plaat(K.bake(Rooms.model(n)), g), { soort: 'decor', model: n, g: g }));
    });
    return { CW: Art.size()[0], CH: Art.size()[1], stats: Art.stats(), items: uit };
  }, { POSES, KINDS, DECOR });

  const meta = [];
  for (const it of werk.items) {
    const buf = Buffer.from(it.png.split(',')[1], 'base64');
    fs.writeFileSync(path.join(OUT, it.naam + '.png'), buf);
    meta.push({ naam: it.naam, w: it.w, h: it.h, dx: it.dx, dy: it.dy, bytes: buf.length,
                soort: it.soort, kind: it.kind, pose: it.pose, g: it.g, model: it.model,
                niveau: it.niveau, deel: it.deel, acc: it.acc });
  }

  /* trouwtest: is de PNG pixel voor pixel gelijk aan de plaat in de motor? */
  const trouw = await p.evaluate(async () => {
    const K = Art.kit;
    async function check(plaat, url) {
      const im = new Image();
      await new Promise((ok, mis) => { im.onload = ok; im.onerror = mis; im.src = url; });
      const c = document.createElement('canvas');
      c.width = plaat.cv.width; c.height = plaat.cv.height;
      const x = c.getContext('2d'); x.drawImage(im, 0, 0);
      const a = plaat.cv.getContext('2d').getImageData(0, 0, c.width, c.height).data;
      const bb = x.getImageData(0, 0, c.width, c.height).data;
      let anders = 0, max = 0;
      for (let i = 0; i < a.length; i++) { const d = Math.abs(a[i] - bb[i]); if (d) { anders++; if (d > max) max = d; } }
      return { px: c.width * c.height, anders, max };
    }
    const p1 = K.dier('hond', 'rust', 4);
    const p2 = K.plaat(K.bake(Rooms.model('boom')), 4);
    return {
      hond: await check(p1, p1.cv.toDataURL('image/png')),
      boom: await check(p2, p2.cv.toDataURL('image/png'))
    };
  });

  /* proefblad: de uitgebakken PNG's naast elkaar op de spelachtergrond */
  const namen = ['gast_hond_rust_g4','gast_poes_rust_g4','gast_konijn_rust_g4','gast_gans_rust_g4',
                 'gast_hond_hap2_g4','gast_hond_blijA_g4','gast_hond_lig_g4','gast_hond_sip_g4',
                 'gast_hond_rust_g4_hoedje+sjaaltje+bal','kom_n4_achter_g4',
                 'decor_boom_g4','decor_bed_g4','decor_kar_g4','decor_hok_g4','decor_prikbord_g4','decor_tobbe_g4'];
  const rijen = namen.map(n => `<figure><img src="file:///tmp/dh-art/${n}.png"><figcaption>${n}</figcaption></figure>`).join('');
  await p.setContent(`<body style="margin:0;background:radial-gradient(1200px 600px at 50% -10%,#FFE9D6,#FFF4E8);
    font:12px system-ui;color:#4A3B33">
    <div style="display:flex;flex-wrap:wrap;gap:10px;padding:12px;align-items:flex-end">${rijen}</div>
    <style>figure{margin:0;text-align:center}img{image-rendering:pixelated;display:block;margin:0 auto 3px}</style>
    </body>`);
  await p.waitForTimeout(300);
  await p.screenshot({ path: path.join(OUT, 'proefblad.png'), fullPage: true });

  fs.writeFileSync(path.join(OUT, 'meta.json'), JSON.stringify({ CW: werk.CW, CH: werk.CH, stats: werk.stats, trouw, platen: meta }, null, 1));
  console.log('platen:', meta.length, 'CW/CH:', werk.CW, werk.CH);
  console.log('trouw:', JSON.stringify(trouw));
  console.log('stats:', JSON.stringify(werk.stats.vlakken));
  await b.close();
})().catch(e => { console.log('ERR', e.stack); process.exit(1); });
