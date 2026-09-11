extends Proef
## Every child-facing string literal in the games and the hotel is covered by
## the bundled font subset (architecture.md §7.5, I2 item 23).  Meubels found
## ↩ and ＋ rendering as tofu in the real export; this test catches the next one
## before it ships.  It reads the sources as text and pulls out every quoted
## literal — a superset of the child-facing strings, which is the safe side.

const MAPPEN := ["res://games", "res://hotel", "res://ui", "res://autoload"]

func test_alle_letterlijke_teksten_hebben_een_glyph() -> void:
	if Ui.thema == null or Ui.thema.default_font == null:
		Ui._bouw_thema(17)          # the shell stamps it at boot; headless we do it here
	waar(Ui.thema != null and Ui.thema.default_font != null, "het thema staat")
	var ontbreekt := {}
	var bestanden := 0
	for map in MAPPEN:
		for pad in _gd_bestanden(map):
			bestanden += 1
			var f := FileAccess.open(pad, FileAccess.READ)
			if f == null:
				continue
			var re := RegEx.new()
			re.compile("\"((?:[^\"\\\\]|\\\\.)*)\"")
			for m in re.search_all(f.get_as_text()):
				var zin: String = m.get_string(1)
				for c in Ui.mist_tekens(zin):
					if not ontbreekt.has(c):
						ontbreekt[c] = pad.get_file() + ": " + zin.left(40)
	waar(bestanden >= 20, "de bronnen zijn gevonden (%d bestanden)" % bestanden)
	for c in ontbreekt.keys():
		fout("teken %s (U+%04X) ontbreekt in de fontsubset — %s" % [c, c.unicode_at(0), ontbreekt[c]])

func _gd_bestanden(map: String) -> Array[String]:
	var uit: Array[String] = []
	var d := DirAccess.open(map)
	if d == null:
		return uit
	d.list_dir_begin()
	var naam := d.get_next()
	while naam != "":
		var pad := map.path_join(naam)
		if d.current_is_dir():
			if not naam.begins_with("."):
				uit.append_array(_gd_bestanden(pad))
		elif naam.ends_with(".gd") and not naam.begins_with("test_"):
			uit.append(pad)
		naam = d.get_next()
	d.list_dir_end()
	return uit
