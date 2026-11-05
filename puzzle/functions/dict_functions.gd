class_name DictFunctions
extends Node

## The dictionary blocks. Like the list blocks, which board a block touches
## depends on what's plugged into it, so these resolve their dictionary
## argument and hand the work to that DictEntity, which animates, paces itself
## and raises any error. `in`, Length Of and For Each take a dictionary too
## (list_functions.gd, control_flow.gd), as Python's do.


## text: <the dictionary's name>
func _dict_reporter(this: Block) -> Variant:
	var dict_name := this.data.func_entity_name
	var board := DictEntity.find(dict_name)
	if board == null:
		this.function.error("There's no dictionary named '%s' here." % dict_name)
		return null
	return board

## text: {dict} [ {key} ]
func _get_value(this: Block) -> Variant:
	var args := await this.function.eval_args([this.function.Argument.VARIANT, this.function.Argument.VARIANT])
	if Interpreter.interrupted: return null
	var board := resolve(this, args[0])
	if board == null: return null
	var key: Variant = this.function.unwrap(args[1])
	if Interpreter.interrupted: return null
	return await board.read(key, this)

## text: set {dict} [ {key} ] to {value}
func _set_value(this: Block) -> void:
	var args := await this.function.eval_args([this.function.Argument.VARIANT, this.function.Argument.VARIANT, this.function.Argument.VARIANT])
	if Interpreter.interrupted: return
	var board := resolve(this, args[0])
	if board == null: return
	var key: Variant = this.function.unwrap(args[1])
	if Interpreter.interrupted: return
	var value: Variant = this.function.unwrap(args[2])
	if Interpreter.interrupted: return
	await board.write(key, value, this)

## text: remove {key} from {dict}
func _remove_key(this: Block) -> void:
	var args := await this.function.eval_args([this.function.Argument.VARIANT, this.function.Argument.VARIANT])
	if Interpreter.interrupted: return
	var key: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return
	var board := resolve(this, args[1])
	if board == null: return
	await board.remove(key, this)

## The DictEntity an argument names, or null after raising the error.
static func resolve(this: Block, raw: Variant) -> DictEntity:
	var value: Variant = this.function.unwrap(raw)
	if Interpreter.interrupted:
		return null
	if value is DictEntity:
		return value
	var block_name := this.data.display_name() if this.data != null else "this"
	if value == null:
		this.function.error("The %s block needs a dictionary. Drop the name block of a dictionary into its empty slot." % block_name)
	else:
		this.function.error("The %s block needs a dictionary, but it got %s." % [block_name, Core.to_python_repr(value)])
	return null
