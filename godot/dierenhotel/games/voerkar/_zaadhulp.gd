extends RefCounted
## Wegwerp (zie _zaad.gd).

const UIT := "res://../../.fanout/scratch/godot-g-voerkar/opslag"

func doe() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UIT))
	for band in [3, 4, 5]:
		_maak(band)

func _maak(band: int) -> void:
	State.nieuw_spel()
	State.start_gekozen()
	var n := 1 if band == 3 else (4 if band == 4 else 7)
	if n > State.alle_bedden().size():
		_extra_bedden(n)
	var pool := State.gasten_pool()
	var bedden := State.alle_bedden()
	var uit: Array = []
	for i in n:
		var g: Dictionary = pool[i]
		g["kamer"] = str(bedden[i]["kamer"])
		g["bed"] = str(bedden[i]["slot"])
		g["waar"] = g["kamer"]
		g["nachten"] = 100
		g["behoefte"] = "eten"
		uit.append(g)
	State.s["gasten"] = uit
	State.s["kamerNu"] = "keuken"
	State.s["ronde"] = "vrij"
	State.s["dag"] = 1 if band == 3 else (3 if band == 4 else 5)
	State.s["kunnen"] = maxi(3, band - 1)
	State.s["meubels"] = Rooms.meubels()
	State.s["meubelNr"] = Rooms.nr_stand()
	State.herbereken()
	State.bewaar()
	var bron := FileAccess.open(State.PAD, FileAccess.READ)
	if bron == null:
		print("FOUT: kon de savegame niet lezen")
		return
	var tekst := bron.get_as_text()
	bron.close()
	var pad := "%s/band%d.json" % [UIT, band]
	var doel := FileAccess.open(pad, FileAccess.WRITE)
	doel.store_string(tekst)
	doel.close()
	print("band ", band, ": gasten=", n, " bedden=", State.alle_bedden().size(),
		" band()=", State.band(), " -> ", ProjectSettings.globalize_path(pad),
		" (", tekst.length(), " tekens)")
	Rooms.herstel()

func _extra_bedden(nodig: int) -> void:
	var plekken := [[78.0, 27.0], [78.0, 75.0], [54.0, 27.0], [54.0, 75.0]]
	for kamer in ["kamer1", "kamer2"]:
		for p in plekken:
			if State.alle_bedden().size() >= nodig:
				return
			Rooms.meubel_zet(kamer, "bed", p[0], p[1])
