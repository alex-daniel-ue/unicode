extends Control


## Radius around center
const DROP_PREVIEW_ALPHA := 0.4

var current_data: Block

var drop_preview: Control
var drop_preview_container: Control
var drop_preview_idx: int
var upper_threshold: float
var lower_threshold: float

# Drop preview variables that update every frame
var this_container: Control
var this_idx: int


func _process(_delta: float) -> void:
	update_drop_preview()

func update_drop_preview() -> void:
	if get_viewport().gui_is_dragging():
		this_container = get_preview_container()
		
		# If there's a valid drop preview spot
		if this_container:
			this_idx = get_preview_idx(this_container)
			
			# If the preview container has changed
			if this_container != drop_preview_container:
				# If there was a previous container
				if drop_preview_container:
					drop_preview_container.remove_child(drop_preview)
				
				this_container.insert_child(this_idx, drop_preview)
				
				# Update stored container, index, and thresholds
				drop_preview_container = this_container
				drop_preview_idx = this_idx
				
				update_thresholds()
			# If only the index has changed
			elif this_idx != drop_preview_idx:
				# Move to and store the new index
				drop_preview_container.move_child(drop_preview, this_idx)
				drop_preview_idx = this_idx
				
				update_thresholds()
		
		# If previewing nothing, but recently previewed
		elif drop_preview_container:
			drop_preview_container.remove_child(drop_preview)
			drop_preview_container = null

func get_preview_container() -> VBoxContainer:
	var control := get_viewport().gui_get_hovered_control()
	if not control:  # If hovering over nothing
		return null
	
	var block := control.owner
	# If hovering over non-Block or non-stackable Block
	if not (block is Block and block.is_stackable):  
		return null
	
	var container := block.get_parent()
	var parent_block := container.owner
	
	if parent_block is NestedBlock:
		if block is Statement:
			return container
		
		if parent_block is NestedBlock:
			var center_y := control.global_position.y + control.size.y * 0.5
			var is_above := get_global_mouse_position().y < center_y
			
			if control.name == ("UpperLip" if is_above else "LowerLip"):
				return parent_block.body.mouth
	
	if block is NestedBlock:
		if block._can_drop_data(Vector2.ZERO, Block.new()):
			if block.is_drop_preview:
				return drop_preview_container
			return block.body.mouth
	
	return null

func get_preview_idx(mouth: VBoxContainer) -> int:
	assert(mouth.owner is NestedBlock, "Passed VBoxContainer isn't part of NestedBlock.")

	var mouse_y := get_global_mouse_position().y
	var mouth_pos := mouth.global_position
	var mouth_size: Vector2 = mouth.get_parent().get_mouth_size()
	
	if not Util.within(mouse_y, mouth_pos.y, mouth_pos.y + mouth_size.y, true):
		var center_y := mouth_pos.y + mouth_size.y * 0.5
		return 0 if mouse_y < center_y else -1
	
	if mouth.get_child_count() == 0:
		return 0
	
	if drop_preview_container != mouth or mouse_y < upper_threshold or mouse_y > lower_threshold:
		for child: Block in mouth.get_children():
			var top := child.global_position.y
			var height := child.size.y
			if mouse_y <= top or mouse_y > top + height:
				continue
			return child.get_index()
	
	return drop_preview_idx

func update_thresholds() -> void:
	await get_tree().process_frame
	
	upper_threshold = -INF
	if drop_preview.get_index() != 0:
		var upper_block: Block = drop_preview_container.get_child(drop_preview.get_index()-1)
		upper_threshold = upper_block.global_position.y + drop_preview.size.y
	
	lower_threshold = INF
	if not drop_preview_container.get_child(-1).is_drop_preview:
		var lower_block: Block = drop_preview_container.get_child(drop_preview_idx+1)
		lower_threshold = (lower_block.global_position.y + lower_block.size.y) - drop_preview.size.y

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			current_data = get_viewport().gui_get_drag_data()
			
			# clone(), not duplicate(0), because children don't have owners
			drop_preview = current_data.clone()
			drop_preview.name = "DropPreview"
			drop_preview.is_drop_preview = true
			drop_preview.modulate.a = DROP_PREVIEW_ALPHA
			
			drop_preview_idx = -1
		NOTIFICATION_DRAG_END:
			if drop_preview_container:
				# Node.replace_by does NOT delete/remove the original Node
				drop_preview_container.insert_child(drop_preview_idx, current_data)
			
			# Delete the node and remove references
			drop_preview.queue_free()
			drop_preview = null
			drop_preview_container = null
			
			if not get_viewport().gui_is_drag_successful():
				if current_data.origin_parent:
					current_data.origin_parent.add_child(current_data)
					current_data.origin_parent.move_child(current_data, current_data.origin_idx)
				else:
					current_data.queue_free()
