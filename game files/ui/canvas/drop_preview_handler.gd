extends Control


## Radius around center
const DP_DEADBAND_PERCENT := 0.5
const DP_ALPHA := 0.4

var current_data: Block

var drop_preview: Control
var dp_container: Control
var dp_idx: int
var dp_deadband: float
var in_deadband := false

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
			if this_container != dp_container:
				# If there was a previous container
				if dp_container:
					dp_container.remove_child(drop_preview)
				
				this_container.insert_child(this_idx, drop_preview)
				
				# Update stored container and index
				dp_container = this_container
				dp_idx = this_idx
			
			# If only the index has changed
			elif this_idx != dp_idx:
				# Move to and store the new index
				dp_container.move_child(drop_preview, this_idx)
				dp_idx = this_idx
		
		# If previewing nothing, but recently previewed
		elif dp_container:
			dp_container.remove_child(drop_preview)
			dp_container = null

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
			Util.log("container: sibling of statement")
			return container
		
		if parent_block is NestedBlock:
			var center_y := control.global_position.y + control.size.y * 0.5
			var is_above := get_global_mouse_position().y < center_y
			
			if control.name == ("UpperLip" if is_above else "LowerLip"):
				Util.log("container: %s of nested nestedblock" % ("above" if is_above else "below"))
				return parent_block.mouth
	
	if block is NestedBlock:
		if block._can_drop_data(Vector2.ZERO, Block.new()):
			if block.is_drop_preview:
				Util.log("container: inherited nestedblock preview")
				return dp_container
			
			Util.log("container: inside nestedblock")
			return block.mouth
	
	return null

func get_preview_idx(mouth: VBoxContainer) -> int:
	var mouse := get_global_mouse_position()
	var top_left := mouth.global_position
	in_deadband = false
	
	# When vertically outside mouth
	if not Util.point_within(mouse, top_left, top_left + mouth.size, true):
		in_deadband = false
		var center := top_left + mouth.size * 0.5
		Util.log("index: mouse %s mouth" % ("above" if mouse.y < center.y else "below"))
		return 0 if mouse.y < center.y else -1
	
	for child: Block in mouth.get_children():
		var idx := child.get_index()
		var top := child.global_position.y
		var height := child.size.y
		
		# Skip if not within vertical bounds
		if not Util.within(mouse.y, top, top + height, true):
			continue
		
		# Immediately take over when hovering over non-preview blocks
		if not (child.is_drop_preview or child is NestedBlock):
			in_deadband = false
			Util.log("index: took over block")
			return idx
		
		var center := top + height * 0.5
		var dy := mouse.y - center
		if not in_deadband:
			in_deadband = abs(dy) <= dp_deadband
		
		if in_deadband:
			# If above deadband
			if dy < -dp_deadband:
				in_deadband = false
				Util.log("index: %s above deadband" % child)
				return max(0, idx-1)
			# If below deadband
			if dy > dp_deadband:
				in_deadband = false
				Util.log("index: %s below deadband" % child)
				return idx+1
		
		Util.log("index: %s %s" % [child, "inside deadband"])
		return dp_idx
	
	push_error("Fallback reached.")
	return -1

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			current_data = get_viewport().gui_get_drag_data()
			
			# clone(), not duplicate(0), because children don't have owners
			drop_preview = current_data.clone()
			drop_preview.name = "DropPreview"
			drop_preview.is_drop_preview = true
			drop_preview.modulate.a = DP_ALPHA
			
			dp_deadband = drop_preview.size.y * DP_DEADBAND_PERCENT / 2.0
		NOTIFICATION_DRAG_END:
			if dp_container:
				# Node.replace_by does NOT delete/remove the original Node
				dp_container.insert_child(dp_idx, current_data)
			
			# Delete the node and remove references
			drop_preview.queue_free()
			drop_preview = null
			dp_container = null
			
			if not get_viewport().gui_is_drag_successful():
				if not current_data.origin_parent:
					current_data.queue_free()
				else:
					current_data.origin_parent.insert_child(current_data.origin_idx, current_data)
