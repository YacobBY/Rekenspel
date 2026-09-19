---
name: dh-export
description: Build the web export, serve it and run the chromium probe exactly as CI does (tools/import.sh, export.sh, serve.sh, probe.js), and read their gates.
whenToUse: When the task mentions the web build, GitHub Pages, CI, the probe, index.html, or a change to project settings/export presets.
---

# Commands (repository root; all three gate on any engine `ERROR:` line)

| command | time | run as |
|---|---|---|
| `tools/import.sh` | ≈ 20 s | foreground |
| `tools/export.sh [target/index.html]` | 60–90 s | background job + `job_output wait` |
| `tools/serve.sh [port]` (default 8642) | — | background job; leave it running |
| `node tools/probe.js [url] --viewport 1024x768@2:ipad --knop bel --uit /tmp/probe` | ≈ 60 s per profile | background job |

Logs: `$DH_LOG_DIR` (default `/tmp/dierenhotel-log/`): `export.log`,
`import.log`, `probe/rapport.json` + PNGs. Set `DH_LOG_DIR=/tmp/ds` to keep
your run apart from others.

# Facts that cost time

- Export output: `godot/dierenhotel/build/web/` (41 MB, `index.wasm` 39.5 MB);
  `build/.gdignore` must stay; `index.service.worker.js` is never byte-identical.
- Godot needs `XDG_CONFIG_HOME=/tmp/godot-config` in the sandbox — the scripts
  set it. Never redirect `HOME`/`XDG_DATA_HOME` for an export (templates live in
  the real home: `~/.local/share/godot/export_templates/4.7.2.stable/`).
- Never export while the test suite runs (shared `.godot/` cache).
- Headless chromium needs the swiftshader flags — probe.js and kiek.js set
  them; Playwright module: `/home/pc/work/ergomouse/node_modules/playwright`.
- probe.js steps: boot → hotel → tik → kaart → herlaad → blad → verder; it
  reads the `[probe] ...` lines `scenes/main.gd` prints. `--eis geen` turns the
  step gates off; console errors, page errors and failed requests always fail.
- For a picture of a specific room or game use the `dh-screenshot` skill
  (`tools/kiek.js`), not probe.js.
- CI: `.github/workflows/test.yml` (import, suite, export) and `pages.yml`
  (deploy; needs Settings → Pages → Source = GitHub Actions).
