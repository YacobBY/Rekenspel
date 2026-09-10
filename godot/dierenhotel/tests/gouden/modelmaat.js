const { chromium } = require('/home/pc/work/ergomouse/node_modules/playwright');
const NAMEN = ['boom','hok','hekx','hekz','tobbe','bal','kist','mat','poort','balie','baliez','bel',
               'kassa','boek','prikbord','sleutelbord','bed','bedz','mand','kast','kastz','zak','kar',
               'lamp','lampaan','plant','prikbordz','sleutelbordz','pol0','pol1','pol2','pol3','pol4'];
(async () => {
  const b = await chromium.launch(); const p = await b.newPage();
  await p.goto('file:///tmp/dh-art/probe.html');
  const r = await p.evaluate((NAMEN) => NAMEN.map(n => {
    const v = Rooms.model(n), B = [1e9,-1e9,1e9,-1e9,1e9,-1e9];
    v.forEach(q => { if(q[0]<B[0])B[0]=q[0]; if(q[0]>B[1])B[1]=q[0];
                     if(q[1]<B[2])B[2]=q[1]; if(q[1]>B[3])B[3]=q[1];
                     if(q[2]<B[4])B[4]=q[2]; if(q[2]>B[5])B[5]=q[2]; });
    const f = Art.kit.bake(v);
    return { n, vox: v.length, vlak: f.length,
             lxhxd: [B[1]-B[0]+1, B[3]-B[2]+1, B[5]-B[4]+1],
             x: [B[0],B[1]], y: [B[2],B[3]], z: [B[4],B[5]] };
  }), NAMEN);
  r.forEach(q => console.log(q.n.padEnd(14), 'l×h×d ' + String(q.lxhxd.join('×')).padEnd(11),
    'x ' + String(q.x.join('..')).padEnd(9), 'y ' + String(q.y.join('..')).padEnd(8),
    'z ' + String(q.z.join('..')).padEnd(9), 'vox ' + String(q.vox).padStart(5), 'vlak ' + q.vlak));
  await b.close();
})().catch(e => { console.log('ERR', e.stack); process.exit(1); });
