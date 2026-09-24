class_name WinkelSpel
extends MiniGame
## De winkels van de Winkelstraat (games-d.md §4) — the shared game of the
## market stalls and the luxury shop.  Each shop is its own game
## (`games/hoeden`, `sjaals`, `schoenen`, `luxe`, and the souvenir stall
## `kraam` that moved in from the garden) that only says WHICH shop it is
## (`winkel()`); the turn lives here.
##
## A turn: the animal of the turn walks up to the counter.  The goods stand on
## the counter, each with its price on it, and the child picks what the animal
## buys (owner, 2026-09-24: "meer aanpassingsmogelijkheden ... zoals kleding").
## Then one to three sums, each a strip of four — the price of four shoes, the
## price with a gift box, half price, the money to pay with, the change
## (`beurt.gd`).  Then the animal wears it, happily, until it checks out, and
## keeps it in its wardrobe: the fitting room lets the child change outfits.
##
## A WRONG ANSWER SENDS THE ANIMAL OUT (owner, 2026-09-24: "Zorg ervoor dat het
## dier teleurgesteld de winkel uit wordt gestuurd en het dier langzaam wegloopt
## als de speler niet het goede aantal geld aanklikt en de speler daarna weer
## terug de winkel in moet klikken om te voorkomen dat de speler probeert snel
## een van de knoppen als resultaat te gokken").  The card goes at once, so
## nothing else can be tapped; the animal sulks with "😞 Dat klopt niet" beside
## it, then walks slowly out of the shop with its head down (`World.stappen`
## pose `sjok`), and once it is out the game closes by itself.  The shop's own
## button is back on the stall: a tap on it starts the game again, the animal
## walks back to the counter, and the SAME question comes back — the turn is in
## the save.  No help and no hint (HOTEL.md §9, owner 2026-09-24: "geef geen
## hulp na fouten"), nothing is taken away: it only costs time, and that is
## what makes guessing a poor plan.

const KAMER := "winkels"
const Beurt := preload("res://games/_winkel/beurt.gd")

const SOM_S := 0.6        ## a right answer, then the next card this much later
const AF_S := 3.4         ## the end card is readable this long before it closes
const LEEG_S := 1.8
const SIP_TIKKEN := 18    ## the sulk at the counter before he walks out (1,2 s)
const SIP_S := 1.2
const WEG_TEMPO := 0.4    ## the slow, sad walk out (`World.stappen` tempo)
const WEG_WACHT := 0.5    ## out of the shop: this long, then the game closes
const WEG_MAX := 12.0     ## never wait longer than this for the walk out
const BLIJF_S := 1.5      ## how often the customer is kept at the counter
const KAART_BOVEN := 22.0 ## the card's aim over the counter top
const TAG_Y := [9.0, 15.0]  ## the price tags, alternately low and high

## The turn.  Lives in `ctx.data()["stand"]`, so it survives a reload and the
## walk out of the shop; every number is read back through `int()`.
var S: Dictionary = {}
## Today's shop (`Beurt.opzet`): a function of shop, N, band and day, so it is
## recomputed at every start and never saved.
var O: Dictionary = {}
var _kaart = null         ## Ui.Kaart
var _kaart_stap := ""
var _t0 := 0

# ------------------------------------------------------------- de winkel

## Which shop this game is.  Override.  Keys:
##   id, naam, icoon, label        the game and its button on the stall
##   decor, x, z                   the stall (or the display counter) it hangs on
##   top                           the height of the counter top, in voxels
##   plekken                       where the goods stand, relative to x, z
##   toon                          how many goods at most (3)
##   klant                         where the customer stands
##   buiten                        where he walks to when he is sent out
##   doos                          (luxe) where the gift box stands
##   wens                          (kraam) the guest wish this shop fulfils
##                                 ("souvenir"): who has it shops first, and
##                                 buying it fulfils the wish
func winkel() -> Dictionary:
	return {}

func _w(sleutel: String, terug = null):
	return winkel().get(sleutel, terug)

func definitie() -> Dictionary:
	var w := winkel()
	# none of these may touch `self`: the registry reads `definitie()` from a
	# throwaway instance and frees it again (architecture.md §6.1)
	var kan := func(s: Dictionary) -> bool:
		for g in s.get("gasten", []):
			if not str(g.get("bed", "")).is_empty():
				return true
		return false
	# At rest the goods stand on the counter too (owner, 2026-09-23: "Dan hangt
	# elk spel aan iets wat je echt ziet"): a stall with nothing on it is not a
	# shop.  The registry puts them down while no game runs.
	var rust: Array = []
	var namen: Array = Beurt.WAREN.get(str(w.get("id", "")), [])
	var plekken: Array = w.get("plekken", [])
	for i in mini(namen.size(), plekken.size()):
		var p: Vector2 = Vector2(float(w.get("x", 0.0)), float(w.get("z", 0.0))) + (plekken[i] as Vector2)
		rust.append({"id": "rust_%s_%d" % [str(w.get("id", "")), i],
			"model": "waar_" + str(namen[i]), "x": p.x, "z": p.y, "y": float(w.get("top", 10.0))})
	var def := {
		"naam": str(w.get("naam", name)),
		"kamer": KAMER,
		"stub": false,
		"rust": rust,
		"hotspot": {"obj": str(w.get("decor", "")), "icoon": str(w.get("icoon", "🛍️")),
			"label": str(w.get("label", "")), "hoog": float(w.get("knop_hoog", 30.0))},
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		"kan": kan,
	}
	if not str(w.get("wens", "")).is_empty():
		def["wens"] = str(w["wens"])
	return def

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
	# the animal the child picked on the game bar shops, if it may (world.md
	# §5.8); another animal's unfinished turn is simply not finished
	var wil := ctx.voorkeur(spelers())
	var hervat := not (S.is_empty() or g.is_empty() or int(S["dag"]) != dag
			or int(S["N"]) != n or int(S["band"]) != band or _stap() == "af")
	var weg := ""
	if hervat and not wil.is_empty() and wil != _gast_id():
		weg = _gast_id()
		hervat = false
	if not hervat:
		var nr: int = Beurt.WINKEL_NR.get(str(_w("id", "")), 0)
		g = kies[(dag + n + nr) % kies.size()] if wil.is_empty() else ctx.state.gast_van(wil)
		S = _nieuwe_stand(g, n, band, dag)
	# back in the shop: the animal that was sent out walks back in
	S["weg"] = 0
	d["stand"] = S
	ctx.speelt(_gast_id())
	O = Beurt.opzet(str(_w("id", "hoeden")), n, band, dag)
	_t0 = Time.get_ticks_msec()
	_kaart = null
	_kaart_stap = ""
	_zet_waren()
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
	O = {}
	_kaart = null
	_kaart_stap = ""

## Who shops: everyone with a bed.  Nobody yet: the game says so and closes.
## A shop that fulfils a wish (`winkel().wens`, the souvenir stall) asks the
## guests who have that wish first — the friendly fallback the garden stall
## had: nobody wishes for it, then everyone with a bed.
func _kandidaten() -> Array:
	var alle := _met_bed()
	var wens := _wens()
	if wens.is_empty():
		return alle
	var met: Array = []
	for g in alle:
		if str(g.get("behoefte", "")) == wens and not bool(g.get("blij", false)):
			met.append(g)
	return met if not met.is_empty() else alle

func _met_bed() -> Array:
	var uit: Array = []
	for g in ctx.state.s["gasten"]:
		if not str(g.get("bed", "")).is_empty():
			uit.append(g)
	return uit

## The wish this shop fulfils, or "".
func _wens() -> String:
	return str(_w("wens", ""))

## Who may shop when the child picks the animal (the game bar, world.md §5.8):
## everyone with a bed, with the wish or without (he then buys without one).
func spelers() -> Array:
	var uit: Array = []
	for g in _met_bed():
		uit.append(str(g.get("id", "")))
	return uit

func _meld_leeg() -> void:
	var plek := {"x": float(_w("x", 60.0)), "z": float(_w("z", 60.0)), "kamer": KAMER}
	ctx.ui.wolk({"id": "wk_leeg", "kamer": KAMER, "x": plek["x"], "z": plek["z"],
		"hoog": float(_w("top", 10.0)) + 8.0, "icoon": "🛏", "tekst": Beurt.T_LEEG, "prio": 12})
	if not await na(LEEG_S):
		return
	ctx.ui.wolk_weg("wk_leeg")
	ctx.sluit()

## `wens` = 1 when this animal came for the shop's wish (`winkel().wens`), so
## that buying fulfils it (the garden stall kept the same field).
func _nieuwe_stand(g: Dictionary, n: int, band: int, dag: int) -> Dictionary:
	var wens := _wens()
	var wil: bool = not wens.is_empty() and str(g.get("behoefte", "")) == wens \
		and not bool(g.get("blij", false))
	return {"gast": str(g.get("id", "")), "dag": dag, "N": n, "band": band,
		"stap": "kies", "waar": "", "plek": 0, "pog": 0, "missers": 0, "weg": 0, "ster": 0,
		"keer": 0, "wens": 1 if wil else 0}

const GETALLEN := ["dag", "N", "band", "pog", "missers", "weg", "ster", "keer", "plek", "wens"]

## A turn that came through the save is JSON: every number a float.  Only the
## fields of a shop turn are kept: a turn of the old garden stall (games-b.md
## §5 — coins on the counter: `gelegd`, `hand`, `zeg`, step `som` or `leg`)
## in the souvenir stall's drawer becomes a fresh choice for the same animal,
## with its wish (`wens`) but without the old stall's misses.
static func _normaliseer(oud: Dictionary) -> Dictionary:
	var st := {}
	for k in GETALLEN:
		st[k] = int(oud.get(k, 0))
	st["gast"] = str(oud.get("gast", ""))
	st["waar"] = str(oud.get("waar", ""))
	var stap := str(oud.get("stap", "kies"))
	st["stap"] = stap if stap in ["kies", "som", "half", "betaal", "terug", "af"] else "kies"
	if not st["stap"] in ["kies", "af"] and not ArtGasten.KLEDING.has(st["waar"]):
		st["stap"] = "kies"
	if st["stap"] == "kies" and stap != "kies":
		# a step this shop cannot resume: a new choice, nothing counted yet
		for k in ["pog", "missers", "weg", "keer", "plek"]:
			st[k] = 0
		st["waar"] = ""
	return st

func _stap() -> String:
	return str(S.get("stap", ""))

func _gast_id() -> String:
	return str(S.get("gast", ""))

func _gast() -> Dictionary:
	if S.is_empty() or ctx == null:
		return {}
	return ctx.state.gast_van(_gast_id())

func _naam() -> String:
	return str(_gast().get("naam", "De gast"))

func _bewaar() -> void:
	if ctx != null and not S.is_empty():
		ctx.data()["stand"] = S
		State.bewaar()

## What the turn asks, for the thing chosen and this animal's kind.
func _sommen() -> Dictionary:
	if O.is_empty() or str(S.get("waar", "")).is_empty():
		return {}
	var kind := str(_gast().get("kind", "hond"))
	return Beurt.sommen(O, str(S["waar"]), kind)

# ------------------------------------------------------------ de klant halen

func _klant() -> Vector2:
	return _w("klant", Vector2(60, 40))

## The customer first, then the card (owner, 2026-09-23: "Zorg dat de minigame
## pas begint wanneer het dier er is").  The goods stand on the counter at once.
func _begin() -> void:
	if not await ctx.wacht_op(_gast_id(), _klant()):
		if actief:
			ctx.sluit.call_deferred()
		return
	if not actief or S.is_empty() or O.is_empty():
		return
	_kaart_neer()
	_teken()
	_houd_bij_de_toonbank()

## The customer stays at the counter for the whole turn (a waiting guest starts
## to wander after a while, world.md §2.6) — unless he was sent out.
func _houd_bij_de_toonbank() -> void:
	var tel := 0
	while actief and not S.is_empty():
		if not await na(BLIJF_S):
			return
		if S.is_empty() or int(S.get("weg", 0)) == 1:
			return
		var d = World.dier(_gast_id())
		if d == null or d.kamer != KAMER or not (d.route as Array).is_empty():
			continue
		if d.staat in ["sip", "blij", "eet", "slaap", "pose"]:
			continue
		tel += 1
		var plek := _klant()
		var doel := plek
		if not (d.punten as Array).is_empty():
			doel = d.punten[(d.punten as Array).size() - 1]
		var thuis: bool = absf(d.x - plek.x) + absf(d.z - plek.y) <= 2.0
		if doel.distance_to(plek) > 2.0 or (not thuis and d.staat != "loop") \
				or (thuis and d.staat == "wacht" and tel % 8 == 0):
			ctx.wereld.ga(_gast_id(), plek.x, plek.y, "wacht")

# ------------------------------------------------------------------ de waren

## What is on the counter today: everything the shop has, except what this
## animal already owns — unless it owns it all, then everything again — and at
## most `toon` things (the luxury shop has four, and its display counter shows
## three a day: on a phone four price tags side by side found no place).
## While choosing it is this list; once a thing is chosen, only that thing, on
## the spot where it stood (`S.plek`).
func _te_koop() -> Array:
	var eigen: Array = ctx.state.kast_van(_gast_id()) if ctx != null else []
	var uit: Array = []
	for w in O.get("waren", []):
		if not eigen.has(str(w["naam"])):
			uit.append(w)
	if uit.is_empty():
		uit = (O.get("waren", []) as Array).duplicate()
	var toon := int(_w("toon", 3))
	if uit.size() > toon:
		var weg := (int(O.get("dag", 1)) + int(O.get("N", 1))) % uit.size()
		uit.remove_at(weg)
		uit = uit.slice(0, toon)
	return uit

## The goods on show now, each with the spot it stands on: [[good, spot], ...].
func _uitstal() -> Array:
	var uit: Array = []
	if _stap() == "kies":
		var lijst := _te_koop()
		for i in lijst.size():
			uit.append([lijst[i], i])
		return uit
	var w := Beurt.waar_van(O, str(S.get("waar", "")))
	if not w.is_empty():
		uit.append([w, int(S.get("plek", 0))])
	return uit

## Where good `i` stands on the counter.
func _plek(i: int) -> Vector2:
	var plekken: Array = _w("plekken", [])
	var basis := Vector2(float(_w("x", 0.0)), float(_w("z", 0.0)))
	if i < 0 or i >= plekken.size():
		return basis
	return basis + (plekken[i] as Vector2)

## The goods on the counter, as loose decor.  While choosing, all of them; once
## a thing is chosen, only that one — the child sees what the sum is about.
func _zet_waren() -> void:
	World.decor_wis_eigenaar(ctx.id)
	var top := float(_w("top", 10.0))
	for paar in _uitstal():
		var naam := str(paar[0]["naam"])
		var i := int(paar[1])
		var p := _plek(i)
		ctx.wereld.decor(KAMER, {"id": "wk_w%d" % i, "model": "waar_" + naam,
			"x": p.x, "z": p.y, "hoog": top})
	if _stap() in ["som", "betaal", "terug"] and int(O.get("doosje", 0)) > 0:
		var dp: Vector2 = _w("doos", Vector2(20, 40))
		ctx.wereld.decor(KAMER, {"id": "wk_doos", "model": "cadeaudoos", "x": dp.x, "z": dp.y})
	ctx.wereld.vuil()

## The price tags: every good carries its price as a number ON the thing
## (HOTEL.md §9).  Not buttons — the strip under the card is where you choose.
func _teken_prijzen() -> void:
	var top := float(_w("top", 10.0))
	var getoond := {}
	if _stap() != "af":
		for paar in _uitstal():
			var naam := str(paar[0]["naam"])
			var prijs := int(paar[0]["prijs"])
			var i := int(paar[1])
			getoond[i] = true
			var p := _plek(i)
			var w: Dictionary = ArtGasten.KLEDING.get(naam, {})
			ctx.ui.getal_tag({"x": p.x, "z": p.y, "kamer": KAMER}, Beurt.euro(prijs),
				{"id": "wk_p%d" % i, "y": top + float(TAG_Y[i % 2]), "prio": 8,
					"titel": "%s %s kost %d euro" % [str(w.get("lid", "de")),
						str(w.get("naam", naam)), prijs]})
	for i in 4:
		if not getoond.has(i):
			ctx.hotspots.weg("wk_p%d" % i)
	if _stap() in ["som", "betaal", "terug"] and int(O.get("doosje", 0)) > 0:
		var dp: Vector2 = _w("doos", Vector2(20, 40))
		ctx.ui.getal_tag({"x": dp.x, "z": dp.y, "kamer": KAMER}, Beurt.euro(int(O["doosje"])),
			{"id": "wk_pdoos", "y": 8.0, "prio": 8,
				"titel": "het doosje kost %d euro" % int(O["doosje"])})
	else:
		ctx.hotspots.weg("wk_pdoos")

func _teken() -> void:
	if not actief or ctx == null or S.is_empty() or O.is_empty():
		return
	_teken_prijzen()
	ctx.wereld.vuil()
	_meld()

# ------------------------------------------------------------------ de kaart

## The card for the step the turn is in, built once per step.
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
	var s := _sommen()
	var zin: Array = Beurt.kaart(stap, O, str(S.get("waar", "")), s, _naam())
	var o := {"id": "wk_kaart", "kamer": KAMER, "hoog": float(_w("top", 10.0)) + KAART_BOVEN,
		"icoon": str(_w("icoon", "🛍️")), "regel": str(zin[0]), "max": 3,
		"dier": _gast_id(), "titel": str(_w("naam", ""))}
	match stap:
		"kies":
			o["keuzes"] = _kies_keuzes()
			o["keuze_titel"] = "kies wat %s koopt" % _naam()
		"betaal":
			o["icoon"] = Beurt.ICOON_GELD
			o["keuzes"] = _geld_keuzes(s)
			o["keuze_titel"] = "kies het geld"
		"som", "half", "terug":
			o["keuzes"] = _getal_keuzes(stap, s)
		_:
			o["icoon"] = Beurt.ICOON_AF
	var plek := {"x": float(_w("x", 60.0)), "z": float(_w("z", 60.0)), "kamer": KAMER}
	_kaart = ctx.ui.somkaart(plek, str(zin[1]), o)
	if _kaart != null and stap == "af":
		_kaart.klaar()

## The choice: one button per good for sale, its picture, its name and price.
func _kies_keuzes() -> Array:
	var uit: Array = []
	for w in _te_koop():
		var naam := str(w["naam"])
		var kl: Dictionary = ArtGasten.KLEDING.get(naam, {})
		var p := int(w["prijs"])
		uit.append({"id": "w_" + naam, "icoon": str(kl.get("icoon", "🛍️")),
			"tekst": "%s %s" % [Beurt.hoofd(str(kl.get("naam", naam)).split(" ")[-1]), Beurt.euro(p)],
			"kort": Beurt.euro(p), "titel": "%s %s, %d euro" % [str(kl.get("lid", "de")),
				str(kl.get("naam", naam)), p],
			"kies": func(_id, _k) -> void: _kies_waar(naam)})
		if uit.size() >= Ui.MAX_KEUZES:
			break
	return uit

## Four numbers, one of them right (`Afleiders.vier`); the same four in the same
## order every time this question comes back.
func _getal_keuzes(stap: String, s: Dictionary) -> Array:
	var goed := Beurt.goed(stap, s)
	var zaad := int(O.get("zaad", 0)) + ["som", "half", "terug"].find(stap) * 211
	var getallen := Afleiders.vier(goed, zaad,
		{"min": 0, "max": 199, "liever": Beurt.liever(stap, s, O)})
	var uit: Array = []
	for g in getallen:
		var n: int = g
		uit.append({"id": "n%d" % n, "icoon": "", "tekst": Beurt.euro(n), "kort": str(n),
			"titel": "%d euro" % n,
			"kies": func(_id, k) -> void: _antwoord(n, k)})
	return uit

## Four handfuls of money, exactly one of them the right amount.
func _geld_keuzes(s: Dictionary) -> Array:
	var uit: Array = []
	var stapels := Beurt.betaal_keuzes(int(s["totaal"]), int(O["band"]), int(O.get("zaad", 0)))
	for i in stapels.size():
		var st: Array = stapels[i]
		var som := Beurt.tel(st)
		uit.append({"id": "g%d" % som, "icoon": Beurt.ICOON_GELD,
			"tekst": Beurt.stapel_tekst(st), "kort": Beurt.stapel_kort(st),
			"titel": "betaal %s" % Beurt.stapel_tekst(st),
			"kies": func(_id, k) -> void: _antwoord(som, k)})
	return uit

# ---------------------------------------------------------------- de beurt

## The child chose what the animal buys.  Not a sum: nothing is right or wrong.
func kies_waar(naam: String) -> void:
	_kies_waar(naam)

func _kies_waar(naam: String) -> void:
	if S.is_empty() or _stap() != "kies" or Beurt.waar_van(O, naam).is_empty():
		return
	S["waar"] = naam
	# the spot it stood on while choosing: it stays there for the sums
	for paar in _uitstal():
		if str(paar[0]["naam"]) == naam:
			S["plek"] = int(paar[1])
	S["stap"] = Beurt.volgende(str(_w("id", "")), int(O["band"]), "kies")
	ctx.snd.tik()
	var id := _gast_id()
	if World.dier(id) != null:
		World.pose(id, "blijA", 6)
	_bewaar()
	_zet_waren()
	_kaart_neer()
	_teken()

## One tap on a number or on a handful of money.
func antwoord(n: int) -> void:
	_antwoord(n, _kaart)

func _antwoord(n: int, k) -> void:
	if S.is_empty() or O.is_empty() or int(S.get("weg", 0)) == 1:
		return
	var stap := _stap()
	if not stap in ["som", "half", "betaal", "terug"]:
		return
	var goed := Beurt.goed(stap, _sommen())
	if n != goed:
		_weggestuurd()
		return
	if k != null:
		k.zet(Beurt.euro(n))
		k.klaar()
	if stap == "betaal":
		ctx.snd.munt()
	else:
		ctx.snd.ja()
	S["stap"] = Beurt.volgende(str(_w("id", "")), int(O["band"]), stap)
	_bewaar()
	if _stap() == "af":
		_klaar()
		return
	_zet_waren()
	_teken()
	if not await na(SOM_S):
		return
	if S.is_empty() or _stap() == "af":
		return
	_kaart_neer()
	_teken()

## Paid and done: the animal wears it, keeps it, and is happy.
func _klaar() -> void:
	var id := _gast_id()
	var naam := str(S.get("waar", ""))
	S["stap"] = "af"
	ctx.state.tel(int(S["missers"]) == 0, Time.get_ticks_msec() - _t0)
	if World.dier(id) != null:
		ctx.state.in_kast(id, naam)
		ctx.wereld.accessoire(id, naam)
	if int(S["ster"]) == 0:
		S["ster"] = 1
		ctx.taak_klaar(str(_w("id", "")), {"sterren": 1})
	# first the task (that is also the star), THEN the wish: `wens_af` redraws
	# the notice board straight away
	if int(S.get("wens", 0)) == 1 and not _wens().is_empty() and not _gast().is_empty():
		S["wens"] = 0
		ctx.wereld.behoefte_klaar(id, _wens())
	ctx.snd.tover()
	ctx.snd.hoera()
	_bewaar()
	_zet_waren()
	_kaart_neer()
	_teken()
	if World.dier(id) != null:
		ctx.wereld.set_mood(id, "bouncy")
		var d = World.dier(id)
		ctx.wereld.spetter(KAMER, d.x, d.z, ArtEffect.STER_N * 3, ArtEffect.STER_KL[0], true, 14.0)
		ctx.ui.wolk({"id": "wk_blij", "kamer": KAMER, "volg": _volg_dier(id), "hoog": 46.0,
			"icoon": str((ArtGasten.KLEDING.get(naam, {}) as Dictionary).get("icoon", "✨")),
			"tekst": Beurt.T_BLIJ, "klas": "goed", "prio": 12})
	if not await na(AF_S):
		return
	if S.is_empty() or _stap() != "af":
		return
	ctx.sluit()

## A wrong answer: out of the shop, slowly (see the header).  The step stays
## where it was, so the same question waits for him when he comes back.
func _weggestuurd() -> void:
	S["weg"] = 1
	S["pog"] = int(S["pog"]) + 1
	S["missers"] = int(S["missers"]) + 1
	S["keer"] = int(S.get("keer", 0)) + 1
	_bewaar()
	ctx.snd.zacht()
	# nothing is left to tap: the card and its strip go at once
	if _kaart != null:
		_kaart.weg()
		_kaart = null
	_kaart_stap = ""
	var id := _gast_id()
	if World.dier(id) == null:
		ctx.sluit.call_deferred()
		return
	World.pose(id, "sip", SIP_TIKKEN)
	# its own sad little "aww", in the place of the `zacht()` above (Snd §de dieren)
	ctx.snd.dier_sip(id)
	ctx.ui.wolk({"id": "wk_weg", "kamer": KAMER, "volg": _volg_dier(id), "hoog": 46.0,
		"icoon": Beurt.ICOON_WEG, "tekst": Beurt.T_WEG, "prio": 12})
	_meld()
	if not await na(SIP_S):
		return
	var buiten: Vector2 = _w("buiten", Vector2(66, 80))
	var t0 := Time.get_ticks_msec()
	_loop_weg(id, buiten)
	# wait until he is out (or until the walk was taken over by something else)
	while actief:
		if not await na(0.2):
			return
		var d = World.dier(id)
		if d == null:
			break
		var er: bool = (d.punten as Array).is_empty() and Vector2(d.x, d.z).distance_to(buiten) <= 3.0
		if er or d.staat != "loop" or (Time.get_ticks_msec() - t0) / 1000.0 > WEG_MAX:
			break
	if not await na(WEG_WACHT):
		return
	ctx.sluit()

## The walk out: slow, head down, and a sulk when he gets there.  A world order,
## so it goes on when the game closes on the way.
func _loop_weg(id: String, naar: Vector2) -> void:
	await World.stappen(id, [naar], {"pose": "sjok", "tempo": WEG_TEMPO, "na": "sip"})

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
	var s := _sommen()
	print("[probe] winkel ", str(_w("id", "")), " stap=", _stap(), " band=", int(O["band"]),
		" waar=", str(S.get("waar", "")), " goed=", Beurt.goed(_stap(), s) if not s.is_empty() else -1,
		" weg=", int(S.get("weg", 0)), " missers=", int(S["missers"]), " ster=", int(S["ster"]))
	# every button of the game as `<id>=<rect>` (tools/speel.js taps them), and
	# the order of the choices on the strip, left to right
	for id in Hits.debug().keys():
		if not str(id).begins_with("wk_"):
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
			print("[probe] winkel keuzes=", ",".join(namen))
