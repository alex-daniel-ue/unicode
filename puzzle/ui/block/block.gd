@tool
class_name Block
extends Control


@export var toolbox := false
@export var data: BlockData

@export_group("Children")
@export var text_container: Control

## To detect whether the cursor is hovering over a preview.
var is_drop_preview := false
var drag_preview: Control
var origin_parent: Node
var origin_idx: int


func _ready() -> void:
	# Initialize block text
	data.text_changed.connect.call_deferred(parse_block_text)
	parse_block_text()

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
	
	if toolbox:
		var copy := clone()
		copy.data = data.duplicate(true)
		copy.toolbox = false
		copy.data.text = Utils.random_name()
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
# TODO: Needs improving, haphazard
func parse_block_text() -> void:
	# Remove old labels
	for child in text_container.get_children():
		text_container.remove_child(child)
		child.queue_free()
	
	# Create new label
	# TODO: Add <expression> handling
	var label := Label.new()
	label.text = data.text
	_normalize_label(label)
	
	text_container.add_child(label)

func _normalize_label(label: Label) -> void:
	label.theme = theme
	label.theme_type_variation = &"BlockLabel"
	
	# To make use of negative line spacing, to "center" text
	# WARNING: Negative line spacing means being restricted to inline text
	label.text = '\n' + label.text
#endregion
