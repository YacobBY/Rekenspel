const { chromium } = require('/home/pc/work/ergomouse/node_modules/playwright');
const POSES = ['rust','tril','hap1','hap2','blijA','blijB','sip','zwaai','kijk','loopA','loopB','zit','zitsip','lig','snuif'];
const KINDS = ['hond','poes','konijn','gans'];
(async () => {
  const b = await chromium.launch(); const p = await b.newPage();
  await p.goto('file:///tmp/dh-art/probe.html');
  const r = await p.evaluate(({POSES,KINDS}) => {
    const K = Art.kit, uit = {};
    KINDS.forEach(k => { uit[k] = {}; POSES.forEach(po => {
      const pl = K.dier(k, po, 4);            /* g = 4, pad = 2 */
      uit[k][po] = { w: (pl.cv.width-4)/4, h: (pl.cv.height-4)/4, ox: (pl.dx+2)/4, oy: (pl.dy+2)/4 };
    }); });
    /* het bakje */
    const kom = {};
    for (let n=0;n<=4;n++) ['a','v'].forEach((d,i)=>{ const pl=K.kom(n,4,i);
      kom['n'+n+d] = { w:(pl.cv.width-4)/4, h:(pl.cv.height-4)/4, ox:(pl.dx+2)/4, oy:(pl.dy+2)/4 }; });
    return { uit, kom, CW: Art.size()[0], CH: Art.size()[1] };
  }, {POSES,KINDS});
  console.log('houding    ' + KINDS.map(k=>k.padEnd(22)).join(''));
  POSES.forEach(po => {
    console.log(po.padEnd(11) + KINDS.map(k => {
      const q = r.uit[k][po];
      return (q.w+'x'+q.h+' @'+q.ox+','+q.oy).padEnd(22);
    }).join(''));
  });
  console.log('\nvoerbakje (voxel-px, a=achter v=voor):');
  Object.keys(r.kom).forEach(k => { const q=r.kom[k]; console.log(' ', k.padEnd(5), q.w+'x'+q.h, '@'+q.ox+','+q.oy); });
  await b.close();
})().catch(e => { console.log('ERR', e.stack); process.exit(1); });
