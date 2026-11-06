class_name NestedBlock
extends Block


const UPPER_LIP_NAME := &"UpperLip"
const LOWER_LIP_NAME := &"LowerLip"

@export_group("Children")
@export var upper_lip: Control
@export var mouth: VBoxContainer
@export var lower_lip: Control


func _ready() -> void:
	super()
	upper_lip.resized.connect(_on_upper_lip_resized)
	_on_upper_lip_resized()

func _can_drop_data(_at_position: Vector2, block: Variant) -> bool:
	return (
		not data.toolbox and
		block is Block and
		block.data.top_notch
	)

## On the loop as it's drawn: its top, its bottom, and the spine down its left
## side. Not the inside of the mouth, nor the box's corner beside a top that is
## narrower than what's in the mouth: there the canvas shows through.
func shows_at(point: Vector2) -> bool:
	if upper_lip.get_global_rect().has_point(point) or lower_lip.get_global_rect().has_point(point):
		return true
	var body := mouth.get_parent() as Control
	var spine := body.get_global_rect()
	spine.size.x = body.get_theme_stylebox(&"panel").get_margin(SIDE_LEFT) * body.get_global_transform().get_scale().x
	return spine.has_point(point)

func within_mouth(global_pos: Vector2) -> bool:
	var m_rect := mouth.get_global_rect()
	var l_rect := lower_lip.get_global_rect()
	var clipped_width := l_rect.end.x - m_rect.position.x
	
	var begin := Vector2(l_rect.position.x, m_rect.position.y)
	var end := Vector2(clipped_width, m_rect.position.y)
	
	var drop_zone := Rect2(begin, end)
	return drop_zone.has_point(global_pos)

func get_all_blocks(include_self := false) -> Array[Block]:
	var result := super(include_self)
	for child in mouth.get_children():
		if child is Block:
			result.append_array(child.get_all_blocks(true))
	return result

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

func _on_upper_lip_resized() -> void:
	lower_lip.custom_minimum_size.x = upper_lip.size.x
