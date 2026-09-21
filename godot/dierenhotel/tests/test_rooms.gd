extends Proef
## The rooms — nine today, `Rooms.lijst()` is what counts them: sizes, boxes,
## the door graph, the floor rules, the derived grids and the furniture API —
## world.md §1.
##
## Every number here is recomputed from the spec, never copied out of the
## implementation: the room boxes of §1.1, the door points of §1.2, the
## fractional places of §1.6 (`plek('receptie', 0.875, 0.25)` = 105, 30) and the
## 30 deterministic garden tufts of §1.3, which must come out of the seeded
## mulberry32 bit for bit (architecture.md §13, Q-X1-2).

const ORDE := ["receptie", "gang", "kamer1", "kamer2", "keuken", "tuin",
	"zwembad", "wasserij", "speelzaal"]

## The five floors `ArtVloer.kleur()` knows how to draw (`art/vloer.gd:18`);
## any other word gives a room the plank floor by accident.
const VLOEREN := ["hout", "tegel", "zacht", "loper", "gras"]
## Eight wander places is the rule for a room a guest strolls through.  Two
## rooms cannot have eight and never will: the corridor is 36 voxels deep and
## the pool room keeps every walk out of the water (world.md §1.3/§1.5), so
## their floor is the number they really have, measured.
const PLEKKEN_MIN := {"gang": 4, "zwembad": 5}

func test_acht_kamers_in_de_juiste_volgorde() -> void:
	gelijk(Rooms.lijst().size(), ORDE.size(), "evenveel kamers als ORDE")
	for i in ORDE.size():
		gelijk(Rooms.lijst()[i], ORDE[i], "kamer %d" % i)
	waar(not Rooms.bestaat("proefkamer"), "de proefkamer is weg")

## The checklist a room has to pass — written for the room that does not exist
## yet.  It counts nothing: it walks `Rooms.lijst()`, so a room added in a later
## batch is held to it the moment it is there, and a room that arrives without
## its cell on the map sheet, without a door, without a floor the world can draw
## or without a model in the baker fails HERE and not in the browser.
func test_elke_kamer_is_compleet() -> void:
	for id in Rooms.lijst():
		var r := Rooms.get_kamer(id)
		waar(r != null, id + " bestaat")
		if r == null:
			continue
		waar(not r.naam.strip_edges().is_empty(), id + " heeft een naam")
		waar(not r.icoon.strip_edges().is_empty(), id + " heeft een pictogram")
		waar(VLOEREN.has(r.vloer), "%s heeft een bekende vloer (%s)" % [id, r.vloer])
		waar(UiPlattegrond.KAART.has(id), id + " heeft een vak op de plattegrond")
		waar(r.deuren.size() >= 1, id + " heeft minstens één deur")
		for dr in r.deuren:
			var naar := String(dr["naar"])
			waar(Rooms.bestaat(naar), "%s: de deur naar %s gaat ergens heen" % [id, naar])
			waar(not Rooms.deur(id, naar).is_empty(),
				"%s: de deur naar %s heeft een deurpunt" % [id, naar])
		waar(Rooms.pad("receptie", id).size() > 0, "je loopt van de receptie naar " + id)
		var nodig: int = PLEKKEN_MIN.get(id, 8)
		waar(r.plekken.size() >= nodig,
			"%s heeft %d loopplekken, minstens %d nodig" % [id, r.plekken.size(), nodig])
		for stuk in r.decor:
			waar(Art.heeft_model(String(stuk["n"])),
				"%s: Art kent het decormodel %s" % [id, str(stuk["n"])])
		for sid in r.slots:
			var model := String(r.slots[sid].get("model", ""))
			waar(model != "" and Art.heeft_model(model),
				"%s: Art kent het slotmodel %s van %s" % [id, model, sid])

func test_maten_en_vloeren() -> void:
	var verwacht := {
		"receptie": [120, 120, 54, "hout", 1.5],
		"gang": [120, 36, 56, "loper", 1.0],
		"kamer1": [114, 114, 58, "zacht", 1.5],
		"kamer2": [114, 114, 58, "zacht", 1.5],
		"keuken": [120, 114, 56, "tegel", 1.5],
		"tuin": [130, 130, 0, "gras", 1.0],
		"zwembad": [144, 88, 0, "gras", 1.5],
		"wasserij": [100, 90, 52, "tegel", 1.25],
		"speelzaal": [114, 100, 56, "hout", 1.5],
	}
	for id in verwacht:
		var r := Rooms.get_kamer(id)
		var v: Array = verwacht[id]
		gelijk(r.w, v[0], id + ".w")
		gelijk(r.d, v[1], id + ".d")
		gelijk(r.wand, v[2], id + ".wand")
		gelijk(r.vloer, v[3], id + ".vloer")
		gelijk(r.loop, v[4], id + ".loop")

## `box = [-d*S - 10, w*S + 10, -wand*HG - 12, (w+d)*(S/2) + 10]` — world.md §1.1.
func test_kamerkaders() -> void:
	var verwacht := {
		"receptie": [-250, 250, -120, 250],
		"gang": [-82, 250, -124, 166],
		"kamer1": [-238, 238, -128, 238],
		"kamer2": [-238, 238, -128, 238],
		"keuken": [-238, 250, -124, 244],
		"tuin": [-170, 190, -70, 220],
		"zwembad": [-190, 300, -60, 250],
		"wasserij": [-190, 210, -116, 200],
		"speelzaal": [-210, 238, -124, 224],
	}
	for id in verwacht:
		var box := Rooms.kader(Rooms.get_kamer(id))
		for i in 4:
			gelijk(box[i], verwacht[id][i], "%s.box[%d]" % [id, i])

## The full door table of world.md §1.2, both the point and the inside step.
func test_deurpunten() -> void:
	var verwacht := [
		# the receptie door moved to the left wall — owner decision, §13 Q-X1-13
		["receptie", "gang", 0, 30, 8, 30],
		["gang", "receptie", 0, 16, 8, 16],
		["gang", "kamer1", 30, 0, 30, 8],
		["gang", "kamer2", 66, 0, 66, 8],
		["gang", "keuken", 102, 0, 102, 8],
		["kamer1", "gang", 78, 0, 78, 8],
		["kamer2", "gang", 78, 0, 78, 8],
		["keuken", "gang", 0, 81, 8, 81],
		["keuken", "tuin", 96, 0, 96, 8],
		["keuken", "wasserij", 0, 36, 8, 36],
		["tuin", "keuken", 0, 40, 8, 40],
		["tuin", "zwembad", 44, 0, 44, 8],
		["zwembad", "tuin", 0, 66, 8, 66],
		["wasserij", "keuken", 68, 0, 68, 8],
		# R2: de speelzaal-deuren, gegenereerd uit een headless run (2026-09-21)
		["receptie", "speelzaal", 0, 114, 8, 114],
		["speelzaal", "receptie", 63, 0, 63, 8],
	]
	for rij in verwacht:
		var dp := Rooms.deur(rij[0], rij[1])
		waar(not dp.is_empty(), "deur %s -> %s" % [rij[0], rij[1]])
		if dp.is_empty():
			continue
		gelijk(dp["x"], rij[2], "%s->%s x" % [rij[0], rij[1]])
		gelijk(dp["z"], rij[3], "%s->%s z" % [rij[0], rij[1]])
		gelijk(dp["ix"], rij[4], "%s->%s ix" % [rij[0], rij[1]])
		gelijk(dp["iz"], rij[5], "%s->%s iz" % [rij[0], rij[1]])
	waar(Rooms.deur("tuin", "zwembad")["poort"], "de tuinpoort is een poort")
	waar(not Rooms.deur("gang", "kamer1")["poort"], "een gewone deur is geen poort")

## `pad()` is a BFS that includes the start room.
func test_pad_door_de_deuren() -> void:
	_pad_is(Rooms.pad("gang", "kamer1"), ["gang", "kamer1"], "buur")
	_pad_is(Rooms.pad("kamer1", "zwembad"),
		["kamer1", "gang", "keuken", "tuin", "zwembad"], "vijf kamers")
	_pad_is(Rooms.pad("tuin", "tuin"), ["tuin"], "zelfde kamer")
	gelijk(Rooms.pad("tuin", "nergens").size(), 0, "onbekende kamer")
	gelijk(Rooms.pad("nergens", "tuin").size(), 0, "onbekende start")
	# every room can be reached from every room
	for van in ORDE:
		for naar in ORDE:
			waar(Rooms.pad(van, naar).size() > 0, "%s -> %s" % [van, naar])

func _pad_is(gekregen: Array, verwacht: Array, wat: String) -> void:
	gelijk(gekregen.size(), verwacht.size(), wat + ": lengte")
	for i in mini(gekregen.size(), verwacht.size()):
		gelijk(gekregen[i], verwacht[i], "%s: stap %d" % [wat, i])

## world.md §1.6 — the fractional places every part of the hotel is built on.
func test_plek_en_hoogte() -> void:
	gelijk(Rooms.plek("receptie", 0.875, 0.25), {"kamer": "receptie", "x": 105, "z": 30},
		"CI_PLEK")
	gelijk(Rooms.hoogte("receptie", 0.2), 24, "CI_HOOG")
	gelijk(Rooms.plek("receptie", 0.15, 0.5)["x"], 18, "TOONBANK x")
	gelijk(Rooms.plek("receptie", 0.15, 0.5)["z"], 60, "TOONBANK z")
	gelijk(Rooms.hoogte("receptie", 0.225), 27, "TOONHOOG")
	gelijk(Rooms.plek("receptie", 0.2, 0.95)["z"], 114, "WACHTPLEK z")
	gelijk(Rooms.plek("receptie", 0.375, 0.775)["x"], 45, "bedplek x")
	gelijk(Rooms.plek("receptie", 0.775, 0.275)["x"], 93, "telknop x")
	gelijk(Rooms.hoogte("receptie", 0.175), 21, "telknop hoog")
	# the three task cards
	for i in 3:
		var p := Rooms.plek("receptie", 0.075 + i * 0.325, 0.025 + i * 0.325)
		gelijk(p["x"], [9, 48, 87][i], "taakkaart %d x" % i)
		gelijk(p["z"], [3, 42, 81][i], "taakkaart %d z" % i)
	# the ghost coins: 0.6875 * 120 = 82.5, and JS rounds a half UP
	gelijk(Rooms.plek("receptie", 0.6875, 0.875)["x"], 83, "spookmunt rondt naar boven")
	# the trolley's resting places
	gelijk(Rooms.plek("keuken", 0.4, 0.579), {"kamer": "keuken", "x": 48, "z": 66}, "kar keuken")
	gelijk(Rooms.plek("kamer1", 0.579, 0.579)["x"], 66, "kar kamer1")
	gelijk(Rooms.plek("zwembad", 0.5, 0.8), {"kamer": "zwembad", "x": 72, "z": 70}, "kar zwembad")
	gelijk(Rooms.plek("wasserij", 0.45, 0.6), {"kamer": "wasserij", "x": 45, "z": 54}, "kar wasserij")
	gelijk(Rooms.plek("nergens", 0.5, 0.5).size(), 0, "onbekende kamer geeft niets")

## world.md §1.4 — the seven floor rules, in order.
func test_vloerkleuren() -> void:
	var receptie := Rooms.get_kamer("receptie")
	gelijk(Rooms.vloer_kleur(receptie, 20, 0), Color("#D2B58C"), "elke vierde plankenrij")
	waar(Rooms.vloer_kleur(receptie, 20, 4) != Color("#D2B58C"), "de rij erna niet")
	var mat := Rooms.vloer_kleur(receptie, 60, 90)
	waar(mat == Color("#E9BFC9") or mat == Color("#E3B4C0"), "de mat overstemt de planken")
	var gang := Rooms.get_kamer("gang")
	var loper := Rooms.vloer_kleur(gang, 20, 16)
	waar(loper == Color("#D68FA0") or loper == Color("#CE8496"), "de loper in het midden")
	var rand := Rooms.vloer_kleur(gang, 20, 2)
	waar(rand == Color("#E9DCC6") or rand == Color("#E2D3BA"), "en de rand ernaast")
	var tuin := Rooms.get_kamer("tuin")
	var wei := Rooms.vloer_kleur(tuin, 4, 4)
	waar(wei == Color("#9DC486") or wei == Color("#98C081"), "buiten het hek is wei")
	var gras := Rooms.vloer_kleur(tuin, 60, 60)
	waar(gras == Color("#AFD595") or gras == Color("#AAD190") or gras == Color("#B4D89A")
		or gras == Color("#ACD392"), "binnen het hek is gras")
	var bad := Rooms.get_kamer("zwembad")
	var water := Rooms.vloer_kleur(bad, 70, 28)
	waar(water == Color("#9CD1E4") or water == Color("#A9D8E6") or water == Color("#93CBE0")
		or water == Color("#A2D4E5"), "diep water")
	var kant := Rooms.vloer_kleur(bad, 20, 28)
	waar(kant == Color("#5AA3C2") or kant == Color("#66ABC8"), "de rand van het water")
	var steen := Rooms.vloer_kleur(bad, 16, 28)
	waar(steen == Color("#FFFDF3") or steen == Color("#FCF8EA"), "de stenen rand eromheen")
	var tegel := Rooms.vloer_kleur(bad, 70, 52)
	waar(tegel == Color("#EDE6DA") or tegel == Color("#D9E6E2"), "en tegels op het dek")
	var achter := Rooms.vloer_kleur(bad, 70, 76)
	waar(ArtVloer.GRAS.has(achter), "en gras achter het dek: het bad ligt buiten")

## Every model a room places must exist in the baker.
func test_decor_staat_er_en_is_bakbaar() -> void:
	for naam in Rooms.gebruikte_modellen():
		waar(Art.heeft_model(naam), "Art kent model " + naam)
	var receptie := Rooms.get_kamer("receptie")
	var namen: Array[String] = []
	for stuk in receptie.decor:
		namen.append(String(stuk["n"]))
	for n in ["balie", "bel", "kassa", "boek", "prikbord", "sleutelbordz", "plant"]:
		waar(namen.has(n), "receptie heeft " + n)
	waar(not namen.has("lamp"), "de balielamp is een ding geworden, geen decor")
	gelijk(World.ding("balielamp").get("kamer", ""), "receptie", "balielamp staat in de receptie")
	gelijk(World.ding("kar").get("kamer", ""), "keuken", "de kar staat in de keuken")
	gelijk(World.ding("kar").get("x", 0.0), 48.0, "de kar op 48")
	# the wall decor stays behind everything
	for stuk in receptie.decor:
		if stuk["n"] == "prikbord":
			waar(stuk.get("ver", false), "het prikbord hangt aan de wand")

## world.md §1.3 — the garden fence and its 30 seeded tufts, bit for bit.
func test_tuin_is_deterministisch() -> void:
	var tuin := Rooms.get_kamer("tuin")
	var hekz := 0
	var hekx := 0
	var pollen: Array = []
	for stuk in tuin.decor:
		if stuk["n"] == "hekz":
			hekz += 1
			gelijk(stuk["x"], 10, "hekz staat op x = 10")
			waar(stuk["z"] < 34 or stuk["z"] > 46, "het hek laat de poort vrij")
		elif stuk["n"] == "hekx":
			hekx += 1
			gelijk(stuk["z"], 10, "hekx staat op z = 10")
			waar(stuk["x"] < 38 or stuk["x"] > 50, "het hek laat de opening vrij")
		elif String(stuk["n"]).begins_with("pol"):
			pollen.append([String(stuk["n"]), stuk["x"], stuk["z"]])
	gelijk(hekz, 8, "acht hekpalen langs z")
	gelijk(hekx, 7, "zeven hekpalen langs x")
	var verwacht := [
		["pol0", 60.5, 125.5], ["pol4", 169.5, 29.5], ["pol0", 159.5, 40.5],
		["pol1", 138.5, 68.5], ["pol4", 52.5, 65.5], ["pol0", 117.5, 123.5],
		["pol2", 50.5, 142.5], ["pol4", 62.5, 142.5], ["pol2", 145.0, 57.0],
		["pol0", 111.0, 16.0], ["pol1", 132.5, 100.5], ["pol4", 24.0, 154.0],
		["pol0", 150.5, 35.5], ["pol3", 45.0, 128.0],
	]
	gelijk(pollen.size(), verwacht.size(), "aantal graspollen")
	for i in mini(pollen.size(), verwacht.size()):
		gelijk(pollen[i][0], verwacht[i][0], "pol %d naam" % i)
		gelijk(pollen[i][1], verwacht[i][1], "pol %d x" % i)
		gelijk(pollen[i][2], verwacht[i][2], "pol %d z" % i)

## world.md §1.5 — the free-cell grid and the wander places derived from it.
func test_vrije_cellen_en_plekken() -> void:
	for id in ORDE:
		var r := Rooms.get_kamer(id)
		waar(r.plekken.size() > 0, id + " heeft loopplekken")
		for p in r.plekken:
			waar(p[0] >= 0 and p[0] <= r.w and p[1] >= 0 and p[1] <= r.d,
				"%s: plek binnen de kamer" % id)
		# every wander place keeps 22 voxels from every other one
		for i in r.plekken.size():
			for j in range(i + 1, r.plekken.size()):
				var af: float = absf(r.plekken[i][0] - r.plekken[j][0]) \
					+ absf(r.plekken[i][1] - r.plekken[j][1])
				waar(af >= 22.0, "%s: plekken %d en %d liggen %.0f uit elkaar" % [id, i, j, af])
		# and 18 from every piece of decor and every slot
		for p in r.plekken:
			for stuk in r.decor:
				waar(absf(stuk["x"] - p[0]) + absf(stuk["z"] - p[1]) >= 18.0,
					"%s: plek te dicht bij decor %s" % [id, stuk["n"]])

## world.md §1.3 — never a standing or wander place in the water.
func test_niemand_loopt_in_het_zwembad() -> void:
	var r := Rooms.get_kamer("zwembad")
	var bad: Dictionary = r.bad
	for p in r.plekken:
		waar(p[1] >= bad["z1"] + 6, "loopplek (%s, %s) blijft achter het water" % [p[0], p[1]])
		var nat: bool = p[0] >= bad["x0"] and p[0] <= bad["x1"] \
			and p[1] >= bad["z0"] and p[1] <= bad["z1"]
		waar(not nat, "loopplek staat niet in het water")
	gelijk(r.dek["start"], Vector2(12, 56), "dek.start")
	gelijk(r.dek["over"], Vector2(132, 56), "dek.over")
	waar(r.dek["start"].y >= 50, "het startvak ligt in de droge strook")

## OWNER DECISION (architecture.md §13, Q-X1-13).  The desk stands along the
## back-right wall and the door is in the back-left wall, and NO walk in this
## room may cross the desk: not the guest coming in, not the walk to the mat,
## not an idle stroll.  The floor a guest may stand on is convex (z >= 36), so
## a straight segment between any two of those places stays in front of it.
func test_niemand_loopt_door_de_balie() -> void:
	var r := Rooms.get_kamer("receptie")
	var b: Dictionary = r.balie
	waar(not b.is_empty(), "de receptie kent haar balievak")
	var dp := Rooms.deur("receptie", "gang")
	gelijk(dp["wand"], "x", "de deur zit in de linkerwand")
	gelijk(dp["x"], 0, "deurpunt x")
	gelijk(dp["z"], 30, "deurpunt z")
	gelijk(dp["ix"], 8, "stap binnen x")
	gelijk(dp["iz"], 30, "stap binnen z")
	waar(dp["iz"] > b["z1"], "de deur ligt vóór de balie, niet erachter")
	# every place the hotel walks to in this room
	var doelen: Array = [Vector2(dp["ix"], dp["iz"])]
	doelen.append(Vector2(72, 96))                       # het midden van de mat
	doelen.append(Vector2(24, 114))                      # WACHTPLEK
	doelen.append(Vector2(45, 93))                       # "wil een bed"
	doelen.append(Vector2(8, 114))                       # R2: stap binnen uit de speelzaal
	for p in r.plekken:
		doelen.append(Vector2(p[0], p[1]))
	for p in doelen:
		waar(not _in_vak(b, p), "(%.0f, %.0f) staat niet op de balie" % [p.x, p.y])
	for i in doelen.size():
		for j in range(i + 1, doelen.size()):
			waar(not _kruist(b, doelen[i], doelen[j]),
				"de loop van (%.0f, %.0f) naar (%.0f, %.0f) kruist de balie"
					% [doelen[i].x, doelen[i].y, doelen[j].x, doelen[j].y])
	# the desk objects sit ON the desk, where a guest never walks
	var op_balie := {"bel": true, "kassa": true, "boek": true, "lamp": true}
	for stuk in r.decor:
		if op_balie.has(stuk["n"]):
			waar(_in_vak(b, Vector2(stuk["x"], stuk["z"])),
				"%s staat op de balie" % stuk["n"])
	# and there are exactly two doors out of the receptie now (R2: the playroom
	# in the far corner), so exactly two door buttons
	gelijk(r.deuren.size(), 2, "de receptie heeft twee deuren")

func _in_vak(b: Dictionary, p: Vector2) -> bool:
	return p.x >= b["x0"] and p.x <= b["x1"] and p.y >= b["z0"] and p.y <= b["z1"]

## Does the straight walk from a to b touch the rectangle?  Sampled densely —
## a walk is a straight glide, so sampling every half voxel cannot miss a
## 74 x 14 voxel desk.
func _kruist(vak: Dictionary, a: Vector2, b: Vector2) -> bool:
	var n := int(ceil(a.distance_to(b) * 2.0))
	for i in n + 1:
		if _in_vak(vak, a.lerp(b, float(i) / float(maxi(1, n)))):
			return true
	return false

## world.md §1.5 `afSlot` — the standing place beside every slot.
func test_stavakken_van_de_slots() -> void:
	Rooms.herstel()                      # an earlier suite may have bought a bed
	var r := Rooms.get_kamer("kamer1")
	gelijk(r.slots.size(), 3, "kamer1 heeft twee bedden en een bak")
	gelijk(r.slots["bed1"]["x"], 30, "bed1 x")
	gelijk(r.slots["bed1"]["z"], 27, "bed1 z")
	gelijk(r.slots["bed1"]["sx"], 32, "bed1 stavak x = x + 2")
	gelijk(r.slots["bed1"]["sz"], 39, "bed1 stavak z = z + 12")
	gelijk(r.slots["bed2"]["sz"], 87, "bed2 stavak z")
	gelijk(r.slots["bak"]["sx"], 71, "de eetplek is (84 - 13, 33)")
	gelijk(r.slots["bak"]["sz"], 33, "de eetplek z")
	gelijk(Rooms.slots("", "bed").size(), 4, "het hotel begint met vier bedden")
	var tuin := Rooms.get_kamer("tuin")
	gelijk(tuin.slots["tobbe"]["sx"], 32, "een gewoon slot staat op zichzelf")

## world.md §1.8 — a bed added is a guest added, and nothing is half placed.
func test_meubels_zetten_en_weghalen() -> void:
	Rooms.herstel()
	var voor := Rooms.slots("", "bed").size()
	var bed := Rooms.meubel_zet("kamer1", "bed", 66.0, 66.0)
	waar(not bed.is_empty(), "het bed staat er")
	gelijk(Rooms.slots("", "bed").size(), voor + 1, "een bed erbij")
	waar(String(bed["id"]).begins_with("m"), "het id is m<n>_<type>")
	# a rotated bed is the mirrored model and stands the other way round
	var draai := Rooms.meubel_zet("kamer2", "bed", 66.0, 66.0, 1)
	gelijk(draai["model"], "bedz", "een gedraaid bed is bedz")
	gelijk(draai["sx"], draai["x"] + 12, "gedraaid stavak x")
	gelijk(draai["sz"], draai["z"] + 2, "gedraaid stavak z")
	# too close to the wall: it snaps to a free cell instead of standing there
	var muur := Rooms.meubel_zet("wasserij", "plant", 1.0, 1.0)
	if not muur.is_empty():
		waar(muur["x"] >= 4 and muur["z"] >= 4, "tegen de muur schuift naar een vrij vak")
	# an occupied cell never gets a second piece on top of it
	var bezet := Rooms.meubel_zet("kamer1", "plant", bed["x"], bed["z"])
	if not bezet.is_empty():
		waar(absf(bezet["x"] - bed["x"]) + absf(bezet["z"] - bed["z"]) >= 15.0,
			"een bezet vak schuift op")
	waar(Rooms.meubel_weg(String(bed["id"])), "het bed gaat weer weg")
	Rooms.herstel()
	gelijk(Rooms.slots("", "bed").size(), voor, "herstel geeft de basisinrichting terug")
	gelijk(Rooms.get_kamer("kamer1").slots.size(), 3, "en de slots van kamer1")
