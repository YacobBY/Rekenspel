#!/usr/bin/env node
// tools/probe.js — the chromium/swiftshader browser probe of architecture.md §14.4,
// parameterised by viewport.
//
// Loads the exported web build in headless chromium (one context per profile) and
// walks the shell's own lifecycle, driven entirely by the `[probe]` lines that
// scenes/main.gd prints (W3 owns those names, this file follows them):
//
//   boot      the engine boots and the shell reports         -> "[probe] klaar"
//   hotel     the hotel is on screen and has buttons         -> "[probe] kamers=" + "[probe] knop <id>="
//   tik       one finger tap = exactly one press             -> "[probe] tik=<n> id=<id>", n >= 1
//   kaart     that press opened a card, sheet or game        -> "[probe] spel=" / "vb_som=" /
//                                                               "bladknop", or the tap is swallowed
//   herlaad   the page is reloaded and boots again           -> a second "[probe] klaar"
//   blad      the start sheet is up, so a save survived      -> "[probe] bladknop <id>=", else a
//                                                               tap on the world is swallowed
//   verder    pressing the sheet's button gives the hotel back -> the world answers a tap again
//
// Headless chromium needs --enable-unsafe-swiftshader --use-gl=angle
// --use-angle=swiftshader for WebGL 2, or the canvas never initialises
// (toolchain.md gotcha G4); the same flags apply on a GitHub Actions runner.
//
//   node tools/probe.js                                   # both iPad profiles
//   node tools/probe.js http://127.0.0.1:8642/index.html
//   node tools/probe.js --viewport 360x740@3:telefoon --viewport 1024x768@2
//   node tools/probe.js --eis boot,hotel,tik              # only these steps gate
//   node tools/probe.js --uit /tmp/probe-shots
//
// Exit code 0 only when every profile passes. Always checked, whatever --eis
// says: zero console errors, zero page errors, zero failed requests, a canvas
// with a non-zero backing store, the Godot engine banner, no `krap` placement,
// and never more than one press per finger tap.

'use strict';
const fs = require('fs');
const path = require('path');

const STANDAARD_URL = 'http://127.0.0.1:8642/index.html';
const STAPPEN = ['boot', 'hotel', 'tik', 'kaart', 'herlaad', 'blad', 'verder'];
// Buttons that are known to open something; the rest is tried in reported order.
const VOORKEUR = ['prikbord', 'bel'];

function hulp() {
  console.log(`gebruik: node tools/probe.js [url] [opties]

  --viewport BxH[@dpr][:naam]  herhaalbaar; standaard 1024x768@2:ipad-land en 768x1024@2:ipad-port
  --uit MAP                    screenshots + rapport.json (standaard $DH_LOG_DIR/probe)
  --eis LIJST                  welke stappen mogen falen: ${STAPPEN.join(',')}; "geen" zet ze uit
  --knop ID                    tik deze hotspot aan in plaats van de eerste die reageert
  --wacht MS                   maximale wachttijd op "[probe] klaar" (standaard 30000)
  --geen-scan                  zoek de knop van het startblad niet met een tastende scan
  --geen-touch                 muisprofiel in plaats van een aanraakscherm
  --zichtbaar                  chromium met venster (debuggen)
  --playwright PAD             map van de playwright-module`);
}

// ---------------------------------------------------------------- argumenten
const argv = process.argv.slice(2);
let url = null;
let uit = path.join(process.env.DH_LOG_DIR || path.join(process.env.TMPDIR || '/tmp', 'dierenhotel-log'), 'probe');
let wachtMs = 30000;
let eisTekst = STAPPEN.join(',');
let knopId = null;
let scan = true;
let touch = true;
let zichtbaar = false;
let pwPad = process.env.PLAYWRIGHT_PAD || null;
const viewportArgs = [];

for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  const volgende = () => {
    const v = argv[++i];
    if (v === undefined) { console.error(`FOUT: ${a} mist een waarde`); process.exit(2); }
    return v;
  };
  if (a === '--help' || a === '-h') { hulp(); process.exit(0); }
  else if (a === '--viewport') viewportArgs.push(volgende());
  else if (a === '--uit') uit = volgende();
  else if (a === '--eis') eisTekst = volgende();
  else if (a === '--knop') knopId = volgende();
  else if (a === '--wacht') wachtMs = parseInt(volgende(), 10);
  else if (a === '--geen-scan') scan = false;
  else if (a === '--geen-touch') touch = false;
  else if (a === '--zichtbaar') zichtbaar = true;
  else if (a === '--playwright') pwPad = volgende();
  else if (a.startsWith('--')) { console.error(`FOUT: onbekende optie ${a}`); hulp(); process.exit(2); }
  else if (url === null) url = a;
  else { console.error(`FOUT: te veel argumenten (${a})`); process.exit(2); }
}
url = url || process.env.DH_PROBE_URL || STANDAARD_URL;

const eisen = (eisTekst === 'geen' || eisTekst === '') ? [] : eisTekst.split(',').map(s => s.trim()).filter(Boolean);
for (const e of eisen) {
  if (!STAPPEN.includes(e)) { console.error(`FOUT: onbekende stap "${e}" (kies uit ${STAPPEN.join(',')})`); process.exit(2); }
}

function leesViewport(spec) {
  const m = spec.match(/^(\d+)x(\d+)(?:@([\d.]+))?(?::(.+))?$/);
  if (!m) { console.error(`FOUT: viewport "${spec}" moet BxH[@dpr][:naam] zijn`); process.exit(2); }
  const b = parseInt(m[1], 10), h = parseInt(m[2], 10);
  const dsf = m[3] ? parseFloat(m[3]) : 2;
  return { naam: m[4] || `${b}x${h}@${dsf}`, viewport: { width: b, height: h }, dsf: dsf };
}
const PROFIELEN = viewportArgs.length
  ? viewportArgs.map(leesViewport)
  : [leesViewport('1024x768@2:ipad-land'), leesViewport('768x1024@2:ipad-port')];

// ---------------------------------------------------------------- playwright
function laadChromium() {
  const kandidaten = [];
  if (pwPad) kandidaten.push(pwPad);
  kandidaten.push('playwright', '/home/pc/work/ergomouse/node_modules/playwright');
  for (const k of kandidaten) {
    try { return require(k).chromium; } catch (e) { /* volgende kandidaat */ }
  }
  console.error(`FOUT: playwright niet gevonden. Probeer --playwright <map> of PLAYWRIGHT_PAD=<map>.
       gezocht in: ${kandidaten.join(', ')}`);
  process.exit(2);
}

// ---------------------------------------------------------------- regels lezen
// Rect2 prints as "[P: (x, y), S: (w, h)]".
const RECHTHOEK = /\[P: \(([-\d.]+), ([-\d.]+)\), S: \(([-\d.]+), ([-\d.]+)\)\]/;
const KNOP = /\[probe\] knop (\S+)=\[P: \(([-\d.]+), ([-\d.]+)\), S: \(([-\d.]+), ([-\d.]+)\)\]/;
// A press always carries " id=", the boot line "[probe] tik=0" never does — that
// distinction is the whole point of the gate (R-W3W6 finding 2).
const TIK = /\[probe\] tik=(\d+) id=(\S+)/;
// The shell reports the buttons of an open sheet as "[probe] bladknop <id>=";
// that is what the start-sheet steps steer on, and it makes the scan a fallback.
const BLADKNOP = /\[probe\] bladknop ?(\S+)=\[P: \(([-\d.]+), ([-\d.]+)\), S: \(([-\d.]+), ([-\d.]+)\)\]/;

const laatste = (regels, sleutel) => [...regels].reverse().find(l => l.includes(sleutel)) || null;
const vlakVan = (regel) => {
  const m = regel && regel.match(RECHTHOEK);
  return m ? { x: +m[1], y: +m[2], w: +m[3], h: +m[4] } : null;
};
const midden = (v) => ({ x: v.x + v.w / 2, y: v.y + v.h / 2 });

function knoppenUit(regels) {
  const uitkomst = [];
  for (const l of regels) {
    const m = l.match(KNOP);
    if (m) uitkomst.push({ id: m[1], vlak: { x: +m[2], y: +m[3], w: +m[4], h: +m[5] } });
  }
  return uitkomst;
}
function bladknoppenUit(regels) {
  const uitkomst = [];
  for (const l of regels) {
    const m = l.match(BLADKNOP);
    if (m) uitkomst.push({ id: m[1], vlak: { x: +m[2], y: +m[3], w: +m[4], h: +m[5] } });
  }
  return uitkomst;
}
function opVoorkeur(knoppen) {
  const score = (k) => {
    const i = VOORKEUR.indexOf(k.id);
    return i < 0 ? VOORKEUR.length : i;
  };
  return [...knoppen].sort((a, b) => score(a) - score(b));
}

(async () => {
  const chromium = laadChromium();
  fs.mkdirSync(uit, { recursive: true });
  const browser = await chromium.launch({
    headless: !zichtbaar,
    args: ['--enable-unsafe-swiftshader', '--use-gl=angle', '--use-angle=swiftshader'],
  });
  const rapport = [];
  let stuk = 0;

  for (const p of PROFIELEN) {
    const ctx = await browser.newContext({
      viewport: p.viewport, deviceScaleFactor: p.dsf,
      hasTouch: touch, isMobile: touch,
    });
    const page = await ctx.newPage();
    const logs = [], errors = [], warnings = [], failed = [];
    page.on('console', m => {
      const t = m.type(), txt = m.text();
      logs.push(`${t}: ${txt}`);
      if (t === 'error') errors.push(txt);
      if (t === 'warning') warnings.push(txt);
    });
    page.on('pageerror', e => errors.push('pageerror: ' + e.message));
    page.on('requestfailed', r => failed.push(r.url() + ' ' + ((r.failure() || {}).errorText || '')));

    const stap = {};
    const zet = (naam, ok, reden) => { stap[naam] = { ok: ok, reden: reden }; };
    const wachtOpKlaar = async (vanaf) => {
      for (let i = 0; i * 250 < wachtMs; i++) {
        if (logs.slice(vanaf).some(l => l.includes('[probe] klaar'))) return true;
        await page.waitForTimeout(250);
      }
      return false;
    };
    // one tap, and everything the shell said about it
    const tikOp = async (punt, wacht = 1600) => {
      const n0 = logs.length;
      await page.touchscreen.tap(punt.x, punt.y);
      await page.waitForTimeout(wacht);
      const nieuw = logs.slice(n0);
      return { nieuw, tikken: nieuw.map(l => l.match(TIK)).filter(Boolean) };
    };

    // ---- boot -----------------------------------------------------------
    const t0 = Date.now();
    await page.goto(url, { waitUntil: 'load' });
    const klaar = await wachtOpKlaar(0);
    const bootMs = Date.now() - t0;
    const banner = logs.some(l => l.includes('Godot Engine v'));
    const canvas = await page.evaluate(() => {
      const c = document.querySelector('canvas');
      if (!c) return null;
      const r = c.getBoundingClientRect();
      return { w: c.width, h: c.height, cssW: Math.round(r.width), cssH: Math.round(r.height) };
    });
    await page.screenshot({ path: `${uit}/${p.naam}-1-boot.png` });
    zet('boot', klaar, klaar ? '' : '"[probe] klaar" bleef uit');

    // ---- hotel ----------------------------------------------------------
    const bootRegels = logs.filter(l => l.includes('[probe]'));
    const knoppen = knoppenUit(bootRegels);
    const kamers = laatste(bootRegels, '[probe] kamers=');
    zet('hotel', !!kamers && knoppen.length > 0,
      !kamers ? 'geen "[probe] kamers=" regel' : (knoppen.length ? '' : 'geen enkele "[probe] knop <id>=" regel'));

    const hits = laatste(bootRegels, '[probe] hits=') || '';
    const krap = (hits.match(/krap=(\d+)/) || [null, null])[1];
    const dekking = (hits.match(/dekking_max=([\d.]+)/) || [null, null])[1];

    // ---- tik: one finger, exactly one press -----------------------------
    let gekozen = null, tikRegel = null, eersteNieuw = [], pogingen = [];
    const kandidaten = knopId
      ? knoppen.filter(k => k.id === knopId)
      : opVoorkeur(knoppen);
    for (const k of kandidaten.slice(0, 5)) {
      const r = await tikOp(midden(k.vlak));
      pogingen.push(`${k.id}:${r.tikken.length}`);
      if (r.tikken.length >= 1) { gekozen = k; tikRegel = r.tikken; eersteNieuw = r.nieuw; break; }
    }
    await page.screenshot({ path: `${uit}/${p.naam}-2-na-tik.png` });
    if (!gekozen) {
      zet('tik', false, knopId ? `hotspot "${knopId}" reageerde niet` :
        `geen enkele hotspot reageerde (${pogingen.join(' ') || 'geen knoppen'})`);
    } else if (tikRegel.length !== 1) {
      zet('tik', false, `${tikRegel.length} tikregels na één tik op ${gekozen.id}`);
    } else if (parseInt(tikRegel[0][1], 10) < 1) {
      zet('tik', false, `tik=${tikRegel[0][1]} na de tik op ${gekozen.id}, verwacht >= 1`);
    } else {
      zet('tik', true, `${gekozen.id} -> tik=${tikRegel[0][1]}`);
    }

    // ---- kaart: did that press open a card, a sheet or a game? ----------
    // Positive evidence is a game/card line or a sheet reporting its buttons;
    // a tap that is suddenly swallowed also counts, because something took the
    // place of the button. Every hotspot is tried before this step gives up.
    const OPEN = /\[probe\] (spel=|vb_som=|kaart|bladknop)/;
    let kaartBewijs = eersteNieuw.filter(l => OPEN.test(l));
    if (!gekozen) {
      zet('kaart', false, 'geen tik gelukt, dus niets te openen');
    } else {
      const tweede = await tikOp(midden(gekozen.vlak), 1200);
      kaartBewijs = kaartBewijs.concat(tweede.nieuw.filter(l => OPEN.test(l)));
      let reden = '';
      if (kaartBewijs.length) reden = kaartBewijs[0].trim();
      else if (tweede.tikken.length === 0) reden = `tweede tik op ${gekozen.id} werd opgeslokt: er ligt iets overheen`;
      if (!reden) {
        // the first hotspot only counted presses: try the others
        const rest = kandidaten.filter(k => k.id !== gekozen.id).slice(0, 4);
        const geprobeerd = [gekozen.id];
        for (const k of rest) {
          geprobeerd.push(k.id);
          const r = await tikOp(midden(k.vlak), 1200);
          const bewijs = r.nieuw.filter(l => OPEN.test(l));
          if (bewijs.length) { reden = bewijs[0].trim(); break; }
          const weer = await tikOp(midden(k.vlak), 900);
          if (r.tikken.length >= 1 && weer.tikken.length === 0) {
            reden = `tweede tik op ${k.id} werd opgeslokt: er ligt iets overheen`;
            break;
          }
        }
        if (!reden) reden = `geen kaart, blad of spel na een tik op ${geprobeerd.join(', ')}`;
      }
      zet('kaart', !!reden && !reden.startsWith('geen kaart'), reden);
      await page.screenshot({ path: `${uit}/${p.naam}-3-kaart.png` });
    }

    // ---- herlaad --------------------------------------------------------
    const voorReload = logs.length;
    await page.reload({ waitUntil: 'load' });
    const klaar2 = await wachtOpKlaar(voorReload);
    await page.waitForTimeout(400);
    await page.screenshot({ path: `${uit}/${p.naam}-4-herlaad.png` });
    zet('herlaad', klaar2, klaar2 ? '' : 'na de herlaad kwam er geen tweede "[probe] klaar"');

    // ---- blad: the start sheet proves the save survived ------------------
    // world.md §6.2: the sheet only appears when State.lees() found a save, and
    // it is modal (`sluitbaar: false`), so a tap on the world is swallowed.
    const naRegels = logs.slice(voorReload).filter(l => l.includes('[probe]'));
    const knoppen2 = knoppenUit(naRegels);
    const bladknoppen = bladknoppenUit(naRegels);
    let wereldKnop = null;
    if (bladknoppen.length) {
      wereldKnop = knoppen2.length ? opVoorkeur(knoppen2)[0] : null;
      zet('blad', true, `het startblad meldt zijn knoppen: ${bladknoppen.map(k => k.id).join(', ')}`);
    } else if (!klaar2 || knoppen2.length === 0) {
      zet('blad', false, 'geen bootblok na de herlaad om tegen te tikken');
    } else {
      wereldKnop = opVoorkeur(knoppen2)[0];
      const r = await tikOp(midden(wereldKnop.vlak), 1200);
      if (r.tikken.length === 0) {
        zet('blad', true, `tik op ${wereldKnop.id} werd opgeslokt: er ligt een modaal blad overheen`);
      } else {
        zet('blad', false, `de wereld reageerde meteen op ${wereldKnop.id}: geen startblad, dus geen bewaarde stand`);
      }
    }

    // ---- verder: press the sheet's own button ---------------------------
    // The shell does not report the sheet's buttons, so the rect comes from a
    // "[probe] blad <id>=" line when W3 ever prints one, and otherwise from a
    // bounded scan down the middle of the frame. Each candidate is confirmed by
    // tapping the world again: the hotel answering is the proof.
    let verderPunt = null, verderPogingen = 0;
    if (!stap['blad'].ok) {
      zet('verder', false, 'geen blad om weg te tikken');
    } else if (bladknoppen.length && wereldKnop) {
      const doel = midden(bladknoppen[0].vlak);
      await page.touchscreen.tap(doel.x, doel.y);
      await page.waitForTimeout(900);
      const r = await tikOp(midden(wereldKnop.vlak), 1200);
      verderPunt = doel; verderPogingen = 1;
      zet('verder', r.tikken.length >= 1,
        r.tikken.length >= 1 ? `blad-knop ${bladknoppen[0].id}, daarna reageerde ${wereldKnop.id} weer`
          : `blad-knop ${bladknoppen[0].id} aangetikt, maar de wereld bleef stil`);
    } else if (!scan) {
      zet('verder', false, 'geen "[probe] blad <id>=" regel en --geen-scan');
    } else {
      // The sheet is centred horizontally but its height follows its content,
      // so the button row can sit anywhere between the title and the bottom:
      // walk the frame from the top down at two x positions — the left half of
      // a two-button row ("verder" is the first child) and the middle, which is
      // where a single button lands. Each candidate is confirmed by tapping the
      // world: only the hotel answering ends the scan.
      const b = p.viewport.width, h = p.viewport.height;
      const cx = Math.round(b / 2);
      const punten = [];
      for (let y = Math.round(h * 0.06); y <= Math.round(h * 0.80) && punten.length < 60; y += 24) {
        punten.push({ x: cx - Math.round(b * 0.08), y: y });
        punten.push({ x: cx, y: y });
      }
      for (const punt of punten) {
        verderPogingen++;
        await page.touchscreen.tap(punt.x, punt.y);
        await page.waitForTimeout(150);
        const r = await tikOp(midden(wereldKnop.vlak), 250);
        if (r.tikken.length >= 1) { verderPunt = punt; break; }
      }
      zet('verder', !!verderPunt, verderPunt
        ? `blad weggetikt op (${verderPunt.x}, ${verderPunt.y}) na ${verderPogingen} pogingen, ${wereldKnop.id} reageerde weer`
        : `${verderPogingen} kandidaatpunten aangetikt, het blad ging niet weg`);
    }
    await page.screenshot({ path: `${uit}/${p.naam}-5-verder.png` });

    // ---- gates ----------------------------------------------------------
    const klachten = [];
    if (errors.length) klachten.push(`${errors.length} consolefout(en)`);
    if (failed.length) klachten.push(`${failed.length} mislukte request(s)`);
    if (!banner) klachten.push('geen Godot-banner in de console');
    if (!canvas || canvas.w === 0 || canvas.h === 0) klachten.push('geen getekend canvas');
    if (krap !== null && krap !== '0') klachten.push(`krap=${krap} (een knop vond geen vrije plek)`);
    for (const e of eisen) {
      if (!stap[e]) klachten.push(`stap ${e} niet uitgevoerd`);
      else if (!stap[e].ok) klachten.push(`stap ${e}: ${stap[e].reden}`);
    }
    if (klachten.length) stuk++;

    rapport.push({
      profiel: p.naam, url, viewport: p.viewport, dsf: p.dsf, touch,
      bootMs, canvas, banner, errors, warnings: warnings.length, failed,
      krap, dekking_max: dekking, stap, eisen, klachten,
      tik_knop: gekozen ? gekozen.id : null, tik_pogingen: pogingen,
      verder_punt: verderPunt, verder_pogingen: verderPogingen,
      probe: logs.filter(l => l.includes('[probe]')),
    });
    await ctx.close();
  }
  await browser.close();

  fs.writeFileSync(`${uit}/rapport.json`, JSON.stringify(rapport, null, 2));
  for (const r of rapport) {
    const c = r.canvas || { w: 0, h: 0, cssW: 0, cssH: 0 };
    const stappen = STAPPEN.map(s => {
      const t = r.stap[s];
      return `${s}${!t ? '–' : (t.ok ? '✓' : '✗')}`;
    }).join(' ');
    console.log(`--- ${r.profiel} ${r.viewport.width}x${r.viewport.height}@${r.dsf}`
      + ` boot=${r.bootMs}ms canvas=${c.w}x${c.h} css=${c.cssW}x${c.cssH}`
      + ` fouten=${r.errors.length} waarschuwingen=${r.warnings} mislukt=${r.failed.length}`
      + ` krap=${r.krap} dekking_max=${r.dekking_max}`);
    console.log(`    stappen: ${stappen}`);
    for (const s of STAPPEN) if (r.stap[s] && r.stap[s].reden) console.log(`      ${s}: ${r.stap[s].reden}`);
    r.errors.slice(0, 5).forEach(l => console.log('    FOUT ' + l));
    r.failed.slice(0, 5).forEach(l => console.log('    MISLUKT ' + l));
    r.klachten.forEach(l => console.log('    KLACHT ' + l));
  }
  console.log(`rapport: ${uit}/rapport.json`);
  console.log(stuk === 0 ? 'PROBE OK' : `PROBE STUK (${stuk})`);
  process.exit(stuk === 0 ? 0 : 1);
})().catch(e => { console.error('PROBE STUK: ' + (e && e.stack || e)); process.exit(1); });
