#!/usr/bin/env node
// tools/kiek.js — one screenshot of one room of the exported web build, in one
// command.  "Kiek" is a snapshot.
//
// It serves build/web itself (or uses --url), seeds a save through the shell's
// own `index.html?opslag=<base64url JSON>` hook (scenes/main.gd, I2) so the
// camera starts in the room you ask for, waits for "[probe] klaar", presses
// "Verder spelen", and writes PNGs.  Optionally it then taps one hotspot
// (`--tik spel_zwembad`) and takes a third picture.  Same chromium/swiftshader
// flags and the same `[probe]` lines as tools/probe.js (architecture.md §14.4).
//
//   node tools/kiek.js --kamer zwembad
//   node tools/kiek.js --kamer zwembad --tik spel_zwembad --wacht 4000
//   node tools/kiek.js --kamer tuin --band 4 --viewport 360x740@3:telefoon
//
// Needs a fresh export first: tools/export.sh (about 60–90 s).  The script
// refuses to run when build/web/index.html is missing and warns when it is
// older than the newest .gd file.
//
// Output (default /tmp/dierenhotel-log/kiek/): <profiel>-1-blad.png (start
// sheet), <profiel>-2-<kamer>.png (the room), <profiel>-3-<tik>.png (after the
// tap), log.txt (every console line).  The last stdout line is "KIEK OK" or
// "KIEK FOUT: <reason>"; exit code 0 only on OK.
'use strict';
const fs = require('fs');
const path = require('path');
const http = require('http');

const REPO = path.resolve(__dirname, '..');
const BUILD = path.join(REPO, 'godot', 'dierenhotel', 'build', 'web');

function hulp() {
  console.log(`gebruik: node tools/kiek.js [opties]

  --kamer ID          receptie | gang | kamer1 | kamer2 | keuken | tuin | zwembad | wasserij | speelzaal | kas  (standaard receptie)
  --tik HOTSPOT       tik deze hotspot aan na aankomst (bv. spel_zwembad, bel, prikbord) en maak nog een foto
  --chip NAAM         tik een chip van de kamerbalk aan (kaart = de plattegrond, of een kamer-id) en maak nog een foto
  --wacht MS          wachttijd na de tik voor de derde foto (standaard 2500)
  --band 3|4|5        aantal gasten/kunnen dat die band oplevert (standaard 3)
  --gasten N          eigen gastenaantal (overschrijft --band; max 7)
  --dag N             dagnummer in de opslag (standaard 1)
  --kleding           kleed elke gast aan uit de winkelstraat (een vaste set per gast)
  --uit MAP           uitvoermap (standaard $DH_LOG_DIR/kiek of /tmp/dierenhotel-log/kiek)
  --viewport BxH[@dpr][:naam]   standaard 1024x768@2:ipad-land
  --url URL           bestaande server gebruiken in plaats van build/web zelf te serveren
  --playwright PAD    map van de playwright-module`);
}

// ---------------------------------------------------------------- argumenten
const argv = process.argv.slice(2);
const opt = {
  kamer: 'receptie', tik: null, chip: null, wacht: 2500, band: 3, gasten: null, dag: 1, kleding: false,
  uit: path.join(process.env.DH_LOG_DIR || '/tmp/dierenhotel-log', 'kiek'),
  viewport: '1024x768@2:ipad-land', url: null,
  playwright: process.env.PLAYWRIGHT_PAD || null,
};
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  const v = () => argv[++i];
  if (a === '--help' || a === '-h') { hulp(); process.exit(0); }
  else if (a === '--kamer') opt.kamer = v();
  else if (a === '--tik') opt.tik = v();
  else if (a === '--chip') opt.chip = v();
  else if (a === '--wacht') opt.wacht = parseInt(v(), 10);
  else if (a === '--band') opt.band = parseInt(v(), 10);
  else if (a === '--gasten') opt.gasten = parseInt(v(), 10);
  else if (a === '--dag') opt.dag = parseInt(v(), 10);
  else if (a === '--kleding') opt.kleding = true;
  else if (a === '--uit') opt.uit = v();
  else if (a === '--viewport') opt.viewport = v();
  else if (a === '--url') opt.url = v();
  else if (a === '--playwright') opt.playwright = v();
  else { console.error(`onbekende optie: ${a}`); hulp(); process.exit(2); }
}
const vm = opt.viewport.match(/^(\d+)x(\d+)(?:@([\d.]+))?(?::(.+))?$/);
if (!vm) { console.error(`FOUT: viewport "${opt.viewport}" moet BxH[@dpr][:naam] zijn`); process.exit(2); }
const PROFIEL = { naam: vm[4] || `${vm[1]}x${vm[2]}`, viewport: { width: +vm[1], height: +vm[2] }, dsf: vm[3] ? +vm[3] : 2 };

function laadChromium() {
  const kandidaten = [];
  if (opt.playwright) kandidaten.push(opt.playwright);
  kandidaten.push('playwright', '/home/pc/work/ergomouse/node_modules/playwright');
  for (const k of kandidaten) {
    try { return require(k).chromium; } catch (e) { /* volgende */ }
  }
  console.error(`KIEK FOUT: playwright niet gevonden (gezocht: ${kandidaten.join(', ')})`);
  process.exit(2);
}

// ---------------------------------------------------------------- de opslag
// The same shape .fanout/scratch/godot-g-zwembad/probe-zwembad.js proved
// against the real build: one save, `kamerNu` puts the camera in the room.
const POOL = [
  ['boef', 'Boef', 'hond', 'puppy', 2], ['muis', 'Muis', 'poes', 'poes', 1],
  ['wolkje', 'Wolkje', 'konijn', 'konijn', 1], ['gerrit', 'Gerrit', 'gans', 'gans', 2],
  ['pip', 'Pip', 'hond', 'puppy', 3], ['vlok', 'Vlok', 'poes', 'poes', 2],
  ['stamp', 'Stampertje', 'konijn', 'konijn', 1],
];
const BEDDEN = [['kamer1', 'bed1'], ['kamer1', 'bed2'], ['kamer2', 'bed1'], ['kamer2', 'bed2']];
// `--kleding`: what each guest wears (ArtGasten.KLEDING, one piece per slot)
const KLEDING = [
  ['pet', 'sjaaltje', 'gympjes'], ['strohoed', 'parels'], ['strik', 'sokjes'],
  ['kroon', 'zonnebril', 'laarsjes'], ['hoedje', 'das'], ['streepsjaal', 'slofjes'],
  ['pet', 'zonnebril', 'bal'],
];

function maakOpslag() {
  const n = Math.min(7, opt.gasten != null ? opt.gasten : (opt.band === 3 ? 1 : (opt.band === 4 ? 4 : 7)));
  const kunnen = opt.band === 5 ? 5 : 3;
  const gasten = [];
  for (let i = 0; i < n; i++) {
    const [id, naam, kind, soort, scoops] = POOL[i];
    const bed = BEDDEN[i % BEDDEN.length];
    gasten.push({
      id, naam, name: naam, kind, soort, scoops, act: 'Wandeling', mins: 30,
      kamer: bed[0], bed: bed[1], waar: bed[0],
      nachten: 100, geslapen: 0, prijs: 1, betaald: 0, dagIn: 1,
      behoefte: i === 0 ? (opt.kamer === 'zwembad' ? 'zwemmen' : 'eten') : 'eten',
      blij: false, gegeten: false,
      accessoires: opt.kleding ? KLEDING[i % KLEDING.length] : [],
      kast: opt.kleding ? KLEDING[i % KLEDING.length] : [],
    });
  }
  const s = {
    dag: opt.dag, ronde: 'vrij', munten: 4, sterren: 0, band: opt.band, kunnen,
    signaal: [], gasten, wachtlijst: [], famIdx: 0,
    meubels: [], meubelNr: 0, taken: [], brieven: [],
    scoops: 40, levering: 4, snoeppot: 0,
    kar: null, spel: {}, gezien: {},
    kamerNu: opt.kamer, uitcheck: [], nieuweGast: null,
    checkin: null, rekening: null, geluid: true,
  };
  return JSON.stringify({ v: 1, s });
}
const base64url = (s) => Buffer.from(s, 'utf8').toString('base64')
  .replace(/\+/g, '-').replace(/\//g, '_');   // keep the '=' padding: Marshalls needs it

// ---------------------------------------------------------------- server
const MIME = {
  '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream', '.png': 'image/png', '.json': 'application/json',
  '.txt': 'text/plain', '.css': 'text/css',
};
function serveer() {
  return new Promise((klaar) => {
    const srv = http.createServer((req, res) => {
      const p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
      const f = path.join(BUILD, p === '/' ? 'index.html' : p);
      if (!f.startsWith(BUILD) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) {
        res.writeHead(404); res.end('niet gevonden'); return;
      }
      res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream' });
      fs.createReadStream(f).pipe(res);
    });
    srv.listen(0, '127.0.0.1', () => klaar({ srv, url: `http://127.0.0.1:${srv.address().port}/index.html` }));
  });
}

const RECHTHOEK = /\[P: \(([-\d.]+), ([-\d.]+)\), S: \(([-\d.]+), ([-\d.]+)\)\]/;
const midden = (l) => {
  const m = l.match(RECHTHOEK);
  return m ? { x: +m[1] + (+m[3]) / 2, y: +m[2] + (+m[4]) / 2 } : null;
};

(async () => {
  if (!fs.existsSync(path.join(BUILD, 'index.html'))) {
    console.log('KIEK FOUT: geen export in godot/dierenhotel/build/web — draai eerst tools/export.sh');
    process.exit(2);
  }
  // warn when the build is older than the newest script
  const bouw = fs.statSync(path.join(BUILD, 'index.html')).mtimeMs;
  let nieuwste = 0;
  const loop = (d) => {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      if (e.name.startsWith('.') || e.name === 'build') continue;
      const p = path.join(d, e.name);
      if (e.isDirectory()) loop(p);
      else if (e.name.endsWith('.gd')) nieuwste = Math.max(nieuwste, fs.statSync(p).mtimeMs);
    }
  };
  loop(path.join(REPO, 'godot', 'dierenhotel'));
  if (nieuwste > bouw) console.log('LET OP: de export is ouder dan de nieuwste .gd — draai tools/export.sh voor een actuele foto');

  fs.mkdirSync(opt.uit, { recursive: true });
  const chromium = laadChromium();
  let server = null;
  let url = opt.url;
  if (!url) { server = await serveer(); url = server.url; }

  const browser = await chromium.launch({
    headless: true,
    args: ['--enable-unsafe-swiftshader', '--use-gl=angle', '--use-angle=swiftshader'],
  });
  const ctx = await browser.newContext({
    viewport: PROFIEL.viewport, deviceScaleFactor: PROFIEL.dsf, hasTouch: true, isMobile: true,
  });
  const page = await ctx.newPage();
  const logs = [], errors = [];
  page.on('console', (m) => { logs.push(`${m.type()}: ${m.text()}`); if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  const wacht = async (test, ms) => {
    for (let i = 0; i * 250 < ms; i++) {
      const r = test();
      if (r) return r;
      await page.waitForTimeout(250);
    }
    return null;
  };
  const laatste = (sleutel) => [...logs].reverse().find((l) => l.includes(sleutel)) || null;
  const fotos = [];
  const foto = async (naam) => {
    const p = path.join(opt.uit, `${PROFIEL.naam}-${naam}.png`);
    await page.screenshot({ path: p });
    fotos.push(p);
  };
  const stop = async (reden) => {
    fs.writeFileSync(path.join(opt.uit, 'log.txt'), logs.join('\n'));
    await browser.close();
    if (server) server.srv.close();
    for (const f of fotos) console.log('foto: ' + f);
    if (errors.length) console.log(`console-fouten: ${errors.length} — eerste: ${errors[0]}`);
    console.log(reden ? `KIEK FOUT: ${reden}` : 'KIEK OK');
    process.exit(reden ? 1 : 0);
  };

  await page.goto(`${url}?opslag=${base64url(maakOpslag())}`, { waitUntil: 'load' });
  if (!await wacht(() => laatste('[probe] klaar'), 90000)) { await foto('0-geen-boot'); await stop('"[probe] klaar" bleef uit (log.txt)'); }
  if (!laatste('[probe] opslag_uit_url=')) console.log('LET OP: de opslag-hook meldde niets; de kamer is dan de receptie');
  await foto('1-blad');

  // "Verder spelen": the seeded day, in the room the save names
  const verder = laatste('[probe] bladknop Kverder=');
  if (verder) {
    const p = midden(verder);
    await page.touchscreen.tap(p.x, p.y);
    await page.waitForTimeout(2000);
  } else {
    console.log('LET OP: geen "Verder spelen"-knop gemeld; de foto toont wat er nu staat');
  }
  await foto(`2-${opt.kamer}`);
  const knoppen = [...new Set(logs.map((l) => (l.match(/\[probe\] knop (\S+)=/) || [])[1]).filter(Boolean))];
  console.log('hotspots gemeld: ' + (knoppen.join(' ') || 'geen'));

  if (opt.tik) {
    const regel = await wacht(() => laatste(`[probe] knop ${opt.tik}=`), 20000);
    if (!regel) await stop(`hotspot "${opt.tik}" is niet gemeld in deze kamer (wel: ${knoppen.join(' ') || 'geen'})`);
    const p = midden(regel);
    await page.touchscreen.tap(p.x, p.y);
    await page.waitForTimeout(opt.wacht);
    await foto(`3-${opt.tik}`);
  }
  if (opt.chip) {
    const regel = await wacht(() => laatste(`[probe] chip ${opt.chip}=`), 20000);
    if (!regel) await stop(`chip "${opt.chip}" is niet gemeld (kaart of een kamer-id)`);
    const p = midden(regel);
    await page.touchscreen.tap(p.x, p.y);
    await page.waitForTimeout(opt.wacht);
    await foto(`${opt.tik ? 4 : 3}-chip-${opt.chip}`);
  }
  await stop(null);
})().catch(async (e) => { console.log('KIEK FOUT: ' + e.message); process.exit(1); });
