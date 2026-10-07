extends MiniGame
## post — "De post sorteren", in de postkamer achter de lobby (U4, 2026-10-07;
## eigenaar: "Verzin nog vier kamers met activiteiten").
##
## Op de postkar ligt de post van vandaag: één brief per gast (2..6).  Langs de
## achterwand staat de vakkenkast met vier vakjes; boven elk vakje hangt zijn
## bordje met de getallen die erin horen ("30 - 39").  De kast is een
## GETALLENLIJN in vier stukken.  Een beurt:
##   1. De postbode van de beurt (een gast met een bed, of het dier dat het
##      kind op de spelbalk koos) loopt naar de kar.  Zonder gasten met een bed
##      sorteert het kind de post alleen.
##   2. Op de bovenste brief staat zijn adres ("💌 34", groep 5 "💌 7 × 8"),
##      de kaart vraagt "💌 In welk vakje hoort deze brief?" met het adres op
##      de somregel, en de strook heeft precies vier knoppen: de vier vakjes,
##      in de volgorde van de kast, met dezelfde getallen als hun bordjes.
##   3. Goed: de brief gaat door de brievenbus (`Snd.brief`) en ligt in zijn
##      vakje, de stapel op de kar wordt lager, de volgende brief.  Fout: de
##      postbode is teleurgesteld (`Ui.misser`: `sip`, 🔄 Nog een keer, de
##      strook even op slot) en dezelfde brief blijft — geen hulp (eigenaar,
##      2026-09-24: "Nee geef geen hulp na fouten").
##   4. De kar is leeg: ✅ "Alle post is gesorteerd!", één ster voor het
##      meedoen, het adaptieve signaal (geen misser = goed), en het spel sluit.
##
## WHY a strip and not a tap on the hole itself (U4 brief, item 1): the strip
## is the design contract every game of the hotel keeps (AGENTS.md §1.4 —
## "answers are one tap on a strip of at most four choices"), so a six-year-old
## who played one game knows where to tap here; it docks with its card in the
## maths bar on every screen and carries the miss pause of `Ui.misser` for
## free.  Four buttons on four holes 16 voxels apart would be squeezed by the
## band grid on a phone, as the laundry's crates needed a solver of their own
## (`WasIndeling`).  The world still does the explaining: the strip's buttons
## stand in the order of the holes and carry the words of their plates, and
## a right letter lands visibly IN its hole.
##
## De getallen komen uit `beurt.gd` (`core/sommen.gd` blijft bevroren); de
## kast, de kar en de balie zijn de modellen van `art/decor_post.gd`.  Ze
## staan ook als rustspul in de kamer als er niet gespeeld wordt
## (`definitie().rust`), zodat de ingang aan iets hangt wat je echt ziet.

const KAMER := "postkamer"
const Beurt := preload("res://games/post/beurt.gd")
const Modellen := preload("res://art/decor_post.gd")

const TAAK := "post"
const KAART_ID := "po_som"
const STROOK_ID := "po_som_keuzes"
const KAST_ID := "po_kast"
const KAR_ID := "po_kar"
const BALIE_ID := "po_balie"
const ADRES_ID := "po_adres"
const VAK_TAG := "po_vak%d"
const RUST_KAST := "rust_po_kast"
const RUST_KAR := "rust_po_kar"
const RUST_BALIE := "rust_po_balie"

## Where things stand in the postkamer (96 × 88, `autoload/rooms.gd`): the
## shelf against the back wall z = 0, the counter against the wall x = 0, the
## cart in the middle, and the postbode beside the cart's handle on the door
## side — never in front of the cart or the shelf (the first play in the
## export had him at the cart's right corner, over the cart, with the plant
## under him), drawn after the cart (x + z 86 > 84), and a few steps from the
## door, so his walk in passes nothing (a walk goes round fixed decor only,
## `World.looppad`).  `mijd` in rooms.gd keeps the floor under all three free.
const KAST_X := 48
const KAST_Z := 1
const BALIE_X := 1
const BALIE_Z := 34
const KAR_X := 40
const KAR_Z := 44
const GAST_X := 22.0
const GAST_Z := 64.0
## The resting cart: the morning's pile waits for somebody to sort it.
const RUST_BRIEVEN := 4

const KAART_HOOG := 24.0     ## the card's aim over the cart (when it floats)
const ADRES_HOOG := 18.0     ## the address hangs just over the pile
const PLAAT_HOOG := float(Modellen.HOOG)

const SOM_S := 0.6           ## a letter in its hole, then the next one this much later
const AF_S := 3.4            ## the end card is readable this long before it closes
const BLIJF_S := 1.5         ## how often the postbode is kept at the cart

## The turn.  Lives in `ctx.data()["stand"]`; every number is read back through
## `int()`, because JSON hands them back as floats.
var S: Dictionary = {}
## The pile of this turn — purely a function of N, band, day and round
## (`Beurt.maak`), so it is recomputed at every start and never saved.
var O: Dictionary = {}
var _kaart = null            ## Ui.Kaart
var _kaart_sleutel := ""     ## the step and letter the card on screen was built for
var _t0 := 0
var _bezig := false          ## a letter is on its way into its hole

# ------------------------------------------------------------- aanmelding

func definitie() -> Dictionary:
	# None of these may touch `self`: the registry reads `definitie()` from a
	# throwaway instance and frees it again (architecture.md §6.1).
	return {
		"naam": "De post sorteren",
		"kamer": KAMER,
		"stub": false,
		# The entry hangs ON the resting cart (`hotspot.rust`); the cart only
		# goes while a game runs, and then no entry of this room is wanted.
		"hotspot": {"obj": RUST_KAR, "icoon": Beurt.ICOON, "label": Beurt.T_KNOP,
			"hoog": 16, "rust": RUST_KAR},
		"modellen": Modellen.spel_tabel(),
		"rust": rust(),
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		"taak": {"id": TAAK, "icoon": Beurt.ICOON, "tekst": Beurt.T_TAAK,
			"kamer": KAMER, "prio": 6},
	}

## The shelf (empty holes), the counter with its scale and the cart with the
## morning's pile, standing in the postkamer while nobody sorts (world.md §5.1).
static func rust() -> Array:
	return [
		{"id": RUST_KAST, "model": "post_kast", "x": float(KAST_X), "z": float(KAST_Z),
			"params": {"vol": [0, 0, 0, 0]}},
		{"id": RUST_BALIE, "model": "post_balie", "x": float(BALIE_X), "z": float(BALIE_Z),
			"params": {}},
		{"id": RUST_KAR, "model": "post_kar", "x": float(KAR_X), "z": float(KAR_Z),
			"params": {"brieven": RUST_BRIEVEN}},
	]

# ------------------------------------------------------------ start / stop

func start(_c: SpelCtx) -> void:
	for naam in Modellen.spel_tabel():
		if not Art.heeft_model(naam):
			Art.registreer_model(naam, Modellen.spel_tabel()[naam])
	var d := ctx.data()
	var n: int = ctx.state.n_gasten()
	var band: int = ctx.state.band()
	var dag := int(ctx.state.s["dag"])
	var oud = d.get("stand", null)
	S = _normaliseer((oud as Dictionary).duplicate(true)) if typeof(oud) == TYPE_DICTIONARY else {}
	var kies := spelers()
	# The animal the child picked on the game bar carries the post, if he may
	# (world.md §5.8); a turn of another animal is simply not finished.
	var wil := ctx.voorkeur(kies)
	# Resume only when the saved turn is still THIS turn: the same day, the
	# same hotel size and band, not finished — and the turn of the picked
	# animal: another one's is dropped (`weg`).
	var hervat := not (S.is_empty() or int(S["dag"]) != dag or int(S["N"]) != n
			or int(S["band"]) != band or _stap() == "af")
	var weg := ""
	if hervat and not wil.is_empty() and wil != _gast_id():
		weg = _gast_id()
		hervat = false
	if not hervat:
		# a finished pile is followed by a fresh one on the same day
		var ronde := 0
		if not S.is_empty() and int(S["dag"]) == dag:
			ronde = int(S["ronde"]) + (1 if _stap() == "af" else 0)
		S = _nieuwe_stand(_kies_postbode(kies, wil, n, dag), n, band, dag, ronde)
	elif not _gast_id().is_empty() and not kies.has(_gast_id()):
		# the postbode of the saved turn left the hotel: the post stays, somebody
		# else carries on with it (or nobody, and the child sorts alone)
		S["gast"] = _kies_postbode(kies, wil, n, dag)
	d["stand"] = S
	ctx.speelt(_gast_id())
	O = Beurt.maak(band, n, dag, int(S["ronde"]))
	S["i"] = clampi(int(S["i"]), 0, (O["brieven"] as Array).size())
	_t0 = Time.get_ticks_msec()
	_kaart = null
	_kaart_sleutel = ""
	_bezig = false
	# the shelf with its numbered holes and the cart with its pile stand there
	# at once; the question waits for the postbode (`_begin`)
	_zet_decor()
	_zet_platen()
	State.bewaar()
	print("[probe] spel=start id=", ctx.id, " kamer=", ctx.kamer, " brieven=",
		(O["brieven"] as Array).size(), " i=", int(S["i"]), " gast=", _gast_id())
	_begin()
	# the one whose turn was dropped makes room at the cart — after the new
	# postbode was sent, so he walks off to a place the new one is not heading for
	if not weg.is_empty() and weg != _gast_id():
		ctx.laat_gaan(weg)

func stop() -> void:
	if ctx != null:
		if not S.is_empty():
			ctx.data()["stand"] = S
			State.bewaar()
		World.decor_wis_eigenaar(ctx.id)
		print("[probe] spel=stop post i=", int(S.get("i", 0)))
	S = {}
	O = {}
	_kaart = null
	_kaart_sleutel = ""
	_bezig = false

## Who may carry the post when the child chooses the animal himself (the game
## bar, world.md §5.8): everyone with a bed, in check-in order.
func spelers() -> Array:
	var uit: Array = []
	if ctx == null:
		return uit
	for g in ctx.state.s["gasten"]:
		if not str(g.get("bed", "")).is_empty():
			uit.append(str(g.get("id", "")))
	return uit

## The postbode: the picked animal, else one that moves on with the day.
static func _kies_postbode(kies: Array, wil: String, n: int, dag: int) -> String:
	if not wil.is_empty():
		return wil
	if kies.is_empty():
		return ""
	return str(kies[posmod(dag + n, kies.size())])

func _nieuwe_stand(gast: String, n: int, band: int, dag: int, ronde: int) -> Dictionary:
	return {"gast": gast, "dag": dag, "N": n, "band": band, "ronde": ronde,
		"stap": "sorteer", "i": 0, "pog": 0, "missers": 0, "ster": 0}

## A turn that came through the save is JSON: every number a float.
static func _normaliseer(st: Dictionary) -> Dictionary:
	for k in ["dag", "N", "band", "ronde", "i", "pog", "missers", "ster"]:
		st[k] = int(st.get(k, 0))
	st["gast"] = str(st.get("gast", ""))
	var stap := str(st.get("stap", "sorteer"))
	st["stap"] = stap if stap in ["sorteer", "af"] else "sorteer"
	return st

func _stap() -> String:
	return str(S.get("stap", ""))

func _gast_id() -> String:
	return str(S.get("gast", ""))

## The letter on top of the pile, {} when the pile is empty.
func _brief() -> Dictionary:
	var brieven: Array = O.get("brieven", [])
	var i := int(S.get("i", 0))
	return brieven[i] if i >= 0 and i < brieven.size() else {}

func _bewaar() -> void:
	if ctx != null and not S.is_empty():
		ctx.data()["stand"] = S
		State.bewaar()

# --------------------------------------------------------- de postbode halen

## The postbode first, then the first letter (owner, 2026-09-23: "Zorg dat de
## minigame pas begint wanneer het dier er is").  The shelf and the cart stand
## there at once; the card comes the moment the postbode stands at the cart —
## after a walk down the stairs and through the lobby, with the hotel's "komt
## eraan" bubble and its `👀 Volg` while he is on his way.  Without an animal
## (nobody has a bed yet, or he left the hotel on the way) the child sorts the
## post alone: a miss then shows its bubble at the card (`Ui.misser`).
func _begin() -> void:
	var gast := _gast_id()
	if not gast.is_empty():
		if not await ctx.wacht_op(gast, Vector2(GAST_X, GAST_Z)):
			if not actief or S.is_empty():
				return
			S["gast"] = ""
			ctx.speelt("")
			_bewaar()
		if not actief or S.is_empty() or O.is_empty():
			return
	# a pile that ran out without its end (cannot happen through `_kies`, which
	# finishes in the same step it takes the last letter) is finished now
	if _stap() == "sorteer" and _brief().is_empty():
		_klaar()
		return
	_kaart_neer()
	_teken()
	if not _gast_id().is_empty():
		_houd_bij_de_kar()

## The postbode stays at the cart for the whole turn: a waiting guest starts to
## wander after sixteen seconds (world.md §2.6).  Every BLIJF_S he is sent back
## to his spot when he is not there and not busy (a sulk after a miss, a happy
## hop at the end).  The shape of oogst's `_houd_bij_de_tafel`.
func _houd_bij_de_kar() -> void:
	var tel := 0
	while actief and not S.is_empty():
		if not await na(BLIJF_S):
			return
		if S.is_empty() or _gast_id().is_empty():
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

## The card for the letter on top of the pile, built once per letter: a miss
## changes nothing on it, so the strip keeps its pause and its four choices
## (S5) — rebuilding it would hand the child a fresh, unlocked strip.
func _kaart_neer() -> void:
	if not actief or S.is_empty() or O.is_empty():
		return
	var stap := _stap()
	var sleutel := "%s|%d" % [stap, int(S["i"])]
	if _kaart != null and _kaart_sleutel == sleutel:
		return
	if _kaart != null:
		_kaart.weg()
		_kaart = null
	_kaart_sleutel = sleutel
	# The card's own thing is the cart AND the shelf: a card that floats (the
	# landscape phone, where the maths bar does not fit) and its strip keep off
	# both, so the holes the question is about stay in view — the first play
	# had the strip lying over the whole shelf there.
	var o := {"id": KAART_ID, "kamer": KAMER, "hoog": KAART_HOOG, "icoon": Beurt.ICOON,
		"dier": _gast_id(), "titel": Beurt.T_TITEL, "volg": _volg_kaart()}
	var som := ""
	if stap == "af":
		o["icoon"] = Beurt.ICOON_AF
		o["regel"] = Beurt.T_AF
	else:
		var br := _brief()
		if br.is_empty():
			return
		o["regel"] = Beurt.T_VRAAG
		o["keuze_titel"] = Beurt.T_KEUZE_TITEL
		o["keuzes"] = _vak_keuzes()
		# a maths question without a number answer: the room bar and the door
		# signs wait for it like for any sum (`Ui.is_som`)
		o["reken"] = true
		som = str(br["tekst"])
	_kaart = ctx.ui.somkaart(KAR_ID, som, o)
	if _kaart != null and stap == "af":
		_kaart.klaar()
	_meld("kaart")

## Where the card aims (over the cart) and what it must not cover: the cart and
## the shelf as one rectangle, measured every frame from their drawn plates.
func _volg_kaart() -> Callable:
	return func() -> Dictionary:
		var uit := {"x": float(KAR_X), "z": float(KAR_Z), "kamer": KAMER}
		var vlak := Rect2()
		for id in [KAR_ID, KAST_ID]:
			var stuk := World.decor_plek(id, KAMER)
			if stuk.is_empty():
				continue
			var v := World.vlak_van(str(stuk["model"]), float(stuk["x"]), float(stuk["z"]),
				float(stuk.get("hoog", 0.0)), stuk.get("params", {}))
			if v.size.x <= 0.0 or v.size.y <= 0.0:
				continue
			vlak = v if vlak.size.x <= 0.0 else vlak.merge(v)
		if vlak.size.x > 0.0:
			uit["vlak"] = vlak
		return uit

## The four holes as the strip: in the order of the shelf, with the words of
## their plates and the post's pictogram (HOTEL.md §9: pictogram AND word).
func _vak_keuzes() -> Array:
	var uit: Array = []
	var vakken: Array = O.get("vakjes", [])
	for j in vakken.size():
		var vk: Dictionary = vakken[j]
		# the pictogram is part of the words, so the short form can put it
		# OVER the numbers instead of beside them (`Beurt.knop_kort`)
		uit.append({"id": "vak%d" % j, "icoon": "", "tekst": Beurt.knop(vk),
			"kort": Beurt.knop_kort(vk), "titel": Beurt.plaat(vk), "kies": _kies_knop(j)})
	return uit

## The strip calls a choice with its id and the card (`Ui.roep`); the hole it
## stands for is fixed when the button is made.
func _kies_knop(j: int) -> Callable:
	return func(_id = "", _k = null) -> void: _kies(j)

## One tap on a hole.  Wrong: the postbode is disappointed and the same letter
## stays — nothing moves, nothing helps, nothing is lost.  Right: the letter
## goes through the letterbox into its hole, the pile on the cart gets lower,
## and the next letter comes a moment later.
func _kies(j: int) -> void:
	if S.is_empty() or O.is_empty() or _stap() != "sorteer" or _bezig:
		return
	var br := _brief()
	if br.is_empty():
		return
	if j != int(br["vak"]):
		S["pog"] = int(S["pog"]) + 1
		S["missers"] = int(S["missers"]) + 1
		ctx.ui.misser(_kaart, _gast_id())
		_bewaar()
		print("[probe] post mis brief=", br["tekst"], " vak=", j, " goed=", int(br["vak"]))
		_meld("mis")
		return
	_bezig = true
	S["pog"] = 0
	S["i"] = int(S["i"]) + 1
	ctx.snd.brief()
	ctx.snd.ja()
	if _kaart != null:
		_kaart.klaar()
	var p := vak_plek(j)
	ctx.wereld.spetter(KAMER, p.x, p.y - 2.0, 5, Modellen.ENVELOP, true,
		float(Modellen.VOET + 8))
	_bewaar()
	_teken()
	print("[probe] post goed brief=", br["tekst"], " vak=", j, " over=", _over())
	if int(S["i"]) >= (O["brieven"] as Array).size():
		_klaar()
		return
	if not await na(SOM_S):
		return
	_bezig = false
	if S.is_empty() or _stap() != "sorteer":
		return
	_kaart_neer()
	_teken()

## The cart is empty: the tick, the star, the postbode is delighted, and a
## moment later the game closes itself.
func _klaar() -> void:
	S["stap"] = "af"
	_bezig = false
	ctx.state.tel(int(S["missers"]) == 0, Time.get_ticks_msec() - _t0)
	if int(S["ster"]) == 0:
		S["ster"] = 1
		ctx.taak_klaar(TAAK, {"sterren": 1})
	ctx.snd.hoera()
	_bewaar()
	_kaart_neer()
	_teken()
	for j in Beurt.VAKJES:
		var p := vak_plek(j)
		ctx.wereld.spetter(KAMER, p.x, p.y - 2.0, 4, Color("#FFD23F"), true, PLAAT_HOOG)
	var id := _gast_id()
	if not id.is_empty() and World.dier(id) != null:
		ctx.wereld.set_mood(id, "bouncy")
	print("[probe] spel=klaar post missers=", int(S["missers"]), " sterren=", State.s["sterren"])
	if not await na(AF_S):
		return
	if S.is_empty() or _stap() != "af":
		return
	ctx.sluit()

# ------------------------------------------------------------------ tekenen

## Letters still on the cart.
func _over() -> int:
	return maxi(0, (O.get("brieven", []) as Array).size() - int(S.get("i", 0)))

## Where hole `j` opens, in the room's voxels (the middle of its front).
static func vak_plek(j: int) -> Vector2:
	var m := Modellen.vak_midden(j)
	return Vector2(float(KAST_X) + m.x, float(KAST_Z) + m.y)

## The shelf with the letters sorted so far, the counter, and the cart with what
## is left.  Re-issuing an id replaces the piece: that is how a letter moves.
func _zet_decor() -> void:
	var brieven: Array = O.get("brieven", [])
	var klaar := int(S.get("i", 0))
	ctx.wereld.decor(KAMER, {"id": KAST_ID, "model": "post_kast",
		"x": float(KAST_X), "z": float(KAST_Z), "params": {"vol": Beurt.vol(brieven, klaar)}})
	ctx.wereld.decor(KAMER, {"id": BALIE_ID, "model": "post_balie",
		"x": float(BALIE_X), "z": float(BALIE_Z), "params": {}})
	ctx.wereld.decor(KAMER, {"id": KAR_ID, "model": "post_kar",
		"x": float(KAR_X), "z": float(KAR_Z), "params": {"brieven": _over()}})

## Every hole's plate, as a number on the board over it (world.md §5.6): they
## stay the whole turn, and the strip under the card says the same words.  A
## plate's own thing is its hole's opening — `volg` hands Hits that rectangle
## every frame — so the plate stands on the board right over its hole.  On a
## frame where four plates cannot stand side by side over their holes (a
## phone: the whole shelf is 140 units wide there) they stay off the glass,
## because the band grid would only push them over each other's holes; then
## the strip, whose buttons stand in the order of the holes, carries the
## numbers alone.  Asked again in every placement pass, so a camera that is
## still sliding in, or the maths bar docking, decides nothing for good.
func _zet_platen() -> void:
	var vakken: Array = O.get("vakjes", [])
	for j in vakken.size():
		var plaat := Beurt.plaat(vakken[j])
		var p := vak_plek(j)
		ctx.ui.getal_tag({"x": p.x, "z": p.y}, plaat, {"id": VAK_TAG % j, "kamer": KAMER,
			"y": float(Modellen.BORD), "prio": 6, "titel": "vakje " + plaat,
			"volg": _volg_vak(j)})

## Where plate `j` hangs this frame: over hole `j`, with the hole's opening as
## its thing — or nowhere (`kamer` ""), when the four do not fit.
func _volg_vak(j: int) -> Callable:
	var p := vak_plek(j)
	return func() -> Dictionary:
		if not platen_nu():
			return {"x": p.x, "z": p.y, "kamer": ""}
		return {"x": p.x, "z": p.y, "kamer": KAMER, "vlak": vak_vlak(j)}

## Do the four plates, as big as they are drawn, fit over their holes now?
func platen_nu() -> bool:
	var maat := Vector2.ZERO
	for j in Beurt.VAKJES:
		var s = Hits.spot(VAK_TAG % j)
		if s != null and is_instance_valid(s.knoop):
			maat = maat.max((s.knoop as Control).get_combined_minimum_size())
	return platen_passen(maat)

## The opening of hole `j` on the screen, in frame units: its front face from
## the floor of the hole to the board.
func vak_vlak(j: int) -> Rect2:
	var p := vak_plek(j)
	var half := Modellen.VAK_BREED / 2.0
	var r := Rect2(World.mik_punt(p.x - half, p.y, float(Modellen.VOET)), Vector2.ZERO)
	for xy in [Vector2(p.x + half, Modellen.VOET), Vector2(p.x - half, Modellen.BORD),
			Vector2(p.x + half, Modellen.BORD)]:
		r = r.expand(World.mik_punt(xy.x, p.y, xy.y))
	return r

## Do four plates of `maat` fit over their holes on this frame: two neighbours
## apart in width or in height, and the first one under the top of the frame?
func platen_passen(maat: Vector2) -> bool:
	if maat.x <= 0.0 or maat.y <= 0.0:
		return false
	var a := World.mik_punt(vak_plek(0).x, vak_plek(0).y, 0.0)
	var b := World.mik_punt(vak_plek(1).x, vak_plek(1).y, 0.0)
	var d := (b - a).abs()
	if d.x < maat.x + 2.0 and d.y < maat.y + 2.0:
		return false
	return vak_vlak(0).position.y - maat.y >= 2.0

## Everything round the cart, but never the card (see `_kaart_neer`): the
## shelf and the pile, and the address of the letter on top — not while a
## letter flies, and not once the cart is empty.
func _teken() -> void:
	if not actief or ctx == null or S.is_empty() or O.is_empty():
		return
	_zet_decor()
	var br := _brief()
	if _stap() == "sorteer" and not _bezig and not br.is_empty():
		ctx.ui.getal_tag(KAR_ID, Beurt.adres(br), {"id": ADRES_ID, "kamer": KAMER,
			"y": ADRES_HOOG, "prio": 8, "titel": "de brief bovenop"})
	else:
		ctx.ui.getal_tag(KAR_ID, null, {"id": ADRES_ID})
	ctx.wereld.vuil()

# ------------------------------------------------------------------ probe

## The turn as the tests and the browser tools read it.
func stand() -> Dictionary:
	return S.duplicate(true)

func opzet() -> Dictionary:
	return O.duplicate(true)

## Machine-readable lines for `tools/kiek.js` / `speel.js`, web export only.
func _meld(wat: String) -> void:
	if not OS.has_feature("web"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not actief or S.is_empty() or O.is_empty():
		return
	var br := _brief()
	print("[probe] post ", wat, " stap=", _stap(), " band=", int(S["band"]), " i=", int(S["i"]),
		"/", (O["brieven"] as Array).size(), " brief=", br.get("tekst", "-"),
		" goed=", int(br.get("vak", -1)), " missers=", int(S["missers"]), " ster=", int(S["ster"]),
		" gast=", _gast_id())
	for id in Hits.debug().keys():
		if not str(id).begins_with("po_"):
			continue
		var spot := Hits.spot(id)
		if spot == null or not is_instance_valid(spot.knoop) or not spot.knoop.visible:
			continue
		print("[probe] postknop ", id, "=", spot.knoop.get_global_rect(),
			" dekking=", "%.2f" % Hits.dekking(id))
