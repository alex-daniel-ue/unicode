class_name NestedBlock
extends Block


var scope: Dictionary[StringName, Variant]
var depth: int

@export_group("Children")
@export var mouth: VBoxContainer
@export var lower_lip: Control


func _can_drop_data(_at_position: Vector2, block: Variant) -> bool:
	return (
		not data.toolbox and
		block is Block and
		block.data.top_notch
	)

func within_mouth(global_pos: Vector2) -> bool:
	var top_right := lower_lip.global_position
	top_right.x += lower_lip.size.x
	
	var mouth_size := top_right - mouth.global_position
	return Rect2(mouth.global_position, mouth_size).has_point(global_pos)

func get_blocks() -> Array[Block]:
	var arr: Array[Block]
	for node in mouth.get_children():
		if node is Block:
			arr.append(node as Block)
	return arr

func is_type(type: NestedData.Type) -> bool:
	if data.nested.type == NestedData.Type.ELIF:
		return type in [NestedData.Type.IF, NestedData.Type.ELSE]
	return data.nested.type == type
