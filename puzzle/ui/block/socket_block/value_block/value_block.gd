@tool
class_name ValueBlock
extends SocketBlock


const TYPE_COLORS: Dictionary[int, Color] = {
	TYPE_NIL : Color.WHITE,
	TYPE_STRING_NAME : Color("#B3B3B3"),
	TYPE_STRING : Color("#FF8FC7"),
	TYPE_BOOL : Color("#72F572"),
	TYPE_INT : Color("#75BAFF"),
	TYPE_FLOAT : Color("#ADADFF"),
}

@export_group("Children")
@export var editable_container: MarginContainer
@export var line_edit: LineEdit
@export var option_button: OptionButton


func _ready() -> void:
	#region Block data signal connections
	data.enum_flag_changed.connect(_on_enum_flag_changed)
	data.editable_changed.connect(_on_editable_changed)
	#endregion
	
	if Engine.is_editor_hint() or is_drop_preview:
		return
	
	option_button.clear()
	for item in data.enum_values:
		option_button.add_item(item)
	if option_button.item_count > 0:
		option_button.select.call_deferred(0)
	
	super()
	
	_on_enum_flag_changed(data.is_enum)
	_on_editable_changed(data.editable)
	set_editing(data.editable and not data.toolbox)
	
	line_edit.text_changed.connect(set_color)
	option_button.item_selected.connect(set_color)
	data.text_changed.connect(set_color)
	set_color()

func _can_drop_data(_at_position: Vector2, drop: Variant) -> bool:
	# Guaranteed all dropped ValueBlocks will be unsocketed
	return (
		super(_at_position, drop) and
		drop is ValueBlock
	)

func format_text() -> void:
	if data.text.is_empty():
		data.text = "empty text"
	
	var raw_texts := data.text.split("{}")
	if len(raw_texts) == 1 and data.editable:
		line_edit.placeholder_text = data.text
	
	super()

func get_raw_text() -> String:
	if data.is_enum:
		return option_button.get_item_text(option_button.get_selected_id())
	if data.editable:
		return line_edit.text
	return super()

func set_color(__: Variant = null) -> void:
	upper_lip.self_modulate = (
		TYPE_COLORS[typeof(Utils.typecast_string(get_raw_text()))]
		if data.text_data.is_empty() else
		Color.WHITE
	)

func set_text(to: String) -> void:
	line_edit.text = to

func set_editing(to: bool) -> void:
	line_edit.editable = to
	option_button.disabled = not to

func _on_enum_flag_changed(to: bool) -> void:
	line_edit.visible = not to
	option_button.visible = to

func _on_editable_changed(to: bool) -> void:
	text_container.visible = not to
	editable_container.visible = to
