extends Node


const MAX_FPS := 144
const LAG_FPS := 3

var is_lagging := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		get_tree().quit()
	if event.is_action_pressed("lag_button"):
		if is_lagging:
			Engine.max_fps = MAX_FPS
			Util.log("Disabled lag.")
		else:
			Engine.max_fps = LAG_FPS
			Util.log("Enabled lag.")
		is_lagging = not is_lagging
	if event.is_action_pressed("pause"):
		Util.log("Breakpoint.")
		pass
