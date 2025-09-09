extends BlockTextComponent


func _ready() -> void:
	assert(base is ValueBlock)
	super()

func get_raw() -> String:
	#region Explicit type conversion hack
	@warning_ignore("confusable_local_usage", "shadowed_variable_base_class")
	var base := base as ValueBlock
	#endregion
	
	if base.data.value.enum_flag:
		if base.option_button.item_count == 0:
			return ""
		
		var selected_id := base.option_button.get_selected_id()
		return base.option_button.get_item_text(selected_id)
	
	if base.data.value.editable_shown:
		return base.line_edit.text
	
	return super()

func format() -> void:
	#region Explicit type conversion hack
	@warning_ignore("confusable_local_usage", "shadowed_variable_base_class")
	var base := base as ValueBlock
	#endregion
	
	if base.data.value.editable_shown and not base.data.has_text_blocks():
		if base.data.text.is_empty():
			base.data.text = base.line_edit.placeholder_text
		base.line_edit.placeholder_text = base.data.text
		return
	
	super()
