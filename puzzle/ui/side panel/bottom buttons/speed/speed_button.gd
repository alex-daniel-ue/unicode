extends Button

var is_fast := false
var slow_down := preload("res://puzzle/ui/side panel/bottom buttons/speed/slow_down.png")
var fast_forward := preload("res://puzzle/ui/side panel/bottom buttons/speed/fast_forward.png")

func _on_pressed() -> void:
	is_fast = not is_fast
	icon = slow_down if is_fast else fast_forward
