extends Proef
## A tap on a wish takes you where it can come true, and the morning is the
## bell, not the board (owner, 2026-09-23: "Als ik eten druk gebeurt er niks
## dat zou me naar de keuken moeten brengen" · "laat niet het prikbord zien als
## start. De gebruiker moet gewoon op de bel drukken").  With a real button
## layer, as test_komt: the pulse lives on the hotel's buttons.

var _laag: Control = null

func _op() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	_laag = Control.new()
	_laag.size = Vector2(1000, 648)
	boom.root.add_child(_laag)
	Ui.registreer_lagen(_laag, _laag, _laag, _laag, _laag)
	Ui.zet_rust_modus(false)
	World.meet(Rect2(Vector2.ZERO, _laag.size))
	State.nieuw_spel()
	State.start_gekozen()
	Econ.rekening_stop()
	State.s["taken"] = []
	World.naar("receptie")
	State.s["kamerNu"] = "receptie"

func _af() -> void:
	Games.stop()
	Hotel.bord_dicht()
	for d in World.dieren():
		World.weg(d.id)
	Hits.wis_alles()
	World.naar("receptie")
	State.nieuw_spel()
	Ui.registreer_lagen(null, null, null)
	if _laag != null:
		_laag.queue_free()
		_laag = null

## Two guests from the pool in the first two real beds; the first one wants
## `behoefte`, the other has what he wants.
func _gasten(behoefte: String) -> Array:
	var pool := State.gasten_pool()
	var bedden := State.alle_bedden()
	var uit: Array = []
	for i in 2:
		var g: Dictionary = pool[i]
		g["kamer"] = str(bedden[i]["kamer"])
		g["bed"] = str(bedden[i]["slot"])
		g["waar"] = g["kamer"]
		g["nachten"] = 100
		g["behoefte"] = behoefte if i == 0 else "eten"
		g["gegeten"] = i != 0 or behoefte != "eten"
		g["blij"] = false
		uit.append(g)
	State.s["gasten"] = uit
	World.sync(Hotel.alle_dieren())
	return uit

func _bak_van(kamer: String) -> String:
	for slot in Rooms.slots(kamer, "bak"):
		if not bool(slot.get("tijdelijk", false)):
			return str(slot.get("id", ""))
	return ""

func _pulseert(id: String) -> bool:
	var s := Hits.spot(id)
	return s != null and is_instance_valid(s.knoop) and s.knoop is UiHotKnop \
		and (s.knoop as UiHotKnop).pulseert()

## 🍪 with an empty bowl: the tap opens the trolley in the kitchen — what the
## "Vul de voerkar" card on the board does.
func test_eten_met_een_leeg_bakje_opent_de_voerkar() -> void:
	_op()
	var gasten := _gasten("eten")
	var kamer := str(gasten[0]["kamer"])
	var bak := _bak_van(kamer)
	waar(not bak.is_empty(), "zijn kamer heeft een bakje")
	World.zet_bak(kamer, bak, 0)
	Hotel.render()
	Hotel.wens_tik(str(gasten[0]["id"]))
	gelijk(World.kamer_nu(), "keuken", "naar de keuken")
	gelijk(Games.actief(), "voerkar", "en de voerkar gaat open")
	_af()

## 🍪 with food in his bowl: to his room, where the bowl is the thing to tap —
## and it pulses.
func test_eten_met_eten_in_het_bakje_wijst_het_bakje_aan() -> void:
	_op()
	var gasten := _gasten("eten")
	var kamer := str(gasten[0]["kamer"])
	var bak := _bak_van(kamer)
	World.zet_bak(kamer, bak, 3)
	Hotel.render()
	Hotel.wens_tik(str(gasten[0]["id"]))
	gelijk(World.kamer_nu(), kamer, "naar zijn kamer")
	gelijk(Games.actief(), "", "geen spel: het bakje is het werk")
	waar(_pulseert("bak_%s_%s" % [kamer, bak]), "het bakje vraagt om een tik")
	_af()

## 🧶: to his room, where the play basket pulses.
func test_spelen_wijst_de_speelmand_aan() -> void:
	_op()
	var gasten := _gasten("spelen")
	var kamer := str(gasten[0]["kamer"])
	if Hotel.decor_plek(kamer, "mand").is_empty():
		_af()
		return
	Hotel.render()
	Hotel.wens_tik(str(gasten[0]["id"]))
	gelijk(World.kamer_nu(), kamer, "naar zijn kamer")
	waar(_pulseert("mand_%s" % kamer), "de speelmand vraagt om een tik")
	waar(not _pulseert("bak_%s_%s" % [kamer, _bak_van(kamer)]), "en niets anders")
	_af()

## The start of the game and every new morning: no board over the room, the
## bell pulses until a guest is checked in.
func test_de_ochtend_is_de_bel_niet_het_bord() -> void:
	_op()
	State.s["ronde"] = "ochtend"
	Hotel.start()
	waar(not Hotel.bord_is_open(), "bij de start gaat het prikbord niet open")
	waar(Hits.spot("prikbord") != null, "het staat wel achter zijn knop")
	waar(_pulseert("bel"), "de bel vraagt om een tik")
	Hotel.morgen()
	gelijk(World.kamer_nu(), "receptie", "een nieuwe ochtend begint in de receptie")
	waar(not Hotel.bord_is_open(), "ook dan zonder prikbord")
	State.s["ronde"] = "vrij"
	Hotel.render()
	waar(not _pulseert("bel"), "na de ochtend staat de bel stil")
	_af()
