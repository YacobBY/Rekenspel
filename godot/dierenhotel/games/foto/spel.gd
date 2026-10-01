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
##      the child taps walks to the booth.  The booth's screen comes forward
##      large (`FotoScherm`): a frame per animal, and under every frame the
##      price per animal — the same for everyone, as in a real booth.
##   2. When they all stand at the booth: "💶 Hoeveel geld gooi je erin?" with
##      the sum under it (groep 3 `€2 + €2 + €2 =`, from groep 4 `3 × €2 =`) and
##      four amounts on the strip (`beurt.gd`).
##   3. Right: the coins drop in, the flash, the screen becomes the photo — the
##      animals side by side and happy — and one star.
##
## A WRONG AMOUNT SENDS THEM OUT, as in every shop of the street (owner,
## 2026-09-24, `WinkelSpel`): the card goes at once, the animals sulk ("😞 Dat
## klopt niet"), walk slowly away with their heads down, and the game closes by
## itself.  A tap on the booth brings the same animals back and the SAME
## question — the turn is in the save.  No help, no hint, nothing taken away.

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
const KLIK_S := 0.7       ## the coins drop in, then the flash
const AF_S := 5.0         ## the photo is to be looked at this long before it closes
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
	State.bewaar()
	_begin()

func stop() -> void:
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
## card is there at once.  The sum waits until every animal on the photo stands
## at the booth (owner, 2026-09-23: "Zorg dat de minigame pas begint wanneer
## het dier er is").
func _begin() -> void:
	_scherm_neer()
	for i in _dieren().size():
		_stuur(i)
	if _stap() == "som":
		_naar_de_som()
		return
	_kaart_neer()
	_teken()

## Animal `i` of the photo walks to its place at the booth.  Nobody waits for
## this walk; `_naar_de_som` does.
func _stuur(i: int) -> void:
	var id := str(_dieren()[i])
	if World.dier(id) == null:
		return
	ctx.wacht_op(id, PLEKKEN[i])

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

## The money question, as soon as everybody stands at the booth.  Until then
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
	var dieren := _dieren().duplicate()
	for i in dieren.size():
		if not await ctx.wacht_op(str(dieren[i]), PLEKKEN[i]):
			if actief:
				ctx.sluit.call_deferred()      # an animal is gone
			return
		if not actief or S.is_empty() or _stap() != "som":
			return
	if not await na(SOM_S * 0.5):
		return
	if S.is_empty() or _stap() != "som" or int(S.get("weg", 0)) == 1:
		return
	_kaart_neer()
	_teken()
	_houd_bij_het_hokje()

## The animals stay at the booth for the whole turn (a waiting guest starts to
## wander after a while, world.md §2.6) — unless they were sent out.
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
			if d.staat in ["sip", "blij", "eet", "slaap", "pose"]:
				continue
			var plek: Vector2 = PLEKKEN[i]
			var doel := plek
			if not (d.punten as Array).is_empty():
				doel = d.punten[(d.punten as Array).size() - 1]
			var thuis: bool = absf(d.x - plek.x) + absf(d.z - plek.y) <= 2.0
			if doel.distance_to(plek) > 2.0 or (not thuis and d.staat != "loop") \
					or (thuis and d.staat == "wacht" and tel % 8 == 0):
				ctx.wereld.ga(id, plek.x, plek.y, "wacht")

func antwoord(n: int) -> void:
	_antwoord(n, _kaart)

## One tap on an amount.  Wrong: out of the booth (see the header).  Right: the
## coins drop in, a moment later the flash, and the photo.
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

## Paid: the flash, the photo, the star.  Then the game closes by itself.
func _klaar() -> void:
	ctx.state.tel(int(S["missers"]) == 0, Time.get_ticks_msec() - _t0)
	if int(S["ster"]) == 0:
		S["ster"] = 1
		ctx.taak_klaar("foto", {"sterren": 1})
	_bewaar()
	if not await na(KLIK_S):
		return
	if S.is_empty() or _stap() != "af":
		return
	ctx.snd.tik()
	_scherm_neer()
	var s := Hits.spot(SCHERM_ID)
	if s != null and is_instance_valid(s.knoop) and s.knoop is FotoScherm:
		(s.knoop as FotoScherm).klik()
	ctx.wereld.spetter(KAMER, HOKJE_X - 3.0, HOKJE_Z + 8.0, 10, Color("#FFF6D6"), true, 20.0)
	ctx.snd.hoera()
	_kaart_neer()
	for id in _dieren():
		if World.dier(str(id)) != null:
			ctx.wereld.set_mood(str(id), "bouncy")
	_teken()
	if not await na(AF_S):
		return
	if S.is_empty() or _stap() != "af":
		return
	ctx.sluit()

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
		var dieren := _dieren()
		if not dieren.is_empty() and World.dier(str(dieren[0])) != null:
			ctx.ui.wolk({"id": BLIJ_ID, "kamer": KAMER, "volg": _volg_dier(str(dieren[0])),
				"hoog": 46.0, "icoon": "😍", "tekst": Beurt.T_BLIJ, "klas": "goed", "prio": 12})
	ctx.wereld.vuil()
	_meld()

## What the screen shows now.
func scherm_params() -> Dictionary:
	var dieren: Array = []
	for id in _dieren():
		var g: Dictionary = ctx.state.gast_van(str(id))
		dieren.append({"kind": str(g.get("kind", "hond")),
			"acc": World.accessoires(str(id)) if World.dier(str(id)) != null else g.get("accessoires", [])})
	return {"dieren": dieren, "prijs": _prijs(), "foto": _stap() == "af"}

## The booth's screen large and straight on (`FotoScherm`), from the first card
## until the game closes, in the free space above the animals at the booth or
## below them — never over them: a wrong amount is only their sad faces.
func _scherm_neer() -> void:
	var p := scherm_params()
	var s := Hits.spot(SCHERM_ID)
	if s != null and is_instance_valid(s.knoop) and s.knoop is FotoScherm:
		(s.knoop as FotoScherm).zet(p)
		return
	var scherm := FotoScherm.new()
	scherm.meet = _scherm_maat
	scherm.zet(p)
	ctx.hotspots.maak({"id": SCHERM_ID, "kind": "eigen", "knoop": scherm, "kamer": KAMER,
		"x": HOKJE_X, "z": HOKJE_Z, "y": 40.0, "op": "midden",
		"geen_vlak": true, "vast": true, "prio": 20, "volg": _volg_scherm()})

## Every placement: the screen stands in the middle of its band, close to the
## animals — just over their heads, or just under their feet.  `Hits` clamps
## it into the frame after that.
func _volg_scherm() -> Callable:
	return func() -> Dictionary:
		var band := _scherm_band()
		var vak: Rect2 = band["rect"]
		var maat := _scherm_maat()
		if vak.size.x <= 0.0 or maat.y <= 0.0:
			return {}
		var y: float = (vak.end.y - maat.y * 0.5) if bool(band["boven"]) \
			else (vak.position.y + maat.y * 0.5)
		return _punt_op(Vector2(vak.get_center().x, y))

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
## at the booth and the free space below them.  On a tablet that is above them
## (over the back wall); on a phone held upright, where the room is a strip
## across the middle, below them.  `{rect, boven}`.
func _scherm_band() -> Dictionary:
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
	if onder.size.y > boven.size.y:
		return {"rect": onder, "boven": false}
	return {"rect": boven, "boven": true}

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

## As large as its band allows, at most as wide as the frame.
func _scherm_maat() -> Vector2:
	var vak: Rect2 = _scherm_band()["rect"]
	var n := maxi(2, _dieren().size())
	var een := FotoScherm.maat_bij(100.0, n)
	var breed := minf(vak.size.x * 0.92, vak.size.y * 0.96 * 100.0 / een.y)
	breed = clampf(breed, SCHERM_MIN, SCHERM_MAX)
	return FotoScherm.maat_bij(floorf(breed), n)

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

## Machine-readable lines for `tools/kiek.js` / `speel.js`, web export only.
func _meld() -> void:
	if not OS.has_feature("web"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not actief or S.is_empty() or O.is_empty():
		return
	print("[probe] foto stap=", _stap(), " band=", int(S["band"]), " prijs=", _prijs(),
		" dieren=", ",".join(PackedStringArray(_dieren())), " goed=", _goed(),
		" weg=", int(S.get("weg", 0)), " missers=", int(S["missers"]), " ster=", int(S["ster"]))
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
