#!/usr/bin/env node
// tools/speel.js — SPEEL het spel zelf, stap voor stap, en zie na elke tik wat
// er verandert.  Waar `kiek.js` één plaatje maakt, tikt dit gereedschap een
// hele reeks knoppen aan en schrijft na ELKE stap een foto plus de meldingen
// die het spel zelf doet.  Zo kun je als agent ondervinden waar een kind
// vastloopt in plaats van het te raden.
//
//   node tools/speel.js --kamer kamer1 --band 4 --toon
//   node tools/speel.js --kamer kamer1 --band 4 --doe "spel_bedden; wacht 2000; bd_som_keuze0"
//   node tools/speel.js --kamer gang --band 4 --doe "spel_wekker; wk_uur; wk_uur; wk_klaar" --uit tmp/speel
//
// `--toon` speelt niets: het komt de kamer binnen en drukt af wat er te tikken
// valt.  Begin daarmee; de id's uit die lijst zijn de stappen van `--doe`.
//
// Een stap is een knop-id (`bd_som_keuze0`), een chip van de kamerbalk
// (`chip:kaart`) of een pauze (`wacht 2500`).  Onbekende id's stoppen de reeks
// met een foutmelding én de lijst van wat er wél gemeld is — dat is zelf al een
// bevinding: een knop die je verwacht en die er niet is.
//
// Uitvoer (standaard $DH_LOG_DIR/speel of tmp/log/speel): per stap
// <profiel>-<nr>-<stap>.png, plus log.txt met elke consoleregel.  De laatste
// regel is "SPEEL OK" of "SPEEL FOUT: <reden>"; exitcode 0 alleen bij OK.
//
// Verse export nodig: tools/export.sh.  Zelfde chromium/swiftshader-vlaggen en
// dezelfde `[probe]`-regels als tools/kiek.js en tools/probe.js.
'use strict';
const fs = require('fs');
const path = require('path');
const http = require('http');

const REPO = path.resolve(__dirname, '..');
const BUILD = path.join(REPO, 'godot', 'dierenhotel', 'build', 'web');

function hulp() {
  console.log(`gebruik: node tools/speel.js [opties]

  --kamer ID          receptie | gang | kamer1 | kamer2 | keuken | tuin | zwembad | wasserij  (standaard receptie)
  --doe "a; b; c"     de reeks stappen: een knop-id, chip:<naam>,
                      "veeg chip:<naam> <dx>" (een vinger veegt de kamerbalk),
                      chroom:<naam> (Munt/Brieven/Geluid/Prikbord/Avond),
                      of "wacht <ms>"
  --toon              speel niets; meld alleen wat er in deze kamer te tikken valt
  --stap-wacht MS     wachttijd na elke tik voor de foto (standaard 1800)
  --band 3|4|5        aantal gasten/kunnen dat die band oplevert (standaard 3)
  --gasten N          eigen gastenaantal (overschrijft --band; max 7)
  --dag N             dagnummer in de opslag (standaard 1)
  --uit MAP           uitvoermap (standaard $DH_LOG_DIR/speel of tmp/log/speel)
  --viewport BxH[@dpr][:naam]   standaard 1024x768@2:ipad-land
  --url URL           bestaande server gebruiken in plaats van build/web zelf te serveren
  --playwright PAD    map van de playwright-module`);
}

// ---------------------------------------------------------------- argumenten
const argv = process.argv.slice(2);
const opt = {
  kamer: 'receptie', doe: '', toon: false, stapWacht: 1800,
  band: 3, gasten: null, dag: 1,
  uit: path.join(process.env.DH_LOG_DIR || path.join(REPO, 'tmp', 'log'), 'speel'),
  viewport: '1024x768@2:ipad-land', url: null,
  playwright: process.env.PLAYWRIGHT_PAD || null,
};
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  const v = () => argv[++i];
  if (a === '--help' || a === '-h') { hulp(); process.exit(0); }
  else if (a === '--kamer') opt.kamer = v();
  else if (a === '--doe') opt.doe = v();
  else if (a === '--toon') opt.toon = true;
  else if (a === '--stap-wacht') opt.stapWacht = parseInt(v(), 10);
  else if (a === '--band') opt.band = parseInt(v(), 10);
  else if (a === '--gasten') opt.gasten = parseInt(v(), 10);
  else if (a === '--dag') opt.dag = parseInt(v(), 10);
  else if (a === '--uit') opt.uit = v();
  else if (a === '--viewport') opt.viewport = v();
  else if (a === '--url') opt.url = v();
  else if (a === '--playwright') opt.playwright = v();
  else { console.error(`onbekende optie: ${a}`); hulp(); process.exit(2); }
}
const vm = opt.viewport.match(/^(\d+)x(\d+)(?:@([\d.]+))?(?::(.+))?$/);
if (!vm) { console.error(`FOUT: viewport "${opt.viewport}" moet BxH[@dpr][:naam] zijn`); process.exit(2); }
const PROFIEL = { naam: vm[4] || `${vm[1]}x${vm[2]}`, viewport: { width: +vm[1], height: +vm[2] }, dsf: vm[3] ? +vm[3] : 2 };
const STAPPEN = opt.doe.split(/[;,]/).map((s) => s.trim()).filter(Boolean);

function laadChromium() {
  const kandidaten = [];
  if (opt.playwright) kandidaten.push(opt.playwright);
  kandidaten.push('playwright', '/home/pc/work/ergomouse/node_modules/playwright');
  for (const k of kandidaten) {
    try { return require(k).chromium; } catch (e) { /* volgende */ }
  }
  console.error(`SPEEL FOUT: playwright niet gevonden (gezocht: ${kandidaten.join(', ')})`);
  process.exit(2);
}

// ---------------------------------------------------------------- de opslag
// Zelfde vorm als tools/kiek.js: één save, `kamerNu` zet de camera in de kamer.
const POOL = [
  ['boef', 'Boef', 'hond', 'puppy', 2], ['muis', 'Muis', 'poes', 'poes', 1],
  ['wolkje', 'Wolkje', 'konijn', 'konijn', 1], ['gerrit', 'Gerrit', 'gans', 'gans', 2],
  ['pip', 'Pip', 'hond', 'puppy', 3], ['vlok', 'Vlok', 'poes', 'poes', 2],
  ['stamp', 'Stampertje', 'konijn', 'konijn', 1],
];
const BEDDEN = [['kamer1', 'bed1'], ['kamer1', 'bed2'], ['kamer2', 'bed1'], ['kamer2', 'bed2']];
// Een gast na de vier vaste bedden krijgt een eigen bed: een gekocht bed in de
// save (`meubels`).  Waar het staat maakt niet uit: het spel zet elk bed van een
// slaapkamer op de eerstvolgende vrije bedplek (Rooms.meubel_zet).  Tot
// 2026-09-24 kreeg gast 5 weer bed1: twee dieren in één bed (zoals kiek.js).
function bedVan(i, meubels) {
  if (i < BEDDEN.length) return BEDDEN[i];
  const kamer = i % 2 === 0 ? 'kamer1' : 'kamer2';
  const id = `m${meubels.length + 1}_bed`;
  meubels.push({ id, kamer, type: 'bed', x: 57, z: 57, rot: 0, soort: 'bed' });
  return [kamer, id];
}

function maakOpslag() {
  const n = Math.min(7, opt.gasten != null ? opt.gasten : (opt.band === 3 ? 1 : (opt.band === 4 ? 4 : 7)));
  const kunnen = opt.band === 5 ? 5 : 3;
  const gasten = [];
  const meubels = [];
  for (let i = 0; i < n; i++) {
    const [id, naam, kind, soort, scoops] = POOL[i];
    const bed = bedVan(i, meubels);
    gasten.push({
      id, naam, name: naam, kind, soort, scoops, act: 'Wandeling', mins: 30,
      kamer: bed[0], bed: bed[1], waar: bed[0],
      nachten: 100, geslapen: 0, prijs: 1, betaald: 0, dagIn: 1,
      behoefte: i === 0 ? (opt.kamer === 'zwembad' ? 'zwemmen' : 'eten') : 'eten',
      blij: false, gegeten: false, accessoires: [],
    });
  }
  const s = {
    dag: opt.dag, ronde: 'vrij', munten: 4, sterren: 0, band: opt.band, kunnen,
    signaal: [], gasten, wachtlijst: [], famIdx: 0,
    meubels, meubelNr: meubels.length, taken: [], brieven: [],
    scoops: 40, levering: 4, snoeppot: 0,
    kar: null, spel: {}, gezien: {},
    kamerNu: opt.kamer, uitcheck: [], nieuweGast: null,
    checkin: null, rekening: null, geluid: true,
  };
  return JSON.stringify({ v: 1, s });
}
const base64url = (s) => Buffer.from(s, 'utf8').toString('base64')
  .replace(/\+/g, '-').replace(/\//g, '_');   // de '='-vulling blijft staan: Marshalls heeft hem nodig

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
    console.log('SPEEL FOUT: geen export in godot/dierenhotel/build/web — draai eerst tools/export.sh');
    process.exit(2);
  }
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
  if (nieuwste > bouw) console.log('LET OP: de export is ouder dan de nieuwste .gd — draai tools/export.sh voor een eerlijk spel');

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
    return p;
  };
  const stop = async (reden) => {
    fs.writeFileSync(path.join(opt.uit, 'log.txt'), logs.join('\n'));
    await browser.close();
    if (server) server.srv.close();
    console.log('');
    for (const f of fotos) console.log('foto: ' + f);
    console.log('log: ' + path.join(opt.uit, 'log.txt'));
    if (errors.length) console.log(`console-fouten: ${errors.length} — eerste: ${errors[0]}`);
    console.log(reden ? `SPEEL FOUT: ${reden}` : 'SPEEL OK');
    process.exit(reden ? 1 : 0);
  };

  // welke knoppen/chips staan er, en wat meldde het spel, sinds regel `vanaf`?
  const idsSinds = (vanaf, soort) => [...new Set(logs.slice(vanaf)
    .map((l) => (l.match(new RegExp(`\\[probe\\] ${soort} (\\S+)=`)) || [])[1]).filter(Boolean))];
  const meldingenSinds = (vanaf) => logs.slice(vanaf)
    .filter((l) => l.includes('[probe] ') && !/\[probe\] (knop|chip|bladknop) /.test(l))
    .map((l) => l.replace(/^[a-z]+: /, '').replace('[probe] ', '').trim());

  await page.goto(`${url}?opslag=${base64url(maakOpslag())}`, { waitUntil: 'load' });
  if (!await wacht(() => laatste('[probe] klaar'), 90000)) { await foto('0-geen-boot'); await stop('"[probe] klaar" bleef uit (log.txt)'); }
  await foto('1-blad');

  const verder = laatste('[probe] bladknop Kverder=');
  if (verder) {
    const p = midden(verder);
    await page.touchscreen.tap(p.x, p.y);
    await page.waitForTimeout(2000);
  } else {
    console.log('LET OP: geen "Verder spelen"-knop gemeld; het spel begint waar het staat');
  }
  let merk = logs.length;
  await foto(`2-${opt.kamer}`);

  console.log(`kamer ${opt.kamer}, band ${opt.band}`);
  console.log('te tikken: ' + (idsSinds(0, 'knop').join(' ') || 'geen'));
  const chips = idsSinds(0, 'chip');
  if (chips.length) console.log('chips: ' + chips.join(' '));

  if (opt.toon || STAPPEN.length === 0) {
    const m = meldingenSinds(0);
    if (m.length) console.log('meldingen:\n  ' + m.slice(-12).join('\n  '));
    if (!opt.toon) console.log('(geen --doe opgegeven; niets gespeeld)');
    await stop(null);
  }

  // ------------------------------------------------------------- spelen
  let nr = 2;
  for (const stap of STAPPEN) {
    nr++;
    const pauze = stap.match(/^wacht[:\s]+(\d+)$/i);
    if (pauze) {
      await page.waitForTimeout(parseInt(pauze[1], 10));
      console.log(`\nstap ${nr - 2}: wacht ${pauze[1]} ms`);
      await foto(`${nr}-wacht`);
      continue;
    }
    // `veeg chip:<naam> <dx>`: een echte vinger die vanaf die chip dx
    // eenheden opzij veegt (touchStart, tien touchMoves, touchEnd) — de
    // kamerbalk van een staande telefoon is één rij die je moet kunnen vegen
    // (eigenaar 2026-09-24).  Daarna meldt de balk zijn chips opnieuw.
    const veeg = stap.match(/^veeg\s+chip[:\s]+(\S+)\s+(-?\d+)$/i);
    if (veeg) {
      const regel = await wacht(() => laatste(`[probe] chip ${veeg[1]}=`), 8000);
      if (!regel) await stop(`stap ${nr - 2}: chip "${veeg[1]}" wordt niet gemeld`);
      const p0 = midden(regel);
      const dx = +veeg[2];
      const cdp = await page.context().newCDPSession(page);
      const punt = (x) => [{ x: Math.round(x), y: Math.round(p0.y), id: 1 }];
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: punt(p0.x) });
      for (let i = 1; i <= 10; i++) {
        await page.waitForTimeout(16);
        await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: punt(p0.x + dx * i / 10) });
      }
      await page.waitForTimeout(16);
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      await page.waitForTimeout(opt.stapWacht);
      const f = await foto(`${nr}-veeg-${veeg[1]}`);
      console.log(`\nstap ${nr - 2}: veeg vanaf chip ${veeg[1]} ${dx}  →  ${path.basename(f)}`);
      const m = meldingenSinds(merk);
      if (m.length) console.log('  meldingen:\n    ' + m.slice(-20).join('\n    '));
      merk = logs.length;
      continue;
    }
    const chip = stap.match(/^chip[:\s]+(\S+)$/i);
    // De chroomknoppen bovenin (Munt, Brieven, Geluid, Prikbord, Avond) melden
    // zich als `[probe] chroomknop <naam>=` en zijn géén hotspot, dus zonder
    // eigen stapsoort was de hele dagcyclus onbespeelbaar (eigenaarsvraag
    // 2026-09-22: "speel de lus, dag na dag").
    const chroom = stap.match(/^chroom[:\s]+(\S+)$/i);
    const soort = chip ? 'chip' : (chroom ? 'chroomknop' : 'knop');
    // Een strook meldt zichzelf als één rechthoek (bv. `bd_som_keuzes`), niet
    // als vier knoppen.  Met `id#2/4` tik je het tweede van vier vakjes erin,
    // met `id@0.5,0.8` op een eigen plek (breuk van breedte, hoogte).
    const kaal = chip ? chip[1] : (chroom ? chroom[1] : stap);
    const vak = kaal.match(/^([^#@]+)(?:#(\d+)\/(\d+))?(?:@([\d.]+),([\d.]+))?$/);
    const id = vak ? vak[1] : kaal;
    // Een hotspot meldt zich als `knop <id>=`, een chip als `chip <id>=`; een
    // strook of kaart meldt zich kaal als `<id>=[P: ...]`.  Alle drie mogen.
    const zoek = () => laatste(`[probe] ${soort} ${id}=`)
      || (chip ? null : (laatste(`[probe] bladknop ${id}=`) || laatste(`[probe] ${id}=`)));
    const regel = await wacht(zoek, 8000);
    if (!regel) {
      const nu = idsSinds(merk, soort);
      await foto(`${nr}-${id}-ONBEKEND`);
      await stop(`stap ${nr - 2} "${id}" is geen ${soort} die het spel nu meldt` +
        ` — wel gemeld sinds de vorige stap: ${nu.join(' ') || 'niets'}`);
    }
    let p = midden(regel);
    const rh = regel.match(RECHTHOEK);
    if (vak && vak[2] && rh) {            // id#k/n — het k-de van n vakjes
      const k = +vak[2], n = +vak[3];
      p = { x: +rh[1] + (+rh[3]) * (k - 0.5) / n, y: +rh[2] + (+rh[4]) / 2 };
    } else if (vak && vak[4] && rh) {     // id@x,y — eigen plek in de rechthoek
      p = { x: +rh[1] + (+rh[3]) * +vak[4], y: +rh[2] + (+rh[4]) * +vak[5] };
    }
    await page.touchscreen.tap(p.x, p.y);
    await page.waitForTimeout(opt.stapWacht);
    const f = await foto(`${nr}-${stap.replace(/[^\w.-]/g, '_')}`);
    const nieuw = idsSinds(merk, 'knop');
    const m = meldingenSinds(merk);
    console.log(`\nstap ${nr - 2}: tik ${id}  →  ${path.basename(f)}`);
    console.log('  knoppen: ' + (nieuw.join(' ') || 'niets nieuws gemeld'));
    if (m.length) console.log('  meldingen:\n    ' + m.slice(-8).join('\n    '));
    merk = logs.length;
  }
  await stop(null);
})().catch(async (e) => { console.log('SPEEL FOUT: ' + e.message); process.exit(1); });
