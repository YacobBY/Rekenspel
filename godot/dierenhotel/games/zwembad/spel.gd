extends MiniGame
## G1 — HET ZWEMBAD (games-b.md §1).
##
## A guest with the 🏊 wish swims a lane of `L` metres, and **the pool itself is
## the number line**: `0 … L` maps linearly onto `bad.x0 … bad.x1`, one metre is
## one stroke, and the child picks how far he swims next from four buttons.
##
## The owner's rules are binding and are all here (§1.3–§1.7):
##   * the lane is variable per band (band 5: 31…80 m, not 76 — A1 §13 Q-X3-1);
##   * at most `M` metres per pick;
##   * exactly reaching the other side says "Precies aan de overkant!";
##   * a wrong answer gets NO help (owner, 2026-09-24: "Nee geef geen hulp na
##     fouten.  Kinderen moeten zelf leren rekenen") and buys NOTHING (owner,
##     2026-10-08: "het moet niet mogelijk zijn om rekenen over te slaan"):
##     too short, too many or past the wall, he does not swim at all, he sulks
##     where he is with `🔄 Nog een keer` and the same card stays — no "nog
##     13 m", no "hooguit 30 m", no help line, no markers lighting up, never a
##     cross and never a star less.  An open question with a miss comes back
##     unchanged after any exit: a reload, a new day, another animal picked on
##     the game bar (`start`).
##
## The numbers come from `Sommen.Zwembad` and are never re-implemented here
## (architecture.md §1.1 F1); the ordering of the four buttons is the frozen
## G1-F1 rule, so the owner's own card (43 → 43, 13, 20, 30) comes out.

const KAMER := "zwembad"
const KAART_ID := "zb_som"
const STROOK_ID := "zb_som_keuzes"
const WOLK_ID := "zb_wolk"
const GAST_TAG := "zb_gasttag"
const VLAG_TAG := "zb_vlagtag"
const VLAG_DECOR := "zb_vlag"

const MODEL_STREEP := "zwembad_streep"
const MODEL_VLAG := "zwembad_vlag"

const REIS_TIK := 0.22        ## how often we look whether he arrived  (§1.6)
const REIS_GEDULD := 25.0     ## and how long we keep looking
const WOLK_S := 1.1           ## a bubble between two questions
## The sulk after a wrong stroke, then the next card.  Shorter than the `sip`
## pose of `Ui.misser`, so he is put back afloat before that pose runs out —
## a pose that ran out in the water would send him paddling off.
const MIS_S := 1.4
const SNUIF_S := 1.3          ## a bump sniffs first, then is happy
const UIT_HOP := 6.0          ## voxels past the near edge: the hop out lands on the deck
const SLUIT_S := 3.4          ## reading time before the game closes
const VANGNET_S := 11.0       ## ... and the net under it

var _b: Dictionary = {}          ## the turn, exactly as it is saved
var _gast := ""
var _kaart: Ui.Kaart = null
var _bezig := false              ## a stroke is running: no second tap
var _gesloten := false
var _hersteld := false
var _t0 := 0
var _uit_kader: Callable = Callable()
var _decor_ids: Array[String] = []
var _label_ids: Array[String] = []
var _kant := ""
var _mis_nr := 0                ## every miss and every right answer gets a number

# --------------------------------------------------------------- aanmelding

func definitie() -> Dictionary:
	return {
		"naam": "Zwembad",
		"kamer": KAMER,
		"hotspot": {"obj": "startblok", "icoon": ZwembadBeurt.ICOON,
			"label": ZwembadBeurt.LABEL, "hoog": 13},
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		"wens": "zwemmen",
		"stub": false,
		"taak": {
			"id": "zwemles", "prio": 1, "icoon": ZwembadBeurt.ICOON, "kamer": KAMER,
			"wanneer": func(s: Dictionary) -> bool:
				return not ZwembadBeurt.wens_gast(s.get("gasten", []), false).is_empty(),
			"tekst": func(s: Dictionary) -> String:
				return ZwembadBeurt.taak_tekst(
					str(ZwembadBeurt.wens_gast(s.get("gasten", []), true).get("naam", ""))),
		},
	}

# ------------------------------------------------------------------- start

func start(_c: SpelCtx) -> void:
	Art.registreer_model(MODEL_STREEP, ZwembadModellen.streep)
	Art.registreer_model(MODEL_VLAG, ZwembadModellen.vlag)
	var bewaard := ZwembadBeurt.normaliseer(ctx.data(), ctx.state.band())
	_hersteld = ZwembadBeurt.geldig(bewaard, _bestaat(str(bewaard.get("gast", ""))))
	# the animal the child picked on the game bar swims; half a lane of another
	# one is simply not finished (owner, 2026-09-23)
	var wil := ctx.voorkeur(spelers())
	var weg := ""              ## whose half lane this start drops
	# ... but never a question that was missed: picking another animal must not
	# swap it for a fresh one (wave-2 rule R2) — the same swimmer, the same sum
	var mis_open := _hersteld and int(bewaard.get("mis_open", 0)) > 0
	if _hersteld and not mis_open and not wil.is_empty() \
			and wil != str(bewaard.get("gast", "")):
		_hersteld = false
		weg = str(bewaard.get("gast", ""))
	if not _hersteld:
		bewaard = _nieuwe_beurt()
	if bewaard.is_empty():
		# nobody to teach: say so and do not open (§1.1)
		ctx.ui.toast(ZwembadBeurt.GEEN_GAST, "kind")
		ctx.sluit.call_deferred()
		return
	_b = bewaard
	_gast = str(_b["gast"])
	_t0 = Time.get_ticks_msec()
	_bewaar()
	ctx.speelt(_gast)
	_uit_kader = ctx.ui.op_kader(_op_kader)
	_bouw_decor()
	print("[probe] zwembad=start gast=", _gast, " band=", _b["band"], " L=", _b["L"],
		" M=", _b["M"], " p=", _b["p"], " hersteld=", _hersteld)
	_begin()
	# who swam the dropped lane was put on the deck by the old `stop()`: he
	# makes room, or turns back when he was still on his way to the pool
	if not weg.is_empty() and weg != _gast:
		ctx.laat_gaan(weg)

func _nieuwe_beurt() -> Dictionary:
	var keus := _gast_kies()
	var wil := ctx.voorkeur(spelers())
	if not wil.is_empty():
		var g: Dictionary = ctx.state.gast_van(wil)
		keus = {"id": wil, "wens": str(g.get("behoefte", "")) == "zwemmen"
			and not bool(g.get("blij", false))}
	if keus.is_empty():
		return {}
	var band: int = ctx.state.band()
	var baan := Sommen.Zwembad.baan(ctx.state.n_gasten(), band, int(ctx.state.s["dag"]))
	return ZwembadBeurt.normaliseer({
		"gast": keus["id"], "wens": keus["wens"],
		"L": int(baan["L"]), "M": int(baan["M"]), "band": int(baan["band"]),
		"p": 0, "leg": 0, "misser": 0,
		"laatste_p": 0, "laatste_rest": int(baan["L"]), "klaar": "",
	}, band)

## Who may swim when the child picks the swimmer himself (the animal on the
## game bar): every guest with a bed, in check-in order.  `_gast_kies` stays
## the game's own choice when nobody was picked.
func spelers() -> Array:
	var uit: Array = []
	for g in ctx.state.s["gasten"]:
		if not str(g.get("bed", "")).is_empty():
			uit.append(str(g["id"]))
	return uit

## Who swims, in the order of games-b.md §1.1.
func _gast_kies() -> Dictionary:
	var gasten: Array = ctx.state.s["gasten"]
	# 1. a guest with a bed who WISHES to swim and is not happy yet
	var wensen: Array = []
	for g in gasten:
		if str(g.get("bed", "")).is_empty() or bool(g.get("blij", false)):
			continue
		if str(g.get("behoefte", "")) == "zwemmen":
			wensen.append(g)
	if not wensen.is_empty():
		for g in wensen:
			var d = ctx.wereld.dier(str(g["id"]))
			if d != null and d.kamer == KAMER:
				return {"id": str(g["id"]), "wens": true}
		return {"id": str(wensen[0]["id"]), "wens": true}
	# 2. else the guest with a bed who is already here, nearest the start edge
	var bad := _bad()
	var beste := ""
	var beste_af := INF
	for g in gasten:
		if str(g.get("bed", "")).is_empty():
			continue
		var d = ctx.wereld.dier(str(g["id"]))
		if d == null or d.kamer != KAMER:
			continue
		var af: float = absf(d.x - float(bad.get("x0", 18))) \
			+ absf(d.z - ZwembadBeurt.baan_z(bad))
		if af < beste_af:
			beste_af = af
			beste = str(g["id"])
	if not beste.is_empty():
		return {"id": beste, "wens": false}
	# 3. else the first guest with a bed, else the first guest at all
	for g in gasten:
		if not str(g.get("bed", "")).is_empty():
			return {"id": str(g["id"]), "wens": false}
	if not gasten.is_empty():
		return {"id": str(gasten[0]["id"]), "wens": false}
	return {}

## The swimmer first, then the question (owner, 2026-09-23: "Zorg dat de
## minigame pas begint wanneer het dier er is" — this turns PLAN N3 step 1
## round, where the first card stood there while he was still in another
## room).  He walks to the deck at the start of the lane, through the doors
## with the hotel's "komt eraan" bubble and its `👀 Volg` at the gate, and the
## card comes the moment he stands there (`ctx.wacht_op`).  A lane that was
## half swum waits for him on the deck its `stop()` put him on (`_dek_nu`).
## The stair, the dive and the swim are still what the first ANSWER buys:
## `_kies()` puts him in the water, on his own metre.
func _begin() -> void:
	if not await ctx.wacht_op(_gast, _dek_nu()):
		if actief:
			ctx.sluit.call_deferred()      # the swimmer is gone: nobody to teach
		return
	if not actief or not str(_b.get("klaar", "")).is_empty():
		return
	_zet_gasttag()
	_vraag()

# --------------------------------------------------------------- de vraag

func _vraag() -> void:
	if not actief or not str(_b.get("klaar", "")).is_empty():
		return
	_kaart_weg()
	var l := int(_b["L"])
	var m := int(_b["M"])
	var p := int(_b["p"])
	var keus := Sommen.Zwembad.keuze_getallen(l, m, p, int(_b["band"]), int(_b["leg"]))
	var keuzes: Array = []
	for waarde in keus["lijst"]:
		var v := int(waarde)
		keuzes.append({
			"id": "m%d" % v, "icoon": ZwembadBeurt.ICOON,
			"tekst": ZwembadBeurt.keuze_woord(v), "kort": str(v),
			"titel": ZwembadBeurt.keuze_woord(v),
			"kies": func(_id) -> void: _kies(v),
		})
	var eerste := p == 0
	# a wrong answer no longer moves him (owner 2026-10-08), so there is no
	# card "after a bump" any more: every card is the start card or the next one
	var regel := ZwembadBeurt.regel_start(l) if eerste \
		else ZwembadBeurt.regel_verder(_naam(), p)
	_kaart = ctx.ui.somkaart(_mik_start(),
		ZwembadBeurt.som_start(l) if eerste else ZwembadBeurt.som_verder(l, p), {
			"id": KAART_ID, "kamer": KAMER, "hoog": 0.0,
			"icoon": ZwembadBeurt.KAART_ICOON,
			"pad": false, "vlak": _vrij_vak(),
			"regel": regel,
			"regel2": ZwembadBeurt.regel2_start(m) if eerste
				else ZwembadBeurt.regel2_verder(),
			"keuze_titel": ZwembadBeurt.HULP_TITEL, "keuzes": keuzes,
			# an answer strip of the game's own: its taps are maths (wave-2 R4)
			"reken": true,
		})
	_volg_kaart()
	# no help line, no lit markers, no pale marker, however many slips there
	# were (owner, 2026-09-24): the card is the question and nothing more
	_strepen_ververs()
	_meld_kaart()

## One tap on a choice button (games-b.md §1.5, and the owner's rule of
## 2026-10-08: "het moet niet mogelijk zijn om rekenen over te slaan").
##
## Only the RIGHT answer moves him.  Too short, more than he may swim at once,
## or past the wall: he does not swim one metre — he sulks where he is
## (`Ui.misser`: `sip`, `🔄 Nog een keer`, the strip locked a moment) and the
## SAME card stays, the same four numbers in the same order (`leg` only counts
## right answers, so the seed of the strip never moves).  Until 2026-10-08 a
## wrong answer swam what it bought — too many swam exactly the right amount
## and a bump threw him to a new metre with a new sum — so guessing finished
## the lane; that broke the new rule and is gone (games-b.md §1.5/§1.7 conflict,
## recorded in the wave-2 notes: the owner's new rule wins).
func _kies(n: int) -> void:
	if _bezig or not actief or not str(_b.get("klaar", "")).is_empty():
		return
	var l := int(_b["L"])
	var m := int(_b["M"])
	var p := int(_b["p"])
	var uit := Sommen.Zwembad.slag(l, m, p, n)
	var soort := str(uit["soort"])
	var meters := int(uit["meters"])
	if soort != "goed":
		_mis(n, soort)
		return
	_bezig = true
	_mis_nr += 1
	_b["mis_open"] = 0
	ctx.reken_goed()
	_b["leg"] = int(_b["leg"]) + 1
	_b["laatste_p"] = p
	_b["laatste_rest"] = maxi(0, l - p)
	ctx.ui.wolk_weg(WOLK_ID)
	_kaart_weg()          # no card = no second tap on the same question
	_bewaar()
	print("[probe] zwembad=kies n=", n, " soort=", soort, " meters=", meters,
		" p=", p, " misser=", _b["misser"])
	var gehaald := await _zorg_in_water()
	if not actief:
		return
	if gehaald:
		gehaald = await _zwem(meters)
	if not actief:
		return
	_bezig = false
	_bewaar()
	if not gehaald:
		# another order took him over, or he never reached the water: never
		# leave the child without a card — the question simply comes back with
		# the metres he DID swim (games-b.md §0.6, never punishing)
		if str(_b.get("klaar", "")).is_empty():
			_vraag()
		return
	if int(_b["p"]) >= l:
		ctx.snd.ja()
		_spat(6)               # the arrival splash (pillar 4)
		_sprankel()            # EXACTLY deserves a shine
		await _afronden("precies")
		return
	ctx.snd.ja()
	_zeg(ZwembadBeurt.PRECIES_ICOON, "%d m" % meters, "gezwommen")
	if not await na(_leestijd(WOLK_S)):
		return
	ctx.ui.wolk_weg(WOLK_ID)
	_vraag()

## A wrong answer: he is disappointed where he is — on the deck, or afloat on
## his metre — and nothing else happens.  No metre swum, no new sum, no word
## about how far is left or what the most is (owner, 2026-09-24), and the card
## with its strip stays exactly as it was (`Ui.misser` locks it a moment).
## `mis_open` counts the misses on the question that is open now: a question
## with a miss comes back unchanged after any exit (`start`, wave-2 rule R2).
func _mis(n: int, soort: String) -> void:
	_b["misser"] = int(_b["misser"]) + 1
	_b["mis_open"] = int(_b.get("mis_open", 0)) + 1
	_bewaar()
	print("[probe] zwembad=kies n=", n, " soort=", soort, " meters=0 p=", _b["p"],
		" misser=", _b["misser"])
	ctx.ui.misser(_kaart, _gast)
	# in the water the sulk must not run out there (a pose that ran out in the
	# water sent him paddling off): afloat again after `MIS_S`, unless a right
	# answer has sent him swimming in the meantime
	_mis_nr += 1
	var mijn := _mis_nr
	if not await na(_leestijd(MIS_S)):
		return
	if mijn != _mis_nr or _bezig:
		return
	var d = ctx.wereld.dier(_gast)
	if d != null and d.kamer == KAMER and _in_bad(d):
		ctx.wereld.blijf(_gast, "zwem")

# ---------------------------------------------------------------- zwemmen

## He lies in the water on metre `p`, or he goes there first (§1.6).
func _zorg_in_water() -> bool:
	var d = ctx.wereld.dier(_gast)
	if d == null:
		return false
	var bad := _bad()
	var doel_x := ZwembadBeurt.baan_x(bad, int(_b["L"]), float(_b["p"]))
	if d.kamer == KAMER and _in_bad(d) and absf(d.x - doel_x) <= 3.0:
		return true
	if _hersteld and int(_b["p"]) > 0:
		# a reload never resumes a walk: put him back where the save says he is
		_hersteld = false
		ctx.wereld.zet(_gast, KAMER, doel_x, ZwembadBeurt.baan_z(bad))
		return await ctx.wereld.loop_naar(_gast, doel_x, ZwembadBeurt.baan_z(bad),
			{"pose": "zwem", "tempo": 1.1, "na": "zwem"})
	return await _naar_water(doel_x)

func _naar_water(doel_x: float) -> bool:
	var d = ctx.wereld.dier(_gast)
	if d == null:
		return false
	var bad := _bad()
	var z := ZwembadBeurt.baan_z(bad)
	if d.kamer != KAMER:
		var dek := _dek("start")
		ctx.wereld.reis(_gast, KAMER, {"x": dek.x, "z": dek.y, "na": "wacht"})
		var gewacht := 0.0
		while gewacht < REIS_GEDULD:
			if not await na(REIS_TIK):
				return false
			gewacht += REIS_TIK
			d = ctx.wereld.dier(_gast)
			if d == null:
				return false
			if d.kamer == KAMER:
				break
		if d.kamer != KAMER:
			return false
	# the lane begins at the WEST end of the water, UP ON THE STARTBLOK: he
	# walks to the foot of its little stair, hops up slowly — three steps and
	# the block — and dives in at the 0 m mark (owner, 2026-09-17:
	# "startblokken ... met een trappetje zodat het dier langzaam omhoog kan
	# springen").  The fence moved back on both sides to make room (same
	# owner, same day: "Doe het hek verder van beide kanten van het zwembad").
	if not await ctx.wereld.loop_naar(_gast, ZwembadBeurt.trap_voet(bad), z,
			{"tempo": 1.2, "na": "wacht"}):
		return false
	for hop in ZwembadBeurt.trap_hoppen(bad):
		if not actief:
			return false
		if not await ctx.wereld.loop_naar(_gast, hop[0], z,
				{"pose": "spring", "tempo": 0.85, "land_hoogte": hop[1]}):
			return false
	if not actief:
		return false
	# a breath on the block before the dive
	if not await na(0.7):
		return false
	if not await ctx.wereld.loop_naar(_gast, ZwembadBeurt.duik_x(bad), z,
			{"pose": "spring", "tempo": 1.6, "land_hoogte": -ArtEffect.ZWEM_DIEP}):
		return false
	if not actief:
		return false
	ctx.snd.plons()
	_spat(4)
	return await ctx.wereld.loop_naar(_gast, doel_x, z,
		{"pose": "zwem", "tempo": 1.1, "na": "zwem"})

## A splash of water drops where the swimmer is (review plan pillar 4).
func _spat(n: int) -> void:
	var d = ctx.wereld.dier(_gast)
	if d != null and d.kamer == KAMER:
		ctx.wereld.spetter(KAMER, d.x, d.z, n, ArtEffect.PLONS_KL[0], true)

## Star sparkles above the swimmer — ONLY for arriving exactly (§1.7: the
## bump stays soft and keeps just its water splash).  `hoog` lifts the burst
## above his back, so it reads as a shine and not as more water.
func _sprankel() -> void:
	var d = ctx.wereld.dier(_gast)
	if d != null and d.kamer == KAMER:
		ctx.wereld.spetter(KAMER, d.x, d.z, 10, ArtEffect.STER_KL[0], true, 10.0)

## `n` metres, one point per metre — the number on his back counts with him.
## A stroke that ends at the far wall (the exact last stretch, and every bump)
## brakes over its last stretch and stops with his NOSE against the wall, the
## number saying `L` as it touches (`ZwembadBeurt.slag_x`) — his middle on
## `x(L)` stood his head on the tiles beyond the water.
func _zwem(n: int) -> bool:
	var d = ctx.wereld.dier(_gast)
	if d == null or d.kamer != KAMER:
		return false               # swimming outside the pool never happens
	var l := int(_b["L"])
	var p0 := int(_b["p"])
	var aantal := clampi(n, 0, maxi(0, l - p0))
	if aantal <= 0:
		return true
	var bad := _bad()
	var z := ZwembadBeurt.baan_z(bad)
	var xs := ZwembadBeurt.slag_x(bad, l, p0, aantal, float(d.x))
	var snel: Array = xs["snel"]
	var traag: Array = xs["traag"]
	var elke := ZwembadBeurt.plons_elke(aantal)
	if not snel.is_empty():
		if not await ctx.wereld.stappen(_gast, _op_de_baan(snel, z), {"pose": "zwem",
				"tempo": ZwembadBeurt.tempo_van(l), "per_stap": _slag_stap(p0, 0, elke),
				"na": "zwem"}):
			return false
		if not actief:
			return false
	if traag.is_empty():
		return true
	return await ctx.wereld.stappen(_gast, _op_de_baan(traag, z), {"pose": "zwem",
		"tempo": ZwembadBeurt.TRAAG, "per_stap": _slag_stap(p0, snel.size(), elke),
		"na": "zwem"})

static func _op_de_baan(xs: Array, z: float) -> Array:
	var uit: Array = []
	for x in xs:
		uit.append(Vector2(float(x), z))
	return uit

## What every metre of a stroke does as he passes it: the number on his back,
## a plons now and then, and the marker he has just swum past colours itself
## in (§1.9).  `voor` = the metres of this stroke already swum by an earlier
## part of it (the slow stretch before the wall is a second order).
func _slag_stap(p0: int, voor: int, elke: int) -> Callable:
	var l := int(_b["L"])
	var bad := _bad()
	var zrand := ZwembadBeurt.rand_z(bad)
	return func(i: int, _punt: Vector2) -> void:
		var k := voor + i
		_b["p"] = mini(l, p0 + k + 1)
		_zet_gasttag()
		if k % elke == 0:
			ctx.snd.plons()
			_spat(2)
		var p := int(_b["p"])
		var sm := int(_b["stap"])
		if p % sm == 0 and p < l:
			_streep_zet(p, p % (2 * sm) == 0,
				float(JsGetal.rond(ZwembadBeurt.baan_x(bad, l, p))), zrand)

# ------------------------------------------------------------- de twee einden

## games-b.md §1.7, in this order.
func _afronden(soort: String) -> void:
	if not actief or not str(_b.get("klaar", "")).is_empty():
		return
	_b["klaar"] = soort
	_bewaar()
	if bool(_b.get("wens", false)):
		ctx.wereld.behoefte_klaar(_gast, "zwemmen")
	ctx.state.tel(int(_b["misser"]) == 0, Time.get_ticks_msec() - _t0)
	# the star belongs to the lane that was really swum: since N3 this point is
	# only reached by answering exactly (PLAN §3.8, open question V1 — it used to
	# be handed out after a bump too, `architecture.md §1.1 F5`, which let one tap
	# on a number that was too big finish twelve of the thirteen band-3 lanes)
	ctx.taak_klaar("zwemles")
	_eindkaart(soort)
	ctx.ui.toast(ZwembadBeurt.TOAST_PRECIES if soort == "precies"
		else ZwembadBeurt.TOAST_BOTS, "happy")
	print("[probe] zwembad=af soort=", soort, " L=", _b["L"], " misser=", _b["misser"],
		" sterren=", int(State.s["sterren"]))
	var droog := await _uit_het_water()
	if not actief:
		return
	if soort == "bots" and droog:
		ctx.wereld.pose(_gast, "snuif", 18)
		if not await na(SNUIF_S):
			return
	ctx.wereld.pose(_gast, "blij", 45)
	ctx.hotspots.weg(GAST_TAG)
	_sluit_straks()

## The end card aims at the DECK he is about to climb onto instead of at the
## swimmer still lying in the water (PLAN N3 step 6): by the time the child has
## read it he is out, and a card that hugged his old spot would have to move.
func _eindkaart(soort: String) -> void:
	_kaart_weg()
	var l := int(_b["L"])
	var precies := soort == "precies"
	_kaart = ctx.ui.somkaart(_mik_dek(), ZwembadBeurt.som_af(l, int(_b["laatste_p"]),
			int(_b["laatste_rest"]), int(_b["leg"]) > 0), {
		"id": KAART_ID, "kamer": KAMER, "hoog": 0.0, "pad": false,
		"vlak": _dek_vak(),
		"icoon": ZwembadBeurt.PRECIES_ICOON if precies else ZwembadBeurt.BOTS_ICOON,
		"regel": ZwembadBeurt.EIND_PRECIES if precies
			else ZwembadBeurt.eind_regel_bots(_naam()),
		"regel2": ZwembadBeurt.eind_regel2_precies(_naam(), l) if precies
			else ZwembadBeurt.eind_regel2_bots(int(_b["laatste_rest"])),
	})
	_volg_kaart()
	_kaart.klaar()
	_meld_kaart()

## Out of the water (§1.8): swim to the near edge first, hop out over the rim
## onto the deck, then walk to his deck spot, so a wander never starts from
## inside the pool.  The hop is the climb out (he used to walk up out of the
## water, standing on it), and it lands him ON the deck: a walk after the dive
## arrived at the dive's depth and left him standing sunk in the tiles
## (`World._aangekomen` keeps the `spring_land` of the last jump; the fix for
## that belongs in World and is written down in the PLAN.md §7 line of this
## change).
func _uit_het_water() -> bool:
	var d = ctx.wereld.dier(_gast)
	if d == null:
		return false
	var bad := _bad()
	var dek := _dek_nu()
	if d.kamer == KAMER and _in_bad(d):
		var rand_x := clampf(d.x, float(bad["x0"]), float(bad["x1"]))
		if not await ctx.wereld.loop_naar(_gast, rand_x, float(bad["z1"]) - 1.0,
				{"pose": "zwem", "tempo": 1.2, "na": "wacht"}):
			return false
		if not actief:
			return false
		_spat(3)
		if not await ctx.wereld.loop_naar(_gast, rand_x, float(bad["z1"]) + UIT_HOP,
				{"pose": "spring", "tempo": 0.9, "land_hoogte": 0.0, "na": "wacht"}):
			return false
		if not actief:
			return false
	return await ctx.wereld.loop_naar(_gast, dek.x, dek.y, {"tempo": 1.2, "na": "wacht"})

func _sluit_straks() -> void:
	_sluit_na(SLUIT_S)
	_sluit_na(VANGNET_S)

func _sluit_na(seconden: float) -> void:
	if not await na(seconden):
		return
	_sluit_als()

## Only close when the turn really is finished, and never with a guest afloat.
func _sluit_als() -> void:
	if not actief or _gesloten or str(_b.get("klaar", "")).is_empty():
		return
	_gesloten = true
	_nood_uit()
	ctx.sluit()

# ------------------------------------------------------------------ decor

## One metre marker, re-issued as it is (a `World.decor` with the same id and
## `door` replaces the piece, which is how a marker recolours).  `gehaald`
## falls out of `_b["p"]` alone, so a reload and a frame change derive it
## again: the knobs he has swum past wear the flag pink.  Nothing lights up
## after a slip (owner, 2026-09-24).
func _streep_zet(m: int, groot: bool, x: float, z: float) -> void:
	var id := "zb_streep_%d" % m
	ctx.wereld.decor(KAMER, {"id": id, "model": MODEL_STREEP, "door": ctx.id,
		"x": x, "z": z, "params": {"groot": groot,
			"gehaald": m > 0 and m <= int(_b["p"])}})
	if not _decor_ids.has(id):
		_decor_ids.append(id)

func _bouw_decor() -> void:
	var l := int(_b["L"])
	var stap := int(_b["stap"])
	var bad := _bad()
	var z := ZwembadBeurt.rand_z(bad)
	var k := float(ctx.wereld.schaal().get("k", 1.0))
	var lstap := ZwembadBeurt.label_stap(l, stap, bad, k)
	for id in _label_ids:
		ctx.hotspots.weg(id)
	_label_ids.clear()
	var m := 0
	while m < l:
		var groot := (m % (2 * stap)) == 0
		var x := float(JsGetal.rond(ZwembadBeurt.baan_x(bad, l, m)))
		_streep_zet(m, groot, x, z)
		# a bare number on the rim, but only on a BIG marker and only as often
		# as two labels still stand 34 px apart
		if groot and (m % lstap) == 0:
			var tid := "zb_label_%d" % m
			ctx.ui.getal_tag({"x": x, "z": z}, m,
				{"id": tid, "kamer": KAMER, "y": 11, "prio": 6})
			_label_ids.append(tid)
		m += stap
	var vx := float(JsGetal.rond(ZwembadBeurt.baan_x(bad, l, l)))
	var vz := ZwembadBeurt.vlag_z(bad)
	ctx.wereld.decor(KAMER, {"id": VLAG_DECOR, "model": MODEL_VLAG, "door": ctx.id,
		"x": vx, "z": vz})
	if not _decor_ids.has(VLAG_DECOR):
		_decor_ids.append(VLAG_DECOR)
	ctx.ui.getal_tag({"x": vx, "z": vz}, "%d m" % l,
		{"id": VLAG_TAG, "kamer": KAMER, "y": 34, "prio": 8})

## Re-issue only the markers of the rim, with the current `gehaald` — no
## numbers and no flag.
func _strepen_ververs() -> void:
	var l := int(_b["L"])
	var stap := int(_b["stap"])
	var bad := _bad()
	var z := ZwembadBeurt.rand_z(bad)
	var m := 0
	while m < l:
		var x := float(JsGetal.rond(ZwembadBeurt.baan_x(bad, l, m)))
		_streep_zet(m, (m % (2 * stap)) == 0, x, z)
		m += stap

func _decor_weg() -> void:
	for id in _decor_ids:
		ctx.wereld.decor_weg(KAMER, id)
	_decor_ids.clear()

# ------------------------------------------------------- de kaart en haar marges

## The card's aim point, recomputed inside the hotspot's own `volg` callable so
## that it is part of the ONE placement pass of architecture.md §4.3 — never a
## measurement after a paint (games-b.md §1.10, G1-F2).
func _volg_kaart() -> void:
	var s := Hits.spot(KAART_ID)
	if s != null:
		s.volg = _kaart_volg

func _kaart_volg() -> Dictionary:
	var kader: Rect2 = ctx.wereld.kader_rect()
	if kader.size.x <= 1.0 or kader.size.y <= 1.0:
		return {}
	# while the turn runs the card keeps off the swimmer; once it is finished the
	# card belongs to the deck, so it stops chasing him out of the water (N3)
	var vrij := _dek_vak() if not str(_b.get("klaar", "")).is_empty() else _vrij_vak()
	var plek := ZwembadKaartplek.kies(kader.size, _maat_van(KAART_ID),
		_maat_van(STROOK_ID), vrij, _vlag_vak())
	_kant = str(plek["kant"])
	var v: Vector3 = ZwembadKaartplek.punt_naar_voxel(ctx.wereld, plek["midden"])
	return {"x": v.x, "z": v.y, "y": v.z, "kamer": KAMER, "vlak": vrij}

## The measured size of a hotspot's Control.  `get_combined_minimum_size()` is
## synchronous and exact before the first draw, which is the whole reason the
## HTML's measure-and-shove machinery is gone (architecture.md §1.2).
func _maat_van(id: String) -> Vector2:
	var s := Hits.spot(id)
	if s == null or not is_instance_valid(s.knoop):
		return Vector2.ZERO
	var m: Vector2 = s.knoop.get_combined_minimum_size()
	return Vector2(maxf(m.x, 48.0), maxf(m.y, 48.0))

## The box the guest occupies: his plate, plus the number on his back and his
## name plate above it, plus the sway of a swimmer.  All of it measured, none
## of it guessed.
func _vrij_vak() -> Rect2:
	var d = ctx.wereld.dier(_gast)
	var r := Rect2()
	if d != null and d.kamer == KAMER:
		r = ctx.wereld.vlak_van_dier(_gast)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		# still in another room — which since N3 is the normal state of the FIRST
		# card: reckon with the entry side of the lane (§1.10)
		var bad := _bad()
		r = _vak_op(float(bad.get("x0", 18)), ZwembadBeurt.baan_z(bad))
	var boven := 0.0
	var breed := r.size.x
	for id in [GAST_TAG, "naam_" + _gast]:
		var s := Hits.spot(id)
		if s == null or not is_instance_valid(s.knoop):
			continue
		var m: Vector2 = s.knoop.get_combined_minimum_size()
		boven += m.y + Hits.GAT
		breed = maxf(breed, m.x)
	var zij := maxf(1.0, float(ctx.wereld.schaal().get("k", 1.0)))
	var mid := r.position.x + r.size.x * 0.5
	return Rect2(Vector2(mid - breed * 0.5 - zij, r.position.y - boven),
		Vector2(breed + zij * 2.0, r.size.y + boven))

## A guest-sized patch of screen around a floor point: what a card keeps off
## when the guest himself is not there to be measured.
func _vak_op(x: float, z: float) -> Rect2:
	var punt: Vector2 = ctx.wereld.mik_punt(x, z, 0.0)
	return Rect2(punt - Vector2(24.0, 44.0), Vector2(48.0, 48.0))

## Where he leaves the water, and the box he will stand in there.
func _mik_dek() -> Dictionary:
	var dek := _dek_nu()
	return {"x": dek.x, "z": dek.y}

func _dek_vak() -> Rect2:
	var dek := _dek_nu()
	return _vak_op(dek.x, dek.y)

func _dek_nu() -> Vector2:
	return _dek("over" if int(_b.get("p", 0)) * 2 >= int(_b.get("L", 1)) else "start")

## The box of the flag and the `<L> m` that hangs on it.
func _vlag_vak() -> Rect2:
	var bad := _bad()
	var l := int(_b.get("L", 1))
	var r: Rect2 = ctx.wereld.vlak_van(MODEL_VLAG,
		float(JsGetal.rond(ZwembadBeurt.baan_x(bad, l, l))),
		ZwembadBeurt.vlag_z(bad), 0.0, {})
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return Rect2()
	var hoog := 24.0
	var breed := r.size.x
	var s := Hits.spot(VLAG_TAG)
	if s != null and is_instance_valid(s.knoop):
		var m: Vector2 = s.knoop.get_combined_minimum_size()
		hoog = m.y
		breed = maxf(breed, m.x)
	var mid := r.position.x + r.size.x * 0.5
	return Rect2(Vector2(mid - breed * 0.5, r.position.y - hoog - Hits.GAT),
		Vector2(breed, r.size.y + hoog + Hits.GAT))

func _kaart_weg() -> void:
	if _kaart != null:
		_kaart.weg()
		_kaart = null
	ctx.hotspots.weg(KAART_ID)
	ctx.hotspots.weg(STROOK_ID)

## The frame changed shape: the label step depends on the scale, so the rim is
## laid out again.  The card needs nothing — its `volg` already recomputes.
func _op_kader(_rect: Rect2, _schaal: Dictionary) -> void:
	if actief:
		_bouw_decor()

# ------------------------------------------------------------------- stoppen

## games-b.md §1.12: every tick cancelled, card and bubble away, NOBODY left in
## the water, every number and every own piece of decor gone, and saved.
func stop() -> void:
	_bezig = false
	if _uit_kader.is_valid():
		_uit_kader.call()
		_uit_kader = Callable()
	_kaart_weg()
	ctx.ui.wolk_weg(WOLK_ID)
	_nood_uit()
	ctx.hotspots.weg(GAST_TAG)
	ctx.hotspots.weg(VLAG_TAG)
	for id in _label_ids:
		ctx.hotspots.weg(id)
	_label_ids.clear()
	_decor_weg()
	_bewaar()
	print("[probe] zwembad=stop p=", _b.get("p", 0), " klaar=", _b.get("klaar", ""))

## Still afloat when the game goes: straight onto the deck, never left swimming.
func _nood_uit() -> void:
	if _gast.is_empty():
		return
	var d = ctx.wereld.dier(_gast)
	if d == null or d.kamer != KAMER or not _in_bad(d):
		return
	var dek := _dek_nu()
	ctx.wereld.zet(_gast, KAMER, dek.x, dek.y)

# ------------------------------------------------------------------ hulpjes

## games-b.md §0.11: in reduced motion the swim itself costs no time at all, so
## the beat between two questions may be SHORTENED — never skipped, or the
## bubble would be gone before the child had read it.  The end card and the
## bump keep their full time: those are the two the child reads longest.
func _leestijd(seconden: float) -> float:
	return seconden * 0.5 if ctx.wereld.rust() else seconden

func _bewaar() -> void:
	var d := ctx.data()
	for sleutel in _b.keys():
		d[sleutel] = _b[sleutel]
	State.bewaar()

func _bad() -> Dictionary:
	var r = Rooms.get_kamer(KAMER)
	return {} if r == null else r.bad

func _dek(welke: String) -> Vector2:
	var r = Rooms.get_kamer(KAMER)
	if r == null or not (r.dek as Dictionary).has(welke):
		return Vector2(12.0, 56.0)
	return r.dek[welke]

func _in_bad(d) -> bool:
	var bad := _bad()
	if bad.is_empty():
		return false
	return d.x >= float(bad["x0"]) - 2.0 and d.x <= float(bad["x1"]) + 2.0 \
		and d.z >= float(bad["z0"]) and d.z <= float(bad["z1"])

func _bestaat(id: String) -> bool:
	return not id.is_empty() and not ctx.state.gast_van(id).is_empty()

func _naam() -> String:
	var g: Dictionary = ctx.state.gast_van(_gast)
	return str(g.get("naam", _gast)) if not g.is_empty() else _gast

## Where a fresh card starts before its own `volg` has spoken: on the swimmer.
func _mik_start() -> Dictionary:
	var d = ctx.wereld.dier(_gast)
	var bad := _bad()
	if d != null and d.kamer == KAMER:
		return {"x": d.x, "z": d.z}
	return {"x": float(bad.get("x0", 18)), "z": ZwembadBeurt.baan_z(bad)}

## The number that swims with him (§1.9): `<p> m`, on the guest, prio 10.
## `metre` shows a number other than the saved one: while the wall throws him
## back the save already holds the metre he ends on, and his back counts down
## to it.
func _zet_gasttag(metre: int = -1) -> void:
	if _gast.is_empty():
		return
	var m := int(_b.get("p", 0)) if metre < 0 else metre
	ctx.ui.getal_tag({"x": 0.0, "z": 0.0}, "%d m" % m, {
		"id": GAST_TAG, "kamer": KAMER, "y": 18, "prio": 10,
		"volg": _volg_gast,
	})

func _volg_gast() -> Dictionary:
	var d = ctx.wereld.dier(_gast)
	if d == null:
		return {}
	return {"x": d.x, "z": d.z, "kamer": d.kamer,
		"vlak": ctx.wereld.vlak_van_dier(_gast)}

func _zeg(icoon: String, getal: String, tekst: String) -> void:
	ctx.ui.wolk({"id": WOLK_ID, "kamer": KAMER, "hoog": 54.0, "prio": 11,
		"icoon": icoon, "getal": null if getal.is_empty() else getal,
		"tekst": tekst, "volg": _volg_gast})

## One machine-readable line per card, for the browser probe: where the card
## and every choice button really are, and how much air they keep.
func _meld_kaart() -> void:
	# two frames, not a timer: `Hits.plaats()` runs once per drawn frame and a
	# press is handled AFTER that pass, so one frame reports the previous
	# layout (scenes/main.gd `_na_plaatsing`).  A frame signal also cannot
	# outlive the node, which a timer can.
	await get_tree().process_frame
	await get_tree().process_frame
	if not actief:
		return
	var s := Hits.spot(KAART_ID)
	if s == null or not is_instance_valid(s.knoop):
		return
	var kaart: Rect2 = s.knoop.get_global_rect()
	var juist := Sommen.Zwembad.juist_van(int(_b["L"]), int(_b["M"]), int(_b["p"]))
	print("[probe] zwembad kaart=", kaart, " kant=", _kant,
		" lucht_gast=", "%.1f" % ZwembadKaartplek.lucht(kaart, _vrij_vak()),
		" lucht_vlag=", "%.1f" % ZwembadKaartplek.lucht(kaart, _vlag_vak()),
		" dekking=", "%.2f" % Hits.dekking(KAART_ID), " juist=", juist)
	var strook := Hits.spot(STROOK_ID)
	if strook == null or not is_instance_valid(strook.knoop):
		return
	# the strip as one rectangle, in the form `tools/speel.js` taps
	# (`zb_som_keuzes#k/4`): without it the pool could not be played there
	print("[probe] ", STROOK_ID, "=", (strook.knoop as Control).get_global_rect())
	var rij := strook.knoop.get_node_or_null("Rij")
	if rij == null:
		return
	for knop in rij.get_children():
		print("[probe] zwembad knop ", knop.name, "=", (knop as Control).get_global_rect())
