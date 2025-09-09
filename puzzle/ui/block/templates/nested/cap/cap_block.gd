class_name CapBlock
extends NestedBlock


func within_mouth(global_pos: Vector2) -> bool:
	return Rect2(mouth.global_position, mouth.size).has_point(global_pos)

func _on_resized() -> void:
	lower_lip.custom_minimum_size.x = upper_lip.size.x
