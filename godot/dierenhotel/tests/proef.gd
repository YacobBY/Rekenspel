class_name Proef
extends RefCounted
## The two lines of test framework this project needs.
##
## `gelijk` / `waar` / `fout` assert; `verwacht_fout` is the escape hatch for a
## test that deliberately walks an error path (architecture.md §2.4).

var _fouten := 0
var _meldingen: Array[String] = []
var _runner = null
## How many engine errors this test says it is going to cause.
var _verwacht := 0
var _verwacht_waarom: Array[String] = []

func gelijk(gekregen, verwacht, wat := "") -> void:
	if typeof(gekregen) == TYPE_FLOAT or typeof(verwacht) == TYPE_FLOAT:
		if is_equal_approx(float(gekregen), float(verwacht)):
			return
	elif str(gekregen) == str(verwacht):
		return
	fout("%s: kreeg %s, verwacht %s" % [wat, str(gekregen), str(verwacht)])

func waar(v: bool, wat := "") -> void:
	if not v:
		fout("%s: niet waar" % wat)

func fout(melding: String) -> void:
	_fouten += 1
	_meldingen.append(melding)

## Announce that this test makes the engine log `aantal` error(s) ON PURPOSE —
## an `Art.registreer_model` that refuses a protected name, a save file that is
## deliberately corrupt.  Without this the runner counts every engine error as a
## failure (and it should: a silent SCRIPT ERROR would otherwise pass as `ok`).
##
## The budget is EXACT, not a maximum: a test that announces one error and
## causes two fails, and so does a test that announces one and causes none —
## then the error path was not walked at all and the test proved nothing.
## May be called before or after the call that errors; the runner only compares
## the totals at the end of the test.
## `alleen_spellen(ids)` — hide every registered game except `ids` for the
## duration of this test (the hotel's wish and board rules depend on which
## games exist).  The runner calls `herstel_spellen()` after each test.
var _spellen_weg: Dictionary = {}
var _scenes_weg: Dictionary = {}

func alleen_spellen(ids: Array) -> void:
	for k in Games._defs.keys().duplicate():
		if not ids.has(str(k)):
			_spellen_weg[k] = Games._defs[k]
			_scenes_weg[k] = Games._scenes.get(k)
			Games._defs.erase(k)
			Games._scenes.erase(k)

func herstel_spellen() -> void:
	for k in _spellen_weg.keys():
		Games._defs[k] = _spellen_weg[k]
		if _scenes_weg.get(k) != null:
			Games._scenes[k] = _scenes_weg[k]
	_spellen_weg.clear()
	_scenes_weg.clear()

func verwacht_fout(aantal := 1, waarom := "") -> void:
	_verwacht += aantal
	if waarom != "":
		_verwacht_waarom.append(waarom)

# -------------------------------------------- geen hulp na een fout (2026-09-24)

## Everything a game shows right now, as text: every hotspot it owns — kind,
## class, the words on it, its title, whether it is pale or lit — and every
## piece of its own loose decor in the room in view with its parameters.
## Taken before a wrong answer and again after the pause, the two are equal
## (owner, 2026-09-24: "Nee geef geen hulp na fouten"): a help line, a ghost
## answer, a hint bubble, a helper, a lit answer each show up as a difference.
## The disappointed animal's own bubble (`Ui.MIS_WOLK`) is the one thing a miss
## puts up, so it is left out.
func beeld(door: String) -> Dictionary:
	var uit := {}
	for id in Hits.lijst():
		var s = Hits.spot(id)
		if s == null or s.door != door or str(id).begins_with(Ui.MIS_WOLK):
			continue
		var wat := ""
		if is_instance_valid(s.knoop):
			wat = _wat_er_staat(s.knoop)
		uit[str(id)] = "%s | %s | %s" % [s.kind, s.klas, wat]
	for d in World.decor_lijst(World.kamer_nu()):
		if str(d.get("door", "")) == door:
			uit["decor " + str(d.get("id", ""))] = "%s %s" % [str(d.get("model", "")),
				str(d.get("params", {}))]
	return uit

## `beeld()` before and after a wrong answer: nothing came, nothing went,
## nothing changed.
func niets_erbij(voor: Dictionary, na: Dictionary, wat := "") -> void:
	for id in na.keys():
		if not voor.has(id):
			fout("%s: na de misser verschijnt %s (%s)" % [wat, id, str(na[id])])
		elif str(na[id]) != str(voor[id]):
			fout("%s: na de misser verandert %s: %s -> %s" % [wat, id, str(voor[id]), str(na[id])])
	for id in voor.keys():
		if not na.has(id):
			fout("%s: na de misser is %s weg (%s)" % [wat, id, str(voor[id])])

## The animal of the turn is disappointed: the `sip` pose of `Ui.misser`.
func is_sip(dier: String) -> bool:
	var d = World.dier(dier)
	return d != null and str(d.pose) == "sip"

## The `🔄 Nog een keer` bubble of a miss on card `kaart` (or, without a card,
## beside animal `dier`).
func mis_wolk(kaart: String, dier := "") -> bool:
	if not kaart.is_empty() and Hits.spot(Ui.MIS_WOLK + kaart) != null:
		return true
	return not dier.is_empty() and Hits.spot(Ui.MIS_WOLK + Ui.MIS_DIER + dier) != null

static func _wat_er_staat(c: Control) -> String:
	var delen: Array[String] = []
	var alle: Array = [c]
	alle.append_array(c.find_children("*", "Control", true, false))
	for n in alle:
		var k := n as Control
		if k == null or not k.visible:
			continue
		if k is Label and not (k as Label).text.is_empty():
			delen.append((k as Label).text)
		elif k is Button and not (k as Button).text.is_empty():
			delen.append((k as Button).text)
		if not k.tooltip_text.is_empty():
			delen.append("«%s»" % k.tooltip_text)
		if not k.modulate.is_equal_approx(Color.WHITE):
			delen.append("~%s" % str(k.modulate))
		if k.has_theme_stylebox_override("normal"):
			delen.append("[verf]")
	return " ".join(delen)
