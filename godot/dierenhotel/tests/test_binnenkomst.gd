extends Proef
## The front door of the receptie and the way a guest comes in through it
## (owner, 2026-09-23: "En nog een agent om het binnenkomen van dieren te
## verbeteren die komen momenteel vanuit de gang binnen ipv ingang.  Doe ook een
## leuke animatie wanneer ze binnenkomen dat per dier anders is") — world.md
## §1.2, §2.5 and §3.3, art-sound-rules.md §5.2 and §11.8.
##
## The think tick is driven BY HAND (`World._tik()`), as in test_world.gd, so
## every arrival below is deterministic and costs no wall-clock time.  The room
## data itself (the door, what hides it, the way round the desk) is held in
## test_rooms.gd; the buttons of the real shell in `test_geen_knop_op_de_voordeur`.

const T := "t_binnen"
const DOEL := Vector2(65, 44)          ## BALIEPLEK(0): in front of the middle of the desk
## "A few seconds at most": five, at the world's 15 ticks a second.
const MAX_TIKKEN := 75
const SOORTEN := ["hond", "poes", "konijn", "gans"]

func _na_afloop() -> void:
	World.weg(T)
	World.naar("receptie")

## One arrival of a guest of `kind`, played to its end and recorded tick by
## tick: the poses in the order they came (a repeat is not written twice), the
## jumps (every take-off from the floor), the highest point, the turns, where
## he stood, and when the door fell shut.
func _speel(kind: String, doel := DOEL) -> Dictionary:
	World.naar("receptie")
	World.zet(T, "receptie", 60.0, 90.0, {"kind": kind, "naam": "Tessa"})
	var d = World.dier(T)
	var ing := Rooms.ingang("receptie")
	var drempel := Vector2(float(ing["dx"]), float(ing["dz"]))
	var gestart := World.kom_binnen(T, doel.x, doel.y)
	var uit := {"gestart": gestart, "start": Vector2(d.x, d.z), "staat0": d.staat,
		"open0": World.ingang_open("receptie"), "poses": [], "sprongen": 0,
		"hoogst": 0.0, "draaien": 0, "plekken": [], "dicht_op": -1, "dicht_af": -1.0}
	var poses: Array = uit["poses"]
	var lucht := false
	var face: int = d.face
	var t := 0
	while World.komt_binnen(T) and t < 300:
		World._tik()
		t += 1
		if poses.is_empty() or poses[poses.size() - 1] != d.pose:
			poses.append(d.pose)
		if d.hoogte > 0.5 and not lucht:
			uit["sprongen"] = int(uit["sprongen"]) + 1
		lucht = d.hoogte > 0.5
		uit["hoogst"] = maxf(float(uit["hoogst"]), d.hoogte)
		if d.face != face:
			uit["draaien"] = int(uit["draaien"]) + 1
			face = d.face
		(uit["plekken"] as Array).append(Vector2(d.x, d.z))
		if int(uit["dicht_op"]) < 0 and not World.ingang_open("receptie"):
			uit["dicht_op"] = t
			uit["dicht_af"] = Vector2(d.x, d.z).distance_to(drempel)
	uit["tikken"] = t
	uit["eind"] = Vector2(d.x, d.z)
	uit["staat"] = d.staat
	uit["pose"] = d.pose
	uit["hoogte"] = d.hoogte
	return uit

func _met_beweging(fn: Callable) -> void:
	var was := Ui.rust_modus()
	Ui.zet_rust_modus(false)
	fn.call()
	Ui.zet_rust_modus(was)

# ------------------------------------------------------------- per soort

## Every kind comes in its own way, and every way ends the same: on the spot at
## the desk, in the plain waiting pose, within five seconds.
func test_elk_dier_komt_anders_binnen() -> void:
	var was := Ui.rust_modus()
	Ui.zet_rust_modus(false)
	var reeks := {}
	var r := {}
	for kind in SOORTEN:
		var s := _speel(kind)
		r[kind] = s
		reeks[kind] = s["poses"]
		waar(s["gestart"], "%s: de binnenkomst begint" % kind)
		gelijk(s["staat0"], "komt", "%s: hij komt binnen" % kind)
		waar(int(s["tikken"]) <= MAX_TIKKEN,
			"%s: binnen in %d tikken (hooguit %d = 5 s)" % [kind, s["tikken"], MAX_TIKKEN])
		waar(int(s["tikken"]) >= 30, "%s: en het is wel een animatie (%d tikken)" % [kind, s["tikken"]])
		gelijk(s["eind"], DOEL, "%s: hij eindigt op zijn plek aan de balie" % kind)
		gelijk(s["staat"], "wacht", "%s: en wacht daar" % kind)
		gelijk(s["pose"], "rust", "%s: in de gewone wachthouding" % kind)
		gelijk(s["hoogte"], 0.0, "%s: met zijn poten op de vloer" % kind)
	# four different animations: no two kinds play the same frames
	for i in SOORTEN.size():
		for j in range(i + 1, SOORTEN.size()):
			waar(reeks[SOORTEN[i]] != reeks[SOORTEN[j]], "%s en %s komen anders binnen (%s / %s)"
				% [SOORTEN[i], SOORTEN[j], str(reeks[SOORTEN[i]]), str(reeks[SOORTEN[j]])])
	# and each kind the way it was written (wereld/binnenkomst.gd)
	var hond: Dictionary = r["hond"]
	waar(int(hond["sprongen"]) >= 3, "de puppy springt naar binnen (%d sprongen)" % hond["sprongen"])
	waar(int(hond["draaien"]) >= 4, "en draait rondjes aan de balie (%d keer)" % hond["draaien"])
	waar((hond["poses"] as Array).has("blijA") and (hond["poses"] as Array).has("blijB"),
		"kwispelend")
	var poes: Dictionary = r["poes"]
	waar((poes["poses"] as Array).has("sluipA") and (poes["poses"] as Array).has("sluipB"),
		"de poes sluipt naar binnen")
	waar((poes["poses"] as Array).has("strek"), "en rekt zich uit aan de balie")
	waar((poes["poses"] as Array).has("zit"), "en gaat netjes zitten")
	gelijk(int(poes["sprongen"]), 0, "de poes springt niet")
	var konijn: Dictionary = r["konijn"]
	waar(int(konijn["sprongen"]) >= 6, "het konijn huppelt helemaal naar binnen (%d sprongetjes)"
		% konijn["sprongen"])
	waar(float(konijn["hoogst"]) > 8.0, "met één grote sprong aan de balie (top %.1f)" % konijn["hoogst"])
	var gans: Dictionary = r["gans"]
	waar((gans["poses"] as Array).has("fladder"), "de gans slaat met zijn vleugels")
	waar((gans["poses"] as Array).has("fladderA") and (gans["poses"] as Array).has("fladderB"),
		"ook al lopend")
	gelijk(int(gans["sprongen"]), 0, "de gans waggelt, hij springt niet")
	Ui.zet_rust_modus(was)
	_na_afloop()

## He appears on the threshold of the front door — not at the corridor door —
## and the door stands open until he is well inside: the child sees the sky
## behind him.  It falls shut once, when he is clear of the doorway.
func test_de_voordeur_staat_open_tot_hij_binnen_is() -> void:
	var was := Ui.rust_modus()
	Ui.zet_rust_modus(false)
	var ing := Rooms.ingang("receptie")
	var gang := Rooms.deur("receptie", "gang")
	for kind in SOORTEN:
		var s := _speel(kind)
		var start: Vector2 = s["start"]
		gelijk(start, Vector2(float(ing["dx"]), float(ing["dz"])), "%s: op de drempel van de voordeur" % kind)
		waar(start.distance_to(Vector2(float(gang["ix"]), float(gang["iz"]))) > 60.0,
			"%s: ver van de deur naar de gang" % kind)
		waar(s["open0"], "%s: de voordeur gaat open" % kind)
		var dicht := int(s["dicht_op"])
		waar(dicht >= 6, "%s: en blijft even open (%d tikken)" % [kind, dicht])
		waar(float(s["dicht_af"]) >= WereldBinnenkomst.DEUR_AF,
			"%s: tot hij binnen is (%.0f voxels van de drempel)" % [kind, s["dicht_af"]])
		waar(not World.ingang_open("receptie"), "%s: daarna is ze dicht" % kind)
	Ui.zet_rust_modus(was)
	_na_afloop()

## No step of any arrival crosses the desk or leaves the room (world.md §1.3:
## no walk in the receptie crosses the counter), to any of the three spots.
func test_niemand_komt_door_de_balie_binnen() -> void:
	var was := Ui.rust_modus()
	Ui.zet_rust_modus(false)
	var r := Rooms.get_kamer("receptie")
	var b: Dictionary = r.balie
	for i in 3:
		var p := Hotel._balieplek(i)
		var doel := Vector2(float(p["x"]), float(p["z"]))
		for kind in SOORTEN:
			var s := _speel(kind, doel)
			var mis := 0
			for q in s["plekken"]:
				var v: Vector2 = q
				if v.x >= float(b["x0"]) and v.x <= float(b["x1"]) \
						and v.y >= float(b["z0"]) and v.y <= float(b["z1"]):
					mis += 1
				if v.x < 0.0 or v.y < 0.0 or v.x > r.w or v.y > r.d:
					mis += 1
			gelijk(mis, 0, "%s naar plek %d: nooit op de balie of buiten de kamer" % [kind, i])
			gelijk(s["eind"], doel, "%s: op plek %d" % [kind, i])
	Ui.zet_rust_modus(was)
	_na_afloop()

# ------------------------------------------------------------ de bel

## `Hotel.bel()`: the new guest comes in through the front door and ends at the
## desk; the check-in does not wait for him — its question is there at once.
func test_de_bel_haalt_de_gast_door_de_voordeur() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var was := Ui.rust_modus()
	Ui.zet_rust_modus(false)
	alleen_spellen([])
	State.nieuw_spel()
	State.s["taken"] = []
	World.naar("receptie")
	Hotel.bel()
	var v = State.s["checkin"]
	waar(v != null, "er is een check-in")
	if v != null:
		var id := str(v["gastId"])
		var d = World.dier(id)
		var ing := Rooms.ingang("receptie")
		waar(d != null, "de gast is er")
		if d != null:
			gelijk(d.kamer, "receptie", "in de receptie")
			gelijk(Vector2(d.x, d.z), Vector2(float(ing["dx"]), float(ing["dz"])),
				"op de drempel van de voordeur, niet bij de gangdeur")
			waar(World.komt_binnen(id), "en hij komt binnen")
			waar(World.ingang_open("receptie"), "door de open voordeur")
			gelijk(int(v["stap"]), 1, "de eerste vraag staat er al: de check-in wacht niet")
			var t := 0
			while World.komt_binnen(id) and t < 200:
				World._tik()
				t += 1
			var p := Hotel._balieplek()
			gelijk(Vector2(d.x, d.z), Vector2(float(p["x"]), float(p["z"])), "hij staat aan de balie")
			gelijk(d.staat, "wacht", "en wacht op het kind")
			waar(t <= MAX_TIKKEN, "binnen vijf seconden (%d tikken)" % t)
			waar(not World.ingang_open("receptie"), "de voordeur is weer dicht")
			gelijk(State.s["checkin"]["gastId"], id, "de check-in is gewoon van hem")
		World.weg(id)
	State.s = bewaard
	World.sync(Hotel.alle_dieren())
	Ui.zet_rust_modus(was)
	_na_afloop()

## The child may answer while the guest is still on his way in: choosing a bed
## sends him to it at once, and nothing of the arrival comes back afterwards.
func test_wie_snel_een_bed_kiest_hoeft_niet_te_wachten() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var was := Ui.rust_modus()
	Ui.zet_rust_modus(false)
	alleen_spellen([])
	State.nieuw_spel()
	State.s["taken"] = []
	Rooms.herstel()
	World.naar("receptie")
	Hotel.bel()
	var v = State.s["checkin"]
	waar(v != null, "er is een check-in")
	if v != null:
		var id := str(v["gastId"])
		var d = World.dier(id)
		for i in 6:
			World._tik()
		waar(World.komt_binnen(id), "hij is nog onderweg naar binnen")
		v["stap"] = 3
		waar(Hotel.wijs_bed("kamer1", "bed1"), "het kind kiest al een bed")
		waar(not World.komt_binnen(id), "de binnenkomst houdt meteen op")
		gelijk(d.slaap_doel, "bed1", "hij gaat naar zijn bed")
		gelijk((d.komt as Array).size(), 0, "er blijft niets van de binnenkomst over")
		gelijk(d.hoogte, 0.0, "met zijn poten op de vloer, ook midden in een sprong")
		for i in 400:
			World._tik()
			waar(d.staat != "komt", "hij komt niet opnieuw binnen")
			if World.slaapt(id):
				break
		waar(World.slaapt(id), "hij slaapt in zijn bed")
		World.weg(id)
	State.s = bewaard
	World.sync(Hotel.alle_dieren())
	Rooms.herstel()
	Ui.zet_rust_modus(was)
	_na_afloop()

# ------------------------------------------------------ andere opdrachten

## Any other order takes the guest over, exactly as it takes over a walk; the
## door falls shut on its own.
func test_een_ander_bevel_neemt_het_binnenkomen_over() -> void:
	var was := Ui.rust_modus()
	Ui.zet_rust_modus(false)
	for kind in SOORTEN:
		World.naar("receptie")
		World.zet(T, "receptie", 60.0, 90.0, {"kind": kind})
		World.kom_binnen(T, DOEL.x, DOEL.y)
		for i in 9:
			World._tik()
		World.ga(T, 40.0, 90.0, "wacht")
		var d = World.dier(T)
		waar(not World.komt_binnen(T), "%s: het nieuwe bevel gaat voor" % kind)
		gelijk(d.hoogte, 0.0, "%s: meteen op de vloer" % kind)
		for i in 120:
			World._tik()
			waar(d.staat != "komt", "%s: de binnenkomst komt niet terug" % kind)
		gelijk(Vector2(d.x, d.z), Vector2(40, 90), "%s: hij liep waar hij heen moest" % kind)
		waar(not World.ingang_open("receptie"), "%s: de voordeur viel vanzelf dicht" % kind)
	Ui.zet_rust_modus(was)
	_na_afloop()

## A room nobody looks at plays no arrival: he is at the desk at once.
func test_buiten_beeld_staat_hij_meteen_aan_de_balie() -> void:
	var was := Ui.rust_modus()
	Ui.zet_rust_modus(false)
	World.naar("receptie")
	World.zet(T, "receptie", 60.0, 90.0, {"kind": "gans"})
	World.kom_binnen(T, DOEL.x, DOEL.y)
	World.naar("gang")
	World._tik()
	var d = World.dier(T)
	gelijk(Vector2(d.x, d.z), DOEL, "aan de balie")
	gelijk(d.staat, "wacht", "wachtend")
	waar(not World.ingang_open("receptie"), "de voordeur is dicht")
	Ui.zet_rust_modus(was)
	_na_afloop()

## Reduced motion (architecture.md §5.1): no arrival at all — the guest simply
## stands at the desk, and the door never opens.
func test_rustmodus_zet_hem_meteen_aan_de_balie() -> void:
	var was := Ui.rust_modus()
	Ui.zet_rust_modus(true)
	World.naar("receptie")
	World.zet(T, "receptie", 60.0, 90.0, {"kind": "hond"})
	waar(World.kom_binnen(T, DOEL.x, DOEL.y), "de opdracht wordt aangenomen")
	var d = World.dier(T)
	gelijk(Vector2(d.x, d.z), DOEL, "hij staat meteen aan de balie")
	gelijk(d.staat, "wacht", "en wacht")
	waar(not World.komt_binnen(T), "er is geen binnenkomst")
	waar(not World.ingang_open("receptie"), "de voordeur gaat niet open")
	# and the bell does the same
	var bewaard: Dictionary = State.s.duplicate(true)
	alleen_spellen([])
	State.nieuw_spel()
	State.s["taken"] = []
	Hotel.bel()
	var v = State.s["checkin"]
	waar(v != null, "de bel haalt een gast")
	if v != null:
		var g = World.dier(str(v["gastId"]))
		var p := Hotel._balieplek()
		gelijk(Vector2(g.x, g.z), Vector2(float(p["x"]), float(p["z"])), "die meteen aan de balie staat")
		gelijk(g.staat, "wacht", "en wacht")
		World.weg(str(v["gastId"]))
	State.s = bewaard
	World.sync(Hotel.alle_dieren())
	# switched on halfway: the arrival stops where it is and he stands at the desk
	# (the bell's `World.sync` took the test guest away: a fresh one)
	Ui.zet_rust_modus(false)
	World.zet(T, "receptie", 60.0, 90.0, {"kind": "konijn"})
	d = World.dier(T)
	World.kom_binnen(T, DOEL.x, DOEL.y)
	for i in 5:
		World._tik()
	waar(World.komt_binnen(T), "hij is onderweg")
	Ui.zet_rust_modus(true)
	World._tik()
	gelijk(Vector2(d.x, d.z), DOEL, "rustmodus halverwege: meteen aan de balie")
	gelijk(d.hoogte, 0.0, "op de vloer")
	gelijk(d.staat, "wacht", "wachtend")
	Ui.zet_rust_modus(was)
	_na_afloop()

# ------------------------------------------------------------ de houdingen

## The arrival's own frames (art-sound-rules.md §5.2) bake for every kind, each
## looks different from the frame it is made from, and the fifteen poses of
## the HTML — every one held against a golden plate — are not touched.
func test_de_houdingen_van_het_binnenkomen() -> void:
	gelijk(ArtGasten.POSE.size(), 15, "de vijftien houdingen van de HTML blijven vijftien")
	var basis := {"sluipA": "loopA", "sluipB": "loopB", "strek": "rust", "fladder": "rust",
		"fladderA": "loopA", "fladderB": "loopB"}
	gelijk(ArtGasten.POSE_EXTRA.size(), basis.size(), "zes houdingen voor het binnenkomen")
	for naam in ArtGasten.POSE_EXTRA:
		waar(not ArtGasten.POSE.has(naam), "%s staat niet tussen de gouden houdingen" % naam)
		waar(basis.has(naam), "%s is bekend" % naam)
		for kind in ArtGasten.SOORTEN:
			var p = Art.dier(kind, naam, 2)
			waar(p != null and p.w > 0 and p.h > 0, "%s bakt voor %s" % [naam, kind])
	# each one is a frame of its own for the kind that uses it
	for paar in [["poes", "sluipA"], ["poes", "sluipB"], ["poes", "strek"], ["gans", "fladder"],
			["gans", "fladderA"], ["gans", "fladderB"]]:
		var kind: String = paar[0]
		var naam: String = paar[1]
		var eigen: Array = ArtGasten.bouw(kind, naam, "")
		var van: Array = ArtGasten.bouw(kind, str(basis[naam]), "")
		waar(str(eigen) != str(van), "%s: %s is anders dan %s" % [kind, naam, basis[naam]])
	# the stretch: the rear higher than the head
	var strek: Array = ArtGasten.bouw("poes", "strek", "")
	var achter := 0
	var voor := 0
	for q in strek:
		if int(q["x"]) <= 8:
			achter = maxi(achter, int(q["y"]))
		if int(q["x"]) >= 22:
			voor = maxi(voor, int(q["y"]))
	waar(achter > voor, "bij het uitrekken gaat het achterlijf omhoog (%d) en de kop omlaag (%d)"
		% [achter, voor])
	# the flap: the wings rise over the back
	var hoog_rust := 0
	var hoog_flad := 0
	for q in ArtGasten.bouw("gans", "rust", ""):
		if int(q["x"]) <= 14:
			hoog_rust = maxi(hoog_rust, int(q["y"]))
	for q in ArtGasten.bouw("gans", "fladder", ""):
		if int(q["x"]) <= 14:
			hoog_flad = maxi(hoog_flad, int(q["y"]))
	waar(hoog_flad >= hoog_rust + 4, "de vleugels gaan boven de rug uit (%d tegen %d)"
		% [hoog_flad, hoog_rust])
	# with an outfit on, too
	waar(Art.dier("poes", "strek", 2, ["hoedje", "sjaaltje", "bal"]) != null, "met hoedje, sjaal en bal")

## The front door is a closed door with a pane when nobody comes in, and an
## opening onto the outside while somebody does — two plates.
func test_de_voordeur_open_en_dicht() -> void:
	waar(Art.heeft_model("voordeur") and Art.is_wereldmodel("voordeur"), "de voordeur is een wereldmodel")
	waar(Art.heeft_model("welkomsmat") and Art.is_wereldmodel("welkomsmat"), "de welkomstmat ook")
	var dicht = Art.plaat("voordeur", 2)
	var open = Art.plaat("voordeur", 2, {"open": 1})
	waar(dicht != null and open != null, "beide standen bakken")
	if dicht != null and open != null:
		waar(dicht.tex.get_image().get_data() != open.tex.get_image().get_data(),
			"open ziet er anders uit dan dicht")
	var kleuren := {}
	for q in Art.model("voordeur", {"open": 1}):
		kleuren[(q["k"] as Color).to_html()] = true
	waar(kleuren.has(ArtDecorHotel.BUITEN.to_html()), "door de open deur zie je de lucht")
	waar(not kleuren.has(ArtDecorHotel.DEUR.to_html()), "en geen deurblad")

# ------------------------------------------------------ de echte receptie

## The screens the real shell is measured on (test_hits.gd SCHERMEN, and the
## two landscape phones and the wide desktop of the owner's captures).
const SCHERMEN := [Vector2i(1024, 768), Vector2i(768, 1024), Vector2i(1280, 800),
	Vector2i(360, 740), Vector2i(740, 360), Vector2i(1536, 760)]

## The whole shell in a SubViewport with a fresh hotel in the receptie — the
## same fixture as test_hits.gd `_hotel_op`: only the real shell centres a room.
func _hotel_op(maat: Vector2i) -> Dictionary:
	var boom := Engine.get_main_loop() as SceneTree
	var vp := SubViewport.new()
	vp.size = maat
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	boom.root.add_child(vp)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var shell := scene.instantiate()
	shell.set_meta("geen_start", true)     # never touch the save from a test
	vp.add_child(shell)
	for _f in 4:
		await boom.process_frame
	State.nieuw_spel()
	Hotel.start()
	Hotel.bord_dicht()
	for _f in 4:
		await boom.process_frame
	return {"vp": vp, "shell": shell}

func _hotel_af(h: Dictionary) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	Ui.naamplaten_leeg()
	Hits.wis_alles()
	(h["vp"] as SubViewport).queue_free()
	await boom.process_frame
	Ui.registreer_lagen(null, null, null)
	State.nieuw_spel()

## The share of the front door a placed hotspot hides, the largest one, and
## whose it is.
func _op_de_deur() -> Dictionary:
	var deur := World.vlak_van_ingang("receptie")
	var uit := {"deel": 0.0, "id": "", "deur": deur}
	var dbg := Hits.debug()
	for id in dbg:
		var snij: Rect2 = (dbg[id]["rect"] as Rect2).intersection(deur)
		if snij.size.x <= 0.0 or snij.size.y <= 0.0:
			continue
		var deel := snij.size.x * snij.size.y / maxf(1.0, deur.size.x * deur.size.y)
		if deel > float(uit["deel"]):
			uit["deel"] = deel
			uit["id"] = id
	return uit

## "Without a hotel button landing on it": in the receptie as it stands, and
## through every step of a check-in, no button, card or bubble hides the front
## door — measured with the placement's own rule for another thing
## (`Hits.VREEMD_DEEL`, 15 %).  On every screen the door is in the frame.
func test_geen_knop_op_de_voordeur() -> void:
	var bewaard: Dictionary = State.s.duplicate(true)
	var boom := Engine.get_main_loop() as SceneTree
	var was := Ui.rust_modus()
	Ui.zet_rust_modus(true)                 # the guest stands at the desk at once
	for maat in SCHERMEN:
		var h: Dictionary = await _hotel_op(maat)
		var kader := World.kader_rect()
		var deur := World.vlak_van_ingang("receptie")
		waar(deur.size.x > 0.0 and deur.size.y > 0.0, "%s: de voordeur heeft een vlak" % str(maat))
		waar(Rect2(Vector2.ZERO, kader.size).encloses(deur),
			"%s: de hele voordeur staat in het kader (%s in %s)" % [str(maat), str(deur), str(kader.size)])
		waar(Hits.debug().size() >= 4, "%s: de knoppen van de receptie staan er (%d)"
			% [str(maat), Hits.debug().size()])
		var m := _op_de_deur()
		waar(float(m["deel"]) < Hits.VREEMD_DEEL, "%s: in de receptie dekt %s %.0f %% van de voordeur"
			% [str(maat), m["id"], float(m["deel"]) * 100.0])
		Hotel.bel()
		for stap in [1, 2, 3]:
			var v = State.s["checkin"]
			waar(v != null, "%s: er checkt iemand in" % str(maat))
			if v == null:
				break
			v["stap"] = stap
			Hotel.paint_checkin()
			Hotel.render()
			for _f in 3:
				await boom.process_frame
			m = _op_de_deur()
			waar(float(m["deel"]) < Hits.VREEMD_DEEL, "%s: bij vraag %d dekt %s %.0f %% van de voordeur"
				% [str(maat), stap, m["id"], float(m["deel"]) * 100.0])
		await _hotel_af(h)
	Ui.zet_rust_modus(was)
	State.s = bewaard
