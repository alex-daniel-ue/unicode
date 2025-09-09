extends Node


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pass

func log(message: Variant = "", separator := ' ') -> void:
	if message is Array[Variant]:
		for index in range(len(message)):
			if message[index] is float:
				message[index] = "%.03f" % message[index]
		message = separator.join(message)
	elif message is float:
		message = "%.03f" % message
	print_rich("%.03f: %s" % [Time.get_ticks_msec() / 1000., str(message)])

func view_callable(_function: Callable) -> void:
	var _debug_function := {
		"is_custom()": _function.is_custom(),
		"is_null()": _function.is_null(),
		"is_standard()": _function.is_standard(),
		"is_valid()": _function.is_valid(),
		"get_argument_count()": _function.get_argument_count(),
		"get_bound_arguments()": _function.get_bound_arguments(),
		"get_method()": _function.get_method(),
		"get_object()": _function.get_object(),
	}
	
	pass
