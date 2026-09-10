/* X4 prototype: exporteer de WebAudio-geluiden van snd.js naar WAV via
   koploos chromium + OfflineAudioContext. snd.js wordt niet aangeraakt. */
const { chromium } = require('/home/pc/work/ergomouse/node_modules/playwright');
const fs = require('fs'), path = require('path');
const OUT = '/tmp/dh-snd';
const NAMEN = ['tik','plop','terug','zacht','ja','tover','dag','brief','hoera','bel',
               'deur','kar','munt','ster','plons','au','klok','hup'];

(async () => {
  const b = await chromium.launch();
  const p = await b.newPage();
  p.on('pageerror', e => console.log('PAGEERROR', e.message));
  const meta = [];
  for (const naam of NAMEN) {
    await p.goto('file:///tmp/dh-snd/probe.html');
    const r = await p.evaluate(async (naam) => {
      window.dispatchEvent(new Event('pointerdown'));   /* ontgrendelt de band */
      if (!Snd.ontgrendeld()) return { fout: 'niet ontgrendeld' };
      Snd[naam]();
      const buf = await window.__offline.startRendering();
      const d = buf.getChannelData(0);
      /* meet: piek en waar het geluid echt ophoudt (< -60 dBFS) */
      let piek = 0, eind = 0;
      for (let i = 0; i < d.length; i++) { const a = Math.abs(d[i]); if (a > piek) piek = a; if (a > 0.001) eind = i; }
      /* 16-bits PCM mono WAV */
      const n = d.length, ab = new ArrayBuffer(44 + n * 2), dv = new DataView(ab);
      const s = (o, t) => { for (let i = 0; i < t.length; i++) dv.setUint8(o + i, t.charCodeAt(i)); };
      s(0, 'RIFF'); dv.setUint32(4, 36 + n * 2, true); s(8, 'WAVEfmt ');
      dv.setUint32(16, 16, true); dv.setUint16(20, 1, true); dv.setUint16(22, 1, true);
      dv.setUint32(24, buf.sampleRate, true); dv.setUint32(28, buf.sampleRate * 2, true);
      dv.setUint16(32, 2, true); dv.setUint16(34, 16, true); s(36, 'data'); dv.setUint32(40, n * 2, true);
      for (let i = 0; i < n; i++) { let v = Math.max(-1, Math.min(1, d[i])); dv.setInt16(44 + i * 2, v < 0 ? v * 0x8000 : v * 0x7FFF, true); }
      let bin = '', u8 = new Uint8Array(ab);
      for (let i = 0; i < u8.length; i++) bin += String.fromCharCode(u8[i]);
      return { piek: piek, eindMs: Math.round(eind / buf.sampleRate * 1000), sr: buf.sampleRate, wav: btoa(bin) };
    }, naam);
    if (r.fout) { console.log(naam, 'FOUT', r.fout); continue; }
    const buf = Buffer.from(r.wav, 'base64');
    fs.writeFileSync(path.join(OUT, naam + '.wav'), buf);
    meta.push({ naam, piek: +r.piek.toFixed(4), dBFS: +(20 * Math.log10(r.piek || 1e-9)).toFixed(1), duurMs: r.eindMs, sr: r.sr, bytes: buf.length });
    console.log(naam.padEnd(7), 'piek', r.piek.toFixed(4), '(' + (20 * Math.log10(r.piek || 1e-9)).toFixed(1) + ' dBFS)', 'duur', r.eindMs + ' ms', buf.length + ' B');
  }
  fs.writeFileSync(path.join(OUT, 'meta.json'), JSON.stringify(meta, null, 1));
  await b.close();
})().catch(e => { console.log('ERR', e.stack); process.exit(1); });
