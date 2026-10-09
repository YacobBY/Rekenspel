extends MiniGame
## Koekjes bakken 🍪 — de bakkerij (2026-10-07, owner: "Verzin nog vier kamers
## met activiteiten").  Design and state of the build:
## .fanout/scratch/uitbreiding/U1-bakkerij.md.
##
## The bakery holds a stone oven against the back wall and a big baker's table
## in the middle of the floor.  Both are this game's own things: resting props
## while nobody plays (`definitie().rust`, the entry "🍪 Bakken" hangs on the
## oven), the game's own decor during a turn.  One turn:
##   1. The baker of the turn (a guest with a bed, or the animal the child
##      picked on the game bar) walks to the left side of the table.  On the
##      table lies the sum itself (`KoekjesBeurt.bank`): a tray with N rows of
##      k balls of dough (one row per guest), a bowl with N eggs and r more
##      beside it, two bowls for a double recipe, or T baked cookies in rows of
##      ten to share.
##   2. When he is there: one card — one sentence, the sum, four numbers.
##   3. Wrong: the strip answers it centrally (`Ui.misser`: the baker sulks,
##      `🔄 Nog een keer`, the strip locks for a moment) and the SAME question
##      stays — no help after a miss (owner, 2026-09-24).
##   4. Right: a tick, `ja`, the adaptive signal, one star.  Then the answer
##      appears in the world: the tray goes into the glowing oven and comes back
##      with golden cookies (`deur`, `ding`, `hoera`, the baker nibbles one),
##      the eggs go into the bowl, the bowls become batter, or the cookies lie
##      in N rows of k with the rest on a plate on the oven ("voor de kok").
##      The card shows the answer; a moment later the game closes itself.
##
## The turn lives in `ctx.data()["stand"]`; a reload resumes the same question
## with the same four numbers (the strip's seed is the card and the day).

const KAMER := "bakkerij"
const Beurt := preload("res://games/koekjes/beurt.gd")

## The oven against the back wall (the mouth faces into the room) and the
## baker's table on the floor; their floor is kept free in the room data
## (`mijd` in rooms.gd).  The entry is anchored to the counter, the nearest
## FIXED piece, and slid onto the oven; while the resting oven stands it hangs
## ON it.
const ANKER := "aanrecht"
const ANKER_X := 56
const ANKER_Z := 6
const OVEN_X := 30
const OVEN_Z := 10
const BANK_X := 56
const BANK_Z := 50
## The baker stands at the left side of the table: in sight, never in front of
## the tray (he is drawn behind the table), and the walk from the kitchen door
## to here passes no table.
const GAST_X := 18.0
const GAST_Z := 50.0

const OVEN_ID := "kk_oven"
const BANK_ID := "kk_bank"
const RUST_OVEN := "rust_kk_oven"
const RUST_BANK := "rust_kk_bank"
const KAART_ID := "kk_kaart"
const STROOK_ID := "kk_kaart_keuzes"
const BORD_ID := "kk_bord"
const LEKKER_ID := "kk_lekker"
const LEEG_ID := "kk_leeg"
const MODEL_OVEN := "koekjes_oven"
const MODEL_BANK := "koekjes_bank"
## The resting table: an empty tray, the rolling pin and a little flour.
const RUST_TAFEL := {"rijen": 2, "kolommen": 4, "aantal": 0, "rol": true}

const KAART_HOOG := 16.0     ## the card's aim over the table (when it floats)
const LEKKER_HOOG := 46.0
const BORD_HOOG := 12.0      ## the big board comes forward from the table top
const CEL_MIN := 16.0        ## a cookie on the big board is at least this wide ...
const CEL_MAX := 46.0        ## ... and at most this wide

const IN_S := 0.5            ## a right answer, then the tray goes into the oven
const BAK_S := 1.6           ## ... and bakes this long
const EI_S := 0.25           ## an egg rolls into the bowl every EI_S
const AF_S := 3.6            ## the end card is readable this long before it closes
const LEEG_S := 1.8
const BLIJF_S := 1.5         ## how often the baker is kept at his place

## The turn.  Lives in `ctx.data()["stand"]`; every number is read back through
## `int()`, because JSON hands them back as floats.
var S: Dictionary = {}
## The question of today — purely a function of N, band and day
## (`KoekjesBeurt.maak`), so it is recomputed at every start and never saved.
var B: Dictionary = {}
var _kaart = null            ## Ui.Kaart
var _kaart_stap := ""        ## the step the card on screen was built for
var _t0 := 0
## While the eggs roll into the bowl one by one: what the table shows between
## two eggs (`{}` = what the step says).
var _tussen: Dictionary = {}

# ------------------------------------------------------------- aanmelding

func definitie() -> Dictionary:
	# None of these may touch `self`: the registry reads `definitie()` from a
	# throwaway instance and frees it again (architecture.md §6.1).
	# The entry and the task card only come with a baker: a guest with a bed
	# (world.md §5.1 `kan`) — the oven and the table stand there anyway.
	var kan := func(s: Dictionary) -> bool:
		for g in s.get("gasten", []):
			if not str(g.get("bed", "")).is_empty():
				return true
		return false
	return {
		"naam": "Koekjes bakken",
		"kamer": KAMER,
		"stub": false,
		"hotspot": {"obj": ANKER, "dx": OVEN_X - ANKER_X, "dz": OVEN_Z - ANKER_Z,
			"icoon": Beurt.ICOON, "label": Beurt.KNOP,
			"hoog": ArtDecorBakkerij.OVEN_TOP + 2, "rust": RUST_OVEN},
		"modellen": {MODEL_OVEN: Callable(ArtDecorBakkerij, "bakoven"),
			MODEL_BANK: Callable(ArtDecorBakkerij, "werkbank")},
		# the oven and the table always stand in the bakery when nobody plays,
		# also before the first guest: a bakery without an oven is no bakery
		"rust": [
			{"id": RUST_OVEN, "model": MODEL_OVEN, "x": float(OVEN_X), "z": float(OVEN_Z),
				"params": {}},
			{"id": RUST_BANK, "model": MODEL_BANK, "x": float(BANK_X), "z": float(BANK_Z),
				"params": RUST_TAFEL}],
		"unlock": func(_n: int, _band: int) -> bool: return true,
		"kan": kan,
		"taak": {"id": "koekjes", "icoon": Beurt.ICOON, "tekst": Beurt.TAAK,
			"kamer": KAMER, "prio": 5},
	}

# ------------------------------------------------------------ start / stop

func start(_c: SpelCtx) -> void:
	for naam in [MODEL_OVEN, MODEL_BANK]:
		if not Art.heeft_model(naam):
			Art.registreer_model(naam, Callable(ArtDecorBakkerij,
				"bakoven" if naam == MODEL_OVEN else "werkbank"))
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
	# The animal the child picked on the game bar bakes, if he may (world.md
	# §5.8); a turn of another animal is simply not finished.
	var wil := ctx.voorkeur(spelers())
	# Resume only when the saved turn is still THIS question: the same day,
	# hotel and band, not answered yet — and the turn of the picked animal.
	var hervat := not (S.is_empty() or g.is_empty() or int(S["dag"]) != dag
			or int(S["N"]) != n or int(S["band"]) != band or _stap() != "som")
	var weg := ""
	# An open question that had a miss comes back UNCHANGED after any exit —
	# another day, another hotel size or band, the game bar's animal switch
	# (wave 2, R2): the sum is seeded on the turn's own day, N and band, so it
	# is rebuilt from the save, never from today.  The picked animal may take
	# over the tray; the question stays.
	var open := open_vraag(S)
	if open:
		hervat = true
		if not wil.is_empty() and wil != _gast_id():
			weg = _gast_id()
			S["gast"] = wil
		elif g.is_empty():
			S["gast"] = str((kies[(dag + n) % kies.size()] as Dictionary).get("id", ""))
	elif hervat and not wil.is_empty() and wil != _gast_id():
		weg = _gast_id()
		hervat = false
	if not hervat:
		g = kies[(dag + n) % kies.size()] if wil.is_empty() else ctx.state.gast_van(wil)
		S = _nieuwe_stand(g, n, band, dag)
	d["stand"] = S
	ctx.speelt(_gast_id())
	B = Beurt.maak(int(S["N"]), int(S["band"]), int(S["dag"]))
	_t0 = Time.get_ticks_msec()
	_kaart = null
	_kaart_stap = ""
	_tussen = {}
	# the oven and the table first: the card hangs on the table, so it must
	# stand before the card asks — and the card waits for the baker (`_begin`)
	_zet_spullen()
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
	B = {}
	_kaart = null
	_kaart_stap = ""
	_tussen = {}

## Who bakes: everyone with a bed, in check-in order.  Nobody yet: the game
## says so and closes.
func _kandidaten() -> Array:
	var uit: Array = []
	for g in ctx.state.s["gasten"]:
		if not str(g.get("bed", "")).is_empty():
			uit.append(g)
	return uit

## Who may bake when the child chooses the animal himself (the game bar,
## world.md §5.8): everyone with a bed, in check-in order.
func spelers() -> Array:
	var uit: Array = []
	for g in _kandidaten():
		uit.append(str(g.get("id", "")))
	return uit

func _meld_leeg() -> void:
	ctx.ui.wolk({"id": LEEG_ID, "kamer": KAMER, "op": "aan",
		"x": float(OVEN_X), "z": float(OVEN_Z), "hoog": 30.0,
		"icoon": "🛏", "tekst": Beurt.T_LEEG, "prio": 12})
	if not await na(LEEG_S):
		return
	ctx.ui.wolk_weg(LEEG_ID)
	ctx.sluit()

func _nieuwe_stand(g: Dictionary, n: int, band: int, dag: int) -> Dictionary:
	return {"gast": str(g.get("id", "")), "dag": dag, "N": n, "band": band,
		"stap": "som", "pog": 0, "missers": 0, "ster": 0}

## A turn that came through the save is JSON: every number a float.
static func _normaliseer(st: Dictionary) -> Dictionary:
	for k in ["dag", "N", "band", "pog", "missers", "ster"]:
		st[k] = int(st.get(k, 0))
	st["gast"] = str(st.get("gast", ""))
	var stap := str(st.get("stap", "som"))
	st["stap"] = stap if stap in ["som", "bak", "af"] else "som"
	return st

## A saved turn whose sum is still asked and was already answered wrong at
## least once: it may not be swapped for an easier or a fresh one (R2).
static func open_vraag(st: Dictionary) -> bool:
	return not st.is_empty() and str(st.get("stap", "")) == "som" \
		and int(st.get("missers", 0)) > 0

func _stap() -> String:
	return str(S.get("stap", ""))

func _gast_id() -> String:
	return str(S.get("gast", ""))

func _bewaar() -> void:
	if ctx != null and not S.is_empty():
		ctx.data()["stand"] = S
		State.bewaar()

# ------------------------------------------------------------ de bakker halen

## The baker first, then the sum (owner, 2026-09-23: "Zorg dat de minigame
## pas begint wanneer het dier er is").  The oven and the table stand there at
## once; the card comes the moment the baker stands beside the table — after a
## walk through the kitchen with the hotel's "komt eraan" bubble when he comes
## from his room (`ctx.wacht_op`).
func _begin() -> void:
	if not await ctx.wacht_op(_gast_id(), Vector2(GAST_X, GAST_Z)):
		if actief:
			ctx.sluit.call_deferred()      # the baker is gone
		return
	if not actief or S.is_empty() or B.is_empty():
		return
	_kaart_neer()
	_teken()
	_houd_bij_de_tafel()

## The baker stays beside the table for the whole turn: a waiting guest starts
## to wander after sixteen seconds (world.md §2.6) and would stroll over the
## table, and the big board would follow him across the frame.  Every BLIJF_S
## he is looked at (the way `games/foto` keeps its animals at the booth): a
## walk that does not end at his place is turned back to it, a guest standing
## anywhere else is sent back, and a guest who waits at his place is told to
## wait again before his sixteen seconds are up.  A sulk after a miss, a happy
## hop at the end and a nibble are left alone.
func _houd_bij_de_tafel() -> void:
	var tel := 0
	while actief and not S.is_empty():
		if not await na(BLIJF_S):
			return
		if S.is_empty():
			return
		tel += 1
		var d = World.dier(_gast_id())
		if d == null or d.kamer != KAMER or not (d.route as Array).is_empty():
			continue
		if d.staat in ["sip", "blij", "eet", "slaap", "pose"]:
			continue
		var plek := Vector2(GAST_X, GAST_Z)
		var doel := plek
		if not (d.punten as Array).is_empty():
			doel = d.punten[(d.punten as Array).size() - 1]
		var thuis: bool = absf(d.x - plek.x) + absf(d.z - plek.y) <= 2.0
		if doel.distance_to(plek) > 2.0 or (not thuis and d.staat != "loop") \
				or (thuis and d.staat == "wacht" and tel % 8 == 0):
			ctx.wereld.ga(_gast_id(), plek.x, plek.y, "wacht")

# ------------------------------------------------------------------ de kaart

## The card for the step the turn is in.  Built once per step: a miss changes
## nothing on it, so the strip keeps its pause and its four numbers — rebuilding
## it would hand the child a fresh, unlocked strip.
func _kaart_neer() -> void:
	if not actief or S.is_empty() or B.is_empty():
		return
	var stap := "som" if _stap() == "som" else "af"
	if _kaart != null and _kaart_stap == stap:
		return
	if _kaart != null:
		_kaart.weg()
		_kaart = null
	_kaart_stap = stap
	var o := {"id": KAART_ID, "kamer": KAMER, "hoog": KAART_HOOG, "icoon": Beurt.ICOON,
		"dier": _gast_id(), "titel": "de bakkerij"}
	if stap == "som":
		o["regel"] = str(B["regel"])
		o["goed"] = int(B["goed"])
		o["liever"] = B["liever"]
		o["min"] = 1
		# the strip's seed is the turn's own day, not today's (`Ui._getal_keuzes`
		# takes today): an open question keeps its four numbers across a new day
		o["zaad"] = (hash(KAART_ID) % 100003) + int(S["dag"]) * 17
		o["on_ok"] = _antwoord
		if B.has("regel2"):
			o["regel2"] = str(B["regel2"])
	else:
		# the answer, under the sum that was asked
		o["icoon"] = Beurt.ICOON_AF
		o["regel"] = Beurt.af_regel(B)
	_kaart = ctx.ui.somkaart(BANK_ID, str(B["som"]), o)
	if _kaart != null and stap == "af":
		_kaart.klaar()
		_kaart.zet(str(int(B["goed"])))

## One tap on the number strip.  Wrong: the strip has already made the baker
## sulk (`Ui.misser`); this game only counts it and stays quiet — the same
## question with the same four numbers waits, nothing helps.  Right: a tick,
## the star, and the answer appears in the world.
func _antwoord(n, k) -> void:
	if n == null or S.is_empty() or B.is_empty() or _stap() != "som":
		return
	if int(n) != int(B["goed"]):
		S["pog"] = int(S["pog"]) + 1
		S["missers"] = int(S["missers"]) + 1
		ctx.snd.zacht()
		_bewaar()
		_meld()
		return
	if k != null:
		k.zet(str(int(B["goed"])))
		k.klaar()
	ctx.snd.ja()
	ctx.state.tel(int(S["missers"]) == 0, Time.get_ticks_msec() - _t0)
	if int(S["ster"]) == 0:
		S["ster"] = 1
		ctx.taak_klaar("koekjes", {"sterren": 1})
	S["pog"] = 0
	S["stap"] = "bak" if Beurt.bakt(B) else "af"
	_bewaar()
	_meld()
	if Beurt.bakt(B):
		_bak()
	elif str(B["soort"]) == "eieren":
		_eieren_erin()
	else:
		_klaar()

## The tray into the oven, the oven glows, the bell of the oven, and the tray
## is back on the table with golden cookies.
func _bak() -> void:
	if not await na(IN_S):
		return
	if S.is_empty() or _stap() != "bak":
		return
	ctx.snd.deur()
	_teken()
	if not await na(BAK_S):
		return
	if S.is_empty() or _stap() != "bak":
		return
	ctx.snd.ding()
	_klaar()

## The eggs beside the bowl roll in one by one; then the end.
func _eieren_erin() -> void:
	var n := int(B.get("eieren", 0))
	var r := int(B.get("erbij", 0))
	for i in r:
		if not await na(EI_S):
			return
		if S.is_empty():
			return
		ctx.snd.plop(i + 1)
		_tussen = {"kommen": [n + i + 1], "los": r - i - 1}
		_teken()
	if not await na(EI_S):
		return
	if S.is_empty():
		return
	_tussen = {}
	_klaar()

## The answer lies in the world: the end card, the sparkles, the baker is
## delighted and tastes one, and a moment later the game closes itself.
func _klaar() -> void:
	S["stap"] = "af"
	_bewaar()
	_kaart_neer()
	_teken()
	if str(B.get("soort", "")) == "verdeel":
		ctx.snd.tover()
	ctx.snd.hoera()
	for i in 3:
		ctx.wereld.spetter(KAMER, float(BANK_X) - 10.0 + 10.0 * i, float(BANK_Z), 5,
			ArtEffect.KRUIMEL_KL if i != 1 else Color("#FFD23F"), true,
			float(ArtDecorBakkerij.BANK_HOOG + 2))
	var id := _gast_id()
	if World.dier(id) != null:
		ctx.wereld.set_mood(id, "bouncy")
		ctx.snd.knabbel()
		ctx.ui.wolk({"id": LEKKER_ID, "kamer": KAMER, "volg": _volg_dier(id),
			"hoog": LEKKER_HOOG, "icoon": Beurt.ICOON_LEKKER, "tekst": Beurt.T_LEKKER,
			"klas": "goed", "prio": 12})
	if not await na(AF_S):
		return
	if S.is_empty() or _stap() != "af":
		return
	ctx.sluit()

# ------------------------------------------------------------------ tekenen

## The oven and the table as they stand in this step, each ONE piece of loose
## decor.  Re-issuing the same id replaces the piece.
func _zet_spullen() -> void:
	var stap := _stap() if not S.is_empty() else "som"
	ctx.wereld.decor(KAMER, {"id": OVEN_ID, "model": MODEL_OVEN,
		"x": float(OVEN_X), "z": float(OVEN_Z), "params": Beurt.oven(B, stap)})
	ctx.wereld.decor(KAMER, {"id": BANK_ID, "model": MODEL_BANK,
		"x": float(BANK_X), "z": float(BANK_Z),
		"params": _tussen if not _tussen.is_empty() else Beurt.bank(B, stap)})

## Everything on the table, in the oven and on the big board, but never the
## card.
func _teken() -> void:
	if not actief or ctx == null or S.is_empty() or B.is_empty():
		return
	_zet_spullen()
	_groot_bord()
	ctx.wereld.vuil()
	_meld()

## What the big board shows now: the table of this step (`KoekjesBeurt.bord`),
## or the table between two eggs.
func bord_params() -> Dictionary:
	if not _tussen.is_empty():
		return _tussen.duplicate(true)
	return Beurt.bord(B, _stap())

## The table large and straight on (`KoekjesBord`), from the moment the card
## asks until the game closes: the table in the middle of the bakery is a
## small thing once the maths bar is docked, and a cookie on it a speck.  It
## hangs in the FIXED layer, so a name plate steps aside for it and it never
## jumps; it stands beside the baker, never over him — a miss is only his
## disappointed face, so it must be seen.
func _groot_bord() -> void:
	var p := bord_params()
	var s := Hits.spot(BORD_ID)
	if s != null and is_instance_valid(s.knoop) and s.knoop is KoekjesBord:
		(s.knoop as KoekjesBord).zet(p)
		return
	var bord := KoekjesBord.new()
	bord.meet = _bord_maat
	bord.zet(p)
	ctx.hotspots.maak({"id": BORD_ID, "kind": "eigen", "knoop": bord, "kamer": KAMER,
		"x": float(BANK_X), "z": float(BANK_Z), "y": BORD_HOOG, "op": "midden",
		"geen_vlak": true, "vast": true, "prio": 20, "volg": _volg_bord()})

## Every placement: the board stands as near to the table as it can, in the
## largest free part of the frame beside the baker.  `Hits` clamps it into the
## frame after that.
func _volg_bord() -> Callable:
	return func() -> Dictionary:
		var vak := _bord_regio()
		var maat := _bord_maat()
		if vak.size.x <= 0.0 or maat.x <= 0.0:
			return {}
		var tafel: Vector2 = World.mik_punt(float(BANK_X), float(BANK_Z),
			float(ArtDecorBakkerij.BANK_HOOG))
		var x := clampf(tafel.x, vak.position.x + maat.x * 0.5,
			maxf(vak.position.x + maat.x * 0.5, vak.end.x - maat.x * 0.5))
		var y := clampf(tafel.y, vak.position.y + maat.y * 0.5,
			maxf(vak.position.y + maat.y * 0.5, vak.end.y - maat.y * 0.5))
		return _punt_op(Vector2(x, y))

## The world point (in this room, at some height) that `World.mik_punt` puts
## on the screen point `doel` — the projection is affine, so three probes give
## it exactly (as `games/foto` places its screen).
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

## Where the board may stand at all: the frame over the maths bar, or —
## without a bar — over the floating card and its strip.
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

## The part of the free frame the board goes in: right of the baker, left of
## him, over him or under him — whichever gives the largest cookies.
func _bord_regio() -> Rect2:
	var vrij := _bord_vrij()
	var dier := World.vlak_van_dier(_gast_id())
	if dier.size.x <= 0.0 or not vrij.intersects(dier):
		return vrij
	# his name plate stands over his head: keep that free as well
	dier = dier.grow_individual(0.0, 28.0, 0.0, 0.0)
	var gat := float(Hits.GAT)
	var kandidaten: Array[Rect2] = [
		Rect2(Vector2(dier.end.x + gat, vrij.position.y),
			Vector2(vrij.end.x - dier.end.x - gat, vrij.size.y)),
		Rect2(vrij.position, Vector2(dier.position.x - gat - vrij.position.x, vrij.size.y)),
		Rect2(vrij.position, Vector2(vrij.size.x, dier.position.y - gat - vrij.position.y)),
		Rect2(Vector2(vrij.position.x, dier.end.y + gat),
			Vector2(vrij.size.x, vrij.end.y - dier.end.y - gat)),
	]
	var c := KoekjesBord.cellen(bord_params())
	var beste := Rect2()
	var beste_cel := -1.0
	for r in kandidaten:
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		var cel := minf(r.size.x / c.x, r.size.y / c.y)
		if cel > beste_cel + 0.5:
			beste = r
			beste_cel = cel
	return beste if beste_cel > 0.0 else vrij

## As large as its part of the frame allows, between CEL_MIN and CEL_MAX a
## cookie.
func _bord_maat() -> Vector2:
	var p := bord_params()
	var c := KoekjesBord.cellen(p)
	var vak := _bord_regio()
	var cel := minf(vak.size.x * 0.96 / c.x, vak.size.y * 0.96 / c.y)
	cel = clampf(cel, CEL_MIN, CEL_MAX)
	return KoekjesBord.maat_bij(floorf(cel), p)

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
	print("[probe] koekjes stap=", _stap(), " soort=", str(B["soort"]), " band=", int(S["band"]),
		" N=", int(S["N"]), " som=", str(B["som"]).replace(" ", ""), " goed=", int(B["goed"]),
		" missers=", int(S["missers"]), " ster=", int(S["ster"]), " gast=", _gast_id())
	var st := Hits.spot(STROOK_ID)
	if st == null or not is_instance_valid(st.knoop) or not st.knoop.visible:
		return
	var rij := (st.knoop as Control).get_node_or_null("Rij")
	if rij != null:
		var namen: Array[String] = []
		for k in rij.get_children():
			namen.append(str(k.name).trim_prefix("Kn"))
		print("[probe] koekjes keuzes=", ",".join(namen))
