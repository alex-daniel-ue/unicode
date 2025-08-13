@tool
extends MarginContainer


const BUTTON_CONTAINER_WIDTH := 50.
const MAXIMUM_NOTIFS := 5

@export var vbox_container: VBoxContainer

var notif_scn := preload("res://puzzle/ui/notification/notification_panel.tscn")

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	get_viewport().size_changed.connect(_update_width)

func add_notification(
		text: String,
		duration: float,
		type: Puzzle.NotificationType
	) -> void:
	
	if vbox_container.get_child_count() >= MAXIMUM_NOTIFS:
		vbox_container.get_child(vbox_container.get_child_count()-1).queue_free()
	
	var notif := notif_scn.instantiate()
	
	notif.duration = duration
	notif.type = type
	notif.set_text(text)
	
	vbox_container.add_child(notif)
	vbox_container.move_child(notif, 0)

func _update_width() -> void:
	position = Vector2.ZERO
	position.x += BUTTON_CONTAINER_WIDTH
	
	size.x = get_viewport_rect().size.x
	size.x -= BUTTON_CONTAINER_WIDTH * 2
