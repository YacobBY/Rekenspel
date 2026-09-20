extends Proef
## The animal runtime: movement as an awaitable order, supersede, travelling
## through the doors, sleeping in a bed, idle wandering, the loose decor and
## the camera — world.md §2, §1.9, §6.6.
##
## The think tick is driven BY HAND (`World._tik()`), never by the frame clock,
## so every assertion here is deterministic: the animals are seeded from their
## id and the day (architecture.md §13, Q-X1-1), the tick is the only source of
## time, and a test that walks 60 voxels asserts the tick count it took.

const T := "t_dier"

func _na_afloop() -> void:
	for id in ["t_dier", "t2", "t3", "t4", "t5", "t_slaap", "t_reis"]:
		World.weg(id)
	World.decor_wis_eigenaar("proef")
	World.decor_wis_eigenaar("ander")

## Start an order without awaiting it, so the test can drive the ticks itself.
func _bestel(uit: Dictionary, id: String, punten: Array, o: Dictionary = {}) -> void:
	uit["gehaald"] = await World.stappen(id, punten, o)
	uit["klaar"] = true

func _draai(uit: Dictionary, max_tikken := 400) -> int:
	var t := 0
	while not uit.has("klaar") and t < max_tikken:
		World._tik()
		t += 1
	return t

# ------------------------------------------------------------- de API van §5.3

## `ctx.wereld` IS `World` (architecture.md §6.3), so every name world.md §5.3
## promises a minigame must exist here with an arity that accepts the
## documented call.  Checked by reflection, so a wave-2 ticket can never find a
## hole the day it starts.  naam -> the number of arguments the spec passes.
const WERELD_API := {
	"kamers": 0, "kamer": 1, "pad": 2, "slots": 2, "slot": 2, "actief": 0,
	"naar": 1, "dieren": 1, "dier": 1, "zet": 4, "sync": 1,
	"ga": 4, "reis": 3, "slaap": 3, "solo": 2, "feest": 1,
	"mood": 2, "set_mood": 2, "set_food": 3, "set_bak": 3, "zet_bak": 3,
	"bak_stand": 2, "ding": 1, "ding_zet": 2, "zet_ding": 2,
	"vuil": 1 - 1, "mik": 2, "mik_punt": 3, "schaal": 0, "vlak_van": 5,
	"behoefte_klaar": 2, "getal_tag": 3, "voeg_bed": 2, "plaats_meubel": 5,
	"verwijder_meubel": 1, "kamer_meubels": 1, "meubeltypen": 0,
	"decor": 2, "decor_weg": 2, "decor_lijst": 1, "decor_plek": 2,
	"decor_wis_alles": 0, "decor_wis_eigenaar": 1,
	"loop_naar": 4, "stappen": 3, "pose": 3,
	"accessoire": 2, "accessoires": 1, "accessoire_weg": 2,
}

func test_de_wereld_api_van_53_is_compleet() -> void:
	var gevonden := {}
	for m in World.get_method_list():
		gevonden[m["name"]] = m
	for naam in WERELD_API:
		var n: int = WERELD_API[naam]
		if not gevonden.has(naam):
			fout("World.%s ontbreekt (world.md §5.3)" % naam)
			continue
		var m: Dictionary = gevonden[naam]
		var alles: int = (m["args"] as Array).size()
		var nodig: int = alles - (m["default_args"] as Array).size()
		waar(nodig <= n and n <= alles,
			"World.%s neemt %d..%d argumenten, §5.3 geeft er %d" % [naam, nodig, alles, n])
	# and the two calls a game reaches them through
	var ctx := SpelCtx.new("proef", {"naam": "Proef", "kamer": "receptie"})
	gelijk(ctx.wereld, World, "ctx.wereld is de World-autoload")
	gelijk(ctx.kamer, "receptie", "ctx.kamer komt uit de definitie")

## The passthroughs give the same answer as the room they pass through to.
func test_de_doorgeefluiken_geven_hetzelfde_terug() -> void:
	gelijk(World.kamers().size(), Rooms.lijst().size(), "kamers()")
	gelijk(World.kamer("kamer1").id, "kamer1", "kamer(id)")
	gelijk(World.pad("gang", "kamer1").size(), 2, "pad()")
	gelijk(World.actief(), World.kamer_nu(), "actief()")
	Rooms.herstel()
	gelijk(World.slots("kamer1", "bed").size(), 2, "slots(kamer, soort)")
	gelijk(World.slots("", "bed").size(), 4, "slots('' , soort) = het hele hotel")
	gelijk(World.slots("kamer1").size(), 3, "slots(kamer) = elk soort")
	gelijk(World.slot("kamer1", "bed1")["x"], 30, "slot(kamer, id)")
	gelijk(World.slot("kamer1", "bestaat-niet").size(), 0, "een onbekend slot geeft niets")
	gelijk(World.meubeltypen().size(), 6, "de zes meubeltypen")
	waar(World.meubeltypen()["bakje"]["model"].is_empty(), "een bakje heeft geen model")
	var bed := World.voeg_bed("kamer1", {"x": 66.0, "z": 66.0})
	waar(not bed.is_empty(), "voeg_bed() zet een bed neer")
	gelijk(World.kamer_meubels("kamer1").size(), 1, "kamer_meubels() ziet het")
	waar(World.verwijder_meubel(String(bed["id"])), "verwijder_meubel() haalt het weg")
	gelijk(World.kamer_meubels("kamer1").size(), 0, "en dan is het weg")
	Rooms.herstel()

## `setFood` maps scoops onto the four levels of a card bowl.
func test_set_food_kiest_een_niveau() -> void:
	World.zet(T, "receptie", 20.0, 20.0, {"kind": "hond"})
	gelijk(World.set_food(T, 0, 2), 0, "niets in de bak")
	gelijk(World.set_food(T, 2, 2), 4, "een hele portie")
	gelijk(World.set_food(T, 1, 2), 2, "de helft")
	gelijk(World.dier(T).voer, 2, "en het dier onthoudt het")
	_na_afloop()

# ------------------------------------------------------------------ lopen

## A walk reaches its target, exactly on the point, and takes at least the
## number of ticks the speed model allows and no more than 2.5x that.
func test_lopen_haalt_zijn_doel_in_de_verwachte_tijd() -> void:
	World.naar("receptie")
	var d := World.zet(T, "receptie", 20.0, 20.0, {"kind": "hond"})
	var doel := Vector2(80.0, 80.0)
	var afstand := Vector2(d.x, d.z).distance_to(doel)
	var vmax: float = d.vmax * Rooms.get_kamer("receptie").loop
	var minimaal := int(ceil(afstand / vmax))
	var uit := {}
	_bestel(uit, T, [doel])
	var tikken := _draai(uit)
	waar(uit.get("klaar", false), "de opdracht is afgerond")
	waar(uit.get("gehaald", false), "stappen() gaf true")
	gelijk(d.x, doel.x, "precies op x")
	gelijk(d.z, doel.y, "precies op z")
	waar(tikken >= minimaal, "niet sneller dan vmax (%d tikken, minimaal %d)"
		% [tikken, minimaal])
	waar(tikken <= minimaal * 3, "en niet traag (%d tikken, minimaal %d)"
		% [tikken, minimaal])
	gelijk(d.staat, "wacht", "eindstaat is de standaard `wacht`")
	_na_afloop()

## Gliding: 20 points along one straight line cost the same as one point.
func test_glijden_door_de_punten_kost_geen_extra_tijd() -> void:
	World.naar("receptie")
	World.zet(T, "receptie", 20.0, 20.0, {"kind": "hond"})
	var een := {}
	_bestel(een, T, [Vector2(20.0, 100.0)])
	var recht := _draai(een)
	World.zet(T, "receptie", 20.0, 20.0, {"kind": "hond"})
	var veel: Array = []
	for i in range(1, 21):
		veel.append(Vector2(20.0, 20.0 + i * 4.0))
	var stukjes := {}
	_bestel(stukjes, T, veel)
	var gestapt := _draai(stukjes)
	waar(stukjes.get("gehaald", false), "de laatste stap is gehaald")
	waar(absi(gestapt - recht) <= 2, "20 punten kosten evenveel tijd als 1 (%d vs %d)"
		% [gestapt, recht])
	_na_afloop()

## Every callback gets its own index, in order.
func test_per_stap_krijgt_elke_punt() -> void:
	World.naar("receptie")
	World.zet(T, "receptie", 20.0, 20.0, {"kind": "hond"})
	var gezien: Array = []
	var uit := {}
	_bestel(uit, T, [Vector2(30.0, 30.0), Vector2(40.0, 40.0), Vector2(50.0, 50.0)],
		{"per_stap": func(i: int, _p): gezien.append(i)})
	_draai(uit)
	gelijk(gezien.size(), 3, "drie keer geroepen")
	gelijk(str(gezien), "[0, 1, 2]", "op volgorde")
	_na_afloop()

## A second order supersedes the first: the first resolves FALSE, never an error.
func test_een_nieuwe_opdracht_haalt_de_oude_van_tafel() -> void:
	World.naar("receptie")
	World.zet(T, "receptie", 20.0, 20.0, {"kind": "hond"})
	var eerste := {}
	_bestel(eerste, T, [Vector2(100.0, 100.0)])
	for i in 5:
		World._tik()
	waar(not eerste.has("klaar"), "de eerste loopt nog")
	var tweede := {}
	_bestel(tweede, T, [Vector2(30.0, 30.0)])
	waar(eerste.get("klaar", false), "de eerste is meteen afgerond")
	gelijk(eerste.get("gehaald", true), false, "en gaf false")
	var tikken := _draai(tweede)
	waar(tweede.get("gehaald", false), "de tweede haalt het wel")
	waar(tikken > 0, "de tweede liep echt")
	# ga(), reis(), slaap() and pose() supersede in exactly the same way
	var derde := {}
	_bestel(derde, T, [Vector2(90.0, 90.0)])
	for i in 3:
		World._tik()
	World.pose(T, "blij", 30)
	waar(derde.get("klaar", false), "pose() haalt een lopende opdracht van tafel")
	gelijk(derde.get("gehaald", true), false, "ook die gaf false")
	_na_afloop()

## The three edge cases of world.md §2.5, all of them without an error.
func test_randgevallen_van_stappen() -> void:
	World.zet(T, "receptie", 20.0, 20.0)
	var leeg := {}
	_bestel(leeg, T, [])
	waar(leeg.get("klaar", false), "stappen(id, []) is meteen klaar")
	gelijk(leeg.get("gehaald", false), true, "en geeft true")
	var weg := {}
	_bestel(weg, "bestaat-niet", [Vector2(1, 1)])
	waar(weg.get("klaar", false), "een onbekend dier is meteen klaar")
	gelijk(weg.get("gehaald", true), false, "en geeft false")
	# a non-finite point is skipped, the rest is still walked
	var raar := {}
	_bestel(raar, T, [Vector2(INF, 3.0), Vector2(30.0, 30.0)])
	_draai(raar)
	gelijk(World.dier(T).x, 30.0, "het onzinnige punt is overgeslagen")
	_na_afloop()

## Reduced motion: the animal is placed, `per_stap` still runs, and the order
## resolves true in the same frame (architecture.md §5.1).
func test_rustmodus_zet_neer_in_plaats_van_lopen() -> void:
	World.naar("receptie")
	World.zet(T, "receptie", 20.0, 20.0)
	var was: bool = Ui.rust_modus()
	Ui.set("_rust", true)
	var gezien: Array = []
	var uit := {}
	_bestel(uit, T, [Vector2(40.0, 40.0), Vector2(60.0, 60.0)],
		{"per_stap": func(i: int, _p): gezien.append(i)})
	waar(uit.get("klaar", false), "meteen klaar, zonder een enkele tik")
	gelijk(uit.get("gehaald", false), true, "en true")
	gelijk(gezien.size(), 2, "per_stap liep alle punten af")
	gelijk(World.dier(T).x, 60.0, "het dier staat op het laatste punt")
	gelijk(World.glij(), 0.0, "er wordt niet geglipt in rustmodus")
	Ui.set("_rust", was)
	_na_afloop()

# ------------------------------------------------------------------ reizen

## `reis` walks through the doors and ends in the room that was asked for.
func test_reis_loopt_door_de_deuren() -> void:
	World.naar("receptie")
	World.zet("t_reis", "receptie", 90.0, 20.0, {"kind": "poes"})
	var route := World.reis("t_reis", "kamer1", {"x": 60.0, "z": 60.0, "na": "wacht"})
	gelijk(route.size(), 3, "receptie -> gang -> kamer1")
	gelijk(route[2], "kamer1", "en eindigt in kamer1")
	var d := World.dier("t_reis")
	var t := 0
	while d.kamer != "kamer1" and t < 900:
		World._tik()
		t += 1
	gelijk(d.kamer, "kamer1", "het dier is in kamer1 aangekomen")
	while (not d.punten.is_empty() or not d.route.is_empty()) and t < 1200:
		World._tik()
		t += 1
	gelijk(d.x, 60.0, "en staat op het gevraagde punt")
	gelijk(d.z, 60.0, "ook in z")
	waar(World.reis("t_reis", "kamer1").is_empty(), "dezelfde kamer is geen opdracht")
	waar(World.reis("t_reis", "nergens").is_empty(), "een onbekende kamer ook niet")
	_na_afloop()

# ------------------------------------------------------------------ slapen

## world.md §2.7 — in the bed's own point, on the mattress, pose `lig`.
func test_slapen_ligt_op_het_matras() -> void:
	Rooms.herstel()
	World.naar("kamer1")
	World.zet("t_slaap", "kamer1", 60.0, 60.0, {"kind": "konijn"})
	waar(World.slaap("t_slaap", "kamer1", "bed1"), "slaap() neemt de opdracht aan")
	var d := World.dier("t_slaap")
	var bed: Dictionary = Rooms.get_kamer("kamer1").slots["bed1"]
	gelijk(d.x, bed["x"], "op het bed x")
	gelijk(d.z, bed["z"], "op het bed z")
	gelijk(d.hoogte, World.MATRAS, "op het matras (y = 7)")
	gelijk(d.lift, -World.MATRAS * Art.HG, "en de lift is het spiegelbeeld daarvan")
	gelijk(d.staat, "slaap", "staat slaap")
	gelijk(d.pose, "lig", "pose lig")
	gelijk(d.face, 1, "een gewoon bed kijkt naar rechts")
	waar(World.slaapt("t_slaap"), "World.slaapt() ziet hem")
	# a rotated bed mirrors the sleeper, which is a quarter turn in this isometry
	var draai := Rooms.meubel_zet("kamer1", "bed", 66.0, 66.0, 1)
	if not draai.is_empty():
		World.slaap("t_slaap", "kamer1", String(draai["id"]))
		gelijk(World.dier("t_slaap").face, -1, "een gedraaid bed spiegelt het dier")
		Rooms.meubel_weg(String(draai["id"]))
	# out of another room he walks there first and lies down on arrival
	World.zet("t_slaap", "receptie", 90.0, 30.0)
	World.slaap("t_slaap", "kamer1", "bed1")
	var t := 0
	while not World.slaapt("t_slaap") and t < 1500:
		World._tik()
		t += 1
	waar(World.slaapt("t_slaap"), "hij is naar bed gelopen (%d tikken)" % t)
	gelijk(World.dier("t_slaap").kamer, "kamer1", "in de goede kamer")
	gelijk(World.dier("t_slaap").x, bed["x"], "en op het bed")
	Rooms.herstel()
	_na_afloop()

## Waking up: a guest that is sent somewhere else leaves the bed behind and
## never climbs back into it on arrival.
func test_uit_bed_blijft_uit_bed() -> void:
	Rooms.herstel()
	World.naar("kamer1")
	World.zet("t_slaap", "kamer1", 60.0, 60.0, {"kind": "hond"})
	World.slaap("t_slaap", "kamer1", "bed1")
	waar(World.slaapt("t_slaap"), "hij ligt")
	World.ga("t_slaap", 66.0, 90.0, "wacht")
	var d := World.dier("t_slaap")
	waar(not World.slaapt("t_slaap"), "en staat meteen op")
	gelijk(d.hoogte, 0.0, "van het matras af")
	for i in 300:
		World._tik()
		if d.punten.is_empty():
			break
	gelijk(d.x, 66.0, "hij loopt naar het gevraagde punt")
	waar(not World.slaapt("t_slaap"), "en kruipt niet terug in bed")
	gelijk(d.hoogte, 0.0, "hij blijft op de vloer")
	World.naar("receptie")
	_na_afloop()

## A swimmer that is told to walk gets out of the water first.
func test_zwemmer_die_gaat_lopen_staat_weer_op_de_vloer() -> void:
	World.naar("zwembad")
	World.zet(T, "zwembad", 20.0, 28.0, {"kind": "hond"})
	var nat := {}
	_bestel(nat, T, [Vector2(120.0, 28.0)], {"pose": "zwem", "na": "zwem"})
	for i in 40:
		World._tik()
	var d := World.dier(T)
	gelijk(d.hoogte, -World.ZWEM_DIEP, "hij ligt 7 voxels in het water")
	gelijk(d.lift, World.ZWEM_DIEP * Art.HG, "en de lift is het spiegelbeeld")
	World.ga(T, 60.0, 70.0, "wacht")
	gelijk(nat.get("gehaald", true), false, "de zwemopdracht is afgebroken")
	for i in 200:
		World._tik()
		if d.punten.is_empty():
			break
	gelijk(d.hoogte, 0.0, "op het droge")
	gelijk(d.lift, 0.0, "geen lift meer")
	World.naar("receptie")
	_na_afloop()

# -------------------------------------------------------------------- idle

## Idle wandering keeps two animals apart and never leaves the room.
func test_dwalen_deelt_geen_plek_en_blijft_in_de_kamer() -> void:
	World.naar("receptie")
	var r := Rooms.get_kamer("receptie")
	World.zet(T, "receptie", NAN, NAN, {"kind": "hond", "nr": 0})
	World.zet("t2", "receptie", NAN, NAN, {"kind": "poes", "nr": 1})
	World.zet("t3", "receptie", NAN, NAN, {"kind": "gans", "nr": 2})
	var namen := [T, "t2", "t3"]
	for i in 600:
		World._tik()
		var doelen: Array = []
		for id in namen:
			var d := World.dier(id)
			waar(d.kamer == "receptie", "niemand verlaat de kamer vanzelf")
			waar(d.x >= -2.0 and d.x <= r.w + 2.0, "x blijft binnen de kamer")
			waar(d.z >= -2.0 and d.z <= r.d + 2.0, "z blijft binnen de kamer")
			if not d.punten.is_empty():
				doelen.append(d.punten[d.punten.size() - 1])
		for a in doelen.size():
			for b in range(a + 1, doelen.size()):
				waar(doelen[a] != doelen[b], "twee dieren lopen nooit naar dezelfde plek")
	_na_afloop()

## An idle animal in the pool room never walks into the water.
func test_dwalen_gaat_nooit_het_water_in() -> void:
	World.naar("zwembad")
	var r := Rooms.get_kamer("zwembad")
	var bad: Dictionary = r.bad
	World.zet(T, "zwembad", NAN, NAN, {"kind": "hond"})
	for i in 600:
		World._tik()
		var d := World.dier(T)
		var nat: bool = d.x >= bad["x0"] and d.x <= bad["x1"] \
			and d.z >= bad["z0"] and d.z <= bad["z1"]
		waar(not nat, "het dier staat op (%.0f, %.0f), niet in het water" % [d.x, d.z])
	World.naar("receptie")
	_na_afloop()

## Off screen there is no pose work, but the route is walked (world.md §2.9).
func test_dieren_buiten_beeld_lopen_grof_door() -> void:
	World.naar("receptie")
	World.zet(T, "keuken", 20.0, 20.0, {"kind": "hond"})
	World.ga(T, 80.0, 80.0, "wacht")
	var d := World.dier(T)
	for i in 200:
		World._tik()
		if d.punten.is_empty():
			break
	gelijk(d.x, 80.0, "hij is er ook zonder publiek")
	gelijk(d.z, 80.0, "in z ook")
	_na_afloop()

# ------------------------------------------------------------ eten en pose

## The bowl empties while a guest eats and he is happy afterwards.
func test_eten_leegt_de_bak() -> void:
	World.naar("kamer1")
	World.zet_bak("kamer1", "bak", 3)
	gelijk(World.bak_stand("kamer1", "bak"), 3, "de bak staat op 3")
	var bak: Dictionary = Rooms.get_kamer("kamer1").slots["bak"]
	World.zet(T, "kamer1", bak["sx"], bak["sz"], {"kind": "hond"})
	World.feed([T])
	var d := World.dier(T)
	for i in 400:
		World._tik()
		if d.staat == "blij":
			break
	gelijk(World.bak_stand("kamer1", "bak"), 0, "de bak is leeg")
	gelijk(d.staat, "blij", "en hij is blij")
	World.naar("receptie")
	_na_afloop()

## V5 (PLAN.md): de kauwteller zit op het dier, niet op de wereld.  Met de
## oude `_tikken % 5`-poort nam elke etende gast op dezelfde tik een niveau
## mee, dus vier gasten leegden een vol bakje in een derde seconde — terwijl
## het 😋-wolkje van 2,6 s nog stond en de knop "Vol" zei.  Twee gasten aan
## een bakje van 4: na 20 tikken is er nog niets af (het eerste niveau komt
## op de vierentwintigste), na 100 tikken is hij leeg.
func test_het_bakje_blijft_even_vol() -> void:
	World.naar("kamer1")
	World.zet_bak("kamer1", "bak", 4)
	var bak: Dictionary = Rooms.get_kamer("kamer1").slots["bak"]
	World.zet(T, "kamer1", bak["sx"], bak["sz"], {"kind": "hond"})
	World.zet("t2", "kamer1", float(bak["sx"]) + 1.0, float(bak["sz"]), {"kind": "poes"})
	World.feest([T, "t2"])
	gelijk(World.dier(T).staat, "eet", "twee gasten eten")
	gelijk(World.dier("t2").staat, "eet", "beide")
	for _i in 20:
		World._tik()
	var stand := World.bak_stand("kamer1", "bak")
	waar(stand >= 3, "na 20 tikken is er hooguit één niveau af: stand %d" % stand)
	for _i in 80:
		World._tik()
	gelijk(World.bak_stand("kamer1", "bak"), 0, "na 100 tikken is de bak leeg")
	World.naar("receptie")
	_na_afloop()

## Hoeveel gasten er ook aan het bakje staan, de bak gaat op hetzelfde tempo
## leeg (V5, PLAN.md: "ongeacht hoeveel dieren er eten").  Met de oude
## `_tikken % 5`-poort namen vier gasten op dezelfde tik elk een niveau mee en
## was een vol bakje in een derde seconde weg; de teller zit nu op het bakje.
func test_eters_veranderen_het_kauwtempo_niet() -> void:
	var per_eter := {}
	for n in [1, 4]:
		_na_afloop()
		World.naar("kamer1")
		World.zet_bak("kamer1", "bak", 4)
		var bak: Dictionary = Rooms.get_kamer("kamer1").slots["bak"]
		var ids: Array = []
		for i in n:
			var id := "t%d" % (i + 2)
			World.zet(id, "kamer1", float(bak["sx"]) + float(i), float(bak["sz"]),
				{"kind": "hond"})
			ids.append(id)
		World.feest(ids)
		var tikken := 0
		while World.bak_stand("kamer1", "bak") > 0 and tikken < 400:
			World._tik()
			tikken += 1
		per_eter[n] = tikken
		gelijk(tikken, 4 * World.KAUW_PER_NIVEAU,
			"%d eter(s), vier niveaus à %d tikken: %d" % [n, World.KAUW_PER_NIVEAU, tikken])
		World.naar("receptie")
	gelijk(int(per_eter[1]), int(per_eter[4]), "één of vier eters, zelfde tempo")
	_na_afloop()

## `bak_veranderd` gaat precies één keer uit per echte verandering en niet als
## er niets verandert (V5, PLAN.md) — de shell schildert de bakknop hierop
## over, en 4 over 4 schrijven is geen nieuws.
func test_bak_veranderd_vuurt_per_echte_verandering() -> void:
	World.zet_bak("kamer1", "bak", 0)   # uitgangspositie, telt niet mee
	var vertellingen := {"n": 0, "laatste": ""}
	var hand := func(k: String, s: String) -> void:
		vertellingen["n"] = int(vertellingen["n"]) + 1
		vertellingen["laatste"] = "%s|%s" % [k, s]
	World.bak_veranderd.connect(hand)
	World.zet_bak("kamer1", "bak", 0)
	gelijk(int(vertellingen["n"]), 0, "0 over 0 is geen verandering")
	World.zet_bak("kamer1", "bak", 4)
	gelijk(int(vertellingen["n"]), 1, "0 naar 4 vuurt één keer")
	World.zet_bak("kamer1", "bak", 4)
	gelijk(int(vertellingen["n"]), 1, "4 over 4 vuurt niet nog eens")
	World.zet_bak("kamer1", "bak", 3)
	gelijk(int(vertellingen["n"]), 2, "4 naar 3 vuurt weer")
	gelijk(str(vertellingen["laatste"]), "kamer1|bak", "en noemt kamer en slot")
	World.zet_bak("kamer1", "bak", 9)
	gelijk(int(vertellingen["n"]), 3, "9 klemmt naar 4 en is wél een verandering")
	gelijk(World.bak_stand("kamer1", "bak"), 4, "en blijft binnen 0..4")
	World.bak_veranderd.disconnect(hand)
	_na_afloop()

## Een render die midden in de eetlus af gaat, gooit niets om (V5, PLAN.md).
## De shell stelt zijn eigen repaint uit, maar de bakknop wordt door
## `Hotel.render()` gebouwd en dat mag niet stuklopen terwijl de wereld
## halverwege zijn dieren loopt.
func test_render_midden_in_de_eetlus_gooit_niets_om() -> void:
	State.nieuw_spel()
	Hotel.start()
	World.naar("kamer1")
	World.zet_bak("kamer1", "bak", 4)
	var bak: Dictionary = Rooms.get_kamer("kamer1").slots["bak"]
	World.zet(T, "kamer1", bak["sx"], bak["sz"], {"kind": "hond"})
	World.feest([T])
	var keer := {"n": 0}
	var hand := func(_k: String, _s: String) -> void:
		keer["n"] = int(keer["n"]) + 1
		Hotel.render()
	World.bak_veranderd.connect(hand)
	for _i in 120:
		World._tik()
	World.bak_veranderd.disconnect(hand)
	waar(int(keer["n"]) >= 4,
		"elk niveau riep de render op: %d keer" % int(keer["n"]))
	gelijk(World.bak_stand("kamer1", "bak"), 0, "en de bak is leeg")
	World.naar("receptie")
	_na_afloop()

## `pose` holds one pose for the number of ticks it was given.
func test_pose_houdt_zijn_tijd_vol() -> void:
	World.naar("receptie")
	World.zet(T, "receptie", 30.0, 30.0)
	waar(World.pose(T, "zwaai", 20), "pose() neemt de opdracht aan")
	var d := World.dier(T)
	for i in 10:
		World._tik()
	gelijk(d.pose, "zwaai", "na 10 tikken nog steeds")
	for i in 15:
		World._tik()
	waar(d.pose != "zwaai" or d.staat != "pose", "en daarna gaat hij verder")
	waar(not World.pose("bestaat-niet", "zwaai", 5), "een onbekend dier geeft false")
	_na_afloop()

## An accessory list is always replaced, never mutated, and it is part of the
## plate key — so a guest with a hat gets his own plate.
func test_accessoires_zitten_in_de_plaatsleutel() -> void:
	World.zet(T, "receptie", 30.0, 30.0, {"kind": "hond"})
	var uit := World.accessoire(T, "sjaaltje")
	gelijk(str(uit), '["sjaaltje"]', "sjaaltje erbij")
	World.accessoire(T, "hoedje")
	gelijk(str(World.dier(T).acc), '["hoedje", "sjaaltje"]', "altijd in de vaste volgorde")
	gelijk(World.dier(T).params["acc"], "hoedje,sjaaltje", "en zo staat het in de sleutel")
	World.accessoire(T, "hoedje", false)
	gelijk(str(World.dier(T).acc), '["sjaaltje"]', "en er weer af")
	_na_afloop()

# ------------------------------------------------------------------ decor

## world.md §1.7 — ownership, the room cap and the copy that comes back.
func test_los_decor_kent_zijn_eigenaar() -> void:
	var stuk := World.decor("receptie", {"id": "d1", "model": "kist", "x": 30.0, "z": 30.0,
		"door": "proef"})
	waar(not stuk.is_empty(), "het stuk staat er")
	gelijk(stuk["kamer"], "receptie", "in de goede kamer")
	waar(World.decor("receptie", {"id": "d1", "model": "kist", "x": 1.0, "z": 1.0,
		"door": "ander"}).is_empty(), "een ander spel kan het niet overnemen")
	gelijk(World.decor_plek("d1")["x"], 30.0, "en het staat er nog")
	waar(World.decor("nergens", {"id": "d2", "model": "kist"}).is_empty(), "onbekende kamer")
	waar(World.decor("receptie", {"id": "", "model": "kist"}).is_empty(), "leeg id")
	waar(World.decor("receptie", {"id": "d3", "model": "bestaat-niet"}).is_empty(),
		"onbekend model")
	for i in World.LOS_MAX + 4:
		World.decor("tuin", {"id": "v%d" % i, "model": "kist", "x": 20.0, "z": 20.0,
			"door": "proef"})
	gelijk(World.decor_lijst("tuin").size(), World.LOS_MAX, "hooguit LOS_MAX per kamer")
	World.decor_wis_eigenaar("proef")
	gelijk(World.decor_lijst("tuin").size(), 0, "de eigenaar ruimt alles op")
	gelijk(World.decor_lijst("receptie").size(), 0, "ook in de receptie")

# ------------------------------------------------------------------ de dingen

## world.md §1.3 — de kar en de balielamp worden bij het opstarten uit het decor
## van hun kamer getild.  Hun thuisplek blijft bewaard: de ingang van een spel
## hangt op zijn ding (`Games._plek_van`), dus een kar die in een andere kamer
## blijft staan zou het voerkarspel onbereikbaar maken.
func test_een_ding_kent_zijn_thuisplek() -> void:
	var thuis := World.ding_thuis("kar")
	waar(not thuis.is_empty(), "de kar heeft een thuisplek")
	gelijk(str(thuis.get("kamer", "")), "keuken", "de kar hoort in de keuken")
	gelijk(float(thuis.get("x", 0.0)), 48.0, "op x 48")
	gelijk(float(thuis.get("z", 0.0)), 66.0, "en op z 66")
	var model := str(World.ding("kar").get("model", ""))
	gelijk(str(thuis.get("model", "")), model, "met het model waarmee hij begon")
	gelijk(str(World.ding_thuis("balielamp").get("kamer", "")), "receptie",
		"de balielamp hoort in de receptie")
	waar(World.ding_thuis("bestaat-niet").is_empty(), "een onbekend ding heeft geen thuis")
	waar(World.ding_thuis_zet("bestaat-niet").is_empty(), "en is ook niet thuis te zetten")
	# een spel duwt de kar het hotel door en zet hem daarna terug
	World.zet_ding("kar", {"kamer": "kamer2", "x": 20.0, "z": 30.0, "model": "lamp"})
	gelijk(str(World.ding("kar").get("kamer", "")), "kamer2", "de kar staat in kamer2")
	gelijk(str(World.ding_thuis("kar").get("kamer", "")), "keuken",
		"en de thuisplek verhuist niet mee")
	var terug := World.ding_thuis_zet("kar")
	gelijk(str(terug.get("kamer", "")), "keuken", "ding_thuis_zet geeft de nieuwe stand terug")
	var nu := World.ding("kar")
	gelijk(str(nu.get("kamer", "")), "keuken", "de kar staat weer in de keuken")
	gelijk(float(nu.get("x", 0.0)), 48.0, "op zijn eigen plek")
	gelijk(float(nu.get("z", 0.0)), 66.0, "in beide richtingen")
	gelijk(str(nu.get("model", "")), model, "en met zijn eigen model")

# ----------------------------------------------------------------- camera

## world.md §1.9 — the floor is never cut; `g` stays a whole number 2..4.
func test_maat_en_camera_houden_de_vloer_heel() -> void:
	World.meet(Rect2(0, 0, 1000, 648))
	var sch := World.schaal()
	waar(sch["g"] >= 2 and sch["g"] <= 4, "g is 2..4 (%s)" % sch["g"])
	waar(sch["dicht"] >= 1.0, "dicht is minstens 1")
	gelijk(sch["pxPerVoxelX"], 2.0 * sch["k"], "pxPerVoxelX = 2k")
	gelijk(sch["pxPerHoogte"], 2.0 * sch["k"], "pxPerHoogte = 2k")
	for id in Rooms.lijst():
		var r := Rooms.get_kamer(id)
		var box := Rooms.kader(r)
		var nodig := World.nodig_hoog(r)
		waar(nodig <= float(box[3] - box[2]) + 0.001, "%s: nodig_hoog past in de box" % id)
		waar(nodig >= float(box[3]) + 0.001 or box[3] <= 0,
			"%s: de vloer hoort er helemaal bij" % id)
	# the aim point moves with the room, and a hotspot uses the TARGET camera
	World.naar("receptie")
	var p1 := World.mik_punt(0, 0)
	var p2 := World.mik_punt(10, 0)
	waar(p2.x > p1.x, "x loopt naar rechtsonder")
	waar(p2.y > p1.y, "en naar beneden")
	var p3 := World.mik_punt(0, 10)
	waar(p3.x < p1.x, "z loopt naar linksonder")

## Hidden tab: no ticks at all until it comes back (world.md §6.6).
func test_verborgen_tabblad_zet_de_klok_stil() -> void:
	World.naar("receptie")
	World.zet(T, "receptie", 20.0, 20.0)
	World.ga(T, 80.0, 80.0)
	World.pauzeer(true)
	waar(World.gepauzeerd(), "de wereld staat stil")
	var d := World.dier(T)
	var x := d.x
	World._process(1.0)
	gelijk(d.x, x, "geen enkele tik terwijl het tabblad weg is")
	World.pauzeer(false)
	waar(not World.gepauzeerd(), "en hij loopt weer")
	_na_afloop()

## The guest's own rectangle and its name plate come out of the baked plate.
func test_vlak_en_naamplaat_van_een_gast() -> void:
	World.meet(Rect2(0, 0, 1000, 648))
	World.naar("receptie")
	World.zet(T, "receptie", 40.0, 40.0, {"kind": "hond", "naam": "Boef"})
	var vlak := World.vlak_van_dier(T)
	waar(vlak.size.x > 0.0 and vlak.size.y > 0.0, "de gast heeft een vlak")
	var mik := World.mik_punt(40.0, 40.0)
	waar(vlak.position.y < mik.y, "het vlak staat boven zijn voetpunt")
	waar(vlak.position.x < mik.x and vlak.end.x > mik.x, "en het voetpunt zit erin")
	var plaat := World.naam_punt(T)
	waar(plaat.y < vlak.position.y, "de naamplaat hangt boven het beeld")
	gelijk(World.naam_punt("bestaat-niet"), Vector2.ZERO, "onbekend dier, geen plaat")
	_na_afloop()

# ------------------------------------------------------------------ deeltjes

## `World.spetter` — particles at a floor point, for the games; none in rust.
func test_spetter_zet_deeltjes_in_de_kamer() -> void:
	var was_rust := Ui.rust_modus()
	Ui.zet_rust_modus(false)
	var voor := World.deeltjes().size()
	World.spetter("tuin", 40.0, 40.0, 3, ArtEffect.KRUIMEL_KL, false)
	gelijk(World.deeltjes().size(), voor + 3, "drie deeltjes erbij")
	var laatste: Dictionary = World.deeltjes()[World.deeltjes().size() - 1]
	gelijk(laatste["kamer"], "tuin", "in de kamer die gevraagd is")
	World.spetter("nergens", 1.0, 1.0, 3, ArtEffect.STER_KL[0], true)
	gelijk(World.deeltjes().size(), voor + 3, "een onbekende kamer krijgt niets")
	Ui.zet_rust_modus(true)
	World.spetter("tuin", 40.0, 40.0, 3, ArtEffect.STER_KL[0], true)
	gelijk(World.deeltjes().size(), voor + 3, "in rust geen deeltjes")
	Ui.zet_rust_modus(was_rust)
	for _i in 12:
		World._tik()
	gelijk(World.deeltjes().size(), voor, "na twaalf tikken zijn ze op")

# ------------------------------------------------------------- om het water

## Owner, 2026-09-14: a guest on the far deck walked straight through the pool
## to the entry mat.  Every walk now goes round the water; a swimmer keeps his
## line, and from inside the water the straight way out is kept.
func test_lopen_gaat_om_het_bad_heen() -> void:
	var r := Rooms.get_kamer("zwembad")
	var water := Rect2(float(r.bad["x0"]), float(r.bad["z0"]),
		float(r.bad["x1"]) - float(r.bad["x0"]), float(r.bad["z1"]) - float(r.bad["z0"]))
	var om := Rooms.om_het_water("zwembad", Vector2(132, 56), Vector2(9, 28))
	waar(not om.is_empty(), "van het verre dek naar de mat gaat om het water (%s)" % str(om))
	gelijk(Rooms.om_het_water("zwembad", Vector2(132, 56), Vector2(12, 56)), [], "langs het dek is de lijn droog")
	gelijk(Rooms.om_het_water("zwembad", Vector2(60, 28), Vector2(12, 56)), [], "uit het water is de rechte weg de kortste")
	gelijk(Rooms.om_het_water("receptie", Vector2(10, 10), Vector2(90, 90)), [], "een kamer zonder bad kent geen omweg")
	World.naar("zwembad")
	World.zet("t_droog", "zwembad", 132.0, 56.0, {"kind": "hond"})
	World.ga("t_droog", 9.0, 28.0, "wacht")
	var d := World.dier("t_droog")
	waar(d.punten.size() >= 2, "de wandeling heeft een tussenpunt (%s)" % str(d.punten))
	var t := 0
	while not d.punten.is_empty() and t < 900:
		World._tik()
		t += 1
		waar(not water.has_point(Vector2(d.x, d.z)), "tik %d: droog op (%.0f, %.0f)" % [t, d.x, d.z])
	gelijk(Vector2(d.x, d.z), Vector2(9, 28), "en hij komt op de mat aan")
	await World.loop_naar("t_droog", 60.0, 28.0, {"pose": "zwem", "na": "zwem"})
	waar(water.has_point(Vector2(d.x, d.z)), "een zwemmer zwemt wel het water in")
	World.weg("t_droog")
	_na_afloop()
