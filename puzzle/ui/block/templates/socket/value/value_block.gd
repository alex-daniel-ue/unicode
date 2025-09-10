class_name ValueBlock
extends SocketBlock


@export var editable_container: Container
@export var type_label: Label
@export var line_edit: LineEdit
@export var option_button: OptionButton


func _ready() -> void:
	assert(data.value != null)
	
	option_button.clear()
	for item in data.value.enum_values:
		option_button.add_item(item)
	
	if option_button.item_count > 0:
		option_button.select(0)
	
	# If editables or static text is shown
	text_container.visible = not data.value.editable_shown
	editable_container.visible = data.value.editable_shown
	
	line_edit.editable = data.value.editable
	option_button.disabled = not data.value.editable
	
	if not data.value.editable_shown or data.toolbox:
		line_edit.editable = false
		option_button.disabled = true
	
	# Whether LineEdit or OptionButton is shown
	line_edit.visible = not data.value.enum_flag
	option_button.visible = data.value.enum_flag
	
	if data.value.show_type:
		type_label.update_type()
	visual.update_type_color()
	
	super()
	if preview_type != PreviewType.NONE:
		return
	
	if has_node(^"/root/Puzzle"):
		var puzzle := $"/root/Puzzle" as Puzzle
		puzzle.running_state_changed.connect(_on_puzzle_running_state_changed)
	
	var text_signals := [
		line_edit.text_changed,
		option_button.item_selected,
		data.text_changed
	]
	
	for sig in text_signals:
		sig.connect(visual.update_type_color)
		if data.value.show_type:
			sig.connect(type_label.update_type.call_deferred)

func _can_drop_data(_at_position: Vector2, drop: Variant) -> bool:
	return (
		super(_at_position, drop) and
		drop is ValueBlock
	)

func typecast(string: String) -> Variant:
	if data.value.enum_as_string:
		assert(data.value.editable_shown and data.value.enum_flag)
		return string
	
	return super(string)

func _on_puzzle_running_state_changed(is_running: bool) -> void:
	var should_be_disabled := (
		not data.value.editable or
		not data.value.editable_shown or
		data.toolbox or
		is_running
	)
	
	line_edit.editable = not should_be_disabled
	option_button.disabled = should_be_disabled
