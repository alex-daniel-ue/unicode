extends Control


var current_block: Block


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			current_block = get_viewport().gui_get_drag_data()
			
			if not current_block is SocketBlock:
				current_block = null
				return
		
		NOTIFICATION_DRAG_END:
			if current_block == null:
				return
			
			current_block.visible = true
			
			if current_block.overridden_socket != null:
				if get_viewport().gui_is_drag_successful():
					current_block.overridden_socket = null
				else:
					current_block.overridden_socket.visible = false
