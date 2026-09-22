extends Node


var level: Level
var level_scene: PackedScene
var level_id := &""
var session_id := Crypto.new().generate_random_bytes(8).hex_encode()


func sleep(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0 and not Interpreter.interrupted:
		await get_tree().process_frame
		if not Interpreter.is_paused:
			remaining -= get_process_delta_time()
