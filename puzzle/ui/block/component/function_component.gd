class_name BlockFunctionComponent
extends BlockBaseComponent


signal notif_pushed(message: String, type: Notification.Type)

const ERROR_SOUND := preload("res://audio/fail.mp3")

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

var _function: Callable:
	set = set_func
var object: Node


func run() -> Variant:
	assert(_function != null)
	
	var value: Variant = await _function.call()
	return value

func initialize() -> void:
	var type := base.data.func_type
	if type != BlockData.FuncType.LAMBDA:
		if type == BlockData.FuncType.ENTITY:
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
		
	var parent := base.get_parent_matching(Block.IS_NESTED, false) as NestedBlock
	if not parent.scope.has(value):
		error("Variable '%s' doesn't exist in the current scope!" % value)
		return null
	
	return parent.scope[value]

func eval_args(types: Array[PackedInt32Array]) -> Array:
	var evaluated: Array
	var arg_count := types.size()
	
	for block in base.text.get_blocks():
		if not block.visible: continue
		
		await block.visual.pulse()
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
	
	var current_scope: Dictionary[StringName, Variant]
	var parent_nested := base.get_parent_matching(Block.IS_NESTED) as NestedBlock
	if parent_nested != null:
		current_scope = parent_nested.scope.duplicate()
	
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
	
	SfxPlayer.play(ERROR_SOUND)
	notif_pushed.emit(message, Notification.Type.ERROR)

func set_func(new_func: Callable) -> void:
	_function = new_func


class Argument:
	static var VARIANT := PackedInt32Array()
	static var BOOL := PackedInt32Array([TYPE_BOOL])
	static var INT := PackedInt32Array([TYPE_INT])
	static var FLOAT := PackedInt32Array([TYPE_FLOAT])
	static var STRING := PackedInt32Array([TYPE_STRING])
	static var STRING_NAME := PackedInt32Array([TYPE_STRING_NAME])
	static var NUMBER := PackedInt32Array([TYPE_INT, TYPE_FLOAT])
