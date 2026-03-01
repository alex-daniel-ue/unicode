extends Control


signal block_dropped

const DROP_SOUND := preload("res://audio/block_drop.mp3")

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
			
			var children: Array[Node]
			Core._get_children(drop_preview, children)
			
			for child in children:
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
			
			if current_block.is_queued_for_deletion():
				drop_preview.queue_free()
				drop_preview = null
				dp_container = null
				current_block = null
				return
			
			# Handle drop event
			current_block.visible = true
			SfxPlayer.play(DROP_SOUND)
			
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
	var hovered_block := Core.get_block(control)
	
	# Fail early if not a block or if it's in the toolbox
	if hovered_block == null or not hovered_block is Block or hovered_block.data.toolbox:
		#Debug.log("drop_manager.gd/container: null/invalid Block or toolbox Block")
		return null
	
	hovered_block = hovered_block.get_parent_matching(Block.IS_SOLID)
	
	# When hovering over drop preview itself, return top-most preview Block's container
	var parent_block := hovered_block.get_parent_block()
	if hovered_block.preview_type == Block.PreviewType.DROP:
		while parent_block.preview_type == Block.PreviewType.DROP:
			parent_block = parent_block.get_parent_block()
		return parent_block.mouth
	
	# Iterate over parent Blocks until reaching a parent NestedBlock
	while not (parent_block is NestedBlock or parent_block == null):
		parent_block = parent_block.get_parent_block()
	
	if hovered_block is StatementBlock:
		# Assumes the hovered Block has been placed inside parent_block
		if parent_block != null and parent_block.within_mouth(mouse_pos):
			#Debug.log("drop_manager.gd/container: hovering over StatementBlock, picking its parent")
			return parent_block.mouth
		
		# Mouse has to be inside mouth to be placed relative to Block
		#Debug.log("drop_manager.gd/container: hovering over StatementBlock, outside parent or no parent")
		return null
		
	elif hovered_block is NestedBlock:
		var hovering_above_control := mouse_pos.y < control.global_position.y + control.size.y * 0.5 * canvas.scale.y
		var is_outer_lip := control.name == (NestedBlock.UPPER_LIP_NAME if hovering_above_control else NestedBlock.LOWER_LIP_NAME)
		var is_inner_lip := control.name == (NestedBlock.LOWER_LIP_NAME if hovering_above_control else NestedBlock.UPPER_LIP_NAME)
		
		if is_outer_lip and parent_block != null and parent_block.within_mouth(mouse_pos):
			#Debug.log("drop_manager.gd/container: hovering over NestedBlock, picking its parent")
			return parent_block.mouth
		
		elif is_inner_lip or hovered_block.within_mouth(mouse_pos) or (parent_block == null and hovered_block.is_ancestor_of(control)):
			if hovered_block._can_drop_data(mouse_pos, current_block):
				#Debug.log("drop_manager.gd/container: hovering over NestedBlock, picking it")
				return hovered_block.mouth
		
		#Debug.log("drop_manager.gd/container: hovering over NestedBlock, can't drop in it")
		return null
	
	push_error('Unhandled case for drop container! "%s" of Block "%s"' % [control, hovered_block])
	return null

func get_preview_idx(container: Container) -> int:
	var mouse_pos := get_global_mouse_position()
	var children := container.get_children()
	
	var target_idx := 0
	
	for child in children:
		# Skip non-blocks and the current drop preview so it doesn't skew index logic
		if not child is Block or child.preview_type == Block.PreviewType.DROP:
			continue
		
		# Find the vertical halfway point of the block
		var center_y: float = child.global_position.y + (child.size.y * canvas.scale.y) * 0.5
		
		# If the mouse is above the block's center, we insert BEFORE this block
		if mouse_pos.y < center_y:
			return target_idx
			
		target_idx += 1
		
	return target_idx
