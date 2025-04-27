extends ColorRect


var _current_drag_data: Variant

const PREVIEW_ALPHA := 0.4
var _preview_block: Control
var _stored_preview_container: Control
var _stored_preview_idx: int
var _this_container: Control
var _this_idx: int


func _process(_delta: float) -> void:
	if get_viewport().gui_is_dragging():
		_this_container = _get_preview_container()
		
		# If there's a valid preview spot
		if _this_container != null:
			_this_idx = _get_preview_idx(_this_container)
			
			# If the preview container has changed
			if _this_container != _stored_preview_container:
				# If there was a previous preview container 
				if _stored_preview_container != null:
					_stored_preview_container.remove_child(_preview_block)
				
				_this_container.insert_child(_this_idx, _preview_block)
				
				# Update stored container and index
				_stored_preview_container = _this_container
				_stored_preview_idx = _this_idx
			
			# If only the index has changed
			elif _this_idx != _stored_preview_idx:
				# Move to and store the new index 
				_stored_preview_container.move_child(_preview_block, _this_idx)
				_stored_preview_idx = _this_idx
		
		# If previewing nothing, but recently previewed
		elif _stored_preview_container != null:
			_stored_preview_container.remove_child(_preview_block)
			_stored_preview_container = null

## Hopefully always returns a [VBoxContainer].
func _get_preview_container() -> Control:
	var control := get_viewport().gui_get_hovered_control()
	# If hovering over nothing 
	if control == null:
		return null
	
	var block := control.owner
	# If hovering over non-Block
	if not block is Block:
		return null
	
	var container := block.get_parent()
	var parent_block := container.owner
	
	if parent_block is NestedBlock:
		if block is Statement:
			return container
		if parent_block is NestedBlock:
			var center_y := control.global_position.y + control.size.y * 0.5
			var is_above := get_global_mouse_position().y < center_y
			
			if control.name == ("UpperLip" if is_above else "LowerLip"):
				return parent_block._mouth
	
	if block is NestedBlock and block._can_drop_data(Vector2.ZERO, Block.new()):
		if block._is_preview:
			return _stored_preview_container
		return block._mouth
	
	return null

func _get_preview_idx(container: Control) -> int:
	var mouse_y := get_global_mouse_position().y
	var top := container.global_position.y
	var height := container.size.y
	
	# If mouse is is hovering in Mouth
	if mouse_y >= top and mouse_y <= top + height:
		var child_bottom := top
		var child: Control
		for idx in range(container.get_child_count()):
			child = container.get_child(idx)
			child_bottom += child.size.y
			
			if mouse_y < child_bottom:
				var child_center_y: float = child_bottom - child.size.y * 0.5
				return idx + (1 if mouse_y > child_center_y else 0)
	
	if mouse_y < (top + height * 0.5):
		return 0
	return -1

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			_current_drag_data = get_viewport().gui_get_drag_data()
			
			_preview_block = _current_drag_data.clone()
			_preview_block._is_preview = true
			_preview_block.modulate.a = PREVIEW_ALPHA
		NOTIFICATION_DRAG_END:
			_preview_block.queue_free()
			_preview_block = null
			_stored_preview_container = null
			
			# On drag & drop failure
			if not get_viewport().gui_is_drag_successful() and _current_drag_data is Block:
				# If block came from block drawer
				if _current_drag_data._original_parent == null:
					_current_drag_data.queue_free()
				else:
					# Return block to where it was
					_current_drag_data._original_parent.add_child(_current_drag_data)
					_current_drag_data._original_parent.move_child(_current_drag_data, _current_drag_data._original_idx)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Block

func _drop_data(at_position: Vector2, data: Variant) -> void:
	data.position = at_position + data._get_center_drag_pos()
	add_child(data)
