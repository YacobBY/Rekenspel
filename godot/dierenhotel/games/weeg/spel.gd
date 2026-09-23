extends MiniGame
## weeg — "Groenten wegen" (games-c.md §3).
##
## Rechts in de kas staat de grote marktweegschaal, met ernaast op de vloer de
## gewichten.  Een beurt is meten met een balans, in drie stappen:
##   1. de weegschaal staat recht met een pompoen links en gewichten rechts —
##      hoeveel kilo weegt de pompoen?  (de gewichten optellen)
##   2. er komt iets anders op (een meloen, een zak aardappels) en de balans
##      zakt naar die kant: leg zelf gewichten op tot hij weer recht staat — hij
##      helt naar de zwaarste kant, dus het kind vergelijkt vóór het optelt;
##   3. hoeveel kilo weegt het dan?  (de eigen gewichten optellen)
## In groep 3 met 1, 2 en 5 kilo tot 10, in groep 4 met 10 kilo erbij tot 20,
## in groep 5 met 20 kilo erbij tot 60 — de reuzenpompoen.
##
## Rekenen eerst (PLAN.md R1): de leesvraag staat er meteen.  Een misser kost
## niets (HOTEL.md §9, S5): de strook van `Ui` doet de pauze en dezelfde vier
## keuzes, dit spel de hulpladder in een wolkje bij de weegschaal.  Te zwaar is
## geen fout: de balans helt gewoon de andere kant op, en "eraf" haalt het
## laatste gewicht er weer af.
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
const ERAF_ID := "wg_eraf"
const ZEG_ID := "wg_zeg"
const HULP_ID := "wg_hulp"
const SPOOK_ID := "wg_spook"
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
const ZEG_HOOG := 20.0
const SPOOK_HOOG := 14.0
const AF_HOOG := 44.0

const SOM_S := 0.6
const RECHT_S := 0.9         ## level: a moment to see it, then the question
const BLIJF_S := 1.5         ## how often the guest of the turn is kept at his spot
const AF_S := 3.4
const LEEG_S := 1.8
const GAST_POLL := 0.7
const GAST_KEER := 24
const SPOOK_NA := 3          ## the ghost number at the third miss on a question
const SPOOK_LEG := 8         ## and the recipe after eight weights up and down

var S: Dictionary = {}       ## the turn, in ctx.data()["stand"]
var O: Dictionary = {}       ## the turn of today (Beurt.opzet), never saved
var _kaart = null            ## Ui.Kaart
var _kaart_stap := ""
var _kaart_hulp := ""        ## the help line the card carries now (small frames)
var _t0 := 0
var _gast_gestuurd := false
var _gast_keer := 0

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
	if S.is_empty() or g.is_empty() or int(S["dag"]) != dag or int(S["N"]) != n \
			or int(S["band"]) != band or _stap() == "af":
		g = kies[(dag + n + 1) % kies.size()]
		S = _nieuwe_stand(g, n, band, dag)
	d["stand"] = S
	O = Beurt.opzet(n, band, dag)
	_t0 = Time.get_ticks_msec()
	_kaart = null
	_kaart_stap = ""
	_gast_gestuurd = false
	_gast_keer = 0
	_zet_decor()
	_kaart_neer()
	_teken()
	State.bewaar()
	_haal_gast()

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

func _kandidaten() -> Array:
	var uit: Array = []
	for g in ctx.state.s["gasten"]:
		if not str(g.get("bed", "")).is_empty():
			uit.append(g)
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
	st["stap"] = stap if stap in ["lees1", "leg", "lees2", "af"] else "lees1"
	var pan: Array = []
	var bewaard = st.get("pan", [])
	if typeof(bewaard) == TYPE_ARRAY:
		for v in bewaard:
			if pan.size() < Beurt.PAN_MAX:
				pan.append(int(v))
	st["pan"] = pan
	return st

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

func _haal_gast() -> void:
	if ctx == null:
		return
	var g: Dictionary = ctx.state.gast_van(_gast_id())
	if g.is_empty():
		return
	var id := str(g["id"])
	var d = World.dier(id)
	if d == null:
		return
	while d != null and d.kamer != KAMER:
		if not _gast_gestuurd:
			_gast_gestuurd = true
			ctx.wereld.reis(id, KAMER, {"x": GAST_X, "z": GAST_Z, "na": "wacht"})
			g["waar"] = KAMER
		if _gast_keer >= GAST_KEER:
			return
		_gast_keer += 1
		if not await na(GAST_POLL):
			return
		if S.is_empty():
			return
		d = World.dier(id)
	g["waar"] = KAMER
	var _gehaald: bool = await ctx.wereld.loop_naar(id, GAST_X, GAST_Z, {"na": "wacht"})
	if not actief or S.is_empty():
		return
	ctx.wereld.vuil()
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
	_kaart_hulp = ""
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
			# where they don't belong"); the strip docks with its card
			o["icoon"] = Beurt.ICOON
			o["regel"] = Beurt.T_RECHT
			o["keuze_titel"] = Beurt.T_KG_TITEL
			o["keuzes"] = _gewicht_keuzes()
		"lees2":
			o["icoon"] = Beurt.icoon(str(O["ding2"]))
			o["regel"] = Beurt.vraag(str(O["ding2"]))
			o["goed"] = Beurt.som(_pan())
			o["liever"] = Beurt.liever(_pan())
			o["on_ok"] = _antwoord
			som = Beurt.som_regel(_pan())
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

## One tap on the strip, for either reading question.
func _antwoord(n, k) -> void:
	if n == null or S.is_empty() or O.is_empty():
		return
	var stap := _stap()
	if stap != "lees1" and stap != "lees2":
		return
	var goed := int(O["gewicht1"]) if stap == "lees1" else Beurt.som(_pan())
	if int(n) != goed:
		S["pog"] = int(S["pog"]) + 1
		S["missers"] = int(S["missers"]) + 1
		ctx.snd.zacht()
		_bewaar()
		_teken()
		return
	if k != null:
		k.zet(str(goed))
		k.klaar()
	ctx.snd.ja()
	S["pog"] = 0
	if stap == "lees2":
		_klaar()
		return
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

## Put one weight of `kg` on the right pan (a tap on it, or a drag).
func leg(kg: int) -> void:
	if S.is_empty() or O.is_empty() or _stap() != "leg":
		return
	if not (O["rek"] as Array).has(kg):
		return
	var pan := _pan()
	if pan.size() >= Beurt.PAN_MAX:
		ctx.snd.zacht()
		_zeg(Beurt.ICOON_HULP, Beurt.T_VOL)
		_bewaar()
		_teken()
		return
	pan.append(kg)
	S["pan"] = pan
	S["acties"] = int(S["acties"]) + 1
	ctx.snd.plop(1)
	# the weight of that kind in the stock puffs: this is where it came from
	var i := (O["rek"] as Array).find(kg)
	if i >= 0:
		var p := voorraad_plek(i, (O["rek"] as Array).size())
		ctx.wereld.spetter(KAMER, float(p.x), float(p.y), 3,
			Modellen.GEWICHT_KL.get(kg, Modellen.GOUD), true, 4.0)
	_na_gewicht()

## Lift the last weight off again.  Never a penalty: the beam just follows.
func eraf() -> void:
	if S.is_empty() or O.is_empty() or _stap() != "leg":
		return
	var pan := _pan()
	if pan.is_empty():
		return
	pan.pop_back()
	S["pan"] = pan
	S["acties"] = int(S["acties"]) + 1
	ctx.snd.terug()
	_na_gewicht()

## After every weight: where does the beam lean, and is it level?
func _na_gewicht() -> void:
	var k := _kant()
	if k < 0:
		_zeg(Beurt.ICOON_LICHT, Beurt.T_LICHT)
	elif k > 0:
		_zeg(Beurt.ICOON_ZWAAR, Beurt.T_ZWAAR)
	else:
		_zeg(Beurt.ICOON, Beurt.T_PRECIES, "goed")
	_bewaar()
	_teken()
	if k != 0:
		return
	ctx.snd.ja()
	var voor := Beurt.som(_pan())
	if not await na(RECHT_S):
		return
	if S.is_empty() or _stap() != "leg" or Beurt.som(_pan()) != voor:
		return
	S["stap"] = "lees2"
	S["pog"] = 0
	_zeg_weg()
	_bewaar()
	_kaart_neer()
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
	_zeg_weg()
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

## A short remark at the balance: which way it leans, or that the pan is full.
func _zeg(icoon: String, tekst: String, klas := "hulp") -> void:
	S["zeg"] = {"icoon": icoon, "tekst": tekst, "klas": klas}

func _zeg_weg() -> void:
	S.erase("zeg")

## Everything round the balance, but never the card (see `_kaart_neer`).
func _teken() -> void:
	if not actief or ctx == null or S.is_empty() or O.is_empty():
		return
	_zet_decor()
	var stap := _stap()
	var rek: Array = O["rek"]
	if stap == "leg" and not _pan().is_empty():
		ctx.hotspots.maak({"id": ERAF_ID, "kamer": KAMER, "obj": SCHAAL_ID, "op": "aan",
			"x": float(SCHAAL_X), "z": float(SCHAAL_Z), "y": 12.0,
			"icoon": Beurt.ICOON_ERAF, "label": Beurt.T_ERAF, "titel": Beurt.T_ERAF_TITEL,
			"prio": 12, "aan": func(_s) -> void: eraf()})
	else:
		ctx.hotspots.weg(ERAF_ID)
	# the remark of the last weight: a bubble at the balance on a tablet, the
	# card's help line on a phone (no room beside the balance there)
	var z: Dictionary = S.get("zeg", {}) if typeof(S.get("zeg", {})) == TYPE_DICTIONARY else {}
	if stap == "leg" and not z.is_empty() and not _klein_kader():
		ctx.ui.wolk({"id": ZEG_ID, "kamer": KAMER, "obj": SCHAAL_ID, "op": "aan",
			"x": float(SCHAAL_X), "z": float(SCHAAL_Z), "hoog": ZEG_HOOG,
			"icoon": str(z.get("icoon", "")), "tekst": str(z.get("tekst", "")),
			"klas": str(z.get("klas", "hulp")), "prio": 10})
	else:
		ctx.ui.wolk_weg(ZEG_ID)
	# the help ladder: count along, and at the third miss the answer pale on
	# the balance; while weighing, after many weights, the recipe
	var lees := stap == "lees1" or stap == "lees2"
	var lijst: Array = O["set1"] if stap == "lees1" else _pan()
	var hulp := ""
	if lees and int(S["pog"]) >= 1:
		hulp = Beurt.hulp(lijst)
	elif stap == "leg" and int(S["acties"]) >= SPOOK_LEG:
		hulp = " + ".join(PackedStringArray(Beurt.splits(int(O["gewicht2"]), rek).map(
			func(v): return str(v))))
	# in a bubble at the balance on a tablet (a help line would push the card
	# out of the maths bar), on a phone as the card's help line (no room for a
	# bubble beside the balance there) — see oogst `_klein_kader`
	if hulp.is_empty() or _klein_kader():
		ctx.ui.wolk_weg(HULP_ID)
	else:
		ctx.ui.wolk({"id": HULP_ID, "kamer": KAMER, "obj": SCHAAL_ID, "op": "aan",
			"x": float(SCHAAL_X), "z": float(SCHAAL_Z), "hoog": ZEG_HOOG,
			"icoon": Beurt.ICOON_HULP, "tekst": hulp, "klas": "hulp", "prio": 11})
	var op_kaart := hulp if _klein_kader() else ""
	if op_kaart.is_empty() and _klein_kader() and stap == "leg" and not z.is_empty():
		op_kaart = ("%s %s" % [str(z.get("icoon", "")), str(z.get("tekst", ""))]).strip_edges()
	if _kaart != null and stap != "af" and op_kaart != _kaart_hulp:
		_kaart_hulp = op_kaart
		_kaart.hulp(op_kaart)
	if lees and int(S["pog"]) >= SPOOK_NA:
		ctx.ui.getal_tag(SCHAAL_ID, str(Beurt.som(lijst)), {"id": SPOOK_ID, "kamer": KAMER,
			"y": SPOOK_HOOG, "klas": "hotspook", "prio": 7, "titel": Beurt.T_SPOOK})
	else:
		ctx.ui.getal_tag(SCHAAL_ID, null, {"id": SPOOK_ID})
	if stap == "af":
		var id := _gast_id()
		if World.dier(id) != null:
			ctx.ui.wolk({"id": AF_ID, "kamer": KAMER, "volg": _volg_dier(id),
				"hoog": AF_HOOG, "icoon": Beurt.icoon(str(O["ding2"])),
				"getal": int(O["gewicht2"]), "tekst": "kilo", "klas": "goed", "prio": 12})
	ctx.wereld.vuil()
	_meld()

func _klein_kader() -> bool:
	var k := World.kader_rect().size
	return k.x > 0.0 and minf(k.x, k.y) < 400.0

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
