@tool
class_name ValueBlock
extends SocketBlock


@export_group("Children")
@export var editable_container: MarginContainer
@export var line_edit: LineEdit
@export var option_button: OptionButton


func _ready() -> void:
	assert(data is ValueBlockData)
	var data := data as ValueBlockData
	
	#region Block data signal connections
	data.enum_flag_changed.connect(_on_enum_flag_changed)
	data.editable_changed.connect(_on_editable_changed)
	#endregion
	
	if Engine.is_editor_hint():
		return
	
	super()
	
	_on_enum_flag_changed(data.is_enum)
	_on_editable_changed(data.editable)
	set_editing(data.editable and not data.toolbox)
	
	if not data.editable:
		text_container.modulate.a = 0.5
	
	option_button.clear()
	for item in data.enum_values:
		option_button.add_item(item)

func _can_drop_data(_at_position: Vector2, drop: Variant) -> bool:
	# Guaranteed all dropped ValueBlocks will be unsocketed
	return (
		super(_at_position, drop) and
		drop is ValueBlock
	)

func format_text() -> void:
	if data.text.is_empty():
		data.text = "empty text"
		push_warning(data.text)
	
	var raw_texts := data.text.split("{}")
	if len(raw_texts) == 1 and data.editable:
		# FIXME: Review this, if it's ok?
		line_edit.placeholder_text = data.text
	
	super()

func get_text() -> String:
	if not visible:
		return ""
	
	if data.editable:
		if data.is_enum:
			return option_button.get_item_text(option_button.selected)
		return line_edit.text
	return super()

func set_editing(to: bool) -> void:
	line_edit.editable = to
	option_button.disabled = not to

func _on_enum_flag_changed(to: bool) -> void:
	line_edit.visible = not to
	option_button.visible = to

func _on_editable_changed(to: bool) -> void:
	text_container.visible = not to
	editable_container.visible = to
