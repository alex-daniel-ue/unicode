extends Control


signal block_dropped

var current_block: Block
var drop_preview: Control
var dp_container: Control
var dp_idx: int

@export var canvas: ColorRect


func _process(_delta: float) -> void:
	if not is_instance_valid(current_block):
		return
	
	update_drop_preview()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			# Simulate a fake drop from releasing right-click (copy Block)
			var fake_drop := InputEventMouseButton.new()
			fake_drop.pressed = false
			fake_drop.button_index = MOUSE_BUTTON_LEFT
			Input.parse_input_event(fake_drop)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			current_block = get_viewport().gui_get_drag_data()
			
			# Socket Blocks handled inside socket_drop_manager.gd 
			if current_block is SocketBlock:
				current_block = null
				return
			
			# Cannot merely duplicate, as preview_idx checks whether hovered
			# Blocks are Block.PreviewType.DROP. Drop previews can be hovered.
			drop_preview = Block.construct(current_block.data.duplicate(true))
			drop_preview.name = "DropPreview_%s" % drop_preview.name
			drop_preview.modulate = PuzzleCanvas.drag_preview.modulate
			for child in Core._get_children(drop_preview):
				if child is Block:
					child.preview_type = Block.PreviewType.DROP
			
			# Add filler block if a nested Block
			if drop_preview is NestedBlock:
				if len(current_block.get_blocks()) > 0:
					var dummy := PuzzleCanvas.drag_preview.mouth.get_child(0) as Block
					drop_preview.mouth.add_child(dummy.duplicate(0))
		
		NOTIFICATION_DRAG_END:
			if current_block == null:
				return
			
			# Handle drop event
			current_block.visible = true
			if dp_container != null:
				# Insert Block data
				current_block.orphan()
				dp_container.add_child(current_block)
				dp_container.move_child(current_block, dp_idx)
				
				block_dropped.emit()
			
			# Delete the preview and remove references
			drop_preview.queue_free()
			drop_preview = null
			dp_container = null
			current_block = null

func update_drop_preview() -> void:
	if drop_preview == null:
		return
	
	var this_container := get_preview_container()
	
	if this_container != null:
		var this_idx := get_preview_idx(this_container)
		PuzzleCanvas.drag_preview.visible = false
		
		# If the preview container has changed
		if this_container != dp_container:
			# If there was a previous container
			if dp_container != null:
				dp_container.remove_child(drop_preview)
			
			this_container.add_child(drop_preview)
			this_container.move_child(drop_preview, this_idx)
			
			# Update stored container, index, and thresholds
			dp_container = this_container
			dp_idx = this_idx
			
		# If only the index has changed
		elif this_idx != dp_idx:
			# Move to and store the new index
			dp_container.move_child(drop_preview, this_idx)
			dp_idx = this_idx
	
	# If previewing nothing, but recently previewed
	elif dp_container != null:
		if drop_preview.get_parent() == dp_container:
			dp_container.remove_child(drop_preview)
		dp_container = null
		
		PuzzleCanvas.drag_preview.visible = true

func get_preview_container() -> Container:
	if not current_block.data.top_notch:
		return null
	
	var mouse_pos := get_global_mouse_position()
	var control := get_viewport().gui_get_hovered_control()
	var block := Core.get_block(control)
	
	# Fail early when hovering over nothing or non-Block
	# Toolbox Blocks can't be dropped onto
	if block == null or not block is Block or block.data.toolbox:
		return null
	
	block = block.get_parent_matching(Block.IS_SOLID)
	
	# When hovering over drop preview itself, return top-most preview Block's container
	var parent_block := block.get_parent_block()
	if block.preview_type == Block.PreviewType.DROP:
		while parent_block.preview_type == Block.PreviewType.DROP:
			parent_block = parent_block.get_parent_block()
		return parent_block.mouth
	
	# Iterate over parent Blocks until reaching a parent NestedBlock
	while not (parent_block is NestedBlock or parent_block == null):
		parent_block = parent_block.get_parent_block()
	
	if parent_block != null:
		if block is StatementBlock:
			# Mouse has to be inside mouth to be placed relative to Block
			if not parent_block.within_mouth(mouse_pos):
				return null
			# Assumes the hovered Block has been placed inside parent_block
			return parent_block.mouth
		
		elif block is NestedBlock:
			var center_y := control.global_position.y + control.size.y * 0.5 * canvas.scale.y
			var is_above := mouse_pos.y < center_y
			if control.name == ("UpperLip" if is_above else "LowerLip"):
				# Mouse has to be inside mouth to be placed relative to Block
				if parent_block.within_mouth(mouse_pos):
					return parent_block.mouth
			
			return block.mouth
	
	else: # Hovered Block has no viable parent Block
		if block is StatementBlock:
			return null
		
		elif block is NestedBlock:
			if block._can_drop_data(mouse_pos, current_block):
				return block.mouth
	
	push_error('Unhandled case for drop container! "%s" of Block "%s"' % [control, block])
	return null

func get_preview_idx(container: Container) -> int:
	var end := container.get_child_count()
	
	var mouse_pos := get_global_mouse_position()
	var control := get_viewport().gui_get_hovered_control()
	var block := Core.get_block(control).get_parent_matching(Block.IS_SOLID)
	
	var center_y := block.global_position.y + block.size.y * 0.5 * canvas.scale.y
	var is_above := mouse_pos.y < center_y
	
	# No change
	if block.preview_type == Block.PreviewType.DROP:
		return dp_idx
	
	# Guaranteed NestedBlock...?
	var container_block := Core.get_block(container).get_parent_matching(Block.IS_SOLID) as NestedBlock
	if not container_block.within_mouth(mouse_pos):
		if is_above or not container_block.lower_lip:
			return 0
		return end
	
	var children := container.get_children()
	if children.is_empty():
		return 0
	
	# Emulate a while loop, but with mutable index/counter
	var idx := -1
	for child in children:
		idx += 1
		
		if not child is Block:
			continue
		
		# Don't count drop preview (? it works IDK)
		if child.preview_type == Block.PreviewType.DROP:
			idx -= 1
		
		var pos: float = child.global_position.y
		var hgt: float = pos + child.size.y * canvas.scale.y
		if pos <= mouse_pos.y and mouse_pos.y < hgt:
			if not is_above:
				idx += 1
			return maxi(0, idx)
	
	push_error('Unhandled case for drop index! "%s" of Block "%s"' % [control, block])
	return end
