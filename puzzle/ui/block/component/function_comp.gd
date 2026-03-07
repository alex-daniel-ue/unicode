class_name BlockFunctionComponent
extends BlockBaseComponent


signal notif_pushed(message: String, type: Notification.Type)
signal errored(block: Block)

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

func evaluate_arg(at: int) -> Variant:
	var visible_blocks: Array = base.text.get_blocks().filter(
		func(_block: Block) -> bool:
			return _block.visible
	)
	
	assert(at < len(visible_blocks))
	var block := visible_blocks[at] as Block
	
	block.visual.highlight()
	await Game.sleep(Interpreter.interpret_delay)
	
	var value: Variant = await block.function.run()
	block.visual.reset()
	
	if Interpreter.interrupted:
		return null
	
	return value

func evaluate_args(arg_length := -1) -> Array:
	var evaluated: Array
	
	for block in base.text.get_blocks():
		if not block.visible:
			continue
		
		block.visual.highlight()
		await Game.sleep(Interpreter.interpret_delay)
		
		var value: Variant = await block.function.run()
		block.visual.reset()
		
		if Interpreter.interrupted:
			return []
		
		evaluated.append(value)
	
	if len(evaluated) < arg_length:
		var plurality := ' is' if arg_length == 1 else 's are'
		base.function.error("%d argument%s required." % [arg_length, plurality])
		
		return []
	
	return evaluated

func error(message: String) -> void:
	Interpreter.interrupted = true
	
	base.visual.set_error(true)
	base.visual.start_error_timer()
	
	SfxPlayer.play(ERROR_SOUND)
	
	errored.emit(base)
	notif_pushed.emit(message, Notification.Type.ERROR)

func set_func(new_func: Callable) -> void:
	_function = new_func
