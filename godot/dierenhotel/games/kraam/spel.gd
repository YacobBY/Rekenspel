extends MiniGame
## kraam — DE SOUVENIRKRAAM (games-b.md §5, money, HOTEL.md §9).
##
## Everything happens IN the garden, in the reserved zone along the right edge
## (`Rooms.get('tuin').zones.kraam`): the stall, the counter and the goods on it
## are LOOSE DECOR of this game, so they stand there only while you play and
## never in the hopscotch zone next door.  The guest with the 🎁 wish walks over
## and stands in front of it; group 4 and 5 first do a sum on the keypad, then
## every band lays real coins on the counter.  It worked out: the thing bought
## goes VISIBLY on the animal and stays there until checkout.
##
## THE SUMS ARE FROZEN and live in `Sommen.Kraam` (architecture.md §2.2):
## `opzet`, `schuif_van`, `splits_met`, `tel_vanaf`, `keuring`, `WAREN`,
## `MUNTEN`, `SPOOK_MUNT`.  This file never re-derives a price.
##
## WHAT THE GODOT PORT DOES DIFFERENTLY, and why (the owner's rule: "als Godot
## verbeteringen biedt implementeer die dan"):
##
##  1. `padPlek` is gone.  The HTML measured the strip-free frame height and
##     pushed the keypad out of the frame below 360 px, because its frame was
##     capped by a CSS aspect ratio and the keys landed on the price tags and on
##     the guest.  Here the camera already reserves `KADER_ONDER = 132` units
##     under the room and the keypad band docks in it, reserving its cells like
##     every other element (architecture.md §4.4).  One keypad, one place.
##  2. `kaartPast` is gone — the 120 ms re-measure loop, its seven rounds, the
##     560 ms repeat after a frame report and the 1500/3200 ms catch-ups for a
##     guest still walking in.  The card hands the hotspot layer a `volg`
##     callable that returns, every drawn frame, the height it wants AND the
##     rectangle it must stay off (the guest's own baked plate).  The band grid
##     then lifts the card off him structurally, in one pass, with no timer, no
##     bus loop and no frame-order dependence.
##  3. The buttons on the grass hang one voxel up instead of on the floor, so
##     they are placed by the band grid and therefore cover no object at all —
##     not the guest, not the counter, not the goods.
##
## Everything a child reads is verbatim from games-b.md §5.11 (F3).

const KAMER := "tuin"
const ZONE_TERUG := {"x0": 104, "x1": 126, "z0": 36, "z1": 68}

const KAART_ID := "kr_som"
const BANK_ID := "kr_geld"
const KLAAR_ID := "kr_ok"
const ZEG_ID := "kr_zeg"
const LEEG_ID := "kr_leeg"
const AF_ID := "kr_af"

## The card hangs this many css px above the counter's floor point (§5.6:
## `kaartHoog() = round(145 / pxPerHoogte)`); the lift on top of it is computed
## from the goods, not iterated.
const KAART_PX := 145.0
## `kortKader()` — one sentence instead of two (§5.6).
const KORT_H := 340.0
const SMAL_W := 360.0
## An overpaid coin lies on the counter this long and then slides back (§5.8).
const TERUG_S := 0.75
## The end card is readable this long before the game closes itself (§5.10).
const AF_S := 3.4
const LEEG_S := 1.8
## Fetching the guest: look again every 700 ms, at most 24 times (§5.5).
const GAST_POLL := 0.7
const GAST_KEER := 24
## After a right sum the card is redrawn 600 ms later (§5.9).
const SOM_S := 0.6
## The buttons on the grass, in css px left of the stall (§5.4).
const GRAS_MUNT := -60.0
const GRAS_MUNT_AF := -62.0
const GRAS_KLAAR := -160.0
const GRAS_SPOOK := -160.0
const GRAS_SPOOK_AF := 40.0
const GRAS_SPOOK_D := 32.0
## One voxel up, so the band grid places them and they cover nothing.
const GRAS_HOOG := 1.0
## A coin button is ~56 px wide in the HTML, because only "€2" stands in it and
## three of them have to read as three different coins.  `Ui.bron` has no way to
## pass a minimum size, so it is set on the Control this game owns.
const MUNT_BREED := 56.0
const WAREN_HOOG := 13.0
const GELD_HOOG := 13.0
const AF_HOOG := 14.0
const ZEG_PX := 66.0

## Child text, verbatim (games-b.md §5.11).
const T_LABEL := "Kraam"
const T_LEEG := "nog geen gasten"
const T_TAAK := "Souvenir"
const T_LEG_MUNTEN := "Leg de munten op de toonbank"
const T_SAMEN := "Hoeveel euro samen?"
const T_TERUG_VRAAG := "Hoeveel krijgt hij terug?"
const T_WISSEL_NEER := "Leg het wisselgeld neer"
const T_AF := "Veel plezier ermee!"
const T_KLAAR := "klaar"
const T_KLAAR_TITEL := "klaar met tellen"
const T_HAND := "in je hand"
const T_TERUG := "terug"
const T_ERBIJ := "erbij"
const T_TIK_GETAL := "tik een getal"
const T_SPOOK_SOM := "zoveel is het"
const T_SPOOK_LEG := "dit moet er nog bij"

const Modellen := preload("res://games/kraam/modellen.gd")

## The turn.  Lives in `ctx.data()["stand"]`, so it survives a reload; every
## number is read back through `int()`, because JSON hands them back as floats.
var S: Dictionary = {}
## The stall of today — purely a function of N, band and day, so it is always
## recomputed and never saved (§5.12).
var O: Dictionary = {}
## Where everything stands, derived from the zone and the current scale.
var P: Dictionary = {}

var _kaart: Ui.Kaart = null
## The coin that is sliding back: ON THE PICTURE ONLY, never in the save, so a
## reload in that half second never finds a counter that is too full (G5-F1).
var _terug_munt := 0
var _terug_nr := 0
var _kader_af := Callable()
var _gast_gestuurd := false
var _gast_gelopen := false
var _gast_keer := 0
var _t0 := 0

# ------------------------------------------------------------- aanmelding

func definitie() -> Dictionary:
	# None of these three may touch `self`: the registry reads `definitie()`
	# from a throwaway instance and frees it again (architecture.md §6.1).
	var unlock := func(n: int, _band: int) -> bool:
		return n >= 1
	var wanneer := func(s: Dictionary) -> bool:
		for g in s.get("gasten", []):
			if str(g.get("behoefte", "")) == "souvenir" and not bool(g.get("blij", false)):
				return true
		return false
	var tekst := func(s: Dictionary) -> String:
		for g in s.get("gasten", []):
			if str(g.get("behoefte", "")) == "souvenir":
				return "%s wil een souvenir" % str(g.get("naam", ""))
		return "Souvenir"
	return {
		"naam": "Souvenirkraam",
		"kamer": KAMER,
		"stub": false,
		# The registry only knows fixed decor, loose things and slots, and the
		# counter exists only while the game runs — so the entry button hangs on
		# the nearest FIXED garden piece (the ball at 120, 76) and dx/dz slide it
		# onto the counter: (120 − 5, 76 − 18) = (115, 58).
		"hotspot": {"obj": "bal", "dx": -5, "dz": -18, "icoon": "🎁",
			"label": T_LABEL, "hoog": 14},
		"unlock": unlock,
		"wens": "souvenir",
		"taak": {"id": "souvenir", "prio": 1, "icoon": "🎁",
			"wanneer": wanneer, "tekst": tekst},
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
	S = d.get("stand", {})
	if typeof(S) != TYPE_DICTIONARY:
		S = {}
	var g: Dictionary = {}
	if not S.is_empty():
		g = ctx.state.gast_van(str(S.get("gast", "")))
	# Resume only when the saved turn is still THIS turn (§5.12).
	if S.is_empty() or g.is_empty() or int(S.get("dag", 0)) != dag \
			or int(S.get("N", 0)) != n or int(S.get("band", 0)) != band \
			or str(S.get("stap", "")) == "af":
		g = kies[0]
		S = _nieuwe_stand(g, n, band, dag)
		d["stand"] = S
	O = Sommen.Kraam.opzet(n, band, dag)
	P = _plekken((O["waren"] as Array).size())
	_t0 = Time.get_ticks_msec()
	_terug_munt = 0
	_terug_nr = 0
	_gast_gestuurd = false
	_gast_gelopen = false
	_gast_keer = 0
	_herstel_bank()
	# A coin in your hand that this band does not have becomes the smallest one.
	if not (O["munten"] as Array).has(int(S.get("hand", 0))):
		S["hand"] = int((O["munten"] as Array)[0])
	# The frame may change shape (rotation, the keypad band appearing).  Only the
	# SENTENCES depend on it here — the card's height and the guest's rectangle
	# are recomputed every pass by `_volg_kaart`, so this listener never redraws
	# and can never become the 86-bus-beats loop the HTML had to guard against.
	_kader_af = ctx.ui.op_kader(_op_kader)
	_zet_decor()
	_haal_gast()
	_teken()
	State.bewaar()

func stop() -> void:
	if _kader_af.is_valid():
		_kader_af.call()
	_kader_af = Callable()
	if ctx != null:
		if not S.is_empty():
			State.bewaar()
		ctx.hotspots.laat()
		# world.md §1.7 wipes a game's loose decor by itself; doing it here too
		# means the garden is clean even when this game was never registered.
		ctx.wereld.decor_wis_alles()
	S = {}
	O = {}
	P = {}
	_kaart = null
	_terug_munt = 0
	_terug_nr = 0
	_gast_gestuurd = false
	_gast_gelopen = false
	_gast_keer = 0

## The star belongs to the whole turn and falls at most once (§5.10 step 4).
func _ster() -> bool:
	if S.is_empty() or int(S.get("ster", 0)) != 0:
		return false
	S["ster"] = 1
	ctx.taak_klaar("souvenir", {"sterren": 1})
	return true

func _meld_leeg() -> void:
	var z := _zone()
	ctx.ui.wolk({"id": LEEG_ID, "kamer": KAMER, "x": float(z["x0"]), "z": float(z["z1"]),
		"icoon": "🎁", "tekst": T_LEEG, "hoog": 24.0})
	if not await na(LEEG_S):
		return
	ctx.ui.wolk_weg(LEEG_ID)
	ctx.sluit()

# ------------------------------------------------------------- de spelstand

## Who buys: guests with a bed AND the 🎁 wish AND not yet happy; is that list
## empty, then everyone with a bed (the same friendly fallback as the tub).
func _kandidaten() -> Array:
	var met: Array = []
	var alle: Array = []
	for g in ctx.state.s["gasten"]:
		if str(g.get("bed", "")).is_empty():
			continue
		alle.append(g)
		if str(g.get("behoefte", "")) == "souvenir" and not bool(g.get("blij", false)):
			met.append(g)
	return met if not met.is_empty() else alle

func _nieuwe_stand(g: Dictionary, n: int, band: int, dag: int) -> Dictionary:
	var b := 3 if band <= 3 else (5 if band >= 5 else 4)
	return {
		"gast": str(g.get("id", "")), "dag": dag, "N": n, "band": band,
		"stap": "som" if b >= 4 else "leg",
		"gelegd": [], "hand": int((Sommen.Kraam.MUNTEN[b] as Array)[0]),
		"som_pog": 0, "leg_pog": 0, "missers": 0, "spook": 0, "hulp": "",
		"wens": 1 if str(g.get("behoefte", "")) == "souvenir" else 0,
		"ster": 0, "acc": 0, "zeg": null,
	}

func _stap() -> String:
	return str(S.get("stap", ""))

func _gast() -> Dictionary:
	if S.is_empty() or ctx == null:
		return {}
	return ctx.state.gast_van(str(S.get("gast", "")))

func _gelegd() -> Array:
	var uit: Array = S.get("gelegd", [])
	return uit if typeof(uit) == TYPE_ARRAY else []

static func _tel(lijst: Array) -> int:
	var som := 0
	for v in lijst:
		som += int(v)
	return som

## What LIES on the counter, the coin that is sliding back included.
func _op_bank() -> int:
	return _tel(_gelegd()) + _terug_munt

## A saved turn from an interrupted game may hold more than the amount; then the
## surplus is simply taken off, so the turn can always go on (§5.8).
func _herstel_bank() -> int:
	if S.is_empty() or O.is_empty():
		return 0
	var lijst := _gelegd()
	var n := 0
	while not lijst.is_empty() and _tel(lijst) > int(O["doel"]):
		lijst.pop_back()
		n += 1
	if n > 0:
		S["gelegd"] = lijst
		State.bewaar()
	return n

func _waar_van(id: String) -> Dictionary:
	for w in O.get("waren", []):
		if str(w["id"]) == id:
			return w
	return {}

func _gekocht() -> Array:
	var uit: Array = []
	for id in O.get("keus", []):
		var w := _waar_van(str(id))
		if not w.is_empty():
			uit.append(w)
	return uit

func _koopt(id: String) -> bool:
	return (O.get("keus", []) as Array).has(id)

# ------------------------------------------------------------- de plekken

func _zone() -> Dictionary:
	var r := Rooms.get_kamer(KAMER)
	if r != null and r.zones.has("kraam"):
		return r.zones["kraam"]
	return ZONE_TERUG

func _sch() -> Dictionary:
	return World.schaal()

## The little plank on the grass in front of the stall, worked out in SCREEN
## pixels so it holds in portrait and in landscape (§5.4).  The whole stall zone
## is only ~108 px wide in portrait and one button is already 84 px, so two
## buttons cannot stand beside each other inside it.
func _op_gras(u_px: float, d_px: float = 0.0) -> Dictionary:
	var s := _sch()
	var z := _zone()
	var d := float(int(z["x1"]) + int(z["z1"]) - 22)
	d += roundf(d_px / maxf(1.0, float(s["pxPerVoxelY"])))
	var ver := roundf(u_px / maxf(1.0, float(s["pxPerVoxelX"])))
	return _pt(roundf((d + ver) * 0.5), roundf((d - ver) * 0.5))

## One point in the garden, always inside the fence.  A pair of voxel
## coordinates is a Dictionary and never a Vector2 here: `y` would then read as
## the depth, and every call site would have to remember that.
static func _pt(x: float, z: float) -> Dictionary:
	return {"x": clampf(x, 6.0, 124.0), "z": clampf(z, 6.0, 124.0)}

func _plekken(n: int) -> Dictionary:
	var z := _zone()
	var xm := int(roundf((int(z["x0"]) + int(z["x1"])) / 2.0))     # 115
	var kraam_z := int(z["z0"]) + 4                               # 40: panel z 36..42
	var bank_z := int(z["z1"]) - 12                               # 56: top z 48..64
	# The goods must stand side by side ON SCREEN; horizontally that is the
	# isometric direction (x − z), so they lie on one depth line x + z = bankD.
	var bank_d := xm + bank_z                                     # 171
	var waren: Array = []
	for i in n:
		var f := 0.5 if n == 1 else float(i) / float(n - 1)
		var wx := int(roundf((xm - 8) + 16.0 * f))
		# The tags hang alternately 26 and 2 voxels above the top: all the goods
		# stand at the same depth, so without that difference they would touch.
		waren.append({"x": wx, "z": bank_d - wx, "tag_y": 26.0 if i % 2 == 1 else 2.0})
	return {
		"zone": z, "xm": xm, "bank_d": bank_d,
		"kraam": _pt(xm, kraam_z),
		"bank": _pt(xm, bank_z),
		"waren": waren,
		# the money comes to the front of the top: bigger x + z than the goods,
		# so on screen it lies in front of them
		"geld": _pt(xm, int(z["z1"]) - 4),
		# the guest stands IN FRONT of the stall, nearer the viewer than the
		# table and left of the ball, 26 voxels before the zone's front edge
		"gast": _pt(int(z["x0"]) - 4, int(z["z1"]) + 26),
	}

# ------------------------------------------------------------------ wereld

func _zet_decor() -> void:
	ctx.wereld.decor(KAMER, {"id": "kr_kraam", "model": "kraam_kraam",
		"x": P["kraam"]["x"], "z": P["kraam"]["z"]})
	ctx.wereld.decor(KAMER, {"id": "kr_toonbank", "model": "kraam_bank",
		"x": P["bank"]["x"], "z": P["bank"]["z"]})
	var waren: Array = O["waren"]
	for i in waren.size():
		var p: Dictionary = P["waren"][i]
		ctx.wereld.decor(KAMER, {"id": "kr_w%d" % i,
			"model": _model_van(waren[i]), "x": float(p["x"]), "z": float(p["z"]),
			"hoog": WAREN_HOOG})
	ctx.wereld.vuil()

## `Sommen.Kraam.WAREN` names the models as the HTML did (`kr_hoedje`); a game's
## own model is registered with the game id in front (architecture.md §13).
static func _model_van(w: Dictionary) -> String:
	return "kraam_" + str(w["model"]).trim_prefix("kr_")

## The guest walks to his place in front of the counter.  In another room he
## travels through the doors first — sent ONCE, because sending him again on the
## way restarts his route — and we look again every 700 ms (§5.5).
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
			ctx.wereld.reis(id, KAMER, {"x": P["gast"]["x"], "z": P["gast"]["z"], "na": "wacht"})
			g["waar"] = KAMER
		if _gast_keer >= GAST_KEER:
			return
		_gast_keer += 1
		if not await na(GAST_POLL):
			return
		if S.is_empty() or P.is_empty():
			return
		d = World.dier(id)
	if _gast_gelopen:
		return
	_gast_gelopen = true
	g["waar"] = KAMER
	# No re-measure on arrival: the card reads his rectangle every pass itself.
	var gehaald: bool = await ctx.wereld.loop_naar(id, P["gast"]["x"], P["gast"]["z"], {"na": "wacht"})
	if not actief or S.is_empty():
		return
	if gehaald:
		ctx.wereld.vuil()

# ------------------------------------------------------------------ tekenen

func _zeg(o = null) -> void:
	if not S.is_empty():
		S["zeg"] = o

## One sentence or two?  A two-sentence card is 129 px high on 320 × 640 and
## then no longer fits beside the guest, and "het dier blijft zichtbaar" beats
## "de zin op één regel" (§5.6).
func _kort_kader() -> bool:
	var k := World.kader_rect().size
	if k.y <= 0.0:
		return false
	return k.y < KORT_H or k.x < SMAL_W

static func _hoofd(w: String) -> String:
	return w if w.is_empty() else w.substr(0, 1).to_upper() + w.substr(1)

## The sentences on the card, verbatim (§5.7).  [0] is the mandatory line, [1]
## the question or the instruction under it.
func _zinnen() -> Array:
	var g := _gast()
	var naam := str(g.get("naam", "De gast"))
	var k := _gekocht()
	if _stap() == "af" or k.is_empty():
		return [T_AF]
	var band := int(O["band"])
	if band <= 3:
		return ["%s wil %s %s van %s" % [naam, str(k[0]["lid"]), str(k[0]["naam"]),
			Sommen.Kraam.euro(int(k[0]["prijs"]))], T_LEG_MUNTEN]
	if band == 4:
		if _stap() == "som":
			return ["%s %s en %s %s" % [_hoofd(str(k[0]["naam"])),
				Sommen.Kraam.euro(int(k[0]["prijs"])), str(k[1]["naam"]),
				Sommen.Kraam.euro(int(k[1]["prijs"]))], T_SAMEN]
		return ["Samen kost het %s" % Sommen.Kraam.euro(int(O["kosten"])), T_LEG_MUNTEN]
	if _stap() == "som":
		return ["%s gaf %s, het kost %s" % [naam, Sommen.Kraam.euro(int(O["betaald"])),
			Sommen.Kraam.euro(int(O["kosten"]))], T_TERUG_VRAAG]
	return ["%s krijgt %s terug" % [naam, Sommen.Kraam.euro(int(O["wissel"]))],
		T_WISSEL_NEER]

## The sum line: at the question the sum itself, at the paying the target
## amount.  The answer box beside it is filled by the card with what lies on the
## counter RIGHT NOW, so there is never an empty box you can do nothing with.
func _som_lijn() -> String:
	if _stap() == "som" and not (O["vraag"] as Dictionary).is_empty():
		return str(O["vraag"]["som"])
	return Sommen.Kraam.euro(int(O["doel"]))

func _kaart_ico() -> String:
	if _stap() == "af":
		return "✅"
	return "👛" if int(O["band"]) >= 5 else "🎁"

func _teken() -> void:
	if not actief or ctx == null or S.is_empty() or O.is_empty():
		return
	ctx.hotspots.wis_alles()
	_teken_kaart()
	_teken_waren()
	if _stap() == "leg":
		_teken_bank()
		_teken_munten()
		_teken_klaar()
	if _stap() == "af":
		_teken_bank()
		_teken_af()
	if _stap() == "leg" and int(S.get("spook", 0)) == 1:
		_spook_neer(int(O["doel"]) - _tel(_gelegd()), T_SPOOK_LEG)
	_teken_zeg()
	ctx.wereld.vuil()
	_meld()

## The browser proof of the ticket follows these lines (architecture.md §14.4).
## They are printed by the WEB export only, so the headless suite stays quiet,
## and they carry exactly what a driver needs to play a turn: the step, the
## target, and the rectangle of every button and every key on the glass.
func _meld() -> void:
	if not OS.has_feature("web"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not actief or S.is_empty() or O.is_empty():
		return
	var vraag: Dictionary = O["vraag"]
	print("[probe] kraam stap=", _stap(), " band=", int(O["band"]),
		" doel=", int(O["doel"]), " ligt=", _op_bank(),
		" antwoord=", int(vraag["goed"]) if not vraag.is_empty() else -1,
		" munten=", O["munten"], " missers=", int(S.get("missers", 0)),
		" ster=", int(S.get("ster", 0)))
	for id in Hits.debug().keys():
		if not str(id).begins_with("kr_"):
			continue
		var spot := Hits.spot(id)
		if spot == null or not is_instance_valid(spot.knoop) or not spot.knoop.visible:
			continue
		print("[probe] kraamknop ", id, "=", spot.knoop.get_global_rect(),
			" dekking=", "%.2f" % Hits.dekking(id))
		var raster := spot.knoop.get_node_or_null("Toetsen")
		if raster != null:
			for k in raster.get_children():
				print("[probe] kraamtoets ", k.name, "=", (k as Control).get_global_rect())

func _teken_kaart() -> void:
	var open := _stap() == "som" and not O.is_empty() and not (O.get("vraag", {}) as Dictionary).is_empty()
	var zinnen := _zinnen()
	var regel2: String = "" if _kort_kader() or zinnen.size() < 2 else str(zinnen[1])
	var o := {
		"id": KAART_ID, "kamer": KAMER, "hoog": _kaart_hoog(), "icoon": _kaart_ico(),
		"regel": str(zinnen[0]), "regel2": regel2, "max": 2,
		"vlak": _vrij_vlak(),
	}
	if open:
		# the slips: the price alone, the note alone, the sum of both
		o["goed"] = int(O["vraag"]["goed"])
		o["liever"] = [int(O["kosten"]), int(O["betaald"]), int(O["kosten"]) + int(O["betaald"])]
		o["on_ok"] = _antwoord_som
	_kaart = ctx.ui.somkaart({"x": P["bank"]["x"], "z": P["bank"]["z"], "kamer": KAMER},
		_som_lijn(), o)
	if _kaart == null:
		return
	# The card follows the guest, every drawn frame, with his own baked
	# rectangle: that is what replaces `kaartPast` (see the header).
	var spot: Hits.Spot = ctx.hotspots.spot(KAART_ID)
	if spot != null:
		spot.volg = _volg_kaart
	if not str(S.get("hulp", "")).is_empty():
		_kaart.hulp(str(S["hulp"]))
	if _stap() == "af":
		_kaart.zet(Sommen.Kraam.euro(int(O["doel"])))
		_kaart.klaar()
	elif _stap() == "leg":
		_kaart.zet(Sommen.Kraam.euro(_op_bank()))
	elif int(S.get("som_pog", 0)) >= 3 and not (O["vraag"] as Dictionary).is_empty():
		_spook_neer(int(O["vraag"]["goed"]), T_SPOOK_SOM)

## Where the card wants to hang, in voxels above the counter's floor point.
## `round(145 / pxPerHoogte)` as the spec says, plus exactly the lift that keeps
## it clear of the goods and of the guest — COMPUTED from the baked rectangles,
## where the HTML measured the DOM every 120 ms and stepped until it fitted.
##
## The hard rule goes first (§5.6): the card may never lie over the guest.  It
## goes above him when there is room above, and under him when there is not.
func _kaart_hoog() -> float:
	if P.is_empty():
		return 22.0
	var pph := maxf(1.0, World.px_per_hoogte())
	var mik := World.mik_punt(P["bank"]["x"], P["bank"]["z"], 0.0)
	var mid := mik.y - KAART_PX
	var maat := _kaart_maat()
	if maat.y <= 0.0:
		return (mik.y - mid) / pph
	var top := _waren_top()
	if top < INF:
		# above the goods AND above the strip their price tags hang in: a card
		# that lands in that strip pushes every tag a whole band down, on top of
		# its own thing (measured: 15.6 % coverage of a €4 hat)
		mid = minf(mid, top - _kaartje_hoog() - float(Hits.GAT) - maat.y * 0.5)
	var g := _gast_vlak()
	var kader := World.kader_rect().size
	if g.size.y > 0.0 and kader.y > 0.0:
		# the x the band grid will really give it: on the aim point, clamped
		var x0 := clampf(mik.x - maat.x * 0.5, float(Hits.KRAP),
			maxf(float(Hits.KRAP), kader.x - maat.x - float(Hits.KRAP)))
		if x0 < g.end.x and x0 + maat.x > g.position.x:
			var boven := g.position.y - float(Hits.GAT) - maat.y * 0.5
			var onder := g.end.y + float(Hits.GAT) + maat.y * 0.5
			if boven - maat.y * 0.5 >= float(Hits.KRAP):
				mid = minf(mid, boven)
			elif onder + maat.y * 0.5 <= kader.y - float(Hits.KRAP):
				mid = onder
	return (mik.y - mid) / pph

func _kaart_maat() -> Vector2:
	var spot := Hits.spot(KAART_ID)
	if spot == null or not is_instance_valid(spot.knoop):
		return Vector2.ZERO
	return spot.knoop.get_combined_minimum_size()

## How much room the price tags need above the goods.  Measured on the tags
## themselves as soon as they exist; `Ui` builds them, so their height is not
## this game's to assume.
func _kaartje_hoog() -> float:
	var h := 26.0
	for i in (O.get("waren", []) as Array).size():
		var spot := Hits.spot("kr_p%d" % i)
		if spot != null and is_instance_valid(spot.knoop):
			h = maxf(h, spot.knoop.get_combined_minimum_size().y)
	return h

## The highest edge of the goods on the counter, in frame units.
func _waren_top() -> float:
	if O.is_empty() or P.is_empty() or World.kamer_nu() != KAMER:
		return INF
	var top := INF
	var waren: Array = O["waren"]
	for i in waren.size():
		var p: Dictionary = P["waren"][i]
		var r := World.vlak_van(_model_van(waren[i]), float(p["x"]), float(p["z"]),
			WAREN_HOOG)
		if r.size.y > 0.0:
			top = minf(top, r.position.y)
	return top

## The rectangle the card may never lie on: the guest while he is in the garden
## (HOTEL.md §9, binding), otherwise the counter it belongs to.
func _vrij_vlak() -> Rect2:
	if P.is_empty():
		return Rect2()
	var g := _gast_vlak()
	return g if g.size.y > 0.0 else _bank_vlak()

## Where the guest draws right now, straight from his own baked plate.
func _gast_vlak() -> Rect2:
	var g := _gast()
	if g.is_empty() or World.kamer_nu() != KAMER:
		return Rect2()
	var d = World.dier(str(g["id"]))
	if d == null or d.kamer != KAMER:
		return Rect2()
	var r := World.vlak_van_dier(str(g["id"]))
	return r if r.size.x > 0.0 and r.size.y > 0.0 else Rect2()

func _bank_vlak() -> Rect2:
	if P.is_empty() or World.kamer_nu() != KAMER:
		return Rect2()
	return World.vlak_van("kraam_bank", P["bank"]["x"], P["bank"]["z"], 0.0)

func _volg_kaart() -> Dictionary:
	if not actief or P.is_empty():
		return {}
	return {"x": P["bank"]["x"], "z": P["bank"]["z"], "y": _kaart_hoog(),
		"kamer": KAMER, "vlak": _vrij_vlak()}

func _volg_bank() -> Dictionary:
	if not actief or P.is_empty():
		return {}
	return {"x": P["geld"]["x"], "z": P["geld"]["z"], "y": GELD_HOOG,
		"kamer": KAMER, "vlak": _bank_vlak()}

## Are the ghost coins on the grass right now?  While they lie there only the
## thing being bought keeps its price tag, so the garden stays under 16 buttons.
func _spook_ligt() -> bool:
	if _stap() == "leg":
		return int(S.get("spook", 0)) == 1
	if _stap() == "som":
		return int(S.get("som_pog", 0)) >= 3
	return false

## The price tags: every displayed thing carries its price as a number ON the
## thing.  It is not a button — the guest already says on the card what he wants.
func _teken_waren() -> void:
	var alleen := _spook_ligt()
	var waren: Array = O["waren"]
	for i in waren.size():
		var w: Dictionary = waren[i]
		var wil := _koopt(str(w["id"]))
		if alleen and not wil:
			continue
		var p: Dictionary = P["waren"][i]
		var id := "kr_p%d" % i
		ctx.ui.getal_tag({"x": float(p["x"]), "z": float(p["z"]), "kamer": KAMER},
			Sommen.Kraam.euro(int(w["prijs"])),
			{"id": id, "y": float(p["tag_y"]), "prio": 8,
				"klas": "veel" if wil else "",
				"titel": "%s %s kost %d euro" % [str(w["lid"]), str(w["naam"]),
					int(w["prijs"])]})
		if wil:
			_verf_veel(id)

## `Ui.getal_tag` passes `klas` on to the hotspot layer but `UiGetalTag` has no
## variant for it, so the pink `veel` number of the HTML is painted here — on
## this game's own Control, never on the theme.
func _verf_veel(id: String) -> void:
	var spot := Hits.spot(id)
	if spot == null or not is_instance_valid(spot.knoop):
		return
	var lbl := spot.knoop as Label
	if lbl == null:
		return
	lbl.add_theme_stylebox_override("normal",
		UiThema.vulling(UiThema.vlak(UiThema.ROZE, 999, 2, UiThema.WIT), 7, 1))

## The counter: drag or tap the coins here, the amount stands on it.  The catch
## area of the hotspot layer covers button AND top, so dragging onto the table
## itself works (architecture.md §10).
func _teken_bank() -> void:
	var som := _op_bank()
	ctx.hotspots.maak({
		"id": BANK_ID, "kamer": KAMER, "x": P["geld"]["x"], "z": P["geld"]["z"],
		"y": GELD_HOOG, "icoon": "🧾", "label": Sommen.Kraam.euro(som),
		"drop": BANK_ID, "klas": "hotbron", "prio": 11,
		# UNDER the top: above it stand the price tags, which do not give way.
		"op": "onder", "volg": _volg_bank,
		"titel": "op de toonbank ligt %s van %s"
			% [Sommen.Kraam.euro(som), Sommen.Kraam.euro(int(O["doel"]))],
		"aan": func(_s) -> void: _leg_munt(int(S.get("hand", 0))),
		"val": func(lading, _data) -> void:
			_leg_munt(int((lading as Dictionary).get("waarde", S.get("hand", 0)))),
	})

## EVERY coin has its own drag source: €1 and €2 in group 3 and 4, and €1, €2
## and €5 in group 5.  One button with a switch would have three states in group
## 5, and "which coin do I have in my hand" is exactly the mistake you do not
## want to make with change (G5-F1).
func _teken_munten() -> void:
	var munten: Array = O["munten"]
	for i in munten.size():
		var v := int(munten[i])
		var in_hand := int(S.get("hand", 0)) == v
		var p := _op_gras(GRAS_MUNT + i * GRAS_MUNT_AF)
		var id := "kr_m%d" % v
		ctx.hotspots.bron({"x": p["x"], "z": p["z"], "kamer": KAMER}, {
			"id": id, "hoog": GRAS_HOOG, "prio": 10 + (1 if in_hand else 0),
			"icoon": Sommen.Kraam.euro(v), "hand": 1 if in_hand else 0,
			"titel": "munt van %d euro%s" % [v, ", " + T_HAND if in_hand else ""],
			"sleep": BANK_ID, "data": {"waarde": v},
			"tik": func(_s) -> void: _pak_munt(v),
		})
		# `UiBron` only hands out drag data when it has a count, and this drawer
		# never runs out; setting the field instead of calling `zet()` keeps the
		# counting pill hidden, which a coin must not have.
		var bron := Ui.bron_van(id)
		if bron != null:
			bron.aantal = 1
			bron.custom_minimum_size = Vector2(MUNT_BREED, float(Ui.tap_maat()))

func _teken_klaar() -> void:
	var p := _op_gras(GRAS_KLAAR)
	ctx.hotspots.maak({
		"id": KLAAR_ID, "kamer": KAMER, "x": p["x"], "z": p["z"], "y": GRAS_HOOG,
		"icoon": "✔", "label": T_KLAAR, "klas": "hotwolk goed", "prio": 9,
		"titel": T_KLAAR_TITEL, "aan": func(_s) -> void: _klaar_met_tellen(),
	})

## The souvenir BESIDE the guest once the turn is done.  A number tag and not a
## bubble: a bubble is pushed away by the layer and then the remark no longer
## stands by its own animal.  It hangs on the left at chest height and NOT on
## his head, because his name plate is there.
func _teken_af() -> void:
	var g := _gast()
	if g.is_empty():
		return
	ctx.ui.getal_tag({"x": P["gast"]["x"] - 11.0, "z": P["gast"]["z"] + 11.0, "kamer": KAMER},
		"🎁", {"id": AF_ID, "y": AF_HOOG, "prio": 12,
			"titel": "%s heeft zijn souvenir" % str(g.get("naam", ""))})

func _teken_zeg() -> void:
	var z = S.get("zeg", null)
	if typeof(z) != TYPE_DICTIONARY:
		return
	var getal = z.get("getal", "")
	ctx.ui.wolk({"id": ZEG_ID, "kamer": KAMER, "x": P["bank"]["x"], "z": P["bank"]["z"],
		"icoon": str(z.get("icoon", "")), "getal": null if str(getal).is_empty() else getal,
		"tekst": str(z.get("tekst", "")), "klas": "hulp",
		"hoog": roundf(ZEG_PX / maxf(1.0, World.px_per_hoogte())), "prio": 12})

# ------------------------------------------------------------- spookmunten

func _spook_weg() -> void:
	if ctx == null:
		return
	for i in Sommen.Kraam.SPOOK_MAX:
		ctx.ui.getal_tag({"x": 0.0, "z": 0.0}, null, {"id": "kr_sp%d" % i})

## The showing row lies on the grass in front of the stall, 40 css px apart, on
## a depth line in front of the purse so it never falls over it (§5.8/§5.9).
func _spook_neer(bedrag: int, titel: String) -> void:
	_spook_weg()
	if bedrag <= 0 or O.is_empty():
		return
	var munten := Sommen.Kraam.splits_met(bedrag, Sommen.Kraam.SPOOK_MUNT)
	for i in mini(munten.size(), Sommen.Kraam.SPOOK_MAX):
		var p := _op_gras(GRAS_SPOOK + i * GRAS_SPOOK_AF, GRAS_SPOOK_D)
		ctx.ui.getal_tag({"x": p["x"], "z": p["z"], "kamer": KAMER},
			Sommen.Kraam.euro(int(munten[i])),
			{"id": "kr_sp%d" % i, "y": 0.0, "klas": "hotspook", "prio": 7,
				"titel": titel})

# ---------------------------------------------------- het cijferpad (§5.9)

func _antwoord_som(n, k) -> void:
	if S.is_empty() or _stap() != "som" or O.is_empty():
		return
	if n == null:
		_zeg({"icoon": "☝", "getal": "", "tekst": T_TIK_GETAL})
		_teken()
		return
	var goed := int(O["vraag"]["goed"])
	if int(n) != goed:
		S["som_pog"] = int(S.get("som_pog", 0)) + 1
		S["missers"] = int(S.get("missers", 0)) + 1
		ctx.snd.zacht()
		if k != null:
			k.zet("")
		# The help ladder: count on together first, then again, and only at the
		# third try do the ghost coins lie there (`_teken_kaart` puts them down).
		var koop := _gekocht()
		if int(O["band"]) == 4 and koop.size() >= 2:
			S["hulp"] = Sommen.Kraam.tel_vanaf(int(koop[0]["prijs"]), int(koop[1]["prijs"]))
		else:
			S["hulp"] = "%s ▸ %s" % [Sommen.Kraam.euro(int(O["kosten"])),
				Sommen.Kraam.euro(int(O["betaald"]))]
		_zeg(null)
		State.bewaar()
		_teken()
		return
	ctx.state.tel(int(S.get("som_pog", 0)) == 0, Time.get_ticks_msec() - _t0)
	ctx.snd.ja()
	if k != null:
		k.zet(Sommen.Kraam.euro(int(n)))
	S["stap"] = "leg"
	S["hulp"] = ""
	S["zeg"] = null
	_spook_weg()
	State.bewaar()
	_na_de_som()

func _na_de_som() -> void:
	if not await na(SOM_S):
		return
	if S.is_empty() or _stap() != "leg":
		return
	_teken()

# ------------------------------------------------------------- de munten

func _pak_munt(v: int) -> void:
	if S.is_empty() or _stap() != "leg" or O.is_empty():
		return
	if not (O["munten"] as Array).has(v):
		return
	S["hand"] = v
	ctx.snd.tik()
	_zeg({"icoon": "🪙", "getal": Sommen.Kraam.euro(v), "tekst": T_HAND})
	State.bewaar()
	_teken()

func _leg_munt(v: int) -> void:
	if S.is_empty() or _stap() != "leg" or O.is_empty():
		return
	if not (O["munten"] as Array).has(v):
		v = int(S.get("hand", 0))
	if not (O["munten"] as Array).has(v):
		return
	_herstel_bank()
	# A coin is already sliding back: then the stall takes no new one for a
	# moment.  Without that gate every tap in that half second adds a coin while
	# only one comes back.
	if _terug_munt != 0:
		ctx.snd.zacht()
		_zeg({"icoon": "🪙", "getal": Sommen.Kraam.euro(_op_bank() - int(O["doel"])),
			"tekst": T_TERUG})
		_teken()
		return
	var lijst := _gelegd()
	var som := _tel(lijst)
	S["hand"] = v
	# Too much: the coin lies on it for a moment and then slides back.  So the
	# child sees how much too much it was; nothing is ever taken away and the
	# turn simply goes on.  The coin lives in `_terug_munt` only, so the SAVE
	# stays on the last valid state.
	if som + v > int(O["doel"]):
		_terug_munt = v
		S["missers"] = int(S.get("missers", 0)) + 1
		_terug_nr += 1
		var mijn := _terug_nr
		ctx.snd.munt()
		_zeg({"icoon": "🪙", "getal": Sommen.Kraam.euro(som + v - int(O["doel"])),
			"tekst": T_TERUG})
		State.bewaar()                    # only the valid state
		_teken()
		_schuif_terug(mijn)
		return
	lijst.append(v)
	S["gelegd"] = lijst
	ctx.snd.munt()
	_zeg(null)
	S["spook"] = 0
	_spook_weg()
	State.bewaar()
	if _tel(lijst) == int(O["doel"]):
		_gelukt()
		return
	_teken()

func _schuif_terug(mijn: int) -> void:
	if not await na(TERUG_S):
		return
	if S.is_empty() or _terug_nr != mijn:
		return
	_terug_munt = 0
	ctx.snd.terug()
	_teken()

## "zo is het goed": tapping is always allowed.  Is there too little, then the
## bubble calmly says how much still has to go on — never red, never a cross.
func _klaar_met_tellen() -> void:
	if S.is_empty() or _stap() != "leg" or O.is_empty():
		return
	var som := _op_bank()
	var doel := int(O["doel"])
	if som == doel:
		_gelukt()
		return
	S["leg_pog"] = int(S.get("leg_pog", 0)) + 1
	S["missers"] = int(S.get("missers", 0)) + 1
	ctx.snd.zacht()
	if som < doel:
		_zeg({"icoon": "🪙", "getal": "+" + Sommen.Kraam.euro(doel - som), "tekst": T_ERBIJ})
	else:
		_zeg({"icoon": "🪙", "getal": Sommen.Kraam.euro(som - doel), "tekst": T_TERUG})
	if int(S["leg_pog"]) >= 2:
		var deel: Array = []
		for m in Sommen.Kraam.splits_met(doel, O["munten"]):
			deel.append(Sommen.Kraam.euro(int(m)))
		S["hulp"] = " + ".join(deel)
	S["spook"] = 1 if int(S["leg_pog"]) >= 3 else 0
	State.bewaar()
	_teken()

# ---------------------------------------------------------------- gelukt

func _gelukt() -> void:
	if S.is_empty() or _stap() == "af":
		return
	S["stap"] = "af"
	S["spook"] = 0
	S["hulp"] = ""
	S["zeg"] = null
	_spook_weg()
	var g := _gast()
	# what was bought stays VISIBLE on the animal until checkout
	if not g.is_empty() and int(S.get("acc", 0)) == 0:
		for w in _gekocht():
			if str(w["acc"]) != "":
				ctx.wereld.accessoire(str(g["id"]), str(w["acc"]))
		S["acc"] = 1
	ctx.state.tel(int(S.get("missers", 0)) == 0, Time.get_ticks_msec() - _t0)
	# first tick the task off (that is also the star), THEN report the wish:
	# `behoefte_klaar` redraws the notice board straight away
	_ster()
	if not g.is_empty() and int(S.get("wens", 0)) == 1:
		ctx.wereld.behoefte_klaar(str(g["id"]), "souvenir")
	ctx.snd.tover()
	ctx.snd.hoera()
	State.bewaar()
	Hotel.render()
	_teken()
	if not g.is_empty():
		ctx.wereld.set_mood(str(g["id"]), "bouncy")
	_sluit_straks()

func _sluit_straks() -> void:
	if not await na(AF_S):
		return
	if S.is_empty() or _stap() != "af":
		return
	ctx.sluit()

# ------------------------------------------------------------ kadermelding

## A frame report only changes the SENTENCES (`_kort_kader`); the card's height
## and the guest's rectangle come from `_volg_kaart` every pass.  Nothing is
## removed and nothing is added here, so this can never feed itself.
func _op_kader(_rect: Rect2, _schaal: Dictionary) -> void:
	if not actief or S.is_empty() or O.is_empty() or _kaart == null:
		return
	var zinnen := _zinnen()
	_kaart.regel(str(zinnen[0]))
	_kaart.regel2("" if _kort_kader() or zinnen.size() < 2 else str(zinnen[1]))
