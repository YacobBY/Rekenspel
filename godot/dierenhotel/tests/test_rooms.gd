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
	"zwembad", "wasserij", "speelzaal", "kas"]

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
		# R3: de kas, zo groot als de receptie-doos (twee spellen en negen
		# meubels, en toch ≥ 8 loopplekken)
		"kas": [128, 112, 40, "tegel", 1.25],
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
		"kas": [-234, 266, -92, 250],
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
		# the garden door moved into the corner at the end of the kitchen run
		# (owner, 2026-09-23): in front of x 90..102 the fridge hid it
		["keuken", "tuin", 110, 0, 110, 8],
		["keuken", "wasserij", 0, 36, 8, 36],
		["tuin", "keuken", 0, 40, 8, 40],
		["tuin", "zwembad", 44, 0, 44, 8],
		["zwembad", "tuin", 0, 66, 8, 66],
		["wasserij", "keuken", 68, 0, 68, 8],
		# R2: de speelzaal-deuren, gegenereerd uit een headless run (2026-09-21)
		["receptie", "speelzaal", 0, 114, 8, 114],
		["speelzaal", "receptie", 63, 0, 63, 8],
		# R3: de glazen deur van de kas in de achtergevel, waar het keukenraam
		# hing, en de tuindeur van de kas midden in haar achterwand
		["tuin", "kas", 0, 68, 8, 68],
		["kas", "tuin", 58, 0, 58, 8],
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
	# the kitchen's back door is a door on both sides now: a hole in the
	# kitchen wall and a door in the hotel's facade in the garden
	waar(not Rooms.deur("keuken", "tuin")["poort"], "de keuken heeft een echte tuindeur")
	waar(not Rooms.deur("tuin", "keuken")["poort"], "de tuin gaat door een deur de keuken in")

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
##
## Since 2026-09-23 the garden's left side is the hotel's back wall, so there
## is no side fence (`hekz`), the back fence starts at the wall's corner, and
## the tufts keep clear of the props where they stand now; the table below was
## regenerated from a headless run, once.
func test_tuin_is_deterministisch() -> void:
	var tuin := Rooms.get_kamer("tuin")
	var hekz := 0
	var hekx := 0
	var pollen: Array = []
	for stuk in tuin.decor:
		if stuk["n"] == "hekz":
			hekz += 1
		elif stuk["n"] == "hekx":
			hekx += 1
			gelijk(stuk["z"], 10, "hekx staat op z = 10")
			waar(stuk["x"] < 38 or stuk["x"] > 50, "het hek laat de opening vrij")
		elif String(stuk["n"]).begins_with("pol"):
			pollen.append([String(stuk["n"]), stuk["x"], stuk["z"]])
	gelijk(hekz, 0, "geen zijhek: daar staat de achtergevel van het hotel")
	gelijk(hekx, 8, "acht hekpalen langs x, de eerste bij de hoek van de gevel")
	var verwacht := [
		["pol0", 60.5, 125.5], ["pol2", 92.0, 14.0], ["pol4", 169.5, 29.5],
		["pol0", 159.5, 40.5], ["pol1", 138.5, 68.5], ["pol4", 52.5, 65.5],
		["pol0", 117.5, 123.5], ["pol2", 50.5, 142.5], ["pol4", 62.5, 142.5],
		["pol2", 145.0, 57.0], ["pol0", 111.0, 16.0], ["pol1", 132.5, 100.5],
		["pol4", 24.0, 154.0], ["pol0", 150.5, 35.5], ["pol3", 45.0, 128.0],
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
	gelijk(r.dek["over"], Vector2(116, 56), "dek.over, naast de vlag en niet in zijn voet")
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

# ------------------------------------------------------------ de overgangen

## The floor plate, for the pure helpers of its door drawing.
const VLOER := preload("res://scenes/vloer.gd")

## OWNER, 2026-09-23: "Ook andere ruimtes als keuken naar tuin hebben geen mooie
## overgang die sprekend is".  Through every door you see the floor of the room
## it leads to, and only the floor its opening lets through.  That view is never
## just more of the room you stand in, and no two doors of one room show the
## same thing — the kitchen and the laundry share their tiles, the reception
## and the playroom their planks, which is why those rooms point their view
## (`kijk`) at their runner, bath mat and rug.
func test_elke_deur_laat_zien_waar_hij_heen_gaat() -> void:
	for id in Rooms.lijst():
		var r := Rooms.get_kamer(id)
		var eigen := _vloerkleuren(r)
		var gezien: Array = []
		for dr in r.deuren:
			if dr.get("poort", false):
				continue
			var naar := String(dr["naar"])
			var hoog := float(Rooms.deur_hoog(r, dr))
			var tegels: Array = VLOER.doorkijk_tegels(dr, Rooms.get_kamer(naar), hoog)
			waar(tegels.size() >= 12,
				"%s -> %s: de opening laat vloer zien (%d tegels)" % [id, naar, tegels.size()])
			var zicht: Array = VLOER.doorkijk_zicht(dr, hoog)
			var binnen := true
			var kleuren := {}
			for t in tegels:
				kleuren[(t["kl"] as Color).to_html()] = true
				for q in t["p"]:
					for h in zicht:
						if h.x * q.x + h.y * q.y > h.z + 0.001:
							binnen = false
			waar(binnen, "%s -> %s: alleen de vloer die de opening doorlaat" % [id, naar])
			var nieuw := 0
			for kl in kleuren:
				if not eigen.has(kl):
					nieuw += 1
			waar(nieuw > 0, "%s -> %s: de deur laat een andere kamer zien, niet meer %s"
				% [id, naar, id])
			for ander in gezien:
				waar(ander["kleuren"] != kleuren, "%s: de deuren naar %s en %s zien er anders uit"
					% [id, ander["naar"], naar])
			gezien.append({"naar": naar, "kleuren": kleuren})

## Every floor colour a room has, inside its walls or on its lawn.
func _vloerkleuren(r: Rooms.Kamer) -> Dictionary:
	var uit := {}
	var rand := 48 if r.erf else 0
	var x := -rand
	while x < r.w + rand:
		var z := -rand
		while z < r.d + rand:
			uit[Rooms.vloer_kleur(r, x, z).to_html()] = true
			z += 4
		x += 4
	return uit

## No piece of furniture stands in front of a door (owner, 2026-09-23): the
## corridor's plants hid 37 % of the kamer 1 door and 29 % of the kamer 2 door.
## Counted in pixels at g = 2: the opening against every plate of the room's
## fixed floor decor and slots, all of which stand in front of the wall.
const DEUR_DEKKING_MAX := 0.03

func test_geen_meubel_voor_een_deur() -> void:
	for id in Rooms.lijst():
		var r := Rooms.get_kamer(id)
		for dr in r.deuren:
			if dr.get("poort", false):
				continue
			var dekking := _deur_dekking(r, dr)
			waar(dekking <= DEUR_DEKKING_MAX, "%s -> %s: %d %% van de deur zit achter een meubel"
				% [id, dr["naar"], roundi(dekking * 100.0)])

## `extra`: more pieces to hold against the opening, as [model, x, z, y, params].
func _deur_dekking(r: Rooms.Kamer, dr: Dictionary, extra: Array = []) -> float:
	var g := 2
	var a := float(dr["at"])
	var b := a + float(dr["breed"])
	var h := float(Rooms.deur_hoog(r, dr))
	var hoeken: PackedVector2Array
	if str(dr["wand"]) == "z":
		hoeken = PackedVector2Array([_px(a, 0, 0, g), _px(b, 0, 0, g), _px(b, 0, h, g),
			_px(a, 0, h, g)])
	else:
		hoeken = PackedVector2Array([_px(0, a, 0, g), _px(0, b, 0, g), _px(0, b, h, g),
			_px(0, a, h, g)])
	var vak := Rect2(hoeken[0], Vector2.ZERO)
	for q in hoeken:
		vak = vak.expand(q)
	var gat: Array[Vector2i] = []
	for py in range(int(floor(vak.position.y)), int(ceil(vak.end.y))):
		for px in range(int(floor(vak.position.x)), int(ceil(vak.end.x))):
			if Geometry2D.is_point_in_polygon(Vector2(px + 0.5, py + 0.5), hoeken):
				gat.append(Vector2i(px, py))
	var stukken: Array = []
	for stuk in r.decor:
		if not stuk.get("ver", false) and not stuk.get("pol", false):
			stukken.append([String(stuk["n"]), float(stuk["x"]), float(stuk["z"]),
				float(stuk.get("y", 0.0)), stuk.get("params", {})])
	for sid in r.slots:
		var m := String(r.slots[sid].get("model", ""))
		if m != "" and Art.heeft_model(m):
			stukken.append([m, float(r.slots[sid]["x"]), float(r.slots[sid]["z"]), 0.0, {}])
	stukken.append_array(extra)
	var bedekt := {}
	for st in stukken:
		var p = Art.plaat(st[0], g, st[4])
		if p == null:
			continue
		var img: Image = p.tex.get_image()
		var o := _px(st[1], st[2], st[3], g) + Vector2(p.dx, p.dy)
		for q in gat:
			var lx := q.x - roundi(o.x)
			var ly := q.y - roundi(o.y)
			if lx >= 0 and ly >= 0 and lx < img.get_width() and ly < img.get_height() \
					and img.get_pixel(lx, ly).a > 0.5:
				bedekt[q] = true
	return float(bedekt.size()) / float(maxi(1, gat.size()))

func _px(x: float, z: float, y: float, g: int) -> Vector2:
	return Vector2((x - z) * Art.S * g, (x + z) * (Art.S / 2.0) * g - y * Art.HG * g)

# ------------------------------------------------------------ de voordeur

## OWNER, 2026-09-23: the guests "komen momenteel vanuit de gang binnen ipv
## ingang".  The receptie has a front door of its own, in the one free stretch
## of wall in view — the back wall right of the desk (the left wall carries the
## corridor door, the bench, the key board and the playroom door) — and it is
## NOT a door of the graph: no path, no door button, no chip and no cell on the
## map lead through it (world.md §1.2).  No other room has one.
func test_de_receptie_heeft_een_voordeur_buiten_de_deurgraaf() -> void:
	var r := Rooms.get_kamer("receptie")
	var ing := Rooms.ingang("receptie")
	waar(not ing.is_empty(), "de receptie heeft een voordeur")
	if ing.is_empty():
		return
	gelijk(str(r.ingang.get("wand", "")), "z", "in de achterwand rechts")
	var a := float(r.ingang["at"])
	var b := a + float(r.ingang["breed"])
	gelijk(float(r.ingang["breed"]), 12.0, "zo breed als elke deur")
	waar(a > float(r.balie["x1"]), "voorbij het eind van de balie (%.0f > %.0f)" % [a, float(r.balie["x1"])])
	waar(b <= float(r.w) - 2.0, "binnen de wand, met zijn kozijn")
	gelijk(float(ing["x"]), (a + b) / 2.0, "het deurpunt in het midden van de opening")
	gelijk(float(ing["z"]), 0.0, "in de wand")
	gelijk(float(ing["ix"]), (a + b) / 2.0, "de stap binnen")
	gelijk(float(ing["iz"]), 8.0, "acht voxels de kamer in, als bij elke deur")
	gelijk(float(ing["dz"]), 3.0, "de drempel, waar een gast verschijnt")
	# it is not a door of the graph: the door pairs, points and paths stay as
	# they were, and outside is no room
	gelijk(r.deuren.size(), 2, "de receptie houdt twee deuren")
	gelijk(r.deur_punten.size(), 2, "en twee deurpunten, dus twee deurknoppen")
	for dr in r.deuren:
		waar(str(dr["wand"]) != "z" or float(dr["at"]) + float(dr["breed"]) <= a - 2.0
			or float(dr["at"]) >= b + 2.0,
			"de voordeur valt niet samen met de deur naar %s" % dr["naar"])
	gelijk(Rooms.lijst().size(), ORDE.size(), "buiten is geen kamer")
	gelijk(UiPlattegrond.KAART.size(), ORDE.size(), "en heeft geen vak op de plattegrond")
	for van in ORDE:
		for naar in ORDE:
			for stap in Rooms.pad(van, naar):
				waar(ORDE.has(stap), "%s -> %s loopt alleen door kamers" % [van, naar])
	for id in Rooms.lijst():
		if id != "receptie":
			waar(Rooms.ingang(id).is_empty(), "%s heeft geen voordeur" % id)
	# the door hangs on the wall over its opening, the mat lies before it
	var deur := _stuk(r, "voordeur")
	waar(not deur.is_empty() and bool(deur.get("ver", false)) and bool(deur.get("ingang", false)),
		"de voordeur hangt aan de wand en weet dat zij de ingang is")
	gelijk(float(deur.get("x", 0)), (a + b) / 2.0, "midden over de opening")
	var mat := _stuk(r, "welkomsmat")
	waar(not mat.is_empty(), "er ligt een welkomstmat")
	gelijk(float(mat.get("x", 0)), (a + b) / 2.0, "voor de deur")
	waar(float(mat.get("z", 0)) <= float(ing["iz"]), "vlak voor de deur")
	# the whole door is in the strip of wall that is always in view
	waar(Rooms.deur_hoog(r, r.ingang) + 2 <= int(World.WAND_ZICHT / Art.HG),
		"de deur met haar kozijn blijft altijd in beeld, ook in een laag kader")
	# no guest wanders onto the mat, no bought plant stands on it
	for p in r.plekken:
		waar(absf(p[0] - float(ing["ix"])) + absf(p[1] - float(ing["iz"])) >= 14.0,
			"loopplek (%s, %s) blijft van de voordeur af" % [p[0], p[1]])
	waar(not Rooms.vrij_vak("receptie", float(ing["ix"]), float(ing["iz"])), "geen meubel op de mat")

## Nothing stands in front of the front door either (the same 3 % as for every
## door, `test_geen_meubel_voor_een_deur`) — the desk lamp included, which is a
## movable thing and not in the decor list.
func test_niets_staat_voor_de_voordeur() -> void:
	var r := Rooms.get_kamer("receptie")
	var extra: Array = []
	for ding in World.dingen("receptie"):
		extra.append([String(ding["model"]), float(ding["x"]), float(ding["z"]),
			float(ding.get("hoog", 0.0)), {}])
	var dekking := _deur_dekking(r, r.ingang, extra)
	waar(dekking <= DEUR_DEKKING_MAX, "%d %% van de voordeur zit achter een meubel"
		% roundi(dekking * 100.0))

## No walk in the receptie crosses the counter, and neither does the way in from
## the front door: to every spot at the desk it goes round the desk's end, each
## leg a straight line in front of it (`WereldBinnenkomst.route`).
func test_de_weg_van_de_voordeur_gaat_om_de_balie() -> void:
	var r := Rooms.get_kamer("receptie")
	var b: Dictionary = r.balie
	var ing := Rooms.ingang("receptie")
	for i in 3:
		var p := Hotel._balieplek(i)
		var doel := Vector2(float(p["x"]), float(p["z"]))
		var weg := WereldBinnenkomst.route(r, ing, doel)
		gelijk(weg[0], Vector2(float(ing["dx"]), float(ing["dz"])), "plek %d: vanaf de drempel" % i)
		gelijk(weg[weg.size() - 1], doel, "plek %d: tot aan de balie" % i)
		for j in weg.size() - 1:
			waar(not _kruist(b, weg[j], weg[j + 1]), "plek %d: stuk %d (%s -> %s) blijft voor de balie"
				% [i, j, str(weg[j]), str(weg[j + 1])])
			var q: Vector2 = weg[j + 1]
			waar(q.x > 0.0 and q.y > 0.0 and q.x < r.w and q.y < r.d, "plek %d: binnen de kamer" % i)

## OWNER, 2026-09-23: "Het zwembad vanuit de tuin gezien is niet duidelijk dat
## lijkt gewoon op een huis".  The garden is the lawn behind the hotel: its left
## side is the hotel's back wall with the kitchen door in it, and behind its back
## fence lies the pool — deck and water — right behind a pool gate.  Neither the
## doghouse nor the tree stands in front of an exit any more.  From the pool the
## way back is a rose arch, with the garden's tree behind the fence.
func test_de_tuin_ligt_achter_het_hotel_en_naast_het_zwembad() -> void:
	var tuin := Rooms.get_kamer("tuin")
	gelijk(str(tuin.gevel.get("wand", "")), "x", "de tuin heeft de achtergevel op x = 0")
	var keuken := {}
	var poort := {}
	for dr in tuin.deuren:
		if dr["naar"] == "keuken":
			keuken = dr
		elif dr["naar"] == "zwembad":
			poort = dr
	gelijk(str(keuken.get("wand", "")), "x", "de keukendeur zit in de gevel")
	gelijk(Rooms.deur_hoog(tuin, keuken), 26, "een echte deur, zo hoog als binnen")
	var mid := int(float(poort["at"]) + float(poort["breed"]) / 2.0)
	waar(ArtVloer.TEGEL.has(Rooms.vloer_kleur(tuin, mid, 4)), "achter de poort ligt het tegeldek")
	waar(ArtVloer.BADWATER.has(Rooms.vloer_kleur(tuin, mid + 16, -20)), "en daarachter het water")
	waar(ArtVloer.GRAS.has(Rooms.vloer_kleur(tuin, mid, 20)), "vóór het hek is het gras van de tuin")
	var hek := _stuk(tuin, "zwembadpoort")
	waar(not hek.is_empty(), "de opening naar het zwembad is een zwembadpoort")
	gelijk(float(hek.get("x", 0)), float(mid), "in het midden van de opening")
	gelijk(float(hek.get("z", 0)), float(tuin.hek_z), "in de lijn van het hek")
	waar(_stuk(tuin, "poort").is_empty(), "de oude tuinpoort is weg")
	for naam in ["hok", "boom"]:
		var s := _stuk(tuin, naam)
		for naar in tuin.deur_punten:
			var dp: Dictionary = tuin.deur_punten[naar]
			waar(absf(float(s["x"]) - float(dp["ix"])) + absf(float(s["z"]) - float(dp["iz"])) >= 30.0,
				"%s staat niet voor de uitgang naar %s" % [naam, naar])
	var zb := Rooms.get_kamer("zwembad")
	var boog := _stuk(zb, "rozenboog")
	waar(not boog.is_empty(), "het zwembad gaat door een rozenboog terug naar de tuin")
	gelijk(float(boog.get("z", 0)), float(zb.deur_punten["tuin"]["z"]), "de boog staat in de opening")
	gelijk(float(boog.get("x", 0)), float(zb.hek_x), "in de lijn van het hek")
	var boom := false
	for stuk in zb.decor:
		if stuk["n"] == "boom" and float(stuk["x"]) < zb.hek_x:
			boom = true
	waar(boom, "achter het hek van het zwembad staat de boom van de tuin")

## PLAN.md R3: the kas is a glass house behind the hotel.  From the garden its
## glass door is in the hotel's back wall where the kitchen window hung (the
## left fence R3 planned is the facade since 2026-09-23), with a glass canopy
## over it; through the door you see the kas's terracotta path, not more tiles.
## Inside, the floor under the two games' tables (`mijd`) holds no wander place
## and takes no bought furniture, and the vegetable beds keep their zone.
func test_de_kas_is_een_glazen_kas_achter_het_hotel() -> void:
	var kas := Rooms.get_kamer("kas")
	var tuin := Rooms.get_kamer("tuin")
	waar(kas.glas, "de kas heeft glazen wanden")
	waar(not tuin.glas, "de tuin niet")
	var deur := {}
	for dr in tuin.deuren:
		if dr["naar"] == "kas":
			deur = dr
	gelijk(str(deur.get("wand", "")), str(tuin.gevel.get("wand", "")), "de kasdeur zit in de achtergevel")
	gelijk(Rooms.deur_hoog(tuin, deur), 26, "een echte deur, zo hoog als de keukendeur")
	waar(not bool(deur.get("poort", false)), "geen poort: een gat in de gevel")
	var luifel := _stuk(tuin, "kasluifelz")
	waar(not luifel.is_empty() and bool(luifel.get("ver", false)), "een glazen luifel aan de gevel")
	gelijk(float(luifel.get("z", 0)), float(deur["at"]) + float(deur["breed"]) / 2.0, "boven de deur")
	waar(_stuk(tuin, "gevelraamz").is_empty(), "het keukenraam maakte plaats voor de kasdeur")
	# through the door: the path's terracotta, which no other room has
	var pad := Rooms.vloer_kleur(kas, int(kas.kijk.x), int(kas.kijk.y))
	var mat: Dictionary = (kas.matten as Array)[0]
	waar((mat["kl"] as Array).has(pad), "de kijk van de kas valt op het terracotta pad")
	for id in Rooms.lijst():
		if id == "kas":
			continue
		waar(not _vloerkleuren(Rooms.get_kamer(id)).has(pad.to_html()),
			"%s heeft het terracotta van de kas niet" % id)
	# the games' floor
	gelijk(kas.mijd.size(), 3, "de pluktafel, de weegschaal en de rij gewichten")
	for p in kas.plekken:
		for m in kas.mijd:
			waar(not (p[0] >= m["x0"] and p[0] <= m["x1"] and p[1] >= m["z0"] and p[1] <= m["z1"]),
				"loopplek %s staat niet op een spel" % str(p))
	for m in kas.mijd:
		var mx := (float(m["x0"]) + float(m["x1"])) / 2.0
		var mz := (float(m["z0"]) + float(m["z1"])) / 2.0
		waar(not Rooms.vrij_vak("kas", mx, mz), "geen gekocht meubel op een spel (%s)" % str(m))
	waar(kas.zones.has("rijen"), "de moesbakken houden hun zone (R3)")
	# every other room: no `mijd`, so nothing moved there
	for id in Rooms.lijst():
		if id != "kas":
			gelijk(Rooms.get_kamer(id).mijd.size(), 0, "%s houdt al zijn vloer" % id)

## A gate's rectangle is the gate in the fence line, not the door line behind
## it: measured on the door line the pool gate's button landed on the gate.
func test_een_poort_meet_zich_in_de_hekkenlijn() -> void:
	var vak := World.vlak_van_deur("tuin", "zwembad")
	waar(vak.has_point(World.mik_punt(44.0, 10.0, 9.0)), "het vak omvat de poort in het hek")
	waar(not vak.has_point(World.mik_punt(44.0, 0.0, 9.0)), "en niet de deurlijn erachter")

func _stuk(r: Rooms.Kamer, naam: String) -> Dictionary:
	for stuk in r.decor:
		if stuk["n"] == naam:
			return stuk
	return {}
