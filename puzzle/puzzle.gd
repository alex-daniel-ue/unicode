class_name Puzzle
extends Control


const COMPLETE_SOUND := preload("res://audio/success.mp3")

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

## Perfectly functional; toggled on each "pause" action. Tested.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_menu.show()
	elif event.is_action_released("pause"):
		pause_menu.hide()

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
	print(canvas.serializer.yaml_serialize())
	
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
	
	Interpreter.is_running = true
	side_panels[1].show_menu(true)
	side_panels[1].keep_state = true
	
	await Game.level.run_rooms(begin)
	
	Interpreter.is_running = false
	side_panels[1].keep_state = false
	Game.level.camera.frame()

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

func _on_room_completed(index: int, total: int) -> void:
	if total <= 1: return
	notif.push("Test %d of %d solved." % [index + 1, total], Notification.Type.SUCCESS)
