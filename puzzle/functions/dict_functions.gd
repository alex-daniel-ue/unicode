class_name DictFunctions
extends Node
## What the dictionary blocks do: a dictionary's name block, `d[key]`, Set Key
## and Remove Key. Like the list blocks, which board a block touches depends on
## what's plugged into it, so these resolve their dictionary argument and hand
## the work to that DictEntity, which animates, paces itself and raises any
## error. In, Length Of and For Each take a dictionary too (list_functions.gd,
## control_flow.gd), as Python's do.


## <the dictionary's name>
func _dict_reporter(this: Block) -> Variant:
	var dict_name := this.data.func_entity_name
	var board := DictEntity.find(dict_name)
	if board == null:
		this.function.error("There's no dictionary named '%s' here." % dict_name)
		return null
	return board


## {dict} [ {key} ]
func _get_value(this: Block) -> Variant:
	var args := await this.function.eval_args([this.function.Argument.VARIANT, this.function.Argument.VARIANT])
	if Interpreter.interrupted: return null
	var board := this.function.resolve(args[0], DictEntity, "a dictionary") as DictEntity
	if board == null: return null
	var key: Variant = this.function.unwrap(args[1])
	if Interpreter.interrupted: return null
	return await board.read(key, this)


## set {dict} [ {key} ] to {value}
func _set_value(this: Block) -> void:
	var args := await this.function.eval_args([this.function.Argument.VARIANT, this.function.Argument.VARIANT, this.function.Argument.VARIANT])
	if Interpreter.interrupted: return
	var board := this.function.resolve(args[0], DictEntity, "a dictionary") as DictEntity
	if board == null: return
	var key: Variant = this.function.unwrap(args[1])
	if Interpreter.interrupted: return
	var value: Variant = this.function.unwrap(args[2])
	if Interpreter.interrupted: return
	await board.write(key, value, this)


## remove {key} from {dict}
func _remove_key(this: Block) -> void:
	var args := await this.function.eval_args([this.function.Argument.VARIANT, this.function.Argument.VARIANT])
	if Interpreter.interrupted: return
	var key: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return
	var board := this.function.resolve(args[1], DictEntity, "a dictionary") as DictEntity
	if board == null: return
	await board.remove(key, this)
