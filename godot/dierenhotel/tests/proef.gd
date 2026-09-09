class_name Proef
extends RefCounted
## The two lines of test framework this project needs.

var _fouten := 0
var _meldingen: Array[String] = []
var _runner = null

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
