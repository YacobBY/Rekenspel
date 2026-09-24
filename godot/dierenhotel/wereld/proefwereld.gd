extends RefCounted
## The vertical slice of the world, for the browser probe of architecture.md
## §14.4 — and for nothing else.
##
## In the real game the guests come from the hotel: `Hotel.start()` puts the
## saved guests back and the bell checks new ones in, so a fresh hotel is
## deliberately empty until a child rings.  A probe cannot ring a bell that is
## being written in another ticket, so this file checks three guests in by hand
## and prints one machine-readable line per fact.
##
## It only ever runs when it is ASKED for:
##   web       index.html?demo=1
##   desktop   godot --path godot/dierenhotel -- --demo
## Without that flag `aan()` is false and not a single line of this file runs,
## so it can never change what a child sees.

const GASTEN := [
	{"id": "boef", "naam": "Boef", "kind": "hond"},
	{"id": "muis", "naam": "Muis", "kind": "poes"},
	{"id": "wolkje", "naam": "Wolkje", "kind": "konijn"},
]

## `?demo=1&rondje=1` / `-- --demo --rondje` also walks the whole hotel: one
## guest goes to bed in kamer1, one goes swimming, and the camera visits every
## room in turn, so a probe can look at all eight of them.
static func rondje() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--rondje":
			return true
	if OS.has_feature("web"):
		var zoek = JavaScriptBridge.eval("location.search", true)
		if zoek != null and str(zoek).contains("rondje=1"):
			return true
	return false

static func aan() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo" or arg == "demo":
			return true
	if OS.has_feature("web"):
		var zoek = JavaScriptBridge.eval("location.search", true)
		if zoek != null and str(zoek).contains("demo=1"):
			return true
	return false

## Check the guests in, walk two of them, and report.
func start() -> void:
	if not Rooms.bestaat("receptie"):
		return
	if not World.kamer_veranderd.is_connected(_op_kamer):
		World.kamer_veranderd.connect(_op_kamer)
	World.naar("receptie")
	var r := Rooms.get_kamer("receptie")
	var i := 0
	for g in GASTEN:
		var plek: Array = r.plekken[(i * 3 + 1) % r.plekken.size()]
		World.zet(g["id"], "receptie", plek[0], plek[1],
			{"naam": g["naam"], "kind": g["kind"], "nr": i})
		i += 1
	print("[probe] proef=gasten n=", World.dieren("receptie").size(),
		" kamer=", World.kamer_nu(), " decor=", r.decor.size(),
		" plekken=", r.plekken.size())
	_wandel("boef", 0)
	_wandel("muis", 1)
	await Engine.get_main_loop().create_timer(1.4).timeout
	# no door button of our own: the hotel builds one per door (world.md §6.3),
	# and two buttons for one door is one button too many
	var deur := Hits.spot("deur_receptie_tuin")
	if deur != null and is_instance_valid(deur.knoop):
		print("[probe] proef=deurknop=", deur.knoop.get_global_rect(),
			" dekking=", "%.2f" % Hits.dekking("deur_receptie_tuin"))
	print("[probe] proef=klaar")
	if rondje():
		_rondje()

## Put one guest to bed, send one swimming, and visit every room.
func _rondje() -> void:
	World.slaap("wolkje", "kamer1", "bed1")
	_zwemmen("muis")
	for kamer in Rooms.lijst():
		await Engine.get_main_loop().create_timer(2.2).timeout
		World.naar(kamer)
		var r := Rooms.get_kamer(kamer)
		print("[probe] proef=rondje=", kamer, " decor=", r.decor.size(),
			" slots=", r.slots.size(), " platen=", Art.gebakken(),
			" fps=", "%.0f" % Engine.get_frames_per_second())
	print("[probe] proef=rondje=af")

## A guest walks to the pool and swims a length; `pose: "zwem"` sinks him 7
## voxels and the room scene puts the water band over his lower half.
func _zwemmen(id: String) -> void:
	World.reis(id, "zwembad", {"x": 12.0, "z": 56.0, "na": "wacht"})
	var d := World.dier(id)
	var t := 0
	while d.kamer != "zwembad" and t < 900:
		await Engine.get_main_loop().process_frame
		t += 1
	if d.kamer != "zwembad":
		return
	var baan: Array = []
	for i in 12:
		baan.append(Vector2(18.0 + i * 10.0, 28.0))
	var gehaald: bool = await World.stappen(id, baan, {"pose": "zwem", "na": "zwem"})
	print("[probe] proef=zwemmen id=", id, " gehaald=", gehaald,
		" hoogte=", d.hoogte, " staat=", d.staat)

## Any room switch, whoever asked for it — the hotel's own door hotspot or the
## button below.
func _op_kamer(kamer_id: String) -> void:
	print("[probe] proef=kamer=", kamer_id, " dieren=", World.dieren(kamer_id).size(),
		" decor=", Rooms.get_kamer(kamer_id).decor.size())

## Two guests walk to opposite corners of the receptie; the awaited walk
## resolves true when the animal is exactly on the point it was given.
func _wandel(id: String, nr: int) -> void:
	var r := Rooms.get_kamer("receptie")
	var d := World.dier(id)
	if r == null or d == null or r.plekken.is_empty():
		return
	var beste: Array = r.plekken[0]
	var ver := -1.0
	for p in r.plekken:
		# guest 0 walks as far away as it can, guest 1 as far from guest 0
		var vanaf: Array = [d.x, d.z] if nr == 0 else r.plekken[r.plekken.size() - 1]
		var af: float = absf(p[0] - vanaf[0]) + absf(p[1] - vanaf[1])
		if af > ver:
			ver = af
			beste = p
	var doel := Vector2(beste[0], beste[1])
	var t0 := World.tikken()
	var gehaald: bool = await World.stappen(id, [doel])
	var na := World.dier(id)
	if na == null:
		return
	print("[probe] proef=gelopen id=", id, " naar=", doel, " gehaald=", gehaald,
		" tikken=", World.tikken() - t0, " plek=(%.1f, %.1f)" % [na.x, na.z])
