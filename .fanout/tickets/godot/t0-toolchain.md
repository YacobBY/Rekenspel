# T0 — Install the Godot toolchain and prove a headless web export

TASK
Install Godot 4.7.2-stable (Linux x86_64, standard build, not .NET), its export templates, and the GitHub CLI under the user's home directory, then prove with a throwaway project that a headless web export works and loads in a browser. There is no sudo on this machine.

EXPECTED OUTCOME
- `godot --version` on PATH (via ~/.local/bin/godot) prints 4.7.2.stable.
- Export templates installed at ~/.local/share/godot/export_templates/4.7.2.stable/ (Godot must find them without prompting).
- `gh --version` works from ~/.local/bin/gh. Report whether `gh auth status` is logged in; do not try to log in yourself.
- A throwaway project under /tmp (not in the repo) with one 2D scene, a Label, and a TouchScreenButton exports headlessly with a "Web" preset: Compatibility renderer, thread support OFF, PWA enabled. The export produces index.html, .wasm, .pck (or embedded), and the PWA service worker.
- The export, served by `python3 -m http.server` from its directory, loads in chromium via Playwright (`require('/home/pc/work/ergomouse/node_modules/playwright')`, chromium only) with a rendered canvas and zero console errors, also when emulating an iPad-sized viewport (1024×768, touch, deviceScaleFactor 2). Take a screenshot as evidence.
- A written spec at `.fanout/specs/godot/toolchain.md` in precise prose: download URLs used, install paths, the exact headless commands (import step and export step, including how to make the first headless import succeed), the full export_presets.cfg for the web preset with every key that matters explained, the project.godot settings needed for the web (renderer, stretch mode, touch emulation), file sizes of the export, load time observed, and any gotchas hit.

CONTEXT
The repo at /home/pc/Documents/xnw/rkn contains an HTML math game for children that will be ported to Godot in a later wave. A GitHub Actions workflow will later run the same export commands on ubuntu-latest, so record commands that work non-interactively. Godot release assets: https://github.com/godotengine/godot/releases/tag/4.7.2-stable (Godot_v4.7.2-stable_linux.x86_64.zip and Godot_v4.7.2-stable_export_templates.tpz). GitHub CLI releases: https://github.com/cli/cli/releases (linux amd64 tarball). ~/.local/bin is already on PATH.

CONSTRAINTS
- No sudo, no system package manager.
- Do not create anything inside the repository except the spec file named above.
- Do not run `pkill -f chrome` or any blanket process kill; close only the browser you launched.

MUST DO
- Verify downloads by size and by running the binaries.
- Use `--headless` for every Godot invocation; run an import pass first (`godot --headless --import` or `--editor --quit` style; find what works on 4.7.2 and record it).
- Keep the export deterministic: preset name "Web", export path build/web/index.html.

MUST NOT
- Do not spawn subagents.
- Do not modify the demos/ folder or any existing repo file.
- Do not install a different Godot version without reporting first; if 4.7.2 assets are missing, report BLOCKED.

WRITE SET
~/.local/opt/godot/, ~/.local/bin/godot, ~/.local/bin/gh, ~/.local/share/godot/, /tmp/godot-probe/, .fanout/specs/godot/toolchain.md.

OUTPUT FORMAT
Open with exactly one status: DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT or BLOCKED. Then at most 25 lines: versions and paths, the two commands that import and export, export size, whether the browser test passed (with the screenshot path), gh login state, and concerns.
