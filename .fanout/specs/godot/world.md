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
| 0 | `receptie` | `Receptie` | 🛎️ | 120 × 120 | 54 | `hout` | 1.5 | mat 45..99 × 78..114, colours `#E9BFC9`/`#E3B4C0`; **port:** the front door `ingang` (§1.2) |
| 1 | `gang` | `Gang` | 🚪 | 120 × 36 | 56 | `loper` | 1 (default) | – |
| 2 | `kamer1` | `Kamer 1` | 🛏️ | 114 × 114 | 58 | `zacht` | 1.5 | mat 51..93 × 45..87, `#DFCBEA`/`#D6BFE4` |
| 3 | `kamer2` | `Kamer 2` | 🛏️ | 114 × 114 | 58 | `zacht` | 1.5 | mat 51..93 × 45..87, `#CBE3D6`/`#BFDBCB` |
| 4 | `keuken` | `Keuken` | 🍪 | 120 × 114 | 56 | `tegel` | 1.5 | – |
| 5 | `tuin` | `Tuin` | 🌳 | 130 × 130 | 0 | `gras` | 1 | `erf: 1`, fixed frame `[-170, 190, -70, 220]`, `zones` |
| 6 | `zwembad` | `Zwembad` | 🏊 | 144 × 88 | 50 | `tegel` | 1.5 | `bad`, `dek` |
| 7 | `wasserij` | `Wasserij` | 🧺 | 100 × 90 | 52 | `tegel` | 1.25 | – |
| 8 | `speelzaal` | `Speelzaal` | 🧸 | 114 × 100 | 56 | `hout` | 1.5 | mat, zone `dans` (R2) |
| 9 | `kas` | `Kas` | 🪴 | 128 × 112 | 40 | `tegel` | 1.25 | **glass walls** (`glas`), terracotta path mat, zone `rijen`, `mijd` (R3, games-c.md §1) |

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
| speelzaal | `[-210, 238, -124, 224]` | 448 × 348 |
| kas | `[-234, 266, -92, 250]` | 500 × 342 |

### 1.2 Doors and the door graph

A door is `{naar, wand: 'x'|'z', at, breed}`; `at` is the start of the gap along the wall.
`Rooms.deur(kamer, naar)` returns the derived point: for `wand: 'z'`,
`{x: at + breed/2, z: 0, ix: at + breed/2, iz: 8}`; for `wand: 'x'`,
`{x: 0, z: at + breed/2, ix: 8, iz: at + breed/2}`. `(ix, iz)` is the step *inside* the
room where an animal stands before walking through. `poort: 1` marks a gate in a fence:
no hole is cut, the gate model stands in the fence line (`hek_x`/`hek_z`) and the gate's
screen box is measured there. Since 2026-09-23 the kitchen and the garden are joined by a
real door on both sides — a hole in the kitchen wall, and a door in the hotel's back wall
(`gevel`) on the garden side — so only the garden ↔ pool passage is a gate.
`Rooms.deur_hoog(r, dr)` is the one height rule for drawing and measuring: `min(wand − 6, 26)`
for a door in a wall, the facade's height standing in for `wand` in the garden, and
`POORT_HOOG = 18` for a gate.

**The tower (port, owner 2026-09-24: "Ik wil de winkels op een andere etage. Het is de
bedoeling dat het hotel heel groot en hoog aanvoelt net als Habbo Hotel. Op de begane grond
zijn enkel de buiten dingen als het zwembad en de tuin").** Every room has a floor,
`Kamer.etage`: 0 is the ground floor — the lobby, the one room indoors there, and the
outdoors (tuin, zwembad, kas) — 1 the shops (`winkels`), 2 the playroom (`speelzaal`), 3 the
guest floor (gang, kamer1, kamer2 and the keuken that feeds them) and −1 the cellar with the
laundry (`wasserij`, "K" on the lift, `Rooms.etage_teken`). A door never leaves its floor.
ONE lift joins the floors: `Kamer.lift = {wand, at, breed}` like a door, in exactly one room
per floor (receptie x/24, winkels x/24, speelzaal z/57, gang x/10, wasserij z/62 — where
each room's door down to the lobby used to be, so their door points did not move). The lift
is not in `deuren`: `bouw_af()` gives every lift room an entry in `deur_punten` for every
OTHER lift room, all on its one opening and marked `lift: true`, so `pad`, `World.reis`,
the free cells and the furniture rules treat a ride like a walk through one door, while the
wall drawing (`scenes/vloer.gd` `_lift`: an open steel cabin, the sliding doors pushed aside,
one floor light per floor with this floor's lit, a call plate), the map and the door buttons
draw it once. `Rooms.buren(kamer)` (doors first, then the lift), `etage(kamer)`, `etages()`
(top down), `op_etage(e)`, `lift_kamers()`, `lift_kamer(e)`, `via_lift(van, naar)` and
`lift_punt(kamer)` read it. The lift's one button (`Hotel`, id `lift_<kamer>`, 🛗 "Lift", a
door sign by `klas: hotdeur`) opens the tower sheet (§6.3); `World.naar` between two floors
is a lift ride — the new floor slides in from above going up, from below going down
(`LIFT_S` 0.55 s, `LIFT_OP` 55 % of the frame height) — and `Hotel.naar_kamer` chimes
`Snd.lift()` instead of the door sound. From the garden the facade rises three floors of
windows over the lobby's back door (`gevel.etages`).

| from | to | wand | at | breed | door point (x, z) | inside (ix, iz) |
|---|---|---|---|---|---|---|
| receptie | *lift* | x | 24 | 12 | (0, 30) | (8, 30) — to gang, speelzaal, winkels, wasserij |
| receptie | tuin | z | 106 | 12 | (112, 0) | (112, 8) — the back door, right of the desk |
| gang | *lift* | x | 10 | 12 | (0, 16) | (8, 16) |
| gang | kamer1 | z | 24 | 12 | (30, 0) | (30, 8) |
| gang | kamer2 | z | 60 | 12 | (66, 0) | (66, 8) |
| gang | keuken | z | 96 | 12 | (102, 0) | (102, 8) |
| kamer1 | gang | z | 72 | 12 | (78, 0) | (78, 8) |
| kamer2 | gang | z | 72 | 12 | (78, 0) | (78, 8) |
| keuken | gang | x | 75 | 12 | (0, 81) | (8, 81) |
| tuin | receptie | x | 34 | 12 | (0, 40) | (8, 40) — a door in the hotel's back wall (`gevel`) |
| tuin | zwembad | z | 38 | 12 | (44, 0) | (44, 8) — `poort` |
| zwembad | tuin | x | 60 | 12 | (0, 66) | (8, 66) — `poort` |
| wasserij | *lift* | z | 62 | 12 | (68, 0) | (68, 8) |
| speelzaal | *lift* | z | 57 | 12 | (63, 0) | (63, 8) |
| winkels | *lift* | x | 24 | 12 | (0, 30) | (8, 30) |
| tuin | kas | x | 62 | 12 | (0, 68) | (8, 68) — the kas's glass door in the hotel's back wall, where the kitchen window hung (R3) |
| kas | tuin | z | 52 | 12 | (58, 0) | (58, 8) |

(Until 2026-09-24 the kitchen had the garden door, z/104, and the laundry door, x/30; the
lobby had doors to the gang, the playroom, x/108, and the shops, z/106.)

`Rooms.pad(van, naar)` is a breadth-first search over this graph; it returns the full path
*including* the start room (`['gang','kamer1']`), `[van]` when `van === naar`, and `[]`
when a room does not exist. Example: `pad('kamer1','zwembad')` =
`['kamer1','gang','receptie','tuin','zwembad']` — down in the lift, out the back door.

**The front door** (port, owner 2026-09-23: the guests "komen momenteel vanuit de gang binnen
ipv ingang"). The receptie has one more opening that is NOT a door of this graph:
`Kamer.ingang = {wand: 'voor', at: 59, breed: 26, hoog: 38, open: true}`, the hotel's way
in from outside.  **Port (owner 2026-09-24: "zet de lobby deur waar het tapijt is maar alleen
de uitlijn en laat hem open zodat je erdoorheen kan kijken en het tapijt zien ... En maak hem
wat groter dan de andere deuren"):** it stands in the FRONT edge of the lobby (`wand: 'voor'`,
z = d), the side the camera looks in through, in the middle of the pink rug (x 59..85 over
the rug's 45..99), and it is only its outline — `voordeuromlijst` (§1.3, art-sound-rules.md
§8): two white posts, a lintel and the threshold, no leaf, so you look through it at the rug
as through every door into the next room.  26 wide and 38 tall (`hoog`, read by
`deur_hoog()`) where a door in a wall is 12 × 26 (first 20 × 32; "Mooi maak de deur nog iets
groter", same day).  `open: true`: it never shuts, makes no
door sound, and `World.ingang_open(kamer)` is always true.  (For one day, 2026-09-23, it was
a closed door on the back wall right of the desk, `voordeur` @ 111,1 with a welcome mat.)
`Rooms.ingang(kamer)` derives `{x: 72, z: 120, ix: 72, iz: 108, dx: 72, dz: 118, wand}`
(`(dx, dz)` is the threshold, where a guest appears; the step inside is onto the rug) and is
`{}` for every other room. It is kept out of `deuren` and `deur_punten`, so no path (`pad`),
no door button, no "komt eraan" bubble, no chip of the room bar and no cell of the map leads
through it; outside is no room. Its step inside keeps free cells (< 14) and bought furniture
(< 12) away like a door's, and `World.vlak_van_ingang(kamer)` is its screen box — a box the
buttons keep off (`Hits.plaats`); a card and its strip may float over it like over the rest
of the world. `tests/test_rooms.gd` holds it to the door rules: not in the graph, nothing of
the room's fixed decor or things hides more than 3 % of it, and the way in from it stays in
front of the desk (§3.3).

### 1.3 Fixed decor per room

Decor entries are `{n, x, z, y?, ver?, params?, sleutel?}`. `ver` means "always draw first"
(wall decor). Two entries are lifted out of the decor list at boot by `world.js`
`bouwDingen()` — every entry with a `sleutel` and every entry named `kar` — and become
movable **dingen**: `balielamp` (receptie 15, 105, y 14) and `kar` (keuken 48, 66).

| room | decor (model @ x, z [, y]) |
|---|---|
| receptie | `balie` @ 40,60 · `balie` @ 75,60 · `baliez` @ 15,58 · `baliez` @ 15,93 · `bel` @ 33,60 y14 · `kassa` @ 66,60 y14 · `boek` @ 15,75 y14 · `lamp` @ 15,105 y14 (→ ding `balielamp`) · `prikbord` @ 1,64 y14 `rot 1` `ver` (since 2026-09-23 on the left wall over the bench in the waiting corner: behind the desk the visible wall had no room for the task cards, which now hang round the board instead of across the room) · `sleutelbordz` @ 1,84 `ver` · `plant` @ 105,18 · `plant` @ 108,81 · **port (2026-09-24):** the outline of the front door `voordeuromlijst` @ 72,119 in the front edge, in the middle of the pink rug, over the opening of §1.2 (open, 26 × 38; on 2026-09-23 it was the closed `voordeur` @ 111,1 on the back wall with `welkomsmat` @ 111,7) |
| gang | `plant` @ 36,30 · `plant` @ 108,30 (along the FRONT edge since 2026-09-23: against the back wall they hid 37 % and 29 % of the bedroom doors) · `kist` @ 114,14 |
| kamer1 | `plant` @ 107,8 (was 102,12: it hid the door's corner) · `mand` @ 106,74 (was 93,99: it stood on the fourth bed place, §1.5, 2026-09-24) · port: `raam`, `schilderijz`, `nachtkastje` @ 8,51, `blokken` @ 14,100 |
| kamer2 | port (owner 2026-09-17, "kamer 2 ... mag wel iets anders"): `raamz`, `schilderij`, `boekenplank`, `staande_lamp` @ 12,52, `speelgoedkist` @ 104,44, `mand` @ 14,106 (was 14,96: on the third bed place, 2026-09-24), `plant` @ 48,106 (was 48,102) |
| keuken | `kast` @ 33,6 · `zak` @ 66,18 · `kar` @ 48,66 (→ ding `kar`) · `plant` @ 108,93 |
| tuin | the lawn behind the hotel (owner 2026-09-23: "Het zwembad vanuit de tuin gezien is niet duidelijk dat lijkt gewoon op een huis"): `gevel` `{wand: x, hoog: 34, stoep: 8}` — the hotel's back wall with the kitchen door and (R3) the kas's glass door with its glass canopy `kasluifelz` @ 1,68 y27 `ver` and a potted plant `kaspot` @ 4,58 (the kitchen window `gevelraamz` @ 1,70 made way for it: z ≤ 85 is all the facade in view), `luifelz` @ 1,40 y27 `ver`, `deurmatz` @ 5,40 · behind the back fence the pool (`uitzicht`, below) with `zwembadtrap` @ 31,−3 and `parasol` @ 66,0, seen through `zwembadpoort` @ 44,10 · `boom` @ 22,126 · `hok` @ 22,22 (the back corner against the hotel, where it also closes the gap between wall and fence; the hopscotch path starts in front of it) · `tobbe` @ 32,94 · `bal` @ 120,76 (the garden's own ball; the souvenir stall that stood behind it moved into the arcade on 2026-09-24, games-d.md §3) · `kist` @ 12,84 · plus the generated back fence and grass tufts (below), and the resting props of `hinkel` and `kraam` (§5.1) |
| zwembad | `plant` @ 136,80 · `rozenboog` @ 4,66 (the gate back to the garden, 2026-09-23) with the garden beyond it: `boom` @ −22,46, `bloemstruik` @ −8,40 and −9,79 · one big `startblok` @ 14,28 (owner 2026-09-17: "Maak het startblok groter en doe 1 ipv 3"; the old `mat` entry plank is gone — "haal de oude houten plank weg") · plus the generated fence (along the back long side only, 2026-09-23) and grass tufts |
| wasserij | `kast` @ 28,6 · `tobbe` @ 80,74 |
| kas | (R3, games-c.md §1.4, `art/decor_kas.gd`) `zonnebloem` @ 6,6 · `moesbak` @ 28,10 `groei 3` and @ 86,10 `groei 2` · `potkast` @ 118,5 · `hangplant` @ 28,1 y22 `ver` · `hangplantz` @ 1,76 y22 `ver` · `aardbeienbakz` @ 7,38 · `gieter` @ 14,66 · `zaadkist` @ 118,20 · `pompoenen` @ 114,100 · `kruiwagen` @ 22,104 — plus the resting props of `oogst` (the picking table @ 30,38) and `weeg` (the balance @ 90,54 and its row of weights) |

The balie is an **L**: two `balie` pieces along x (35 voxels heart-to-heart) and two
`baliez` along z, so the four objects on it stay far apart on screen.

**Garden fence and tufts** (`bouwTuin`, deterministic, runs once at load):

* `HEK_X = HEK_Z = 10` is the default fence line; each room carries its own
  `hek_x`/`hek_z` (the garden keeps 10/10; the pool stands further off its
  fence at 4/4 — owner 2026-09-17: "Doe het hek verder van beide kanten van
  het zwembad", to make room for the startblokken).  Inside ⇔ `x > hek_x`
  and `z > hek_z`.
* `hekz` posts at `x = hek_x`, `z = hek_z, +14, … ≤ 130`, **skipping** `34 ≤ z ≤ 46` — but
  only where the side is a fence: since 2026-09-23 the garden's left side is the hotel's
  back wall (`gevel` on `x`), so the garden has no `hekz` at all (and `hek_x = 0`).
* `hekx` posts at `z = hek_z`, `x = 24, 38, … ≤ 130` — from `x = 10` when the left side is
  the facade, so the fence starts at its corner — **skipping** `38 ≤ x ≤ 50` (the opening
  to the pool, where `zwembadpoort` stands).
* The pool's own fence (`bouwZwembad`) runs along the BACK long side of the
  water and nowhere else (owner 2026-09-23: "zet het hek aan de bovenste
  zijkant van het zwembad niet aan de korte kant bij de startblokken"):
  `hekx` posts at `z = hek_z` (4), `x = bad.x0 + 14 = 32, 46, … ≤ w − 12`
  (the last rail ends at 142), and **no `hekz`**: the short side by the
  startblok is open, only the `rozenboog` of the gate stands in its line
  (`x = hek_x = 4`).  The fence starts one post past the corner over the
  startblok, so the block's own 🏊 button keeps that corner free (on a phone a
  post there stood under it).  Until 2026-09-23 it was the other way round: a
  side fence along the startblok, and behind the water only the posts beyond
  its two ends (owner 2026-09-17: "Haal het hek gedeelte dat op het zwembad
  zit weg").
* 30 grass tufts `pol0..pol4` from a seeded PRNG (`prng(90210)`, the same
  `a += 0x6D2B79F5` / `Math.imul` mulberry-style generator used for animals). Per iteration
  `i`: `u = round(r()*300 − 150)`, `w = 24 + round(r()*220)`, `px = (u+w)/2`,
  `pz = (w−u)/2`. A tuft is kept only if `px > 12 && pz > 12`, it is ≥ 22 (Manhattan) away
  from every piece of fixed decor that stands on the lawn (every decor entry that is neither
  `ver` nor a fence post — so a prop that moves takes its clear patch along; until
  2026-09-23 this was the literal list `[(16,68),(67,19),(32,94),(120,76),(95,23)]`), and it
  is outside every reserved zone inflated by 4 voxels (only `hinkel` since 2026-09-24, when
  the stall zone `kraam` went: two tufts, (108, 60) and (111, 39), grow where the stall
  stood). Model name is `'pol' + (i % 5)`.
  The port must reproduce this PRNG bit-for-bit if the garden is to look identical
  (32-bit unsigned arithmetic, `Math.imul`).

**Garden zones** (`Rooms.get('tuin').zones`, data only — the games place their own props):

| zone | rectangle | size |
|---|---|---|
| `hinkel` | x 24..100, z 34..50 | 76 × 16, running towards the doghouse in the far corner (moved there 2026-09-23) |

(`kraam`, x 104..126, z 36..68 along the right edge, was the souvenir stall's zone until
2026-09-24 — owner: "De kraam in de tuin voelt nu dubbelop die kan verwerkt worden in de
winkels"; the stall is the fourth stall of the arcade now, games-d.md §3.  The arcade has a
zone `kraam` of its own: the floor in front of that stall, x 112..124, z 28..40.)

**Pool** (`Rooms.get('zwembad')`):

* `bad = {x0: 18, x1: 134, z0: 12, z1: 44}` — water is a floor rule, not a model
  (116 × 32 voxels = 81 % of the room width), with a 4-voxel stone rim around it
  (x 14..138, z 8..48).
* `dek = {start: {x: 12, z: 56}, over: {x: 116, z: 56}}` — the two standing places on the
  deck, 12 voxels in front of the waterline.  `over` stands beside the finish flag
  (x 134, z 50), not in its foot: at (132, 56) a guest who climbed out stood inside the
  flag (2026-09-23).
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

Two rules the port added for the lawn (2026-09-23), both checked on a `gras` floor before
rule 2's meadow/grass split:

* `r.gevel.stoep`: the strip `0 ≤ x < stoep` along a facade on `x` (inside the fence) is
  paved, `STOEP = ['#E8DAC4','#DDCDB5'][((x>>2)+(z>>2))&1]` — the garden's path along the
  hotel's back wall.
* `r.uitzicht`: what lies beyond the fence and can be seen from here. A `{soort: 'bad', x0,
  x1, z0, z1}` entry is drawn exactly like `r.bad` (edge, water, rim) plus a `TEGEL` deck of
  16 voxels round it that stops at the fence line — the pool behind the garden's back fence
  (water `x 24..124, z −36..−4`), so the garden's exit to the pool shows the pool.

**Walls** (`bouwWand`, only for rooms with `wand > 0`; the tuin has none): both back walls
are drawn as flat quads on the baked floor plate. Wall `z` (running along x, facing +z)
uses `#DFC6A8` with band `#E9D4BA`; wall `x` uses `#EDD8BC` with band `#F5E5CE`. Every
segment gets a skirting `y 0..3` in `#C08F6B` and a rail `y 9..10.4` in the band colour.
Door openings (`poort` doors excluded) are cut to height `Rooms.deur_hoog()` =
`min(wand − 6, 26)`. **Every opening shows the room it leads to** (owner 2026-09-23: "geen
mooie overgang die sprekend is"; the HTML drew one dark hole `#7A6250` for every door):
the floor behind the wall in the destination room's own 4×4 tile colours, clipped to what
the opening lets through (a floor point (x, z) behind the `z` wall shows when
`a ≤ x − z ≤ b` and `−z ≤ hoog`, the `x` wall likewise with x and z swapped), centred on
the destination's `kijk` point (its middle by default; the reception, the kitchen and the
laundry aim theirs at their rug, runner and bath mat so rooms with the same floor still look
different). Indoors the view is darkened 16 % towards `#6E5A4A`, from the lawn into the
hotel 36 %; a view onto a lawn is lightened 8 % towards `#FFFBEF`. Over it: the threshold
`#C9A27E` inside the 3-voxel wall, the one jamb the viewer can see (the left one in the `z`
wall, the right one in the `x` wall, in the wall colour darkened 12 %), a lintel shadow
fading from 38 % to 0 over 11 voxels (half that outdoors), and the frame of `HOUT_D #B98F62`
posts 1 voxel wide plus a `HOUT #D0A87A` lintel 1.4 high — `#E6DDCC` / `#FBF7EE`, white,
when the door leads outside. `tests/test_rooms.gd` holds every door to it: each view shows
a colour its own room does not have, no two doors of a room look alike, and no fixed decor
hides more than 3 % of an opening.
**Glass walls** (`Kamer.glas`, the kas, R3 — games-c.md §1.3): the same two planes, drawn
as a brick knee wall `#C98B6B` (y 0..6, top course `#B67858`), panes that show the
garden's green `#BCDDB7` low down fading over 14 voxels into light glass (`#CFE7E3` on the
z wall, `#DCEFEB` on the x wall), white glazing bars every 12 voxels, a transom at y 22 and
a white cap; the jamb of a door in a glass wall is white.  A door INTO a glass room has a
white frame and no folded leaf, and seen from the lawn its view is darkened 16 %, not 36 %.
The wall top cap is `#FCF0DE`, 3 voxels deep. A 10 %-alpha `#6E5A4A` shadow strip 4 voxels
wide lies where each wall meets the floor. A radial vignette
(`rgba(120,96,70,0)` → `.18`) is painted over the whole plate.
The tuin instead fills the plate with `#AAD190` and tiles diamond cells of 4 voxels out to
8 voxels beyond the frame, so the lawn runs on past the edge.

**The facade** (`r.gevel = {wand: 'x', hoog: 34, stoep: 8}`, the tuin since 2026-09-23): the
hotel's back wall on `x = 0` from `z = −6` to `z = 400` — no end of the building is ever in
view — in plaster `#F3E2C9` on a `#CDB195` plinth (`y 0..3`) with a `#E6D0B1` band in the
shadow of the eaves (`y hoog−3..hoog`), a shadow strip on the paving at its foot, and a
roof of 44 rows of 4 voxels at 45° (`#E79C7C` / `#DA8C6D`) from eaves that stick out 3
voxels (`#B7876C` fascia) back and up out of the picture. The facade's doors are cut like
indoor doors; the kitchen door also shows its open leaf folded flat against the wall
beyond the opening (sage `#93C19C`, panel `#7BA986`, a four-pane window `#DDF0F4` and a
brass knob `#F2C14E`), and wears the `luifelz` awning and the `deurmatz` doormat.

### 1.5 Derived data (`bouwAf`, recomputed after every furniture change)

* `r.box` — see §1.1.
* `r.deurPunten` — see §1.2.
* `r.vrij` — the **free-cell grid**: `x, z` from `marge` to `w−marge` / `d−marge` in steps
  of 12, with `marge = 12` (18 for the tuin, `erf`). A cell is dropped when the Manhattan
  distance is `< 18` to any decor item or slot, `< 14` to any door's inside point (and, port,
  the front door's, §1.2), or
  (pool only) when `z < bad.z1 + 6`, or (port, R3) within 3 voxels of one of the room's
  `mijd` rectangles — the floor a game's table or scale stands on (only the kas has them;
  a bought piece of furniture keeps 4 voxels from them, `_bezet`). Ids are
  `'v' + x + '_' + z`, soort `'vrij'`.
* `r.plekkenLijst` — the **wander places**: walk `r.vrij` in order and keep a cell only if
  it is ≥ 22 (Manhattan) away from every kept cell. If nothing survives, `[[w/2, d/2]]`.
* Every slot gets its **standing place** `sx, sz` (`afSlot`):
  * `bed`: normal bed → `(x + 2, z + 12)`; rotated bed (`draai` or `model === 'bedz'`) →
    `(x + 12, z + 2)`;
  * `bak`: `(x − 13, z)`;
  * anything else: `(x, z)`.
* **Port (2026-09-24): the walking grid** (`World.looppad_rooster(kamer)`, `wereld/looppad.gd`;
  owner: "Dieren lopen ook vaak door objecten heen als ze naar andere maps toe lopen en ik ze
  volg"). It is NOT derived here once: it is read from what stands on the floor of the room
  *right now* — `Rooms.hindernissen(kamer)` (every decor piece that is not `ver` and not a
  grass tuft `pol`; every slot: a bed as its model, a bowl as `kom` on `Art.KOM_ANKER` — a
  bought `bakje` too — the tub; the pool's `bad` as a floor rectangle; the desk `balie` and
  the strip behind it back to the wall), plus the movable things standing in the room (the
  trolley, the desk lamp) and the games' loose decor (`World.decor`, not `ver`). `World`
  keeps one grid per room and rebuilds it (≈ 5–10 ms) whenever that list changes — bought
  furniture, a pushed trolley, a game's stall — the list itself is the cache key.
  * A piece blocks the voxel columns in which it has a voxel between `VLOER = 2` and
    `KOP = 12` over the floor (its own `y` included, its `rot` applied). Flat things (a
    doormat, the hopscotch stones, a threshold) lie under a guest's paws; what hangs over
    his back (the garland, a tree's crown, a parasol's canopy, the bar over a gate) is no
    wall.
  * Cells of `CEL = 2` voxels: **DICHT** when a blocked column lies within `HARD = 3` of the
    cell's middle (so every point of a cell that is not DICHT is ≥ 2.5 voxels from every
    footprint), **KRAP** within `RUIM = 6`, or within `RAND = 4` of the room's edge, else
    **OPEN**. A* runs over nodes of `KNOOP = 4` voxels (2 × 2 cells, the worst class).
  * The free-cell grid `r.vrij` and the wander places `r.plekken` above keep their own
    Manhattan rules; a wander place is only walked to when its cell is not DICHT and it is
    reachable (§2.6).

**Fixed slots.** Only kamer1 and kamer2 have slots, identical in both:
`bed1 = bed @ (30, 27)`, `bed2 = bed @ (30, 75)`, `bak = bak @ (84, 33)`.
The tuin has one slot `tobbe` (soort `vrij`) at (32, 94). So the hotel starts with
**4 beds → `maxGasten() = 4`**.  **Port (owner 2026-09-17):** kamer2 has `bed1 = bedz @
(18, 30)`, `bed2 = bedz @ (52, 30)`, `bak @ (96, 84)`; since 2026-09-24 the guest cap counts
the bed places below, not the beds (games-a.md §3.2).

**Bed places (port, owner 2026-09-24: "De eerste twee bedden zijn goed geplaatst, daarna
gaat alles door elkaar").** A bedroom names the places its beds stand on, in order
(`Kamer.bedden`, `Rooms.bed_raster(k)`), and how they all lie (`Kamer.bed_model`,
`Rooms.bed_model(k)`): kamer1 `bed` at `(30, 27)`, `(30, 75)`, `(84, 54)`, `(84, 98)`;
kamer2 `bedz` at `(18, 30)`, `(52, 30)`, `(18, 78)`, `(52, 78)`.  The first two are bed1
and bed2.  Every place holds a whole bed (`Rooms.bed_vlak(model, x, z)`, the model's own
voxels: `bed` −17..16 × −8..8, `bedz` the other way round) with a voxel of air to the next,
on no floor decor, slot or door step (20 × 20 round `ix, iz`), with its standing place
(`Rooms.bed_sta`, as `afSlot`) inside the room and on nothing — `tests/test_rooms.gd`
holds all of it.  `Rooms.vrije_bedplekken(k)` = the places with no bed and nothing else on
their floor now.  Around every bed no free cell lies within 3 voxels of its floor (its ends
reach past the Manhattan 18 above) and no bought piece within 7 (`bezet`).  Every other
room has no bed places.

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
| check-in card / bill card `CI_PLEK`, `WERKPLEK` | `plek('receptie', 0.875, 0.25)` | (105, 30) — **port:** the check-in card hangs at the guest's `BALIEPLEK` (owner 2026-09-23) |
| its height `CI_HOOG`, `WERKHOOG` | `hoogte('receptie', 0.2)` | 24 |
| counter `TOONBANK` | `plek('receptie', 0.15, 0.5)` | (18, 60) |
| its height `TOONHOOG` | `hoogte('receptie', 0.225)` | 27 |
| guest waiting spot `WACHTPLEK` | `plek('receptie', 0.2, 0.95)` | (24, 114) — **port:** unused; see `BALIEPLEK` |
| **port:** guest at the desk `BALIEPLEK(i)` | x = middle of `Kamer.balie` + `[0, +20, −20][i % 3]`, z = `balie.z1` + 17 + 2·(i % 3) | (65, 44), (85, 46), (45, 48) |
| "needs a bed" spot | `plek('receptie', 0.375, 0.775)` | (45, 93) |
| "klaar met tellen" button | `plek('receptie', 0.775, 0.275)`, `hoogte(0.175)` | (93, 33), y 21 |
| room hint during check-in | `plek('receptie', 0.775, 0.05)` | (93, 6) — **port:** at the door the way to that room starts with |
| task cards `i = 0,1,2` | `plek('receptie', 0.075 + i·0.325, 0.025 + i·0.325)` | (9, 3), (48, 42), (87, 81) — **port:** on the prikbord sheet, no place in the room (§3.7) |
| day messages `i = 0,1` | `plek('receptie', 0.375, 0.5)`, `hoogte(0.375 + i·0.15)` | (45, 60), y 45 / 63 — **port:** on the prikbord sheet |
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
   (`bezet`: Manhattan < 15 to a slot or decor item, < 12 to a door's inside point or the
   front door's), snap
   to the nearest **free** grid cell (`naarRaster`); if `x`/`z` are omitted, snap from the
   room centre;
3. if the chosen cell is still occupied → return `null` (never a half-placed item);
4. decor types are pushed into `r.decor` with `meubel: id`; `bed`/`bakje` are pushed into
   `r.slots` (a bed with odd `rot` uses model `bedz` and `draai: true`), then `bouwAf(r)`
   runs again so standing places, free cells and wander places are up to date.
   **Port (2026-09-24):** a bed in a room with bed places (§1.5) skips steps 2–3: it goes on
   the free bed place nearest to `(x, z)` — the first free one when `x`/`z` are omitted —
   with the room's model (`rot` becomes 0 for `bed`, 1 for `bedz`), or returns `null` when
   every place has a bed.  A saved bed that stood anywhere comes back on a bed place.  An
   `id` that already exists somewhere gets a fresh one (never two pieces under one id).

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
`wacht`, `zwem`, `spring`, and (port) `komt` — coming in through the front door (§2.5). The tick rate is **15 Hz** (`STAP = 1000/15`), at most 3 catch-up
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
| `World.blijf(id, na)` | **port:** stay where you stand and take end state `na` (default `wacht`) in this frame — what `ctx.wacht_op` (§5.3) gives the animal of a turn once he is at his place, so he does not wander off from under the card |
| `World.loopNaar(id, x, z, o)` / `World.stappen(id, punten, o)` | **promise-based** movement |
| `World.pose(id, naam, duur)` | set one pose; `true`/`false` |
| **port** `World.kom_binnen(id, x, z, kamer = 'receptie')` | the guest arrives at the hotel: he appears on the threshold of the room's front door (`Rooms.ingang`, §1.2) and plays his own entrance to `(x, z)` (state `komt`, art-sound-rules.md §11.8), ending there in `wacht` as `ga(id, x, z, 'wacht')` would. Not awaitable. Reduced motion, or a room without a front door: he simply stands at `(x, z)`. Off screen the arrival is skipped to its end; any other order above supersedes it (a guest in mid-hop lands at once) |
| **port** `World.komt_binnen(id)` / `World.ingang_open(kamer)` | is he still coming in? / does the front door stand open — always, for the lobby's open outline (`ingang.open`); a front door with a leaf stands open from the start of an arrival until he is 22 voxels clear of the threshold, 3 s at most |

`na` values on arrival: `eet`, `sip`, `wacht`, `snuif`, `blij`, `slaap`, `deur`, anything
else → `stil` for `round((10 + r()·40) · rustig)` ticks.

**Port (2026-09-24): an order that supersedes a journey ends its doors too.**  Every new
order above clears the door route along with `reis_doel`.  Before, a guest who was sent
back to the desk (`ga`) halfway to his room kept the doors of that first walk, and the new
walk ended with a step through one of them — he turned up in the corridor (found by the
beds game's `⬅ Terug`, games-a.md §3.6).

**Port (2026-09-24): every walk goes round what stands in the room** (`World.looppad(kamer,
van, naar)`, the grid of §1.5). Every leg a guest WALKS inside a room — `ga`, every point of
`stappen`/`loop_naar`, the leg to the next door of a `reis` (door step `ix, iz` to door step),
the last leg to the asked point (a bed's standing place, a bowl's eating spot, a game's
place), `mood`, `solo`, idle wandering — is the way A* finds over the grid, eight neighbours,
at a cost per voxel of 1 (OPEN), 1.5 (KRAP) and 200 (DICHT), then pulled straight: from every
corner kept, straight on to the farthest corner whose line runs no further through DICHT cells
than the path it cuts off and costs at most 1.25 × as much, sampled every half voxel. So a
guest walks natural diagonals round the beds, the desk, the plants, the stalls and the
trolley, and never closer to a piece than the grid path went. A straight line over OPEN cells
only is walked as it is (one point). DICHT is expensive, never forbidden: a goal inside a
piece (the bed's own point) is reached the shortest way in, and a guest who stands in
something (woken on the mattress, a piece put down on him) walks out the shortest way — out
of the water too, which replaces `Rooms.om_het_water` (kept as the fallback when a room has
no grid). **Not** routed: `pose: 'zwem'` and `'spring'`, a walk with `perStap` (it counts its
own points), and reduced motion (he is put on the last point anyway). The travel bar of a
journey (`World.reis_voortgang`) counts the leg's real length round everything
(`been_lengte`), so it still only climbs.

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
**Port (2026-09-24):** first skip a place whose cell of the walking grid (§1.5) is DICHT —
kamer 1's four places at the ends of its beds, the keuken's three under the trolley — or that
cannot be reached without squeezing through something (the fallback "first candidate" is
then his own spot, so he stays where he is). A guest who stands IN something — the kraam's
customer spot lies in the counter's footprint — counts as standing on the nearest free floor
around it, where he walks out to. The walk there goes round things like every
walk (§2.5).
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
that room the animal steps into the bed regardless of what `na` said — since 2026-09-23 it
**hops** in (owner: "een animatie dat het dier op het bed springt wanneer je een vrij bed
kiest"): the hinkel's own jump arc from the floor at the standing place to the bed's own
point, at tempo `BED_SPRONG_TEMPO = 0.7` and `BED_SPRONG_EXTRA = 4` voxels over the kind's
`SPRING_HOOG`, landing on `MATRAS` with the usual squat, a `Snd.hup()` at take-off, and only
then `inBed`. With reduced motion, and when it is already in the room (a load, a test),
it still lies down at once.

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
**Port:** while the camera follows a guest (`👀 Volg`, §6.3) his plate reads `👀 <naam>`
(`Ui.zet_plaat_teken`).

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
| `souvenir` | **port (2026-09-24):** the middle of the arcade's zone `kraam` — the floor in front of the souvenir stall → winkels (118, 34), where its customer stands; fallback tuin near (106, 58). (Until 2026-09-24: the point in front of the garden's `kraam` zone, `voorRand` → tuin (96, 52).) |

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
* no bedroom can take one more guest → soft sound and a bubble at the bell: icon 🛏,
  number `maxGasten()`, text `alle kamers vol` (the HTML: `alle bedden vol`), class
  `hulp`, height 26, removed after 3200 ms.
  **Port (owner 2026-09-24: "Je moet bij bellen van het dier een kamer voor het dier
  kiezen"):** the guest cap is the free FLOOR, not the free beds.  `State.plek_voor_gast()`:
  some bedroom (a room with a bed, `State.slaapkamers()`) has a free bed, or free floor
  where a whole new bed fits (games-a.md §3.2) and fewer than `State.MAX_BEDDEN` (6)
  beds — in the two base rooms five beds a room, ten guests.
  `maxGasten()` = every bed plus every bed the check-in may still put down.  The same
  rule decides the bell button (§6.3) and the board card (§3.7);
* otherwise: close the prikbord, take the next guest, compute
  `geld = sommen.geld(band)` and store `nachten`, `prijs`, `betaald`, `dagIn = dag`;
  reset `kamer/bed/behoefte/geslapen/gegeten/blij`; put the guest in `state.nieuweGast`;
  build the check-in; `Snd.bel()`; place the guest at the gang door of the receptie and
  walk it to `WACHTPLEK` (24, 114) with `na: 'wacht'`; go to the receptie; paint;
  toast `<naam> staat aan de balie! 🔔`.
  **Port (owner 2026-09-23):** the guest walks to `BALIEPLEK(0)`, on the floor in front of
  the desk — `WACHTPLEK` is the far corner by the bench, and the guest "at the desk" waited
  there while its card hung at the desk.  The bill (§3.5) walks the guest to the same spot,
  and a reload puts a pending guest there.
  **Port (owner 2026-09-23, "die komen momenteel vanuit de gang binnen ipv ingang"):** a
  guest who arrives comes from OUTSIDE, through the receptie's front door (§1.2), not out
  of the corridor: `World.kom_binnen(id, BALIEPLEK(0))` puts him on its threshold and he
  makes his way round the end of the desk to the counter with an entrance of his own kind —
  the puppy bounds, the cat slinks and stretches, the rabbit hops, the goose waddles
  flapping (art-sound-rules.md §11.8), three to four seconds.  Nothing waits for him: the
  check-in card is up at once, as before, and a check-in that ends while he is still on
  his way sends him to his bed.  The families of §3.5 do not walk — they are the `👪` bubbles at the desk
  and the guest they fetch walks down from his own room — so check-out is unchanged.

**Check-in state** (`state.checkin`): `{gastId, samen, extra, nieuw: samen+extra,
dagen: state.levering, voorraad: state.scoops, stap: 1, fouten1: 0, fouten2: 0, invoer: '',
keuze: null, weg: false, t0}` where `samen = Σ scoops of the current guests` and
`extra = the new guest's scoops`.  **Port (2026-09-24):** plus `kamer: ''`, the room of
step 3; `stap` runs 1 (samen) → 2 (genoeg) → 3 (the room) → 4 (the beds game).

**Step 1 — "Samen?"** One sum card at (105, 30), height 24 (lifted when the frame is under
300 px high, by `ceil(20/(2k))` height steps), icon 🥄, with two lines — **port:** the card
aims at `BALIEPLEK(0)` and keeps the box the guest has THERE free (`volg` returns that box),
so it hangs by the guest without walking in with it from the door:

> `De gasten eten <n> schep|scheppen per dag`
> `<naam> eet <extra> erbij. Samen?`

Sum text `"<samen> + <extra> ="`, open keypad, max 2 digits.
After a wrong answer (`fouten1 > 0`) the help line is the spoon rows
`scoopjes(samen) + ' + ' + scoopjes(extra)` where `scoopjes(n)` is `n` spoon emoji for
`n ≤ 8` and `"<n> 🥄"` above that (0 → `"0"`).
Correct → `Snd.ja()`, toast `Precies! 🎉`, `State.tel(fouten1 === 0, elapsed)`, step 2.
Wrong → `Snd.zacht()`, toast `🥄 Tel ze samen`, `fouten1++`.
Empty input → toast `👆 Tik eerst een getal`.
**Port (owner 2026-09-24: "Nee geef geen hulp na fouten. Kinderen moeten zelf leren
rekenen. Fout antwoord kiezen moet niet beloond worden met hulp maar juist een
teleurgesteld dier"):** after a wrong answer the card gets NO help line (the spoon rows
are gone) and there is no hint toast; the guest at the desk is disappointed instead —
`Ui.misser` with the guest as the card's animal: he goes `sip`, `🔄 Nog een keer` hangs
by him, the strip is shut for `MIS_PAUZE` (1,2 s) — `Snd.zacht()`, `fouten1++`, and the
SAME card with the same four numbers stays up.  When the sad pose cut his walk to the
desk short, he steps back to his place afterwards (`Hotel._naar_balie`).

**Step 2 — "Genoeg?"** Same card, no keypad, one choice strip. Lines:

> `Elke dag <nieuw> schep|scheppen, <dagen> dag|dagen lang`
> `📦 In huis: <voorraad> schep|scheppen. Genoeg?`

Sum text `"<dagen> × <nieuw>"`, and after a first mistake `"<dagen> × <nieuw> = <product>"`
(**port, owner 2026-09-24:** never — the product is not written out after a slip).
Choice strip title `is er genoeg eten?`, three buttons:
`⬇ te weinig` (= `meer`), `⚖ precies`, `⬆ blijft over` (= `minder`).
The frozen comparison is `vergelijk(v)`: `dagen · nieuw > voorraad` → `'meer'`,
`<` → `'minder'`, `=` → `'precies'`. Correct → `Snd.ja()`, toast `Goed gerekend! 🎉`,
`State.tel(fouten2 === 0, elapsed)`, step 3. Wrong → `fouten2++`, `Snd.zacht()`, toast
`🥄 <dagen> × <nieuw> = <product>` (**port, owner 2026-09-24:** no toast with the answer;
the guest is disappointed, `Ui.misser`, and the same question stays, as in step 1).

**Step 3 — the bed** (the HTML).  A bubble over the guest: icon 🛏, text `Kies een bed` (or
`Alles bezet`), tapping it travels to the room of the first free bed, a second bubble at the
door shows that room; tapping a free bed calls `wijsBed`; tapping an occupied bed → toast
`<naam> slaapt hier. 💤`; a free bed without a check-in → toast `🛏 Bel eerst een gast`.
**Port (owner 2026-09-24): all of that is gone** — "En het moet heten "verdeel bedden over
de kamers" met kamer 1 en kamer 2 waar de bedden geplaatst moeten worden op basis van waar
het dier gaat slapen. Je moet bij bellen van het dier een kamer voor het dier kiezen en
daarna moet dat spel plaatsvinden op basis van hoeveel dieren je hebt op basis van welke
kamers ze zitten".  No bed has a button (§6.3).

**Step 3 (port) — the room.**  The same card at the desk, no sum: `🛏 Welke kamer voor
<naam>?` (4 words, 28 characters on `Stampertje`), a strip of the bedrooms where one more
animal fits (`State.kamers_met_plek()`), each `🛏 Kamer 1` (short `🛏 1`), title
`kies een kamer`.  A tap: `Hotel.kies_kamer(k)` → `checkin.kamer = k`, `stap = 4`, save,
and the game `bedden` starts (games-a.md §3).  A registry without that game (a narrowed
test) gives him the room's free bed, or a new one, at once — the check-in never gets stuck.
With no room left (the floor filled up with furniture while he waited) he goes back to the
front of the waiting list — never lost — and the bell says `alle kamers vol`.

**Step 4 (port) — the beds: "Verdeel bedden over de kamers"** (games-a.md §3).  At the desk
`<In kamer 1> slapen al <n> dieren` / `<naam> komt erbij. Hoeveel bedden?`, `<n> + 1 =` and
four numbers; the room gets that many beds, he walks there with the camera along, and a
right answer ends the check-in, a wrong one brings him back to the desk and to the same
question.  While the game runs, `paint_checkin` paints nothing (the game owns the desk).
`⬅ Terug` (any stop before the right answer) and a reload: `Hotel.checkin_terug()` /
`paint_checkin` see step 4 without the game, the guest walks back to his place at the desk,
`stap = 3`, and the room question hangs there again.

**The end — `Hotel.wijs_bed(kamer, bed, o)`:** set `kamer`/`bed`, move the guest from
`nieuweGast` into `gasten`, recompute the band, `World.slaap`, `behoefte = 'eten'`, clear
the check-in, `Snd.tover()`, **one star** (`Econ.sterren(1, 'checkin')`), tick off the `bed`
task, flip `ochtend → vrij`, save.  The beds game passes `{loop: true}`: he WALKS to his
bed, the camera walks along, and the game shows `💤 <naam> doet een dutje` (class `goed`)
once he lies in it.  Without `loop` (the fallback): travel to that room and the bubble
`💤 <naam> doet een dutje` for 3600 ms, as the HTML did (the HTML said `welterusten`).  An
occupied bed → toast `💤 Hier slaapt iemand`, nothing else happens.

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
count, coins, checkout count, room for a guest yes/no (**port 2026-09-24:** `plek_voor_gast`, was
"free bed"), pending guest, every game task id+text, and
per guest `id:bed:behoefte:gegeten:blij`, and every bowl level).

Hotel tasks, in this order:

| id | icoon | tekst | kamer | actie | when |
|---|---|---|---|---|---|
| `bel` | 🔔 | `Bel een gast` | receptie | `bel` | room for a guest (§3.3) and **no** guests |
| `bel` | 🔔 | `Nog plek voor een gast` (HTML: `Nog een bed vrij`) | receptie | `bel` | room for a guest and guests present |
| `bed` | 🛏 | `<naam> wil een bed` | receptie | `bel` | a guest without a bed |
| `voer` | 🍪 | `Vul de voerkar` | keuken | `game:voerkar` | a room with guests has an empty bowl |
| `uit` | 💰 | `Reken af: <naam>` | receptie | `avond` | `uitcheck` not empty |
| `spelen` | 🧶 | `<naam> wil spelen` | that guest's room (else kamer1) | `kamer` | a guest wants to play |

All hotel tasks have `prio = 0`. Game tasks come from `def.taak` (or the default table
`SPEL_TAAK`: `voerkar → none`, `tobbe → {id:'bad', prio:1, 🛁, "<naam> wil in bad"` /
`"Tobbe-tijd"}`, `bedden → none` (**port 2026-09-24:** it is step 4 of the check-in; the HTML
had `{🛏, "Zet de bedden op rij", when ≥2 guests}`),
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

**Port (owner 2026-09-23): the board is a sheet.** "Plaatjes als [de receptie met het open
bord] zijn veel te druk in iconen. en wekker zetten is bijvoorbeeld helemaal niet relevant
aan waar de tekst geplaatst is".  A card is about a room somewhere else in the hotel, so no
place in the receptie is its right place: `Hotel.toon_bord()` opens `Ui.prikbord_blad()`
(`ui/prikbordblad.gd`) — title `📋 Prikbord`, hint `Tik op een taakje om erheen te gaan.`,
the cards as paper notes on cork (pictogram, the task in bold, under it where it is done:
`in de keuken`, `in kamer 1`, `bij het zwembad`; a done card ✅ on mint), under the cork at
most two day messages, and `Sluiten`.  With no cards: one note `🐾 Speel lekker rond` that
closes the sheet.  Below a 450 unit screen the notes stand side by side.  Nothing of the
board hangs in the room any more; the 📋 button on the board and its badge stay.  A tapped
note runs `doe_taak` (the sheet closes, round → `vrij`, travel, action); `Sluiten` or a tap
beside the sheet closes the board.  The board opens wherever the child is (it no longer
travels to the receptie first), it never replaces another sheet — behind the start screen
it waits until that one closes — and a card that changes while it is open rebuilds it
without the pop-in (`stil`).  The notice board itself hangs on the back wall again, left of
the desk, at (12, 1).

**Card layout (HTML).** Up to three bubbles at (9, 3), (48, 42) and (87, 81), height 22, prio 10,
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
promises. `Ui`/`Hits`/`World` hold no persistent state. `speler` — the animal the child
picked on the game bar (§5.8) — lives in `State.s` for the session only: it is written
along with the rest, but `State.lees()` keeps only the fields of this table, so a reload
(and a new game) forgets it.

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
| `hotspot` | optional | `{obj, icoon, label, hoog, dx, dz, blijf, rust}` — the entry button; `rust` names the resting prop it hangs on |
| `modellen` | optional | `{naam: builder}` — the game's own models, registered at the scan; the builders are STATIC (a function of the game's script, `Callable(get_script(), …)`), because the scanned instance is freed |
| `rust` | optional | loose decor entries `{id, model, x, z, y?, params?}` that stand in the room whenever the game may be played and NO game runs (owner 2026-09-23: "Dan hangt elk spel aan iets wat je echt ziet"); owner `rust:<id>`, put down and taken away by `hersteek`, all of them cleared when any game starts |
| `kan` | optional | **port:** `func(s) -> bool` — has the game something to do right now?  Absent = yes.  False hides the entry button and the game's task card (`Games.speelbaar_nu`): a game that would only say "vol ✓", "Alle bakjes vol!" or "Nog geen munten" is an action that cannot be carried out (owner 2026-09-23: "actions ... are available ... but when you click on them you can't execute them ... this provides visual clutter").  STATIC like `taak.wanneer` (autoloads and literals only).  bedden (2026-09-24): a check-in stands at its beds (step 4, with a room); voerkar: `Hotel.lege_bakken()` not empty; meubels: coins, a star, or something still to place |
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
button must hang on a **fixed** object, not on the game's own loose decor. It is placed
`aan` the resting prop `hotspot.rust` while that stands (the first hopscotch stone, the
stall's counter, the pile of washing, the corridor clock, the blanket chest), else on
`hotspot.obj` when `|dx| + |dz| ≤ 8`, else on the band grid at its aim point.  Before the
clock and the chest, "⏰ Wekker" hung on the paw poster and "🛏 Bedden" on the play basket,
next to that basket's own "Speelmand" — two names on one thing (owner 2026-09-23).

Currently registered games:

| id | naam | kamer | hotspot obj (icoon) | unlock | wens | taak |
|---|---|---|---|---|---|---|
| `voerkar` | De voerkar | keuken | `kar` 🛒 | N ≥ 1 | – | (hotel task `voer`) |
| `bedden` | Verdeel bedden over de kamers | receptie | none — step 4 of the check-in (§3.3); `hotspot` carries only 🛏 for the game bar, no `obj`, no `rust` (the blanket chest `rust_bd_kist` went with the old entry, 2026-09-24) | always (the first guest checks in with N = 0) | – | none |
| `sleutels` | Het sleutelbord | receptie | `sleutelbordz` 🔑 | N ≥ 2 | – | default `sleutels` |
| `tobbe` | Tobbe-tijd | tuin | `tobbe` 🛁 | N ≥ 1 | (`bad` via `WENS_SPEL`) | `bad`, prio 1 |
| `meubels` | Het meubelboek | receptie | `boek` 📖 | N ≥ 3 | – | default `meubels` |
| `zwembad` | Zwembad | zwembad | `mat` 🏊 | N ≥ 1 | `zwemmen` | `zwemles`, prio 1 |
| `wekker` | Wekkerdienst | gang | fixed decor + offset ⏰, resting on `rust_wk_klok` — the corridor clock itself at 7 o'clock | N ≥ 1 | – | `wekker`, prio 3 |
| `hinkel` | Hinkelpad | tuin | `hok` 🪨 (offset), resting on `rust_hk_steen0` — band 3's eleven plain stones | N ≥ 1 | `spelen` | prio 2 with a waiting guest, else 5 |
| `was` | Wasmandtoren | wasserij | `tobbe` 🧺 (offset), resting on `rust_was_berg` — the pile at (60, 54) | N ≥ 1 | – | `was`, prio 8 |
| `kraam` | Souvenirkraam | winkels (since 2026-09-24; was tuin) | `souvenirkraam` 🎁 Souvenirs — the fourth stall of the arcade, fixed decor, no resting prop (its goods stand on the counter at rest, like the other shops', games-d.md §4) | N ≥ 1 | `souvenir` | `souvenir`, prio 1 |
| `oogst` | Aardbeien plukken | kas | `aardbeienbakz` 🍓 (offset), resting on `rust_og_tafel` — the picking table with five empty punnets (games-c.md §2) | N ≥ 1 | – | `oogst`, prio 6 |
| `weeg` | Groenten wegen | kas | `pompoenen` ⚖️ (offset), resting on `rust_wg_schaal` — the level balance and its row of weights (games-c.md §3) | N ≥ 1 | – | `weeg`, prio 7 |

### 5.2 Lifecycle

`Games.start(id)`:
1. if another game is open → `stop()` it first;
2. `actief = id`, `actieveKamer = def.kamer`; **port:** `Games.beurt()` counts one more
   start (every `ctx.wacht_op` of an earlier start is over), and a walk along with a
   guest (`👀 Volg`, §6.3) ends — the camera is the game's now;
3. close the prikbord;
4. `Hits.voorrang(id)` — from now on this game picks its screen positions first, the
   hotel's buttons give way, the wish bubbles disappear, and the loose decor of every
   *other* registered game is removed.  **Port (owner 2026-09-23):** one hotel element
   stays — the "komt eraan" bubble of the animal the game waits for (`ctx.wacht_op`),
   which the hotel marks `data.spel = <id>` (§6.3);
5. `Hotel.render()`, `hersteek()`;
6. travel to `def.kamer` if not already there;
7. call `def.start(ctx)` inside a `try`; a throw resets `actief = null` and toasts
   `💛 Probeer iets anders`;
8. if the game moved the camera itself, `actieveKamer` is updated to the room actually in
   view and the hotel re-renders (so the wish bubbles hide in the right room).

`Games.stop()`: clear `actief`, call `def.stop()` in a `try`, `Hits.wisEigenaar(id)` (which
also returns every borrowed button), `Hits.voorrang(null)`, `Ui.leegPaneel()`,
`hersteek()`, `Hotel.render()`. **Port:** nobody is awaited any more, and a walk along with
the animal it waited for ends where the camera is (the room bar comes back there).

**Supersede** = starting another game: exactly the sequence above, so a game never has to
detect it — its `stop()` runs, its hotspots, bubbles, cards, number tags, sources and loose
decor are removed for it. Promises from `stappen` resolve `false`.

**Switching the animal** (§5.8) is a supersede of the running game by itself:
`Games.wissel_speler()` writes the next animal into `State.s.speler` and calls
`Games.start(id)` for the game that runs, so the unfinished turn goes with every timer,
walk, card and prop of it, and the new `start(ctx)` builds a fresh turn for that animal.

**Evening**: `Hotel.avondronde()` sets the round, turns the desk lamp model into `lampaan`,
closes the board and paints the checkout bubbles. It does **not** stop a running game; the
game keeps its priority until it stops itself.

### 5.3 `ctx`

One ctx per game, built once and cached. `ctx.id`, `ctx.naam`, `ctx.kamer`.

`ctx.wereld`: `kamers()`, `kamer(id)`, `pad(a,b)`, `slots(kamer, soort)`,
**port (2026-09-24):** `verberg_bed(kamer, slot, aan)`, `bed_verborgen(kamer, slot)`,
`toon_bedden(kamer?)` — a FREE bed out of sight for a while (bedden: the room holds exactly
the beds the child asked for); hidden beds come back the moment the camera leaves their
room, and nothing is saved;
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

The animal of the turn (§5.8): `ctx.voorkeur(kandidaten)` → the animal the child picked
(`State.s.speler`) when it is one of `kandidaten` and still a guest, else `""`;
`ctx.speelt(gastId)` → this game's animal of the turn is now `gastId` (the game bar shows
it; call it whenever the turn takes or moves on to an animal); `ctx.wissel_speler()` →
`Games.wissel_speler()`; `ctx.laat_gaan(gastId)` → the animal whose unfinished turn the
pick dropped makes room (§5.8).

**Port (owner 2026-09-23): waiting for the animal.** `await ctx.wacht_op(gastId, plek, o)`
→ `bool`: the game begins when its animal is there ("Zorg dat de minigame pas begint
wanneer het dier er is", §5.8). `plek` is his place in the game's own room (voxels);
`o = {na: 'wacht', tempo: 1, marge: 3}`.

* It **sends** him — `World.reis` through the doors, `World.stappen` inside the room —
  unless he is on his way there already (walking into this room, or inside it with his
  last point at `plek`): a guest who walks in keeps his route, so the bar of his "komt
  eraan" bubble never jumps back. `State` `waar` becomes the game's room, as the games
  always did when they sent somebody.
* **Already there** (within `marge` voxels, standing still): `true` at once, in the same
  call, without a frame in between. **Reduced motion** resolves every walk at once
  (§2.5), so there it is always at once.
* Otherwise it looks every **0.1 s** in the timer phase — where the games make their
  cards — and is `true` the moment he stands at his place. Whenever it is `true` he
  stands in end state `na` (`World.blijf`).
* Meanwhile the running game **waits for him**: `Games.verwacht_dier(gastId)` is true,
  the hotel keeps his "komt eraan" bubble with its bar and `👀 Volg` in view although
  every other hotel button steps aside (§5.2 step 4, §6.3), and `Hotel.volg` may walk
  along with him into the game's room.
* `false` when **this start** of the game is over — stopped, superseded, the animal
  switched (`Games.wissel_speler` is a fresh start; `Games.beurt()` counts the starts) —
  or when the guest is gone. A game checks `actief` after it anyway; a game that is still
  running when it gets `false` has lost its animal and closes itself.
* Nothing a reload would need lives in memory: a resumed turn simply asks again, and a
  guest the reload put somewhere else is sent again. A walk that another order took
  over (a wander, another game) is sent again after 1 s.

`ctx.is_er(gastId, plek, marge?)` → the same "is he there" test, for a game that wants to
clear its screen only when it will really have to wait.

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

**Port rules for `op: "aan"` (owner 2026-09-23: "Dit gebeurt vaak over het hele spel").**
A button that belongs to a thing tries, in order: ON the thing when it is big (the board),
right under it, right over it, and beside it (right, left) level with its middle — all
centred on the thing as it is DRAWN, not on its aim point (a bowl's plate stands well
right of its slot point).  Each place must touch no placed element and no other button's
thing; of those, the first that hides nothing of any OTHER thing in the room wins
(fixed decor, slots, movable things, loose decor, guests — a share of at least 15 % of that
thing counts), else the one that hides the least.  So "Sleutels" hangs over its key board
and not on the plant in front of it.  A **door** carries its sign ON itself, in ONE place
the same for every door in every room and state (owner 2026-09-24: "Kamer 2 staat onder de
deur maar kamer 1 boven de deur. Dit is geen consistente plaats"): centred on the door
opening at its half height (`Hits.deurbord_plekken`, `debug()[id].deurplek == "deur"`).
Only when a thing with a button of its own stands in that opening (the voerkar's trolley,
the corridor's clock, a guest with a name plate) or a neighbouring sign already hangs there
does it take its ONE fallback: straight over the door, just above its lintel
(`deurplek == "latei"`), with a second row one sign higher for the phone corridor, whose
four doors stand closer together than two signs are wide.  Never on the foot of the door,
never under it, never on the band grid (`deurplek == ""` fails the tests).  The heights are
fixed; sideways a sign is only pushed by the frame edge or slides past a neighbour or a
thing, and never so far that the middle of its door leaves it (`Hits.DEUR_RAND` = 8
units).  The signs of a room are chosen as ONE set (`_kies_deurborden`: the cheapest set of
heights that fits, all on the door first) and placed **before everything else**, fixed
cards and name plates included, so the other elements give way to them and not the other
way round: a name plate slides along its row (staying over its guest) before it steps a
band, and a band-placed element that finds no free block of cells left gets one more pass
with the real rectangles, sliding along each band (`_kies_plek`, pass 1c).  On its own door
nothing next to the opening counts.  In front of a door is where the
furniture stands (the bench, the chest, the ball pit, the ironing board); the opening is
kept clear of furniture (test_rooms).  An `aan` button chooses afresh every pass, also
after it once fell back on a band.  The desk the cards keep off is its pieces (the two
halves and what stands on them, `World.vlakken_van_balie`), not the box round the diagonal
desk, which was mostly the floor in front of the counter.  A fixed card (`midden`) that
would lie on its OWN thing steps beside it — under, over, right, left, the nearest free —
instead of climbing whole bands away; a card that only meets another element keeps its
column.  `Ui.wolk` and `Ui.bron` pass `op` and `obj` on, so a bubble or a source that is
about a thing can hang `aan` it (the coins on the meubels counter, the purse).

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
* **Port (2026-09-23):** `o.balk: false` keeps the card out of the maths bar
  (`Ui.balk_kandidaat` skips it): it stays by its own thing.  For a game whose layout
  hangs on one wall and must not jump when the world shrinks for the bar between two
  steps — the key board on a wide landscape frame (games-a.md §4.4 `wand`).
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
**Port (owner 2026-09-23: "de text van opdrachten staat soms ver van waar ik kan klikken
voor antwoorden"):** a floating card and its strip are placed as ONE pair (`Hits`): the card
takes the first place in its usual order (on its aim point, beside its own thing, whole
bands up and down, then two and four columns sideways) at which its strip fits right beside
it — under, over, right or left, `KLEEF` apart, clear of every placed element and object
box — and that place is kept for the strip.  Where the strip fitted before nothing moves.
When no such pair fits, both go down together onto the foot of the frame, the strip at the
bottom and the card straight over it.  A game that plans its card, its own row and its
strip as one layout says `somkaart(…, {paar: false})` and keeps the single-card rule: the
key board plans its hook row around where the card stands (`sleutels` `_kaart_rect`), and a
card moved by the pair broke that row in two on a phone.  The low bar (`vorm laag`) has room for one line of
words, so a card with a second line (`regel2`) is not docked there: it floats with its
strip (the check-in lost "📦 In de kast: … Genoeg?" in the low bar).  In the bar the strip
tries its long words first ("te weinig", "blijft over") and takes the short ones only when
the long strip does not fit its block.  In the tall bar (`vorm hoog`) the card's sentence,
second line, sum row and help line stand centred over the centred strip (owner 2026-09-24:
"De text onderaan is niet goed gecentreerd"); in the low bar the card is the left block
beside the strip and keeps to the left.  A toast stands just above the bar while the bar is
on, never over the answers.

A card, its pad and its choice strip are **fixed**: they never give way, everything else
gives way to them. Use at most one at a time.

### 5.6 Bubbles, sources and number tags

* `Ui.wolk(obj, {icoon, getal, tekst, hoog, klas, prio, tik, id, door})` — a speech bubble
  on an object or animal, default height 52 voxels on an animal and 20 on an object,
  default prio 9. Without `tik` a tap reads the text aloud (`Ui.spreek`, Dutch
  `nl-NL`, rate 0.95, pitch 1.05; silently does nothing when unsupported).
  It follows its animal, also into another room.
  **Port (owner 2026-09-23: "heel veel textboxen die allemaal klikbaar lijken dan is het
  niet meer duidelijk welke nou interactie hebben en welke niet"):** what you can press
  looks pressable, what only speaks does not.  Every button in the world (`Hotknop`,
  `Keuzeknop`, a source, the game bar) stands on a warm border (`UiThema.KNOP_RAND`) with a
  thicker key edge at the bottom (`KNOP_LIP` 5) and a small shadow, and pressing it pushes
  the edge in (`UiThema.knop_staten`).  A bubble WITH its own `tik` (`UiWolk.actie`: the
  "komt eraan" bubble with `👀 Volg`, a wish, "Alle bakjes vol!") wears the same key; a
  bubble without one is a **speech bubble** (owner 2026-09-24: "Hints als 'tik op een
  deur' of 'je duwt de kar' lijken erg op bubbeltjes waar interactie voor is"): the Button
  draws no face of its own, `UiWolk._draw()` draws body and tail as ONE shape — warm paper
  at `UiThema.INFO_VUL_ALFA` (80 %) with a thin soft outline (`INFO_LIJN`, ink at 35 %,
  1.5 units), small corners (`INFO_RONDING` 10) instead of the pill, no shadow, no key edge —
  and a comic tail (14 wide at its foot, 7–16 long) that points at what the bubble talks
  about: `Hits.plaats()` hands every `UiWolk` the point of its thing nearest to it, or its
  aim point (`UiWolk.richt`).  The tail is drawn outside the rectangle `Hits` placed, so no
  size and no placement changes.  Its words are regular weight (a `Label`, not the bold
  of a `Button`) and `INFO_KLEINER` (2 px) under a button's, never under 12 px; its
  pictogram is `icoon`, not `icoon_wolk`.  It is the same in every state, takes no focus and
  lets a tap through (`MOUSE_FILTER_IGNORE`).
  A button that SAYS a state wears the same quiet face (`UiThema.info_vlak`) while it is
  in that state: the voerkar's trolley is `🛒 Pak de kar` on its key edge, and held it is
  `🛒 Je duwt de kar` flat and quiet — still a toggle a tap turns off, still draggable.
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

### 5.8 The game bar and the animal of the turn

While a game runs, the room bar's row is the **game bar** (`ui/spelbalk.gd`, owner
2026-09-18): `⬅ Terug` first, the game's pictogram and name beside it, in the room bar's
exact footprint (under the frame, or as the rail beside it in the compact shell), so the
frame never moves. `⬅ Terug` is `Games.stop()`. The name hides when the row is too narrow;
the buttons never do.

**The animal of the turn** (owner, 2026-09-23: "een methode om te wisselen met welk dier
je de spellen speelt"). A game whose turn belongs to ONE animal gets one more button on
the bar, after the name: that animal as `<pictogram> <naam> 🔄` (`🐶 Boef 🔄`; in the rail
`🐶 🔄` over `Boef`, so it keeps the rail's 152 units), title `Speel met een ander dier`.
The pictogram is the hotel's own per kind (`Hotel.DIER_ICOON`: 🐶 🐱 🐰 🦆, else 🐾). The
design sketch had ⇄ (U+21C4); it is in none of the bundled subsets, nor in Noto Sans
Symbols 2, so it would draw tofu — 🔄, the house glyph for "nog een keer / opnieuw", says
the same: this game once more, with somebody else.

The button is there only when the running game has an animal of the turn AND somebody else
could take it (`Games.kan_wisselen()`); with one animal it could do nothing, so it is not
shown at all. A tap (`Snd.tik()`, then deferred, because it rebuilds the bar) runs
`Games.wissel_speler()`: the next animal of the game's list after the one playing now,
going round (the first of the list when the current one is not on it); it is remembered for
the session in `State.s.speler` (§4.2) and the game restarts with it (§5.2). Nothing is taken
away — no star, no coin; the unfinished turn of the previous animal is simply not finished,
and the adaptive signal only ever counts finished turns. The bar follows the game through
`Games.speler_veranderd`; probe lines `[probe] speler=<id> van=<id> spel=<id>` on a switch
and `[probe] spelbalk speler=<id> knop=<rect>` with the button's rectangle.

The contract a game with an animal of the turn keeps:

- `func spelers() -> Array` on its node: the guest ids that may take the turn, in a
  **stable** order (the save's check-in order). The default (`MiniGame`) is `[]`: no animal
  of the turn, no button. Called at any moment while the game runs; reads, never writes.
- `ctx.speelt(gastId)` whenever its turn takes, or moves on to, an animal.
- `ctx.voorkeur(spelers())` when it builds a turn: the picked animal when it may take part
  here, else `""` and the game chooses as it always did. A saved turn is resumed only when
  it belongs to the picked animal (the multi-animal games: when that animal already had or
  has its go in it) or when there is no pick that may take part.
- `ctx.laat_gaan(gastId)` for the animal whose unfinished turn the pick dropped, AFTER the
  new animal was sent (so the free place he walks to keeps off the new one's target):
  asleep or gone → left alone (a switch never wakes anybody); still on his way into the
  game's room → back to his own bed instead; on his way anywhere else → left alone (the
  old `stop()` already sent him); in the game's room → off to a free place (`World.solo`).
  Without it the stall had two animals on one spot: the old one still walked in and
  waited at the counter after the new one.

| game | who may take the turn (`spelers()`) | its own choice without a pick | on a switch |
|---|---|---|---|
| `sleutels` | every guest with a bed and a room | keys in check-in order | the same board (the core seeds on day, N, band, round) laid out again, first key for the picked animal, the next keys round the list; who waited at the desk goes back to bed (its own `stop()`) |
| `kraam` | every guest with a bed (also without the 🎁 wish: he buys without one) | the guests with the 🎁 wish, else everyone with a bed, picked by day and N like every shop (`WinkelSpel`, games-d.md §4) | fresh turn for the picked animal; the previous one `laat_gaan` (off the counter, or back to bed when still on his way) |
| `hinkel` | every guest with a bed | the wish 🧶 first, then who is in the garden | fresh turn from the start stone; the previous hopper `laat_gaan`, and on the stones he is sent to the grass like every guest who is not playing |
| `zwembad` | every guest with a bed | §1.1 of games-b (wish, then nearest the start edge, then the first with a bed) | fresh lane from 0 m; the previous swimmer is put on the deck (`stop()`) and `laat_gaan` |
| `wekker` | every guest who can be woken (sleepers with a bed, else everyone with a bed, else everyone) | the first three of that list | fresh round of at most three starting at the picked animal and going round; nobody is woken |
| `oogst` | every guest with a bed | games-c §2.6 (by day and N round the list) | fresh turn from the counting question; the previous picker `laat_gaan` (off the table) |
| `weeg` | every guest with a bed | games-c §3.6 (by day and N round the list) | fresh turn from the first reading; the previous weigher `laat_gaan` (off the scale) |

No button: `bedden` (its guest is the one checking in — the subject of the sum, not a
player), `meubels`, `was`, `voerkar` (serves everybody at once) and `tobbe`
(the sum is about soap and tubs; afterwards every waiting animal has its own button in the
bath step, and since 2026-09-23 a tap on it bathes THAT animal — games-a §6.5 E — so the
child picks who bathes there).

**The game begins when its animal is there** (owner, 2026-09-23: "Bij het zwembad is er
geen volg optie om boef aan te komen tenzij ik eerst op 'terug' druk. Zorg dat de minigame
pas begint wanneer het dier er is"). Until 2026-09-23 the games put their first card up
while the animal of the turn was still walking in (PLAN.md R1 "binnen één seconde", N3,
N11), and during a game the child could neither see who was coming nor follow him. Now
every game whose animal has to walk into its room sends him with `ctx.wacht_op` (§5.3) and
puts up **nothing that looks like a task** — no card, no strip, no price, no coin, no hook,
no number above his head — until he stands at his place. The world props of the game (the
stall, the stones, the lane markers, the table, the balance) stand there at once; the game
bar shows the animal (`🐶 Boef 🔄`, so the child may switch while waiting); and at the door
he will come through hangs the hotel's own bubble `🐶 Boef komt eraan` with its bar and
`👀 Volg` (§6.3). Already there, or reduced motion: the first card comes at once, as before.
R1's "within a second" now counts from his arrival.

| game | his place (`ctx.wacht_op`) | what waits |
|---|---|---|
| `sleutels` | the desk (`plek(0.75, 0.85)`, within 6 voxels) | the question, the hooks, the key — for EVERY key: after a hung key the next guest comes forward and the board waits for him |
| `kraam` | in front of the souvenir stall's counter in the arcade (118, 34) | the card, its strip and the price tags (`WinkelSpel`, games-d.md §4.3) |
| `hinkel` | his stone (`dierX(s)`, `zDier`, within 2.5 voxels; the card "komt eraan / Tel straks mee" is gone — PLAN N11 overruled) | the card, the strip, the number above his head |
| `zwembad` | the deck at the start of the lane (`dek.start`; a half-swum lane: the deck `stop()` put him on) | the question and the number on his back; the stair, the dive and the swim are still what the first answer buys |
| `oogst` | beside the picking table (64, 32) | the counting question |
| `weeg` | beside the balance (62, 88) | the first reading |
| `tobbe` | (no animal of the turn) each bather who comes from elsewhere after the sum, beside the first tub | his own bath button — the sum itself needs nobody |
| `wekker` | nobody walks: the sleepers are woken where they lie | nothing — the card comes at once |
| `bedden` | his place at the desk (`Hotel.balieplek()`, within 6 voxels) — he may still be coming in, or walking back after a wrong answer | the beds question, every time it comes |

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
`ochtend`.  **Port (owner 2026-09-23: "laat niet het prikbord zien als start. De gebruiker
moet gewoon op de bel drukken"):** the board never opens by itself — not at the start and
not on a new morning (`Hotel.morgen()` ends in the receptie); it waits behind its button
with its badge.  While the round is `ochtend` the bell button pulses (`puls: -1`, a gentle
breath of ±9 % with a rest, nothing in reduced motion) until the check-in turns the round
into `vrij`.  The reception bell sounds `Snd.ding()`, a struck bell of its own (a 3 ms
attack, E6 with a shimmer 3.5 Hz above it and the 2.76×/5.40× overtones of a metal cup,
about a second of ring); `Snd.bel()` keeps the HTML's reference sound.

**The welcome of a fresh game** (Godot port only; owner, 2026-09-24: "Ik wil ook geen
intro waar je 5x door moet klikken. Maakt het veel korter en zonder tutorial dat lukt de
kinderen zelf wel"). `ui/intro.gd` (`UiIntro`), started by `scenes/main.gd`. It replaces
the six-page story of 2026-09-23 (guests walking in, wishes, a spotlight on the bell,
`Verder ▸` / `Overslaan ▸▸`): no pages, no buttons, nothing explained.

* **When** — a FRESH game only: boot with no save at all, and after `Nieuw spel`. Never
  after `Verder spelen`. The flow decides this; the save has no field for it.
* **What** — one card, `👋 Welkom in het Dierenhotel!` (§7.2), in the middle of the
  screen a little above centre, at most 640 units wide, the sentence in 32/28/24 px by the
  screen's short side (≥ 600 / ≥ 420 / less), `tover` and a few sparkles at the bell. It
  lies over the whole shell in the receptie and closes the prikbord that `Hotel.start()`
  opens on a morning round; while it is up the hotel's buttons step aside
  (`Hits.voorrang("intro")`) and come back, the bell pulsing, when it goes. The pulsing
  bell is the only hint the game gives.
* **How it goes** — by itself after 2.5 s (each frame counts at most 0.1 s, so a
  stuttering first frame of the web export does not eat it), or at the first tap
  anywhere or Enter/Escape; a fresh card ignores taps for 0.35 s (the tap that started
  the game).
* **Reduced motion** — the same card without its pop-in, gone after the same time.
* **Probe lines** — `[probe] intro stap=1/1`, `[probe] introkaart=<rect>`,
  `[probe] intro=klaar hoe=<vanzelf|tik|weg>`, and `[probe] intro=stap 1/1` or
  `intro=geen` before `[probe] klaar`. `tools/probe.js` waits for `intro=klaar` on a fresh
  boot and screenshots the card (`-1a-welkom.png`).

### 6.3 Room navigation

* **Room bar** (`#kamerbalk`): one chip per room — icon + name + a badge with
  `wachtIn(room)` — plus a last chip `🗺️ Plattegrond`. **Per floor** (owner, 2026-09-24: the
  hotel is a tower, `Kamer.etage`): the ground floor first (the receptie stays the first
  chip), then up the tower (1, 2, 3), then the cellar (`K`), the map last; within a floor
  `Rooms.lijst()` order (`UiKamerbalk.etage_volgorde`, `Rooms.op_etage`). Every floor after
  the first opens with a small quiet round badge carrying `Rooms.etage_teken(e)` — no
  button, no key edge, `MOUSE_FILTER_IGNORE`, no focus, so a swipe may start on it — which
  shares one grid cell with its floor's first chip (beside it in a row, above it in the
  rail), so a wrapped bar never leaves a badge alone; a wrapping grid breaks its rows where
  a floor starts when that costs no extra row. The badges fade with the chips during a sum.
  The tablet row (1000 units) keeps one row with the badges and up to four waiting badges
  by stepping its pictures down to 14 px (`_rij_trappen`). The bar is built **once**
  and only updated afterwards (otherwise the row scrolls back to the left on every event and
  the child taps the wrong room). `wachtIn(room)` counts the guests whose need is not yet
  fulfilled **and** whose waiting place is in that room, plus the guest at the desk for the
  receptie.
* **Swiping** (owner, 2026-09-24: "Op mobile kan ik de map shortcuts niet swipen onderaan het
  scherm"): on a phone in portrait the bar is one scrolling row, and a finger swipes it.
  Godot's `ScrollContainer` only scrolls under a finger when the touch reaches it, so every
  chip passes its touch on (`MOUSE_FILTER_PASS`) while still taking its tap; the row has a
  dead zone of 10 units (a trembling tap stays a tap), and the chip under the finger that
  ends a swipe does not navigate (`scroll_started` … `scroll_ended`). Web probe line after a
  swipe: `[probe] kamerbalk veeg scroll=<x>,<y>` plus the chips' new rects; `tools/speel.js`
  plays it with `veeg chip:<naam> <dx>`.
* **Map sheet**: header `🗺️ De plattegrond`, hint `Tik op een ruimte om er naartoe te gaan.`,
  one cell per room showing icon, name and the waiting badge, and a `Sluiten` button.
  **Port (owner 2026-09-24: the hotel is a tower, "heel groot en hoog … net als Habbo
  Hotel").** The map is a cross-section of the building (`ui/plattegrond.gd`): one row per
  floor (`Kamer.etage`, `Rooms.etages()`), the top floor at the top and the cellar at the
  bottom. The table is computed from `Rooms`, never written down (`UiPlattegrond.kaart()`:
  `id → Vector2i(column, row)`), so a room added later gets a cell on its own floor. In a
  row the room the lift stops in comes first (column 1); then each next cell is a room with
  a door to the cell before it when there is one, else the nearest room left on the floor
  (breadth-first over the floor's doors from the lift), a room without a door on its floor
  last (`UiPlattegrond.rij_van(e)`). Today that reads, top-down: `3: gang kamer1 kamer2
  keuken` · `2: speelzaal` · `1: winkels` · `0: receptie tuin zwembad kas` · `K: wasserij`.
  A door between two cells side by side is drawn in their gap (a `poort` dashed): today
  `gang|kamer1`, `receptie|tuin` and the gate `tuin|zwembad`; doors between rooms that are
  not neighbours in their row are left out, and the lift is not a door. Left of the rows
  runs the lift shaft: one line from the top floor to the cellar, on it a small round button
  per floor with `Rooms.etage_teken(e)` (drawn, not a tap target: the row is where a finger
  goes); the button of the floor in view is lit, and that floor's row wears a faint sunny
  band; the room in view stays the sunny cell. Everything is placed by hand, no `Container`.
  On a narrow sheet the gaps give way first (8 → 4), then the shaft (36 → 24), then the
  cells (never under 56 wide: a 48 tap target plus air); with five floors a short screen
  scrolls the sheet. The same sheet, titled `🛗 De lift`, is the lift's panel
  (`scenes/main.gd::_toren`).
* `Hotel.naarKamer(id)` = `World.naar(id)` + `state.kamerNu = id` + `Snd.deur()` +
  `render()`.
* **Port (owner 2026-09-23): `👀 Volg`.**  The "komt eraan" bubble (a guest walking in
  from a room you cannot see, with its bar) carries a `👀 Volg` pill, and the whole bubble
  is the button: a tap calls `Hotel.volg(id)`.  The camera goes to the room the guest is
  in, and every drawn frame (`World.getekend`) follows him through the next door with
  `Hotel.naarKamer` — so the door sound and the repaint come along — until he steps into
  the room he was heading for (`reis_doel` empties); there the walk ends by itself, which
  is where the child was looking.  His name plate reads `👀 <naam>` meanwhile.  Every
  other room change ends it (a door, the room bar, the map, a game's own camera — the
  walk's own switches are the only ones it lets through), and so does a game that
  starts.  Not saved.
* **Port (owner 2026-09-23): following during a game.**  "Bij het zwembad is er geen
  volg optie om boef aan te komen tenzij ik eerst op 'terug' druk."  While a game runs,
  the bubble of the animal that game waits for (`ctx.wacht_op`, §5.3, §5.8) stays in view
  — the hotel marks it `data.spel = <game>` and `Hits` lets exactly that one through the
  voorrang (§5.2 step 4) — and its `👀 Volg` works: the camera walks along with him
  through every door and ends in the game's room, where the game then begins.  Only that
  animal may be followed during a game (`Games.verwacht_dier`); every other guest's
  bubble stays off the glass and `Hotel.volg` refuses him.  A game that STARTS while you
  follow still ends the walk (step 2 of §5.2); a walk begun during a game ends when that
  start of the game ends (`⬅ Terug`, a supersede, the animal switch) — the camera stays
  where it is — and when the guest is gone or no longer awaited before he reached the
  game's room, the camera goes back there (`stop_volgen(true)`): the child is never left
  in a room whose doors the game hides.  While the camera is away, the game's own things
  are simply not in view (they belong to its room); back in the room `Hits` lays them out
  again.
* **Port (owner 2026-09-24: "Het dier moet gevolgd worden met de camera nadat het aantal
  bedden geselecteerd is"): a game that walks its animal somewhere else.**  The beds game
  (games-a.md §3) sends the guest from the desk to his room and back.  It says so with
  `Games.verhuis(kamer)` — the room the game "is in" moves along — registers him as awaited
  (`Games.verwacht`) and calls `Hotel.volg`: the camera walks along through every door, and
  because the walk now ends in the game's (moved) room, `stop_volgen(true)` leaves it
  there instead of jumping back to the desk.
* **Port (owner 2026-09-23): a hotel button stands only where a tap does something**
  ("actions such as a blank bed are available ... but when you click on them you can't
  execute them ... this provides visual clutter").  Outside a game: the bell only while a
  bedroom can take one more guest (`State.plek_voor_gast()`, §3.3) and nobody is at the
  desk or checking in; a bed never (since 2026-09-24 the check-in chooses a room at the
  desk, not a bed in the room); the play basket only while a guest
  in that room wants to play; a bowl only with food in it and a guest there that has not
  eaten (the tap feeds).  Doors, the prikbord and the lamp keep their rules.  While a game
  runs every hotel button is made as before: `Hits` keeps them off the glass anyway, and a
  game may borrow one (the voerkar takes the bowls and the doors).
* **Port (owner 2026-09-24: "Kan je tijdens een rekensom de hotkeys voor mappen
  verbergen"): during a sum the ways out of the room step aside.**  While a sum is being
  answered on the glass, every chip of the room bar — the map chip too — fades out
  (0.15 s, at once in reduced motion) and can be neither tapped nor focused (disabled,
  `MOUSE_FILTER_IGNORE`, `FOCUS_NONE`; the bar itself lets the finger through), and the
  hotel's door signs (`hotdeur`) leave the glass (`Hits.plaats`).  A door a running game
  has BORROWED (`ctx.hotspots.pak`, §5.3) is that game's own tool — the voerkar pushes its
  trolley through it — and stays.  When the sum is answered (the card is ticked,
  `.klaar()`) or its card is gone, everything comes back as it was.  Nothing moves: the
  chips keep their place and size in the shell, so the world frame keeps every unit (the
  only rescale is the maths bar's own, PLAN.md §3.1).  **The rule** (`Ui.is_som`, one
  function for the bar and the doors): a card counts while it is open, stands in the room
  in view, is not ticked, and asks a sum — it asks for a number (`goed`, its strip is four
  numbers) or carries a sum line (`som`: `2 + 1 =`, `3 × 4`, `€8 − €6 =`).  A card with
  only word choices and no sum line (the check-in's room question, step 3) asks
  something but no sum: the shortcuts stay.  A card in another room never counts, so a
  child who followed a guest out of the receptie always has doors.  The way on is the sum
  itself — four choices, a miss costs nothing (HOTEL.md §1 R6) — plus, in a game, the
  game bar's `⬅ Terug` (§5.8), which never steps aside; the beds game's `⬅ Terug` brings
  the check-in back to its room question (`Hotel.checkin_terug`).  The chrome (board,
  evening, coins, letters, sound) stays.  Probe: `[probe] kamerbalk verstopt=<bool>
  som=<card id>` on every change, and no `chip` lines while the chips are hidden; every
  opened card now also reports its answer strip bare as `[probe] <id>_keuzes=<rect>`, so
  `tools/speel.js` can answer the desk's questions (`ci_som_keuzes#3/4`).
* **Door hotspots** (**port:** the sign hangs ON its door, prio 11 — §5.4 port rules): one per door of the room in view, at the door point, `y = 9`, icon and
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

The welcome of a fresh game (§6.2): `👋 Welkom in het Dierenhotel!` — one card, no
buttons (since 2026-09-24; the five tutorial sentences and `Verder ▸` / `Overslaan ▸▸` are
gone). It keeps HOTEL.md §9 counted as `Ui.keur_regel` counts.

### 7.3 Map sheet

`🗺️ De plattegrond` · `Tik op een ruimte om er naartoe te gaan.` · `Sluiten`

### 7.4 Receptie: hotspots and the bell

`Bel` (title `Bel voor de volgende gast`) · `Prikbord` (title `Het prikbord met de taakjes`) ·
`Avond` (title `De avondronde`) · (`Vrij bed` / `Een vrij bed`: gone 2026-09-24) ·
`Speelmand` (title `De speelmand`) · `Vol` / `Leeg`
(titles `Er ligt eten in het bakje` / `Het bakje is nog leeg`) ·
`Ga naar <kamernaam>` · bell-full bubble `🛏 <maxGasten> alle kamers vol` ·
toast `🛎️ Er staat al iemand` · toast `<naam> staat aan de balie! 🔔`

### 7.5 Check-in

**Port (owner 2026-09-23: "De manier om voer scheppen te tellen is ook niet heel
duidelijk ... die niet veel langer is"):** `Elke dag eten de gasten <n> schep|scheppen` ·
`<naam> wil er <n> bij. Hoeveel samen?` · `Voer voor <n> dag|dagen: elke dag <n> schep|scheppen` ·
`📦 In de kast: <n> schep|scheppen. Genoeg?` · choice title `is er genoeg voer?` (the HTML
had `De gasten eten … per dag` · `<naam> eet <n> erbij. Samen?` · `Elke dag …, … lang` ·
`📦 In huis: …` · `is er genoeg eten?`) · `te weinig` `precies` `blijft over` ·
**port (owner 2026-09-24):** `Welke kamer voor <naam>?` · `Kamer 1` / `Kamer 2` (short
`1` / `2`) · choice title `kies een kamer` · `<naam> doet een dutje` (owner 2026-09-24,
was `welterusten`) · the beds game's own words
(games-a.md §3.7) · after a slip the house miss bubble `🔄 Nog een keer` (`UiTekst`) ·
toasts: `👆 Tik eerst een getal` · `Precies! 🎉` · `Goed gerekend! 🎉` · `💤 Hier slaapt iemand`.
Gone with the room choice and the no-help rule: `Kies een bed` · `Alles bezet` ·
`🥄 Tel ze samen` · `🥄 <dagen> × <nieuw> = <product>` · `<naam> slaapt hier. 💤` ·
`🛏 Bel eerst een gast`.

### 7.6 Feeding, playing, wishes

Wish bubbles: `🍪 eten` `🛏 bed` `🛁 bad` `🧶 spelen` `🏊 zwemmen` `🎁 souvenir`
(title `<naam> wil eten` / `wil een bed` / `wil in de tobbe` / `wil spelen` /
`wil zwemmen` / `wil een souvenir`).  **Port (owner 2026-09-23: "Als ik eten druk gebeurt
er niks dat zou me naar de keuken moeten brengen"):** a tap takes you where the wish comes
true (`Hotel.wens_tik`), doing what its card on the board does: 🍪 with food in his bowl →
his room, where the bowl pulses (`WIJS_S` 4 s); 🍪 with an empty bowl → the keuken with the
voerkar open; 🧶 → his room, where the play basket pulses; a wish a game fulfils (`wens` in
its definition, or `WENS_SPEL`) → that game in its room.  The HTML toasted the sentence.
Toasts: `Smakelijk eten! 😋` · `🍪 Vul eerst de voerkar` · `🍽 Hier slaapt niemand` ·
`🧶 Straks samen spelen` · `<naam> speelt met het balletje! 🧶` ·
`Ze spelen allemaal met het balletje! 🧶`

### 7.7 Prikbord

`Bel een gast` · `Nog plek voor een gast` (the HTML: `Nog een bed vrij`; port 2026-09-24,
§3.3) · `<naam> wil een bed` · `Vul de voerkar` ·
`Reken af: <naam>` · `<naam> wil spelen` · `Speel lekker rond` ·
sheet (port, owner 2026-09-23) `📋 Prikbord` · `Tik op een taakje om erheen te gaan.` ·
under a card `in de <kamer>` · `in kamer 1` / `in kamer 2` · `bij het zwembad` · `Sluiten` ·
day messages `voer: <n> 🥄` · `Els bracht 10 🥄` · `<naam> gaat naar huis`
(game cards: `<naam> wil in bad` / `Tobbe-tijd` · `Hang de sleutels op` · `Koop iets moois` ·
plus the golf-3 cards from their own files; `Zet de bedden op rij` is gone, 2026-09-24)

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
