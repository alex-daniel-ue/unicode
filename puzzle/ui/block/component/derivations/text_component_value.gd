extends BlockTextComponent
## A value block's text: what is typed or chosen in it, when it is a slot.


func _ready() -> void:
	assert(base is ValueBlock)
	super()


func get_raw() -> String:
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
	var value := base as ValueBlock
	if value.data.value.editable_shown and not value.data.has_text_blocks():
		# data.text is the slot's value, so it goes in as text, not as the
		# placeholder: get_raw() reads line_edit.text, and a value shown greyed
		# would evaluate empty. The grey "..." hint is the LineEdit's own
		# placeholder_text, set in value_block.tscn.
		value.line_edit.text = value.data.text
		return
	super()
