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

var receptive_line_valueblock := preload("res://puzzle/blocks/_common/receptive_line_valueblock.tres")
var line_valueblock := preload("res://puzzle/blocks/_common/line_valueblock.tres")
## Mainly used to retain LineEdit values when using format_text.
var line_values: PackedStringArray

var func_call_block: Block


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	match preview_type:
		PreviewType.DROP: return
		PreviewType.DRAG:
			super()
			return
	
	super()
	if not data.toolbox:
		add_argument_button.pressed.connect(add_argument)
		remove_argument_button.pressed.connect(remove_argument)
		
		var func_call_data := load("res://puzzle/blocks/control flow/function_call_block.tres")
		func_call_block = Utils.construct_block(func_call_data.duplicate(true))
		func_call_block.visible = false
		# MEDIUM FIXME: Code smell. Watch out if I ever use a FunctionBlock
		# outside the Puzzle scene.
		$"/root/Puzzle"._on_function_defined(self)

func format_text() -> void:
	for button in [add_argument_button, remove_argument_button]:
		text_container.remove_child(button)
	
	line_values.clear()
	for block in get_text_blocks():
		line_values.append(block.get_raw_text())
	
	super()
	
	for button in [add_argument_button, remove_argument_button]:
		button.owner = null
		text_container.add_child(button)
	
	var text_blocks_after := get_text_blocks()
	for idx in range(len(text_blocks_after)):
		var block := text_blocks_after[idx]
		if block is ValueBlock:
			block.value_text_changed.connect(update_call_block)
			if idx < len(line_values) and block is ValueBlock:
				block.set_text(line_values[idx])
				block.set_color()
	
	add_argument_button.visible = len(data.text_data) <= MAX_ARGUMENTS
	remove_argument_button.visible = len(data.text_data) > 1 and data.text.ends_with("{}")

func generate_statement_text() -> Utils.Result:
	# Get arguments
	var result := Utils.evaluate_arguments(self)
	if result is Utils.Error: return result
	var args := result.data as Array
	
	# Validate function name as StringName
	result = Utils.validate_type(args, 0, [TYPE_STRING_NAME], self)
	if result is Utils.Error: return result
	var var_name := result.data as StringName
	
	# Validate function name
	if not var_name.is_valid_ascii_identifier():
		return Utils.Result.error("'%s' isn't a valid variable name!" % var_name, self)
	
	var arg_count := len(data.text_data)-1
	return Utils.Result.success(var_name + "{}".repeat(arg_count))

func update_call_block(asdasd) -> void:
	if func_call_block == null:
		return
	
	var result := generate_statement_text()
	func_call_block.visible = not result is Utils.Error
	if func_call_block.visible:
		func_call_block.data.text = result.data as String

func add_argument() -> void:
	data.text_data.append(line_valueblock.duplicate(true))
	# One-liner so data.text.changed isn't called twice
	data.text += (WITH_ARGS_TEXT if len(data.text_data) <= 2 else "") + "{}"

func remove_argument() -> void:
	data.text_data.pop_back()
	data.text = data.text.trim_suffix((WITH_ARGS_TEXT if len(data.text_data) <= 1 else "") + "{}")
