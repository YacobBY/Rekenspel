extends Node
## The shell.  Boots the autoloads into a running world and keeps one unit
## equal to one CSS pixel at every window size and device pixel ratio.
##
## W3 replaces the placeholder chrome below with the real HUD, room bar, sheets
## and start screen of world.md §6.

const GAST := "gast1"

@onready var wereld_vp: SubViewport = $Wereld
@onready var kamer: Node2D = $Wereld/Kamer
@onready var kader: Control = $Scherm/Kolom/Kader
@onready var beeld: TextureRect = $Scherm/Kolom/Kader/Beeld
@onready var knoplaag: Control = $Scherm/Kolom/Kader/Knoplaag
@onready var naamlaag: Control = $Scherm/Kolom/Kader/Naamlaag
@onready var toastlaag: Control = $Toastlaag
@onready var speel_knop: Button = $Scherm/Kolom/Chroom/Speel
@onready var dag_label: Label = $Scherm/Kolom/Chroom/Dag

var _bezig_met_meten := false
var _gemeld := false
var _tikken := 0

func _ready() -> void:
	Ui.registreer_lagen(knoplaag, naamlaag, toastlaag)
	beeld.texture = wereld_vp.get_texture()
	get_window().size_changed.connect(_op_venster)
	kader.resized.connect(_op_kader)
	speel_knop.pressed.connect(_speel)
	_op_venster()
	World.naar("proefkamer")
	State.lees()
	State.start_gekozen()
	var d := World.zet(GAST, "proefkamer", 20, 14)
	d.model = "proef_dier"
	d.params = {"kleur": Color("#EEC194"), "donker": Color("#D3996A")}
	kamer.bouw("proefkamer")
	var volg_gast := func() -> Dictionary:
		var dd := World.dier(GAST)
		if dd == null:
			return {}
		return {"x": dd.x, "z": dd.z, "y": 12.0, "kamer": dd.kamer, "vlak": kamer.gast_vlak()}
	var tik_gast := func(_s) -> void:
		_loop()
	Hits.maak({
		"id": "gast_knop", "kamer": "proefkamer", "x": d.x, "z": d.z, "y": 12.0,
		"icoon": "", "label": "Loop", "titel": "laat de gast lopen", "prio": 6,
		"door": "hotel", "volg": volg_gast, "aan": tik_gast,
	})
	Ui.toast("Dierenhotel — skelet")
	_meld_later()

## One unit = one CSS pixel, at any device pixel ratio (architecture.md §4.1).
func _op_venster() -> void:
	if _bezig_met_meten:
		return
	_bezig_met_meten = true
	var win := get_window()
	var dpr := maxf(1.0, DisplayServer.screen_get_scale())
	var css := Vector2i(
		maxi(320, JsGetal.rond(win.size.x / dpr)),
		maxi(240, JsGetal.rond(win.size.y / dpr)))
	if win.content_scale_size != css:
		win.content_scale_size = css
	_bezig_met_meten = false
	call_deferred("_op_kader")

func _op_kader() -> void:
	if kader == null:
		return
	World.meet(Rect2(Vector2.ZERO, kader.size))

func _loop() -> void:
	_tikken += 1
	print("[probe] tik=", _tikken)
	var r := Rooms.get_kamer("proefkamer")
	var d := World.dier(GAST)
	if r == null or d == null:
		return
	Snd.ontgrendel()
	var beste: Array = r.plekken[0]
	var ver := -1.0
	for p in r.plekken:
		var afst: float = abs(p[0] - d.x) + abs(p[1] - d.z)
		if afst > ver:
			ver = afst
			beste = p
	var gehaald: bool = await World.stappen(GAST, [Vector2(beste[0], beste[1])])
	if gehaald:
		Snd.ja()
		Ui.toast("De gast is er.")
		print("[probe] gelopen naar=", Vector2(beste[0], beste[1]), " tikken=", _tikken)

func _speel() -> void:
	Snd.ontgrendel()
	if Games.actief() == "_voorbeeld":
		Games.stop()
	else:
		Games.start("_voorbeeld")

func _process(_delta: float) -> void:
	dag_label.text = "Dag %d  ster %d" % [State.s["dag"], State.s["sterren"]]

## One machine-readable line per fact, for the browser probe and the tests.
func _meld_later() -> void:
	await get_tree().create_timer(1.0).timeout
	if _gemeld:
		return
	_gemeld = true
	var win := get_window()
	var sch := World.schaal()
	print("[probe] versie=", Engine.get_version_info()["string"])
	print("[probe] venster=", win.size, " css=", win.content_scale_size,
		" dpr=", DisplayServer.screen_get_scale())
	print("[probe] kader=", kader.size, " viewport=", wereld_vp.size,
		" g=", sch["g"], " dicht=", "%.3f" % sch["dicht"], " k=", "%.3f" % sch["k"])
	print("[probe] spellen=", Games.lijst())
	print("[probe] platen=", Art.gebakken())
	var dbg: Dictionary = Hits.debug().get("gast_knop", {})
	print("[probe] dekking_gast_knop=", "%.2f" % Hits.dekking("gast_knop"))
	print("[probe] knop_rect=", dbg.get("rect", Rect2()), " gast_vlak=", dbg.get("vlak", Rect2()))
	var knop := Hits.spot("gast_knop")
	if knop != null and is_instance_valid(knop.knoop):
		print("[probe] knop_paginavlak=", knop.knoop.get_global_rect())
	print("[probe] speel_knop=", speel_knop.get_global_rect())
	print("[probe] klaar")
