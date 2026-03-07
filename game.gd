extends Node


var level: Level


func sleep(seconds: float) -> void:
	if seconds <= 0:
		return
	
	await get_tree().create_timer(seconds).timeout
