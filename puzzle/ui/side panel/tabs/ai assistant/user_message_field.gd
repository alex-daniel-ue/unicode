extends TextEdit


signal submitted


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	
	var key := event as InputEventKey
	if key.pressed and not key.echo:
		if key.keycode in [KEY_ENTER, KEY_KP_ENTER] and key.shift_pressed:
			submitted.emit()
