@tool
class_name ValueBlock
extends SocketBlock


@export_group("Children")
@export var editable_container: MarginContainer
@export var line_edit: LineEdit
@export var option_button: OptionButton

## So that toolbox ValueBlocks can't get edited.
var editable := true:
	set(value):
		editable = value
		line_edit.editable = editable


func _ready() -> void:
	assert(data is ValueBlockData)
	var data := data as ValueBlockData
	data.receptivity_changed.connect(_on_receptivity_changed)
	
	if Engine.is_editor_hint():
		return
	
	super()
	
	line_edit.visible = not data.is_enum
	option_button.visible = data.is_enum
	
	# Equivalent to "if toolbox: editable = false", only this always calls the
	# setter, which we need to update line_edit.editable
	editable = editable and not toolbox
	
	option_button.clear()
	for item in data.enum_values:
		option_button.add_item(item)

func _can_drop_data(_at_position: Vector2, drop: Variant) -> bool:
	# Guaranteed all dropped ValueBlocks will be unsocketed
	return (
		super(_at_position, drop) and
		drop is ValueBlock
	)

func _on_receptivity_changed(to: bool) -> void:
	text_container.visible = not to
	editable_container.visible = to

func _on_enum_flag_changed(to: bool) -> void:
	line_edit.visible = not to
	option_button.visible = to
