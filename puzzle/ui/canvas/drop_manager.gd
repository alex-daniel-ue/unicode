extends Control
## 
## Manages drop previews and insertion of Blocks on drag-and-drop events.
## 
## Basic process
## 1. On drag start (NOTIFICATION_DRAG_BEGIN):
##    a. Retrieve drag data and verify it's a valid Block
##    b. Create translucent drop preview clone
## 2. During drag (_process loop):
##    a. Continuously find potential drop containers under cursor
##    b. Determine optimal insertion index in container
##    c. Position/update drop preview accordingly
## 3. On drag end (NOTIFICATION_DRAG_END):
##    a. Insert actual Block at preview position if valid
##    b. Handle failed drops:
##        - Return Block to origin if exists
##        - Destroy toolbox-originated Blocks
##    c. Clean up preview and reset state
##
## Container detection
## - Traverses from hovered Control to parent Blocks
## - Finds nearest valid NestedBlock container
## - Handles special cases:
##    * Drop previews: Uses top-most non-preview parent
##    * StatementBlocks: Requires mouse in parent's mouth
##    * NestedBlocks: Accepts drops directly into mouth
##
## Index determination
## - Splits Blocks vertically at midpoint
## - Above midpoint: Insert before hovered Block
## - Below midpoint: Insert after hovered Block
## - Handles edge cases (lips, empty containers, previews)


signal block_dropped

const DROP_PREVIEW_ALPHA := 0.4

var is_block_dragging := false
var current_drop: Block

var drop_preview: Control
var drop_preview_container: Control
var drop_preview_idx: int

# Drop preview variables that update every frame
var this_container: Control
var this_idx: int

@onready var canvas := $".." as ColorRect


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	update_drop_preview()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			current_drop = get_viewport().gui_get_drag_data()
			
			# Disregard irrelevant/illegal drag-and-drops
			if not current_drop is Block:
				current_drop = null
				return
			
			is_block_dragging = true
			
			# Clone, not duplicate, because get_parent_block is also used on
			# the drop preview (and get_parent_block utilizes owners)
			drop_preview = current_drop.clone()
			
			# Indicate drop preview status to itself and all child Blocks recursively
			drop_preview.is_drop_preview = true
			for child in Utils.get_children(drop_preview):
				if child is Block:
					child.is_drop_preview = true
			
			drop_preview.name = "DropPreview_%s" % drop_preview.get_block_name()
			drop_preview.modulate.a = DROP_PREVIEW_ALPHA
		NOTIFICATION_DRAG_END:
			# Disregard invalid data
			if current_drop == null:
				return
			is_block_dragging = false
			
			# Drag-and-drop ended on valid container
			if drop_preview_container != null:
				# Insert Block data
				block_dropped.emit()
				drop_preview_container.add_child(current_drop)
				drop_preview_container.move_child(current_drop, drop_preview_idx)
			
			# When the drop isn't successful (when _can_drop_data is false)
			if not get_viewport().gui_is_drag_successful():
				if current_drop.origin_parent != null:
					# Return Block to origin
					current_drop.origin_parent.add_child(current_drop)
					current_drop.origin_parent.move_child(current_drop, current_drop.origin_idx)
					
					# MILD FIXME? Kinda out of scope, kinda not
					if current_drop is SocketBlock:
						if current_drop.overridden_socket != null:
							current_drop.overridden_socket.visible = false
				else:
					# If has no origin (like from a toolbox Block), destroy
					current_drop.queue_free()
			
			# Delete the preview and remove references
			drop_preview.queue_free()
			for thing in [drop_preview, drop_preview_container, current_drop]:
				thing = null
			

func update_drop_preview() -> void:
	if drop_preview == null:
		return
	
	if get_viewport().gui_is_dragging():
		this_container = get_preview_container()
		
		if this_container != null:
			this_idx = get_preview_idx(this_container)
			
			# If the preview container has changed
			if this_container != drop_preview_container:
				# If there was a previous container
				if drop_preview_container != null:
					drop_preview_container.remove_child(drop_preview)
				
				this_container.add_child(drop_preview)
				this_container.move_child(drop_preview, this_idx)
				
				# Update stored container, index, and thresholds
				drop_preview_container = this_container
				drop_preview_idx = this_idx
				
			# If only the index has changed
			elif this_idx != drop_preview_idx:
				# Move to and store the new index
				drop_preview_container.move_child(drop_preview, this_idx)
				drop_preview_idx = this_idx
		
		# If previewing nothing, but recently previewed
		elif drop_preview_container != null:
			if drop_preview.get_parent() == drop_preview_container:
				drop_preview_container.remove_child(drop_preview)
			drop_preview_container = null

func get_preview_container() -> Container:
	# MEDIUM FIXME: This should probably be in _notification itself, but I can't
	# find the ideal spot, or what to change instead.
	if not current_drop.data.top_notch:
		return null
	
	var mouse_pos := get_global_mouse_position()
	var control := get_viewport().gui_get_hovered_control()
	var block := Utils.get_block(control)
	
	# Fail early when hovering over nothing or non-Block
	# Toolbox Blocks can't be dropped onto
	if block == null or not block is Block or block.data.toolbox:
		return null
	
	# When hovering over drop preview itself, return top-most preview Block's container
	var parent_block := block.get_parent_block()
	if block.is_drop_preview:
		while parent_block.is_drop_preview:
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
			if block._can_drop_data(mouse_pos, drop_preview):
				return block.mouth
	
	push_error('Unhandled case for drop container! "%s" of Block "%s"' % [control, block])
	return null

func get_preview_idx(container: Container) -> int:
	assert(Utils.get_block(container) != null, "Passed Container is null.")
	assert(Utils.get_block(container) is NestedBlock, "Passed Container isn't part of NestedBlock.")
	
	var end := container.get_child_count()
	
	var mouse_pos := get_global_mouse_position()
	var control := get_viewport().gui_get_hovered_control()
	var block := Utils.get_block(control)
	
	var center_y := block.global_position.y + block.size.y * 0.5 * canvas.scale.y
	var is_above := mouse_pos.y < center_y
	
	# No change
	if block.is_drop_preview:
		return drop_preview_idx
	
	# Guaranteed NestedBlock via initial assert() above
	var container_block: NestedBlock = Utils.get_block(container)
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
		if child.is_drop_preview:
			idx -= 1
		
		var pos: float = child.global_position.y
		var hgt: float = pos + child.size.y * canvas.scale.y
		if pos <= mouse_pos.y and mouse_pos.y < hgt:
			if not is_above:
				idx += 1
			return maxi(0, idx)
	
	push_error('Unhandled case for drop index! "%s" of Block "%s"' % [control, block])
	return end
