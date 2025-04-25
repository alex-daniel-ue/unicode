class_name Block
extends Control


var original_parent: Node


#region === DRAG & DROP =======================================================
func _get_center_drag_pos() -> Vector2:
	return -0.5 * size

func _get_drag_data(at_position: Vector2) -> Variant:
	var preview := Control.new()
	set_drag_preview(preview)
	
	# Creates a dummy for drag & drop visuals
	var dummy := duplicate(0)  # Need only appearance, no need for functionality
	preview.add_child(dummy)
	dummy.position = _get_center_drag_pos()
	
	# Store original parent in case of drag & drop failure
	original_parent = get_parent()
	original_parent.remove_child(self)
	
	return self
#endregion
