extends SceneTree
## tools/bak_dieren.gd — a contact sheet of the guests, for looking at them.
##
## Bakes every species in a row of poses (and optionally an outfit) at one
## voxel size and writes ONE png, so a change to `art/gasten.gd` can be judged
## by eye without a web export:
##
##   godot --headless --path godot/dierenhotel --script res://tools/bak_dieren.gd \
##     -- --uit ../../tmp/dieren.png --g 4 --poses rust,loopA,loopM,sip \
##        --acc pet,sjaaltje
##
## `--outfits "pet,sjaaltje;kroon,parels"` makes every COLUMN an outfit instead
## (in the pose of `--poses`' first entry), to see the wardrobe side by side.
##
## Rows are species (hond, poes, konijn, gans), columns are poses.  Not a test:
## nothing is compared, the picture is for a human.

const SOORTEN := ["hond", "poes", "konijn", "gans"]

func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var uit := "user://dieren.png"
	var g := 4
	var poses: Array = ["rust", "loopA", "loopB", "blijA", "sip", "zit", "lig", "hap2"]
	var acc := ""
	var outfits: Array = []
	var i := 0
	while i < args.size():
		var a: String = args[i]
		var waarde: String = args[i + 1] if i + 1 < args.size() else ""
		match a:
			"--uit": uit = waarde; i += 1
			"--g": g = int(waarde); i += 1
			"--poses": poses = Array(waarde.split(",")); i += 1
			"--acc": acc = waarde; i += 1
			"--outfits": outfits = Array(waarde.split(";")); i += 1
		i += 1
	var art = root.get_node("Art")
	var platen: Array = []
	var cel := Vector2i(0, 0)
	var kolommen: Array = []
	for pose in poses:
		kolommen.append([str(pose), acc])
	if not outfits.is_empty():
		kolommen = []
		for o in outfits:
			kolommen.append([str(poses[0]), str(o)])
	poses = kolommen
	for kind in SOORTEN:
		var rij: Array = []
		for kol in kolommen:
			var p = art.dier(kind, str(kol[0]), g, str(kol[1]))
			rij.append(p)
			if p != null:
				cel.x = maxi(cel.x, p.w)
				cel.y = maxi(cel.y, p.h)
		platen.append(rij)
	cel += Vector2i(8, 8)
	var img := Image.create_empty(cel.x * poses.size(), cel.y * SOORTEN.size(), false,
		Image.FORMAT_RGBA8)
	img.fill(Color("#FFF7EC"))
	for r in platen.size():
		for c in (platen[r] as Array).size():
			var p = platen[r][c]
			if p == null:
				continue
			var beeld: Image = p.tex.get_image()
			beeld.convert(Image.FORMAT_RGBA8)
			var dst := Vector2i(c * cel.x + (cel.x - p.w) / 2, r * cel.y + cel.y - p.h - 4)
			img.blend_rect(beeld, Rect2i(0, 0, p.w, p.h), dst)
	var pad := uit if uit.begins_with("user://") or uit.begins_with("/") \
		else ProjectSettings.globalize_path("res://").path_join(uit)
	img.save_png(pad)
	print("dieren: ", pad, " ", img.get_width(), "x", img.get_height())
	quit(0)
