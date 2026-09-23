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
		await run_case(c[0], c[1], c[2], c[3])
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
	]

func run_case(title: String, path: String, program: Array, expect: String) -> void:
	var level: Level = (load(path) as PackedScene).instantiate()
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
	puzzle.run_program()
	var started := Time.get_ticks_msec()
	var frames := 0
	while Interpreter.is_running:
		await get_tree().process_frame
		frames += 1
		if frames > int(RUN_LIMIT_S * 60):
			Interpreter.interrupted = true
			level.fail("RUNS FOREVER (stopped by harness)")
			while Interpreter.is_running: await get_tree().process_frame
	if out.reason.is_empty() and not out.completed and not Interpreter.active_errors.is_empty():
		out.reason = "error: " + Interpreter.active_errors[0].message
	var got: String = "PASS" if out.completed else "FAIL " + str(out.reason)
	var ok := got.begins_with(expect)
	report.append("%s %-58s -> %s" % ["OK  " if ok else "BAD ", title, got])
	if "yaml" in OS.get_cmdline_user_args():
		print(puzzle.canvas.serializer.yaml_serialize())
	puzzle.queue_free()
	for i in 3: await get_tree().process_frame

func make(kind: String) -> Block:
	var data: BlockData = load(DATA[kind])
	return Block.construct(data)

func build_into(nested: NestedBlock, program: Array) -> void:
	for spec in program:
		var block := make(spec[0])
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
			for k in 4: type_into(slots[k], str(spec[1 + k]))
			await build_into(block, spec[5])
		"declare":
			var slots := block.text.get_blocks()
			type_into(slots[0], str(spec[1])); type_into(slots[1], str(spec[2]))
		"inc":
			type_into(block.text.get_blocks()[0], str(spec[1]))
		"cmp":
			var slots := block.text.get_blocks()
			type_into(slots[0], str(spec[1])); await choose(slots[1], spec[2]); type_into(slots[2], str(spec[3]))

func plug(slot: Block, spec: Array) -> void:
	var block := make(spec[0])
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
