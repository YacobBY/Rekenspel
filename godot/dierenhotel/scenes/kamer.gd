extends Node2D
## The room in view, inside the world SubViewport.
##
## Layers, in drawing order (world.md §0 painter's algorithm):
##   Vloer      one mesh: floor tiles in 4x4 blocks + both back walls
##   Ver        wall decor (`ver: 1`) — never sorted, always behind
##   Objecten   y_sort_enabled -> depth = x + z, for free
##   Voor       overlays: the 💤 over a sleeper, particles
##
## Every thing in `Objecten` is a `WereldObject` standing on its own floor
## point, so Godot's y-sorting IS the painter's algorithm and nothing has to be
## sorted by hand.  The depth tweaks of world.md §0 are a bias on that node:
## +0.3 for decor with a height, +0.5 for a sleeping animal, +0.2 for a loose
## "ding", and the back half of a feeding bowl sits far enough back that the
## guest eating from it is drawn in between.

const Proefwereld := preload("res://wereld/proefwereld.gd")
const KOM_ACHTER := -16.0      ## depth bias: the bowl's back half
const KOM_VOOR := 0.2

@onready var vloer: Node2D = $Vloer
@onready var ver: Node2D = $Ver
@onready var objecten: Node2D = $Objecten
@onready var voor: Node2D = $Voor

var _kamer := ""
var _los_versie := -1
var _meubel_versie := 0
var _decor: Array[WereldObject] = []
var _los: Dictionary = {}          ## id -> WereldObject, a game's loose decor
var _dieren: Dictionary = {}       ## gast id -> Dierbeeld
var _bed_nodes: Dictionary = {}    ## slot-id -> WereldObject van een bed hier
var _bedden_verborgen := false     ## de kamer leeg voor de vraag (zie verberg_bedden)
var _dingen: Dictionary = {}       ## ding id -> WereldObject
var _ingang: WereldObject = null   ## the front door, drawn open while a guest comes in
var _proefwereld = null            ## only with --demo / ?demo=1

func _ready() -> void:
	World.registreer_viewport(get_parent() as SubViewport, self)
	World.kader_veranderd.connect(_op_kader)
	World.kamer_veranderd.connect(_op_kamer)
	World.getekend.connect(_ververs)
	Rooms.kamers_veranderd.connect(_op_meubels)
	bouw(World.kamer_nu())
	if Proefwereld.aan():
		_proef()

## The vertical slice of §14.4, only with `?demo=1` / `--demo` (see the file).
func _proef() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_proefwereld = Proefwereld.new()
	_proefwereld.start()

func _op_kamer(kamer_id: String) -> void:
	bouw(kamer_id)

func _op_meubels() -> void:
	_meubel_versie += 1
	if vloer != null and vloer.has_method("herbouw"):
		vloer.herbouw()
	bouw(_kamer)

## (Re)build the room.  An unknown id keeps the room that is in view — the
## world decides which room that is, never the caller.
func bouw(kamer_id: String) -> void:
	if not Rooms.bestaat(kamer_id):
		kamer_id = World.kamer_nu()
	var r := Rooms.get_kamer(kamer_id)
	if r == null:
		return
	_kamer = kamer_id
	for laag in [objecten, ver]:
		for k in laag.get_children():
			laag.remove_child(k)
			k.queue_free()
	_decor.clear()
	_ingang = null
	_los.clear()
	_dieren.clear()
	_bed_nodes.clear()
	if Ui.naamlaag != null:
		Ui.naamplaten_leeg()      # plates of guests in another room are hidden
	_dingen.clear()
	_los_versie = -1
	for stuk in r.decor:
		var o := WereldObject.maak(String(stuk["n"]))
		var hoog: float = float(stuk.get("y", 0.0))
		if stuk.get("ver", false):
			ver.add_child(o)
		else:
			# `d` = an explicit depth bias for a thing that stands on a bigger
			# thing whose centre lies deeper (the bell on the left end of the
			# desk sorted behind the desk and was hidden, owner 2026-09-14)
			o.diepte_bias = float(stuk.get("d", 0.3 if hoog > 0.0 else 0.0))
			objecten.add_child(o)
		o.zet_model(stuk["n"], stuk.get("params", {}), Vector2.ZERO, int(stuk.get("rot", 0)))
		o.plaats(stuk["x"], stuk["z"], hoog)
		_decor.append(o)
		if stuk.get("ingang", false):
			_ingang = o
	for sid in r.slots:
		_bouw_slot(r, sid)
	_zet_bedden(not _bedden_verborgen)
	_ververs_dingen()
	_ververs_dieren()
	_ververs_los()
	if vloer != null and vloer.has_method("herbouw"):
		vloer.herbouw()
	queue_redraw()

## A bed is one object; a bowl is two, so a guest can sit IN it while eating.
##
## The KIND decides, not the model name: a bought `bakje` has no model of its
## own (world.md §1.8) and must still draw a bowl, exactly as world.js keys it
## on `soort`.
func _bouw_slot(r: Rooms.Kamer, sid: String) -> void:
	var slot: Dictionary = r.slots[sid]
	var model: String = slot.get("model", "")
	if slot["soort"] == "bak":
		var kamer_id := r.id
		for deel in [false, true]:
			var o := WereldObject.maak("%s_%s" % [sid, "voor" if deel else "achter"])
			# The bowl is two plates: the front wall is drawn AFTER the guest, so
			# he sits IN the bowl while he eats (art-sound-rules.md §7).
			o.diepte_bias = KOM_VOOR if deel else KOM_ACHTER
			objecten.add_child(o)
			o.zet_bron(func() -> String:
					return "kom|%d|%d" % [World.bak_stand(kamer_id, sid), 1 if deel else 0],
				func(g: int): return Art.kom(World.bak_stand(kamer_id, sid), g, deel),
				Art.KOM_ANKER)
			o.plaats(slot["x"], slot["z"], 0.0)
			_decor.append(o)
		return
	if model.is_empty() or not Art.heeft_model(model):
		return
	var b := WereldObject.maak(sid)
	objecten.add_child(b)
	b.zet_model(model, {})
	b.plaats(slot["x"], slot["z"], 0.0)
	_decor.append(b)
	if String(slot.get("soort", "")) == "bed":
		_bed_nodes[sid] = b

## Zet álle bedden van deze kamer in het zicht of weg (zie `verberg_bedden`),
## en houd elk los verborgen vrij bed weg (`World.verberg_bed`, bedden).
func _zet_bedden(zichtbaar: bool) -> void:
	for sid in _bed_nodes:
		var nd = _bed_nodes[sid]
		if is_instance_valid(nd):
			nd.visible = zichtbaar and not World.bed_verborgen(_kamer, String(sid))

## Eigenaarsduw (2026-09-21): op het moment dat de gast aankomt en de kaart
## vraagt hoeveel bedden er nodig zijn, moet de kamer leeg zijn. Zolang dit
## aanstaat verdwijnen de bedden die hier al staan én de gasten die erin
## slapen; de rest van de kamer blijft zoals het is. Zo telt het kind niet,
## maar rekent. Alleen `bedden` roept dit aan.
func verberg_bedden(aan: bool) -> void:
	_bedden_verborgen = aan
	_zet_bedden(not aan)
	_ververs_dieren()

## De gasten die in een bed van deze kamer slapen, maar alleen zolang de
## bedden verborgen zijn. Leeg als er niets te verbergen is.
func _slapende_gasten() -> Dictionary:
	var ids := {}
	if not _bedden_verborgen:
		return ids
	for sid in _bed_nodes:
		var g: Dictionary = State.gast_in_bed(_kamer, sid)
		if not g.is_empty():
			ids[String(g.get("id", ""))] = true
	return ids

func gast_vlak(id: String = "") -> Rect2:
	if id != "" and _dieren.has(id):
		return _dieren[id].vlak()
	for d in _dieren.values():
		return d.vlak()
	return Rect2()

func dier_beeld(id: String) -> Node2D:
	return _dieren.get(id)

func _op_kader(_rect: Rect2, _schaal: Dictionary) -> void:
	for o in _decor:
		o.ververs()
	for o in _los.values():
		o.ververs()
	for o in _dingen.values():
		o.ververs()
	if vloer != null and vloer.has_method("herbouw"):
		vloer.herbouw()
	queue_redraw()

## One guest, one node.  Guests in other rooms have no node at all — that is
## the off-screen rule of world.md §2.9 on the drawing side.  The name plate
## hangs over the world in `Ui`, which owns the widget; the world owns the
## point it hangs on (world.md §2.10).
func _ververs_dieren() -> void:
	var gezien := {}
	var slaap := _slapende_gasten()
	for d in World.dieren(_kamer):
		gezien[d.id] = true
		var beeld: Dierbeeld = _dieren.get(d.id)
		if beeld == null:
			beeld = Dierbeeld.maak_dier(d.id)
			objecten.add_child(beeld)
			_dieren[d.id] = beeld
		beeld.volg()
		if slaap.has(d.id):
			# het bed is weg, dus de slaper die erin ligt ook
			beeld.visible = false
			if Ui.naamlaag != null:
				Ui.naamplaat_weg(d.id)
			continue
		beeld.visible = true
		if Ui.naamlaag != null and d.naam != "":
			Ui.naamplaat(d.id, d.naam)
	for id in _dieren.keys():
		if not gezien.has(id):
			_dieren[id].queue_free()
			_dieren.erase(id)
			if Ui.naamlaag != null:
				Ui.naamplaat_weg(id)

## The two movable things (the desk lamp, the food trolley) — world.md §1.3.
func _ververs_dingen() -> void:
	var gezien := {}
	for stuk in World.dingen(_kamer):
		var id: String = stuk["id"]
		gezien[id] = true
		var o: WereldObject = _dingen.get(id)
		if o == null:
			o = WereldObject.maak("ding_" + id)
			o.diepte_bias = 0.2
			objecten.add_child(o)
			_dingen[id] = o
		o.zet_model(stuk["model"], {})
		o.plaats(stuk["x"], stuk["z"], stuk["hoog"])
	for id in _dingen.keys():
		if not gezien.has(id):
			_dingen[id].queue_free()
			_dingen.erase(id)

## Loose decor of the running game (World.decor); the version counter is the
## redraw-on-change rule for them.
func _ververs_los() -> void:
	if World.decor_versie() == _los_versie:
		for o in _los.values():
			o.ververs()
		return
	_los_versie = World.decor_versie()
	var gezien := {}
	for stuk in World.decor_lijst(_kamer):
		var id: String = stuk["id"]
		gezien[id] = true
		var o: WereldObject = _los.get(id)
		if o == null:
			o = WereldObject.maak("los_" + id)
			if stuk["ver"]:
				ver.add_child(o)
			else:
				objecten.add_child(o)
			_los[id] = o
		o.diepte_bias = 0.3 if stuk["hoog"] > 0.0 else 0.0
		o.zet_model(stuk["model"], stuk["params"], Vector2.ZERO, int(stuk["rot"]))
		o.plaats(stuk["x"], stuk["z"], stuk["hoog"])
	for id in _los.keys():
		if not gezien.has(id):
			_los[id].queue_free()
			_los.erase(id)

func _ververs() -> void:
	if _kamer != World.kamer_nu():
		bouw(World.kamer_nu())
		return
	var sch := World.schaal()
	modulate.a = World.reis_alfa()
	if vloer != null:
		# the mesh is in voxel-px, so the camera is the node's own transform and
		# panning costs nothing; only the vignette, which is screen-anchored,
		# has to be re-emitted when the camera moves
		vloer.position = World.cam()
		vloer.scale = Vector2(sch["g"], sch["g"])
		vloer.queue_redraw()
	_ververs_dieren()
	_ververs_dingen()
	_ververs_los()
	# a bed the beds game hides or gives back (`World.verberg_bed`)
	_zet_bedden(not _bedden_verborgen)
	# the front door stands open while a guest comes in (World.kom_binnen);
	# its plate follows its params, like every model's
	if _ingang != null:
		_ingang.params = {"open": 1} if World.ingang_open(_kamer) else {}
	for o in _decor:
		o.ververs()
	voor.queue_redraw()

func _draw() -> void:
	pass
