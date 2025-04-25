class_name NestedBlock
extends Block


var preview_node: Block
var initial_min_size: Vector2

@onready var _texture := $NinePatchRect
@onready var _upper_lip := $UpperLip
@onready var _lower_lip := $LowerLip
@onready var _mouth: VBoxContainer = $Mouth


func _ready() -> void:
	initial_min_size = custom_minimum_size
	_upper_lip.custom_minimum_size.y = _texture.patch_margin_top
	_lower_lip.custom_minimum_size.y = _texture.patch_margin_bottom
	
	_update_height()
	_mouth.size = Vector2.ZERO
	_mouth.minimum_size_changed.connect(_update_height)

func _update_height() -> void:
	custom_minimum_size.y = _mouth.size.y + _texture.custom_minimum_size.y
	custom_minimum_size.y = max(custom_minimum_size.y, initial_min_size.y)
	
	size.y = custom_minimum_size.y



## Overrides [method Block._get_center_drag_pos].
func _get_center_drag_pos() -> Vector2:
	return -0.5 * Vector2(size.x, _texture.patch_margin_top)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Block

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var hovered := get_viewport().gui_get_hovered_control()
	var hovered_block := hovered.owner
	
	# Calculate the center y-coordinate and if data was dropped above it
	prints(hovered, hovered_block)
	var block_center: float = hovered_block.global_position.y + hovered_block.size.y * 0.5
	at_position += global_position
	var is_above_block := at_position.y < block_center
	
	if hovered_block is NestedBlock:
		var parent_container := hovered_block.get_parent()
		var parent_block := parent_container.owner
		
		# If this NestedBlock is nested inside another NestedBlock
		if parent_block is NestedBlock:
			var hovered_center := hovered.global_position.y + hovered.size.y * 0.5
			var is_above_hovered := at_position.y < hovered_center
			
			var hover_idx := parent_container.get_children().find(self)
			
			# Put data in parent NestedBlock instead
			if hovered == _upper_lip and is_above_hovered:
				parent_container.insert_child(hover_idx, data)
				return
			elif hovered == _lower_lip and not is_above_hovered:
				parent_container.insert_child(hover_idx + 1, data)
				return
		
		_mouth.insert_child(0 if is_above_block else -1, data)
	
	elif hovered_block is Statement:
		var hover_idx := _mouth.get_children().find(hovered_block)
		if not is_above_block:
			hover_idx += 1
		_mouth.insert_child(hover_idx, data)
