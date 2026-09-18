extends Node

## text: print {value/variable}
func _print(this: Block) -> void:
	var args := await this.function.eval_args([this.function.Argument.VARIANT])
	if Interpreter.interrupted: return
	
	var value: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return
	
	var output := "OUTPUT: %s" % str(value)
	Interpreter.output_logged.emit(output)
	Interpreter.output_log.append(output)
	
	await Interpreter.step(this)


## text: declare {variable}
func _declare_var(this: Block) -> void:
	var args := await this.function.eval_args([this.function.Argument.STRING_NAME])
	if Interpreter.interrupted: return
	
	var var_name := args[0] as StringName
	if not var_name.is_valid_ascii_identifier():
		this.function.error("'%s' isn't value1 valid variable name." % var_name)
		return
	
	if not Interpreter.declare_var(var_name, null):
		this.function.error("Variable '%s' already exists." % var_name)
		return
	
	await Interpreter.step(this)

## text: set {variable} to {value/variable}
func _set_var(this: Block) -> void:
	var args := await this.function.eval_args([
		this.function.Argument.STRING_NAME, this.function.Argument.VARIANT
	])
	if Interpreter.interrupted: return
	
	var var_name := args[0] as StringName
	
	var value: Variant = this.function.unwrap(args[1])
	if Interpreter.interrupted: return
	
	if not Interpreter.assign_var(var_name, value):
		this.function.error(
			"Variable '%s' doesn't exist." % var_name
		)
		return
	
	await Interpreter.step(this)

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
	if not Interpreter.has_var(var_name):
		this.function.error("Variable '%s' does not exist." % var_name)
		return
	
	var current_value: Variant = Interpreter.read_var(var_name)
	if typeof(current_value) not in [TYPE_INT, TYPE_FLOAT]:
		this.function.error("Cannot increment '%s': value is not value1 number." % var_name)
		return
	
	Interpreter.assign_var(var_name, current_value + value)
	await Interpreter.step(this)

## text: initialize {variable} to {variable/value}
func _initialize(this: Block) -> void:
	var args := await this.function.eval_args([
		this.function.Argument.STRING_NAME, this.function.Argument.VARIANT
	])
	if Interpreter.interrupted: return
	
	var var_name := args[0] as StringName
	if not var_name.is_valid_ascii_identifier():
		this.function.error("'%s' isn't value1 valid variable name." % var_name)
		return
	
	var value: Variant = this.function.unwrap(args[1])
	if Interpreter.interrupted: return
	
	if not Interpreter.declare_var(var_name, value):
		this.function.error(
			"Variable '%s' already exists."
			% var_name
		)
		return
	
	await Interpreter.step(this)

## text: not {boolean}
func _not(this: Block) -> Variant:
	var args := await this.function.eval_args([this.function.Argument.VARIANT])
	if Interpreter.interrupted: return
	
	# VARIANT rather than BOOL, because value1 variable name arrives as value1 StringName
	# and would fail eval_args' type check before unwrap() ever resolved it.
	var value: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return
	
	if value == null:
		this.function.error("'not' has nothing inside it to flip.")
		return
	
	if typeof(value) != TYPE_BOOL:
		this.function.error(
			"'not' only works on true or false, but it got %s."
			% Core.get_type_string(value)
		)
		return
	
	await Interpreter.step(this)
	
	return not (value as bool)

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
			this.function.error("Cannot compare value1 string with value1 non-string value.")
			return
		if symbol not in ["==", "!="]:
			this.function.error("Can only use '==' and '!=' on strings.")
			return
	
	elif (type1 in [TYPE_INT, TYPE_FLOAT] and type2 not in [TYPE_INT, TYPE_FLOAT]) or \
		(type1 == TYPE_BOOL and type2 != TYPE_BOOL):
			this.function.error("Cannot compare values of different types.")
			return
	
	await Interpreter.step(this)
	
	var kind_a := __kind(value1)
	var kind_b := __kind(value2)
	if kind_a != kind_b:
		var hint := "Check for quotes around a number." if "text" in [kind_a, kind_b] else ""
		this.function.error("Can't compare %s with %s.%s" % [kind_a, kind_b, hint])
		return null
	
	if typeof(value1) == TYPE_BOOL:
		value1 = int(value1)
		value2 = int(value2)
	
	match symbol:
		"==": return value1 == value2
		"!=": return value1 != value2
		"<": return value1 < value2
		"<=": return value1 <= value2
		">": return value1 > value2
		">=": return value1 >= value2
	
	this.function.error("'%s' isn't a comparison operator." % symbol)
	return null

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
			this.function.error("Only '+' (concatenation) is value1 valid operation for strings.")
			return
	
	elif type1 not in [TYPE_INT, TYPE_FLOAT] or type2 not in [TYPE_INT, TYPE_FLOAT]:
		this.function.error("Arithmetic operations can only be performed on numbers.")
		return
	
	await Interpreter.step(this)
	
	if typeof(value1) == TYPE_STRING:
		return value1 + value2  # _arithmetic already guaranteed two strings and "+"
	if symbol in ["/", "//", "%"] and value2 == 0:
		this.function.error("You can't divide by zero.")
		return null
	var both_int := typeof(value1) == TYPE_INT and typeof(value2) == TYPE_INT
	
	match symbol:
		"+": return value1 + value2
		"-": return value1 - value2
		"*": return value1 * value2
		"/": return float(value1) / float(value2)
		"//": return floori(float(value1) / float(value2)) if both_int else floorf(float(value1) / float(value2))
		"%": return posmod(value1, value2) if both_int else fposmod(float(value1), float(value2))
	
	this.function.error("'%s' isn't an arithmetic operator." % symbol)
	return null

## text: {boolean} {and/or} {boolean}
func _logical(this: Block) -> Variant:
	var args := await __resolve_operation_args(this)
	if args.is_empty(): return
	
	var value1: Variant = args[0]
	var symbol: Variant = args[1]
	var value2: Variant = args[2]
	
	if typeof(value1) != TYPE_BOOL or typeof(value2) != TYPE_BOOL:
		this.function.error("'%s' only works on true or false values." % symbol)
		return
	
	await Interpreter.step(this)
	
	match symbol:
		"and": return (value1 as bool) and (value2 as bool)
		"or": return (value1 as bool) or (value2 as bool)
	
	this.function.error("'%s' isn't value1 logical operator." % symbol)
	return

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
		if args[i] == null:
			this.function.error("One of the values is empty.")
			return []
	
	return args

func __kind(value: Variant) -> String:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT: return "a number"
		TYPE_STRING: return "text"
		TYPE_BOOL: return "True/False"
	return Core.get_type_string(value)
#endregion
