extends ColorRect


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Block

func _drop_data(at_position: Vector2, data: Variant) -> void:
	data.position = at_position + data.get_center()
	add_child(data)
