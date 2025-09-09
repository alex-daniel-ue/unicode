extends BlockVisualComponent


const TYPE_COLORS: Dictionary[int, Color] = {
	TYPE_NIL : Color.WHITE,
	TYPE_STRING_NAME : Color("#D8D8D8"),
	TYPE_STRING : Color("#FFBA8F"),
	TYPE_INT : Color("#75BAFF"),
	TYPE_FLOAT : Color("#ADADFF"),
}

const BOOL_COLORS: Dictionary[bool, Color] = {
	true: Color("#72F572"),
	false: Color("#F57373")
}


func _ready() -> void:
	if base.preview_type != Block.PreviewType.NONE:
		return
	
	update_type_color()
	super()

func reset() -> void:
	update_type_color()

## MILD FIXME: LineEdit.text_changed and OptionButton.item_selected both pass
## one argument, necessitating _unused_arg. Find some way to unbind arguments?
func update_type_color(_unused_arg: Variant = null) -> void:
	#region Explicit type conversion hack
	@warning_ignore("confusable_local_usage", "shadowed_variable_base_class")
	var base := base as ValueBlock
	#endregion
	
	if base.data.has_text_blocks():
		target_color = Color.WHITE
		return
	
	var value: Variant = base.typecast(base.text.get_raw())
	var type := typeof(value)
	
	if type == TYPE_BOOL:
		target_color = BOOL_COLORS[value]
		return
	
	target_color = TYPE_COLORS[type]
