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
	var all: Array[Dictionary] = [
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
	all.append_array(module_states())
	return all

## Two real mistakes from each of the other modules, taken from the wrong programs
## tools/modules/cases.json already checks. IO-1 is the one from the survey
## screenshot: Hello, World typed without quotes, which prints None.
func module_states() -> Array[Dictionary]:
	var lv := func(name: String) -> String: return "res://level/levels/%s.tscn" % name
	var read_int: Array = ["convert", "int", ["input"]]
	var cases: Array[Dictionary] = [
		{id = "IO-1_no_quotes", level = lv.call("io_1"),
			mistake = "Hello, World typed without quotes, so the terminal shows None.",
			program = [["print", "Hello, World"]]},
		{id = "IO-6_three_inputs", level = lv.call("io_6"),
			mistake = "Reads input three times, but the user types only two lines.",
			program = [["print", ["input"]], ["print", ["input"]], ["print", ["input"]]]},
		{id = "VAR-3_no_f", level = lv.call("var_3"),
			mistake = "Leaves the f off the f-string, so {name} is printed as it is.",
			program = [["declare", "name", ["input"]], ["print", "\"Hello, {name}!\""]]},
		{id = "VAR-7_no_convert", level = lv.call("var_7"),
			mistake = "Never converts the input, so the price stays text.",
			program = [["declare", "price", ["input"]], ["print", "f\"Price: {price}\""]]},
		{id = "OP-7_times_not_power", level = lv.call("op_7"),
			mistake = "Uses * where ** (to the power of) is needed.",
			program = [["declare", "n", read_int], ["print", ["arith", "n", "*", 2]], ["print", ["arith", "n", "*", 3]]]},
		{id = "OP-8_set_not_add", level = lv.call("op_8"),
			mistake = "Uses = instead of +=, so only the last number is kept.",
			program = [["declare", "total", 0], ["set", "total", read_int], ["set", "total", read_int],
				["set", "total", read_int], ["print", "total"]]},
		{id = "SEL-1_no_int", level = lv.call("sel_1"),
			mistake = "Compares the input, still text, with the number 100.",
			program = [["declare", "n", ["input"]], ["if", ["cmp", "n", ">", 100], [["print", "\"That is a lot!\""]]],
				["print", "\"Thank you.\""]]},
		{id = "SEL-5_ifs_not_elifs", level = lv.call("sel_5"),
			mistake = "Uses separate ifs instead of elif, so a high score prints more than one grade.",
			program = [["declare", "score", read_int],
				["if", ["cmp", "score", ">=", 90], [["print", "\"Grade: A\""]]],
				["if", ["cmp", "score", ">=", 80], [["print", "\"Grade: B\""]]],
				["if", ["cmp", "score", ">=", 70], [["print", "\"Grade: C\""]]],
				["else", [["print", "\"Grade: F\""]]]]},
		{id = "FN-5_printed_not_returned", level = lv.call("fn_5"),
			mistake = "The function prints the double instead of returning it, so it gives back None.",
			program = [["def", "double", [["print", ["arith", "n", "*", 2]]]], ["moven", ["call", "double", read_int]]]},
		{id = "FN-6_a_minus_b_only", level = lv.call("fn_6"),
			mistake = "Always returns a - b, which is negative when b is bigger.",
			program = [["def", "distance", [["return", ["arith", "a", "-", "b"]]]],
				["moven", ["call", "distance", read_int, read_int]]]},
		{id = "DICT-5_no_check", level = lv.call("dict_5"),
			mistake = "Looks up the item without checking that it is a key first.",
			program = [["declare", "item", ["input"]], ["print", ["get", ["dict", "prices"], "item"]]]},
		{id = "DICT-6_set_to_1", level = lv.call("dict_6"),
			mistake = "Sets each vote to 1 instead of adding 1, so repeats aren't counted.",
			program = [F("i", 0, 3, 1, [["declare", "color", ["input"]], ["setkey", ["dict", "votes"], "color", 1]])]},
		{id = "FILES-6_no_int", level = lv.call("files_6"),
			mistake = "Adds each line, still text, to a number without int().",
			program = [["declare", "total", 0], ["each", "line", ["file", "scores.txt"], [["update", "total", "+=", "line"]]],
				["print", "f\"Total: {total}\""]]},
		{id = "FILES-9_counting_from_0", level = lv.call("files_9"),
			mistake = "Numbers the lines from 0 instead of 1.",
			program = [["declare", "n", 0], ["each", "line", ["file", "poem.txt"],
				[["write", "f\"{n}: {line}\"", ["file", "numbered.txt"]], ["update", "n", "+=", 1]]]]},
	]
	return cases

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
		# ["def", name, body] fills that function's define block, which the level
		# put on the canvas, as level_checks does; the rest goes under Begin.
		var main: Array = []
		for spec: Array in c.program:
			if spec[0] != "def":
				main.append(spec)
				continue
			for child in puzzle.canvas.get_children():
				if child is NestedBlock and (child as NestedBlock).is_type(NestedData.Type.FUNCTION) \
						and String((child as NestedBlock).data.func_entity_name) == spec[1]:
					for old in (child as NestedBlock).mouth.get_children():
						(child as NestedBlock).mouth.remove_child(old)
						old.queue_free()
					await build_into(child as NestedBlock, spec[2])
		await build_into(begin, main)
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
