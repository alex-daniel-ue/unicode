extends BlockTextComponent


func _ready() -> void:
	assert(base is ValueBlock)
	super()

func get_raw() -> String:
	# Explicit type conversion
	var value := base as ValueBlock
	
	if value.data.value.enum_flag:
		if value.option_button.item_count == 0:
			return ""
		
		var selected_id := value.option_button.get_selected_id()
		return value.option_button.get_item_text(selected_id)
	
	if value.data.value.editable_shown:
		return value.line_edit.text
	
	return super()

func format() -> void:
	# Explicit type conversion
	var value := base as ValueBlock
	
	if value.data.value.editable_shown and not value.data.has_text_blocks():
		# data.text is the VALUE, not the hint. It used to be written into
		# placeholder_text, which is why a locked `for ... to 3` showed a grey 3 and
		# then evaluated empty: get_raw() reads line_edit.text, and nothing ever put
		# anything there. The grey "..." hint is the LineEdit's own placeholder_text,
		# set once in value_block.tscn.
		value.line_edit.text = value.data.text
		return
	
	super()
