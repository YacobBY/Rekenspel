extends MiniGame
## weeg — "Groenten wegen" (games-c.md §3).
##
## Rechts in de kas staat de grote marktweegschaal, met ernaast op de vloer de
## gewichten.  Een beurt is meten met een balans, in twee stappen:
##   1. de weegschaal staat recht met een pompoen links en gewichten rechts —
##      hoeveel kilo weegt de pompoen?  (de gewichten optellen)
##   2. er komt iets anders op (een meloen, een zak aardappels), de kaart zegt
##      wat het weegt, en het kind MAAKT dat getal met de gewichten (splitsen:
##      13 = 10 + 2 + 1) — precies goed, dan staat de balans recht.
## In groep 3 met 1, 2 en 5 kilo tot 10, in groep 4 met 10 kilo erbij tot 20,
## in groep 5 met 20 kilo erbij tot 60 — de reuzenpompoen.
##
## Rekenen eerst (PLAN.md R1): de leesvraag staat er meteen.  Golf 2 (eigenaar:
## "rekenen moet minstens 50% van de interactie zijn"): het opleggen was
## proberen tot de balans recht stond ("nog te licht", "te zwaar", "eraf"),
## tikken zonder getal.  Nu is elk gewicht een deel van een antwoord dat
## nagekeken wordt: te veel, of de schaal vol en nog te licht, is een misser.
## Een misser kost niets en helpt ook niet (HOTEL.md §9, S5; eigenaar
## 2026-09-24: "geef geen hulp na fouten"): de weger is sip met `🔄 Nog een
## keer`, na de pauze is de schaal weer leeg en staat dezelfde vraag er — geen
## telrij, geen bleek getal, geen recept, geen opmerking over licht of zwaar.
##
## De getallen komen uit `beurt.gd` (eigen gezaaide generator, `core/sommen.gd`
## blijft bevroren); de weegschaal met wat erop ligt is één model.

const KAMER := "kas"
const Modellen := preload("res://games/weeg/modellen.gd")
const Beurt := preload("res://games/weeg/beurt.gd")

const SCHAAL_ID := "wg_schaal"
const RUST_SCHAAL := "rust_wg_schaal"
## The pumpkin patch in the kas's front corner (fixed decor): the entry button
## is anchored to it and slid onto the scale.
const VELD := "pompoenen"
const VELD_X := 114
const VELD_Z := 100
const KAART_ID := "wg_som"
const STROOK_ID := "wg_som_keuzes"
const AF_ID := "wg_af"
const LEEG_ID := "wg_leeg"

## Where the balance stands, and the guest of the turn beside it (left of the
## thing's pan, so he never stands in front of what is being weighed).
const SCHAAL_X := 90
const SCHAAL_Z := 54
const GAST_X := 62.0
const GAST_Z := 88.0
## The stock of weights on the floor in front of the balance, one of each kind,
## in a row along the SCREEN'S horizontal (x + z = const, like the beam) round
## VOORRAAD, VOORRAAD_STAP apart: that is 40 voxel-px between two weights, room
## for the button of each to hang under its own weight.
const VOORRAAD := Vector2i(98, 78)
const VOORRAAD_STAP := 10
## The resting look: the level, empty balance and the four weights of groep 4.
const RUST_BAND := 4

const KAART_HOOG := 28.0
const AF_HOOG := 44.0

const SOM_S := 0.6
const RECHT_S := 0.9         ## level: a moment to see it, then the question
const BLIJF_S := 1.5         ## how often the guest of the turn is kept at his spot
const AF_S := 3.4
const LEEG_S := 1.8

var S: Dictionary = {}       ## the turn, in ctx.data()["stand"]
var O: Dictionary = {}       ## the turn of today (Beurt.opzet), never saved
var _kaart = null            ## Ui.Kaart
var _kaart_stap := ""
var _t0 := 0
var _bezig := false          ## the beam is level, or a miss pauses: weights wait

# ------------------------------------------------------------- aanmelding

func definitie() -> Dictionary:
	return {
		"naam": "Groenten wegen",
		"kamer": KAMER,
		"stub": false,
		"hotspot": {"obj": VELD, "dx": SCHAAL_X - VELD_X, "dz": SCHAAL_Z - VELD_Z,
			"icoon": Beurt.ICOON, "label": "Wegen", "hoog": 16, "rust": RUST_SCHAAL},
		"modellen": Modellen.tabel(),
		"rust": _rust(),
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		"taak": {"id": "weeg", "icoon": Beurt.ICOON, "tekst": "Weeg de groente",
			"kamer": KAMER, "prio": 7},
	}

## The level, empty balance and a row of weights, standing in the kas while
## nobody weighs (world.md §5.1): the entry button hangs on the balance.
static func _rust() -> Array:
	var uit: Array = [{"id": RUST_SCHAAL, "model": "weeg_schaal",
		"x": float(SCHAAL_X), "z": float(SCHAAL_Z), "params": {"kant": 0}}]
	var rek: Array = Beurt.REK[RUST_BAND]
	for i in rek.size():
		var p := voorraad_plek(i, rek.size())
		uit.append({"id": "rust_wg_kg%d" % int(rek[i]), "model": "weeg_gewicht",
			"x": float(p.x), "z": float(p.y), "params": {"kg": int(rek[i])}})
	return uit

## Where weight `i` of `n` in the stock stands: lightest on the left.
static func voorraad_plek(i: int, n: int) -> Vector2i:
	var t := roundi((float(i) - float(n - 1) * 0.5) * VOORRAAD_STAP)
	return Vector2i(VOORRAAD.x + t, VOORRAAD.y - t)

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
	# The animal the child picked on the game bar weighs, if he may (world.md
	# §5.8); a turn of another animal is simply not finished.
	var wil := ctx.voorkeur(spelers())
	# An open question that was missed comes back UNCHANGED (wave 2, R2): after
	# a new day, another N or band, an animal switch — the turn's numbers are
	# rebuilt from its own N, band and day, only the weigher may change.
	var vast := open_misser(S)
	var hervat := vast or not (S.is_empty() or g.is_empty() or int(S["dag"]) != dag
			or int(S["N"]) != n or int(S["band"]) != band or _stap() == "af")
	var weg := ""
	if hervat and not wil.is_empty() and wil != _gast_id():
		weg = _gast_id()
		if vast:
			S["gast"] = wil
		else:
			hervat = false
	elif vast and g.is_empty():
		S["gast"] = str(kies[(dag + n + 1) % kies.size()].get("id", ""))
	if not hervat:
		g = kies[(dag + n + 1) % kies.size()] if wil.is_empty() else ctx.state.gast_van(wil)
		S = _nieuwe_stand(g, n, band, dag)
	d["stand"] = S
	ctx.speelt(_gast_id())
	O = Beurt.opzet(int(S["N"]), int(S["band"]), int(S["dag"]))
	# a pan that was left over-full (the game stopped inside a miss's pause)
	# starts empty again for the same question
	if _stap() == "leg" and (Beurt.som(_pan()) > int(O["gewicht2"])
			or (_pan().size() >= Beurt.PAN_MAX and Beurt.som(_pan()) != int(O["gewicht2"]))):
		S["pan"] = []
	_t0 = Time.get_ticks_msec()
	_kaart = null
	_kaart_stap = ""
	_bezig = false
	# the balance and its weights stand there at once; the card waits for the
	# weigher (`_begin`)
	_zet_decor()
	State.bewaar()
	_begin()
	# the one whose turn was dropped makes room at the scale — after the new
	# guest was sent, so he walks off to a place the new one is not heading for
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

func _kandidaten() -> Array:
	var uit: Array = []
	for g in ctx.state.s["gasten"]:
		if not str(g.get("bed", "")).is_empty():
			uit.append(g)
	return uit

## Who may weigh when the child chooses the animal himself (the game bar,
## world.md §5.8): everyone with a bed, in check-in order.
func spelers() -> Array:
	var uit: Array = []
	for g in _kandidaten():
		uit.append(str(g.get("id", "")))
	return uit

func _meld_leeg() -> void:
	var v := World.mik(VELD, KAMER)
	ctx.ui.wolk({"id": LEEG_ID, "kamer": KAMER, "obj": VELD, "op": "aan",
		"x": float(v.get("x", VELD_X)), "z": float(v.get("z", VELD_Z)), "hoog": 12.0,
		"icoon": "🛏", "tekst": Beurt.T_LEEG, "prio": 12})
	if not await na(LEEG_S):
		return
	ctx.ui.wolk_weg(LEEG_ID)
	ctx.sluit()

func _nieuwe_stand(g: Dictionary, n: int, band: int, dag: int) -> Dictionary:
	return {"gast": str(g.get("id", "")), "dag": dag, "N": n, "band": band,
		"stap": "lees1", "pan": [], "pog": 0, "missers": 0, "acties": 0, "ster": 0}

static func _normaliseer(st: Dictionary) -> Dictionary:
	for k in ["dag", "N", "band", "pog", "missers", "acties", "ster"]:
		st[k] = int(st.get(k, 0))
	st["gast"] = str(st.get("gast", ""))
	var stap := str(st.get("stap", "lees1"))
	var pan: Array = []
	var bewaard = st.get("pan", [])
	if typeof(bewaard) == TYPE_ARRAY:
		for v in bewaard:
			if pan.size() < Beurt.PAN_MAX:
				pan.append(int(v))
	# a save from before wave 2 may stand in the reading step after the
	# balancing ("lees2"): it is the build again, from an empty pan
	if stap == "lees2":
		stap = "leg"
		pan = []
	st["stap"] = stap if stap in ["lees1", "leg", "af"] else "lees1"
	st["pan"] = pan
	return st

## Does this saved turn hold a question that was answered wrong and is still
## open?  Then nothing may replace it (wave 2, R2).
static func open_misser(st: Dictionary) -> bool:
	return not st.is_empty() and str(st.get("stap", "")) in ["lees1", "leg"] \
			and int(st.get("pog", 0)) > 0

func _stap() -> String:
	return str(S.get("stap", ""))

func _gast_id() -> String:
	return str(S.get("gast", ""))

func _pan() -> Array:
	var p = S.get("pan", [])
	return p if typeof(p) == TYPE_ARRAY else []

func _bewaar() -> void:
	if ctx != null and not S.is_empty():
		ctx.data()["stand"] = S
		State.bewaar()

# ------------------------------------------------------------ de gast halen

## The weigher first, then the first reading (owner, 2026-09-23: "Zorg dat de
## minigame pas begint wanneer het dier er is").  The balance with the pumpkin
## on it stands there at once; the card comes the moment the guest of the turn
## stands beside it — after a walk through the doors with the hotel's "komt
## eraan" bubble and its `👀 Volg` at the kas door when he comes from another
## room (`ctx.wacht_op`, games-c.md §3.6).
func _begin() -> void:
	if ctx == null:
		return
	if not await ctx.wacht_op(_gast_id(), Vector2(GAST_X, GAST_Z)):
		if actief:
			ctx.sluit.call_deferred()      # the weigher is gone
		return
	if not actief or S.is_empty() or O.is_empty():
		return
	_kaart_neer()
	_teken()
	# stopped in the moment the beam was level: that answer still counts
	if _stap() == "leg" and not _pan().is_empty() and Beurt.som(_pan()) == int(O["gewicht2"]):
		_na_gewicht()
	_houd_bij_de_schaal()

## The guest of the turn stays beside the balance for the whole turn: a waiting
## guest starts to wander after sixteen seconds (world.md §2.6), and he would
## stroll behind the pan and stand in the pumpkin.  Every BLIJF_S he is sent
## back to his spot when he is not there and not busy (a sip after a miss, a
## happy hop at the end).
func _houd_bij_de_schaal() -> void:
	var tel := 0
	while actief and not S.is_empty():
		if not await na(BLIJF_S):
			return
		if S.is_empty():
			return
		var d = World.dier(_gast_id())
		if d == null or d.kamer != KAMER or not d.route.is_empty():
			continue
		if d.staat in ["sip", "blij", "eet", "slaap", "pose"]:
			continue
		tel += 1
		var doel := Vector2(GAST_X, GAST_Z)
		if not d.punten.is_empty():
			doel = d.punten[d.punten.size() - 1]
		var thuis: bool = absf(d.x - GAST_X) + absf(d.z - GAST_Z) <= 2.0
		if doel.distance_to(Vector2(GAST_X, GAST_Z)) > 2.0 or (not thuis and d.staat != "loop") \
				or (thuis and d.staat == "wacht" and tel % 8 == 0):
			ctx.wereld.ga(_gast_id(), GAST_X, GAST_Z, "wacht")

# ------------------------------------------------------------------ de kaart

## The card for the step the turn is in, built once per step (a miss keeps the
## card, so `Ui`'s pause and its four choices survive — S5).
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
	var o := {"id": KAART_ID, "kamer": KAMER, "hoog": KAART_HOOG, "max": 2,
		"dier": _gast_id(), "titel": "de weegschaal"}
	var som := ""
	match stap:
		"lees1":
			o["icoon"] = Beurt.icoon(str(O["ding1"]))
			o["regel"] = Beurt.vraag(str(O["ding1"]))
			o["goed"] = int(O["gewicht1"])
			o["liever"] = Beurt.liever(O["set1"])
			o["on_ok"] = _antwoord
			som = Beurt.som_regel(O["set1"])
		"leg":
			# the weights on the card's own strip, pictogram and word: world
			# buttons on five small weights in a row drifted off them on every
			# frame the bands were full (owner, 2026-09-23: "labels floating
			# where they don't belong"); the strip docks with its card.  The
			# card says what the thing weighs; the child makes that number, so
			# every weight is part of a graded answer (wave 2, R1/R4)
			o["icoon"] = Beurt.icoon(str(O["ding2"]))
			o["regel"] = Beurt.maak(int(O["gewicht2"]))
			o["keuze_titel"] = Beurt.T_KG_TITEL
			o["keuzes"] = _gewicht_keuzes()
			o["reken"] = true
		_:
			o["icoon"] = Beurt.ICOON_AF
			o["regel"] = Beurt.af(str(O["ding2"]), int(O["gewicht2"]))
			som = Beurt.som_regel(_pan())
	_kaart = ctx.ui.somkaart(SCHAAL_ID, som, o)
	if _kaart == null:
		return
	if stap == "af":
		_kaart.klaar()
		_kaart.zet(str(int(O["gewicht2"])))

## One tap on the strip of the reading question.
func _antwoord(n, k) -> void:
	if n == null or S.is_empty() or O.is_empty():
		return
	if _stap() != "lees1":
		return
	var goed := int(O["gewicht1"])
	if int(n) != goed:
		S["pog"] = int(S["pog"]) + 1
		S["missers"] = int(S["missers"]) + 1
		ctx.snd.zacht()
		_bewaar()
		return
	if k != null:
		k.zet(str(goed))
		k.klaar()
	ctx.snd.ja()
	S["pog"] = 0
	S["stap"] = "leg"
	S["pan"] = []
	_bewaar()
	if not await na(SOM_S):
		return
	if S.is_empty():
		return
	# the pumpkin goes off, the next thing comes on: the beam drops to its side
	ctx.snd.plop(3)
	_kaart_neer()
	_teken()

# ------------------------------------------------------------------- wegen

## Put one weight of `kg` on the right pan (a tap on its button on the strip).
## The weights together are the answer to "make this many kilo" (wave 2): see
## `_na_gewicht` for how the build is checked.
func leg(kg: int) -> void:
	if S.is_empty() or O.is_empty() or _stap() != "leg" or _bezig:
		return
	if not (O["rek"] as Array).has(kg):
		return
	var pan := _pan()
	if pan.size() >= Beurt.PAN_MAX:
		return
	pan.append(kg)
	S["pan"] = pan
	S["acties"] = int(S["acties"]) + 1
	ctx.snd.gewicht()
	# the weight of that kind in the stock puffs: this is where it came from
	var i := (O["rek"] as Array).find(kg)
	if i >= 0:
		var p := voorraad_plek(i, (O["rek"] as Array).size())
		ctx.wereld.spetter(KAMER, float(p.x), float(p.y), 3,
			Modellen.GEWICHT_KL.get(kg, Modellen.GOUD), true, 4.0)
	_na_gewicht()

## After every weight the build is checked against the number on the card.
## Exactly that many kilo: the beam is level — a right answer, and a moment
## later the thing's weight stands under its sum.  Too many kilo, or the pan
## full and still too few: a miss — the weigher is disappointed (`Ui.misser`),
## the beam shows what lies there for the pause, and then the pan is empty
## again for the SAME question.  Below the number nothing is said: no "too
## light", no "too heavy" — the card already holds the number (owner,
## 2026-09-24: no help after a mistake).
func _na_gewicht() -> void:
	var t := Beurt.som(_pan())
	var doel := int(O["gewicht2"])
	_bewaar()
	_teken()
	if t == doel:
		_bezig = true
		ctx.snd.ja()
		ctx.reken_goed()
		S["pog"] = 0
		_bewaar()
		if not await na(RECHT_S):
			return
		if S.is_empty() or _stap() != "leg":
			return
		_bezig = false
		_klaar()
		return
	if t < doel and _pan().size() < Beurt.PAN_MAX:
		return
	_bezig = true
	S["pog"] = int(S["pog"]) + 1
	S["missers"] = int(S["missers"]) + 1
	ctx.ui.misser(_kaart, _gast_id())
	_bewaar()
	if not await na(Ui.MIS_PAUZE):
		return
	if S.is_empty() or _stap() != "leg":
		return
	S["pan"] = []
	_bezig = false
	ctx.snd.terug()
	_bewaar()
	_teken()

func _kant() -> int:
	if _stap() == "lees1":
		return 0
	return Beurt.kant(int(O["gewicht2"]), Beurt.som(_pan()))

func _klaar() -> void:
	S["stap"] = "af"
	ctx.state.tel(int(S["missers"]) == 0, Time.get_ticks_msec() - _t0)
	if int(S["ster"]) == 0:
		S["ster"] = 1
		ctx.taak_klaar("weeg", {"sterren": 1})
	ctx.snd.hoera()
	_bewaar()
	_kaart_neer()
	_teken()
	var id := _gast_id()
	if World.dier(id) != null:
		ctx.wereld.set_mood(id, "bouncy")
	if not await na(AF_S):
		return
	if S.is_empty() or _stap() != "af":
		return
	ctx.sluit()

# ------------------------------------------------------------------ tekenen

## The balance with what lies on it, and the stock of weights on the floor.
func _zet_decor() -> void:
	ctx.wereld.decor(KAMER, {"id": SCHAAL_ID, "model": "weeg_schaal",
		"x": float(SCHAAL_X), "z": float(SCHAAL_Z), "params": _schaal_params()})
	var rek: Array = O["rek"]
	for i in rek.size():
		var p := voorraad_plek(i, rek.size())
		ctx.wereld.decor(KAMER, {"id": _kg_id(int(rek[i])), "model": "weeg_gewicht",
			"x": float(p.x), "z": float(p.y), "params": {"kg": int(rek[i])}})

func _kg_id(kg: int) -> String:
	return "wg_kg%d" % kg

## One button per weight of this band, lightest first: "⬇ 5 kg".
func _gewicht_keuzes() -> Array:
	var uit: Array = []
	for kg in O["rek"]:
		var gewicht := int(kg)
		uit.append({"id": "kg%d" % gewicht, "icoon": Beurt.ICOON_LEG,
			# the bar always takes the short word, and four "⬇ 10 kg" are too
			# wide for a phone's bar: there it is "⬇ 10", like "🍓 37"
			"tekst": Beurt.T_KG % gewicht, "kort": str(gewicht),
			"titel": Beurt.T_KG % gewicht,
			"kies": func(_k, _kaart) -> void: leg(gewicht)})
	return uit

func _schaal_params() -> Dictionary:
	if _stap() == "lees1":
		return {"kant": 0, "l": str(O["ding1"]), "lm": int(O["maat1"]), "r": O["set1"]}
	return {"kant": _kant(), "l": str(O["ding2"]), "lm": int(O["maat2"]), "r": _pan()}

## Everything round the balance, but never the card (see `_kaart_neer`).  No
## "eraf" button and no remark about light or heavy any more (wave 2): the
## build is an answer, a wrong one is a miss and the pan empties by itself.
func _teken() -> void:
	if not actief or ctx == null or S.is_empty() or O.is_empty():
		return
	_zet_decor()
	var stap := _stap()
	if stap == "af":
		var id := _gast_id()
		if World.dier(id) != null:
			ctx.ui.wolk({"id": AF_ID, "kamer": KAMER, "volg": _volg_dier(id),
				"hoog": AF_HOOG, "icoon": Beurt.icoon(str(O["ding2"])),
				"getal": int(O["gewicht2"]), "tekst": "kilo", "klas": "goed", "prio": 12})
	ctx.wereld.vuil()
	_meld()

func _volg_dier(id: String) -> Callable:
	return func() -> Dictionary:
		var d = World.dier(id)
		if d == null:
			return {}
		return {"x": d.x, "z": d.z, "kamer": d.kamer, "vlak": World.vlak_van_dier(id)}

# ------------------------------------------------------------------ probe

func stand() -> Dictionary:
	return S.duplicate(true)

func opzet() -> Dictionary:
	return O.duplicate(true)

## The weights that make the second thing level, heaviest first (for tests and
## the browser tools).
func oplossing() -> Array:
	if O.is_empty():
		return []
	return Beurt.splits(int(O["gewicht2"]), O["rek"])

func _meld() -> void:
	if not OS.has_feature("web"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not actief or S.is_empty() or O.is_empty():
		return
	print("[probe] weeg stap=", _stap(), " band=", int(O["band"]),
		" gewicht1=", int(O["gewicht1"]), " gewicht2=", int(O["gewicht2"]),
		" pan=", _pan(), " kant=", _kant(), " missers=", int(S["missers"]),
		" ster=", int(S["ster"]))
	for id in Hits.debug().keys():
		if not str(id).begins_with("wg_"):
			continue
		var spot := Hits.spot(id)
		if spot == null or not is_instance_valid(spot.knoop) or not spot.knoop.visible:
			continue
		print("[probe] weegknop ", id, "=", spot.knoop.get_global_rect(),
			" dekking=", "%.2f" % Hits.dekking(id))
