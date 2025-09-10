extends Control


var current_socket: SocketBlock
var drop_preview: SocketBlock
var dp_socket: SocketBlock
var children: Array[Node]


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
			
			for child in Core.get_children_recursive(drop_preview):
				if child is Block:
					child.preview_type = Block.PreviewType.DROP
		
		NOTIFICATION_DRAG_END:
			if current_socket == null:
				return
			
			current_socket.visible = true
			
			if current_socket.has_overridden():
				if get_viewport().gui_is_drag_successful():
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
			
			drop_preview.queue_free()
			
			drop_preview = null
			dp_socket = null
			current_socket = null

func _process(_delta: float) -> void:
	if current_socket == null:
		return
	
	var this_socket := get_preview_socket()
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
	var block := Core.get_block(control)
	
	# Rule out the obvious
	if block == null or not block is SocketBlock or block.data.toolbox:
		return null
	
	# Return the same when hovering drop previews
	if block.preview_type == Block.PreviewType.DROP:
		return dp_socket
	
	if not block._can_drop_data(Vector2.ZERO, current_socket):
		return null
	
	return block as SocketBlock
