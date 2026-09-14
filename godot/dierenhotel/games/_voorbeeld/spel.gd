extends MiniGame
## _voorbeeld — the reference minigame.  It does nothing a child would enjoy;
## it exercises every part of the contract exactly once, so a wave-2 worker can
## copy the shape and a reviewer can see what "correct" looks like:
##
##   definitie() · start(ctx) · stop() · ctx.data() · ctx.hotspots.maak ·
##   ctx.ui.somkaart with its mandatory sentence and a choice strip ·
##   ctx.ui.wolk on the guest · ctx.wereld.decor with its own registered model ·
##   an awaited walk with the `actief` check after it · ctx.taak_klaar ·
##   ctx.sluit()
##
## Copy this directory to `res://games/<id>/`, rename nothing else: the
## directory name IS the game id, and no shared file is touched.

var _stap := 0
var _kaart = null

func definitie() -> Dictionary:
	return {
		"naam": "Voorbeeld",
		"kamer": "gang",
		"stub": true,     # a worked example for developers: never a task card or a button in the hotel (owner, 2026-09-14: "Doe het voorbeeld" hung over the desk)
		"hotspot": {"obj": "kist", "icoon": "", "label": "Voorbeeld", "hoog": 14},
		"unlock": func(n: int, _band: int) -> bool: return n >= 0,
		"taak": {"id": "voorbeeld", "icoon": "", "tekst": "Doe het voorbeeld", "prio": 5},
	}

func start(_c: SpelCtx) -> void:
	_stap = int(ctx.data().get("stap", 0))
	# a game's own model is namespaced with the game id (§13 Q-X1-11)
	Art.registreer_model("_voorbeeld_blok", _blok)
	ctx.wereld.decor(ctx.kamer, {
		"id": "vb_baken", "model": "_voorbeeld_blok", "x": 30.0, "z": 8.0,
		"params": {"kleur": Color("#F2C14E")},
	})
	var tik := func(_s) -> void:
		_beurt()
	ctx.hotspots.maak({
		"id": "vb_knop", "kamer": ctx.kamer, "x": 24.0, "z": 20.0, "y": 10.0,
		"label": "Beurt %d" % (_stap + 1), "titel": "doe een beurt", "prio": 8,
		"aan": tik,
	})
	ctx.ui.wolk({"id": "vb_wolk", "kamer": ctx.kamer, "x": 20.0, "z": 14.0,
		"hoog": 30.0, "icoon": "", "getal": _stap, "tekst": "beurten gedaan"})
	var kies := func(_id) -> void:
		_beurt()
	_kaart = ctx.ui.somkaart({"x": 24.0, "z": 20.0}, "1 + 1 =", {
		"id": "vb_som", "kamer": ctx.kamer, "hoog": 20.0, "icoon": "",
		"regel": "Hoeveel blokken staan er?",          # 4 woorden, 27 tekens
		"keuze_titel": "kies er een",
		"keuzes": [
			{"id": "een", "icoon": "", "tekst": "een blok", "kort": "een", "kies": kies},
			{"id": "twee", "icoon": "", "tekst": "twee blokken", "kort": "twee", "kies": kies},
		],
	})
	ctx.ui.toast("Voorbeeldspel gestart")
	print("[probe] spel=start id=", ctx.id, " kamer=", ctx.kamer)
	_meld_knop()

## The button and the card are only placed on the next drawn frame; report them
## after that, so the browser probe can put a finger on them.
func _meld_knop() -> void:
	if not await na(0.5):
		return
	for id in ["vb_knop", "vb_som", "vb_som_keuzes"]:
		var knop := Hits.spot(id)
		if knop != null and is_instance_valid(knop.knoop):
			print("[probe] ", id, "=", knop.knoop.get_global_rect(),
				" dekking=", "%.2f" % Hits.dekking(id))

func stop() -> void:
	ctx.data()["stap"] = _stap
	State.bewaar()
	print("[probe] spel=stop stap=", _stap, " sterren=", State.s["sterren"])

func _beurt() -> void:
	_stap += 1
	ctx.data()["stap"] = _stap
	ctx.snd.plop(_stap)
	var d := World.dier("gast1")
	if d != null:
		var gehaald: bool = await World.stappen("gast1", [Vector2(36.0, 28.0), Vector2(12.0, 12.0)])
		if not actief:
			return                      # superseded: the node is on its way out
		if gehaald:
			ctx.snd.ja()
	if _kaart != null:
		_kaart.zet(str(_stap))
		_kaart.klaar()
	if not await na(0.4):
		return
	ctx.taak_klaar("voorbeeld")
	ctx.ui.toast("Klaar - een ster erbij")
	print("[probe] spel=klaar sterren=", State.s["sterren"])
	ctx.sluit()

## Its own voxel model: a small marker block.
func _blok(params: Dictionary) -> Array:
	var kl: Color = params.get("kleur", Color("#F2C14E"))
	var v: Array = []
	for x in 3:
		for y in 6:
			for z in 3:
				v.append({"x": x, "y": y, "z": z, "k": kl})
	return v
