extends Node

## Screenshots of the screens whose look changes without a level to play: the
## toolbox, the assistant's panel, a block with hinted slots on the canvas, the
## win card with a summary that has code in it, a room mid-scan and a list's goal
## marks, level select, the main menu, and its quit popup. Not headless.
##   godot --path . --resolution 1920x1080 res://tools/ui_snaps.tscn
## Saved to user://ui_<name>.png; each path is printed. With `-- menu` after
## the path, only the main menu's shots; with `-- levels`, only level select's;
## with `-- win`, only the puzzle's, the win card among them.

const SUMMARY := "Nice use of a loop! In Python that is for steps in route: and it reads each stop with route[0], route[1] and so on."


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "levels" in args:
		await _level_select_shot()
	elif "win" in args:
		await _puzzle_shots()
	else:
		if not "menu" in args:
			await _puzzle_shots()
			await _room_shots()
			await _level_select_shot()
		await _quit_shot()
	get_tree().quit()

## The robot's Ahead Is scan halfway across the tile in front of it (it-2), with
## the speed button blue as in a fast run and the Information tab's Go to
## Toolbox, and a list that starts empty, with the green numbers it should end
## up with (ar-8).
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
		var speed := puzzle.get_node(^"UserInterface/SideMenuRight/ButtonContainer/SpeedButton") as Button
		if pair[0] == "it_2":
			var robot := get_tree().get_first_node_in_group(&"robot") as Robot
			robot._scan(false)
			# The speed button as it looks while a run goes fast: blue.
			Interpreter.is_fast = true
			speed.disabled = false
			speed.call(&"_update_look")
			for i in 14: await get_tree().process_frame
		await _snap("room_" + pair[0])
		Interpreter.is_fast = false
		speed.call(&"_update_look")
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

	# The assistant with a short chat, so New chat is awake, and three questions
	# spent, so the limit bar shows used pips and its countdown.
	var assistant := puzzle.ai_assistant
	puzzle.side_panels[0].focus_content(assistant)
	for i in 3:
		HintPool.take()
	assistant._refresh_busy_state()
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
	# A tile under the pointer, then one held down: their bands change, and
	# their numbers and stars stay where they were. Let go off the tile, so it
	# doesn't open its level.
	var tiles := (select.get(&"grid") as Container).get_children()
	if tiles.size() >= 2:
		_pointer((tiles[0] as Control).get_global_rect().get_center())
		for i in 20: await get_tree().process_frame
		await _snap("level_select_hover")
		_pointer((tiles[1] as Control).get_global_rect().get_center(), true)
		for i in 20: await get_tree().process_frame
		await _snap("level_select_pressed")
		_pointer(Vector2(2, 2), false)
		for i in 5: await get_tree().process_frame
	# Tutorial, the first module: fewer levels than a row holds, so its row
	# should sit centred.
	while not (select.get(&"prev_button") as Button).disabled:
		select.call(&"_on_prev_pressed")
	for i in 40: await get_tree().process_frame
	await _snap("level_select_first")
	select.queue_free()

## The pointer moved to `at`, by events rather than the real cursor, with its
## left button then pressed (true) or let go (false) there if `press` says.
func _pointer(at: Vector2, press: Variant = null) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	if press != null:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = press
		click.position = at
		click.global_position = at
		Input.parse_input_event(click)

func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var file := "user://ui_%s.png" % label
	get_viewport().get_texture().get_image().save_png(file)
	print("SNAP ", ProjectSettings.globalize_path(file))
