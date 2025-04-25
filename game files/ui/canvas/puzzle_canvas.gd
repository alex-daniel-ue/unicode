extends ColorRect


var _current_drag_data: Variant


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			_current_drag_data = get_viewport().gui_get_drag_data()
		NOTIFICATION_DRAG_END:
			# On drag & drop failure
			if not get_viewport().gui_is_drag_successful() and _current_drag_data is Block:
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
