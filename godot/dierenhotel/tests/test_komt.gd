extends Proef
## "Boef komt eraan" (owner, 2026-09-14): a guest walking in from a room you
## cannot see gets a bubble at the door, with his pictogram, his name and a bar
## that fills until he is in view.  Driven tick by tick, as test_world does.

var _laag: Control = null

func _op() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = Vector2(1000, 648)
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	Ui.zet_rust_modus(false)
	World.meet(Rect2(Vector2.ZERO, _laag.size))
	World.naar("receptie")

func _af() -> void:
	Hotel.stop_volgen()
	World.weg("k_boef")
	World.naar("receptie")
	State.s["kamerNu"] = "receptie"
	Hotel.komt_eraan()
	Hits.wis_alles()
	Ui.zet_rust_modus(false)
	Ui.registreer_lagen(null, null, null)
	if _laag != null:
		_laag.queue_free()
		_laag = null

func _bubbel() -> UiWolk:
	var s := Hits.spot("komt_k_boef")
	return null if s == null or not is_instance_valid(s.knoop) else s.knoop as UiWolk

func test_bubbel_met_balk_tot_het_dier_in_beeld_is() -> void:
	_op()
	World.zet("k_boef", "kamer1", 60.0, 60.0, {"kind": "hond", "naam": "Boef"})
	var route := World.reis("k_boef", "receptie", {"x": 40.0, "z": 40.0, "na": "wacht"})
	waar(route.size() >= 3, "kamer1 -> gang -> receptie (%s)" % str(route))
	gelijk(World.reis_van("k_boef"), "gang", "hij komt straks uit de gang")
	Hotel.komt_eraan()
	var w := _bubbel()
	waar(w != null, "de bubbel hangt er zodra Boef vertrekt")
	if w == null:
		_af()
		return
	gelijk(w.icoon_label.text, "🐶", "het pictogram van een hond")
	gelijk(w.zeg_label.text, "Boef komt eraan", "de zin: naam en drie woorden")
	waar(w.balk != null, "met een balk")
	gelijk(Hits.spot("komt_k_boef").kamer, "receptie", "in de kamer die je ziet")
	var d := World.dier("k_boef")
	var vorige := -1.0
	var stijgt := true
	var t := 0
	while d.kamer != "receptie" and t < 900:
		World._tik()
		Hotel.komt_eraan()
		t += 1
		var nu := World.reis_voortgang("k_boef")
		if nu + 0.0001 < vorige:
			stijgt = false
		vorige = nu
		w = _bubbel()
		if w != null and absf(w.balk.value - nu) > 0.001:
			fout("de balk volgt de voortgang: %.3f tegen %.3f" % [w.balk.value, nu])
	gelijk(d.kamer, "receptie", "Boef is er")
	waar(stijgt, "de balk loopt alleen maar op")
	waar(vorige >= 0.9, "en staat bijna vol als hij de deur door komt (%.2f)" % vorige)
	Hotel.komt_eraan()
	waar(_bubbel() == null, "de bubbel is weg zodra hij in beeld is")
	gelijk(World.onderweg_naar("receptie"), [], "en niemand is meer onderweg")
	_af()

## Only the room you look at gets bubbles; walk to that room and it is there.
func test_alleen_voor_de_kamer_die_je_ziet() -> void:
	_op()
	World.zet("k_boef", "kamer1", 60.0, 60.0, {"kind": "poes", "naam": "Muis"})
	var route := World.reis("k_boef", "tuin")
	waar(route.size() >= 2, "er is een route naar de tuin")
	Hotel.komt_eraan()
	waar(_bubbel() == null, "in de receptie geen bubbel voor een kat op weg naar de tuin")
	World.naar("tuin")
	Hotel.komt_eraan()
	var w := _bubbel()
	waar(w != null, "in de tuin wel")
	if w != null:
		gelijk(w.icoon_label.text, "🐱", "met het pictogram van een poes")
		gelijk(Hits.spot("komt_k_boef").kamer, "tuin", "en die hangt in de tuin")
	World.naar("receptie")
	Hotel.komt_eraan()
	waar(_bubbel() == null, "terug in de receptie is hij weer weg")
	_af()

## Reduced motion: the walk resolves at once, so there is nothing to announce;
## and a new order cancels the journey and the bubble with it.
func test_rust_en_een_nieuwe_opdracht() -> void:
	_op()
	Ui.zet_rust_modus(true)
	World.zet("k_boef", "kamer1", 60.0, 60.0, {"kind": "konijn", "naam": "Pluis"})
	World.reis("k_boef", "receptie")
	gelijk(World.dier("k_boef").kamer, "receptie", "in rust is hij er meteen")
	Hotel.komt_eraan()
	waar(_bubbel() == null, "dus geen bubbel")
	Ui.zet_rust_modus(false)
	World.weg("k_boef")
	World.zet("k_boef", "kamer1", 60.0, 60.0, {"kind": "konijn", "naam": "Pluis"})
	World.reis("k_boef", "receptie")
	Hotel.komt_eraan()
	waar(_bubbel() != null, "onderweg: bubbel")
	World.ga("k_boef", 30.0, 30.0, "wacht")
	Hotel.komt_eraan()
	waar(_bubbel() == null, "een nieuwe opdracht in zijn eigen kamer haalt de bubbel weg")
	_af()

# ------------------------------------------------------------------ volgen

## "👀 Volg" (owner, 2026-09-23): the bubble carries the pill, and a tap takes
## the camera to the guest and along with him through every door, until he is
## in the room he was heading for.  There the walk ends by itself.
func test_volg_loopt_mee_tot_hij_er_is() -> void:
	_op()
	World.zet("k_boef", "kamer1", 60.0, 60.0, {"kind": "hond", "naam": "Boef"})
	World.reis("k_boef", "receptie", {"x": 40.0, "z": 40.0, "na": "wacht"})
	Hotel.komt_eraan()
	var w := _bubbel()
	waar(w != null and w.knop_label != null, "de bubbel draagt een knop")
	if w == null or w.knop_label == null:
		_af()
		return
	gelijk(w.knop_label.text, "👀 Volg", "die zegt wat een tik doet")
	w.pressed.emit()
	gelijk(Hotel.volgt(), "k_boef", "een tik: de camera loopt met Boef mee")
	gelijk(World.kamer_nu(), "kamer1", "en gaat eerst naar hem toe")
	gelijk(Ui.plaat_teken("k_boef"), "👀", "met ogen op zijn naambordje")
	var d := World.dier("k_boef")
	var kamers: Array = [World.kamer_nu()]
	var t := 0
	while not Hotel.volgt().is_empty() and t < 900:
		World._tik()
		Hotel._volg_stap()
		t += 1
		if World.kamer_nu() != d.kamer:
			fout("de camera is steeds waar Boef is: %s tegen %s" % [World.kamer_nu(), d.kamer])
			break
		if kamers.back() != World.kamer_nu():
			kamers.append(World.kamer_nu())
	gelijk(kamers, ["kamer1", "gang", "receptie"], "door elke deur mee")
	gelijk(d.kamer, "receptie", "Boef is er")
	gelijk(Hotel.volgt(), "", "en dan stopt het volgen vanzelf")
	gelijk(Ui.plaat_teken("k_boef"), "", "de ogen gaan van zijn bordje")
	gelijk(State.s["kamerNu"], "receptie", "het hotel weet waar je kijkt")
	for i in 40:
		World._tik()
		Hotel._volg_stap()
	gelijk(World.kamer_nu(), "receptie", "de camera blijft waar hij aankwam")
	_af()

## Choosing a room yourself ends the walk: the camera stays where you went
## while the guest walks on.  A guest who is not on his way is not followed.
func test_zelf_een_kamer_kiezen_stopt_het_volgen() -> void:
	_op()
	World.zet("k_boef", "kamer1", 60.0, 60.0, {"kind": "poes", "naam": "Muis"})
	World.reis("k_boef", "receptie")
	Hotel.volg("k_boef")
	gelijk(World.kamer_nu(), "kamer1", "de camera is bij Muis")
	Hotel.naar_kamer("tuin")
	gelijk(Hotel.volgt(), "", "een deur kiezen: je volgt niet meer")
	gelijk(Ui.plaat_teken("k_boef"), "", "en de ogen zijn weg")
	var t := 0
	while World.dier("k_boef").kamer != "receptie" and t < 900:
		World._tik()
		Hotel._volg_stap()
		t += 1
	gelijk(World.dier("k_boef").kamer, "receptie", "Muis loopt gewoon door")
	gelijk(World.kamer_nu(), "tuin", "en de camera blijft in de tuin")
	Hotel.volg("k_boef")
	gelijk(Hotel.volgt(), "", "wie er al is, volg je niet")
	gelijk(World.kamer_nu(), "tuin", "dus de camera blijft staan")
	_af()

## A game that starts takes the camera for itself: the walk ends, and while it
## runs only the animal it waits for may be followed (`Games.verwacht_dier`,
## see the tests below) — Pluis is not that animal.
func test_een_spel_stopt_het_volgen() -> void:
	_op()
	var def := Games.definitie("_voorbeeld")
	if not Rooms.bestaat(str(def.get("kamer", ""))):
		_af()
		return
	World.zet("k_boef", "kamer1", 60.0, 60.0, {"kind": "konijn", "naam": "Pluis"})
	World.reis("k_boef", "receptie")
	Hotel.volg("k_boef")
	gelijk(Hotel.volgt(), "k_boef", "je volgt Pluis")
	waar(Games.start("_voorbeeld"), "het spel start")
	gelijk(Hotel.volgt(), "", "het spel stopt het volgen")
	var kamer := World.kamer_nu()
	for i in 200:
		World._tik()
		Hotel._volg_stap()
	gelijk(World.kamer_nu(), kamer, "de camera blijft bij het spel")
	Hotel.volg("k_boef")
	gelijk(Hotel.volgt(), "", "tijdens een spel volg je niet wie het spel niet verwacht")
	Games.stop()
	_af()

# ------------------------------------------------- volgen tijdens een spel
##
## Owner, 2026-09-23: "Bij het zwembad is er geen volg optie om boef aan te
## komen tenzij ik eerst op 'terug' druk.  Zorg dat de minigame pas begint
## wanneer het dier er is."  The pool waits for its swimmer (`ctx.wacht_op`);
## his bubble stays in view while the game runs, and `👀 Volg` walks along with
## him through every door into the game's room, where the game then begins.

var _bewaard: Dictionary = {}

## One guest with a bed and the 🏊 wish, standing in `kamer`.
func _zwemmer(kamer: String) -> void:
	_bewaard = State.s.duplicate(true)
	var bedden := State.alle_bedden()
	var g: Dictionary = (State.gasten_pool()[0] as Dictionary).duplicate(true)
	g["id"] = "k_boef"
	g["naam"] = "Boef"
	g["name"] = "Boef"
	g["kind"] = "hond"
	g["kamer"] = str(bedden[0]["kamer"])
	g["bed"] = str(bedden[0]["slot"])
	g["waar"] = kamer
	g["behoefte"] = "zwemmen"
	g["blij"] = false
	g["nachten"] = 100
	State.s["gasten"] = [g]
	State.herbereken()
	State.spel_data("zwembad").clear()
	World.zet("k_boef", kamer, 60.0, 60.0, {"kind": "hond", "naam": "Boef"})

func _spel_af() -> void:
	Games.stop()
	World.pauzeer(false)
	World.weg("k_muis")
	if not _bewaard.is_empty():
		State.s = _bewaard
		_bewaard = {}
	_af()

func _volg_tot_het_eind(d) -> Array:
	var kamers: Array = [World.kamer_nu()]
	var t := 0
	while not Hotel.volgt().is_empty() and t < 3000:
		World._tik()
		Hotel._volg_stap()
		t += 1
		if d != null and World.kamer_nu() != d.kamer:
			fout("de camera is steeds waar Boef is: %s tegen %s" % [World.kamer_nu(), d.kamer])
			break
		if kamers.back() != World.kamer_nu():
			kamers.append(World.kamer_nu())
	return kamers

func _kaart_binnen(ms: int) -> bool:
	var boom := Engine.get_main_loop() as SceneTree
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await boom.process_frame
		var s := Hits.spot("zb_som_keuzes")
		if s != null and is_instance_valid(s.knoop):
			return true
	return false

func test_volg_tijdens_een_spel_het_dier_waarop_het_wacht() -> void:
	_op()
	_zwemmer("kamer1")
	World.pauzeer(true)                  # the test ticks the world itself
	waar(Games.start("zwembad"), "het zwembad start")
	gelijk(World.kamer_nu(), "zwembad", "de camera staat bij het water")
	waar(Games.verwacht_dier("k_boef"), "het spel wacht op Boef")
	waar(Hits.spot("zb_som") == null, "er staat nog geen vraag")
	Hotel.komt_eraan()
	Hits.plaats()
	var w := _bubbel()
	waar(w != null and w.visible, "zijn wolkje staat in beeld, ook nu het spel loopt")
	if w == null or w.knop_label == null:
		_spel_af()
		return
	gelijk(w.knop_label.text, "👀 Volg", "met de knop die zegt wat een tik doet")
	w.pressed.emit()
	gelijk(Hotel.volgt(), "k_boef", "een tik: de camera loopt met Boef mee")
	gelijk(World.kamer_nu(), "kamer1", "en gaat eerst naar hem toe")
	gelijk(Games.actief(), "zwembad", "het spel loopt gewoon door")
	gelijk(Ui.plaat_teken("k_boef"), "👀", "met ogen op zijn naambordje")
	Hits.plaats()
	var kaart_elders := Hits.spot("zb_vlagtag")
	waar(kaart_elders == null or not kaart_elders.knoop.visible,
		"wat van het spel is blijft bij het water, niet in kamer 1")
	var d := World.dier("k_boef")
	var kamers := _volg_tot_het_eind(d)
	# down in the lift and out through the lobby's back door (the tower,
	# 2026-09-24): the camera rides along
	gelijk(kamers, ["kamer1", "gang", "receptie", "tuin", "zwembad"], "door elke deur en de lift mee")
	gelijk(World.kamer_nu(), "zwembad", "de camera eindigt bij het spel")
	gelijk(Hotel.volgt(), "", "daar stopt het volgen vanzelf")
	gelijk(Ui.plaat_teken("k_boef"), "", "de ogen gaan van zijn bordje")
	gelijk(Games.actief(), "zwembad", "het spel loopt nog")
	Hits.plaats()
	var vlag := Hits.spot("zb_vlagtag")
	waar(vlag != null and vlag.knoop.visible, "terug bij het water staat de baan weer in beeld")
	waar(Hits.spot("zb_som") == null, "hij loopt nog naar het dek: nog geen vraag")
	var t := 0
	while not (d.punten as Array).is_empty() and t < 3000:
		World._tik()
		t += 1
	waar(await _kaart_binnen(1500), "op het dek: nu begint het spel, met de strook")
	_spel_af()

## While the pool waits for Boef, somebody else walking in keeps his bubble off
## the glass (every hotel button steps aside during a game), and `volg` refuses
## him: only the animal the game waits for may be followed.
func test_een_ander_dier_volg_je_tijdens_een_spel_niet() -> void:
	_op()
	_zwemmer("kamer1")
	World.pauzeer(true)
	waar(Games.start("zwembad"), "het zwembad start")
	World.zet("k_muis", "keuken", 60.0, 60.0, {"kind": "poes", "naam": "Muis"})
	World.reis("k_muis", "zwembad")
	Hotel.komt_eraan()
	Hits.plaats()
	var muis := Hits.spot("komt_k_muis")
	waar(muis != null, "ook Muis heeft een wolkje")
	waar(muis == null or not muis.knoop.visible, "maar dat staat niet in beeld tijdens het spel")
	var boef := Hits.spot("komt_k_boef")
	waar(boef != null and boef.knoop.visible, "dat van Boef wel")
	Hotel.volg("k_muis")
	gelijk(Hotel.volgt(), "", "Muis volg je niet: op haar wacht het spel niet")
	gelijk(World.kamer_nu(), "zwembad", "de camera blijft bij het water")
	_spel_af()

## `⬅ Terug` while following: the game stops, and the walk ends with it — the
## camera stays in the room it was in and the eyes leave his plate.
func test_het_volgen_eindigt_met_het_spel() -> void:
	_op()
	_zwemmer("kamer1")
	World.pauzeer(true)
	waar(Games.start("zwembad"), "het zwembad start")
	Hotel.komt_eraan()
	Hotel.volg("k_boef")
	gelijk(Hotel.volgt(), "k_boef", "je volgt Boef")
	var d := World.dier("k_boef")
	var t := 0
	while d.kamer == "kamer1" and t < 2000:
		World._tik()
		Hotel._volg_stap()
		t += 1
	gelijk(World.kamer_nu(), "gang", "de camera is met hem mee de gang in")
	Games.stop()
	gelijk(Hotel.volgt(), "", "het spel stopt: het volgen ook")
	gelijk(Ui.plaat_teken("k_boef"), "", "de ogen zijn weg")
	gelijk(World.kamer_nu(), "gang", "en de camera blijft waar hij was")
	_spel_af()

## A walk along that ends before he is in the game's room — he is gone — brings
## the camera back to the game: never a child left in a room without its doors.
func test_is_hij_weg_dan_terug_naar_het_spel() -> void:
	_op()
	_zwemmer("kamer1")
	World.pauzeer(true)
	waar(Games.start("zwembad"), "het zwembad start")
	Hotel.komt_eraan()
	Hotel.volg("k_boef")
	gelijk(World.kamer_nu(), "kamer1", "de camera is bij Boef")
	World.weg("k_boef")
	Hotel._volg_stap()
	gelijk(Hotel.volgt(), "", "wie er niet meer is, volg je niet")
	gelijk(World.kamer_nu(), "zwembad", "de camera gaat terug naar het spel")
	_spel_af()
