extends VBoxContainer

@warning_ignore("unused_signal")
signal button_pressed

@export var panel: Panel

func _ready() -> void:
	for child in get_children():
		if child is Button:
			if child.has_signal(&"contents_visibility_requested"):
				child.contents_visibility_requested.connect(panel.show_content)
