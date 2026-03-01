extends VBoxContainer


const MAXIMUM_NOTIFS := 5

const NOTIFICATION := preload("res://puzzle/ui/notification/notification.tscn")


func add(message: String, duration: float, type: Puzzle.NotificationType) -> void:
	while get_child_count() >= MAXIMUM_NOTIFS:
		var last_child := get_child(get_child_count() - 1)
		remove_child(last_child)
		last_child.queue_free()
	
	var notif := NOTIFICATION.instantiate()
	
	notif.duration = duration
	notif.type = type
	notif.label.text = message
	
	add_child(notif)
	move_child(notif, 0)
