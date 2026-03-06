class_name NotificationStack
extends VBoxContainer


const MAXIMUM := 5

@export var notif_scene: PackedScene


func push(message: String, type: Notification.Type, duration: float) -> void:
	while get_child_count() >= MAXIMUM:
		var last_child := get_child(get_child_count() - 1)
		remove_child(last_child)
		last_child.queue_free()
	
	var notif := notif_scene.instantiate().with(type, duration) as Notification
	notif.label.text = message
	
	add_child(notif)
	move_child(notif, 0)
