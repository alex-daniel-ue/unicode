extends Node


## text: print {value/variable}
func _print(this: Block) -> void:
	var args := await this.function.eval_args([this.function.Argument.VARIANT])
	if Interpreter.interrupted: return
	
	var value: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return
	
	var output := "OUTPUT: %s" % str(value)
	this.function.notif_pushed.emit(output, Notification.Type.LOG)
	Interpreter.output_log.append(output)
	
	await this.visual.pulse()


## text: declare {variable}
func _declare_var(this: Block) -> void:
	var args := await this.function.eval_args([this.function.Argument.STRING_NAME])
	if Interpreter.interrupted: return
	
	var var_name := args[0] as StringName
	if not var_name.is_valid_ascii_identifier():
		this.function.error("'%s' isn't a valid variable name." % var_name)
		return
	
	var parent_nested := this.get_parent_matching(Block.IS_NESTED, false) as NestedBlock
	if parent_nested.scope.has(var_name):
		this.function.error("Variable '%s' already exists in scope." % var_name)
		return
	
	parent_nested.scope[var_name] = null
	
	await this.visual.pulse()

## text: set {variable} to {value/variable}
func _set_var(this: Block) -> void:
	var args := await this.function.eval_args([this.function.Argument.STRING_NAME, this.function.Argument.VARIANT])
	if Interpreter.interrupted: return
	
	var var_name := args[0] as StringName
	
	var value: Variant = this.function.unwrap(args[1])
	if Interpreter.interrupted: return
	
	var parent_nested := this.get_parent_matching(Block.IS_NESTED, false) as NestedBlock
	parent_nested.scope[var_name] = value
	
	await this.visual.pulse()

## text: increment {variable}
func _increment(this: Block) -> void:
	await __crement(this, 1)

## text: decrement {variable}
func _decrement(this: Block) -> void:
	await __crement(this, -1)

func __crement(this: Block, value: int) -> void:
	var args := await this.function.eval_args([this.function.Argument.STRING_NAME])
	if Interpreter.interrupted: return
	
	var var_name := args[0] as StringName
	
	var parent_nested := this.get_parent_matching(Block.IS_NESTED, false) as NestedBlock
	if not parent_nested.scope.has(var_name):
		this.function.error("Variable '%s' doesn't exist!" % var_name)
		return
	
	var current_value: Variant = parent_nested.scope[var_name]
	if typeof(current_value) not in [TYPE_INT, TYPE_FLOAT]:
		this.function.error("Cannot increment '%s': value is not a number." % var_name)
		return
	
	parent_nested.scope[var_name] = current_value + value
	await this.visual.pulse()

## text: initialize {variable} to {variable/value}
func _initialize(this: Block) -> void:
	var args := await this.function.eval_args([this.function.Argument.STRING_NAME, this.function.Argument.VARIANT])
	if Interpreter.interrupted: return
	
	var var_name := args[0] as StringName
	if not var_name.is_valid_ascii_identifier():
		this.function.error("'%s' isn't a valid variable name." % var_name)
		return
	
	var parent_nested := this.get_parent_matching(Block.IS_NESTED, false) as NestedBlock
	if parent_nested.scope.has(var_name):
		this.function.error("Variable '%s' already exists in the current scope." % var_name)
		return
	
	var value: Variant = this.function.unwrap(args[1])
	if Interpreter.interrupted: return
	
	parent_nested.scope[var_name] = value
	
	await this.visual.pulse()

## text: {value/variable} {symbol} {value/variable}
func _comparison(this: Block) -> Variant:
	var args := await __resolve_operation_args(this)
	if args.is_empty(): return
	
	var value1: Variant = args[0]
	var symbol: Variant = args[1]
	var value2: Variant = args[2]
	
	var type1 := typeof(value1)
	var type2 := typeof(value2)
	
	if type1 == TYPE_STRING or type2 == TYPE_STRING:
		if type1 != type2:
			this.function.error("Cannot compare a string with a non-string value.")
			return
		if symbol not in ["==", "!="]:
			this.function.error("Can only use '==' and '!=' on strings.")
			return
	
	elif (type1 in [TYPE_INT, TYPE_FLOAT] and type2 not in [TYPE_INT, TYPE_FLOAT]) or \
		(type1 == TYPE_BOOL and type2 != TYPE_BOOL):
			this.function.error("Cannot compare values of different types.")
			return
	
	await this.visual.pulse()
	
	return _execute_expression(this, [value1, symbol, value2])

## text: {value/variable} {symbol} {value/variable}
func _arithmetic(this: Block) -> Variant:
	var args := await __resolve_operation_args(this)
	if args.is_empty(): return
	
	var value1: Variant = args[0]
	var symbol: Variant = args[1]
	var value2: Variant = args[2]

	var type1 := typeof(value1)
	var type2 := typeof(value2)
	
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
	
	await this.visual.pulse()
	
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
	
	var result: Variant = expression.execute([], null, false, true)
	if expression.has_execute_failed():
		this.function.error("Execution error: %s." % expression.get_error_text())
		return
	
	return result


#region Generic helper methods
func __resolve_operation_args(this: Block) -> Array:
	var args := await this.function.eval_args([
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT
	])
	if Interpreter.interrupted: return []
	
	for i in [0, 2]:
		args[i] = this.function.unwrap(args[i])
		if Interpreter.interrupted: return []
	
	return args
#endregion
