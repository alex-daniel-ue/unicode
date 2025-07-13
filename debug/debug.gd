extends Node


const MAX_FPS := 144
const LAG_FPS := 5

var lagging := false


func _ready() -> void:
	Engine.max_fps = MAX_FPS

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pass
	if event.is_action_pressed("lag"):
		lagging = not lagging
		Engine.max_fps = LAG_FPS if lagging else MAX_FPS
		Utils.log([lagging, Engine.max_fps])
