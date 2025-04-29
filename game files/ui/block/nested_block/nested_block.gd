class_name NestedBlock
extends Block


var initial_min_size: Vector2

@onready var _lower_lip := $LowerLip
@onready var _mouth: VBoxContainer = $Mouth


func _ready() -> void:
	initial_min_size = custom_minimum_size
	_upper_lip.custom_minimum_size.y = _texture.patch_margin_top
	_lower_lip.custom_minimum_size.y = _texture.patch_margin_bottom
	_mouth.position = Vector2(_texture.patch_margin_left, _texture.patch_margin_top)
	
	_update_height()
	# VBoxContainer works really weirdly, sometimes its size doesn't reset to
	# zero when it has no children
	_mouth.size = Vector2.ZERO
	
	# minimum_size_changed must be connected AFTER setting size to Vector2.ZERO
	_mouth.minimum_size_changed.connect(_update_height)


func _update_height() -> void:
	custom_minimum_size.y = _mouth.size.y + _texture.custom_minimum_size.y
	custom_minimum_size.y = max(custom_minimum_size.y, initial_min_size.y)
	#size.y = custom_minimum_size.y


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Block and not is_infinite


## This function is called when it is [b]dropped onto[/b], not being dropped.
func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _is_drop_preview:
		var parent_container := get_parent()
		parent_container.insert_child(get_index(), data)
		return
	
	var hovered := get_viewport().gui_get_hovered_control()
	var block := hovered.owner
	
	# Calculate the center y-coordinate and if data was dropped above it
	var center_y: float = block.global_position.y + block.size.y * 0.5
	at_position += global_position
	var above_block := at_position.y < center_y
	
	if block is NestedBlock:
		var container := block.get_parent()
		
		if container.owner is NestedBlock:
			center_y = hovered.global_position.y + hovered.size.y * 0.5
			var above_hovered := at_position.y < center_y
			
			var idx := get_index()
			if hovered == (_upper_lip if above_hovered else _lower_lip):
				if not above_hovered:
					idx += 1
				container.insert_child(idx, data)
				return
		
		_mouth.insert_child(0 if above_block else -1, data)
		return
	
	elif block is Statement:
		var idx := _mouth.get_children().find(block)
		if not above_block:
			idx += 1
		_mouth.insert_child(idx, data)
