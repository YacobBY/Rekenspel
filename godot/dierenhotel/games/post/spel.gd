extends MiniGame
## post — "De post sorteren", in de postkamer achter de lobby (U4, 2026-10-07;
## eigenaar: "Verzin nog vier kamers met activiteiten").
##
## Op de postkar ligt de post van vandaag: één brief per gast (2..6).  Langs de
## achterwand staat de vakkenkast met vier vakjes; boven elk vakje hangt zijn
## bordje met de getallen die erin horen ("30 - 39").  De kast is een
## GETALLENLIJN in vier stukken.  Een beurt:
##   1. De kaart staat er METEEN (W5e, 2026-10-08: de postbode kwam uit kamer 1
##      via de trap, de lobby, de tuin en de kas — 14 tot 24 s wachten, en een
##      kind van zes haakt dan af).  De postbode van de beurt (het dier dat het
##      kind op de spelbalk koos, anders de gast met een bed die het DICHTST
##      bij de postkamer is) loopt ondertussen in zijn eigen tempo naar de kar
##      en doet mee zodra hij er is.  Zonder gasten met een bed, of als hij
##      nooit aankomt, sorteert het kind de post alleen.
##   2. Op de bovenste brief staat zijn adres ("📮 34", groep 5 "📮 7 × 8"),
##      de kaart vraagt "📮 In welk vakje hoort deze brief?" met het adres op
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
const VAK_TAG := "po_vak%d"        ## the big plates (tablet, desktop)
const VAK_KLEIN := "po_vakje%d"    ## the small plates (phone, W5e)
const VORM_GROOT := "groot"
const VORM_KLEIN := "klein"
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
## The small plates of a phone (`_maak_klein`): text size, side padding, and
## how tall a digit of Nunito stands, in em (its cap height is 0.705).
const KLEIN_PUNT := UiThema.VLOER
const KLEIN_RAND := 4
const CIJFER_HOOG := 0.72

const SOM_S := 0.6           ## a letter in its hole, then the next one this much later
const AF_S := 3.4            ## the end card is readable this long before it closes
const BLIJF_S := 1.5         ## how often the postbode is kept at the cart
const KOM_TIK := 0.25        ## how often the turn looks whether he is at the cart yet
const HERSTUUR_S := 1.0      ## a postbode on nobody's way to the cart is sent again after this
## What a postbode is busy with that a fetch or a keep never breaks: a sulk
## after a miss, a happy hop, a meal, his bed.
const DRUK := ["sip", "blij", "eet", "slaap", "pose"]

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
var _klein_letter: FontVariation = null   ## the small plates' font (`_klein_font`)

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
	# A letter that was already put in a wrong hole stays on top of the pile
	# after any exit — another day, another hotel size or band (wave 2, R2):
	# the pile is seeded on the turn's own band, N, day and round, so it is
	# rebuilt from the save, never from today.
	if open_brief(S):
		hervat = true
	var weg := ""
	if hervat and not wil.is_empty() and wil != _gast_id():
		# the game bar's animal switch: the picked animal takes over the cart,
		# the pile and its progress stay (wave 2, R2 — it used to start the
		# same pile again at letter 0)
		weg = _gast_id()
		S["gast"] = wil
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
	O = Beurt.maak(int(S["band"]), int(S["N"]), int(S["dag"]), int(S["ronde"]))
	S["i"] = clampi(int(S["i"]), 0, (O["brieven"] as Array).size())
	_t0 = Time.get_ticks_msec()
	_kaart = null
	_kaart_sleutel = ""
	_bezig = false
	# the shelf with its numbered holes and the cart with its pile stand there
	# at once, and so does the question; the postbode walks over meanwhile
	# (`_begin`)
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

## The postbode: the picked animal, else the guest with a bed who is NEAREST to
## the postkamer — fewest doors to walk: the postkamer itself, then the kas, the
## garden, the lobby, then upstairs (W5e: the first play fetched him from
## kamer 1, 14–24 s away).  Equally near ones take turns with the day, as the
## whole list did before.
func _kies_postbode(kies: Array, wil: String, n: int, dag: int) -> String:
	if not wil.is_empty():
		return wil
	if kies.is_empty():
		return ""
	var beste := ""
	var beste_deuren := INF
	for k in kies.size():
		var id := str(kies[posmod(dag + n + k, kies.size())])
		var deuren := deuren_tot_kar(id)
		if deuren < beste_deuren:
			beste = id
			beste_deuren = deuren
	# nobody can walk there: the turn of the day's animal, as before
	return beste if not beste.is_empty() else str(kies[posmod(dag + n, kies.size())])

## How many doors (stairs included) `gast_id` walks to reach the postkamer:
## 0 when he is in it, INF when he is not in the world or has no way there.
static func deuren_tot_kar(gast_id: String) -> float:
	var d = World.dier(gast_id)
	if d == null:
		return INF
	if str(d.kamer) == KAMER:
		return 0.0
	var pad: Array = Rooms.pad(str(d.kamer), KAMER)
	return INF if pad.size() < 2 else float(pad.size() - 1)

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

## A saved pile whose top letter was already put in a wrong hole: that letter
## may not be swapped for a fresh pile (R2).
static func open_brief(st: Dictionary) -> bool:
	return not st.is_empty() and str(st.get("stap", "")) == "sorteer" \
		and int(st.get("pog", 0)) > 0

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

## The first letter at once, the postbode in his own time (W5e, 2026-10-08).
## The first play fetched him from kamer 1 — down the corridor and the stairs,
## through the lobby, the garden and the kas — and the card waited 14–24 s for
## him: a six-year-old gives up before the post has even started.  So this
## game departs from the owner's rule of 2026-09-23 ("Zorg dat de minigame pas
## begint wanneer het dier er is", `ctx.wacht_op`): its sum is the letter and
## the shelf, which stand there at once, not the animal.  The card comes at
## once, and the postbode — the NEAREST guest with a bed (`_kies_postbode`) —
## walks to the cart meanwhile and joins when he is there.  The game does not
## wait for him (no `ctx.wacht_op`, so no `Games.verwacht`): the hotel's "komt
## eraan" bubble with its `👀 Volg` steps aside like every hotel button while
## the game runs, and the camera stays in the postkamer with the card.  Without
## an animal in the room (nobody has a bed yet, he left the hotel on the way,
## or he is still walking) a miss shows its bubble at the card (`Ui.misser`);
## the turn ends the same way.
func _begin() -> void:
	# a pile that ran out without its end (cannot happen through `_kies`, which
	# finishes in the same step it takes the last letter) is finished now
	if _stap() == "sorteer" and _brief().is_empty():
		_klaar()
		return
	_kaart_neer()
	_teken()
	_haal_postbode()

## The postbode walks to the cart and then stays there for the whole turn.
## Nobody awaits this: the card never waits for him.
##   * On his way: every KOM_TIK the turn looks whether he stands at his place
##     (`ctx.is_er`).  A walk that something else took over is sent again after
##     HERSTUUR_S — never a sulk, a meal or a bed (`DRUK`); reduced motion
##     sends him at once, as `ctx.wacht_op` does.
##   * At the cart: a waiting guest starts to wander after sixteen seconds
##     (world.md §2.6), so every BLIJF_S he is sent back to his spot when he is
##     not there and not busy — the shape of oogst's `_houd_bij_de_tafel`.
##   * Gone from the hotel: the child sorts on alone (`_zonder_postbode`).
##   * The pile sorted before he came: he is not fetched any further.
func _haal_postbode() -> void:
	var gast := _gast_id()
	if gast.is_empty():
		return
	if World.dier(gast) == null:
		_zonder_postbode()
		return
	var plek := Vector2(GAST_X, GAST_Z)
	_stuur_postbode(gast)
	var er: bool = ctx.is_er(gast, plek)
	if er:
		ctx.wereld.blijf(gast, "wacht")
	var los := 0.0
	var tel := 0
	while actief and not S.is_empty() and _gast_id() == gast:
		if not await na(BLIJF_S if er else KOM_TIK):
			return
		if S.is_empty() or _gast_id() != gast:
			return
		var d = World.dier(gast)
		if d == null:
			_zonder_postbode()
			return
		if not er:
			if _stap() != "sorteer":
				return
			if ctx.is_er(gast, plek):
				er = true
				ctx.wereld.blijf(gast, "wacht")
				print("[probe] post postbode=er gast=", gast, " i=", int(S["i"]))
				continue
			if str(d.staat) in DRUK:
				los = 0.0
				continue
			los = 0.0 if _komt_eraan(d) else los + KOM_TIK
			if World.rust() or los >= HERSTUUR_S:
				los = 0.0
				_stuur_postbode(gast)
			continue
		if d.kamer != KAMER or not d.route.is_empty():
			continue
		if str(d.staat) in DRUK:
			continue
		tel += 1
		var doel := plek
		if not d.punten.is_empty():
			doel = d.punten[d.punten.size() - 1]
		var thuis: bool = absf(d.x - GAST_X) + absf(d.z - GAST_Z) <= 2.0
		if doel.distance_to(plek) > 2.0 or (not thuis and d.staat != "loop") \
				or (thuis and d.staat == "wacht" and tel % 8 == 0):
			ctx.wereld.ga(gast, GAST_X, GAST_Z, "wacht")

## Send him to his place at the cart — through the doors with `World.reis`,
## inside the room with `World.ga` — unless he stands there or is on his way.
## The save says where he is going (`waar`), as `ctx.wacht_op` writes it.
func _stuur_postbode(gast: String) -> void:
	var d = World.dier(gast)
	if d == null or ctx.is_er(gast, Vector2(GAST_X, GAST_Z)) \
			or (_komt_eraan(d) and not World.rust()):
		return
	if str(d.kamer) != KAMER:
		ctx.wereld.reis(gast, KAMER, {"x": GAST_X, "z": GAST_Z, "na": "wacht"})
		var g: Dictionary = ctx.state.gast_van(gast)
		if not g.is_empty():
			g["waar"] = KAMER
		d = World.dier(gast)
		# reduced motion walks the doors at once and leaves the last leg
		if d == null or str(d.kamer) != KAMER or not World.rust():
			return
	ctx.wereld.ga(gast, GAST_X, GAST_Z, "wacht")

## On his way to the cart: through the doors into the postkamer, or inside it
## with the cart's place at the end of his walk.
func _komt_eraan(d) -> bool:
	if str(d.kamer) != KAMER:
		return str(d.reis_doel) == KAMER
	var punten: Array = d.punten
	if punten.is_empty():
		return false
	var laatste: Vector2 = punten[punten.size() - 1]
	return laatste.distance_to(Vector2(GAST_X, GAST_Z)) <= SpelCtx.WACHT_MARGE

## He left the hotel on his way (or is not in the world): the post stays and
## the child sorts on alone; the game bar shows nobody.
func _zonder_postbode() -> void:
	if S.is_empty():
		return
	S["gast"] = ""
	ctx.speelt("")
	_bewaar()
	print("[probe] post postbode=weg")

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
	# a right answer on a choice strip (not a `goed: n` strip): the game says so
	ctx.reken_goed()
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
	# the postbode cheers where the child sees him — in the postkamer; one who
	# is still on his way is not stopped in a room nobody looks at
	var id := _gast_id()
	var wie = World.dier(id) if not id.is_empty() else null
	if wie != null and str(wie.kamer) == KAMER:
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
## every frame — so the plate stands on the board right over its hole.
##
## Two sets, one shown at a time (`plaat_vorm`, asked again in every placement
## pass, so a camera that is still sliding in, the maths bar docking or a
## phone turned over decides nothing for good):
##   * the BIG plates "50 - 59" (`VAK_TAG`) where four fit side by side over
##     their holes — every tablet and desktop frame;
##   * the SMALL plates "50-59" (`VAK_KLEIN`, W5e 2026-10-08) on a phone, where
##     the whole shelf is ~140 units wide and a big plate (58 × 25) is wider
##     than a hole's pitch (33 units) and taller than its step (17): the
##     hotel's own number tag at the hotel's smallest text, its line box hugging
##     the digits (14 units), so the four stand in a staircase right over their
##     holes like the big ones, the same words as the phone's strip buttons;
##   * none where not even those fit (a frame narrower than any phone the
##     hotel is made for): the band grid would only push plates over each
##     other's holes, and the strip — its buttons in the order of the holes —
##     carries the numbers alone.
func _zet_platen() -> void:
	var vakken: Array = O.get("vakjes", [])
	for j in vakken.size():
		var plaat := Beurt.plaat(vakken[j])
		var p := vak_plek(j)
		ctx.ui.getal_tag({"x": p.x, "z": p.y}, plaat, {"id": VAK_TAG % j, "kamer": KAMER,
			"y": float(Modellen.BORD), "prio": 6, "titel": "vakje " + plaat,
			"volg": _volg_vak(j, VORM_GROOT)})
		var klein: String = ctx.ui.getal_tag({"x": p.x, "z": p.y}, Beurt.kort(vakken[j]),
			{"id": VAK_KLEIN % j, "kamer": KAMER, "y": float(Modellen.BORD), "prio": 6,
			"titel": "vakje " + plaat, "volg": _volg_vak(j, VORM_KLEIN)})
		_maak_klein(ctx.hotspots.spot(klein))

## Where plate `j` of set `vorm` hangs this frame: over hole `j`, with the
## hole's opening as its thing — or nowhere (`kamer` ""), when the other set
## (or neither) is the one that fits.
func _volg_vak(j: int, vorm: String) -> Callable:
	var p := vak_plek(j)
	return func() -> Dictionary:
		if plaat_vorm() != vorm:
			return {"x": p.x, "z": p.y, "kamer": ""}
		return {"x": p.x, "z": p.y, "kamer": KAMER, "vlak": vak_vlak(j)}

## Which plates stand over the holes now: VORM_GROOT, VORM_KLEIN or "".
func plaat_vorm() -> String:
	if platen_passen(_plaat_maat(VAK_TAG)):
		return VORM_GROOT
	if platen_passen(_plaat_maat(VAK_KLEIN)):
		return VORM_KLEIN
	return ""

## The size of the biggest plate of one set, as big as it is drawn.
func _plaat_maat(sjabloon: String) -> Vector2:
	var maat := Vector2.ZERO
	for j in Beurt.VAKJES:
		var s = Hits.spot(sjabloon % j)
		if s != null and is_instance_valid(s.knoop):
			maat = maat.max((s.knoop as Control).get_combined_minimum_size())
	return maat

## A small plate: the hotel's own number tag (`UiGetalTag` — sun yellow, white
## rim, ink), in bold at the hotel's smallest text (`UiThema.VLOER`, the floor
## HOTEL.md §9 sets), with a thin rim and a line box that hugs the digits: a
## label reserves the line of its tallest fallback font (21 px for 12 px text,
## the emoji font), digits need 9 of it.  Made once when the turn starts; it
## never changes after that, so `Hits` measures what it draws.
func _maak_klein(s) -> void:
	if s == null or not is_instance_valid(s.knoop) or not (s.knoop is Label):
		return
	var t := s.knoop as Label
	t.add_theme_font_override("font", _klein_font())
	t.add_theme_font_size_override("font_size", KLEIN_PUNT)
	t.add_theme_stylebox_override("normal",
		UiThema.vulling(UiThema.vlak(UiThema.ZON, 999, 1, UiThema.WIT), KLEIN_RAND, 1))

## The small plates' font: Nunito bold, its line cut down to the digits with
## one pixel above them and two under the baseline (digits have no descent).
func _klein_font() -> Font:
	if _klein_letter != null:
		return _klein_letter
	var basis: Font = load(UiThema.NUNITO_VET)
	_klein_letter = FontVariation.new()
	_klein_letter.base_font = basis
	if basis != null:
		var cijfer := ceili(CIJFER_HOOG * KLEIN_PUNT)
		_klein_letter.spacing_top = -maxi(0, roundi(basis.get_ascent(KLEIN_PUNT)) - cijfer - 1)
		_klein_letter.spacing_bottom = -maxi(0, roundi(basis.get_descent(KLEIN_PUNT)) - 2)
	return _klein_letter

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
