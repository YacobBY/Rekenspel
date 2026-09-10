class_name Dierbeeld
extends WereldObject
## One guest in the room in view.
##
## It is a `WereldObject` with two extras that only an animal has: the soft
## ground shadow under it (drawn by the node itself, so it always lies *under*
## the sprite), and the translucent water band over its lower half when it is
## swimming.  The pool water is baked into the floor, so a swimmer would
## otherwise float on top of it (art-sound-rules.md §11.5).
##
## The position glides between two think ticks (`World.glij()`), so the world
## thinks at 15 Hz and still draws smoothly.

var gast_id := ""
var _nat := false
var _schaduw := true
var _staat := ""

static func maak_dier(id: String) -> Dierbeeld:
	var o := Dierbeeld.new()
	o.name = "dier_" + id
	o.gast_id = id
	o.anker = Art.DIER_ANKER
	var s := Sprite2D.new()
	s.name = "Beeld"
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	o.add_child(s)
	return o

## Take over everything that changed about the guest this frame.
func volg() -> void:
	var d := World.dier(gast_id)
	if d == null:
		return
	var f := World.glij()
	face = d.face
	diepte_bias = 0.5 if d.staat == "slaap" else 0.0
	model = World.gast_model(d.kind)
	params = d.params
	_schaduw = d.staat != "slaap"
	_staat = d.staat
	var nat := _in_water(d)
	if nat != _nat:
		_nat = nat
		_sleutel = ""          # the plain plate and the wet one are two textures
	var x := lerpf(d.px, d.x, f)
	var z := lerpf(d.pz, d.z, f)
	plaats(x + d.zij * 0.25, z - d.zij * 0.25, d.hoogte - d.bob / float(Art.HG))
	_water(d)
	queue_redraw()

## The pool water is baked into the floor and therefore lies UNDER the guest,
## so a swimmer needs a translucent band over his lower half.  `Art` bakes it
## into the plate, cut by the ellipse of the surface seen from above, and
## caches it per waterline — a swimmer does not bob, so that is one extra plate
## per pose (art-sound-rules.md §11.5).
func _water(d) -> void:
	if beeld == null or beeld.texture == null or not _nat:
		return
	var g: int = World.schaal()["g"]
	var top := int(round(-beeld.position.y))
	if top <= 0 or top >= beeld.texture.get_height():
		return
	var p = Art.water_plaat(d.kind, d.pose, g, top, d.acc)
	if p != null:
		beeld.texture = p.tex

## A guest standing in swim pose on the deck stays dry.
func _in_water(d) -> bool:
	if d.hoogte >= 0.0 or (d.staat != "zwem" and d.beweeg_pose != "zwem"):
		return false
	var r := Rooms.get_kamer(d.kamer)
	if r == null or r.bad.is_empty():
		return true
	var b: Dictionary = r.bad
	return d.x >= b["x0"] and d.x <= b["x1"] and d.z >= b["z0"] and d.z <= b["z1"]

## The ground shadow: an ellipse at the floor point, with the radii `ArtEffect`
## gives for this state — a sitting or sad guest sits lower, a sleeping guest
## gets no shadow at all.
func _draw() -> void:
	if not _schaduw:
		return
	var g: int = World.schaal()["g"]
	var straal := ArtEffect.grondschaduw(g, _staat)
	var kl := ArtEffect.SCHADUW_KL
	kl.a = ArtEffect.SCHADUW_ALFA
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, straal.y / maxf(1.0, straal.x)))
	draw_circle(Vector2.ZERO, straal.x, kl)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
