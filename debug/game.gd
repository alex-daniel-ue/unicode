extends Node


var delaying_interpret := true
var block_interpret_delay := 0.4


func sleep(seconds: float) -> void:
	if seconds <= 0:
		await get_tree().process_frame
	else:
		await get_tree().create_timer(seconds).timeout
