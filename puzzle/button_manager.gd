extends Node


@export var idle_buttons: Array[Button]
@export var running_buttons: Array[Button]

@onready var puzzle := get_parent() as Puzzle


func _ready() -> void:
	Interpreter.running_changed.connect(_on_running_changed)

func _on_running_changed() -> void:
	for btn: Button in idle_buttons:
		btn.disabled = Interpreter.is_running
	
	for btn: Button in running_buttons:
		btn.disabled = not Interpreter.is_running

func _on_stop_button_pressed() -> void:
	if Interpreter.is_running:
		Interpreter.interrupted = true
		puzzle.notif.push("Program terminated.", Notification.Type.ERROR)

func _on_speed_button_pressed() -> void:
	Interpreter.is_fast = not Interpreter.is_fast

func _on_return_button_pressed() -> void:
	Transition.change_scene(Core.LEVEL_SELECT)
