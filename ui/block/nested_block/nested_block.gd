@tool
class_name NestedBlock
extends Block


@export var mouth: VBoxContainer
@export var lower_lip: Control


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return bool(
		not self.toolbox and
		data is Block and
		data.stackable
	)

func within_mouth(global_pos: Vector2) -> bool:
	var lower_lip_top_right := lower_lip.global_position + Vector2(lower_lip.size.x, 0)
	var _size := lower_lip_top_right - mouth.global_position
	return Rect2(mouth.global_position, _size).has_point(global_pos)

func _on_mouth_resized() -> void:
	await get_tree().process_frame
	size = Vector2.ZERO
