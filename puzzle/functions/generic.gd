extends Object


## NOTE: Functions with bound arguments go in reverse, for example:
## prints().bind(1, 2) prints "2 1"

const BUG_WARNING := "\nThis error shouldn't be reached. This is a bug."


## Text: DECLARE [VAR_NAME]
static func function_declare_var(this: Block) -> Utils.Result:
	var result := Utils.evaluate_and_check_arguments(1, this)
	if result is Utils.Error: return result
	var args := result.data as Array
	
	# Variable name validation
	result = _validate_var_name(args, 0, this)
	if result is Utils.Error: return result
	var var_name := result.data as StringName
	
	var scope := this.parent_nested.scope
	if scope.has(var_name):
		printt(this, this.parent_nested, scope)
		return Utils.Result.error("Variable '%s' already exists in current scope!" % var_name, this)
	
	# Actual operation
	scope[var_name] = null
	
	return Utils.Result.success()

## Text: SET [VAR_NAME] TO [VAR_NAME/VALUE]
static func function_set_var(this: Block) -> Utils.Result:
	var result := Utils.evaluate_and_check_arguments(2, this)
	if result is Utils.Error: return result
	var args := result.data as Array
	var scope := this.parent_nested.scope
	
	var idx := 0
	# Variable name validation
	result = _validate_var_name(args, idx, this)
	if result is Utils.Error: return result
	var var_name := result.data as StringName
	
	if not scope.has(var_name):
		return Utils.Result.error("Variable '%s' doesn't exist in current scope!" % var_name, this)
	
	# Value checking (value)
	idx = 1
	result = _resolve_var_or_val(args[idx], this)
	if result is Utils.Error: return result
	var value: Variant = result.data
	
	if value == null:
		return Utils.Result.error("Cannot set to nothing!", this)
	
	if value is StringName:
		# Variable name validation
		result = _validate_var_name(args, idx, this)
		if result is Utils.Error: return result
	
	# Actual operation
	scope[var_name] = value
	
	return Utils.Result.success()

## Text: PRINT [VALUE/VAR_NAME]
static func function_print(this: Block) -> Utils.Result:
	var result := Utils.evaluate_and_check_arguments(1, this)
	if result is Utils.Error: return result
	var args := result.data as Array
	
	# Value checking
	result = _resolve_var_or_val(args[0], this)
	if result is Utils.Error: return result
	var value: Variant = result.data
	
	# Actual operation
	print(value)
	
	return Utils.Result.success()

## text: [VALUE/VAR_NAME] [SYMBOL] [VALUE/VAR_NAME]
static func function_comparison(this: Block) -> Utils.Result:
	return function_operation(this,
		["==", "!=", ">", "<", ">=", "<="],
		[TYPE_INT, TYPE_FLOAT, TYPE_BOOL]
	)

## text: [VALUE/VAR_NAME] [SYMBOL] [VALUE/VAR_NAME]
static func function_arithmetic(this: Block) -> Utils.Result:
	return function_operation(this,
		["+", "-", "*", "/", "%"],
		[TYPE_INT, TYPE_FLOAT, TYPE_STRING]
	)

## text: [VALUE/VAR_NAME] [SYMBOL] [VALUE/VAR_NAME]
static func function_operation(
		this: Block,
		symbols: PackedStringArray,
		types: PackedInt32Array
	) -> Utils.Result:
	
	var result := Utils.evaluate_and_check_arguments(3, this)
	if result is Utils.Error: return result
	var args := result.data as Array
	
	for idx in [0, 2]:
		result = _resolve_var_or_val(args[idx], this)
		if result is Utils.Error: return result
		args[idx] = result.data
		
		result = Utils.validate_type(args, idx, types, this)
		if result is Utils.Error: return result
	
	match typeof(args[0]):
		TYPE_INT, TYPE_FLOAT when typeof(args[2]) not in [TYPE_INT, TYPE_FLOAT]:
			return Utils.Result.error("Operands should be of the same type (number)!", this)
		TYPE_STRING when typeof(args[2]) != TYPE_STRING:
			return Utils.Result.error("Operands should be of the same type (string)!", this)
	
	# Wrap strings in quotes for Expression execution
	for idx in [0, 2]:
		if typeof(args[idx]) == TYPE_STRING:
			args[idx] = '"%s"' % args[idx]
	
	if args[1] not in symbols: # Failsafe
		return Utils.Result.error("Invalid symbol! %s" % BUG_WARNING, this)
	
	var expression := Expression.new()
	if expression.parse("%s %s %s" % args) != OK:
		var err_text := expression.get_error_text()
		return Utils.Result.error("Parsing error: %s. %s" % [err_text, BUG_WARNING], this)
	
	var expression_result: Variant = expression.execute()
	if expression.has_execute_failed():
		var err_text := expression.get_error_text()
		return Utils.Result.error("Execution error: %s. %s" % [err_text, BUG_WARNING], this)
	
	return Utils.Result.success(expression_result)


static func _resolve_var_or_val(value: Variant, this: Block) -> Utils.Result:
	var scope := this.parent_nested.scope
	if this is NestedBlock:
		scope = this.scope
	
	if value is StringName:
		if not scope.has(value):
			return Utils.Result.error("Variable '%s' doesn't exist in current scope!" % value, this)
		return Utils.Result.success(scope[value])
	return Utils.Result.success(value)

static func _validate_var_name(args: Array, idx: int, this: Block) -> Utils.Result:
	var result := Utils.validate_type(args, idx, [TYPE_STRING_NAME], this)
	if result is Utils.Error: return result
	var name := result.data as StringName
	
	if not name.is_valid_ascii_identifier():
		return Utils.Result.error("'%s' isn't a valid variable name!" % name, this)
	
	return Utils.Result.success(name)
