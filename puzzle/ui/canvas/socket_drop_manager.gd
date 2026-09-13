extends Control


var current_socket: SocketBlock
var drop_preview: SocketBlock
var dp_socket: SocketBlock
var children: Array[Node]


# Refer to drop_manager.gd, most of this is just copied
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			var drag_data: Variant = get_viewport().gui_get_drag_data()
			
			if not drag_data is SocketBlock:
				current_socket = null
				return
			
			current_socket = drag_data
			
			drop_preview = Block.construct(current_socket.data.duplicate(true))
			drop_preview.name = "DropPreview_%s" % drop_preview.name
			drop_preview.modulate = PuzzleCanvas.drag_preview.modulate
			
			# If the socket is an entity block, forward the object reference
			if current_socket.data.func_type == BlockData.FuncType.ENTITY:
				drop_preview.function.object = current_socket.function.object
			
			# Use _get_children so drop_preview isn't prematurely added to the scene tree
			var children: Array[Node]
			Core._get_children(drop_preview, children)
			for child in children:
				if child is Block:
					child.preview_type = Block.PreviewType.DROP
		
		NOTIFICATION_DRAG_END:
			if current_socket == null:
				return
			
			# If the block was dropped in the trash, restore and unlink the overridden socket
			if current_socket.is_queued_for_deletion():
				if current_socket.has_overridden():
					current_socket.overridden_socket.visible = true
					current_socket.overridden_socket = null
				
				if drop_preview != null:
					drop_preview.queue_free()
					drop_preview = null
				dp_socket = null
				current_socket = null
				return
			
			current_socket.visible = true
			var dropped := dp_socket != null
			
			if current_socket.has_overridden():
				if dropped: 
					current_socket.overridden_socket = null
				else: 
					current_socket.overridden_socket.visible = false
			
			if dp_socket != null:
				var container := dp_socket.get_parent()
				var idx := dp_socket.get_index()
				
				dp_socket.visible = false
				
				current_socket.orphan()
				container.add_child(current_socket)
				container.move_child(current_socket, idx)
				
				current_socket.overridden_socket = dp_socket
			
			if drop_preview != null:
				drop_preview.queue_free()
				drop_preview = null
			
			dp_socket = null
			current_socket = null

func _process(_delta: float) -> void:
	if current_socket == null:
		return
	
	var this_socket := get_preview_socket()
	PuzzleCanvas.drag_preview.visible = this_socket == null
	if this_socket != null:
		if this_socket != dp_socket:
			# Temporarily parent the drop_preview to the socket to visualize the drop
			var container := this_socket.get_parent()
			var idx := this_socket.get_index()
			
			drop_preview.orphan()
			container.add_child(drop_preview)
			container.move_child(drop_preview, idx)
			this_socket.visible = false
			
			if dp_socket != null:
				dp_socket.visible = true
			
			drop_preview.overridden_socket = this_socket
	
	elif dp_socket != null:
		dp_socket.visible = true
		drop_preview.orphan()
		if drop_preview.has_overridden():
			drop_preview.overridden_socket = null
	
	dp_socket = this_socket

func get_preview_socket() -> SocketBlock:
	var control := get_viewport().gui_get_hovered_control()
	if control == null:
		return null
	
	# If hovering anywhere over the current drop preview or any of its children, maintain target
	if dp_socket != null and is_instance_valid(drop_preview) and drop_preview.is_inside_tree():
		if control == drop_preview or drop_preview.is_ancestor_of(control):
			return dp_socket

	var block := Core.get_block(control)
	
	# Rule out the obvious
	if block == null or not block is SocketBlock or block.data.toolbox:
		return null
	
	# Return the same when hovering drop previews or blocks inside drop previews
	if block.preview_type == Block.PreviewType.DROP:
		return dp_socket
	
	var parent_drop := block.get_parent_matching(func(b: Block) -> bool: return b.preview_type == Block.PreviewType.DROP)
	if parent_drop != null:
		return dp_socket
	
	if not block._can_drop_data(Vector2.ZERO, current_socket):
		return null
	
	return block as SocketBlock
