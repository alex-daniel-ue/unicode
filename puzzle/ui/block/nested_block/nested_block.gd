@tool
class_name NestedBlock
extends Block


@export_group("Children")
@export var mouth: VBoxContainer
@export var lower_lip: Control


func _can_drop_data(_at_position: Vector2, drop: Variant) -> bool:
	return (
		not toolbox and
		drop is Block and
		drop.data.top_notch
	)

# Includes lower_lip in calculation because Mouth can visually gape, but have no
# actual size
func within_mouth(global_pos: Vector2) -> bool:
	var lower_lip_top_right := lower_lip.global_position + Vector2(lower_lip.size.x, 0)
	var _size := lower_lip_top_right - mouth.global_position
	return Rect2(mouth.global_position, _size).has_point(global_pos)

func _get_block_name() -> String: return "NestedBlock"

func _on_mouth_resized() -> void:
	set_deferred("size", Vector2.ZERO)
