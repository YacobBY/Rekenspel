extends Proef
## The minigame registry (architecture.md §6.1): a game is a DIRECTORY under
## `res://games/` with a `spel.tscn` in it, and the directory name is its id.
##
## That is what lets ten wave-2 workers run in parallel worktrees with zero
## merge conflicts: adding a game touches no shared file at all.  The scan must
## therefore keep working both in the editor tree and inside the exported PCK —
## the second half is proven by the browser probe, which prints `Games.lijst()`
## from the running wasm.

var _laag: Control = null

func _op() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = Vector2(1000, 648)
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	World.meet(Rect2(Vector2.ZERO, Vector2(1000, 648)))

func _af() -> void:
	Hits.wis_alles()
	Ui.registreer_lagen(null, null, null)
	if _laag != null:
		_laag.queue_free()
		_laag = null

## The scan itself: every `res://games/*/spel.tscn` is found, without any shared
## registry file existing anywhere in the project.
func test_map_scan_vindt_elk_spel() -> void:
	var mappen := DirAccess.get_directories_at(Games.MAP)
	var verwacht: Array[String] = []
	for map in mappen:
		if not map.begins_with(".") and ResourceLoader.exists("%s/%s/spel.tscn" % [Games.MAP, map]):
			verwacht.append(map)
	verwacht.sort()
	waar(verwacht.size() >= 1, "er staat minstens één spel in res://games")
	gelijk(str(Games.lijst()), str(verwacht), "de scan vindt precies die mappen")
	waar(Games.lijst().has("_voorbeeld"), "het voorbeeldspel hoort erbij")
	# no shared registry file may have crept back in
	for pad in ["res://games/_lijst.json", "res://games/registry.gd", "res://games/lijst.gd"]:
		waar(not ResourceLoader.exists(pad) and not FileAccess.file_exists(pad),
			"geen gedeeld registerbestand (%s)" % pad)

## `definitie()` is read once, with the scene OUTSIDE the tree.
func test_definitie_wordt_gelezen() -> void:
	var def := Games.definitie("_voorbeeld")
	gelijk(def.get("naam", ""), "Voorbeeld", "definitie().naam")
	gelijk(def.get("kamer", ""), "gang", "definitie().kamer")
	gelijk(def.get("id", ""), "_voorbeeld", "de mapnaam IS het id")
	waar(def.has("hotspot"), "en er hangt een ingangsknop aan")
	gelijk(Games.definitie("bestaat-niet"), {}, "een onbekend spel geeft niets")

## `unlock(N, band)` decides whether a game may be played; absent means yes.
func test_ontgrendeling() -> void:
	waar(Games.ontgrendeld("_voorbeeld"), "het voorbeeld is altijd te spelen")
	waar(not Games.ontgrendeld("bestaat-niet"), "wat er niet is, is niet te spelen")

## An unknown game never leaves the child staring at a dead button: it toasts
## `💛 Probeer iets anders` and stays where it was (world.md §5.2 step 7).
func test_onbekend_spel_meldt_zich() -> void:
	_op()
	waar(not Games.start("bestaat-niet"), "start() van een onbekend spel is false")
	gelijk(Games.actief(), "", "en er draait niets")
	var t: Control = _laag.get_node_or_null("Toast")
	waar(t != null, "er staat een toast")
	if t != null:
		gelijk(t.get_node("Label").text if t.has_node("Label") else _eerste_label(t),
			UiTekst.SPEL_MIS, "en die zegt het woordelijk")
	_af()

func _eerste_label(k: Node) -> String:
	for kind in k.get_children():
		if kind is Label:
			return (kind as Label).text
		var diep := _eerste_label(kind)
		if not diep.is_empty():
			return diep
	return ""

## The entry button hangs ON its own object, covers 0 % of it, and disappears
## while its own game is running (world.md §5.1).
func test_ingangsknop_hangt_aan_zijn_voorwerp() -> void:
	_op()
	var def := Games.definitie("_voorbeeld")
	var kamer := str(def.get("kamer", ""))
	if not Rooms.bestaat(kamer):
		return                       # the placeholder room went with W1; nothing to hang on
	World.naar(kamer)
	World.meet(Rect2(Vector2.ZERO, Vector2(1000, 648)))
	Games.hersteek()
	Hits.plaats()
	var s := Hits.spot("spel__voorbeeld")
	waar(s != null, "de ingangsknop staat er")
	if s != null:
		gelijk(s.door, "registry", "de eigenaar is het register")
		# `op: aan` (owner, 2026-09-14): a big thing like the chest may carry
		# its button; a small one keeps it just above or below
		var d: Dictionary = Hits.debug()["spel__voorbeeld"]
		waar(Hits.dekking("spel__voorbeeld") <= 0.0 or str(d["op"]) == "aan",
			"de knop hangt aan zijn voorwerp (%s, %.1f %%)" % [d["op"], Hits.dekking("spel__voorbeeld")])
		var r: Rect2 = Hits.debug()["spel__voorbeeld"]["rect"]
		waar(r.size.x >= 48.0 and r.size.y >= 48.0, "en is een tikdoel")
	_af()

## One turn through the lifecycle: start stamps the owner and gives the game
## priority, stop wipes everything the game placed and hands the buttons back.
func test_levensloop_ruimt_alles_op() -> void:
	_op()
	var def := Games.definitie("_voorbeeld")
	if not Rooms.bestaat(str(def.get("kamer", ""))):
		_af()
		return
	# owner "keurmeester": anything but "hotel", whose own render() legitimately
	# rebuilds its buttons while the game starts
	Hits.maak({"id": "hotelknop", "kamer": World.kamer_nu(), "x": 8.0, "z": 8.0, "y": 10.0,
		"icoon": "🔔", "label": "Bel", "door": "keurmeester", "aan": func(_s) -> void: pass})
	waar(Games.start("_voorbeeld"), "het spel start")
	gelijk(Games.actief(), "_voorbeeld", "en is actief")
	gelijk(Hits.voorrang_van(), "_voorbeeld", "en heeft voorrang")
	var eigen := 0
	for id in Hits.lijst():
		if Hits.spot(id).door == "_voorbeeld":
			eigen += 1
	waar(eigen >= 1, "het spel plaatste eigen hotspots (%d)" % eigen)
	Games.stop()
	gelijk(Games.actief(), "", "na stop draait er niets meer")
	gelijk(Hits.voorrang_van(), "", "en niemand heeft voorrang")
	for id in Hits.lijst():
		waar(Hits.spot(id).door != "_voorbeeld", "geen hotspot van het spel bleef staan: %s" % id)
	waar(Hits.spot("hotelknop") != null, "de knop van een andere eigenaar bleef staan")
	gelijk(World.decor_lijst().filter(func(d): return d["door"] == "_voorbeeld").size(), 0,
		"en het losse decor van het spel is weg")
	_af()

## `ctx` stamps everything the game places, so "supersede = full stop" is free.
func test_ctx_stempelt_de_eigenaar() -> void:
	_op()
	var ctx := SpelCtx.new("proefspel", {"naam": "Proef", "kamer": World.kamer_nu()})
	gelijk(ctx.id, "proefspel", "ctx.id")
	gelijk(ctx.naam, "Proef", "ctx.naam")
	ctx.hotspots.maak({"id": "ps1", "kamer": World.kamer_nu(), "x": 8.0, "z": 8.0,
		"y": 10.0, "icoon": "🐾", "label": "Kijk"})
	ctx.ui.wolk({"id": "ps2", "kamer": World.kamer_nu(), "x": 8.0, "z": 8.0,
		"hoog": 20.0, "icoon": "💤", "tekst": "slaapt"})
	ctx.ui.getal_tag({"x": 8.0, "z": 8.0}, 3, {"id": "ps3"})
	for id in ["ps1", "ps2", "ps3"]:
		var s := Hits.spot(id)
		waar(s != null and s.door == "proefspel", "%s draagt de stempel van het spel" % id)
	ctx.hotspots.wis_alles()
	for id in ["ps1", "ps2", "ps3"]:
		waar(Hits.spot(id) == null, "%s is weg na wis_alles()" % id)
	_af()
