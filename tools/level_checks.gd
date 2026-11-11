extends Node
## Real-engine replay: builds each program from a compact spec, runs it through
## the real Puzzle, interpreter, physics and goals, and prints PASS or the fail
## reason next to what was expected.
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
	"in": "res://puzzle/blocks/lists/contains.tres",
	"input": "res://puzzle/blocks/terminal/input.tres",
	"convert": "res://puzzle/blocks/terminal/convert.tres",
	"update": "res://puzzle/blocks/generic/update.tres",
	"return": "res://puzzle/blocks/functions/return.tres",
	"get": "res://puzzle/blocks/dicts/dict_get.tres",
	"setkey": "res://puzzle/blocks/dicts/dict_set.tres",
	"remove": "res://puzzle/blocks/dicts/dict_remove.tres",
	"write": "res://puzzle/blocks/files/write.tres",
}
## The levels tools/modules/gen_modules.py writes: each one's intended program
## and the wrong ones it is built to catch, as the generator wrote them.
const MODULE_CASES := "res://tools/modules/cases.json"
const RUN_LIMIT_S := 90.0

var report: PackedStringArray = []
var filter := ""
## What the running case typed into slots a student can't type into, such as
## a list slot. Not typed: the case is reported BAD unless it expects "LOCKED".
var typed_into_locked: PackedStringArray = []


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
		# Every corner is one left turn, so the first programs a student writes pass
		# too. Turning more than once on one tile waits for IT-10.
		["IT-3 accepted: no else", "res://level/levels/it_3.tscn", [W(N(A("destination")), [I(A("blocked"), [T("left")]), M()]), M()], "PASS"],
		["IT-3 accepted: step only when the flag isn't ahead", "res://level/levels/it_3.tscn", [W(N(A("destination")), [I(A("blocked"), [T("left")]), I(N(A("destination")), [M()])]), M()], "PASS"],
		["IT-3 turn right", "res://level/levels/it_3.tscn", [W(N(A("destination")), [I(A("blocked"), [T("right")]), ["else", [M()]]]), M()], "FAIL"],
		["IT-3 no last step", "res://level/levels/it_3.tscn", [W(N(A("destination")), [I(A("blocked"), [T("left")]), ["else", [M()]]])], "FAIL"],
		["IT-4 intended", "res://level/levels/it_4.tscn", [["declare", "i", 0], W(["cmp", "i", "<", 3], [M(), ["inc", "i"]])], "PASS"],
		["IT-5 intended", "res://level/levels/it_5.tscn", [F("i", 1, 4, 1, [M()]), T("left"), F("i", 1, 5, 1, [M()])], "PASS"],
		["IT-6 intended", "res://level/levels/it_6.tscn", [F("i", 1, 5, 1, [M(), T("left"), M(), T("right")])], "PASS"],
		["IT-7 intended", "res://level/levels/it_7.tscn", [F("side", 1, 5, 1, [F("s", 1, 5, 1, [M()]), T("left")])], "PASS"],
		["IT-7 accepted: steps written out", "res://level/levels/it_7.tscn", [F("side", 1, 5, 1, [M(), M(), M(), M(), T("left")])], "PASS"],
		["IT-7 three steps a side", "res://level/levels/it_7.tscn", [F("side", 1, 5, 1, [F("s", 1, 4, 1, [M()]), T("left")])], "FAIL"],
		["IT-7 turn right", "res://level/levels/it_7.tscn", [F("side", 1, 5, 1, [F("s", 1, 5, 1, [M()]), T("right")])], "FAIL"],
		["IT-7 three sides", "res://level/levels/it_7.tscn", [F("side", 1, 4, 1, [F("s", 1, 5, 1, [M()]), T("left")])], "FAIL"],
		["IT-8 intended", "res://level/levels/it_8.tscn", [F("side", 1, 5, 1, [F("s", 0, "side", 1, [M()]), T("left")])], "PASS"],
		["IT-8 from 1 until side", "res://level/levels/it_8.tscn", [F("side", 1, 5, 1, [F("s", 1, "side", 1, [M()]), T("left")])], "FAIL"],
		["IT-8 IT-7's four steps a side", "res://level/levels/it_8.tscn", [F("side", 1, 5, 1, [F("s", 1, 5, 1, [M()]), T("left")])], "FAIL"],
		["IT-8 turn right", "res://level/levels/it_8.tscn", [F("side", 1, 5, 1, [F("s", 0, "side", 1, [M()]), T("right")])], "FAIL"],
		["IT-8 turn first, then steps", "res://level/levels/it_8.tscn", [F("side", 1, 5, 1, [T("left"), F("s", 0, "side", 1, [M()])])], "FAIL"],
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
	] + arrays_cases() + module_cases()


## The generated modules' cases, from MODULE_CASES. JSON numbers arrive as
## floats; a whole one is typed as an int, as a student would type it.
func module_cases() -> Array:
	var file := FileAccess.open(MODULE_CASES, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Array:
		push_error("level_checks: %s isn't a JSON list." % MODULE_CASES)
		return []
	return _whole_numbers(parsed)


func _whole_numbers(value: Variant) -> Variant:
	if value is Array:
		return (value as Array).map(_whole_numbers)
	if value is float and is_equal_approx(value, roundf(value)):
		return int(value)
	return value


## The Arrays module, named by level id: AR-T2 and AR-T3 (Arrays 1 and 2), then
## AR-3 to AR-11, with no AR-9 (Tidy up was cut): each level's intended program,
## what it accepts, and the wrong programs it's built to catch. Then checks of
## the list operations themselves, run on AR-8's rooms with extra lists
## injected, where only what they print matters.
func arrays_cases() -> Array:
	var lv := func(n: int) -> String: return "res://level/levels/ar_%d.tscn" % n
	var tut := func(n: int) -> String: return "res://level/levels/ar_t%d.tscn" % n
	var ar := "res://level/levels/ar_8.tscn"
	var length := func(list: String) -> Array: return ["len", L(list)]
	var last := func(list: String) -> Array: return ["arith", ["len", L(list)], "-", 1]
	var route_i := MV(["item", "i", L("route")])
	var lockers := func(from: Variant, until: Variant, index: Variant, number: Variant) -> Array:
		return [F("i", from, until, 1, [["setitem", index, L("lockers"), number]])]
	var passing := func(op: String) -> Array:
		return [E("s", L("scores"), [I(["cmp", "s", op, 75], [["append", "s", L("passed")]])])]
	var both := func(loop: String, other: String) -> Array:
		return [E("s", L(loop), [I(["in", "s", L(other)], [["append", "s", L("both")]])])]
	var days := func(check: Variant) -> Array:
		var second: Array = [["append", "s", L("present")]] if check == null else [I(check, [["append", "s", L("present")]])]
		return [E("s", L("monday"), [["append", "s", L("present")]]), E("s", L("tuesday"), second)]
	var out_trip := E("steps", L("route"), [MV("steps"), T("left")])
	var nums := [{name = "nums", values = [1, 2]}]
	return [
		["AR-T2 intended", tut.call(2), [MV(["item", 2, L("route")])], "PASS"],
		["AR-T2 counting from 1", tut.call(2), [MV(["item", 3, L("route")])], "FAIL error: Index 3 is out of range. 'route' has 3 values, at indexes 0 to 2."],
		["AR-T2 index 1", tut.call(2), [MV(["item", 1, L("route")])], "FAIL"],
		["AR-T2 index 0", tut.call(2), [MV(["item", 0, L("route")])], "FAIL"],
		["AR-T2 the last value", tut.call(2), [MV(["item", -1, L("route")])], "FAIL Room 2 of 2"],
		["AR-T2 Room 1's flag typed in", tut.call(2), [MV(3)], "FAIL Room 2 of 2"],
		["AR-T2 Room 2's flag typed in", tut.call(2), [MV(5)], "FAIL Room 1 of 2"],
		["AR-T3 intended", tut.call(3), [MV(length.call("route")), T("left"), MV(["item", 0, L("route")])], "PASS"],
		["AR-T3 the last value first", tut.call(3), [MV(["item", -1, L("route")]), T("left"), MV(["item", 0, L("route")])], "FAIL"],
		["AR-T3 counting from 1", tut.call(3), [MV(length.call("route")), T("left"), MV(["item", 1, L("route")])], "FAIL"],
		["AR-T3 length both ways", tut.call(3), [MV(length.call("route")), T("left"), MV(length.call("route"))], "FAIL"],
		["AR-T3 Room 1's numbers typed in", tut.call(3), [MV(4), T("left"), MV(2)], "FAIL error: Robot: I can't step forward."],
		["AR-3 intended", lv.call(3), [MV(["item", last.call("route"), L("route")])], "PASS"],
		["AR-3 accepted: index -1", lv.call(3), [MV(["item", -1, L("route")])], "PASS"],
		["AR-3 the last index, not its value", lv.call(3), [MV(last.call("route"))], "FAIL Room 1 of 2"],
		["AR-3 index length of route", lv.call(3), [MV(["item", length.call("route"), L("route")])], "FAIL error: Index 3 is out of range. 'route' has 3 values, at indexes 0 to 2."],
		["AR-3 index 2 typed in", lv.call(3), [MV(["item", 2, L("route")])], "FAIL Room 2 of 2"],
		["AR-3 Room 1's last value typed in", lv.call(3), [MV(5)], "FAIL Room 2 of 2"],
		["AR-4 intended", lv.call(4), [F("i", 0, 3, 1, [route_i, T("left")])], "PASS"],
		["AR-4 accepted: until length of route", lv.call(4), [F("i", 0, length.call("route"), 1, [route_i, T("left")])], "PASS"],
		["AR-4 from 1 until 4", lv.call(4), [F("i", 1, 4, 1, [route_i, T("left")])], "FAIL"],
		["AR-4 until 2", lv.call(4), [F("i", 0, 2, 1, [route_i, T("left")])], "FAIL"],
		["AR-4 index 0 every time", lv.call(4), [F("i", 0, 3, 1, [MV(["item", 0, L("route")]), T("left")])], "FAIL"],
		["AR-4 Room 1's numbers typed in", lv.call(4), [MV(3), T("left"), MV(2), T("left"), MV(3)], "FAIL Room 2 of 2"],
		["AR-5 intended", lv.call(5), [out_trip], "PASS"],
		["AR-5 turn right", lv.call(5), [E("steps", L("route"), [MV("steps"), T("right")])], "FAIL"],
		["AR-6 intended", lv.call(6), [F("i", last.call("route"), -1, -1, [route_i, T("left")])], "PASS"],
		["AR-6 from length of route", lv.call(6), [F("i", length.call("route"), -1, -1, [route_i, T("left")])], "FAIL error: Index 3 is out of range. 'route' has 3 values, at indexes 0 to 2."],
		["AR-6 until 0", lv.call(6), [F("i", last.call("route"), 0, -1, [route_i, T("left")])], "FAIL"],
		["AR-6 for each, first to last", lv.call(6), [out_trip], "FAIL"],
		["AR-6 turning right", lv.call(6), [F("i", last.call("route"), -1, -1, [route_i, T("right")])], "FAIL"],
		["AR-7 intended", lv.call(7), lockers.call(0, length.call("lockers"), "i", ["arith", "i", "+", 1]), "PASS"],
		["AR-7 accepted: count from 1", lv.call(7), lockers.call(1, ["arith", ["len", L("lockers")], "+", 1], ["arith", "i", "-", 1], "i"), "PASS"],
		["AR-7 numbered from 0", lv.call(7), lockers.call(0, length.call("lockers"), "i", "i"), "FAIL Room 1 of 3 — 'lockers' should end up as [1, 2, 3], but it's [0, 1, 2]."],
		["AR-7 index one too far", lv.call(7), lockers.call(0, length.call("lockers"), ["arith", "i", "+", 1], ["arith", "i", "+", 1]), "FAIL error: Index 3 is out of range. 'lockers' has 3 values, at indexes 0 to 2."],
		["AR-7 until length - 1", lv.call(7), lockers.call(0, last.call("lockers"), "i", ["arith", "i", "+", 1]), "FAIL Room 1 of 3 — 'lockers' should end up as [1, 2, 3], but it's [1, 2, 0]."],
		["AR-7 for each's variable is a copy", lv.call(7), [E("x", L("lockers"), [["set", "x", ["arith", "x", "+", 1]]])], "FAIL Room 1 of 3 — 'lockers' should end up as [1, 2, 3], but it's [0, 0, 0]."],
		["AR-8 intended", ar, passing.call(">="), "PASS"],
		["AR-8 no filter", ar, [E("s", L("scores"), [["append", "s", L("passed")]])], "FAIL Room 1 of 3 — 'passed' should end up as [82, 75, 91], but it's [70, 82, 75, 60, 91]."],
		["AR-8 > instead of >=", ar, passing.call(">"), "FAIL Room 1 of 3 — 'passed' should end up as [82, 75, 91], but it's [82, 91]."],
		["AR-8 set item into empty passed", ar, [["setitem", 0, L("passed"), 82]], "FAIL error: 'passed' is empty, so it has no index 0. set index only changes"],
		["AR-10 intended", lv.call(10), both.call("chess", "choir"), "PASS"],
		["AR-10 accepted: loop over choir", lv.call(10), both.call("choir", "chess"), "PASS"],
		["AR-10 no check", lv.call(10), [E("s", L("chess"), [["append", "s", L("both")]])], "FAIL Room 1 of 3 — 'both' should end up as [2, 4], but it's [1, 2, 3, 4]."],
		["AR-10 checks chess", lv.call(10), both.call("chess", "chess"), "FAIL Room 1 of 3 — 'both' should end up as [2, 4], but it's [1, 2, 3, 4]."],
		["AR-11 intended", lv.call(11), days.call(["not", ["in", "s", L("present")]]), "PASS"],
		["AR-11 no check", lv.call(11), days.call(null), "FAIL Room 1 of 3 — 'present' should end up as [1, 2, 3, 4], but it's [1, 2, 3, 2, 3, 4]."],
		["AR-11 in without not", lv.call(11), days.call(["in", "s", L("present")]), "FAIL Room 1 of 3 — 'present' should end up as [1, 2, 3, 4], but it's [1, 2, 3, 2, 3]."],
		["AR-11 Monday only", lv.call(11), [E("s", L("monday"), [["append", "s", L("present")]])], "FAIL Room 1 of 3 — 'present' should end up as [1, 2, 3, 4], but it's [1, 2, 3]."],
		["Lists: a list prints like Python", ar, [["print", L("scores")]], "LOG [70, 82, 75, 60, 91]"],
		["Lists: -1 is the last item", ar, [["print", ["item", -1, L("scores")]]], "LOG 91"],
		["Lists: out of range names the list", ar, [["print", ["item", 5, L("scores")]]], "FAIL error: Index 5 is out of range. 'scores' has 5 values, at indexes 0 to 4."],
		["Lists: in looks through a list", ar, [["print", ["in", 60, L("scores")]]], "LOG True"],
		["Lists: for each's variable is a copy", ar, [E("x", L("nums"), [["set", "x", 9]]), ["print", L("nums")]], "LOG [1, 2]", nums],
		["Lists: break works in for each", ar, [E("x", L("nums"), [["break"]]), ["print", 7]], "LOG 7", nums],
		["Lists: growing the list being walked", ar, [E("x", L("nums"), [["append", "x", L("nums")]])], "FAIL error: 'nums' already has 20 values", nums],
		["Lists: a list slot can't be typed into", ar, [["print", ["len", "scores"]]], "LOCKED"],
		["Logic: and stops at a False left side", ar, [I(["andor", ["cmp", ["len", L("passed")], ">", 0], "and", ["cmp", ["item", 0, L("passed")], "==", 82]], [["print", 1]]), ["else", [["print", 2]]]], "LOG 2"],
		["Logic: or stops at a True left side", ar, [I(["andor", ["cmp", ["len", L("passed")], "==", 0], "or", ["cmp", ["item", 0, L("passed")], "==", 82]], [["print", 3]])], "LOG 3"],
		["Logic: and runs the right side when it must", ar, [I(["andor", ["cmp", ["len", L("scores")], ">", 0], "and", ["cmp", ["item", 0, L("scores")], "==", 71]], [["print", 4]]), ["else", [["print", 5]]]], "LOG 5"],
		["Robot: step forward text", tut.call(2), [MV(["item", 0, L("names")])], "FAIL error: Robot: I can only step forward a whole number of times, but I got 'Ana'.", [{name = "names", values = ["Ana"]}]],
	]


## `extras` adds lists to the level before it opens, so list operations can be
## checked without a scene of their own: [{name, values}]. An
## `expect` of "LOG <text>" passes when a printed line contains <text>, whatever
## the rooms made of the run.
func run_case(title: String, path: String, program: Array, expect: String, extras: Array = []) -> void:
	var level: Level = (load(path) as PackedScene).instantiate()
	for extra: Dictionary in extras:
		var list := ListEntity.create()
		list.name = extra.name
		list.values = extra.get("values", [])
		list.position = Vector2(-2000, -2000 - 100 * level.get_child_count())
		level.add_child(list)
	Game.level_scene = null
	Game.level = level
	Game.level_id = &"e2e"
	var puzzle: Puzzle = (load("res://puzzle/puzzle.tscn") as PackedScene).instantiate()
	add_child(puzzle)
	puzzle.configure_level()
	for i in 3: await get_tree().process_frame
	var begin: CapBlock = puzzle._find_begin()
	for child in begin.mouth.get_children():
		begin.mouth.remove_child(child); child.queue_free()
	await get_tree().process_frame
	typed_into_locked.clear()
	# ["def", name, body] builds the body of that function's define block,
	# which the level put on the canvas; the rest goes under Begin.
	var main: Array = []
	for spec: Array in program:
		if spec[0] != "def":
			main.append(spec)
			continue
		for child in puzzle.canvas.get_children():
			if child is NestedBlock and (child as NestedBlock).is_type(NestedData.Type.FUNCTION) \
					and String((child as NestedBlock).data.func_entity_name) == spec[1]:
				for old in (child as NestedBlock).mouth.get_children():
					(child as NestedBlock).mouth.remove_child(old); old.queue_free()
				await build_into(child as NestedBlock, spec[2])
	await build_into(begin, main)
	for i in 2: await get_tree().process_frame
	if expect == "LOCKED" or not typed_into_locked.is_empty():
		var locked := not typed_into_locked.is_empty()
		var said := "refused typing %s" % ", ".join(typed_into_locked) if locked else "accepted every value typed"
		report.append("%s %-58s -> %s" % ["OK  " if locked == (expect == "LOCKED") else "BAD ", title, said])
		puzzle.queue_free()
		for i in 3: await get_tree().process_frame
		return

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
		if snap and frames in [90, 240]: await _snap(title + " 2 during %d" % frames)
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
	if spec[0] == "call":
		# A level's own function: its call block comes from the level.
		var data := FunctionDefinitions.call_data_for(spec[1])
		assert(data != null, "no function " + str(spec[1]))
		return Block.construct(data)
	if spec[0] == "file":
		var original_file := Block.construct(FileBlockProvider.reporter_data(spec[1]))
		var copied_file := original_file.drag.copy()
		original_file.free()
		return copied_file
	if spec[0] == "dict":
		var original_dict := Block.construct(DictBlockProvider.reporter_data(StringName(spec[1])))
		var copied_dict := original_dict.drag.copy()
		original_dict.free()
		return copied_dict
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
			type_into(slots[0], str(spec[1])); await put(slots[1], spec[2])
		"convert":
			var slots := block.text.get_blocks()
			await choose(slots[0], spec[1]); await put(slots[1], spec[2])
		"update":
			var slots := block.text.get_blocks()
			type_into(slots[0], str(spec[1])); await choose(slots[1], spec[2]); await put(slots[2], spec[3])
		"inc":
			type_into(block.text.get_blocks()[0], str(spec[1]))
		"cmp", "arith", "andor":
			var slots := block.text.get_blocks()
			await put(slots[0], spec[1]); await choose(slots[1], spec[2]); await put(slots[2], spec[3])
		"set":
			var slots := block.text.get_blocks()
			type_into(slots[0], str(spec[1])); await put(slots[1], spec[2])
		"print", "moven", "len", "return":
			await put(block.text.get_blocks()[0], spec[1])
		"call":
			var slots := block.text.get_blocks()
			for k in range(2, spec.size()):
				await put(slots[k - 2], spec[k])
		"item", "append", "add", "in", "get", "remove", "write":
			var slots := block.text.get_blocks()
			await put(slots[0], spec[1]); await put(slots[1], spec[2])
		"setitem", "setkey":
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
	if not (slot as ValueBlock).data.value.editable:
		typed_into_locked.append(value)
		return
	var le := (slot as ValueBlock).line_edit
	le.text = value
	le.text_changed.emit(value)
