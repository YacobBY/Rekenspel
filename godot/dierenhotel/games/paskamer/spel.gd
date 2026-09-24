extends MiniGame
## paskamer — de paskamer van de Winkelstraat (games-d.md §5).
##
## The owner asked for "meer aanpassingsmogelijkheden in de minigames, zoals
## kleding of andere outfit-opties" (2026-09-24).  What an animal buys in the
## shops is its own (`State.kast_van`); here, in front of the big mirror, the
## child chooses what it wears.  One button per slot the animal owns something
## for — head, neck, paws, eyes, the ball — and every tap puts on the next piece
## of that slot, round to nothing and back.  The animal shows it at once and is
## pleased with itself.  No sum and no star: this is dressing up, not maths,
## and it costs nothing.  `⬅ Terug` (or the animal chip on the game bar, to
## dress the next one) ends it.

const KAMER := "winkels"
const SPIEGEL := "spiegelz"
const PLEK := Vector2(20, 94)      ## in front of the mirror
const KAART_ID := "pk_kaart"
const LEEG_ID := "pk_leeg"
const LEEG_S := 1.8
const KAART_HOOG := 30.0

const T_REGEL := "Wat trekt %s aan?"          ## 4 woorden
const T_LEEG := "nog niets gekocht"
const T_GEEN := "Geen"
## The picture of a slot when nothing is worn in it.
const SLOT_ICOON := {"hoofd": "🎩", "nek": "🧣", "poten": "👟", "ogen": "🕶️", "speel": "⚽"}

var _gast := ""
var _kaart = null

func definitie() -> Dictionary:
	# `kan`: somebody with a bed owns something to put on (world.md §5.1: no
	# button that can do nothing).  Static: literals and autoloads only.
	var kan := func(s: Dictionary) -> bool:
		for g in s.get("gasten", []):
			if str(g.get("bed", "")).is_empty():
				continue
			for lijst in [g.get("kast", []), g.get("accessoires", [])]:
				if typeof(lijst) == TYPE_ARRAY and not (lijst as Array).is_empty():
					return true
		return false
	return {
		"naam": "Paskamer",
		"kamer": KAMER,
		"stub": false,
		"hotspot": {"obj": SPIEGEL, "icoon": "🪞", "label": "Paskamer", "hoog": 34},
		"unlock": func(n: int, _band: int) -> bool: return n >= 1,
		"kan": kan,
	}

## Everyone with a bed, the ones with something in their wardrobe first.
func spelers() -> Array:
	var met: Array = []
	var zonder: Array = []
	for g in ctx.state.s["gasten"]:
		if str(g.get("bed", "")).is_empty():
			continue
		var id := str(g.get("id", ""))
		if ctx.state.kast_van(id).is_empty():
			zonder.append(id)
		else:
			met.append(id)
	return met + zonder

func start(_c: SpelCtx) -> void:
	var lijst := spelers()
	if lijst.is_empty():
		_meld_leeg()
		return
	var wil := ctx.voorkeur(lijst)
	_gast = wil if not wil.is_empty() else str(lijst[0])
	ctx.speelt(_gast)
	if ctx.state.kast_van(_gast).is_empty():
		_meld_leeg()
		return
	_begin()

func stop() -> void:
	_kaart = null
	_gast = ""

func _meld_leeg() -> void:
	ctx.ui.wolk({"id": LEEG_ID, "kamer": KAMER, "obj": SPIEGEL, "op": "aan",
		"x": PLEK.x - 18.0, "z": PLEK.y, "hoog": 20.0,
		"icoon": "🛍️", "tekst": T_LEEG, "prio": 12})
	if not await na(LEEG_S):
		return
	ctx.ui.wolk_weg(LEEG_ID)
	ctx.sluit()

func _begin() -> void:
	if not await ctx.wacht_op(_gast, PLEK):
		if actief:
			ctx.sluit.call_deferred()
		return
	if not actief or _gast.is_empty():
		return
	_kaart_neer()

## The slots this animal owns something for, in the fixed order.
func sloten() -> Array:
	var uit: Array = []
	for naam in ctx.state.kast_van(_gast):
		var slot := ArtGasten.slot_van(str(naam))
		if not slot.is_empty() and not uit.has(slot):
			uit.append(slot)
	var orde: Array = ArtGasten.SLOTEN
	uit.sort_custom(func(a, b) -> bool: return orde.find(a) < orde.find(b))
	return uit.slice(0, Ui.MAX_KEUZES)

## What the animal wears in `slot` now, "" for nothing.
func draagt(slot: String) -> String:
	for naam in World.accessoires(_gast):
		if ArtGasten.slot_van(str(naam)) == slot:
			return str(naam)
	return ""

func _kaart_neer() -> void:
	if not actief or _gast.is_empty():
		return
	var g: Dictionary = ctx.state.gast_van(_gast)
	var keuzes: Array = []
	for slot in sloten():
		var nu := draagt(str(slot))
		var kl: Dictionary = ArtGasten.KLEDING.get(nu, {})
		var icoon := str(kl.get("icoon", SLOT_ICOON.get(slot, "✨")))
		var woord := T_GEEN if nu.is_empty() else str(kl.get("naam", nu)).split(" ")[-1]
		var s := str(slot)
		keuzes.append({"id": "s_" + s, "icoon": icoon,
			"tekst": woord.substr(0, 1).to_upper() + woord.substr(1), "kort": icoon,
			"titel": "trek iets anders aan", "kies": func(_id, _k) -> void: wissel(s)})
	_kaart = ctx.ui.somkaart({"x": PLEK.x - 16.0, "z": PLEK.y, "kamer": KAMER}, "", {
		"id": KAART_ID, "kamer": KAMER, "hoog": KAART_HOOG, "icoon": "🪞",
		"regel": T_REGEL % str(g.get("naam", "")), "keuzes": keuzes, "dier": _gast,
		"titel": "de paskamer", "keuze_titel": "kies wat het dier draagt"})
	_meld()

## `<id>=<rect>` of the strip, for tools/speel.js (web export only).
func _meld() -> void:
	if not OS.has_feature("web"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not actief:
		return
	var spot := Hits.spot(KAART_ID + "_keuzes")
	if spot != null and is_instance_valid(spot.knoop):
		print("[probe] ", KAART_ID + "_keuzes", "=", (spot.knoop as Control).get_global_rect())
		print("[probe] paskamer draagt=", World.accessoires(_gast))

## One tap on a slot: the next piece of that slot the animal owns, or nothing
## after the last one.
func wissel(slot: String) -> void:
	if _gast.is_empty():
		return
	var eigen: Array = []
	for naam in ctx.state.kast_van(_gast):
		if ArtGasten.slot_van(str(naam)) == slot:
			eigen.append(str(naam))
	if eigen.is_empty():
		return
	var nu := draagt(slot)
	var i := eigen.find(nu)
	var volgende := "" if i == eigen.size() - 1 else str(eigen[i + 1])
	if volgende.is_empty():
		ctx.wereld.accessoire(_gast, nu, false)
	else:
		ctx.wereld.accessoire(_gast, volgende)
	ctx.snd.tik()
	var d = World.dier(_gast)
	if d != null:
		World.pose(_gast, "blijA" if not volgende.is_empty() else "kijk", 8)
		if not volgende.is_empty():
			ctx.wereld.spetter(KAMER, d.x, d.z, ArtEffect.STER_N, ArtEffect.STER_KL[0], true, 14.0)
	State.bewaar()
	_kaart_neer()
