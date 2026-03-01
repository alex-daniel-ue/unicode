class_name CapBlock
extends NestedBlock


var current_block: Block
var preview: Control

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			visual.start_drag_feedback(Core.current_drag_preview.get_child(0))
		NOTIFICATION_DRAG_END:
			visual.stop_drag_feedback()
