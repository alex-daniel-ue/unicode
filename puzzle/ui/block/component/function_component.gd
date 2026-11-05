class_name BlockFunctionComponent
extends BlockBaseComponent
## What a block does when it runs, and what its function uses to do it:
## evaluating its parameters, looking names up, raising errors.
##
## The block's data says where its function is (BlockData.func_type):
## - STANDARD: a method on a script in puzzle/functions/. The script is put on
##   a Node of this component's, and the method is called with the block.
## - ENTITY: a method on something in the level (the robot, a list), called
##   with the block. The entity is `object`, or is found by the data's entity
##   name or script (_find_entity()).
## - LAMBDA: nothing to look up. The block's own script sets the callable (a
##   slot's socket_function()).

## The entity an ENTITY block talks to. A BlockProvider sets it on the blocks it
## hands out; a preset block authored as a scene node can set it by NodePath.
@export var object: Node

var _callable: Callable


## Runs the block: what it does, and what it gives back.
func run() -> Variant:
	assert(not _callable.is_null())
	return await _callable.call()


func initialize() -> void:
	match base.data.func_type:
		BlockData.FuncType.ENTITY:
			if object == null:
				object = _find_entity()
			if object == null:
				push_error("(%s) No entity found for '%s'. Is there one in the level?" % [base.name, base.data.func_method])
			assert(object != null)
			_callable = Callable(object, base.data.func_method).bind(base)
		BlockData.FuncType.STANDARD:
			assert(object == null)
			var node := Node.new()
			add_child(node)
			node.set_script(base.data.func_script)
			_callable = Callable(node, base.data.func_method).bind(base)


func set_callable(callable: Callable) -> void:
	_callable = callable


## `value` itself, or, for a name, what the name means: a variable's value, else
## the room's list, dictionary or file of that name (Python's lists are names
## too, and a variable of the same name wins, as it would in Python). Raises
## the error and gives null for a name that means nothing.
func unwrap(value: Variant) -> Variant:
	if typeof(value) != TYPE_STRING_NAME:
		return value
	if Interpreter.has_var(value):
		return Interpreter.read_var(value)

	var list := ListEntity.find(value)
	if list != null:
		return list
	var board := DictEntity.find(value)
	if board != null:
		return board
	var file := FileEntity.find(value)
	if file != null:
		return file

	var var_name := str(value)
	var hint := " Python spells it %s." % var_name.capitalize() if var_name in ["true", "false"] else ""
	error("Variable '%s' doesn't exist.%s" % [value, hint])
	return null


## The room entity of `kind` (ListEntity, DictEntity, FileEntity) that an
## argument names, or null after raising the error. A name block arrives as the
## entity itself; a typed-in name is looked up by unwrap(), a variable first.
## `noun` is what the block needs, for the message: "a list".
func resolve(raw: Variant, kind: Script, noun: String) -> RoomEntity:
	var value: Variant = unwrap(raw)
	if Interpreter.interrupted:
		return null
	if value is RoomEntity and (value as RoomEntity).get_script() == kind:
		return value
	# Named by the block's name, as students know it, not its text.
	var block_name := base.data.display_name()
	if value == null:
		error("The %s block needs %s. Drop the name block of %s into its empty slot." % [block_name, noun, noun])
	else:
		error("The %s block needs %s, but it got %s." % [block_name, noun, Core.to_python_repr(value)])
	return null


## Every parameter, evaluated in order, each type checked against `types` (one
## entry per parameter; an empty entry takes anything). Empty after an error.
func eval_args(types: Array[PackedInt32Array]) -> Array:
	var evaluated: Array
	var arg_count := types.size()
	Interpreter.values_cleared.emit(base)

	for block in base.text.get_blocks():
		await Interpreter.step(block)
		if Interpreter.interrupted:
			return []

		var value: Variant = await block.function.run()
		if Interpreter.interrupted:
			return []

		# A slot that names the variable being set (set, for, for each) isn't
		# read, so its value would only be the old one.
		var index := evaluated.size()
		if index >= arg_count or types[index] != Argument.STRING_NAME:
			Interpreter.value_shown.emit(block, value)
		evaluated.append(value)

	if evaluated.size() < arg_count:
		var plurality := " is" if arg_count == 1 else "s are"
		error("%d argument%s required." % [arg_count, plurality])
		return []

	var params := base.text.get_blocks()
	for i in range(arg_count):
		# A name slot whose text isn't a name Python would accept says which
		# name, and why. Core.validate_type() would say "1st argument must be a
		# variable name", which reads oddly when the name typed was "1st".
		if types[i] == Argument.STRING_NAME and evaluated[i] == null:
			var typed: String = params[i].text.get_raw() if i < params.size() else ""
			if not typed.strip_edges().is_empty():
				error("'%s' isn't a valid variable name. A name starts with a letter or _, and has no spaces." % typed)
				return []
		if not types[i].is_empty():
			var err := Core.validate_type(evaluated[i], types[i], i)
			if not err.is_empty():
				error(err)
				return []

	return evaluated


## One parameter, evaluated on its own and only when asked for. eval_args() runs
## every parameter up front; a short-circuiting `and`/`or` must not run its right
## side at all when the left side already decides the answer. Null after an
## error, so check Interpreter.interrupted.
func eval_arg(index: int) -> Variant:
	var params := base.text.get_blocks()
	if index >= params.size():
		error("%d arguments are required." % (index + 1))
		return null

	if index == 0:
		Interpreter.values_cleared.emit(base)
	var block: Block = params[index]
	await Interpreter.step(block)
	if Interpreter.interrupted:
		return null
	var value: Variant = await block.function.run()
	if not Interpreter.interrupted:
		Interpreter.value_shown.emit(block, value)
	return value


## Marks parameter `index` as not evaluated this time, for the value tags, as
## when the left side of an and/or has already decided the answer.
func skip_arg(index: int) -> void:
	var params := base.text.get_blocks()
	if index < params.size():
		Interpreter.value_skipped.emit(params[index])


## Stops the run with `message`, on this block: it flashes red, and the message
## goes to the student, the output log and the assistant.
func error(message: String) -> void:
	Interpreter.interrupted = true

	var current_scope := Interpreter.flatten_scopes()
	var trace: PackedStringArray
	var current := base.get_parent_block()
	while current != null:
		trace.append(current.text.get_raw())
		current = current.get_parent_block()
	trace.reverse()

	var err := Interpreter.BlockError.new(message, base, trace, current_scope)
	Interpreter.active_errors.append(err)
	Interpreter.output_log.append(str(err))

	base.visual.set_error(true)
	base.visual.start_error_timer()

	Interpreter.error_raised.emit(err)


## Blocks handed out by a BlockProvider arrive already bound to their entity, and a
## preset block authored as a scene node can have `object` set by NodePath. Neither
## reaches a block that text.format() built from data (anything inside a socket
## pre-filled through BlockData), so those resolve here.
##
## By name first: the author types "RobotCharacter" into the block data, names
## the node that in the scene dock, and the two agree or the level says so on
## startup. No group to remember to join, no path to keep valid when a node moves.
##
## The script match is the fallback, and it is only right while the level holds
## exactly one node of that script, so two is an error rather than a guess.
func _find_entity() -> Node:
	var root := _level_root()
	if root == null:
		return null

	var wanted_name := base.data.func_entity_name
	if not wanted_name.is_empty():
		var named := root.find_children(String(wanted_name), "", true, false)
		if named.size() == 1:
			return named[0]
		if named.is_empty():
			push_error(
				"(%s) No node named '%s' in level '%s'. Rename the entity to match the block's Function/entity_name, or clear that field."
				% [base.name, wanted_name, root.name]
			)
		else:
			push_error(
				"(%s) %d nodes named '%s' in level '%s'. Entity names have to be unique within a level."
				% [base.name, named.size(), wanted_name, root.name]
			)
		return null

	var wanted := base.data.func_entity_script
	if wanted == null:
		return null

	var matches: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var script := node.get_script() as Script
		while script != null:
			if script == wanted:
				matches.append(node)
				break
			script = script.get_base_script()
		stack.append_array(node.get_children())

	if matches.size() == 1:
		return matches[0]
	if matches.size() > 1:
		push_error(
			"(%s) Level '%s' holds %d entities running this block's script, so the block can't tell which one it means. Set Function/entity_name on the block data."
			% [base.name, root.name, matches.size()]
		)
	return null


func _level_root() -> Node:
	var root: Node = base
	while root != null and not (root is Level):
		root = root.get_parent()
	return root if root != null else Game.level


## The type checks eval_args() takes, one per parameter.
class Argument:
	static var VARIANT := PackedInt32Array()
	static var BOOL := PackedInt32Array([TYPE_BOOL])
	static var INT := PackedInt32Array([TYPE_INT])
	static var FLOAT := PackedInt32Array([TYPE_FLOAT])
	static var STRING := PackedInt32Array([TYPE_STRING])
	static var STRING_NAME := PackedInt32Array([TYPE_STRING_NAME])
	static var NUMBER := PackedInt32Array([TYPE_INT, TYPE_FLOAT])
