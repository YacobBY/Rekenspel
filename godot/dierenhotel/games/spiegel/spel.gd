extends MiniGame
## spiegel — "Spiegelmaskers" (PLAN.md §3.7.2, M3 + M4), the game of the
## playroom (owner, 2026-09-25: "De speelzaal lijkt momenteel kapot" … "waar
## zijn de spelletjes" — the speelzaal was built as its home and stood empty).
##
## On an easel stands a mask with a mirror down the middle (and in groep 5 a
## second one across it).  One side is stuck full of pink dots; the child
## first does the sum — how many more dots on the right (groep 3), how many
## dots will the mask have: doubling (groep 4) or four times a quarter
## (groep 5) — and then places the missing dots one by one.  Each of them is a
## mirror question: its twin on the board shines, three coloured marks stand on
## the empty side, and the child taps the colour of the mirror image.  The
## wrong marks are the real slips: the dot shifted instead of mirrored, the
## mirror one row off.
##
## Maths first (PLAN.md R1): the sum card stands there at once, the dots come
## after it.  A miss costs nothing and helps nothing (HOTEL.md §9; owner
## 2026-09-24: "geef geen hulp na fouten"): the animal of the turn is
## disappointed, the strip pauses and the SAME question stays.  (§3.7.2 still
## had a help ladder — a glowing mirror, a ghost dot; the owner's rule wins.)
##
## The numbers come from `beurt.gd` (own seeded generator, `core/sommen.gd`
## stays frozen); the easel with the mask is one model (`modellen.gd`).

const KAMER := "speelzaal"
const Modellen := preload("res://games/spiegel/modellen.gd")
const Beurt := preload("res://games/spiegel/beurt.gd")

const EZEL_ID := "sp_ezel"
const RUST_EZEL := "rust_sp_ezel"
## The music box, fixed decor of the playroom: the entry is anchored to it and
## slid onto the easel; while the resting easel stands it hangs ON it.
const DOOS := "muziekdoos"
const DOOS_X := 57
const DOOS_Z := 90
const KAART_ID := "sp_som"
const STROOK_ID := "sp_som_keuzes"
const MOOI_ID := "sp_mooi"
const BORD_ID := "sp_bord"
const LEEG_ID := "sp_leeg"

## The easel on the left of the mat, its board facing into the room, and the
## guest of the turn on the right of the mat — never in front of the easel,
## and clear of the big board (`SpiegelBord`), which covers the left half of
## the frame: a miss is only his disappointed face, so it must be seen.
const EZEL_X := 26
const EZEL_Z := 66
const GAST_X := 80.0
const GAST_Z := 44.0

const KAART_HOOG := 36.0     ## the card's aim over the board (when it floats)
const BORD_HOOG := 20.0      ## the big board comes forward from this high on the easel
const BORD_MIN := 150.0      ## ... and is this wide at least
const BORD_MAX := 420.0      ## ... and at most
const MOOI_HOOG := 44.0

const SOM_S := 0.6           ## a right answer, then the next card this much later
const PLAK_S := 0.35         ## a dot sticks; the next one is asked after this
const AF_S := 3.4            ## the end card is readable this long before it closes
const LEEG_S := 1.8
const BLIJF_S := 1.5         ## how often the guest of the turn is kept at his spot

## The turn.  Lives in `ctx.data()["stand"]`; every number is read back through
## `int()`, because JSON hands them back as floats.
var S: Dictionary = {}
## The mask of today — purely a function of N, band and day (`Beurt.opzet`),
## so it is recomputed at every start and never saved.
var O: Dictionary = {}
var _kaart = null            ## Ui.Kaart
var _kaart_stap := ""        ## the step the card on screen was built for
var _t0 := 0
var _bezig := false          ## a dot is sticking: a second tap waits for it

# ------------------------------------------------------------- aanmelding

func definitie() -> Dictionary:
	# None of these may touch `self`: the registry reads `definitie()` from a
	# throwaway instance and frees it again (architecture.md §6.1).
	return {
		"naam": "Spiegelmaskers",
		"kamer": KAMER,
		"stub": false,
		"hotspot": {"obj": DOOS, "dx": EZEL_X - DOOS_X, "dz": EZEL_Z - DOOS_Z,
			"icoon": Beurt.ICOON, "label": Beurt.T_KNOP, "hoog": 34, "rust": RUST_EZEL},
		"modellen": Modellen.tabel(),
		"rust": [{"id": RUST_EZEL, "model": "spiegel_ezel", "x": float(EZEL_X),
			"z": float(EZEL_Z), "params": {}}],
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		"taak": {"id": "masker", "icoon": Beurt.ICOON, "tekst": Beurt.T_TITEL,
			"kamer": KAMER, "prio": 5},
	}

# ------------------------------------------------------------ start / stop

func start(_c: SpelCtx) -> void:
	for naam in Modellen.tabel():
		if not Art.heeft_model(naam):
			Art.registreer_model(naam, Modellen.tabel()[naam])
	var kies := _kandidaten()
	if kies.is_empty():
		_meld_leeg()
		return
	var d := ctx.data()
	var n: int = ctx.state.n_gasten()
	var band: int = ctx.state.band()
	var dag := int(ctx.state.s["dag"])
	var oud = d.get("stand", null)
	S = _normaliseer((oud as Dictionary).duplicate(true)) if typeof(oud) == TYPE_DICTIONARY else {}
	var g: Dictionary = {}
	if not S.is_empty():
		g = ctx.state.gast_van(str(S.get("gast", "")))
	# The animal the child picked on the game bar makes the mask, if he may
	# (world.md §5.8); a turn of another animal is simply not finished.
	var wil := ctx.voorkeur(spelers())
	# Resume only when the saved turn is still THIS turn — and the turn of the
	# picked animal: another one's is dropped (`weg`).
	var hervat := not (S.is_empty() or g.is_empty() or int(S["dag"]) != dag
			or int(S["N"]) != n or int(S["band"]) != band or _stap() == "af")
	var weg := ""
	if hervat and not wil.is_empty() and wil != _gast_id():
		weg = _gast_id()
		hervat = false
	if not hervat:
		g = kies[(dag + n) % kies.size()] if wil.is_empty() else ctx.state.gast_van(wil)
		S = _nieuwe_stand(g, n, band, dag)
	d["stand"] = S
	ctx.speelt(_gast_id())
	O = Beurt.opzet(n, band, dag)
	S["i"] = clampi(int(S["i"]), 0, (O["doel"] as Array).size())
	_t0 = Time.get_ticks_msec()
	_kaart = null
	_kaart_stap = ""
	_bezig = false
	# the easel first: the card hangs on it, so it must stand before the card
	# asks — and the card waits for the guest of the turn (`_begin`)
	_zet_ezel()
	State.bewaar()
	_begin()
	if not weg.is_empty() and weg != _gast_id():
		ctx.laat_gaan(weg)

func stop() -> void:
	if ctx != null:
		if not S.is_empty():
			ctx.data()["stand"] = S
			State.bewaar()
		World.decor_wis_eigenaar(ctx.id)
	S = {}
	O = {}
	_kaart = null
	_kaart_stap = ""
	_bezig = false

## Who makes the mask: everyone with a bed.  Nobody yet: the game says so and
## closes.
func _kandidaten() -> Array:
	var uit: Array = []
	for g in ctx.state.s["gasten"]:
		if not str(g.get("bed", "")).is_empty():
			uit.append(g)
	return uit

## Who may play when the child chooses the animal himself (the game bar,
## world.md §5.8): everyone with a bed, in check-in order.
func spelers() -> Array:
	var uit: Array = []
	for g in _kandidaten():
		uit.append(str(g.get("id", "")))
	return uit

func _meld_leeg() -> void:
	ctx.ui.wolk({"id": LEEG_ID, "kamer": KAMER, "op": "aan",
		"x": float(EZEL_X), "z": float(EZEL_Z), "hoog": 30.0,
		"icoon": "🛏", "tekst": Beurt.T_LEEG, "prio": 12})
	if not await na(LEEG_S):
		return
	ctx.ui.wolk_weg(LEEG_ID)
	ctx.sluit()

func _nieuwe_stand(g: Dictionary, n: int, band: int, dag: int) -> Dictionary:
	return {"gast": str(g.get("id", "")), "dag": dag, "N": n, "band": band,
		"stap": "som", "i": 0, "pog": 0, "missers": 0, "ster": 0}

## A turn that came through the save is JSON: every number a float.
static func _normaliseer(st: Dictionary) -> Dictionary:
	for k in ["dag", "N", "band", "i", "pog", "missers", "ster"]:
		st[k] = int(st.get(k, 0))
	st["gast"] = str(st.get("gast", ""))
	var stap := str(st.get("stap", "som"))
	st["stap"] = stap if stap in ["som", "plak", "af"] else "som"
	return st

func _stap() -> String:
	return str(S.get("stap", ""))

func _gast_id() -> String:
	return str(S.get("gast", ""))

func _bewaar() -> void:
	if ctx != null and not S.is_empty():
		ctx.data()["stand"] = S
		State.bewaar()

# ------------------------------------------------------------ de gast halen

## The guest of the turn first, then the sum (owner, 2026-09-23: "Zorg dat de
## minigame pas begint wanneer het dier er is").  The easel with the mask
## stands there at once; the card comes the moment the guest stands beside it
## — after a climb up the stairs with the hotel's "komt eraan" bubble when he
## comes from another floor (`ctx.wacht_op`).
func _begin() -> void:
	if not await ctx.wacht_op(_gast_id(), Vector2(GAST_X, GAST_Z)):
		if actief:
			ctx.sluit.call_deferred()      # the guest is gone
		return
	if not actief or S.is_empty() or O.is_empty():
		return
	_kaart_neer()
	_teken()
	_houd_bij_de_ezel()

## The guest of the turn stays beside the easel for the whole turn: a waiting
## guest starts to wander after sixteen seconds (world.md §2.6) and would stroll
## in front of the board.  Every BLIJF_S he is sent back when he is not there
## and not busy (a sulk after a miss, a happy hop at the end).
func _houd_bij_de_ezel() -> void:
	while actief and not S.is_empty():
		if not await na(BLIJF_S):
			return
		if S.is_empty():
			return
		var d = World.dier(_gast_id())
		if d == null or d.kamer != KAMER or not d.route.is_empty():
			continue
		if d.staat in ["sip", "blij", "eet", "slaap", "pose", "loop"]:
			continue
		if absf(d.x - GAST_X) + absf(d.z - GAST_Z) > 2.0:
			ctx.wereld.ga(_gast_id(), GAST_X, GAST_Z, "wacht")

# ------------------------------------------------------------------ de kaart

## The card for the step the turn is in.  Built once per step: a miss changes
## nothing on it, so the strip keeps its pause and its choices (S5) —
## rebuilding it would hand the child a fresh, unlocked strip.  Placing a dot
## only moves the sum line on (`_plak_regel`).
func _kaart_neer() -> void:
	if not actief or S.is_empty() or O.is_empty():
		return
	var stap := _stap()
	if _kaart != null and _kaart_stap == stap:
		return
	if _kaart != null:
		_kaart.weg()
		_kaart = null
	_kaart_stap = stap
	var o := {"id": KAART_ID, "kamer": KAMER, "hoog": KAART_HOOG, "icoon": Beurt.ICOON,
		"max": 3, "dier": _gast_id(), "titel": "het masker"}
	var som := ""
	match stap:
		"som":
			o["regel"] = Beurt.vraag(O)
			o["goed"] = int(O["goed"])
			o["liever"] = O["liever"]
			o["max_getal"] = 40
			o["on_ok"] = _antwoord
			som = str(O["som"])
		"plak":
			o["icoon"] = Beurt.ICOON_PLAK
			o["regel"] = Beurt.T_PLAK
			o["keuze_titel"] = "kies een kleur"
			var keuzes: Array = []
			for j in Beurt.MERKEN.size():
				var m: Dictionary = Beurt.MERKEN[j]
				keuzes.append({"id": str(m["id"]), "icoon": str(m["icoon"]),
					"tekst": str(m["tekst"]), "kort": str(m["tekst"]),
					"kies": _kies_knop(j)})
			o["keuzes"] = keuzes
			# no sum line while the dots are placed: the sum is done, and a
			# choice card has no box to count on in (`4 + 0 =` hung there)
		_:
			# the finished mask under the sum that was answered, with its answer
			o["icoon"] = Beurt.ICOON_AF
			o["regel"] = Beurt.T_AF
			o["regel2"] = Beurt.af2(O, _totaal())
			som = str(O["som"])
	_kaart = ctx.ui.somkaart(EZEL_ID, som, o)
	if _kaart == null:
		return
	if stap == "af":
		_kaart.klaar()
		_kaart.zet(str(int(O["goed"])))

## The dots to place.
func _aantal() -> int:
	return (O.get("doel", []) as Array).size()

## The dots on the finished mask.
func _totaal() -> int:
	return int(O.get("basis", 0)) + _aantal()

## One tap on the number strip.  Wrong: a soft sound, and that is all this game
## adds — the sulk, the pause and the same four numbers are `Ui`'s (S5), and no
## help follows a miss.  Right: a tick, a happy sound, and the first dot to
## place a moment later.
func _antwoord(n, k) -> void:
	if n == null or S.is_empty() or O.is_empty() or _stap() != "som":
		return
	if int(n) != int(O["goed"]):
		S["pog"] = int(S["pog"]) + 1
		S["missers"] = int(S["missers"]) + 1
		ctx.snd.zacht()
		_bewaar()
		return
	if k != null:
		k.zet(str(int(O["goed"])))
		k.klaar()
	ctx.snd.ja()
	S["pog"] = 0
	S["stap"] = "plak"
	S["i"] = 0
	_bewaar()
	if not await na(SOM_S):
		return
	if S.is_empty():
		return
	if _aantal() == 0:
		_klaar()
		return
	_kaart_neer()
	_teken()

# ------------------------------------------------------------------ plakken

## The strip calls a choice with its id and the card (`Ui.roep`); the colour it
## stands for is fixed when the button is made.
func _kies_knop(j: int) -> Callable:
	return func(_id = "", _k = null) -> void: _kies(j)

## One tap on a colour: is that mark the mirror image of the dot that shines?
## Right: the dot sticks there (a plop, sparkles on the board) and the next one
## shines.  Wrong: the animal is disappointed and the same question stays —
## nothing moves on the board.
func _kies(j: int) -> void:
	if S.is_empty() or O.is_empty() or _stap() != "plak" or _bezig:
		return
	var i := int(S["i"])
	var doel: Array = O["doel"]
	if i >= doel.size():
		return
	var d: Dictionary = doel[i]
	if j != int(d["goed"]):
		S["pog"] = int(S["pog"]) + 1
		S["missers"] = int(S["missers"]) + 1
		ctx.ui.misser(_kaart, _gast_id())
		_bewaar()
		_meld()
		return
	_bezig = true
	S["pog"] = 0
	S["i"] = i + 1
	ctx.snd.plop(1)
	var cel: Array = d["cel"]
	var p := Modellen.cel_midden(int(cel[0]), int(cel[1]), int(O["R"]), int(O["K"]), str(O["as"]))
	ctx.wereld.spetter(KAMER, float(EZEL_X) + p.x, float(EZEL_Z) + p.z, 5,
		Modellen.STIP, true, p.y)
	_bewaar()
	if int(S["i"]) >= doel.size():
		_klaar()
		return
	_teken()
	if not await na(PLAK_S):
		return
	_bezig = false

## The mask is done: the tick, the star, the guest is delighted, and a moment
## later the game closes itself.
func _klaar() -> void:
	S["stap"] = "af"
	_bezig = false
	ctx.state.tel(int(S["missers"]) == 0, Time.get_ticks_msec() - _t0)
	if int(S["ster"]) == 0:
		S["ster"] = 1
		ctx.taak_klaar("masker", {"sterren": 1})
	ctx.snd.hoera()
	_bewaar()
	_kaart_neer()
	_teken()
	for i in 3:
		ctx.wereld.spetter(KAMER, float(EZEL_X) + 1.0, float(EZEL_Z) - 10.0 + 10.0 * i, 6,
			Color("#FFD23F"), true, float(Modellen.POOT + 12))
	var id := _gast_id()
	if World.dier(id) != null:
		ctx.wereld.set_mood(id, "bouncy")
	if not await na(AF_S):
		return
	if S.is_empty() or _stap() != "af":
		return
	ctx.sluit()

# ------------------------------------------------------------------ tekenen

## The easel as it stands, as ONE piece of loose decor.  Re-issuing the same
## id replaces the piece: that is how a dot lands on the mask.
func _zet_ezel() -> void:
	ctx.wereld.decor(KAMER, {"id": EZEL_ID, "model": "spiegel_ezel",
		"x": float(EZEL_X), "z": float(EZEL_Z), "params": ezel_params()})

## What the mask shows right now: the dots, and while a dot is asked the three
## marks and the frame round its twin.
func ezel_params() -> Dictionary:
	var stip: Array = (O.get("stip", []) as Array).duplicate()
	var doel: Array = O.get("doel", [])
	var i := int(S.get("i", 0))
	for j in mini(i, doel.size()):
		stip.append((doel[j] as Dictionary)["cel"])
	var p := {"r": int(O.get("R", 4)), "k": int(O.get("K", 6)), "as": str(O.get("as", "v")),
		"stip": stip}
	if _stap() == "plak" and i < doel.size():
		p["merk"] = (doel[i] as Dictionary)["merk"]
		p["bron"] = (doel[i] as Dictionary)["bron"]
	return p

## Everything on the easel and around it, but never the card (see `_kaart_neer`).
func _teken() -> void:
	if not actief or ctx == null or S.is_empty() or O.is_empty():
		return
	_zet_ezel()
	_groot_bord()
	if _stap() == "af":
		var id := _gast_id()
		if World.dier(id) != null:
			ctx.ui.wolk({"id": MOOI_ID, "kamer": KAMER, "volg": _volg_dier(id),
				"hoog": MOOI_HOOG, "icoon": Beurt.ICOON_MOOI, "tekst": Beurt.T_MOOI,
				"klas": "goed", "prio": 12})
	ctx.wereld.vuil()
	_meld()

## The mask large and straight on (`SpiegelBord`), from the moment the card
## asks until the game closes: the easel on the side of the playroom is a
## thumbnail once the maths bar is docked.  It hangs in the FIXED layer, so a
## name plate steps aside for it and it never jumps.
func _groot_bord() -> void:
	var p := ezel_params()
	var s := Hits.spot(BORD_ID)
	if s != null and is_instance_valid(s.knoop) and s.knoop is SpiegelBord:
		(s.knoop as SpiegelBord).zet(p)
		return
	var bord := SpiegelBord.new()
	bord.meet = _bord_maat
	bord.zet(p)
	ctx.hotspots.maak({"id": BORD_ID, "kind": "eigen", "knoop": bord, "kamer": KAMER,
		"x": float(EZEL_X), "z": float(EZEL_Z), "y": BORD_HOOG, "op": "midden",
		"geen_vlak": true, "vast": true, "prio": 20, "volg": _volg_bord()})

## Every placement: the board stands as near to the easel as it can, but
## wholly in the free space over the maths bar.  `Hits` clamps it into the
## frame after that.
func _volg_bord() -> Callable:
	return func() -> Dictionary:
		var hoog: float = World.px_per_hoogte()
		if hoog <= 0.001:
			return {}
		var vrij := _bord_vrij()
		var maat := _bord_maat()
		var ezel: Vector2 = World.mik_punt(float(EZEL_X), float(EZEL_Z), BORD_HOOG)
		var y_mid := clampf(ezel.y, vrij.position.y + maat.y * 0.5,
			maxf(vrij.position.y + maat.y * 0.5, vrij.end.y - maat.y * 0.5))
		var vloer: float = World.mik_punt(float(EZEL_X), float(EZEL_Z), 0.0).y
		return {"x": float(EZEL_X), "z": float(EZEL_Z), "y": (vloer - y_mid) / hoog, "kamer": KAMER}

## Where the big board may stand: the frame over the maths bar, or — without a
## bar — over the floating card and its strip.
func _bord_vrij() -> Rect2:
	var kader := World.kader_rect().size
	var boven := float(Hits.RAND)
	var onder := kader.y - float(Hits.RAND)
	if Ui.balk_aan():
		onder = kader.y - Ui.balk_kost() - float(Hits.GAT)
	else:
		onder -= _kaart_ruimte()
	return Rect2(Vector2(float(Hits.RAND), boven),
		Vector2(maxf(0.0, kader.x - 2.0 * float(Hits.RAND)), maxf(0.0, onder - boven)))

## How tall the floating card with its strip under it is, plus the air between.
func _kaart_ruimte() -> float:
	var h := 0.0
	var k := Hits.spot(KAART_ID)
	if k != null and is_instance_valid(k.knoop) and k.knoop is UiSomkaart:
		h += Ui.kaart_mat(k.knoop as UiSomkaart).y + float(Hits.GAT)
	var st := Hits.spot(STROOK_ID)
	if st != null and is_instance_valid(st.knoop):
		h += (st.knoop as Control).get_combined_minimum_size().y + float(Hits.KLEEF)
	return h

## As large as the free space allows: its whole height, and at most three
## fifths of the width (the guest stands beside it).
func _bord_maat() -> Vector2:
	var vrij := _bord_vrij()
	var r := int(O.get("R", 4))
	var k := int(O.get("K", 6))
	var een := SpiegelBord.maat_bij(100.0, r, k)
	var breed := minf(vrij.size.x * 0.6, vrij.size.y * 0.92 * 100.0 / een.y)
	breed = clampf(breed, BORD_MIN, BORD_MAX)
	return SpiegelBord.maat_bij(floorf(breed), r, k)

func _volg_dier(id: String) -> Callable:
	return func() -> Dictionary:
		var d = World.dier(id)
		if d == null:
			return {}
		return {"x": d.x, "z": d.z, "kamer": d.kamer, "vlak": World.vlak_van_dier(id)}

# ------------------------------------------------------------------ probe

## The turn as the tests and the browser tools read it.
func stand() -> Dictionary:
	return S.duplicate(true)

func opzet() -> Dictionary:
	return O.duplicate(true)

## The colour of the right mark for the dot that is asked now, "" otherwise.
func goede_kleur() -> String:
	if _stap() != "plak" or O.is_empty():
		return ""
	var i := int(S.get("i", 0))
	var doel: Array = O["doel"]
	if i >= doel.size():
		return ""
	return str((Beurt.MERKEN[int((doel[i] as Dictionary)["goed"])] as Dictionary)["id"])

## Machine-readable lines for `tools/kiek.js` / `speel.js`, web export only.
func _meld() -> void:
	if not OS.has_feature("web"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not actief or S.is_empty() or O.is_empty():
		return
	print("[probe] spiegel stap=", _stap(), " band=", int(O["band"]), " N=", int(S["N"]),
		" goed=", int(O["goed"]),
		" i=", int(S["i"]), "/", _aantal(), " kleur=", goede_kleur(),
		" missers=", int(S["missers"]), " ster=", int(S["ster"]))
