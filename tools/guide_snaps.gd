extends Node

## Opens a level in the real Puzzle and saves a screenshot of every page of its
## guide, to look over the guides without clicking through them. Not headless:
## headless draws nothing.
##   godot --path . --resolution 1920x1080 res://tools/guide_snaps.tscn -- res://level/levels/ar_1.tscn [more levels]
## Pages that wait for an action are shown as they first appear. Screenshots go
## to user://guide_<level>_<page>.png, and the path of each is printed.


func _ready() -> void:
	for path in OS.get_cmdline_user_args():
		await _snap_level(path)
	get_tree().quit()

func _snap_level(path: String) -> void:
	var level: Level = (load(path) as PackedScene).instantiate()
	Game.level_scene = null
	Game.level = level
	Game.level_id = &"guide_snaps"
	var puzzle: Puzzle = (load("res://puzzle/puzzle.tscn") as PackedScene).instantiate()
	puzzle.visible = true
	add_child(puzzle)
	puzzle.configure_level()
	for i in 20: await get_tree().process_frame
	var overlay := puzzle.find_children("*", "TutorialOverlay", true, false)
	var key := path.get_file().get_basename()
	if overlay.is_empty():
		await _snap("%s_noguide" % key)
	else:
		var guide := overlay[0] as TutorialOverlay
		for i in guide.pages.size():
			guide._go_to(i)
			for f in 12: await get_tree().process_frame
			await _snap("%s_%d" % [key, i + 1])
	puzzle.queue_free()
	for i in 3: await get_tree().process_frame

func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var file := "user://guide_%s.png" % label
	get_viewport().get_texture().get_image().save_png(file)
	print("SNAP ", ProjectSettings.globalize_path(file))
