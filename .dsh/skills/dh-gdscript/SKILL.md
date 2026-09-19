---
name: dh-gdscript
description: The GDScript and project traps that break this codebase silently (typed inference on untyped values, autoload names, inner classes, signals re-entering placement, Label minimum sizes, new-file .uid) — read before editing autoload/*.gd, games/*/spel.gd or ui/*.gd.
whenToUse: Before editing any .gd file, and when the log shows Parse Error, "Cannot infer the type", "Invalid access to property or key", or a Control that is far taller than it draws.
---

# Typing — the #1 parse error in this repo

- `:=` only works when the right side has a known type. Anything reached
  through an UNTYPED value has none: `ctx.wereld.x()`, `ctx.ui.x()`,
  `dict["k"]`, `Hits.spot(id)`, `s.knoop` (a `Variant`), `o.get("k", 0.0)`.
  Write the type: `var balk: float = ctx.wereld.balk_hoog()`,
  `var n: int = int(d.get("n", 0))`, `var r: Rect2 = dbg["id"]["rect"]`.
- A parse error in `games/<id>/spel.gd` does not crash: the game silently
  fails to register and every test of that game goes red with
  `het spel start: niet waar`. Always run the filter after an edit.
- Autoloads are reached by NAME (`Hits`, `Ui`, `World`, `Hotel`, `State`,
  `Games`, `Rooms`, `Art`, `Snd`, `Econ`), never by a class name. Their inner
  classes (`Hits.Spot`, `Ui.Kaart`) cannot be used as a type outside their
  file — hold them in an untyped `var`.
- Scripts with `class_name` (`UiRekenbalk`, `UiSomkaart`, `UiThema`, `ArtVorm`,
  `Proef`) can be used as types anywhere.

# Order and re-entrancy

- `Hits.plaats()` lays out every hotspot of the room in one pass. Never call
  it from inside a signal handler that `Hits` itself may fire, and never from
  a spot's `on_weg`. `World.kader_veranderd` is safe to LISTEN to for redraws.
- `World.zet_bak`/`_eet` run inside the world tick while it iterates the
  animals: anything they trigger that redraws goes through `call_deferred`.
- In a game: after every `await` → `if not actief: return`; waits via
  `await na(seconds)`; state after every step in `ctx.data()`; `stop()`
  removes everything the game made.
- `Hits.maak(spot)` with an existing id removes the old spot first and runs
  its `on_weg` — remember the new thing only AFTER `maak` returns.

# Sizes and layout

- `Hits` writes the size it placed a card at into `custom_minimum_size`; a
  card measured once at a wrong size keeps it. Measure with
  `Ui.kaart_mat(kaart)`-style helpers that clear the pin, not with the node.
- A `Label` with autowrap reports its LONGEST WORD as minimum width and the
  height at whatever width it last had. Use `UiThema.wrap_hoogte(label, breed)`.
- A tap target is ≥ 48 units (`Hits.RIJ` = 52 with air); a band grid row is
  what a room needs to lay out its buttons. Taking frame height away from a
  room takes bands away — check `Hits.debug()` on the low frame `740x360`.
- Every frame number is in units of `World.kader_rect()`; the frame is the
  world's frame, not the window.

# Files

- A new `.gd` needs its `.uid`: run `tools/import.sh` (≈ 20 s), commit both.
- Child-facing strings: `const` at the top of the game file, ≤ 8 words and
  ≤ 40 characters, pictogram + words, never punishing; `Ui.keur_regel` checks.
- `core/sommen.gd`: never edit.
