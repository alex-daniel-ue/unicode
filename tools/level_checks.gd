extends Node

## Runs programs through the real Puzzle, interpreter, physics and goals.

const PUZZLE := "res://puzzle/puzzle.tscn"
var MOVE: BlockData = load("res://level/objects/entities/robot/blocks/move.tres")
var AHEAD: BlockData = load("res://level/objects/entities/robot/blocks/ahead_is.tres")
var NOT: BlockData = load("res://puzzle/blocks/socket/not.tres")

var report: Array[String] = []
## `-- base` runs IT-1 alone against code without this round's patches.
var BASE := "base" in OS.get_cmdline_user_args()
var EMPTY_SLOT := "FAIL error: 1st argument must be a Boolean." if "base" in OS.get_cmdline_user_args() else "FAIL error: This slot is empty."
var yamls := {}


func _ready() -> void:
	get_tree().create_timer(420.0).timeout.connect(func() -> void:
		print("!! safety timeout"); for l in report: print(l)
		get_tree().quit())
	Interpreter.is_fast = true
	await get_tree().process_frame

	# ---- IT-1: the while is locked in the preset; the student fills it ----
	await case("IT-1 intended: while not ahead_is(blocked) { move }", "res://level/levels/it_1.tscn",
		func(p: Puzzle) -> void: _fill_while(p, _not_ahead(&"blocked"), 1), "PASS", "it_1")
	await case("IT-1 target, not barrier: while not ahead_is(destination) { move }", "res://level/levels/it_1.tscn",
		func(p: Puzzle) -> void: _fill_while(p, _not_ahead(&"destination"), 1), "FAIL Room 1")
	await case("IT-1 two steps per check: { move; move }", "res://level/levels/it_1.tscn",
		func(p: Puzzle) -> void: _fill_while(p, _not_ahead(&"blocked"), 2), "FAIL error: Robot: I can't move forward.")
	await case("IT-1 unrolled: loop skipped, five moves after it", "res://level/levels/it_1.tscn",
		func(p: Puzzle) -> void:
			_fill_while(p, _ahead(&"blocked"), 0)
			for i in 5:
				_begin(p).mouth.add_child(_tool(MOVE)),
		"FAIL Room 2")
	await case("IT-1 empty condition", "res://level/levels/it_1.tscn",
		func(p: Puzzle) -> void: _add_to(_while(p), _tool(MOVE)), EMPTY_SLOT)
	await retry_case()

	# ---- IT-0a: the whole program is the preset ----
	if BASE:
		_finish(); return
	await it_0a_case()
	await case("IT-0a hazard check: third move unguarded", "res://level/levels/it_0a.tscn",
		func(p: Puzzle) -> void:
			var if_block := _find(_begin(p), "IfBlock")
			var idx := if_block.get_index()
			if_block.get_parent().remove_child(if_block); if_block.queue_free()
			var m := _tool(MOVE); _begin(p).mouth.add_child(m); _begin(p).mouth.move_child(m, idx),
		"FAIL Room 2")
	await case("IT-0a two moves only", "res://level/levels/it_0a.tscn",
		func(p: Puzzle) -> void:
			var if_block := _find(_begin(p), "IfBlock")
			if_block.get_parent().remove_child(if_block); if_block.queue_free(),
		"FAIL Room 1")

	_finish()


func _finish() -> void:
	print("\n==================== RESULTS ====================")
	for line in report:
		print(line)
	for key in yamls:
		var f := FileAccess.open("res://tools/%s.yaml" % key, FileAccess.WRITE)
		f.store_string(yamls[key]); f.close()
	get_tree().quit()


func case(title: String, path: String, build: Callable, expect: String, yaml_key := "") -> void:
	var run := await _run(path, build)
	var got := "PASS" if run.completed else "FAIL %s" % run.reason
	var ok := got.begins_with(expect)
	report.append("%s  %-58s -> %s" % ["OK  " if ok else "BAD ", title, got])
	report.append("       placed %d, par %d, stars %d" % [run.placed, run.par, run.stars])
	if not yaml_key.is_empty():
		yamls[yaml_key] = run.yaml


func retry_case() -> void:
	# The last line of the authoring checklist: fail on purpose, then retry in
	# the same session. run_rooms() past index 0 and the retry path are what
	# have broken silently before.
	var level: Level = (load("res://level/levels/it_1.tscn") as PackedScene).instantiate()
	var puzzle := await _open(level)
	_fill_while(puzzle, _not_ahead(&"destination"), 1)
	await get_tree().process_frame
	await _apply_choices()
	var first := await _execute(puzzle, level)
	# Fix it the way a student would: swap the condition's dropdown to "blocked".
	var enum_block: ValueBlock = _find_all(_begin(puzzle), "ValueEditableEnumBlock")[0]
	enum_block.option_button.select(enum_block.data.value.enum_values.find("blocked"))
	var second := await _execute(puzzle, level)
	var ok: bool = not first.completed and second.completed
	report.append("%s  %-58s -> first %s, then %s" % ["OK  " if ok else "BAD ", "IT-1 fail, edit the dropdown, retry",
		"FAIL" if not first.completed else "PASS", "PASS" if second.completed else "FAIL %s" % second.reason])
	await _close(puzzle)


func it_0a_case() -> void:
	var level: Level = (load("res://level/levels/it_0a.tscn") as PackedScene).instantiate()
	var puzzle := await _open(level)
	var play: Button = puzzle.get_node("ButtonManager").play_button
	var gated := play.disabled
	var predict: Button = null
	for node in puzzle.information.find_children("*", "Button", true, false):
		if node.name == "PredictButton": predict = node
	predict.pressed.emit()
	await get_tree().process_frame
	var released := not play.disabled and predict.disabled

	var ahead_block: Block = _find_all(_begin(puzzle), "AheadIsBlock")[0]
	var robot := level.get_node("Visuals/YSorted/RobotCharacter")
	var bound: bool = ahead_block.function.object == robot
	var reads: Array = _begin(puzzle).get_all_blocks().map(func(b: Block) -> String: return b.text.get_raw())

	var run := await _execute(puzzle, level)
	report.append("%s  %-58s -> %s" % ["OK  " if run.completed else "BAD ", "IT-0a as built (the preset is the program)",
		"PASS" if run.completed else "FAIL %s" % run.reason])
	report.append("       placed %d, par %d, stars %d" % [run.placed, run.par, run.stars])
	report.append("%s  %-58s -> Play disabled %s, then enabled %s" % ["OK  " if gated and released else "BAD ", "IT-0a prediction gate", gated, released])
	report.append("%s  %-58s -> %s" % ["OK  " if bound else "BAD ", "IT-0a socketed ahead_is bound to the robot", bound])
	report.append("       preset reads: %s" % [reads.filter(func(s: String) -> bool: return s.begins_with("if"))])
	yamls["it_0a"] = puzzle.canvas.serializer.yaml_serialize()
	await _close(puzzle)


#region Running
func _run(path: String, build: Callable) -> Dictionary:
	var level: Level = (load(path) as PackedScene).instantiate()
	var puzzle := await _open(level)
	build.call(puzzle)
	await get_tree().process_frame
	await _apply_choices()
	var run := await _execute(puzzle, level)
	await _close(puzzle)
	return run


func _open(level: Level) -> Puzzle:
	Game.level_scene = null
	Game.level = level
	Game.level_id = &"e2e"
	var puzzle: Puzzle = (load(PUZZLE) as PackedScene).instantiate()
	add_child(puzzle)
	puzzle.configure_level()
	for i in 3:
		await get_tree().process_frame
	return puzzle


func _execute(puzzle: Puzzle, level: Level) -> Dictionary:
	var out := {completed = false, reason = "", placed = 0, par = 0, stars = 0, yaml = ""}
	var on_done := func() -> void: out.completed = true
	var on_fail := func(r: String) -> void: out.reason = r
	level.completed.connect(on_done)
	level.failed.connect(on_fail)
	await puzzle.run_program()
	if out.reason.is_empty() and not out.completed and not Interpreter.active_errors.is_empty():
		out.reason = "error: " + Interpreter.active_errors[0].message
	out.yaml = puzzle.canvas.serializer.yaml_serialize()
	out.placed = puzzle.current_run_placed_blocks
	out.par = level.get_star_par()
	out.stars = level.calculate_stars(out.placed) if out.completed else 0
	level.completed.disconnect(on_done)
	level.failed.disconnect(on_fail)
	if puzzle.level_complete.visible:
		puzzle.level_complete.hide()
	return out


func _close(puzzle: Puzzle) -> void:
	puzzle.queue_free()
	for i in 3:
		await get_tree().process_frame
#endregion


#region Program building, mimicking what a student's drops produce
func _begin(p: Puzzle) -> CapBlock:
	return p._get_begin()


func _while(p: Puzzle) -> NestedBlock:
	return _find(_begin(p), "WhileBlock")


func _fill_while(p: Puzzle, condition: Block, moves: int) -> void:
	var w := _while(p)
	_place_in_socket(w.text.get_blocks()[0], condition)
	for i in moves:
		_add_to(w, _tool(MOVE))


## A block as the toolbox hands it out: constructed, then bound to the robot
## the way BlockProvider does, so nothing here depends on the new fallback.
func _tool(data: BlockData) -> Block:
	var block := Block.construct(data)
	if data.func_type == BlockData.FuncType.ENTITY:
		block.function.object = Game.level.get_node("Visuals/YSorted/RobotCharacter")
	return block


## Exactly what socket_drop_manager does on a successful drop.
func _place_in_socket(slot: Block, block: Block) -> void:
	var container := slot.get_parent()
	var idx := slot.get_index()
	slot.visible = false
	container.add_child(block)
	container.move_child(block, idx)
	block.overridden_socket = slot


func _add_to(nested: NestedBlock, block: Block) -> void:
	nested.mouth.add_child(block)


## `not` from the toolbox, with `ahead is` from the toolbox dropped into its slot
## once `not` is on the canvas. Dropping into a block before it is in the tree
## doesn't survive: Block._ready() rebuilds its sockets from data.
func _not_ahead(tag: StringName) -> Block:
	var not_block := _tool(NOT)
	_pending_drops.append([not_block, _ahead(tag)])
	return not_block

var _pending_drops: Array = []


func _ahead(tag: StringName) -> Block:
	var block := _tool(AHEAD)
	_pending_choices.append([block, String(tag)])
	return block


## Dropdowns only fill once in the tree, so choices are applied after a frame,
## the way a student picks one after dropping the block.
var _pending_choices: Array = []
func _apply_choices() -> void:
	for pair in _pending_drops:
		_place_in_socket((pair[0] as Block).text.get_blocks()[0], pair[1])
	_pending_drops.clear()
	await get_tree().process_frame
	for pair in _pending_choices:
		var enum_block: ValueBlock = (pair[0] as Block).text.get_blocks()[0]
		enum_block.option_button.select(enum_block.data.value.enum_values.find(pair[1]))
	_pending_choices.clear()


func _find(root: Node, block_name: String) -> Block:
	var all := _find_all(root, block_name)
	return all[0] if not all.is_empty() else null


func _find_all(root: Node, data_name: String) -> Array:
	var out := []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Block and (n.data.name == data_name or String(n.name) == data_name):
			out.append(n)
		stack.append_array(n.get_children())
	out.reverse()
	return out
#endregion
