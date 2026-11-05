class_name NotificationStack
extends VBoxContainer
## Toasts at the top of the canvas: errors, what a program printed, a room
## solved. The newest is on top, and the oldest goes once there are MAXIMUM.

const MAXIMUM := 5

@export var notification_scene: PackedScene


## Shows `message`; with an `action`, clicking the toast runs it.
func push(message: String, type: Notification.Type, action := Callable()) -> void:
	while get_child_count() >= MAXIMUM:
		var last_child := get_child(get_child_count() - 1)
		remove_child(last_child)
		last_child.queue_free()

	var toast := notification_scene.instantiate() as Notification
	toast.type = type
	# Before it enters the tree: how long it stays depends on its text.
	toast.label.text = message
	add_child(toast)
	move_child(toast, 0)
	toast.set_action(action)
