extends Control


var current_data: Block
var polling := false


#func _process(_delta: float) -> void:
	#if get_viewport().gui_is_dragging() and polling:
		#var block := get_viewport().gui_get_hovered_control().owner
		#if block is ExpressionBlock:
			#if block._can_drop_data(Vector2.ZERO, current_data):
				#Util.log("hovering expression")
#
#func _notification(what: int) -> void:
	#match what:
		#NOTIFICATION_DRAG_BEGIN:
			#current_data = get_viewport().gui_get_drag_data()
			#polling = current_data is ExpressionBlock
