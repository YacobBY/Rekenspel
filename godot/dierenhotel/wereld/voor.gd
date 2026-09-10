extends Node2D
## The `Voor` layer of the room scene: everything that is drawn *after* the
## sorted objects — the 💤 over a sleeping guest and the particles.
##
## Not one number lives here.  The sleep mark and the particles are `ArtEffect`
## (W4): the rectangles of the three block Z's, their colour and their alpha,
## and the size and the fade of a particle.  This file only puts them on the
## screen, so nothing can drift away from the art spec.

func _draw() -> void:
	var g: int = World.schaal()["g"]
	var kamer := World.kamer_nu()
	for d in World.dieren(kamer):
		if d.staat == "slaap":
			_slaapt(d, g)
	for p in World.deeltjes():
		if p["kamer"] != kamer:
			continue
		var m := ArtEffect.pluis_maat(p, g)
		var kl: Color = p["c"]
		kl.a = ArtEffect.pluis_alfa(p)
		var punt := World.cam() + Vector2(p["x"], p["y"]) * g
		draw_rect(Rect2(punt, Vector2(m, m)), kl)

## The rectangles come back relative to the guest's floor point; world.js adds
## `(bob + lift) * g` to the y itself, and so does this.
func _slaapt(d, g: int) -> void:
	var basis := World.scherm(d.x, d.z, 0.0)
	basis.y += (d.bob + d.lift) * g
	var kl := ArtEffect.ZZZ_KL
	kl.a = ArtEffect.ZZZ_ALFA
	for r in ArtEffect.zzz_rechthoeken(g, d.face):
		draw_rect(Rect2(basis + Vector2(r.position), Vector2(r.size)), kl)
