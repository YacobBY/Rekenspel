extends MiniGame
## band — De dierenband in de muziekkamer (U2; eigenaar 2026-10-07: "Verzin
## nog vier kamers met activiteiten").  Design and state of the room:
## `.fanout/scratch/uitbreiding/U2-muziekkamer.md`.
##
## A turn:
##   1. The animal of the turn walks onto the stage, beside the big drum
##      (`ctx.wacht_op`).  Over them the stave stands large (`BandNotenbalk`):
##      one tile per bar, every note still pale.
##   2. "🔔 Luister en kijk goed": the drum plays the rhythm.  Every tick is a
##      `plop` (higher with every tick of the bar), a spark on the drumhead, a
##      nod of the animal AND one more lit note on the stave; a `klok` marks
##      every bar line.  The lit notes stay lit: with the sound off the child
##      counts them — the number lives in the world.
##   3. The card asks (`beurt.gd`): how many ticks (groep 3), how many ticks in
##      M bars (groep 4/5), how many bars for D ticks (groep 5, even days);
##      four numbers on the strip.  "🔄 Nog een keer luisteren" plays the
##      rhythm again whenever the child wants — it stands there from the
##      start, it is not a help that a miss unlocks.
##   4. Right: `ja`, the band plays (`hoera`, `tover`, a glow sweeps over the
##      stave), every animal in the music room cheers, one star.  Wrong: what
##      `Ui.misser` does and nothing more (owner, 2026-09-24: "geef geen hulp
##      na fouten") — the animal sulks, the strip pauses, the SAME question.
##
## The turn lives in `ctx.data()["stand"]`; the rhythm itself is a function of
## N, band, day and the number of turns finished today (`Beurt.opzet`), so a
## reload plays the very same rhythm and asks the very same question.  WHEN a
## note lights is this file's: sound and light come from the same line in
## `_speel_ritme`, one `na()` per tick, and a stop ends it at the next tick.

const Beurt := preload("res://games/band/beurt.gd")

const KAMER := "muziekkamer"
const KAART := "band_som"
const STROOK := "band_som_keuzes"
const BALK_ID := "band_balk"
const KNOP_NOG := "band_nog"
const LUISTER_ID := "band_luister"
const BLIJ_ID := "band_blij"
const LEEG_ID := "band_leeg"
## The props of the band, as the room shows them while nobody plays (`rust`,
## ids `rust_band_<id>`) and as the game puts them down while it runs (its own
## loose decor, ids `bd_<id>`): the drum on the stage, the xylophone, the
## upright piano against the back wall and the music stand.
const RUST := "rust_band_"
const EIGEN := "bd_"
const RUST_TROMMEL := "rust_band_trommel"
const TROMMEL_ID := "bd_trommel"
const SPULLEN := [
	{"id": "trommel", "model": "band_trommel", "x": 44.0, "z": 44.0},
	{"id": "xylofoon", "model": "band_xylofoon", "x": 66.0, "z": 30.0},
	{"id": "piano", "model": "band_piano", "x": 34.0, "z": 1.0},
	{"id": "standaard", "model": "band_standaard", "x": 24.0, "z": 34.0},
]
## The drum (16 × 16 voxels from its corner) and the music box of the room —
## the fixed thing the entry is anchored to, slid onto the drum (as
## spiegel's box → easel).
const TROMMEL_X := 44
const TROMMEL_Z := 44
const TROMMEL_MIDDEN := Vector2(52.0, 52.0)
const DOOS_X := 6
const DOOS_Z := 84
## Where the animal of the turn stands: on the stage, right of the drum.
const PLEK := Vector2(74.0, 56.0)
## Where "🔄 Nog een keer luisteren" aims: in front of the drum.
const NOG := Vector2(40.0, 70.0)
const VONK := Color("#F5D37A")

const KAART_HOOG := 30.0
const BALK_HOOG := 30.0     ## the stave's aim over the drum (when it floats)
const BALK_MAX := 900.0     ## px: the stave is at most this wide
const SOM_S := 0.5          ## the right answer, then the band plays this much later
const TOVER_S := 0.5        ## ... and the magic this much after the cheer
const AF_S := 3.4           ## the end is readable this long before it closes
const LEEG_S := 1.8
const BLIJF_S := 1.0        ## how often the animal of the turn is kept at the drum
const WACHT_BIJ := 45       ## world ticks: a wait this close to its end is renewed
const KNIK_POSE := "hap1"   ## a nod onto the drum: the head goes down
const KNIK_S := 0.2         ## a nod on a tick lasts this long ...
const KNIK_TIKKEN := 6      ## ... and the pose would hold this many world ticks (0.4 s)
## `Ui.misser` lets the animal sulk `Ui.SIP_TIKKEN` world ticks (15 a second);
## this long before that runs out the game puts him back to waiting at the drum.
const SIP_VOOR_S := 0.15

## The turn.  Every number is read back through `int()`: JSON hands floats.
var S: Dictionary = {}
## The rhythm and the question of this turn (`Beurt.opzet`) — recomputed at
## every start, never saved.
var O: Dictionary = {}
var _kaart = null           ## Ui.Kaart
var _kaart_stap := ""       ## the step the card on screen was built for
var _t0 := 0
var _ritme := 0             ## counts the rhythms started: an older one stops at its next tick
var _speelt := false        ## a rhythm is playing now

# ------------------------------------------------------------- aanmelding

func definitie() -> Dictionary:
	# None of these may touch `self`: the registry reads `definitie()` from a
	# throwaway instance and frees it again (architecture.md §6.1).
	var kan := func(s: Dictionary) -> bool:
		for g in s.get("gasten", []):
			if not str(g.get("bed", "")).is_empty():
				return true
		return false
	var rust: Array = []
	for stuk in SPULLEN:
		rust.append({"id": RUST + str(stuk["id"]), "model": str(stuk["model"]),
			"x": float(stuk["x"]), "z": float(stuk["z"]), "params": {}})
	return {
		"naam": "De dierenband",
		"kamer": KAMER,
		"stub": false,
		"hotspot": {"obj": "muziekdoos", "dx": TROMMEL_X - DOOS_X, "dz": TROMMEL_Z - DOOS_Z,
			"icoon": Beurt.ICOON, "label": Beurt.T_KNOP, "hoog": 30, "rust": RUST_TROMMEL},
		"modellen": ArtDecorMuziek.tabel(),
		"rust": rust,
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		"kan": kan,
		"taak": {"id": "band", "icoon": Beurt.ICOON, "tekst": Beurt.T_TITEL,
			"kamer": KAMER, "prio": 5},
	}

# ------------------------------------------------------------ start / stop

func start(_c: SpelCtx) -> void:
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
		g = ctx.state.gast_van(_gast_id())
	# The animal the child picked on the game bar plays the drum, if he may
	# (world.md §5.8); a turn of another animal is simply not finished.
	var wil := ctx.voorkeur(spelers())
	var hervat := not (S.is_empty() or g.is_empty() or str(g.get("bed", "")).is_empty()
			or int(S["dag"]) != dag or int(S["N"]) != n or int(S["band"]) != band
			or _stap() == "af")
	var weg := ""
	if hervat and not wil.is_empty() and wil != _gast_id():
		weg = _gast_id()
		hervat = false
	if not hervat:
		# a finished turn of today: the next one is another rhythm
		var nr := 0
		if not S.is_empty() and int(S["dag"]) == dag and _stap() == "af":
			nr = int(S["nr"]) + 1
		g = kies[(dag + n + nr) % kies.size()] if wil.is_empty() else ctx.state.gast_van(wil)
		S = _nieuwe_stand(g, n, band, dag, nr)
	d["stand"] = S
	ctx.speelt(_gast_id())
	O = Beurt.opzet(int(S["N"]), int(S["band"]), int(S["dag"]), int(S["nr"]))
	_t0 = Time.get_ticks_msec()
	_kaart = null
	_kaart_stap = ""
	_speelt = false
	# the band first: the stave and the card hang on the drum
	_zet_spullen()
	_balk_neer()
	State.bewaar()
	print("[probe] spel=start id=", ctx.id, " kamer=", ctx.kamer, " soort=", O["soort"],
		" goed=", O["goed"], " tikken=", O["tikken"], " gast=", _gast_id(), " stap=", _stap())
	_begin()
	if not weg.is_empty() and weg != _gast_id():
		ctx.laat_gaan(weg)

func stop() -> void:
	_ritme += 1
	_speelt = false
	if ctx != null:
		if not S.is_empty():
			ctx.data()["stand"] = S
			State.bewaar()
		World.decor_wis_eigenaar(ctx.id)
	S = {}
	O = {}
	_kaart = null
	_kaart_stap = ""

## Who can play the drum: everyone with a bed.  Nobody yet: the game says so
## and closes.
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
		"x": TROMMEL_MIDDEN.x, "z": TROMMEL_MIDDEN.y, "hoog": 30.0,
		"icoon": Beurt.ICOON_LEEG, "tekst": Beurt.T_LEEG, "prio": 12})
	if not await na(LEEG_S):
		return
	ctx.ui.wolk_weg(LEEG_ID)
	ctx.sluit()

## `stap`: "luister" until the rhythm was heard to its end once, then "som"
## (the card asks), then "af".
static func _nieuwe_stand(g: Dictionary, n: int, band: int, dag: int, nr: int) -> Dictionary:
	return {"gast": str(g.get("id", "")), "dag": dag, "N": n, "band": band, "nr": nr,
		"stap": "luister", "pog": 0, "missers": 0, "ster": 0}

## A turn that came through the save is JSON: every number a float.
static func _normaliseer(st: Dictionary) -> Dictionary:
	for k in ["dag", "N", "band", "nr", "pog", "missers", "ster"]:
		st[k] = int(st.get(k, 0))
	st["gast"] = str(st.get("gast", ""))
	var stap := str(st.get("stap", "luister"))
	st["stap"] = stap if stap in ["luister", "som", "af"] else "luister"
	return st

func _stap() -> String:
	return str(S.get("stap", ""))

func _gast_id() -> String:
	return str(S.get("gast", ""))

func _bewaar() -> void:
	if ctx != null and not S.is_empty():
		ctx.data()["stand"] = S
		State.bewaar()

# ------------------------------------------------------------ de beurt

## The animal of the turn first, then the music (owner, 2026-09-23: "Zorg dat
## de minigame pas begint wanneer het dier er is").  The stave stands there at
## once; the drum plays the moment the animal stands beside it — after a
## climb up the stairs with the hotel's "komt eraan" bubble when he comes from
## another floor.  A turn that already asked (a reload) asks again at once.
func _begin() -> void:
	if not await ctx.wacht_op(_gast_id(), PLEK):
		if actief:
			ctx.sluit.call_deferred()      # the animal is gone
		return
	if not actief or S.is_empty() or O.is_empty():
		return
	_kijk_naar_de_trommel()
	_knop_nog()
	if _stap() == "som":
		_kaart_neer()
	_houd_bij_de_trommel()
	_speel_ritme()

## "🔄 Nog een keer luisteren" — the rhythm from the start, as often as the
## child likes, also while it plays and while the card asks.
func nog_eens() -> void:
	if not actief or S.is_empty() or O.is_empty() or _stap() == "af":
		return
	_speel_ritme()

## The drum plays the bars the stave shows.  A newer rhythm (the child tapped
## 🔄 again), a right answer and a stop each end this one at its next tick.
func _speel_ritme() -> void:
	if not actief or S.is_empty() or O.is_empty() or _stap() == "af":
		return
	_ritme += 1
	var nr := _ritme
	_speelt = true
	_knik_af()              # a nod of the rhythm this one replaces
	var b := notenbalk()
	if b != null:
		b.doof()
	if _stap() == "luister":
		ctx.ui.wolk({"id": LUISTER_ID, "kamer": KAMER, "volg": _volg_dier(_gast_id()),
			"hoog": 46.0, "icoon": Beurt.ICOON_LUISTER, "tekst": Beurt.T_LUISTER, "prio": 12})
	ctx.snd.hup()
	_meld()
	var begin := Time.get_ticks_msec()
	if not await na(Beurt.VOOR_S):
		return
	if nr != _ritme:
		return
	var bars := Beurt.toon(O)
	var tik := Beurt.tik_s(O)
	var totaal := Beurt.tel_tikken(bars)
	var i := 0
	var knik := minf(KNIK_S, tik * 0.5)
	for m in bars.size():
		var k := (bars[m] as Array).size()
		for j in k:
			i += 1
			ctx.snd.plop(j + 1)
			b = notenbalk()
			if b != null:
				b.slag(i)
			_slag_in_de_wereld()
			_meld_slag(i, totaal)
			if not await na(knik):
				return
			if nr != _ritme:
				return
			_knik_af()
			if not await na(tik - knik):
				return
			if nr != _ritme:
				return
			_vraag_na(begin)
		if m < bars.size() - 1:
			ctx.snd.klok()
			if not await na(Beurt.MAAT_RUST_S):
				return
			if nr != _ritme:
				return
			_vraag_na(begin)
	_speelt = false
	if _stap() == "luister":
		_vraag()
	_meld()

## A long rhythm does not keep the card waiting (`Beurt.KAART_NA_S`).
func _vraag_na(begin: int) -> void:
	if _stap() == "luister" and float(Time.get_ticks_msec() - begin) / 1000.0 >= Beurt.KAART_NA_S:
		_vraag()

## The rhythm was heard (or played long enough): the card asks.
func _vraag() -> void:
	if S.is_empty() or _stap() != "luister":
		return
	S["stap"] = "som"
	_bewaar()
	ctx.ui.wolk_weg(LUISTER_ID)
	_kaart_neer()

## One tick, seen in the room: a spark jumps off the drumhead and the animal
## of the turn nods onto the drum — unless it is sulking about a miss.
func _slag_in_de_wereld() -> void:
	ctx.wereld.spetter(KAMER, TROMMEL_MIDDEN.x, TROMMEL_MIDDEN.y, 3, VONK, true,
		float(ArtDecorMuziek.TROMMEL_TOP))
	var d = World.dier(_gast_id())
	if d == null or d.kamer != KAMER or not str(d.reis_doel).is_empty() \
			or not (d.punten as Array).is_empty() or str(d.pose) == "sip" \
			or d.staat == "blij" or World.slaapt(_gast_id()):
		return
	_kijk_naar_de_trommel()
	# held a little longer than the nod lasts: `_knik_af` ends it, so the
	# world never gets to choose what he does next (a wander, world.md §2.6)
	World.pose(_gast_id(), KNIK_POSE, KNIK_TIKKEN)

## The nod is over: back to waiting at the drum, nose to it.
func _knik_af() -> void:
	var d = World.dier(_gast_id())
	if d == null or d.kamer != KAMER or d.staat != "pose" or str(d.pose) != KNIK_POSE:
		return
	World.blijf(_gast_id(), "wacht")
	_kijk_naar_de_trommel()

## The animal of the turn looks at the drum (his nose toward it on screen).
func _kijk_naar_de_trommel() -> void:
	var d = World.dier(_gast_id())
	if d == null or d.kamer != KAMER:
		return
	d.face = 1 if (TROMMEL_MIDDEN.x - TROMMEL_MIDDEN.y) - (d.x - d.z) >= 0.0 else -1
	World.vuil()

## The animal of the turn stays beside the drum for the whole turn: a waiting
## guest starts to wander after a while (world.md §2.6).  Every BLIJF_S he is
## sent back when he is not there and not busy (a nod, a sulk, a cheer).
func _houd_bij_de_trommel() -> void:
	while actief and not S.is_empty():
		if not await na(BLIJF_S):
			return
		if S.is_empty() or _stap() == "af":
			return
		var d = World.dier(_gast_id())
		if d == null or d.kamer != KAMER or not (d.route as Array).is_empty():
			continue
		if d.staat in ["sip", "blij", "eet", "slaap", "pose"]:
			continue
		var thuis: bool = absf(d.x - PLEK.x) + absf(d.z - PLEK.y) <= 2.0
		var doel := Vector2(d.x, d.z)
		if not (d.punten as Array).is_empty():
			doel = d.punten[(d.punten as Array).size() - 1]
		if doel.distance_to(PLEK) > 2.0:
			# wandering off, or standing elsewhere: back to the drum
			ctx.wereld.ga(_gast_id(), PLEK.x, PLEK.y, "wacht")
		elif thuis and (d.staat != "wacht" or int(d.tikken) < WACHT_BIJ):
			# a wait runs out after 16 s and then he may wander: renew it
			World.blijf(_gast_id(), "wacht")
			_kijk_naar_de_trommel()

# ------------------------------------------------------------------ de kaart

## The card for the step the turn is in.  Built once per step: a miss changes
## nothing on it, so the strip keeps its pause and its four numbers.
func _kaart_neer() -> void:
	if not actief or S.is_empty() or O.is_empty():
		return
	var stap := _stap()
	if stap == "luister" or (_kaart != null and _kaart_stap == stap):
		return
	if _kaart != null:
		_kaart.weg()
		_kaart = null
	_kaart_stap = stap
	var o := {"id": KAART, "kamer": KAMER, "hoog": KAART_HOOG, "icoon": Beurt.ICOON,
		"max": 2, "dier": _gast_id(), "titel": "de trommel"}
	if stap == "som":
		o["regel"] = Beurt.vraag(O)
		o["goed"] = int(O["goed"])
		o["min"] = int(O["min"])
		o["max_getal"] = int(O["max"])
		o["liever"] = O.get("liever", [])
		o["keuze_titel"] = "hoeveel"
		o["on_ok"] = _antwoord
	else:
		# the end: the sum that was answered, with its answer in it
		o["icoon"] = Beurt.ICOON_AF
		o["regel"] = Beurt.T_AF
		o["regel2"] = Beurt.af2(O)
	_kaart = ctx.ui.somkaart(TROMMEL_ID, str(O["som"]), o)
	if _kaart != null and stap == "af":
		_kaart.klaar()
		_kaart.zet(str(int(O["goed"])))
	_meld()

func antwoord(n: int) -> void:
	_antwoord(n, _kaart)

## Every tap on the strip lands here (`Ui.somkaart`: after a wrong tap too —
## the card has already shown `Ui.misser`).  Wrong: count it, a soft sound,
## nothing else.  Right: a tick, `ja`, and a moment later the band plays.
func _antwoord(n, k) -> void:
	if n == null or S.is_empty() or O.is_empty() or _stap() != "som":
		return
	if int(n) != int(O["goed"]):
		S["pog"] = int(S["pog"]) + 1
		S["missers"] = int(S["missers"]) + 1
		ctx.snd.zacht()
		_bewaar()
		print("[probe] band=mis n=", int(n), " missers=", int(S["missers"]))
		_meld()
		_na_het_mokken()
		return
	if k != null:
		k.zet(str(int(O["goed"])))
		k.klaar()
	ctx.snd.ja()
	# a rhythm that still plays ends here: the whole band plays now
	_ritme += 1
	_speelt = false
	_knik_af()
	S["pog"] = 0
	S["stap"] = "af"
	ctx.state.tel(int(S["missers"]) == 0, Time.get_ticks_msec() - _t0)
	if int(S["ster"]) == 0:
		S["ster"] = 1
		ctx.taak_klaar("band", {"sterren": 1})
	_bewaar()
	ctx.hotspots.weg(KNOP_NOG)
	ctx.ui.wolk_weg(LUISTER_ID)
	if not await na(SOM_S):
		return
	if S.is_empty() or _stap() != "af":
		return
	_klaar()

## The sulk of a miss (`Ui.misser`) is a pose of `Ui.SIP_TIKKEN` world ticks,
## after which the world would choose what he does next — perhaps a wander
## off the stage.  Just before that he goes back to waiting at the drum.
func _na_het_mokken() -> void:
	if not await na(maxf(0.1, float(Ui.SIP_TIKKEN) / 15.0 - SIP_VOOR_S)):
		return
	var d = World.dier(_gast_id())
	if S.is_empty() or _stap() != "som" or d == null or d.kamer != KAMER \
			or d.staat != "pose" or str(d.pose) != "sip":
		return
	World.blijf(_gast_id(), "wacht")
	_kijk_naar_de_trommel()

## The band plays: the end card, a glow over the whole stave, the fanfare,
## sparks off the drum, and every animal in the music room cheers.  A moment
## later the game closes itself.
func _klaar() -> void:
	_kaart_neer()
	var b := notenbalk()
	if b != null:
		b.feest()
	ctx.snd.hoera()
	for i in 3:
		ctx.wereld.spetter(KAMER, TROMMEL_MIDDEN.x - 4.0 + 4.0 * i, TROMMEL_MIDDEN.y, 6, VONK,
			true, float(ArtDecorMuziek.TROMMEL_TOP) + 2.0)
	_juich()
	var id := _gast_id()
	if World.dier(id) != null:
		ctx.ui.wolk({"id": BLIJ_ID, "kamer": KAMER, "volg": _volg_dier(id),
			"hoog": 46.0, "icoon": Beurt.ICOON_BLIJ, "tekst": Beurt.T_BLIJ,
			"klas": "goed", "prio": 12})
	print("[probe] spel=klaar sterren=", State.s["sterren"], " missers=", int(S["missers"]))
	_meld()
	if not await na(TOVER_S):
		return
	ctx.snd.tover()
	if not await na(AF_S):
		return
	if S.is_empty() or _stap() != "af":
		return
	ctx.sluit()

## Every animal in the music room cheers: the one of the turn and whoever came
## to listen.  Asleep is asleep.
func _juich() -> void:
	for d in World.dieren(KAMER):
		var id := str(d.id)
		if World.slaapt(id):
			continue
		ctx.wereld.set_mood(id, "bouncy")

# ------------------------------------------------------------------ de wereld

## The props as the game's own loose decor (the resting ones went when the
## game started, `Games.start`).
func _zet_spullen() -> void:
	for stuk in SPULLEN:
		ctx.wereld.decor(KAMER, {"id": EIGEN + str(stuk["id"]), "model": str(stuk["model"]),
			"x": float(stuk["x"]), "z": float(stuk["z"]), "params": {}})

## "🔄 Nog een keer luisteren", in front of the drum.
func _knop_nog() -> void:
	if Hits.spot(KNOP_NOG) != null:
		return
	ctx.hotspots.maak({"id": KNOP_NOG, "kamer": KAMER, "x": NOG.x, "z": NOG.y, "y": 6.0,
		"icoon": Beurt.ICOON_NOG, "label": Beurt.T_NOG, "titel": "luister nog een keer",
		"prio": 9, "aan": func(_s) -> void: nog_eens()})

## The stave, large and straight on, from the start of the turn until the
## game closes: in the free space over the drum and the animal of the turn, or
## under them — never over them.  It hangs in the FIXED layer, so a name plate
## steps aside for it and it never jumps.
func _balk_neer() -> void:
	if notenbalk() != null:
		return
	var b := BandNotenbalk.new()
	b.meet = _balk_maat
	b.zet(Beurt.toon(O), {"kleuren": Beurt.kleuren(O)})
	if _stap() == "som":
		b.alles_aan()       # a turn that comes back: the rhythm was heard
	ctx.hotspots.maak({"id": BALK_ID, "kind": "eigen", "knoop": b, "kamer": KAMER,
		"x": TROMMEL_MIDDEN.x, "z": TROMMEL_MIDDEN.y, "y": BALK_HOOG, "op": "midden",
		"geen_vlak": true, "vast": true, "prio": 20, "volg": _volg_balk()})

## The stave of this turn, or null.
func notenbalk() -> BandNotenbalk:
	var s = Hits.spot(BALK_ID)
	if s != null and is_instance_valid(s.knoop) and s.knoop is BandNotenbalk:
		return s.knoop as BandNotenbalk
	return null

## Every placement: the stave stands in its band, close to the drum — just over
## the animals' heads or just under their feet.  `Hits` clamps it into the
## frame after that.
func _volg_balk() -> Callable:
	return func() -> Dictionary:
		var vak: Dictionary = _balk_band()
		var r: Rect2 = vak["rect"]
		var maat := _balk_maat()
		if r.size.x <= 0.0 or maat.y <= 0.0:
			return {}
		var y: float = (r.end.y - maat.y * 0.5) if bool(vak["boven"]) \
			else (r.position.y + maat.y * 0.5)
		var groep := _groep_rect()
		var x := groep.get_center().x if groep.size.x > 0.0 else r.get_center().x
		x = clampf(x, r.position.x + maat.x * 0.5, maxf(r.position.x + maat.x * 0.5, r.end.x - maat.x * 0.5))
		return _punt_op(Vector2(x, y))

## The world point (in this room, at some height) that `World.mik_punt` puts
## on the screen point `doel` — the projection is affine, so three probes give
## it exactly (the photo booth's screen does the same).
func _punt_op(doel: Vector2) -> Dictionary:
	var z := TROMMEL_MIDDEN.y
	var o: Vector2 = World.mik_punt(0.0, z, 0.0)
	var ax: Vector2 = World.mik_punt(1.0, z, 0.0) - o
	var ay: Vector2 = World.mik_punt(0.0, z, 1.0) - o
	if absf(ax.x) < 0.0001 or absf(ay.y) < 0.0001:
		return {}
	var x := (doel.x - o.x) / ax.x
	var y := (doel.y - o.y - x * ax.y) / ay.y
	return {"x": x, "z": z, "y": y, "kamer": KAMER}

## Where the stave may stand at all: the frame over the maths bar, or —
## without a bar — over the floating card and its strip.
func _balk_vrij() -> Rect2:
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
	var k = Hits.spot(KAART)
	if k != null and is_instance_valid(k.knoop) and k.knoop is UiSomkaart:
		h += Ui.kaart_mat(k.knoop as UiSomkaart).y + float(Hits.GAT)
	var st = Hits.spot(STROOK)
	if st != null and is_instance_valid(st.knoop):
		h += (st.knoop as Control).get_combined_minimum_size().y + float(Hits.KLEEF)
	return h

## The band the stave goes in: the larger of the free space above the drum and
## its animal and the free space below them.  `{rect, boven}`.
func _balk_band() -> Dictionary:
	var vrij := _balk_vrij()
	var groep := _groep_rect()
	if groep.size.x <= 0.0:
		return {"rect": vrij, "boven": true}
	var gat := float(Hits.GAT)
	var boven := Rect2(vrij.position,
		Vector2(vrij.size.x, maxf(0.0, groep.position.y - gat - vrij.position.y)))
	var onder_y := maxf(vrij.position.y, groep.end.y + gat)
	var onder := Rect2(Vector2(vrij.position.x, onder_y),
		Vector2(vrij.size.x, maxf(0.0, vrij.end.y - onder_y)))
	if onder.size.y > boven.size.y:
		return {"rect": onder, "boven": false}
	return {"rect": boven, "boven": true}

## Where the drum and the animal of the turn are on the screen.  The drum is
## 16 × 16 voxels and about 17 high with its sticks; an animal about 28 long,
## 16 deep and 26 high.
func _groep_rect() -> Rect2:
	var r := Rect2()
	var eerste := true
	var punten: Array[Vector3] = []
	for hoek in [Vector3(0, 0, 0), Vector3(16, 0, 0), Vector3(0, 0, 16), Vector3(16, 0, 16),
			Vector3(0, 17, 0), Vector3(16, 17, 16)]:
		punten.append(Vector3(float(TROMMEL_X), 0.0, float(TROMMEL_Z)) + hoek)
	for hoek in [Vector3(-14, 0, -8), Vector3(14, 0, -8), Vector3(-14, 0, 8),
			Vector3(14, 0, 8), Vector3(-14, 26, 0), Vector3(14, 26, 0)]:
		punten.append(Vector3(PLEK.x, 0.0, PLEK.y) + hoek)
	for p in punten:
		var q: Vector2 = World.mik_punt(p.x, p.z, p.y)
		if eerste:
			r = Rect2(q, Vector2.ZERO)
			eerste = false
		else:
			r = r.expand(q)
	return r

## As large as its band allows, never wider than BALK_MAX — and never larger
## than the band: a stave grown past it would be pushed onto the drum (a
## single short bar of groep 3 is narrow and tall).
func _balk_maat() -> Vector2:
	if O.is_empty():
		return Vector2(48.0, 48.0)
	var vak: Rect2 = _balk_band()["rect"]
	var maat := BandNotenbalk.past(minf(vak.size.x * 0.96, BALK_MAX), vak.size.y * 0.96, Beurt.toon(O))
	return maat.floor()

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

func speelt() -> bool:
	return _speelt

## One line per tick, web export only: the evidence that the stave lights in
## time with the drum (`tools/speel.js` writes it next to its pictures).
func _meld_slag(i: int, totaal: int) -> void:
	if not OS.has_feature("web"):
		return
	var b := notenbalk()
	print("[probe] band slag=", i, "/", totaal, " aan=", b.aantal_aan() if b != null else -1)

## Machine-readable lines for `tools/kiek.js` / `speel.js`, web export only.
func _meld() -> void:
	if not OS.has_feature("web"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not actief or S.is_empty() or O.is_empty():
		return
	var b := notenbalk()
	print("[probe] band stap=", _stap(), " soort=", O["soort"], " band=", int(O["band"]),
		" N=", int(S["N"]), " goed=", int(O["goed"]), " som=", O["som"],
		" aan=", b.aantal_aan() if b != null else -1, "/", b.aantal() if b != null else -1,
		" speelt=", _speelt, " missers=", int(S["missers"]), " ster=", int(S["ster"]),
		" gast=", _gast_id())
	for id in Hits.debug().keys():
		if not str(id).begins_with("band_"):
			continue
		var spot = Hits.spot(id)
		if spot == null or not is_instance_valid(spot.knoop) or not spot.knoop.visible:
			continue
		print("[probe] ", id, "=", (spot.knoop as Control).get_global_rect())
		var rij := (spot.knoop as Control).get_node_or_null("Rij")
		if rij != null:
			var namen: Array[String] = []
			for k in rij.get_children():
				namen.append(str(k.name).trim_prefix("K"))
			print("[probe] band keuzes=", ",".join(namen))
