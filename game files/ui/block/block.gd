class_name Block
extends Control


@export var is_infinite := false
@export var block_color := Color.WHITE:
	set(value):
		var children := get_children()
		const NINEPATCHRECT_IDX := 0
		children[0].self_modulate = value
		block_color = value

var _original_parent: Node
var _original_idx: int


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
		
		# FIXME: Bad ad hoc code; find a way to initialize _texture without
		# the NestedBlock entering the SceneTree.
		var children := copy.get_children()
		const NINEPATCHRECT_IDX := 0
		if copy is NestedBlock:
			copy._texture = children[NINEPATCHRECT_IDX]
		
		copy.modulate = Color(0.99,0.99,0.99)
		copy.block_color = Color.from_hsv(randf(), randf_range(0.2, 0.6), randf_range(0.9, 1.0))
		copy.is_infinite = false
		
		return copy
	
	# Store original parent in case of drag & drop failure
	_original_parent = get_parent()
	_original_idx = _original_parent.get_children().find(self)
	_original_parent.remove_child(self)
	return self
#endregion ====================================================================
