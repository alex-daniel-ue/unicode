extends Node


func sleep(seconds: float) -> void:
	if seconds <= 0:
		await get_tree().process_frame
		return
	
	await get_tree().create_timer(seconds).timeout
