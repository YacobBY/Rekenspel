---
name: dh-minigame
description: Change, fix or extend one of the ten minigames (games/<id>/) within the MiniGame contract, the frozen maths core and the child-text rules; includes the exact files and checks.
whenToUse: Any task that touches games/<id>/spel.gd, its helpers, its voxel models or its tests.
---

# Files (all under `godot/dierenhotel/games/<id>/`)

| file | holds |
|---|---|
| `spel.gd` | the game: `definitie()`, `start(ctx)`, `stop()`, the turn (`_vraag`, `_kies`, `_afronden`), decor, card placement |
| `beurt.gd` | pure helpers + every child-facing sentence as `static func`/`const` (no world access) |
| `modellen.gd` | the game's voxel models (`ArtVorm.bx(v, x, y, z, w, h, d, Color)`), registered as `<id>_<naam>` |
| `kaartplek.gd` (some games) | where the card may stand |
| `test_<id>.gd` | the game's suite |

Spec: `.fanout/specs/godot/games-a.md` (bedden §3, sleutels §4, meubels §5,
tobbe §6, voerkar §7) or `games-b.md` (zwembad §1 lines 226–626, wekker §2
626–953, hinkel §3 953–, was §4, kraam §5). Read the section, not the file.

# Contract (spel/minigame.gd, spel/ctx.gd — AGENTS.md §5 has the full table)

- Everything goes through `ctx`: `ctx.ui.somkaart(...)`, `ctx.ui.wolk(...)`,
  `ctx.ui.toast(text, klas)`, `ctx.wereld.<World API>`, `ctx.snd.<name>()`,
  `ctx.hotspots.weg(id)`, `ctx.data()` (the game's own save drawer),
  `ctx.state.band()/tel(ok, ms)/n_gasten()`, `ctx.taak_klaar(id)`, `ctx.sluit()`.
- After every `await`: `if not actief: return`. Use `await na(seconds)` for
  waits (returns false when the game was stopped).
- `stop()` must remove every card, bubble, tag, hotspot and decor the game made
  and leave no guest in an impossible place; `_bewaar()` before you leave.
- `ctx.state.tel(first_try_ok, ms)` once per finished turn; `ctx.taak_klaar`
  when the board task is done; `ctx.sluit()` after the reading time.
- Decor: `ctx.wereld.decor(KAMER, {"id", "model", "door": ctx.id, "x", "z",
  "params"})` — re-issuing the same id replaces the piece (that is how you
  recolour); `decor_weg(KAMER, id)` removes; `World.decor_lijst(KAMER)` lists.
- Effects: `ctx.wereld.spetter(KAMER, x, z, n, Color, omhoog := true, hoog := 0.0)`;
  colours in `art/effect.gd` (`PLONS_KL`, `STER_KL`, `KRUIMEL_KL`, `ZEEP_KL`).
  No-op in reduced motion (`ctx.wereld.rust()`).
- Sounds: only the names in games-b.md §0.7 (`ja`, `zacht`, `au`, `plons`,
  `hoera`, ...). Do not add sounds the spec does not name for that moment.

# Hard rules

- **Never edit `core/sommen.gd`** (frozen, byte-identical oracle) or any
  autoload for a game change; if a game needs a new World/Ui feature, say so
  in the answer instead.
- Child-facing strings are verbatim from the spec tables ("Kindtekst,
  letterlijk"); tests compare them. New sentences: ≤ 8 words, ≤ 40 characters,
  no reading required, never punishing (no red, no "fout", no timer).
- The card rule line `regel` is mandatory; `keuzes` ≤ 4 buttons.
- Keep the game's own reduced-motion behaviour (`_leestijd`, instant moves).

# Steps

1. `read` spel.gd (whole file once), `beurt.gd` if strings change, the spec
   section, the test file's helpers (first ~150 lines) and one similar test.
2. Edit. Every new behaviour gets one test in `test_<id>.gd`.
3. `DH_TEST_FILTER=<id> tools/test.sh 2>&1 | tail -15` → fix → full suite once.
4. Answer: files changed, what the child now sees, `N goed, 0 fout`.
