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
	World.weg("k_boef")
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
