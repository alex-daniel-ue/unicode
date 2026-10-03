extends Node

## Screenshots of the screens whose look changes without a level to play: the
## toolbox, the assistant's panel, a block with hinted slots on the canvas, the
## win card with a summary that has code in it, and level select. Not headless.
##   godot --path . --resolution 1920x1080 res://tools/ui_snaps.tscn
## Saved to user://ui_<name>.png; each path is printed.

const SUMMARY := "Nice use of a loop! In Python that is for leg in route: and it reads each stop with route[0], route[1] and so on."


func _ready() -> void:
	await _puzzle_shots()
	await _level_select_shot()
	get_tree().quit()

func _puzzle_shots() -> void:
	Game.level = (load("res://level/levels/ar_4.tscn") as PackedScene).instantiate()
	Game.level_scene = null
	Game.level_id = &"ar-4"
	var puzzle: Puzzle = (load("res://puzzle/puzzle.tscn") as PackedScene).instantiate()
	puzzle.visible = true
	add_child(puzzle)
	puzzle.configure_level()
	for i in 10: await get_tree().process_frame

	# A for block on the canvas, its slots empty, to show the hints and shimmer.
	var for_block := Block.construct(load("res://puzzle/blocks/control flow/for_int.tres"))
	puzzle.canvas.add_child(for_block)
	for_block.position = puzzle._get_begin().position + Vector2(0, 160)
	for i in 30: await get_tree().process_frame
	puzzle.side_panels[0].focus_content(puzzle.toolbox)
	for i in 30: await get_tree().process_frame
	await _snap("toolbox_and_slots")

	# The assistant with a short chat, so New chat is awake.
	var assistant := puzzle.ai_assistant
	puzzle.side_panels[0].focus_content(assistant)
	var asked := assistant.chat_bubble_scene.instantiate() as ChatBubble
	asked.text = "why does it stop early?"
	asked.right_aligned = true
	assistant._add_bubble(asked)
	assistant._add_ai_bubble("In Room 2 the robot stops 1 tile short of the second blue flag. How many times did your loop run there?")
	for i in 30: await get_tree().process_frame
	await _snap("assistant")

	# The win card, with code in the summary the way the model tends to write it.
	var card := puzzle.level_complete.present(3, 3, 3, 1, true)
	for i in 20: await get_tree().process_frame
	puzzle.level_complete.show_summary(SUMMARY, card)
	for i in 30: await get_tree().process_frame
	await _snap("level_complete")
	puzzle.queue_free()
	for i in 3: await get_tree().process_frame

func _level_select_shot() -> void:
	Game.level_id = &"ar-4"  # just played: level select should open on Arrays
	var select: Node = (load("res://menus/level select/level_select.tscn") as PackedScene).instantiate()
	add_child(select)
	for i in 40: await get_tree().process_frame
	await _snap("level_select")
	select.queue_free()

func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var file := "user://ui_%s.png" % label
	get_viewport().get_texture().get_image().save_png(file)
	print("SNAP ", ProjectSettings.globalize_path(file))
