class_name Puzzle
extends Control


enum NotificationType {LOG, ERROR}

const MAX_LOOPS := 9999
const MAX_DEPTH := 100

static var is_program_running := false
static var delaying_interpret := true
static var block_interpret_delay := .4

var error_duration := 2.
var error_block: Block

@export_group("Children")
@export var canvas: ColorRect
@export var camera: Camera2D
@export var notification_container: MarginContainer
@export var toolbox_panel: MarginContainer
@export var side_menus: Array[Panel]


func run_program() -> void:
	if is_program_running:
		printt("Program is currently running!")
		return
	
	is_program_running = true
	if error_block != null:
		error_block.is_error = false
	
	var begin := _get_begin()
	if begin == null:
		push_warning("No start block detected!")
		return
	
	var result := await begin.function.call() as Utils.Result
	if result is Utils.Error:
		error_block = result.block
		error_block.is_error = true
		get_tree().create_timer(error_duration).timeout.connect(func() -> void:
			error_block.is_error = false)
		notification_container.add_notification(result.message, error_duration * 2., NotificationType.ERROR)
	
	is_program_running = false

func _get_begin() -> CapBlock:
	for child in canvas.get_children():
		if child is CapBlock:
			if child.check_type(NestedBlockData.Type.BEGIN):
				return child
	return null

func _on_function_defined(block: FunctionBlock) -> void:
	toolbox_panel.add_block(block.func_call_block)

func _on_canvas_clicked() -> void:
	for side_menu in side_menus:
		side_menu.show_menu(false)
