extends MiniGame
## foto — het fotohokje van de Winkelstraat (eigenaar, 2026-10-01: "Ik wil bij
## de winkel ook graag een fotohokje maken waar je minimaal 2 dieren moet kiezen
## die op de foto gaan en de prijs per dier daaronder en dan een hoe veel geld
## je moet inwerpen").
##
## The booth stands at the end of the row of stalls (`fotohokje`, decor of the
## arcade).  A turn:
##   1. "📸 Wie gaan er op de foto?" — the strip holds the animals that may go
##      (at most four) and, from the second one on, "📸 Klaar".  Every animal
##      the child taps walks to the booth, looks at it and steps INTO it
##      through the curtain (owner, 2026-10-06: "kan het echt in het hokje
##      geanimeerd worden van een camera hokje PoV met alle dieren die erin
##      zitten"): he is gone from the street (`World.verstop`) and the booth's
##      screen, large in front (`FotoScherm`), shows him sitting inside — a
##      frame per animal, and under every frame the price per animal, the same
##      for everyone, as in a real booth.
##   2. When they all sit inside: "💶 Hoeveel geld gooi je erin?" with the sum
##      under it (groep 3 `€2 + €2 + €2 =`, from groep 4 `3 × €2 =`) and four
##      amounts on the strip (`beurt.gd`).
##   3. Right: the coins drop in, the screen counts 3 – 2 – 1, the shutter
##      clicks and the photo develops — and one star.  Then the animals come
##      out again, happy.
##
## A WRONG AMOUNT SENDS THEM OUT, as in every shop of the street (owner,
## 2026-09-24, `WinkelSpel`): the card goes at once, the animals come out of the
## booth, sulk ("😞 Dat klopt niet"), walk slowly away with their heads down,
## and the game closes by itself.  A tap on the booth brings the same animals
## back and the SAME question — the turn is in the save.  No help, no hint,
## nothing taken away.  Whatever ends the game, nobody stays inside (`stop`).

const KAMER := "winkels"
const Beurt := preload("res://games/foto/beurt.gd")

const HOKJE := "fotohokje"
const HOKJE_X := 144.0
const HOKJE_Z := 12.0
const KAART_HOOG := 44.0
const KAART_ID := "ft_kaart"
const STROOK_ID := "ft_kaart_keuzes"
const SCHERM_ID := "ft_scherm"
const WEG_ID := "ft_weg"
const BLIJ_ID := "ft_blij"
const LEEG_ID := "ft_leeg"

## Where the animals stand for the photo, in the order they were chosen: in
## front of the booth on the street, the first right before the cabin, in two
## rows so that four of them stay four animals and not one heap.
const PLEKKEN := [Vector2(140, 28), Vector2(124, 30), Vector2(132, 42), Vector2(116, 42)]
## Where each of them walks to, slowly, when the money was wrong.
const BUITEN := [Vector2(122, 70), Vector2(96, 54), Vector2(104, 88), Vector2(78, 70)]

const SOM_S := 0.6        ## a choice, then the next card this much later
const STAP_IN_S := 0.3    ## at the booth: a look at it, then in through the curtain
const TEL_S := 0.6        ## the countdown on the screen: 3, 2, 1, each this long
const ONTWIKKEL_S := 1.0  ## the shutter, the photo develops — then they come out
const AF_S := 3.5         ## out and happy: this long before the game closes
## The curtain of the cabin, where an animal steps in: a few teal sparkles of
## the curtain's own colour.
const GORDIJN := Vector2(141, 21)
const GORDIJN_N := 6
const LEEG_S := 1.8
const SIP_TIKKEN := 18    ## the sulk before they walk out (1,2 s)
const SIP_S := 1.2
const WEG_TEMPO := 0.4    ## the slow, sad walk out (`World.stappen` tempo)
const WEG_WACHT := 0.5    ## out: this long, then the game closes
const WEG_MAX := 12.0     ## never wait longer than this for the walk out
const BLIJF_S := 1.5      ## how often the animals are kept at the booth
const SCHERM_MIN := 180.0 ## the screen is at least this wide ...
const SCHERM_MAX := 600.0 ## ... and at most this wide

## The turn.  Lives in `ctx.data()["stand"]`; every number is read back through
## `int()`, because JSON hands them back as floats.
var S: Dictionary = {}
## Today's booth: the price per animal and who may go on the photo — a function
## of the hotel, the band and the day, so it is recomputed at every start.
var O: Dictionary = {}
var _kaart = null          ## Ui.Kaart
var _kaart_sleutel := ""   ## the step (and the choice so far) the card on screen was built for
var _t0 := 0
## Who stepped into the booth, in the order they did — the screen has them in
## the same order.  Not saved: after a reload everyone walks to the booth and
## steps in again.
var _binnen: Array[String] = []
var _gaat_in: Dictionary = {}   ## id -> true while he walks there to step in
## Once the money question is on screen, the booth's screen keeps the size and
## the side of the animals it had then, and its place as long as that still
## lies in its band, until the game closes: a wrong amount lets the maths bar
## go, the room grows into the frame, and a screen that grew along with it
## during the sad walk out looked like a glitch.  `{kader, maat, boven,
## midden}`; empty until the question is up.
var _vast: Dictionary = {}

# ------------------------------------------------------------- aanmelding

func definitie() -> Dictionary:
	# None of these may touch `self`: the registry reads `definitie()` from a
	# throwaway instance and frees it again (architecture.md §6.1).
	var kan := func(s: Dictionary) -> bool:
		var n := 0
		for g in s.get("gasten", []):
			if not str(g.get("bed", "")).is_empty():
				n += 1
		return n >= 2
	return {
		"naam": "Fotohokje",
		"kamer": KAMER,
		"stub": false,
		"hotspot": {"obj": HOKJE, "icoon": Beurt.ICOON, "label": Beurt.T_KNOP, "hoog": 46},
		"unlock": func(n: int, _band: int) -> bool: return n >= 2,
		"kan": kan,
	}

# ------------------------------------------------------------ start / stop

func start(_c: SpelCtx) -> void:
	var alle := _met_bed()
	if alle.size() < Beurt.MIN_DIEREN:
		_meld_leeg()
		return
	var d := ctx.data()
	var n: int = ctx.state.n_gasten()
	var band: int = ctx.state.band()
	var dag := int(ctx.state.s["dag"])
	var oud = d.get("stand", null)
	S = _normaliseer((oud as Dictionary).duplicate(true)) if typeof(oud) == TYPE_DICTIONARY else {}
	var hervat := not (S.is_empty() or int(S["dag"]) != dag or int(S["N"]) != n
			or int(S["band"]) != band or _stap() == "af")
	if hervat:
		# an animal that left the hotel is not on the photo any more
		var nog: Array = []
		for id in S["dieren"]:
			if alle.has(str(id)) and World.dier(str(id)) != null:
				nog.append(str(id))
		S["dieren"] = nog
		if _stap() == "som" and nog.size() < Beurt.MIN_DIEREN:
			S["stap"] = "kies"
	else:
		S = _nieuwe_stand(n, band, dag)
	# back at the booth: the animals that were sent out walk back in
	S["weg"] = 0
	d["stand"] = S
	# a group photo has no animal of the turn on the game bar
	ctx.speelt("")
	O = {"prijs": Beurt.prijs(n, band, dag), "pool": _pool(alle, n, dag)}
	_t0 = Time.get_ticks_msec()
	_kaart = null
	_kaart_sleutel = ""
	_binnen.clear()
	_gaat_in.clear()
	_vast = {}
	State.bewaar()
	_begin()

func stop() -> void:
	# nobody stays inside the booth, whatever the turn was doing: every animal
	# of the photo is on the street again (also one that was still on his way)
	for id in S.get("dieren", []):
		World.verstop(str(id), false)
	for id in _binnen:
		World.verstop(id, false)
	_binnen.clear()
	_gaat_in.clear()
	_vast = {}
	if ctx != null:
		if not S.is_empty():
			ctx.data()["stand"] = S
			State.bewaar()
		World.decor_wis_eigenaar(ctx.id)
	S = {}
	O = {}
	_kaart = null
	_kaart_sleutel = ""

## Everyone with a bed, in check-in order.
func _met_bed() -> Array:
	var uit: Array = []
	for g in ctx.state.s["gasten"]:
		if not str(g.get("bed", "")).is_empty():
			uit.append(str(g.get("id", "")))
	return uit

## Who may play when the child chooses the animal himself (the game bar,
## world.md §5.8): everyone with a bed.
func spelers() -> Array:
	return _met_bed()

## Who may go on the photo today: at most four (the strip holds four).  The
## ones already chosen first, then the animal the child picked on the game bar,
## then the others from a place that moves on every day.
func _pool(alle: Array, n: int, dag: int) -> Array:
	var uit: Array = []
	for id in S.get("dieren", []):
		if not uit.has(str(id)):
			uit.append(str(id))
	var wil := ctx.voorkeur(alle)
	if not wil.is_empty() and not uit.has(wil):
		uit.append(wil)
	var begin := (dag + n) % alle.size()
	for i in alle.size():
		var id := str(alle[(begin + i) % alle.size()])
		if not uit.has(id):
			uit.append(id)
	return uit.slice(0, Beurt.MAX_DIEREN)

func _meld_leeg() -> void:
	ctx.ui.wolk({"id": LEEG_ID, "kamer": KAMER, "op": "aan",
		"x": HOKJE_X, "z": HOKJE_Z, "hoog": 30.0,
		"icoon": "🛏", "tekst": Beurt.T_LEEG, "prio": 12})
	if not await na(LEEG_S):
		return
	ctx.ui.wolk_weg(LEEG_ID)
	ctx.sluit()

func _nieuwe_stand(n: int, band: int, dag: int) -> Dictionary:
	return {"dag": dag, "N": n, "band": band, "stap": "kies", "dieren": [],
		"pog": 0, "missers": 0, "weg": 0, "ster": 0}

## A turn that came through the save is JSON: every number a float.
static func _normaliseer(st: Dictionary) -> Dictionary:
	for k in ["dag", "N", "band", "pog", "missers", "weg", "ster"]:
		st[k] = int(st.get(k, 0))
	var stap := str(st.get("stap", "kies"))
	st["stap"] = stap if stap in ["kies", "som", "af"] else "kies"
	var dieren: Array = []
	var oud = st.get("dieren", [])
	if typeof(oud) == TYPE_ARRAY:
		for id in oud:
			if not dieren.has(str(id)) and dieren.size() < Beurt.MAX_DIEREN:
				dieren.append(str(id))
	st["dieren"] = dieren
	return st

func _stap() -> String:
	return str(S.get("stap", ""))

func _dieren() -> Array:
	return S.get("dieren", [])

func _prijs() -> int:
	return int(O.get("prijs", 0))

func _goed() -> int:
	return Beurt.goed(_dieren().size(), _prijs())

func _bewaar() -> void:
	if ctx != null and not S.is_empty():
		ctx.data()["stand"] = S
		State.bewaar()

# ------------------------------------------------------------ de beurt

## The screen first, then the card.  Choosing needs nobody at the booth: the
## card is there at once.  The sum waits until every animal on the photo sits
## inside the booth (owner, 2026-09-23: "Zorg dat de minigame pas begint
## wanneer het dier er is").
func _begin() -> void:
	_scherm_neer()
	for i in _dieren().size():
		_stuur(i)
	if _stap() == "som":
		_naar_de_som()
		return
	_kaart_neer()
	_teken()

## Animal `i` of the photo walks to its place at the booth and steps in there
## (`_stap_in`) — unless he is inside already or on his way in.  Nobody waits
## for this; `_naar_de_som` does.
func _stuur(i: int) -> void:
	var id := str(_dieren()[i])
	if World.dier(id) == null or _binnen.has(id) or _gaat_in.has(id):
		return
	_stap_in(id, PLEKKEN[i])

## At his place in front of the booth he looks at it, and a moment later he
## steps in through the curtain.  Should something take him away in that
## moment, he walks back and tries again.
func _stap_in(id: String, plek: Vector2) -> void:
	_gaat_in[id] = true
	while actief and _mag_in(id):
		if not await ctx.wacht_op(id, plek):
			break
		if not actief or not _mag_in(id):
			break
		World.pose(id, "kijk", 5)
		if not await na(STAP_IN_S):
			return
		if not _mag_in(id):
			break
		if _bij_het_hokje(id, plek):
			_in_het_hokje(id)
			break
	_gaat_in.erase(id)

## May `id` still step in: the turn chooses or asks the money, nobody was sent
## out, he is on the photo and not inside yet.
func _mag_in(id: String) -> bool:
	return not S.is_empty() and _stap() in ["kies", "som"] and int(S.get("weg", 0)) == 0 \
		and _dieren().has(id) and not _binnen.has(id)

## Still at his place in front of the booth: in this room, not travelling, as
## near as `ctx.wacht_op` counts "there".  Standing still is not asked: the
## look (5 think ticks) may just have run out into an idle step, and the step
## in stops that where he is (`World.verstop`).
func _bij_het_hokje(id: String, plek: Vector2) -> bool:
	var d = World.dier(id)
	return d != null and d.kamer == KAMER and str(d.reis_doel).is_empty() \
		and (d.route as Array).is_empty() \
		and Vector2(d.x, d.z).distance_to(plek) <= SpelCtx.WACHT_MARGE

## In through the curtain: a swish, he is gone from the street, a few teal
## sparkles at the curtain — and only then the screen shows him inside (it
## lets him come in itself).
func _in_het_hokje(id: String) -> void:
	ctx.snd.zwiep()
	World.verstop(id, true)
	ctx.wereld.spetter(KAMER, GORDIJN.x, GORDIJN.y, GORDIJN_N, ArtDecorWinkels.HOKJE_GORDIJN)
	_binnen.append(id)
	var sch := _scherm()
	if sch != null:
		sch.dieren = sch.dieren + [id]
	_meld()

func kies_dier(id: String) -> void:
	_kies_dier(id)

## One animal more on the photo.  Not a sum: nothing is right or wrong.
func _kies_dier(id: String) -> void:
	if S.is_empty() or _stap() != "kies" or _dieren().has(id) \
			or _dieren().size() >= Beurt.MAX_DIEREN or not (O.get("pool", []) as Array).has(id):
		return
	_dieren().append(id)
	ctx.snd.plop(_dieren().size())
	if World.dier(id) != null:
		World.pose(id, "blijA", 6)
	_bewaar()
	_stuur(_dieren().size() - 1)
	_scherm_neer()
	# everyone who may go is chosen: on to the money at once
	if _dieren().size() >= mini(Beurt.MAX_DIEREN, (O.get("pool", []) as Array).size()):
		_naar_de_som()
		return
	_kaart_neer()
	_teken()

func klaar() -> void:
	_klaar_gekozen()

## "📸 Klaar": the photo has its animals.
func _klaar_gekozen() -> void:
	if S.is_empty() or _stap() != "kies" or _dieren().size() < Beurt.MIN_DIEREN:
		return
	_naar_de_som()

## The money question, as soon as everybody sits inside the booth.  Until then
## there is no card: the hotel shows who is still on the way (`komt eraan`).
func _naar_de_som() -> void:
	S["stap"] = "som"
	_bewaar()
	if _kaart != null:
		_kaart.weg()
		_kaart = null
	_kaart_sleutel = ""
	_scherm_neer()
	_teken()
	# whoever is not inside yet walks there and steps in ...
	for i in _dieren().size():
		_stuur(i)
	# ... and the question waits until they all are
	while not _allemaal_binnen():
		if not await na(SpelCtx.WACHT_TIK):
			return
		if S.is_empty() or _stap() != "som" or int(S.get("weg", 0)) == 1:
			return
		for id in _dieren():
			if World.dier(str(id)) == null:
				ctx.sluit.call_deferred()      # an animal is gone
				return
		for i in _dieren().size():
			_stuur(i)                          # one whose walk in ended is sent again
	if not await na(SOM_S * 0.5):
		return
	if S.is_empty() or _stap() != "som" or int(S.get("weg", 0)) == 1:
		return
	_kaart_neer()
	_teken()
	_houd_bij_het_hokje()

## Does everybody on the photo sit inside the booth?
func _allemaal_binnen() -> bool:
	for id in _dieren():
		if not _binnen.has(str(id)):
			return false
	return true

## The animals stay at the booth for the whole turn (a waiting guest starts to
## wander after a while, world.md §2.6) — unless they were sent out.  One who
## sits inside is left alone: hidden, he stands still in there.  One the game
## still has inside whom something else showed again (a new day:
## `World.zet_dag`) is walked back to his place and steps in again there,
## unseen — the photo is never taken with him standing outside.
func _houd_bij_het_hokje() -> void:
	var tel := 0
	while actief and not S.is_empty():
		if not await na(BLIJF_S):
			return
		if S.is_empty() or int(S.get("weg", 0)) == 1:
			return
		tel += 1
		var dieren := _dieren()
		for i in dieren.size():
			var id := str(dieren[i])
			var d = World.dier(id)
			if d == null or d.kamer != KAMER or not (d.route as Array).is_empty():
				continue
			if World.verstopt(id):
				continue
			var plek: Vector2 = PLEKKEN[i]
			var thuis: bool = absf(d.x - plek.x) + absf(d.z - plek.y) <= 2.0
			if _binnen.has(id) and thuis and (d.punten as Array).is_empty():
				World.verstop(id, true)
				continue
			if d.staat in ["sip", "blij", "eet", "slaap", "pose"]:
				continue
			var doel := plek
			if not (d.punten as Array).is_empty():
				doel = d.punten[(d.punten as Array).size() - 1]
			if doel.distance_to(plek) > 2.0 or (not thuis and d.staat != "loop") \
					or (thuis and d.staat == "wacht" and tel % 8 == 0):
				ctx.wereld.ga(id, plek.x, plek.y, "wacht")

func antwoord(n: int) -> void:
	_antwoord(n, _kaart)

## One tap on an amount.  Wrong: out of the booth (see the header).  Right: the
## coins drop in, the countdown, the flash, and the photo.
func _antwoord(n: int, k) -> void:
	if S.is_empty() or O.is_empty() or _stap() != "som" or int(S.get("weg", 0)) == 1:
		return
	if n != _goed():
		_weggestuurd()
		return
	if k != null:
		k.zet(Beurt.euro(n))
		k.klaar()
	ctx.snd.munt()
	S["stap"] = "af"
	_bewaar()
	_klaar()

## Paid: the star, then the screen counts down 3, 2, 1 with a tick for every
## digit, the shutter clicks and flashes, the photo develops, and the animals
## come out of the booth, happy.  Then the game closes by itself.
func _klaar() -> void:
	ctx.state.tel(int(S["missers"]) == 0, Time.get_ticks_msec() - _t0)
	if int(S["ster"]) == 0:
		S["ster"] = 1
		ctx.taak_klaar("foto", {"sterren": 1})
	_bewaar()
	for n in [3, 2, 1]:
		var sch := _scherm()
		if sch != null:
			sch.tel(n)
		ctx.snd.tik()
		_meld()
		if not await na(TEL_S):
			return
		if S.is_empty() or _stap() != "af":
			return
	_scherm_neer()
	var scherm := _scherm()
	if scherm != null:
		scherm.tel(0)
	ctx.snd.klik()
	if scherm != null:
		scherm.klik()
	ctx.wereld.spetter(KAMER, HOKJE_X - 3.0, HOKJE_Z + 8.0, 10, Color("#FFF6D6"), true, 20.0)
	ctx.snd.hoera()
	_kaart_neer()
	_teken()
	if not await na(ONTWIKKEL_S):
		return
	if S.is_empty() or _stap() != "af":
		return
	ctx.snd.tover()
	_kom_naar_buiten()
	_teken()
	if not await na(AF_S):
		return
	if S.is_empty() or _stap() != "af":
		return
	ctx.sluit()

## Out of the booth with the photo: every animal on the street again, one
## swish for the whole group, and they bounce for joy (`set_mood` sets the
## cheer itself; a pose before it would be overwritten in the same call).
func _kom_naar_buiten() -> void:
	for id in _dieren():
		if World.dier(str(id)) != null:
			World.verstop(str(id), false)
			ctx.wereld.set_mood(str(id), "bouncy")
	_binnen.clear()
	ctx.snd.zwiep()

## A wrong amount: out of the booth, slowly (see the header).  The step stays
## where it was, so the same question waits when they come back.
func _weggestuurd() -> void:
	S["weg"] = 1
	S["pog"] = int(S["pog"]) + 1
	S["missers"] = int(S["missers"]) + 1
	_bewaar()
	ctx.snd.zacht()
	# nothing is left to tap: the card and its strip go at once
	if _kaart != null:
		_kaart.weg()
		_kaart = null
	_kaart_sleutel = ""
	# out of the booth first: the screen lets them go, and they stand on the
	# street again before they sulk and walk away
	var sch := _scherm()
	if sch != null:
		sch.vertrek()
	for id in _dieren():
		World.verstop(str(id), false)
	_binnen.clear()
	var dieren := _dieren().duplicate()
	if dieren.is_empty() or World.dier(str(dieren[0])) == null:
		ctx.sluit.call_deferred()
		return
	for id in dieren:
		if World.dier(str(id)) != null:
			World.pose(str(id), "sip", SIP_TIKKEN)
	# the first one says it with its own sad little sound, in the place of
	# the `zacht()` above (Snd §de dieren)
	ctx.snd.dier_sip(str(dieren[0]))
	ctx.ui.wolk({"id": WEG_ID, "kamer": KAMER, "volg": _volg_dier(str(dieren[0])), "hoog": 46.0,
		"icoon": Beurt.ICOON_WEG, "tekst": Beurt.T_WEG, "prio": 12})
	_meld()
	if not await na(SIP_S):
		return
	var t0 := Time.get_ticks_msec()
	for i in dieren.size():
		_loop_weg(str(dieren[i]), BUITEN[i % BUITEN.size()])
	# wait until they are out (or until the walk was taken over by something else)
	while actief:
		if not await na(0.2):
			return
		var allemaal := true
		for i in dieren.size():
			var d = World.dier(str(dieren[i]))
			if d == null:
				continue
			var buiten: Vector2 = BUITEN[i % BUITEN.size()]
			var er: bool = (d.punten as Array).is_empty() and Vector2(d.x, d.z).distance_to(buiten) <= 3.0
			if not er and d.staat == "loop":
				allemaal = false
		if allemaal or (Time.get_ticks_msec() - t0) / 1000.0 > WEG_MAX:
			break
	if not await na(WEG_WACHT):
		return
	ctx.sluit()

## The walk out: slow, head down, and a sulk when he gets there.  A world order,
## so it goes on when the game closes on the way.
func _loop_weg(id: String, naar: Vector2) -> void:
	await World.stappen(id, [naar], {"pose": "sjok", "tempo": WEG_TEMPO, "na": "sip"})

# ------------------------------------------------------------------ de kaart

## The card for the step the turn is in.  While choosing it changes with every
## animal (the strip holds the ones still free), so it is built again then.
func _kaart_neer() -> void:
	if not actief or S.is_empty() or O.is_empty():
		return
	var stap := _stap()
	var sleutel := "%s|%s" % [stap, str(_dieren())]
	if _kaart != null and _kaart_sleutel == sleutel:
		return
	if _kaart != null:
		_kaart.weg()
		_kaart = null
	_kaart_sleutel = sleutel
	var dieren := _dieren()
	var o := {"id": KAART_ID, "kamer": KAMER, "hoog": KAART_HOOG, "icoon": Beurt.ICOON,
		"max": 3, "titel": "het fotohokje",
		"dier": str(dieren[0]) if not dieren.is_empty() else ""}
	var som := ""
	match stap:
		"kies":
			o["regel"] = Beurt.T_KIES
			o["keuzes"] = _kies_keuzes()
			o["keuze_titel"] = "kies wie er op de foto gaat"
		"som":
			o["icoon"] = Beurt.ICOON_GELD
			o["regel"] = Beurt.T_SOM
			o["keuzes"] = _geld_keuzes()
			o["keuze_titel"] = "kies hoeveel geld"
			som = Beurt.som(dieren.size(), _prijs(), int(S["band"]))
		_:
			o["icoon"] = Beurt.ICOON_AF
			o["regel"] = Beurt.T_AF
			som = Beurt.som(dieren.size(), _prijs(), int(S["band"]))
	var plek := {"x": HOKJE_X, "z": HOKJE_Z, "kamer": KAMER}
	_kaart = ctx.ui.somkaart(plek, som, o)
	if _kaart != null and stap == "af":
		_kaart.klaar()
		_kaart.zet(Beurt.euro(_goed()))

## The choice: a button per animal that may still go, its own picture and its
## name, and from the second animal on "📸 Klaar" — four buttons at most.
func _kies_keuzes() -> Array:
	var uit: Array = []
	var klaar := _dieren().size() >= Beurt.MIN_DIEREN
	var plek := Ui.MAX_KEUZES - (1 if klaar else 0)
	for id in O.get("pool", []):
		if _dieren().has(str(id)) or uit.size() >= plek:
			continue
		var g: Dictionary = ctx.state.gast_van(str(id))
		if g.is_empty():
			continue
		var naam := str(g.get("naam", ""))
		var dier_id := str(id)
		uit.append({"id": "d_" + dier_id,
			"icoon": str(Hotel.DIER_ICOON.get(str(g.get("kind", "hond")), "🐾")),
			"tekst": naam, "kort": naam, "titel": "%s gaat op de foto" % naam,
			"kies": func(_id, _k) -> void: _kies_dier(dier_id)})
	if klaar:
		uit.append({"id": "klaar", "icoon": Beurt.ICOON, "tekst": Beurt.T_KLAAR,
			"kort": Beurt.T_KLAAR, "titel": "klaar, maak de foto",
			"kies": func(_id, _k) -> void: _klaar_gekozen()})
	return uit

## Four amounts, one of them right (`Afleiders.vier`); the same four in the same
## order every time this question comes back.
func _geld_keuzes() -> Array:
	var aantal := _dieren().size()
	var zaad := Beurt.zaad(int(S["N"]), int(S["band"]), int(S["dag"]), aantal)
	var getallen := Afleiders.vier(_goed(), zaad,
		{"min": 1, "max": 99, "liever": Beurt.liever(aantal, _prijs())})
	var uit: Array = []
	for g in getallen:
		var n: int = g
		uit.append({"id": "n%d" % n, "icoon": "", "tekst": Beurt.euro(n), "kort": str(n),
			"titel": "%d euro" % n,
			"kies": func(_id, k) -> void: _antwoord(n, k)})
	return uit

# ------------------------------------------------------------------ tekenen

func _teken() -> void:
	if not actief or ctx == null or S.is_empty() or O.is_empty():
		return
	if _stap() == "af":
		# the 😍 hangs on the first animal once he is out of the booth again
		var dieren := _dieren()
		if not dieren.is_empty() and World.dier(str(dieren[0])) != null \
				and not World.verstopt(str(dieren[0])):
			ctx.ui.wolk({"id": BLIJ_ID, "kamer": KAMER, "volg": _volg_dier(str(dieren[0])),
				"hoog": 46.0, "icoon": "😍", "tekst": Beurt.T_BLIJ, "klas": "goed", "prio": 12})
	ctx.wereld.vuil()
	_meld()

## The booth's screen large and straight on (`FotoScherm`), from the first card
## until the game closes, in the free space above the animals at the booth or
## below them — never over them: a wrong amount is only their sad faces.  It
## gets the price here; the animals it gets one by one as they step in
## (`_in_het_hokje`), the countdown and the shutter from `_klaar`.
func _scherm_neer() -> void:
	var sch := _scherm()
	if sch != null:
		sch.zet(_prijs())
		return
	var scherm := FotoScherm.new()
	scherm.meet = _scherm_maat
	scherm.zet(_prijs())
	if not _binnen.is_empty():
		scherm.dieren = _binnen.duplicate()
	ctx.hotspots.maak({"id": SCHERM_ID, "kind": "eigen", "knoop": scherm, "kamer": KAMER,
		"x": HOKJE_X, "z": HOKJE_Z, "y": 40.0, "op": "midden",
		"geen_vlak": true, "vast": true, "prio": 20, "volg": _volg_scherm()})

## The booth's screen while the game has it, or null.
func _scherm() -> FotoScherm:
	var s := Hits.spot(SCHERM_ID)
	if s != null and is_instance_valid(s.knoop) and s.knoop is FotoScherm:
		return s.knoop as FotoScherm
	return null

## Every placement: the screen stands in the middle of its band, close to the
## animals — just over their heads, or just under their feet
## (`_scherm_stand`).  `Hits` clamps it into the frame after that.
func _volg_scherm() -> Callable:
	return func() -> Dictionary:
		var st := _scherm_stand()
		if (st["rect"] as Rect2).size.x <= 0.0 or (st["maat"] as Vector2).y <= 0.0:
			return {}
		return _punt_op(st["midden"])

## The size `Hits` puts the screen down at (`FotoScherm.meet`).
func _scherm_maat() -> Vector2:
	return _scherm_stand()["maat"]

## Where the screen goes and how large it is: `{rect, boven, maat, midden}` —
## its band (`_scherm_band`), on which side of the animals that is, its size,
## and the frame point its middle goes on.  As large as the band allows: at
## most `SCHERM_MAX` wide, never narrower than `SCHERM_MIN` (its price tags
## stay readable) unless the band itself is, and NEVER HIGHER than the band:
## on a phone on its side (740x360) the band above the animals is 115 high,
## lower than the smallest screen at its own shape (136), so the screen's
## picture gets wider for its height instead (`FotoScherm._indeling`).  While
## the money question is on screen this is written down, and from then on the
## size, the side and the place hold (`_vast`) — the place as long as it still
## lies in the band.
func _scherm_stand() -> Dictionary:
	var kader := World.kader_rect().size
	var vraag := _stap() == "som" and int(S.get("weg", 0)) == 0 and _kaart != null
	var vast := not vraag and not _vast.is_empty() \
		and (_vast["kader"] as Vector2).is_equal_approx(kader)
	var band := _scherm_band(_vast["boven"] if vast else null)
	var vak: Rect2 = band["rect"]
	var boven := bool(band["boven"])
	var maat: Vector2
	if vast:
		var m: Vector2 = _vast["maat"]
		maat = Vector2(minf(m.x, vak.size.x), minf(m.y, vak.size.y))
	else:
		var breed := minf(vak.size.x * 0.92, vak.size.y * 0.96 / FotoScherm.maat_bij(1.0).y)
		breed = minf(clampf(breed, SCHERM_MIN, SCHERM_MAX), vak.size.x)
		maat = FotoScherm.maat_bij(floorf(breed))
		maat.y = minf(maat.y, floorf(vak.size.y))
	var midden := Vector2(vak.get_center().x,
		(vak.end.y - maat.y * 0.5) if boven else (vak.position.y + maat.y * 0.5))
	if vast:
		var was: Vector2 = _vast["midden"]
		if vak.grow(0.5).encloses(Rect2(was - maat * 0.5, maat)):
			midden = was
	elif vraag:
		_vast = {"kader": kader, "maat": maat, "boven": boven, "midden": midden}
	return {"rect": vak, "boven": boven, "maat": maat, "midden": midden}

## The world point (in this room, at some height) that `World.mik_punt` puts
## on the screen point `doel` — the projection is affine, so three probes give
## it exactly.
func _punt_op(doel: Vector2) -> Dictionary:
	var z := 40.0
	var o: Vector2 = World.mik_punt(0.0, z, 0.0)
	var ax: Vector2 = World.mik_punt(1.0, z, 0.0) - o
	var ay: Vector2 = World.mik_punt(0.0, z, 1.0) - o
	if absf(ax.x) < 0.0001 or absf(ay.y) < 0.0001:
		return {}
	var x := (doel.x - o.x) / ax.x
	var y := (doel.y - o.y - x * ax.y) / ay.y
	return {"x": x, "z": z, "y": y, "kamer": KAMER}

## Where the screen may stand at all: the frame over the maths bar.
func _scherm_vrij() -> Rect2:
	var kader := World.kader_rect().size
	var boven := float(Hits.RAND)
	var onder := kader.y - float(Hits.RAND)
	if Ui.balk_aan():
		onder = kader.y - Ui.balk_kost() - float(Hits.GAT)
	return Rect2(Vector2(float(Hits.RAND), boven),
		Vector2(maxf(0.0, kader.x - 2.0 * float(Hits.RAND)), maxf(0.0, onder - boven)))

## The band the screen goes in: the larger of the free space above the animals
## at the booth and the free space below them — or the side `kant` (true:
## above) when that is fixed (`_vast`).  On a tablet that is above them (over
## the back wall); on a phone held upright, where the room is a strip across
## the middle, below them.  `{rect, boven}`.
func _scherm_band(kant: Variant = null) -> Dictionary:
	var vrij := _scherm_vrij()
	var groep := _groep_rect()
	if groep.size.x <= 0.0:
		return {"rect": vrij, "boven": true}
	var gat := float(Hits.GAT)
	var boven := Rect2(vrij.position,
		Vector2(vrij.size.x, maxf(0.0, groep.position.y - gat - vrij.position.y)))
	var onder_y := groep.end.y + gat
	var onder := Rect2(Vector2(vrij.position.x, onder_y),
		Vector2(vrij.size.x, maxf(0.0, vrij.end.y - onder_y)))
	var kies_boven: bool = bool(kant) if kant != null else onder.size.y <= boven.size.y
	return {"rect": boven if kies_boven else onder, "boven": kies_boven}

## Where the animals at the booth are on the screen: all four places, whoever
## is chosen yet, so the screen does not move while the photo fills up.  An
## animal is about 28 voxels long, 16 deep and 26 high.
func _groep_rect() -> Rect2:
	var r := Rect2()
	var eerste := true
	for p in PLEKKEN:
		for hoek in [Vector3(-14, 0, -8), Vector3(14, 0, -8), Vector3(-14, 0, 8),
				Vector3(14, 0, 8), Vector3(-14, 26, 0), Vector3(14, 26, 0)]:
			var q: Vector2 = World.mik_punt(p.x + hoek.x, p.y + hoek.z, hoek.y)
			if eerste:
				r = Rect2(q, Vector2.ZERO)
				eerste = false
			else:
				r = r.expand(q)
	return r

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

## The `[probe] foto …` line `_meld` prints (and the tests read): the turn, who
## sits inside the booth (`binnen`), the digit of the countdown on the screen
## (`tel`, 0 = none) and whether the photo is taken (`foto`).
func probe_regel() -> String:
	var sch := _scherm()
	return "[probe] foto stap=%s band=%d prijs=%d dieren=%s goed=%d weg=%d missers=%d ster=%d binnen=%s tel=%d foto=%d" % [
		_stap(), int(S.get("band", 0)), _prijs(), ",".join(PackedStringArray(_dieren())), _goed(),
		int(S.get("weg", 0)), int(S.get("missers", 0)), int(S.get("ster", 0)),
		",".join(PackedStringArray(_binnen)), sch.tel_getal if sch != null else 0,
		1 if sch != null and sch.foto else 0]

## Machine-readable lines for `tools/kiek.js` / `speel.js`, web export only.
func _meld() -> void:
	if not OS.has_feature("web"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not actief or S.is_empty() or O.is_empty():
		return
	print(probe_regel())
	for id in Hits.debug().keys():
		if not str(id).begins_with("ft_"):
			continue
		var spot := Hits.spot(id)
		if spot == null or not is_instance_valid(spot.knoop) or not spot.knoop.visible:
			continue
		print("[probe] ", id, "=", (spot.knoop as Control).get_global_rect())
		var rij := (spot.knoop as Control).get_node_or_null("Rij")
		if rij != null:
			var namen: Array[String] = []
			for k in rij.get_children():
				namen.append(str(k.name).trim_prefix("K"))
			print("[probe] foto keuzes=", ",".join(namen))
