extends LineEdit


# Courtesy of Gemini 2.5 Pro
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	
	var typed_char := char(event.unicode)
	if typed_char in ["'", "\""]:
		if has_selection():
			wrap_selection(typed_char)
			accept_event()
			return
	
		if caret_column < text.length() and text[caret_column] == typed_char:
			caret_column += 1
			accept_event()
			return
		
		if text.is_empty():
			insert_quote_pair(typed_char)
			accept_event()
			return
	
	if event.keycode == KEY_BACKSPACE:
		var can_delete_pair := caret_column > 0 and caret_column < text.length()
		if can_delete_pair:
			var char_before := text[caret_column - 1]
			var char_after := text[caret_column]
			
			if char_before == char_after and char_before in ["'", "\""]:
				var caret_pos := caret_column
				text = text.substr(0, caret_pos - 1) + text.substr(caret_pos + 1)
				text_changed.emit(text)
				caret_column = caret_pos - 1
				accept_event()

func wrap_selection(quote: String) -> void:
	var start := get_selection_from_column()
	var end := get_selection_to_column()
	var selected_text := text.substr(start, end - start)
	
	text = text.substr(0, start) + quote + selected_text + quote + text.substr(end)
	text_changed.emit(text)
	
	select(start + 1, end + 1)
	caret_column = end + 1

func insert_quote_pair(quote: String) -> void:
	var caret_pos := caret_column
	insert_text_at_caret(quote + quote)
	text_changed.emit(text)
	caret_column = caret_pos + 1
