# X1 — Dierenhotel Kwispelsteeg: the world outside the minigames

Port specification for Godot 4.7 (GDScript). Source of truth: `demos/dierenhotel/`
(`rooms.js`, `world.js`, `hotel.js`, `state.js`, `econ.js`, `hits.js`, `ui.js`,
`game.js`, `games/registry.js`, `index.html`, `style.css`, `snd.js`, `art.js`) as of
commit `e8c9bd2`. Everything below was read out of that code; statements that are not
directly in the code are marked **(inferred)**.

Scope: the hotel world, its state, the day cycle, the save format, the game contract and
the UI shell. The five golf‑1/2 games are specified in `games-a.md` (X2), the golf‑3 games
in `games-b.md` (X3), art/sound/style in `art-sound-rules.md` (X4). Where those overlap,
this document gives the world side of the contract only.

---

## 0. Coordinate system, units and the drawing model

Everything in the world is expressed in **voxels**.

| symbol | value | meaning |
|---|---|---|
| `S` | 2 | half-width of one voxel in *voxel-px* (`Art.kit.S`) |
| `HG` | 2 | height of one voxel in voxel-px (`Art.kit.HG`) |
| `g` | integer 2..4 | voxel-px → canvas-px multiplier (the **voxelmaat**) |
| `dicht` | ≥ 1, may be fractional | canvas-px per css-px |
| `q` = `k` | `g / dicht` | css-px per voxel-px |

Axes: `x` runs to the lower right, `z` to the lower left, `y` upwards. The two back walls
of a room stand on the planes `x = 0` and `z = 0`; the floor is `w × d` voxels.

Projection (world.js `schermX`/`schermY`/`projectie`), in canvas-px:

```
screenX = camX + (x - z) * S * g
screenY = camY + (x + z) * (S / 2) * g - y * HG * g
```

In css-px within the frame that is `x_css = (x−z)·2k`, `y_css = (x+z−2y)·k`.
`World.schaal()` returns `{g, dpr, k, pxPerVoxelX: 2k, pxPerVoxelY: k, pxPerHoogte: 2k}`
(`dpr` here is `dicht`, **not** `devicePixelRatio` — never use the device ratio for layout).

**Painter order.** One list per frame, sorted ascending on depth `d`; small = far away =
drawn first. Depth defaults to `x + z`, with `+0.3` for decor that has a `y`/`hoog`,
`−1000` for `ver` (wall decor, always at the back), `+0.5` for a sleeping animal, and
`+0.2` for a loose "ding" (the food trolley). The hotspot layer copies this ordering into
its `z-index` exactly (see §5.4).

**Worked example.** A guest standing at `(30, 40)` in kamer1 (`g = 3`, `dicht = 3`,
`k = 1`) sits at canvas `(camX + (30−40)·2·3, camY + (70)·1·3) = (camX − 60, camY + 210)`
and at css `((30−40)·2 = −20 px, (70)·1 = 70 px)` relative to the camera origin.

---

## 1. Rooms (`rooms.js`)

### 1.1 The eight rooms

Room order in `Rooms.lijst()` is the order below; it drives the room bar, the map, and the
direction of the camera slide.

| # | id | naam | icoon | w × d | wand | vloer | loop | special |
|---|---|---|---|---|---|---|---|---|
| 0 | `receptie` | `Receptie` | 🛎️ | 120 × 120 | 54 | `hout` | 1.5 | mat 45..99 × 78..114, colours `#E9BFC9`/`#E3B4C0` |
| 1 | `gang` | `Gang` | 🚪 | 120 × 36 | 56 | `loper` | 1 (default) | – |
| 2 | `kamer1` | `Kamer 1` | 🛏️ | 114 × 114 | 58 | `zacht` | 1.5 | mat 51..93 × 45..87, `#DFCBEA`/`#D6BFE4` |
| 3 | `kamer2` | `Kamer 2` | 🛏️ | 114 × 114 | 58 | `zacht` | 1.5 | mat 51..93 × 45..87, `#CBE3D6`/`#BFDBCB` |
| 4 | `keuken` | `Keuken` | 🍪 | 120 × 114 | 56 | `tegel` | 1.5 | – |
| 5 | `tuin` | `Tuin` | 🌳 | 130 × 130 | 0 | `gras` | 1 | `erf: 1`, fixed frame `[-170, 190, -70, 220]`, `zones` |
| 6 | `zwembad` | `Zwembad` | 🏊 | 144 × 88 | 50 | `tegel` | 1.5 | `bad`, `dek` |
| 7 | `wasserij` | `Wasserij` | 🧺 | 100 × 90 | 52 | `tegel` | 1.25 | – |

`loop` is the walking-speed multiplier of that room (the rooms grew 1.5×, the animals did
not, so a guest crosses a big room in the same wall-clock time as before).

**Room box** (`Rooms.kader`), in voxel-px, used by the camera:

```
box = [ -d*S - 10 , w*S + 10 , -wand*HG - 12 , (w+d)*(S/2) + 10 ]
```

| room | box | box w × h |
|---|---|---|
| receptie | `[-250, 250, -120, 250]` | 500 × 370 |
| gang | `[-82, 250, -124, 166]` | 332 × 290 |
| kamer1 / kamer2 | `[-238, 238, -128, 238]` | 476 × 366 |
| keuken | `[-238, 250, -124, 244]` | 488 × 368 |
| tuin | `[-170, 190, -70, 220]` (literal, floor runs on beyond it) | 360 × 290 |
| zwembad | `[-186, 298, -112, 242]` | 484 × 354 |
| wasserij | `[-190, 210, -116, 200]` | 400 × 316 |

### 1.2 Doors and the door graph

A door is `{naar, wand: 'x'|'z', at, breed}`; `at` is the start of the gap along the wall.
`Rooms.deur(kamer, naar)` returns the derived point: for `wand: 'z'`,
`{x: at + breed/2, z: 0, ix: at + breed/2, iz: 8}`; for `wand: 'x'`,
`{x: 0, z: at + breed/2, ix: 8, iz: at + breed/2}`. `(ix, iz)` is the step *inside* the
room where an animal stands before walking through. `poort: 1` marks a garden gate (no
door hole is cut in a wall; the tuin has no walls).

| from | to | wand | at | breed | door point (x, z) | inside (ix, iz) |
|---|---|---|---|---|---|---|
| receptie | gang | z | 87 | 12 | (93, 0) | (93, 8) |
| gang | receptie | x | 10 | 12 | (0, 16) | (8, 16) |
| gang | kamer1 | z | 24 | 12 | (30, 0) | (30, 8) |
| gang | kamer2 | z | 60 | 12 | (66, 0) | (66, 8) |
| gang | keuken | z | 96 | 12 | (102, 0) | (102, 8) |
| kamer1 | gang | z | 72 | 12 | (78, 0) | (78, 8) |
| kamer2 | gang | z | 72 | 12 | (78, 0) | (78, 8) |
| keuken | gang | x | 75 | 12 | (0, 81) | (8, 81) |
| keuken | tuin | z | 90 | 12 | (96, 0) | (96, 8) — `poort` |
| keuken | wasserij | x | 30 | 12 | (0, 36) | (8, 36) |
| tuin | keuken | x | 34 | 12 | (0, 40) | (8, 40) — `poort` |
| tuin | zwembad | z | 38 | 12 | (44, 0) | (44, 8) — `poort` |
| zwembad | tuin | x | 60 | 12 | (0, 66) | (8, 66) |
| wasserij | keuken | z | 62 | 12 | (68, 0) | (68, 8) |

`Rooms.pad(van, naar)` is a breadth-first search over this graph; it returns the full path
*including* the start room (`['gang','kamer1']`), `[van]` when `van === naar`, and `[]`
when a room does not exist. Example: `pad('kamer1','zwembad')` =
`['kamer1','gang','keuken','tuin','zwembad']`.

### 1.3 Fixed decor per room

Decor entries are `{n, x, z, y?, ver?, params?, sleutel?}`. `ver` means "always draw first"
(wall decor). Two entries are lifted out of the decor list at boot by `world.js`
`bouwDingen()` — every entry with a `sleutel` and every entry named `kar` — and become
movable **dingen**: `balielamp` (receptie 15, 105, y 14) and `kar` (keuken 48, 66).

| room | decor (model @ x, z [, y]) |
|---|---|
| receptie | `balie` @ 40,60 · `balie` @ 75,60 · `baliez` @ 15,58 · `baliez` @ 15,93 · `bel` @ 33,60 y14 · `kassa` @ 66,60 y14 · `boek` @ 15,75 y14 · `lamp` @ 15,105 y14 (→ ding `balielamp`) · `prikbord` @ 39,1 `ver` · `sleutelbordz` @ 1,84 `ver` · `plant` @ 105,18 · `plant` @ 108,81 |
| gang | `plant` @ 44,8 · `plant` @ 82,8 · `kist` @ 114,14 |
| kamer1 | `plant` @ 102,12 · `mand` @ 93,99 |
| kamer2 | `plant` @ 12,99 · `mand` @ 93,99 |
| keuken | `kast` @ 33,6 · `zak` @ 66,18 · `kar` @ 48,66 (→ ding `kar`) · `plant` @ 108,93 |
| tuin | `boom` @ 16,68 · `hok` @ 67,19 · `tobbe` @ 32,94 · `bal` @ 120,76 · `kist` @ 95,23 · `poort` @ 10,40 `ver` · plus generated fence and grass tufts (below) |
| zwembad | `mat` @ 9,28 (the entry mat on the deck) · `plant` @ 136,80 |
| wasserij | `kast` @ 28,6 · `tobbe` @ 80,74 |

The balie is an **L**: two `balie` pieces along x (35 voxels heart-to-heart) and two
`baliez` along z, so the four objects on it stay far apart on screen.

**Garden fence and tufts** (`bouwTuin`, deterministic, runs once at load):

* `HEK_X = HEK_Z = 10`.
* `hekz` posts at `x = 10`, `z = 10, 24, 38, … ≤ 130`, **skipping** `34 ≤ z ≤ 46` (the gate
  to the kitchen).
* `hekx` posts at `z = 10`, `x = 24, 38, … ≤ 130`, **skipping** `38 ≤ x ≤ 50` (the opening
  to the pool).
* 30 grass tufts `pol0..pol4` from a seeded PRNG (`prng(90210)`, the same
  `a += 0x6D2B79F5` / `Math.imul` mulberry-style generator used for animals). Per iteration
  `i`: `u = round(r()*300 − 150)`, `w = 24 + round(r()*220)`, `px = (u+w)/2`,
  `pz = (w−u)/2`. A tuft is kept only if `px > 12 && pz > 12`, it is ≥ 22 (Manhattan) away
  from every large object `[(16,68),(67,19),(32,94),(120,76),(95,23)]`, and it is outside
  both reserved zones inflated by 4 voxels. Model name is `'pol' + (i % 5)`.
  The port must reproduce this PRNG bit-for-bit if the garden is to look identical
  (32-bit unsigned arithmetic, `Math.imul`).

**Garden zones** (`Rooms.get('tuin').zones`, data only — the games place their own props):

| zone | rectangle | size |
|---|---|---|
| `hinkel` | x 24..100, z 34..50 | 76 × 16, in front of the doghouse |
| `kraam` | x 104..126, z 36..68 | 22 × 32, along the right edge |

**Pool** (`Rooms.get('zwembad')`):

* `bad = {x0: 18, x1: 134, z0: 12, z1: 44}` — water is a floor rule, not a model
  (116 × 32 voxels = 81 % of the room width), with a 4-voxel stone rim around it
  (x 14..138, z 8..48).
* `dek = {start: {x: 12, z: 56}, over: {x: 132, z: 56}}` — the two standing places on the
  deck, 12 voxels in front of the waterline.
* A lane of `L` metres maps linearly: `x(p) = 18 + 116 · p / L`, swim lane `z = 28`.
* **Rule:** never put a standing or wander place in the water. All wander places, the door
  and both deck places lie in the convex strip `z ≥ 50`, so no straight walk crosses the
  pool.

### 1.4 Floors and walls

`Rooms.vloerKleur(r, x, z)` decides the colour of one 1×1 floor cell; the floor plate is
baked in 4×4 blocks (`x, z` stepping 4, colour taken at the block origin). `hash2(x,z) =
(imul(x*73856093 ^ z*19349663, 2654435761) >>> 24)`.

Order of the rules:

1. `r.matten`: inside `[x0,x1) × [z0,z1)` → `kl[hash & 1]`.
2. `vloer === 'gras'`: `x < 10 || z < 10` → `WEI = ['#9DC486','#98C081'][hash&1]`, else
   `GRAS = ['#AFD595','#AAD190','#B4D89A','#ACD392'][hash&3]`.
3. `r.bad`: inside the water → outer 4 voxels `BADKANT = ['#5AA3C2','#66ABC8'][hash&1]`,
   inner `BADWATER = ['#9CD1E4','#A9D8E6','#93CBE0','#A2D4E5'][hash&3]`; in the 4-voxel
   ring around it `BADRAND = ['#FFFDF3','#FCF8EA'][((x>>2)+(z>>2))&1]`.
4. `tegel` → `['#EDE6DA','#D9E6E2'][((x>>2)+(z>>2))&1]`.
5. `loper` → middle strip `8 ≤ z < d−6` gets `['#D68FA0','#CE8496'][(x>>2)&1]`, else
   `['#E9DCC6','#E2D3BA'][hash&1]`.
6. `zacht` → `['#E6D3B8','#DFC9AC'][(z>>2)&1]`.
7. default (`hout`) → `((z>>2)&3) === 0 ? '#D2B58C' : ['#E4CBA6','#DCC29B'][(z>>2)&1]`.

**Walls** (`bouwWand`, only for rooms with `wand > 0`; the tuin has none): both back walls
are drawn as flat quads on the baked floor plate. Wall `z` (running along x, facing +z)
uses `#DFC6A8` with band `#E9D4BA`; wall `x` uses `#EDD8BC` with band `#F5E5CE`. Every
segment gets a skirting `y 0..3` in `#C08F6B` and a rail `y 9..10.4` in the band colour.
Door openings (`poort` doors excluded) are cut to height `min(wand − 6, 26)`: dark hole
`#7A6250`, lighter lintel strip `#9C8168` over the top 1.2 voxels, wall above the opening,
and a frame of `HOUT_D #B98F62` posts 1 voxel wide plus a `HOUT #D0A87A` lintel 1.4 high.
The wall top cap is `#FCF0DE`, 3 voxels deep. A 10 %-alpha `#6E5A4A` shadow strip 4 voxels
wide lies where each wall meets the floor. A radial vignette
(`rgba(120,96,70,0)` → `.18`) is painted over the whole plate.
The tuin instead fills the plate with `#AAD190` and tiles diamond cells of 4 voxels out to
8 voxels beyond the frame, so the lawn runs on past the edge.

### 1.5 Derived data (`bouwAf`, recomputed after every furniture change)

* `r.box` — see §1.1.
* `r.deurPunten` — see §1.2.
* `r.vrij` — the **free-cell grid**: `x, z` from `marge` to `w−marge` / `d−marge` in steps
  of 12, with `marge = 12` (18 for the tuin, `erf`). A cell is dropped when the Manhattan
  distance is `< 18` to any decor item or slot, `< 14` to any door's inside point, or
  (pool only) when `z < bad.z1 + 6`. Ids are `'v' + x + '_' + z`, soort `'vrij'`.
* `r.plekkenLijst` — the **wander places**: walk `r.vrij` in order and keep a cell only if
  it is ≥ 22 (Manhattan) away from every kept cell. If nothing survives, `[[w/2, d/2]]`.
* Every slot gets its **standing place** `sx, sz` (`afSlot`):
  * `bed`: normal bed → `(x + 2, z + 12)`; rotated bed (`draai` or `model === 'bedz'`) →
    `(x + 12, z + 2)`;
  * `bak`: `(x − 13, z)`;
  * anything else: `(x, z)`.

**Fixed slots.** Only kamer1 and kamer2 have slots, identical in both:
`bed1 = bed @ (30, 27)`, `bed2 = bed @ (30, 75)`, `bak = bak @ (84, 33)`.
The tuin has one slot `tobbe` (soort `vrij`) at (32, 94). So the hotel starts with
**4 beds → `maxGasten() = 4`**.

### 1.6 Fractional placement

```
Rooms.plek(kamerId, fx, fz)  ->  { kamer, x: round(w*fx), z: round(d*fz) }
Rooms.hoogte(kamerId, f)     ->  round(w * f)
```

Everything the hotel places uses these, so a room resize moves it along.
Worked example: `Rooms.plek('receptie', 0.875, 0.25)` = `{x: 105, z: 30}` (w = d = 120) and
`Rooms.hoogte('receptie', 0.2)` = `24`.

All fractional constants used by the world:

| constant | call | value in receptie (120 × 120) |
|---|---|---|
| check-in card / bill card `CI_PLEK`, `WERKPLEK` | `plek('receptie', 0.875, 0.25)` | (105, 30) |
| its height `CI_HOOG`, `WERKHOOG` | `hoogte('receptie', 0.2)` | 24 |
| counter `TOONBANK` | `plek('receptie', 0.15, 0.5)` | (18, 60) |
| its height `TOONHOOG` | `hoogte('receptie', 0.225)` | 27 |
| guest waiting spot `WACHTPLEK` | `plek('receptie', 0.2, 0.95)` | (24, 114) |
| "needs a bed" spot | `plek('receptie', 0.375, 0.775)` | (45, 93) |
| "klaar met tellen" button | `plek('receptie', 0.775, 0.275)`, `hoogte(0.175)` | (93, 33), y 21 |
| room hint during check-in | `plek('receptie', 0.775, 0.05)` | (93, 6) |
| task cards `i = 0,1,2` | `plek('receptie', 0.075 + i·0.325, 0.025 + i·0.325)` | (9, 3), (48, 42), (87, 81) |
| day messages `i = 0,1` | `plek('receptie', 0.375, 0.5)`, `hoogte(0.375 + i·0.15)` | (45, 60), y 45 / 63 |
| ghost coins `i = 0..5` | `plek('receptie', 0.5 + (i%3)·0.1875, 0.875 + (i>2 ? 0.075 : 0))` | (60,105) (83,105) (105,105) (60,114) (83,114) (105,114) |
| trolley rest spots (`RUST.kar`) | keuken `plek(0.4, 0.579)` = (48, 66) · gang literal (60, 20) · kamer1/kamer2 `plek(0.579,0.579)` = (66, 66) · receptie `plek(0.7,0.3)` = (84, 36) · zwembad `plek(0.5,0.8)` = (72, 70) · wasserij `plek(0.45,0.6)` = (45, 54) | |

### 1.7 Decor models and the runtime model hook

Built-in model names (all voxel lists anchored at (0,0,0) on the floor, centred):
`boom`, `hok`, `hekx`, `hekz`, `tobbe`, `bal`, `kist`, `mat`, `poort`, `balie`, `baliez`,
`bel`, `kassa`, `boek`, `prikbord`, `prikbordz`, `sleutelbord`, `sleutelbordz`, `bed`,
`bedz`, `mand`, `kast`, `kastz`, `zak`, `kar`, `lamp`, `lampaan`, `plant`, plus the
generated `pol0..polN` grass tufts. `…z` variants are the same model mirrored over the
diagonal (`[x,y,z] → [z,y,x]`), i.e. a quarter turn.

Sizes that matter for the port: a bed is 33 long × 17 wide × up to 13 high; the mattress
top is `y = 7` (`MATRAS`); the tallest piece of furniture is the food cupboard `kast`
at 29 voxels — the walls (50–58) must stay taller than everything in front of them.
Palette: `HOUT #D0A87A`, `HOUT_D #B98F62`, `HOUT_L #E2C094`, `STAM #B08A6A`,
`BLAD #A6CE8E`/`#A9D08F`/`#B2D797`, `DAK #E79C7C`, `MUUR #F6E2C8`, `DEURKL #8B6F5C`,
`WATER #A9D8E6`, `KUSSEN #FFF7EC`, `DEKEN #A9D3F0`/`#84B4D8`, `STOF #F5B0C2`,
`METAAL #C9CCDC`/`#EDEFF6`, `GOUD #F2C14E`/`#D9A72F`, `POT #D98E6A`, `PAPIER #FFFDF3`.

**`Rooms.registerModel(naam, fn)`** — a game registers its own model.
Returns `false` for an empty name, a non-function, or a **protected** built-in name
(own properties of the built-in table only; inherited `Object.prototype` keys such as
`toString` are *not* protected). Re-registering your own name is allowed (last wins).
`Rooms.heeftModel(naam)` is true for a built-in, a registered extra, or `/^pol\d+$/`.
`Rooms.model(naam, params)` calls the function with `params` (or `{}`); an unknown name
falls back to `pPol(+naam.slice(3) || 0)`.
A model function must be **pure**: the same `params` must give the same list, because the
baked image is cached on `model | g | JSON(params)`.

**Runtime loose decor** (`World.decor`, per game; not saved, see §5.3):
`decor(kamerId, {id, model, x, z, params?, hoog?|y?, rot?, ver?})` creates or updates a
piece and returns a **copy** `{id, model, kamer, x, z, hoog, rot, ver, params, door}`, or
`null` on: unknown room, missing id, unknown model, a piece owned by another game, or a
full room (**`LOS_MAX = 48` pieces per room**). `rot` is 0..3 quarter turns about y
(`rot 1: [x,y,z] → [z,y,−x]`, a real rotation, not a mirror). `hoog` only lifts the image;
depth stays on the floor (`x + z`, `+0.3` when `hoog` is set). `decorWeg(kamer, id)`,
`decorLijst(kamer?)`, `decorPlek(id, kamer?)`, `decorWisEigenaar(door)`.
Ownership is enforced; starting or stopping any registered game wipes the loose decor of
all *other* registered games (hooked on `Hits.voorrang`).

### 1.8 Furniture API (persistent)

`Rooms.MEUBEL` types: `bed` (soort `bed`, model `bed`, "bed"), `bakje` (soort `bak`, no
model, "voerbakje"), `mandje` (decor, model `mand`), `speelmand` (decor, model `mand`),
`plant` (decor, model `plant`), `badkuip` (decor, model `tobbe`).

`Rooms.meubelZet(kamerId, type, x, z, rot, id)`:

1. remember the base layout of the room once (`_basis`), so "Nieuw spel" can restore it;
2. reject a position closer than 4 voxels to any wall/edge; if the cell is occupied
   (`bezet`: Manhattan < 15 to a slot or decor item, < 12 to a door's inside point), snap
   to the nearest **free** grid cell (`naarRaster`); if `x`/`z` are omitted, snap from the
   room centre;
3. if the chosen cell is still occupied → return `null` (never a half-placed item);
4. decor types are pushed into `r.decor` with `meubel: id`; `bed`/`bakje` are pushed into
   `r.slots` (a bed with odd `rot` uses model `bedz` and `draai: true`), then `bouwAf(r)`
   runs again so standing places, free cells and wander places are up to date.

Ids are `'m' + n + '_' + type` with a counter that must survive a reload
(`Rooms.nrStand/zetNr/nrUitIds`, mirrored in the save as `meubelNr`).
`Rooms.meubelWeg(id)`, `Rooms.meubels(kamerId?)`, `Rooms.herstel()` (back to the base
layout), `Rooms.vrijVak(kamerId, x, z)`.

A bed added is a **guest added**: beds are the hard guest cap (HOTEL.md §2).

### 1.9 Camera rules (per room)

`world.js` gives **every room its own voxelmaat**; the frame height is the same for all
rooms (otherwise the page would jump at every door).

* `maatVan(r, cssW, hoogPx)`:
  `d = schermDicht()`;
  `q = min((max(240, cssW) − 4) / boxWidth, max(120, hoogPx − 4) / nodigHoog)`;
  `ng = clamp(round(q·d), 2, 4)`; if `ng/d < q·0.9` then `ng = clamp(ceil(q·d), 2, 4)`;
  `dicht = max(d, ng/q)`; result `{q: ng/dicht, g: ng, dicht}`.
  `nodigHoog(r) = boxHeight − max(0, −box[2] − 56)`: the floor plus a 56 voxel-px strip of
  wall (`WAND_ZICHT`) must always fit; bare wall above that may be cut off.
* `schermDicht()`: `min(3, devicePixelRatio)`, but **2** when `devicePixelRatio > 2` and
  `min(innerWidth, innerHeight) < 500` (the small-phone density cap).
* `kaderHoogte(cssW, ruim)`: over all rooms take the smallest `boxHeight·q` (`laagste`)
  and the largest `nodigHoog·q` (`nodig`); the frame wants
  `max(round(laagste/0.60), round(nodig))`, clamped to `[200, ruim]`.
  `ruim = min(screenHeight − chrome − 6, round(screenHeight · (portrait ? 0.78 : 0.90)))`,
  never below `KADER_MIN = 200`.
* `camDoel(r)`: `cx = W/2 − (box[0]+box[1])/2·g`;
  `over = H − boxHeight·g`; `onder = min(132·dicht, max(0, over))` (the strip under the
  room where the keypad and the blanket chest live);
  `cy = over ≥ 0 ? (over − onder)/2 − box[2]·g : H − 4 − box[3]·g`.
  So when the box does not fit, the **floor stays whole** and bare wall is cut at the top.
* **Room change** (`World.naar`): re-measure first (the new room may have another `g`),
  then slide the camera over `REIS_MS = 300 ms` with ease-in-out
  (`t<0.5 ? 2t² : 1 − (−2t+2)²/2`) starting `±0.40·W` sideways — `+` when the new room is
  later in the room list, `−` when earlier — while the whole frame fades from
  `alpha 0.35` to `1`. With reduced motion, or when the world is not measured yet, the
  camera jumps. During the slide the **hotspots already sit at their destination**, so a
  tap halfway lands on the right object.

---

## 2. Guests

### 2.1 The pool

`GASTEN_POOL` (state.js), taken in this order by the bell:

| id | naam | kind | soort | scoops | act | mins |
|---|---|---|---|---|---|---|
| `boef` | `Boef` | hond | puppy | 2 | `Wandeling` | 30 |
| `muis` | `Muis` | poes | poes | 1 | `Spelen` | 15 |
| `wolkje` | `Wolkje` | konijn | konijn | 1 | `Bad` | 15 |
| `gerrit` | `Gerrit` | gans | gans | 2 | `Plonzen` | 15 |
| `pip` | `Pip` | hond | puppy | 3 | `Wandeling` | 30 |
| `vlok` | `Vlok` | poes | poes | 2 | `Spelen` | 15 |
| `stamp` | `Stampertje` | konijn | konijn | 1 | `Bad` | 15 |
| `bikkel` | `Bikkel` | hond | puppy | 2 | `Wandeling` | 30 |
| `pluis` | `Pluis` | poes | poes | 1 | `Spelen` | 15 |

When the waiting list runs out it is refilled from the same pool with ids suffixed
`_d<dag>`; a still-colliding id gets `_2`, `_3`, … appended.

Families for the thank-you letters, cycled by `famIdx`:
`Van Dijk`, `De Groot`, `Bakker`, `Jansen`, `Visser`, `Mulder`.
Articles: `de puppy`, `de poes`, `de gans`, `het konijn`.
Dutch possessive `bezit(naam)`: ends in s/x/z → `naam + "'"`; ends in a/i/o/u/y →
`naam + "'s"`; otherwise `naam + "s"`. So `Boef → Boefs`, `Pip → Pip's`, `Vlok → Vloks`,
`Muis → Muis'`. (Used by the frozen planner text only.)

### 2.2 Guest record

`mkGast` produces: `{id, naam, name (same), kind, soort, scoops, act, mins, kamer: null,
bed: null, waar: 'receptie', nachten: 2, geslapen: 0, prijs: 1, behoefte: 'kamer',
dagIn: 1, accessoires: []}`. The hotel adds at check-in: `betaald`, `gegeten` (bool),
`blij` (bool), and updates `nachten`, `prijs`, `dagIn`, `kamer`, `bed`, `waar`, `behoefte`.

`waar` is the room the guest is *in* (written back from the world every `Hotel.render()`);
`kamer` is the room the guest *sleeps in*.

### 2.3 Appearance parameters

Four species, each a voxel model built in `art.js` (details in X4). Palette per species
(`b` fur, `d` dark fur, `e` accent, `l` light):

| kind | b | d | e | l |
|---|---|---|---|---|
| hond | `#EEC194` | `#D3996A` | `#B4744A` | `#FCE8D3` |
| poes | `#C9CCDC` | `#A0A6C0` | `#F4C8D5` | `#EDEFF6` |
| konijn | `#F5E7EC` | `#DCC6D3` | `#F5B0C2` | `#FFFBF6` |
| gans | `#FDF8EA` | `#E0D8C2` | `#F6A957` | `#FFFCF4` |

Eyes `#5B4840`, nose/mouth `#7E6255`, dog collar `#6BC5A4`. A body is roughly 30 voxels
long; the sprite anchor is `dierAnker = [13, 7.5]` (the middle of the four paws).

**Poses** (frames, not transforms): `rust`, `tril`, `hap1`, `hap2`, `blijA`, `blijB`,
`sip`, `zwaai`, `kijk`, `loopA`, `loopB`, `zit`, `zitsip`, `lig`, `snuif`.
`lig` is the sleeping pose (paws pulled in: everything at `y ≤ 7` is squashed to 30 %,
everything above shifts down accordingly; eyes closed).

**Accessories** (`Art.ACCESSOIRES`): `hoedje`, `sjaaltje`, `bal` — nothing else is
accepted. They live on the guest record (`g.accessoires`), are part of save v7, are baked
into the guest sprite (so a bed drawn after the guest cannot slide over them) and vanish
when the guest checks out. `accessoire(id, naam)` is idempotent and always replaces the
array (never mutates in place — a fresh guest shares its empty array with the pool);
every change redraws and saves by itself. Colours: hat `#6BC5A4` with `#FFF7EC` band,
scarf `#F6A957` with white fringe, ball `#F4C8D5` with a white equator.

### 2.4 The animal runtime (`world.js`)

Each guest gets a `Dier` seeded with `prng(hash(id) ^ ZAAD)` where `ZAAD = (Date.now()>>>3) & 0xffff`
(so idle behaviour differs between sessions — **inferred**: the port may seed from the day
number instead if determinism is wanted).

Per-animal constants (from the seeded generator):
`fase = r()·6.283`, `tempo = 0.78 + r()·0.5`, `staartSnel = 0.16 + r()·0.2`,
`rustig = 0.6 + r()·0.9`, `wandelKans = 0.34 + r()·0.22`,
`blijStijl = ['draai','hup','wiebel'][(index + ZAAD%3) % 3]`,
`vmax = (konijn 1.5 | gans 1.0 | else 1.3) · tempo`,
`stapLengte = konijn 0.26 | gans 0.60 | else 0.46`,
`bobHoog = konijn 5.0 | gans 1.4 | else 2.1`.
Start position: wander place `[(index·3 + 1) % count]`.

**States**: `stil`, `loop`, `zit`, `kijk`, `snuif`, `eet`, `blij`, `sip`, `slaap`,
`wacht`, `zwem`, `spring`. The tick rate is **15 Hz** (`STAP = 1000/15`), at most 3 catch-up
ticks per frame, drawing at ~31 Hz (`TEKEN = 1000/31`) and only when the frame actually
changed (see §6.6).

Movement physics (`rijd`, per tick): with `vmax' = vmax · roomLoop · tempoFactor`,
`acc = vmax'/5.5 · tempoFactor`, braking distance
`rem = v²/(2·acc) + vmax·0.4/tempoFactor`; accelerate unless the remaining distance
(including what is left after this point) is inside `rem`; `v` is clamped to
`[0.14·vmax', vmax']`; facing is `+1` when `(dx − dz) ≥ 0`. Walk bob is
`−|sin(gang·π)|·bobHoog`; a goose also sways `±1.6`.
Practical speed: **20–35 voxels/s in a `loop 1.5` room**.

### 2.5 Movement API

| call | meaning |
|---|---|
| `World.zet(id, kamer, x, z)` | teleport; clears route/bed target/lift; state `stil` for 12 ticks. Without x/z it uses wander place `[(nr·3+1) % n]` |
| `World.ga(id, x, z, na)` | walk inside the current room, then take state `na` |
| `World.reis(id, kamer, {x, z, na})` | walk **through the doors**; returns the path. No path (same room / unknown room) is *not* an order: a swimmer or a running command is left alone |
| `World.slaap(id, kamer, slot)` | go to bed (see §2.7) |
| `World.feed(ids)` | walk to the eating place and eat |
| `World.mood(id, 'sad'\|'happy'\|'idle')` | walk to the sip place and sulk / bounce / resume |
| `World.solo(id, act)` | walk to a free place and be happy there |
| `World.loopNaar(id, x, z, o)` / `World.stappen(id, punten, o)` | **promise-based** movement |
| `World.pose(id, naam, duur)` | set one pose; `true`/`false` |

`na` values on arrival: `eet`, `sip`, `wacht`, `snuif`, `blij`, `slaap`, `deur`, anything
else → `stil` for `round((10 + r()·40) · rustig)` ticks.

**Promises** (`stappen`, `loopNaar`): options `{pose: null|'zwem'|'spring', tempo: 1,
perStap(i, punt), na}`. The promise resolves `true` when the last point is reached (exactly
on the point, in end pose `na`, default `wacht`, or `zwem` when `pose: 'zwem'`), and
`false` — never a rejection — as soon as another order takes the animal over: a new
`stappen`/`loopNaar`, `ga`, `reis`, `slaap`, `pose`, `feest`, `setMood('happy')`, `solo`,
leaving the room, or checking out. `stappen(id, [])` resolves `true` immediately and does
**not** touch the animal; an unknown animal resolves `false` immediately.
Points may be `{x,z}` or `[x,z]`; non-finite points are skipped. Coordinates are always in
the animal's current room — a command never walks through a door.

Tempo scales the whole movement linearly in time (tempo 2 = half the duration). Walking
and swimming **glide through** the points (only the last point is braked for), so 43 points
along the pool cost the same time as one straight line (measured 4.3 s); jumping
deliberately does not glide: it stops and squashes on every stone (≈ 0.6 s per stone at
tempo 1: `SPRING_TIKKEN = 6` ticks in the air, `SQUASH = 3` ticks flat).

`pose: 'spring'` draws a parabola with peak `SPRING_HOOG = {hond 5, poes 6, konijn 7,
gans 4}` voxels: `h = peak·4·f·(1−f)`, poses `loopA` (f<0.25) → `blijA` (<0.75) → `loopB`.
`pose: 'zwem'` sinks the animal `ZWEM_DIEP = 7` voxels (`hoogte = −7`, `lift = +7·HG`),
sways `sin(t·0.42+fase)·0.9`, paddles `loopA/loopB`, and drops splashes
(`ZWEM_KL = ['#E6F5FF','#FFFFFF','#CFE9FF']`) every 5th tick while moving, every 30th while
floating. `d.hoogte` (voxels up, +jump / −swim) is what games read; `d.lift` is the same
value as a downward pixel offset.

**Water band.** Because the pool water is baked into the floor plate, a swimmer gets a
translucent band drawn *over* his lower part after he is drawn: colour `#9CD1E4` at
alpha 0.75, cut off by an ellipse at the waterline (the floor line under the animal),
clipped to the animal's own pixels (`source-atop`), and only when `inWater()`: pose `zwem`
(or a running `zwem` command), `hoogte < 0`, and — in a room that has a `bad` rectangle —
inside that rectangle. A guest standing in swim pose on the deck stays dry.

### 2.6 Idle wandering

When a `stil`/`zit`/`kijk`/`snuif` state runs out, `kies()` picks with `w = wandelKans`:

| roll | result |
|---|---|
| `r < w` | walk to a free place, then `stil` |
| `< w + 0.17` | walk to a free place, then `snuif` |
| `< w + 0.32` | `zit` for `24 + floor(r·50)` ticks |
| `< w + 0.44` | `kijk` for `6 + floor(r·12)` ticks |
| else | `stil` for `round((12 + r·46) · rustig)` ticks |

If a route through doors is pending, that is done first.
`vrijePlek(d)`: start at a random index in the wander list, skip a place within isometric
screen distance 66 of another animal's target in the same room, skip a place closer than 40
to the animal itself, keep the farthest, and stop early with 45 % chance per candidate.
After a happy bout, `wandelKans` grows by 0.06 (max 0.62).

Other state details: `blij` lasts `46 + floor(r·34)` ticks with one of three styles
(`draai` flips facing every 3 ticks, `hup` bounces to −7.5, `wiebel` sways ±2.6) and throws
2 sparkle particles every `9 + nr·2` ticks; `eet` chews in a 5-tick cycle and removes one
piece of food from the bowl every 5th tick, then goes `blij` for `50 + floor(r·36)` ticks
when the bowl is empty; `wacht` and `stil` just breathe (`bob = sin(t·0.085+fase)·0.8−0.4`)
with random blinks (3.5 % per tick, `tril` or `kijk` for 1–4 ticks).

### 2.7 Sleeping on a bed, and 💤

`World.slaap(id, kamer, slot)`: if the animal is already in that room (or reduced motion is
on) it lies down immediately; otherwise it walks (through doors if needed) to the bed's
**standing place** `(sx, sz)` with `na: 'wacht'` and remembers `slaapDoel`. On arrival in
that room the animal steps into the bed regardless of what `na` said.

`inBed`: position = the bed's own `(x, z)`, `lift = −MATRAS·HG = −14` px (mattress top is
`y = 7`), state `slaap`, pose `lig`, `face = −1` for a rotated bed (`bedz`) and `+1`
otherwise — mirroring is exactly a quarter turn in this isometry, so the animal always lies
along the bed. Breathing while asleep: `bob = sin(t·0.045)·0.6`.

A sleeper is drawn **without a ground shadow** and at depth `x + z + 0.5`.
Above his head three 💤 blocks are drawn in `#7E6255` at alpha 0.8, at
`[dx, dy above the mattress, cell size] = [0, 17.5, 0.85], [2, 20.5, 1.15], [4, 24, 1.5]`,
offset `Z_KOP = 8` voxels toward the snout (mirrored with `face`). They are static —
no animation — and disappear when he gets up.

An occupied bed gets **no button** (the sleeping animal with its name plate says it all).

### 2.8 Bowls and eating

One bowl object per `bak` slot (`World.setBak(kamer, slot, 0..4)`, `bakStand`), level
clamped to 0..4. `Art.setFood(id, aantal, per)` maps to a level:
`0 → 0`, else `clamp(ceil((aantal/per)·4), 1, 4)`. The eating place is
`(bowl.x − 13, bowl.z ± 7)` (alternating by guest index), the sulking place
`(bowl.x − 5, bowl.z + 13)`. `World.feed(ids)` walks each animal there and starts `eet`.
While one animal eats, the bowl is drawn in two parts around him so he sits *in* the bowl.

### 2.9 Off-screen guests

Animals in rooms you cannot see run `grofTik()`: they keep their route and positions (one
`vmax·loop` step per tick, straight to the target) but get no poses, no particles and no
drawing. An eating animal off-screen empties its bowl at once. This keeps one rAF loop
enough for the whole hotel.

### 2.10 Name plates

Every guest has a DOM label (`.wtag`) in `#worldTags`, positioned at
`screenY − (30·HG + 8)·g + (bob + lift)·g`, divided by `dicht`. Overlap resolution: up to
6 passes, and a plate within 62 css-px horizontally and 24 vertically of an already-placed
plate is moved to `otherY − 26`. Plates of guests in other rooms are hidden.

---

## 3. The day, the wishes and the economy

### 3.1 What a day is

`state.dag` starts at 1 and only increases through `Hotel.morgen()`. Within a day,
`state.ronde` is one of `'ochtend'`, `'vrij'`, `'avond'`. No round ever locks anything:
the child can bell, play games and walk around in any round.

* **ochtend** — set by `morgen()`, which also opens the prikbord. Assigning a bed
  (`wijsBed`) or tapping a task card flips the round to `'vrij'`.
* **vrij** — free play.
* **avond** — set by `Hotel.avondronde()` (the moon button in the bar, the lamp hotspot on
  the desk, or the "Reken af" task): checkout and the bills.

`morgen()` in order:
1. clear the `avond` hotspots and close the prikbord;
2. `dag++`; every guest with a bed gets `geslapen++`;
3. food bookkeeping: `gebruik = Σ scoops of all guests`; `scoops = max(0, scoops − gebruik)`;
   `levering--`; if `levering ≤ 1` then `scoops = 20 + min(scoops, 4)`, `levering = 4` and a
   message `{icoon: '📦', tekst: 'voer: <scoops> 🥄'}`; if `scoops < gebruik` then
   `scoops += 10` and a message `{icoon: '🩺', tekst: 'Els bracht 10 🥄'}`;
4. all bowls to 0, `state.kar = null`;
5. `badBeurt = badMogelijk() && dag % 2 === 0`; `nieuw = nieuweWensen(badBeurt)`;
6. per guest: `gegeten = false`, `blij = false`,
   `behoefte = bed ? 'eten' : 'kamer'`; if it has a bed and `badBeurt` and it is guest
   index 0 → `'bad'`; else if it has a bed and it is in `nieuw` → that wish. A guest with a
   bed is placed **next to its bed** (the standing place) and then walks to its wish place;
7. `uitcheck = [guests with geslapen ≥ nachten]`; if any, a message
   `{icoon: '👪', tekst: '<naam> gaat naar huis'}`;
8. `dagBericht` = those messages or `null`; `ronde = 'ochtend'`; tasks rebuilt; the desk
   lamp model goes back to `lamp`; band recomputed; `Snd.dag()`; camera to the receptie;
   prikbord opened; save.

### 3.2 Needs and wishes

`BEHOEFTE` (state.js) — icon, long text, place keyword:

| behoefte | icoon | tekst | plek | resolved by |
|---|---|---|---|---|
| `eten` | 🍪 | `wil eten` | bak | `g.gegeten` |
| `kamer` | 🛏 | `wil een bed` | bed | `g.bed` |
| `bad` | 🛁 | `wil in de tobbe` | tobbe | `g.blij` |
| `spelen` | 🧶 | `wil spelen` | mand | `g.blij` |
| `zwemmen` | 🏊 | `wil zwemmen` | zwembad | `g.blij` |
| `souvenir` | 🎁 | `wil een souvenir` | kraam | `g.blij` |

Short words shown next to the icon (`WENSWOORD`): `eten`, `bed`, `bad`, `spelen`,
`zwemmen`, `souvenir`. An icon never appears without its word (HOTEL.md §9). An unknown
need falls back to its own name and logs one console warning.

**Where a guest waits** (`Hotel.plekVanBehoefte`):

| behoefte | place |
|---|---|
| `kamer` (or no room yet) | receptie (45, 93) |
| `eten` | the room's `bak` standing place `(84−13, 33) = (71, 33)` |
| `bad` | tuin `(tobbe.x − 14, tobbe.z) = (18, 94)` |
| `spelen` | `(mand.x − 12, mand.z) = (81, 99)` in its own room |
| `zwemmen` | `zwembad` `dek.start` (12, 56); if the pool does not exist or is unreachable → tuin near (58, 106), snapped to a free cell |
| `souvenir` | the point in front of the `kraam` zone (`voorRand`, 8 voxels off the side facing the room centre) → tuin (96, 52); fallback tuin near (106, 58) |

The guest walks there itself (`World.reis(..., na: 'wacht')`) and waits patiently. Nothing
decays, nobody becomes sad from waiting.

**Which wishes may be handed out** (`wensMogelijk`): `kamer`, `eten` and `spelen` are
always possible (the hotel resolves them itself). `bad` needs the `tobbe` game;
any other type needs a registered game that declares `wens: '<type>'` (or an array
containing it), is not `stub: true`, and whose `unlock(N, band)` returns true. That is how
a 🏊 or 🎁 bubble can never appear without a game to fulfil it.

**Handing out the new wishes** (`nieuweWensen(badBeurt)`), run only in `morgen()`:

```
if (dag % 2 === 0) return {};                 // even days belong to the tobbe
kan  = ['zwemmen','souvenir'].filter(wensMogelijk)
kies = guests with a bed, minus index 0 when badBeurt
hoeveel = guests.length > 4 ? 2 : 1
beurt = (dag − 1) / 2                          // 0, 1, 2, …
ring  = max(kies.length, 2)
for k in 0..hoeveel−1:
   c = beurt*hoeveel + k;  i = c % ring;  if i >= kies.length: continue
   wish[kies[i].id] = kan[ floor(c / ring) % kan.length ]
```

Worked example — 3 guests with beds, both games registered. Day 3: `beurt = 1`, `ring = 3`,
`c = 1`, `i = 1` → guest #2 gets `kan[0] = 'zwemmen'`. Day 5: `c = 2` → guest #3 gets
`zwemmen`. Day 7: `c = 3`, `i = 0` → guest #1 gets `kan[1] = 'souvenir'`. So every guest
gets every wish in turn, at most one outing per day (two above four guests), and 🍪 stays
the ordinary morning bubble.

### 3.3 The bell and check-in

`Hotel.bel()`:

* a check-in already running → repaint it and toast `🛎️ Er staat al iemand`;
* no free bed → soft sound and a bubble at the bell: icon 🛏, number `maxGasten()`,
  text `alle bedden vol`, class `hulp`, height 26, removed after 3200 ms;
* otherwise: close the prikbord, take the next guest, compute
  `geld = sommen.geld(band)` and store `nachten`, `prijs`, `betaald`, `dagIn = dag`;
  reset `kamer/bed/behoefte/geslapen/gegeten/blij`; put the guest in `state.nieuweGast`;
  build the check-in; `Snd.bel()`; place the guest at the gang door of the receptie and
  walk it to `WACHTPLEK` (24, 114) with `na: 'wacht'`; go to the receptie; paint;
  toast `<naam> staat aan de balie! 🔔`.

**Check-in state** (`state.checkin`): `{gastId, samen, extra, nieuw: samen+extra,
dagen: state.levering, voorraad: state.scoops, stap: 1, fouten1: 0, fouten2: 0, invoer: '',
keuze: null, weg: false, t0}` where `samen = Σ scoops of the current guests` and
`extra = the new guest's scoops`.

**Step 1 — "Samen?"** One sum card at (105, 30), height 24 (lifted when the frame is under
300 px high, by `ceil(20/(2k))` height steps), icon 🥄, with two lines:

> `De gasten eten <n> schep|scheppen per dag`
> `<naam> eet <extra> erbij. Samen?`

Sum text `"<samen> + <extra> ="`, open keypad, max 2 digits.
After a wrong answer (`fouten1 > 0`) the help line is the spoon rows
`scoopjes(samen) + ' + ' + scoopjes(extra)` where `scoopjes(n)` is `n` spoon emoji for
`n ≤ 8` and `"<n> 🥄"` above that (0 → `"0"`).
Correct → `Snd.ja()`, toast `Precies! 🎉`, `State.tel(fouten1 === 0, elapsed)`, step 2.
Wrong → `Snd.zacht()`, toast `🥄 Tel ze samen`, `fouten1++`.
Empty input → toast `👆 Tik eerst een getal`.

**Step 2 — "Genoeg?"** Same card, no keypad, one choice strip. Lines:

> `Elke dag <nieuw> schep|scheppen, <dagen> dag|dagen lang`
> `📦 In huis: <voorraad> schep|scheppen. Genoeg?`

Sum text `"<dagen> × <nieuw>"`, and after a first mistake `"<dagen> × <nieuw> = <product>"`.
Choice strip title `is er genoeg eten?`, three buttons:
`⬇ te weinig` (= `meer`), `⚖ precies`, `⬆ blijft over` (= `minder`).
The frozen comparison is `vergelijk(v)`: `dagen · nieuw > voorraad` → `'meer'`,
`<` → `'minder'`, `=` → `'precies'`. Correct → `Snd.ja()`, toast `Goed gerekend! 🎉`,
`State.tel(fouten2 === 0, elapsed)`, step 3. Wrong → `fouten2++`, `Snd.zacht()`, toast
`🥄 <dagen> × <nieuw> = <product>`.

**Step 3 — the bed.** A bubble over the guest: icon 🛏, text `Kies een bed` (or
`Alles bezet`), tapping it travels to the room of the first free bed. When that room is not
in view, a second bubble at (93, 6) shows that room's icon and name and travels there too.
Tapping a free bed calls `wijsBed`: set `kamer`/`bed`, move the guest from `nieuweGast` into
`gasten`, recompute the band, `World.slaap`, `behoefte = 'eten'`, clear the check-in,
`Snd.tover()`, **one star** (`Econ.sterren(1, 'checkin')`), tick off the `bed` task, flip
`ochtend → vrij`, save, travel to that room, and show a bubble
`💤 welterusten` (class `goed`) for 3600 ms.
Tapping an occupied bed → toast `<naam> slaapt hier. 💤`; tapping a free bed without a
check-in → toast `🛏 Bel eerst een gast`.

### 3.4 Feeding and playing (hotel-resolved wishes)

* **Bowl** (`tikBak`): a full bowl feeds *all* guests of that room —
  `gegeten = true`, and only a guest whose need is `eten` (or empty) switches to `spelen`;
  a guest waiting for 🛁/🏊/🎁 keeps its wish. Then `Art.feast(ids)`, toast
  `Smakelijk eten! 😋`, one star (`'voeren'`), task `voer` ticked, save.
  An empty bowl with guests → toast `🍪 Vul eerst de voerkar`; without guests → toast
  `🍽 Hier slaapt niemand`.
* **Play basket** (`tikMand`): every guest of that room whose need is `spelen` and who is
  not yet happy becomes `blij = true` and runs to `(mand.x − 12 − i·4, mand.z ± 6)` with
  `na: 'blij'` and mood `bouncy`; one star (`'spelen'`), task `spelen` ticked, save;
  toast `<naam> speelt met het balletje! 🧶` for one guest, or
  `Ze spelen allemaal met het balletje! 🧶` for more. Nobody waiting → toast
  `🧶 Straks samen spelen`.
* `Hotel.wensAf(gastId, welke)` (exposed to games as `ctx.wereld.behoefteKlaar`) sets
  `gegeten` for `eten`, `blij` for `bad`/`spelen`/`zwemmen`/`souvenir`, returns
  `!!g.bed` for `kamer`, removes the wish bubble, saves and re-renders. It gives **no**
  star — the game does that with `ctx.taakKlaar`.

### 3.5 Checkout and the bill (`econ.js`)

The evening round shows, at the desk, one bubble per departing guest
(at `(8 + i·24, 60 − i·6)`, height 16, max 3): icon 👪 and the guest's name. Tapping starts
the bill. With nobody to check out, a bubble hangs on the desk lamp: `🌙 Morgen ▸`, which
runs `morgen()`.

`Econ.rekening({gast, fam, nachten, prijs, totaal, betaald, onKlaar})` builds a three-step
moment; the camera goes to the receptie first. State: `{stap: 1|2|3, pogingen, telPog,
wisselPog, hand (the family's purse), bank (coins on the counter)}`.
A permanent bubble above the guest reads `👪 <naam> gaat naar huis` (class `goed`).

**Step 1 — the sum.** Work card at (105, 30) height 24, icon 🛏, line
`<naam> sliep <n> nacht|nachten, €<prijs> per nacht`, sum `"<nachten> × €<prijs> ="`,
open keypad, max 2. Help ladder: from the **first** wrong attempt the card shows
`Ui.telMee(prijs, nachten, '')` — for €5 × 3 nights literally `5 … 10 … 15.`; from the
**third** attempt six ghost coins are laid out on the floor with title
`zoveel is het samen`. Correct → `State.tel(pogingen === 0, elapsed)`, tick the card,
`Snd.ja()`, step 2 after 500 ms. Empty input → bubble at the till: `☝ tik een getal`
(class `hulp`).

**Step 2 — counting coins.** The ticked receipt stays on the work place. The counter
(`rek_bank`, a drop target `toonbank`, icon 🧾) shows `€<counted>`; the family's purse on
the ledger book (`rek_buidel`) shows the next coin (`🪙` + `€<value>`, badge = number of
coins left) or `👍` and title `de buidel is leeg`. Tap or drag one coin → it moves from
`hand` to `bank`, `Snd.munt()`, and a bubble `🪙 €<total>` appears at the till.
The `✔ klaar` button sits at (93, 33) height 21, title `klaar met tellen`:
* counted = price → done;
* counted < price → `telPog++`, `Snd.zacht()`, bubble `🪙 +€<rest>` (class `hulp`), and from
  the third attempt ghost coins with title `dit moet er nog bij`;
* counted > price → step 3 (change).

**Step 3 — change.** The receipt disappears; the same work place now holds a card, icon 👛,
line `<naam> gaf €<betaald>, het kost €<totaal>`, sum `"€<betaald> − €<totaal> ="`, keypad
open, max 2. The amount paid stays visible on the counter as a plain box
(`hotgetal hotbedrag`, depth 200 so it picks its place first), title
`op de toonbank ligt €<betaald>`. Help ladder: 1st mistake → `<totaal> → <betaald>`;
2nd → `Ui.telMee(1, betaald − totaal, '')` (`1 … 2 … 3.`); 3rd → ghost coins with title
`zoveel krijgt de familie terug`. Correct → `State.tel(wisselPog === 0, elapsed)`.

**Done** (`gelukt`): `Snd.tover()`, everything cleared, a bubble over the guest
`👋 €<wissel> terug` or `👋 ✔ betaald` (class `goed`), removed after 1100 ms, then the
callback. The hotel then adds `totaal` coins, one star (`'rekening'`), writes a letter,
removes the guest from `gasten` and from `uitcheck`, recomputes the band, ticks task `uit`,
saves, and shows the letter sheet.

**Coin helpers.**
`Econ.buidel(total)` builds a purse in which *every* amount up to the total can be paid
exactly: repeatedly take the largest denomination from `[10, 5, 2, 1]` that is `≤ rest`
**and** `≤ (sum so far) + 1`; finally sort descending. Worked example: `buidel(13)` picks
1, 2, 2, 5, 2, 1 and returns `[5, 2, 2, 2, 1, 1]`.
`Econ.splits(n)` is plain greedy: `splits(13) = [10, 2, 1]`.
Coin markup: `€10` and `€20` render as a note, others as a coin.

### 3.6 Stars, coins and letters

* **Stars are for taking part**, never for being right: check-in bed (1), feeding (1),
  playing (1), a bill finished (1), and each `ctx.taakKlaar()` from a game (1 by default).
  `Econ.sterren` plays `Snd.ster()` and immediately refreshes the HUD (`Hotel.hud()`), so
  the counter goes up during a game, not after it.
* **Coins** come only from checking out: `geefMunt(r.totaal)`.
* **Letters**: on checkout, `nieuweBrief(gast)` composes
  title `Bedankje van familie <fam> 💌` and body
  `Lieve hotelhouder,\n\n<zin>\n\nDank je wel dat je zo goed voor <naam> hebt gezorgd. Het bed was zacht, het bakje vol en de rekening klopte precies.\n\nLiefs, familie <fam>`
  with `<zin>` = `zinnen[famIdx % 4]` after `famIdx++`:
  1. `<naam> heeft heerlijk geslapen in kamer <1|2>.`
  2. `<naam> rende elke dag door de tuin en at netjes het bakje leeg.`
  3. `<naam> vond het bad het allerleukste van het hele hotel.`
  4. `<naam> lag het liefst bij het raam naar de vogels te kijken.`
  The sheet is headed `💌 Er is post!` with the button
  `Hang de brief op de muur 📌`; `Snd.brief()` plays; confirming toasts `💌 Aan de muur!`.

### 3.7 The prikbord (task board)

Tasks are rebuilt whenever a fingerprint changes (`taakSignatuur` = day, round, guest
count, coins, checkout count, free bed yes/no, pending guest, every game task id+text, and
per guest `id:bed:behoefte:gegeten:blij`, and every bowl level).

Hotel tasks, in this order:

| id | icoon | tekst | kamer | actie | when |
|---|---|---|---|---|---|
| `bel` | 🔔 | `Bel een gast` | receptie | `bel` | free bed and **no** guests |
| `bel` | 🔔 | `Nog een bed vrij` | receptie | `bel` | free bed and guests present |
| `bed` | 🛏 | `<naam> wil een bed` | receptie | `bel` | a guest without a bed |
| `voer` | 🍪 | `Vul de voerkar` | keuken | `game:voerkar` | a room with guests has an empty bowl |
| `uit` | 💰 | `Reken af: <naam>` | receptie | `avond` | `uitcheck` not empty |
| `spelen` | 🧶 | `<naam> wil spelen` | that guest's room (else kamer1) | `kamer` | a guest wants to play |

All hotel tasks have `prio = 0`. Game tasks come from `def.taak` (or the default table
`SPEL_TAAK`: `voerkar → none`, `tobbe → {id:'bad', prio:1, 🛁, "<naam> wil in bad"` /
`"Tobbe-tijd"}`, `bedden → {🛏, "Zet de bedden op rij", when ≥2 guests}`,
`sleutels → {🔑, "Hang de sleutels op", when ≥2 guests}`,
`meubels → {📖, "Koop iets moois", when ≥5 coins}`) and default to `prio = 5`.

**The fair rotation with the 3-chip cap.** Every *ordinary* game chip (has a `spel` and
`prio ≥ LAAG = 5`) counts equally on the board (`bordPrio` clamps them all to 5), and they
shift one place per day: with `n` such chips, day `d` starts the list at
`(d − 1) mod n`. Animal wishes (prio 0..4) keep their own order. After that the list is
sorted stably on `bordPrio` and **cut to three**.
Worked example: chips `[hinkel(5), was(8), bedden(5), sleutels(5)]` — all four are "low", so
on day 1 the order is hinkel, was, bedden, sleutels; on day 2 was, bedden, sleutels,
hinkel; on day 3 bedden, sleutels, hinkel, was. Each of them reaches the board within four
days instead of one of them living there forever.

A card that was just ticked keeps its ✅ for the rest of the day, even when it is no longer
needed; a card that disappears from the list while it was on the board is marked done
instead of vanishing. Tomorrow the board starts empty.

`openTaken()` counts the unticked cards; that number is the badge on the prikbord hotspot.
`Hotel.taakAf(id)` ticks by task id **or** by game id.
Tapping a card: close the board, round → `vrij`, travel to its room, then run its action
(`bel`, `avond`, `game:<id>`, or nothing for `kamer`).
The board opens with the prikbord hotspot or the `📋 Prikbord` button and closes when the
bell rings, a card is tapped, the evening round starts or any game starts.

**Card layout.** Up to three bubbles at (9, 3), (48, 42) and (87, 81), height 22, prio 10,
each `icoon` (or ✅ when done) + the task text. With no tasks at all, one bubble at the
prikbord: `🐾 Speel lekker rond`. Under them, up to two day messages at (45, 60), heights
45 and 63, prio 9, which disappear when tapped.

### 3.8 HUD

`Hotel.hud()` writes exactly five texts (nothing else, no buttons):

| element | content |
|---|---|
| `#dayNum` | `state.dag` |
| `#muntNum` | `state.munten` |
| `#sterNum` | `state.sterren` |
| `#letterNum` | `state.brieven.length` |
| `#rondeNaam` | `☀️ Ochtendronde` / `🌙 Avondronde` / `🐾 Vrij spelen` |

The bar around it (index.html): logo `🛎️ Dierenhotel`, badges `📅 Dag <n>` (title `Dag`),
`💰 <n>` (button, title `De kassa`), `⭐ <n>` (title `Sterren`), `💌 <n>` (button),
`🔊`/`🔇` (button, title `Geluid`, aria-label `Geluid aan of uit`), then the round bar with
the round name and the buttons `📋 Prikbord` and `🌙 Avond`.

### 3.9 The band and the number factories (`state.js`)

* `bandVanN(N)`: `N ≤ 3 → 3`, `N ≤ 6 → 4`, else `5`.
* Adaptive signal: `State.tel(goed, ms)` pushes `{g: 0|1, t: clamp(ms, 0, 20000)}`, keeping
  the last **10**. With ≥ 6 items: accuracy ≥ 0.8 **and** mean time < 7000 ms **and**
  `kunnen < 5` → `kunnen++` and the buffer is cleared; accuracy < 0.5 and `kunnen > 3` →
  `kunnen--` and cleared. `kunnen` starts at 3.
* Final band: `band = max(3, min(bandVanN(N), kunnen + 1))`.
  Right/wrong **never** buys stars or access — only the size of the next sum.
* `sommen.deel(N, band, dag)` → `{T, k, r, band}` with `T = k·N + r`, `0 ≤ r < k`.
  Band 3 returns exactly the frozen `koekjesSom` with `T ≤ 20`
  (plan per day: `(4,0) (4,1) (3,2) (4,0) (3,1) (4,2)` cycling on `(dag−1) mod 6`; `rest` is
  reduced to `n−1` when it is ≥ n, and `per` is lowered while `n·per + rest > 20 && per > 2`).
  Band 4/5 grow `k` inside the band's own table `KSET = {4: [2,3,4,5,10],
  5: [1..10]}` with ceiling `100`: candidates are the `kk ≥ k` for which
  `kk·N + min(r, kk−1) ≤ 100`, and the choice is `kand[(dag + N) % kand.length]`,
  `r' = min(r, kk−1)`.
  Worked example: `deel(5, 4, 2)` → frozen `(per 3, rest 1)`, candidates `[3,4,5,10]`,
  index `(2+5) % 4 = 3` → `k = 10, r = 1, T = 51`.
* `sommen.geld(band, nachten?, prijs?)` → `{nachten, prijs, totaal, betaald, wissel}`:
  price table `band ≤ 3 → [1,2]`, `4 → [1,2,5]`, `5 → [2,5]`, chosen by `dag % len`;
  default nights `2 / 3 / 4`; nights are lowered while `nachten·prijs > 20`.
  Band 4 on an even day adds €2 change when `totaal + 2 ≤ 20`; band 5 always pays with a
  note: nights are lowered while `totaal ≥ 20`, then `betaald = totaal < 10 ? 10 : 20`.
  Worked example band 5, day 4: prices `[2,5]`, `prijs = 2`, `nachten = 4`, `totaal = 8`,
  `betaald = 10`, `wissel = 2`.
* `sommen.klok(band)`: `u = 7 + (dag·3) % 8`. Band 3 → `{u, m: 0, stap: 60, tekst:'<u> uur'}`;
  band 4 → `m = [0,15,30,45][(dag+u) % 4]`, `stap 15`, text `u:mm`; band 5 →
  `m = (dag·7 + u·5) % 60`, `stap 5`, `duur = 20 + (dag % 4)·10`, text `u:mm`.
* `sommen.tafel(band)`: tables `{3: [1,2,5,10], 4: [1,2,3,4,5,10], 5: [1..10]}`,
  ceiling `{3: 20, 4: 100, 5: 100}`; `a = set[(dag + N) % len]`,
  `maxB = clamp(floor(plafond / a), 1, 10)`, `b = 1 + (dag·3 + N) % maxB`.
* Also frozen but **not in use**: the day-planner solver (`planbord`, `maakPlan`,
  `planOplossingen`, `planFouten`, 8 cells, four fixed appointments). It is kept so the
  planner can be moved onto the prikbord later with identical results.

---

## 4. Save format (v7)

### 4.1 Keys and envelope

| key | meaning |
|---|---|
| `kws-hotel-v7` | the current save |
| `kws-hotel-v6` | the pre-rebuild hotel save (read once, migrated, never written) |
| `kws-spel-v5` | the old Kwispelsteeg shelter (read once, migrated, never written) |
| `kws-geluid` | `'0'` = muted, `'1'` = sound on (separate, written by the speaker button) |

Envelope: `{"v": 7, "s": { …fields… }}`, JSON in `localStorage`. Saving is a no-op until
the start screen has been answered (`startKeuze`), and any storage error is swallowed.

### 4.2 Every field of `s`

| field | type | meaning |
|---|---|---|
| `dag` | int ≥ 1 | day number |
| `ronde` | `'ochtend'\|'vrij'\|'avond'` | round |
| `munten` | int | coins |
| `sterren` | int | stars |
| `band` | 3..5 | current band (recomputed on load anyway) |
| `kunnen` | 3..5 | adaptive ability level |
| `signaal` | array of `{g: 0\|1, t: ms}` | last ≤ 10 items |
| `gasten` | array of guest records | the guests in the hotel |
| `wachtlijst` | array of guest records | the queue |
| `famIdx` | int | family/sentence cursor for letters |
| `meubels` | array of `{id, kamer, type, x, z, rot, soort}` | bought furniture |
| `meubelNr` | int | furniture id counter (must survive reloads) |
| `taken` | array of task cards | today's board |
| `brieven` | array of `{titel, tekst, dag}` | the letter wall |
| `scoops` | int | food in store |
| `levering` | int | days until the next delivery |
| `snoeppot` | int | sweets jar (voerkar) |
| `kar` | any | trolley state (game data) |
| `spel` | object id → object | one drawer per minigame (`ctx.data()`) |
| `gezien` | object key → 1 | which explanations have been seen |
| `kamerNu` | room id | room in view |
| `uitcheck` | array of guest ids | guests due to leave |
| `nieuweGast` | guest record or null | the guest standing at the desk |
| `checkin` | object or null | half-finished check-in (see §3.3) |

Not saved: `rekening`, `dagBericht` (both are re-created), loose decor of games, hotspots,
promises. `Ui`/`Hits`/`World` hold no persistent state.

**When it is saved:** `State.bewaar()` is called after assigning a bed, feeding, playing,
`wensAf`, checkout, every `ctx.taakKlaar`, every accessory change, furniture changes, and
`morgen()`; plus `game.js` saves on `visibilitychange → hidden` and on `pagehide`.

### 4.3 Loading, defaults and repair (`vulAan`)

Missing or `null` fields are filled from: `dag 1`, `ronde 'ochtend'`, `munten 0`,
`sterren 0`, `band 3`, `kunnen 3`, `signaal []`, `gasten []`, `wachtlijst []`, `famIdx 0`,
`meubels []`, `meubelNr 0`, `taken []`, `brieven []`, `scoops 20`, `levering 4`,
`snoeppot 0`, `checkin null`, `rekening null`, `uitcheck []`, `kar null`, `spel {}`,
`gezien {}`, `kamerNu 'receptie'`, `dagBericht null`, `nieuweGast null`, `v 7`.
An empty waiting list is refilled from the pool.

Repairs, in this order:
1. a `checkin` whose `gastId` does not match `nieuweGast` is dropped;
2. a `nieuweGast` without a `checkin` is put back at the **front** of the waiting list — so
   a guest is never lost;
3. per guest: `naam`/`name` mirrored, `waar` defaults to `kamer` or `receptie`,
   `nachten 2`, `geslapen 0`, `prijs 1`, `behoefte` = `eten` when it has a room else
   `kamer`, `accessoires []`;
4. every waiting guest (and the pending one) gets `accessoires []` when missing.

### 4.4 Migrations

**v6 → v7** (`naarV7`): the receptie, kamer1, kamer2 and keuken became 1.5× larger, so
every saved furniture item in those four rooms moves: `x = round(x·1.5)`,
`z = round(z·1.5)`, then snapped to the nearest free cell of the (new) floor grid
(`Rooms.vrijVak`). Furniture in the gang or the tuin stays put. Then `v = 7`.
The v6 blob is left in storage untouched.

**v5 → v7** (`leesOudSpel`, only when there is no v6 and no v7 save): the old
`kws-spel-v5` shelter is read when `d.v === 5` and `d.s.dieren` is non-empty. Its animals
become guests without a room (`kamer: null, bed: null, waar: 'receptie', behoefte:
'kamer'`), its `pool` becomes the waiting list, and `day`, `brieven`, `scoops` (default 20),
`levering` (default 4), `snoeppot`, `famIdx` carry over; the save is marked `gemigreerd: 1`.

**Corrupt save.** Reading, migrating **and** filling in defaults all happen inside one
`try`: unparsable JSON, a wrong `v`, a missing `s`, or a hand-edited blob that breaks
`vulAan`/`naarV7` all end the same way — `leesSpel()` returns `null`, no save is used, and
the child simply gets the start screen with a fresh game. Nothing is thrown, nothing is
half-loaded.

---

## 5. The game contract

### 5.1 `Games.register(def)`

| field | required | meaning |
|---|---|---|
| `id` | yes | unique, equals the file name |
| `naam` | yes in practice | what the child sees (used as the hotspot title) |
| `kamer` | yes | the room the game lives in |
| `hotspot` | optional | `{obj, icoon, label, hoog, dx, dz, blijf}` — the entry button |
| `unlock(N, band)` | optional | may it be played? (`true` when absent; a throw counts as `true`) |
| `wens` | optional | which wish it fulfils: a name or an array of names |
| `taak` | optional | prikbord card `{id?, icoon, tekst (string or fn(state)), wanneer(state), kamer?, prio?}` |
| `stub` | optional | `true` = placeholder: no wish is handed out for it |
| `start(ctx)` | yes | build the turn |
| `stop()` | optional | clean up |

Registering twice replaces the earlier definition (last wins).

**Entry button** (`hersteek`, re-run after every render): the icon is placed on
`plek(kamer, hotspot.obj)`, which searches in this order: loose things (`kar`,
`balielamp`) → slots (`bed1`, `bed2`, `bak`, `tobbe`) → fixed decor of that room →
**loose decor of a running game** (`World.decorPlek`). It is offset by `dx`/`dz` and
`hoog` (default 12 voxels above the object), owner `registry`, class `hotgame`
(`hotgame aan` while running), prio 7, and it follows its object every frame.
The icon is removed while its own game is running (unless `hotspot.blijf`), when
`unlock` is false, or when the object cannot be found — which is exactly why an entry
button must hang on a **fixed** object, not on the game's own loose decor.

Currently registered games:

| id | naam | kamer | hotspot obj (icoon) | unlock | wens | taak |
|---|---|---|---|---|---|---|
| `voerkar` | De voerkar | keuken | `kar` 🛒 | N ≥ 1 | – | (hotel task `voer`) |
| `bedden` | Bedden op rij | kamer1 | `mand` 🛏 | N ≥ 1 | – | default `bedden` |
| `sleutels` | Het sleutelbord | receptie | `sleutelbordz` 🔑 | N ≥ 2 | – | default `sleutels` |
| `tobbe` | Tobbe-tijd | tuin | `tobbe` 🛁 | N ≥ 1 | (`bad` via `WENS_SPEL`) | `bad`, prio 1 |
| `meubels` | Het meubelboek | receptie | `boek` 📖 | N ≥ 3 | – | default `meubels` |
| `zwembad` | Zwembad | zwembad | `mat` 🏊 | N ≥ 1 | `zwemmen` | `zwemles`, prio 1 |
| `wekker` | Wekkerdienst | gang | fixed decor + offset ⏰ | N ≥ 1 | – | `wekker`, prio 3 |
| `hinkel` | Hinkelpad | tuin | `hok` 🪨 | N ≥ 1 | `spelen` | prio 2 with a waiting guest, else 5 |
| `was` | Wasmandtoren | wasserij | `tobbe` 🧺 | N ≥ 1 | – | `was`, prio 8 |
| `kraam` | Souvenirkraam | tuin | `bal` 🎁 (offset) | N ≥ 1 | `souvenir` | `souvenir`, prio 1 |

### 5.2 Lifecycle

`Games.start(id)`:
1. if another game is open → `stop()` it first;
2. `actief = id`, `actieveKamer = def.kamer`;
3. close the prikbord;
4. `Hits.voorrang(id)` — from now on this game picks its screen positions first, the
   hotel's buttons give way, the wish bubbles disappear, and the loose decor of every
   *other* registered game is removed;
5. `Hotel.render()`, `hersteek()`;
6. travel to `def.kamer` if not already there;
7. call `def.start(ctx)` inside a `try`; a throw resets `actief = null` and toasts
   `💛 Probeer iets anders`;
8. if the game moved the camera itself, `actieveKamer` is updated to the room actually in
   view and the hotel re-renders (so the wish bubbles hide in the right room).

`Games.stop()`: clear `actief`, call `def.stop()` in a `try`, `Hits.wisEigenaar(id)` (which
also returns every borrowed button), `Hits.voorrang(null)`, `Ui.leegPaneel()`,
`hersteek()`, `Hotel.render()`.

**Supersede** = starting another game: exactly the sequence above, so a game never has to
detect it — its `stop()` runs, its hotspots, bubbles, cards, number tags, sources and loose
decor are removed for it. Promises from `stappen` resolve `false`.

**Evening**: `Hotel.avondronde()` sets the round, turns the desk lamp model into `lampaan`,
closes the board and paints the checkout bubbles. It does **not** stop a running game; the
game keeps its priority until it stops itself.

### 5.3 `ctx`

One ctx per game, built once and cached. `ctx.id`, `ctx.naam`, `ctx.kamer`.

`ctx.wereld`: `kamers()`, `kamer(id)`, `pad(a,b)`, `slots(kamer, soort)`,
`slot(kamer, slotId)`, `actief()`, `naar(kamer)`, `dieren(kamer?)` (guest **records**,
filtered on `waar`), `dier(id)` (the live animal: `x, z, kamer, staat, pose, hoogte`),
`ga`, `reis`, `slaap`, `setMood`, `setFood`, `setBak`, `bakStand`, `feest(ids)`,
`solo`, `ding(sleutel)`, `dingZet(sleutel, o)`, `vuil()`, `mik(obj, kamer?)`,
`schaal()`, `behoefteKlaar(gastId, wens?)`, `getalTag(obj, n, o?)`,
`voegBed`, `plaatsMeubel`, `verwijderMeubel`, `kamerMeubels`, `meubeltypen`,
plus the module extensions: `decor`, `decorWeg`, `decorLijst`, `decorWisAlles`
(world.js), `loopNaar`, `stappen`, `pose` (world.js), `accessoire`, `accessoires`,
`accessoireWeg` (art.js). Everything placed through `ctx` is owned by the game.

`ctx.hotspots`: `maak(o)`, `weg(id)`, `wisAlles()`, `bron(obj, o)`, `pak(id, fn)`
(borrow one of the hotel's buttons while the game runs), `laat()`, `lijst()`.
`ctx.sleep(node, opts)` = the shared drag helper.
`ctx.state` = the global `State`; `ctx.data()` = `State.spelData(id)` (its own drawer in the
save). `ctx.ui` = `Ui` with the game stamped as owner on `wolk`, `somkaart`, `bron`.
`ctx.econ` = `Econ`, `ctx.snd` = `Snd`.
`ctx.taakKlaar(naam, {sterren})` → one star (`sterren` or 1), tick the card by that name
**and** by the game id, save. `ctx.sluit()` → `Games.stop()`.

Extensions are added through `window.CTX_UITBREIDINGEN` — a list of
`function(ctx, eigen)` that registry runs once per game, so a motor module can add API
without touching the registry.

### 5.4 Hotspot buttons (`hits.js`) — the placement contract

A hotspot is `{id, kamer, x, z, y, icoon, label, getal, badge, titel, html, kind:
'btn'|'drop'|'tag', drop, data, klas, prio, vast, d, op, volg(), aan(spot, ev),
onWeg(spot), door, tagnaam}`. Defaults: `kind 'btn'`, `prio 5`. The element is a `<button>`
(or `tagnaam`), class `hot` plus `hotdrop`/`hottag` plus `klas`, `data-hot="<id>"`, custom
data as `data-h-<key>`, aria-label from `titel`. A `tag` is `aria-hidden`, not focusable and
not clickable. `onWeg(spot)` runs exactly once, before the element leaves the page, also on
`wisEigenaar`.

Every frame, `Hits.plaats(kamer, projectie)` does:

1. **follow**: every hotspot with `volg()` takes its new `x, z, y, kamer, d`
   (so a bubble follows its animal, even into another room);
2. **visibility**: hotspots of other rooms are hidden (their catch area too);
3. **cull**: at most **16 buttons per room**. When there are more, they are sorted by layer
   then `prio` and the rest are hidden. Layers (`laagVan`): fixed cards and number tags = 3,
   the game that has priority = 2, wish bubbles (`hotwens`) = 0, everything else = 1;
4. **depth**: `_d = d ?? x + z`, sorted ascending; the DOM `z-index` is `20 + index`,
   i.e. exactly the drawing order, so a tap always hits the object you see in front;
5. **anchor and policy** (`o.op`, default `'auto'`):
   * `'auto'` → `'rand'` for a number tag, `'midden'` for a fixed card / own `html` /
     card class (`hotwens hotwolk hotsom hotpad hotkeuzes hotgetal`) / `y ≤ 0`,
     otherwise `'boven'`;
   * `'boven'`: the bottom edge of the button sits `GAT = 4` css-px above the aim point, so
     the object stays **completely visible (0 % coverage)**. If that would leave the frame,
     it silently becomes `'onder'`;
   * `'onder'`: the top edge sits 4 px below the floor point of the object
     (`y += vh + h/2 + 4`, with `vh = y · pxPerHoogte`);
   * `'midden'`: exactly on the aim point (the old behaviour);
   * `'rand'` (number tags): the tag drops its bottom edge just over the top edge of the
     object, covering at most **a tenth** of it (`TAG_IN = 0.1`);
   then the position is clamped inside the frame (26 px margin rule);
6. **evasion in four rounds** — placement order is by layer (fixed first, then the playing
   game, then hotel buttons, then wish bubbles), and inside a layer front-most first;
   a later chooser must give way:
   * round 0: only the natural direction (a `boven` button may not move down, an `onder`
     button not up), using the offset table `UITWIJK`: `dy 0..−3 × dx −2..+2` first, then
     `dy +1..+2 × dx −2..+2`, sorted by cost `|dy|·2 + |dx|·3`, in steps of
     `(w + 4)` horizontally and `(h + 3)` vertically;
   * round 1: all directions, but never back onto its own object;
   * round 2: **stacking** — row by row from the top edge of the frame downwards, five
     columns `dx ∈ [0, −1, +1, −2, +2]`; this is what makes three 148 px task cards plus
     five buttons fit in a 326 × 383 frame;
   * round 3: anything — two buttons covering each other is worse than a button covering a
     corner of its object. If even that fails it falls back to its first choice.
   Two rectangles overlap when `|dx| < (w1+w2)/2 − 1` **and** `|dy| < (h1+h2)/2 − 1`;
7. **short frame**: if there is a fixed card in view owned by the playing game (or, with no
   game playing, by a single owner), any button of *another* owner that would still land on
   that card or on that game's buttons is hidden for this frame (`display:none`,
   counted in `debug().verstopt`). Next frame, with the card gone, it is back;
8. **catch area** (`vangvlak`): a hotspot with `drop` that stands above or below its object
   gets a transparent rectangle = **the union of button and object**, carrying the same
   `data-drop` and `data-h-*`, in its own layer (`.vanglaag`, `z-index: 2`) under the button
   layer (`z-index: 3`). So dragging onto the object itself works, a real button always
   wins a tap, and `Hits.watRaakt` / any `#worldHits` query never sees it. A click on the
   catch area does exactly what a click on the button does.

Measurements (button width/height, frame size) are cached and only re-measured after
`Hits.hermeet()` (called from `World.meet()`) or when the button's HTML changes; a button
measured while hidden (0 × 0) is measured again next frame instead of caching the zero.

Fallback sizes are 56 × 48 px. `Hits.debug()` reports per spot: id, room, owner, depth,
z-index, visibility, position, size, `op`, anchor, object height `vh`, `weg`, the catch
rectangle and the object rectangle.

### 5.5 The answer input contract (`Ui.somkaart` and the keypad)

`Ui.somkaart(obj, som, o)` places a fixed card (`klas hotsom`, `vast: true`, `prio 14`) on
the aim point with height `o.hoog` (default 22 voxels).

* `o.regel` is **mandatory**: one plain Dutch sentence (or two short ones) above the sum,
  with the icon `o.icoon` first on the same line. Budget: **≤ 8 words and ≤ 40 characters**
  per line; more than two lines does not exist. Violations still draw, but log one
  `console.warn` per card (`somkaart "<id>" heeft geen regel: …` /
  `… heeft een regel van <n> woorden en <m> tekens; hooguit 8 woorden en 40 tekens …`).
* `o.max` digits (default 2), `o.open` opens the keypad at once, `o.pad: false` means no
  keypad at all, `o.keuzes` replaces the answer box and keypad with one strip of buttons
  (`{id, icoon, tekst, kies(k, api)}`), `o.keuzeTitel` is its aria title.
* Handle: `.regel(zin)`, `.som(tekst)`, `.zet(tekst)`, `.hulp(html)`, `.open()`,
  `.klaar()` (tick, keypad and strip away), `.weg()` (everything away), `.getal()`, `.id`.
* `o.onOk(n, kaart)` is called on ✓ with the number or `null` when nothing was typed.

**Keypad placement (`padPlek`)**: `'auto'` (default), `'binnen'`, `'buiten'`.
`'auto'` puts the pad **inside** the frame, hanging under the card at
`y = round(((x + z) − (box[3] + 44)) / 2)` — i.e. in the air below the room, so it never
covers the floor — except when the frame is lower than **300 px** or too narrow for one row
of six keys (needs 286 px below 360 px screen width, 310 px at 360, 326 px above), in which
case it becomes the **strip below the frame** (`#padstrip`, one row of twelve keys over the
full width). Coming back inside only happens above **340 px** (dead zone), the strip's own
height is discounted when measuring (`kaderHoogVrij`), its own layout change is ignored for
400 ms (`VERSTIL_MS`), and there are at most **2** in/out switches per screen size.
There is exactly **one** strip: a second card taking it over wins; keep at most one keypad
open. Keys are always findable as `[data-hot="<kaart-id>_pad"] [data-pk="7"]`, wherever the
pad is. Inside the frame the pad is two rows of six, or one row of twelve on a frame
≥ 660 px wide.
The card lifts itself if its own pad would cover it: measured after one draw, at most twice,
lifting by `ceil(overlap / (2k))` height steps.
The choice strip hangs at `hoog − round(((cardHeight/2) + (stripHeight/2) + 5) / (2k))`
height steps, i.e. glued under the card at any scale.

A card, its pad and its choice strip are **fixed**: they never give way, everything else
gives way to them. Use at most one at a time.

### 5.6 Bubbles, sources and number tags

* `Ui.wolk(obj, {icoon, getal, tekst, hoog, klas, prio, tik, id, door})` — a speech bubble
  on an object or animal, default height 52 voxels on an animal and 20 on an object,
  default prio 9. Without `tik` a tap reads the text aloud (`Ui.spreek`, Dutch
  `nl-NL`, rate 0.95, pitch 1.05; silently does nothing when unsupported).
  It follows its animal, also into another room.
* `Ui.bron(obj, {icoon, aantal, hand, klas, prio, titel, tik, sleep})` — a drag source with
  a counter and a "in your hand" badge; `zet(aantal, hand)`, `weg()`. One tap delivers
  exactly once (the browser's follow-up click is swallowed).
* `World.getalTag(obj, n, {id, y, klas, titel, prio, door, kamer})` — a number **on** an
  object (`kind: 'tag'`, default y 8, default prio 4); `n = null` removes it. It is not
  clickable and not focusable.

### 5.7 Dragging (`ctx.sleep` = `makeDraggable`)

Pointer events (mouse, pen, finger). A movement under 8 px counts as a tap
(`onTap`); beyond that a ghost element follows the pointer, and **with a finger the ghost
and the hit test sit 40 px above the fingertip** so the child can see the target. The drop
target is `document.elementFromPoint(...).closest(dropSel)`; the current target gets the
class `drop-hot`. `body.sleept` is set while dragging. The context menu is suppressed on
drag sources. After a tap or a drop, one following `click` on the same node is swallowed in
the capture phase (and the soft tap sound is played instead), so one tap delivers one item.

---

## 6. UI shell

### 6.1 Page structure (`index.html`)

```
#app
  .chroom          → header.topbar (logo + badges) and .rondebalk (round name, 📋, 🌙)
  .stagewrap
    .stagecol
      #world       → canvas #worldCv, .tags #worldTags, .hits #worldHits (+ .vanglaag)
      #padstrip    (hidden unless the keypad lives outside the frame)
      nav#kamerbalk
    main#scene     (the calculation panel; hidden when empty)
  footer.foot      "Dierenhotel Kwispelsteeg · demo · rustig aan, je mag alles zo vaak proberen als je wil"
#overlay > #sheet  (modal sheet)
#toast
```

Script order (load order matters — each module registers itself):
`art.js, rooms.js, hits.js, world.js, snd.js, ui.js, state.js, econ.js,
games/registry.js, hotel.js, games/*.js, game.js`.

### 6.2 Start screen (`game.js` `beginScherm`)

On boot: read the v7 save (or, failing that, the v5 shelter), always start a fresh
`newGame()` and `Hotel.start()` so a living world is visible behind the sheet, and then:

* **no save at all** → no sheet: `startKeuze = true` and the fresh game is saved;
* **a v7 save** → sheet:
  `Welkom terug in het Dierenhotel! 👋` and
  `Je was bij <n dag|dagen> — met <n gast|gasten>, <munten> munten en <sterren> sterren.`
  with buttons `Verder spelen ▸` and `Nieuw spel`;
* **only the old v5 shelter** → sheet:
  `Er staan nog dieren in de Kwispelsteeg! 🐾` and
  `Je oude opvang staat nog op deze tablet: <n gast|gasten>. Neem je ze mee naar het hotel? Ze krijgen dan een echt bed.`
  with buttons `Ja, verhuizen naar het hotel ▸` and `Nieuw spel`; after continuing it
  toasts `🛏 Geef iedereen een bed`.

`Hotel.start()` restores the world: first the furniture (`Games.herstelInrichting()`), then
`World.sync`, sleeping guests into their beds and everybody else into their room, the
pending desk guest back at (45, 93), show the world, jump the camera to `kamerNu`;
then build the tasks, render, subscribe to the layout bus, and finally: a half-finished
check-in is repainted (it comes first), otherwise the prikbord opens when the round is
`ochtend`.

### 6.3 Room navigation

* **Room bar** (`#kamerbalk`): one chip per room in `Rooms.lijst()` order — icon + name +
  a badge with `wachtIn(room)` — plus a last chip `🗺️ Plattegrond`. The bar is built **once**
  and only updated afterwards (otherwise the row scrolls back to the left on every event and
  the child taps the wrong room). `wachtIn(room)` counts the guests whose need is not yet
  fulfilled **and** whose waiting place is in that room, plus the guest at the desk for the
  receptie.
* **Map sheet**: header `🗺️ De plattegrond`, hint `Tik op een ruimte om er naartoe te gaan.`,
  a 4 × 3 grid with cells at `KAART = {receptie [1,2], gang [2,2], kamer1 [2,1],
  kamer2 [2,3], keuken [3,2], tuin [4,2], wasserij [3,3], zwembad [4,3]}` (column, row),
  each showing icon, name and the waiting badge, and a `Sluiten` button.
* `Hotel.naarKamer(id)` = `World.naar(id)` + `state.kamerNu = id` + `Snd.deur()` +
  `render()`.
* **Door hotspots**: one per door of the room in view, at the door point, `y = 9`, icon and
  label of the target room, title `Ga naar <naam>`, badge `wachtIn(target)`, class
  `hotdeur`, prio 8, and a drop target `deur` with `data = {naar, kamer}` — that is how the
  food trolley is pushed into the corridor.

### 6.4 The layout bus and a stable frame

One `ResizeObserver` watches three boxes: the frame `#world`, an invisible `100svh` measure
strip (`#worldSvh`) and `#app`. A width change measures immediately; a height-only change is
debounced by `KADER_WACHT = 120 ms`. Without `ResizeObserver` the same path hangs on
`resize` + `orientationchange`. A `MutationObserver` on `body.class` catches the
`metpaneel` switch (a calculation panel changes the frame without changing the window).

`World.onKader(fn)` subscribes and returns an **unsubscribe** function;
`fn({x, y, w, h}, schaal)` gets the frame rectangle in css-px and `World.schaal()` plus
`schaal.kamer`. It does not fire on subscribe. `World.kader()` reads the cached rectangle
(no layout read). `World.hermeet()` forces a measurement. `Ui.opKader(fn)` is the same thing
for games, falling back to `resize`/`orientationchange` (90 ms debounce) if the bus is
missing. **Always unsubscribe.**
`World.vuil()` only asks for a redraw; `World.hermeet()` re-measures the frame.

**Stable screen height.** `window.innerHeight` jumps 60–90 px when a phone's URL bar slides;
the world therefore measures `100svh` (or `visualViewport.height`, or `innerHeight`) and
*latches* it: a new height is only taken over when the width changed, the orientation
flipped, or the height moved by at least `HOOGTE_RUIS = 120 px`.

The hotel re-lays its hotspots on a real frame change: 180 ms after the bus fires, and only
when the signature `<frameW>x<frameH>|g:dicht:kamer|room` actually differs — this lock is
what stops the check-in repaint / keypad-strip feedback loop (measured without it: 61 bus
hits in 5 s).

### 6.5 Safe areas, tap sizes and the 12 px text floor

* `#app` padding uses `env(safe-area-inset-*)` with minimums 6/12/10/12 px (4/8/4/8 px in
  the low-landscape layout).
* `html { overscroll-behavior: none; touch-action: manipulation }`;
  `html.sheet-open { overflow: hidden }`; `body { min-height: 100dvh }`.
* Tap targets: `.btn` ≥ 52 px (`--tap`), `.hot` ≥ 48 × 48, `.badge.tap` ≥ 48,
  keypad keys 48 (44 below 360 px screen width), room chips 48 (44 below 359 px).
* **Text floor**: `clamp(12px, .75rem, 14px)` on button labels, wish labels, choice labels,
  badges, waiting badges, the source's hand badge, room chip names, map cell names, name
  plates, bubble text, the sentence on a sum card and its help line. Text set by a game's
  own inline `font-size` is not covered by that floor.
* Below 520 px the footer disappears; the sum card gets a smaller font and tighter padding;
  below 360 px the card is ~170 px wide, every sentence wraps to two lines (never
  ellipsised) and keys are 44 px.
* Landscape under 450 px high: header and round bar merge into one 48 px row, the logo is
  hidden, the room bar becomes a 3-column rail of 48 px chips **next to** the frame, the
  keypad strip spans the full width underneath, and the toast moves to the top.
* The room bar wraps rather than scrolling sideways (4 px gaps) so that all nine chips —
  including the map — are always visible.

### 6.6 Audio unlock, hidden tab, reduced motion

* **Audio**: no `AudioContext` exists before the first real touch. `pointerdown` and
  `touchend` (capture) unlock it, play a 1-sample buffer (the iOS trick) and resume the
  context; master gain is fixed at 0.16. Every sound is silent before that, without
  warnings. `Snd.dempt()` / `Snd.ontgrendeld()` / `Snd.schakel()` (which persists
  `kws-geluid` and plays a tick when unmuting). On `visibilitychange → hidden` the context
  is suspended. There are no angry sounds: `zacht` means "not yet", never a buzzer.
  Sounds used by the world itself: `tik` (every `.btn`, `.hot`, `.kchip`,
  `.padstrip .padk` click, via delegation), `bel`, `deur`, `ja`, `zacht`, `tover`, `munt`,
  `ster`, `brief`, `dag`. The games add `plop`, `terug`, `hoera`, `kar`, `plons`, `au`,
  `klok`, `hup`.
* **Hidden tab**: the animation loop stops (`document.hidden` → no rAF, no ticks, no
  drawing); on return the clock restarts (never catching up three heartbeats) and one frame
  is drawn. `game.js` saves the game on hidden and on `pagehide`.
* **Reduced motion** (`prefers-reduced-motion: reduce`): the world enters `rustModus` —
  nothing moves. Animals are placed instead of walking; `ga`/`reis`/`solo`/`feed`/`mood`
  teleport and freeze; a sleeper stays lying in his bed and a floater keeps floating;
  `stappen`/`loopNaar` run `perStap` per point in order, put the animal on the last point,
  give it the end pose and resolve `true` immediately; no particles at all; the camera
  jumps instead of sliding. CSS also disables the `bouncy`, `wiggle` and `pop` animations.
* **Redraw rule**: the world only redraws when the *input to drawing* changed — camera,
  travel, scale, canvas size, every animal (state, pose, facing, position, previous
  position, sway, bob, lift, height, particles, its swim pose, its accessory key), bowls,
  fixed decor, loose decor, loose things and the pool rectangle — or at most once every
  400 ms when everything stands still. While somebody is gliding between two ticks, every
  frame is dirty. Drawing is capped at ~31 fps.

### 6.7 Sheets and toasts

`openSheet(html)` fills `#sheet`, shows `#overlay`, and locks page scrolling; clicking the
backdrop closes it. Toasts (`toast(msg, kind)`) live 2600 ms, are never clickable
(`pointer-events: none`) and come in three colours: default (dark), `happy` (mint),
`kind` (peach).

---

## 7. Every child-facing string of the world, verbatim

### 7.1 Shell and HUD

| where | string |
|---|---|
| logo | `🛎️ Dierenhotel` |
| day badge | `📅 Dag` + number, title `Dag` |
| coin badge | `💰` + number, title `De kassa` |
| star badge | `⭐` + number, title `Sterren` |
| letters badge | `💌` + number |
| sound button | `🔊` / `🔇`, title `Geluid`, aria `Geluid aan of uit` |
| round name | `☀️ Ochtendronde` · `🌙 Avondronde` · `🐾 Vrij spelen` |
| buttons | `📋 Prikbord` · `🌙 Avond` |
| footer | `Dierenhotel Kwispelsteeg · demo · rustig aan, je mag alles zo vaak proberen als je wil` |
| room chips | `Receptie` `Gang` `Kamer 1` `Kamer 2` `Keuken` `Tuin` `Zwembad` `Wasserij` `Plattegrond` |

### 7.2 Start screen

`Welkom terug in het Dierenhotel! 👋` ·
`Je was bij <dagen> — met <gasten>, <munten> munten en <sterren> sterren.` ·
`Verder spelen ▸` · `Nieuw spel` ·
`Er staan nog dieren in de Kwispelsteeg! 🐾` ·
`Je oude opvang staat nog op deze tablet: <gasten>. Neem je ze mee naar het hotel? Ze krijgen dan een echt bed.` ·
`Ja, verhuizen naar het hotel ▸` · toast `🛏 Geef iedereen een bed`

### 7.3 Map sheet

`🗺️ De plattegrond` · `Tik op een ruimte om er naartoe te gaan.` · `Sluiten`

### 7.4 Receptie: hotspots and the bell

`Bel` (title `Bel voor de volgende gast`) · `Prikbord` (title `Het prikbord met de taakjes`) ·
`Avond` (title `De avondronde`) · `Vrij bed` (title `Een vrij bed`) ·
`Speelmand` (title `De speelmand`) · `Vol` / `Leeg`
(titles `Er ligt eten in het bakje` / `Het bakje is nog leeg`) ·
`Ga naar <kamernaam>` · bell-full bubble `🛏 <maxGasten> alle bedden vol` ·
toast `🛎️ Er staat al iemand` · toast `<naam> staat aan de balie! 🔔`

### 7.5 Check-in

`De gasten eten <n> schep|scheppen per dag` · `<naam> eet <n> erbij. Samen?` ·
`Elke dag <n> schep|scheppen, <n> dag|dagen lang` · `📦 In huis: <n> schep|scheppen. Genoeg?` ·
choice title `is er genoeg eten?` · `te weinig` `precies` `blijft over` ·
`Kies een bed` · `Alles bezet` · `welterusten` ·
toasts: `👆 Tik eerst een getal` · `Precies! 🎉` · `🥄 Tel ze samen` · `Goed gerekend! 🎉` ·
`🥄 <dagen> × <nieuw> = <product>` · `<naam> slaapt hier. 💤` · `🛏 Bel eerst een gast` ·
`💤 Hier slaapt iemand`

### 7.6 Feeding, playing, wishes

Wish bubbles: `🍪 eten` `🛏 bed` `🛁 bad` `🧶 spelen` `🏊 zwemmen` `🎁 souvenir`
(title `<naam> wil eten` / `wil een bed` / `wil in de tobbe` / `wil spelen` /
`wil zwemmen` / `wil een souvenir`; tapping toasts that same sentence plus the icon).
Toasts: `Smakelijk eten! 😋` · `🍪 Vul eerst de voerkar` · `🍽 Hier slaapt niemand` ·
`🧶 Straks samen spelen` · `<naam> speelt met het balletje! 🧶` ·
`Ze spelen allemaal met het balletje! 🧶`

### 7.7 Prikbord

`Bel een gast` · `Nog een bed vrij` · `<naam> wil een bed` · `Vul de voerkar` ·
`Reken af: <naam>` · `<naam> wil spelen` · `Speel lekker rond` ·
day messages `voer: <n> 🥄` · `Els bracht 10 🥄` · `<naam> gaat naar huis`
(game cards: `<naam> wil in bad` / `Tobbe-tijd` · `Zet de bedden op rij` ·
`Hang de sleutels op` · `Koop iets moois` · plus the golf-3 cards from their own files)

### 7.8 Evening, bill and letters

`Morgen ▸` · `<naam> gaat naar huis` ·
`<naam> sliep <n> nacht|nachten, €<prijs> per nacht` ·
`<naam> gaf €<betaald>, het kost €<totaal>` · `klaar` (title `klaar met tellen`) ·
`de toonbank` · `munt van <n> euro` · `de buidel is leeg` ·
`op de toonbank ligt €<n>` · `tik een getal` · `zo ziet het uit` ·
`zoveel is het samen` · `dit moet er nog bij` · `zoveel krijgt de familie terug` ·
`terug` / `betaald` ·
`💌 Er is post!` · `Hang de brief op de muur 📌` · toast `💌 Aan de muur!` ·
`💌 De brievenmuur` ·
`Hier komen de bedankjes van de families die hun dier bij jou lieten slapen.` ·
`Laat een gast zijn nachten uitslapen en reken netjes af — dan komt er post.` · `Sluiten` ·
letter title `Bedankje van familie <fam> 💌` and the body of §3.6

### 7.9 Kassa sheet

`💰 De kassa` · `💰 <n> munten` · `⭐ <n> sterren` · `🍬 <n> in de snoeppot` ·
`Munten komen uit het uitchecken: elke gast betaalt zijn nachten. Sterren krijg je voor meedoen — of je som klopt of niet.` ·
`In het meubelboek koop je straks nieuwe bedden, mandjes en badkuipen. Meer bedden = meer gasten = grotere sommen.` ·
`Sluiten`

### 7.10 Other

Registry failure toast: `💛 Probeer iets anders`.
Number words `Ui.woord(0..20)`: `nul een twee drie vier vijf zes zeven acht negen tien elf
twaalf dertien veertien vijftien zestien zeventien achttien negentien twintig`.
`meervoud(n, een, veel)` = `"1 nacht"` vs `"3 nachten"` — always used, a wrong plural makes
a six-year-old read the sentence twice.

---

## 8. Open questions for the port

1. **Idle randomness is session-seeded.** `ZAAD = (Date.now() >>> 3) & 0xffff` mixes into
   every animal's PRNG, so wandering, blinking and happy styles differ per session and are
   not reproducible from the save. Should the Godot port seed from the day number (making
   the world deterministic) or keep the wall-clock seed?
2. **The garden tufts depend on JavaScript integer semantics** (`Math.imul`, `>>> 0`). A
   port that wants the identical lawn must reproduce 32-bit unsigned wrap-around exactly;
   otherwise the tuft positions drift. Is bit-identity required, or is "same style" enough?
3. **`state.taken` is saved but rebuilt from a fingerprint on load.** A card ticked today
   survives a reload only through that array; whether a reload mid-day should keep the ✅ of
   a task that is no longer "needed" is not stated anywhere — the code keeps it because the
   array is saved. Confirm the intent.
4. **`state.rekening` is in the defaults but never written**; `Econ` keeps its bill in a
   module variable. A reload during a bill therefore loses the counted coins and restarts
   the checkout from the evening bubble. Intended, or a gap to close in the port?
5. **`geslapen` counts only guests who have a bed**, and `uitcheck` is computed exclusively
   in `morgen()`. A guest who gets a bed late in the day still has a full night counted the
   next morning. Confirm.
6. **The day planner is frozen but unused.** `planbord/maakPlan/planOplossingen` are fully
   implemented in `state.js` and referenced by HOTEL.md §5 as "dagplanner op het prikbord".
   Port it now (dead code today) or leave it out?
7. **`badGast` uses `state.gasten[0]`** for the even-day tobbe turn, i.e. insertion order,
   not a rotation like the new wishes. Deliberate asymmetry or a leftover?
8. **`wensAf` for `behoefte === 'kamer'`** returns whether the guest has a bed but does not
   change anything; a game calling `behoefteKlaar(id, 'kamer')` therefore gets `false`
   silently. Should the port treat that as an error?
9. **Priority of the desk lamp**: the evening hotspot only appears when there is somebody to
   check out (`avondKlaar()`), while the `🌙 Avond` button in the bar always works. That
   makes two entrances with different conditions; confirm the intended behaviour.
10. **Frame constants are tuned against CSS measurements** (`KADER_ONDER = 132`,
    `WAND_ZICHT = 56`, `KADER_MIN = 200`, the 60 % fill rule, the 300/340 px keypad dead
    zone). In Godot with a fixed base resolution and a stretch mode these numbers need a
    new derivation; X4 proposes the tablet base resolution. Which of these are hard design
    rules (the floor is never cut, the prikbord stays visible) versus HTML workarounds?
11. **`Rooms.registerModel` protects only own properties** of the built-in table; a game
    could register `'toString'` because that is an inherited key. Harmless today, but the
    port should decide on a name policy.
12. **Two rooms are never entered by guests on their own**: nothing in the hotel sends a
    guest to the `wasserij`, and only the `zwemmen` wish sends one to the `zwembad`. Is idle
    wandering into those rooms intended (it cannot happen — `kies()` never leaves a room)?
