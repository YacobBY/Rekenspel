extends MiniGame
## Koekjes bakken 🍪 — de bakkerij (2026-10-07, owner: "Verzin nog vier kamers
## met activiteiten").  Design and state of the build:
## .fanout/scratch/uitbreiding/U1-bakkerij.md.  STUB until the turn runs end
## to end in the export (`stub: true` keeps it off the board and the room).
##
## One turn: the guest of the turn stands by the work table, on the floor in
## front of the counter lies a baking tray with the cookies in rows × columns
## (`KoekjesBeurt`) or the egg bowl; one card with one sentence and a strip of
## four numbers hangs on it.  Right: the tray goes into the oven, a star, done.
## Wrong: `Ui.misser` — the same question, no help (owner 2026-09-24).

const Beurt := preload("res://games/koekjes/beurt.gd")

var _b: Dictionary = {}
var _kaart = null
var _gast := ""
var _t0 := 0
var _missers := 0

func definitie() -> Dictionary:
	return {
		"naam": "Koekjes bakken",
		"kamer": "bakkerij",
		"stub": true,
		"hotspot": {"obj": "oven", "icoon": "🍪", "label": Beurt.KNOP, "hoog": 26},
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		"wens": "eten",
		"taak": {"id": "koekjes", "icoon": "🍪", "tekst": Beurt.TAAK,
			"kamer": "bakkerij", "prio": 4},
	}

func start(_c: SpelCtx) -> void:
	_t0 = Time.get_ticks_msec()
	Art.registreer_model("koekjes_plaat", ArtDecorBakkerij.bakplaat)
	Art.registreer_model("koekjes_kom", ArtDecorBakkerij.eierschaal)
	var d := ctx.data()
	if d.has("beurt") and d["beurt"] is Dictionary and not (d["beurt"] as Dictionary).is_empty():
		_b = d["beurt"]
	else:
		_b = Beurt.maak(ctx.state.n_gasten(), ctx.state.band(), int(State.s.get("dag", 1)))
		d["beurt"] = _b
	_missers = int(d.get("missers", 0))
	var gasten: Array = State.s.get("gasten", [])
	_gast = str(gasten[0]["id"]) if not gasten.is_empty() else ""
	_teken()

func stop() -> void:
	ctx.data()["beurt"] = _b
	ctx.data()["missers"] = _missers
	State.bewaar()

func _teken() -> void:
	var soort := str(_b.get("soort", ""))
	var punt := {"kamer": ctx.kamer, "x": 60.0, "z": 42.0}
	if soort in ["eieren", "dubbel"]:
		ctx.wereld.decor(ctx.kamer, {"id": "koekjes_kom", "model": "koekjes_kom",
			"x": 60.0, "z": 42.0, "params": {"n": int(_b.get("eieren", 0))}})
	elif soort == "verdeel":
		ctx.wereld.decor(ctx.kamer, {"id": "koekjes_plaat", "model": "koekjes_plaat",
			"x": 60.0, "z": 42.0,
			"params": {"rijen": 1, "kolommen": mini(int(_b.get("totaal", 1)), 12),
				"aantal": int(_b.get("totaal", 1))}})
	else:
		for i in int(_b.get("platen", 1)):
			ctx.wereld.decor(ctx.kamer, {"id": "koekjes_plaat%d" % i, "model": "koekjes_plaat",
				"x": 48.0 + 26.0 * i, "z": 42.0,
				"params": {"rijen": int(_b["rijen"]), "kolommen": int(_b["kolommen"])}})
	var o := {"id": "koekjes_som", "kamer": ctx.kamer, "hoog": 16.0, "icoon": "🍪",
		"regel": str(_b["regel"]), "goed": int(_b["goed"]), "liever": _b.get("liever", []),
		"on_ok": _antwoord}
	if _b.has("regel2"):
		o["regel2"] = str(_b["regel2"])
	_kaart = ctx.ui.somkaart(punt, str(_b["som"]), o)

func _antwoord(n, k) -> void:
	if n == null or _b.is_empty():
		return
	if int(n) != int(_b["goed"]):
		_missers += 1
		ctx.data()["missers"] = _missers
		Ui.misser(k, _gast)
		return
	k.zet(str(int(n)))
	k.klaar()
	ctx.snd.ja()
	ctx.state.tel(_missers == 0, Time.get_ticks_msec() - _t0)
	ctx.ui.wolk({"id": "koekjes_klaar", "kamer": ctx.kamer, "x": 30.0, "z": 10.0,
		"hoog": 30.0, "icoon": "🍪", "tekst": Beurt.KLAAR.substr(3)})
	if not await na(1.4):
		return
	ctx.data()["beurt"] = {}
	ctx.taak_klaar("koekjes")
	ctx.sluit()
