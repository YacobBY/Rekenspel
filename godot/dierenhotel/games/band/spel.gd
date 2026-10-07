extends MiniGame
## band — De dierenband 🥁 in de muziekkamer (U2; eigenaar 2026-10-07: "Verzin
## nog vier kamers met activiteiten").  Ontwerp en stand:
## `.fanout/scratch/uitbreiding/U2-muziekkamer.md`.
##
## De trommel speelt een ritme — elke tik een `plop` én een vonkje op het vel
## (en straks een oplichtende noot op de notenbalk boven de trommel, een
## game-eigen Control zoals `WekkerKlok`; NOG NIET GEBOUWD) — en dan vraagt de
## somkaart hoeveel tikken dat waren (groep 3), hoeveel tikken in M maten
## (groep 4/5) of hoeveel maten er nodig zijn voor D tikken (groep 5, even
## dagen).  De rekenkunde staat in `beurt.gd`; dit bestand doet alleen de
## wereld.  Een misser: `Ui.misser` (standaard), dezelfde vraag blijft, het
## ritme speelt op 🔁 opnieuw.  Goed: `ja`, `hoera`, `tover`, een ster.
##
## STUB tot de beurt in de browser is gespeeld (`speel.js`); dan `stub: false`.

const Beurt := preload("res://games/band/beurt.gd")

const KAMER := "muziekkamer"
const KAART := "band_som"
const KNOP_NOG := "band_nog"
const RUST_TROMMEL := "rust_band_trommel"
const RUST_XYLO := "rust_band_xylofoon"
const RUST_PIANO := "rust_band_piano"
const RUST_STANDAARD := "rust_band_standaard"
## Waar de instrumenten staan (voxels, zie de kamerdata in `rooms.gd`): de
## trommel midden op het kleed, de muziekdoos van de kamer is het ankerobject
## van de knop (zoals spiegel's doos → ezel).
const TROMMEL_X := 44
const TROMMEL_Z := 44
const DOOS_X := 6
const DOOS_Z := 84
const VONK := Color("#F5D37A")

var _o: Dictionary = {}
var _kaart = null
var _t0 := 0
var _missers := 0
var _speelt := false

func definitie() -> Dictionary:
	# None of these may touch `self`: the registry reads `definitie()` from a
	# throwaway instance and frees it again (architecture.md §6.1).
	return {
		"naam": "De dierenband",
		"kamer": KAMER,
		"stub": true,
		"hotspot": {"obj": "muziekdoos", "dx": TROMMEL_X - DOOS_X, "dz": TROMMEL_Z - DOOS_Z,
			"icoon": Beurt.ICOON, "label": Beurt.T_KNOP, "hoog": 30, "rust": RUST_TROMMEL},
		"modellen": ArtDecorMuziek.tabel(),
		"rust": [
			{"id": RUST_TROMMEL, "model": "band_trommel", "x": float(TROMMEL_X),
				"z": float(TROMMEL_Z), "params": {}},
			{"id": RUST_XYLO, "model": "band_xylofoon", "x": 66.0, "z": 30.0, "params": {}},
			{"id": RUST_PIANO, "model": "band_piano", "x": 34.0, "z": 1.0, "params": {}},
			{"id": RUST_STANDAARD, "model": "band_standaard", "x": 24.0, "z": 34.0, "params": {}},
		],
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		"taak": {"id": "band", "icoon": Beurt.ICOON, "tekst": Beurt.T_TITEL,
			"kamer": KAMER, "prio": 5},
	}

func start(_c: SpelCtx) -> void:
	_t0 = Time.get_ticks_msec()
	var S := ctx.data()
	var dag := int(State.s.get("dag", 1))
	var n := State.n_gasten()
	var band := State.band()
	# the turn lives in the save; a new day, a new guest or a new band is a new turn
	if int(S.get("dag", -1)) != dag or int(S.get("n", -1)) != n \
			or int(S.get("band", -1)) != band or not S.has("soort"):
		S.clear()
		var o := Beurt.opzet(n, band, dag)
		for k in o:
			S[k] = o[k]
		S["missers"] = 0
		State.bewaar()
	_o = S
	_missers = int(S.get("missers", 0))
	print("[probe] spel=start id=", ctx.id, " kamer=", ctx.kamer, " soort=", S["soort"],
		" goed=", S["goed"], " tikken=", S["tikken"])
	_kaart = ctx.ui.somkaart({"x": float(TROMMEL_X), "z": float(TROMMEL_Z)}, String(S["som"]), {
		"id": KAART, "kamer": KAMER, "hoog": 36.0, "icoon": Beurt.ICOON,
		"regel": Beurt.vraag(S), "titel": "de trommel",
		"goed": int(S["goed"]), "min": int(S["min"]), "max": int(S["max"]),
		"on_ok": _antwoord})
	ctx.hotspots.maak({"id": KNOP_NOG, "kamer": KAMER, "x": 70.0, "z": 56.0, "y": 8.0,
		"icoon": Beurt.ICOON_NOG, "label": Beurt.T_NOG, "titel": "luister nog eens",
		"prio": 8, "aan": func(_s) -> void: _speel_ritme()})
	_speel_ritme()

func stop() -> void:
	if not _o.is_empty():
		ctx.data()["missers"] = _missers
		State.bewaar()
	print("[probe] spel=stop missers=", _missers)

## The drum plays the bars the stave shows: a `plop` per tick, rising in pitch,
## a spark on the drumhead, a `klok` on every bar line.
func _speel_ritme() -> void:
	if _speelt or _o.is_empty():
		return
	_speelt = true
	ctx.snd.hup()
	var maten: Array = _o["maten"]
	var toon: int = mini(int(_o["toon_maten"]), maten.size())
	var i := 0
	for mi in toon:
		for _tik in (maten[mi] as Array):
			i += 1
			ctx.snd.plop(i)
			World.spetter(KAMER, float(TROMMEL_X) + 8.0, float(TROMMEL_Z) + 8.0, 3, VONK)
			if not await na(Beurt.TIK_S):
				return
		if mi < toon - 1:
			ctx.snd.klok()
			if not await na(Beurt.MAAT_RUST_S):
				return
	_speelt = false
	print("[probe] band=gespeeld tikken=", i)

## Every tap on the strip lands here (`Ui.somkaart`: `on_ok` runs after a wrong
## tap too, the card has already shown `Ui.misser`).  Wrong: count it, keep
## the same question, no help.  Right: cheer, a star, done.
func _antwoord(n: int, kaart) -> void:
	if not actief:
		return
	if n != int(_o["goed"]):
		_missers += 1
		ctx.data()["missers"] = _missers
		State.bewaar()
		print("[probe] band=mis n=", n, " missers=", _missers)
		return
	ctx.snd.ja()
	if kaart != null:
		kaart.zet(str(_o["goed"]))
		kaart.klaar()
	ctx.state.tel(_missers == 0, Time.get_ticks_msec() - _t0)
	ctx.ui.toast("%s %s" % [Beurt.ICOON_AF, Beurt.T_AF])
	if not await na(0.6):
		return
	ctx.snd.hoera()
	ctx.snd.tover()
	ctx.taak_klaar("band")
	print("[probe] spel=klaar sterren=", State.s["sterren"], " missers=", _missers)
	ctx.sluit()
