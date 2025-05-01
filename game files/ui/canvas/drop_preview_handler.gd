extends Control


## Radius around center
const DROP_PREVIEW_DEADZONE_PERCENT := 0.5
const DROP_PREVIEW_ALPHA := 0.4

var current_data: Block

var drop_preview: Control
var drop_preview_container: Control
var drop_preview_idx: int
var drop_preview_deadzone: float
var in_deadzone := false

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
				
				# Update stored container and index
				drop_preview_container = this_container
				drop_preview_idx = this_idx
			
			# If only the index has changed
			elif this_idx != drop_preview_idx:
				# Move to and store the new index
				drop_preview_container.move_child(drop_preview, this_idx)
				drop_preview_idx = this_idx
		
		# If previewing nothing, but recently previewed
		elif drop_preview_container:
			drop_preview_container.remove_child(drop_preview)
			drop_preview_container = null

func get_preview_container() -> VBoxContainer:
	var control := get_viewport().gui_get_hovered_control()
	if not control:  # If hovering over nothing
		return null
	
	var block := control.owner
	if not block is Block:  # If hovering over non-Block
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
				return parent_block.mouth
	
	if block is NestedBlock:
		if block._can_drop_data(Vector2.ZERO, Block.new()):
			if block.is_drop_preview:
				return drop_preview_container
			return block.mouth
	
	return null

func get_preview_idx(mouth: VBoxContainer) -> int:
	var mouse := get_global_mouse_position()
	var top := mouth.global_position.y
	
	# When vertically outside mouth
	if mouse.y < top or mouse.y > top + mouth.size.y:
		var center := top + mouth.size.y * 0.5
		return 0 if mouse.y < center else -1
	
	for child: Block in mouth.get_children():
		var idx := child.get_index()
		top = child.global_position.y
		var height := child.size.y
		
		# Skip if not within vertical bounds
		if mouse.y < top or mouse.y > top + height:
			continue
		
		# Immediately take over when hovering over non-preview blocks
		# NestedBlocks have special cases (?)
		if not child.is_drop_preview and not child is NestedBlock:
			in_deadzone = false
			return idx
		
		var center := top + height * 0.5
		var dy := mouse.y - center
		
		if not in_deadzone and abs(dy) <= drop_preview_deadzone:
			in_deadzone = true
			Util.log("Turned deadzone on.")
			return idx
		
		if in_deadzone and abs(dy) > drop_preview_deadzone:
			in_deadzone = false
			if dy < 0:  # Above center
				Util.log("Above deadzone.")
				return max(0, idx-1)
			else:  # Below center
				Util.log("Below deadzone.")
				return idx+1
		
		if in_deadzone:
			Util.log("Within deadzone.")
			return idx
	
	# Fallback to previously stored index
	in_deadzone = false
	Util.log("Oh no. %d")
	return this_idx

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			current_data = get_viewport().gui_get_drag_data()
			
			# clone(), not duplicate(0), because children don't have owners
			drop_preview = current_data.clone()
			drop_preview.name = "DropPreview"
			drop_preview.is_drop_preview = true
			drop_preview.modulate.a = DROP_PREVIEW_ALPHA
			
			drop_preview_deadzone = drop_preview.size.y * DROP_PREVIEW_DEADZONE_PERCENT / 2.0
		NOTIFICATION_DRAG_END:
			if drop_preview_container:
				# Node.replace_by does NOT delete/remove the original Node
				drop_preview_container.insert_child(drop_preview_idx, current_data)
			
			# Delete the node and remove references
			drop_preview.queue_free()
			drop_preview = null
			drop_preview_container = null
			
			if not get_viewport().gui_is_drag_successful():
				if not current_data.origin_parent:
					current_data.queue_free()
				else:
					current_data.origin_parent.add_child(current_data)
					current_data.origin_parent.move_child(current_data, current_data.origin_idx)
