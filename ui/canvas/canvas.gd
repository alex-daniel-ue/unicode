class_name Canvas
extends ColorRect


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return bool(
		data is Block and
		data.stackable
	)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	# data is Block && data.stackable
	add_child(data)
	data.position = at_position - data.get_center()
