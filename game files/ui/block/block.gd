class_name Block
extends Control


@export var is_infinite := false
@export var block_color := Color.WHITE:
	set(value):
		find_child("NinePatchRect", true, false).self_modulate = value
		block_color = value

## Is used in [Statement], [NestedBlock], and PuzzleCanvas.
@warning_ignore("unused_private_class_variable")
var _is_preview := false
var _original_parent: Node
var _original_idx: int


func clone() -> Block:
	var copy := duplicate(DUPLICATE_GROUPS | DUPLICATE_SCRIPTS | DUPLICATE_SIGNALS)
	for child in Util.get_all_children(copy).slice(1):
		child.owner = copy
	return copy


#region === DRAG & DROP =======================================================
func _get_center_drag_pos() -> Vector2:
	return -0.5 * size

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Control.new()
	set_drag_preview(preview)
	
	# Creates a dummy for drag & drop visuals
	var dummy := duplicate(0)  # Need only appearance, no need for functionality
	preview.add_child(dummy)
	dummy.position = _get_center_drag_pos()
	
	if is_infinite:
		var copy := duplicate()
		copy.is_infinite = false
		
		copy.modulate = Color(0.99,0.99,0.99)
		copy.block_color = Color.from_hsv(randf(), randf_range(0.2, 0.6), randf_range(0.9, 1.0))
		
		return copy
	
	# Store original parent in case of drag & drop failure
	_original_parent = get_parent()
	_original_idx = _original_parent.get_children().find(self)
	
	_original_parent.remove_child(self)
	return self
#endregion ====================================================================
