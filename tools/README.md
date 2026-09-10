# tools/ — the commands CI runs, runnable by hand

Five helpers around the Godot project in `godot/dierenhotel/`. Every step of
`.github/workflows/test.yml` and `.github/workflows/pages.yml` is one of these
scripts, so a red CI run is reproduced locally with the same single command —
and a change to the command is made in one place.

Run them from anywhere; each resolves the repository root from its own path.

| script | what it does | architecture.md |
|---|---|---|
| `tools/import.sh` | headless import pass, gates on engine ERROR lines | §7.3, §14.1 |
| `tools/test.sh` | the headless test suite (wraps the project's own runner) | §2.4, §14.3 |
| `tools/export.sh` | release web export, gates on engine ERROR lines | §7.3, §14.2 |
| `tools/serve.sh` | plain static server for the exported build | §14.4 |
| `tools/probe.js` | chromium/swiftshader browser probe, per viewport | §14.4 |

## Prerequisites

* **Godot 4.7.2-stable** on `PATH` as `godot` (toolchain.md §1), or `GODOT=/path/to/godot`.
* Export templates in `~/.local/share/godot/export_templates/4.7.2.stable/`
  (`web_nothreads_release.zip` is the only one the Web preset needs).
* `python3` for `serve.sh`; `node` + Playwright for `probe.js`.

## The three commands

```bash
tools/import.sh          # godot --headless --import --path godot/dierenhotel
tools/test.sh            # godot --headless --path godot/dierenhotel --script res://tests/run_tests.gd
tools/export.sh          # godot --headless --path … --export-release "Web" build/web/index.html
```

All three exit non-zero on failure **and** on any `^(USER )?(SCRIPT )?ERROR:`
line in the engine output. That second gate is the point: a GDScript runtime
error inside a test aborts the test function quietly, so an exit code alone
would report a green suite for a test that never reached its assertions
(architecture.md §2.4).

`tools/test.sh` deliberately does not duplicate the suite: it calls
`godot/dierenhotel/tools/test.sh`, which owns the runner and its stderr gate,
so the developer, CI and the project all run one implementation.

`tools/export.sh` creates `build/web` first (Godot refuses to create it —
toolchain.md gotcha G1) and keeps `build/.gdignore` in place (without it the
next import pass imports the exported PNGs back into the project — G2). It
takes an optional target: `tools/export.sh /tmp/elders/index.html`.
`index.service.worker.js` carries a timestamped `CACHE_VERSION` and is the one
artefact that is never byte-identical between two exports — never checksum-gate
it (G3). After a successful export it also copies `fonts/OFL-*.txt` next to
`index.html`, so the licences of the bundled fonts are readable on the deployed
site as well as inside the pck (`include_filter="fonts/*.txt"`); `pages.yml`
refuses to publish a build without them.

Environment: `GODOT` (which binary), `PRESET` (default `Web`), `DH_LOG_DIR`
(where the `import.log` / `export.log` land, default
`${TMPDIR:-/tmp}/dierenhotel-log`).

## Looking at the build in a browser

```bash
tools/serve.sh                 # http://127.0.0.1:8642/index.html, ctrl-c stops
tools/serve.sh 9000            # another port (or POORT=9000)
node tools/probe.js            # both iPad profiles against 127.0.0.1:8642
```

`serve.sh` is `python3 -m http.server` on the loopback: no compression and no
COOP/COEP headers, exactly what GitHub Pages gives. That is enough because the
Web preset has `variant/thread_support=false` (architecture.md §7.2). Note that
the 39.5 MB `index.wasm` is served uncompressed here, where Pages sends the
10.1 MB gzip.

`probe.js` loads the build in headless chromium with
`--enable-unsafe-swiftshader --use-gl=angle --use-angle=swiftshader`, without
which the canvas never initialises in headless mode (toolchain.md gotcha G4).
Per profile it walks the shell's lifecycle with a **finger**, taking a
screenshot at every step and writing `rapport.json`.

| step | what it proves | the line it reads |
|---|---|---|
| `boot` | engine and shell came up | `[probe] klaar` |
| `hotel` | the hotel is on screen with buttons | `[probe] kamers=`, `[probe] knop <id>=` |
| `tik` | one finger tap = **exactly one** press | `[probe] tik=<n> id=<id>`, `n ≥ 1` |
| `kaart` | that press opened a card, sheet or game | `spel=` / `vb_som=` / `bladknop`, or the tap is swallowed |
| `herlaad` | the page reloads and boots again | a second `[probe] klaar` |
| `blad` | the start sheet is up, so a save survived | `[probe] bladknop <id>=`, else a tap on the world is swallowed |
| `verder` | the sheet's button gives the hotel back | the world answers a tap again |

The step names come from the shell's own lines, which `scenes/main.gd` owns; the
probe follows them and never assumes a rect it was not told about — world buttons
come from `[probe] knop <id>=`, the buttons of an open sheet from
`[probe] bladknop <id>=`. Only when a sheet reports no buttons at all does
`verder` fall back to a bounded scan down the middle of the frame, with every
candidate confirmed by tapping the world again (`--geen-scan` turns that off).

```bash
node tools/probe.js --viewport 360x740@3:telefoon --viewport 1024x768@2
node tools/probe.js http://127.0.0.1:9000/index.html --uit /tmp/shots
node tools/probe.js --eis boot,hotel,tik,kaart      # only these steps gate
node tools/probe.js --eis geen                      # only the hard gates
node tools/probe.js --help
```

| option | meaning |
|---|---|
| `--viewport BxH[@dpr][:naam]` | repeatable; default `1024x768@2:ipad-land` and `768x1024@2:ipad-port` |
| `--uit MAP` | screenshots + `rapport.json` (default `$DH_LOG_DIR/probe`) |
| `--eis LIJST` | which steps must pass, out of `boot,hotel,tik,kaart,herlaad,blad,verder`; `geen` disables all |
| `--knop ID` | tap this hotspot instead of the first one that answers |
| `--wacht MS` | how long to wait for `[probe] klaar` (default 30000) |
| `--geen-scan` | do not hunt for the start sheet's button |
| `--geen-touch` | mouse profile instead of a touch screen |
| `--zichtbaar` | chromium with a window, for debugging |
| `--playwright PAD` | directory of the Playwright module (or `PLAYWRIGHT_PAD`) |

Always checked, whatever `--eis` says: zero console errors, zero page errors,
zero failed requests, a canvas with a non-zero backing store, the Godot engine
banner, no `krap` placement (`[probe] hits=`), and never more than one press per
finger tap. A boot line reads `[probe] tik=0` without an `id=`, so it can never
be mistaken for a press — the `tik` step only counts lines that carry `id=` and
appeared **after** the tap.

Playwright is not vendored in this repository. `probe.js` uses, in order:
`--playwright <map>` / `PLAYWRIGHT_PAD`, a local `playwright` module, and
finally `/home/pc/work/ergomouse/node_modules/playwright` (v1.60.0), the copy
the toolchain and A1 probes were verified against.

## What CI does with them

`.github/workflows/test.yml` (every push and pull request) installs Godot
4.7.2-stable from the release page — SHA-512 checked against the sums pinned in
the workflow, cached per version — then runs `tools/import.sh`, `tools/test.sh`
and `tools/export.sh`, and uploads `godot/dierenhotel/build/web` plus the logs
as artifacts.

`.github/workflows/pages.yml` (push to `main`, or manually via
**Actions ▸ pages ▸ Run workflow**) first calls `test.yml` as a reusable
workflow, and only if that whole workflow is green does it import, export and
publish the build with `upload-pages-artifact` + `deploy-pages`. A red suite can
therefore never reach the deployment.

> **One-time setting, by hand, by the owner:** *Settings ▸ Pages ▸ Build and
> deployment ▸ Source = "GitHub Actions"*. Until that is set the build succeeds
> and the deploy step fails with "Get Pages site failed".

Both workflows strip the 2.0 GiB template set down to `web_nothreads_*` +
`version.txt` (20 MB) before caching it (toolchain.md G6); an export from that
stripped set was verified to produce the same 15 files, byte for byte in size,
as an export from the full set.

The browser probe is deliberately **not** in CI: it needs a Playwright browser
download on the runner. Run it locally before a release, or add a step that
installs `playwright` and calls `node tools/probe.js` after `tools/serve.sh`.
