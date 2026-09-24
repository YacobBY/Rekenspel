extends MiniGame
## bedden — "Verdeel bedden over de kamers" (games-a.md §3): step 4 of the
## check-in.
##
## The owner, 2026-09-24, in this order: "Waarom zijn er 5 bedden nodig voor 1
## dier?" — "En het moet heten 'verdeel bedden over de kamers' met kamer 1 en
## kamer 2 waar de bedden geplaatst moeten worden op basis van waar het dier gaat
## slapen. Je moet bij bellen van het dier een kamer voor het dier kiezen en
## daarna moet dat spel plaatsvinden op basis van hoeveel dieren je hebt op basis
## van welke kamers ze zitten" — "En wanneer dat bedden spel fout is dan moet het
## dier naar de kamer lopen, teleurgesteld zijn dat er geen bed is, en teruglopen
## naar de balie en dan moet het opnieuw. Het dier moet gevolgd worden met de
## camera nadat het aantal bedden geselecteerd is" — "Nee geef geen hulp na
## fouten. Kinderen moeten zelf leren rekenen."
##
## The turn, for the guest at the desk and the room the check-in chose for him:
##
##  1. At the desk: "In kamer 1 slapen al 2 dieren" / "Boef komt erbij.
##     Hoeveel bedden?", the sum "2 + 1 =" and four numbers.  The numbers are the
##     animals themselves: the ones whose bed is in that room, plus him.
##  2. The number the child taps is how many beds the room holds when he gets
##     there: the sleepers' beds always stay, then the free beds that stand
##     there, then new ones.  A free bed beyond the number is out of sight
##     (`World.verberg_bed`) — it comes back when the camera leaves the room.
##  3. He walks there and the camera walks along (`Hotel.volg`, allowed because
##     the game awaits him: `Games.verwacht`).
##       * Right: he hops into the free bed.  The check-in ends in
##         `Hotel.wijs_bed` (bed, star, board, `vrij`), "💤 <naam> doet een
##         dutje", and the game closes itself.
##       * Too few: "🛏 geen bed", he is sad, walks back to his place at the desk
##         — the camera along — and the SAME question comes again.
##       * Too many: "🛏 te veel bedden", he is sad, the beds made for him go
##         away again, he walks back and the same question comes again.
##     Never a help line, a hint, a helper or a written answer (owner), never a
##     star or a bed taken away.
##  4. Reduced motion: nobody walks.  He is in his bed at once (the camera goes
##     there), or the sad bubble hangs at the desk and the question comes back.
##
## `⬅ Terug` (or any stop) before the beds are right leaves the check-in open:
## `Hotel.checkin_terug()` walks him back to the desk and puts the room question
## up again.  A reload does the same (`Hotel.paint_checkin`).

const SPEL_ID := "bedden"        ## the directory, and so the drawer in `State.s.spel`
const KAMER := "receptie"        ## the question hangs at the desk
const NAAM := "Verdeel bedden over de kamers"
const ICOON := "🛏"

## Child-facing words (HOTEL.md §9: ≤ 8 words and ≤ 40 characters a sentence,
## measured on the longest guest name, "Stampertje").  `%s` is the room as
## `UiTekst.in_kamer` says it, with a capital: "In kamer 1".
const AL_NIEMAND := "%s slaapt nog niemand"      ## "In kamer 1 slaapt nog niemand"   5 / 29
const AL_EEN := "%s slaapt al 1 dier"             ## "In kamer 1 slaapt al 1 dier"     6 / 27
const AL_VEEL := "%s slapen al %d dieren"         ## "In kamer 1 slapen al 2 dieren"   7 / 29
const ERBIJ := "%s komt erbij. Hoeveel bedden?"   ## "Stampertje komt erbij. Hoeveel bedden?" 5 / 38
const KEUZE_TITEL := "hoeveel bedden?"
const GEEN_BED := "geen bed"                      ## 🛏 geen bed
const TE_VEEL := "te veel bedden"                 ## 🛏 te veel bedden
const DUTJE := "%s doet een dutje"                ## "💤 Stampertje doet een dutje"   4 / 25

const TIK := 0.1                 ## how often a walk is looked at
const HERSTUUR := 1.0            ## s standing still off his place: sent there again
const MAX_LOOP := 40.0           ## s: a walk that takes longer than this is helped along
const BALIE_MARGE := 6.0         ## voxels from his place at the desk still count as "there"
const MARGE := 3.0               ## ... and from his place in the room
const SIP_TIJD := 2.4            ## s he stands there sad before he walks back
const TERUG_NA := 1.0            ## s until the beds made for "te veel" go away again
const SIP_RUST := 2.2            ## s the sad bubble hangs at the desk in reduced motion
const NAGENIET := 3.2            ## s asleep in view before the game closes itself
const NAGENIET_RUST := 2.6
const SIP_HOOG := 46.0

var _gast := ""                  ## the guest who checks in
var _kamer := ""                 ## the room the check-in chose for him
var _slapers := 0                ## the animals whose bed is in that room
var _kaart = null                ## Ui.Kaart
var _bezig := false              ## an answer is being played out: the card is gone
var _t0 := 0
var _nep: Array[String] = []     ## the loose-decor beds of a "too many" answer
var _getoond: Array[String] = [] ## the free beds shown for this answer (slot ids)

# ---------------------------------------------------------------- aanmelden

func definitie() -> Dictionary:
	return {
		"naam": NAAM,
		"kamer": KAMER,
		# No entry button and no task card: the game is step 4 of the check-in
		# and begins at the room question at the desk (`Hotel.kies_kamer`).  The
		# hotspot carries only the pictogram of the game bar beside ⬅ Terug;
		# without an `obj` the registry never hangs an entry anywhere.
		"hotspot": {"icoon": ICOON},
		# the very first guest checks in with nobody in the hotel yet
		"unlock": func(_n: int, _band: int) -> bool: return true,
		"kan": Callable(get_script(), "kan_nu"),
		"stub": false,
	}

## `kan` (world.md §5.1): only while a check-in stands at its beds.
static func kan_nu(s: Dictionary) -> bool:
	var v = s.get("checkin", null)
	return v is Dictionary and int((v as Dictionary).get("stap", 0)) >= 4 \
		and not str((v as Dictionary).get("kamer", "")).is_empty()

# ------------------------------------------------------------------- laatje

## The turn in `ctx.data()` (architecture.md §6.2): whose it is, which room,
## how many animals slept there, the misses and the phase.  Timers and walks do
## not survive a reload; the check-in then asks the room again.
func _d() -> Dictionary:
	return ctx.data()

func _missers() -> int:
	return int(_d().get("missers", 0))

# ------------------------------------------------------------ de teksten

## "In kamer 1": the room as the board says it ("in kamer 1", "in de keuken"),
## with a capital, because it opens the sentence.
static func in_de_kamer(kamer_id: String) -> String:
	var r = Rooms.get_kamer(kamer_id)
	var naam: String = str(r.naam) if r != null else kamer_id
	var zin := UiTekst.in_kamer(kamer_id, naam)
	return zin.substr(0, 1).to_upper() + zin.substr(1)

## The first sentence of the card: who sleeps in that room already.
static func regel_slapers(kamer_id: String, slapers: int) -> String:
	var waar := in_de_kamer(kamer_id)
	if slapers <= 0:
		return AL_NIEMAND % waar
	if slapers == 1:
		return AL_EEN % waar
	return AL_VEEL % [waar, slapers]

static func regel_erbij(naam: String) -> String:
	return ERBIJ % naam

# ------------------------------------------------------------------- start

func start(_c: SpelCtx) -> void:
	_t0 = Time.get_ticks_msec()
	_bezig = false
	_nep.clear()
	_getoond.clear()
	var v = State.s["checkin"]
	if v == null or int(v.get("stap", 0)) < 4 or str(v.get("kamer", "")).is_empty() \
			or World.dier(str(v.get("gastId", ""))) == null:
		# nothing to give beds to: no card, no star, and the game steps aside
		print("[probe] spel=start id=bedden leeg=1")
		_sluit_straks.call_deferred()
		return
	_gast = str(v["gastId"])
	_kamer = str(v["kamer"])
	var d := _d()
	if str(d.get("gast", "")) != _gast or str(d.get("kamer", "")) != _kamer:
		d.clear()
		d["gast"] = _gast
		d["kamer"] = _kamer
		d["missers"] = 0
	d["missers"] = int(d.get("missers", 0))
	d["fase"] = "vraag"
	State.bewaar()
	print("[probe] spel=start id=bedden kamer=", _kamer, " gast=", _gast,
		" slapers=", State.slapers_in(_kamer).size())
	_vraag()

func _sluit_straks() -> void:
	if actief:
		ctx.sluit()

# ------------------------------------------------------------------ de vraag

## The question comes when he stands at his place at the desk (world.md §5.8):
## he may still be coming in through the front door, or walking back.
func _vraag() -> void:
	while World.komt_binnen(_gast):
		if not await na(TIK):
			return
	var plek := _balie()
	if not ctx.is_er(_gast, plek, BALIE_MARGE):
		if not await ctx.wacht_op(_gast, plek, {"marge": BALIE_MARGE}):
			if actief:
				ctx.sluit()          # he is gone: the check-in repairs itself
			return
		if not actief:
			return
	_toon_vraag()

func _balie() -> Vector2:
	var p := Hotel.balieplek()
	return Vector2(float(p.get("x", 0.0)), float(p.get("z", 0.0)))

## The card at the desk, where the check-in's own questions hung.  The same
## id and the same answer give the same four numbers in the same order every
## time the question comes back (`Ui._getal_keuzes`, S5).
func _toon_vraag() -> void:
	_bezig = false
	_slapers = State.slapers_in(_kamer).size()
	var d := _d()
	d["slapers"] = _slapers
	d["fase"] = "vraag"
	State.bewaar()
	var g := Hotel.gast_bij_id(_gast)
	var goed := _slapers + 1
	if _kaart != null:
		_kaart.weg()
	_kaart = ctx.ui.somkaart(Hotel.balieplek(), "%d + 1 =" % _slapers, {
		"id": "bd_som", "kamer": KAMER, "hoog": Hotel.balie_hoog(), "icoon": ICOON,
		"volg": Hotel.balie_anker(_gast),
		"regel": regel_slapers(_kamer, _slapers),
		"regel2": regel_erbij(str(g.get("naam", ""))),
		# the slips a child makes: the room without him, or one too many
		"goed": goed, "liever": [_slapers, goed + 1], "min": 0,
		"max_getal": goed + 4, "keuze_titel": KEUZE_TITEL,
		"on_ok": func(n: int, _k) -> void: _op_antwoord(n),
	})
	World.vuil()
	_meld_knoppen()

## Where the buttons really are, one placement pass later (`tools/speel.js`).
func _meld_knoppen() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not actief:
		return
	for id in Hits.lijst():
		if not id.begins_with("bd_"):
			continue
		var s := Hits.spot(id)
		if s != null and is_instance_valid(s.knoop) and s.knoop.visible:
			print("[probe] ", id, "=", s.knoop.get_global_rect())

# ---------------------------------------------------------------- het antwoord

func _op_antwoord(n: int) -> void:
	if not actief or _bezig:
		return
	_bezig = true
	var goed := _slapers + 1
	var d := _d()
	d["keus"] = n
	# the card goes while he shows what the answer means; the same question
	# comes back when he is at the desk again
	if _kaart != null:
		_kaart.weg()
		_kaart = null
	print("[probe] bedden keus=", n, " goed=", goed, " uitkomst=",
		"goed" if n == goed else ("weinig" if n < goed else "veel"))
	if n == goed:
		_goed()
	else:
		d["missers"] = _missers() + 1
		State.bewaar()
		_mis(n)

# ------------------------------------------------------------------- goed

## Exactly the beds he asked for: his free bed, or a new one where the floor
## has room, and the other free beds out of sight.  Then the check-in ends and
## he walks to it — the camera along — and hops in.
func _goed() -> void:
	ctx.state.tel(_missers() == 0, Time.get_ticks_msec() - _t0)
	var slot := ""
	var vrij := State.vrije_bedden(_kamer)
	if not vrij.is_empty():
		slot = str((vrij[0] as Dictionary).get("id", ""))
	else:
		var p := State.bed_plek(_kamer)
		if not p.is_empty():
			var b: Dictionary = ctx.wereld.voeg_bed(_kamer, {"x": p["x"], "z": p["z"]})
			slot = str(b.get("id", ""))
			if not slot.is_empty():
				ctx.snd.plop(1)
	if slot.is_empty():
		# the room filled up after all: the check-in asks for a room again
		ctx.sluit()
		return
	_verberg_behalve(slot)
	_d()["fase"] = "slaap"
	if not Hotel.wijs_bed(_kamer, slot, {"loop": true}):
		ctx.sluit()
		return
	print("[probe] bedden bed=", slot, " kamer=", _kamer)
	Games.verhuis(_kamer)
	if World.rust():
		# no walk: `wijs_bed` put him in his bed at once; the camera goes to him
		Hotel.naar_kamer(_kamer)
		_dutje()
		if not await na(NAGENIET_RUST):
			return
		ctx.sluit()
		return
	_volg_mee()
	var t := 0.0
	while not World.slaapt(_gast):
		if not await na(TIK):
			return
		if World.dier(_gast) == null:
			ctx.sluit()
			return
		t += TIK
		if t >= MAX_LOOP:
			World.slaap(_gast, _kamer, slot)      # stuck somewhere: into bed
			t = 0.0
	Games.verwacht(_gast, Games.beurt(), false)
	_dutje()
	print("[probe] spel=klaar id=bedden gast=", _gast, " sterren=", State.s["sterren"])
	if not await na(NAGENIET):
		return
	ctx.sluit()

## "💤 Boef doet een dutje" over him in his bed (owner 2026-09-24, in place of
## the old good-night bubble).
func _dutje() -> void:
	var naam := str(Hotel.gast_bij_id(_gast).get("naam", ""))
	ctx.ui.wolk({"id": "bd_slaap", "kamer": _kamer, "volg": _volg_gast(54.0),
		"hoog": 54.0, "icoon": "💤", "tekst": DUTJE % naam, "klas": "goed", "prio": 12})

## Every free bed of the room out of sight but `eigen` (a new bed nobody has
## yet stays too: that is his).
func _verberg_behalve(eigen: String) -> void:
	for b in State.vrije_bedden(_kamer):
		var sid := str((b as Dictionary).get("id", ""))
		if sid != eigen:
			World.verberg_bed(_kamer, sid)

# -------------------------------------------------------------------- fout

## The room as the child said it, then his walk there, his disappointment and
## the walk back.  In reduced motion only the disappointment, at the desk.
func _mis(n: int) -> void:
	var te_veel := n > _slapers + 1
	if World.rust():
		_sip(te_veel)
		if not await na(SIP_RUST):
			return
		ctx.ui.wolk_weg("bd_nee")
		_toon_vraag()
		return
	var doel := _kamer_voor(n)
	_d()["fase"] = "heen"
	State.bewaar()
	Games.verhuis(_kamer)
	World.reis(_gast, _kamer, {"x": doel.x, "z": doel.y, "na": "wacht"})
	_volg_mee()
	if not await _tot_hij_er_is(_kamer, doel, MARGE):
		return
	_sip(te_veel)
	if te_veel:
		if not await na(TERUG_NA):
			return
		_neem_terug()
		if not await na(maxf(0.4, SIP_TIJD - TERUG_NA)):
			return
	elif not await na(SIP_TIJD):
		return
	ctx.ui.wolk_weg("bd_nee")
	# back to his place at the desk, the camera along
	_d()["fase"] = "terug"
	State.bewaar()
	Games.verhuis(KAMER)
	var balie := _balie()
	World.reis(_gast, KAMER, {"x": balie.x, "z": balie.y, "na": "wacht"})
	_volg_mee()
	if not await ctx.wacht_op(_gast, balie, {"marge": BALIE_MARGE}):
		if actief:
			ctx.sluit()
		return
	if not actief:
		return
	_nep_weg()                        # the room is out of view now
	_toon_vraag()

## Make the room hold `n` beds and say where he walks: to the free bed that
## would be his, or — no bed for him — to the floor where one would stand.
func _kamer_voor(n: int) -> Vector2:
	_nep_weg()
	_getoond.clear()
	var vrij := State.vrije_bedden(_kamer)
	var toon := maxi(0, n - _slapers)          # free beds the child asked for
	for b in vrij:
		var sid := str((b as Dictionary).get("id", ""))
		if _getoond.size() < toon:
			_getoond.append(sid)
		else:
			World.verberg_bed(_kamer, sid)
	# what is still missing stands there as a bed for this answer only
	var erbij := toon - _getoond.size()
	var i := 0
	for p in State.bed_plekken(_kamer, erbij):
		var id := "bd_nep%d" % i
		var v: Vector2 = p
		if not ctx.wereld.decor(_kamer, {"id": id, "model": "bed", "x": v.x, "z": v.y,
				"door": ctx.id}).is_empty():
			_nep.append(id)
		i += 1
	if not _getoond.is_empty():
		var s: Dictionary = Rooms.slot(_kamer, _getoond[0])
		return Vector2(float(s.get("sx", s.get("x", 0.0))), float(s.get("sz", s.get("z", 0.0))))
	if not _nep.is_empty():
		var stuk := World.decor_plek(_nep[0], _kamer)
		# the standing place beside a bed along x (`Rooms._af_slot`)
		return Vector2(float(stuk.get("x", 0.0)) + 2.0, float(stuk.get("z", 0.0)) + 12.0)
	# no bed for him: he stands in the middle of the room and looks round for
	# one — the free floor nearest its centre (the farthest free cell, where a
	# new bed would go, can lie right in front of the bowl or the basket)
	return midden_van(_kamer)

## The free floor cell nearest the middle of a room.
static func midden_van(kamer_id: String) -> Vector2:
	var r = Rooms.get_kamer(kamer_id)
	if r == null:
		return Vector2(40.0, 40.0)
	var mid := Vector2(float(r.w) / 2.0, float(r.d) / 2.0)
	var beste := mid
	var af := INF
	for cel in r.vrij:
		var p := Vector2(float(cel["x"]), float(cel["z"]))
		if p.distance_to(mid) < af:
			af = p.distance_to(mid)
			beste = p
	return beste

## "Te veel": the beds made for this answer go away again, in view.
func _neem_terug() -> void:
	for sid in _getoond:
		World.verberg_bed(_kamer, sid)
	_getoond.clear()
	_nep_weg()
	ctx.snd.terug()

func _nep_weg() -> void:
	for id in _nep:
		ctx.wereld.decor_weg(_kamer, id)
	_nep.clear()

## Disappointed: sad where he stands (`sip` sulks for six seconds), a soft
## sound and one bubble over him — pictogram and word, never a cross.
func _sip(te_veel: bool) -> void:
	ctx.snd.zacht()
	World.blijf(_gast, "sip")
	var d = World.dier(_gast)
	ctx.ui.wolk({"id": "bd_nee", "kamer": d.kamer if d != null else _kamer,
		"volg": _volg_gast(SIP_HOOG), "hoog": SIP_HOOG, "icoon": ICOON,
		"tekst": TE_VEEL if te_veel else GEEN_BED, "prio": 12})
	print("[probe] bedden sip=", "veel" if te_veel else "weinig", " kamer=",
		d.kamer if d != null else "")

# ---------------------------------------------------------------- lopen

## The camera walks along with him (`Hotel.volg`): the game awaits him for this
## walk, and only the awaited animal of a running game may be followed.
func _volg_mee() -> void:
	Games.verwacht(_gast, Games.beurt(), true)
	Hotel.volg(_gast)

## Until he stands at `plek` in `kamer`.  A walk another order took over (he
## sulked, he wandered) is sent again; one that takes far too long ends with
## him put there.  False when this start of the game is over.
func _tot_hij_er_is(kamer: String, plek: Vector2, marge: float) -> bool:
	var beurt := Games.beurt()
	var t := 0.0
	var los := 0.0
	while true:
		var d = World.dier(_gast)
		if d == null:
			if actief:
				ctx.sluit()
			return false
		var stil: bool = str(d.reis_doel).is_empty() and (d.route as Array).is_empty() \
			and (d.punten as Array).is_empty() and d.staat != "komt"
		if stil and d.kamer == kamer and Vector2(d.x, d.z).distance_to(plek) <= marge:
			break
		if stil:
			los += TIK
			if los >= HERSTUUR:
				los = 0.0
				if d.kamer == kamer:
					World.ga(_gast, plek.x, plek.y, "wacht")
				else:
					World.reis(_gast, kamer, {"x": plek.x, "z": plek.y, "na": "wacht"})
		else:
			los = 0.0
		if not await na(TIK):
			return false
		t += TIK
		if t >= MAX_LOOP:
			World.zet(_gast, kamer, plek.x, plek.y)
			break
	Games.verwacht(_gast, beurt, false)
	return actief

func _volg_gast(hoog: float) -> Callable:
	var id := _gast
	return func() -> Dictionary:
		var d = World.dier(id)
		if d == null:
			return {}
		return {"x": d.x, "z": d.z, "y": hoog, "kamer": d.kamer,
			"vlak": World.vlak_van_dier(id), "d": d.x + d.z + 0.6}

# --------------------------------------------------------------------- stop

func stop() -> void:
	if ctx != null:
		if _kaart != null:
			_kaart.weg()
		for id in ["bd_nee", "bd_slaap"]:
			ctx.ui.wolk_weg(id)
		_nep_weg()
		# Beds hidden in a room nobody looks at come back now; in view they come
		# back when the camera leaves it (no bed pops up in front of the child).
		if not _kamer.is_empty() and World.kamer_nu() != _kamer:
			World.toon_bedden(_kamer)
		print("[probe] spel=stop id=bedden fase=", str(_d().get("fase", "")))
		# The beds are not right yet: the check-in is not over.  He walks back
		# to the desk and the room question comes again (world.md §3.3).
		var v = State.s["checkin"]
		if v != null and str(v.get("gastId", "")) == _gast:
			Hotel.checkin_terug()
		State.bewaar()
	_kaart = null
	_bezig = false
