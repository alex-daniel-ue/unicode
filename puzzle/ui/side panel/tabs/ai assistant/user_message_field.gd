extends TextEdit


signal submitted


## Enter sends, as in a chat app; Shift+Enter starts a new line. Handled before
## TextEdit's own input, which would put a new line in for Enter and nothing for
## Shift+Enter.
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key := event as InputEventKey
	if not key.pressed or key.keycode not in [KEY_ENTER, KEY_KP_ENTER]:
		return
	if key.shift_pressed:
		insert_text_at_caret("\n")
	elif not key.echo:
		submitted.emit()
	accept_event()
