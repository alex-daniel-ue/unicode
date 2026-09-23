extends Node


@export var play_button: Button
@export var play_icon: Texture2D
@export var pause_icon: Texture2D

@export var scripting_buttons: Array[Button]
@export var running_buttons: Array[Button]

@onready var puzzle := get_parent() as Puzzle


func _ready() -> void:
	Interpreter.running_changed.connect(_on_interpreter_running_changed)
	Interpreter.paused_changed.connect(_update_play_button)
	_update_play_button()
	# Deferred: Puzzle instantiates the level in its own _ready, which runs after
	# this one, since children are readied first.
	_gate_play_on_prediction.call_deferred()

func _gate_play_on_prediction() -> void:
	var level := Game.level
	if level == null or not level.prediction_required:
		return
	
	play_button.disabled = true
	play_button.tooltip_text = "Make your prediction first"
	level.prediction_made.connect(
		func() -> void:
			play_button.disabled = false
			_update_play_button(),
		CONNECT_ONE_SHOT
	)

func _on_interpreter_running_changed() -> void:
	for btn: Button in scripting_buttons:
		btn.disabled = Interpreter.is_running
	
	for btn: Button in running_buttons:
		btn.disabled = not Interpreter.is_running
	
	_update_play_button()

func _update_play_button() -> void:
	var pausing := Interpreter.is_running and not Interpreter.is_paused
	play_button.icon = pause_icon if pausing else play_icon
	play_button.tooltip_text = "Pause" if pausing else ("Resume" if Interpreter.is_running else "Run")

func _on_play_button_pressed() -> void:
	if Interpreter.is_running:
		Interpreter.is_paused = not Interpreter.is_paused
	else:
		puzzle.run_program()

func _on_stop_button_pressed() -> void:
	if not Interpreter.is_running:
		return
	
	Interpreter.interrupted = true
	Game.level.fail("Program terminated.")

func _on_speed_button_pressed() -> void:
	Interpreter.is_fast = not Interpreter.is_fast

func _on_frame_button_pressed() -> void:
	Game.level.camera.frame()
	puzzle.notif.push("Level reframed.", Notification.Type.LOG)
