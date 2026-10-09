extends Proef
## The owner (2026-10-08): "rekenen moet minstens 50% van de interactie zijn"
## and "het moet niet mogelijk zijn om rekenen over te slaan".  Every maths
## game proves R1 (golf2-regels.md: reken >= spel + 1 per turn, the tap that
## opened the game not counted) in its own `test_rekenaandeel`, and since VA
## (2026-10-09) that test asserts the REAL classifier, `Reken.beurt()`, next to
## its own counter.  This file makes that rule hold for every game that will
## ever be registered: a maths game without such a test fails here, so a new
## game cannot skip it.  A static check over the test files.

## Games whose turns are tested in a shared test file under `games/_<naam>/`
## (the stalls of the shopping arcade share `WinkelSpel`): such a file covers
## a game when it names the id in one of its `const` lists.
const GEDEELD := "res://games"

## Every registered game that has to prove R1: not a stub (`_voorbeeld`, never
## shown) and not a free-play game (`vrij: true`, the paskamer — its entry is
## refused during a rekenmoment and it closes when the budget runs out).
func _rekenspellen() -> Array[String]:
	var uit: Array[String] = []
	for id in Games.lijst():
		var def := Games.definitie(id)
		if bool(def.get("stub", false)) or bool(def.get("vrij", false)):
			continue
		uit.append(id)
	return uit

## The test files of a game's own folder.
func _eigen_tests(id: String) -> Array[String]:
	var uit: Array[String] = []
	var map := "%s/%s" % [GEDEELD, id]
	for f in DirAccess.get_files_at(map):
		if f.begins_with("test_") and f.ends_with(".gd"):
			uit.append("%s/%s" % [map, f])
	return uit

## The test files of the shared folders (`games/_winkel/`, ...) that name `id`
## in a `const` list of the games they walk through.
func _gedeelde_tests(id: String) -> Array[String]:
	var uit: Array[String] = []
	for map in DirAccess.get_directories_at(GEDEELD):
		if not map.begins_with("_"):
			continue
		for f in DirAccess.get_files_at("%s/%s" % [GEDEELD, map]):
			if not (f.begins_with("test_") and f.ends_with(".gd")):
				continue
			var pad := "%s/%s/%s" % [GEDEELD, map, f]
			for regel in FileAccess.get_file_as_string(pad).split("\n"):
				if regel.begins_with("const ") and regel.contains("\"%s\"" % id):
					uit.append(pad)
					break
	return uit

## Does this test file prove R1 with the real classifier?  It has a
## `test_rekenaandeel` (or one per band) and it reads `Reken.beurt()`, and it
## compares that with `reken >= spel + 1`.
func _bewijst(pad: String) -> bool:
	var bron := FileAccess.get_file_as_string(pad)
	return bron.contains("func test_rekenaandeel") and bron.contains("Reken.beurt()") \
		and bron.contains(">= s + 1")

func test_elk_rekenspel_bewijst_het_rekenaandeel_met_de_echte_rekenwacht() -> void:
	var spellen := _rekenspellen()
	# the registry must really be there, or this test would pass on nothing
	waar(spellen.size() >= 20, "er zijn rekenspellen geregistreerd (%d)" % spellen.size())
	for id in ["bedden", "sleutels", "meubels", "tobbe", "voerkar", "zwembad", "wekker",
			"hinkel", "was", "kraam", "hoeden", "sjaals", "schoenen", "luxe", "foto", "oogst",
			"weeg", "spiegel", "koekjes", "band", "sterren", "post"]:
		waar(spellen.has(id), "%s telt als rekenspel" % id)
	for id in spellen:
		var bestanden := _eigen_tests(id) + _gedeelde_tests(id)
		var bewijs := ""
		for pad in bestanden:
			if _bewijst(pad):
				bewijs = pad
				break
		waar(not bewijs.is_empty(),
			"%s heeft een test_rekenaandeel die Reken.beurt() toetst (gezocht in %s)" % [
				id, str(bestanden)])

## The free-play game and the stub are the only ones left out, and on purpose.
func test_alleen_vrij_spel_en_stubs_vallen_erbuiten() -> void:
	var buiten: Array[String] = []
	for id in Games.lijst():
		if not _rekenspellen().has(id):
			buiten.append(id)
	for id in buiten:
		var def := Games.definitie(id)
		waar(bool(def.get("stub", false)) or bool(def.get("vrij", false)),
			"%s valt alleen buiten de regel als stub of als vrij spel" % id)
	waar(buiten.has("paskamer"), "de paskamer is vrij spel")

## The check-in and the bill are no game (`Reken.beurt()` stays still at the
## desk), so their R1 test reads the real totals instead.
func test_de_balie_bewijst_het_rekenaandeel_met_de_echte_rekenwacht() -> void:
	var bron := FileAccess.get_file_as_string("res://tests/test_hotel_rekenen.gd")
	waar(bron.contains("func test_rekenaandeel_checkin_en_rekening"),
		"de check-in en de rekening hebben een rekenaandeeltest")
	waar(bron.contains("Reken.totaal()"), "die de echte Rekenwacht leest")

## The static check itself catches a game without the proof: a file with only
## the in-test counter does not count.
func test_een_teller_alleen_is_geen_bewijs() -> void:
	var pad := "user://va_proef_test.gd"
	var f := FileAccess.open(pad, FileAccess.WRITE)
	f.store_string("func test_rekenaandeel() -> void:\n\tvar r := 2\n\tvar s := 0\n\tassert(r >= s + 1)\n")
	f.close()
	waar(not _bewijst(pad), "zonder Reken.beurt() is er geen bewijs")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pad))
