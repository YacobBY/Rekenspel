extends SceneTree
## Wegwerp: schrijft drie savegames (band 3, 4 en 5) naar
## `.fanout/scratch/godot-g-voerkar/opslag/`, zodat de browserproef met een
## hotel vol gasten kan beginnen in plaats van eerst vier keer in te checken.

func _initialize() -> void:
	await process_frame
	var hulp = load("res://games/voerkar/_zaadhulp.gd").new()
	hulp.doe()
	quit(0)
