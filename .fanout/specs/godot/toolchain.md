# Godot 4.7.2 web toolchain — install, headless export, browser proof

Written after a full end-to-end run on this machine (no sudo, no system packages) on
2026-09-09. Everything below was executed and verified; sizes and timings are measured,
not estimated. Probe project: `/tmp/godot-probe/project` (throwaway, outside the repo).

---

## 1. What was installed, from where

| Component | Version | Source URL | Download size |
|---|---|---|---|
| Godot editor (standard, **not** .NET/mono) | `4.7.2.stable.official.ed1daf0bf` | `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip` | 77,860,424 B |
| Export templates (all platforms) | 4.7.2.stable | `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz` | 1,281,349,702 B |
| Checksums | — | `https://github.com/godotengine/godot/releases/download/4.7.2-stable/SHA512-SUMS.txt` | 5,682 B |
| GitHub CLI | `2.100.0` (2026-09-03) | `https://github.com/cli/cli/releases/download/v2.100.0/gh_2.100.0_linux_amd64.tar.gz` | 15,152,253 B |

Both Godot downloads were verified with `sha512sum -c` against the release
`SHA512-SUMS.txt`; `gh` was verified with `sha256sum -c` against
`gh_2.100.0_checksums.txt`. All three reported `OK`.

### Install paths (this machine)

```
~/.local/opt/godot/Godot_v4.7.2-stable_linux.x86_64     # 146,414,384 B, chmod +x
~/.local/bin/godot -> ../opt/godot/Godot_v4.7.2-stable_linux.x86_64   # symlink, on PATH
~/.local/bin/gh                                          # real binary, copied out of the tarball
~/.local/share/godot/export_templates/4.7.2.stable/      # 35 files, 2.0 GiB on disk
```

The template directory name **must** be exactly `4.7.2.stable` (it is matched against
`Engine.get_version_info()`); the `.tpz` is a plain zip whose contents live under
`templates/`, so the install is "unzip, then rename `templates` to `<version>.stable`".
`~/.local/share/godot/export_templates/<version>/version.txt` contains `4.7.2.stable`.

### Exact install commands (reproducible, non-interactive)

```bash
set -euo pipefail
GODOT_VER=4.7.2-stable
BASE=https://github.com/godotengine/godot/releases/download/$GODOT_VER
mkdir -p ~/.local/opt/godot ~/.local/bin ~/.local/share/godot/export_templates /tmp/godot-dl
cd /tmp/godot-dl

curl -sSL -O "$BASE/SHA512-SUMS.txt"
curl -sSL --retry 3 -O "$BASE/Godot_v${GODOT_VER}_linux.x86_64.zip"
curl -sSL --retry 3 -O "$BASE/Godot_v${GODOT_VER}_export_templates.tpz"
sha512sum -c <(grep -E 'linux\.x86_64\.zip|export_templates\.tpz' SHA512-SUMS.txt | grep -v mono)

unzip -o -q "Godot_v${GODOT_VER}_linux.x86_64.zip" -d ~/.local/opt/godot/
chmod +x ~/.local/opt/godot/Godot_v${GODOT_VER}_linux.x86_64
ln -sfn ~/.local/opt/godot/Godot_v${GODOT_VER}_linux.x86_64 ~/.local/bin/godot

unzip -q "Godot_v${GODOT_VER}_export_templates.tpz" -d /tmp/godot-dl/tpl
rm -rf ~/.local/share/godot/export_templates/4.7.2.stable
mv /tmp/godot-dl/tpl/templates ~/.local/share/godot/export_templates/4.7.2.stable

godot --headless --version    # -> 4.7.2.stable.official.ed1daf0bf
```

GitHub CLI:

```bash
curl -sSL -O https://github.com/cli/cli/releases/download/v2.100.0/gh_2.100.0_linux_amd64.tar.gz
curl -sSL -O https://github.com/cli/cli/releases/download/v2.100.0/gh_2.100.0_checksums.txt
sha256sum -c <(grep linux_amd64.tar.gz gh_2.100.0_checksums.txt)
mkdir -p /tmp/gh && tar -xzf gh_2.100.0_linux_amd64.tar.gz -C /tmp/gh --strip-components=1
install -m 0755 /tmp/gh/bin/gh ~/.local/bin/gh    # single static binary; share/ is docs+completions only
gh --version    # -> gh version 2.100.0 (2026-09-03)
```

`gh auth status` currently prints **"You are not logged into any GitHub hosts"** — no
credentials on this machine. Not logged in by this task, as instructed. Anything that
needs the API (PR creation, release upload) must first get `gh auth login` from the user
or a `GH_TOKEN` in the environment.

---

## 2. The two commands that matter

```bash
# 1. import pass — populates .godot/, imports every asset, exits 0
godot --headless --import --path /abs/path/to/project

# 2. export pass — release web build
mkdir -p /abs/path/to/project/build/web            # REQUIRED, see gotcha G1
godot --headless --path /abs/path/to/project \
      --export-release "Web" build/web/index.html
```

Notes learned by running them:

* `--import` on a brand-new project (no `.godot/`) succeeded **on the first invocation**
  on 4.7.2; there was no need to run it twice, and no need for a virtual X server. Output
  is the `first_scan_filesystem` / `loading_editor_layout` progress lines, exit code 0.
* `godot --headless --editor --quit --path <proj>` is the older recipe and also works on
  4.7.2 (creates `.godot/`, exports afterwards cleanly). `--import` is preferred: it is
  narrower and does not load the editor layout.
* On 4.7.2 the export command **re-imports on its own** — exporting a fresh project that
  contains an un-imported PNG worked without a prior `--import` (it printed a `reimport`
  progress block and packed the imported texture). Keep the explicit import step anyway:
  it makes CI failures attributable to import vs. export, and it is what the docs assume.
* The `<path>` argument of `--export-release` is relative to the project directory (or
  absolute). The preset name is matched case-sensitively against `export_presets.cfg`.
* Exit codes are honest: 0 on success, 1 on any export configuration error, so
  `set -e` in CI is enough. Errors go to stderr with an `ERROR:` prefix.

Runtime on this machine (Ryzen-class desktop, warm page cache): import ≈ 1 s,
export ≈ 2.4 s wall clock for the probe project.

---

## 3. `export_presets.cfg` — the full Web preset

This file is written by hand (Godot only rewrites it from the GUI). It lives next to
`project.godot`. Verbatim, exactly what produced the verified build:

```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/web/index.html"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
texture_format/s3tc_bptc=false
texture_format/etc2_astc=true
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=true
progressive_web_app/ensure_cross_origin_isolation_headers=false
progressive_web_app/offline_page=""
progressive_web_app/display=1
progressive_web_app/orientation=0
progressive_web_app/icon_144x144=""
progressive_web_app/icon_180x180=""
progressive_web_app/icon_512x512=""
progressive_web_app/background_color=Color(0, 0, 0, 1)
```

Key by key, the ones that matter:

* `name="Web"` / `platform="Web"` — `platform` must be the exact platform id; `name` is
  what you pass to `--export-release`. Keep both `"Web"` so the CI command is stable.
* `export_path="build/web/index.html"` — the default target; the CLI `<path>` argument
  overrides it, but keeping them identical means a GUI export and a CI export land in the
  same place. The `index` stem becomes the prefix of *every* generated file.
* `export_filter="all_resources"` — pack everything under `res://` that the importer
  knows about. `resources` (only what the scenes reference) is the alternative and is a
  frequent source of "works in editor, missing in export" bugs. Leave it at all_resources.
* `script_export_mode=2` — 0 = plain text `.gd`, 1 = binary tokens (faster load),
  2 = compressed binary tokens (smaller). 2 is the default and is what shipped.
* `variant/thread_support=false` — **the decisive key for this project.** false selects
  the `web_nothreads_*` template, which does not need `SharedArrayBuffer` and therefore
  does **not** need COOP/COEP cross-origin-isolation headers. That is what makes the build
  hostable on a plain static server (GitHub Pages, `python3 -m http.server`) and what makes
  it work on iOS Safari. Verified byte-for-byte: the exported `index.wasm` md5
  `83e2f97ab834d857572e3da40d56e70d` is identical to
  `export_templates/4.7.2.stable/web_nothreads_release.zip → godot.wasm`.
* `variant/extensions_support=false` — GDExtension in the browser needs the much larger
  `web_dlink_*` templates. Off unless a native extension is actually used.
* `texture_format/etc2_astc=true`, `texture_format/s3tc_bptc=false` — which compressed
  VRAM texture variants get packed. ETC2/ASTC is the mobile/GLES family and is the right
  single choice for a Compatibility-renderer game aimed at tablets; enabling S3TC as well
  roughly doubles the texture payload. (Only relevant once real textures with VRAM
  compression are imported; irrelevant for the probe.)
* `html/canvas_resize_policy=2` — 0 = None, 1 = Project (fixed at the project viewport
  size), 2 = Adaptive (canvas follows the browser window). 2 is what makes the game fill
  an iPad screen; combined with `stretch/mode="canvas_items"` it gives resolution-independent
  scaling.
* `html/focus_canvas_on_start=true` — canvas grabs keyboard focus on load; harmless for
  touch, needed for keyboard input.
* `html/experimental_virtual_keyboard=false` — leave off unless a `LineEdit` must raise
  the on-screen keyboard on iOS/Android; the implementation is still flagged experimental.
* `html/head_include=""` — raw HTML injected into `<head>`. This is the hook for a
  viewport meta tag, `theme-color`, or an analytics snippet without a custom shell.
* `html/custom_html_shell=""` — path to a replacement for the default `index.html`. Empty
  keeps Godot's shell (loading bar + status). Custom shells must keep the `$GODOT_*`
  placeholders.
* `html/export_icon=true` — writes `index.png`, `index.icon.png`,
  `index.apple-touch-icon.png` next to the build.
* `progressive_web_app/enabled=true` — emits `index.manifest.json`,
  `index.service.worker.js`, `index.offline.html` and the three PWA icons, and registers
  the service worker from the shell. This is what makes "Add to Home Screen" behave like
  an app on iPad.
* `progressive_web_app/ensure_cross_origin_isolation_headers=false` — when true the
  service worker rewrites responses to add `Cross-Origin-Embedder-Policy: require-corp` and
  `Cross-Origin-Opener-Policy: same-origin`, which is only needed for **threaded** builds
  on hosts that cannot set headers. With `thread_support=false` it must stay false; leaving
  it on adds header rewriting for no benefit and can break third-party embeds.
* `progressive_web_app/display=1` — 0 = Fullscreen, 1 = Standalone, 2 = Minimal UI,
  3 = Browser. 1 gives an app window with no browser chrome when installed.
* `progressive_web_app/orientation=0` — 0 = Any, 1 = Landscape, 2 = Portrait.
* `progressive_web_app/icon_*` — empty means "reuse the project icon, resized"; Godot
  generated `index.144x144.png`, `index.180x180.png`, `index.512x512.png` automatically.
* `progressive_web_app/background_color=Color(0, 0, 0, 1)` — the splash background written
  into the manifest as `#000000`. Set this to the game's background colour to avoid a
  black flash on launch.
* `custom_template/debug|release=""` — override the template zips per preset; empty uses
  the installed templates. Useful later if a custom-compiled, size-optimised template is
  ever built.
* `encrypt_pck=false`, `encryption_include_filters`, `seed=0` — PCK encryption, off. With
  `encrypt_pck=true` the export also needs `GODOT_SCRIPT_ENCRYPTION_KEY` in the environment.

---

## 4. `project.godot` settings that matter for web

```ini
config_version=5

[application]
config/name="Godot Web Probe"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[display]
window/size/viewport_width=1024
window/size/viewport_height=768
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[input_devices]
pointing/emulate_touch_from_mouse=true

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

* `config_version=5` is still current on 4.7.2 — the file above was accepted unchanged,
  with no migration prompt.
* `renderer/rendering_method="gl_compatibility"` — the **Compatibility** renderer, i.e.
  WebGL 2. The Forward+/Mobile renderers need WebGPU and are not an option for the target
  browsers. The `.mobile` override must be set too, otherwise a mobile-tagged run falls
  back to the Mobile (Vulkan) method. Confirmed in the browser console at runtime:
  `OpenGL API OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) - Compatibility`.
* `config/features` must contain `"GL Compatibility"` alongside the engine version tag,
  or the editor rewrites it on first open.
* `window/stretch/mode="canvas_items"` + `aspect="expand"` — the standard combination for
  a 2D game that must fill arbitrary tablet aspect ratios: UI is laid out in the 1024×768
  base resolution and scaled, and the extra area on a wider screen becomes extra visible
  viewport rather than black bars. Verified: at a 1024×768 CSS viewport with
  `deviceScaleFactor: 2` the canvas backing store was 2048×1536 and content stayed
  1:1 with the design coordinates.
* `pointing/emulate_touch_from_mouse=true` — makes desktop mouse clicks generate touch
  events, so a `TouchScreenButton` is clickable during development on a desktop browser.
  (Real touch works regardless; this is the dev-ergonomics half.)
* Viewport 1024×768 was chosen to match the iPad-shaped target used for verification.

---

## 5. Export output — files and sizes

`/tmp/godot-probe/project/build/web`, total **39,945,830 B (38.1 MiB)**:

| File | Bytes | What it is |
|---|---:|---|
| `index.wasm` | 39,514,754 | engine binary (nothreads release template) |
| `index.js` | 279,815 | Emscripten loader + Godot JS glue |
| `index.html` | 5,535 | default shell, loading bar, SW registration |
| `index.pck` | 3,112 | the project data (scenes, scripts, imported assets) |
| `index.service.worker.js` | 5,828 | PWA service worker |
| `index.manifest.json` | 330 | PWA manifest |
| `index.offline.html` | 971 | offline fallback page |
| `index.audio.worklet.js` | 7,298 | AudioWorklet processor |
| `index.audio.position.worklet.js` | 2,973 | AudioWorklet position reporting |
| `index.png` | 21,443 | project icon |
| `index.icon.png` | 5,700 | favicon |
| `index.apple-touch-icon.png` | 11,944 | iOS home-screen icon |
| `index.144x144.png` / `index.180x180.png` / `index.512x512.png` | 9,583 / 14,024 / 62,520 | PWA manifest icons |

The `.pck` is separate (not embedded); `index.html` fetches `index.wasm` and `index.pck`
by name. **Serve with compression**: `gzip -9` takes `index.wasm` from 39,514,754 to
**10,084,297 B** and `index.js` from 279,815 to 68,400 B. Over a plain
`python3 -m http.server` (no compression) the browser downloads the full 39.5 MB.

Generated manifest for reference:

```json
{"background_color":"#000000","display":"standalone",
 "icons":[{"sizes":"144x144","src":"index.144x144.png","type":"image/png"},
          {"sizes":"180x180","src":"index.180x180.png","type":"image/png"},
          {"sizes":"512x512","src":"index.512x512.png","type":"image/png"}],
 "name":"Godot Web Probe","orientation":"any","start_url":"./index.html"}
```

Service worker behaviour: `CACHED_FILES` (precached at install) = shell, loader, offline
page, icons, audio worklets. `CACHEABLE_FILES` (cached on first use) = `index.wasm`,
`index.pck`. `ENSURE_CROSSORIGIN_ISOLATION_HEADERS = false`, matching the preset.

---

## 6. Browser verification (chromium via Playwright)

Server: `python3 -m http.server 8731 --bind 127.0.0.1` from the build directory.
Driver: `require('/home/pc/work/ergomouse/node_modules/playwright')` (v1.60.0), chromium
only, headless, launched with
`--enable-unsafe-swiftshader --use-gl=angle --use-angle=swiftshader` (see gotcha G4).

Two profiles, both **passed**:

| Profile | Viewport | canvas (backing / CSS) | engine boot | console errors | warnings | failed requests | service worker |
|---|---|---|---:|---:|---:|---:|---|
| desktop | 1280×800 | 1280×800 / 1280×800 | 480 ms | 0 | 0 | 0 | active |
| ipad | 1024×768, dSF 2, touch, isMobile | 2048×1536 / 1024×768 | 421 ms | 0 | 0 | 0 | active |

"engine boot" = ms from `page.goto` until Godot's banner
`Godot Engine v4.7.2.stable.official.ed1daf0bf` appears on `console.log`. A separate
timing pass measured: load event 96 ms, `index.wasm` fetch 142 ms (39,515,054 B
transferred, uncompressed, over loopback), banner at 346 ms cold; 264 ms with a warm
service-worker cache.

Touch input was exercised, not just assumed: in the iPad profile
`page.touchscreen.tap(192, 264)` hit the `TouchScreenButton`, the `pressed` signal fired,
the GDScript printed `probe: tap 1` to the browser console and the on-canvas `Label`
changed to `Godot web probe - taps: 1` in the post-tap screenshot.

Console output of a clean run, in full (three lines, all `log`, zero `error`/`warning`):

```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
OpenGL API OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) - Compatibility - Using Device: WebKit - WebKit WebGL
Build configuration: Emscripten 4.0.20, single-threaded, no GDExtension support.
```

Evidence (outside the repo, throwaway):

```
/tmp/godot-probe/shots/desktop.png          1280x800  rendered label + button
/tmp/godot-probe/shots/ipad.png             2048x1536 before tap ("taps: 0")
/tmp/godot-probe/shots/ipad-after-tap.png   2048x1536 after tap  ("taps: 1")
/tmp/godot-probe/shots/report.json          full machine-readable result
/tmp/godot-probe/pw-test.js                 the driver script
```

---

## 7. Gotchas hit (each one cost a run)

**G1 — the export directory must already exist.** `--export-release "Web" build/web/index.html`
on a project without `build/web/` fails with
`ERROR: Export: Target folder does not exist or is inaccessible: "build/web"` and exit 1.
Godot does not create it. Always `mkdir -p build/web` first — in CI too.

**G2 — put a `.gdignore` in the build directory, or the export eats its own output.**
With `export_path` inside the project, the *next* import pass scans `build/web/`, imports
the exported PNG icons as project resources (writing `*.png.import` files into the build
output) and packs them: the probe's `.pck` went from 3,112 B to 82,864 B and the build dir
filled with `.import` junk. Fix, applied and verified:

```bash
mkdir -p build/web && touch build/.gdignore
```

after which the `.pck` was back to 3,112 B and no `.import` files appeared. (Exporting to
a directory outside the project works too, but breaks the relative `export_path`.)

**G3 — the export is byte-deterministic except the service worker.** Two consecutive
exports of an unchanged project produced identical md5s for all 15 files *except*
`index.service.worker.js`, whose `CACHE_VERSION = '<unix-timestamp>|<counter>'` changes
every run. Do not diff or checksum-gate that one file in CI; every other artefact,
including `index.wasm` and `index.pck`, is stable.

**G4 — headless chromium needs an explicit software-GL flag.** Godot's Compatibility
renderer requires WebGL 2. Recent chromium refuses the SwiftShader fallback in headless
mode unless launched with `--enable-unsafe-swiftshader` (plus
`--use-gl=angle --use-angle=swiftshader`); without them the page loads but the canvas
never initialises and the console fills with WebGL errors. On a GitHub Actions runner the
same flags apply.

**G5 — missing templates fail loudly, before packing.** With the templates directory
absent the export prints
`Cannot export project with preset "Web" due to configuration errors: No export template
found at the expected path: .../4.7.2.stable/web_nothreads_release.zip` (it names both the
debug and release nothreads zips, i.e. it reports exactly which variant the preset needs)
and exits 1. That message is the fastest way to confirm the preset's variant selection.

**G6 — `.tpz` is ~1.3 GB and expands to ~2.0 GiB.** Only `web_nothreads_release.zip`
(10.2 MB) and `web_nothreads_debug.zip` (10.2 MB) are needed for this project. In CI,
downloading the full `.tpz` costs ~1.3 GB per run; cache
`~/.local/share/godot/export_templates/4.7.2.stable` keyed on the Godot version, or strip
the directory down to the `web_*` files after extraction.

**G7 — the mono/.NET builds are a trap.** The release page carries
`Godot_v4.7.2-stable_mono_linux_x86_64.zip` and `Godot_v4.7.2-stable_mono_export_templates.tpz`
right next to the standard ones, and the mono templates are *not* interchangeable. Filter
with `grep -v mono` when reading `SHA512-SUMS.txt`, as the commands above do.

---

## 8. GitHub Actions notes (ubuntu-latest)

Everything above is `sudo`-free and works unchanged on a runner. Sketch:

```yaml
env:
  GODOT_VERSION: 4.7.2-stable
steps:
  - uses: actions/checkout@v4
  - name: Cache export templates
    uses: actions/cache@v4
    with:
      path: ~/.local/share/godot/export_templates
      key: godot-templates-${{ env.GODOT_VERSION }}
  - name: Install Godot
    run: |            # the install block from section 1 (skip the .tpz on a cache hit)
      ...
  - name: Import
    run: godot --headless --import --path $GITHUB_WORKSPACE/<project>
  - name: Export web
    run: |
      mkdir -p <project>/build/web && touch <project>/build/.gdignore
      godot --headless --path $GITHUB_WORKSPACE/<project> \
            --export-release "Web" build/web/index.html
```

Runner specifics worth remembering: `HOME` is writable so the default
`~/.local/share/godot` template path needs no override; no display server is required
(`--headless` uses the dummy driver, and no `xvfb-run` wrapper was needed here either);
and if the deploy target is GitHub Pages, no COOP/COEP headers are needed *because*
`variant/thread_support=false` — that is the entire reason the thread setting is pinned off.
