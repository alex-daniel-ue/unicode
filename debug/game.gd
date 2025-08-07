extends Node


var delaying_interpret := true
var block_interpret_delay := .1


func sleep(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
