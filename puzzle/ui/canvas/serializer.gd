class_name Serializer
extends Node


@onready var canvas: ColorRect = get_parent()


func yaml_serialize() -> String:
	var begin: CapBlock = null
	var detached: Array[Block]
	
	for child in canvas.get_children():
		if not (child is Block):
			continue
		if begin == null and child is CapBlock and (child as CapBlock).is_type(NestedData.Type.BEGIN):
			begin = child as CapBlock
			continue
		detached.append(child as Block)
	
	var lines: PackedStringArray
	
	if begin == null:
		lines.append("# No 'begin' block found on canvas.")
	else:
		lines.append(_serialize_block(begin))
	
	if not detached.is_empty():
		lines.append("detached:  # loose on the canvas, not part of the program")
		for block in detached:
			lines.append(_serialize_list_item(block))
	
	return "\n".join(lines)


func _serialize_block(block: Block) -> String:
	var lines: PackedStringArray
	
	lines.append("block: " + block.data.name)
	lines.append("  text: " + _serialize_value(block.data.text))
	
	var param_blocks: Array[Block] = block.text.get_blocks()
	if not param_blocks.is_empty():
		lines.append("  parameters:")
		for param in param_blocks:
			lines.append(_serialize_list_item(param))
	
	if block is NestedBlock and not block.get_blocks().is_empty():
		lines.append("  children:")
		for child in block.get_blocks():
			lines.append(_serialize_list_item(child))
	
	return "\n".join(lines)


func _serialize_list_item(block: Block) -> String:
	if block is ValueBlock and not block.data.has_text_blocks():
		var raw_value := block.text.get_raw()
		return "    - " + _serialize_value(raw_value)
	return ("- " + _serialize_block(block)).indent("    ")


func _serialize_value(value_str: String) -> String:
	if value_str.is_empty(): return "null"
	if value_str in ["true", "false"] or value_str.is_valid_int() or value_str.is_valid_float():
		return value_str
	
	return '"' + value_str.replace('"', '\\"') + '"'
