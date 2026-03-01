extends BlockTextComponent


func _ready() -> void:
	assert(base is ValueBlock)
	super()

func get_raw() -> String:
	# Explicit type conversion hack
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
	# Explicit type conversion hack
	var value := base as ValueBlock
	
	if value.data.value.editable_shown and not value.data.has_text_blocks():
		if value.data.text.is_empty():
			value.data.text = value.line_edit.placeholder_text
		value.line_edit.placeholder_text = value.data.text
		return
	
	super()
