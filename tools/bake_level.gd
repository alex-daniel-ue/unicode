extends Node
## Measures a level the way the editor's bake buttons do, without opening the
## editor: the whole-level camera bounds and every room's bounds, printed as
## JSON. For levels generated outside the editor (the Arrays sample). A scene
## rather than a --script, because --script runs without the autoloads.
##   godot --headless --path . res://tools/bake_level.tscn -- res://level/levels/ar_sample.tscn
## Given several levels, it measures each in turn and prints BOUNDS_FOR, the
## level's path, then its JSON, one line per level (tools/modules/finish_modules.py).


func _ready() -> void:
	var paths := OS.get_cmdline_user_args()
	if paths.size() == 1:
		print("BOUNDS " + JSON.stringify(await _measure(paths[0])))
	else:
		for path in paths:
			print("BOUNDS_FOR %s %s" % [path, JSON.stringify(await _measure(path))])
	get_tree().quit()


func _measure(path: String) -> Dictionary:
	var level: Level = (load(path) as PackedScene).instantiate()
	Game.level = level
	var out := {}
	# The editor measures a level from the camera's _ready(), which comes before
	# the rest of the level is laid out. Measuring at that same moment shows
	# whether the early measurement agrees with the settled one below.
	var camera := level.get_node(^"Camera2D")
	camera.ready.connect(func() -> void:
		var early := LevelCamera.node_bounds(level)
		out["level_at_camera_ready"] = [early.position.x, early.position.y, early.size.x, early.size.y])
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var whole := LevelCamera.node_bounds(level)
	out["level"] = [whole.position.x, whole.position.y, whole.size.x, whole.size.y]
	for manager in level.room_goals:
		manager.bake_bounds()
		var b: Rect2 = manager.bounds
		out[String(manager.name)] = [b.position.x, b.position.y, b.size.x, b.size.y]
	level.queue_free()
	await get_tree().process_frame
	Game.level = null
	return out
