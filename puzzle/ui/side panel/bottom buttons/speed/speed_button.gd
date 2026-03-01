extends Button

var slow_down := preload("res://puzzle/ui/side panel/bottom buttons/speed/slow_down.png")
var fast_forward := preload("res://puzzle/ui/side panel/bottom buttons/speed/fast_forward.png")

func _ready() -> void:
	_update_icon()

func _on_pressed() -> void:
	_update_icon.call_deferred()

func _update_icon() -> void:
	icon = slow_down if Puzzle.is_fast else fast_forward
