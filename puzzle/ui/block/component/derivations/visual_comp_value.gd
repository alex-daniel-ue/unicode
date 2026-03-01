extends BlockVisualComponent


const TYPE_COLORS: Dictionary[int, Color] = {
	TYPE_NIL : Color("#D8D8D8"),
	TYPE_STRING_NAME : Color("#FDE047"),
	TYPE_STRING : Color("#FFBA8F"),
	TYPE_INT : Color("#75BAFF"),
	TYPE_FLOAT : Color("#ADADFF"),
}

const BOOL_COLORS: Dictionary[bool, Color] = {
	true: Color("#4ADE80"),
	false: Color("#F87171")
}


func _ready() -> void:
	if base.preview_type != Block.PreviewType.NONE:
		return
	
	update_type_color()
	super()

func reset() -> void:
	update_type_color()

func update_type_color() -> void:
	# Explicit type conversion hack
	var value_base := base as ValueBlock
	
	if value_base.data.has_text_blocks():
		target_color = Color.WHITE
		return
	
	var value: Variant = value_base.typecast(value_base.text.get_raw())
	var type := typeof(value)
	
	if type == TYPE_BOOL:
		target_color = BOOL_COLORS[value]
		return
	
	target_color = TYPE_COLORS.get(type, Color.WHITE)
