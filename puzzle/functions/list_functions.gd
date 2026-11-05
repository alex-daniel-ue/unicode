class_name ListFunctions
extends Node

## The list blocks. Which list a block touches depends on what's plugged into
## it, so these are ordinary functions rather than entity methods: each resolves
## its list argument and hands the work to that ListEntity, which animates, paces
## itself and raises any error in Python's terms.
##
## Replaces the old variable-based array.gd, whose lists were interpreter
## variables with nothing on screen. Its out-of-range wording lives on in
## ListEntity._checked_index().


## text: <the list's name>
func _reporter(this: Block) -> Variant:
	var list_name := this.data.func_entity_name
	var list := ListEntity.find(list_name)
	if list == null:
		this.function.error(ListEntity.missing_message(list_name))
		return null
	list.flash_name()
	return list

## text: item {index} of {list}
func _item(this: Block) -> Variant:
	var args := await this.function.eval_args([
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT,
	])
	if Interpreter.interrupted: return null

	var index: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return null
	var list := resolve(this, args[1], "index of")
	if list == null: return null

	return await list.read(index, this)

## text: set item {index} of {list} to {value}
func _set_item(this: Block) -> void:
	var args := await this.function.eval_args([
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT,
	])
	if Interpreter.interrupted: return

	var index: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return
	var list := resolve(this, args[1], "set index")
	if list == null: return
	var value: Variant = this.function.unwrap(args[2])
	if Interpreter.interrupted: return

	await list.write(index, value, this)

## text: length of {list}
func _length(this: Block) -> Variant:
	var args := await this.function.eval_args([this.function.Argument.VARIANT])
	if Interpreter.interrupted: return null

	# len() of a dictionary counts its keys, and of text its characters.
	var target: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return null
	if target is DictEntity:
		return await (target as DictEntity).size(this)
	if target is FileEntity:
		return await (target as FileEntity).size(this)
	if typeof(target) == TYPE_STRING:
		await Interpreter.step(this)
		return (target as String).length()
	var list := resolve(this, args[0], "length of")
	if list == null: return null

	return await list.size(this)

## text: append {value} to {list}
func _append(this: Block) -> void:
	var args := await this.function.eval_args([
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT,
	])
	if Interpreter.interrupted: return

	var value: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return
	var list := resolve(this, args[1], "append")
	if list == null: return

	await list.append_value(value, this)

## text: {value} in {list}
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
	var list := resolve(this, args[1], "in")
	if list == null: return null

	return await list.contains(value, this)


## The ListEntity an argument names, or null after raising the error. A list's
## name block arrives as the entity itself; a typed-in name arrives as a
## StringName, which unwrap() resolves to a variable first and a list second,
## the way Python looks a name up.
static func resolve(this: Block, raw: Variant, what: String) -> ListEntity:
	var value: Variant = this.function.unwrap(raw)
	if Interpreter.interrupted:
		return null
	if value is ListEntity:
		return value
	# Named by the block's name, as students know it, not its text.
	var block_name := this.data.display_name() if this.data != null else what
	if value == null:
		this.function.error("The %s block needs a list. Drop the name block of a list into its empty slot." % block_name)
	else:
		this.function.error("The %s block needs a list, but it got %s." % [block_name, Core.to_python_repr(value)])
	return null
