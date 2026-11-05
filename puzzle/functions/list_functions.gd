class_name ListFunctions
extends Node
## What the list blocks do: a list's name block, Index Of, Set Index, Length Of,
## Append and In. Which list a block touches depends on what's plugged into it,
## so these are ordinary functions rather than the list's own methods: each
## resolves its list argument (BlockFunctionComponent.resolve()) and hands the
## work to that ListEntity, which animates, paces itself and raises any error in
## Python's terms.
##
## Length Of and In take a dictionary, a file or text too, as Python's len()
## and `in` do.


## <the list's name>
func _reporter(this: Block) -> Variant:
	var list_name := this.data.func_entity_name
	var list := ListEntity.find(list_name)
	if list == null:
		this.function.error(ListEntity.missing_message(list_name))
		return null
	list.flash_name()
	return list


## index {index} of {list}
func _item(this: Block) -> Variant:
	var args := await this.function.eval_args([
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT,
	])
	if Interpreter.interrupted: return null

	var index: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return null
	var list := this.function.resolve(args[1], ListEntity, "a list") as ListEntity
	if list == null: return null

	return await list.read(index, this)


## set index {index} of {list} to {value}
func _set_item(this: Block) -> void:
	var args := await this.function.eval_args([
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT,
	])
	if Interpreter.interrupted: return

	var index: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return
	var list := this.function.resolve(args[1], ListEntity, "a list") as ListEntity
	if list == null: return
	var value: Variant = this.function.unwrap(args[2])
	if Interpreter.interrupted: return

	await list.write(index, value, this)


## length of {list}
func _length(this: Block) -> Variant:
	var args := await this.function.eval_args([this.function.Argument.VARIANT])
	if Interpreter.interrupted: return null

	# len() of a dictionary counts its keys, of a file its lines, and of text its
	# characters.
	var target: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return null
	if target is DictEntity:
		return await (target as DictEntity).size(this)
	if target is FileEntity:
		return await (target as FileEntity).size(this)
	if typeof(target) == TYPE_STRING:
		await Interpreter.step(this)
		return (target as String).length()
	var list := this.function.resolve(args[0], ListEntity, "a list") as ListEntity
	if list == null: return null

	return await list.size(this)


## append {value} to {list}
func _append(this: Block) -> void:
	var args := await this.function.eval_args([
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT,
	])
	if Interpreter.interrupted: return

	var value: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return
	var list := this.function.resolve(args[1], ListEntity, "a list") as ListEntity
	if list == null: return

	await list.append_value(value, this)


## {value} in {list}
func _contains(this: Block) -> Variant:
	var args := await this.function.eval_args([
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT,
	])
	if Interpreter.interrupted: return null

	var value: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return null
	# `in` looks among a dictionary's keys, and inside text for a piece of it,
	# as Python's does.
	var target: Variant = this.function.unwrap(args[1])
	if Interpreter.interrupted: return null
	if target is DictEntity:
		return await (target as DictEntity).has(value, this)
	if typeof(target) == TYPE_STRING:
		if typeof(value) != TYPE_STRING:
			this.function.error("Only text can be looked for inside text, but this looks for %s." % Core.to_python_repr(value))
			return null
		await Interpreter.step(this)
		return (target as String).contains(value)
	var list := this.function.resolve(args[1], ListEntity, "a list") as ListEntity
	if list == null: return null

	return await list.contains(value, this)
