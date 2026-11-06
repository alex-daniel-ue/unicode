extends "res://tools/level_checks.gd"

## The AI relay's test states (ai/tests/states): each case opens its level in the
## real Puzzle, builds a student's program the way level_checks does, runs it
## (unless it has none), and saves what the AI Assistant would send with a
## question, made by the assistant's own helpers. The relay can then be tested on
## real game states without playing (ai/tests/run_hints.py).
##
## Not headless: the pictures need a renderer.
##   godot --path . --resolution 1920x1080 res://tools/hint_states.tscn
## With `-- AR-4` after the path, only the cases whose id contains that text.
##
## Each case writes ai/tests/states/<id>.json, with <id>_now.jpg (the level when
## the question is asked) and, once something has run, <id>_start.jpg (the level
## as it opened) beside it: the two pictures the game sends.

const OUT_DIR := "res://ai/tests/states"
## How long a run that never ends goes on before it is stopped, as a student
## watching it go round a few times would stop it. Long enough for IT-10's robot
## to go round three times at this speed, so its path shows the repeating.
const STOP_AFTER_S := 45.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	filter = args[0] if not args.is_empty() else ""
	Interpreter.is_fast = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await get_tree().process_frame
	for c: Dictionary in states():
		if filter.is_empty() or (c.id as String).contains(filter):
			await make_state(c)
	get_tree().quit()

## id, level, what the student got wrong, and their program in level_checks'
## spec form. A null program is the level as it opens: nothing placed, nothing run.
func states() -> Array[Dictionary]:
	var it := func(n: Variant) -> String: return "res://level/levels/it_%s.tscn" % n
	var ar := func(n: Variant) -> String: return "res://level/levels/ar_%s.tscn" % n
	var length := func(list: String) -> Array: return ["len", L(list)]
	var last := func(list: String) -> Array: return ["arith", ["len", L(list)], "-", 1]
	return [
		{id = "IT-3_empty", level = it.call(3),
			mistake = "Nothing placed or run yet: the level as it opens.",
			program = null},
		{id = "IT-5_first_loop_short", level = it.call(5),
			mistake = "The first for loop steps 2 times instead of 3.",
			program = [F("i", 1, 3, 1, [M()]), T("left"), F("i", 1, 5, 1, [M()])]},
		{id = "IT-9_flag_check_only", level = it.call(9),
			mistake = "Checks for the flag but never for the puddle.",
			program = [W(["bool", "True"], [I(A("destination"), [M(), ["break"]]), M()])]},
		{id = "IT-10_turn_right", level = it.call(10),
			mistake = "Turns right at a wall instead of left, so the robot circles until the student presses Stop.",
			program = [W(N(A("destination")), [I(A("blocked"), [T("right"), ["continue"]]), M()]), M()]},
		{id = "AR-T2_counting_from_1", level = ar.call("t2"),
			mistake = "Uses index 3 for the third value, counting from 1.",
			program = [MV(["item", 3, L("route")])]},
		{id = "AR-4_until_length_minus_1", level = ar.call(4),
			mistake = "The loop stops at length - 1, one side of the lap short.",
			program = [F("i", 0, last.call("route"), 1, [MV(["item", "i", L("route")]), T("left")])]},
		{id = "AR-7_numbered_from_0", level = ar.call(7),
			mistake = "Puts i in each locker instead of i + 1.",
			program = [F("i", 0, length.call("lockers"), 1, [["setitem", "i", L("lockers"), "i"]])]},
		{id = "AR-8_greater_not_equal", level = ar.call(8),
			mistake = "Uses > 75 instead of >= 75, so a score of exactly 75 is left out.",
			program = [E("s", L("scores"), [I(["cmp", "s", ">", 75], [["append", "s", L("passed")]])])]},
	]

func make_state(c: Dictionary) -> void:
	var level: Level = (load(c.level) as PackedScene).instantiate()
	Game.level_scene = null
	Game.level = level
	Game.level_id = &"e2e"
	var puzzle: Puzzle = (load("res://puzzle/puzzle.tscn") as PackedScene).instantiate()
	puzzle.visible = true
	add_child(puzzle)
	puzzle.configure_level()  # takes the start picture, as in the game
	for i in 20: await get_tree().process_frame
	for guide in puzzle.find_children("*", "TutorialOverlay", true, false):
		(guide as TutorialOverlay).skip()
	for i in 10: await get_tree().process_frame

	if c.program != null:
		var begin: CapBlock = puzzle._find_begin()
		for child in begin.mouth.get_children():
			begin.mouth.remove_child(child)
			child.queue_free()
		await get_tree().process_frame
		await build_into(begin, c.program)
		for i in 2: await get_tree().process_frame
		puzzle.run_program()
		# A program that never ends is stopped the way a student stops it, with
		# the Stop button (button_manager.gd), so the log says what the game says.
		var started := Time.get_ticks_msec()
		while Interpreter.is_running:
			await get_tree().process_frame
			if not Interpreter.interrupted and Time.get_ticks_msec() - started > STOP_AFTER_S * 1000:
				Interpreter.interrupted = true
				level.fail("Program terminated.")
		for i in 30: await get_tree().process_frame  # the robot and the camera settle

	# What _send_hint_request in ai_assistant.gd sends, from the same function,
	# without the message and history, which run_hints.py adds per question.
	var assistant := puzzle.ai_assistant
	var now_shot: String = await assistant._get_viewport_jpeg_base64()
	var start_shot: String = assistant._start_shot if not puzzle.last_run_yaml.is_empty() else ""
	var context := assistant.hint_context()
	var base := ProjectSettings.globalize_path(OUT_DIR).path_join(c.id)
	_save_jpg(base + "_now.jpg", now_shot)
	if not start_shot.is_empty():
		_save_jpg(base + "_start.jpg", start_shot)
	var file := FileAccess.open(base + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({
		id = c.id,
		level_id = level.scene_file_path.get_file().get_basename(),
		mistake = c.mistake,
		context = context,
	}, "  ", false))
	file.close()
	print("STATE %s: %s" % [c.id, context.last_run])

	puzzle.queue_free()
	for i in 3: await get_tree().process_frame

func _save_jpg(path: String, b64: String) -> void:
	if b64.is_empty():
		push_warning("hint_states: no picture for %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(Marshalls.base64_to_raw(b64))
	file.close()
