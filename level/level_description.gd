class_name LevelDescription
extends Node


## Populated by take_content(). Puzzle reparents these into the side panel, so
## after that point this node is childless and get_raw() has to walk the handed-
## over Controls instead of get_children().
var content: Array[Control]


func _enter_tree() -> void:
	_prepare(self, false)

func take_content() -> Array[Control]:
	content.clear()
	
	for child in get_children():
		if child is Control:
			_prepare(child, true)
			child.visible = true
			content.append(child as Control)
	
	return content

func get_raw() -> String:
	var lines: PackedStringArray
	for node in _roots():
		lines.append_array(_collect_raw(node))
	return "\n".join(lines)

## Mirrors _prepare()'s walk. Without the recursion, wrapping instruction copy in
## a VBox or HBox for layout silently removes it from the assistant's context.
func _collect_raw(node: Node) -> PackedStringArray:
	var lines: PackedStringArray
	
	if node is CanvasItem and not (node as CanvasItem).visible:
		return lines
	
	# Leaves. A Block renders its own parameter blocks into its raw text, so
	# don't descend into one.
	if node is Block:
		lines.append((node as Block).text.get_raw())
		return lines
	if node is Label:
		lines.append((node as Label).text)
		return lines
	if node is RichTextLabel:
		lines.append((node as RichTextLabel).get_parsed_text())
		return lines
	
	for child in node.get_children():
		lines.append_array(_collect_raw(child))
	return lines

func _roots() -> Array[Node]:
	var roots: Array[Node]
	for node in content:
		if is_instance_valid(node):
			roots.append(node)
	return roots if not roots.is_empty() else get_children()

func _prepare(node: Node, sanitize: bool) -> void:
	if node is Block:
		var block := node as Block
		block.display = true
		if sanitize:
			block.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.focus_mode = Control.FOCUS_NONE
	
	for child in node.get_children():
		_prepare(child, sanitize)
