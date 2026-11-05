class_name TerminalFunctions
extends Node

## The terminal's blocks, and the conversions that go with what it gives:
## Input reads a line the user typed in the running room, as text, the way
## Python's input() does; Convert is int(), float() and str(). Print stays in
## generic.gd, where it writes to the terminal when the room has one.


## text: input ( ). Not _input, which is Godot's own input callback on every Node.
func _read_input(this: Block) -> Variant:
	var terminal := TerminalEntity.find()
	if terminal == null:
		this.function.error("There's no terminal in this room, so no one can type anything for input() to read.")
		return null
	var line: Variant = terminal.read_input()
	if line == null:
		var count := terminal.inputs.size()
		this.function.error(
			"input() has nothing left to read. In this room the user typed %d line%s, and the program already read %s."
			% [count, "" if count == 1 else "s", "it" if count == 1 else "them all"]
		)
		return null
	await Interpreter.step(this)
	return line

## text: {int/float/str} ( {value} )
##
## Python's rules: int() of text needs a whole number written out ("12", not
## "12.5"), int() of a decimal number drops what's after the point, and float()
## of a whole number gives it a ".0". str() writes a value the way print() does.
func _convert(this: Block) -> Variant:
	var args := await this.function.eval_args([
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT,
	])
	if Interpreter.interrupted: return null

	var kind := str(args[0])
	var value: Variant = this.function.unwrap(args[1])
	if Interpreter.interrupted: return null
	if value == null:
		this.function.error("%s() has nothing inside it to change." % kind)
		return null

	await Interpreter.step(this)
	match kind:
		"int":
			match typeof(value):
				TYPE_INT: return value
				TYPE_FLOAT: return int(value)
				TYPE_BOOL: return 1 if value else 0
				TYPE_STRING:
					var text := (value as String).strip_edges()
					if text.is_valid_int():
						return text.to_int()
					var why := " It has a decimal point, so use float()." if text.is_valid_float() else ""
					this.function.error("int() can't turn %s into a whole number.%s" % [Core.to_python_repr(value), why])
					return null
		"float":
			match typeof(value):
				TYPE_INT, TYPE_FLOAT: return float(value)
				TYPE_BOOL: return 1.0 if value else 0.0
				TYPE_STRING:
					var text := (value as String).strip_edges()
					if text.is_valid_float() or text.is_valid_int():
						return text.to_float()
					this.function.error("float() can't turn %s into a number." % Core.to_python_repr(value))
					return null
		"str":
			return Core.to_python_literal(value)
		_:
			this.function.error("'%s' isn't a type this block knows." % kind)
			return null
	this.function.error("%s() can't change %s." % [kind, Core.to_python_repr(value)])
	return null
