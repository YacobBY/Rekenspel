extends SceneTree
## W4 measuring stick — NOT a test, so it does not start with `test_`.
## Prints the numbers architecture.md §3.5 and §8 budget against:
##
##   godot --headless --path godot/dierenhotel --script res://tests/gouden/_meet.gd
##
## The browser half of §3.5 has its own measuring stick: export the game and
## open it as `index.html?bakmeting` (see `Art._bakmeting`), or run
## `node .fanout/scratch/w4/probe-bak.js`.
##
## (This file lives in a `.gdignore`d folder, so it is never exported and the
## autoloads are reached through the tree instead of by their global name.)

func _initialize() -> void:
	await process_frame
	var Art = root.get_node("Art")
	var Snd = root.get_node("Snd")
	var Gasten = load("res://art/gasten.gd")

	print("== bak per plaat (ms) ==")
	var namen := ["hok", "boom", "kast", "balie", "bed", "kar", "prikbord", "plant",
		"mand", "kist", "lamp", "bal"]
	for g in [2, 3, 4]:
		var som := 0.0
		var ergst := 0.0
		var ergste := ""
		for n in namen:
			Art.wis_platen()
			var vox: Array = Art.model(n)
			var t0 := Time.get_ticks_usec()
			Art.bak(vox, g)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			som += ms
			if ms > ergst:
				ergst = ms
				ergste = n
		print("  g=%d  gemiddeld %5.1f ms  ergste %s %5.1f ms  (%d modellen)"
			% [g, som / namen.size(), ergste, ergst, namen.size()])
	for g in [2, 3, 4]:
		Art.wis_platen()
		var t0 := Time.get_ticks_usec()
		Art.dier("hond", "rust", g)
		print("  gast_hond rust g=%d: %5.1f ms" % [g, (Time.get_ticks_usec() - t0) / 1000.0])

	print("== koude bak van een kamerset (het reisvenster is 300 ms) ==")
	var receptie := ["balie", "balie", "baliez", "baliez", "bel", "kassa", "boek",
		"lamp", "prikbord", "sleutelbordz", "plant", "mat", "kom"]
	var gasten := ["gast_hond", "gast_poes", "gast_konijn", "gast_gans"]
	for g in [2, 3, 4]:
		Art.wis_platen()
		var t0 := Time.get_ticks_usec()
		for n in receptie:
			Art.plaat(n, g)
		for n in gasten:
			Art.plaat(n, g, {"pose": "rust"})
		var koud := (Time.get_ticks_usec() - t0) / 1000.0
		var t1 := Time.get_ticks_usec()
		for n in receptie:
			Art.plaat(n, g)
		print("  receptie g=%d: koud %6.1f ms (%d platen), warm %6.3f ms"
			% [g, koud, Art.platen_in_cache(), (Time.get_ticks_usec() - t1) / 1000.0])
	Art.wis_platen()
	for n in receptie:
		Art.plaat(n, 4)
	var t2 := Time.get_ticks_usec()
	for n in receptie:
		Art.plaat(n, 3)
	print("  dezelfde kamer op een andere g: %6.1f ms (vlakkencache)"
		% ((Time.get_ticks_usec() - t2) / 1000.0))
	# (There is no floor plate to measure: `scenes/vloer.gd` draws the floor as
	# one ArrayMesh and `ArtVloer.kleur()` is only the colour table it reads.)

	print("== LRU ==")
	Art.wis_platen()
	for kind in Gasten.SOORTEN:
		for pose in Gasten.POSE.keys():
			for g in [2, 3, 4]:
				Art.dier(kind, pose, g)
	print("  180 platen gevraagd -> %d in de cache (PLAAT_MAX %d)"
		% [Art.platen_in_cache(), Art.PLAAT_MAX])

	print("== geluid tegen de WAV-export ==")
	var meta = JSON.parse_string(FileAccess.get_file_as_string("res://tests/gouden/snd-oracle.json"))
	var ref := {}
	for m in meta:
		ref[m["naam"]] = m
	var t4 := Time.get_ticks_usec()
	for naam in Snd.namen():
		Snd.stream(naam)
	print("  18 geluiden genereren + wav: %.1f ms" % ((Time.get_ticks_usec() - t4) / 1000.0))
	for naam in Snd.namen():
		var ronden: int = 48 if Snd.is_ruis(naam) else 1
		var som := 0.0
		var lengtes: Array[int] = []
		for i in ronden:
			var buf: PackedFloat32Array = Snd.monster(naam)
			var piek := 0.0
			var laatst := 0
			for j in buf.size():
				var a := absf(buf[j])
				if a > piek: piek = a
				if a > 0.001: laatst = j
			som += piek
			lengtes.append(int(round(1000.0 * float(laatst) / float(Snd.SR))))
		lengtes.sort()
		var db := 20.0 * log(maxf(som / ronden, 1e-9)) / log(10.0)
		var ms: int = lengtes[ronden / 2]
		var r: Dictionary = ref[naam]
		var rdb: float = float(r["runs"]["dB_gem"]) if Snd.is_ruis(naam) else float(r["dBFS"])
		print("  %-6s %7.2f dB (ref %6.2f, %+5.2f)  %4d ms (ref %4d, %+3d)%s"
			% [naam, db, rdb, db - rdb, ms, int(r["duurMs"]), ms - int(r["duurMs"]),
			"   verse ruis; ref = gemiddelde van 8 export-runs" if Snd.is_ruis(naam) else ""])
	quit(0)
