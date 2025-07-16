extends Node


const MAX_FPS := 144
const LAG_FPS := 5

var lagging := false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("lag"):
		lagging = not lagging
		Engine.max_fps = LAG_FPS if lagging else MAX_FPS
		Debug.log([lagging, Engine.max_fps])

func log(message: Variant = "", separator := ' ') -> void:
	if message is Array[Variant]:
		for index in range(len(message)):
			if message[index] is float:
				message[index] = "%.03f" % message[index]
		message = separator.join(message)
	elif message is float:
		message = "%.03f" % message
	print_rich("%.03f: %s" % [Time.get_ticks_msec() / 1000., str(message)])
