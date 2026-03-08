class_name Puzzle
extends Control


const COMPLETE_SOUND := preload("res://audio/success.mp3")

@export var print_yaml := false

@export_group("Children")
@export var canvas: PuzzleCanvas
@export var side_panels: Array[SidePanel]
@export var information: Label
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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_menu.show()
	elif event.is_action_released("pause"):
		pause_menu.hide()

func configure_level() -> void:
	Game.level.completed.connect(_on_level_completed)
	Game.level.failed.connect(_on_level_failed)
	information.text = Game.level.instructions
	
	for node in level_viewport.get_children():
		node.queue_free()
	level_viewport.add_child(Game.level)
	
	for block in Game.level.get_blocks():
		if block is CapBlock and block.is_type(NestedData.Type.BEGIN):
			canvas.add_child(block)
			block.position = canvas.size / 2.
		else:
			toolbox.add_block(block)

func run_program() -> void:
	if print_yaml:
		print(canvas.serializer.yaml_serialize())
	
	for err in Interpreter.active_errors:
		if is_instance_valid(err.block):
			err.block.visual.set_error(false)
	Interpreter.clear_state()
	
	if Interpreter.is_running:
		notif.push("Program is already running.", Notification.Type.ERROR)
		return
	
	var begin := _get_begin()
	if begin == null:
		notif.push("No begin block on Canvas.", Notification.Type.ERROR)
		return
	
	Game.level.camera.frame()
	Game.level.reset_state()
	
	Interpreter.is_running = true
	side_panels[1].show_menu(true)
	side_panels[1].keep_state = true
	
	await begin.function.run()
	
	Interpreter.is_running = false
	side_panels[1].keep_state = false

func _get_begin() -> CapBlock:
	for child in canvas.get_children():
		if child is CapBlock and child.is_type(NestedData.Type.BEGIN):
			return child
	return null

func _on_level_completed() -> void:
	Interpreter.interrupted = true
	SfxPlayer.play(COMPLETE_SOUND)
	level_complete_popup.show()

func _on_level_failed() -> void:
	Interpreter.interrupted = true
	notif.push("Level failed!", Notification.Type.ERROR)
