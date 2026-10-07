extends MiniGame
## Sterren tellen ⭐ — on the dakterras (U3, 2026-10-07; owner: "Verzin nog
## vier kamers met activiteiten").  Stars hang in the night sky over the roof
## deck in DOT PATTERNS; the telescope shows the patch large (`SterrenKijker`)
## and one tap on the strip answers.  The maths is `beurt.gd` (pure, static,
## seeded): groep 3 subitizing, bonds to 10 and sums to 20; groep 4 rows of
## 2/5/10 and doubles; groep 5 tens and hundreds and r rows of s.
##
## `stub: true` until the turn runs end to end on the real shell
## (`test_sterren.gd`): no entry button, no task card in the hotel yet.
##
## The save (`ctx.data()`) holds only the SEED of the turn (`som`: band, n,
## beurt_nr, zaad) and the misses: the patterns are rebuilt with `Beurt.maak`,
## so a reload asks the same question and no Vector2i has to survive JSON.

const Beurt := preload("res://games/sterren/beurt.gd")
const KAMER := "dakterras"
const KAART := "st_som"
const KIJKER := "st_kijker"
const TAAK := "sterren"
const KIJK_X := 90.0
const KIJK_Z := 86.0
const KIJKER_HOOG := 44.0

var _kaart = null
var _t0 := 0

func definitie() -> Dictionary:
	return {
		"naam": "Sterren tellen",
		"kamer": KAMER,
		"stub": true,     # U3: until the turn runs end to end (see test_sterren.gd)
		"hotspot": {"obj": "telescoop", "icoon": "⭐", "label": "Sterren tellen", "hoog": 22},
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		"taak": {"id": TAAK, "icoon": "⭐", "tekst": "Tel de sterren", "prio": 6},
	}

func start(_c: SpelCtx) -> void:
	_t0 = Time.get_ticks_msec()
	var S := ctx.data()
	var dag := int(State.s.get("dag", 1))
	if not S.has("som") or int((S["som"] as Dictionary).get("dag", -1)) != dag:
		S["som"] = {
			"band": ctx.state.band(), "n": maxi(1, ctx.state.n_gasten()),
			"beurt_nr": int(S.get("beurt_nr", 0)), "zaad": Beurt.ZAAD + dag, "dag": dag}
		S["missers"] = 0
		State.bewaar()
	_toon(_beurt())

func stop() -> void:
	State.bewaar()
	print("[probe] spel=stop id=", ctx.id, " sterren=", State.s.get("sterren", 0))

## The turn, rebuilt from its seed.
func _beurt() -> Dictionary:
	var s: Dictionary = ctx.data().get("som", {})
	return Beurt.maak(int(s.get("band", 3)), int(s.get("n", 1)),
		int(s.get("beurt_nr", 0)), int(s.get("zaad", Beurt.ZAAD)))

func _toon(b: Dictionary) -> void:
	var kijker := SterrenKijker.new()
	kijker.meet = func() -> Vector2: return Vector2(260.0, 160.0)
	kijker.zet(b["patronen"])
	ctx.hotspots.maak({"id": KIJKER, "kind": "eigen", "knoop": kijker, "kamer": KAMER,
		"x": KIJK_X, "z": KIJK_Z, "y": KIJKER_HOOG, "op": "midden",
		"geen_vlak": true, "vast": true, "prio": 20})
	_kaart = ctx.ui.somkaart({"x": KIJK_X, "z": KIJK_Z}, "", {
		"id": KAART, "kamer": KAMER, "hoog": 26.0, "icoon": "⭐",
		"regel": str(b["regel"]),
		"goed": int(b["goed"]), "liever": b["liever"], "min": 1,
		"dier": _gast_id(), "titel": "de sterren",
		"on_ok": _antwoord,
	})
	print("[probe] spel=start id=", ctx.id, " kamer=", ctx.kamer, " soort=", b["soort"],
		" goed=", int(b["goed"]))

## The strip's tap: wrong = the animal is disappointed and the same question
## stays (no help); right = the stars twinkle, one star for taking part.
func _antwoord(n: int, kaart) -> void:
	if not actief:
		return
	var S := ctx.data()
	var b := _beurt()
	if not Beurt.keur(b, int(n)):
		S["missers"] = int(S.get("missers", 0)) + 1
		ctx.ui.misser(kaart, _gast_id())
		return
	kaart.zet(str(int(b["goed"])))
	kaart.klaar()
	ctx.snd.ja()
	ctx.wereld.spetter(KAMER, KIJK_X, KIJK_Z, 14, Color("#FFF3B0"))
	ctx.state.tel(int(S.get("missers", 0)) == 0, Time.get_ticks_msec() - _t0)
	S["beurt_nr"] = int(S.get("beurt_nr", 0)) + 1
	S.erase("som")
	State.bewaar()
	if not await na(0.9):
		return
	ctx.taak_klaar(TAAK)
	ctx.ui.toast("⭐ Klaar! Een ster erbij")
	print("[probe] spel=klaar sterren=", State.s.get("sterren", 0))
	ctx.sluit()

## The animal of the turn: the first guest on the deck, else none.
func _gast_id() -> String:
	for d in World.dieren(KAMER):
		if d != null and "id" in d:
			return str(d.id)
	return ""
