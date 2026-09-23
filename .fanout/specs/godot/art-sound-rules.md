# Art, sound, style and binding design rules — port specification for Godot 4.7

Source of truth: `demos/dierenhotel/art.js`, `snd.js`, `style.css`, `index.html`,
`rooms.js` (decor models + floors), `world.js` (camera, world-side drawing), `ui.js`
and `hits.js` (frame/keypad/hotspot rules), plus `HOTEL.md` and
`demos/dierenhotel/GAMES-API.md` §9. Everything below was read out of that code on
2026-09-09; numbers marked **(measured)** were produced by running the real code in
headless chromium (scripts and outputs in `/tmp/dh-art/` and `/tmp/dh-snd/`).
Anything I could not establish from the code is marked **(inferred)**.

Companion specs: `world.md` (X1) owns rooms/guests/state/game contract, `games-*.md`
(X2/X3) own the minigames. This document owns *how it looks and sounds* and *which
rules bind every screen*. Where a rule also appears there, it is repeated here in full
because a Godot worker reading only this file must be able to obey it.

Language note: all child-facing strings are Dutch and are quoted **verbatim**. Do not
translate them, do not re-word them, do not add punctuation.

---

## 1. The rendering model

### 1.1 What kind of art is this

Not voxel 3D, not pixel art, not vector, not emoji sprites: it is **hand-built voxel
models rasterised to 2-D canvas polygons in a fixed 2:1 dimetric (isometric)
projection with a painter's algorithm**. There is no 3-D scene, no camera matrix, no
mesh, no external image file anywhere in the project. Every pixel you see in the world
is drawn by `CanvasRenderingContext2D.fill()` on three-sided rhombi.

Emoji appear **only in the HTML/DOM layer** (buttons, badges, room chips, task cards,
speech bubbles). The single exception is the sleep mark 💤 above a sleeping guest,
which is *not* an emoji: `world.js` draws three block-built "Z" glyphs (§11.3).

### 1.2 Voxel geometry

Constants (`art.js`): `S = 2`, `HG = 2`. One voxel is drawn as three faces:

| face | drawn when | polygon (relative to the face origin `x,y`, with `b = S·g`, `h = g`, `d = HG·g`) |
|---|---|---|
| top (`ct`) | no voxel at `y+1` | `(x,y) (x+b,y+h) (x,y+b) (x−b,y+h)` — a rhombus `2b` wide, `b` tall |
| right (`cr`) | no voxel at `x+1` | `(x+b,y+h) (x,y+b) (x,y+b+d) (x+b,y+h+d)` |
| left (`cl`) | no voxel at `z+1` | `(x−b,y+h) (x,y+b) (x,y+b+d) (x−b,y+h+d)` |

So at scale `g` one voxel occupies **4·g px wide** and **4·g px tall** (2·g of top
rhombus + 2·g of side wall). At `g = 1` that is a 4×4 px footprint. Each polygon is
both filled and stroked with the same colour at `lineWidth = 1`, `lineJoin = 'bevel'`
— the stroke closes the half-pixel seams between neighbouring rhombi. **Do not drop
the stroke in the port; without it a 1-px hairline grid appears between voxels.**

Hidden-face culling: a face is emitted only when the neighbour in that direction is
absent. Faces are sorted ascending by `d = x + y + z` and painted in that order
(painter's algorithm). The viewer sees the `+x`, `+y` and `+z` sides.

### 1.3 Projection (the only two formulas that matter)

Per voxel, in *voxel-pixels* (the unit before the whole-number scale `g`):

```
px = (x − z) · S          = 2·(x − z)
py = (x + z) · (S/2) − (y + 1) · HG   = (x + z) − 2·(y + 1)
```

Per world point, in css-px inside the world frame (`world.js`, `GAMES-API.md` §4):

```
screen-x = px0 + (x − z) · 2k
screen-y = py0 + (x + z − 2y) · k        with k = q = css-px per voxel-px
```

`x` runs along the room's length, `z` along its depth, `y` upward from the floor.
`+x−z` is right on screen; larger `x+z` is nearer the viewer (drawn later).

**Worked example.** Guest at room voxel `(30, 27)`, standing on the floor (`y = 0`), in
`kamer1` on an iPad in landscape where `k = 1.784` **(measured)**, with the camera
origin at `px0 = py0 = 0`: `screen-x = (30 − 27)·2·1.784 = 10.7 px`,
`screen-y = (30 + 27 − 0)·1.784 = 101.7 px`.

### 1.4 The three scale numbers (HOTEL.md §1)

| symbol | meaning | range |
|---|---|---|
| `q` (`k` in the game API) | css-px per voxel-px — how big the room looks | free, ≈0.58–1.95 **(measured)** |
| `g` | canvas-px per voxel-px — the **voxel size**, always a whole number | 2…4 in the world, 1…5 on cards |
| `dicht` | canvas-px per css-px — the draw density of the canvas | ≥ screen density; free, fractional |

`q = g / dicht`. **A minigame must read `ctx.wereld.schaal()` and never
`devicePixelRatio`.** Per room: `q = min((frame_w − 4)/box_w, (frame_h − 4)/box_h_needed)`,
then `g = clamp(round(q·d), 2, 4)`; if `g/d < 0.9·q` then `g = clamp(ceil(q·d), 2, 4)`;
finally `dicht = max(d, g/q)` where `d` is the screen density lower bound (§13.2).

### 1.5 Plate baking and blitting

Each `(model, pose, g, accessory-set)` is baked once into an offscreen canvas
("plaat") and thereafter only blitted. A plate is `{cv, dx, dy}` where `dx = box[0]·g − pad`
and `dy = box[2]·g − pad` with `pad = 2` **canvas px (not scaled by g)**. It is drawn at
`(anchor_x·g + dx, anchor_y·g + dy)`. The anchors are:

| anchor | voxels | used for |
|---|---|---|
| `Art.kit.dierAnker` | `[13, 7.5]` | centre of the four paws of a guest |
| `Art.kit.komAnker` | `[29.5, 7.5]` | centre of the feeding bowl |

Mirroring (`d.face < 0`) is done by drawing the same plate through `scale(-1, 1)` about
the guest's screen-x. **No mirrored textures are needed.**

Caches: `poseCache` (plain models, unbounded, 4 species × 15 poses = 60 entries),
`tooiCache` (dressed models, LRU, `TOOI_MAX = 72`), `plaatCache` (rasterised plates,
LRU, `PLAAT_MAX = 110`), `komCache` (bowls, unbounded).

### 1.6 Silhouette treatment

Two post-processes run on every plate:

1. **`omlijn`** — a soft dark contour of width `max(1, round(g / 2.6))` px
   (`g=2→1`, `g=3→1`, `g=4→2`, `g=5→2`), colour `rgba(112,90,76,.26)`, drawn
   *behind* the shape (`destination-over`) from a dilated copy of the silhouette.
   For the bowl the outline is computed on the **whole** bowl (front + back walls) so
   the two halves share one contour; the front wall itself is drawn with
   `silhouet = false` (no outline of its own).
2. **`rondAf`** — only when `g ≥ 2`: every opaque pixel (alpha ≥ 200) that has two or
   more empty orthogonal neighbours (alpha < 40) gets alpha 112. This shaves exactly
   one pixel off each staircase corner. The shape stays voxel; the edge stops biting.

---

## 2. Palette (every hex value)

### 2.1 Guests (`art.js`)

| role | key | hond | poes | konijn | gans |
|---|---|---|---|---|---|
| fur | `b` | `#EEC194` | `#C9CCDC` | `#F5E7EC` | `#FDF8EA` |
| dark fur | `d` | `#D3996A` | `#A0A6C0` | `#DCC6D3` | `#E0D8C2` |
| accent | `e` | `#B4744A` | `#F4C8D5` | `#F5B0C2` | `#F6A957` |
| light | `l` | `#FCE8D3` | `#EDEFF6` | `#FFFBF6` | `#FFFCF4` |

Shared: ink `#4A3B33`, white `#FFF7EC`, eye `#5B4840` (soft dark brown, **never
black**), nose/mouth `#7E6255`, dog collar (`BAND`) `#6BC5A4`, outline ink
`rgba(112,90,76,.26)`.

Bowl (`KOM`): dish `#DFC6D6`, rim `#F8E7F1`, kibble `#BC8149`, second kibble `#97663A`.

Accessories: hat `#6BC5A4` with ribbon `#FFF7EC`; scarf `#F6A957` with fringe
`#FFF7EC`; ball `#F4C8D5` with band `#FFF7EC`.

### 2.2 Decor and rooms (`rooms.js`)

`HOUT #D0A87A`, `HOUT_D #B98F62`, `HOUT_L #E2C094`, `STAM #B08A6A`, `BLAD #A6CE8E`,
`BLAD_A #A9D08F`, `BLAD_B #B2D797`, `DAK #E79C7C`, `MUUR #F6E2C8`, `DEURKL #8B6F5C`,
`WATER #A9D8E6`, `KUSSEN #FFF7EC`, `DEKEN #A9D3F0`, `DEKEN_D #84B4D8`, `STOF #F5B0C2`,
`METAAL #C9CCDC`, `METAAL_L #EDEFF6`, `GOUD #F2C14E`, `GOUD_D #D9A72F`, `POT #D98E6A`,
`PAPIER #FFFDF3`.

### 2.3 Floors — colour per 1×1 voxel tile, keyed by a hash or by `>>2` blocks

| floor `vloer` | rule | colours |
|---|---|---|
| `hout` (receptie) | every 4th row `PLANK_D`, else `PLANK[(z>>2)&1]` | `#E4CBA6` `#DCC29B`, dark `#D2B58C` |
| `tegel` (keuken, zwembad, wasserij) | `TEGEL[((x>>2)+(z>>2))&1]` — 4×4 checker | `#EDE6DA` `#D9E6E2` |
| `zacht` (kamer 1/2) | `ZACHT[(z>>2)&1]` | `#E6D3B8` `#DFC9AC` |
| `loper` (gang) | runner `LOPER_M[(x>>2)&1]` for `8 ≤ z < d−6`, edges `LOPER[hash&1]` | runner `#D68FA0` `#CE8496`, edge `#E9DCC6` `#E2D3BA` |
| `gras` (tuin) | inside the fence `GRAS[hash&3]`, outside (`x<10` or `z<10`) `WEI[hash&1]` | `#AFD595 #AAD190 #B4D89A #ACD392`, meadow `#9DC486 #98C081` |
| mats (`matten`) | rectangle overrides everything, `kl[hash&1]` | receptie `#E9BFC9 #E3B4C0`, kamer1 `#DFCBEA #D6BFE4`, kamer2 `#CBE3D6 #BFDBCB` |
| pool (`bad`) | inner water `BADWATER[hash&3]`, outer 4 voxels of the water `BADKANT[hash&1]`, 4-voxel stone rim `BADRAND[((x>>2)+(z>>2))&1]` | `#9CD1E4 #A9D8E6 #93CBE0 #A2D4E5`; edge `#5AA3C2 #66ABC8`; rim `#FFFDF3 #FCF8EA` |

`hash2(x,z) = (Math.imul(x·73856093 ^ z·19349663, 2654435761) >>> 24)` — a stable
per-tile hash; reproduce it exactly or the floor speckle changes.

### 2.4 UI palette (`style.css` `:root`)

`--bg #FFF4E8`, `--bg2 #FFE9D6`, `--card #FFFDF8`, `--ink #4A3B33`, `--ink2 #8A7566`,
`--peach #FFB88C`, `--peach-d #F2915B`, `--mint #A7DEC6`, `--mint-d #5FBF9B`,
`--lilac #CBB8EA`, `--sky #A9D3F0`, `--pink #FFC7D9`, `--sun #FFDD8C`,
`--gold #F2C14E`, `--cork #E8CFA6`, `--r 22px` (corner radius),
`--tap 52px` (default button minimum), and
`--shadow: 0 4px 0 rgba(74,59,51,.14), 0 10px 24px rgba(74,59,51,.10)`.

Page background: `radial-gradient(1200px 600px at 50% -10%, var(--bg2), var(--bg)) fixed`.
World frame: `linear-gradient(#EFDFC9,#E1CDB2)` behind the canvas, `5px solid #FFFDF8`
border, radius 26 px, `box-shadow: 0 5px 0 rgba(74,59,51,.13), 0 14px 28px rgba(74,59,51,.12), inset 0 0 0 2px #EFE4CF`.

---

## 3. Light and shading

Three direction tints × five ambient-occlusion steps, then a colour *mix* (not a
multiply):

```
F_TOP = 1.10   F_RECHTS = 0.90   F_LINKS = 0.72
AO    = [1, 0.972, 0.946, 0.928, 0.914]     indexed by the number of neighbours (0..4)
WARM  = (255,248,236)   KOEL = (116,100,116)

shade(hex, m):
  doel = m >= 1 ? WARM : KOEL
  t    = m >= 1 ? min(1, (m − 1)·1.25) : min(1, (1 − m)·1.55)
  out  = round(c + (doel − c)·t)     per channel, clamped to 0..255
```

`m` for a face is `F_face · AO[n]`, where `n` counts the occupied neighbours listed in
`bake()` (top face: `x±1,y+1,z` and `x,y+1,z±1`; right face: `x+1,y±1,z` and
`x+1,y,z±1`; left face: `x,y±1,z+1` and `x±1,y,z+1`).

**Worked example** — dog fur `#EEC194 = (238,193,148)`, top face, no neighbours:
`m = 1.10`, `t = min(1, 0.10·1.25) = 0.125`, → `(240,200,159)` **(measured, matches
the running engine)**. Same colour, left face, no neighbours: `m = 0.72`,
`t = min(1, 0.28·1.55) = 0.434` → `(185,153,134)`.

Reference values **(measured)** for the four fur colours, `AO[0]` / `AO[4]`:

| fur | top | right | left | top (4 nb) | right (4 nb) | left (4 nb) |
|---|---|---|---|---|---|---|
| `#EEC194` | `240,200,159` | `219,179,143` | `185,153,134` | `238,193,149` | `204,167,139` | `173,144,131` |
| `#C9CCDC` | `208,210,222` | `188,188,204` | `164,159,175` | `201,204,220` | `178,175,191` | `156,149,165` |
| `#F5E7EC` | `246,233,236` | `225,211,217` | `189,174,184` | `245,231,236` | `210,195,203` | `177,162,172` |
| `#FDF8EA` | `253,248,234` | `232,225,216` | `194,184,183` | `253,248,234` | `215,207,202` | `180,170,171` |

The design intent recorded in the source: warmer tints and smaller contrast than the
first version; eyes and noses are warm brown, never near-black — "dat haalt de
robot-blik uit de koppen".

---

## 4. The four guests

Grid: `x` = length (0 = tail, ~29 = nose), `y` = height (0 = ground), `z` = depth
0…15 with the heart at 7.5. The feeding bowl sits at `x` 26…33.

**Model census (measured, `Art.stats()` on pose `rust`):**

| species | voxels | culled faces | l × h × d (voxels) |
|---|---|---|---|
| hond | 3102 | 777 | 29 × 23 × 18 |
| poes | 2108 | 575 | 25 × 23 × 10 |
| konijn | 2768 | 708 | 27 × 28 × 10 |
| gans | 1584 | 467 | 21 × 27 × 14 |

### 4.1 Build primitives

| helper | signature | what it makes |
|---|---|---|
| `bx` | `(v,x,y,z,w,h,d,c)` | axis-aligned box of voxels |
| `ell` | `(v,cx,cy,cz,rx,ry,rz,c,{e,lim,ymin})` | superellipsoid; `e` = 2 (egg) … 3.4 (rounded cube), `lim = 1.02`, `ymin` = flat bottom |
| `hals` | `(v,x0,y0,x1,y1,cz,r,rz,c)` | capsule/neck along a 2-D line; z-radius `rz·(0.55 + 0.45·√(1 − d²/r²))` |
| `punt` | `(v,x,y,z,w,h,d,c)` | tapering spike (ear, tail) — width shrinks by `floor(j·w/h)` per layer |
| `verf` | `(v,x0,x1,y0,y1,z0,z1,c)` | *repaint existing voxels only* — eyes, nose, socks, collar, bib. Never adds a voxel, so a detail always lands on the outermost face. |

### 4.2 Per-species geometry (exact values from the code)

**hond** — 4 legs at `[[5,3],[5,9],[13,3],[13,9]]`, box 4×(7−py)×4 in `d`, light foot
5×2×4 in `l`, toe line in `d`. Body `ell(10.5, 9.5, 7.5, 7.0, 4.4, 5.8, b, {e:3.4, ymin:5})`,
light bib repainted over `x 14..18, y 5..9, z 3..12`. Tail = three 3×3×3 blocks
curling up (or a low variant). Neck `hals(16,12, 20+hx,15+hy, 7.5, 2.8, 3.6)`; mint
collar repainted at `x 15..16, y 9..12, z 3..12`. Head `ell(22+hx, 17+hy, 7.5, 4.4, 5.0, 5.6, {e:3.2})`,
muzzle `ell(27+hx, 15+hy, 7.5, 2.4, 2.4, 3.4, l, {e:2.8})`, nose repainted at
`x 28..29+hx, y 16..17+hy, z 7..8`. Floppy ears: two `ell(ox+hx, oy+hy, 0.6 / 14.4, 1.9, 3.4, 1.8, e, {e:3.0})`
with `ox = 21, oy = 17` normally, `oy = 21` when `oor='perk'`, `oy = 14` when `'hang'`,
`ox = 23, oy = 18` when `'vooruit'`. Eyes `ogen(25+hx, 18+hy, z 4 / 11, h2 w2 dik2)`.

**poes** — slimmer legs 3×(8−py)×3 with white socks. Body
`ell(10.5, 10.5, 7.5, 6.4, 4.2, 5.0, {e:3.2, ymin:6})`, white bib `x 14..17, y 6..10, z 4..11`.
Long tail with two dark rings and a white tip. Neck `hals(15,12, 19+hx,15+hy, 7.5, 2.4, 3.0)`.
Head `ell(21+hx, 16.5+hy, 7.5, 3.8, 4.0, 4.8, {e:3.2})`, muzzle
`ell(25.5+hx, 14.5+hy, 7.5, 1.8, 1.8, 3.2, l, {e:2.8})`, pink nose at `x 26..27+hx, y 15+hy, z 7..8`.
Pointed ears via `punt(ex+hx, 18+eo+hy, z 4 / 9, 3,5,3)` with `ex = 20` when
`'vooruit'` else 18, `eo = 1` when `'perk'`; pink inner ear repainted. When `'hang'`
the ears become flat 3×2×3 boxes at `y 18+hy`, `z 2` and `z 11`.

**konijn** — long hind feet `bx(5+hs, 0, 3 / 9, 7,3,4, l)` with dark toe lines, haunches
`ell(9+hs, 5, 4.8 / 10.2, 3.5, 3.7, 2.3, {e:3.0, ymin:2})`, small front paws
`bx(14, vy, 4 / 9, 3, 7−vy, 3)`. Hop instead of walk: `hs = +2` on `stap 1`, `−1` on
`stap 2`; `vy = 2` on `stap 1`. Body `ell(11, 10, 7.5, 6.2, 5.0, 5.2, {e:3.2, ymin:5})`.
Pom-pom tail `ell(3.2, 9.5|12, 7.5+tz, 2.3, 2.3, 2.3, l, {e:3.0})`. Head
`ell(21+hx, 17+hy, 7.5, 4.2, 4.4, 5.2, {e:3.2})`, muzzle `ell(25.5+hx, 15+hy, …1.8,1.8,3.0)`,
pink nose `y 15+hy`, white teeth `y 13+hy`. Ears: upright
`ell(ox+hx, 19+oh+hy, 4.4 / 10.6, 1.8, oh, 1.6, d, {e:3.0})` with `ox = 22` when
`'vooruit'` else 19, `oh = 5.0` when `'perk'` else 4.4; `'hang'` swings them down along
the head; **`p.lig` lays them flat along the back** (`ell(15+hx, 16, 2.4 / 12.6, 4.8, 1.6, 1.6)`)
so they do not stick up out of the bed.

**gans** — its head reaches further than a muzzle, so it gets its own head offset:
`hx = round(p.hx · 2.5)`, `hy = p.hy < 0 ? round(p.hy · 2.2) : p.hy`. Orange webbed
feet `bx(8±gs, 0, 3/10, 5,1,3)` and legs `bx(9±gs, 1, 4/10, 2,7,2)`, waddling with
`gs = ±2`. Body `ell(10, 10.5, 7.5, 6.2, 4.6, 5.2, {e:3.0, ymin:5})`, wings
`ell(10, wy, 2.0 / 13.0, 4.6, 3.0, 1.5, {e:3.0})` with `wy = 11.5 / 9.5 / 10.5` for
`perk / hang / other`, one feather line each. Pointed tail `punt(3, 9|11, 6+tz, 3,3,4)`.
Long neck `hals(14,13, 19+hx, ky+1, 7.5, 1.9, 2.2)` with `ky = 21 + hy`; small head
`ell(19+hx, ky+3, 7.5, 2.8, 2.8, 3.0, {e:2.8})`; beak `bx(21+hx, ky+2, 6, 3,2,4, e)`.
Eyes are 1×1 (`h:1, w:1, dik:2`).

### 4.3 Face details

`ogen(v, p, x, y, z1, z2, o)` paints a block on both sides of the head, mirrored in z,
with a white highlight on the top layer (`o.glans !== false`, only when `h > 1`):

| `p.oog` | meaning | effect |
|---|---|---|
| `0` | normal | block `h` high (2 for dog/cat/rabbit, 1 for goose) |
| `1` | happy | squint: one layer at the top of the block |
| `2` | sad | half closed: `h − 1` |
| `-1` | looking at the bowl | shifted one voxel down |
| `3` | asleep | one layer, one voxel **wider**, painted in nose brown `#7E6255` — a soft lash stroke |

`mond(v, p, x, y, z1, z2, zacht)`: `p.mond === 1` = open (happy/biting) — a line
`z1+1 … z2−1`; `p.mond === 2` = soft down-turned corners — only `z1` and `z2`.
**Never crying, never angry; the face must stay visible.**

### 4.4 Gait

`duwen(stap)` returns `[s, −s, −s, s]` with `s = +1` for `stap 1`, `−1` for `stap 2`,
`0` otherwise: a diagonal gait (left-rear + right-front together). The forward leg is
pushed `±2` voxels along `x` and lifted 1 voxel (`py = 1`, so its height is `ph = 7 − py`
for the dog, `8 − py` for the cat). The rabbit ignores this and hops (§4.2); the goose
waddles with `gs`.

---

## 5. Poses

15 poses, all *frame poses* — real geometry changes, **never a CSS transform**.

| pose | hx | hy | oor | staart | mond | oog | extra | used for |
|---|---|---|---|---|---|---|---|---|
| `rust` | 0 | 0 | rust | mid | 0 | 0 | | idle |
| `tril` | 0 | 0 | perk | r | 0 | 0 | | idle twitch (4 of every 108 frames) |
| `hap1` | 1 | −4 | vooruit | l | 1 | −1 | | biting, up |
| `hap2` | 2 | −7 | vooruit | r | 1 | −1 | | biting, down (eats one level) |
| `blijA` | 0 | 0 | perk | l | 1 | 1 | | happy A |
| `blijB` | 0 | 2 | perk | r | 1 | 1 | | happy B |
| `sip` | 0 | −1 | hang | laag | 2 | 2 | | gently sad — head slightly down, ears and tail hang |
| `zwaai` | 0 | 0 | rust | l | 0 | 0 | | waving |
| `kijk` | −1 | 1 | perk | l | 0 | 0 | | looking around |
| `loopA` | 1 | 0 | rust | l | 0 | 0 | `stap:1` | walk A |
| `loopB` | 1 | 0 | rust | r | 0 | 0 | `stap:2` | walk B |
| `zit` | 0 | 1 | rust | laag | 0 | 0 | `zit:1` | sitting |
| `zitsip` | 0 | 0 | hang | laag | 2 | 2 | `zit:1` | sitting sad |
| `lig` | 0 | −1 | hang | laag | 0 | 3 | `lig:1` | lying on the mattress, eyes closed |
| `snuif` | 1 | −6 | vooruit | mid | 0 | −1 | | sniffing |

Only nine poses decide the canvas size of a card sprite:
`['rust','tril','hap1','hap2','blijA','blijB','sip','snuif','loopA']`.

Two post-transforms replace per-pose models:

* **`zitten(v)`** (`zit:1`): the rear sinks, the head stays up. Per voxel
  `t = (x − x0)/(x1 − x0)`, `y −= round((1−t)²·5)`, clamped at 0.
* **`liggen(v)`** (`lig:1`): the legs (the bottom `POOT = 7` layers) are squashed to
  30 % (`y ≤ 7 → round(y·0.3)`), everything above shifts down by `7 − round(7·0.3) = 5`.
  Light is baked **after** this step, so no shadow falls the wrong way.

### 5.1 Plate sizes per species and pose (measured, in voxel-px; offset = the plate's
top-left relative to the anchor)

| pose | hond | poes | konijn | gans |
|---|---|---|---|---|
| rust | 64×60 @ −16,−29 | 58×58 @ −14,−29 | 60×64 @ −16,−34 | 54×57 @ −18,−31 |
| tril | 68×61 @ −20,−30 | 60×56 @ −16,−27 | 62×67 @ −18,−37 | 54×57 @ −18,−31 |
| hap1 | 70×62 @ −16,−31 | 60×60 @ −14,−31 | 62×52 @ −16,−22 | 60×46 @ −18,−20 |
| hap2 | 76×58 @ −20,−27 | 64×56 @ −16,−27 | 66×50 @ −18,−20 | 64×46 @ −18,−20 |
| blijA | 64×62 @ −16,−31 | 58×60 @ −14,−31 | 60×67 @ −16,−37 | 54×57 @ −18,−31 |
| blijB | 68×65 @ −20,−34 | 60×59 @ −16,−30 | 62×71 @ −18,−41 | 54×61 @ −18,−35 |
| sip | 66×50 @ −18,−19 | 62×48 @ −18,−19 | 60×49 @ −16,−19 | 54×53 @ −18,−27 |
| zwaai | 64×62 @ −16,−31 | 58×60 @ −14,−31 | 60×64 @ −16,−34 | 54×57 @ −18,−31 |
| kijk | 62×64 @ −16,−33 | 56×60 @ −14,−31 | 58×70 @ −16,−40 | 50×61 @ −18,−35 |
| loopA | 70×62 @ −20,−31 | 62×60 @ −16,−31 | 60×60 @ −14,−33 | 60×52 @ −18,−28 |
| loopB | 70×56 @ −20,−27 | 62×54 @ −16,−27 | 64×63 @ −18,−33 | 60×56 @ −18,−28 |
| zit | 66×55 @ −18,−24 | 62×53 @ −18,−24 | 60×65 @ −16,−35 | 54×59 @ −18,−33 |
| zitsip | 66×51 @ −18,−20 | 62×48 @ −18,−19 | 60×50 @ −16,−20 | 54×57 @ −18,−31 |
| lig | 66×40 @ −18,−9 | 62×38 @ −18,−9 | 60×43 @ −16,−13 | 54×43 @ −18,−17 |
| snuif | 70×60 @ −16,−29 | 60×58 @ −14,−29 | 62×51 @ −16,−21 | 60×46 @ −18,−20 |

In canvas pixels multiply by `g` and add the constant 4 px of padding
(2 px on each side); the offset becomes `voxel-offset·g − 2`.

---

## 6. Accessories (bought at the souvenir stall, worn by the guest)

Names: `['hoedje', 'sjaaltje', 'bal']`, stored on the guest record as
`g.accessoires`. The cache key is the *fixed* order `hoedje,sjaaltje,bal` joined with
commas; unknown names are dropped; an empty list gives `''`.

Anchors per species (`ankers(kind, p)` → `kop = [cx, top-y, rx, rz]`,
`hals = [x0, y0, x1, y1, r, rz, t-on-axis, extra thickness]`):

| species | kop | hals |
|---|---|---|
| hond | `[22+hx, 22+hy, 4.4, 5.6]` | `[16, 12, 20+hx, 15+hy, 2.8, 3.6, 0.45, 1.1]` |
| poes | `[22+hx, 20.5+hy, 3.8, 4.8]` | `[15, 12, 19+hx, 15+hy, 2.4, 3.0, 0.55, 1.0]` |
| konijn | `[21+hx, 21.4+hy, 4.2, 5.2]` | `[15, 13, 19+hx, 16+hy, 2.6, 3.2, 0.55, 1.0]` |
| gans | `[19+hx, ky+5.8, 2.8, 3.0]` (with the goose `hx/hy` rewrite) | `[14, 13, 19+hx, ky+1, 1.9, 2.2, 0.60, 0.9]` |

* **hoedje** — flat brim `ell(cx, y−0.2, 7.5, rx+0.7, 0.9, rz+0.7)` sunk one layer into
  the head, then a crown `ell(cx, y, 7.5, rx−0.8, 3.2, rz−0.8, {ymin:y})`; the layer at
  `y+1` is repainted white as a ribbon. Three layers high — a cap, not a box. Rabbit
  ears are higher than the crown and stick out above it.
* **sjaaltje** — three parts, in this order: (1) a generous *repaint* disc around neck,
  chin and upper chest (`ringVerf`, radius `r+1.8`, half-thickness 1.8) under a
  **ceiling** at `round(max(y0,y1))` so ears laid along the back are never painted
  orange; (2) an added collar (`ring`, radius `r+1.2`, half-thickness 2.2) kept under
  the per-column roof of the animal itself; (3) a **slip** hanging over the chest
  toward the viewer: for `y = 0..6`, find the frontmost existing column near `x0`, then
  place four 1×1×2 blocks one voxel outside the skin; the last row (`y = 6`) is white
  fringe.
* **bal** — a `r = 2.7` sphere (`e: 2.2`) attached to the *skin* of the already-posed
  model at `sx = round(hals.x0)`, at `cy = round(k[1] + (k[2]−k[1])·0.45)` and
  `z = skin_z + 1.4`; if it would hang below the animal's silhouette it is lifted by
  `ceil((py_max_ball − py_max_body + 1)/HG)` voxels. The layer at `cy` is repainted
  white as an equator.

Order: scarf and hat go on **before** `liggen()`/`zitten()` (they sink with the pose);
the ball goes on **after** (so it stays a round ball against the belly even when lying
down). All three belong to the guest's own silhouette, so a bed drawn later can never
slide over them.

---

## 7. The feeding bowl (`komVox`)

Round dish centred at `KOM_CX = 29.5`, `KOM_CZ = 7.5`.

| | card size (`groot` false) | world size (`groot` true) |
|---|---|---|
| radius `R` | 3.9 | 6.3 |
| wall height `HH` | 4 | 6 |
| floor thickness `BOD` | 2 | 3 |
| kibble per level (`trap`) | `[0, 3, 6, 10, 15]` | `[0, 10, 21, 34, 50]` |
| front-wall cut | `x + z ≥ 38` | `x + z ≥ 29.5 + 7.5 + R·0.72` |

Cell test: `|(x−cx)/R|^2.5 + |(z−cz)/R|^2.5 ≤ 1`; the inner region
(`q < 0.30` card / `0.36` world) is floor, the rest is wall with the top layer
repainted in `KOM.rim`. Kibble fills from the centre outward (cells sorted by `q`);
every third kibble uses the darker `KOM.brok2`. Voxels of the **front** wall get flag
`voor = 1` — they are drawn *after* the animal so it can bite into the bowl.

Fill level: `Art.niveau(aantal, per) = 0` when `aantal` is 0, else
`clamp(ceil((aantal/per)·4), 1, 4)` (`per ≤ 0` counts as a full portion).

Plate sizes **(measured, world size, voxel-px)**: back part 40×32 @ 24,16; front part
28×18 @ 30,30 — identical for all five levels (the kibble never grows past the rim).

---

## 8. Decor models (`rooms.js`) — measured extents

All models are anchored at `(0,0,0)` on the floor, `y` up. `l×h×d` in voxels;
`vox` = voxel count, `vlak` = culled faces. **(measured)**

| model | l×h×d | x range | y range | z range | vox | faces | note |
|---|---|---|---|---|---|---|---|
| `boom` | 29×41×25 | −15…13 | 0…40 | −12…12 | 7611 | 1150 | trunk + 5 leaf blobs (`#A9D08F #B2D797 #A6CE8E #B2D797 #A9D08F`) |
| `hok` | 24×26×22 | −12…11 | 0…25 | −11…10 | 11088 | 1345 | kennel, 9-step sloping roof |
| `hekx` | 14×14×5 | −2…11 | 0…13 | −2…2 | 274 | 166 | fence along x |
| `hekz` | 5×14×14 | −2…2 | 0…13 | −2…11 | 274 | 166 | fence along z |
| `tobbe` | 11×6×11 | −5…5 | 0…5 | −5…5 | 444 | 192 | tub, water inside (`q ≤ 15`) |
| `bal` | 7×7×7 | −3…3 | 0…6 | −3…3 | 175 | 77 | ball `#F5A8BE` with `#FFF0C6` band |
| `kist` | 11×9×11 | −5…5 | 0…8 | −5…5 | 769 | 257 | chest |
| `mat` | 17×1×17 | −8…8 | 0…0 | −8…8 | 289 | 289 | flat mat (one layer) |
| `poort` | 3×15×19 | −1…1 | 0…14 | −9…9 | 474 | 256 | garden gate |
| `balie` / `baliez` | 39×14×15 / 15×14×39 | | 0…13 | | 5790 | 1178 | reception counter, one arm |
| `bel` | 7×8×7 | −3…3 | 0…7 | −3…3 | 209 | 105 | desk bell, gold |
| `kassa` | 11×14×13 | −5…5 | 0…13 | −6…6 | 1247 | 339 | till |
| `boek` | 11×2×9 | −5…5 | 0…1 | −4…4 | 297 | 118 | furniture book |
| `prikbord` / `prikbordz` | 23×19×4 / 4×19×23 | | 4…22 | | 1686 | 478 | notice board, hangs on the wall |
| `sleutelbord` / `sleutelbordz` | 21×13×3 / 3×13×21 | | 6…18 | | 591 | 306 | key board, 5 hooks |
| `bed` / `bedz` | 34×13×17 / 17×13×34 | | 0…12 | | 5511 | 1067 | pillow at the high-`x` end, blanket at the foot |
| `mand` | 13×7×13 | −6…6 | 0…6 | −6…6 | 659 | 334 | basket with `#F5B0C2` cloth |
| `kast` / `kastz` | 27×29×12 / 12×29×27 | | 0…28 | | 7402 | 1280 | food cupboard — **the tallest piece of furniture, 29 voxels** |
| `zak` | 13×16×13 | −6…6 | 0…15 | −6…6 | 1662 | 359 | biscuit sack |
| `kar` | 30×22×19 | −16…13 | 0…21 | −9…9 | 4725 | 1365 | feeding cart: 3 compartments + sweet jar + 4 wheels |
| `lamp` / `lampaan` | 9×15×9 | −4…4 | 0…14 | −4…4 | 471 | 203 | `lampaan` repaints the shade `#FFE9A8` |
| `plant` | 14×22×13 | −6…7 | 0…21 | −6…6 | 2035 | 512 | pot + three leaf blobs |
| `pol0…pol4` | 5…9 × 5…6 × 5…8 | | 0…5 | | 56…106 | 40…70 | grass tufts, deterministic PRNG seed `4711 + n·977`; `n % 4 === 1` adds a pink or yellow flower |

`draai(maak)` mirrors a model over the diagonal by swapping `x` and `z` per voxel —
that is how `baliez`, `bedz`, `kastz`, `prikbordz` and `sleutelbordz` exist. There is
no `poortz` yet.

**The passages outdoors** (`art/decor_buiten.gd`, class `ArtDecorBuiten`, owner 2026-09-23:
"Het zwembad vanuit de tuin gezien is niet duidelijk dat lijkt gewoon op een huis"). Every
exit should say where it goes before its button does. Own names, merged through
`ArtDecor._extra()`; the base models above stay frozen (their golden images). The garden's
old `poort` is no longer placed anywhere; the model stays in the base set.

| model | where | shape |
|---|---|---|
| `zwembadpoort` | tuin, in the back fence @ 44,10 | two white posts with blue caps and bar, a blue sign with two white waves, a coral-and-white lifebuoy on the left post; opening 12, 19 wide, 23 tall |
| `rozenboog` | zwembad, in the side fence @ 4,66 | two wooden posts overgrown with leaves, a leafy arch, roses in pink, white and yellow on the pool side; opening 12, 26 tall |
| `gevelraam` / `gevelraamz` | tuin, on the hotel's back wall | a kitchen window seen from outside: white frame and cross, warm light `#FFEFC6`, half curtains, sill and a terracotta flower box with five flowers; 17 × 19 |
| `luifel` / `luifelz` | tuin, over the kitchen door | coral-and-white striped awning, 16 wide, 6 deep, scalloped edge |
| `deurmat` / `deurmatz` | before the kitchen's back door, both sides | coir mat 12 × 7 with a darker border and a paw print |
| `parasol` | tuin, on the pool deck behind the fence | coral-and-white canopy on a white pole, 17 across, 21 tall |
| `zwembadtrap` | tuin, at the water behind the gate | the two bent handrails of a pool ladder, 7 × 9 |
| `bloemstruik` | zwembad, the garden beyond the fence | a green mound with pink, yellow, white and lilac flowers, 9 × 7 (the reception's desk flowers are `bloemen`) |

The doors themselves are not models: `scenes/vloer.gd` draws every opening with a view of
the room behind it, and the kitchen's back door with its open leaf — see world.md §1.4.

The grass tufts of the garden are laid out by a seeded PRNG (`prng(90210)`, 30
attempts) that keeps 22 voxels' Manhattan distance from the five large props and
4 voxels' margin from the reserved zones (`hinkel`, `kraam`). **Reproduce the PRNG
exactly** (`a = a + 0x6D2B79F5 | 0; t = Math.imul(a ^ a>>>15, 1|a); t = t + Math.imul(t ^ t>>>7, 61|t) ^ t; return ((t ^ t>>>14) >>> 0) / 4294967296`)
or the garden will not look the same.

---

## 9. Models registered by minigames

Games add decor through `Rooms.registerModel(naam, fn)`; `fn(params)` returns the same
`[x, y, z, colour, voor?]` voxel list. Built-in names are protected; re-registering
your own name is allowed (last one wins). Caching key = `naam | g | paramSleutel`.

| name | game | shape and parameters |
|---|---|---|
| `klok` | wekker | hall clock on the wall (`x 48, z 1`), heart of the dial at `y = 34`. Screen radii `R_PLAAT 19`, `R_RAND 22`, `R_KAST 25`, `R_STREEP 16.5`, `R_UUR 10`, `R_MIN 15.5`. Because a screen-round dial is a skewed ellipse in voxels, every point goes through `naarVox(X,Y) = [round(X/2), round((X/2 − Y)/2)]`. Colours: case `#7E6255`, rim `#E8C58E`, face `#FFF7E4`, marks `#7E6255`, hour hand `#4A3B33`, minute hand `#C9788F`, centre `#E0A86B`, ghost hands `#9A8578` / `#D9A0B0`, bells `#E8C58E`. 12 marks (3/6/9/12 as strokes, the rest dots); ghost hands are drawn **first** and dotted (`stap = 1.5`) so the real hands overwrite them. Params: `{uur, min, spookU, spookM}`. |
| `steen` | hinkel | stepping stone 4 (or 5 when `groot`) × 2 × 5 with a lighter top; an optional number board **behind** the stone, `y0 = 2 + rij·8`. |
| `trap` | hinkel | three steps rising toward `+x`, with the target number on a board above the top step and a pink flag cap. |
| `was_krat` | was | crate on a bench. `KRAT_VOET = 18` (clamped 0…18): the bars start 18 voxels above the floor so the question card can never cover them. Crate body 13 wide × 11 deep; each block is `stap − 1` voxels of colour plus 1 voxel of dark seam (`stap` clamped 2…3, default 3); `n` clamped to `floor((50 − y0 − 2)/stap)` so a stack never breaks through the 52-voxel wall. |
| `was_berg` | was | pile of laundry: up to 8 blobs `ell(…4.2, 2.8, 4.2, {e:2.4, ymin:0})` on fixed PRNG positions; `m = clamp(ceil(n/2), 1, 8)`; `n = 0` returns an empty list (no plate). |
| `zb_streep` | zwembad | metre mark on the pool rim: stroke 2×1×4 + post 2×h×2 (`h = 7` when `groot` else 4) + white knob 4×1×4. Colours `#4C7FA6` (big) / `#8FB4CC` (small), knob `#FFFDF3`. |
| `zb_vlag` | zwembad | flag at `L` metres: foot 7×1×7 `#EDEFF6`, mast 2×21×2 `#B98F62`, triangular pennant of 7 rows `#F5A8BE`. |
| `kr_kraam` | kraam | market stall: back panel 21×24×2, two 27-tall posts, 6-row striped awning. |
| `kr_bank` | kraam | square counter 21×11×15 with a 23×2×17 top. |
| `kr_hoedje` / `kr_sjaaltje` / `kr_bal` / `kr_tas` | kraam | the displayed goods, deliberately 10–12 voxels tall (20–24 css-px at garden scale) so they do not vanish next to their price tag. |

---

## 10. Rooms, walls and the frame — what the art side needs to know

Room list (`HOTEL.md` §1, verbatim table in Appendix A). What matters for the look:

* Walls stand on the planes `x = 0` and `z = 0`; wall heights 50–58 voxels; the garden
  has no walls (fence + fixed frame `[-170, 190, -70, 220]`).
* The room box is `[-d·S − 10, w·S + 10, -wand·HG − 12, (w+d)·S/2 + 10]` in voxel-px.
* Box sizes (voxel-px): receptie 500×370, gang 332×290, kamer1/2 476×366,
  keuken 488×368, tuin 360×290, zwembad 484×354, wasserij 400×316.
* **Always visible:** the whole floor plus a `WAND_ZICHT = 56` voxel-px strip of wall
  (the notice board is 23 voxels = 46 voxel-px tall, the key board 19). Bare wall above
  that strip may be cut off on a low frame; **the floor never may be.**
* `KADER_ONDER = 132` css-px is reserved below the room for the keypad when there is
  height to spare; `KADER_RAND = 4` css-px of air left and right.
* The frame height is **the same for every room** (otherwise the page jumps at every
  door): as tall as fits, but never so tall that the smallest box fills less than 60 %.
* Rooms 1–2, receptie, keuken, zwembad get `loop: 1.5` and the wasserij `1.25` so a
  guest crosses a room in the same wall-clock time as before the rooms were enlarged.

---

## 11. Motion, particles and overlays

### 11.1 Card sprites (`art.js`, 12 fps)

Loop: `requestAnimationFrame`, throttled to `STAP = 1000/12 ≈ 83.3 ms`. It runs **only
while at least one `.animal` element is on screen** and stops itself when the last one
leaves; it also stops while the tab is hidden.

| mood | frames |
|---|---|
| `idle` | `pose = (f % 108) < 4 ? 'tril' : 'rust'`; `dy = (f % 26) < 13 ? 0 : −2` |
| `happy` | `k = f % 8`; `pose = k < 4 ? 'blijA' : 'blijB'`; `dy = [0,−4,−6,−4,0,−2,−4,−2][k]`; at `k === 1` two sparkles |
| `sad` | `pose = 'sip'`; `dy = (f % 46) < 23 ? 2 : 0` |
| `eat` | scripted sequence, see below |

Eating sequence (`feast`): `happen = max(2, eten)`; the sequence is
`[['rust',2]]` then per bite `['hap1',1], ['hap2',3], ['hap1',1]`, then `['blijA',0]`.
The second number is the frame count. On entering `hap2` the food level drops by one
and three crumbs spawn. `dy = 2` while in `hap2`, else 0. When the sequence ends the
mood becomes `happy`.

Mood names on the public API: `blij → idle`, `droopy → sad`, `bouncy → happy`
(`Art.setMood(id, mood)`). The DOM element carries `data-vox` = the internal mood.

### 11.2 Particles

`pluis(st, n, x, y, kleur, omhoog)` spawns `n` particles with a spawn jitter of
`x ± 7`, `y ± 3.5`, `vx = (rand − 0.5)·3.2`:

| kind | n | vy | gravity | life `t` | size `s` | colour |
|---|---|---|---|---|---|---|
| crumbs (`omhoog = false`) | 3 | `−(0.6 … 1.8)` | 0.5 | 7 | 1.5 | `KOM.brok #BC8149` |
| sparkles (`omhoog = true`) | 2 | `−(1.4 … 3.4)` | 0.08 | 9 | 2 | `#FFE9A8` or `#FFF7EC`, 50/50 |

Drawn as an axis-aligned square of `max(2, round(s·g))` px with
`globalAlpha = min(1, t/5)` on cards and `min(1, t/6)` in the world. Spawn points:
crumbs at the centre-top of the bowl, sparkles at 68 % of the animal's width and 6
voxel-px below its top. In the world the splash colours are
`['#E6F5FF', '#FFFFFF', '#CFE9FF']`.

**With `prefers-reduced-motion: reduce` there are no particles at all** and every guest
holds one still pose (`idle→rust`, `sad→sip`, `happy→blijA`, `eat→hap2`).

### 11.3 The sleep mark 💤 (drawn, not typed)

`world.js` draws three block "Z" glyphs above a sleeper's head, small to large:
`ZZZ = [[dx 0, dy 17.5, cell 0.85], [2, 20.5, 1.15], [4, 24, 1.5]]`, anchored
`Z_KOP = 8` voxels along the screen axis from the guest's position, colour `#7E6255`,
`globalAlpha = 0.8`. Each Z is four `fillRect`s (roof `4m×m`, two diagonal cells,
floor `4m×m`) with `m = max(1, round(cell·g))`. A mirrored guest (`face < 0`) gets
mirrored Z placement. **Still image — no endless animation**; they vanish the moment
the guest gets up.

### 11.4 Shadows

* Cards: two stacked ground rhombi from `SCHADUW = [x0 3, z0 1, x1 19, z1 14]`, the
  inner one inset by 2 voxels, each filled `rgba(74,59,51,.07)` — the overlap makes the
  middle darker.
* World: `grondschaduw` — an ellipse at the guest's floor point, `globalAlpha 0.15`,
  fill `#6E5A4A`, radii `r·g` by `r·0.5·g` with `r = 8`, or `7` when sitting or sad.
  Sleeping guests get **no** shadow.

### 11.5 Water over a swimmer

The pool water is baked into the floor plate and therefore lies *under* the guest. A
swimmer sinks `ZWEM_DIEP = 7` voxels (`POOT_HOOG`), so its belly sits exactly on the
water line. After the guest is drawn, a translucent water band is composited
`source-atop` on the guest only, cut by an **ellipse** (the surface seen from above, so
the line is higher at the back than at the front), covering roughly the bottom 40 % of
the sprite. The band does not bob with the animal — the water stays put, the animal
bobs in it.

### 11.6 World timing (`world.js`)

| constant | value | meaning |
|---|---|---|
| `STAP` | `1000/15` (66.7 ms) | one think tick; at most 3 catch-up ticks per frame, resync when more than 6 ticks behind |
| `TEKEN` | `1000/31` (32.3 ms) | draw cap ≈ 31 fps |
| `REIS_MS` | 300 | camera travel between rooms, ease-in-out `t<0.5 ? 2t² : 1 − (−2t+2)²/2`, alpha `0.35 + 0.65·e` |
| `SPRING_TIKKEN` | 6 | ticks in the air per jump (at tempo 1), `max(2, round(6/tempo))` |
| `SQUASH` | 3 | ticks flat on the stone after landing |
| `SPRING_HOOG` | hond 5, poes 6, konijn 7, gans 4 | top of the arc, in voxels |

### 11.7 Redraw-on-change (do not skip this in the port)

Two independent dirty checks:

* **Cards:** a sprite is redrawn only when its key `pose|dy|eten|(pluis.length ? f : 0)`
  changes.
* **World:** every frame `beeldStand()` builds a fingerprint string of *everything*
  `teken()` reads — room id, camera `x,y`, `g`, `dicht`, `W`, `H`, travel alpha, the
  pool rectangle; per guest `id|kind|staat|pose|face|x|z|px|pz|zij|bob|lift|hoogte|particles|order-pose|accessory-key`
  plus every particle; then the room decor, the slots (beds, bowls with their food
  level), travelling props and per-game loose decor. If the fingerprint is unchanged
  and nothing is sliding, the world redraws **at most once per 400 ms**. A guest
  sliding between two ticks (`px ≠ x || pz ≠ z`) marks every frame dirty.

The accessory key is only recomputed when `Art.tooiVersie()` moves (a counter bumped on
every accessory change) — the accessory list must always be *replaced*, never mutated
in place, or the counter lies.

---

## 12. Emoji, fonts and text sizes

### 12.1 Font

```
font-family: "Comic Sans MS","Comic Neue","Chalkboard SE","Segoe UI Rounded",
             ui-rounded,"Trebuchet MS",system-ui,sans-serif;
```

Base `font-size: 18px`, `line-height: 1.4`; on `max-width: 520px` it drops to `17px`.
The port must ship a rounded, friendly, **non-serif** face with a full Dutch glyph set
and bundle it (a web export cannot rely on Comic Sans being installed) — see Open
questions.

### 12.2 Text sizes (the ones that bind)

| element | size |
|---|---|
| child-facing floor (labels, badges, bubbles, sum sentences, name tags) | `clamp(12px, .75rem, 14px)` — **never below 12 px** |
| `h1` / `h2` | 1.32 rem / 1.2 rem |
| `.btn` | 1.05 rem bold; `.btn.big` 1.2 rem |
| `.logo` | 1.05 rem bold |
| `.ronde` | 0.82 rem bold |
| `.badge` | 0.9 rem |
| `.hot .ico` | 1.3 rem (`hotwolk` 1.4, `hotbron` 1.5, `hotkeuzes` 1.1) |
| `.hot.hotwolk .get` | 1.3 rem bold |
| `.hot.hotsom .somlijn` | 1.15 rem (1 rem ≤520 px, 0.95 rem ≤360 px) |
| `.hot.hotsom .somvak` | 1.25 rem (1.05 ≤360 px, 1 rem in the smallest frame) |
| `.padk` / `.padstrip .padk` | 1.15 rem bold (1.05 rem below 360 px) |
| `.answer` (sheet) | 1.9 rem; `.somregel` 1.5 rem; `.counton` 1.4 rem |
| `.coin` | 1.1 rem bold (1 rem ≤520 px) |
| `.foot` | 0.8 rem (hidden ≤520 px) |

If a game writes its own `style="font-size:…"` in hotspot HTML, **the 12 px floor does
not apply there** — then it is that game's file making the text too small.

### 12.3 Emoji inventory (DOM only)

Chrome / HUD (`index.html`, verbatim): `🛎️ Dierenhotel`, `📅 Dag`, `💰`, `⭐`, `💌`,
`🔊`, `☀️ Ochtendronde`, `📋 Prikbord`, `🌙 Avond`.

Rooms: `🛎️` receptie, `🚪` gang, `🛏️` kamer 1 and kamer 2, `🍪` keuken, `🌳` tuin,
`🏊` zwembad, `🧺` wasserij.

Most-used in games (count over all `.js` files): 🛏 (36), 🛁 (20), 🏊 (19), 🍪 (19),
✅ (18), 🎁 (17), 🛒 (16), ⭐ (14), ✓ (14), 🥄 (13), 🐾 (12), 🔑 (10), 📦 (10),
💤 (9), 💛 (9), 🐶 (9), 💰 (7), 🦆 (6), 🚰 (6), 🐰 (6), ✨ (6), ☝ (6), 🧶 (6),
📊 (5), 💌 (5), 🪨 (5), 🪙 (5), 😋 (4), 🔔 (4), 📖 (4), 👪 (4), 🐱 (4), 🌙 (4),
☀ (4), 🚫 (3), 😌 (3), 🎉 (3), 🍽 (3), ⚖ (3), 🫙 (3), 🩺 (3), 🕐🕒 clock faces,
🗺 (2), 🔇 (2), 🔄 (2), 📌 (2), 💦 (2), 💡 (2), 👛 (2), 👋 (2), 🐑 (2), 🎒 (2),
🧹 (2), 🧴 (2), 🫗 (2), 🧦 (2) **(measured by grep)**.

Keypad glyphs: `⌫` for delete, `✓` for OK.

**Binding rule (HOTEL.md §9): a pictogram always sits in the same bubble as its word or
number.** Never a lone pictogram, never scattered through the room.

---

## 13. Canvas sizing and the density cap

### 13.1 Card sprites

`.animal` is sized purely from CSS variables that `Art.init()` writes on
`documentElement`: `--vox-w = CW = 82`, `--vox-h = CH = 89` **(measured)**.

```
width  = var(--vox-w, 82) * var(--vox-scale) * 1px
height = var(--vox-h, 89) * var(--vox-scale) * 1px
```

`--vox-scale` is `1.15` by default → **94.3 × 102.35 css-px**; `.gate .animal` and
`.scene-warm .animal` use `1.75` → **143.5 × 155.75 css-px**, dropping back to `1.15`
on `max-width: 520px` and on landscape `max-height: 560px`.

The backing canvas is chosen by `meet()`:

```
ratio = (rect.width > 4 ? rect.width * devicePixelRatio : CW * 1.5 * devicePixelRatio) / CW
g     = clamp(ceil(ratio − 0.08), 1, 5)
canvas = CW*g  ×  CH*g
```

Worked example: a card animal 94.3 css-px wide on a dpr-2 screen →
`ratio = 94.3·2/82 = 2.30` → `g = ceil(2.22) = 3` → canvas 246 × 267 px. **The canvas is
never smaller than the device pixels it covers**, so there is no blurry
nearest-neighbour upscale.

Without a bowl in view (`sp.kom` false, i.e. the element is not inside a `.pet` card)
the animal is centred by `GEEN_KOM` / `GEEN_KOM_Y` — the extra room the bowl would have
taken, halved.

### 13.2 World canvas and the density cap on phones (M1b)

```
d = (devicePixelRatio > 2 && min(innerWidth, innerHeight) < 500) ? 2 : min(3, devicePixelRatio)
```

The cap is on the **lower bound** of `dicht`, not on `dicht` itself: `dicht = max(d, g/q)`
still climbs when a room does not fit. "Small screen" is a property of the *device*
(the **short** side), so a phone keeps the cap in landscape too — which is exactly where
the canvas is widest and most expensive.

Effect recorded in the source: an iPhone 13 portrait went from 1444×1392 (7.7 MB) to
963×928 (3.4 MB) and the floor plate from 6.3 MB to 2.8 MB, with `q` unchanged.

**Measured today** (real app, headless chromium, `World.schaal()` after load):

| viewport | dpr | frame (css) | canvas (px) | RGBA | g | dicht | q (=k) | `#app` |
|---|---|---|---|---|---|---|---|---|
| 320×640 | 2 | 296×314 | 1014×1075 | 4.16 MB | 2 | 3.42 | 0.584 | 320 |
| 360×740 | 3 | 336×405 | 1012×1220 | 4.71 MB | 2 | 3.01 | 0.664 | 360 |
| iPhone 13 390×844 | 3 | 366×441 | 1011×1218 | 4.70 MB | 2 | 2.76 | 0.724 | 390 |
| iPhone 13 844×390 | 3 | 676×320 | 1352×640 | 3.30 MB | 2 | 2.00 | 1.000 | 844 |
| iPad 768×1024 | 2 | 744×799 | 1508×1620 | 9.32 MB | 3 | 2.03 | 1.480 | 768 |
| iPad 1024×768 | 2 | 1000×550 | 2242×1233 | 10.55 MB | 4 | 2.24 | 1.784 | 1024 |
| iPad 820×1180 | 2 | 796×885 | 1592×1770 | 10.75 MB | 3 | 2.00 | 1.500 | 820 |
| iPad 1180×820 | 2 | 1156×602 | 2366×1232 | 11.12 MB | 4 | 2.05 | 1.954 | 1180 |
| Android tab 800×1280 | 2 | 776×885 | 1552×1770 | 10.48 MB | 3 | 2.00 | 1.500 | 800 |
| Android tab 1280×800 | 2 | 1156×582 | 2448×1232 | 11.50 MB | 4 | 2.12 | 1.889 | 1180 |

Note the density cap does **not** apply on tablets (short side ≥ 500), so a dpr-3
tablet would land at `d = 3` and roughly double these canvas sizes.

### 13.3 Stable screen height (M1b)

`innerHeight` jumps 60–90 px on a phone when the URL bar slides. The frame is computed
from the **small viewport** height instead: a hidden 0-width strip with `height: 100svh`,
falling back to `visualViewport.height`, falling back to `innerHeight`. That value is
**latched**: a new height is only taken when the width changed, the orientation flipped,
or the height moved by `HOOGTE_RUIS = 120` px or more. `KADER_MIN = 200` css-px is the
absolute floor for the frame. The frame may take
`min(available, round(screenHeight · (portrait ? 0.78 : 0.90)))`.

---

## 14. Asset extraction: can the artwork be carried over as textures?

### 14.1 The prototype (run today, evidence in `/tmp/dh-art/`)

* `/tmp/dh-art/probe.html` loads **only** `art.js` and `rooms.js` from the repo by
  `file://` — no server, no app boot, nothing written back to the game.
* `/tmp/dh-art/extract.js` (Playwright 1.60.0 at
  `/home/pc/work/ergomouse/node_modules/playwright`, chromium) calls the engine's own
  bake path — `Art.kit.dier(kind, pose, g, acc)`, `Art.kit.kom(n, g, voor)` and
  `Art.kit.plaat(Art.kit.bake(Rooms.model(n)), g)` — and writes each plate's
  `canvas.toDataURL('image/png')` to disk.
* **64 PNGs produced**: 15 dog poses at g=4, all four species in `rust` at g=4, the dog
  at g=2/3/5, four accessory combinations, 5 bowl levels × front/back, and 14 decor
  models at g=2 and g=4. `/tmp/dh-art/meta.json` records every plate's size, its
  `dx/dy` offset and its byte count.
* **Fidelity test:** the exported PNG was loaded back into the page, drawn to a fresh
  canvas and compared byte-for-byte with the live plate. Result for the dog (260×244 =
  63 440 px) and the tree (380×392 = 148 960 px): **0 differing bytes, max channel
  delta 0** — the round trip through PNG is exactly lossless, alpha included.
* **Visual proof sheet:** `/tmp/dh-art/proefblad.png` (16 sprites on the real page
  background). The look is preserved: soft AO, the contour ring, the softened corners,
  the mint collar, the pink ball, the hat ribbon.

Measured plate sizes and file sizes:

| plate | canvas | offset dx,dy | PNG |
|---|---|---|---|
| `gast_hond_rust_g2` | 132×124 | −34, −60 | 16.3 kB |
| `gast_hond_rust_g3` | 196×184 | −50, −89 | 24.2 kB |
| `gast_hond_rust_g4` | 260×244 | −66, −118 | 32.0 kB |
| `gast_hond_rust_g5` | 324×304 | −82, −147 | 38.4 kB |
| `gast_hond_lig_g4` | 268×164 | −74, −38 | 25.1 kB |
| `kom_n4_achter_g4` / `_voor_g4` | 164×132 / 116×76 | 94,62 / 118,118 | 10.5 / 3.3 kB |
| `decor_boom_g2` / `_g4` | 192×198 / 380×392 | −98,−180 / −194,−358 | 26.3 / 54.7 kB |
| `decor_bed_g4` | 412×312 | −210, −206 | 29.7 kB |
| `decor_kar_g4` | 396×364 | −210, −278 | 44.2 kB |

64 plates = **1.27 MB of PNG**.

### 14.2 What a full texture set would cost

| set | plates | note |
|---|---|---|
| guests, plain | 4 species × 15 poses = 60 | mirroring is free (flip at draw time) |
| guests, dressed | + 4 × 15 × 7 accessory combinations = 420 | the JS caches only 72 at a time; pre-rendering all of them is the price of not having a baker at runtime |
| bowl | 5 levels × 2 parts × 2 sizes = 20 | |
| decor, fixed | 33 | |
| decor, parameterised | unbounded | `klok` alone is 12 hours × 60 minutes × ghost-hand states; `was_krat` is `n` × 3 kinds × `voet`; `steen`/`trap` carry arbitrary numbers |
| × scales | × 3 (`g` = 2, 3, 4) | plates are **not** integer upscales of each other: the outline width is `round(g/2.6)` and `rondAf` only runs at `g ≥ 2`, so a g=2 plate is not a 2× downscale of a g=4 plate |

Rough total for the fixed part at three scales: `(60 + 20 + 33) × 3 ≈ 340` plates,
≈ 8–10 MB of PNG. With accessories: ≈ 1500 plates. **The parameterised game models
cannot be pre-rendered at all** — a clock with hands at 7:23 and a ghost hand at 8:00
is a distinct image.

### 14.3 Recommendation: **re-draw procedurally in GDScript, keep extraction as a test oracle**

Reasons, in order of weight:

1. **Parameterised models make a texture set incomplete.** `klok`, `steen`, `trap`,
   `was_krat`, `was_berg`, `zb_streep` all take parameters that change geometry. A port
   that ships textures still needs the voxel baker for these, so it would carry both
   systems.
2. **Plates are scale-specific.** Because outline width and corner softening depend on
   `g`, and `g` legitimately varies 2…4 across phones and tablets (§13.2), a texture
   port needs one set per `g` or accepts a visibly different edge treatment. Procedural
   drawing gets the right edge at every `g` for free.
3. **The drawing cost is already tiny and the engine already caches.** Faces per model
   are 467–1365 (§4, §8); the JS bakes each plate once and blits thereafter, and the
   whole world redraws at most 31 fps and idles at 400 ms (§11.7). A GDScript port doing
   the same — bake a plate into an `Image`/`ImageTexture` on first use, LRU it, blit
   afterwards — is the same amount of work as the JS and far less than a 10 MB texture
   download on a school tablet.
4. **Fidelity is not the differentiator.** The extraction is provably lossless
   (§14.1), so PNG is not "safer"; the risk with textures is *coverage*, not quality.
5. **Runtime memory is comparable.** 340 plates at g=4 average ~120 kB RGBA each is
   ~40 MB resident; a procedural baker holds only the ~110 plates the JS holds.

**But keep the extractor.** It gives the port a golden-image test: render the same
model/pose/`g` in Godot, compare against `/tmp/dh-art/*.png` pixel-for-pixel (or with a
small tolerance for the polygon rasteriser difference between canvas2d and Godot's
`draw_colored_polygon`). That is the cheapest way to prove the GDScript baker is right,
and it is why the prototype above is worth keeping in the repo's test tooling.

**If** the team overrules this and wants textures anyway: ship `g = 4` only, place the
world in a `SubViewport` sized `frame_css × dicht` with `dicht` chosen so `q = 4/dicht`
(exactly the JS rule), and use `texture_filter = nearest` **inside** the SubViewport and
`linear` when the SubViewport is scaled to the frame (the browser's CSS downscale of the
canvas is smooth, not nearest — matching it needs linear).

### 14.4 Godot rendering notes for the procedural path

* Draw the three faces as `draw_colored_polygon` with the same vertex lists as §1.2 and
  an additional `draw_polyline` of the same colour, width 1, to close the seams.
* Bake into an `Image` via a `SubViewport` + `get_texture().get_image()` once per
  `(model, pose, g, acc)`, then draw the `ImageTexture`. Do **not** re-emit polygons per
  frame: the JS does not, and the dirty rules in §11.7 assume a blit.
* `omlijn` maps to: render the silhouette to a second image, dilate by
  `max(1, round(g/2.6))` (a Manhattan-radius dilation — the JS uses
  `|dx| + |dy| ≤ w`), tint it `rgba(112,90,76,.26)` and draw it **behind**.
* `rondAf` maps to a single pass over the baked image: alpha ≥ 200 with two or more
  orthogonal neighbours below 40 → alpha 112.
* Sorting: sort faces by `x + y + z` ascending, exactly as `bake()` does. Do not use a
  z-buffer; the AO and the tint model assume painter order.

---

## 15. Sound (`snd.js`)

### 15.1 Architecture

Every sound is synthesised with WebAudio; **there are no audio files in the project**.
One master gain of **0.16** feeds the destination — "altijd zacht, nooit hard".
There are no angry sounds, only soft ones.

* **No AudioContext exists before the first real touch.** Until then `Snd` does
  nothing at all (a browser will not let an AudioContext play before a gesture, and it
  saves battery on a phone that only glances at the page).
* Unlock: `pointerdown` and `touchend` listeners on `window` (capture phase). The
  unlock also plays a **1-sample silent buffer** — the iOS trick, without which the
  band sometimes stays silent until the second tap.
* `metBand(fn)` only runs `fn` when the context is actually `running`; otherwise it
  awaits `resume()` and runs afterwards — never into the void.
* On `visibilitychange` to hidden the context is **suspended**.
* Mute is persisted in `localStorage` under the key **`kws-geluid`**: `'0'` = muted,
  `'1'` = on; a missing key means on. `Snd.schakel()` flips it, persists it, and when
  un-muting calls the unlock and plays `tik`. `Snd.dempt()` reports the state,
  `Snd.ontgrendeld()` whether the band has been woken.

### 15.2 The two generators

```
noot(f, to, duur, vorm, top, wacht)
  t = currentTime + (wacht || 0)
  osc.type = vorm || 'sine'
  osc.frequency.setValueAtTime(f, t)
  if (to && to !== f) osc.frequency.exponentialRampToValueAtTime(max(40, to), t + duur)
  gain.setValueAtTime(0.0001, t)
  gain.exponentialRampToValueAtTime(top || 0.4, t + min(0.035, duur * 0.3))
  gain.exponentialRampToValueAtTime(0.0001, t + duur)
  osc.start(t); osc.stop(t + duur + 0.03)

papier(duur, freq, top, wacht)                    // rustling paper / splash / rumble
  n   = max(16, floor(sampleRate * duur))
  buf[i] = (random()*2 − 1) * (1 − i/n)           // white noise with a linear fade-out
  BiquadFilter: type 'bandpass', frequency = freq, Q = 0.7
  Gain: constant `top`   →  master
```

Note the envelope shape: an exponential attack of `min(35 ms, 30 % of the duration)`
followed by an exponential decay to −80 dB at `duur`. In Godot the same curve is
`exp` interpolation on an `AudioStreamGenerator` or a pre-baked sample.

### 15.3 Every sound, exactly

`noot(f, to, duur, vorm, top, wacht)`; `papier(duur, freq, top, wacht)`. Measured peak
and audible length come from the WAV export (§15.4).

| name | Dutch comment in the source (verbatim) | synthesis | peak | audible |
|---|---|---|---|---|
| `tik` | *zacht tikje op een knop* | `noot(720, 620, 0.07, 'sine', 0.30)` | −26.5 dBFS | 44 ms |
| `plop` | *koekje valt in een bakje: een vollere hand klinkt iets hoger* | `noot(480 + 40·hand, 190, 0.13, 'sine', 0.5)` | −22.6 | 84 ms |
| `terug` | *een koekje rolt terug de zak in* | `noot(300, 460, 0.09, 'sine', 0.28)` | −27.3 | 56 ms |
| `zacht` | *dat is het nog niet - zacht meedenken, nooit een nee-geluid* | `noot(430, 0, 0.15, 'sine', 0.30)` + `noot(340, 0, 0.22, 'sine', 0.26, 0.13)` | −26.7 | 253 ms |
| `ja` | *dat klopt! twee vrolijke toontjes* | `noot(660, 0, 0.10, 'triangle', 0.42)` + `noot(880, 0, 0.16, 'triangle', 0.42, 0.09)` | −23.8 | 187 ms |
| `tover` | *eerlijk verdeeld of een vriend die jou uitkiest: kleine magie* | `noot(n, 0, i===3 ? 0.5 : 0.11, 'triangle', 0.34, i·0.08)` for `n = [523, 659, 784, 1047]` | −25.4 | 502 ms |
| `dag` | *goedemorgen, een nieuwe dag in de steeg* | `noot(587, 0, 0.12, 'sine', 0.26)` + `noot(784, 0, 0.22, 'sine', 0.24, 0.11)` | −27.9 | 231 ms |
| `brief` | *een brief door de brievenbus* | `papier(0.16, 1100, 0.5)` + `papier(0.10, 700, 0.4, 0.10)` + `noot(660, 0, 0.12, 'sine', 0.22, 0.16)` | −28.1 | 234 ms |
| `hoera` | *hoera! adoptiedag en het grote einde* | `noot(n, 0, 0.14, 'triangle', 0.40, i·0.13)` for `[523, 659, 784, 1047]`, then `noot(1047, 0, 0.55, 'triangle', 0.34, 0.52)` + `noot(1319, 0, 0.55, 'sine', 0.22, 0.52)` | −21.5 | 844 ms |
| `bel` | *de bel op de balie: helder, kort, nooit hard* | `noot(1046, 0, 0.34, 'sine', 0.42)` + `noot(1568, 0, 0.28, 'sine', 0.20, 0.04)` | −23.5 | 210 ms |
| `deur` | *een deur die opengaat en weer dichtvalt* | `noot(250, 190, 0.11, 'sine', 0.26)` + `papier(0.09, 520, 0.22, 0.06)` | −28.9 | 140 ms |
| `kar` | *de voerkar rolt over de gang* | `papier(0.24, 300, 0.26)` + `noot(170, 210, 0.22, 'sine', 0.16)` | −29.6 | 216 ms |
| `munt` | *een munt op de toonbank* | `noot(1180, 0, 0.07, 'triangle', 0.34)` + `noot(1560, 0, 0.10, 'sine', 0.20, 0.05)` | −25.6 | 112 ms |
| `ster` | *een sterretje erbij* | `noot(784, 0, 0.09, 'triangle', 0.30)` + `noot(988, 0, 0.09, 'triangle', 0.28, 0.07)` + `noot(1319, 0, 0.20, 'sine', 0.24, 0.14)` | −26.6 | 252 ms |
| `plons` | *een dier glijdt het zwembad in: een plons met wat spetters* | `noot(560, 150, 0.14, 'sine', 0.40)` + `papier(0.20, 1500, 0.28, 0.03)` + `papier(0.13, 800, 0.16, 0.10)` | −22.5 | 222 ms |
| `au` | *zachte bots tegen de wand: een klein "au", nooit een schrikgeluid. Hier wordt niemand gestraft, dus blijft het laag, kort en rond.* | `noot(240, 180, 0.09, 'sine', 0.26)` + `noot(430, 350, 0.16, 'sine', 0.20, 0.06)` | −27.8 | 152 ms |
| `klok` | *de halklok slaat een keer: een zachte gong die nog even naklinkt* | `noot(659, 0, 0.55, 'sine', 0.36)` + `noot(988, 0, 0.40, 'sine', 0.16, 0.02)` | −23.9 | 299 ms |
| `hup` | *hup, een sprongetje naar de volgende steen* | `noot(430, 720, 0.08, 'sine', 0.30)` | −26.6 | 51 ms |

"Audible" is the last sample above amplitude 0.001 **(measured)**; the note's nominal
`duur` runs longer because the decay is exponential (e.g. `klok` is nominally 550 ms but
inaudible after ~300 ms).

Usage frequency across the codebase **(measured by grep)**: `zacht` 45, `tik` 17,
`ja` 16, `plop` 12, `terug` 8, `tover` 8, `brief` 7, `munt` 5, `hoera` 4, `deur` 2,
`ster` 2, `plons` 3, `klok` 2, `hup` 3, `au` 2, `kar` 1, `dag` 1, `bel` 1.
`zacht` is the "not yet" sound and is by far the most used — **it is never a "no"
sound**, and that is a design rule, not an accident.

### 15.4 The export prototype (`/tmp/dh-snd/`)

`/tmp/dh-snd/probe.html` replaces `window.AudioContext` with a factory that returns an
`OfflineAudioContext(1, 48000·1.5, 48000)` whose `state` getter is forced to
`'running'`; `snd.js` is then loaded **unmodified**. `/tmp/dh-snd/export.js` dispatches
a synthetic `pointerdown` on `window` (which is exactly what unlocks the real band),
calls one sound, renders offline, measures peak and audible length, and writes a 16-bit
mono WAV at 48 kHz.

**All 18 sounds exported** — `/tmp/dh-snd/*.wav`, 144 044 bytes each (1.5 s of
headroom), plus `/tmp/dh-snd/meta.json`. Peaks and lengths are the table above.

Two findings that matter for the port:

1. **Determinism.** Two runs of the exporter produce **bit-identical** files for every
   oscillator-only sound (`klok` verified) but **different** files for every sound that
   uses `papier()` (`brief`, `deur`, `kar`, `plons` — `plons` verified different). The
   noise is `Math.random()` per call, so exporting a WAV *freezes one particular
   splash*. In the browser every splash is a new one.
2. **Level.** Every export peaks between −29.6 and −21.5 dBFS because of the 0.16 master
   gain. Do not normalise the WAVs: the quietness is deliberate. If the port uses
   samples, keep the relative levels and put the 0.16 on the bus.

**Recommendation: synthesise in Godot, do not ship samples.**
`AudioStreamGenerator` (or, simpler, a tiny `AudioStreamPlayer` per sound fed by a
pre-generated `AudioStreamWAV` built **at runtime** from the same formulas) reproduces
these 18 sounds in under 100 lines and keeps the noise fresh per call, the parameterised
`plop(hand)` pitch, and the exact envelope. Total sample data if you do ship WAVs:
18 × ~30 kB when trimmed to their audible length — small, so this is a matter of
fidelity, not size. The one thing samples cannot do is `plop(hand)`, whose base
frequency is `480 + 40·hand`.

Godot notes: an exponential ramp to 0.0001 is `ease-out`; Godot's
`AudioStreamPlayer.volume_db` tweening is in dB, so `0.0001 → −80 dB` and
`top = 0.30 → −10.5 dB`. Autoplay policy on the web export needs the same unlock: no
audio before the first real input event.


---

## 16. Style and layout (`style.css`, `index.html`, `ui.js`)

### 16.1 Page shell

```
#app  max-width 960px; margin 0 auto; padding 6px 12px 10px
      @supports (padding:max(0px)) → padding-top    max(6px,  env(safe-area-inset-top))
                                      padding-right  max(12px, env(safe-area-inset-right))
                                      padding-bottom max(10px, env(safe-area-inset-bottom))
                                      padding-left   max(12px, env(safe-area-inset-left))
body  min-height 100vh, and 100dvh where supported (@supports (min-height:100dvh))
html  overscroll-behavior: none;  touch-action: manipulation
html.sheet-open  overflow: hidden        (page under an open sheet does not scroll)
*     -webkit-tap-highlight-color: transparent
[hidden] display: none !important        (a plain `hidden` must really hide)
```

`touch-action: manipulation` keeps panning and pinching but kills the 300 ms
double-tap-zoom delay; only drag sources and drop targets (`.hot`, `.coin`, `.block`,
`.placed`, `.gastkaart`, `.bag`) set `touch-action: none`.

Nothing is accidentally selectable or long-pressable:
`.hot, .ghost, .kchip, .btn, .wtag, .padstrip .padk { user-select:none;
-webkit-user-select:none; -webkit-touch-callout:none }` — a child easily holds a button
for a second and must not get the blue selection or the iOS "Kopiëren / Delen" menu.

Viewport meta (verbatim): `width=device-width, initial-scale=1, viewport-fit=cover`;
`<meta name="color-scheme" content="light">`; `<html lang="nl">`. **There is no dark
mode.**

### 16.2 The document skeleton (`index.html`) with its verbatim strings

```
#app
 └ .chroom
    ├ header.topbar
    │   ├ .logo               "🛎️ Dierenhotel"
    │   └ .badges             #dayBadge  title="Dag"      "📅 Dag <b id=dayNum>1</b>"
    │                         #muntBadge title="De kassa" "💰 <b id=muntNum>0</b>"   (button)
    │                         #sterBadge title="Sterren"  "⭐ <b id=sterNum>0</b>"
    │                         #lettersBtn                 "💌 <b id=letterNum>0</b>"  (button)
    │                         #sndBtn    title="Geluid" aria-label="Geluid aan of uit" "🔊"
    └ .rondebalk              #rondeNaam "☀️ Ochtendronde"
                              #prikBtn   "📋 Prikbord"     #avondBtn "🌙 Avond"
 ├ .stagewrap
 │   ├ .stagecol
 │   │   ├ #world .world  role="img"
 │   │   │      aria-label="De ruimte van het dierenhotel waar je nu staat"
 │   │   │      ├ canvas#worldCv
 │   │   │      ├ .tags#worldTags        (name plates, pointer-events none)
 │   │   │      └ .hits#worldHits        (hotspot layer, z-index 3)
 │   │   ├ #padstrip .padstrip role="group" aria-label="Cijfers" hidden
 │   │   └ nav#kamerbalk aria-label="Naar een andere ruimte"
 │   └ main#scene .scene                 (the optional calculation panel)
 └ footer.foot  "Dierenhotel Kwispelsteeg · demo · rustig aan, je mag alles zo vaak proberen als je wil"
#overlay .overlay.hidden aria-hidden="true"  →  .sheet#sheet role="dialog" aria-modal="true"
#toast .toast.hidden role="status" aria-live="polite"
```

Script order in `index.html` matters: `art.js, rooms.js, hits.js, world.js, snd.js,
ui.js, state.js, econ.js, games/registry.js, hotel.js`, then the ten game files, then
`game.js`. `art.js` waits one tick (`setTimeout 0`) before hooking `World.onKader`,
because `world.js` registers later.

### 16.3 The world frame: portrait and landscape

CSS gives the frame an aspect ratio; **`world.js` then overrides it with an inline
`height`/`max-height`** whenever `body` is *not* `.metpaneel` (§10, `pasKader`). So in
practice the CSS ratios are the pre-JS fallback and the `.metpaneel` case only.

| condition | `aspect-ratio` | `max-height` |
|---|---|---|
| default (portrait, no panel) | `4/5` | `60vh` |
| `body.metpaneel` | `4/3` | `44vh` |
| `@media (orientation: landscape)` | `3/2` | `74vh` |
| `@media (orientation: landscape) and (min-width: 900px)`, no panel | `16/9` | — (`.stagecol` becomes 100 %, `.scene` is hidden) |
| `@media (orientation: landscape) and (min-width: 900px)`, with panel | `3/2` | `70vh`; `.stagecol` `flex 0 0 48%`, `position: sticky; top: 8px`; `#app` `max-width: 1180px` |

Two earlier rules — `@media (max-width:520px){.world{max-height:44vh}}` and
`@media (orientation:landscape) and (max-height:560px){.world{max-height:62vh}}` — are
**overridden by the later block** at the same specificity and are therefore dead in the
shipped file. Do not port them. (Verified: at iPad 1024×768 the frame measures
1000×550 css-px, not the 562.5 that `16/9` would give — the height comes from JS.)

An empty `<main class="scene">` costs nothing: `body:not(.metpaneel) .scene { display:none }`.

### 16.4 The chrome, and the compact landscape shell

Normal:

| element | size |
|---|---|
| `.topbar` | flex row, `gap 6px`, wraps, `margin-bottom 4px` |
| `.badge` | radius 999px, `padding 4px 9px`, `min-height 38px`, 2 px white border |
| `.badge.tap` | **`min-height 48px; min-width 48px`** (it is a button) |
| `.rondebalk` | centred flex row, `margin 2px 0 4px`, no wrap |
| `.ronde` | `--sun` pill, `padding 5px 12px`, 0.82 rem bold |
| `.btn.mini2` | `padding 6px 10px`, **`min-height 48px`** |
| `.foot` | 0.8 rem, `--ink2`, hidden below 520 px |

`@media (orientation:landscape) and (max-height:450px)` — the compact shell:

* `#app` padding `4px 8px` (with `env(safe-area-inset-*)` maxima).
* `.chroom` becomes one flex row: `.topbar { flex: 1 1 320px }` and `.rondebalk`
  right-aligned; if it gets too narrow it may wrap to two rows — **rather that than a
  button under 48 px**.
* `.logo { display: none }` — the title is decoration, not a button.
* `.stagecol` becomes a grid:
  `grid-template-columns: minmax(0,1fr) auto; grid-template-areas: "wereld rail" "strook strook"`.
* `.kamerbalk` becomes a **rail** of `repeat(3, 48px)` next to the frame (98 px wide);
  with three labelled columns it was 231 px and those 231 px come straight off the
  frame width. The word stays (a pictogram without a word does not exist here, and
  🛏️ Kamer 1 / 🛏️ Kamer 2 share a picture) but it may wrap:
  `white-space: normal; overflow-wrap: anywhere; max-height: 2.1em`.
* `.kb` (the waiting-guest badge) shrinks to 18 px, but its digit stays 12 px.
* `.pcel` (map cells) `min-height 48px`; `.sheet` padding `10px 12px`; the sheet's
  button row becomes `position: sticky; bottom: -10px` so "Sluiten" is always in view.
* `@media (orientation:landscape) and (max-height:320px)`: `.sheet .hint { display:none }`
  — below 320 px of screen height the explanation line goes rather than a tap target
  shrinking below 48 px.

### 16.5 Buttons, tap targets and the 12 px floor

* `--tap: 52px` is the default `min-height`/`min-width` of `.btn`.
* **Every tap target is at least 48 px**; 44 px is allowed **only below 360 px screen
  width** (`@media (max-width:359px)`: `.kchip { min-width:44px }`,
  `.padk { min-width:44px; min-height:44px }`). At exactly 360 px everything stays 48
  (`@media (min-width:360px) and (max-width:520px){ .padk { min-width:48px; min-height:48px } }`).
* `.hot { min-width:48px; min-height:48px }`, also on `max-width:520px`.
* `.padk`, `.kzk`, `.mini`, `.badge.tap`, `.kchip`, `.pcel`, `.taak` all carry an
  explicit 48 px (or 52/56) minimum.
* `.btn:active { transform: translateY(3px) }`, `.padk:active { translateY(2px) }` — a
  pressed button sinks. **`.hot:active` must not use `transform`**: `hits.js` writes the
  position into that property.
* Coins: `.coin` 60×60, `.coin.c5` 68×68, `.coin.note` 92×60; on `max-width:520px`
  52×52 / 58×58 / 80×52; on landscape `max-height:560px` 50×50.
* Text floor: `clamp(12px, .75rem, 14px)` on `.hot .lbl`, `.hot.hotwens .lbl`,
  `.hot.hotkeuzes .lbl`, `.hot .bdg`, `.kb`, `.hot.hotbron .hand`, `.kchip .kn`,
  `.pcel .pn`, `.wtag`, `.hot.hotwolk .zeg`, `.hot.hotsom .somzin`,
  `.hot.hotsom .somhulp`. Measured before this rule: 8.8 px labels, 10.9 px room chips,
  11.2 px bubbles — unreadable in a child's hand.

### 16.6 The sum card and the speech bubble

* `.hot.hotwolk` — one row: pictogram, number, sentence; `max-width 290px`
  (274 px ≤520 px), sentence `max-width 228px` (216 px ≤520 px), radius
  `20px 20px 20px 6px`, background `#FFFDF6`; `.goed` → `#E4F7EC`, `.hulp` → `#FFF8E7`.
* `.hot.hotsom` — a single line of squared paper: background `#FCFAF0`, border
  `#EAE0C8`, `repeating-linear-gradient(180deg, transparent 0 21px, #C2D8EA 21px 22px)`,
  radius `6px 14px 14px 6px`. With a sentence it becomes a column
  (`.metzin`, `padding-bottom 14px` — the keypad hangs right under the card and its top
  edge touches the last 6 px). The answer box `.somvak` is `min 40×34` with
  `inset 0 -4px 0 #EAF1F8`; correct → `#D8F3E4` with `--mint-d` border; a finished card
  → `#EAFBF3`.
* On `max-width:360px` the whole card shrinks to ~170 px: sentence `max-width 150px`,
  `.somvak` `32×32`, `.somlijn` 0.95 rem, paddings and gaps cut; the letters stay 12 px
  and the keys stay 44 px. **The sentence wraps to a second line and is never
  ellipsised** (`white-space: normal; overflow-wrap: break-word; text-overflow: clip`).
* One card has its own escape hatch: `.hot.hotsom[data-hot="bd_som"]` is capped at
  104 px below 360 px so "Bedden op rij" can stand *beside* its row on a 320×640 phone.

### 16.7 The keypad (the only permitted 2-D element)

Keys, in order: `['1','2','3','4','5','del','6','7','8','9','0','ok']`, rendered as
`⌫` and `✓`. Inside the frame: two rows of six normally, **one row of twelve when the
frame is ≥ 660 css-px wide** (then the pad is half as tall and does not cover the
floor). The strip below the frame always emits all twelve keys in one row and lets
`flex-wrap` break them.

`Ui.somkaart(...).padPlek`:

| value | behaviour |
|---|---|
| `'auto'` (default) | inside the frame, **except** when the frame is lower than 300 px or too narrow for one row of six keys — then it becomes a strip below the frame |
| `'binnen'` | always inside |
| `'buiten'` | always the strip |

Anti-flapping (measured 44 switches in 5 s before the fix): the frame height is measured
**without** the strip's own height (`kaderHoogVrij`), there is a **dead zone between
`KADER_KORT = 300` and `KADER_RUIM = 340`** (out below 300, back in only above 340),
the switch's own frame event is ignored for `VERSTIL_MS = 400` ms, and there are at
most `WISSEL_MAX = 2` switches per screen size. Minimum frame width for an inside pad:
286 px below 360 px screen width, 310 px at exactly 360 px, 326 px above **(measured
in `ui.js`)**.

**There is exactly one strip.** If two cards put their pad outside, the last one takes
it over. The keys are always findable at
`[data-hot="<card-id>_pad"] [data-pk="7"]`, wherever the pad stands. The strip is
`display:flex; flex-wrap:wrap; gap:4px`, background `#FFFDF8`, 3 px white border,
radius 18 px, keys `min 48×48` (44×44 below 360 px).

### 16.8 Toast, overlay and sheet

* `.toast` — fixed, `left:50%`, `bottom:18px` (or
  `max(18px, env(safe-area-inset-bottom) + 10px)`), `--ink` background, white text,
  radius 999px, `max-width 92vw`, **`pointer-events: none`** (a toast is a message,
  never a button). Variants `.happy` (`--mint-d`) and `.kind` (`--peach-d`).
  On `max-height: 450px` it moves to the **top**: `top: 58px` (or
  `max(58px, env(safe-area-inset-top) + 56px)`), 0.95 rem, `padding 8px 16px`.
* `.overlay` — `inset:0`, `#4a3b3355`, `z-index 50`, `overscroll-behavior: contain`.
* `.sheet` — `--card`, radius 26px, `max-width 560px`, `max-height 92vh`
  (`92dvh` where supported), `animation: pop .25s ease-out`.

### 16.9 Breakpoints, in the order they appear

| query | what it changes |
|---|---|
| `max-width: 520px` | base font 17 px; cards/pet/bowl narrower; `--vox-scale` back to 1.15; ruled paper `padding-left 46px`, `--lijn 28px`; `.hot` padding and label 0.55 rem; coins smaller; `.foot` hidden; sum-card gaps trimmed |
| `max-width: 700px` | `.kchip` 48×48, `padding 3px 5px`, icon 1.15 rem |
| `max-width: 360px` | sum card ≈170 px, `.somzin` 150 px / 0.64 rem, `.somvak` 32–34 px, keypad `padding 3px`, keys 44 px, `.kzk` tighter |
| `max-width: 359px` | `.kchip { min-width: 44px }`, `.padstrip .padk { 44×44 }` |
| `min-width: 360px and max-width: 520px` | `.padk` back to 48×48, 1.15 rem |
| `orientation: landscape and min-width: 900px` | side-by-side layout, `#app` 1180 px, sticky column, frame `3/2`/`16/9` |
| `orientation: landscape and max-height: 560px` | `--vox-scale` 1.15, `.pet` 150 px, `.cell` 72 px, `.kchip` 48×58, coins 50 px |
| `orientation: landscape and max-height: 450px` | the compact shell (§16.4) |
| `orientation: landscape and max-height: 320px` | `.sheet .hint` hidden |
| `max-height: 450px` | toast moves to the top |
| `prefers-reduced-motion: reduce` | `.bouncy, .wiggle, .pop { animation: none }` — and in JS: `art.js` draws one still pose per mood, `world.js` freezes every guest (`stilzetten('rust')`) and spawns no particles |

Animations defined: `wiggle` (`.4s ease-in-out 2`, ±6°), `pop`
(`scale(.4)→scale(1)`, opacity 0→1, `.3s ease-out`), `fadeup`
(`translateY(-30px) scale(.4)`, opacity 0).

### 16.10 The name plate above a guest

`.wtag` — absolutely positioned, `background #FFFDF6E8`, colour `#5A4A3E`, 2 px white
border, radius 999px, `padding 1px 9px`, bold, `letter-spacing .2px`,
`box-shadow 0 2px 0 rgba(74,59,51,.14)`, font-size from the 12 px clamp.
`world.js` places it at `translate(-50%,-100%)` on
`(screenX, screenY − (30·HG + 8)·g + (bob + lift)·g) / dicht` — i.e. **68 voxel-px above
the guest's floor point**. Collision avoidance: up to 6 attempts, another plate counts
as a hit within 62 css-px horizontally and 24 vertically, and the plate then moves
26 px up.

---

## 17. The binding rules, as a checklist

### 17.1 HOTEL.md §9 — "rekenen ín de wereld, zonder leeswerk" (full text in Appendix A)

- [ ] **No calculation panel beside the world.** Sums, counts and choices appear as
      small cards or speech bubbles hanging on an object or animal, anchored exactly
      like the name plates. The world stays visible and is the only playing field.
- [ ] **Numbers on objects.** Bowls show their count on the bowl, hooks their number,
      the counter its amount, beds their row. The squared-paper look may come back as
      one small "sommenkaart" on the object, never as a slab of text.
- [ ] **Text budget: one ordinary Dutch sentence per sum card, ≤ 8 words and
      ≤ 40 characters**, directly above the sum, containing a verb or a question word,
      with the pictogram first on that same line. One line is guaranteed up to about
      34 characters (measured at 420 and 860 px wide); 35–40 wraps to a second line;
      more than two lines per sentence does not exist.
- [ ] On a narrow phone (frame < 360 px) the card shrinks to 170 px and **every**
      sentence wraps: "het dier blijft zichtbaar" beats "de zin op één regel", and the
      keypad may use 44 px keys there.
- [ ] A second short sentence is allowed if another number belongs to it (a stock, for
      instance). **Three sentences: never.**
- [ ] The sentence names the numbers in hotel words: `"🍽 We eten 4 dagen lang 2 scheppen"`
      above `4 × 2`. A bare expression (`"4 × 2 ? 20"`, `"12 : 3"`, `"🪑 + 🛋 ="`) never
      stands there without that sentence, and **`?` is never used as a comparison sign
      between two expressions**.
- [ ] Answer choices are buttons with **pictogram AND word** — `"⬇ te weinig"`,
      `"⚖ precies"`, `"⬆ blijft over"` — in one strip on the card. Never a pictogram
      alone, never scattered through the room.
- [ ] A pictogram always sits in the same bubble as its word or number, wish
      pictograms above the guests included (`"🍪 eten"`, `"🛏 bed"`).
- [ ] Explanation happens by **showing** (a worked example in the world), not by
      reading. Feedback is pictogram + number (`"nog 2 🍪"`, `"3 + 3 ✓"`).
- [ ] Task cards on the notice board keep their own short line: **≤ 6 words**.
- [ ] **Dragging happens in the world**: biscuits from a sack hotspot to bowls, coins
      from the purse to the counter, keys to hooks on the wall, beds from the chest to
      the floor. The keypad is the only permitted 2-D element and appears small,
      anchored to the object.
- [ ] Optional read-aloud of short prompts on a tap on the bubble; never compulsory,
      never automatically repeating.
- [ ] Games use only the provided primitives for showing arithmetic:
      `ui.wolk(obj, {icoon, getal, tekst?})`, `ui.somkaart(obj, som, {regel, icoon, keuzes})`,
      `wereld.getalTag(obj, n)`, `hotspots.bron(obj, {icoon, aantal})`. The old
      `ui.paneel` remains only for the start sheet and the furniture-book overview.

### 17.2 GAMES-API §9 — "Op de telefoon"

- [ ] **The button stands above its object, not on it.** `o.op` on
      `ctx.hotspots.maak`: `'boven'` (just above — the object stays whole),
      `'onder'` (just below its floor point), `'midden'` (on the aim point, the old
      behaviour), `'rand'` (number tags: just over the top edge, at most a tenth of the
      object hidden), `'auto'` (**the default**).
- [ ] `'auto'` picks `'rand'` for a number tag; `'midden'` for a fixed card (sum card,
      keypad, choice strip), for a place without an object (`y ≤ 0`), for a button with
      its own `html`, and for a bubble or card; **otherwise `'boven'`**. Those last two
      rules are the brake: *a game that computes its own button position in screen
      pixels keeps its own layout.*
- [ ] If `'boven'` no longer fits inside the frame it silently becomes `'onder'`. When
      buttons cover each other they evade — first up and sideways, then all directions,
      and in a really tight frame they **stack** row by row from the top edge. **A
      button covering another button is worse than a button covering a corner of its
      object.** `Hits.debug().spots[].op` reports what it became.
- [ ] **Dragging still goes to the object.** Every hotspot with `drop` that stands above
      or below its object gets a transparent **catch area** over button + object with
      the same `data-drop`/`data-h-*`, in its own layer *under* the buttons. Nothing to
      do for the game: just give the hotspot its `drop`.
- [ ] Use `onWeg(spot)` on `ctx.hotspots.maak` to clean up when a hotspot disappears; it
      fires once, before the element leaves the page, also on `wisAlles()`.
- [ ] Keypad placement via `padPlek` (§16.7). One strip only; give the other card
      `padPlek: 'binnen'`.
- [ ] **Never hook `window.addEventListener('resize', …)`.** Use `ctx.ui.opKader(fn)`,
      which returns an unsubscribe function, and call it in `stop()`. Under water that
      is `World.onKader(fn)` → one `ResizeObserver` on the frame, one 120 ms debounce,
      one signal, and it only fires when something really changed. It does **not** fire
      on subscribe. `World.kader()` gives `{x,y,w,h}` from the cache without a layout
      read; `World.hermeet()` forces a measurement.
- [ ] Know the difference: **`World.vuil()` asks for a redraw at the current size;
      `World.hermeet()` re-measures the frame.** A shell change (a bar appearing, a panel
      opening) needs `hermeet()`.
- [ ] Measure your own card or button only **after one draw pass** (`offsetWidth`), keep
      at least `(h1 + h2) / 2` px between two buttons, and compute around everything
      that is `vast` (a sum card and its keypad choose first and never move).
      `games/sleutels.js` is the worked example for three frame heights.
- [ ] **Text never below 12 px.** The floor is in the stylesheet; a `style="font-size:…"`
      in your own hotspot HTML escapes it — then it is your file making it too small.
- [ ] **Tap targets at least 48 px** (44 px below 360 px screen width), with finger and
      with mouse.
- [ ] Finger dragging lifts the drag image **40 px above the fingertip** and measures the
      target at that point; one tap delivers exactly once (the browser's after-click is
      swallowed) and the hold menu is off on a drag source. Mouse and pen unchanged.
      This is inside `ctx.sleep` — nothing to do.
- [ ] **Landscape under 450 px high**: the shell goes compact, the room bar becomes a
      3 × 3 block beside the frame, and there is **less height than you think — check
      that your layout also fits in ~190 px.**
- [ ] The three suites are the inspection: `node mobiel.js` (eight phone profiles:
      shell, taps, drags, sound), `node mobiel-perf.js` (frame size, density, drawing,
      listeners), `node hits-plaats.js` (no button covers its object or another button).
      They live in `.fanout/scratch/dierenhotel/` and hang in `alles.sh`. **A game is
      only finished when it passes those, not when it works on a laptop.**

### 17.3 Band-dependent behaviour (HOTEL.md §3)

Art, sound and layout are band-independent with three exceptions, so the whole rule is
repeated here. Every minigame derives its numbers from `N` (number of guests) with
`T = k·N + r`, `0 ≤ r < k`:

| band | N | k | ceiling | extra |
|---|---|---|---|---|
| groep 3 | 2–3 | 1–2 | ≤ 20 (preferably ≤ 10) | `r = 0 or 1`; whole hours on the clock; **icoon-only** |
| groep 4 | 4–6 | 2, 3, 4, 5, 10 (only those tables) | ≤ 100 | `rest < k`; quarters; whole euros |
| groep 5 | 7–10 | up to 10 | ≤ 100 (money ≤ €20 per payment) | division strategy, duration, change |

The art/sound consequences: **groep 3 is icon-only** (no written sums on the card
beyond the mandatory sentence — see `Bedden op rij`, `Wasmandtoren`, `Tobbe-tijd` in
HOTEL.md §5); the clock model draws whole hours for groep 3, quarters for groep 4 and
free minutes for groep 5; and money games never show an amount above €20. **Never show
level numbers.** Timers exist only for memorisation items (splits to 10, tables) with a
2-second window that decides only whether *help* appears, never whether the answer
counts.

---

## 18. Tablet targets — recommendation

### 18.1 What is tested today

`mobiel.js` runs eight phone profiles: `iphone13` (390×844 dpr 3), `iphone13-land`
(844×390), `pixel5` (393×851 dpr 2.75), `pixel5-land`, `375×667` dpr 2, `667×375`,
`360×740` dpr 3, `740×360` dpr 3. `hits-plaats.js` adds `420×860` dpr 3, `860×420`
dpr 2, `740×360` dpr 2, `360×740` dpr 3, `844×390` dpr 3. `mobiel-perf.js` uses
`844×390` and `851×393`. The smallest frame the CSS explicitly designs for is a
**320×640** phone (frame 296×314 css-px). **No tablet is tested at all today.**

### 18.2 What the current build does on a tablet (measured, §13.2)

* Landscape ≥ 900 px: `#app` is capped at **1180 px**, so a 1280 px tablet gets 50 px
  of margin on each side; the panel column is hidden and the frame takes the full
  width. Frame 1000×550 (iPad 1024×768), 1156×602 (iPad 1180×820), 1156×582
  (Android 1280×800).
* Portrait: `#app` is capped at 960 px, so 768/800/820 px tablets use the full width.
  Frame 744×799 / 776×885 / 796×885.
* `g` lands on **4 in landscape and 3 in portrait** on all three tablets; `q` on
  1.48–1.95 css-px per voxel-px, i.e. **2.5–3× the phone value** — the rooms are
  genuinely bigger, not just sharper.
* The keypad always stays *inside* the frame (every tablet frame is ≥ 550 px tall,
  well above `KADER_RUIM = 340`).
* Room chips measure ≥ 52 px, the footer is visible, no page scrolling occurs.
* The world canvas is **9.3–11.5 MB of RGBA** at dpr 2 — the density cap does not apply
  (short side ≥ 500). On a dpr-3 tablet it would roughly double. This is the single
  number to watch on the port.

### 18.3 Recommendation for the Godot port

**Base resolution: `1024 × 768` (iPad landscape logical), stretch mode
`canvas_items`, stretch aspect `expand`, and `get_window().content_scale_factor` set at
runtime so that one Godot unit is one CSS pixel.**

Rationale and the exact settings:

1. **One unit = one CSS pixel is non-negotiable.** The 48 px / 44 px tap rule and the
   12 px text floor are CSS-pixel rules that come from a child's fingertip, not from
   the display. If units were device pixels, every rule would need a `dpr` multiplier;
   if the viewport were letterboxed to a fixed base, a 360 px phone would shrink every
   button to 17 px. So: `stretch_mode = canvas_items` (so vector UI and fonts render at
   full device resolution rather than in a low-res buffer), `stretch_aspect = expand`
   (extra screen becomes extra units, exactly like a fluid CSS page), and
   `content_scale_factor = device_pixels_per_css_pixel` — read once at start-up and on
   every resize. `1024 × 768` is then only a *design reference* for the layout work; the
   real viewport is whatever the browser gives.
2. **The layout must stay fluid, not scaled.** Port `style.css` as Containers with the
   same breakpoints (§16.9). Add **one tablet breakpoint of your own**: at
   `viewport width ≥ 900` the current CSS already switches to the landscape
   side-by-side/full-width mode; keep the `#app` cap at **1180 units** so the reading
   distance stays child-sized on a 1280-unit tablet, and centre it.
3. **The world goes in a `SubViewport`, reproducing `dicht`.** Size the SubViewport
   `frame_css × dicht` where `dicht = max(d, g/q)` with `d = min(3, dpr)`, capped at 2
   when `min(width, height) < 500`. Draw voxels at the whole `g`. Display the
   SubViewport in a `TextureRect` of `frame_css` size with **`texture_filter = linear`**
   (the browser's CSS downscale of the canvas is smooth). This is a literal translation
   of HOTEL.md §1 and it is what keeps voxels un-stretched.
4. **Extend the density cap to tablets.** The JS cap only fires below a 500 px short
   side; on a dpr-2 tablet the world canvas is already 11.5 MB and a dpr-3 tablet would
   be ≈ 25 MB. Recommendation: cap `d` at 2 whenever `min(width, height) < 900`, i.e.
   every phone **and** every tablet in portrait; only a large desktop keeps 3. `q` is
   unchanged by this, so nothing looks smaller — verify with the `mobiel-perf.js`
   equivalent.
5. **Targets to add to the test matrix:** `1024 × 768` and `768 × 1024` (iPad, dpr 2),
   `1180 × 820` and `820 × 1180` (iPad Air/Pro 11", dpr 2), `1280 × 800` and
   `800 × 1280` (Android tablet, dpr 2), plus at least one dpr-3 tablet
   (`1024 × 768 @ 3`) to prove the cap in point 4. Expected frames are in §18.2 — use
   them as the regression baseline.
6. **Do not raise the voxel size above 4.** `g` is clamped 2…4 by design; a tablet
   already lands on 4 in landscape. If a future 2 K tablet would push it higher, let
   `dicht` rise instead — that is exactly what `dicht = max(d, g/q)` is for.

---

## 19. Open questions for the port

1. **Font.** The stack starts with Comic Sans MS / Comic Neue / Chalkboard SE. A Godot
   web export cannot rely on any of those being installed, and the em-widths differ per
   fallback — yet the whole layout was measured against a specific rendering ("34
   characters on one line at 420 px"). Which font ships, and is the ≤ 34-character
   one-line guarantee re-measured against it? Unresolved in the JS.
2. **Emoji.** ~60 distinct emoji are used, several with variation selectors
   (`🛎️`, `☀️`, `🛏️`). The browser supplies the colour font today. A Godot export must
   bundle an emoji font or an atlas; which one, and does it contain every glyph above
   (`🫗`, `🪙`, `🩺`, `🧦`)? Not answered anywhere in the code.
3. **`hoedje`, `sjaaltje` and `bal` on a *lying* goose.** `sjaaltje()` uses a per-column
   roof and a ceiling to keep the collar under the neckline; the goose's neck geometry
   is rewritten (`hx·2.5`) and I could not confirm from the code that all seven
   accessory combinations were ever inspected on all four species in all fifteen poses.
   The JS is silent; the port should render the 420-image matrix once and look at it.
4. **`komFaces` cache key.** `komCache` is declared as an array (`var komCache = []`)
   but used as a map with string keys `'k0'…'g4'`. It works, and it is never cleared —
   an unbounded cache with at most 10 entries. Intentional or a leftover? (Harmless
   either way; it is 10 plates.)
5. **Two dead CSS rules** (§16.3): the `max-width:520px` and landscape
   `max-height:560px` `.world { max-height }` overrides are shadowed by the later block.
   Was 44vh / 62vh meant to survive? Porting them would change the frame on phones.
6. **`Snd.plop(hand)`** takes a `hand` argument that raises the pitch by 40 Hz per unit,
   but no caller in the repo passes one **(measured by grep: all calls are `plop()`)**.
   Dead parameter, or a feature waiting for the fuller hand? The port should keep it.
7. **Noise determinism.** `papier()` uses `Math.random()`, so `brief`, `deur`, `kar` and
   `plons` differ on every play (§15.4). Is that intended texture, or should the port
   seed it so the same splash always sounds the same? The code gives no hint.
8. **`prefers-reduced-motion` and the 💤.** `world.js` freezes the guests and drops the
   particles, but `tekenZzz` is not guarded — a sleeping guest keeps its Z's. They are a
   still image, so this is probably fine; confirm it is a decision and not an oversight.
9. **`KADER_ONDER = 132` versus the keypad strip.** The camera reserves 132 css-px below
   the room for the keypad, and `ui.js` moves the keypad *out of the frame* below
   300 px. Between 300 and ~430 px of frame height both mechanisms are active. No test
   pins the interaction; the port should decide one owner.
10. **Text-to-speech.** HOTEL.md §9 allows optional read-aloud through the Web Speech
    API. No code in the repo uses it. Is it in scope for the Godot port (which has no
    Web Speech API — it would need a JS bridge on the web export)?
11. **Tablet interaction distances.** `hits.js` keeps `(h1 + h2)/2` px between buttons
    and `GAT = 4` px between a button and its object. Those were tuned on phone frames
    of 296–676 px; on a 1156 px frame the same absolute gaps are proportionally much
    smaller. Should they scale with `q`? Nothing in the code says.
12. **Dark mode / high contrast.** `color-scheme: light` is declared and there is no dark
    palette. Confirm the port also ships light-only.

---

## Appendix A — `HOTEL.md`, complete

Reproduced from `/home/pc/Documents/xnw/rkn/HOTEL.md` (2026-09-04). The text is
byte-for-byte; only the heading levels are demoted by one so this appendix nests inside
this document.

## Dierenhotel Kwispelsteeg — ontwerp (synthese)

Pivot van het Kwispelsteeg-diorama naar een Habbo-achtig dierenhotel waarin de rekenminigames IN de 3D-wereld gespeeld worden. Doelgroep ongewijzigd: meisjes 6–9, groep 3–5 (curriculum en ontwerpvalkuilen: zie IDEAS.md). Techniek ongewijzigd: de bestaande vanilla-JS voxelmotor (demos/waggletail). Gegenereerd 2026-08-24 uit drie ontwerp-lenzen (architectuur, hotelwerk-games, gastenplezier-games), samengevat en ontdubbeld door de lead.

### 1. Kernidee: de wereld is het rekenblad

- Geen rekenkaartjes onder het diorama meer. Alles wat je aanraakt (bakjes, bedden, sleutels, munten, wijzers, dieren) ligt in de wereld. Technisch: de bestaande naamplaatjes-laag (DOM boven het canvas op schermX/schermY) wordt een hotspot-laag met knoppen en drop-targets; het huidige sleepmechanisme blijft ongewijzigd werken.
- Kamer-camera: nooit uitzoomen, wel verhuizen. Eén ruimte vult altijd het scherm (voxels blijven scherp); groei = meer ruimtes. Wisselen via deur/trap, een kamerbalk met "hier wacht iemand"-badges, of een 2D-plattegrond.
- Ruimtes: receptie, gang met kamers, keuken, tuin (het huidige erf, hergebruikt), zwembad en wasserij (golf 3); later spelzaal, spa, feestzaal, verdieping 2.

**De acht ruimtes (`rooms.js`, maten in voxels; de wanden staan op x = 0 en z = 0).** Dit is de lijst zoals hij in de code staat:

| id | naam | w × d | wand | deuren naar | waarvoor |
|---|---|---|---|---|---|
| `receptie` | Receptie 🛎️ | 120 × 120 | 54 | gang | de balie als L: bel, kassa, meubelboek, prikbord, sleutelbord — hier komt een gast binnen en checkt hij uit. |
| `gang` | Gang 🚪 | 120 × 36 | 56 | receptie, kamer 1, kamer 2, keuken | de verdeelruimte: vier deuren, twee planten en een kist, en de route van de voerkar. |
| `kamer1` | Kamer 1 🛏️ | 114 × 114 | 58 | gang | twee bedden, een voerbakje en een speelmand: hier slapen en eten de gasten. |
| `kamer2` | Kamer 2 🛏️ | 114 × 114 | 58 | gang | dezelfde inrichting als kamer 1, tweede slaapkamer (en de uitwijkkamer van "bedden op rij"). |
| `keuken` | Keuken 🍪 | 120 × 114 | 56 | gang, tuin, wasserij | voerkast, koekjeszak en de voerkar: hier wordt het eten verdeeld. |
| `tuin` | Tuin 🌳 | 130 × 130 | — (erf, vast kader) | keuken, zwembad | het erf van de Kwispelsteeg: tobbe, hok, boom, bal, kist, plus twee vrijgehouden vloerzones. |
| `zwembad` | Zwembad 🏊 | 144 × 88 | 50 | tuin | een langwerpig bad ín de vloer tegen de achterwand, met een dek ervóór: de zwemles (G1). |
| `wasserij` | Wasserij 🧺 | 100 × 90 | 52 | keuken | wasrek en wastobbe, vrije wand voor de kratten: de wasmandtoren (G4). |

De deurgraaf is één samenhangend geheel (`Rooms.pad`); de tuin heeft geen wanden, dus haar twee doorgangen zijn gaten in het hek in plaats van deurgaten.

**Nieuwe ruimtes (golf 3, ticket P1a).** Het zwembad hangt aan de tuin via een opening in het achterhek. Het bad staat als data op de ruimte (`Rooms.get('zwembad').bad` = x 18..134, z 12..44), zodat een spel er een baan van L meter lineair op afbeeldt; de twee wachtplekken staan er ook (`.dek.start` en `.dek.over`). De dieren dwalen alleen op het dek vóór het water — de dwaalplekken, de deur en beide dek-plekken liggen in dezelfde convexe strook, dus geen enkele wandeling kruist het bad. De wasserij ligt naast de keuken en is de kamer van de wasmandtoren (G4). De tuin houdt twee kale vloerzones vrij (`Rooms.get('tuin').zones`): `hinkel` langs de achterrand vóór het hok (76 × 16, voor de stapstenen van G3) en `kraam` langs de rechterzijrand (22 × 32, voor de souvenirkraam van G5).

**Kamermaten (voxels, `rooms.js`).** De vier speelkamers in de tabel hierboven zijn 1,5× groter dan de eerste opzet — ze voelden te klein. De gang en de tuin (vast kader) bleven zoals ze waren. De wandhoogtes bleven ook staan (50–58), dus de kamerdoos van die vier is hoger geworden (290 → 366–370 voxel-px) en hun vloer is 1,5× zo diep. Meubels worden niet groter: de balie is daarom een L van twee + twee stukken, en álle plekken in een kamer staan als bréuk van `r.w` / `r.d` in de code (`Rooms.plek`, `Rooms.hoogte`) — een volgende verbouwing schuift ze automatisch mee. De dieren zijn ook niet groter geworden; die vier kamers krijgen daarom `loop: 1.5` (rooms.js), zodat een gast er op het scherm net zo hard loopt als vroeger en een kamer oversteken even lang duurt.

**Camera en voxelmaat.** Drie getallen horen bij elkaar, per ruimte: `q` = css-px per voxel-px (hoe groot staat de kamer op het scherm), `g` = de voxelmaat in canvas-px (altijd een heel getal 2..4, want uitgerekte blokjes willen we niet) en `dicht` = canvas-px per css-px, met `q = g / dicht`. Omdat de kamers niet meer allemaal even groot zijn heeft **elke ruimte zijn eigen maat**: hij vult het kader in de breedte, en in de hoogte past minstens de hele vloer plus een strook wand van 28 voxels (daar hangen het prikbord en het sleutelbord). Boven die strook staat kale wand; in een laag kader (een liggende telefoon, 200 px) snijdt de camera daar een stuk van af — nooit van de vloer. Dat is geen uitzoomen: je ziet nooit het hele hotel, je verhuist, en bij het verhuizen verandert de maat mee (anders zou de smalle gang klein in beeld staan omdat de receptie breed is). Daarna kiezen we de dichtstbijzijnde héle `g`; is die groter dan het scherm zelf kan geven (op een telefoon is `g = 2` al te groot voor een kamer van 500 voxel-px breed), dan tekenen we het canvas op een hógere dichtheid dan het scherm en laat de css het terugschalen. Zo blijft de voxelmaat heel, past de kamer altijd, en houden de knoppen en de tekst van de hotspot-laag hun echte css-maat (≥ 48 px). **Dichtheidsplafond (M1b).** Op een klein scherm — de **korte** zijde onder de 500 px, dus een telefoon staand én liggend — met `devicePixelRatio > 2` rekenen we met 2 als ondergrens van `dicht` in plaats van 3. Daarmee valt `g` daar op 2 en werd het wereldcanvas van een iPhone 13 staand 3,4 MB in plaats van 7,7 MB (vloerplaat 2,8 in plaats van 6,3 MB) en liggend 6,1 MB in plaats van 9,6 MB, terwijl `q` (hoe groot de kamer op het scherm staat) precies gelijk blijft: de css schaalt het canvas terug en op een 3×-scherm zie je dat niet. Het blijft een plafond op de **ondergrens**: `dicht = max(ondergrens, g / q)`, dus een kamer die niet in het kader past duwt de dichtheid nog steeds omhoog (anders zou `g` geen heel getal meer kunnen zijn). Liggend is dat goed te zien: hoe lager het kader, hoe hoger `dicht` — een hoger kader is daar dus ook een goedkoper kader. De hoogte van het kader is voor alle ruimtes gelijk (anders springt de pagina bij elke deur): zo hoog als er op het scherm over is, maar nooit zó hoog dat de kleinst uitvallende doos minder dan 60% vult; onder de kamer blijft een strook van 132 px vrij voor het cijferpad. Reken in een minigame dus met `ctx.wereld.schaal()` (`k = q`, per kamer) en **nooit** met `devicePixelRatio`.

### 2. Gastenstroom en progressie

- Gast arriveert als het kind op de bel tikt (nooit automatisch, geen oplopende wachtrij). Check-in aan de balie = de bestaande poortvragen plus "is er een vrij bed?".
- Bedden zijn de harde gastenlimiet. Meer bedden kopen = meer gasten = grotere getallen. Rekenen koopt beter, nooit toegang: het hotel gaat nooit op slot.
- Behoeften (eten, kamer, spelen, bad) staan als pictogram boven het dier; het dier loopt zelf naar de plek en wacht daar geduldig. Geen verval, geen meters, nooit boos of ziek.
- Uitchecken: familie aan de balie, brief/foto voor de muur, rekening betalen (rekenmoment).
- Dagloop: ochtendronde (prikbord, max 3 taakchips) → vrij spelen (taken in willekeurige volgorde, meubels zetten, bel) → avondronde (uitchecken, sterren, morgen).

### 3. Eén schaalregel: N bepaalt het getal, nooit het tempo

Elke minigame leidt zijn getallen af uit N (aantal gasten) met T = k·N + r, 0 ≤ r < k; k en het plafond komen uit de band:

| Band | N | k | Plafond | Extra |
|---|---|---|---|---|
| groep 3 | 2–3 | 1–2 | ≤ 20 (liefst ≤ 10) | r = 0 of 1; klok hele uren; icoon-only |
| groep 4 | 4–6 | 2,3,4,5,10 (alleen die tafels) | ≤ 100 | rest < k; kwartieren; hele euro's |
| groep 5 | 7–10 | t/m 10 | ≤ 100 (geld ≤ €20 per betaling) | verdeelstrategie, tijdsduur, wisselgeld |

De band wordt begrensd door het adaptieve signaal (rollende accuratesse + twijfeltijd): hooguit één stap boven het kunnen van het kind. Een snelle zesjarige mag een groot hotel hebben zonder groep-5-sommen. Nooit levelnummers tonen. Timers: alleen memoriseer-items (splitsingen t/m 10, tafels) hebben een 2-secondenvenster, en dat bepaalt alleen of er hulp verschijnt (rekenrek/getallenlijn), nooit of het antwoord telt.

### 4. Economie

- Sterren: voor meedoen (taak afgerond, hoe dan ook) → versiering (vlaggetjes, kleuren, stickers). Beloning die niet aan goed rekenen hangt.
- Munten (hele euro's): uit uitchecken. Rekening = nachten × prijs (€1/€2/€5), totaal ≤ €20; familie legt munten neer, kind telt en geeft wisselgeld (groep 3: samen tellen; 4: bedrag samenstellen; 5: wisselgeld van €20). Muntenlade van Zilverhoef hergebruikt.
- Meubelboek, alles ≤ €20: plant €1, bakje €2, mandje €3, bed €5 (+1 gast), speelmand €4, badkuip €8; nieuwe kamer = 4 bouwdelen × €5; verdieping = 4 × €10 (tafel van 10 met biljetten). Meubels slepen op het voxelraster, tik = draaien.

### 5. Minigame-catalogus (in-world, schaalt met N)

Bestaande drie, opnieuw gehuisvest:
- **Voerkar** (was: eerlijk delen) — keuken: zak van T koekjes, kar met N vakjes + snoeppot, door de gang, elk bezet bakje vullen. Overgeslagen kamer is zichtbaar.
- **Dagplanner op het prikbord** (was: planbord) — regels komen uit het gebouw (één tobbe, wasserij voor 2, dokter Els om 15:00); na "Klaar" speelt het hotel het plan echt af. Solver ongewijzigd.
- **Check-in aan de balie** (was: poort) — voorraad vs dagen × nieuw, plus "vrij bed?".

Hotelwerk (nieuw):
1. **Bedden op rij** — kamer als rooster, bedjes slepen tot rijen × bedden; schuifwand = verdeelstrategie (7×6 = 5×6 + 2×6). Tafels als kamer. Icoon-only. Kernspel: bepaalt gastcapaciteit.
2. **Sleutelbord** — sleutel naar juiste haakje; blanco nummerplaatjes uit het patroon opmaken (1–20 → sprongen van 5 → kamer 214 = verdieping 2). Gast loopt daarna naar zijn deur.
3. **Souvenirkraam** — gast met verlanglijst, munten slepen, wisselgeld; het gekochte (sjaaltje, hoedje, bal) blijft zichtbaar op het dier.
4. **Wasmandtoren** — wasgoed sorteren in kratten; kratten worden echte staven (turven, verschil, legenda 1 = 2). Icoon-only.
5. **Poetskar** — tegelmat (oppervlakte) en plintlatten (omtrek) laden en leggen; L-vormige kamer bij groep 5. Tekort = tweede loopje, geen fout.
6. **Wekkerdienst** — wijzers van de halklok draaien naar wekkerkaartje (hele uren → kwartieren → minuten + tijdsduur). Spookwijzer na 2 pogingen.
7. **Bagagelift** — koffers in de liftbak tot de grens (touw zakt door, naald draait); balansplank = getal in twee gelijke delen. Kilo's, later gram.
8. **Tafel dekken** — spiegelbeeld van de gedekte tafelhelft, later twee assen. (Overlapt met Spiegelmaskers; zie §6.)

Gastenplezier (nieuw):
9. **Tot je schouders** — zwembad met aflopende bodem; meetlat, dier naar de zone waar het water tot zijn schouders komt, opstapblokjes van 10 cm. Meten cm/dm.
10. **Hinkelpad** — stapstenen als getallenlijn (20 → 100 → 1000); sprongkeitjes 2/5/10 op een dier; het dier hupt en moet precies op de trap landen.
11. **Rijtjes in de moestuin** — zaadjes in rijen × kolommen, twee vormen voor hetzelfde getal, rest in het kweekpotje. (Overlapt met Bedden op rij; zie §6.)
12. **Wat wil de jubilaris?** — feestzaal: stemmen turven op het krijtbord, ballonnen als echte staven, hoogste kolom wint.
13. **Tobbe-tijd** — scheppen shampoo, splitskraantje = halveren, twee tobbes even hoog; verdubbelen/halveren, splitsen t/m 10. Icoon-only.
14. **Spiegelmaskers** — stickers op linkerhelft, tafel klapt dicht, masker op de snuit; as verticaal → horizontaal → diagonaal.
15. **Dansrijtje** — polonaise op lichttegels, dansmove per dier, patronen ABAB/AABB/groeiend; muziek wacht altijd op jou.
16. **De bus van tien uur** — wijzers op vertrektijd, activiteiten met duur, retourtijd; bus rijdt echt door het diorama.

Domeindekking: delen met rest, tafels/arrays, geld, tijd/klok, tijdsduur, meten (cm/dm, kg/g, oppervlakte/omtrek), getallenlijn/sprongen, getalpatronen/positiewaarde, data/turven/staafdiagram, symmetrie, patronen, verdubbelen/halveren/splitsen.

### 6. Lead-keuzes bij overlap

- Arrays: **Bedden op rij** is primair (stuurt de gastenlimiet). Moestuin-rijtjes later als groep-5-variant (verdeelstrategie over twee bakken).
- Data: beide houden, andere band: **Wasmandtoren** (groep 3–4, icoon-only) en **Feestzaal** (groep 4–5, legenda).
- Symmetrie: **Spiegelmaskers** wint (eigen masker, gedragen door het dier). Tafel dekken vervalt of wordt patroonvariant.
- Tijd: beide houden: **Wekkerdienst** (groep 3–4) en **Bus** (groep 5 tijdsduur).
- Geld: één muntenlade-component voor rekening bij uitchecken, Souvenirkraam en meubelboek.

### 7. Bouwplan (fasen, elk apart verifieerbaar)

1. **Fundament** — rooms.js (ruimtes als data, deurgraaf met BFS), kamer-camera, hotspot-laag + hit-test, receptie met bel en check-in, bedden als limiet, save-formaat v7 met migratie van v6 en v5, dieren buiten beeld grof gesimuleerd. Voerkar en rekening-bij-uitchecken als eerste twee in-world taken.
2. **Kern-lus** — Bedden op rij (capaciteit), Sleutelbord, Tobbe-tijd, meubelboek + muntenlade. Hiermee sluit de lus rekenen → inrichten → meer gasten → moeilijker.
3. **Verbreding** — Wekkerdienst, Hinkelpad, Souvenirkraam, Wasmandtoren, dagplanner in-world.
4. **Feest** — Feestzaal, Spiegelmaskers, Dansrijtje, Bagagelift, Poetskar, Zwembad, Bus.

### 8. Open beslissingen voor de ontwikkelaar

1. Eén ruimte per scherm of toch een uitgezoomd hotel-overzicht (Habbo-gevoel)? Advies: kamer-camera + 2D-plattegrond; papieren prototype op telefoonformaat eerst.
2. Band-van-N versus adaptief: adaptief begrenst de band, N de grootte. Productkeuze.
3. Prijzen ≤ €20 dwingen tot bouwdelen (kamer = 4 × €5): sparen of gedruppel? Playtesten.
4. Uitcheck-cadans: met 2–4 nachten per gast kan N schommelen in plaats van groeien; eerst een simulatie van bedden × nachten op papier.
5. Hotspots bij overlap in isometrie: z-index moet exact de tekenvolgorde volgen (anders pakt een tik het verkeerde object). Engine-ticket die alle games delen.

*Status: ontwerp, niet gebouwd, niet geplaytest. Motorclaims zijn door de workers tegen world.js/ui.js/state.js/shop.js gecheckt (hergebruik van naamplaatjes-laag, makeDraggable, planOplossingen, koekjesSom, muntenlade).*

### 9. Ontwerpregel: rekenen ín de wereld, zonder leeswerk (toegevoegd na speeltest fundament)

Feedback op het fundament: de rekenpanelen naast het diorama voelen als "een website naast het spel", en er staat te veel tekst. Vanaf nu geldt voor het fundament en alle minigames:

- **Geen rekenpaneel naast de wereld.** Sommen, aantallen en keuzes verschijnen als kleine kaartjes of spreekwolkjes die aan een object of dier in de wereld hangen (zelfde verankering als de naamplaatjes). De wereld blijft altijd zichtbaar en is het enige speelvlak.
- **Getallen op objecten.** Bakjes tonen hun aantal als cijfer op het bakje, haakjes hun nummer, de toonbank het bedrag, bedden hun rij. Het rekenschrift-uiterlijk mag terugkomen als één kleine "sommenkaart" aan het object, nooit als een lap tekst.
- **Tekstbudget (herzien 2026-09-03 na speeltest: een kind van zes kon "4 × 2 ? 20" niet ontcijferen).** Elke sommenkaart draagt één gewone Nederlandse zin, vlak bóven de som, met een werkwoord of een vraagwoord erin en met het pictogram vooraan op diezelfde regel. **Budget: ≤ 8 woorden én ≤ 40 tekens.** De één-regel-garantie geldt tot ongeveer 34 tekens (gemeten op 420 en 860 px breed); 35-40 tekens breekt naar een tweede regel, en meer dan twee regels per zin bestaat niet. Op een smalle telefoon (kader < 360 px) krimpt het kaartje naar 170 px en breekt elke zin af: daar gaat "het dier blijft zichtbaar" vóór "de zin op één regel", en het cijferpad mag daar toetsen van 44 px hebben. Een tweede korte zin mag als er nog een getal bij hoort, bijvoorbeeld de voorraad; drie zinnen niet. De zin noemt de getallen in hotelwoorden: "🍽 We eten 4 dagen lang 2 scheppen" boven "4 × 2". Een kale uitdrukking ("4 × 2 ? 20", "12 : 3", "🪑 + 🛋 =") staat er nooit zonder die zin, en "?" wordt nooit als vergelijkingsteken tussen twee uitdrukkingen gebruikt. Antwoordkeuzes zijn knoppen met pictogram ÉN woord ("⬇ te weinig", "⚖ precies", "⬆ blijft over") in één strook aan het kaartje: nooit alleen een pictogram, nooit verspreid door de kamer. Een pictogram staat altijd in hetzelfde wolkje als zijn woord of getal - ook de wenspictogrammen boven de dieren ("🍪 eten", "🛏 bed"). Verder blijft het bij pictogrammen en getallen: uitleg gebeurt door voordoen (uitgewerkt voorbeeld in de wereld), niet door lezen, en feedback is pictogram + getal ("nog 2 🍪", "3 + 3 ✓"). Taakkaartjes op het prikbord houden hun eigen korte regel (≤ 6 woorden).
- **Slepen gebeurt in de wereld.** Koekjes komen uit een zak-hotspot en gaan naar bakjes in de kamer; munten uit de buidel naar de toonbank; sleutels naar haakjes op de muur; bedjes uit de kist op de vloer. Het cijferpad is het enige toegestane 2D-element en verschijnt klein, aan het object verankerd.
- **Optioneel voorlezen.** Korte prompts mogen via de browser-spraaksynthese (Web Speech API, offline beschikbaar op de meeste apparaten) worden voorgelezen bij een tik op het wolkje; nooit verplicht, nooit automatisch herhalend.
- **Technisch.** Het fundament levert hiervoor primitieven in de plugin-API: `ui.wolk(obj, {icoon, getal, tekst?})` (spreekwolkje aan object), `ui.somkaart(obj, som, {regel, icoon, keuzes})` (mini-rekenschrift aan object; `regel` = de verplichte zin, `keuzes` = de knoppenstrook met woorden), `wereld.getalTag(obj, n)` (cijfer op object), en sleepbronnen met teller (`hotspots.bron(obj, {icoon, aantal})`). Games gebruiken uitsluitend deze primitieven voor rekenweergave; het oude `ui.paneel` blijft alleen voor het startblad en het meubelboek-overzicht.

---

## Appendix B — prototype artefacts

Everything below was produced today by running the unmodified game code in headless
chromium (Playwright 1.60.0, chromium, from
`/home/pc/work/ergomouse/node_modules/playwright`). Nothing in `demos/dierenhotel/` was
touched.

### `/tmp/dh-art/` — sprite extraction

| file | what |
|---|---|
| `probe.html` | loads only `art.js` + `rooms.js` by `file://` |
| `extract.js` | bakes 64 plates through `Art.kit` and writes them as PNG; runs the pixel-for-pixel fidelity test; renders the proof sheet |
| `modelmaat.js` | measures voxel extents and face counts of all 33 built-in decor models (table in §8) |
| `posemaat.js` | measures the plate box and anchor offset of 4 species × 15 poses and of the bowl (tables in §5.1 and §7) |
| `kader-meet.js` | loads the **whole app** at ten viewports and reads `World.schaal()` (table in §13.2) |
| `meta.json` | per plate: name, canvas size, `dx`/`dy`, byte count, plus `Art.stats()` and the fidelity result |
| `gast_*.png` (23) | dog in all 15 poses at g=4, four species in `rust` at g=4, dog at g=2/3/5, four accessory sets |
| `kom_*.png` (10) | bowl levels 0–4, front and back part, g=4 |
| `decor_*.png` (28) | 14 decor models at g=2 and g=4 |
| `proefblad.png` | visual proof sheet, 16 sprites on the real page background |

Fidelity: `{"hond":{"px":63440,"anders":0,"max":0},"boom":{"px":148960,"anders":0,"max":0}}`
— **zero differing bytes**, so PNG extraction is exactly lossless. Total 1.27 MB for 64
plates.

### `/tmp/dh-snd/` — sound export

| file | what |
|---|---|
| `probe.html` | swaps `AudioContext` for an `OfflineAudioContext` with `state` forced to `'running'`, then loads `snd.js` **unmodified** |
| `export.js` | unlocks the band with a synthetic `pointerdown`, plays one sound, renders offline, measures peak and audible length, writes 16-bit mono WAV at 48 kHz |
| `<naam>.wav` (18) | `tik plop terug zacht ja tover dag brief hoera bel deur kar munt ster plons au klok hup`, 144 044 bytes each (1.5 s window) |
| `meta.json` | per sound: peak, dBFS, audible length in ms, sample rate, byte count |

Reproducibility check: two runs give bit-identical files for oscillator-only sounds
(`klok` verified) and different files for the noise-based ones (`plons` verified) —
`papier()` uses `Math.random()`.
