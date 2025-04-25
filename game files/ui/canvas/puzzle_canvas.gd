extends ColorRect


var current_dragged_data: Variant


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			current_dragged_data = get_viewport().gui_get_drag_data()
		NOTIFICATION_DRAG_END:
			# On drag & drop failure
			if not get_viewport().gui_is_drag_successful():
				if current_dragged_data is Block:
					# Return block to where it was
					current_dragged_data.original_parent.add_child(current_dragged_data)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Block
func _drop_data(at_position: Vector2, data: Variant) -> void:
	data.position = at_position + data._get_center_drag_pos()
	add_child(data)
