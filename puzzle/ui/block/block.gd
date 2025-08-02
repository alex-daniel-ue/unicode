@tool
class_name Block
extends Control


@export var data: BlockData

@export_group("Children")
@export var text_container: Control

## To detect whether the cursor is hovering over a preview.
var is_drop_preview := false
var drag_preview: Control
var origin_parent: Node
var origin_idx: int


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	# Initialize block text
	if not is_drop_preview:
		data.text_changed.connect(format_text)
		format_text()

func _get_drag_data(_at_position: Vector2) -> Variant:
	# Null for undraggable
	if not data.draggable:
		return null
	
	# Set drag preview Control
	var drag_preview_container := Control.new()
	set_drag_preview(drag_preview_container)
	Utils.drag_preview_container = drag_preview_container
	drag_preview_container.name = "DragPreviewContainer"
	
	drag_preview = duplicate(0)  # No signals/groups/instantiation
	drag_preview_container.add_child(drag_preview)
	drag_preview.position = -get_local_mouse_position()
	
	#region Drag preview animations
	var tween := drag_preview_container.create_tween()
	
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(
		drag_preview, "position",
		size / -2., 0.3
	)
	#endregion
	
	if data.toolbox:
		var copy := clone()
		copy.data = data.duplicate(true)
		copy.data.toolbox = false
		return copy
	
	origin_parent = get_parent()
	origin_idx = get_index()
	origin_parent.remove_child(self)
	
	return self

## Returns null when this doesn't have a parent Block.
func get_parent_block() -> Block:
	return Utils.get_block(get_parent())

func get_block_name() -> String:
	return "%s#%s" % [data.block_name, get_instance_id()]

#region Duplicate fuckery
func clone() -> Block:
	# INFO: Node.duplicate() with these flags copy programmatically-added
	# children, but all nodes have no Node.owner
	var copy: Block = duplicate(DUPLICATE_SCRIPTS | DUPLICATE_SIGNALS)
	
	# Set owners manually, recursively
	_set_block_owner(copy)
	
	copy.name = copy.get_block_name()
	
	return copy

# TODO: Potential optimization: if child is Block, get amt. of children and skip
# ahead that many times?
func _set_block_owner(node: Node) -> void:
	# Skip first node to avoid setting its owner to itself
	for child in Utils.get_children(node).slice(1):
		if child.owner == null:
			child.owner = node
			if child is Block:
				_set_block_owner(child)
#endregion

#region Block text handling
# TODO: A better implementation is to smartly reuse Labels, but eh.
## Rebuilds the block's visual representation by replacing "{}" placeholders with child blocks.
##
## The method:
## 1. Splits `data.text` using "{}" as delimiters
## 2. Clears existing content in `text_container`
## 3. Rebuilds the content as alternating [Label] and [Block] elements:
##    - Text segments become normalized Labels
##    - Placeholders ("{}") are replaced with Blocks from `data.text_block_data`
##
## The resulting structure follows this pattern:
##   [Label: text before first "{}"]
##   [Block: first child from text_block_data]
##   [Label: text after first "{}" before second]
##   [Block: second child block]...
##
## Example: For "Hello {} world" with 1 child block:
##   Creates: [Label "Hello "][Block][Label " world"]
func format_text() -> void:
	if data.text.is_empty():
		data.text = "empty text"
		push_warning(data.text)
	
	var raw_texts := data.text.split("{}")
	if len(raw_texts)-1 != len(data.text_data):
		if len(raw_texts)-1 > len(data.text_data):
			push_error("(%s) Not enough Blocks inside text_data! (%s, %s)" %
				[get_block_name(), len(raw_texts)-1, len(data.text_data)]
			)
			return
		else: push_warning("(%s) Too many Blocks inside text_data.")
	
	# Remove old children
	for child in text_container.get_children():
		text_container.remove_child(child)
		child.queue_free()
	
	# Add first guaranteed label
	var label := Label.new()
	label.text = raw_texts[0].strip_edges()
	if not label.text.is_empty():
		_normalize_label(label)
		text_container.add_child(label)
	
	for idx in range(1, len(raw_texts)):
		var block_data := data.text_data[idx - 1]
		var block := Utils.construct_block(block_data)
		text_container.add_child(block)
		
		label = Label.new()
		label.text = raw_texts[idx].strip_edges()
		if label.text.is_empty():
			continue
		
		_normalize_label(label)
		text_container.add_child(label)

## This method vertically centers the label, since the font itself takes up too
## much height. Centering is achieved by using negative line spacing, which
## effectively restricts block text to a single line.
## (Unless labels are in a VBoxContainer, at which point, the font itself should
## be changed to avoid bloat/complexity.)
func _normalize_label(label: Label) -> void:
	label.theme = theme
	label.theme_type_variation = &"BlockLabel"
	
	# To make use of negative line spacing, to "center" text
	# WARNING: Negative line spacing means being restricted to inline text
	label.text = '\n' + label.text

func get_text() -> String:
	var fmt_values: Array[String]
	for child in get_text_blocks():
		fmt_values.append(child.get_text())
	return data.text.format(fmt_values, "{}")

func get_text_blocks() -> Array[Block]:
	var arr: Array[Block]
	for child in text_container.get_children():
		if child is Block:
			arr.append(child)
	return arr
#endregion
