extends Node
## State — the save file, the guests and the band.  Autoload #7.
## Port of `demos/dierenhotel/state.js` (world.md §2.1, §2.2, §3.9, §4).
##
## DECISION (architecture.md §9): a NEW save document, version 1, written as
## JSON to `user://dierenhotel.json` (IndexedDB on the web).  The fields carry
## the same meaning as save v7 of the HTML game, but nothing is migrated: the
## Godot build lives on another origin and cannot see localStorage.  A file that
## does not parse, or carries another `v`, is ignored entirely -> the child gets
## the start screen and a fresh hotel.  Nothing is ever half-loaded.
##
## Beyond the envelope this file owns the guest pool, the guest record and its
## repairs (world.md §4.3), the bed bookkeeping every other module asks about
## (`plek_voor_gast`, `kamers_met_plek`, `plek_in`, `bed_vrij`, `max_gasten`,
## `gast_in_bed`), the food sum `dag_verbruik`, the
## petting supply of PLAN.md §3.4, the thank-you letters and the adaptive band.

signal veranderd()
signal band_veranderd(band: int)
## PLAN.md §3.4 — a sum was answered somewhere in the hotel and every guest got
## a pet back.  Fires only when somebody really gained one, so a hotel that is
## already full stays quiet.
signal aai_gevuld()

const PAD := "user://dierenhotel.json"
const PAD_TMP := "user://dierenhotel.json.tmp"
const VERSIE := 1
const SIGNAAL_MAX := 10
## PLAN.md §3.4 — the petting supply of one guest.  Petting spends it, maths
## fills it up again and the clock never touches it.  Three is the whole ladder
## (3 → 2 → 1 → a nap); the child reads it off the button and the hearts, never
## off a meter (HOTEL.md §2 forbids meters).
const AAI_MAX := 3

var s: Dictionary = {}
var _start_keuze := false      ## nothing is saved until the start screen answered

func _ready() -> void:
	s = standaard()
	_vul_wachtlijst(s)

## The window is closing or the tablet went to sleep: never lose a day
## (architecture.md §9).  `bewaar()` is a no-op before the start screen.
func _notification(wat: int) -> void:
	if wat == NOTIFICATION_WM_CLOSE_REQUEST or wat == NOTIFICATION_APPLICATION_PAUSED:
		bewaar()

# ------------------------------------------------------------------ gasten

## world.md §2.2 `mkGast`.  A guest is a plain Dictionary so it can be saved
## as it stands; every module holds the SAME dictionary, so a change made by
## the hotel is visible in the save without copying anything back.
static func mk_gast(id: String, naam: String, kind: String, soort: String,
		scoops: int, act: String, mins: int) -> Dictionary:
	return {
		"id": id, "naam": naam, "name": naam, "kind": kind, "soort": soort,
		"scoops": scoops, "act": act, "mins": mins,
		"kamer": "", "bed": "", "waar": "receptie",
		"nachten": 2, "geslapen": 0, "prijs": 1, "behoefte": "kamer",
		"dagIn": 1, "accessoires": [], "aai": AAI_MAX,
	}

## world.md §2.1 — the pool, taken in this order by the bell.
static func gasten_pool() -> Array:
	return [
		mk_gast("boef", "Boef", "hond", "puppy", 2, "Wandeling", 30),
		mk_gast("muis", "Muis", "poes", "poes", 1, "Spelen", 15),
		mk_gast("wolkje", "Wolkje", "konijn", "konijn", 1, "Bad", 15),
		mk_gast("gerrit", "Gerrit", "gans", "gans", 2, "Plonzen", 15),
		mk_gast("pip", "Pip", "hond", "puppy", 3, "Wandeling", 30),
		mk_gast("vlok", "Vlok", "poes", "poes", 2, "Spelen", 15),
		mk_gast("stamp", "Stampertje", "konijn", "konijn", 1, "Bad", 15),
		mk_gast("bikkel", "Bikkel", "hond", "puppy", 2, "Wandeling", 30),
		mk_gast("pluis", "Pluis", "poes", "poes", 1, "Spelen", 15),
	]

const FAMILIES := ["Van Dijk", "De Groot", "Bakker", "Jansen", "Visser", "Mulder"]
const LIDWOORD := {"puppy": "de", "poes": "de", "gans": "de", "konijn": "het"}

## world.md §3.2 — icon, long text and place keyword per need.  Frozen table;
## the short word next to the icon lives in `Hotel.WENSWOORD`.
const BEHOEFTE := {
	"eten": {"icoon": "🍪", "tekst": "wil eten", "plek": "bak"},
	"kamer": {"icoon": "🛏", "tekst": "wil een bed", "plek": "bed"},
	"bad": {"icoon": "🛁", "tekst": "wil in de tobbe", "plek": "tobbe"},
	"spelen": {"icoon": "🧶", "tekst": "wil spelen", "plek": "mand"},
	"zwemmen": {"icoon": "🏊", "tekst": "wil zwemmen", "plek": "zwembad"},
	"souvenir": {"icoon": "🎁", "tekst": "wil een souvenir", "plek": "kraam"},
}

## Dutch possessive (world.md §2.1): s/x/z -> apostrophe only, a long vowel
## -> 's, otherwise a plain s.
static func bezit(naam: String) -> String:
	if naam.is_empty():
		return naam
	var l := naam.substr(naam.length() - 1, 1).to_lower()
	if "sxz".contains(l):
		return naam + "'"
	if "aiouy".contains(l):
		return naam + "'s"
	return naam + "s"

static func met_lidwoord(g: Dictionary) -> String:
	return "%s %s" % [LIDWOORD.get(g.get("soort", ""), "de"), g.get("soort", "")]

# --------------------------------------------------------------- standaard

## Every field of the save, with its default (world.md §4.3 `vulAan`).
func standaard() -> Dictionary:
	return {
		"dag": 1, "ronde": "ochtend", "munten": 0, "sterren": 0,
		"band": 3, "kunnen": 3, "signaal": [],
		"gasten": [], "wachtlijst": [], "famIdx": 0,
		"meubels": [], "meubelNr": 0, "taken": [], "brieven": [],
		"scoops": 20, "levering": 4, "snoeppot": 0,
		"kar": null, "spel": {}, "gezien": {},
		"kamerNu": "receptie", "uitcheck": [], "nieuweGast": null,
		"checkin": null, "rekening": null, "geluid": true,
	}

func nieuw_spel() -> void:
	s = standaard()
	_vul_wachtlijst(s)
	_start_keuze = false
	veranderd.emit()

func start_gekozen() -> void:
	_start_keuze = true
	bewaar()

func gestart() -> bool:
	return _start_keuze

# --------------------------------------------------------------- opslag

func bewaar() -> bool:
	if not _start_keuze:
		return false
	var doc := {"v": VERSIE, "s": s}
	var f := FileAccess.open(PAD_TMP, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(doc))
	f.close()
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove(PAD.get_file())
		dir.rename(PAD_TMP.get_file(), PAD.get_file())
	return true

## Returns true when a usable save was read.  Anything wrong -> fresh game.
func lees() -> bool:
	if not FileAccess.file_exists(PAD):
		return false
	var f := FileAccess.open(PAD, FileAccess.READ)
	if f == null:
		return false
	var tekst := f.get_as_text()
	f.close()
	# JSON.new().parse() reports a broken file quietly; parse_string() would
	# push an engine error for what is a perfectly normal case here.
	var lezer := JSON.new()
	if lezer.parse(tekst) != OK:
		return false
	var doc = lezer.data
	if typeof(doc) != TYPE_DICTIONARY or int(doc.get("v", 0)) != VERSIE \
			or typeof(doc.get("s")) != TYPE_DICTIONARY:
		return false
	var uit := standaard()
	for k in uit.keys():
		if doc["s"].has(k) and doc["s"][k] != null:
			uit[k] = doc["s"][k]
	# EVERYTHING happens on the candidate `uit`, never on `s`: shape check,
	# normalise, repair and one more shape check.  Only a document that came
	# through all four whole is swapped in, so a hand-edited blob ends at the
	# start screen with the running game untouched (world.md §4.4).
	if not _vorm_klopt(uit):
		return false
	_normaliseer(uit)
	_repareer(uit)
	if not _vorm_klopt(uit):
		return false
	s = uit
	_herbereken()
	veranderd.emit()
	return true

# ------------------------------------------------------------- vormcontrole
##
## The reviewer's file `{"v":1,"s":{"rekening":{"hand":"kapot","bank":3}}}` has
## a valid envelope, a valid `v` and a `rekening` that IS a Dictionary — and it
## crashed the loader on the first `for` over `hand`.  So the check below walks
## every field of architecture.md §9 down to the leaves it will later index:
## a list must be a list, a counted field must be a number, and the two coin
## piles of the bill must be lists of numbers.

func _is_getal(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT

func _is_tekst(v) -> bool:
	return typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME

## An Array whose every element is a Dictionary (with `sleutel` when given).
func _dicts(v, sleutel := "") -> bool:
	if typeof(v) != TYPE_ARRAY:
		return false
	for item in v:
		if typeof(item) != TYPE_DICTIONARY:
			return false
		if not sleutel.is_empty() and not item.has(sleutel):
			return false
	return true

func _getallen(v) -> bool:
	if typeof(v) != TYPE_ARRAY:
		return false
	for item in v:
		if not _is_getal(item):
			return false
	return true

## Are all the fields present and of a shape the rest of the code may index?
func _vorm_klopt(uit: Dictionary) -> bool:
	for k in INT_VELDEN:
		if not _is_getal(uit[k]):
			return false
	if not _is_tekst(uit["ronde"]) or not RONDEN.has(str(uit["ronde"])):
		return false
	if not _is_tekst(uit["kamerNu"]):
		return false
	if typeof(uit["geluid"]) != TYPE_BOOL:
		return false
	if not _dicts(uit["signaal"]) or not _dicts(uit["meubels"]) \
			or not _dicts(uit["taken"], "id") or not _dicts(uit["brieven"]):
		return false
	for item in uit["signaal"]:
		if not _is_getal(item.get("g", 0)) or not _is_getal(item.get("t", 0)):
			return false
	if not _dicts(uit["gasten"], "id") or not _dicts(uit["wachtlijst"], "id"):
		return false
	for g in (uit["gasten"] as Array) + (uit["wachtlijst"] as Array):
		if not _gast_vorm_klopt(g):
			return false
	if typeof(uit["uitcheck"]) != TYPE_ARRAY:
		return false
	for id in uit["uitcheck"]:
		if not _is_tekst(id):
			return false
	for k in ["spel", "gezien"]:
		if typeof(uit[k]) != TYPE_DICTIONARY:
			return false
	for laatje in (uit["spel"] as Dictionary).values():
		if typeof(laatje) != TYPE_DICTIONARY:
			return false
	if uit["nieuweGast"] != null:
		if typeof(uit["nieuweGast"]) != TYPE_DICTIONARY \
				or not uit["nieuweGast"].has("id") \
				or not _gast_vorm_klopt(uit["nieuweGast"]):
			return false
	if not _checkin_vorm_klopt(uit["checkin"]):
		return false
	if not _rekening_vorm_klopt(uit["rekening"]):
		return false
	return true

func _gast_vorm_klopt(g) -> bool:
	if typeof(g) != TYPE_DICTIONARY or not _is_tekst(g.get("id", 0)):
		return false
	for k in GAST_INT:
		if g.has(k) and g[k] != null and not _is_getal(g[k]):
			return false
	for k in ["naam", "name", "kamer", "bed", "waar", "behoefte", "kind", "soort", "act"]:
		if g.has(k) and g[k] != null and not _is_tekst(g[k]):
			return false
	if g.has("accessoires") and g["accessoires"] != null \
			and typeof(g["accessoires"]) != TYPE_ARRAY:
		return false
	if g.has("kast") and g["kast"] != null and typeof(g["kast"]) != TYPE_ARRAY:
		return false
	return true

func _checkin_vorm_klopt(v) -> bool:
	if v == null:
		return true
	if typeof(v) != TYPE_DICTIONARY or not _is_tekst(v.get("gastId", 0)):
		return false
	for k in CHECKIN_INT:
		if v.has(k) and v[k] != null and not _is_getal(v[k]):
			return false
	return true

func _rekening_vorm_klopt(v) -> bool:
	if v == null:
		return true
	if typeof(v) != TYPE_DICTIONARY:
		return false
	if not _is_tekst(v.get("gastId", 0)) or not _is_tekst(v.get("fam", 0)):
		return false
	for k in REKENING_INT:
		if v.has(k) and v[k] != null and not _is_getal(v[k]):
			return false
	# the two coin piles: lists of numbers, or the counting step crashes
	for k in ["hand", "bank"]:
		if not _getallen(v.get(k, [])):
			return false
	return true

const RONDEN := ["ochtend", "vrij", "avond"]

const INT_VELDEN := ["dag", "munten", "sterren", "band", "kunnen", "famIdx",
	"meubelNr", "scoops", "levering", "snoeppot"]
const GAST_INT := ["scoops", "mins", "nachten", "geslapen", "prijs", "dagIn", "betaald",
	"aai"]
const CHECKIN_INT := ["samen", "extra", "nieuw", "dagen", "voorraad", "stap",
	"fouten1", "fouten2", "t0"]
const REKENING_INT := ["nachten", "prijs", "totaal", "stap", "pogingen",
	"telPog", "wisselPog", "t0", "tw"]

## JSON has no integers: every number comes back as a float.  Normalise the
## fields that are counted with, or `s["dag"] + 1` starts drifting.
##
## The three free-form drawers — `spel` (one per minigame), `gezien` and `kar`
## — are deliberately NOT walked: their shape belongs to the game that wrote
## them, and a game reads its own numbers through `int(ctx.data()[...])`.
func _normaliseer(d: Dictionary) -> void:
	_maak_int(d, INT_VELDEN)
	for lijst in [d["gasten"], d["wachtlijst"]]:
		for g in lijst:
			_maak_int(g, GAST_INT)
	if d["nieuweGast"] != null:
		_maak_int(d["nieuweGast"], GAST_INT)
	if d["checkin"] != null:
		_maak_int(d["checkin"], CHECKIN_INT)
	if d["rekening"] != null:
		_maak_int(d["rekening"], REKENING_INT)
		for veld in ["hand", "bank"]:
			var munten: Array = []
			for v in (d["rekening"].get(veld, []) as Array):
				munten.append(int(v))
			d["rekening"][veld] = munten
	for item in d["signaal"]:
		_maak_int(item, ["g", "t"])
	for m in d["meubels"]:
		_maak_int(m, ["x", "z", "rot"])
	for q in d["taken"]:
		_maak_int(q, ["prio"])
	for b in d["brieven"]:
		_maak_int(b, ["dag"])

func _maak_int(d: Dictionary, sleutels: Array) -> void:
	for k in sleutels:
		if d.has(k) and d[k] != null and typeof(d[k]) != TYPE_STRING:
			d[k] = int(d[k])

## world.md §4.3 — the four repairs, in order.  A guest is never lost.
func _repareer(d: Dictionary) -> void:
	var nieuw = d["nieuweGast"]
	if d["checkin"] != null and (nieuw == null
			or str(d["checkin"].get("gastId", "")) != str(nieuw.get("id", ""))):
		d["checkin"] = null
	if nieuw != null and d["checkin"] == null:
		(d["wachtlijst"] as Array).push_front(nieuw)
		d["nieuweGast"] = null
	# a bill for a guest who is not in the hotel any more has nothing to pay
	if d["rekening"] != null and _gast_in(d, str(d["rekening"].get("gastId", ""))).is_empty():
		d["rekening"] = null
	for g in d["gasten"]:
		_repareer_gast(d, g, true)
	for g in d["wachtlijst"]:
		_repareer_gast(d, g, false)
	if d["nieuweGast"] != null:
		_repareer_gast(d, d["nieuweGast"], false)
	_vul_wachtlijst(d)

static func _gast_in(d: Dictionary, id: String) -> Dictionary:
	for g in d["gasten"]:
		if str(g.get("id", "")) == id:
			return g
	return {}

func _repareer_gast(d: Dictionary, g: Dictionary, in_hotel: bool) -> void:
	if not g.has("naam") or str(g["naam"]).is_empty():
		g["naam"] = str(g.get("name", g.get("id", "gast")))
	g["name"] = g["naam"]
	if not g.has("kamer") or g["kamer"] == null:
		g["kamer"] = ""
	if not g.has("bed") or g["bed"] == null:
		g["bed"] = ""
	if not g.has("waar") or str(g.get("waar", "")).is_empty():
		g["waar"] = str(g["kamer"]) if not str(g["kamer"]).is_empty() else "receptie"
	if not g.has("nachten"):
		g["nachten"] = 2
	if not g.has("geslapen"):
		g["geslapen"] = 0
	if not g.has("prijs"):
		g["prijs"] = 1
	if not g.has("behoefte") or str(g.get("behoefte", "")).is_empty():
		g["behoefte"] = "eten" if (in_hotel and not str(g["kamer"]).is_empty()) else "kamer"
	if not g.has("accessoires") or typeof(g["accessoires"]) != TYPE_ARRAY:
		g["accessoires"] = []
	# the wardrobe (2026-09-24) is optional: a save without it simply has an
	# empty one, and `kast_van` counts what he wears as his own anyway
	if g.has("kast") and typeof(g["kast"]) != TYPE_ARRAY:
		g["kast"] = []
	if not g.has("scoops"):
		g["scoops"] = 1
	if not g.has("dagIn"):
		g["dagIn"] = int(d["dag"])
	# a save from before PLAN.md §3.4 gets three pets as a present, and a number
	# that wandered off the ladder is clamped back onto it
	if not g.has("aai") or g["aai"] == null:
		g["aai"] = AAI_MAX
	g["aai"] = clampi(int(g["aai"]), 0, AAI_MAX)

## world.md §4.3: an empty waiting list is refilled from the pool.
func _vul_wachtlijst(d: Dictionary) -> void:
	if (d["wachtlijst"] as Array).is_empty():
		var achter := "" if int(d["dag"]) <= 1 else "_d%d" % int(d["dag"])
		for g in gasten_pool():
			g["id"] = str(g["id"]) + achter
			(d["wachtlijst"] as Array).append(g)

func zet_geluid(aan: bool) -> void:
	s["geluid"] = aan
	bewaar()

## Its own drawer per minigame — `ctx.data()`.
func spel_data(id: String) -> Dictionary:
	if not s["spel"].has(id):
		s["spel"][id] = {}
	return s["spel"][id]

## `state.gezien` — which explanations the child has already seen.
func gezien(sleutel: String) -> bool:
	return s["gezien"].has(sleutel)

func zet_gezien(sleutel: String) -> void:
	s["gezien"][sleutel] = 1
	bewaar()

## One star per game per day (§3.8 `N1`).  The day on which `<spel>` last handed
## a star out lives in that same `gezien` drawer under `ster_<spel>`, so the save
## format stays v1: `gezien` already carried ints and round-trips like any other
## key.  `_normaliseer` deliberately skips the drawer, so JSON gives the number
## back as a float — the `int()` is what makes the comparison survive a reload.
## Day 0 does not exist (`standaard()` starts at 1, `Hotel.morgen()` only counts
## up); guarding it keeps a hand-edited 0 from reading as "already had one" for
## every game at once.
func ster_gehad(spel: String) -> bool:
	var dag := int(s["dag"])
	return dag > 0 and int(s["gezien"].get("ster_" + spel, 0)) == dag

func zet_ster(spel: String) -> void:
	s["gezien"]["ster_" + spel] = int(s["dag"])
	bewaar()

# ------------------------------------------------------------ bedden, gasten

## Every bed of the hotel, in a fixed order (world.md §5.3, `Rooms.slots`).
func alle_bedden() -> Array:
	var uit: Array = []
	for slot in Rooms.slots("", "bed"):
		uit.append({"kamer": str(slot.get("kamer", "")), "slot": str(slot.get("id", ""))})
	return uit

## The first free bed — of the whole hotel, or of one room — or {} when there
## is none.  Bookkeeping only: whether a guest may come is `plek_voor_gast()`.
func bed_vrij(kamer_id := "") -> Dictionary:
	for b in alle_bedden():
		if not kamer_id.is_empty() and str(b["kamer"]) != kamer_id:
			continue
		if gast_in_bed(str(b["kamer"]), str(b["slot"])).is_empty():
			return b
	return {}

# ------------------------------------------------------- plek in de kamers
##
## Owner, 2026-09-24: "met kamer 1 en kamer 2 waar de bedden geplaatst moeten
## worden op basis van waar het dier gaat slapen".  The check-in chooses a ROOM
## for the new guest, and the beds game (`games/bedden`) makes the beds that
## room needs — so the guest cap is no longer the free beds but the free floor:
## a guest may come while some bedroom can take one more animal, a free bed of
## its own or room on its floor for a new one.  Every guest that checks in still
## ends WITH a bed, so everything that asks "who has a bed" keeps its answer.
##
## The floor is the room's BED PLACES (`Rooms.bed_raster`, owner 2026-09-24:
## "De eerste twee bedden zijn goed geplaatst, daarna gaat alles door
## elkaar"): a new bed goes on the first free one, turned the room's way, so
## beds 3, 4, ... stand in the same rows as bed1 and bed2.  Until that day a new
## bed took the free cell farthest from every other bed, and beds landed
## crosswise and through each other.  The check-in puts beds down up to
## `MAX_BEDDEN` a room and never beyond the room's bed places.

## The most beds the check-in itself puts in one room.  The bed places of the
## two bedrooms stay under it (four each), so today they are the real cap.
const MAX_BEDDEN := 6

## The rooms with at least one bed, in the room order: the bedrooms.
func slaapkamers() -> Array[String]:
	var uit: Array[String] = []
	for k in Rooms.lijst():
		if not Rooms.slots(k, "bed").is_empty():
			uit.append(k)
	return uit

## The guests whose bed is in this room (the animals that sleep there).
func slapers_in(kamer_id: String) -> Array:
	var uit: Array = []
	for g in s["gasten"]:
		if str(g.get("kamer", "")) == kamer_id and not str(g.get("bed", "")).is_empty():
			uit.append(g)
	return uit

## The beds of this room nobody sleeps in, as slot records, in slot order.
func vrije_bedden(kamer_id: String) -> Array:
	var uit: Array = []
	for b in Rooms.slots(kamer_id, "bed"):
		if gast_in_bed(kamer_id, str(b.get("id", ""))).is_empty():
			uit.append(b)
	return uit

## Where the next `hoeveel` new beds would go, in the order they would be put
## down: the room's free bed places (`Rooms.vrije_bedplekken`), first to last.
## A room without bed places takes no new beds.
func bed_plekken(kamer_id: String, hoeveel: int) -> Array:
	var uit: Array = []
	if hoeveel <= 0:
		return uit
	for p in Rooms.vrije_bedplekken(kamer_id):
		if uit.size() >= hoeveel:
			break
		uit.append(p)
	return uit

## Where the next new bed of this room goes, {x, z}, or {} when none fits.
func bed_plek(kamer_id: String) -> Dictionary:
	var p := bed_plekken(kamer_id, 1)
	if p.is_empty():
		return {}
	return {"x": (p[0] as Vector2).x, "z": (p[0] as Vector2).y}

## How many new beds the check-in may still put down in this room.
func nieuwe_bedden(kamer_id: String) -> int:
	var ruimte := MAX_BEDDEN - Rooms.slots(kamer_id, "bed").size()
	if ruimte <= 0:
		return 0
	return bed_plekken(kamer_id, ruimte).size()

## How many more guests this room can take: its free beds and its new ones.
func plek_in(kamer_id: String) -> int:
	return vrije_bedden(kamer_id).size() + nieuwe_bedden(kamer_id)

## The bedrooms where one more guest fits, in the room order.
func kamers_met_plek() -> Array[String]:
	var uit: Array[String] = []
	for k in slaapkamers():
		if plek_in(k) > 0:
			uit.append(k)
	return uit

## May the bell bring a guest?  Some bedroom has a free bed, or a free bed place
## for one new bed.
func plek_voor_gast() -> bool:
	for k in slaapkamers():
		if not vrije_bedden(k).is_empty():
			return true
		if Rooms.slots(k, "bed").size() < MAX_BEDDEN and not bed_plekken(k, 1).is_empty():
			return true
	return false

## How many guests the hotel can hold as it stands: every bed, and every bed
## the check-in may still put down.
func max_gasten() -> int:
	var n := 0
	for k in slaapkamers():
		n += Rooms.slots(k, "bed").size() + nieuwe_bedden(k)
	return n

## Every guest in the hotel sleeps in a bed of his own (owner, 2026-09-24).  A
## save can say otherwise: two guests named in one bed (a hand-made or seeded
## save — `tools/kiek.js --gasten 7` did it), or a bed that is gone (a bought
## bed that no longer stands on a bed place).  Such a guest gets a free bed of
## his own room, else a new bed on a free bed place there, else the same in the
## other bedrooms; with no bed anywhere he goes back to the front of the waiting
## list — never lost.  Returns the ids of the guests it moved.  Runs once the
## furniture is back (`Hotel.herstel_wereld`).
func herstel_bedden() -> Array:
	var uit: Array = []
	var bezet := {}
	var zonder: Array = []
	# first every guest whose bed is really his, in guest order: the first one
	# named in a bed keeps it
	for g in s["gasten"]:
		var bed := str(g.get("bed", ""))
		if bed.is_empty():
			continue
		var sleutel := "%s|%s" % [str(g.get("kamer", "")), bed]
		var slot := Rooms.slot(str(g.get("kamer", "")), bed)
		if not slot.is_empty() and str(slot.get("soort", "")) == "bed" and not bezet.has(sleutel):
			bezet[sleutel] = true
		else:
			zonder.append(g)
	var wacht: Array = []
	for g in zonder:
		var nieuw := _bed_voor(str(g.get("kamer", "")), bezet)
		if nieuw.is_empty():
			wacht.append(g)
			continue
		g["kamer"] = nieuw["kamer"]
		g["bed"] = nieuw["slot"]
		g["waar"] = nieuw["kamer"]
		bezet["%s|%s" % [str(nieuw["kamer"]), str(nieuw["slot"])]] = true
		uit.append(str(g.get("id", "")))
	for g in wacht:
		(s["gasten"] as Array).erase(g)
		g["kamer"] = ""
		g["bed"] = ""
		g["waar"] = "receptie"
		g["behoefte"] = "kamer"
		(s["wachtlijst"] as Array).push_front(g)
		uit.append(str(g.get("id", "")))
	return uit

## A bed for a guest who has none: a free bed of `kamer` (not in `bezet`), a new
## one on its first free bed place, then the other bedrooms.  {kamer, slot}.
func _bed_voor(kamer: String, bezet: Dictionary) -> Dictionary:
	var kamers: Array[String] = []
	if Rooms.bestaat(kamer):
		kamers.append(kamer)
	for k in slaapkamers():
		if not kamers.has(k):
			kamers.append(k)
	for k in kamers:
		for b in Rooms.slots(k, "bed"):
			if not bezet.has("%s|%s" % [k, str(b.get("id", ""))]):
				return {"kamer": k, "slot": str(b.get("id", ""))}
		if not Rooms.vrije_bedplekken(k).is_empty():
			var m := Rooms.meubel_zet(k, "bed")
			if not m.is_empty():
				return {"kamer": k, "slot": str(m.get("id", ""))}
	return {}

func gast_in_bed(kamer: String, slot: String) -> Dictionary:
	for g in s["gasten"]:
		if str(g.get("kamer", "")) == kamer and str(g.get("bed", "")) == slot:
			return g
	return {}

## The guest record itself, so a caller can change it in place.
## The wardrobe of a guest (owner, 2026-09-24: "meer aanpassingsmogelijkheden
## ... zoals kleding"): every piece it ever bought in the shops, worn or not,
## in the fixed order of `ArtGasten.ACC_NAMEN`.  What he wears is always his
## own, so a save from before the shops (a souvenir from the stall) counts.
func kast_van(id: String) -> Array:
	var g := gast_van(id)
	var uit: Array = []
	if g.is_empty():
		return uit
	var eigen: Array = []
	for lijst in [g.get("kast", []), g.get("accessoires", [])]:
		if typeof(lijst) == TYPE_ARRAY:
			eigen.append_array(lijst)
	for naam in ArtGasten.ACC_NAMEN:
		if eigen.has(naam):
			uit.append(naam)
	return uit

## Put a bought piece in the guest's wardrobe (it is not worn by this alone).
func in_kast(id: String, naam: String) -> void:
	var g := gast_van(id)
	if g.is_empty() or not ArtGasten.KLEDING.has(naam):
		return
	var kast = g.get("kast", [])
	if typeof(kast) != TYPE_ARRAY:
		kast = []
	if not (kast as Array).has(naam):
		(kast as Array).append(naam)
	g["kast"] = kast

func gast_van(id: String) -> Dictionary:
	for g in s["gasten"]:
		if str(g.get("id", "")) == id:
			return g
	return {}

func gasten_in(kamer_id: String) -> Array:
	var uit: Array = []
	for g in s["gasten"]:
		if str(g.get("waar", "")) == kamer_id:
			uit.append(g)
	return uit

# ------------------------------------------------------------------- aaien
##
## PLAN.md §3.4.  The supply only goes DOWN by petting and only UP by maths; the
## day cycle refills it and the clock never spends it.  A guest on the waiting
## list has nothing to pet yet, so all four functions look at `s["gasten"]`.
##
## None of the four calls `bewaar()`: `tel()` runs on every single answer and
## must not hit the disk each time.  The save follows at the next `bewaar()` of
## the caller that did the real work (a finished task, the new day).

## How many pets `id` has left, −1 when no guest of that name is in the hotel.
func aai_van(id: String) -> int:
	var g := gast_van(id)
	if g.is_empty():
		return -1
	return clampi(int(g.get("aai", AAI_MAX)), 0, AAI_MAX)

## Spend one pet.  Returns what is LEFT, so the caller knows whether the animal
## drops off for its nap (0) and how many hearts to float up (the number before,
## i.e. the answer + 1).  At zero it stays at zero — nothing is ever refused and
## the number never goes negative.  −1 for an unknown guest, like `aai_van`.
func aai_uit(id: String) -> int:
	var g := gast_van(id)
	if g.is_empty():
		return -1
	var over := maxi(0, clampi(int(g.get("aai", AAI_MAX)), 0, AAI_MAX) - 1)
	g["aai"] = over
	return over

## Hand every guest in the hotel `n` pets back, never above `AAI_MAX`.  True when
## at least one of them really gained something: that is what decides whether the
## hearts rise, so a full hotel (and an empty one) stays quiet.
func aai_bij(n := 1) -> bool:
	var iets := false
	for g in s["gasten"]:
		var nu := clampi(int(g.get("aai", AAI_MAX)), 0, AAI_MAX)
		var na := mini(nu + maxi(0, n), AAI_MAX)
		g["aai"] = na
		if na > nu:
			iets = true
	return iets

## Everybody full again — a finished task, a new day.  Same answer as `aai_bij`.
func aai_vol() -> bool:
	return aai_bij(AAI_MAX)

## The next guest from the waiting list; an empty list is refilled from the
## pool with ids suffixed `_d<dag>`, a colliding id gets `_2`, `_3`, ...
func pak_gast() -> Dictionary:
	_vul_wachtlijst(s)
	var wacht: Array = s["wachtlijst"]
	if wacht.is_empty():
		return {}
	var g: Dictionary = wacht.pop_front()
	var bezet := {}
	for q in s["gasten"]:
		bezet[str(q.get("id", ""))] = 1
	var n := 2
	while bezet.has(str(g["id"])):
		g["id"] = "%s_%d" % [str(g["id"]), n]
		n += 1
	return g

## Σ scoops of the guests in the hotel — one day of food.
func dag_verbruik() -> int:
	var som := 0
	for g in s["gasten"]:
		som += int(g.get("scoops", 0))
	return som

# ------------------------------------------------------------------ brieven

## world.md §3.6 — the thank-you letter.  The family is read BEFORE famIdx
## moves on, the sentence AFTER it: that is the HTML's order and it decides
## which of the four sentences a family gets.
func nieuwe_brief(g: Dictionary) -> Dictionary:
	var fam: String = FAMILIES[posmod(int(s["famIdx"]), FAMILIES.size())]
	s["famIdx"] = int(s["famIdx"]) + 1
	var naam := str(g.get("naam", "de gast"))
	var kamer_nr := "2" if str(g.get("kamer", "")) == "kamer2" else "1"
	var zinnen := [
		"%s heeft heerlijk geslapen in kamer %s." % [naam, kamer_nr],
		"%s rende elke dag door de tuin en at netjes het bakje leeg." % naam,
		"%s vond het bad het allerleukste van het hele hotel." % naam,
		"%s lag het liefst bij het raam naar de vogels te kijken." % naam,
	]
	var zin: String = zinnen[posmod(int(s["famIdx"]), zinnen.size())]
	return {
		"titel": "Bedankje van familie %s 💌" % fam,
		"tekst": "Lieve hotelhouder,\n\n%s\n\nDank je wel dat je zo goed voor %s hebt gezorgd. Het bed was zacht, het bakje vol en de rekening klopte precies.\n\nLiefs, familie %s" % [zin, naam, fam],
		"dag": int(s["dag"]),
	}

# ----------------------------------------------------------------- de band

func n_gasten() -> int:
	return (s["gasten"] as Array).size()

## `band = max(3, min(bandVanN(N), kunnen + 1))` — right or wrong never buys
## stars or access, only the size of the next sum.
func band() -> int:
	return maxi(3, mini(Sommen.band_van_n(n_gasten()), int(s["kunnen"]) + 1))

## `State.tel(goed, ms)` — the adaptive signal (world.md §3.9).
func tel(goed: bool, ms: int) -> void:
	var sig: Array = s["signaal"]
	sig.append({"g": 1 if goed else 0, "t": clampi(ms, 0, 20000)})
	while sig.size() > SIGNAAL_MAX:
		sig.pop_front()
	_herbereken()
	# PLAN.md §3.4: every sum the child answers hands every animal a pet back —
	# ALSO a wrong one.  Joining in is what counts, not being right (R6).
	if aai_bij(1):
		aai_gevuld.emit()

## `herbereken()` — after every change of the guest count as well, because the
## band has a ceiling per N (world.md §3.9).
func herbereken() -> int:
	_herbereken()
	return int(s["band"])

func _herbereken() -> void:
	var sig: Array = s["signaal"]
	if sig.size() >= 6:
		var acc := 0.0
		var tijd := 0.0
		for item in sig:
			acc += float(item["g"])
			tijd += float(item["t"])
		acc /= sig.size()
		tijd /= sig.size()
		if acc >= 0.8 and tijd < 7000.0 and int(s["kunnen"]) < 5:
			s["kunnen"] = int(s["kunnen"]) + 1
			sig.clear()
		elif acc < 0.5 and int(s["kunnen"]) > 3:
			s["kunnen"] = int(s["kunnen"]) - 1
			sig.clear()
	var b := band()
	if b != s["band"]:
		s["band"] = b
		band_veranderd.emit(b)
