class_name Puzzle
extends Control


const COMPLETE_SOUND := preload("res://audio/success.mp3")
const ERROR_SOUND := preload("res://audio/fail.mp3")

var _last_run_yaml := ""
var _last_run_result := "The student hasn't pressed Play on this level yet."

@export var print_yaml := false

@export_group("Children")
@export var canvas: PuzzleCanvas
@export var side_panels: Array[SidePanel]
@export var information: Container
@export var toolbox: Toolbox
@export var notif: NotificationStack
@export var level_viewport: SubViewport
@export var level_complete_popup: PopupPanel
@export var pause_menu: PopupPanel

func _ready() -> void:
	side_panels[0].show_menu(true)
	side_panels[1].show_menu(true)
	
	if Game.level != null:
		configure_level()
	
	Interpreter.error_raised.connect(_on_interpreter_error)
	Interpreter.output_logged.connect(_on_interpreter_output)

## Perfectly functional; toggled on each "pause" action. Tested.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_menu.show()
		Interpreter.is_paused = true
	elif event.is_action_released("pause"):
		pause_menu.hide()

func _exit_tree() -> void:
	Interpreter.is_running = false
	Interpreter.clear_state()

func configure_level() -> void:
	Interpreter.clear_scopes()
	
	Game.level.completed.connect(_on_level_completed)
	Game.level.failed.connect(_on_level_failed)
	Game.level.room_completed.connect(_on_room_completed)
	
	for node in level_viewport.get_children():
		node.queue_free()
	level_viewport.add_child(Game.level)
	
	for child in information.get_children():
		child.queue_free()
	for content in Game.level.description.take_content():
		content.reparent(information)
	
	for block in Game.level.get_blocks():
		toolbox.add_block(block)
	
	# Block preset setup, for permanent, already-initialized Blocks in levels
	var preset := Game.level.preset.get_preset()
	preset.reparent(canvas)
	preset.position = canvas.size / 2.
	preset.visible = true

func run_program() -> void:
	for err in Interpreter.active_errors:
		if is_instance_valid(err.block):
			err.block.visual.set_error(false)
	
	if Interpreter.is_running:
		notif.push("Program is already running.", Notification.Type.ERROR)
		return
	Interpreter.clear_state()
	
	var begin := _get_begin()
	if begin == null:
		notif.push("No begin block on Canvas.", Notification.Type.ERROR)
		return
	
	_last_run_yaml = canvas.serializer.yaml_serialize()
	
	Interpreter.is_running = true
	side_panels[1].show_menu(true)
	side_panels[1].keep_state = true
	
	var cleared := await Game.level.run_rooms(begin)
	if not cleared:
		_report_failure()
		_last_run_result = "Did not solve the level; the reason is in the output log."
	else:
		_last_run_result = "Solved every room."
	
	Interpreter.is_running = false
	side_panels[1].keep_state = false
	Game.level.camera.frame()

func describe_last_run() -> String:
	if _last_run_yaml.is_empty():
		return _last_run_result
	var changed := _last_run_yaml != canvas.serializer.yaml_serialize()
	return _last_run_result + (" The blocks have changed since that run." if changed else " The blocks are unchanged since that run.")

func _get_begin() -> CapBlock:
	for child in canvas.get_children():
		if child is CapBlock and child.is_type(NestedData.Type.BEGIN):
			return child
	return null

func _on_level_completed() -> void:
	Interpreter.interrupted = true
	SfxPlayer.play(COMPLETE_SOUND)
	level_complete_popup.show()

func _on_level_failed(reason: String) -> void:
	Interpreter.interrupted = true
	notif.push(reason, Notification.Type.ERROR)

func _report_failure() -> void:
	if not Interpreter.active_errors.is_empty():
		return
	if Game.level.has_failed:
		return
	
	const MESSAGE := "The program didn't finish."
	Interpreter.output_log.append(MESSAGE)
	notif.push(MESSAGE, Notification.Type.ERROR)

func _on_interpreter_error(error: Interpreter.Error) -> void:
	SfxPlayer.play(ERROR_SOUND)
	notif.push(error.message, Notification.Type.ERROR)

func _on_interpreter_output(line: String) -> void:
	notif.push(line, Notification.Type.LOG)

func _on_room_completed(index: int, total: int) -> void:
	if total <= 1: return
	notif.push("Room %d of %d solved." % [index + 1, total], Notification.Type.SUCCESS)
