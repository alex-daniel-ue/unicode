extends Node

## Screenshots of the screens whose look changes without a level to play: the
## toolbox, the assistant's panel, a block with hinted slots on the canvas, the
## win card with a summary that has code in it, a room mid-scan and a list's goal
## marks, level select, the main menu, and its quit popup. Not headless.
##   godot --path . --resolution 1920x1080 res://tools/ui_snaps.tscn
## Saved to user://ui_<name>.png; each path is printed. With `-- menu` after
## the path, only the main menu's shots.

const SUMMARY := "Nice use of a loop! In Python that is for steps in route: and it reads each stop with route[0], route[1] and so on."


func _ready() -> void:
	if not "menu" in OS.get_cmdline_user_args():
		await _puzzle_shots()
		await _room_shots()
		await _level_select_shot()
	await _quit_shot()
	get_tree().quit()

## The robot's Ahead Is scan halfway across the tile in front of it (it-2), and
## a list that starts empty, with the green numbers it should end up with (ar-8).
func _room_shots() -> void:
	for pair in [["it_2", &"it-2"], ["ar_8", &"ar-8"]]:
		Game.level = (load("res://level/levels/%s.tscn" % pair[0]) as PackedScene).instantiate()
		Game.level_scene = null
		Game.level_id = pair[1]
		var puzzle: Puzzle = (load("res://puzzle/puzzle.tscn") as PackedScene).instantiate()
		puzzle.visible = true
		add_child(puzzle)
		puzzle.configure_level()
		for i in 20: await get_tree().process_frame
		for guide in puzzle.find_children("*", "TutorialOverlay", true, false):
			(guide as TutorialOverlay).skip()
		for i in 20: await get_tree().process_frame
		if pair[0] == "it_2":
			var robot := get_tree().get_first_node_in_group(&"robot") as Robot
			robot._scan(false)
			for i in 14: await get_tree().process_frame
		await _snap("room_" + pair[0])
		puzzle.queue_free()
		for i in 3: await get_tree().process_frame

## The main menu's quit popup, with the progress code in it.
func _quit_shot() -> void:
	var menu: Control = (load("res://menus/main/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	# The menu as it opens, with the demo a few steps in.
	for i in 150: await get_tree().process_frame
	await _snap("main_menu")
	# Each of the other demos, a few steps in. The card's rect is printed, to
	# check it's centred in the space right of the logo and buttons.
	var demo := menu.get_node(^"Demo") as MenuDemo
	print("DEMO 0 ", demo.get_global_rect(), " free from ", demo._left_limit() - MenuDemo.GAP, " to ", demo.get_viewport_rect().size)
	for i in range(1, MenuDemo.DEMOS.size()):
		demo._show(i)
		for f in 150: await get_tree().process_frame
		await _snap("main_menu_demo_%d" % i)
		print("DEMO %d " % i, demo.get_global_rect())
	menu.call(&"_on_quit_pressed")
	for i in 60: await get_tree().process_frame  # past the pop-in and the flashes
	await _snap("quit")
	menu.queue_free()

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
	# A loose block let go right on top of Begin, where it can't attach: it
	# should have drifted clear by the time of the shot (PuzzleCanvas._separate).
	var loose := Block.construct(load("res://level/objects/entities/robot/blocks/move.tres"))
	puzzle.canvas.add_child(loose)
	loose.position = puzzle._get_begin().position + Vector2(12, 6)
	for i in 30: await get_tree().process_frame
	puzzle.side_panels[0].focus_content(puzzle.toolbox)
	# One block's note open, through its eye, as a student would.
	var tiles := puzzle.toolbox.find_children("*", "ToolboxTile", true, false)
	if not tiles.is_empty():
		(tiles[0] as ToolboxTile).eye.button_pressed = true
	for i in 30: await get_tree().process_frame
	await _snap("toolbox_and_slots")

	# The assistant with a short chat, so New chat is awake.
	var assistant := puzzle.ai_assistant
	puzzle.side_panels[0].focus_content(assistant)
	var asked := assistant.chat_bubble_scene.instantiate() as ChatBubble
	asked.text = "why does it stop early?"
	asked.right_aligned = true
	assistant._add_bubble(asked)
	assistant._add_ai_bubble("In Room 2 the robot stops 1 tile short of the second battery. How many times did your loop run there?")
	for i in 30: await get_tree().process_frame
	await _snap("assistant")

	# The win card, with code in the summary the way the model tends to write it.
	# One star of three, so the empty ones show.
	var card := puzzle.level_complete.present(1, 6, 3, 1, true)
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
