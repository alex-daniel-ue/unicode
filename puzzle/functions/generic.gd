extends Object


## NOTE: Functions with bound arguments go in reverse, for example:
## prints().bind(1, 2) prints "2 1"

const UNREACHABLE_ERROR_WARNING := "\nThis error shouldn't be reached. This is a bug."


## Text: DECLARE [VAR_NAME]
func function_declare_var(this: Block) -> Variant:
	var result := Utils.evaluate_and_check_arguments(1, this)
	if result is Utils.Error: return result
	var args := result.data as Array
	
	# Variable name validation
	result = _validate_var_name(args, 0, this)
	if result is Utils.Error: return result
	var var_name := result.data as StringName
	
	var scope := this.parent_nested.scope
	if scope.has(var_name):
		return Utils.Result.error("Variable %s already exists in current scope!" % var_name, this)
	
	# Actual operation
	scope[var_name] = null
	
	return Utils.Result.success()

## Text: SET [VAR_NAME] TO [VAR_NAME/VALUE]
func function_set_var(this: Block) -> Variant:
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
	
	# (if) Variable name validation
	if value is StringName:
		result = _validate_var_name(args, idx, this)
		if result is Utils.Error: return result
	
	# Actual operation
	scope[var_name] = value
	
	return Utils.Result.success()

## Text: PRINT [VALUE/VAR_NAME]
func function_print(this: Block) -> Variant:
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
func function_comparison(this: Block) -> Variant:
	return function_operation(this,
		["==", "!=", ">", "<", ">=", "<="],
		[TYPE_INT, TYPE_FLOAT, TYPE_BOOL]
	)

## text: [VALUE/VAR_NAME] [SYMBOL] [VALUE/VAR_NAME]
func function_arithmetic(this: Block) -> Variant:
	return function_operation(this,
		["+", "-", "*", "/", "%"],
		[TYPE_INT, TYPE_FLOAT]
	)

## text: [VALUE/VAR_NAME] [SYMBOL] [VALUE/VAR_NAME]
func function_operation(this: Block, symbols: PackedStringArray, types: PackedInt32Array) -> Variant:
	var result := Utils.evaluate_and_check_arguments(3, this)
	if result is Utils.Error: return result
	var args := result.data as Array
	
	for idx in [0, 2]:
		result = _resolve_var_or_val(args[idx], this)
		if result is Utils.Error: return result
		args[idx] = result.data
		
		result = Utils.validate_type(args, idx, types, this)
		if result is Utils.Error: return result
	
	if args[1] not in symbols:
		return Utils.Result.error("Invalid symbol! %s" % UNREACHABLE_ERROR_WARNING, this)
	
	var expression := Expression.new()
	if expression.parse("%s %s %s" % args) != OK:
		return Utils.Result.error("Parsing error: %s. %s" % [expression.get_error_text(), UNREACHABLE_ERROR_WARNING], this)
	
	var exp_result: Variant = expression.execute()
	if expression.has_execute_failed():
		return Utils.Result.error("Execution error: %s. %s" % [expression.get_error_text(), UNREACHABLE_ERROR_WARNING], this)
	
	print(exp_result)
	return exp_result


func _resolve_var_or_val(value: Variant, this: Block) -> Utils.Result:
	var scope := this.parent_nested.scope
	
	if value is StringName:
		if not scope.has(value):
			return Utils.Result.error("Variable '%s' doesn't exist in current scope!" % value, this)
		return Utils.Result.success(scope[value])
	return Utils.Result.success(value)

func _validate_var_name(args: Array, idx: int, this: Block) -> Utils.Result:
	var result := Utils.validate_type(args, idx, [TYPE_STRING_NAME], this)
	if result is Utils.Error: return result
	var name := result.data as StringName
	
	if not name.is_valid_ascii_identifier():
		return Utils.Result.error("'%s' isn't a valid variable name!" % name, this)
	
	return Utils.Result.success(name)
