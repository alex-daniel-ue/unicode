@tool
extends MarginContainer


const BUTTON_CONTAINER_WIDTH := 50.

@export_tool_button("asdsad") var _001 := _update_width
@export var vbox_container: VBoxContainer

var notification := preload("res://puzzle/ui/notification/notification_panel.tscn")

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	get_viewport().size_changed.connect(_update_width)

func add_notification(text: String, duration: float) -> void:
	var notif := notification.instantiate()
	notif.duration = duration
	notif.set_text(text)
	vbox_container.add_child(notif)

func _update_width() -> void:
	position = Vector2.ZERO
	position.x += BUTTON_CONTAINER_WIDTH
	
	size.x = get_viewport_rect().size.x
	size.x -= BUTTON_CONTAINER_WIDTH * 2
