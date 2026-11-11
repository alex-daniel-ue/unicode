extends Node
## Screenshots of the screens whose look changes without a level to play: the
## toolbox, the assistant's panel, a block with hinted slots on the canvas, the
## win card with a summary that has code in it, a room mid-scan and a list's goal
## marks, level select, the main menu, and its quit popup. Not headless.
##   godot --path . --resolution 1920x1080 res://tools/ui_snaps.tscn
## Saved to user://ui_<name>.png; each path is printed. With `-- menu` after
## the path, only the main menu's shots; with `-- levels`, only level select's;
## with `-- win`, only the puzzle's, the win card among them; with `-- rooms`,
## only the rooms' (the Information tab among them); with `-- tips`, the puzzle
## screen's hints: a long notification, the assistant peeking out with a
## suggestion, and the pointer beside the running line; with `-- reset`, a room
## as a run left it and then after its Reset button; with `-- trash`, a block
## dragged out of a slot and let go over the toolbox; with `-- pan`, presses on
## the canvas, in blocks' boxes and on blocks, and whether each pans the canvas
## or picks a block up.

const SUMMARY := "Nice use of a loop! In Python that is for steps in route: and it reads each stop with route[0], route[1] and so on."


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "levels" in args:
		await _level_select_shot()
	elif "win" in args:
		await _puzzle_shots()
	elif "rooms" in args:
		await _room_shots()
	elif "tips" in args:
		await _tips_shots()
	elif "reset" in args:
		await _reset_shots()
	elif "trash" in args:
		await _trash_shots()
	elif "pan" in args:
		await _pan_checks()
	else:
		if not "menu" in args:
			await _puzzle_shots()
			await _room_shots()
			await _level_select_shot()
		await _quit_shot()
	get_tree().quit()

## A notification too long for one line, wrapped; the assistant peeking out of
## its button, saying what it can do; then a for block left counting by nothing
## (so by 1) runs a step forward three times, with the pointer beside the line
## that's lit (ar-4).
func _tips_shots() -> void:
	Game.level = (load("res://level/levels/ar_4.tscn") as PackedScene).instantiate()
	Game.level_scene = null
	Game.level_id = &"ar-4"
	var puzzle: Puzzle = (load("res://puzzle/puzzle.tscn") as PackedScene).instantiate()
	puzzle.visible = true
	add_child(puzzle)
	puzzle.configure_level()
	for i in 20: await get_tree().process_frame
	for guide in puzzle.find_children("*", "TutorialOverlay", true, false):
		(guide as TutorialOverlay).skip()
	var begin := puzzle._find_begin()
	var counting := (load("res://puzzle/blocks/control flow/for_int.tres") as BlockData).deep_copy()
	for pair in [[0, "i"], [1, "0"], [2, "3"], [3, ""]]:
		counting.text_blocks[pair[0]].text = pair[1]
	var loop := Block.construct(counting) as NestedBlock
	loop.mouth.add_child(Block.construct(load("res://level/objects/entities/robot/blocks/move.tres")))
	begin.mouth.add_child(loop)
	puzzle.notifications.push("A message as long as a run's errors can be is too wide for one line, so it wraps onto the next one instead of running off the screen.", Notification.Type.ERROR)
	puzzle._suggest_assistant()
	for i in 40: await get_tree().process_frame
	await _snap("tips")
	puzzle.run_program()
	await get_tree().create_timer(5.5).timeout
	await _snap("running")
	puzzle.queue_free()
	for i in 3: await get_tree().process_frame

## A Not in a While's condition, dragged out with the mouse and let go over the
## open toolbox, which throws it away: the While's empty condition slot should
## show again (ar-4). Prints whether it does.
func _trash_shots() -> void:
	Game.level = (load("res://level/levels/ar_4.tscn") as PackedScene).instantiate()
	Game.level_scene = null
	Game.level_id = &"ar-4"
	var puzzle: Puzzle = (load("res://puzzle/puzzle.tscn") as PackedScene).instantiate()
	puzzle.visible = true
	add_child(puzzle)
	puzzle.configure_level()
	for i in 20: await get_tree().process_frame
	for guide in puzzle.find_children("*", "TutorialOverlay", true, false):
		(guide as TutorialOverlay).skip()
	var loop := Block.construct(load("res://puzzle/blocks/control flow/while.tres")) as NestedBlock
	puzzle.canvas.add_child(loop)
	loop.position = puzzle._find_begin().position + Vector2(0, 220)
	for i in 5: await get_tree().process_frame
	# The Not in the slot as a drop leaves it (socket_drop_manager.gd): the
	# slot's own block hidden, and remembered by the one put in its place.
	var slot := loop.text.get_blocks()[0] as SocketBlock
	var fill := Block.construct(load("res://puzzle/blocks/socket/not.tres")) as SocketBlock
	slot.get_parent().add_child(fill)
	slot.get_parent().move_child(fill, slot.get_index())
	slot.visible = false
	fill.overridden_socket = slot
	puzzle.side_panels[0].focus_content(puzzle.toolbox)
	for i in 20: await get_tree().process_frame
	await _snap("trash_before")
	# A real drag out of the slot, toward the toolbox. Letting go is not: the
	# trash button asks where the system's own pointer is, which events don't
	# move. So the drag ends as an unsuccessful one does, the drop managers
	# answering it as they would, and then comes what the trash button does for
	# a block let go over the toolbox.
	var grab := fill.get_global_rect().position + Vector2(10, fill.get_global_rect().size.y / 2.0)
	await _drag(grab, puzzle.side_panels[0].get_global_rect().get_center(), false)
	get_viewport().gui_cancel_drag()
	await get_tree().process_frame
	puzzle.get_node(^"UserInterface/SideMenuLeft/ButtonContainer/TrashButton").call(&"_drop_data", Vector2.ZERO, fill)
	for i in 20: await get_tree().process_frame
	print("TRASH not thrown away: ", not is_instance_valid(fill), ", while's slot shows: ", is_instance_valid(slot) and slot.is_visible_in_tree())
	await _snap("trash_after")
	puzzle.queue_free()
	for i in 3: await get_tree().process_frame

## Where a press on the canvas goes (ar-4, begin holding a For block wider than
## its hat): beside begin's hat and inside the For's empty mouth it should pan,
## on the For's top it should pick the For up, the middle button should pan even
## on a block, and so should a press beside a notification. Prints each, as
## "pans" or "picks up"; the canvas doesn't move, since panning follows the
## system's own pointer, which events don't move.
func _pan_checks() -> void:
	Game.level = (load("res://level/levels/ar_4.tscn") as PackedScene).instantiate()
	Game.level_scene = null
	Game.level_id = &"ar-4"
	var puzzle: Puzzle = (load("res://puzzle/puzzle.tscn") as PackedScene).instantiate()
	puzzle.visible = true
	add_child(puzzle)
	puzzle.configure_level()
	for i in 20: await get_tree().process_frame
	for guide in puzzle.find_children("*", "TutorialOverlay", true, false):
		(guide as TutorialOverlay).skip()
	var begin := puzzle._find_begin()
	var loop := Block.construct(load("res://puzzle/blocks/control flow/for_int.tres")) as NestedBlock
	begin.mouth.add_child(loop)
	puzzle.notifications.push("A notification at the top of the canvas.", Notification.Type.LOG)
	for i in 30: await get_tree().process_frame
	var hat := begin.upper_lip.get_global_rect()
	var body := (loop.mouth.get_parent() as Control).get_global_rect()
	var note := (puzzle.notifications.get_child(0) as Control).get_global_rect()
	var spots := [
		["beside begin's hat, in its box", Vector2(hat.end.x + 24, hat.get_center().y), MOUSE_BUTTON_LEFT],
		["inside the For's empty mouth", Vector2(body.position.x + 70, body.get_center().y), MOUSE_BUTTON_LEFT],
		["on the For's top", loop.upper_lip.get_global_rect().position + Vector2(12, 14), MOUSE_BUTTON_LEFT],
		["middle button on the For's top", loop.upper_lip.get_global_rect().position + Vector2(12, 14), MOUSE_BUTTON_MIDDLE],
		["beside the notification", Vector2(note.end.x + 40, note.get_center().y), MOUSE_BUTTON_LEFT],
	]
	print("PAN begin's box ", begin.get_global_rect(), ", hat ", hat)
	for spot: Array in spots:
		var at: Vector2 = spot[1]
		_press(at, spot[2], true)
		await get_tree().process_frame
		var panning := puzzle.canvas._is_panning
		for i in range(1, 13):
			var motion := InputEventMouseMotion.new()
			motion.position = at + Vector2(3 * i, 2 * i)
			motion.global_position = motion.position
			motion.relative = Vector2(3, 2)
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT if spot[2] == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_MIDDLE
			Input.parse_input_event(motion)
			await get_tree().process_frame
		var picked: Variant = get_viewport().gui_get_drag_data() if get_viewport().gui_is_dragging() else null
		print("PAN %s: %s" % [spot[0], "pans" if panning and picked == null else ("picks up %s" % picked if picked != null else "nothing")])
		if get_viewport().gui_is_dragging():
			get_viewport().gui_cancel_drag()
		_press(at + Vector2(36, 24), spot[2], false)
		for i in 5: await get_tree().process_frame
	puzzle.queue_free()
	for i in 3: await get_tree().process_frame

## A mouse button pressed or let go at `at`, after the pointer moves there.
func _press(at: Vector2, button: MouseButton, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	var click := InputEventMouseButton.new()
	click.button_index = button
	click.pressed = pressed
	click.position = at
	click.global_position = at
	Input.parse_input_event(click)

## A left-button drag from `from` to `to`, in steps, as a mouse makes one; let
## go at the end unless `release` says not to.
func _drag(from: Vector2, to: Vector2, release := true) -> void:
	_pointer(from, true)
	await get_tree().process_frame
	for i in range(1, 13):
		var motion := InputEventMouseMotion.new()
		motion.position = from.lerp(to, i / 12.0)
		motion.global_position = motion.position
		motion.relative = (to - from) / 12.0
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
		await get_tree().process_frame
	print("DRAG under way: ", get_viewport().gui_is_dragging(), " with ", get_viewport().gui_get_drag_data())
	if release:
		_pointer(to, false)
		await get_tree().process_frame

## Two steps forward run, fast, and leave the robot two tiles on; then the
## room's Reset button, pressed as a student would, puts it back (ar-4).
func _reset_shots() -> void:
	Game.level = (load("res://level/levels/ar_4.tscn") as PackedScene).instantiate()
	Game.level_scene = null
	Game.level_id = &"ar-4"
	var puzzle: Puzzle = (load("res://puzzle/puzzle.tscn") as PackedScene).instantiate()
	puzzle.visible = true
	add_child(puzzle)
	puzzle.configure_level()
	for i in 20: await get_tree().process_frame
	for guide in puzzle.find_children("*", "TutorialOverlay", true, false):
		(guide as TutorialOverlay).skip()
	var begin := puzzle._find_begin()
	for i in 2:
		begin.mouth.add_child(Block.construct(load("res://level/objects/entities/robot/blocks/move.tres")))
	for i in 5: await get_tree().process_frame
	Interpreter.is_fast = true
	puzzle.run_program()
	var waited := 0.0
	while Interpreter.is_running and waited < 30.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	Interpreter.is_fast = false
	for i in 30: await get_tree().process_frame
	await _snap("after_run")
	var reset := puzzle.get_node(^"UserInterface/SideMenuRight/ButtonContainer/ResetButton") as Button
	print("RESET disabled after the run: ", reset.disabled)
	reset.pressed.emit()
	for i in 30: await get_tree().process_frame
	await _snap("after_reset")
	puzzle.queue_free()
	for i in 3: await get_tree().process_frame

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
	for_block.position = puzzle._find_begin().position + Vector2(0, 160)
	# A loose block let go right on top of Begin, where it can't attach: it
	# should have drifted clear by the time of the shot (PuzzleCanvas._separate).
	var loose := Block.construct(load("res://level/objects/entities/robot/blocks/move.tres"))
	puzzle.canvas.add_child(loose)
	loose.position = puzzle._find_begin().position + Vector2(12, 6)
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
