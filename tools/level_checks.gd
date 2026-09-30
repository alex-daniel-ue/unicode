extends Node

## Real-engine replay: builds each program from a compact spec, runs it through
## the real Puzzle, interpreter, physics and goals, and prints PASS or the fail
## reason next to what was expected. Replaces the old IT-0a/IT-1-only checks.
##
## Run the scene (F6 on level_checks.tscn), or headless and fast:
##   godot --headless --fixed-fps 60 --path . res://tools/level_checks.tscn -- IT-9
## The optional argument filters cases by title. A program that never ends is
## stopped after RUN_LIMIT_S and reported as RUNS FOREVER.
##
## It clears Begin and rebuilds every block, locked ones included, so it checks
## the rooms, goals and painted tiles, not the preset. Add a case per program a
## level claims to accept or kill.

const DATA := {
	"move": "res://level/objects/entities/robot/blocks/move.tres",
	"turn": "res://level/objects/entities/robot/blocks/turn.tres",
	"ahead": "res://level/objects/entities/robot/blocks/ahead_is.tres",
	"while": "res://puzzle/blocks/control flow/while.tres",
	"if": "res://puzzle/blocks/control flow/if.tres",
	"elif": "res://puzzle/blocks/control flow/elif.tres",
	"else": "res://puzzle/blocks/control flow/else.tres",
	"break": "res://puzzle/blocks/control flow/break.tres",
	"continue": "res://puzzle/blocks/control flow/continue.tres",
	"for": "res://puzzle/blocks/control flow/for_int.tres",
	"not": "res://puzzle/blocks/socket/not.tres",
	"bool": "res://puzzle/blocks/socket/boolean.tres",
	"cmp": "res://puzzle/blocks/socket/comparison.tres",
	"declare": "res://puzzle/blocks/generic/initialize.tres",
	"inc": "res://puzzle/blocks/generic/increment.tres",
	"set": "res://puzzle/blocks/generic/set_var.tres",
	"print": "res://puzzle/blocks/generic/print.tres",
	"arith": "res://puzzle/blocks/socket/arithmetic.tres",
	"andor": "res://puzzle/blocks/socket/and_or.tres",
	"moven": "res://level/objects/entities/robot/blocks/move_n.tres",
	"each": "res://puzzle/blocks/control flow/for_each.tres",
	"item": "res://puzzle/blocks/lists/item_of.tres",
	"setitem": "res://puzzle/blocks/lists/set_item.tres",
	"len": "res://puzzle/blocks/lists/length_of.tres",
	"append": "res://puzzle/blocks/lists/append.tres",
	"add": "res://puzzle/blocks/lists/add.tres",
	"in": "res://puzzle/blocks/lists/contains.tres",
}
const RUN_LIMIT_S := 90.0

var report: PackedStringArray = []
var filter := ""

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	filter = args[0] if not args.is_empty() else ""
	Interpreter.is_fast = true
	await get_tree().process_frame
	for c in cases():
		if not filter.is_empty() and not (c[0] as String).contains(filter):
			continue
		await run_case(c[0], c[1], c[2], c[3], c[4] if c.size() > 4 else [])
	print("\n==================== RESULTS ====================")
	for line in report: print(line)
	get_tree().quit()

func W(cond, body: Array) -> Array: return ["while", cond, body]
func I(cond, body: Array) -> Array: return ["if", cond, body]
func A(tag: String) -> Array: return ["ahead", tag]
func N(cond) -> Array: return ["not", cond]
func M() -> Array: return ["move"]
func T(dir: String) -> Array: return ["turn", dir]
func F(v: String, a, b, s, body: Array) -> Array: return ["for", v, a, b, s, body]
## A list's name block. Anything else in a value slot is typed into it.
func L(list_name: String) -> Array: return ["list", list_name]
func E(v: String, list, body: Array) -> Array: return ["each", v, list, body]
func MV(tiles) -> Array: return ["moven", tiles]

func cases() -> Array:
	var it9 := "res://level/levels/it_9.tscn"
	var it10 := "res://level/levels/it_10.tscn"
	return [
		["T-1 First steps", "res://level/levels/tutorial_1.tscn", [M()], "PASS"],
		["T-2 Read it first", "res://level/levels/it_0a.tscn", [M(), M(), I(N(A("puddle")), [M()])], "PASS"],
		["T-3 Rebuild it", "res://level/levels/it_0b.tscn", [M(), M(), I(N(A("puddle")), [M()])], "PASS"],
		["IT-1 intended", "res://level/levels/it_1.tscn", [W(N(A("blocked")), [M()])], "PASS"],
		["IT-2 intended", "res://level/levels/it_2.tscn", [W(N(A("destination")), [M()]), M()], "PASS"],
		["IT-3 intended", "res://level/levels/it_3.tscn", [W(N(A("destination")), [I(A("blocked"), [T("left")]), ["else", [M()]]]), M()], "PASS"],
		["IT-4 intended", "res://level/levels/it_4.tscn", [["declare", "i", 0], W(["cmp", "i", "<", 3], [M(), ["inc", "i"]])], "PASS"],
		["IT-5 intended", "res://level/levels/it_5.tscn", [F("i", 1, 3, 1, [M()]), T("left"), F("i", 1, 4, 1, [M()])], "PASS"],
		["IT-6 intended", "res://level/levels/it_6.tscn", [F("i", 1, 4, 1, [M(), T("left"), M(), T("right")])], "PASS"],
		["IT-7 intended", "res://level/levels/it_7.tscn", [F("a", 1, 3, 1, [T("left"), F("s", 1, 3, 1, [M()]), T("back"), F("s", 1, 3, 1, [M()]), T("left"), F("s", 1, 2, 1, [M()])]), T("left"), M()], "PASS"],
		["IT-8 intended", "res://level/levels/it_8.tscn", [F("row", 1, 4, 1, [F("seat", 1, "row", 1, [M()]), T("right"), M(), T("left")])], "PASS"],
		["IT-9 intended", it9, [W(["bool", "True"], [I(A("puddle"), [["break"]]), I(A("destination"), [M(), ["break"]]), M()])], "PASS"],
		["IT-9 checks swapped", it9, [W(["bool", "True"], [I(A("destination"), [M(), ["break"]]), I(A("puddle"), [["break"]]), M()])], "PASS"],
		["IT-9 puddle check only", it9, [W(["bool", "True"], [I(A("puddle"), [["break"]]), M()])], "FAIL"],
		["IT-9 flag check only", it9, [W(["bool", "True"], [I(A("destination"), [M(), ["break"]]), M()])], "FAIL"],
		["IT-9 flag check, no step onto it", it9, [W(["bool", "True"], [I(A("puddle"), [["break"]]), I(A("destination"), [["break"]]), M()])], "FAIL"],
		["IT-9 move first, then check", it9, [W(["bool", "True"], [M(), I(A("puddle"), [["break"]]), I(A("destination"), [M(), ["break"]])])], "FAIL"],
		["IT-9 four unrolled moves", it9, [M(), M(), M(), M()], "FAIL"],
		["IT-10 intended", it10, [W(N(A("destination")), [I(A("blocked"), [T("left"), ["continue"]]), M()]), M()], "PASS"],
		["IT-10 accepted: if not blocked {move; continue}; turn left", it10, [W(N(A("destination")), [I(N(A("blocked")), [M(), ["continue"]]), T("left")]), M()], "PASS"],
		["IT-10 two ifs, no continue", it10, [W(N(A("destination")), [I(A("blocked"), [T("left")]), M()]), M()], "FAIL"],
		["IT-10 nested while", it10, [W(N(A("destination")), [W(A("blocked"), [T("left")]), M()]), M()], "FAIL"],
		["IT-10 no trailing move", it10, [W(N(A("destination")), [I(A("blocked"), [T("left"), ["continue"]]), M()])], "FAIL"],
		["IT-10 turn right", it10, [W(N(A("destination")), [I(A("blocked"), [T("right"), ["continue"]]), M()]), M()], "FAIL"],
	] + arrays_cases()

## The Arrays sample (ar_sample.tscn) and checks of the list operations themselves.
## The LOG cases run on the sample's rooms with extra lists injected; only what
## they print matters.
func arrays_cases() -> Array:
	var ar := "res://level/levels/ar_sample.tscn"
	var passing := func(op: String) -> Array:
		return E("s", L("scores"), [I(["cmp", "s", op, 75], [["append", "s", L("passed")]])])
	var bag := [{name = "bag", values = [3, 1, 3, 2, 1]}, {name = "seen", kind = ListEntity.Kind.SET, capacity = 5}]
	var seen := [{name = "seen", kind = ListEntity.Kind.SET, values = [3, 1, 2], capacity = 5}]
	var nums := [{name = "nums", values = [1, 2]}]
	return [
		["AR-S intended", ar, [passing.call(">="), MV(["len", L("passed")])], "PASS"],
		["AR-S accepted: list names typed in", ar, [E("s", "scores", [I(["cmp", "s", ">=", 75], [["append", "s", "passed"]])]), MV(["len", "passed"])], "PASS"],
		["AR-S no filter", ar, [E("s", L("scores"), [["append", "s", L("passed")]]), MV(["len", L("passed")])], "FAIL Room 1 of 3 — 'passed' should end up as [82, 75, 91], but it's [70, 82, 75, 60, 91]."],
		["AR-S > instead of >=", ar, [passing.call(">"), MV(["len", L("passed")])], "FAIL Room 1 of 3 — 'passed' should end up as [82, 75, 91], but it's [82, 91]."],
		["AR-S writes into the tuple", ar, [E("s", L("scores"), [I(["cmp", "s", "<", 75], [["setitem", 0, L("scores"), 0]])])], "FAIL error: 'scores' is a tuple, so its items can't be changed."],
		["AR-S set item into empty passed", ar, [["setitem", 0, L("passed"), 82]], "FAIL error: 'passed' is empty, so it has no item 0. set item only changes"],
		["AR-S walks the length of scores", ar, [passing.call(">="), MV(["len", L("scores")])], "FAIL Room 1 of 3 — The robot didn't finish on the flag."],
		["AR-S walk typed in", ar, [passing.call(">="), MV(3)], "FAIL Room 2 of 3 — The robot didn't finish on the flag."],
		["Lists: a tuple prints like Python", ar, [["print", L("scores")]], "LOG (70, 82, 75, 60, 91)"],
		["Lists: -1 is the last item", ar, [["print", ["item", -1, L("scores")]]], "LOG 91"],
		["Lists: out of range names the list", ar, [["print", ["item", 5, L("scores")]]], "FAIL error: Index 5 is out of range. 'scores' has 5 items, at indexes 0 to 4."],
		["Lists: in scans a tuple", ar, [["print", ["in", 60, L("scores")]]], "LOG True"],
		["Lists: add is refused on a list", ar, [["add", 4, L("passed")]], "FAIL error: 'passed' is a list. Lists use append, not add."],
		["Lists: for each's variable is a copy", ar, [E("x", L("nums"), [["set", "x", 9]]), ["print", L("nums")]], "LOG [1, 2]", nums],
		["Lists: break works in for each", ar, [E("x", L("nums"), [["break"]]), ["print", 7]], "LOG 7", nums],
		["Lists: growing the list being walked", ar, [E("x", L("nums"), [["append", "x", L("nums")]])], "FAIL error: 'nums' is full", nums],
		["Sets: repeats bounce off", ar, [E("x", L("bag"), [["add", "x", L("seen")]]), ["print", L("seen")]], "LOG {1, 2, 3}", bag],
		["Sets: in finds a value", ar, [["print", ["in", 2, L("seen")]]], "LOG True", seen],
		["Sets: no item 0", ar, [["print", ["item", 0, L("seen")]]], "FAIL error: 'seen' is a set. Sets have no positions", seen],
		["Sets: append is refused", ar, [["append", 4, L("seen")]], "FAIL error: 'seen' is a set. Sets use add, not append.", seen],
		["Logic: and stops at a False left side", ar, [I(["andor", ["cmp", ["len", L("passed")], ">", 0], "and", ["cmp", ["item", 0, L("passed")], "==", 82]], [["print", 1]]), ["else", [["print", 2]]]], "LOG 2"],
		["Logic: or stops at a True left side", ar, [I(["andor", ["cmp", ["len", L("passed")], "==", 0], "or", ["cmp", ["item", 0, L("passed")], "==", 82]], [["print", 3]])], "LOG 3"],
		["Logic: and runs the right side when it must", ar, [I(["andor", ["cmp", ["len", L("scores")], ">", 0], "and", ["cmp", ["item", 0, L("scores")], "==", 71]], [["print", 4]]), ["else", [["print", 5]]]], "LOG 5"],
		["Robot: move forward text", ar, [MV(["item", 0, L("names")])], "FAIL error: Robot: I can only move a whole number of tiles, but I got 'Ana'.", [{name = "names", values = ["Ana"]}]],
	]

## `extras` adds lists to the level before it opens, so list operations can be
## checked without a scene of their own: [{name, kind, values, capacity}]. An
## `expect` of "LOG <text>" passes when a printed line contains <text>, whatever
## the rooms made of the run.
func run_case(title: String, path: String, program: Array, expect: String, extras: Array = []) -> void:
	var level: Level = (load(path) as PackedScene).instantiate()
	for extra: Dictionary in extras:
		var list := ListEntity.create()
		list.name = extra.name
		list.kind = extra.get("kind", ListEntity.Kind.LIST)
		list.values = extra.get("values", [])
		list.capacity = extra.get("capacity", 0)
		list.position = Vector2(-2000, -2000 - 100 * level.get_child_count())
		level.add_child(list)
	Game.level_scene = null
	Game.level = level
	Game.level_id = &"e2e"
	var puzzle: Puzzle = (load("res://puzzle/puzzle.tscn") as PackedScene).instantiate()
	add_child(puzzle)
	puzzle.configure_level()
	for i in 3: await get_tree().process_frame
	var begin: CapBlock = puzzle._get_begin()
	for child in begin.mouth.get_children():
		begin.mouth.remove_child(child); child.queue_free()
	await get_tree().process_frame
	await build_into(begin, program)
	for i in 2: await get_tree().process_frame

	var out := {completed = false, reason = ""}
	level.completed.connect(func() -> void: out.completed = true)
	level.failed.connect(func(r: String) -> void: out.reason = r)
	var snap := "snap" in OS.get_cmdline_user_args()
	if snap: await _snap(title + " 1 before")
	puzzle.run_program()
	var started := Time.get_ticks_msec()
	var frames := 0
	while Interpreter.is_running:
		await get_tree().process_frame
		frames += 1
		if snap and frames == 90: await _snap(title + " 2 during")
		if frames > int(RUN_LIMIT_S * 60):
			Interpreter.interrupted = true
			level.fail("RUNS FOREVER (stopped by harness)")
			while Interpreter.is_running: await get_tree().process_frame
	if out.reason.is_empty() and not out.completed and not Interpreter.active_errors.is_empty():
		out.reason = "error: " + Interpreter.active_errors[0].message
	var got: String = "PASS" if out.completed else "FAIL " + str(out.reason)
	var ok := got.begins_with(expect)
	if expect.begins_with("LOG "):
		var wanted := expect.trim_prefix("LOG ")
		var printed := Interpreter.output_log.filter(func(line: String) -> bool: return line.begins_with("OUTPUT: "))
		ok = printed.any(func(line: String) -> bool: return line.contains(wanted))
		got = " | ".join(printed) if not printed.is_empty() else got
	report.append("%s %-58s -> %s" % ["OK  " if ok else "BAD ", title, got])
	if snap: await _snap(title + " 3 after")
	if "yaml" in OS.get_cmdline_user_args():
		print(puzzle.canvas.serializer.yaml_serialize())
	puzzle.queue_free()
	for i in 3: await get_tree().process_frame

## With "snap" among the arguments (and without --headless, which draws
## nothing), each case saves screenshots before, during and after its run.
func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var file := "user://snap_%s.png" % label.validate_filename().replace(" ", "_")
	get_viewport().get_texture().get_image().save_png(file)
	print("SNAP ", ProjectSettings.globalize_path(file))
	# The level panel on its own, enlarged without smoothing, for reading detail.
	if Game.level != null and Game.level.is_inside_tree():
		var level_image := Game.level.get_viewport().get_texture().get_image()
		level_image.resize(level_image.get_width() * 2, level_image.get_height() * 2, Image.INTERPOLATE_NEAREST)
		level_image.save_png(file.replace("snap_", "level_"))

func make(kind: String) -> Block:
	var data: BlockData = load(DATA[kind])
	return Block.construct(data)

func make_spec(spec: Array) -> Block:
	if spec[0] == "list":
		# Through copy(), the pack-and-instantiate a toolbox drag goes through, so
		# the name block is checked the way a student gets one.
		var original := Block.construct(ListEntity.reporter_data(StringName(spec[1])))
		var copied := original.drag.copy()
		original.free()
		return copied
	return make(spec[0])

func build_into(nested: NestedBlock, program: Array) -> void:
	for spec in program:
		var block := make_spec(spec)
		nested.mouth.add_child(block)
		await get_tree().process_frame
		await fill(block, spec)

func fill(block: Block, spec: Array) -> void:
	match spec[0]:
		"turn", "ahead", "bool":
			await choose(block.text.get_blocks()[0], spec[1])
		"while", "if", "elif":
			await plug(block.text.get_blocks()[0], spec[1])
			await build_into(block, spec[2])
		"else":
			await build_into(block, spec[1])
		"not":
			await plug(block.text.get_blocks()[0], spec[1])
		"for":
			var slots := block.text.get_blocks()
			type_into(slots[0], str(spec[1]))
			for k in range(1, 4): await put(slots[k], spec[1 + k])
			await build_into(block, spec[5])
		"declare":
			var slots := block.text.get_blocks()
			type_into(slots[0], str(spec[1])); type_into(slots[1], str(spec[2]))
		"inc":
			type_into(block.text.get_blocks()[0], str(spec[1]))
		"cmp", "arith", "andor":
			var slots := block.text.get_blocks()
			await put(slots[0], spec[1]); await choose(slots[1], spec[2]); await put(slots[2], spec[3])
		"set":
			var slots := block.text.get_blocks()
			type_into(slots[0], str(spec[1])); await put(slots[1], spec[2])
		"print", "moven", "len":
			await put(block.text.get_blocks()[0], spec[1])
		"item", "append", "add", "in":
			var slots := block.text.get_blocks()
			await put(slots[0], spec[1]); await put(slots[1], spec[2])
		"setitem":
			var slots := block.text.get_blocks()
			await put(slots[0], spec[1]); await put(slots[1], spec[2]); await put(slots[2], spec[3])
		"each":
			var slots := block.text.get_blocks()
			type_into(slots[0], str(spec[1])); await put(slots[1], spec[2])
			await build_into(block, spec[3])

## Plugs a block into a slot when given a spec, types into it otherwise.
func put(slot: Block, x) -> void:
	if x is Array:
		await plug(slot, x)
	else:
		type_into(slot, str(x))

func plug(slot: Block, spec: Array) -> void:
	var block := make_spec(spec)
	var container := slot.get_parent()
	var idx := slot.get_index()
	slot.visible = false
	container.add_child(block)
	container.move_child(block, idx)
	block.overridden_socket = slot
	await get_tree().process_frame
	await fill(block, spec)

func choose(slot: Block, value: String) -> void:
	await get_tree().process_frame
	var vb := slot as ValueBlock
	var idx := vb.data.value.enum_values.find(value)
	assert(idx >= 0, "no option " + value)
	vb.option_button.select(idx)

func type_into(slot: Block, value: String) -> void:
	var le := (slot as ValueBlock).line_edit
	le.text = value
	le.text_changed.emit(value)
