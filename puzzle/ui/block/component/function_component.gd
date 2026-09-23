class_name BlockFunctionComponent
extends BlockBaseComponent


## Determines the function type based on the presence of `func_script` and
## `func_method` in the BlockData:
## 1. STANDARD: Both script and method exist. A dummy Node is created, the
##    script is attached to it, and `_function` is assigned to
##    Callable(dummy_node, func_method).
## 2. ENTITY: Only the method is present. The `object` property must be
##    explicitly set before initialization.
## 3. LAMBDA: Neither script nor method is present. Relies on manually assigning
##    the `_function` Callable, typically done inside the overridden _ready()
##    method of the specific Block script.
## Note: Providing only a script without a method is invalid and has no designated type.

@export var _function: Callable:
	set = set_func
@export var object: Node


func run() -> Variant:
	assert(_function != null and not _function.is_null())
	
	var value: Variant = await _function.call()
	return value

func initialize() -> void:
	var type := base.data.func_type
	if type != BlockData.FuncType.LAMBDA:
		if type == BlockData.FuncType.ENTITY:
			if object == null:
				object = _find_entity()
			if object == null:
				push_error("(%s) No entity found for '%s'. Is there one in the level?" % [base.name, base.data.func_method])
			assert(object != null)
			_function = Callable(object, base.data.func_method).bind(base)
		
		elif object == null:
			var node := Node.new()
			add_child(node)
			node.set_script(base.data.func_script)
			
			_function = Callable(node, base.data.func_method).bind(base)
		
		else: assert(false)

func is_initialized() -> bool:
	return not _function.is_null()

func unwrap(value: Variant) -> Variant:
	if typeof(value) != TYPE_STRING_NAME:
		return value
	
	if not Interpreter.has_var(value):
		var var_name := str(value)
		var hint := " Python spells it %s." % var_name.capitalize() if var_name in ["true", "false"] else ""
		error("Variable '%s' doesn't exist.%s" % [value, hint])
		return null
	
	return Interpreter.read_var(value)

func eval_args(types: Array[PackedInt32Array]) -> Array:
	var evaluated: Array
	var arg_count := types.size()
	
	for block in base.text.get_blocks():
		if not block.visible: continue
		
		await Interpreter.step(block)
		if Interpreter.interrupted: return []
		
		var value: Variant = await block.function.run()
		if Interpreter.interrupted: return []
		
		evaluated.append(value)
		
	if evaluated.size() < arg_count:
		var plurality := " is" if arg_count == 1 else "s are"
		error("%d argument%s required." % [arg_count, plurality])
		return[]
		
	for i in range(arg_count):
		if not types[i].is_empty():
			var err := Core.validate_type(evaluated[i], types[i], i)
			if not err.is_empty():
				error(err)
				return[]
				
	return evaluated

func error(message: String) -> void:
	Interpreter.interrupted = true
	
	var current_scope := Interpreter.flatten_scopes()
	var trace: PackedStringArray
	var current := base.get_parent_block()
	while current != null:
		trace.append(current.text.get_raw())
		current = current.get_parent_block()
	trace.reverse()
	
	var err := Interpreter.Error.new(message, base, trace, current_scope)
	Interpreter.active_errors.append(err)
	Interpreter.output_log.append(str(err))
	
	base.visual.set_error(true)
	base.visual.start_error_timer()
	
	Interpreter.error_raised.emit(err)

func set_func(new_func: Callable) -> void:
	_function = new_func

## Blocks handed out by a BlockProvider arrive already bound to their entity, and a
## preset block authored as a scene node can have `object` set by NodePath in the
## inspector. Neither reaches a block that text.format() built from data -- anything
## inside a socket pre-filled through BlockData -- so those resolve here.
##
## By name first, because a name is the honour-system handle: the author types
## "RobotCharacter" into the block data, names the node that in the scene dock, and
## the two agree or the level says so on startup. No group to remember to join, no
## path to keep valid when a node moves.
##
## The script match is the fallback, and it is only right while the level holds
## exactly one node of that script. It now errors on two rather than silently taking
## the first, which is what made two robots or two lists unauthorable.
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


class Argument:
	static var VARIANT := PackedInt32Array()
	static var BOOL := PackedInt32Array([TYPE_BOOL])
	static var INT := PackedInt32Array([TYPE_INT])
	static var FLOAT := PackedInt32Array([TYPE_FLOAT])
	static var STRING := PackedInt32Array([TYPE_STRING])
	static var STRING_NAME := PackedInt32Array([TYPE_STRING_NAME])
	static var NUMBER := PackedInt32Array([TYPE_INT, TYPE_FLOAT])
