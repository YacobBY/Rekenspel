extends MiniGame
## oogst — "Aardbeien plukken" (games-c.md §2).
##
## In de kas staat de pluktafel met tien plekken voor bakjes van tien.  Er
## staan volle bakjes en één open bakje; het kind telt hoeveel aardbeien er
## liggen (tientallen en eenheden), rekent uit hoeveel er nog bij moeten
## (splitsen tot 10, aanvullen tot het tiental of tot 100) en plukt ze daarna
## zelf uit de aardbeienbak: één per tik, en in groep 5 na het volle bakje een
## heel bakje per tik — "via de tien" om naar honderd te komen.  De gast van de
## beurt staat naast de tafel en eet mee.
##
## Rekenen eerst (PLAN.md R1): de telvraag staat er meteen, het plukken komt pas
## na de twee sommen (R2/R3).  Een misser kost niets (HOTEL.md §9, S5): de
## centrale strook van `Ui` doet de pauze en dezelfde vier keuzes, dit spel
## geeft de hulpladder — samen tellen, nog eens, en bij de derde misser een
## bleek getal op de tafel of bleke aardbeien in het open bakje.
##
## De getallen komen uit `beurt.gd` (eigen gezaaide generator, `core/sommen.gd`
## blijft bevroren); de tafel met haar bakjes is één model (`modellen.gd`).

const KAMER := "kas"
const Modellen := preload("res://games/oogst/modellen.gd")
const Beurt := preload("res://games/oogst/beurt.gd")

const TAFEL_ID := "og_tafel"
const RUST_TAFEL := "rust_og_tafel"
## The strawberry planter (fixed decor of the kas): the berries come from it,
## the pick button hangs on it, and the entry button is anchored to it.
const BAK := "aardbeienbakz"
const BAK_X := 7
const BAK_Z := 38
const KAART_ID := "og_som"
const STROOK_ID := "og_som_keuzes"
const PLUK_ID := "og_pluk"
const HULP_ID := "og_hulp"
const SPOOK_ID := "og_spook"
const LEKKER_ID := "og_lekker"
const LEEG_ID := "og_leeg"

## The table in front of the planter, and the guest of the turn beside it, on
## the terracotta path (the guest may never stand in front of the punnets).
const TAFEL_X := 30
const TAFEL_Z := 38
const GAST_X := 64.0
const GAST_Z := 32.0
## The resting table (world.md §5.1): five empty punnets waiting in the left
## column, so the entry hangs on something that says "strawberries go here".
const RUST_BAKJES := [0, 0, 0, 0, 0]

const KAART_HOOG := 26.0     ## the card's aim over the table (when it floats)
const PLUK_HOOG := 12.0
const HULP_HOOG := 14.0
const SPOOK_HOOG := 18.0
const LEKKER_HOOG := 44.0

const SOM_S := 0.6           ## a right answer, then the next card this much later
const AF_S := 3.4            ## the end card is readable this long before it closes
const LEEG_S := 1.8
const GAST_POLL := 0.7       ## looking for the guest on the way, every 0.7 s …
const GAST_KEER := 24        ## … at most 24 times
const BLIJF_S := 1.5         ## how often the guest of the turn is kept at his spot
const SPOOK_NA := 3          ## the ghost numbers come at the third miss (games-b.md §0.5)

## The turn.  Lives in `ctx.data()["stand"]`; every number is read back through
## `int()`, because JSON hands them back as floats.
var S: Dictionary = {}
## The table of today — purely a function of N, band and day (`Beurt.opzet`),
## so it is recomputed at every start and never saved.
var O: Dictionary = {}
var _kaart = null            ## Ui.Kaart
var _kaart_stap := ""        ## the step the card on screen was built for
var _kaart_hulp := ""        ## the help line the card carries now (small frames)
var _t0 := 0
var _gast_gestuurd := false
var _gast_keer := 0

# ------------------------------------------------------------- aanmelding

func definitie() -> Dictionary:
	# None of these may touch `self`: the registry reads `definitie()` from a
	# throwaway instance and frees it again (architecture.md §6.1).
	return {
		"naam": "Aardbeien plukken",
		"kamer": KAMER,
		"stub": false,
		# The table only exists as a resting prop (and during a turn), so the
		# entry is anchored to the planter, the nearest FIXED piece, and slid onto
		# the table; while the resting table stands it hangs ON it.
		"hotspot": {"obj": BAK, "dx": TAFEL_X - BAK_X, "dz": TAFEL_Z - BAK_Z,
			"icoon": Beurt.ICOON, "label": "Plukken", "hoog": 14, "rust": RUST_TAFEL},
		"modellen": Modellen.tabel(),
		"rust": [{"id": RUST_TAFEL, "model": "oogst_tafel", "x": float(TAFEL_X),
			"z": float(TAFEL_Z), "params": {"b": RUST_BAKJES}}],
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		"taak": {"id": "oogst", "icoon": Beurt.ICOON, "tekst": "Pluk de aardbeien",
			"kamer": KAMER, "prio": 6},
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
	# Resume only when the saved turn is still THIS turn (games-c.md §2.10).
	if S.is_empty() or g.is_empty() or int(S["dag"]) != dag or int(S["N"]) != n \
			or int(S["band"]) != band or _stap() == "af":
		g = kies[(dag + n) % kies.size()]
		S = _nieuwe_stand(g, n, band, dag)
	d["stand"] = S
	O = Beurt.opzet(n, band, dag)
	_t0 = Time.get_ticks_msec()
	_kaart = null
	_kaart_stap = ""
	_gast_gestuurd = false
	_gast_keer = 0
	# the table first: the card hangs on it, so it must stand before the card asks
	_zet_tafel()
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

## Who picks: everyone with a bed.  Nobody yet: the game says so and closes.
func _kandidaten() -> Array:
	var uit: Array = []
	for g in ctx.state.s["gasten"]:
		if not str(g.get("bed", "")).is_empty():
			uit.append(g)
	return uit

func _meld_leeg() -> void:
	var b := World.mik(BAK, KAMER)
	ctx.ui.wolk({"id": LEEG_ID, "kamer": KAMER, "obj": BAK, "op": "aan",
		"x": float(b.get("x", BAK_X)), "z": float(b.get("z", BAK_Z)), "hoog": 16.0,
		"icoon": "🛏", "tekst": Beurt.T_LEEG, "prio": 12})
	if not await na(LEEG_S):
		return
	ctx.ui.wolk_weg(LEEG_ID)
	ctx.sluit()

func _nieuwe_stand(g: Dictionary, n: int, band: int, dag: int) -> Dictionary:
	return {"gast": str(g.get("id", "")), "dag": dag, "N": n, "band": band,
		"stap": "tel", "geplukt": 0, "pog": 0, "missers": 0, "ster": 0}

## A turn that came through the save is JSON: every number a float.
static func _normaliseer(st: Dictionary) -> Dictionary:
	for k in ["dag", "N", "band", "geplukt", "pog", "missers", "ster"]:
		st[k] = int(st.get(k, 0))
	st["gast"] = str(st.get("gast", ""))
	var stap := str(st.get("stap", "tel"))
	st["stap"] = stap if stap in ["tel", "bij", "pluk", "af"] else "tel"
	return st

func _stap() -> String:
	return str(S.get("stap", ""))

func _gast() -> Dictionary:
	if S.is_empty() or ctx == null:
		return {}
	return ctx.state.gast_van(str(S.get("gast", "")))

func _gast_id() -> String:
	return str(S.get("gast", ""))

func _bewaar() -> void:
	if ctx != null and not S.is_empty():
		ctx.data()["stand"] = S
		State.bewaar()

# ------------------------------------------------------------ de gast halen

## The guest of the turn walks to the table.  In another room he travels
## through the doors first — sent ONCE, because sending him again on the way
## restarts his route — and we look again every 0.7 s (like the stall's guest).
func _haal_gast() -> void:
	var g := _gast()
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
	_houd_bij_de_tafel()

## The guest of the turn stays beside the table for the whole turn: a waiting
## guest starts to wander after sixteen seconds (world.md §2.6) and would stroll
## in front of the punnets.  Every BLIJF_S he is sent back to his spot when he
## is not there and not busy (a sip after a miss, a happy hop at the end).
func _houd_bij_de_tafel() -> void:
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

## The card for the step the turn is in.  Built once per step: a miss only
## changes its help line, so the answer strip keeps its pause and its four
## choices (S5) — rebuilding it would hand the child a fresh, unlocked strip.
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
	var o := {"id": KAART_ID, "kamer": KAMER, "hoog": KAART_HOOG, "icoon": Beurt.ICOON,
		"max": 3, "dier": _gast_id(), "titel": "de pluktafel"}
	var som := ""
	# One sentence per question: the sum line carries the structure (`7 + ? =
	# 10`), and a card with two sentences over its strip is too tall for the
	# maths bar on a tablet, so it would float over the planter instead of
	# docking (PLAN.md §3.1).  Only groep 3 is told, once, what a full punnet
	# holds — it is the fact the whole turn stands on.
	match stap:
		"tel":
			o["regel"] = Beurt.T_TEL
			if int(O["band"]) <= 3 and int(O["vol"]) > 0:
				o["regel2"] = Beurt.T_TEL2
			o["goed"] = int(O["T"])
			o["liever"] = Beurt.liever_tel(O)
			o["max_getal"] = 100
			o["on_ok"] = _antwoord
		"bij":
			o["regel"] = str(Beurt.vraag_bij(O)[0])
			o["goed"] = int(O["nodig"])
			o["liever"] = Beurt.liever_bij(O)
			o["max_getal"] = 100
			o["on_ok"] = _antwoord
			som = Beurt.som_bij(O)
		"pluk":
			o["regel"] = Beurt.T_PLUK % _nog()
			som = "%d + %d =" % [int(O["T"]), int(S["geplukt"])]
		_:
			o["icoon"] = Beurt.ICOON_AF
			o["regel"] = Beurt.T_AF
			o["regel2"] = Beurt.T_AF2 % _totaal()
			som = "%d + %d =" % [int(O["T"]), int(S["geplukt"])]
	_kaart = ctx.ui.somkaart(TAFEL_ID, som, o)
	if _kaart == null:
		return
	if stap == "pluk":
		_kaart.zet(str(_totaal()))
	elif stap == "af":
		# the tick, and then the total back in the box: "34 + 6 = 40"
		_kaart.klaar()
		_kaart.zet(str(_totaal()))

## Berries on the table right now.
func _totaal() -> int:
	return int(O.get("T", 0)) + int(S.get("geplukt", 0))

## Berries still to pick.
func _nog() -> int:
	return maxi(0, int(O.get("nodig", 0)) - int(S.get("geplukt", 0)))

func _hulp_tekst() -> String:
	return Beurt.hulp_tel(O) if _stap() == "tel" else Beurt.hulp_bij(O)

## One tap on the strip.  Wrong: a soft sound and the next step of the help
## ladder — counting along in a bubble ON THE TABLE, where the punnets are, so
## the card keeps its size and stays in the maths bar (a help line on the card
## made it too tall for the bar and it jumped out, over the planter).  The
## pause and the same four choices are `Ui`'s (S5).  Right: a tick, a happy
## sound, and the next card a moment later.
func _antwoord(n, k) -> void:
	if n == null or S.is_empty() or O.is_empty():
		return
	var stap := _stap()
	var goed := int(O["T"]) if stap == "tel" else int(O["nodig"])
	if stap != "tel" and stap != "bij":
		return
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
	S["stap"] = "bij" if stap == "tel" else "pluk"
	_bewaar()
	_teken()
	if not await na(SOM_S):
		return
	if S.is_empty():
		return
	_kaart_neer()
	_teken()

# ---------------------------------------------------------------- plukken

## One tap on the planter: one berry into the open punnet, or (band 5, once
## that punnet is full) a whole punnet.  The card counts on with it.
func pluk() -> void:
	if S.is_empty() or O.is_empty() or _stap() != "pluk":
		return
	var stap_n := Beurt.pluk_stap(O, int(S["geplukt"]))
	if stap_n <= 0:
		return
	var voor := Beurt.bakjes(O, int(S["geplukt"]))
	S["geplukt"] = int(S["geplukt"]) + stap_n
	var na_b := Beurt.bakjes(O, int(S["geplukt"]))
	ctx.snd.plop(1 if stap_n == 1 else 3)
	for i in 10:
		if int(na_b[i]) != int(voor[i]):
			var p := Modellen.plek(i)
			ctx.wereld.spetter(KAMER, float(TAFEL_X + p.x), float(TAFEL_Z + p.y), 4,
				ArtDecorKas.AARDBEI, true, float(Modellen.TOP + 2))
	if _nog() <= 0:
		_klaar()
		return
	if _kaart != null:
		_kaart.regel(Beurt.T_PLUK % _nog())
		_kaart.som("%d + %d =" % [int(O["T"]), int(S["geplukt"])])
		_kaart.zet(str(_totaal()))
	_bewaar()
	_teken()

## Every punnet full: the tick, the star, the guest has a taste, and a moment
## later the game closes itself.
func _klaar() -> void:
	S["stap"] = "af"
	ctx.state.tel(int(S["missers"]) == 0, Time.get_ticks_msec() - _t0)
	if int(S["ster"]) == 0:
		S["ster"] = 1
		ctx.taak_klaar("oogst", {"sterren": 1})
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

## The table as it stands, as ONE piece of loose decor.  Re-issuing the same id
## replaces the piece: that is how a berry lands in its punnet.
func _zet_tafel() -> void:
	ctx.wereld.decor(KAMER, {"id": TAFEL_ID, "model": "oogst_tafel",
		"x": float(TAFEL_X), "z": float(TAFEL_Z), "params": _tafel_params()})

func _tafel_params() -> Dictionary:
	var spook := -1
	if _stap() == "bij" and int(S["pog"]) >= SPOOK_NA and int(O["band"]) < 5:
		spook = int(O["vol"])
	return {"b": Beurt.bakjes(O, int(S["geplukt"])), "spook": spook}

## Everything on the table and around it, but never the card (see `_kaart_neer`).
func _teken() -> void:
	if not actief or ctx == null or S.is_empty() or O.is_empty():
		return
	_zet_tafel()
	var stap := _stap()
	if stap == "pluk":
		var stap_n := Beurt.pluk_stap(O, int(S["geplukt"]))
		var b := World.mik(BAK, KAMER)
		ctx.hotspots.maak({"id": PLUK_ID, "kamer": KAMER, "obj": BAK, "op": "aan",
			"x": float(b.get("x", BAK_X)), "z": float(b.get("z", BAK_Z)), "y": PLUK_HOOG,
			"icoon": Beurt.ICOON if stap_n <= 1 else Beurt.ICOON_PLUK10,
			"label": Beurt.T_PLUK_KNOP if stap_n <= 1 else Beurt.T_PLUK10_KNOP,
			"titel": Beurt.T_PLUK_TITEL if stap_n <= 1 else Beurt.T_PLUK10_TITEL,
			"prio": 12, "aan": func(_s) -> void: pluk()})
	else:
		ctx.hotspots.weg(PLUK_ID)
	# the help ladder (games-b.md §0.5): after a miss, count along together; at
	# the third miss the answer in pale numbers on the table
	var vraag := stap == "tel" or stap == "bij"
	var hulp := _hulp_tekst() if vraag and int(S["pog"]) >= 1 else ""
	if not hulp.is_empty() and not _klein_kader():
		ctx.ui.wolk({"id": HULP_ID, "kamer": KAMER, "obj": TAFEL_ID, "op": "aan",
			"x": float(TAFEL_X), "z": float(TAFEL_Z), "hoog": HULP_HOOG,
			"icoon": Beurt.ICOON_HULP, "tekst": hulp, "klas": "hulp", "prio": 11})
	else:
		ctx.ui.wolk_weg(HULP_ID)
	var op_kaart := hulp if _klein_kader() else ""
	if _kaart != null and vraag and op_kaart != _kaart_hulp:
		_kaart_hulp = op_kaart
		_kaart.hulp(op_kaart)
	var spook := ""
	if vraag and int(S["pog"]) >= SPOOK_NA:
		if stap == "tel":
			spook = Beurt.spook_tel(O)
		elif int(O["band"]) >= 5:
			spook = Beurt.spook_bij(O)
	if spook.is_empty():
		ctx.ui.getal_tag(TAFEL_ID, null, {"id": SPOOK_ID})
	else:
		ctx.ui.getal_tag(TAFEL_ID, spook, {"id": SPOOK_ID, "kamer": KAMER,
			"y": SPOOK_HOOG, "klas": "hotspook", "prio": 7, "titel": Beurt.T_SPOOK})
	if stap == "af":
		var id := _gast_id()
		if World.dier(id) != null:
			ctx.ui.wolk({"id": LEKKER_ID, "kamer": KAMER, "volg": _volg_dier(id),
				"hoog": LEKKER_HOOG, "icoon": Beurt.ICOON_LEKKER, "tekst": Beurt.T_LEKKER,
				"klas": "goed", "prio": 12})
	ctx.wereld.vuil()
	_meld()

## Where the counting-along goes.  On a tablet or a desktop in a bubble on the
## table: as a help line on the card it made the card too tall for the maths
## bar, and the card jumped out of the bar over the planter.  On a phone the
## frame has no room for a bubble next to the table (it landed 143 units away,
## or on the table itself at 740 × 360), so there it is the card's help line,
## the place games-b.md §0.5 names for it.
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
	print("[probe] oogst stap=", _stap(), " band=", int(O["band"]), " T=", int(O["T"]),
		" nodig=", int(O["nodig"]), " geplukt=", int(S["geplukt"]),
		" missers=", int(S["missers"]), " ster=", int(S["ster"]))
	for id in Hits.debug().keys():
		if not str(id).begins_with("og_"):
			continue
		var spot := Hits.spot(id)
		if spot == null or not is_instance_valid(spot.knoop) or not spot.knoop.visible:
			continue
		print("[probe] oogstknop ", id, "=", spot.knoop.get_global_rect(),
			" dekking=", "%.2f" % Hits.dekking(id))
