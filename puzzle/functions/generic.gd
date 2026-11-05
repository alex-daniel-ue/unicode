extends Node
## What the basic blocks do: Print, the variable blocks, Not, Compare, Math,
## Update and And/Or.
##
## Each method is a block's function, named by its BlockData (Function/method)
## and called with the block; helpers start with __, which keeps them out of the
## inspector's list of methods a block can use.


## print {value/variable}
func _print(this: Block) -> void:
	var args := await this.function.eval_args([this.function.Argument.VARIANT])
	if Interpreter.interrupted: return

	var value: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return

	var text := Core.to_python_literal(value)
	# On the room's terminal when it has one, where a goal can read it; in the
	# log either way.
	var terminal := TerminalEntity.find()
	if terminal != null and not terminal.write_text(text):
		this.function.error("The terminal is full: it holds %d lines. Is something printing again and again?" % TerminalEntity.MAX_LINES)
		return
	var output := "OUTPUT: %s" % text
	# A room's terminal shows the line already; a toast for each one too would
	# bury the screen in a level that prints five.
	if terminal == null:
		Interpreter.output_logged.emit(output)
	Interpreter.output_log.append(output)

	await Interpreter.step(this)


## set {variable} to {value/variable}
func _set_var(this: Block) -> void:
	var args := await this.function.eval_args([
		this.function.Argument.STRING_NAME, this.function.Argument.VARIANT
	])
	if Interpreter.interrupted: return

	var var_name := args[0] as StringName
	var value: Variant = this.function.unwrap(args[1])
	if Interpreter.interrupted: return

	if not Interpreter.assign_var(var_name, value):
		this.function.error("Variable '%s' doesn't exist." % var_name)
		return

	await Interpreter.step(this)


## increment {variable}
func _increment(this: Block) -> void:
	var args := await this.function.eval_args([this.function.Argument.STRING_NAME])
	if Interpreter.interrupted: return

	var var_name := args[0] as StringName
	if not Interpreter.has_var(var_name):
		this.function.error("Variable '%s' does not exist." % var_name)
		return

	var current_value: Variant = Interpreter.read_var(var_name)
	if typeof(current_value) not in [TYPE_INT, TYPE_FLOAT]:
		this.function.error("Cannot increment '%s': value is not a number." % var_name)
		return

	Interpreter.assign_var(var_name, current_value + 1)
	await Interpreter.step(this)


## initialize {variable} to {variable/value}
func _initialize(this: Block) -> void:
	var args := await this.function.eval_args([
		this.function.Argument.STRING_NAME, this.function.Argument.VARIANT
	])
	if Interpreter.interrupted: return

	var var_name := args[0] as StringName
	if not var_name.is_valid_ascii_identifier():
		this.function.error("'%s' isn't a valid variable name." % var_name)
		return

	var value: Variant = this.function.unwrap(args[1])
	if Interpreter.interrupted: return

	if not Interpreter.declare_var(var_name, value):
		this.function.error("Variable '%s' already exists." % var_name)
		return

	await Interpreter.step(this)


## not {boolean}
func _not(this: Block) -> Variant:
	# VARIANT rather than BOOL, because a variable name arrives as a StringName
	# and would fail eval_args' type check before unwrap() ever resolved it.
	var args := await this.function.eval_args([this.function.Argument.VARIANT])
	if Interpreter.interrupted: return

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


## {value/variable} {symbol} {value/variable}
func _comparison(this: Block) -> Variant:
	var args := await __resolve_operation_args(this)
	if args.is_empty(): return

	var value1: Variant = args[0]
	var symbol: Variant = args[1]
	var value2: Variant = args[2]

	await Interpreter.step(this)
	if Interpreter.interrupted: return null

	var kind_a := __kind(value1)
	var kind_b := __kind(value2)
	if kind_a != kind_b:
		var hint := "Check for quotes around a number." if "text" in [kind_a, kind_b] else ""
		this.function.error("Can't compare %s with %s. %s" % [kind_a, kind_b, hint])
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


## {value/variable} {symbol} {value/variable}
func _arithmetic(this: Block) -> Variant:
	var args := await __resolve_operation_args(this)
	if args.is_empty(): return

	if not __can_compute(this, args[0], str(args[1]), args[2]):
		return null
	await Interpreter.step(this)
	if Interpreter.interrupted: return null
	return __compute(this, args[0], str(args[1]), args[2])


## {variable} {+=, -=, ...} {value/variable}
##
## Python's assignment operators: `total += 5` is `total = total + 5`, with the
## same rules as the Math block, so `name += "!"` adds to text too.
func _update(this: Block) -> void:
	var args := await this.function.eval_args([
		this.function.Argument.STRING_NAME, this.function.Argument.VARIANT, this.function.Argument.VARIANT
	])
	if Interpreter.interrupted: return

	var var_name := args[0] as StringName
	if not Interpreter.has_var(var_name):
		this.function.error("Variable '%s' doesn't exist. Give it a value first." % var_name)
		return
	var symbol := str(args[1]).trim_suffix("=")
	var value: Variant = this.function.unwrap(args[2])
	if Interpreter.interrupted: return
	if value == null:
		this.function.error("The value after %s is empty." % args[1])
		return
	var current: Variant = Interpreter.read_var(var_name)
	if not __can_compute(this, current, symbol, value):
		return
	var result: Variant = __compute(this, current, symbol, value)
	if Interpreter.interrupted: return
	Interpreter.assign_var(var_name, result)
	await Interpreter.step(this)


## {boolean} {and/or} {boolean}
##
## Short-circuits, as Python does: the right side runs only when the left side
## hasn't already decided the answer, so on screen it never lights up. That is
## what makes a guard work: `length of xs > 0 and item 0 of xs == 3` stops at the
## left side for an empty list instead of reading an item that isn't there.
func _logical(this: Block) -> Variant:
	var left: Variant = await __logical_side(this, 0)
	if Interpreter.interrupted: return null

	var symbol: Variant = await this.function.eval_arg(1)
	if Interpreter.interrupted: return null
	if symbol not in ["and", "or"]:
		this.function.error("'%s' isn't a logical operator." % symbol)
		return null

	var decided: bool = (symbol == "and" and not left) or (symbol == "or" and left)
	if decided:
		this.function.skip_arg(2)
		await Interpreter.step(this)
		return left

	var right: Variant = await __logical_side(this, 2)
	if Interpreter.interrupted: return null
	await Interpreter.step(this)
	return right


## Whether `a symbol b` can be worked out, raising the error when not. Numbers
## take every sign; text takes + with text (joining), and * with a whole number
## (repeating: "ab" * 3 is "ababab").
func __can_compute(this: Block, value1: Variant, symbol: String, value2: Variant) -> bool:
	var type1 := typeof(value1)
	var type2 := typeof(value2)
	var number1 := type1 in [TYPE_INT, TYPE_FLOAT]
	var number2 := type2 in [TYPE_INT, TYPE_FLOAT]
	if type1 == TYPE_STRING or type2 == TYPE_STRING:
		if symbol == "*" and ((type1 == TYPE_STRING and type2 == TYPE_INT) or (type1 == TYPE_INT and type2 == TYPE_STRING)):
			return true
		if symbol == "+" and type1 == TYPE_STRING and type2 == TYPE_STRING:
			return true
		if symbol == "+":
			var number: Variant = value2 if type1 == TYPE_STRING else value1
			this.function.error(
				"'+' can join text to text, but not to a number like %s. Make it text with str() first, or use an f-string."
				% Core.to_python_repr(number)
			)
		else:
			this.function.error("Text can only be joined with + or repeated with *, not used with '%s'." % symbol)
		return false
	if not number1 or not number2:
		this.function.error("Math only works on numbers, but this has %s." % Core.to_python_repr(value2 if number1 else value1))
		return false
	return true


## `value1 symbol value2` as Python works it out: // and % round towards
## negative infinity, and ** of whole numbers stays whole.
func __compute(this: Block, value1: Variant, symbol: String, value2: Variant) -> Variant:
	if typeof(value1) == TYPE_STRING or typeof(value2) == TYPE_STRING:
		if symbol == "*":
			var text: String = value1 if typeof(value1) == TYPE_STRING else value2
			var times: int = value2 if typeof(value2) == TYPE_INT else value1
			return text.repeat(maxi(times, 0))
		return (value1 as String) + (value2 as String)
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
		"**":
			if both_int and value2 >= 0:
				var result := 1
				for i in value2:
					result *= value1
				return result
			return pow(float(value1), float(value2))

	this.function.error("'%s' isn't an arithmetic operator." % symbol)
	return null


## One side of an and/or, checked to be True or False.
func __logical_side(this: Block, index: int) -> Variant:
	var value: Variant = this.function.unwrap(await this.function.eval_arg(index))
	if Interpreter.interrupted: return null

	var symbol := this.text.get_blocks()[1].text.get_raw() if this.text.get_blocks().size() > 1 else "and/or"
	if value == null:
		this.function.error("One side of '%s' is empty." % symbol)
		return null
	if typeof(value) != TYPE_BOOL:
		this.function.error(
			"'%s' only works on True or False, but one side is %s."
			% [symbol, Core.to_python_repr(value)]
		)
		return null
	return value


## A comparison's or a sum's three slots, the two sides looked up.
func __resolve_operation_args(this: Block) -> Array:
	var args := await this.function.eval_args([
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT,
	])
	if Interpreter.interrupted: return []

	for i in [0, 2]:
		args[i] = this.function.unwrap(args[i])
		if Interpreter.interrupted: return []
		if args[i] == null:
			this.function.error("One of the values is empty.")
			return []
	return args


## How a student would name the kind of `value`, for "Can't compare ... with ...".
func __kind(value: Variant) -> String:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT: return "a number"
		TYPE_STRING: return "text"
		TYPE_BOOL: return "True/False"
	return Core.get_type_string(value)
