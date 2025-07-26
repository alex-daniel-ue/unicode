@tool
class_name ValueBlock
extends SocketableBlock


@export var is_enum := false:
	set(value):
		is_enum = value
		line_edit.visible = not is_enum
		option_button.visible = is_enum
@export var enum_values: PackedStringArray

@export_group("Children")
@export var editable_container: MarginContainer
@export var line_edit: LineEdit
@export var option_button: OptionButton

var editable := true:
	set(value):
		editable = value
		line_edit.editable = editable


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	super()
	
	line_edit.visible = not is_enum
	option_button.visible = is_enum
	
	# Equivalent to "if toolbox: editable = false", only this always calls the
	# setter, which we need to update line_edit.editable
	editable = editable and not toolbox
	
	option_button.clear()
	for item in enum_values:
		option_button.add_item(item)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Guaranteed all dropped ValueBlocks will be unsocketed
	return (
		super(_at_position, data) and
		data is ValueBlock
	)

func set_socketed(value: bool) -> void:
	super(value)
	text_container.visible = not socketed
	editable_container.visible = socketed

func _get_block_name() -> String: return "ValueBlock"
