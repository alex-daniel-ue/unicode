extends Node


const MAX_FPS := 30
const LAG_FPS := 2
const DEBUG_RED := "tomato"
const DEBUG_GREEN := "palegreen"

var is_lagging := false


func _ready() -> void:
	Engine.max_fps = MAX_FPS
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		get_tree().quit()
	if event.is_action_pressed("lag_button"):
		if is_lagging:
			Engine.max_fps = MAX_FPS
			Util.log(_wrap_color(DEBUG_RED, "Disabled lag."))
		else:
			Engine.max_fps = LAG_FPS
			Util.log(_wrap_color(DEBUG_GREEN, "Enabled lag."))
		is_lagging = not is_lagging
	if event.is_action_pressed("pause"):
		Util.log(_wrap_color(DEBUG_RED, "Breakpoint."))
		pass

func _wrap_color(color: String, message: String) -> String:
	return "[color=%s]%s[/color]" % [color, message]

func _is_lmb_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index == 1 and event.pressed
