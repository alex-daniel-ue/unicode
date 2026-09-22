class_name ArrayFunctions
extends Node

## text: create empty list
func _create_empty_list(this: Block) -> Variant:
	await Interpreter.step(this)
	return []

## text: append {item} to {list_var}
func _append(this: Block) -> void:
	var args := await this.function.eval_args([
		this.function.Argument.VARIANT,
		this.function.Argument.STRING_NAME
	])
	if Interpreter.interrupted: return
	
	var item: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return
	var list_name := args[1] as StringName
	
	var target_list: Variant = Interpreter.read_var(list_name)
	if typeof(target_list) != TYPE_ARRAY:
		this.function.error("Cannot append to '%s': it is %s, not a list." % [list_name, Core.get_type_string(target_list)])
		return
	
	(target_list as Array).append(item)
	Interpreter.assign_var(list_name, target_list)
	await Interpreter.step(this)

## text: item {index} of {list}
func _get_item(this: Block) -> Variant:
	var args := await this.function.eval_args([
		this.function.Argument.VARIANT,
		this.function.Argument.VARIANT
	])
	if Interpreter.interrupted: return null
	
	var idx_raw: Variant = this.function.unwrap(args[0])
	var list_raw: Variant = this.function.unwrap(args[1])
	if Interpreter.interrupted: return null
	
	if typeof(idx_raw) != TYPE_INT:
		this.function.error("List index must be an integer, not %s." % Core.get_type_string(idx_raw))
		return null
	
	if typeof(list_raw) != TYPE_ARRAY:
		this.function.error("Cannot index %s: expected a list." % Core.get_type_string(list_raw))
		return null
	
	var list := list_raw as Array
	var idx := idx_raw as int
	if idx < 0 or idx >= list.size():
		this.function.error("List index out of range: index %d, but length is %d." % [idx, list.size()])
		return null
	
	await Interpreter.step(this)
	return list[idx]

## text: set item {index} of {list_var} to {value}
func _set_item(this: Block) -> void:
	var args := await this.function.eval_args([
		this.function.Argument.VARIANT,
		this.function.Argument.STRING_NAME,
		this.function.Argument.VARIANT
	])
	if Interpreter.interrupted: return
	
	var idx_raw: Variant = this.function.unwrap(args[0])
	var list_name := args[1] as StringName
	var value: Variant = this.function.unwrap(args[2])
	if Interpreter.interrupted: return
	
	if typeof(idx_raw) != TYPE_INT:
		this.function.error("List index must be an integer, not %s." % Core.get_type_string(idx_raw))
		return
	
	var target_list: Variant = Interpreter.read_var(list_name)
	if typeof(target_list) != TYPE_ARRAY:
		this.function.error("Cannot set item on '%s': it is not a list." % list_name)
		return
	
	var list := target_list as Array
	var idx := idx_raw as int
	if idx < 0 or idx >= list.size():
		this.function.error("List index out of range: index %d, but length is %d." % [idx, list.size()])
		return
	
	list[idx] = value
	Interpreter.assign_var(list_name, list)
	await Interpreter.step(this)

## text: length of {list}
func _length(this: Block) -> Variant:
	var args := await this.function.eval_args([this.function.Argument.VARIANT])
	if Interpreter.interrupted: return null
	
	var list_raw: Variant = this.function.unwrap(args[0])
	if Interpreter.interrupted: return null
	
	if typeof(list_raw) != TYPE_ARRAY:
		this.function.error("Cannot get length of %s: expected a list." % Core.get_type_string(list_raw))
		return null
	
	await Interpreter.step(this)
	return (list_raw as Array).size()

## text: pop from {list_var}
func _pop(this: Block) -> Variant:
	var args := await this.function.eval_args([this.function.Argument.STRING_NAME])
	if Interpreter.interrupted: return null
	
	var list_name := args[0] as StringName
	var target_list: Variant = Interpreter.read_var(list_name)
	if typeof(target_list) != TYPE_ARRAY:
		this.function.error("Cannot pop from '%s': not a list." % list_name)
		return null
	
	var list := target_list as Array
	if list.is_empty():
		this.function.error("Cannot pop from an empty list.")
		return null
	
	var val: Variant = list.pop_back()
	Interpreter.assign_var(list_name, list)
	await Interpreter.step(this)
	return val
