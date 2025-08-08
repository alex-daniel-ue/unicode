@tool
class_name FunctionBlock
extends CapBlock


const MAX_ARGUMENTS := 3

@export_tool_button("Add argument") var _003 := add_argument
@export_tool_button("Remove argument") var _004 := remove_argument

@export var add_argument_button: Button
@export var remove_argument_button: Button

var line_valueblock := preload("res://puzzle/blocks/generic/line_valueblock.tres")
var line_values: PackedStringArray


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	super()
	
	add_argument_button.pressed.connect(add_argument)
	remove_argument_button.pressed.connect(remove_argument)
	add_argument()

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
	remove_argument_button.visible = len(data.text_data) > 2 and data.text.ends_with(",{}")

func add_argument() -> void:
	data.text += ",{}"
	data.text_data.append(line_valueblock.duplicate(true))
	format_text()

func remove_argument() -> void:
	data.text = data.text.trim_suffix(",{}")
	data.text_data.pop_back()
	format_text()
