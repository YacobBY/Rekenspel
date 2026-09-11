# A1 — Architecture of the Godot 4.7 port of Dierenhotel Kwispelsteeg

Status: **decided**. Every rule below is binding for the wave-1 and wave-2 tickets;
where a rule is a decision that could have gone another way, the rejected option is
named so nobody re-opens it by accident. Everything marked `Wn` is a hole that ticket
`Wn` fills; the signature next to it is already fixed.

Companion specs, all four written in wave 0 and all still the source of truth for
*behaviour*: `toolchain.md` (T0), `world.md` (X1), `games-a.md` (X2), `games-b.md` (X3),
`art-sound-rules.md` (X4). `HOTEL.md` §9 is binding and is reproduced in X4 Appendix A.
The HTML game in `demos/dierenhotel/` stays untouched; it is read only to settle a
contradiction between specs. This document was allowed one such reading (§2.1).

The skeleton that proves this architecture lives in `godot/dierenhotel/` and is
described file by file in §11. It imports, exports and runs in chromium with zero
errors; the exact commands and their results are in §14.

### Contents

1. Goals, freedoms, and what is frozen · 2. The frozen number core · 3. Rendering the
voxel art · 4. Resolution and layout on tablets and phones · 5. Scene tree and autoloads ·
6. The game contract · 7. Project settings, web export, CI · 8. Sound · 9. Save format ·
10. Input and dragging · 11. The skeleton, file by file · 12. The ticket plan ·
13. Every open question of the four wave-0 specs, answered · 14. Verification

---

## 1. Goals, freedoms, and what is frozen

The owner, mid-wave-0: *"De game hoeft niet exact te werken als nu. Als Godot
verbeteringen biedt implementeer die dan. Ik merkte dat de HTML versie tegen
beperkingen aanliep."*

### 1.1 Frozen — parity is binding, no exceptions

| # | What | Where it is specified | How it is enforced |
|---|---|---|---|
| F1 | The curriculum bands and every number generator (`koekjesSom`, `vergelijk`, `deel`, `tafel`, `geld`, `klok`, `bandVanN`, `tel/herbereken`, the planbord solver, both LCGs, `buidel`, `splits`) — **byte-identical output for identical input** | games-a.md §2, world.md §3.9 | `res://core/sommen.gd` + `res://tests/test_sommen.gd`, one assertion per worked example in the specs (§2) |
| F2 | The owner's zwembad rules | games-b.md §1 (esp. §1.3–1.7, §1.10) | wave-2 ticket G1, with the same worked turn (43 → 43/13/20/30) |
| F3 | Every child-facing string, verbatim, Dutch, including the real minus sign U+2212 and the ellipsis U+2026 | world.md §7, games-a.md §3.7/4.6/5.9/6.6/7.7, games-b.md §1.11/2.10/3.9/4.10/5.11 | a string test per game: the literal must appear in the file |
| F4 | HOTEL.md §9 / GAMES-API §9 design rules: no calculation panel beside the world; numbers on objects; one Dutch sentence per sum card, ≤ 8 words **and** ≤ 40 characters, pictogram first on that line; choices are pictogram **and** word; task cards ≤ 6 words; never punishing; tap targets ≥ 48 px (44 px only below 360 px wide); text never below 12 px; explanation by showing, not by reading | X4 §17 | `Ui.somkaart()` warns once per violating card (as the HTML does) **and** a headless test walks every registered game's strings |
| F5 | A star is for taking part, never for being right; right/wrong only sizes the next sum | HOTEL.md §3, world.md §3.6 | code review + `Econ.sterren` has no "correct" parameter |

Everything else may be rebuilt the Godot way.

### 1.2 HTML mechanisms that are replaced by a Godot feature

| HTML mechanism | Replaced by | Why it can go |
|---|---|---|
| The layout bus (`ResizeObserver` on three boxes, 120 ms debounce, `MutationObserver` on `body.class`, the 180 ms re-lay lock, the 61-hits-in-5-s feedback loop) | `Control.resized` on the world frame + `World.meet(rect)` → `World.kader_veranderd` | Containers lay out synchronously and do not feed back: a change of the frame cannot change the chrome that changed the frame |
| `hits.js` measurement + four evasion rounds (UITWIJK table, stacking, "short frame" hiding) | the **band grid** of §4.3: one deterministic pass, 0 % coverage by construction | `Control.get_combined_minimum_size()` is exact *before* the first draw, so nothing has to be measured after a paint and then shoved |
| `padPlek` (`auto`/`binnen`/`buiten`), the 300/340 px dead zone, `VERSTIL_MS = 400`, `WISSEL_MAX = 2`, the single `#padstrip` | one keypad band, always inside the frame, docked to the bottom of the world frame (§4.4) | the frame is no longer capped by CSS aspect ratios, so there is always room; the flapping problem disappears with its cause |
| Per-game frame-width thresholds (`wekker` 370/400, `was` 330/340/300, `kraam` 340/360, `hinkel` 320) and `strookNakijken()` after 140 ms | `HBoxContainer` + `get_combined_minimum_size()`: pick the short word when the long strip does not fit, before the first frame | synchronous measurement; no empirical pixel thresholds per viewport |
| `was.meetIndeling` leaning on `Hits.debug()` | `World.vlak_van(model, x, z, y, params)` returns the exact screen rect of a baked plate | the plate's size is known at bake time, not after a DOM read |
| DOM card placement (`translate(-50%,-50%) translate(x,y)`, the "fresh button has no transform" bug, the 0.02-voxel `plek-rem`, `kaartLegStraks()` at 140/420/900/1800 ms) | Control `position` set in the same pass that computes it; a fresh Control is placed before it is first drawn | there is no frame in which a Godot Control exists but has no position |
| The density cap and canvas sizing done by hand on `<canvas>` | one `SubViewport` sized `frame × dicht` inside a `TextureRect` of `frame` units (§4.2) | same maths, one owner |
| Redraw-on-change via a fingerprint string of everything `teken()` reads | `World.vuil()` + node-level `queue_redraw()`; plates are blitted, not re-emitted | the scene graph already knows what changed |
| Promises for movement | `await World.stappen(...) -> bool` (§6.3) | a coroutine is the same contract with a stack |
| `localStorage` + save migrations v5/v6/v7 | one JSON document in `user://`, version 1, no migration (§9) | another origin; there is nothing to migrate |
| `setTimeout` chains that keep running after a game stopped | `MiniGame.na(seconds) -> bool`, cancelled by `stop()` | removes a whole bug class |
| Text-to-speech via the Web Speech API | dropped for now, see Q-X4-10 in §13 | not available to a Godot web export without a JS bridge |

### 1.3 Limitations of the HTML version that this port removes

1. **The world frame no longer has a CSS aspect-ratio cap** (`4/5`, `3/2`, `16/9`, `60vh`,
   `44vh`, `74vh`). The frame takes every unit the chrome leaves. Measured on the
   skeleton: 1000 × 648 units at an iPad 1024 × 768, where the HTML frame was
   1000 × 550. That is 98 extra units of room height, which is exactly what the keypad
   needed and could not get.
2. **No hidden buttons.** `hits.js` hides a button that would land on a fixed card
   ("short frame" rule, `debug().verstopt`). The band grid always finds a cell or the
   button is culled by priority — a child never taps a button that silently vanished
   between two frames.
3. **No iterative evasion**, therefore no frame-order dependence, therefore the same
   layout for the same state on every device.
4. **No 300 ms double-tap delay workaround, no swallowed follow-up click.** Godot
   delivers one press per tap (proven in the browser probe: one `touchscreen.tap` →
   `tik=1`).
5. **One text floor that cannot be escaped.** In the HTML a game's own inline
   `font-size` escaped the 12 px clamp; here every child-facing Control is built by
   `Ui`, which owns the theme.
6. **Sound needs no unlock trick per sound.** One `Snd.ontgrendel()` on the first input,
   after which every sound is a normal `AudioStreamPlayer`.
7. **The save is written atomically** (temp file + rename) instead of a `localStorage`
   string that can be half-written by a background tab.
8. **The world keeps running at a stable tick** independent of the draw rate (15 Hz
   think, engine-paced draw), instead of `requestAnimationFrame` with catch-up ticks and
   a 400 ms idle redraw. Battery is handled by the engine.
9. **Deterministic idle behaviour is now possible**: the animal PRNG is seeded from the
   day and the guest id instead of `Date.now()` (Q-X1-1 in §13).

---

## 2. The frozen number core

### 2.1 JavaScript integer semantics — the single hardest thing in the port

`res://core/jsgetal.gd` (`class_name JsGetal`) reproduces three JavaScript behaviours
that GDScript does not share. Every frozen function goes through it.

| JS | GDScript | Why |
|---|---|---|
| `x >>> 0`, `x \| 0` on a value that stays inside 53 bits | `JsGetal.u32(v)` / `JsGetal.i32(v)` | plain masking is enough |
| `x >>> 0` on a float64 that exceeded 53 bits | `JsGetal.to_uint32(f)` — `fmod(floor(abs(f)), 2^32)` | **the value was already rounded before the truncation** |
| `Math.imul(a, b)` | `JsGetal.imul(a, b)` | true 32-bit signed multiply |
| `Math.round(x)` | `JsGetal.rond(x)` = `floor(x + 0.5)` | JS sends halves to +∞, GDScript sends them away from zero |

The decisive case, and the reason this section exists. `dagRnd`'s step is
`a = (a * 1103515245 + 12345) >>> 0` with `a < 2^32`: the product reaches 4.7·10^18,
far past 2^53, so JavaScript **rounds it to a multiple of 1024 before truncating**.

```
a0 = 2654448106                       (dagRnd(1) after seeding)
64-bit integer port  : (a0 * 1103515245 + 12345) & 0xFFFFFFFF = 678745307   WRONG
float64 path (JS)    : ToUint32(float(a0) * 1103515245.0 + 12345.0) = 678745088   RIGHT
```

Both numbers are asserted in `test_sommen.gd::test_js_integer_semantiek`, the wrong one
deliberately, so that a future "optimisation" to integer arithmetic fails the suite
instead of silently changing every generated day.

The seeding multiply (`zaad * 2654435761`) and the whole of `zaadje` (`s * 1664525`)
*do* stay inside 53 bits for every seed the game can produce, so those are exact in
either arithmetic — but they are written through the same helpers anyway.

*(This is the one place where `demos/dierenhotel/` was read: X2 §2.7 writes the LCG as
`mod 2^32` pseudocode, which is ambiguous about the float64 rounding, and F1 makes the
difference binding. `state.js:380-386` and `games/sleutels.js:139-142` settled it.)*

### 2.2 What lives where

* `res://core/jsgetal.gd` — the four helpers above. **Frozen after W5.**
* `res://core/sommen.gd` (`class_name Sommen`) — the number core. Already ported and
  under test in the skeleton: `DagRnd`, `Zaadje`, `Prng` (mulberry32, for the garden
  tufts and the animals), `hash2`, `hash_tekst`, `band_van_n`, `koekjes_som`,
  `vergelijk`, `deel`, `tafel`, `geld`, `klok`, `buidel`, `splits`.
  **W5 added:** the planbord solver (`plan_fouten`, `plan_oplossingen`, `maak_plan`,
  `planbord`, `CELLEN`, `VASTE_AFSPRAKEN`), the 31-bit LCG `Sommen.Lcg31` that
  `zwembad`/`rooms` use, and one inner class per wave-2 game carrying that game's own
  frozen generators. W5 owns this file; a game may not copy a generator into its own
  directory, it calls:

  | call | spec |
  |---|---|
  | `Sommen.Zwembad.baan / juist_van / keuze_getallen / slag` | games-b §1.3–§1.5 |
  | `Sommen.Wekker.doel_tijd / afstand / duur_keuzes / duur_vraag / beurt / tijd_woord / uur_ico / u12 / in_min / van_min / klok5` | games-b §2.3–§2.4 |
  | `Sommen.Hinkel.beurt / maten_voor / maten / keuze_getallen` | games-b §3.4 |
  | `Sommen.Was.kies_t / verdeel / soorten_voor / recept` | games-b §4.3 |
  | `Sommen.Kraam.schuif_van / opzet / keuring / splits_met` + `WAREN` `MUNTEN` `SPOOK_MUNT` | games-b §5.3 |
  | `Sommen.Sleutels.maak_opdracht / controleer / kies_blanco / rij_van / variant_van / aantal_haken / aantal_sleutels` | games-a §4.2 |
  | `Sommen.Tobbe.recept / soorten` + `PLAFOND` `CAP` `HAND` | games-a §6.2 |
  | `Sommen.Bedden.opdracht(band, dag, N, cap, max_stroken)` | games-a §3.3 |
  | `Sommen.Meubels.max_lijst / buidel_max / wisselgeld / buidel_cap / prijs_van` + `WINKEL` `VERSIERING` | games-a §5.2–§5.3 |
  | `Sommen.Voerkar.som_regel / volgende_hand` + `HAND` | games-a §7.2 |

  The dictionary keys keep the JavaScript names (`L`, `M`, `T`, `k`, `r`, `per`…);
  a JS `null` is `""` for a text field and `{}` for a record. Every one of these was
  compared case by case against the original JavaScript in node — **23 042 cases,
  0 differences**, PRNG doubles included down to the bit (`tests/test_sommen_kruis.gd`).
* Every function is `static` and pure. No autoload, no state, no `randf()`.

### 2.3 Signatures (already implemented, do not change)

```gdscript
Sommen.band_van_n(n: int) -> int
Sommen.koekjes_som(dag: int, n: int) -> Dictionary          # {per, rest, total}
Sommen.vergelijk(dagen: int, nieuw: int, voorraad: int) -> String   # meer|minder|precies
Sommen.deel(n_gasten: int, band: int, dag: int) -> Dictionary       # {T, k, r, band}
Sommen.tafel(band: int, dag: int, n_gasten: int) -> Dictionary      # {a, b, uit, band, tafels, plafond}
Sommen.geld(band: int, dag: int, nachten := 0, prijs := 0) -> Dictionary
Sommen.klok(band: int, dag: int) -> Dictionary              # {u, m, stap, tekst, duur?}
Sommen.buidel(totaal: int) -> Array[int]                    # descending
Sommen.splits(n: int) -> Array[int]
Sommen.hash2(x: int, z: int) -> int
Sommen.DagRnd.new(zaad: int).volgende() -> float            # 24-bit output
Sommen.Zaadje.new(n: int).volgende() -> float               # 32-bit output
Sommen.Prng.new(seed: int).volgende() -> float              # mulberry32
```

`State` is the only caller that knows the day and the guest count; a game asks
`ctx.state.band()` and passes `dag`/`N` explicitly, so every generator stays pure and
testable.

### 2.4 The test framework — decision

**A home-grown headless runner, no vendored addon.**

```
godot --headless --path godot/dierenhotel --script res://tests/run_tests.gd
```

`res://tests/run_tests.gd` extends `SceneTree`; it awaits one frame (autoloads get their
`_ready` on the first frame, not before `_initialize`), then loads every
`res://tests/test_*.gd` **and** every `res://games/<id>/test_*.gd`, runs each `test_*`
method on a fresh instance of `Proef` (`res://tests/proef.gd`: `gelijk`, `waar`, `fout`),
prints one line per test and exits 1 on any failure.

**A test file that does not compile is a failure, never a skip** (W5-F1). `load()` on a
script with a parse error hands back a `GDScript` that is *not* null but whose method list
is empty, so the runner used to walk past it without a word: the bare `--script` command
printed `n goed, 0 fout` while a test file was broken, and only the stderr grep in
`tools/test.sh` noticed. The runner now reports `FOUT <bestand>: kan niet laden —
parseerfout?` when the script is null or `can_instantiate()` is false, `geen enkele
test_-methode — parseerfout?` when it compiled to nothing, and `kan geen exemplaar maken`
when `new()` fails — each of them exits 1 from the bare command as well.

The test method is invoked as `await proef.call(naam)`, and the `await` is not optional
(fixed in W5). A test method that awaits anything is a coroutine; calling one without
`await` logs `SCRIPT ERROR: Trying to call an async function without "await"` and then
**abandons the rest of that file** — the test and every test after it in the same file
vanish from the suite without a line of output. Measured on `tests/test_ui.gd`: 14 test
methods, 13 result lines, and the missing one was red. Awaiting a value that is not a
coroutine simply returns it, so the one word covers both kinds of test.

**A runtime error is a failure, not a pass.** A GDScript runtime error (a null call, a
bad index) aborts the test function and returns quietly, so a naive runner prints `ok`
for a test that never reached its assertions. Two independent gates close that:

1. **In-engine**: the runner registers an `OS.add_logger()` hook (`Logger`, available
   since 4.4) that counts everything the engine logs as an error while a test runs.
   `push_warning` and the `# Wn` stubs are explicitly *not* failures — only
   `ERROR_TYPE_ERROR`, `_SCRIPT` and `_SHADER` count. The failing test is reported with
   the first four engine messages under it.
2. **In the shell**: `godot/dierenhotel/tools/test.sh` is the command CI and the tools
   use. It runs the suite, prints the log, and additionally fails on any
   `ERROR:` / `SCRIPT ERROR:` line in the output — so the gate survives even if a future
   engine version changes the logger hook.

Proven with a throwaway test that dereferences a null (`§14.3`): both the runner and the
wrapper exit **1**, and the summary counts the test as `FOUT` with
`1 motorfout(en) tijdens de test`.

**A test may walk an error path on purpose** (W5). `Proef.verwacht_fout(aantal := 1,
waarom := "")` announces that this test makes the engine log exactly `aantal` errors —
`Art.registreer_model` refusing a protected name, a deliberately corrupt save file. The
budget is **exact in both directions**: announcing one and causing two fails, and
announcing one and causing none fails too, because then the error path was never walked
and the test proved nothing. It may be called before or after the erroring call; only the
totals are compared. The runner prints the suite total as its last line,
`verwachte motorfouten: n`, and `tools/test.sh` allows exactly that many `ERROR:` lines
and not one more — so gate 2 keeps its teeth. Proven green in
`tests/test_sommen_runner.gd` and proven red with a throwaway file: an undeclared error,
an over-budget error and an announced-but-absent error each report `FOUT`
(`verwachtte 1 motorfout(en), kreeg er 2`) and exit **1** from both the runner and the
wrapper.

Rejected: **GUT** and **GdUnit4** — both are large third-party trees that have to track
the engine version, both would sit in `addons/` inside the export filter, and the whole
suite here is "call a pure function, compare an integer". The runner above is 55 lines,
starts in under a second and gives CI an honest exit code. Measured: **22 tests, 61 ms**
on this machine, well inside the one-minute budget with room for the ten game suites.

Scanning `res://games/<id>/test_*.gd` is deliberate: a wave-2 ticket then never writes a
file outside its own directory.

---

## 3. Rendering the voxel art

### 3.1 Decision

**(i) A GDScript voxel baker.** Each `(model, params, g)` is rasterised once into an
`Image`, post-processed (`omlijn`, `rondAf`) and kept as an `ImageTexture` in an LRU
cache of `PLAAT_MAX = 110` plates; the world only blits those textures.

Rejected, with the X4 evidence:

* **(iii) pre-baked sprite sheets from the extractor** — `klok`, `steen`, `trap`,
  `was_krat`, `was_berg` and `zb_streep` take parameters that change geometry (X4 §14.2:
  a clock at 7:23 with a ghost hand at 8:00 is a distinct image), so a texture port still
  needs the baker and would carry both systems. Plates are also not integer rescales of
  each other (the outline width is `round(g/2.6)` and `rondAf` only runs at `g ≥ 2`), so
  a full set is ~340 plates × 3 scales ≈ 8–10 MB, on top of a 40 MB wasm, on a school
  tablet. The extractor stays as a **golden-image oracle** (§3.6).
* **(ii) `Node2D._draw` per model** — re-emitting 467–1365 polygons per model per frame
  is what the HTML deliberately does *not* do; the dirty rules of X4 §11.7 assume a blit.

Rasterisation is **CPU-side** — one prepared stamp per (face shape, scale, shade),
blended with `Image.blend_rect`; W4 measured that this is roughly twice as fast as a
`fill_rect` per scanline span, because a model uses at most 3 x 5 shades per base colour
so the stamps are made once and the whole raster becomes native blends — not a
SubViewport read-back. That buys three things the read-back cannot: the bake is deterministic, it
needs no GPU round trip on the single-threaded web build, and it runs under
`--headless`, which is what makes the golden-image test possible in CI.

### 3.2 The plate

Geometry, straight from X4 §1.2/§1.3/§1.5 (`S = 2`, `HG = 2`, `PAD = 2` canvas px,
**not** scaled by `g`):

```
per voxel, in voxel-px:  px = (x − z) · S          py = (x + z) − (y + 1) · HG
the voxel covers         [px − S, px + S] × [py, py + 2·HG]
box  = [min px − S, max px + S, min py, max py + 2·HG]
plate size = (box.w · g + 2·PAD) × (box.h · g + 2·PAD)
dx = box[0] · g − PAD        dy = box[2] · g − PAD
```

Verified against X4 §14.1: `gast_hond_rust_g4` = 260 × 244 at (−66, −118), and X4 §5.1
gives 64 × 60 voxel-px at (−16, −29): `64·4 + 4 = 260`, `−16·4 − 2 = −66`. ✔

Faces are emitted with hidden-face culling, shaded with `F_TOP/F_RECHTS/F_LINKS × AO[n]`
and the WARM/KOEL mix of X4 §3, sorted ascending on `d = x + y + z`, and filled with
per-row spans whose x-range is taken over the whole row and rounded outward — that is
what the JS `fill` + 1 px `stroke` does, and it closes the seams by construction.
Then `omlijn` (Manhattan dilation by `max(1, round(g/2.6))`, tinted
`rgba(112,90,76,.26)`, drawn behind) and `rondAf` (alpha ≥ 200 with ≥ 2 empty orthogonal
neighbours → alpha 112, only at `g ≥ 2`).

```gdscript
Art.registreer_model(naam: String, fn: Callable) -> bool   # fn(params) -> Array of {x,y,z,k: Color}
Art.heeft_model(naam: String) -> bool
Art.model(naam: String, params := {}) -> Array
Art.plaat(naam: String, g: int, params := {}) -> Art.Plaat # {tex, dx, dy, w, h}, LRU-cached
Art.bak(voxels: Array, g: int, opties := {}) -> Art.Plaat
Art.wis_platen() -> void
Art.gebakken() -> int                                      # bake counter, for tests
```

W4 added, on top of that and without changing any line above (all of it is a new door
onto the same cache, so nothing that was written against the seven calls has to move):

```gdscript
Art.dier(kind, pose, g, acc := null) -> Art.Plaat     # one guest; acc = list or "a,b"
Art.kom(niveau, g, voor: bool, groot := true) -> Art.Plaat  # the bowl, split in two
Art.niveau(aantal, per) -> int                        # how full the bowl looks, 0..4
Art.water_plaat(kind, pose, g, top, acc := null)      # a swimmer with his water band
Art.vloer_kleur(kamer, x, z) -> Color                 # = ArtVloer.kleur; takes a
                                                      # Rooms.Kamer or a Dictionary
Art.plaat_van(sleutel: String, maak: Callable)        # the generic LRU door
Art.census(voxels) -> Dictionary                      # {voxels, vlakken, lxhxd}, diagnostic
Art.platen_in_cache() -> int
Art.DIER_ANKER = (13, 7.5)   Art.KOM_ANKER = (29.5, 7.5)
```

`opties` on `bak()` are all optional and all default to the plain case: `voor`
(-1 = every face, 0/1 = only that group — the bowl's front wall is drawn after the
animal), `omlijn` (false = no contour of its own), `silhouet_alles` (box and contour
over every face, not only the selected group) and `vlaksleutel` (cache name for the
culled face list, which is scale-free and therefore serves every `g`).

The four guests and the bowl are registered as protected world models as well
(`gast_hond`, `gast_poes`, `gast_konijn`, `gast_gans` with `params = {pose, acc}`, and
`kom` with `{niveau, groot}`), so a `WereldObject` can carry one through the plain
`Art.plaat()` door without knowing anything about poses.

A model function must be **pure**: same `params`, same voxel list, because the cache key
is `naam|g|JSON(params)`.

### 3.3 Anchors — one unambiguous rule

X4 §1.5 states the anchor as a canvas offset, which does not survive translation to a
scene graph. The port uses one rule instead:

> A model's voxel `(0,0,0)` projects onto the object's world point. The plate is drawn at
> that point plus `(dx, dy)`. A model may declare an `anker` in **voxels**; the sprite is
> then shifted by the isometric projection of that anchor:
> `anker_px = ((a.x − a.z)·S·g, (a.x + a.z)·(S/2)·g)`.

For the four guests, `anker = (13, 7.5)` (the centre of the four paws), so the guest's
world position is its paw centre exactly as in the HTML. W4 verifies the resulting plate
offsets against `/tmp/dh-art/meta.json`.

Mirroring (`face < 0`) is `Sprite2D.flip_h` about the object's world point — no mirrored
textures, exactly as in the HTML.

### 3.4 Painter order = y-sorting, for free

The room scene (`res://scenes/kamer.tscn`) has four layers, drawn in tree order:

```
Kamer (Node2D)
├── Vloer      one baked plate: floor tiles in 4×4 blocks + both back walls   (W1/W4)
├── Ver        wall decor (`ver: 1` in rooms.js) — never sorted, always behind
├── Objecten   y_sort_enabled = true  ← guests, decor, runtime decor
└── Voor       overlays: the water band over a swimmer, particles
```

Every thing in `Objecten` is a **`WereldObject`** (`res://scenes/wereldobject.gd`):

* the node sits on the object's **floor point** `World.scherm(x, z, 0)`, so Godot's
  y-sorting *is* the `d = x + z` painter's algorithm of world.md §0;
* the depth tweaks of world.md §0 become a Y bias on that node: `+0.3·k` for decor with
  a height, `+0.5·k` for a sleeping animal, `+0.2·k` for a loose "ding"; `ver` decor is
  not biased at all, it lives in the `Ver` layer;
* the `Beeld` child (`Sprite2D`, `centered = false`, `TEXTURE_FILTER_NEAREST`) carries
  the plate offset, the anchor and the **lift** (`hoogte` in voxels: a jump `+`, a
  swimmer `−7`, a sleeper on a mattress `−7·HG` px), so lifting never changes the depth.

```gdscript
WereldObject.zet_model(naam: String, params := {}, anker := Vector2.ZERO) -> void
WereldObject.plaats(x: float, z: float, y := 0.0) -> void
WereldObject.ververs() -> void        # re-reads the plate only when g changed
WereldObject.vlak() -> Rect2          # screen rect in frame units — Hits needs it
var face: int                          # +1 / −1
var diepte_bias: float
```

Guests, fixed decor and a game's runtime decor are the same class; the only difference is
who owns them (`World.decor(...)` stamps the owner and enforces `LOS_MAX = 48` per room).

### 3.5 Cost, and the bake budget

A bake is one prepared stamp per (face shape, scale, shade) blended per face, plus two
native passes over the plate. Budget:

* ≤ 8 ms per plate at `g = 4` on this desktop, ≤ 25 ms in the browser;
* the current room's models are baked when the room is entered — the 300 ms camera slide
  is the window;
* if a measurement blows the budget, the fix is inside `Art.bak()` (span batching,
  reusing the silhouette image) and the plate API does not change.

**Measured by W4** on this desktop, with the real models
(`tests/gouden/_meet.gd` prints the whole table):

| what | `g = 2` | `g = 3` | `g = 4` |
|---|---:|---:|---:|
| average of 12 decor models | 7.1 ms | 8.8 ms | 12.2 ms |
| the heaviest model (`hok`, 11 088 voxels) | 15.1 | 18.3 | 23.4 |
| a guest (`gast_hond`, 3 102 voxels, model build included) | 11.1 | 13.2 | 16.3 |
| **the whole receptie set cold** (15 plates: 11 decor + 4 guests) | **103 ms** | **121 ms** | **151 ms** |
| the same room warm (every plate from the cache) | 0.03 ms | 0.03 ms | 0.03 ms |
| the same room at another `g` (face list still cached) | — | — | 34 ms |

(Measured while five other wave-1 workers were running on the same machine, so these
are pessimistic by 10–30 %; a quiet run gives 147 ms for the receptie set at `g = 4`.)

The **room-level budget holds with room to spare** — 147 ms of the 300 ms slide, and
nothing at all on a second visit. The **per-plate 8 ms does not hold for the four
biggest models** (`hok`, `kar`, `boom`, `kast`, 4 700–11 000 voxels): a bake is
dominated by GDScript walking the voxel list, not by the raster, and a model of 11 000
dictionaries costs ~15 ms there whatever the raster does. Three things were done inside
`Art.bak()` first, and they took a `hok` plate from 48 ms to 24: a dense occupancy grid
instead of a Dictionary, a counting sort on `d` instead of `sort_custom`, and one
prepared stamp per (shape, scale, shade) instead of a `fill_rect` per span. What is
left would need the voxel format itself to stop being `Array[Dictionary]`, which is the
published model contract, so it was not done. The **face list is cached scale-free**
(`vlaksleutel`), so the second and third scale of the same model are ~40 % cheaper and a
resize of a whole room costs 34 ms instead of 151.

**In the browser** (W4-F1). There is no way to time a wasm bake from the outside, so the
web build answers a query flag: `index.html?bakmeting` makes `Art` bake the model set of
the receptie and of the tuin at the scale the world actually chose and print one
`[probe]` line per room. Without the flag nothing runs. Measured in chromium with the
swiftshader flags of T0 gotcha G4 (`.fanout/scratch/w4/probe-bak.js`, 0 console errors in
every profile):

| profile | `g` | receptie (12 plates) | tuin (17 plates) | worst single plate |
|---|---:|---:|---:|---|
| iPad landscape 1024 x 768 dpr 2 | 4 | **174–183 ms** | **161–165 ms** | `balie(z)` 34–41 ms |
| iPad portrait 768 x 1024 dpr 2 | 3 | **146–206 ms** | **127–173 ms** | `baliez` 32–46 ms |
| iPhone landscape 844 x 390 dpr 3 | 2 | **136–179 ms** | **119–148 ms** | `baliez` 28–40 ms |

(Two independent runs; the high end is a machine with five parallel workers on it, the
low end a quiet one.)

**Neither room exceeds the 300 ms slide** in wasm — the widest measurement is 206 ms,
two thirds of the window — so a child never sees a room arrive late. The **≤ 25 ms per
plate browser budget is exceeded** by the two heaviest models: `baliez` (a `balie` of
5 790 voxels, mirrored, so 11 580 dictionaries are built) reaches 32–46 ms and `hok`
(11 088 voxels) 31–43 ms; wasm is 1.2–1.5x slower than this desktop for the same bake. Proposed, **not
implemented** (it changes the plate lifecycle, which is W1's `World.naar()`): spread a
room's cold bake over the frames of the slide instead of one burst — twelve plates across
~18 frames is ~15 ms of work per frame and fits the budget without touching the
rasteriser. The second lever, worth more but wider, is dropping `Array[Dictionary]` as
the model voxel format: the model *build* is the dominant term in every one of these
numbers, not the raster.

There is no second floor renderer: `scenes/vloer.gd` (W1) draws the floor and both back
walls as one `ArrayMesh` with per-vertex colours, and `ArtVloer.kleur(kamer, x, z)` is
the colour table it reads — one authority, no plate. An `Art.vloer_plaat()` existed
briefly in W4 and was deleted in W4-F1: at 163 ms and three megapixels per room it was
not a fallback but a fork.

### 3.6 The golden-image oracle

`/tmp/dh-art/*.png` (64 plates, extracted losslessly from the running HTML engine) is the
reference. W4 ships `res://tests/test_art.gd`, which bakes the same model/pose/`g` and
compares per pixel with a tolerance for the rasteriser difference between canvas2d
(anti-aliased) and this integer filler. The extractor and its PNGs now live in
`godot/dierenhotel/tests/gouden/` (**72 plates**, 73 rows in `meta.json` because
`gast_hond_rust_g4` is both a pose and a species, + `extract.js`), under a `.gdignore` so
Godot neither imports them nor packs them into the web export; the test reads them with
`FileAccess` + `Image.load_png_from_buffer`. W4-F1 added the nine that were missing: the
pose coverage was dog-only, so `poes`, `konijn` and `gans` now also come out in `lig`,
`loopA` and `loopB` at `g = 4` — the three poses that exercise the post-transforms
(`liggen()` squashes the legs and lays a rabbit's ears flat) and the gaits (a rabbit hops,
a goose waddles). There is no pose `zwem`: art.js has fifteen and swimming is none of
them; a swimmer keeps his pose and gets the water band of §11.5 over him, which
`test_water_alleen_op_de_zwemmer` asserts instead.

**The tolerance, revised by W4 after measuring** (this is the one contract change of the
ticket). The rule was "≤ 2 % of pixels may differ by more than 16 in any channel, and the
alpha silhouette must match within 1 px". The second half holds exactly — **0 silhouette
pixels are more than 1 px off on all 64 plates** — but the first half is not
scale-invariant: the difference is an *edge* phenomenon (canvas anti-aliases every
polygon edge and strokes it 1 px wide; this integer filler rounds the span outward), so
it scales with the plate's **perimeter**, not its area. Measured: 1.19 % on a 436 × 316
counter and 14.36 % on a 44 × 44 ball — but a near-constant 2.7–3.8 differing pixels per
unit of perimeter across every plate. The rule is therefore:

> per plate, the pixels whose channel difference exceeds 16 must stay under
> `2 % · w · h + 5 · (w + h)`, and no silhouette pixel may be more than 1 px off.

Measured with that rule: **73/73 plate comparisons pass**, aggregate 3.3 % of the pixels,
worst plate `decor_bal_g2` at 14.36 % (2.72 px per unit of perimeter, against the 5 the
rule allows). Of the differing pixels ~59 % sit where the golden image has a
partial alpha (the anti-aliased outline ring) and ~41 % are one-pixel seams between two
faces of the same object, where canvas blends the two shades and this filler picks one.
Three rasterisation rules were tried against the oracle before settling — outward
rounding over the row, pixel-centre sampling, and pixel-centre of the stroked shape —
and outward rounding (the shipped one) is the best of the three; softening the outermost
pixel row to alpha 96/128/160 made it *worse*, so the browser's fill+stroke edge really
is nearly opaque. **Everything that is not the edge matches exactly**: plate size,
`dx`/`dy` offset, voxel count, culled-face count and `l × h × d` are identical to
`meta.json` for all 64 plates and all four species.

---

## 4. Resolution and layout on tablets and phones

### 4.1 One Godot unit = one CSS pixel

The 48 px tap rule and the 12 px text floor come from a six-year-old's fingertip, not
from a display. So:

| setting | value |
|---|---|
| `display/window/size/viewport_width` × `height` | **1024 × 768** — a design reference only |
| `display/window/stretch/mode` | `canvas_items` |
| `display/window/stretch/aspect` | `expand` |
| `display/window/handheld/orientation` | `6` (sensor: portrait **and** landscape) |
| at runtime, on every `Window.size_changed` | `content_scale_size = round(window.size / dpr)`, with `dpr = max(1, DisplayServer.screen_get_scale())` |

Setting the **base size** to the CSS size makes both stretch ratios equal, so the scale
is exactly `dpr` whatever convention the engine uses for `expand`. UI and fonts then
render at full device resolution while every layout number is a CSS pixel.

Measured in the exported build (browser probe, §14):

| viewport (CSS) | dpr | `window.size` | `content_scale_size` | canvas backing store |
|---|---|---|---|---|
| 1024 × 768 | 2 | 2048 × 1536 | **1024 × 768** | 2048 × 1536 |
| 768 × 1024 | 2 | 1536 × 2048 | **768 × 1024** | 1536 × 2048 |

Rejected: a fixed 1024 × 768 viewport with letterboxing (a 360 px phone would shrink
every button to 17 px) and `content_scale_factor` arithmetic against the base
(needs the engine's `expand` convention to be assumed rather than forced).

### 4.2 The world lives in a SubViewport, reproducing `dicht`

```
SubViewport "Wereld"   size = round(frame_units · dicht)   render_target_update_mode = ALWAYS
   └── Kamer (instance of res://scenes/kamer.tscn)
TextureRect "Beeld"    size = frame_units, texture = SubViewport texture,
                       texture_filter = LINEAR, expand_mode = IGNORE_SIZE
```

Voxels are rasterised at the whole number `g` inside the SubViewport and the result is
scaled smoothly down to the frame — a literal translation of HOTEL.md §1 and exactly what
the browser did with a CSS-downscaled canvas.

`World.schaal()` is the only source of scale numbers; a game may never read the device
pixel ratio (X4 §1.4).

```
d      = min(3, dpr), but 2 when min(frame_w, frame_h) < 900          # §4.2a
q      = min((max(240, frame_w) − 4) / box_w, max(120, frame_h − 4) / nodig_h)
g      = clamp(round(q·d), 2, 4);  if g/d < 0.9·q then g = clamp(ceil(q·d), 2, 4)
dicht  = max(d, g/q)
k = q  = g / dicht          pxPerVoxelX = 2k   pxPerVoxelY = k   pxPerHoogte = 2k
nodig_h(room) = box_h − max(0, −box[2] − WAND_ZICHT)      WAND_ZICHT = 56
```

**§4.2a — the density cap is extended to tablets** (X4 §18.3 recommendation 4). The HTML
capped `d` at 2 only below a 500 px short side; a dpr-2 tablet already carries a
9–11 MB canvas and a dpr-3 tablet would carry ≈ 25 MB. The port caps at
`min(frame_w, frame_h) < 900`, i.e. every phone and every tablet in portrait. `q` is
unchanged by the cap, so nothing looks smaller. Measured on the skeleton at an iPad
1024 × 768: frame 1000 × 648, `g = 4`, `dicht = 2.000`, `k = 2.000`, SubViewport
2000 × 1296 — the same `g` the HTML reaches in landscape, with a taller room.

Camera (world.md §1.9, unchanged): `cx = W/2 − (box[0]+box[1])/2·g`;
`over = H − box_h·g`; `onder = min(KADER_ONDER·dicht, max(0, over))`;
`cy = over ≥ 0 ? (over − onder)/2 − box[2]·g : H − 4 − box[3]·g`.
`KADER_ONDER = 132` units stays: it is the strip under the room that the keypad band and
the blanket chest live in, and it is what keeps the floor whole.

### 4.3 Hotspot placement: the band grid — 0 % coverage by construction

This replaces `hits.js` §5.4 entirely. Constants (`res://autoload/hits.gd`):

| name | value | meaning |
|---|---|---|
| `RIJ` | **52** units | band height = 48 px tap target + 4 px air |
| `KOL` | **56** units | column width (the hits.js fallback button width) |
| `RAND` | **6** units | air to the frame edge |
| `GAT` | **4** units | air between a button and its object |
| `KRAP` | **2** units | the hard frame edge; nothing goes past it |
| `MAX_PER_KAMER` | **16** | buttons visible in one room |
| `TAG_IN` | **0.1** | a number tag may cover a tenth of its object |

Two invariants hold for every placed element, and `tests/test_hits.gd` asserts both in
five frame sizes and four adversarial shapes:

* **nothing overlaps anything else** — every placed element, a fixed card and a clamped
  placement included, reserves every grid cell it touches;
* **no button stands on any object in view** — not just on its own object. A fixed card
  (`midden`) and a number tag (`rand`) are the only elements allowed over the world, and
  they choose first.

One pass per drawn frame:

1. **follow** — every hotspot with a `volg` callable takes its new `{x, z, y, kamer, vlak}`
   (that is how a bubble walks with its animal, into another room too);
2. **layer** — `VAST (0)` fixed cards, number tags and the keypad · `SPEL (1)` the game
   that has priority · `HOTEL (2)` · `WENS (3)` wish bubbles;
3. **cull** — sort by layer, then priority descending, then depth; everything past
   `MAX_PER_KAMER` is hidden;
4. **place**, front-most first inside a layer, into a grid of
   `rijen = (frame_h − 2·RAND) / RIJ` bands × `kolommen = (frame_w − 2·RAND) / KOL`
   columns:
   * `midden` (fixed cards, `y ≤ 0`, own html): on the aim point, clamped to the frame,
     and it reserves every cell it covers — everything else gives way to it;
   * `rand` (number tags and **name plates**): bottom edge just over the object's top
     edge, covering at most `TAG_IN` of it (a name plate keeps 2 units of air and covers
     nothing); it reserves its cells too, and steps up in whole bands when the place it
     wants is taken — that reservation is what keeps a plate off a button (I1 finding 3);
   * `kleef` (a choice strip under its card): top edge `KLEEF = 5` units under the rect
     of the hotspot named in `kleef_aan`, horizontally centred on it, and above it
     instead when there is no room below. `kleef` elements are placed last inside their
     layer, so the thing they glue onto already has a rectangle;
   * **`boven` (the default for a button on an object): the nearest band the element
     FITS IN with its bottom edge `≤ object_top − GAT`** — it may sit at the very top of
     that band, so the four units a 48 unit button has spare inside a 52 unit band are
     used to hug the object instead of leaving up to 51 units of quantisation gap (I1).
     Coverage is still 0 % by construction, not by iteration;
   * `onder`: the same on the other side, top edge `≥ object_floor + GAT`;
   * inside a band, the free column block nearest the aim point (`ceil(w/KOL)` columns
     wide, `ceil(h/RIJ)` bands tall); a taken block is never handed out twice, so two
     buttons cannot overlap;
   * **the two bands beside the object are weighed against each other, and the cell
     whose centre is NEAREST the object wins** (I1 finding 2). Taking the first band
     with any free cell is what put the 🔔 Bel button beside the door: the band above
     the bell exists, but its free cells are 130 units away because the notice board
     fills the rest of it. When neither band beside the object has a free block the
     element stacks elsewhere and says so: `debug()[id].gestapeld` is `true`, and that
     is the only case in which it may stand further away than one band / one column;
   * at equal priority, an element that HANGS ON AN OBJECT is placed before one that
     floats (a wish bubble, a board card): the bound one has a single good place, the
     floating one has the whole frame;
   * the band search runs twice: first for a cell block that is free **and** touches no
     object, then — only if that fails anywhere in the frame — for the free cell block
     with the least object overlap. Both passes walk the bands closest-to-the-object
     first, then the other side, then every remaining band from the top down (the HTML's
     "stacking" round);
   * if not one cell in the whole frame is free, the button falls back to its aim point
     and `debug()[id].krap` is `true`. That is a diagnosis, not a silent overlap: the
     tests fail on any `krap`;
   * **what this pass does not place, it hides** (V1 finding 1). A hotspot whose room is
     not the room in view is skipped — and its Control used to stay on the glass at
     whatever size it last had, which for a bubble made while its guest was still
     elsewhere is 0 × 0: a ten-pixel blob with the sentence spilling down the frame, one
     letter per line, for the three seconds the bubble lives. A bubble also pins its own
     minimum (its content, never under 48 × 48), so it can never be drawn as a sliver;
   * **a fixed card gives way to the counter** as well as to its own object: the desk
     footprint (`Kamer.balie`, `World.vlak_van_balie()`) carries the bell, the till, the
     book and the lamp, and a card that hides them hides what the child is counting
     (V1 finding 4). Only `midden` cards are held to it — a number tag or a name plate
     hangs on its own animal and must stay there.

The object rectangle is exact, because it comes from the baked plate
(`World.vlak_van()` / `WereldObject.vlak()`), not from a DOM measurement.

**Where that rectangle comes from, in order (W3-F1).** A caller may hand it in
(`vlak`), name the object (`obj`), or hand in neither — and the hotel's own
buttons hand in neither: they know where the bowl *is*, not how big it draws. So
when `vlak` is absent `Hits` looks the object up by position in the room (loose
things, a game's loose decor, slots, fixed decor, within `VLAK_NABIJ = 2` voxels
of the aim point) and bakes its plate rectangle. The lookup is cached per room +
`World.decor_versie()`; the rectangle is recomputed every pass, because the
camera moves. Without this, `Hits.dekking()` returned 0 % for every hotel button
simply because it had never been told what to avoid — a green number that proved
nothing. The browser probe prints `vlakken=<n>` beside `dekking_max` so the
denominator is visible.

Proven, in `res://tests/test_hits.gd` (headless) at frames 1000 × 648, 744 × 904,
296 × 314 and 676 × 320: coverage 0.00 %, every button ≥ 48 × 48, every button inside
the frame, and four buttons competing for one object do not overlap. Proven again in the
browser on the exported build: `dekking_gast_knop=0.00` in both orientations.

**With the real receptie on screen (I1).** Two more tests build the whole shell in a
SubViewport at 1024 × 768, 768 × 1024, 1280 × 800 and 360 × 740 — the camera only centres
a room when a viewport is registered, so hotspots placed against a camera at the origin
prove nothing about the room the child sees. They assert that every hotel button with an
object stands within one band (52) of it vertically and within its object's width plus one
column (56) horizontally, unless `gestapeld` says both bands were full; and that three
guests at the desk get three name plates that touch neither each other nor a button.
Against the wave-1 tree the first fails with `bel` 148 units beside the bell and the
second with plates in the button layer, overlapping each other.

**Every hotspot a finger can reach is a `BaseButton`** — `Hits` connects `pressed`, and
nothing else. A speech bubble (`UiWolk`) was a `PanelContainer` and therefore silently
swallowed every tap: the prikbord's task cards did nothing at all (I1 finding 1). A
Control that carries a Container inside a non-Container answers `inhoud_maat()` with the
size of that content, because `Button` computes its minimum size in C++ and never asks
the script.

```gdscript
Hits.maak(o: Dictionary) -> String    # id
#   o = {id, kamer, x, z, y, icoon, label, getal, badge, titel, kind, drop, klas,
#        prio, vast, d, op, volg: Callable, aan: Callable, on_weg: Callable, door,
#        vlak: Rect2}
#   kind: "btn" | "drop" | "tag" | "naam" | "kaart" | "keuzes" | "pad" | "wolk" | "bron"
#         "naam" is a guest's name plate: it is placed and RESERVED like a tag but
#         its Control lives in `Naamlaag`, under the buttons (`Ui.laag_voor`)
#   op:   "auto" | "boven" | "onder" | "midden" | "rand" | "voet"
#         "voet" is the keypad band: docked to the bottom edge of the frame,
#         horizontally centred, reserving its cells like every other element.
#   val:  Callable(lading, data) — the drop handler of a hotspot with `drop`
#   maat: Vector2 — an explicit minimum size (a tag may be smaller than 48 x 48;
#         a button never is).  The grid reserves whole cells for it.
#   kleef_aan: String — glue my top edge under the rect of that hotspot
Hits.weg(id: String) -> void
Hits.wis_eigenaar(door: String) -> void
Hits.wis_alles() -> void
Hits.voorrang(spel_id: String) -> void      # "" = nobody
Hits.leen(id, door, fn) -> bool             # ctx.hotspots.pak: borrow a hotel button
Hits.geef_terug(door: String) -> void       # ctx.hotspots.laat; wis_eigenaar does it too
Hits.spot(id: String) -> Hits.Spot
Hits.debug() -> Dictionary   # id -> {rect, vlak, dekking, op, laag, prio, krap, gestapeld}
#   gestapeld: the band directly above/below the object had no free block left
Hits.dekking(id: String) -> float           # % of its own object covered — must be 0
signal hotspot_getikt(id: String)
```

### 4.4 Cards, the keypad band and the choice strip

* A **sheet** (`Ui.blad_open`) fills the screen with its backdrop and centres a
  panel of `min(560, frame − 24)` units wide and exactly its own content tall,
  capped at 92 % of the screen and scrolling beyond that. Two Godot traps make
  that harder than it reads, and both cost W3 a review round:
  `Control.set_anchors_preset()` keeps the offsets — on a Control built in code
  that means it stays 0 × 0 — so it must be `set_anchors_and_offsets_preset()`;
  and a `Label` with autowrap reports its height *for the width it currently has*,
  which before the first layout pass is one character per line (the start screen's
  two sentences claimed 2970 units), so a sheet measures its content child by
  child at the width it will really give it (`UiThema.wrap_hoogte`).
  Two more, found by I1: `wrap_hoogte` must add the Label's own `line_spacing` per
  line (4 units here) or every child is measured 4 units short — the start screen
  then clipped its own "Verder spelen ▸" off the bottom of the sheet and a phone
  could not answer it at all; and the sheet re-measures itself one frame later
  (`UiBlad._hermeet`), because a `Button` reports a smaller minimum before its first
  layout pass than the height it really takes. The same trap hits a speech bubble,
  which pins BOTH sides of its sentence Label and sets `clip_text` so the Label's
  own guess (375 units for four words at width 1) cannot reach the sum — without
  that the prikbord's cards came back 441 units tall after "Verder spelen".
* A **sum card** (`Ui.somkaart`) is a `PanelContainer > VBoxContainer` with the mandatory
  sentence (`Label`, `autowrap`, never ellipsised), the sum line and the answer box. It is
  `vast: true`, `prio 14`, layer `VAST`; it takes its cells first and never moves.
* The **keypad** is one Control docked to the bottom of the world frame, inside the
  `KADER_ONDER = 132` unit strip the camera already keeps free. Two rows of six keys
  (112 units incl. gaps) or **one row of twelve when the frame is ≥ 660 units wide**
  (60 units). Keys are 48 × 48, 44 × 44 only below a **360 px screen** — measured on
  the window, never on the world frame, and 48 at exactly 360
  (art-sound-rules.md §16.5: `max-width:359px` drops to 44 and `min-width:360px`
  puts it back). A fingertip does not shrink because the chrome took some room;
  the shell reports the CSS size with `Ui.zet_scherm()` and the frame decides
  only the *shape*. There is no
  `binnen`/`buiten` switch, no dead zone and no switch counter: `padPlek` disappears from
  the API. Key order is unchanged: `1 2 3 4 5 ⌫ 6 7 8 9 0 ✓`.
  It is a hotspot of kind `pad` with `op: "voet"` and `vast: true`, so the band grid
  reserves its cells: a fixed card that would land on it lifts itself in whole bands
  instead of the pad sliding over the floor. There is exactly one keypad on screen —
  `kaart.open()` takes it over from whichever card had it (world.md §5.5).
* The **choice strip** is an `HBoxContainer` in a hotspot of kind `keuzes`, glued under
  the card with `kleef_aan: <card id>` (5 units, at any scale). Long words are used when
  `strip.get_combined_minimum_size().x + 8 ≤ frame_w`, short words (`kort`) otherwise —
  decided **before** the first draw, so `strookNakijken()` and the per-game width
  thresholds are gone. Pictogram **and** word, always (F4).
* A **toast** is a message over the WORLD: it is drawn in the toast layer, which covers
  the whole screen, but it is positioned inside the world frame — `Ui.toast_band()` —
  so it can never cover the chrome or a room chip (V1 finding 4: "Precies! 🎉" sat on
  the Zwembad chip while it faded). With the keypad open, or in a frame under 450 units,
  it moves to the top of that band instead of the bottom.
* At most one card, one keypad and one strip on screen at a time — unchanged rule.

### 4.5 Orientation, safe areas, breakpoints

* Both orientations are supported; the PWA manifest says `orientation: any`.
* The shell is one `MarginContainer > VBoxContainer`: chrome (HUD) · **world frame
  (`size_flags_vertical = EXPAND|FILL`)** · room bar. The frame gets every unit the chrome
  does not use — that is why the aspect-ratio caps could go (§1.3).
* Safe areas: the outer `MarginContainer` takes `max(6/12/10/12, DisplayServer.get_display_safe_area())`
  per side (4/8/4/8 in the compact landscape shell). W3 wires this.
* Breakpoints, expressed in units and evaluated on the shell, not on media queries:
  `< 360` (44 px keys, card ≈ 170 units, every sentence wraps), `< 520` (base font 17,
  footer hidden), `≥ 900 landscape` (side-by-side, `#app` cap 1180 units, centred),
  `landscape and height < 450` (compact shell: one chrome row, logo hidden, room bar
  becomes a 3-column rail beside the frame). The rail is exactly
  `3 × 48 + 2 × 4 = 152` units wide (art-sound-rules.md §16.4); the word stays and
  wraps whole under the picture, and what gives way when nine chips do not fit the
  height is the *picture* — and only at the last step the word, down to the 12 px
  floor and never below it.
* **A phone in portrait (`width < 520`, I1 finding 4).** The chrome wrapped to three rows
  and the room bar to four, which left the world 402 of 740 units — 54 %. The phone shell
  drops the two items that carry neither a number nor an action (the logo and the round
  name), which puts day · coins · stars · letters · sound on ONE row and the two round
  buttons on a second (100 units instead of 152; seven items of ≥ 48 units cannot share a
  336 unit row, so two rows is the floor), and the room bar becomes ONE horizontally
  scrolling row of whole chips (48 instead of 152) with the current room always scrolled
  into view — the map chip still opens the sheet that lists every room, so nothing is
  reachable only by swiping. Measured on the real shell: 360 × 740 → frame 326 × 558
  (54 % → 75 %), 390 × 844 → 356 × 662 (60 % → 78 %); the tablets are untouched
  (1024 × 768 → 990 × 637).
* `KADER_MIN = 200` units: if the frame would fall below it, the chrome gives way, never
  the world.
* **The extreme case, spelled out for W3.** At the smallest legal frame (200 units high)
  the camera reserves `KADER_ONDER = 132` units under the room, which leaves 68 units.
  What fits there is exactly one band: the **one-row-of-twelve keypad** (48 px keys +
  4 px gaps + 2×3 px padding = 60 units), with 8 units of air. The two-row keypad (112
  units) does **not** fit, so the rule is: `frame_h < 450` → one row of twelve, which
  needs `frame_w ≥ 620` (12·48 + 11·4); between 572 and 620 the keys drop to 44 px
  (12·44 + 11·4 = 572); below 572 units of width the strip wraps to two rows and the
  room loses 52 units instead. Everything above `frame_h ≥ 450` uses two rows of six
  (112 units) and never touches the floor, because the reserved strip is 132.

---

## 5. Scene tree and autoloads

Autoload order is the HTML script order, which is also the dependency order:

| # | name | file | owns | ticket |
|---|---|---|---|---|
| 1 | `Art` | `autoload/art.gd` | voxel baker, model registry, plate cache, palette, shading | W4 |
| 2 | `Rooms` | `autoload/rooms.gd` | the eight rooms, doors, decor, slots, floors, furniture | W1 |
| 3 | `Hits` | `autoload/hits.gd` | the button layer and the band grid | W3 |
| 4 | `World` | `autoload/world.gd` | frame, scale, camera, the room in view, the animal runtime | W1 |
| 5 | `Snd` | `autoload/snd.gd` | the 18 synthesised sounds | W4 |
| 6 | `Ui` | `autoload/ui.gd` | cards, bubbles, keypad, name plates, HUD, toasts, sheets | W3 |
| 7 | `State` | `autoload/state.gd` | the save, the band, the adaptive signal | W2 |
| 8 | `Econ` | `autoload/econ.gd` | coins, stars, letters, the bill | W2 |
| 9 | `Games` | `autoload/games.gd` | the minigame registry and lifecycle | W3 |
| 10 | `Hotel` | `autoload/hotel.gd` | the day, wishes, check-in, prikbord, HUD contents | W2 |

They keep the JS names on purpose: every line of world.md, games-a.md and games-b.md
that says `World.reis(...)` or `Ui.somkaart(...)` then reads as executable knowledge.
`project.godot` is **frozen after A1** — the autoload list is complete, so no wave-1 or
wave-2 ticket has a reason to touch it, and it cannot become a merge conflict.

Main scene, `res://scenes/main.tscn` (owned by W3):

```
Main (Node, scenes/main.gd)
├── Wereld (SubViewport, ALWAYS)
│   └── Kamer  ← instance of res://scenes/kamer.tscn   (owned by W1)
├── Achtergrond (ColorRect)                            background #FFF7EC
├── Scherm (MarginContainer, safe areas)
│   └── Kolom (VBoxContainer)
│       ├── Chroom (HFlowContainer)  HUD: day, coins, stars, letters, sound, round,
│       │                            prikbord, evening — wraps rather than shrinking
│       ├── Middenrij (HBoxContainer)
│       │   ├── Kaderdoos (PanelContainer, EXPAND|FILL)   the 5 unit frame border
│       │   │   └── Kader (Control, clip_contents)        ← the world frame
│       │   │       ├── Beeld (TextureRect ← SubViewport)
│       │   │       ├── Vanglaag (Control)  ← drop catch areas, under the buttons
│       │   │       ├── Knoplaag (Control)  ← every hotspot, card, keypad
│       │   │       └── Naamlaag (Control)  ← name plates
│       │   └── Rail (VBoxContainer)  the room bar when it stands beside the frame
│       ├── Kamerbalk (GridContainer)  room chips + map, wrapping
│       └── Voet (Label)               the footer, hidden below 520 units
├── Toastlaag (Control, mouse_filter = IGNORE)
└── Bladlaag (Control)                 the modal sheet
```

`Middenrij`, `Kaderdoos`, `Vanglaag`, `Rail`, `Voet` and `Bladlaag` are W3's; the world
frame is still exactly one Control, and hotspot coordinates are still relative to it.

`Ui.registreer_lagen(knoplaag, naamlaag, toastlaag, bladlaag, vanglaag)`,
`Ui.registreer_wortels([scherm, toastlaag, bladlaag])` (§7.5: a Control inherits a theme
only from a Control or Window ancestor, and this root is a plain Node) and
`World.registreer_viewport(subviewport, kamer_scene)` wire the autoloads to the scene;
`Kader.resized` → `World.meet(Rect2(Vector2.ZERO, kader.size))` → `World.kader_veranderd`.

### 5.1 Timing

* `World._process` runs the think tick at **15 Hz** (`TIK = 1/15`), at most 3 catch-up
  ticks per frame, resyncing past 6 — the HTML's numbers.
* Drawing is engine-paced; `World.vuil()` marks the world dirty and the room scene
  redraws. Plates are blitted, never re-emitted.
* `REIS_MS = 300` camera slide with the HTML's ease-in-out
  (`t<0.5 ? 2t² : 1 − (−2t+2)²/2`) and the 0.35 → 1 fade; the hotspots already sit at
  their destination during the slide, so a tap halfway lands on the right object.
* **Reduced motion.** Godot exposes no `prefers-reduced-motion`, so `Ui.rust_modus()`
  owns it: on the web export it reads
  `JavaScriptBridge.eval("matchMedia('(prefers-reduced-motion: reduce)').matches")` once
  at boot, elsewhere it is `false`, and a switch on the start screen can force it on.
  In rust modus nothing moves, no particles are spawned, the camera jumps instead of
  sliding, and `World.stappen()` calls `perStap` per point, puts the animal on the last
  point, gives it its end pose and resolves `true` in the same frame. A game's own waits
  keep running unchanged (X2 §1.7, Q-X2-1 in §13).

---

## 6. The game contract

### 6.1 Registration without a shared file

A game is a directory under `res://games/`. `Games.scan()` (autoload `_ready`) walks
`DirAccess.get_directories_at("res://games")`; every directory that contains
`spel.tscn` is a game and **the directory name is its id**. The scene is instantiated
once, outside the tree, only to read `definitie()`, and freed again.

That is what lets ten wave-2 workers run in parallel worktrees with **zero merge
conflicts**: adding a game touches no shared file at all — not `project.godot`, not a
registry list, not the test runner (§2.4).

Proven in the **exported** build, not only in the editor: the browser probe prints
`[probe] spellen=["_voorbeeld"]` from the running wasm, so `DirAccess` does list the PCK.
(If a future engine version breaks that, the fallback is a `games/_lijst.json` generated
by the CI step — still no hand-edited shared file. Nothing depends on it today.)

Rules for the scene:

* `res://games/<id>/spel.tscn`, root node script extends `MiniGame`;
* `_ready()` may not touch the world — the node is instantiated to be read, and again
  when the game actually starts;
* everything else the game owns lives in the same directory, including its tests
  (`test_<id>.gd`) and its own models and scenes.

### 6.2 `MiniGame` — the base class

`res://spel/minigame.gd` (`class_name MiniGame extends Node`), template scene
`res://spel/minigame.tscn`, worked example `res://games/_voorbeeld/`.

```gdscript
func definitie() -> Dictionary
#   {naam: String, kamer: String,
#    hotspot: {obj: String, icoon: String, label: String, hoog: int, dx: int, dz: int, blijf: bool},
#    unlock: Callable(N: int, band: int) -> bool,      # absent = always
#    wens: String | Array[String],                     # which wish it fulfils
#    stub: bool,                                       # true = no wish is handed out
#    taak: {id, icoon, tekst: String|Callable(state), wanneer: Callable(state) -> bool,
#           kamer: String, prio: int}}
func start(ctx: SpelCtx) -> void      # build the turn; camera is already in `kamer`
func stop() -> void                   # clean up; also runs on supersede
func avond() -> void                  # optional: the evening round started
var ctx: SpelCtx
var actief: bool                      # false the moment the game is being torn down
func na(seconden: float) -> bool      # awaitable delay, cancelled by stop(); false = stopped
```

The lifecycle the ticket asks for maps like this: **start** = `start(ctx)`; **klaar** =
`ctx.taak_klaar(naam, {sterren})`, the only way a game hands out a star and ticks its
card; **stop** = `stop()`, always called before the node is freed; **supersede** =
`Games.start(other)`, which is `stop()` of this game followed by `start()` of the next,
so a game never has to detect it; **evening** = `avond()`, called when
`Hotel.avondronde()` runs while this game is playing — the round changes, the game keeps
playing and keeps its priority until it stops itself.

Five rules, all reviewable:

1. **After every `await`, check `actief`.** An await resolves `false` when another game
   took over, and the node is freed right after `stop()`.
2. **Use `await na(s)`, never a raw `SceneTreeTimer`.** `stop()` cancels them; a timer
   that fires after `stop()` is the classic bug of the HTML version.
3. **Persist the turn in `ctx.data()`** after every step that must survive a reload.
   Awaits and timers never survive one.
4. **Everything visible goes through `ctx`**, so it carries the owner stamp and
   disappears when the game stops.
5. **Never subscribe to a window/resize signal directly**; use `ctx.ui.op_kader(fn)` and
   call the returned unsubscribe in `stop()`.

### 6.3 What a game receives — `SpelCtx`

`res://spel/ctx.gd` (`class_name SpelCtx`). One per game, cached.

```gdscript
ctx.id      : String        ctx.naam : String        ctx.kamer : String
ctx.state   -> State        # band(), tel(goed, ms), n_gasten(), s (the save dictionary)
ctx.wereld  -> World        # see §6.4
ctx.econ    -> Econ         ctx.snd -> Snd
ctx.data()  -> Dictionary   # its own drawer in the save (State.spel_data(id))
ctx.taak_klaar(naam := "", o := {})   # `sterren` (default 1), ticks the card by
                                      # `naam` AND by the game id, then saves
ctx.sluit()                           # Games.stop()

ctx.hotspots.maak(o) -> String        # owner-stamped Hits.maak
ctx.hotspots.weg(id) / wis_alles()
ctx.hotspots.bron(obj, o) -> String   # drag source with a counter
ctx.hotspots.pak(id, fn) / laat()     # borrow one of the hotel's own buttons  [W3]
ctx.ui.wolk(o) -> String              # speech bubble on an object or an animal
ctx.ui.wolk_weg(id)
ctx.ui.somkaart(obj, som, o) -> Ui.Kaart   # the mini squared-paper card + strip
ctx.ui.getal_tag(obj, n, o := {}) -> String # a bare number ON an object; n = null removes
ctx.ui.toast(tekst, soort := "")
ctx.ui.op_kader(fn) -> Callable       # unsubscribe
```

The band, the guest, the room, the day and the save slot reach the game as
`ctx.state.band()`, `ctx.wereld.dieren(kamer)` / `ctx.wereld.dier(id)`, `ctx.kamer`,
`ctx.state.s["dag"]` and `ctx.data()`.

`Ui.Kaart` (returned by `somkaart`; the card, the sentence check and the choice strip
are implemented in the skeleton, the keypad half is W3):

```gdscript
kaart.regel(zin: String)   kaart.regel2(zin: String)   kaart.som(tekst: String)
kaart.zet(tekst: String)   kaart.hulp(tekst: String)
kaart.open()  kaart.klaar()  kaart.weg()
kaart.getal() -> Variant   kaart.id : String
# o = {id, kamer, hoog, icoon, regel (mandatory), regel2, klas, pad, open, max,
#      keuzes, keuze_titel, on_ok: Callable(n, kaart)}
# keuzes = [{id, icoon, tekst, kort, kies: Callable(k, kaart)}]
# `regel2` is held to the same 8-word / 40-character budget as `regel`.
# `on_ok` and `kies` are called with as many arguments as they DECLARE (`Ui.roep`),
# so a game may write `func(n)` or `func(n, kaart)` — the reference game in
# `res://games/_voorbeeld/` uses the one-argument form.
```

`regel2` is an optional **second** sentence on its own line, drawn under `regel`
and checked against F4 **separately** (each line ≤ 8 words and ≤ 40 characters,
the pictogram on the first one). The HTML passes an array to `regel` for exactly
this; the two check-in questions of world.md §3.3 and the two-line cards of
games-a.md need it, and one joined string would break the 40-character budget
that F4 measures per sentence. `Ui.Kaart.regel(zin)` keeps writing line one;
`Ui.Kaart.regel2(zin)` writes line two. Added by W2, implemented by W3.

### 6.4 Movement — awaitable, not promises

```gdscript
World.zet(id, kamer, x, z) -> World.Dier          # teleport
World.ga(id, x, z, na := "") -> bool              # walk inside the room        [W1]
World.reis(id, kamer, o := {}) -> Array[String]   # walk through the doors      [W1]
World.slaap(id, kamer, slot) -> void                                            [W1]
World.feed(ids: Array) -> void                                                  [W1]
World.solo(id, act) / World.mood(id, stemming)                                  [W1]
World.pose(id, naam, duur_in_tikken) -> bool                                    [W1]
World.loop_naar(id, x, z, o := {}) -> bool        # awaitable
World.stappen(id, punten: Array, o := {}) -> bool # awaitable
#   o = {pose: "" | "zwem" | "spring", tempo: 1.0, per_stap: Callable(i, punt), na: String}
#   true  = the last point was reached, in end pose `na` (default "wacht")
#   false = another order took over: a new stappen/loop_naar, ga, reis, slaap, pose,
#           feest, mood("happy"), solo, leaving the room, or checking out.
#   Never an error. stappen(id, []) is true immediately; an unknown animal is false.
```

Semantics that must be kept (world.md §2.5): coordinates are voxels **in the animal's
current room** — a command never walks through a door, that stays `reis`; `tempo` scales
the whole duration linearly; walking and swimming glide through the points and brake only
for the last one (43 points along the pool cost the same time as one straight line);
jumping deliberately does not glide.

`World.decor(kamer, o) -> Dictionary` / `decor_weg` / `decor_lijst` / `decor_plek` /
`decor_wis_eigenaar` keep their world.md §1.7 behaviour, including `LOS_MAX = 48` per
room and the ownership rule (starting or stopping any game wipes the loose decor of every
other game). [W1]

W1 added, all of them additive — no signature above changed:
`World.zet(id, kamer, x, z, o)` takes an optional `{naam, kind, acc, nr}`;
`sync(gasten)` / `zet_dag(dag)` / `weg(id)` keep the world in step with the save;
`ding(id)` / `dingen(kamer)` / `zet_ding(id, o)` are the two movable things of
world.md §1.3; `zet_bak(kamer, slot, 0..4)` / `bak_stand()` / `voer_niveau(n, per)` are
the feeding bowls of §2.8; `accessoire(id, naam, aan)`, `feest(ids)`, `slaapt(id)`,
`behoefte_klaar`, `voeg_bed`, `plaats_meubel`, `getal_tag` are the calls the wave-2
specs make on `ctx.wereld`; `naam_punt(id)` gives `Ui` the point a name plate hangs on;
`vlak_van()` takes an optional anchor and `vlak_van_dier(id)` fills it in for a guest;
`glij()` is how far the world is between two ticks (the room scene glides on it) and
`pauzeer(aan)` is the hidden-tab switch of world.md §6.6.
A world model is named after world.md §1.7 (`bed`, `plant`, …); a guest is
`gast_<kind>` with `params {pose, acc}` and the bowl is `Art.kom(niveau, g, voor)`.

### 6.5 Lifecycle, worked out: one turn of `wekker`

The exact call sequence, band 4, day 2, guest #2 of the row, from the child's tap on the
prikbord card to the star. Every call is a real signature from this document.

```
 1  Hotel: card "⏰ Wekker zetten" tapped
       Hotel.bord_dicht(); State.s["ronde"] = "vrij"; Hotel.naar_kamer("gang")
 2  Games.start("wekker")
       (a running game, if any) -> Games.stop()
       Hits.voorrang("wekker")          # its buttons are VIP, wish bubbles step aside
       Hotel.render()
       World.naar("gang")               # 300 ms slide, hotspots already at their target
       node = load("res://games/wekker/spel.tscn").instantiate(); add_child(node)
       node._spel_start(ctx)            # -> MiniGame.start(ctx), actief = true
 3  wekker.start(ctx):
       var herstel := ctx.data()        # resume only if dag/N/band match and the turn
                                        # is not `af` and the guest still exists
       var rij := rijtje()              # sleeping guests with a bed, else guests with a
                                        # bed, else all guests; first three
       var band := ctx.state.band()     # 4
       var k := Sommen.klok(band, dag)  # frozen: {u:13, m:45, stap:15}
       doel = doelTijd(band, dag, idx)  # per-guest shift, games-b.md §2.3
       afst = afstand(band, N, dag)     # how far the hands must travel
       start = doel − afst  (mod 12 h)
 4    the clock model, its own parameterised voxel model.  The name is qualified
      with the game id, because `klok` alone would collide with a world model
      (§13 Q-X1-11) and `registreer_model` refuses those:
       Art.registreer_model("wekker_klok", _klok_voxels)      # once, in start()
       ctx.wereld.decor("gang", {"id": "klok", "model": "wekker_klok",
                                 "x": 48, "z": 1, "hoog": 34, "ver": true,
                                 "params": {"u": start_u, "m": start_m}})
 5    keep the dial free (games-b.md §2.6):
       ctx.hotspots.maak({"id": "wk_plaat", "kind": "tag", "kamer": "gang",
                          "x": 48, "z": 1, "y": 34, "op": "midden", "prio": 13,
                          "titel": "de wijzerplaat",
                          "maat": Vector2(d, d)})     # invisible, reserves the cells
 6    the card under the clock:
       var kaart := ctx.ui.somkaart("klok", "nu: kwart voor 11",
            {"id": "wk_som", "hoog": 3, "icoon": "⏰", "pad": false,
             "regel": "Muis wil om half 3 op",       # <= 8 words, <= 40 chars  (F4)
             "keuze_titel": "draai de klok",
             "keuzes": [
               {"id": "uur", "icoon": "🕐", "tekst": "uur erbij", "kort": "uur", "kies": ...},
               {"id": "kwartier", "icoon": "🕒", "tekst": "kwartier erbij", "kort": "kwartier", "kies": ...},
               {"id": "klaar", "icoon": "✅", "tekst": "Klaar", "kies": ...}]})
       # somkaart checks the sentence against F4, builds the card, and glues the
       # strip under it with kleef_aan; the strip measures itself synchronously
       # and picks `kort` when the long words do not fit the frame
 7    the bubble at the guest:
       ctx.ui.wolk({"id": "wk_gast", "volg": <the guest>, "hoog": 54,
                    "icoon": "💤", "tekst": "half 3"})
 8  child taps "kwartier erbij":
       draai(15) -> params.m += 15; ctx.wereld.decor(...) with the new params
                    -> Art.plaat("klok", g, params) bakes exactly one new image
       kaart.som("nu: 11 uur"); ctx.snd.klok()        # throttled: never twice in 120 ms
 9  child taps "✅ Klaar", wrong:
       missers += 1; ctx.snd.zacht()                  # never a buzzer  (F5)
       kaart.hulp("💛 draai nog wat verder")          # 2nd miss: ghost hands on the dial
       ctx.data()["missers"] = missers; State.bewaar()
10  child taps "✅ Klaar", right:
       ctx.state.tel(missers == 0, Time.get_ticks_msec() - t0)
       ctx.snd.klok(); await na(0.22); ctx.snd.ja()
       kaart.regel("Muis is wakker"); kaart.hulp(""); kaart.klaar()
       ctx.ui.wolk_weg("wk_gast")
       World.naar(gastkamer)                          # the waking happens in her room
       World.pose(gast, "blij", 60)
       ctx.ui.wolk({"id": "wk_zon", "volg": <guest>, "hoog": 54,
                    "icoon": "☀", "tekst": "goedemorgen"})
       ctx.taak_klaar("wekker", {"sterren": 1})       # 1 star, card ticked, save
       Hotel.render()                                 # the star appears in the bar now
       if not await na(2.2): return                   # cancelled if the game was stopped
       volgende()                                     # next guest, or:
11  round finished:
       ctx.ui.wolk({"id": "wk_af", "obj": "klok", "icoon": "⏰",
                    "tekst": "allemaal gewekt"})
       if not await na(2.2): return
       ctx.ui.wolk_weg("wk_af"); ctx.sluit()
12  Games.stop():
       node._spel_stop() -> actief = false; every na() timer cancelled;
                            MiniGame.stop() (own decor away, listeners off);
                            ctx.hotspots.wis_alles()
       Hits.wis_eigenaar("wekker"); Hits.voorrang(""); Hotel.render()
       node.queue_free()
```

Every call above exists in the skeleton with that signature; `res://games/_voorbeeld/`
walks the same path in miniature (own model → `decor` → `wolk` → `somkaart` with a
choice strip → awaited walk with the `actief` check → `taak_klaar` → `sluit`) and the
browser probe plays it through in the exported build (§14.4).

Supersede is exactly step 12 followed by step 2 for the new game; a game never has to
detect it. Any `await` still in flight resolves `false`, and rule 1 of §6.2 makes the
game return instead of touching a torn-down world.

---

## 7. Project settings, web export, CI

### 7.1 `project.godot` — every key that matters

```ini
config_version=5

[application]
config/name="Dierenhotel"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
config/icon="res://icon.svg"
boot_splash/bg_color=Color(1, 0.968627, 0.925490, 1)   ; warm paper, no black flash
boot_splash/show_image=false

[autoload]                    ; the ten of §5, in this order
Art / Rooms / Hits / World / Snd / Ui / State / Econ / Games / Hotel

[display]
window/size/viewport_width=1024
window/size/viewport_height=768
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=6          ; sensor: portrait and landscape

[input_devices]
pointing/emulate_touch_from_mouse=true
pointing/android/enable_long_press_as_right_click=false

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/canvas_textures/default_texture_filter=1      ; nearest; plates blit 1:1
environment/defaults/default_clear_color=Color(1, 0.968627, 0.925490, 1)
anti_aliasing/quality/msaa_2d=0
```

The `.mobile` renderer override is not optional: without it a mobile-tagged run falls
back to the Vulkan Mobile method and the web export dies (T0 §4).

### 7.2 `export_presets.cfg` — the Web preset

Taken verbatim from toolchain.md §3 with three project-specific values. The keys that
decide the build:

* `variant/thread_support=false` — selects `web_nothreads_release.zip`, which needs no
  `SharedArrayBuffer` and therefore no COOP/COEP headers. **That is the entire reason
  GitHub Pages can host this**, and it is why iOS Safari works. Never turn it on.
* `export_filter="all_resources"` — everything under `res://` is packed. With
  `resources` the game-directory scan of §6.1 would find scenes the packer left out.
* `script_export_mode=2` — compressed binary tokens.
* `html/canvas_resize_policy=2` (adaptive) + `stretch/mode=canvas_items` — the canvas
  follows the browser window, which is what §4.1 assumes.
* `texture_format/etc2_astc=true`, `s3tc_bptc=false` — the mobile family only.
* `progressive_web_app/enabled=true`, `display=1` (standalone), `orientation=0` (any),
  `ensure_cross_origin_isolation_headers=false` (it must stay false with threads off),
  `background_color=Color(1, 0.968627, 0.92549, 1)`.
* `html/head_include` carries the three meta tags the HTML page had:
  `viewport = width=device-width, initial-scale=1, viewport-fit=cover`,
  `color-scheme = light`, `theme-color = #FFF7EC`. `viewport-fit=cover` is what makes
  the safe-area insets of §4.5 meaningful on a notched device.
* `export_path="build/web/index.html"`, and `build/.gdignore` **must** exist, or the next
  import pass eats the exported PNGs back into the project (T0 gotcha G2).

### 7.3 The two commands

```bash
godot --headless --import --path godot/dierenhotel
mkdir -p godot/dierenhotel/build/web            # Godot does not create it (G1)
godot --headless --path godot/dierenhotel --export-release "Web" build/web/index.html
```

`tools/test.sh` gives every run its OWN `user://` (a temp `XDG_DATA_HOME`, removed
afterwards, overridable with `DH_USERDATA`). That path is per USER, not per checkout, so
ten worktrees running their suites in parallel — wave 2 — and a CI job on the same runner
otherwise share one `dierenhotel.json`: `test_state.gd` writes a corrupt-save fixture and
another process replaces it with a valid save between two lines, failing a test that is
perfectly correct (V1-F1).

Exit codes are honest; errors carry an `ERROR:` prefix on stderr. Output: 15 files,
40,006,159 B, of which `index.wasm` is 39,514,754 B (**10,084,297 B gzipped**) and
`index.pck` is 108,500 B. Serve with compression. `index.service.worker.js` is the only
non-deterministic artefact (its `CACHE_VERSION` is a timestamp) — never checksum-gate it.

### 7.4 GitHub Actions — export + Pages, and the tests (W6)

Two workflows, both on `ubuntu-latest`, both `sudo`-free.

```yaml
# .github/workflows/test.yml — on every push and pull request
name: test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    env: { GODOT_VERSION: 4.7.2-stable }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/cache@v4
        with:
          path: ~/.local/opt/godot
          key: godot-${{ env.GODOT_VERSION }}
      - name: Install Godot (editor only, no templates)
        run: |
          set -euo pipefail
          if [ ! -x ~/.local/opt/godot/Godot_v${GODOT_VERSION}_linux.x86_64 ]; then
            mkdir -p ~/.local/opt/godot && cd /tmp
            base=https://github.com/godotengine/godot/releases/download/$GODOT_VERSION
            curl -sSL -O $base/SHA512-SUMS.txt
            curl -sSL --retry 3 -O $base/Godot_v${GODOT_VERSION}_linux.x86_64.zip
            sha512sum -c <(grep 'linux\.x86_64\.zip' SHA512-SUMS.txt | grep -v mono)
            unzip -o -q Godot_v${GODOT_VERSION}_linux.x86_64.zip -d ~/.local/opt/godot/
            chmod +x ~/.local/opt/godot/Godot_v${GODOT_VERSION}_linux.x86_64
          fi
          mkdir -p ~/.local/bin
          ln -sfn ~/.local/opt/godot/Godot_v${GODOT_VERSION}_linux.x86_64 ~/.local/bin/godot
          echo "$HOME/.local/bin" >> $GITHUB_PATH
      - name: Import
        run: godot --headless --import --path godot/dierenhotel 2>&1 | tee import.log
      - name: No import errors
        run: '! grep -qE "^ERROR:|SCRIPT ERROR:" import.log'
      - name: Tests
        run: godot --headless --path godot/dierenhotel --script res://tests/run_tests.gd
```

```yaml
# .github/workflows/pages.yml — on push to main
name: pages
on:
  push: { branches: [main] }
  workflow_dispatch:
permissions: { contents: read, pages: write, id-token: write }
concurrency: { group: pages, cancel-in-progress: true }
jobs:
  build:
    runs-on: ubuntu-latest
    env: { GODOT_VERSION: 4.7.2-stable }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/cache@v4
        with:
          path: ~/.local/share/godot/export_templates
          key: godot-templates-${{ env.GODOT_VERSION }}
      - name: Install Godot + web templates
        run: |            # as above, plus:
          set -euo pipefail
          d=~/.local/share/godot/export_templates/4.7.2.stable
          if [ ! -f $d/web_nothreads_release.zip ]; then
            cd /tmp
            base=https://github.com/godotengine/godot/releases/download/$GODOT_VERSION
            curl -sSL --retry 3 -O $base/Godot_v${GODOT_VERSION}_export_templates.tpz
            unzip -q Godot_v${GODOT_VERSION}_export_templates.tpz -d /tmp/tpl
            rm -rf $d && mkdir -p $(dirname $d) && mv /tmp/tpl/templates $d
            # keep only what the Web preset needs (G6: the full set is 2.0 GiB)
            find $d -type f ! -name 'web_nothreads_*' ! -name 'version.txt' -delete
          fi
      - name: Export
        run: |
          godot --headless --import --path godot/dierenhotel
          mkdir -p godot/dierenhotel/build/web
          godot --headless --path godot/dierenhotel \
                --export-release "Web" build/web/index.html
      - uses: actions/upload-pages-artifact@v3
        with: { path: godot/dierenhotel/build/web }
  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: { name: github-pages, url: "${{ steps.deployment.outputs.page_url }}" }
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

Notes for W6: `gh auth login` has not been run on this machine (T0 §1), so the owner must
enable Pages once in the repository settings (Source: GitHub Actions). Pages serves
`.wasm` gzipped automatically. No COOP/COEP headers are needed *because* threads are off.
The browser probe of §14 should run in `test.yml` too once W6 has a Playwright step; the
swiftshader flags of T0 gotcha G4 apply on a runner as well.

### 7.5 Fonts and emoji (W3, decision)

The layout was measured against Comic Sans; a web export cannot rely on any installed
font. Decision:

* **Text: one bundled rounded sans with a full Dutch glyph set** — `Nunito` (SIL OFL),
  pinned to two static instances (400 / 700) and subsetted to Latin-1 plus the
  punctuation F3 needs (`− … × € ≤ ≥`): `fonts/Nunito-Regular.ttf` and
  `fonts/Nunito-Bold.ttf`, 45 kB each. Base 18 px, 17 px below 520 units.
  **Measured (W3, `tests/test_ui.gd::test_kaartzin_past_op_een_regel`): the sum card's
  sentence renders at the 12 px floor size (14 px at base 18), where 34 characters take
  236 units — inside the card's 270 unit sentence width, so the one-line guarantee of F4
  holds to at least 37 characters.** Below a 360 unit frame the card is 170 units wide
  and every sentence wraps to a second line instead of shrinking.
* **Symbols: `Noto Sans Symbols 2` (SIL OFL), subsetted to three glyphs** —
  `fonts/Symbolen.ttf`, 6.5 kB. Nunito has neither `⌫` nor `✓` nor `▸`, and neither does
  Noto Color Emoji; without this the keypad and `Verder spelen ▸` would be tofu.
* **Emoji: a subset of `Noto Color Emoji` (SIL OFL)** — `fonts/Emoji.ttf`, 200 kB for
  111 glyphs; the CBDT/CBLC colour bitmaps are subsetted with them (24 MB → 200 kB).
* All three are **fallbacks on one `FontFile`**, so one Label carries Dutch letters,
  keypad symbols and colour emoji without any call site knowing. The glyph inventory is
  `fonts/tekens.txt` and `fonts/maak-fonts.sh` rebuilds all three subsets from it. (This
  document first named that script `tools/emoji-subset.sh`; it lives next to the fonts
  because `tools/` is not in W3's write set and it builds the text subsets as well.)
  `tests/test_ui.gd::test_alle_schermteksten_hebben_een_glyph` scans every child-facing
  shell string, every room name, every keypad key and every number word for a glyph the
  subset does not carry.
* **The theme is stamped on the shell's top-level Controls, not only on the Window.**
  A Control inherits a theme from a Control or Window *ancestor*, and `scenes/main.tscn`
  has a plain `Node` as its root (§5), so `get_window().theme` never reaches `Scherm`.
  `Ui.registreer_wortels([...])` closes that, and the shell test asserts that a Label
  inside the chrome really reads the bundled font — the tofu this caused was invisible
  to an assertion on `Ui.thema` itself.
* The OFL text of all three fonts sits next to them in `fonts/`. Those `.txt` files are
  **not** packed into the PCK (`export_filter="all_resources"` packs resources only); a
  one-line `include_filter="fonts/*.txt"` in `export_presets.cfg` would ship them with
  the build. That file is frozen, so the change is proposed, not applied.

---

## 8. Sound

`Snd` synthesises; **no samples ship**. The two generators of X4 §15.2 (`noot` with its
exponential attack of `min(35 ms, 30 % of the duration)` and exponential decay, and
`papier`, band-passed white noise with a linear fade) render into a `PackedFloat32Array`,
which becomes a 16-bit mono `AudioStreamWAV` at 22 050 Hz, played on one of six
`AudioStreamPlayer` voices. Master gain stays **0.16** — "altijd zacht, nooit hard".

* Oscillator-only sounds are cached per name; **noise sounds are rebuilt per call**, so
  every splash is a new one, exactly as in the browser (X4 §15.4 finding 1).
* `plop(hand)` keeps its parameter: `480 + 40·hand` Hz. Samples could not do that.
* **No sound before the first real input**: `Snd.ontgrendel()` is called from the first
  touch/click, and every sound is silent before it. That satisfies the browser autoplay
  policy without the 1-sample-buffer trick.
* **The save owns the mute, the first tap owns the unlock** (V1 finding 2). `Snd.schakel()`
  is the child's toggle and writes `geluid` into the save; `Snd.stem_af(aan)` only reads
  it, and the shell calls it whenever `State.s` is replaced — a fresh game, "Verder
  spelen ▸", "Nieuw spel" — and once on the first input. Deciding the mute *on* that
  first input was wrong: the first input IS the tap on "Verder spelen ▸", which happens
  before the saved state is swapped in, so a saved `geluid=false` came back on for the
  whole session. Proven in chromium by tee-ing every AudioContext into an analyser:
  peak 0 after the reload (`.fanout/scratch/godot-w3/opslag-probe.js`).
* Mute is persisted in the save (`s["geluid"]`), not in a separate key.
* There are no angry sounds. `zacht` means "not yet" and is the most-used sound in the
  game; it is never a buzzer (F5).

**All eighteen are in** (W4). The oracle is `tests/gouden/wav/*.wav` — the eighteen
sounds as the browser renders them offline at 48 kHz, trimmed to their audible length
plus 30 ms of tail, 445 kB instead of 2.6 MB of silence — with
`tests/gouden/snd-oracle.json` beside it: per sound the sample count, peak, RMS, audible
length, an RMS envelope in 16 slices, and the spread over **eight** independent export
runs. Nothing depends on `/tmp` any more (W4-F1). `res://tests/test_snd.gd` reads the
WAVs back (a hand-parsed RIFF, because the folder is `.gdignore`d) and asserts peak
(±1 dB), audible length (±10 ms), sample count, format, mix rate **and the RMS envelope
against the browser's own render** — the last one is what catches a wrong envelope, a
wrong glide or a wrong filter, which a peak measurement sleeps through. Measured worst
case: peak −0.52 dB (`munt`, a triangle whose apex a 22 050 Hz sampler misses), length
±2 ms, envelope ≤ 0.71 dB per slice for the fourteen oscillator sounds and ≤ 2.4 dB for
the four that carry noise.

**The `kar` level, reconciled** (W4-F1). X4 §15.3 prints −29.6 dBFS and the first export
−31.5; the review asked which is right. Neither is wrong: `kar` is
`papier(0.24, 300, 0.26)` plus a tone, and `papier()` draws from `Math.random()`, so its
peak is a random variable. Eight fresh exports of the untouched HTML give **−31.77 …
−29.90 dBFS, mean −31.06** — both published numbers are draws from that one
distribution, and this port's mean (−31.0) sits on top of it. The same holds for `brief`
(−28.85 … −26.09) and `plons` (−23.24 … −21.54); `deur` is fixed at −28.87 because its
peak comes from the tone, not from the noise. All fourteen oscillator sounds are
bit-identical across all eight runs. `snd-oracle.json` therefore carries the mean and the
range, and the test measures the noise sounds against the *distribution* instead of
against one lucky splash.

Three things W4 had to settle to make that comparison honest:

* **`papier` is a real bandpass.** WebAudio's `BiquadFilterNode` of type `bandpass` is
  the RBJ constant-0-dB-peak biquad; a one-pole approximation is several dB out. It is
  ported as that biquad, `Q = 0.7`.
* **The noise is normalised for the sample rate.** White noise carries its power per
  *sample*, so the same bandpass at 22 050 Hz passes a louder band than at the 48 kHz the
  reference was rendered at. The factor is the ratio of the two filters'
  impulse-response energies (0.689 at 300 Hz, 0.732 at 1500 Hz — a flat
  `sqrt(SR/48000)` is not enough, the digital bandwidth is frequency-warped). Without it
  every splash is 3.4 dB too loud.
* **The four noise sounds need a statistical form of the ±1 dB.** Their peak is a random
  variable by design (fresh noise per call, X4 §15.4 finding 1) and the export froze one
  particular splash; a single render sits between −1.9 and +1.6 dB from that one. The
  test therefore asserts the mean over 48 renders within 1.5 dB (measured: `brief` −0.39,
  `deur` +0.07, `kar` +0.57, `plons` −0.84), that the frozen peak lies inside the range
  this generator produces, and the median audible length within 10 ms.

(The old `snd-meta.json` was deleted with it: two files describing the same eighteen
sounds is one source of truth too many.)

`Snd.klok()` is throttled at 120 ms (§6.5, step 8), `Snd.monster(naam)` and
`Snd.stream(naam)` hand a test the raw buffer or the finished stream without waking the
band, and `Snd.namen()` lists the eighteen in the order of X4 §15.3. Generating all
eighteen, WAV encoding included, costs **69 ms** once.

Proven in the browser as well (`.fanout/scratch/w4/probe-geluid.js`, chromium with the
real autoplay policy, one finger tap on a hotspot): the page is patched before Godot
boots so every `AudioContext` is recorded and everything that connects to `destination`
is tee'd into an `AnalyserNode`. Peak leaving the engine **before** the first touch:
`0.000000`. **After** one tap: `0.065132`, one context in state `running`, zero console
errors. That measures the samples, not a log line.

---

## 9. Save format

**A new document, version 1, no migration.** `user://dierenhotel.json` (IndexedDB on the
web, so it survives a reload and an "Add to Home Screen" install). Written atomically:
`dierenhotel.json.tmp` then rename.

```json
{"v": 1, "s": { ... }}
```

`s` carries the same semantic fields as save v7 (world.md §4.2):

| field | type | meaning |
|---|---|---|
| `dag` | int ≥ 1 | day number |
| `ronde` | `ochtend` \| `vrij` \| `avond` | the round |
| `munten`, `sterren` | int | coins, stars |
| `band` | 3..5 | recomputed on load anyway |
| `kunnen` | 3..5 | adaptive ability level |
| `signaal` | array of `{g: 0\|1, t: ms}` | last ≤ 10 items |
| `gasten`, `wachtlijst` | array of guest records | in the hotel / in the queue |
| `famIdx` | int | family + sentence cursor for the letters |
| `meubels` | array of `{id, kamer, type, x, z, rot, soort}` | bought furniture |
| `meubelNr` | int | furniture id counter, must survive a reload |
| `taken` | array of task cards | today's board |
| `brieven` | array of `{titel, tekst, dag}` | the letter wall |
| `scoops`, `levering`, `snoeppot` | int | food store, days to delivery, sweets jar |
| `kar` | any | trolley state (voerkar) |
| `spel` | object id → object | one drawer per minigame (`ctx.data()`) |
| `gezien` | object key → 1 | which explanations have been seen |
| `kamerNu` | room id | the room in view |
| `uitcheck` | array of guest ids | guests due to leave |
| `nieuweGast` | guest record or null | the guest standing at the desk |
| `checkin` | object or null | a half-finished check-in |
| `rekening` | object or null | a half-counted bill: `{gastId, fam, nachten, prijs, totaal, stap, pogingen, telPog, wisselPog, hand: [int], bank: [int], t0, tw}` (Q-X1-4) |
| `geluid` | bool | replaces the separate `kws-geluid` key |

Rules:

* **No migration from the HTML saves.** The Godot build lives on another origin and
  cannot read `localStorage` at all; v5/v6/v7 and `naarV7` are dropped.
* **Corrupt or foreign file → start screen with a fresh hotel.** Unparsable JSON, a
  wrong `v`, a missing `s`: `State.lees()` returns `false`, nothing is half-loaded and
  nothing is thrown. Tested (`test_skelet.gd::test_opslag_rondrit`).
  A valid envelope is not enough: `lees()` shape-checks **every** field of the table
  above down to the leaves it will later index (a list is a list, a counted field is a
  number, `rekening.hand`/`rekening.bank` are lists of numbers), then normalises and
  repairs a **candidate** copy, checks the shape once more, and only then swaps it in.
  A hand-edited blob therefore never half-loads and never reaches a `for` over a
  String. Tested with fourteen broken files (`test_state.gd::test_kapotte_opslag_geeft_het_startscherm`).
* **Nothing is saved before the start screen has been answered** (`State.start_gekozen()`),
  so looking at the start screen can never destroy a save.
* **JSON has no integers.** Every number returns as a float; `State._normaliseer()` casts
  the counted fields back to `int` on load. W2 must extend that list when it adds fields.
* Saved after: assigning a bed, feeding, playing, `wens_af`, a finished bill, every
  `ctx.taak_klaar`, every accessory change, furniture changes, `morgen()`, and on
  `NOTIFICATION_WM_CLOSE_REQUEST` / `NOTIFICATION_APPLICATION_PAUSED`.
* `rekening` is now saved as well (Q-X1-4 in §13): a reload in the middle of a bill
  resumes it instead of losing the counted coins. It leaves the save the moment the
  bill is **paid** — before the 1100 ms the goodbye bubble hangs there (world.md §3.5)
  and therefore before `Econ.rekening_klaar` fires, so a reload during that beat can
  never resume a bill that is already settled. The guest is only removed from `gasten`
  by that callback, so the 👋 bubble always has an animal to hang on.
* `meubels`/`meubelNr` are mirrored out of `Rooms` on every `Rooms.kamers_veranderd`
  (`Hotel.bewaar_inrichting`) and replayed into the rooms at boot
  (`Hotel.herstel_inrichting`). `Rooms.herstel()` alone is the **base** layout and would
  throw away every bought bed — and with it the guest cap — on each start.

---

## 10. Input and dragging

* **Touch first.** `pointing/emulate_touch_from_mouse = true` so a desktop mouse
  produces touch events during development.
* **`emulate_mouse_from_touch` stays at Godot's default `true`** — a deliberate deviation
  from the ticket's wording, for a hard reason: `Control`/`BaseButton` handle
  `InputEventMouseButton`, so with the emulation off **no card, keypad key or hotspot
  would react to a finger**, and this architecture puts every child-facing element in a
  Control. The emulation converts, it does not duplicate: the browser probe taps once and
  the game logs exactly one press (`tik=1`). Raw `InputEventScreenTouch` /
  `InputEventScreenDrag` remain available for anything that needs multi-touch.
* **Single-fire taps** come from `BaseButton.pressed`, not from a swallowed follow-up
  click. The HTML's capture-phase click swallowing disappears.
* **Tap targets ≥ 48 × 48 units** (44 only below a 360-unit frame width), enforced in
  `Ui.maak_knop()` and asserted by `test_hits.gd`.
* **Dragging** uses Godot's built-in Control drag-and-drop (`_get_drag_data`,
  `_can_drop_data`, `_drop_data`) with `Control.set_drag_preview()`:
  * the preview is offset **40 units up** from the finger, so the child can see the
    target (world.md §5.7);
  * a drop target is a Control whose rectangle is the **union of the button and its
    object** (the HTML's `vangvlak`), which is what makes "drag onto the object itself"
    work; it is created automatically for every hotspot that declares `drop`;
  * a movement under **8 units** is a tap, not a drag;
  * the games that drag, from the specs: `voerkar` (the trolley to a door
    `[data-drop="deur"]` and to a bowl `[data-drop="bak"]`), `meubels` (a piece from the
    box onto the floor grid), `kraam` (coins to the counter, `kr_geld`), `tobbe` (an
    animal into a tub), `bedden` (a bed from the chest onto a strip), `was` (a piece of
    laundry into a crate, `krat`), `sleutels` (a key onto a hook). Drop names stay the
    same strings; `Hits` matches them by name instead of by CSS selector.

---

## 11. The skeleton, file by file

`godot/dierenhotel/` — everything below imports, exports and runs (§14).

| path | what it is | ticket that fills it |
|---|---|---|
| `project.godot` | §7.1, complete; **frozen** | — |
| `export_presets.cfg` | §7.2, complete | — |
| `.gitignore` | `.godot/`, `build/web/` | — |
| `build/.gdignore` | mandatory (T0 G2) | — |
| `icon.svg` | the app icon: the reception bell and one paw print | W3 |
| `ui/**` | the shell's Controls: theme, card, keypad, choice strip, bubble, source, number tag, name plate, HUD, room bar, map, sheet, catch area, and every verbatim shell string (`ui/teksten.gd`) | W3 |
| `fonts/**` | the three bundled OFL subsets, their licences, the glyph inventory and the script that rebuilds them (§7.5) | W3 |
| `core/jsgetal.gd` | JS integer semantics (§2.1) | W5 (frozen) |
| `core/sommen.gd` | the frozen number core (§2.2) | W5 adds the planbord solver |
| `autoload/art.gd` | the voxel baker, complete and under test; two placeholder models | W4 adds the real models |
| `autoload/rooms.gd` | the eight rooms, doors, floors, slots, furniture (§1 of world.md) | W1 |
| `autoload/hits.gd` | the band grid, complete and under test | W3 refines the widgets |
| `autoload/world.gd` | scale, camera, projection, `vlak_van`, a walking animal, `stappen` | W1 |
| `autoload/snd.gd` | both generators + 6 of the 18 sounds | W4 |
| `autoload/ui.gd` | layers, button factory, toast, `wolk`, `somkaart` (card + mandatory-sentence check + glued choice strip), `meervoud`/`woord`, `op_kader`, `rust_modus`; keypad, `bron`, `getal_tag` stubbed | W3 |
| `autoload/state.gd` | the save envelope, defaults, atomic write, corrupt rule, band, `tel` | W2 |
| `autoload/econ.gd` | stars, coins; the bill stubbed | W2 |
| `autoload/games.gd` | the directory-scan registry and the lifecycle | W3 |
| `autoload/hotel.gd` | signals only | W2 |
| `spel/minigame.gd` + `spel/minigame.tscn` | the base class and its template scene (§6.2) | — |
| `spel/ctx.gd` | `SpelCtx` with owner stamping (§6.3) | W3 completes `pak`/`laat` |
| `scenes/main.tscn` + `main.gd` | the shell, one unit = one CSS px, probe lines | W3 |
| `scenes/kamer.tscn` + `kamer.gd` | the four-layer room scene | W1 |
| `scenes/vloer.gd` | floor + walls as one `ArrayMesh` in voxel-px, drawn in one call | W1 |
| `scenes/dier.gd` | one guest: gliding position, ground shadow, water band | W1 |
| `wereld/voor.gd` | the `Voor` layer: the 💤 over a sleeper and the particles | W1 |
| `wereld/proefwereld.gd` | the vertical slice of §14.4, only with `?demo=1` / `--demo` | W1 |
| `tools/test.sh` | the test command CI uses: suite + stderr gate (§2.4) | W5 |
| `scenes/wereldobject.gd` | the node every thing in a room is | W1 |
| `games/_voorbeeld/spel.tscn` + `spel.gd` | the reference game: exercises the whole contract | — |
| `tests/run_tests.gd`, `tests/proef.gd` | the runner (§2.4) | W5 |
| `tests/test_sommen.gd` | every worked example of the frozen core | W5 |
| `tests/test_hits.gd` | both placement invariants, five frame sizes, four adversarial shapes | W3 |
| `tests/test_skelet.gd` | autoloads, baker, registry scan, save round trip, band | W1 |

The placeholder room `proefkamer` (48 × 36, wall 24) and the two placeholder models
`proef_dier` / `proef_blok` proved the vertical slice **without any real world
content**. W1 removed all three together with `scenes/proef_modellen.gd`; the two
assertions in `tests/test_skelet.gd` that named them now bake a 4 × 4 × 4 cube of the
test's own, so the plate geometry of §3.2 is still asserted on a shape whose box is
known by hand. What the slice proved is now proved by the world itself: the browser
probe of §14.4 loads the exported build with `?demo=1`, which is the only thing that
starts `res://wereld/proefwereld.gd` — two guests walk in the receptie, one sleeps in
kamer1, one swims in the pool, and the camera visits all eight rooms. Without that flag
not one line of it runs, so a child never sees it.

---

## 12. The ticket plan

### 12.1 Wave 1 — six tickets, disjoint write sets

No two tickets write the same file. `project.godot` and `export_presets.cfg` are frozen;
any change to them goes through the foreman.

| # | ticket | write set (under `godot/dierenhotel/` unless stated) | depends on | what the skeleton already gives it |
|---|---|---|---|---|
| **W1** | world + rooms + guests + movement | `autoload/rooms.gd`, `autoload/world.gd`, `scenes/kamer.tscn`, `scenes/kamer.gd`, `scenes/vloer.gd`, `scenes/wereldobject.gd`, `scenes/dier.gd`, `wereld/**`, `scenes/proef_modellen.gd` (deletes it), `tests/test_rooms.gd`, `tests/test_world.gd`, `tests/test_skelet.gd` | `Art.plaat`, `Sommen.Prng/hash2`, `Hits.maak` | projection, `schaal()`, `cam_doel()`, `vlak_van()`, the 15 Hz tick, `stappen()` as a coroutine, the four-layer room scene, `WereldObject` |
| **W2** | hotel: day cycle, economy, wishes, prikbord, save | `autoload/hotel.gd`, `autoload/econ.gd`, `autoload/state.gd`, `tests/test_hotel.gd`, `tests/test_econ.gd`, `tests/test_state.gd` | `Rooms.*`, `World.*`, `Ui.*` (signatures in §4–6), `Sommen.*` | the save envelope + atomic write + corrupt rule, `band()`, `tel()`, `spel_data()`, `Econ.sterren/geef_munt`, every `Hotel` signal |
| **W3** | UI shell: cards, keypad, HUD, room bar, sheets, start screen | `autoload/ui.gd`, `autoload/hits.gd`, `autoload/games.gd`, `spel/ctx.gd`, `spel/minigame.tscn`, `scenes/main.tscn`, `scenes/main.gd`, `ui/**`, `fonts/**`, `icon.svg`, `tests/test_ui.gd`, `tests/test_hits.gd` | `World.mik_punt/vlak_van/kader_veranderd`, `Hotel` signals, `State` | the band grid (working, tested), the button factory, toast, `wolk`, `op_kader`, the registry, `SpelCtx`, the shell that keeps 1 unit = 1 CSS px |
| **W4** | art baker + sounds | `autoload/art.gd`, `autoload/snd.gd`, `art/**`, `tests/test_art.gd`, `tests/test_snd.gd`, `tests/gouden/**` | nothing (pure) | the whole baker (culling, shading, spans, `omlijn`, `rondAf`, LRU), both sound generators, six sounds |
| **W5** | the frozen number core + the runner | `core/sommen.gd`, `core/jsgetal.gd`, `tests/run_tests.gd`, `tests/proef.gd`, `tests/test_sommen.gd`, `tools/test.sh` | nothing | 13 of the frozen functions with their worked examples green, the JS integer semantics, the runner |
| **W6** | CI + GitHub Pages | `.github/workflows/test.yml`, `.github/workflows/pages.yml`, `tools/*.sh` (outside the Godot project) | §7.3, §7.4 | the exact commands and their measured output |

Order: **W1, W4, W5 start immediately** (no dependency on each other). **W3** starts
immediately as well — it owns files the others do not touch and codes against the
signatures in §4–§6. **W2** may start immediately against the documented `Rooms`/`World`
signatures and tests its logic through `State` and signals, not through pixels; it merges
after W1. **W6** any time.

Two integration points to watch, both named here so no worker invents them:

* `Ui.somkaart()` draws its card, checks the mandatory sentence and glues its choice
  strip, but has no keypad yet (`open()` is a no-op, `getal()` reads the box). W2 must
  not depend on typed answers before W3 lands; it asserts on `State` and on `Hotel`
  signals.
* `Rooms.get_kamer()` returns only `proefkamer` until W1 lands. Anything that needs a
  real room id must go through `Rooms.lijst()`.
* **The hotspot owner `"hotel"` is reserved for `Hotel.hotspots()`**, which opens with
  `Hits.wis_eigenaar("hotel")` and rebuilds that whole layer on every `Hotel.render()`
  — the doors, the bell, the prikbord, the beds, the bowls, the play basket and the
  wish bubbles. A button somebody else stamps `door: "hotel"` therefore disappears at
  the next render (and `Games.stop()` calls one). Test fixtures and games use their own
  owner name; a game that wants one of the hotel's buttons borrows it with
  `ctx.hotspots.pak(id, fn)` (§6.3). **(W1 landed: the eight real rooms are
  there, `proefkamer` is gone.)**

### 12.2 Wave 2 — one ticket per game, confined to `res://games/<id>/`

Write set of every ticket: **`godot/dierenhotel/games/<id>/**` and nothing else** —
scene, script, own models, own tests (`test_<id>.gd`, picked up automatically by the
runner). Each runs in its own git worktree so the parallel headless runs do not share one
`.godot/` cache.

| id | naam | kamer | hotspot obj / icon | unlock | wens | taak (prio) | spec |
|---|---|---|---|---|---|---|---|
| `bedden` | Bedden op rij | kamer1 | `mand` 🛏 | N ≥ 1 | – | `bedden` (5) | games-a §3 |
| `sleutels` | Het sleutelbord | receptie | `sleutelbordz` 🔑 | N ≥ 2 | – | `sleutels` (5) | games-a §4 |
| `meubels` | Het meubelboek | receptie | `boek` 📖 | N ≥ 3 | – | `meubels` (5) | games-a §5 |
| `tobbe` | Tobbe-tijd | tuin | `tobbe` 🛁 | N ≥ 1 | `bad` | `bad` (1) | games-a §6 |
| `voerkar` | De voerkar | keuken | `kar` 🛒 | N ≥ 1 | – | hotel task `voer` | games-a §7 |
| `zwembad` | Zwembad | zwembad | `mat` 🏊 | N ≥ 1 | `zwemmen` | `zwemles` (1) | games-b §1 |
| `wekker` | Wekkerdienst | gang | `kist` + offset ⏰ | N ≥ 1 | – | `wekker` (3) | games-b §2 |
| `hinkel` | Hinkelpad | tuin | `hok` 🪨 | N ≥ 1 | `spelen` | (2 or 5) | games-b §3 |
| `was` | Wasmandtoren | wasserij | `tobbe` 🧺 | N ≥ 1 | – | `was` (8) | games-b §4 |
| `kraam` | Souvenirkraam | tuin | `bal` 🎁 (offset) | N ≥ 1 | `souvenir` | `souvenir` (1) | games-b §5 |

Interfaces every wave-2 ticket depends on, and nothing else:
`MiniGame` (§6.2) · `SpelCtx` (§6.3) · `World.stappen/loop_naar/pose/decor/dieren/dier/vlak_van`
(§6.4) · `Hits.maak/weg` through `ctx.hotspots` (§4.3) · `Ui.somkaart/wolk/bron/getal_tag`
through `ctx.ui` (§4.4) · `Snd.<naam>()` (§8) · `Sommen.*` (§2.3) · `ctx.taak_klaar`,
`ctx.data()`, `ctx.sluit()`.

Games that need a model the world does not have register it themselves
(`Art.registreer_model("<id>_<naam>", fn)`, §13 Q-X1-11) — that is the whole reason the
model registry exists.

Definition of done for a wave-2 ticket: the turn plays at bands 3, 4 and 5; every string
matches the spec verbatim; `Hits.dekking` is 0 % for every button on an object in four
frame sizes; the sum card obeys F4 (≤ 8 words, ≤ 40 characters, sentence present); the
turn survives a reload from `ctx.data()`; `stop()` leaves the world clean; the suite runs
green headlessly.

---

## 13. Every open question of the four wave-0 specs, answered

`world.md` §8 — Q-X1-n:

| # | question | decision |
|---|---|---|
| 1 | idle randomness seeded from `Date.now()` | **Seed deterministically**: `Sommen.Prng.new(Sommen.hash_tekst(gast_id) ^ dag * 2654435761)`. Same day, same guest, same wandering — reproducible bugs and deterministic tests. W1 |
| 2 | garden tufts need JS 32-bit semantics | **Bit-identical required.** `Sommen.Prng` is mulberry32 through `JsGetal.imul`; W1 asserts the 30 tuft positions in a test |
| 3 | `taken` saved but rebuilt from a fingerprint | **Confirmed, keep saving.** A ✅ earned today survives a reload. W2 |
| 4 | `rekening` never written | **Gap closed.** The bill is part of the save (§9); a reload resumes the counted coins. W2 |
| 5 | `geslapen` counts a full night after a late bed | **Confirmed, keep.** Generous, never punishing |
| 6 | the day planner is frozen but unused | **Port the solver** (W5, it is frozen math and cheap); **do not surface it** in this run |
| 7 | `badGast` uses `gasten[0]` | **Change to the wish rotation** so every guest gets a tub turn. Not a generator, so F1 is untouched. W2 |
| 8 | `wensAf('kamer')` silently returns false | **Programming error**: `Hotel.wens_af` pushes a warning and returns false. W2 |
| 9 | two evening entrances with different conditions | **Keep both, make them agree**: the desk lamp shows `🌙 Morgen ▸` when there is nobody to check out. W2 |
| 10 | frame constants tuned against CSS | **Re-derived in §4.** Hard rules: the floor is never cut, the prikbord stays visible, ≥ 48 px targets, ≥ 12 px text, `KADER_MIN = 200`, `KADER_ONDER = 132`, `WAND_ZICHT = 56`. Dropped as HTML workarounds: the 60 % fill rule, the 300/340 keypad dead zone, the aspect-ratio caps |
| 11 | `registerModel` name policy | **Namespaced and enforced**: `Art.registreer_wereldmodel()` (W1/W4) marks a name protected; `Art.registreer_model()` (a game) refuses a protected name outright and warns when the name is not `<spel>_<naam>` |
| 12 | wasserij / zwembad never entered on their own | **Confirmed**, idle wandering never leaves a room; both are reached by a game or a wish |
| 13 | **the receptie desk stands in the walking line** (raised by the owner on the first screenshots, not by X1) | **Owner decision, overrides world.md §1.3 for this one room.** In the HTML the door to the gang is in the back-right wall (`z`, at 87) *behind* the L-shaped desk, and a guest walking in walks straight through the desk. In the port the desk is **one straight run along the back-right wall** (`balie` at 48,20 and 83,20, with `bel` 36, `kassa` 60, `boek` 84 and the desk lamp 99 on it) and the **door moved to the back-left wall** (`wand: "x", at: 24` → point (0,30), inside (8,30)). The room keeps its size, its mat, its key board and its notice board (moved to x 12 so the desk cannot hide it). Because the desk now hugs one wall, the floor a guest may stand on is the **convex** strip `z ≥ 36` (`Kamer.vrij_z0`), and its footprint is `Kamer.balie = {28..102, 13..27}`: every straight walk between the door, the mat, the waiting places and the wander places stays in front of it. `tests/test_rooms.gd::test_niemand_loopt_door_de_balie` asserts exactly that, over every pair of those places. W1. **I1:** the bill's counting counter moved with the desk — `TOONBANK = plek(0.15, 0.5) = (18, 60)` was the arm of the old L-shaped desk and is open floor in the walking line now, so `HotelRekening` counts on the till (`kassa`, and otherwise the middle of the `Kamer.balie` footprint) and the bill's cards hang over the desk; `tests/test_econ.gd::test_toonbank_ligt_op_de_balie` holds it there and cross-checks that no walking cell lies on the desk |

`games-a.md` §9 — Q-X2-n:

| # | question | decision |
|---|---|---|
| 1 | game timers in rust modus | **Unchanged length.** They are reading time, not animation time (§5.1) |
| 2 | `taakKlaar('meubel')` vs task id `meubels` | **Contract already ticks both** name and game id; meubels passes `"meubels"` |
| 3 | `kiesBlanco` may give fewer blanks | **Acceptable, keep** |
| 4 | `MAXBLANCO[band]` also picks the guests | **Documented as intended**: the first `MAXBLANCO[band]` guests in check-in order |
| 5 | bedden may shrink to 1 × 1 | **Floor raised**: below capacity 2 the game says "vol ✓"; 1 × 1 is not a sum |
| 6 | tobbe band 5 `per` ≥ 10 unreadable | **Cap `per` at 8** when the frame is under 400 units |
| 7 | voerkar may show a divisor outside the band's tables | **Keep** — the child divides objects, not tables |
| 8 | meubels `wacht.nog` unbounded | **Cap at 3**, the number of pick-up buttons |
| 9 | meubels shows at most 3 own pieces | **Keep the cap**; a fourth request answers "leg eerst iets neer" |
| 10 | sleutels' door plates cleaned up on stop | **Keep cleaning up**; a permanent world change belongs in the save |
| 11 | port the unused frozen functions? | **Yes, all of them** (W5). They anchor F1 |
| 12 | merge the two LCGs? | **Two functions.** Their arithmetic genuinely differs (§2.1); merging invites exactly that mistake |

`games-b.md` §6 — Q-X3-n:

| # | question | decision |
|---|---|---|
| 1 | zwembad upper window 80 or 76 | **80** — the specified factual behaviour |
| 2 | `zwembad.keuzeGetallen` LCG byte-identical? | **Yes, F1 applies.** 32-bit LCG with `& 0x7fffffff` through `JsGetal` |
| 3 | `was.prng` shuffle order | **Must match**; the Fisher-Yates loop stays descending |
| 4 | `was.meetIndeling` leans on `Hits.debug()` | **Provided**: `Hits.debug()` keeps the name and returns `{rect, vlak, dekking, op, laag, prio}`; `World.vlak_van()` gives exact object rects. C1/C2 stay enforceable |
| 5 | rust modus and the games' own waits | **Unchanged** (see Q-X2-1) |
| 6 | wekker: ghost hands at the 2nd or 3rd miss | **2nd** — HOTEL.md §5 is the design source and the code agrees |
| 7 | wekker: 12-hour clock without am/pm | **Keep.** The hotel has no day/night; the child reads a clock face |
| 8 | hinkel: a wrong answer still jumps, no attempt cap | **Keep** — never punishing |
| 9 | hinkel `melding: 'start'` | **Drop the field** |
| 10 | kraam: €10 change equals the price | **Keep**; a legitimate sum |
| 11 | kraam: the 🎒 bag is never buyable | **Stays decor** in this run |
| 12 | `was` `k = 0` emergency branch | **Port it**, and assert in a test that it is unreachable for every (N, band) |
| 13 | per-game frame thresholds | **Replaced** by §4.3/§4.4. The goal (a card never touches the animal or the diagram) is enforced by `Hits.dekking` in tests, not by pixel thresholds |
| 14 | prikbord rotation among equal low chips | **Ported as is** (`roteerSpel`, the fix from run 1). W2 |

`art-sound-rules.md` §19 — Q-X4-n:

| # | question | decision |
|---|---|---|
| 1 | which font ships | **Nunito (OFL), bundled**; W3 re-measures the ≤ 34-character one-line guarantee against it (§7.5) |
| 2 | which emoji font | **Subsetted Noto Color Emoji** (~70 glyphs) + a test that scans every child-facing string for a missing glyph (§7.5) |
| 3 | accessories on a lying goose | W4 renders the 4 × 15 × 7 contact sheet once and fixes what looks wrong **in the model** |
| 4 | `komFaces` cache key | Moot: one LRU keyed `naam\|g\|params` |
| 5 | two dead CSS rules | **Do not port them** |
| 6 | `Snd.plop(hand)` | **Keep the parameter** (§8) |
| 7 | noise determinism | **Fresh noise per call**, as in the browser |
| 8 | reduced motion and the 💤 | **Confirmed**: a still image, it stays |
| 9 | `KADER_ONDER` versus the keypad strip | **One owner**: the camera reserves 132 units, the keypad lives in that band; the strip is gone (§4.4) |
| 10 | text-to-speech | **Out of scope this run.** `Ui.spreek()` exists as a no-op so a later `JavaScriptBridge` implementation needs no call-site change |
| 11 | should button gaps scale with `q`? | **No.** They are fingertip distances in CSS px, not world distances |
| 12 | dark mode / high contrast | **Light only**, confirmed |

---

## 14. Verification — the exact commands, and what they produced

All four were run from the repository root, `/home/pc/Documents/xnw/rkn`, against the
skeleton as committed. `godot` is `~/.local/bin/godot` = 4.7.2.stable.official.ed1daf0bf.
Logs and screenshots: `.fanout/scratch/godot-a1/`.

### 14.1 Import (from a deleted `.godot/`, i.e. cold)

```bash
rm -rf godot/dierenhotel/.godot
godot --headless --import --path godot/dierenhotel
```

exit **0**, `grep -cE "^ERROR:|SCRIPT ERROR:"` → **0**. Log:
`.fanout/scratch/godot-a1/import-clean.log`.

### 14.2 Web export

```bash
mkdir -p godot/dierenhotel/build/web            # required, T0 gotcha G1
godot --headless --path godot/dierenhotel --export-release "Web" build/web/index.html
```

exit **0**, `grep -cE "^ERROR:|SCRIPT ERROR:"` → **0**. Log:
`.fanout/scratch/godot-a1/export-clean.log`. Output: **15 files, 40,006,159 B**, of which
`index.wasm` 39,514,754 B (**10,084,297 B gzipped**), `index.js` 279,815 B, `index.pck`
108,500 B. No `.import` files leaked into `build/web` (`.gdignore` works).

### 14.3 Tests

```bash
godot --headless --path godot/dierenhotel --script res://tests/run_tests.gd
godot/dierenhotel/tools/test.sh      # the same, plus the stderr gate; what CI runs
```

exit **0** — **22 goed, 0 fout, 61 ms**:

```
ok  test_hits.gd.test_knop_dekt_zijn_voorwerp_nooit     # 0 % coverage, 5 frame sizes
ok  test_hits.gd.test_vaste_kaart_reserveert_haar_plek  # the reviewer's card case
ok  test_hits.gd.test_voorwerp_bovenaan_wijkt_naar_onder
ok  test_hits.gd.test_tien_knoppen_op_een_voorwerp
ok  test_hits.gd.test_twee_knoppen_delen_geen_plek
ok  test_skelet.gd.test_autoloads_bestaan               # all ten autoloads
ok  test_skelet.gd.test_baker_maakt_een_plaat           # plate size + LRU cache hit
ok  test_skelet.gd.test_registry_vindt_voorbeeld        # directory scan, no shared file
ok  test_skelet.gd.test_opslag_rondrit                  # save round trip + corrupt file
ok  test_skelet.gd.test_band_en_signaal
ok  test_sommen.gd.test_js_integer_semantiek            # the float64 LCG proof of §2.1
ok  test_sommen.gd.test_dag_rnd / test_zaadje / test_hash2
ok  test_sommen.gd.test_koekjes_som / test_vergelijk / test_deel / test_tafel
ok  test_sommen.gd.test_geld / test_klok / test_band / test_munten
```

Two red-to-green proofs, both run and then reverted:

* **The placement invariant.** Removing the one line that makes a `midden` card reserve
  its cells (the bug the review found) turns
  `test_vaste_kaart_reserveert_haar_plek` red: `21 goed, 1 fout`. Restored: `22 goed,
  0 fout`.
* **The runner's error gate.** A throwaway `tests/test_kapot_tijdelijk.gd` whose body is
  `var leeg: Node = null; leeg.get_name()` reports
  `FOUT test_kapot_tijdelijk.gd.test_stille_crash / 1 motorfout(en) tijdens de test`,
  `22 goed, 1 fout`, and **exit code 1** from both `run_tests.gd` and `tools/test.sh`
  (the wrapper additionally prints `FOUT: de motor logde fouten tijdens de suite`).
  Before this fix the same test printed `ok` and the suite exited 0. The file was
  deleted again; the suite is back at `22 goed, 0 fout`, exit 0.
* **A broken test file** (added W5-F1, after the review found the hole). A throwaway
  `tests/test_kapot.gd` was made unloadable in three ways — a syntax error, a type error
  the analyser rejects, and a file with no `test_` method at all. Before the fix the
  **bare** command printed `… goed, 0 fout` and exit 0 for all three (only `tools/test.sh`
  caught them, through stderr). After it, each reports its own `FOUT test_kapot.gd: …`
  line and **exit 1** from the bare command too. The file was deleted again.

### 14.4 Browser probe (chromium via Playwright 1.60.0, swiftshader)

```bash
cd godot/dierenhotel/build/web && python3 -m http.server 8741 --bind 127.0.0.1 &
node .fanout/scratch/godot-a1/probe.js            # kill the server afterwards
```

Chromium is launched headless with `--enable-unsafe-swiftshader --use-gl=angle
--use-angle=swiftshader` (T0 gotcha G4). Two profiles, both `hasTouch`, `isMobile`,
`deviceScaleFactor 2`. Result: **PROBE OK**.

| profile | viewport | canvas | boot | console errors | warnings | failed requests |
|---|---|---|---:|---:|---:|---:|
| ipad-land | 1024 × 768 | 2048 × 1536 | 2224 ms | **0** | 0 | 0 |
| ipad-port | 768 × 1024 | 1536 × 2048 | 2020 ms | **0** | 0 | 0 |

What the run proves, from the game's own console lines (`shots/rapport.json`):

```
[probe] venster=(2048, 1536) css=(1024, 768) dpr=2.0        -> 1 unit = 1 CSS pixel
[probe] kader=(1000.0, 648.0) viewport=(2000, 1296) g=4 dicht=2.000 k=2.000
[probe] spellen=["_voorbeeld"]                              -> DirAccess scans the PCK
[probe] platen=8                                            -> the baker ran in the browser
[probe] dekking_gast_knop=0.00                              -> 0 % coverage, structurally
[probe] tik=1                                               -> one finger tap = one press
[probe] gelopen naar=(36.0, 28.0)                           -> awaited walk resolved true
[probe] spel=start id=_voorbeeld kamer=proefkamer           -> registry + lifecycle
[probe] spel=klaar sterren=1                                -> ctx.taak_klaar gave one star
[probe] vb_som=[P: (414.0, 248.5), S: (180.0, 83.0)] dekking=0.00
[probe] vb_som_keuzes=[P: (414.0, 336.5), S: (180.0, 48.0)] dekking=0.00
                                   -> the strip is glued 5 px under the card, no overlap
[probe] spel=stop stap=1 sterren=1                          -> stop() ran, state persisted
```

Screenshots: `.fanout/scratch/godot-a1/shots/{ipad-land,ipad-port}.png`,
`…-na-tik.png`, `…-kaart.png` (the sum card with its sentence and its glued choice
strip, in the running wasm build), `…-spel.png`. Machine-readable: `shots/rapport.json`. The probe exits
non-zero if any profile has a console error, a failed request, more than one press per
tap, or a missing lifecycle line, so it can be dropped into CI as is.

**Two lines the shell owes the probe (I1).** `[probe] kaart <id>=<rect>` is printed when
a sum card opens, so "a tap produced a card" is positive evidence and not the absence of
a second press; and the whole `[probe] knop <id>=` block is printed AGAIN after the start
screen is answered, because "Verder spelen" restores a saved day and the hotel lays its
buttons out for that day — a probe that kept tapping the boot rectangles tapped empty
glass. Both wait two frames: a tap is handled after `Hits.plaats()` in the same frame on
the web export, so one frame of waiting reports the previous layout.

### 14.5 What is NOT verified yet, and by whom

* ~~No dpr-3 profile and no phone profile were run in the browser~~ — **done by W3**:
  `.fanout/scratch/godot-w3/probe.js` runs six profiles on the exported build
  (1024 × 768 @2, 768 × 1024 @2, 1280 × 800 @2, 360 × 740 @3, 740 × 360 @3 and
  1024 × 768 @3, the last one proving the density cap of §4.2a: `dicht` stays 2.03 and
  the SubViewport stays 2008 × 1292 at dpr 3). All six: 0 console errors, 0 warnings,
  0 failed requests, one finger tap = one press, `krap=0`, `dekking_max=0.00`.
  Screenshots and `rapport.json`: `.fanout/scratch/godot-w3/shots/`.
* The baker was never measured against the golden images — there is no real model yet.
  W4 (§3.6).
* Sound was not heard in the browser; the probe only proves that nothing errors before
  the first input. W4 adds an offline render comparison against `/tmp/dh-snd/meta.json`.
* Performance under a full room (16 buttons, 4 guests, 12 decor pieces) is unmeasured.
  W1 reports it with the first real room.
