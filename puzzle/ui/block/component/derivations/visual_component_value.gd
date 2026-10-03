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

## An empty slot that can be typed into shimmers between its grey and this, so
## it reads as a place to type rather than as part of the block's picture. All
## slots shimmer in step, from one clock, so a canvas of them breathes together
## instead of flickering.
const SHIMMER_LIGHT := Color("#F4F7FB")
const SHIMMER_PERIOD := 2.2
## A slot under the pointer brightens, whether or not it's empty.
const HOVER_LIGHTEN := 0.25

var _hovered := false


func _ready() -> void:
	if base.preview_type != Block.PreviewType.NONE:
		return
	
	update_type_color()
	super()
	var line := (base as ValueBlock).line_edit
	line.mouse_entered.connect(func() -> void: _hovered = true)
	line.mouse_exited.connect(func() -> void: _hovered = false)

func _update(delta: float) -> void:
	var resting := target_color
	if _typeable():
		if (base as ValueBlock).line_edit.text.is_empty():
			var t := Time.get_ticks_msec() / 1000.0
			var wave := (sin(t * TAU / SHIMMER_PERIOD) + 1.0) / 2.0
			target_color = resting.lerp(SHIMMER_LIGHT, smoothstep(0.0, 1.0, wave) * 0.85)
		if _hovered:
			target_color = target_color.lightened(HOVER_LIGHTEN)
	super(delta)
	target_color = resting

## A slot the student can type into right now: shown, not in the toolbox, and
## not locked by a running program.
func _typeable() -> bool:
	var value_base := base as ValueBlock
	return value_base.line_edit.visible and value_base.line_edit.editable and value_base.is_visible_in_tree()

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
