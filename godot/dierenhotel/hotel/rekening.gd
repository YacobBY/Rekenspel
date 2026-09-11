class_name HotelRekening
extends RefCounted
## The bill at checkout, in three steps (world.md §3.5).  Owned by `Econ`.
##
## Everything the child has already done lives in `State.s["rekening"]`, so a
## reload in the middle of a bill resumes it with the counted coins on the
## counter instead of throwing them away — the gap Q-X1-4 asked about,
## closed by architecture.md §9/§13.
##
## `hand` and `bank` are plain arrays of coin values (ints), because that is
## what has to survive a reload; the HTML kept `{v, id}` objects only to have a
## DOM key.
##
## The help ladder is the same in all three steps and it never punishes: a
## wrong answer costs nothing but a softer sound and one more line of help.

const EIGENAAR := "rekening"
const SPOOK_MAX := 6
const AF_S := 1.1          ## the goodbye bubble hangs this long before the callback
const NA_SOM_S := 0.5      ## between the ticked sum and the coins on the counter

signal veranderd()
signal klaar(uit: Dictionary)

func bezig() -> bool:
	return State.s["rekening"] != null

func stand() -> Dictionary:
	var r = State.s["rekening"]
	return r if r != null else {}

# --------------------------------------------------------------- beginnen

## `Econ.rekening({gast, fam, nachten, prijs, totaal, betaald})`.
func begin(o: Dictionary) -> Dictionary:
	var g: Dictionary = o.get("gast", {})
	var nachten := int(o.get("nachten", 1))
	var prijs := int(o.get("prijs", 1))
	var totaal := int(o.get("totaal", nachten * prijs))
	var betaald := int(o.get("betaald", totaal))
	var hand: Array = []
	for v in Sommen.buidel(betaald):
		hand.append(int(v))
	State.s["rekening"] = {
		"gastId": str(g.get("id", "")), "fam": str(o.get("fam", "de familie")),
		"nachten": nachten, "prijs": prijs, "totaal": totaal,
		"stap": 1, "pogingen": 0, "telPog": 0, "wisselPog": 0,
		"hand": hand, "bank": [],
		"t0": Time.get_ticks_msec(), "tw": 0,
	}
	Hotel.naar_kamer("receptie")
	bouw()
	State.bewaar()
	return stand()

## After a reload: the same moment, from the save alone.
func herstel() -> void:
	if not bezig():
		return
	Hotel.naar_kamer("receptie")
	bouw()

func stop() -> void:
	State.s["rekening"] = null
	_wis()

# ------------------------------------------------------------ het antwoord

## Step 1: `nachten × €prijs =`.  `n` is null when the keypad was empty.
func som_ok(n: Variant) -> void:
	var r := stand()
	if r.is_empty() or int(r["stap"]) != 1:
		return
	if n == null:
		_hint("☝", "tik een getal")
		return
	if int(n) == int(r["totaal"]):
		State.tel(int(r["pogingen"]) == 0, Time.get_ticks_msec() - int(r["t0"]))
		r["stap"] = 2
		Snd.ja()
		State.bewaar()
		# the ticked receipt stays under the child's eyes for half a second
		# before the coins appear (econ.js: setTimeout(..., 500))
		await Econ.wacht(NA_SOM_S)
		if int(stand().get("stap", 0)) == 2:
			bouw()
		return
	r["pogingen"] = int(r["pogingen"]) + 1
	Snd.zacht()
	bouw()
	State.bewaar()

## Step 2: one coin moves from the family's purse to the counter.
func leg_neer() -> void:
	var r := stand()
	if r.is_empty() or int(r["stap"]) == 3:
		return
	var hand: Array = r["hand"]
	if hand.is_empty():
		return
	(r["bank"] as Array).append(hand.pop_front())
	Snd.munt()
	bouw()
	if Hotel.scherm_klaar():
		Ui.wolk({"id": "rek_tel", "door": EIGENAAR, "kamer": "receptie",
			"x": _toonbank().get("x", 0.0), "z": _toonbank().get("z", 0.0),
			"hoog": _toonhoog(), "icoon": "🪙", "getal": "€%d" % geteld(),
			"prio": 7})
	State.bewaar()

func geteld() -> int:
	var som := 0
	for v in stand().get("bank", []):
		som += int(v)
	return som

## `✔ klaar` — counted enough, too little, or too much (then step 3).
func klaar_met_tellen() -> void:
	var r := stand()
	if r.is_empty() or int(r["stap"]) != 2:
		return
	var t := geteld()
	var p := int(r["totaal"])
	if t == p:
		await _gelukt(0)
		return
	if t < p:
		# its own counter: a slip on the SUM may not pull the ghost coins of
		# the COUNTING step forward
		r["telPog"] = int(r["telPog"]) + 1
		Snd.zacht()
		bouw()
		if Hotel.scherm_klaar():
			Ui.wolk({"id": "rek_hint", "door": EIGENAAR, "kamer": "receptie",
				"x": _toonbank().get("x", 0.0), "z": _toonbank().get("z", 0.0),
				"hoog": _toonhoog(), "icoon": "🪙", "getal": "+€%d" % (p - t),
				"klas": "hulp", "prio": 9})
		if int(r["telPog"]) >= 3:
			_spook(p - t, "dit moet er nog bij")
		State.bewaar()
		return
	r["stap"] = 3
	r["wisselPog"] = 0
	r["tw"] = Time.get_ticks_msec()
	_spook_weg()
	bouw()
	State.bewaar()

## Step 3: `€betaald − €totaal =`.
func wissel_ok(n: Variant) -> void:
	var r := stand()
	if r.is_empty() or int(r["stap"]) != 3:
		return
	var goed := geteld() - int(r["totaal"])
	if n == null:
		_hint("☝", "tik een getal")
		return
	if int(n) == goed:
		var t0 := int(r["tw"]) if int(r["tw"]) > 0 else int(r["t0"])
		State.tel(int(r["wisselPog"]) == 0, Time.get_ticks_msec() - t0)
		await _gelukt(goed)
		return
	r["wisselPog"] = int(r["wisselPog"]) + 1
	Snd.zacht()
	bouw()
	State.bewaar()

func _gelukt(wissel: int) -> void:
	var r := stand()
	var uit := {
		"totaal": int(r["totaal"]), "betaald": geteld(), "wissel": wissel,
		"pogingen": int(r["pogingen"]) + int(r["telPog"]) + int(r["wisselPog"]),
		"gastId": str(r["gastId"]), "fam": str(r["fam"]),
	}
	var gast := State.gast_van(str(r["gastId"]))
	Snd.tover()
	# The bill leaves the SAVE at once — a reload may never resume a bill that
	# is already paid — but the callback waits.  `klaar` is what makes the hotel
	# take the guest out of `gasten` and re-sync the world, and the 👋 bubble
	# hangs on that very animal: firing both in one frame despawned the guest
	# under its own goodbye (world.md §3.5: bubble, 1100 ms, then the callback).
	State.s["rekening"] = null
	_wis()
	State.bewaar()
	if Hotel.scherm_klaar() and not gast.is_empty():
		Ui.wolk({"id": "rek_af", "door": EIGENAAR, "kamer": "receptie",
			"volg": _volg_gast(str(r["gastId"])), "hoog": 54.0,
			"icoon": "👋", "getal": ("€%d" % wissel) if wissel > 0 else "✔",
			"tekst": "terug" if wissel > 0 else "betaald",
			"klas": "goed", "prio": 12})
	await Econ.wacht(AF_S)
	Hits.weg("rek_af")
	klaar.emit(uit)

# ------------------------------------------------------------- de wereld

## Put the whole moment on the table again.  Called after every step, so the
## card, the counter and the purse always agree with the save.
func bouw() -> void:
	if not Hotel.scherm_klaar():
		veranderd.emit()
		return
	var r := stand()
	if r.is_empty():
		return
	_wis()
	var gast := State.gast_van(str(r["gastId"]))
	if not gast.is_empty():
		# one short line above the animal: the family is here
		Ui.wolk({"id": "rek_gast", "door": EIGENAAR, "kamer": "receptie",
			"volg": _volg_gast(str(r["gastId"])), "hoog": 54.0, "icoon": "👪",
			"tekst": "%s gaat naar huis" % gast.get("naam", "de gast"),
			"klas": "goed", "prio": 8})
	if int(r["stap"]) == 1:
		_som_stap()
	else:
		_munt_stap()
	veranderd.emit()

## The sentence over the bill: who slept, how many nights, and the price.
func bon_zin() -> String:
	var r := stand()
	var gast := State.gast_van(str(r.get("gastId", "")))
	return "%s sliep %s, €%d per nacht" % [gast.get("naam", "de gast"),
		Ui.meervoud(int(r.get("nachten", 1)), "nacht", "nachten"), int(r.get("prijs", 1))]

func _som_stap() -> void:
	var r := stand()
	var kaart := Ui.somkaart(_werkplek(), "%d × €%d =" % [int(r["nachten"]), int(r["prijs"])], {
		"id": "rek_som", "door": EIGENAAR, "kamer": "receptie", "open": true,
		"max": 2, "hoog": _werkhoog(), "icoon": "🛏", "regel": bon_zin(),
		"on_ok": func(n, _k): som_ok(n)})
	# the same ladder everywhere: count along once, count along again, and
	# only at the THIRD attempt do the ghost coins appear
	if int(r["pogingen"]) >= 1:
		kaart.hulp(Econ.tel_mee(int(r["prijs"]), int(r["nachten"])))
	if int(r["pogingen"]) >= 3:
		_spook(int(r["totaal"]), "zoveel is het samen")

func _munt_stap() -> void:
	var r := stand()
	var betaald := geteld()
	# while counting, the ticked receipt stays exactly where the sum was
	if int(r["stap"]) != 3:
		Ui.somkaart(_werkplek(), "%d × €%d = %d" % [int(r["nachten"]), int(r["prijs"]),
				int(r["totaal"])], {
			"id": "rek_bon", "door": EIGENAAR, "kamer": "receptie", "pad": false,
			"hoog": _werkhoog(), "icoon": "🛏", "regel": bon_zin()}).klaar()
	if int(r["stap"]) == 3:
		# the amount paid stays visible as a plain box; depth 200 makes it pick
		# its place first, so the bell steps aside instead of covering the euro
		Hits.maak({"id": "getal_bank", "door": EIGENAAR, "kamer": "receptie",
			"x": _toonbank().get("x", 0.0), "z": _toonbank().get("z", 0.0),
			"y": _toonhoog(), "kind": "tag", "klas": "hotgetal hotbedrag",
			"prio": 13, "d": 200.0, "getal": "€%d" % betaald,
			"titel": "op de toonbank ligt €%d" % betaald})
		_wissel_kaart()
		return
	# the counter: tap or drag the coins here, the amount is written on it
	Hits.maak({"id": "rek_bank", "door": EIGENAAR, "kamer": "receptie",
		"x": _toonbank().get("x", 0.0), "z": _toonbank().get("z", 0.0),
		"y": _toonhoog(), "icoon": "🧾", "label": "€%d" % betaald,
		"getal": "€%d" % betaald, "kind": "drop", "drop": "toonbank",
		"klas": "hotbron", "prio": 11, "titel": "de toonbank",
		"aan": func(_s): leg_neer()})
	# the family's purse: the next coin is shown on it
	var hand: Array = r["hand"]
	var volgende: int = int(hand[0]) if not hand.is_empty() else 0
	var o := {
		"id": "rek_buidel", "door": EIGENAAR, "kamer": "receptie",
		"hoog": _toonhoog(), "x": _boek().get("x", 0.0), "z": _boek().get("z", 0.0),
		"icoon": "🪙" if volgende > 0 else "👍",
		"label": ("€%d" % volgende) if volgende > 0 else "",
		"aantal": ("€%d" % volgende) if volgende > 0 else "",
		"hand": hand.size(), "klas": "" if not hand.is_empty() else "leeg",
		"titel": ("munt van %d euro" % volgende) if volgende > 0 else "de buidel is leeg",
		"prio": 10, "drop_doel": "toonbank",
		"tik": func(): leg_neer(), "aan": func(_s): leg_neer()}
	if Ui.bron("boek", o).is_empty():
		# `Ui.bron` is W3's; until it lands the purse is an ordinary button, so
		# the bill can be played through end to end
		Hits.maak(o)
	# `klaar met tellen` stands next to the counter
	Hits.maak({"id": "rek_ok", "door": EIGENAAR, "kamer": "receptie",
		"x": _plek(0.775, 0.275).get("x", 0.0), "z": _plek(0.775, 0.275).get("z", 0.0),
		"y": Rooms.hoogte("receptie", 0.175), "icoon": "✔", "label": "klaar",
		"klas": "hotwolk goed", "prio": 10, "titel": "klaar met tellen",
		"aan": func(_s): klaar_met_tellen()})

func _wissel_kaart() -> void:
	var r := stand()
	var betaald := geteld()
	var kaart := Ui.somkaart(_werkplek(), "€%d − €%d =" % [betaald, int(r["totaal"])], {
		"id": "rek_wissel", "door": EIGENAAR, "kamer": "receptie", "open": true,
		"max": 2, "hoog": _werkhoog(), "icoon": "👛",
		"regel": "%s gaf €%d, het kost €%d" % [
			State.gast_van(str(r["gastId"])).get("naam", "de gast"), betaald, int(r["totaal"])],
		"on_ok": func(n, _k): wissel_ok(n)})
	if int(r["wisselPog"]) == 1:
		kaart.hulp("%d ▸ %d" % [int(r["totaal"]), betaald])
	if int(r["wisselPog"]) >= 2:
		kaart.hulp(Econ.tel_mee(1, betaald - int(r["totaal"])))
	if int(r["wisselPog"]) >= 3:
		_spook(betaald - int(r["totaal"]), "zoveel krijgt de familie terug")

# ------------------------------------------------------------------ hulpjes

func _hint(icoon: String, tekst: String) -> void:
	if not Hotel.scherm_klaar():
		return
	Ui.wolk({"id": "rek_hint", "door": EIGENAAR, "kamer": "receptie",
		"x": _toonbank().get("x", 0.0), "z": _toonbank().get("z", 0.0),
		"hoog": _toonhoog(), "icoon": icoon, "tekst": tekst, "klas": "hulp",
		"prio": 9})

## Ghost coins on the free floor in front of the desk — never on the card.
## The default title is the one every step shares (world.md §7.8).
func _spook(bedrag: int, label: String = "zo ziet het uit") -> void:
	_spook_weg()
	if not Hotel.scherm_klaar():
		return
	var munten := Sommen.splits(bedrag)
	for i in mini(munten.size(), SPOOK_MAX):
		var p := _plek(0.5 + (i % 3) * 0.1875, 0.875 + (0.075 if i > 2 else 0.0))
		Ui.getal_tag(p, "€%d" % munten[i], {"id": "spook%d" % i, "door": EIGENAAR,
			"y": 4, "klas": "hotspook", "titel": label})

func _spook_weg() -> void:
	for i in SPOOK_MAX:
		Hits.weg("spook%d" % i)

func _wis() -> void:
	Hits.wis_eigenaar(EIGENAAR)
	_spook_weg()

func _volg_gast(id: String) -> Callable:
	return func() -> Dictionary:
		var d = World.dier(id)
		if d == null:
			return {}
		return {"x": d.x, "z": d.z, "kamer": d.kamer,
				"vlak": World.vlak_van_dier(id)}

# Fractions of the room, so a room resize moves the whole desk with it
# (world.md §1.6).  Read at call time: `Rooms` is only filled in its _ready.
func _plek(fx: float, fz: float) -> Dictionary:
	return Rooms.plek("receptie", fx, fz)

## Where the bill's own cards hang: over the desk, beside the counted coins
## (I1 finding 6) — not out on the open floor to the right of it.
func _werkplek() -> Dictionary:
	return _balie_midden()

func _werkhoog() -> int:
	return Rooms.hoogte("receptie", 0.2)

## The counting counter (I1 finding 6).  `plek(0.15, 0.5)` was the old L-shaped
## desk arm; since the receptie was rebuilt along the back-right wall
## (architecture.md §13, Q-X1-13) that spot is open floor, and the coins were
## counted in the middle of the walking line.  The counter is the DESK: the till
## when it stands there — then the coins land on the till and dragging onto it
## works, because the catch area is button plus object — and otherwise the
## middle of the `Kamer.balie` footprint.
func _toonbank() -> Dictionary:
	var kassa := Hotel.decor_plek("receptie", "kassa")
	if not kassa.is_empty():
		return {"kamer": "receptie", "x": kassa["x"], "z": kassa["z"]}
	return _balie_midden()

## The middle of the desk footprint, so a room that changes shape takes the
## counter with it.
func _balie_midden() -> Dictionary:
	var r = Rooms.get_kamer("receptie")
	if r != null and not (r.balie as Dictionary).is_empty():
		return {"kamer": "receptie",
			"x": JsGetal.rond((int(r.balie["x0"]) + int(r.balie["x1"])) / 2.0),
			"z": JsGetal.rond((int(r.balie["z0"]) + int(r.balie["z1"])) / 2.0)}
	return _plek(0.5, 0.1667)

## The desk top: the till, the book and the bell all stand at 14 voxels, so a
## bubble or a tag over the counter hangs just above them.
func _toonhoog() -> int:
	return Rooms.hoogte("receptie", 1.0 / 6.0)

func _boek() -> Dictionary:
	var p := Hotel.decor_plek("receptie", "boek")
	return p if not p.is_empty() else _plek(0.35, 0.35)
