class_name Puzzle
extends Control


enum NotificationType {LOG, ERROR}
enum SideMenu {LEFT, RIGHT}

const MAX_LOOPS := 9999
const MAX_DEPTH := 100

static var is_program_running := false
static var delaying_interpret := true
static var block_interpret_delay := .15

var error_duration := 4.
var error_block: Block

@export_group("Children")
@export var error_timer: Timer
@export var camera: Camera2D
@export var canvas: ColorRect
@export var notification_container: MarginContainer
@export var side_menus: Array[Panel]
@export var toolbox_panel: MarginContainer
@export var environment_panel: MarginContainer



func _ready() -> void:
	for block in environment_panel.get_exposed_blocks():
		toolbox_panel.add_block(block)

func run_program() -> void:
	if is_program_running:
		add_notification(
			"Program is currently running!",
			error_duration,
			NotificationType.ERROR
		)
		return
	
	var begin := _get_begin()
	if begin == null:
		add_notification(
			"No begin block detected!",
			error_duration,
			NotificationType.ERROR
		)
		return
	
	is_program_running = true
	side_menus[SideMenu.RIGHT].show_menu(true)
	side_menus[SideMenu.RIGHT].keep_shown = true
	if error_block != null:
		error_block.is_error = false
	
	var result := await begin.function.call() as Utils.Result
	if result is Utils.Error:
		error_block = result.block
		error_block.is_error = true
		
		error_timer.start(error_duration)
		error_timer.timeout.connect(func() -> void: error_block.is_error = false)
		
		add_notification(
			result.message,
			error_duration,
			NotificationType.ERROR
		)
	
	is_program_running = false
	side_menus[SideMenu.RIGHT].keep_shown = false

func _get_begin() -> CapBlock:
	for child in canvas.get_children():
		if child is CapBlock:
			if child.check_type(NestedBlockData.Type.BEGIN):
				return child
	return null

func add_notification(msg: String, dur: float, type: NotificationType) -> void:
	side_menus[SideMenu.LEFT].show_menu(false)
	notification_container.add_notification(msg, dur, type)

func show_canvas() -> void:
	release_focus()
	for side_menu in side_menus:
		side_menu.show_menu(false)

func _on_function_defined(block: FunctionBlock) -> void:
	toolbox_panel.add_block(block.func_call_block)
