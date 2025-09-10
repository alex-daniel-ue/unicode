extends Node


## text: print {value/variable}
func _print(this: Block) -> void:
	var args := await this.function.evaluate_args(1)
	if Puzzle.has_errored:
		return
	
	var value: Variant = args[0]
	if typeof(value) == TYPE_STRING_NAME:
		var parent_nested := this.get_parent_matching(Block.IS_NESTED, false) as NestedBlock
		
		if not parent_nested.scope.has(value):
			this.function.error("Variable \"%s\" doesn't exist in the current scope!" % value)
			return
		
		value = parent_nested.scope[value]
	
	var output := "OUTPUT: %s" % str(value)
	this.function.notif_pushed.emit(output, Puzzle.NotificationType.LOG)
	
	this.visual.highlight()
	await Game.sleep(Puzzle.interpret_delay)
	this.visual.reset()

## text: declare {variable}
func _declare_var(this: Block) -> void:
	var args := await this.function.evaluate_args(1)
	if Puzzle.has_errored:
		return
	
	var err_message := Core.validate_type(args[0], [TYPE_STRING_NAME])
	if not err_message.is_empty():
		this.function.error(err_message)
		return
	
	var var_name := args[0] as StringName
	if not var_name.is_valid_ascii_identifier():
		this.function.error("'%s' isn't a valid variable name." % var_name)
		return
	
	var parent_nested := this.get_parent_matching(Block.IS_NESTED, false) as NestedBlock
	if parent_nested.scope.has(var_name):
		this.function.error("Variable '%s' already exists in scope." % var_name)
		return
	
	parent_nested.scope[var_name] = null
	
	this.visual.highlight()
	await Game.sleep(Puzzle.interpret_delay)
	this.visual.reset()

## text: set {variable} to {value/variable}
func _set_var(this: Block) -> void:
	var args := await this.function.evaluate_args(2)
	if Puzzle.has_errored:
		return
	
	var err_message := Core.validate_type(args[0], [TYPE_STRING_NAME], 0)
	if not err_message.is_empty():
		this.function.error(err_message)
		return
	var var_name := args[0] as StringName
	
	var parent_nested := this.get_parent_matching(Block.IS_NESTED, false) as NestedBlock
	
	var value: Variant = args[1]
	if value is StringName:
		if not parent_nested.scope.has(value):
			this.function.error("Variable '%s' doesn't exist in scope." % value)
			return
		value = parent_nested.scope[value]
	
	parent_nested.scope[var_name] = value
	
	this.visual.highlight()
	await Game.sleep(Puzzle.interpret_delay)
	this.visual.reset()

## text: initialize {variable} to {variable/value}
func _initialize(this: Block) -> void:
	var args := await this.function.evaluate_args(2)
	if Puzzle.has_errored:
		return
	
	var err_message := Core.validate_type(args[0], [TYPE_STRING_NAME], 0)
	if not err_message.is_empty():
		this.function.error(err_message)
		return
	
	var var_name := args[0] as StringName
	if not var_name.is_valid_ascii_identifier():
		this.function.error("'%s' isn't a valid variable name." % var_name)
		return
	
	var parent_nested := this.get_parent_matching(Block.IS_NESTED, false) as NestedBlock
	if parent_nested.scope.has(var_name):
		this.function.error("Variable '%s' already exists in the current scope." % var_name)
		return
	
	var value: Variant = args[1]
	if value is StringName:
		if not parent_nested.scope.has(value):
			this.function.error("Variable '%s' doesn't exist in the current scope." % value)
			return
		value = parent_nested.scope[value]
	
	parent_nested.scope[var_name] = value
	
	this.visual.highlight()
	await Game.sleep(Puzzle.interpret_delay)
	this.visual.reset()

## text: {value/variable} {symbol} {value/variable}
func _comparison(this: Block) -> Variant:
	var args := await __resolve_operation_args(this)
	if args.is_empty():
		return

	var value1 = args[0]
	var symbol = args[1]
	var value2 = args[2]
	
	var type1 = typeof(value1)
	var type2 = typeof(value2)
	
	if type1 == TYPE_STRING or type2 == TYPE_STRING:
		if type1 != type2:
			this.function.error("Cannot compare a string with a non-string value.")
			return
		if symbol not in ["==", "!="]:
			this.function.error("Can only use '==' and '!=' on strings." % symbol)
			return
	
	elif (type1 in [TYPE_INT, TYPE_FLOAT] and type2 not in [TYPE_INT, TYPE_FLOAT]) or \
		(type1 == TYPE_BOOL and type2 != TYPE_BOOL):
			this.function.error("Cannot compare values of different types.")
			return
	
	this.visual.highlight()
	await Game.sleep(Puzzle.interpret_delay)
	this.visual.reset()
	
	return _execute_expression(this, [value1, symbol, value2])

## text: {value/variable} {symbol} {value/variable}
func _arithmetic(this: Block) -> Variant:
	var args := await __resolve_operation_args(this)
	if args.is_empty():
		return

	var value1 = args[0]
	var symbol = args[1]
	var value2 = args[2]

	var type1 = typeof(value1)
	var type2 = typeof(value2)
	
	if type1 == TYPE_STRING or type2 == TYPE_STRING:
		if type1 != TYPE_STRING or type2 != TYPE_STRING:
			this.function.error("Both values must be strings for string concatenation.")
			return
		if symbol != "+":
			this.function.error("Only '+' (concatenation) is a valid operation for strings.")
			return
	
	elif type1 not in [TYPE_INT, TYPE_FLOAT] or type2 not in [TYPE_INT, TYPE_FLOAT]:
		this.function.error("Arithmetic operations can only be performed on numbers.")
		return
	
	this.visual.highlight()
	await Game.sleep(Puzzle.interpret_delay)
	this.visual.reset()
	
	return _execute_expression(this, [value1, symbol, value2])

func _execute_expression(this: Block, args: Array) -> Variant:
	if typeof(args[0]) == TYPE_STRING:
		args[0] = '"%s"' % args[0]
	if typeof(args[2]) == TYPE_STRING:
		args[2] = '"%s"' % args[2]

	var expression := Expression.new()
	var parse_error := expression.parse("%s %s %s" % args)
	if parse_error != OK:
		this.function.error("Parsing error: %s." % expression.get_error_text())
		return
	
	var result = expression.execute([], null, false, true)
	if expression.has_execute_failed():
		this.function.error("Execution error: %s." % expression.get_error_text())
		return
	
	return result


#region Generic helper methods
func __resolve_operation_args(this: Block) -> Array:
	var args := await this.function.evaluate_args(3)
	if Puzzle.has_errored:
		return []
	
	var parent_nested := this.get_parent_matching(Block.IS_NESTED, false) as NestedBlock
	
	for i in [0, 2]:
		if args[i] is StringName:
			if not parent_nested.scope.has(args[i]):
				this.function.error("Variable '%s' doesn't exist in the current scope!" % args[i])
				return []
			args[i] = parent_nested.scope[args[i]]
	
	return args
#endregion
