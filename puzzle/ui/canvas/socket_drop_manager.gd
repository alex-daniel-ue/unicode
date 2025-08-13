extends Control


signal block_dropped

var current_drop: Block


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			current_drop = get_viewport().gui_get_drag_data()
			if not current_drop is SocketBlock:
				current_drop = null
				return
		
		NOTIFICATION_DRAG_END:
			if current_drop == null:
				return
			
			if get_viewport().gui_is_drag_successful():
				block_dropped.emit()
			else:
				if current_drop.origin_parent != null:
					current_drop.origin_parent.add_child(current_drop)
					current_drop.origin_parent.move_child(current_drop, current_drop.origin_idx)
					
					if current_drop.overridden_socket != null:
						current_drop.overridden_socket.visible = false
