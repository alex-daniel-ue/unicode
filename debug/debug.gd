extends Node


func log(message: Variant = "", separator := ' ') -> void:
	if message is Array[Variant]:
		for index in range(len(message)):
			if message[index] is float:
				message[index] = "%.03f" % message[index]
		message = separator.join(message)
	elif message is float:
		message = "%.03f" % message
	print_rich("%.03f: %s" % [Time.get_ticks_msec() / 1000., str(message)])
