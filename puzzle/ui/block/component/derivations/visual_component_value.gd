extends BlockVisualComponent


const TYPE_COLORS: Dictionary[int, Color] = {
	TYPE_NIL : Color("#CBD5E1"),
	TYPE_STRING_NAME : Color("f57fbcff"),
	TYPE_STRING : Color("fcc283ff"),
	TYPE_INT : Color("#93C5FD"),
	TYPE_FLOAT : Color("b19dfcff"),
}

const BOOL_COLORS: Dictionary[bool, Color] = {
	true: Color("#86EFAC"),
	false: Color("#FCA5A5")
}


func _ready() -> void:
	if base.preview_type != Block.PreviewType.NONE:
		return
	
	update_type_color()
	super()

func reset() -> void:
	update_type_color()

func update_type_color() -> void:
	# Explicit type conversion
	var value_base := base as ValueBlock
	
	# A value block with a function of its own is a block, not a slot, and wears
	# its own colour: a list's name block would otherwise read as a variable
	# name and turn pink.
	if value_base.data.has_text_blocks() or value_base.data.func_type != BlockData.FuncType.LAMBDA:
		target_color = base.data.color
		return
	
	var value: Variant = value_base.typecast(value_base.text.get_raw())
	var type := typeof(value)
	
	if type == TYPE_BOOL:
		target_color = BOOL_COLORS[value]
		return
	
	target_color = TYPE_COLORS.get(type, base.data.color)
