extends VBoxContainer


const MAXIMUM_NOTIFS := 5

const notif_scene := preload("res://puzzle/ui/notification/notification.tscn")


func add(message: String, duration: float, type: Puzzle.NotificationType) -> void:
	var length := get_child_count()
	if length >= MAXIMUM_NOTIFS:
		get_child(length-1).queue_free()
	
	var notif := notif_scene.instantiate()
	
	notif.duration = duration
	notif.type = type
	notif.label.text = message
	
	add_child(notif)
	move_child(notif, 0)
