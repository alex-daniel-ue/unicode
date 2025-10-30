class_name BlockFunctionComponent
extends BlockBaseComponent


signal notif_pushed(message: String, type: Puzzle.NotificationType)
signal errored(block: Block)

const ERROR_SOUND := preload("res://audio/fail.mp3")

## Function types are based on the existence of `func_script` and `func_method`
## in a BlockData.
## 1. STANDARD - When both are present. Creates a dummy Node and attaches
##		`func_script`, where `_function` becomes Callable(`dummy_node`, `func_method`)
## 2. ENTITY - When only method is present. Requires `object` to be set before
##		initializing.
## 3. LAMBDA - When none are present. Relies on earlier manual setting of
##		_function, usually in overridden _ready methods of the main Block script.
## There's no type for when only script is present, since that means nothing.

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
	await Game.sleep(Puzzle.interpret_delay)
	
	var value: Variant = await block.function.run()
	block.visual.reset()
	
	if Puzzle.has_errored:
		return null
	
	return value

func evaluate_args(arg_length := -1) -> Array:
	var evaluated: Array
	
	for block in base.text.get_blocks():
		if not block.visible:
			continue
		
		block.visual.highlight()
		await Game.sleep(Puzzle.interpret_delay)
		
		var value: Variant = await block.function.run()
		block.visual.reset()
		
		if Puzzle.has_errored:
			return []
		
		evaluated.append(value)
	
	if len(evaluated) < arg_length:
		var plurality := ' is' if arg_length == 1 else 's are'
		base.function.error("%d argument%s required." % [arg_length, plurality])
		
		return []
	
	return evaluated

func error(message: String) -> void:
	Puzzle.has_errored = true
	
	base.visual.set_error(true)
	base.visual.start_error_timer()
	
	SfxPlayer.play(ERROR_SOUND)
	
	errored.emit(base)
	notif_pushed.emit(message, Puzzle.NotificationType.ERROR)

func set_func(new_func: Callable) -> void:
	_function = new_func
