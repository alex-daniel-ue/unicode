class_name Serializer
extends Node


@onready var canvas: ColorRect = get_parent()


static func count_solid_blocks(yaml: String, skip_locked := true) -> int:
	var lines := yaml.split("\n")
	
	# indent → is this section one whose items count
	var sections: Array[Vector2i] = []   # x = key indent, y = 1 when it is `children:`
	var total := 0
	
	for i in lines.size():
		var line := lines[i]
		var body := line.strip_edges(true, false)
		if body.is_empty() or body.begins_with("#"):
			continue
		var indent := line.length() - body.length()
		
		while not sections.is_empty() and indent <= sections.back().x:
			sections.pop_back()
		
		if body.begins_with("- block:"):
			var counts: bool = not sections.is_empty() and sections.back().y == 1
			if counts and not (skip_locked and _item_is_locked(lines, i, indent)):
				total += 1
			continue
		
		if body.begins_with("children:"):
			sections.append(Vector2i(indent, 1))
		elif body.begins_with("parameters:") or body.begins_with("detached:"):
			sections.append(Vector2i(indent, 0))
	
	return total

static func _item_is_locked(lines: PackedStringArray, item_index: int, item_indent: int) -> bool:
	for i in range(item_index + 1, lines.size()):
		var line := lines[i]
		var body := line.strip_edges(true, false)
		if body.is_empty():
			continue
		var indent := line.length() - body.length()
		if indent <= item_indent:
			return false
		if indent == item_indent + 2 and body == "locked: true":
			return true
	return false


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
	lines.append("# locked: true marks blocks the level placed; the student can't delete them")
	
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
	
	if not block.data.trashable and not block.data.syntax.is_empty():
		lines.append("  locked: true")
	
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
		return ("- " + _serialize_scalar(block)).indent("    ")
	return ("- " + _serialize_block(block)).indent("    ")
 
 
func _serialize_scalar(block: Block) -> String:
	var raw := block.text.get_raw()
	if block.data.value.enum_flag:
		return raw  # a dropdown choice: <, and, left, True
	var value: Variant = block.typecast(raw)
	match typeof(value):
		TYPE_NIL:
			return "null" if raw.strip_edges().is_empty() else '"%s"  # not a readable value' % raw.c_escape()
		TYPE_STRING:
			return '"%s"' % String(value).c_escape()
		_:
			return raw  # variable names, numbers, booleans


func _serialize_value(value_str: String) -> String:
	if value_str.is_empty(): return "null"
	if value_str in ["true", "false"] or value_str.is_valid_int() or value_str.is_valid_float():
		return value_str
	
	return '"' + value_str.replace('"', '\\"') + '"'
