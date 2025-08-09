@tool
class_name FunctionBlock
extends CapBlock


const MAX_ARGUMENTS := 3
const WITH_ARGS_TEXT := ", with"

#@export_tool_button("Add argument") var _003 := add_argument
#@export_tool_button("Remove argument") var _004 := remove_argument

@export_group("Children")
@export var add_argument_button: Button
@export var remove_argument_button: Button

var line_valueblock := preload("res://puzzle/blocks/generic/line_valueblock.tres")
var line_values: PackedStringArray


func _ready() -> void:
	if Engine.is_editor_hint() or is_drop_preview:
		return
	
	super()
	
	add_argument_button.pressed.connect(add_argument)
	remove_argument_button.pressed.connect(remove_argument)

func format_text() -> void:
	text_container.remove_child(add_argument_button)
	text_container.remove_child(remove_argument_button)
	
	line_values.clear()
	for block in get_text_blocks():
		line_values.append(block.get_raw_text())
	
	super()
	
	text_container.add_child(add_argument_button)
	text_container.add_child(remove_argument_button)
	
	var text_blocks_after := get_text_blocks()
	for idx in range(len(text_blocks_after)):
		if idx >= len(line_values): break
		
		var block := text_blocks_after[idx]
		if block is ValueBlock:
			block.set_text(line_values[idx])
	
	add_argument_button.visible = len(data.text_data) <= MAX_ARGUMENTS
	remove_argument_button.visible = len(data.text_data) > 1 and data.text.ends_with("{}")

func add_argument() -> void:
	data.text_data.append(line_valueblock.duplicate(true))
	# One-liner so data.text.changed doesn't call twice
	data.text += (WITH_ARGS_TEXT if len(data.text_data) <= 2 else "") + "{}"

func remove_argument() -> void:
	data.text_data.pop_back()
	data.text = data.text.trim_suffix((WITH_ARGS_TEXT if len(data.text_data) <= 1 else "") + "{}")
