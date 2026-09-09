extends Node
## State — the save file, the band and the frozen number factories.  Autoload #7.
## Port of `demos/dierenhotel/state.js` (world.md §3.9, §4).
##
## DECISION (architecture.md §9): a NEW save document, version 1, written as
## JSON to `user://dierenhotel.json` (IndexedDB on the web).  The fields carry
## the same meaning as save v7 of the HTML game, but nothing is migrated: the
## Godot build lives on another origin and cannot see localStorage.  A file that
## does not parse, or carries another `v`, is ignored entirely -> the child gets
## the start screen and a fresh hotel.  Nothing is ever half-loaded.
##
## W2 fills in: guests, waiting list, letters, furniture, prikbord tasks and the
## whole day cycle.  The skeleton implements the envelope, the defaults, the
## atomic write, the corrupt-file rule, the band and `tel`.

signal veranderd()
signal band_veranderd(band: int)

const PAD := "user://dierenhotel.json"
const PAD_TMP := "user://dierenhotel.json.tmp"
const VERSIE := 1
const SIGNAAL_MAX := 10

var s: Dictionary = {}
var _start_keuze := false      ## nothing is saved until the start screen answered

func _ready() -> void:
	s = standaard()

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
		"checkin": null, "geluid": true,
	}

func nieuw_spel() -> void:
	s = standaard()
	_start_keuze = false
	veranderd.emit()

func start_gekozen() -> void:
	_start_keuze = true
	bewaar()

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
	s = uit
	_normaliseer()
	veranderd.emit()
	return true

## JSON has no integers: every number comes back as a float.  Normalise the
## fields that are counted with, or `s["dag"] + 1` starts drifting.
func _normaliseer() -> void:
	for k in ["dag", "munten", "sterren", "band", "kunnen", "famIdx", "meubelNr",
			"scoops", "levering", "snoeppot"]:
		s[k] = int(s[k])

func zet_geluid(aan: bool) -> void:
	s["geluid"] = aan
	bewaar()

## Its own drawer per minigame — `ctx.data()`.
func spel_data(id: String) -> Dictionary:
	if not s["spel"].has(id):
		s["spel"][id] = {}
	return s["spel"][id]

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
