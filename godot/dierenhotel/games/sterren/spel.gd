extends MiniGame
## sterren — "Sterren tellen" ⭐, the game of the dakterras (U3, 2026-10-07;
## owner: "Verzin nog vier kamers met activiteiten").
##
## On the roof of the tower, at night, a telescope stands on the deck.  A turn:
## the animal of the turn climbs the stairs and stands beside it; the telescope
## shows its patch of sky LARGE (`SterrenKijker`): stars in PATTERNS — a dice
## face, a ten-frame with its empty boxes, rows of five or ten, blocks of ten
## and a hundred — so the child sees the structure instead of counting one by
## one.  The card asks one question (`beurt.gd`), the strip holds four numbers.
##   * groep 3: how many (subitizing to 10), two constellations together (to
##     20), how many more to make ten;
##   * groep 4: rows of 2, 5 or 10 (the tables), doubles;
##   * groep 5: tens and ones, hundreds and tens, r rows of s.
## Right: the stars in the telescope light up, sparkles rise over the deck,
## every animal on the roof looks up, one star for taking part, and a moment
## later the game closes.  Wrong: the animal is disappointed and the SAME
## question stays (`Ui.misser`, done by the card) — no help (HOTEL.md §9).
##
## The save holds only the SEED of the turn (`stand`: band, N, nr, zaad, …):
## the patterns are rebuilt with `Beurt.maak`, so a reload shows the same sky
## and asks the same question, and no Vector2i has to survive JSON.  The
## telescope stands on the deck while the game does not run (`rust`), and its
## entry button hangs on it.

const KAMER := "dakterras"
const Beurt := preload("res://games/sterren/beurt.gd")

const MODEL := "sterren_telescoop"
const RUST_TELESCOOP := "rust_st_telescoop"
const TELESCOOP_ID := "st_telescoop"
const KAART_ID := "st_som"
const STROOK_ID := "st_som_keuzes"
const KIJKER_ID := "st_kijker"
const LEEG_ID := "st_leeg"
const TAAK := "sterren"

## The telescope in the front-right corner of the deck (zone `sterren`), its
## tube pointing up and to the left; the animal of the turn stands beside its
## eyepiece, in front of it, so the telescope never hides him.
const TELESCOOP_X := 94.0
const TELESCOOP_Z := 74.0
const GAST_X := 104.0
const GAST_Z := 90.0
const PLEK_VRIJ := 18.0      ## another animal this close (voxels, |dx| + |dz|) steps aside

const KAART_HOOG := 30.0     ## the card's aim over the telescope (when it floats)
const KIJKER_DEEL := 0.6     ## the view takes at most this share of the free width ...
const KIJKER_HOOG_DEEL := 0.92  ## ... and of the free height
const KIJKER_MIN := 150.0
const KIJKER_MAX := 560.0
const KIJKER_CEL := 54.0     ## a star's cell is never wider than this (frame units)
const AF_S := 2.6            ## the lit stars are to be looked at this long before it closes
const LEEG_S := 1.8
const BLIJF_S := 1.5         ## how often the animal of the turn is kept at his place
const KIJK_TIKKEN := 36      ## the animals look up this long (15 ticks = 1 s)

## The turn.  Lives in `ctx.data()["stand"]`; every number is read back through
## `int()`, because JSON hands them back as floats.
var S: Dictionary = {}
## The turn's sky and question, rebuilt from `S` (`Beurt.maak`), never saved.
var B: Dictionary = {}
var _kaart = null            ## Ui.Kaart
var _t0 := 0

# ------------------------------------------------------------- aanmelding

func definitie() -> Dictionary:
	# None of these may touch `self`: the registry reads `definitie()` from a
	# throwaway instance and frees it again (architecture.md §6.1).
	return {
		"naam": "Sterren tellen",
		"kamer": KAMER,
		"stub": false,
		# the deck has no fixed thing in that corner: the button hangs on the
		# resting telescope itself (`World.mik` finds loose decor by its id)
		"hotspot": {"obj": RUST_TELESCOOP, "icoon": Beurt.ICOON, "label": Beurt.T_KNOP,
			"hoog": 30, "rust": RUST_TELESCOOP},
		"modellen": {MODEL: Callable(ArtDecorDak, "telescoop")},
		"rust": [{"id": RUST_TELESCOOP, "model": MODEL, "x": TELESCOOP_X, "z": TELESCOOP_Z}],
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		"taak": {"id": TAAK, "icoon": Beurt.ICOON, "tekst": Beurt.T_TAAK, "kamer": KAMER,
			"prio": 6},
	}

# ------------------------------------------------------------ start / stop

func start(_c: SpelCtx) -> void:
	if not Art.heeft_model(MODEL):
		Art.registreer_model(MODEL, Callable(ArtDecorDak, "telescoop"))
	# the resting telescope went with the start (`Games.start`): the game's own
	# stands in its place at once, so the card has something to hang on
	_zet_telescoop()
	var kies := _kandidaten()
	if kies.is_empty():
		_meld_leeg()
		return
	var d := ctx.data()
	var n: int = maxi(1, int(ctx.state.n_gasten()))
	var band: int = ctx.state.band()
	var dag := int(ctx.state.s["dag"])
	var oud = d.get("stand", null)
	S = _normaliseer((oud as Dictionary).duplicate(true)) if typeof(oud) == TYPE_DICTIONARY else {}
	var g: Dictionary = {}
	if not S.is_empty():
		g = ctx.state.gast_van(_gast_id())
	# The animal the child picked on the game bar looks through the telescope,
	# if he may (world.md §5.8); a turn of another animal is simply not finished.
	var wil := ctx.voorkeur(spelers())
	# Resume only when the saved turn is still THIS turn — the same day, hotel
	# and band, not finished — and the turn of the picked animal.
	var hervat := not (S.is_empty() or g.is_empty() or int(S["dag"]) != dag
			or int(S["N"]) != n or int(S["band"]) != band or _stap() == "af")
	var weg := ""
	if hervat and not wil.is_empty() and wil != _gast_id():
		weg = _gast_id()
		hervat = false
	if not hervat:
		var nr := int(d.get("beurt_nr", 0))
		g = kies[posmod(dag + n + nr, kies.size())] if wil.is_empty() else ctx.state.gast_van(wil)
		S = _nieuwe_stand(g, n, band, dag, nr)
	d["stand"] = S
	ctx.speelt(_gast_id())
	B = _beurt_uit(S)
	_kaart = null
	_t0 = Time.get_ticks_msec()
	State.bewaar()
	_begin()
	if not weg.is_empty() and weg != _gast_id():
		ctx.laat_gaan(weg)
	_maak_plek()

## Another animal standing at the telescope — the one of the last turn, who
## stayed to look — steps aside to a free place on the deck, so the animal of
## this turn does not end up in the same spot.
func _maak_plek() -> void:
	for d in World.dieren(KAMER):
		var id := str(d.id)
		if id == _gast_id() or World.slaapt(id) or not str(d.reis_doel).is_empty():
			continue
		if absf(d.x - GAST_X) + absf(d.z - GAST_Z) < PLEK_VRIJ \
				or absf(d.x - TELESCOOP_X) + absf(d.z - TELESCOOP_Z) < PLEK_VRIJ:
			World.solo(id)

func stop() -> void:
	if ctx != null:
		if not S.is_empty():
			ctx.data()["stand"] = S
			State.bewaar()
		World.decor_wis_eigenaar(ctx.id)
	S = {}
	B = {}
	_kaart = null

## Who looks through the telescope: everyone with a bed.  Nobody yet: the game
## says so and closes.
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
		"x": TELESCOOP_X, "z": TELESCOOP_Z, "hoog": 30.0,
		"icoon": "🛏", "tekst": Beurt.T_LEEG, "prio": 12})
	if not await na(LEEG_S):
		return
	ctx.ui.wolk_weg(LEEG_ID)
	ctx.sluit()

func _nieuwe_stand(g: Dictionary, n: int, band: int, dag: int, nr: int) -> Dictionary:
	return {"gast": str(g.get("id", "")), "dag": dag, "N": n, "band": band, "nr": nr,
		"zaad": Beurt.ZAAD + dag, "stap": "som", "missers": 0, "ster": 0}

## A turn that came through the save is JSON: every number a float.
static func _normaliseer(st: Dictionary) -> Dictionary:
	for k in ["dag", "N", "band", "nr", "zaad", "missers", "ster"]:
		st[k] = int(st.get(k, 0))
	st["gast"] = str(st.get("gast", ""))
	var stap := str(st.get("stap", "som"))
	st["stap"] = stap if stap in ["som", "af"] else "som"
	return st

## The sky and the question of a turn, from its seed.
static func _beurt_uit(st: Dictionary) -> Dictionary:
	return Beurt.maak(int(st.get("band", 3)), int(st.get("N", 1)), int(st.get("nr", 0)),
		int(st.get("zaad", Beurt.ZAAD)))

func _stap() -> String:
	return str(S.get("stap", ""))

func _gast_id() -> String:
	return str(S.get("gast", ""))

func _bewaar() -> void:
	if ctx != null and not S.is_empty():
		ctx.data()["stand"] = S
		State.bewaar()

# ------------------------------------------------------------ de gast halen

## The animal of the turn first, then the question (owner, 2026-09-23: "Zorg
## dat de minigame pas begint wanneer het dier er is"): he climbs the stairs to
## the roof with the hotel's "komt eraan" bubble (`ctx.wacht_op`) and stands
## beside the telescope; then the telescope shows its sky and the card asks.
func _begin() -> void:
	if not await ctx.wacht_op(_gast_id(), Vector2(GAST_X, GAST_Z)):
		if actief:
			ctx.sluit.call_deferred()      # the guest is gone
		return
	if not actief or S.is_empty() or B.is_empty():
		return
	_t0 = Time.get_ticks_msec()
	_toon()
	_houd_bij_de_telescoop()

## The animal of the turn stays beside the telescope for the whole turn: a
## waiting guest starts to wander after sixteen seconds (world.md §2.6).  Every
## BLIJF_S he is sent back when he is not there and not busy (a sulk after a
## miss, looking up at the end).
func _houd_bij_de_telescoop() -> void:
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

# ------------------------------------------------------------------ de beurt

## The telescope's view and the card.  The card is built once per turn: a miss
## changes nothing on it, so the strip keeps its pause and its four numbers
## (S5) — rebuilding it would hand the child a fresh, unlocked strip.
func _toon() -> void:
	if not actief or S.is_empty() or B.is_empty():
		return
	_kijker_neer()
	if _kaart != null or _stap() != "som":
		return
	var goed := int(B["goed"])
	_kaart = ctx.ui.somkaart(TELESCOOP_ID, "", {
		"id": KAART_ID, "kamer": KAMER, "hoog": KAART_HOOG, "icoon": Beurt.ICOON,
		"regel": str(B["regel"]), "goed": goed, "liever": B["liever"], "min": 1,
		"max": Beurt.cijfers(goed), "dier": _gast_id(), "titel": "de sterren",
		"on_ok": _antwoord,
	})
	_meld()

## One tap on the number strip.  Wrong: the card already made the animal sulk,
## put up `🔄 Nog een keer` and paused the strip (`Ui.misser`); the game counts
## the miss for the adaptive signal and says nothing more — the same question
## stays, nothing in the sky changes.  Right: the tick, the stars light up.
func _antwoord(n, k) -> void:
	if n == null or S.is_empty() or B.is_empty() or _stap() != "som":
		return
	if int(n) != int(B["goed"]):
		S["missers"] = int(S["missers"]) + 1
		ctx.snd.zacht()
		_bewaar()
		_meld()
		return
	if k != null:
		# done (the strip goes, the card turns green), and the counted number
		# stays in the box — `klaar()` alone would leave a bare ✓ there
		k.klaar()
		k.zet(str(int(B["goed"])))
	_klaar()

## Counted right: the adaptive signal (first try = no misses), one star for
## taking part, the stars in the telescope light up, sparkles rise over the
## deck, every animal on the roof looks up — and a moment later it closes.
func _klaar() -> void:
	S["stap"] = "af"
	ctx.state.tel(int(S["missers"]) == 0, Time.get_ticks_msec() - _t0)
	ctx.data()["beurt_nr"] = int(S["nr"]) + 1
	if int(S["ster"]) == 0:
		S["ster"] = 1
		ctx.taak_klaar(TAAK)
	ctx.snd.ja()
	_bewaar()
	var kijker := _kijker()
	if kijker != null:
		kijker.juich()
	# sparkles rise from the open end of the telescope and round the animal
	for plek in [Vector3(TELESCOOP_X - 12.0, TELESCOOP_Z - 3.0, 26.0),
			Vector3(GAST_X - 8.0, GAST_Z - 6.0, 22.0), Vector3(GAST_X + 2.0, GAST_Z - 12.0, 30.0)]:
		var p: Vector3 = plek
		ctx.wereld.spetter(KAMER, p.x, p.y, 8, ArtEffect.STER_KL[0], true, p.z)
	# everyone on the roof looks up — but not who is passing through on his way
	# to another floor: his errand is not broken
	for d in World.dieren(KAMER):
		if d != null and not World.slaapt(str(d.id)) and str(d.reis_doel).is_empty():
			ctx.wereld.pose(str(d.id), "kijk", KIJK_TIKKEN)
	_meld()
	if not await na(AF_S):
		return
	if S.is_empty() or _stap() != "af":
		return
	ctx.sluit()

# ------------------------------------------------------------------ tekenen

## The game's own telescope where the resting one stood (one piece of loose
## decor; the card aims at it).
func _zet_telescoop() -> void:
	ctx.wereld.decor(KAMER, {"id": TELESCOOP_ID, "model": MODEL,
		"x": TELESCOOP_X, "z": TELESCOOP_Z, "params": {}})

## The telescope's view, from the moment the card asks until the game closes.
## It hangs in the FIXED layer, so a name plate steps aside for it.
func _kijker_neer() -> void:
	var s := Hits.spot(KIJKER_ID)
	if s != null and is_instance_valid(s.knoop) and s.knoop is SterrenKijker:
		(s.knoop as SterrenKijker).zet(B["patronen"])
		return
	var kijker := SterrenKijker.new()
	kijker.meet = _kijker_maat
	kijker.zet(B["patronen"])
	ctx.hotspots.maak({"id": KIJKER_ID, "kind": "eigen", "knoop": kijker, "kamer": KAMER,
		"x": TELESCOOP_X, "z": TELESCOOP_Z, "y": 40.0, "op": "midden",
		"geen_vlak": true, "vast": true, "prio": 20, "volg": _volg_kijker()})

func _kijker() -> SterrenKijker:
	var s := Hits.spot(KIJKER_ID)
	if s == null or not is_instance_valid(s.knoop):
		return null
	return s.knoop as SterrenKijker

## Every placement: the view stands where `_kijker_plek()` says.  `Hits`
## clamps it into the frame after that.
func _volg_kijker() -> Callable:
	return func() -> Dictionary:
		if World.px_per_hoogte() <= 0.001:
			return {}
		var mid: Vector2 = _kijker_plek()["mid"]
		return _wereldpunt(mid)

## The world point (z = 0) whose projection is the frame point `p`.
func _wereldpunt(p: Vector2) -> Dictionary:
	var p0: Vector2 = World.mik_punt(0.0, 0.0, 0.0)
	var ex: Vector2 = World.mik_punt(1.0, 0.0, 0.0) - p0
	var ey: Vector2 = World.mik_punt(0.0, 0.0, 1.0) - p0
	if absf(ex.x) < 0.0001 or absf(ey.y) < 0.0001:
		return {}
	var x := (p.x - p0.x) / ex.x
	var y := (p.y - p0.y - x * ex.y) / ey.y
	return {"x": x, "z": 0.0, "y": y, "kamer": KAMER}

## Where the view stands and how large, in frame units: {mid, maat}.  It
## never covers the animal of the turn or the telescope, nor the maths bar (or
## the floating card and its strip).  Two places are weighed — BESIDE them, on
## the left where the telescope points, the whole free height; or ABOVE them,
## the whole free width — and the one with the bigger stars wins: on a tablet
## lying down that is beside, on a phone standing up above.  In both it hugs
## the top-left corner of its place.
func _kijker_plek() -> Dictionary:
	var kader := World.kader_rect().size
	var boven := float(Hits.RAND)
	var onder := kader.y - float(Hits.RAND)
	if Ui.balk_aan():
		onder = kader.y - Ui.balk_kost() - float(Hits.GAT)
	else:
		onder -= _kaart_ruimte()
	var links := float(Hits.RAND)
	var rechts := kader.x - float(Hits.RAND)
	var opzij := rechts        # the right edge of a view beside them
	var erboven := onder       # the bottom edge of a view above them
	for vlak in [World.vlak_van_dier(_gast_id()),
			World.vlak_van(MODEL, TELESCOOP_X, TELESCOOP_Z, 0.0)]:
		var r: Rect2 = vlak
		if r.size.x <= 0.0:
			continue
		opzij = minf(opzij, r.position.x - float(Hits.GAT) * 2.0)
		erboven = minf(erboven, r.position.y - float(Hits.GAT) * 2.0)
	var patronen: Array = B.get("patronen", [])
	var verhouding := SterrenKijker.verhouding(patronen)
	# a few stars stay star-sized: the view hugs them instead of filling the sky
	var cel := SterrenKijker.cellen(patronen)
	var grens := minf(KIJKER_MAX, maxf(cel.x, cel.y * verhouding) * KIJKER_CEL)
	var naast := _kijker_breed(minf(opzij - links, kader.x * KIJKER_DEEL), onder - boven,
		verhouding, grens)
	var erop := _kijker_breed(rechts - links, erboven - boven, verhouding, grens)
	var breed := maxf(naast, erop)
	var maat := Vector2(floorf(breed), floorf(breed / verhouding))
	return {"mid": Vector2(links + maat.x * 0.5, boven + maat.y * 0.5), "maat": maat,
		"waar": "boven" if erop > naast else "naast"}

## The width of a view in a place `w` by `h` for stars of shape `verhouding`.
static func _kijker_breed(w: float, h: float, verhouding: float, grens: float) -> float:
	var breed := minf(minf(w, h * KIJKER_HOOG_DEEL * verhouding), grens)
	return clampf(breed, KIJKER_MIN, KIJKER_MAX)

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

## As large as its place allows, in the shape the stars want.
func _kijker_maat() -> Vector2:
	return _kijker_plek()["maat"]

# ------------------------------------------------------------------ probe

## The turn as the tests and the browser tools read it.
func stand() -> Dictionary:
	return S.duplicate(true)

func beurt() -> Dictionary:
	return B.duplicate(true)

## Machine-readable lines for `tools/kiek.js` / `speel.js`, web export only.
func _meld() -> void:
	if not OS.has_feature("web"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not actief or S.is_empty() or B.is_empty():
		return
	print("[probe] sterren stap=", _stap(), " band=", int(B["band"]), " N=", int(S["N"]),
		" soort=", str(B["soort"]), " goed=", int(B["goed"]),
		" missers=", int(S["missers"]), " ster=", int(S["ster"]))
