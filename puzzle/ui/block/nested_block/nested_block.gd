@tool
class_name NestedBlock
extends Block


# Functionality variables
var scope: Dictionary[StringName, Variant]
var depth: int

@export_group("Children")
@export var mouth: VBoxContainer
@export var lower_lip: Control


func _ready() -> void:
	assert(data is NestedBlockData)
	super()

func _can_drop_data(_at_position: Vector2, drop: Variant) -> bool:
	return (
		not data.toolbox and
		drop is Block and
		drop.data.top_notch
	)

# Includes lower_lip in calculation because Mouth can visually gape, but have no
# actual size
func within_mouth(global_pos: Vector2) -> bool:
	var lower_lip_top_right := lower_lip.global_position + Vector2(lower_lip.size.x, 0)
	var _size := lower_lip_top_right - mouth.global_position
	return Rect2(mouth.global_position, _size).has_point(global_pos)

func get_blocks() -> Array[Block]:
	var arr: Array[Block]
	for node in mouth.get_children():
		if node is Block: arr.append(node as Block)
	return arr

func check_type(type: NestedBlockData.Type) -> bool:
	return (data as NestedBlockData).nested_type == type

func _on_mouth_resized() -> void:
	set_deferred("size", Vector2.ZERO)
	# MILD FIXME: Band-aid for container sizing not immediately fitting contents
	if is_inside_tree():
		await get_tree().process_frame
		size = Vector2.ZERO
