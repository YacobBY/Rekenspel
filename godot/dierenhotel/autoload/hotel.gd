extends Node
## Hotel — the day, the wishes, check-in, the prikbord and the HUD.  Autoload #10.
## Port of `demos/dierenhotel/hotel.js` (world.md §3).
##
## This is the only module that knows what a DAY is.  Everything else answers
## questions: `Rooms` where things stand, `World` where the animals are, `State`
## what is saved, `Econ` what a bill costs.  The hotel decides when a guest
## wants something, who may want it, and what the child sees on the board.
##
## Three rules from HOTEL.md §9 are load-bearing here and are marked in the
## code where they are enforced:
##   * a pictogram NEVER appears without its word (`wens_woord`);
##   * nothing decays and nobody is punished — a waiting animal waits happily;
##   * a star is for taking part, so the hotel gives one for a bed, for feeding,
##     for playing and for a finished bill — never for a right answer.
##
## The board, the bill and the guest bookkeeping live next door:
## `res://hotel/prikbord.gd`, `res://hotel/rekening.gd`, `autoload/state.gd`.

signal hud_veranderd()
signal bord_veranderd()
signal dag_veranderd(dag: int)
signal checkin_veranderd()
signal avond_veranderd()
signal brief_gereed(brief: Dictionary)

## The short word that goes next to the pictogram (world.md §3.2).  An icon
## without a word is unreadable for a six-year-old, so an unknown need falls
## back to its own name and complains exactly once.
const WENSWOORD := {"eten": "eten", "kamer": "bed", "bad": "bad",
	"spelen": "spelen", "zwemmen": "zwemmen", "souvenir": "souvenir"}
## What makes a wish fulfilled: a bed for 🛏, `gegeten` for 🍪, `blij` for the rest.
const WENS_BLIJ := {"bad": 1, "spelen": 1, "zwemmen": 1, "souvenir": 1}
## The wishes the hotel resolves itself — they need no game at all.
const HOTEL_WENS := {"kamer": 1, "eten": 1, "spelen": 1}
## A wave-2 wish that is bound to one fixed game.
const WENS_SPEL := {"bad": "tobbe"}
const NIEUWE_WENS := ["zwemmen", "souvenir"]

const RONDE_NAAM := {"ochtend": "☀️ Ochtendronde", "avond": "🌙 Avondronde",
	"vrij": "🐾 Vrij spelen"}

## world.md §7.8, verbatim.  The letter sheet is drawn by `Ui` (W3), but the
## words are the hotel's: `briefOpMuur` and `brievenMuur` live in `hotel.js`.
## They sit here as constants so the shell has one place to read them from and
## the string test has one place to check.
const POST := {
	"titel": "💌 Er is post!",
	"knop": "Hang de brief op de muur 📌",
	"toast": "💌 Aan de muur!",
}
const BRIEVENMUUR := {
	"titel": "💌 De brievenmuur",
	"uitleg": "Hier komen de bedankjes van de families die hun dier bij jou lieten slapen.",
	"hint": "Laat een gast zijn nachten uitslapen en reken netjes af — dan komt er post.",
	"sluiten": "Sluiten",
}

## Where each room hangs on the map sheet (world.md §6.3).
const KAART := {"receptie": [1, 2], "gang": [2, 2], "kamer1": [2, 1],
	"kamer2": [2, 3], "keuken": [3, 2], "tuin": [4, 2], "wasserij": [3, 3],
	"zwembad": [4, 3]}

const EIGENAAR := "hotel"
const BORD := "bord"
const BORD_LEEG := "Speel lekker rond"
const AVOND := "avond"
const CHECKIN := "checkin"

## The check-in's third step (owner, 2026-09-24: "Je moet bij bellen van het
## dier een kamer voor het dier kiezen"): a room, not a bed.  The beds that room
## needs are the game `bedden` ("Verdeel bedden over de kamers"), which starts
## the moment a room is chosen.  "Welke kamer voor Stampertje?" is 4 words and
## 28 characters on the longest guest name (HOTEL.md §9).
const KAMER_VRAAG := "Welke kamer voor %s?"
const KAMER_TITEL := "kies een kamer"
const BEDDEN_SPEL := "bedden"
## The bell when no bedroom can take one more guest (world.md §7.4).
const BEL_VOL := "alle kamers vol"

var _bord_open := false
var _bord_blad = null          ## the open board sheet (UiBlad), or null
var _dag_bericht: Array = []
var _prikbord: HotelPrikbord = null
var _ci_kaart = null
var _wens_klacht := {}
var _spel_taak: Dictionary = {}
var _herstelt := false         ## busy replaying the furniture: do not save back

func _ready() -> void:
	_prikbord = HotelPrikbord.new()
	_bouw_spel_taak()
	Econ.rekening_klaar.connect(_rekening_klaar)
	# "Boef komt eraan": refreshed with every drawn frame and every room change,
	# and so is "👀 Volg" — a room change that was not the walk's own ends it
	World.getekend.connect(_volg_stap)
	World.getekend.connect(komt_eraan)
	World.kamer_veranderd.connect(func(_k: String) -> void:
		if not _volgt_zelf:
			stop_volgen()
		komt_eraan())
	# every furniture change, whoever made it, lands in the save at once
	Rooms.kamers_veranderd.connect(bewaar_inrichting)

# ------------------------------------------------------------------ opstart

## Called by the shell once the save has been read and the layers registered.
func start() -> void:
	herstel_wereld()
	bouw_taken(true)
	render()
	# No board at the start (owner, 2026-09-23: "laat niet het prikbord zien
	# als start. De gebruiker moet gewoon op de bel drukken"): the morning is
	# the pulsing bell; the board stays behind its button, with its badge.
	if Econ.rekening_bezig():
		Econ.herstel_rekening()          # a bill that was half counted
	elif State.s["checkin"] != null:
		paint_checkin()                  # a half-finished check-in goes first

## Put every guest back where the save says it was.
func herstel_wereld() -> void:
	herstel_inrichting()                 # bought beds and furniture come first
	State.herstel_bedden()               # then every guest in a bed of his own
	World.zet_dag(int(State.s["dag"]))
	World.sync(alle_dieren())
	for g in State.s["gasten"]:
		var id := str(g["id"])
		if not str(g.get("bed", "")).is_empty() and not str(g.get("kamer", "")).is_empty():
			g["waar"] = g["kamer"]
			World.slaap(id, str(g["kamer"]), str(g["bed"]))
		else:
			if str(g.get("waar", "")).is_empty():
				g["waar"] = "receptie"
			var p := plek_van_behoefte(g)
			World.zet(id, str(g["waar"]), p.get("x", 0.0), p.get("z", 0.0))
	var nieuw = State.s["nieuweGast"]
	if nieuw != null:
		nieuw["waar"] = "receptie"
		var np := _balieplek()
		World.zet(str(nieuw["id"]), "receptie", np.get("x", 0.0), np.get("z", 0.0))
	World.naar(str(State.s["kamerNu"]))

## Replay every bought piece of furniture into the rooms (`herstelInrichting`
## of the HTML, world.md §1.8).  `Rooms.herstel()` on its own puts the rooms
## back to their BASE layout, so calling only that would throw away every bed
## and mat the child bought — the beds are the guest cap, so that would also
## silently shrink the hotel on every boot.
##
## The piece keeps its saved id, so `meubelNr` never hands out an id twice; a
## piece whose spot is taken (a room changed shape) is dropped from the save
## instead of being placed somewhere the child did not put it.
func herstel_inrichting() -> void:
	_herstelt = true
	Rooms.herstel()
	Rooms.zet_nr(int(State.s["meubelNr"]))
	var terug: Array = []
	for m in State.s["meubels"]:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var uit := Rooms.meubel_zet(str(m.get("kamer", "")), str(m.get("type", "")),
			float(m.get("x", NAN)), float(m.get("z", NAN)),
			int(m.get("rot", 0)), str(m.get("id", "")))
		if not uit.is_empty():
			terug.append(m)
	_herstelt = false
	State.s["meubels"] = terug
	State.s["meubelNr"] = Rooms.nr_stand()

## Mirror the rooms back into the save.  Hangs on `Rooms.kamers_veranderd`, so
## a game that buys a bed does not have to remember to save it (world.md §4.2).
func bewaar_inrichting() -> void:
	if _herstelt:
		return                            # we are the ones putting them back
	State.s["meubels"] = Rooms.meubels()
	State.s["meubelNr"] = Rooms.nr_stand()
	State.bewaar()

## Is there a button layer to draw on?  Headless (and before the shell has
## registered its layers) the hotel keeps all of its state and draws nothing.
func scherm_klaar() -> bool:
	return Ui.knoplaag != null and is_instance_valid(Ui.knoplaag)

# --------------------------------------------------------------------- HUD

## `Hotel.hud()` writes exactly five texts and nothing else (world.md §3.8).
func hud() -> void:
	hud_veranderd.emit()

## The five texts, so the shell has one place to read them from.
func hud_gegevens() -> Dictionary:
	return {
		"dag": int(State.s["dag"]),
		"munten": int(State.s["munten"]),
		"sterren": int(State.s["sterren"]),
		"brieven": (State.s["brieven"] as Array).size(),
		"ronde": ronde_naam(),
	}

func ronde_naam() -> String:
	return RONDE_NAAM.get(str(State.s["ronde"]), RONDE_NAAM["vrij"])

## The full repaint: the world says where an animal IS, we write that back,
## rebuild the board and lay out the hotel's own buttons.
func render() -> void:
	for g in State.s["gasten"]:
		var d = World.dier(str(g["id"]))
		if d != null:
			g["waar"] = d.kamer
	hud()
	var voor := _prikbord.kaart_afdruk()
	bouw_taken()
	hotspots()
	# is the board open and did something on it change?  Repaint at once, or a
	# card that is already done keeps hanging there.
	if _bord_open and _prikbord.kaart_afdruk() != voor:
		toon_bord()
	bord_veranderd.emit()

func naar_kamer(id: String) -> void:
	if not Rooms.bestaat(id):
		return
	World.naar(id)
	State.s["kamerNu"] = id
	Snd.deur()
	render()

# ------------------------------------------------------------- behoeften

func wens_woord(behoefte: String) -> String:
	if WENSWOORD.has(behoefte):
		return WENSWOORD[behoefte]
	if not _wens_klacht.has(behoefte):
		_wens_klacht[behoefte] = 1
		push_warning('behoefte "%s" heeft geen kort woord in WENSWOORD; het pictogram krijgt nu de naam van de behoefte als label (HOTEL.md §9).' % behoefte)
	return behoefte if not behoefte.is_empty() else "wens"

## Is this guest's wish already fulfilled?  One table, so `wens_af` and the
## wish bubbles can never drift apart.
func behoefte_klaar(g: Dictionary) -> bool:
	var b := str(g.get("behoefte", ""))
	if b == "kamer":
		return not str(g.get("bed", "")).is_empty()
	if b == "eten":
		return bool(g.get("gegeten", false))
	return bool(g.get("blij", false))

## Where does this animal belong with its wish? (world.md §3.2)
func plek_van_behoefte(g: Dictionary) -> Dictionary:
	var b := str(g.get("behoefte", ""))
	var kamer := str(g.get("kamer", ""))
	if b == "kamer" or kamer.is_empty():
		return _plek(0.375, 0.775)
	if b == "eten":
		var bakken := _slots(kamer, "bak")
		if bakken.is_empty():
			return {}
		return {"kamer": kamer, "x": bakken[0].get("sx", 0), "z": bakken[0].get("sz", 0)}
	if b == "bad":
		var t := _slot("tuin", "tobbe")
		if t.is_empty():
			return {}
		return {"kamer": "tuin", "x": int(t.get("x", 0)) - 14, "z": t.get("z", 0)}
	if b == "spelen":
		var m := decor_plek(kamer, "mand")
		if m.is_empty():
			return {}
		return {"kamer": str(m["kamer"]), "x": int(m["x"]) - 12, "z": m["z"]}
	if b == "zwemmen":
		return _zwem_plek(kamer)
	if b == "souvenir":
		var tu = Rooms.get_kamer("tuin")
		if tu != null and "zones" in tu and (tu.zones as Dictionary).has("kraam"):
			var p := _voor_rand("tuin", tu.zones["kraam"], 8)
			if not p.is_empty():
				return p
		return _tuin_plek(106, 58)
	return {}

## The start of the deck, just before the waterline.  The pool comes from
## another ticket; until it exists the animal simply waits in the garden.
func _zwem_plek(van_kamer: String) -> Dictionary:
	var zb = Rooms.get_kamer("zwembad")
	if zb == null or Rooms.pad(van_kamer, "zwembad").is_empty():
		return _tuin_plek(58, 106)
	# the deck BEFORE the waterline (`dek.start`), else just short of the pool
	if (zb.dek as Dictionary).has("start"):
		var st: Vector2 = zb.dek["start"]
		return {"kamer": "zwembad", "x": clampi(int(st.x), 4, zb.w - 4),
				"z": clampi(int(st.y), 4, zb.d - 4)}
	if (zb.bad as Dictionary).has("x0"):
		var bd: Dictionary = zb.bad
		return {"kamer": "zwembad", "x": clampi(int(bd["x0"]) - 6, 4, zb.w - 4),
				"z": clampi(JsGetal.rond((float(bd["z0"]) + float(bd["z1"])) / 2.0),
					4, zb.d - 4)}
	return {"kamer": "zwembad", "x": 12, "z": JsGetal.rond(zb.d / 2.0)}

## A quiet spot in the garden.  `Rooms.vrij_vak` only says whether a cell is
## free, so an occupied one is nudged to the nearest free wander place — the
## fallback for 🏊 and 🎁 as long as the pool and the stall are not there yet.
func _tuin_plek(x: int, z: int) -> Dictionary:
	if Rooms.vrij_vak("tuin", x, z):
		return {"kamer": "tuin", "x": x, "z": z}
	var r = Rooms.get_kamer("tuin")
	if r == null:
		return {"kamer": "tuin", "x": x, "z": z}
	var beste := Vector2(x, z)
	var beste_af := INF
	for cel in r.vrij:
		if not Rooms.vrij_vak("tuin", cel["x"], cel["z"]):
			continue
		var af := absf(float(cel["x"]) - x) + absf(float(cel["z"]) - z)
		if af < beste_af:
			beste_af = af
			beste = Vector2(cel["x"], cel["z"])
	return {"kamer": "tuin", "x": JsGetal.rond(beste.x), "z": JsGetal.rond(beste.y)}

## The point IN FRONT OF a rectangle: the middle of the side that faces the
## middle of the room, a few voxels off it.
func _voor_rand(kamer_id: String, rc: Dictionary, af: int = 8) -> Dictionary:
	var r = Rooms.get_kamer(kamer_id)
	if r == null or rc.is_empty() or not rc.has("x0") or not rc.has("z0"):
		return {}
	var cx := (float(rc["x0"]) + float(rc["x1"])) / 2.0
	var cz := (float(rc["z0"]) + float(rc["z1"])) / 2.0
	var dx := minf(float(rc["x0"]), r.w - float(rc["x1"]))
	var dz := minf(float(rc["z0"]), r.d - float(rc["z1"]))
	var px := 0.0
	var pz := 0.0
	if dx <= dz:
		px = float(rc["x1"]) + af if float(rc["x0"]) <= r.w / 2.0 else float(rc["x0"]) - af
		pz = cz
	else:
		px = cx
		pz = float(rc["z1"]) + af if float(rc["z0"]) <= r.d / 2.0 else float(rc["z0"]) - af
	return {"kamer": kamer_id, "x": JsGetal.rond(clampf(px, 4.0, r.w - 4.0)),
			"z": JsGetal.rond(clampf(pz, 4.0, r.d - 4.0))}

## The animal walks there itself and waits patiently — nothing decays.
func stuur_naar_behoefte(g: Dictionary) -> void:
	var p := plek_van_behoefte(g)
	if p.is_empty():
		return
	g["waar"] = p["kamer"]
	World.reis(str(g["id"]), str(p["kamer"]),
		{"x": p.get("x", 0), "z": p.get("z", 0), "na": "wacht"})

## "Somebody is waiting here": how many guests need something from you in this
## room?  A fulfilled wish does not count, and neither does a wish with nowhere
## to go — otherwise a bubble hangs where nothing can be done.
func wacht_in(kamer_id: String) -> int:
	var n := 0
	for g in State.s["gasten"]:
		if behoefte_klaar(g):
			continue
		var p := plek_van_behoefte(g)
		if not p.is_empty() and str(p["kamer"]) == kamer_id:
			n += 1
	if kamer_id == "receptie" and State.s["nieuweGast"] != null:
		n += 1
	return n

## Every guest in the hotel plus the one standing at the desk.
func alle_dieren() -> Array:
	var l: Array = (State.s["gasten"] as Array).duplicate()
	if State.s["nieuweGast"] != null:
		l.append(State.s["nieuweGast"])
	return l

func gast_bij_id(id: String) -> Dictionary:
	var nieuw = State.s["nieuweGast"]
	if nieuw != null and str(nieuw.get("id", "")) == id:
		return nieuw
	return State.gast_van(id)

## `Hotel.wensAf(gastId, welke)` = `ctx.wereld.behoefteKlaar`.  No star: the
## game hands that out itself with `ctx.taak_klaar`.
func wens_af(gast_id: String, welke: String = "") -> bool:
	var g := gast_bij_id(gast_id)
	if g.is_empty():
		return false
	var b := welke if not welke.is_empty() else str(g.get("behoefte", ""))
	if b == "eten":
		g["gegeten"] = true
	elif WENS_BLIJ.has(b):
		g["blij"] = true
	elif b == "kamer":
		# architecture.md §13 Q-X1-8: only a bed resolves 'kamer', so asking
		# for it from a game is a programming error instead of a silent false.
		push_warning("Hotel.wens_af(%s, 'kamer'): alleen wijs_bed() lost een bed in" % gast_id)
		return false
	Hits.weg("wens_" + str(g["id"]))
	State.bewaar()
	render()
	return true

# --------------------------------------------------------- welke wens mag

func _spel_wil(def: Dictionary, type: String) -> bool:
	var w = def.get("wens", null)
	if w == null:
		return false
	if w is String:
		return w == type
	if w is Array:
		return (w as Array).has(type)
	return false

func _speelbaar(id: String) -> bool:
	var def := Games.definitie(id)
	return not def.is_empty() and not bool(def.get("stub", false)) and Games.ontgrendeld(id)

## A 🏊 or 🎁 bubble can never appear without a game that fulfils it.
func wens_mogelijk(type: String) -> bool:
	if HOTEL_WENS.has(type):
		return true
	if WENS_SPEL.has(type) and _speelbaar(str(WENS_SPEL[type])):
		return true
	for id in Games.lijst():
		if _spel_wil(Games.definitie(id), type) and _speelbaar(id):
			return true
	return false

func bad_mogelijk() -> bool:
	return wens_mogelijk("bad")

## The guest whose turn it is for the tub.  architecture.md §13 Q-X1-7 changes
## the HTML's `gasten[0]` into the wish rotation, so every guest gets a turn.
func bad_gast(ook_als := false) -> Dictionary:
	for g in State.s["gasten"]:
		if str(g.get("behoefte", "")) == "bad" and (ook_als or not g.get("blij", false)):
			return g
	return {}

## `nieuweWensen(badBeurt)` — only ever run from `morgen()` (world.md §3.2).
## Every guest gets every wish in turn, at most one outing a day (two above
## four guests), so 🍪 stays the ordinary morning bubble.
func nieuwe_wensen(bad_beurt: bool) -> Dictionary:
	var uit := {}
	var dag := int(State.s["dag"])
	if posmod(dag, 2) == 0:
		return uit                              # even days belong to the tub
	var kan: Array = []
	for t in NIEUWE_WENS:
		if wens_mogelijk(t):
			kan.append(t)
	if kan.is_empty():
		return uit
	var kies: Array = []
	var gasten: Array = State.s["gasten"]
	for i in gasten.size():
		var g: Dictionary = gasten[i]
		if str(g.get("bed", "")).is_empty():
			continue
		if bad_beurt and i == 0:
			continue
		kies.append(g)
	if kies.is_empty():
		return uit
	var hoeveel := 2 if gasten.size() > 4 else 1
	@warning_ignore("integer_division")
	var beurt := (dag - 1) / 2                  # 0, 1, 2, ...
	var ring := maxi(kies.size(), 2)
	for k in hoeveel:
		var c := beurt * hoeveel + k
		var i := posmod(c, ring)
		if i >= kies.size():
			continue
		var g: Dictionary = kies[i]
		@warning_ignore("integer_division")
		var w: int = posmod(c / ring, kan.size())
		if not uit.has(str(g["id"])):
			uit[str(g["id"])] = kan[w]
	return uit

# ------------------------------------------------------------------- morgen

## world.md §3.1, the eight steps in order.  This is the only place `dag` moves.
func morgen() -> void:
	var b: Array = []
	# yesterday's moon and family bubbles go, or you could tap them again and
	# skip a day without an evening round
	Hits.wis_eigenaar(AVOND)
	bord_dicht()
	State.s["dag"] = int(State.s["dag"]) + 1
	for g in State.s["gasten"]:
		if not str(g.get("bed", "")).is_empty():
			g["geslapen"] = int(g.get("geslapen", 0)) + 1

	# food bookkeeping: the same rhythm as the tested demo, so the check-in
	# question always looks at least two days ahead
	var gebruik := State.dag_verbruik()
	State.s["scoops"] = maxi(0, int(State.s["scoops"]) - gebruik)
	State.s["levering"] = int(State.s["levering"]) - 1
	if int(State.s["levering"]) <= 1:
		State.s["scoops"] = 20 + mini(int(State.s["scoops"]), 4)
		State.s["levering"] = 4
		b.append({"icoon": "📦", "tekst": "voer: %d 🥄" % int(State.s["scoops"])})
	if int(State.s["scoops"]) < gebruik:
		State.s["scoops"] = int(State.s["scoops"]) + 10
		b.append({"icoon": "🩺", "tekst": "Els bracht 10 🥄"})

	# bowls empty, everybody awake, new needs
	for bak in alle_bakken():
		World.zet_bak(str(bak["kamer"]), str(bak["slot"]), 0)
	State.s["kar"] = null
	World.zet_dag(int(State.s["dag"]))
	var bad_beurt := bad_mogelijk() and posmod(int(State.s["dag"]), 2) == 0
	var nieuw := nieuwe_wensen(bad_beurt)
	var gasten: Array = State.s["gasten"]
	for i in gasten.size():
		var g: Dictionary = gasten[i]
		g["gegeten"] = false
		g["blij"] = false
		var heeft_bed := not str(g.get("bed", "")).is_empty()
		g["behoefte"] = "eten" if heeft_bed else "kamer"
		if heeft_bed and bad_beurt and i == 0:
			g["behoefte"] = "bad"
		elif heeft_bed and nieuw.has(str(g["id"])):
			g["behoefte"] = nieuw[str(g["id"])]
		if heeft_bed:
			# getting up happens NEXT to your bed, on the standing place —
			# without it the animal woke up somewhere random in the room
			g["waar"] = g["kamer"]
			var sb := _slot(str(g["kamer"]), str(g["bed"]))
			World.zet(str(g["id"]), str(g["kamer"]),
				sb.get("sx", g.get("x", 0)), sb.get("sz", g.get("z", 0)))
			stuur_naar_behoefte(g)

	var uit: Array = []
	for g in gasten:
		if int(g.get("geslapen", 0)) >= int(g.get("nachten", 2)):
			uit.append(str(g["id"]))
	State.s["uitcheck"] = uit
	if not uit.is_empty():
		var eerste := State.gast_van(str(uit[0]))
		b.append({"icoon": "👪", "tekst": "%s gaat naar huis" % eerste.get("naam", "gast")})

	_dag_bericht = b
	State.s["ronde"] = "ochtend"
	State.s["taken"] = []
	_prikbord.vergeet()
	bouw_taken(true)
	World.zet_ding("balielamp", {"model": "lamp"})
	State.herbereken()
	Snd.dag()
	# a new morning is the receptie with its pulsing bell, not the board
	# (owner, 2026-09-23); the day's news waits on the board behind its button
	naar_kamer("receptie")
	State.bewaar()
	dag_veranderd.emit(int(State.s["dag"]))

func dag_bericht() -> Array:
	return _dag_bericht

# --------------------------------------------------------------- de bel

func bel() -> void:
	if State.s["checkin"] != null:
		paint_checkin()
		Ui.toast("🛎️ Er staat al iemand", "kind")
		return
	# A guest may come while some bedroom can take one more animal: a free bed,
	# or floor for the bed the check-in puts down for him (owner, 2026-09-24).
	if not State.plek_voor_gast():
		_bel_vol()
		return
	bord_dicht()                              # the board closes: now the guest
	var g := State.pak_gast()
	if g.is_empty():
		return
	var geld := Sommen.geld(State.band(), int(State.s["dag"]))
	g["nachten"] = geld["nachten"]
	g["prijs"] = geld["prijs"]
	g["betaald"] = geld["betaald"]
	g["dagIn"] = int(State.s["dag"])
	g["kamer"] = ""
	g["bed"] = ""
	g["waar"] = "receptie"
	g["behoefte"] = "kamer"
	g["geslapen"] = 0
	g["gegeten"] = false
	g["blij"] = false
	State.s["nieuweGast"] = g
	init_checkin(g)
	Snd.ding()
	World.sync(alle_dieren())
	var w := _balieplek()
	World.kom_binnen(str(g["id"]), w.get("x", 66), w.get("z", 44))
	naar_kamer("receptie")
	paint_checkin()
	State.bewaar()
	Ui.toast("%s staat aan de balie! 🔔" % g["naam"], "happy")

## Every bedroom is full: friendly and without reading, one bubble at the bell
## (HOTEL.md §9) — `🛏 <n> alle kamers vol`.
func _bel_vol() -> void:
	Snd.zacht()
	if not scherm_klaar():
		return
	var bp := decor_plek("receptie", "bel")
	Ui.wolk({"id": "bel_vol", "door": "wolk", "kamer": "receptie",
		"x": bp.get("x", 0), "z": bp.get("z", 0), "hoog": 26,
		"icoon": "🛏", "getal": State.max_gasten(),
		"tekst": BEL_VOL, "klas": "hulp", "prio": 12})
	Econ.na(3.2, _wolk_weg.bind("bel_vol"))

## The check-in (world.md §3.3): two gate questions — both frozen sums — then
## the room (step 3) and the beds that room needs (step 4, the game `bedden`).
func init_checkin(g: Dictionary) -> void:
	var samen := State.dag_verbruik()
	var extra := int(g.get("scoops", 0))
	State.s["checkin"] = {
		"gastId": str(g["id"]),
		"samen": samen, "extra": extra, "nieuw": samen + extra,
		"dagen": int(State.s["levering"]), "voorraad": int(State.s["scoops"]),
		"stap": 1, "fouten1": 0, "fouten2": 0, "invoer": "", "keuze": null,
		"weg": false, "t0": Time.get_ticks_msec(), "kamer": "",
	}
	checkin_veranderd.emit()

## "1 schep" versus "2 scheppen": a wrong plural makes a six-year-old read the
## sentence twice (HOTEL.md §9).
func scheppen(n: int) -> String:
	return Ui.meervoud(n, "schep", "scheppen")

func dagen(n: int) -> String:
	return Ui.meervoud(n, "dag", "dagen")

## "Nee geef geen hulp na fouten. Kinderen moeten zelf leren rekenen. Fout
## antwoord kiezen moet niet beloond worden met hulp maar juist een
## teleurgesteld dier" (owner, 2026-09-24).  A slip on either question writes no
## worked example, no product and no hint on the card: the guest at the desk is
## sad for a moment (`Ui.misser`: he goes `sip`, `🔄 Nog een keer` hangs by him
## and the strip is shut for ~1,2 s), a soft sound, and then the SAME question
## with the same four choices.  Nothing is taken away.
func paint_checkin() -> void:
	if _ci_kaart != null:
		_ci_kaart.weg()
		_ci_kaart = null
	Hits.wis_eigenaar(CHECKIN)
	var v = State.s["checkin"]
	if v == null:
		return
	var g := gast_bij_id(str(v["gastId"]))
	if g.is_empty():
		State.s["checkin"] = null
		return
	# Step 4 is the beds game: it hangs its own question at the desk while it
	# runs.  Without it — `⬅ Terug`, a reload — the check-in is back at the room.
	if int(v["stap"]) >= 4:
		if Games.actief() == BEDDEN_SPEL:
			checkin_veranderd.emit()
			return
		v["stap"] = 3
	var kamers: Array[String] = []
	if int(v["stap"]) == 3:
		kamers = State.kamers_met_plek()
		if kamers.is_empty():
			# the floor filled up while he waited (furniture): another day
			_checkin_vol.call_deferred()
			return
	checkin_veranderd.emit()
	if not scherm_klaar():
		return
	# The question hangs at the guest who is asking it, where it stands at the
	# desk (HOTEL.md §9: a card hangs on its object or animal).  It used to
	# hang at the far end of the desk while the guest waited by the bench in
	# the other corner (owner, 2026-09-23: "helemaal niet relevant aan waar de
	# tekst geplaatst is").  It keeps the guest's box free at that spot — not
	# the guest itself, or the card would walk in with it from the door.
	var plek := _balieplek()
	var gid := str(g["id"])
	var volg := _volg_balieplek(gid)
	if int(v["stap"]) == 1:
		# two short lines: what goes out every day, and what this guest eats
		# on top of it — plus the question itself.  Worded as a child counts
		# (owner, 2026-09-23: "De manier om voer scheppen te tellen is ook niet
		# heel duidelijk"): the same "Elke dag" as the second question, and the
		# question asked in words instead of a bare "Samen?".
		var op_ok := func(n, _k) -> void:
			v["invoer"] = "" if n == null else str(n)
			antwoord1()
		_ci_kaart = Ui.somkaart(plek, "%d + %d =" % [int(v["samen"]), int(v["extra"])], {
			"id": "ci_som", "door": CHECKIN, "kamer": "receptie",
			"goed": int(v["nieuw"]), "liever": [int(v["samen"]), int(v["extra"]),
				int(v["samen"]) + int(v["extra"]) + 1],
			"max": 2, "hoog": _ci_hoog(), "icoon": "🥄", "volg": volg, "dier": gid,
			"regel": "Elke dag eten de gasten %s" % scheppen(int(v["samen"])),
			"regel2": "%s wil er %d bij. Hoeveel samen?" % [g["naam"], int(v["extra"])],
			"on_ok": op_ok})
	elif int(v["stap"]) == 2:
		# The first line says what the food is FOR (the days until the next
		# delivery), the second where it is: "in de kast" is a place a child can
		# picture, "in huis" was not (owner, 2026-09-23).  The product is never
		# written out after a slip (owner, 2026-09-24).
		_ci_kaart = Ui.somkaart(plek, "%d × %d" % [int(v["dagen"]), int(v["nieuw"])], {
			"id": "ci_som", "door": CHECKIN, "kamer": "receptie", "pad": false,
			"hoog": _ci_hoog(), "icoon": "🥄", "volg": volg, "dier": gid,
			"regel": "Voer voor %s: elke dag %s" % [dagen(int(v["dagen"])), scheppen(int(v["nieuw"]))],
			"regel2": "📦 In de kast: %s. Genoeg?" % scheppen(int(v["voorraad"])),
			"keuze_titel": "is er genoeg voer?",
			"keuzes": _checkin_keuzes()})
	else:
		# Step 3 — a room, not a bed (owner, 2026-09-24): only the rooms where one
		# more animal still fits, a free bed or floor for a new one.
		_ci_kaart = Ui.somkaart(plek, "", {
			"id": "ci_som", "door": CHECKIN, "kamer": "receptie", "pad": false,
			"hoog": _ci_hoog(), "icoon": "🛏", "volg": volg, "dier": gid,
			"regel": KAMER_VRAAG % g["naam"],
			"keuze_titel": KAMER_TITEL, "keuzes": _kamer_keuzes(kamers)})
	World.vuil()

## The three choices of question 2.  Note the link with the frozen `vergelijk`:
## it compares days × per day WITH the stock, so 'meer' (more is needed) is the
## button that says there is TOO LITTLE food.  The arrows are decoration; the
## word does the work (HOTEL.md §9: pictogram AND word).
func _checkin_keuzes() -> Array:
	return [
		{"id": "meer", "icoon": "⬇", "tekst": "te weinig", "kort": "weinig",
			"kies": func(k): antwoord2(str(k))},
		{"id": "precies", "icoon": "⚖", "tekst": "precies", "kort": "precies",
			"kies": func(k): antwoord2(str(k))},
		{"id": "minder", "icoon": "⬆", "tekst": "blijft over", "kort": "over",
			"kies": func(k): antwoord2(str(k))},
	]

## The rooms of step 3, one button each: "🛏 Kamer 1" (short: "🛏 1").
func _kamer_keuzes(kamers: Array) -> Array:
	var uit: Array = []
	for k in kamers:
		var kid := str(k)
		var r = Rooms.get_kamer(kid)
		var naam: String = str(r.naam) if r != null else kid
		var kort: String = naam.get_slice(" ", naam.get_slice_count(" ") - 1)
		uit.append({"id": kid, "icoon": "🛏", "tekst": naam, "kort": kort, "titel": naam,
			"kies": func(_id) -> void: kies_kamer(kid)})
	return uit

## In a LOW frame the card and its choice strip must fit under each other;
## one height step is 2k screen pixels (world.md §5.5).
func _ci_hoog() -> int:
	var basis := Rooms.hoogte("receptie", 0.2)
	var h := World.kader_rect().size.y
	if h >= 300.0 or h <= 0.0:
		return basis
	var k := float(World.schaal().get("k", 1.0))
	return basis + int(ceil(20.0 / (2.0 * maxf(0.01, k))))

func antwoord1() -> void:
	var v = State.s["checkin"]
	if v == null:
		return
	if str(v["invoer"]).is_empty():
		Ui.toast("👆 Tik eerst een getal", "kind")
		return
	if int(str(v["invoer"])) == int(v["nieuw"]):
		v["stap"] = 2
		v["invoer"] = ""
		paint_checkin()
		Snd.ja()
		Ui.toast("Precies! 🎉", "happy")
		State.tel(int(v["fouten1"]) == 0, Time.get_ticks_msec() - int(v["t0"]))
	else:
		v["fouten1"] = int(v["fouten1"]) + 1
		v["invoer"] = ""
		_teleurgesteld(str(v["gastId"]))
	State.bewaar()

func antwoord2(keus: String) -> void:
	var v = State.s["checkin"]
	if v == null:
		return
	var goed := Sommen.vergelijk(int(v["dagen"]), int(v["nieuw"]), int(v["voorraad"]))
	if keus == goed:
		v["stap"] = 3
		paint_checkin()
		Snd.ja()
		Ui.toast("Goed gerekend! 🎉", "happy")
		State.tel(int(v["fouten2"]) == 0, Time.get_ticks_msec() - int(v["t0"]))
	else:
		v["fouten2"] = int(v["fouten2"]) + 1
		_teleurgesteld(str(v["gastId"]))
	State.bewaar()

## A slip at the desk: the card stays as it is — no help line, no product, no
## toast with the answer — and the guest shows it (`Ui.misser`, S5; a number
## strip has already called it itself, a second call does nothing).  A sad pose
## cuts a walk short, so afterwards he steps back to his place at the desk.
func _teleurgesteld(gast_id: String) -> void:
	Snd.zacht()
	# only on the card that is really up (headless there is none, and a handle
	# from an earlier check-in may still be lying about)
	if not scherm_klaar() or _ci_kaart == null or Hits.spot(str(_ci_kaart.id)) == null:
		return
	Ui.misser(_ci_kaart, gast_id)
	Econ.na(Ui.MIS_PAUZE + 0.4, _naar_balie.bind(gast_id))

## Back to his place at the desk, when he stands somewhere else in the receptie
## and no game has him.
func _naar_balie(gast_id: String) -> void:
	var v = State.s["checkin"]
	var d = World.dier(gast_id)
	if v == null or str(v["gastId"]) != gast_id or d == null or d.kamer != "receptie" \
			or not Games.actief().is_empty() or not (d.punten as Array).is_empty():
		return
	var p := _balieplek()
	if Vector2(d.x, d.z).distance_to(Vector2(float(p["x"]), float(p["z"]))) > 3.0:
		World.ga(gast_id, float(p["x"]), float(p["z"]), "wacht")

# ------------------------------------------------------------ de kamer kiezen

## A room was chosen for the guest at the desk: step 4, and the beds game
## "Verdeel bedden over de kamers" (`games/bedden`, games-a.md §3) starts at the
## desk for this guest and this room.  A registry without that game (a narrowed
## test) does not leave the check-in stuck: he gets the room's free bed, or a
## new one, at once.
func kies_kamer(kamer_id: String) -> bool:
	var v = State.s["checkin"]
	if v == null or int(v["stap"]) != 3:
		return false
	if State.plek_in(kamer_id) <= 0:
		paint_checkin()               # out of date: offer what fits now
		return false
	v["kamer"] = kamer_id
	v["stap"] = 4
	if _ci_kaart != null:
		_ci_kaart.weg()
		_ci_kaart = null
	Hits.wis_eigenaar(CHECKIN)
	State.bewaar()
	checkin_veranderd.emit()
	if not Games.definitie(BEDDEN_SPEL).is_empty() and Games.start(BEDDEN_SPEL):
		return true
	return _bed_zonder_spel(kamer_id)

func _bed_zonder_spel(kamer_id: String) -> bool:
	var slot := str(State.bed_vrij(kamer_id).get("slot", ""))
	if slot.is_empty():
		var p := State.bed_plek(kamer_id)
		if not p.is_empty():
			slot = str(World.voeg_bed(kamer_id, {"x": p["x"], "z": p["z"]}).get("id", ""))
	if slot.is_empty() or not wijs_bed(kamer_id, slot):
		checkin_terug()
		return false
	return true

## The beds game stopped before the room had its beds (`⬅ Terug`, another game
## started): the check-in is not over.  The guest comes back to his place at the
## desk and waits there, and the room question is up again — never a guest lost,
## never a check-in that cannot go on (owner, 2026-09-24).
func checkin_terug() -> void:
	var v = State.s["checkin"]
	if v == null:
		return
	if int(v["stap"]) >= 4:
		v["stap"] = 3
	var gid := str(v["gastId"])
	var d = World.dier(gid)
	if d != null:
		var p := _balieplek()
		if d.kamer != "receptie":
			World.reis(gid, "receptie", {"x": p["x"], "z": p["z"], "na": "wacht"})
		elif Vector2(d.x, d.z).distance_to(Vector2(float(p["x"]), float(p["z"]))) > 3.0:
			World.ga(gid, float(p["x"]), float(p["z"]), "wacht")
	State.bewaar()
	paint_checkin()

## No bedroom can take him any more (the floor filled up with furniture while he
## waited): he goes back to the front of the waiting list — not lost — and the
## bell says why.
func _checkin_vol() -> void:
	var v = State.s["checkin"]
	var nieuw = State.s["nieuweGast"]
	if v == null or not State.kamers_met_plek().is_empty():
		return
	if _ci_kaart != null:
		_ci_kaart.weg()
		_ci_kaart = null
	Hits.wis_eigenaar(CHECKIN)
	State.s["checkin"] = null
	if nieuw != null:
		(State.s["wachtlijst"] as Array).push_front(nieuw)
		State.s["nieuweGast"] = null
	World.sync(alle_dieren())
	State.bewaar()
	checkin_veranderd.emit()
	_bel_vol()
	render()

# ------------------------------------------------------------ het bed geven

## The end of the check-in: a bed, a star for taking part, and the round flips
## from `ochtend` to `vrij`.  The beds game calls it the moment the child gave
## the room the right number of beds, with `o.loop`: the guest WALKS to his bed
## while the camera walks along, and the game says "<naam> doet een dutje" once
## he lies in it.  Without `o.loop` the camera goes to the room at once.
func wijs_bed(kamer_id: String, slot_id: String, o: Dictionary = {}) -> bool:
	var v = State.s["checkin"]
	if v == null or int(v["stap"]) < 3:
		return false
	var g := gast_bij_id(str(v["gastId"]))
	if g.is_empty():
		return false
	if not State.gast_in_bed(kamer_id, slot_id).is_empty():
		Ui.toast("💤 Hier slaapt iemand", "kind")
		return false
	var loop := bool(o.get("loop", false))
	g["kamer"] = kamer_id
	g["bed"] = slot_id
	var nieuw = State.s["nieuweGast"]
	if nieuw != null and str(nieuw["id"]) == str(g["id"]):
		(State.s["gasten"] as Array).append(g)
		State.s["nieuweGast"] = null
	State.herbereken()
	World.sync(alle_dieren())
	World.slaap(str(g["id"]), kamer_id, slot_id)
	g["waar"] = kamer_id
	g["behoefte"] = "eten"
	g["gegeten"] = false
	State.s["checkin"] = null
	Hits.wis_eigenaar(CHECKIN)
	_ci_kaart = null
	Snd.tover()
	Econ.sterren(1, "checkin")
	taak_af("bed")
	if str(State.s["ronde"]) == "ochtend":
		State.s["ronde"] = "vrij"
	State.bewaar()
	if loop:
		render()
	else:
		naar_kamer(kamer_id)
	checkin_veranderd.emit()
	if scherm_klaar() and not loop:
		Ui.wolk({"id": "ci_af", "door": "wolk", "kamer": kamer_id,
			"volg": _volg_dier(str(g["id"])), "hoog": 54, "icoon": "💤",
			"tekst": "%s doet een dutje" % g["naam"], "klas": "goed", "prio": 12})
		Econ.na(3.6, _wolk_weg.bind("ci_af"))
	return true

## One bubble away plus a redraw — as a method, so it can be `bind`-ed into a
## delay without a multi-line closure.
func _wolk_weg(id: String) -> void:
	Ui.wolk_weg(id)
	World.vuil()

# ------------------------------------------------------------ eten en spelen

## A full bowl feeds ALL guests of that room.  A guest waiting for 🛁/🏊/🎁
## keeps its own wish: it got that wish because a game exists for it, and the
## child should not lose it by filling the bowl first.
func tik_bak(kamer_id: String, slot_id: String) -> void:
	var niveau := _bak_stand(kamer_id, slot_id)
	var gasten: Array = []
	for g in State.s["gasten"]:
		if str(g.get("kamer", "")) == kamer_id:
			gasten.append(g)
	if niveau > 0:
		if gasten.is_empty():
			return
		var ids: Array = []
		for g in gasten:
			g["gegeten"] = true
			var b := str(g.get("behoefte", ""))
			if b.is_empty() or b == "eten":
				g["behoefte"] = "spelen"
			ids.append(str(g["id"]))
		World.feed(ids)
		Ui.toast("Smakelijk eten! 😋", "happy")
		Econ.sterren(1, "voeren")
		taak_af("voer")
		State.bewaar()
		render()
		return
	if gasten.is_empty():
		Ui.toast("🍽 Hier slaapt niemand", "kind")
		return
	Ui.toast("🍪 Vul eerst de voerkar", "kind")

## The play basket: the animal runs to it and dances.
func tik_mand(kamer_id: String) -> void:
	var mp := decor_plek(kamer_id, "mand")
	var hier: Array = []
	for g in State.s["gasten"]:
		if str(g.get("kamer", "")) == kamer_id and str(g.get("behoefte", "")) == "spelen" \
				and not g.get("blij", false):
			hier.append(g)
	if hier.is_empty():
		Ui.toast("🧶 Straks samen spelen", "kind")
		return
	for i in hier.size():
		var g: Dictionary = hier[i]
		g["blij"] = true
		g["waar"] = kamer_id
		if not mp.is_empty():
			_speel_mee(str(g["id"]), int(mp["x"]) - 12 - i * 4,
				int(mp["z"]) + (6 if i % 2 == 1 else -6))
		else:
			World.solo(str(g["id"]), "Spelen")
	Econ.sterren(1, "spelen")
	taak_af("spelen")
	State.bewaar()
	if hier.size() == 1:
		Ui.toast("%s speelt met het balletje! 🧶" % hier[0]["naam"], "happy")
	else:
		Ui.toast("Ze spelen allemaal met het balletje! 🧶", "happy")
	render()

## Run to the play basket and bounce there.  The end state `blij` is what the
## arrival gives, and `mood("bouncy")` on TOP of it is what raises the animal's
## `wandel_kans` by 0.06 (world.md §2.6) — set before the walk it would break
## off the very order it was just given, so it waits for the walk to resolve.
## A `false` means another order took over; then the animal is not ours.
func _speel_mee(id: String, x: float, z: float) -> void:
	if await World.loop_naar(id, x, z, {"na": "blij"}):
		World.mood(id, "bouncy")

# ------------------------------------------------------------- het prikbord

## Game chips for the board (world.md §3.7).  A game says for itself when it
## belongs there; when it says nothing the default table below applies.
func spel_taken() -> Array:
	var uit: Array = []
	for id in Games.lijst():
		var def := Games.definitie(id)
		var t = def["taak"] if def.has("taak") else _spel_taak.get(id, null)
		if t == null or typeof(t) != TYPE_DICTIONARY:
			continue
		if not Games.ontgrendeld(id) or bool(def.get("stub", false)):
			continue
		# a card that leads to a game with nothing to do is an action that
		# cannot be carried out either (owner, 2026-09-23)
		if not Games.speelbaar_nu(id):
			continue
		var aan := true
		var wanneer = t.get("wanneer", null)
		if wanneer is Callable:
			aan = bool(wanneer.call(State.s))
		if not aan:
			continue
		var tekst = t.get("tekst", def.get("naam", id))
		if tekst is Callable:
			tekst = tekst.call(State.s)
		var prio = t.get("prio", HotelPrikbord.LAAG)
		if prio is Callable:          # hinkel: 2 while a guest wants to play, else 5
			prio = prio.call(State.s)
		uit.append({
			"id": str(t.get("id", id)), "spel": id,
			"icoon": str(t.get("icoon", "✨")), "tekst": str(tekst),
			"kamer": str(t.get("kamer", def.get("kamer", ""))),
			"actie": "game:" + id,
			"prio": int(prio), "klaar": false,
		})
	return uit

## The default board card per wave-2 game (world.md §3.7).  Built in `_ready`
## because a Dictionary constant cannot hold a Callable.
func _bouw_spel_taak() -> void:
	_spel_taak = {
		"voerkar": null,                     # already has its own 'voer' card
		"tobbe": {"id": "bad", "prio": 1, "icoon": "🛁",
			"wanneer": _wanneer_bad, "tekst": _tekst_bad},
		# `bedden` has no card of its own any more: it is step 4 of the check-in
		# and starts from the room question at the desk (owner, 2026-09-24)
		"bedden": null,
		"sleutels": {"icoon": "🔑", "tekst": "Hang de sleutels op",
			"wanneer": _wanneer_twee_gasten},
		"meubels": {"icoon": "📖", "tekst": "Koop iets moois",
			"wanneer": _wanneer_vijf_munten},
	}

func _wanneer_bad(_s: Dictionary) -> bool:
	return not bad_gast().is_empty()

func _tekst_bad(_s: Dictionary) -> String:
	var g := bad_gast(true)
	return "%s wil in bad" % g["naam"] if not g.is_empty() else "Tobbe-tijd"

func _wanneer_twee_gasten(s: Dictionary) -> bool:
	return (s["gasten"] as Array).size() >= 2

func _wanneer_vijf_munten(s: Dictionary) -> bool:
	return int(s["munten"]) >= 5

func bouw_taken(forceer := false) -> Array:
	return _prikbord.bouw(forceer)

func open_taken() -> int:
	return _prikbord.open_taken()

## `Hotel.taakAf(id)` — tick a card by task id OR by game id.
func taak_af(id: String) -> bool:
	var raak := _prikbord.taak_af(id)
	if raak and _bord_open:
		toon_bord()
	if raak:
		bord_veranderd.emit()
	return raak

## Tapping a card: the board closes, the round becomes free play, we travel to
## its room and then run its action.
func doe_taak(q: Dictionary) -> void:
	bord_dicht()
	State.s["ronde"] = "vrij"
	var kamer := str(q.get("kamer", ""))
	if not kamer.is_empty():
		naar_kamer(kamer)
	var actie := str(q.get("actie", ""))
	if actie == "bel":
		if (State.s["gasten"] as Array).is_empty() or State.plek_voor_gast():
			bel()
	elif actie == "avond":
		avondronde()
	elif actie.begins_with("game:"):
		Games.start(actie.substr(5))
	render()

func prikbord() -> void:
	bouw_taken()
	_bord_open = true
	toon_bord()
	bord_veranderd.emit()

## The board opens with the prikbord hotspot or the `📋 Prikbord` button.
func bord_open() -> void:
	prikbord()

## The bell, a card, the evening round and every game that starts close the
## board — and so does the child, with `Sluiten` or a tap beside the sheet.
func bord_dicht() -> bool:
	if not _bord_open:
		return false
	_bord_open = false
	Hits.wis_eigenaar(BORD)
	if _bord_blad != null:
		var blad = _bord_blad
		_bord_blad = null             # it is us closing it, not the child
		if is_instance_valid(blad):
			Ui.blad_dicht_als(blad)
	World.vuil()
	bord_veranderd.emit()
	return true

func bord_is_open() -> bool:
	return _bord_open

## The sheet the board was waiting for has closed; `Ui` forgets it only after
## this signal, so the board opens one step later.
func _na_ander_blad() -> void:
	toon_bord.call_deferred()

func prikbord_tik() -> void:
	if _bord_open:
		bord_dicht()
		return
	prikbord()

## The board is a sheet: today's cards pinned on cork, each naming its room,
## and under them at most two day messages (world.md §3.7).
##
## OWNER, 2026-09-23: "Plaatjes als [de receptie met het open bord] zijn veel te
## druk in iconen. en wekker zetten is bijvoorbeeld helemaal niet relevant aan
## waar de tekst geplaatst is".  The cards used to be bubbles in the receptie,
## hung round the little board wherever the band grid had room, and a card is
## about a room somewhere else in the hotel — "⏰ Wekker zetten" on the floor by
## the corridor door read as if that door were the clock.  So nothing of the
## board hangs in the world any more; the 📋 button on the board and its badge
## stay.  Built again (`stil`, no pop-in) when a card changes while it is open.
func toon_bord() -> void:
	Hits.wis_eigenaar(BORD)
	if not _bord_open or not scherm_klaar():
		return
	# Another sheet is up — the start screen that must be answered first, a
	# letter — and the board never pushes it away: it opens when that one
	# closes.
	var ander := Ui.huidig_blad()
	if ander != null and ander != _bord_blad:
		if not ander.gesloten.is_connected(_na_ander_blad):
			ander.gesloten.connect(_na_ander_blad, CONNECT_ONE_SHOT)
		return
	var kaarten: Array = (State.s["taken"] as Array).duplicate()
	if kaarten.is_empty():
		kaarten = [{"id": "leeg", "leeg": true, "icoon": "🐾", "tekst": BORD_LEEG}]
	var stil := _bord_blad != null
	_bord_blad = null                 # replaced, not closed by the child
	var blad = Ui.prikbord_blad(kaarten, _dag_bericht.slice(0, 2), doe_taak, stil)
	_bord_blad = blad
	if blad == null:
		return
	blad.gesloten.connect(func() -> void:
		if _bord_blad == blad:        # the child closed it
			_bord_blad = null
			bord_dicht())

# ------------------------------------------------------------- de avondronde

func avond_klaar() -> bool:
	return not (State.s["uitcheck"] as Array).is_empty()

func avondronde() -> void:
	State.s["ronde"] = "avond"
	World.zet_ding("balielamp", {"model": "lampaan"})
	bord_dicht()
	naar_kamer("receptie")
	toon_avond()
	avond_veranderd.emit()

## At the desk stands the family (one bubble per departing guest) or the lamp
## with "Morgen ▸".  No written day summary: the numbers are already in the bar.
func toon_avond() -> void:
	Hits.wis_eigenaar(AVOND)
	if str(State.s["ronde"]) != "avond" or not scherm_klaar():
		return
	var uit: Array = []
	for id in State.s["uitcheck"]:
		var g := State.gast_van(str(id))
		if not g.is_empty():
			uit.append(g)
	if not uit.is_empty():
		for i in mini(3, uit.size()):
			var g: Dictionary = uit[i]
			Ui.wolk({"id": "av_" + str(g["id"]), "door": AVOND, "kamer": "receptie",
				# the family waits AT the desk, where its animal comes to be
				# checked out — not in the middle of the floor
				"x": _balieplek(i).get("x", 66), "z": _balieplek(i).get("z", 44),
				"hoog": 0, "prio": 11,
				"icoon": "👪", "tekst": str(g["naam"]),
				"tik": func(): reken_af(str(g["id"]))})
	else:
		# architecture.md §13 Q-X1-9: the desk lamp and the bar button must
		# agree, so with nobody to check out the lamp offers the next day.
		var lp := decor_plek("receptie", "balielamp")
		Ui.wolk({"id": "av_morgen", "door": AVOND, "kamer": "receptie",
			"x": lp.get("x", 0), "z": lp.get("z", 0), "hoog": 24, "prio": 11,
			"icoon": "🌙", "tekst": "Morgen ▸",
			"tik": func(): morgen()})
	World.vuil()

## Start the bill for one guest.  The guest walks to the desk itself: its
## family is waiting there.
func reken_af(id: String) -> void:
	var g := State.gast_van(id)
	if g.is_empty():
		return
	Hits.wis_eigenaar(AVOND)
	if str(g.get("waar", "")) != "receptie":
		g["waar"] = "receptie"
		var w := _balieplek()
		World.reis(str(g["id"]), "receptie",
			{"x": w.get("x", 24), "z": w.get("z", 114), "na": "wacht"})
	var fam: String = State.FAMILIES[posmod(int(State.s["famIdx"]), State.FAMILIES.size())]
	var nachten := int(g.get("nachten", 2))
	var prijs := int(g.get("prijs", 1))
	var betaald := int(g.get("betaald", 0))
	if betaald <= 0:
		betaald = int(Sommen.geld(State.band(), int(State.s["dag"]), nachten, prijs)["betaald"])
	Econ.rekening({"gast": g, "fam": fam, "nachten": nachten, "prijs": prijs,
		"totaal": nachten * prijs, "betaald": betaald})

## The bill is finished: coins, a star, a letter, the guest goes home.
func _rekening_klaar(uit: Dictionary) -> void:
	var id := str(uit.get("gastId", ""))
	var g := State.gast_van(id)
	Econ.geef_munt(int(uit.get("totaal", 0)))
	Econ.sterren(1, "rekening")
	var brief := State.nieuwe_brief(g if not g.is_empty() else {"naam": "de gast"})
	(State.s["brieven"] as Array).append(brief)
	var over: Array = []
	for q in State.s["gasten"]:
		if str(q["id"]) != id:
			over.append(q)
	State.s["gasten"] = over
	var uitcheck: Array = []
	for q in State.s["uitcheck"]:
		if str(q) != id:
			uitcheck.append(q)
	State.s["uitcheck"] = uitcheck
	State.herbereken()
	World.sync(alle_dieren())
	taak_af("uit")
	State.bewaar()
	brief_op_muur(brief)
	toon_avond()
	render()

# ------------------------------------------------------------------ brieven

## `briefOpMuur(brief)` — the sheet with the fresh thank-you letter and the one
## button under it.  The shell draws `POST.titel`, the letter and `POST.knop`;
## confirming calls `brief_opgehangen()` (world.md §3.6, §7.8).
func brief_op_muur(brief: Dictionary) -> void:
	Snd.brief()
	brief_gereed.emit(brief)

## The child hung the letter on the wall.
func brief_opgehangen() -> void:
	Ui.toast(POST["toast"], "happy")
	render()

## `brievenMuur()` — everything the letter wall sheet needs, in one dictionary.
## With no letters yet it explains how to earn one instead of showing a blank.
func brievenmuur() -> Dictionary:
	var brieven: Array = State.s["brieven"]
	return {
		"titel": BRIEVENMUUR["titel"],
		"brieven": brieven.duplicate(true),
		"uitleg": BRIEVENMUUR["uitleg"],
		"hint": BRIEVENMUUR["hint"] if brieven.is_empty() else "",
		"sluiten": BRIEVENMUUR["sluiten"],
	}

# --------------------------------------------------------------- hotspots

# ------------------------------------------------------------- komt eraan

const KOMT := "komt"           ## owner of the "X komt eraan" bubbles
const DIER_ICOON := {"hond": "🐶", "poes": "🐱", "konijn": "🐰", "gans": "🦆"}
var _komt: Dictionary = {}     ## guest id -> spot id of its bubble

## A guest walking in from a room you cannot see — back to the desk, or on his
## way to a wish — gets a bubble at the door he will come through, with his
## pictogram, his name and a bar that fills until he steps into view (owner,
## 2026-09-14).  Gone the moment he is in the room.  Owned by the hotel, so a
## game's `wis_alles` and the hotel's own `render()` leave it alone.
##
## While a game runs every hotel button steps aside (`Hits` voorrang), but the
## bubble of the animal that game waits for (`ctx.wacht_op`) stays: it is
## marked `data.spel` with the running game, and its `👀 Volg` walks along with
## him into the game's room (owner, 2026-09-23: "Bij het zwembad is er geen
## volg optie om boef aan te komen tenzij ik eerst op 'terug' druk").
func komt_eraan() -> void:
	if not scherm_klaar():
		return
	var nu := World.kamer_nu()
	var spel := Games.actief()
	var gezien := {}
	for id in World.onderweg_naar(nu):
		var d = World.dier(id)
		if d == null:
			continue
		gezien[id] = true
		var voor: String = spel if not spel.is_empty() and Games.verwacht_dier(id) else ""
		var f := World.reis_voortgang(id)
		var sid: String = "%s_%s" % [KOMT, id]
		var s := Hits.spot(sid)
		if s != null and is_instance_valid(s.knoop):
			(s.knoop as UiWolk).zet_voortgang(f)
			s.data["spel"] = voor
			continue
		var dp := Rooms.deur(nu, World.reis_van(id))
		var gast: String = id
		Ui.wolk({"id": sid, "door": KOMT, "kamer": nu,
			"x": float(dp.get("ix", 20.0)), "z": float(dp.get("iz", 20.0)), "hoog": 30,
			"icoon": str(DIER_ICOON.get(str(d.kind), "🐾")),
			"tekst": "%s komt eraan" % str(d.naam), "voortgang": f, "prio": 8,
			"klas": "komt", "titel": "Volg %s" % str(d.naam), "knop": VOLG_KNOP,
			"tik": func(_s): volg(gast)})
		var nieuw := Hits.spot(sid)
		if nieuw != null:
			nieuw.data["spel"] = voor
		_komt[id] = sid
	for id in _komt.keys():
		if not gezien.has(id):
			Hits.weg(_komt[id])
			_komt.erase(id)

# ------------------------------------------------------------------ volgen

const VOLG_KNOP := "👀 Volg"
const VOLG_TEKEN := "👀"       ## on the name plate of the guest you walk along with
var _volg_id := ""             ## that guest, or ""
var _volgt_zelf := false       ## the walk switches rooms itself: that is no "stop"
var _volg_beurt := -1          ## the game start the walk belongs to (`Games.beurt`), -1 outside a game

## "👀 Volg" on a "komt eraan" bubble (owner, 2026-09-23): the camera goes to
## the guest and walks along with him, room by room through the doors, until
## he is in the room he was heading for — which is where you were looking.
## Choosing a room yourself, or a game that starts, ends the walk.
##
## While a game runs, only the animal that game waits for may be followed
## (`Games.verwacht_dier`, owner 2026-09-23: "Bij het zwembad is er geen volg
## optie om boef aan te komen tenzij ik eerst op 'terug' druk"): the walk ends
## in the game's room, where the game then begins, and it ends with the game.
func volg(id: String) -> void:
	var d = World.dier(id)
	if d == null or d.reis_doel == "":
		return
	var spel := not Games.actief().is_empty()
	if spel and not Games.verwacht_dier(id):
		return
	if _volg_id != id:
		stop_volgen()
	_volg_id = id
	_volg_beurt = Games.beurt() if spel else -1
	Ui.zet_plaat_teken(id, VOLG_TEKEN)
	_volg_stap()

## The guest the camera walks along with, or "".
func volgt() -> String:
	return _volg_id

## `terug`: a walk along during a game that ends before he is in the game's
## room — the guest gone, or no longer awaited — brings the camera back there,
## so the child is never left in a room whose doors the game hides.
func stop_volgen(terug := false) -> void:
	if _volg_id.is_empty():
		return
	Ui.zet_plaat_teken(_volg_id, "")
	_volg_id = ""
	var beurt := _volg_beurt
	_volg_beurt = -1
	if not terug or beurt < 0 or Games.actief().is_empty() or Games.beurt() != beurt:
		return
	var kamer := Games.actieve_kamer()
	if Rooms.bestaat(kamer) and kamer != World.kamer_nu():
		naar_kamer(kamer)

## May the walk go on?  Outside a game: as long as no game runs.  During one:
## as long as that start runs and still waits for him.
func _volg_mag() -> bool:
	if _volg_beurt < 0:
		return Games.actief().is_empty()
	return not Games.actief().is_empty() and Games.beurt() == _volg_beurt \
		and Games.verwacht_dier(_volg_id)

## Every drawn frame: has the guest gone through a door?  Then the camera goes
## through it too — the same room change as tapping that door, sound and all.
## In the room he was heading for, the walk is done.
func _volg_stap() -> void:
	if _volg_id.is_empty():
		return
	var d = World.dier(_volg_id)
	if d == null or not _volg_mag():
		stop_volgen(true)
		return
	if d.kamer != World.kamer_nu():
		_volgt_zelf = true
		naar_kamer(d.kamer)
		_volgt_zelf = false
	if d.reis_doel == "":
		stop_volgen(true)

## Every button the hotel itself owns, laid out again after each render.
func hotspots() -> void:
	Hits.wis_eigenaar(EIGENAAR)
	if not scherm_klaar():
		return
	var nu := World.kamer_nu()
	var r = Rooms.get_kamer(nu)
	if r == null:
		return
	for dp in _deur_punten(r):
		var doel = Rooms.get_kamer(str(dp.get("naar", "")))
		if doel == null:
			continue
		var w := wacht_in(str(dp["naar"]))
		var naar := str(dp["naar"])
		# The door opening is its object (I1 finding 5): the button hangs beside
		# the hole instead of over it, and `Hits.dekking` measures something.
		# `prio` 11, above the bell, the board and its task cards (10): a door
		# sign has one right place, in front of its door, and the cards the
		# board spreads over the room float anyway — the third one used to take
		# the floor in front of the receptie's gang door and push the sign up
		# onto the wall (owner, 2026-09-23).
		Hits.maak({"id": "deur_%s_%s" % [nu, naar], "door": EIGENAAR, "kamer": nu,
			"x": dp.get("x", 0), "z": dp.get("z", 0), "y": 9,
			"icoon": doel.icoon, "label": doel.naam,
			"titel": "Ga naar %s" % doel.naam,
			"badge": str(w) if w > 0 else "", "klas": "hotdeur", "prio": 11, "op": "aan",
			"kind": "drop", "drop": "deur", "data": {"naar": naar, "kamer": nu},
			"volg": _volg_deur(nu, naar),
			"aan": func(_s): naar_kamer(naar)})
	# While a game runs the hotel's own buttons are off the glass anyway
	# (`Hits` hides them) — and a game may BORROW one (`ctx.hotspots.pak`, the
	# voerkar takes the bowls), so then they are all made as they always were.
	# Outside a game a button stands only where a tap does something.
	var spel := not Games.actief().is_empty()
	if nu == "receptie":
		var bp := decor_plek("receptie", "bel")
		# Only where ringing brings a guest: room for one more animal in some
		# bedroom (a free bed, or floor for a new one) and nobody at the desk
		# yet.  With every room full or a guest still checking in, a tap only
		# said "alle kamers vol" or "Er staat al iemand" (owner, 2026-09-23:
		# "actions ... are available ... but when you click on them you can't
		# execute them ... this provides visual clutter").
		var vrij := State.s["nieuweGast"] == null and State.s["checkin"] == null \
			and State.plek_voor_gast()
		if bp.is_empty() or not (vrij or spel):
			Hits.weg("bel")
		else:
			# In the morning the bell is THE thing to do, and it says so: it
			# pulses until a guest is checked in (owner, 2026-09-23: "laat niet
			# het prikbord zien als start. De gebruiker moet gewoon op de bel
			# drukken").  -1: for as long as this button stands.
			Hits.maak({"id": "bel", "door": EIGENAAR, "kamer": "receptie",
				"x": bp["x"], "z": bp["z"], "y": 20, "icoon": "🔔", "label": "Bel",
				"op": "aan", "badge": "!",
				"puls": -1.0 if (str(State.s["ronde"]) == "ochtend" and not spel) else 0.0,
				"titel": "Bel voor de volgende gast", "klas": "hotbel vrij", "prio": 10,
				"aan": func(_s): bel()})
		var pp := decor_plek("receptie", "prikbord")
		if not pp.is_empty():
			var open := open_taken()
			# Same priority as the bell and the board's own cards: they are the
			# three controls of the morning round, and the button that opens the
			# board must not be pushed off the board by the cards on it (V1-5).
			Hits.maak({"id": "prikbord", "door": EIGENAAR, "kamer": "receptie",
				"x": pp["x"], "z": pp["z"], "y": 22, "icoon": "📋", "op": "aan",
				"label": "Prikbord", "badge": str(open) if open > 0 else "",
				"titel": "Het prikbord met de taakjes", "prio": 10, "klas": "hotbord",
				"aan": func(_s): prikbord_tik()})
		var lp := decor_plek("receptie", "balielamp")
		if avond_klaar() and not lp.is_empty():
			Hits.maak({"id": "lamp", "door": EIGENAAR, "kamer": "receptie",
				"x": lp["x"], "z": lp["z"], "y": 20, "icoon": "🌙", "label": "Avond",
				"op": "aan", "titel": "De avondronde", "klas": "hotlamp aan", "prio": 9,
				"aan": func(_s): avondronde()})
		else:
			Hits.weg("lamp")
	# A bed has no button at all.  An OCCUPIED bed never had one: the sleeping
	# animal with its name plate already says it.  A FREE bed had one while a
	# guest waited for a bed; since 2026-09-24 the check-in chooses a ROOM and the
	# beds game gives that room its beds (owner: "Je moet bij bellen van het dier
	# een kamer voor het dier kiezen"), so a tap on a bed has nothing to do.
	var mp := decor_plek(nu, "mand")
	if not mp.is_empty():
		var wil := 0
		for g in State.s["gasten"]:
			if str(g.get("kamer", "")) == nu and str(g.get("behoefte", "")) == "spelen" \
					and not g.get("blij", false):
				wil += 1
		# only when somebody in this room wants to play: otherwise a tap only
		# said "🧶 Straks samen spelen" (owner, 2026-09-23)
		if wil <= 0 and not spel:
			Hits.weg("mand_%s" % nu)
		else:
			Hits.maak({"id": "mand_%s" % nu, "door": EIGENAAR, "kamer": nu,
				"x": mp["x"], "z": mp["z"], "y": 8, "icoon": "🧶", "label": "Speelmand",
				"op": "aan", "titel": "De speelmand", "badge": str(wil) if wil > 0 else "", "prio": 7,
				"puls": _puls_van("mand_%s" % nu),
				"aan": func(_s): tik_mand(nu)})
	for slot in _slots(nu, "bak"):
		var sid := str(slot.get("id", ""))
		if bool(slot.get("tijdelijk", false)):
			Hits.weg("bak_%s_%s" % [nu, sid])
			continue
		var niveau := _bak_stand(nu, sid)
		var hier := 0
		var honger := 0
		for g in State.s["gasten"]:
			if str(g.get("kamer", "")) == nu:
				hier += 1
				if not g.get("gegeten", false):
					honger += 1
		# a bowl is something to tap when there is food in it and somebody here
		# still has to eat (the tap feeds them); an empty one only said "🍪 Vul
		# eerst de voerkar" or "🍽 Hier slaapt niemand" — the hungry guest's
		# own 🍪 bubble already says it (owner, 2026-09-23)
		if not spel and (niveau <= 0 or honger <= 0):
			Hits.weg("bak_%s_%s" % [nu, sid])
			continue
		Hits.maak({"id": "bak_%s_%s" % [nu, sid], "door": EIGENAAR, "kamer": nu,
			"x": slot.get("x", 0), "z": slot.get("z", 0), "y": 7,
			"icoon": "🍪" if niveau > 0 else "🍽",
			"label": "Vol" if niveau > 0 else "Leeg",
			"badge": "!" if niveau == 0 and hier > 0 else "",
			"titel": "Er ligt eten in het bakje" if niveau > 0 else "Het bakje is nog leeg",
			"kind": "drop", "drop": "bak", "data": {"kamer": nu, "slot": sid},
			"klas": "hotbak vol" if niveau > 0 else "hotbak", "prio": 7, "op": "aan",
			"puls": _puls_van("bak_%s_%s" % [nu, sid]),
			"aan": func(_s): tik_bak(nu, sid)})
	_wens_wolken(nu)

## The wish pictograms above the animals that are here.  A game that plays in
## this room owns the screen: its buttons come first, so the wish bubbles step
## aside until it stops (world.md §5.2).
func _wens_wolken(nu: String) -> void:
	var spel_hier := false
	var spel := Games.actief()
	if not spel.is_empty():
		var sd := Games.definitie(spel)
		spel_hier = Games.actieve_kamer() == nu or str(sd.get("kamer", "")) == nu
		if not spel_hier:
			for id in Hits.lijst():
				var s = Hits.spot(id)
				if s != null and s.door == spel and s.kamer == nu:
					spel_hier = true
					break
	var wens_nr := 0
	var nieuw = State.s["nieuweGast"]
	for g in alle_dieren():
		var id := str(g["id"])
		if str(g.get("waar", "")) != nu or spel_hier:
			Hits.weg("wens_" + id)
			continue
		if nieuw != null and str(nieuw["id"]) == id:
			Hits.weg("wens_" + id)      # the guest at the desk has its own bubble
			continue
		var b := str(g.get("behoefte", ""))
		if not State.BEHOEFTE.has(b) or behoefte_klaar(g):
			continue
		var d = World.dier(id)
		if d != null and d.staat == "eet":
			Hits.weg("wens_" + id)
			continue
		var bh: Dictionary = State.BEHOEFTE[b]
		var hoog := 58 + (wens_nr % 2) * 13
		wens_nr += 1
		var zin: String = "%s %s" % [g["naam"], bh["tekst"]]
		Ui.wolk({"id": "wens_" + id, "door": EIGENAAR, "kamer": nu, "hoog": hoog,
			"icoon": bh["icoon"], "tekst": wens_woord(b), "titel": zin,
			"klas": "hotwens", "prio": 6, "volg": _volg_dier(id, hoog),
			"tik": func(_s): wens_tik(id)})

# ------------------------------------------------------------ een wens volgen

## A tap on a wish takes you where it can come true (owner, 2026-09-23:
## "Wanneer boef nu eten wil weet ik niet waar ik naar toe moet. Als ik eten druk
## gebeurt er niks dat zou me naar de keuken moeten brengen").  It does what the
## card of that wish on the board does: a wish a game fulfils opens that game in
## its room — the voerkar in the keuken for 🍪 while his bowl is empty, the tub,
## the pool, the stall — and a wish the hotel fulfils itself takes you to the
## thing to tap there, his bowl with food in it or the play basket, which then
## pulses for a moment (`WIJS_S`).  A tap used to toast the wish once more.
const WIJS_S := 4.0
var _wijs := {"id": "", "tot": 0}   ## the hotel button a tapped wish points at

func wens_tik(gast_id: String) -> void:
	var g := gast_bij_id(gast_id)
	if g.is_empty():
		return
	var b := str(g.get("behoefte", ""))
	var kamer := str(g.get("kamer", ""))
	if b == "eten" and not kamer.is_empty():
		for slot in _slots(kamer, "bak"):
			var sid := str(slot.get("id", ""))
			if not bool(slot.get("tijdelijk", false)) and _bak_stand(kamer, sid) > 0:
				_ga_en_wijs(kamer, "bak_%s_%s" % [kamer, sid])
				return
		if _speelbaar("voerkar") and Games.speelbaar_nu("voerkar"):
			doe_taak({"kamer": "keuken", "actie": "game:voerkar"})
		else:
			naar_kamer("keuken")
		return
	if b == "spelen" and not kamer.is_empty():
		_ga_en_wijs(kamer, "mand_%s" % kamer)
		return
	var spel := _spel_voor_wens(b)
	if not spel.is_empty():
		doe_taak({"kamer": str(Games.definitie(spel).get("kamer", "")), "actie": "game:" + spel})
		return
	var p := plek_van_behoefte(g)
	if not str(p.get("kamer", "")).is_empty():
		naar_kamer(str(p["kamer"]))

## The game that fulfils this wish and can be played right now, or "".
func _spel_voor_wens(b: String) -> String:
	var vast := str(WENS_SPEL.get(b, ""))
	if not vast.is_empty() and _speelbaar(vast) and Games.speelbaar_nu(vast):
		return vast
	for id in Games.lijst():
		if _spel_wil(Games.definitie(id), b) and _speelbaar(id) and Games.speelbaar_nu(id):
			return str(id)
	return ""

## To that room, and the button of the thing pulses there for a moment.
func _ga_en_wijs(kamer: String, knop_id: String) -> void:
	_wijs = {"id": knop_id, "tot": Time.get_ticks_msec() + int(WIJS_S * 1000.0)}
	if World.kamer_nu() != kamer:
		naar_kamer(kamer)
	else:
		hotspots()

## How long a hotel button pulses: `WIJS_S` for the one a tapped wish points
## at, while that lasts; 0 for every other one.
func _puls_van(knop_id: String) -> float:
	if str(_wijs["id"]) != knop_id:
		return 0.0
	var rest := (int(_wijs["tot"]) - Time.get_ticks_msec()) / 1000.0
	return rest if rest > 0.1 else 0.0

# ---------------------------------------------------------------- bakjes

## Every bowl of the hotel with its level.  Empty until W1 lands `Rooms.slots`.
func alle_bakken() -> Array:
	var uit: Array = []
	for kamer_id in Rooms.lijst():
		for slot in _slots(kamer_id, "bak"):
			var sid := str(slot.get("id", ""))
			uit.append({"kamer": kamer_id, "slot": sid,
				"niveau": _bak_stand(kamer_id, sid)})
	return uit

## The bowls of rooms where guests sleep and that are empty.
func lege_bakken() -> Array:
	var uit: Array = []
	for b in alle_bakken():
		if int(b["niveau"]) > 0:
			continue
		for g in State.s["gasten"]:
			if str(g.get("kamer", "")) == str(b["kamer"]):
				uit.append(b)
				break
	return uit

# --------------------------------------------------------- kleine hulpjes

## Where a named thing stands: the room's fixed decor first, then the loose
## things a game put down (world.md §5.1 `plek`).
func decor_plek(kamer_id: String, naam: String) -> Dictionary:
	var r = Rooms.get_kamer(kamer_id)
	if r != null:
		for d in r.decor:
			if str(d.get("n", "")) == naam or str(d.get("sleutel", "")) == naam:
				return {"kamer": kamer_id, "x": d.get("x", 0), "z": d.get("z", 0)}
	# the desk lamp and the trolley are movable "dingen" and were lifted out
	# of the room's own decor list at boot (world.md §1.3)
	var ding := World.ding(naam)
	if not ding.is_empty():
		return {"kamer": str(ding["kamer"]), "x": ding["x"], "z": ding["z"]}
	var stuk := World.decor_plek(naam, kamer_id)
	if not stuk.is_empty():
		return {"kamer": str(stuk["kamer"]), "x": stuk["x"], "z": stuk["z"]}
	return {}

## A bubble that walks with its animal, and knows how big that animal draws:
## with the guest's own rectangle the band grid keeps the guest whole
## (HOTEL.md §9) instead of guessing from the aim point (I1 finding 5).
func _volg_dier(id: String, hoog: float = 54.0) -> Callable:
	return func() -> Dictionary:
		var d = World.dier(id)
		if d == null:
			return {}
		return {"x": d.x, "z": d.z, "y": hoog, "kamer": d.kamer,
				"vlak": World.vlak_van_dier(id), "d": d.x + d.z + 0.6}

## The check-in card's anchor: the guest's spot at the desk, with the box the
## guest will have THERE, so the card leaves room for it and does not follow
## it in from the corridor door.
func _volg_balieplek(id: String) -> Callable:
	return func() -> Dictionary:
		var p := _balieplek()
		var vak := Rect2()
		var d = World.dier(id)
		if d != null:
			vak = World.vlak_van(d.model, float(p["x"]), float(p["z"]), 0.0, d.params,
				Art.DIER_ANKER)
		return {"x": p["x"], "z": p["z"], "y": float(_ci_hoog()), "kamer": "receptie",
			"vlak": vak}

## The same for a door: its rectangle moves with the camera, so it is measured
## every pass instead of once at creation.
func _volg_deur(kamer_id: String, naar: String) -> Callable:
	return func() -> Dictionary:
		return {"vlak": World.vlak_van_deur(kamer_id, naar)}

func _plek(fx: float, fz: float) -> Dictionary:
	return Rooms.plek("receptie", fx, fz)

## Where a guest stands AT the desk: on the floor in front of the counter — the
## first in front of its middle, by the till, the next ones beside it.  The
## check-in and the bill both happen here and the family that comes to fetch
## its animal waits here (owner, 2026-09-23: the guest "at the desk" waited by
## the bench in the far corner while its card hung at the desk).  From the
## `Kamer.balie` footprint, so a desk that moves takes its spot along.
const BALIE_VOOR := 17          ## voxels in front of the desk's front edge
const BALIE_NAAST := 20         ## between two guests at the desk

## The same three for the beds game, which asks its question at the desk as
## step 4 of the check-in: where the guest stands, the anchor its card shares
## with the check-in's own card, and that card's height.
func balieplek(i: int = 0) -> Dictionary:
	return _balieplek(i)

func balie_anker(id: String) -> Callable:
	return _volg_balieplek(id)

func balie_hoog() -> int:
	return _ci_hoog()

func _balieplek(i: int = 0) -> Dictionary:
	var r = Rooms.get_kamer("receptie")
	if r == null or (r.balie as Dictionary).is_empty():
		return _plek(0.55, 0.37)
	var mid := (float(r.balie["x0"]) + float(r.balie["x1"])) * 0.5
	var stap: float = float([0, 1, -1][posmod(i, 3)] * BALIE_NAAST)
	return {"kamer": "receptie", "x": JsGetal.rond(mid + stap),
		"z": int(r.balie["z1"]) + BALIE_VOOR + posmod(i, 3) * 2}

# ---- the few places where the hotel reaches into `Rooms` and `World`.  They
#      live together here, so a rename on that side is one edit on this one.

func _slots(kamer_id: String, soort: String) -> Array:
	return Rooms.slots(kamer_id, soort)

func _slot(kamer_id: String, slot_id: String) -> Dictionary:
	return Rooms.slot(kamer_id, slot_id)

## `Rooms.deur_punten` is keyed by the room it leads to; the hotel wants a list.
func _deur_punten(r) -> Array:
	var uit: Array = []
	for naar in r.deur_punten:
		var dp: Dictionary = (r.deur_punten[naar] as Dictionary).duplicate()
		dp["naar"] = naar
		uit.append(dp)
	return uit

func _bak_stand(kamer_id: String, slot_id: String) -> int:
	return World.bak_stand(kamer_id, slot_id)
