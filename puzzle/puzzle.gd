class_name Puzzle
extends Control


signal running_state_changed(to: bool)

enum NotificationType {
	LOG,
	ERROR,
	SUCCESS
}

const NOTIF_DURATION := 2.0
const MAX_DEPTH := 1000
const MAX_LOOPS := 10000

static var is_running := false
static var interpret_delay := 0.15
static var has_errored := false

@export var canvas: ColorRect
@export var side_panels: Array[Panel]
@export var notification_stack: VBoxContainer
@export var run_button: Button
@export var stop_button: Button
@export var trash_button: Button

# NOTE: Avoid refactoring this. This is perfectly fine.
var errored_blocks: Array[Block]


func run_program() -> void:
	for block in errored_blocks:
		if is_instance_valid(block):
			block.visual.set_error(false)
	errored_blocks.clear()
	
	if is_running:
		notification_stack.add(
			"Program is already running.",
			NOTIF_DURATION,
			NotificationType.ERROR
		)
		return
	
	var begin := _get_begin()
	if begin == null:
		notification_stack.add(
			"No begin block on Canvas.",
			NOTIF_DURATION,
			NotificationType.ERROR
		)
		return
	
	set_running_state(true)
	side_panels[0].show_menu(false)
	side_panels[1].show_menu(true)
	
	for panel in side_panels:
		panel.keep = true
	
	await begin.function.run()
	
	set_running_state(false)
	for panel in side_panels:
		panel.keep = false

func set_running_state(to: bool) -> void:
	is_running = to
	
	run_button.disabled = to
	trash_button.disabled = to
	stop_button.disabled = not to
	
	if not to:
		has_errored = false
	
	running_state_changed.emit(is_running)

func _get_begin() -> CapBlock:
	for child in canvas.get_children():
		if child is CapBlock and child.is_type(NestedData.Type.BEGIN):
			return child
	return null

func hide_side_menus() -> void:
	for panel in side_panels:
		if panel.has_method(&"show_menu"):
			panel.show_menu(false)

func _on_block_errored(block: Block) -> void:
	has_errored = true
	if not errored_blocks.has(block):
		errored_blocks.append(block)

func _on_notif_pushed(message: String, type: NotificationType) -> void:
	notification_stack.add(message, 2., type)

func _on_stop_button_pressed() -> void:
	if is_running:
		has_errored = true
		notification_stack.add(
			"Program terminated.",
			NOTIF_DURATION,
			NotificationType.ERROR
		)
