class_name NestedBlock
extends Block


const UPPER_LIP_NAME := &"UpperLip"
const LOWER_LIP_NAME := &"LowerLip"

var scope: Dictionary[StringName, Variant]
var depth: int

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

func within_mouth(global_pos: Vector2) -> bool:
	var m_rect := mouth.get_global_rect()
	var l_rect := lower_lip.get_global_rect()
	
	var clipped_width := l_rect.end.x - m_rect.position.x
	var drop_zone := Rect2(m_rect.position, Vector2(clipped_width, m_rect.size.y))
	
	return drop_zone.has_point(global_pos)

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
